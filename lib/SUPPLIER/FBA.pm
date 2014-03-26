package SUPPLIER::FBA;

use Data::Dumper;
use strict;

use Digest::HMAC_SHA1;
use MIME::Base64;
use Digest::MD5;
use XML::SAX::Simple;

use lib "/backend/lib";
require ZOOVY;
require DIME::Parser;
require ZTOOLKIT;
require AMAZON3;
require PRODUCT;
require INVENTORY2;
require ZSHIP;

## USAGE
## perl -e 'use lib "/backend/lib"; use SUPPLIER::FBA; my ($S) = SUPPLIER::FBA::test("zephyrsports"); SUPPLIER::FBA::inventory($S); '
# perl -e 'use lib "/backend/lib"; use SUPPLIER::FBA;  
#			my ($CART2) = CART2->new_persist("zephyrsports",7,""); 
#			my ($S) = SUPPLIER::FBA::test("zephyrsports"); 
#			SUPPLIER::FBA::shipquote($S,$CART2,$CART2->stuff2()); '


sub test { 
	my ($USERNAME) = @_;  
	print "hello\n"; 
	my ($S) = SUPPLIER->new($USERNAME,"FBA"); 
	if (not defined $S) {
		($S) = SUPPLIER->new($USERNAME,"FBA",'create'=>1);
		my ($userref) = &AMAZON3::fetch_userprt($USERNAME,0);
		$S->set('.our.fba_marketplaceid',$userref->{'AMAZON_MARKETPLACEID'});
		$S->set('.our.fba_merchantid',$userref->{'AMAZON_MERCHANTID'});
		}

	return($S);
	}


##
## userref is the format required by most of the code in AMAZON3
##	normally built by SYNDICATION/AMAZON3 .. this emulates it.
##
sub emulated_userref {
	my ($S) = @_;

	my ($USERNAME) = $S->username();
	if ($USERNAME eq 'greatlookz') {
		my ($userref) = &AMAZON3::fetch_userprt($USERNAME,2);
		$S->set('.our.fba_marketplaceid',$userref->{'AMAZON_MARKETPLACEID'});
		$S->set('.our.fba_merchantid',$userref->{'AMAZON_MERCHANTID'});
		}

	my $userref = {
		'USERNAME'=>$USERNAME,
		'AMAZON_MARKETPLACEID'=>$S->get('.our.fba_marketplaceid'),
		'AMAZON_MERCHANTID'=>$S->get('.our.fba_merchantid'),
		'INV_LASTSYNC_GMT'=> $S->get('.inv.fba_lastsync_gmt'),
		};

	return($userref);
	}

