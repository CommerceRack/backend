package ZPAY::PAYPAL;

use Data::Dumper;
use lib "/backend/lib";
##
## NOTE: This is mostly helper functions that are called by either
## ZPAY::PAYPALEC
## ZPAY::PAYPALWP

# John 402.517.4600


#
# Hi Brian!
#[9:56:32 AM] Melissa Happel: Good to hear from you!  You can log a ticket at www.paypal.com/mts.
#[9:57:35 AM] Melissa Happel: Your login is brian@zoovy.com
#[9:58:19 AM] Melissa Happel: Click on "Contact Support" once you get to that site or you can login with your email address.  (Login is in the upper right corner)
#	psasword is: password1
##
#
#
#



## sandbox: https://api.sandbox.paypal.com/nvp
##	production: https://api.paypal.com/nvp

## DEV: api.sandbox.paypal.com 	66.135.197.162
# patti@zoovy.com
# Credential: 		API Signature
# API Username: 		patti_api1.zoovy.com
# API Password: 		KL5R9HVKRULUN76J
# Signature: 		A28vO9Pwbl8UcqaVx8q.7-boW11LA8oBaHci3G6mke.7f33tPcqU6lHZ
# Request Date: 		Jun. 13, 2007 11:42:06 PDT

## 
## HOW EXPRESS CHECKOUT WORKS:
##
## Start the Checkout Using "SetExpressCheckout"
##	Redirect Customer browser to Paypal Login page
##	Getting Payer Details using GetExpressCheckoutDetails
##	Making a sale using DoExpressCheckoutPayment
##	
##

	## AVSCODE
	##		A Address Only
	##		B Address Only (International A)
	##		C None (International N)
	##		D Address Postal (International X)
	##		E Not allowed MOTO
	##		UK Specific X
	## G Global Unavailable
	## I International Unavailable
	## N No
	## Postal (International Z)
	## R Retry
	##	S Service not supported
	## U Unavailable
	## W Whole Zip
	## X Exact Match Address + (9 digit zip)
	## Y Yes Address + (5 digit zip)
	## Z Zip (Give digit zip only)
	
	## CVV2
	##	M Match
	##	N No Match
	## P Not processed
	## S Service not supported
	## U Unavailable
	## X No response. 



## response format:
##	ACK=Success&TIMESTAMP<time>&CORRELATIONID=&VERSION&BUILD=

sub buildHeader {
	my ($webdb,$api) = @_;

	$api->{'VERSION'} = '58';
	if (($webdb->{'paypal_api_user'} ne '') && ($webdb->{'paypal_api_pass'} ne '') && ($webdb->{'paypal_api_sig'} ne '')) {
		## Paypal considers a "1st Party" transaction one where the user provides their own credentials.
		$api->{'USER'} = $webdb->{'paypal_api_user'};
		$api->{'PWD'} = $webdb->{'paypal_api_pass'};
		$api->{'SIGNATURE'} = $webdb->{'paypal_api_sig'};
		}
	else {
		## Paypal considers a "3rd Party" transaction one where the user authorizes ZOOVY's credentials.
		## the information is for the paypal@zoovy.com account
		## this is the preferred method as of 3/24/09
		$api->{'USER'} = 'paypal_api1.zoovy.com';
		$api->{'PWD'} = 'ERXHXJ9R9QU98TSH';
		$api->{'SIGNATURE'} = 'AIDIxNtcNU6SpJCLnG528On-xf--AkN0-1KdiGeWhowqM21piaG15BaN';
		if ($webdb->{'paypal_api_env'}==1) {
			## SANDBOX
			$api->{'USER'} = 'patti_api1.zoovy.com';
			$api->{'PWD'} = 'KL5R9HVKRULUN76J';
			$api->{'SIGNATURE'} = 'A28vO9Pwbl8UcqaVx8q.7-boW11LA8oBaHci3G6mke.7f33tPcqU6lHZ';
			}
		elsif ($webdb->{'paypal_api_env'}==3) {
			## SANDBOX
			## username: 'lizm_1238020561_biz@zoovy.com'
			$api->{'USER'} = 'lizm_1238020561_biz_api1.zoovy.com',
			$api->{'PWD'} = '1238020587';
			$api->{'SIGNATURE'} = 'AVIodDZ7rRKwta0KKUGchfaXwFiXAVtIJJJ0sBssyTdREn.Vy4JtuBZb';
			$api->{'VERSION'} = '57';
			}
		}

	$api->{'SUBJECT'} = $webdb->{'paypal_email'};
	$api->{'BUTTONSOURCE'}='Zoovy_Cart_DP_US';


#$VAR1 = {
#          'SUBJECT' => 'patti@zoovy.com',
#          'AMT' => '1',
#          'PWD' => 'KL5R9HVKRULUN76J',
#          'RETURNURL' => 'http://brian.zoovy.com/paypal.cgis?mode=express-return',
#          'VERSION' => '2.3',
#          'CANCELURL' => 'http://brian.zoovy.com/cart.cgis',
#          'USER' => 'patti_api1.zoovy.com',
#          'METHOD' => 'SetExpressCheckout',
#          'SIGNATURE' => 'A28vO9Pwbl8UcqaVx8q.7-boW11LA8oBaHci3G6mke.7f33tPcqU6lHZ'
#        };

#	$api->{'SUBJECT'} = 'patti@zoovy.com';
#	$api->{'PWD'} = 'KL5R9HVKRULUN76J';
#	$api->{'SIGNATURE'} = 'A28vO9Pwbl8UcqaVx8q.7-boW11LA8oBaHci3G6mke.7f33tPcqU6lHZ';
#	$api->{'USER'} = 'patti_api1.zoovy.com';


	if ($webdb->{'paypal_api_env'}==1) {
		## we set this to tell doRequest that we're using the sandbox
		$api->{'_isSandbox'} = 1;
		}
	elsif ($webdb->{'paypal_api_env'}==3) {
		## we set this to tell doRequest that we're using the beta sandbox
		$api->{'_isSandbox'} = 3;
		}
	return($api);
	}

