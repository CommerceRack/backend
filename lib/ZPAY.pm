package ZPAY;

use strict;

##
## Generic Review Code A=approved, X=not available, P=partial, D=Decline
##
$ZPAY::AVS_REVIEW_DEFAULT = 'A=AAV|P=AAV|D=AAV|X=AAV';
@ZPAY::AVS_REVIEW_STATUS = (
	[ '', 'Use Zoovy Recommended Values' ],
	[ 'A=AAV|P=AAV|D=AAV|X=AAV', 'Partial: Approve, No Match: Approve, N/A: Approve' ],
	[ 'A=AAV|P=AAV|D=RAV|X=AAV', 'Partial: Approve, No Match: Review, N/A: Approve' ],
	[ 'A=AAV|P=AAV|D=DAV|X=AAV', 'Partial: Approve, No Match: Decline, N/A: Approve' ],
	[ 'A=AAV|P=AAV|D=DAV|X=RAV', 'Partial: Approve, No Match: Decline, N/A: Review' ],
	[ 'A=AAV|P=AAV|D=RAV|X=RAV', 'Partial: Approve, No Match: Review, N/A: Review' ],
	[ 'A=AAV|P=RAV|D=RAV|X=RAV', 'Partial: Review, No Match: Review, N/A: Review' ],
	[ 'A=AAV|P=RAV|D=DAV|X=RAV', 'Partial: Review, No Match: Decline, N/A: Review' ],
	);

$ZPAY::CVV_REVIEW_DEFAULT = 'A=AAV|D=DCV|X=RCV';
@ZPAY::CVV_REVIEW_STATUS = (
	[ '', 'Use Zoovy Recommended Values' ],
	[ 'A=AAV|D=DCV|X=RCV', 'No Match: Decline, N/A: Review' ],
	[ 'A=AAV|D=DCV|X=ACV', 'No Match: Decline, N/A: Approve' ],
	[ 'A=AAV|D=ACV|X=ACV', 'No Match: Approve, N/A: Approve' ],
	[ 'A=AAV|D=RCV|X=ACV', 'No Match: Review, N/A: Approve' ],
	[ 'A=AAV|D=RCV|X=RCV', 'No Match: Review, N/A: Review' ],
	[ 'A=AAV|D=RCV|X=RCV', 'No Match: Review, N/A: Review' ],
	[ 'A=AAV|D=DCV|X=RCV', 'No Match: Decline, N/A: Review' ],
	);






##
##
##
sub has_kount {
	my ($USERNAME) = @_;

	my $enabled = 0;
	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
	if (defined $gref->{'%kount'}) {
		$enabled = int($gref->{'%kount'}->{'enable'});
		}

	# return(int($webdbref->{'kount'}));
	return($enabled);
	}


##
## takes a string like: PAOK.MA.NA and returns 
##
## perl -e 'use lib "/backend/lib"; 
##		use ZPAY; print &ZPAY::review_match("AOK","D",&ZTOOLKIT::gstr($webdbref->{"cc_avs_review"},"A=AAV|P=AAV|D=DAV|X=RAV"));'
sub review_match {
	my ($RS,$match,$policytxt) = @_;
	
	my $NEW_RS = 'XYY';
	foreach my $set (split(/\|/,$policytxt)) {
		my ($k,$v) = split(/=/,$set,2);
		if ($k eq $match) { $NEW_RS = $v; }
		}

	if ($RS eq '') { 
		## existing $RS is blank, so we'll use the new result.
		$RS = $NEW_RS; 
		}
	elsif ($RS eq 'XYY') {
		$RS = $NEW_RS;	
		}
	elsif ((substr($NEW_RS,0,1) eq 'X') && ($RS eq '')) {
		## get rid of 'X' (uknown) as quick as possible.
		$RS = $NEW_RS;
		}
	elsif (substr($RS,0,1) eq 'A') {
		## Aold vs Anew -- winner is: Anew (unless it's an X)
		if (substr($NEW_RS,0,1) ne 'X') { $RS = $NEW_RS; }
		}
	elsif (substr($RS,0,1) eq 'R') {
		## E and D, trump R
		if (substr($NEW_RS,0,1) ne 'E') { $RS = $NEW_RS; }
		if (substr($NEW_RS,0,1) ne 'D') { $RS = $NEW_RS; }
		}
	elsif (substr($RS,0,1) eq 'E') {
		## D trumps E
		if (substr($NEW_RS,0,1) ne 'D') { $RS = $NEW_RS; }
		}
	elsif (substr($RS,0,1) eq 'D') {
		## D pretty much trumps everything
		if (substr($NEW_RS,0,1) ne 'D') { $RS = $NEW_RS; }
		}
	else {
		$RS = $NEW_RS;
		}

	return($RS);
	}

# review_status
#Approved  AXX   (Green)
#Review  RXX   (Yellow)
#Escalated EXX   (Orange)
#Declined  DXX   (Red)
#Unknown   ''    (white/Not Set)


## PACKIT FORMAT:
## there are WELL KNOWN keys - which are:
###
## LU => logged in user (the luser who made the request)
## $$ => amount we will charge on this payment type 
##	$# => requested (max) *FIXED* amount to charge (cannot exceed T$, can be more than $$) 
##
## TN => tender
## TC => tender created (date valid from ex: wallet created) 
## TD => tender description (ex: WALLET description)
## TE => tender expiration (valid until YYYYMMDDHHMMSS) WALLET/PAYPAL
## T$ => tender available balance set internally by the system (or api) .. many types
## ID => transaction id (many types, can be user/app set)
## IP => ip address that input the payment data.
##
###### SPECIAL FIELDS:  (mostly used for wallets, but might be useful elsewhere)
## #* => boolean preferred/is_default payment method (ex: list of wallets)
## ## => internal counter to track # of attempts (wallet)
##	#! => internal counter of failures 	(wallet)
##
###### wallet
## WI => WALLET ID (this is used internally)
###### giftcard
## GC => giftcard code  (this one is secure, but it might be masked)
## GI => giftcard gcid	(this one is sequential and should never be trusted from a user)
## GP => giftcard promocode   X12  [0] is always a 'G'(version) [1] is a YN for COMBINABLE [2] is a YN for promo class
######
## RP => rewards points  (not in dollars)
## RM => rma number
######
##	AO => Amazon Order #
## BO => buy.com order #
##	DO => doba order #
###### echeck
##	EA => electronic check account #					 [REQUIRED]
## ER => electronic check routing # (aba number) [REQUIRED]
##	EI => electronic check #
## EB => electronic check bank name
## ET => electronic check account type
## EN => electronic check account name
## ES => electronic check bank state
## EL => electronic check drivers license #
## EZ => electronic check drivers license state
###### credit
## C4 => credit card (last 4 digits)
## CM => card masked
##	KH => kount hash
## CC => credit card #		(only stored in secure)
## CT => card type VISA/AMEX/MC/DISC
## YY => two digit year		
## MM => two digit month
## CV => cvv/cid(should never be stored except in debug cases)
##	GW => Gateway/Processor ID
#####
## PC => paypal correlation id
## PS => paypal payerstatus
## PI => paypal payerid (required)
## PT => paypal token	(required)
## PZ => paypal address confirmed
## PR => paypal payment receipt id (confirms a capture)
#### other
## PO = PO #
## CK = check #
#####
## GS => google serial
##	GO => google orderid
## GA => Google Checkout Account ID
##
## takes a hashref returns a string
## currently defautlts to |A:B encoding
##
sub packit {
	my ($hashref) = @_;

	my $out = '';
	foreach my $k (keys %{$hashref}) {
		next if (length($k) != 2);
		$out = "|$k:$hashref->{$k}$out";
		}
	return($out);
	return('?'.&ZTOOLKIT::buildparams($hashref));
	}


## task a string returns a hashref
## in either: |A:B|C:D format or ?A=B&C=D
sub unpackit {
	my ($str,$ref) = @_;

	if (not defined $ref) { $ref = {}; }

	#if (substr($str,0,1) eq '?') {
	#	## leading ? means uses uri encoding rules
	#	$ref = &ZTOOLKIT::parseparams($str);
	#	}
	if (substr($str,0,1) eq '|') {
		foreach my $kv (split(/\|/,$str)) {
			next if ($kv eq '');
			my ($k,$v) = split(/\:/,$kv,2);
			$ref->{$k} = $v;
			}
		}

	## cheap hack for the ORDERv4 upgrades
	if ((defined $ref->{'CC'}) && ($ref->{'CC'} =~ /xxxx/)) {
		## silly app, that value isn't a CC it's a CM (it has xxx's!)
		$ref->{'CM'} = $ref->{'CC'}; delete $ref->{'CC'};
		}

	return($ref);
	}

#sub hash_card {
#	my ($webdbref,$paymentrec) = @_;
#
#	if (int($webdbref->{'kount'})) {
#		require PLUGIN::KOUNT;
#		PLUGIN::KOUNT::generate_khash($paymentrec->{'CC'});
#		}
#	$storepayment{'CM'} = &ZTOOLKIT::cardmask($payment->{'CC'});		
#	$paymentrec->{'CM'} = 
#		}
#	}


## pronounced "is ps a" (ps=payment status)
## a quick helper function to lookup and see if we're a particular type of status
## ex: &ZPAY::ispsa($ps,['1','4']);
sub ispsa {
	my ($ps,$set) = @_;

	my $psch = substr($ps,0,1);
	foreach my $ch (@{$set}) {
		if ($psch eq $ch) { return(1); }
		}
	return(0);
	}


## credit card fields:
# 'payment_cc_results'  => $message -- a message from the gateway! (stored in add_historys)
# 'cc_bill_transaction' => $trans,	-- the transaction id from the gateway
# 'cc_auth_transaction' => 			-- this is the transaction id for the auth stage (if we had one)
# 'cc_authorization'    => $gwcode,	-- the authorization code from the gateway
#
## e-check equivalent fields:
# 'payment_echeck_results'  => $message,
# 'echeck_bill_transaction' => $transid,
# 'echeck_authorization'    => $gwcode,
#