##
##
##
sub inventory {
	my ($S,%options) = @_;

	my $USERNAME = $S->username();
	my $date = &ZTOOLKIT::pretty_date(time(),1);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($lm) = LISTING::MSGS->new($USERNAME,logfile=>'~/fba-%YYYYMM%.log',stderr=>1);
	my $agent = new LWP::UserAgent;
	$agent->agent('CommerceRack/FBA (Language=Perl/v5.8.6)');

	my %SKUS = ();
	my @REQUESTS = ();
	my $START_TS = time();			## on success save the time we started, not the time we finished.
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	$lm->pooshmsg("INFO|+Start INVENTORY");
	my $userref = &SUPPLIER::FBA::emulated_userref($S);	
	## print STDERR Dumper($userref)."\n";
	
	if (not $lm->can_proceed()) {
		## bad shit already happened.
		}
	elsif ($userref->{'AMAZON_MARKETPLACEID'} eq '') {
		## w/o the marketplaceid, MWS will not function
		$lm->pooshmsg(sprintf("STOP|+SUPPLIER:%s is not setup for MWS .our.fba_marketplaceid",$S->code()));
		}
	elsif ($userref->{'AMAZON_MERCHANTID'} eq '') {
		## w/o the merchantid, MWS will not function
		$lm->pooshmsg(sprintf("STOP|+SUPPLIER:%s is missising .our.fba_merchantid",$S->code()));
		}

	if (not $lm->can_proceed()) {
		## bad shit already happened.
		}
	else {
		my $TS = &AMAZON3::amztime($userref->{'INV_LASTSYNC_GMT'});	#amztime requires a unix timestamp
		$TS = 1;
		my $DETAIL_LEVEL = 'Basic';

		## print Dumper(\%options);
		@REQUESTS = ();
		my %SKUS = ();

		if ($TS>0) {
			push @REQUESTS, { 
				'Action'=>'ListInventorySupply',
				'QueryStartDateTime'=>&AMAZON3::amztime($options{'TS'}),
				'ResponseGroup'=>($options{'ResponseGroup'} || 'Basic'),
				};
			}
		elsif (defined $options{'@SKUS'}) {
			foreach my $batch (@{&ZTOOLKIT::batchify($options{'@SKUS'},50)}) {
				my %HEADERS = ();		
				$HEADERS{'Action'} = 'ListInventorySupply';
				$HEADERS{'ResponseGroup'} = ($options{'ResponseGroup'} || 'Basic');
				my $i = 1;
				foreach my $SKU (@{$batch}) {
					$HEADERS{sprintf('SellerSkus.member.%d',$i++)} = $SKU;
					}	
	  			 push @REQUESTS, \%HEADERS;
  				 }
  			 }
  		 else {
  			 $lm->pooshmsg("ISE|+Please send TS or \@SKUS");
			}
		}

	
	## SANITY: @REQUESTS is populated (assuming we got no errors)
	my $API_FAILURES = 0;
	while (my $headers = shift @REQUESTS) {
		next if (not $lm->can_proceed());		## fatal errors will stop us!

		my ($request_url, $head) = &SUPPLIER::FBA::mws_headers("/FulfillmentInventory/2010-10-01/",$userref,$headers);

		my $request = HTTP::Request->new('POST',$request_url,$head);
		my $response = $agent->request($request);

		if ($response->code() == 400) {
			## 400 = this definitely means account was suspended or password is wrong.
			## this is DEFINITELY not a retry condition.
			$lm->pooshmsg("FAIL-FATAL|+HTTP 400 response code (account was suspended or password is wrong)");
			}
		elsif (not $response->is_success()) {
			## High level API Failure (this could be us, or Amazon down)
			$lm->pooshmsg(sprintf("%s|+API ERROR[%d] %s",(($API_FAILURES<3)?'WARN':'ERROR'),$API_FAILURES,$response->content()));
			$API_FAILURES++;
			if ($API_FAILURES < 3) {
				## lets make this request again!
				unshift @REQUESTS, $headers;
				}
			}
		else {
			## we did not receive an api error so set $xml
			my $raw_xml_response = $response->content();
			my ($sh) = IO::String->new(\$raw_xml_response);
			open F, ">/dev/shm/fba.raw_xml_response";
			print F $raw_xml_response;
			close F;

			my ($msgs) = XML::SAX::Simple::XMLin($sh,ForceArray=>1);

			## NOTE: stripNamespace rewrites the sax xml without namespaces e.g.:
			# original: '{http://mws.amazonservices.com/schema/Products/2011-10-01}SKUIdentifier'=>{..}
			#	  into: 'SKUIdentifier'=>{}
			## so the xml response looks very different (but much more managable after stripNamespace)
			&ZTOOLKIT::XMLUTIL::stripNamespace($msgs);	
			my $PRETTY_PARSEDXML_RESPONSE = $msgs;		# !!! HEY look at the reminder about stripNamespace above.
				
			## set $TOP_LEVEL_ELEMENT  ListInventorySupplyResult  ListInventorySupplyByNextTokenResult
			my $TOP_LEVEL_ELEMENT = $headers->{'Action'}."Result";	
			if ($PRETTY_PARSEDXML_RESPONSE->{$TOP_LEVEL_ELEMENT}[0]->{'NextToken'}[0] ne '') {
				## if NextToken is returned Amazon have not yet retuned the entire response and the process that sent us to this subroutine 
				##		needs to ask for more
				my $NEXT_TOKEN = $PRETTY_PARSEDXML_RESPONSE->{$TOP_LEVEL_ELEMENT}[0]->{'NextToken'}[0];
				## amazon don't always return all skus in 1 doc which doesn't make things harder at all. If they have more to give us they will return a NextToken
				## in the response. If they do this we get the pleasure of asking for more using the ListInventorySupplyByNextToken call. Love it.
				##	
				## we will only have to call ListInventorySupplyByNextToken once because if a NextToken is returned for a second time ListInventorySupplyByNextToken
				## can call itself
				## my ($SKUS, $lm) = &ListInventorySupplyByNextToken($userref, $NEXT_TOKEN, $REPORT_TYPE, $SKUS, '*LM'=>$lm);
				if ($NEXT_TOKEN ne '') {
					## append this next token to the front of the list
					## see SKU_LIST for *WHY* we do it this way
					unshift @REQUESTS, { 'Action'=>'ListInventorySupplyByNextToken', 'NextToken'=>$NEXT_TOKEN };
					}
				}

			## we should probably check for ResponseGroup eq 'Basic'
			if (defined $PRETTY_PARSEDXML_RESPONSE->{$TOP_LEVEL_ELEMENT}[0]->{'InventorySupplyList'}[0]->{'member'}) {
				foreach my $msg (@{$PRETTY_PARSEDXML_RESPONSE->{$TOP_LEVEL_ELEMENT}[0]->{'InventorySupplyList'}[0]->{'member'}}) {
					#'.FNSKU' => 'X0002D20LD',
					#'.SellerSKU' => 'PB-PMI-DEFENDER',
					#'.ASIN' => 'B0014UWJJ0',
					#'.InStockSupplyQuantity' => '95',
					#'.EarliestAvailability.TimepointType' => 'Immediately',
					#'.Condition' => 'NewItem',
					#'.TotalSupplyQuantity' => '319'
					my ($node) = ZTOOLKIT::XMLUTIL::SXMLflatten($msg);
					$SKUS{ $node->{'.SellerSKU'} } = $node 
					}
				}
			}
		}
	

	## SANITY: at this point %SKUS is populated
	if ($lm->can_proceed()) {
		my ($INV2) = INVENTORY2->new($USERNAME,sprintf("*S!%s",$S->code()));
		foreach my $SKU (sort keys %SKUS) {
			my $REF = $SKUS{$SKU};
			## $REF = {
			  #'.FNSKU' => 'X0002D20LD',
				#'.SellerSKU' => 'PB-PMI-DEFENDER',
				#'.ASIN' => 'B0014UWJJ0',
				#'.InStockSupplyQuantity' => '95',
				#'.EarliestAvailability.TimepointType' => 'Immediately',
				#'.Condition' => 'NewItem',
				#'.TotalSupplyQuantity' => '319'

			my $NOTE = '';
			if ($REF->{'.TotalSupplyQuantity'}>0 && $REF->{'.TotalSupplyQuantity'}!=$REF->{'.InStockSupplyQuantity'}) {
				$NOTE = sprintf("Cond:%s Avail:%s Expected:%s",$REF->{'.Condition'},$REF->{'.EarliestAvailability.TimepointType'},$REF->{'.TotalSupplyQuantity'});
				}
			elsif ($REF->{'.InStockSupplyQuantity'}>0) {
				$NOTE = sprintf("Cond:%s",$REF->{'.Condition'});
				}
			else {
				$NOTE = "Out of stock";
				}

			$INV2->supplierskuinvcmd($S,$SKU,"SET",
				"QTY"=>$REF->{'.InStockSupplyQuantity'}, 
				'UUID'=>sprintf("FBA*%s",$REF->{'.ASIN'}),
				'SUPPLIER_SKU'=>$REF->{'.FNSKU'},
				'NOTE'=>$NOTE,
				);
			}
		$INV2->sync();
		}

	if (not $lm->can_proceed()) {
		$lm->pooshmsg("WARN|+End Inventory (errors)");
		}
	elsif (scalar(keys %SKUS) == 0) {
		$lm->pooshmsg("WARN|+no skus found/updated");
		}
	else {
		$lm->pooshmsg(sprintf("SUCCESS|+End Inventory %d records, took %d seconds",(scalar keys %SKUS),(time()-$START_TS)));
		$S->set('.inv.fba_lastsync_gmt',$START_TS);
		$S->save();
		}

	DBINFO::db_user_close();
	}



