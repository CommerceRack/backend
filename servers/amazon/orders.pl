#!/usr/bin/perl

use Data::Dumper;
use strict;

## hopefully this will correct address handling in amazon orders
use locale;
use utf8 qw();
use Encode qw();


use lib "/httpd/modules";
require STUFF;
require CART2;
require ZOOVY;
require ZSHIP;
require DIME::Parser;
require ZTOOLKIT;
require ZWEBSITE;
require SYNDICATION;
require AMAZON3;
require CART2;
require STUFF2;
use lib "/httpd/modules";
use Data::Dumper;
require PRODUCT;
require AMAZON3;
require ZTOOLKIT;
use strict;
use XML::Smart;
use XML::Parser;


#my $rv = `ps -ef | grep "amz_orders.pl" | grep -v "grep"`;
#if ($rv) { die "amz_orders.pl is already running\n"; }


## USAGE
## ./mws_orders.pl verb=orders cluster=snap
## ./mws_orders.pl verb=orders user=username
## ./mws_orders.pl verb=track ..
## ./mws_orders.pl verb=track ..

## NO LONGER WORKING:
## ./mws_orders.pl ack
## ./mws_orders.pl ack username
## ./mws_orders.pl recreate username OUR_ORDERID
## ./mws_orders.pl create_docid username DOCID
## ./mws_orders.pl fix username OUR_ORDERID

## set up to 1 when your loading manually added orders
##

my %params = ();
foreach my $arg (@ARGV) {
	if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}

if ($params{'cluster'} ne '') {
	}
elsif ($params{'user'} eq '') {
	die("user= is required");
	}


if ($params{'verb'} eq 'track') {
	}
elsif (($params{'verb'} eq 'orders') || ($params{'verb'} eq 'FIXORDERS')) {

	if ($params{'docid'}) {
		## we'll be reprocessing a file thank you!
		}
	elsif ($params{'oid'}) {
		my ($O2) = CART2->new_from_oid($params{'user'},$params{'oid'});
		$params{'docid'} = $O2->in_get('mkt/docid');
		$params{'amzoid'} = $O2->in_get('mkt/amazon_orderid');
		if (($params{'docid'} eq '') || ($params{'amzoid'} eq '')) {
			die("oid:$params{'oid'} is incomplete - does not have mkt/docid or mkt/amazon_orderid");
			}
		}
	elsif ($params{'amzoid'}) {
		## lookup docid by amzoid
		my ($udbh) = &DBINFO::db_user_connect($params{'user'});
		my $pstmt = "select DOCID from AMAZON_ORDERS where AMAZON_ORDERID=".$udbh->quote($params{'amzoid'})." and MID=".&ZOOVY::resolve_mid($params{'user'});
		print "$pstmt\n";
		my ($DOCID) = $udbh->selectrow_array($pstmt);
		if ($DOCID>0) {
			print "RESOLVED DOCID:$DOCID\n";
			$params{'docid'} = $DOCID;
			}
		else {
			die "COULD NOT RESOLVE DOCID FOR ORDER: $params{'amzoid'}\n";
			}
		&DBINFO::db_user_close();
		}
	## at this point if we're in recovery mode $params{'docid'} is set or we've errored out.
	}
elsif ($params{'verb'} eq 'ack-create') {
	}
else {
	die("Try a valid verb (orders, track)\n");
	}


my $INITIAL = 0;
my $VERB = $params{'verb'};
my $USERNAME = $params{'user'};






if ($VERB eq '') { die("VERB not specified"); }

my @TODO = ();
my $pstmt = '';
if (($VERB eq 'track') || ($VERB eq 'ack-create')) {
	## Check for track looks up who has data waiting.
	
	if ($VERB eq 'track') {
		$pstmt = "select MID,PRT from AMAZON_ORDERS where HAS_TRACKING=1 and FULFILLMENT_ACK_PROCESSED_GMT=0 and FULFILLMENT_ACK_REQUESTED_GMT<unix_timestamp(now())-3600 ";
		}
	elsif ($VERB eq 'ack-create') {
		$pstmt = "select MID,PRT from AMAZON_ORDERS where NEWORDER_ACK_PROCESSED_GMT=0 ";
		}
	if ($params{'user'} ne '') {
		$pstmt .= " and MID=".&ZOOVY::resolve_mid($USERNAME); 
		}
	if ($params{'prt'} ne '') {
		$pstmt .= " and PRT=".int($params{'prt'});
		}
	$pstmt .= " group by MID,PRT";

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($MID,$PRT) = $sth->fetchrow() ) {
		push @TODO, [ $USERNAME, $PRT ];
		}
	$sth->finish();
	&DBINFO::db_user_close();
	}
elsif (($VERB eq 'orders') || ($VERB eq 'FIXORDERS')) {
	## Check for new orders looks up in SYNDICATION table
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	if ($params{'user'} ne '') {
		$pstmt = "select USERNAME,DOMAIN from SYNDICATION where DSTCODE='AMZ' and USERNAME=".$udbh->quote($USERNAME)." and IS_ACTIVE>0"; 
		}
	else {
		$pstmt = "select USERNAME,DOMAIN from SYNDICATION where DSTCODE='AMZ' and IS_ACTIVE>0"; 
		}
	
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($USERNAME,$DOMAIN) = $sth->fetchrow() ) {
		my ($PRT) = int(substr($DOMAIN,1));	##  PRT=#0
		push @TODO, [ $USERNAME, $PRT ];
		}
	$sth->finish();
	&DBINFO::db_user_close();
	}

my $date = &ZTOOLKIT::pretty_date(time(),1);
print STDERR "\n\n##\n".$date."\n";
print STDERR $pstmt."\n";
print STDERR "verb=$VERB\n";
print Dumper(\@TODO);


##
## SANITY: at this point we @TODO is the list of users we need to do something for.
##