#<option value="01">01 (Jan)</option>
#<option value="02">02 (Feb)</option>
#<option value="03">03 (Mar)</option>
#<option value="04">04 (Apr)</option>
#<option value="05">05 (May)</option>
#<option value="06">06 (Jun)</option>
#<option value="07">07 (Jul)</option>
#<option value="08">08 (Aug)</option>
#<option value="09">09 (Sep)</option>
#<option value="10">10 (Oct)</option>
#<option value="11">11 (Nov)</option>
#<option value="12">12 (Dec)</option>

%ZPAY::REVIEW_STATUS = (
	'AOK' => 'Approved',
	'AAV' => 'Approved - AVS Match',
	'ACV' => 'Approved - CVV Match',
	'AXX' => 'Approved - No reason to review',
	'AZZ' => 'Approved - manual override.',
	'APC' => 'Approved - Paypal Confirmed.',
	'RIS' => 'Review - Reason not specifed.',
	'RAA' => 'Review - AVS Partial Address Match',
	'RAP' => 'Review - AVS Partial Postal Match',
	'RAV' => 'Review - AVS Failure.',
	'RCV' => 'Review - CVV Failure.',
	'RZZ' => 'Review - manual override.',
	'RPC' => 'Review - Paypal Unconfirmed.',
	'EIS' => 'Escalated - Reason not specified.',
	'EZZ' => 'Escalated - manual override.',
	'DIS' => 'Declined - Reason not specified.',
	'DAV' => 'Declined - AVS Failure.',
	'DCV' => 'Declined - CVV Failure.',
	'DSC' => 'Declined - Score is too low.',
	'DZZ' => 'Declined - manual override.',
	'XXX' => 'No Fraud Screen Performed',
	'XYY' => 'Unknown Result Type',
#   '401' =>' Review - Processed using Instant Capture (AVS or CVV failure)',
#   '402' =>' Review - Processed using Delayed Capture (AVS or CVV failure)',
#   '481' => 'Review - Paypal payment processed, but did not match address criteria.',
#   '404' => 'Review - AVS does not match, so order cannot be set to correct status.',
#   '403' => 'Review - AVS Failure -- undetermined cause.',
#   '409' => 'Review - CVV failure.',
#   '410' => 'Review - CVV could not be processed (issuer not available).',
#   '411' => 'Review - GoogleCheckout',
#   '421' => 'Review - Kount recommended ',
#   '422' => 'Review - Kount recommended Merchant Review',
#   '429' => 'Review - Kount recommended Merchant Review before capture.',
#   '489' => 'Review - Paypal success w/warning',
#   '499' => 'Review - Authorization obtained, but please review before capturing.',
	);

use lib '/backend/lib';
require ZWEBSITE;
require ZSHIP;
use strict;



require Exporter;
@ZPAY::ISA = qw(Exporter);

# Exported by default
@ZPAY::EXPORT = qw(@PAY_METHODS @CC_TYPES);
# Allowable to be exported to foreign namespaces
@ZPAY::EXPORT_OK = qw();
# These are the logical groupings of exported functions
%ZPAY::EXPORT_TAGS = (); 

my $DEBUG = 0; # This only outputs debug information to the apache log file
my $results_debug = 1; # This will dump a rendering of the results hash for a transaction into /tmp/ORDERID_unixtime.results
$DEBUG && &msg('zpay_called');


%ZPAY::RETURN_REASON = (
	'DAMAGED'=>'',
	'UNWANTED'=>'',
	'OTHER'=>''
	);


