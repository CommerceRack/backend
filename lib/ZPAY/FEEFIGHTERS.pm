package ZPAY::FEEFIGHTERS;

use XML::Writer;

# https://samurai.feefighters.com/developers

sub new { 
	my ($class,$USERNAME,$WEBDB) = @_;	
	my $self = {}; 
	$self->{'%webdb'} = $WEBDB;
	bless $self, 'ZPAY::FEEFIGHTERS'; 
	return($self);
	}
 

use LWP::UserAgent;
use HTTP::Request;

use lib '/backend/lib';
require ZPAY;
require ZWEBSITE;
require ZTOOLKIT;
require ZSHIP;
use strict;

my $DEBUG = 1;    # This just outputs debug information to the apache log file


##############################################################################
# AUTHORIZE.NET FUNCTIONS

# Docs at https://secure.authorize.net/docs/

# WE ARE USING VERSION 3.1 OF THE AUTHORIZENET API


########################################
# AUTHORIZENET AUTHORIZE
sub authorize { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('AUTHORIZE',$O2,$payrec,$payment)); }
sub capture { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CAPTURE',$O2,$payrec,$payment)); }
sub charge { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CHARGE',$O2,$payrec,$payment)); }
sub void { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('VOID',$O2,$payrec,$payment)); }
sub credit { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('REFUND',$O2,$payrec,$payment)); } 




