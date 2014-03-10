package ZPAY::PAYFLOW;

use lib '/backend/lib';
require ZPAY;
require ZWEBSITE;
require ZTOOLKIT;
use strict;



# https://cms.paypal.com/cms_content/US/en_US/files/developer/PP_WPPPF_HTTPSInterface_Guide.pdf
# https://cms.paypal.com/us/cgi-bin/?cmd=_render-content&content_ID=developer/howto_gateway_payflowpro
# https://cms.paypal.com/cms_content/US/en_US/files/developer/PP_PayflowPro_Guide.pdf

# https://ppmts.custhelp.com/app/answers/detail/a_id/883/
$ZPAY::VERISIGN::DEFAULT_PARTNER = 'VeriSign'; # Used if they don't have a vendor selected in their payment configuration.
$ZPAY::VERISIGN::PROD_SERVER = 'https://payflowpro.paypal.com';
$ZPAY::VERISIGN::PROD_SERVER_ALT = 'https://payflowpro.verisign.com';	
$ZPAY::VERISIGN::TEST_SERVER = 'https://pilot-payflowpro.paypal.com';

#$ENV{'PFPRO_CERT_PATH'} = '/backend/lib/verisign';
#$PFProAPI::PFPRO = '/backend/lib/PFPro';
#use PFProAPI;

my $DEBUG = 1;    # This just outputs debug information to the apache log file

##############################################################################
# VERISIGN FUNCTIONS

# Docs at https://manager.verisign.com
# Partner = 'VeriSign'
# Login = 'digconcept'
# Vendor = 'digconcept'
# Password = 'H1fsd6fD'
# Its under the section "Downloads"

# Returns all the fields that would be interesting to look at for this processor
sub verisign_whitelist {
	return qw(PNREF RESULT AUTHCODE AVSADDR AVSZIP);
	}


sub new {
   my ($class) = @_;
   my $self = {};
   bless $self, 'ZPAY::PAYFLOW';
	return($self);
   }