%ZPAY::PAYMENT_STATUS = (
	## 0xx are paid in full, should be applied towards order_total
	'000' => 'Paid - Status Set Manually',
	'001' => 'Paid - Processed using Instant Capture',
	'002' => 'Paid - Processed using Delayed Capture',
	'003' => 'Paid - Manually created on web',
	'004' => 'Paid - Web API Updated',
	'005' => 'Paid - Via external credit card terminal',
	'006' => 'Paid - Electronic Check',
	'007' => 'Paid Address Inquiry - The payment for this tranaction is was approved, but the address on file with the payment method does not match their records.',
	'008' => 'Paid Address Changed - The payment for this tranaction is was approved, but the address information in the order was modified to match what was on file with the payment prcoessor.',
	'009' => 'Paid - Zero dollar order',
	'010' => 'Paid - via Amazon.com',
	'011' => 'Paid - via GoogleCheckout',
	'019' => 'Paid - Marketplace',
	'020' => 'Paid - via Buy.com',
	'021' => 'Paid - via Sears.com',
	'022' => 'Paid - via HSN',
	'025' => 'Paid - batch flagged as paid on web',
	'030' => 'Paid - TESTING GATEWAY ONLY',
	'050'	=> 'Paid - via Paypal (verified buyer)',
	'051'	=> 'Paid - via Paypal (intl verified buyer)',
	'052' => 'Paid - via Paypal (unverified buyer)',
	'053' => 'Paid - via Paypal (intl unverified buyer)',
	'089' => 'Paid - via Paypal DoExpressCheckout Capture',
	'060' => 'Paid - via eBay',
	'066' => 'Paid - Wire',
	'067' => 'Paid - Purchase Order',
	'068' => 'Paid - Check',
	'069' => 'Paid - Cash',
	'070' => 'Paid - Giftcard',
	'075' => 'Paid - Processed via Zoovy Support',
	'076' => 'Paid - Processed via Bing Support',
	'088' => 'Adjusted',
	'090' => 'Paid - Multiple Payment Methods',
	'094' => 'Paid - Paid at pickup',

	## 1xx are pending capture, summed towards balance_auth, changed to 0xx on paid.
	##		if an error occurrs attempting to capture a 1xx order, a new 2xx should be created.

	## PAYPALEC, GOOGLE, CREDIT with payment status of 109,179,189,199

	'100' => 'Pending Manual Interaction - must be manually set to another status by merchant.',
	'101' => 'Waiting for Payment - must be manually approved when payment is received.',
	'103' => 'Pending Voice Authorization - contact bank and then process via gateway, manually update payment status afterwards.',
	'104' => 'Pending - incomplete/insufficient funds were submitted by user',
	'105' => 'Pending AVS Verification - Transaction successfully processed, however AVS result failed! Either set the order to paid, or void/credit the sale.',
	'106' => 'Pending Paypal - The payment for this transaction is waiting for the user to visit the PayPal system and make payment.',
	'107' => 'Pending Address Inquiry - The payment for this tranaction is was approved, but the address on file with the payment method does not match their records.',
	'108' => 'Pending Address Changed - The payment for this tranaction is was approved, but the address information in the order was modified to match what was on file with the payment prcoessor.',
	'109' => 'Pending Initial Processing - The merchant has a gateway account but has elected to manually charge via instant capture later.  The merchant has not yet performed this capture.',
	'110' => 'Pending Amazon Simple Pay - The payment for this transaction is waiting for the user to visit Amazon and make payment.',
	'111' => 'Pending for Google Fraud & Financial Review',
	'120' => 'Pending Clearance - Transaction successfully processed, waiting for order to be manually flagged after funds have cleared.',
	'130' => 'Pending - TESTING GATEWAY ONLY',
	'150' => 'Waiting - this is waiting for payment to be automatically cleared by the system.',
	'160' => 'Pending - Waiting for Settlement via eBay',
	'165' => 'Pending - Money Order/Cashiers Check',
	'166' => 'Pending - Wire Transfer',
	'167' => 'Pending - Purchase Order Credit Limit',
	'168' => 'Waiting - Payment will be mailed',
	'169' => 'Waiting - for cash payment.', #  would be "waiting for cash"
	'175' => 'Pending - set to pending by Zoovy Support',
	# '179' => 'Pending - reserved for capturable status',
	'188' => 'Pending - Paypal eCheck',
	'189' => 'Pending - Paypal DoExpressCheckout',
	'190' => 'Pending - Multiple Payment Methods require Capture',
	## PICKUP
	'194' => 'Waiting - Customer will Pay at Pickup',
	## LAYAWAY
	'195' => 'Layaway - Customer will choose and process payment method online.',
	## WILLCALL (? not used)
	'196' => 'Pending - customer will call and provide credit card #',
	'197' => 'Pending - need to make request with manual processor',
	'198' => 'Pending Reprocessing  - payment information updated by customer after a failure.',
	'199' => 'Pending Capture - currently authorized only, transaction must be captured to transfer funds.',

	## 2xx series are errors, they don't affect balance_paid, they can be origin, or chained transactions.
	##	origin 2xx payrec is created when a payment fails to authorize or instant capture
	## chained 2xx payrec is created when an authorization can't be turned into a capture.
	'200' => 'Declined - Approval was declined (reason not specified, contact the gateway)',
	'202' => 'Voice Authorization - Approval was denied due to request for Voice Authorization, customer was told the order failed.',
	'203' => 'Invalid Expiration - The issuing bank said the expiration given did not match the card.',
	'204' => 'Insufficient Funds - The cardholder did not have sufficient funds available to purchase this order.',
	'205' => 'AVS Failed - the gateway reports an Address Verification System failure.',
	'206' => 'Fraud - The gateway reports the card as a fraud risk.',
	'207' => 'Verification Code - The CID or CVV code provided was not correct.',
	'208' => 'Invalid Checksum - The credit card is not a valid number.',
	'209' => 'Data Validation Error - The data that was supplied to a field was not properly formatted.',
	'210' => 'CVV Check Failed. Number provided is wrong',
	'211' => 'Credits are not supported by this gateway - please check webdoc for more information on how to resolve this.',
	'212' => 'VOIDs are not supported by this gateway - please check webdoc for more information on how to resolve this.',
	'230' => 'Denied - TESTING GATEWAY ONLY',
	'249' => 'Gateway Unavailable - Zoovy could not reach the gateway or the gateway api returned an unstructured response, or other API error.',
	'250' => 'Processor Unavailable - The transaction failed because the card processor or bank could not be contacted by gateway.',
	'251' => 'Gateway Authentication Failed - Gateway response code indicates credentials provided for the gateway were not valid or have expired.',
	'252' => 'Disallowed - Invalid tender, the bank/account does not support that type of payment.',
	'253' => 'Bad Request - Badly formatted data was input, invalid amount, or field format error.',
	'254' => 'Missing Data - the gateway reported at least one required field was missing.',
	'255' => 'Merchant Unrecognized - The transaction failed because the processor or bank did not recognize the merchant information.',
	'256' => 'Critical - The transaction failed due to an internal inconsistency (i.e., capturing against an authorization that was already captured, crediting a transaction that never existed, etc).',
	'257' => 'Unknown - The gateway returned results the zoovy system does not recognize.',
	'258' => 'In Process - The transaction failed because the card processor or bank had locked the transaction while processing it.',
	'259' => 'Gateway API Error - Failure to communicate, the gateway was either down, or contacted using an incorrect implementation or outdated version of its interface.',
	'260' => 'Purchaser Unrecognized - The transaction failed because the processor or bank did not recognize the purchaer information.',
	'261' => 'Duplicate Transaction - The transaction failed because the processor has already completed another transaction which is identical.',
	'262' => 'Transaction Expired - The transaction could not be completed because the amount of time available has been exceed.',
	'270' => 'Giftcard does not have sufficient balance to process transaction',
	'275' => 'Debug - this order has been flagged for debugging by Zoovy Support',
	'278' => 'Fraud - gateway would not accept the payment due to built in fraud filters',
	'286' => 'Paypal 10481,10482 - please establish/upgrade the receiving Paypal account to a business account',
	'287' => 'Paypal 10474 error - paypal refused txn due to buyer address not matching country',
	'288' => 'Paypal 10417 error - paypal will not process payment (contact paypal for more detail)',
	'289' => 'Paypal Express Checkout Failure',
	'290' => 'Multiple failure attempts to correct Payment',
	'291' => 'Wallet does not match customer record',
	'299' => 'Partial AVS Failure - An Authorization was given, but AVS failed. The customer informed order failed, verify and void the authorization.',

	## 3xx series are "Refunds" (meaning that they should decement the balance_paid)
	## origin 3xx can only be created by merchants.
	'300' => 'Returned - payment was Returned by the Merchant (manual override)',
	'301' => 'Returned - payment was Returned by the Customer.',
	'302' => 'Returned - The Zoovy System automatically returned this order.',
	'303' => 'Returned - Remote gateway acknowledged partial or full refund.',
	'310' => 'Returned - Amazon.com',
	'311'	=> 'Returned - GoogleCheckout Refunded this transaction.',
	'312' => 'Returned - Google cancelled this order due to non-payment by the buyer.',
	'319' => 'Returned - Payment amount was refunded on marketplace by merchant.',
	'330' => 'Returned - TESTING GATEWAY ONLY',
   '321' => 'Returned - Sears.com',
   '322' => 'Returned - HSN',
	'368' => 'Returned - check returned to customer',
	'369' => 'Returned - cash to client',
	'370' => 'Returned - Deposit on Giftcard',
	'375' => 'Returned - this order was Returned by Zoovy Support.',
	'389' => 'Returned - Paypal transaction was voided/refunded.',
	'390' => 'Returned - one or more payments on this order was fully returned.',

	## 4xx series are success w/warnings. most of the time 0xx and 4xx are the same.
	## special cases: see ticket #446928
	'400' => 'Review - Reason not specified. (manual override)',
	'401' =>' Review - Processed using Instant Capture (AVS or CVV failure)',
	'402' =>' Review - Processed using Delayed Capture (AVS or CVV failure)',
	'481' => 'Review - Paypal payment processed, but did not match address criteria.',
	'404' => 'Review - AVS does not match, so order cannot be set to correct status.',
	'403' => 'Review - AVS Failure -- undetermined cause.',
	'409' => 'Review - CVV failure.',
	'410' => 'Review - CVV could not be processed (issuer not available).',
	'411' => 'Review - GoogleCheckout',
	'421' => 'Review - Kount recommended Review',
	'422' => 'Review - Kount recommended Merchant Review',
	'429' => 'Review - Kount recommended Merchant Review before capture.',
	'430' => 'Review - TESTING GATEWAY ONLY',
	'467' => 'Review - Purchase Order',	# used when PO should be sent, but has not been paid.
	'478' => 'Review - Received review condition from fraud filters at Gateway',
	'489' => 'Review - Paypal success w/warning',
	# '490' RESERVED FOR MULTIPLE PAYMENT METHODS
	'499' => 'Review - Authorization obtained, but please review before capturing.',

	## 5xx series are special 'processing' states, they will become another state with time.
	'500' => 'Processing - new payment (status unknown)',
	'501' => 'Processing - new payment (from zid status unknown)',
	'511' => 'Processing - Waiting for async notification from GoogleCheckout.',
	'512' => 'Processing - Waiting for async credit/void notification from GoogleCheckout.',
	'560' => 'Processing - Waiting for eBay Payment Notification',

	# '590' RESERVED FOR MULTIPLE PAYMENT METHODS
	'599' => 'Processing - created order via ZID client (waiting for charge)',

	## 6xx series, have the effect of nullifying their parent transaction.
	'600' => 'Void - This order was Voided by the Merchant (manual override)',
	'601' => 'Void - This order was Voided by the Customer.',
	'602' => 'Void - The Zoovy System automatically cancelled this order.',
	'603' => 'Void - The gateway returned this transaction has been cancelled.',
	'611'	=> 'Void - GoogleCheckout Refunded this transaction.',
	'612' => 'Void - Google cancelled this order due to non-payment by the buyer.',
	'619' => 'Void - Order was cancelled on marketplace by merchant.',
   '621' => 'Void - Sears.com',
   '622' => 'Void - HSN',
	'630' => 'Void - TESTING GATEWAY ONLY',
	'668' => 'Void - Check was NSF',
	'669' => 'Void - Cash was returned to client.',
	'675' => 'Void - this order was Voided by Zoovy Support.',
	'689' => 'Void - Paypal transaction was voided',
	'699' => 'Void - all payments on this order have been voided or cancelled.',

	# 7xx waiting

	# 8xx reserved | adjustment/corrections
	'800' => 'Manual Adjustment',
	'887'	=> 'Order Combined',
	'888' => 'Transfer - sent',
	'889' => 'Transfer - received',

	'900' => 'Error - feature not available',
	'901' => 'Error - (ISE) invalid payrec sent to module.',
	'902' => 'Error - no payments on order.',
	'903' => 'Error - no items or payments in order.',
	'904' => 'Error - insufficient funds necessary to process the order.',
	'911' => 'Error - Google Checkout Unknown Order State',
	'970' => 'Error - Requested charge on an invalid giftcard id.',
	'990' => 'Error - Error determining one or more payment methods status.',
	'998' => 'Error - please verify account configuration.',
	'999' => 'Error - something bad happened internally.',
	);