##
## posts an actual request to paypal
##
sub doRequest {
	my ($api) = @_;

	require LWP::UserAgent;
	my $ua = LWP::UserAgent->new;
	$ua->timeout(15);
	$ua->env_proxy;

	my $URL = 'https://api.paypal.com/nvp'; 		## THIS IS FOR CERTIFICATES
	$URL = 'https://api-3t.paypal.com/nvp';
		
	my $DEBUG = 0;
	if ((not defined $api->{'_isSandbox'}) || ($api->{'_isSandbox'}==0)) {
		## NO SANDBOX - LIVE!
		}
	elsif ($api->{'_isSandbox'}==1) {
		## SANDBOX
		$DEBUG++;
		delete $api->{'_isSandbox'};
		$URL = 'https://api.sandbox.paypal.com/nvp';
		$URL = 'https://api.sandbox.paypal.com/nvp';
		}
	elsif ($api->{'_isSandbox'}==3) {
		## SANDBOX
		$DEBUG++;
		delete $api->{'_isSandbox'};
		$URL = 'https://api-3t.beta-sandbox.paypal.com/nvp';
		}

	print STDERR "URL: $URL\n";

	my $RETRY_ATTEMPTS = 0;
	my %API_DEBUG = ();

	my $response = $ua->post( $URL, $api );

	if ((not $response->is_success()) && ($response->code() == 500)) {
		## paypal seems to go down *A LOT* so we're going to add an automatic retry on 500 errors
		sleep(1);
		$response = $ua->post( $URL, $api );
		$RETRY_ATTEMPTS++;
		# print STDERR Data::Dumper::Dumper($api,$response);
		}

	my $result = undef;
	if ($response->is_success) {
		$result = &ZTOOLKIT::parseparams($response->content());
		}
	else {
		$result = { 'ERR'=>$response->status_line() };
		$DEBUG++;
		}

	if ($RETRY_ATTEMPTS>0) {
		$result{'RETRY_ATTEMPTS'} = $RETRY_ATTEMPTS;
		}

#	$DEBUG++;
	if ($DEBUG) {
		open F, sprintf(">>%s/paypal.log",&ZOOVY::tmpfs());
		print F "--------- ".&ZTOOLKIT::pretty_date(time(),1)." - [$URL]\n";
		print F &ZTOOLKIT::buildparams($api)."\n";
		print F &ZTOOLKIT::buildparams($result)."\n";
		if ($result->{'ACK'} eq 'Failure') {
			print F Data::Dumper::Dumper($SITE::CART2);
			}
		close F;
		}

 	return($result);
	}





