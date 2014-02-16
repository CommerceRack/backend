package ZPAY::GOOGLE;

use YAML::Syck;
$YAML::Syck::ImplicitBinary++;
$YAML::Syck::ImplicitUnicode++;
$YAML::Syck::SingleQuote++;		# do not fucking enable this. it has issues with cr/lf 183535

use Clone;

#
# 
# known bugs in the perl SDK:
#	Google/Checkout/General/ShippingRestrictions.pm  country 'UK' should be 'GB' around line 179 part of 'EU_COUNTRIES'
#
#
#
#
#
#
# DEBUG LINE:
#perl -e 'use lib "/backend/lib"; use ORDER; my ($O2) = ORDER->new("pnt","2008-07-29357"); 
#my ($c) = $O2->as_cart(); print Dumper($c); print Dumper($c->stuff()->count(1)); use Data::Dumper; 
#use ZPAY::GOOGLE; print Dumper(&ZPAY::GOOGLE::getCheckoutURL($c));'
#
#
#
#
#
#

#
# Just a clarification -
# My understanding is that you should be using your sandbox merchant acct ID: 624918436474245 right now. 
# But you are right about your production merchant ID being 116786571323704 -- this ID is to be used when you 
# launch and the transactions conducted using this ID are considered "official"
#
# - Gaurav
#

#
# 624918436474245 
# username: zoovyinc@gmail.com
# pw: labslave
#

use Data::Dumper;
use strict;
use Google::Checkout::General::GCO;
use Google::Checkout::General::MerchantItem;
use Google::Checkout::General::ShoppingCart;
use Google::Checkout::XML::CheckoutXmlWriter;
use Google::Checkout::General::MerchantCheckoutFlow;
use Google::Checkout::General::AddressFilters;
use Google::Checkout::General::AddressFilters;
use Google::Checkout::General::Pickup;
use Google::Checkout::General::FlatRateShipping;
use Google::Checkout::General::MerchantCalculatedShipping;
use Google::Checkout::General::TaxRule;
use Google::Checkout::General::TaxTable;
use Google::Checkout::General::TaxTableAreas;
use Google::Checkout::General::MerchantCalculations;
use Google::Checkout::General::ParameterizedUrl;
use Google::Checkout::General::Error;

use Google::Checkout::XML::Constants;
use Google::Checkout::General::Util qw/is_gco_error/;
use Text::CSV_XS;

use lib "/backend/lib";
require ZWEBSITE;
require LUSER;
require ZPAY;
require CART2;


$::PLATFORMID = '116786571323704';

##
## ISSUE #1 - user configurable wrappers + existing work. + POST ugh! don't have control over form.
## 		#2 - what about displaying required UPS messaging?
##			#2 - tax advice.
##			#3 - bonding
##			#4 - in example4.pl there is an "analytics_data"
##

# SANDBOX - Account information
# https://sandbox.google.com/checkout/cws/v2/Merchant/[[MERCHANTID]]/checkout
# Google merchant ID: 624918436474245
# Google merchant key: G6Ikabn9ExYYV2KHugpZvw

# PRODUCTION - 
# Merchant ID: 116786571323704

## BUTTONS:
# LARGE: https://checkout.google.com/buttons/checkout.gif?merchant_id=624918436474245&w=180&h=46&style=&variant=text&loc=en_US
# MED: https://checkout.google.com/buttons/checkout.gif?merchant_id=624918436474245&w=168&h=44&style=&variant=text&loc=en_US
# SMALL: https://checkout.google.com/buttons/checkout.gif?merchant_id=624918436474245&w=160&h=43&style=&variant=text&loc=en_US
## style= can be either white or trans
## variant= can be disabled or text


sub new {
	my ($class,$USERNAME,$webdbref) = @_;
	my $self = {}; 
	$self->{'USERNAME'} = $USERNAME;
	$self->{'%webdb'} = $webdbref;
	bless $self, 'ZPAY::GOOGLE'; 
	return($self);
	}

sub webdb { return($_[0]->{'%webdb'}); }


########################################
# AUTHORIZENET AUTHORIZE
#sub authorize { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('AUTHORIZE',$O2,$payrec,$payment)); }
#sub charge { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CHARGE',$O2,$payrec,$payment)); }


#--
#-- Create a cancel order command. Note that a reason is required.
#--    run this on a 
#--
sub void { 
	my ($self, $O2, $payrec, $payment) = @_; 

	require Google::Checkout::Command::CancelOrder;

	my $USERNAME = $O2->username();
	my ($webdbref) = $self->webdb();
	my ($gco) = buildGCO($USERNAME,$webdbref,0);

	if (not defined $gco) {
		warn("cannot cancel order because gco for $USERNAME not defined");
		return(undef);
		}

	my $AMT = $payrec->{'amt'};
	if (defined $payment->{'amt'}) { $AMT = $payment->{'amt'}; }

	my $NOTE = $payment->{'note'};
	if ((not defined $NOTE) || ($NOTE eq '')) { $NOTE = $payrec->{'note'}; }
	if ((not defined $NOTE) || ($NOTE eq '')) { $NOTE = 'Refunded Order'; }

	my $GOOGLE_ORDERID = $payrec->{'txn'};
	my $cancel_order = Google::Checkout::Command::CancelOrder->new(
                   order_number => $GOOGLE_ORDERID,
                   amount       => $AMT,
                   reason       => $NOTE);
	my $run_diagnose = 0;
	my $response = $gco->command($cancel_order, $run_diagnose);
	if (not  is_gco_error($response)) {
		$O2->add_history(sprintf("GC did CancelOrder Total:%.2f Response:%s",
			$O2->in_get('sum/order_total'), $response
			),etype=>1+2+4,luser=>'*google');
		($payrec) = $O2->add_payment('GOOGLE',$AMT,
			'r'=>$response,
			'note'=>"Refund Pending (waiting for Google)",
			'ps'=>'512',
			'puuid'=>$payrec->{'uuid'});
		}
	else {
		print STDERR "RESPONSE: $response\n";
		$O2->add_history(sprintf("GC said CancelOrder ERROR: %s",$response),etype=>1+2+4+8,luser=>'*google');
		}
	return($payrec);
	}

