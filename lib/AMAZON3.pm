package AMAZON3;


##
## primary XSD https://images-na.ssl-images-amazon.com/images/G/01/rainier/help/xsd/release_1_9/amzn-envelope.xsd
##

#CA https://mws.amazonservices.ca
#CN https://mws.amazonservices.com.cn
#DE https://mws-eu.amazonservices.com
#ES https://mws-eu.amazonservices.com
#FR https://mws-eu.amazonservices.com
#IT https://mws-eu.amazonservices.com
#JP https://mws.amazonservices.jp
#UK https://mws-eu.amazonservices.

##
## AMAZON3
##	
##		http://mws.amazon.com/docs/devGuide/
##
##	changes for MWS functionality
##	- use of XML post vs SOAP/DIME
##	- 

use strict;

use File::Slurp;
use JSON::XS;

use XML::Smart;
use Carp;
use POSIX qw(strftime);
#use DIME::Parser;
use Data::UUID;
use XML::Writer;
use Digest::MD5;
use Digest::HMAC_SHA1;
use MIME::Base64;
use URI::Escape;
use LWP;
use LWP::UserAgent;
use HTTP::Headers;
use HTTP::Request::Common;
use HTTP::Cookies;
use XML::Parser;
use XML::Parser::EasyTree;
use XML::SAX::Simple;
use IO::Scalar;
use IO::String;

use lib "/backend/lib";
require PRODUCT;
require PRODUCT;
require ZTOOLKIT;
require TXLOG;
require LISTING::MSGS;
require XMLTOOLS;
require DBINFO;
require ZTOOLKIT::XMLUTIL;
require ZTOOLKIT::FAKEUPC;
require SYNDICATION;
require INVENTORY2;

$::PRODUCTION = 1;

#
# AMAZON_PID_UPCS:
# FEEDS_DONE <-- feeds that have been done.  (no longer used)
# FEEDS_SENT <-- feeds that have been sent to amazon
# FEEDS_WAIT <-- feeds that are waiting
# FEEDS_TODO <-- feeds that need to be run.
# FEEDS_ERROR <-- which of the feeds (if any) had an error.
#
# when FEEDS_DONE == FEEDS_TODO - the product is fully on amazon (all feeds current).
# when FEEDS_TODO > 0 -- one or more feeds needs to be sent.
# when FEEDS_DONE == 0 -- this is a new product, or a reset product.
# when FEEDS_TODO = 0xFFFF - this product should be deleted.
# when FEEDS_DONE = 0xFFFF - this product has been deleted.
#
# - note: FEEDS_TODO&n is turned off on syndication, but so is FEEDS_DONE&n
# - then FEEDS_DONE&n is turned on on successful ack - for all feeds !EXCEPT!
#

@AMAZON3::VARIATION_KEYWORDS = (
	
	);


##
## accepts a @CONTENTS array [ [msgid1,sku1,debug],[msgid2,sku2,debug] ] and writes to the database (for future msg lookup)
## 
sub record_contents {
	my ($udbh,$USERNAME,$DOCID,$FEEDTYPE,$CONTENTSAR) = @_;

#	print "printing dumper for record contents\n"; 
#	print Dumper($CONTENTSAR);

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my %vars = ();
	$vars{'MID'} = $MID;
	$vars{'DOCID'} = $DOCID;
	$vars{'FEED'} = $FEEDTYPE;
	$vars{'*CREATED_TS'} = &ZTOOLKIT::mysql_from_unixtime(time());
	foreach my $entry (@{$CONTENTSAR}) {
		$vars{'MSGID'} = $entry->[0];
		$vars{'SKU'} = $entry->[1];
		$vars{'DEBUG'} = $entry->[2];
		my $pstmt = &DBINFO::insert($udbh,'AMAZON_DOCUMENT_CONTENTS',\%vars,insert=>1,sql=>1);
		if (not $udbh->do($pstmt)) {
			print STDERR "SQL FAILURE: $pstmt\n";
			}
		}
	}



## 
## create xml for product price info
## 
## inputs:
##		userref => hashref for merchant data (contains SCHEDULE)
##		PIDsref => pids to be sent
##
sub create_pricexml {
	my ($userref,$SKU,$P, %options) = @_;
		
	my $CONTENTSAR = $options{'@CONTENTS'};
	if (not defined $CONTENTSAR) { $CONTENTSAR = []; }

	my $lm = $options{'*LM'};
	if (not defined $lm) { $lm = LISTING::MSGS->new($userref->{'USERNAME'}); }

	my $xmlar = $options{'@xml'};
	if (not defined $xmlar) {
		die("pricexmlar is required parameter \@xml=>[]");
		}

	my $USERNAME = $userref->{'USERNAME'};
	my $PRT = $userref->{'PRT'};

	### VALIDATION
	## don't send if price isn't set
	# my $pref = $P->dataref();

	if (not defined $userref->{'*SO'}) {
		$lm->pooshmsg("WARN|+Price feed - No syndication object");
		}
	elsif ((int($userref->{'*SO'}->get('.feedpermissions'))&2)==0) {
		$lm->pooshmsg("STOP|+Prices feed not enabled");
		}

	my $SCHEDULE = $options{'schedule'} || $userref->{'*SO'}->get('.schedule');
	my $PRICE = undef;

	if (scalar($P->grp_children())>0) {
		## hmm.. don't send prices for parents
		$lm->pooshmsg("STOP|+No pricing should be sent for group parents");
		}
	elsif ( $P->has_variations('inv') && ($SKU eq $P->pid()) ) {
		## dont' send parent prices with options either.
		$lm->pooshmsg("STOP|+No pricing for inventoriable option parents");
		}
	elsif ($options{'PRICE'}) {
		## used by repricing
		$PRICE = $options{'PRICE'};
		}
	elsif ($SKU eq $P->pid()) {
		if (not $P->is_purchasable()) {
			$lm->pooshmsg("ERROR|+Not purchasable");
			}
		elsif (($P->fetch('zoovy:base_price') == 0)) {
			$lm->pooshmsg("ERROR|+No Price");
			}
		elsif ($SCHEDULE) {
			$lm->pooshmsg(sprintf("INFO|+Using schedule '%s'",$SCHEDULE));
			my $result = $P->wholesale_tweak_product($SCHEDULE);
			$PRICE = $result->{'zoovy:base_price'};
			}
		else {
			$PRICE = $P->fetch('zoovy:base_price');
			}
		}
	else {
		# my $pogresult = &POGS::apply_options($USERNAME,$SKU,$pref,'result'=>1);
		if ($SCHEDULE) { $P->schedule($SCHEDULE); }	## set the schedule to be used for product price computations
		$PRICE = $P->skufetch($SKU,'sku:price'); # $pogresult->{'zoovy:base_price'};
		}

	if ($PRICE == 0) {
		$lm->pooshmsg(sprintf("STOP|+Zero price set on SKU $SKU, cannot transmit"));
		}

	if ($lm->can_proceed()) {
		my $MSGID = 0;

		my $xml = '';
		require XML::Writer;
		my $writer = new XML::Writer(OUTPUT => \$xml, UNSAFE=>1, DATA_INDENT => 3, ENCODING => 'utf-8');
		$writer->startTag("Message");
		$writer->raw("\n");
		$writer->dataElement("MessageID",$MSGID = scalar(@{$xmlar})+1);
		$writer->startTag("Price");
		$writer->dataElement("SKU",$SKU);
		$writer->dataElement("StandardPrice",sprintf("%.2f",$PRICE),"currency"=>"USD");
		$writer->endTag("Price");
		$writer->raw("\n");
		$writer->endTag("Message");
		$writer->raw("\n");
		$writer->end();

		$lm->pooshmsg("SUCCESS|SKU:$SKU|+Price is:$PRICE");

		push @{$CONTENTSAR}, [ $MSGID, $SKU, '' ];
		push @{$xmlar}, $xml;
		}

	return($lm,$xmlar,$CONTENTSAR);
	}






#####################################################################
## PIDsref => array ref of pids
## INVGMT  => INVENTORY_GMT from AMAZON_FEEDS table 
##
sub create_inventoryxml {
	my ($userref,$SKU,$P, %options) = @_;

	my $CONTENTSAR = $options{'@CONTENTS'};
	if (not defined $CONTENTSAR) { $CONTENTSAR = []; }

	my $lm = $options{'*LM'};
	if (not defined $lm) { $lm = LISTING::MSGS->new($userref->{'USERNAME'}); }

	my $xmlar = $options{'@xml'};
	if (not defined $xmlar) {
		die("imagexmlar is required parameter \@xml=>[]");
		}

	my $USERNAME = $userref->{'USERNAME'};
	my $PRT = $userref->{'PRT'};

	if ((int($userref->{'*SO'}->get('.feedpermissions'))&1)==0) {
		$lm->pooshmsg("STOP|+Inventory feed not enabled");
		}

	my ($sTB) = &ZOOVY::resolve_lookup_tb($userref->{'USERNAME'});

	my ($udbh) = &DBINFO::db_user_connect($userref->{'USERNAME'});
	my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME);

	## returns SKUs with inventory > 0
	my %instockSKUs = ();
	my ($INV2) = INVENTORY2->new($USERNAME,"*AMZ");

	require ZWEBSITE;
	my $GREF = &ZWEBSITE::fetch_globalref($USERNAME);
	## my ($tsref,$reserveref) = $INV2->fetch_qty('@SKUS'=>[$SKU]);

	my ($INVSUMMARY) = $INV2->summary('@SKUS'=>[$SKU]);
	my $AVAILABLE = $INVSUMMARY->{$SKU}->{'AVAILABLE'};

	my $pref = $P->prodref();

	## FBA HANDLING
	my ($detailrows) = $INV2->detail('+'=>'SUPPLIER','@SKUS'=>[$SKU],WHERE=>['SUPPLIER_ID','EQ','FBA']);	
	my %HAS_FBA = ();
	foreach my $row (@{$detailrows}) {
		$HAS_FBA{ $row->{'SKU'} } = $row->{'QTY'};
		}

	if ((defined $pref->{'amz:fba'}) && ($pref->{'amz:fba'} == 1)) {
		## legacy FBA support, can only enable, never disable.
		$HAS_FBA{ $SKU } |= $pref->{'amz:fba'};
		}
	## /FBA HANDLING


	if ($lm->can_proceed()) {
		my $MSGID = 0;
		my $TXT = '?';
		my $xml = '';

		require XML::Writer;
		my $writer = new XML::Writer(OUTPUT => \$xml, UNSAFE=>1, DATA_INDENT => 3, ENCODING => 'utf-8');
		$writer->startTag("Message");
		$writer->raw("\n");
		$writer->dataElement("MessageID",$MSGID = scalar(@{$xmlar})+1);
		$writer->startTag("Inventory");
		$writer->dataElement("SKU",$SKU);

		## non-FBA products			
		my $AVAILABLE_FOR_AMAZON = $AVAILABLE;
		if ((not defined $AVAILABLE) || ($AVAILABLE eq '')) { 
			$lm->pooshmsg("WARN|+Quantity returned from inventory system was blank/not defined (setting to zero)");
			$AVAILABLE_FOR_AMAZON = 0; 
			}

		if ($HAS_FBA{$SKU}) {
			## FBA items don't use reserves, etc.
			}
		elsif ($GREF->{'inv_reserve'} == 0) { 
			## RESERVES DO NOT MATTER!
			$lm->pooshmsg("WARN|+$SKU is going to use actual qty because inv_reserve is out of stock");
			}
		else { 
			## RESERVES DO MATTER!
			## SANITY: at this point $AVAIALBLE is set to the available inventory - other (non amz) reserves
			##			  we removed amz reserves from quantity *because* we're going to re-reserve in a sec.
			if ((not defined $P->skufetch($SKU,'amz:qty')) || ($P->skufetch($SKU,'amz:qty') eq '')) {
				## no inventory record, so clear anything we've got. (in case they set amz:qty back to blank)
				$INV2->mktinvcmd('NUKE',"AMZ",$SKU,$SKU);
				}
			elsif (int($P->skufetch($SKU,'amz:qty')>=0)) {
				## amz:qty is set, and non-zero, that means we will be reserving inventory 
				##		(normally we won't reserve inventory for amazon unless amz:qty is set)
				if ($AVAILABLE_FOR_AMAZON>$P->skufetch($SKU,'amz:qty')) { $AVAILABLE_FOR_AMAZON = int($P->skufetch($SKU,'amz:qty')); }
				$INV2->mktinvcmd('FOLLOW',"AMZ",$SKU,$SKU,QTY=>$AVAILABLE_FOR_AMAZON,"NOTE"=>sprintf("amz:qty=%d",$P->skufetch($SKU,'amz:qty')));
				}
			else {
				## ignore amz:qty and tell the merchant to change it.
				&TODO::easylog($userref->{'USERNAME'},
					title=>"Amazon QTY error: ",
					detail=>"The value (".$P->skufetch($SKU,'amz:qty').") set for amz:qty on SKU: $SKU is invalid. amz:qty needs to be a whole number of 0 or greater",
					class=>"WARN",
					priority=>2,
					link=>"product:$SKU"
					);
				$INV2->mktinvcmd('NUKE',"AMZ",$SKU,$SKU);
				}
			}

		my $restock_date = '';
		if ($P->skufetch($SKU,'amz:restock_date') eq '') {
			}
		elsif ($P->skufetch($SKU,'amz:restock_date') =~ /^(\d\d\d\d)(\d\d)(\d\d)$/ ) {
			$restock_date = $P->skufetch($SKU,'amz:restock_date');
			}
		else {
			$lm->pooshmsg("ERROR|+Invalid restock date $pref->{'amz:restock_date'}");
			}


		## FBA addition
		## FBA products do not submit quantity or Latency
		if ($HAS_FBA{$SKU}) {
			$writer->dataElement('FulfillmentCenterID','AMAZON_NA');
			$writer->dataElement('Lookup','FulfillmentNetwork');
			$writer->dataElement('SwitchFulfillmentTo','AFN');
			$TXT = 'FBA'; 
			}
		else {
			## if we send negative inventory amazon will return an error in the feed
			## $writer->dataElement('SwitchFulfillmentTo','Merchant??');
			if ($AVAILABLE_FOR_AMAZON < 0) { 
				$AVAILABLE_FOR_AMAZON = 0;
				$lm->pooshmsg("WARN|+AVAILABLE_FOR_AMAZON was ($AVAILABLE_FOR_AMAZON)<0 so setting to zero");
				}

			if ($restock_date ne '') {
				## RESTOCK DATE - new feature amz is using... added here 2011-04-25
				## 	- restock is set so customers can buy products that are out of stock. time not allowed in date format - (YYYY-MM-DD) only
				if ($AVAILABLE_FOR_AMAZON > 0) {
					$writer->dataElement('Quantity',$AVAILABLE_FOR_AMAZON);
					$TXT = "Qty $AVAILABLE_FOR_AMAZON";
					}
				else {
					## if $qty <=0 and restock is set, we must send 'Available' instead on 'Quantity'. RestockDate will be ignored if Quantity is set to 0.
					$writer->dataElement('Available',1);
					$TXT = "Available";
					}
				my $restock_date = $1."-".$2."-".$3;
				$writer->dataElement('RestockDate',$restock_date);
				$TXT .= " (Restock $restock_date)";
				}
			else {
				$writer->dataElement('Quantity',$AVAILABLE_FOR_AMAZON);
				$TXT = "Qty $AVAILABLE_FOR_AMAZON";
				}
			##
			## SANITY: at this point $AVAILABLE_FOR_AMAZON is:
			##				9999 if it's unlimited inventory
			##				the quantity in stock (if reserves don't matter)
			##			  	the quantity we just reserved and subsequently will be sending to Amazon
			##

			## SHIP LATENCY
			## if ship latency is defined as 0, then it is _not_ sent to Amazon
			## and Amazon assumes no extra processing time
			my $latency = '';
			## defined on product-level
			if ($pref->{'zoovy:ship_latency'} ne '') {
				## if the merchant supplies a range, the number at the top of the range is taken
				if ($pref->{'zoovy:ship_latency'} =~ /(\d+)-(\d+)/){ $latency = $2; }
				else { $latency = $pref->{'zoovy:ship_latency'}; }
				}
			## defined on store-level
			elsif ($webdbref->{'ship_latency'} ne '') { 
				$latency = $webdbref->{'ship_latency'};
				}

			## more than 30 days, errors Amazon			
			$latency = int($latency);
			if ($latency > 30) {
				$lm->pooshmsg("ERROR|+Fulfillment Latency > 30 [not allowed]");
				}
			elsif ($latency > 0) {
				$writer->dataElement('FulfillmentLatency',$latency);
			 	}	
			else {
				## fulfillment latency is not required apparently.
				}
			## end of latency

			## SWITCH TO MFN
			## this attribute is only required if the product is AFN on Amazon but since we can't confirm that and since it does no harm we send it evcery time.
			$writer->dataElement('SwitchFulfillmentTo','MFN');	

			}

		$writer->endTag("Inventory");
		$writer->raw("\n");
		$writer->endTag("Message");
		$writer->raw("\n");
		$writer->end();

		## add to xml
		push @{$CONTENTSAR}, [ $MSGID, $SKU, '' ];
		push @{$xmlar}, $xml;

		# print "XML: $xml\n";

		$lm->pooshmsg("SUCCESS|+Set inventory $TXT");
		}


	&DBINFO::db_user_close();
	return($lm,$xmlar,$CONTENTSAR);
	}











############################################
## creates shipping overrides xml
##
##
## hashref - product hashref (includes other non-standard variables; msgid, sku)
## 
## this feed was added for secondact (~Dec 15 2008)
## it was not fully implemented (ie added to cron) for the following reasons:
##		- overrides are not viewable on SellerCentral 
##		- only way to test override is to create an order with product
##		- overrides can take up to 4 hrs to be accepted by Amazon
##		- overrides need to be "deleted" from Amazon if no longer needed
##		-- ie sending a new feed doesn't override your overrides for that product
##
## feature can be added to cron, /httpd/servers/amazon/amz_feed.pl PUSH=shipping
##
sub create_shippingxml {
	my ($userref,$SKU,$P, %options) = @_;

	my $CONTENTSAR = $options{'@CONTENTS'};
	if (not defined $CONTENTSAR) { $CONTENTSAR = []; }

	my $lm = $options{'*LM'};
	if (not defined $lm) { $lm = LISTING::MSGS->new($userref->{'USERNAME'}); }

	my $xmlar = $options{'@xml'};
	if (not defined $xmlar) {
		die("imagexmlar is required parameter \@xml=>[]");
		}

	my $USERNAME = $userref->{'USERNAME'};
	my $PRT = $userref->{'PRT'};

	my $prodref = $P->prodref();

	if (not $lm->can_proceed()) {
		}
	elsif ((int($userref->{'*SO'}->get('.feedpermissions'))&2)==0) {
		$lm->pooshmsg("STOP|+Shipping feed not enabled");
		}
	elsif ($prodref->{'amz:so_ship_option1'} eq '') {
		$lm->pooshmsg("STOP|+No shipping overrides found.");
		}
	else {
		my $xml = '';
		my $MSGID = 0;

		my $writer = new XML::Writer(OUTPUT => \$xml, UNSAFE=>1, DATA_INDENT => 3, ENCODING => 'utf-8');
		$writer->startTag("Message");
		$writer->raw("\n");
		$writer->dataElement("MessageID",$MSGID = scalar(@{$xmlar})+1);
		$writer->dataElement("OperationType","Update");
		$writer->dataElement("SKU",$SKU);

		my %overrides = ();  ## stores all current overrides per SKU/position, used for logging

		foreach my $n (1..4) {
			if ($prodref->{'amz:so_ship_option'.$n} eq '') { 
				last; 
				}
			$writer->startTag("Override");
			$writer->startTag("ShippingOverride");
			$writer->dataElement("ShipOption",$prodref->{'amz:so_ship_option'.$n});

			## Don't Ship => 1, changed to IsShippingRestricted 
			if (int($prodref->{'amz:so_donotship'.$n}) == 1) {
				$writer->dataElement("IsShippingRestricted",$prodref->{'amz:so_donotship'.$n});
				}
			## Ship w/Additive or Exclusive Amount
			else {
				$writer->dataElement("Type",$prodref->{'amz:so_type'});
				$writer->dataElement("ShipAmount",$prodref->{'amz:so_amount'.$n},'currenty'=>'USD');
				}
			## log each shipping override 

			#$overrides{$pid.":".$n} = "ship_option=".$prodref->{'amz:so_ship_option'.$n}.
         #                         " donotship=".$prodref->{'amz:so_donotship'.$n}.
         #                         " type=".$prodref->{'amz:so_donotship'.$n}.
         #                         " amount=".$prodref->{'amz:so_amount'.$n};
  
			$writer->endTag("ShippingOverride");
			$writer->endTag("Override");
			}
		## add to xml

		$writer->endTag("Message");
		$writer->end();

		push @{$CONTENTSAR}, [ $MSGID, $SKU, ''];
		push @{$xmlar}, $xml;

		$lm->pooshmsg("SUCCESS|+Added shipping override");
		}
	
	
	return($lm,$xmlar,$CONTENTSAR);
	}





















##############################
##
## amazon now only wants one images per option, plus a swatch (if available)
##
## Amazon now allow mutilple images for options again 2011-02-09
##
###############################
sub create_imgxml {
	my ($userref,$SKU,$P, %options) = @_;
	
	require MEDIA;

	my $CONTENTSAR = $options{'@CONTENTS'};
	if (not defined $CONTENTSAR) { $CONTENTSAR = []; }

	## this holds CSV headers
	my $CSV = $options{'%AMZCSV'} || {};

	my $lm = $options{'*LM'};
	if (not defined $lm) { $lm = LISTING::MSGS->new($userref->{'USERNAME'}); }

	my $xmlar = $options{'@xml'};
	if (not defined $xmlar) {
		die("imagexmlar is required parameter \@xml=>[]");
		}
	elsif ($options{'%AMZCSV'}) {
		## we don't care about feedpermissions for %AMZCSV 
		}
	elsif ((int($userref->{'*SO'}->get('.feedpermissions'))&4)==0) {
		$lm->pooshmsg("STOP|+Images feed not enabled");
		}

	my $imgselect = '';
#	my ($JSONREF) = &AMAZON3::resolve_cat($pref->{'amz:catalog'});
#	my ($catalog, $subcat) = split(/\./, $pref->{'amz:catalog'});
#	$catalog =~ s/FOOD/GOURMET/;

	## switched back to url_to_orig
	#my $PATH = IMGLIB::Lite::get_static_url($USERNAME,'img','http')."/-/";

	#print STDERR "PREF: ".Dumper($pref);

	#### CHILD
	## swatches are only allowed for apparel, home, beauty and adult products
	##
	## need to send blank for other images (to fix existing issue)
	## --- of only displaying one image for parent
	## if this is an imgselect pog and option, use that image instead
	## parent should send all the other images
	#### define $imgselect if needed
	## send a separate image for item in the group (shows up better on amazon.com)
	## don't go this way if you are a GRP CHILD

	my %Pref = ();
	tie %Pref, 'PRODUCT', $P;

	my @IMAGES = ();
	if ($Pref{'amz:catalog'} eq 'EXISTING') {
		$lm->pooshmsg("SKIP|+Image sync skipped (catalog=EXISTING)");
		}
	elsif (($SKU =~ /:/) && ($Pref{'zoovy:grp_parent'} eq '')) {
		## OPTION
		my $skuref = $P->skuref($SKU);
		for (my $i=1; $i<6; $i++) {
			if ($skuref->{"zoovy:prod_image$i"} ne '') {
				my ($img) = $skuref->{"zoovy:prod_image$i"};
				last if ($img eq '');
				push @IMAGES, [ "zoovy:prod_image$i", $img ];
				}
			}
		## need to add something for swatches
		}
	elsif (($Pref{'zoovy:grp_type'} eq 'PARENT') || ($Pref{'zoovy:grp_children'} ne '')) {
		## GROUP PARENT
		## 	only set the MAIN image for GRP PARENT, display better in amz
		if ($Pref{'amz:prod_image1'}) {
			push @IMAGES, [ "amz:prod_image1", $Pref{'amz:prod_image1'} ];
			}
		elsif ($Pref{'zoovy:prod_image1'} ne '') {
			push @IMAGES, [ "zoovy:prod_image1", $Pref{'zoovy:prod_image1'} ];
			}
		}
	elsif ($Pref{'amz:prod_image1'} ne '') {
		## BASE OR STANDARD PARENT - use amz:images instead of zoovy:images if they exist 		
		## 	amz:images is set by the merchant for each product
		## 	this was built to get around watermarks (which amz doesn't allow)
		## 	if amz:prod_image1 is set then ONLY amz:prod_images are used (no zoovy:prod_imageN)
		for (my $i=1; $i<9; $i++) {
			if ($Pref{"amz:prod_image$i"} ne '') {
				push @IMAGES, [ "amz:prod_image$i", $Pref{"amz:prod_image$i"} ];
				} 
			}
		}
	elsif ($Pref{'zoovy:prod_image1'} ne '') {
		## BASE OR STANDARD PARENT - amz:images not set
		## 	this is the most common case, we'll use up to 9 zoovy:prod_image1 images.
		for (my $i=1; $i<9; $i++) {
			if ($Pref{'zoovy:prod_image'.$i} ne '') {
				my ($img) = $Pref{'zoovy:prod_image'.$i};
				push @IMAGES, [ "zoovy:prod_image$i", $img ];
				}
			}
		}

	if (not $lm->can_proceed()) {
		}
	elsif (scalar(@IMAGES)==0) {
		$lm->pooshmsg("ERROR|+Found no images associated to SKU:$SKU");
		}		

	foreach my $imgset (@IMAGES) {
		if ($imgset->[1] =~ /[\s]+/) {
			$lm->pooshmsg("ERROR|+Image $imgset->[0] '$imgset->[1]' contains a space in value");
			}
		elsif ($imgset->[1] =~ /^\*\*ERR/) {
			# ERR => invalid image marked by Zoovy (may be legacy at this point)
			$lm->pooshmsg("ISE|+Image $imgset->[0] '$imgset->[1]' is marked as legacy **ERR");
			}
		}

	if (not $lm->can_proceed()) {
		}
	elsif (scalar(@IMAGES) == 0) {
		$lm->pooshmsg("STOP|+No Images for product");
		}

	## amazon limits us to 9 images
	if (scalar(@IMAGES)>9) {
		$lm->pooshmsg(sprintf("WARN|+Found %d images, Amazon only allows 9 (rest truncated)",scalar(@IMAGES)));
		@IMAGES = splice(@IMAGES,0,9);
		}

	my $swatch_url = '';
	my $i = 0; 
	foreach my $imgset (@IMAGES) {
		next if ($imgset->[1] eq ''); 
		my $url = undef;
		my $ERROR = undef;
		
		if ($imgset->[1] =~ /^http\:/) { 
			$imgset->[2] = $url = $imgset->[1];
			$lm->pooshmsg("WARN|+Image $imgset->[0] '$imgset->[1]' is hosted externally, cannot verify size / format.");
			}
		else {
			my ($result) = MEDIA::getinfo($userref->{'USERNAME'},$imgset->[1],DB=>1);
			if (not defined $result) {
				$lm->pooshmsg("ISE|+$imgset->[1] received an undef result from MEDIA::getinfo");
				}
			elsif ($result->{'err'} == 10) {
				## could not find file in database (try disk lookup)
				$lm->pooshmsg("WARN|+Could not find image $imgset->[1] in db for fast lookup, trying direct disk lookup");
				($result) = MEDIA::getinfo($userref->{'USERNAME'},$imgset->[1],DB=>0);
				}

			## WARN => IMAGE EMPTY or UNKNOWN FORMAT
			## ERR if main image, else just WARN
			# $lm->pooshmsg("DEBUG|+".Dumper($result));
			if (defined $result->{'Format'}) {
				}
			elsif ($i == 0) { 
				# print STDERR "Image Format unknown (possibly bitmap?)\n";
				## ERR => main image
				$lm->pooshmsg("ERROR|+Main Image $imgset->[0] '$imgset->[1]' unknown format (empty?, bitmap?) - fatal");
				$result = undef;
				}
			else { 
				$lm->pooshmsg("WARN|+Image $imgset->[0] '$imgset->[1]' unknown format (empty?, bitmap?)");
				$result = undef;
				}

			## IMAGE OKAY
			if ($lm->can_proceed()) {
				}
			elsif (not defined $result) {
				}
			elsif (($result->{'H'} >= 110 && $result->{'W'} >= 11) || ($result->{'W'} >= 110 && $result->{'H'} >= 11)) {
				$lm->pooshmsg("SUCCESS|+Image $imgset->[0] '$imgset->[1]' H:$result->{'H'}  W:$result->{'W'}");
	 			}
			## WARN => IMAGE TOO SMALL, Amazon is just gonna error and merchant will get confused
			elsif ($i == 0) { 
				$lm->pooshmsg("ERROR|+Main Image $imgset->[0] '$imgset->[1]' is too small (H:$result->{'H'}  W:$result->{'W'})");
				$result = undef;
				}
			else { 
				$lm->pooshmsg("WARN|+Main Image $imgset->[0] '$imgset->[1]' is too small (H:$result->{'H'}  W:$result->{'W'})");
				$result = undef;
				}

			if (not defined $result) {
				}
			elsif ($imgset->[1] eq '') {
				}
			elsif (not defined $url) {
				# $url = &IMGLIB::Lite::url_to_orig($userref->{'USERNAME'},$imgset->[1]);
				$url = sprintf("http://%s/media/img/%s/-/%s",&ZOOVY::resolve_media_host($userref->{'USERNAME'}),$userref->{'USERNAME'},$imgset->[1]);
				$url =~ s/\.png$/\.jpg/;
			
				if ($url !~ /\.gif$/i && $url !~ /\.jpg$/i){
					$url = $url.".jpg";
					}
				$imgset->[2] = $url;
				}
			}
		$i++;
		}

	if ($lm->can_proceed()) {
		my $i = 0;
		foreach my $imgset (@IMAGES) {

			my $url = $imgset->[2];
			next if ((not defined $url) || ($url eq ''));
			my $MSGID = 0;
			my $xml = '';
			my $writer = new XML::Writer(OUTPUT => \$xml, UNSAFE=>1, DATA_INDENT => 3, ENCODING => 'utf-8');
#			$imgxml = $imgxml->{'Message'};
#			$imgxml->{'MessageID'}->content($MSGID = scalar(@{$xmlar})+1);
			$writer->startTag("Message");
			$writer->raw("\n");
			$writer->dataElement("MessageID",$MSGID = scalar(@{$xmlar})+1);
			my $type = 'Update';
			$writer->dataElement('OperationType',$type);		
			# $imgxml->{'OperationType'}->content($type);
			# $imgxml->{'ProductImage'}{'SKU'}->content($SKU);
			$writer->startTag('ProductImage');
			$writer->dataElement('SKU',$SKU);

			## get the first one in the hash (either from imgselect or prod_image1)
			if ($i == 0) {	
				## NOTE: andrew says swatches are crap and we don't need 'em. 
				## he thinks it's just because amazon are a bunch of wankers.
				#if (
				#	(($img_type eq 'swatch') || ($catalog eq 'APPAREL')) && ($SKU =~ /:/)) {
				#	$imgxml->{'ProductImage'}{'ImageType'}->content('Swatch');
				#	$swatch_url = $url;
				#	} 
				#else {
				# $imgxml->{'ProductImage'}{'ImageType'}->content('Main'); 
				$writer->dataElement('ImageType','Main');
				#	}
				}
			else { 
				# $imgxml->{'ProductImage'}{'ImageType'}->content('PT'.($i-1)); 
				$writer->dataElement('ImageType',sprintf('PT%d',$i));
				}
			# $imgxml->{'ProductImage'}{'ImageLocation'}->content($url);
			$writer->dataElement('ImageLocation',$url);
			$CSV->{'main_image_url'} = $url;

			$writer->endTag('ProductImage');
			$writer->endTag('Message');
			$writer->end();

			# my ($xml) = $imgxml->data(nometagen=>1,noheader=>1);	## note: this dumbass function returns two elements.
			push @{$CONTENTSAR}, [ $MSGID, $SKU, sprintf("%s=%s",$imgset->[0],$imgset->[1]) ];
			push @{$xmlar}, $xml;
			$i++;
			}
		
		if ($i>0) {
			$lm->pooshmsg(sprintf("SUCCESS|+Sent %d images",$i));
			}
		}

	## addition for GRP CHILDREN 
	## we want to send both Swatch and Main (Swatch was sent above)
	## all other categories and configs => this is a no-no
	#if ($Pref{'zoovy:grp_parent'} ne '' && $swatch_url ne '') {
	#	my $imgxml = XML::Smart->new();
	#	$imgxml = $imgxml->{'Message'}; 
	#	$imgxml->{'MessageID'}->content(scalar(@{$xmlar})+1);
	#	$imgxml->{'OperationType'}->content('Update');
	#	$imgxml->{'ProductImage'}{'SKU'}->content($SKU);
	#	$imgxml->{'ProductImage'}{'ImageType'}->content('Main'); 
	#	$imgxml->{'ProductImage'}{'ImageLocation'}->content($swatch_url);
#
#		my ($xml) = $imgxml->data(nometagen=>1,noheader=>1);	# note: returns two items, so don't push directly.
#		push @{$xmlar}, $xml;
#		}
 		
	return($lm,$xmlar,$CONTENTSAR);
	}






