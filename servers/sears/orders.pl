#!/usr/bin/perl

use strict;


##
## NOTE: sears requies SSLv3 connections to it's webserver. look at $ua->ssl_opts 
##

##
## orders.pl [SEARS]
##		./orders.pl type=orders user=patti prt=0
##	- GET orders from SEARS via API 
##	- upload tracking info back to SEARS 
##
##


##
## DOCS:
## http://searsmarketplace.force.com/knowledgeProduct?c=XML&k=
## 

use Date::Parse;
use XML::Simple;
use XML::Writer;
use Data::Dumper;
use URI::Escape::XS;
use YAML::Syck;
$YAML::Syck::ImplicitBinary++;
$YAML::Syck::ImplicitUnicode++;
$YAML::Syck::SingleQuote++;		# do not fucking enable this. it has issues with cr/lf 183535

use lib "/httpd/modules";
use SYNDICATION;
use SYNDICATION::SEARS;
use STUFF2;
use CART2;
use ZOOVY;
use LUSER::FILES;
use POSIX qw(strftime);
use LWP::UserAgent;
use HTTP::Headers;
use HTTP::Request;
use ZSHIP;

## SEARS specific info
my $MKT_BITSTR = 3;	
my $DST = 'SRS';
my $PS = '021';
my $sdomain = 'sears.com';
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

if ($params{'user'} eq '') {
	die("user= is required");
	}

if ($params{'debug'}) {
	}
else {
#	die();
	}
## validate type
if (($params{'type'} ne '') && ($params{'verb'} eq '')) { $params{'verb'} = $params{'type'}; }
if ($params{'verb'} eq 'tracking') {
	}
elsif ($params{'verb'} eq 'orders') {
	}
elsif ($params{'verb'} eq 'docs') {
	}
else {
	die("Try a valid type (orders, tracking, docs, credit)\n");
	}

## USER is defined, only run for this USER
#if (not defined $params{'cluster'}) {
#	die("cluster= or user= is required");
#	}

#my $udbh = &DBINFO::db_user_connect("\@$params{'cluster'}");
my $udbh = &DBINFO::db_user_connect($params{'user'});
my $pstmt = "select USERNAME,DOMAIN,ID,ERRCOUNT from SYNDICATION where DSTCODE='".$DST."'";
	if ($params{'user'}) { $pstmt .= " and MID=".&ZOOVY::resolve_mid($params{'user'}); }
	print STDERR $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($USERNAME,$DOMAIN,$ID,$ERRCOUNT) = $sth->fetchrow() ) {
		if ($ERRCOUNT>10) {
			print STDERR "USER:$USERNAME DOMAIN:$DOMAIN ID:$ID was skipped due to ERRCOUNT=$ERRCOUNT\n";
			}
		else {
			push @USERS, [ $USERNAME, $DOMAIN, $ID ];
			print STDERR "USERNAME: $USERNAME $DOMAIN\n";
			}
		}
	$sth->finish();


## run thru each USER 
foreach my $set (@USERS) {
	my ($USERNAME,$DOMAIN,$ID) = @{$set};

	## create LOGFILE for each USER/PROFILE
	my ($lm) = LISTING::MSGS->new($USERNAME,'logfile'=>"~/sears-%YYYYMM%.log");
	my ($so) = SYNDICATION->new($USERNAME,$DST,'DOMAIN'=>$DOMAIN,'ID'=>$ID);

 	my $ERROR = '';

	## deactivate, too many errors
	if (not &DBINFO::task_lock($USERNAME,"sears-".$params{'verb'},(($params{'unlock'})?"PICKLOCK":"LOCK"))) {
		$lm->pooshmsg("STOP|+Could not obtain opportunistic lock");
		}
	elsif ($so->get('ERRCOUNT')>1000) {
		ZOOVY::confess($so->username(),"Deactivated SEARS syndication for $USERNAME due to >1000 errors\n".Dumper($so),justkidding=>1);
		$lm->pooshmsg("ERROR|+Deactivated SEARS synd due to too many errors");
		$so->deactivate();
		}
	elsif ($so->get('.user') eq '' || $so->get('.pass') eq '')  {
		$lm->pooshmsg("ERROR|+Deactivated SEARS synd due to blank username and/or password");
		$so->deactivate();
		}

	if (not $lm->can_proceed()) {
		}
	elsif ($params{'verb'} eq 'orders') { 
		## DOWNLOAD Orders
		$lm->pooshmsg("INFO-ORDER|+Performing feed $params{'verb'}");
		(my $orderref) = &downloadOrders($so, $lm, %params);
		if ($lm->has_win()) {
			$lm->pooshmsg("INFO-ORDER|+Finished feed $params{'verb'}");
			$so->set('ORDERS_LASTRUN_GMT',time());
			}
		$so->save();
		}
	elsif ($params{'verb'} eq 'tracking') { 
		## send tracking
		$lm->pooshmsg("INFO-TRACK|+Performing feed $params{'verb'}");
		&uploadTracking($so, $lm, %params);
		if ($lm->has_win()) {
			$lm->pooshmsg("INFO-TRACK|Saving TRACKING_LASTRUN_GMT to ".ZTOOLKIT::pretty_date( time(),1 ) );		
			$so->set('TRACKING_LASTRUN_GMT',time());
			}
		$so->save();
		$lm->pooshmsg("INFO-TRACK|+Finished feed $params{'verb'}");
		}
	elsif ($params{'verb'} eq 'docs') {
		## not really sure what this does.
		my $pstmt = "select DOCID from SEARS_DOCS where MID=".$so->mid()." and PRT=".$so->prt();
		if ($params{'docid'}>0) {
			$pstmt .= " and DOCID=".int($params{'docid'});
			}
		else {
			$pstmt .= " and PROCESSED_TS=0 order by ID desc limit 0,1";
			}
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($DOCID) = $sth->fetchrow() ) {
			my ($xml) = &get_docid($so,$DOCID,$lm);

			print "XML: $xml\n";	
			#die();
		
			my ($response) = XML::Simple::XMLin($xml,ForceArray=>1,ContentKey=>'_');		
			#$lm->pooshmsg("INFO-TRACK|+errorref: ".Dumper($response));
		
			## this doesnt really work! docid just arent processed quickly enough to get results
		
			## if ERROR
			my $RESULT = "ERROR|+$response->{'report'}[0]->{'detail'}[0]->{'errors'}[0]->{'error'}[0]->{'error-info'}[0]";
			if ($RESULT eq '') {
				}
			elsif (not defined $response->{'report'}) {
				$RESULT = "ISE|+UNKNOWN/UNPROCESSABLE RESPONSE";
				}
			else {
				# ($response->{'report'}[0]->{'summary'}[0]->{'records-with-errors'}[0]>0) {
				$RESULT = sprintf("INFO|+type:%s total:%d accepted:%d warnings:%d errors:%d",
					$response->{'report'}[0]->{'summary'}[0]->{'description'}[0],
					$response->{'report'}[0]->{'summary'}[0]->{'record-count'}[0],
					$response->{'report'}[0]->{'summary'}[0]->{'records-accepted'}[0],
					$response->{'report'}[0]->{'summary'}[0]->{'records-with-errors'}[0],
					$response->{'report'}[0]->{'summary'}[0]->{'records-with-warnings'}[0]
					);
				}

			my $qtRESULT = $udbh->quote($RESULT);
			my $pstmt = "update SEARS_DOCS set RESULT=$qtRESULT,PROCESSED_TS=now() where DOCID=$DOCID";
			print STDERR "$pstmt\n";
			$udbh->do($pstmt);
			}
		$sth->finish();
		}
	else {
		## unknown type
		$lm->pooshmsg("WARN|+Unknown feed type:$params{'verb'}");
		}

	&DBINFO::task_lock($USERNAME,"sears-".$params{'verb'},"UNLOCK");
	}