%ZPAY::PAYMENT_STATUS_HELPER = (
	'000'=>q~
0xx series payment codes are used to indicate a successful paid in full and settled/deposited (or at least settlement pending) transaction.
The amount of a 0xx transaction will be applied to the balance_paid which will decrease the balance_due.
Once an order has it's balance_paid set at, or above the balance_due then the order is considered paid in full.
000 is a reserved for merchants who wish to manually overriding a payment to "paid in full".
~,
	'001'=>q~The Instant Capture code means that according to Zoovy the funds for a specific order was successfully captured by a gateway at the time the order was placed and will be settled at the next available settlement (this may be either instantly, or within 24 hours depending on the gateay). For more detail about this transaction view the payment_cc_result to find gateway and/or processors transaction number (if available) and look up the transaction using the gateway's user interface.~,
	'002'=>q~The Delayed Capture code means that the funds for a specific order was successfully captured by a gateway after the order was placed because the Zoovy account is configured to only obtain authorizations when an order placed. These authorization must be subsequently captured (therefore called a delayed capture). The funds for this transaction will be settled in the next available settlement (this may be either instantly, or within 24 hours depending on the gateway you are using). For more detail about this transaction view the payment_cc_result to find gateway and/or processors transaction number (if available) or look up the transactions detail via the gateway's user interface.~,
	'003'=>q~This means that either the Zoovy Order Manager, or another 3rd party client was used to update the status of this transaction to paid.~,
	'088'=>q~
Adjustments are special payments that are applied by supervisors or other customer service representatives as special
exception credits. These will typically be stored as journal entries in a merchants accounting system.
~,
	'100'=>q~
1xx series are pending capture, they are specifically for payments which have been authorized, but have not been settled.
100 is reserved for a manual 'user defined' process, it can only be set by a merchant and it will never be used by an automated system.
~,
	'101'=>q~This means that either the payment type selected does not support authorization or capture, or that the payment type configured requires manual intervention (specifically acknowledgement of funds received by a person) before the order should be processed.~,
	'103'=>q~This status occurs when a gateway requires a voice authorization to be sent in. Once a voice authorization has been obtained, then process the transaction manually through the gateway user interface, and then move the sale to paid.~,
	'104'=>q~This status is most commonly associated with an order where items were added to the order after it was placed and the user will need to supply
additional funds to pay for the item.  This is normally a temporary status until an appropriate payment method is added by the merchant
(such as lay away)~,
	'105'=>q~This status occurs if the Merchant has successfully authorized (or captured) a transaction, but the AVS failed so Zoovy did not automatically move the order to paid. In this case verify the order contents, then either manually capture the sale using the gateway user interface, or simply move the sale to paid (if the transaction was already captured). Each gateway handles this a little differently, in many cases it is preferrable to configure the gateway to allow/deny the AVS order, so that Zoovy will automatically move it to either Paid or Denied rather than moving it to pending where it must be manually processed. Unfortunately not all gateway's support AVS filtering so this is really more of a work-around for misconfigure or feature-lacking gateways.~,
	'106'=>q~This status specifically means one of two things: either that the customer has been sent to Paypal to send payment, or that Paypal has not actually captured the funds. If Paypal is configured for instant payment notification then this status will automatically move to paid once the transaction has been successfully captured and the funds have been transferred (or will be transferred soon.) If instant payment notification is not configured for a Paypal account, then the Merchant must manually login to their Paypal account, and once funds have been verified then manually move the sale to paid.~,
	'150'=>q~This status is reserved for internal use, for example some payment types like electronic checks, have two levels of success, one of the intial transaction, however most merchants do not realize that after a transaction is successfully captured, there is a mandatory 10 day holding period, which means the payment may still be returned via Non-sufficient funds. In the add_history the payment is returned to the Merchant as non-sufficient funds then the Merchant must manually move this status to DENIED. Otherwise Zoovy will wait for the normal clearing process (such as a 10 day waiting period) before automatically moving the order to paid. Unfortunately in most circumstances there is no way for Zoovy to verify the payment was successfully transferred and will not be returned as non-sufficient funds.~,
	'199'=>q~If a gateway is configured for delayed capture, it will only obtain an authorization - then the Merchant will need to use the capture facility in either the Zoovy Windows Order Manager, or the Order Management in their Zoovy account.~,
	'200'=>q~2xx series codes are for transactions which have failed/declined or errored or the response format was not understood and was considered an error.
2xx series codes do not impact the balance_paid, balance_due, or balance_auth, they are kept merely for posterity to show an attempt
was made, but it didn't work. 
200 is a general decline, which usually means the Merchant manually set the payment status to denied.
~,
	'202'=>q~This means the merchants Zoovy account is configured to reject orders which require a voice authorization. In this circumstance, although a voice authorization may be possible the Merchant does not want to deal with trying to obtain one and would rather return a failure to the customer telling them they card could not be processed.~,
	'203'=>q~The Zoovy checkout automatically verifies that the expiration date for a card is sometime in the future, however it is not possible for Zoovy to verify that the expiration date matches the card. In most cases this is caused by simple user error, however in some cases it could also indicate the presence of fraud. In these circumstances the best advice is to manually contact the customer, verify the expiration date, fix any problems and and re-authorize the order.~,
	'204'=>q~The most common reason for a electronic payment transfer is a simple lack of funds. In this case the customer was notified the transaction failed. Each merchant handles this a little differently, some merchants simply delete the order. Others will contact the customer, or automatically wait a few days and attempt to re-authorize the order.~,
	'205'=>q~For gateways which support AVS filtering, this indicates a transaction failed because the order did not meet the configured AVS fraud settings.~,
	'206'=>q~This code incidates a fraudlent transaction for a reason other than AVS. In some rare cases it may also be caused by a misconfigured, or feature lacking AVS filtering system. Consult the gateways user interface to determine the specific cause of the problem.~,
	'207'=>q~If the gateway supports CID/CVV numbers, this would indicate either the user mistyped the CVV/CVC/CID or had a fraudulent card and therefore lacked the required information. Contact the customer and verify the number, if the current number is incorrect then fix it and attempt to re-process the order.~,
	'250'=>q~This code indicates a failure by the gateway to connect to the Merchant Processor. To resolve this problem contact the Gateway provider and provide them with the codes from the payment_cc_results (which holds the relevant information sent back from the gateway).~,
	'251'=>q~This usually indicates the username or password supplied for the gateway is incorrect. Please note: not all gateways, or more specifically Cardservice, do not have a seperate code for username/password being correct. Any error code 250-299 could indicate the presence of an incorrect username, password, service provider, or invalid PEM file. This code is set ONLY if the gateway supports telling Zoovy that the username and password was invalid. In other words don't assume that just because the status isn't code #255 that the username and/or password are correct rather it is better to always verify all account information before contacting technical support - this will save valuable time in resolving your issue.~,
	'252'=>q~This code indicates that the Merchant account and/or Gateway is not configured to accept the specified payment type, for example processing American Express without being authorized to take American Express. First verify the card number listed is accepted by the Merchant Account (numbers starting with a 3 are Mastercard, 4 are Visa, 5 are American Express, and 6 are Discover). If the problem persists contact the gateway provider to have them verify the account configuration. The most likely culprit of a misconfigured account is the incorrect MID (Merchant ID) or TID (Terminal ID).~,
	'253'=>q~This indicates that failure occurred betwee Zoovy and the Gateway, in most circumstances this occurs because Zoovy did not properly format the transaction for the gateway. Contact the support provider, be sure to provide them with the order number and any other relevant information.~,
	'255'=>q~This code indicates that the transaction was sent from Zoovy to the gateway successfully,
and that the error occurred while sending the transaction from the gateway to the processor unsuccessfully.  
The gateway received an error from the processor which indicated they
did not recognize the account. There are a variety of causes for this type of error - and it is
very difficult to tell the exact cause because each gateway/platform interacts differently. 

First check the error notes and debug from the gateway to see if they provide additional information, 
then contact your merchant service provider and have them verify your account is active/not on credit hold,
and that the gateway has the proper configuration matching your account.  Have the merchant service provider
verify that the platform you are setup on was not having any technical issues.  If this isn't a new merchant 
account or gateway and no recent changes have been made then we'd recommend retrying the transaction in a 
few minutes and see if the error is transient, otherwise you're account has probably been frozen by your
merchant bank. This is definitely not a Zoovy error and unless you are using a BPP recommended merchant service
provider then unfortunately our technical support team will not be able to offer any assistance beyond this 
error message.
~,
	'256'=>q~This is a code returned by the gateway which indicates the process could not be completed due to a problem with a previous state of a transaction. the most common culprits of this problem are trying to capturing against an authorization that was already captured, trying to crediting a transaction that never existed, or trying to void a transaction which has already settled. Very few gateways support this code, so do not assume that just because did not receive a status code #256 that the problem is not one of the ones above.~,
	'257'=>q~The customer should contact their support provider as soon as possible and notify them of the order number and any other relevant information so this may be relayed to Zoovy Developer support. This is a catch all code, which occurs if the Zoovy Payment module cannot determine what happened with the transaction.~,
	'299'=>q~This occurs if the Zoovy account is configured to deny partial or full AVS failures. Either void the transaction, so the Merchant does not get charged for the authorization, AND the customer does not have the order amount removed from their balance, OR capture the order in which case it will be moved to paid.~,
	'300'=>q~3xx series payment codes keep track of credits/refunds to a customer, they indicate to the order that a credit was succssfully processed and that the associated amount should be REMOVED from the balance paid (which subsequently increases the balance due).~,
	'302'=>q~This is the recommended status for any type of manual (offline) refund that is not cash or check~,
	'400'=>q~4xx series are considered 'paid with warnings' usually these are fraud warnings returned by a gateway. They are the same as 0xx payment codes except merchants may want to review any notes on the payment before shipping.
Since 11/7/10 most gateways will now set the Review Status rather than use a 4xx warning code.~,
	'500'=>q~5xx series are reserved for processing / status to be determined - it is an internal status used for when Zoovy has not received a success or failure response from a gateway.~,
	'600'=>q~6xx series payment codes are voids. A 6xx series code can ONLY be applied as a chained payment to a 
0xx or 1xx payment. Any 6xx series payment in a chain will invalidate the entire chain and effective set the amount to zero for
purposes of balance_paid, balance_due, and balance_auth.  Some gateways support void of authorizations, others support void of settle requested and settled
some support void on day after settlement, and others support void only before batch closing on the day of settlement.  Please consult your specific
gateway for more information on how voids are handled.  A void attempt which fails will be given a 2xx series payment code.~,
	'800'=>q~8xx series are consider "adjustments", they can be postitive or negative. They are always created
as a result of user interaction.  Each distinct user interaction has it's own 8xx series code.  These would typically
be considered "journal entries" in quickbooks.  They are most commonly used with the 'ADJUST' tender type.~,
	'900'=>q~
9xx series payment codes indicate a failure in zoovy to ascertain the status of a payment.  
This is effectively a "status unknown" message, verusus a 2xx series which is a "error occurred", or any 
of the other statuses which would be considered a successful authorization (1xx), capture/settlement (0xx or 4xx), 
refund(3xx), or void(6xx).  ~,	
	#'300'=>q~In most cases this means that the payment status was moved to cancelled by an unknown source, usually an External Client via the WebAPI.~,
	#'301'=>q~In this case it means the order was cancelled by the customer. The Merchant should manually verify the funds were credited back to the customer to avoid a chargeback.~,
	#'302'=>q~This means that this order was flagged as cancelled by the merchant using the online Order Management tools.~,
	);

sub webdoc_review_status {
	my $out = '';
	foreach my $rs (sort keys %ZPAY::REVIEW_STATUS) {
		$out .= "<tr><td>$rs</td><td>$ZPAY::REVIEW_STATUS{$rs}</td></tr>";
		}
	$out = qq~
<h2>Review Status</h2>
<table>
<tr><td><b>CODE</b></td><td><b>MEANING</b></td></tr>
$out
</table>~;
	return($out);
	}

## 
sub webdoc_payment_status {
	my $out = '';
	foreach my $ps (sort keys %ZPAY::PAYMENT_STATUS) {
		my $txt = $ZPAY::PAYMENT_STATUS{$ps};
		if ($ZPAY::PAYMENT_STATUS_HELPER{$ps}) { $txt .= "<div class=\"wiki_caution\">$ZPAY::PAYMENT_STATUS_HELPER{$ps}</div>"; }
		$out .= "<tr><td valign=top>$ps</td><td valign=top>$txt</td></tr>";
		}
	$out = qq~
<h2>Payment Status</h2>
<table>
<tr><td><b>CODE</b></td><td><b>MEANING</b></td></tr>
$out
</table>~;
	return($out);
	}


##
## payment status short description 
##
sub payment_status_short_desc {
	my ($ps) = @_;
	my $pc = '';
	if ($ps eq '195') { $pc = 'PAYMENT REQUIRED'; }
	elsif (substr($ps,0,1) eq '0') { $pc = 'PAID'; }
	elsif (substr($ps,0,1) eq '1') { $pc = 'PENDING'; }
	elsif (substr($ps,0,1) eq '2') { $pc = 'DENIED'; }
	elsif (substr($ps,0,1) eq '3') { $pc = 'CANCELLED'; }
	elsif (substr($ps,0,1) eq '4') { $pc = 'REVIEW'; }
	elsif (substr($ps,0,1) eq '5') { $pc = 'PROCESSING'; }
	elsif (substr($ps,0,1) eq '6') { $pc = 'VOIDED'; }
	elsif (substr($ps,0,1) eq '9') { $pc = 'ERROR'; }
	return($pc);
	}


