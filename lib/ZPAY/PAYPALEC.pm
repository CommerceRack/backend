package ZPAY::PAYPALEC;

use strict;

use lib "/backend/lib";
require ZWEBSITE;
require ZPAY;
require ZPAY::PAYPAL;
require ZPAY::PAYPALWP;


## API CALL REFERENCE:
# https://www.x.com/developers/paypal/documentation-tools/api

## some helpful guides
# https://cms.paypal.com/cms_content/US/en_US/files/developer/PP_ExpressCheckout_IntegrationGuide.pdf
# https://cms.paypal.com/us/cgi-bin/?cmd=_render-content&content_ID=developer/e_howto_html_authcapture

##
## NOTE: paypal supports multiple authorizations/captures up to 115% of the original auth amount
##

# SAMPLE REQUEST:
#AMT=111%2e37&BUTTONSOURCE=Zoovy_Cart_EC_US&CITY=&COUNTRYCODE=US&FIRSTNAME=Tim&HANDLINGAMT=0%2e00&INVNUM=2010%2d11%2d6315&IPADDRESS=&ITEMAMT=99%2e95&L_AMT0=99%2e95&LASTNAME=Henson&L_NAME0=Apple+Factory+Refurbished+MC037LL%2fA+Blue+iPod+Nano+8+GB&L_NUMBER0=MC037LLA&L_QTY0=1&L_TAXAMT0=0&METHOD=DoExpressCheckoutPayment&NOTIFYURL=https%3a%2f%2fwebapi%2ezoovy%2ecom%2fwebapi%2fpaypal%2fnotify%2ecgi%2ftting&PAYERID=WFNVZ2U76YZS4&PAYMENTACTION=Sale&PWD=S4LU2JUY7HH6RSJR&SHIPPINGAMT=11%2e42&SHIPTOCITY=Benton&SHIPTOCOUNTRYCODE=US&SHIPTONAME=Tim+Henson&SHIPTOPHONENUM=&SHIPTOSTATE=KY&SHIPTOSTREET=13668+Hwy+68E%2e&SHIPTOSTREET2=&SHIPTOZIP=42025&SIGNATURE=ASyWoD0QEUiut0IDG0AZEfaI14VoAxq7bQmYXHVJDE39GiNgS35Xd3ca&STATE=&STREET=&SUBJECT=stevenkim%40tting%2ecom&TAXAMT=0%2e00&TOKEN=EC%2d7MA05553RJ860674W&USER=stevenkim_api1%2etting%2ecom&VERSION=58&ZIP=
# SAMPLE RESPONSE:
#ACK=Success&AMT=111%2e37&BUILD=1613293&CORRELATIONID=64b457a43888a&CURRENCYCODE=USD&FEEAMT=2%2e42&INSURANCEOPTIONSELECTED=false&ORDERTIME=2010%2d11%2d16T02%3a42%3a25Z&PAYMENTSTATUS=Completed&PAYMENTTYPE=instant&PENDINGREASON=None&PROTECTIONELIGIBILITY=Eligible&REASONCODE=None&SHIPPINGOPTIONISDEFAULT=false&TAXAMT=0%2e00&TIMESTAMP=2010%2d11%2d16T02%3a42%3a26Z&TOKEN=EC%2d7MA05553RJ860674W&TRANSACTIONID=4WS91214542161530&TRANSACTIONTYPE=cart&VERSION=58


# tech support: www.paypal.com/mts
# login: brian@zoovy.com|password1


sub new {
   my ($class,$USERNAME,$webdb) = @_;
   my $self = {};
	$self->{'USERNAME'} = lc($USERNAME);
	$self->{'%webdb'} = $webdb;
   bless $self, 'ZPAY::PAYPALEC';
	return($self);
   }


sub webdb { return($_[0]->{'%webdb'}); }
sub username { return($_[0]->{'USERNAME'}); }

##
##
sub charge {
	my ($self, $O2, $payrec, $payment) = @_; 
	($payrec) = $self->DoExpressCheckoutPayment('CHARGE',$O2,$payrec,$payment);
	return($payrec);
	}

##
##
##
sub authorize {
	my ($self, $O2, $payrec, $payment) = @_; 
	($payrec) = $self->DoExpressCheckoutPayment('AUTHORIZE',$O2,$payrec,$payment);
	return($payrec);
	}


sub capture {
	my ($self, $O2, $payrec, $payment) = @_;

	my %params = ();
	my $webdb = $self->{'%webdb'};
	&ZPAY::PAYPAL::buildHeader($webdb,\%params);
	$params{'METHOD'} = 'DoCapture';

	$params{'AUTHORIZATIONID'} = $payrec->{'auth'};
	# (Required) The authorization identification number of the payment you want to capture. This is the transaction id returned from DoExpressCheckoutPayment or DoDirectPayment.	
	# Character length and limits: 19 single-byte characters maximum.

	$params{'AMT'} = &ZPAY::PAYPAL::currency($payment->{'amt'});
	#(Required) Amount to capture.
	#Limitations: Value is a positive number which cannot exceed $10,000 USD in any currency. No currency symbol. Must have two decimal places, decimal separator must be a period (.), and the optional thousands separator must be a comma (,).

	$params{'CURRENCYCODE'} = 'USD';
	if ($self->username() eq 'pricematters') { $params{'CURRENCYCODE'} = 'CAD'; }
	# (Optional) A three-character currency code. Default: USD.

	$params{'COMPLETETYPE'} = 'Complete';
	# (Required) The value Complete indicates that this the last capture you intend to make.
	# The value NotComplete indicates that you intend to make additional captures.
	# Note:
	# If Complete, any remaining amount of the original authorized transaction is automatically voided and all remaining open authorizations are voided.
	# Character length and limits: 12 single-byte alphanumeric characters.

	$params{'INVNUM'} = $payment->{'uuid'};
	# (Optional) Your invoice number or other identification number that is displayed to the merchant and customer in his transaction history.
	# Note:
	# This value on DoCapture will overwrite a value previously set on DoAuthorization.
	# Note:
	# The value is recorded only if the authorization you are capturing is an order authorization, 
	# not a basic authorization.
	# Character length and limits: 127 single-byte alphanumeric characters.
	# NOTE
	# (Optional) An informational note about this settlement that is displayed to the payer in email and in his transaction history.
	# Character length and limits: 255 single-byte characters.
	# SOFTDESCRIPTOR
	# (Optional) The soft descriptor is a per transaction description of the payment that is passed to the consumer.s credit card statement.
	# If a value for the soft descriptor field is provided, the full descriptor displayed on the customer.s statement has the following format:
	# <PP * | PAYPAL *><Merchant descriptor as set in the Payment Receiving Preferences><1 space><soft descriptor>
	# The soft descriptor can contain only the following characters:
	#    Alphanumeric character, dash, asterisk, period, space
	# If you use any other characters (such as .,.), an error code is returned.
	# The soft descriptor does not include the phone number, which can be toggled between the merchant.s 
	# customer service number and PayPal.s customer service number.
	# The maximum length of the total soft descriptor is 22 characters. Of this, either 4 or 8 characters are used by the PayPal prefix shown in the data format. Thus, the maximum length of the soft descriptor passed in the API request is:
	# 22 - len(<PP * | PAYPAL *>) - len(<Descriptor set in Payment Receiving Preferences> + 1)
	# For example, assume the following conditions:
   # The PayPal prefix toggle is set to PAYPAL * in PayPal.s admin tools.
   # The merchant descriptor set in the Payment Receiving Preferences is set to EBAY.
   #   The soft descriptor is passed in as JanesFlowerGifts LLC.
	# The resulting descriptor string on the credit card would be:
	# PAYPAL *EBAY JanesFlow 

	my $RESULT = undef;
	my $api = undef;
	if (not $RESULT) {
		$api = &ZPAY::PAYPAL::doRequest(\%params);
		}
	
   if ($api->{'ERR'}) {
		$RESULT = "289|$api->{'ERR'}";
      }
   elsif ($api->{'ACK'} eq 'Failure') {
      # TIMESTAMP=2007%2d07%2d17T01%3a53%3a12Z&CORRELATIONID=d157a248f0ade&ACK=Failure&L_ERRORCODE0=10002&L_SHORTMESSAGE0=Aut
		$RESULT = sprintf("289|%s:%s",$api->{"L_ERRORCODE0"},$api->{"L_LONGMESSAGE0"});
		if (not defined $payrec->{'auth'}) { $payrec->{'auth'} = $params{'PT'}; }
      }
	elsif ($api->{'ACK'} eq 'Success') {
		## note: we might want to check PAYMENTSTATUS=Completed as well 
		$RESULT = "089|$api->{'L_LONGMESSAGE0'}";
		}
	else {
		$RESULT = "900|Unknown response ACK:$api->{'ACK'}";
		}

	my ($PS,$DEBUG) = split(/\|/,$RESULT,2);
	if (&ZPAY::ispsa($PS,['2','9'])) {
		## type of error so we chain a payment
		my %chain = %{$payrec};
		$chain{'r'} = &ZTOOLKIT::buildparams($api);
		delete $chain{'ts'};
		delete $chain{'debug'};
		delete $chain{'note'};
		$chain{'puuid'} = $chain{'uuid'};
		$chain{'uuid'} = $O2->next_payment_uuid();
		$payrec = $O2->add_payment($payrec->{'tender'},$params{'AMT'},%chain);
		$O2->paymentlog("PAYPALEC DOCAPTURE ADDED TO CHAIN");
		}
	elsif (&ZPAY::ispsa($PS,['0'])) {
		$O2->paymentlog("PAYPALEC DOCAPTURE SET TXN: ".$api->{'TRANSACTIONID'});
		$payrec->{'txn'} = $api->{'TRANSACTIONID'}; # ex: 5LP37255ND963090U
		}
	else {
		$O2->paymentlog("PAYPALEC DOCAPTURE OTHER PS[$PS]");
		}


	$payrec->{'ts'} = time();	
	$payrec->{'ps'} = $PS;
	$payrec->{'note'} = $payment->{'note'};
	$payrec->{'debug'} = $DEBUG;

	$O2->paymentlog("PAYPALEC DOCAPTURE REQUEST: ".&ZTOOLKIT::buildparams(\%params));	
	$O2->paymentlog("PAYPALEC DOCAPTURE RESPONSE: ".&ZTOOLKIT::buildparams($api));	
	$O2->paymentlog("PAYPALEC RESULT: $RESULT");

	return($payrec);
	}