############################################
## creates relational xml, only used with options
##
##
## hashref - product hashref (includes other non-standard variables; msgid, sku)
## childref - children array ref; contains children skus 
## 
## http://sellercentral.amazon.com/help/merchant_documents/XSD/samples/Relationship_sample.xml
##
sub create_relationxml {
	my ($userref,$SKU,$P,%options) = @_;

	my $lm = $options{'*LM'};
	if (not defined $lm) { $lm = LISTING::MSGS->new($userref->{'USERNAME'}); }
	my $CSV = $options{'%AMZCSV'} || {};

	my $xmlar = $options{'@xml'};
	if (not defined $xmlar) {
		die("xml array ref is required parameter \@xml=>[]");
		}

	my $CONTENTSAR = $options{'@CONTENTS'};
	if (not defined $CONTENTSAR) { $CONTENTSAR = []; }
	my $USERNAME = $userref->{'USERNAME'};
	my $PRT = $userref->{'PRT'};
	my $MID = ZOOVY::resolve_mid($USERNAME);

	if (defined $options{'%AMZCSV'}) {
		## we don't need to worry about feedpermissions when %AMZCSV is passed.
		}
	elsif ((int($userref->{'*SO'}->get('.feedpermissions'))&4)==0) {
		$lm->pooshmsg("STOP|+Relations feed not enabled");
		}

	my %Pref = ();
	tie %Pref, 'PRODUCT', $P;
	
	if ($Pref{'amz:catalog'} eq 'EXISTING') {
		$lm->pooshmsg("SKIP|+Relation sync skipped (catalog=EXISTING)");
		}
	elsif ($SKU ne $P->pid()) {
		## no relations feed for sku's
		$lm->pooshmsg("STOP|+No need for relations on SKU:$SKU");
		}
	elsif ($Pref{'zoovy:grp_parent'} ne '') {
		## no relations feed for children either
		$lm->pooshmsg(sprintf("STOP|+No need for relations on GROUP CHILD: %s",$Pref{'zoovy:grp_parent'}));
		}

	my @RELATIONS = ();	 ## an array of arrays of [ SKU, Type ]
	if (not $lm->can_proceed()) {
		}	
	elsif ($Pref{'zoovy:grp_children'} ne '') {
		foreach my $childpid (split(/,/,$Pref{'zoovy:grp_children'})) {
			push @RELATIONS, [ 'Variation', $childpid ];
			}
		}

	if ($P->has_variations('inv')) {
		foreach my $skuset (@{$P->list_skus()}) {
			push @RELATIONS, [ 'Variation', $skuset->[0] ];
			}
		}

	## ACCESSORIES
	foreach my $child (split(",",$Pref{'zoovy:accessory_products'})) {
		push @RELATIONS, [ 'Accessory', $child ];
		}
	## RELATED PRODUCTS
	foreach my $child (split(",",$Pref{'zoovy:related_products'})) {
		push @RELATIONS, [ 'Accessory', $child ];
		}

	## TODO:CSV -- this seems like a good place to process some CSV relationship info

	my $relations_to_send = 0;
	if (scalar(@RELATIONS)==0) {
		$lm->pooshmsg("DEBUG|+No accessories or related items");
		}
	else {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my ($sTB) = &ZOOVY::resolve_lookup_tb($USERNAME,$MID);

		my %SETLOOKUP = (); 
		my @SKUS = (); 
		foreach my $rset (reverse @RELATIONS) { 
			push @SKUS, $rset->[1]; 
			$SETLOOKUP{$rset->[1]} = $rset;
			}

		my $pstmt = "select SKU,AMZ_FEEDS_TODO,AMZ_FEEDS_DONE,AMZ_FEEDS_ERROR from $sTB where SKU in ".&DBINFO::makeset($udbh,\@SKUS)." and mid=$MID";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($sku,$feeds_todo,$feeds_done,$feeds_error) = $sth->fetchrow() ) {
			if (not defined $SETLOOKUP{$sku}) {
				$lm->pooshmsg("ISE|+DB returned a sku[$sku] we didn't ask for (or already processed)");
				}
			elsif ($SETLOOKUP{$sku}->[0] eq 'Variation') {
				if (($feeds_done & 1)==0) {
					$lm->pooshmsg("PAUSE|+The relationship for variation/$sku cannot be synced because the $sku has not been successfully sent to Amazon.".
					" If this was returned for 'VALIDATE' and the product has not yet been sent to Amazon, this message can be ignored");
					}
				elsif (($feeds_error & 1)==1) {
					$lm->pooshmsg("PAUSE|+The relationship for variation/$sku cannot be synced because it is marked as error.".
					" If this was returned for 'VALIDATE' and the product has not yet been sent to Amazon, this message can be ignored");
					}
				elsif ( ($feeds_done & $AMAZON3::BW{'deleted'}) > 0) {
					$lm->pooshmsg("PAUSE|+The relationship for variation/$sku cannot be synced because it is marked as deleted.".
					" If this was returned for 'VALIDATE' and the product has not yet been sent to Amazon, this message can be ignored");
					}
				elsif ( ($feeds_error & $AMAZON3::BW{'deleted'}) > 0) {
					$lm->pooshmsg("PAUSE|+The relationship for variation/$sku cannot be synced because it is marked as delete attempted.".
					" If this was returned for 'VALIDATE' and the product has not yet been sent to Amazon, this message can be ignored");
					}
				else {
					$SETLOOKUP{$sku}->[2] = ++$relations_to_send;
					}
				delete $SETLOOKUP{$sku};
				}
			elsif ($SETLOOKUP{$sku}->[0] eq 'Accessory') {
				if (($feeds_done & 1)==0) {
					$lm->pooshmsg("WARN|+The relationship for Accessory/$sku cannot be synced because the $sku  has not been successfully sent to Amazon");
					}
				elsif (($feeds_error & 1)==1) {
					$lm->pooshmsg("WARN|+The relationship for accessory/$sku cannot be synced because it is marked as error");
					}
				elsif ( ($feeds_done & $AMAZON3::BW{'deleted'}) > 0) {
					$lm->pooshmsg("WARN|+The relationship for accessory/$sku cannot be synced because it is marked as deleted");
					}
				elsif ( ($feeds_error & $AMAZON3::BW{'deleted'}) > 0) {
					$lm->pooshmsg("WARN|+The relationship for accessory/$sku cannot be synced because it is marked as delete attempted");
					}
				else {
					$SETLOOKUP{$sku}->[2] = ++$relations_to_send;
					}
				delete $SETLOOKUP{$sku};
				}
			else {
				## not as accessory or variation - Maybe a deleted or corrupt product?
				$lm->pooshmsg("ISE|SKU:$sku|+DB returned an invalid sku: child[$SETLOOKUP{$sku}->[1]] of type[$SETLOOKUP{$sku}->[0]] we didn't ask for");
				}
			}
		$sth->finish();
		&DBINFO::db_user_close();

		foreach my $sku (keys %SETLOOKUP) {
			next if ($sku eq '');
			if ($SETLOOKUP{$sku} eq 'Variation') {
				$lm->pooshmsg("ERROR|+Variation/$sku cannot be synced because it is not in SKU_LOOKUP (invalid reference)");
				}
			elsif ($SETLOOKUP{$sku} eq 'Accessory') {
				$lm->pooshmsg("WARN|+Accessory/$sku was ignored because it is not in SKU_LOOKUP (invalid reference)");
				}
			else {
				$lm->pooshmsg("ISE|#:121432|+$SKU has a related item '$SETLOOKUP{$sku}->[1]' which does not exist.");
				}
			}
		}

	if (not $lm->can_proceed()) {
		# shit happened.
		}
	elsif (not $relations_to_send) {
		$lm->pooshmsg("STOP|+No relations to send");
		}
	elsif (scalar(@RELATIONS)>0) {
		my $xml = '';
		require XML::Writer;
		my $MSGID = 0;
		my $writer = new XML::Writer(OUTPUT=>\$xml,UNSAFE=>1,DATA_INDENT => 3, ENCODING => 'utf-8');
		$writer->startTag("Message");
		$writer->dataElement("MessageID",$MSGID = scalar(@{$xmlar})+1);
		$writer->startTag("Relationship");
		$writer->raw("\n");
		$writer->dataElement("ParentSKU", $CSV->{'parent_sku'} = $P->pid());
		$writer->raw("\n");
		foreach my $rset (@RELATIONS) {
			next if ((not defined $rset->[2]) || ($rset->[2] == 0));
			# print "Mapping parent=$PARENT to $r->[1]=$r->[0]\n";
			$writer->startTag("Relation");
			$writer->dataElement("SKU",$rset->[1]);
			$writer->dataElement("Type",$rset->[0]);
			$writer->endTag("Relation");
			$writer->raw("\n");
			}
		$writer->endTag("Relationship");
		$writer->endTag("Message");
		$writer->raw("\n");
		$writer->raw("\n");
		$writer->end();
		push @{$CONTENTSAR}, [ $MSGID, $P->pid() ];
		push @{$xmlar}, $xml;
		$lm->pooshmsg(sprintf("SUCCESS|+Sent %d relations",scalar(@RELATIONS)));
		}
	else {
		$lm->pooshmsg("ISE|+Internal issue - no valid relationships");
		} 

	## only push the XML if there's data	
	#if ($msgid == 0) { 
	#	$lm->pooshmsg("ISE|DOCID:$docid|+msgid was 0 (no messages?!?!)");
	#	}
	#else {
	#	($docid,$error) = AMAZON3::push_xml($userref,$xml,'Relationship','_POST_PRODUCT_RELATIONSHIP_DATA_');
	#	if ($docid>0) {
	#		&AMAZON3::item_set_status($userref,$PIDsref,['-relations.todo'],DOCTYPE=>'_POST_PRODUCT_RELATIONSHIP_DATA_',DOCID=>$docid);
	#		$lm->pooshmsg("INFO|+Relationship Feed got docid=$docid");
	#		}
	#	else {
	#		$lm->pooshmsg("ISE|+Relationship Feed got error:$error docid:$docid");
	#		&AMAZON3::item_set_status($userref,$PIDsref,['+relations.doh'],DOCTYPE=>'_POST_PRODUCT_RELATIONSHIP_DATA_',DOCID=>$docid,ERROR=>$error);
	#		}
	#		
	#	if ($error eq '') {
	#		## add event to AMAZON_LOG
	#		foreach my $pid (@processing) {
	#			$lm->pooshmsg("INFO|DOC:$docid|PID:$pid|+Posted to Relationship Feed");
	#			}
	#		}
	#	}
		
	return($lm,$xmlar,$CONTENTSAR);
	}