#%ZPAY::PAYMENT_NAMES = (
#
#	'GOOGLE'					=> 'Google Checkout',
#	'CREDIT'             => 'Credit Card',
#	'ECHECK'             => 'Electronic Check',
#	'PAYPAL'             => 'PayPal online payment system',
#	'PAYPALEC'				=> 'PayPal Express Checkout',
#	'COD'                => 'Cashier Check or Money Order on Delivery',
#	'PICKUP'             => 'NO DELIVERY - Customer will Pay at Pickup',
#	'CHKOD'              => 'Company or Personal Check on Delivery',
#	'CASH'               => 'Cash Point of Sale',
#	'MO'     	         => 'Money Order or Cashiers Check',
#	'GIFTCARD'				=> 'Giftcard',
#	'PO'                 => 'Purchase Order',
#	'CHECK'              => 'Company or Personal Check Pre-Payment via Mail',
#	'WIRE'               => 'Wire Transfer',
##	'BIDPAY'             => 'Western Union Bidpay',
#	'CUSTOM'             => 'Custom Payment Type',
#	'ZERO'               => 'Zero-dollar order (no payment)', ## See comment on ZERO below.
#
#	## These indented ones, I don't think they belong here actually,
#	## They aren't methods so much as processors.  But I don't want to
#	## be the one to take them out, so I'm keeping them in for now. -AK
#	'VERISIGN'           => 'Credit Card',
#	'SKIPJACK'           => 'Credit Card',
#	'CARDSERVICE'        => 'Credit Card',
#	'AUTHORIZENET'       => 'Credit Card',
##		'TC'                 => 'Credit Card',
#	'ECHO'               => 'Credit Card',
#	'QBMS'					=> 'Credit Card',
#	'PAYPALWP'				=> 'Credit Card',
#	'PAYPALVT'				=> 'Credit Card',
#	'AMZSPAY',				=> 'Amazon Payments',
#	);

@ZPAY::PAY_METHODS = (
	['CREDIT','Credit Card'],
	['ECHECK','Electronic Check'],
	['PAYPALEC','PayPal Express Checkout'],
#	['PAYPAL','PayPal online payment system'],
	['GOOGLE','Google Checkout'],
	['GIFTCARD','Giftcard'],
	['LAYAWAY','Customer will call with Credit Card # or pay online'],
	['REWARDS','Rewards points'],
	['MONOPOLY','Monopoly Money'],
	['ADJUST','Supervisor Adjustment'],
	['CHKOD','Company or Personal Check on Delivery'],
	['CASH','Cash Payment'],
	['MO','Money Order or Cashiers Check by Mail'],
	['PICKUP','NO DELIVERY - Customer will Pay at Pickup'],
	['CHECK','Company or Personal Check Pre-Payment via Mail'],
	['WIRE','Wire Transfer'],
#	'PAYDIRECT',
#	'BIDPAY',
#	['AMZSPAY','Amazon Payments'],	## doesn't work!
	['CUSTOM','Custom Payment Type'],
	['COD','Cashier Check or Money Order on Delivery'],
	['ZERO', 'Zero-dollar order (no payment)' ],

	## wholesale payment methods:
	['PO','Purchase Order'],
#	['NET-10', 'Payment Terms: Net 10' ],
#	['NET-15', 'Payment Terms: Net 15' ],
#	['NET-30', 'Payment Terms: Net 30' ],
#	['NET-60', 'Payment Terms: Net 60' ],

	## SEARS
	## BUY
	## AMAZON
	## AMZCBA
	## DOBA
	## HSN

		## Don't ever let a merchant select ZERO as a payment method, it is
		## selected automatically if an order is $0 and there is no webdb attribute
		## of 'disable_zero_paymethod'

#			## These indented ones, I don't think they belong here actually,
#			## They aren't methods so much as processors.  But I don't want to
#			## be the one to take them out, so I'm keeping them in for now. -AK
#			'VERISIGN',
#			'SKIPJACK',
#			'CARDSERVICE',
#			'AUTHORIZENET',
##			'TC',
#			'ECHO',
#			'PAYPALWP',
#			'QBMS',
);




##
## insert_payment_into_wallet
##
## this is a robust function which takes "what you know" and stores it, optional parameters give a high degree
##	of functionality.
##
## in %options the following are optional
##		*C =>	 reference to customer object
##		CID => scalar of customer id
##		IS_FAILED => true if this is being stored as a result of a failed payment attempt (different retention policy)
##		
sub insert_payment_into_wallet {
	my ($CART2, $paymentref, %options) = @_;

	require CUSTOMER;
	
	if ($paymentref->{'WI'}) {
		## this already has a wallet id
		warn "called insert_payment_into_wallet without checking to see if we were using a wallet to being with\n";
		return($paymentref->{'WI'});
		}

	my $WALLETID = 0;
	my $CID = 0;	# this will be the customer's cid (on success)
	my $C = undef;	# this will be the customer record (on success)
	if ((defined $options{'*C'}) && (ref($options{'*C'}) eq 'CUSTOMER')) {
		## did we get passed a customer object (if so, lets use that)
		$C = $options{'*C'};
		$CID = $C->cid();
		}
	if ((defined $options{'CID'}) && (int($options{'CID'})>0)) {
		## we got passed a CID in %options (but we didn't get customer object)
		$CID = $options{'CID'};
		($C) = CUSTOMER->new($CART2->username(),PRT=>$CART2->prt(),CID=>$options{'CID'});
		}

	if (($CID<=0) && (defined $CART2) && (ref($CART2) eq 'CART2')) {
		## last chance, maybe CID is set in the order.
		($CID) = $CART2->in_get('customer/cid');
		if ($CID<=0) { 
			## no customer id set in the order, lets do a last chance lookup
			($CID) = CUSTOMER::resolve_customer_id($CART2->username(),$CART2->prt(),$CART2->in_get('bill/email'));
			if ($CID>0) {
				## woot, lets save the customer id for next time!
				$CART2->in_set('customer/cid',$CID);	
				}
			}
		if ($CID>0) { 
			($C) = CUSTOMER->new($CART2->username(),PRT=>$CART2->prt(),CID=>$CID); 
			}
		}

	## SANITY: a this point $CID is *NOT* set, we couldn't resolve it, so lets just create a new one
	my ($was_created) = 0;
	if ((not defined $C) || (ref($C) ne 'CUSTOMER') || ($CID<=0)) {
		($C) = CUSTOMER->new($CART2->username(),'PRT'=>$CART2->prt(),'CREATE'=>2,'*CART2'=>$CART2,'EMAIL'=>$CART2->in_get('bill/email'));		
		if ((defined $C) && (ref($C) eq 'CUSTOMER')) { 
			($CID) = $C->cid(); 
			$was_created++;
			$CART2->in_set('customer/cid',$CID);
			} 
		else { 
			$C = undef; 
			}
		}

	## SANITY: at this point either $CID and $C are set, or we got problems!
	if (($CID>0) && (ref($C) eq 'CUSTOMER')) {
		my ($EXPIRES_GMT) = 0;
		if ($options{'IS_FAILED'}) { $EXPIRES_GMT = time()+(86400*14); }
		$paymentref->{'IP'} = $CART2->in_get('cart/ip_address');
		($WALLETID,my $ERROR) = $C->wallet_store($paymentref,$EXPIRES_GMT);	
		if ($ERROR) {
			$CART2->add_history("CustomerID:$CID received ERROR[$ERROR] when trying to store wallet");
			}
		elsif ($was_created) {
			$CART2->add_history("CustomerID:$CID was created and linked to wallet:$WALLETID");
			}
		else {
			$CART2->add_history("CustomerID:$CID was linked to wallet:$WALLETID");
			}
		}

	return($WALLETID);
	}




##
## finds the appropriate row of $result
##
sub lookup_method {
	my ($METHOD) = @_;

	my $result = undef;
	foreach my $ref (@ZPAY::PAY_METHODS) {
		next if (defined $result);
		if ($ref->[0] eq $METHOD) { $result = $ref; }
		}
	return($result);
	}

%ZPAY::cc_names = (
	'AMEX'  => 'American Express',
	'VISA'  => 'Visa',
	'MC'    => 'MasterCard',
	'NOVUS' => 'Discover',
);

if (%ZPAY::cc_names) {};