sub unified {
	my ($self,$VERB,$O2,$payrec,$payment) = @_;

	$O2->paymentlog("PAYFLOW PAYREC(IN): ".&ZTOOLKIT::buildparams($payrec));	

	$VERB = uc($VERB);
	my $RESULT = undef;

	if (not defined $O2) { $RESULT = "999|Order not passed"; }

	my $order_id = time();
	if ($O2->is_order()) { $order_id = $O2->oid(); }
	if ($O2->is_cart()) { $order_id = $O2->cartid(); }

	my ($webdbref) = &ZWEBSITE::fetch_website_dbref($O2->username(),$O2->prt());

	my $AMT = $payrec->{'amt'};
	if (defined $payment->{'amt'}) {
		$AMT = $payment->{'amt'};
		}

	my %params = ();
	my %k = ();

	## hmm.. if this has a puuid then we should probably use that.
	my $invnum = $payrec->{'uuid'};
	if ($payrec->{'puuid'} ne '') { $invnum = $payrec->{'puuid'}; }
	$invnum = uc($invnum);
	$invnum =~ s/[^A-Z0-9]+//gs;
	$invnum = substr($invnum,-9);
	$params{'INVNUM'} = $invnum;

	if (defined $RESULT) {
		}
	elsif (($VERB eq 'CREDIT') || ($VERB eq 'CAPTURE') || ($VERB eq 'VOID')) {
		}
	else {

		my $bill_address = $O2->in_get('bill/address1');
		if ($O2->in_get('bill/address2')) { $bill_address .= ' ' . $O2->in_get('bill/address2'); }
		my $ship_address = $O2->in_get('ship/address1');
		if ($O2->in_get('ship/address2')) { $ship_address .= ' ' . $O2->in_get('ship/address2'); }

		#my $invnum = $order_id;
		#$invnum = substr($order_id,rindex($order_id,'-')+1);
		# $params{'INVNUM'} = $invnum;

		$params{'STREET'} = $bill_address;
		$params{'ZIP'} = $O2->in_get('bill/postal');
		$params{'COMMENT1'} = $O2->in_get('bill/firstname') . ' ' . $O2->in_get('bill/lastname');
		$params{'COMMENT2'} = $order_id;
		$params{'CITY'} = $O2->in_get('bill/city');
		$params{'COMPANYNAME'} = $O2->in_get('bill/company');
		$params{'EMAIL'} = $O2->in_get('bill/email');
		$params{'FIRSTNAME'} = $O2->in_get('bill/firstname');
		$params{'LASTNAME'} = $O2->in_get('bill/lastname');
		$params{'SHIPTOCITY'} = $O2->in_get('ship/city');
		$params{'SHIPTOFIRSTNAME'} = $O2->in_get('ship/firstname');
		$params{'SHIPTOLASTNAME'} = $O2->in_get('ship/lastname');
		$params{'SHIPTOSTATE'} = $O2->in_get('ship/region');
		$params{'SHIPTOSTREET'} = $ship_address;
		$params{'SHIPTOCOUNTRY'} = $O2->in_get('ship/countrycode');
		if ($params{'SHIPTOCOUNTRY'} eq '') { $params{'SHIPTOCOUNTRY'} = 'US'; }
		$params{'SHIPTOZIP'} = $O2->in_get('ship/postal');
		$params{'STATE'} = $O2->in_get('bill/region');
		$params{'COUNTRY'} = $O2->in_get('bill/countrycode');
		if ($params{'COUNTRY'} eq '') { $params{'COUNTRY'} = 'US'; }
		$params{'CUSTIP'} = $O2->in_get('cart/ip_address');
		$params{'PHONENUM'} = $O2->in_get('bill/phone');

		if (sprintf("%d",$AMT*100) < sprintf("%d",$O2->in_get('sum/balance_due_total')*100)) {
			## the 'amt' is less than the balance_due so we won't send fields like TAXAMT because we'll get a 
			## payflow 10413 error
			}
		else {
			$params{'TAXAMT'} = ZTOOLKIT::cashy($O2->in_get('sum/tax_total'));
			}
		$params{'AMT'} = ZTOOLKIT::cashy($AMT);
		}

	if ($payrec->{'tender'} eq 'CREDIT') {
		$params{'TENDER'} = 'C';
		if ($payment->{'CC'} ne '') {
			$params{'ACCT'} = $payment->{'CC'};
			}
		elsif ($payment->{'CM'} ne '') {
			$params{'ACCT'} = $payment->{'CM'};
			}
		else {
			## this is more of an internal message
			$RESULT = "200|Need CC or CM for payflow ACCT";
			}
		$params{'EXPDATE'} = sprintf("%02d%02d",$payment->{'MM'},$payment->{'YY'});
		if ($payment->{'CV'} ne '') { $params{'CVV2'} = $payment->{'CV'}; }

		if ($VERB eq 'VOID') {
			## PATTI: parsed ACCT to only pass last 4 digits 9/7/2005
		   $params{'ACCT'} =~ /.*(\d\d\d\d)$/;
		   $params{'ACCT'} = $1;
			}
		}
	elsif ($payrec->{'tender'} eq 'ECHECK') {
		## .. K = Telecheck
		$RESULT = "999|Telecheck not supported";
		$params{'TENDER'} = 'K';
		}
	else {
		## A = Automated clearinghouse
		## .. C = Credit card
		##	.. D = Pinless debit
		## .. P = PayPal
		}


	if ($VERB eq 'AUTHORIZE') {
		$params{'TRXTYPE'} = 'A';
		}
	elsif ($VERB eq 'CHARGE') {
		$params{'TRXTYPE'} = 'S';
		}
	elsif ($VERB eq 'CAPTURE') {
		delete $params{'ACCT'};
		delete $params{'EXPDATE'};
		delete $params{'CVV2'};
		$params{'TRXTYPE'} = 'D';
		$params{'ORIGID'} = $payrec->{'txn'}; # $payrec->{'auth'};
		$params{'AMT'} = ZTOOLKIT::cashy($AMT);
		}
	elsif ($VERB eq 'VOID') {
		$params{'TRXTYPE'} = 'V';
		$params{'ORIGID'} = $payrec->{'txn'};
		}
	elsif ($VERB eq 'CREDIT') {
		$params{'TRXTYPE'} = 'C';
		$params{'ORIGID'} = $payrec->{'txn'};
		$params{'AMT'} = ZTOOLKIT::cashy($AMT);
		}
	## The PNREF value is used as the ORIGID value (original transaction ID) in Delayed
	## Capture transactions (TRXTYPE=D), Credits (TRXTYPE=C), Inquiries (TRXTYPE=I), and Voids (TRXTYPE=V).

	my $api = &verisign_call(\%params, $O2->username(), $webdbref);

##		ICAP - instant capture
##		VOID - void
##		AUTH - auth
##		SETL - settlement (from an auth)
	if ($VERB eq 'AUTHORIZE') {
		# $payrec->{'auth'} = $api->{'AUTHCODE'};	 NOTE: AUTHCODE is a voice authorization code
		$payrec->{'txn'} = $api->{'PNREF'};
		}
	elsif ($VERB eq 'CAPTURE') {
		$payrec->{'txn'} = $api->{'PNREF'};
		}
	elsif ($VERB eq 'CHARGE') {
		# $payrec->{'auth'} = $api->{'AUTHCODE'};	NOTE: AUTHCODE is a 6 digit voice auth code (given to the operator)
		$payrec->{'txn'} = $api->{'PNREF'};
		}

	my $response = $api->{'RESPMSG'};
	my $message = "Verisign - auth=$api->{'AUTHCODE'} pnref=$api->{'PNREF'} rc=$api->{'RESULT'} rs=$api->{'RESPMSG'}";

	my $RS = undef;
	if (($VERB eq 'AUTHORIZE') || ($VERB eq 'CHARGE')) {
		if (defined($api->{'AVSZIP'}) && ($api->{'AVSZIP'} ne '')) {
			$message .= " - AVS Zip: $api->{'AVSZIP'}";
			}
		if (defined($api->{'AVSADDR'}) && ($api->{'AVSADDR'} ne '')) {
			$message .= " - AVS Addr: $api->{'AVSADDR'}";
			}
		# AVS Settings
		my $avsch = '';
		if (($api->{'AVSZIP'} eq 'Y') && ($api->{'AVSADDR'} eq 'Y')) { $avsch = 'A'; }
		elsif (($api->{'AVSZIP'} eq 'Y') && ($api->{'AVSADDR'} eq 'X')) { $avsch = 'A'; }
		elsif (($api->{'AVSZIP'} eq 'X') && ($api->{'AVSADDR'} eq 'Y')) { $avsch = 'A'; }
		elsif (($api->{'AVSZIP'} eq 'Y') && ($api->{'AVSADDR'} eq 'N')) { $avsch = 'P'; }
		elsif (($api->{'AVSZIP'} eq 'N') && ($api->{'AVSADDR'} eq 'Y')) { $avsch = 'P'; }
		elsif (($api->{'AVSZIP'} eq 'Y') && ($api->{'AVSADDR'} eq 'X')) { $avsch = 'P'; }
		elsif (($api->{'AVSZIP'} eq 'X') && ($api->{'AVSADDR'} eq 'Y')) { $avsch = 'P'; }
		elsif (($api->{'AVSZIP'} eq 'N') && ($api->{'AVSADDR'} eq 'N')) { $avsch = 'D'; }
		elsif (($api->{'AVSZIP'} eq 'N') && ($api->{'AVSADDR'} eq 'X')) { $avsch = 'D'; }
		elsif (($api->{'AVSZIP'} eq 'X') && ($api->{'AVSADDR'} eq 'N')) { $avsch = 'X'; }
		$RS = &ZPAY::review_match($RS,$avsch,&ZTOOLKIT::gstr($webdbref->{'cc_avs_review'},$ZPAY::AVS_REVIEW_DEFAULT));		
		$k{'AVSZ'} = &ZTOOLKIT::translatekeyto($api->{'AVSZIP'},'X',{'Y'=>'M','X'=>'X','N'=>'N'});
		$k{'AVST'} = &ZTOOLKIT::translatekeyto($api->{'AVSADDR'},'X',{'Y'=>'M','X'=>'X','N'=>'N'});

		my $cvvch = '';
		if ($api->{'CVV2MATCH'} eq 'Y') { $cvvch = 'A'; }
		elsif ($api->{'CVV2MATCH'} eq 'N') { $cvvch = 'D'; }
		elsif ($api->{'CVV2MATCH'} eq 'X') { $cvvch = 'X'; }
		$k{'CVVR'} = &ZTOOLKIT::translatekeyto($api->{'CVV2MATCH'},'X',{'Y'=>'M','X'=>'X','N'=>'N'});
		$RS = &ZPAY::review_match($RS,$cvvch,&ZTOOLKIT::gstr($webdbref->{'cc_cvv_review'},$ZPAY::CVV_REVIEW_DEFAULT));				
		}

	if (not defined $RS) {
		$O2->in_set('flow/review_status',$RS);
		}

	if (&ZPAY::has_kount($O2->username())) {
		## store KOUNT values.
		require PLUGIN::KOUNT;
		$payment->{'KH'} = PLUGIN::KOUNT::generate_khash($payment->{'CC'});
		$O2->in_set('flow/kount',sprintf("AVSZ=%s|AVST=%s|CVVR=%s",$k{'AVSZ'},$k{'AVST'},$k{'CVVR'}));
		}

	## CORRELATIONID
	## Value used for tracking this Direct Payment transaction. 
	# Character length and limitations: 13 alphanumeric characters

	## PNREF
	## The PNREF is a unique transaction identification number issued by PayPal that identifies the
	## transaction for billing, reporting, and transaction data purposes. The PNREF value appears in
	## the Transaction ID column in PayPal Manager reports.
	$DEBUG && &msg("\$api->{'PNREF'} is '$api->{'PNREF'}'");
	## Returned for Sale, Authorization, and Voice Authorization credit card
	## transactions. AUTHCODE is the approval code obtained over the telephone
	## from the processing network.
	## AUTHCODE is required when submitting a Force (F) transaction. 
	## Character length and limitations: 6 alphanumeric characters
	$DEBUG && &msg("\$api->{'AUTHCODE'} is '$api->{'AUTHCODE'}'");
	$DEBUG && &msg("\$api->{'RESULT'} is '$api->{'RESULT'}'");
	$DEBUG && &msg("\$api->{'AVSZIP'} is '$api->{'AVSZIP'}'");
	$DEBUG && &msg("\$api->{'AVSADDR'} is '$api->{'AVSADDR'}'");
	$DEBUG && &msg("\$api->{'RESPMSG'} is '$api->{'RESPMSG'}'");
	$DEBUG && &msg("\$message is '$message'");


	if (($api->{'RESULT'} < 0) || (not defined $api->{'RESULT'})) { 
		$RESULT = '250|'; 
		}    # A variety of network and SSL problems
	elsif (($api->{'RESULT'} == 0) && ($VERB eq 'VOID')) {
		$RESULT = '303';	# 303: Cancelled - The gateway returned this transaction has been cancelled.
		if ($api->{'RESPMSG'} ne 'Approved') {
			$RESULT = '259';	# 259: Gateway API Error - The transaction failed because the gateway was contacted using an incorrect implementation
			}
		}
	elsif (($api->{'RESULT'} == 0) && ($VERB eq 'CREDIT')) {
		# die("Liz - what does a credit return?");
		$RESULT = "303|PAYFLOW:$api->{'RESPMSG'}";
		}
	elsif ($api->{'RESULT'} == 0) {
		# The transaction succeeded
		if    ($VERB eq 'CHARGE') { $RESULT = '001|'; }    # Instant
		elsif ($VERB eq 'CAPTURE') { $RESULT = '002|'; }    # Capture authorized
		elsif ($VERB eq 'AUTHORIZE') { $RESULT = '199|'; }                     # Auth only


		}
	elsif (($api->{'RESULT'}>0) && ($api->{'RESPMSG'} ne '')) {
		$RESULT = "200|PAYFLOW:$api->{'RESPMSG'}";
		}
	elsif ($api->{'RESULT'} == 13)   { 
		# Voice Auth Settings
#		my $voicefail = $webdbref->{'cc_report_voice_fail'};    # ALWAYS or NEVER
#		if ((not defined $voicefail) || ($voicefail eq '')) { $voicefail = 'ALWAYS'; }         # Default to ALWAYS
		#my $voicefailcode = $webdbref->{'cc_voice_fail_code'};  # 103 (Pending) or 202 (Denied)
		#if ((not defined $voicefailcode) || ($voicefailcode eq '')) { $voicefailcode = '202'; }    # Default to denied
		$RESULT = "202|"; 
		} # If voice authorization is considered a failure, set the code appropriately
	elsif ($api->{'RESULT'} == 1)    { $RESULT = '253|User authentication failed'; } # All the infomration neccessary wasn't provided, or it was incorrect
	elsif ($api->{'RESULT'} == 2)    { $RESULT = '252|Invalid tender'; } # Invalid tender, your bank/account doesn't support that type of card
	elsif ($api->{'RESULT'} == 3)    { $RESULT = '256|Invalid transacation type'; } # Invalid transaction type. i.e., trying to credit and authorize transaction
	elsif ($api->{'RESULT'} == 4)    { $RESULT = '253|User authentication failed'; } # Invalid amont
	elsif ($api->{'RESULT'} == 5)    { $RESULT = '255|Invalid merchant information'; } # Your processor or bank doesn't know who you are
	elsif ($api->{'RESULT'} == 7)    { $RESULT = '253|User authentication failed'; } # Field format error
#	elsif ($api->{'RESULT'} == 8)    { $RESULT = '257|'; } # Not a transaction server ... ???
#	elsif ($api->{'RESULT'} == 9)    { $RESULT = '253|'; } # Too many parameters or invalid stream
#	elsif ($api->{'RESULT'} == 10)   { $RESULT = '253|'; } # Too many line items
#	elsif ($api->{'RESULT'} == 11)   { $RESULT = '250|'; } # Client timeout
	elsif ($api->{'RESULT'} == 12)   { $RESULT = '200|Declined'; } # Denied, be-yatch!
	elsif ($api->{'RESULT'} == 13)	{ $RESULT = '202|Referral'; } #Voice Authorization - Approval was denied due to request for Voice Authorization, customer was told the order failed.  
	elsif ($api->{'RESULT'} == 19)   { $RESULT = '256|Original transaction ID not found'; } # Previous transaction referred to does not exist
#	elsif ($api->{'RESULT'} == 20)   { $RESULT = '255|'; } # Cannot find the customer reference number
	elsif ($api->{'RESULT'} == 22)   { $RESULT = '255|Invalid ABA number'; } # Invalid ABA number
	elsif ($api->{'RESULT'} == 23)   { $RESULT = '253|User authentication failed'; } # Invalid account number. Check credit card number and re-submit.
	elsif ($api->{'RESULT'} == 24)   { $RESULT = '253|User authentication failed'; } # Invalid expiration date. Check and re-submit.
	elsif ($api->{'RESULT'} == 25)   { $RESULT = '252|Transaction type not mapped to this host (Processor)'; } # Invalid Host Mapping. Transaction type not mapped to this host
#	elsif ($api->{'RESULT'} == 26)   { $RESULT = '255|'; } # Invalid vendor account
#	elsif ($api->{'RESULT'} == 27)   { $RESULT = '255|'; } # Insufficient partner permissions
#	elsif ($api->{'RESULT'} == 28)   { $RESULT = '255|'; } # Insufficient user permissions
	elsif ($api->{'RESULT'} == 29)   { $RESULT = '253|User authentication failed'; } # Invalid XML document. This could be caused by an unrecognized XML tag or a bad XML format that cannot be parsed by the system.
	elsif ($api->{'RESULT'} == 30)   { $RESULT = '261|Duplicate Transaction'; } # Duplicate transaction
#	elsif ($api->{'RESULT'} == 31)   { $RESULT = '257|'; } # Error in adding the recurring profile
#	elsif ($api->{'RESULT'} == 32)   { $RESULT = '257|'; } # Error in modifying the recurring profile
#	elsif ($api->{'RESULT'} == 33)   { $RESULT = '257|'; } # Error in canceling the recurring profile
#	elsif ($api->{'RESULT'} == 34)   { $RESULT = '257|'; } # Error in forcing the recurring profile
#	elsif ($api->{'RESULT'} == 35)   { $RESULT = '257|'; } # Error in reactivating the recurring profile
#	elsif ($api->{'RESULT'} == 36)   { $RESULT = '257|'; } # OLTP Transaction failed
	elsif ($api->{'RESULT'} == 50)   { $RESULT = '204|Insufficient funds available'; } # Insufficient funds
	elsif ($api->{'RESULT'} == 99)   { $RESULT = '257|General error'; } # General error
	elsif ($api->{'RESULT'} == 100)  { $RESULT = '250|Invalid transaction returned from host (Processor)'; } # Invalid transaction from host?
	elsif ($api->{'RESULT'} == 101)  { $RESULT = '250|Invalid transaction returned from host (Processor)'; } # Timeout value too small
#	elsif ($api->{'RESULT'} == 102)  { $RESULT = '250|Invalid transaction returned from host (Processor)'; } # Host unavailable
	elsif ($api->{'RESULT'} == 103)  { $RESULT = '250|Invalid transaction returned from host (Processor)'; } # Error reading response from host
	elsif ($api->{'RESULT'} == 104)  { $RESULT = '250|Invalid transaction returned from host (Processor)'; } # Timeout waiting for host response
	elsif ($api->{'RESULT'} == 105)  { $RESULT = '256|Credit error'; } # Credit error. Make sure you have not already credited this transaction, or that this transaction ID is for a creditable transaction. (For example, you cannot credit an authorization.)
#	elsif ($api->{'RESULT'} == 106)  { $RESULT = '250|Invalid transaction returned from host (Processor)'; } # Host not available
#	elsif ($api->{'RESULT'} == 107)  { $RESULT = '250|Invalid transaction returned from host (Processor)'; } # Duplicate suppression time-out
	elsif ($api->{'RESULT'} == 108)  { $RESULT = '256|Credit error'; } # Void error. See RESPMSG. Make sure the transaction ID entered has not already been voided. If not, then look at the Transaction Detail screen for this transaction to see if it has settled. (The Batch field is set to a number greater than zero if the transaction has been settled). If the transaction has already settled, your only recourse is a reversal (credit a payment or submit a payment for a credit).
#	elsif ($api->{'RESULT'} == 109)  { $RESULT = '250|'; } # Time-out waiting for host response
	elsif ($api->{'RESULT'} == 111)  { $RESULT = '256|Invalid transaction returned from host (Processor)'; } # Capture error. Only authorization transactions can be captured.
	elsif ($api->{'RESULT'} == 112)  { $RESULT = '205|Failed AVS check'; } # AVS Decline at the processor
	elsif ($api->{'RESULT'} == 113)  { $RESULT = '252|Cannot exceed sales cap'; } # Cannot exceed sales cap
	elsif ($api->{'RESULT'} == 114)  { $RESULT = '207|CVV2 mismatch'; } # Card Security Code (CSC) Mismatch. An authorization may still exist on the cardholder's account.
#	elsif ($api->{'RESULT'} == 115)  { $RESULT = '250|'; } # System busy, try again later
#	elsif ($api->{'RESULT'} == 116)  { $RESULT = '250|'; } # VPS Internal error - Failed to lock terminal number
#	elsif ($api->{'RESULT'} == 117)  { $RESULT = '200|'; } # Failed merchant rule check. An attempt was made to submit a transaction that failed to meet the security settings specified on the VeriSign Manager Security Settings page. See Chapter 4; Configuring Account Security.
#	elsif ($api->{'RESULT'} == 118)  { $RESULT = '253|'; } # Invalid keywords found in string fields
#	elsif ($api->{'RESULT'} == 125)  { $RESULT = '205|'; } # AVS Failure returned by Verisign/Paypal
	elsif ($api->{'RESULT'} == 1000) { $RESULT = '257|General error'; } # Generic host error returned by processor
	
	if (not defined $RESULT) {
		$RESULT = "257|Verisign pcode not defined - RCODE=$api->{'RESULT'} PPMSG=$api->{'RESPMSG'}";
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
			$chain{'puuid'} = $chain{'uuid'};
			$chain{'amt'} = $params{'AMT'};
			$chain{'uuid'} = $O2->next_payment_uuid();
			$chain{'auth'} = sprintf("%s",$api->{'AUTHCODE'});	
			$chain{'txn'} = sprintf("%s",$api->{'PNREF'});	
			$payrec = $O2->add_payment($payrec->{'tender'},$params{'AMT'},%chain);
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
		$payrec->{'r'} = &ZTOOLKIT::buildparams($api);
		}
	$O2->paymentlog("PAYFLOW API REQUEST: ".&ZTOOLKIT::buildparams(\%params));	
	$O2->paymentlog("PAYFLOW API RESPONSE: ".&ZTOOLKIT::buildparams($api));	
	$O2->paymentlog("PAYFLOW RESULT: $RESULT");

	$DEBUG && &msg("\$message is $message");
	$DEBUG && &msg("\$api->{'PNREF'} is $api->{'PNREF'}");
	$DEBUG && &msg("\$api->{'AUTHCODE'} is $api->{'AUTHCODE'}");

	return($payrec);
	}



