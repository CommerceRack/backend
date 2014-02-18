#!/usr/bin/perl

use strict;

##
## orders.pl [SEARS]
##		./orders.pl type=orders user=patti prt=0
##	- GET orders from SEARS via API 
##	- upload tracking info back to SEARS 
##
##
use Date::Parse;
use XML::Simple;
use XML::Writer;
use Data::Dumper;
use URI::Escape;

use lib "/httpd/modules";
use SYNDICATION;
use SYNDICATION::SEARS;
use CART2;
use ZOOVY;
use LUSER::FILES;
use POSIX qw(strftime);
use LWP::UserAgent;
use HTTP::Headers;
use HTTP::Request;
use ORDER::BATCH;
use Text::CSV_XS;

## SEARS specific info
my $MKT_BITSTR = 3;	
my $syn_name = 'GOOGLEBASE';
my $DST = 'GOO';
my @USERS = (); 


##
## parameters: 
##		user=toynk 
##		prt=0 || profile=DEFAULT
##		type=tracking|orders
##			DEBUGORDER=####-##-#####
##		REDO=filename 
##			RECREATE=2009-01-1234 (will recreate the stuff in the order)
my %params = ();
foreach my $arg (@ARGV) {
	if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}


## CODE TO RESEND TRACKING FOR AN ORDER:
#my $so = SYNDICATION->new("designed2bsweet","","SRS");
#my $lm = LISTING::MSGS->new("brian");
#my ($o) = ORDER->new("designed2bsweet","2012-03-128401");
##print &trackingXMLforOrder($o,$lm);
#uploadTracking($so,$lm,OID=>'2012-03-128401');
#die();

## validate type
if ($params{'type'} eq 'tracking') {
	}
elsif ($params{'type'} eq 'orderstatus') {
	}
else {
	die("Try a valid type (ordersstatus, tracking)\n");
	}




## USER is defined, only run for this USER
if ($params{'user'} ne '')  {
	my $udbh = &DBINFO::db_user_connect($params{'user'});
	my $pstmt = "select ID,DOMAIN from SYNDICATION where USERNAME=".$udbh->quote($params{'user'});
	if ($params{'dst'}) { $pstmt .= " and DSTCODE=".$udbh->quote($params{'dst'}); }
	if ($params{'dbid'}) { $pstmt .= " and ID=".$udbh->quote($params{'dbid'}); }
	$pstmt .= " limit 1";

	my $sth = $udbh->prepare($pstmt);
	$sth->execute();	
	while( my ($ID,$DOMAIN) = $sth->fetchrow()) {
		if ($ID>0) {
			print STDERR "FOUND ID: $ID\n";
			push @USERS, [ $params{'user'}, $DOMAIN, $ID ];
			}
		}
	$sth->finish();
	&DBINFO::db_user_close();
	}
else {
	die("Cluster or specific user is required!");
	}


