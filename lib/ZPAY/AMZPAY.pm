package ZPAY::AMZPAY;

use strict;
use Data::Dumper qw();
use MIME::Base64 qw();
use XML::Simple qw();
use lib "/backend/lib";
require ZOOVY;
require ZTOOLKIT;
require ZWEBSITE;
require ZSHIP;
require CART2;

## http://docs.amazonwebservices.com/AmazonFPS/2007-01-08/FPSDeveloperGuide/
# http://amazonpayments.s3.amazonaws.com/documents/ImplementationGuideXML.pdf

# http://static.zoovy.com/merchant/redford/TICKET_321209-Checkout_by_Amazon_Prime_US.pdf

sub simplePayButton {
	my ($USERNAME,$webdbref) = @_;

return(qq~
<form action="https://authorize.payments.amazon.com/pba/paypipeline" method="post">
  <input type="hidden" name="immediateReturn" value="1" >
  <input type="hidden" name="collectShippingAddress" value="0" >
  <input type="hidden" name="accessKey" value="11SEM03K88SD016FS1G2" >
  <input type="hidden" name="referenceId" value="cart-id-goes-here" >
  <input type="hidden" name="amount" value="USD 100" >
  <input type="hidden" name="variableMarketplaceFee" value="" >
  <input type="hidden" name="signature" value="AquSIdGGLNM2kBDiLWmSvBzYBOo=" >
  <input type="hidden" name="isDonationWidget" value="0" >
  <input type="hidden" name="fixedMarketplaceFee" value="" >
  <input type="hidden" name="description" value="description" >
  <input type="hidden" name="amazonPaymentsAccountId" value="GUMAWHESVISH7E89GIXN87XGAN5EPSDS75PIDF" >
  <input type="hidden" name="ipnUrl" value="http://webapi.zoovy.com/webapi/amazon/ipn.cgi" >
  <input type="hidden" name="returnUrl" value="http://username.zoovy.com/amazon/return" >
  <input type="hidden" name="processImmediate" value="1" >
  <input type="hidden" name="cobrandingStyle" value="banner" >
  <input type="hidden" name="abandonUrl" value="http://username.zoovy.com/amazon/cancel" >
  <input type="image" src="https://authorize.payments.amazon.com/pba/images/SMPayNowWithAmazon.png" border="0">
</form>
~);

	}

sub doRequest {
	my ($USERNAME,$xml) = @_;
	}


sub tag {
	my ($tag,$content) = @_;
	if ($content eq '') { return(); }
	return("<$tag>".&ZOOVY::incode($content)."</$tag>\n");
	}

sub priceTag {
	my ($price) = @_;
	my $tags = &tag("Amount",sprintf("%.2f",$price)).&tag("CurrencyCode","USD");
	$tags =~ s/[\n\r]+//g;
	$tags = "$tags\n";
	return($tags);
	}



