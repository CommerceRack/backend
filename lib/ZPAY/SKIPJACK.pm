package ZPAY::SKIPJACK;

use LWP::UserAgent;
use HTTP::Request;
use Text::CSV;
use strict;

use lib '/backend/lib';
require ZPAY;
require ZTOOLKIT;

## SkipJack :: Denver DeGregorio 888-368-8507 x2132 // denverd@skipjack.com
## Skipjack sucks sucks sucks.

$ZPAY::SKIPJACK::DEVELOPER_SERIAL = '100818546642';
$ZPAY::SKIPJACK::TEST_URL = "https://developer.skipjackic.com/scripts/EvolvCC.dll";
$ZPAY::SKIPJACK::PROD_URL = "https://www.skipjackic.com/scripts/EvolvCC.dll";

my $DEBUG = 1;    # This just outputs debug information to the apache log file

##############################################################################
# SKIPJACK FUNCTIONS

sub new { 
	my ($class,$USERNAME,$WEBDB) = @_;	
	my $self = {}; 
	$self->{'%webdb'} = $WEBDB;
	bless $self, 'ZPAY::SKIPJACK'; 
	return($self);
	}


sub authorize { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('AUTHORIZE',$O2,$payrec,$payment)); }
sub capture { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CAPTURE',$O2,$payrec,$payment)); }
sub charge { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CHARGE',$O2,$payrec,$payment)); }
sub void { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('VOID',$O2,$payrec,$payment)); }
sub credit { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CREDIT',$O2,$payrec,$payment)); } 


sub unified {
	my ($self,$VERB,$O2,$payrec,$payment) = @_;

	my $RESULT = undef;
	
	if (not defined $O2) {
		$RESULT = "999|Order was not passed properly";
		}

	if (defined $RESULT) {
		}

	my $webdbref = $self->{'%webdb'};
	my $api = undef;
	my %params = ();
	my $USERNAME = $O2->username();


	if ($payrec->{'tender'} eq 'CREDIT') {
		$params{'accountnumber'} = &ZPAY::SKIPJACK::safe_data($payment->{'CC'},'0123456789 ');
		$params{'month'} = $payment->{'MM'};
		$params{'year'} = $payment->{'YY'};
		$params{'cvv2'} = $payment->{'CV'};		
		}

	if (defined $RESULT) {
		}
	elsif ($VERB eq 'AUTHORIZE') {
		my $bill_state =  &ZTOOLKIT::gstr($O2->in_get('bill/region'), $O2->in_get('bill/region'));
		my $bill_zip   = &ZTOOLKIT::gstr($O2->in_get('bill/postal'),   $O2->in_get('bill/postal'));
		my $ship_zip   = &ZTOOLKIT::gstr($O2->in_get('ship/postal'),   $O2->in_get('ship/postal'));

		my $order_string = &skipjack_format_order($O2);
		$params{'sjname'} = $O2->in_get('bill/firstname') . ' ' . $O2->in_get('bill/lastname');
		$params{'email'} = $O2->in_get('bill/email');
		$params{'streetaddress'} = $O2->in_get('bill/address1');
		$params{'city'} = $O2->in_get('bill/city');
		$params{'state'} = $bill_state;
		$params{'zipcode'} = $bill_zip;
		$params{'ordernumber'} = &ZPAY::SKIPJACK::safe_data($payrec->{'uuid'},'0123456789');
		$params{'transactionamount'} = ZTOOLKIT::cashy($O2->in_get('order_total'));
		$params{'orderstring'} = $order_string;
		$params{'shiptophone'} = $O2->in_get('ship/phone');
		$params{'streetaddress2'} = $O2->in_get('bill/address2');
		$params{'country'} = $O2->in_get('bill/country');
		$params{'phone'} = $O2->in_get('bill/phone');
		$params{'shiptoname'} = $O2->in_get('ship/firstname').' '.$O2->in_get('ship/lastname');
		$params{'shiptostreetaddress'} = $O2->in_get('ship/address1');
		$params{'shiptostreetaddress2'} = $O2->in_get('ship/address2');
		$params{'shiptocity'} = $O2->in_get('ship/city');
		$params{'shiptostate'} = $O2->in_get('ship/region');
		$params{'shiptozipcode'} = $ship_zip;
		$params{'shiptocountry'} = $O2->in_get('ship/countrycode');
		$params{'comment'} = "IP Address: ".$O2->in_get('cart/ip_address');
		$api = $self->skipjack_auth_call(\%params);
		$payrec->{'auth'} = $api->{'szAuthorizationResponseCode'};
		# $payrec->{'auth'} = $api->{'szTransactionFileName'};
		}
	elsif ($VERB eq 'CAPTURE') {
		$params{'szOrderNumber'} = &ZPAY::SKIPJACK::safe_data($payrec->{'uuid'}, '0123456789');
		$params{'szDesiredStatus'} = 'SETTLE';
		$params{'szForceSettlement'} = '0';
		$api = $self->skipjack_change_call(\%params);
		# $payrec->{'txn'} = $api->{'TransactionId'};
		$payrec->{'txn'} = $api->{'szTransactionId'};
		}
	elsif ($VERB eq 'CHARGE') {
		$RESULT = "999|Gateway does not support instant capture";
		}
	elsif ($VERB eq 'VOID') {
		$RESULT = "999|Gateway does not support void";
		}
	elsif ($VERB eq 'CREDIT') {
		$RESULT = "999|Gateway does not support credits";
		}

	if ((not defined $RESULT) && (defined $api->{'ERROR'})) {
		$RESULT = "257|API ERROR:$api->{'ERROR'}";
		}

	my $approved   = defined($api->{'szIsApproved'}) ? $api->{'szIsApproved'} : '';
	# my $retcode    = defined($api->{'szReturnCode'}) ? $api->{'szReturnCode'} : '';
	# my $auth       = defined($api->{'szAuthorizationResponseCode'}) ? $api->{'szAuthorizationResponseCode'} : '';
	my $cardcode   = defined($api->{'szCVV2ResponseCode'}) ? $api->{'szCVV2ResponseCode'} : '';
	my $avs        = defined($api->{'szAVSResponseCode'}) ? $api->{'szAVSResponseCode'} : '';
	my $retmessage = defined($api->{'szReturnMessage'}) ? $api->{'szReturnMessage'} : '';

	# my $trans = $api->{'szTransactionFileName'};
	# if (not defined $trans) { $trans = $api->{'szTransactionId'}; }
	# if (not defined $trans) { $trans = ''; }

	# AVS Settings
	## $avspc is AVS Partial Code
	#my $avspc = $webdbref->{'cc_avs_fail_code'};    # 105 (Pending) or 205 (Denied)
	#if ((not defined $avspc) || ($avspc eq '')) { $avspc = '402'; }                   # Default to review

	# Voice Auth Settings
	my $voicefail = 202;


	if (defined $RESULT) {
		}
	elsif (not defined $api) {
		$RESULT = "257|empty response from skipjack call";
		}
	elsif ($approved eq '1') {
		if (($api->{'szReturnCode'} eq '1') || ($api->{'szReturnCode'} eq '0')) {
			if ($VERB eq 'AUTHORIZE') {
				$RESULT = "199|Successfully Authorized";
				}
			else {
				$RESULT = "001|Successfully Captured";
				}
			}
		else {
			$RESULT = "256|Skipjack indicated transaction success but authorization was '$api->{'szAuthorizationResponseCode'}' and return code was '$api->{'szReturnCode'}'";
			}
		}
	elsif ($approved eq '0') {
		if    ($api->{'szReturnCode'} eq '-1')  { $RESULT = "253|Invalid Command " . $retmessage; }
		elsif ($api->{'szReturnCode'} eq '-2')  { $RESULT = "253|Parameter Missing " . $retmessage; }
		elsif ($api->{'szReturnCode'} eq '-3')  { $RESULT = "253|Failed retrieving response " . $retmessage; }
		elsif ($api->{'szReturnCode'} eq '-4')  { $RESULT = "253|Invalid Status " . $retmessage; }
		elsif ($api->{'szReturnCode'} eq '-5')  { $RESULT = "253|Failed reading security flags " . $retmessage; }
		elsif ($api->{'szReturnCode'} eq '-6')  { $RESULT = "253|Developer serial number not found " . $retmessage; }
		elsif ($api->{'szReturnCode'} eq '-7')  { $RESULT = "253|Invalid Serial Number " . $retmessage; }
		elsif ($api->{'szReturnCode'} eq '-8')  { $RESULT = "253|Expiration year not four characters " . $retmessage; }
		elsif ($api->{'szReturnCode'} eq '-9')  { $RESULT = "253|Credit card expired " . $retmessage; }
		elsif ($api->{'szReturnCode'} eq '-10') { $RESULT = "253|Invalid starting date (recurring payment) " . $retmessage; }
		elsif ($api->{'szReturnCode'} eq '-11') { $RESULT = "253|Failed adding recurring payment " . $retmessage; }
		elsif ($api->{'szReturnCode'} eq '-12') { $RESULT = "253|Invalid frequency (recurring payment) " . $retmessage; }
		elsif ($api->{'szReturnCode'} eq '-35') { $RESULT = "208|Error invalid credit card number"; }
		elsif ($api->{'szReturnCode'} eq '-37') { $RESULT = "250|Error failed communication"; }
		elsif ($api->{'szReturnCode'} eq '-39') { $RESULT = "251|Length serial number"; }
		elsif ($api->{'szReturnCode'} eq '-51') { $RESULT = "209|Zip code not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-52') { $RESULT = "209|Ship-to zip code not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-53') { $RESULT = "203|Expiration date not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-54') { $RESULT = "203|Account number date not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-55') { $RESULT = "209|Street address not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-56') { $RESULT = "209|Ship-to street address not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-57') { $RESULT = "253|Transaction amount not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-58') { $RESULT = "209|Name not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-59') { $RESULT = "209|Location not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-60') { $RESULT = "209|State not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-61') { $RESULT = "209|Ship-to state not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-62') { $RESULT = "209|Order string not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-64') { $RESULT = "209|Invalid phone number"; }
		elsif ($api->{'szReturnCode'} eq '-65') { $RESULT = "209|Empty name"; }
		elsif ($api->{'szReturnCode'} eq '-66') { $RESULT = "209|Empty email"; }
		elsif ($api->{'szReturnCode'} eq '-67') { $RESULT = "209|Empty street address"; }
		elsif ($api->{'szReturnCode'} eq '-68') { $RESULT = "209|City not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-69') { $RESULT = "209|State not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-79') { $RESULT = "209|Customer name not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-80') { $RESULT = "209|Ship-to customer name not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-81') { $RESULT = "209|Customer location not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-82') { $RESULT = "209|Customer state not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-83') { $RESULT = "209|Ship-to phone not present or not formatted correctly"; }
		elsif ($api->{'szReturnCode'} eq '-84') { $RESULT = "256|Pause error duplicate order number"; }
		elsif ($api->{'szReturnCode'} eq '-91') { $RESULT = "202|Pause error CVV2"; }
		elsif ($api->{'szReturnCode'} eq '-92') { $RESULT = "202|Pause error error approval code"; }
		elsif ($api->{'szReturnCode'} eq '-93') { $RESULT = "202|Pause error blind credits not allowed"; }
		elsif ($api->{'szReturnCode'} eq '-94') { $RESULT = "202|Pause error blind credits fail"; }
		elsif ($api->{'szReturnCode'} eq '-95') { $RESULT = "202|Pause error voice authorizations not allowed'" }
		else { $RESULT = "251|Unrecognized return code [$api->{'szReturnCode'}] contact Zoovy support."; }
		} ## end elsif ($approved eq '0')
	else {
		$RESULT = "251|Unable to contact skipjack server";
		}

	## This section deals with AVS:
	## * If we failed AVS, set AVS Failure code to an appropriate ZOOVY status code
	## * If we got a partial match (on a transaction we thought was good) set the
	##   AVS failure code the partial AVS zoovy status code set above
	## * If we got a full match, set the AVS fail code to blank so we don't flag it
	##   as failed (flow through with the status code set before here)
	## In all cases report the AVS status into the message (this is what has fundamentally
	## changed in the logic of this code, it used to not report anything if set to IGNORE
	## now it reports on it, but IGNORE means it still doesn't do anything based on AVS)
	##  -AK 12/30/02
	my $RS = undef;

	my %k = ();
	if ($RESULT =~ /^[01]\d\d\|/) {
		## we have a 0xx OR 1xx reponse
		my $avsch = '';    ## AVS Failure Code
		if    ($avs eq 'B') { 
				($k{'AVSZ'},$k{'AVST'}) = ('X','X'); $avsch = 'X'; $RESULT .= ' - No data provided for AVS'; }
		elsif ($avs eq 'R') { 
				($k{'AVSZ'},$k{'AVST'}) = ('X','X'); $avsch = 'X'; $RESULT .= ' - Retry transaction later AVS system unavailable' }
		elsif ($avs eq 'G') { 
				($k{'AVSZ'},$k{'AVST'}) = ('X','X'); $avsch = 'X'; $RESULT .= ' - AVS Non-US Bank'; }
		elsif ($avs eq 'S') { 
				($k{'AVSZ'},$k{'AVST'}) = ('X','X'); $avsch = 'X'; $RESULT .= ' - AVS is not supported by the credit card issuer'; }
		elsif ($avs eq 'E') { 
				($k{'AVSZ'},$k{'AVST'}) = ('X','X'); $avsch = 'X'; $RESULT .= ' - AVS General / Unknown Error'; }
		elsif ($avs eq 'X') { 
				($k{'AVSZ'},$k{'AVST'}) = ('M','M'); $avsch = 'A'; $RESULT .= ' - Exact AVS Match'; }                                                                         ## Don't set the fail code (it passed AVS)
		elsif ($avs eq 'Y') { 
				($k{'AVSZ'},$k{'AVST'}) = ('M','M'); $avsch = 'A'; $RESULT .= ' - AVS Address and 5 Digit ZIP matches'; }                                                     ## Don't set the fail code (it passed AVS)
		elsif ($avs eq 'A') { 
				($k{'AVSZ'},$k{'AVST'}) = ('M','N'); $avsch = 'P'; $RESULT .= ' - AVS Address Matches Zip does not'; }                   ## Only set the fail code if it thinks its good and it failed AVS
		elsif ($avs eq 'W') { 
				($k{'AVSZ'},$k{'AVST'}) = ('M','N'); $avsch = 'P'; $RESULT .= ' - AVS 9 Digit ZIP matches Street address does not'; }    ## Only set the fail code if it thinks its good and it failed AVS
		elsif ($avs eq 'Z') { 
				($k{'AVSZ'},$k{'AVST'}) = ('M','N'); $avsch = 'P'; $RESULT .= ' - AVS 5 Digit ZIP matches Street address does not'; }    ## Only set the fail code if it thinks its good and it failed AVS
		elsif ($avs eq 'N') { 
				($k{'AVSZ'},$k{'AVST'}) = ('N','N'); $avsch = 'D'; $RESULT .= ' - AVS No match on address or ZIP'; }
		elsif ($avs eq 'U') { 
				($k{'AVSZ'},$k{'AVST'}) = ('X','X'); $avsch = 'X'; $RESULT .= ' - AVS Address information unavailable'; }
		elsif ($avs eq 'P') { 
				($k{'AVSZ'},$k{'AVST'}) = ('X','X');  }    ## We used to flag this as 205, now we don't change status based on it since it is irrelevant to the transaciton in question.
		elsif ($avs ne '') { 
				($k{'AVSZ'},$k{'AVST'}) = ('X','X'); $avsch = 'X'; $RESULT .= ' - Unrecognized AVS Code'; }
		## Change the AVS Code if we need to (capturing a delayed transaction doesn't
		## use AVS failure codes, since AVS shouldn't be happening, it should have
		## happened on the first hit to Skipjack)  If $avsfc is blank then we have
		## no need to change the code. -AK
		$RS = &ZPAY::review_match($RS,$avsch,&ZTOOLKIT::gstr($webdbref->{'cc_avs_review'},$ZPAY::AVS_REVIEW_DEFAULT));
		}

	
	## CVV2/CVC2/CID Card Code checking
	# Card code CVV2/CVC2/CID settings 
	my $cvvreq = $webdbref->{'cc_cvvcid'};                  # 0, 1 and 2 (1 is optional, 2 is required)
	if ((not defined $cvvreq) || ($cvvreq eq '')) { $cvvreq = 0; }
	my $cvvch = '';
	if (($RESULT =~ /^[01]\d\d\|/) && ($cvvreq)) {
		## Non-zero means we should be reporting on card code failures
		my $cvvfc = '';    ## $cvvfc = CVV failure status code, blank means no failure
		if    ($cardcode eq 'M') { $k{'CVVR'} = 'M'; $cvvch = 'A'; $RESULT .= ' - Card Code CVV2/CVC2/CID Matched card'; }
		elsif ($cardcode eq 'N') { $k{'CVVR'} = 'N'; $cvvch = 'D'; $RESULT .= ' - Card Code CVV2/CVC2/CID Did not match card'; }
		elsif ($cardcode eq 'S') { $k{'CVVR'} = 'N'; $cvvch = 'D'; $RESULT .= ' - Card Code CVV2/CVC2/CID Should have been present'; }
		elsif ($cardcode eq 'U') { $k{'CVVR'} = 'X'; $cvvch = 'X'; $RESULT .= ' - Card Code CVV2/CVC2/CID Issuer unable to process request'; }
		elsif ($cardcode eq 'P') { $k{'CVVR'} = 'X'; $cvvch = 'X'; $RESULT .= ' - Card Code CVV2/CVC2/CID Not Processed'; }
		elsif ($cardcode ne '') { $k{'CVVR'} = 'X'; $cvvch = 'X'; $RESULT .= " - Card Code CVV2/CVC2/CID Unknown code"; }
		## Only change the status if $cvvreq is 2 (required)...  a setting of 1 is optional
		## Otherwise the reporting we added onto $RESULT should do. -AK
		if ($cvvreq == 0) {
			$RS = &ZPAY::review_match($RS,$cvvch,&ZTOOLKIT::gstr($webdbref->{'cc_cvv_review'},$ZPAY::CVV_REVIEW_DEFAULT));
			}
		}

	if (not defined $RS) {
		$O2->in_set('flow/review_status',$RS);
		}

	if (&ZPAY::has_kount($USERNAME)) {
		## store KOUNT values.
		require PLUGIN::KOUNT;
		$payment->{'KH'} = PLUGIN::KOUNT::generate_khash($payment->{'CC'});
		$O2->in_set('flow/kount',sprintf("AVSZ=%s|AVST=%s|CVVR=%s",$k{'AVSZ'},$k{'AVST'},$k{'CVVR'}));
		}

	## Report on the codes sent to us.
	$payrec->{'debug'} = "Skipjack Response $api->{'szReturnCode'} - AVS $avs - Card Code $cardcode"; 

	  ## Old stuff...?

	  #my ($code,$message);
	  #$message = $r{'StatusResponseMessage'}.' SkipJack reports status is '.$r{'DesiredStatus'};
	  #if ($r{'StatusResponse'} eq 'SUCCESSFUL') { $code = '002'; }
	  #elsif ($r{'StatusResponse'} eq 'UNSUCCESSFUL') { $code = '257'; }
	  #elsif ($r{'StatusResponse'} eq 'NOTALLOWED') { $code = '256'; }
	  #else { $code = '255'; $message = 'StatusResponse not set.'; }

	  #my ($code,$message);
	  #$message = $r{'StatusResponseMessage'}.' SkipJack reports status is '.$r{'DesiredStatus'};
	  #if ($r{'StatusResponse'} eq 'SUCCESSFUL') { $code = '303'; }
	  #elsif ($r{'StatusResponse'} eq 'UNSUCCESSFUL') { $code = '257'; }
	  #elsif ($r{'StatusResponse'} eq 'NOTALLOWED') { $code = '256'; }
	  #else { $code = '255'; $message = 'SkipJack Error: '.$content; }

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
		delete $chain{'debug'};
		delete $chain{'note'};
		$chain{'puuid'} = $chain{'uuid'};
		$chain{'uuid'} = $O2->next_payment_uuid();
		$chain{'auth'} = $api->{'szAuthorizationResponseCode'};
		$chain{'txn'} = $api->{'szTransactionId'};	
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
	$payrec->{'r'} = &ZTOOLKIT::buildparams($api);

	$O2->paymentlog("SKIPJACK API REQUEST: ".&ZTOOLKIT::buildparams(\%params));	
	$O2->paymentlog("SKIPJACK API RESPONSE: ".&ZTOOLKIT::buildparams($api));	
	$O2->paymentlog("SKIPJACK RESULT: $RESULT");


	return($payrec);
	}

# Docs at http://www.skipjack.com/resources



########################################
# SKIPJACK GENERATE MESSAGE
# Description: Makes a message describing the results of a skipjack transaction
# Accepts: A reference to a hash with the results of the skipjack call
# Returns: A string describing what occurred with the skipjack transaction
sub skipjack_generate_message {
	my ($hashref) = @_;
	return '(skipjack:' . $hashref->{'x_response_code'} . '/avs' . $hashref->{'x_avs_code'} . ') ' . $hashref->{'x_response_reason_code'};
	}

################################################################################

sub skipjack_auth_call {
	my ($self,$params) = @_;

	my ($webdbref) = $self->{'%webdb'};

	my $testmode = &ZTOOLKIT::num($webdbref->{'skipjack_testmode'});
	my $serial = &ZTOOLKIT::def($webdbref->{'skipjack_htmlserial'});
	if ($serial =~ m/^(.*)\/test$/) { $serial = $1; $testmode = 1; }
	my $url = $testmode ? $ZPAY::SKIPJACK::TEST_URL : $ZPAY::SKIPJACK::PROD_URL ;

	$params = {%{$params}, 'serialnumber' => $serial };

	my $agent = new LWP::UserAgent;
	$agent->agent('Groovy-Zoovy/1.0');
	my $req = new HTTP::Request('POST', "$url?Authorize");
	$req->content(&ZTOOLKIT::makecontent($params));
	my $result  = $agent->request($req);
	my $content = $result->content();
	&msg($result, '*result');
	my $output = {};

	unless ($result->is_success()) {
		&msg("Error: $result->message()");
		return {'ERROR' => $result->message()};
		}
	unless ($content =~ m/\<\!\-\-(.*?)\-\-\>/) {
		&msg("Error: Unable to find output from skipjack.");
		return {'ERROR' => "Unable to find output from skipjack."};
		}
	while ($content =~ s/\<\!\-\-(.*?)\-\-\>//s) {
		my ($name, $value) = split /\=/, $1;
		$output->{$name} = $value;
		}
	$output->{'szReturnMessage'} = $content;
	$output->{'szReturnMessage'} =~ s/^.*?\<body\>(.*)\<\/body\>.*$/$1/si;
	$output->{'szReturnMessage'} =~ s/\<.*?\>//gis;
	$output->{'szReturnTitle'} = $content;
	$output->{'szReturnTitle'} =~ s/^.*?\<title\>(.*)\<\/title\>.*$/$1/si;
	&msg($output, '*output');
	return $output;
} ## end sub skipjack_auth_call

sub skipjack_change_call {
	my ($self,$params) = @_;

	my ($webdbref) = $self->{'%webdb'};

	my $testmode = &ZTOOLKIT::num($webdbref->{'skipjack_testmode'});
	my $serial = &ZTOOLKIT::def($webdbref->{'skipjack_htmlserial'});
	if ($serial =~ m/^(.*)\/test$/) { $serial = $1; $testmode = 1; }
	my $url = $testmode ? $ZPAY::SKIPJACK::TEST_URL : $ZPAY::SKIPJACK::PROD_URL ;

	$params = {%{$params}, 'szSerialNumber' => $serial, 'szDeveloperSerialNumber' => $ZPAY::SKIPJACK::DEVELOPER_SERIAL };

	my $agent = new LWP::UserAgent;
	$agent->agent('Groovy-Zoovy/1.0');
	my $req = new HTTP::Request('POST', "$url?SJAPI_TransactionChangeStatusRequest");
	$req->content(&ZTOOLKIT::makecontent($params));
	my $result  = $agent->request($req);
	my $content = $result->content();
	&msg($result, '*result');
	my $output = {};

	unless ($result->is_success())
	{
		&msg("Error: $result->message()");
		return {'ERROR' => $result->message()};
	}
	if ($content eq '')
	{
		&msg("Error: content returned from skipjack is blank");
		return {'ERROR' => $result->message()};
	}
	my $csv = Text::CSV->new();
	(my $statusline, $content) = split (/[\n\r]+/, $content);
	$csv->parse($statusline);
	my @status = $csv->fields();
	$output->{'szSerialNumber'} = shift @status;
	$output->{'szReturnCode'}   = shift @status;
	if (defined($output->{'szReturnCode'}) && ($output->{'szReturnCode'} eq '0'))
	{
		$csv->parse($content);
		my @fields = $csv->fields();
		$output->{'szSerialNumber'}          = shift @fields;
		$output->{'szTransactionAmount'}     = shift @fields;
		$output->{'szDesiredStatus'}         = shift @fields;
		$output->{'szStatusResponse'}        = shift @fields;
		$output->{'szStatusResponseMessage'} = shift @fields;
		$output->{'szOrderNumber'}           = shift @fields;
		$output->{'szTransactionId'}         = shift @fields;
		$output->{'szIsApproved'}            = '1';
	}
	else
	{
		$output->{'szIsApproved'}    = '0';
		$output->{'szReturnMessage'} = $content;
	}
	&msg($output, '*output');
	return $output;

} ## end sub skipjack_change_call

sub safe_data {
	my ($data, $filter) = @_;
	my $output;
	foreach my $c (split (//, $data)) {
		if (index($filter, $c) >= 0) { $output .= $c; }
		}
	return ($output);
	}

sub skipjack_format_order {
	my ($O2) = @_;

	my $username = $O2->username();
	my $orderid = $O2->oid();

	my $c = '';
#	my %hash = %{$o->stuff()->make_contents()};
#	foreach my $k (keys %hash) {
#		my ($price, $qty, $weight, $tax, $desc) = split (/,/, $hash{$k});
#		$desc =~ s/[^\w ]+//gs;
#		$c .= "$k~$desc~$price~$qty~$tax~||\n";
#		}
	foreach my $item (@{$O2->stuff2()->items()}) {
		my $stid = $item->{'stid'};
		my ($price, $qty, $weight, $tax, $desc) = ($item->{'price'},$item->{'qty'},$item->{'weight'},$item->{'tax'},$item->{'prod_name'});
		$desc =~ s/[^\w ]+//gs;
		$c .= "$stid~$desc~$price~$qty~$tax~||\n";
		}
	return ($c);
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
	my $head = 'ZPAY::SKIPJACK: ';
	while ($_ = shift (@_))
	{
		if (ref) { require Data::Dumper; $_ = Data::Dumper->Dump([$_], [shift (@_)]); }
		print STDERR $head, join ("\n$head", split (/\n/, $_)), "\n";
	}
}

1;