##
## in paypal you can void an order or an authorization.
##
sub void { 
	my ($self, $O2, $payrec, $payment) = @_; 

	my $RESULT = undef;
	my %params = ();
	my $webdb = $self->{'%webdb'};
	&ZPAY::PAYPAL::buildHeader($webdb,\%params);
	$params{'METHOD'} = 'DoVoid';
	# (Required) Must be DoVoid.

	# AUTHORIZATIONID
	# (Required) The original authorization ID specifying the authorization to void or, to void an order, the order ID.
	# Important:
	# If you are voiding a transaction that has been reauthorized, use the ID from the original authorization, 
	# and not the reauthorization.
	# Character length and limits: 19 single-byte characters.
	if (&ZPAY::ispsa($payrec->{'ps'},['1'])) {
		## VOID AUTHORIZATION
		$params{'AUTHORIZATIONID'} = $payrec->{'auth'};
		}
	elsif (&ZPAY::ispsa($payrec->{'ps'},['0','4'])) {
		$params{'AUTHORIZATIONID'} = $payrec->{'auth'};

		# The order ID is the "TRANSACTIONID" returned in the API response.
		# Please note, a DoVoid call can only be made for Authorizations or Orders. If
		# you want to refund payment from a DoExpressCheckoutPayment or DoCapture then a
		# RefundTransaction would be performed.
		# Voiding an order closes it out so an Authorization cannot be made referencing
		# it.

		# $params{'AUTHORIZATIONID'} = 'c7fd0e96b5ad8';
		# $params{'AUTHORIZATIONID'} = '43H32040GY4835005';
		# $params{'AUTHORIZATIONID'} = $O2->oid();
		# $params{'AUTHORIZATIONID'} = $payrec->{'auth'};
		# $params{'AUTHORIZATIONID'} = $payrec->{'txn'};
		## NOTE: TRANSACTIONID this is *NOT* the EC- value (which is called the TOKEN)
		#if ($params{'AUTHORIZATIONID'} =~ /^EC-/) {
		#	## this is a TOKEN so we'll try the 'auth' field
		#	$params{'AUTHORIZATIONID'} = $payrec->{'auth'};
		#	}
		$RESULT = sprintf("900|Paypal only supports void on authorized (non-captured) transactions");
		}
	else {
		$RESULT = sprintf("999|Cannot void a payment status of '%s'",$payrec->{'ps'});
		}

#	$params{'TRANSACTIONID'} = $payrec->{'txn'};
#	## NOTE: TRANSACTIONID this is *NOT* the EC- value (which is called the TOKEN)
#	if ($params{'TRANSACTIONID'} =~ /^EC-/) {
#		## this is a TOKEN so we'll try the 'auth' field
#		$params{'TRANSACTIONID'} = $payrec->{'auth'};
#		}

	# NOTE
	# (Optional) An informational note about this void that is displayed to the payer in 
	# email and in his transaction history.
	# Character length and limits: 255 single-byte characters
	$params{'NOTE'} = $payment->{'note'};

	my $api = undef;
	if (not $RESULT) {
		$api = &ZPAY::PAYPAL::doRequest(\%params);
		}
	
   if ($api->{'ERR'}) {
		$RESULT = "289|$api->{'ERR'}";
      }
   elsif ($api->{'ACK'} eq 'Failure') {
      # TIMESTAMP=2007%2d07%2d17T01%3a53%3a12Z&CORRELATIONID=d157a248f0ade&ACK=Failure&L_ERRORCODE0=10002&L_SHORTMESSAGE0=Aut
		$RESULT = sprintf("289|%s:%s",$api->{"L_ERRORCODE0"},$api->{"L_LONGMESSAGE0"});
      }
	elsif ($api->{'ACK'} eq 'Success') {
		$RESULT = "689|$api->{'L_LONGMESSAGE0'}";
		}
	else {
		$RESULT = "900|Unknown response ACK:$api->{'ACK'}";
		}

	my ($PS,$DEBUG) = split(/\|/,$RESULT,2);
	## type of error so we chain a payment
	my %chain = %{$payrec};
	$chain{'r'} = &ZTOOLKIT::buildparams($api);
	delete $chain{'ts'};
	delete $chain{'debug'};
	delete $chain{'note'};
	$chain{'puuid'} = $chain{'uuid'};
	$chain{'uuid'} = $O2->next_payment_uuid();
	if (substr($PS,0,1) eq '6') {
		## this was a successful void
		$payrec->{'voided'} = time();
		$payrec->{'voidtxn'}  = $chain{'uuid'};	## this doesn't really appear to be used
		}

	($payrec) = $O2->add_payment($payrec->{'tender'},$payrec->{'amt'},%chain);
	$payrec->{'ps'} = $PS;
	$payrec->{'note'} = $payment->{'note'};
	$payrec->{'debug'} = $DEBUG;

	$O2->paymentlog("PAYPALEC DOVOID REQUEST: ".&ZTOOLKIT::buildparams(\%params));	
	$O2->paymentlog("PAYPALEC DOVOID RESPONSE: ".&ZTOOLKIT::buildparams($api));	
	$O2->paymentlog("PAYPALEC RESULT: $RESULT");

	return($payrec);
	}




##
##
##
sub credit { 
	my ($self, $O2, $payrec, $payment) = @_; 

	my %params = ();
	my $webdb = $self->{'%webdb'};
	&ZPAY::PAYPAL::buildHeader($webdb,\%params);

	$params{'NOTE'} = $payment->{'note'};
	$params{'METHOD'} = 'RefundTransaction';
	# (Required) Must be RefundTransaction.

	$params{'TRANSACTIONID'} = $payrec->{'txn'};
	## NOTE: TRANSACTIONID this is *NOT* the EC- value (which is called the TOKEN)
	if ($params{'TRANSACTIONID'} =~ /^EC-/) {
		## this is a TOKEN so we'll try the 'auth' field
		$params{'TRANSACTIONID'} = $payrec->{'auth'};
		}

	# https://cms.paypal.com/us/cgi-bin/?cmd=_render-content&content_ID=developer/e_howto_api_nvp_r_RefundTransaction
	# (Required) Unique identifier of a transaction.
	# Character length and limitations: 17 single-byte alphanumeric characters.

	$params{'INVOICEID'} = $payrec->{'uuid'};
	#if ($params{'INVOICEID'} =~ /^(.*?)Z0$/) {
	#	$params{'INVOICEID'} = $1;
	#	}
	# (Optional) Your own invoice or tracking number.
	# Character length and limitations: 127 single-byte alphanumeric characters

	$params{'REFUNDTYPE'} = 'Partial';
	# Type of refund you are making:
   #   Full - default
   #   Partial
	my $AMT = $payment->{'amt'};
	$params{'AMT'} = $AMT;

	my $RESULT = undef;
	if ($payrec->{'amt'}<=0) {
		$RESULT = "999|Amount must be greater than zero for refunds";
		}
	elsif ($payrec->{'amt'} == $params{'AMT'}) {
		$params{'REFUNDTYPE'} = 'Full';
		delete $params{'AMT'};
		}
	# (Optional) Refund amount.
	# Amount is required if RefundType is Partial.
	# Note:
	# If RefundType is Full, do not set the Amount.
	$params{'CURRENCYCODE'} = 'USD';
	if ($self->username() eq 'pricematters') { $params{'CURRENCYCODE'} = 'CAD'; }
	# A three-character currency code. 
	# This field is required for partial refunds. Do not use this field for full refunds.
	# NOTE
	# (Optional) Custom memo about the refund.
	# Character length and limitations: 255 single-byte alphanumeric characters.


	my $api = undef;
	if (not $RESULT) {
		$api = &ZPAY::PAYPAL::doRequest(\%params);
		}
	
   if ($api->{'ERR'}) {
		$RESULT = "289|$api->{'ERR'}";
      }
   elsif ($api->{'ACK'} eq 'Failure') {
      # TIMESTAMP=2007%2d07%2d17T01%3a53%3a12Z&CORRELATIONID=d157a248f0ade&ACK=Failure&L_ERRORCODE0=10002&L_SHORTMESSAGE0=Aut
		$RESULT = sprintf("289|%s:%s",$api->{"L_ERRORCODE0"},$api->{"L_LONGMESSAGE0"});
      }
	elsif ($api->{'ACK'} eq 'Success') {
		$RESULT = "389|$api->{'L_LONGMESSAGE0'}";
		}
	else {
		$RESULT = "900|Unknown response ACK:$api->{'ACK'}";
		}

	my ($PS,$DEBUG) = split(/\|/,$RESULT,2);
	## type of error so we chain a payment
	my %chain = %{$payrec};
	$chain{'r'} = &ZTOOLKIT::buildparams($api);
	delete $chain{'ts'};
	delete $chain{'debug'};
	delete $chain{'note'};
	$chain{'puuid'} = $chain{'uuid'};
	$chain{'uuid'} = $O2->next_payment_uuid();
	if (defined $api->{'GROSSREFUNDAMT'}) {
		$chain{'amt'} = $api->{'GROSSREFUNDAMT'};
		}
	## NOTE: eventually might want to remove FEEAMT

	($payrec) = $O2->add_payment($payrec->{'tender'},$AMT,%chain);
	$payrec->{'ps'} = $PS;
	$payrec->{'note'} = $payment->{'note'};
	$payrec->{'debug'} = $DEBUG;

	$O2->paymentlog("PAYPALEC DOCREDIT REQUEST: ".&ZTOOLKIT::buildparams(\%params));	
	$O2->paymentlog("PAYPALEC DOCREDIT RESPONSE: ".&ZTOOLKIT::buildparams($api));	
	$O2->paymentlog("PAYPALEC RESULT: $RESULT");

	return($payrec);
	} 



