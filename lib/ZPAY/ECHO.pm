package ZPAY::ECHO;

no warnings 'once';

use HTTP::Request;
use LWP::UserAgent;
use lib '/backend/lib';
require ZPAY;
require ZWEBSITE;
require ZTOOLKIT;
use XML::Parser;
use XML::Parser::EasyTree;
use strict;

# https://wwws.echo-inc.com/IPS_NVP_Transaction_Processing_API.pdf
# While the normal Request/Response time is 6 seconds or less, there are rare instances of delay, 
# usually due to third party involvement in processing. Therefore ECHO suggests leaving the 
# connection open for approximately 45 seconds to incorporate possible delays.

# Test ID : 123>4681958
# PIN     : 75610783
#order type: S is real / F is debug

my $DEBUG = 1; # This just outputs debug information to the apache log file

##############################################################################
# ECHO FUNCTIONS


sub new {
   my ($class, $USERNAME, $webdb) = @_;
   my $self = {};
	$self->{'USERNAME'} = $USERNAME;
	$self->{'%webdb'} = $webdb;
   bless $self, 'ZPAY::ECHO';
	return($self);
   }

sub username { return($_[0]->{'USERNAME'}); }

sub webdb {
	my ($self,$attrib) = @_;

#	my ($package,$file,$line,$sub,$args) = caller(0);
#	print STDERR "WEBDB DEBUG: $package,$file,$line,$sub,$args\n";
#	use Data::Dumper; print STDERR 'WEBDB: '.Dumper($self,$attrib);

	return($self->{'%webdb'}->{$attrib});
	}

##
##
##
sub authorize { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('AUTHORIZE',$O2,$payrec,$payment)); }
sub capture { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CAPTURE',$O2,$payrec,$payment)); }
sub charge { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CHARGE',$O2,$payrec,$payment)); }
sub void { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('VOID',$O2,$payrec,$payment)); }
sub credit { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('REFUND',$O2,$payrec,$payment)); } 


