package BATCHJOB::UTILITY::PRODUCT_POWERTOOL;

use YAML::Syck;
use strict;
use lib "/backend/lib";
use SEARCH;
use PRODUCT;
use Data::Dumper;
require INVENTORY2;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	my $USERNAME = $bj->username();
	my $MID = $bj->mid();
	my $PRT = $bj->prt();
	$bj->progress(0,0,"Downloading list of products.");

	my @RECORDS = ();
	my $reccount = 0;

	my $vars = $bj->meta();

	my @LINES = ();
	my @PRODUCTS = ();

	my $ERROR = undef;
	
#@actions = [
#'VERB1?params',
#'VERB2?params',
#'VERB3?params',
#]

#@product_selectors = [
#'navcat=.safe.name',
#'pids=xyz1,xyz2',
#'search=xyz',
#'all',
#]

	my @CMDS = ();
	if ($bj->version() < 201324) {
		@LINES = split(/[,\n\r]+/,$vars->{'PRODUCTS'});
		my $ACTIONS = YAML::Syck::Load($vars->{'ACTIONS'});

		foreach my $line (@LINES) {
			if ($line eq '') {
				## do nothing
				}
			elsif (substr($line,0,1) ne '~') {
				## this is probably a product
				push @PRODUCTS, $line;
				}
			elsif ($line eq '~ALL') {
				## this is a list that needs to be expanded.
				my $hashref = &ZOOVY::fetchproducts_by_nameref($USERNAME,cache=>1);	
				@PRODUCTS = sort keys %{$hashref};
				}
			else {
				$ERROR = "UNKNOWN PRODUCT SOURCE[$line]";
				}
			}

		if ($vars->{'ACTIONS'} eq '') {
			$ERROR = "No actions were specified";
			}
		elsif (not defined $ACTIONS) {
			$ERROR = "Actions could not be determined/decoded/specified";
			}
		elsif (scalar(@{$ACTIONS})==0) {
			$ERROR = "No actions specified";
			}

		my $count = 0;
		foreach my $action (@{$ACTIONS}) {
			push @CMDS, [ uc($action->{'verb'}), $action, '', $count++ ];
			}
		}
	else {
		## 201324 and higher

		## validation phase
		if ($ERROR) {
			## shit happened!
			}
		elsif (not defined $vars->{'actions'}) {
			$ERROR = 'actions not specified';
			}
		elsif (ref($vars->{'actions'}) eq '') {
			my $count = 0;


			print STDERR "$vars->{'actions'}\n";
			foreach my $line (split(/[\n]+/,$vars->{'actions'})) {
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					$cmdset->[2] = $line;
					$cmdset->[3] = $count++;
					$cmdset->[1]->{'#'} = $count;


					my $VERB = lc($cmdset->[0]);
					foreach my $k (keys %{$cmdset->[1]}) {
						## CONVERT "verb#something" to just "something"
						if ($k =~ /^$VERB\-(.*?)$/) {
							$cmdset->[1]->{$1} = $cmdset->[1]->{$k};
							}
						}

					# print Dumper($cmdset);
					push @CMDS, [ $cmdset->[0], $cmdset->[1], '', $count++ ];
					}
				}
			}


		if ($ERROR) {
			}
		elsif (not defined $vars->{'product_selectors'}) {
			$ERROR = 'product_selectors not specified';
			}
		elsif (ref($vars->{'product_selectors'}) eq '') {
			require PRODUCT::BATCH;
			@PRODUCTS = &PRODUCT::BATCH::resolveProductSelector($USERNAME,$PRT,[ split(/[\n]+/,$vars->{'product_selectors'}) ]);
			}
		}


	my $BATCHES = &ZTOOLKIT::batchify(\@PRODUCTS,150);
	my $rectotal = scalar(@{$BATCHES});

	if ($ERROR) {
		}
	elsif (scalar(@PRODUCTS)==0) {
		$ERROR = "No products selected";
		}

	##
	## pre-flight stage. 
	## 
	my %PARSER = ();
	my $AMAZON_USERREF = undef;
	my $i = 0;
	foreach my $CMDSET (@CMDS) {
		my ($VERB,$CMD,$line,$count) = @{$CMDSET};
		$VERB = lc($VERB);

		if ($VERB eq 'wikify') {
			require HTML::WikiConverter; 
			require HTML::WikiConverter::Creole;
			$PARSER{'HTML::WikiConverter'} = new HTML::WikiConverter(
				dialect => 'Creole',
				# dialect => 'WikkaWiki',
				# dialect => 'MediaWiki',
				# dialect => 'TikiWiki',
				#wiki_uri => [
				#	"http://static.zoovy.com/img/$USERNAME/",
			   #   # sub { pop->query_param('title') } # requires URI::QueryParam
  	  			#	]
				);
			}
		elsif ($VERB =~ /amazon\:/) {
			require AMAZON3;
			$AMAZON_USERREF = &AMAZON3::fetch_userprt($USERNAME,$PRT);
			}

		if ($VERB eq 'makekeywords') {
			require Lingua::EN::Keywords::Yahoo;
			}

		if (($CMD->{'when'}) && ($CMD->{'when'} eq 'when-attrib-contains')) {
			## we default to "has" which is a case insensitive regex
			if ($CMD->{'when-attrib-operator'} eq '') {
				$CMD->{'when-attrib-operator'} = 'has'; 
				}

			### if we have a "has" we short circuit when-attrib-contains by compiling the regex
			if ($CMD->{'when-attrib-operator'} eq 'has') {
				$CMD->{'when-attrib-operator'} = 'regex';
				$CMD->{'when-regex'} = qr/$CMD->{'when-attrib-contains'}/i;
				}
			}
		}

	print 'ACTIONS: '.Dumper(\@PRODUCTS,\@CMDS);
	
	##
	## flight stage
	##
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	$ZOOVY::GLOBAL_CACHE_FLUSH = 0;
	$i = 0;
	foreach my $batches (@{$BATCHES}) {
		next if (defined $ERROR);


		my @MSGS = ();
		my $Prodsref = &PRODUCT::group_into_hashref($USERNAME,$batches);
		if ( scalar(keys %{$Prodsref}) != scalar(@{$batches})) {
			warn "ERROR|+Some of the products which were specified are not valid or could not be loaded.\n";
			}

		foreach my $P (values %{$Prodsref}) {
			my ($PID) = $P->pid();

#			next unless ($PID eq 'ZOO-BZ102-C');
			print STDERR "PID: $PID (batch $reccount of $rectotal)\n";

			my $changes = 0;
			# print Dumper($prodref);


			foreach my $CMDSET (@CMDS) {
				my ($VERB,$CMD,$line,$cmdcount) = @{$CMDSET};
				$VERB = lc($VERB);
				print STDERR "VERB:$VERB\n";
				
				my $attrib = $CMD->{'attrib'};
				$attrib =~ s/[\s]+//gso;

				my $val = $P->fetch( $attrib );
				# my $val = &ZOOVY::fetchproduct_attrib($USERNAME,$PID,$attrib);
				# print STDERR "PROD: $USERNAME $PID $attrib\n";

				# print "VERB WAS: $VERB\n";
				my $when = $CMD->{'when'};
				# print "WHEN: $when\n";

				if ($when eq '') {
					}
				elsif ($when eq 'when-attrib-contains') {
					my $attrib = $CMD->{'when-attrib'};
					my $op = $CMD->{'when-attrib-operator'};
					
					if ($op eq 'regex') {
						# print "CMD[$CMD->{'#'}] OP[$op] attrib=[$prodref->{$attrib}] \"$CMD->{'when-attrib-contains'}\"\n";
						if ($P->fetch($attrib) =~ $CMD->{'when-regex'}) { } else { $VERB = '--SKIP--'; }
						if ($VERB ne '--SKIP--') { 
							print "MATCH!!!!! [".$P->fetch($attrib)."] to [$CMD->{'when-attrib-contains'}]\n"; 
							}
						}
					elsif ($op eq 'has') {
						if ($P->fetch($attrib) !~ /$CMD->{'when-attrib-contains'}/i) { $VERB = '--SKIP--'; }
						}
					elsif ($op eq 'eq') {
						if ($P->fetch($attrib) ne $CMD->{'when-attrib-contains'}) { $VERB = '--SKIP--'; }
						}
					elsif ($op eq 'ne') {
						if ($P->fetch($attrib) eq $CMD->{'when-attrib-contains'}) { $VERB = '--SKIP--'; }
						}
					elsif ($op eq 'gt') {
						if ($P->fetch($attrib) < $CMD->{'when-attrib-contains'}) { $VERB = '--SKIP--'; }
						}
					elsif ($op eq 'lt') {
						if ($P->fetch($attrib) > $CMD->{'when-attrib-contains'}) { $VERB = '--SKIP--'; }
						}
					elsif ($op eq 'isblank') {
						if ($P->fetch($attrib) ne '') { $VERB = '--SKIP--'; }
						}
					elsif ($op eq 'isnull') {
						if (defined $P->fetch($attrib)) { $VERB = '--SKIP--'; }
						}
					else {
						die("Unknown when-attrib-operator [$op]\nLINE: $cmdcount\n".Dumper($CMD));
						}
					}
				else {
					die("Unknown when [$when]");
					}

				if ($VERB eq '--SKIP--') {
					print "CMD[$CMD->{'#'}] SKIPPED\n";
					}
				else {
					print "CMD[$CMD->{'#'}] VERB IS: $VERB\n".Dumper($CMD)."\n";
					}

				my $new = undef;
				my ($pretty);

				if ($VERB eq 'set') {
					$new = $CMD->{'value'}; 
					}
				elsif ($VERB eq 'copy') {
					## new value is old value
					$new = $val;
					## change attrib in focus to new field
					$attrib = $CMD->{'copyto'};
					## the (new) old value is now the existing value of the target attrib
					$val = $P->fetch($attrib);
					}
				elsif ($VERB eq 'copyfrom') {
					## the (new) old value is now the existing value of the target attrib
					$new = $P->fetch($CMD->{'copyfrom'});
					}
				elsif ($VERB eq 'deleteattrib') {
					$new = undef;
					}
				elsif ($VERB eq 'add') {
					($new,$pretty) = &ZOOVY::calc_modifier($val,$CMD->{'value'},1);
					}
				elsif ($VERB eq 'explode') {
					($new) = &SEARCH::explode($val);
					# &ZOOVY::calc_modifier($val,$CMD->{'addval'},1);
					}
#				elsif ($VERB eq 'makekeywords') {
#					## make keywords will ONLY update blank fields.
#					if ($val ne '') {
#						$new = $val;
#						}
#					else {
#						my @keywords = Lingua::EN::Keywords::Yahoo::keywords(
#								$P->fetch('zoovy:prod_name')."\n".
#								$P->fetch('zoovy:prod_desc')."\n".
#								$P->fetch('zoovy:prod_detail')
#								);
#						@keywords = splice(@keywords,1,20);
#						($new) = join(',',@keywords);
# 						}
#					}
				elsif (($VERB eq 'set-sku-from-product') || ($VERB eq 'set-empty-sku-from-product')) {
					my $val = $P->fetch($attrib);
					foreach my $set (@{$P->list_skus()}) {
						my ($SKU,$SKUREF) = @{$set};
						if ($VERB eq 'set-sku-from-product') {
							$SKUREF->{$attrib} = $val; $changes++;
							}
						elsif ($VERB eq 'set-empty-sku-from-product') {
							if ((not defined $SKUREF->{$attrib}) || ($SKUREF->{$attrib} eq '')) {
								$SKUREF->{$attrib} = $val;	$changes++;				
								}
							}
						}
					}
				elsif ($VERB eq 'nuke-option') {
					my $pogs2 = $P->fetch_pogs();
					my ($focus_sogid) = substr($CMD->{'value'},0,2);
					my ($focus_optid) = substr($CMD->{'value'},2,2);
					$attrib = '@POGS';

					my @newpogs = ();
					foreach my $pog (@{$pogs2}) {
						if ($pog->{'id'} ne $focus_sogid) {
							push @newpogs, $pog;
							}
						elsif ($focus_optid eq '') {
							## nuke the whole option group by skipping adding it to @newpogs
							}
						else {
							## nuke the an individual option in an option group (option group is nuked if no options are selected though)
							my @newoptions = ();
							foreach my $opt (@{$pog->{'@options'}}) {
								if ($opt->{'v'} ne $focus_optid) { push @newoptions, $opt; }
								}
							$pog->{'@options'} = \@newoptions;
							if (scalar(@newoptions)>0) {
								push @newpogs, $pog;
								}
							}
						}
					$new = \@newpogs;
					}
				elsif ($VERB eq 'set-option') {
					## who are we focusing on.
					$attrib = '@POGS';
					my ($focus_sogid) = uc(substr($CMD->{'value'},0,2));
					my ($focus_optid) = uc(substr($CMD->{'value'},2,2));

					# print "FOCUS: $focus_sogid $focus_optid\n";	print Dumper($CMD);	die();


					## load sog from disk
					require POGS;
					my ($FULLSOGREF) = &POGS::load_sogref($USERNAME,$focus_sogid);
					my $FULLOPTREF = undef;
					foreach my $opt (@{$FULLSOGREF->{'@options'}}) {
						if ($opt->{'v'} eq $focus_optid) { $FULLOPTREF = $opt; }
						}
			
					my $pogs2 = $P->fetch_pogs();
					my $focuspogref = undef;
					foreach my $pogref (@{$pogs2}) {
						if ($pogref->{'id'} eq $focus_sogid) { $focuspogref = $pogref; }
						} 


					if (not defined $FULLSOGREF) {
						## we could not find this SOG in the product.
						warn "CMD[$CMD->{'#'}] FULLSOGREF was not defined (could not load SOG)\n";
						}
					elsif (not defined $FULLOPTREF) {
						## we could not find THIS option in the SOG
						warn "CMD[$CMD->{'#'}] FULLOPTREF the option value optid=[$focus_optid] requested in sogid=[$focus_sogid] does not exist in SOG\n";
						}
					elsif (not defined $focuspogref) {
						## add the OPTIONGROUP to the list of OG's in the product's pog stack
						$focuspogref = $FULLSOGREF;
						$focuspogref->{'@options'} = [ $FULLOPTREF ]; 
						push @{$pogs2}, $focuspogref;
						}
					elsif (defined $focuspogref) {
						## yay, we found the sog in the product already.
						}
					else {
						## the product must already have the option?
						print Dumper($FULLSOGREF,$PID,$focuspogref);
						warn "CMD[$CMD->{'#'}] This line should NEVER be reached.";
						}

					# print Dumper($focuspogref);

					## sog exists, make sure we aren't adding a dup. opt
					my $found = 0;
					foreach my $opt (@{$focuspogref->{'@options'}}) {
						if ($opt->{'v'} eq $focus_optid) { $found++; }
						}
					if ($found) {
						print "[$focus_optid] ALREADY EXISTED\n";
						}
					elsif (not $found) {
						print "[$focus_optid] WAS ADDED\n";
						push @{$focuspogref->{'@options'}}, $FULLOPTREF;
						}

					$new = $pogs2;
					print "RETURNING: $new\n";
					}

				elsif ($VERB eq 'replace') {
					my $search = quotemeta($CMD->{'value'});

					my $replace = undef;
					if ($bj->version()<201324) { 
						$replace = $CMD->{'replacewith'};
						}
					else {
						$replace = $CMD->{'replace-with'};
						}

					if ($search eq '') {
						$search = '^$';
						}
					else {
						$search =~ s/\\\*/\.\*\?/g;		# translate escaped wildcards \* to .*?
						}
					$new = $val;
					print STDERR "VAL: [$val]\n";
					$new =~ s/$search/$replace/igs;
					print STDERR "NEW: [$new]\n";
					}
				elsif ($VERB eq 'cleandeadproducts') {
					# print STDERR "VAL: $val\n";
					my @pids = '';
					foreach my $PID (split(/,/,$val)) {
						next if ($PID eq '');
						push @pids, $PID;
						}
					#my ($invref) = &INVENTORY::fetch_incrementals($USERNAME,\@pids);
					#@pids = ();
					#foreach my $PID (keys %{$invref}) {
					#	next if (index($PID,':')>=0);
					#	if ($invref->{$PID}>0) { push @pids, $PID; }
					#	}
					#$new = join(',',@pids);
					my ($INVSUMMARY) = INVENTORY2->new($USERNAME,$bj->lusername())->summary('@PIDS'=>\@pids);
					@pids = ();
					foreach my $PID (keys %{$INVSUMMARY}) {
						next if (index($PID,':')>=0);		## ignore skus!? (wtf)
						if ($INVSUMMARY->{$PID}>0) { push @pids, $PID; }
						}
					$new = join(',',@pids);
					}
				elsif ($VERB eq 'wikify') {
					if (not defined $val) { $val = ''; }
					$new = $PARSER{'HTML::WikiConverter'}->html2wiki($val);
					$new = &ZTOOLKIT::htmlstrip($val,1);
					# print "NEW: $new\n";
					}
				elsif ($VERB eq 'striphtml') {
					$new = &ZTOOLKIT::htmlstrip($val,1);
					}
				elsif ($VERB eq 'stripwiki') {
					$new = &ZTOOLKIT::wikistrip($val,1);
					}
				elsif ($VERB eq 'stripcrlf') {
					$new = $val;
					$new =~ s/[\n\r]+/ /gs;
					}
				elsif ($VERB eq 'fmakeupc') {
					require ZTOOLKIT::FAKEUPC;
					$new = &ZTOOLKIT::FAKEUPC::fmake_upc($USERNAME,$PID);
					}
				elsif ($VERB =~ /amazon\:(delete|requeue)$/) {
					if ($attrib ne 'amz:ts') {
						warn "needs amz:ts set as attribute (for safety reasons, that is all)\n";
						}
					elsif ($1 eq 'delete') {
						&AMAZON3::item_set_status($AMAZON_USERREF,[ $P->pid() ],['=this.delete_please'],'USE_PIDS'=>1,'+ERROR'=>TXLOG::addline(0,'PRODUCTS','_'=>'SUCCESS','+'=>'Delete via PowerTool'));
						}
					elsif ($1 eq 'requeue') {
						&AMAZON3::item_set_status($AMAZON_USERREF,[ $P->pid() ],['=this.create_please'],'USE_PIDS'=>1,'+ERROR'=>TXLOG::addline(0,'PRODUCTS','_'=>'SUCCESS','+'=>'Requeue via PowerTool'));
						}
					$VERB = '--SKIP--';
					}
				elsif ($VERB eq '--SKIP--') {
					## a condition probably set this to --SKIP--
					}
				elsif ($VERB eq '') {
					warn "********* VERB NOT SET\n";
					}
				else {
					print 'UNknown command: '.Dumper($CMD);
					die();
					}


				if ($VERB eq '--SKIP--') {
					## this probably failed some if then logic.
					}
				elsif (not defined $new) { 				
					print "CMD[$CMD->{'#'}] VERB: ($VERB) val[$val] REMOVED\n";
					push @MSGS, [ "Updated PID=$PID ATTR=$attrib was removed.","SAVE" ];
					$P->store($attrib,undef);
					$changes++;
					}
				elsif ($attrib eq '@POGS') {
					## special rules for comparing @POGS sets (for now they always cause a save)
					$P->store_pogs($new); $changes++;
					}
				elsif ($val ne $new) {
					print "VERB: ($VERB) val[$val] new[$new]\n";
					push @MSGS, [ "Updated PID=$PID ATTR=$attrib to $new","SAVE" ];
					$P->store($attrib,$new);
					$changes++;
					}
				}
		
			if ($changes>0) {
				# use Data::Dumper; print STDERR Dumper($pidrefs->{$PID});
				$P->save();
				}
		
			#if ($USERNAME eq 'toynk') {
			#	open F, ">>/tmp/toynk.debug";
			#	print F Dumper({'PID'=>$PID,'prodref'=>$P,'fetch(hanges'=>$changes));
			#	close F;
			#	}
			}

		if ((++$reccount % 100)==1) {
			$bj->progress($reccount,$rectotal,"Did batch");
			}

		## TODO:: write @MSGS
		if (scalar(@MSGS)>0) {
			$bj->logmsgs("UTILITIES.POWERTOOL",\@MSGS);
			}

		}

	if (not $ERROR) {
		$bj->progress($rectotal,$rectotal,"Finished powertool.");
		}
	else {
		$bj->progress(0,0,"ERROR-$ERROR");
		}

	$ZOOVY::GLOBAL_CACHE_FLUSH = 1;
	&ZOOVY::nuke_product_cache($USERNAME);
	&DBINFO::db_user_close();

	return(undef);
	}

1;