#### creat
#sub createOrder {
#	my ($userref,%options) = @_;

#	print Dumper(\%options);

#


#### CreateFulfillmentOrder

##The CreateFulfillmentOrder operation generates a request for Amazon to ship items from the seller's inventory in the Amazon Fulfillment Network to a destination address. 

## EXAMPLE REQUEST

## In the example below an R before the attribute identifies it as required

#http://mws.amazonaws.com/FulfillmentOutboundShipment/2010-10-01/
#R  ?Action=CreateFulfillmentOrder
#R  &Version=2010-10-01
#R  &AWSAccessKeyId=AKIAJGUEXAMPLEE2NVUA
#R  &SignatureVersion=2
#R  &SignatureMethod=HmacSHA256
#R  &Signature=ZRA9DR5rveSuz%2F1D18AHvoipg2BAev8yblPQ1BbEbfU%3D
#R  &Timestamp=2010-10-01T02:40:36Z
#R  &SellerId=A2NKEXAMPLEF53
#R  &SellerFulfillmentOrderId=mws-test-query-20100713023203751
#R  &DisplayableOrderId=mws-test-query-20100713023203751
#R  &ShippingSpeedCategory=Standard
#R  &DestinationAddress.Name=John%20Smith
#R  &DestinationAddress.Line1=1234%201st%20Ave
#  &DestinationAddress.Line2=More%20address%20info
#R  &DestinationAddress.City=Seattle										(Required, except in JP. Do not use in JP)
#R  &DestinationAddress.CountryCode=US
#R  &DestinationAddress.StateOrProvinceCode=WA
#  &DestinationAddress.PostalCode=98104
#R  &DisplayableOrderComment=Seller%20comment%20here
#R  &DisplayableOrderDateTime=2010-06-15
#  &Items.member.1.DisplayableComment=Seller%20comment%20here
#  &Items.member.1.GiftMessage=Gift%20comment%20here
#  &Items.member.1.PerUnitDeclaredValue.CurrencyCode=USD
#  &Items.member.1.PerUnitDeclaredValue.Value=10.05
#R  &Items.member.1.Quantity=1
#R  &Items.member.1.SellerFulfillmentOrderItemId=mws-test-1
#R  &Items.member.1.SellerSKU=Sample_SKU_1
#  &Items.member.2.DisplayableComment=Seller%20comment%20here
#  &Items.member.2.GiftMessage=Gift%20comment%20here
#  &Items.member.2.PerUnitDeclaredValue.CurrencyCode=USD
#  &Items.member.2.PerUnitDeclaredValue.Value=10.05
#  &Items.member.2.Quantity=2
#  &Items.member.2.SellerFulfillmentOrderItemId=mws-test-2
#  &Items.member.2.SellerSKU=Sample_SKU_2
#  &NotificationEmailList.member.1=test1%40amazon.com
#  &NotificationEmailList.member.2=test2%40amazon.com
				

## EXAMPLE RESPONSE

#<?xml version="1.0"?>
#<CreateFulfillmentOrderResponse xmlns="http://mws.amazonaws.com/FulfillmentOutboundShipment/2010-10-01/">
#  <ResponseMetadata>
#	 <RequestId>d95be26c-16cf-4bbc-ab58-dce89fd4ac53</RequestId>
#  </ResponseMetadata>
#</CreateFulfillmentOrderResponse>
		