##
##
## if options is:
##		shipping=>1		-- include shipping address complex type.
##
sub xmlCart {
	my ($CART2, $SREF, %options) = @_;

	my $USERNAME = $CART2->username();
	my $webdbref = $SREF->webdb();

	my $merchantid = $webdbref->{"amz_merchantid"};

	my $shippingxml = '';
	my $itemshipxml = '';

	## shipping now always pulled from Zoovy
#	if ($webdbref->{'amzpay_shipping'}==0) {
#		my @shipping = ();
#		my ($zip) = $CART->fetch_property('data.ship_zip');
#		if ($zip eq '') { 
#			$CART->save_property('cgi.zip', $webdbref->{'google_dest_zip'}); 
#			}
#		$CART->shipping();
#		my $handling = 0;
#		foreach my $fee ('ship.hnd_total','ship.spc_total','ship.ins_total') {
#			$handling += sprintf("%.2f",$CART->fetch_property($fee));
#			}

#		my $i = 0;
#		foreach my $method (@{$cart->shipmethods()
#			next if ($i++>0); 
#			my $shipid = lc($method); 
#			$shipid =~ s/[^a-z0-9]/_/g;
#			$shipid = "id-$shipid";
#			$itemshipxml .= "  <ShippingMethodId>$shipid</ShippingMethodId>\n";
#	
#			my $price = sprintf("%.2f",$methodsref->{$method} + $handling);
#			$shippingxml .= "<ShippingMethod>\n";
#			$shippingxml .= '  '.&tag("ShippingMethodId",$shipid);
#			$shippingxml .= '  '.&tag("ServiceLevel","Standard");
#			$shippingxml .= "  <Rate>\n";
#			## possible values: "Standard"/"Expedited"/"OneDay"/"TwoDay"/
#			$shippingxml .= "    <ShipmentBased>\n";
#			$shippingxml .= '    '.&priceTag($price);
#			$shippingxml .= "    </ShipmentBased>\n";
#			$shippingxml .= "  </Rate>\n";
#			$shippingxml .= "  <IncludedRegions>";
#			## possible values: "USContinental48States"/"USFull50States"/"USAll"/"WorldAll"
#			$shippingxml .= '  '.&tag("PredefinedRegion","WorldAll");
#			$shippingxml .= "  </IncludedRegions>";
#			#$shippingxml .= "<ExcludedRegions>";
#			#$shippingxml .= "</ExcludedRegions>";
#			#$shippingxml .= &tag("IsPOBoxSupported","true");
#			$shippingxml .= "</ShippingMethod>\n";		
#			}
#		}

	my $itemsxml = '';
	my $promotionsxml = '';
	my $cartpromotionsxml = '';
	foreach my $item (@{$CART2->stuff2()->items()}) {
		my $stid = $item->{'stid'};	
		if ((substr($stid,0,1) eq '%') || (substr($stid,0,1) eq '!')) {
			$promotionsxml .= "<Promotion>";
			$promotionsxml .= &tag("PromotionId",$stid);
			$promotionsxml .= "<Benefit><FixedAmountDiscount>";
			$promotionsxml .= &tag("Amount",sprintf("%.2f",0-$item->{'price'}));
			$promotionsxml .= &tag("CurrencyCode","USD");
			$promotionsxml .= "</FixedAmountDiscount></Benefit>";
			$promotionsxml .= "</Promotion>";
			
			## added per Carol to get Promotions working correctly
			$cartpromotionsxml .= "<CartPromotionId>$stid</CartPromotionId>\n";
			}
		else {
			$itemsxml .= "<Item>";
			$itemsxml .= &tag("SKU",$stid);
			$itemsxml .= &tag("MerchantId",$merchantid);
			$itemsxml .= &tag("Title", $item->{'prod_name'});
			$itemsxml .= &tag("Description", $item->{'prod_desc'});
			$itemsxml .= "<Price>".&priceTag($item->{'price'})."</Price>";
			$itemsxml .= &tag("Quantity", $item->{'qty'});
			if ($item->{'base_weight'}>0) {
				$itemsxml .= "<Weight>".
					&tag("Amount",sprintf("%.2f", $item->{'base_weight'}/16)).
					&tag("Unit","lb").
					"</Weight>\n";
				}
			$itemsxml .= &tag("Description", $item->{'profile'});

			## uncomment to turn off Tax calc callbacks
			#$itemsxml .= &tag("TaxTableId", 'default');

#			if ($itemshipxml ne '') {
#				$itemsxml .= "<ShippingMethodIds>\n";
#				$itemsxml .= $itemshipxml;
#				$itemsxml .= "</ShippingMethodIds>\n";
#				}
			## possible values: "MERCHANT"/"AMAZON_NA"
			$itemsxml .= &tag("FulfillmentNetwork","MERCHANT");
			$itemsxml .= "</Item>\n";
			}
		## end foreach $stid
		}	

	my $xml = "";
	$xml .= qq~<?xml version="1.0" encoding="UTF-8"?>\n~;
	$xml .= qq~<Order xmlns="http://payments.amazon.com/checkout/2008-11-30/">\n~;
	$xml .= &tag("ClientRequestId",$CART2->cartid());
	# $xml .= &tag('ExpirationDate',
	
	$xml .= "<Cart>\n<Items>\n".$itemsxml."</Items>\n$cartpromotionsxml\n</Cart>\n";


	if ($promotionsxml ne '') {
#     <Promotions>
#       <Promotion>
#         <PromotionId>ButtonPromotion-123</PromotionId>
#         <Benefit>
#          <FixedAmountDiscount>
#             <Amount>1.00</Amount>
#             <CurrencyCode>USD</CurrencyCode>
#           </FixedAmountDiscount>
#         </Benefit>
#       </Promotion>
#     </Promotions>
		$xml .= "<Promotions>".$promotionsxml."</Promotions>";
		}

####
#   <ShippingMethods>
#       <ShippingMethod>
#         <ShippingMethodId>ButtonShippingMethod-123</ShippingMethodId>
#         <ServiceLevel>Standard</ServiceLevel>
#         <Rate>
#           <ShipmentBased>
#             <Amount>3.00</Amount>
#             <CurrencyCode>USD</CurrencyCode>
#           </ShipmentBased>
#         </Rate>
#         <IncludedRegions>
#          <PredefinedRegion>USAll</PredefinedRegion>
#         </IncludedRegions>
#       </ShippingMethod>
#     </ShippingMethods>
#	if ($shippingxml ne '') {
#		$xml .= "<ShippingMethods>";
#		$xml .= $shippingxml;
#		$xml .= "</ShippingMethods>";
#		}


	$xml .= &tag("IntegratorId","ZOOVY");
	$xml .= &tag("IntegratorName","ZOOVY");

	my $SDOMAIN = $SREF->sdomain();

	$xml .= &tag("ReturnUrl",($options{'ReturnUrl'})?$options{'ReturnUrl'}:"http://$SDOMAIN/c=".$CART2->cartid()."/amazon.cgis?verb=return");
	$xml .= &tag("CancelUrl",($options{'CancelUrl'})?$options{'CancelUrl'}:"http://$SDOMAIN/c=".$CART2->cartid()."/cart.cgis?amazon-cancel=1");
	$xml .= &tag("YourAccountUrl",($options{'YourAccountUrl'})?$options{'YourAccountUrl'}:"http://$SDOMAIN/customer/amazonlookup");
	# $CART->save_property('chkout.sdomain',$SDOMAIN);

	##
	##/* ENABLE CALLBACKS SECTION*/
	##
	##<OrderCalculationCallbacks>
	##<CalculateTaxRates>true</CalculateTaxRates>
	##<CalculatePromotions>true</CalculatePromotions>
	##<CalculateShippingRates>true</CalculateShippingRates>
	##<OrderCallbackEndpoint>https://my.endpoint.com/receive.php</OrderCallbackEndpoint>
	##<ProcessOrderOnCallbackFailure>true</ProcessOrderOnCallbackFailure>
	##</OrderCalculationCallbacks>
	$xml .= "<OrderCalculationCallbacks>";

	## change to false to turn off Tax calc callbacks
	### callback.cgi will also need to be modified to turn off
	$xml .= &tag("CalculateTaxRates","true");
	$xml .= &tag("CalculatePromotions","false");
	$xml .= &tag("CalculateShippingRates","true");	
	my ($PRT) = $CART2->prt();
	my ($CARTID) = $CART2->cartid();
	$xml .= &tag("OrderCallbackEndpoint","https://webapi.zoovy.com/webapi/amazon/callback.cgi/u=$USERNAME/prt=$PRT/c=$CARTID");
	$xml .= &tag("ProcessOrderOnCallbackFailure","false");   ## order errors if Zoovy doesn't return rates successfully
	$xml .= "</OrderCalculationCallbacks>";

	if ($options{'shipping'}) {
		my $shipxml = '';
		$shipxml .= &tag('Name',$CART2->in_get('ship/firstname').' '.$CART2->in_get('ship/lastname'));
		$shipxml .= &tag('AddressFieldOne',$CART2->in_get('ship/address1'));
		# $shipxml .= &tag('AddressFieldTwo','5868 Owens Ave. #150');
		$shipxml .= &tag('City',$CART2->in_get('ship/city'));
		$shipxml .= &tag('State',$CART2->in_get('ship/region'));
		$shipxml .= &tag('PostalCode',$CART2->in_get('ship/postal'));
		# require ZSHIP;
		#my ($info) = &ZSHIP::resolve_country(ZOOVY=>$CART2->in_get('ship/countrycode'));
		#my ($iso) = $info->{'ISO'};
		#if ($iso eq '') { $iso = 'US'; }
		my $iso = $CART2->in_get('ship/countrycode');
		$shipxml .= &tag('CountryCode',$iso);
		$shipxml = "<ShippingAddress>\n$shipxml</ShippingAddress>\n";
		$xml .= "<ShippingAddresses>\n$shipxml</ShippingAddresses>\n";
		}

	## not used	
	#if ($webdbref->{'amzpay_tax'}==0) {
	#	$xml .= "\n<TaxTables>\n<TaxTable>\n";
	#	$xml .= &tag("TaxTableId","default");
	#	$xml .= "<TaxRules><TaxRule>".
	#		&tag("Rate",sprintf("%0.4f",0.0775)).
	#		&tag("IsShippingTaxed","true").
	#		&tag("PredefinedRegion","USAll").
	#		"</TaxRule></TaxRules>";
	#	$xml .= "</TaxTable>\n</TaxTables>\n";
	#	}

	
	$xml .= qq~</Order>~;
	return($xml);
	}