my $i = 0;
foreach my $set (@TODO) {
	$VERB = $params{'verb'};		## we need to reset verb at the top of each loop in case it changes during the execution

	my ($USERNAME,$PRT) = @{$set};
	if ($USERNAME eq '') { die("no username!"); }



	my ($lm) = LISTING::MSGS->new($USERNAME,logfile=>'~/amazonorders-%YYYYMM%.log',stderr=>1);
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	$lm->pooshmsg("INFO|+Starting amazon/orders VERB:$VERB");

	if (not &ZOOVY::locklocal("amazon.orders.$USERNAME")) {
		$lm->pooshmsg("STOP|+Could not obtain opportunistic lock");
		next;
		}
	elsif ($MID == -1) {
		$lm->pooshmsg("ISE|+$USERNAME could not be found, and should probably be removed.");
		}


	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my $t = time()-1;
	my ($so) = undef;
	if ($lm->can_proceed()) {
		$so = SYNDICATION->new($USERNAME,"AMZ","PRT"=>$PRT);
		if (not defined $so) {
			$lm->pooshmsg("STOP|+Could not load syndication object for PRT:$PRT");
			}
		}

	my ($userref) = &AMAZON3::fetch_userprt($USERNAME,$PRT);

	if (not $lm->can_proceed()) {
		## bad shit already happened.
		}
	elsif ($userref->{'AMAZON_MARKETPLACEID'} eq '') {
		## w/o the marketplaceid, MWS will not function
		$lm->pooshmsg("STOP|+$USERNAME prt:$PRT is not setup for MWS (missing AMAZON_MARKETPLACEID in userref)");
		}
	elsif ($userref->{'AMAZON_MERCHANTID'} eq '') {
		## w/o the merchantid, MWS will not function
		$lm->pooshmsg("STOP|+$USERNAME prt:$PRT is missing merchantid (missing AMAZON_MERCHANTID in userref)");
		}

	## POST TRACKING INFO TO AMAZON
	#if ($USERNAME eq 'toynk') {
	#	## 10/26/09 - turned off tracking feed for toynk per amazon's request.
	#	}
	if (not $lm->can_proceed()) {
		## bad shit already happened.
		}
	elsif ($VERB eq "track") {
		print STDERR "\n\nTRACKing info for $USERNAME $PRT $date\n";	

		## end of validation		
		my $ERROR = '';
		my $xml = XML::Smart->new();
		## only select orders from the last 30 days
		my $pstmt = "select OUR_ORDERID, AMAZON_ORDERID from AMAZON_ORDERS where PRT=$PRT and MID=".int($MID).
					" and FULFILLMENT_ACK_PROCESSED_GMT=0 and FULFILLMENT_ACK_REQUESTED_GMT>0 limit 0,30000";
		print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();

		$xml = $xml->{'Message'};		
		my @UPDATES = ();
		my $outxml = '';
		
		my $msgid = 1;
		my @docs = ();
		while (my ($OUR_ORDERID, $AMAZON_ORDERID) = $sth->fetchrow() ) {
		
			my ($O2) = undef;
			if ($OUR_ORDERID eq '') {
				$lm->pooshmsg("WARN|+Did not find ZOOVY order id for amazon order $AMAZON_ORDERID");
				}
			else {
				$lm->pooshmsg("INFO|+tracking order object for $USERNAME $OUR_ORDERID");
				($O2) = CART2->new_from_oid($USERNAME,$OUR_ORDERID);
				if (not defined $O2) {
					$lm->pooshmsg("ERROR|+order object could not be loaded for $OUR_ORDERID");
					}
				elsif (ref($O2) ne 'CART2') {
					$lm->pooshmsg("ERROR|+order $OUR_ORDERID was not returned as a reference to an ORDER object");
					}
				}


			if (not $lm->can_proceed()) {
				}
			elsif (defined $O2) {
				$xml->{'MessageID'}->content($msgid++);
				$xml->{'OrderFulfillment'}{'AmazonOrderID'}->content($AMAZON_ORDERID);

				my $orderid = $OUR_ORDERID;	
				$orderid =~ s/-//g;
				$xml->{'OrderFulfillment'}{'MerchantFulfillmentID'}->content($orderid);
				#$xml->{'OrderFulfillment'}{'FulfillmentDate'}->content($amztime);

				my $track_gmt = '';
				my $found = 0;
				foreach my $trkref (@{$O2->tracking()}) {
					next if ($found);	# already sent one - thank you!
					my ($carrier, $trackid,$track_gmt) = ($trkref->{'carrier'},$trkref->{'track'},$trkref->{'created'});

					## ZOM is not synced/saving the Carrier correctly
					## added 9/12/2006
					if ($carrier eq '' && $trackid =~ /^1Z/) { $carrier = 'UPS'; }
					next if ($carrier eq '');

					#my $amztime = AMAZON::amztime(time());
					## changed fulfillment time to be an hour before the feed is sent
					## was causing a 5002 error
					## changing to 5hrs, arg!
					## okay, turns out Amazon uses GMT, so need to add 8hrs, then substract 1hr
				
					## need to make sure tracking is not "sooner" than amz expects
					## so compare with amztime (magical time) and use as necessary
					## track_gmt => written to AMAZON_ORDERS
					## amztrack_gmt => sent to AMAZON (GMT of track_gmt)
					## fuck you amazon.. if our client has this in the future, we get an error.
					#my $amztrack_gmt = $track_gmt+(10*3600);
					if ($track_gmt<=0) { $track_gmt = time(); }
					my $amztrack_gmt = $track_gmt+(7*3600);
				

					my $amztime = AMAZON3::amztime($amztrack_gmt);
					$xml->{'OrderFulfillment'}{'FulfillmentDate'}->content($amztime);
				
					# from ralpho @ amazon 11/25/09
					#Use:
					#"USPS priority mail" (lower case).
					#Do *not* use:
					#"USPS Priority Mail" (it's recognized but configured as non-trackable)
					#"Priority Mail" (not reliable, works only if shiptrack can recognize the tracking id pattern)
					#
					#For other carriers, make sure the carrier id is within the ship method name, like:
					#
					#"UPS Ground" <-- good
					#"Ground" <- BAD, unreliable, works only on recognizable tracking ids
					#"FEDEX" <-- good, contains FEDEX
					#"FedEx" <-- good also, shiptrack will upper case it
					#"CIVA" <-- good (= ex Eagle)
					#"DHL" <-- good ONLY for US (DHL UK/DE needs special ship method names)
					#"ABF" <-- good - supported carrier

					## these ae generic carriers where we don't know the specific shipping type!
					$xml->{'OrderFulfillment'}{'FulfillmentData'} = '';
					$carrier =~ s/FDXG/FEDX/;
					my $amzmethod = undef;
					if ($trackid eq '') {
						## this line should never be reached and indicates an error in the tracking data.
						$lm->pooshmsg("WARN|oid=$OUR_ORDERID|+empty tracking id");
						}
					elsif ($carrier eq 'AIRB') {
						$found++;
						$amzmethod = 'Airbill';
						$xml->{'OrderFulfillment'}{'FulfillmentData'}{'CarrierName'}->content($amzmethod);
						$xml->{'OrderFulfillment'}{'FulfillmentData'}{'ShipperTrackingNumber'}->content($trackid); 
						}
					elsif (defined $ZSHIP::SHIPCODES{$carrier}->{'amzcc'}) {
						## use the 'amz' code if it's available
						my $coderef = $ZSHIP::SHIPCODES{$carrier};
						$amzmethod = $coderef->{'amzmethod'};
						$found++;
						$xml->{'OrderFulfillment'}{'FulfillmentData'}{'CarrierCode'}->content($coderef->{'amzcc'});
						$xml->{'OrderFulfillment'}{'FulfillmentData'}{'ShippingMethod'}->content($coderef->{'amzmethod'});
						$xml->{'OrderFulfillment'}{'FulfillmentData'}{'ShipperTrackingNumber'}->content($trackid);
						}
					else {
						## we either do not have a shipping method or the method does not exist in ZSHIP.pm
						$amzmethod = 'Other';
						if (($carrier eq 'OTHR') || ($carrier eq '')) {
							}
						elsif (not defined $ZSHIP::SHIPCODES{$carrier}) {
							## perhaps the user made up their own carrier code during a csv import?!
							$lm->pooshmsg("WARN|oid=$OUR_ORDERID|+CARRIER: $carrier not defined in ZSHIP::SHIPCODES");
							}
						elsif ((not defined $ZSHIP::SHIPCODES{$carrier}->{'amzcc'}) || (not defined $ZSHIP::SHIPCODES{$carrier}->{'amzmethod'})) {
							## this is probably something like 'FAST' or '1DAY' (user data error)
							$lm->pooshmsg("WARN|oid=$OUR_ORDERID|+CARRIER: $carrier does not have amazon definitions in ZSHIP::SHIPCODES");
							}
						$found++;
						if ((defined $ZSHIP::SHIPCODES{$carrier}->{'amzmethod'}) && ($ZSHIP::SHIPCODES{$carrier}->{'amzmethod'} ne '')) {
							$amzmethod = $ZSHIP::SHIPCODES{$carrier}->{'amzmethod'};
							}
						$xml->{'OrderFulfillment'}{'FulfillmentData'}{'CarrierName'}->content($amzmethod);
						$xml->{'OrderFulfillment'}{'FulfillmentData'}{'ShipperTrackingNumber'}->content($trackid); 
						}

					$lm->pooshmsg("DEBUG|oid=$OUR_ORDERID|+METHOD: $amzmethod, TRACKING NUMBER: $trackid");

					if ($found) {
						push @UPDATES, [ $O2, $track_gmt, $AMAZON_ORDERID, $OUR_ORDERID ];
						$outxml .= $xml->data(nometagen=>1,noheader=>1);
						}
					else {
						$lm->pooshmsg("WARN|oid=$OUR_ORDERID|err=434|+amazon send tracking order: $OUR_ORDERID HAS_TRACKING=1 *BUT* we didn't find any tracking in the file!");
						}
					} ## end not $ERROR
				}	## END NOT ERROR
			}	## END WHILE ORDERS
		$sth->finish();

		## SANITY: at this point @UPDATES is an array of arrayrefs containing orders, track_gmt, amz_orderid, zoovyoid

		if (scalar(@UPDATES)==0) {		
			$lm->pooshmsg("ERROR|+No \@UPDATES available .. this should never be reached!");
			}
		else {
			# my ($docid,$error) = AMAZON3::queue_xml($userref,'OrderFulfillment',$outxml);
			my ($docid,$error) = &AMAZON3::push_xml($userref,$outxml,'OrderFulfillment',undef);
			($docid) = int($docid);
			if ($error ne '') { 
				$lm->pooshmsg("ERROR|+$error");
				}
			else {
				my $t = time();
				foreach my $set (@UPDATES) {
					my ($O2,$track_gmt,$AMAZON_ORDERID,$OUR_ORDERID) = @{$set};
					my $pstmt = "update AMAZON_ORDERS set FULFILLMENT_ACK_PROCESSED_GMT=$t,FULFILLMENT_ACK_DOCID=$docid,HAS_TRACKING=2,TRACK_GMT=".int($track_gmt)." where MID=$MID and PRT=$PRT and AMAZON_ORDERID=".$udbh->quote($AMAZON_ORDERID)." and OUR_ORDERID=".$udbh->quote($OUR_ORDERID);  
					print STDERR $pstmt."\n";
					if ($udbh->do($pstmt)) {
						## add marketplace event
						$O2->add_history("Tracking info has been uploaded to Amazon",etype=>32);
						$O2->order_save();	
						}
					}
				$lm->pooshmsg("SUCCESS|+Finished uploading tracking to Amazon");
				}
			}

		if ($lm->has_win()) {
			## eventually we should use the shipping syndication object and the SHIPPED_GMT field in the orders.
			$so->{'TRACKING_LASTRUN_GMT'} = $t;
			$so->save();
			}
		#else ($lm->has_failed()) {
		#	&ZOOVY::confess($USERNAME,"mws_orders.pl $ERROR\nAMAZON_ORDERS: $AMAZON_ORDERID\nZOOVY_ORDER: $OUR_ORDERID\n\n".Dumper($o),justkidding=>1);
		#	$pstmt = "update AMAZON_ORDERS set HAS_TRACKING=0 where PRT=$PRT and MID=".int($MID)." and AMAZON_ORDERID=".$udbh->quote($AMAZON_ORDERID);
		#	print $pstmt."\n";
		#	$udbh->do($pstmt);
		#	}
		}


	## CREATE ORDERS
	if (not $lm->can_proceed()) {
		}
	elsif (($VERB eq "orders") || ($VERB eq 'FIXORDERS')) {
		my ($EMAIL_CONF) = $so->get('.emailconfirmations');
		my ($SHIPPING_MAP) = $so->get('.shipping');

		print STDERR "CREATING ORDERS FOR ".Dumper($userref)."\n";
		## no more nexts
		my $ERROR = '';

		my $CAN_I_HAS_MORE_ORDERS_PLEASE = 20;		## amazon doesn't really like us getting more than 20 per hour
		my $got_no_orders_from_amazon = 0;			## this is true if we ran out of order documents.

		if ($params{'file'} ne '') {
			}


		while ( (not $got_no_orders_from_amazon) && ($lm->can_proceed()) && ($CAN_I_HAS_MORE_ORDERS_PLEASE--)) {
			## we have a while loop here so we can keep downloading orders from amazon
			## getOrders only returns one docid (which may contain multiple orders)

			## orderef is a hashref keyed by docid, hashref is an xml order document.
			my $ordref = {};
			if ($params{'docid'}) {
				my ($DOCID) = $params{'docid'};
				my $DOCFILE = "/var/log/zoovy/amazon/order_docids/$DOCID.xml";
				if (! -f $DOCFILE) {
					$DOCFILE = &ZOOVY::resolve_userpath($userref->{'USERNAME'})."/PRIVATE/amz-mws-response-$DOCID.xml";
					print STDERR "DOCFILE: $DOCFILE\n";
					}
				if (-f $DOCFILE) {
					open F, "<$DOCFILE"; $/ = undef;
					$ordref->{$DOCID} = <F>; 
					close F; $/ = "\n";
					$lm->pooshmsg("DEBUG|+FILE: $DOCFILE");
					}
				else {
					$lm->pooshmsg("ISE|+RECREATE Could not find docid:$DOCID ($DOCFILE)");
					}

				if ( $ordref->{$DOCID} eq  '' ) {
					$lm->pooshmsg("WARN|No content in docid: $DOCID");
					}

				if (not $params{'reset'}) {
					}
				elsif (not $lm->can_proceed()) {
					$lm->pooshmsg("WARN|Skipped 'reset' command because of previous error");
					}
				elsif ($params{'reset'}) {
					## reset clears out crap from the tables
					my $pstmt = "delete from AMAZON_ORDERS where MID=$MID and DOCID=".int($DOCID);
					if ($params{'amzoid'}) { 
						$pstmt .= " and AMAZON_ORDERID=".$udbh->quote($params{'amzoid'}); 
						}
					else {
						die("I will not. you need to pass amzoid for safety!");
						}
					print STDERR "$pstmt\n";
					$udbh->do($pstmt);	
					# die(); ## bad because we might crash in the middle of a document of ordres and this would delete all records.

					#$pstmt = "/* REST */ delete from AMAZON_ORDERSDETAIL where MID=$MID and DOCID=".int($DOCID);
					#print STDERR "$pstmt\n";
					#$udbh->do($pstmt);	
					}

				$CAN_I_HAS_MORE_ORDERS_PLEASE = 0;
				}
			else {
				($ordref) = &getOrders($userref);
				}

			if (scalar(keys %{$ordref})==0) {
				$lm->pooshmsg("INFO|+Found no new pending orders from Amazon (this is normal)");
				$got_no_orders_from_amazon++;
				}

			# print STDERR "ORDERREF:".Dumper($ordref);
			## process orders (if there's any)
			## add to AMAZON_ORDERS
 			foreach my $DOCID (sort keys %{$ordref}) {
				my $xml = $ordref->{$DOCID};
				print STDERR "DOCID: $DOCID\n";
	
				my $DOCFILE = &ZOOVY::resolve_userpath($userref->{'USERNAME'})."/PRIVATE/amz-mws-response-$DOCID.xml";
				print STDERR "DOCFILE: $DOCFILE\n";
				if ($params{'docid'} ne '') {
					## don't backup files we already have
					}
				elsif (-f $DOCFILE) {
					## we already have a copy of this order.
					}
				elsif (&ZOOVY::host_operating_system() eq 'SOLARIS') {
					## there is no /var/log/zoovy on solaris!
					}
				elsif (-f "/var/log/zoovy/amazon/order_docids/".$DOCID.".xml") {
					$lm->pooshmsg("WARN|/var/log/zoovy/amazon/order_docids/".$DOCID.".xml already exists (not over-writing) .. are we doing some type of recovery boss?");
					}
				elsif ($VERB eq 'orders') {
					open(DOCID, ">/var/log/zoovy/amazon/order_docids/".$DOCID.".xml") or die "can't open /var/log/zoovy/amazon/$DOCID.xml";
					print DOCID $xml;
					close DOCID;		
					}

			 	my $XML = XML::Smart->new($xml) ;
 				$XML = $XML->cut_root ;
				my $doc_had_errors = 0;
				foreach my $msg ($XML->{'Message'}->('@')) {
					# print STDERR "XML: ".$msg->data."\n";

					my $MessageID = $msg->{'MessageID'}->content;
					$msg = $msg->{'OrderReport'};

					## check if order has already been created
					my ($amzoid) = $msg->{'AmazonOrderID'}->content;

					$lm->pooshmsg("START|+Processing DOCID:$DOCID AMZORDERID:$amzoid");

					my $pstmt = "select OUR_ORDERID from AMAZON_ORDERS where /* DOCID:$DOCID */ AMAZON_ORDERID=".$udbh->quote($amzoid).
								    " and PRT=$PRT and MID=".$udbh->quote($MID);
					print STDERR $pstmt."\n";	
					my ($OUR_ORDERID) = $udbh->selectrow_array($pstmt);
	
					## order already exists
					my $CREATE = 0;
					if ((defined $params{'amzoid'}) && ($amzoid ne $params{'amzoid'})) {
						$lm->pooshmsg("WARN|skipping amzoid:$amzoid because it does not match params{amzoid}:$params{'amzoid'}");
						}
					elsif (($params{'amzoid'}) && ($OUR_ORDERID)) {
						$CREATE++;
						}
					elsif ($OUR_ORDERID ne '') {
						$lm->pooshmsg("WARN|warn=030|amzoid=$amzoid|docid=$DOCID|+DOCID:$DOCID AMZOID:$amzoid was already processed (ZOOVY:$OUR_ORDERID)");
                  my ($OO2) = CART2->new_from_oid($USERNAME,$OUR_ORDERID);
                  if (not defined $OO2) {
							# we should probably clear $OUR_ORDERID  and delete the entry from the AMAZON_ORDERS table or we will get an ISE at create_order. checking to see if that will cause any issues
                      $lm->pooshmsg("WARN|warn=030|amzoid=$amzoid|docid=$DOCID|+seems the order didn't actually exist.");
                      $CREATE++;
                      }
						}					
					elsif ($OUR_ORDERID eq '') {
						$CREATE++;
						}

					if ($CREATE) {
						my ($O2,$olm) = &create_order($USERNAME,$PRT,
									'DOCID'=>$DOCID,'MSG'=>$msg,'AMZ_MERCHANT'=>$userref->{'AMAZON_MERCHANTID'},
									'EMAIL_CONF'=>$EMAIL_CONF,'SHIPPING_MAP'=>$SHIPPING_MAP,'VERB'=>$VERB,'OUR_ORDERID'=>$OUR_ORDERID,
									);	
						$lm->merge($olm);
						print Dumper($O2);
						if (defined $O2) {
							$lm->pooshmsg("FINISH|+Created amzoid=$amzoid docid=$DOCID orderid=".$O2->oid());
							}
						else {
							$lm->pooshmsg("FINISH-FAIL|+Failed amzoid=$amzoid docid=$DOCID orderid=UNDEFINED");
							}
						}

					}

				if (not $lm->can_proceed()) {
					delete $ordref->{$DOCID};
					$lm->pooshmsg("WARN|+We are not going to remove docid:$DOCID from acknowldgement report due to errors processing the document");
					&ZOOVY::confess($USERNAME,"AMAZON ORDER PROCESSING ERROR: $DOCID\n".Dumper($lm),justkidding=>1);
					}
				}

			my @docs = keys %{$ordref};
			if (not $lm->can_proceed()) {
				## do'nt acknowldge
				}
			elsif ($got_no_orders_from_amazon) {
				## oh cruel world, nothing to do here... but we don't want to pass an error to ack-create
				}
			elsif (scalar(@docs)==0) {
				$lm->pooshmsg("ERROR|+No documents were in ordref to acknowledge - this should never be reached.");
				}
			else {
				print "acknwledging docids apparently\n";
				$lm->pooshmsg("INFO|+Acknowledged docids: ".join(",",@docs));
				my ($acked_docs) = &AMAZON3::postDocumentAck($userref,\@docs);
				}
			}	## end of while loop

		$VERB = 'ack-create';
		}



	if (not $lm->can_proceed()) {
		print "we hit not can proceed. We must have hit an error\n";
		## earlier errors block ack-create
		}
	elsif ($VERB eq 'ack-create') {
		print "reached ack create\n";
		##
		## per conversation with ralpho@amazon 10/27/09 -
		##		batches of 500 - 1000 are fine to send, every 15 minutes and should not interfere with other
		##		feed processing.
		## update: 9/2/2010 - andrewt - we should be submitting no more than once per hour, up to 30,000 per shot.
		my @ACKDBIDS;
		my $MID = ZOOVY::resolve_mid($userref->{'USERNAME'});
		my $PRT = $userref->{'PRT'};

		my ($alm) = LISTING::MSGS->new($USERNAME,'stderr'=>1);

		my $msgid = 1;
		my $outxml = '';

		my $pstmt = "select id, AMAZON_ORDERID, DOCID, OUR_ORDERID from AMAZON_ORDERS where NEWORDER_ACK_PROCESSED_GMT=0 and MID=$MID and PRT=$PRT limit 0,30000";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		if ($sth->rows()==0) { $alm->pooshmsg("SUCCESS|No orders to acknowledge in database"); }
		while ( my ($dbid,$amzoid,$docid,$zoovyoid) = $sth->fetchrow() ) {
			if ($zoovyoid eq '') {
				$alm->pooshmsg("WARN|dbid=$dbid|docid:$docid|+amzoid:$zoovyoid is missing zoovy oid");
				}
			else {
				my $xml = XML::Smart->new();
				$xml = $xml->{'Message'};
				$xml->{'MessageID'}->content($msgid++);
				$xml->{'OrderAcknowledgement'}{'AmazonOrderID'}->content($amzoid);	
				$xml->{'OrderAcknowledgement'}{'MerchantOrderID'}->content($zoovyoid);
				$xml->{'OrderAcknowledgement'}{'StatusCode'}->content('Success');
				$outxml .= $xml->data(nometagen=>1,noheader=>1);
				push @ACKDBIDS, $dbid;
				}
			}
		$sth->finish();

		my ($docid,$error) = ();
		if ($alm->has_win()) {
			## already done .. no need to continue, probably had no rows
			}
		elsif ($alm->has_failed()) {
			## shit already happened
			}
		elsif ($outxml eq '') {		
			## this line should NEVER be reached.
			$alm->pooshmsg("ISE|+outxml has no content, and has_failed was not true");
			}
		else {
			($docid,$error) = &AMAZON3::push_xml($userref,$outxml,'OrderAcknowledgement',undef);
			# ($docid,$error) = AMAZON3::queue_xml($userref,'OrderAcknowledgement',$outxml);
			if ($error ne '') {
				$alm->pooshmsg("ERROR|+$error");
				}
			elsif ($docid == 0) {
				## note: there is no need to queue this document because the next time we ack-create we'll get the same id's again
				$alm->pooshmsg("ISE|+docid of zero returned from AMAZON3::queue_xml for OrderAcknowledgement");
				}
			else {
				## yay! success
				$docid = int($docid);
				my $pstmt = "update AMAZON_ORDERS set NEWORDER_ACK_PROCESSED_GMT=".time().",NEWORDER_ACK_DOCID=$docid where PRT=$PRT and MID=".int($MID)." and ID in ".&DBINFO::makeset($udbh,\@ACKDBIDS);
				print STDERR $pstmt."\n";
				if ($udbh->do($pstmt)) {
					$alm->pooshmsg("SUCCESS|+submitted order acks in docid:$docid");
					}
				else {
					$alm->pooshmsg("ISE|+failed to update ACK_GMT in database");
					}
				}
			# print STDERR $outxml."\n$docid\n$error\n";
			}

		## SANITY: at this point we are guaranteed to have either a has_win or has_failed type result.

		if ($alm->has_win()) {		
			## eventually we should use the shipping syndication object and the SHIPPED_GMT field in the orders.
			$so->{'ORDERS_LASTRUN_GMT'} = $t;
			$so->{'ORDERS_NEXTRUN_GMT'} = $t+7200;		## every two hours by default.
			$so->save();
			}
		$lm->merge($alm);

		}

	## end of TODO loop.
	DBINFO::db_user_close();
	}

