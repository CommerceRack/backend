package BATCHJOB::IMPORT;

use strict;

use Data::Dumper;
use Archive::Zip;
use lib "/backend/lib";
use ZTOOLKIT;
use ZCSV;
use Data::Dumper;


##
## references throughout this file:
##		$u = UTILITY object
##		$bj = batch job BATCHJOB object.
##

sub parse_csv { return(&ZCSV::parse_csv(@_)); }

##
##
##
sub new {
	my ($class,$bj) = @_;

#	print "CLASS: $class\n";
#	print Dumper($batch);

	my $ERROR = undef;

	my $self = {};
	$self->{'*BJ'} = $bj;		## pointer to the batch job object
	bless $self, $class;
	return($self);
	}


##
## this is normally called outside a .cgi -- 
##	it actually RUNS a job that was queued to unix atd with ->start()
##
sub run {
	my ($self,$bj) = @_;

	if (not defined $bj) {
		$bj = $self->{'*BJ'};
#		$bj->nuke_slog();			## we might run a csv more than once. so lets clear it out.
		}

	my $vars = $bj->vars();
	my $LOADTYPE = uc($vars->{'LOADTYPE'});
	$LOADTYPE =~ s/[^A-Z0-9\_\-]+//g;
	print "LOADTYPE: $LOADTYPE\n";

	my ($USERNAME) = $bj->username();
	print Dumper($bj,$vars);

	my $LUSERNAME = $bj->lusername();
	my $PRT = $bj->prt();



	my %FILTER = ();
	# special fields:
	# %INVENTORY will load into inventory
	# %HOMEPAGE will place on homepage
	# %CATEGORY will create a category (if necessary) and place the product on it
	# %DELETE
	# %IMGURL=attrib will copy an image url into imagelibrary and associate it with the defined attribute
	# %PRODUCTID will create/update a product id.

	my @ERRORS = ();
	my $BUFFER = undef;
	
	my $filename = $vars->{'file'};
	print "FILE: $filename\n";


	require LUSER::FILES;
	my ($lf) = LUSER::FILES->new($bj->username());
	my ($TYPE,$FILENAME,$GUID) = $lf->lookup(GUID=>$bj->guid());

	my $userppath = &ZOOVY::resolve_userpath($bj->username())."/PRIVATE";
	
	if (scalar(@ERRORS)>0) {
		}
	elsif ($vars->{'TYPE'} eq 'JEDI') {
		## we've got a jedi file.. so no need to load it into memory.
		}
	elsif (-f "$userppath/$filename") {
		## attempt to read from local tmp file.		
		open F, "<$userppath/$filename";
		$/ = undef; $BUFFER = <F>; close F;
		close F;
		if (length($BUFFER)<10) { 
			print STDERR "length: ".length($BUFFER)."\n".$BUFFER."\n";
			push @ERRORS, "File $filename had no contents.\n";
			}
		}
	elsif (-f "/tmp/$filename") {
		## attempt to read from local tmp file.		
		open F, "</tmp/$filename";
		$/ = undef; $BUFFER = <F>; close F;
		close F;
		if (length($BUFFER)<10) { 
			print STDERR "length: ".length($BUFFER)."\n".$BUFFER."\n";
			push @ERRORS, "File $filename had no contents.\n";
			}
		}
	else {
		## TODO: attempt to read from network private files directory 
		push @ERRORS, "Could not read $filename";
		}


	my ($fieldref,$lineref,$optionsref);
	if (scalar(@ERRORS)>0) {
		## bad shit happened.. no need to do anything else.
		}
	elsif ($vars->{'TYPE'} eq 'JEDI') {
		## we got a JEDI file, we won't be able to read headers so lets fake out "TYPE"
		$optionsref->{'TYPE'} = 'JEDI';
		$fieldref = [];
		$lineref = [];
		}
	else {
		if (not defined $vars->{'ALLOW_CRLF'}) { $vars->{'ALLOW_CRLF'}++; }
		if (not defined $vars->{'SEP_CHAR'}) { $vars->{'SEP_CHAR'} = ','; }
		($fieldref,$lineref,$optionsref) = &ZCSV::readHeaders($BUFFER,header=>1,
			ALLOW_CRLF=>int($vars->{'ALLOW_CRLF'}),SEP_CHAR=>$vars->{'SEP_CHAR'}
			);
		if (not defined $optionsref->{'FILENAME'}) {
			$optionsref->{'FILENAME'} = $filename;
			}
		}


	if (scalar(@ERRORS)>0) {
		## something bad already happened.
		}
	elsif (defined $optionsref->{'TYPE'}) {
		## TYPE is already defined!
		$optionsref->{'TYPE'} = uc($optionsref->{'TYPE'});
		if ($optionsref->{'TYPE'} eq 'PRODUCTS') { 
			## change "PRODUCTS" to "PRODUCT"
			$optionsref->{'TYPE'} = 'PRODUCT';
			}
		elsif ($optionsref->{'TYPE'} =~ /INVENTORY[\.]?(.*?)/) {
			my $subtype = $1;
			$optionsref->{'TYPE'} = 'INVENTORY';			
#			if ($subtype eq 'SIMPLE') { $fieldref = ['%SKU','%INVENTORY','%LOCATION','%MIN_QTY'];  }
			}
		elsif ($optionsref->{'TYPE'} =~ /CUSTOMER[\.]?(.*?)/) {
			my $subtype = $1;
			$optionsref->{'TYPE'} = 'CUSTOMER';
#			if ($subtype eq 'FULL') { $fieldref = ['%EMAIL','bill_fullname','bill_address1','bill_address2','bill_city','bill_state','bill_zip','bill_country','bill_phone','ship_fullname','ship_address1','ship_address2','ship_city','ship_state','ship_zip','ship_country','ship_phone','%LIKESPAM']; }
#			if ($subtype eq 'SIMPLE') { $fieldref = ['%EMAIL','bill_firstname','bill_lastname','%LIKESPAM']; }
			}

		}
	else { 
		push @ERRORS, "No Format (Load Type) was specified.\n"; 
		}
	
	# print STDERR Dumper($optionsref,$fieldref,$lineref);
	# print STDERR Dumper($optionsref,\@ERRORS);


	if (scalar(@ERRORS)==0) {
		$bj->progress(0,0,"Received bytes=".length($BUFFER).", rows=".scalar(@{$lineref}));

		if (scalar(@{$lineref})==0) {
			$bj->title(sprintf("IMPORT JOB TYPE: %s",$optionsref->{'TYPE'}));
			push @ERRORS, "No lines found in file. Check the file contents and delimiter"; 
			}
		elsif ($optionsref->{'TYPE'} eq 'ORDER') { 
			require BATCHJOB::IMPORT::ORDER;
			$bj->title(sprintf("Order Import: %s",$bj->get('.file')));
			eval { &BATCHJOB::IMPORT::ORDER::parseorder($bj,$fieldref,$lineref,$optionsref,\@ERRORS); };
			if ($@) { push @ERRORS, "ISE - $@"; }
			}
		elsif ($optionsref->{'TYPE'} eq 'CATEGORY') {
			require BATCHJOB::IMPORT::CATEGORY;
			$bj->title(sprintf("Category Import: %s",$bj->get('.file')));
			eval { &BATCHJOB::IMPORT::CATEGORY::parsecategory($bj,$fieldref,$lineref,$optionsref,\@ERRORS);	};
			if ($@) { push @ERRORS, "ISE - $@"; }
			}
		elsif ($optionsref->{'TYPE'} eq 'CUSTOMER') {
			require BATCHJOB::IMPORT::CUSTOMER;
			$bj->title(sprintf("Customer Import: %s",$bj->get('.file')));
			if ($LUSERNAME eq 'SUPPORT') { $optionsref->{'OVERRIDE'}++; }
			eval { &BATCHJOB::IMPORT::CUSTOMER::parsecustomer($bj,$fieldref,$lineref,$optionsref,\@ERRORS); };
			if ($@) { push @ERRORS, "ISE - $@"; }
			}
		elsif ($optionsref->{'TYPE'} eq 'REVIEW') {
			require BATCHJOB::IMPORT::REVIEW;
			$bj->title(sprintf("Review Import: %s",$bj->get('.file')));
			eval { &BATCHJOB::IMPORT::REVIEW::parse($bj,$fieldref,$lineref,$optionsref,\@ERRORS); };
			if ($@) { push @ERRORS, "ISE - $@"; }
			}
		elsif ($optionsref->{'TYPE'} eq 'REWRITES') {
			require BATCHJOB::IMPORT::REWRITES;
			$bj->title(sprintf("URL Rewrites Import: %s",$bj->get('.file')));
			eval { &BATCHJOB::IMPORT::REWRITES::import($bj,$fieldref,$lineref,$optionsref,\@ERRORS); };
			if ($@) { push @ERRORS, "ISE - $@"; }
			}
		elsif ($optionsref->{'TYPE'} eq 'RULES') {
			require BATCHJOB::IMPORT::RULES;
			$bj->title(sprintf("RULES Import: %s",$bj->get('.file')));
			eval { &BATCHJOB::IMPORT::RULES::import($bj,$fieldref,$lineref,$optionsref,\@ERRORS); }; 
			if ($@) { push @ERRORS, "ISE - $@"; }			
			}
		elsif ($optionsref->{'TYPE'} eq 'INVENTORY') {
			$bj->title(sprintf("Inventory Import: %s",$bj->get('.file')));
			require BATCHJOB::IMPORT::INVENTORY;
			eval { &BATCHJOB::IMPORT::INVENTORY::parseinventory($bj,$fieldref,$lineref,$optionsref,\@ERRORS); }; 
			if ($@) { push @ERRORS, "ISE - $@"; }			
			}
		elsif ($optionsref->{'TYPE'} eq 'LISTINGS') {
			$bj->title(sprintf("Listing Event Import: %s",$bj->get('.file')));
			require BATCHJOB::IMPORT::LISTING;
#			&BATCHJOB::IMPORT::logImport($USERNAME,$LUSERNAME,$fieldref,$lineref,$optionsref);
			eval { &BATCHJOB::IMPORT::LISTING::parse($bj,$fieldref,$lineref,$optionsref,\@ERRORS);	}; 
			if ($@) { push @ERRORS, "ISE - $@"; }			
			}
		elsif ($optionsref->{'TYPE'} eq 'PRODUCT') {
			$bj->title(sprintf("Product Import: %s",$bj->get('.file')));
			require BATCHJOB::IMPORT::PRODUCT;
			eval { &BATCHJOB::IMPORT::PRODUCT::parseproduct($bj,$fieldref,$lineref,$optionsref,\@ERRORS); };
			if ($@) { push @ERRORS, "ISE: $@"; }
			}
		elsif ($optionsref->{'TYPE'} eq 'JEDI') {
			$bj->title(sprintf("JEDI Import: %s",$bj->get('.file')));
			print Dumper($bj);
			my ($ERRMSG) = $self->gogojedi($bj);
			if ((defined $ERRMSG) && ($ERRMSG ne '')) {
				push @ERRORS, $ERRMSG;
				}
			}
		elsif ($optionsref->{'TYPE'} eq 'TRACKING') { 
			require BATCHJOB::IMPORT::TRACKING;
			$bj->title(sprintf("Tracking Import: %s",$bj->get('.file')));
			eval { &BATCHJOB::IMPORT::TRACKING::parsetracking($bj,$fieldref,$lineref,$optionsref,\@ERRORS); };
			if ($@) { push @ERRORS, "ISE - $@"; }			 
			}
		else {
			push @ERRORS, "Unknown import TYPE=$optionsref->{'TYPE'}";
			}


		if (scalar(@ERRORS)==0) {
			}

		}
	# NOTE: at some point we'll probably have more optimized loaders, for other file types (eg: strict inventory)


	print STDERR "HELLO IMPORT TYPE:$optionsref->{'TYPE'}\n";

	if (scalar(@ERRORS)==0) {
		$bj->finish("SUCCESS","Completed import.");
		}
	else {
		$bj->finish("ERROR",join("|",@ERRORS));
		}

	return("FINISHED");
	}