########################################
# VERISIGN AUTHORIZE
sub authorize { my ($self,$O2,$payrec,$payment) = @_; return($self->unified('authorize',$O2,$payrec,$payment)); }

########################################
# VERISIGN CHARGE AUTHORIZED
sub capture { my ($self,$O2,$payrec,$payment) = @_; return($self->unified('capture',$O2,$payrec,$payment)); }

########################################
# VERISIGN CHARGE
sub charge { my ($self,$O2,$payrec,$payment) = @_; return($self->unified('charge',$O2,$payrec,$payment)); }

########################################
# VERISIGN VOID
sub void { my ($self,$O2,$payrec,$payment) = @_; return($self->unified('void',$O2,$payrec,$payment)); }

# VERISIGN CREDIT
sub credit { my ($self,$O2,$payrec,$payment) = @_; return($self->unified('credit',$O2,$payrec,$payment)); }


########################################
# VERISIGN RESULT
# Description: Takes a authorizenet error code and translates it into a zoovy error code
##
## ACTION:



########################################
# VERISIGN CALL
# Description: Calls the external PFPro API
# Accepts: A hash of parameters needed to call PFPro
# Returns: A hash of the result codes from calling PFPro
sub verisign_call {
	my ($params, $merchant_id, $webdb) = @_;
	# my $webdb = &ZWEBSITE::fetch_website_dbref($merchant_id);
	my $username     = &ZTOOLKIT::def($webdb->{'verisign_username'}); 
	if ($username =~ m/(.*?)\/test$/) { $username = $1; $webdb->{'verisign_testmode'}++; }
	my $password     = &ZTOOLKIT::def($webdb->{'verisign_password'});
	my $partner      = &ZTOOLKIT::gstr($webdb->{'verisign_partner'},$ZPAY::VERISIGN::DEFAULT_PARTNER);
	my $vendor       = &ZTOOLKIT::gstr($webdb->{'verisign_vendor'},$username);
	
	my $URL = $ZPAY::VERISIGN::PROD_SERVER;
	if (&ZTOOLKIT::num($webdb->{'verisign_testmode'})) {
		$URL = $ZPAY::VERISIGN::TEST_SERVER;
		}

	## Verify USER, VENDOR, PARTNER and PASSWORD. Remember, USER and VENDOR are both the merchant 
	## login ID unless a Payflow Pro USER was created. All fields are case-sensitive.
	$params->{'USER'} = $username;
	$params->{'PWD'} = $password;
	$params->{'PARTNER'} = $partner;
	$params->{'VENDOR'} = $vendor;		## merchant login?

#	print STDERR Dumper($params,$URL);
#	my $auth_params  = { %{$params}, 'USER' => $username, 'PWD' => $password, 'PARTNER' => $partner, 'VENDOR' => $vendor };
#	my $params_text  = &PFProAPI::makeparams($auth_params);
#	my $api_text = &PFProAPI::call_pfpro($host, $ZPAY::VERISIGN::PORT, $params_text, 60, '', '', '', '');
#	my $api      = &PFProAPI::parseparams($api_text);
	
	## http://www.pdncommunity.com/pdn/board/message?board.id=payflow&thread.id=1008

	use LWP::UserAgent;
   # Create an LWP instance
   my $agent = new LWP::UserAgent;
   $agent->agent('Groovy-Zoovy/1.0');
	$agent->timeout(20);

	require HTTP::Headers;
	my $h = HTTP::Headers->new();

	$h->header("Content-Type"=>"text/namevalue");  # set

   # Now lets go ahead and create a request

	# The X-VPS-REQUEST-ID is a unique identifier for each request, whether the request is a single name-value transaction or an XMLPay 2.0 document with multiple transactions. This identifier is associated with all the transactions in that particular request. 
	#X-VPS-REQUEST-ID: [See description above]
	my ($guid) = substr(Data::GUID->new()->as_string(),0,32);
	$h->header("X-VPS-REQUEST-ID"=>$guid);

	$h->header("X-VPS-CLIENT-TIMEOUT"=>45);
	$h->header("X-VPS-VIT-INTEGRATION-PRODUCT"=>"Groovy-Zoovy");
	$h->header("X-VPS-VIT-INTEGRATION-VERSION"=>"08");
	$h->header("X-VPS-VIT-OS-NAME"=>"OS");
	$h->header("X-VPS-VIT-OS-VERSION"=>"2");
	$h->header("X-VPS-VIT-RUNTIME-VERSION"=>"1.00");	

	# NOTE: The bracketed numbers are length tags which allow you to use the special characters of "&" and "=" in the value sent. See "Using Special Characters in Values" in the Payflow Pro Developer's Guide for more information.
	# TRXTYPE[1]=S&ACCT[16]=5105105105105100&EXPDATE[4]=0109&TENDER[1]=C&INVNUM[8]=INV12345&AMT[5]=25.12&PONUM[7]=PO12345&STREET[23]=123 Main St.&ZIP[5]=12345&USER[6]=jsmith&VENDOR[6]=jsmith&PARTNER[6]=PayPal&PWD[8]=testing1 
	# ADDITIONAL NOTE: The Request Body should NOT be url-encoded.  Pass the data as a standard data and use the length tags if needed.
	my $txt = '';
	foreach my $k (keys %{$params}) {
		$txt .= sprintf("%s[%d]=%s&",$k,length($params->{$k}),$params->{$k});
		}
	chop($txt);

	my $success = 0;
	my $attempts = 0;
	my $api = {};
	my $responsetxt = undef;
	while ((not $success) && ($attempts<3)) {
		if ($attempts>=2) {
			## final last ditch attempt to work around this, try to hit payflowpro.verisign.com
			$URL = $ZPAY::VERISIGN::PROD_SERVER_ALT;
			}
	   my $req = new HTTP::Request('POST', $URL, $h, $txt);
	   my $response  = $agent->request($req);
		
		if (not $response->is_success()) {
			## yipes.
			}
		elsif ($response->content() eq '') {
			## empty response eh?
			}
		else {
			$success++;
			}
		
		if (not $success) {
			open F, sprintf(">%s/payflow.$attempts.$guid.log",&ZOOVY::memfs());
			use Data::Dumper; 
			print F Dumper($response);
			close F;
			$attempts++;
			$api->{'err'} = $response->status_line();
			}
		else {
			$api = &ZTOOLKIT::parseparams($response->content());	
			if ($attempts > 0) {
				$api->{'attempts'} = $attempts;
				}
			$success++;
			}
		}

	if ($api->{'err'}) {
		## perhaps we ought to do a carp ticket here.
		}

#	open F, ">>/tmp/payflow.log";
#	print F "VERISIGN RESULTS: [$txt] [$responsetxt]\n".Dumper($api)."\n";
#	close F; 
#	print STDERR "VERISIGN RESULTS: [$txt] [$responsetxt]\n".Dumper($api)."\n";
	return $api;
	}