sub transmit {
	my ($S,$O2,%options) = @_;

	my ($USERNAME) = $S->username();
	my ($userref) = &SUPPLIER::FBA::emulated_userref($S);

	tie my %o, 'CART2', 'CART2'=>$O2;
	my %HEADERS = ();		
	$HEADERS{'Action'} = 'CreateFulfillmentOrder';
	$HEADERS{'Version'} = '2010-10-01';
	$HEADERS{'SellerFulfillmentOrderId'} = $O2->oid();
	$HEADERS{'DisplayableOrderId'} = $O2->oid();
	
	## lets get the amazon ship code
	$HEADERS{'ShippingSpeedCategory'} = 'Standard';
	if ($o{'sum/shp_carrier'} ne '') {
		my ($carrierinfo) = &ZSHIP::shipinfo($o{'sum/shp_carrier'});
		if (not defined $carrierinfo) {}
		elsif (not $carrierinfo->{'expedited'}) {}
		elsif (not $carrierinfo->{'is_nextday'}) { $HEADERS{'ShippingSpeedCategory'} = 'Priority'; }
		else { $HEADERS{'ShippingSpeedCategory'} = 'Expedited'; }
		}

	## for name, first we try firstname / lastname
	if ($HEADERS{'DestinationAddress.Name'} eq '') { $HEADERS{'DestinationAddress.Name'} = $o{'ship/firstname'}.($o{'ship/lastname'}?' '.$o{'ship/lastname'}:''); }
	## then we'll try fullname (in case that's set .. but it probably isn't.)
	## if ($HEADERS{'DestinationAddress.Name'} eq '') { $HEADERS{'DestinationAddress.Name'} = $o{'ship/fullname'}; }
	## finally we'll try the comany name
	if ($HEADERS{'DestinationAddress.Name'} eq '') { $HEADERS{'DestinationAddress.Name'} = $o{'ship/company'}; }

	$HEADERS{'DestinationAddress.Line1'} = $o{'ship/address1'};
	if ($o{'ship/address2'}) { $HEADERS{'DestinationAddress.Line2'} = $o{'ship/address2'}; }
#	if ($o{'ship/address3'}) { $HEADERS{'DestinationAddress.Line3'} = $o{'ship/address3'}; }

	$HEADERS{'DestinationAddress.City'} = $o{'ship/city'};
	if ($o{'ship/countrycode'} eq 'JP') { delete $HEADERS{'DestinationAddress.City'};  }	## see note on 'city' above

	$HEADERS{'DestinationAddress.CountryCode'} = $o{'ship/countrycode'};
	$HEADERS{'DestinationAddress.StateOrProvinceCode'} = $o{'ship/region'};
	$HEADERS{'DestinationAddress.PostalCode'} = $o{'ship/postal'};

	$HEADERS{'DisplayableOrderDateTime'} = &AMAZON3::amztime($o{'cart/created_ts'});
	if ($o{'want/order_notes'}) {
		$HEADERS{'DisplayableOrderComment'} = $o{'want/order_notes'};
		}
	untie %o;

	my $i = 1;
	foreach my $item (@{$O2->stuff2()->items()}) {
		print "adding headers for ".$item."\n";
		$HEADERS{sprintf('Items.member.%d.SellerSKU',$i)} = $item->{'sku'};
		$HEADERS{sprintf('Items.member.%d.GiftMessage',$i)} = $item->{'notes'};
		$HEADERS{sprintf('Items.member.%d.Quantity',$i)} = $item->{'qty'};
		$HEADERS{sprintf('Items.member.%d.SellerFulfillmentOrderItemId',$i)} = $item->{'uuid'};
		## FulfillmentNetworkSKU
		## PerUnitDeclaredValue
		## DisplayableComment
		$i++;
		}	

	my $API_FAILURES = 0;
	
	my $lm = LISTING::MSGS->new($USERNAME);
	my $agent = new LWP::UserAgent;
	$agent->agent('CommerceRack/FBA (Language=Perl/v5.8.6)');
	print "about to submit order\n";
	my ($request_url, $head) = &SUPPLIER::FBA::mws_headers("/FulfillmentOutboundShipment/2010-10-01/",$userref,\%HEADERS);

	print "**************request url ***********".Dumper($request_url);

	while ( (not $lm->has_win()) && ($lm->can_proceed()) ) {
		my $request = HTTP::Request->new('POST',$request_url,$head);
		my $response = $agent->request($request);

		print Dumper($response);

		if ($response->code() == 400) {
			## 400 = this definitely means account was suspended or password is wrong.
			## this is DEFINITELY not a retry condition.
			$lm->pooshmsg("FAIL-FATAL|+HTTP 400 response code (account was suspended or password is wrong)");
			}
		elsif (not $response->is_success()) {
			## High level API Failure (this could be us, or Amazon down)
			$lm->pooshmsg(sprintf("%s|+API ERROR[%d] %s",(($API_FAILURES<3)?'WARN':'ERROR'),$API_FAILURES,$response->content()));
			$API_FAILURES++;
			}
		else {
			## we did not receive an api error so set $xml
			## <CreateFulfillmentOrderResponse xmlns="http://mws.amazonaws.com/FulfillmentOutboundShipment/2010-10-01/">
			## <ResponseMetadata>
			##   <RequestId>d95be26c-16cf-4bbc-ab58-dce89fd4ac53</RequestId>
			##  </ResponseMetadata>
			## </CreateFulfillmentOrderResponse>
			my $raw_xml_response = $response->content();
			my ($sh) = IO::String->new(\$raw_xml_response);
			open F, sprintf(">%s/%s",&ZOOVY::tmpfs(),"/amzfba.order.out"); print F $raw_xml_response; close F;
			my ($ref) = XML::Simple::XMLin($sh,ForceArray=>1);
			my $requestid = $ref->{'ResponseMetadata'}->[0]->{'RequestId'}->[0];
			$lm->pooshmsg("WIN|+AmazonFBA Response:$requestid");
			}
		}

	print "done with the subroutine\n";
	return($lm);	
	}


# GetFulfillmentPreview

#The GetFulfillmentPreview operation returns a list of fulfillment order previews based on items and shipping speed categories that you specify. 
#Each fulfillment order preview contains the estimated shipping weight and the estimated shipping fees for the potential fulfillment order, 
# as well as ship dates, arrival dates, and estimated shipping weights for individual shipments within the potential fulfillment order. 
#This operation also provides information about unfulfillable items in fulfillment order previews. 
#If ShippingSpeedCategories is not included in the request, the operation returns previews for all available shipping speeds. 


## EXAMPLE REQUEST