##
## moved the jedi code here so it doesn't pollute ->run() method.
##
sub gogojedi {
	my ($self,$bj) = @_;

	my ($USERNAME) = $bj->username();
	my ($PRT) = $bj->prt();
	my $LUSERNAME = undef;

	my $vars = $bj->vars();

	my %params = ();

	my $zip = Archive::Zip->new();
	$zip->read("/tmp/$vars->{'file'}");

	my $ERROR = undef;
	my $ZYAML = undef;
	if ($zip->memberNamed('zoovy.yaml')) {
		require YAML::Syck;
		$ZYAML = YAML::Syck::Load($zip->contents('zoovy.yaml'));
		}
	else {
		$ERROR = "Could not find zoovy.yaml file in JEDI Package";
		}

	my $SUPPLIER = $ZYAML->{'SUPPLIER'};
	$SUPPLIER = substr($SUPPLIER,0,6);

	if ((not $ERROR) && (not defined $ZYAML)) {
		$ERROR = "No zoovy.yaml file found in JEDI package file";
		}

	if ((not $ERROR) && ($vars->{'.create'})) {
		## create a supplier
		require SUPPLIER;
		if (not defined $ZYAML->{'SUPPLIER-EMAIL'}) { $ZYAML->{'SUPPLIER-EMAIL'} = '-'; }
		if (not defined $ZYAML->{'SUPPLIER-PHONE'}) { $ZYAML->{'SUPPLIER-PHONE'} = '-'; }
		print STDERR Dumper($ZYAML);

		my ($S) = SUPPLIER->new($USERNAME,$SUPPLIER,'NEW'=>1);
		$S->save_property('NAME',"$ZYAML->{'DOMAIN'}");
		$S->save_property('PHONE',"$ZYAML->{'SUPPLIER-PHONE'}");
		$S->save_property('EMAIL',"$ZYAML->{'SUPPLIER-EMAIL'}");
		$S->save_property('WEBSITE',sprintf("%s",$ZYAML->{'DOMAIN'}));
		$S->save_property('MARKUP',sprintf("%s",$ZYAML->{'SCHEDULE-DEFAULT-MARKUP'}));
		$S->save_property('FORMAT','DROPSHIP');
		$S->save_property('MODE','JEDI');

		$S->save_property('.jedi.domain',$ZYAML->{'DOMAIN'});
		if ($vars->{'.login'} ne '') {
			$S->save_property('.jedi.login',$vars->{'.login'});
			}
		if ($vars->{'.pass'} ne '') {
			$S->save_property('.jedi.pass',$vars->{'.pass'});
			}
		$S->save();

#		require SUPPLIER::JEDI;
#		my $errs = (SUPPLIER::JEDI::checkaccess($S));
#		if (defined $errs) {
#			foreach my $errref (@{$errs}) {
#				$ERROR .= "$errref->{'severity'} API error[$errref->{'err'}] $errref->{'content'}<br>";
#				}
#			}
		}

#	if ((not $ERROR) && ($vars->{'.themes'})) {
#		## load themes.
#		my ($PROFILE) = &ZOOVY::prt_to_profile($USERNAME,$PRT);
#		my ($nsref) = &ZOOVY::fetchmerchantns_ref($USERNAME,$PROFILE);
#		$nsref->{'zoovy:site_wrapper'} = $ZYAML->{'RECOMMENDED-WRAPPER'};
#		&ZOOVY::savemerchantns_ref($USERNAME,$PROFILE,$nsref);
#		}


	# $zip->readFromFileHandle($fh);
	my @names = $zip->memberNames();
	my $file_count = 0;
	foreach my $m (@names) {
		$file_count++;
		next if ($ERROR);
		$bj->progress($file_count,scalar(@names),"Loading file $m");

		if ($m eq 'products.txt') {
			my ($udbh) = &DBINFO::db_user_connect($USERNAME);
			my ($fieldref,$lineref,$optionsref) = &ZCSV::readHeaders($zip->contents($m),header=>1,ALLOW_CRLF=>1,SEP_CHAR=>",");
			$optionsref->{'SUPPLIER'} = $SUPPLIER;
			$optionsref->{'JEDI'} = $SUPPLIER;
			$optionsref->{'MODE'} = 'JEDI';
			$optionsref->{'ALLOW_CRLF'}++;
			if ($vars->{'.products'} eq 'reset') {
				## nuke all products for this supplier if we're doing a reset
				$bj->slog("Resetting product database");
				require PRODUCT::BATCH;
				my ($NC) = NAVCAT->new($USERNAME,PRT=>$PRT);
				foreach my $pid (@{&PRODUCT::BATCH::list_by_attrib($USERNAME,'zoovy:prod_supplier',$SUPPLIER)}) {
					$bj->slog("Deleting product: $pid (will reload from supplier)");
					&ZOOVY::deleteproduct($USERNAME,$pid,'navcat'=>$NC);
					}
				$NC->save();
				$vars->{'.products'} = 'new';
				}
			else {
				$optionsref->{'DESTRUCTIVE'} = 0;
				}

			if ($vars->{'.products'} eq 'new') {
				## loads any new products that do noe exist, updates costs.
				$optionsref->{'NEW_ONLY'}++;
				}
			elsif ($vars->{'.products'} eq 'smart') {
				$optionsref->{'COLUMNS_ALLOWED'} = 'zoovy:base_cost,zoovy:pogs,zoovy:prod_msrp';
				}
			$optionsref->{'TYPE'} = 'PRODUCT';
			require BATCHJOB::IMPORT::PRODUCT;
			&BATCHJOB::IMPORT::PRODUCT::parseproduct($bj,$fieldref,$lineref,$optionsref);			
			&DBINFO::db_user_close();
			}
		elsif (($m eq 'categories.txt') && ($vars->{'.navcats'} eq 'ignore')) {
			}
		elsif ($m eq 'categories.txt') {
			my ($fieldref,$lineref,$optionsref) = &ZCSV::readHeaders($zip->contents($m),header=>1,ALLOW_CRLF=>1,SEP_CHAR=>",");
			if ($vars->{'.navcats'} eq 'reset') {
				$optionsref->{'CAT_DESTRUCTIVE'}++;
				}
			elsif ($vars->{'.navcats'} eq 'smart') {
				$optionsref->{'JUST_PRODUCTS'}++;
				}
			# $optionsref->{'JEDI'} = $jedistr;
			$optionsref->{'TYPE'} = 'CATEGORY';
			require BATCHJOB::IMPORT::CATEGORY;
			&BATCHJOB::IMPORT::CATEGORY::parsecategory($bj,$fieldref,$lineref,$optionsref);			
			}
		elsif ($m eq 'inventory.html') {
			}
		else {
			warn "Unknown file: $m\n";
			}
		}

	return($ERROR);
	}