sub unified {
	my ($self, $VERB, $O2, $payrec, $payment) = @_;

	my $RESULT = undef;
	my $USERNAME = $O2->username();


	if (not defined $O2) {
		$RESULT = "999|Undefined order object passed to ECHO::unified";
		}

	if (($VERB eq 'AUTHORIZE') && ($payrec->{'tender'} eq 'ECHECK')) {
		$VERB = 'CHARGE';
		}
	elsif ($VERB eq 'CREDIT') {
		## transaction_type CR
		$RESULT = "900|Credits not available for ECHO.";
		}
	elsif ($VERB eq 'VOID') {
		## transaction_type VT
		$RESULT = "900|Voids are not supported.";
		}

	## NOTE: $payrec->txn field

	my %params = ();
	if (defined $RESULT) {
		}
	elsif (($VERB eq 'AUTHORIZE') && ($payrec->{'tender'} ne 'CREDIT')) {
		$RESULT = "252|$payrec->{'tender'} does not support delayed capture transactions";
		}
	else {

		my $amount = $payrec->{'amt'};
		$amount = &ZTOOLKIT::cashy($amount);

		$params{'order_type'} = 'S'; 	 # S=self service, F=hosted (note: zoovy is not approved)
		$params{'counter'} = time()%7200;
		$params{'billing_ip_address'} = $O2->in_get('cart/ip_address');
		$params{'billing_first_name'} = $O2->in_get('bill/firstname');
		$params{'billing_last_name'} = $O2->in_get('bill/lastname');
		$params{'billing_company_name'} = $O2->in_get('bill/company');
		$params{'billing_address1'} = $O2->in_get('bill/address1');
		$params{'billing_address2'} = $O2->in_get('bill/address2');
		$params{'billing_city'} = $O2->in_get('bill/city');
		$params{'billing_state'} = $O2->in_get('bill/region');
		$params{'billing_zip'} = $O2->in_get('bill/postal');
		$params{'billing_country'} = $O2->in_get('bill/country');
		$params{'billing_phone'} = ((defined $O2->in_get('bill/phone')) && $O2->in_get('bill/phone')) ? $O2->in_get('bill/phone') : '000-000-0000';
		$params{'billing_email'} = $O2->in_get('bill/email');
		$params{'grand_total'} = $amount;
		$params{'product_description'} = $O2->oid();
		$params{'sales_tax'} = ZTOOLKIT::cashy($O2->in_get('sum/tax_total'));
		$params{'merchant_trace_nbr'} = $O2->oid();
		}

	if (($VERB ne 'AUTHORIZE') && ($VERB ne 'CHARGE')) {
		# we only pass payment information on AUTHORIZE or CHARGE
		}
	elsif ($payrec->{'tender'} eq 'CREDIT') {
		$params{'cc_number'} = $payment->{'CC'};
		$params{'ccexp_month'} = $payment->{'MM'};
		$params{'ccexp_year'} = $payment->{'YY'};
		if (defined($payment->{'CV'}) && ($payment->{'CV'} ne '')) {
			$params{'cnp_security'} = $payment->{'CV'};
			}
		}
	elsif ($payrec->{'tender'} eq 'ECHECK') {
		$params{'ec_payee'} = $self->webdb('echeck_payable_to');

		$params{'ec_type'} = ($O2->in_get('bill/company') eq '') ? 'P' : 'B';
		$params{'ec_address1'} = $O2->in_get('bill/address1');
		$params{'ec_address2'} = $O2->in_get('bill/address2');
		$params{'ec_city'} = $O2->in_get('bill/city');
		$params{'ec_email'} = $O2->in_get('bill/email');
		$params{'ec_first_name'} = $O2->in_get('bill/firstname');
		$params{'ec_last_name'} = $O2->in_get('bill/lastname');
		$params{'ec_other_name'} = $O2->in_get('bill/mi');
		$params{'ec_payment_type'} = 'WEB';
		$params{'ec_account'} = $payment->{'EA'};
		$params{'ec_bank_name'} = $payment->{'EB'};
		$params{'ec_rt'} = $payment->{'ER'}; # orderref->{'echeck_aba_number'};
		$params{'ec_serial_number'} = $payment->{'EI'}; # $O2->in_get(('echeck_check_number');
		$params{'ec_state'} = $payment->{'ES'}; # $O2->in_get('bill/region');
		$params{'ec_zip'} = $O2->in_get('bill/postal');
		if (defined($O2->in_get('our/order_ts')) && $O2->in_get('our/order_ts'))	{
			'ec_transaction_dt' => &ZTOOLKIT::unixtime_to_timestamp($O2->in_get('our/order_ts')),
			}
		}

	if (defined $RESULT) {
		## transaction_type: CK (system check)
		## transaction_type: PR (purchase return)
		## transaction_type: PS (purchase))
		}
	elsif ($VERB eq 'AUTHORIZE') {
		$params{'transaction_type'} = 'AV'; # note: should this be AV - means w/AV;
		## transaction_type: AD (Address Verification)
		## transaction_type: AS (Authorization)
		## transaction_type: AV (Authorization w/Address Verification)
		}
	elsif ($VERB eq 'CAPTURE') {
	   $params{'transaction_type'} = 'DS'; # Desposit
		my $cybersource = $self->webdb('echo_cybersource'); # IGNORE PARTIAL and FULL	
		if ($cybersource eq 'NOFRAUD') { $params{'transaction_type'}  = 'CI'; }
		my ($echo_order_num,$echo_etv,$echo_cc_auth) = split(/\^/,$payrec->{'auth'});
		$params{'order_number'} = $echo_order_num;
		$params{'authorization'} = $echo_cc_auth;
		}
	elsif ($VERB eq 'CHARGE') {
		if ($payrec->{'tender'} eq 'CREDIT') {
			# $params{'order_number'} = $echo_order_num;
			## transaction_type: ES (Authorization & Deposit)
			## transaction_type: EV (Authorization & Deposit w/AVS)
			$params{'transaction_type'} = 'EV'; 
			}
		elsif ($payrec->{'tender'} eq 'ECHECK') {
			#$params{'order_number'} = ''; $O2->in_get(('echeck_authorization');
			## transaction_type: DV (Verification)
			## transaction_type: DD (Debit w/Verification)
			## transaction_type: DH (Debit w/Verification ACH only (doesnt include check verification))			
			## transaction_type: EC (Electronic check credit)
			$params{'transaction_type'} = 'DD';
			}
		}
	elsif ($VERB eq 'REFUND') {	 ## CREDIT
		$RESULT = "900|Feature REFUND not supported";
		# POST/nvpapi.asp transaction_type=CR&order_type=S&merchant_echo_id=123>4567890&merchant_pin=12345678&counter=1&billing_ip_address=xxx.xx.xx.xxx&cc_number=9999999999999999&ccexp_month=12&ccexp_year=2008&grand_total=100.00&order_number=0123-45678-90123&original_amount=100.00
		# The order_number submitted is the order_number from the previous Deposit Transaction. 
		# If the order_number is blank for CR, then the original_trandate_mm, original_trandate_dd, 
		# original_trandate_yyyy, and original_reference is required. 
		# If the order_number is present, these fields are ignored
		$params{'transaction_type'} = 'CR';
		$params{'grand_total'} = $payment->{'amt'};
		if ($payrec->{'tender'} eq 'CREDIT') {
			my $acctref = &ZPAY::unpackit($payrec->{'acct'});
			$params{'cc_number'} = $acctref->{'CM'};
			$params{'ccexp_month'} = $acctref->{'MM'};
			$params{'ccexp_year'} = $acctref->{'YY'};
			}
		my ($echo_order_num,$echo_etv) = split(/\^/,$payrec->{'txn'});
		#$params{'order_number'} = $echo_order_num; # $payrec->{'uuid'};

#ECHO API RESPONSE: auth_code=270656&
#avs_result=Y&
#echo_reference=26381159&
#ETV=101300701103090841580833&
#merchant_name=ROCK+MUSIC+JEWELRY+amp%3b+GIF&
#merchant_trace_nbr=2010%2d11%2d18499&
#order_number=0310%2d03419%2d11314&		
		# $params{'order_number'} = '0310-03419-11314';
		$params{'original_reference'} = '26381159';
		# $params{'original_reference'} = 101300701103090841580833
		$params{'original_trandate_mm'} = '11';
		$params{'original_trandate_dd'} = '05';
		$params{'original_trandate_yyyy'} = '2010';
		#$params{'original_reference'} = $echo_etv;
		#$params{'ETV'} = $echo_etv;
		# If the transaction request is CR . Credit . and the order_number is blank, then the original_trandate_mm, original_trandate_dd, original_trandate_yyyy, and original_reference is required. If the order_number is present, these fields are ignored.
		}
	elsif ($VERB eq 'VOID') {	 
		$RESULT = "900|Feature VOID not supported";
		#$params{'transaction_type'} = 'VT';
		#my ($echo_order_num,$echo_etv) = split(/\^/,$payrec->{'txn'});
		#$params{'ETV'} = $echo_etv;
		}
	else {
		$RESULT = "900|Unsupported VERB:$VERB";
		}

	my ($api) = undef;
	if (not defined $RESULT) {
		$api = $self->echo_call(\%params);
		}

	if ($api->{'term_code'} ne '') { $api->{'term_code'}    = int($api->{'term_code'}); }
	if ($api->{'decline_code'} ne '') { $api->{'decline_code'} = int($api->{'decline_code'}); }
	$api->{'status'} = defined($api->{'status'}) ? uc($api->{'status'}) : '';

	if ( (($VERB eq 'AUTHORIZE') || ($VERB eq 'CHARGE')) && ($api->{'auth_code'} ne '')) {
		## NOTE: $payrec->auth field holds order_number^auth_code^ETV
		$payrec->{'auth'} = $api->{'order_number'}.'^'.$api->{'ETV'}.'^'.$api->{'auth_code'};
		}
	if ( (($VERB eq 'CHARGE') || ($VERB eq 'CAPTURE')) && ($api->{'order_number'} ne '')) {
		## NOTE: $payrec->{'txn'} field holds order_number^ETV
		$payrec->{'txn'} = $api->{'order_number'}.'^'.$api->{'ETV'};
		}
	
	# if term_code is defined, then we had a hard failure, lets try to figure out why
	my $RS = undef;
	my %k = ();

	if (($api->{'status'} eq 'R') || ($api->{'status'} eq 'G')) {
		## what is an R?
		if ($payrec->{'tender'} eq 'CREDIT') {
			# Instant or delayed capture?
			if    ($VERB eq 'CHARGE') { $RESULT = '001|'; } # Instant
			elsif ($VERB eq 'CAPTURE') { $RESULT = '002|'; } # Capture authorized
			else                  { $RESULT = '199|'; } # Auth only
			}
		elsif ($payrec->{'tender'} eq 'ECHECK') {
			$RESULT = "120|";
			}
		else {
			$RESULT = '257|Unknown tender type';
			}
	
		if ($api->{'status'} eq 'G') {
			my %AVS_REASON = (
				'X' => 'A:All digits of address and ZIP match (9-digit ZIP)',
				'Y' => 'A:All digits of address and ZIP match (5-digit ZIP)',
				'A' => 'P:Address matches, ZIP does not',
				'W' => 'P:9-digit ZIP matches; address does not',
				'Z' => 'P:5-digit ZIP matches, address does not',
				'U' => 'X:Issuer unavailable or AVS not supported (US Issuer)',
				'G' => 'X:Issuer unavailable or AVS not supported (non-US Issuer)',
				'N' => 'D:Nothing matches',
				'R' => 'X:Retry; system is currently unable to process',
				'S' => 'X:Card issuer does not support AVS',
				'E' => 'X:ECHO received an invalid response from the issuer.',
				);
			$k{'AVST'} = &ZTOOLKIT::translatekeyto($api->{'avs_result'},'X',
				{'X'=>'M','Y'=>'M','A'=>'M','W'=>'N','Z'=>'N','U'=>'X','G'=>'X','N'=>'N','R'=>'X','S'=>'X','E'=>'X'});
			$k{'AVSZ'} = &ZTOOLKIT::translatekeyto($api->{'avs_result'},'X',
				{'X'=>'M','Y'=>'M','A'=>'N','W'=>'M','Z'=>'M','U'=>'X','G'=>'X','N'=>'N','R'=>'X','S'=>'X','E'=>'X'});

			# my $avsreq = $self->webdb('cc_avs_require'); # IGNORE PARTIAL and FULL	
			# $DEBUG && &msg("\$avsreq is '$avsreq'");
			my $avsreason = $AVS_REASON{ $api->{'avs_result'} };
			if (not defined $avsreason) { $avsreason = 'X:Undefined AVS result'; }
			my ($avsch,$avsreason) = split(/:/,$avsreason,2);
			$RS = &ZPAY::review_match("AOK",$avsch,&ZTOOLKIT::gstr($self->webdb("cc_avs_review"),$ZPAY::AVS_REVIEW_DEFAULT));

			## Handle AVS Stuff (perhaps we didn't really get that far)
			#if (($avsreq eq 'FULL') || ($avsreq eq 'NOFRAUD'))	{
			#	if (($avs ne 'X') && ($avs ne 'Y'))	{ $RS = 'RAV'; }
			#	}
			#elsif ($avsreq eq 'PARTIAL') {
			#	if (($avs ne 'X') && ($avs ne 'Y') && ($avs ne 'A') && ($avs ne 'W') && ($avs ne 'Z'))	{ $RS = 'RAV'; }
			#	}
			}
		## we should add CVV checking here.
		}
	elsif ($api->{'status'} eq 'C') {
		$RESULT = "303|"; # Cancelled
		}
	elsif ($api->{'status'} eq 'D') {
		$RESULT = "257|Unknown Decline Reason"; ## Unknown Declined code
		## I just switched from having out own messages to echoing back what ECHO gives us...
		## Their error messages tend to include important messages such as which particular fields had problems, etc.
		if    ($api->{'decline_code'} ==    1) { $RESULT = '200|Refer to card issuer The card must be referred to the issuer before the transaction can be approved. '; }
		elsif ($api->{'decline_code'} ==    3) { $RESULT = '251|Invalid merchant number The merchant submitting the request is not supported by the acquirer. '; }
		elsif ($api->{'decline_code'} ==    4) { $RESULT = '206|Capture card The card number has been listed on the Warning Bulletin File for reasons of counterfeit fraud or other. '; }
		elsif ($api->{'decline_code'} ==    5) { $RESULT = '200|Do not honor The transaction was declined by the issuer without definition or reason. '; }
		elsif ($api->{'decline_code'} ==   12) { $RESULT = '252|Invalid transaction The transaction request presented is not supported or is not valid for the card number presented. '; }
		elsif ($api->{'decline_code'} ==   13) { $RESULT = '253|Invalid amount The amount is below the minimum limit or above the maximum limit the issuer allows for this type of transaction. '; }
		elsif ($api->{'decline_code'} ==   14) { $RESULT = '208|Invalid card number The issuer has indicated this card number is not valid. '; }
		elsif ($api->{'decline_code'} ==   15) { $RESULT = '253|Invalid issuer The issuer number is not valid. '; }
		elsif ($api->{'decline_code'} ==   30) { $RESULT = '253|Format error The transaction was not formatted properly. '; }
		elsif ($api->{'decline_code'} ==   41) { $RESULT = '200|Lost card This card has been reported lost. '; }
		elsif ($api->{'decline_code'} ==   43) { $RESULT = '206|Stolen card This card has been reported stolen. '; }
		elsif ($api->{'decline_code'} ==   51) { $RESULT = '204|Over credit limit The transaction will result in an over credit limit or insufficient funds condition. '; }
		elsif ($api->{'decline_code'} ==   54) { $RESULT = '203|Expired card The card is expired. '; }
		elsif ($api->{'decline_code'} ==   55) { $RESULT = '253|Incorrect PIN The cardholder-entered PIN is incorrect. '; }
		elsif ($api->{'decline_code'} ==   57) { $RESULT = '252|Transaction not permitted (card) This card does not support the type of transaction requested. '; }
		elsif ($api->{'decline_code'} ==   58) { $RESULT = '252|Transaction not permitted (merchant) The merchant\'s account does not support the type of transaction presented. '; }
		elsif ($api->{'decline_code'} ==   61) { $RESULT = '204|Daily withdrawal limit exceeded The cardholder has requested a withdrawal amount in excess of the daily defined maximum. '; }
		elsif ($api->{'decline_code'} ==   62) { $RESULT = '206|Restricted card The card has been restricted. '; }
		elsif ($api->{'decline_code'} ==   63) { $RESULT = '206|Security violation. The card has been restricted. '; }
		elsif ($api->{'decline_code'} ==   65) { $RESULT = '204|Withdrawal limit exceeded The allowed number of daily transactions has been exceeded. '; }
		elsif ($api->{'decline_code'} ==   75) { $RESULT = '206|Pin retries exceeded The allowed number of PIN retries has been exceeded. '; }
		elsif ($api->{'decline_code'} ==   76) { $RESULT = '260|Invalid "to"  account The "to"  (credit) account specified in the transaction does not exist or is not associated with the card number presented. '; }
		elsif ($api->{'decline_code'} ==   77) { $RESULT = '260|Invalid "from" account The "from" (debit) account specified in the transaction does not exist or is not associated with the card number presented. '; }
		elsif ($api->{'decline_code'} ==   78) { $RESULT = '260|Invalid account The "from" (debit) or "to" (credit) account does not exist or is not associated with the card number presented. '; }
		elsif ($api->{'decline_code'} ==   84) { $RESULT = '253|Invalid cycle The authorization life cycle is above or below limits established by the issuer. '; }
		elsif ($api->{'decline_code'} ==   91) { $RESULT = '250|Issuer not available The bank is not available to authorize this transaction. '; }
		elsif ($api->{'decline_code'} ==   92) { $RESULT = '250|Unable to route The transaction does not contain enough information to be routed to the authorizing agency. '; }
		elsif ($api->{'decline_code'} ==   94) { $RESULT = '256|Duplicate transmission The host has detected a duplicate transmission. '; }
		elsif ($api->{'decline_code'} ==   96) { $RESULT = '250|Authorization system error A system error has occurred or the files required for authorization are not available. '; }
		elsif ($api->{'decline_code'} == 1000) { $RESULT = '257|Unrecoverable error. An unrecoverable error has occurred in the ECHONLINE processing. '; }
		elsif ($api->{'decline_code'} == 1001) { $RESULT = '251|Account closed The merchant account has been closed. '; }
		elsif ($api->{'decline_code'} == 1002) { $RESULT = '250|System closed Services for this system are not available. '; }
		elsif ($api->{'decline_code'} == 1003) { $RESULT = '250|E-Mail Down The e-mail function is not available. '; }
		elsif ($api->{'decline_code'} == 1012) { $RESULT = '255|Invalid trans code The host computer received an invalid transaction code. '; }
		elsif ($api->{'decline_code'} == 1013) { $RESULT = '251|Invalid term id The ECHO-ID is invalid. '; }
		elsif ($api->{'decline_code'} == 1015) { $RESULT = '208|Invalid card number The credit card number that was sent to the host computer was invalid. '; }
		elsif ($api->{'decline_code'} == 1016) { $RESULT = '203|Invalid expiry date The card has expired or the expiration date was invalid. '; }
		elsif ($api->{'decline_code'} == 1017) { $RESULT = '209|Invalid amount The dollar amount was less than 1.00 or greater than the maximum allowed for this card. '; }
		elsif ($api->{'decline_code'} == 1019) { $RESULT = '209|Invalid state The state code was invalid. '; }
		elsif ($api->{'decline_code'} == 1021) { $RESULT = '252|Invalid service The merchant or card holder is not allowed to perform that kind of transaction. '; }
		elsif ($api->{'decline_code'} == 1024) { $RESULT = '207|Invalid auth code The authorization number presented with this transaction is incorrect. (deposit transactions only). '; }
		elsif ($api->{'decline_code'} == 1025) { $RESULT = '255|Invalid reference number The reference number presented with this transaction is incorrect or is not numeric. '; }
		elsif ($api->{'decline_code'} == 1029) { $RESULT = '255|Invalid contract number The contract number presented with this transaction is incorrect or is not numeric. '; }
		elsif ($api->{'decline_code'} == 1030) { $RESULT = '253|Invalid inventory data The inventory data presented with this transaction is not ASCII "printable". '; }
		elsif ($api->{'term_code'}   == 30998) { $RESULT = '250|ECHO Internal software error. '; }
		elsif ($api->{'term_code'}   == 20999) { $RESULT = '251|Missing or invalid ECHO-ID. '; }
		elsif ($api->{'term_code'}   == 20998) { $RESULT = '251|Could not validate ECHO-ID. '; }
		elsif ($api->{'term_code'}   == 20997) { $RESULT = '251|Invalid Server - (potential security violation). '; }
		elsif ($api->{'term_code'}   == 20996) { $RESULT = '254|Missing Transaction type. '; }
		elsif ($api->{'term_code'}   == 20995) { $RESULT = '253|Invalid Transaction type. '; }
		elsif ($api->{'term_code'}   == 20994) { $RESULT = '254|Missing duplication counter. '; }
		elsif ($api->{'term_code'}   == 20993) { $RESULT = '253|Duplication counter was not numeric. '; }
		elsif ($api->{'term_code'}   == 20990) { $RESULT = '254|Bad or missing order type. '; }
		elsif ($api->{'term_code'}   == 20989) { $RESULT = '251|Account has been suspended by gateway. '; }
		elsif ($api->{'term_code'}   == 20988) { $RESULT = '252|Merchant is not approved for requested service. '; }
		elsif ($api->{'term_code'}   == 20980) { $RESULT = '254|Shopper IP Address and Phone Number are both missing or invalid. '; }
		elsif ($api->{'term_code'}   == 20979) { $RESULT = '254|A required transaction field is missing. '; }
		elsif ($api->{'term_code'}   == 20978) { $RESULT = '254|A required transaction field is invalid or missing. '; }
		}
	
	
	## Add on the contents of the text results of the echo transaction.
	if ($RESULT eq '') {
		$RESULT = '257|Bad things happened';
		}
	if (defined($api->{'pretty'}) && ($api->{'pretty'} !~ m/^\s*$/)) {
		$RESULT .= " / $api->{'pretty'}";
		}

	if (not defined $RS) {
		$O2->in_set('flow/review_status',$RS);
		}

	my $webdbref = $self->{'%webdb'};
	if (&ZPAY::has_kount($USERNAME)) {
		## store KOUNT values.
		require PLUGIN::KOUNT;
		$payment->{'KH'} = PLUGIN::KOUNT::generate_khash($payment->{'CC'});
		$O2->in_set('flow/kount',sprintf("AVSZ=%s|AVST=%s|CVVR=%s",$k{'AVSZ'},$k{'AVST'},$k{'CVVR'}));
		}


	if (defined $RESULT) {
		if ($RESULT eq '') { $RESULT = "999|Internal error - RESULT was blank"; }

		my $chain = 0;
		if (($VERB eq 'AUTHORIZE') || ($VERB eq 'CHARGE')) { $chain = 0; }
		elsif ($VERB eq 'CREDIT') { $chain++; }
		elsif (substr($RESULT,0,1) eq '2') { $chain++; }
		elsif (substr($RESULT,0,1) eq '3') { $chain++; }
		elsif (substr($RESULT,0,1) eq '6') { $chain++; $payrec->{'voided'} = time(); }
		elsif (substr($RESULT,0,1) eq '9') { $chain++; }

		if ($chain) {
			my %chain = %{$payrec};
			$chain{'puuid'} = $chain{'uuid'};
			$chain{'uuid'} = $O2->next_payment_uuid();
			$chain{'txn'} = $api->{'order_number'}.'^'.$api->{'ETV'};
			$payrec = $O2->add_payment($payrec->{'tender'},$payrec->{'amt'},%chain);
			}


		($payrec->{'ps'},$payrec->{'debug'}) = split(/\|/,$RESULT,2);
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
		## Add on the echo transaction codes
		$payrec->{'r'} = &ZTOOLKIT::buildparams($api);
		}

	$O2->paymentlog("ECHO API REQUEST: ".&ZTOOLKIT::buildparams(\%params));	
	$O2->paymentlog("ECHO API RESPONSE: ".&ZTOOLKIT::buildparams($api));	
	$O2->paymentlog("ECHO RESULT: $RESULT");
	
	return($payrec);
	}