#http://mws.amazonaws.com/FulfillmentOutboundShipment/2010-10-01/
#  ?Action=GetFulfillmentPreview
#  &Version=2010-10-01
#  &AWSAccessKeyId=AKIAJGUEXAMPLEE2NVUA
#  &SignatureVersion=2
#  &SignatureMethod=HmacSHA256
#  &Signature=ZRA9DR5rveSuz%2F1D18AHvoipg2BAev8yblPQ1BbEbfU%3D
#  &Timestamp=2010-10-01T02:40:36Z
#  &SellerId=A2NKEXAMPLEF53
#  &ShippingSpeedCategories.1=Expedited
#  &ShippingSpeedCategories.2=Standard
#  &Address.Name=James%20Smith
#  &Address.Line1=456%20Cedar%20St
#  &Address.City=Seattle
#  &Address.StateOrProvinceCode=WA
#  &Address.PostalCode=98104
#  &Address.CountryCode=US
#  &Items.member.1.Quantity=1
#  &Items.member.1.SellerFulfillmentOrderItemId=TestId1
#  &Items.member.1.SellerSKU=SampleSKU1
#  &Items.member.2.Quantity=2
#  &Items.member.2.SellerFulfillmentOrderItemId=TestId2
#  &Items.member.2.SellerSKU=SampleSKU2


sub shipquote {
	my ($S,$CART2,$PKG) = @_;

	my ($USERNAME) = $S->username();
	my ($userref) = &SUPPLIER::FBA::emulated_userref($S);


	tie my %o, 'CART2', 'CART2'=>$CART2;
	my %HEADERS = ();		
	$HEADERS{'Action'} = 'GetFulfillmentPreview';
	$HEADERS{'Version'} = '2010-10-01';

	my $i = 0;

	## DO NOT UNCOMMENT
	## will result in: Top level element may not be treated as a list
	#foreach my $rate ('Expedited','Standard','Priority') {
	#	$HEADERS{sprintf("ShippingSpeedCategories.%d",++$i)} = $rate;
	#	}
	## $HEADERS{'ShippingSpeedCategories.1.value'} = 'Standard';

	## for name, first we try firstname / lastname
	if ($HEADERS{'Address.Name'} eq '') { $HEADERS{'Address.Name'} = $o{'ship/firstname'}.($o{'ship/lastname'}?' '.$o{'ship/lastname'}:''); }
	## then we'll try fullname (in case that's set .. but it probably isn't.)
	## if ($HEADERS{'Address.Name'} eq '') { $HEADERS{'Address.Name'} = $o{'ship/fullname'}; }
	## finally we'll try the comany name
	if ($HEADERS{'Address.Name'} eq '') { $HEADERS{'Address.Name'} = $o{'ship/company'}; }
	if ($HEADERS{'Address.Name'} eq '') { $HEADERS{'Address.Name'} = 'Harry Balls'; }

	#$HEADERS{'Address.Line1'} = $o{'ship/address1'};
	if ($HEADERS{'Address.Line1'} eq '') { $HEADERS{'Address.Line1'} = '123 Main St.'; }
	if ($o{'ship/address2'}) { $HEADERS{'Address.Line2'} = $o{'ship/address2'}; }
	## if ($o{'ship/address3'}) { $HEADERS{'Address.Line3'} = $o{'ship/address3'}; }

	$HEADERS{'Address.City'} = $o{'ship/city'};
	if ($o{'ship/countrycode'} eq 'JP') { delete $HEADERS{'Address.City'};  }	## see note on 'city' above

	$HEADERS{'Address.CountryCode'} = $o{'ship/countrycode'};
	$HEADERS{'Address.StateOrProvinceCode'} = uc($o{'ship/region'});
	$HEADERS{'Address.PostalCode'} = $o{'ship/postal'};
	untie %o;

	$i = 1;
	foreach my $item (@{$PKG->items()}) {
		$HEADERS{sprintf('Items.member.%d.SellerSKU',$i)} = $item->{'sku'};
		$HEADERS{sprintf('Items.member.%d.Quantity',$i)} = $item->{'qty'};
		$HEADERS{sprintf('Items.member.%d.SellerFulfillmentOrderItemId',$i)} = $item->{'uuid'};
		$i++;
		}	

	my $API_FAILURES = 0;

	my $lm = LISTING::MSGS->new($USERNAME);
	my $agent = new LWP::UserAgent;
	$agent->agent('CommerceRack/FBA (Language=Perl/v5.8.6)');
	my ($request_url, $head) = &SUPPLIER::FBA::mws_headers("/FulfillmentOutboundShipment/2010-10-01/",$userref,\%HEADERS);

	my @SHIPMETHODS = ();
	while ( not $lm->has_win() && $lm->can_proceed() ) {
		my $request = HTTP::Request->new('POST',$request_url,$head);
		my $response = $agent->request($request);
		print STDERR "REQUEST!\n";
		print STDERR Dumper($response);

		if ($response->code() == 400) {
			## 400 = this definitely means account was suspended or password is wrong.
			## this is DEFINITELY not a retry condition.
			$lm->pooshmsg("FAIL-FATAL|+HTTP 400 response code (account was suspended or password is wrong)");
			die();
			}
		elsif (not $response->is_success()) {
			## High level API Failure (this could be us, or Amazon down)
			$lm->pooshmsg(sprintf("%s|+API ERROR[%d] %s",(($API_FAILURES<3)?'WARN':'ERROR'),$API_FAILURES,$response->content()));
			$API_FAILURES++;
			print Dumper($lm);
			die();
			}
		else {
			## we did not receive an api error so set $xml
			## <CreateFulfillmentOrderResponse xmlns="http://mws.amazonaws.com/FulfillmentOutboundShipment/2010-10-01/">
			## <ResponseMetadata>
			##   <RequestId>d95be26c-16cf-4bbc-ab58-dce89fd4ac53</RequestId>
			##  </ResponseMetadata>
			## </CreateFulfillmentOrderResponse>
			my $raw_xml_response = $response->content();
			my ($sh) = IO::String->new(\$raw_xml_response);
			open F, ">/dev/shm/amzfba.order.out"; print F $raw_xml_response; close F;
			my ($ref) = XML::Simple::XMLin($sh,ForceArray=>1);
			$ref = $ref->{'GetFulfillmentPreviewResult'}->[0];		## drop some nesting.
			foreach my $member ( @{$ref->{'FulfillmentPreviews'}->[0]->{'member'}} ) {
				if ($member->{'IsFulfillable'}->[0] ne 'true') {
					$lm->pooshmsg("WARN|+FBA Got IsFulfillable response of False");
					}
				else {
					my %SHIPMETHOD = ();
					$SHIPMETHOD{'id'} = sprintf("FBA-%s",$member->{'ShippingSpeedCategory'}->[0]);	## Priority|Standard|Expedited
					$SHIPMETHOD{'name'} = $member->{'ShippingSpeedCategory'}->[0];	## Priority|Standard|Expedited
					if ($SHIPMETHOD{'name'} eq 'Expedited') { $SHIPMETHOD{'carrier'} = 'FAST'; }
					if ($SHIPMETHOD{'name'} eq 'Priority') { $SHIPMETHOD{'carrier'} = 'BEST'; }
					if ($SHIPMETHOD{'name'} eq 'Standard') { $SHIPMETHOD{'carrier'} = 'SLOW'; }

					foreach my $key ('EarliestShipDate','EarliestArrivalDate', 'LatestArrivalDate', 'LatestShipDate') {
						$SHIPMETHOD{lc(sprintf('fba-%s',$key))} = $member->{'FulfillmentPreviewShipments'}->[0]{'member'}->[0]{$key}->[0];
						}
	
					my $total = 0;
					foreach my $fee (@{$member->{'EstimatedFees'}->[0]{'member'}}) {
			          #'Amount' => [
			          #            {
			          #              'Value' => [
			          #                         '2.40'
			          #                       ],
			          #              'CurrencyCode' => [
			          #                                'USD'
			          #                              ]
			          #            }
			          #          ],
			          #'Name' => [
			          #          'FBATransportationFee'
			          #        ]
						my $amt = $fee->{'Amount'}->[0]->{'Value'}->[0];
						my $currency = $fee->{'Amount'}->[0]->{'CurrencyCode'}->[0];
						my $name = $fee->{'Name'}->[0];

						$SHIPMETHOD{lc(sprintf('fee-%s',$name))} = $amt;
						$SHIPMETHOD{'currency'} = $currency;
						$total += $amt;
						}
					$SHIPMETHOD{'amount'} = $total;		## system 'amount' is the total for all shipping.
					push @SHIPMETHODS, \%SHIPMETHOD;
					}
				## end of else not fulfillable.
				}
			## end of else not api error response.
			}
		## end of while not api retry
		}

	return(\@SHIPMETHODS);
	}