##
## pretty self explanatory. updates the progress meter.
##
sub progress {
	my ($self, $records_done, $records_total, $msg) = @_;

	print STDERR "$records_done/$records_total: $msg\n";
	my ($bj) = $self->bj();
	if (defined $bj) {
		$bj->update(
			RECORDS_DONE=>$records_done,
			RECORDS_TOTAL=>$records_total,
			STATUS=>'RUNNING',
			STATUS_MSG=>$msg,
			NOTES=>sprintf("%s",$self->meta()->{'notes'}),
			);
		}
	}

1;


__DATA__

	die();

	my $CLASS = "UTILITY::$MAPP";
	my $cl = undef;

	if (not $ERROR) {
		$cl = Class::Runtime->new( class => $CLASS );
		if ( not $cl->load ) {
			warn "Error in loading class $CLASS\n";
			warn "\n\n", $@, "\n\n";
			$ERROR = $@;
			}
		}
		
	my $u = undef;
	## create the object. 
	## 	*ALWAYS* return an object.. if an object isn't returned it's assumed to be an invalid MAP
	if ($ERROR) {
		}
	elsif (not $cl->isLoaded()) {
		$ERROR = "Utility Class $CLASS could not be loaded.";
		}
	elsif ($CLASS->can('new')) {
		## basically this is calling SYNDICATION::DOBA->new() for example
   	($u) = $CLASS->new();
		## copy all parameters into %meta 
		}
	else {
		$ERROR = "Could not call new on Utility Class $CLASS";
		}


	# print STDERR 'BLAH: '.Dumper($r,$ERROR);

	if ($ERROR) {
		}
	elsif ((not defined $u) || (ref($u) ne $CLASS)) {
		$ERROR = "Unknown Utility: $MAPP";
		}
	else {
		$u->{'*PARENT'} = $self;
		$self->{'*UM'} = $u;
		}

	if ($ERROR) {
		}
	elsif (not $CLASS->can('work')) {
		$ERROR = "Class $CLASS cannot call work";
		}

	if ($ERROR) {
		## returns a scalar on failure.
		warn "About to return error: $ERROR\n";
		return($ERROR);
		}
	else {
		bless $self, "BATCHJOB::UTILITY";
		}

	return($self);
	}