##
##	note: this does the magic that amazon requires, then &button_html generates the form
##
## returns:
##		ERRCODE  0 for success
##		ERRMSG
##		b64xml, signature, aws-access-key-id
##
sub payment_button_params {
	my ($CART2,$xml) = @_;

	my %R = ();

	my $webdbref = $CART2->webdb();
	$R{'merchantid'} = $webdbref->{"amz_merchantid"};
	$R{'xml'} = $xml;

	if (not defined $CART2) {
		return({'ERRCODE'=>8,"ERRMSG"=>"CART was not passed"});
		}
	elsif (not defined $webdbref) {
		return({'ERRCODE'=>9,"ERRMSG"=>"WEBDB was not passed"});
		}
	elsif (not defined $webdbref->{'amzpay_env'}) {
		## amazon is disabled!
		return({'ERRCODE'=>9,"ERRMSG"=>"amzpay_env is not set in webdb"});
		}
	elsif ($webdbref->{'amzpay_env'}==0) {
		## amazon is disabled!
		return({'ERRCODE'=>10,"ERRMSG"=>"Disabled $webdbref->{'amzpay_env'}"});
		}
	elsif ($R{'merchantid'} eq '') {
		return({"ERRCODE"=>11,"ERRMSG"=>"merchantid not set"});
		}
	if (ref($CART2) ne 'CART2') {
		return({"ERRCODE"=>11,"ERRMSG"=>"amazon payment received cart that was not a valid object"});
		}
	if ($webdbref->{'amz_secretkey'} eq '') {
		return({"ERRCODE"=>12,"ERRMSG"=>"secret key was not set in config"});
		}
	if ($webdbref->{'amz_accesskey'} eq '') {
		return({"ERRCODE"=>12,"ERRMSG"=>"aws access key not set."});
		}
	foreach my $item (@{$CART2->stuff2()->items()}) {
		my $stid = $item->{'stid'};
		if (length($stid)>40) {
			return({"ERRCODE"=>13,"ERRMSG"=>"sorry, amazon payments doesn't support stids longer than 40 characters"});
			}
		}

	
	
	$R{'referenceId'} = $CART2->cartid();

	## note: never share $sk in response
	my $sk = $webdbref->{'amz_secretkey'};
	use Digest::HMAC_SHA1;
	use MIME::Base64;

	$R{'signature'} = Digest::HMAC_SHA1::hmac_sha1($R{'xml'},$sk);
	$R{'signature'} = MIME::Base64::encode_base64($R{'signature'});	

	$R{'b64xml'} = MIME::Base64::encode_base64($R{'xml'});
	$R{'b64xml'} =~ s/[\n\r]+//gs;
	$R{'aws-access-key-id'} = $webdbref->{'amz_accesskey'};

	return(\%R);
	}