exit 1;


#####################################################################
## get pending orders
## called from ./mws_orders.pl create
##
sub getOrders { 
	my ($userref) = @_;
	my %XMLDOCS = ();
	my @docs = ();

	## define backup_docid to use existing docid
	my $backup_docid = undef;

	## normal way of getting docids
	my ($docsref) = &AMAZON3::getDocumentPending($userref,'_GET_ORDERS_DATA_');
	if ($backup_docid) {
		## to recover a document.
		push @docs, $backup_docid;
		}
	elsif (ref($docsref) eq '') {
		## scalar indicates an error occurred.
		warn "ERROR: $docsref\n";
		}
	elsif (scalar(@{$docsref}) == 0) {
		print STDERR "uh-oh, _GET_ORDERS_DATA_ returned no documents\n";
		}
	else {
		print STDERR "\nRETURNED DOC COUNT [".$userref->{'USERNAME'}."]: ".scalar(@{$docsref})."\n";

		foreach my $docid (@{$docsref}) {
			print STDERR "DOCID from getDocumentPending: $docid\n";
			push @docs, $docid;
			}
		}

	my $i = 0;
	foreach my $docid (@docs) {
		my $XML = '';
		my $ERROR = undef;
		if ($backup_docid eq '') {
			($ERROR,$XML) = &AMAZON3::getDocument($userref,$docid,'_GET_ORDERS_DATA_');
			}
		## grab XML from existing docid
		else {
			my $backdir = "/var/log/zoovy/amazon/order_docids/";
			open(DOCID,$backdir.$docid.".xml") or die "can't open ".$backdir.$docid.".xml";
			while(<DOCID>) { $XML .= $_; }
			close(DOCID);
			}

		if ($ERROR) {
	      print STDERR "ERROR for $docid : $ERROR\n";
			}
		else {
			$XMLDOCS{$docid} .= $XML;
			}
		}
	return(\%XMLDOCS);	
	}