##
##
##
sub run {
	my ($self,$bj) = @_;

	my ($um) = $self->{'*UM'};
	my $ERROR = undef;
	if (not defined $um) {
		$ERROR = "1|BATCHJOB::UTILITY::run did not have *UM set";
		}
	else {
		print "###BATCHJOB_IMPORT_RUNNING#####################################################\n";
		($ERROR) = $um->work($bj);
		if (defined $ERROR) {
			$ERROR = "2|$ERROR";
			}
		else {
			$ERROR = "0|Success";
			}
		}

	## hmm.. might be a good idea to do some more error handling here.
	# $BATCHJOB::UTILITY::VERBS{$r->{'TYPE'}}->($bj,$r);

	## cleanup batch job.
	my ($errcode,$msg) = split(/\|/,$ERROR,2);
	if ($errcode>0) {
		warn "BATCHJOB::UTILITY::run returning with err=$errcode ($msg)";
		$bj->finish('ERROR',"Utility error: $msg");
		}
	elsif ($um->can('finish')) {
		$um->finish($bj);
		}
	else {
		warn "BATCHJOB::UTILITY::run returning SUCCESS";
		$bj->finish('SUCCESS',"Utility has Completed");
		}
	return($errcode,$msg);
	}


##
##
##


sub username { return($_[0]->{'_USERNAME'}); }
sub prt { return($_[0]->{'_PRT'}); }
sub mid { return($_[0]->{'_MID'}); }
sub luser { return($_[0]->{'_LUSER'}); }


##
##
##


sub batchify {
	my ($ARREF,$SEGSIZE) = @_;

	my @batches = ();
	my $arref = ();
	my $count = 0;
	foreach my $i (@{$ARREF}) {
		push @{$arref}, $i; 
		$count++;
		if ($count>=$SEGSIZE) {
			$count=0; 
			push @batches, $arref;
			$arref = ();
			}
		}
	if ($count>0) {
		push @batches, $arref;
		}
	return(\@batches);
	}




##
##
##

1;