&DBINFO::db_user_close();





##
## - find all orders with new tracking info
##	- create XML 
##	
##	valid params
##		=> DEBUGORDER
##
sub uploadTracking {
	my ($so, $lm, %params) = @_;

	my $ERROR = '';
	my $USERNAME = $so->username();
	my $output = '';

	## this is a really bad way to do this.
	## https://admin.zoovy.com/support/index.cgi?ACTION=VIEWTICKET&TICKET=479994&USERNAME=designed2bsweet


	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	## return all SEARS orders that have been shipped since tracking was last sent
	require ORDER::BATCH;
	#my ($list) = ORDER::BATCH::report($USERNAME,MKT_BIT=>$MKT_BITSTR,SHIPPED_GMT=>$so->get('TRACKING_LASTRUN_GMT'),PAID_GMT=>time()-(60*86400));
	## changed the query to look for last modified_gmt (TS) and also SHIPPED_GMT > 1
	## - this should resolve the issue we were having with merchants adding tracking to orders, syncing many hours later, and code missing order
	my @ORDERLIST = ();
	my ($redis) = &ZOOVY::getRedis($USERNAME,1);
	my $REDISQUEUE = uc(sprintf("EVENTS.ORDER.SHIP.%s.%s",$so->dst(),$so->username()));
	if (defined $params{'OID'}) {
		## to resend a specific ORRDER send OID
		push @ORDERLIST, $params{'OID'};
		}
	else {
		my ($length) = $redis->llen($REDISQUEUE);
		if ($length > 0) {
			@ORDERLIST = $redis->lrange($REDISQUEUE,0,250);
			}
		}
	#if (not defined $list) {
	#	$list = ORDER::BATCH::report($USERNAME,
	#		'MKT_BIT'=>$MKT_BITSTR,
	#		'TS'=>$so->get('TRACKING_LASTRUN_GMT'),
	#		'PAID_GMT'=>time()-(60*86400),
	#		'SHIPPED_GMT'=>1);
	#	}

	# $lm->pooshmsg("INFO-TRACK|+getting orders for SHIPPED_GMT >= ".$so->get('TRACKING_LASTRUN_GMT')." and <= ".time());
	$lm->pooshmsg(sprintf("INFO-TRACK|+Found %d orders for TS>%s (%s) and MKT_BITSTR=%s",
		scalar(@ORDERLIST),
		ZTOOLKIT::pretty_date($so->get('TRACKING_LASTRUN_GMT'),1),
		$so->get('TRACKING_LASTRUN_GMT'),
		$MKT_BITSTR ));

	if ($params{'DEBUGORDERl'}) {
		my $found = 0;
		foreach my $ORDERID ( @ORDERLIST ) {
			if ($params{'DEBUGORDER'} eq $ORDERID) { $found++; }
			}
		if (not $found) {
			die("ORDER: $params{'DEBUGORDER'} not in current list of orders to send.");
			}
		}

	

	## only send one feed per order
	foreach my $REDISELEMENT (@ORDERLIST) 
{
		## REDISELEMENT is:
		##		ORDERID					2012-01-1234
		##		ORDERID#ATTEMPTS		2012-01-1234#1
		my ($ORDERID,$ATTEMPTS) = split(/\#/,$REDISELEMENT);
		if (not defined $ATTEMPTS) { $ATTEMPTS = 0; }
		$ATTEMPTS++;

		my $SUCCESS = 0;
		my ($O2) = CART2->new_from_oid($USERNAME,$ORDERID);
		my $erefid = $O2->in_get('mkt/erefid');	

		## SANITY: at this point @TRACKING is an array of tracking #'s
		if ($erefid eq '') {
			$lm->pooshmsg("WARN-TRACK|+$erefid erefid ($sdomain receipt-id) is not set (attempt $ATTEMPTS)");
			}
		elsif ($O2->in_get('flow/shipped_ts')==0) {
			$lm->pooshmsg("WARN-TRACK|+".$O2->oid()." is not flagged as shipped. (attempt $ATTEMPTS)");
			}
		elsif (scalar(@{$O2->tracking()})==0) {
			$lm->pooshmsg("WARN-TRACK|+".$O2->oid()." no tracking in order. (attempt $ATTEMPTS)");
			}
		else {
			$lm->pooshmsg("INFO-TRACK|+sending tracking #$ATTEMPTS for erefid: $erefid orderid: ".$O2->oid());

			my $request_xml = &trackingXMLforOrder($O2,$lm);
			# open F, ">/tmp/sears-track.xml";	print F $request_xml; close F; die();

			my %ref = ();
			$ref{'@ORDERS'} = ();
			push @{$ref{'@ORDERS'}}, $O2->oid();

			### SANITY: XML is defined, time to for API call
			## CREDENTIALS	
			my $user = $so->get('.user');
			$user = URI::Escape::XS::uri_escape($user);
			my $pass = $so->get('.pass');
			$pass = URI::Escape::XS::uri_escape($pass);

			my $URL = "https://seller.marketplace.sears.com/SellerPortal/api/oms/asn/v1?email=$user&password=$pass";
			my $length = length($request_xml);
			my $header = HTTP::Headers->new('Content-Length' => $length, 'Content-Type' => 'application/xml', 'connection'=>'close', 'date' => 'Wed, 08 Dec 2010 21:43:29 GMT',);
			my $request = HTTP::Request->new("PUT", $URL, $header, $request_xml);

#			my $ua = LWP::UserAgent->new();
#			$ua->ssl_opts(
#				'SSL_version'=>'SSLv3',
#				'verify_hostname' => 0 
#				);
			my ($ua) = LWP::UserAgent->new(ssl_opts=>{"verify_hostname"=>0,"SSL_version"=>"SSLv3"});

			my $response = $ua->request($request);
			my $response_xml = $response->content;

			my $responseref = XML::Simple::XMLin($response_xml,ForceArray=>1,ContentKey=>'_');
			print "TRACK RESPONSE [".$O2->oid()." : $erefid]\n". Dumper($responseref);
			## if a docid exists, let's get the full submittal report
			if ($responseref->{'document-id'}[0] ne '') {
				my $docid = $responseref->{'document-id'}[0];
				$lm->pooshmsg("INFO-TRACK|+Received docid: ".$docid);

				## NOT SURE WHY WE DO IT THIS WAY!
				my $YAML = YAML::Syck::Dump({'@ORDERS'=>[$O2->oid()]});
				my ($pstmt) = &DBINFO::insert($udbh,'SEARS_DOCS',{
					'MID'=>$so->mid(),
					'PRT'=>$so->prt(),
					'DOCID'=>$docid,
					'DOCTYPE'=>'track',
					'*CREATED_TS'=>'now()',
					'YAML'=>$YAML,
					},'verb'=>'insert',sql=>1);
				print "$pstmt\n";	
				$udbh->do($pstmt);

				if ($docid ne '') {
					## we only confirm/remove if we got a docid from sears
					$SUCCESS++;
					}

				if ($ERROR ne '') { $ERROR = "DOCID: $docid ".$ERROR; }
				}
			elsif ($responseref->{'error-detail'}[0] ne '') {
				## otherwise, there's an error in the submittal (ill-formed XML, etc)
				$ERROR = $responseref->{'error-detail'}[0];
				}
			$output .= "#######\ntracking-feed for ".$O2->in_get('mkt/erefid')."[".$O2->oid()."]\n$request_xml\n$response_xml\n";			

			if ($ERROR ne '') {
				$output .= "ERROR\n$ERROR\n";
				#$lm->pooshmsg("ERROR|+Tracking error occured for order: ".$o->id()."po-number: $erefid $ERROR");
				$lm->pooshmsg("WARN|+Tracking error occured for order: ".$O2->oid()."po-number: $erefid $ERROR (attempt $ATTEMPTS)");
				}
			}
		
		if ((not $SUCCESS) && ($ATTEMPTS>3)) {
			$lm->pooshmsg("WARN|+too many attempts - removing from queue");
			$redis->lrem($REDISQUEUE,0,"$REDISELEMENT");
			}
		elsif ($SUCCESS) {
			$redis->lrem($REDISQUEUE,0,"$REDISELEMENT");
			}
		else {
			## insert overly elaborate retry protocol here
			$redis->rpush($REDISQUEUE,"$ORDERID#$ATTEMPTS");
			$redis->lrem($REDISQUEUE,0,"$REDISELEMENT");	
			}
		}


	if ($output ne '') {
		my $DATE = strftime("%Y%m%d%H%M%S",localtime(time()));
		my $local_file = "SEARSTrack".$DATE.".txt";
		## store the file to private files.
		my ($lf) = LUSER::FILES->new($USERNAME, 'app'=>'SEARS');
		$lf->add(
			buf=>$output,
			type=>$DST,
			title=>$local_file,
			meta=>{'DSTCODE'=>$DST,'TYPE'=>$params{'type'}},
			);
		$lm->pooshmsg("INFO-TRACK|+tracking xml written to private file [$local_file]");
		}
	else {
		}

	&DBINFO::db_user_close();
	return();
	}


##
## - download the most recent orders from SEARS
##	-- all NEW orders from yesterday to today
##	- create orderref from XML
##	- assign values to CART
##	- use CART to create order
##
##	VIEW AN ORDER:
## https://seller.marketplace.sears.com/SellerPortal/api/oms/purchaseorder/v4?email=dropship@downlite.com&password=3696lite&status=New
##
sub downloadOrders {
	my ($so, $lm, %params) = @_;

	my $USERNAME = $so->username();
	my $ORDERTS = 0;
	my @ORDERSXML = ();

	my $user = $so->get('.user');
	$user = URI::Escape::XS::uri_escape($user);
	my $pass = $so->get('.pass');
	$pass = URI::Escape::XS::uri_escape($pass);
#	my $ua = LWP::UserAgent->new();
#	$ua->ssl_opts(
#		"SSL_version"=>"SSLv3",
#		"verify_hostname" => 0 
#		);
	# my $ua = LWP::UserAgent->new(agent=> 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)');
	my ($ua) = LWP::UserAgent->new(ssl_opts=>{"verify_hostname"=>0,"SSL_version"=>"SSLv3"});
	my $ORDERSXML = undef;

	$lm->{'STDERR'} = 1;

	my $DOCID = '';

	## create order if no $ERROR
	if (not $lm->can_proceed()) {
		}
	elsif ($params{'REDO'} ne '') {
		## recreate order from existing file: REDO
		$lm->pooshmsg("INFO-REDO|+create orders for file: ".$params{'REDO'});
		$DOCID = substr($params{'REDO'},rindex($params{'REDO'},"/")+1);
		## redo an import (perhaps there was an issue?)
		open F, "<$params{'REDO'}";
		$/ = undef; my ($str) = <F>; $/ = "\n";
		close F;
		$ORDERSXML = $str;
		if ($ORDERSXML eq '') { $lm->pooshmsg("STOP|No xml in REDO file"); }
		}
	else {
		## use XML returned from get
		## CREDENTIALS	
			
		## values used to get order data
		## default 60 days ago, if this merchant has never successfully downloaded orders
		##		and ORDERS_LASTRUN_GMT has therefore not been set yet
		##		(previously used 1969-12-31 and orders were not returned!!)
		my $FROM_DATE = strftime("%Y-%m-%d",localtime( time()-(60*86400) ));		
	
		## otherwise use the last time this process was run
		my $orders_lastrun_gmt = $so->get('ORDERS_LASTRUN_GMT');
		if ($orders_lastrun_gmt > 0) {
			$FROM_DATE = strftime("%Y-%m-%d",localtime($orders_lastrun_gmt)); 
			}
				
		my $TO_DATE = strftime("%Y-%m-%d",localtime(time()));
		my $STATUS = 'NEW';

		my $URL = "https://seller.marketplace.sears.com/SellerPortal/api/oms/purchaseorder/v4".
			 		 "?email=$user&password=$pass&fromdate=$FROM_DATE&todate=$TO_DATE&status=$STATUS";

		$lm->pooshmsg("INFO|+get URL: $URL");
		$lm->pooshmsg("INFO|+getting $STATUS order info for $FROM_DATE to $TO_DATE");
			
		my $response = $ua->get($URL);	
		$ORDERSXML = $response->content;


		## ERROR returned by SEARS
		if ($ORDERSXML =~ /<title>Sears Server Error<\/title>/s) {	
			$lm->pooshmsg("STOP|+Sears appears to be down for a little while (saw unstructured server error)");
			}
		elsif ($ORDERSXML eq '') {
			$lm->pooshmsg("ERROR|+blank API response in purchaseorder request from sears");
			}
		elsif ($ORDERSXML =~ /error-detail/) {
			my ($errorref) = XML::Simple::XMLin($ORDERSXML,ForceArray=>1,ContentKey=>'_');
			#print Dumper($errorref);
			
			if ($errorref->{'error-detail'}[0] eq 'No POs found') {
				$lm->pooshmsg("STOP|+No POs found");
				}
			else {	
				$lm->pooshmsg("ERROR|+ERROR in XML returned by SEARS [".$errorref->{'error-detail'}[0]."]");
				}
			$ORDERSXML = undef;
			}
			
		if ($lm->can_proceed()) {			
			## store the file
			my $DATE = strftime("%Y%m%d%H%M",localtime(time()));
			$DOCID = "SEARSOrder".$DATE.".xml";

			$lm->pooshmsg("INFO-ORDER|+order response xml written to private file [$DOCID]");

			## store the output XML to a private files\
			my ($lf) = LUSER::FILES->new($so->username(), 'app'=>'SEARS');
			$lf->add(
				buf=>$ORDERSXML,
				type=>$DST,
				title=>$DOCID,
				meta=>{'DSTCODE'=>$DST,'TYPE'=>$params{'type'}},
				);
			}
		} ## end of else

	##
	## SANITY: at this stage we have  @ORDERSXML = ( [ $filename, $xmlcontents ] );
	##

	my @ACK_PLEASE = ();	# an array of [ searspo1#, zoovy order1#, date1 ], [ searspo2#, zoovy order2#, date2 ]

	if (not $lm->can_proceed()) {
		}
	elsif ($DOCID eq '') {
		$lm->pooshmsg("ISE|+NO DOCID SET");
		}
	elsif ((not defined $ORDERSXML) || ($ORDERSXML eq '')) {
		$lm->pooshmsg("ISE|+ORDERSXML is empty or blank");
		}
	else {
		my $lc = 0;		# line count
		my ($orderref) = XML::Simple::XMLin($ORDERSXML,ForceArray=>1,ContentKey=>'_');

		foreach my $order (@{$orderref->{'purchase-order'} }) {
			my ($olm) = LISTING::MSGS->new($USERNAME,'stderr'=>1);

			my $erefid = $order->{'po-number'}[0];
			my ($ordsumref) = $so->resolve_erefid($erefid);

			my $previous_orderid = undef;	
			if (defined $ordsumref) {
				$previous_orderid = $ordsumref->{'ORDERID'};
				$olm->pooshmsg("STOP|+It appears $erefid is already created as ".$ordsumref->{'ORDERID'});
				}
			else {
				$olm->pooshmsg("INFO|+erefid $erefid appears to be a new order");
				}
			## these lines are helpful, they stop me from being an idiot.	
			next if ((defined $previous_orderid) && (not defined $params{'REDO'}) && (not defined $params{'RECREATE'}));
			next if ((defined $previous_orderid) && ($params{'RECREATE'} ne $previous_orderid)); 

			$olm->pooshmsg("INFO|+Time to create order for $erefid");

			my ($O2) = CART2->new_memory($USERNAME);
			my @EVENTS = ();
			my %cart2 = ();
			tie %cart2, 'CART2', 'CART2'=>$O2;
	
			# $cart2{'our/profile'} = $so->profile();
		   $cart2{'our/domain'} = $sdomain;
			$cart2{'mkt/erefid'} = $erefid;
			$cart2{'mkt/expected_ship_date'} = $order->{'expected-ship-date'}[0];
			$cart2{'is/origin_marketplace'} = 1;		# allows the marketplace to override store values
			$cart2{'flow/payment_method'} =  'SEARS';
			$cart2{'flow/payment_status'} = $PS; 
			$cart2{'mkt/docid'} = $DOCID;
			$cart2{'mkt/sears_orderid'} = $erefid;
			## no balance due, we are adding payment further down in code, dont need ZPAY to handle
			$cart2{'must/payby'} = 'ZERO'; 		
			$cart2{'want/order_notes'} = "SEARS Order # ".$erefid;				

			$cart2{'bill/email'} = $order->{'customer-email'}[0];
			$cart2{'bill/phone'} = $order->{'shipping-detail'}[0]->{'phone'}[0];

			($cart2{'bill/firstname'}, $cart2{'bill/lastname'}) = split(/[\s]+/,$order->{'customer-name'}[0],2);
			($cart2{'ship/firstname'}, $cart2{'ship/lastname'}) = split(/[\s]+/,$order->{'shipping-detail'}[0]->{'ship-to-name'}[0],2);
			
			$cart2{'ship/phone'} = $order->{'shipping-detail'}[0]->{'phone'}[0];
			$cart2{'ship/address1'} = $order->{'shipping-detail'}[0]->{'address'}[0];
			$cart2{'ship/city'} = $order->{'shipping-detail'}[0]->{'city'}[0];
			$cart2{'ship/region'} = $order->{'shipping-detail'}[0]->{'state'}[0];
			$cart2{'ship/postal'} = $order->{'shipping-detail'}[0]->{'zipcode'}[0];
			$cart2{'ship/countrycode'} = 'US';
 		
			my $CREATED = Date::Parse::str2time($order->{'po-date'}[0]);
			$cart2{'mkt/sears_po_date'} = $CREATED;
			$olm->pooshmsg("INFO-ORDER|+order po-date: ".$order->{'po-date'}[0]." CREATED: $CREATED ");
			if ($CREATED>$ORDERTS) { $ORDERTS = $CREATED; } 	# keep a high watermark for order timestamps.

			## add items to cart
			# my ($s2) = STUFF2->new($USERNAME);
			# $CART->stuff();
			my ($s2) = $O2->stuff2();

			## populate item_hashref, to get unique SKUs from SEARS order
			## sears has legacy "bug" that sends multiple lines for an item with qty > 1
			## - Zoovy system automatically only adds the first line (with qty=1)
			## --- FIX => use hashref
			## 2011-05-10
			my %ITEMS = ();
			foreach my $poline (@{$order->{'po-line'}}) {
			 	foreach my $searspoline (@{$poline->{'po-line-header'}}) {	
					my $sku = ZOOVY::from_safesku($searspoline->{'item-id'}[0]); ## convert -- to :
					my $mktid = sprintf("%dqty%d",$searspoline->{'line-number'}[0],$searspoline->{'order-quantity'}[0]);

					## BH: i've attemped to cleanup PM fuck ups with mktid best i could, it needs a new rewrite.
					## changed to deal with line number and qty - 2011-12-07
					## ie some orders will have multiple lines for the same sku and each line may have a qty >=1
					## 	- new format mktid => '1qty4:5qty1' -> line 1 has qty 4, line 5 has qty 1

					if (defined $ITEMS{$sku}) {
						## we've already got this summary item from a previous line
						## so we need to appned it's LINE#qtyQTY# to the summary
						my $summaryref = $ITEMS{$sku};
						$summaryref->{'mktid'} = sprintf('%s:%s',$summaryref->{'mktid'},$mktid);
						$summaryref->{'qty'} = $summaryref->{'qty'} + $searspoline->{'order-quantity'}[0];
						}
					else {
						## new summary record, add it.
						my %summary = ();
						$summary{'sku'} = $sku;
						$summary{'prod_name'} = $searspoline->{'item-name'}[0];
						$summary{'price'} = $searspoline->{'selling-price-each'}[0];
						$summary{'qty'} = $searspoline->{'order-quantity'}[0];
						## tracking upload uses line numbers ex: "1:3" or "5"
						$summary{'mktid'} = $mktid;
						$ITEMS{$sku} = \%summary;
						}
					}
				}
		
			## go thru each unique SKU in the order, qty's have already been computated
			foreach my $summaryref (values %ITEMS) {
				my $SKU = $summaryref->{'sku'};
				my ($P) = PRODUCT->new($USERNAME,$SKU,'create'=>0);
				#my ($prodref) = &ZOOVY::fetchsku_as_hashref($USERNAME,$SKU);
				#my $prod_name = $summaryref->{'prod_name'};
				#if (defined $prodref) {					
				#	if ($SKU =~ /:/) { POGS::apply_options($USERNAME,$SKU,$prodref); }
				#	$prod_name = $prodref->{'zoovy:prod_name'};
				#	}
				#if ($prod_name eq '') { 
				#	$prod_name = "$SKU not set";
				#	}
		
				print "SKU:$SKU\n";
				my $item = undef;
				if (not defined $P) {
					$olm->pooshmsg("WARN|+SKU:$SKU does not exist, adding as basic");
					($item) = $s2->basic_cram( $SKU, $summaryref->{'qty'}, $summaryref->{'price'}, $summaryref->{'prod_name'}, 
						'mkt'=>$item->{'mkt'},
						'mktid'=>$item->{'mktid'}
						);
					}
				else {
					my @suggestions = @{$P->suggest_variations('stid'=>$SKU,'guess'=>1)};
					foreach my $suggestion (@suggestions) {
						if ($suggestion->[4] eq 'guess') {
							$olm->pooshmsg("WARN|+SKU '$SKU' variation '$suggestion->[0]' was set to guess '$suggestion->[1]' because it was not specified by sears");
							}
						}
					my $variations = STUFF2::variation_suggestions_to_selections(\@suggestions);
					($item,my $oilm) = $s2->cram( $P->pid(), $summaryref->{'qty'}, $variations, 
						force_qty=>$summaryref->{'qty'}, 
						force_price=>$summaryref->{'price'}
						);
					$item->{'prod_name'} = $summaryref->{'prod_name'};
					$item->{'mkt'} = 'SRS';
					$item->{'mktid'} = $summaryref->{'mktid'};
					$olm->merge($oilm);
					}

				#my ($ERROR, my $msg) = $s->legacy_cram({ 
				#	mkt=>$DST,
				#	sku=>$SKU,
				#	# auto_detect_options=>$SKU,
				#	qty=>$summaryref->{'qty'},
				#	force_qty=>$summaryref->{'qty'},
				#	base_price=>$summaryref->{'base_price'},
				#	mktid=>$summaryref->{'mktid'},
				#	full_product=>$prodref,
				#	prod_name=>$prod_name,
				#	},'make_pogs_optional'=>1,'auto_detect_options'=>1);
				#

				#if ($ERROR) {
				#	if ($msg eq 'could not lookup pogs') {
				#		$msg = "SKU doesn't EXIST";
				#		}
				#	$olm->pooshmsg("ERROR|+cram got error: $ERROR ($msg), Sears order: $erefid Item: $SKU");
				#	ZOOVY::confess($USERNAME,"cram got error: $ERROR ($msg), Sears order: $erefid Item: $SKU\n");
				#	}
				#else {
				#	$olm->pooshmsg("INFO-ORDER|+cram'ed item: $SKU qty: ".$summaryref->{'qty'});
				#	}
				}

			# $O2->use_stuff2_please($s2);	
			if ($previous_orderid) {
				my ($O2) = CART2->new_from_oid($USERNAME,$previous_orderid);
				if ($O2->stuff2()->digest() ne $s2->digest()) {
					$O2->use_stuff2_please($s2);
					$O2->add_history("Reset stuff. original order digest:".$O2->stuff2()->digest());
					$O2->order_save();
					}
				die("done with redid stuff");
				}
			
			### CALCULATE SHIPPING

			#$cart2{'sum/shp_total'} = $shipping_fees;
			#$cart2{{'/ship.selected_price'} = $shipping_fees;
			#$cart2{{'/ship.selected_method'} = $order->{'shipping-detail'}[0]->{'shipping-method'}[0];
			#$cart2{{'/ship.selected_carrier'} = $ship_map{$order->{'shipping-detail'}[0]->{'shipping-method'}[0]};

			my $SEARS_CARRIER = $order->{'shipping-detail'}[0]->{'shipping-method'}[0];
			my $OUR_CARRIER = '';
			if ($SEARS_CARRIER eq 'Ground') { $OUR_CARRIER = 'SLOW'; }
			if ($SEARS_CARRIER eq 'Priority') { $OUR_CARRIER = 'DAY2'; }
			if ($SEARS_CARRIER eq 'Express') { $OUR_CARRIER = 'DAY1'; }

			## if total-shipping-handling arent defined, the reference of the first element in the array is a HASH
			## 	 so if its not defined, set it = 0
			my $total_shipping_handling = ((ref($order->{'total-shipping-handling'}[0]) eq 'HASH')?0:$order->{'total-shipping-handling'}[0]);

			$O2->set_mkt_shipping(
				$order->{'shipping-detail'}[0]->{'shipping-method'}[0],
				$total_shipping_handling,
				'carrier'=>$OUR_CARRIER,
				);

			## calculate some totals
			my $order_subtotal = ((ref($order->{'order-total-sell-price'}[0]) eq 'HASH')?0:$order->{'order-total-sell-price'}[0]);
			#order->{'sales-tax'}[0] sales tax is collected and submitted by sears so nothing to do here
			#$order->{'balance-due'}[0] balance due = order total seller price -total comission +total shipping handling (not entirely relevant to us)

			my $order_total = ZOOVY::f2money($order_subtotal+$total_shipping_handling);
			$O2->in_set('mkt/order_total',$order_total);

			$cart2{'mkt/recipient_orderid'} = $order->{'customer-order-confirmation-number'}[0];

			##
			#my @PAYMENTS = ();
			#push @PAYMENTS, [ $syn_name, $order_total, { ps=>$PS, txn=> $erefid} ];		
			#(my $orderid, my $success, my $o, my $ERROR) = &CHECKOUT::finalize($CART,
			#	orderid				=>$previous_orderid,
			#	use_order_cartid	=>sprintf("%s",$erefid),
			#	email_suppress		=>1,
			#	'@payments' 		=>\@PAYMENTS, 
			#	);

			## TAX - Sears charges its customer tax, BUT doesn't give the tax to our merchants...
			## so don't include it!!
			#$cart2{{'/data.tax_total'} = $order->{'sales-tax'}[0];
			#$CART->guess_taxrate_using_voodoo($order->{'sales-tax'}[0],src=>'SEARS.com',events=>\@EVENTS);
			## let's note the total info, we should prolly alert if different
			#my $total_info = "Order Total [".$O2->in_get('sum/order_total')."]".
			#			 " should be equal Sears subtotal [".$order_subtotal."]".
			#			 " plus shipping total [".$shipping_fees."]";			
			#$olm->pooshmsg("INFO-ORDER|+$total_info");
			#$olm->pooshmsg("INFO-ORDER|+ORDERID: ".$O2->oid());

			#$O2->add_history("$total_info");
			#$O2->order_save();
				
			#if ($ERROR ne '') {
			#	$olm->pooshmsg("ERROR|+$ERROR");					
			#	}

			if ($olm->can_proceed()) {
				## if we get to this line - we're going to try and create an order.
				my $ts = time();

				my %params = ();
				$params{'*LM'} = $olm;
				# $cart2{'mkt/siteid'} eq 'cba')
				$O2->in_set('want/create_customer',0);
				$params{'skip_ocreate'} = 1;
				$O2->in_set('is/email_suppress', 1);


				foreach my $estr (@EVENTS) {
					# $lm->pooshmsg(sprintf("EVENT|ebayoid=%s|%s",$ordref->{'.OrderID'},$msg));
					$O2->add_history($estr,'ts'=>$ts,'etype'=>2,luser=>'*SEARS');
					}

				## report any finalize errors, add payments before we save.
				$O2->add_payment("SEARS",$O2->in_get('mkt/order_total'),'ps'=>$PS,'txn'=>$erefid );

				# $O2->add_history(sprintf("Sears Order Processing %s Ps=$$",$eb2->ebay_compat_level(),$::LMS_APPVE));
				($olm) = $O2->finalize_order(%params);

				if (not $O2->oid()) {					
					$olm->pooshmsg("WARN|+Order creation was skipped due to previous errors");
					}
				}
			
			if ($olm->has_win()) {
				## associate Zoovy OrderId with SEARS PO number for Ack'ing
				push @ACK_PLEASE, [ $O2->oid(), $order->{'po-number'}[0], $order->{'po-date'}[0] ];
				}

			#$poref->{$order->{'po-number'}[0]}->{'orderid'} = $orderid;
			#$poref->{$order->{'po-number'}[0]}->{'po-date'} = $order->{'po-date'}[0];
			$lm->merge($olm,'_refid'=>$O2->oid(),'%mapstatus'=>{'ERROR'=>'ORDER-ERROR'});
			}

		}


	## ACK ORDERS
	## go thru orderref returned from downloadOrders
	##	- send XML to associate the Zoovy OrderId with the SEARS PO number
	##	-- one XML file per Order
	##	- PRIVATE output file is created with the contents of the request and response XML
	if (not $lm->can_proceed()) {
		}
	elsif (scalar(@ACK_PLEASE)==0) {
		$lm->pooshmsg("WARN|+nothing to ack");
		}
	else {
		my $URL = "https://seller.marketplace.sears.com/SellerPortal/api/oms/invoice/v1?email=$user&password=$pass";

		## one XML file sent for each ACK
		foreach my $set (@ACK_PLEASE) {
			my ($zoovy_orderid, $ponum, $podate) = @{$set};
			my $request_xml = '';
			my $writer = new XML::Writer(OUTPUT => \$request_xml, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');	
			$writer->startTag("invoice-feed", 
				"xmlns"=>"http://seller.marketplace.sears.com/oms/v1",
			 	"xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance", 
				"xsi:schemaLocation"=>"https://seller.marketplace.sears.com/SellerPortal/s/schema/rest/oms/import/v1/invoice.xsd");
				$writer->startTag("invoice");
					$writer->dataElement("po-number", $ponum);
					$writer->dataElement("po-date",$podate);
					$writer->dataElement("seller-invoice-number",$zoovy_orderid);
				$writer->endTag("invoice");
			$writer->endTag("invoice-feed");
			$writer->end();
	
			my $length = length($request_xml);
			my $header = HTTP::Headers->new('Content-Length' => $length, 'Content-Type' => 'application/xml', 'connection'=>'close', 'date' => 'Wed, 08 Dec 2010 21:43:29 GMT',);
			my $request = HTTP::Request->new("PUT", $URL, $header, $request_xml);
	
			my $response = $ua->request($request);
			my $ACKSXML = $response->content;	
			
			my $DATE = strftime("%Y%m%d%H%M",localtime(time()));
			my $local_file = "SEARSAck".$DATE.".txt";
			## store the file to private files.
			my ($lf) = LUSER::FILES->new($so->username(), 'app'=>'SEARS');
			$lf->add(
				buf=>$ACKSXML,
				type=>$DST,
				title=>$local_file,
				meta=>{'DSTCODE'=>$DST,'TYPE'=>$params{'type'}},
				);
		
			$lm->pooshmsg("ACK|+ack invoice info written to private file [$local_file]");
			}
		$lm->pooshmsg("SUCCESS|+Finished ACKs");
		}
	}



###########################################################################################
## given a docid (from a feed)
## 	return the error, if supplied
## this doesnt really work! docid just arent processed quickly enough to get results
sub get_docid {
	my ($so,$docid,$lm) = @_;
	
	my $user = $so->get('.user');
	$user = URI::Escape::XS::uri_escape($user);
	my $pass = $so->get('.pass');
	$pass = URI::Escape::XS::uri_escape($pass);
	
	my $URL = "https://seller.marketplace.sears.com/SellerPortal/api/reports/v1/processing-report/$docid?email=$user&password=$pass";
	$lm->pooshmsg("INFO-TRACK|+$URL");
	my $request = HTTP::Request->new("GET", $URL);
	my $ua = LWP::UserAgent->new();
	$ua->ssl_opts(
		'SSL_version'=>'SSLv3',
		'verify_hostname' => 0 
		);
	my $response = $ua->request($request);
	my $xml = $response->content;

	return($xml);
	}


##
## takes an order object, returns the xml tracking document for sears
##
sub trackingXMLforOrder {
	my ($O2,$lm) = @_;

	my $erefid = $O2->in_get('mkt/erefid');	

	my $xml = '';
	my $writer = new XML::Writer(OUTPUT => \$xml, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');
	$writer->startTag("shipment-feed", 
		"xmlns"=>"http://seller.marketplace.sears.com/oms/v1",
	 	"xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance", 
		"xsi:schemaLocation"=>"https://seller.marketplace.sears.com/SellerPortal/s/schema/rest/oms/import/v1/asn.xsd");
		$writer->startTag("shipment");
			$writer->startTag("header");
				my $asn = $O2->oid();
				$asn =~ s/-//g;
				$writer->dataElement("asn-number",$asn);		## no clue what im supposed to use here
				$writer->dataElement("po-number",$erefid);
				## if po-date is defined, use it... otherwise use the Zoovy create date
				## sears errors if the po-date doesnt match their create date
				my $CREATE_DATE = strftime("%Y-%m-%d",localtime($O2->in_get('our/order_ts')));
				my $PO_DATE = ($O2->in_get('mkt/sears_po_date') eq '')?$CREATE_DATE:strftime("%Y-%m-%d",localtime($O2->in_get('mkt/sears_po_date')));
				$writer->dataElement("po-date",$PO_DATE);
			$writer->endTag("header");
			$writer->startTag("detail");

			### CARRIER and TRACKING NUMBER
			## we dont currently store a tracking number per item, 
			## 	so just grab the first number and use for all items
			my $tracking_number = '';
			my $shipinfo = undef;
			foreach my $trk (@{$O2->tracking()}) {
				if (not defined $shipinfo) {
					$tracking_number = $trk->{'track'};
					$shipinfo = ZSHIP::shipinfo( $trk->{'carrier'} );
					}
				}

			$writer->dataElement("tracking-number",$tracking_number);
			my $SHIP_DATE = strftime("%Y-%m-%d",localtime($O2->in_get('flow/shipped_ts')));
			$writer->dataElement("ship-date",$SHIP_DATE);

			## valid carriers for SEARS: UPS, FDE, OTH, USPS
			#if ($carrier eq 'USPS' || $carrier eq 'UPS') { } 	## do nothing, these are valid
			#elsif ($carrier =~ /^F/) { $carrier = 'FDE'; }		## FEDEX
			#else { $carrier = 'OTH'; }									## OTHER
			my $SEARS_CARRIER = '';
			### METHOD
			## valid method: GROUND [Standard], PRIORITY [2Day], EXPRESS [NextDay]
			my $SEARS_METHOD = '';
			if (not defined $shipinfo) {
				$SEARS_CARRIER = 'OTH';
				$SEARS_METHOD = 'GROUND';
				}
			elsif (defined $shipinfo) {
				if ($shipinfo->{'is_nextday'}) { $SEARS_METHOD = 'EXPRESS'; }
				elsif ($shipinfo->{'expedited'}) { $SEARS_METHOD = 'PRIORITY'; }
				else { $SEARS_METHOD = 'GROUND'; }

				if ($shipinfo->{'carrier'} eq 'FDX') { $SEARS_CARRIER = 'FDE'; }
				elsif ($shipinfo->{'carrier'} eq 'UPS') { $SEARS_CARRIER = 'UPS'; }
				elsif ($shipinfo->{'carrier'} eq 'USPS') { $SEARS_CARRIER = 'USPS'; }
				else { $SEARS_CARRIER = 'OTH'; }
				}

			$writer->dataElement("shipping-carrier", $SEARS_CARRIER);
			$writer->dataElement("shipping-method", $SEARS_METHOD); # $ship_map{$O2->in_get('sum/shp_carrier')});
				
			## go thru each item in the cart
			## populate $item_hashref
			## keep in mind, mktid may have 2 line numbers because..
			## sears has legacy "bug" that sends multiple lines for an item with qty > 1
			## - Zoovy system automatically only adds the first line (with qty=1)
			## --- FIX => use hashref
			## 2011-05-10
			my $item_hashref = {};
			foreach my $item (@{$O2->stuff2()->items()}) {
				my $stid = $item->{'stid'};
				next if ($stid =~ /@/); ## skip assembly contents

				my $mktid = ($item->{'mktid'} ne '')?$item->{'mktid'}:1;
				
				## line number got consolidated, need to split out
				## sears wants a line per item it sent in order
				if ($mktid =~ /:/) {
					## BH 4/13/12 - there is a bug here, this shouldn't be getting run -- maybe for REALLY OLD ORDERS
					##					can't tell, it looks like this encoding is still used, but ugh - no time to fix.
					###				FUCK YOU PATTI FOR COPYING THIS CODE (YOU ARE A STUPID SHITTY PROGRAMMER AND I'M
					##					GLAD YOU DON'T WORK HERE ANYMORE SO I DON'T HAVE TO CLEANUP YOUR GOD DAMN MESSES)
					my @lines = split(/:/,$mktid);
					foreach my $element (@lines) {
						## 
						if ($element =~ /^([\d]+)qty([\d]+)$/) {
							my ($line_number,$quantity) = ($1,$2);
							$lm->pooshmsg("INFO-TRACK|+Found new mktid: $element for order: ".$O2->oid());
							## new way '1qty4:3qty1' -> line 1 has qty of 4, line 3 has a qty of 1
							$item_hashref->{$line_number}->{'item-id'} = ZOOVY::to_safesku($stid);	## convert to safe sku
							$item_hashref->{$line_number}->{'quantity'} = $quantity;
							}
						else {
							## old way '1:3' -> line 1 has a qty of 1, line 3 has a qty of 1
							$item_hashref->{$element}->{'item-id'} = ZOOVY::to_safesku($stid);  ## convert to safe sku
							$item_hashref->{$element}->{'quantity'} = $item->{'qty'};
							}
						}
					}
				elsif ($mktid =~ /^([\d]+)qty([\d]+)$/) {
					my ($line_number,$quantity) = ($1,$2);
					$lm->pooshmsg("INFO-TRACK|+Found new mktid: $mktid for order: ".$O2->oid());
					## new way '1qty3' -> line 1 has qty of 3
					$item_hashref->{$line_number}->{'item-id'} = ZOOVY::to_safesku($stid);  ## convert to safe sku
					$item_hashref->{$line_number}->{'quantity'} = $quantity;
					}
				else {
					## old way '1'
					$item_hashref->{$mktid}->{'item-id'} = ZOOVY::to_safesku($stid);	## convert to safe sku
					$item_hashref->{$mktid}->{'quantity'} = $item->{'qty'};
					}	
				}

			## go thru each line item from original order
			foreach my $line_number (keys %{$item_hashref}) {
				$lm->pooshmsg("INFO-TRACK|+Adding line-number: $line_number item: ".$item_hashref->{$line_number}->{'item-id'}." qty: ".$item_hashref->{$line_number}->{'quantity'});

				$writer->startTag("package-detail");
					$writer->dataElement("line-number",$line_number);						
					$writer->dataElement("item-id",$item_hashref->{$line_number}->{'item-id'});	
					$writer->dataElement("quantity",$item_hashref->{$line_number}->{'quantity'});
				$writer->endTag("package-detail");
				}
			$writer->endTag("detail");
		$writer->endTag("shipment");
	$writer->endTag("shipment-feed");
	$writer->end();
	return($xml);
	}





exit(1);