##
##
##
sub GetExpressCheckoutDetails { 
	my ($CART2,$token,$payerid,$paymentQref) = @_;

	my $USERNAME = $CART2->username();
	print STDERR "USERNAME: $USERNAME\n";
	my $webdb = undef;
	if (not defined $webdb) { 
		$webdb = &ZWEBSITE::fetch_website_dbref($CART2->username(),$CART2->prt()); 
		}

	my %params = ();
	&ZPAY::PAYPAL::buildHeader($webdb,\%params);

	# $params{'BUTTONSOURCE'}='Zoovy_Cart_EC_US';
	delete $params{'BUTTONSOURCE'}; 	## PAYPAL TOLD US TO REMOVE FROM GETEXPRESSCHECKOUTDETAILS
	$params{'METHOD'}='GetExpressCheckoutDetails';
	$params{'TOKEN'} = $token;

	my $api = &ZPAY::PAYPAL::doRequest(\%params);		

#$VAR1 = {
#       x   'SHIPTOZIP' => '92024',
#       x   'SHIPTOSTREET' => '430 Pescado Pl.',
#       x   'TIMESTAMP' => '2007-06-14T20:56:08Z',
#       x   'SHIPTOSTATE' => 'CA',
#       x   'SHIPTOCOUNTRYCODE' => 'US',
#       x   'PAYERID' => 'NAJ7P4ATNYGNN',
#       x   'ACK' => 'Success',
#       x   'BUSINESS' => 'Brian',
#       x   'EMAIL' => 'gru3hunt3r@gmail.com',
#       x   'SHIPTONAME' => 'Brian',
#       x   'ADDRESSID' => 'PayPal',
#       x   'BUILD' => '1.0006',
#       x   'SHIPTOCOUNTRYNAME' => 'United States',
#       x   'LASTNAME' => 'horakh',
#       x   'COUNTRYCODE' => 'US',
#       x   'ADDRESSSTATUS' => 'Confirmed',
#       x   'FIRSTNAME' => 'brian',
#       x   'SHIPTOCITY' => 'Encinitas',
#       x   'TOKEN' => 'EC-67336940AE771842M',
#       x   'CORRELATIONID' => '9703663a1af60',
#       x   'PAYERSTATUS' => 'unverified',
#       x   'VERSION' => '2.300000'
#        };

	open F, ">>/dev/shm/paypalec-return";
	use Data::Dumper; print F 'GetExpressCheckoutDetails',Dumper(\%params,$api);
	close F;

	if ($api->{'ACK'} eq 'Success') {
		# Note the 'PT' field below is being copied into the txn field in CHECKOUT.pm (hmm..)
		# this is duct-tape
		my %xc = ();
		tie %xc, 'CART2', 'CART2'=>$CART2;

		my $Pamount = sprintf("%.2f",$xc{'sum/order_total'}*1.1);
		if ($Pamount<20) { $Pamount = 20; }
	
		if ($paymentQref) {
			## paymentQ mode
			$paymentQref->{'PT'} = $api->{'TOKEN'};
			$paymentQref->{'PI'} = $api->{'PAYERID'};
			$paymentQref->{'TE'} = &ZTOOLKIT::pretty_date(time()+3600,3); # tender expiration
			$paymentQref->{'T$'} = $Pamount;
			$paymentQref->{'PS'} = $api->{'PAYERSTATUS'};
			$paymentQref->{'PC'} = $api->{'CORRELATIONID'};
			$paymentQref->{'PZ'} = $api->{'ADDRESSSTATUS'};
			}
		else {
			## LEGACY CART MODE
			$xc{'cart/paypalec_result'} = &ZPAY::packit({
				'TE'=>&ZTOOLKIT::pretty_date(time()+3600,3), 	# tender expiration
				'T$'=>$Pamount,
				'PT'=>$api->{'TOKEN'},
				'PS'=>$api->{'PAYERSTATUS'},
				'PC'=>$api->{'CORRELATIONID'},
				'PI'=>$api->{'PAYERID'},
				'PZ'=>$api->{'ADDRESSSTATUS'},
				});
			#$xc{'data.paypal_token'} = $api->{'TOKEN'};
			#$xc{'data.paypal_payerstatus'} = $api->{'PAYERSTATUS'};
			#$xc{'data.paypal_auth_correlationid'} = $api->{'CORRELATIONID'};
			#$xc{'data.paypal_payerid'} = $api->{'PAYERID'};
			#$xc{'data.paypal_confirmaddr'} = ($api->{'ADDRESSSTATUS'} eq 'Confirmed')?1:0;
			if ($xc{'cart/paypalec_result'} ne '') {
				$xc{'must/payby'} = 'PAYPALEC';
				$xc{'want/payby'} = 'PAYPALEC';
				}
			}

		my $address_changed = 0;

		my @FIELDS = ();
		push @FIELDS, [ 'ship/postal', $api->{'SHIPTOZIP'} ];
		#$xc{'ship/zip'} = $api->{'SHIPTOZIP'};
		push @FIELDS, [ 'ship/city', $api->{'SHIPTOCITY'} ];
		#$xc{'ship/city'} = $api->{'SHIPTOCITY'};
		push @FIELDS, [ 'ship/address1', $api->{'SHIPTOSTREET'} ];
		push @FIELDS, [ 'ship/address2', $api->{'SHIPTOSTREET2'} ];
		#$xc{'ship/address1'} = $api->{'SHIPTOSTREET'};
		#$xc{'ship/address2'} = $api->{'SHIPTOSTREET2'};
		push @FIELDS, [ 'ship/region', $api->{'SHIPTOSTATE'} ];
		#$xc{'ship/region'} = $api->{'SHIPTOSTATE'};

		# my ($ccref) = &ZSHIP::resolve_country(PAYPAL=> $api->{'SHIPTOCOUNTRYCODE'}, ISO=>$api->{'SHIPTOCOUNTRYCODE'});
		push @FIELDS, [ 'ship/countrycode', $api->{'SHIPTOCOUNTRYCODE'} ];

		push @FIELDS, [ 'bill/address1', '' ];
		push @FIELDS, [ 'bill/address2', '' ];
		push @FIELDS, [ 'bill/city', '' ];
		push @FIELDS, [ 'bill/region', '' ];
		push @FIELDS, [ 'bill/postal', '' ];
		push @FIELDS, [ 'bill/countrycode', $api->{'COUNTRYCODE'} ];

		#$xc{'ship/countrycode'} = $api->{'SHIPTOCOUNTRYCODE'};
		## push @FIELDS, [ 'ship/country', $ccref->{'Z'} ];
		# $xc{'ship/country'} = $ccref->{'Z'};

		## NOPE: This is what we send to them!
		# $xc{'ship/phone'} = $api->{'SHIPTOPHONE'};
		## NOPE: this is what is returned in an IPN notification (actually it's contact_phone)
		# $xc{'bill/phone'} = $api->{'CONTACTPHONE'};
		if ($api->{'PHONENUM'} ne '') {
			push @FIELDS, [ 'bill/phone', $api->{'PHONENUM'} ];
			}

		# $xc{'bill/phone'} = $api->{'PHONENUM'};
		push @FIELDS, [ 'bill/email', $api->{'EMAIL'} ];
		# $xc{'bill/email'} = $api->{'EMAIL'};
		push @FIELDS, [ 'bill/firstname', $api->{'FIRSTNAME'} ];
		# $xc{'bill/firstname'} = $api->{'FIRSTNAME'};
		push @FIELDS, [ 'bill/lastname', $api->{'LASTNAME'} ];
		# $xc{'bill/lastname'} = $api->{'LASTNAME'};

		push @FIELDS, [ 'ship/company', $api->{'SHIPTONAME'} ];
		# $xc{'ship/company'} = $api->{'SHIPTONAME'};
		push @FIELDS, [ 'ship/firstname', $api->{'FIRSTNAME'} ];
		# $xc{'ship/firstname'} = $api->{'FIRSTNAME'};
		push @FIELDS, [ 'ship/lastname', $api->{'LASTNAME'} ];
		# $xc{'ship/lastname'} = $api->{'LASTNAME'};

		## PAYERSTATUS = 'verified'
		## SHIPPINGCALCULATIONMODE = 'Callback'
		## ADDRESSSTATUS = 'Unconfirmed'		

		foreach my $row (@FIELDS) {
			my ($ZOOVY_CART_FIELD,$PAYPAL_VALUE) = @{$row};
			if ($xc{$ZOOVY_CART_FIELD} eq '') {
				## field in zoovy cart was blank, so no reason to worry (we updated blank)
				$xc{$ZOOVY_CART_FIELD} = $PAYPAL_VALUE;
				}
			elsif ($xc{$ZOOVY_CART_FIELD} eq $api->{$PAYPAL_VALUE}) {
				## two fields are equal, nothing to do.
				}
			else {
				## override cart field and set $address_changed variable (so we can display a warning)
				$address_changed++;
				$xc{$ZOOVY_CART_FIELD} = $PAYPAL_VALUE;
				}
			}
		$api->{'_ADDRESS_CHANGED'} = $address_changed;


		if ($api->{'SHIPPINGCALCULATIONMODE'} eq 'Callback') {
			# 'FedEx 2 Day simple_1270508941
			my $pp_selected_id = $api->{'SHIPPINGOPTIONNAME'};
			$pp_selected_id =~ s/^.*[\s]([a-z0-9\_]+)$/$1/gs;
			foreach my $shipmethod (@{$CART2->shipmethods()}) {
				## duplicated code in addShippingToParams
				my $id = lc($shipmethod->{'id'});
				$id =~ s/[^a-z0-9]/_/g;
				$id = "$id";
				if ($id eq $pp_selected_id) {
					$api->{'_SHIPPING_CHANGED'} = $CART2->set_shipmethod($shipmethod->{'id'});
					}		
				}
			}


		#if (0) {
		#	## okay apparently the SHIPTONAME is often the same as firstname + lastname			
		#	my $x = uc($api->{'SHIPTONAME'});
		#	my $y = uc($api->{'FIRSTNAME'}.' '.$api->{'LASTNAME'});
		#	$x =~ s/[\s]+//g;
		#	$y =~ s/[\s]+//g;
		#	# if ($x eq $y) { $xc{'ship/company'} = ''; }
		#	if ($api->{'SHIPTONAME'} eq '') {}
		#	# otherwise if the first 5 digits are the same.. 
		#	elsif (substr($x,0,5) eq substr($y,0,5)) { $xc{'ship/company'} = ''; }
		#	}


#		if ($api->{'ZIP'} ne '') {
#			$xc{'bill/zip'} = $api->{'ZIP'};
#			$xc{'bill/city'} = $api->{'CITY'};
#			$xc{'bill/address1'} = '';
#			$xc{'bill/address2'} = '';
#			$xc{'bill/state'} = $api->{'STATE'};
#			$xc{'bill/countrycode'} = $api->{'COUNTRYCODE'};
#			($ccref) = &ZSHIP::resolve_country(ISO=> $api->{'COUNTRYCODE'} );
#			$xc{'bill/country'} = $ccref->{'Z'};
#			$xc{'chkout.bill_to_ship'}=1;		## LOCK and do not allow customer to edit
#			}
#		else {
#$VAR1 = {
#          'TIMESTAMP' => '2007-11-12T03:02:54Z',
#          'SHIPTONAME' => 'Kelly Parker',
#          'ADDRESSID' => 'PayPal',
#          'BUILD' => '1.0006',
#          'SHIPTOCOUNTRYNAME' => 'United States',
#          'ADDRESSSTATUS' => 'Confirmed',
#          'VERSION' => '2.300000'
#        };

#			## hmm.. paypal did not pass a billing ZIP  so we'll use the shipping info
#		$xc{'bill/company'} = $api->{'SHIPTONAME'};
#		$xc{'bill/zip'} = $xc{'ship/zip'};
#		$xc{'bill/city'} = $xc{'ship/city'};
#		$xc{'bill/address1'} = $xc{'ship/address1'};
#		$xc{'bill/address2'} = $xc{'ship/address2'};
#		$xc{'bill/state'} = $xc{'ship/region'};
#		$xc{'bill/country'} = $xc{'ship/country'};
#		$xc{'bill/countrycode'} = $xc{'ship/countrycode'};
#		$xc{'chkout.bill_to_ship'}=0;		## LOCK and do not allow customer to edit
#			}
			


#		open F, ">>/tmp/paypal.log";
#		print F "\n\n".Dumper(\%xc)."\n\n";
#		close F;
		
		untie %xc;
#		$CART2->shipping();
#		$CART2->save();
		}

	return($api);
	}