## EXAMPLE RESPONSE

#<?xml version="1.0"?>
#  <GetFulfillmentPreviewResponse xmlns="http://mws.amazonaws.com/FulfillmentInboundShipment/2010-10-01/">
#    <GetFulfillmentPreviewResult>
#      <FulfillmentPreviews>
#        <member>
#          <EstimatedShippingWeight>
#            <Unit>POUNDS</Unit>
#            <Value>12</Value>
#          </EstimatedShippingWeight>
#          <ShippingSpeedCategory>Expedited</ShippingSpeedCategory>
#          <FulfillmentPreviewShipments>
#            <member>
#              <LatestShipDate>2010-07-14T00:30:00Z</LatestShipDate>
#              <LatestArrivalDate>2010-07-16T06:59:59Z</LatestArrivalDate>
#              <FulfillmentPreviewItems>
#                <member>
#                  <EstimatedShippingWeight>
#                    <Unit>POUNDS</Unit>
#                    <Value>5</Value>
#                  </EstimatedShippingWeight>
#                  <SellerSKU>SampleSKU1</SellerSKU>
#                  <SellerFulfillmentOrderItemId>
#                  mws-test-query-20100713023406723-2
#                  </SellerFulfillmentOrderItemId>
#                  <ShippingWeightCalculationMethod>Package
#                  </ShippingWeightCalculationMethod>
#                  <Quantity>2</Quantity>
#                </member>
#                <member>
#                  <EstimatedShippingWeight>
#                    <Unit>POUNDS</Unit>
#                    <Value>0.290</Value>
#                  </EstimatedShippingWeight>
#                  <SellerSKU>SampleSKU2</SellerSKU>
#                  <SellerFulfillmentOrderItemId>
#                  mws-test-query-20100713023406723-1
#                  </SellerFulfillmentOrderItemId>
#                  <ShippingWeightCalculationMethod>Package
#                  </ShippingWeightCalculationMethod>
#                  <Quantity>1</Quantity>
#                </member>
#              </FulfillmentPreviewItems>
#              <EarliestShipDate>2010-07-14T00:30:00Z</EarliestShipDate>
#              <EarliestArrivalDate>2010-07-15T07:00:00Z
#              </EarliestArrivalDate>
#            </member>
#          </FulfillmentPreviewShipments>
#          <EstimatedFees>
#            <member>
#              <Amount>
#                <CurrencyCode>USD</CurrencyCode>
#                <Value>2.25</Value>
#              </Amount>
#              <Name>FBAPerUnitFulfillmentFee</Name>
#            </member>
#            <member>
#              <Amount>
#                <CurrencyCode>USD</CurrencyCode>
#                <Value>4.75</Value>
#              </Amount>
#              <Name>FBAPerOrderFulfillmentFee</Name>
#            </member>
#            <member>
#              <Amount>
#                <CurrencyCode>USD</CurrencyCode>
#                <Value>6.60</Value>
#              </Amount>
#              <Name>FBATransportationFee</Name>
#            </member>
#          </EstimatedFees>
#          <UnfulfillablePreviewItems/>
#          <IsFulfillable>true</IsFulfillable>
#        </member>
#        <member>
#          <EstimatedShippingWeight>
#            <Unit>POUNDS</Unit>
#            <Value>12</Value>
#          </EstimatedShippingWeight>
#          <ShippingSpeedCategory>Standard</ShippingSpeedCategory>
#          <FulfillmentPreviewShipments>
#            <member>
#              <LatestShipDate>2010-07-14T00:30:00Z</LatestShipDate>
#              <LatestArrivalDate>2010-07-19T06:59:59Z</LatestArrivalDate>
#              <FulfillmentPreviewItems>
#                <member>
#                  <EstimatedShippingWeight>
#                    <Unit>POUNDS</Unit>
#                    <Value>5</Value>
#                  </EstimatedShippingWeight>
#                  <SellerSKU>SampleSKU1</SellerSKU>
#                  <SellerFulfillmentOrderItemId>
#                  mws-test-query-20100713023406723-2
#                  </SellerFulfillmentOrderItemId>
#                  <ShippingWeightCalculationMethod>Package
#                  </ShippingWeightCalculationMethod>
#                  <Quantity>2</Quantity>
#                </member>
#                <member>
#                  <EstimatedShippingWeight>
#                    <Unit>POUNDS</Unit>
#                    <Value>0.290</Value>
#                  </EstimatedShippingWeight>
#                  <SellerSKU>SampleSKU2</SellerSKU>
#                  <SellerFulfillmentOrderItemId>
#                  mws-test-query-20100713023406723-1
#                  </SellerFulfillmentOrderItemId>
#                  <ShippingWeightCalculationMethod>Package
#                  </ShippingWeightCalculationMethod>
#                  <Quantity>1</Quantity>
#                </member>
#              </FulfillmentPreviewItems>
#              <EarliestShipDate>2010-07-14T00:30:00Z</EarliestShipDate>
#              <EarliestArrivalDate>2010-07-15T07:00:00Z
#              </EarliestArrivalDate>
#            </member>
#          </FulfillmentPreviewShipments>
#          <EstimatedFees>
#            <member>
#              <Amount>
#                <CurrencyCode>USD</CurrencyCode>
#                <Value>2.25</Value>
#              </Amount>
#              <Name>FBAPerUnitFulfillmentFee</Name>
#            </member>
#            <member>
#              <Amount>
#                <CurrencyCode>USD</CurrencyCode>
#                <Value>4.75</Value>
#              </Amount>
#              <Name>FBAPerOrderFulfillmentFee</Name>
#            </member>
#            <member>
#              <Amount>
#                <CurrencyCode>USD</CurrencyCode>
#                <Value>6.60</Value>
#              </Amount>
#              <Name>FBATransportationFee</Name>
#            </member>
#          </EstimatedFees>
#          <UnfulfillablePreviewItems/>
#          <IsFulfillable>true</IsFulfillable>
#        </member>
#      </FulfillmentPreviews>
#    </GetFulfillmentPreviewResult>
#    <ResponseMetadata>
#      <RequestId>f4c29ec4-ceb7-4608-a764-5c758ac0021a</RequestId>
#    </ResponseMetadata>
#  </GetFulfillmentPreviewResponse>