##
##
##
sub credit { 
	my ($self, $O2, $payrec, $payment) = @_; 

	require Google::Checkout::Command::RefundOrder;
	my $USERNAME = $O2->username();
	my ($webdbref) = $self->webdb();
	my ($gco) = buildGCO($USERNAME,$webdbref,0);

	if (not defined $gco) {
		warn("cannot cancel order because gco for $USERNAME not defined");
		return(undef);
		}

	my $AMT = $payrec->{'amt'};
	if (defined $payment->{'amt'}) { $AMT = $payment->{'amt'}; }

	my $NOTE = $payment->{'note'};
	if ((not defined $NOTE) || ($NOTE eq '')) { $NOTE = $payrec->{'note'}; }
	if ((not defined $NOTE) || ($NOTE eq '')) { $NOTE = 'Refunded Order'; }

	my $GOOGLE_ORDERID = $payrec->{'txn'};
	my $cancel_order = Google::Checkout::Command::RefundOrder->new(
                   order_number => $GOOGLE_ORDERID,
                   amount       => $AMT,
                   reason       => $NOTE);
	my $run_diagnose = 0;
	my $response = $gco->command($cancel_order, $run_diagnose);
	if (not is_gco_error($response)) {
		$O2->add_history(sprintf("GC did RefundOrder Total:%.2f Response:%s",
			$O2->in_get('sum/order_total'), $response
			),etype=>1+2+4,luser=>'*google');
		($payrec) = $O2->add_payment('GOOGLE',$AMT,
			'r'=>$response,
			'note'=>"Refund Pending (waiting for Google)",
			'ps'=>'512',
			'puuid'=>$payrec->{'uuid'});
		}
	else {
		print STDERR "RESPONSE: $response\n";
		my $errmsg = 'Unknown';
		if ($response =~ /<error-message>(.*?)<\/error-message>/) { $errmsg = $1; }
		($payrec) = $O2->add_payment('GOOGLE',$AMT,'r'=>$response,'note'=>$errmsg,'ps'=>'911','puuid'=>$payrec->{'uuid'});
		$O2->add_history(sprintf("GC said RefundOrder ERROR: %s",$response),etype=>1+2+4+8,luser=>'*google');
		}

	$O2->order_save();
	return($payrec);
	} 

#############################################
#--
#-- Send the charge order command.
#--
sub capture { 
	my ($self, $O2, $payrec, $payment) = @_; 

	require Google::Checkout::Command::ChargeOrder;

	my $USERNAME = $O2->username();
	my ($webdbref) = $self->webdb();
	my ($gco) = buildGCO($USERNAME,$webdbref,0);

	if (not defined $gco) {
		warn("cannot cancel order because gco for $USERNAME not defined");
		return(undef);
		}

	my $AMT = $payrec->{'amt'};
	if (defined $payment->{'amt'}) { $AMT = $payment->{'amt'}; }
	my $GOOGLE_ORDERID = $payrec->{'txn'};

	my $charge_order = Google::Checkout::Command::ChargeOrder->new(
                   order_number => $GOOGLE_ORDERID,
                   amount       => $AMT,
						);
	my $run_diagnose = 0;
	my $response = $gco->command($charge_order, $run_diagnose);

	# print STDERR "RESPONSE: $response\n";

	if (not is_gco_error($response)) {
		$payrec->{'ps'} = 511;
		$O2->add_history(sprintf("GC did ChargeOrder Total:%.2f Response:%s",
			$O2->in_get('sum/order_total'), $response
			),etype=>1+2+4,luser=>'*google');
		}
	else {
		my $errmsg = 'Unknown';
		if ($response =~ /<error-message>(.*?)<\/error-message>/) { $errmsg = $1; }
		($payrec) = $O2->add_payment('GOOGLE',$AMT,'r'=>$response,'note'=>$errmsg,'ps'=>'911','puuid'=>$payrec->{'uuid'});
		$O2->add_history(sprintf("GC said ChargeOrder ERROR: %s",$response),etype=>1+2+4+8,luser=>'*google');
		}

	return($payrec);
	}



##sub credit {
#	return(900,"Please process credits directly on google.com");
#	}
#
#sub void {
#	return(900,"Please process voids directly on google.com");
#	}




#############################################################


sub button_html {
	my ($CART2,$SREF) = @_;

	my $USERNAME = $CART2->username();
	my $webdbref = $SREF->webdb();

	## MORE INFO: http://code.google.com/apis/checkout/developer/index.html#google_checkout_buttons

	## NOTE: we should *ALWAYS* make sure session rewriting is on before redirecting to the secure_url.. how bizarre.
	$SREF->URLENGINE()->set(sessions=>1);	

	my $gmid = $webdbref->{'google_merchantid'};
	my $cartid = $CART2->username()."!".$CART2->uuid();
	my $googlecheckout_url = $SREF->URLENGINE()->get('googlecheckout_url');
	# my ($protocol) = ($SITE::SREF->{'+secure'})?'https':'http';

	my $variant = 'text';
	## $variant = 'disable';  ## means this the button is grey/clickable

	if (ref($CART2) eq 'CART2') {
		## look for disabled items via the product attribute gc:blocked==1
		## if true, then we set $variant='disabled' 
		my ($stuff2) = $CART2->stuff2();
		if (ref($stuff2) eq 'STUFF2') {
			foreach my $item (@{$stuff2->items()}) {
				next if (ref($item->{'%attribs'}) ne 'HASH');
				next if (not defined $item->{'%attribs'}->{'gc:blocked'});
				if ($item->{'%attribs'}->{'gc:blocked'}==1) { $variant = 'disabled'; }
				elsif ($item->{'mkt'} eq 'EBAY') { $variant = 'disabled'; }
				}
			}
		}


	my $style = 'white';
	if ($webdbref->{'google_api_buttonstyle'}) {
		## possible values: white, trans -- set via client override until we get it into the interface.
		$style = $webdbref->{'google_api_buttonstyle'};
		}

	my $html = '';
	if ($variant eq 'disabled') {
		## Disabled Google Checkout button
		$html .= qq~<img height=43 width=160 border=0 src="https://checkout.google.com/buttons/checkout.gif?merchant_id=$gmid&w=160&h=43&style=$style&variant=$variant&loc=en_US"></a>~;
		}
#	elsif ($webdbref->{'google_api_analytics'}) {
#		## YES - GOOGLE ANALYTICS
#		$html = qq~
#<script src="$protocol://checkout.google.com/files/digital/urchin_post.js" type="text/javascript"></script>
#<a href="javascript:document.location='$googlecheckout_url?analyticsdata='+getUrchinFieldValue();">
#<img height=43 width=160 border=0 src="https://checkout.google.com/buttons/checkout.gif?merchant_id=$gmid&w=160&h=43&style=$style&variant=$variant&loc=en_US"></a>~;
#		}
	elsif ($webdbref->{'google_api_analytics'}==1) {
		## YES - GOOGLE ANALYTICS NON-ASYNC (PAGETRACKER)
		# $html = qq~<script src="$protocol://checkout.google.com/files/digital/ga_post.js" type="text/javascript"></script>
		$html = qq~<a href="javascript:setUrchinInputCode(pageTracker); document.location='$googlecheckout_url?analyticsdata='+getUrchinFieldValue();">
<img height=43 width=160 border=0 src="https://checkout.google.com/buttons/checkout.gif?merchant_id=$gmid&w=160&h=43&style=$style&variant=$variant&loc=en_US"></a>~;
		}
	elsif ($webdbref->{'google_api_analytics'}==2) {
		## YES - GOOGLE ANALYTICS ASYNC (GAQ)
		$html = qq~<a href="javascript:_gaq.push(function() {var pageTracker = _gaq._getAsyncTracker();setUrchinInputCode(pageTracker);}); document.location='$googlecheckout_url?analyticsdata='+getUrchinFieldValue();">
<img height=43 width=160 border=0 src="https://checkout.google.com/buttons/checkout.gif?merchant_id=$gmid&w=160&h=43&style=$style&variant=$variant&loc=en_US"></a>~;
		}
	else {
		## NO - GOOGLE ANALYTICS
		$html = qq~<a href="$googlecheckout_url"><img height=43 width=160 border=0 src="https://checkout.google.com/buttons/checkout.gif?merchant_id=$gmid&w=160&h=43&style=$style&variant=$variant&loc=en_US"></a>~;
		}

	return($html);	
	}