##
## takes the same options parameter.
##
sub buildOrder {
	my ($api,$O2,%options) = @_;

	my $USERNAME = $O2->username();

	my $webdb = $options{'webdb'};
	if (not defined $webdb) { 
		$webdb = &ZWEBSITE::fetch_website_dbref($O2->username(),$O2->prt()); 
		}

	## https://developer.paypal.com/webapps/developer/docs/classic/paypal-payments-pro/integration-guide/WPDPGettingStarted/

	$api->{'INVNUM'} = $O2->oid();
	$api->{'IPADDRESS'} = $O2->in_get('cart/ip_address');
	if ($api->{'IPADDRESS'} =~ /,[\s]*(.*?)$/) { $api->{'IPADDRESS'} = $1; }
	$api->{'FIRSTNAME'} = $O2->in_get('bill/firstname');
	$api->{'LASTNAME'} = $O2->in_get('bill/lastname');
	$api->{'STREET'} = $O2->in_get('bill/address1');
	$api->{'STREET2'} = $O2->in_get('bill/address2');
	$api->{'CITY'} = $O2->in_get('bill/city');
	$api->{'STATE'} = $O2->in_get('bill/region');
	$api->{'ZIP'} = $O2->in_get('bill/postal');
	$api->{'COUNTRYCODE'} = $O2->in_get('bill/countrycode');

	$api->{'SHIPTONAME'} = $O2->in_get('ship/firstname').' '.$O2->in_get('ship/lastname');
	$api->{'SHIPTOSTREET'} = $O2->in_get('ship/address1');
	$api->{'SHIPTOSTREET2'} = $O2->in_get('ship/address2');
	$api->{'SHIPTOCITY'} = $O2->in_get('ship/city');
	$api->{'SHIPTOSTATE'} = $O2->in_get('ship/region');
	$api->{'SHIPTOCOUNTRYCODE'} = $O2->in_get('ship/countrycode');
	if ($api->{'SHIPTOCOUNTRYCODE'} eq '') {
		$api->{'SHIPTOCOUNTRYCODE'} = &ZPAY::PAYPAL::resolve_country($O2->in_get('ship/country'));
		}
	$api->{'SHIPTOPHONENUM'} = $O2->in_get('ship/phone');
	$api->{'SHIPTOZIP'} = $O2->in_get('ship/postal');

	$api->{'ITEMAMT'} = &ZPAY::PAYPAL::currency($O2->in_get('sum/items_total'));
	$api->{'SHIPPINGAMT'} = &ZPAY::PAYPAL::currency($O2->in_get('sum/shp_total'));
	$api->{'HANDLINGAMT'} = &ZPAY::PAYPAL::currency($O2->in_get('sum/bnd_total')+$O2->in_get('sum/hnd_total')+$O2->in_get('sum/ins_total'));
	$api->{'TAXAMT'} = &ZPAY::PAYPAL::currency($O2->in_get('sum/tax_total'));
	
	my $taxrate = $O2->in_get('our/tax_rate');

	my $stuff2 = $O2->stuff2();
	my $c = 0;
	foreach my $item (@{$stuff2->items()}) {
		my $stid = $item->{'stid'};
		$api->{'L_NAME'.$c} = $item->{'prod_name'};
		$api->{'L_NUMBER'.$c} = $stid;
		$api->{'L_QTY'.$c} = $item->{'qty'};
		$api->{'L_TAXAMT'.$c} = 0;
## --- 
##		if (&ZOOVY::is_true($item->{'taxable'}) && ($taxrate>0)) {
##			$api->{'L_TAXAMT'.$c} = currency( ($item->{'base_price'} * $taxrate) / 100);
##			}
##
		# $api->{'L_AMT'.$c} = currency($item->{'base_price'});
		$api->{'L_AMT'.$c} = currency($item->{'price'});

#		if ($USERNAME ne 'nyciwear') {}
#		elsif (uc($item->{'mkt'}) eq 'EBAY') {
#			## apparently these fields are required for buyer protection
#			$api->{'CHANNELTYPE'} = 'eBayItem';
#			my ($mktid,$mkttrans) = split(/-/,$item->{'mktid'},2);
#
#			$api->{'L_EBAYITEMNUMBER'.$c} = $mktid;
#			$api->{'L_EBAYITEMAUCTIONTXNID'.$c} = $mkttrans;
#			}

		$c++;
		}


	$api->{'NOTIFYURL'} = "https://webapi.zoovy.com/webapi/paypal/notify.cgi/$USERNAME";

	return($api);
	}


## https://www.paypal.com/express-checkout-buttons
#sub checkout_button {
#	my $image = qq~<img src="https://www.paypal.com/en_US/i/btn/btn_xpressCheckoutsm.gif" align="left" style="margin-right:7px;">~;
#	}

sub resolve_country {
	my ($countryname) = @_;

	$countryname = uc($countryname);

	my $country = '';
	
	if ($countryname eq '') { $country = 'US'; }
	elsif (length($countryname)<3) { $country = $countryname; }	# already a countrycode
	elsif ($countryname eq 'UNITED STATES') { $country = 'US'; }
	elsif ($countryname eq 'USA') { $country = 'US'; }
	elsif ($countryname eq 'IRELAND') { $country = 'UK'; }
	else {
		require ZSHIP;
		my ($countryref) = &ZSHIP::resolve_country(ZOOVY=>$countryname);
		$country = $countryref->{'PAYPAL'};
		if ($country eq '') { $country = $countryref->{'ISO'}; }
		}

	return($country); 
	}




sub currency {
	my ($x) = @_;
	$x = sprintf("%.2f",$x);	
	return($x);
	}







1;