#Installing /usr/lib/perl5/site_perl/5.6.0/i386-linux/auto/PFProAPI/PFProAPI.so
#Skipping /usr/lib/perl5/site_perl/5.6.0/i386-linux/auto/PFProAPI/PFProAPI.bs (unchanged)
#Files found in blib/arch: installing files in blib/lib into architecture dependent library tree
#Installing /usr/lib/perl5/site_perl/5.6.0/i386-linux/PFProAPI.pm
#Skipping /usr/lib/perl5/site_perl/5.6.0/i386-linux/auto/PFProAPI/autosplit.ix (unchanged)
#Installing /usr/share/man/man3/PFProAPI.3pm
#Writing /usr/lib/perl5/site_perl/5.6.0/i386-linux/auto/PFProAPI/.packlist
#Appending installation info to /usr/lib/perl5/5.6.0/i386-linux/perllocal.pod

########################################
# MSG
# Description: Prints an error message to STDERR (the apache log file)
# Accepts: An error message as a string, or a reference to a variable (if a reference,
#          the name of the variable must be the next item in the list, in the format
#          that Data::Dumper wants it in).  For example:
#          &msg("This house is ON FIRE!!!");
#          &msg(\$foo=>'*foo');
#          &msg(\%foo=>'*foo');
# Returns: Nothing

sub msg {
	my $head = 'ZPAY::VERISIGN: ';
	while ($_ = shift (@_)) {
		if (ref) { require Data::Dumper; $_ = Data::Dumper->Dump([$_], [shift (@_)]); }
		print STDERR $head, join ("\n$head", split (/\n/, $_)), "\n";
		}
	}

1;
