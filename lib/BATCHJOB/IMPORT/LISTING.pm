package BATCHJOB::IMPORT::LISTING;

use strict;
use Data::Dumper;
use YAML::Syck;
use lib "/backend/lib";
require DBINFO;
require PRODUCT;
require LISTING::EVENT;


##
##
##
sub parse {
	my ($bj,$fieldsref,$lineref,$optionsref,$errorsref) = @_;

	my $CREATED_GMT = time();
	my ($USERNAME,$LUSERNAME,$PRT) = ($bj->username(),$bj->lusername(),$bj->prt());
	my $MID = &ZOOVY::resolve_mid($USERNAME);


	my $count = 0;
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	foreach my $line ( @{$lineref} ) {

		my $ERROR = undef;
		my %data = ();
		my %cols = ();
		my $pos = 0;
		foreach my $destfield (@{$fieldsref}) {	

			if ($destfield eq '') {
				# Skip blank fields
				}
			elsif ($destfield eq 'SKU') {
				$cols{'SKU'} = $line->[$pos];
				}
			elsif (($destfield eq 'PRODUCTID') || ($destfield eq 'PID') || ($destfield eq 'PRODUCT')) {
				$cols{'PRODUCT'} = $line->[$pos];
				}
			elsif ($destfield eq 'QTY') {
				$cols{'QTY'} = $line->[$pos];
				}
			elsif ($destfield eq 'TARGET') {
				$cols{'TARGET'} = LISTING::EVENT::normalize_target($line->[$pos]);
				}
			elsif (($destfield eq 'TARGET_LISTINGID') || ($destfield eq 'LISTINGID') || ($destfield eq 'LISTING_ID') || ($destfield eq 'EBAY_ID')) {
				$cols{'TARGET_LISTINGID'} = int($line->[$pos]);
				if ($destfield eq 'EBAY_ID') { $cols{'TARGET'} = 'EBAY'; }
				}
			elsif ($destfield eq 'VERB') {
				$cols{'VERB'} = uc($line->[$pos]);
				}
			elsif ($destfield eq 'TITLE') {
				$data{'ebay:title'} = uc($line->[$pos]);
				}
			elsif ((lc($destfield) eq $destfield) && ($destfield =~ /:/)) {
				## this is a zoovy attribute e.g. zoovy: space, or ebay:variable
				## eventually we should add some validation/whitelist of supported/allowed attributes
				$data{$destfield} = $line->[$pos];
				}
			else {
				$ERROR = "Unknown header[$destfield]";
				# die("Unknown destfield:$destfield\n");
				}
			$pos++;
			}

		## SANITY: at this point all fields have been sucked in, we might want to run a validation routine
		## 			or something eventually.  

		if (defined $ERROR) {
			## something bad happened and we won't be launching this.
			$bj->slog($ERROR);
			push @{$errorsref}, $ERROR;
			}	
		elsif (not defined $ERROR) {
			## SANITY: at this point we're good for launch.
			$cols{'USERNAME'} = $USERNAME;
			$cols{'LUSER'} = $LUSERNAME;
			$cols{'PRT'} = $PRT;
			$cols{'MID'} = $MID;
			$cols{'CREATED_GMT'} = $CREATED_GMT;

			## check we have SKU/PRODUCTID
			if ($cols{'SKU'} eq '') { $cols{'SKU'} = $cols{'PRODUCT'}; }
			if ($cols{'PRODUCT'} eq '') { 
				($cols{'PRODUCT'}) = &PRODUCT::stid_to_pid($cols{'SKU'});
				}
			$cols{'SKU'} =~ s/^[\s]+//;
			$cols{'SKU'} =~ s/[\s]+$//;
			$cols{'PRODUCT'} =~ s/^[\s]+//;
			$cols{'PRODUCT'} =~ s/[\s]+$//;
			$cols{'TARGET'} =~ s/^[\s]+//;
			$cols{'TARGET'} =~ s/[\s]+$//;
			$cols{'LAUNCH_GMT'} = $CREATED_GMT;
		
			$cols{'REQUEST_BATCHID'} = $bj->id();
			$cols{'REQUEST_APP'} = 'CSV';
			$cols{'REQUEST_APP_UUID'} = $count++;
			if (scalar(keys %data)>0) {
				$cols{'REQUEST_DATA'} = YAML::Syck::Dump(\%data);
				# YAML::Syck::Load($YAML);
				}
			$cols{'RESULT'} = 'PENDING';
	
			my $pstmt = DBINFO::insert($udbh,'LISTING_EVENTS',\%cols,sql=>1);
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			my ($ID) = $udbh->selectrow_array("select last_insert_id()");
			$bj->slog("SKU:$cols{'SKU'} LISTING-EVENT:$ID");
			}
		else {
			&ZOOVY::confess($USERNAME,"This line should NEVER be reached (we didn't launch, we didn't error)");
			}
		}

	&DBINFO::db_user_close();
	}


1;