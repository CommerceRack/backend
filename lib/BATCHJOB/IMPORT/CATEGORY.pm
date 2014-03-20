package BATCHJOB::IMPORT::CATEGORY;

use strict;
use lib "/backend/lib";
require NAVCAT;


sub parsecategory {
	my ($bj,$fieldsref,$lineref,$optionsref,$errs) = @_;

	my %SORT_CATS = ();		# list of categories we need to resort.

	if (not defined $errs) { $errs = []; }

	my ($USERNAME,$LUSERNAME,$PRT) = ($bj->username(),$bj->lusername(),$bj->prt());

	if (defined $optionsref->{'PRT'}) {
		if (lc($LUSERNAME) eq 'admin') { 
			$bj->slog("Changing PRT to $optionsref->{'PRT'} for ADMIN user");
			$PRT = $optionsref->{'PRT'};
			}
		elsif ($LUSERNAME eq 'SUPPORT') { 
			$bj->slog("Changing PRT to $optionsref->{'PRT'} for ZOOVY SUPPORT");
			$PRT = $optionsref->{'PRT'};
			}
		else {
			$bj->slog("Cannot change to PRT=$optionsref->{'PRT'} (requires support or admin user) - aborting");		
			$lineref = [];
			push @{$errs}, "FAIL|PRT= header option requires ADMIN user (not equivalence).";
			}
		}	


#	if (($LU->is_admin()) && (defined $optionsref->{'PRT'})) {
#		$PRT = int($optionsref->{'PRT'});
#		$bj->slog("<font color='red'>ADMIN USER: Set Partition to PRT=$PRT</font><br>\n");		
#		}

	my ($PROFILE) = &ZOOVY::prt_to_profile($USERNAME,$optionsref->{'PRT'});
	my ($DOMAIN) = $bj->domain();
	my $nc = NAVCAT->new($USERNAME,PRT=>$PRT);

	require NAVCAT;	
	require PAGE;
	if (defined $optionsref->{'CAT_DESTRUCTIVE'}) {
		$bj->slog("<font color='red'>DESTRUCTIVE IMPORT - NUKING ALL NAVIGATION CATEGORIES!</font><br>\n");
		$nc->nuke();
		}

	use Data::Dumper; $bj->slog("HEADERS: ".Dumper($fieldsref));

	my $needs_page = 0;
	foreach my $destfield (@{$fieldsref}) {
		if ($destfield eq '%LAYOUT') { $needs_page++; }
		next if (substr($destfield,0,1) eq '%');
		$needs_page++;
		}
	## SANITY: at this point $needs_page is set if we need to load the page object.

	my $rows_count = scalar(@{$lineref});
	my $rows_done = 0;

	foreach my $line (@{$lineref}) {
		# clean up the line
		my $tmp = ''; my $errstr = ''; foreach my $ch (split(//,$line)) { 
			if (ord($ch)<=128 && ord($ch)>20) { $errstr .= $ch; $tmp .= $ch; } else { $errstr .= "<font style='background-color: red; color: white;' color='red'>$ch [#".ord($ch)."]</font>"; }
			} 
		if ($line ne $tmp) { 
			$bj->slog("<font color='blue'>ENCOUNTERED CORRECTABLE ERROR:</font> (corrected characters are shown below)<br>$errstr");
			$line = $tmp;
			}
		
		my @DATA = &BATCHJOB::IMPORT::parse_csv($line);
		if (scalar(@DATA)==0) {
			$bj->slog("<font color='red'>ERROR WITH LINE (could not be imported):<br></font>$line");
			next; # bail out of this loop since we had an error.
			}


		my $pos = 0;
		my $SAFE = undef; 
		my %ncdata = ();
		my %pagedata = ();
		foreach my $destfield (@{$fieldsref}) {
			$destfield =~ s/[\s]+//g;

			if ($destfield eq '%SAFE') {				
				$SAFE = lc($DATA[$pos]);
				if (substr($SAFE,0,1) eq '$') {
					$SAFE =~ s/\$[^a-z0-9\_]+$//gs;		# strip all invalid characters for a list.
					}		# lists.
				elsif (substr($SAFE,0,1) eq '*') {} 	# special pages e.g. *cart
				elsif (substr($SAFE,0,1) ne '.') { 
					$SAFE = '.'.$SAFE;  
					$SAFE =~ s/[^a-z0-9\.\_\-]+$//gs;		# strip all invalid characters for a navcat (note: $ is not allowed)
					}
				}
			elsif ($destfield eq '%PRETTY') {
				$ncdata{'pretty'} = $DATA[$pos];
				}
			elsif ($destfield eq '%SORT') {
				$ncdata{'sort'} = $DATA[$pos];
				}
			elsif ($destfield eq '%PRODUCTS') {
				$ncdata{'products'} = $DATA[$pos];
				$ncdata{'products'} =~ s/[ ]+/,/gs;
				$ncdata{'products'} =~ s/[,]+/,/gs;
				}
			elsif ($destfield eq '%LAYOUT') {
				$pagedata{'fl'} = $DATA[$pos];
				if ($DATA[$pos] eq '') { 
					## never save a blank category, so blank = delete. .. might make more sense to ignore blank's.
					delete $pagedata{'fl'}; 
					}	
				}
			elsif ($destfield eq '%METASTR') {
				$ncdata{'metastr'} = $DATA[$pos];
				}
			elsif ($destfield eq '%REMAP_SAFE') {
				$ncdata{'%REMAP_SAFE'} = $DATA[$pos];
				}
			elsif ($destfield eq '%NUKE_SAFE') {
				$ncdata{'%NUKE_SAFE'} = $DATA[$pos];
				}
			else {
				# $bj->slog("<font color='red'>Unknown Column: $destfield\n</font>");
				$pagedata{$destfield} = $DATA[$pos];
				}
			$pos++;
			}
		$bj->progress($rows_done++,$rows_count,"Category: $SAFE");

		if ($SAFE =~ /[^a-z0-9_\-\.\$\*]+/) {
			# invalid categories detected.
			$bj->slog("<font color='red'>Skipping invalid safename [$SAFE]\n</font>");
			}
		elsif ($optionsref->{'JUST_PRODUCTS'}) {
			if ($nc->exists($SAFE)) {
				foreach my $pid (split(/,/,$ncdata{'products'})) {
					$nc->set($SAFE,insert_product=>$pid);
					}
				}
			}
		else {
	
			if ($ncdata{'%NUKE_SAFE'} ne '') {
				$bj->slog("<font color='green'>Nuking $ncdata{'%NUKE_SAFE'}\n</font><br>");
				$nc->nuke($ncdata{'%NUKE_SAFE'});
				require PAGE;
				my ($PG) = PAGE->new($USERNAME,$ncdata{'%NUKE_SAFE'},DOMAIN=>$DOMAIN,PRT=>$PRT);
				$PG->nuke();
				$SAFE = undef;
				}
			elsif ($ncdata{'%REMAP_SAFE'}) {
				$bj->slog("<font color='blue'>Remapping $SAFE to $ncdata{'%REMAP_SAFE'}\n</font><br>");
				$nc->remap($SAFE,$ncdata{'%REMAP_SAFE'});
				$SAFE = $ncdata{'%REMAP_SAFE'};
				}

			if (defined $SAFE) {
				$bj->slog("Importing category safe=[$SAFE] pretty=[$ncdata{'pretty'}] sort=[$ncdata{'sort'}] products=[$ncdata{'products'}]\n");
				$nc->set($SAFE, %ncdata);
				my $PG = undef;

				if ($needs_page) {
					$PG = PAGE->new($USERNAME,$SAFE,PRT=>$PRT,DOMAIN=>$DOMAIN);
					foreach my $k (keys %pagedata) {
						$PG->set($k, $pagedata{$k});
						}
					$PG->save();
					}
				}
			}
		} # end of while loop
	
	if (defined $optionsref->{'NUKE_CAT_EMPTY'}) {
		$bj->slog("Nuking empty categories - this may take some time!");
		my %COUNTS = ();
		foreach my $safe ($nc->paths()) {
			next unless (substr($safe,0,1) eq '.');
			# print "PATH: $safe\n";

			my ($pretty,$children,$products,undef,$metaref) = $nc->get($safe);
			my $count = 0;
			if ($metaref->{'PROTECT'}) { $count++; }
			foreach my $pid (split(/\,/,$products)) { next if ($pid eq ''); $count++; }

		   # print Dumper($nc->get($path)); die();
		   my @nodes = split(/\./,$safe);
		   my $x = '';
		   foreach my $node (@nodes) {
		      next if ($node eq '');
		      $x = "$x.$node";
		      $COUNTS{$x} += $count;
		      }
		   }
	
		foreach my $k (keys %COUNTS) {
		   next unless ($COUNTS{$k}<=0);
		   delete $COUNTS{$k};
		   $nc->nuke($k);
		   }
		
		}

	## Resort any categories which may have changed.
	if (defined $optionsref->{'CAT_RESORT_NAVCATS'}) {
		$bj->slog("Resorting all navigation categories - this may take some time!");
		foreach my $path ($nc->paths()) {
			$nc->set( $path, products=>$nc->sort($path) );
			}
		}
	elsif (scalar(keys(%SORT_CATS)) > 0) {
		foreach my $path (keys %SORT_CATS) {
			$bj->slog("Resorting Category $path");
			$nc->set( $path, products=>$nc->sort($path) );
			}
		}

	$nc->save();
	undef $nc;
	}

1;