#############################################
## create xml for products
##
## hashref - product hashref inlcudes some non-standard vars; msgid, catalog, subcat, etc
## thesaurusinfo - thesaurus hashref
## type - type of product push; products (initial push)
## themeref - theme hashref, contains Amazon Variation Keyword and value for particular sku
## 
sub create_skuxml {
	my ($userref,$SKU,$P,%options) = @_;

	my $CSV = $options{'%AMZCSV'} || {};

	my $xmlar = $options{'@xml'};
	if (not defined $xmlar) {
		die("xmlar is required parameter \@xml=>[]");
		}

	my $lm = $options{'*LM'};
	if (not defined $lm) { $lm = LISTING::MSGS->new($userref->{'USERNAME'});  }

	my $USERNAME = $userref->{'USERNAME'};

	if (defined $options{'%AMZCSV'}) {
		## move along, nothing to see here. (we don't check feedpermissions for $options{'%AMZCSV'})
		}
	elsif ((int($userref->{'*SO'}->get('.feedpermissions'))&4)==0) {
		$lm->pooshmsg("STOP|+Product feed not enabled");
		}

	## this is what loads the .json file
	my $PID = $P->pid();
	my %Pref = ();
	tie %Pref, 'PRODUCT', $P;


	my $MSGID = 0;

	if (not defined $P) {
		$lm->pooshmsg("ERROR|+Product doesn't exist??");
		}
	elsif ($Pref{'zoovy:prod_name'} eq '') {
		$lm->pooshmsg("ERROR|+Product name blank");
		}
	elsif ($Pref{'amz:ts'}<=0) {
		$lm->pooshmsg("STOP|+amz:ts field is set to not allow syndication");
		}

	## find thesaurus set by merchant
	my $ncref = $options{'%NCREF'};
	#if (not defined $ncref) {
	#	warn "NO %NCREF PASSED, BUT WE CAN LOAD DIRECTLY (BUT THIS IS VERY SLOW AND SHOULD BE FIXED)";
	#	(my $ncprettyref,my $ncprodref, $ncref) = &NAVCAT::FEED::matching_navcats($USERNAME,'AMAZON_THE');
	#	}
	my $thesaurus = undef; 
	if ($thesaurus = $P->fetch('amz:thesaurus')) {
		$lm->pooshmsg("DEBUG|SKU:$SKU|+Using THESAURUS[$thesaurus] from PRODUCT");
		}
	#elsif ($thesaurus = $ncref->{$P->pid()}) {
	#	$lm->pooshmsg("DEBUG|SKU:$SKU|+Using THESAURUS[$thesaurus] from NAVCAT");			
	#	}

	my $thesref = $options{'%THESAURUSREF'};
	if (not defined $thesref) {
		warn "NO %THESAURUSREF PASSSED, BUT WE CAN LOAD DIRECTLY (BUT THIS IS VERY SLOW AND SHOULD BE FIXED)";
		($thesref) = &AMAZON3::fetch_thesaurus_detail($userref);
		}
	my $thesaurusinfo = undef;
	if ($thesaurus ne '') {
		$thesaurusinfo = $thesref->{$thesaurus};
		if (not defined $thesaurusinfo) {
			$lm->pooshmsg("WARN|SKU:$SKU|+Thesaurus[$thesaurus] was not valid");
			}
		}

	#my $themeref = $options{'%THEMEREF'};
	#if (not defined $themeref) {
	#	warn "NO %THEMEREF PASSSED, BUT WE CAN LOAD DIRECTLY (BUT THIS IS VERY SLOW AND SHOULD BE FIXED)";
	#	die();
	#	}
	## note: not sure if we can get blanks in themeref, but we'll delete them just in case
	# if (defined $themeref->{''}) { delete $themeref->{''}; };
	# print STDERR "SKU[$SKU] ".Dumper($themeref)."\n";

	$lm->pooshmsg("DEBUG|SKU:$SKU|+THESAURUS:$thesaurus CATALOG:$Pref{'amz:catalog'} ClothingType:$Pref{'amz:prod_cloth_cd_clothingtype'} ItemType:".lc($thesaurusinfo->{'ITEMTYPE'})." TS:$Pref{'amz:ts'}");

	##
	## CATALOG
	## 
	##	CATALOGREF comes from JSON FILES - stored in folder /httpd/static/definitions/amz/
	my $JSONREF = undef;
	if (not $lm->can_proceed()) {
		}
	elsif (not &AMAZON3::is_defined($Pref{'amz:catalog'})) {
		## this can be reached: the product has grouped children, but the grouped children did not
		## not have proper catalogs set.
		$lm->pooshmsg("ERROR|+amz:catalog [$Pref{'amz:catalog'}] is not defined/blank");
		}
	elsif ($Pref{'amz:catalog'} eq 'EXISTING') {
		$lm->pooshmsg("SKIP|+Product sync skipped - (catalog=EXISTING)");
		$JSONREF = {};
		}
	else {
		$JSONREF = &AMAZON3::fetch_catalogref($Pref{'amz:catalog'});
		if (not defined $JSONREF) {
			$lm->pooshmsg(sprintf("ERROR|+Catalog [%s] could not be loaded from AMAZON3::fetch_catalogref",$Pref{'amz:catalog'}));
			}
		}

	## check if valid CATALOG
	my ($catalog,$subcat,$amz_catalog,$amz_subcat) = ($JSONREF->{'catalog'},$JSONREF->{'subcat'},$JSONREF->{'amz-catalog'},$JSONREF->{'amz-subcat'});

	## TODO:CSV
	$CSV->{'feed_product_type'} = $amz_catalog;
	if (defined $AMAZON3::CATALOG_CSV_feed_product_type{$catalog}) {
		$CSV->{'feed_product_type'} = $AMAZON3::CATALOG_CSV_feed_product_type{$catalog};
		}

	#print Dumper($JSONREF);

	## it's easier to figure out themes and relationships together 
	my $AMZ_RELATIONSHIP = undef;	
	## AMZ_RELATIONSHIP will be an arrayref -- that contains the following values
	##
	##		[0] = zoovy's disposition ex: vcchild, vchild, child, parent, vparent, none-option, none-group, vcontainer, none, base
	##		[1] = the parent sku (if appropriate)
	##		[2] = amazons high level disposition for grouping parent,child,base,none
	##		[3] = what we will be sending to amazon for 'parentage'
	##
	my %themes = ();		## a hash keyed by variation value is the value we'll send to amazon
								## note: value can also be **PARENT** since we don't actually send these for parents.

	## first process any parent solo items
	## addition of Group Variation Keyword keys and values
	## amz:grp_varkey	=> APPAREL: Color
	## amz:grp_varvalue => Silver
	if ($Pref{'amz:grp_varkey'} ne '') {
		## if the grp_child has options		
		my ($pog_cat, $pog_theme) = split(/: /, $Pref{'amz:grp_varkey'});
		$themes{$pog_theme} = $Pref{'amz:grp_varvalue'};

		if (($themes{$pog_theme} eq '') && ($Pref{'zoovy:grp_children'} ne '')) {
			## group containers don't have/require values
			$themes{ $pog_theme } = '*** GROUP_PARENT ***';
			}
		}

	if (not $lm->can_proceed()) {
		}
	elsif ($P->has_variations('inv')) {
		## go through and create an array of SOGS --
		##		Theme is the amz:grp_varkey[1] in a vchild/vparent situation
		my ($PID,$claim,$invopts) = &PRODUCT::stid_to_pid($SKU);
		my %SELECTED_OPTIONS = ();
		foreach my $opt (split(/:/,$invopts)) {
			my $id = substr($opt,0,2); 
			my $val = substr($opt,2,4);					
			$SELECTED_OPTIONS{$id} = $val;
			}

		foreach my $pog (@{$P->fetch_pogs()}) {
			if (($pog->{'amz'} eq '') && ($pog->{'AMZ'} ne '')) {
				## attribute should be amz but the admin app is currently saving it as AMZ
				##		jt said this will be corrected in the near furture and the following line should ensure that products with updated sogs don't crash 
				##		while we're waiting for a fix.
				$pog->{'amz'} = $pog->{'AMZ'};
				}
			$lm->pooshmsg("DEBUG|+POG:$pog->{'id'} TYPE:$pog->{'type'} OPTION-SELECTED:$SELECTED_OPTIONS{ $pog->{'id'} }");
			## remove FINDERs from array
			next if ($pog->{'type'} eq 'attribs');
			## no-inventory = no variables.
			next if ($pog->{'inv'} == 0);
			## only processing SOGs, ie non-inv POGs have already been removed
			## The line below is unecessary as pogs have already been removed by validation and have no amz variation keyword.
			## The line also does not stop the feed (only removes the option value) and therefore has no benefits.
			## It started to effect sogs after the POG upgrades and therefore has been commented out. 
			next if ($pog->{'amz'} eq '');

			my ($optioncatalog,$optiontheme) = (undef,undef);
			## NOTE: (this should probably be changed) the space is apparently required
			##			AND if it is .. andrew says to remember to also change the 'amz:grp_varkey' 'amz:grp_varkey_value'
			##			this seems to be done a few lines below (search for those attributes)
			if ($pog->{'amz'} =~ m/^(\w+)\: (.*?)$/) { ($optioncatalog,$optiontheme) = ($1,$2); }
			if ($optioncatalog eq '') {
				$lm->pooshmsg("ERROR|+Variation error - ID:$pog->{'id'} TYPE:$pog->{'type'} requires format 'Catalog: Theme'");
				}
			elsif ($optioncatalog ne $JSONREF->{'catalog'}) {
				## deprecation notice
				$lm->pooshmsg("DEPRECATION|+Variation error - ID:$pog->{'id'} TYPE:$pog->{'type'} catalog:$optioncatalog does not match product setting of catalog:$JSONREF->{'catalog'} (deprecated 7/24/12)");
				}
			elsif ((not defined $JSONREF->{'variation-themes'}) || ($JSONREF->{'variation-themes'} eq '')) {
				## well.. variations-themes is not specified for the catalog, that means:
				##		1. andrew hasn't created a specific list of allowed variation-themes in the json
				##		2. amazon allows any variation theme in this category, so we can't possibly validate that!
				}
			else {

				##	for some categories there are variations that can't be sent as individual variations.
				##		-	eg for category FineNecklaceBraceletAnklet variation 'StoneShape' must be sent with 'MetalType' as 'StoneShapeMetalType'
				## 	- therefore we can't accuratey check the validity of theme until later in the code when the themes of all options are combined 
				}

			#print "POG (build_prodFeed) ".Dumper($pog);
			## so at this point, this option is heading to amazon.
			## $catalog =~ s/FOOD/GOURMET/;	# bh: this probably shouldn't be here!

			$lm->pooshmsg(sprintf("DEBUG|+POG:%s CAT:%s THEME:%s",$pog->{'id'},$catalog,$optiontheme));
			## check if the theme is a valid category theme

			## not a RELATIONSHIP=none - so we'll lookup our value for this option.
			if ($PID eq $SKU) {
				$themes{ $optiontheme } = '*** VARIATION_PARENT ***';
				}
			else {
				my $found = 0;
				foreach my $sogoption (@{ $pog->{'@options'} }) {
					if ($sogoption->{'v'} eq $SELECTED_OPTIONS{ $pog->{'id'} }) {
						$found++;
						$themes{ $optiontheme } = $sogoption->{'prompt'};
						}
					}
				if (not $found) {
					$lm->pooshmsg(sprintf("ERROR|+Could not resolve inventory variation [%s][%s]",$pog->{'id'},$SELECTED_OPTIONS{ $pog->{'id'} }));
					}
				}

			}

		if (not $lm->can_proceed()) {
			}
		elsif (($P->fetch('zoovy:grp_parent') ne '') && ($PID eq $SKU)) {
			## VCONTAINER: vchild with options
			$AMZ_RELATIONSHIP = [ 'vcontainer', $P->fetch('zoovy:grp_parent') ];			
			}
		elsif (($Pref{'zoovy:grp_parent'} ne '') && ($PID ne $SKU)) {
			## VCCHILD: a product option, where the product itself has a parent (and is therefore grouped)
			$AMZ_RELATIONSHIP = [ 'vcchild', $Pref{'zoovy:grp_parent'} ];
			}
		elsif ($PID eq $SKU) { 
			## PARENT: a product with options
			$AMZ_RELATIONSHIP = [ 'parent', '' ];
			}
		else {
			$AMZ_RELATIONSHIP = [ 'child', $PID ];
			}
		}

	## SPECIAL CASE: "NPARENT" -- this will overwrite 
	## SANITY: at this point %themes is full populated with key=>variationname,val=>variationvalue
	##			  for this specific inventoriable option.
	if (not $lm->can_proceed()) {
		}
	elsif (scalar(keys %themes) > 2) {
	#if (scalar(keys %sog_variation_lookup) > 2) {
		$lm->pooshmsg("ERROR|+Too many variations for $PID ".join("/",keys %themes));
		}
	elsif ((grep(/^None$/,keys %themes)) && (scalar(keys %themes)>1)) {
		$lm->pooshmsg("ERROR|+Theme 'None' must be used exclusively");
		}
	elsif (grep(/^None$/,keys %themes)) {
		## Detect "NPARENT" or "NONE" 
		## some categories don't allow variations (or merchants don't want to send them for some reason), 
		##		so each option, child is sent up as its own product. 
		##		ie no parent relationship="NONE" effectively the children become orphans
		## 	CE, CAMERA, OFFICE, TOYSBABY, TOYS, TOOLS, WIRELESS 
		if ($P->has_variations('inv')) {
			if ($SKU eq $PID) {
				$AMZ_RELATIONSHIP = [ 'none', '' ];
				}
			else {
				$AMZ_RELATIONSHIP = [ 'none-option', '' ];
				}
			}
		elsif ($Pref{'zoovy:grp_parent'} ne '') {
			$AMZ_RELATIONSHIP = [ 'none', '' ];
			}
		elsif ($Pref{'zoovy:grp_children'} ne '') {
			$AMZ_RELATIONSHIP = [ 'none-grouped', '' ];
			}			
		else {
			## this line should NEVER be reached, but in theory the person COULD configure a base product as
			## theme None which makes no fucking sense, so we'll just throw this error below:
			$lm->pooshmsg("ERROR|+Internal logic error for theme type 'None' (requires inv,grp_parent, or grp_children)");
			}
		}

	if (not $lm->can_proceed()) {
		}
	elsif (not defined $AMZ_RELATIONSHIP) {
		## SANITY: so everything needs to have a relationship or it's going to error out.
		## the rules related to product options were already handled, so if we get here
		## we're GUARANTEED to not have product options
		if ($Pref{'zoovy:grp_parent'} ne '') {
			## this means "we have a parent"
			$AMZ_RELATIONSHIP = [ "vchild", $Pref{'zoovy:grp_parent'} ];
			}
		elsif (($Pref{'zoovy:grp_parent'} eq '') && ($Pref{'zoovy:grp_children'} ne '')) {
			## this means "we are a parent"
			$AMZ_RELATIONSHIP = [ "vparent", '' ];
			}
		else {
			## no special parentage, just a regular old product 
			$AMZ_RELATIONSHIP = [ 'base', '' ];
			}
		}

	##
	##	SANITY: at this point $AMZ_RELATIONSHIP is either set properly [ 'type','parentpid' ] or $ERROR is set.
	##			  ** DO NOT MODIFY AMZ_RELATIONSHIP BELOW THIS LINE **
	##
	## possible values:
	##		vcontainer, vcchild, parent, child, none, none-option, none-grouped, vchild, vparent, base
	##
	## reminder: vcontainers WILL NOT BE SENT to amazon
	##	note: parent,vparent are basically the same thing for amazon (both are parent)
	##	note: vchild,vcchild,child are basically the same thing for amazon (all are child)
	##

	##			
	## SET PARENTAGE
	##
	##		- 	parentage can optionally be set in the json config area for categories that do not follow the normal standard: 
	##			(normal standard: 'parent' for parents, 'child' for children and no parentage for base products.     	
	##			-	some categories have different values for parentage than others. 
	##				(ie. for 'home' the parentage for a parent is 'variation-parent' rather than 'parent')
	##			-	some categories require parentage for 'base' products.
	##				(ie. JEWELRY requires parentage to be set to 'child' for base products. HOME requires parentage to be set to 'base-product'. 

	if ($AMZ_RELATIONSHIP->[0] eq 'none') {
		$lm->pooshmsg("STOP|+relationship type 'none' is not sent to amazon (only none-option, none-group)");
		}
	elsif ($AMZ_RELATIONSHIP->[0] =~ /^(vcontainer)$/) { 
		$lm->pooshmsg("STOP|+relationship type 'vcontainer' is not sent to amazon");
		}

	## 		
	if ($lm->can_proceed()) {
		##
		## we normalize the relationship data in ($AMZ_RELATIONSHIP->[2])
		##	valid amazon /normalized/ relationship types:
		##		parent, child, base
		##
		$AMZ_RELATIONSHIP->[2] = '';  ## amazon relationships: parent,child,base,none
		$AMZ_RELATIONSHIP->[3] = '';  ## amazon parentage is: category specific parentage values ex: base-product
												## in other stupid instances amazon uses the word 'child' for every 'base' product
												## check parentage-values in the json files for more examples of this ludicrousy
												## NOTE: we should never use $AMZ_RELATIONSHIP->[3] for internal logic, amazon MAY change it.

		if ($AMZ_RELATIONSHIP->[0] =~ /^(parent|vparent)$/) { $AMZ_RELATIONSHIP->[2] = 'parent'; }
		elsif ($AMZ_RELATIONSHIP->[0] =~ /^(vcchild|vchild|child)$/) { $AMZ_RELATIONSHIP->[2] = 'child'; }
		elsif ($AMZ_RELATIONSHIP->[0] =~ /^(base)$/) { $AMZ_RELATIONSHIP->[2] = 'base'; }
		elsif ($AMZ_RELATIONSHIP->[0] =~ /^(none-grouped|none-option)$/) { $AMZ_RELATIONSHIP->[2] = 'none'; }
		elsif ($AMZ_RELATIONSHIP->[0] =~ /^(vcontainer)$/) { $AMZ_RELATIONSHIP->[2] = 'vcontainer'; } # never reached, just for clarity.
		else {
			## this line should *NEVER* Be reached, it indicates a mishandling of AMZ_RELATIONSHIP internally.
			$lm->pooshmsg(sprintf("ISE|+unknown AMZ_RELATIONSHIP[0]:%s - cannot continue",$AMZ_RELATIONSHIP->[0]));	
			}

		if ($AMZ_RELATIONSHIP->[2] eq 'none') {
			## the product doesn't need or support parentage types (this is fine)
			}
		elsif ($JSONREF->{'parentage-values'} eq '') {
			## the category doesn't have parentage values (most common)
			## parentage not defined in the json so we're going to trust $AMZ_RELATIONSHIP
			$AMZ_RELATIONSHIP->[3] = $AMZ_RELATIONSHIP->[2];
			if ($AMZ_RELATIONSHIP->[2] eq 'base') {
				# relationship for a base product is blank 
				$AMZ_RELATIONSHIP->[3] = '';
				}
			}
		else {
			##parentage has been set at json level
			my @PARENTAGE_VALUES = split(/,/,$JSONREF->{'parentage-values'});
			if ($AMZ_RELATIONSHIP->[2] eq 'parent') {
				$AMZ_RELATIONSHIP->[3] = $PARENTAGE_VALUES[0];
				}
			elsif ($AMZ_RELATIONSHIP->[2] eq 'child') {
				$AMZ_RELATIONSHIP->[3] = $PARENTAGE_VALUES[1];
				}
			elsif ($AMZ_RELATIONSHIP->[2] eq 'base') {
				## 
				$AMZ_RELATIONSHIP->[3] = $PARENTAGE_VALUES[2];
				}			
			else {
				$lm->pooshmsg(sprintf("ISE|+unknown AMZ_RELATIONSHIP[2]:%s for parentage - cannot continue",$AMZ_RELATIONSHIP->[2]));
				}
			}

		$lm->pooshmsg(sprintf("DEBUG|+AMZ_RELATIONSHIP 0:[%s] 1:[%s] 2:[%s] 3:[%s]",@{$AMZ_RELATIONSHIP}));
		}

	## Product->StandardProductID
	

		## couple of rules about UPCs
		## don't send UPC for parent 
		## UPC should be unique! so don't send same UPC for all children




	#####
	## VALIDATION
	## SKIP OUT of loop for the following reasons
	## only log error as needed
	## check all ERRORs first
	if (not $lm->can_proceed()) {
		}
	elsif (not defined $JSONREF) {
		$lm->pooshmsg("ERROR|+Invalid amz:catalog ($Pref{'amz:catalog'})");
		}
	elsif (($Pref{'amz:prod_cloth_cd_stylekwords'} eq '') && ($JSONREF->{'catalog'} eq 'APPAREL')) {
		$lm->pooshmsg("ERROR|+There are no Apparel Style Keywords entered for this product.");
		}
	elsif (
		($JSONREF->{'catalog'} ne 'SPORTS') && 
		($JSONREF->{'catalog'} ne 'APPAREL') && 
		($JSONREF->{'catalog'} ne 'CAMERA') && 
		($JSONREF->{'catalog'} ne 'GOURMET') && 
		($JSONREF->{'catalog'} ne 'CLOTHING') && 
		($JSONREF->{'catalog'} ne 'SHOES') && 
		($JSONREF->{'catalog'} ne 'HANDBAG') && 
		($JSONREF->{'catalog'} ne 'SHOEACCESSORY') && 
		($JSONREF->{'catalog'} ne 'EYEWEAR') && 
		($JSONREF->{'catalog'} ne 'MISC') && 
		($thesaurusinfo->{'ITEMTYPE'} eq '')
		) {
		$lm->pooshmsg("ERROR|+No Thesaurus Item Type (required for $JSONREF->{'catalog'})");
		}
	elsif (($Pref{'amz:prod_misc_producttype'} eq '') && ($JSONREF->{'catalog'} eq 'MISC')) {
		$lm->pooshmsg("ERROR|+No Misc Product Type");
		}
	elsif ($Pref{'amz:catalog'} =~ /^SOFTWARE.SOFTWAREGAMES/ &&
		($Pref{'amz:prod_swvg_swg_esrbrating'} eq '' ||
		  $Pref{'amz:prod_swvg_swg_mediaformat'} eq '' ||
		  $Pref{'amz:prod_swvg_swg_os'} eq '' ||
		  $Pref{'amz:prod_swvg_swg_swvggenre'} eq '') ) {
			## required fields for SOFTWARE
			$lm->pooshmsg("ERROR|+Missing SoftwareGames specifics");
			}

	## check if inventorable option group is a SOG vs POG
	## remember that products w/non-inv p/sog(s) are "allowed"...
	##		meaning that these options are removed and only the parent (and inv SOGs) are syn'd
	## 	-- orders created with these products use suggest_variations to determine the correct STID
	##			that includes the non-inv p/sog(s)
	elsif ($P->has_variations('pinv')) {
		$lm->pooshmsg("ERROR|+Inventorable POGs not allowed");
		}

	###### END to VALIDATION checks that cause ERRORs #######
	if ($lm->can_proceed()) {
		## check for VALIDATION WARNINGs
		## AMZ made department optional (and sometimes errors when its there)
		if (($Pref{'amz:prod_cloth_cd_clothingtype'}) eq '' && ($JSONREF->{'catalog'} eq 'APPAREL')) {
			$lm->pooshmsg("WARN|SKU:$SKU|+No Apparel Clothing Type");
			}
		elsif (($Pref{'amz:prod_cloth_cd_dpt'} eq '') && ($JSONREF->{'catalog'} eq 'APPAREL')) {	
			## AMZ made department optional (and sometimes errors when its there)
			$lm->pooshmsg("WARN|SKU:$SKU|+No Apparel Department");
			}			
		}
		
	## want to add UPC check here (need to check children too, hmm)
	###### END OF VALIDATION
	


	## REMOVED 1/25/12
	#foreach my $attrib (keys %{$pref}) {
	#	## NOTE: this logic below could EVENTUALLY be moved in ZOOVY.pm to upgrade the whole database! (yay!)
	#	next if ($attrib !~ /amz:prod/);
	#	my $value = $Pref{$attrib};
	#	next if ($value eq 'NA' || $value eq '' || $value eq ' '); ## need to turn off validation on UI
	#	if ($attrib =~ /^(.*?)_[\d]*$/) {
	#		## merge the amz:prod_xyz_1, amz:prod_xyz_2, etc. into just amz:prod_xyz
	#		$Pref{$1} .= $Pref{$attrib}."\n";
	#		delete $Pref{$attrib};
	#		}
	#	}






	## SET VARIATION THEME
	##		-	each category/sub category has it's own allowed variations 
	## 	-	when an amazon category has dual options (ie. Color and Size) they should be combined.
	##		-	every category chooses how they want variation theme to be formatted.
	##				ie APPAREL, CLOTHING & HOME all allow 'Size' and 'Color' dual variations but theme is set differently for each: 
	##					(SPORTS - 'ColorSize', APPAREL - 'SizeColor' and HOME - 'Size-Color')

	##		- for some categories there are variations that can't be sent as individual variations.
	##			ie for category FineNecklaceBraceletAnklet variation 'StoneShape' must be sent with 'MetalType' as 'StoneShapeMetalType'

	my $theme = '';
	my @VARKEYS = ();
	my @VARIATIONS = ();
	my @POSSIBLE_VARIATIONTHEMES = ();
	if (not $lm->can_proceed()) {
		}
	elsif (scalar(keys %themes)==0) {
		## there are no options with a theme set, we can skip the rest, pretend we don't have *any* variations since
		##	no category requires variations(methinks??) BH
		}
	elsif (scalar(keys %themes)>2) {
		$lm->pooshmsg(sprintf("ERROR|+Too many variations[%s] defined (max[2])",join(',',keys %themes)));		
		}
	elsif ($JSONREF->{'variation-themes'} ne '') {
		## 'variation-themes' field in the json should include only the variation themes that are allowed for that category/sub category 
		## 	- formatting in json should be (in order of preference)
		## 		ie. key1+key2,key1,key2
		##			-	the theme for a vaparent is entered manually and has one combined value rather than 2 single values (ie SizeColor rather than Size, Color)
		##				for this reason we need to add an allowed value to the json for vparents,
		##					ie. $JSONREF->{'variation-themes'})  now becomes key1+key2,key1key2,key1,key2
		@POSSIBLE_VARIATIONTHEMES = split(/,/,$JSONREF->{'variation-themes'});
		}
	else {
		## non-validated variation themes, anything goes!
		## this can *eventually* be removed when all possible theme variations for amason are specified.
		@POSSIBLE_VARIATIONTHEMES = (join("+",sort keys %themes));
		}

	if (not $lm->can_proceed()) {
		}
	elsif (scalar(@POSSIBLE_VARIATIONTHEMES)>0) {	
		## SANITY: if we get in here, we have options, and one or more possible variation themes.
		foreach my $try_theme (@POSSIBLE_VARIATIONTHEMES) {
			next if (scalar(@VARKEYS)>0);
			@VARKEYS = split(/\+/,$try_theme);
			foreach my $key (@VARKEYS) {
				if (not defined $themes{$key}) { @VARKEYS = (); }	## this one did not match.
				}
			}
			
		if (scalar(@VARKEYS)==0) {
			## there were no valid variation keywords found
			$lm->pooshmsg(sprintf("ERROR|+No compatible variation theme(s)[%s]. Allowed values for $Pref{'amz:catalog'} are:%s",join('+',sort keys %themes),join(",",@POSSIBLE_VARIATIONTHEMES)));
			}
		elsif (scalar(@VARKEYS) != scalar(keys %themes)) {
			## there were less valid variation keywords than variations in the product
			##		-	this was probably because only 1 out of 2 variation keywords used was valid.
			##		-	we are going to throw an error here because the theme is not going to match the variations sent.
			##			-	if the variation keyword is not valid it almost certainly means the variation is also invalid. 
			$lm->pooshmsg(sprintf("ERROR|+Non-matched variation themes(s)[%s]. Allowed values for $Pref{'amz:catalog'} are:%s",join('+',sort keys %themes),join(",",@POSSIBLE_VARIATIONTHEMES)));
			}
		else {
			## we have a valid theme
			my $JOINER = '-';
			if (($catalog eq 'APPAREL' || $catalog eq 'SPORTS' || $catalog eq 'CLOTHING' || 
				$catalog eq 'SHOES' || $catalog eq 'SHOEACCESSORY' || $catalog eq 'HANDBAG' || $catalog eq 'TOYS')) { 
				$JOINER = ''; 
				}		
			$theme = join($JOINER,@VARKEYS);
			}
		}

	$CSV->{'variation_theme'} = $theme;

	##
	## SANITY: at this point we've determined what type of SPID we're using, or we won't be returning
	##				any data .. and we should probably set $ERROR
	## 
	if (not $lm->can_proceed()) {
		## shit already happened
		}
	elsif ($AMZ_RELATIONSHIP->[1] eq 'vcontainer') {
		## NOTE: intentionally duplicated code, failsafe
		$lm->pooshmsg("STOP|+vcontainer products are never ever sent to amazon");
		}


	# my $prodxml = undef;
	my $xml = '';
	require XML::Writer;
	my $writer = new XML::Writer(OUTPUT => \$xml, UNSAFE=>1, DATA_INDENT => 3, ENCODING => 'utf-8');
	if ($lm->can_proceed()) {

		# $prodxml = XML::Smart->new();
		# $prodxml = $prodxml->{'Message'};
		$writer->startTag("Message");

		## MessageID, Product->SKU
		# $prodxml->{'MessageID'}->content($MSGID = int(scalar(@{$xmlar}))+1);
		$writer->dataElement("MessageID",$MSGID = scalar(@{$xmlar})+1);
		$writer->startTag('Product');
		
		$writer->dataElement('SKU',$CSV->{'item_sku'} = $SKU);
		# $prodxml->{'Product'}{'SKU'}->content($SKU);

		my $AMZSPID = undef;	
		## if we have an ASIN, we'll use that over everything else. 
		## only use asin for an option if it was defined for that specific option (ie use_asin) - make sure it's unique
		##	 Amazon "Standard Product ID" -- tells us what type of data we're going to use
		##	to identify this particular product. .. it's an arrayref [ 'PARENT|UPC|ASIN|EAN|ERR|EXEMPT', value ]
		## yay, already good to go!
		my $ASIN = $P->skufetch($SKU,'sku:amz_asin') ||  $P->skufetch($SKU,'amz:asin');
		if ($ASIN) {
			if (length($ASIN) ne 10) {		
				## 12/10/11: Prevent 5000 response - XML Parsing Error: cvc-minLength-valid: Value \'9999\' with length = \'4\' is not facet-valid with respect to minLength \'8\' for type \'#AnonType_ValueStandardProductID\'.
				$lm->pooshmsg(sprintf("ERROR|+SKU:$SKU|+ASIN [%s] must be 10 digits, is invalid, and was not used.",$ASIN));
				}
			## ($relationship eq 'base') || ($relationship eq 'child') ) {	
			## only use asin for a child if it's merchant-defined and specific to that child 
			$AMZSPID = [ 'ASIN',$ASIN ];
			}
		elsif ($AMZ_RELATIONSHIP->[0] =~ /^(vparent|parent)$/) {
			## As near as I can tell.. parents don't require Standard Product Id's.
			$AMZSPID = [ 'PARENT', '' ];
			}
		elsif ($P->skufetch($SKU,'amz:asin') eq '') {
			## no ASIN set, nothing to see here/use.
			}

		## catch invalid merchant-defined UPCs
		#if ((not defined $AMZSPID) && ($Pref{'zoovy:prod_upcfake'} ne '')) {
		#	## apparently we've generated a fake upc for amazon / buy.com? .. we will trust this blindly!
		#	$AMZSPID = [ 'UPC', $Pref{'zoovy:prod_upcfake'} ];
		#	}
	
		if ((not defined $AMZSPID) && (($P->skufetch($SKU,'sku:ean') ne '') || ($P->skufetch($SKU,'zoovy:prod_ean') ne ''))) {
			## product has an EAN -- lets use that! .. we don't have a way to check to see if this is
			##	actually a valid EAN right now.
			my $ean = $P->skufetch($SKU,'sku:ean') || $P->skufetch($SKU,'zoovy:prod_ean');
			$ean =~ s/[^\d]+//g; 	## strip non-numeric characters
			if ((length($ean)==13) || (length($ean)==14)) {
				$AMZSPID = [ 'EAN', $ean ];
				}
			}

		## okay so lets do a check to see if we've got a real upc
		if ((not defined $AMZSPID) && (($P->skufetch($SKU,'sku:upc') ne '') || ($P->skufetch($SKU,'zoovy:prod_upc') ne ''))) {
			## only use prod_upc for a child if it's merchant-defined and specific to that child 
			print STDERR "Checking validity of UPC\n";	 
			my $UPC = $P->skufetch($SKU,'sku:upc') || $P->skufetch($SKU,'zoovy:prod_upc');
			$UPC =~ s/[^\d]+//g; 	## strip non-numeric characters
			my $upcOBJ = new Business::UPC($UPC);
			if ((defined $upcOBJ) && ($upcOBJ->is_valid) && (length($UPC) <= 12) && (length($UPC) >= 10)) {
				## hurrah! it's a valid UPC, it's got a good checksum, it's between 10 and 12 digits!
				if ($UPC =~ /^(2|4)/) {
					## crap.. it was reserved [by Amazon as noted in their docs, no clue why]
					$lm->pooshmsg("WARN|+UPC [".$UPC."] is reserved by Amazon(starts w/2 or 4).");
					}
				else {
					$AMZSPID = [ 'UPC', $UPC ];
					}
				}
			elsif ((length($UPC)==13) || (length($UPC)==14)) {
				## backward compatibility hack:
				## apparently sometimes customers are allowed to put EAN's into the UPC field.
				## EAN's are supposedly always 13 or 14 characters ..	we will trust this blindly.
				$AMZSPID = [ 'EAN', $UPC ];
				}
			else {
				$lm->pooshmsg("WARN|SKU:$SKU|SRC:PRODUCT|+UPC [".$UPC."] seems invalid");
				}
			}

		# print "CATALOG[$catalog]\n"; die();
		if (defined $AMZSPID) {
			## no need to run the next statement, .. we've got a UPC!
			}
		## current categories that require UPCs
		elsif (
			grep(/^(APPAREL|AUTOPART|CLOTHING|MUSICINST|HOME|CE|ELECTRONIX|WIRELESS|TOYS|TOYSBABY|SOFTWARE|SHOES|HANDBAG|EYEWEAR|SHOEACCESSORY|CAMERA|MISC|HEALTH|TOOLS|OFFICE|SPORTS|PETSUPPLY)$/,$catalog) 
			 || ($catalog eq 'JEWELRY' && $amz_subcat eq 'Watch')) {

			## PrivateLabel => merchant has petitioned to Amazon to exempt them from the UPC requirement
			## ie their products are unique to the merchant, and are sold under their own 'PrivateLabel'
			if (not defined $userref->{'*SO'}) {
				warn "Could not get private_label settings due to missing *SO object (okay if in debug)";
				}
			elsif (int($userref->{'*SO'}->get('.private_label'))>0) {
			# if ($userref->{'PRIVATE_LABEL'}>0) {
				$AMZSPID = [ 'EXEMPT', 'PrivateLabel Merchant' ];
				## need to add $prodxml->{'Product'}{'RegisteredParameter'}->content('PrivateLabel');
				## after ProductData 
				}
			elsif (not defined $userref->{'*SO'}) {
				$lm->pooshmsg("ISE|+userref->*SO was not defined so we cant do UPC_CREATION");
				}
			elsif (int($userref->{'*SO'}->get('.upc_creation'))>0) {
				## woot, apparently we can make up/lookup fake UPC's.
				my ($fakeupc) = &ZTOOLKIT::FAKEUPC::fmake_upc($userref->{'USERNAME'},$SKU);
				if ($fakeupc eq '') {
					$lm->pooshmsg("WARN|+Could not generate fake UPC (possibly out of numbers)");
					}
				else {
					$AMZSPID = [ 'UPC', $fakeupc ];
					}
				}
			else {
				$lm->pooshmsg("WARN|+UPC or ASIN required. Hint: Turn on setting to automatically create Fake UPC");
				}	
			}
		## all other categories do not require UPCs
		else {
			$AMZSPID = [ 'EXEMPT', 'Category does not require UPCs' ];
			}


		if ($AMZSPID->[0] eq 'PARENT') {
			## as near as I can tell.. parent's don't need standard product id's EVER..
			}
		elsif ($AMZSPID->[0] eq 'EXEMPT') {
			## merchant or category is exempt
			}
		elsif ($AMZSPID->[0] eq 'ASIN') {
			## Per discussion with Andrew on 20091203 - ASIN IS ABSOLUTELY FUCKING ALLOWED it's in the god damn xsd
			## but the error message that amazon sends back is an absolutely steaming pile of shit that infers that
			## you can *ONLY* use a UPC, ISBN, or EAN -- which is the dumbest fucking thing I've heard in a long time.
			## thank god i never listen to andrew. - bh.
			$writer->startTag('StandardProductID');
				$writer->dataElement('Type','ASIN');
				$writer->dataElement('Value',$AMZSPID->[1]);
			$writer->endTag('StandardProductID');
			$CSV->{'external_product_id_type'} = 'ASIN';
			$CSV->{'external_product_id'} = $AMZSPID->[1];
			#$prodxml->{'Product'}->{'StandardProductID'}->{'Type'}->content('ASIN');
			# $prodxml->{'Product'}->{'StandardProductID'}->{'Value'}->content($AMZSPID->[1]);
			}
		## only use merchant-defined UPC if this PID doesn't have inventorable options
		## and if its a base product or... upc has been defined at the SKU level
		elsif ($AMZSPID->[0] eq 'UPC') {
			# print STDERR "USING UPC: $AMZSPID->[1]}\n";
			$writer->startTag('StandardProductID');
				$writer->dataElement('Type','UPC');
				$writer->dataElement('Value',$AMZSPID->[1]);
			$writer->endTag('StandardProductID');
			$CSV->{'external_product_id_type'} = 'UPC';
			$CSV->{'external_product_id'} = $AMZSPID->[1];
			#$prodxml->{'Product'}->{'StandardProductID'}->{'Type'}->content('UPC');
			#$prodxml->{'Product'}->{'StandardProductID'}->{'Value'}->content($AMZSPID->[1]);
			}
		elsif ($AMZSPID->[0] eq 'EAN') {
			# print STDERR "USING EAN: $AMZSPID->[1]\n";
			$writer->startTag('StandardProductID');
				$writer->dataElement('Type','EAN');
				$writer->dataElement('Value',$AMZSPID->[1]);
			$writer->endTag('StandardProductID');
			$CSV->{'external_product_id_type'} = 'EAN';
			$CSV->{'external_product_id'} = $AMZSPID->[1];
			#$prodxml->{'Product'}->{'StandardProductID'}->{'Type'}->content('EAN');
			#$prodxml->{'Product'}->{'StandardProductID'}->{'Value'}->content($AMZSPID->[1]);
			}
		else {
			## This line should never be reached!
			$lm->pooshmsg("ERROR|+Unknown Amazon Standard Product ID Type $AMZSPID->[0]");
			}

		## end of StandardProductID

		## Product->ProductTaxCode
		##	probably need to make this editable
		# $prodxml->{'Product'}{'ProductTaxCode'}->content('A_GEN_TAX');
		$writer->dataElement('ProductTaxCode',$CSV->{'product_tax_code'} = 'A_GEN_TAX');
	
		## Product->LaunchDate	
		# $prodxml->{'Product'}{'LaunchDate'}->content(&AMAZON3::amztime(time()));
		$writer->dataElement('LaunchDate',&AMAZON3::amztime(time()));
		}

	if ($lm->can_proceed()) {
		##	CONDITION
		## Product->Condition->ConditionType, where is this settable in ZOOVY
		## 	amazon allow a bigger variety of conditons than other marketplaces. If 'zoovy:prod_condition' was set to one of these
   	## 	it could cause an invalid value to be sent to the other marketplace. Worse still, depending on the regex, we could end
	   ## 	sending new instead of used to the other marketplaces. I have added 'amz:prod_condition' to allow for the other conditions.

		## Allowed values: New,UsedLikeNew,UsedVeryGood,UsedGood,UsedAcceptable,CollectibleLikeNew,CollectibleVeryGood,CollectibleGood,CollectibleAcceptable,Refurbished,Club.
		##  
		my $conditionType = &AMAZON3::canipleasehas($P->prodref(),'amz:prod_condition','zoovy:prod_condition');
		$conditionType =~ s/ //g; ## remove the spaces
		my @ALLOWED_CONDITIONS = ('New','UsedLikeNew','UsedVeryGood','UsedGood','UsedAcceptable','CollectibleLikeNew','CollectibleVeryGood','CollectibleGood','CollectibleAcceptable','Refurbished','Club');

		if (not defined $conditionType) { 
			$conditionType = 'New'; 
			}
		elsif ($conditionType =~ m/^(New|UsedLikeNew|UsedVeryGood|UsedGood|UsedAcceptable|CollectibleLikeNew|CollectibleVeryGood|CollectibleGood|CollectibleAcceptable|Refurbished|Club)$/i) {
			## make sure we only send values allowed by amazon
			$conditionType =~ s/new/New/i;
			$conditionType =~ s/usedlikenew/UsedLikeNew/i;
			$conditionType =~ s/usedverygood/UsedVeryGood/i;
			$conditionType =~ s/usedgood/UsedGood/i;
			$conditionType =~ s/usedacceptable/UsedAcceptable/i;
			$conditionType =~ s/collectiblelikenew/CollectibleLikeNew/i;
			$conditionType =~ s/collectibleverygood/CollectibleVeryGood/i;
			$conditionType =~ s/collectiblegood/CollectibleGood/i;
			$conditionType =~ s/collectibleacceptable/CollectibleAcceptable/i;
			$conditionType =~ s/(refurbished|reconditioned|refurb$)/Refurbished/i;
			$conditionType =~ s/club/Club/i;
			}
	
		## Since we're using regex to convert lets do one final check to make sure we have a valid value.
		$writer->startTag('Condition');
		if (scalar(@ALLOWED_CONDITIONS)>0) {
			## this should always be fine.
			my $condition_is_fine = 0;
			foreach my $allowed_condition (@ALLOWED_CONDITIONS) {
				if ($allowed_condition eq $conditionType) { $condition_is_fine++; }
					}
			if (not $condition_is_fine) {
				## We do not have a valid unit of measure 
				$lm->pooshmsg("ERROR|+Invalid Condition type ($conditionType) entered. Please try one of the following: ".join(", ",@ALLOWED_CONDITIONS).
							". If you are using '$conditionType' for another markeplace you can set the Amazon condition with attribute 'amz:prod_condition' instead");
				}
			else {
				## we have a valid Conditon
				# $prodxml->{'Product'}{'Condition'}{'ConditionType'}->content($conditionType);
				$writer->dataElement('ConditionType',$CSV->{'condition_type'} = $conditionType);
				}
			}

		## added 2008-03-19
		## Condition Note
		if (&AMAZON3::is_defined($Pref{'zoovy:prod_condition_note'})) {
			my $conditionNote = substr(&ZTOOLKIT::htmlstrip($Pref{'zoovy:prod_condition_note'}),0,199);
			$conditionNote = &ZTOOLKIT::stripUnicode($conditionNote);
			$lm->pooshmsg("DEBUG|+Using Condition Note: $conditionNote");
			# $prodxml->{'Product'}{'Condition'}{'ConditionNote'}->content($conditionNote);
			$writer->dataElement('ConditionNote',$CSV->{'condition_note'} = $conditionNote);
			}
		$writer->endTag('Condition');
		}


	## ***changed by options
	## Product->DescriptionData->Title
	## commented out htmlstrip (was stripping ' also), will put back in if its an issue
	## put back in on 10/20/2006, ' strip was taken out of sub
	#my $title = &ZTOOLKIT::htmlstrip($Pref{'zoovy:prod_name'},2);

	$writer->startTag('DescriptionData');
	if (not $lm->can_proceed()) {
		## bad shit already happened
		}
	else {
		my $title = &AMAZON3::canipleasehas($P->prodref(),'amz:prod_name','zoovy:prod_name');
		if ($P->has_variations('inv') && ($P->pid() ne $SKU)) {
			## append pog description to title.
			my $variation_detail = $P->skufetch($SKU,'sku:variation_detail');
			if ($title eq '') {
				$lm->pooshmsg("ISE|+Empty amz:prod_name zoovy:prod_name field(s) are blank");
				}
			elsif ($variation_detail eq '') {
				$lm->pooshmsg("ISE|+sku:variation_detail is blank - will not send product.");
				}
			elsif (length($title)+length($variation_detail)>249) {
				$lm->pooshmsg(sprintf("WARN|SKU:$SKU|+Title length(%d) + Option length(%d) exceeds 249 characters and will be truncated",length($title),length($variation_detail)));
				}
			$title = sprintf("%s %s",$title,$variation_detail);
			}
		$title =~ s/\&reg;/(tm)/g;
		$title =~ s/\n/ /g;
		$title =~ s/[\s]+/ /gs; 	# remove duplicate spaces
		$title = &ZTOOLKIT::htmlstrip($title,2);
		$title = ZTOOLKIT::stripUnicode($title);
		if (($AMZ_RELATIONSHIP->[2] eq 'parent') && (length($title)>80) && ( 
			($JSONREF->{'catalog'} eq 'APPAREL') || 
			($JSONREF->{'catalog'} eq 'CLOTHING') || 
			($JSONREF->{'catalog'} eq 'SHOES') || 
			($JSONREF->{'catalog'} eq 'HANDBAG') || 
			($JSONREF->{'catalog'} eq 'SHOEACCESSORY') || 
			($JSONREF->{'catalog'} eq 'EYEWEAR'))) {
			## the maximum length a title can be for a parent in a clothing category is 80
			$lm->pooshmsg(sprintf("WARN|SKU:$SKU|+Title length:%d is longer than the maximum allowed length (80 characters) for a parent in a clothing category and was truncated.",length($title)));
			$title = substr($title, 0, 80);
			}
		elsif (length($title)>249) {
			## all other products can have up to 249 characters in their title
			$lm->pooshmsg(sprintf("WARN|SKU:$SKU|+Title length:%d is longer than allowed 249 characters and was truncated.",length($title)));
			$title = substr($title, 0, 249);
			}
		elsif ($title eq '') {
			$lm->pooshmsg("ERROR|+Empty title");
			}
	
		# $prodxml->{'Product'}{'DescriptionData'}{'Title'}->content($title);
		$writer->dataElement('Title', $CSV->{'item_name'} = $title);
		}

	## Product->DescriptionData->Brand
	##	set as defined, else use USERNAME
	if (not $lm->can_proceed()) {
		## bad shit already happened
		}
	elsif ($Pref{'zoovy:prod_mfg'} eq ' ') {
		## 1/25/12
		$lm->pooshmsg("WARN|+Product manufacturer has a space in it, this will not be allowed in the future.");
		delete $Pref{'zoovy:prod_mfg'};
		}


	if ($lm->can_proceed()) {
		## 
		##			DESCRIPTION AND BULLET CODE
		##
		if (&AMAZON3::is_defined($Pref{'amz:prod_brand'})) {
			# $prodxml->{'Product'}{'DescriptionData'}{'Brand'}->content(substr(ZTOOLKIT::stripUnicode($Pref{'zoovy:prod_mfg'}),0,49));
			$writer->dataElement('Brand',$CSV->{'brand_name'} = substr(ZTOOLKIT::stripUnicode($Pref{'amz:prod_brand'}),0,49));
			}
		elsif (&AMAZON3::is_defined($Pref{'zoovy:prod_brand'})) {
			# $prodxml->{'Product'}{'DescriptionData'}{'Brand'}->content(substr(ZTOOLKIT::stripUnicode($Pref{'zoovy:prod_mfg'}),0,49));
			$writer->dataElement('Brand',$CSV->{'brand_name'} = substr(ZTOOLKIT::stripUnicode($Pref{'zoovy:prod_brand'}),0,49));
			}
		elsif (&AMAZON3::is_defined($Pref{'zoovy:prod_mfg'})) {
			# $prodxml->{'Product'}{'DescriptionData'}{'Brand'}->content(substr(ZTOOLKIT::stripUnicode($Pref{'zoovy:prod_mfg'}),0,49));
			$writer->dataElement('Brand',$CSV->{'brand_name'} = substr(ZTOOLKIT::stripUnicode($Pref{'zoovy:prod_mfg'}),0,49));
			}
		else {
			$lm->pooshmsg("WARN|+Set zoovy:prod_mfg field (Amazon Brand) is required, defaulting to $USERNAME.");
			# $prodxml->{'Product'}{'DescriptionData'}{'Brand'}->content($USERNAME);
			$writer->dataElement('Brand',$CSV->{'brand_name'} = $USERNAME);
			}


		## Product->DescriptionData->Description
		##	take out encodings, [[CDATA]]
		##	shorten to 2000 chars
		my $description = '';
		## added prod_features 2008-04-22 - patti
		my $contents = $Pref{'zoovy:prod_features'}."\n".$Pref{'zoovy:prod_desc'}."\n".$Pref{'zoovy:prod_detail'};
		if ($Pref{'amz:prod_desc'} ne '') { $contents = $Pref{'amz:prod_desc'}; }

		## strip out unicode characters
		$contents = ZTOOLKIT::stripUnicode($contents);

		my @BULLETS = ();
		if ($Pref{'amz:key_features'} ne '') {
			foreach my $line (split(/\*/, $Pref{'amz:key_features'})) {
				$line =~ s/^[\s]+//gs; 	# strip leading whitespace
				$line =~ s/[\s]+$//gs; 	# strip trailing whitespace
				next if ($line eq '');
				push @BULLETS, $line;
				}
			}

		## strip out wiki text
		## stripping out all wiki, except converting newlines to <br>
		##		Amazon now allows <br>'s!!!!
		$contents =~ s/\r\n/\n/gs;	# convert CRLF to just CR
		foreach my $line (split(/\n/,$contents)) {
			$line =~ s/\<li\>/\&li\;/ig;
		
			my $ch = substr($line,0,1);
			my $is_bullet = 0;

			$line = &ZTOOLKIT::stripUnicode($line);

			# print STDERR "LINE: $line CH: $ch\n";
			if ($ch eq '|' || $ch eq '=') {
				$line =~ s/|//g;
				$line =~ s/=/ /g;
				}
			## skip wiki bullets, information will be put in BulletPoints
			## will eventually need to deal with BulletPoints (in excess of 5)
			## that don't make in BulletPoints or Description
			elsif ($ch eq '*') {
				$line =~ s/^\*//;
				$line = &ZTOOLKIT::htmlstrip($line,2);
				$line =~	s/\[\[(.*)\].*\]/$1/g;

				if (($line ne '') && (scalar(@BULLETS)<5)) { 
					push @BULLETS, $line; 
					$line = undef;
					}
				}

			if (defined $line) {
				$description .= "$line\n";
				}
			}

		##okay yes, I know its listed twice
		## htmlstrip unescapes HTML at the end, i need this stripped too
		$description =~ s/\n/-BREAK-/g;	## Amazon now allows <br>, let's convert the newlines
		$description =~ s/\<[Bb][Rr]\>/-BREAK-/g;	## Amazon now allows <br>, let's convert the html <br>'s
	
		$description =~ s/\&nbsp;/ /g;
		$description = &ZTOOLKIT::htmlstrip($description,2);
		$description =~ s/\!\[CDATA\[//; $description =~ s/\]\]//;

		## need to strip encoded html, &reg; &#8821;
		#$description =~ s/\&(\#\d+|\w+)\;//g;
		$description =~ s/%hardbreak%/ /g;
		$description =~ s/%softbreak%/ /g;

		## strip out wiki urls
		## [[Patti's URL]:popup=http://patti.zoovy.com/url] => Patti's URL
		$description =~ s/\[\[(.*)\].*\]/$1/g;
		$description =~ s/\={2,}/ /g;
		$description =~ s/\'{2,}/ /g;
	
		## escape ampersands &, and < >
		$description =~ s/\&/&amp;/g;
		$description =~ s/\</\&lt\;/g;
		$description =~ s/\>/\&gt\;/g;

		## limit merchants to 2 br's, else it'll start looking bad
		$description =~ s/(-BREAK-){3,}/-BREAK--BREAK-/g;

		#$description =~ s/-BREAK-/\&lt\;BR\&gt\;/g;	
		$description =~ s/-BREAK-/<BR>\n/g;				## apparently Amazon likes BR's
 
		if (length($description)>2000) {
			$lm->pooshmsg(sprintf("WARN|+Description length of %d characters is longer than allowed length.",length($description)));
			}
 
		# $prodxml->{'Product'}{'DescriptionData'}{'Description'}->content(substr($description,0,2000));
		$writer->dataElement('Description',$CSV->{'product_description'} = substr($description,0,2000));

		my $i = 0;
		foreach my $bullet (@BULLETS) {
			## strip wiki
			$bullet =~ s/\={2,}/ /g;
			$bullet = &ZTOOLKIT::stripUnicode($bullet);
	
			## only 5 Bullet Points are allowed
			$bullet = substr($bullet,0, 100);
			# $prodxml->{'Product'}{'DescriptionData'}{'BulletPoint'}[$i++]->content($bullet);
			$writer->dataElement('BulletPoint',$bullet);
			$i++;
			$CSV->{sprintf('bullet_point%d',$i)} = $bullet;
			}
		}

	## Product->DescriptionData->ItemDimensions->Length,Width,Height
	## note: Amazon will error if width and length are given w/o height
	## lots of extra code to add unitOfMeasure, this is required by Amazon in most cases
	if (not $lm->can_proceed()) {
		}
	elsif ($Pref{'zoovy:prod_length'} ne '' &&
		 $Pref{'zoovy:prod_width'} ne '' &&
		 $Pref{'zoovy:prod_height'} ne '' ) {

		## LEGNTH
		$writer->startTag('ItemDimensions');
		if ($Pref{'zoovy:prod_length'} ne '') {
			my $l = $Pref{'zoovy:prod_length'};
			$l =~ m/(\d+\.?\d+)(.*)/;
			$l = $1; 
			my $lunit = $2;
			$lunit =~ s/ //g;
			# $prodxml->{'Product'}{'DescriptionData'}{'ItemDimensions'}{'Length'}->content(sprintf("%.2f",$l));

			## unitOfMeasure			
			if ($lunit eq "\"" || $lunit =~ /inch/i || $lunit eq '') { 
				$lunit = "IN"; 
				}
			elsif ($lunit eq "'" || $lunit =~ /foot/i || $lunit =~ /ft/i) { 
				$lunit = "FT";
				}
			else { $lunit = uc($lunit); }
			# $prodxml->{'Product'}{'DescriptionData'}{'ItemDimensions'}{'Length'}{'unitOfMeasure'} = $lunit;

			$writer->dataElement('Length',
				$CSV->{'item_length'} = sprintf("%.2f",$l),
				'unitOfMeasure'=> $CSV->{'item_length_unit_of_measure'} = $lunit);
			}

		## WIDTH
	 	if ($Pref{'zoovy:prod_width'} ne '') {
			my $w = $Pref{'zoovy:prod_width'};
			$w =~ m/(\d+\.?\d+)(.*)/;
			$w = $1; 
			my $wunit = $2;
			$wunit =~ s/ //g;
			# $prodxml->{'Product'}{'DescriptionData'}{'ItemDimensions'}{'Width'}->content(sprintf("%.2f",$w));

			## unitOfMeasure			
			if ($wunit eq "\"" || $wunit =~ /inch/i || $wunit eq '') { 
				$wunit = "IN"; 
				}
			elsif ($wunit eq "'" || $wunit =~ /foot/i || $wunit =~ /ft/i) { 
				$wunit = "FT";
				}
			else { $wunit = uc($wunit); }
			#$prodxml->{'Product'}{'DescriptionData'}{'ItemDimensions'}{'Width'}{'unitOfMeasure'} = $wunit;
			$writer->dataElement('Width',
				$CSV->{'item_width'} = sprintf("%.2f",$w),
				'unitOfMeasure'=>$CSV->{'item_width_unit_of_measure'} = $wunit);
			}

		## HEIGHT
	 	if ($Pref{'zoovy:prod_height'} ne '') {
			my $h = $Pref{'zoovy:prod_height'};
			$h =~ m/(\d+\.?\d+)(.*)/;
			$h = $1; 
			my $hunit = $2;
			$hunit =~ s/ //g;
			# $prodxml->{'Product'}{'DescriptionData'}{'ItemDimensions'}{'Height'}->content(sprintf("%.2f",$h));
			
			## unitOfMeasure			
			if ($hunit eq "\"" || $hunit =~ /inch/i || $hunit eq '') { 
				$hunit = "IN"; 
				}
			elsif ($hunit eq "'" || $hunit =~ /foot/i || $hunit =~ /ft/i) { 
				$hunit = "FT";
				}
			else { $hunit = uc($hunit); }
			# $prodxml->{'Product'}{'DescriptionData'}{'ItemDimensions'}{'Height'}{'unitOfMeasure'} = $hunit;
			$writer->dataElement('Height',
				$CSV->{'item_height'} = sprintf("%.2f",$h),
				'unitOfMeasure'=>$CSV->{'item_height_unit_of_measure'} =$hunit);			
			}
		
		## WEIGHT
	 	if ($Pref{'zoovy:prod_weight'} ne '') {
			my $w = $Pref{'zoovy:prod_weight'};
			require ZSHIP;
			$w = &ZSHIP::smart_weight($w);
			# $prodxml->{'Product'}{'DescriptionData'}{'ItemDimensions'}{'Weight'}->content(sprintf("%.2f",$w));
			# $prodxml->{'Product'}{'DescriptionData'}{'ItemDimensions'}{'Weight'}{'unitOfMeasure'} = 'OZ';
			$writer->dataElement('Weight',
				$CSV->{'item_weight'} = sprintf("%.2f",$w),
				'unitOfMeasure'=>$CSV->{'item_weight_unit_of_measure'} = 'OZ');
			}
		$writer->endTag('ItemDimensions');
		}
		
	## end of Length, Width, Height, Weight

	## Product->DescriptionData->ShippingWeight
	## Product->DescriptionData->ShippingWeight->unitOfMeasure
	## ***possibly changed by options
	if ($lm->can_proceed()) {
		if ($P->skufetch($SKU,'sku:weight') ne '') {
			## convert weight to ounces
			require ZSHIP;
			my $weight = $P->skufetch($SKU,'sku:weight');
			$weight = &ZSHIP::smart_weight($weight);
			## merchants are using non-numerical weights, doesn't work
			if (($weight eq '') || ($weight <= 0)) {
				$lm->pooshmsg("WARNING|SRC:PRODUCT|SKU:$SKU|+Weight invalid [".$P->skufetch($SKU,'sku:weight').']');
				$weight = '';
				}
	
			if ($weight ne '') {
				# $prodxml->{'Product'}{'DescriptionData'}{'ShippingWeight'}->content(sprintf("%.2f", $weight));
				# $prodxml->{'Product'}{'DescriptionData'}{'ShippingWeight'}{'unitOfMeasure'} = 'OZ';
				$writer->dataElement('ShippingWeight',
					$CSV->{'weight_shipping_weight'} = sprintf("%.2f",$weight),
					'unitOfMeasure'=>$CSV->{'weight_shipping_weight_unit_of_measure'} = 'OZ');
				}
			}

		## Product->DescriptionData->MSRP
		## Product->DescriptionData->MSRP->currency
		if ($Pref{'zoovy:prod_msrp'}>0) {
			#$prodxml->{'Product'}{'DescriptionData'}{'MSRP'}{'currency'} = "USD";
			#$prodxml->{'Product'}{'DescriptionData'}{'MSRP'}->content(sprintf("%.2f",$Pref{'zoovy:prod_msrp'}));
			$writer->dataElement('MSRP',
				$CSV->{'list_price'} = sprintf("%.2f",$Pref{'zoovy:prod_msrp'}),
				'currency'=>'USD');
			}

		## added 2008-11-25
		## Product->DescriptionD->CPSIAWarning
		## 	possible warnings include the following:	
		## 	* choking_hazard_balloon
		##	 * choking_hazard_contains_a_marble
		##	 * choking_hazard_contains_small_ball
		##	 * choking_hazard_is_a_marble
		##	 * choking_hazard_is_a_small_ball
		##	 * choking_hazard_small_parts
		##	 * no_warning_applicable
		##
		## - multiple warnings (up to 4) are allowed)
		if ($Pref{'zoovy:prod_cpsiawarning'} =~ /choking_hazard_/ || $Pref{'zoovy:prod_cpsiawarning'} eq 'no_warning_applicable') {
			print STDERR "Found warning $USERNAME $SKU: ".$Pref{'zoovy:prod_cpsiawarning'}."\n";
			my @warnings = split(/(,| )/, $Pref{'zoovy:prod_cpsiawarning'});
			my $n = 1;
			foreach my $warning (@warnings) {
				next if $warning !~ /^(choking_hazard|no_warning_applicable)/;
				# $prodxml->{'Product'}{'DescriptionData'}{'CPSIAWarning'}[$n]->content($warning);
				$writer->dataElement('CPSIAWarning',$warning);
				$CSV->{sprintf('cpsia_cautionary_statement%d',$n)} = $warning;
				## only 4 warnings allowed
				last if $n++ == 4;
				}
			}
		## Product->DescriptionData->Manufacturer
		## Product->DescriptionData->MfrPartNumber
		##	Amazon requires these fields, use USERNAME/PID as necessary
		if (&AMAZON3::is_defined($Pref{'amz:prod_mfg'})) {
			# $prodxml->{'Product'}{'DescriptionData'}{'Brand'}->content(substr(ZTOOLKIT::stripUnicode($Pref{'zoovy:prod_mfg'}),0,49));
			$writer->dataElement('Brand',
				$CSV->{'brand'} = substr(ZTOOLKIT::stripUnicode($Pref{'amz:prod_mfg'}),0,49)
				);
			}
		elsif (&AMAZON3::is_defined($Pref{'zoovy:prod_mfg'}) && $Pref{'zoovy:prod_mfg'} ne ' ') {
			# $prodxml->{'Product'}{'DescriptionData'}{'Manufacturer'}->content(substr(ZTOOLKIT::stripUnicode($Pref{'zoovy:prod_mfg'}),0, 49));
			$writer->dataElement('Manufacturer',
				$CSV->{'manufacturer'} = substr(ZTOOLKIT::stripUnicode($Pref{'zoovy:prod_mfg'}),0, 49)
				);
	
			}
		else {
			# $prodxml->{'Product'}{'DescriptionData'}{'Manufacturer'}->content($USERNAME);
			$writer->dataElement('Manufacturer',$CSV->{'manufacturer'} = $USERNAME);
			}
	
		if ( &AMAZON3::is_defined($P->skufetch($SKU,'zoovy:prod_mfgid')) ) {
			# $prodxml->{'Product'}{'DescriptionData'}{'MfrPartNumber'}->content(substr(ZTOOLKIT::stripUnicode($Pref{'zoovy:prod_mfgid'}),0,39));
			$writer->dataElement('MfrPartNumber',$CSV->{'part_number'} = substr(ZTOOLKIT::stripUnicode($P->skufetch($SKU,'zoovy:prod_mfgid')),0,39)
				);
			}
		else {
			# $prodxml->{'Product'}{'DescriptionData'}{'MfrPartNumber'}->content($SKU);
			$writer->dataElement('MfrPartNumber',$CSV->{'part_number'} = $SKU);
			}
		}


	if ($lm->can_proceed()) {

		## THESAURUS sample
		#	$VAR1 = {
		#			 'TARGETAUDIENCE' => 'consumer-audience: professional-audience',
		#			 'ID' => '37',
		#			 'CREATED_GMT' => '1124830963',
		#			 'ADDITIONALATTRIBS' => '',
		#			 'USEDFOR' => 'plumbing: electrical-installation-and-maintenance: carpentry',
		#			 'OTHERITEM' => '',
		#			 'MID' => '2749',
		#			 'ITEMTYPE' => 'hand-tools',
		#			 'SUBJECTCONTENT' => '',
		#			 'PROFILE' => 'Hand Tools',
		#				'ISGIFTMESSAGEAVAILABLE' = 1,
		#				'ISGIFTWRAPAVAILABLE' = 1,
		#			};

		##
		## HANDLE ALL THE ITEM CLASSIFICATION GUIDE STUFF (aka thesaurus profiles)
		##
		## Product->DescriptionData->SearchTerms
		if (($Pref{'amz:search_terms'} ne '') || ($thesaurusinfo->{'SEARCH_TERMS'} ne '')) {
			my $search_terms = $Pref{'amz:search_terms'};
			$search_terms =~ s/[\n\r]+/,/gs;	# replace \n with ,
			$search_terms .= ','.$thesaurusinfo->{'SEARCH_TERMS'};

			## take out unicode characters
			$search_terms = &ZTOOLKIT::stripUnicode($search_terms);

			my @arr = &AMAZON3::node_split($search_terms, 4, 50, ',');
			my $i = 1; 
			foreach my $element (@arr) {
				#next if ($element eq '');
				if ($element eq '') { $element = ' '; }
				$element =~ s/,{2,}/,/g;
				$element =~ s/^,//;	# strip leading ,
				next if ($element eq '');
				# $prodxml->{'Product'}{'DescriptionData'}{'SearchTerms'}[$i]->content($element);
				$writer->dataElement('SearchTerms',$element);
				$CSV->{ sprintf("generic_keywords%d",$i)} = $element;
				$i++;
				}
			}

		## Product->DescriptionData->UsedFor
		if ($thesaurusinfo->{'USEDFOR'} ne '') {
			$thesaurusinfo->{'USEDFOR'} = lc($thesaurusinfo->{'USEDFOR'});
			my @arr = &AMAZON3::node_split($thesaurusinfo->{'USEDFOR'}, 3, 0);
			my $i = 0; 
			foreach my $element (@arr) {
				next if ($element eq '');
				# $prodxml->{'Product'}{'DescriptionData'}{'UsedFor'}[$i]->content($element);
				$writer->dataElement('UsedFor',$element);
				## TODO:CSV
				$i++;
				}
			}


		## Product->DescriptionData->ItemType
		##	APPAREL doesn't use ItemType, it uses ClothingType (in ClassificationData)
		#if ($catalog eq 'HOME') {
		#	$prodxml->{'Product'}{'DescriptionData'}{'ItemType'}->content($subcat);
		#	}
		my $lc_itemtype = '';
		if ($Pref{'amz:prod_cloth_cd_itemtype'} ne '') {
			## if the itemtype is set in the product then use that for $lc_itemtype.
			$lc_itemtype = lc($Pref{'amz:prod_cloth_cd_itemtype'});
			}
		elsif ($catalog eq 'APPAREL') {
			## apparel does NOT use an item type (ever)
			}
		elsif ($thesaurusinfo->{'ITEMTYPE'} ne '') {
			## clothing, apparel and shoe catalogs have special behaviors, anything else should have item type set in the thesaurus.
			$lc_itemtype = lc($thesaurusinfo->{'ITEMTYPE'});
			}
		else {
			## should probably have an error here rather than a warn.
			$lm->pooshmsg("WARN|+strange behavior with itemtype (not set, and not apparel)!?!");
			}
      
		if ($lc_itemtype ne '') {
			# $prodxml->{'Product'}{'DescriptionData'}{'ItemType'}->content($lc_itemtype);
			$writer->dataElement('ItemType',$lc_itemtype);
			$CSV->{'item_type'} = $lc_itemtype;	
			}
		
		## Product->DescriptionData->OtherItemAttributes
		##	this needs to changed, the sending format is incorrect
		if ($thesaurusinfo->{'OTHERITEM'} ne '') {
			$thesaurusinfo->{'OTHERITEM'} = lc($thesaurusinfo->{'OTHERITEM'});
			my @arr = &AMAZON3::node_split($thesaurusinfo->{'OTHERITEM'}, 5, 0);
			my $i = 1;
			foreach my $element (@arr) {
				next if ($element eq '');
				# $prodxml->{'Product'}{'DescriptionData'}{'OtherItemAttributes'}[$i]->content($element);
				$writer->dataElement('OtherItemAttributes',$element);
				$CSV->{sprintf('thesaurus_attribute_keywords%d',$i++)} = $element;
				}
			}
		## Product->DescriptionData->TargetAudience
		if ($thesaurusinfo->{'TARGETAUDIENCE'} ne '') {
			$thesaurusinfo->{'TARGETAUDIENCE'} = lc($thesaurusinfo->{'TARGETAUDIENCE'});
			my @arr = &AMAZON3::node_split($thesaurusinfo->{'TARGETAUDIENCE'}, 3, 0);
			my $i = 1;
			foreach my $element (@arr) {
				next if ($element eq '');
				# $prodxml->{'Product'}{'DescriptionData'}{'TargetAudience'}[$i]->content($element);
				$writer->dataElement('TargetAudience',$element);
				$CSV->{sprintf('target_audience_keywords%d',$i++)} = $element;
				}
			}
	
		## Product->DescriptionData->SubjectContent
		if ($thesaurusinfo->{'SUBJECTCONTENT'} ne '') {
			$thesaurusinfo->{'SUBJECTCONTENT'} = lc($thesaurusinfo->{'SUBJECTCONTENT'});
			my @arr = &AMAZON3::node_split($thesaurusinfo->{'SUBJECTCONTENT'}, 5, 0);
			my $i = 1;
			foreach my $element (@arr) {
				next if ($element eq '');
				# $prodxml->{'Product'}{'DescriptionData'}{'SubjectContent'}[$i]->content($element);
				$writer->dataElement('SubjectContent',$element);
				$CSV->{sprintf('thesaurus_subject_keywords%d',$i++)} = $element;
				}
			}
		## Product->DescriptionData->IsGiftWrapAvailable
		if ($thesaurusinfo->{'ISGIFTWRAPAVAILABLE'} == 1) {
			$writer->dataElement('IsGiftWrapAvailable',1);
			$CSV->{'offering_can_be_giftwrapped'} = 1;
			# $prodxml->{'Product'}{'DescriptionData'}{'IsGiftWrapAvailable'}->content(1);
			}
		## Product->DescriptionData->IsGiftMessageAvailable
		if ($thesaurusinfo->{'ISGIFTMESSAGEAVAILABLE'} == 1) {
			$writer->dataElement('IsGiftMessageAvailable',1);
			$CSV->{'offering_can_be_giftmessaged'} = 1;
			# $prodxml->{'Product'}{'DescriptionData'}{'IsGiftMessageAvailable'}->content(1);
			}
		### END of THESAURUS
		}

	$writer->endTag('DescriptionData');

	## SANITY - All attributes beyond this point are category specific and are part of the category json files
	
	##################################################################################################
	##																																##
	##										CATEGORY SPECIFIC DATA 															##
	##																																##
	##################################################################################################


	##
	## JSON FIELDS
	##		-	were going to go through all of the json fields now
	##
	my $I_HAVE_SUBCAT_VALUES = 0;
	my @XMLPATH_AND_VAL = ();	# an array of array refs, [ [ 0:xpath, 1:data-value ] ]
	foreach my $field (@{$JSONREF->{'@fields'}}) {
		next if ($field->{'xmlpath'} eq '');		# xmlpath is required!
		next if (not $lm->can_proceed());

		my @vals = ();

		##
		## TYPE VALIDATION
		## 	NOTE: do all 'type' specific validation up here.
		##

		## Type Validation - HIDDEN ATTRIBUTES
		if ($field->{'type'} eq 'hidden') {
			## any required xmlpath (ex: Home.ProductType.BedAndBath) should have a "hidden" input type because it sets subcat if all other cat specific attribs are blank 
			@vals = ((defined $field->{'value'})?$field->{'value'}:'');
			}

		## Type Validation - DEFAULT ATTRIBUTES
		##		-	some categories have mandatory attributes that also have mandatory values
		##			ie (SHOES must have a ClothingType value of 'Shoes'
		elsif ($field->{'type'} eq 'default') {
			push (@vals, $field->{'default'});
			}
		## Type Validation - VARIATION ATTRIBUTES


		##	VARIATION ORDERING
		## 	- we've moved variation data into the json file for 2 reasons.
		##			1. all attributes should eventually be in the json.
		##			2. every category requires variation data be positioned differently. some categories don't even send variations in the variation data.
		##				ie size and color are postitioned outside of variation data for AUTO:
		##
		##							<AutoAccessoryMisc>
		##								<VariationData>
		##									<Parentage>child</Parentage>
		##									<VariationTheme>Size-Color</VariationTheme>
		##								</VariationData>
		##								<Amperage unitOfMeasure="amps">12</Amperage>
		##								<ColorSpecification>
		##									<Color>blue</Color>
		##									<ColorMap>blue</ColorMap>
		##								</ColorSpecification>
		##								<Diameter unitOfMeasure="IN">12</Diameter>
		##								<Material>plastic</Material>
		##								<Size>2</Size>
		##							</AutoAccessoryMisc>
		##
		##				-	Usually variations are positioned as they are in theme (if theme is SizeColor, Size would usually come before color in the xml.
		##					As you can see above this is not always the case.
		elsif (($field->{'type'} eq 'variation') && ($theme eq '')) { # variation is an amazon field (not related to zoovy)
			## field type variation, theme is blank, as george takei would say 'oh my'
			## category requires parentage set on base products
			if (($AMZ_RELATIONSHIP->[3] ne '') && $field->{'variation-type'} eq 'parentage') {
				# base product thats requires parentage to be set
				push (@vals, $AMZ_RELATIONSHIP->[3]);
				}
			}
		elsif ($field->{'type'} eq 'variation') {	# variation is an amazon field (not related to zoovy)
			## theme has been set so this product has variations
			if ($AMZ_RELATIONSHIP->[2] eq 'none') {
				## we do not send variation details for products with a relationship of none (set for options/grouped children sent as individual products)
				}
			elsif ($field->{'variation-type'} eq 'parentage') {
				$lm->pooshmsg("DEBUG|+pushing variation-type = $AMZ_RELATIONSHIP->[3]");
				push (@vals, $AMZ_RELATIONSHIP->[3]);
				}
			elsif ($field->{'variation-type'} eq 'theme') {
				push (@vals, $theme);
				}
			elsif ($AMZ_RELATIONSHIP->[0] =~ /(^parent|vparent$)/) {
				#elsif ( $relationship eq 'parent' ) {
				## this is the variation value (ie for color = blue ) parents don't have variation values
				}
			elsif ($field->{'variation-type'} eq 'value') {
				my $vkey = $field->{'vkey'};
				if ($themes{$vkey} eq '') {
					## nothing to send.
					}
				elsif ((defined $field->{'amz-max-length'}) && (length($themes{$vkey}) > int($field->{'amz-max-length'}))) {
					## the option value length exceeds the max length set in the json.
					## we should probably do this at a higher level but we have been in the habit of just shortening values.
					##		- we probably don't want to generate errors for products that are already on amazon. 
					$lm->pooshmsg("ERROR|+The length of the option value ($themes{$vkey}) is too long on sku $SKU. The max length for this variation $vkey is $field->{'amz-max-length'}");
					} 
				elsif (length($themes{$vkey}) > 50) {
					## no options can be longer than 50 characters. this should catch any option values that are too long but don't have a max length set in teh json. 
					$lm->pooshmsg("ERROR|+The length of the option value ($themes{$vkey}) is too long on sku $SKU. An Option values's length should not exceed 50 characters");
					}
				else {
					$lm->pooshmsg("DEBUG|+pushing themes{$vkey} = $themes{$vkey}");
					push (@vals, $themes{$vkey});
					}
				}
			}

		## Type Validation - PRODUCT ATTRIBUTES

		elsif ($field->{'id'} eq '') {
			# no id, so no where to load data from! (some hidden fields have this type of wonkiness [check toysandbaby])
			}
		##
		## THIS WOULD BE A GOOD PLACE TO IMPLEMENT SKU SPECIFIC JSON LOADING
		##
		elsif (($Pref{ $field->{'id'} } eq '') || (not defined ($Pref{ $field->{'id'} })) || ($Pref{ $field->{'id'} } =~ m/^\s+$/) ) {
			## attribute is either undefined, is blank or has whitespace only.
			## 	- the regex is there to catch attributes that merchants have accidently populated with whitespace using the csv tool.
			## 	  these errors would have been caught later anyway but we can deal with it better here.

			## rules:
			## 	Some attributes are mandatory and MUST have a valid non-blank value. If they don't Amazon will return a 5000 error.
			##		A blank attribute should NEVER be sent. blank values will always return a 5000 error.

			if (not &ZOOVY::is_true($field->{'mandatory'})) {

				##
				## product attribute specified by this field is undefined or blank, but it's okay because it's also not mandatory.
				## so we can ignore it. 
				##
				## this is a short-circuit that it is used when an optional (non-mandatory) attribute has no data.
				## it means specific types (ex: textlist, select) don't have to worry about handling blank values on
				##	non-mandatory attributes.
				##
				## this will only be a problem if we ever need the ability to 'default' based on a specific type (ex: textlist)
				## **BUT** we should never really default here because we're dealing with non-mandatory attributes and as 
				## a wise man (andrew) once said: 
				##	"why would you ever default a non-mandatory field? there's no bloody good reason."
				##
				}
			else {
				## this is a madatory attribute and must have a non-blank value
				$lm->pooshmsg("ERROR|+$field->{'title'} ($field->{'id'})  is a required attribute and must not be blank. Please save a valid value in that field and the product will be resent.");
				}
			}

		## SANITY -
		## 	- If we pass this point in the if statement we have a defined non-blank attribute.

		elsif ($field->{'type'} eq 'textlist') {
			## textlist is a hardline separated list of multiple values (one per line)
			foreach my $line (split(/[\n\r]+/,$Pref{ $field->{'id'} })) {
				if ($line ne '') { 
					push @vals, $line;
					}
				else {
					# skip blank lines since they'll error later
					}
				}
			
			if ((not defined $field->{'max-allowed-lines'}) || (int($field->{'max-allowed-lines'}) == 0)) {
				## no max-allowed-lines for this field.
				}
			elsif (scalar(@vals)>$field->{'max-allowed-lines'}) {
				$lm->pooshmsg(sprintf("WARN|+Field:%s had %d lines, but only %d can be sent due to amazon formatting restrictions",$field->{'id'},scalar(@vals),$field->{'max-allowed-lines'}));
				@vals = splice(@vals,0,$field->{'max-allowed-lines'});
				}

			if (scalar(@vals)==0) {
				if (not &ZOOVY::is_true($field->{'mandatory'})) {
					## product attribute specified by this field is undefined or blank, but it's okay because it's also not mandatory.
					## so we can ignore it.
					}
				else {
					$lm->pooshmsg("ERROR|+$field->{'title'} ($field->{'id'})  is a required attribute and must not be blank. Please save a valid value in that field and the product will be resent.");
					}
				}
			}

		elsif ($field->{'type'} eq 'select') {
			## select list must have options [{v=>'',p=>''},{v=>'', p=>''}] in the data struct.

			## we better make sure we have a valid matching value.
			my $val = $Pref{ $field->{'id'} };
			my @allowed = ();
			foreach my $try (@{$field->{'options'}}) {
				push @allowed, $try->{'v'};
				if (($try->{'v'} eq $val) || ($try->{'p'} eq $val)) {
					push @vals, $val; 
					}
				}
			if (scalar(@vals)==0) {
				## not found
				$lm->pooshmsg("ERROR|+$field->{'xmlpath'} $field->{'id'} value:$val is invalid, must be one of (".join(",",@allowed).")");
				}
			}

		elsif ($Pref{ $field->{'id'} } ne '') {
			## standard attribute with a non blank value, yay!
			push @vals, $Pref{ $field->{'id'} };
			}

		else {
			## this line should never be reached
			}

		if ((scalar(@vals)>0) && (index( $field->{'xmlpath'}, sprintf(".%s.",$JSONREF->{'xmlsubcat'}) )>0)) {
			## look for .BedAndBath. inside of Home.ProductType.BedAndBath.VolumeCapacity
			$I_HAVE_SUBCAT_VALUES++;
			}

		my $pos=0;	## data position

		##print '@vals: '.Dumper($field, \@vals);

		foreach my $v (@vals) {
			push @XMLPATH_AND_VAL, [ $pos++, $field, $v ];

			}
		}

	## SANITY: at this point we are guaranteed to be looking at a message, which has one or more values
	## xmlpath = Jewelry.ProductType.FashionEarring.Material

	## set $color_val for ColorSpecification format
	my $color_val = '';

	##
	## VALIDATE & FORMAT XML 
	## 	now we'll actually go through and format the xml based on @XMLPATH_AND_VAL
	##		if we get an "ERROR" (ex. non-correctable validation problems)
	##		
	my $prodxml = XML::Smart->new();
	$writer->startTag('ProductData');
	foreach my $dataset (@XMLPATH_AND_VAL) {
		next if (not $lm->can_proceed());
		my ($pos,$field,$val) = @{$dataset};
		## remove any bad data the user might have given us.
		$val = &ZTOOLKIT::htmlstrip($val,2);

		if (($val ne '') && ($field->{'amzcsv'})) {
			$CSV->{ $field->{'amzcsv'} } = $val;
			}

		# my $pathxml = $prodxml->{'Product'}{'ProductData'};
		my $pathxml = $prodxml;
		## xmlpath is set in Json ex: "xmlpath" : "Home.ProductType.BedAndBath.VolumeCapacity"
		foreach my $branch (split(/\./, $field->{'xmlpath'})) { $pathxml = $pathxml->{$branch}; }
		$pathxml = $pathxml->[$pos];

		my @arr = split(/\./, $field->{'xmlpath'});
		my $node = pop(@arr);
		my $subnode = pop(@arr);
		## SANITY:
		##		$subcat is "bagcase" if catalog is camera.bagcase
		##		$catalog is "camera" if catalog is camera.bagcase
		##		$node is "d" if xmlpath is a.b.c.d
		##		$subnode is "c" if xmlpath is a.b.c.d
	
		my $n = '';

		if ( ($val eq '') && ($field->{'type'} ne 'hidden') && (not &ZOOVY::is_true( $field->{'amz-allow-blank'})) ) {
			## THIS LINE SHOULD NEVER BE REACHED - it's simply an added check in case a blank value gets through.

			## $val will always be '' for 'hidden' input (id: CRC****) but thats fine because it's not a product attribute.
			##	this input type sets subcat if all other cat specific attribs are blank and therefore this type exists in every json
			##	we could have simply used 'if $field->{'type'} ne 'hidden' but for future flexibilty we're adding $field->{'amz-allow-blank'}.

			## not all CRC**** input types have 'amz-allow-blank' set yet so we keeping 'if ($field->{'type'} ne 'hidden')' until all jsons have been updated     
			$lm->pooshmsg("ERROR|+$field->{'xmlpath'} json:$field->{'id'} may never have a blank value.");
			}
	
		## we need to work on this but for now we aren't sending is recalled
		## dont send IsRecalled or RecallDescription if IsRecalled == 0
		#my $IsRecalled = 0;
		#if ($node eq 'IsRecalled') { 
		#	## special stupid shit i don't feel like fixin right now.
		#	if ($val eq "on") { $val = 1; }
		#	if ($val eq '') { $val = 0; }
		#	if ($val>0) {
		#		$IsRecalled = 1; 
		#		$prodxml->{'Recall'}{$node}[$n]->content(1);
		#		}
		#	}
		#elsif ($node eq 'RecallDescription') {
			## Recall node
		#	if ($IsRecalled) {
		#		$prodxml->{'Recall'}{$node}[$n]->content();
		#		}
		#	}


		## HINTS
		##		- Hints can be used when a json attribute fails validation.
		##			- hints should be used to give a hint to a merchant that is specific to that format or attribute.
		##			- they will be used primarily to give fomatting instruction but can also be used at attribute level to give other configuration advise.
		##			  - eg. the hint for format 'Volume' (which uses # ounce) should be different to that of format 'Length' (which can use either # cm or #.## cm.) 
		##			  - hints can be set at json level to give advise specific to that attribute.
		##
		my $hint = '';
		
		if (($field->{'type'} eq 'select') && ($field->{'amz-format'} ne 'ColorSpecification')) {
			## if a select type attribute makes it this far it already has a valid value. select attributes are fully validated earlier in 'type validation'.
			## 	Exception: ColorSpecification values are not always used - See below for details
			$pathxml->content($val);
			}
		
		## COLOR SPECIFICATION
		##		-	only auto, music and office use ColorSpecification format
		##		-	ColorMap can only be set to certain values (ie. 'black') but the Color Variation value does not have such limitations (ie could be 'blackish').
		##		-	variation color should always come before color map in the json because the ColorMap attrib should be ignored if we have variation color.
		##			(ColorMap is not currently variation specific so it shouldn't be used for the option if we have a variation color. This may change if we make it option specific.
		##			 because we can't set ColorMap at SKU level it serves no purpose other that to get the product passed Amazon's validation) 
		##		RULES
		##			-	if either color or colormap are set, a value for both needs to be added to xml

		##		We send ColorMap for the parent of a color variation. This doesn't cause any problems but it's not correct either so we should change. 
		elsif ($field->{'amz-format'} eq 'ColorSpecification') {
			## color/color variation attributes
			#		set color and colormap values
			if ($field->{'title'} ne 'Color Map') {
				## either color or variation color has been set - we now don't care if ColorMap is set in the product because ColorMap is not variation specific in Zoovy
				## 	- if this is also an allowed ColorMap value lets set Color Map to that - Otherwise we'll use the default ColorMap value for this category
				## 
				$color_val = $val;
				my $map_val = '';
				my @allowed = ();
				foreach my $field (@{$JSONREF->{'@fields'}}) {
					if ($field->{'title'} eq 'Color Map') {
						if ($field->{'type'} eq 'select') {
							# ColorMap has a select list of valid values  
							foreach my $try (@{$field->{'options'}}) {
								push @allowed, $try->{'v'};
								if (($try->{'v'} eq $color_val) || ($try->{'p'} eq $color_val)) {
									$map_val = $color_val; 
									}
								}
							if ($map_val eq '') {
								# our color value is not in our list of valid ColorMap values
								if ($field->{'default-color'} eq ''){
									# if default color is not set default is MultiColored
									$map_val = 'MultiColored';
									}
								else {
									# we have a default color so lets use it
									$map_val = $field->{'default-color'};
									}
								}
							}
						else {
							# there are no specified values for colormap in this category so we should use the color/variation color value for ColorMap.
							$map_val = $color_val; 
							}
						} 
					}
				if ($map_val eq '') {
					# this could only be reached if ColorMap does not exist in the json but better to be safe than sorry since that 
					# pommy **** probably can't be trusted to keep the json files up to date  
					$map_val = $color_val;
					}
				$pathxml->{'Color'}->content(lc($color_val));
				$pathxml->{'ColorMap'}->content($map_val);
				}
			elsif (($theme =~ /color/i) && ($AMZ_RELATIONSHIP->[2] eq 'child')) {
				## color variation
				#		nothing to do here. we're only here so that we don't overwrite colormap for color variations
				} 
			else {
				## colormap
				if ($color_val eq '') {
					$pathxml->{'Color'}->content(lc($val));
					}
				$pathxml->{'ColorMap'}->content(lc($val));
				}
			}
		elsif ($field->{'amz-format'} eq 'ComputerPlatform') {
			$pathxml->{'Type'}->content($val);
			$pathxml->{'SystemRequirements'}->content($Pref{'amz:prod_base_systemreqs'});
			}
		elsif ($field->{'amz-format'} eq 'Unit') {
			$val =~ m/(\d+)(.*)/;
			$val = $1;
			$pathxml->content($val);
			## example of unitofmeasure: pixels,
			$pathxml->{'unitOfMeasure'} = $field->{'amz-units'};
			}
		elsif ($field->{'amz-format'} eq 'Text') {
			$val =~ s/[\n\r]+$//gs;	# remove trailing hard returns
			if ($val eq "on") { $val = 1; }
			if (defined $field->{'amz-max-length'}) {	 $val = substr($val,0,$field->{'amz-max-length'}); }
			if (defined $field->{'amz-min-length'}) {	 
				if (length($val) < int($field->{'amz-min-length'})) {
					$lm->pooshmsg("ERROR|+$field->{'xmlpath'} value:$val must be $field->{'amz-min-length'} characters in length.");
					}
				}
			$pathxml->content($val);
			}
		elsif ($field->{'amz-format'} eq 'Verbatim') {
			$pathxml->content($val);
			}
		elsif ($field->{'amz-format'} eq 'Scalar') {
			$val =~ s/[\n\r]+$//gs;	# remove trailing hard returns
			if ($val eq "on") { $val = 1; }
			$pathxml->content($val);
			}
		elsif ($field->{'amz-format'} eq 'Boolean') {
			# $prodxml->{$subcat}{$node}[$n]->content( &ZOOVY::is_true($val)?1:0 );
			$pathxml->content( &ZOOVY::is_true($val)?1:0 );
			}
		elsif (($field->{'amz-format'} eq 'Length') || ($field->{'amz-format'} eq 'Volume')
				|| ($field->{'amz-format'} eq 'Age') || ($field->{'amz-format'} eq 'Weight') 
				|| ($field->{'amz-format'} eq 'Memory')|| ($field->{'amz-format'} eq 'Time')) {

			## This code is intended to handle any format that has a UnitOfMeasure.

			## Formatting rules:
			## 	- the allowed uom (units of measure) differ for each attribute even if they are the same amz-format.
			##			eg. Home.DisplayLength allows:MM, CM, M, IN, FT but Home.BladeLength (yet to be added) only allows CM and IN.
			##		- certain uom exist is 2 amz-formats but have a different fomatting.
			##			eg. in 'volume' ounce is written 'ounce' but in 'Weight' it is written as 'OZ'
			##			- due to this we have to add an extra check alongside the regex for 'Volume' and 'Weight' so we know what value to send.
			my ($unitOfMeasure) = '';

			## if 'amz-length-uom' or is not set for any given attribute we will use the default value for that format. 
			my @ALLOWED_UNITS_OF_MEASURE = ();
			if ($field->{'amz-format'} eq 'Length') {
				## valid amazon values and default format uom:  MM, CM, M, IN, FT
				@ALLOWED_UNITS_OF_MEASURE = ('MM','CM','M','IN','FT');
				if ($field->{'amz-uom'} ne '') {
					#use json specific uom for attribute 
					@ALLOWED_UNITS_OF_MEASURE = split(/,/,$field->{'amz-uom'});
					}
				$hint = "value entered ($val) for '$field->{'title'}($field->{'id'})', is invalid. Please use a number with up to 2 decimal places".
							"(eg. 1 or 1.23 ) followed one of:".join(',',@ALLOWED_UNITS_OF_MEASURE);
				}
			elsif ($field->{'amz-format'} eq 'Volume') {
				## valid amazon values and default format uom: cubic-cm, cubic-ft, cubic-in, cubic-m, cubic-yd, cup, gallon, liter, ounce, pint, quart
				@ALLOWED_UNITS_OF_MEASURE = ('cubic-cm','cubic-ft','cubic-in','cubic-m','cubic-yd','cup','gallon','liter','ounce','pint','quart');
				if ($field->{'amz-uom'} ne '') {
					#use json specific uom for attribute 
					@ALLOWED_UNITS_OF_MEASURE = split(/,/,$field->{'amz-uom'});
					}
				$hint = "value entered ($val) for '$field->{'title'}($field->{'id'})', is invalid. Please use a whole number".
							"(eg. 1) followed one of:".join(',',@ALLOWED_UNITS_OF_MEASURE);
				}
			elsif ($field->{'amz-format'} eq 'Age') {
				## valid amazon values and default format uom:  years, months
				@ALLOWED_UNITS_OF_MEASURE = ('years','months');
				if ($field->{'amz-uom'} ne '') {
					#use json specific uom for attribute 
					@ALLOWED_UNITS_OF_MEASURE = split(/,/,$field->{'amz-uom'});
					}
				$hint = "value entered ($val) for '$field->{'title'}($field->{'id'})', is invalid. Please use a whole number".
							"(eg. 1) followed one of:".join(',',@ALLOWED_UNITS_OF_MEASURE);
				}
			elsif ($field->{'amz-format'} eq 'Time') {
				## valid amazon values and default format uom:  sec, min, hr
				@ALLOWED_UNITS_OF_MEASURE = ('sec','min','hr');
				if ($field->{'amz-uom'} ne '') {
					#use json specific uom for attribute 
					@ALLOWED_UNITS_OF_MEASURE = split(/,/,$field->{'amz-uom'});
					print Dumper(@ALLOWED_UNITS_OF_MEASURE);
					}
				$hint = "value entered ($val) for '$field->{'title'}($field->{'id'})', is invalid. Please use a whole number".
							"(eg. 1) followed one of:".join(',',@ALLOWED_UNITS_OF_MEASURE);
				}
			elsif ($field->{'amz-format'} eq 'Weight') {
				## valid amazon values and default format uom:  GR, KG, OZ, LB
				@ALLOWED_UNITS_OF_MEASURE = ('GR','KG','OZ','LB');
				if ($field->{'amz-uom'} ne '') {
					#use json specific uom for attribute 
					@ALLOWED_UNITS_OF_MEASURE = split(/,/,$field->{'amz-uom'});
					print Dumper(@ALLOWED_UNITS_OF_MEASURE);
					}
				$hint = "value entered ($val) for '$field->{'title'}($field->{'id'})', is invalid. Please use a number with up to 2 decimal places".
							"(eg. 1 or 1.23 ) followed one of:".join(',',@ALLOWED_UNITS_OF_MEASURE);
				}
			elsif ($field->{'amz-format'} eq 'Memory') {
				## valid amazon values and default format uom:  GR, KG, OZ, LB
				@ALLOWED_UNITS_OF_MEASURE = ('TB','GB','MB','KB');
				if ($field->{'amz-uom'} ne '') {
					#use json specific uom for attribute 
					@ALLOWED_UNITS_OF_MEASURE = split(/,/,$field->{'amz-uom'});
					print Dumper(@ALLOWED_UNITS_OF_MEASURE);
					}
				$hint = "value entered ($val) for '$field->{'title'}($field->{'id'})', is invalid. Please use a number with up to 2 decimal places".
							"(eg. 1 or 1.23 ) followed one of:".join(',',@ALLOWED_UNITS_OF_MEASURE);
				}
			else {
				## THIS LINE SHOULD NEVER BE REACHED
				$lm->pooshmsg("ERROR|+Internal Json issue with amz-format: $field->{'amz-format'}");
				}


			if ($val eq '') {
				## NOTE: this should *never* happen
				$lm->pooshmsg("ERROR|+Measurements require a valid value");
				}
			elsif (($field->{'amz-format'} eq 'Volume') && 
					($val =~ m/^(\d+)[ \|\-]?(cubic-cm|cubic-ft|cubic-in|cubic-m|cubic-yd|cup|cups|c|gallon|gallons|gal|liter|liters|l|ounce|ounces|fl oz|oz|pint|pints|pt|guart|quarts|qt)$/i)) {
				## amz-format: Volume 
				($val,$unitOfMeasure) = ($1,$2);
				$unitOfMeasure = lc($unitOfMeasure); #merchants enter the units of measurement in a variety of cases (eg PINT,Pint and pint) 

				if ($unitOfMeasure eq 'cups') {$unitOfMeasure = "cup"; } 
				elsif ($unitOfMeasure eq 'c') {$unitOfMeasure = "cup"; }
				elsif ($unitOfMeasure eq 'gallons') {$unitOfMeasure = "gallon"; }
				elsif ($unitOfMeasure eq 'gal') {$unitOfMeasure = "gallon";}
				elsif ($unitOfMeasure eq 'liters') {$unitOfMeasure = "liter";}
				elsif ($unitOfMeasure eq 'l') { $unitOfMeasure = "liter"; }						
				elsif ($unitOfMeasure eq 'ounces') { $unitOfMeasure = "ounce"; }						
				elsif ($unitOfMeasure eq 'fl oz') { $unitOfMeasure = "ounce"; }
				elsif ($unitOfMeasure eq 'oz') { $unitOfMeasure = "ounce"; }
				elsif ($unitOfMeasure eq 'pints') { $unitOfMeasure = "pint"; }
				elsif ($unitOfMeasure eq 'pt') { $unitOfMeasure = "pint"; }
				elsif ($unitOfMeasure eq 'quarts') { $unitOfMeasure = "quart"; }
				elsif ($unitOfMeasure eq 'qt') { $unitOfMeasure = "quart"; }
				}
			elsif (($field->{'amz-format'} eq 'Length') &&
					($val =~ m/^(\d+\.?\d*)[ \|\-]?(mm|millimeter|millimeters|CM|centimeters|centimeter|M|meters|meter|\"|IN|inch|inches|\'|FT|foot|feet)$/i)) {
				## amz-format: Length
				($val,$unitOfMeasure) = ($1,$2);
				$unitOfMeasure = uc($unitOfMeasure); #merchants enter the units of measurement in a variety of cases (eg INCH,Inch and inch) 

				if ($unitOfMeasure eq 'MILLIMETER') { $unitOfMeasure = "MM"; }
				elsif ($unitOfMeasure eq 'MILLIMETERS') { $unitOfMeasure = "MM"; }						
				elsif ($unitOfMeasure eq 'CENTIMETER') { $unitOfMeasure = "CM"; }						
				elsif ($unitOfMeasure eq 'CENTIMETERS') { $unitOfMeasure = "CM"; }						
				elsif ($unitOfMeasure eq 'METERS') { $unitOfMeasure = "M"; }						
				elsif ($unitOfMeasure eq 'METER') { $unitOfMeasure = "M"; }						
				elsif ($unitOfMeasure eq "\"") {$unitOfMeasure = "IN"; } 
				elsif ($unitOfMeasure eq 'INCH') {$unitOfMeasure = "IN"; }
				elsif ($unitOfMeasure eq 'INCHES') {$unitOfMeasure = "IN"; }
				elsif ($unitOfMeasure eq "\'") {$unitOfMeasure = "FT";}
				elsif ($unitOfMeasure eq 'FOOT') {$unitOfMeasure = "FT";}
				elsif ($unitOfMeasure eq 'FEET') {$unitOfMeasure = "FT";}
				}
			elsif (($field->{'amz-format'} eq 'Weight')&& 
					($val =~ m/^(\d+\.?\d*)[ \|\-]?(G|GR|grams|gram|KG|kilograms|kilogram|OZ|ounce|ounces|LB|LBS|pound|pounds)$/i)) {
				## amz-format: Weight
				($val,$unitOfMeasure) = ($1,$2);
				$unitOfMeasure = uc($unitOfMeasure); #merchants enter the units of measurement in a variety of cases (GRAM, Gram and gram) 

				if ($unitOfMeasure eq 'G') {$unitOfMeasure = "GR"; } 
				elsif ($unitOfMeasure eq 'GRAM') { $unitOfMeasure = "GR"; }						
				elsif ($unitOfMeasure eq 'GRAMS') { $unitOfMeasure = "GR"; }						
				elsif ($unitOfMeasure eq 'KILOGRAMS') { $unitOfMeasure = "KG"; }						
				elsif ($unitOfMeasure eq 'KILOGRAM') { $unitOfMeasure = "KG"; }
				elsif ($unitOfMeasure eq 'OUNCE') {$unitOfMeasure = "OZ"; }
				elsif ($unitOfMeasure eq 'OUNCES') {$unitOfMeasure = "OZ"; }
				elsif ($unitOfMeasure eq 'LBS') {$unitOfMeasure = "LB";}
				elsif ($unitOfMeasure eq 'POUND') {$unitOfMeasure = "LB";}
				elsif ($unitOfMeasure eq 'POUNDS') {$unitOfMeasure = "LB";}
				}
			elsif (($field->{'amz-format'} eq 'Age') &&
					($val =~ m/^(\d+)[ \|\-]?(yrs|yr|years|year|months|month)$/i)) {
				## amz-format: Age
				($val,$unitOfMeasure) = ($1,$2);
				$unitOfMeasure = lc($unitOfMeasure); #merchants enter the units of measurement in a variety of cases (eg YEARS, Years and years) 

				if ($unitOfMeasure eq 'yr') { $unitOfMeasure = 'years'; }
				if ($unitOfMeasure eq 'yrs') { $unitOfMeasure = 'years'; }
				if ($unitOfMeasure eq 'year') { $unitOfMeasure = 'years'; }
				if ($unitOfMeasure eq 'month') { $unitOfMeasure = 'months'; }
				}
			elsif (($field->{'amz-format'} eq 'Time') && 
					($val =~ m/^(\d+)[ \|\-]?(sec|secs|second|seconds|min|mins|minute|minutes|hr|hrs|hour|hours)$/i)) {
				## amz-format: Time
				($val,$unitOfMeasure) = ($1,$2);
				$unitOfMeasure = lc($unitOfMeasure); #merchants enter the units of measurement in a variety of cases (eg YEARS, Years and years) 

				if ($unitOfMeasure eq 'secs') { $unitOfMeasure = 'sec'; }
				if ($unitOfMeasure eq 'second') { $unitOfMeasure = 'sec'; }
				if ($unitOfMeasure eq 'seconds') { $unitOfMeasure = 'sec'; }
				if ($unitOfMeasure eq 'mins') { $unitOfMeasure = 'min'; }
				if ($unitOfMeasure eq 'minute') { $unitOfMeasure = 'min'; }
				if ($unitOfMeasure eq 'minutes') { $unitOfMeasure = 'min'; }
				if ($unitOfMeasure eq 'hrs') { $unitOfMeasure = 'hr'; }
				if ($unitOfMeasure eq 'hour') { $unitOfMeasure = 'hr'; }
				if ($unitOfMeasure eq 'hours') { $unitOfMeasure = 'hr'; }
				}
			elsif (($field->{'amz-format'} eq 'Memory') &&
					($val =~ m/^(\d+\.?\d*)[ \|\-]?(KB|kilobyte|kilobytes|MB|megs|megabyte|megabytes|GB|gigs|gigabyte|gigabytes|TB|terabyte|terabytes)$/i)) {
				## amz-format: Memory
				($val,$unitOfMeasure) = ($1,$2);
				$unitOfMeasure = uc($unitOfMeasure); #merchants enter the units of measurement in a variety of cases (eg YEARS, Years and years) 

				if ($unitOfMeasure eq 'KILOBYTE') { $unitOfMeasure = 'KB'; }
				if ($unitOfMeasure eq 'KILOBYTES') { $unitOfMeasure = 'KB'; }
				if ($unitOfMeasure eq 'MEGS') { $unitOfMeasure = 'MB'; }
				if ($unitOfMeasure eq 'MEGABYTE') { $unitOfMeasure = 'MB'; }
				if ($unitOfMeasure eq 'MEGABYTES') { $unitOfMeasure = 'MB'; }
				if ($unitOfMeasure eq 'GIGS') { $unitOfMeasure = 'GB'; }
				if ($unitOfMeasure eq 'GIGABYTE') { $unitOfMeasure = 'GB'; }
				if ($unitOfMeasure eq 'GIGABYTES') { $unitOfMeasure = 'GB'; }
				if ($unitOfMeasure eq 'TERABYTE') { $unitOfMeasure = 'TB'; }
				if ($unitOfMeasure eq 'TERABYTES') { $unitOfMeasure = 'TB'; }
				}
			else {
				if ($field->{'hint'} ne '') {
					$hint .= $field->{'hint'};
					}
				$lm->pooshmsg("ERROR|+".$hint);
				}
			
			## SANITY: AT THIS POINT either $val & $unitOfMeasure are set, or we've got an error
			if (not $lm->can_proceed()) {
				}
			elsif (scalar(@ALLOWED_UNITS_OF_MEASURE)>0) {
				## this should always be fine.
				my $uom_is_fine = 0;
				foreach my $allowed_uom (@ALLOWED_UNITS_OF_MEASURE) {
					if ($allowed_uom eq $unitOfMeasure) { $uom_is_fine++; }
					}
				if (not $uom_is_fine) {
					$lm->pooshmsg("ERROR|+WARN|Prohibited UnitOfMeasure ($unitOfMeasure) used on attribute '$field->{'title'}($field->{'id'})' - allowed types: ".join(",",@ALLOWED_UNITS_OF_MEASURE));
					}
				}

			if (not $lm->can_proceed()) {
				}
			elsif (($val ne '') && ($unitOfMeasure ne '')) {
				## VALID VALUE
				$pathxml->content($val);
				$pathxml->{'unitOfMeasure'} = $unitOfMeasure;
				}
			else {
   			}
			}
		elsif ($field->{'amz-format'} eq 'Number') {
			if ($val =~ m/^\d+$/) {
				## alow whole numbers only 
				$pathxml->content($val);
				}
			else {
				$lm->pooshmsg("ERROR|+Prohibited value ($val) used for attribute '$field->{'title'}($field->{'id'})'. Value must be a whole number only");
				}
			}
		elsif ($field->{'amz-format'} eq 'WirelessType') {
			## Although wireless type is part of CE in the XSD, the validation for wireless type values are inexplicably taken from the Computer Inventory File Template.
			##		- amazon are currently making changes to wireless frequencies so when that has been completed we need to take another look at how we deal with these attributes.
			##		- this should at least stop 5000 errors from being returned on these attributes and enable us to notify the merchant of the values that should be used. 
			if ($val =~ m/^(802_11_AB|802_11_G|dect_6.0|irda|radio_frequency|5.8_ghz_radio_frequency|802_11_B|dect|900_mhz_radio_frequency|802_11_AG|802_11_N|802_11_BGN|Bluetooth|2.4_ghz_radio_frequency|802_11_ABG|infrared|802_11_G_108Mbps|802_11_A)$/) {
				$pathxml->content($val);
				}
			else {
				$lm->pooshmsg("ERROR|+Invalid Wireless Type:$val (try one of the following: 802_11_AB|802_11_G|dect_6.0|irda|radio_frequency|5.8_ghz_radio_frequency|802_11_B|dect|900_mhz_radio_frequency|802_11_AG|802_11_N|802_11_BGN|Bluetooth|2.4_ghz_radio_frequency|802_11_ABG|infrared|802_11_G_108Mbps|802_11_A)");
   			}
			}
		elsif ($field->{'amz-format'} eq 'Recall') {
			# $prodxml->{'Recall'}{$node}[$n]->content($val);
			$pathxml->content($val);
			}
		elsif ($field->{'amz-format'} eq 'Players') {
			## this node should be a number, not a range
			## grab the maximum number if a range is given (2-6 => 6)
			# ($node =~ /NumberOfPlayers/ && $val =~ /\-/) {				
			#$val =~ s/ //g;
			#$val =~ m/(\d+)\-(\d+)/;
			#$val = $2; 
			#$pathxml->content($val);
			if ($val =~ /\-/) {
				$val =~ s/ //g;
				$val =~ m/(\d+)\-(\d+)/;
				$val = $2; 
				$pathxml->content($val);
				}
			elsif ($val =~ /\d+/) {
				$pathxml->content($val);
				}
			else { 
				## don't add it
				}
			}
		elsif ($field->{'amz-format'} eq 'WeightRecommended') {
			## TOYSANDBABY
			## Pretty sure this didn't port over nicely from legacy (but also didnt' seem to work on prod before either)
			if ($val =~ /(\d+)-\d+(.*)/) { $val = $1;	}
			else {
				$val =~ m/(\d+)(.*)/;
				$val = $1;
				} 
			
			my $unitOfMeasure = uc($2);
			if ($unitOfMeasure eq '' || $unitOfMeasure eq ' ') { $unitOfMeasure = 'LB'; }
			#$prodxml->{'WeightRecommendation'}{$node}[$n]->content($val);
			#$prodxml->{'WeightRecommendation'}{$node}[$n]{'unitOfMeasure'} = $unitOfMeasure;
			$pathxml->content($val);
			$pathxml->{'unitOfMeasure'} = $unitOfMeasure;
			}
		elsif ($field->{'amz-format'} eq 'FrequencyDimension') {
			## ProcessorSpeed
			my ($unitOfMeasure) = ('');
			if ($val eq '') {
				$lm->pooshmsg("ERROR|+attrib:$field->{'id'} FrequencyDimension must be specified");
				}
			elsif ($val =~ /^([\d\.]+)[ \|\-]?(MHz|GHz)$/) {
				## 1.2 GHz
				($val,$unitOfMeasure) = ($1,$2);
				}
			else {
				# A number with up to 10 digits to the left of the decimal point and 2 digits to the right of the decimal point. Please do not use commas. 
				# [5:52:01 PM] Andrew Todd: Accepted units of measure are MHz, GHz.
				$lm->pooshmsg("ERROR|+attrib:$field->{'id'} Invalid format. why not try: ##.##### GHz|MHz");
				}

			$pathxml->content($val);
			$pathxml->{'unitOfMeasure'} = lc($unitOfMeasure);
			}
		elsif (($field->{'amz-format'} eq '') && ($field->{'type'} eq 'hidden')) {
			## hidden types don't actually require a special amz-format routine.
			$pathxml->content($val);
			}
		else {
			warn "!!!!! Unknown or unset amz-format: $field->{'amz-format'} for xmlpath: $field->{'xmlpath'} id:$field->{'id'} val:$val **** THIS IS MOST LIKELY A JSON ERROR -- BUT I DO NOT KNOW WHAT TO DO SO THIS WILL NOT BE INCLUDED ***\n";
			}
		}			
	$writer->raw($prodxml->data(nometagen=>1,noheader=>1));
	$prodxml = undef;
	$writer->endTag('ProductData');
		
	## Addition of private label
	## needs to done more elegantly

	my $CONTENTSAR = $options{'@CONTENTS'};
	if (not defined $CONTENTSAR) { $CONTENTSAR = []; }
	if ($lm->can_proceed()) {
		if (not defined $userref->{'*SO'}) {
			warn "cannot ascertain private_label status due to missing *SO object (okay if debug)\n";
			}
		elsif (int($userref->{'*SO'}->get('.private_label'))>0) {
		#if ($userref->{'PRIVATE_LABEL'} == 1) {
			# $prodxml = $prodxml->base();
			# $prodxml->{'Message'}{'Product'}{'RegisteredParameter'}->content('PrivateLabel');
			$writer->dataElement('RegisteredParameter','PrivateLabel');
			## TODO:CSV
			}

		# my ($xml) = $prodxml->data(nometagen=>1,noheader=>1);

		$writer->endTag('Product');
		$writer->endTag("Message");
		$writer->end();

		push @{$CONTENTSAR}, [ $MSGID, $SKU ];
		push @{$xmlar}, $xml;
		$lm->pooshmsg(sprintf("SUCCESS|MSGID:$MSGID|+appended product to feed",$SKU));
		}

	## QUICK AND DIRTY HACK FOR AMZCSV PROOF OF CONCEPT
	if (defined $options{'%AMZCSV'}) {
		## NOTE: if we're in %AMZCSV mode, this is a list of special csv logic.
		$CSV->{'parent_child'} = $AMZ_RELATIONSHIP->[3];
		if ($AMZ_RELATIONSHIP->[0] eq 'child') {
			$CSV->{'parent_sku'} = $AMZ_RELATIONSHIP->[1];
			$CSV->{'relationship_type'} = 'Variation';
			}
		## we could return something unique settings here (but I can't imagine why)
		}


	return($lm,$xmlar,$CONTENTSAR);
	}	






##
## this is the master list of variation options and which categories they are valid for
##		-	this list shows all variations allowed for each category.
##			keep in mind that certain subcategories only allow a selection of the variations that the parent category allow.
##			-	check the json files for a list of variations allowed for each subcategory. 
##	the spaces are here thanks to sloppy programming by patti. at some point in the future we'll want to remove those.
##	this is most likely only called from the option editor.
##
sub get_amz_options {
	my @options = (
		"APPAREL: Size",
		"APPAREL: Color",
		"AUTO: Size",
		"AUTO: Color",
		"CAMERA: None",
		"CE: None",
		"EYEWEAR: Color",
		"EYEWEAR: Size",
		"EYEWEAR: ColorName",
		"EYEWEAR: LensColor",
		"EYEWEAR: MagnificationStrength",
		"EYEWEAR: LensWidth",
		"FOOD: Size",
		"FOOD: Flavor",
		"HANDBAG: Color",
		"HEALTH: Size",
		"HEALTH: Color",
		"HEALTH: Count",
		"HEALTH: Flavor",
		"HOME: Color",
		"HOME: ItemPackageQuantity",
		"HOME: Material",
		"HOME: Scent",
		"HOME: Size",
		"JEWELRY: Length",
		"JEWELRY: MetalType",
		"JEWELRY: RingSize",
		"JEWELRY: SizePerPearl",
		"JEWELRY: TotalDiamondWeight",
		"OFFICE: None",
		"MUSIC: Color",
		"SHOEACCESSORY: Size",
		"SHOEACCESSORY: Color",
		"SHOES: Size",
		"SHOES: Color",
		"SOFTWARE: None",
#		"SPORTS: AgeGenderCategory",
#		"SPORTS: Amperage",
#		"SPORTS: BikeRimSize",
#		"SPORTS: BootSize",
#		"SPORTS: CalfSize",
#		"SPORTS: Caliber",
#		"SPORTS: Capacity",
		"SPORTS: Color",
#		"SPORTS: Curvature",
#		"SPORTS: Design",
#		"SPORTS: Diameter",
#		"SPORTS: DivingHoodThickness",
#		"SPORTS: Flavor",
		"SPORTS: GolfFlex",
		"SPORTS: GolfLoft",
		"SPORTS: GripSize",
		"SPORTS: GripType",
		"SPORTS: Hand",
#		"SPORTS: HeadSize",
#		"SPORTS: Height",
#		"SPORTS: ItemThickness",
		"SPORTS: Length",
		"SPORTS: LensColor",
#		"SPORTS: LineCapacity",
#		"SPORTS: LineWeight",
#		"SPORTS: Material",
#		"SPORTS: Quantity",
#		"SPORTS: Rounds",
		"SPORTS: ShaftMaterial",
		"SPORTS: ShaftType",
#		"SPORTS: Shape",
		"SPORTS: Size",
		"SPORTS: Style",
#		"SPORTS: TemperatureRating",
		"SPORTS: TensionLevel",
		"SPORTS: Weight",
		"SPORTS: WeightSupported",
#		"SPORTS: WheelSize",
		"SPORTS: Width",
		"TOOLS: None",
#		"TOYS: Color",
#		"TOYS: Edition",
#		"TOYS: Size",
#		"TOYS: Style",
		"TOYSBABY: None",
		"WIRELESS: None"
		);
	return(@options);
	}




##
## NOTE: it appears this occasionaly isn't set.
##


## IF THIS IS MODIFIED -- WE MUST INFORM THE CLIENT(s) and VERSION
%AMAZON3::BW = (
	## PUSHVAL lookup table:
   'all'=>2+4+8+16+32+64,	# 2+4+8+16+32+64	 (NOT INIT)

	'init'=>1,
	'init_mask'=>~1,
   'products'=>2,
	'products_mask'=>~2,
   'prices'=>4,
	'prices_mask'=>~4,
   'images'=>8,
	'images_mask'=>~8,
   'inventory'=>16,
   'inventory_mask'=>~16,
   'relations'=>32,
   'relations_mask'=>~32,
   'shipping'=>64,
   'shipping_mask'=>~64,

   'docs'=>128,

	'not_needed'=>1<<10,	## this product has been flagged as 'not needed' - it will never be transmitted. (ex: vcontainer)

	#'parentage'=>1<<14,	## this bit is used during a product syndication to see if options changed. 
	#							## we'll turn on parentage all mapped grp_children, and inventoriable options to this 
	#							## PRIOR to syndication (anything where parent=PID)
	#							## then run the syndication, and turn it OFF on the products that we sent up.
	#							## anything left with parentage ON, has changed/is no longer valid and should be removed.
	'blocked'=>1<<14,	## used for high level product actions (ex: error)
	'deleted'=>1<<15,
	);


##
## based on an input bitwise value (ex: FEEDS_TODO) formats a pretty
##		user readable version of which feeds are flipped on.
##
sub describe_bw {
	my ($val) = @_;

	my @out = ();
	if (($val & 1<<0)>0) { push @out, "init"; }
	if (($val & 1<<1)>0) { push @out, "products"; }
	if (($val & 1<<2)>0) { push @out, "prices"; }
	if (($val & 1<<3)>0) { push @out, "images"; }
	if (($val & 1<<4)>0) { push @out, "inventory"; }
	if (($val & 1<<5)>0) { push @out, "relations"; }
	if (($val & 1<<6)>0) { push @out, "shipping"; }

	## these are high level product bits
	if (($val & 1<<10)>0) { push @out, "unreal"; }	
	if (($val & 1<<14)>0) { push @out, "blocked"; }
	if (($val & 1<<15)>0) { push @out, "deleted"; }

	return(join(',',@out));
	}



%AMAZON3::UPC_TYPES = (
	''=>{},			## unknown/undetermined
	'base'=>{},		## a single product by itself.
	'child'=>{},	## a subordinate of a parent, also can be a "base" depending on category
						## note: children can *NEVER* have accessories.
	'orphan'=>{},	## a child, with no parent (necessary in some categories)
	'nparent'=>{},	##	none (products w/options that are sent as individual products, ie categories don't allow options)
						## note: nparents can never have relationship data. (since their siblings are their relationships)
	'vparent'=>{}, ## it's a parent in a grouping zoovy:prod_
	);


%AMAZON3::POST_TYPES = (
	'OrderAcknowledgement'=>'_POST_ORDER_ACKNOWLEDGEMENT_DATA_',
	'OrderFulfillment'=>'_POST_ORDER_FULFILLMENT_DATA_',
	## hmm.. 
	'Inventory'=>'_POST_INVENTORY_AVAILABILITY_DATA_',
	'Product'=>'_POST_PRODUCT_DATA_',
	'Price'=>'_POST_PRODUCT_PRICING_DATA_',
	'Relationship'=>'_POST_PRODUCT_RELATIONSHIP_DATA_',
	'Image'=>'_POST_PRODUCT_IMAGE_DATA_',
	'ProductImage'=>'_POST_PRODUCT_IMAGE_DATA_',		## Hmm.. this is what shoudl appear in the body i think!?
	'Order Fulfillment'=>'_POST_ORDER_FULFILLMENT_DATA_',
	'Order Acknowledgement'=>'_POST_ORDER_ACKNOWLEDGEMENT_DATA_',
	);

## a lookup table of our CATALOG to amazon CSV feed_product_type
%AMAZON3::CATALOG_CSV_feed_product_type = (
	'SPORTS'=>'SportingGoods'
	);

%AMAZON3::CATALOGS = (
	'APPAREL'=>'Apparel - Shoes, Handbags, Sunglasses/Eyewear',
	'CLOTHING'=>'Clothing and Accessories',
	'AUTOPART.AUTOACCESSORYMISC'=>'AutoParts',
	'CAMERA.BAGCASE'=>'Camera Bag Cases',
	'CAMERA.BINOCULAR'=>'Camera Binocular',
	'CAMERA.BLANKMEDIA'=>'Camera Blank Media',
	'CAMERA.CAMCORDER'=>'Camera Camcorders',
	'CAMERA.CLEANER'=>'Camera Cleaners',
	'CAMERA.DARKROOM'=>'Camera Darkroom',
	'CAMERA.DIGITALCAMERA'=>'Digital Cameras',
	'CAMERA.FILM'=>'Camera Film',
	'CAMERA.FILMCAMERA'=>'Film Cameras',
	'CAMERA.FILTER'=>'Camera Filters',
	'CAMERA.FLASH'=>'Camera Flashes',
	'CAMERA.LENS'=>'Camera Lens',
	'CAMERA.LENSACCESSORY'=>'Camera Lens Accessories',
	'CAMERA.LIGHTING'=>'Camera Lighting',
	'CAMERA.LIGHTMETER'=>'Camera Light Meter',
	'CAMERA.MICROSCOPE'=>'Camera Microscope',
	'CAMERA.OTHERACCESSORY'=>'Camera Other Accessories',
	'CAMERA.PHOTOPAPER'=>'Camera Photo Paper',
	'CAMERA.PHOTOSTUDIO'=>'Camera Photo Studio',
	'CAMERA.POWERSUPPLY'=>'Camera Power Supply',
	'CAMERA.PROJECTION'=>'Camera Projection',
	'CAMERA.SURVEILLANCESYSTEM'=>'Camera Surveillance System',
	'CAMERA.TELESCOPE'=>'Camera Telescope',
	'CAMERA.TRIPODSTAND'=>'Camera Tripod Stands',
	'CE.CONSUMERELECTRONICS'=>'Consumer Electronics',
	'CE.PC'=>'Electronix PC',
	'CE.PDA'=>'Electronix PDA',
	'GOURMET.GOURMETMISC'=>'Food Miscellaneous Gourmet',
	'HEALTH.HEALTHMISC'=>'Miscellaneous Health',
	'HOME.BEDANDBATH'=>'Home Bed and Bath',
	'HOME.FURNITUREANDDECOR'=>'Home Furniture and Decor',
	'HOME.KITCHEN'=>'Home Kitchen',
	'HOME.OUTDOORLIVING'=>'Home Outdoor Living',
	'HOME.SEEDSANDPLANTS'=>'Home Seeds and Plants',
	'JEWELRY.FASHIONEARRING'=>'Jewelry Fashion Earring',
	'JEWELRY.FASHIONNECKLACEBRACELETANKLET'=>'Jewelry Fashion Necklace/Bracelet/Anklet',
	'JEWELRY.FASHIONOTHER'=>'Jewelry Fashion Other',
	'JEWELRY.FASHIONRING'=>'Jewelry Fashion Ring',
	'JEWELRY.FINEEARRING'=>'Jewelry Fine Earring',
	'JEWELRY.FINENECKLACEBRACELETANKLET'=>'Jewelry Fine Necklace/Bracelet/Anklet',
	'JEWELRY.FINEOTHER'=>'Jewelry Fine Other',
	'JEWELRY.FINERING'=>'Jewelry Fine Ring',
	'JEWELRY.WATCH'=>'Jewelry Watch',
	'MISC'=>'Miscellaneous',
	'MUSICINST.BRASSANDWOODWINDINSTRUMENTS'=>'Brass and Woodwind Musical Instruments',
	'MUSICINST.GUITARS'=>'Guitars',
	'MUSICINST.INSTRUMENTPARTSANDACCESSORIES'=>'Musical Instrument Parts and Accessories',
	'MUSICINST.KEYBOARDINSTRUMENTS'=>'Keyboard Musical Instruments',
	'MUSICINST.MISCWORLDINSTRUMENTS'=>'Miscellaneous World Musical Instruments',
	'MUSICINST.PERCUSSIONINSTRUMENTS'=>'Percussion Musical Instruments',
	'MUSICINST.SOUNDANDRECORDINGEQUIPMENT'=>'Sound and Recording Equipment',
	'MUSICINST.STRINGEDINSTRUMENTS'=>'Stringed Musical Instruments',
	'OFFICE.ARTSUPPLIES'=>'Office Art Supplies',
	'OFFICE.EDUCATIONALSUPPLIES'=>'Office Educational Supplies',
	'OFFICE.OFFICEPRODUCTS'=>'Office Products',
	'PETSUPPLY.PETSUPPLIESMISC'=>'Miscellaneous Pet Supplies',
	'EYEWEAR'=>'Eyewear',
	'HANDBAG'=>'Handbags',
	'SHOEACCESSORY'=>'Shoe Accessories',
	'SHOES'=>'Shoes',
	'SOFTWARE.HANDHELDSOFTWAREDOWNLOADS'=>'Handheld Software Download Video Games',
	'SOFTWARE.SOFTWAREGAMES'=>'Software Video Games',
	'SOFTWARE.VIDEOGAMES'=>'Video Games',
	'SOFTWARE.VIDEOGAMESACCESSORIES'=>'Video Games Accessories',
	'SOFTWARE.VIDEOGAMESHARDWARE'=>'Video Games Hardware',
	'SPORTS'=>'Sports',
	'TOOLS'=>'Tools',
#	'TOYS.TOYSANDGAMES'=>'Toys and Games (New: allows variations)',
	'TOYSBABY.TOYSANDGAMES'=>'Toys and Games',
	'TOYSBABY.BABYPRODUCTS'=>'Baby Products',
	'WIRELESS.WIRELESSACCESSORIES'=>'Wireless Accessories',
	'WIRELESS.WIRELESSDOWNLOADS'=>'Wireless Downloads',
   );



##
##
##
sub r_whataremy {
	my ($RELATIONSHIPS,$TYPE) = @_;
	my @RESULTS = ();

	foreach my $line (@{$RELATIONSHIPS}) {
		if ($line->[0] eq $TYPE) { 
			push @RESULTS, $line->[1];
			}
		}

	return(@RESULTS);	
	}

##
## 
##
sub r_ami {
	my ($RELATIONSHIPS,$TYPE) = @_;

	my $yes = 0;
	foreach my $line (@{$RELATIONSHIPS}) {
		if ($line->[0] eq $TYPE) {
			if ($line->[1] eq '') { $yes++; }
			}
		}
	return($yes);
	}

##
## outputs an array of all the relationships to a product
## 
sub relationships {
	my ($P) = @_;

	my $PID = $P->pid();
	my $prodref = $P->prodref();

	my @RELATIONSHIPS = ();
	## 	[ 'TYPE', 'SKU' ]
	my $ME = '';

	#my $has_asm = 0;
	#if ($prodref->{'zoovy:prod_asm'} ne '') { $has_asm |= 1; }
	#if ($P->fetch('pid:assembly') ne '') { $has_asm |= 1; }
	#if ($P->has_variations('inv')) {
	#	foreach my $skuset (@{$P->list_skus('verify'=>1)}) {
	#		my ($sku,$skuref) = @{$skuset};
	#		if ($skuref->{'sku:assembly'}) 
	#		}
	#	}

	my $has_inv_options = 0;
	my $amz_wants_nparent = 0;

	foreach my $pog (@{$P->fetch_pogs()}) {
		if ($pog->{'inv'}>0) { $has_inv_options++; }
		# if ($pog->{'asm'} ne '') { $has_asm |= 2; }

		if ($pog->{'amz'} ne '') {
			my ($catalog,$theme) = (undef,undef);
			## NOTE: (this should probably be changed) the space is apparently required
			##			AND if it is .. andrew says to remember to also change the 'amz:grp_varkey' 'amz:grp_varkey_value'
			##			this seems to be done a few lines below (search for those attributes)
			if ($pog->{'amz'} =~ m/^(\w+)\: (.*)$/) { ($catalog,$theme) = ($1,$2); }
			if ($catalog ne '') {
				#print "POG (build_prodFeed) ".Dumper($pog);
				## so at this point, this option is heading to amazon.
				$catalog =~ s/FOOD/GOURMET/;	# bh: this probably shouldn't be here!
				## check if the theme is a valid category theme
				if ($theme eq 'None') { $amz_wants_nparent++; }
				}
			}
		}

	my @GRP_CHILDREN = ();
	foreach my $CHILDPID (split(/,/,$prodref->{'zoovy:grp_children'})) {
		next if ($CHILDPID eq '');
		push @GRP_CHILDREN, $CHILDPID;
		}

	my $PARENT = $prodref->{'zoovy:grp_parent'};
	if (not defined $PARENT) { $PARENT = ''; }
	if ($PARENT ne '') { 
		push @RELATIONSHIPS, [ 'PARENT', $PARENT ]; 
		}

	## BASE nothing special
	## PARENT/CHILD refers to my relationship in GROUPING
	## PRODUCT/VARIATION refers to my relationship in OPTIONS
	## CONTAINER is anything which has options, or children
	## ORPHANAGE/ORPHAN refers to any abandoned SKU or CHILD
	## XFAMILY/XPRODUCT/XSKU  is any PID which has CHILDREN (VARIATION or FAMILY)

	if ($amz_wants_nparent) { 
		$ME = 'CONTAINER';
		push @RELATIONSHIPS, [ 'ORPHANAGE' ];
		foreach my $set (@{$P->list_skus()}) {
			my ($SKU,$SKUREF) = @{$set};
			push @RELATIONSHIPS, [ 'ORPHAN', $SKU ];
			}
		}

	if ($ME ne '') {
		}
	#elsif ($SKU =~ /:/) {
	#	$ME = 'SKU';
	#	push @RELATIONSHIPS, [ 'PRODUCT', $PID ];
	#	if ($PARENT ne '') {
	#		push @RELATIONSHIPS, [ 'XPRODUCT', $PID ];
	#		push @RELATIONSHIPS, [ 'XFAMILY', $PARENT ];
	#		}
	#	}
	elsif (($PARENT ne '') && (not $has_inv_options)) {
		$ME = 'CHILD';
		}
	elsif ($has_inv_options) {
		$ME = 'CONTAINER';
		push @RELATIONSHIPS, [ 'PRODUCT', $PID ];
		my $child_count = 0;
		foreach my $SKUSET (@{$P->list_skus()}) {
			my ($SKU,$SKUREF) = @{$SKUSET};
			next if ($SKU eq '');
			$child_count++;
			push @RELATIONSHIPS, [ 'VARIATION', $SKU ];
			if ($PARENT ne '') {
				push @RELATIONSHIPS, [ 'XSKU', $SKU ];
				}
         }
	
		if ($child_count == 0) {
			## a container item with inventoriable options, but has no choices (how confusing)
			$ME = 'INVALID-GROUP';
			}

		if ($PARENT ne '') {
			push @RELATIONSHIPS, [ 'XFAMILY', $PARENT ];
			push @RELATIONSHIPS, [ 'XPRODUCT', $PID ];
			}
		}
	elsif (scalar(@GRP_CHILDREN)>0) {
		$ME = 'CONTAINER';
		foreach my $CHILDPID (@GRP_CHILDREN) {
			my ($childP) = PRODUCT->new($P->username(),$CHILDPID);
			if ((not defined $childP) || (ref($childP) ne 'PRODUCT')) {
				$ME = 'INVALID-GROUPING';
				}
			elsif ($childP->has_variations('inv')) {
				$ME = 'XFAMILY';
				push @RELATIONSHIPS, [ 'XPRODUCT', $CHILDPID ];
				foreach my $CHILDSET (@{$childP->list_skus()}) {
					my ($CHILDSKU,$CHILDSKUREF) = @{$CHILDSET};
					push @RELATIONSHIPS, [ 'XSKU', $CHILDSKU ];
					push @RELATIONSHIPS, [ 'VARIATION', $CHILDSKU ];
					}					
				}
			else {
				push @RELATIONSHIPS, [ 'CHILD', $CHILDPID ];
				}
			}
		}
	else {
		$ME = 'BASE';
		}
		
	unshift @RELATIONSHIPS, [ $ME ];	

	## ACCESSORIES
	foreach my $sku (split(",",$prodref->{'zoovy:accessory_products'})) {
		push @RELATIONSHIPS, [ 'ACCESSORY', $sku ];
		}
	foreach my $sku (split(",",$prodref->{'zoovy:related_products'})) {
		push @RELATIONSHIPS, [ 'RELATED', $sku ];
		}

	foreach my $line (@RELATIONSHIPS) {
		## make sure things referencing our sku are blank so we don't need to pass in $PID or $SKU to amia, etc.
		if ($line->[1] eq $P->pid()) { $line->[1] = ''; }
		}

	return(\@RELATIONSHIPS);
	}






#mysql> desc SYNDICATION_PID_ERRORS;
#+-------------+----------------------+------+-----+---------+----------------+
#| Field       | Type                 | Null | Key | Default | Extra          |
#+-------------+----------------------+------+-----+---------+----------------+
#| ID          | int(10) unsigned     | NO   | PRI | NULL    | auto_increment |
#| CREATED_GMT | int(10) unsigned     | NO   |     | 0       |                |
#| ARCHIVE_GMT | int(10) unsigned     | NO   |     | 0       |                |
#| MID         | int(10) unsigned     | NO   | MUL | 0       |                |
#| DSTCODE     | varchar(3)           | NO   |     | NULL    |                |
#| PID         | varchar(20)          | NO   |     | NULL    |                |
#| SKU         | varchar(35)          | NO   |     | NULL    |                |
#| FEED        | smallint(5) unsigned | NO   |     | 0       |                |
#| ERRCODE     | int(10) unsigned     | NO   |     | 0       |                |
#| ERRMSG      | text                 | YES  |     | NULL    |                |
#| BATCHID     | bigint(20)           | NO   |     | 0       |                |
#+-------------+----------------------+------+-----+---------+----------------+
#11 rows in set (0.00 sec)


##
## 
##
#sub add_sku_log {
# 	my ($userref,$SKU,$DOCID,$FEED,$ERRCODE,$ERRMSG) = @_;
#
#	my ($PID) = &PRODUCT::stid_to_pid($SKU);
#
#	my ($udbh) = &DBINFO::db_user_connect($userref->{'USERNAME'});
#
#	## archive any old errors associated with this feed.
#	my $pstmt = &DBINFO::insert($udbh,'SYNDICATION_PID_ERRORS',{ARCHIVE_GMT=>time(),},
#		update=>2, key=>{ MID=>$userref->{'MID'}, FEED=>$FEED, PID=>$PID,SKU=>$SKU, DSTCODE=>'AMZ' }, sql=>1);
#	print STDERR $pstmt."\n";
#	$udbh->do($pstmt);
#
#	## now add this error.
#	($pstmt) = &DBINFO::insert($udbh,'SYNDICATION_PID_ERRORS',{
#		CREATED_GMT=>time(),
#		MID=>$userref->{'MID'},
#		DSTCODE=>'AMZ',
#		PID=>$PID,SKU=>$SKU,
#		FEED=>$FEED,
#		ERRCODE=>$ERRCODE,
#		ERRMSG=>$ERRMSG,
#		BATCHID=>$DOCID,
#		},sql=>1);
#
#	print STDERR $pstmt."\n";
#	$udbh->do($pstmt);
#	&DBINFO::db_user_close();
#	return();
#	}





##
## takes in one or more PID's returns an array of skus (usually used with $userref->{'@PRODUCTS'})
##
#sub sku_expand {
#	my ($USERNAME,@products) = @_;
#
#
#	die("I don't think this actually works");
#
#	my %set = ();
#	foreach my $pid (@products) {
#		my $pref = &ZOOVY::fetchproduct_as_hashref($USERNAME,$pid);
#		my $skurefs = &ZOOVY::skuhash_via_prodref($USERNAME,$pid,$pref);
#		foreach my $sku (keys %{$skurefs}) {
#			$set{$sku}++;
#			}
#		}
#	my @results = keys %set;
#	return(@results);
#	}


##
## takes in _POST_PRODUCT_DATA_ returns PRODUCTS
##		which can then be used as LASTDOC_PRODUCTS
##		or to set FEED_TODO +PRODUCTS 
sub resolve_dbcolumn {
	my ($doctype) = @_;

	my $dbcolumn = undef;
	if ($doctype =~ /^(PRODUCTS|INVENTORY|PRICES|IMAGES|RELATIONS|ACCESSORY|SHIPPING)$/) { $dbcolumn = $doctype; }
	## else the bastard is gonna make us work for it.
	elsif ($doctype eq '_POST_PRODUCT_DATA_') { $dbcolumn = 'PRODUCTS'; }
	elsif ($doctype eq '_POST_PRODUCT_PRICING_DATA_') { $dbcolumn = 'PRICES'; }
	elsif ($doctype eq '_POST_INVENTORY_AVAILABILITY_DATA_') { $dbcolumn = 'INVENTORY'; }
	elsif ($doctype eq '_POST_PRODUCT_IMAGE_DATA_') { $dbcolumn = 'IMAGES'; }
	elsif ($doctype eq '_POST_PRODUCT_RELATIONSHIP_DATA_') { $dbcolumn = 'RELATIONS'; }
	## don't let the programmer thing something happened, that really didn't
	else { 
		ZOOVY::confess("","could not resolve_dbcolumn($doctype)");
		}
	return($dbcolumn);
	}


##
## returns an array of SKU's for a specific DOCTYPE + DOCID
##		used by mws_feed.pl
##
#sub skus_for_doc {
#	my ($userref,$doctype,$docid) = @_;
#
#	my $DBCOLUMN = sprintf("AMZ_LASTDOC_%s",&resolve_dbcolumn($doctype));
#
#	my @SKUS = ();
#	my ($udbh) = &DBINFO::db_user_connect($userref->{'USERNAME'});	
#	my ($sTB) = &ZOOVY::resolve_lookup_tb($userref->{'USERNAME'});
#	my $pstmt = "select SKU from $sTB where MID=$userref->{'MID'} and $DBCOLUMN=".int($docid);
#	print STDERR $pstmt."\n";
#	my $sthx = $udbh->prepare($pstmt);
#	$sthx->execute();
#	while ( my ($SKU) = $sthx->fetchrow() ) {
#		## start with a sane error.
#		push @SKUS, $SKU;
#		}
#	$sthx->finish();
#	&DBINFO::db_user_close();
#
#	return(\@SKUS);
#	}


# 
# &AMAZON3::item_set_status($userref,$SKU,['+products.todo','-products.done'],DOCID=>'',DOCTYPE=>'');
# &AMAZON3::item_set_status($userref,$SKU,['+products.need');
# &AMAZON3::item_set_status($userref,$SKU,['-products.todo','+products.done']);
# &AMAZON3::item_set_status($userref,$SKU,['+products.did');

# 
# 	SYNC  YYYYMMDDHHMMSS	$caller	$SKU	timestamp is now 123
#	STAT	YYYYMMDDHHMMSS	$caller	$SKU	'+products.todo','-products.done'



##
## send inventory for a single item
##
sub sync_inventory {
	my ($USERNAME,$SKU,$IS,$ATTEMPTS) = @_;
	return(0);
	}



##
## okay here's the syntax for feeds - it's an arrayref
##		[ '[+-]/feed/mode' ]
##		FEED can be any type in AMAZON3::BW  (note: please avoid the _mask versions)
##		MODE can: 
##			DONE, TODO, SENT, WAIT, ERROR - all those correspond to FEEDS_TODO, FEEDS_DONE, FEEDS_ERROR
##			also there is an alias which is past/future tense versions - 
##			NEED (equivalent to writing -DONE, +TODO)
##			DID  (+DONE, -TODO)
##			DOH  (sets +DONE+TODO+ERROR)
##			HALT (sets the delete bits on)
##	e.g.:
##		[ '-images.todo', '+images.done' ]  ---- or you could simply write: [ '+images.done' ]
##
## some additional %options that are useful/fun
##		'DOCTYPE'=>PRODUCTS|INVENTORY|PRICES|RELATIONS|ACCESSORY|SHIPPING
##		'DOCID'=>$rdocid
##		'ERROR'=>set the error state for the product to this (no longer used)
##		'ERRCODE'=>error code
##		'ERRMSG'=>error message
##	
##	USE_PIDS
##
sub item_set_status {
	my ($userref,$SKU,$changeAR,%options) = @_;

	if (ref($changeAR) ne 'ARRAY') {
		ZOOVY::confess($userref->{'USERNAME'},"Sorry, but changeAR must be an array of SKUS commands");
		}

	# LASTDOC_PRODUCTS  | bigint(20) unsigned                          | NO   |     | 0       |                |
	# LASTDOC_INVENTORY | bigint(20) unsigned                          | NO   |     | 0       |                |
	# LASTDOC_PRICES    | bigint(20) unsigned                          | NO   |     | 0       |                |
	# LASTDOC_IMAGES    | bigint(20) unsigned                          | NO   |     | 0       |                |
	# LASTDOC_RELATIONS | bigint(20) unsigned                          | NO   |     | 0       |                |
	# LASTDOC_ACCESSORY | bigint(20) unsigned                          | NO   |     | 0       |                |
	# LASTDOC_SHIPPING  | bigint(20) unsigned                          | NO   |     | 0       |                |

	my $ERROR = undef;

	if (defined $options{'DOCTYPE'}) {
		## if we were nice and passed a valid DOCTYPE (which matches our DBCOLUMN use that
		$options{'DOCTYPE'} = &AMAZON3::resolve_dbcolumn($options{'DOCTYPE'});
		}

	## columns are 
	my @PARSED = ();

	foreach my $feedcmd (@{$changeAR}) {
		next if ($ERROR ne '');
		## +-= products reset
		if ($feedcmd =~ /^\=this\.(.*?)$/) {
			## note: =this.create_xxxx and =this.delete_xxxx are special commands that effectively "douche" the record.
			## 		and leave it clean smelling, they are very destructive and should be used with extreme caution.
			my ($verb) = $1;
			$options{'RELATIONSHIP'} = '';
			#if ($feedcmd eq '=this.retry_please') {
			#	## set the todo bits on for any bits that are WAIT
			#	push @PARSED, [ '|', 'todo', 'wait' ];
			#	}
			if ($feedcmd eq '=this.create_please') {
				## this.create -- should be called when we want to reset a product and send all feeds
				#push @PARSED, [ '-', 'delete', 'done', $AMAZON3::BW{'deleted'} ];	# remove flags
				#push @PARSED, [ '-', 'delete', 'todo', $AMAZON3::BW{'deleted'} ];	# remove flags
				#push @PARSED, [ '-', 'delete', 'error', $AMAZON3::BW{'deleted'} ];	# remove flags
				#push @PARSED, [ '-', 'delete', 'wait', $AMAZON3::BW{'deleted'} ];	# remove flags
				#push @PARSED, [ '-', 'delete', 'sent', $AMAZON3::BW{'deleted'} ];	# remove flags
				push @PARSED, [ '=', '', 'todo', $AMAZON3::BW{'all'}|$AMAZON3::BW{'init'} ]; #  other feeds CHECK init before the actually send (so it's safe to set todo on for all)
				push @PARSED, [ '=', '', 'done', 0 ];
				push @PARSED, [ '=', '', 'wait', 0 ];
				push @PARSED, [ '=', '', 'sent', 0 ];
				push @PARSED, [ '=', '', 'error', 0 ];
				}
			elsif ($feedcmd eq '=this.create_sent') {
				## this.create_sent: it's been sent to amazon, but it's definitely NOT done.
				push @PARSED, [ '-', '', 'todo', $AMAZON3::BW{'init'} | $AMAZON3::BW{'products'} ]; #  
				push @PARSED, [ '+', '', 'wait', $AMAZON3::BW{'init'} | $AMAZON3::BW{'products'} ]; #  
				push @PARSED, [ '+', '', 'sent', $AMAZON3::BW{'init'} | $AMAZON3::BW{'products'} ]; #  
				}
			elsif ($feedcmd eq '=this.create_done') {
				## this.create_done
				push @PARSED, [ '-', '', 'wait', $AMAZON3::BW{'init'} | $AMAZON3::BW{'products'} ]; #  other feeds CHECK init before the actually send (so it's safe to set todo on for all)
				push @PARSED, [ '+', '', 'done', $AMAZON3::BW{'init'} | $AMAZON3::BW{'products'} ]; #  other feeds CHECK init before the actually send (so it's safe to set todo on for all)
				}
			elsif ($feedcmd eq '=this.delete_please') {
				push @PARSED, [ '=', '', 'todo', $AMAZON3::BW{'deleted'} ]; # 
				push @PARSED, [ '=', '', 'wait', 0 ];
				push @PARSED, [ '=', '', 'sent', 0 ];
				push @PARSED, [ '=', '', 'error', 0 ];
				}
			elsif ($feedcmd eq '=this.delete_sent') {
				## this.delete (aka deleted.sent) is a bit special, since it turns off ALL errors
				push @PARSED, [ '=', '', 'error', 0 ];  	# reset all errors
				push @PARSED, [ '=', '', 'todo',  0 ];		# turn off all todo
				push @PARSED, [ '=', '', 'sent', $AMAZON3::BW{'deleted'} ]; # 
				push @PARSED, [ '=', '', 'wait', $AMAZON3::BW{'deleted'} ]; # 
				}
			elsif ($feedcmd eq '=this.delete_done') {
				push @PARSED, [ '=', '', 'done', $AMAZON3::BW{'deleted'} ]; # 
				push @PARSED, [ '=', '', 'todo', 0 ];
				push @PARSED, [ '=', '', 'wait', 0 ];
				push @PARSED, [ '=', '', 'sent', 0 ];
				push @PARSED, [ '=', '', 'error', 0 ];
				}
			elsif ($feedcmd eq '=this.will_not_be_sent') {
				## a vcontainer that is not sent to amazon  (set txlog 'product' STOP to reason)
				push @PARSED, [ '=', '', 'done', $AMAZON3::BW{'not_needed'} ];	
				push @PARSED, [ '=', '', 'error', 0 ];	
				push @PARSED, [ '=', '', 'todo', 0 ];	
				push @PARSED, [ '=', '', 'sent', 0 ];	
				push @PARSED, [ '=', '', 'wait', 0 ];	
				}
			elsif ($feedcmd eq '=this.fatal_error') {
				## a vcontainer that is not sent to amazon  (set txlog 'product' STOP to reason)
				push @PARSED, [ '=', '', 'done', 0 ]; # $AMAZON3::BW{'not_needed'} ];	
				push @PARSED, [ '=', '', 'error', $AMAZON3::BW{'blocked'} ];	
				push @PARSED, [ '=', '', 'todo', 0 ];	
				push @PARSED, [ '=', '', 'sent', 0 ];	
				push @PARSED, [ '=', '', 'wait', 0 ];	
				}
			else {
				die("Unsupported feedcmd verb for this[$feedcmd]");
				}
			}
		elsif ($feedcmd =~ /^([\-\+\=])(.*?)\.(|win|sent|fail|done|todo|error|send|need|did|doh|nuke|reset|retry|stop)$/) {
			my ($op,$feed,$verb) = ($1,$2,$3);
			my $bitval = $AMAZON3::BW{$feed};
			if ($feed eq 'this') { $bitval = 0xFFFF; }

			if (not defined $bitval) {
				$ERROR = "Unknown feed[$feed] in $feedcmd";
				}
			elsif (($op ne '+') && ($op ne '-') && ($op ne '=')) {
				$ERROR = "Unknown op[$op] in $feedcmd";
				}
			elsif (($verb eq 'done') || ($verb eq 'todo') || ($verb eq 'error')) {
				## standard, singular columns
				push @PARSED, [ $op, $feed, $verb, $bitval ];
				}
			elsif ($verb eq 'send') {
				## changes todo and done states. 
				## note: it's never a good idea to run this on 'products' or 'all' because it turns 
				##			off done which can impact other feeds.  use "need" instead.
				push @PARSED, [ '+', $feed, 'todo', $bitval ];
				push @PARSED, [ '-', $feed, 'done', $bitval ];
				}
			elsif ($verb eq 'need') {
				## changes todo and done states. 
				## note: run this on products because it leaves on done which can impact
				##			other feeds.
				push @PARSED, [ '+', $feed, 'todo', $bitval ];
				push @PARSED, [ '-', $feed, 'done', ($bitval & $AMAZON3::BW{'products_mask'}) ];
				## make sure we unflag deleted products/sku's so we can try and resyndicate them.
				## the lines below were a REALLY bad idea and are left here of poserity as a reminder to the next poor soul who MIGHT think they are a good idea
				## why are they a bad idea? well .. 
				## just because I needed to send images DOES NOT MEAN I SHOULD UNDELETE THE WHOLE FUCKING PRODUCT. whatever part of the software deleted
				## the product probably had it right, and even if some asshole subprocess thinks an image needs to go up - that's tough shit, it's deleted
				## and it should stay that way.  if you are changing the lines below - you aren't FIXING the problem, you're just adding duct tape to cover
				## the problem up -- don't be a douche go find the module which incorrectly set the product to deleted, or write a new process which 
				## ressurects products which were properly deleted.
				#push @PARSED, [ '-', $feed, 'done', $AMAZON3::BW{'deleted'} ];
				#push @PARSED, [ '-', $feed, 'todo', $AMAZON3::BW{'deleted'} ];
				push @PARSED, [ '=', $feed, 'error', 0 ];
				}
			elsif ($verb eq 'did') {
				## we've synced up a specific type of feed, changes done and todo states
				push @PARSED, [ '-', $feed, 'todo', $bitval ];
				push @PARSED, [ '+', $feed, 'done', $bitval ];
				}
			elsif ($verb eq 'doh') {
				## some error happened.
				push @PARSED, [ '-', $feed, 'todo', $bitval ];
				push @PARSED, [ '+', $feed, 'done', $bitval ];
				push @PARSED, [ '+', $feed, 'error', $bitval ];
				}
			elsif ($verb eq 'nuke') {
				## we want to delete this product.
				push @PARSED, [ '=', $feed, 'todo', $bitval ];
				push @PARSED, [ '=', $feed, 'done', $bitval ];
				push @PARSED, [ '=', $feed, 'error', $bitval ];
				}
			elsif ($verb eq 'nuked') {
				## confirmation product has been fully deleted.
				push @PARSED, [ '=', $feed, 'todo', 0 ];
				push @PARSED, [ '=', $feed, 'done', $bitval ];
				push @PARSED, [ '=', $feed, 'error', $bitval ];
				}
			elsif ($verb eq 'sent') {
				## sent is used after a feed is uploaded to amazon and we received back a doc id.
				my $combo_bitval = $bitval;
				if (($bitval & 3)>0) { $combo_bitval |= 3; }	## treat init, products, or products+init as the same
				if ($feed eq 'init') { die("don't do init.sent - use this.create ".join("|",caller(0))); }
				push @PARSED, [ '-', $feed, 'error', $combo_bitval ];  	# turn off error
				push @PARSED, [ '-', $feed, 'todo', $combo_bitval ];		# turn off todo
				push @PARSED, [ '+', $feed, 'sent', $combo_bitval ];		# turn on sent
				push @PARSED, [ '-', $feed, 'done', $bitval ];		
				}
			elsif ($verb eq 'stop') {
				my $combo_bitval = $bitval;
				if (($bitval & 3)>0) { $combo_bitval |= 3; }	## treat init, products, or products+init as the same
				push @PARSED, [ '-', $feed, 'todo', $bitval ];
				push @PARSED, [ '+', $feed, 'done', $bitval ];
				push @PARSED, [ '-', $feed, 'error', $bitval ];
				push @PARSED, [ '-', $feed, 'wait', $bitval ];
				push @PARSED, [ '-', $feed, 'sent', $bitval ];
				}
			elsif ($verb eq 'win') {
				## fail is used when we cannot process due to an internal error or we receive a response back from amazon
				push @PARSED, [ '-', $feed, 'error', $bitval ];  	# turn off error
				push @PARSED, [ '-', $feed, 'todo', $bitval ];		# turn off todo
				push @PARSED, [ '-', $feed, 'sent', $bitval ];		# turn off sent (we're not waiting for ack)
				push @PARSED, [ '+', $feed, 'done', $bitval ];		# turn on done
				}
			elsif ($verb eq 'fail') {
				## fail is used when we cannot process due to an internal error or we receive a response back from amazon
				push @PARSED, [ '+', $feed, 'error', $bitval ];  	# turn ON error
				push @PARSED, [ '-', $feed, 'todo', $bitval ];		# turn off todo
				push @PARSED, [ '-', $feed, 'sent', $bitval ];		# turn on sent
				push @PARSED, [ '-', $feed, 'done', $bitval ];		
				}
			elsif ($verb eq 'retry') {
				## retry gracefully re-flags data so that we'll do it again.
				push @PARSED, [ '+', $feed, 'todo', $bitval ];		# turn on todo
				push @PARSED, [ '-', $feed, 'sent', $bitval ];		# turn off sent
				push @PARSED, [ '-', $feed, 'wait', $bitval ];		# turn off wait
				}
			else {
				$ERROR = "Unknown verb[$verb] in $feedcmd";
				}


			## modern amazon4 calls:
			##
			## columns:
			##		todo: need to send
			##		sent: latest version (we know about) has been sent to amazon (0 = known unsynched changes)
			##		wait: 1=amazon has received the document, 0=amazon has processed the doc.
			##		done: the latest version is live on amazon (init,delete has special behaviors)
			## 	error: there was an error processing the document. 
			##	
			## standard actions:
			##		create: sets 0error, 0sent, 0wait, done
			## 	fail: sets +error (caused by any error)
			##		todo: sets +todo, -sent, -error (usually set by events or script) 
			##		sent: sets +sent, +wait, -error (data has been sent to amazon and we received a docid)
			##		win: sets -wait, +done, -error (data has been confirmed by amazon)
			## 	
			
			## 
			}
		else {
			$ERROR = "Could not understand feedcmd[$feedcmd]";
			}
		}

	## 
	## SANITY: at this point @PARSED is a series of distinct operations which in a moment we'll group
	##				into actionable bitwise values / operations and then eventually into SQL statement
	##
	# print STDERR Dumper(\@PARSED);

	##
	## DBCOLS is a hash of arrayrefs keyed by column+operation
	##		array 0: tracks if it's changed. (>1 means yes)
	##		array 1: tracks the current operation (|&) value this is important if we have products(1)+images(4) then it'd be 5
	##		array 2: the sprintf statement with %d where value of array1 goes.
	##
	my %DBCOLS = (
		FEED_TODO_AND => [0,0xFFFF,"AMZ_FEEDS_TODO=AMZ_FEEDS_TODO&%d"],
		FEED_DONE_AND => [0,0xFFFF,"AMZ_FEEDS_DONE=AMZ_FEEDS_DONE&%d"],
		FEED_SENT_AND => [0,0xFFFF,"AMZ_FEEDS_SENT=AMZ_FEEDS_SENT&%d"],
		FEED_WAIT_AND => [0,0xFFFF,"AMZ_FEEDS_WAIT=AMZ_FEEDS_WAIT&%d"],
		FEED_ERROR_AND => [0,0xFFFF,"AMZ_FEEDS_ERROR=AMZ_FEEDS_ERROR&%d"],	
		FEED_TODO_OR => [0,0x0,"AMZ_FEEDS_TODO=AMZ_FEEDS_TODO|%d"],
		FEED_DONE_OR => [0,0x0,"AMZ_FEEDS_DONE=AMZ_FEEDS_DONE|%d"],
		FEED_SENT_OR => [0,0x0,"AMZ_FEEDS_SENT=AMZ_FEEDS_SENT|%d"],
		FEED_WAIT_OR => [0,0x0,"AMZ_FEEDS_WAIT=AMZ_FEEDS_WAIT|%d"],
		FEED_ERROR_OR => [0,0x0,"AMZ_FEEDS_ERROR=AMZ_FEEDS_ERROR|%d"],	
		FEED_TODO_EQ => [0,0x0,"AMZ_FEEDS_TODO=%d"],
		FEED_DONE_EQ => [0,0x0,"AMZ_FEEDS_DONE=%d"],
		FEED_SENT_EQ => [0,0x0,"AMZ_FEEDS_SENT=%d"],
		FEED_WAIT_EQ => [0,0x0,"AMZ_FEEDS_WAIT=%d"],
		FEED_ERROR_EQ => [0,0x0,"AMZ_FEEDS_ERROR=%d"],	
		);

	# print Dumper(\@PARSED);
	foreach my $set (@PARSED) {
		my ($op, $feed, $verb, $bitval) = @{$set};
		if ($op eq '+') {
			$DBCOLS{ uc("FEED_$verb\_OR") }->[0]++;
			$DBCOLS{ uc("FEED_$verb\_OR") }->[1] |= ($DBCOLS{ uc("FEED_$verb\_OR") }->[1] | $bitval);
			}
		elsif ($op eq '-') {
			$DBCOLS{ uc("FEED_$verb\_AND") }->[0]++;
			$DBCOLS{ uc("FEED_$verb\_AND") }->[1] = ($DBCOLS{ uc("FEED_$verb\_AND") }->[1] & ~$bitval);
			}
		elsif ($op eq '=') {
			$DBCOLS{ uc("FEED_$verb\_EQ") }->[0]++;
			$DBCOLS{ uc("FEED_$verb\_EQ") }->[1] |= ($DBCOLS{ uc("FEED_$verb\_EQ") }->[1] | $bitval);
			}
		else {
			$ERROR = "Unknown parsed operation[$op]";
			}
		}

	##
	## SANITY: Lets make an SQL statement.
	##
	my ($udbh) = &DBINFO::db_user_connect($userref->{'USERNAME'});
	my ($sTB) = &ZOOVY::resolve_lookup_tb($userref->{'USERNAME'});
	my @PSTMTS = ();

	my $pstmt = "/* ".join(",",@{$changeAR})." */ update $sTB set ";
	my ($changed) = 0;
	foreach my $key (sort keys %DBCOLS) {
		# print "KEY: $key\n";
		next if ($DBCOLS{$key}->[0] == 0);	## no need to include, it hasn't changed.
		$pstmt .= sprintf($DBCOLS{$key}->[2],$DBCOLS{$key}->[1]);
		$pstmt .= ",";
		$changed++;
		}
	chop($pstmt);

	#if (defined $options{'RELATIONSHIP'}) {
	#	$pstmt .= ",AMZ_RELATIONSHIP=".$udbh->quote($options{'RELATIONSHIP'}).' ';
	#	}
	if ($options{'DOCTYPE'}) {
		$options{'DOCID'} = int($options{'DOCID'});
		$pstmt .= ",AMZ_LASTDOC_$options{'DOCTYPE'}=$options{'DOCID'} ";
		}
	if (defined $options{'ERROR'}) {
		## can be used to reset options to blank
		$pstmt .= ",AMZ_ERROR=".$udbh->quote($options{'ERROR'}).' ',
		}
	if ($options{'+ERROR'}) {
		## append a txline to AMZ_ERROR
		$pstmt .= ",AMZ_ERROR=concat(".$udbh->quote($options{'+ERROR'}).",AMZ_ERROR) ";
		}
	if ($options{'PRODUCTDB_GMT'}) {
		$pstmt .= ",AMZ_PRODUCTDB_GMT=".int($options{'PRODUCTDB_GMT'}).' ',
		}
	elsif ((defined $options{'TS'}) && ($options{'TS'}>0)) {
		$pstmt .= ",AMZ_PRODUCTDB_GMT=".time();
		}

	$pstmt .= " where MID=".int($userref->{'MID'})." /* $userref->{'USERNAME'} */ ";

	if (ref($SKU) eq 'ARRAY') {
		## we expected an array.
		}
	elsif (ref($SKU) eq '') { 
		## but we also allow scalars (i hope this isn't being called in a loop)
		$SKU = [ $SKU ]; 
		}
	else {
		$ERROR = "Unknown SKU type specified ".ref($SKU);
		}


	if (ref($SKU) ne 'ARRAY') {
		# print Dumper(\%options);
		&ZOOVY::confess($userref->{'USERNAME'},"**INTERNAL LOGIC** AMAZON3::item_set_status received non SKU array",justkidding=>1);
		}
	elsif (scalar(@{$SKU})==0) {
		$ERROR = "What? an empty array of SKU or PID was passed.";
		&ZOOVY::confess($userref->{'USERNAME'},"**INTERNAL LOGIC** AMAZON3::item_set_status received empty SKU array",justkidding=>1);
		push @PSTMTS, $pstmt;
		}
	else {
		# print Dumper($SKU);
		foreach my $batch (@{&ZTOOLKIT::batchify($SKU,150)}) {
			my $set = &DBINFO::makeset($udbh,$batch);
			#if ($options{'INCLUDE_OFFSPRING'}) {
			### hunt down anything which thinks this is it's parent, including children of vcontainers.
			#	if (not defined $options{'USE_PIDS'}) {
			#		&ZOOVY::confess($userref->{'USERNAME'},"**INTERNAL LOGIC*** AMAZON3::item_set_status WARNING: INCLUDE_OFFSPRING is only compatible with USE_PIDS",justkidding=>1);
			#		}
			#	# my $set = &DBINFO::makeset($udbh,$SKU);
			#	#$pstmt .= " and (PID in $set or PARENT in $set) ";
			#	push @PSTMTS, sprintf("/* 1/2 */ $pstmt and (PID in %s)",$set);
			#	push @PSTMTS, sprintf("/* 2/2 */ $pstmt and (PARENT in %s)",$set);
			#	}
			if ((defined $options{'USE_PIDS'}) && ($options{'USE_PIDS'}>0)) {
				# $pstmt .= " and PID in ".&DBINFO::makeset($udbh,$SKU);
				## LFMF: avoid putting $pstmt inside the sprintf since +ERROR will often have %% values in them
				push @PSTMTS, $pstmt.sprintf(" and PID in %s",$set);
				}
			else {
				# $pstmt .= " and SKU in ".&DBINFO::makeset($udbh,$SKU);
				## LFMF: avoid putting $pstmt inside the sprintf since +ERROR will often have %% values in them
				push @PSTMTS, $pstmt.sprintf(" and SKU in %s",$set);
				}		
			}
		}


	if ((not $ERROR) && ($changed>0)) {
		## if there were zero changes, (why?) then no sense running update.
		foreach my $pstmt (@PSTMTS) {
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			}
		}

	if (($options{'DOCTYPE'}) && ($options{'%SKUMSGS'})) {
		foreach my $SKU (sort keys %{$options{'%SKUMSGS'}}) {
			my ($PID,$CLAIM,$INVOPTS) = &PRODUCT::stid_to_pid($SKU);
			#$pstmt = "update AMAZON_PID_UPCS set LASTDOC_$options{'DOCTYPE'}_MSGID=".int($options{'%SKUMSGS'}->{$SKU});
			#$pstmt .= " where MID=$userref->{'MID'} /* $userref->{'USERNAME'} */ and SKU=".$udbh->quote($SKU);
			$pstmt = "update $sTB set AMZ_LASTDOC_$options{'DOCTYPE'}_MSGID=".int($options{'%SKUMSGS'}->{$SKU});
			$pstmt .= " where MID=$userref->{'MID'} /* $userref->{'USERNAME'} */ and PID=".$udbh->quote($PID)." and INVOPTS=".$udbh->quote($INVOPTS);
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			}
		}

	&DBINFO::db_user_close();

	if ($ERROR) {
		ZOOVY::confess($userref->{'USERNAME'},$ERROR);
		}
#	my $pstmt = '';
	
#	$pstmt = "update AMAZON_PID_UPCS set FEEDS_TODO=0,FEEDS_ERROR=0,FEEDS_DONE=$AMAZON3::BW{'deleted'}, UPLOADED_GMT=".time().
#				" where MID=".$dbh->quote($MID)." and SKU=".$dbh->quote($SKU);
#		## don't update UPC if it is NULL or doesn't exist
#		## this is all types except products
#      $pstmt = "/* map_to_pid_upcs */ update AMAZON_PID_UPCS set ";
#
#      ## update INVENTORY_GMT if we're sending inv, otherwise UPLOADED_GMT
#      if ($type eq 'inventory') { $pstmt .= " INVENTORY_GMT=".time()." "; }
#      else { $pstmt .= " UPLOADED_GMT=".time()." "; }      
#
#      if (($UPC ne '') && ($UPC ne 'NULL')) { $pstmt .= ", UPC=".$dbh->quote($UPC)." "; }
#      
      
##      if ($catalog ne '') { $pstmt .= ",CATALOG='".$catalog."' "; }
#      if ($relationship ne '') { $pstmt .= ",RELATIONSHIP='".$relationship."' "; }
#      
#		if (not defined $AMAZON3::BW{$type}) {
#			die("Unknown Type: $type");
#			}
#
#		## we're in a feed, so we can safely turn it's TODO bit off";
#      $pstmt .= ",FEEDS_TODO=FEEDS_TODO&".$AMAZON3::BW{"$type\_mask"}." ";
#		$pstmt .= " where MID=$MID /* $USERNAME */";
#      # $pstmt .= " where MID=$MID /* $USERNAME */";
#      $pstmt .= " and SKU=".$dbh->quote($SKU);
#
#
	}








##
## purpose: this just *ADDS_AN_ITEM* it should ONLY BE CALLED if the item doesn't exist.
##			it will throw an error if you try and call it for items that already exist
##
#sub item_add {
#	my ($userref,$SKU,$catalog,$relationship,$UPC) = @_;
#
#	if ((not defined $relationship) || ($relationship eq '')) {
#		ZOOVY::confess($userref->{'USERNAME'},"Sorry, but relationship is *really* not optional for item_add");
#		}
#
#	my $ERROR = undef;
#	my ($USERNAME) = $userref->{'USERNAME'};
#	my ($PID) = &PRODUCT::stid_to_pid($SKU);
#	if ($PID eq '') { ZOOVY::confess($userref->{'USERNAME'},"FATALITY: blank sku to AMAZON3::map_pid_to_upcs"); }
#	$catalog =~ s/:$//;
#
#	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#	
#	my $pstmt = "select count(1) from AMAZON_PID_UPCS where MID=$MID /* $USERNAME */ and SKU=".$udbh->quote($SKU);
#	print $pstmt."\n";
#	my ($exists) = $udbh->selectrow_array($pstmt);
#	print "AMAZON_PID_UPCS EXISTS: $exists\n";
#	if ($exists) {
#		$ERROR = "OKAY|Item $SKU already exists";
#		}
#	elsif (($exists == 0) && (not defined $catalog)) { 
#		ZOOVY::confess($userref->{'USERNAME'},"FATALITY: blank catalog to AMAZON3::map_pid_to_upcs when sku doesn't exist in AMAZON_PID_UPCS table!"); 
#		}
#
#	my $is_dup = 0;
#	if ($ERROR ne '') {
#		}
#	elsif ($MID == 52277) { 
#		## not sure why this is here, but apparently TOYNK can have duplicate UPC's.
#		## toynk has multiple products with the same UPC i'm assuming
#		## seems like eventually we could make this a setting in AMAZON_FEEDS
#		}
#	elsif ($UPC eq '') {
#		## hmm.. hope you meant to add one without a UPC.
#		}
#	elsif ($UPC ne '') {
#		## TEST FOR DUPLICATE UPC
#		my @DUPS = ();
#		my $pstmt = "select SKU from AMAZON_PID_UPCS where UPC=".$udbh->quote($UPC)." and MID=$MID";
#		print STDERR "$pstmt\n";
#		my $sth = $udbh->prepare($pstmt);
#		$sth->execute();
#		while( my ($dupSKU) = $sth->fetchrow()) {
#			next if ($dupSKU eq $SKU);	# skip our product id, but see if any other products have the same UPC
#			push @DUPS, $dupSKU;			## if this is a user-defined UPC we'll throw an error.
#			}
#	   $sth->finish;
#		if (scalar(@DUPS)>0) {
#			$ERROR = "FAIL|Duplicate UPC[$UPC] for $SKU (found in: ".join(@DUPS).")\n";
#			}
#		}
#
#	if ($ERROR) {
#		## shit happened.
#		}
#	elsif ($exists == 0) {
#		if ($relationship eq '') { $relationship = 'base'; }
#		## no need to insert UPC, defaults to NULL
#      my %i = ();
#      $i{'MID'} = $MID;
#      $i{'PID'} = $PID;
#      $i{'SKU'} = $SKU;
#      $i{'FEEDS_DONE'} = 0;
#      $i{'UPLOADED_GMT'} = 0,
#      $i{'RELATIONSHIP'} = $relationship;
#      $i{'CATALOG'} = $catalog;
#		$i{'FEEDS_TODO'} = $AMAZON3::BW{'all'};
#  		if (($UPC ne '') && ($UPC ne 'NULL')) { $i{'UPC'} = $UPC; }
#      ($pstmt) = &DBINFO::insert($udbh,'AMAZON_PID_UPCS',\%i,debug=>1+2);		
#		$udbh->do($pstmt);
#		}
#	else {
#		ZOOVY::confess($userref->{'USERNAME'},"This is never reached under normal running circumstances");
#		}
#
#	&DBINFO::db_user_close();
#	return($ERROR);
#	}









##############################


## get Zoovy Order id, given an Amazon Order Id
##
## input: amz_orderid
##	output: 
##		Zoovy Order ID 
##		MID
## sub was commented out. uncommented it because it is required to able to search for orders by Amazon order. 
## changed the database used within the sub from ZOOVY because the Amazon tables are now cluster specific.
## changed the input to use $USERNAME as well as $AMZ_ORDERID so that we could open cluster specific tables.
## added 'ZOOVY::resolve_mid' rather than returning the MID in the select statement to increase the sub's efficiency. at 2010-08-29
sub resolve_orderid {
	my ($USERNAME, $AMZ_ORDERID) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select OUR_ORDERID from AMAZON_ORDERS where MID=$MID and AMAZON_ORDERID=".$udbh->quote($AMZ_ORDERID);
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my ($ORDERID) = $sth->fetchrow();
	$sth->finish();

	&DBINFO::db_user_close();
	return($MID,$ORDERID);
	}

## resend feed
## inputs:
##		USERNAME
##		PRT
##		DOCID
##		
#sub resend_feed {
#	my ($userref,$DOCID) = @_;
#
#	# die("AMAZON::TRANSPORT::postDocument no longer exists.. now AMAZON3::push_xml");
#
#	my $USERNAME = $userref->{'USERNAME'};
#	my $MID = ZOOVY::resolve_mid($USERNAME);
#	my ($udbh) = DBINFO::db_user_connect($userref->{'USERNAME'});
#	my %type = ();
#
#	$type{'Relationship'} = '_POST_PRODUCT_RELATIONSHIP_DATA_';
#	$type{'ProductImage'} = '_POST_PRODUCT_IMAGE_DATA_';
#	$type{'Price'} = '_POST_PRODUCT_PRICING_DATA_';
#	$type{'Product'} = '_POST_PRODUCT_DATA_';
#	$type{'OrderFulfillment'} = '_POST_ORDER_FULFILLMENT_DATA_';
#	$type{'OrderAcknowledgement'} = '_POST_ORDER_ACKNOWLEDGEMENT_DATA_';
#	$type{'Inventory'} = '_POST_INVENTORY_AVAILABILITY_DATA_';
#
#	## open feed file
#	
#	open(FILE, &ZOOVY::resolve_userpath($USERNAME)."/PRIVATE/amz-$DOCID.xml");
#	my $contents = '';
#	while(<FILE>) {
#		$contents .= $_;
#		}
#	close(FILE);
#
#	## <MessageType>OrderFulfillment</MessageType>
#	$contents =~ /\<MessageType\>(.*)\<\/MessageType\>/s;
#	my $msgtype = $1;
#
#	my $VAR1;
#	eval($contents);
#
#	#$contents =~ s/'\;//;
#	#$contents =~ s/\$VAR1 \= '//;
#	# print $VAR1;
#	$contents = $VAR1;
#
#	print STDERR "USERNAME: $USERNAME msgtype: $msgtype type: ".$type{$msgtype}."\n\n";
#	$USERNAME = lc($USERNAME);	
#
#	## check to see if this feed is already a RESEND
#	my $pstmt = "select DOCID from AMAZON_DOCS where RESENT_DOCID = $DOCID and MID = $MID";
#	print STDERR $pstmt."\n";
#	my $sth = $udbh->prepare($pstmt);
#	$sth->execute();
#	my ($orig_docid) = $sth->fetchrow();
#	$sth->finish();
#
#	my $resent_docid = 0;
#	my $error = '';
#	## DOCID has already been RESENT
#	if ($orig_docid ne '') {
#		$error = "The contents of this DOCID (orig: $orig_docid docid: $DOCID) has already been RESENT.";
#
#		## update AMAZON_LOG to indicate that DOCID was RESENT and it failed
#		my $pstmt = "update AMAZON_LOG set message = concat(message,' - FAILED RESENT') where DOCID = $DOCID and MID = $MID and type = 'ERR'";
#		print $pstmt."\n";
#		#print $udbh->do($pstmt);
#
#		} 		
#
#	## otherwise RESEND
#	else {
#		## used to be postDocument
#		my ($resent_docid, $error) = AMAZON3::push_xml($userref,$type{$msgtype},$contents);
#		print "DOCID: $resent_docid ERROR: $error\n";
#
#		## update AMAZON_LOG/AMAZON_DOCS to indicate that DOCID was RESENT
#		my $pstmt = "update AMAZON_LOG set message = concat(message,' - RESENT'),TYPE='PROCESS' where DOCID = $DOCID and MID = $MID and type = 'ERR'";
#		print $pstmt."\n";
#		print $udbh->do($pstmt);
#
#		$pstmt = "update AMAZON_DOCS set RESENT_DOCID=$resent_docid where DOCID = $DOCID and MID = $MID";	
#		print $pstmt."\n";
#		print $udbh->do($pstmt);
#		}
#
#	DBINFO::db_user_close();
#
#	return($resent_docid,$error);
#	}
#







## utility function: returns true/false if a value is defined.
sub is_defined { return( ((defined $_[0]) && ($_[0] ne ''))  ); }

##
## a stupid function that checks a series of variables for the best NON-BLANK match
##
sub canipleasehas {
	my ($pref,@vars) = @_;

	my $result = undef;
	foreach my $v (@vars) {
		next if (defined $result);
		if ($pref->{$v} ne '') {
			$result = $pref->{$v};
			}
		}
	return($result);
	}


##
## fix_relations
## 
## - merchants sometimes change the structure of a product
## -- ie from a product w/o options to a product w/options
## 
## this is run to fix these instancies
##
## note: could start storing parent in a separate field
##
#sub fix_relations {
#	my ($USERNAME) = @_; 
#
#	warn "I'm not fixing relations anymore(need to get this working)";
#	return();
#
#	my $udbh = &DBINFO::db_zoovy_connect();	
#	my $MID = ZOOVY::resolve_mid($USERNAME);
#	my $pstmt = "select MID, PID,SKU, relationship from AMAZON_PID_UPCS where MID=$MID /* $USERNAME */ and RELATIONSHIP=''";
#
#	print STDERR "FIX RELATIONS: ".$pstmt."\n";
#	my $sth = $udbh->prepare($pstmt);
#	$sth->execute;
#
#	my $ctr = 0;
#	while(my ($MID, $pid, $sku, $current) = $sth->fetchrow() ) {
#		my $qtPID = $udbh->quote($pid);
#		my $qtSKU = $udbh->quote($sku);
#		## vparent = virtual (grouped products) and 
#		## nparent = none (products w/options that are sent as individual products, ie categories don't allow options)
#		## neither of these case need to be fixed or rather can be fixed
#		if ($current eq 'nparent') {
#			}
#		elsif ($current eq 'vparent') {
#			my @grp_children = split(/,/,ZOOVY::fetchproduct_attrib($USERNAME,$pid,'zoovy:grp_children'));
#			 
#			foreach my $child (@grp_children) {
#				my $child_pogs = ZOOVY::fetchproduct_attrib($USERNAME,$child,'zoovy:pogs');
#				 
#				my $pstmt3 = "update AMAZON_PID_UPCS set relationship = 'child', parent=$qtPID where MID=$MID and sku=$qtSKU";
#				## if grp child doesn't have options...
#				if ($child_pogs eq '') {
#					$pstmt3 = "update AMAZON_PID_UPCS set relationship = 'child', parent=$qtPID where MID=$MID and sku=$qtSKU";
#					}
#				print $pstmt3."\n";
#				print $udbh->do($pstmt3);
#				}
#			}
#		elsif ($current eq 'child') {
#			my $pstmt2 = "select sku,relationship,parent from AMAZON_PID_UPCS where PID=$qtPID and PID!=SKU and MID=".int($MID);
#			#print $pstmt2."\n";
#			my $sth2 = $udbh->prepare($pstmt2);
#			$sth2->execute;
#			my $count = 0;
#			while (my ($child,$relationship,$parent) = $sth2->fetchrow) {
#				if ($relationship ne 'child' || $parent ne $pid) {
#					my $pstmt3 = "update AMAZON_PID_UPCS set relationship = 'child', parent = '".$pid."' where MID=$MID and sku='".$child."'";
#					print $pstmt3."\n";
#					$udbh->do($pstmt3);
#					}
#				$count++;
#				}
#			$sth2->finish;
#
#			my $relationship = 'base';
#			 
#			## has children
#			if ($count > 0) { $relationship = 'parent'; }
#			## check if its a virtual child (vs base)
#			elsif (ZOOVY::fetchproduct_attrib($USERNAME,$pid,'zoovy:grp_parent') ne '') {
#				print STDERR "$MID\t$pid\t$count\t$current\t$relationship\n";
#				my $pstmt4 = "update AMAZON_PID_UPCS set relationship='child' where pid = ".$udbh->quote($pid).
#							 " and MID=$MID";
#				print $ctr++." ".$pstmt4."\n";
#				$udbh->do($pstmt4);
#				}
#			elsif ($current ne $relationship) {
#				print STDERR "$MID\t$pid\t$count\t$current\t$relationship\n";
#				my $pstmt4 = "update AMAZON_PID_UPCS set relationship = '".$relationship."' where pid = ".$udbh->quote($pid).
#								 " and MID=$MID";
#				print $ctr++." ".$pstmt4."\n";
#				$udbh->do($pstmt4);
#				}
#			}
#		else {
#			die("Unknown current type: $current");
#			}
#		}
#	$sth->finish;
#	&DBINFO::db_zoovy_close();	
#	return();	
#	}			
#



##
## returns a hashref of amazon profiles for a given customer.
##
sub fetch_thesaurus {
	my ($USERNAME) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my %hash = ();

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select ID,NAME from AMAZON_THESAURUS where MID=$MID /* $USERNAME */";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($id,$name) = $sth->fetchrow() ) {
		$hash{$id} = $name;
		}
	$sth->finish();

	&DBINFO::db_user_close();
	return(\%hash);
	}

##
## returns an hashref of all possible timestamps.
## -- not used
#sub get_ts {
#	my ($USERNAME) = @_;
#
##| PRODUCTS_GMT      | int(10) unsigned      |      |     | 0                   |                |
##| PRODIMAGES_GMT    | int(10) unsigned      |      |     | 0                   |                |
##| PRICING_GMT       | int(10) unsigned      |      |     | 0                   |                |
##| INVENTORY_GMT     | int(10) unsigned      |      |     | 0                   |                |
##| RELATIONSHIPS_GMT | int(10) unsigned      |      |     | 0                   |                |
##| OVERRIDES_GMT     | int(10) unsigned      |      |     | 0                   |                |
##| ORDERACK_GMT      | int(10) unsigned      |      |     | 0                   |                |
##| ORDERFILL_GMT     | int(10) unsigned      |      |     | 0                   |                |
##| ORDERADJ_GMT      | int(10) unsigned      |      |     | 0                   |                |
##| ORDERSETTLE_GMT   | int(10) unsigned      |      |     | 0                   |                |
#
#	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#	my $pstmt = "select PRODUCTS_GMT,PRODIMAGES_GMT,PRICING_GMT,INVENTORY_GMT,RELATIONSHIPS_GMT,OVERRIDES_GMT,ORDERACK_GMT,ORDERFILL_GMT,ORDERADJ_GMT,ORDERSETTLE_GMT from AMAZON_FEEDS where MID=$MID /* $USERNAME */";
#	my $sth = $udbh->prepare($pstmt);
#	$sth->execute();
#	my $hashref = $sth->fetchrow_hashref();
#	$sth->finish();
#	
#	&DBINFO::db_user_close();
#	return($hashref);
#	}


##
## returns a list of amazon "approved" conditions
##
sub fetch_conditions {
	my ($USERNAME) = @_;
	my @ar = ('New','UsedLikeNew','UsedVeryGood','UsedGood','UsedAcceptable','CollectibleLikeNew','CollectibleVeryGood','CollectibleGood','CollectibleAcceptable','Refurbished','Club');
	return(\@ar);
	}


#
# inputs:
#	word string (separated by commas)
#  # of element in array to return
# 	max chars per line in array (0 if max unlimited and only one word per line)
# 	
# return array
sub node_split {
	my ($string, $line_num, $max_char, $split) = @_;
	my @return = ();
	my @keywords = ();

	## added split 2008-04-22 - patti
	## keywords can now be multiple words, ie its now split on comma's	
	if (defined $split && $split ne '') {
		@keywords = split(/$split/, $string);
		}
	else {
		@keywords = split(/[^\w\-]+/, $string);	# split on non-word characters. A-Z 0-9 _ -
		}

	if ($max_char > 0) {
		my @lines = ();
		foreach my $key (@keywords) {
			for (my $i = 0; $i <= $line_num; $i++) {
				# if length of line in array is less than max chars per line, 
				# add to the line, otherwise move on
				if (length($lines[$i])+length($key) < $max_char) {
					$lines[$i] .= "$key,";
					$i = $line_num+1;				
					} 
				}
			}
		# need to remove pesky comma
		foreach my $line (@lines){
			$line =~ s/,$//;
			push @return, $line;
			}
		}
	else {
		for (my $i=0; $i < $line_num; $i++) {
			$return[$i] = $keywords[$i];
			}
		}

	return(@return);
	}

###
# fetch_shippingmap
#
#  get param list of merchant defined mapping of Amazon ship
#		methods to Zoovy ship methods
#
# 	input: USERNAME
#	output: hashref of Amazon method to Zoovy method (code)
##
#sub fetch_shippingmap {
#	my ($USERNAME) = @_;
#	
#	my $MID = ZOOVY::resolve_mid($USERNAME);
#
#	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
#	my $pstmt = "select SHIPPING_MAP from AMAZON_FEEDS where MID=$MID /* $USERNAME */";
#	my $sth = $udbh->prepare($pstmt);
#	$sth->execute();
#	my $c = '';
#	my ($map) = $sth->fetchrow();
#	$sth->finish;
#	&DBINFO::db_user_close();
#
#	require ZTOOLKIT;
#	return(ZTOOLKIT::parseparams($map));
#	}



#####################################################################
## get pending reports
## called from ./amz_reports.pl create
##	( acknowledge order docs using "amz_reports.pl ack" )
##
## pass in old_docid if an older docid needs to be created
##	ack doesn't seem to make these docids unavailable(?)
## *************** MWS (BTW - looks like there is another call (diff results?) for MWS)
sub getReportRequests { 
	my ($userref,$docid,$msgtype,%options) = @_;


	my $ERROR = '';
	my $xml = undef;
	
	if ($docid == 0) {
		$ERROR = "AMAZON is fairly certain that docid 0 doesn't exist.";
		}

	my %action_params = ();
	## REPORTS REQUESTS
	if ($msgtype =~ /^_GET_(.*)_DATA_$/) {
		%action_params = (
			'Action' => 'GetReportRequestList',
			'ReportRequestIdList.Id.1' => $docid,
			'ReportTypeList.Type.1' => $msgtype,
			'ReportProcessingStatusList.Status.1' => '_DONE_',
			);
		}
	else {
		$ERROR = "Unknown msgtype sent to AMAZON3::getReportRequests: $msgtype docid: $docid USERNAME: $userref->{'USERNAME'}";	
		}

	## no need to POST to amz
	if ($ERROR ne '') {
		&ZOOVY::confess($userref->{'USERNAME'},"ERROR: ".$ERROR);	
		}
	
	elsif ($ERROR eq '') {	
		my ($request_url, $head, $agent) = &AMAZON3::prep_header($userref,\%action_params);
		my $request = HTTP::Request->new('POST',$request_url,$head);
		my $response = $agent->request($request);

		#print STDERR "RESPONSE: ".Dumper($response);

		## SUCCESS
		if ($response->is_success()) {
			$xml = $response->content();

			## write to tmp for Zoovy troubleshooting, rolled daily?
			my $FILENAME = "/tmp/amz-$userref->{'USERNAME'}-$docid-response.xml";
			open F, ">$FILENAME"; print F $xml; close F;

			## write to merchant's PRIVATE dir
			require LUSER::FILES;
			my ($lf) = LUSER::FILES->new($userref->{'USERNAME'},'app'=>'AMAZON');
			my $guid = undef;
			if (defined $lf) {
				($guid) = $lf->add(
					'*lm'=>$userref->{'*msgs'},
	  	  			file=>$FILENAME,
					title=>"Syndication Response AMAZON3: $docid ($msgtype)",
					type=>'AMZ',
  		 			overwrite=>1,
					EXPIRES_GMT=>time()+(86400*14),	## expire in 2 weeks
					createdby=>'*AMAZON',
					# unlink=>1,
					meta=>{'DSTCODE'=>'AMZ','PROFILE'=>"#$userref->{'PRT'}",'TYPE'=>'Response'},
					);
				}
			print "FILENAME: $FILENAME\n";

			}
		## ERRORED
		else {
			$ERROR = $response->status_line;
			my ($USERNAME) = $userref->{'USERNAME'};
			open F, ">>/tmp/amz-errors.$USERNAME.xml";
			use Data::Dumper; 
			print F "ERROR: $ERROR\nREQUEST: ".Dumper($request)."\nRESPONSE: ".Dumper($response)."USERNAME: $USERNAME\n\n";
			print STDERR "ERROR: $ERROR\nREQUEST: ".Dumper($request)."\nRESPONSE: ".Dumper($response)."USERNAME: $USERNAME\n\n";
			close F;

			&ZOOVY::confess($userref->{'USERNAME'},"ERROR: ".$response->status_line."\nREQUEST: $request\nRESPONSE: ".Dumper($response)."\n",justkidding=>1);
			}
		}

	return($ERROR,$xml);	

	}


##
##
##
sub fetch_catalogref {
	my ($product_amz_catalog) = @_;

	my $file = lc("/httpd/static/definitions/amz/amz.$product_amz_catalog.json");
	if ($product_amz_catalog eq '') {
		warn "catalog was blank!\n";
		return(undef);
		}
	elsif ($product_amz_catalog eq '-- Not Set --') {
		warn "Catalog was not set\n";
		return(undef);
		}
	elsif (-f $file) {
		## yay! json file exists
		my ($catalog, $subcat) = split(/\./, $product_amz_catalog, 2);
		$catalog = uc($catalog);
		$catalog =~ s/FOOD/GOURMET/;
		$catalog =~ s/^CE$/ELECTRONIX/;
		$catalog =~ s/JEWERLY/JEWELRY/;
		my $json = &File::Slurp::read_file($file);
		my $ref = JSON::XS::decode_json($json);
		#foreach my $f (@{$ref}) {
		#	if ($f->{'_pretty'} !~ /ProductType/) { $f->{'_order'} = $f->{'_pretty'} + 1000; }
		#	}

	my %subcat_pretty = (
		##MUSICALINSTRUMENTS
		 'BRASSANDWOODWINDINSTRUMENTS', 'BrassAndWoodwindInstruments',
		 'KEYBOARDINSTRUMENTS', 'KeyboardInstruments',
		 'PERCUSSIONINSTRUMENTS', 'PercussionInstruments',
		 'INSTRUMENTPARTSANDACCESSORIES', 'InstrumentPartsAndAccessories',
		 'STRINGEDINSTRUMENTS', 'StringedInstruments',
		 'GUITARS', 'Guitars',
		 'MISCWORLDINSTRUMENTS', 'MiscWorldInstruments',
		 'SOUNDANDRECORDINGEQUIPMENT', 'SoundAndRecordingEquipment',
		## HOME
		 'FURNITUREANDDECOR', 'FurnitureAndDecor',
		 'KITCHEN', 'Kitchen',
		 'OUTDOORLIVING', 'OutdoorLiving',
		 'BEDANDBATH', 'BedAndBath',
		 'SEEDSANDPLANTS', 'SeedsAndPlants',
		## JEWERLY
		 'WATCH', 'Watch',
		 'FASHIONEARRING', 'FashionEarring',
		 'FASHIONNECKLACEBRACELETANKLET', 'FashionNecklaceBraceletAnklet',
		 'FASHIONOTHER', 'FashionOther',
		 'FASHIONRING', 'FashionRing',
		 'FINEEARRING', 'FineEarring',
		 'FINENECKLACEBRACELETANKLET', 'FineNecklaceBraceletAnklet',
		 'FINEOTHER', 'FineOther',
		 'FINERING', 'FineRing',
		 'LOOSESTONE', 'LooseStone',
		## PETSUPPLY
		 'PETSUPPLIESMISC', 'PetSuppliesMisc',
		## ELECTRONIX
		 'PC', 'PC',
		 'PDA', 'PDA',
		 'CONSUMERELECTRONICS', 'ConsumerElectronics',
		## HEALTH
		 'HEALTHMISC', 'HealthMisc',
		## CAMERAPHOTO
		 'FILMCAMERA', 'FilmCamera',
		 'CAMCORDER', 'Camcorder',
		 'DIGITALCAMERA', 'DigitalCamera',
		 'BINOCULAR', 'Binocular',
       'SURVEILLANCESYSTEM', 'SurveillanceSystem',   
		 'TELESCOPE', 'Telescope',
		 'MICROSCOPE', 'Microscope',
		 'DARKROOM', 'Darkroom',
		 'LENS', 'Lens',
		 'LENSACCESSORY', 'LensAccessory',
		 'FILTER', 'Filter',
		 'FILM', 'Film',
		 'BAGCASE', 'BagCase',
		 'BLANKMEDIA', 'BlankMedia',
		 'PHOTOPAPER', 'PhotoPaper',
		 'CLEANER', 'Cleaner',
		 'FLASH', 'Flash',
		 'TRIPODSTAND', 'TripodStand',
		 'LIGHTING', 'Lighting',
		 'PROJECTION', 'Projection',
		 'PHOTOSTUDIO', 'PhotoStudio',
		 'LIGHTMETER', 'LightMeter',
		 'POWERSUPPLY', 'PowerSupply',
		 'OTHERACCESSORY', 'OtherAccessory',					
## WIRELESS
		 'WIRELESSACCESSORIES', 'WirelessAccessories',
		 'WIRELESSDOWNLOADS', 'WirelessDownloads',
## AUTOPART
		 'AUTOACCESSORYMISC', 'AutoAccessoryMisc',
## SOFTWARE
		 'SOFTWARE', 'Software',
		 'HANDHELDSOFTWAREDOWNLOADS', 'HandheldSoftwareDownloads',
		 'SOFTWAREGAMES', 'SoftwareGames',
		 'VIDEOGAMES', 'VideoGames',
		 'VIDEOGAMESACCESSORIES', 'VideoGamesAccessories',
		 'VIDEOGAMESHARDWARE', 'VideoGamesHardware',
## OFFICE
		 'OFFICEPRODUCTS', 'OfficeProducts',
		 'ARTSUPPLIES', 'ArtSupplies',
		 'EDUCATIONALSUPPLIES', 'EducationalSupplies',
## TOYSBABY
		 'TOYS', 'Toys',
		 'TOYSBABY', 'ToysBaby',
		 'BABYPRODUCTS', 'BabyProducts',
		 'TOYSANDGAMES', 'ToysAndGames',
## GOURMET
		 'GOURMETMISC', 'GourmetMisc' 
		);

		my $xmlsubcat = $subcat_pretty{$subcat};
		if ($xmlsubcat eq '') { 
			# warn "Did not match on subcat=$subcat";
			## andrews words: this is bollocks (it's not an error, it will almost certainly be overwritten by config element)
			##						unless he's missed shit.
			$xmlsubcat = $subcat; 
			}

		my %response = ('catalog'=>$catalog,'subcat'=>$subcat,'xmlsubcat'=>$xmlsubcat,'@fields'=>$ref);
		## NOTE: 'catalog', 'subcat',' 'xmlsubcat' are all legacy fields that *should* be overwritten by config element.
		##			but we really ought to test this before killing it.

		## copy any 'config' fields into the response
		foreach my $node (@{$ref}) {
			if ($node->{'type'} eq 'config') {
				foreach my $field (keys %{$node}) {
					$response{$field} = $node->{$field};
					}
				}
			}
	
		return(\%response);
		}
	else {
		warn "invalid product_amz_catalog passed: $product_amz_catalog\n";
		return(undef);
		}
	}




##
## 
##
sub fetch_thesaurus_detail {
	my ($userref) = @_;

	my %hash = ();

	my ($udbh) = &DBINFO::db_user_connect($userref->{'USERNAME'});
	my ($MID) = $userref->{'MID'};
	my $pstmt = "select * from AMAZON_THESAURUS where MID=$MID /* $userref->{'USERNAME'} */";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		$hash{$hashref->{'ID'}} = $hashref;		# don't use database id's this is fucking stupid. 5/27/11
		$hash{$hashref->{'NAME'}} = $hashref;
		$hash{$hashref->{'GUID'}} = $hashref;
		}
	$sth->finish();

	&DBINFO::db_user_close();
	return(\%hash);
	}




##
## AMAZON3::queue_xml
## Purpose:  adds an xml document to the upload queue.
##
#sub queue_xml {
#	my ($userref,$type,$bodyxml) = @_;
#
#	print Dumper($userref);
#
#	my ($udbh) = &DBINFO::db_user_connect($userref->{'USERNAME'});
#	my ($MID) = &ZOOVY::resolve_mid($userref->{'USERNAME'});
#	my ($pstmt) = &DBINFO::insert($udbh,'AMAZON_DOCS_QUEUE',{
#		USERNAME=>$userref->{'USERNAME'}, MID=>$MID, PRT=>$userref->{'PRT'},
#		DOCTYPE=>$type, DOCBODY=>$bodyxml, 
#		CREATED_GMT=>time()
#		},debug=>1+2,delayed=>1);
#	$udbh->do($pstmt);
#	&DBINFO::db_user_close();
#	return();	
#	}





##
##
## pass this the <Message>....</Message> document.
##
## ***************** this sub does NOT change for MWS
#sub addenvelope {
#	my ($userref,$msgtype,$msgsxml) = @_;
#
#	my ($USERNAME) = $userref->{'USERNAME'};
#
#	if ($USERNAME eq '') { warn 'No username passed to AMAZON3::addenvelope - return undef'; return(undef); }
#	elsif ($msgtype eq '') { warn 'No msgtype passed to AMAZON3::addenvelope - return undef'; return(undef); }
#	elsif ($msgsxml eq '') { warn 'Msgsxml passed to AMAZON3::addenvelope - return undef'; return(undef); }
#	
#	my $TOKEN = $userref->{'AMAZON_TOKEN'};
#	#if ($TOKEN =~ /^Q_/) { $::PRODUCTION = 0; }
#
#	my $xml = qq~<?xml version="1.0" ?>
#<AmazonEnvelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="amzn-envelope.xsd">
#<Header>
#	<DocumentVersion>1.01</DocumentVersion>
#	<MerchantIdentifier>$TOKEN</MerchantIdentifier>
#</Header>
#<MessageType>$msgtype</MessageType> 
#$msgsxml
#</AmazonEnvelope>
#~;
#
#	return($xml);
#	}

##
## added for MWS support
## - creates encrypted url and header for MWS POST
##
## input:
##		userref => merchant credentials
##		action_params => include all info needed to send appropriate query/XML to MWS
##			XML: product/price/relationship/inv/etc xml for SubmitFeed
##			Action: SubmitFeed, GetFeedSubmissionResult, RequestReport, GetReportRequestList, GetReport, etc
##			
##			example params:
##					
sub prep_header {
	my ($userref, $action_paramref) = @_;
	my $XML = $action_paramref->{'XML'};
	
	## 1. define credentials
	my $USERNAME = $userref->{'USERNAME'};
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $AMZ_TOKEN = $userref->{'AMAZON_TOKEN'};
	my $AMZ_MARKETPLACEID = $userref->{'AMAZON_MARKETPLACEID'};
	my $AMZ_MERCHANTID = $userref->{'AMAZON_MERCHANTID'};
	my $MWS_AUTH_TOKEN = $userref->{'MWS_AUTH_TOKEN'};

	my ($CFG) = CFG->new();
	my $host = $CFG->get("amazon_mws","host");
	my $sk = $CFG->get('amazon_mws',"sk");
	my $awskey = $CFG->get('amazon_mws',"aws_key");

	my $TS = AMAZON3::amztime(time());
	my $md5 = &Digest::MD5::md5_base64($XML);
	$md5 .= "==";		## this is officially duct-tape, run w/o and md5's dont match

	my %params = (
		'AWSAccessKeyId'=>$awskey,
		'MWSAuthToken'=>$MWS_AUTH_TOKEN,
		'Marketplace'=>$AMZ_MARKETPLACEID,
		'Merchant'=>$AMZ_MERCHANTID,
		'SignatureVersion'=>2,
		'SignatureMethod'=>'HmacSHA1',
		'Timestamp'=>$TS,
		'Version' => '2009-01-01',
		);

	## populate params w/actions from push_xml
	## ie Action, FeedType, ReportId, FeedSubmissionId, ReportRequestIdList.Id.1, ReportRequestIdList.Id.2
	foreach my $action_param (keys %{$action_paramref}) {
		if ($action_param ne 'XML') {
			$params{$action_param} = $action_paramref->{$action_param};
			}
		}

	## 2. create header
	my $head = HTTP::Headers->new();
	$head->header('Content-Type'=>'text/xml');
	$head->header('Host',$host);	
	$head->header('Content-MD5',$md5);

	## 3. create query string
	my $query_string = '';
	foreach my $k (sort keys %params) {
		$query_string .= URI::Escape::uri_escape_utf8($k).'='.URI::Escape::uri_escape_utf8($params{$k}).'&';
		}
	$query_string = substr($query_string,0,-1);	# strip trailing &

	#print "PARAMS\n".Dumper(\%params)."\nQUERY_STRING:\n".$query_string."\n";


	## 4. create string to sign
	my $request_uri = "/";
	my $url = "https://mws.amazonaws.com/";

	my $data = 'POST';
	$data .= "\n";
	$data .= $host;
	$data .= "\n";
	$data .= $request_uri;
	$data .= "\n";
	$data .= $query_string;
	

	## 5. create digest by calculating HMAC, convert to base64
	my $digest = Digest::HMAC_SHA1::hmac_sha1($data,$sk);
	$digest = MIME::Base64::encode_base64($digest);
	$digest =~ s/[\n\r]+//gs;

	## 6. POST contents to MWS
	my %sig = ('Signature'=>$digest);
	my $request_url = $url."?".$query_string."&".&AMAZON3::build_mws_params(\%sig);

	## 7. Create User-Agent
	my $agent = new LWP::UserAgent;
	$agent->agent('Zoovy/just-testing1 (Language=Perl/v5.8.6)');

	return($request_url, $head, $agent);	
	}


##
## added for MWS support
## - creates encrypted url and header for MWS POST
##
## input:
##		userref => merchant credentials
##		action_params => include all info needed to send appropriate query/XML to MWS
##			XML: product/price/relationship/inv/etc xml for SubmitFeed
##			Action: SubmitFeed, GetFeedSubmissionResult, RequestReport, GetReportRequestList, GetReport, etc
##			
##			example params:
##					
sub prep_header2 {
	my ($userref, $action_paramref) = @_;
	my $XML = $action_paramref->{'XML'};
	
	## 1. define credentials
	my $USERNAME = $userref->{'USERNAME'};
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $AMZ_TOKEN = $userref->{'AMAZON_TOKEN'};
	my $AMZ_MARKETPLACEID = $userref->{'AMAZON_MARKETPLACEID'};
	my $AMZ_MERCHANTID = $userref->{'AMAZON_MERCHANTID'};
	my $MWS_AUTH_TOKEN = $userref->{'MWS_AUTH_TOKEN'};

	my ($CFG) = CFG->new();
	my $host = $CFG->get("amazon_mws","host");
	my $sk = $CFG->get('amazon_mws',"sk");
	my $awskey = $CFG->get('amazon_mws',"aws_key");

	my $TS = AMAZON3::amztime(time());
	my $md5 = &Digest::MD5::md5_base64($XML);
	$md5 .= "==";		## this is officially duct-tape, run w/o and md5's dont match

	my %params = (
		'AWSAccessKeyId'=>$awskey,
		'MWSAuthToken'=>$MWS_AUTH_TOKEN,
		'Marketplace'=>$AMZ_MARKETPLACEID,
		'Merchant'=>$AMZ_MERCHANTID,
		'SignatureVersion'=>2,
		'SignatureMethod'=>'HmacSHA1',
		'Timestamp'=>$TS,
		'Version' => '2009-01-01',
		);

	## populate params w/actions from push_xml
	## ie Action, FeedType, ReportId, FeedSubmissionId, ReportRequestIdList.Id.1, ReportRequestIdList.Id.2
	foreach my $action_param (keys %{$action_paramref}) {
		if ($action_param ne 'XML') {
			$params{$action_param} = $action_paramref->{$action_param};
			}
		}

	## 2. create header
	my $head = HTTP::Headers->new();
	$head->header('Content-Type'=>'text/xml');
	$head->header('Host',$host);	
	$head->header('Content-MD5',$md5);

	## 3. create query string
	my $query_string = '';
	foreach my $k (sort keys %params) {
		$query_string .= URI::Escape::uri_escape_utf8($k).'='.URI::Escape::uri_escape_utf8($params{$k}).'&';
		}
	$query_string = substr($query_string,0,-1);	# strip trailing &

	#print "PARAMS\n".Dumper(\%params)."\nQUERY_STRING:\n".$query_string."\n";


	## 4. create string to sign
	my $request_uri = "/Products/2011-10-01";
	my $url = "https://mws.amazonaws.com";

	my $data = 'POST';
	$data .= "\n";
	$data .= $host;
	$data .= "\n";
	$data .= $request_uri;
	$data .= "\n";
	$data .= $query_string;
	

	## 5. create digest by calculating HMAC, convert to base64
	my $digest = Digest::HMAC_SHA1::hmac_sha1($data,$sk);
	$digest = MIME::Base64::encode_base64($digest);
	$digest =~ s/[\n\r]+//gs;

	## 6. POST contents to MWS
	my %sig = ('Signature'=>$digest);
	my $request_url = $url.$request_uri."?".$query_string."&".&AMAZON3::build_mws_params(\%sig);

	## 7. Create User-Agent
	my $agent = new LWP::UserAgent;
	$agent->agent('Zoovy/just-testing1 (Language=Perl/v5.8.6)');

	return($request_url, $head, $agent);	
	}



##
## basically a wrapper around postDocument
##		example:
##		ORDER::AMAZON -- push_xml($USERNAME,$PRT,$outackxml,'OrderAcknowledgement','_POST_ORDER_ACKNOWLEDGEMENT_DATA_');
##
## ************** major MWS change
sub push_xml {
	my ($userref,$xmlbody,$type,$lm) = @_;


	my $USERNAME = $userref->{'USERNAME'};
	if (not defined $lm) { $lm = LISTING::MSGS->new($USERNAME); }
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	if ($xmlbody eq '') {
		$lm->pooshmsg("ISE|+blank xml handed to push_xml");
		}

	my $msgtype = undef;
	if (not defined $AMAZON3::POST_TYPES{$type}) {
		$lm->pooshmsg("ISE|+INVALID POST_TYPE ($type) -- CANNOT SEND DOCUMENT");
		}
	else {
		$msgtype = $AMAZON3::POST_TYPES{$type};
		}

	if (not defined $msgtype) {
		## this line should never be reached
		$lm->pooshmsg("ISE|+undefined msgtype: $type requested to push_xml");
		}
	elsif ($USERNAME eq '') { 
		$lm->pooshmsg("ISE|+No username passed to AMAZON3::addenvelope");
		}
	elsif ($msgtype eq '') { 
		$lm->pooshmsg("ISE|+No msgtype passed to AMAZON3::addenvelope");
		}
	elsif ($xmlbody eq '') { 
		$lm->pooshmsg("ISE|+xmlbody passed to AMAZON3::addenvelope");
		}
	

	my $xml = undef;
	if ($lm->can_proceed()) {
		my $TOKEN = $userref->{'AMAZON_TOKEN'};
	#if ($TOKEN =~ /^Q_/) { $::PRODUCTION = 0; }

		$xml = qq~<?xml version="1.0" ?>
<AmazonEnvelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="amzn-envelope.xsd">
<Header>
	<DocumentVersion>1.01</DocumentVersion>
	<MerchantIdentifier>$TOKEN</MerchantIdentifier>
</Header>
<MessageType>$type</MessageType> 
$xmlbody
</AmazonEnvelope>~;
		$xml =~ s/^<\?(.*)\?>$//mg;	# what is this?, looks like it strips <?xml ?> directives.
		}

	## Amazon's servers aren't handling the load well
	## 	some requests are erroring even though the credentials are valid
	## 	-- seeing if a retry works
	my $docid = 0;
	my ($attempts) = 0;

	my %action_params = (
		'Action' => 'SubmitFeed',
		'FeedType' => $msgtype,	
		'XML' => $xml,
		);

	my ($request_url, $head, $agent) = &AMAZON3::prep_header($userref,\%action_params);
	my $FILENAME = "/tmp/amz-$USERNAME-0.xml";

	##
	## go through until we have a critical error, we try 5 times, or we get a docid.
	##
	my $error = undef;
	if (not $lm->can_proceed()) { $error = "PREFLIGHT-ERROR"; }

	while (($docid <= 0) && (not defined $error)) {
		#($docid,$err) = &AMAZON3::postDocument($userref,$msgtype,$xml);
		# my ($userref,$msgtype,$xmldoc) = @_;

		## attempts will be incremented if this is a retry.
		if ($attempts>0) { sleep(1); }

		my $request = HTTP::Request->new('POST', $request_url, $head, $xml);
		my $response = $agent->request($request);

		$docid = -1;
		if ($response->is_success()) {
			$docid = 0;
			##<?xml version="1.0"?><SubmitFeedResponse xmlns="http://mws.amazonaws.com/doc/2009-01-01/"><SubmitFeedResult><FeedSubmissionInfo><FeedSubmissionId>
			##3133506888</FeedSubmissionId><FeedType>_POST_PRODUCT_PRICING_DATA_</FeedType><SubmittedDate>2010-05-03T23:18:15+00:00</SubmittedDate>
			##<FeedProcessingStatus>_SUBMITTED_</FeedProcessingStatus></FeedSubmissionInfo></SubmitFeedResult><ResponseMetadata><RequestId>
			##48ce0e93-b488-47b5-9572-c0d571de7b12</RequestId></ResponseMetadata></SubmitFeedResponse>
			if ($response->content() =~ /\<FeedSubmissionId\>([\d]+)\<\/FeedSubmissionId\>/s) { 
				$docid = $1; 
				$FILENAME = "/tmp/amz-$USERNAME-$docid-request.xml";				
				}
			open F, ">$FILENAME"; print F $xml; close F;
			$error = undef;	# no need to leave error set.
			}
		elsif ($response->code() == 401) {
			## '401 Authorization Required'
			## usually means a password is invalid
			my $VERB = ($attempts>1)?'RETRY':'FAIL';
			$error = "$VERB|+Could not login to Amazon Seller Central (HTTP 401)";
			}
		elsif ($response->code() == 403) {
			## this is a new MWS Error
			## only some merchants are getting it
			# 403 Forbidden Access to MWS
			my $VERB = ($attempts>1)?'RETRY':'FAIL';
			$error = "$VERB|+403 Forbidden Access to MWS - Amazon";
			}
		elsif ($response->code() == 404) {
			# '404 Page not found'
			$error = "FAIL|+API returned HTTP 404 (Amazon is down)";
			}
		elsif ($response->code() == 500) {
			# '500 Internal Server Error'
			$error = "FAIL|+Internal error 500 in Amazon Seller Central Account";
			}
		elsif ($response->code() == 502) {
			# '502 Bad Gateway'
			$error = "FAIL|+Internal gateway error HTTP 502 (Amazon is down)";
			}
		elsif ($response->code() == 503) {
			# '503 Service Unavailable'
			$error = "FAIL|+Service Unavailable Error HTTP 503 (Amazon is down)";
			}
		else {
			$error = "FAIL|+API Response: ".$response->status_line();
			open F, ">>/tmp/amz-errors.$USERNAME.xml";
			print STDERR "LOGGING $error to /tmp/amz-errors.$USERNAME.xml\n";
			use Data::Dumper; 
			print F time()."push_xml: $msgtype\nATTEMPTS: $attempts\nERROR: $error\nREQUEST: ".Dumper($request)."\nRESPONSE: ".Dumper($response)."USERNAME: $USERNAME\n\n";
			close F;
			}

		if (not defined $error) {
			## SUCCESS!
			} 
		elsif ($error =~ /^RETRY\|/) {
			## RETRY
			$attempts++;
			if ($attempts>2) { sleep(5); } 
			$error = undef; 		## this is how we tell the while loop to rinse and repeat.
			}
		else {
			## FAILURE
			}
		}

	if ($docid>0) {
		## SUCCESS! adding write of DOCID to PRIVATE FILES
		require LUSER::FILES;
		my ($lf) = LUSER::FILES->new($USERNAME, 'app'=>'AMAZON');
		my $guid = undef;
		if (defined $lf) {
			($guid) = $lf->add(
				'*lm'=>$userref->{'*msgs'},
  	  			file=>$FILENAME,
				title=>"Syndication Feed AMAZON: $docid ($msgtype)",
				type=>'AMZ',
  		 		overwrite=>1,
				EXPIRES_GMT=>time()+(86400*14),	## expire in a week
				createdby=>'*AMAZON',
				unlink=>1,
				meta=>{'DSTCODE'=>'AMZ','PROFILE'=>"#$userref->{'PRT'}",'TYPE'=>$type},
				);
			}

		my ($udbh) = &DBINFO::db_user_connect($userref->{'USERNAME'});
		my ($pstmt) = &DBINFO::insert($udbh,'AMAZON_DOCS',{
			'USERNAME'=>$USERNAME, 'MID'=>$MID,	'PRT'=>$userref->{'PRT'},
			'DOCTYPE'=>$msgtype, 'DOCID'=>$docid, 'CREATED_GMT'=>time() 
			},sql=>1,verb=>'insert');
		#my $qtDOCTYPE = $udbh->quote($msgtype);
		#my $qtUSERNAME = $udbh->quote($USERNAME);
		#my ($PRT) = $userref->{'PRT'};
		#my $pstmt = "insert into AMAZON_DOCS (USERNAME,MID,PRT,DOCTYPE,DOCID,CREATED_GMT) values ($qtUSERNAME,$MID,$PRT,$qtDOCTYPE,$docid,".time().")";
		print STDERR $pstmt."\n";
		$udbh->do($pstmt);
		&DBINFO::db_user_close();
		$lm->pooshmsg("SUCCESS|+Sent $msgtype response-docid:$docid");
		}
	elsif ($error =~ /^FAILOK\|(.*?)$/) {
		my ($msg) = $1;
		$lm->pooshmsg("FAIL|+$msg");
		&TODO::easylog($userref->{'USERNAME'},
			title=>"Amazon postDoc Error: $1",
			detail=>"$xml",
			class=>"ERROR",
			priority=>1
			);
		}
	elsif ($error =~ /^FAIL\|(.*?)$/) {
		my ($errmsg) = ($1);
		$lm->pooshmsg($error);
		&ZOOVY::confess($userref->{'USERNAME'},"AMAZON $error\nAMZ_TOKEN:".$userref->{'AMZ_TOKEN'}."\nPRT:$userref->{'PRT'}\nDOCID:$docid\nMSG:$msgtype-$errmsg\nSRC:postDoc\nxml: $xml");
		}
	else {
		## (this line should never be reached)
		$lm->pooshmsg("ISE|+Unknown response '$error' docid:$docid");
		}

	return($docid, $error, $lm);
	}

##
## Converts a hashref to URI params (returns a string)
## 	note: minimal defaults to 0 
##		note: minimal of 1 means do not escape < > or / in data.
## (used for push_xml, added for MWS functionality)
##
sub build_mws_params {	
	my ($hashref,$minimal) = @_;

	if (not defined $minimal) { $minimal = 0; }	
	my $string = '';

	foreach my $k (sort keys %{$hashref}) {
		foreach my $ch (split(//,$k)) {
			# print "ORD: ".ord($ch)."\n";
			if ($ch eq ' ') { $string .= '%20'; }
			elsif ($ch =~ /^[A-Za-z0-9\-\_\.]$/o) { $string .= $ch; }
			elsif ($ch =~ /\~/) { $string .= "%7E"; }
			else { $string .= '%'.sprintf("%02x",ord($ch));  }
			}
		$string .= '=';
		foreach my $ch (split(//,$hashref->{$k})) {
			if ($ch eq ' ') { $string .= '%20'; }
			elsif ($ch =~ /^[A-Za-z0-9\-\_\.\~]$/o) { $string .= $ch; }
			else { $string .= '%'.sprintf("%02x",ord($ch));  }
			}
		$string .= '&';
		}
	chop($string);
	return($string);
	}



## changed on 2009-04-02, addition of Z to indicate UTC time
## input: unix timestamp
sub amztime {
	my ($ts) = @_;
	#return(strftime("%Y-%m-%dT%H:%M:%S",localtime($ts)));
	## GMTIME IS WHAT SHOULD BE USED IF THE TZ ENDS IN A "Z"
	return(POSIX::strftime("%Y-%m-%dT%H:%M:%S"."Z",gmtime($ts)));
	}



##############################################################
## amztime looks like 2005-12-14T10:56:10
## need to return GMT
sub amzdate_to_gmt {
	my ($ts) = @_;
	$ts =~ s/T/ /;	
	my $gmt = &ZTOOLKIT::mysql_to_unixtime($ts);
	return($gmt);
	}	

####
## PIDsref => array ref of PIDs to check
##
## sums inv for all children
##
## returns hash ref of instock PIDs with their associated instock inventory
## and the PIDs that are out of stock
###
## this *REALLY* should be moved into INVENTORY::
##
#sub check_prod_inv {
#	my ($PIDsref, $USERNAME) = @_;
#	
#	die();
##	return(\%instockPIDs, \@outofstock);
#	}




## fetch merchantinfo
## optionref
## USERNAME
## FEED_PERMISSIONS (SYN) => 	0 - merchant no longer syndicating (or cancelled)
## 									1 - product syn
##							  			4 - just orders 
##
##	need to add more PRT support to merchantref 
## 
## added AMAZON_MARKETPLACEID for MWS functionality
sub fetch_userprt {
	my ($USERNAME,$PRT) = @_;

	if (not defined $PRT) {
		my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
		if (not defined $gref->{'amz_prt'}) {
			warn "internal data error - globalref->{'amz_prt'} is not set in fetch_userprt\n";
			}
		$PRT = int($gref->{'amz_prt'});	# defaults to zero?!
		}

#	my ($webdbref) = ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
#	my %USER = ();
#	$USER{'PRT'} = $PRT;
#	$USER{'USERNAME'} = $USERNAME;
#	$USER{'MID'} = &ZOOVY::resolve_mid($USERNAME);
#	$USER{'PASSWORD'} = $webdbref->{'amz_password'};
# 	$USER{'USERID'} = $webdbref->{'amz_userid'};
# 	$USER{'AMAZON_TOKEN'} = $webdbref->{'amz_merchanttoken'};
#	$USER{'AMAZON_MERCHANT'} = $webdbref->{'amz_merchantname'};			
#	$USER{'AMAZON_MERCHANT'} =~ s/\&/and/g;	# no idea why we do this.

#	my $amz_tokenref = ZTOOLKIT::parseparams($webdbref->{'amz_token'});
#	$USER{'AMAZON_MWSTOKEN'} = $webdbref->{'amz_token'};

#	# The Marketplace ID is the logical location a seller's online business is registered in. (per amz)
#	## required for MWS
#	$USER{'AMAZON_MARKETPLACEID'} = $amz_tokenref->{'marketplaceId'}; 
#	$USER{'AMAZON_MERCHANTID'} = $amz_tokenref->{'merchantId'};			

	my %USER = ();
	my ($so) = SYNDICATION->new($USERNAME,'AMZ','PRT'=>$PRT,'type'=>'x');
	$USER{'PRT'} = $PRT;
	$USER{'USERNAME'} = $USERNAME;
	$USER{'MID'} = &ZOOVY::resolve_mid($USERNAME);
	$USER{'PASSWORD'} = $so->get('.amz_password');						## seller central password 
	$USER{'USERID'} = $so->get('.amz_userid');							## seller central login id
	$USER{'AMAZON_TOKEN'} = $so->get('.amz_merchanttoken');			## obtained from the seller central account.
	$USER{'AMAZON_MERCHANT'} = $so->get('.amz_merchantname');		## plaintext company name (obtained from seller central)

	## $USER{'AMAZON_MWSTOKEN'} = $so->get('.amz_token');					## ('.amz_token',sprintf("marketplaceId=%s&merchantId=%s",$MARKETPLACE_ID,$MERCHANT_ID)
	my $amz_tokenref = ZTOOLKIT::parseparams( $so->get('.amz_token') );		## deprecated field: ('.amz_token',sprintf("marketplaceId=%s&merchantId=%s",$MARKETPLACE_ID,$MERCHANT_ID)
	# The Marketplace ID is the logical location a seller's online business is registered in. (per amz)
	## required for MWS
	$USER{'AMAZON_MARKETPLACEID'} = $so->get('.amz_marketplaceid') || $amz_tokenref->{'marketplaceId'}; 		## us seller central marketplace id
	$USER{'AMAZON_MERCHANTID'} = $so->get('.amz_merchantid') || $amz_tokenref->{'merchantId'};					## 
	$USER{'MWS_AUTH_TOKEN'} = $so->get('.mwsauthtoken');					## required as of 04/2015

	## afaik: these are not currently used, but they are the mws public/secret keys
	$USER{'AMAZON_MWS_ACCESS'} = $so->get('.amz_accesskey');
	$USER{'AMAZON_MWS_SECRET'} = $so->get('.amz_secretkey');

	return(\%USER);
	}






##
## a generic logging function
##
## MSG=>SEVERITY|msg
##	FATAL=>1
##		terminates feed processing, sets pretty "easylog" message
##
#sub zlog {
#	my ($userref,%options) = @_;
#
#	if (defined $options{'ERROR'}) {
#		$options{'MSG'} = "ERROR|$options{'ERROR'}";
#		}
#
#	my @cols = ();
#	open F, ">>/tmp/amazon-zlog-$userref->{'USERNAME'}.log";
#	print F Dumper(\%options)."\n";;
#	close F;
#
#	## SKU
#	## RESULT  (FAIL/GOOD/PASS)|reason
#	## DOCTYPE=>
#	print Dumper(\%options);
#	return();
#	}





#######################################################################
##
## msgtype could be:
##		_GET_ORDERS_DATA_, _GET_AMAZON_FULFILLED_SHIPMENTS_DATA_, _GET_PAYMENT_SETTLEMENT_DATA_ 
## 
## changed for MWS functionality
sub getDocumentPending {
	my ($userref,$msgtype) = @_;

	my %action_params = (
		'Action' => 'GetReportList',
		'ReportTypeList.Type.1' => $msgtype,
		'Acknowledged' => 'false',
		);

	my ($request_url, $head, $agent) = &AMAZON3::prep_header($userref,\%action_params);
	my $request = HTTP::Request->new('POST',$request_url,$head);
	my $response = $agent->request($request);

	use Data::Dumper; 
	print "REQUEST: ".Dumper($request)." RESPONSE:".Dumper($response);

	my @docs = ();
	my $ERROR = undef;
	if (not $response->is_success()) {
		$ERROR = $response->status_line;
		}
	else {
		print "\n\n\n\n ************** CONTENT".Dumper($response->content());
		my $p = new XML::Parser(Style=>'EasyTree');
		my $tree=$p->parse($response->content());
		print "\n\n\n\n ************** TREE".Dumper($tree);
		foreach my $node (@{$tree->[0]->{'content'}}) {
			next if ($node->{'type'} eq 't');
			#### changed on 10-04-2010 - patti
			####	code was written incorrectly, was only returning one DOCID
			#my $info = &XMLTOOLS::XMLcollapse($node->{'content'});
			#print Dumper($info);
			#if ($info->{'ReportInfo.ReportId'} ne '') {
			#	push @docs, $info->{'ReportInfo.ReportId'};	
			#	}
	
			foreach my $subnode (@{$node->{'content'}}) {
				next if ($subnode->{'type'} eq 't');
				my $info = &XMLTOOLS::XMLcollapse($subnode->{'content'});
				print "INFO: ".Dumper($info);
				if ($info->{'ReportId'} ne '') {
					push @docs, $info->{'ReportId'};	
					}
				}
			}
		}

	if (defined $ERROR) {
		my ($USERNAME) = $userref->{'USERNAME'};
		open F, ">>/tmp/amz-errors.$USERNAME.xml";
		use Data::Dumper; 
		print F `date`."ERROR: $ERROR\nREQUEST: ".Dumper($request)."\nRESPONSE: ".Dumper($response)."USERNAME: $userref->{'USERNAME'}\n\n";
		close F;
		return($ERROR);
		}

	return(\@docs);	
	}

###################################################################### 
##
## request report
##
##	this is used to create reports: _GET_AMAZON_FULFILLED_SHIPMENTS_DATA_ 
##
## note: this sub is not needed to create _GET_ORDERS_DATA_ (automatically scheduled every 15min) reports
## 	or Settlement Reports (every month??)
##
## http://mws.amazon.com/docs/devGuide/index.html?RequestReport.html
##
sub requestReport {
	my ($userref, $report_type, $start_date, $end_date) = @_;
	
	my %action_params = (
		'Action' => 'RequestReport',
		'ReportType' => $report_type,
		'StartDate' => AMAZON3::amztime($start_date),
		'EndDate' => AMAZON3::amztime($end_date),
		);

	my ($request_url, $head, $agent) = &AMAZON3::prep_header($userref,\%action_params);
	my $request = HTTP::Request->new('POST',$request_url,$head);
	my $response = $agent->request($request);

	use Data::Dumper; 
	print "REQUEST: ".Dumper($request)." RESPONSE:".Dumper($response);

	my $request_reportid = '';
	my $ERROR = undef;
	if (not $response->is_success()) {
		$ERROR = $response->status_line;
		}
	else {
		my $p = new XML::Parser(Style=>'EasyTree');
		my $tree=$p->parse($response->content());

		## this shouldnt be a loop, only one node returned...
		foreach my $node (@{$tree->[0]->{'content'}}) {
			my $info = &XMLTOOLS::XMLcollapse($node->{'content'});
			print STDERR Dumper($info);
			if ($info->{'ReportRequestInfo.ReportRequestId'} ne '') {
				$request_reportid = $info->{'ReportRequestInfo.ReportRequestId'};	
				}
			}
		}

	## 
	if ($request_reportid eq '') {
		$ERROR = "request reportid not returned";
		$request_reportid = 0;
		}

	if (defined $ERROR) {
		my ($USERNAME) = $userref->{'USERNAME'};
		open F, ">>/tmp/amz-errors.$USERNAME.xml";
		print F `date`."ERROR: $ERROR\nREQUEST: ".Dumper($request)."\nRESPONSE: ".Dumper($response)."USERNAME: $userref->{'USERNAME'}\n\n";
		close F;
		}

	return($request_reportid,$ERROR);	
	}




#######################################################################
##
##	docsref is an arrayref of docid's. (not a hashref or anything fancy)
##
## changed for MWS functionality
sub postDocumentAck {
	my ($userref,$docsref) = @_;

	my $ERROR = '';

	my %action_params = (
		'Action' => 'UpdateReportAcknowledgements',
		);

	my $n = 1;
	foreach my $docid (@{$docsref}) {
		my $list_id = "ReportIdList.Id.".$n++; 
		$action_params{$list_id} = $docid;
		}

	my ($request_url, $head, $agent) = &AMAZON3::prep_header($userref,\%action_params);
	my $request = HTTP::Request->new('POST',$request_url,$head);
	my $response = $agent->request($request);

	if ($response->is_success()) {
		}
	else {
		my $USERNAME = $userref->{'USERNAME'};
		$ERROR = $response->status_line;
		open F, ">>/tmp/amz-errors.$USERNAME.xml";
		use Data::Dumper; 
		print F "ERROR: $ERROR\nREQUEST: ".Dumper($request)."\nRESPONSE: ".Dumper($response)."USERNAME: $USERNAME\n\n";
		close F;
		}

	return($ERROR);	
	}


#######################################################################
##
## if the docid's Processing Status is > 0 (from getDocumentPS), ie been processed
## get the results back w/getDocument
##
## GetFeedSubmissionResult (ie what/if any errors or warnings were returned)
##	GetReport (ie contents of report, can be XML or tab-delimited data,
## 	depending of the type of report requested)
##
## changed for MWS functionality
sub getDocument {
	my ($userref,$docid,$msgtype,$attempt) = @_;
	
	$attempt++;
	my $ERROR = undef;
	my $xml = undef;
	
	if ($docid == 0) {
		$ERROR = "AMAZON is fairly certain that docid 0 doesn't exist.";
		}

	my %action_params = ();
	## REPORTS
	if ($msgtype =~ /^_GET_(.*)_DATA_$/) {
		%action_params = (
			'Action' => 'GetReport',
			'ReportId' => $docid,
			);
		}
	## FEED SUBMISSIONS
	elsif ($msgtype =~ /^_POST_(.*)_DATA_$/) {
		%action_params = (
			'Action' => 'GetFeedSubmissionResult',
			'FeedSubmissionId' => $docid,
			);
		}
	else {
		$ERROR = "Unknown msgtype sent to AMAZON3::getDocument: $msgtype docid: $docid USERNAME: $userref->{'USERNAME'}";	
		}

	## no need to POST to amz
	if ($ERROR ne '') {
		&ZOOVY::confess($userref->{'USERNAME'},"ERROR: ".$ERROR);	
		}

	while ( (not defined $xml) && (not defined $ERROR) ) {
		my ($request_url, $head, $agent) = &AMAZON3::prep_header($userref,\%action_params);
		my $request = HTTP::Request->new('POST',$request_url,$head);
		my $response = $agent->request($request);

		#print STDERR "RESPONSE: ".Dumper($response);

		## SUCCESS
		if ($response->is_success()) {
			$xml = $response->content();

			## write to tmp for Zoovy troubleshooting, rolled daily?
			my $FILENAME = "/tmp/amz-mws-response-$docid.xml";
			open F, ">$FILENAME"; print F $xml; close F;

			## write to merchant's PRIVATE dir
			require LUSER::FILES;
			my ($lf) = LUSER::FILES->new($userref->{'USERNAME'}, 'app'=>'AMAZON');
			my $guid = undef;
			if (defined $lf) {
				($guid) = $lf->add(
					'*lm'=>$userref->{'*msgs'},
	  	  			file=>$FILENAME,
					title=>"Syndication Response AMAZON3: $docid ($msgtype)",
					type=>'AMZ',
  		 			overwrite=>1,
					EXPIRES_GMT=>time()+(86400*7),	## expire in a week
					createdby=>'*AMAZON',
					# unlink=>1,
					meta=>{'DSTCODE'=>'AMZ','PROFILE'=>"#$userref->{'PRT'}"},
					);
				}
			print "FILENAME: $FILENAME\n";
			}
		## ERRORED
		elsif (($response->code() == 500) && ($attempt<2)) {
			## okay 500 errors are 'normal' for Amazon, so we'll build in an automatic retry
			## the message from amazon literally says 'Please try again' so we'll do it automatically.
			$ERROR = undef;	 # try again!
			}
		else {
			$ERROR = $response->status_line;
			my ($USERNAME) = $userref->{'USERNAME'};
			open F, ">>/tmp/amz-errors.$USERNAME.xml";
			use Data::Dumper; 
			print F "ERROR: $ERROR\nREQUEST: ".Dumper($request)."\nRESPONSE: ".Dumper($response)."USERNAME: $USERNAME\n\n";
			print STDERR "ERROR: $ERROR\nREQUEST: ".Dumper($request)."\nRESPONSE: ".Dumper($response)."USERNAME: $USERNAME\n\n";
			close F;	
			&ZOOVY::confess($userref->{'USERNAME'},"ATTEMPTS: $attempt\nERROR: ".$response->status_line."\nREQUEST: $request\nRESPONSE: ".Dumper($response)."\n",justkidding=>1);
			}
		
		##
		## SANITY: at this point if either $xml or $ERROR are set, we're going to exit, otherwise
		##				we'll run the loop again!
		##
		}

	if ($ERROR ne '') {
		}
	elsif ($xml eq '') {
		$ERROR = "Got zero byte response from AMAZON3::getReadyDocument";
		}
	elsif ($xml =~ /<ResultMessageCode>5006<\/ResultMessageCode>/) {
		# for error 5006 amazon sends us badly formatted xml, so we need to fix that shit or the parse_string() will crash
		#
		#	 <ResultDescription>
		#	 This feed processing request was cancelled by an operator.
		#	 Details: We are unable to keep up with the volume of your feeds.
		#	 Please submit no more than one feed per hour.
		#	 http://www.amazon.com/gp/help/customer/display.html?ie=UTF8&nodeId=200325440&qid=1250786571&sr=1-1
		#	 For further information please submit this full processing report to merchants-questions@amazon.com
		#	 </ResultDescription>
		$xml =~ s/&/&amp;/g;	
		## NOTE: this is a recoverable error.
		}

	return($ERROR,$xml);	
	}

#######################################################################
##
## used in amz_feed.pl docs (ie get a particular docid's Processing Status (PS))
##
## _SUBMITTED_, _IN_PROGRESS_, _CANCELLED_, _DONE_
##
## currently only retrofitted for FeedSubmittals
## changed for MWS functionality
sub getDocumentPS {
	my ($userref,$docid) = @_;

	## this request could/should be used for multiple docids 
	my %action_params = (
		'Action' => 'GetFeedSubmissionList',
		'FeedSubmissionIdList.Id.1' => $docid,
		);

	my ($request_url, $head, $agent) = &AMAZON3::prep_header($userref,\%action_params);
	my $request = HTTP::Request->new('POST',$request_url,$head);
	my $response = $agent->request($request);

	#print STDERR "REQUEST (getDocumentPS):".Dumper($request)."\nRESPONSE (getDocumentPS):".Dumper($response);

	my $status = '';
	my $rdocid = 0;

	## request errored
	if (not $response->is_success()) {
		$status = $response->status_line();
		$rdocid = -1;
		}
	elsif ($response->content() ne '') {
		## rdocid == docid for FeedSumittals, hmm  ??
		if ($response->content() =~ /\<FeedSubmissionId\>(.*)\<\/FeedSubmissionId\>/s) { $rdocid = $1; }
		if ($response->content() =~ /\<FeedProcessingStatus\>(.*?)\<\/FeedProcessingStatus\>/) { $status = $1; }
		}
	else {
		#use Data::Dumper; print STDERR "GetDocumentPS: \n".Dumper($response);
		print STDERR "No content for this DOCID\n";
		$status = "received empty response for get getDocumentPS $docid";
		$rdocid = -1;
		}

	return($rdocid,$status);	
	}



1;