package ZPAY::PAYPALWP;

use lib "/backend/lib";
use base "ZPAY::PAYPALEC";


##
## note: this module sort piggy backs on the ZPAY::PAYPALEC module
##

use strict;
use Data::Dumper;
use lib "/backend/lib";
require ZOOVY;
require ZPAY::PAYPAL;
require ZTOOLKIT;
require ZWEBSITE;
require ZSHIP;


## https://cms.paypal.com/cms_content/US/en_US/files/developer/PP_NVPAPI_DeveloperGuide.pdf

sub new {
   my ($class, $USERNAME, $webdb) = @_;
   my $self = {};
   bless $self, 'ZPAY::PAYPALWP';
	$self->{'USERNAME'} = $USERNAME;
	$self->{'%webdb'} = $webdb;

	return($self);
   }

##
## note: capture, void, credit are all shared (inherited) from ZPAY::PAYPALEC
##

sub charge {
	my ($self,$O2,$payrec,$payment) = @_;
	return($self->authorizeorcharge('CHARGE',$O2, $payrec, $payment))
	}


sub authorize { 
	my ($self, $O2, $payrec, $payment) = @_; 
	return($self->authorizeorcharge('AUTHORIZE',$O2, $payrec, $payment))
	}


##
## this handles the authorization or charge functions for PAYPALWPP
##
sub authorizeorcharge {
	my ($self,$VERB,$O2,$payrec,$payment) = @_;
	my $USERNAME = $self->{'USERNAME'};
	my $webdb = $self->{'%webdb'};
	my %params = ();
	my $RESULT = undef;

	if (scalar( @{$O2->payments('is_parent'=>1,'skip_uuid'=>$payrec->{'uuid'})} )>0) {
		## so we have more than one parent payment (so this must be a second transaction)
		if ($O2->in_get('sum/order_total') == $payrec->{'amt'}) {
			## if it's for the full amount, then fill out the full amount info.
			&ZPAY::PAYPAL::buildOrder(\%params,$O2,webdb=>$webdb);
			}
		$params{'INVNUM'} = $payrec->{'uuid'};	
		}
	elsif ($O2->in_get('sum/order_total') == $payrec->{'amt'}) {
		## the requested payment amount matches the order total
		&ZPAY::PAYPAL::buildOrder(\%params,$O2,webdb=>$webdb);
		}
	else {
		## this is a chained payment
		$params{'INVNUM'} = $payrec->{'uuid'};
		}
	&ZPAY::PAYPAL::buildHeader($webdb,\%params);
	
	$params{'METHOD'} = 'DoDirectPayment';
	$params{'BUTTONSOURCE'}='Zoovy_Cart_EC_US';
	if ($VERB eq 'AUTHORIZE') {
		$params{'PAYMENTACTION'} = 'Authorization'; # authorize a credit card for later capture.
		}
	elsif ($VERB eq 'CHARGE') {
		$params{'PAYMENTACTION'} = 'Sale'; 
		}
	else {
		$RESULT = "900|Unknown VERB[$VERB] to authorizeorcharge";
		}

	## when we're in DoExpressCheckoutPayment, we don't have this information.
	my $type = substr($payment->{'CC'},0,1);
	if ($type eq '4') { $type = 'Visa'; }
	elsif ($type eq '5') { $type = 'MasterCard'; }
	elsif ($type eq '6') { $type = 'Discover'; }
	elsif ($type eq '3') { $type = 'Amex'; }
	else { $type = 'UNKNOWN:'.$type; }
	$params{'CREDITCARDTYPE'} = $type;
	$params{'ACCT'} = $payment->{'CC'};
	$params{'EXPDATE'} = sprintf("%02d%04d",$payment->{'MM'},$payment->{'YY'}+2000);
	$params{'CVV2'} = $payment->{'CV'};
	if ($params{'CVV2'} eq '') {
		delete $params{'CVV2'};
		}

	## amt comes from payrec on an auth (but not necessarily on a capture, etc.)
	$params{'AMT'} = $payrec->{'amt'};

	if ($O2->username() eq 'pricematters') { $params{'CURRENCYCODE'} = 'CAD'; }


	## this will return a TRANSACTIONID
	my ($api) = undef;
	if (not defined $RESULT) {
		$api = &ZPAY::PAYPAL::doRequest(\%params);
		}


	if (defined $RESULT) {
		}
	elsif ( (($VERB eq 'CREDIT') || ($VERB eq 'VOID')) && ($api->{'ACK'} eq 'AlreadyProcessed') ) {
		## see ticket# 344280
#     'content' => 'SUCCESSFULLY credited order $169.00 - $VAR1 = {
#          \'L_SEVERITYCODE0\' =- \'Error\',
#          \'TIMESTAMP\' =- \'2010-09-07T13:36:35Z\',
#          \'BUILD\' =- \'1482946\',
#          \'L_LONGMESSAGE0\' =- \'You are over the time limit to perform a refund on this transaction\',
#          \'CORRELATIONID\' =- \'48cef2d6a6ae9\',
#          \'L_ERRORCODE0\' =- \'10009\',
#          \'VERSION\' =- \'58\',
#          \'L_SHORTMESSAGE0\' =- \'Transaction refused\',
#          \'ACK\' =- \'AlreadyProcessed\'
#        };
		$RESULT = '200|Paypal['.$api->{'L_ERRORCODE0'}.'] '.$api->{'L_LONGMESSAGE0'};
		}
	elsif (($api->{'ACK'} eq 'Failure') || ($api->{'ACK'} eq 'FailureWithWarning')) {
		$RESULT = '200|Paypal['.$api->{'L_ERRORCODE0'}.'] '.$api->{'L_LONGMESSAGE0'};

		if ($api->{'L_ERRORCODE1'} == 11610) {
			## NOTE: this is L_ERRORCODE1 not L_ERRORCODE0 on purpose
			$RESULT = sprintf("278|Paypal[%s] %s",$api->{'L_ERRORCODE1'},$api->{'L_LONGMESSAGE1'});			
			}
		elsif ($api->{'L_ERRORCODE0'} == 15005) {
			## 15005 we got this from paypal when our mc card was denied due to a security hold.
			$RESULT = sprintf("206|Paypal[%s] %s",$api->{'L_ERRORCODE0'},$api->{'L_LONGMESSAGE0'});			
			}
		elsif ($api->{'L_ERRORCODE0'} == 10536) {
			## 10536 The transaction was refused as a result of a duplicate invoice ID supplied.  Attempt with a new invoice ID			
			$RESULT = sprintf("261|Paypal[%s] %s",$api->{'L_ERRORCODE0'},$api->{'L_LONGMESSAGE0'});			
			}
		elsif ($api->{'L_ERRORCODE0'} == 10556) {
			## This+transaction+cannot+be+processed   (Filter Error)
			$RESULT = sprintf("278|Paypal[%s] %s",$api->{'L_ERRORCODE0'},$api->{'L_LONGMESSAGE0'});			
			}
		elsif (($api->{'L_ERRORCODE0'} == 10002) || ($api->{'L_ERRORCODE0'} == 10501)) {
			## 10002: You do not have permissions to make this API call
			## 10501:  This transaction cannot be processed due to an invalid merchant configuration.
			$RESULT = sprintf("251|Paypal[%s] %s",$api->{'L_ERRORCODE0'},$api->{'L_LONGMESSAGE0'});
			}
		}
	elsif (
		($VERB eq 'AUTHORIZE') && 
		(($api->{'ACK'} eq 'Success') || ($api->{'ACK'} eq 'SuccessWithWarning'))
		) {
		# ACK=SuccessWithWarning&AMT=9%2e82&AVSCODE=Y&BUILD=1603674&
		# CORRELATIONID=74b5e34579265&CURRENCYCODE=USD&CVV2MATCH=I&
		# L_ERRORCODE0=11610&
		# L_LONGMESSAGE0=Payment+Pending+your+review+in+Fraud+Management+Filters&
		# L_SEVERITYCODE0=Warning&L_SHORTMESSAGE0=Payment+Pending+your+review+in+Fraud+Management+Filters&
		# TIMESTAMP=2010%2d11%2d18T21%3a26%3a40Z&TRANSACTIONID=1G394744W4077561B&VERSION=58
		if ($api->{'ACK'} eq 'SuccessWithWarning') {
			$RESULT = sprintf("199|Paypal[%s] %s",$api->{'L_ERRORCODE0'},$api->{'L_LONGMESSAGE0'});		
			}
		else {
			$RESULT = "199|"; ## 189 is the paypal authorization #
			}
		$payment->{'PC'} =  $api->{'CORRELATIONID'};
		$payrec->{'auth'} = $api->{'TRANSACTIONID'};		## the TRANSACTIONID becomes the AUTHORIZATIONID for future
		}
	elsif (
		($VERB eq 'CHARGE') && 
		(($api->{'ACK'} eq 'Success') || ($api->{'ACK'} eq 'SuccessWithWarning')) 
		) {
		# ACK=SuccessWithWarning&AMT=9%2e82&AVSCODE=Y&BUILD=1603674&
		# CORRELATIONID=74b5e34579265&CURRENCYCODE=USD&CVV2MATCH=I&
		# L_ERRORCODE0=11610&
		# L_LONGMESSAGE0=Payment+Pending+your+review+in+Fraud+Management+Filters&
		# L_SEVERITYCODE0=Warning&L_SHORTMESSAGE0=Payment+Pending+your+review+in+Fraud+Management+Filters&
		# TIMESTAMP=2010%2d11%2d18T21%3a26%3a40Z&TRANSACTIONID=1G394744W4077561B&VERSION=58
		if ($api->{'ACK'} eq 'SuccessWithWarning') {
			$RESULT = sprintf("402|Paypal[%s] %s",$api->{'L_ERRORCODE0'},$api->{'L_LONGMESSAGE0'});		
			}
		else {
			$RESULT = "001|"; ##  is the paypal authorization #
			}
		$payment->{'PC'} =  $api->{'CORRELATIONID'};
		$payrec->{'auth'} = $api->{'TRANSACTIONID'};		## the TRANSACTIONID becomes the AUTHORIZATIONID for future
		$payrec->{'txn'} = $api->{'TRANSACTIONID'};		## the TRANSACTIONID becomes the AUTHORIZATIONID for future
		}
	elsif ($api->{'ERR'}) {
		## this is what gets set by zoovy for a variety of API errors
		$RESULT = "250|$api->{'ERR'}";
		}
	else {
		$RESULT = "999|Internal error - RESULT was blank"; 
		}

#	if (not defined $RS) {
#		$O2->set_attrib('review_status',$RS);
#		}

	my %k = ();
	my $webdbref = $self->{'%webdb'};
	if (&ZPAY::has_kount($USERNAME)) {
		## store KOUNT values.
		require PLUGIN::KOUNT;
		$payment->{'KH'} = PLUGIN::KOUNT::generate_khash($payment->{'CC'});
		$O2->in_set('flow/kount',sprintf("AVSZ=%s|AVST=%s|CVVR=%s",$k{'AVSZ'},$k{'AVST'},$k{'CVVR'}));
		}



	if (defined $RESULT) {
		my ($PS,$DEBUG) = split(/\|/,$RESULT,2);
		$payrec->{'ts'} = time();	
		$payrec->{'ps'} = $PS;
		$payrec->{'note'} = $payment->{'note'};
		$payrec->{'debug'} = $DEBUG;

		my %storepayment = %{$payment};
		$storepayment{'CM'} = &ZTOOLKIT::cardmask($payment->{'CC'});		
		if (not &ZPAY::ispsa($payrec->{'ps'},['2','9'])) {
			## if we got a failure, so .. we toss out the CVV, but we'll keep the CC
			delete $storepayment{'CC'};
			}
		delete $storepayment{'CV'};
		$payrec->{'acct'} = &ZPAY::packit(\%storepayment);
		$payrec->{'r'} = &ZTOOLKIT::buildparams($api);
		}
	
	$O2->paymentlog("PAYPALWP API REQUEST: ".&ZTOOLKIT::buildparams(\%params));	
	$O2->paymentlog("PAYPALWP API RESPONSE: ".&ZTOOLKIT::buildparams($api));	
	$O2->paymentlog("PAYPALWP RESULT: $RESULT");

	return($payrec);
	}


##
## note: capture, charge, void, credit, etc. are all loaded PAYPALEC
##


1;