##
## returns a token and URL for a buyer to be sent off to paypal
##		return is a hashref with key "URL"
##
## there are two supported modes:
##		cartec
##		chkoutec
##
sub SetExpressCheckout {
	my ($SITE,$CART2,$mode, %options) = @_;

#	open F, ">/tmp/paypal.log";
#	print F "reset log ".time()."\n";
#	close F;

	my $api = undef;
	my $CARTID = $CART2->cartid();
	if ($CARTID eq '*') {
		$api->{'ERR'} = "Sorry but this is not a real cart.";
		}

	my $USERNAME = $CART2->username();
	my $PRT = $CART2->prt();

	my $webdb = undef;
	if (not defined $webdb) { 
		$webdb = &ZWEBSITE::fetch_website_dbref($CART2->username(),$CART2->prt()); 
		}
	

	my %params = ();
	&ZPAY::PAYPAL::buildHeader($webdb,\%params);
	delete $params{'BUTTONSOURCE'};		## PAYPAL SAID DO NOT PASS BUTTONSOURCE FOR THIS CALL.

	if ($webdb->{'cc_instant_capture'} eq 'NOAUTH_DELAY') {
		$webdb->{'cc_instant_capture'} = 'NEVER';
		}
	if ($webdb->{'cc_instant_capture'} eq '') {
		$webdb->{'cc_instant_capture'} = 'NEVER';	## hmm.. not initialized?
		}

	$params{'METHOD'} = 'SetExpressCheckout';
	$params{'VERSION'} = '109.0';

	if ($webdb->{"cc_instant_capture"} eq 'ALWAYS') {
		## INSTANT CAPTURE!
		$params{'PAYMENTACTION'} = 'Authorization';
		}
	elsif ($webdb->{"cc_instant_capture"} eq 'NEVER') {
		## DELAYED CAPTURE!
		$params{'PAYMENTACTION'} = 'Authorization';
		}

	if ($options{'returnURL'}) {
		$params{'RETURNURL'} = $options{'returnURL'};
		}
	else {
		$params{'RETURNURL'} = $SITE->URLENGINE()->get('paypal_url').'?mode=express-return';
		}

	if ($options{'cancelURL'}) {
		$params{'CANCELURL'} = $options{'cancelURL'};
		}
	else {
		$params{'CANCELURL'} = $SITE->URLENGINE()->get('cart_url');
		}
	$params{'LOCALECODE'} = 'US'; # AU, DE, FR, GB, IT, ES, JP, US, ES

# Regarding LOCALECODE from ticket #194929
#hi Brian, just got this back from paypal
#kevin
#As you have a Spanish PayPal account it is normal that the PayPal payment page
#is display in Spanish even for customer from English speaking country.
#
#In your situation for Spanish PayPal account the ExpressCheckout payement page
#language is set on the settings below.
#1. The value of the variable "LOCALCODE". If this variable is not use it will
#use the point 2.
#2. The language of the Seller PayPal account. If PayPal is not localizing in
#this country language it will go to point 3.
#3. The language of the Internet Browser of your customer
#
#The only solution will be to us the variable "LOCALCODE" with the value US.
#Then when your customer will log on is PayPal accounts of select the country to
#process a credit cart transaction the language will be modify automatically.


	if (int($webdb->{'paypal_api_reqconfirmship'})>0) {
		## To require that the shipping address be a PayPal confirmed address, set REQCONFIRMSHIPPING to 1 in SetExpressCheckout request.
		## Note:
		## The value of REQCONFIRMSHIPPING overrides the setting in your Merchant Account Profile,
		$params{'REQCONFIRMSHIPPING'} = 1; 
		$params{'ADDROVERRIDE'} = 0;
		## note: this doesn't let the customer specify an address OR create a paypal account.
		## so it's really less than ideal if you're only accepting paypal or plan to use it for credit card processing.
		}
	elsif (0) {
		## To suppress the display of the customer.s shipping address on the PayPal web pages, set NOSHIPPING to 1 in SetExpressCheckout request. You might want to do this if you are selling a product or service that does not require shipping.
		# NOSHIPPING=1
		}
	elsif ($mode eq 'chkoutec') {
		## To override the shipping address stored on PayPal, call SetExpressCheckout to set ADDROVERRIDE to 1 and set the shipping address fields (see Table A.11, .Ship to Address (Optional).).
		## The customer cannot edit the address if it has been overridden.
		$params{'ADDROVERRIDE'} = 1;
		$params{'SHIPTONAME'} = '';
		$params{'SHIPTOSTREET'} = '';

		$params{'SHIPTONAME'} = $CART2->in_get('ship/firstname').' '.$CART2->in_get('ship/lastname');
		$params{'SHIPTOSTREET'} = $CART2->in_get('ship/address1');
		$params{'SHIPTOSTREET2'} = $CART2->in_get('ship/address2');
		$params{'SHIPTOCITY'} = $CART2->in_get('ship/city');
		$params{'SHIPTOSTATE'} = $CART2->in_get('ship/region');
		$params{'SHIPTOCOUNTRY'} = &ZPAY::PAYPAL::resolve_country($CART2->in_get('ship/countrycode'));
		$params{'SHIPTOPHONENUM'} = $CART2->in_get('ship/phone');
		$params{'SHIPTOZIP'} = $CART2->in_get('ship/postal');
		## Request
		## [requiredSecurityParameters]&METHOD=SetExpressCheckout&AMT=10.00&
		## RETURNURL=https://www.anycompany.com/orderprocessing/orderreview.html&
		## CANCELURL=https://www.anycompany.com/orderprocessing/shippinginfo.html
		## &SHIPTONAME=Peter+Smith&SHIPTOSTREET=144+Main+St.&SHIPTOCITY=SAN+JOSE
		## &SHIPTOSTATE=CA&SHIPTOCOUNTRYCODE=US&SHIPTOZIP=99911&
		## ADDROVERRIDE=1
		## Response
		## [successResponseFields]&TOKEN=EC-17C76533PL706494P
		}

	## new fields in July 08:
	if (0) {
	#	$params{'L_NAME0'} = 
	#	$params{'L_NUMBER0'} = 
	#	$params{'L_DESC0'} = 
	#	$params{'L_AMT0'} = 
	#	$params{'L_QTY0'} = 
	#	$params{'ITEMAMT'} = 
	#	$params{'TAXAMT'} = 
	#	$params{'SHIPPINGAMT'} =
	#	$params{'HANDLINGAMT'} = 
	#	$params{'INSURANCEAMT'} =
	# 	$params{'AMT'} =
		$params{'ALLOWNOTE'} = 0;
		}


	## L_NAME0 - 
	my $taxrate = $CART2->in_get('our/tax_rate');

##
## APPARENTLY - now line item detail is not necessary in SetExpressCheckout per Jason Chow @ Payapl during 
##					SetExpressCheckout, ONLY during DoExpressCheckout
##
#	my $stuff = $CART2->stuff();
#	my $c = 0;
#	foreach my $stid ($stuff->stids()) {
#		my $iref = $stuff->item($stid);
#		$params{'L_NAME'.$c} = $iref->{'prod_name'};
#		$params{'L_NUMBER'.$c} = $stid;
#		$params{'L_QTY'.$c} = $iref->{'qty'};
#		$params{'L_TAXAMT'.$c} = 0;
###
###	--	TAX AMOUNT per Jason @ PAYPAL
##		if (&ZOOVY::is_true($iref->{'taxable'}) && ($taxrate>0)) {
##			$params{'L_TAXAMT'.$c} = currency( ($iref->{'base_price'} * $taxrate) / 100);
##			}
###
#		$params{'L_AMT'.$c} = currency($iref->{'base_price'});
#		$c++;
#		}

	## NOTE: these probably aren't necessary for paypal.
	$params{'ITEMAMT'} = &ZPAY::PAYPAL::currency($CART2->in_get('sum/items_total'));
	# $CART2->shipping();
	$CART2->set_shipmethod('');

#	print 'SELECTEDPRICE:'.$CART2->fetch_property('ship.selected_price')."\n";
#	die();

	$params{'SHIPPINGAMT'} = &ZPAY::PAYPAL::currency($CART2->in_get('sum/shp_total'));
	$params{'HANDLINGAMT'} = &ZPAY::PAYPAL::currency($CART2->in_get('sum/hnd_total')+$CART2->in_get('sum/spc_total'));
	$params{'TAXAMT'} = &ZPAY::PAYPAL::currency($CART2->in_get('sum/tax_total'));
	$params{'INSURANCEAMT'} = &ZPAY::PAYPAL::currency($CART2->in_get('sum/bnd_total')+$CART2->in_get('sum/ins_total'));

	# $webdb->{'paypal_api_callbacks'} = 0;

	$webdb->{'paypal_api_callbacks'} = 1;		# turn them on by default.
	if ($params{'SHIPPINGAMT'} == 0) {
		## no need for callbacks, there is no shipping.
		$webdb->{'paypal_api_callbacks'} = 0;
		}
	elsif ($CART2->has_giftcards()) {
		## turn off callbacks for giftcards.
		$webdb->{'paypal_api_callbacks'} = 0;
		}
	elsif ($options{'useMobile'}) {
		## turn off callbacks for mobile (not supported)
		$webdb->{'paypal_api_callbacks'} = 0;
		}

	## 9/10/11 - it appears that paypal likes contents even if callbacks are off, 
	my $i = 0;
	my $ITEMAMT = 0;
	foreach my $item (@{$CART2->stuff2()->items()}) {
		next if ($item->{'qty'} == 0);
		$params{'L_NAME'.$i} = $item->{'prod_name'};
		$params{'L_DESC'.$i} = substr($item->{'description'},0,45);
		$params{'L_QTY'.$i} = $item->{'qty'};
		$params{'L_AMT'.$i} = sprintf("%.2f",$item->{'price'});
		$params{'L_ITEMWEIGHTVALUE'.$i} = $item->{'weight'}/16;
		$params{'L_ITEMWEIGHTUNIT'.$i} = 'lbs';
		$ITEMAMT += ($params{'L_AMT'.$i} * $params{'L_QTY'.$i});
		$i++;
		}

	if (int($webdb->{'paypal_api_callbacks'})==0) {
		## NO CALLBACKS
		$params{'AMT'} = $params{'SHIPPINGAMT'}+$params{'TAXAMT'}+$params{'INSURANCEAMT'}+$params{'ITEMAMT'}+$params{'SHIPDISCAMT'}+$params{'HANDLINGAMT'};
		}
	else {
		## CALLBACKS!

		require ZPAY::PAYPALWP;
		my ($SHIPAMT) = &ZPAY::PAYPALEC::addShippingToParams($CART2,\%params);

#		$params{'INSURANCEOPTIONOFFERED'} = 'false';
#		$params{'INSURANCEAMT'} = '0.00';
#		$params{'TAXAMT'} = '0.00';

		$params{'SHIPDISCAMT'} = '0';
		$params{'SHIPPINGAMT'} = $SHIPAMT;
#		delete $params{'SHIPPINGAMT'};

		$params{'AMT'} = $params{'SHIPPINGAMT'}+$params{'TAXAMT'}+$params{'INSURANCEAMT'}+$params{'ITEMAMT'}+$params{'SHIPDISCAMT'}+$params{'HANDLINGAMT'};

		$params{'CURRENCYCODE'} = 'USD';

		## turning off ALLOWNOTE, this should now use the merchants paypal settings.		
		# $params{'ALLOWNOTE'} = '1';

		$params{'CALLBACK'} = "https://webapi.zoovy.com/webapi/paypal/ec-callback.cgi/USERNAME=$USERNAME/PRT=$PRT/C=$CARTID/V=1";
		# $params{'CALLBACK'} = 'https://www.ppcallback.com/callback.pl';
		$params{'CALLBACKTIMEOUT'} = 10;
		$params{'MAXAMT'} = '5000.00';
		}

#	if ($webdb->{'paypal_paylater'}>0) {
#		## PAYPAL PAY LATER SUPPORT
#		$params{'L_PROMOCODE0'} = 101;
#		}
#	open F, ">/tmp/foo";
#	print F Dumper(\%p);
#	close F;

	if ($options{'useMobile'}) {
		## delete $params{'SHIPDISCAMT'};		## has no impact
		$params{'LANDINGPAGE'} = 'Login';		## can also be 'Billing'
		## $params{'LOCALECODE'} = 'US';			## has no impact
		$params{'CHANNELTYPE'} = 'merchant';
		$params{'SOLUTIONTYPE'} = 'mark';
		$params{'PAYMENTACTION'} = 'Sale';		## definitely required for mobile (barf on paypal side without)
		$params{'VERSION'} = '109.0';
		}

	##
	## NOTE: AMT computation must be at the bottom so the totals match up with whatever we selected for shipping.
	##

	## let's be clear, if ITEMAMT is set then AMT must match the totals
	$params{'AMT'} = $params{'SHIPPINGAMT'}+$params{'TAXAMT'}+$params{'INSURANCEAMT'}+$params{'ITEMAMT'}+$params{'SHIPDISCAMT'}+$params{'HANDLINGAMT'};

#	if (not defined $params{'AMT'}) {
#		$params{'AMT'} = $CART2->in_get('sum/balance_due_total');
#		}
#	if (not defined $params{'AMT'}) {
#		$params{'AMT'} = $CART2->in_get('sum/order_total');
#		}
#	if (($params{'AMT'} eq '') || ($params{'AMT'}==0)) {
#		## not sure why this line is here.
#		($params{'AMT'}) = $CART2->in_get('sum/items_total');
#		}

	if ($params{'AMT'}==0) {
		$params{'ZOOVY_CART_ID'} = $CART2->cartid();
		}
	$params{'AMT'} = sprintf("%.2f",$params{'AMT'});

	if ($CART2->username() eq 'pricematters') { $params{'CURRENCYCODE'} = 'CAD'; }

	if (not defined $api) {	


		$api = &ZPAY::PAYPAL::doRequest(\%params);

		open F, ">/tmp/paypalec.xyz";
		print F Dumper(\%params,$api);
		close F;

		}


	### NOTE: SetExpressCheckout has a modified error handler
	##			 ** THIS IS ON PURPOSE **
	##			 because it must generate a URL to the paypal system.
   if ($api->{'ERR'}) {
		$api->{'%request'} = \%params;
      }
   elsif ($api->{'ACK'} eq 'Failure') {
      # TIMESTAMP=2007%2d07%2d17T01%3a53%3a12Z&CORRELATIONID=d157a248f0ade&ACK=Failure&L_ERRORCODE0=10002&L_SHORTMESSAGE0=Aut
		$api->{'%request'} = \%params;
      }
   else {
      $CART2->in_set('cart/paypal_token',$api->{'TOKEN'});

		my $kvpairs = 'cmd=_express-checkout&token='.$api->{'TOKEN'};
		## http://www.paypalobjects.com/webstatic/en_US/developer/docs/pdf/PP_MECL_Developer_Guide_and_Reference_iOS_1_0_3.pdf
		if ($options{'useMobile'}) {
			## https://developer.paypal.com/docs/classic/express-checkout/integration-guide/ECOnMobileDevices/
			## note: docs say *both* expresscheckout-mobile and express-checkout-mobile
			$kvpairs = sprintf('cmd=_express-checkout-mobile&token=%s',$api->{'TOKEN'});
			if ($options{'drt'}) { $kvpairs = sprintf("%s&useraction=%s",$kvpairs,$options{'drt'}); }
			if ($options{'useraction'}) { $kvpairs = sprintf("%s&useraction=%s",$kvpairs,$options{'useraction'}); }
			}

      if ($webdb->{'paypal_api_env'}==1) {
         ## staging/sandbox
         $api->{'URL'} = "https://www.sandbox.paypal.com/cgi-bin/webscr?$kvpairs";
         }
		elsif ($webdb->{'paypal_api_env'}==3) {
         ## staging/sandbox
         $api->{'URL'} = "https://www.beta-sandbox.paypal.com/cgi-bin/webscr?$kvpairs";
         }
      else {
         ## production
         $api->{'URL'} = "https://www.paypal.com/cgi-bin/webscr?$kvpairs";
         }
      }

	# print STDERR Dumper(\%params,$api);


	return($api);
	}







