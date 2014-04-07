package BATCHJOB::IMPORT::REVIEW;

use strict;
use Data::Dumper;
use YAML::Syck;
use lib "/backend/lib";
require DBINFO;


##
## valid fields
## 
## %FULL_NAME 			=> doesnt appear that reviews link back to customer table
## %LOCATION			=> geographical location
## %PID					=> reviews are product-based (vs sku-based)
## %SUBJECT
## %MESSAGE
## %USEFUL_YES			=> how many customers found this review helpful
## %USEFUL_NO			=> how many did not
## %RATING				=> how many out of 10 (10 is the highest)
## %BLOG_URL			=> 
## %APPROVED_DATE		=> when review approved (defaults to 0), YYYY-MM-DD
##
##	note: 
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
			elsif ($destfield eq '%FULL_NAME') {
				$cols{'CUSTOMER_NAME'} = $line->[$pos];
				}
			elsif ($destfield eq '%LOCATION') {
				$cols{'LOCATION'} = $line->[$pos];
				}
			elsif (($destfield eq '%PRODUCTID') || ($destfield eq '%PID') || ($destfield eq '%PRODUCT')) {
				$cols{'PID'} = $line->[$pos];
				}
			elsif ($destfield eq '%SUBJECT') {
				$cols{'SUBJECT'} = $line->[$pos];
				}
			elsif ($destfield eq '%MESSAGE') {
				$cols{'MESSAGE'} = $line->[$pos];
				}
			elsif ($destfield eq '%USEFUL_YES') {
				$cols{'USEFUL_YES'} = $line->[$pos];
				}
			elsif ($destfield eq '%USEFUL_NO') {
				$cols{'USEFUL_NO'} = $line->[$pos];

				}
			elsif ($destfield eq '%RATING') {
				$cols{'RATING'} = $line->[$pos];
				}
			elsif ($destfield eq '%BLOG_URL') {
				$cols{'BLOG_URL'} = $line->[$pos];
				}
			elsif ($destfield eq '%APPROVED_DATE') {
				$cols{'APPROVED_DATE'} = $line->[$pos];
				}
			else {
				$ERROR = "Unknown header[$destfield]";
				# die("Unknown destfield:$destfield\n");
				}
			$pos++;
			}

	
		## set DEFAULTs
		if ($cols{'USEFUL_YES'} eq '') { $cols{'USEFUL_YES'} = 0; }
		if ($cols{'USEFUL_NO'} eq '') { $cols{'USEFUL_NO'} = 0; }
		if ($cols{'APPROVED_DATE'} eq '') {	$cols{'APPROVED_DATE'} = 0; }
		if ($cols{'CUSTOMER_NAME'} eq '') { $cols{'CUSTOMER_NAME'} = "Anonymous"; }


		## VALIDATION
		###########
		if ($cols{'PID'} eq '') {
			$ERROR = "Product is required.";
			}
		elsif ($cols{'CUSTOMER_NAME'} eq '') {
			$ERROR = "Customer name is required.";	
			}
		#elsif ($cols{'SUBJECT'} eq '') {
		#	$ERROR = "Review Subject is required.";	
		#	}
		#elsif ($cols{'MESSAGE'} eq '') {
		#	$ERROR = "Review Message is required.";	
		#	}
		elsif ($cols{'USEFUL_YES'} !~ /^(\d+)$/) {
			$ERROR = "Useful Yes must be a number or left blank [".$cols{'USEFUL_YES'}."]" ;
			}
		elsif ($cols{'USEFUL_NO'} !~ /^(\d+)$/) {
			$ERROR = "Useful No must be a number or left blank [".$cols{'USEFUL_NO'}."]";
			}
		elsif ($cols{'RATING'} !~ /^(1|2|3|4|5|6|7|8|9|10)$/) {
			$ERROR = "Rating must be a number from 1 to 10";
			}
		elsif ($cols{'APPROVED_DATE'} != 0 && $cols{'APPROVED_DATE'} !~ /^(\d\d\d\d)-(\d\d)-(\d\d)/) {
			$ERROR = "Approved date should either be left blank or in format YYYY-MM-DD";
			}


		## SANITY: at this point all fields have been sucked in, we might want to run a validation routine
		## 			or something eventually.  

		if (defined $ERROR) {
			## something bad happened and we won't be launching this.
			$bj->slog($ERROR);
			}	
		elsif (not defined $ERROR) {
			## SANITY: at this point we're good for launch.
			$cols{'USERNAME'} = $USERNAME;
			#$cols{'LUSER'} = $LUSERNAME;
			#$cols{'PRT'} = $PRT;
			$cols{'MID'} = $MID;
			$cols{'CREATED_GMT'} = $CREATED_GMT;

			## take spaces out of PRODUCTID
			$cols{'PID'} =~ s/^[\s]+//;
			$cols{'PID'} =~ s/[\s]+$//;

			$cols{'APPROVED_GMT'} = ZTOOLKIT::mysql_to_unixtime($cols{'APPROVED_DATE'});				
			delete $cols{'APPROVED_DATE'};
			
			my $pstmt = DBINFO::insert($udbh,'CUSTOMER_REVIEWS',\%cols,sql=>1);
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			}
		else {
			&ZOOVY::confess($USERNAME,"This line should NEVER be reached (we didn't launch, we didn't error)");
			}
		}

	&DBINFO::db_user_close();
	}


1;