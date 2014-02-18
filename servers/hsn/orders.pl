#!/usr/bin/perl

use strict;

##
## orders.pl [HSN]
##		./orders.pl type=orders user=patti prt=0 
##
##	- download orders from HSN ftp server
##	- upload tracking info back to HSN 
## - [tracking doc: https://view.hsn.net/WebDocuments/FileSpecs/856xml.pdf	
##
## NOTE: use delete_sample_orders.pl username to DELETE sample orders!!
##
##
use Date::Parse;
use XML::Simple;
use XML::Writer;
use Data::Dumper;

use lib "/httpd/modules";
use STUFF2;
use SYNDICATION;
use CART2;
use LUSER::FILES;
use POSIX qw(strftime);

##
## parameters: 
##		user=toynk prt=0
##		type=tracking|orders
##			DEBUGORDER=####-##-#####
##		REDO=filename 
##			RECREATE=2009-01-1234 (will recreate the stuff in the order)
##
my %params = ();
foreach my $arg (@ARGV) {
	if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}


if ($params{'type'} ne '') { 
	warn "!! type= should be verb=\n";
	$params{'verb'} = $params{'type'}; 
	}

if ($params{'verb'} eq 'create') {
	warn "!! verb=create should be verb=orders\n";
	$params{'verb'} = 'orders';
	}

## validate type
if ($params{'verb'} eq 'tracking') {
	}
elsif ($params{'verb'} eq 'orders') {
	}
elsif ($params{'verb'} eq 'credit') {
	}
else {
	die("Try a valid type=(orders, tracking, credit)\n");
	}

## date needed for XML feeds
my $DATE = strftime("%Y%m%d",localtime(time()));
my $TIME = strftime("%H%M",localtime(time()));

my $MKT_BITSTR = 26;
my $syn_name = 'HSN';
my $DST = 'HSN';
my $PS = '022';
my @USERS = (); 

## USER is defined, only run for this USER
if ($params{'user'} ne '')  {
	#if ((not defined $params{'profile'}) && (defined $params{'prt'})) {
	#	## if we get a prt, but not a profile, then lookup the profile
	#	$params{'profile'} = &ZOOVY::prt_to_profile($params{'user'},$params{'prt'});
	#	}
	if (not defined $params{'prt'}) {
		warn "prt not set , using zero\n";
		}
	$params{'prt'} = int($params{'prt'});
	
	my $udbh = &DBINFO::db_user_connect($params{'user'});
	my $pstmt = "select ID from SYNDICATION where USERNAME=".$udbh->quote($params{'user'}).
					# " and PROFILE=".$udbh->quote($params{'profile'}). 
					" and PRT=".int($params{'prt'})." and DSTCODE='HSN'";
	print STDERR $pstmt."\n";
	
	my ($ID) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();
	if ($ID>0) {
		print STDERR "FOUND ID: $ID\n";
		push @USERS, [ $params{'user'}, $params{'prt'}, $ID ];
		}
	}

## run for specific CLUSTER
elsif ($params{'user'} eq '' && $params{'cluster'} ne  '') {
	my $udbh = &DBINFO::db_user_connect("\@$params{'cluster'}");
	my $pstmt = "select USERNAME,PRT,ID,ERRCOUNT from SYNDICATION where DSTCODE='".$DST."' and IS_ACTIVE>0 ";
	print STDERR $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($USERNAME,$PRT,$ID,$ERRCOUNT) = $sth->fetchrow() ) {
		if ($ERRCOUNT>10) {
			print STDERR "USER:$USERNAME PRT:$PRT ID:$ID was skipped due to ERRCOUNT=$ERRCOUNT\n";
			}
		else {
			push @USERS, [ $USERNAME, $PRT, $ID ];
			print STDERR "USERNAME: $USERNAME $PRT\n";
			}
		}
	$sth->finish();
	&DBINFO::db_user_close();
	}

## die, we need user or cluster to run
else {
	die("Cluster or specific user is required!");
	}


## run thru each USER 
foreach my $set (@USERS) {
	my ($USERNAME,$PRT,$ID) = @{$set};
	## create LOGFILE for each USER/PROFILE
	my ($lm) = LISTING::MSGS->new($USERNAME,'logfile'=>"~/".lc($syn_name)."-%YYYYMM%.log");
	my ($so) = SYNDICATION->new($USERNAME,$DST,'PRT'=>$PRT,'ID'=>$ID);

	my $ERROR = '';
	tie my %s, 'SYNDICATION', THIS=>$so;


	## deactivate, too many errors
	if ($so->get('ERRCOUNT')>1000) {
		ZOOVY::confess($so->username(),"Deactivated $syn_name syndication for $USERNAME due to >1000 errors\n".Dumper($so),justkidding=>1);
		$so->deactivate();
		}

	## get orders 
	elsif ($params{'verb'} eq 'orders') { 
		$lm->pooshmsg("INFO|+Performing feed $params{'verb'}");

		## DOWNLOAD then ACK Orders
		&downloadOrders($so, $lm, %params);

		$lm->pooshmsg("INFO|+Finished feed $params{'verb'}");
		}

	## send tracking
	elsif ($params{'verb'} eq 'tracking') { 
		$lm->pooshmsg("INFO|+Performing feed $params{'verb'}");
		$so->save();

		&uploadTracking($so, $lm, %params);
		
		$so->set('TRACKING_LASTRUN_GMT',time());
		$so->save();

		$lm->pooshmsg("INFO|+Finished feed $params{'verb'}");
		}

	## send credits, needs major work
	#elsif ($params{'verb'} eq 'credit') {
		#my ($orderref) = &downloadOrders($so, $ftp, %params);
		#my ($XML) = createCredit($orderref);
		#print $XML."\n";
		#die();
		#}

	## unknown type
	else {
		$lm->pooshmsg("WARN|+Unknown feed type:$params{'verb'}");
		}

	}