##
## options:
##		country
##		ordertotal
##		webdb
##		prt
##		admin=>1 | user is admin (e.g. calling from editor)
##
## returns:
##		 { id=>$method, pretty=>$pretty, fee=>$fee };
sub payment_methods {
	my ($USERNAME, %options) = @_;

	my %DESTINATIONBITS = (
		'NONE'=>0,
		'DOMESTIC'=>1,
		'ALL51'=>3,
		'INT_HIGH'=>1+2+4+8,
		'INT_LOW'=>1+2+4,
		);

	my %ALLOWED_METHODS = ();

	my $country = (defined $options{'country'})?$options{'country'}:'';

	my $ISO = undef;
	my $IS_LOW_RISK = undef;

	if ($country eq '') {
		$ISO = '';
		}
	elsif (length($country)==2) {
		$ISO = $country;
		my ($info) = &ZSHIP::resolve_country('ISO'=>$ISO);
		if (not defined $info) {
			$ISO = undef;
			}
		else {
			$IS_LOW_RISK = $info->{'SAFE'};
			}
		}
	elsif (length($country)>2) {
		## convert long country name to a two digit country code
		$country = &ZSHIP::correct_country($country);
		my ($info) = &ZSHIP::resolve_country('ZOOVY'=>$country);
		if (defined $info) {
			$ISO = $info->{'ISO'};
			$IS_LOW_RISK = &ZSHIP::is_low_risk($country);
			}
		}

	## NOTE: ordertotal should be the total *AFTER* giftcards.
	my $ordertotal = (defined $options{'ordertotal'})?sprintf("%.2f",$options{'ordertotal'}):1;

	my $has_giftcards = 0;
	# my $IS_PAYPAL_EC = 0;

	my $C = undef;
	my $CART2 = undef;
	if ((defined $options{'cart2'}) && (ref($options{'cart2'}) eq 'CART2')) {
		$CART2 = $options{'cart2'};

		($C) = $CART2->customer();
		if ((not defined $C) || (ref($C) ne 'CUSTOMER')) { $C = undef; }
		elsif ($C->cid()<=0) { $C = undef; }	## not authenticated

		if (not defined $C) {
			}
		elsif ($CART2->in_get('is/wholesale')) {
		   my $wsinfo = $C->fetch_attrib('WS');
		   if ($wsinfo->{'ALLOW_PO'}) {
				# $payby{'PO'} = 'Purchase Order (Established Terms)'; 
				$ALLOWED_METHODS{'PO'} = 1;
				}
		
			if ($wsinfo->{'RESALE'}) {
				$CART2->in_set('customer/tax_id',$wsinfo->{'RESALE_PERMIT'});
				}
			}

		#if ($CART2->is_order()) {
		#	## we don't use PAYPALEC exclusive mode when it's already an order (in fact we probably shouldn't show PAYPALEC at all)
		#	}
		#elsif ($CART2->in_get('will/payby') eq 'PAYPALEC') {
		#	## paypal express payment, once that is selected, nothing else can be.
		#	$IS_PAYPAL_EC = 1;
		#	}
		#elsif (scalar(@{$CART2->paymentQshow('TN'=>'PAYPALEC')})>0) {
		#	$IS_PAYPAL_EC = 1;
		#	}

		$has_giftcards = $CART2->has_giftcards();
		}

	## we received *C
	if ((not defined $C) && (defined $options{'*C'})) {
		$C = $options{'*C'};
		}
			

	my $webdbref = $options{'webdb'};
	if (not defined $webdbref) { $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME, $options{'prt'}); }
	if ($webdbref->{'cc_processor'} eq '') { 
		$webdbref->{'cc_processor'} = 'NONE'; 
		}

	if ($webdbref->{'paypal_api_env'}>0) {
		$webdbref->{'pay_paypalec'} = 0xFF;
		}

	## SANITY: at this point $webdbref is assumed to have been initialized

	my $is_secure = 0;
	$is_secure++;
	if ($is_secure) {
		}
	elsif ($ENV{'HTTP_X_SSL_CIPHER'} ne '') { 
		# secure.domain.com ssl certificate
		$is_secure = 1; 	
      # 'HTTP_X_SSL_CIPHER' => 'AES128-SHA              SSLv3 Kx=RSA      Au=RSA  Enc=AES(128)  Mac=SHA1',
      # 'HTTP_X_SSL_CIPHER' => 'AES256-SHA              SSLv3 Kx=RSA      Au=RSA  Enc=AES(256)  Mac=SHA1',
      # 'HTTP_X_SSL_CIPHER' => 'RC4-MD5                 SSLv3 Kx=RSA      Au=RSA  Enc=RC4(128)  Mac=MD5',
		if ($ENV{'HTTP_X_SSL_CIPHER'} =~ /Enc\=(DEC|AES|RC4|RC5)\([\d]+\)/) {
			my $size = int($1);
			if (($size>0) && ($size<80)) { $is_secure = 0; }
			}
		}
	elsif (defined $ENV{'SSL_PROTOCOL'}) {
		# ssl.zoovy.com !?
		$is_secure = 1;
#		if ($ENV{'SSL_PROTOCOL'} eq 'SSLv2') { $is_secure = 0; }
#		elsif ($ENV{'SSL_PROTOCOL'} eq 'SSLv1') { $is_secure = 0; }
#		## SSL_PROTOCOL 	string 	The SSL protocol version (SSLv3, TLSv1, TLSv1.1, TLSv1.2)
#		elsif ($ENV{'SSL_PROTOCOL'} eq 'SSLv3') { $is_secure = 1; }
#		elsif ($ENV{'SSL_PROTOCOL'} eq 'TLSv1') { $is_secure = 1; }
#		elsif ($ENV{'SSL_PROTOCOL'} eq 'TLSv1.1') { $is_secure = 1; }
#		elsif ($ENV{'SSL_PROTOCOL'} eq 'TLSv1.2') { $is_secure = 1; }
#		## TLSv1.1, TLSv1.2 are secure right now.
#		elsif ($ENV{'SSL_CIPHER_USEKEYSIZE'} eq '') { }	# unknown behavior.
#		elsif ($ENV{'SSL_CIPHER_USEKEYSIZE'} < 80) { $is_secure = 0; }
		}
	elsif (($options{'trust_me_im_secure'}) && (&ZOOVY::servername() eq 'dev')) {
		$is_secure++;
		}


	# print STDERR "ORDER_TOTAL: $ordertotal IS:$is_secure COUNTRY:$country\n";

	my @RESULTS = ();
	if (
		($ordertotal <= 0) && 
		(defined $options{'cart'}) && 
		(ref($options{'cart2'}) eq 'CART2') && 
		($options{'cart2'}->has_giftcards()) 
		) {
		## print STDERR "HAS GIFTCARD\n";
		push @RESULTS, { id=>'ZERO', pretty=>"Zero-dollar order (no payment)", fee=>0 };
		}
	#elsif ($IS_PAYPAL_EC) {
	#	## once a user selects PAYPALEC for a cart, that's the only way you can pay.
	#	## print STDERR "ISPAYPAL\n";
	#	push @RESULTS, { id=>'PAYPALEC', pretty=>"Paypal Express Checkout", fee=>0 };
	#	}
	elsif ((defined($ordertotal)) && ($ordertotal == 0) && (not &ZTOOLKIT::def($webdbref->{'disable_zero_paymethod'}))) {
		## print STDERR "IS ZERO\n";
		push @RESULTS, { id=>'ZERO', pretty=>"Zero-dollar order (no payment)", fee=>0 };
    	}
  	else {

		#SSLv3
		#EXP-EDH-RSA-DES-CBC-SHA Kx=DH(512) Au=RSA Enc=DES(40) Mac=SHA1 export
		#EXP-DES-CBC-SHA Kx=RSA(512) Au=RSA Enc=DES(40) Mac=SHA1 export
		#EXP-RC2-CBC-MD5 Kx=RSA(512) Au=RSA Enc=RC2(40) Mac=MD5 export
		#EXP-RC4-MD5 Kx=RSA(512) Au=RSA Enc=RC4(40) Mac=MD5 export
		#TLSv1
		#EXP-EDH-RSA-DES-CBC-SHA Kx=DH(512) Au=RSA Enc=DES(40) Mac=SHA1 export
		#EXP-DES-CBC-SHA Kx=RSA(512) Au=RSA Enc=DES(40) Mac=SHA1 export
		#EXP-RC2-CBC-MD5 Kx=RSA(512) Au=RSA Enc=RC2(40) Mac=MD5 export
		#EXP-RC4-MD5 Kx=RSA(512) Au=RSA Enc=RC4(40) Mac=MD5 export  

		foreach my $pmref (@ZPAY::PAY_METHODS) {
			my ($method,$pretty) = @{$pmref};

			my $IS_ALLOWED = undef;

			if ((not defined $method) || ($method eq '')) { $IS_ALLOWED = -1; }

			## only show giftcard option to CRM subscribers
			if ($method eq 'GIFTCARD') { $IS_ALLOWED = -2; }

			if ($options{'admin'}) {
				if ($method eq 'CASH') { $IS_ALLOWED = 128; }
				if ($method eq 'MO') { $IS_ALLOWED = 128; }
				if ($method eq 'LAYAWAY') { $IS_ALLOWED = 128; }
				if ($method eq 'PICKUP') { $IS_ALLOWED = 128; }
				if ($method eq 'ADJUST') { $IS_ALLOWED = 128; }
				}


			## SSLv2 Countermeasure			
			if ((not $is_secure) && ($method eq 'CREDIT')) { $IS_ALLOWED = -3; }

			## Giftcards aren't compatible with ANY form of paypal payment.
			if (($method eq 'PAYPALEC') && ($has_giftcards)) { $IS_ALLOWED = -5; }

			## admin (merchants) can't use paypal ec since it's a customer initiated action.
			if (($method eq 'PAYPALEC') && (defined $options{'admin'}) && ($options{'admin'}>0)) { $IS_ALLOWED = -6; }

			## don't show PAYPAL when PAYPALEC was already displayed.
			if (($method eq 'PAYPAL') && ($ALLOWED_METHODS{'PAYPALEC'})) { 
				$IS_ALLOWED = -10; 
				}
			
			if ((not defined $IS_ALLOWED) && ($ALLOWED_METHODS{$method})) { $IS_ALLOWED = 128; }
			## Don't show regular PAYPAL when we've got a giftcard in the cart.
		
			# This code is based on the assumption that the pay indicator field (such as pay_paypal) uses the same
			# exact text [in lowercase] as the payment code for that field (i.e.PAYPAL)
			# look for pay_xxxx where xxx is a payment type.

			# print STDERR "$method -- $IS_ALLOWED\n";
			if (not defined $IS_ALLOWED) {
				my $fieldname = 'pay_'.lc($method);
				# if ($fieldname eq 'pay_paypalec') { $fieldname = 'pay_paypal'; }
				if (not defined($webdbref->{$fieldname})) { $webdbref->{$fieldname} = 0; }
				$DEBUG && &msg("\$webdbref->{$fieldname} = '$webdbref->{$fieldname}'");

				# Basically we need to figure out if this is an acceptable payment method.
				if (($fieldname eq 'pay_credit') && ($webdbref->{'cc_processor'} eq 'NONE')) {
					$webdbref->{$fieldname} = 0;
					}
				elsif (defined $DESTINATIONBITS{$webdbref->{$fieldname}}) {
					## translate the old NONE, DOMESTIC, ALL51, INT_HIGH, INT_LOW to bit values
					$webdbref->{$fieldname} = $DESTINATIONBITS{$webdbref->{$fieldname}};
					}
				elsif ($webdbref->{$fieldname} eq 'NO') { 
					$webdbref->{$fieldname} = 0; 
					}
				$webdbref->{$fieldname} = int($webdbref->{$fieldname});
	
				# print STDERR "METHOD: $method $IS_ALLOWED [$ISO] =$webdbref->{$fieldname}\n";
				if (($webdbref->{$fieldname} & 1) && ( ($ISO eq '') || ($ISO eq 'US') ) )                          
					{ $IS_ALLOWED = 1; }
				elsif (($webdbref->{$fieldname} & 2)    && ( ($ISO eq 'US') || ($ISO eq 'CA') )) 
					{ $IS_ALLOWED = 2; }
				elsif (($webdbref->{$fieldname} & 8))                                                   
					{ $IS_ALLOWED = 8; }
				elsif (($webdbref->{$fieldname} & 4)  && $IS_LOW_RISK )                                  
					{ $IS_ALLOWED = 4; }
				else { $IS_ALLOWED = 0; }
				}

			my $fee = 0;
		
			if (not defined $IS_ALLOWED) {
				warn "IS_ALLOWED is set to undef for method: $method";
				}
			elsif ($IS_ALLOWED<=0) {
				## it's not allowed, so we can pretty much skip this.
				}
			elsif ( $method eq 'MO' || $method eq 'CASH' || $method eq 'WIRE' || $method eq 'COD' || $method eq 'CHKOD' || $method eq 'CHECK') {
				my $field = 'pay_'.lc($method).'_fee';
				$fee = defined($webdbref->{$field}) ? $webdbref->{$field} : 0 ;
				} 
			elsif ($method eq 'PAYPALEC') {
				$pretty = 'PayPal - Express Checkout',
				}
			elsif ($method eq 'AMZSPAY') {
				$pretty = 'Amazon Payments';
				}
			elsif ($method eq 'GIFTCARD') {
				## eventually we should check for cached flags here!
				$pretty = 'Giftcard';
				}
			elsif ($method eq 'CREDIT') {
				## NOTE: VISA CISP compliance requires we do not accept credit cards over a SSLv2 session.
				if (not $is_secure) {
					$method = ''; 
					$fee = 0;
					$pretty = undef;
					open F, sprintf(">>%s/sslv2.log",&ZOOVY::tmpfs());
					print F $ENV{'REMOTE_ADDR'}."\n"; 
					close F; 
					}
				elsif ($method ne '') {
					my @names = ();
					foreach (&ZPAY::cc_merchant_types($USERNAME, $webdbref)) { 
						push @names, $ZPAY::cc_names{$_}; 
						}
					my $cc_desc = join('/', @names);
					$pretty = "Credit Card ($cc_desc)";
					}
				}
			elsif ($method eq 'CUSTOM') {
				$pretty = defined($webdbref->{'pay_custom_desc'}) ? $webdbref->{'pay_custom_desc'} : '' ;
				}
			elsif ($pretty eq '') {
				$pretty = $method;
				}

			if ((not defined $pretty) || ($pretty eq '')) {
				warn "Unknown pretty description for method: $method\n";
				$pretty = "$method";
				}

			if ($fee) {
				my ($fee, $pretty) = &ZOOVY::calc_modifier($ordertotal, $fee, 0);
				$pretty .= " (Additional $pretty will apply)";
				}

			if ($IS_ALLOWED>0) {		
				if (not defined $ALLOWED_METHODS{$method}) {  
					## method added implicitly. (gives memory for PAYPAL vs PAYPALEC)
					$ALLOWED_METHODS{$method} = 64;
					}
				push @RESULTS, { id=>$method, pretty=>"$pretty", fee=>$fee, is_allowed=>$IS_ALLOWED, allowed_reason=>$ALLOWED_METHODS{$method} };
				}
			
			}
    	}


	if ((defined $C) && (ref($C) eq 'CUSTOMER')) {
		## WALLETS
		foreach my $payref (@{$C->wallet_list()}) {
			my $pretty = $payref->{'TD'}.
				($options{'admin'}?sprintf(" attempts:%d failures:%d",$payref->{'##'},$payref->{'#!'}):'').
				($payref->{'IS_DEFAULT'}?' [PREFERRED]':'');
			
			unshift @RESULTS, { 
				id=>sprintf("WALLET:%d",$payref->{'WI'}), 
				pretty=>$pretty,
				, fee=>0 
				};
			}

		## GIFTCARDS
		foreach my $gcref (@{$C->giftcards()}) {
			## first - don't add/show giftcards which are already in the cart		
			next if ((defined $CART2) && ($CART2->has_giftcard($gcref->{'CODE'})));

			$gcref->{'OBCODE'} = &GIFTCARD::obfuscateCode($gcref->{'CODE'},$options{'OBFUSCATE'});
			my $pretty = '';
			if (not $options{'admin'}) { 
				$pretty = "Giftcard "; 
				}
			$pretty .= sprintf("%s %s; balance:\$%0.2f;",
				&GIFTCARD::obfuscateCode($gcref->{'CODE'},2), ($gcref->{'NOTE'}?"Note: $gcref->{'NOTE'}":'Note: not set'),$gcref->{'BALANCE'}, 
				);
			if ($options{'admin'}) {
				$pretty .= sprintf(" used#:%s; combinable:%s cash:%s",
	 				$gcref->{'TXNCNT'}, 
					($gcref->{'COMBINABLE'}?'Y':'N'),
					($gcref->{'CASHEQUIV'}?'Y':'N')
					);
				}
			if ($gcref->{'EXPIRES_GMT'}>0) {
				$pretty .= sprintf(" expires:%s",&ZTOOLKIT::pretty_date($gcref->{'EXPIRES_GMT'}));
				}
			$gcref->{'PRETTY'} = $pretty;

			unshift @RESULTS, {
				id=>sprintf("GIFTCARD:%s",$gcref->{'CODE'}),
				pretty=>$gcref->{'PRETTY'}, # Dumper($gcref), fee=>0,
				};	
			}
		}


	$DEBUG && &msg('payment methods fetched');
	return \@RESULTS;	
	}