######################################################################
##
##  this is the primary "magic" routine for authorize.net
##
sub unified {
	my ($self, $VERB, $O2, $payrec, $payment) = @_;

	my $USERNAME = $O2->username();
	my $PRT = $O2->prt();

	my $agent = new LWP::UserAgent;
	$agent->agent('Groovy-Zoovy/1.0');


	my $RESULT = undef;

	if ((not defined $O2) || (ref($O2) ne 'CART2')) { 
		$RESULT = "999|Order was not defined"; 
		}
	elsif ($payrec->{'tender'} eq 'ECHECK') {
		$RESULT = "252|ECHECK not supported for this gateway";
		}
	elsif ($payrec->{'tender'} ne 'CREDIT') {
		$RESULT = "900|tender:$payrec->{'tender'} unknown";
		}
	elsif ($payrec->{'amt'}<=0) {
		$RESULT = "901|amt is a required field and must be greater than zero.";
		}
	elsif (($VERB eq 'CAPTURE') && ($payrec->{'tender'} eq 'CREDIT') && 
		($payment->{'CM'} eq '') && ($payment->{'CC'} eq '')) { 
		$RESULT = "252|Payment variables CC or CM are required!";
		}

	my $PROCESSOR_TOKEN = 'xyz';

	my $AMT = $payrec->{'amt'};
	if (defined $payment->{'amt'}) {
		$AMT = $payment->{'amt'};
		}


	# <payment_method_token>[Your Payment Method Token]</payment_method_token>
	# <billing_reference>Custom identifier for this transaction in your application.  Optional.</billing_reference>
  	# <customer_reference>Custom identifier for this customer in your application.  Optional.</customer_reference>
	# <description>Custom description here for future reference.  Will be passed on to processor where supported by processor.  Optional.</description>
	# <descriptor_name>Dynamic name descriptor. Will show up as merchant name on customer statement when supported by processor. Optional.</descriptor_name>
	# <descriptor_phone>Dynamic phone number descriptor. Will show up as merchant phone number on customer statement when supported by processor.</descriptor_phone>
	# <custom>Any value you like.  Will be passed to your processor for tracking.  Optional.</custom>

	my $payment_method_token = '';
	if (defined $RESULT) {
		}
	elsif ( ($VERB eq 'AUTHORIZE') || ($VERB eq 'CHARGE') || ($VERB eq 'CAPTURE') ) {
	
		# REQUIRED: card_number, expiry_month, expiry_year. However in practice, you should also include cvv, first_name, last_name, and the address field
		#<payment_method>
		# <custom>Any value you want us to save with this payment method</custom>
  		# <first_name>Bob</first_name>
  		# <last_name>Smith</last_name>
  		# <address_1></address_1>
  		# <address_2></address_2>
		# <city></city>
		# <state></state>
		# <zip></zip>
		# <country></country>
		# <card_type>visa</card_type>
		# <card_number>4242424242424242</card_number>
		# <cvv>123</cvv>
		# <expiry_month>12</expiry_month>
		# <expiry_year>2012</expiry_year>
		# </payment_method>

		my $xml = '';
		require XML::Writer;
		my $writer = new XML::Writer(OUTPUT => \$xml, UNSAFE=>1, DATA_INDENT => 3, ENCODING => 'utf-8');
		$writer->startTag("Payment");
			$writer->dataElement("custom",$payrec->{'uuid'});
			$writer->dataElement("first_name",$O2->in_get('bill/firstname'));
			$writer->dataElement("last_name",$O2->in_get('bill/lastname'));
			$writer->dataElement("address1",$O2->in_get('bill/address1'));
			$writer->dataElement("address2",$O2->in_get('bill/address2'));
			$writer->dataElement("city",$O2->in_get('bill/city'));
			$writer->dataElement("state",$O2->in_get('bill/region'));
			$writer->dataElement("zip",$O2->in_get('bill/postal'));
			$writer->dataElement("country",$O2->in_get('bill/countrycode'));
			my $cardtype = '';
			if (substr($payment->{'CC'},0,1) eq '4') { $cardtype = 'visa'; }
			if (substr($payment->{'CC'},0,1) eq '3') { $cardtype = 'amex'; }
			if (substr($payment->{'CC'},0,1) eq '5') { $cardtype = 'mastercard'; }
			if (substr($payment->{'CC'},0,1) eq '6') { $cardtype = 'novus'; }
			if ($cardtype ne '') {
				$writer->dataElement("card_type",$cardtype);
				}
			$writer->dataElement("card_number",$payment->{'CC'});
			$writer->dataElement("cvv",$payment->{'CV'});
			$writer->dataElement("expiry_month",$payment->{'MM'});
			$writer->dataElement("expiry_year",$payment->{'YY'});
		$writer->endTag("Payment");
		$writer->end();

		my $req = new HTTP::Request('POST', 'https://api.samurai.feefighters.com/v1/payment_methods.xml');
		$req->content($xml);
		my $result = $agent->request($req);

		## response:
		#<payment_method>
  		# <payment_method_token>QhLaMNNpvHwfnFbHbUYhNxadx4C</payment_method_token>
 		# <created_at type="datetime">2011-02-12T20:20:46Z</created_at>
  		# <updated_at type="datetime">2011-04-22T17:57:30Z</updated_at>
		# </payment_method>
		
		if ($result->content() =~ /\<payment_method_token\>(.*?)\<\/payment_method_token\>/s) {
			$payment_method_token = $1;
			}
		else {
			$RESULT = "249|Could not create payment token";
			}
		}


	#<transaction>
	#  <type>purchase</type>
	#  <amount>100.00</amount>
	#  <currency_code>USD</currency_code>
	#  <payment_method_token>[Your Payment Method Token]</payment_method_token>
	#  <billing_reference>Custom identifier for this transaction in your application.  Optional.</billing_reference>
	#  <customer_reference>Custom identifier for this customer in your application.  Optional.</customer_reference>
	#  <description>Custom description here for future reference.  Will be passed on to processor where supported by processor.  Optional.</description>
	#  <descriptor_name>Dynamic name descriptor. Will show up as merchant name on customer statement when supported by processor. Optional.</descriptor_name>
	#  <descriptor_phone>Dynamic phone number descriptor. Will show up as merchant phone number on customer statement when supported by processor.</descriptor_phone>
	#  <custom>Any value you like.  Will be passed to your processor for tracking.  Optional.</custom>
	#</transaction>
	my $URL = '';
	my @DATA = ();
	push @DATA, [ 'amount', &ZTOOLKIT::cashy($AMT) ];
	push @DATA, [ 'currency_code', 'USD' ];
	if (defined $RESULT) {
		}
	elsif ($VERB eq 'AUTHORIZE') { 
		# POST https://api.samurai.feefighters.com/v1/processors/[Processor Token]/authorize.xml
		$URL = sprintf("https://api.samurai.feefighters.com/v1/processors/%s/authorize.xml",$PROCESSOR_TOKEN);
		push @DATA, [ 'type', 'authorize' ];
		push @DATA, [ 'payment_method_token', $payment_method_token ];
		push @DATA, [ 'billing_reference', $payrec->{'uuid'} ];
		if ($O2->customerid()>0) { push @DATA, [ 'customer_reference', $O2->customerid() ]; }
		}
	elsif ($VERB eq 'CHARGE') { 
		# POST https://api.samurai.feefighters.com/v1/processors/[Processor Token]/purchase.xml
		$URL = sprintf("https://api.samurai.feefighters.com/v1/processors/%s/purchase.xml",$PROCESSOR_TOKEN);
		push @DATA, [ 'type', 'purchase' ];
		push @DATA, [ 'payment_method_token', $payment_method_token ];
		push @DATA, [ 'billing_reference', $payrec->{'uuid'} ];
		if ($O2->customerid()>0) { push @DATA, [ 'customer_reference', $O2->customerid() ]; }
		}
	elsif ($VERB eq 'CAPTURE') {
		## just requires amount
		# POST https://api.samurai.feefighters.com/v1/transactions/[Transaction Token]/capture.xml 
		$URL = sprintf("https://api.samurai.feefighters.com/v1/transactions/%s/capture.xml",$payrec->{'txn'});
		push @DATA, [ 'type', 'capture' ];
		}
	elsif ($VERB eq 'VOID') {
		# POST https://api.samurai.feefighters.com/v1/transactions/[Transaction Token]/reverse.xml
		$URL = sprintf("https://api.samurai.feefighters.com/v1/transactions/%s/reverse.xml",$payrec->{'txn'});
		}
	elsif ($VERB eq 'REFUND') {
		# POST https://api.samurai.feefighters.com/v1/transactions/[Transaction Token]/credit.xml
		$URL = sprintf("https://api.samurai.feefighters.com/v1/transactions/%s/credit.xml",$payrec->{'txn'});
		}
	else {
		$RESULT = sprintf("249|VERB:%s is not implemented",$VERB);
		}

	if (not defined $RESULT) {
		my $xml = '';
		my $writer = new XML::Writer(OUTPUT => \$xml, UNSAFE=>1, DATA_INDENT => 3, ENCODING => 'utf-8');
		$writer->startTag("Transaction");	
		foreach my $set (@DATA) {
			$writer->dataElement($set->[0],$set->[1]);
			}
		$writer->endTag("Transaction");
		$writer->end();

		my $req = new HTTP::Request('POST', $URL);
		$req->content($xml);
		my $result = $agent->request($req);


		# <transaction>
		#   <reference_id>3dcFjTC7LDjIjTY3nkKjBVZ8qkZ</reference_id>
		#   <transaction_token>53VFyQKYBmN9vKfA9mHCTs79L9a</transaction_token>
		#   <created_at type="datetime">2011-04-22T17:57:56Z</created_at>
		#   <description>Custom description here if your processor supports it.</description>
		#   <custom>Any value you like.</custom>
		#   <transaction_type>void</transaction_type>
		#   <amount>100.00</amount>
		#   <currency_code>USD</currency_code>
		#   <processor_token>[Processor Token]</processor_token>
		#   <processor_response>
		#     ...
		#     <processor_data>
		#       ...escaped data packet in it.s raw format as received from the processor...
		#     </processor_data>
		#   </processor_response>
		#   <payment_method>...</payment_method>
		# </transaction>
		# Several top-level XML blocks (<processor_response>, <payment_method> and error) can contain a messages block inside where you.ll find more information about the item. Here.s an example:

		#$payrec->{'auth'} = $transaction_token;
		#$payrec->{'txn'} = $reference_id;	
		}

	## NEED TO ADD A LOT OF ERROR HANDLING CODE HERE
	}

1;


__DATA__