exit 1; # success

##
## - find all orders with new tracking info
##	- create XML 
##	- upload to HSN
##	
##	valid params
##		=> DEBUGORDER
##

sub uploadTracking {
	my ($so, $lm, %params) = @_;

	my $USERNAME = $so->username();

	## return all HSN orders that have been shipped since tracking was last sent
	require ORDER::BATCH;
	#my ($list) = ORDER::BATCH::report($USERNAME,
	#	MKT_BIT=>$MKT_BITSTR,SHIPPED_GMT=>$so->get('TRACKING_LASTRUN_GMT'),PAID_GMT=>time()-(60*86400));
	## changed the query to look for last modified_gmt (TS) and also SHIPPED_GMT > 1
	## - this should resolve the issue we were having with merchants adding tracking to orders, syncing many hours later, and code missing order
	##
	## NOTE: PERIOD_TS is the CREATED_GMT, PAID_GMT, and SHIPPED_GMT (this reduces the potential result set and lets
	##			us use indexes better, DO NOT CHANGE THIS WITHOUT TALKING TO BRIAN)
	##			**BIG ISSUE** for toynk during xmas.
#	my ($PERIOD_TS) = (time()-(86400*60));
#	my ($list) = ORDER::BATCH::report($USERNAME,MKT_BIT=>$MKT_BITSTR,TS=>$so->get('TRACKING_LASTRUN_GMT'),PAID_GMT=>$PERIOD_TS,CREATED_GMT=>$PERIOD_TS,SHIPPED_GMT=>$PERIOD_TS);
#
#	if ($params{'DEBUGORDER'}) {
#		my $found = 0;
#		foreach my $set ( @{$list} ) {
#			if ($params{'DEBUGORDER'} eq $set->{'ORDERID'}) { 
#				$found++; 
#				$list = ();
#				push @{$list},$set;
#				}
#			}
#		if (not $found) {
#			die("ORDER: $params{'DEBUGORDER'} not in current list of orders to send.");
#			}
#		}

	## create a hash of senderid:receiverid per order object
	## so we can send one tracking feed XML per HSN receiverid /HSN sender id
	my %orders = ();

	my $trackinglist = $so->get_tracking();

	$lm->pooshmsg("INFO|Found ".scalar(@{$trackinglist})." orders to uploadTracking");
	
	foreach my $trackset (@{$trackinglist}) {
		my ($DBID, $ORDERID, $CARRIER, $TRACKING) = @{$trackset};
		my ($O2) = CART2->new_from_oid($USERNAME,$ORDERID);

		my $senderid = $O2->in_get('mkt/hsn_senderid');		## send as receiver id with tracking
		my $receiverid = $O2->in_get('mkt/hsn_receiverid'); ## send as sender id with tracking
		
		$orders{$senderid.":".$receiverid.":".$O2->id()} = $O2;
		}
	
	my @order_cnt = keys %orders;
	$lm->pooshmsg("INFO|Found ".scalar(@order_cnt)." orders to uploadTracking");
	foreach my $key (keys %orders) {
		my ($senderid, $receiverid, $id) = split(/:/,$key);
		my $O2 = $orders{$key};
		my $erefid = $O2->get('mkt/erefid');	

		$lm->pooshmsg("INFO|Found ".$O2->oid()." : ".$erefid);
		## SANITY: at this point @TRACKING is an array of tracking #'s
		if ($erefid eq '') {
			$lm->pooshmsg("WARN|+$erefid erefid (hsn.com receipt-id) is not set");
			}
		elsif ($O2->get('flow/shipped_ts')==0) {
			$lm->pooshmsg("WARN|+".$O2->id()." is not flagged as shipped.");
			}
		elsif (scalar(@{$O2->tracking()})==0) {
			$lm->pooshmsg("WARN|+".$O2->oid()." no tracking in order.");
			}
		else {
			my $xCBL = '';
			my $writer = new XML::Writer(OUTPUT => \$xCBL, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');
	$writer->startTag("HSN_DROPSHIP", "FUNCTIONAL_ID"=>"SH", "INTERCHANGE_SENDER_ID"=>"$receiverid",
			"INTERCHANGE_RECEIVER_ID"=>"$senderid", "DATE"=>$DATE, "TIME"=>$TIME, 
			"VENDOR_ID"=>$so->get('.vendorid'), "GS_CNTRL_NUM"=>46);
		$writer->startTag("SHIP_CONFIRM_LIST");
			$writer->startTag("SHIP_CONFIRM");
				$writer->dataElement("ORDER_NUMBER",$erefid);
				
				## per HSN docs, https://view.hsn.net/WebDocuments/FileSpecs/856xml.pdf
				## SHIPPING_HANDLING shouldnt have decimals, ie 2.00 => 200
				## HSN (via Katy) reporting that shipping_handling has to be set to 150
#				my $shipping_handling = $O2->get('sum/shp_total');
#				$shipping_handling =~ s/\.//;  
				my $shipping_handling = 150;
				$writer->dataElement("SHIPPING_HANDLING",$shipping_handling);
				my $SHIP_DATE = strftime("%Y%m%d",localtime($O2->get('flow/shipped_ts')));
				$writer->dataElement("SHIP_DATE",$SHIP_DATE);

			foreach my $trk (@{$O2->tracking()}) {
				$writer->dataElement("TRACKING_NUMBER",$trk->{'track'});
				}
				
				$writer->dataElement("INVOICE_NUMBER",$O2->oid());
			$writer->endTag("SHIP_CONFIRM");
		$writer->endTag("SHIP_CONFIRM_LIST");
	$writer->endTag("HSN_DROPSHIP");

			### SANITY: XML is defined, time to ftp to HSN
			my $SUCCESS = 0;
			my $remote_file = 'tracking'.$erefid.'.xml';  ## not sure what they want here
			my $local_file = $DST."Track".$DATE.$TIME.".xml";
			## store the file to private files.
			my ($lf) = LUSER::FILES->new($USERNAME, 'app'=>'HSN');
			$lf->add(
				buf=>$xCBL,
				type=>$DST,
				title=>$local_file,
				meta=>{'DSTCODE'=>$DST,'PROFILE'=>$so->profile(),'TYPE'=>$params{'type'}},
				);

			$lm->pooshmsg("INFO|+wrote private file : $local_file");
			my $path = ZOOVY::resolve_userpath($so->username())."/PRIVATE/";
			#my ($ERROR) = &transfer_ftp_put($so,$lm,$so->get('.url'),$path.$local_file,$remote_file);
			## useSSL is absolutely necessary for HSN
			my $useSSL = 1;
			my ($ERROR) = $so->transfer_ftp($so->get('.url'),[{'in'=>$path.$local_file,'out'=>$remote_file}]);
			
			if ($ERROR ne '') {
				$lm->pooshmsg("ERROR-FTP-PUT|+$ERROR");
				&ZOOVY::confess(
					$USERNAME,
					"$DST got ftp error while sending tracking (will retry)\nERROR: $ERROR\nFILENAME:$local_file\nxml:$xCBL\n",
					justkidding=>1
					);
				}
			else {
				$lm->pooshmsg("INFO|+successfully ftp'ed ".$remote_file);
				$so->ack_tracking($trackinglist);
				}
			}
		}
	}


##
## - download the most recent orders from HSN
##	- create orderref from XML
##	- assign values to CART
##	- use CART to create order
##
sub downloadOrders {
	my ($so, $lm, %params) = @_;

	my $USERNAME = $so->username();
	my $ORDERTS = 0;
	my @ORDERSXML = ();
	my $orderref = ();
	my $ERROR = '';
	my @oids = ();		## only used for pretty output
	my $modified_gmt = 0;

	## create order if no $ERROR
	if ($ERROR eq '') {
		## recreate order from existing file: REDO
		if ($params{'REDO'} ne '') {
			$lm->pooshmsg("INFO-REDO|+create orders for file: ".$params{'REDO'});
			## redo an import (perhaps there was an issue?)
			open F, "<$params{'REDO'}";
			$/ = undef; my ($str) = <F>; $/ = "\n";
			close F;
			push @ORDERSXML, [ $params{'REDO'}, $str ];
			
			}
		## use XML returned from get
		else {
			## believe it's refreshed daily at approx 3am
			## we dont really need @ORDERSXML if there's only one file
			#my $remote_file = 'PO41934885010282010.xml';
			

			## ftp download orders.
			## NOTE!!: this subroutinue has been added in this code!
			##		it uses a special PORT, etc for HSN
			(my $ordersxml,$modified_gmt) = &transfer_ftp_get($so,$lm,$so->get('.url'));
			$lm->pooshmsg("INFO|+Last modified time : $modified_gmt");

			@ORDERSXML = (@{$ordersxml});
			} ## end of else
		}

	##
	## SANITY: at this stage we have  @ORDERSXML = ( [ $filename, $xmlcontents ] );
	##
	if ($ERROR eq '') {

		foreach my $info (@ORDERSXML) {
			my ($local_file, $xml) = @{$info};
			my $lc = 0;		# line count

			my $ctr = 0;
			($orderref) = XML::Simple::XMLin($xml,ForceArray=>1,ContentKey=>'_');
			foreach my $order (@{$orderref->{'ORDERS'}[0]->{'ORDER'} }) {
				print Dumper($order);

				my $erefid = $order->{'ORDER_NUM'}[0];
				my ($ordsumref) = $so->resolve_erefid($erefid);
	
				my $previous_orderid = undef;	
				if (defined $ordsumref) {
					$previous_orderid = $ordsumref->{'ORDERID'};
					print STDERR "INFO-ORDER|+It appears $erefid is already created as ".$ordsumref->{'ORDERID'};
					$lm->pooshmsg("INFO-ORDER|+It appears $erefid is already created as ".$ordsumref->{'ORDERID'});
					}
				else {
					$lm->pooshmsg("INFO-ORDER|+erefid $erefid appears to be a new order");
					}
				## these lines are helpful, they stop me from being an idiot.
				print STDERR "$previous_orderid REDO: ".$params{'REDO'}." RECREATE: ".$params{'RECREATE'}."\n";
				next if ((defined $previous_orderid) && (not defined $params{'REDO'}) && (not defined $params{'RECREATE'}));
				next if ((defined $previous_orderid) && ($params{'RECREATE'} ne $previous_orderid)); 
	
				my ($CART2) = CART2->new_memory($USERNAME);
				my @EVENTS = ();
				my %cart2 = ();
				tie %cart2, 'CART2', 'CART2'=>$CART2;
		
			   $cart2{'our/sdomain'} = 'hsn.com';
				$cart2{'mkt/erefid'} = $erefid;
				$cart2{'mkt/hsn_orderid'} = $order->{'ORDER_NUM'}[0];
				$cart2{'mkt/hsn_customer_num'} = $order->{'CUSTOMER_NUM'}[0];
				$cart2{'mkt/hsn_payment_method'} = $order->{'PAY_METHOD'}[0];
				$cart2{'mkt/hsn_credit_amount'} = &fix_decimal($order->{'CREDIT_AMOUNT'}[0]);
				$cart2{'our/payment_method'} = $syn_name;
				$cart2{'flow/payment_status'} = $PS; 
				## no balance due, we are adding payment further down in code, dont need ZPAY to handle
				$cart2{'must/payby'} = 'ZERO'; 		
				$cart2{'want/order_notes'} = $syn_name."Order # ".$erefid;
				
				## these values are needed to uploadTracking back to HSN
				$cart2{'mkt/hsn_senderid'} =  $orderref->{'INTERCHANGE_SENDER_ID'};
				$cart2{'mkt/hsn_receiverid'} = $orderref->{'INTERCHANGE_RECEIVER_ID'};

				$cart2{'bill/phone'} = $order->{'PHONE_NUM'}[0];
				
				my $email = '';
				if (ref($order->{'EMAIL_ADDRESS'}[0]) eq 'SCALAR' && $order->{'EMAIL_ADDRESS'}[0] ne '') {
					$email = $order->{'EMAIL_ADDRESS'}[0];
					}
				
				$cart2{'bill/email'} = $email;
				if ($order->{'SENDER_NAME'}[0] ne '' && ref($order->{'SENDER_NAME'}[0]) ne 'HASH') {
					($cart2{'bill/lastname'}, $cart2{'bill/firstname'}) = split(/[\s]+/,$order->{'SENDER_NAME'}[0],2);
					}
				else {
					($cart2{'bill/lastname'}, $cart2{'bill/firstname'}) = split(/[\s]+/,$order->{'SHIP_NAME'}[0],2);
					}
				($cart2{'ship/lastname'}, $cart2{'ship/firstname'}) = split(/[\s]+/,$order->{'SHIP_NAME'}[0],2);
		
				$cart2{'ship/address1'} = $order->{'SHIP_ADDRESS_LINE_1'}[0];
				if ($order->{'SHIP_ADDRESS_LINE_2'}[0] ne '' && ref($order->{'SHIP_ADDRESS_LINE_2'}[0]) ne 'HASH') {
					$cart2{'ship/address2'} = $order->{'SHIP_ADDRESS_LINE_2'}[0];
					}
				$cart2{'ship/city'} = $order->{'SHIP_CITY'}[0];
				$cart2{'ship/region'} = $order->{'SHIP_STATE'}[0];
				$cart2{'ship/postal'} = $order->{'SHIP_ZIP_CODE'}[0];
				if ($cart2{'ship/postal'} =~ /(\d\d\d\d\d)(\d\d\d\d)/) {
					## HSN is sending 665230000, need to convert to 66523-0000
					$cart2{'ship/postal'} = $1.'-'.$2;
					}	
			
				$cart2{'ship/country'} = 'US';
	 	
				## 20111115
				#my $CREATED = ZTOOLKIT::mysql_to_unixtime($order->{'ORDER_DATE'}[0].'000000');
				#if ($CREATED>$ORDERTS) { $ORDERTS = $CREATED; } 	# keep a high watermark for order timestamps.


				# my ($s) = $CART->stuff();
				## only getting one item per order, HSN splits order (into different order nums) before we 'get' it
				## note: options are not currently supported.
				# my $full_product = &ZOOVY::fetchsku_as_hashref($USERNAME,$order->{'VENDOR_UPC'}[0]);
				my ($P) = PRODUCT->new($USERNAME,$order->{'VENDOR_UPC'}[0]);
				my $SKU = ($order->{'VENDOR_UPC'}[0] eq '')?$order->{'VENDOR_ITEM_NUM'}[0]:$order->{'VENDOR_UPC'}[0];

				my $product_price = &fix_decimal($order->{'SALE_AMOUNT'}[0]);
				if ($product_price == 0.00) {
					$product_price = $P->fetchsku($SKU,'sku:price'); # $full_product->{'zoovy:base_price'};
					$cart2{'is/giftorder'} = 1;
					}

				#my $itemref = { 
				#	'mkt'=>$DST,
				#	# 'auto_detect_options'=>1, 	# moved to cram parameters.
				#	'mktid'=>$order->{'HSN_ITEM_NUM'}[0],
				#	'sku'=>$SKU,
				#	'product'=>$product,
				#	'qty'=>int($order->{'QUANTITY'}[0]),
				#	'force_qty'=>int($order->{'QUANTITY'}[0]),
				#	# 'base_price'=>int($order->{'SALE_AMOUNT'}[0])==0?'1.50':$order->{'SALE_AMOUNT'}[0],
				#	'base_price'=>sprintf("%.2f",$product_price),
				#	'description'=>$order->{'ITEM_DESCR'}[0],
				#	'prod_name'=>$order->{'ITEM_DESCR'}[0],
				#	'full_product'=>$full_product,
				#	};
			
				my $suggested_variations = $P->suggest_variations('stid'=>$SKU,'guess'=>1);
				my $selected_variations = &STUFF2::variation_suggestions_to_selections($suggested_variations);
				if ($order->{'GIFT_HEADER'}[0] ne '' || $order->{'GIFT_MESSAGE'}[0] ne '') {
					#print STDERR "ADD GIFT MSG!!: ".$order->{'GIFT_HEADER'}[0]." ".$order->{'GIFT_MESSAGE'}[0];
					#$itemref->{'%options'} = {};
					my $gift_message = '';
					if ($order->{'GIFT_HEADER'}[0] ne '') {
						$gift_message = "==".$order->{'GIFT_HEADER'}[0]."==\n";
						}
					if ($order->{'GIFT_MESSAGE'}[0] ne '') {
						$gift_message .= $order->{'GIFT_MESSAGE'}[0];
						}
					# $itemref->{'%options'}->{'##'} = "~".$gift_message;
					$selected_variations->{'##'} = "~".$gift_message;
					$cart2{'is/giftorder'} = 1;
					}
				my ($item,$ilm) = $CART2->stuff2()->cram( $SKU, int($order->{'QUANTITY'}[0]), $selected_variations, 
					'force_price'=>$product_price, 
					'force_quantity'=>int($order->{'QUANTITY'}[0]),
					'*P'=>$P
					);
				$item->{'mkt'} = $DST;
				$item->{'mktid'} = $order->{'HSN_ITEM_NUM'}[0];
				$item->{'prod_name'} = $order->{'ITEM_DESCR'}[0],
				$lm->merge($ilm);
	
				#print "ITEMREF: ".Dumper($itemref);
				#print "CART: ".Dumper(\%cart);

				## check for Gift Msg

				# ($ERROR, my $msg) = $s->legacy_cram($itemref, 'make_pogs_optional'=>1, 'auto_detect_options'=>1);			
				#if ($previous_orderid) {
				#	my ($o) = ORDER->new($USERNAME,$previous_orderid);
				#	if ($o->stuff()->digest() ne $s->digest()) {
				#		$o->{'stuff'} = $s2->as_legacy_stuff();						
				#		$o->event("Reset stuff. original order digest:".$o->stuff()->digest());
				#		$o->save();
				#		}
				#	die("done with redid stuff");
				#	}

				## HANDLING 			
				$CART2->surchargeQ('add','hnd',&fix_decimal($order->{'HANDLING_CHARGE'}[0]),'Handling',0,2);
				#$cart2{{'ship/hnd_method'} = 'Handling';
				#$cart2{{'ship/hnd_total'} = &fix_decimal($order->{'HANDLING_CHARGE'}[0]);
	
				## TAX
				$CART2->surchargeQ('add','tax',&fix_decimal($order->{'TAX_AMOUNT'}[0]),'Tax',0,2);
				# $cart2{{'data/tax_total'} = &fix_decimal($order->{'TAX_AMOUNT'}[0]);
	
				## SHIPPING, not really confident about these 'selected_carriers'


				my $ship_total = &fix_decimal($order->{'SHIPPING_CHARGE'}[0]);
				# $cart2{{'data/shp_total'} = $ship_total;

				## GROUND
				if ($order->{'SHIP_MODE'}[0] == 10) {
					$CART2->set_mkt_shipping('Standard Shipping',$ship_total,'carrier'=>'SLOW');
					#$cart2{{'ship/selected_price'} = $ship_total;
					#$cart2{{'ship/selected_carrier'} = "STD";
					#$cart2{{'ship/selected_method'} = 'Standard Shipping';
					}
				## EXPRESS
				elsif ($order->{'SHIP_MODE'}[0] == 20) {
					$CART2->set_mkt_shipping('Expedited Shipping',$ship_total,'carrier'=>'FAST');
					# $cart2{{'ship/selected_price'} = $ship_total;
					#$cart2{{'ship/selected_carrier'} = "EXP";
					#$cart2{{'ship/selected_method'} = 'Expedited Shipping';
					}
				## 2 DAY
				elsif ($order->{'SHIP_MODE'}[0] == 25) {
					$CART2->set_mkt_shipping('2 Day Shipping',$ship_total,'carrier'=>'2DAY');
					#$cart2{{'ship/selected_price'} = $ship_total;
					#$cart2{{'ship/selected_carrier'} = "2DA";
					#$cart2{{'ship/selected_method'} = '2 Day Shipping';
					}
				## FREIGHT???
				elsif ($order->{'SHIP_MODE'}[0] == 30) {
					$CART2->set_mkt_shipping('Freight',$ship_total,'carrier'=>'FRT');
					#$cart2{{'ship/selected_price'} = $ship_total;
					#$cart2{{'ship/selected_carrier'} = "FRT";
					#$cart2{{'ship/selected_method'} = 'Freight Shipping';
					}
				else {
					$lm->pooshmsg("ERROR|+HSN.com got something [".$order->{'SHIP_MODE'}[0]."] other than 10, 20, 25 in SHIP_MODE");
					#ZOOVY::confess($USERNAME,"HSN.com got something [".$order->{'SHIP_MODE'}[0]."] other than 10, 20, 25 in SHIP_MODE");
					}

				$CART2->guess_taxrate_using_voodoo(&fix_decimal($order->{'TAX_AMOUNT'}[0]),src=>$DST,events=>\@EVENTS);

				## 		
				my @PAYMENTS = ();
				my $order_total = $cart2{'mkt/hsn_credit_amount'} + &fix_decimal($order->{'TOTAL_AMOUNT'}[0]);
				$lm->pooshmsg("INFO|+Order total: ".$order_total);
				push @PAYMENTS, [ $syn_name, $order_total, {ps=>$PS, txn=> $erefid} ];
				

				my ($orderid,$success,$o,$ERROR) = &CHECKOUT::finalize($CART2,
					orderid=>$previous_orderid,
					use_order_cartid=>sprintf("%s",$erefid),
					email_suppress=>1,
					'@payments'       =>\@PAYMENTS,
					);
	
				if ($ERROR eq '') {
					## save order, add to saved order list
					$CART2->order_save();
					push @oids,$CART2->oid();
					$lm->pooshmsg("INFO|+Added ".$o->id()." for erefid: ".$erefid);

					
					}
				else {
					$lm->pooshmsg("ERROR|+$ERROR");					
					}

				## let's only do one order for testing
				#last if $ctr++>1;

				}
			
			## ACK all orders for this file (even if they've already been created)
			##  no harm in re-ACK'ing (ie looks like HSN keeps all orders avail currently)
			($ERROR) = &ackOrders($so, $lm, $orderref);
			}
		}
		
	## should we still save this if there was an ERROR??
	## getting updated with the last modified_gmt of the file we "got"
	if ($modified_gmt>0) {
		$lm->pooshmsg("INFO|+ORDERS_LASTRUN_GMT set to $modified_gmt");
		$so->set('ORDERS_LASTRUN_GMT',$modified_gmt);
		$so->save();
		}
	
	## report back success/errors
	if ($ERROR eq '' || $ERROR == 0) {
		$lm->pooshmsg("INFO|+CREATED the following orders: ".join("\n",@oids));
		}
	else {
		$lm->pooshmsg("INFO|+ERROR: $ERROR");
		}	

	return($ERROR,$orderref);
	}

##
## go thru hashref of orders returned from downloadOrders (ie XML contents of ftp'ed file from HSN)
## - count how many orders grabbed from HSN
##	- and how many of those orders were successfully created in Zoovy
## - return info to HSN, and log it
##
## HSN docs: https://view.hsn.net/WebDocuments/FileSpecs/997xml.pdf
##
sub ackOrders {
	my ($so, $lm, $orderref) = @_;

	$lm->pooshmsg("INFO_ACK|+Starting to ACK");

	my $ERROR = '';
	my $total_ord_cnt = 0;
	my $created_ord_cnt = 0;
	foreach my $order (@{$orderref->{'ORDERS'}[0]->{'ORDER'}}) {
		$total_ord_cnt++;
		my ($ordsumref) = $so->resolve_erefid($order->{'ORDER_NUM'}[0]);
		## order created successfully
		if (defined $ordsumref) {
			print "ORDER: ".$order->{'VENDOR_NUM'}[0]."\n" ;
			$created_ord_cnt++;
			}
		## uh-oh, order didnt get created
		else {
			$lm->pooshmsg("INFO|+problem creating ".$order->{'VENDOR_NUM'}[0]. " for feed, can't ACK:".$orderref->{'GS_CNTRL_NUM'});
			}
		}

	$lm->pooshmsg("INFO|+acking $created_ord_cnt out of $total_ord_cnt for ".$orderref->{'GS_CNTRL_NUM'});
	
	if ($created_ord_cnt == 0) {
		## no need to send an ACK
		#$ERROR = "No orders successfully created!!!";
		$created_ord_cnt = 1;
		}
		
	
	if ($ERROR eq '') {	
		## ACK orders file
		my $xCBL = '';
		my $writer = new XML::Writer(OUTPUT => \$xCBL, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');
		$writer->startTag("HSN_DROPSHIP", "FUNCTIONAL_ID"=>"FA", "INTERCHANGE_SENDER_ID"=>"$orderref->{'INTERCHANGE_RECEIVER_ID'}",
				"INTERCHANGE_RECEIVER_ID"=>"$orderref->{'INTERCHANGE_SENDER_ID'}", "DATE"=>$DATE, "TIME"=>$TIME, 
				"VENDOR_ID"=>$so->get('.vendorid'), "GS_CNTRL_NUM"=>$orderref->{'GS_CNTRL_NUM'});
				$writer->startTag("ACK_LIST");
					$writer->startTag("ACK");
					$writer->dataElement("FUNCTIONAL_GROUP_RESPONSE_HEADER", $orderref->{'GS_CNTRL_NUM'});
					$writer->dataElement("FUNCTIONAL_GROUP_CODE","PO");
					$writer->dataElement("ACKNOWLEDGE_CODE","A");
					$writer->dataElement("NUMBER_OF_INCLUDED_SETS","$total_ord_cnt");
					$writer->dataElement("NUMBER_OF_RECEIVED_SETS","$total_ord_cnt");
					$writer->dataElement("NUMBER_OF_ACCEPTED_SETS","$total_ord_cnt");
					$writer->endTag("ACK");
				$writer->endTag("ACK_LIST");
		$writer->endTag("HSN_DROPSHIP");

		my $remote_file = "orderAck.xml";
		my $local_file = $DST."Ack".$DATE.$TIME."_".$orderref->{'GS_CNTRL_NUM'}.".xml";
		## store the file to private files.
		my ($lf) = LUSER::FILES->new($so->username(), 'app'=>'HSN');
			$lf->add(
			buf=>$xCBL,
			type=>$DST,
			title=>$local_file,
			meta=>{'DSTCODE'=>$DST,'PROFILE'=>$so->profile(),'TYPE'=>$params{'type'}},
			);
	
		$lm->pooshmsg("INFO|+wrote private file : $local_file");

		my $path = ZOOVY::resolve_userpath($so->username())."/PRIVATE/";
		($ERROR) = $so->transfer_ftp($so->get('.url'),[{'in'=>$path.$local_file,'out'=>$remote_file}]);

		if ($ERROR ne '') {
			$lm->pooshmsg("ERROR-FTP-PUT|+$ERROR");
			}
		}

	$lm->pooshmsg("INFO_ACK|+Finishing ACK");
	
	return($ERROR);	
	}


sub createCredit {
	my ($orderref) = @_;

	my $order_cnt = 0;
	foreach my $order (@{$orderref->{'ORDERS'}[0]->{'ORDER'} }) {
		print "ORDER: ".$order->{'VENDOR_NUM'}[0]."\n" ;
		$order_cnt++;
		}
#	print Dumper($orderref);
#die();

	## CREDIT orders file
	## https://view.hsn.net/WebDocuments/FileSpecs/997xml.pdf
	my $credit_xml = qq~
<HSN_DROPSHIP FUNCTIONAL_ID="CD" INTERCHANGE_SENDER_ID="$orderref->{'INTERCHANGE_RECEIVER_ID'}" INTERCHANGE_RECEIVER_ID="$orderref->{'INTERCHANGE_SENDER_ID'}" DATE="$DATE" TIME="0939" VENDOR_ID="$orderref->{'VENDOR_ID'}" GS_CNTRL_NUM="47">
	<RETURN_LIST>~;

	foreach my $order (@{$orderref->{'ORDERS'}[0]->{'ORDER'}}) {
		$credit_xml .= qq~
		<RETURN>
			<ORDER_NUMBER>$order->{'ORDER_NUM'}[0]</ORDER_NUMBER>
			<PRODUCT_ID>$order->{'HSN_ITEM_NUM'}[0]</PRODUCT_ID>
			<QUANTITY>$order->{'QUANTITY'}[0]</QUANTITY>
			<REASON_CODE>03</REASON_CODE>
			<RETURN_DATE>$DATE</RETURN_DATE>
		</RETURN>~;
		}

	$credit_xml .= qq~
	</RETURN_LIST>
</HSN_DROPSHIP>~;

	return($credit_xml);
	}

##
## [copied from SYNDICATION::transfer_ftp]
## Edited to do gets, using an SSL connection
## FILES is an array which can only contain scalars
##	scalar: [$FILENAME]	(the input file -- only compatible with single file transfers)
##
sub transfer_ftp_get {
	my ($so,$lm,$URL,$FILE) = @_;

	my @ORDERSXML = ();
	## this will passed back to update ORDER_LASTRUN_GMT
	## be sure to grab the most recent modified_gmt (from all the order files)
	my $max_modified_gmt = 0;
	
	my ($USER) = $so->get('.order_ftp_user');  # WRONG - this uses .order_ftp_user (which is stupid ecause it's ftps)
	my ($PASS) = $so->get('.order_ftp_pass');
	my ($HOST) = $so->get('.order_ftp_server');		

	$lm->{'STDERR'} = 1;

	if ($HOST =~ /^ftp\:\/\//i) { 
		$lm->pooshmsg("ERROR|+field .order_ftp_server should NOT have an ftp:// in it");
		}

	## the order ftp user/pass is different than the syn ftp user/pass
	if ($USER =~ / /) { $lm->pooshmsg("ERROR|+field .order_ftp_user has space (not allowed)"); }
	if ($PASS =~ / /) { $lm->pooshmsg("ERROR|+field .order_ftp_pass has space (not allowed)"); }

	my $PORT = 990;	## specific to HSN
		
	print STDERR 'DIAGS:'.Dumper({$USER,$PASS,$HOST});

	my $ftp = ();
	my $rc = '';
	## connect to ftps server
	if ($lm->can_proceed()) {
		use Net::FTPSSL;
		$ftp = Net::FTPSSL->new($HOST, Port=>$PORT, Trace=>1, useSSL => 1, Debug => 1, Encryption => IMP_CRYPT);
		print STDERR "FTPSERV:[$HOST] FUSER: $USER FPASS: $PASS\n";
		if (not defined $ftp) { $lm->pooshmsg("ISE|+Unknown FTP server $HOST"); }
		}

	## login to server
	if ($lm->can_proceed()) {
		$rc = $ftp->login($USER,$PASS);	
		print STDERR "RC: $rc\n";
		if ($rc!=1) { $lm->pooshmsg('ERROR|+FTP User/Pass invalid.'); }
		}

	## change dir and get file
	if ($lm->can_proceed()) {
		$ftp->pasv();

		## go thru all files, 
		## see which ones have been modified since the last time this code ran
		my $file_cnt = 0;
		
#		print Dumper('LIST',$ftp->list("/orders"));
#		print Dumper('NLST',$ftp->nlst("/orders"));

		$lm->pooshmsg("INFO|+starting file list");
		
		## NOTE: 9/12/12 -- this was blank changed to /orders (not sure what is correct)
		foreach my $new_file ($ftp->nlst("/orders")) {
			## only PO files need to be processed
			print "FILE: $new_file\n";
			next unless $new_file =~ /^PO/;
			print $new_file."\n";
			
			my $modified = $ftp->mdtm($new_file)."\n";
			## 20111122235242
			if ($modified =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/) {
				my ($date) = ("$1-$2-$3 $4:$5:$6 MST");
				my $file_modified_gmt = ZTOOLKIT::gmtime_to_unixtime($date);
				$lm->pooshmsg("INFO|+Found file: $new_file date: $date file_modified_gmt: $file_modified_gmt orders_lastrun_gmt: ".$so->get('ORDERS_LASTRUN_GMT'));

				## only go thru this file if its greater than the last run time
				if ($file_modified_gmt > $so->get('ORDERS_LASTRUN_GMT')) {
					if ($ftp->get($new_file,"/tmp/$new_file")) {
						$lm->pooshmsg("INFO-FTP|+FTP GET $new_file");
						open(FILE,"/tmp/$new_file") or $lm->pooshmsg("ISE|+Can't open local file: /tmp/$new_file");
					
						my $XML = '';
						while(<FILE>) { $XML .= $_; } 
						close(FILE);
						
						if ($lm->can_proceed()) {			
							my $local_file = "HSNOrder_".$new_file;
							my $full_path = &ZOOVY::resolve_userpath($so->username())."/PRIVATE/HSNOrder_".$new_file;

							if (-e $full_path) {
								$lm->pooshmsg("INFO-ORDER|+no create, file already exists");
								}
							else {
								$lm->pooshmsg("INFO-ORDER|+create orders for file: $local_file");
								## store the file to private files.
								my ($lf) = LUSER::FILES->new($so->username(), 'app'=>'HSN');
								$lf->add(
									buf=>$XML,
									type=>'SYNDICATION',
								title=>$local_file,
								meta=>{'DSTCODE'=>$DST,'PROFILE'=>$so->profile(),'TYPE'=>'SYNDICATION'},
									);
								}

							push @ORDERSXML, [ $full_path, $XML ];

							## return the most recent modified gmt
							if ($file_modified_gmt > $max_modified_gmt) {	
								$max_modified_gmt = $file_modified_gmt;
								}
							$file_cnt++;
							}
						}
					else {
						$lm->pooshmsg("ERROR|+FAILED ON FILE=$new_file");
						}
						
					}
				}
			}
		$lm->pooshmsg("INFO-ORDER|+Found $file_cnt new files to process");
		}


	#print STDERR "XML: $XML\n";
	
	## quit and check XML contents
	if ($lm->can_proceed()) {
		$ftp->quit;
		#if ($XML eq '') {
		#	$ERROR = "XML contents are blank.";
		#	}
		}

	return(\@ORDERSXML,$max_modified_gmt);
	}

sub fix_decimal {
	my ($value) = @_;
	
	print STDERR "INPUT: $value\n";
	my $output = sprintf('%.2f',$value);
	print STDERR "OUTPUT: $output\n";
	
	return($output);
	}

exit;