##
## Note: this function is only called from ONE PLACE
##			ZPAY::private_order_initialize
##
sub DoExpressCheckoutPayment {
	my ($self,$VERB,$O2,$payrec,$payment) = @_;

	my ($USERNAME) = $self->username();
	my $webdb = $self->webdb();

	if (not defined $webdb) { 
		$webdb = &ZWEBSITE::fetch_website_dbref($USERNAME,$O2->prt()); 
		}
	# my $attribs = $o->get_attribs();

	my %params = ();
	&ZPAY::PAYPAL::buildOrder(\%params,$O2,{webdb=>$webdb});
	&ZPAY::PAYPAL::buildHeader($webdb,\%params);

	if ((not defined $payment->{'PT'}) || ($payment->{'PT'} eq '')) {
		## this should NEVER happen
		$params{'TOKEN'} = "TOKEN_NOT_IN_PAYMENT";
		}
	else {
		$params{'TOKEN'} = $payment->{'PT'};
		}

	$params{'METHOD'} = 'DoExpressCheckoutPayment';
	$params{'BUTTONSOURCE'}='Zoovy_Cart_EC_US';

	#if ($webdb->{'cc_instant_capture'} eq 'NOAUTH_DELAY') {
	#	$webdb->{'cc_instant_capture'} = 'NEVER';
	#	}
	#if ($webdb->{'cc_instant_capture'} eq '') {
	#	$webdb->{'cc_instant_capture'} = 'NEVER';	## hmm.. not initialized?
	#	}

#
# sale = normal transaction, payment is made instantly
# 
# authorization =  payment is not captured immediately, but an authorization for the amount is made.  You have to make the product and are not sure what the shipping charges are.  You can capture up to 115% of the authorized amount. Funds can be captured within a three day period. Anything beyond that you can reset. The funds can be captured through the PayPal account.
# 
# order = same as the authoirzation, but you need an interface to capture the funds. this can't be done through the account.
# 
# payment_status is set to those values. The rest of the information is not affected and is passed for a normal transaction.
#

	#if ($options{'PAYMENTACTION'} eq 'Sale') {
	#	## Manually override the store capture settings (a delayed capture)
	#	$params{'PAYMENTACTION'} = 'Sale';
	#	}
	if ($VERB eq 'CHARGE') {
		$params{'PAYMENTACTION'} = 'Sale';
		}
	elsif ($VERB eq 'AUTHORIZE') {
		$params{'PAYMENTACTIONSPECIFIED'} = '1';
		$params{'PAYMENTACTION'} = 'Authorization';
#An authorization payment action represents an agreement to pay and places the buyer.s funds
#on hold for up to three days.
#To set up an authorization, specify the following payment action in your
#SetExpressCheckout and DoExpressCheckoutPayment requests:
#PAYMENTACTION=Authorization
#An authorization enables you to capture multiple payments up to 115% of, or USD $75 more
#than, the amount you specify in the DoExpressCheckoutPayment request. Choose this
#payment action if you need to ship the goods before capturing the payment or if there is some
#reason not to accept the payment immediately.
#The honor period, for which funds can be held, is three days. The valid period, for which the
#authorization is valid, is 29 days. You can reauthorize the 3-day honor period at most once
#within the 29-day valid period.
#You can void an authorization, in which case, the uncaptured part of the amount specified in
#the DoExpressCheckoutPayment request becomes void and can no longer be captured. If
#no part of the payment has been captured, the entire payment becomes void and nothing can be
#captured.
		}

	# (Optional) How you want to obtain payment:
	#. Authorization indicates that this payment is a basic authorization subject to
	# settlement with PayPal Authorization & Capture.
	# . Sale indicates that this is a final sale for which you are requesting payment.
	#Character length and limit: Up to 13 single-byte alphabetic characters.
	# Defa ult: Sale
	# NOTE: Order is not allowed for Direct Payment.

	#elsif ($webdb->{'cc_instant_capture'} eq 'ALWAYS') {
	#	## INSTANT CAPTURE!
	#	$params{'PAYMENTACTION'} = 'Sale';
	#	}
	#elsif ($webdb->{"cc_instant_capture"} eq 'NEVER') {
	#	## DELAYED CAPTURE!
	#	$params{'PAYMENTACTIONSPECIFIED'} = '1';
	#	$params{'PAYMENTACTION'} = 'Authorization';
	#	}
	else {
		## this should NEVER be reached!
		$params{'PAYMENTACTION'} = 'UNKNOWN';
		}
	# $params{'PAYMENTACTION'} = 'Sale';	#  this works
	#$params{'PAYMENTACTION'} = 'Authorization';
	#$params{'PAYMENTACTIONSPECIFIED'} = 1;
	

	$O2->paymentlog("DoExpressCheckout PT=$payment->{'PT'} PI=$payment->{'PI'} PAYACT=$params{'PAYMENTACTION'}",time(),2,"PAYPAL");
	## 

	## Authorization indicates that this payment is a BASIC AUTHORIZATION subject to settlement with PayPal Authorization & Capture
	## Order indicates that this payment is an ORDER AUTHORIZATION subject to settlement with Paypal Authorization & Capture
	## Sale indicates that this is a final sale for which you are requesting payment
	
	$params{'PAYERID'} = $payment->{'PI'};
	$params{'AMT'} = sprintf("%.2f",$payrec->{'amt'});

	if (($payment->{'uuid'} eq '') || ($payment->{'uuid'} =~ /Z0$/)) {
		$params{'INVNUM'} = $O2->oid();
		}
	else {
		$params{'INVNUM'} = $payment->{'uuid'};
		}
	$params{'INVNUM'} =~ s/-/x/gs;

	if ($self->username() eq 'pricematters') { $params{'CURRENCYCODE'} = 'CAD'; }

	if ($webdb->{'paypal_paylater'}>0) {
		## PAYPAL PAY LATER SUPPORT
		$params{'L_PROMOCODE0'} = 101;
		}

	my $RESULT = undef;
	my $api = undef;
	if (not $RESULT) {
		$api = &ZPAY::PAYPAL::doRequest(\%params);
		}

	if (not defined $api) {
		$RESULT = "289|api result from doRequest was not defined";
		}

## PAYMENTACTION eq 'SALE'
#$VAR3 = {
#          'ORDERTIME' => '2007-07-23T02:05:51Z',
#          'TIMESTAMP' => '2007-07-23T02:05:53Z',
#          'PAYMENTSTATUS' => 'Completed',
#          'ACK' => 'Success',
#          'CURRENCYCODE' => 'USD',
#          'REASONCODE' => 'None',
#          'PENDINGREASON' => 'None',
#          'TRANSACTIONTYPE' => 'cart',
#          'PAYMENTTYPE' => 'instant',
#          'AMT' => '0.02',
#          'BUILD' => '1.0006',
#          'TRANSACTIONID' => '4EV07764Y8100794V',
#          'TAXAMT' => '0.00',
#          'TOKEN' => 'EC-05G55353NP011370L',
#          'CORRELATIONID' => '16c56b9442333',
#          'VERSION' => '2.300000',
#          'FEEAMT' => '0.02'
#        };

#$VAR3 = {
#          'ORDERTIME' => '2007-07-23T02:33:27Z',
#          'TIMESTAMP' => '2007-07-23T02:33:29Z',
#          'PAYMENTSTATUS' => 'Pending',
#          'ACK' => 'Success',
#          'CURRENCYCODE' => 'USD',
#          'REASONCODE' => 'None',
#          'PENDINGREASON' => 'authorization',
#          'TRANSACTIONTYPE' => 'cart',
#          'PAYMENTTYPE' => 'instant',
#          'AMT' => '0.02',
#          'BUILD' => '1.0006',
#          'TRANSACTIONID' => '2CW322855C151182F',
#          'TAXAMT' => '0.00',
#          'TOKEN' => 'EC-5PU41408YE700943S',
#          'CORRELATIONID' => 'a328bc5ea06dc',
#          'VERSION' => '2.300000'
#        };

	if (defined $RESULT) {
		}
	elsif ($api->{'ACK'} eq 'Failure') {
		## SHIT HAPPENED
		# TIMESTAMP=2007%2d07%2d17T01%3a53%3a12Z&CORRELATIONID=d157a248f0ade&ACK=Failure&L_ERRORCODE0=10002&L_SHORTMESSAGE0=Authentication%2fAuthorization%20Failed&L_LONGMESSAGE0=You%20do%20not%20have%20permissions%20to%20make%20this%20API%20call&L_SEVERITYCODE0=Error&VERSION=2%2e300000&BUILD=1%2e0006
		## NOTE: ERR will be set previously if it was a connection error.
		my $ERRMSG = '';
		foreach my $x (0..3) {
			## combine up to four different errors.
			## NOTE: error's start at 0 ex: L_LONGMESSAGE0=Internal+Error
			if ($api->{"L_SHORTMESSAGE$x"} ne '') {
				## we'll keep up to three errors
				$ERRMSG .= sprintf("%s:%s\n",$api->{"L_ERRORCODE$x"},$api->{"L_LONGMESSAGE$x"});
				}
			}
		if ($ERRMSG eq '') { $ERRMSG = 'Received ACK Failure with no messages'; }
		$RESULT = "289|$ERRMSG";

		if ($api->{'L_ERRORCODE0'} == 10417) { $RESULT = "288|$api->{'L_LONGMESSAGE0'}"; }	# The transaction cannot complete successfully.  Instruct the customer to use an alternative payment method.
		if ($api->{'L_ERRORCODE0'} == 10474) { $RESULT = "287|$api->{'L_LONGMESSAGE0'}"; } # Transaction cannot be processed. The country code in the shipping address must match the buyer\\\'s country of residence.\
		if ($api->{'L_ERRORCODE0'} == 10482) { $RESULT = "286|$api->{'L_LONGMESSAGE0'}"; } # Accelerated Boarding: Must be established, or upgraded to business account
		if ($api->{'L_ERRORCODE0'} == 10481) { $RESULT = "286|$api->{'L_LONGMESSAGE0'}"; } # Accelerated Boarding: Must be established, or upgraded to business account
		}
	elsif ($api->{'ERR'} eq '500 SSL read timeout: ') {
		## 
		$RESULT = "249|$api->{'ERR'}";
		}
	elsif ($api->{'ERR'}) {
		## indicates a non-SSL read timeout transport level failure
		## 259 says 'invalid or outdated gateway implementation' so .. it might not be the best.
		$RESULT = "259|$api->{'ERR'}";
		}
	elsif ($api->{'ACK'} =~ /^Success/) {
		if (defined $api->{'TOKEN'}) {
			$payment->{'PT'} = $api->{'TOKEN'};
			}

		if ($api->{'PARENTTRANSACTIONID'} eq '') {
			## THIS MUST BE AN AUTH BECAUSE IT DOESN'T HAVE A PARENTTRANSACTIONID
			$payment->{'PC'} = $api->{'CORRELATIONID'};
			$payrec->{'auth'} = $api->{'TRANSACTIONID'};	
			}
		elsif ($api->{'RECEIPTID'} ne '') {
			## THIS MUST BE A CAPTURE BECAUSE WE GOT A RECEIPT?? (hopefully this is a safe assumption)
			$payment->{'PC'} = $api->{'CORRELATIONID'};
			$payment->{'PR'} = $api->{'RECEIPTID'};
			$payrec->{'txn'} = $api->{'TRANSACTIONID'};
			}
		else {
			$O2->paymentlog('PAYPALEC [unknown] Got: '.Dumper($api));
			}

		## HEY!!!! WE UPPER CASE PENDINGREASON SINCE PAYPAL DEVELOPERS WERE FEELING INDECISIVE!
		##		e.g. None, authorization or was it Authorization (apparently depends on exact call!!!)
		$api->{'PENDINGREASON'} = uc($api->{'PENDINGREASON'});

		if (($api->{'TRANSACTIONTYPE'} ne 'cart') && ($api->{'TRANSACTIONTYPE'} ne 'express-checkout')) {	
			## NOT SURE WHY THIS WOULD HAPPEN? - 
			$RESULT = "289|PaypalEC Unknown TRANSACTIONTYPE: $api->{'TRANSACTIONTYPE'}";;
			}
		elsif ($api->{'PAYMENTTYPE'} eq 'none') {
			## WTF?? why would PAYMENTTYPE be set to none?? 
			$RESULT = '289|PaypalEC Unknown PAYMENTTYPE: none';
			}
		elsif (($api->{'PAYMENTTYPE'} ne 'instant') && 
				($api->{'PAYMENTTYPE'} ne 'echeck')) { 
			## NOT SURE WHY THIS WOULD HAPPEN? -
			##		instant, or echeck are only possible values.
			$RESULT = "289|PaypalEC Unknown PAYMENTTYPE: $api->{'PAYMENTTYPE'}";
			}
		elsif ($api->{'PAYMENTSTATUS'} eq 'Pending') {
			## Pending = Not completed.
			if ($api->{'PENDINGREASON'} eq 'UPGRADE') {
				## this is an accelerated boarding error - that means the client needs to upgrade their
				## paypal account from a personl account to a business account.
				$RESULT = "189|PaypalEC Capture Pending -- merchant paypal account must be upgraded from personal to business.";
				}
			elsif ($api->{'PENDINGREASON'} eq 'UNILATERAL') {
				## an accelerated boarding error - that means the client needs to actually register with 
				## paypal before they can receive their funds.
				$RESULT = "189|PaypalEC Capture Pending due to fact merchant is not registered with Paypal (UNILATERAL)";
				}
			elsif ($api->{'PENDINGREASON'} eq 'AUTHORIZATION') {
				$RESULT = "189|PaypalEC Capture Pending: $api->{'PENDINGREASON'}";
				}
			elsif ($api->{'PENDINGREASON'} eq 'ADDRESS') {
				$RESULT = "189|PaypalEC Capture Pending manual address approval";
				}
			elsif ($api->{'PENDINGREASON'} eq 'ECHECK') {
				$RESULT = "189|PaypalEC Capture Pending due to eCheck Payment";
				}
			elsif ($api->{'PENDINGREASON'} eq 'INTL') {
				$RESULT = "189|PaypalEC Capture Pending due to Intl Account";
				}
			elsif ($api->{'PENDINGREASON'} eq 'MULTI-CURRENCY') {
				$RESULT = "189|PaypalEC Capture Pending due to currency approval.";
				}
			elsif ($api->{'PENDINGREASON'} eq 'VERIFY') {
				$RESULT = "189|PaypalEC Capture Pending because you are not yet verified.";
				}
			elsif ($api->{'PENDINGREASON'} eq 'OTHER') {
				$RESULT = "189|PaypalEC Capture Pending due to OTHER (unspecified) reason - contact Paypal";
				}
			else {
				$RESULT = "189|PaypalEC Unknown PENDINGREASON: $api->{'PENDINGREASON'}";
				}
			}
		elsif (($api->{'PAYMENTSTATUS'} eq 'Completed') && ($api->{'PENDINGREASON'} eq 'NONE')) {
			## Completed = you gots your money
			$O2->paymentlog('PaypalEC Captured via DoExpressCheckout',undef,2);
			if ($api->{'ACK'} =~ /Warning/) {
				$RESULT = "489|$api->{'PAYMENTSTATUS'}";
				}
			else {
				$RESULT = "089|$api->{'PAYMENTSTATUS'}";
				}
			$O2->set_fee('','PP_TRANSFEE',$api->{'FEEAMT'});
			}
		else {
			## PAYMENTSTATUS != Pending && PAYMENTSTATUS != Completed
			## NOT SURE WHY THIS WOULD HAPPEN? -
			##		according to docs can only be Completed or Pending
			$RESULT = "990|$api->{'PAYMENTSTATUS'}";
			}
		}


	if (defined $RESULT) {
		if ($RESULT eq '') { $RESULT = "999|Internal error - RESULT was blank"; }

		my ($PS,$DEBUG) = split(/\|/,$RESULT,2);

		my $chain = 0;
		if (($VERB eq 'AUTHORIZE') || ($VERB eq 'CHARGE')) { $chain = 0; }
		elsif ($VERB eq 'CREDIT') { $chain++; }
		elsif (substr($PS,0,1) eq '2') { $chain++; }
		elsif (substr($PS,0,1) eq '3') { $chain++; }
		elsif (substr($PS,0,1) eq '6') { $chain++; $payrec->{'voided'} = time(); }
		elsif (substr($PS,0,1) eq '9') { $chain++; }

		if ($chain) {
			my %chain = %{$payrec};
			$chain{'r'} = &ZTOOLKIT::buildparams($api);
			delete $chain{'ts'};
			delete $chain{'debug'};
			delete $chain{'note'};
			$chain{'puuid'} = $chain{'uuid'};
			$chain{'uuid'} = $O2->next_payment_uuid();
			$payrec = $O2->add_payment($payrec->{'tender'},$payrec->{'amt'},%chain);
			}

		$payrec->{'ts'} = time();	
		$payrec->{'ps'} = $PS;
		$payrec->{'note'} = $payment->{'note'};
		$payrec->{'debug'} = $DEBUG;

		if ($chain) {
			delete $payrec->{'acct'};
			}
		elsif ($VERB eq 'CAPTURE') {
			## don't touch payment on a CAPTURE
			}
		else {
			my %storepayment = %{$payment};
			$storepayment{'CM'} = &ZTOOLKIT::cardmask($payment->{'CC'});		
			if (not &ZPAY::ispsa($payrec->{'ps'},['2','9'])) {
				## we got a failure, so .. we toss out the CVV, but keep the CC
				delete $storepayment{'CC'};
				}
			delete $storepayment{'CV'};
			$payrec->{'acct'} = &ZPAY::packit(\%storepayment);
			}
		$payrec->{'r'} = &ZTOOLKIT::buildparams(\%params);
		}
	
	my $RS = undef;
	if (defined $RS) {
		}
	elsif ((defined $api) && ($api->{'PROTECTIONELIGIBILITY'} eq 'Eligible')) {
		$RS = 'APC'; # =Eligible
		}
	elsif (not defined $payment->{'PZ'}) {
		}
	elsif ($payment->{'PZ'} eq 'Confirmed') {
		$RS = 'APC';
		}
	elsif ($payment->{'PZ'} eq 'Unconfirmed') {
		$RS = 'APC';
		}

	if (defined($RS)) {
		$O2->in_set('flow/review_status',$RS);
		}

	if ((defined $api) && ($api->{'NOTE'} ne '')) {
		my $note = sprintf("%s",$O2->in_get('want/order_notes'));
		$note = (($note ne '')?"$note\n":"")."PAYPAL: $api->{'NOTE'}";
		$O2->in_set('want/order_notes',$note);
		}
	
	$O2->paymentlog("PAYPALEC API REQUEST: ".&ZTOOLKIT::buildparams(\%params));	
	$O2->paymentlog("PAYPALEC API RESPONSE: ".&ZTOOLKIT::buildparams($api));	
	$O2->paymentlog("PAYPALEC RESULT: $RESULT");

	## this will return an error message to $ZPAY::private_order_initialize
	return($payrec);	
	}