########################################
# ECHO CALL
# Description: Calls the external API
# Accepts: A hash of parameters needed to call PFPro
# Returns: A REFERENCE to a hash of the result codes 
#
sub echo_call {
	my ($self,$params_hash) = @_;
	my %api = ();	# we'll return a pointer to this.

#	my ($package,$file,$line,$sub,$args) = caller(0);
#	print STDERR "CALL DEBUG: $package,$file,$line,$sub,$args\n";
#	$DEBUG && &msg('got to echo_call');

	$params_hash->{'merchant_echo_id'} = $self->webdb('echo_username');
	# $params_hash->{'merchant_echo_id'} =~ s/\<//g;
	$params_hash->{'merchant_pin'} = $self->webdb('echo_password');
	# $params_hash->{'merchant_email'} = ??
	$params_hash->{'isp_echo_id'} = '';
	$params_hash->{'isp_pin'} = '';
	$params_hash->{'debug'} = 'T';
	
	# Create an LWP instance
	my $agent = new LWP::UserAgent;
	$agent->agent('Groovy-Zoovy/1.0');
	# my $req = new HTTP::Request('POST','https://wwws.echo-inc.com/scripts/INR200.EXE');
	my $req = new HTTP::Request('POST','https://nvp.echo-inc.com/nvpapi.asp');

	# $req->content(&ZTOOLKIT::makecontent($params_hash));
	my $c = '';
	foreach my $k (keys %{$params_hash}) {
		$c .= &ZOOVY::incode($k).'='.&ZOOVY::incode($params_hash->{$k}).'&';
		# $c .= sprintf("%s=%s&",$k,$params_hash->{$k});
		}
	chop($c);
	$req->content($c);

	my $result = $agent->request($req);
	my $content = $result->content();
#	print STDERR Dumper($req);

	# content type 2 has useful debugging stuff
	# get it, and strip out html
	$content =~ s/[\&]+//gs;

	if ($content =~ /(<ECHOTYPE2>.*?<\/ECHOTYPE2>)/s) {
		$api{'pretty'} = $1;
		$api{'pretty'} =~ s/\<.*?\>/ /igs;
		$api{'pretty'} =~ s/&nbsp;/ /g;
		$api{'pretty'} =~ s/ /_/gs;
		$api{'pretty'} =~ s/\W+/_/gs;
		$api{'pretty'} =~ s/[\n\r]+/ /g;
		$api{'pretty'} =~ s/_/ /g;
		$api{'pretty'} =~ s/nbsp/ /g; ## Don't know why there are coming through still...?
		$api{'pretty'} =~ s/Please save or print this screen to retain a record of your transaction//s;
		$api{'pretty'} =~ s/Transaction approved Processed by Electronic Clearing House//s;
		$api{'pretty'} =~ s/^\s*//;
		$api{'pretty'} =~ s/\s\s+/. /gs;
		}

	if ($content =~ /(<ECHOTYPE3>.*?<\/ECHOTYPE3>)/s) {
		$content =~ s/[\&]+//gs;
		print STDERR "ECHO returned: ".$content."\n";
		$XML::Parser::Easytree::Noempty=1;
		my $p=new XML::Parser(Style=>'EasyTree');
		my $tree=$p->parse($1);
		$tree = $tree->[0]{'content'};
		foreach my $key (@{$tree})	{
			$api{$key->{'name'}} = $key->{'content'}[0]->{'content'};
			}
		}
	else {
		$api{'ERROR'} = 'ECHO servers did not respond propertly. OUTPUT=['.$content.']';
		}

	require ZOOVY;
#	open F, ">>/tmp/ZPAY.echo.out";
#	print F "--------------------------------------------------\n";
#	print F "SENT: ".$req->as_string()."\n";
#	print F "RECEIVED: ".$content."\n";
#	close F;

	return (\%api);
	}

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

sub msg
{
	my $head = 'ZPAY::ECHO: ';
	while ($_ = shift (@_))
	{
		if (ref) { require Data::Dumper; $_ = Data::Dumper->Dump([$_], [shift (@_)]); }
		print STDERR $head, join ("\n$head", split (/\n/, $_)), "\n";
	}
}

1;