##	The ListInventorySupplyByNextToken operation returns the next page of information about the availability of a seller's inventory using the NextToken 
##	value that was returned by your previous request to either ListInventorySupply or ListInventorySupplyByNextToken. If NextToken is not returned, there 
## are no more pages to return. 


## here to test FBA inventory - AT
sub mws_headers {
	my ($request_uri, $userref, $action_paramref) = @_;
	my $XML = $action_paramref->{'XML'};

	## 1. define credentials
	my $AMZ_MARKETPLACEID = $userref->{'AMAZON_MARKETPLACEID'};
	my $AMZ_MERCHANTID = $userref->{'AMAZON_MERCHANTID'};

	my ($CFG) = CFG->new();
	my $host = $CFG->get("amazon_mws","host");
	my $sk = $CFG->get('amazon_mws',"sk");
	my $awskey = $CFG->get('amazon_mws',"aws_key");

	my $TS = AMAZON3::amztime(time()+(8*3600));
	my $md5 = &Digest::MD5::md5_base64($XML);
	$md5 .= "==";		## this is officially duct-tape, run w/o and md5's dont match

	my %params = (
		'AWSAccessKeyId'=>$awskey,
		## NOTE: in repricing this is 'MarketplaceId' not 'Marketplace'
		'Marketplace'=>$AMZ_MARKETPLACEID,
		'SellerId'=>$AMZ_MERCHANTID,
		'SignatureVersion'=>2,
		'SignatureMethod'=>'HmacSHA1',
		'Timestamp'=>$TS,
		## NOTE: in repricing this is '2013-07-01
		'Version' => '2010-10-01',
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

	return($request_url, $head);	
	}







1;

__DATA__

<GetFulfillmentPreviewResponse xmlns="http://mws.amazonaws.com/FulfillmentOutboundShipment/2010-10-01/">
  <GetFulfillmentPreviewResult>
    <FulfillmentPreviews>
      <member>
        <EstimatedShippingWeight>
          <Unit>POUNDS</Unit>
          <Value>4</Value>
        </EstimatedShippingWeight>
        <ShippingSpeedCategory>Priority</ShippingSpeedCategory>
        <FulfillmentPreviewShipments>
          <member>
            <LatestShipDate>2013-09-28T22:00:00Z</LatestShipDate>
            <LatestArrivalDate>2013-10-01T06:59:59Z</LatestArrivalDate>
            <FulfillmentPreviewItems>
              <member>
                <EstimatedShippingWeight>
                  <Unit>POUNDS</Unit>
                  <Value>3.541</Value>
                </EstimatedShippingWeight>
                <SellerSKU>EMPR-2030-21630</SellerSKU>
                <SellerFulfillmentOrderItemId>C1E7E34227D811E392217F8E3DE391E7</SellerFulfillmentOrderItemId>
                <ShippingWeightCalculationMethod>Dimensional</ShippingWeightCalculationMethod>
                <Quantity>1</Quantity>
              </member>
            </FulfillmentPreviewItems>
            <EarliestShipDate>2013-09-28T22:00:00Z</EarliestShipDate>
            <EarliestArrivalDate>2013-09-30T07:00:00Z</EarliestArrivalDate>
          </member>
        </FulfillmentPreviewShipments>
        <EstimatedFees>
          <member>
            <Amount>
              <CurrencyCode>USD</CurrencyCode>
              <Value>3.00</Value>
            </Amount>
            <Name>FBAPerUnitFulfillmentFee</Name>
          </member>
          <member>
            <Amount>
              <CurrencyCode>USD</CurrencyCode>
              <Value>17.00</Value>
            </Amount>
            <Name>FBAPerOrderFulfillmentFee</Name>
          </member>
          <member>
            <Amount>
              <CurrencyCode>USD</CurrencyCode>
              <Value>6.00</Value>
            </Amount>
            <Name>FBATransportationFee</Name>
          </member>
        </EstimatedFees>
        <IsFulfillable>true</IsFulfillable>
        <UnfulfillablePreviewItems/>
      </member>
      <member>
        <EstimatedShippingWeight>
          <Unit>POUNDS</Unit>
          <Value>4</Value>
        </EstimatedShippingWeight>
        <ShippingSpeedCategory>Standard</ShippingSpeedCategory>
        <FulfillmentPreviewShipments>
          <member>
            <LatestShipDate>2013-10-01T06:59:59Z</LatestShipDate>
            <LatestArrivalDate>2013-10-04T06:59:59Z</LatestArrivalDate>
            <FulfillmentPreviewItems>
              <member>
                <EstimatedShippingWeight>
                  <Unit>POUNDS</Unit>
                  <Value>3.541</Value>
                </EstimatedShippingWeight>
                <SellerSKU>EMPR-2030-21630</SellerSKU>
                <SellerFulfillmentOrderItemId>C1E7E34227D811E392217F8E3DE391E7</SellerFulfillmentOrderItemId>
                <ShippingWeightCalculationMethod>Dimensional</ShippingWeightCalculationMethod>
                <Quantity>1</Quantity>
              </member>
            </FulfillmentPreviewItems>
            <EarliestShipDate>2013-09-30T07:00:00Z</EarliestShipDate>
            <EarliestArrivalDate>2013-10-03T07:00:00Z</EarliestArrivalDate>
          </member>
        </FulfillmentPreviewShipments>
        <EstimatedFees>
          <member>
            <Amount>
              <CurrencyCode>USD</CurrencyCode>
              <Value>3.00</Value>
            </Amount>
            <Name>FBAPerUnitFulfillmentFee</Name>
          </member>
          <member>
            <Amount>
              <CurrencyCode>USD</CurrencyCode>
              <Value>7.00</Value>
            </Amount>
            <Name>FBAPerOrderFulfillmentFee</Name>
          </member>
          <member>
            <Amount>
              <CurrencyCode>USD</CurrencyCode>
              <Value>2.00</Value>
            </Amount>
            <Name>FBATransportationFee</Name>
          </member>
        </EstimatedFees>
        <IsFulfillable>true</IsFulfillable>
        <UnfulfillablePreviewItems/>
      </member>
      <member>
        <EstimatedShippingWeight>
          <Unit>POUNDS</Unit>
          <Value>4</Value>
        </EstimatedShippingWeight>
        <ShippingSpeedCategory>Expedited</ShippingSpeedCategory>
        <FulfillmentPreviewShipments>
          <member>
            <LatestShipDate>2013-09-28T22:00:00Z</LatestShipDate>
            <LatestArrivalDate>2013-10-02T06:59:59Z</LatestArrivalDate>
            <FulfillmentPreviewItems>
              <member>
                <EstimatedShippingWeight>
                  <Unit>POUNDS</Unit>
                  <Value>3.541</Value>
                </EstimatedShippingWeight>
                <SellerSKU>EMPR-2030-21630</SellerSKU>
                <SellerFulfillmentOrderItemId>C1E7E34227D811E392217F8E3DE391E7</SellerFulfillmentOrderItemId>
                <ShippingWeightCalculationMethod>Dimensional</ShippingWeightCalculationMethod>
                <Quantity>1</Quantity>
              </member>
            </FulfillmentPreviewItems>
            <EarliestShipDate>2013-09-28T22:00:00Z</EarliestShipDate>
            <EarliestArrivalDate>2013-10-01T07:00:00Z</EarliestArrivalDate>
          </member>
        </FulfillmentPreviewShipments>
        <EstimatedFees>
          <member>
            <Amount>
              <CurrencyCode>USD</CurrencyCode>
              <Value>3.00</Value>
            </Amount>
            <Name>FBAPerUnitFulfillmentFee</Name>
          </member>
          <member>
            <Amount>
              <CurrencyCode>USD</CurrencyCode>
              <Value>10.00</Value>
            </Amount>
            <Name>FBAPerOrderFulfillmentFee</Name>
          </member>
          <member>
            <Amount>
              <CurrencyCode>USD</CurrencyCode>
              <Value>2.40</Value>
            </Amount>
            <Name>FBATransportationFee</Name>
          </member>
        </EstimatedFees>
        <IsFulfillable>true</IsFulfillable>
        <UnfulfillablePreviewItems/>
      </member>
    </FulfillmentPreviews>
  </GetFulfillmentPreviewResult>
  <ResponseMetadata>
    <RequestId>b390452a-a11a-435c-a111-1078a65c0cae</RequestId>
  </ResponseMetadata>
</GetFulfillmentPreviewResponse>