########################################
# FETCH PAYMENT METHODS
# Purpose: Finds all of all the payment methods the merchan accepts for the country
#          in question and loads them into a hash with their descriptions.
# Accepts: merchant_id, country
# Returns: a hash keyed with all of the acceptable payment types for that country,
#          with values of those payment type's descriptions
sub fetch_payment_methods {
	my ($USERNAME, $country, $ordertotal, $webdbref) = @_;
	my ($payref) = &ZPAY::payment_methods($USERNAME, country=>$country, ordertotal=>$ordertotal, webdb=>$webdbref);

	my %result = ();
	foreach my $ref (@{$payref}) {
		$result{ $ref->{'id'} } = $ref->{'pretty'};
		}

	&ZOOVY::confess($USERNAME,"accessed deprecated method: ZPAY::fetch_payment_methods");
		
	return(%result);
	}


########################################
# PAYMENT METHODS ARRAY
# Purpose: Finds all of all the payment methods the merchan accepts for the
#          country in question
# Accepts: merchant_id, country
# Returns: an array of payment methods
sub payment_methods_array {
	my ($USERNAME, $country, $ordertotal, $webdbref, $cart) = @_;

	my ($payref) = &ZPAY::payment_methods($USERNAME, cart=>$cart, country=>$country, ordertotal=>$ordertotal, webdb=>$webdbref);

#	use Data::Dumper;
#	print STDERR Dumper($payref);

	&ZOOVY::carp($USERNAME,"accessed deprecated method: ZPAY::payment_methods_array");

	my @methods = ();
	foreach my $ref (@{$payref}) {
		push @methods, $ref->{'id'};
		}
	
	return @methods;
	}



########################################
# CC VERIFY EXPIRATION
# Purpose: Makes sure that the credit card month and year aren't expired
# Accepts: Credit card expiration  year and month
# Returns: 1 if the expiration is good, 0 if it isn't
sub cc_verify_expiration {
 	$DEBUG && &msg('Verifying credit card expiration.');
	my ($card_exp_month, $card_exp_year) = @_;

	# print STDERR "MO:$card_exp_month YY:$card_exp_year\n";
	if (($card_exp_month < 0) || ($card_exp_month>12)) { return(0); }
	$card_exp_month = sprintf("%02d",$card_exp_month);

	if (($card_exp_year !~ m/^\d\d$/) || ($card_exp_month !~ m/^\d\d$/)) { return 0; }
	my @now = localtime(time);
	if (
		(($card_exp_year + 2000) < ($now[5] + 1900)) ||
		((($card_exp_year + 2000) == ($now[5] + 1900)) && (($card_exp_month + 0) < ($now[4] + 1)))
	)
	{
		return 0;
	}
	return 1;
}