## run thru each USER 
foreach my $set (@USERS) {
	my ($USERNAME,$DOMAIN,$ID) = @{$set};
	## create LOGFILE for each USER/PROFILE
	## http://support.google.com/trustedstoresmerchant/bin/answer.py?hl=en&answer=2609890
	my ($lm) = LISTING::MSGS->new($USERNAME,'logfile'=>"~/googletrustedstores-%YYYYMM%.log");
	my ($so) = SYNDICATION->new($USERNAME,$DST,'DOMAIN'=>$DOMAIN,'ID'=>$ID);

 	my $ERROR = '';

	my $ts = time()-1;
	my $csv = Text::CSV_XS->new({'sep_char'=>"\t"});
	my $lines = 0;


	## deactivate, too many errors
	if ($so->get('ERRCOUNT')>1000) {
		ZOOVY::confess($so->username(),"Deactivated $syn_name syndication for $USERNAME due to >1000 errors\n".Dumper($so),justkidding=>1);
		$so->deactivate();
		}
	elsif ($so->get('.trusted_feed')==0) {
		$lm->pooshmsg("STOP|+Trusted feeds are disabled");
		}
	elsif ($so->get('.ftp_user') eq '' || $so->get('.ftp_pass') eq '')  {
		$lm->pooshmsg("ERROR|+Deactivated $syn_name synd due to blank username and/or password");
		$so->deactivate();
		}
	elsif ($so->get('.ftp_user') eq '' || $so->get('.ftp_pass') eq '')  {
		$lm->pooshmsg("ERROR|+Deactivated $syn_name synd due to blank username and/or password");
		$so->deactivate();
		}
	## send order status 
	elsif ($params{'type'} eq 'orderstatus') { 
		$lm->pooshmsg("INFO-ORDER|+Performing feed $params{'type'}");

		my $lastts = $so->get('ORDERS_LASTRUN_GMT');
		if ($lastts < time()-(86400*3)) {
			$lastts = time()-(86400*3);
			}
		my $orders = ORDER::BATCH::report($USERNAME,'PRT'=>$so->prt(),'TS'=>$lastts,'POOL'=>'DELETED');

		my $lines = 0;
		my $tmpfile = sprintf("/tmp/trustedstores-orderstatus-%s-%d.txt",$so->username(),$so->prt());
		open F, ">$tmpfile";
		my @cols = ();
		push @cols, "merchant order id";
		push @cols, "reason";
		$csv->combine(@cols);
		print F $csv->string()."\n";

		foreach my $set (@{$orders}) {
			my ($O2) = CART2->new_from_oid($USERNAME,$set->{'ORDERID'});
			next if (not defined $O2);

			my @cols = ();
			# Attribute Description
			# merchant order id Order ID number as sent in order confirmation module. This value should match the MERCHANT_ORDER_ID value passed to Google in the JavaScript.
			push @cols, $O2->oid();
			# reason Accepted values with this exact spelling are: BuyerCanceled, MerchantCanceled, DuplicateInvalid, FraudFake
			push @cols, "MerchantCanceled";
			$csv->combine(@cols);
			print F $csv->string()."\n";
			$lines++;			
			}
		close F;
	
		# $lm->pooshmsg("INFO-TRACK|Saving ORDERS_LASTRUN_GMT to ".ZTOOLKIT::pretty_date( time(),1 ) );		
		$so->set('ORDERS_LASTRUN_GMT',$ts);
		if ($lines>0) {
			print Dumper($tmpfile);
			$so->transfer_ftp('',[{'in'=>$tmpfile,'out'=>"orderstatus.txt"}]);
			}

		$lm->pooshmsg("INFO-ORDER|+Finished feed $params{'type'}");
		}
	## send tracking
	elsif ($params{'type'} eq 'tracking') { 
		$lm->pooshmsg("INFO-TRACK|+Performing feed $params{'type'}");
		$lm->pooshmsg("INFO-TRACK|Saving TRACKING_LASTRUN_GMT to ".ZTOOLKIT::pretty_date( time(),1 ) );		

		my $lastts = $so->get('TRACKING_LASTRUN_GMT');
		if ($lastts<time()-86400*15) { $lastts = time()-86400*15; }

		my $orders = ORDER::BATCH::report($USERNAME,'PRT'=>$so->prt(),'TS'=>$lastts,'SHIPPED_GMT'=>1,'CREATED_GMT'=>time()-(86400*30));

		my $tmpfile = sprintf("/tmp/trustedstores-tracking-%s-%d.txt",$so->username(),$so->prt());
		open F, ">$tmpfile";
		my @cols = ();
		push @cols, "merchant order id";
		push @cols, "tracking number";
		push @cols, "carrier code";
		push @cols, "other carrier name";
		push @cols, "ship date";
		$csv->combine(@cols);
		print F $csv->string()."\n";
		
		foreach my $set (@{$orders}) {
			print "ORDERID: $set->{'ORDERID'}\n";
			my ($O2) = CART2->new_from_oid($USERNAME,$set->{'ORDERID'},'CREATE'=>0);
			next if (not defined $O2);
			
			foreach my $track (@{$O2->tracking()}) {
				my @cols = ();
				# merchant order id	Order ID number as sent in Order Confirmation module. This value should match the MERCHANT_ORDER_ID value passed to Google in the JavaScript.
				push @cols, $O2->oid();
				# tracking number	Actual tracking number of the order. Leave this field blank if the order does not have a tracking number.
				push @cols, $track->{'track'};
				
				# carrier code	Accepted values: UPS, FedEx, USPS, Other. (UPS Mail Innovations should be noted with the UPS carrier code. FedEx Smartposts should be noted with the FedEx carrier code.)
				my $shipinfo = &ZSHIP::shipinfo($track->{'carrier'});
				my $carrier = $shipinfo->{'carrier'};
				if ($carrier eq 'FDX') {
					push @cols, "FedEx";
					push @cols, '';
					}
				elsif ($carrier eq 'UPS') {
					push @cols, "UPS";
					push @cols, '';
					}
				elsif ($carrier eq 'USPS') {
					push @cols, "USPS";
					push @cols, '';
					}
				else {
					push @cols, "Other";
					push @cols, 'OTHER';
					# ABF Freight Systems	ABFS
					# America West	AMWST
					# Bekins	BEKINS
					# Conway	CNWY
					# DHL	DHL
					# Estes	ESTES
					# Home Direct USA	HDUSA
					# LaserShip	LASERSHIP
					# Mayflower	MYFLWR
					# Old Dominion Freight	ODFL
					# Reddaway	RDAWAY
					# Team Worldwide	TWW
					# Watkins	WATKINS
					# Yellow Freight	YELL
					# YRC/td>	YRC
					# All Other Carriers	OTHER
					}
				# other carrier name	Only if .Other. is selected above. (Please include this attribute name in your header row, even if values are blank). See below for accepted values.

				# ship date	Actual ship date of the order. Format: YYYY-MM-DD (Timestamps are not required; however, if your system generates timestamps, please format as YYYY-MM-DDThh:mm:ss. Note the T delimiter.)
				my $shipped = $track->{'created'};
				if ($shipped == 0) { $shipped = $O2->in_get('flow/shipped_ts'); }
				if ($shipped == 0) { $shipped = time(); }
				push @cols, POSIX::strftime("%Y-%m-%d",localtime($shipped));

				$csv->combine(@cols);
				print F $csv->string()."\n";
				$lines++;
				}
			}
		close F;

		if ($lines>0) {
			$so->transfer_ftp('',[{'in'=>$tmpfile,'out'=>"tracking.txt"}]);
			}

		$so->set('TRACKING_LASTRUN_GMT',$ts);
		$so->save();
		$lm->pooshmsg("INFO-TRACK|+Finished feed $params{'type'}");
		}
	## unknown type
	else {
		$lm->pooshmsg("WARN|+Unknown feed type:$params{'type'}");
		}

	}



__DATA__

				my ($lf) = LUSER::FILES->new($so->username());
				$lf->add(
					buf=>$response_xml,
					type=>'SYNDICATION',
					title=>$local_file,
					meta=>{'DSTCODE'=>$DST,'PROFILE'=>$so->profile(),'TYPE'=>'SYNDICATION'},
					);
	
