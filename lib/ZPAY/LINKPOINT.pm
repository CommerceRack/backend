package ZPAY::LINKPOINT;


# test to see if they are up:
# /usr/bin/curl https://secure.linkpt.net:1129/LSGSXML

# 3/4/11 - linkpoint changed CA certificates, CURL broke. command line attempt to access fails.
# see this thread: http://curl.haxx.se/docs/sslcerts.html
# http://curl.haxx.se/docs/caextract.html
#
# new pem files with updated certs can be found here:
# http://curl.haxx.se/ca/cacert.pem
# 
# apparently they use their own self signed certificate - so we can get that and install it:
# openssl s_client -connect secure.linkpt.net:1129 | tee /usr/share/ssl/linkpoint.pem



##
## VERSION HISTORY:
##		1.00 - released
##		1.01 - changed delay capture processing added code 499 for review
##		1.02 - added XML to debugging results hash (will be removed later)
##		1.03 - fixed: wasn't passing fully populated billinginfo
##		1.04 - cleaned up some of the address code
##
$::VERSION = '1.03';

# Visa: 4111111111111 (begin with 4 and 13 digits long total) l   
# MasterCard: 5111111111111111 (begin with 5 and 16 digits long total) l   
# MasterCard: 5419840000000003 (begin with 5 and 16 digits long total) l   
# Amex: 371111111111111 (begin with 37 and 15 digits long total) l   
# Discover: 6011111111111111 (begin with 60 and 16 digits long total) l   
# JCB®: 311111111111111 (begin with 3 and 15 digits long total) l   


use lib '/backend/lib';
require ZTOOLKIT;
require ZOOVY;
require ZPAY;
require ZWEBSITE;
use strict;
use Data::Dumper;

use lib "/backend/lib/ZPAY/linkpoint/30012_perl"; ## LPERL
require lpperl;

my $DEBUG = 1; # This just outputs debug information to the apache log file


sub new {
   my ($class, $USERNAME, $WEBDB) = @_;
   my $self = {};
	$self->{'%webdb'} = $WEBDB;
   bless $self, 'ZPAY::LINKPOINT';
	return($self);
   }

##################################################################################
## SUB buildNode
##
## Supporting Function to build linkpoint xml - tags in two parameters:
##		node (string), $params (hashref e.g. key=>value)
##	returns XML:
##		<node><key>value</key></node>
##
sub buildNode {
	my ($node,$params) = @_;
	my $XML = '';
	$XML = "<$node>\n";
	foreach my $k (keys %{$params}) {
		$XML .= "\t<$k>".&ZOOVY::incode($params->{$k})."</$k>\n";
		}
	$XML .= "</$node>\n";
	}