##
## refundOrder - run this on a CHARGED order
##
sub refundOrder {
	my ($O2) = @_;

	return($O2);
	}



#sub chargeOrder {
#	my ($self,$O2,$payrec) = @_;	return();
#	}


##############################################
#--
#-- Send the archive order command.
#--
#--	not exactly sure *WHY* but this seems useful!
#--
sub archiveOrder {
	my ($O2,$payrec,$save) = @_;

	if (not defined $save) { $save++; }
	my $USERNAME = $O2->username();

	my $TS = time();
	my ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$O2->prt());
	my ($gco) = buildGCO($USERNAME,$webdbref,0);

	if (not defined $gco) {
		warn("cannot cancel order because gco for $USERNAME not defined");
		return(undef);
		}

	my $google_orderid = &ZPAY::GOOGLE::getGoogleOID($O2,$payrec);
	if ($google_orderid eq '') {
		warn "received a payrec that did not contain GO field in acct";
		}


	require Google::Checkout::Command::ArchiveOrder;
	my $process_order = Google::Checkout::Command::ArchiveOrder->new(
                   order_number => $google_orderid, # 767650915669533
						);
	my $run_diagnose = 0;
	my $response = $gco->command($process_order, $run_diagnose);


	if (not is_gco_error($response)) {
		## SUCCESS!
		$O2->add_history(sprintf("GC was sent archiveOrder"),ts=>$TS,etype=>16,luser=>'*google');
		$O2->in_set('flow/google_archived_ts',$TS);
		}
	else {
		## FAILURE!
		$O2->add_history(sprintf("GC said archiveOrder ERROR: %s",$response),ts=>$TS,etype=>16+32,luser=>'*google');		
		}
	if ($save) { $O2->order_save(); }
	return();
	}



##############################################
#--
#-- Send the "UNARCHIVE" order command.
#--
#--	not exactly sure *WHY* but this seems useful!
#--
sub unarchiveOrder {
	my ($O2,$payrec,$save) = @_;

	if (not defined $save) { $save++; }
	my $USERNAME = $O2->username();

	my $TS = time();
	my ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$O2->prt());
	my ($gco) = buildGCO($USERNAME,$webdbref,0);

	if (not defined $gco) {
		warn("cannot cancel order because gco for $USERNAME not defined");
		return(undef);
		}

	my $google_orderid = &ZPAY::GOOGLE::getGoogleOID($O2,$payrec);
	if ($google_orderid eq '') {
		warn "received a payrec that did not contain GO field in acct";
		}

	require Google::Checkout::Command::UnarchiveOrder;
	my $process_order = Google::Checkout::Command::UnarchiveOrder->new(
                   order_number => $google_orderid, # 767650915669533
						);
	my $run_diagnose = 0;
	my $response = $gco->command($process_order, $run_diagnose);

	if (not is_gco_error($response)) {
		## SUCCESS!
		$O2->add_history(sprintf("GC was sent UnarchiveOrder"),ts=>$TS,etype=>16,luser=>'*google');
		$O2->in_set('flow/google_archived_ts',undef);
		}
	else {
		## FAILURE!
		$O2->add_history(sprintf("GC said UnarchiveOrder ERROR: %s",$response),ts=>$TS,etype=>16+32,luser=>'*google');		
		}
	if ($save) { $O2->order_save(); }
	return();
	}




##
##
##
sub getGoogleOID {
	my ($O2,$payrec) = @_;

	my $google_orderid = undef;
	my $acctref = &ZPAY::unpackit($payrec->{'acct'});
	($google_orderid) = $acctref->{'GO'};
	if ($acctref->{'GO'} eq '') {
		## legacy mode orderv4 mode
		$google_orderid = $O2->in_get('mkt/google_orderid');
		}
	return($google_orderid);
	}




##############################################
#--
#-- Send the process order command.
#--
#-- notifies the buyer that have received this order and we are processing it.
#--
sub processOrder {
	my ($O2,$payrec,$save) = @_;

	if (not defined $save) { $save++; }
	my $USERNAME = $O2->username();

	my $TS = time();
	my ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$O2->prt());
	my ($gco) = buildGCO($USERNAME,$webdbref,0);

	if (not defined $gco) {
		warn("cannot cancel order because gco for $USERNAME not defined");
		return(undef);
		}

	my $google_orderid = &ZPAY::GOOGLE::getGoogleOID($O2,$payrec);
	if ($google_orderid eq '') {
		warn "received a payrec that did not contain GO field in acct";
		}


	require Google::Checkout::Command::ProcessOrder;
	my $process_order = Google::Checkout::Command::ProcessOrder->new(
                   order_number => $google_orderid, # 767650915669533
						);
	my $run_diagnose = 0;
	my $response = $gco->command($process_order, $run_diagnose);

	if (not is_gco_error($response)) {
		## SUCCESS!
		$O2->add_history(sprintf("GC was sent processOrder"),ts=>$TS,etype=>16,luser=>'*google');
		$O2->in_set('flow/google_processed_ts',$TS);
		}
	else {
		## FAILURE!
		$O2->add_history(sprintf("GC said processOrder ERROR: %s",$response),ts=>$TS,etype=>16+32,luser=>'*google');		
		}

	if ($save) { $O2->order_save(); }
	return();
	}


##############################################
#--
#-- Create a deliver order command. Note that we
#-- specify email should also be sent to the user.
#--
#-- set_tracking_number TRACKING_NUMBER
#--
sub deliverOrder {
	my ($O2, $payrec, $trackrec) = @_;

	my $USERNAME = $O2->username();
	my ($gco) = &ZPAY::GOOGLE::buildGCO($USERNAME,$O2->webdb(),0);

	my $RESULT = undef;

	if (not defined $gco) {
		$RESULT = "cannot upload tracking due to gco for $USERNAME not defined";
		}
	elsif (not defined $payrec) {
		$RESULT = "received undefined payrec";
		}
	elsif ($payrec->{'acct'} eq '') {
		$RESULT = "received a payrec without acct defined (cannot process)";
		}
	elsif ($payrec->{'tender'} ne 'GOOGLE') {
		$RESULT = "is only compatible with GOOGLE tender payrec";
		}

	my $google_orderid = &ZPAY::GOOGLE::getGoogleOID($O2,$payrec);
	if ($google_orderid eq '') {
		$RESULT = "received a payrec that did not contain GO field in acct";
		}
	
	my ($CARRIER,$TRACKING) = (undef,undef);
	if (not defined $RESULT) {
		$CARRIER = $trackrec->{'carrier'};
		$TRACKING = $trackrec->{'track'};
		if ($CARRIER eq '') {
			$RESULT = " carrier could not be found in trackrec";
			}
	   $CARRIER = uc(sprintf("%s",$CARRIER));

		## this does a quick lookup and coverts FXSP (fedex smart post) to simply FDX (generic Fedex)
		if ((defined $ZSHIP::SHIPCODES{$CARRIER}) && (defined $ZSHIP::SHIPCODES{$CARRIER}->{'carrrier'})) {
			$CARRIER = $ZSHIP::SHIPCODES{$CARRIER}->{'carrier'};
			}

		if (($CARRIER eq 'FEDX') || ($CARRIER eq 'FEDEX') || ($CARRIER eq 'FDX') || ($CARRIER eq 'FDXG')) { $CARRIER = 'FedEx'; }
		elsif ($CARRIER eq 'UPS') {}
		elsif ($CARRIER eq 'USPS') {}
		else {
			$CARRIER = 'Other';
			}
		}

	if (defined $RESULT) {
		$O2->add_history("ZPAY::GOOGLE::deliverOrder $RESULT");
		}
	else {
		require Google::Checkout::Command::DeliverOrder;
		my $deliver_order = Google::Checkout::Command::DeliverOrder->new(
                    order_number => $google_orderid,
                    send_email   => 0);

 		# Carrier: Invalid Argument Errors
		# The value of the carrier tag in your request is not valid. Valid values for the carrier tag are DHL, FedEx, UPS, USPS and Other.
		# DHL, FedEx, UPS, USPS and Other
		## hmm.. sometimes CARRIER is throwing a weird error
		$deliver_order->set_carrier($CARRIER);
		if ($TRACKING ne '') {
			$deliver_order->set_tracking_number($TRACKING);
			}
	
		my $run_diagnose = 0;
		my $response = $gco->command($deliver_order, $run_diagnose);

		if (is_gco_error($response)) {
			## WE GOT AN ERROR RESPONSE
			$O2->add_history(sprintf("GC got ERROR DeliverOrder Notification carrier=[%s] track=[%s] response=[%s]",
				$CARRIER,$TRACKING, $response
				), etype=>16+32, luser=>'*google');
			}
		else {
			$O2->add_history(sprintf("GC did DeliverOrder Notification carrier=[%s] track=[%s]",
				$CARRIER,$TRACKING
				), etype=>16, luser=>'*google');
			}
		}

	return();
	}