########################################
# CC VERIFY CHECKSUM
# Purpose: Anthony's super-duper tiny credit card checksum validator
# Accepts: Credit card number
# Returns: true if the checksum is valid, false if it isn't 
sub cc_verify_checksum
{
 	$DEBUG && &msg('Verifying credit card checksum.');
	my ($card) = @_;
	$card =~ s/\D//;
	my $total = 0;
	my $count = 0;
	my @evens = (0, 2, 4, 6, 8, 1, 3, 5, 7, 9);
	foreach my $num (split(//, reverse($card))) {
		$total += ($count % 2) ? $evens[$num] : $num;
		$count++;
	}
	return not(($total % 10) + 0);
}

# Some of Anthony's cute code...
# sub cc{$x=0;$t=0;for(split//,reverse pop){/\D/?$x--:($t+=$x%2?(0,2,4,6,8,1,3,5,7,9)[$_]:$_);$x++}$t%10}
# Doesn't trounce global variables, doesn't use $_, even strips non-numbers and checks for all-zeroes (which is valid mod 10)...
# The %w hash trick was just for effect, its actually smaller and more efficient using the straight array below.
# Except for the spacing and variable naming, totally conforming to zoovy specs
# sub cc_verify_checksum_tiny{my%w=(0..9);my$t=0;my$x=0;for$n(split//,reverse pop){$n=~/\D/?$x--:($t+=$x%2?(sort(keys%w),sort(values%w))[$n]:$n);$x++}($t&&!($t%10))+0}
# sub cc_verify_checksum_tiny{my$t=0;my$x=0;for$n(split//,reverse pop){$n=~/\D/?$x--:($t+=$x%2?(k,k(1))[$n]:$n);$x++}($t&&!($t%10))+0}sub k{%w=(0..9);sort(pop?keys%w:values%w)}

########################################
# VERIFY CREDIT CARD
# Purpose: High level function for card validation
# Accepts: credit card number, expiration month, expiration year
# Returns: an empty string if completely successful, or a strin with a description of the problem it it failed

sub verify_credit_card
{
	$DEBUG && &msg('Verifying credit card in general');
	my ($CARD_NUM, $EXP_MO, $EXP_YR, $CVVCID) = @_;

	if (not defined $CARD_NUM) { $CARD_NUM = ''; }
	if (not defined $EXP_MO) { $EXP_MO = ''; }
	if (not defined $EXP_YR) { $EXP_YR = ''; }
	if (not defined $CVVCID) { $CVVCID = ''; }

	if (length($EXP_YR)==4) {	
		## CHANGE 4 DIGIT YEAR TO LAST 2 DIGITS
		$EXP_YR = substr($EXP_YR,2,2);
		}

	# make sure we've just got the card num.
	$CARD_NUM =~ s/\D+//g;

	my $result = "";
	if (
		(not &ZPAY::cc_verify_checksum($CARD_NUM)) ||
		(not &ZPAY::cc_verify_length($CARD_NUM))
	)
	{
		$result = 'Credit card number must be a valid credit card number.';
	}
 	if (not &ZPAY::cc_verify_expiration($EXP_MO, $EXP_YR))
	{
		$result = 'Credit card has expired.';
	}
	if ($CVVCID)
	{
		if (not &ZPAY::cc_verify_cvvcid($CARD_NUM, $CVVCID))
		{
			$result = 'If a CID or CVV number is provided, it must be valid.';
		}   
	}
	return($result);
}

########################################
# CC VERIFY LENGTH
# Purpose: Makes sure the card is the right length for the type
# Accepts: Credit card number
# Returns: 1 if the card length is valid, 0 if it isn't
sub cc_verify_length
{
 	$DEBUG && &msg('Verifying credit card length.');
	my ($card_number) = @_;
	if (not defined $card_number) { $card_number = ''; }
	my $card_type = &cc_type_from_number($card_number);
	my $len = length($card_number);
	if (
		(($card_type eq 'VISA')  && ($len == 13)) ||
		(($card_type eq 'VISA')  && ($len == 16)) ||
		(($card_type eq 'MC')    && ($len == 16)) ||
		(($card_type eq 'NOVUS') && ($len == 16)) ||
		(($card_type eq 'AMEX')  && ($len == 15))
	)
	{
		return 1;
	}
	return 0;
}

########################################
# CC VERIFY CIDCVV
# Purpose: Sees if the CID or CVV provided is right for the type of card
# Accepts: Credit card number and CID/CVV number
# Returns: 1 if the CID/CVV matches the format needed by the card number, 0 if it doesn't
sub cc_verify_cvvcid {
 	$DEBUG && &msg('Verifying credit card CVV or CID.');
	my ($card_number, $card_cvvcid) = @_;
	if (not defined $card_number) { $card_number = ''; }
	if (not defined $card_cvvcid) { $card_cvvcid = ''; }
	my $card_type = &cc_type_from_number($card_number);
	if (
		(($card_type eq 'AMEX')  && ($card_cvvcid !~ m/^\d\d\d\d$/)) ||
		(($card_type eq 'VISA')  && ($card_cvvcid !~ m/^\d\d\d$/))   ||
		(($card_type eq 'MC')    && ($card_cvvcid !~ m/^\d\d\d$/))   ||
		(($card_type eq 'NOVUS') && ($card_cvvcid !~ m/^\d\d\d$/))
		# Don't know the format for a discover card CVV/CID
		)	{
		return 0;
		}
	return 1;
	}

########################################
# CC VERIFY TYPE FOR MERCHANT
# Purpose: Looks to see if the credit card type is accepted by the merchant
# Accepts: Merchant_id, Credit card number
# Returns: 1 if the credit card is a type the merchant accepts, 0 if it isn't
sub cc_verify_type_for_merchant {
 	$DEBUG && &msg('Verifying credit card against merchant type.');
	my ($USERNAME, $card_number, $webdbref) = @_;
	if (not defined $card_number) { $card_number = ''; }
	my $card_type = &cc_type_from_number($card_number);
	foreach my $paymethod (&cc_merchant_types($USERNAME,$webdbref)) {
		($card_type eq $paymethod) && return 1;
		}
	return 0;
	}

########################################
# CC MERCHANT TYPES
# Purpose: Finds all the credit card types the merchant accepts
# Accepts: Merchant_id
# Returns: An array of the card types the merchant accepts
sub cc_merchant_types {
	my ($USERNAME, $webdbref) = @_;
 	$DEBUG && &msg('Gathering merchant credit car types accepted.');
	if (not defined $webdbref) {
		$webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME);
		}
	# my $paymethods = defined($webdbref->{'cc_types'}) ? $webdbref->{'cc_types'} : '' ;
	# return split (/\,/, $paymethods);
	my @METHODS = ();
	foreach my $type ('visa','mc','novus','amex') {
		if ($webdbref->{sprintf("cc_type_%s",$type)}) {
			push @METHODS, uc($type); 
			}
		}
	return(@METHODS);
	}

########################################
# CC MERCHANT TYPES DESC
# Purpose: Finds all the credit card types the merchant accepts and returns the types in a format suitable for display
# Accepts: Merchant_id
# Returns: An string of the pretty names of the accepted types with slashes between
#sub cc_merchant_types_desc {
#	my ($USERNAME) = @_;
#	my @names = ();
#	foreach (&cc_merchant_types($USERNAME)) { push @names, $ZPAY::cc_names{$_}; }
#	return join('/', @names);
#	}


########################################
# CC TYPE FROM NUMBER
# Purpose: Finds out the credit card type from the credit card number
# Accepts: Credit card number
# Returns: The credit card type code of the card
sub cc_type_from_number {
	my ($card_number) = @_;
	if (not defined $card_number) { $card_number = ''; }
 	$DEBUG && &msg('Ascertaining the credit card type based on its number.');
	my $card_type = '';
	if    ($card_number =~ m/^3[47].*$/)    { $card_type = 'AMEX';  }
	elsif ($card_number =~ m/^4.*$/)        { $card_type = 'VISA';  }
	elsif ($card_number =~ m/^5[12345].*$/) { $card_type = 'MC';    }
	elsif ($card_number =~ m/^6011.*$/)     { $card_type = 'NOVUS'; }
	return $card_type;	
	}

########################################
# CC HIDE NUMBER
# Purpose: Returns a safe-to-show version of a card number
# Accepts: Credit card number
# Returns: The XXXX-XXXX-XXXX-1234 version of the card number
sub cc_hide_number {
	my ($card) = @_;
	if (not defined $card) { $card = ''; }
	my $len = length($card);
	if    ($len == 15) { $card = 'XXXX-XXXXXX-'    . substr($card, $len-5, 5); } ## Amex
	elsif ($len == 16) { $card = 'XXXX-XXXX-XXXX-' . substr($card, $len-4, 4); } ## MC/Discover/Most Visa
	else               { $card = 'X' x ($len-4)    . substr($card, $len-4, 4); } ## Some visa are 13 digits, etc.
	return $card;
	}

##############################################################################
# MISCELLANEOUS FUNCTIONS

########################################
# RESULT_LOG
# Purpose: Dumps the hash passed to it into the file /tmp/ORDER_ID.results if $results_debug is true)
# Accepts: An order id and a reference to a hash with the results of the transaction attempted
# Returns: Nothing

sub result_log {
	require ZTOOLKIT;
	require ZOOVY;
	if ($results_debug && $ZOOVY::SHAREDTEMP) {
		my ($USERNAME, $OID, $hashref, $processor) = @_;
	#	my $filename = ">$ZOOVY::SHAREDTEMP/$USERNAME" . "_$OID" . "_$processor" . '_' . time . '.results';
	#	open RESULTS, $filename;
	#	print RESULTS &ZTOOLKIT::dumpvar($hashref, '%results');
	#	close RESULTS;
	}
}

########################################
# MSG
# Purpose: Prints an error message to STDERR (the apache log file)
# Accepts: An error message as a string, or a reference to a variable (if a reference,
#		  the name of the variable must be the next item in the list, in the format
#		  that Data::Dumper wants it in).  For example:
#		  &msg("This house is ON FIRE!!!");
#		  &msg(\$foo=>'*foo');
#		  &msg(\%foo=>'*foo');
# Returns: Nothing

sub msg {
	my $head = 'ZPAY: ';
	while ($_ = shift(@_)) {
		if (ref) { require Data::Dumper; $_ = Data::Dumper->Dump([$_],[shift(@_)]); }
#		print STDERR $head, join("\n$head",split(/\n/,$_)), "\n";
	}
}

# Test card numbers:
#  Visa: 4111111111111111
#  Visa: 4242424242424242
#  MC:   5105105105105100
#  Disc: 6011111111111117
#  AmEx: 378282246310005

# Will pass validation, but don't know if they will be valid on the test server
#  Visa: 4222222222222
#  Visa: 4444444444444448
#  Visa: 4444444411111111
#  MC:   5555555555555557
#  MC:   5555555533333333
#  Disc: 6011701170117011
#  Disc: 6011621162116211
#  Disc: 6011608860886088
#  Disc: 6011333333333333
#  Amex: 370370370370370
#  Amex: 377777777777770
#  Amex: 343434343434343
#  Amex: 341111111111111
#  Amex: 341341341341341
#  None: 8888888888888888

1;