########################################################################
##
##	sub linkpoint_process
##
## purpose: universal linkpoint interface, called by capture, credit, etc.
##
## RETURNS:
##		$code = payment_status
##		$message = payment_cc_results,payment_echeck_results
##		$hash = (key/value pairs -- used in result log)
##		  cc_bill_transaction/cc_auth_transaction/echeck_auth_transaction		
##		cc_authorization/echeck_authorization
#
## METHOD CAN BE:
##		CHARGE
##		AUTHORIZE
##		CAPTURE (called after AUTHORIZE)
##		VOID
##		CREDIT (pass alt amount)
##		RETURN (a credit for the full order, e.g. merchandise RETURNED)
##
sub unified {
	my ($self,$VERB,$O2,$payrec,$payment) = @_;

   if (not defined $O2) { die("order is not set!");  }

	my $PRT = $O2->prt();
	my $webdbref = $self->{'%webdb'};

	my $RESULT = undef;
	my $USERNAME = $O2->username();

	## PAYMETHOD can be either CREDIT or ECHECK
	my $PAYMETHOD = $payrec->{'tender'};
	if (($PAYMETHOD ne 'CREDIT') && ($PAYMETHOD ne 'ECHECK')) {
		$RESULT = "252|$PAYMETHOD does not support delayed capture transactions";
		}

	## before you ever break this -- be sure to check with marion.
	my $PEMFILE = undef;
	if (not defined $RESULT) {
		$PEMFILE = &ZOOVY::resolve_userpath($O2->username()) . "/linkpoint.pem";
		if ($PRT>0) {
			my $PRTPEMFILE = &ZOOVY::resolve_userpath($O2->username()) . "/linkpoint-$PRT.pem";
			if (-f $PRTPEMFILE) {
				$PEMFILE = $PRTPEMFILE;
				}
			}
		if (! -f $PEMFILE) {  
			$RESULT = "259|could not locate .pem file";
			}
		}

	## Internal use only, this should never be set on a customer account.
	my $testmode = &ZTOOLKIT::def($webdbref->{'linkpoint_testmode'}, 0);
	# $testmode = 1;

	## VALID ORDERTYPES:
	##		CHARGE - instant capture
	##		PREAUTH - authorize only
	##		POSTAUTH - forced ticket (voice auth), or ticket only
	##		VOID
	##		CREDIT
	##
	my $LPTYPE = '';

	if ($VERB eq 'CHARGE') { $LPTYPE = 'SALE'; }
	elsif ($VERB eq 'AUTHORIZE') { $LPTYPE = 'PREAUTH'; }
	elsif ($VERB eq 'CAPTURE') { $LPTYPE = 'POSTAUTH'; }
	elsif ($VERB eq 'VOID') { $LPTYPE = 'VOID'; }
	elsif ($VERB eq 'CREDIT') { $LPTYPE = 'CREDIT'; }


	print STDERR  "VERB: $VERB\n";

	my $XML = '';
	if (not defined $RESULT) {
		$XML .= &buildNode('merchantinfo',{'configfile'=>$webdbref->{'linkpoint_storename'}});

		## result=> This field puts the account in live mode or test mode. Set to LIVE for live mode,
		## GOOD for an approved response in test mode, DECLINE for a declined reponse
		## in test mode, or DUPLICATE for a duplicate response in test mode.
		$XML .= &buildNode('orderoptions',{ 
			'ordertype'=>$LPTYPE,
			'result'=>(($testmode)?'GOOD':'LIVE'),
			});
		my $AMOUNT = $payrec->{'amt'}; 
		$XML .= &buildNode('payment',{ 
			'chargetotal'=>sprintf("%.2f",$AMOUNT) }
			);
		}

	if (defined $RESULT) {
		}
	elsif ($PAYMETHOD eq 'CREDIT') {
		my %params = ();
		$params{'cvmvalue'} = $payment->{'CV'};
		$params{'cvmindicator'} = 'provided'; 
		$params{'cardnumber'} = $payment->{'CC'};
		$params{'cardexpmonth'} = $payment->{'MM'};
		$params{'cardexpyear'} = $payment->{'YY'};
		## CVMINDICATOR: Indicates whether CVM was supplied and, if not, why. The
		## possible values are .provided., .not_provided., .illegible., .not_present., and .no_imprint..
		$XML .= &buildNode('creditcard', \%params);
		}
	elsif ($PAYMETHOD eq 'ECHECK') {
		my %params = ();
		$params{'account'} = $payment->{'EA'}; # $O2->get_attrib('echeck_acct_number');
		$params{'routing'} = $payment->{'ER'}; # $O2->get_attrib('echeck_aba_number');
		$params{'bankname'} = $payment->{'EB'}; # $O2->get_attrib('echeck_bank_name');
		$params{'bankstate'} = $payment->{'ES'}; # $O2->get_attrib('bill_state');
		$params{'dl'} = $payment->{'EL'}; # $O2->get_attrib('drivers_license_number');
		$params{'dlstate'} = $payment->{'EZ'}; # $O2->get_attrib('drivers_license_state');
		$XML .= &buildNode('telecheck', \%params);
		}

	if (not defined $RESULT) {
		my $orderid = $O2->oid();
		if ($payment->{'##'}) {	$orderid .= ".".$payment->{'##'}; }

		# if (defined $O2->in_get(('payment_reset')) { $orderid .= '.'.$payrec->{'##'}; $O2->in_get(('payment_reset'); }
		$XML .= &buildNode('transactiondetails', { 
			'oid'=>$orderid ,
			'transactionorigin'=>'ECI',
			'taxexempt'=>'N',
			'ponumber'=>$O2->in_get('want/po_number'),
			'ip'=>$O2->in_get('cart/ip_address'),
			});
		}

	if (not defined $RESULT) {
		## OID: The Order ID to be assigned to this transaction. For SALE and PREAUTH, this field must be unique. 
		## For VOID, CREDIT, and POSTAUTH, this field must be a valid Order ID from a prior SALE or PREAUTH transaction. For a
		## Forced Ticket (that is a POSTAUTH where the authorization was given over the phone), the oid field is not required, 
		## but the reference_number field is required
		## TRANSACTIONORIGIN: ECI = web/email

		my $addrnum = $O2->in_get('bill/address1');
		if ($addrnum =~ /([\d]+)/) { $addrnum = $1; }
		my $zip = substr($O2->in_get('bill/postal'),0,5);
		if ($zip eq '') { $zip = $O2->in_get('bill/postal'); }
		my $state = $O2->in_get('bill/region');
		if ($state eq '') { $state = $O2->in_get('bill/region'); }
		my $country = $O2->in_get('bill/countrycode');
		if ($country eq '') { $country = 'US'; }

		my %billinfo = ();
		$billinfo{'name'} = $O2->in_get('bill/firstname').' '.$O2->in_get('bill/lastname');
		$billinfo{'address1'} = $O2->in_get('bill/address1');
		$billinfo{'address2'} = $O2->in_get('bill/address2');
		$billinfo{'company'} = $O2->in_get('bill/company');
		$billinfo{'country'} = $country;
		$billinfo{'addrnum'} = $addrnum;
		$billinfo{'city'} = $O2->in_get('bill/city');
		$billinfo{'state'} = $O2->in_get('bill/state');
		$billinfo{'zip'} = $zip;
		$billinfo{'phone'} = $O2->in_get('bill/phone');
		$billinfo{'email'} = $O2->in_get('bill/email');
		$XML .= &buildNode('billing', \%billinfo );
		$XML .= &buildNode('notes', { 'comments'=>$O2->oid() });
		}


	#########################################################################33
	## SANITY: at this point the XML is formatted
	##
	my %api = ();
	if (not defined $RESULT) {
		require lpperl;
		my ($lperl) = LPPERL->new();
		print STDERR "PEMFILE: $PEMFILE\n";

		my $myorder = { 
			host => $testmode ? 'secure.linkpt.net' : 'secure.linkpt.net',,
			port => '1129',
			keyfile => $PEMFILE, # change this to the name and location of your certificate file
			xml => "<order>$XML</order>", # the string we built above
			cargs=>'-m 60 -s -S --insecure', # for now we'll pass our own custom args due to linkpoint certificate issues
			# debugging => 'true', # for development only - not intended for production use
			};

		# Send transaction. Use one of two possible methods
		# $response = $lperl->process($myorder); # use shared library model
		my $response = $lperl->curl_process($myorder); # or use curl methods

		# NB - sending xml returns a string, not an array as in the other samples
		# Print XML server response
		$DEBUG && print STDERR "Response: $response\n\n";
		#OPTIONAL - break XML string into readable hash
		while ($response =~ /<(.*?)>(.*?)<\x2f\1>/gi) {
			$api{$1} = $2;
			}

		$DEBUG && print STDERR "\ndecoded xml:\n";
		while(my($key, $value) = each %api){
			print STDERR "$key = $value\n";
			}
		}

	##############################################
	## SANITY: at this point the call has been made, and %api holds the key/value pairs


	## RESULT FIELDS:
	## r_avs The Address Verification System (AVS) response for this transaction. The first character indicates whether the 
	##		contents of the addrnum tag match the address number on file for the billing address. The second character indicates 
	##		whether the billing zip code matches the billing records. The third character is the raw AVS response from the 
	##		card-issuing bank. The last character indicates whether the cvmvalue was correct and may be .M. for Match, .N. 
	##		for No Match, or .Z. if the match could not determined. See the sections entitled Using Address Verification and
	##		Using the Card Code for additional information on using this information to help you combat fraud.
	##	r_ordernum The order number associated with this transaction.
	## r_error Any error message associated with this transaction.
	##	r_approved The result of the transaction, which may be APPROVED, DECLINED, or FRAUD.
	##	r_code The approval code for this transaction.
	## r_message Any message returned by the processor; e.g., .CALL VOICE CENTER..
	##	r_time The time and date of the transaction server response.
	## r_ref The reference number returned by the credit card processor.
	## r_tdate A server time-date stamp for this transaction. Used to uniquely identify a specific transaction where one order 
	##		number may apply to several individual transactions. See the Transaction Details Data Fields section for further 
	##		information and an example of tdate.
	## r_tax The calculated tax for the order, when the ordertype is calctax.
	## r_shipping The calculated shipping charges for the order, when the ordertype is calcshipping.

	## Okay, now that PC_SUCCESS is defined, we should figure out if the transaction succeeded or failed.
	my $PAYMENT_CC_RESULT = "$api{'r_message'} $api{'r_error'} (Linkpoint: $api{'r_approved'} $api{'code'}) tdate=$api{'r_tdate'} avs=$api{'r_avs'} v=$::VERSION"; 
	$DEBUG && print STDERR "\$PAYMENT_CC_RESULT is '$PAYMENT_CC_RESULT'\n";


	my $RS = undef;
	my %k = ();
	if ($api{'r_approved'} eq 'APPROVED') {
		if ($VERB eq 'VOID' || $VERB eq 'RETURN' || $VERB eq 'CREDIT') { 
			$RESULT = "302|";
			}
		elsif ($PAYMETHOD eq 'CREDIT') {
			# Instant or delayed capture?
			if    ($VERB eq 'CHARGE') { $RESULT = '001|'; } # Instant
			elsif ($VERB eq 'CAPTURE') { $RESULT = '002|'; } # Capture authorized
			elsif ($VERB eq 'AUTHORIZE') { $RESULT = '199|'; } # Auth only

			## Where do I find card code comparison api?
			## A typical transaction result code might look like this. The card code result is highlighted.
			##		0097820000019564:YNAM:12345678901234567890123:
			## The last alphabetic character in the middle (M) is a code indicating the CVV result
			## An "M" indicates that the code matched. This code may or may not be present, depending on whether the card code was passed and 
			## the service was available for the type of card used. 
			my ($cs1,$cs2,$cs3) = split(/\:/,$api{'r_code'}); 	## cs2 is the avs code from cardservice

			############ BEGIN AVS CODE
			## AVS Code DESCRIPTION
			## YY* Address matches, zip code matches
			## YN* Address matches, zip code does not match
			## YX* Address matches, zip code comparison not available
			## NY* Address does not match, zip code matches
			## XY* Address comparison not available, zip code matches
			## NN* Address comparison does not match, zip code does not match
			## NX* Address does not match, zip code comparison not available
			## XN* Address comparison not available, zip code does not match
			## XX* Address comparisons not available, zip code comparison not available
			## (*) -- This is the one character response code sent by the authorizing bank and it
			## varies by card type (e.g., Y,Z,A,N,U,R,S,E,G are valid responses for Visa®;
			## Y,Z,A,N,X,W,U,R,S are valid for MasterCard®; Y,Z,A,N,U,R,S are valid for
			## American Express® and A,Z,Y,N,W,U are valid for Discover®).
			#my $avsreq = $webdbref->{'cc_avs_require'};    # IGNORE PARTIAL and FULL
			#if ($avsreq eq '') { $avsreq = 'FULL'; } elsif ($avsreq eq 'NONE') { $avsreq = 'IGNORE'; }

			my $avsresult = substr($cs2,0,2);	
			my $avsch = '';
			if ($VERB eq 'CAPTURE') {
				## they had their chance to review AVS already!
				}
			elsif ($avsresult eq 'YY') { $avsch = 'A'; } #  Address matches, zip code matches
			elsif ($avsresult eq 'YN') { $avsch = 'P'; } #  Address matches, zip code does not match
			elsif ($avsresult eq 'YX') { $avsch = 'A'; } #  Address matches, zip code comparison not available
			elsif ($avsresult eq 'NY') { $avsch = 'P'; } #  Address does not match, zip code matches
			elsif ($avsresult eq 'XY') { $avsch = 'P'; } #  Address comparison not available, zip code matches
			elsif ($avsresult eq 'NN') { $avsch = 'P'; } #  Address comparison does not match, zip code does not match
			elsif ($avsresult eq 'NX') { $avsch = 'D'; } #  Address does not match, zip code comparison not available
			elsif ($avsresult eq 'XN') { $avsch = 'D'; } #  Address comparison not available, zip code does not match
			elsif ($avsresult eq 'XX') { $avsch = 'X'; } #  Address comparisons not available, zip code comparison not available
			elsif ($avsresult) { $avsch = 'X'; }
			else { $avsch = 'D'; }
			$RS = &ZPAY::review_match($RS,$avsch,&ZTOOLKIT::gstr($webdbref->{"cc_avs_review"},$ZPAY::AVS_REVIEW_DEFAULT));
			$k{'AVST'} = &ZTOOLKIT::translatekeyto(substr($avsresult,0,1),'X',{'Y'=>'M','X'=>'X','N'=>'N'});
			$k{'AVSZ'} = &ZTOOLKIT::translatekeyto(substr($avsresult,1,1),'X',{'Y'=>'M','X'=>'X','N'=>'N'});
			
			############ END AVS CODE
		

			############ BEGIN CVV CODE
			## CVV:
			##	Below is a table showing all the possible return codes and their meanings.
			##		M Card Code Match
			##		N Card code does not match Using the Card Code
			##		P Not processed
			##		S Merchant has indicated that the card code is not present on the card
			##		U Issuer is not certified and/or has not provided encryption keys
			##		  A blank response should indicate that no code was sent and that there was no indication that the code was not present on the card.
			##
			##	What about American Express® and Discover®?
			## Don't they have card codes too? Yes, American Express and Discover do have card codes printed on their cards. 
			## The Gateway does not currently support American Express or Discover card codes, so the card code response will be blank
			## from an American Express or Discover card. We do encourage you to get in the habit of entering card codes from all cards, however.
			##
			my $cvvreq = $webdbref->{'cc_cvvcid'};                   # 0, 1 and 2 (1 is optional, 2 is required)
			if ($VERB eq 'CAPTURE') {
				## they had their chance to review CVV already!
				}
			elsif ((defined $cvvreq) && ($cvvreq ne '')) {
				my $cvvresult = substr($cs2,3,1); 	# 4th digit is significant for CVV
				my $avsch = '';
				if ($cvvresult eq 'N') { $avsch = 'D'; }
				if ($cvvresult eq 'M') { $avsch = 'A'; }
				if ($cvvresult eq 'P') { $avsch = 'X'; }
				if ($cvvresult eq 'P') { $avsch = 'X'; }
				if ($cvvresult eq 'P') { $avsch = 'X'; }
				$k{'AVSZ'} = &ZTOOLKIT::translatekeyto(substr($cvvresult,1,1),'X',{'M'=>'M','N'=>'N','P'=>'X','S'=>'X','U'=>'X'});
				$RS = &ZPAY::review_match($RS,$avsch,&ZTOOLKIT::gstr($webdbref->{"cc_cvv_review"},$ZPAY::CVV_REVIEW_DEFAULT));
				}
			}
		elsif ($PAYMETHOD eq 'ECHECK') {
			$RESULT = "120|";
			}
		}
	elsif (($api{'r_approved'} eq 'DECLINED') || ($api{'r_approved'} eq 'FRAUD')) {
		## yeah, I suppose we could handle more specific errors, if I wasn't feeling so lazy!
		$RESULT = "200|";
		}	
	elsif (($api{'r_approved'} eq '') && ($api{'r_error'} ne '')) {
		$RESULT = "200|$api{'r_error'}";
		}
	elsif ($api{'r_approved'} eq 'DUPLICATE') {
		$RESULT = "261|";
		}
	else {	
		die("Very unknown result!");
		}


	if (not defined $RS) {
		$O2->in_set('flow/review_status',$RS);
		}

	$webdbref = $self->{'%webdb'};
	if (&ZPAY::has_kount($USERNAME)) {
		## store KOUNT values.
		require PLUGIN::KOUNT;
		$payment->{'KH'} = PLUGIN::KOUNT::generate_khash($payment->{'CC'});
		$O2->in_set('flow/kount',sprintf("AVSZ=%s|AVST=%s|CVVR=%s",$k{'AVSZ'},$k{'AVST'},$k{'CVVR'}));
		}


	$DEBUG && print STDERR "PAYMENT_CC_RESULT is $PAYMENT_CC_RESULT\n";

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
			delete $chain{'debug'};
			delete $chain{'note'};
			$chain{'puuid'} = $chain{'uuid'};
			$chain{'uuid'} = $O2->next_payment_uuid();
			$chain{'auth'} = sprintf("%s",$api{'r_code'});	
			$chain{'txn'} = sprintf("%s",$api{'r_code'});	
			$payrec = $O2->add_payment($payrec->{'tender'},$payrec->{'amt'},%chain);
			}

		$payrec->{'ts'} = time();	
		$payrec->{'ps'} = $PS;
		$payrec->{'note'} = $payment->{'note'};
		$payrec->{'debug'} = $DEBUG;
		$payrec->{'auth'} = sprintf("%s",$api{'r_code'});	
		$payrec->{'txn'} = sprintf("%s",$api{'r_code'});	

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
		$payrec->{'r'} = &ZTOOLKIT::buildparams(\%api);
		}

	$O2->paymentlog("LINKPOINT API RESPONSE: ".&ZTOOLKIT::buildparams(\%api));	
	$O2->paymentlog("LINKPOINT RESULT: $RESULT");

	## NOTE: r_tdate isn't actually used, since linkpoint keys in on ordernum
	return($payrec);
	}


sub authorize { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('AUTHORIZE',$O2,$payrec,$payment)); }
sub capture { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CAPTURE',$O2,$payrec,$payment)); }
sub charge { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CHARGE',$O2,$payrec,$payment)); }
sub void { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('VOID',$O2,$payrec,$payment)); }
sub credit { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CREDIT',$O2,$payrec,$payment)); } 


1;