##
## used in Paypal callbacks - adds relevant shipping variables to both
##		the request and response (since both seem to be the same)
##
sub addShippingToParams {
	my ($CART2, $ppref, $src) = @_;

	$src = uc($src);
	## SRC='CALLBACK' has special behaviors (turns off guess)

	# $CART2->shipping();
	my $handling = 0;

	foreach my $fee ('sum/hnd_total','sum/spc_total','sum/ins_total') {
		$handling += sprintf("%.2f",$CART2->in_get($fee));
		}

	## ADD SHIPPING METHODS + SET ITEM
	my $i = 0;
	my $SHIPAMT = 0;

	my $SHIPPOSSIBILITIES = [];
	if ($src eq 'CALLBACK') {
		## on a callback return all available methods.
		$SHIPPOSSIBILITIES = $CART2->shipmethods('tbd'=>1);		
		}
	else {
		$SHIPPOSSIBILITIES = $CART2->shipmethods('selected_only'=>1,'tbd'=>1);
		}

#	open F, ">/tmp/possibilities";
#	print F Dumper($SHIPPOSSIBILITIES,$cart);
#	close F;


	foreach my $shipmethod (@{$SHIPPOSSIBILITIES}) {

		# my $price = sprintf("%.2f",$methodsref->{$method} + $handling);
		my $price = sprintf("%.2f",$shipmethod->{'amount'});
		$ppref->{'L_SHIPPINGOPTIONISDEFAULT'.$i} = 'false';
		
		## L_SHIPPINGOPTIONLABELx is what is SHOWN to the user.
		## L_SHIPPINGOPTIONNAMEx
		## NOTE: duplicated code in GetExpressCheckoutDetails
		my $id = lc($shipmethod->{'id'});	
		$id =~ s/[^a-z0-9]/_/g;
		$id = "$id";
		
		if ($src eq 'CALLBACK') {
			$ppref->{'L_SHIPPINGOPTIONLABEL'.$i} = $id; # $shipmethod->{'name'}; 
			$ppref->{'L_SHIPPINGOPTIONNAME'.$i} = $shipmethod->{'name'};  # this appears before the label
			#$ppref->{'L_SHIPPINGOPTIONLABEL'.$i} = "$name|CB-LABEL";	
			#$ppref->{'L_SHIPPINGOPTIONNAME'.$i} = "$method|CB-NAME";  #displayed
			}
		else {
			## so paypal doesn't actually support $0.00 shipping in the initial request
			## but they apparently do, on the callback, so this is a cheap hack:
			if ($price==0) { $price = 0.01; }
			# $ppref->{'L_SHIPPINGOPTIONLABEL'.$i} = $id; 
			$ppref->{'L_SHIPPINGOPTIONNAME'.$i} = $shipmethod->{'name'}; #displayed
			#$ppref->{'L_SHIPPINGOPTIONLABEL'.$i} = "$name|GUESS-LABEL";  
			#$ppref->{'L_SHIPPINGOPTIONNAME'.$i} = "$method|GUESS-NAME"; #displayed
			}
		## stupid typo.b
		# $ppref->{'L_SHIPPINGOPTIONLABEL'.$i} = $ppref->{'L_SHIPPINGOPTIONLABEL'.$i};
	
		my $shipdisc = 0;
		if ($price == 0) {
			## work around for paypals inability to support zero dollar shipping.
			$shipdisc = "0.01";
			$price = "0.01";
			}		

		$ppref->{'L_SHIPPINGOPTIONAMOUNT'.$i} = $price;
		if ($i==0) { 
			$SHIPAMT = $price; 
			$ppref->{'L_SHIPPINGOPTIONISDEFAULT'.$i} = 'true';
			}
		
		if ($shipdisc>0) {
			$ppref->{'L_SHIPPINGDISCOUNT'} = $shipdisc;
			}		

		$ppref->{'L_INSURANCEAMOUNT'.$i}= '0.00';		## hmm.. not sure how this impacts INSURANCEAMT 
		$i++;
		}

	return($SHIPAMT);
	}





1;