##############################################
##
#
# sub sendTracking {
#
#   my ($o) = @_;
#   my $gco = Google::Checkout::General::GCO->new(config_path => $config_path);
#   --
#   -- Create a add trcking data command
#   --
#   my $add_tracking = Google::Checkout::Command::AddTrackingData->new(
#                   order_number    => 566858445838220,
#                   carrier         => Google::Checkout::XML::Constants::DHL,
#                   tracking_number => 5678);
#   my $response = $gco->command($add_tracking, $run_diagnose);
#   die $response if is_gco_error($response);
#
#   print $response,"\n\n";
#
#   }
#
##



##
## takes in a base64 cart, and decodes it.
##
sub decodeCart {
	my ($data,$USERNAME) = @_;

	## NOTE: CARTS are sent to google and decoded here!
	require Storable;
	require Compress::Bzip2;
	require MIME::Base64;

	## decode Base64
	my $reason = undef;
	my $serialized = MIME::Base64::decode($data);
	if ($serialized eq '') { $reason = "Could not base64 decode cart data\n"; }

	## print Dumper($serialized);

	my $CART2 = undef;
	if ($serialized =~ /^\-\-\- /) {
		## use YAML::Encoding
		$CART2 = YAML::Syck::Load($serialized);
		}
	else {
		## decompress Bzip2
		$serialized = Compress::Bzip2::decompress($serialized);
		if ($serialized eq '') { $reason = "Could not decompress cart data\n"; }
		## dethaw into memory
		$CART2 = eval { Storable::thaw($serialized) };
		if ($serialized eq '') { $reason = "Could not thaw cart data\n"; }
		}

	if ((defined $CART2) && ($CART2->{'id'} eq '*')) {
		## COMPATIBILITY FOR OLD CARTS
		$CART2 = undef;
		}
	elsif (defined $CART2) {
		bless $CART2, 'CART2';
		bless $CART2->{'*stuff2'}, 'STUFF2';

		my $USERNAME = $CART2->username();
		my $CARTID = $CART2->cartid();

		if (not defined $USERNAME) { warn "Could not interpret USERNAME"; }

		if (not defined $CART2) {
			warn 'Could not deserialize google encoded cart, trying to load from disk!';
			($CART2) = CART2->new_persist($USERNAME,$CART2->prt(),$CARTID);
			}
		}
	elsif ($data =~ /\|eCrater\.com/) {
		## stupid user uses ecrater.	
		$reason = undef;
		$CART2 = CART2->new_memory($USERNAME);
		$CART2->in_set("want/order_notes","This order was created by a payment notification from eCrater.com\n");		
		}
	elsif (defined $reason) {
		}
	else {
		$reason = "unknown reason";
		die();
		}

	if (defined $reason) {
		## could not decode the cart
		&ZOOVY::confess($USERNAME,"Google Checkout could not decode cart\nREASON:$reason\n\nDATA:\n$data",justkidding=>1);
		}

	return($CART2);
	}



##
## A google checkout object
##		includes merchant credentials!
##
sub buildGCO {
	my ($USERNAME,$webdbref,$checkout) = @_;

	if ($USERNAME eq '') {
		warn "Attempting to buildGCO with blank username!";
		my $gco = Google::Checkout::General::GCO->new(
                merchant_id  => '',
                merchant_key => '',
                gco_server   => '' );
		return($gco);	
		}

	if (not defined $webdbref) {
		warn("webdbref not set.");
		$webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,0);
		}

	my $api_env = $webdbref->{'google_api_env'};	# 0 = disable, 1 = sandbox, 2 = prod
	if ($api_env==0) { 
		warn "requested buildGCO for $USERNAME but api_env was [$api_env]";
		return(undef); 
		}

	my $server = undef;

#
# Old URL format:
# /cws/v2/Merchant/<merchant id>/<command>
#
# Example of old URL (prod):
# https://checkout.google.com/cws/v2/Merchant/1234567890/request
# https://checkout.google.com/cws/v2/Merchant/1234567890/checkout
#
# Example of old URL (sandbox):
# https://sandbox.google.com/checkout/cws/v2/Merchant/1234567890/request
# https://sandbox.google.com/checkout/cws/v2/Merchant/1234567890/checkout
#
#
# New URL format:
# /api/checkout/v2/<command>/Merchant/<merchant id>
#
# Example of new URL (production):
# Commands: https://checkout.google.com/api/checkout/v2/request/Merchant/1234567890
# Cart Post: https://checkout.google.com /api/checkout/v2/checkout/Merchant/1234567890
#
# Example of new URL (Sandbox)
# Commands: https://sandbox.google.com/checkout/api/checkout/v2/request/Merchant/1234567890
# Cart Post: https://sandbox.google.com /checkout/api/checkout/v2/checkout/Merchant/1234567890
#

	if ($checkout) {
		## CHECKOUT SERVERS HAVE A DIFFERENT URL
		($server) = ($api_env==1)?
		"https://sandbox.google.com/checkout/cws/v2/Merchant/$webdbref->{'google_merchantid'}/merchantCheckout":
		"https://checkout.google.com/cws/v2/Merchant/$webdbref->{'google_merchantid'}/merchantCheckout";
		}
	else {
		## 
		($server) = ($api_env==1)?
		"https://sandbox.google.com/checkout/cws/v2/Merchant/$webdbref->{'google_merchantid'}/request":
		"https://checkout.google.com/cws/v2/Merchant/$webdbref->{'google_merchantid'}/request";
		}

	#	print STDERR "SERVER: $server\n";

	my $gco = Google::Checkout::General::GCO->new(
                merchant_id  => $webdbref->{'google_merchantid'},
                merchant_key => $webdbref->{'google_key'},
                gco_server   => $server );
 
	return($gco);
	}