##
## inputs:
## 	USERNAME
##		PRT
##
##		options:
##		DOCID => Amazon docid, xml is stored under
##			/var/log/zoovy/amazon/order_docids/$docid.xml
##		msg => contents of the xml
##		OUR_ORDERID => Zoovy Orderid if it exists, like with a recreate or fix
##		AMZ_MERCHANT_ID => the Amazon Merchant ID, defined by Amz
##		EMAIL_CONF => send email confirmation to the customer (against Amazon policy)
## 	SHIPPING_MAP => convert Amz shipping desc to something known in merchant's Zoovy store
##			ie; Standard => UPS Ground
##		FIX_ORDER => 1, edit/fix existing order (ie add missing promos)
##
sub create_order {
	my ($USERNAME,$PRT,%options) = @_;

	my ($userref) = &AMAZON3::fetch_userprt($USERNAME,$PRT);

	my $olm = LISTING::MSGS->new($USERNAME,logfile=>'~/amazonorders-%YYYYMM%.log',stderr=>1);
	my $VERB = uc($options{'VERB'});
	
	## define options
	my $DOCID = $options{'DOCID'};
	my $msg = $options{'MSG'};
	my $OUR_ORDERID = $options{'OUR_ORDERID'};
	my $AMZ_MERCHANT_ID = $options{'AMZ_MERCHANT_ID'};
	my $EMAIL_CONF = $options{'EMAIL_CONF'};
	my $SHIPPING_MAP = $options{'SHIPPING_MAP'};

	print STDERR Dumper($USERNAME,$DOCID,$OUR_ORDERID);
	if ($USERNAME eq '' || $DOCID eq '' || not defined $msg) {
		$olm->pooshmsg("ISE|+Need more info about order to create");
		}

	my ($udbh) = DBINFO::db_user_connect($USERNAME);

	my @EVENTS = ();
	push @EVENTS, "Amazon DOCID:$DOCID MERCHANTID:$AMZ_MERCHANT_ID";

	my @FEES = ();		# pipe separated string SKU,FeeName,Amount
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	my ($O2) = undef;
	if ($options{'OUR_ORDERID'} eq '') {
		## fresh order
		($O2) = CART2->new_memory($USERNAME,$PRT,$msg->{'AmazonOrderID'}->content);
		}
	elsif ($VERB eq 'FIXORDERS') {		
		($O2) = CART2->new_from_oid($USERNAME,$options{'OUR_ORDERID'});
		if (not defined $O2) {
			$olm->pooshmsg("WARN|+VERB=RECOVER but ORDER '$options{'OUR_ORDERID'}' is invalid!");
			($O2) = CART2->new_memory($USERNAME,$PRT);
			$O2->in_set('our/orderid',$options{'OUR_ORDERID'});
			}

		## MAKE SURE TO EMPTY THE CART SINCE WE'RE GOING TO RE-ADD ITEMS	
		$O2->stuff2()->empty();
		$O2->{'@PAYMENTS'} = [];
		#if (not defined $O2) {
		#	## CBA orders may not exist in the database .. this is really bad design because 
		#	## 	we can't tell what is and is not an error, .. 
		#	($O2) = CART->new_memory($USERNAME);
		#	$O2->in_set('our/orderid',$OUR_ORDERID);
		#	}
		#else {
		#	$olm->pooshmsg(sprintf("INFO|+RE-CREATING ORDERID: %s (old-oid:%s)",$O2->oid(),$OUR_ORDERID));
		#	$O2->add_history("amazon/orders.pl is reprocessing order $OUR_ORDERID, previous order (if it existed) was destroyed.");
		#	}
		}
	else {
		$olm->pooshmsg("ISE|+OUR_ORDERID passed with UNKNOWN VERB '$VERB'");
		}


	##
	## CBA (Checkout By Amazon) - special code.
	##
	my $IS_BROKEN_CBA = 0;
	if (1) {
		my $pstmt = "select ORDERID,CARTID,CART from AMZPAY_ORDER_LOOKUP where MID=$MID /* $USERNAME */ ".
						" and AMZ_PAYID = ".$udbh->quote($msg->{'AmazonOrderID'}->content);
		my ($CBA_ORDERID, $CBA_CARTID,$CBA_XMLCART) = $udbh->selectrow_array($pstmt);
		if ($OUR_ORDERID eq $CBA_ORDERID) {
			## HMM>.. not sure what the hell this is about!?
			#$O2 = CART2->new_from_oid($USERNAME,$OUR_ORDERID);
			#if (not defined $O2) {
			#	}
			#elsif ($VERB eq 'FIXORDERS') {
			#	}
			#else {
			#	$O2->make_readonly();
			#	}
			}

		if ($CBA_ORDERID && $CBA_CARTID) {
			$O2->in_set('mkt/siteid','cba');		## used as a flag later in the process
			$O2->in_set('our/orderid',$CBA_ORDERID);
			$O2->in_set('cart/cartid',$CBA_CARTID);

			$O2->from_xml($CBA_XMLCART);
			if ($O2->stuff2()->count()==0) {
				$O2->history("CBA source cart is corrupt, using AMAZON fail-over");
				$IS_BROKEN_CBA++; 
				}
			}
		}

	my %cart2 = ();
	tie %cart2, 'CART2', 'CART2'=>$O2;
	$cart2{'is/origin_marketplace'} = 1;		## we need to do this REALLY early so that %coupons doesn't get copied in/populated.
	$cart2{'our/prt'} = $PRT;
	$cart2{'mkt/amazon_merchantid'} = $AMZ_MERCHANT_ID;
	$cart2{'mkt/amazon_orderid'} = $msg->{'AmazonOrderID'}->content;
	$cart2{'mkt/erefid'} = $msg->{'AmazonOrderID'}->content;
	$cart2{'want/order_notes'} = "AmazonOrder # ".$cart2{'mkt/amazon_orderid'};
	$cart2{'mkt/amazon_sessionid'} = $msg->{'AmazonSessionID'}->content;
	$cart2{'mkt/post_date'} = &AMAZON3::amzdate_to_gmt($msg->{'OrderPostedDate'}->content);

	
	## check if order has already been created
	my $pstmt = "select count(*) from AMAZON_ORDERS where MID=$MID and AMAZON_ORDERID=".$udbh->quote($cart2{'mkt/amazon_orderid'});
	my ($exists) = $udbh->selectrow_array($pstmt);
	if (not $olm->can_proceed()) {
		}
	elsif (not $exists) {
		## yay!
		my %db = ();
		$db{'MID'} = $MID;
		$db{'PRT'} = $PRT;
		$db{'DOCID'} = $DOCID;
		$db{'AMAZON_ORDERID'} = $cart2{'mkt/amazon_orderid'};
		$db{'CREATED_GMT'} = time();
		$db{'POSTED_GMT'} = $cart2{'mkt/post_date'};
		$db{'OUR_ORDERID'} = '';	## this has a not null constraint (thanks patti)
		my $pstmt = &DBINFO::insert($udbh,'AMAZON_ORDERS',\%db,'verb'=>'insert',sql=>1);
		my $rv = $udbh->do($pstmt);
		if (int($rv) != 1) { 
			$olm->pooshmsg("ISE|+Had DB error:$rv on insert -- $pstmt");
			}
		}
	elsif ($OUR_ORDERID ne '') {
		if ($VERB eq 'FIXORDERS') {
			## it's okay.
			}
		else {
			$olm->pooshmsg("ISE|+FAILSAFE (record exists in database w/ORDERID) - DUPLICATE ORDER $OUR_ORDERID trying to be recreated!!");
			}
		}
	else {
		$olm->pooshmsg("WARN|+Recreating order - with existing DB ENTRY but no OUR_ORDERID");
		}
	

	#my $pstmt = "insert into AMAZON_ORDERS (mid, prt, docid, amz_orderid, created_gmt,posted_gmt) ".
	#				"values ($MID, $PRT, $DOCID, ".$udbh->quote($cart2{{'/amazon_orderid'}).", ".
	#					time().",".$udbh->quote($cart2{{'/posted'})." )";
	push @EVENTS, "Amazon Merchant orderid=[$cart2{'mkt/amazon_orderid'}] sessionid=[$cart2{'mkt/amazon_sessionid'}]";
		
	$cart2{'our/order_ts'} = &AMAZON3::amzdate_to_gmt($msg->{'OrderDate'}->content);
	$cart2{'flow/paid_ts'} = $cart2{'our/order_ts'};
	
	#print STDERR &ZTOOLKIT::pretty_date($cart2{{'/created'}, 1)."\n";
	#print STDERR $msg->{'OrderDate'}->content."\n";
	
	## check if this order is older than 4wks
	## allow fixing of orders older than 4wks old
	if (not $olm->can_proceed()) {
		}
	elsif ($cart2{'our/order_ts'} < time()-(86400*28)) {
		if ($params{'WAYOLDOKAY'}) {
			$olm->pooshmsg("WARN|+We're in WAYOLDOKAY mode");
			}
		else {
			$olm->pooshmsg("ISE|+Order [".$cart2{'mkt/amazon_orderid'}."] for $USERNAME, is way old (use param WAYOLDOKAY=1 to ignore): ".&ZTOOLKIT::pretty_date($cart2{'our/order_ts'}, 1));
			}
		}

	## Billing 
	$cart2{'bill/email'} = $msg->{'BillingData'}->{'BuyerEmailAddress'}->content;
	($cart2{'bill/firstname'}, $cart2{'bill/lastname'}) = split(/[\s]+/,$msg->{'BillingData'}->{'BuyerName'}->content,2);
	$cart2{'bill/phone'} = $msg->{'BillingData'}->{'BuyerPhoneNumber'}->content;

	## Shipping
	($cart2{'ship/firstname'}, $cart2{'ship/lastname'}) = split(/[\s]+/,$msg->{'FulfillmentData'}->{'Address'}->{'Name'}->content,2);
	$cart2{'ship/phone'} = $msg->{'FulfillmentData'}->{'Address'}->{'PhoneNumber'}->content;
	$cart2{'ship/address1'} = $msg->{'FulfillmentData'}->{'Address'}->{'AddressFieldOne'}->content;
	$cart2{'ship/address2'} = $msg->{'FulfillmentData'}->{'Address'}->{'AddressFieldTwo'}->content;
	$cart2{'ship/countrycode'} = $msg->{'FulfillmentData'}->{'Address'}->{'CountryCode'}->content;
	$cart2{'ship/city'} =  $msg->{'FulfillmentData'}->{'Address'}->{'City'}->content;

	#require ZSHIP;
	#$cart2{'ship/country'} = &ZSHIP::fetch_country_shipname($cart2{'ship/countrycode'});

	if ($cart2{'ship/countrycode'} eq 'US') {
		print STDERR "Getting the correct STATE for ".$msg->{'FulfillmentData'}->{'Address'}->{'StateOrRegion'}->content."\n";
		$cart2{'ship/postal'} =  $msg->{'FulfillmentData'}->{'Address'}->{'PostalCode'}->content;
		
		# make state uppercase & remove periods & spaces
		$cart2{'ship/region'} =  uc($msg->{'FulfillmentData'}->{'Address'}->{'StateOrRegion'}->content);
		$cart2{'ship/region'} =~ s/\.//g;  
		$cart2{'ship/region'} =  &ZSHIP::correct_state($cart2{'ship/region'});
		$cart2{'ship/region'} =~ s/ //g;
	
		if (defined $ZSHIP::STATE_NAMES{$cart2{'ship/region'}}) { 
			$olm->pooshmsg(sprintf("WARN|+STATE correct was '%s' corrected to '%s'", $cart2{'ship/region'}, $ZSHIP::STATE_NAMES{$cart2{'ship/region'}}));
			$cart2{'ship/region'} = $ZSHIP::STATE_NAMES{$cart2{'ship/region'}}; 
			}
		}
	else {
		$cart2{'ship/postal'} =  $msg->{'FulfillmentData'}->{'Address'}->{'PostalCode'}->content;
		$cart2{'ship/region'} =  $msg->{'FulfillmentData'}->{'Address'}->{'StateOrRegion'}->content;
		}

	## note: CUSTOMER create code got moved from here to after order creation

		
	##
	## now process the items	
	##		- hint: the summaries below are used to make sure everything from amazon matches the zoovy formulas.
	##
	my $SHIPPING_TOTAL = 0;			
	my $SHIPPING_TAXTOTAL = 0;
	my $ITEMS_TAXTOTAL = 0;
	my $SUB_TOTAL = 0;

	my $promo_ctr = 0;
	
	my %SKU_QTY = ();			## a count of how many of each sku, at each quantity we have.

	##
	## -- so amazon has a nice 'feature' that it returns multiple qty of the same item
	##		with qty 1, but unique 'AmazonOrderItemCode' -- so we use this to track the unique counter for a sku
	##		so we can cram it safely. this won't be necessary in the future when each item get's a unique uuid and
	##		we can safely dispose of stid and have multiple of the same sku in an order.  but for now, we need to code
	##	 	for this (what i'm saying is in the future this can probably be streamlined) - BH 9/14/12
	##

	my %AMAZON_SEEN_BEFORE = ();
	my $line_item_counter = 0;
	foreach my $ai ($msg->{'Item'}->('@')) {
		## first lets compress all the ItemPrice/Component tags into a hash

		$line_item_counter++;
		my ($ilm) = LISTING::MSGS->new($USERNAME);

		my $SKU = uc($ai->{'SKU'}->content);
		if ($SKU =~ /[^A-Z0-9\-\_\#\:\/\@]/) {
			$ilm->pooshmsg("WARN|+SKU:$SKU has invalid characters");
			$SKU =~ s/[^A-Z0-9\-\_\#\:\/\@]/\_/gs;
			}

		if ($IS_BROKEN_CBA) {
			## the cba order had no items, so don't skip cba items
			}
		elsif ($O2->in_get('mkt/siteid') eq 'cba') {
			$ilm->pooshmsg("SKIP|+CBA Order - ignoring $SKU (using items from local db.)");
			}
		
		my %COMPONENTS = ();
		foreach my $component ($ai->{'ItemPrice'}->{'Fees'}->('@')) {
			$COMPONENTS{ sprintf("Fee-%s",$component->{'Type'}->content) } = $component->{'Amount'}->content;
			}

		foreach my $component ($ai->{'ItemPrice'}->{'Component'}->('@')) {
			## WTF IS % Components ??
			## Principal, Shipping, Tax, ShippingTax
			$COMPONENTS{  $component->{'Type'}->content  } = $component->{'Amount'}->content; 
			}


		## added to notes 2007-03-27
		# $item{'notes'} .= " Amazon Item Code: ".$item{'amz_itemcode'};
		#$item{'full_product'} = &ZOOVY::fetchsku_as_hashref($USERNAME,$item{'sku'});
		
		## added 2008-04-02 for toynk and their kits that default pogs
		## remember that products w/non-inv p/sog(s) are "allowed"...
		##		meaning that these options are removed and only the parent (and inv SOGs) are syn'd
		## 	-- orders created with these products use default_options to determine the correct STID
		##			that includes the non-inv p/sog(s)
		#if (&ZOOVY::prodref_has_variations($item{'full_product'})) {
		#	## we have options, better make sure we check 'em a..
		#	my ($pogs2) = &ZOOVY::fetch_pogs($USERNAME,$item{'full_product'});
		#	($item{'%options'},$item{'stid'}) = POGS::default_options($USERNAME,$item{'sku'},$pogs2);
		#	}
		#	## no options, so stid and sku are the same thing.
		#	$item{'stid'} = $item{'sku'};
		#	}


		my ($PID) = PRODUCT::stid_to_pid($SKU);
		if (defined $AMAZON_SEEN_BEFORE{$SKU}) {
			$ilm->pooshmsg("WARN|+DUPLICATE ITEM $SKU (SEEN BEFORE ON SAME ORDER)");
			}
		$AMAZON_SEEN_BEFORE{$SKU}++;
	
		my $selected_variations = {};
		my ($P) = PRODUCT->new($USERNAME,$PID);
		if (not defined $P) {
			## there's enough people doing this that it just warrants just treating everybody the same.
			#if ($USERNAME =~ /^(number21sports|lasvegasfurniture|usfreight|reesewholesale|studiohut|deals2all|standsbyriver|myhotshoes|downlite)$/) {
			# $ilm->pooshmsg("WARN|+PRODUCT $PID does not exist.");
			#	}
			#else {
			#	$ilm->pooshmsg("ISE|+PRODUCT $PID does not exist");
			#	}
			}
		elsif ($P->has_variations()) {
			my $suggestions = $P->suggest_variations('stid'=>$SKU,'guess'=>1);
			foreach my $suggestion (@{$suggestions}) {
				if ($suggestion->[4] eq 'guess') {
					$ilm->pooshmsg("WARN|+ITEM:$SKU VARIATION MISMATCH:$suggestion->[0] was GUESSED to be '$suggestion->[1]'");
					}
				if ($suggestion->[4] eq 'invalid') {
					$ilm->pooshmsg("WARN|+ITEM:$SKU VARIATION MISMATCH:$suggestion->[0] is INVALID '$suggestion->[1]'");
					$P = undef;
					}
				}
			$selected_variations = STUFF2::variation_suggestions_to_selections($suggestions);
			}

		## AMZ MULTIPLE QTY ITEMs added incorrectly		
		### looking like this (or something similar) needs to be readded
		### amz order docid treats multiple items of the same SKU as multiple items (vs qty>1)
		### the only difference btwn the items is the amz_itemcode
		### if we don't include this in our STID, then stuff will think it's the same item w/qty=1 (which is incorrect)
		### line 380 also needs modifying? SKU won't work as the key
		#$item{'stid'} = $item{'sku'}.'/'.$item{'amz_itemcode'};
		# $ai->{'AmazonOrderItemCode'}->content;
		my $notes = '';
		if ($ai->{'GiftMessageText'}->content ne '') {
			$notes = $ai->{'GiftMessageText'}->content;
			}
			
		
		## total qty for this stid gets added to SKU_QTY below
		# $item{'qty'} = $ai->{'Quantity'}->content;
		## be sure to figure the price before mucking with qty below
		## amz sends us the extended price, so we need to calculate base_price

		# my $taxable = $ai->{'ProductTaxCode'};
		# $item{'taxable'} = 0;
		my $taxable = 0;
		if ($ai->{'ProductTaxCode'}->content() eq 'A_GEN_NOTAX') {}	# not taxable??
		elsif ($ai->{'ProductTaxCode'}->content() eq 'A_GEN_TAX') { $taxable++; }
		elsif ($ai->{'ProductTaxCode'}->content() eq 'A_CUSTOM_RATE') { $taxable++; }
		elsif ($ai->{'ProductTaxCode'}->content() eq 'PTC_PRODUCT_TAXABLE_A') { $taxable++; }
		elsif ($ai->{'ProductTaxCode'}->content() eq 'A_BOOKS_GEN') { $taxable++; }
		else { $ilm->pooshmsg("WARN|+UNKNOWN ProductTaxCode SETTING $ai->{'ProductTaxCode'}"); }

		if ($COMPONENTS{'Tax'}>0) { $taxable = '1'; }

		my $QTY = int($ai->{'Quantity'}->content);	# for readability

		my $item = undef;
		if (not $ilm->can_proceed()) {
			## shit already happened.
			}
		elsif (not defined $P) {
			## we will add a basic item
			}
		else {
			($item,my $iilm) = $O2->stuff2()->cram( 
				$PID, $QTY, $selected_variations, 
					'force_price'=>sprintf("%.2f",$COMPONENTS{'Principal'}/$QTY),
					'force_qty'=>$QTY,
					'*P'=>$P,
					'needs_unique'=>1,
					'notes'=>$notes,
					'mkt'=>($cart2{'mkt/siteid'} eq 'cba')?'CBA':'AMZ',	# this must be set for checkbox handling to default to 'Not Set' when not specified.
					## NOTE: description is set below
				);
			# if ($CBA_ORDERID eq '') {	$item->{'mkt'} = 'AMZ';  }
			$item->{'taxable'} = $taxable;
			$item->{'amz_itemcode'} = $ai->{'AmazonOrderItemCode'}->content;	# needed later for inserting into AMAZON_ORDERSITEMS
			$item->{'description'} = $ai->{'Title'}->content;
			
			if ($iilm->had(['ERROR'])) {
				## catch errors, and switch them to CRAM-ERROR
				$P = undef;
				}
			$ilm->merge($iilm,'%mapstatus'=>{'ERROR'=>'CRAM-ERROR'});	## CRAM-ERROR won't shut us dow, we'll still get another shot to add the item as a basic item
			}

		## if $P is not defined here we need to add a basic item, if we got back an error from cram above
		if (not defined $P) {
			my $i = 0;
			my $uniqueSKU = undef;	# amazon may return duplicate items on the same order with the same sku
			while (not $uniqueSKU) {
				if ($i == 0) { $uniqueSKU = $SKU; }
				elsif ($i > 99) { $uniqueSKU = sprintf("DUPLICATE-%s",$SKU); }
				else {
					$uniqueSKU = sprintf("$SKU/##%02D",$i);
					}
				if ($O2->stuff2()->item('stid'=>$uniqueSKU)) { $uniqueSKU = undef; }	
				$i++;
				} 
			$ilm->pooshmsg("WARN|PRODUCT:$SKU does not exist, creating a basic item $uniqueSKU");
			($item) = $O2->stuff2()->basic_cram("$uniqueSKU",$QTY,sprintf("%.2f",$COMPONENTS{'Principal'}/$QTY),$ai->{'Title'}->content);
			}

		## FOOZ SHOOZ debugging..
		if ($ilm->had(['FOOZ'])) {	print Dumper($ilm,$O2->stuff2()); die(); }

		my $ITEM_FEES = 0;
		foreach my $component ($ai->{'ItemFees'}->{'Fee'}->('@')) {
			push @FEES, [ $item->{'stid'}, $component->{'Type'}->content, $component->{'Amount'}->content ];
			$ITEM_FEES += $component->{'Amount'}->content;
			}

		if ($ilm->can_proceed()) {
			if (defined $item) {
				$ilm->pooshmsg("INFO|+STID: $item->{'stid'} SKU: $item->{'sku'}");
				}
			}

		$SHIPPING_TOTAL += $COMPONENTS{'Shipping'};
		$SHIPPING_TAXTOTAL += $COMPONENTS{'ShippingTax'};
		$ITEMS_TAXTOTAL += $COMPONENTS{'Tax'};
		$SUB_TOTAL += $COMPONENTS{'Principal'};

		## force_qty for assembly orders

		## Amazon Promotions
		## Promotions can be assigned to a specific product
		## should they show up in the ZOOVY order as a separate item or should we just adjust this item
		## and make a note in the item description or order notes
		##<Promotion>
      ##  <PromotionClaimCode>_SITE_WIDE_</PromotionClaimCode>
      ##  <MerchantPromotionID>Free Shipping 12-31-2006</MerchantPromotionID>
      ##   <Component>
      ##      <Type>Shipping</Type>
		##      <Amount currency="USD">-10.49</Amount>
      ##   </Component>
      ##</Promotion>
      #my $ctr = 0;
		my $promo_ctr = 0;
      my $promo_item_total = 0;
      foreach my $promo ($ai->{'Promotion'}->('@')) {
			my %promo_item = ();

			#<Promotion>
			#<PromotionClaimCode>_SITE_WIDE_</PromotionClaimCode>
			#<MerchantPromotionID>40% Discount Clearance Offer</MerchantPromotionID>
			#<Component>
			#<Type>Principal</Type>
			#<Amount currency="USD">-9.58</Amount>
			#</Component>
			#<Component>
			#<Type>Shipping</Type>
			#<Amount currency="USD">0.00</Amount>
			#</Component>
			#</Promotion>



			my %PROMO_COMPONENTS = ();
			foreach my $component ($promo->{'Component'}->('@')) {
				## WTF IS % Components ??
				## Principal, Shipping, Tax, ShippingTax
				$PROMO_COMPONENTS{  $component->{'Type'}->content  } = $component->{'Amount'}->content; 
				}
	
			## remember 'Principal' and 'Shipping' are expressed as negative amounts
			if (($PROMO_COMPONENTS{'Principal'}<0) && ($PROMO_COMPONENTS{'Shipping'}==0)) {
				my $SKU = sprintf("%%%s/##%s",$ai->{'AmazonOrderItemCode'}->content(),POGS::base36($promo_ctr));
				my $PROMO_AMOUNT = $PROMO_COMPONENTS{'Principal'};		## this given to us as a negative 
				$SUB_TOTAL += $PROMO_AMOUNT;

				$O2->stuff2()->promo_cram( 
					$SKU,
					1,
					$PROMO_AMOUNT,
					sprintf("Amazon Promo: %s",$promo->{'MerchantPromotionID'}->content),
					);
				}
			elsif (($PROMO_COMPONENTS{'Principal'}==0) && ($PROMO_COMPONENTS{'Shipping'}<0)) {
				## NOTE: Amazon shipping is per item, but we don't use item shipping (yet) so .. that means that
				##			we can ignore shipping promotions because we expect that the order total at the end of the 
				##			order will be correct (and reflect any promotions)
				$ilm->pooshmsg("INFO|+SHIPPING Promotion Detected Addition: ".$promo->{'PromotionClaimCode'}->content);
				}
			elsif (($PROMO_COMPONENTS{'Principal'}==0) && ($PROMO_COMPONENTS{'Shipping'}==0)) {
				## NOTE: Amazon shipping is per item, but we don't use item shipping (yet) so .. that means that
				##			we can ignore shipping promotions because we expect that the order total at the end of the 
				##			order will be correct (and reflect any promotions)
				$ilm->pooshmsg("INFO|+ZERO DOLLAR Promotion Detected (ignored) Addition: ".$promo->{'PromotionClaimCode'}->content);
				}
			}
			

		my %giftwrap_item = ();				
		if (int($COMPONENTS{'GiftWrap'}) > 0) {
			## the example below is a REAL **TEST** order placed by nicole for nicole @ designed2bsweet
			## ./orders.pl verb=FIXORDERS user=designed2bsweet docid=7902182593 amzoid=102-5241347-4466615
			$ilm->pooshmsg("INFO|+Gift Wrap Addition: ".$COMPONENTS{'GiftWrap'});
			my $GWSKU = sprintf("%%%s/####",$item->{'sku'});

			my ($taxable) = ($COMPONENTS{'GiftWrapTax'}>0)?1:0;
			$O2->stuff2()->promo_cram($GWSKU,1,$COMPONENTS{'GiftWrap'},'GiftWrap','taxable'=>$taxable,'mkt'=>'AMZ');
			$SUB_TOTAL += $COMPONENTS{'GiftWrap'};
			$ITEMS_TAXTOTAL += $COMPONENTS{'GiftWrapTax'};

#			## CBA doesn't have gift wrap items, so its ok to add mkt here
#			$giftwrap_item{'mkt'} = 'AMZ';
#			$giftwrap_item{'amz_itemcode'} = $ai->{'AmazonOrderItemCode'}->content;
#			#$giftwrap_item{'sku'} = "%GIFTWRAP-$item{'sku'}";
#			#$giftwrap_item{'product'} = "%GIFTWRAP-$item{'sku'}";
#
#			## added 2009-05-27
#			$giftwrap_item{'sku'} = "%GIFTWRAP";
#			$giftwrap_item{'product'} = "%GIFTWRAP";
#			$giftwrap_item{'%options'}->{'##'} = "Item: $item{'sku'}";
#			$giftwrap_item{'description'} = "Amazon Gift Wrap";
#			$giftwrap_item{'qty'} = 1;
#			$giftwrap_item{'base_price'} = $COMPONENTS{'GiftWrap'}; 
	
#			$giftwrap_item{'full_product'} = &ZOOVY::fetchsku_as_hashref($USERNAME,$giftwrap_item{'sku'});
#		
#			## 
#			if (&ZOOVY::prodref_has_variations($giftwrap_item{'full_product'})) {
#				## we have options, better make sure we check 'em a..
#				my ($pogs2) = &ZOOVY::fetch_pogs($USERNAME,$giftwrap_item{'full_product'});
#				($giftwrap_item{'%options'},$giftwrap_item{'stid'}) = POGS::default_options($USERNAME,$giftwrap_item{'sku'},$pogs2);
#				}
#			else {
#				## no options, so stid and sku are the same thing.
#				$giftwrap_item{'stid'} = $giftwrap_item{'sku'};
#				}
#
#				
#			## add to stuff
#			push @amz_items, \%giftwrap_item;
#
#			## adjust subtotal
#			$SUB_TOTAL += $COMPONENTS{'GiftWrap'};
#			$ITEMS_TAXTOTAL += $COMPONENTS{'GiftWrapTax'};
			}

		## ORDER AUDITING
		my $item_cost = $item->{'%attribs'}->{'zoovy:base_cost'};
		if ($item_cost>0) {
			if (($item_cost+$ITEM_FEES+$promo_item_total) >= $item->{'base_price'}) {
				push @EVENTS, "WARNING: Item $item->{'sku'} being sold at or below cost (cost[$item_cost] + fees[$ITEM_FEES] +promo[$promo_item_total]) > $item->{'base_price'}";
				}
			}
#
#
#		
#		## Calculate TaxRate
#		## only calculate once, it should be the same for all items?
		if (not defined $cart2{'our/tax_rate'}) { 
			## amazon sends tax per item.
			
			$cart2{'our/tax_rate'} = 
					$ai->{'ItemTaxData'}->{'TaxRates'}->{'District'} + 
					$ai->{'ItemTaxData'}->{'TaxRates'}->{'City'} +
					$ai->{'ItemTaxData'}->{'TaxRates'}->{'County'} + 
					$ai->{'ItemTaxData'}->{'TaxRates'}->{'State'};
			$ilm->pooshmsg("INFO|+SKU $SKU setting tax rate to: $cart2{'our/tax_rate'}");
			}

		$olm->merge($ilm,'%mapstatus'=>{'SKIP'=>'ITEM-SKIP'});
		}



	##
	## SANITY: at this point @amz_items is a list of items which will appear in the order.
	##				it should not change after this point.


	$cart2{'mkt/docid'} = $DOCID;
	if ($cart2{'mkt/siteid'} eq 'cba') {
		# $OUR_ORDERID = $CBA_ORDERID;
		require ZWEBSITE;
		require DOMAIN::TOOLS; 
		$cart2{'our/domain'} = DOMAIN::TOOLS::domain_for_prt($USERNAME,$PRT);
		$cart2{'our/mkts'} = '0JZ6RK';		# flags the order as purchased on CBA/APA
		$cart2{'must/payby'} = 'AMZCBA';
		push @EVENTS, "Checkout By Amazon Order created (DOCID:$DOCID)";

		## addition of cart variables here
		}		
	## only allow email suppress for amz syn
	else {
		## perl -e 'use lib "/httpd/modules"; use ZOOVY; print &ZOOVY::bitstr(&ZOOVY::mkt_to_bitsref(2));'
		$cart2{'our/domain'} = 'amazon.com';
		$cart2{'our/mkts'} = '00000W';		# flags the order as amazon
		$cart2{'must/payby'} = 'AMAZON';
		#if ($EMAIL_CONF) { $cart2{{'/email_suppress'} = 0xFF;	}
		## always set to suppress email
		$cart2{'is/email_suppress'} = 0xFF;
		$cart2{'is/origin_marketplace'} = 1;
		push @EVENTS, "Amazon\@Merchant Order (DOCID:$DOCID)";
		}
# 	$cart2{'our/payment_method'} = $payment_method;

   ## cram items into stuff
#	foreach my $item (@amz_items) {
#		use Data::Dumper;
#		print STDERR "Bout to cram stuff $USERNAME\n".Dumper($item);
		
		## CBA items' pogs have already been processed (ie this was jacking up assemblies)
      ## need to find the right setting to not process the assemnbly again... neither of these setting worked
      ## - use the following to test:
      ##		/httpd/servers/amazon/amz_orders.pl recreate toynk 2008-11-110479
      ##
      ## if ($CBA_ORDERID ne '') { 
      ## 	$item{'pogs_processed'}++; 
      ##		$item{'asm_processed'}++; 
      ##		}

		## add the mkt = Amz if this order was create on Amz (vs CBA)

		## add it to stuff:
		##	asm_processed=>500  (500 is some random code which tell us that cba did it)
		##							  this is key because cba orders will already have assembly choices options set.
		#my ($cramerrid,$cramerrmsg) = $stuff->legacy_cram(
		#	$item,
		#	asm_processed=>($is_cba_order)?500:0,
		#	auto_detect_options=>1,
		#	# please_dont_not_work=>1, # this might be a good idea, but i don't feel like coding it right now.
		#	'*LM'=>$lm,
		#	);
		#$lm->pooshmsg("INFO|+CRAM STID: $item->{'stid'} SKU: $item->{'sku'} result:$cramerrid,$cramerrmsg");
		#if ($cramerrid>0) {
		#	push @EVENTS, "CRAM STID: $item->{'stid'} SKU: $item->{'sku'} result:$cramerrid,$cramerrmsg";
		#	}		
#		}

	if (not $olm->can_proceed()) {
		}
   elsif ($O2->in_get('mkt/siteid') eq 'cba') {
			## CBA with assemblies will cause the next check to fail.
			$olm->pooshmsg("WARN|+CBA Order - can't compare/trust order item counts since CBA cannot be trusted.");
			}
	elsif ( $O2->stuff2()->count('show'=>'real+noasm') != $line_item_counter)  {
		## this line should never be reached (i think) .. might be a good place to throw an error check. -BH
		$olm->pooshmsg(sprintf("ISE|+stuff->stids('real+noasm'):%d does not match %d, order items do not match, order is incomplete.",$O2->stuff2()->count('show'=>'real+noasm'),$line_item_counter));
		}

	#$stuff->build_pogs($USERNAME);

	$cart2{'flow/pool'} = 'RECENT';
	$cart2{'flow/payment_status'} = '010';

	# $cart2{'sum/shp_total'} = $SHIPPING_TOTAL;	
	## if amz has sent us tax for ship, indicate that Zoovy should add ship tax too

	## we ignore FulfillmentMethod: Ship, InStorePickup, MerchantDelivery
	## can be standard and expedited
	$cart2{'sum/shp_method'} = $msg->{'FulfillmentData'}->{'FulfillmentServiceLevel'}->content;

	## addition of shp_carrier if SHIPPING_MAP is defined
	## shp_carrier is only "apparent" in ZOM, automatically choses method in label printing
	## configured in U/I setup / syndication / amazon / shipping maps
	if ($SHIPPING_MAP ne '') { 
		my $shipref = ZTOOLKIT::parseparams($SHIPPING_MAP);
		## shp_method will be: Standard, Expedited, SecondDay, NextDay
		my $code = $shipref->{$cart2{'sum/shp_method'}};
		## try and identify orders which are expedited.
		if (($code eq '') && ($cart2{'sum/shp_method'} eq 'Expedited')) { $code = '3DAY'; }
		if (($code eq '') && ($cart2{'sum/shp_method'} eq 'SecondDay')) { $code = '2DAY'; }
		if (($code eq '') && ($cart2{'sum/shp_method'} eq 'NextDay')) { $code = '1DAY'; }
		if (($code eq '') && ($cart2{'sum/shp_method'} eq 'Standard')) { $code = 'SLOW'; }
		if ($code ne '') { $cart2{'sum/shp_carrier'} = $code; }
		print STDERR "SHIPPING_MAP [$USERNAME]: added $code for ".$shipref->{$cart2{'sum/shp_method'}}."\n";
		}

	$O2->set_mkt_shipping($cart2{'sum/shp_method'}, $SHIPPING_TOTAL, 'carrier'=>$cart2{'sum/shp_carrier'});

	if ($SHIPPING_TAXTOTAL > 0) { $cart2{'sum/shp_taxable'} = 1; } 
	my $amazon_order_total = sprintf("%.2f",$SUB_TOTAL + $ITEMS_TAXTOTAL + $SHIPPING_TOTAL + $SHIPPING_TAXTOTAL); 
	
	if (not $olm->can_proceed()) {
		}
	elsif ($cart2{'our/tax_rate'}>0) {
		if ($cart2{'our/tax_rate'}>1) {
			## tax rate is already 8.775 or whatever (usually CBA)
			$cart2{'our/tax_rate'} = sprintf("%.3f", $cart2{'our/tax_rate'});
			}
		else {
			## tax rate is 0.08775 (calculated)
			$cart2{'our/tax_rate'} = sprintf("%.3f", $cart2{'our/tax_rate'} * 100);
			}

		$olm->pooshmsg("INFO|+Total tax rate: ".$cart2{'our/tax_rate'}."\nTotal Tax: ".$ITEMS_TAXTOTAL);
		$cart2{'sum/items_taxdue'} = $ITEMS_TAXTOTAL;
		$cart2{'sum/shp_taxdue'} = $SHIPPING_TAXTOTAL;
		$cart2{'sum/tax_total'} = $ITEMS_TAXTOTAL + $SHIPPING_TAXTOTAL;
		$cart2{'sum/tax_rate_state'} = $cart2{'our/tax_rate'};
		$olm->pooshmsg(sprintf("INFO|+SUB_TOTAL:%.3f + TOTAL_TAX:%.3f + SHIPPING_TOTAL:%.3f + SHIPPING_TAXTOTAL:%.3f",
			$SUB_TOTAL,$ITEMS_TAXTOTAL,$SHIPPING_TOTAL,$SHIPPING_TAXTOTAL));
		}


#	$O2->order_save();
#	print Dumper($O2);
#	die();
	

	## 
	## SANITY: at this point we're a go for creating the order
	##
	## pass the order id if this is a recreate
	print "USERNAME: $USERNAME OUR_ORDERID: $OUR_ORDERID\n";
	print "EVENTS: ".Dumper(@EVENTS)."\n";
	print "LM: ".Dumper($olm)."\n";

	## currently to setup to fix items in STUFF
	## ie the original creation of the order didn't include promo items
	## go thru the stuff created above and confirm all those items are in the ORDER 
   ## that was originally created, if not, add it

	if (not $olm->can_proceed()) {
		## BAIL OUT BEFORE ORDER CREATION
		$olm->pooshmsg("STOP|previous error caused premature stop");
		}

	if (not $olm->can_proceed()) {
		}
	elsif ($options{'FIX_ORDER'}==1) {
		##
		## THIS CODE IS ONLY FOR FIX ORDER.
		## 
		$olm->pooshmsg("STOP|+(STOP) ATTEMPTING TO FIX ORDER!! - $OUR_ORDERID");
		}
	else {	  
		## 
		## CREATE-NEW OR RE-CREATE FIX AN EXISTING ORDER
		##
		## note: not sure why useoid is specified here.. looks like it might be a cba thing? -bh 
		##			also when we re-craete an order using useoid= it will destroy previous events.
		##			i think cba requires we reserve oid's, so we need to go back and use that oid.

		## moved create CUSTOMER code here
		#if ($cart2{'mkt/siteid'} eq 'cba') {
		#	require CUSTOMER;
		#	$CUSTOMER::DEBUG=1;
		#	my ($C) = CUSTOMER->new($USERNAME,CREATE=>3,'*CART2'=>$O2,'INFO.ORIGIN'=>3,EMAIL=>$cart2{'bill/email'},PRT=>$O2->prt());
		#	}

		foreach my $feeset (@FEES) {
			$O2->set_fee( @{$feeset} );
			}
	
		## VALIDATE SOME TOTALS
		## check SHIPPING
		## Lets see if the order's shipping cost matches up.

		#my $lowestshipmethod = undef;
		#foreach my $shipmethod (@{$shipmethods}) { 
		#	next if ($shipmethod->{'carrier'} eq 'ERR');
		#	if (not defined $lowestshipmethod) { $lowestshipmethod = $shipmethod; }
		#	elsif ($lowestshipmethod->{'amount'} > $shipmethod->{'amount'}) { $lowestshipmethod = $shipmethod; }
		#	}
		#if (not defined $lowestshipmethod) {
		#	$olm->pooshmsg('WARN|+Could not create shipping estimate for this order');
		#	}
		#elsif ($lowestshipmethod->{'amount'}<$SHIPPING_TOTAL) {
		#	$olm->pooshmsg("WARN|+Actual shipping [$lowestshipmethod->{'id'}] lower = [$lowestshipmethod->{'amount'}] Amazon Shipping=[$SHIPPING_TOTAL]");
		#	}	
		#elsif ($lowestshipmethod->{'amount'}>$SHIPPING_TOTAL) {
		#	$olm->pooshmsg("WARN|+Actual shipping [$lowestshipmethod->{'id'}] higher = [$lowestshipmethod->{'amount'}] Amazon Shipping=[$SHIPPING_TOTAL]");
		#	}
		#else { 
		#	## Amazon shipping is the same.	
		#	}


		## it would be nice here to detect if amazon says it should be expedited shipping.
		}	## end of new order.

	#if (not $olm->can_proceed()) {
	#	}
	#elsif (not defined $o) {
	#	$olm->pooshmsg("ISE|+order not defined primary to adding payment");
	#	}
	#elsif (scalar(@{$o->payments('is_parent'=>1)})==0) {
	#	## add a payment if none-exist, it might be better to check for balance_due, but for now this is how we do it.
	#	
	#	}
        
    
	##
	## TAX CODE
	##
	## keep in mind that tax calculations for Amz syn and CBA are determined differently
	##		Amz syn uses tax settings from SellerCentral, District/City/County/State tax rates are transferred in the Order XML
	##		- tax rates are then added to the Zoovy order and a tax_total is calculated
	##		- because Amz calculates tax on a per item level, its tax total can be different from Zoovy's tax total by a cent
	##		CBA uses the tax rate from Zoovy via callbacks (comments changed to reflect callback implementation)
	##		- keep in mind that only the tax total is transferred in the Order XML
	##		- we don't get the rate from Amz, we use the rate determined by Zoovy
	if (not $olm->can_proceed()) {
		}
	elsif (($cart2{'sum/tax_total'} == 0) && ($ITEMS_TAXTOTAL + $SHIPPING_TAXTOTAL > 0)) {
		## hope our tax rates match amazons.
		$olm->pooshmsg("INFO|+ORDER tax_total: ".$cart2{'sum/tax_total'}." TOTAL_TAX: $ITEMS_TAXTOTAL SHIPTAX: $SHIPPING_TAXTOTAL");
		my (%taxinfo) = &ZSHIP::getTaxes($USERNAME,$O2->prt(),
			city=>$cart2{'ship/city'},
			state=>$cart2{'ship/region'},
			zip=>$cart2{'ship/postal'},
			country=>$cart2{'ship/country'}
			);
		# print 'TAXINFO: '.Dumper(\%taxinfo);			
		$cart2{'our/tax_zone'} = $taxinfo{'tax_zone'};
		$cart2{'our/tax_rate'} = $taxinfo{'tax_rate'};
		$cart2{'sum/tax_rate_zone'} = $taxinfo{'local_rate'};
		$cart2{'sum/tax_rate_state'} = $taxinfo{'state_rate'};
		}
	## check ORDER TOTAL and TAX TOTAL


	## seems to me .. in the code below, you'd always be comparing order_total to amazon_total, which is retreived from order_total
   #if (not $olm->can_proceed()) {
	#	## shit happened.
   #   }
	#else {
	#	$olm->pooshmsg("ISE|+order object not defined, could not recalculate");
	#	}

	if (not $olm->can_proceed()) {
		## shit happened.
		}
	elsif (int($amazon_order_total*100) != int($cart2{'sum/order_total'}*100)){
		my $ADJUST = undef;
		$olm->pooshmsg("WARN|+amazon totals did not match ours! amazon_total=[$amazon_order_total] our_total=[".$cart2{'sum/order_total'}."]");	
		if (abs(&ZOOVY::f2int($amazon_order_total*100)-&ZOOVY::f2int($cart2{'sum/order_total'}*100))<50) {
			$amazon_order_total = $cart2{'sum/order_total'};
			}
		else {
			$olm->pooshmsg("WARN|+alas, too much variance between the totals to set Amazon to our total");	
			}
		}

	#if (not $olm->can_proceed()) {
	#	## shit happened.
	#	}
	#elsif (int($amazon_order_total*100) != int($cart2{'sum/order_total'}*100)){
	#	my $ADJUST = undef;
	#	$olm->pooshmsg("WARN|+amazon totals did not match ours! amazon_total=[$amazon_order_total] our_total=[".$cart2{'sum/order_total'}."]");	
	#	#my $i_amazon_order_total = int($amazon_order_total*100);
	#	#my $i_zoovy_order_total = int($cart2{{'order_total'}*100);
	#	# perl -e '$x = int(34.41*100); $y = int(34.43*100); $diff = ($y-$x); print "Diff: $diff\n";' 
	#	my $i_amazon_order_total = &ZTOOLKIT::f2int($amazon_order_total*100);
	#	my $i_zoovy_order_total = &ZTOOLKIT::f2int($cart2{'sum/order_total'}*100);
	#	if ( int($ITEMS_TAXTOTAL * 100)!=int($cart2{'sum/tax_total'}*100) ) {
	#		$olm->pooshmsg("WARN|+Amazon Order Total difference appears to be caused by known tax issue (nothing to worry about), see webdoc for more info");
	#		my $difference = ($i_zoovy_order_total - $i_amazon_order_total);	# usually this will be a something like 1,2,3
	#		if ($difference <= $O2->stuff2()->count()) {
	#			## note: we should ONLY auto-correct the difference when it is less than $0.01 per item 
	#			## (so 6 items should have an allowed variance of $0.06)
	#			## note: designed2bsweet 2011-03-76122 had a single stid, qty 9 that had a tax variance of 0.06
	#			$olm->pooshmsg(sprintf("WARN|+Correcting Amazon Tax Issue by adding %.2f to order",$difference/100));
	#			$ADJUST = ($difference/100);
	#			}
	#		else {
	#			$olm->pooshmsg("WARN|+Cannot auto-correct tax in order, because the variance exceeds the number allowed.");
	#			}
	#		}		
	#	elsif ($i_amazon_order_total+1 == $i_zoovy_order_total) {
	#		## take a penny
	#		$olm->pooshmsg("INFO|+Amazon Order Total is less, adding 0.01");
	#		$ADJUST = 0.01;
	#		}
	#	elsif ($i_amazon_order_total-1 == $i_zoovy_order_total) {
	#		##	leave a penny
	#		$olm->pooshmsg("INFO|+Amazon Order Total is greater, subtracting 0.01");
	#		$ADJUST = -0.01;
	#		}
	#	else {
	#		$olm->pooshmsg("INFO|+Amazon Order variance exceeded allowed amount (0.01), nothing done [ao:$i_amazon_order_total==zo:$i_zoovy_order_total]");
	#		}

	#	if (defined $ADJUST) {
	#		## NOTE: $o->payments always returns an arrayref of payments
	#		my ($payrec) = @{$o->payments("is_parent"=>1,"tender"=>"AMAZON")};
	#		if (defined $payrec) {
	#			## WRONG: $payrec->{'amt'} = $amazon_order_total;
	#			$payrec->{'amt'} = $cart2{{'order_total'};
	#			}
	#		else {
	#			$o->add_payment("ADJUST",sprintf("%.2f",$ADJUST),'ps'=>'010',txn=>$cart2{{'/amazon_orderid'});	
	#			}
	#		#$o->add_payment("ADJUST",0.01,'ps'=>'010',txn=>$cart2{{'/amazon_orderid'});			
	#		#$o->add_payment("ADJUST",-0.01,'ps'=>'010',txn=>$cart2{{'/amazon_orderid'});			}
	#		$o->recalculate();
	#		}
	#	}
	#else {
	#	$olm->pooshmsg(sprintf("INFO|+Yippie! Amazon Total [$amazon_order_total] matches Zoovy Total %.2f",$cart2{{'order_total'}));
	#	}

	if ($olm->can_proceed()) {
		## LETS CREATE THIS ORDER	!!!!

		## FOR A FIX??
		# $params{'skip_inventory'} = 1;
		my %finalize_params = ();
		$finalize_params{'*LM'} = $olm;
		if ($cart2{'mkt/siteid'} eq 'cba') {
			## CHECKOUT BY AMAZON (CBA)
			$O2->in_set('want/create_customer',1);
			$finalize_params{'skip_ocreate'} = 0;
			$finalize_params{'skip_oid_creation'}++;	# cba orders already have our/orderid set
			# $finalize_params{'do_not_lock'}++;		# this makes it so the order isn't returned readonly (so we can still do an order_save)
			}
		else {
			## regular amazon order
			$finalize_params{'skip_ocreate'} = 1;
			if (($params{'verb'} eq 'FIXORDERS') && ($OUR_ORDERID ne '')) {
				$finalize_params{'skip_oid_creation'}++;	
				}
			}
		$finalize_params{'skip_save'}++;

		if ($cart2{'mkt/siteid'} eq 'cba') {
			$O2->add_payment('AMZCBA',$amazon_order_total,'ps'=>'010','txn'=>$cart2{'mkt/amazon_orderid'});
			}
		else {
			$O2->add_payment('AMAZON',$amazon_order_total,'ps'=>'010','txn'=>$cart2{'mkt/amazon_orderid'});
			}

		### report any finalize errors, add payments before we save.
		#if ($olm->has_win()) {
		#	# $olm->pooshmsg("SUCCESS|+".$O2->oid()." was finalized SUCCESSFULLY");
		#	}
		#else {
		#	# $olm->pooshmsg("ERROR|+ORDER:".$O2->oid()." had finalize error(s)");
		#	foreach my $msg (@{$olm->msgs()}) {
		#		my ($ref) = LISTING::MSGS::msg_to_disposition($msg);
		#		next if ($ref->{'_'} eq 'INFO');
		#		$O2->add_history(sprintf("FINALIZE %s[%s] ",$ref->{'_'},$ref->{'+'}));
		#		}
		#	} 	

		($olm) = $O2->finalize_order(%finalize_params);
		#if ($O2->oid() ne '') {
		#	## only save if we have an order id!
		#	$O2->order_save();
		#	}
		}
	else {
		$olm->pooshmsg("WARN|+Order creation was skipped due to previous errors");
		}


	## check UNQ ITEM COUNT (2: only count each item once, 4: include % items, 8: skip assembly children)
	# my $unq_zoovy_count = $O2->stuff2()->as_legacy_stuff()->count(2+4+8); 
	# my $unq_amz_count = 0;	
	# my $tot_zoovy_count = $O2->stuff2()->as_legacy_stuff()->count(4+8);
	# my $tot_amz_count = 0;
	#foreach my $item (@amz_items) {
	#	$tot_amz_count += $item->{'qty'};
	#	$unq_amz_count++;
	#	}
	#if ($unq_zoovy_count != $unq_amz_count){
	#	#$o->event("Uh-oh, the amazon item count does not seem to match! amazon_items=[$amz_count] zoovy_total=[$zoovy_count]");	
#
#		## AMAZON3::log_failure is undef
#		##AMAZON3::log_failure($userref,$DOCID,"Unique Item count, zcnt: $unq_zoovy_count acnt: $unq_amz_count order: ".$o->id());
#		$olm->pooshmsg("WARN|+ITEM count doesn't match. Zoovy: $unq_zoovy_count Amazon: $unq_amz_count");
#		} 
	

	#if (defined $O2) {	
	#	## why do we do this here -- it *normally* happens in user events??
	#	## process any orders with Supply Chain products
	#	my ($vcount,$vstuffref) = $o->fetch_virtualstuff();
	#	if ($vcount>0) {
	#		$o->event("INFO: processing Supply Chain order");
	#		require SUPPLIER;
	#		&SUPPLIER::process_order($O2);
	#		} ## virtual
	#	## need to save order
	#	$o->save(1);
	#	}
	
	## add to map table if new order
	if (not defined $O2) {
		}
	elsif ($options{'FIX_ORDER'}==1) {
		$olm->pooshmsg("WARN|+Fixed Amazon Order (did not remove inventory a second time)");
		warn "Since we're just fixing an order.. nothing else to do here.";
		}
	#elsif ($OUR_ORDERID ne '') && (not $IS_CBA_ORDER)) {
	#	$olm->pooshmsg(sprintf("WARN|+NOTE: %s has been replaced by %s",$OUR_ORDERID,$o->id()));
	#	}
	### only decrement if this is a new order, ie not a recreate
	#elsif (($OUR_ORDERID eq '') || ($IS_CBA_ORDER)) {
	#	## NOTE: eventually we'll need do some thing better here because $IS_CBA_ORDER could be true on a retry
	#	##			but we should PROBABLY do some type of smart inventory handling in the order itself, which we'll
	#	##			do eventually, so no sense inventing a square wheel here.
	#	## decrement inventory
	#	use INVENTORY;
	#	my $results = INVENTORY::checkout_cart_stuff2($USERNAME, $O2->stuff2(), $o->id());
	#	$o->event("Decremented Inventory");
	#	}



	if ($O2->is_order()) {
		}

	&DBINFO::db_user_close();

	untie %cart2;
	
	return($O2,$olm);
	}





1;


__DATA__

	<Message>
  <MessageID>1</MessageID>
  <OrderReport>
    <AmazonOrderID>058-0281716-8643530</AmazonOrderID>
    <AmazonSessionID>102-9757967-9801721</AmazonSessionID>
    <OrderDate>2005-11-28T14:23:01-08:00</OrderDate>
    <OrderPostedDate>2005-11-28T14:57:06-08:00</OrderPostedDate>
    <BillingData>
      <BuyerEmailAddress>theresafa@aol.com</BuyerEmailAddress>
      <BuyerName>theresa aragona</BuyerName>
      <BuyerPhoneNumber>2483409376</BuyerPhoneNumber>
    </BillingData>
    <FulfillmentData>
      <FulfillmentMethod>Ship</FulfillmentMethod>
      <FulfillmentServiceLevel>Standard</FulfillmentServiceLevel>
      <Address>
        <Name>Theresa Aragona</Name>
        <AddressFieldOne>3460 Summit Ridge Dr.</AddressFieldOne>
        <City>Rochester Hills</City>
        <StateOrRegion>Michigan</StateOrRegion>
        <PostalCode>48306</PostalCode>
        <CountryCode>US</CountryCode>
        <PhoneNumber>248-340-9376</PhoneNumber>
      </Address>
    </FulfillmentData>
    <Item>
      <AmazonOrderItemCode>49484274898731</AmazonOrderItemCode>
      <SKU>3710</SKU>
      <Title>Harley Davidson Duffel Bag Carry On Travel Bag</Title>
      <Quantity>1</Quantity>
      <ProductTaxCode>A_GEN_NOTAX</ProductTaxCode>
      <ItemPrice>
        <Component>
          <Type>Principal</Type>
          <Amount currency="USD">29.99</Amount>
        </Component>
        <Component>
          <Type>Shipping</Type>
          <Amount currency="USD">10.49</Amount>
        </Component>
        <Component>
          <Type>Tax</Type>
          <Amount currency="USD">0.00</Amount>
        </Component>
        <Component>
          <Type>ShippingTax</Type>
          <Amount currency="USD">0.00</Amount>
        </Component>
      </ItemPrice>
      <ItemFees>
        <Fee>
          <Type>Commission</Type>
          <Amount currency="USD">-6.07</Amount>
        </Fee>
      </ItemFees>
    </Item>
  </OrderReport>
</Message>