##
##
sub button_html {
	my ($CART2,$SREF,%options) = @_;

	my $webdbref = $CART2->webdb();

	my ($xml) = ZPAY::AMZPAY::xmlCart($CART2,$SREF,%options);
	my ($PBP) = &ZPAY::AMZPAY::payment_button_params($CART2,$xml);

	# my ($c) = CART->new("hotnsexymama","d2gd6gvjHWG6XyHWvk868RaJv"); 

	## note: amazon payments only accepts 

	my $btnref = &ZTOOLKIT::parseparams($webdbref->{'amzpay_button'});
	if ($btnref->{'color'} eq '') { $btnref->{'color'} = 'orange'; }
	if ($btnref->{'size'} eq '') { $btnref->{'size'} = 'small'; }
	if ($btnref->{'background'} eq '') { $btnref->{'background'} = 'white'; }

	my $buttonimg = sprintf("https://payments-sandbox.amazon.com/gp/cba/button?ie=UTF8&color=%s&background=%s&size=%s",
		$btnref->{'color'}, $btnref->{'background'}, $btnref->{'size'});

	if (not defined $CART2) {
		## short circuit if no CART
		return("PREVIEW: <img src=\"$buttonimg\">");
		}

	my ($amz_env) = ($webdbref->{'amzpay_env'}==1)?1:0;
	#if (int($CART2->fetch_property('+sandbox'))&3) {
	#	$webdbref->{'amzpay_env'} = 1;
	#	}

	my $merchantid = $webdbref->{"amz_merchantid"};

	my $b64xml = $PBP->{'b64xml'};
	my $signature = $PBP->{'signature'};
	my $awskey = $PBP->{'aws-access-key-id'};
	my $referenceId = $PBP->{'referenceId'};

	if ($PBP->{'ERRCODE'}>0) {
		return("<!-- AWS-ERROR($PBP->{'ERRCODE'}): $PBP->{'ERRMSG'} -->");
		}
	## just a quick sanity check:
	elsif ((not defined $PBP->{'b64xml'}) || ($PBP->{'b64xml'} eq '')) { 
		return("<!-- AWS-ISE: b64xml was not in response from AMZPAY::payment_button_params() -->");
		}
	elsif ((not defined $PBP->{'signature'}) || ($PBP->{'signature'} eq '')) { 
		return("<!-- AWS-ISE: signature was not in response from AMZPAY::payment_button_params() -->");
		}
	elsif ((not defined $PBP->{'aws-access-key-id'}) || ($PBP->{'aws-access-key-id'} eq '')) { 
		return("<!-- AWS-ISE: aws-access-key-id was not in response from AMZPAY::payment_button_params() -->");
		}
	elsif ((not defined $PBP->{'referenceId'}) || ($PBP->{'referenceId'} eq '')) { 
		return("<!-- AWS-ISE: referenceId was not in response from AMZPAY::payment_button_params() -->");
		}

	my $formurl = '';
	if ($webdbref->{'amzpay_env'}==1) {
		## sandbox
		$formurl = "https://payments-sandbox.amazon.com/checkout/$merchantid";
		# $formurl = "https://payments-sandbox.amazon.com/checkout/$merchantid?debug=true";
		}
	else {
		## production
		$formurl = "https://payments.amazon.com/checkout/$merchantid";
		}


 	my $out = '';
	if ($options{'form'}) {
		$out .= qq~<script type="text/javascript" src="https://images-na.ssl-images-amazon.com/images/G/01/cba/js/jquery.js"></script>
<script type="text/javascript" src="https://images-na.ssl-images-amazon.com/images/G/01/cba/js/widget/widget.js"></script>
<form method=POST action="$formurl">
~;
		}


	$out .= qq~
<input type="hidden" name="order-input" value="type:merchant-signed-order/aws-accesskey/1;order:$b64xml;signature:$signature;aws-access-key-id:$awskey">
<input type="image" id="cbaImage" name="cbaImage" src="$buttonimg" onClick="this.form.action='$formurl'; checkoutByAmazon(this.form)">
<!--
<input type="hidden" name="immediateReturn" value="TRUE" />
<input type="hidden" name="referenceId" value="$referenceId" />
<input type="hidden" name="returnUrl" value="" />
<input type="hidden" name="ipnUrl" value="http://webapi.zoovy.com/webapi/amazon/ipn.cgi" />
<input type="hidden" name="processImmediate" value="TRUE" />
-->
~;

	if ($options{'form'}) {
		$out .= '</form>';
		}

	if ($webdbref->{'amzpay_env'}==1) {
		my $safexml = &ZOOVY::incode($xml);
		$out .= qq~<table><tr><td><pre style="font-align: left; font-size: 8pt;">$safexml</pre></td></tr>~;
		}

	return($out);
	}


sub new {
	my ($class,$USERNAME,$WEBDB) = @_;	
	my $self = {}; 
	$self->{'%webdb'} = $WEBDB;
	bless $self, 'ZPAY::AMZPAY'; 
	return($self);
	}


########################################
# AMZPAY
sub authorize { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('AUTHORIZE',$O2,$payrec,$payment)); }
sub capture { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CAPTURE',$O2,$payrec,$payment)); }
sub charge { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CHARGE',$O2,$payrec,$payment)); }
sub void { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('VOID',$O2,$payrec,$payment)); }
sub credit { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CREDIT',$O2,$payrec,$payment)); } 


sub unified {
	my ($self,$VERB,$o,$payrec,$payment) = @_;

	$payrec->{'ps'} = 900;

	return($payrec);
	}


1;