#mysql> desc GOOGLE_ORDERS;
#+----------------+------------------+------+-----+---------------------+-------+
#| Field          | Type             | Null | Key | Default             | Extra |
#+----------------+------------------+------+-----+---------------------+-------+
#| ID             | int(11)          | NO   |     | 0                   |       |
#| CREATED        | datetime         | NO   |     | 0000-00-00 00:00:00 |       |
#| USERNAME       | varchar(20)      | NO   |     | NULL                |       |
#| MID            | int(10) unsigned | NO   |     | 0                   |       |
#| GOOGLE_ORDERID | varchar(20)      | NO   | PRI | NULL                |       |
#| OUR_ORDERID  | varchar(20)      | NO   |     | NULL                |       |
#+----------------+------------------+------+-----+---------------------+-------+
#6 rows in set (0.02 sec)
sub resolve_orderid {
	my ($USERNAME,$GOOGLE_ORDERID) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select OUR_ORDERID from GOOGLE_ORDERS where MID=$MID /* $USERNAME */ and GOOGLE_ORDERID=".$udbh->quote($GOOGLE_ORDERID);
	print STDERR $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my ($ORDERID) = $sth->fetchrow();
	$sth->finish();
	&DBINFO::db_user_close();

	return($ORDERID);
	}


##
## 10/7/11 - added deep cloning.
##
## recommended options
##
sub getCheckoutURL {
	my ($CART2,$SITE,%params) = @_;


	## we really should clone the cart.
	$CART2 = Clone::clone($CART2);

	my ($USERNAME) = $CART2->username();
	my ($CARTID) = $CART2->uuid();

	## turn on turbo mode so the cart won't be saved to disk!
	## and make it a temp cart JUST IN CASE!
	$CART2->{'_id'} = $CART2->uuid();

	my $analyticsdata = $params{'analyticsdata'};
	my $webdbref = $CART2->webdb();

	my $gref = $params{'gref'};
	if (not defined $gref) { $gref = &ZWEBSITE::fetch_globalref($USERNAME); }

  	if ((defined $gref->{'inv_police_checkout'}) && ($gref->{'inv_police_checkout'} == 1)) {
      # If there's nothing in the shopping cart, then the cart must have expired.
      if ((defined $gref->{'inv_mode'}) && ($gref->{'inv_mode'} > 1)) {

			my $update = $CART2->check_inventory('*SITE'=>$SITE);	## this is the *SITe dependenecty for this function
			if ((defined $update) && (scalar(@{$update})>0)) {
				return(0,"Sorry, items in your cart are no longer available, please check your shopping cart.");		
				}
			}
		}


	my ($gco) = buildGCO($USERNAME,$webdbref,1);
	if (not defined $gco) {
		warn("cannot cancel order because gco for $USERNAME not defined");
		return(undef);
		}
	
	## Arrgh.. some customer must have bookmarked the /_googlecheckout URL or something?
	if ($CART2->stuff2()->count('show'=>'real')<=0) {
		return(0,"Please add some items to your cart before attempting to pay");
		}

	my $PRT = int($CART2->prt());	

	my $api_env = $webdbref->{'google_api_env'};	# 0 = disable, 1 = sandbox, 2 = prod
	if ($api_env==0) { return(undef); }
	my ($calcurl) = ($api_env==1)?
		"http://webapi.zoovy.com/webapi/google/callback.cgi/v=1/u=$USERNAME/c=$CARTID/prt=$PRT":
		"https://webapi.zoovy.com/webapi/google/callback.cgi/v=1/u=$USERNAME/c=$CARTID/prt=$PRT";

#	if ($api_env==2) {
#		## lets try this alternate calculation url.
#		$calcurl = "https://ebaycheckout.zoovy.com/google-callback.cgi/v=1/u=$USERNAME/c=$CARTID/prt=$PRT";
#		}

#	$calcurl = 'https://ebaycheckout.zoovy.com/blah';
#	print STDERR "CARTID: $CARTID\n";

	my $SDOMAIN = $SITE->sdomain();
	#if (not defined $SDOMAIN) { $SDOMAIN = $USERNAME.'.zoovy.com'; }
	#$CART2->save_property('chkout.sdomain',$SDOMAIN);
	
	if ($CART2->in_get('our/domain')) {
		warn "it's a bad idea to run zpay::google::goooglecheckouturl without our/domain set\n";
		}

	#--
	#-- This example is the same as example 2 except it doesn't actuall
	#-- perform a checkout. Instead, it prints out the XML, signature, 
	#-- etc. This gives the user a chance to manually inspect the XML
	#-- generated. Great for debug! 
	#--
	#--
	#-- We create another tax table with the name 'item'. 
	#-- This is not a default table but we can reference 
	#-- it using it's name
	#--
	my $tax_table = Google::Checkout::General::TaxTable->new(
			default => 1,
			# name => "taxtable",
			standalone => 1,
			merchant_calculated => 0,
			rules => []);	## we'll add rules in a second!

#	if ($webdbref->{'sales_tax'} eq 'off') {
#		## no taxes!
#		}
#	else {
#		my %OTHERTAX = ();
#		## other tax: 1 = SHIPPING, 2 = HANDLING, 4 = INSURANCE, 8 = SPECIAL
#		foreach my $kv (split (',', $webdbref->{'state_tax_other'})) {
#			next unless ((defined $kv) && ($kv ne ''));
#			my ($state, $v) = split ('=', $kv);
#			next unless ((defined $state) && ($state ne ''));
#			$OTHERTAX{ $state } = $v;
#			}
#
	my $csv = Text::CSV_XS->new();
	my $tax_rules = $webdbref->{'tax_rules'};

	if ($CART2->in_get('is/tax_exempt')) {
		## no sense computing tax rules
		$tax_rules = '';
		}
	
	my @STATE_TAX_RULES = ();	# an array of state rules which will need to be added at the end
										# because google applies tax rules in a descending first match order
	my $i = 0;

	foreach my $line (split(/[\n\r]+/,$tax_rules)) {
		next if (($line eq '') || (substr($line,0,1) eq '#'));
		my $status  = $csv->parse($line);       # parse a CSV string into fields
		my ($method,$match,$rate,$apply,$zone) = $csv->fields();           # get the parsed fields

		if ($i>100) {
			warn "Exceeded 100 tax rule limit in Google Checkout";
			}
		next if ($i++ > 100);

		if ($method eq 'state') {
			my $state = $match;
			my $tax_rule = Google::Checkout::General::TaxRule->new(
  			   shipping_tax => ($apply&2)?1:0,
				rate => $rate,
            area => [Google::Checkout::General::TaxTableAreas->new(state => [$state])]
				);
			push @STATE_TAX_RULES, $tax_rule;
			}

		if ($method eq 'zipspan') {
			my ($start,$end) = split(/-/,$match,2);
			my ($state) = &ZSHIP::zip_state($start);
			if ($state eq '') { $state = &ZSHIP::zip_state(sprintf("%05d",$start+1)); }
			if ($state eq '') { $state = &ZSHIP::zip_state(sprintf("%05d",$start-1)); }
			my %taxes = &ZSHIP::getTaxes($CART2->username(),$CART2->prt(),webdb=>$webdbref,zip=>$start,state=>$state);
			my ($rate) = $taxes{'tax_rate'};
			# print STDERR "STATE: $state START: $start RATE: $rate\n";
			my @zips = ();

			foreach my $zip ($start..$end) { 
				push @zips, sprintf("%05d",$zip); 
				}
			## lets see if we can summarize any of those zip codes
			if (1) { 
				## ZIP CODE REDUX: lets see if we can summarize any of those zip codes
				## 92014..92102 becomes: 92024-92029,9203*,9204*,9205*,9206*,9207*,9208*,9209*,92100,92101,92102
				my %tmp = ();
				foreach my $zip (@zips) { $tmp{ "$zip" }++; }
				foreach my $zip (@zips) {
				   ## look for numbers ending in a zero
				   next unless (substr($zip,-1) eq '0');
				   ## we summarize by tens, so drop last digit
				   $zip = substr($zip,0,-1);
				   ## okay make sure we've got a full set of 0-9
				   my $missed = 0;
				   foreach my $i (0..9) {
				      if (not defined $tmp{ "$zip$i" }) { $missed++; }
				      }
				   next if ($missed);
				   ## we've got a full set so add a summary and then remove the set
				   $tmp{"$zip*"}++;
				   foreach my $i (0..9) { delete $tmp{"$zip$i"}; }
				   }

				## apparently google needs one tax rule per zip code if we want it to work!
				foreach my $zipcode (sort keys %tmp) {
					my $tax_rule = Google::Checkout::General::TaxRule->new(
					   shipping_tax => ($apply&2)?1:0,
						rate => $rate,
						area => [Google::Checkout::General::TaxTableAreas->new(zip=>[$zipcode])]
						);
	
					if ($state eq '') { warn "Missing state for zip: $start\n"; }
					else {
						$tax_table->add_tax_rule($tax_rule);
						}
					}

				## woot!
				}

			}		
		}

	## we add state rules at the end, since they are less specific than zip code rules.
	foreach my $tax_rule (@STATE_TAX_RULES) {
		$tax_table->add_tax_rule($tax_rule);
		}


	#--
	#-- Create a custom shipping method with the above 
	#-- shipping restriction for a total of $45.99
	#--
	## cool, we could compute default shipping.
	my $r_domestic = Google::Checkout::General::AddressFilters->new(
		allowed_zip => ["*"],
		allowed_country_area => [Google::Checkout::XML::Constants::FULL_50_STATES],
		allowed_country => ['US'],
		);
	


	

	##
	##
	##
	my @shipping = ();
	my ($zip) = $CART2->in_get('ship/postal');
	if ($zip eq '') { 
		$CART2->in_set('ship/postal', $webdbref->{'google_dest_zip'}); 
		}

	# $CART2->shipping();
	my $handling = 0;

	foreach my $fee ('sum/hnd_total','sum/spc_total','sum/ins_total') {
		$handling += sprintf("%.2f",$CART2->in_get($fee));
		}

	print STDERR "HANDLING: $handling\n";



	foreach my $shipmethod (@{$CART2->shipmethods()}) {
		my $price = sprintf("%.2f",$shipmethod->{'amount'} + $handling);
		my $methodid = sprintf("%s",$shipmethod->{'name'});

		#if ($shipmethod->{'handler'} eq 'FIXED') {
		#	my $method = Google::Checkout::General::FlatRateShipping->new(
      #                price         => $price,
      #                shipping_name => $methodid );
		#	push @shipping, $method;		
		#	}
		if ($webdbref->{'google_api_merchantcalc'}>0) {
			my %options = ();
			$options{'price'} = $price,
			$options{'shipping_name'} = $methodid;
			my $is_local = 0;
			if ($shipmethod->{'name'} eq 'Customer Pickup') { $is_local++; }
			if ($shipmethod->{'carrier'} eq 'CPU') { $is_local++; }
			if (($is_local) && (defined $shipmethod->{'@zips'}) && (scalar($shipmethod->{'@zips'})>0)) {
				## okay, we'll treat this as local
				}
			else {
				$is_local = 0;
				}
			
			if ($is_local) {
				## LOCAL PICKUP
				# $options{'restriction'} = $r_pickup; 
				my $r_pickup = Google::Checkout::General::AddressFilters->new();
				foreach my $rateset (@{$shipmethod->{'@zips'}}) {
					my ($start, $end, $price) = @{$rateset};
					foreach my $zip ($start .. $end) {
						$r_pickup->add_allowed_zip(sprintf("%05d",$zip));
						}
					}
				$options{'address_filters'} = $r_pickup; 
				}
			else {
				# $options{'restriction'} = $r_domestic;
				$options{'address_filters'} = $r_domestic;
				}
			
			my $method = Google::Checkout::General::MerchantCalculatedShipping->new(%options);
			push @shipping, $method;
			}
		else {
			my $method = Google::Checkout::General::FlatRateShipping->new(
                      price         => $price,
                      shipping_name => $methodid );
			push @shipping, $method;		
			}
		}


	#open F, ">/tmp/asdf2";
	#use Data::Dumper; print F Dumper($CART2->shipmethods(),$CART2,\@shipping);
	#close F;

	## INTERNATIONAL SHIPPING
	# @shipping = ();
	# $webdbref->{'google_int_shippolicy'} = 1;
 

#	$r_canada->add_allowed_postal_area(Google::Checkout::XML::Constants::EU_COUNTRIES);
# 	print Dumper($r_canada->get_allowed_postal_area(),Google::Checkout::XML::Constants::EU_COUNTRIES);
	# $r_canada->add_allowed_world_area('true');

	if ($webdbref->{'google_int_shippolicy'} == 0) { }	## no international shipping for GC checkout
	elsif ($webdbref->{'ship_int_risk'} eq 'NONE') { }
	else {
		##
		## royal canadian mounted police recruiting office will be the default address for quotes
		## 7575 - 8 Street NE, Calgary, AB T2E 8A2
		## .. 
		my ($zip) = $CART2->in_get('ship/postal');
		# $CART->save_property('cgi.ship_address1','7575 - 8 Street NE');
		# $CART->save_property('ship.zip', 'T2E 8A2');
		# $CART->save_property('ship.country_code','CA');
		#$CART2->in_set('cgi.zip', 'T2E 8A2');
		#$CART2->in_set('cgi.country','Canada');
		#$CART2->in_set('cgi.state','Calgary');
		$CART2->in_set('ship/region','Calgary');
		$CART2->in_set('ship/country','CA');
		$CART2->in_set('ship/postal','T2E 8A2');
		$CART2->shipmethods('flush'=>1);

		my $r_canada = Google::Checkout::General::AddressFilters->new(id=>'Canada');
		$r_canada->add_allowed_postal_area({ 'country_code'=>'CA' });
		$r_canada->add_excluded_country_area(Google::Checkout::XML::Constants::FULL_50_STATES);
		$r_canada->add_excluded_postal_area({ 'country_code'=>'US' });

		my $handling = 0;
		foreach my $fee ('sum/hnd_total','sum/spc_total','sum/ins_total') {
			$handling += sprintf("%.2f",$CART2->in_get($fee));
			}
		foreach my $shipmethod (@{$CART2->shipmethods()}) {
			my $price = sprintf("%.2f",$shipmethod->{'amount'} + $handling);
			my %options = ();
			$options{'price'} = $price,
			$options{'shipping_name'} = sprintf("Can. %s",$shipmethod->{'name'});
			# $options{'restriction'} = $r_canada;
			$options{'address_filters'} = $r_canada;
			my $method = undef;
			if ($webdbref->{'google_api_merchantcalc'}>0) {
				$method = Google::Checkout::General::MerchantCalculatedShipping->new(%options);
				}
			else {
				$method = Google::Checkout::General::FlatRateShipping->new(%options);
				}			
			push @shipping, $method;
			}

		# print STDERR Dumper(\@shipping);
#		die();
		}


	# @shipping = ();
	if ($webdbref->{'google_int_shippolicy'} == 0) { }	## no international shipping for GC checkout
	elsif ($webdbref->{'ship_int_risk'} eq 'NONE') { }
	elsif ($webdbref->{'ship_int_risk'} eq 'ALL51') { }
	else {
	   my $r_int = Google::Checkout::General::AddressFilters->new(id=>'Int');
		$r_int->add_allowed_postal_area(Google::Checkout::XML::Constants::EU_COUNTRIES);
		$r_int->add_excluded_country_area(Google::Checkout::XML::Constants::FULL_50_STATES);
		$r_int->add_excluded_postal_area({ 'country_code'=>'CA' });
		$r_int->add_excluded_postal_area({ 'country_code'=>'US' });
		$r_int->add_allowed_world_area('true');

		## Buckingham Palace
		## London
		## SW1A 1, United Kingdom
		## +44 20 7766 7300 
		#$CART2->in_set('cgi.zip', 'SW1A 1AA');
		#$CART2->in_set('cgi.country','United Kingdom');
		#$CART2->in_set('cgi.state','UK');
		$CART2->in_set('ship/region','London');
		$CART2->in_set('ship/country','United Kingdom');
		$CART2->in_set('ship/postal','SW1A 1AA');
		$CART2->shipmethods('flush'=>1);

		my $handling = 0;
		foreach my $fee ('sum/hnd_total','sum/spc_total','sum/ins_total') {
			$handling += sprintf("%.2f",$CART2->in_get($fee));
			}

		foreach my $shipmethod (@{$CART2->shipmethods()}) {
			my $price = sprintf("%.2f",$shipmethod->{'amount'} + $handling);
			my %options = ();
			$options{'price'} = $price,
			$options{'shipping_name'} = sprintf("%s Int.",$shipmethod->{'name'});
			# $options{'restriction'} = $r_int;
			$options{'address_filters'} = $r_int;
			my $method = undef;
			if ($webdbref->{'google_api_merchantcalc'}>0) {
				$method = Google::Checkout::General::MerchantCalculatedShipping->new(%options);
				}
			else {
				$method = Google::Checkout::General::FlatRateShipping->new(%options);
				}			
			push @shipping, $method;
			}
		}

#	open F, ">>/tmp/foo";
#	print F Dumper(\@shipping);
#	close F;

#	elsif ($webdbref->{'ship_int_risk'} eq 'SOME') {
#		}
#	elsif ($webdbref->{'ship_int_risk'} eq 'FULL') {
#		}
#	else {
#		## US ONLY!
#		}
	

#	if ($webdbref->{'google_int_shippolicy'} == 1) {
#		my %options = ();
#		$options{'price'} = '1.00',
#		$options{'shipping_name'} = "Canada Shipping";
#			$options{'restriction'} = $r_canada;
#			
#		my $method = Google::Checkout::General::MerchantCalculatedShipping->new(%options);
#		# print Dumper($method);
#		push @shipping, $method;
#		}


	my $stuff2 = $CART2->stuff2();
#	my $shiptotal = 0;
#	foreach my $stid ($stuff->stids()) {
#		next if (not defined $shiptotal);		## if this becomes not defined, then we can't quote shipping.
#		my $i = $stuff->item($stid);
#
#		if ((not defined $i->{'full_product'}->{'zoovy:ship_cost1'}) || 
#			($i->{'full_product'}->{'zoovy:ship_cost1'} eq '')) {
#			$shiptotal = undef;
#			}
#		else {
#			$shiptotal += sprintf("%.2f",$i->{'full_product'}->{'zoovy:ship_cost1'} * $->{'qty'});
#			}
#		}
#
#	my $default_shipping = undef;
#	$shiptotal = undef;
#	if (not defined $shiptotal) {
#		## crap, we could default shipping is to block shipping.
#		my $r_allownone = Google::Checkout::General::AddressFilters->new(
#                           allowed_zip           => ["00000"],
#                           excluded_zip          => ["*"],
#                           excluded_country_area => [Google::Checkout::XML::Constants::FULL_50_STATES]);
#
#		$default_shipping = Google::Checkout::General::MerchantCalculatedShipping->new(
#                      price         => 0,
#                      restriction   => $r_allownone,
#                      shipping_name => "Shipping");
#		}
#	else {
#		## cool, we could compute default shipping.
#		my $r_domestic = Google::Checkout::General::AddressFilters->new(
#						allowed_zip => ["*"],
#                  allowed_state => [Google::Checkout::XML::Constants::FULL_50_STATES]);
#
#		$shiptotal = 3.50;
#
#		$default_shipping = Google::Checkout::General::MerchantCalculatedShipping->new(
#                      price         => $shiptotal,
#                    #  restriction   => $r_domestic,		## NOT NECESSARY
#                      shipping_name => "Shipping");
#		}

	#my $pickup_shipping    = Google::Checkout::General::Pickup->new(shipping_name => "Pickup");
	#my $flat_rate_shipping = Google::Checkout::General::FlatRateShipping->new(
   #                      shipping_name => "Flat rate UPS", 
   #                      price         => 19.99);


	#--
	#-- A merchant calculations object tells Checkout that we want to calculate
	#-- the shipping expense using a custom algorithm. The URL specify
	#-- the address that Checkout should call when it needs to find out the 
	#-- shipping expense. We also specify that users can apply coupons and
	#-- gift certificates to the shipping cost
	#--
	my $merchant_calculation = Google::Checkout::General::MerchantCalculations->new(
                             url => $calcurl,
                             coupons => 0,
                             certificates => 0
									  );
	## NOTE: Google Checkout can't modify the cart once it's been created, so our coupon codes won't work.
	## 		GIFT CERTIFICATES aren't released yet.



	#--
	#-- Add a couple more params
	#--
	#$purls->set_url_param(taxes => 'tax-amount');
	#$purls->set_url_param(shipping => 'shipping-amount');

	#--
	#-- Now it's time to create the checkout flow. 
	#-- Edit cart and continue 
	#-- shopping URL specify 2 addresses: one for editing the cart 
	#-- and another for when the user click the continue shopping link.
	#-- The 2 tax tables (created above) is added and we tell Checkout what 
	#-- we are interested in calculating our own shipping expense with 
	#-- our own calculation. The buyer's phone number is also added
	#--

	my $edit_cart_url = $params{'edit_cart_url'};
	if (not defined $edit_cart_url) {
		$edit_cart_url = "http://$SDOMAIN/c=$CARTID/cart.cgis";
		}
	my $continue_shopping_url = $params{'continue_shopping_url'};
	if (not defined $continue_shopping_url) {
		$continue_shopping_url = "http://$SDOMAIN/c=$CARTID/?mode=finish";
		}

	if (not defined $webdbref->{'google_tax_tables'}) { $webdbref->{'google_tax_tables'} = 0; }

	if ($webdbref->{'google_tax_tables'}>0) {
		if ($CART2->in_get('is/tax_exempt')) {
			## tax exempt orders always get sent to google.
			}
		else {
			$tax_table = undef;
			}
		}


	my $checkout_flow = Google::Checkout::General::MerchantCheckoutFlow->new(
                    shipping_method       => \@shipping,
                    edit_cart_url         => "http://$SDOMAIN/c=$CARTID/cart.cgis",
                    continue_shopping_url => "http://$SDOMAIN/c=$CARTID/?mode=finish",
                    buyer_phone           => 1, # "1-111-111-1111",
                    tax_table             => [ $tax_table ], # [$tax_table1,$$tax_table],
                   # merchant_calculation  => $merchant_calculation,
						  # notification_url      => $calcurl,
						  platform_id => $::PLATFORMID,
						  # analytics_data        => "SW5zZXJ0IDxhbmFseXRpY3MtZGF0YT4gdmFsdWUgaGVyZS4=",
                    # parameterized_url     => $purls
							);

	#--
	#-- Create a parameterized URL object so we can track the order
	#--
	#my $purls = Google::Checkout::General::ParameterizedUrls->new(
   #         url => 'http://www.zoovy.com/webapi/google/tracking?parter=123&amp;partnerName=Company',
   #         url_params => {orderID => 'order-id', totalCost => 'order-total'});

	if ($webdbref->{'google_pixelurls'} ne '') {
		foreach my $line (split(/[\n\r]+/,$webdbref->{'google_pixelurls'})) {
			next if ($line eq '');
			my ($url,$paramsline) = split(/\?/,$line,2);
			my $pref = &ZTOOLKIT::parseparams($paramsline);
			my %url_params = ();
			foreach my $k (keys %{$pref}) {
				## look for key=[value]
				if ($pref->{$k} =~ /^\[(.*)\]$/) {
					$url_params{$k} = $1;
					delete $pref->{$k};
					}
				}
			$url .= '?'.&ZTOOLKIT::buildparams($pref,1);
			my $purls = Google::Checkout::General::ParameterizedUrl->new(
				url=>$url, url_params => \%url_params);
			$checkout_flow->add_parameterized_url($purls);			
			}
		}

	#if ($USERNAME eq 'barefoottess') {
	#	my $purls = Google::Checkout::General::ParameterizedUrl->new(
	#		url => 'https://affiliates.barefoottess.com/addorder.asp',
	#		url_params => {c => 'order-id', a => 'order-subtotal'});
	#	$checkout_flow->add_parameterized_url($purls);
	#	}

#	if ((defined $SITE::SREF->{'%NSREF'}) && (ref($SITE::SREF->{'%NSREF'}) eq 'HASH')) {
		## http://code.google.com/apis/checkout/developer/checkout_pixel_tracking.html
#		my $nsref = $SITE::SREF->{'%NSREF'};
#		
#		}

#	print STDERR "ANALYTICS: $analyticsdata\n";
	if ((defined $analyticsdata) && ($analyticsdata ne '')) {
		$checkout_flow->set_analytics_data($analyticsdata);
		}

	if ($webdbref->{'google_api_merchantcalc'}>0) {
		$checkout_flow->set_merchant_calculation($merchant_calculation);
		}

	# my $private = '';

	#--
	#-- Once the merchant checkout flow is created, we can create the shopping
	#-- cart. The cart includes the checkout flow created above, it will expire
	#-- in 1 month and we include a private message in the cart
	#--

#	require MIME::Base64;
#	require Storable;
#	require Compress::Bzip2;
#	my $serialized = Storable::freeze($CART2);
#	$serialized = Compress::Bzip2::compress($serialized);

	my $CLONE = Storable::dclone($CART2);
	delete $CLONE->{'*SITE'};
	my $serialized = YAML::Syck::Dump($CLONE);
	my $private = MIME::Base64::encode_base64( $serialized );

	my $cart = Google::Checkout::General::ShoppingCart->new(
           expiration    => "+1 month",
           private       => $private,
           checkout_flow => $checkout_flow);

#	use Data::Dumper; 
#	print 'ZZZZZ: '.$cart->get_checkout_flow();

	#--
	#-- Now we create a merchant item.
	#--
	foreach my $item (@{$stuff2->items()}) {

		# print STDERR Dumper($i);
		if ((not defined $item->{'prod_name'}) || ($item->{'prod_name'} eq '')) {
			$item->{'prod_name'} = 'prod_name not set';
			}

		my $prod_name = &ZTOOLKIT::stripUnicode($item->{'prod_name'});
		my $prod_desc = ZTOOLKIT::stripUnicode($item->{'description'});

		my $item = Google::Checkout::General::MerchantItem->new(
           name               => $prod_name,
           description        => $prod_desc,
           price              => $item->{'price'},
           quantity           => $item->{'qty'},
           private            => $item->{'stid'},
           # tax_table_selector => $tax_table->get_name()
			  );

#		print Dumper($item);
#		die();

		#--
		#-- We can the item to the cart
		#--
		$cart->add_item($item);
		}


	my ($bnd_total) = $CART2->in_get('sum/bnd_total');
	if ($bnd_total>0) {
		## Bonding
		my $item = Google::Checkout::General::MerchantItem->new(
			name=>"buySafe Bond",  # $CART->fetch_property('ship.bnd_method'),
			description=> 'Ensure a safe and enjoyable online transaction by looking for the buySAFE Seal.',
			price=> sprintf("%.2f",$bnd_total),
			quantity=> 1,
			private=> '%BOND',
			);
		$cart->add_item($item);
		}		
	

	#--
	#-- Get the signature and XML cart
	#--
	my $data = $gco->get_xml_and_signature($cart);
#	open F, ">/tmp/asdf";
#	print F Dumper($checkout_flow);
#	my $xml = $data->{'raw_xml'};
#	$xml =~ s/></>\n</g;
#	print F Dumper($xml);
#	close F;


	#--
	#-- Print the XML and signature
	#--
	#print STDERR
	#	 "URL:       ",$gco->get_checkout_url,"\n",
   #	"Raw XML:   $data->{raw_xml}\n",
   #   "Key:       $data->{raw_key}\n",
   #   "Signature: $data->{signature}\n",
   #   "XML cart:  $data->{xml}\n";
#

	## NOTE: Google appears to have very long service times.

	my $url = $gco->checkout($cart);
	my $success = (is_gco_error($url))?0:1;

#	# print STDERR Dumper($success,$url);
#   use Data::Dumper;
#   open F, ">/tmp/cubworld.log";
#   print F Dumper($CART,$cart,$success,$url);
#   close F;

	return($success,$url);
#	print 'REDIRECT: '.$gco->checkout($cart);


#	return($data->{xml},$data->{signature},$data->{raw_xml});
	}






1;
