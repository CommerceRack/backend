package CART2;

#use Math::BigInt;
#use bignum;

use utf8 qw();
use Encode qw();

use Data::Dumper qw();
use strict;
use Data::GUID qw();
use POSIX qw();
use YAML::Syck qw();
use Elasticsearch::Bulk;
$YAML::Syck::ImplicitBinary++;
$YAML::Syck::ImplicitUnicode++;
$YAML::Syck::SingleQuote++;		# do not fucking enable this. it has issues with cr/lf 183i535

use IO::String qw();
use XML::SAX::Simple qw();
use Storable qw();
use Digest::MD5 qw();

$CART2::DEBUG = 0;

require ZOOVY;
require ZTOOLKIT;
# require ZTOOLKIT::XMLUTIL;
require PRODUCT;
require STUFF2;
require STUFF2::PACKAGE;
require STUFF;
require ZSHIP::RULES;
require ZSHIP;
require GIFTCARD;
require WHOLESALE;
require CUSTOMER;
require CUSTOMER::ADDRESS;
require DBINFO;
require ZWEBSITE;
require ZPAY;
require SITE;
require LISTING::MSGS;
require INVENTORY2;
require BLAST;


%CART2::FEES_MAP = (
	'PP_TRANSFEE' => 'Paypal Processing Fee',
	'CC_TRANSFEE' => 'Gateway/Terminal Transaction Fee',
	'CC_DISCRATE' => 'Gateway/Terminal Discount Rate',
	'VISA_TRANSFEE' => 'Visa Transaction Fee',
	'VISA_DISCRATE' => 'Visa Discount Rate',
	'MC_TRANSFEE' => 'Mastercard Transaction Fee',
	'MC_DISCRATE' => 'Mastercard Discount Rate',
	'AMEX_TRANSFEE' => 'American Express Transaction Fee',
	'AMEX_DISCRATE' => 'American Express Discount Rate',
	'NOVUS_TRANSFEE' => 'Discover/Novus Transaction Fee',
	'NOVUS_DISCRATE' => 'Discover/Novus Discount Rate',

	'ECHECK_TRANSFEE' => 'ECheck Transaction Fee',
	'ECHECK_DISCOUNT' => 'ECheck Discount Rate',

	'PAYPAL_FEE' => 'Paypal Transaction Fee',
	'BUY'=>'Buy.com Commission',
	'EBAY' => 'eBay Fees',
	'AOL' => 'AOL Fees',
	'ZOOVY' => 'Zoovy Fees (Est)',
	);

if (defined $CART2::FEES_MAP{''}) {}; 	# damn perl -w


##
## returns one or more fees associated with an order.
##
## %options
##		webdb (pass it if you got it)
##
sub payment_fees {
	my ($self,$payrec,%options) = @_;

	if (not defined $options{'webdb'}) {
		$options{'webdb'} = &ZWEBSITE::fetch_website_dbref($self->username());
		}

	my @FEES = ();
	if ($payrec->{'tender'} eq 'CREDIT') {
		my $ccfees = &ZTOOLKIT::parseparams($options{'webdb'}->{'cc_fees'});
		if (defined $ccfees->{'CC_TRANSFEE'}) { push @FEES, [ 'CC_TRANSFEE',sprintf("%.2f",0 + $ccfees->{'CC_TRANSFEE'}) ]; }
		if (defined $ccfees->{'CC_DISCRATE'}) { push @FEES, [ 'CC_DISCRATE',sprintf("%.2f",$payrec->{'amt'} * ($ccfees->{'CC_DISCRATE'}/100)) ]; }

		my $acctref = &ZPAY::unpackit($payrec->{'acct'});
		my $cardtype = substr($acctref->{'CM'},0,1);
		if ($cardtype eq '3') { 	## Amex
			if (defined $ccfees->{'AMEX_TRANSFEE'}) { push @FEES, [ 'AMEX_TRANSFEE',sprintf("%.2f",0 + $ccfees->{'AMEX_TRANSFEE'}) ];}
			if (defined $ccfees->{'AMEX_DISCRATE'}) { push @FEES, [ 'AMEX_DISCRATE',sprintf("%.2f",$payrec->{'amt'} * ($ccfees->{'AMEX_DISCRATE'}/100)) ];}			
			}
		elsif ($cardtype eq '4') { 	## Visa
			if (defined $ccfees->{'VISA_TRANSFEE'}) { push @FEES, [ 'VISA_TRANSFEE',sprintf("%.2f",0 + $ccfees->{'VISA_TRANSFEE'}) ];}
			if (defined $ccfees->{'VISA_DISCRATE'}) { push @FEES, [ 'VISA_DISCRATE',sprintf("%.2f",$payrec->{'amt'} * ($ccfees->{'VISA_DISCRATE'}/100)) ];}			
			}
		elsif ($cardtype eq '5') { 	## MC
			if (defined $ccfees->{'MC_TRANSFEE'}) { push @FEES, [ 'MC_TRANSFEE',sprintf("%.2f",0 + $ccfees->{'MC_TRANSFEE'}) ];}
			if (defined $ccfees->{'MC_DISCRATE'}) { push @FEES, [ 'MC_DISCRATE',sprintf("%.2f",$payrec->{'amt'} * ($ccfees->{'MC_DISCRATE'}/100)) ];}			
			}
		elsif ($cardtype eq '6') { 	## Discover
			if (defined $ccfees->{'NOVUS_TRANSFEE'}) { push @FEES, [ 'NOVUS_TRANSFEE',sprintf("%.2f",0 + $ccfees->{'NOVUS_TRANSFEE'}) ];}
			if (defined $ccfees->{'NOVUS_DISCRATE'}) { push @FEES, [ 'NOVUS_DISCRATE',sprintf("%.2f",$payrec->{'amt'} * ($ccfees->{'NOVUS_DISCRATE'}/100)) ];}			
			}
		}

	if ($options{'apply'}) {
		foreach my $row (@FEES) {
			my ($FEETYPE,$AMOUNT) = @{$row};
			my $UUID = sprintf("%s-%s",$FEETYPE,$payrec->{'uuid'});
			$self->set_fee('',$FEETYPE,$AMOUNT,$payrec->{'ts'},undef,$UUID);
			}
		}

	return(@FEES);
	}


##
## webdoc WEBDOC #51732
## 

=pod

[[SECTION]Cart/Order Format]
 There are going to be *AT LEAST* three types of carts, just like humans, monkeys and apes they share 99% of the same DNA.
	Some are bigger, some are smaller. Some are faster, some are slower. Some aren't carts at all. The three types are:

1. Persistent == use either a user defined session id, or random session id. changes are stored in databsae.
						  CART->new_persist(USERNAME,PRT,CARTID,IPADDRESS,%params)
2. In Memory  == used by syndications to populate data and run validation BEFORE creating an order, never stored 
						  CART->new_memory(USERNAME,PRT,%params)
3. From Order == carts sourced from orders, or orders that need to be modified (ex: recalc promotions, shipping, etc.)
					  CART->new_from_order(ORDEROBJECT,%params)

 NOTE: there is **INTENTIONALLY** no CART->new function (intentionally) each type of cart has it's own new function. 

[[/SECTION]]

[[SECTION]Fields]

[[MASON]]
% use CART2;
% print CART2::htmltable();
[[/MASON]]

[[/SECTION]]

[[SECTION]Order Flags]
 ORDER "FLAGS" COLUMN: flags
 1 1<<0 = true if +1 items in order (at creation)
 2 1<<1 = true if high priority shipping  (based on known PRIORITY carrier codes)
 4 1<<2 = true if repeat customer  
 8 1<<3 = true if order was *involved* in a split.
 16 1<<4 = true if split-result (new orders will get this set)
 32 1<<5 = true if order has multiple payments    (not supported yet)
 64 1<<6 = true if one or more items has a supply chain (virtual) item. 
 128 1<<7 = true if multiple shipments           -- a flag set when shipping
 256 1<<8 = true if one or more items returned   -- to be implemented
 512 1<<9 = true if the order was edited by merchant

 1024 1<<10 = one or more items is backordered
 2048 1<<11 = user set "high priority" bit
 4096 1<<12 = order was on the 'a' side of a/b test
 8192 1<<13 = order was on the 'b' side of a/b test
 4096+8192 (1+2)<<12 = multivarsite was set, but not to 'A' or 'B'
 16384 1<<14 = order is a gift order (does not print out prices)
 1<<15 = has public notes
 1<<16 = has private notes

[[/SECTION]]



=cut

sub epoch2xmltime {
	my ($t) = @_;
	return ( strftime("%Y-%m-%dT%H:%M:%S", gmtime($t)));
	}


sub SESSION {
	my ($self, $session) = @_;
	if (defined $session) { $self->{'*SESSION'} = $session; }
	return($self->{'*SESSION'});
	}

##
##
##
sub invdetail {
	my ($self) = @_;

	my %UUIDS = ();

	if ($self->is_order()) {
		my $INVDETAIL = INVENTORY2->new($self->username())->detail(
			'+'=>'ORDER',
			'@BASETYPES'=>['UNPAID','PICK','DONE','BACKORDER','PREORDER'],
			'WHERE'=>[ 'ORDERID', 'EQ', $self->oid() ]
			);
		foreach my $row (@{$INVDETAIL}) {
			$UUIDS{$row->{'UUID'}} = $row;
			}
		}
	return(\%UUIDS);
	}


##
## reformats the output for a JSON %R response object, strips out some detail level
##
sub jsonify {
	my ($self) = @_;

	my %R = ();
	foreach my $grp (@CART2::VALID_GROUPS) {
		$R{"$grp"} = $self->{"%$grp"};
		}
	foreach my $key ('@PACKAGES','@PAYMENTQ','@PAYMENTS','@HISTORY') {
		$R{"$key"} = $self->{"$key"};
		}

	$R{'@SHIPMENTS'} = $self->tracking();
	$R{'@ITEMS'} = $self->stuff2()->items();

	$R{'%INVDETAIL'} = $self->invdetail();
	#foreach my $item (@{$R{'@ITEMS'}}) {
	#	
	#	}

	$R{'@SHIPMETHODS'} = $self->{'@shipmethods'};

	return(\%R);
	}


##
## 
##
sub clone {
	my ($self) = @_;
	$self = Storable::dclone($self);	
	}


##
## strips private info so we can expose this order safely to a buyer
##
sub make_public {
	my ($self) = @_;

	## protect yourself before you mess yourself:
	$self = $self->clone()->make_readonly();

	## strip down fields which should not be public
	foreach my $k (keys %CART2::VALID_FIELDS) {
		my $public = $CART2::VALID_FIELDS{$k}->{'public'};

		if ((defined $public) && ($public == 0)) {
			$self->in_set($k,undef);
			}
		}

	## remove sensitive fields from items
	foreach my $item (@{$self->stuff2()->items()}) {
		delete $item->{'cost'};
		delete $item->{'base_cost'};
		}

	## yeah, we never show history.
	delete $self->{'@HISTORY'};
	delete $self->{'@FEES'};
	delete $self->{'@ACTIONS'};

	return($self);
	}



##
## this returns sdomain ONLY if it's not a marketplace domain (ex: assumed to be owned by us)
## note: eventually we should split our/sdomain and mkt/domain -- future build.
sub if_our_sdomain {
	my ($self) = @_;

	my $sdomain = lc($self->__GET__('our/domain'));
	if ($sdomain eq '') { $sdomain = undef; }
	foreach my $intref (@ZOOVY::INTEGRATIONS) {
		last if (not defined $sdomain);
		if ($intref->{'domain'} eq $sdomain) { $sdomain = undef; }
		}
	return($sdomain);
	}

## 
## this could eventually have parameters for only requesting a valid domain (ex: no amazon.com)
##
sub sdomain {
	my ($self, %options) = @_;
	return($self->domain(%options));
#	my $sdomain = lc($self->__GET__('our/sdomain'));
#	return($sdomain);
	}




##
## we'd REALLY like to look at xxxx/countrycode for "US" but right now that seems a little far fetched.
##    2012/09/28 - bh 
sub is_domestic {
	my ($self,$type) = @_;
	my $is_domestic = 0;
	if ($self->{"%$type"}->{'countrycode'} eq '') {
		warn "$type/countrycode not set - defaulting to IS domestic\n";
		$is_domestic++;
		}	
	elsif ($self->{"%$type"}->{'countrycode'} eq 'US') {
		$is_domestic++;
		}	
	#if ($O2->in_get('ship/countrycode') eq 'United States') { $O2->in_set('ship/countrycode','US'); }
	#if ($O2->in_get('ship/countrycode') eq 'USA') { $O2->in_set('ship/countrycode','US'); }
	#if ($O2->in_get('ship/countrycode') eq 'US') { $O2->in_set('ship/countrycode','US'); }
	#if ($O2->in_get('bill/countrycode') eq 'United States') { $O2->in_set('bill/countrycode','US'); }
	#if ($O2->in_get('bill/countrycode') eq 'USA') { $O2->in_set('bill/countrycode','US'); }
	#if ($O2->in_get('bill/countrycode') eq 'US') { $O2->in_set('bill/countrycode','US'); }

	return($is_domestic);
	}



sub set_site { my ($self,$site) = @_;  $_[0]->{'*SITE'} = $site; return($site); }
sub has_site { return(defined $_[0]->{'*SITE'})?1:0; }
sub site {
	my ($self, $site) = @_;
	if (not defined $self->{'*SITE'}) {
		$self->{'*SITE'} = SITE->new($self->username(),'PRT'=>$self->prt(),'*CART2'=>$self,'DOMAIN'=>$self->in_get('our/domain'));
		}
	return($self->{'*SITE'});
	}



sub htmltable {
		
	my $c = '';
	my $r = '';
	foreach my $k (sort keys %CART2::VALID_FIELDS) {
		$r = ($r eq 'r0')?'r1':'r0';
		my $ref = $CART2::VALID_FIELDS{$k};
		my $title = $ref->{'title'};
		if ($title eq '') { $title = "<i>Unknown</i>"; }
		my $format = $ref->{'format'};
		if ($format eq '') { $format = '?'; }
		my $notes = '';
		if ($ref->{'hint'}) { $notes .= "HINT: $ref->{'hint'}<br>"; }
		if ($ref->{'sync'}) { $notes .= "** causes internal validation of object **<br>"; }
		if ($ref->{'order1'}) { $notes .= "legacy order v1: $ref->{'order1'}<br>"; }
		if ($ref->{'cart1'}) { $notes .= "legacy cart v1: $ref->{'cart1'}<br>"; }
		$c .= "<tr class=\"$r\"><td valign=top>$k</td><td valign=top>$format</td><td nowrap valign=top>$title</td><td valign=top>$notes</td></tr>";
		}

	return(qq~
<table border=1 width=100%>
<tr>
	<td><b>FIELD</b></td>
	<td><b>FORMAT</b></td>
	<td><b>TITLE</b></td>
	<td><b>NOTES/USAGE</b></td>
</tr>
$c
</table>
~);
	}


##
## <drumroll>
##	<que angels singing>
##	Rosetta stone for Cart1=>Order1=>Cart2+Order2
##
## Before you start reading - there are namespaces built into the object that are shared across all carts
##		the namespaces denote a level of privacy, and security - the goal of each field is to clearly denote:
##
##		WHO (end-user or our software) is responsible for setting the data's initial state.
##		WHAT data is contained in the field both for validation, and developer intuitiveness
##		WHERE data can be changed - has validation rules - or is read only.
##		WHEN business logic is allowed to override their settings. 
##		WHY  we will rock them like a hurricane. (sorry i got nothing here)
##
##  The naming convention uses a / notation to denote the class of data I'll briefly explain those:
##
##	 ship/* 	: shipping address info
##	 bill/*	: billing address info  (internally this may be a memory pointer to ship/*)
##	 our/*	: constants that are common/set by business logic - mostly order centric.
##  flow/*	: workflow status, private notes, etc.
##	 is/*		: boolean - where false is (0) / true is (positive single byte unsigned integer 1..255 bitwise compatible) 
##	 sum/*	: all currency fields denoting order totals, etc. this will be recomputed whenever is/* or this/* changes
##	 want/*	: things that should/can be the end-user/app managing the session
##	 must/* 	: things the user can't change (they will always use the same name as want/* settings)
##  customer/* : a few fields to expose customer record and authentication data
##  app/*	: non-validated fields that will be stored in the cart (and order?) for developer extensibility
##	 mkt/* 	: marketplace specific fields
##
## use??

##
## IN AN ORDER:
##
## @PAYMENTS
##		an array of:
##		{ uuid=>"", txn=>"", tender=>"", ts=>time, amt=>1.00, note=>"" }
##	the sum of all amt=> becomes paid_total   (and  order_total - balancedue_total)
##
##
## IN A CART:
## @PAYMENTQ
##		$self->paymentQ('list')
## 



## $CART2::VERSION = 20120921;
## $CART2::VERSION = 20120921;
@CART2::VALID_GROUPS = ( 'ship','bill','our','flow','mkt','cart','is','sum','want','app','customer');

## FIELDS THAT ARE ALLOWED IN AN ADDRESS SPACE
@CART2::VALID_ADDRESS = ( 'email','phone','facsimile','company','firstname','shortcut','middlename','lastname','address1','address2','postal','region','city','countrycode' );


##
## returns the internal version # of the cart or order
##
sub version {
	if (defined $_[1]) { $_[0]->{'V'} = $_[1]; }
	if (not defined $_[0]->{'V'}) { $_[0]->{'V'} = $CART2::VERSION; }
	return($_[0]->{'V'});
	}

##
##
##     
##
##
%CART2::VALID_FIELDS = (	
	## shipping address (accessible to authorized user)
	'ship/email'=>{ es=>'ship/email', format=>"email", cart1=>'data.ship_email', order1=>'ship_email', title=>"Shipping Email", hint=>"Not usually specified" },	 # stored $self->{'%ship'}->{'email'}
	'ship/phone'=>{ es=>'ship/phone', format=>"phone", cart1=>'data.ship_phone', order1=>'ship_phone', title=>"Shipping Phone" },
	'ship/facsimile'=>{ format=>"phone", title=>"Shipping Facsimile" },
	'ship/company'=> { es=>'ship/company', format=>"text", cart1=>'data.ship_company', order1=>'ship_company' },
	'ship/firstname'=>{ es=>'ship/firstname', format=>"text", cart1=>'data.ship_firstname', order1=>'ship_firstname' },
	'ship/middlename'=> { format=>"text", cart1=>'data.ship_middlename', order1=>'ship_middlename' },
	'ship/lastname'=>{ es=>'ship/lastname', format=>"text", cart1=>'data.ship_lastname', order1=>'ship_lastname' },
	'ship/address1'=>{ sync=>1, cart1=>'data.ship_address1', order1=>'ship_address1' },
	'ship/address2'=>{ sync=>1, cart1=>'data.ship_address2', order1=>'ship_address2' },
	'ship/region'=>{ es=>'ship/region', compat=>'ship/state', sync=>1, cart1=>'data.ship_state', order1=>'ship_state' },
	'ship/postal'=>{ es=>'ship/postal', compat=>'ship/zip', sync=>1, cart1=>'data.ship_zip', order1=>'ship_zip' },
	'ship/city'=>{ sync=>1, cart1=>'data.ship_city', order1=>'ship_city' },
#	'ship/province'=>{ compat=>'ship/province', sync=>1, cart1=>'data.ship_province', order1=>'ship_province' },
#	'ship/int_zip'=>{ compat=>'ship/int_zip', sync=>1, cart1=>'data.ship_int_zip', order1=>'ship_int_zip' },
	'ship/countrycode' => { es=>'ship/country', sync=>1, 'order1'=>'ship_countrycode' }, 	# ship_country (pretty name)
	'ship/shortcut'=>{ },	# shortcut id in the customer record

#	'our/paypal_acct' => {},
#	'flow/sc_orderinfo' => {},
#	'our/payment_authorization' => {},
#	'our/payment_cc_processor' => {},
#	'our/payment_cc_results' => {},
#	'our/payment_cc_status' => {},

	## billing address
	'bill/email'=>{ es=>'bill/email', cart1=>'data.bill_email', order1=>'bill_email', title=>"Billing Email", hint=>"Used for all correspondence for the order, the order will be auto-linked to a customer with this email." },
	'bill/phone'=>{ es=>'bill/phone', format=>"phone", cart1=>'data.bill_phone', order1=>'bill_phone', title=>"Billing Phone", hint=>"format: XXX-XXX-XXXX" },
	'bill/facsimile'=>{ format=>"phone", title=>"Billing Facsimile", hint=>"format: XXX-XXX-XXXX" },
	'bill/company'=> { es=>'bill/company', cart1=>'data.bill_company', order1=>'bill_company' },
	'bill/firstname'=>{ es=>'bill/firstname', cart1=>'data.bill_firstname', order1=>'bill_firstname' },
	'bill/middlename'=> { cart1=>'data.bill_middlename', order1=>'bill_middlename' },
	'bill/lastname'=>{ es=>'bill/lastname', cart1=>'data.bill_lastname', order1=>'bill_lastname' },
	'bill/address1'=>{ cart1=>'data.bill_address1', order1=>'bill_address1' },
	'bill/address2'=>{ cart1=>'data.bill_address2', order1=>'bill_address2' },
	'bill/region'=>{ compat=>'bill/state', cart1=>'data.bill_state', order1=>'bill_state' },
	'bill/postal'=>{ es=>'bill/postal', compat=>'bill/zip', sync=>1, cart1=>'data.bill_zip', order1=>'bill_zip' },
#	'bill/province'=>{ compat=>'bill/province', cart1=>'data.bill_province', order1=>'bill_province' },
#	'bill/int_zip'=>{ compat=>'bill/int_zip', cart1=>'data.bill_int_zip', order1=>'bill_int_zip' },
	'bill/city'=>{ es=>'bill/city', cart1=>'data.bill_city', order1=>'bill_city' },
	'bill/countrycode' => { es=>'bill/country', sync=>1, 'order1'=>'bill_countrycode' }, 	# bill_country (pretty name)
	'bill/shortcut'=>{ },

	## 'OUR' may only be set by internal methods, usually for orders, they are considered constants
	## and should NOT be visible to non-authenticated users.
	##	note: these names are horrible and WILL change prior to release, but for simplicity 
	##			will not right now.
	## The private order variables (our/ship_date) will likely change. 
	## I *may* move away from timestamp to a more common YYYYMMDDHHMMSS format for syncing (tbd)

	'cart/created_ts'=>{ public=>1, es=>'cart_created_ts', compat=>'this/created', cart1=>'created' },	# date the cart was created (name will probably change)
	'cart/cartid'=>{ compat=>'our/cartid', order1=>'cartid' },
	'cart/refer' => { es=>'refer', public=>1, inicompat=>'our/meta', order1=>'meta' },
	'cart/refer_src' => { public=>1, compat=>'our/meta_src', order1=>'meta_src' },
	'cart/checkout_stage'=> { public=>0, compat=>'this/checkout_stage', },
	'cart/checkout_digest'=> { public=>0, compat=>'this/checkout_digest', cart1=>'chkout.checksum' },
	'cart/ip_address'=>{ es=>'ip_address', compat=>'our/ip_address', order1=>'ip_address', cart1=>'ipaddress' },
	'cart/multivarsite'=> { public=>1, compat=>'our/multivarsite', order1=>'multivarsite', cart1=>'multivarsite' },
	'cart/previous_cartid'=> { compat=>'this/previous_cart_id' },
	'cart/next_cartid'=> { compat=>'this/previous_cart_id' },
	'cart/shipping_id' => { compat=>'this/shipping_id', order1=>'shp_id' },
	'cart/paypalec_result'=>{ public=>0, compat=>'our/paypalec_result', cart1=>'chkout.paypalec' },	# a packit of PV=|PT=|PS=|PC=|PI=|PZ=
	'cart/paypal_token'=> { public=>0, compat=>'our/paypal_token', cart1=>'chkout.paypal_token' }, # the token returned to us by paypal for ec
	'cart/buysafe_purchased'=>{ compat=>'this/buysafe_purchased', sync=>1, order1=>'buysafe_val', cart1=>'ship.buysafe_purchased', format=>'int' },
	'cart/buysafe_cartdetailsdisplaytext' => { compat=>'this/buysafe_cartdetailsdisplaytext', sync=>1, order1=>'buysafe_cartdetailsdisplaytext' },
	'cart/buysafe_cartdetailsurl' => { compat=>'this/buysafe_cartdetailsurl', sync=>1, order1=>'buysafe_cartdetailsurl' },
	'cart/buysafe_bondingsignal' => { compat=>'this/buysafe_bondingsignal', sync=>1, order1=>'buysafe_bondingsignal' },
	'cart/buysafe_bondcostdisplaytext' => { compat=>'this/buysafe_bondcostdisplaytext', sync=>1, order1=>'buysafe_bondcostdisplaytext' },
	'cart/buysafe_mode' => { compat=>'this/buysafe_mode', sync=>1 },
	'cart/buysafe_error'=>{ compat=>'this/buysafe_error', sync=>1, order1=>'buysafe_error', cart1=>'ship.buysafe_error', format=>'int' },
	'cart/buysafe_val'=>{ compat=>'this/buysafe_val', sync=>1, order1=>'buysafe_val', cart1=>'ship.buysafe_val', format=>'int' },
	'cart/qbms_sent' => { public=>0, compat=>'flow/qbms_sent', order1=>'qbms_sent' },
	'cart/qbms_rcv' => { public=>0, compat=>'flow/qbms_rcv', order1=>'qbms_rcv' },

	## the ones below are available to *most* carts
	'our/orderid'=> { es=>'orderid', cart1=>'chkout.order_id' },
	'our/order_ts' => { es=>'cart_order_ts', compat=>'our/created', format=>"date", order1=>'created' },		## ts of when orde was created
	'our/version'=>{ order1=>'version' },
	## 'our/profile'=>{ es=>"profile", public=>0, order1=>'profile' },
	'our/prt'=>{ es=>"prt", public=>0, order1=>'prt' },
	## 'our/sdomain' => { es=>"sdomain", order1=>'sdomain', cart1=>'chkout.sdomain' },
	'our/domain' => { order1=>'sdomain' },
	'our/mkts' => { order1=>'mkts' },
	'our/jobid'=>{ public=>0, },		# batch job # which created this file.
	'our/fedex_signature' => { order1=>'fedex_signature', hint=>"NO_SIGNATURE_REQUIRED|INDIRECT|DIRECT" },	
	'our/fedex_insuredvalue' => { order1=>'fedex_insuredvalue' },
	'our/ups_signature' => { order1=>'ups_signature' },
	'our/ups_insuredvalue' => {  order1=>'ups_insuredvalue' },
	'our/usps_signature' => { order1=>'usps_signature' },
	'our/usps_insuredvalue' => { order1=>'usps_insuredvalue' },
	'our/usps_insuredtype' => { order1=>'usps_insuredtype' },
	'our/schedule'=>{ compat=>'this/schedule', order1=>'schedule', cart1=>'schedule' },	
	'our/schedule_src'=>{ compat=>'this/schedule_src', order1=>'schedule_src', cart1=>'schedule_src' },	
	'our/tax_zone'=>{ group=>'tax', compat=>'this/tax_zone', order1=>'tax_zone', cart1=>'data.tax_zone' },	## tax_zone settings to use 
	'our/tax_rate'=>{ group=>'tax', compat=>'this/tax_rate', order1=>'tax_rate', cart1=>'data.tax_rate' },	## will be used for all taxable items where tax_rate is zero 

	## marketplace fields all
	'mkt/google_orderid'=>{ es=>"*REFERENCE", legacy=>1, order1=>'google_orderid', title=>"Google Order Id", hint=>"Legacy field - replaced by GO in payment ACCT field" },	 
	'mkt/google_serial'=>{ legacy=>1, order1=>'google_serial', title=>"Google Transaction Serial #", hint=>"Legacy field - replaced by GS in payment ACCT field=" },	 
	'mkt/google_protection' => { order1=>'google_protection' },
	'mkt/google_account_age' => { order1=>'google_account_age' },
	'mkt/google_account_cc' => { order1=>'google_cc_number' },
	'mkt/order_total' => { },
	'mkt/sears_po_date' => { order1=>'mkt/sears_po_date' },
	'mkt/sears_orderid' => { es=>'*REFERENCE', order1=>'sears_orderid' },
	'mkt/hsn_orderid' => { es=>'*REFERENCE', order1=>'hsn_orderid' },
	'mkt/hsn_customer_num' => { order1=>'hsn_customer_num' },
	'mkt/hsn_credit_amount' => { order1=>'hsn_credit_amount' },
	'mkt/hsn_payment_method' => { order1=>'hsn_payment_method' },
	'mkt/hsn_senderid' => { order1=>'hsn_senderid' },
	'mkt/hsn_receiverid' => { order1=>'hsn_receiveid' },
	'mkt/newegg_po_date' => { order1=>'mkt/newegg_po_date' },
	'mkt/recipient_orderid' => {},
	'mkt/siteid' => { 'title'=>"Marketplace Site #", 'hint'=>'eBay[site id], AmazonCBA is "cba"' },
	'mkt/docid' => { 'title'=>'Marketplace Origin Document #' },
	'mkt/buyerid' => { 'title'=>"Marketplace Buyer ID", 'hint'=>'eBay[buyer username]' },
	'mkt/payment_txn'=> {},
	'mkt/post_date' => { format=>"date", order1=>'post_date' },	## this is used by marketplaces to indicate when payment was posted (but not cleared)
	'mkt/expected_ship_date'=> { format=>"date" },
	'mkt/erefid'=>{ es=>"*REFERENCE", format=>"text",order1=>'erefid', cart1=>'erefid' },
	'mkt/amazon_orderid'=>{ es=>"*REFERENCE", order1=>'amazon_orderid' },
	'mkt/amazon_merchantid'=>{ order1=>'amazon_merchantid' },
	'mkt/amazon_sessionid'=>{ order1=>'amazon_sessionid' },

	## we don't need these methods - just push a shipment onto the queue and select it.
	#'mkt/shp_total' => {},
	#'mkt/shp_method' => {},


	## 'FLOW' fields are for workflow. will likely be stored separately since they'll be updated a lot more.
	## they *ONLY* apply to orders that have been created.
	'flow/cancelled_ts' => { compat=>'flow/cancelled', format=>"date", order1=>'cancelled' },  ## (ts of when order was cancelled)
	'flow/paid_ts' => { es=>"paid_ts", compat=>'our/paid_date', format=>"date", order1=>'paid_date' },
	'flow/shipped_ts' => { es=>"shipped_ts", format=>"date", compat=>'flow/shipped_gmt', order1=>'shipped_gmt' },
	'flow/posted_ts' => { compat=>'flow/posted', order1=>'posted' },		
	'flow/modified_ts'=>{ compat=>'our/timestamp', format=>"date", order1=>'timestamp' },
	'flow/google_processed_ts'=>{ compat=>'flow/google_processed', order1=>'google_processed' },
	'flow/google_archived_ts'=>{ compat=>'flow/google_archived', order1=>'google_archived' },
	'flow/private_notes'=>{ public=>0, order1=>'private_notes' },
	'flow/review_status'=>{ es=>"review_status", order1=>'review_status' },
	'flow/pool'=>{ es=>"pool", order1=>'pool' },
	'flow/subpool'=>{ order1=>'subpool' },
	'flow/payment_status'=>{ es=>"payment_status", order1=>'payment_status' },
	'flow/flags'=>{ es=>"flags", public=>0, order1=>'flags' },
	'flow/batchid'=>{ order1=>'batchid' },
	'flow/google_sequenceid'=>{ order1=>'google_sequenceid' },	# tracks the internal msgs received from google payments
	'flow/buysafe_notified_ts'=>{ compat=>'flow/buysafe_notified_gmt', 'order1'=>'buysafe_notified_gmt' },
	'flow/shp_service' => { group=>'ship', compat=>'this/shp_service', order1=>'our/shp_service' },	# ZID?
	'flow/shp_footer' => { group=>'ship', compat=>'this/shp_footer', order1=>'our/shp_footer' },		# ZID?
	'flow/om_process' => { compat=>'this/om_process', order1=>'our/om_process' }, 	# ZID?
	'flow/kount' => { public=>0, order1=>'kount' },
	'flow/supplier_orderid' => { compat=>'our/supplier_orderid', order1=>'supplier_order_id' }, 	## *** NEEDS LOVE *** (is okay)
	'flow/qbook_export' => { compat=>'our/qbook_export', order1=>'qbook_export' },
	'flow/payment_method'=>{ compat=>'this/payment_method', order1=>'payment_method' },

	## 'THIS' must be set by internal methods and will be used to compute digests.
	##			 THIS values are often changed 
	# 'this/total_weight'=>{ compat=>'THIS', format=>"weight", order1=>'total_weight', cart1=>'data.total_weight' }, 	## deprecated field.


	## true/false settings (these will read well in the code) .. may store values 0 .. 255 (for bitwise)
	# 'is/gfc_available'=> {},	 .. eventually we might want to use this as an indicator
	'is/cpn_optional' => {},
	'is/cpn_quote' => {},
	'is/tax_fixed'=>{ group=>'tax', sync=>1, format=>'intbool' },
	'is/spc_taxable'=>{ group=>'tax', sync=>1, format=>"intbool", order1=>'spc_taxable', cart1=>'ship.spc_taxable' },
	'is/bnd_taxable'=>{ group=>'tax', sync=>1, format=>"intbool", order1=>'bnd_taxable', cart1=>'ship.bnd_taxable' },
	'is/bnd_optional'=>{ },	# yes we still have support for this.
	'is/gfc_taxable'=>{ group=>'tax',  },
	'is/pnt_taxable'=>{ group=>'tax', },
	'is/rmc_taxable'=>{ group=>'tax', },
	'is/ins_optional'=>{ sync=>1, format=>"intbool", order1=>'ins_optional', cart1=>'ship.ins_optional' },
	'is/ins_taxable'=>{ group=>'tax', sync=>1, format=>"intbool", order1=>'ins_taxable', cart1=>'ship.ins_taxable' },
	'is/hnd_taxable'=>{ group=>'tax', sync=>1, format=>"intbool", order1=>'hnd_taxable', cart1=>'ship.hnd_taxable' },
	'is/shp_taxable'=>{ group=>'tax', sync=>1, format=>"intbool", order1=>'shp_taxable', cart1=>'ship.shp_taxable' },
	## note: is/gfc_taxable is always false so we don't include it.
	'is/giftorder'=>{ sync=>1, format=>"intbool", order1=>'is_giftorder' },
	'is/cpn_taxable'=>{ group=>'tax' },
	##	is_wholesale => bitwise, set on login
	##		1 = has wholesale access (has a schedule associated with customer record)
	##		2 = the customer has inventory edi access
	##		4 = the customer has product edi access
	##		8 = the customer has order edi access
	'is/wholesale'=>{ sync=>1, format=>"intbw" },	# a wholesale pricing schedule is in use
	'is/allow_po'=>{ sync=>1, format=>"intbw" },
	'is/inventory_exempt'=> {  format=>"intbool" }, 	# customer can order items that are not in stock
	'is/tax_exempt'=>{  format=>"intbool"  },	# customer is tax exempt
	'is/email_suppress'=>{  format=>"intbool", order1=>'email_suppress' },	# don't send emails
	## perhaps you meant 'is/marketplace' ?
	'is/origin_marketplace'=> { format=>"intbool", title=>"Use Marketplace Fixed Taxes/Shipping" }, # an internal flag that tells us to avoid computing shipping.
	'is/origin_staff' => { format=>"intbool", title=>"Created by an Admin User" },

	## these fields are computed by the system (the formulas are documented below) -- the "SUM" stands 
	## 	for summary, many are numeric
	##
	## naming conventions:
	##		sum/fee_total = the fee amount
	##		sum/fee_tax   = should the tax rate be applied to the amount
	##		our/fee_method = the name of the fee		
	##
	## 'this/product_count'=>{ order1=>'product_count' },	# used by infusionsoft
	'sum/items_taxdue'=>{ group=>'tax', sync=>1 },
	'sum/items_count'=>{ sync=>1, format=>'integer', order1=>'item_count' },			# wtf is the difference between item_count vs. product count?
	'sum/items_taxable'=>{ group=>'tax', sync=>1, format=>'intamt',order1=>'tax_subtotal', cart1=>'data.tax_subtotal' },
	'sum/items_total'=>{ es=>"items_total", sync=>1, format=>'intamt',order1=>'order_subtotal', cart1=>'data.order_subtotal' },

	'sum/pkg_weight'=>{ format=>"weight", order1=>'actual_weight', cart1=>'data.actual_weight' },  # wtf is the difference between actual vs. total
	'sum/pkg_weight_166'=>{ order1=>'pkg_weight_166', cart1=>'data.pkg_weight_166' },	# air dimensional weight
	'sum/pkg_weight_194'=>{ order1=>'pkg_weight_194', cart1=>'data.pkg_weight_194' },	# ground dimensional weight
	'sum/pkg_cubic_inches'=>{ format=>"integer", hint=>"ground dimensional weight LxWxH" },

	'sum/cpn_method' => { compat=>'this/cpn_method' },
	'sum/cpn_total'=>{},

	## we should think about adding another type of tax field.
	'sum/tax_method'=>{ group=>'tax', compat=>'this/tax_method', pretty=>'Taxes' },
	'sum/tax_total'=>{ group=>'tax', sync=>1, format=>'intamt',order1=>'tax_total', cart1=>'data.tax_total'  },
	'sum/tax_rate_state'=>{ group=>'tax', compat=>'this/state_tax_rate', order1=>'state_tax_rate', cart1=>'data.state_tax_rate' },
	'sum/tax_rate_zone'=>{ group=>'tax', compat=>'this/local_tax_rate', order1=>'local_tax_rate', cart1=>'data.local_tax_rate' }, # district
	'sum/tax_rate_city'=>{ group=>'tax', compat=>'this/city_tax_rate'  },
	'sum/tax_rate_region'=>{ group=>'tax', compat=>'this/county_tax_rate' },

	'sum/hnd_method'=>{ group=>'ship', compat=>'this/hnd_method', sync=>1, order1=>'hnd_method', cart1=>'ship.hnd_method' },
	'sum/hnd_total'=>{ group=>'ship', sync=>1, format=>'intamt',order1=>'hnd_total', cart1=>'ship.hnd_total' },
	'sum/hnd_taxdue'=>{ group=>'tax', sync=>1, format=>'intamt', },

	'sum/gfc_method' => { compat=>'this/gfc_method', },
	'sum/gfc_total'=>{ sync=>1, format=>'intamt',order1=>'gfc_total', cart1=>'ship.gfc_total', title=>"amount of all giftcards" },
	'sum/gfc_available'=>{ sync=>1, format=>'intamt', title=>"available balance of giftcards" },	
	'sum/pnt_method' => { },
	'sum/pnt_total'=>{ sync=>1, format=>'intamt', title=>"value of all points" },
	'sum/pnt_available'=>{ sync=>1, format=>'intamt', title=>"available balance of giftcards" },	
	'sum/rmc_method' => { },
	'sum/rmc_total'=>{ sync=>1, format=>'intamt', title=>"total value of return merchandise credits" },
	'sum/rmc_available'=>{ sync=>1, format=>'intamt', title=>"available balance of return merchandise credit" },	

	'sum/ins_method'=>{ group=>'ship', compat=>'this/ins_method', sync=>1, order1=>'ins_method', cart1=>'ship.ins_method' },
	'sum/ins_total'=>{ sync=>1, format=>'intamt',order1=>'ins_total', cart1=>'ship.ins_total' },
	'sum/ins_quote'=>{ group=>'ship', digest=>0, sync=>1, format=>'intamt',order1=>'ins_quote', cart1=>'ship.ins_quote' },
	'sum/ins_taxdue'=>{ group=>'tax', sync=>1, },

	'sum/bnd_method'=>{ compat=>'this/bnd_method', sync=>1, order1=>'bnd_method', cart1=>'ship.bnd_method' },
	'sum/bnd_total'=>{ sync=>1, format=>'intamt',order1=>'bnd_total', cart1=>'ship.bnd_total' },

	'sum/spc_method'=>{ compat=>'this/spc_method', sync=>1, order1=>'spc_method', cart1=>'ship.spc_method' },
	'sum/spc_taxable'=>{ sync=>1 },
	'sum/spc_total'=>{ sync=>1, format=>'intamt',order1=>'spc_total', cart1=>'ship.spc_total' },

	'sum/shp_carrier' => { group=>'ship', compat=>'this/shp_carrier', order1=>'shp_carrier', cart1=>'ship.selected_carrier' },	## 4 digit carrier code ups|fedex|usps  for selected ship method -- where is this set ?? (user.pl uses it)
	'sum/shp_method'=>{ es=>"shp_method", group=>'ship', compat=>'this/shp_method', order1=>'shp_method', cart1=>'ship.selected_method' },
	'sum/shp_taxable'=> { group=>'tax', sync=>1 },
	'sum/shp_total'=>{ group=>'ship', sync=>1, format=>'intamt',order1=>'shp_total', cart1=>'ship.selected_price' },
	'sum/shp_taxdue'=>{ group=>'tax', sync=>1, format=>'intamt', },

	'sum/spx_total'=>{ sync=>1, format=>'intamt',order1=>'spx_total', cart1=>'ship.spx_total' },	 ## reserved for future use
	'sum/spy_total'=>{ sync=>1, format=>'intamt',order1=>'spx_total', cart1=>'ship.spy_total' },  ## reserved for future use
	'sum/spz_total'=>{ sync=>1, format=>'intamt',order1=>'spz_total', cart1=>'ship.spz_total' },  ## reserved for future use

	## these are set by internal methods but they are separate because they based on business logic and want/must settings.
	'sum/order_total'=>{ es=>"order_total", sync=>1, format=>'intamt',order1=>'order_total', cart1=>'data.order_total' },
	'sum/payments_total'=>{ sync=>1, format=>'intamt', order1=>'payments_total', cart1=>'data.payments_total' },
	'sum/balance_paid_total'=>{ compat=>'sum/balance_paid', sync=>1, format=>'intamt', order1=>'balance_paid', cart1=>'data.balance_paid' },
	'sum/balance_due_total'=>{ compat=>'sum/balance_due', sync=>1, format=>'intamt', order1=>'balance_due', cart1=>'data.balance_due' },
	'sum/balance_auth_total'=>{ compat=>'sum/balance_auth', sync=>1, format=>'intamt',order1=>'balance_auth', cart1=>'data.balance_auth' },
	'sum/balance_returned_total'=>{ compat=>'sum/balance_returned', sync=>1, format=>'intamt',order1=>'balance_auth', cart1=>'data.balance_auth' },

	## WANT settings are expected to be set by user, they can be overridden by a MUST setting
	'want/bnd_purchased'=>{ sync=>1, format=>"intbool", order1=>'bnd_purchased', cart1=>'ship.bnd_purchased' },
	'want/ins_purchased'=>{ sync=>1, format=>"intbool", order1=>'ins_purchased', cart1=>'ship.ins_purchased' },
	'want/is_giftorder' => { format=>"intbool",order1=>'is_giftorder' },
	'want/shipping_id' => { sync=>1, format=>"selector",cart1=>'ship.selected_id' },
	'want/order_notes'=>{ format=>"text",cart1=>'chkout.order_notes',order1=>'order_notes', },
	'want/po_number'=>{ es=>"po_number", format=>"text",order1=>'po_number', cart1=>'chkout.po_number' },
	'want/erefid'=>{ es=>"erefid", format=>"text", },
	'want/refer'=>{ public=>1, setifnb=>'cart/refer' },			## let the app tell us who the referrer should be -- record cart/refer on first refer
	'want/refer_src'=>{ public=>1, setifnb=>'cart/refer_src' },	

	## these may be settable by user, however if they are set in 'must' then those settings will be used.
	# 0 = do not create customer # 1 = prompt user to create a customer # 100 = user already has a customer
	'want/create_customer'=> { format=>"intbool", cart1=>'chkout.create_customer' },
	# bitwise field indicating which newsletters
	'want/email_update' => { format=>"intbw", cart1=>'chkout.email_update' },
	'want/new_password'=> { format=>"text", cart1=>'chkout.new_password' },
	'want/new_password2'=> { format=>"text", cart1=>'chkout.new_password2' },
	'want/recovery_hint'=> { format=>"integer", cart1=>'chkout.recovery_hint' },
	'want/recovery_answer'=> { format=>"text", cart1=>'chkout.recovery_answer' },
	'want/payby'=> { format=>"selector", cart1=>'chkout.payby' },
	'want/bill_to_ship'=> { format=>"intbool", cart1=>'chkout.bill_to_ship' },
	'want/shipping_residential'=> { format=>"intbool", cart1=>'chkout.shipping_residential' },
	'want/giftcard_number' => { cart1=>'chkout.giftcard_number' },
	'want/keepcart'=> { format=>"intbool" },

	## MUST settings will override any 'want' setting 
	'must/create_customer'=>{ sync=>1, },
	'must/bill_to_ship' => { sync=>1, order1=>'bill_to_ship' },
	'must/payby'=> { sync=>1 }, # set for example to PAYPALEC when PAYPALEC result is present

	## WILL is read only "will/" which basically checks must/* then want/*
	# 'will/payby'

	## these fields are linked to the customer record for an order.
	'customer/cid' => { order1=>'customer_id' },
	'customer/login' => { cart1=>'login' },
	'customer/pass' => { public=>0, cart1=>'login.pass' },
	'customer/login_gmt' => { cart1=>'login_gmt' },
	'customer/created_gmt' => { },	
	'customer/tax_id' => { order1=>'tax_id', cart1=>'chkout.tax_id' },	# why is this set by zpay?
	'customer/account_manager'=>{ order1=>'account_manager' },

	## these fields are intended to store payment info
	'payment/en'=> { cart1=>'payment.en' }, # echeck
	'payment/eb'=> { cart1=>'payment.eb' }, # echeck
	'payment/es'=> { cart1=>'payment.es' }, # echeck
	'payment/er'=> { cart1=>'payment.er' }, # echeck
	'payment/ea'=> { cart1=>'payment.ea' }, # echeck
	'payment/ei'=> { cart1=>'payment.ei' }, # echeck
	'payment/cc'=> { cart1=>'payment.cc' },
	'payment/mm'=> { cart1=>'payment.mm' },
	'payment/yy'=> { cart1=>'payment.yy' },
	'payment/cv'=> { cart1=>'payment.cv' },

	## finally there is 'app' space
	# 'app/xyz' for application specific extensions .. we may include a naming convention for business logic.
	##		app/memory_cart => products added to the cart - format: pid3,pid2,pid1, (where pid3 is the most recently visited)
	##		app/memory_visit => products viewed (product page)
	##		app/memory_category => safenames visited
	##
	'app/offered_freeship'=>{},
	'app/recent_category'=> { cart1=>'recent_category' },
	'app/add_event_count'=>{ cart1=>'cart.add_event_count' },
	'app/memory_cart'=>{ cart1=>'memory_cart' },
	'app/memory_visit'=>{ cart1=>'memory_visit' },
	'app/memory_navcat'=>{ cart1=>'memory_navcat' },
	'app/last_add_digest'=>{},	
	'app/recent_category_path'=>{ cart1=>'recent_category_path' }, # toynk whitelist
	'app/recent_category'=>{ cart1=>'recent_category' },
	'app/recent_category_tier1'=>{ cart1=>'recent_category_tier1' },	
	'app/recent_category_tier2'=>{ cart1=>'recent_category_tier2' },
	'app/recent_category_tier3'=>{ cart1=>'recent_category_tier3' },
	'app/status' => { cart1=>'status' },
	'app/attempts' => { cart1=>'attempts' },
	'app/payment-pi' => { cart1=>'payment-pi' },		## these were accidents should have been payment. (they can be ignored)
	'app/payment-pt' => { cart1=>'payment-pt' },		
	'app/giftcard' => { cart1=>'giftcard' },
	'app/bill_to_ship_cb' => { cart1=>'chkout.bill_to_ship_cb' },
	'app/info_newsletter' => {},
	'app/info_fullname' => {},
	'app/ship_date'=>{},
	'app/search_keywordlist'=>{},

	
	# COULD NOT LOOKUP LEGACY CART VALUE: data.ship_country [[hint: add an alias in %CART2::LEGACY_CART1_LOOKUP]]
	# COULD NOT LOOKUP LEGACY CART VALUE: data.bill_country [[hint: add an alias in %CART2::LEGACY_CART1_LOOKUP]]
	# COULD NOT LOOKUP LEGACY CART VALUE: chkout.bill_to_ship_cb [[hint: add an alias in %CART2::LEGACY_CART1_LOOKUP]]

	);



%CART2::LEGACY_CART1_LOOKUP = (	
	## this is populated full from the 'cart1' field above, and the for loop below.
	'specialtydomain'	=> 'app/specialtydomain',
	'SEARCH_KEYWORDLIST'		=> 'app/search_keywordlist',
	'cheese'	=> 'app/cheese',
	'customer::info.newsletter' => 'app/info_newsletter',
	'customer::info.fullname' => 'app/info_fullname',
	'search_keywordlist'		=> 'app/search_keywordlist',
	'recent_category_tier1' => 'app/recent_category_tier1',
	'recent_category_tier2' => 'app/recent_category_tier2',
	'recent_category'			=>	'app/recent_category',
	'login' 						=> 'customer/login',
	'id' 							=> 'cart/cartid',
	'schedule' 					=> 'our/schedule',
	'recent_category' 		=> 'app/recent_category',
	'data.total_weight' 		=> 'sum/pkg_weight',
	#'data.ship_country'		=> sub { return($_[0]->__GET__('ship/countrycode')); },
	#'data.bill_country'		=> sub { return($_[0]->__GET__('bill/countrycode')); },
	'data.ship_country'		=> 'ship/countrycode',
	'data.bill_country'		=> 'bill/countrycode',
	);

%CART2::LEGACY_ORDER1_LOOKUP = (
	'total_weight'	=> 'sum/pkg_weight',
	'ship_address' => '',
	'cod'=>'',
	'gfc_method'=>'',
	);

## populate both LEGACY LOOKUP hashes
foreach my $k (keys %CART2::VALID_FIELDS) {
	if (defined $CART2::VALID_FIELDS{$k}->{'cart1'}) {
		$CART2::LEGACY_CART1_LOOKUP{ $CART2::VALID_FIELDS{$k}->{'cart1'} } = $k;
		}
	if (defined $CART2::VALID_FIELDS{$k}->{'order1'}) {
		$CART2::LEGACY_ORDER1_LOOKUP{ $CART2::VALID_FIELDS{$k}->{'order1'} } = $k;
		}
	}


=pod

[[SECTION]]
## 
## NOW FOR THE COOL PART:
##
##  My expectation is in the future an app will be able to register/bind using zeromq or something similiar to
##	 to receive events when fields here change and be notified like zeromq.  The idea is that it could bind to everything
##	 a specific field, or an class(group/*) of fields on one specific object, or all objects.
##
##	this approach also provides us with an easy approach to adding multiple shipping addresses (by removing %ship to @ship)
##		or nesting %ship->{'id'}->{..} in the future 
##		which btw would probably also need to be paired with a %this->{id} and ultimately it's own sum->{'id'} and flow->{'id'}
##		no immediate plans .. but still, there's some interesting things.
##	also in a crowd-funding scenario there might be multiple bill addresses
##	in theory @payments, @events, @tracking are already ready for this type of modification in the future.
##
## these are some of the most likely scenarios in the future, and I think this order format really holds up well without
##	being needlessly complex.
##
[[/SECTION]]

=cut




## this is the current $::XCOMPAT level
sub v { return(222); }

sub is_readonly { my ($self) = @_; return( (defined $self->{'__READONLY__'}) ? 1 : 0); }
sub make_readonly { 
	my ($self) = @_; 
	$self->{'__READONLY__'} = &ZTOOLKIT::stripUnicode(sprintf("$$ [%s]",join("|",caller(0)))); 
	return($self); 
	}





##
## returns:
##		a count of actual VIRTUAL providers.
##		a hashref of STUFF keyed by zoovy:supplier field.
##		note: '' is returned
#sub fetch_virtualstuff {
#	my ($self) = @_;
#
#	my $count = 0;				# this will be the number of virtuals which are not equal to ""
#	my %VIRTUALSTUFF = ();	# this is a hash, key is the virtual "code", value is an arrayref of stuff items.
#	foreach my $item (@{$self->stuff2()->items()}) {
#
#		my $virtual = '';
#
#		if (not defined $item->{'%attribs'}) {}
#		elsif (not defined $item->{'%attribs'}->{'zoovy:virtual'}) {}
#		else { $virtual = $item->{'%attribs'}->{'zoovy:virtual'}; }
#		## SANITY: at this point $virtual is blank, or set to a valid value.
#
#		## make sure the $virtual value exists in %VIRTUALSTUFF
#		if (not defined $VIRTUALSTUFF{ $virtual }) { $VIRTUALSTUFF{$virtual} = (); }
#		push @{$VIRTUALSTUFF{$virtual}}, $item;
#		}
#
#	$count = scalar(keys %VIRTUALSTUFF);
#	if (defined $VIRTUALSTUFF{''}) { $count--; } # never count non-virtuals (normal products)
#
#	return($count,\%VIRTUALSTUFF);
#	}
#
sub has_supplychain_items {
	my ($self) = @_;

	my $count = 0;
	foreach my $item (@{$self->stuff2()->items()}) {
		next if ($item->{'is_promo'});
		my $virtual = undef;
		if (defined $item->{'virtual_ship'}) { $virtual = $item->{'virtual_ship'}; }
		if (defined $item->{'virtual'}) { $virtual = $item->{'virtual'}; }
		if ((not defined $virtual) || ($virtual eq '')) { $virtual = 'LOCAL'; }
		if ($virtual ne 'LOCAL') {
			$count++;
			}
		}
	return($count);
	}




##
## NOTE: this is a non OO method
##		called pretty much exclusively from ORDER.pm
##
#sub process_order {
#	my ($O2,$add_historyMsg) = @_;
#	my $INV2 = 
#	return($O2);
#	}








## converts a float to an int safely
## ex: perl -e 'print int(64.35*100);' == 6434  (notice the penny dropped)
## ex: perl -e 'print int(sprintf("%f",64.35*100));' == 6435
## ex: perl -e '$x = int(34.41*100); $y = int(34.43*100); $diff = ($y-$x); print "Diff: $diff\n";' # hint: it's 3!!
sub f2int { return(int(sprintf("%0f",$_[0]))); }

sub reduceyyyymm {
	my ($YYYY,$MM) = @_;

	$YYYY -= 2000;
	$YYYY = $YYYY << 4;
	$YYYY += $MM;

	$YYYY = &ZTOOLKIT::base36($YYYY);	
	return($YYYY);
	}




#sub paymentQshow {
#	my ($self, $filter, $value) = @_;
#
#	if (not defined $self->{'@PAYMENTQ'}) { $self->{'@PAYMENTQ'} = []; }
#	my @RESULT = ();
#	foreach my $payq (@{$self->{'@PAYMENTQ'}}) {
#		if ($filter eq 'tender') {
#			if ($payq->{'TN'} eq $value) {
#				push @RESULT, $payq;
#				}
#			}
#		else {
#			warn "UNKNOWN paymentQshow filter: $filter\n";
#			}
#		}
#	return(\@RESULT);
#	}
	


###########################################################################################
##
##	cmd is:
##		reset : clears payment queue
##		insert,delete  (self explanatory)
## 
##  different terms (and what they mean)
##		id => internal identifier used as a reference 
##		T$ => giftcard balance, max that can be charged 
##		$$ => requested amount to be charged (if 0 = then 'T$' is assumed) .. set by user
##		amountI => amount that will be charged (as integer) 
##
##  @PAYMENTQ internal format
##			[ id=>'', tender=>'', 'amountI'=>'', 'GC'=>, 'GI'=>'', 'CC'=>'', etc.. ],
##			[ id=>'', tender=>'', 'amountI'=>'', 'GC'=>, 'GI'=>'', 'CC'=>'', etc.. ],
##
sub paymentQ {
	my ($self, $payqref) = @_;

	if ($self->SESSION()) {
		## print STDERR "SESSION ROUTE!\n";
		return($self->{'@PAYMENTQ'} = $self->SESSION()->paymentQ($payqref));
		}
	else {
		## print STDERR "NON SESSION ROUTE!\n";
		if (not defined $self->{'@PAYMENTQ'}) { $self->{'@PAYMENTQ'} = []; }
		if (defined $payqref) { $self->{'@PAYMENTQ'} = $payqref; }
		return($self->{'@PAYMENTQ'});
		}
	}



###########################################################################################
##
##	surchargequeue are things like the shipping, tip, bonding, speciality fees.
##	 params
##		cmd[0]
##		id[1] : shp, hnd, spc, bnd, etc.
##		amount[2] : pass in decimal (but will be stored in integer format)
##		title[3] : 
##		taxable[4] : include in taxable total
##		required[5] : defaults 1, 0=optional, 1=required, 2=permanent (survives reset)
##				required[5] |=2 is typically used by marketplaces to make sure surcharges like tax/ins don't get removed.
##
sub surchargeQ {
	my ($self, $cmd, $id, $amount, $title, $taxable, $required) = @_;

	if (not defined $required) { $required = 1; }
	if (not defined $self->{'@SURCHARGEQ'}) { $self->{'@SURCHARGEQ'} = []; }

	foreach my $row (@{$self->{'@SURCHARGEQ'}}) {
		$self->__SET__( sprintf("sum/%s\_total",$row->[0]),	undef  );	# remove
		$self->__SET__( sprintf("sum/%s\_method",$row->[0]),	undef  );	# remove
		if (defined $CART2::VALID_FIELDS{ sprintf("is/%s\_taxable",$row->[0]) }) {
			## skip fields like is/tax_taxable
			$self->__SET__( sprintf("is/%s\_taxable",$row->[0]),		undef  );		# remove
			}
		if (defined $CART2::VALID_FIELDS{ sprintf("is/%s\_optional",$row->[0]) }) {
			## skip is/tax_optional??
			$self->__SET__( sprintf("is/%s\_optional",$row->[0]),	undef  );	# remove
			}
		if (defined $CART2::VALID_FIELDS{ sprintf("sum/%s\_quote",$row->[0]) }) {
			$self->__SET__( sprintf("sum/%s\_quote",$row->[0]),		undef  );		# remove
			}
		}

	my @ROWS = ();
	if ($cmd eq 'reset') {
		## lines that are $line[4]&2  are 'required' and will survive a reset unless 'add' or 'set' called to disable &2 bit
		foreach my $row (@{$self->{'@SURCHARGEQ'}}) {
			if (($row->[4]&2)==2) { push @ROWS, $row; }	## i must survive!
			}
		$self->{'@SURCHARGEQ'} = \@ROWS;
		$self->sync_action('surchargeQ_reset',"");
		#print 'AFTER RESET: '.Dumper($self->{'@SURCHARGEQ'});
		}
	elsif ($cmd eq 'remove') {
		my $found = 0;
		foreach my $row (@{$self->{'@SURCHARGEQ'}}) {
			if ($row->[0] ne $id) { push @ROWS, $row; } else { $found++; }
			}
		$self->{'@SURCHARGEQ'} = \@ROWS;
		if ($found) {
			$self->sync_action('surchargeQ_remove',"$id");
			}
		}
	elsif (($cmd eq 'add') || ($cmd eq 'set')) {
		#print 'ADD: '.Dumper($self->{'@SURCHARGEQ'});
		foreach my $row (@{$self->{'@SURCHARGEQ'}}) {
			# print 'ROW: '.Dumper($row);
			if ($row->[0] ne $id) { push @ROWS, $row; }
			}
		if ($title eq '') { $title = $CART2::VALID_FIELDS{ "sum/$id\_method" }->{'prompt'}; }
		push @ROWS, [ $id, &f2int($amount*100), $title, $taxable, $required ];
		$self->sync_action('surchargeQ_add',"$id $title $taxable $required");
		$self->{'@SURCHARGEQ'} = \@ROWS;
		#print 'AFTER ADD: '.Dumper(\@ROWS,$self->{'@SURCHARGEQ'});
		}
	elsif ($cmd eq 'sync') {
		## do nothing
		}
	else {
		warn "unknown surcharge cmd:$cmd\n";
		}

	##
	## set summary values
	##
	foreach my $row (@{$self->{'@SURCHARGEQ'}}) {
		$self->__SET__( sprintf("sum/%s\_method",$row->[0]),		sprintf("%s",$row->[2]) );
		if ($row->[0] eq 'tax') {
			## no, i will NOT set is/tax_taxable
			}
		else {
			$self->__SET__( sprintf("is/%s\_taxable",$row->[0]) ,		sprintf("%d",$row->[3]) );
			}
		if ( not defined $row->[4] ) { 
			warn "INTERNAL ERROR ON SURCHARGE ROW in COLUMN[4] -- UNDEFINED! ".join("!",$row)."\n";
			}
		elsif ($row->[4]==0) {
			## required = no/not specified (not optional)
			$self->__SET__( sprintf("is/%s\_optional",$row->[0]),	1  );	# remove
			$self->__SET__( sprintf("is/%s\_quote",$row->[0]),		sprintf("%.2f", $row->[1]/100) );		# remove
			if (not $self->__GET__( sprintf("want/%s\_purchased",	$row->[0]) )) {
				## optional + not purchased
				$self->__SET__( sprintf("sum/%s\_total",$row->[0]),0 );
				}
			else {
				## optional + purchased
				$self->__SET__( sprintf("sum/%s\_total",$row->[0]),sprintf("%.2f", $row->[1]/100) );
				}
			}
		elsif ( $row->[4] > 0 ) {
			## required: yes
			$self->__SET__( sprintf("sum/%s\_total",$row->[0]),	sprintf("%.2f", $row->[1]/100) ); # set to total
			}
		}
	return($self->{'@SURCHARGEQ'});
	}


##
## ex: has_surcharge('tax')
##		returns amountI
##
sub has_surcharge {
	my ($self, $id) = @_;
	my $result = undef;
	foreach my $line (@{$self->{'@SURCHARGEQ'}}) {
		if ($line->[0] eq $id) { $result = $line->[1]; last; }
		}
	return($result);
	}



##
## safely converts something like 'ship' (meaning group %ship) into a pushable, digestable set of strings.
##
sub hashref_to_digestables {
	my ($self, $group) = @_;

	my @DIGESTABLE = ();
	my $ref = $self->{"%$group"};
	if (defined $ref) {
		foreach my $k (sort keys %{$ref}) { 
			my $val = $ref->{$k};
			my $field = ($CART2::VALID_FIELDS{ "$group/$k" });

			if (not defined $field) {
				## ignore
				$val = undef;
				}
			elsif ((defined $field->{'digest'}) && ($field->{'digest'}==0)) {
				## do not include in digest
				$val = undef;
				}
			elsif ($field->{'format'} eq 'intamt') {
				$val = int($val);
				}
			elsif ($field->{'format'} eq 'weight') {
				$val = int($val);
				}
			elsif ($field->{'format'} eq 'intbool') {
				$val = int($val);
				}
			elsif ($field->{'format'} eq 'intbw') {
				$val = int($val);
				}
			elsif ($field->{'format'} eq 'integer') {
				$val = int($val);
				}
			else {
				## unknown type
				}
			
			if (defined $val) {
				push @DIGESTABLE, sprintf('%s/%s=%s',$group,$k,$val);  
				}
			}
		}
	else {
		push @DIGESTABLE, "$group=EMPTY"; 
		}
	return(@DIGESTABLE);
	}



=pod

[[SECTION]]

##########################################################################################
## 
## sub __SYNC__
##
## ..
## 	Any sufficiently advanced technology is indistinguishable from magic.  
##			-- Arthur C. Clarke
## ..
##
## if the object is like the WIZARD OF OZ, then __SYNC__ is our man behind the curtain, it 
## each time a in_set, pr_set, pu_se is called *AND* a value is changed that field 
##	is added to the @CHANGED (this is handy to inspect btw)
##	when a in_get, pr_get, or pu_get is set, then looks at @CHANGES and if there is 
##	anything there, then it will compute all internal values.
##
## any sub that relies on internal values MUST call __SYNC__ 
##	further it should **NEVER** be called directly .. or outside the object, doing so
##	is a contract violation and will be punishable by fines, and/or death at my 
## discretion.
##

[[/SECTION]]

=cut


##
## __INIT_TAX_RATES__ is intended to be used ONLY by __SYNC__ and possibly by some marketplacse
##		which may choose to override it's values.. but it'd be nice to setup things like tax_zone etc
##
sub __INIT_TAX_RATES__ {
	my ($self, %params) = @_;

	my $webdbref = $self->webdb();
	my %taxes = &ZSHIP::getTaxes($self->username(),$self->prt(),webdb=>$webdbref,
		city		=> $self->__GET__('ship/city'),
		state		=> $self->__GET__('ship/region'), 
		zip		=> $self->__GET__('ship/postal'), 
		country	=> $self->__GET__('ship/countrycode'), 
		address1	=> $self->__GET__('ship/address1'),
		);

	## this customer isn't taxable! just set the rates to zero.
	if ($self->__GET__('is/tax_exempt')) { %taxes = (); }

	$self->__SET__('is/shp_taxable', (($taxes{'tax_applyto'} & 2)==2)?1:0 );
	$self->__SET__('is/hnd_taxable', (($taxes{'tax_applyto'} & 4)==4)?1:0 );
	$self->__SET__('is/ins_taxable', (($taxes{'tax_applyto'} & 8)==8)?1:0 );
	$self->__SET__('is/spc_taxable', (($taxes{'tax_applyto'} & 16)==16)?1:0 );
	$self->__SET__('is/bnd_taxable', (($taxes{'tax_applyto'} & 32)==32)?1:0 );
	$self->__SET__('sum/tax_rate_state', $taxes{'state_rate'});
	$self->__SET__('sum/tax_rate_zone', $taxes{'local_rate'});
	$self->__SET__('our/tax_rate',$taxes{'state_rate'}+$taxes{'local_rate'});
	$self->__SET__('our/tax_zone',$taxes{'tax_zone'});
	return($self);
	}

sub __SYNC__ {
	my ($self, %params) = @_;

	if (not defined $self->{'@CHANGES'}) { $self->{'@CHANGES'} = []; }
	if (scalar(@{$self->{'@CHANGES'}})==0) {
		$CART2::DEBUG && warn "__SYNC__ was not needed, and therefore was not performed\n";
		return();
		}

	## LOOPBACK DETECTION -- this will prevent a SYNC from starting while a SYNC is running
	##								 ex. shipping which runs towards the bottom of a sync reads a lot of values about
	##								 order totals, addresses, shit like that.  this guarantees that anything 
	##								 __SYNC__ calls won't also turn around and trigger another __SYNC__
	if ($self->{'__SYNCING__'}) { return(); }
	$self->{'__SYNCING__'}++;

	if (&ZOOVY::servername() eq 'dev') {
		warn "SYNC CALLED: ".join("|",caller(1))."\n";
		$self->is_debug() && $self->msgs()->pooshmsg("INFO|+Using server 'DEV' rules");
		}
	my $webdbref = $self->webdb();

	## NOTE: we reset any surcharge fees *FIRST* in case they get added back by shipping (COD?), etc.
	$self->surchargeQ('reset');

	## calculate the effective tax rate for this order based on the zip code

	my $IS_TAX_FIXED = $self->__GET__('is/tax_fixed');

	## STUFF
	if (not $IS_TAX_FIXED) {
		$self->__SET__('sum/tax_total',undef);		## we'll recompute this
		}
	$self->__SET__('sum/order_total',undef);
	$self->__SET__('sum/items_total',undef);
	$self->__SET__('sum/items_count',undef);

	
	## SHIPPING
	# it should NOT be updated when insufficient shipping data is present (ex. no items)
	# so shipping is a VERY expensive call, and we should avoid calling it unless we need to.
	# if any ship/* field has changed then shipping needs to be updated.	
	# if any cart geometry has changed then it needs to be updated.

	#	## so if country is not blank, then we lookup the ISO code to compute tax.
	#	my $info = &ZSHIP::resolve_country(ZOOVY=>$country);
	#	$country = $info->{'ISO'};
	#	if ($country eq 'US') { $country = ''; }
	#	}
	if ($self->is_order()) {
		}
	elsif ($self->is_supplier_order()) {
		}
	elsif ($self->is_marketplace_order()) {
		}
	elsif ($self->is_cart()) {
		## we shoudl only set these fields for carts, not orders, because changings orders during a sync is a bad idea.
		$self->__SET__('sum/shp_carrier',undef);
		$self->__SET__('sum/shp_method',undef);
		$self->__SET__('cart/shipping_id',undef);
		$self->__SET__('sum/shp_total',undef);
		$self->__SET__('is/ins_optional', ($webdbref->{'ins_optional'})?1:0);
		}

	## shipping really benefits from some sane default values.
	## but really, we should always populate the country if we're going to set a zip, assuming the US is a bad idea.
	# if (length( $self->__GET__('%ship/countrycode') )==0) { $self->__SET__('%ship/countrycode','US'); }
	if ($self->__GET__('ship/countrycode') eq 'US') {
		## correct the zip code
		if ($self->__GET__('ship/postal') =~ m/^\d\d\d\d\d/) {
			## make sure we've got a well formatted zip.
			$self->__SET__('ship/postal',&ZSHIP::correct_zip($self->__GET__('ship/postal'),$self->__GET__('ship/countrycode')));
			## this line below is really key since a lot of people (aka beachmart) use rules that match off the state
			##	of course the customer only supplies a zip code and the merchant expects it to !@#$% work.
			if (not &ZTOOLKIT::isin(\@ZSHIP::STATE_CODES,$self->__GET__('ship/region'))) {
				## lookup+set the state
				$self->__SET__('ship/region', &ZSHIP::zip_state($self->__GET__('ship/postal')))
				}
			}
		}
	#if (not defined $self->__GET__('ship/countrycode')) {
	#	## lookup country code if we don't already have it!
	#	require ZSHIP;
	#	($self->__GET__('ship/countrycode')) = &ZSHIP::fetch_country_shipcodes($self->__GET__('ship/country'));
	#	}


	if (not defined $self->{'%digests'}) { $self->{'%digests'} = {}; }

	my @DIGESTABLE = ();
	push @DIGESTABLE, $self->hashref_to_digestables('ship');
	push @DIGESTABLE, $self->__GET__('want/shipping_id');
	foreach my $item (@{$self->stuff2()->items('')}) { push @DIGESTABLE, "$item->{'stid'}|$item->{'qty'}|$item->{'price'}|$item->{'weight'}"; }
	my $shipdigest = Digest::MD5::md5_base64(Encode::encode_utf8(join("|",@DIGESTABLE)));

	if ($self->is_order()) {
		}
	elsif ($self->is_supplier_order()) {
		## supply chain orders also have this data set implicitly.
		}
	elsif ($self->is_marketplace_order()) {
		## if we have a marketplace origin then we don't need to compute shipping and/or taxes 
		## because they'll be computed and added by the marketplace
		}
#	elsif (0) { #  ( int($self->fetch_property('chkout.force_shipping'))>0) {
#		#my @METHODS = ();
#		#push @METHODS, &ZSHIP::build_shipping_method(
#		#	$self->fetch_property('ship.selected_method'),
#		#	$self->fetch_property('ship.selected_price'),
#		#	'id'=>$self->fetch_property('ship.selected_id'),
#		#	'carrier'=>$self->fetch_property('ship.selected_carrier')
#		#	);
#		#$self->__SET__('@shipmethods',\@METHODS);
#		}
#	elsif (0) {
#		## reverse method, only use when receiving data from a trusted marketplace to create an order.
#		## this is *ONLY* used for google.
#		## used by ebay, google checkout, etc.
#		## juset set ship.selected_method, ship.selected_id, ship.selected_carrier, etc.
#		# $self->__SET__('ship.computed',0);
#		}
	elsif ( $self->stuff2()->count('show'=>'') == 0) {
		## EMPTY CART 
		$self->__SET__('sum/shp_method','Empty Cart');
		$self->__SET__('sum/shp_total',0);
		}
	elsif ($self->{'%digests'}->{'taxship'} eq $shipdigest) {
		## NOTHING CHANGED
		}
	else {
		## CART HAS CHANGED 

		## &1 == items are taxable!
		if ($self->__GET__('is/tax_fixed')) {
			## taxes are a fixed amount, so we shouldn't compute tax
			}
		else {
			$self->__INIT_TAX_RATES__();
			}

		## at this point all the taxes are figured out.
		warn "__SYNC__ IS ABOUT TO CALL SHIPMETHODS $$ ".join("|",caller(0))."\n";
		$self->shipmethods('tbd'=>1);
		}

	if (ref($self->stuff2()) eq 'STUFF2') {
		my ($stuff_results) = $self->stuff2()->sum({},'tax_rate'=>$self->__GET__('our/tax_rate'));
		# print STDERR Dumper($self->__GET__('our/tax_rate'),$stuff_results);

		foreach my $k (keys %{$stuff_results}) {
			next if ($k =~ /^legacy\_/);	# don't copy legacy_ fields
			## sum/items_total, sum/items_  sum/pkg_weight
			$self->__SET__( "sum/$k" , $stuff_results->{$k} );
			}
		}


	##
	## -- Okay: does our cgi.selected_method match our current ship.selected_method
	##	
	#if (($selected_id ne '') && ($selected_id ne $self->fetch_property('ship.selected_id'))) {
 	#   $self->save_property('ship.selected_id',$selected_id);          # set ship.selected_method
	#   $changed |= 8192;
 	#   }

	if ($self->is_order() || $self->is_supplier_order() || $self->is_marketplace_order()) {
		## orders need to manually update shipping, and set shipping_id, etc.
		## because we don't want them accidentally arbirarily changing without user/admin consent
		}
	elsif (($self->__GET__('want/shipping_id') eq '') && (scalar($self->{'@shipmethods'})==0)) {
		## we have not selected a shipping_id, and we have no @shipmethods .. so nothing to do here.
		}
	elsif (scalar($self->{'@shipmethods'})==0) {
		## there are no shipping methods available so, we'll leave want/shipping_id alone
		## $self->__SET__('want/shipping_id','');
		}
	elsif (scalar($self->{'@shipmethods'})>0) {
		## we have shipping methods
		## see if we need to reselect a shipping method because our previous one isn't available anymore
		my $selected_id = $self->__GET__('want/shipping_id');
		my $found = 0;
		foreach my $method (@{$self->{'@shipmethods'}}) { if ($method->{'id'} eq $selected_id) { $found++; } }
		## crap, our old shipping method doesn't exist anymore.
		$self->set_shipmethod( $found ? $selected_id : '' );	
		$self->{'%digests'}->{'taxship'} = $shipdigest;
		}
	else {
		## hmm.. not sure why/how this is reached (shipping not computed?) 
		}

	## NOTE: if 'want/shipping_id' is blank, then it means the user hasn't chosen a shipping method .. that does NOT
	## mean we don't default to one.


	## SPECIALITY FEES
	if ($self->is_order()) {
		}
	elsif (not defined $self->__GET__('want/payby')) {
		} 
	elsif (($self->__GET__('want/payby') eq 'COD') && (defined $webdbref->{'pay_cod_fee'}) && ($webdbref->{'pay_cod_fee'})) {
		$self->surchargeQ('add','spc',sprintf("%.2f",$webdbref->{'pay_cod_fee'}),'Surcharge for COD payment',1,1);
		}
	elsif (($self->__GET__('want/payby') eq 'CHKOD') && (defined $webdbref->{'pay_chkod_fee'}) && ($webdbref->{'pay_chkod_fee'})) {
		$self->surchargeQ('add','spc',sprintf("%.2f",$webdbref->{'pay_chkod_fee'}),'Surcharge for Check on Delivery',1,1);
		}
	elsif (($self->__GET__('want/payby') eq 'CHECK') && (defined $webdbref->{'pay_check_fee'}) && ($webdbref->{'pay_check_fee'})) {
		$self->surchargeQ('add','spc',sprintf("%.2f",$webdbref->{'pay_check_fee'}),'Surcharge for payment by Check',1,1);
		}
	elsif (($self->__GET__('want/payby') eq 'WIRE') && (defined $webdbref->{'pay_wire_fee'}) && ($webdbref->{'pay_wire_fee'})) {
		$self->surchargeQ('add','spc',sprintf("%.2f",$webdbref->{'pay_wire_fee'}),'Surcharge for payment by Wire Transfer',1,1);
		}


	##
	## simple marketplace promotions
	## calculate promotions
	##
	my $promotion_mode = 1;	 ## promotion_mode => 0 (disable), 1 (use default), 2 (alternate) PROMO-SID rules
	my $RULESET = 'PROMO';
	if ($self->is_marketplace_order()) {
		}
	elsif ($self->schedule() ne '') {
		require WHOLESALE;
		my ($S) = &WHOLESALE::load_schedule($self->username(),$self->schedule());
		if (defined $S) { 
			$promotion_mode = $S->{'promotion_mode'};
			## a schedule specific setting that tells us to ignore inventory
			$self->{'dev.inventory_ignore'} = int($S->{'inventory_ignore'});
			## commented out 200-10-27 by patti - fixes prob with wholesale schedules using store promotions
			#if ($promotion_mode==1) { $promotion_mode = 0; } ## huh? 1 is disable.. doh!
			if ($promotion_mode==2) { 
				# 2= use special schedule specific promotions
				$RULESET = 'PROMO-'.$S->{'SID'}; 
				}	
			}
		}



	##
	## NOTE: need to add chuck promotion code here and remove from ZSHIP::RULES::apply_discount_rules_stuff
	##			so that we can have multiple promotions in the cart.
	##

	## Advanced Discount Processing
	if ($self->is_order()) {
		## changes are locked.
		}
	elsif ($self->is_marketplace_order()) {
		## when this line is NOT present the amazon orders (for some 
		if (not defined $self->{'%coupons'}) { $self->{'%coupons'} = {}; }		## initialize coupons in cart
		}
	elsif ($promotion_mode==0) { 
		## promotion processing is turned off.
		}		
	else {
		my $ts = time();
		my ($webdbref) = $self->webdb();
		my @AUTO_COUPONS = ();
		if (not defined $self->{'%coupons'}) { $self->{'%coupons'} = {}; }		## initialize coupons in cart

		## FIRST - empty all promo items, that came from a coupon.
		my @PROMOSTIDS_WAS = ();
		foreach my $item (@{$self->stuff2()->items()}) {
			if ((substr($item->{'stid'}, 0, 1) eq '%') || ($item->{'is_promo'})) {
				push @PROMOSTIDS_WAS, $item->{'stid'};
				$self->stuff2()->drop('stid'=>$item->{'stid'});
				}
			}

		## AUTO COUPONS
		my $couponsref = $webdbref->{'%COUPONS'};
		if (not defined $couponsref) { $couponsref = {}; }
		foreach my $cpnref (values %{$couponsref}) {
			next if ($cpnref->{'auto'} == 0);		
			next if (($cpnref->{'begins_gmt'}>0) && ($cpnref->{'begins_gmt'}>$ts));		
			next if (($cpnref->{'expires_gmt'}>0) && ($cpnref->{'expires_gmt'}<$ts));	
			$cpnref->{'stackable'} = 1;		## yeah, don't let them fuck this up.

			if (not defined $cpnref->{'coupon'}) { $cpnref->{'coupon'} = $cpnref->{'id'}; }
			if (not defined $cpnref->{'coupon'}) { $cpnref->{'coupon'} = $cpnref->{'code'}; }

			push @AUTO_COUPONS, $cpnref;
			}

		## 
		## SO THE ISSUE WITH COUPONS IS ThAT THE ORDER TOTAL *MUST* BE RIGHT 
		## 

		$self->is_debug() && $self->msgs()->pooshmsg("INFO|+Processing %coupons");
		$self->{'ship.cpn_total'} = 0;
		my $count = -1;
	
		## NOTE: coupons *MUST BE* applied in alphanumeric order by code.
		my @CART_COUPONS = ();
		foreach my $code (sort keys %{$self->{'%coupons'}}) {
			next if ($code eq '');
			next if (not defined $self->{'%coupons'}->{$code});
	
			next if ($self->{'%coupons'}->{$code}->{'auto'});	
			push @CART_COUPONS,  $self->{'%coupons'}->{$code}
			}

#		$self->is_debug(0xFF);
#		print STDERR Dumper(\@CART_COUPONS, \@AUTO_COUPONS);
#		$self->msgs()->{'STDERR'}++;

		foreach my $CPNREF (@CART_COUPONS, @AUTO_COUPONS) {
			my $ID = $CPNREF->{'coupon'};
			if (not defined $ID) { $ID = $CPNREF->{'id'}; }

			$self->is_debug() && $self->msgs()->pooshmsg("INFO|+Processing COUPON:$ID");

#			print STDERR "COUPON: $ID\n";
			my $SKIP = 0;

			if (($CPNREF->{'begins_gmt'}>0) && ($CPNREF->{'begins_gmt'}>$ts)) {
				$self->stuff2()->drop('stid'=>'%'.$ID);
				delete $self->{'%coupons'}->{$ID};		# permanently remove the coupon!
				$SKIP++;
				}
			elsif (($CPNREF->{'expires_gmt'}>0) && ($CPNREF->{'expires_gmt'}<$ts)) {
				## coupon has expired while in the cart.
				$self->stuff2()->drop('stid'=>'%'.$ID);
				delete $self->{'%coupons'}->{$ID};		# permanently remove the coupon!
				$SKIP++;
				}
			
			if (not $SKIP) {
				## NOTE: apply_discount_rules_stuff drops all existing coupons.
				## my ($itemref) = &ZSHIP::RULES::apply_discount_rules_stuff($self, $RULESET, $CPNREF);
				## my $couponSKU = '%'.$CPNREF->{'id'};

				## NOTE: GROUPCODE is NOT USED YET .. but will be passed to items() to calculate totals within a group.
				my $STUFF2 = $self->stuff2();	

				my ($skucount, $char) = (0, 0, 0, 0);

				my $RULESET = uc('COUPON-'.$ID);
				my @rules = &ZSHIP::RULES::fetch_rules($self->webdbref(), $RULESET);

				my $FINISH = 0; ## Gets set to 1 if we stop rule processing
				my $rulemaxcount = scalar(@rules);
			
				if ($self->is_debug()) {
					# $self->pooshmsg("INFO|+debug($self->is_debug())<br>STUFF contents: <pre>".&ZOOVY::incode(Dumper($STUFF))."</pre>");
					# $self->pooshmsg("INFO|+debug($self->is_debug())<br>STUFF contents: <pre>".&ZOOVY::incode(Dumper(\@rules))."</pre>");
					$self->msgs()->pooshmsg("DEBUG|+apply_discount_rules is starting .. COUPON=$CPNREF->{'id'} RULESET=$RULESET ($rulemaxcount rules total)");	
					}
			
				# $self->pooshmsg(DDEBUG|+umper($CPNREF));
			
				# strip old discounts from the cart
				#if (defined $CPNREF) {
				if (not $CPNREF->{'stackable'}) {
					$self->msgs()->pooshmsg("DEBUG|+COUPON=$CPNREF->{'id'} is not stackable, removing other coupons.");	
					foreach my $item (@{$STUFF2->items()}) {
						if ((substr($item->{'stid'}, 0, 1) eq '%') || ($item->{'is_promo'})) {
							$self->msgs()->pooshmsg("DEBUG|+COUPON=$CPNREF->{'id'} removed $item->{'stid'}");	
							$STUFF2->drop('stid'=>$item->{'stid'});
							}
						}
					}
				else {
					$self->msgs()->pooshmsg("DEBUG|+COUPON=$CPNREF->{'id'} *IS* stackable, *LEAVING* other coupons.");	
					}
				#	}
				#else {
				#	$self->msgs()->pooshmsg("DEBUG|+NON-COUPON FOUND -- removing other promotional discounts and coupons.");	
				#	foreach my $item (@{$STUFF2->items()}) {
				#		if ((substr($item->{'stid'}, 0, 1) eq '%') || ($item->{'is_promo'})) {
				#			$STUFF2->drop('stid'=>$item->{'stid'});
				#			}
				#		}
				#	}
			
				if ($self->is_debug()) { print STDERR "\$rulemaxcount=$rulemaxcount\n"; }
				my $CODE = uc($CPNREF->{'id'});
				if ($CODE eq '') { $CODE = $CPNREF->{'code'}; }
				# print STDERR "CODE: $CODE\n";
			
				my $itemref = undef;
			  	for (my $counter=0; $counter < $rulemaxcount; $counter++) {
					my $rule = $rules[$counter];
					$rule->{'.line'} = $counter;
			
					if ($self->is_debug()) {
						foreach my $key (keys %{$rule}) {
							$self->msgs()->pooshmsg("DEBUG|+FILTERMATCH KEY: $key=".$rule->{$key});;
							}
						$self->msgs()->pooshmsg("DEBUG|+Rule[$counter] .. Trying [".$rule->{'NAME'}."] MATCH=[$rule->{'MATCH'}]\n"); 
						}
			
					my ($result) = $self->rulematch($rule,'*LM'=>$self->msgs());	
			
					my $DOACTION = $result->{'DOACTION'};
					if ($rule->{'EXEC'} eq 'GOGO') {
						if ($DOACTION eq 'GOGO') { 
							## we should GOGO (keep going) - since it was true, a GOGO 
							}
						else {
							## on a GOGO rule, if it's false, we need to STOP rule processing.
							if ($self->is_debug()) { $self->msgs()->pooshmsg("DEBUG|+Rule[$counter] .. found GOGO rule, in false position, changing to rule action to STOP\n"); }
							$DOACTION = 'STOP';
							}			
						}
			
			
					## At this point, if DOACTION is set - we do the action requested.
					if (not $DOACTION){
						if ($self->is_debug()) { $self->msgs()->pooshmsg("DEBUG|+Rule[$counter] .. NOT APPLIED!\n"); }
						}
					else {
					
						if ($self->is_debug()) { $self->msgs()->pooshmsg("DEBUG|+Rule[$counter] .. MATCHED! (ACTION IS: $DOACTION)\n"); }
						#my $CODE = $rule->{'CODE'};
						#if ($CODE eq '') { 
						#	$CODE = 'UBERPROMO'; 
						#	}
						#else {
						#	$CODE = uc($CODE);
						#	}
			
						$itemref = $STUFF2->item('stid'=>"%$CODE");
						if (not defined $itemref) {
							$itemref->{'stid'} = "%$CODE";
							$itemref->{'price'} = 0;
							$itemref->{'qty'} = 1;
							$itemref->{'weight'} = &ZTOOLKIT::gstr($rule->{'WEIGHT'}, 0);
							$itemref->{'force_qty'} = 1;
							$itemref->{'base_weight'} = 0;
							## coupon fields:
							if (not defined $CPNREF->{'taxable'}) { $CPNREF->{'taxable'} = 1; }
							$itemref->{'taxable'} = $CPNREF->{'taxable'};
							$itemref->{'description'} = $CPNREF->{'title'};
							my $img = $CPNREF->{'image'};
							if ((not defined $img) || ($img eq '')) { $img = ''; } 
							$itemref->{'%attribs'} = { 'zoovy:prod_thumb'=>$img, 'zoovy:prod_image1'=>$img, };
							}
						my $price = $itemref->{'price'};
			
						if ($DOACTION eq 'GOGO') {
							# GOGO rules are a little bizarre, because they become a STOP rule if it wasn't true.
							}
						elsif ($DOACTION eq 'STOP') {
							# 0 = disabled .. so we don't do anything
							$FINISH = 1; 
							$itemref = undef;
							}
						elsif (($DOACTION eq 'REMOVE') || ($DOACTION eq 'DISABLE')) {
							# 50 = disable (remove) this discount code
							if ($DOACTION eq 'DISABLE') { $FINISH++; }
							if ($self->is_debug()) {
								print STDERR "Removing discount code \%$rule->{'CODE'}\n";
								}
							$STUFF2->drop('stid'=>uc('%'.$rule->{'CODE'}));
							$itemref = undef;
							}
						elsif ($DOACTION eq 'SET') 	{
							# 51 means set discount to the following value (percentages are based on order total)
							my $v = $rule->{'VALUE'};
							if (index($v, '%') >= 0) { 
								# my ($subtotal, $totalweight, $totaltax, $totaltaxable, $itemcount) = $STUFF2->totals(0,1);
								my $subtotal = $STUFF2->sum({'show'=>'real'})->{'items_total'};
								if (not defined $subtotal) { warn "SHIPRULE 'SET' GOT UNDEF RESULT when requesting items_total\n"; }
								($v) = &ZOOVY::calc_modifier($subtotal, $v, 0);
								}
							else {
								# assume this is a dollar amount
								$v =~ s/[^\-\d.]//g;
								}
							$itemref->{'price'} = $v;
							}
						elsif ($DOACTION eq 'ADD*ONE') {
							# 52 means add discount to the following value, qty =1
							my $v = $rule->{'VALUE'};
							if (index($v, '%') >= 0) {
								# my ($subtotal, $totalweight, $totaltax, $totaltaxable, $itemcount) = $STUFF2->totals(0,1);
								my $subtotal = $STUFF2->sum({'show'=>'real'})->{'items_total'};
								if (not defined $subtotal) { warn "SHIPRULE 'ADD*ONE' GOT UNDEF RESULT when requesting items_total\n"; }
								($v) = &ZOOVY::calc_modifier($subtotal, $v, 0);
								}		
							$price += $v;
							$itemref->{'price'} = $price;
							}
						elsif ($DOACTION eq 'ADD*MATCHITEM') {
							## LEGACY 9/29/11
							# 53 means add discount to the following value for every matching ITEM, qty=1
							my $v = $rule->{'VALUE'};
							if (index($v, '%') >= 0) { 
								my ($itemtotal) = ($result->{'totalitem'}>0)?$result->{'totalitem'}:0;
								if ($result->{'matches'} <= 0) { $itemtotal = 0; }
								($v) = &ZOOVY::calc_modifier($itemtotal, $v, 0);
								$price += $v;
								}
							else	{
								my ($addprice, $pretty) = &ZOOVY::calc_modifier($price, $rule->{'VALUE'}, 0);
								$price += ($result->{'matches'} * $addprice);
								}
							$itemref->{'price'} = $price;
							}
						elsif ($DOACTION eq 'ADD*MATCHSKU') {
							## LEGACY 9/29/11
							# 54 means add discount to the following value for every matching sku, qty =1
							my $v = $rule->{'VALUE'};
							if (index($v, '%') >= 0) { 
								my ($skutotal) = ($result->{'matches'}>0)?$result->{'skutotal'}:0;
								if ($result->{'matches'}<=0) { $skutotal = 0; }
								($v) = &ZOOVY::calc_modifier($skutotal, $v, 0);
								$price += $v;
								}
							else {
								my ($addprice, $pretty) = &ZOOVY::calc_modifier($price, $rule->{'VALUE'}, 0);
								my ($qtymatch) = ($result->{'matches'}>0)?$result->{'qtymatch'}:0;
								$price += ($qtymatch * $addprice);
								}
							$itemref->{'price'} = $price;
							}
						elsif (($DOACTION eq 'ADD*MATCHITEMS') || ($DOACTION =~ /ADD\*MATCHITEMS[\d]+/)) {
							# 53 means add discount to the following value for every matching ITEM, qty=1
							my $DIVIDEBY = 1;
							if ($DOACTION =~ /ADD\*MATCHITEMS([\d]+)/) { $DIVIDEBY = int($1); }

							my $v = $rule->{'VALUE'};
							if (index($v, '%') >= 0) { 
								# 9/9/11 my ($itemtotal) = ($result->{'totalitem'}>0)?$result->{'totalitem'}:0;
								my ($totalitem) = ($result->{'matches'}>0)?$result->{'totalitem'}:0;
								$totalitem = int($totalitem / $DIVIDEBY); 
								if ($result->{'matches'} <= 0) { $totalitem = 0; }
								($v) = &ZOOVY::calc_modifier($totalitem, $v, 0);
								$price += $v;
								}
							else	{
								# 9/9/11 my ($addprice, $pretty) = &ZOOVY::calc_modifier($price, $rule->{'VALUE'}, 0);
								# 9/9/11 $price += ($result->{'matches'} * $addprice);
								my ($addprice, $pretty) = &ZOOVY::calc_modifier($price, $rule->{'VALUE'}, 0);
								my ($qtymatch) = ($result->{'matches'}>0)?$result->{'qtymatch'}:0;
								$qtymatch = int($qtymatch / $DIVIDEBY); 
								$price += ($qtymatch * $addprice);
								}
							$itemref->{'price'} = $price;
							}
						elsif ($DOACTION eq 'ADD*MATCHLINES') {
							# 54 means add discount to the following value for every matching sku, qty =1
							my $v = $rule->{'VALUE'};
							if (index($v, '%') >= 0) { 
								# 9/9/11 my ($totalsku) = ($result->{'matches'}>0)?$result->{'skutotal'}:0; # (key did not exist)
								my ($totalsku) = ($result->{'matches'}>0)?$result->{'totalsku'}:0;
								if ($result->{'matches'}<=0) { $totalsku = 0; }
								($v) = &ZOOVY::calc_modifier($totalsku, $v, 0);
								$price += $v;
								}
							else {
								my ($addprice, $pretty) = &ZOOVY::calc_modifier($price, $rule->{'VALUE'}, 0);
								$price += ($result->{'matches'} * $addprice);
								# 9/9/11 my ($addprice, $pretty) = &ZOOVY::calc_modifier($price, $rule->{'VALUE'}, 0);
								# 9/9/11 my ($qtymatch) = ($result->{'matches'}>0)?$result->{'qtymatch'}:0;
								# 9/9/11 $price += ($qtymatch * $addprice);
								}
							$itemref->{'price'} = $price;
							}
						elsif ($DOACTION eq 'ADD*ALLSKU') {
							# 55 means add discount to the following value for every sku (regardless if match)
							my ($addprice, $pretty) = &ZOOVY::calc_modifier($price, $rule->{'VALUE'});
							my $skucount = 0;
							foreach my $item (@{$STUFF2->items()}) {
								if ($item->{'stid'} !~ m/^(\%|\!)/) { $skucount++; }
								}
							$price += ($skucount * $addprice);
							$itemref->{'price'} = $price;
							}
						elsif ($DOACTION eq 'ADD*ALLITEMS')	{
							# 56 means add discount to the following for every item (regardless if match)
							my ($addprice, $pretty) = &ZOOVY::calc_modifier($price, $rule->{'VALUE'});
							# my ($subtotal, $totalweight, $totaltax, $totaltaxable, $itemcount) = $STUFF2->totals(0,1);
							my $itemcount = $STUFF2->sum({'show'=>'real'})->{'items_count'};
							if (not defined $itemcount) { warn "SHIPRULE 'ADD*ALLITEMS' GOT UNDEF RESULT when requesting items_count\n"; }
			
							$price += ($itemcount * $addprice);
							$itemref->{'price'} = $price;
							}
						elsif ($DOACTION eq 'ADD*EFFECTIVESUBTOTAL') {
							## this is specifically for cumulative discounts applied to the subtotal
							## e.g. 10000% coupon1=-5%, now $9500, coupon2=-5%, now 9025, coupon3=-5%, now 8573.3
							# my ($subtotal, $totalweight, $totaltax, $totaltaxable, $itemcount) = $STUFF2->totals(0,0);
							my $subtotal = $STUFF2->sum({'show'=>''})->{'items_total'};
							if (not defined $subtotal) { warn "SHIPRULE 'ADD*EFFECTIVESUBTOTAL' GOT UNDEF RESULT when requesting items_total\n"; }
			
							my ($addprice, $pretty) = &ZOOVY::calc_modifier($subtotal, $rule->{'VALUE'},0);
							$itemref->{'price'} = $price + $addprice;
							}
						elsif ($DOACTION eq 'SETQTY*MATCHSKU')	{
							# 60 means to set Discount Quantity equal to every matching SKU
							my ($skumatch) = ($result->{'matches'}>0)?$result->{'matches'}:0;
							my $v = $rule->{'VALUE'};
							if ($v ne '') { $price = $v; }
							$itemref->{'price'} = $price;
							$itemref->{'qty'} = $skumatch;
							}
						elsif (($DOACTION eq 'SETQTY*MATCHITEM') || ($DOACTION eq 'SETQTY*MATCHITEM2')) {
							# 61 means to set Discount Quantity equal to every matching ITEM
							my ($qtymatch) = ($result->{'matches'}>0)?$result->{'qtymatch'}:0;
							my $v = $rule->{'VALUE'};
							if ($v ne '') { $price = $v; }
							$itemref->{'price'} = $price;
							$itemref->{'qty'} = $qtymatch;
							if ($DOACTION eq 'SETQTY*MATCHITEM2') {
								$itemref->{'qty'} = int($qtymatch/2);
								}
							}
						elsif ($DOACTION eq 'SETQTY*ALLSKU') {
							# 62 means to set Discount Quantity equal to every SKU (regardless of match)
							my $skucount = 0;
							foreach my $item (@{$STUFF2->items()}) {
								if ($item->{'stid'} !~ m/^(\%|\!)/) { $skucount++; }
								}
							my $v = $rule->{'VALUE'};
							if ($v ne '') { $price = $v; }
							$itemref->{'price'} = $price;
							$itemref->{'qty'} = $skucount;
							}
						elsif ($DOACTION eq 'SETQTY*ALLITEMS') {
							# 63 means to set Discount Quantity equal to every ITEM (regardless of match)
							# my ($subtotal, $totalweight, $totaltax, $totaltaxable, $itemcount) = $STUFF2->totals(0,1);
							my $itemcount = $STUFF2->sum({'show'=>'real'})->{'items_count'};
							if (not defined $itemcount) { warn "SHIPRULE 'SETQTY*ALLITEMS' GOT UNDEF RESULT when requesting items_count\n"; }
			
							my $v = $rule->{'VALUE'};
							if ($v ne '') { $price = $v; }
							$itemref->{'price'} = $price;
							$itemref->{'qty'} = $itemcount;
							}
						elsif ($DOACTION =~ /MATCHADD\*(BOGO|B2GO|B3GO|MINUS0|MINUS1|MINUS2|MINUS3|ONLY1)/) {
							## minus one, two or three
							my $style = $1;
							my $prices = $result->{'%PRICES'};
							my $qtys = $result->{'%QUANTITIES'};
							my @series = ();		# an array, of arrayrefs [ stid, price ] .. one entry per qty.
							foreach my $stid (&ZTOOLKIT::value_sort($prices,'numerically')) {
								foreach my $count (1..$qtys->{$stid}) {
									push @series, [ $stid, $prices->{$stid} ];
									}
								}
			
			
							## at this point @series is built, it is in the format:
							##		(  [ stid1, 1.00 ], [stid1,1.00], [stid2,2.00], [stid3,3.00] )
							if (($style eq 'BOGO') || ($style eq 'B2GO') || ($style eq 'B3GO')) {
								my @bogos = ();
								my $i = 0;
								## @series = A=5,B=3,B=3,C=1,D=0.50
								#use Data::Dumper;
								#print STDERR Dumper(@series);
								foreach my $set (reverse @series) {
									## remember, we're going in reverse order (most expensive to least)
									if (($style eq 'BOGO') && (($i%2)==1)) { push @bogos, $set; }
									if (($style eq 'B2GO') && (($i%3)==2)) { push @bogos, $set; }
									if (($style eq 'B3GO') && (($i%4)==3)) { push @bogos, $set; }
									$i++;
									}
								## @bogos = B=3,C=1
								@series = @bogos;
								}
							elsif ($style =~ /^MINUS([\d]+)$/) {
								## SUBTOTAL THE MOST EXPENSIVE ITEMS EXCEPT THE FIRST 'N'
								my ($minus) = int($1);
								## now we remove the leading N values .. first we must reverse!
								@series = reverse @series;
								@series = splice(@series,$minus); 
								}
							elsif ($style =~ /^ONLY([\d]+)$/) {
								## SUBTOTAL THE MOST EXPENSIVE 'N' ITEMS
								@series = reverse @series;
								my ($include) = int($1);
								## now we remove the leading N values .. since we only
								if ($self->is_debug()) { $self->msgs()->pooshmsg("DEBUG|+".sprintf("Rule[$counter] .. $style -- series was: %s\n",Dumper(\@series))); }
								@series = splice(@series,0,$include); 
								if ($self->is_debug()) { $self->msgs()->pooshmsg("DEBUG|+".Dumper(\@series)); }
								}
			
							my $matchtotal = 0;
							if ($self->is_debug()) { $self->msgs()->pooshmsg("DEBUG|+".sprintf("Rule[$counter] .. recomputing matchtotal based on new series ")); }
							foreach my $s (@series) {
								$matchtotal += $s->[1];
								if ($self->is_debug()) { $self->msgs()->pooshmsg("DEBUG|+".sprintf("Rule[$counter] .. item: %s = %0.2f  [matchtotal:%0.2f]",$s->[0],$s->[1],$matchtotal)); }
								}
							if ($self->is_debug()) { 
								$self->msgs()->pooshmsg("DEBUG|+".sprintf("Rule[$counter] .. matchtotal recomputed to: %0.2f",$matchtotal)); 
								}
			
			
							my $v = 0;
							if ($matchtotal>0) {
								($v) = &ZOOVY::calc_modifier($matchtotal, $rule->{'VALUE'}, 0);
								if ($self->is_debug()) { $self->msgs()->pooshmsg("DEBUG|+Rule[$counter] $DOACTION calc_modifier($matchtotal, $rule->{'VALUE'}) set price=$v"); }
								}
							else {
								if ($self->is_debug()) { $self->msgs()->pooshmsg("DEBUG|+Rule[$counter] $DOACTION calc_modifier was not run because matchtotal=$matchtotal (must be positive)"); }
								}
			
							$itemref->{'price'} = $v;
							$itemref->{'qty'} = 1;
							}
						else {
							# if ($self->is_debug()) { $self->msgs()->pooshmsg("DEBUG|+".sprintf("Rule[$counter] .. $style -- series is: %s\n",join(",",@series))); }
							warn "Unknown DOACTION: $DOACTION\n";
							}
			
						if (defined $itemref) {
							my $img		 = $rule->{'IMAGE'};
							if ((not defined $img) || ($img eq '')) { $img = ''; } 
							if ($img ne '') {
								$itemref->{'%attribs'} = { 'zoovy:prod_image1'=>$img, };
								}
							$STUFF2->promo_cram($CODE,$itemref->{'qty'},$itemref->{'price'},$itemref->{'description'},%{$itemref});
							}
						} 
			
					if ($FINISH) {
						if ($self->is_debug()) {
							$self->msgs()->pooshmsg("DEBUG|+rule[$counter] halted rule execution cart items:".join(',',$STUFF2->stids()));	
							}
						$counter = $rulemaxcount; 
						#print STDERR "FINISH was true, setting counter (was $counter) to rulemaxcount ($rulemaxcount)\n";
						}
			
					}
				undef @rules;
			
				# $CART2->msgs()->pooshmsg("DEBUG|+end items:".Dumper($STUFF));
			
				if (defined $itemref) {
					$self->stuff2()->promo_cram($itemref->{'stid'},$itemref->{'qty'},$itemref->{'price'},$itemref->{'description'},%{$itemref});
					}
				}

			$self->is_debug() && $self->msgs()->pooshmsg("INFO|+Finished COUPON:$ID");
			## end of foreach loop.
			}

		# open F, ">/tmp/step2"; print F Dumper($self); close F;
		## we'll need to update the items total because the items may have changed.
		my ($sumresult) = $self->stuff2()->sum({});
		$self->__SET__('sum/items_total',$sumresult->{'items_total'});
		$self->is_debug() && $self->msgs()->pooshmsg("INFO|+Finished %coupons");

		my @PROMOSTIDS_NOW = ();
		foreach my $item (@{$self->stuff2()->items()}) {
			if ((substr($item->{'stid'}, 0, 1) eq '%') || ($item->{'is_promo'})) {
				push @PROMOSTIDS_NOW, $item->{'stid'};
				}
			}

		## now compare @PROMOS_WAS and @PROMOS_ISNOW
		my $promos_was = join("|",sort @PROMOSTIDS_WAS);
		my $promos_isnow = join("|",sort @PROMOSTIDS_NOW);
		## print STDERR "PROMO_WAS:$promos_was PROMO_NOW:$promos_isnow\n";
		if ($promos_was ne $promos_isnow) {
			## alright so our promotions/coupons have changed, we *might* need to recompute shipping here.
			warn "cart geometry has changed due to promotions, re-running shipping\n";
			$self->shipmethods('__SYNC__'=>1);
			}
		}


	## I don't think anybody is actually using this anymore.
	#	## API Shipping  -- used be golfswingtrainer.
	#	my $adv = def($webdbref->{'dev_promotionapi2_url'});
	#	if (($promotion_mode>0) && (length($adv) > 10)) {
	#		require CART::PROMOTIONAPI;
	#		## backward compatibility
	#		my %shipinfo = ();
	#
	#		my $shipinfo_update = &CART::PROMOTIONAPI::update_stuff(
	#			$self->username(),
	#			$self,
	#			);
	#		}

	
	##
	## NOTE: at this point sum/order_total must be correct
	##
	my $tax_totalI = 0;
	if (($self->is_marketplace_order()) && (defined $self->has_surcharge('tax'))) {
		## some (most) marketplaces pass us the tax and if they do that, then we don't compute our own
		$self->__SET__('sum/tax_total',sprintf("%.2f",$self->has_surcharge('tax')/100));
		$self->__SET__('is/tax_fixed',1);
		}
	elsif ($self->__GET__('is/tax_fixed')) {
		## tax is a fixed amount, so we don't modify that!
		}
	else {
		$tax_totalI += &f2int($self->__GET__('sum/items_taxdue')*100); # TAX ON SUBTOTAL
		foreach my $surcharge ('shp','ins','hnd','spc','spx','spy','spz','bnd','pay') {
			## hmm, until the tax line can be rendered as part of the specialty specs we're kinda stuck.
			my $amount = $self->__GET__(sprintf('sum/%s_total',$surcharge));
			if ($surcharge eq 'gfc') {
				## giftcards are never taxable
				}
			elsif ( ($amount>0) && $self->__GET__(sprintf('sum/%s_taxdue',$surcharge)) ) {
				## taxdue is a fixed amount - if it's set, we'll use that.
				$tax_totalI += &f2int(  $self->__GET__(sprintf('sum/%s_taxdue',$surcharge)) * 100);
				}
			elsif ( ($amount>0) && $self->__GET__(sprintf('is/%s_taxable',$surcharge)) ) {
				## otherwise we check the is/fee_taxable field and compute the tax
				$tax_totalI += sprintf("%d",($amount * ($self->__GET__('our/tax_rate')/100) * 100));
				}
			}
		$self->__SET__('sum/tax_total',sprintf("%.2f",$tax_totalI/100));
		}

	#$self->{'chkout.giftcard_count'} = $count;
	#$self->{'ch	kout.giftcard_total'} = $total;

	## at this point we can figure out order total - yay!
	my $order_totalI = 0;
	$order_totalI += &f2int($self->__GET__('sum/items_total')*100);	# SUBTOTAL
	$order_totalI += &f2int($self->__GET__('sum/shp_total')*100);	# SHIPPING
	$order_totalI += &f2int($self->__GET__('sum/tax_total')*100);		# TAX
	$order_totalI += &f2int($self->__GET__('sum/ins_total')*100);		# INSURANCE
	$order_totalI += &f2int($self->__GET__('sum/hnd_total')*100);		# HANDLING
	$order_totalI += &f2int($self->__GET__('sum/spc_total')*100);		# SPECIALTY
	$order_totalI += &f2int($self->__GET__('sum/bnd_total')*100);		# BONDING
	$self->__SET__('sum/order_total', sprintf("%.2f",$order_totalI/100) );

	
	## PAYMENTS
	## 	GIFTCARDS! (eventually we might actually want to reload the actual card balances!)

	## GIFTCARDS
	$self->__SET__('sum/gfc_total',undef);			# total we're using
	$self->__SET__('sum/gfc_available', undef);	# total we *COULD* spend
	$self->__SET__('sum/gfc_method', undef);
	$self->__SET__('is/gfc_taxable', undef);
	$self->__SET__('sum/pnt_total',undef);			# total we're using
	$self->__SET__('sum/pnt_available', undef);	# total we *COULD* spend
	$self->__SET__('sum/pnt_method', undef);
	$self->__SET__('is/pnt_taxable', undef);
	$self->__SET__('flow/payment_status',undef);
	$self->__SET__('flow/payment_method',undef);
	$self->__SET__('sum/balance_paid_total',undef);
	$self->__SET__('sum/balance_auth_total',undef);
	$self->__SET__('sum/balance_returned_total',undef);
	# $self->__SET__('our/flags',undef); 	# don't initialize flags to zero or we'll lose bit 9
	
	if ($self->is_order() || $self->__GET__('sum/items_total')) {
		
		my $tax_rate = $self->__GET__('our/tax_rate');
		# my $tax_total_i = &f2int($self->__GET__('this/tax_total')*100);
		my $tax_subtotal_i = &f2int($self->__GET__('sum/items_total')*100);
		my $order_total_i = &f2int($self->__GET__('sum/order_total')*100);

		## NOTE: it seems like amazon truncates/doesn't round the sales tax (invalid) not sure.
		## NOTE: we need to do a sprintf("%0.0f") here so it rounds properly (ex: 622.75 becomes 623)
		my $take_a_penny_leave_a_penny = 0;
		my $tax_total_i = &f2int(sprintf("%0.0f",$self->__GET__('sum/items_total') * ($tax_rate/100)));
		if (&f2int($tax_subtotal_i * ($tax_rate/100))+1 == $tax_total_i) {
			## sometimes we find cases where tax rounding didn't occur (ex. at the marketplace level)
			## so we institute take_a_penny_leave_a_penny mode which allows totals within 0.01 to match as paid.
			$take_a_penny_leave_a_penny++; 
			}
		# $order_total_i += $tax_total_i;
		# print "TAX: $order_total_i tax_subtotal:$tax_subtotal_i tax_total:$tax_total_i rate:$tax_rate\n";

		##
		## run through the payments to recompute any balances
		##
		my $balance_paid_i = 0;
		my $balance_authorized_i = 0;
		my $balance_returned_i = 0;
	
		my $payment_method = undef;
		my $payment_status = undef;

		my %paymentuuids = ();		# hashref keyed by uuid of payments, value is payment hashref
		my @originpayments = ();	# an array of origin payments hashrefs
		my %chaineduuids = ();		# hashref keyed by puuid, value is an array of uuids (for each chained payment)

		if (not defined $self->{'@PAYMENTS'}) { $self->{'@PAYMENTS'} = []; }
		foreach my $payment (@{$self->{'@PAYMENTS'}}) {
			# next if (ref($payment) ne 'HASH');
			if (not defined $payment->{'amt'}) { $payment->{'amt'} = 0; }
			if (not defined $payment->{'puuid'}) { $payment->{'puuid'} = ''; }
	
			## uuid should only be allowed to have A-Z 0-9 and -
			if (length($payment->{'uuid'})>32) {
				## things over 32 characters are invalid. fuck, leave them alone.
				## becky will fix in future release (version 12) then we can upgrade everybody that has them.
				}
			else {
				$payment->{'uuid'} = uc($payment->{'uuid'});
				$payment->{'uuid'} =~ s/[^A-Z0-9\-]/\-/g;
				$payment->{'uuid'} = substr($payment->{'uuid'},0,32);	# limit of 32 characters for uuid
				}
	
			## set payment method to either the tender type or "MIXED"
			if ($payment->{'voided'}) {}
			elsif (not defined $payment_method) { $payment_method = $payment->{'tender'}; }
			elsif ($payment_method ne $payment->{'tender'}) { $payment_method = 'MIXED'; }

			## look at the payment status of each payment to figure out what we should do.
			$paymentuuids{$payment->{'uuid'}} = $payment;
			if ($payment->{'puuid'} eq '') {
				## this is an origin payment
				push @originpayments, $payment;
				}
			else {
				## this is a chained payment (tied to a origin payment by puuid)
				push @{$chaineduuids{ $payment->{'puuid'} }}, $payment->{'uuid'};
				}
			}
		if (not defined $payment_method) { $payment_method = 'NONE'; }

		## now we go through each origin payment and look at any chained payments to compute
		## the final c_amt, c_ps
		foreach my $payment (@originpayments) {
			my $this_txn_paid_i = 0;
			my $this_txn_ps = undef;
			if ($payment->{'voided'}) {
				## doesn't count anymore!
				}
			elsif ((substr($payment->{'ps'},0,1) eq '0') || (substr($payment->{'ps'},0,1) eq '4')) {
				## capture/paid
				# print "$payment->{'amt'}\n";
				$balance_paid_i += &f2int($payment->{'amt'}*100);
				# print "$payment->{'amt'} $balance_paid_i\n";
				$this_txn_paid_i += &f2int($payment->{'amt'}*100);
				# print "THIS: $this_txn_paid_i\n";
				}
			elsif (substr($payment->{'ps'},0,1) eq '1') {
				## auth only
				$balance_authorized_i += &f2int($payment->{'amt'}*100);
				}
			elsif (substr($payment->{'ps'},0,1) eq '3') {
				## credit
				$balance_paid_i -= &f2int($payment->{'amt'}*100);
				$this_txn_paid_i -= &f2int($payment->{'amt'}*100);
				$balance_returned_i += &f2int($payment->{'amt'}*100);
				}
			elsif (substr($payment->{'ps'},0,1) eq '6') {
				## void!
				$payment = undef;
				}
		
			next if (not defined $payment);
			$this_txn_ps = $payment->{'ps'};

			if (defined $chaineduuids{ $payment->{'uuid'} }) {
				## already we have one or more chained uuids
				foreach my $chaineduuid ( @{$chaineduuids{ $payment->{'uuid'} }} ) {
					my $chainpayment = $paymentuuids{$chaineduuid};
					my $ignore = 0;
					if ($payment->{'voided'}) {
						## the parent was voided, then this doesn't count anymore
						}
					elsif ((substr($chainpayment->{'ps'},0,1) eq '0') || (substr($chainpayment->{'ps'},0,1) eq '4')) {
						$balance_paid_i += &f2int($chainpayment->{'amt'}*100);
						$this_txn_paid_i += &f2int($chainpayment->{'amt'}*100);
						}
					elsif (substr($chainpayment->{'ps'},0,1) eq '1') {
						$balance_authorized_i += &f2int($chainpayment->{'amt'}*100);
						}
					elsif (substr($chainpayment->{'ps'},0,1) eq '2') {
						## ignore chained failures (they should never be the final status for the order!)
						$ignore++;
						}
					elsif (substr($chainpayment->{'ps'},0,1) eq '3') {
						$balance_paid_i -= &f2int($chainpayment->{'amt'}*100);
						$this_txn_paid_i -= &f2int($chainpayment->{'amt'}*100);
						$balance_returned_i += &f2int($chainpayment->{'amt'}*100);
						}			
					if (not $ignore) {
						$this_txn_ps = $chainpayment->{'ps'};
						}
					}
				}
			$payment->{'c_amt'} = sprintf("%d",$this_txn_paid_i);	# the chained result amount
			$payment->{'c_ps'} = $this_txn_ps;		# the chained result payment status (last result)
			if ( ($payment->{'c_ps'} ne $payment->{'ps'}) && ($this_txn_paid_i>0) ) {	
				# note: even though c_ps != $ps but this this_txn_paid has an >0 
				# which means it's got SOME positive PAID amount, so even if it's not enough for the whole order
				# it's still should count as a paid transaction - this is often the case where we've got a credit
				# card transaction, and then a subsequent (partial) credit, we'd want to keep the 001 or 002 instead
				# of keep the 303 (for example) because it's paid, just partially.
				$payment->{'c_ps'} = $payment->{'ps'};
				}
			}

		## we can't store these numbers as floating point because they run into precision issues on == < and >
		## so we *100 and then int, and then we divide them back down later at the end.
		# print "ORDER_TOTAL_I: $order_total_i\n";
		# print STDERR "ORDER_TOTAL: $order_total balance_paid:$balance_paid\n";

		## @updates is an internal list of things that have changed.
		my $balance_due_i = &f2int($order_total_i - $balance_paid_i);

		if (($balance_due_i == 1) && ($take_a_penny_leave_a_penny)) {
			## take_a_penny_leave_a_penny occurs in strange rounding cases with tax or other things
			## which used to be ignored, but now aren't anymore.
			$balance_due_i = 0;
			$balance_paid_i = $order_total_i;
			}

		## now go through and try to figure out the final payment status for the order
		if (scalar(@originpayments)==0) {
			## there are no payments on this order
			if (($order_total_i == 0) && ($self->__GET__('sum/items_count')>0)) {
				## NOTE: the check for items.count>0 is necessary so we don't dispatch new orders with no items as paid.
				$payment_method = 'ZERO';
				$payment_status = '009';
				}
			else {
				$payment_status = '902';
				}
			}
		elsif ($balance_paid_i==$order_total_i) {
			## paid (but not overpaid) orders, 
			foreach my $payment (@originpayments) {
				if ($payment->{'c_amt'}<=0) {}	# don't count payments where the calculate amount is less than zero
				elsif (not defined $payment_status) { $payment_status = $payment->{'c_ps'}; }	# first paid method, lets use this
				elsif ($payment_status eq $payment->{'c_ps'}) { }	# yay, this method the same as the last one.
				else { $payment_status = '090'; };	# shit, multiple types exist!
				}	
			if ((not defined $payment_status) && ($order_total_i==0)) {
				## zero dollar order! wtf!?
				$payment_status = '009';
				}
			}	
		elsif ($balance_authorized_i >= $order_total_i) {
			## so, if the order is authorized for the full amount or more, then that's fine too.
			foreach my $payment (@originpayments) {
				if ($payment->{'voided'}) {}
				elsif (substr($payment->{'ps'},0,1) ne '1') {}	# not an authorization
				elsif (not defined $payment_status) { $payment_status = $payment->{'ps'}; } # first auth, assume this is ps
				elsif ($payment_status eq $payment->{'ps'}) {}	# leave it alone
				else { $payment_status = '190'; };	# ugh, multiple types of 'ps' so set order to 190
				}	
			}
		elsif (($balance_paid_i < $order_total_i) && ($balance_paid_i>0) && ($balance_due_i>0)) {
			# print "(($balance_paid < $order_total) && ($balance_paid>0))\n";
			$payment_status = '904';	# insufficient funds were supplied by user (wtf? how did this happen!)
			}
		elsif (scalar(@{$self->{'@PAYMENTS'}})==1) {
			## we only have one payment (whew) so we'll use it's payment status.
			$payment_status = $self->{'@PAYMENTS'}->[0]->{'ps'};
			}
		elsif (($balance_paid_i == 0) && ($balance_authorized_i==0) && ($order_total_i>0)) {
			## so nothing has been paid, it's probably a void or something like that.
			my $was_not_voidorfail = 0;
			my $how_many_denied = 0;	 # tracks how many of the origin payments were denied!
			my $how_many_returned = 0;	 # tracks how many of the origin payments were returned.
			my $ps = undef;
			foreach my $payment (@originpayments) {
				if (($payment->{'voided'}) && (substr($payment->{'c_ps'},0,1) eq '6')) { $ps = $payment->{'c_ps'}; }
				elsif ($payment->{'voided'}) { $ps = '699'; }
				elsif ($payment->{'c_amt'}==0) { $ps = '390'; }	# one or more payment methods returned (or failure)
				else { $was_not_voidorfail++; }
				if (substr($payment->{'c_ps'},0,1) eq '2') { $how_many_denied++; }
				if (substr($payment->{'c_ps'},0,1) eq '3') { $how_many_returned++; }
				}
			if ($was_not_voidorfail) {
				## at least one of the payments was not a void, or credit, but yet we're here wtf!?
				$payment_status = 990;
				}
			elsif (scalar(@originpayments)==1) {
				## note: we should never get here if there is only one payment on the order! (but we would if there was only one origin!)
				$payment_status = $ps;
				}
			elsif (scalar(@originpayments)==$how_many_denied) {
				## all the payments on the order were denied! 
				$payment_status = '290'; # multiple attempts to correct failure.
				}
			elsif ($how_many_returned>0) {
				$payment_status = '390'; # one or more payment methods returned
				}
			else {
				$payment_status = '990'; # unknown payment status.
				}
			}
		else {
			## unable to determine payment status
			#print STDERR "balance_due_i: $balance_due_i\n";
			#print STDERR "balance_paid_i: $balance_paid_i\n";
			#print STDERR "balance_authorized_i: $balance_authorized_i\n";
			#print STDERR "order_total_i: $order_total_i\n";
			$payment_status = '990';
			# $data->{'990_reason'} = "balance_paid:$balance_paid order_total:$order_total";
			}


		if (1) {
			## INVENTORY DETAIL PROCESSING
			my ($INV2) = INVENTORY2->new($self->username(),"*paid");
			my $NEEDS_PROCESS = 0;
			foreach my $LINEREF (values %{$self->invdetail()}) {
				## print STDERR 'LINEREF'.Dumper($LINEREF)."\n";
				if ($LINEREF->{'BASETYPE'} eq 'UNPAID') {
					$INV2->orderinvcmd($self,$LINEREF->{'UUID'},"ITEM-PAID");
					$LINEREF->{'BASETYPE'} = 'PICK';
					$LINEREF->{'PICK_ROUTE'} = 'NEW';
					}
				if (($LINEREF->{'BASETYPE'} eq 'PICK') && ($LINEREF->{'PICK_ROUTE'} eq 'NEW')) {
					$NEEDS_PROCESS++;
					}
				}
			if ($NEEDS_PROCESS) {
				$INV2->process_order($self);
				}
			if ($INV2->needs_sync()) { 
				$INV2->sync(); 
				}
			}

		# print "ORDER: $order_total BALANCE: $balance_due\n";
		if (not defined $self->__GET__('flow/paid_ts')) { $self->__SET__('flow/paid_ts', 0); }
	
		if (not defined $self->__GET__('flow/payment_status')) {
			push @{$self->{'@updates'}}, ['flow/payment_status',$payment_status,'recalc payment_status initialized'];
			}
		elsif ($self->__GET__('flow/payment_status') ne $payment_status) {
			push @{$self->{'@updates'}}, ['flow/payment_status',$payment_status,'recalc payment_status changed'];
			}
		elsif (($self->__GET__('flow/paid_ts')==0) && ($balance_due_i == 0)) {
			push @{$self->{'@updates'}}, ['flow/payment_status',$payment_status,'recalc detected paid_ts was not set on balance_due'];
			}
		elsif ($self->__GET__('flow/paid_ts')>0) {
			## order is paid, make sure we have a payment event otherwise we run paid
			my $found_paid_event = 0;
			foreach my $d (@{$self->{'@ACTIONS'}}) {
				if ($d->[0] eq 'paid') { $found_paid_event++; }
				}


			if (not $found_paid_event) {
				$self->queue_event('paid');
				push @{$self->{'@updates'}}, ['payment_status',$payment_status,'no paid event found'];
				}
			}
	
		if (($payment_method eq 'MIXED') && (substr($payment_status,0,1) eq '0')) {
			## if we have a 'MIXED' payment method on a PAID (0xx) order, then we will attempt to go through
			## and ONLY look at paid payment methods (so anything that isn't paid, is ignored as part of the payment)
			$payment_method = undef;
			foreach my $payment (@{$self->{'@PAYMENTS'}}) {
				next if ($payment->{'puuid'} ne '');
	
				## set payment method to either the tender type or "MIXED"
				if ($payment->{'voided'}) {}
				elsif (substr($payment->{'ps'},0,1) ne '0') {}
				elsif (not defined $payment_method) { $payment_method = $payment->{'tender'}; }
				elsif ($payment_method ne $payment->{'tender'}) { $payment_method = 'MIXED'; }
				}
			if (not defined $payment_method) { $payment_method = 'MIXED'; }
			}


		my $FLAGS = (defined $self->__GET__('our/flags'))?int($self->__GET__('our/flags')):0;
		# if (($bwoptions & 128)==128) { $FLAGS |= (1<<9); }	# edited by merchant

		## test for expedited shipping.
		if (not defined $self->__GET__('sum/shp_carrier')) {
			#warn "no shp_carrier\n";
			}
		elsif (not defined $ZSHIP::SHIPCODES{ $self->__GET__('sum/shp_carrier') }) {
			#warn "no zship::shipcode\n";
			}
		else {
			#warn "expedited: ".$ZSHIP::SHIPCODES{ $self->__GET__('shp_carrier') }->{'expedited'}."\n";
			$FLAGS |= ($ZSHIP::SHIPCODES{ $self->__GET__('sum/shp_carrier') }->{'expedited'})?(1<<1):0;
			}	

		if ((not defined $self->__GET__('cart/multivarsite')) || ($self->__GET__('cart/multivarsite') eq '' )) {
			## multvar site not set
			}
		elsif ( $self->__GET__('cart/multivarsite') eq 'A' ) {
			## A Side
			$FLAGS |= (1<<12);
			}
		elsif ( $self->__GET__('cart/multivarsite') eq 'B' ) {
			## B Side
			$FLAGS |= (1<<13);
			}
		else {
			## else, not A or B or blank
			$FLAGS |= ((1+2)<<12);
			}

		if ($self->__GET__('want/order_notes') ne '') {
			$FLAGS |= (1<<15);
			}

		if ($self->__GET__('flow/private_notes') ne '') {
			$FLAGS |= (1<<16);
			}

		if ((defined $self->__GET__('is/giftorder')) && ($self->__GET__('is/giftorder')==1)) {
			## gift orders -- the field is_giftorder should be set to 1
			$FLAGS |= (1<<14);
			}

		my $itemcount = 0;
		if (1) {
			## we don't recompute this stuff on a non-timestamp bump.
			my $stuff2 = $self->stuff2();
			foreach my $item (@{$stuff2->items()}) {
				my $stid = $item->{'stid'};
				next if (substr($stid,0,1) eq '%');	# skip promo items.
				next if ($item->{'is_promo'});	# skip promo items.
				$itemcount += int($item->{'qty'});
				if ((not defined $item->{'virtual'}) || ($item->{'virtual'} eq '')) {}
				elsif ($item->{'virtual'} =~ /^(LOCAL|NULL)/o) {}
				else { $FLAGS |= (1<<6); }
				}
	
			if ($itemcount>1) { $FLAGS |= (1<<0); }	## more than one item on an order.

			if (not defined $self->__GET__('sum/shp_carrier')) {}
			elsif ($self->__GET__('sum/shp_carrier') eq '') {}
			elsif (&ZSHIP::shipinfo( $self->__GET__('sum/shp_carrier'), 'expedited' ) ) { $FLAGS |= (1<<1); }
			}


		## handle dispatch events

		if (defined $self->__GET__('flow/pool')) {
			## cleanup the pool!
			$self->__SET__('flow/pool', uc($self->__GET__('flow/pool')) );
			if ($self->__GET__('flow/pool') eq 'CANCEL') { $self->__SET__('flow/pool','DELETED'); }
			elsif ($self->__GET__('flow/pool') eq 'CANCELED') { $self->__SET__('flow/pool','DELETED'); }
			elsif ($self->__GET__('flow/pool') eq 'CANCELLED') { $self->__SET__('flow/pool','DELETED'); }	
			if ($self->__GET__('flow/pool') eq 'PROCESSING') { $self->__SET__('flow/pool','PROCESS'); }
			}


		my @RESULTS = ();
		if ((defined $self->{'@PAYMENTS'}) && (ref($self->{'@PAYMENTS'}) eq 'ARRAY')) {
			my $GFC_TOTAL = 0;
			my $PNT_TOTAL = 0;
			foreach my $payment (@{$self->{'@PAYMENTS'}}) {
				if ($payment->{'tender'} eq 'GIFTCARD') {
					$GFC_TOTAL += (&f2int($payment->{'amount'}*100));
					}
				elsif ($payment->{'tender'} eq 'GIFTCARD') {
					$PNT_TOTAL += (&f2int($payment->{'amount'}*100));
					}
				}
			if ($GFC_TOTAL>0) {
				push @RESULTS, [ 'sum/gfc_total',  sprintf("%.2f",($GFC_TOTAL / 100))  ];
				push @RESULTS, [ 'sum/gfc_method', 'GiftCard(s)' ];
				push @RESULTS, [ 'is/gfc_taxable', 0 ];
				push @RESULTS, [ 'sum/pnt_total',  sprintf("%.2f",($PNT_TOTAL / 100))  ];
				push @RESULTS, [ 'sum/pnt_method', 'Points(s)' ];
				push @RESULTS, [ 'is/gfc_taxable', 0 ];
				}	
			#print STDERR "CART2 GFC_TOTAL: $GFC_TOTAL\n";
			#print STDERR "CART2 GFC_AVAILABLE: $GFC_AVAILABLE\n";
			}
 
		# push @RESULTS, [ 'order_subtotal', sprintf("%.2f",$totals->{'items.subtotal'}) ];
		push @RESULTS, [ 'flow/payment_method', $payment_method ];
		push @RESULTS, [ 'flow/payment_status', $payment_status ];
		push @RESULTS, [ 'sum/order_total', sprintf("%.2f",$order_total_i/100) ];
		push @RESULTS, [ 'sum/balance_paid_total', sprintf("%.2f",$balance_paid_i/100) ];
		push @RESULTS, [ 'sum/balance_due_total', sprintf("%.2f",$balance_due_i/100) ];
		push @RESULTS, [ 'sum/balance_auth_total', sprintf("%.2f",$balance_authorized_i/100) ];
		foreach my $set (@RESULTS) {
			$self->__SET__( $set->[0], $set->[1] );
			}
		@RESULTS = ();
	
		## BEGIN balance payments code

		##
		## AT THIS STAGE ANY PAYMENTS **SHOULD** be on @PAYMENTQ and 
		##
		}

	if (scalar(@{$self->paymentQ()})>0) {
		##
		## now - reorient the @PAYMENTQ so any giftcards are first
		##
		if (scalar(@{$self->paymentQ()})==0) {
			## not sure how/where this would happen. this line should *NEVER* be reached
			die();
			}
		elsif (scalar(@{$self->paymentQ()})==1) {
			$self->in_set('want/payby', $self->paymentQ()->[0]->{'TN'});
			}
		else {
			## LEAVE BRITTNEY ALONE.
			$self->in_set('want/payby',undef);
			}

		my $balance_due_i = &f2int($self->in_get('sum/balance_due_total')*100);
		my $balance_paid_i = &f2int($self->in_get('sum/balance_paid_total')*100);
		my $balance_authorized_i = &f2int($self->in_get('sum/balance_auth_total')*100);

		my @PRE_PAYMENTQ = ();  # giftcard payments will ALWAYS be processed first
		my $PRE_PAYBY = undef;
		my $PAYBY = undef;
		my @FIXED_PAYMENTQ =  	();  # fixed payments will ALWAYs be processed second.
		my @SPLIT_PAYMENTQ = 	();  # finally, we'll split any remaining payments
		foreach my $payq (@{$self->paymentQ()}) {	
			if ($payq->{'TN'} eq 'GIFTCARD') {
				if ($payq->{'TE'}>0) {
					unshift @PRE_PAYMENTQ, $payq;
					}
				else {
					push @PRE_PAYMENTQ, $payq;
					}
				if (not defined $PRE_PAYBY) { $PRE_PAYBY = 'GIFTCARD'; }
				elsif ($PRE_PAYBY eq 'GIFTCARD') {}
				else { $PRE_PAYBY = 'PREPAID'; }
				}
			elsif ($payq->{'TN'} eq 'POINTS') {
				unshift @PRE_PAYMENTQ, $payq;
				if (not defined $PRE_PAYBY) { $PRE_PAYBY = 'POINTS'; }
				elsif ($PRE_PAYBY eq 'POINTS') {}
				else { $PRE_PAYBY = 'PREPAID'; }
				}
			elsif ($payq->{'TN'} eq 'RMC') {
				unshift @PRE_PAYMENTQ, $payq;
				if (not defined $PRE_PAYBY) { $PRE_PAYBY = 'RMC'; }
				elsif ($PRE_PAYBY eq 'RMC') {}
				else { $PRE_PAYBY = 'PREPAID'; }
				}
			elsif ($payq->{'$#'}>0) {
				## NOTE: $$ is what we will charge -- $# means *FIXED* payment
				push @FIXED_PAYMENTQ, $payq;
				}
			else {
				push @SPLIT_PAYMENTQ, $payq;
				if (not defined $PAYBY) { $PAYBY = $payq->{'TN'};  } # first seen payment type
				elsif ($PAYBY eq $payq->{'TN'}) {	}						# same payment type
				else { $PAYBY = 'MIXED'; }	# more than one payment type
				}
			}

		if ((not defined $PAYBY) && (scalar(@PRE_PAYMENTQ)>0)) {
			## NOTE: giftcard can only be the PAYBY if it's the ONLY payment type.			
			$PAYBY = $PRE_PAYBY;
			}

		my @PAYMENTQ = ();
		# don't panic, we'll rebuild this in a sec.

		##
		## NEXT, RUN THROUGH THE PREPAID METHODS AND SEE HOW MUCH THEY CAN KNOCK THE BALANCE DOWN
		##
		##		$$ is the amount we *WILL* charge (and is set below)
		##		$#	is the amount we were requested to charge (which might be more [if the order total is less]) or 0 for not set.
		##
		foreach my $prepayq (@PRE_PAYMENTQ) {
			if ($prepayq->{'TN'} eq 'GIFTCARD') {
				## T$ = verified giftcard balance, max that can be charged
				## $$ = requested amount to be charged
				## $# = amount we will charge
				my ($gcref) = &GIFTCARD::lookup($self->username(),PRT=>$self->prt(),'CODE'=>$prepayq->{'GC'},'GCID'=>$prepayq->{'GI'});
				$prepayq->{'T$'} = $gcref->{'BALANCE'};
	
				$prepayq->{'$$'} = $prepayq->{'T$'};	# spend up to the full balance
				if (($prepayq->{'$#'} > 0 ) && ($prepayq->{'$#'} < $prepayq->{'$$'})) { 
					# BUT, don't spend more than asked
					$prepayq->{'$$'} = $prepayq->{'$#'}; 
					} 
				if ($balance_due_i < &ZOOVY::f2int($prepayq->{'$$'}*100)) {
					# AND we should never spend more than the balance due
					$prepayq->{'$$'} = sprintf("%.2f",$balance_due_i/100);
					}
				$balance_due_i = $balance_due_i - &ZOOVY::f2int($prepayq->{'$$'}*100);
				push @PAYMENTQ, $prepayq;
				}
			elsif ($prepayq->{'TN'} eq 'POINTS') {
				$balance_due_i = $balance_due_i - &ZOOVY::f2int($prepayq->{'$$'}*100);
				push @PAYMENTQ, $prepayq;
				}
			elsif ($prepayq->{'TN'} eq 'RMC') {
				$balance_due_i = $balance_due_i - &ZOOVY::f2int($prepayq->{'$$'}*100);
				push @PAYMENTQ, $prepayq;
				}
			}

		##
		## SANITY: at this point balance due is a list of payments next we're going to run through every payment with
		##			  $$ set to non-zero and subtract them from balance_due (these are called FIXED_PAYMENS) because the
		##			  amount is fixed.
		##
		my $after_paymentq_balance_due_i = $balance_due_i;
		my $after_paymentq_balance_auth_i = $balance_authorized_i;

		foreach my $payq (@FIXED_PAYMENTQ) {
			if ($payq->{'$#'}<=0) {
				## yeah, lets just abruptly stop, somebody meddled with the logic above. this line should never be reached.
				&ZOOVY::confess($self->username(),"INTERNAL ERROR - FIXED_PAYMENTQ queue has non-fixed payments");
				}
			$payq->{'$$'} = $payq->{'$#'};	# only spend what we were asked
			if ($after_paymentq_balance_due_i <  &ZOOVY::f2int($payq->{'$$'}*100)) {
				# UNLESS that's too much, then only spend what we have to spend.
				$payq->{'$$'} = sprintf("%.2f",$after_paymentq_balance_due_i/100);
				}
			$after_paymentq_balance_auth_i = $after_paymentq_balance_auth_i + &ZOOVY::f2int($payq->{'$$'}*100);
			$after_paymentq_balance_due_i = $after_paymentq_balance_due_i - &ZOOVY::f2int($payq->{'$$'}*100);
			push @PAYMENTQ, $payq;
			}

		##
		## FINALLY: go through remaining payments and divide up the totals evently.
		##
		my $split_payment_count = scalar(@SPLIT_PAYMENTQ);
		if ($split_payment_count==0) { $split_payment_count = 1; }	 # avoid div/zero error
		my $split_payment_amount = sprintf("%.2f", &ZOOVY::f2int( $after_paymentq_balance_due_i / $split_payment_count )/100);

		## dedup the payment queue
		
		
		foreach my $payq (@SPLIT_PAYMENTQ) {
			if ($split_payment_count == 1) {
				## the last payment split payment always gets the full balance due to avoid rounding issues
				$payq->{'$$'} = sprintf("%.2f",$after_paymentq_balance_due_i/100);
				$after_paymentq_balance_auth_i += $after_paymentq_balance_due_i;
				$after_paymentq_balance_due_i = 0;
				}
			else {
				$payq->{'__'} = "split=$split_payment_count;amt=$split_payment_amount;bal=$after_paymentq_balance_due_i";
				$payq->{'$$'} = $split_payment_amount;
				$after_paymentq_balance_auth_i += $split_payment_amount*100;
				$after_paymentq_balance_due_i -= $split_payment_amount*100;
				}

			## any split payments will consume the entire balance_due and finish the balance_auth
			$split_payment_count--;
			push @PAYMENTQ, $payq;
			}
		## END balance payemnts
		$self->paymentQ(\@PAYMENTQ);


		## SUMMARIZE TOTAL OF GIFTCARDS, POINTS, RETURN MERCHANDISE CREDITS
		if (scalar(@PAYMENTQ)>0) {
			## GIFTCARDS
			my $GFC_TOTAL = 0;
			my $GFC_AVAILABLE = 0;
			my $PNT_TOTAL = 0;
			my $PNT_AVAILABLE = 0;
			my $RMC_TOTAL = 0;
			my $RMC_AVAILABLE = 0;
			foreach my $payq (@PAYMENTQ) {
				if ($payq->{'TN'} eq 'GIFTCARD') {
					$GFC_TOTAL += (&f2int($payq->{'$$'}*100));
					$GFC_AVAILABLE += (&f2int($payq->{'T$'}*100));
					}
				elsif ($payq->{'TN'} eq 'POINTS') {
					$PNT_TOTAL += (&f2int($payq->{'$$'}*100));
					$PNT_AVAILABLE += (&f2int($payq->{'T$'}*100));
					}
				elsif ($payq->{'TN'} eq 'RMC') {
					$RMC_TOTAL += (&f2int($payq->{'$$'}*100));
					$RMC_AVAILABLE += (&f2int($payq->{'T$'}*100));
					}
				}
			if ($GFC_TOTAL>0) {
				$self->__SET__('sum/gfc_total', sprintf("%.2f",($GFC_TOTAL / 100)) );
				$self->__SET__('sum/gfc_available', sprintf("%.2f",$GFC_AVAILABLE /100) );
				$self->__SET__('sum/gfc_method','GiftCard(s)');
				$self->__SET__('is/gfc_taxable',0);
				}	
			if ($PNT_TOTAL>0) {
				$self->__SET__('sum/pnt_total', sprintf("%.2f",($PNT_TOTAL / 100)) );
				$self->__SET__('sum/pnt_available', sprintf("%.2f",$PNT_AVAILABLE /100) );
				$self->__SET__('sum/pnt_method','Point(s)');
				$self->__SET__('is/pnt_taxable',0);
				}	
			if ($RMC_TOTAL>0) {
				$self->__SET__('sum/rmc_total', sprintf("%.2f",($RMC_TOTAL / 100)) );
				$self->__SET__('sum/rmc_available', sprintf("%.2f",$RMC_AVAILABLE /100) );
				$self->__SET__('sum/rmc_method','Point(s)');
				$self->__SET__('is/rmc_taxable',0);
				}	
			}

		$self->__SET__('sum/balance_paid_total', sprintf("%.2f",$balance_paid_i/100) );
		if ($self->is_order()) {
			$self->__SET__('sum/balance_due_total', sprintf("%.2f",$balance_due_i/100) );
			$self->__SET__('sum/balance_auth_total', sprintf("%.2f",$balance_authorized_i/100) );
			}
		else {
			$self->__SET__('sum/balance_due_total', sprintf("%.2f",$after_paymentq_balance_due_i/100) );
			$self->__SET__('sum/balance_auth_total', sprintf("%.2f",$after_paymentq_balance_auth_i/100) );
			}
	
#		open F, ">/tmp/cart2.sync";
#		print F Dumper($self); 
#		close F;

		}

	$self->{'__SYNCING__'} = 0;
	$self->{'@CHANGES'} = [];
	}



#sub __SAVE__ {
#	my ($self) = @_;
#
#	if (not defined $self->{'@CHANGES'}) { $self->{'@CHANGES'} = []; }
#	if (scalar(@{$self->{'@CHANGES'}})>0) {
#		## we have changs we need to __SYNC__ to make sure all other fiels are up to date.
#		$self->__SYNC__();
#		}
#
#	return();
#	}







##
## gets a supplier record, caches in memory for faster lookups
##
sub getSUPPLIER {
	my ($self, $SUPPLIERCODE) = @_;
	if (not defined $self->{'%SUPPLIER_CACHE'}) {
		warn "PRODUCT '%SUPPLIER_CACHE'} was not pre-set on getSUPPLIER request\n";
		$self->{'%SUPPLIER_CACHE'} = {};
		}
	my $S = $self->{'%SUPPLIER_CACHE'}->{$SUPPLIERCODE};
	if (not defined $S) {
		$S = $self->{'%SUPPLIER_CACHE'}->{$SUPPLIERCODE} =  SUPPLIER->new($self->username(),$SUPPLIERCODE);
		if (not defined $S) { $self->{'%SUPPLIER_CACHE'}->{$SUPPLIERCODE} = ''; }
		}
	elsif (ref($S) eq '') {
		## this line is reached when getP has attempted this sku before, it failed, we shouldn't try it again.
		$S = undef;
		}
	return($S);
	}




##
## this is a transition function, basically so we can build data stuff2 and use it in a legacy cart
## use_stuff2_please 
sub set_stuff2_please {
	my ($self,$stuff2) = @_;
	$self->{'*stuff2'} = $stuff2;
	# $self->in_set('our/schedule',$stuff2->schedule()); ## HMM??
	return();
	}


## UTILITY FUNCTIONS
sub username { return($_[0]->{'USERNAME'}); }
sub mid { return(&ZOOVY::resolve_mid($_[0]->{'USERNAME'})); }
sub prt { 
	if (not defined $_[0]->{'PRT'}) {
		warn "PRT is not set on JSONAPI->prt() -- this probably won't work well.\n";
		}
	return($_[0]->{'PRT'}); 
	}
sub stuff2 {
	if (not defined $_[0]->{'*stuff2'}) { $_[0]->{'*stuff2'} = STUFF2->new($_[0]->username()); }
	return($_[0]->{'*stuff2'}); 
	}
sub uuid { 
	return($_[0]->{'UUID'}); 
	}
sub cartid { 
	if ($_[0]->is_order()) { return( $_[0]->in_get('cart/cartid') ); }
	return($_[0]->uuid()); 
	}

sub id {
	my ($self) = @_;
	warn Carp::cluck("CALLING cart2->id DIRECTLY (NOT ALLOWED)\n");
	if ($self->is_cart()) {
		return($self->cartid());
		}
	else {
		return($self->oid());
		}
	}

sub is_cart { return( ($_[0]->oid() eq '')?1:0 ); }
sub is_order { return( $_[0]->oid() ) };
sub is_memory { return($_[0]->{'__MEMORY__'}) };
sub is_persist { return( (defined $_[0]->{'CDBID'})?1:0) };  ## this returns true even if it's a new persist cart ID=0

sub cart_dbid  { return( int($_[0]->{'CDBID'}) ) };	# used to determine if a CART is fresh
sub order_dbid { return( int($_[0]->{'ODBID'}) ) };	# used to determine if an ORDER is fresh

sub is_supplier_order { return( $_[0]->__GET__('flow/supplier_orderid') ) };
sub supplier_orderid { return($_[0]->__GET__('flow/supplier_orderid') ) };	## *** NEEDS LOVE ***

sub is_marketplace_order { return( $_[0]->__GET__('is/origin_marketplace') ) };
sub is_staff_order { return( $_[0]->__GET__('is/origin_staff') ) };

sub cache_ts { 
	if (not defined $_[0]->{'+cache'}) {
		$_[0]->{'+cache'} = &ZOOVY::touched($_[0]->username(),0);	
		if ($ENV{'HTTP_PRAGMA'} eq 'no-cache') {  $_[0]->{'+cache'} = (time()+86400); }
		}
	return($_[0]->{'+cache'}); 
	}

sub webdb { my ($self) = @_; return(&ZWEBSITE::fetch_website_dbref($self->username(),$self->prt())); };
sub webdbref { my ($self) = @_; return(&ZWEBSITE::fetch_website_dbref($self->username(),$self->prt())); };
sub gref { my ($self) = @_; return(&ZWEBSITE::fetch_globalref($self->username())); };

sub schedule { 
	my ($self, $schedule, $src) = @_;

	if ((defined $schedule) && ($schedule eq '') && ($self->has_site()) ) {
		## attempt to load a site schedule
		my ($SITE) = $self->site();
		if ( not defined $SITE ) {
			}
		elsif ( not defined $SITE->nsref()->{'zoovy:site_schedule'}) {
			}
		elsif ( $SITE->nsref()->{'zoovy:site_schedule'} eq '') {
			}
		else {
			$schedule = $SITE->nsref()->{'zoovy:site_schedule'};
			$src = "SITE:".$SITE->sdomain();
			}
		}
	
	#if ((defined $schedule) && ($schedule eq '')) {
	#	print STDERR Dumper($self->has_site());
	#	die();
	#	}

	## if $schedule is not defined we're just doing a read.
	if (not defined $schedule) { 
		# print STDERR "SCHEDULE: ".$self->in_get('our/schedule')."\n";
		}
	elsif ($schedule eq $self->in_get('our/schedule')) {
		## it's the same, nothing to update.
		}
	else {
		## update the schedule in the stuff object as well.

		$self->in_set('our/schedule',$schedule);

		## NOTE: the line below corrupts yaml
		# if (not defined $src) { $src = join("|",caller(0)); }

		## okay so we are on a wholesale schedule
		$self->{'%WHOLESALE'} = WHOLESALE::load_schedule($self->username(),$schedule);

		my $is_wholesale = 1;
		if ($self->{'%WHOLESALE'}->{'realtime_inventory'}) { $is_wholesale |= 2; }
		if ($self->{'%WHOLESALE'}->{'realtime_products'}) { $is_wholesale |= 4; }
		if ($self->{'%WHOLESALE'}->{'realtime_orders'}) { $is_wholesale |= 8; }
		$self->in_set('is/wholesale',$is_wholesale);
		
		## list is duplicated in CHECKOUT.pm
		$self->in_set('our/schedule_src',$src);

		## hmm.. perhaps we should load the schedule here someday, and then avoid all the separate calls
		## *** NEEDS LOVE ***
		# if ($is_resale) { $SITE::CART2->shipping('flush'=>1); } # this will recompute the tax.
		$self->in_set('is/inventory_exempt',$self->{'%WHOLESALE'}->{'inventory_ignore'});
		$self->stuff2()->schedule($schedule);
		}

	return($self->in_get('our/schedule'));	
	}

## DATA FORMAT METHODS


##
##
##
# if (defined $SITE::remote_addr) { $self->{'ipaddress'} = $SITE::remote_addr; }
# elsif (defined $ENV{'REMOTE_ADDR'}) { $self->{'ipaddress'} = $ENV{'REMOTE_ADDR'}; }
## perl -e 'use lib "/backend/lib"; use CART2; use Data::Dumper; print Dumper(CART2->new_persist("zephyrsports",7,"HpslJO9OP13tCxCUd79bSNdc3"));'
##
## %params 
##		ip=>1				$r->connection()->remote_ip()
##		is_fresh=>1
##
sub new_persist {
	my ($class, $USERNAME, $PRT, $CART_ID, %params) = @_;

	if (not defined $CART_ID) { 
		warn "UUID is required to create persistent_cart".Carp::cluck(); return(undef); 
		} 

	if ($CART_ID eq '*') {
		warn Carp::confess("CART_ID of * is definitely invalid.. wtf - how did that happen?");
		die();
		}

	my $self = undef;
	my ($ID,$DATA) = (0,undef);

	if (not defined $DATA) {
		my ($redis) = &ZOOVY::getRedis($USERNAME);
		print STDERR "REDIS -- USERNAME:$USERNAME PRT:$PRT CART:$CART_ID ($redis)\n";
		my $REDIS_ID = &CART2::redis_cartid($USERNAME,$PRT,$CART_ID);
 		# print STDERR "LOADING: $REDIS_ID\n";
		$DATA = $redis->get($REDIS_ID);
		if ((defined $DATA) && ($DATA ne '')) {
			$ID = $redis->get("$REDIS_ID\@CDBID");
			($self) = YAML::Syck::Load($DATA);
			if (not defined $self) {
				$ID = 0;
				}
			else {
				$ID = 37;	## is persistent
				}
			}
		if ((not defined $ID) || ($ID == 0)) {
			## load from database
			$self = undef;
			$DATA = undef;
			}
		# print STDERR Dumper($self);
		}

	## UNIFIED THE CART VERSION #
	if (defined $self) {
		if ($self->{'V'} == 20120921) { $self->{'V'} = $CART2::VERSION; }
		## if ($self->{'V'} == 201314) { $self->{'V'} = $CART2::VERSION; }
		}

	if (not defined $self) {
		## create a new cart
		if ((defined $params{'create'}) && ($params{'create'} == 0)) {
			## leave it undef
			}
		else {
			$self->{'*stuff2'} = STUFF2->new($USERNAME);
			}
		}
	elsif ((defined $self) && ($self->{'V'} == $CART2::VERSION)) {
		## CURRENT CART FORMAT 20120921
		bless $self, 'CART2';
		bless $self->{'*stuff2'}, 'STUFF2';
		$self->stuff2()->link_cart2($self,'caller'=>'init');
		}
	elsif ((defined $self) && (not defined $self->{'V'})) {
		&ZOOVY::confess($USERNAME,"FOUND CART WITH NO VERSION -- YIPES!",justkidding=>1);
		$self->{'V'} = $CART2::VERSION;
		## CURRENT CART FORMAT 20120921
		bless $self, 'CART2';
		bless $self->{'*stuff2'}, 'STUFF2';
		$self->stuff2()->link_cart2($self,'caller'=>'init');
		}
	else {
		warn "this line in CART->new_persist is never reached this->{'V'}=$self->{'V'} -- current \$CART2::VERSION=$CART2::VERSION\n";
		&ZOOVY::confess($USERNAME,"CART->new_persist is never reached .. ");
		print STDERR 'DIE EEFORE CARt->new persist'.Dumper($self); 
		die();
		}

	if ( (defined $params{'is_fresh'}) && ( $params{'is_fresh'} )) {
		if (not defined $params{'ip'}) {
			warn "Please pass ip=> when calling CART2->new_persist with 'is_fresh'";
			}
		bless $self, 'CART2';
		$self->__SET__('cart/ip_address',$params{'ip'});
		}

	if ((defined $params{'create'}) && ($params{'create'}==0) && ($ID==0)) {
		## it's k, we want to fail
		$self = undef;	
		}
	else {
		$self->{'CDBID'} = int($ID);		## only set on PERSISTENT CARTS
		$self->{'UUID'} = $CART_ID;
		$self->{'USERNAME'} = $USERNAME;
		$self->{'PRT'} = int($PRT);
		$self->{'*stuff2'}->{'USERNAME'} = $USERNAME;	## USERNAME isn't set when CARTS are serialized
		$self->{'*stuff2'}->{'*CART2'} = $self;				## circular reference in STUFF2 back to cart
	
		# print STDERR Dumper($self);
	
		if (ref($self) ne 'CART2') {
			## i realize this is crude but it was handy for 'get er done' mode last night
			warn "possible - issue had to re-bless CART2 (it's k, i fixed it for now)\n";
			bless $self, 'CART2';
			}

		$self->__SET__('cart/cartid',$self->cartid());
		}

	if (not defined $self) {
		## it's k, at this point we probably intend to fail.
		}
	elsif (not defined $self->{'*stuff2'}) {
		## hmm.. is htis ever necessary?
		warn "possible - issue had to create STUFF2 way after i should have (it's k, i fixed it for now)\n";
		$self->{'*stuff2'} = STUFF2->new($self->username());
		}
	elsif (ref($self->{'*stuff2'}) ne 'STUFF2') {
		## hmm.. is this ever necessary
		warn "possible - issue had to re-bless STUFF2 in cart (it's k, i fixed it for now)\n";
		bless $self->{'*stuff'}, 'STUFF2';	
		}

	if (defined $self && $params{'*SESSION'}) {
		$self->SESSION($params{'*SESSION'});
		}

	return($self);	
	}



##
##
##
sub new_memory {
	my ($class, $USERNAME, $PRT, $UUID) = @_;
	my $self = {};

	$self->{'__MEMORY__'} = $$;		## only set on MEMORY carts
	$self->{'USERNAME'} = $USERNAME;
	
	$self->{'UUID'} = $UUID;
	if (not defined $self->{'UUID'}) {
		$self->{'UUID'} = &CART2::generate_cart_id();
		}
	$self->{'PRT'} = int($PRT);
	$self->{'%ship'} = {};
	$self->{'%bill'} = {};
	$self->{'%settings'} = {};

	$self->{'@HISTORY'} = [];
	

	#$self->{'id'} = '*';			# this is a temporary cart -- it should *NEVER* be saved (used in memory only, as scratch)
	#$self->{'created'} = $^T;
	#$self->{'stuff'} = STUFF->new($self->username());
	bless $self, 'CART2';
	$self->add_history(sprintf("MemoryCart %s init [%s:%s:%d]",$self->uuid(),&ZOOVY::servername(),&ZOOVY::appname(),$$));

	return($self);
	}




sub upgrade_v211_to_220 {
	my ($self) = @_;

	## convert v211 to v220
	foreach my $group ('%ship','%bill') {
		my $ref = $self->{$group};
		if (($ref->{'zip'}) && ($ref->{'zip'} ne '')) {
			$ref->{'postal'} = $ref->{'zip'};   delete $ref->{'zip'};
			}
		elsif (($ref->{'int_zip'}) && ($ref->{'int_zip'} ne '')) {
			$ref->{'postal'} = $ref->{'int_zip'};   delete $ref->{'int_zip'};
			}
		if (($ref->{'state'}) && ($ref->{'state'} ne '')) {
			$ref->{'region'} = $ref->{'state'};   delete $ref->{'state'};
			}
		elsif (($ref->{'province'}) && ($ref->{'province'} ne '')) {
			$ref->{'region'} = $ref->{'province'};   delete $ref->{'province'};
			}
		my %UPGRADE = ();
		$UPGRADE{'this/county_tax_rate'} = 'sum/tax_rate_region';
		$UPGRADE{'this/buysafe_cartdetailsdisplaytext'} = 'cart/buysafe_cartdetailsdisplaytext';
		$UPGRADE{'this/gfc_method'} = 'sum/gfc_method';
		$UPGRADE{'this/tax_zone'} = 'our/tax_zone';
		$UPGRADE{'our/ip_address'} = 'cart/ip_address';
		$UPGRADE{'sum/balance_auth'} = 'sum/balance_auth_total';
		$UPGRADE{'flow/posted'} = 'flow/posted_ts';
		$UPGRADE{'our/supplier_orderid'} = 'flow/supplier_orderid';
		$UPGRADE{'this/buysafe_bondcostdisplaytext'} = 'cart/buysafe_bondcostdisplaytext';
		$UPGRADE{'our/meta_src'} = 'cart/refer_src';
		$UPGRADE{'this/schedule'} = 'our/schedule';
		$UPGRADE{'this/city_tax_rate'} = 'sum/tax_rate_city';
		$UPGRADE{'our/meta'} = 'cart/refer';
		$UPGRADE{'this/shp_service'} = 'flow/shp_service';
		$UPGRADE{'sum/balance_paid'} = 'sum/balance_paid_total';
		$UPGRADE{'this/shp_method'} = 'sum/shp_method';
		$UPGRADE{'this/cpn_method'} = 'sum/cpn_method';
		$UPGRADE{'this/ins_method'} = 'sum/ins_method';
		$UPGRADE{'our/paid_date'} = 'flow/paid_ts';
		$UPGRADE{'this/bnd_method'} = 'sum/bnd_method';
		$UPGRADE{'sum/balance_returned'} = 'sum/balance_returned_total';
		$UPGRADE{'this/shp_footer'} = 'flow/shp_footer';
		$UPGRADE{'this/shipping_id'} = 'cart/shipping_id';
		$UPGRADE{'our/qbook_export'} = 'flow/qbook_export';
		$UPGRADE{'bill/zip'} = 'bill/postal';
		$UPGRADE{'flow/cancelled'} = 'flow/cancelled_ts';
		$UPGRADE{'flow/qbms_sent'} = 'cart/qbms_sent';
		$UPGRADE{'this/tax_rate'} = 'our/tax_rate';
		$UPGRADE{'ship/zip'} = 'ship/postal';
		$UPGRADE{'our/paypal_token'} = 'cart/paypal_token';
		$UPGRADE{'this/om_process'} = 'flow/om_process';
		$UPGRADE{'sum/balance_due'} = 'sum/balance_due_total';
		$UPGRADE{'flow/google_archived'} = 'flow/google_archived_ts';
		$UPGRADE{'this/buysafe_cartdetailsurl'} = 'cart/buysafe_cartdetailsurl';
		$UPGRADE{'flow/qbms_rcv'} = 'cart/qbms_rcv';
		$UPGRADE{'flow/buysafe_notified_gmt'} = 'flow/buysafe_notified_ts';
		$UPGRADE{'our/cartid'} = 'cart/cartid';
		$UPGRADE{'this/spc_method'} = 'sum/spc_method';
		$UPGRADE{'our/timestamp'} = 'flow/modified_ts';
		$UPGRADE{'this/checkout_digest'} = 'cart/checkout_digest';
		$UPGRADE{'this/payment_method'} = 'flow/payment_method';
		$UPGRADE{'our/paypalec_result'} = 'cart/paypalec_result';
		$UPGRADE{'this/hnd_method'} = 'sum/hnd_method';
		$UPGRADE{'bill/state'} = 'bill/region';
		$UPGRADE{'this/previous_cart_id'} = 'cart/previous_cartid';
		$UPGRADE{'this/checkout_stage'} = 'cart/checkout_stage';
		$UPGRADE{'this/created'} = 'cart/created_ts';
		$UPGRADE{'this/buysafe_val'} = 'cart/buysafe_val';
		$UPGRADE{'sum/tax_rate_state'} = 'sum/tax_rate_state';
		$UPGRADE{'this/shp_carrier'} = 'sum/shp_carrier';
		$UPGRADE{'this/buysafe_mode'} = 'cart/buysafe_mode';
		$UPGRADE{'this/buysafe_error'} = 'cart/buysafe_error';
		$UPGRADE{'this/buysafe_bondingsignal'} = 'cart/buysafe_bondingsignal';
		$UPGRADE{'sum/tax_rate_zone'} = 'sum/tax_rate_zone';
		$UPGRADE{'this/schedule_src'} = 'our/schedule_src';
		$UPGRADE{'our/created'} = 'our/order_ts';
		$UPGRADE{'this/tax_method'} = 'sum/tax_method';
		$UPGRADE{'ship/state'} = 'ship/region';
		$UPGRADE{'flow/google_processed'} = 'flow/google_processed_ts';
		$UPGRADE{'this/buysafe_purchased'} = 'cart/buysafe_purchased';
		$UPGRADE{'flow/ship_date'} = 'flow/shipped_ts';
		$UPGRADE{'our/multivarsite'} = 'cart/multivarsite';
		$UPGRADE{'flow/shipped_gmt'} = 'flow/shipped_ts';
		foreach my $k (sort keys %UPGRADE) {
			my ($old1,$old2) = split(/\//,$k,2);
			my ($new1,$new2) = split(/\//,$UPGRADE{$k},2);
			if ((defined $self->{"%$old1"}) && (defined $self->{"%$old1"}->{"$old2"})) {
				if (not defined $self->{"%$new1"}) { $self->{"%$new1"} = {}; }
				$self->{"%$new1"}->{"$new2"} = $self->{"%$old1"}->{"$old2"};
				}
			}
		$self->{'v'} = 220;
		}
	return($self);
	}


sub upgrade_v220_to_222 {
	my ($self) = @_;

	delete $self->{'%our'}->{'profile'};
	$self->{'%our'}->{'domain'} = $self->{'%our'}->{'sdomain'};
	delete $self->{'%our'}->{'sdomain'};
	$self->{'v'} = 222;

	return($self);
	}


##
##  $options{'warn_on_undef'} || don't throw a warning if it doesn't exist.
## 
sub new_from_oid {
	my ($class, $USERNAME, $ORDER_ID, %options) = @_;

	$ORDER_ID = (defined $ORDER_ID)?$ORDER_ID:'';

	## first we check the new database
	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my $mid = &ZOOVY::resolve_mid($USERNAME);
	my $order_id_qt = $odbh->quote($ORDER_ID);
	my $TB = &DBINFO::resolve_orders_tb($USERNAME,$mid);
	my $pstmt = "select ID, YAML, FLAGS, POOL, CREATED_GMT, MODIFIED_GMT, MKT_BITSTR, CUSTOMER from $TB where ORDERID=$order_id_qt and MID=$mid";
	(my $ID, my $YAML, my $FLAGS, my $POOL, my $CREATED_GMT, my $MODIFIED_GMT, my $MKTS, my $CUSTOMER_ID) = $odbh->selectrow_array($pstmt);

	my $self = undef;
	my $NUKE_EVENTS = 0;
	if ($YAML ne '') {
		## primarily load from YAML
		## make's it possible to load version 9 orders
		my $fixed = 0;
		#if ($YAML =~ /CUSTOMER\:\:ADDRESS/) {
		#	$fixed++;
		#	$YAML =~ s/\"\*CUSTOMER\"\: \&1 \!\!perl\/hash\:CUSTOMER/"*CUSTOMER"\:/gs;
		#	$YAML =~ s/\!\!perl\/hash\:CUSTOMER\:\:ADDRESS//gs;
		#	}

		# $YAML =~ s/CART2\|\/httpd\/modules\/CART2\.pm\|2913\|CART2\:\:schedule\|1\|\|\|\|2\|//gs;

		## NOTE: this was caused by YAML::XS (fixed by switching to YAML::Syck)
		#$YAML =~ s/\!\!perl\/hash\:Math\:\:BigInt//gs;	
		$YAML =~ s/\&[\d]+ \&[\d]+ \!\!perl\/hash\:Math\:\:BigInt/\!\!perl\/hash\:Math\:\:BigInt/gs;
		$YAML =~ s/\x{0}//gs;	## 10/17/12 -- 
		#$YAML =~ s/\&1 \&2 !\!\perl\/hash\:Math\:\:BigInt/\!\!perl\/hash\:Math\:\:BigInt/gs; # zephyrsports - "2012-06-261019"
		($self) = YAML::Syck::Load($YAML);
			
		$self->{'ODBID'} = $ID;

		if ((defined $self->{'v'}) && ($self->{'v'}>=210)) {
			bless $self, 'CART2';
			if (defined $self->{'*stuff2'}) {
				$self->{'*stuff2'}->{'USERNAME'} = $self->username();
				bless $self->{'*stuff2'}, 'STUFF2';

				## make sure we always have a uuid
				foreach my $item (@{$self->{'*stuff2'}->{'@ITEMS'}}) {
					if (not defined $item->{'uuid'}) {
						$item->{'uuid'} = $item->{'stid'};
						}
					}

				}



			if ($self->{'v'}==210) {
				foreach my $item (@{$self->{'*stuff2'}->items()}) {
					if (defined $item->{'*options'}) {
						$item->{'%options'} = $item->{'*options'};
						delete $item->{'*options'};
						foreach my $k (keys %{$item->{'%options'}}) {
							next if (defined $item->{'%options'}->{$k}->{'data'}) && ($item->{'%options'}->{$k}->{'data'} ne '');
							$item->{'%options'}->{$k}->{'data'} = $item->{'%options'}->{$k}->{'value'};
							delete $item->{'%options'}->{$k}->{'value'};
							}
						}
					}
				$self->{'v'} = 211;
				}

			if ($self->{'v'} <= 212) {
				&upgrade_v211_to_220($self);
				}

			if ($self->{'v'} < 222) {
				&upgrade_v220_to_222($self);
				}

			## ADD v=220 code here
			#my @HISTORY = ();
			#foreach my $h (@{$self->{'@HISTORY'}}) {
			#	if ($h->{'content'} =~ /CC=/) { 
			#		}
			#	else {
			#		push @HISTORY, $h;
			#		}				
			#	}
			#$self->{'@HISTORY'} = \@HISTORY;
			#foreach my $h (@{$self->{'@PAYMENTS'}}) {
			#	if ($h->{'acct'} =~ /CC:/) {
			#		$h->{'acct'} =~ s/\|CC\:([\d]+)\|/|/gs;
			#		$h->{'acct'} =~ s/\|CC\:([\d]+)^//gs;
			#		}
			#	delete $h->{'debug'};
			#	}

			if (length($YAML) > 100000) {
				## 12/17/2012 order manager had a bug which caused HUGE events to be generated.
				$self->{'@HISTORY'} = [];
				$self->add_history("order too large, events reset");
				}


			}
#		elsif ($self->{'version'} < 200) {
#
#			warn "DETECTED OLD LEGACY FORMAT ORDER IN DB: $USERNAME / $ORDER_ID";
##			return(undef);
#
#			require ORDER;
#			my ($o,$err) = ORDER->new($USERNAME, $ORDER_ID, 'new'=>0, 'create'=>0);
#
#			if ($err) { warn "ORDER[$ORDER_ID] ERROR:$err\n"; return(undef); }
#			if (ref($o) ne 'ORDER') { warn "ORDER[$ORDER_ID] ERROR:$err\n"; return(undef); }
#			$o->{'order_id'} = $ORDER_ID; 	# fix corrupt orders?
#
#			my $C2 = CART2->new_from_order($o);
#			$C2->{'ODBID'} = $ID;		## make usre we know this is already in the database
#			$C2->order_save('silent'=>1,'force'=>1);		## force upgrade
#			return($C2);
#			}
		else {
			Carp::confess("UNKNOWN ORDER FORMAT -- this line should never be reached");
			}
		

		}
		
	if ((not defined $self) || (ref($self) ne 'CART2')) {
		## invalid order
		if ((defined $options{'warn_on_undef'}) && ($options{'warn_on_undef'} == 0)) {
			}
		else {
			warn "REQUESTED INVALID ORDER $USERNAME $ORDER_ID (does not exist)\n";
			}
		}
	elsif ($self->{'v'} == $self->v()) {
		## valid order, current version
		}
	else {
		warn sprintf("SORRY I DO NOT KNOW HOW TO UPGRADE V: %s\n",$self->{'v'});
		}
	&DBINFO::db_user_close();
		
	return($self);
	}






##
## perl -e 'use lib "/backend/lib"; use ORDER; my ($o) = ORDER->new("toynk","2012-09-721608"); use CART2; use Data::Dumper; print Dumper(CART2->new_from_order($o));'
##	 
## %params =()
## 	# not used is_global_cart=>1 ??	
##
sub new_from_order {
	my ($class, $o, %params) = @_;


	my $self = {};
	# $self->{'*O'} = $o;

	if (ref($o) eq 'CART2') {
		## yay - we're already CART2 format
		$self = $o;
		}
	elsif (ref($o) eq 'ORDER') {
		bless $self, 'CART2';
		$self->{'*stuff2'} = STUFF2::upgrade_legacy_stuff($o->stuff());

		## use this to see what *stuff is being upgraded as
		# print Dumper($self->{'*stuff2'}); die();

		$self->{'%ship'} = {};
		$self->{'%bill'} = {};	
		$self->{'%settings'} = {};
		$self->{'ODBID'} = int($o->{'ODBID'});
		$self->{'USERNAME'} = $o->username();
		$self->{'MID'} = $o->mid();
		$self->{'PRT'} = $o->prt();

		## version 12 ORDER 
		## build a field map
		#my %map = ();
		#foreach my $newid (keys %CART2::VALID_FIELDS) {
		#	my $order1id = $CART2::VALID_FIELDS{$newid}->{'order1'};
		#	next if (not defined $order1id);
		#	$map{$order1id} = $newid; 
		#	}

		my $data = $o->get_attribs();
		foreach my $k (keys %{$data}) {
			next if ($k eq 'modified');
			next if ($k eq 'gfc_taxable');
			next if ($CART2::LEGACY_ORDER1_LOOKUP{$k} eq '');

			if ($CART2::LEGACY_ORDER1_LOOKUP{$k}) {
				$self->in_set( $CART2::LEGACY_ORDER1_LOOKUP{$k}, $data->{$k} );
				}
			elsif ($k =~ /^app\//) {
				warn "UNKNOWN CART FIELD: $k\n";
				$self->in_set( "app/$k", $data->{$k} );
				}
			else {
				warn "UNKNOWN CUSTOM CART FIELD: $k\n";
				my $kk = $k;  $kk =~ s/[^a-z0-9]/_/gs;
				$self->in_set( "app/$kk", $data->{$k} );
				}
			}

		# $self->{'*O'} = $o;
		$self->__SET__('our/orderid',$o->oid()); 
		$self->{'@FEES'} = $o->{'fees'};
		if (not defined $self->{'@FEES'}) { $self->{'@FEES'} = []; }
		$self->{'@HISTORY'} = $o->{'events'};
		if (not defined $self->{'@HISTORY'}) { $self->{'@HISTORY'} = []; }
		$self->{'@SHIPMENTS'} = $o->tracking();
		$self->{'@ACTIONS'} = $o->{'@dispatch'};
		$self->{'@PAYMENTS'} = $o->{'payments'};
		}
	else {
		Carp::confess("CANNOT ORDER OBJECT WAS NOT VALID\n");
		$self = undef;
		}

	return($self);
	}



##
## there are certain things (i.e. google checout which destroy the cart, so this clones itself)
##
sub as_copy {
	my ($self) = @_;	
	}


##
## gets/sets the reference to *MSGS (same as $lm)
##

sub msgs {
	my ($self, $lm) = @_;
	if (defined $lm) { $self->{'*MSGS'} = $lm; }
	if (not defined $self->{'*MSGS'}) { 
		$self->{'*MSGS'} = LISTING::MSGS->new($self->username()); 
		}
	return($self->{'*MSGS'});
	}

##
## should we be tracing debug
##
##	1: general trace    	
##	2: detailed trace
##	3: ?? (show rules)
## 4: ?? (show detailed rules)
## 5: developer level	
##
##      $TRACE += ($ZOOVY::cgiv->{'detail_1'})?1:0;     # general trace info (always enabled)
##      $TRACE += ($ZOOVY::cgiv->{'detail_2'})?2:0;     # detail trace info
##      $TRACE += ($ZOOVY::cgiv->{'detail_16'})?3:0;    # shipping rules level 1
##      $TRACE += ($ZOOVY::cgiv->{'detail_32'})?4:0;    # shipping rules detailed
##      $TRACE += ($ZOOVY::cgiv->{'detail_128'})?5:0;   # developer 	
##
sub is_debug {
	my ($self, $enable) = @_;

	if (defined $enable) { $self->{'+debug'} = $enable; }
	
	return($self->{'+debug'});
	}

## called (usually by stuff2) to inform us we should run a __SYNC__ before 
##	displaying any values.
sub sync_action {
	my ($self, $action, $reason) = @_;
	push @{$self->{'@CHANGES'}}, [ $action, $reason ];
	return();
	}


##
## rules:
##

sub __SET__ {
	my ($self, $path, $val) = @_;
   my ($node) = substr($path,0,index($path,'/'));
   my ($field) = substr($path,index($path,'/')+1);

	if (substr($path,0,4) eq 'app/') {
		}
	elsif (not defined $CART2::VALID_FIELDS{$path}) {
		Carp::confess("CART2::__SET__ $path value '$val' is not valid and was ignored");
		return(undef);
		}

	if (not defined $val) {
		delete $self->{"%$node"}->{$field};
		}
	else {
		$self->{"%$node"}->{$field} = $val;		
		}
	}

# internal set/get (anything/everything)
sub in_set { 
	my ($self,$path,$val) = @_;

	my %IGNORE = ();
	$IGNORE{'password'}++;
	$IGNORE{'giftcard'}++;
	$IGNORE{'want/bill_to_ship_cb'}++;

	if (substr($path,0,4) eq 'app/') {
		}
	elsif ($IGNORE{$path}) {
		## jt is lazy.
		}
	elsif (not defined $CART2::VALID_FIELDS{$path}) {
		warn Carp::cluck("FIELD $path value '$val' is not valid and was ignored");
		return(undef);
		}

	if (not defined $self->{'@CHANGES'}) { $self->{'@CHANGES'} = []; }
	my ($node) = substr($path,0,index($path,'/'));
	my ($field) = substr($path,index($path,'/')+1);

	my $FIELDREF = $CART2::VALID_FIELDS{$path};
	if (defined $FIELDREF) {}
	elsif ($FIELDREF->{'format'} eq 'int') { $val = sprintf("%d",$val); }

	# print STDERR '0 FILEDREF: '.Dumper($FIELDREF,$node,$field,$val);

	my $changes = 0;
	if (not defined $val) {
		## delete value
		if (defined $self->{"%$node"}->{$field}) {
			push @{$self->{'@CHANGES'}}, [ "$node/$field", $self->{"%$node"}->{$field}, $val ];
			delete $self->{"%$node"}->{$field};
			$changes++;
			}
		}
	elsif ($self->{"%$node"}->{$field} eq $val) {
		## no change
		}
	elsif ((defined $FIELDREF) && ($FIELDREF->{'setifnb'})) {
		## FIELD PROPERTY setifnb (set if not blank) is a useful way to only set a field be set once. 
		my $setifnbpath = $FIELDREF->{'setifnb'};
	   my ($setifnbnode) = substr($setifnbpath,0,index($setifnbpath,'/'));
	   my ($setifnbfield) = substr($setifnbpath,index($setifnbpath,'/')+1);
		if ((not defined $self->{"%$setifnbnode"}->{$setifnbfield}) || ($self->{"%$setifnbnode"}->{$setifnbfield} eq '')) {
			push @{$self->{'@CHANGES'}}, [ "$setifnbpath", $self->{"%$setifnbnode"}->{$field}, $val ];
			$self->{"%$setifnbnode"}->{$setifnbfield} = $val;
			}
		
		if ($setifnbpath ne $path) {
			## we still (always) set path -- unless the setifnb was referencing ourselves.
			push @{$self->{'@CHANGES'}}, [ "$node/$field", $self->{"%$node"}->{$field}, $val ];
			$self->{"%$node"}->{$field} = $val;		
			$changes++;			
			}
		}		
	else {
		push @{$self->{'@CHANGES'}}, [ "$node/$field", $self->{"%$node"}->{$field}, $val ];
		$self->{"%$node"}->{$field} = $val;		
		$changes++;
		}

	return($changes); 
	}	



##
## an 'unsynced' get -- assumed all data is in sync
##		**NEVER** call this function outside of __SYNC__ instead call
##		in_get, pr_get, pu_get
sub __GET__ {
	my ($self, $path) = @_;

	my ($node,$field) = ();
	if (index($path,'/')<0) {
		warn Carp::cluck("attempt to CART2::__GET__ on **VERY** invalid path '$path'\n");
		($node,$field) = ('','');
		}
	elsif ( (not defined $CART2::VALID_FIELDS{$path}) && (substr($path,0,4) eq 'app/') && (substr($path,0,5) ne 'will/') ) {
		warn Carp::cluck("attempt to CART::__GET__ on **MISSNAMED** path '$path'\n");
		}
	else {
		($node) = substr($path,0,index($path,'/'));
		($field) = substr($path,index($path,'/')+1);
		if ($node eq 'will') {
			$node = ($self->{"%must"}->{$field})?'must':'want';
			}
		}


	return($self->{"%$node"}->{$field});
	}




##
##
##
sub in_get { 
	my ($self, $path) = @_;

	if ($path eq 'our/sdomain') { $path = 'our/domain'; }

	if (not defined $self->{'@CHANGES'}) { $self->{'@CHANGES'} = []; }

	my $properties = $CART2::VALID_FIELDS{ $path };
	if ((not defined $properties) && (substr($path,0,4) eq 'app/')) { $properties = {}; }
	if ((not defined $properties) && (substr($path,0,5) eq 'will/')) { $properties = {}; }

	if (not defined $properties) {
		## this could eventually be moved inside of @CHANGES since it *really* doesn't matter but it's really useful for 
		## debugging so i'm running it more than i need to. -bh
		warn Carp::cluck("REQUESTED TO READ INVALID FIELD AFTER CHANGES HAVE BEEN MADE '$path' -- RETURNING UNDEF");
		return(undef);
		}
	elsif (scalar(@{$self->{'@CHANGES'}})>0) {
		## we have changs we need to __SYNC__ to make sure all other fiels are up to date.
		if ($properties->{'sync'}) {
			$self->__SYNC__();
			}
		}

	return($self->__GET__($path));
	}
	


sub pr_set { return(&in_set(@_)); } # private authorized user set/get
sub pr_get { return(&in_get(@_)); }	
sub pu_set { return(&in_set(@_)); } # public user get/set
sub pu_get { return(&in_get(@_)); }

##
## returns a legacy cart object based on this data
##
sub as_legacy {
	my ($self) = @_;

	## key cart fields
	## $self->{'id'} = &CART2::generate_cart_id();	

	# perl -e 'use lib "/backend/lib"; use CART2; my $cart2 = CART2->new_persist("zephyrsports",7,"AgI1Xu9OYU3ufWNRxPOspU6gK");'

	my %legacy = ();
	foreach my $group ('ship','bill','want','must','our','flow','this','sum','customer','app') {
		foreach my $k (sort keys %{$self->{"%$group"}}) {
			my $ref = $CART2::VALID_FIELDS{"$group/$k"};
			if (defined $ref->{'cart1'}) {
				$legacy{ $ref->{'cart1'} } = $self->in_get("$group/$k");
				}
			}
		}
	$legacy{'stuff'} = $self->stuff2()->as_legacy_stuff();
	$legacy{'@shipmethods'} = $self->shipmethods();
	my ($sums) = $self->stuff2()->sum();
	$legacy{'data.item_count'} = $sums->{'items_count'};
	foreach my $k (keys %{$sums}) {
		my $ref = $CART2::VALID_FIELDS{"sum/$k"};
		next if (not defined $ref->{'cart1'});
		next if (defined $legacy{ $ref->{'cart1'} });
		$legacy{ $ref->{'cart1'} } = $sums->{$k};
		}
	$legacy{'data.order_total'} = $self->in_get('sum/order_total');
		
	return(\%legacy);
	}



##
## verifies the current ip address is really the owner, or remaps the cart and resets the id.
##
sub reset_session {
   my ($self,$CAUSE) = @_;

	## make sure all users (when this function is run) who don't have cookies - 
	##		and/or don't pass referrer have to login once per hour.

	my $remap = 0;
	if (not $self->is_persist()) {}    # never mind..
	else { $remap++; }

	print STDERR "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! REMAP: $remap CAUSE:$CAUSE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";

 	if (($remap) && ($CAUSE ne 'CART_EMPTY')) {
		## ALWAYS clear important cart variables in a remap situation.
		delete $self->{'login'};
		foreach my $k (keys %{$self}) {
			if ($k eq 'previous_cart_id') {} # keep
			elsif (substr($k,0,1) eq '%') { $self->{$k} = {}; }
			elsif (substr($k,0,1) eq '*') { delete $self->{$k}; }
			else {
				print STDERR "RESET($CAUSE) UNKNOWN KEY: $k\n";
				}
			}
		}

	if ($remap) {
		}

	if ($remap) {
		## remap the cart.
		my $WAS_CARTID = $self->cartid();
		$self->__SET__('cart/created_ts',time());
		$self->__SET__('cart/previous_cartid', sprintf("%s|%s",$WAS_CARTID, $self->__GET__('cart/previous_cartid')) );
		$self->__SET__('cart/cartid',$self->{'UUID'} = &CART2::generate_cart_id());
		$self->{'CDBID'} = 0;	
		$self->cart_save();

		my ($redis) = &ZOOVY::getRedis($self->username());
		if (defined $redis) {
			my $REDIS_ID = &CART2::redis_cartid($self->username(),$self->prt(),$WAS_CARTID);
			$redis->del($REDIS_ID);
			print STDERR "!!!!!!!!!!! DELETE REDIS ID: $REDIS_ID !!!!!!!\n";
			}		
      }
   }



##############################################################################
##
## CART::generate_cart_id
##
## Purpose: Generate a unique identifier for the cart and bounce
## Accepts: Nothing
## Returns: A random 25 length alphanumeric value
##
sub generate_cart_id {
	my (%options) = @_;

	my @characters = ('A' .. 'Z', 'a' .. 'z', 0 .. 9);
	my $new_cart_id = '';
	my $cs = scalar(@characters);

	my $s = (time() + $CART::SEED ^ ($$ + ($$ << 15))); # Partially yoinked from "Programming Perl"

	foreach (values %ENV) {
		$s ^= ord( substr($_, -1, 1) );
		$s ^= ord( substr($_, 1, 1) );
		}

	$s ^= ZTOOLKIT::ip_to_int( &ZTOOLKIT::def($ENV{'REMOTE_ADDR'}, 0) );
	$s ^= ZTOOLKIT::ip_to_int( &ZTOOLKIT::def($ENV{'SERVER_ADDR'}, 0) );
	srand($s);

	## the first six digits are unique
	for (1 .. 6) { $new_cart_id = $new_cart_id.$characters[rand $cs]; }
	## the next 4 digits this guarantees a cart id is unique within a 10 minute window.
	$new_cart_id .= &ZTOOLKIT::zeropad(4,substr(	&ZTOOLKIT::base62(time()/600) ,-4));
	## the next 6 digits contains the remote IP
	## use ZTOOLKIT; print &ZTOOLKIT::pretty_date(&ZTOOLKIT::unbase62(substr('LpgeLd9c1v3Wk8HLYn55wWOd5',6,4))*600,1);

	if (defined $ENV{'REMOTE_ADDR'}) { 
		$new_cart_id .= &ZTOOLKIT::zeropad(6,&ZTOOLKIT::base62(&ZTOOLKIT::ip_to_int($ENV{'REMOTE_ADDR'})));
		}
	else {
		## or for no IP present it contains an X and 5 random digits
		$new_cart_id .= 'X';
		for (1 .. 5) { $new_cart_id .= $characters[rand $cs]; }
		}

	## last 9 digits are unique
	for (1 .. 9) { $new_cart_id .= $characters[rand $cs]; }
	
	$CART::SEED = $CART::SEED + 69; # Nice odd number, this is so two subsequent calls don't get the same number.
	$new_cart_id = substr($new_cart_id,0,25);

	return($new_cart_id);
	}


##
## returns a customer record if one is logged in.
##

sub customerid { return(int($_[0]->in_get('customer/cid')));  }
sub cid { return(int($_[0]->in_get('customer/cid')));  }
sub customer {
	my ($self, $C) = @_;

	if (defined $C) { 
		$self->{'*CUSTOMER'} = $C; 
		$self->__SET__('customer/cid',$C->cid());
		$self->__SET__('customer/login',$C->email());
		$self->__SET__('customer/login_gmt',time());

		my $ORG = undef;
		if ($C->is_wholesale()) {
			$ORG = $C->org();
			}
		
		$self->__SET__('customer/tax_id',undef);
		if ((defined $ORG) && (ref($ORG) eq 'CUSTOMER::ORGANIZATION')) {
			#$self->__SET__('is/tax_exempt',$C->fetch_attrib('WS.RESALE'));		
			$self->__SET__('is/tax_exempt',$ORG->get('RESALE'));
			#$self->__SET__('is/allow_po',$C->fetch_attrib('WS.ALLOW_PO'));
			$self->__SET__('is/allow_po',$ORG->get('ALLOW_PO'));
			#$self->__SET__('customer/account_manager',$C->fetch_attrib('WS.ACCOUNT_MANAGER'));
			$self->__SET__('customer/account_manager',$ORG->get('ACCOUNT_MANAGER'));
			#$self->schedule($C->fetch_attrib('INFO.SCHEDULE'),"CUSTOMER:".$C->cid());
			$self->schedule($ORG->schedule(),sprintf("CID[%d] ORGID[%d]",$C->cid(),$ORG->orgid()));


			# print STDERR Dumper($self, $C->fetch_attrib('INFO.SCHEDULE'));
			# die();
			}
		else {
			$self->__SET__('is/tax_exempt',undef);
			$self->__SET__('is/allow_po',undef);
			$self->__SET__('customer/account_manager',undef);
			$self->schedule('');
			}
		}
	## who else should we inform? linked orders? 
	## linked sessions?

	if (defined $self->{'*CUSTOMER'}) {
		## we've already got it - and it's cached - no sense trying to load.
		}
	elsif ($self->__GET__('customer/cid')>0) {
		## customer ID is set, so we try and load that.
		$self->{'*CUSTOMER'} = CUSTOMER->new($self->username(),PRT=>$self->prt(),CID=>$self->customerid(),INIT=>0x1);
		}

	## TODO: we probably ought to do a bit of checking to ensure that customer/cid matches *CUSTOMER

	if (ref($self->{'*CUSTOMER'}) eq 'CUSTOMER') { 
		return($self->{'*CUSTOMER'}); 
		}

	return(undef);
	}

### 
## note: set customer_id to undef, or -1 to force a lookup
##	formerly: ORDER::customerid()
sub guess_customerid { 
	my ($self) = @_;
	##
	## map customer if it exists (duplicated in save())
	##
	my ($cid) = $self->__GET__('customer/cid');
	if (not defined $cid) { $cid = -1; }

	if ($cid>0) {
		## yay!
		}
	elsif (not defined $self->__GET__('bill/email')) {
		## oh shit, well this won't work!
		$self->__SET__('customer/cid',undef);		# 'undef' will cause guess to run again!
		}
	elsif (defined $self->__GET__('bill/email')) {
		## new order, and we don't have a customer to match to, we'll try to do a lookup.
		require CUSTOMER;
		($cid,my $ccreated_gmt) = &CUSTOMER::resolve_customer_info($self->username(), $self->prt(),$self->__GET__('bill/email'));
		if (not defined $cid) { 
			$self->__SET__('customer/cid',0);
			}
		else {
			$self->__SET__('customer/cid',$cid);
			$self->__SET__('customer/created_gmt',$ccreated_gmt);
			}

		}

	return($self);
	}


##
##
##
#sub customer_fetch {
#	my ($self, %params) = @_;
#	
#	#if ($self->cid()>0) {
#	#	# auto-load customer
#	#	$self->{'*CUSTOMER'} = CUSTOMER->new($self->username(),'PRT'=>$self->prt(),'CID'=>$self->cid());
#	#	return($self->{'customer'});		
#	#	}
#	# return($c);
#	}



sub orderid { 
	print STDERR "CART2->orderid isn't valid\n";
	return(CART2::oid(@_)); 
	}
sub oid { return($_[0]->in_get('our/orderid')); }
#sub O {
#	my ($self) = @_;
#	if (ref($self->{'*O'}) eq 'ORDER') { return($self->{'*O'}); }
#	}





##
## detailref
##	
##	pass in $CODE to reference an on disk coupon code.
##	
##	pass in $CODE as "SCHEDULE" or "CAMPAIGN" with $cpnref for a dynamic coupon.
##	$cpnref = {
## 	type=>product
##			product=>
##			price=>
##		type=>fullset
##			products=>pid1,pid2
##			discount=>10%
##		type=>discount_shipping
##			price=>0.00
##	
##	all cpnrefs support:
##		created_gmt=>			(will be automatically set to now)	-- when the promotion was added to cart.
##		addcart_gmt=>epoch	(0 for never)		--	the latest time an add will be accepted
##		expires_gmt=>			the final purchase must be made by this time. (0 for never)
##		
##		image=>cart image
##		taxable=>
##		src=>
##
##
## addedfrom:
##		SITE
##		NEWSLETTER
##
sub add_coupon {
	my ($self,$code,$errorsref,$cpnref,$addedfrom) = @_;

	$code = uc($code);

	if ($code eq '') { return(); }

	if (not defined $errorsref) {
		$errorsref = [];
		}

	if (not defined $self->{'%coupons'}) {
		$self->{'%coupons'} = {};
		}

	my $count = 0;
	if (not defined $cpnref) {
		require CART::COUPON;
		# push @SITE::ERRORS, "PRT=".$self->prt().",$code";
		my ($webdbref) = $self->webdb();
		($cpnref) = CART::COUPON::load($webdbref,$code);
		}

	if (not defined $cpnref) {
		}
	elsif (not $cpnref->{'stackable'}) {
		## non-stackable coupon, delete all coupons
		$self->{'%coupons'} = {};
		}
	elsif (defined $self->{'%coupons'}->{$code}) {
		## stackable coupon, just delete itself so it can be replaced (if it exists)
		delete $self->{'%coupons'}->{$code};
		}

	if (not defined $cpnref) {
		push @{$errorsref}, "Coupon $code could not be found.";
		}
	elsif (($addedfrom eq 'SITE') && ($cpnref->{'limiteduse'}>0)) {
		push @{$errorsref}, "Coupon $code cannot be added directly from the SITE";
		}
	#elsif (($self->profile()) && 		## okay, SITE::SREF is initialized
	#		($cpnref->{'profile'} ne '') && 	## and the profile in the coupon is set.
	#		($cpnref->{'profile'} ne $self->profile())) { ## and it matches the profile of the coupon.
	#	push @{$errorsref}, "Coupon $code not available for this profile";
	#	}
	elsif ($cpnref->{'disabled'}) {
		push @{$errorsref}, "Coupon $code is no longer available.";
		}
	elsif ((defined $cpnref->{'begins_gmt'}) && ($cpnref->{'begins_gmt'}>0) && ($cpnref->{'begins_gmt'}>time())) {
		push @{$errorsref}, "Coupon $code is not available yet.";
		}
	elsif (($cpnref->{'expires_gmt'}>0) && ($cpnref->{'expires_gmt'}<$^T)) {
		push @{$errorsref}, "Coupon $code has expired.";
		}
	elsif (($cpnref->{'expires_gmt'}>0) && ($cpnref->{'expires_gmt'}<$^T)) {
		push @{$errorsref}, "Coupon $code has expired.";
		}
	else {
		$self->{'%coupons'}->{$code} = $cpnref;
		$self->sync_action('coupon-added',$code);
		}

	#print STDERR "BEGINS_GMT ".$cpnref->{'begins_gmt'}." T: ".$^T." time: ".time()."\n";
	# use Data::Dumper;
	# print STDERR 'COUPON ERROR: '.Dumper($errorsref);
	return($errorsref);
	}



#sub has_points { 
#	my ($self) = @_;
#	if (not defined $self->{'@PAYMENTQ'}) { $self->{'@PAYMENTQ'} = []; }
#	my $count = 0;
#	foreach my $payq (@{$self->{'@PAYMENTQ'}}) {
#		if ($payq->{'TN'} eq 'POINTS') {
#			$count++;
#			## ignore this.
#			}
#		}
#	}


##
## returns the a scalar array of giftc
## paramters:
##		$code is a giftcard code (un-obfuscated)
##
sub has_giftcards { return($_[0]->has_giftcard()); }	 # this reads better in the code
sub has_giftcard {
	my ($self, $code) = @_;

	my $count = 0;
	foreach my $payq (@{$self->paymentQ()}) {
		if ($payq->{'TN'} ne 'GIFTCARD') {
			## ignore this.
			}
		elsif ($code eq '') { $count++; }
		elsif ($payq->{'GC'} eq $code) { $count++; }
		}
	return($count);
	}


##
## How giftcards work:
##		code=>xyz, 
##
#sub add_giftcard {
#	my ($self,$code,$errorsref) = @_;
#
#	return($errorsref);
#	}





## not sure what this does.
#sub debug {
#	my ($self, $type, $priority, $txt) = @_;
#
#	#if ($self->has_msgs()) {
#	#	$self->msgs()->pooshmsg("ZOOVY|+$type/$priority $txt");
#	#	}
#	};



sub exists {
	my ($self) = @_;

	if ($self->is_memory()) { 
		# print STDERR "RETURNED IS_MEMORY\n";
		return(0); 
		}
	elsif ($self->is_persist()) { 
		# print STDERR "IS PERSIST\n";
		return($self->cart_dbid()); 
		}
	}



##############################################################################
##
## CART->save
##
## Purpose: Writes out a full cart in storable format
## Accepts: A reference to a full cart
## Returns: 1 if the cart is written, 0 if it failed
##
sub save {
	my ($self, %options) = @_;

	if ($self->is_readonly()) {
		warn Carp::cluck("called non-supported save command on is_readonly order, wtf -- seriously, this is bad news."); 
		}
	elsif ($self->is_order()) {
		warn "called method save() on CART2::ORDER ".join("|",caller(0))." -- this is bad, very bad.\n";
		return($self->order_save(%options));
		}
	elsif ($self->is_memory()) { 
		warn "attempted to save a memory cart\n";
		return(0); 
		}
	elsif ($self->is_cart()) {
		warn "called method save() on CART2::ORDER ".join("|",caller(0))." -- this is bad, call cart_save instead.\n";
		return($self->cart_save(%options));
		}
	}



sub redis_cartid { my ($USERNAME,$PRT,$CARTID) = @_;	return(sprintf("cart+%s.%s+%s",$USERNAME,$PRT,$CARTID)); }


##
##
##
##
sub cart_save {
	my ($self, %options) = @_;

	if (not defined $self->{'@CHANGES'}) { $self->{'@CHANGES'} = []; }
	if (scalar(@{$self->{'@CHANGES'}})>0) {
		$CART2::DEBUG && warn "cart_save is callign sync because changes were made\n";
		$self->__SYNC__();
		}

	if ($options{'force'}) {
		## used by binedit.pl
		warn "forced cart save (hope that's what you wanted)\n";
		}
	elsif ($self->is_readonly()) {
		warn Carp::cluck("attempted to save a readonly cart READONLY:[$self->{'__READONLY__'}]\n");
		}
	elsif ($self->is_memory()) { 
		warn "attempted to save a memory cart (note: this is perfectly fine as an order)\n";
		return(0); 
		}
	elsif (not defined $self->{'__SYNCING__'}) {

		warn "__SYNCING__ is undefined, nothing has been changed - so we'll skip the save\n";
		return(0);
		}

	
	## we clear the urls so that we don't cache the session id (not sure if this is necessary)
	## so we'll leave it for now. -bh
	# my ($success) = &BLOB::store($self->username(),'CART',$self->{'id'},$self);
	my $USERNAME = $self->username();

	$self->__SYNC__();

	my %p = ();
	$p{'MID'} = &ZOOVY::resolve_mid($self->username());
	$p{'CARTID'} = $self->cartid();

	## ignore:
	##	_tied
	##	@tied


	my %clone = ();
	$clone{'V'} = $CART2::VERSION;
	$clone{'UUID'} = $self->{'UUID'};
	$clone{'USERNAME'} = $self->{'USERNAME'};
	$clone{'PRT'} = $self->{'PRT'};

	$clone{'@PAYMENTQ'} = $self->{'@PAYMENTQ'};	## preserve giftcards
	$clone{'%coupons'} = $self->{'%coupons'};		## preserve coupons
	foreach my $group (@CART2::VALID_GROUPS) {
		if (defined $self->{"%$group"}) { $clone{"%$group"} = $self->{"%$group"}; }
		}
	if (defined $self->{'@shipmethods'}) {
		$clone{'@shipmethods'} = $self->{'@shipmethods'};
		}
	$clone{'*stuff2'}->{'@ITEMS'} = $self->stuff2()->{'@ITEMS'};

	$p{'DATA'} = YAML::Syck::Dump(\%clone);
	$p{'PRT'} = $self->prt();
	$p{'ITEM_COUNT'} = $self->stuff2()->count('show'=>'');

	#if (defined $self->has_msgs()) {
	#	$self->msgs()->pooshmsg("DEBUG|+Saved cart to database");
	#	}

	if (length($p{'DATA'})>100000) {
		## this is a problematic cart, lets log it.
#		open F, sprintf(">/tmp/bigcart.%s",$self->cartid());
#		print F Dumper(\%clone);
#		close F;
		}

#	my ($memd) = &ZOOVY::getMemd($self->username());
#	$memd->set($self->cacheid(),$p{'DATA'});

	my ($redis,$redis_cart_id);
	if (1) {	
		## REDIS CACHE CODE
		($redis) = &ZOOVY::getRedis($self->username());
		$redis_cart_id = &CART2::redis_cartid($self->username(),$self->prt(),$self->cartid());

		#open F, sprintf(">%s/cart.$redis_cart_id",&ZOOVY::memfs());
		#print F $p{'DATA'};
		#close F;

		if (defined $redis) {
			my $EXPIRESIN = 86400*3;
			if ($self->__GET__('sum/items_count')>0) { $EXPIRESIN = 86400*15; }
			$redis->setex($redis_cart_id,$EXPIRESIN,$p{'DATA'});
			# unlink "/dev/shm/cart.$redis_cart_id";
			}
		else {
			&ZOOVY::confess($self->username(),"OH-SHIT - could not save cart to REDIS\n".Dumper($self),justkidding=>1);
			}
		# print STDERR "REDIS STORING $redis_cart_id\n";
		}
	
	return();
	}




##
## resolves a legacy cart property to it's new CART2 name
##
sub legacy_resolve_cart_property {
	my ($cart1key) = @_;
	## try and find the property

	my $found = $CART2::LEGACY_CART1_LOOKUP{lc($cart1key)};

	if (not $found) { 
		warn "COULD NOT LOOKUP LEGACY CART VALUE: $cart1key [[hint: add an alias in \%CART2::LEGACY_CART1_LOOKUP]]\n";
		$found = lc("app/$cart1key");
		if (not defined $CART2::VALID_FIELDS{ $found }) { $CART2::VALID_FIELDS{ $found } = {}; }
		}

	return($found);
	}


## LEGACY CART
sub legacy_fetch_property {
	my ($self, $cart1key) = @_;
	$cart1key = lc($cart1key);
	## try and find the property
	my $cart2key = &CART2::legacy_resolve_cart_property($cart1key);
	if (($cart1key eq 'data.ship_country') || ($cart1key eq 'data.bill_country')) {
		my ($info) = &ZSHIP::resolve_country("ISO"=>$self->pu_get($cart2key));
		return($info->{'Z'});
		}
	elsif (defined $cart2key) {
		return($self->pu_get($cart2key));
		}
	else {
		warn Carp::cluck("Missed legacy_fetch_property resolve for field '$cart1key' key:$cart2key - ".join("|",caller(0))."\n");
		}
	}

## LEGACY CART
sub legacy_save_property {
	my ($self, $cart1key, $value) = @_;
	## try and find the property
	my ($cart2key) = &CART2::legacy_resolve_cart_property($cart1key);
	if (defined $cart2key) {
		return($self->pu_set($cart2key,$value));
		}
	else {
		warn "Missed legacy_save_property resolve for field '$cart1key' - ".join("|",caller(0))."\n";
		}
	}



##
## used by legacy emails
##
sub get_legacy_order_attribs_as_hashref {
	my ($self) = @_;
	my %result = ();
	foreach my $k (keys %CART2::VALID_FIELDS) {
		my $order1key = $CART2::VALID_FIELDS{$k}->{'order1'};
		next if (not defined $order1key);
		$result{$order1key} = $self->__GET__($k);
		}
	return(\%result);
	}



###########################################################################
##
## resolves a legacy order property to it's new CART2 name
##
sub legacy_resolve_order_property {
	my ($order1key) = @_;
	## try and find the property

	$order1key = lc($order1key);
	my $found = $CART2::LEGACY_ORDER1_LOOKUP{$order1key};
	
	if (not $found) {
		if ($order1key =~ /^(ship|bill)\_country$/) {
			$found = "*$order1key";
			}
		}

	if (not $found) { 
		warn "COULD NOT LOOKUP LEGACY ORDER VALUE: $order1key [[hint: add an alias in \%CART2::LEGACY_ORDER1_LOOKUP]]\n";
		$found = lc("app/$order1key");
		}

	return($found);
	}


## LEGACY CART
sub legacy_order_get {
	my ($self, $order1key) = @_;
	$order1key = lc($order1key);
	## try and find the property
	my $order2key = &CART2::legacy_resolve_order_property($order1key);
	if (not defined $order2key) {
		warn Carp::cluck("Missed legacy_order_get resolve for field '$order1key' key:$order2key - ".join("|",caller(0))."\n");
		}
	elsif (substr($order2key,0,1) eq '*') {
		if ($order2key eq '*bill_country') { my ($info) = &ZSHIP::resolve_country('ISO'=>$self->__GET__('bill/countrycode')); return($info->{'Z'}); }
		if ($order2key eq '*ship_country') { my ($info) = &ZSHIP::resolve_country('ISO'=>$self->__GET__('ship/countrycode')); return($info->{'Z'}); }
		}
	else {
		return($self->pu_get($order2key));
		}
	}

## LEGACY CART
sub legacy_order_set {
	my ($self, $order1key, $value) = @_;
	## try and find the property
	my ($order2key) = &CART2::legacy_resolve_order_property($order1key);
	if (not defined $order2key) {
		warn "Missed legacy_order_set resolve for field '$order1key' - ".join("|",caller(0))."\n";
		}
	elsif (substr($order2key,0,1) eq '*') {
		if ($order2key eq '*bill_country') { my ($info) = &ZSHIP::resolve_country('ZOOVY'=>$value); return($self->__SET__("bill/countrycode",$info->{'ISO'})); }
		if ($order2key eq '*ship_country') { my ($info) = &ZSHIP::resolve_country('ZOOVY'=>$value); return($self->__SET__("ship/countrycode",$info->{'ISO'})); }		
		}
	else {
		return($self->in_set($order2key,$value));
		}
	}







##############################################################################
##
## CART::empty
##
## Purpose: Empty the cart
##
## Accepts: level bitwise:
##			1 = destroy !meta
##			2 = remove login
##
## Returns: Nothing (It modifies the cart directly)
##
## params
##		reason=>"string why"	ex: kill_cookies
##		scope=>order|all
##
sub empty {
	my ($self, %params) = @_;

	foreach my $item (@{$self->stuff2()->items()}) {
		$self->stuff2()->drop('uuid'=>$item->{'uuid'});
		}

	$self->paymentQ([]); ## clear the paymentQ

	delete $self->{'%ship'};
	delete $self->{'%bill'};
	$self->{'*stuff2'} = STUFF2->new($self->username());
	delete $self->{'%sum'};

	## nuke the cart
	$self->in_set("cart/previous_cartid",$self->cartid());

	$self->reset_session("CART_EMPTY");		## hmm, this will almost certainly cause the cart id to flip.
	delete $self->{'%coupons'}; 		# clear any coupons

	push @{$self->{'@CHANGES'}}, [ 'empty' ];
	$self->__SYNC__();	
	}



##############################################################################
##
## CART::update_quantities
##
## Purpose: Updates the cart with a set of new quantities
## Accepts: A reference to a hash of SKU=>quantity
## Returns: Nothing (It modifies the cart directly)
##
#sub update_quantities {
#	my ($self,$quantities) = @_;
#	
#	warn "CART2->update_quantities is not implemented\n";
#
#	### *** NEEDS LOVE ***	
#	# my ($changes) = $self->stuff2()->update_quantities($quantities);
#	
#	#delete $self->{'ship'}; ## Clear any cached totals, shipping info
#	## NOTE: if we don't flush the ship. keys then bad stuff happens.
#	##			I THINK THIS WAS DUE TO A BUG IN THE CHECKSUM NOT USING STUFF->DIGEST
#	#foreach my $k (keys %{$self}) {
#	#	if ($k =~ /^ship\./) { delete $self->{$k}; }
#	#	}
#	#if ($changes) {
#	#	$self->{'modified'}++;
#	#	$self->{'modified_gmt'} = time();
#	#	$self->{'need_update_shipping'}++;
#	#	$self->recalc();
#	#	$self->shipping();
#	#	$self->save();
#	#	}
#	return({});
#	}
#



sub digest {
	my ($self, $SET) = @_;

	my @DIGESTABLE = ();
	push @DIGESTABLE, $self->hashref_to_digestables('ship');
	push @DIGESTABLE, $self->hashref_to_digestables('bill');
	push @DIGESTABLE, $self->hashref_to_digestables('sum');
	push @DIGESTABLE, $self->hashref_to_digestables('this');
	push @DIGESTABLE, $self->__GET__('want/shipping_id');
	foreach my $item (@{$self->stuff2()->items('')}) { 
		push @DIGESTABLE, "$item->{'stid'}|$item->{'qty'}|$item->{'price'}|$item->{'weight'}"; 
		}


	# my $digest = Digest::MD5::md5_base64(Encode::encode_utf8(join("|",@DIGESTABLE)));
	my $digest = join("|",@DIGESTABLE);

	return($digest);
	}


#######################################################
##
## 1 = cod payment changed
##	2 = payment changed
##	4 = shipping changed
##	8 = insurance changed
## 16 = bonding changed.
## 32 = shipping
## 64 = billing
## 128 = items in the cart
## 256 = a required field was not completed.
## 512 = (set in checkout for a banned cart)
##
#sub digest_has_changed {
#	my ($self,$olddigest,$nowdigest) = @_;
#
#	my $cart_changed = 0;
#
#	if (not defined $nowdigest) {
#		$nowdigest = $self->digest();
#		}
#
#	my @previous = ();
#
#	## so if we passed in "current" then compare that to the existing checksum and generate
#	##	a cart_changed value (which contains the difference)
#
#	my @previous = split(/\|/,$olddigest);
#	my @current = split(/\|/,$nowdigest);
#	$cart_changed = 0;
#	foreach my $i (0..8) {
#		next if ($previous[$i] eq $current[$i]);
#		$cart_changed += (1 << $i);
#		}
#	
#	return($cart_changed);
#	}


##
##
##
sub checksum {
	my ($self,$olddigest) = @_;

	warn "RAN OLD CHECKSUM CODE\n";

	my $nowdigest = $self->digest();
	my ($cart_changed) = $self->digest_has_changed($olddigest,$nowdigest);

	return($cart_changed,$nowdigest);
	}


##############################################################################
##
## CART->count()
##
## Purpose: Counts the items in the cart
## Accepts: An optional cart hash (defaults to using the current cart's)
## Returns: The total number items in the cart, not counting invisible !skus
##
sub count {
	my ($self) = @_;
	
	if (not defined $self) {
		warn "self was not defined when calling CART->count() - returning -1\n";
		return(-1); 
		}
	elsif (not defined $self->stuff2()) {
		warn "self->stuff2() was not defined when calling CART->count() - returning -2\n";
		return(-2); 
		}

	return $self->stuff2()->count('show'=>'');
	}





##
## this function sets all the appropriate shipping fields based on the selected id/name
##
## selector can be:
##		'id' => the shipmethod identifier
##		
##		
##
sub set_shipmethod {
	my ($self, $new_id) = @_;

	my $prior_id = '';
	if (not $self->is_marketplace_order()) {
		## prior shipping method often causes a recalc of methods (if we weren't already in sync)
		$prior_id = $self->in_get('want/shipping_id');
		}
			
	my $prior_method = undef;
	my $new_selected_method = undef;
	my $default_method = undef;

	my $i = 0;
	foreach my $shipmethod (@{ $self->shipmethods() }) {
		$i++;

		if ($new_id eq '') {}
		elsif (defined $new_selected_method) {}
		elsif ($shipmethod->{'id'} eq $new_id) { $new_selected_method = $shipmethod; }
		elsif ($shipmethod->{'pretty'} eq $new_id) { $new_selected_method = $shipmethod; }   # the old way of doing things, match by pretty name
		elsif ($shipmethod->{'name'} eq $new_id) { $new_selected_method = $shipmethod; }   # the old way of doing things, match by pretty name

		if ($prior_id eq '') {}
		elsif (defined $prior_method) {}
		elsif ($shipmethod->{'id'} eq $prior_id) { $prior_method = $shipmethod; }
		elsif ($shipmethod->{'pretty'} eq $prior_id) { $prior_method = $shipmethod; }   # the old way of doing things, match by pretty name
		elsif ($shipmethod->{'name'} eq $prior_id) { $prior_method = $shipmethod; }   # the old way of doing things, match by pretty name
	
		if (defined $default_method) {}
		else {
			## defaultable is really only a big deal for a few carrier codes, specifically customer pickup (CPU)
			my $carrier = $shipmethod->{'carrier'};
			if (not defined $carrier) {}
			elsif (not defined $ZSHIP::SHIPCODES{ $carrier }) { 
				$default_method = $shipmethod; 
				}	# unknown carriers are defautable
			elsif (defined $ZSHIP::SHIPCODES{ $carrier }->{'defaultable'}) { 
				# carriers which have defaultable defined
				if ($ZSHIP::SHIPCODES{ $carrier }->{'defaultable'}) {
					$default_method = $shipmethod;
					}
				}
			else { 
				# defualt to defaultable
				$default_method = $shipmethod; 
				} 
			}
		}

	if ($self->in_get('sum/items_count')<=0) {
		## no need to cluck, we have no items, this is not an issue.
		}
	elsif ($i==0) {
		# warn Carp::cluck("no shipping methods were returned to set_shipmethod\n");
		}
	
	## sanity: at this point the following should be true ..
	##		* $prior_id contains a scalar of the id of the previously selected shipping method
	##		* $prior_method is a reference to the previously chosen $shipmethod (or undef if none)
	##		* $new_id contains a blank (if no implicit value was set)
	##		* $new_selected_method contains the method (if any) referenced by $new_id 
	##		* $default_method is set to the first defaultable method in the $shipmethods array

	if (($new_id ne '') && (not defined $new_selected_method)) {
		# the shipping method the user selected was not available! (uhoh)
		warn "shipping method: '$new_id' no longer available\n";
		$new_id = '';
		}

	if (($prior_id ne '') && (defined $prior_method)) {
		## we had a prior choice
		if ($new_id eq '') { $new_id = ''; $new_selected_method = $prior_method; }
		}

	if (($new_id eq '') && (defined $default_method)) {
		## we still don't have a $new_id, so we should default to something
		$new_id = $default_method->{'id'};  $new_selected_method = $default_method;
		}


#	# print STDERR Dumper($new_selected_method);
#	open F, ">/tmp/cart.".time();
#	print F Dumper($new_selected_method,$self);
#	close F;

	if (defined $new_selected_method) {
		$self->in_set('want/shipping_id',$new_id);
		$self->in_set('sum/shp_total',$new_selected_method->{'amount'});  # set ship.selected_price from methods{$sel
		$self->in_set('sum/shp_carrier',$new_selected_method->{'carrier'});
		$self->in_set('sum/shp_method',$new_selected_method->{'name'});
		}
	else {
		$self->in_set('want/shipping_id','');
		$self->in_set('sum/shp_total',undef);
		$self->in_set('sum/shp_carrier',undef);
		$self->in_set('sum/shp_method',undef);
		}

	return($new_id);	
	}



##############################################################################
## CART2::is_pobox
##
##	returns: 0 for no, 1 for yes, -1 for unknown! (no address)
##
sub is_pobox {
	my ($self) = @_;

	my $STATE = $self->__GET__('ship/region');
	if (($STATE eq 'AA') || ($STATE eq 'AE') || ($STATE eq 'AP')) {
		## APO/FPO armed force states
		return(10);
		}

	my $ADDRESS1 = $self->__GET__('ship/address1');	
	my $ADDRESS2 = $self->__GET__('ship/address2');	

	if ((not defined $ADDRESS1) && (not defined $ADDRESS2)) { return(-1); }
	if (($ADDRESS1 =~ m/\bP\.?O\.?(\b|BOX)/i) || ($ADDRESS2 =~ m/\bP\.?O\.?(\b|BOX)/i)) {
		return(1);
		}
	elsif ($ADDRESS1 =~ m/^POB [\d]+/) {
		return(2);
		}
	elsif ($ADDRESS1 =~ m/PO BOX/) {
		return(3);
		}
	return(0);
	}




## REMOVE THIS LATER
#sub shipping {
#	warn Carp::cluck("called legacy shipping method in CART2\n");
#	return(CART2::shipmethods(@_));
#	}


##
## this is used by marketplaces it's intended a placeholder .. but it sets up the various fields inside the object
##	to FORCE this choice for shipping ..
##
sub set_mkt_shipping {
	my ($self, $pretty, $price, %options) = @_;

	if ($self->is_marketplace_order()) {
		}
	elsif ($self->is_staff_order()) {
		}
	elsif ($self->in_get('must/payby') eq 'GOOGLE') {
		}
	elsif ($self->in_get('must/payby') eq 'AMZCBA') {
		}	
	else {
		&ZOOVY::confess($self->username(),"FATAL - called set_mkt_shipping without is_marketplace_order being set");
		}

	my $carrier = $options{'carrier'};
	my $id = $options{'id'};
	my $tax_on_ship = $options{'tax'}; 

	## *** NEEDS LOVE *** (tax on shipping)
	my $SHIP_METHOD_ROW = &ZSHIP::build_shipmethod_row($pretty,$price,'carrier'=>$carrier);
	$self->{'@shipmethods'} = [ $SHIP_METHOD_ROW ];
	$self->set_shipmethod( $SHIP_METHOD_ROW->{'id'} );
	return();
	}


##
## function: shipmethods
## this is guaranteed to return an array (so it's safe to do for $method (@{$CART->shipmethods()}) {
##	which is better than @{$CART->fetch_property('@shipmethods'))}
##
## shipmethods has:
##		name
##		amount
##		carrier
##		id
##
## tbd=>1 		- if true, and no shipping methods are available, then actual cost to be determined is added
##	strip_errors=>1 - if true, then any methods carrier=>'ERR' are removed (this might trigger a worst case result)
##	selected_only=>1 - if true, only returns selected methods means you can do ($selected_shipmethod) = $CART->shipmethods('selected_only'=>1)
##							 NOTE: will return blank if we' haven't selected a best match
##	sub universal_ship 
##	sub shipping_methods
## sub ship_methods
sub shipmethods {
	my ($self,%options) = @_;

	## make sure we're dealing the latest shipping methods
	if (defined $options{'__SYNC__'}) {
		## don't call __SYNC__ if we're __SYNC__
		}
	else {
		$self->__SYNC__();
		}

	if ($self->site()->client_is() eq 'BOT') { 
		$CART2::DEBUG && warn "__SYNC__ disabled for BOT\n";
		return();
		}

	my $CART2 = $self;
	my $hostname = &ZOOVY::servername();
	#if (($hostname eq 'newdev') || ($CART2->is_debug())) {
	#	if (not defined $CART2->msgs()) {
	#		require LISTING::MSGS;
	#		$CART2->msgs(LISTING::MSGS->new($CART2->username()));
	#		}
	#	$CART2->debug('ship.warn',2,'NEWDEV RULES ENGAGED - STORING SHIP DEBUG IN CART.');
	#	}

	## LONG TERM WE MIGHT WANT TO PRESERVE ADMIN METHODS
	#my @ADMIN_SHIPMETHODS = ();
	#if (defined $self->{'@shipmethods'}) {
	#	foreach my $shipmethod (@{$self->{'@shipmethods'}}) {
	#		if ($shipmethod->{'is_admin'}) {
	#			push @ADMIN_SHIPMETHODS, $shipmethod;
	#			}
	#		}
	#	}

	my $RECALCULATE = 0;
	#if ((not defined $CART2->{'@shipmethods'}) || (scalar(@{$CART2->{'@shipmethods'}})==0)) {
	#	if (
	#	$RECALCULATE |= 0xFF;
	#	}

	if ($options{'flush'}) {
		$RECALCULATE |= 1;
		}
	elsif ($self->is_order() && ($options{'force_update'})) {
		## there are cases, ex: recomputing shipping on an order where __SYNC__ won't actually update our shipping methods
		## in those cases we implicitly pass 'force_update'=>1
		$RECALCULATE |= 2;

		#if (scalar(@{$SHIPMETHODS})==0) {
		#	push @{$SHIPMETHODS}, ZSHIP::build_shipmethod_row('Actual cost to be determined',0,carrier=>'ERR');
		#	}
		#$self->{'@shipmethods'} = $SHIPMETHODS;
		}

	if ($self->is_marketplace_order()) {
		## we don't update shipping for marketplace orders (they tell us what the shipping should be)
		}
	elsif ($self->is_cart()) {
		if (not defined $CART2->{'%digests'}) { $CART2->{'%digests'} = {}; }
		my $olddigest = $CART2->{'%digests'}->{'shipmethods'};

		my @DIGESTABLE = ();
		push @DIGESTABLE, $self->hashref_to_digestables('ship');
		push @DIGESTABLE, $self->__GET__('want/shipping_id');
		foreach my $item (@{$self->stuff2()->items('')}) { push @DIGESTABLE, "$item->{'stid'}|$item->{'qty'}|$item->{'price'}|$item->{'weight'}"; }
		my $newdigest = Digest::MD5::md5_base64(Encode::encode_utf8(join("|",@DIGESTABLE)));

		if ($olddigest ne $newdigest) {
			$RECALCULATE |= 16; 
			$CART2->{'%digests'}->{'shipmethods'} = $newdigest;
			}
		}


	#if ($hostname eq 'newdev') {
	#	$CART2->debug('ship.dev',0,"NEWDEV PROHIBITED RESPONSE OF CACHED SHIPMETHODS");
	#	$RECALCULATE |= 128;
	#	}

	if (($RECALCULATE > 0) && ($self->has_site())) {
		if ($self->site()->client_is() eq 'BOT') { 
			warn "BOT requested shipping, so I said no.\n";
			$RECALCULATE = 0; 
			}
		}

	$self->is_debug() && $CART2->msgs()->pooshmsg("INFO|+RECALCULATE:$RECALCULATE");

	my $shipmethods = undef;
	if (not $RECALCULATE) {
		$self->is_debug() && $CART2->msgs()->pooshmsg("INFO|+DID NOT RECALCULATE (USING CACHED SHIPMETHODS) -- ".join("/",caller(0))."\n"); 
		if (not defined $CART2->{'@shipmethods'}) {
			$CART2->{'@shipmethods'} = [];
			}
		$shipmethods = $CART2->{'@shipmethods'};
		}
	elsif ($self->is_marketplace_order()) {
		## this is just here to fix stupidity where we accidentally add a RECALCULATE case that shouldn't trigger this.
		## it avoids us having to cleanup orders, i know it's redundant -- that's the whole fucking point. bh
		$self->is_debug() && $CART2->msgs()->pooshmsg("WARN|+RECALCULATE WAS CALLED ON A MARKETPLACE ORDER -- SO IT WAS IGNORED");
		}
	elsif ($self->is_staff_order()) {
		$self->is_debug() && $CART2->msgs()->pooshmsg("WARN|+RECALCULATE WAS CALLED ON A STAFF ORDER -- SO IT WAS IGNORED");
		}
	else {
		my $WEBDBREF = $self->webdb();
	
		$self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+ship.dev 1 UNIVERSAL SHIP CALLER: ".join('!',caller(1)));	
		my $country = $self->__GET__('ship/countrycode');
		if ($country ne '') {
			## yay - we have a country set.
			#if (($country ne 'US') && ($self->__GET__('ship/postal_int') eq '') && ($self->__GET__('ship/postal') ne '')) {
			#	## but we apparently set the zip code wrong.
			#	$self->__SET__('ship/int_zip', $self->__GET__('ship/postal'));
			#	}
			}
		elsif ($self->__GET__('ship/postal') ne '') { 
			$country = 'US'; 
			$self->__SET__('ship/countrycode',$country); 
			}
		else {
			## DEFAULT COUNTRY (eventually might be non-us)
	      $country = 'US';
	      $self->__SET__('ship/countrycode',$country);
			}
		
		$self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+ship.info 0 SHIP COUNTRY:$country");
		my $metaref = {};	#
	
	
		########################### BEGIN VIRTUAL PRODUCT CODE ###########################
		## we never do virtualization on external calls!
	
		####################################################################
		$self->is_debug() && $CART2->msgs()->pooshmsg("TITLE|+*** PHASE1: SORT INTO PACKAGES ***"); 	
		####################################################################
	
		# my @EBAY_VIRTS = ();
		# my @COUPON_STIDS = ();
		my %SHIPPING_GROUPS = ();
		foreach my $item (@{$CART2->stuff2()->items()}) {
			##
			## shipdsn is 'virtual_ship'
			##		
			$item->{'shipdsn'} = '';
	
			my $virtual ='';
			if ($item->{'virtual_ship'} ne '') { 
				$virtual = $item->{'virtual_ship'}; 
				$self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+ITEM STID \"$item->{'stid'}\" has virtual_ship defined: ".$virtual); 			
				}
			elsif ($item->{'virtual'} ne '') { 
				$virtual = $item->{'virtual'};	
				$self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+ITEM \"$item->{'stid'}\" has virtual defined: ".$virtual); 				
				}
	
			## figure out if we've got an alternate shipping provider for this supplier
			if ((substr($item->{'stid'},0,1) eq '%') || ($item->{'is_promo'})) {
				## ignore promotional items with no weight, for the purpose of shipping.
				##  push @COUPON_STIDS, $item->{'stid'};
				if ($item->{'weight'} == 0) {
					$self->is_debug() && $CART2->msgs()->pooshmsg("WARN|+STID \"$item->{'stid'}\" is a promo item and will not be given it's own package."); 
					$virtual = 'NULL';
					}
				}
			elsif (index($item->{'asm_master'},'*')>=0) { 
				## figure out if the item is part of a claim launched to a marketplace, 
				##		if so, then the parent item will define shipping.
				##	NOTE: we might eventually want to actually *CHECK* the parent to make sure
				##			this is an ebay listing.
				$self->is_debug() && $CART2->msgs()->pooshmsg("WARN|+STID \"$item->{'stid'}\" is part of marketplace assembly master; setting virtual=NULL");
				$virtual = 'NULL'; 
				}
			elsif (($item->{'special'}>0) && ($item->{'weight'}==0)) {
				## promotion items !DISC, and %PROMO don't get shipping added when the weight is zero.
				$self->is_debug() && $CART2->msgs()->pooshmsg("WARN|+STID \"$item->{'stid'}\" is special=$item->{'special'} and weight==0 (probably a promotion); setting virtual=NULL");
				$virtual = 'NULL';
				}
			elsif ($virtual eq '') { 
				## sometimes virtual is blank (e.g. special promotion items)
				$virtual = 'LOCAL'; 
				}
	
			## virtual is either "LOCAL" or it's a MODE:CODE
			if ($virtual eq 'LOCAL') {
				## LOCAL IS A RESERVED SUPPLIER TYPE
				}
			elsif ($virtual eq 'NULL') {
				## promo's, marketplace assembly masters, weight of zero
				}
			#elsif ($virtual =~ /^EBAY\:/) {
			#	## EBAY IS A RESERVED SUPPLIER TYPE
			#	push @EBAY_VIRTS, $virtual;
			#	}
			elsif ($virtual =~ /^FIXEDPRICE\:([\d]+)$/) {
				## secondact uses FIXEDPRICE:AMOUNT
				}
			elsif ($virtual =~ /^GIFTCARD$/) {
				# { USERNAME=>$USERNAME, MID=>$MID, MODE=>"GIFTCARD", FORMAT=>"GIFTCARD", '.api.dispatch_on_create'=>0 };
				}
			elsif ($virtual =~ /^(SUPPLIER|GENERIC|API|PARTNER|)\:([A-Z0-9]+)$/) {
				## supplier GENERIC|API|PARTNER are all types of "SUPPLIERS"
				## NOTE: :value is not technically valid, but is used by at least bamtar
				my ($MODE,$CODE) = ($1,$2);
				$CODE = uc($CODE);
	
				my $S = $self->getSUPPLIER($CODE);
				## by default each supplier items will be grouped by the supplier code to calculate shipping
				## STOCK suppliers always ship from our warehouse, so they are really LOCAL
				## if no shipping methods are configure we treat the supplier as LOCAL
				#if ($resultref->{'MODE'} eq 'JEDI') {
				#	## yeah, so JEDI will always use JEDI (no way to override this)
				#	}
				if ((defined $S) && (ref($S) eq 'SUPPLIER')) {
					$virtual = sprintf("SUPPLIER:%s?connector=%s",$CODE,$S->ship_connector());
					}
				else {
					$S = undef;
					}

				if (not defined $S) {
					$CART2->msgs()->pooshmsg("ERROR|+SUPPLIER \"$CODE\" is invalid.");
					}
				elsif ($S->ship_connector() eq 'NONE') {
					$virtual = 'LOCAL';
					}
				elsif ($S->format() eq 'STOCK') {
					## stock suppliers always ship from our local warehouse
					$virtual = 'LOCAL';	
					}
				#elsif ($S->fetch_property('.ship.methods')==4) { 
				#	## use API shipping (e.g. PARTNER:DOBA)
				#	}
				elsif ($S->fetch_property('.ship.methods')==0) { 
					## this is *probably* a bad idea, but we'll default to local if we have no other methods.
					$virtual = 'LOCAL'; 
					}
				else {
					## leave britney^H^H^H^H^H^Hvirtual alone!!!
					}
			
				if (not defined $S) {
					$self->is_debug() && $CART2->msgs()->pooshmsg("ERROR|+SUPPLIER \"$CODE\" did not set proper group");
					$virtual = "LOCAL";
					}
				elsif (($S->fetch_property('.ship.options')&1)==1) {
					## append a unique uuid to the virtual so the item gets it's own package.
					if (index($virtual,'?')>0) {
						$virtual = "$virtual&uuid=$item->{'uuid'}";
						}
					else {
						$virtual = "$virtual?uuid=$item->{'uuid'}";
						}
					}

#				open F, ">>/tmp/theory";
#				print F "ITEM: $item->{'uuid'} --- $virtual ($SHIP_OPTIONS) $CODE\n";
#				# print F Dumper($S);
#				close F;
	
				# print STDERR "MODE=$MODE CODE=$CODE virtual=$virtual\n";
				$self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+RESULT SUPPLIER \"$CODE\" for stid \"$item->{'stid'}\" uses \"$virtual\" method"); 
				}
			#elsif ($virtual =~ /^FORMULA:(.*?)$/) {
			#	## wow.. so they coded a shipping formula directly into here.
			#	##	so how does a formula work well.. 
			#	&ZOOVY::confess($CART2->username(),"LEGACY DEPRECATED FORMULA $virtual",justkidding=>1);
			#	}
			else {
				$virtual = "ERROR?was=$virtual";
				## hmm... 
				}
	
			$self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+SORT \"$item->{'stid'}\" into \"$virtual\" package"); 			
			if (not defined $SHIPPING_GROUPS{$virtual}) { $SHIPPING_GROUPS{$virtual} = []; }
			push @{$SHIPPING_GROUPS{$virtual}}, $item;
		
			# print STDERR "VIRTUAL METHOD: $virtual\n";
	
			## a virtual of "LOCAL" means to loopback and use the store rates.
			## note: since it's still technically a virtual item it has a @stid, we need to treat it special
			}
	
	
		## 
		## COMPUTE PACKAGES (AT THIS POINT EACH VIRTUAL IS IT'S OWN PACKAGE)
		## 
		my @PACKAGES = ();
		foreach my $GROUPID (keys %SHIPPING_GROUPS) {
			next if ($GROUPID eq 'NULL');	
			push @PACKAGES, STUFF2::PACKAGE->new($CART2,$GROUPID,'@ITEMS'=>$SHIPPING_GROUPS{$GROUPID});	
			}

		if (scalar(@PACKAGES)==0) {
			$metaref->{'ERROR'} = 'No items in cart';
			}

      my $qs = int($self->webdb()->{'cart_quoteshipping'});
		my $quotewithoutzip = (($qs == 1) || ($qs == 3) || ($qs==4)) ? 1 : 0;
		if ($quotewithoutzip) {}	## we can keep going
		elsif (($self->__GET__('ship/countrycode') eq 'US') && ($self->__GET__('ship/postal') eq '')) { $metaref->{'ERROR'} = "Partition settings - do not allow rate quotes to Domestic locations without zip code"; }
		elsif (($self->__GET__('ship/countrycode') ne 'US') && ($self->__GET__('ship/postal') eq '')) { $metaref->{'ERROR'} = "Partition settings - do not allow rate quotes to International locations without zip code"; }
	
		# print STDERR "----------------------------------PACKAGES---------------------------------\n".Dumper($CART2,\@PACKAGES);

		$self->{'@PACKAGES'} = \@PACKAGES;
		if ($CART2->is_debug()) { 
			my $i = 0;
			foreach my $package (@PACKAGES) {
				my @DETAIL = ();
				my $packageid = $package->id();
				foreach my $item ( @{$package->{'@ITEMS'}} ) {
					push @DETAIL, sprintf("%s qty %d",$item->{'sku'},$item->{'qty'});
					}
				$self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+PACKAGE($packageid)#$i: ".join(",",@DETAIL)." \n"); 
				}
			}
		
	
		####################################################################
		$self->is_debug() && $CART2->msgs()->pooshmsg("TITLE|+*** PHASE2: RATE PACKAGES ***"); 	
	
		####################################################################
	
	
		####################################################################
		## now go through the shipping groups and create packages
	
		########################################################
		## SANITY: at this point SHIPMENTS is a hashref, the '' key is the zoovy items, other keys are virtuals
		##				now we iterate through the virtuals.
		##				NOTE: $item->{'full_product'} is guaranteed to be populated!
	
		foreach my $PKG (@PACKAGES) {
			$self->is_debug() && $CART2->msgs()->pooshmsg("SUBTITLE|+PROCESSING PACKAGE:".$PKG->id());
			if ((defined $metaref->{'ERROR'}) && ($metaref->{'ERROR'} ne '')) {
				my $groupid = $PKG->id();
				$self->is_debug() && $CART2->msgs()->pooshmsg("WARN|+SKIPPED SHIPMENT:$groupid because of error: $metaref->{'ERROR'}");
				}	# if we had an error - STOP
			#if ((defined $METAREF->{'ERROR'}) && ($METAREF->{'ERROR'} ne '')) {
			#	# if we had an error - STOP
			#	$PKG->pooshmsg("STOP|+SHIPMENT:$groupid because of error: $METAREF->{'ERROR'}");
			#	}	
			else {
				$PKG->calculate_rates($self);
				if ($self->is_debug()) {
					$CART2->msgs()->merge( $PKG->lm() );
					}

				my ($pkg_shipmethods) = $PKG->shipmethods();
				if (defined $metaref->{'ERROR'}) {
					}
				elsif (scalar(@{$pkg_shipmethods})<=0) {
					$metaref->{'ERROR'} = 'No rates returned from calculate_rates.';
					$PKG->pooshmsg(sprintf("ERROR|+%s",$metaref->{'ERROR'}));
					}
				else {
					if ($self->is_debug()) {
						my $i = 0;
						foreach my $method (@{$pkg_shipmethods}) {
							$CART2->msgs()->pooshmsg(sprintf("TRACE|+PACKAGE(%s) RATE#%d: %s",$PKG->id(),++$i,&ZOOVY::debugdump($method)));
							}
						$CART2->msgs()->pooshmsg(sprintf("WIN|+PACKAGE(%s) got %d shipping rates",$PKG->id(),scalar(@{$pkg_shipmethods})));						
						}
					}
				}
			# print STDERR $PKG->pretty_dump();
			}
	
	
		# $self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+debug 0 SHIPPING_GROUPS:'.Dumper(\%SHIPPING_GROUPS));
	
		####################################################################
		$self->is_debug() && $CART2->msgs()->pooshmsg("TITLE|+*** PHASE3: SORT+MERGE SHIPPING ***"); 	
		####################################################################
	
		
		my @RESULTS = ();
		if (defined $metaref->{'ERROR'}) {
			## shit alraedy happened.
			}
		elsif (scalar(@PACKAGES)==1) {
			## yay, only one provider
			$self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+ship.info 2 SINGLE RESULT");
			(@RESULTS) = @{$PACKAGES[0]->shipmethods()};
			}
		else {
			## two or more packages
			$self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+ship.info 2 COMBINATION RESULT");
	
			## hmm, only one shipping method and it's virtual - lets present all methods to the user.
			## this is sort of a cheap hack.
			# $shipref = \%m;
			## actually - if we leave VIRTUAL_SHIPPING to zero, we'll overwrite shipref with "Shipping"
			##		so we'd better set it back to undef;
			## find the lowest rate
			#foreach my $key (keys %m) {
			#	if (not defined $lowest) { $lowest = $m{$key}; }
			#	elsif ($lowest > $m{$key}) { $lowest = $m{$key}; }
			#	}
	
			my $TOTAL_SHIPPING = 0;
			foreach my $PKG (@PACKAGES) {
				my $lowest = undef;
				foreach my $shipmethod (@{$PKG->shipmethods()}) {
					if (not defined $lowest) { $lowest = $shipmethod; }
					elsif ($lowest->{'amount'} > $shipmethod->{'amount'}) { $lowest = $shipmethod; }
					}
				$self->is_debug() && $CART2->msgs()->pooshmsg(sprintf("TRACE|+ship.info 2 PACKAGEID:%s Selected method:%s",$PKG->id(),Dumper($lowest)));			
				$TOTAL_SHIPPING += $lowest->{'amount'};
				delete $PKG->{'*CART2'};
				}
			$self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+ship.info 1 Total Combined Shipping is:$TOTAL_SHIPPING");
	
			###############################
			## SANITY: at this point VIRTUAL_SHIPPING is the sum of all the lowest shipping methods
			###############################
			@RESULTS = &ZSHIP::build_shipmethod_row('Shipping', $TOTAL_SHIPPING, 'carrier'=>'SLOW' );
			}
	
		## print STDERR '------------------POST PACKAGES:-----------------'.Dumper(\@PACKAGES);
	
		## RESTORE THE CART:
		## NOTE: SHIPMENTS{''} may not always be defined, especially if we only have virtuals.
	
		############################################################
		## SANITY: at this point the cart might actually have a different set of STUFF in it (just local stuff)
		##				so we can quote that without worrying about the virtual stuff
		# die("VIRTUALS!!!");
		undef %SHIPPING_GROUPS;
		########################### END VIRTUAL PRODUCT CODE ###########################
		
	
		#######################################
		## Handling
		#######################################
	
		####################################################################
		$self->is_debug() && $CART2->msgs()->pooshmsg("TITLE|+*** PHASE4: GLOBAL HANDLING/INSURANCE ***"); 	
		####################################################################
	
		my $area = '';
		if ($country eq 'US') { $area = 'dom'; }
		elsif ($country eq 'CA') { $area = 'can'; }
		else { $area = 'int'; }
	
		## print STDERR "!!!!!!!!!!!!!!!!!!!!!! HANDLING:  $WEBDBREF->{'handling'}\n";
		if (not defined $WEBDBREF->{'handling'}) { $WEBDBREF->{'handling'} = 0; }

		if (defined $metaref->{'ERROR'}) {
			warn "CART2->shipmethods() ERROR: $metaref->{'ERROR'}\n";
			}	# if we had an error - STOP
		elsif ($WEBDBREF->{'handling'}>0) {
			if ($CART2->is_debug()) { $self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+ship 1 Entered handling computation"); }
			require ZSHIP::HANDLING;
			my $HANDLING = 0;
	
			if (not defined $WEBDBREF->{'hand_flat'}) { $WEBDBREF->{'hand_flat'} = 0; }
			if (not defined $WEBDBREF->{'hand_product'}) { $WEBDBREF->{'hand_product'} = 0; }
			if (not defined $WEBDBREF->{'hand_weight'}) { $WEBDBREF->{'hand_weight'} = 0; }
			if ($WEBDBREF->{'hand_flat'}>0) {
				$HANDLING += &ZSHIP::HANDLING::calc_flat($area,'hand',$CART2,$WEBDBREF);
				}
	
			if ($WEBDBREF->{'hand_product'}>0) {
				$HANDLING += &ZSHIP::HANDLING::calc_product($area,'zoovy:ship_handling',$CART2,$WEBDBREF);
				}
	
			if ($WEBDBREF->{'hand_weight'}>0) {
				$HANDLING += &ZSHIP::HANDLING::calc_weight($area,'hand',$CART2,$WEBDBREF);
				}
	
			($HANDLING) = &ZSHIP::RULES::do_ship_rules($CART2, $CART2->stuff2(), "HANDLING", $HANDLING);
			## print STDERR "HANDLING: $HANDLING\n";

			# $WEBDBREF->{'handling'} = 2;
			if (not defined $HANDLING) {
				## Hmm.. the rules must have deleted this!
				$self->is_debug() && $CART2->msgs()->pooshmsg("WARN|+HANDLING WAS DISABLED (probably due to rules or complete misconfiguration)"); 				
				$CART2->in_set('sum/hnd_total',undef);
				$CART2->in_set('sum/hnd_method','');
				}
			elsif ($WEBDBREF->{'handling'}==1) {
				$CART2->in_set('sum/hnd_total',undef);
				$CART2->in_set('sum/hnd_method',undef);
				foreach my $shipmethod (@RESULTS) { 
					if ($shipmethod->{'name'} eq '') {
						}
					elsif (defined $shipmethod->{'handling'}) {
						## this shipping method already has handling.
						}
					else {
						## apply global handling.
						$self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+HANDLING of $HANDLING being added into shipping method: $shipmethod->{'name'} (original amount:$shipmethod->{'amount'})"); 				
						$shipmethod->{'handling'} = $HANDLING;
						$shipmethod->{'amount_before_handling'} = $shipmethod->{'amount'};
						$shipmethod->{'amount'} += $HANDLING;
						}
					}
				$HANDLING = 0;
				}
			else {
				$self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+HANDLING is: \$$HANDLING"); 				
				$CART2->in_set('sum/hnd_total',$HANDLING);
				$CART2->in_set('sum/hnd_method','Handling');
				}
			}
	
		#########################################
		## Insurance
		##		NOTE: we *always* compute insurance even if it's optional!
		##				then we add it to the order if webdb->{'ins_optional'} is true AND cgi.ins_purchased is true!
		#########################################
		if (not defined $WEBDBREF->{'insurance'}) { $WEBDBREF->{'insurance'} = 0; }
		if (defined $metaref->{'ERROR'}) {}	# if we had an error - STOP!
		elsif ($WEBDBREF->{'insurance'}>0) {
			require ZSHIP::HANDLING;
			my $INSURANCE = 0;
			
			if (not defined $WEBDBREF->{'ins_flat'}) { $WEBDBREF->{'ins_flat'} = 0; }
			if (not defined $WEBDBREF->{'ins_product'}) { $WEBDBREF->{'ins_product'} = 0; }
			if (not defined $WEBDBREF->{'ins_weight'}) { $WEBDBREF->{'ins_weight'} = 0; }
			if (not defined $WEBDBREF->{'ins_weight'}) { $WEBDBREF->{'ins_price'} = 0; }
	
			if ($WEBDBREF->{'ins_flat'}>0) {
				$INSURANCE += &ZSHIP::HANDLING::calc_flat($area,'ins',$CART2,$WEBDBREF);
				}
	
			if ($WEBDBREF->{'ins_product'}>0) {
				$INSURANCE += &ZSHIP::HANDLING::calc_product($area,'zoovy:ship_insurance',$CART2,$WEBDBREF);
				}
	
			if ($WEBDBREF->{'ins_weight'}>0) {
				$INSURANCE += &ZSHIP::HANDLING::calc_weight($area,'ins',$CART2,$WEBDBREF);
				}
	
			if ($WEBDBREF->{'ins_price'}>0) {
				$INSURANCE += &ZSHIP::HANDLING::calc_price($area,'ins',$CART2,$WEBDBREF);
				}
	
			($INSURANCE) = &ZSHIP::RULES::do_ship_rules($CART2, $CART2->stuff2(), "INSURANCE", $INSURANCE);
	
			if (not defined $INSURANCE) {
				## Hmm.. the rules must have deleted this!
				$CART2->in_set('sum/ins_quote',undef);
				$CART2->in_set('sum/ins_total',undef);
				$CART2->in_set('sum/ins_method','');
				}
			elsif ($WEBDBREF->{'insurance'}==1) {
				## merge insurance into shipping
				# foreach my $method (keys %{$LEGACY_SHIPREF}) { $LEGACY_SHIPREF->{$method} += $INSURANCE; }
				## THIS IS A STUPID STUPID SETTING.
				my $SELECTED_SHIPPING_ID = $CART2->in_get('want/shipping_id');
				foreach my $shipmethod (@RESULTS) {
					next if ($shipmethod->{'name'} eq '');
					$shipmethod->{'insurance'} = $INSURANCE;
					$shipmethod->{'amount_before_insurance'} = $shipmethod->{'amount'};
					$shipmethod->{'amount'} += $INSURANCE;	
					if ($shipmethod->{'id'} eq $SELECTED_SHIPPING_ID) {
						## after we update the amount in the 
						$CART2->in_set('sum/shp_total',$shipmethod->{'amount'});  # set ship.selected_price from methods{$sel
						}
					}
				$INSURANCE = 0;
				}
			else {
				$CART2->in_set('sum/ins_quote',$INSURANCE);					# this is what we computed it at
				if ($WEBDBREF->{'ins_optional'}) { 
					## if it's optional, then we might want to save a zero -- unless it's been purchased!
					if (not $CART2->in_get('want/ins_purchased')) { $INSURANCE = 0; }	# none has been purchased!
					}
				$CART2->in_set('sum/ins_total',$INSURANCE);					# this is what would be added to the order (and calculated in tax)
				$CART2->in_set('sum/ins_method','Insurance');				# this is the name (for now it's hardcoded to Insurance)
				}
			}
	
		## 
		## finally, lets go through results and add any properties from SHIPINFO (such as defaultable)
		##
		foreach my $shipmethod (@RESULTS) {
			my $carrier = $shipmethod->{'carrier'};		
			if (defined $ZSHIP::SHIPCODES{$carrier}) {
				foreach my $k (keys %{$ZSHIP::SHIPCODES{$carrier}}) {
					$shipmethod->{"_$k"} = $ZSHIP::SHIPCODES{$carrier}->{$k};
					if (not defined $shipmethod->{$k}) {
						$shipmethod->{$k} = $ZSHIP::SHIPCODES{$carrier}->{$k};
						}
					}
				}
			# apperance controls the weight (ranking of items)
			$shipmethod->{'appearance'} = int($shipmethod->{'amount'}*100);
			if ((defined $shipmethod->{'defaultable'}) && ($shipmethod->{'defaultable'}==0)) {
				## if defaultable is defined, and it's 0 then we move the appearance weight to the very bottom.
				$shipmethod->{'appearance'} += 100000;
				}

			if ($shipmethod->{'amount'}<0) {
				$shipmethod->{'warning'} = "Amount was: $shipmethod->{'amount'} (not allowed, setting to zero)";
				$shipmethod->{'amount'} = 0;
				}
			}

		## make sure each shipmethod has a name+pretty
		foreach my $shipmethod (@RESULTS) {
			## not sure if this is ever necessary, but seems like a good idea.
			if ((defined $shipmethod->{'pretty'}) && (not defined $shipmethod->{'name'})) {
				## use 'name' instad of 'pretty'
				$shipmethod->{'name'} = $shipmethod->{'pretty'};
				}
			$shipmethod->{'name'} =~ s/[\s]+$//gs;
			if (not defined $shipmethod->{'id'}) {
				$shipmethod->{'id'} = uc(sprintf("%s-%s-%s",$shipmethod->{'carrier'},$shipmethod->{'pretty'},$shipmethod->{'amount'}));
				$shipmethod->{'id'} =~ s/[^A-Z0-9\-]/-/gs;
				}
			$shipmethod->{'id'} =~ s/^[\s]+//gs;	
			}

	   ## sort results
	   ## @RESULTS = sort { ($a->{'id'} <= $b->{'id'})?-1:1 } @RESULTS;
		@RESULTS = sort { ($a->{'appearance'} <= $b->{'appearance'})?-1:1 } @RESULTS;
	
		# my ($LEGACY_SHIPREF,$LEGACY_CARRIERSREF) = &ZSHIP::shipmethods_to_legacy(\@RESULTS);
	#	use Data::Dumper;
	#	print STDERR Dumper(\@RESULTS);
	
		##
		## SANITY: at this point all the hashrefs are populated, nothing will be changing.
		## 
		$shipmethods = $CART2->{'@shipmethods'} = \@RESULTS;
		## $CART->{'@cache.shipmethods'} = \@RESULTS;
		## *** NEEDS LOVE ** metaref and blurbs
		## $CART->{'%cache.ship.metaref'} = $metaref;
		## $CART->{'%cache.ship.digest'} = $CART->digest();
		undef $WEBDBREF;
	
		# open F, ">>/tmp/shipquote"; use Data::Dumper; print F Dumper({'CART'=>$CART,'shipref'=>$LEGACY_SHIPREF}); close F;
		foreach my $result (@RESULTS) {
			$self->is_debug() && $CART2->msgs()->pooshmsg("TRACE-RESULT|+".&ZOOVY::debugdump($result));
			}
		$self->is_debug() && $CART2->msgs()->pooshmsg("TRACE|+SHIPMETHODS ENDED");
		}

	##
	## at this point @shipmethods should be set to the correct (current) values
	##

	if (ref($shipmethods) ne 'ARRAY') {
		&ZOOVY::confess($CART2->username(),"NON ARRAY IN \@SHIPMETHODS RECALCULATE[$RECALCULATE]",justkidding=>1);
		$shipmethods = [];
		}

	##
	## MAKE A FRESH COPY WE CAN TRASH (WITH CRAP LIKE ACTUAL COST, ETC.)
	##
	$shipmethods = Storable::dclone($shipmethods);

	#open F, ">/tmp/asdf"; print F Dumper($shipmethods); close F;

	if ($options{'strip_errors'}) {
		## removes any shipping methods with carrier=>'ERR'
		my $shipmethods_without_errors = [];
		foreach my $shipmethod (@{$shipmethods}) {
			next if ($shipmethod->{'carrier'} eq 'ERR');
			push @{$shipmethods_without_errors}, $shipmethod;
			}
		$shipmethods = $shipmethods_without_errors;
		}

	if (($options{'tbd'}) && (scalar(@{$shipmethods})==0)) {
		## there are no shipping methods, and we need 'actual cost to be determined'
		push @{$shipmethods}, ZSHIP::build_shipmethod_row('Actual cost to be determined',0,carrier=>'ERR');
		}

	if ($options{'best_match'}) {
		## this is intended for a case such as google checkout where we've got an order and we need to match
		## it to a shipping row in the cart (so for example we end up with the right carrier)
		## pass "name" or "amount", or both (name will be used first, amount second)
		my $matched_shiprow = undef;
		## first try and match by name
		if ((not $matched_shiprow) && (defined $options{'name'})) {
			foreach my $shiprow (@{$self->shipmethods('strip_errors'=>1)}) {
				if ($shiprow->{'name'} eq $options{'name'}) { $matched_shiprow = $shiprow; }
				}
			}
		if ((not $matched_shiprow) && (defined $options{'amount'})) {
			foreach my $shiprow (@{$self->shipmethods('strip_errors'=>1)}) {
				if ($shiprow->{'amount'} eq $options{'amount'}) { $matched_shiprow = $shiprow; }
				}
			}

		if (defined $matched_shiprow) { 
			$shipmethods = [ $matched_shiprow ]; 
			}
		else {
			## hmm.. this is an error.
			$shipmethods = [];
			}
		}
	elsif ($options{'selected_only'}) {
		## only returns the selected method
		my $selected_shipmethod_only = [];
		my $selected_id = $self->in_get('want/shipping_id');
		foreach my $shipmethod (@{$shipmethods}) {
			if ($selected_id eq $shipmethod->{'id'}) { push @{$selected_shipmethod_only}, $shipmethod; }
			elsif ($selected_id eq $shipmethod->{'name'}) { push @{$selected_shipmethod_only}, $shipmethod; }
			elsif ($selected_id eq $shipmethod->{'pretty'}) { push @{$selected_shipmethod_only}, $shipmethod; }
			}
		$shipmethods = $selected_shipmethod_only;
		}

	return($shipmethods);
	}














##
## returns 
##		a customer id #
## 	@ERRS (an array of error messages)	
##
## options:
##		authenticated=>1 -- ignore password, and just login the user.
##
sub login {
	my ($self, $login, $password, %options) = @_;

	## pulled from checkout - make sure this line isn't needed
	# if ((defined $cart2{'customer/login'}) && ($cart2{'customer/login'} eq '')) { delete $cart2{'customer/login'}; }

	require CUSTOMER;

	#if (ref($self->{'customer'}) eq 'CUSTOMER') {
	#	$c = $self->{'customer'};	
	#	$cid = $c->cid(); 
	#	if ($c->prt() != $self->prt()) {
	#		warn "Oh shit.. customer object not on the same partition as this cart!";
	#		$cid = 0; $c = undef;
	#		}
	#	}

	my ($CID,$C) = (0,undef);

	my ($USERNAME) = $self->username();
	if (($CID==0) && ($login ne '') && ($options{'authenticated'})) {
		## user has already been authetnicated, no need to check password
		($CID) = &CUSTOMER::resolve_customer_id($USERNAME,$self->prt(),$login);
		if ($CID>0) { 
			}
		else {
			warn "it says we authenticated $login but that user doesn't have a CID -- wtf!??!";
			}
		}

	if (($CID==0) && ($password ne '') && ($login ne '')) {
		($CID) = &CUSTOMER::authenticate($USERNAME, $self->prt(), $login, $password);
		if ($CID>0) { 
			}
		}

	if ($CID > 0) {
		($C) = CUSTOMER->new($USERNAME,CID=>$CID,'EMAIL'=>$self->{'login'},PRT=>$self->prt(),INIT=>1+2+4+8);
		if (defined $C) {
			#$self->{'customer'} = $c;
			#$self->{'login'} = $c->fetch_attrib('INFO.EMAIL');
			#$self->{'cid'} = $cid;
			##$SITE::CART2->save_property('login',$login);
			#$self->{'login_gmt'} = time();
			#$self->{'dev.inventory_ignore'} = 0;
			#$self->{'is_wholesale'} = 0;
			## BILL and SHIP records are returned as an array of hashrefs
			## *** NEEDS LOVE ***
			$self->customer($C);
			}

		if ((defined $C) && (not defined $options{'skip_addresses'})) {

			## *TODO* edit customer records so they store the ship/postal instead of ship_zip

			## each hashref has fields such as bill_
			my $billaddr = $C->fetch_preferred_address('BILL');
			if (defined $billaddr) {
				foreach my $key (@{$billaddr->safekeys()}) {
					next if ($key eq 'bill_email');
					if ($key eq 'payment_method') {
						$self->in_set('want/payby',$billaddr->{$key});
						}
					else {
						my $value = $billaddr->{$key};
						$key =~ s/^bill_//; ## this should *HOPEFULLY* downgrade nicely if we ever switch from bill_postal to just postal
						$self->in_set("bill/$key",$value);
						## $self->in_set(&CART2::legacy_resolve_order_property("$key"),$billaddr->{$key});
						}
					}
				}

			my $shipaddr = $C->fetch_preferred_address('SHIP');
			if (defined $shipaddr) {
				foreach my $key (@{$shipaddr->safekeys()}) {
					next if ($key eq 'ship_email');
					my $value = $shipaddr->{$key};
					$key =~ s/^ship_//;	## this should *HOPEFULLY* downgrade nicely if we ever switch from bill_postal to just postal
					$self->in_set("ship/$key",$value);
					## $self->in_set(&CART2::legacy_resolve_order_property("$key"),$shipaddr->{$key});
					}
				}

			my $recs = $C->fetch_attrib('META'); 
			if ((defined $recs) && (scalar(keys %{$recs}>0))) {
				#foreach my $key (keys %{$recs}) { 
				#	$self->{'data.'.$key} = $recs->{$key}; 
				#	}
				}
			$self->in_set('bill/email',$C->fetch_attrib('INFO.EMAIL'));
			$self->in_set('ship/email',undef);	## this is stupid, no shipping email.
			}
		# $self->{'chkout.bill_to_ship'} = '0';
		## Strip out any payment info if we weren't supposed to save it.
		#if ((defined $webdbref->{'chkout_save_payment_disabled'}) && $webdbref->{'chkout_save_payment_disabled'}) {
		#	delete $self->{'cc_number'};
		#	delete $self->{'cc_exp_month'};
		#	delete $self->{'cc_exp_year'};
		#	delete $self->{'cc_cvvcid'};
		#	}
		#$self->{'data.bill_country'}  = &ZSHIP::correct_country($self->{'data.bill_country'});
		#$self->{'data.ship_country'} = &ZSHIP::correct_country($self->{'data.ship_country'});
		#$self->{'data.bill_state'}    = &ZSHIP::correct_state($self->{'data.bill_state'},$self->{'data.bill_country'});
		#$self->{'data.ship_state'}   = &ZSHIP::correct_state($self->{'data.ship_state'},$self->{'data.ship_country'});
		#$self->{'data.bill_zip'}      = &ZSHIP::correct_zip($self->{'data.bill_zip'},$self->{'data.bill_country'});
		#$self->{'data.ship_zip'}     = &ZSHIP::correct_zip($self->{'data.ship_zip'},$self->{'data.ship_country'});
		# $self->save();	

		push @{$self->{'@CHANGES'}}, [ 'logout' ];
		}
#	elsif ($cid == 0) {
##		$errors->{'login'} = 'Unknown customer.  Perhaps you used a different email address?<br>';
#		}
#	elsif ($cid == -1) {
##		$errors->{'password'} = 'Password does not match login.  Please try again, or follow the "Forgot your password?" link.';
#		}
#	else {
#		# -2 or lower
##		$errors->{'login'} = "Internal error accessing customer record. ($id)";
#		} 
	
	return($CID);
#	print STDERR "CART LOGIN: $self->{'login'}\n";
	}


##
## is logout really this easy?
##
sub logout {
	my ($self) = @_;

	delete $self->{'%customer'};
	delete $self->{'*CUSTOMER'};
	$self->schedule('','logout');		# reset schedule

	push @{$self->{'@CHANGES'}}, [ 'logout' ];

	return();
	}





##
## returns an array of coupons, sorted in order.
##
sub coupons {
	my ($self,%filter) = @_;

	my $result = [];
	my $cpnsref = $self->{'%coupons'};

	if (defined $cpnsref) {
		## return all coupons
		foreach my $cpnid (sort keys %{$cpnsref}) {
			#my $add = 1;
			my $cpnref = $cpnsref->{$cpnid};
			## NOTE: cpnref->product was probably used for veruta
			#if (defined $filter{'product'}) {
			#	## restrict output to only coupons matching a specific product.
			#	$add = 0;
			#	if (($cpnref->{'type'} eq 'product') && ($cpnref->{'product'} eq $filter{'product'})) { $add++; }
			#	}

			#if ($add) {
			#	## make sure uniuqe 'id' is set on coupon.
			$cpnref->{'id'} = $cpnid;
			push @{$result}, $cpnref;
			#	}
			}
		}
	else {
		## short circuit, we have no coupons!
		}

	# print STDERR "COUPONS: ".Dumper(\%filter,$result);

	return($result);
	}


##############################################################################
##
## CART::cart_add_stuff
##
## Purpose: Adds products to the cart
## Wrapper around STUFF->legacy_cram
## parameters: item is an item ready to be legacy_crammed e.g.:
#ADDED STUFF: $VAR1 = {
#          'prod_name' => 'test',
#          'pogs' => '',
#          'taxable' => '1',
#          'qty' => 1,
#          'base_weight' => '1',
#          'qty_price' => undef,
#          'full_product' => {
#                              'zoovy:virtual' => '',
#                              'zoovy:quantity' => '1',
#                              'zoovy:base_weight' => '1',
#                              'zoovy:taxable' => '1',
#                              'zoovy:base_price' => '1',
#                              'zoovy:marketuser' => '',
#                              'zoovy:prod_name' => 'test'
#                            },
#          'inv_mode' => undef,
#          'base_price' => '1',
#          'stid' => '1273649*ASDF'
#        };
##
## options:
##		1 = make a note in the hitlog
##	sub add
##	sub add_to_cart
#sub is_stuff2_item_okay_to_add {
#	my ($self,$item,%params) = @_;
#
#	my $lm = $params{'*LM'};
#	if (not defined $lm) { $lm = LISTING::MSGS->new($self->username()); }
#	return ($err, $message);
#	}
## use STUFF2->cram( $PID, $qty ) instead



sub init_mkts {
	my ($self) = @_;
	## SEE THE @ZOOVY::INTEGRATIONS TABLE
	my @MKTIDS = ();

	my %DST_L = ();	# a dst lookup table (key=DST val=id)
	my %META_L = ();	# meta lookup (key=META val=id)
	my %SDOMAIN_L = ();	# sdomain lookup (key=SDOMAIN val=id)

	if ((defined $self->__GET__('our/mkts')) && ($self->__GET__('our/mkts') ne '')) {
		foreach my $id (@{&ZOOVY::bitstr_bits($self->__GET__('our/mkts'))}) {
			my $intref = &ZOOVY::fetch_integration('id'=>$id);
#			if (defined $intref) { push @MKTIDS, $intref->{'dst'}; }
			if (defined $intref) { push @MKTIDS, $intref->{'id'}; }
			}
		}

#	my %DST_L = ();	# a dst lookup table (key=DST val=id)
#	my %META_L = ();	# meta lookup (key=META val=id)
#	my %SDOMAIN_L = ();	# sdomain lookup (key=SDOMAIN val=id)
	foreach my $intref (@ZOOVY::INTEGRATIONS) {
		next if ($intref->{'id'} == 0);
		if ((defined $intref->{'dst'}) && ($intref->{'dst'} ne '')) {
			$DST_L{$intref->{'dst'}} = $intref->{'id'};
			}
		if ((defined $intref->{'meta'}) && ($intref->{'meta'} ne '')) {
			$META_L{$intref->{'meta'}} = $intref->{'id'};
			}
		if ((defined $intref->{'sdomain'}) && ($intref->{'sdomain'} ne '')) {
			$SDOMAIN_L{$intref->{'sdomain'}} = $intref->{'id'};
			}
		}
	foreach my $item (@{$self->stuff2()->items()}) {
	next if (not defined $item->{'mkt'});
		next if ($item->{'mkt'} eq '');
		next if (substr($item->{'stid'},0,1) eq '%');	# skip promotional items.
	
		$item->{'mkt'} = uc($item->{'mkt'});
	
		if (($item->{'mkt'} eq 'EBAY') || ($item->{'mkt'} eq 'EBY')) {
			push @MKTIDS, $DST_L{'EBA'}; 
			}
		elsif (($item->{'mkt'} eq 'EBAYS') || ($item->{'mkt'} eq 'EBAYSTORES') || ($item->{'mkt'} eq 'ESS')) {
			push @MKTIDS, $DST_L{'EBF'};
			}
		else {
			push @MKTIDS, $DST_L{ $item->{'mkt'} };
			}
		}

	##
	## SPECIAL CASES
	##
	#if ((defined $self->__GET__('our/ebates_ebs')) && 
	#	($self->__GET__('our/ebates_ebs') ne '')) { push @MKTIDS, $DST_L{'EBS'}; } 	# ebates
	#if ((defined $self->__GET__('our/jf_mid')) && 
	#	($self->__GET__('our/jf_mid') ne '')) { push @MKTIDS, $DST_L{'JLY'; }	# jellyfish
	#elsif ((defined $self->__GET__('our/jf_tid')) && 
	#	($self->__GET__('our/jf_tid') ne '')) { push @MKTIDS, $DST_L{'JLY'}; }# jellyfish
	if (not defined $self->__GET__('cart/buysafe_val')) { $self->__GET__('cart/buysafe_val',0); }
	if ((defined $self->__GET__('sum/bnd_method')) && 
		($self->__GET__('sum/bnd_method') ne '')) { push @MKTIDS, $DST_L{'BYS'}; }	# buysafe
	elsif ((defined $self->__GET__('cart/buysafe_val')) &&
		($self->__GET__('cart/buysafe_val'))>0) { push @MKTIDS, $DST_L{'BYS'}; }	# buysafe
	if (int($self->__GET__('cart/buysafe_val'))>0) { 
		if ($self->__GET__('want/bnd_purchased')>0) { push @MKTIDS, $DST_L{'BYS'}; }
		}

	##
	## META RESOLUTION
	##
	my $META = uc($self->__GET__('cart/refer'));
	if ($META eq '') {
		## shortcut
		}
	elsif ($META =~ /^(.*?)[\?\:\.]+/) {
		## META has crazy characters in it (ex: CAMPAIGN:XYZ)
		push @MKTIDS, $META_L{$1};
		}
	elsif ($META_L{$META}) {
		## FOUND IT!
		push @MKTIDS, $META_L{$META};
		}
	else {
		## SOME OTHER META (user defined perhaps?)
		}
		
	##
	## SDOMAIN RESOLUTION
	##
	my $SDOMAIN = lc($self->__GET__('our/sdomain'));
	if ($SDOMAIN eq '') {
		}
	elsif ($SDOMAIN_L{$SDOMAIN}) {
		push @MKTIDS, $SDOMAIN_L{$SDOMAIN};
		}

	$self->__SET__('our/mkts',&ZOOVY::bitstr(\@MKTIDS));

	## 
	## END MKTS HANDLING
	##
	return();
	}


##
## the purpose of CHECKOUT is to take
##
## possible params:
##		app = pretty name/version of the calling app (used in order history)
##		skip_inventory =>1|0 (default 0) mostly useful in recovery situations
##		skip_ocreate =>1|0 	(default 0) don't send emails 
##		skip_oid_creation=1  (default 0) it's okay (non-error) if our/orderid is already set
##
## OLD @PAYMENTS FORMAT (here for reference)
#	## array: 0 = method, 1 = amount, 2 params, 3=acctref, 4=event message
#	#if (defined $payment->[4]) { $o->add_history($payment->[4],etype=>2); }
#	my %params = %{$payment->[2]};	
#	if ((defined $payment->[3]) && (ref($payment->[3]) eq 'HASH')) {
#		## if we receive payment->[3] then it becomes $params{'acct'}=>&ZPAY::packit({});
#		$params{'acct'} = &ZPAY::packit($payment->[3]);
#		}
#	my ($payrec) = $o->add_payment( $payment->[0], $payment->[1], %params );
#	# $payq->{'tender'} = $payment->[0];
#	}

sub ignore_finalize_term {
	print STDERR "IGNORING SIGTERM SIGNAL (in finalize)\n";
	return();
	}

##
##
sub finalize_order {
	my ($self, %params) = @_;

	$SIG{'SIGTERM'} = \&CART2::ignore_finalize_term();
	my ($redis) = &ZOOVY::getRedis($self->username(),0);

	my $NONCE = $params{'nonce'};
	my $CARTID = $self->uuid();
	#if ((defined $NONCE) && ($NONCE ne '')) { 
	#	my $NONCE = join("",reverse split(//,$NONCE));
	#	$CARTID = substr( sprintf("%s#%s",$CARTID,$NONCE) ,0,30 ); 
	#	#$self->set('cart/cartid',$CARTID);
	#	}
	#print STDERR "NONCE: $NONCE\n";

	if ($params{'app'}) {
		$self->add_history(sprintf("Order App:%s Cart:%s Proc:$$",$params{'app'},$CARTID ));
		}
	else {
		warn "finalize_order *really* appreciates receiving an 'app' parameter describing who called it.";
		}

	if (not defined $self->__GET__('flow/pool')) {
		## make sure we have a good default POOL
		$self->__SET__('flow/pool','RECENT');
		}

	my $USERNAME = $self->username();

	my $EREFID = $self->__GET__('want/erefid');
	if ((not defined $EREFID) || ($EREFID eq '')) { $EREFID = $self->__GET__('mkt/erefid'); }
	if (not defined $EREFID) { $EREFID = ''; }

	my $REDIS_ASYNC_KEY = $params{'R_A_K'} || sprintf("FINALIZE.%s.CART.%s",$self->username(),$self->uuid());
	print STDERR "ASYNC_KEY: $REDIS_ASYNC_KEY NONCE:$NONCE\n";
	$redis->append($REDIS_ASYNC_KEY,"\nSPOOLER*NONCE|$NONCE");

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $MID = $self->mid();
	my $STARTTS = time();
		
	my ($lm) = $params{'*LM'};
	if (not defined $lm) { $lm = LISTING::MSGS->new($self->username()); }

	## 
	## DO WE ALREADY HAVE AN ORDER FOR THIS CART
	##
	if (not $lm->can_proceed()) {
		}
	elsif (($params{'our_orderid'}) && ($params{'our_orderid'} ne '')) {	
		## this is typically used by marketplaces.
		$self->__SET__('our/orderid',$params{'our_orderid'});
		$lm->pooshmsg(sprintf("INFO|+Using external order# %s",$params{'our_orderid'}));
		}
	elsif ($self->is_order()) {
		## we already have an orderid? wtf -- not sure why this line is reached.
		## we get here when we've got a csv order import
		if ($params{'skip_oid_creation'}) {
			}
		else {
			$lm->pooshmsg("ERROR|+Already have an oRDER ID! [".$self->oid()."] (pass oid_is_already_set=1 to disable this)");
			}
		}
	elsif ( not $self->is_cart() ) {
		$lm->pooshmsg("ISE|+Logic failure - not a cart, not an order (not sure what to do)");
		}
	elsif ( not $self->is_persist() ) {
		## no database row id
		## YAY -- we can just get a OID and keep moving.	
		my ($OID) = &CART2::next_id($self->username(),0,$EREFID);
		$self->__SET__('our/orderid',$OID);
		if (not $self->is_marketplace_order()) {
			$lm->pooshmsg("ISE|+tried to finalize non-persistent, non-marketplace order.");
			}
		}
	elsif ( $self->is_persist() && $params{'retry'} ) {
		##
		## a recovery situation, we'll load the previous, we can just continue.
		##
		}
	elsif ( $self->is_persist() ) {
		##
		## PERSIST CART - VERIFY THIS ORDERID IS NOT A DUPLICATE TO ONE ALREADY CREATED, and LOCK IT.
		##	
		my ($OID) = &CART2::next_id($self->username(),0,$CARTID);
		$self->__SET__('our/orderid',$OID);

		my ($ORDER_TB) = &DBINFO::resolve_orders_tb($USERNAME,$self->mid());
		my $PRT = $self->prt();
		my $qtCARTID = $udbh->quote($self->cartid());

		## There can only be one process (when creating from a website)
		$redis->append($REDIS_ASYNC_KEY,"\nNONCE|$NONCE");
		$redis->append($REDIS_ASYNC_KEY,"\nORDERID|$OID");
		$redis->expire($REDIS_ASYNC_KEY,86400*7);

		## NEW REDIS BASED CODE
		my $pstmt = "select ID,ORDERID,CREATED_GMT from $ORDER_TB where MID=$MID /* $USERNAME */ and PRT=$PRT and CARTID=$qtCARTID";
		print STDERR "$pstmt\n";
		my ($DBID,$DBOID,$DBCREATED_GMT) = $udbh->selectrow_array($pstmt);

		if (not defined $DBID) {
			## NO RECORD IN DATABASE - BEST CASE
			$lm->pooshmsg("WARN|+No order was stored in REDIS (duplication could happen)");
			}
		elsif ($DBID>0) {
			## ORDER ALREADY EXIST
			$self->__SET__('our/orderid',$DBOID);
			$lm->pooshmsg("RETRY|+USE DBROW:$DBID DBOID:$DBOID CREATED:$DBCREATED_GMT");
			## we could probably add code to be more intelligent here.
			$self->add_history("WARNING - Recovered ORDERID:$DBOID ROW:#$DBID from CART:$qtCARTID");
			}
		else {
			$lm->pooshmsg("ISE|+FATALITY DURING COID/DBID CHECK - THIS LINE IS NEVER REACHED");		
			}

		}
	else {
		$redis->append($REDIS_ASYNC_KEY,"\nFINALIZE-FAILURE");
		$lm->pooshmsg("ISE|+Finalize workflow failure.");
		}

	## create a recovery file
	my $recoveryfile = sprintf("%s/CART2-RECOVER-%s-%s-%s-%s.log",&ZOOVY::memfs(),$USERNAME,$self->cartid(),$self->oid(),$STARTTS);
	if (! -f $recoveryfile) {
		open F, ">$recoveryfile";
		print F Dumper({'CART'=>$self,'PARAMS'=>\%params,'LM'=>$lm});
		close F;
		}


	##
	## AT THIS POINT WE HAVE AN OID 
	##
	if (not $lm->can_proceed()) {
		}
	elsif ($self->oid() eq '') {
		$lm->pooshmsg("ISE|+INTERNAL LOGIC FAILURE - BLANK OID IS NOT POSSIBLE");
		}
	else {
		## we schedule an ORDER.VERIFY in 30 minutes as a way to insure everything went well/catch errors
		&ZOOVY::add_event($self->username(),"ORDER.verify",'DISPATCH_GMT'=>$STARTTS+(60*30),'ORDERID'=>$self->oid(),'CARTID'=>$self->cartid(),'PRT'=>$self->prt());
		}

	if (my $iseref = $lm->had(['ISE'])) {
		## indicates an internal error.
		&ZOOVY::confess($self->username(),"FINALIZE ORDER ISE ".Dumper($lm,$self),justkidding=>1);
		}

	my $webdbref = $self->webdb();
	my ($gref) = &ZWEBSITE::fetch_globalref($self->username());
	# my $SREF = undef;
	# my $SE = undef;
	my ($BLAST,$rcpt) = undef;

	my $CID = undef;
	my %cart2 = ();

	tie %cart2, 'CART2', 'CART2'=>$self;

	if ($lm->can_proceed()) {
		$CID = $self->customerid();
		($BLAST) = BLAST->new($self->username(),$self->prt());	
		}


	##
	## WE DO THE CUSTOMER STUFF FIRST BECAUSE (BEFORE PAYMENTS) WE *MIGHT* NEED TO CREATE A WALLET
	##

	if (not $lm->can_proceed()) {
		}
	elsif ( ($CID = $self->customerid()) > 0) {
		# grab all the bill_ keys and ship_ keys to save them
		$self->add_history("Mapping order to logged in customer: $CID (updating account)",etype=>64);
		my $billhash = {};
		my $shiphash = {};
		foreach my $field (@CART2::VALID_ADDRESS) {
			$billhash->{"$field"} = $cart2{"bill/$field"};
			$shiphash->{"$field"} = $cart2{"ship/$field"};
			}
		$billhash->{'ID'} = 'DEFAULT'; $billhash->{'_IS_DEFAULT'}++;
		$shiphash->{'ID'} = 'DEFAULT'; $shiphash->{'_IS_DEFAULT'}++;
		&CUSTOMER::store_addr($USERNAME,$CID,'BILL',$billhash);
		&CUSTOMER::store_addr($USERNAME,$CID,'SHIP',$shiphash);
		} 
	elsif (not $self->in_get('will/create_customer')) {
		## do not create a customer
		}
	#elsif ($self->payment_method() eq 'GOOGLE') {
	#  Google now uses the must/create_customer flag
	#	}
	elsif (($self->__GET__('bill/email') ne '') && ($CID = CUSTOMER::resolve_customer_id($self->username(),$self->prt(),$self->__GET__('bill/email')>0))) {
		$self->add_history(sprintf("Customer #%d '%s' already exists",$CID,$self->__GET__('bill/email')));
		}
	elsif ($self->__GET__('bill/email') ne '') {

		my %R = ();
		# Create a new customer account	
		my ($CID) = CUSTOMER::resolve_customer_id($USERNAME,$self->prt(),$self->__GET__('bill/email'));
		my ($C) = CUSTOMER->new($USERNAME,
			PRT=>$self->prt(),
			EMAIL=>$self->__GET__('bill/email'),
			CID=>$CID,
			CREATE=>2,
			'*CART2'=>$self,
			'DATA'=>{
				#'INFO.PASSWORD'=>$customer_password,
				'INFO.HINT_NUM'=>$self->in_get('want/recovery_hint'),
				'INFO.HINT_ANSWER'=>$self->in_get('want/recovery_answer'),
				'INFO.NEWSLETTER'=>$self->in_get('want/email_update'),
				'INFO.ORIGIN'=>1,
				}
			);	

		$self->customer($C);
		if (not defined $C) {
			$self->add_history(sprintf("Could not create customer %s for cart #%s",$self->__GET__('bill/email'),$self->oid()),etype=>1+8);
			}
		elsif (ref($C) ne 'CUSTOMER') {
			$self->add_history(sprintf("Invalid customer %s for cart #%s",$self->__GET__('bill/email'),$self->oid()),etype=>1+8);
			}
		elsif ($CID>0) {
			# don't Send them the password if we didn't just create the account.
			($CID) = $C->cid();
			}
		else {
			## generate a new password and email it.
			($CID) = $C->cid();
			my $customer_password = $self->in_get('want/new_password');
			$R{'PASSWORD-SET'}->{'password'} = $C->initpassword("set"=>$customer_password);
			$self->add_history(sprintf("Created customer %s prt:%d cid:%s",$self->__GET__('bill/email'),$self->prt(),$CID),etype=>1);
			my ($rcpt) = $BLAST->recipient('CUSTOMER',$C,{'%CUSTOMER'=>$C,'%RUPDATE'=>\%R});
			my ($msg) = $BLAST->msg('CUSTOMER.CREATED');
			$BLAST->send($rcpt,$msg);
			}
		} ## end elsif ($cart{'chkout.create_customer'...
	else {
		$CID = 0;
		$self->add_history("Customer account was not created",etype=>64);
		}

	##
	## PAYMENTS (PAYMENTQ processing)
	##
	my $payment_success = undef;
	if (not $lm->can_proceed()) {	
		# die(Dumper($lm));
		$lm->pooshmsg("DEBUG|+PAYMENT COULD NOT PROCEED");
		}
	elsif ($lm->had(['RETRY'])) {
		## don't retry this portion of the order.
		$lm->pooshmsg("DEBUG|+PAYMENT IS A RETRY");
		}
	elsif ($self->__GET__('sum/order_total') == 0) {
		## this is okay, we don't need any payments.
		$lm->pooshmsg("DEBUG|+PAYMENT IS ZERO");
		}
	elsif (scalar($self->{'@PAYMENTQ'})==0) {
		if (scalar($self->{'@PAYMENTS'})==0) {
			## some marketplaces just add payments directly, rather than passing into PAYMENTQ
			$lm->pooshmsg("ISE|+PAYMENTQ and PAYMENTS are empty, something almost certainly went horribly horribly wrong");
			}
		}
	else {
		## many of the fraud screen's and gateways need ip, it wasn't pulled from the cart (not available)
		## and won't be set by ordhash until much later (if at all)

		## USED BY:
		##		ZCSV::ORDER
		##		ebay/monitor.pl
		##		google/process.pl
		##		buycom/orders.pl
		##		sears/orders.pl
		## @payments is probably how future orders will pass in their payments, basically it's an array
		## 0=method (ex: 'EBAY', 'PAYPAL', 'GOOGLE')
		## 1=amount
		## 2=hashref of parameters (ex: ps, txn, etc.)
		## 3=acct params (ex: GS=> GO=> etc.)
		## 4=an event message	

		$self->__SYNC__();		## make sure we sync before processing @PAYMENTQ to get latest totals
		my $luser = '*checkout';

		foreach my $payq (@{$self->{'@PAYMENTQ'}}) {
			$lm->pooshmsg("PAYMENT|+".&ZTOOLKIT::buildparams($payq));

			if ($payq->{'TN'} eq 'ZERO') {
				## ZERO BALANCE - it will always be zero dollars.
				$payq->{'T$'} = 0;
				}
			elsif ($payq->{'TN'} eq 'PAYPALEC') {
				## PAYPAL MUST ALWAYS BE SET TO THE FULL ORDER AMOUNT (OR IT WILL FAIL)
				$payq->{'$$'} = $self->in_get('sum/order_total');
				}
			elsif ($payq->{'$$'} <= 0) {
				## TRY AND RECOVER:
				if ($self->in_get('sum/balance_due_total') == 0) {
					## this is fine, ex: ZERO payment method
					}
				elsif ($self->in_get('sum/balance_due_total') > 0) {
					&ZOOVY::confess($USERNAME,'RECOVERABLE  ERROR $$ is <= 0'.Dumper($self),justkidding=>1);
					$payq->{'$$'} = $self->in_get('sum/balance_due_total');
					}
				else {
					&ZOOVY::confess($USERNAME,'FATAL INTERNAL ERROR $$ is <= 0'.Dumper($self),justkidding=>0);
					}
				}
			
			next if ($payq->{'$$'} <= 0);	# stop bad things from happening

			if ($payq->{'TN'} eq 'WALLET') {
				my $walletvars = $self->customer()->wallet_retrieve($payq->{'WI'});
				foreach my $k (keys %{$walletvars}) { 
					next if (length($k) != 2);	## only two digit payment codes may pass!
					next if (defined $payq->{$k});	## never overwrite anything, during copy, ever.
					$payq->{$k} = $walletvars->{$k}; 
					}

				if (defined $payq->{'CC'}) { $payq->{'TN'} = 'CREDIT'; }
				elsif (defined $payq->{'EA'}) { $payq->{'TN'} = 'ECHECK'; }
				else { 
					$lm->pooshmsg("ISE|+Wallet tender type could not be auto-detected needs either CC or EA");
					$payq->{'TN'} = 'WALLET-INVALID'; 
					}

				}
		
			if (not defined $payq->{'IP'}) {
				$payq->{'IP'} = $self->__GET__('cart/ip_address');
				}

			my $payrec = ();
			if ($payq->{'TN'} eq 'GIFTCARD') {
				my $card_balance_remain = &ZOOVY::f2money( &ZOOVY::f2int($payq->{'T$'}*100) - &ZOOVY::f2int($payq->{'$$'}*100) );
								
				my $obfscode = &GIFTCARD::obfuscateCode($payq->{'GC'},0);
				my $GCID = $payq->{'GI'};
				my $NOTE = sprintf("Purchase %s for \$%s",$self->oid(),$payq->{'$$'});
				## should CID=>$CID be set here?
				my ($txn) = &GIFTCARD::update($self->username(),$payq->{'GI'},
					## SPEND=>&ZOOVY::f2money($payq->{'$$'}/100),
					SPEND=>&ZOOVY::f2money($payq->{'$$'}),
					LAST_ORDER=>$self->oid(),
					LUSER=>$luser,
					LOGNOTE=>$NOTE
					);
	
				if ($txn <= 0) {
					$self->add_history(sprintf("Giftcard %s FAILED card_debit:%s card_balance_remain:%s",$obfscode,&ZOOVY::f2money($payq->{'$$'}),&ZOOVY::f2money($card_balance_remain/100)));
					}
				else {
					$NOTE = sprintf("Giftcard %s [#%d]",$obfscode,$GCID);
					my $txnuuid = sprintf("%s.%d",&GIFTCARD::obfuscateCode($payq->{'GC'},0),$txn);
					($payrec) = $self->add_payment("GIFTCARD",&ZOOVY::f2money($payq->{'$$'}),
						note=>$NOTE,luser=>$luser,event=>1,
						acct=>&ZPAY::packit({'GC'=>$obfscode,'GI'=>$GCID}),
						txn=>$txnuuid,
						uuid=>$txnuuid,
						ps=>'070',
						);
					$self->add_history(sprintf("Giftcard %s SUCCESS card_debit:%s card_balance_remain:%s",$obfscode,&ZOOVY::f2money($payq->{'$$'}),&ZOOVY::f2money($card_balance_remain/100)));
					}

				# $self->add_history(sprintf("Finished giftcard processing with balance_due of: \$%.2f",$balance_due),time(),2,$luser);
				}
			elsif ($payq->{'TN'} eq 'CREDIT') {
				($payrec) = $self->add_payment('CREDIT',$payq->{'$$'});
				## THIS IS REALLY BAD BECAUSE IT WILL CAPTURE CVV/CID ETC. PRE MASKED
				## $self->add_history(sprintf("Balance Due: $payq->{'$$'} payrec=%s vars=%s\n",&ZTOOLKIT::buildparams($payrec),&ZTOOLKIT::buildparams($payq)));
				($payrec) = $self->process_payment('INIT',$payrec,%{$payq});
				}
			elsif ($payq->{'TN'} eq 'PAYPALEC') {
	
				#print STDERR 'PAYQ: '.Dumper($payq)."\n";
				($payrec) = $self->add_payment('PAYPALEC',$payq->{'$$'},'txn'=>$payq->{'PT'});
				#print STDERR 'PAYREC: '.Dumper($payrec)."\n";
				#die();
				($payrec) = $self->process_payment('INIT',$payrec,%{$payq});
				}
			elsif (
				($payq->{'TN'} eq 'CALL') || 
				($payq->{'TN'} eq 'CHKOD') || 
				($payq->{'TN'} eq 'PICKUP') || 
				($payq->{'TN'} eq 'CHECK') || 
				($payq->{'TN'} eq 'COD') || 
				($payq->{'TN'} eq 'CASH') ||
				($payq->{'TN'} eq 'MO') ||
				($payq->{'TN'} eq 'WIRE') ||
				($payq->{'TN'} eq 'BIDPAY') ||
				($payq->{'TN'} eq 'LAYAWAY') ||
				($payq->{'TN'} eq 'CUSTOM')
				) {
				($payrec) = $self->add_payment($payq->{'TN'},$payq->{'$$'},'note'=>'','ps'=>'168');
				}
			elsif ($payq->{'TN'} eq 'PO') {
				($payrec) = $self->add_payment('PO',$payq->{'$$'},%{$payq});
				$self->in_set('want/po_number',$payq->{'PO'});
				}
			elsif ($payq->{'TN'} eq 'ECHECK') {
				($payrec) = $self->add_payment('ECHECK',$payq->{'$$'});
				($payrec) = $self->process_payment('INIT',$payrec,%{$payq});
				}
			else {
				print STDERR Carp::cluck(sprintf("Checkout Unknown Payment: %s",$payq->{'TN'}));
				$self->add_history(sprintf("Checkout Unknown Payment: %s",$payq->{'TN'}),etype=>2);
				## this will probably have a balance due!
				}
			}	
		$self->__SYNC__();		## make sure we're dealing with the latest version of the order.
		}

	my $payment_status = $self->payment_status();
	if (&ZPAY::ispsa($payment_status,['0','1','4'])) {
		$self->add_history("PAYMENT SUCCESS: $payment_status",etype=>2);
		}
	elsif ($payment_status eq '902') {
		if ($self->__GET__('is/origin_marketplace')) {
			## it is fine (for now) for marketplace orders to have no payments
			$self->add_history("Marketplace Order");
			}
		else {
			$self->add_history("NO PAYMENTS IN ORDER DURING FINALIZE - NON MARKETPLACE ORDER (PS:$payment_status)");
 			}
		}
	else {
		$self->add_history("PAYMENT FAILED: $payment_status",etype=>2);
		}


	# Decrement the inventory quantities of everything in the shopping cart
	if (not $lm->can_proceed()) {
		}
	elsif ($lm->had(['RETRY'])) {
		## no retry inventory
		}
	elsif ($params{'skip_inventory'}) {
		## explicitly skip's inventory decrement (for FBA type stuff)
		}
	else {
		INVENTORY2->new($USERNAME)->checkout_cart2($self);
		if ($REDIS_ASYNC_KEY) { $redis->append($REDIS_ASYNC_KEY,"\nSTATUS|Updated inventory.\n"); }
		}

	## Save the order and reload it so we know if there's somethign wrong in the checkout there must have been something
	## wrong saving the order

	if (not $lm->can_proceed()) {
		}
	elsif ($lm->had(['RETRY'])) {
		## don't retry this portion of the order.
		}
	elsif ($params{'skip_ocreate'}) {
		## used by ebay (since ebay adds payment after CHECKOUT::finalize)
		}
	elsif ($self->in_get('is/email_suppress')) {
		## used by checkout(s) to indicate customer doesn't want to or isn't allowed to receive emails.
		}
	else {
		my $ORDER_PS = $self->payment_status();
		my $ORDER_PS_PRETTY = &ZPAY::payment_status_short_desc($ORDER_PS);	 # PAID|PENDING|DENIED
		my ($MSGID) = sprintf('ORDER.CONFIRM.%s.%03d',$ORDER_PS,$ORDER_PS);
		my ($rcpt) = $BLAST->recipient('CART',$self,{'%ORDER'=>$self->TO_JSON()});
		my ($msg) = $BLAST->msg($MSGID);
		$BLAST->send($rcpt,$msg);
		if ($REDIS_ASYNC_KEY) { $redis->append($REDIS_ASYNC_KEY,"\nSTATUS|Sent order confirmation email.\n"); }
		}

	##
	## INITIALIZE SOME TRACKING VARIABLES
	## 
	if (not $lm->can_proceed()) {
		}
	elsif (not ref($self) ne 'CART2') {
		open F, ">/dev/shm/unblessed.cart2.dump";
		print F Dumper($self);
		close F;
		}
	else {
		## this should *ALWAYS* be true under normal circumstances
		if ($self->in_get('our/mkts') eq '') {
			$self->init_mkts();
			}

		## map customer if it exists (duplicated in save())
		## 	WAIT -- call 'guess_customerid()' before creating order if you want this to happen .. or rather set 'cid' = 0
		if (($self->__GET__('customer/cid')>0) && ($self->__GET__('customer/created_gmt')+86400 < $self->__GET__('our/order_ts'))) {
			## the customer existed 1 day before this order, so we should flag that it's a repeat customer here.
			$self->__SET__('flow/flags', $self->__GET__('flow/flags') | (1<<2));
			}
		}


	##
	## SANITY: if we crash at this point with a PERSIST cart, then we're going to have a locked cartid.
	##  -- do not separate the lines below!

	if ($self->is_marketplace_order()) {
		foreach my $msg (@{$lm->msgs()}) {
			my ($msgref,$status) = LISTING::MSGS::msg_to_disposition($msg);
			if ($status eq 'DEBUG') {
				}
			elsif ($status =~ /^(WARN|ERROR|ISE)$/) {
				$self->add_history(sprintf("FINALIZE %s: %s",$msgref->{'_'},$msgref->{'+'}),$STARTTS,8+32);
				}
			else {
				$self->add_history(sprintf("FINALIZE %s: %s",$msgref->{'_'},$msgref->{'+'}),$STARTTS,32);
				}
			}
		}

	## NOTE: it seems like we should *ALWAYS* try and reliably save ebay.com and amazon.com orders before we commit to the database
	##			because otherwise we can create duplicates, this way worst case we end up doing a recovery.
	if ($self->__GET__('our/sdomain') eq 'ebay.com') {
		##
		## special ebay code
		##
		my ($pstmt) = &DBINFO::insert($udbh,'EBAY_ORDERS',{
			'MID'=>$self->mid(),
			'EBAY_ORDERID'=>$self->__GET__('mkt/erefid'),
			'OUR_ORDERID'=>$self->oid(),	
			'PAY_METHOD'=>'EBAY',
			'PAY_REFID'=>$self->__GET__('mkt/payment_txn'),
			},key=>['MID','EBAY_ORDERID'],verb=>'update','sql'=>1);
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		}
	elsif (
		($self->__GET__('mkt/amazon_orderid') ne '') ||
		($self->__GET__('our/sdomain') eq 'amazon.com') || 
		($self->__GET__('mkt/siteid') eq 'cba')
		) {
		##
		## special amazon code
		##
		my $pstmt = "update AMAZON_ORDERS set OUR_ORDERID=".$udbh->quote($self->oid()).
  			  ",ORDER_TOTAL=".$udbh->quote($self->__GET__('sum/order_total')).
  			  ",SHIPPING_METHOD=".$udbh->quote($cart2{'sum/shp_method'}).
			  " where OUR_ORDERID='' and MID=$MID and AMAZON_ORDERID=".$udbh->quote($cart2{'mkt/amazon_orderid'});
	   $udbh->do($pstmt);
		## store processing into order.
		$self->add_history("Finished Amazon Processing");
		}


	if (not $lm->had(['RETRY'])) {
		## don't retry this portion of the order.
		$self->queue_event('create','override'=>1);	
		}

	if ($params{'do_not_lock'}) {
		## google checkout dispatches after create, it's not technically a marketplace, .. but bleh.
		## amazon cba has the same issue
		}
	else {
		## WE MUST RUN THIS SAVE:		
		$self->order_save();
		}

	## &DBINFO::release_lock($udbh,$USERNAME,$self->cartid());
	&DBINFO::db_user_close();

	## SANITY: at this point $ERROR should either be undef, or OID\tERRORMSG 
	##				in some cases OID may not be known.
	if (not $lm->can_proceed()) {
		## SOME TYPE OF NON-RECOVERABLE ERROR
		# 1294884190		totalfanshop	 CART-OID-STAGE1-ALREADY-SET  cv3omrQUWhslhHtYAzzzhdOEL
		open F, ">>/tmp/checkout-errors.log";
		print F &ZTOOLKIT::pretty_date(time(),3)."\t".$USERNAME."\t".$self->cartid()."\n";
		close F;
		my ($redis) = &ZOOVY::getRedis($self->username(),0);
		if (defined $redis) {
			my ($i) = $redis->incr(sprintf("ORDER-FAILURE:%s.%s",$self->username(),$self->cartid()));
			if ($i >= 1) {
				$lm->pooshmsg("SUCCESS|OID:".$self->oid());
				$lm->pooshmsg("ISE|+Too many internal failures ($i)");
				my $REDIS_ID = &CART2::redis_cartid($self->username(),$self->prt(),$self->cartid());
				$redis->del($REDIS_ID);
				}
			}
		}
	else {
		if ($REDIS_ASYNC_KEY) { $redis->append($REDIS_ASYNC_KEY,sprintf("\nSUCCESS|Order %s has been placed\n",$self->oid())); }
		$lm->pooshmsg("SUCCESS|OID:".$self->oid());
		unlink("$recoveryfile");
		}
	untie %cart2;
	delete $SIG{'SIGTERM'};

	return($lm);
	}












##
##
## NOTE: this is used by several different areas of the system includING:
##		SUPPLIER::API	-	version# can be configured by users as .api.version  versions < 100 are reserved
##
sub as_xml {
	my ($self,$xcompat) = @_;

	my $xml = '';
	if ($xcompat < 200) {
		$xml = "<!-- minimum supported xcompat is 200 (you requested: $xcompat) -->\n";
		}
	elsif ($self->is_supplier_order() && ($xcompat < 210)) {
		if (length($self->in_get('flow/private_notes'))>32768) {
			## limit private notes to something *huge* - fix for a bug with large private notes.
			$self->in_set('flow/private_notes', substr($self->in_get('flow/private_notes'),0,32768) );
			}
		$xml .= sprintf("<ORDER ID=\"%s\" USER=\"%s\" V=\"%s\">\n",$self->is_supplier_order(),$self->username(),$xcompat);
		$xml .= "<DATA>\n";
		$xml .= "<APPLOCK></APPLOCK>";
		my %data = ();
		foreach my $k  (keys %CART2::VALID_FIELDS) {
			my $order1key = $CART2::VALID_FIELDS{$k}->{'order1'};
			next if ((not defined $order1key) || ($order1key eq ''));
			$data{$order1key} = $self->__GET__($k);
			if (not defined $data{$order1key}) { delete $data{$order1key}; }
			}
		
		$xml .= &ZTOOLKIT::hashref_to_xmlish(\%data,'encoder'=>'latin1');
		$xml .= "</DATA>\n";
		$xml .= "<STUFF>\n";
			my ($legacyxml,$error) = $self->stuff2()->as_legacy_stuff()->as_xml($xcompat);
			$xml .= $legacyxml;
		$xml .= "</STUFF>\n";
		if (defined $self->{'@PAYMENTS'}) {
			$xml .= "<PAYMENTS>\n";
			$xml .= &ZTOOLKIT::arrayref_to_xmlish_list($self->payments(),'tag'=>'payment','encoder'=>'latin1','content_attrib'=>'content');
			$xml .= "</PAYMENTS>\n";
			}
		$xml .= "</ORDER>\n";

		## this should correct the wide byte error when attempting to encode as base64
		require Encode;
		$xml = Encode::encode("UTF-8",$xml);
		}
	elsif ($self->is_cart() && ($xcompat < 210)) {
		$xml .= '<cart id="'.$self->cartid().'">';
		$xml .= '<stuff>';
		my ($stuffxml,$stufferrors) = $self->stuff2()->as_legacy_stuff()->as_xml($xcompat);
		if ($stufferrors ne '') { $xml .= "<!-- stuff errors: $stufferrors -->"; }
		$xml .= $stuffxml;
		$xml .= '</stuff>';
		$xml .= '</cart>';
		}
	elsif ($self->is_order() && ($xcompat < 210)) {
		if (length($self->in_get('flow/private_notes'))>32768) {
			## limit private notes to something *huge* - fix for a bug with large private notes.
			$self->in_set('flow/private_notes', substr($self->in_get('flow/private_notes'),0,32768) );
			}
		$xml .= sprintf("<ORDER ID=\"%s\" USER=\"%s\" V=\"%s\">\n",$self->oid(),$self->username(),$xcompat);
		$xml .= "<DATA>\n";
		$xml .= "<APPLOCK></APPLOCK>";

		my %data = ();
		foreach my $k  (keys %CART2::VALID_FIELDS) {
			my $order1key = $CART2::VALID_FIELDS{$k}->{'order1'};
			next if ((not defined $order1key) || ($order1key eq ''));
			$data{$order1key} = $self->__GET__($k);
			if (not defined $data{$order1key}) { delete $data{$order1key}; }
			}

		if ($self->__GET__('ship/countrycode') ne 'US') {
			my ($info) = &ZSHIP::resolve_country('ISO'=>$self->__GET__('ship/countrycode')); 
			$data{'ship_country'} = $info->{'Z'};
			$data{'ship_int_zip'} = $self->__GET__('ship/postal');
			$data{'ship_province'} = $self->__GET__('ship/region');
			}
		if ($self->__GET__('bill/countrycode') ne 'US') {
			my ($info) = &ZSHIP::resolve_country('ISO'=>$self->__GET__('bill/countrycode')); 
			$data{'bill_country'} = $info->{'Z'};
			$data{'bill_int_zip'} = $self->__GET__('bill/postal');
			$data{'bill_province'} = $self->__GET__('bill/region');
			}

		if (not defined $data{'ship_gmt'}) {
			$data{'ship_gmt'} = $data{'shipped_gmt'};
			}
		if (not defined $data{'ship_date'}) {
			$data{'ship_date'} = $data{'shipped_gmt'};
			}
		
		$xml .= &ZTOOLKIT::hashref_to_xmlish(\%data,'encoder'=>'latin1');
		$xml .= "</DATA>\n";
		$xml .= "<STUFF>\n";
			my ($legacyxml,$error) = $self->stuff2()->as_legacy_stuff()->as_xml($xcompat);
			$xml .= $legacyxml;
		$xml .= "</STUFF>\n";

		$xml .= "<EVENTS>\n";
		$xml .= &ZTOOLKIT::arrayref_to_xmlish_list($self->{'@HISTORY'},'tag'=>'event','encoder'=>'latin1','content_attrib'=>'content');
		$xml .= "</EVENTS>\n";

		if (defined $self->{'@PAYMENTS'}) {
			$xml .= "<PAYMENTS>\n";
			$xml .= &ZTOOLKIT::arrayref_to_xmlish_list($self->payments(),'tag'=>'payment','encoder'=>'latin1','content_attrib'=>'content');
			$xml .= "</PAYMENTS>\n";
			}

		if (defined $self->{'@FEES'}) {
			$xml .= "<FEES>\n";
			$xml .= &ZTOOLKIT::arrayref_to_xmlish_list($self->fees(1),'tag'=>'fee','encoder'=>'latin1');
			$xml .= "</FEES>\n";
			}

		if (defined $self->{'@SHIPMENTS'}) {
			$xml .= "<TRACKING>\n";
			$xml .= &ZTOOLKIT::arrayref_to_xmlish_list($self->{'@SHIPMENTS'},'tag'=>'pkg','encoder'=>'latin1');
			$xml .= "</TRACKING>\n";
			}
		$xml .= "</ORDER>\n";

		## this should correct the wide byte error when attempting to encode as base64
		require Encode;
		$xml = Encode::encode("UTF-8",$xml);
		}
	else {
		## starting at version 210 the output for carts and order is nearly identical (with a few more fields in order)
		require XML::Writer;
		my $writer = new XML::Writer(OUTPUT => \$xml, UNSAFE=>1);

		if ($self->is_supplier_order()) {
			$writer->startTag("order", 'variant'=>'supplier-order', 'id'=>$self->supplier_orderid(), 'v'=>$self->v());
			}
		elsif ($self->is_cart()) {
			$writer->startTag("cart", 'id'=>$self->cartid(), 'v'=>$self->v());
			}
		else {
			$writer->startTag("order", 'id'=>$self->oid(), 'v'=>$self->v());
			}

		#$writer->dataElement('our', '', %{$self->{'%our'}});
		#$writer->dataElement('flow','',  %{$self->{'%flow'}});
		$writer->startTag('stuff');	
		my ($stuffxml,$stufferrors) = $self->stuff2()->as_xml($xcompat);
		if ($stufferrors ne '') { $xml .= "<!-- $stufferrors -->"; }
		$writer->raw($stuffxml);
		$writer->endTag('stuff');

		$self->{'%our'}->{'prt'} = $self->prt();

		if ($xcompat < 222) {
			if (not defined $self->{'%our'}->{'profile'}) {	$self->{'%our'}->{'profile'} = ''; }
			$self->{'%our'}->{'sdomain'} = $self->{'%our'}->{'domain'};
			}
			
		foreach my $grp (@CART2::VALID_GROUPS) {
			## bill,ship,mkt,this,want,flow, etc.
			foreach my $k (keys %{$self->{"%$grp"}}) {
				if ($grp eq 'app') {
					if ($k =~ /\//) { delete $self->{"%$grp"}->{$k}; }	## delete app/xyz ( it's app/app/key )
					if (substr($k,0,1) eq '@') { delete $self->{"%$grp"}->{$k}; }	## delete @giftcards
					if ($k =~ /\./) { delete $self->{"%$grp"}->{$k}; }	# delete payment.yy
					if ($k =~ /[\s]/) { delete $self->{"%$grp"}->{$k}; }	# delete 'modified    '
					}
				}
			$writer->dataElement("$grp", '', %{$self->{"%$grp"}});
			}

		## PAYMENTS? 
		if ($self->is_order()) {
			$writer->startTag('history');
			$writer->raw(&ZTOOLKIT::arrayref_to_xmlish_list($self->{'@HISTORY'},'tag'=>'event','encoder'=>'latin1','content_attrib'=>'content'));
			$writer->endTag('history');

			$writer->startTag('payments');
			$writer->raw(&ZTOOLKIT::arrayref_to_xmlish_list($self->payments(),'tag'=>'payment','encoder'=>'latin1','content_attrib'=>'content'));
			$writer->endTag('payments');

			$writer->startTag('actions');
			foreach my $actionar (@{$self->{'@ACTIONS'}}) {
				my ($eventname,$found, $ts) = @{$actionar};
				$writer->dataElement('action','',  'verb'=>$eventname, found=>$found, ts=>$ts);
				# $writer->raw(&ZTOOLKIT::arrayref_to_xmlish_list($self->{'@ACTIONS'},'tag'=>'action','encoder'=>'latin1','content_attrib'=>'content'));
				}
			$writer->endTag('actions');

			$writer->startTag('fees');
			$writer->raw(&ZTOOLKIT::arrayref_to_xmlish_list($self->fees(1),'tag'=>'fee','encoder'=>'latin1'));
			$writer->endTag('fees');

			$writer->startTag('shipments');
			$writer->raw(&ZTOOLKIT::arrayref_to_xmlish_list($self->{'@SHIPMENTS'},'tag'=>'pkg','encoder'=>'latin1'));
			$writer->endTag('shipments');
			}

		if ($self->is_supplier_order()) {
			$writer->endTag('order');
			}
		elsif ($self->is_cart()) {
			$writer->endTag('cart');		
			}
		else {
			$writer->endTag('order');
			}
		$writer->end();
		}

	return($xml);
	}



##
## TIE HASH FUNCTIONS
##
sub DESTROY {
	my ($self) = @_;

	# print STDERR "Calling destroy\n";
	# use Data::Dumper; print STDERR Dumper(@_);
	if ($self->{'_tied'}==0) {
		# print STDERR "Cleaning up stuff in cart on destroy\n";
		undef $self->{'*stuff2'};
		delete $self->{'*stuff2'};
		}
	else {
		$self->{'_tied'}--;
		}
	}

## you can tie one of these options.
##
##	tie %xc, 'CART2', CART2=>$cart2, 'ACCESS'=>'IN' -- internal (in_get/in_set)
##	tie %xc, 'CART2', CART2=>$cart2, 'ACCESS'=>'PR' -- private[admin] (pr_get/pr_set)
##	tie %xc, 'CART2', CART2=>$cart2, 'ACCESS'=>'PU' -- public (pu_get/pu_set)
##
## 	NOTE: access is required (or public is assumed)
##
sub TIEHASH {
	my ($class, %options) = @_;

#	if (not defined $options{'ACCESS'}) {
#		warn "CART2::TIEHASH called without specifying 'ACCESS' parameter == setting to PUBLIC (hope that is what you wanted)\n";
#		$options{'ACCESS'} = 'PU';
#		}
#	elsif (($options{'ACCESS'} eq 'PR') || ($options{'ACCESS'} eq 'IN') || ($options{'ACCESS'} eq 'PU')) {
#		## valid PR/IN/PU
#		}
#	else {
#		warn "CART2::TIEHASH called with invalid 'ACCESS' parameter (should be IN/PR/PU) setting to [PU]BLIC (hope that is what you wanted)\n";
#		$options{'ACCESS'} = 'PU';
#		}

	my $this = undef;
	if (ref($options{'CART2'}) eq 'CART2') { $this = $options{'CART2'}; }
	else { 
		warn "UNSUPPORTED USE OF CART2->TIEHASH\n";
		}
	$this->{'_tied'}++;
#	if (not defined $this->{'@tied'}) { $this->{'@tied'} = []; }
	return($this);
	}

sub UNTIE {
	my ($this) = @_;
	$this->{'_tied'}--;
	}

sub FETCH { 
	my ($this,$key) = @_; 	
	my $val = $this->in_get($key);
	return($val);
	}

sub EXISTS { 
	my ($this,$key) = @_; 
	return( (defined $this->in_get($key))?1:0 ); 
	}

sub DELETE { 
	my ($this,$key) = @_; 
	$this->in_set($key,undef);
	return(0);
	}

sub STORE { 
	my ($this,$key,$value) = @_; 
	$this->in_set($key,$value);
	return(0); 
	}

sub CLEAR { 
	my ($this) = @_; 
	#foreach my $k (keys %{$this}) {
	#	next if (substr($k,0,1) eq '_');
	#	delete $this->{$k};
	#	}
	return(0);
	}

sub FIRSTKEY {
	my ($this) = @_;
	my @KEYS = ();
	if (defined $this->{'%our'}) {
		foreach my $k (keys %{$this->{'%our'}}) { push @KEYS, "our/$k";  }
		}
	if (defined $this->{'%bill'}) {
		foreach my $k (keys %{$this->{'%bill'}}) { push @KEYS, "bill/$k";  }
		}
	if (defined $this->{'%ship'}) {
		foreach my $k (keys %{$this->{'%ship'}}) { push @KEYS, "ship/$k";  }
		}
	if (defined $this->{'%cart'}) {
		foreach my $k (keys %{$this->{'%cart'}}) { push @KEYS, "cart/$k";  }
		}
	if (defined $this->{'%want'}) {
		foreach my $k (keys %{$this->{'%want'}}) { push @KEYS, "want/$k";  }
		}
	if (defined $this->{'%must'}) {
		foreach my $k (keys %{$this->{'%must'}}) { push @KEYS, "must/$k";  }
		}
	if (defined $this->{'%flow'}) {
		foreach my $k (keys %{$this->{'%flow'}}) { push @KEYS, "flow/$k";  }
		}
	if (defined $this->{'%app'}) {
		foreach my $k (keys %{$this->{'%app'}}) { push @KEYS, "app/$k";  }
		}
	if (defined $this->{'%is'}) {
		foreach my $k (keys %{$this->{'%is'}}) { push @KEYS, "is/$k";  }
		}
	if (defined $this->{'%sum'}) {
		foreach my $k (keys %{$this->{'%sum'}}) { push @KEYS, "sum/$k";  }
		}
	if (defined $this->{'%customer'}) {
		foreach my $k (keys %{$this->{'%customer'}}) { push @KEYS, "customer/$k";  }
		}
	$this->{'_KEYS'} = \@KEYS;
	my $x = pop @{$this->{'_KEYS'}};
	return($x);
	}

sub NEXTKEY {
	my ($this) = @_;
	return(pop @{$this->{'_KEYS'}});
	}


##
## LIVE macros are used by site messaging
##
%CART2::LIVE_MACROS = (
	'run.id'=>\&CART::id,
	'run.total_discounts'=>sub {
		my ($self) = @_;
		my $total = 0;
		foreach my $item (@{$self->stuff2()->items()}) {
			if ($item->{'price'}<0) {
				$total += abs($item->{'price'});
				}
			}
		return(sprintf("%0.2f",$total));
		},
	'run.est_ship_yyyy_mm_dd'=>sub {
		my ($self) = @_;
		my $days = undef;
		foreach my $item (@{$self->stuff2()->items()}) {
			if ($item->{'%attribs'}->{'zoovy:ship_latency'}>0) {
				if (not defined $days) { $days = $item->{'%attribs'}->{'zoovy:ship_latency'}; }
				if ($item->{'%attribs'}->{'zoovy:ship_latency'}<$days) { $days = $item->{'%attribs'}->{'zoovy:ship_latency'}; }
				}
			}
		return(POSIX::strftime("%Y-%m-%d",localtime(time()+(86400*$days))));
		},
	'run.has_prebackdelay_yn'=>sub {
		my ($self) = @_;
		my $is_true = 0;
		my $MASK = 0;
		$MASK += 1<<8; ## IS_PREORDER
		$MASK += 1<<10; ## IS_SPECIALORDER
		$MASK += 1<<25; ## IS_BACKORDER
		foreach my $item (@{$self->stuff2()->items()}) {
			if ($item->{'%attribs'}->{'zoovy:prod_is'} & $MASK) { $is_true++; }
			}
		return(($is_true)?'Y':'N');
		},
	'run.has_download_yn'=>sub {
		my ($self) = @_;
		my $is_true = 0;
		my $MASK = 0;
		$MASK += 1<<6; ## IS_DOWNLOAD
		foreach my $item (@{$self->stuff2()->items()}) {
			if ($item->{'%attribs'}->{'zoovy:prod_is'} & $MASK) { $is_true++; }
			}
		return(($is_true)?'Y':'N');
		},
	'run.deduce_bill_countrycode'=>sub {
		my ($self) = @_;
		my $country = undef;
		if (not defined $self) {
			$country = "ISE-run.deduce_bill_country received no cart";
			&ZOOVY::confess("zoovy","$country",justkidding=>1);
			}
		elsif (length($self->in_get('bill/countrycode'))==2) {
			$country = $self->in_get('bill/countrycode');
			}
		elsif (defined $self->in_get('bill/countrycode')) {
			$country = substr($self->in_get('bill/countrycode'),0,2);
			}
		elsif ($self->in_get('bill/countrycode') eq '') {
			$country = 'US';
			}
		elsif ($self->in_get('bill/countrycode') ne '') {
			my $result = &ZSHIP::resolve_country("ZOOVY"=>$self->in_get('bill/countrycode'));
			if (defined $result) { $country = $result->{'ISO'}; }
			}
		else {
			## this line should never be reached!
			$country = "XZ";
			}
		return($country);
		}
	);


##
## returns address in a consistent, parsable format (used in address validation, possibly elsewhere)
## type: ship|bill
sub get_address {
	my ($self,$type) = @_;

	if (not defined $self->in_get("$type/countrycode")) { 
		$self->in_set("$type/countrycode",'US');
		}

	my $ADDRESSREF = $self->{"%$type"};
#	my %ADDRESS = ();
#	$ADDRESS{'address1'} = $self->fetch_property("data.$type\_address1");
#	$ADDRESS{'address2'} = $self->fetch_property("data.$type\_address2");
#	$ADDRESS{'city'} = $self->fetch_property("data.$type\_city");
#	$ADDRESS{'state'} = $self->fetch_property("data.$type\_state");
#	$ADDRESS{'zip'} = $self->fetch_property("data.$type\_zip");
#	$ADDRESS{'country'} = $self->fetch_property("data.$type\_country");
#
#	if (
##		($ADDRESS{'bill_country'} ne 'US') && 
#		($ADDRESS{'bill_country'} ne '') && 
#		($ADDRESS{'bill_country'} ne 'USA') && 
#		(uc($ADDRESS{'bill_country'}) ne 'UNITED STATES')) {
#		## international address 
#		$ADDRESS{'_is_international'} = 1;
#		}
#	else {
#		$ADDRESS{'_is_international'} = 0;
#		}

	## note: eventually we might do a country code lookup here.
	return($ADDRESSREF);
	}




##
## $type is either: ship|bill
##
## returns:
##	
sub validate_address {
	my ($self,$type) = @_;

	my ($webdbref) = $self->webdbref();

	require ZSHIP;
	my @ISSUES = ();

	my $address = undef;
	if ($type eq 'ship') { $address = $self->get_address('ship'); }
	elsif ($type eq 'bill') { $address = $self->get_address('bill'); }
	else {
		push @ISSUES, [ 'ISE', 'verify_address_unknown_type', '', 'Cannot verify an unknown address type' ];
		}

	# print STDERR "ADDRESS: ".Dumper($address);

	my $validator = '';
	if (not defined $address) {
		}
	elsif ($address->{'countrycode'} ne 'US') {
		## do not attempt to validate non US addresses
		}
	elsif (defined $webdbref) {
		require ZSHIP::UPSAPI;
		&ZSHIP::UPSAPI::upgrade_webdb($webdbref);
		if ($webdbref->{'upsapi_config'} ne '') {
			my $config = &ZTOOLKIT::parseparams($webdbref->{'upsapi_config'});
			# open F, ">>/tmp/config"; print F "$webdbref->{'upsapi_config'}\n"; close F;
			if (not $config->{'.validation'}) {
				## no validation required.
				}
			elsif ($config->{'enable_dom'}) { 
				$validator = 'UPS'; 
				}
			}
		}

	## The suggestions hash is keyed on a pretty name for the suggested address, with a value of another hash
	## The hash in the value is keyed by address, address2, city, state, zip, and country
	## When the suggestion is selected from the drop-down, those fields should be overwritten with the
	## suggested information.
	my $suggestions = [];
	my $meta = {};
		
#	elsif ((defined $webdbref->{'endicia_avs'}) && ($webdbref->{'endicia_avs'}>0)) {
##		require ZSHIP::ENDICIA;
##		($err_ref) = &ZSHIP::ENDICIA::validate_address($USERNAME,
##				$self->fetch_property("$type.bill_address1"),$self->fetch_property("$type.bill_address2"),
##				$self->fetch_property("$type.bill_city"),$self->fetch_property("$type.bill_state"),$self->fetch_property("$type.bill_zip"),$self->fetch_property("$type.bill_country"),$webdbref);
#		}
#

	if ($validator eq 'UPS') {
		require ZSHIP::UPSAPI;
		($suggestions,$meta) = &ZSHIP::UPSAPI::validate_address($self->username(),$webdbref,$address);
		print STDERR 'SUG/META'.Dumper($suggestions,$meta)."\n";
		}

	## give each suggestion it's own unique alpha id.
	if (scalar(@{$suggestions})>0) {

		my $i = 1;
		foreach my $suggestion (@{$suggestions}) {
			if (not defined $suggestion->{'prompt'}) {
				$suggestion->{'prompt'} = sprintf("%s, %s, %s",$suggestion->{'city'},$suggestion->{'state'},$suggestion->{'zip'});
				}

			if (not defined $suggestion->{'id'}) {
				$suggestion->{'id'} = ++$i;
				}
			}

		## add in the default 
		$address->{'prompt'} = 'Current Address';
		$address->{'id'} = 0;
		unshift @{$suggestions}, $address;
		}

	return($suggestions,$meta);
	}


##
## some stupid fucking marketplaces think it's a good idea to just give us a tax total and we're
##	supposed to trust those pricks. you know the ones who create those overly intuitive feeds.
## yeah i think i'll pass on that.. so we'll figure out our own effective tax rate thank you very
## much. 
##
## options (use'em if ya want 'em)
##		%options 
##			events=>\@HISTORY (your events array) -- great for debugging internal logic.
##			src=>"ebay" or maybe src=>'buy' (used in some of the events will default to "Marketplace")
##			ignore_order_totals_dont_match --- yeah i know this one is kind long for a parameter..
##				but it's self documenting, if you don't like it .. go fuck yourself.
##				basically - this will try and reverse logic, but will ultimately use marketplace
##				for the totals, even it's just fucking wrong, otherweise you might be in for a fatal error.. or 
##				perhaps you'll build your own spiffy handler... anything is possible. ANYTHING! =)
##
sub guess_taxrate_using_voodoo {
	my ($self, $tax_total, %options) = @_;

	my $source = $options{'src'};
	if ($source eq '') { $source = 'Marketplace'; }

	my $evref = $options{'events'};
	if (not defined $evref) {
		$evref = [];
		}

	my $IGNORE_ORDER_TOTALS_DONT_MATCH = 0;

	my %cart2 = (); tie %cart2, 'CART2', 'CART2'=>$self;
	
	my ($sumsref) = $self->stuff2()->sum({});

	## reverse out the tax rate(s)
	if (($cart2{'sum/tax_total'}>0) || ($tax_total>0)) {
		my (%taxinfo) = &ZSHIP::getTaxes($self->username(),
			$self->prt(),
			city=>$cart2{'ship/city'},
			state=>$cart2{'ship/region'},
			zip=>$cart2{'ship/postal'},
			country=>$cart2{'ship/countrycode'},
			address1=>$cart2{'ship/address1'}
			);

		my $rate = sprintf("%.5f",($cart2{'sum/tax_total'} / $sumsref->{'items_total'}) * 100);
		$cart2{'sum/tax_rate_state'} = $rate;
		# $self->totals();			

		#print 'TAXINFO'.Dumper(\%taxinfo);
		#print "RATE: ebay:$rate == zoovy:$taxinfo{'tax_rate'}\n"; 
		push @{$evref}, "mkt-tax-total:\$$tax_total zoovy-tax-total:\$$cart2{'sum/tax_total'}";
		push @{$evref}, "mkt-tax-rate:$rate zoovy-tax:$taxinfo{'tax_rate'}";

		if ($rate == $taxinfo{'tax_rate'}) {
			$cart2{'our/tax_zone'} = $taxinfo{'tax_zone'};
			push @{$evref}, "Marketplace matches our tax rate";
			}
		elsif ($tax_total == $cart2{'sum/tax_total'}) {
			push @{$evref}, "Zoovy didn't agree with $source on sales tax %$rate - but fortunately we can both agree on tax amount: \$$cart2{'sum/tax_total'}.";
			}
		elsif ( sprintf("%.2f",int($cart2{'sum/tax_total'}*100)) != int(sprintf("%.2f",$tax_total)*100) ) {
			## NOTE: we really ought to do this tax magic shit inside the cart since it's gonna come up for
			## for multiple marketplaces e.g. ebay, amazon, buy.
			## note.. i fully expect to question my sanity for writing this later. bh 2009/10/05
			push @{$evref}, "Zoovy doesn't agree with marketplace on sales tax- lets see if we can find a compromise.";
			my $tax_rate_was = $cart2{'sum/tax_rate_state'};
			my $adjust = 0;
			if ($cart2{'sum/tax_total'}>$tax_total) { 
				$adjust = -0.003; 
				}
			elsif ($cart2{'sum/tax_total'}>$tax_total) { 
				$adjust = 0.003; 
				}
			my $i = 0;
			while ($i++<10000) {
				$cart2{'sum/tax_rate_state'} += $adjust;
				# $self->totals();
				last if (sprintf("%.2f",$cart2{'sum/tax_total'}) == sprintf("%.2f",$tax_total));
				}
			push @{$evref}, 'zoovy says: '.sprintf("%.2f",$cart2{'sum/tax_total'})."  $source needs:".sprintf("%.2f",$tax_total);
			if ($i<10000) {
				push @{$evref}, "compromise found: did $i * $adjust adjustments match tax rate to $source, should be: $taxinfo{'tax_rate'} $source needs: $cart2{'sum/tax_rate_state'}";
				}
		else {
				push @{$evref}, "compromise failed: could not reliably match tax rate to $source after $i attempts (got to $cart2{'sum/tax_rate_state'}), we're gonna ignore the diff..\n";
				$cart2{'sum/tax_rate_state'} = $tax_rate_was;
				$IGNORE_ORDER_TOTALS_DONT_MATCH++;
				}
			}
		else {
			# print STDERR Dumper(\@{$evref});
			Carp::confess("Could not determine tax rate (ebay: $rate) (zoovy: $taxinfo{'tax_rate'})");
			}
		# print STDERR Dumper(\@{$evref});
		}

	return($IGNORE_ORDER_TOTALS_DONT_MATCH);
	}



##
## $cart2->set_order_flag(1<<7) to turn on	or  0-(1<<7) to turn off 
##
sub set_order_flag {
	my ($self,$value) = @_;

	my $flags = $self->__GET__('flow/flags');
	if ($value < 0) {
		$flags = $flags - ($flags & $value);
		}
	else {
		$flags = $flags | $value;
		}
	$self->in_set('flow/flags',$flags);	
	return($self);
	}



##
## 
## %params
##		removed -- silent=>0|1		 (default is 0) -- avoids making any notes or updates that it saved
##		removed -- fast=>0|1		 (default is 0) -- avoids running any events such as cancel / google notifications
##
## if you're searching for save_order -- perhaps you meant order_save?
##
sub order_save {
	my ($self, %params) = @_;

	$self->__SYNC__();

	if ($self->is_readonly()) {
		&ZOOVY::confess($self->username(),"attempted to save a readonly order (not going to happen)\n".Dumper($self),'justkidding'=>1);
		return();
		}
	elsif ($self->username() eq '') {
		Carp::cluck("ORDER IS IS INVALID - NO USERNAME - WILL NOT SAVE\n");
		}

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my ($ORDER_TB) = DBINFO::resolve_orders_tb($self->username(),$self->mid());
	my $CREATED_TS = time();


	my $is_new = ($self->order_dbid()>0)?0:1;
	my $modified_gmt = time();

	## clean out any Math::BigInt
	foreach my $e (@{$self->{'@HISTORY'}}) {
		if (not defined $e->{'etype'}) { $e->{'etype'} = 0; }
		$e->{'etype'} = sprintf("%d",$e->{'etype'});
		}

	## Good to make sure that the order is correct before issuing a save on it.
	my $err = $self->check();

	## Set the order information in ORDER_POOLS_xx
	if (not $params{'silent'}) {
		$self->__SET__('flow/modified_ts',time());
		}

	my $paymentkey = '';
	foreach my $payrec (@{$self->payments()}) {
		next unless ($payrec->{'puuid'} eq '');	# skip chained
		next unless ($paymentkey eq '');				# once we've found a key, that's the one we keep!
		my ($ps) = substr($payrec->{'ps'},0,1);
		if ($payrec->{'tender'} eq 'CREDIT') {
			my ($acctref) = &ZPAY::unpackit($payrec->{'acct'});
			$paymentkey = substr($acctref->{'CM'},-4);	# should be the masked credit card #
			}
		elsif ($payrec->{'tender'} eq 'PAYPALEC') {
			$paymentkey = substr($payrec->{'txn'},-4); 	# should be the transaction #
			}
		}

	my $erefid = $self->__GET__('want/erefid');
	if ((not defined $erefid) || ($erefid eq '')) { $erefid = $self->__GET__('mkt/erefid'); }
	if (not defined $erefid) { $erefid = ''; }

	if ($self->__GET__('our/order_ts') <= 0) {
		## make sure created time was set
		$self->__SET__('our/order_ts',time());
		}

	if ($self->__GET__('our/orderid') eq '') {
		## wow! this is a bad error case. -- we should NEVER reach this
		$self->__SET__('our/orderid',&CART2::next_id($self->username(),1,$self->cartid()));
		$self->add_history('order_save() had blank Order ID (very bad) setting to next available id');
		}


	if ($self->__GET__('flow/payment_status') =~ m/^0/) {
#		$desc = 'Paid In Full';
		if (int($self->__GET__('flow/paid_ts'))==0) {
			$self->__SET__('flow/paid_ts', time());
			}
		## note we always need to run fire_event('paid') because zid sometimes sets paid_ts
		$self->queue_event('paid');
		}


	## if we cancel an order - then return the inventory
	if ($self->__GET__('flow/pool') eq 'DELETED') {
		if (not defined $self->__GET__('flow/cancelled_ts')) { $self->cancelOrder(); }
		}

	## Pool should always be set on ORDER->new so I'm not sure why this is here -AK
	my $qtORDERID = $udbh->quote($self->{'order_id'});
	#if (not defined $self->__GET__('flow/pool')) {
	#	## NEW ORDER DATABASE FORMAT
	#	# $pstmt = "select POOL from $TB use index (MID_4) where ORDERID=$qtORDERID and MID=$self->mid() /* $self->username() */";
	#	$pstmt = "select POOL from $TB where ORDERID=$qtORDERID and MID=$self->mid() /* $self->username() */";
	#	$sth = $udbh->prepare($pstmt);
	#	my $rv = $sth->execute();
	#	if ($sth->rows()>0) {
	#		$is_new = 0;		# note, we don't need to do another lookup, if we got here, this isn't a new order!
	#		($self->__GET__('flow/pool')) = $sth->fetchrow_array();
	#		$sth->finish();
	#		}
	#	}

	if (not defined $self->__GET__('flow/pool')) { 
		$self->__SET__('flow/pool','RECENT'); 
		$self->add_history('SAVE - blank pool, set order to RECENT',etype=>4);
		} 
	## Verify this is really new! (so we do an update rather than insert!)


	#if ($is_new) {
	#	$pstmt = "select count(*) from $TB where MID='$self->mid()' and ORDERID=$qtORDERID";
	#	# $pstmt = "select count(*) from $TB use index (MID_4) where MID='$self->mid()' and ORDERID=$qtORDERID";
	#	# print STDERR $pstmt."\n";
	#	$sth = $udbh->prepare($pstmt);
	#	$sth->execute();
	#	my ($count) = $sth->fetchrow();
	#	$sth->finish();
	#	if ($count>0) { $is_new = 0; }
	#	# print STDERR "COUNT: $count\n";
	#	}

	# print STDERR "IS: $is_new\n";


	## PAIDTXN is a foreign payment key
	my $PAIDTXN = '';
	if ($self->__GET__('flow/payment_method') eq 'AMAZON') {
		$PAIDTXN = $self->__GET__('mkt/amazon_orderid');
		}
	elsif ($self->__GET__('flow/payment_method') eq 'GOOGLE') {
		$PAIDTXN = $self->__GET__('mkt/google_orderid');
		}
	if (not defined $PAIDTXN) { $PAIDTXN = ''; }

	if (not defined $self->__GET__('flow/paid_ts')) {
		$self->__SET__('flow/paid_ts',0);
		}
	## changed to ship_date 2009-05-19, this is what ZID uses
	if (not defined $self->__GET__('flow/shipped_ts')) {
		$self->__SET__('flow/shipped_ts',0);
		}
	## make sure we have a cartid set.
	if (not defined $self->__GET__('cart/cartid')) {
		$self->__SET__('cart/cartid','');
		}


	## bill zone is 
	##		USCA92024 (2 digit country, 2 digit state, zip)
	##		CA______	 (2 digit country, 7 digit zip)
	my $billzone = '';
	if ((not defined $self->__GET__('bill/countrycode')) || ($self->__GET__('bill/countrycode') eq '')) { 
		# UNKNOWN ORDER
		$self->__SET__('bill/countrycode', '');
		$billzone = '??';
		}	
	elsif ($self->__GET__('bill/countrycode') eq 'US') {
		## DOMESTIC ORDER
		if (not defined $self->__GET__('bill/region')) { $self->__SET__('bill/region',''); }
		if (not defined $self->__GET__('bill/postal')) { $self->__SET__('bill/postal',''); }
		$billzone = sprintf("US%2s%5s",$self->__GET__('bill/region'),$self->__GET__('bill/postal'));
		}
	else {
		## INTERNATIONAL ORDER
		$billzone = substr($self->__GET__('bill/countrycode'),0,2).substr($self->__GET__('bill/postal'),0,10);
		}

	my $shipzone = '';
	if ((not defined $self->__GET__('ship/countrycode')) || ($self->__GET__('ship/countrycode') eq '')) { 
		# UNKNOWN ORDER
		$self->__SET__('ship/countrycode', '');
		$shipzone = '??';
		}	
	elsif ($self->__GET__('ship/countrycode') eq 'US') {
		## DOMESTIC ORDER
		if (not defined $self->__GET__('ship/region')) { $self->__GET__('ship/region',''); }
		if (not defined $self->__GET__('ship/postal')) { $self->__GET__('ship/postal',''); }
		$shipzone = sprintf("US%2s%5s",$self->__GET__('ship/region'),$self->__GET__('ship/postal'));
		}
	else {
		## INTERNATIONAL ORDER
		$shipzone = substr($self->__GET__('ship/countrycode'),0,2).substr($self->__GET__('ship/postal'),0,10);
		}

	my $billname = '';
	if (defined $self->__GET__('bill/lastname')) {
		$billname = $self->__GET__('bill/lastname').', '.$self->__GET__('bill/firstname'); 
		}
	if (not defined $billname) { $billname = ''; }

	my $shipname = '';
	if (defined $self->__GET__('ship/lastname')) {
		$shipname = $self->__GET__('ship/lastname').', '.$self->__GET__('ship/firstname'); 
		}
	if (not defined $shipname) { $shipname = ''; }

	$self->__SYNC__();

	my $TB = &DBINFO::resolve_orders_tb($self->username(),$self->mid());
	
	
	
	if (not defined $self->__GET__('flow/payment_status')) { 
		$self->__SET__('flow/payment_status','999');
		}

	if (not defined $self->__GET__('flow/payment_method')) { 
		$self->__SET__('flow/payment_method','ERROR');
		}

	if (not defined $self->__GET__('sum/order_total')) { 
		$self->__SET__('sum/order_total','0');
		}

	my $paymethod = $self->__GET__('flow/payment_method');
	if ($paymethod eq 'PAYPALEC') { $paymethod = 'PPEC'; }

	my $review_status = $self->__GET__('flow/review_status');
	if (not defined $review_status) { $review_status = ''; }

	my $FLAGS = int($self->__GET__('our/flags'));

	delete $self->{'*O'};

	my %dbparams = ();
	$dbparams{'ID'} = 0;
	$self->{'v'} = $dbparams{'V'} = $self->v();
	$dbparams{'MERCHANT'} = $self->username();
	$dbparams{'MID'} = $self->mid();

	$dbparams{'ORDERID'} = $self->oid();
	$dbparams{'MKT_BITSTR'} = sprintf("%s",$self->__GET__('our/mkts'));
	$dbparams{'ORDER_BILL_NAME'} = substr(sprintf("%s %s",$self->__GET__('bill/firstname'),$self->__GET__('bill/lastname')),0,30);
	$dbparams{'ORDER_BILL_EMAIL'} = substr(sprintf("%s",$self->__GET__('bill/email')),0,30);
	$dbparams{'ORDER_BILL_ZONE'} = $billzone;

	$dbparams{'POOL'} = $self->__GET__('flow/pool');
	$dbparams{'CUSTOMER'} = int($self->__GET__('customer/cid'));
	$dbparams{'SHIPPED_GMT'} = int($self->__GET__('flow/shipped_ts'));
	$dbparams{'ORDER_PAYMENT_STATUS'} = substr($self->__GET__('flow/payment_status'),0,3);
	$dbparams{'ORDER_PAYMENT_METHOD'} = substr($paymethod,0,4);
	$dbparams{'ORDER_PAYMENT_LOOKUP'} = substr($paymentkey,0,4);
	$dbparams{'ORDER_TOTAL'} = $self->__GET__('sum/order_total');
	$dbparams{'ORDER_SHIP_NAME'} = substr($shipname,0,30);
	$dbparams{'ORDER_SHIP_ZONE'} = substr($shipzone,0,12);
	$dbparams{'ORDER_EREFID'} = substr($erefid,0,30);
	$dbparams{'ITEMS'} = int($self->__GET__('sum/items_count'));
	$dbparams{'REVIEW_STATUS'} = $review_status;
	$dbparams{'PAID_GMT'} = $self->__GET__('flow/paid_ts');
	$dbparams{'PAID_TXN'} = $PAIDTXN;
	$dbparams{'SYNCED_GMT'} = 0;
	if (($dbparams{'PAID_GMT'} > 0) && ($dbparams{'PAID_GMT'} < ($^T-(86400*90))) ) {
		## don't flag orders paid after 90 days as need sync
		delete $dbparams{'SYNCED_GMT'};
		}
	$dbparams{'*FLAGS'} = int($self->__GET__('our/flags'));

	## temporary until we rebuild sdomain in database
	$dbparams{'SDOMAIN'} = $self->__GET__('our/sdomain');
	if (not defined $dbparams{'SDOMAIN'}) {
		delete $dbparams{'SDOMAIN'};
		}

	my @REDIS_EVENTS = ();
	my $ts = time();
	if ($self->order_dbid()==0) {
		## this is a new order, force it to run 'create'
		$self->queue_event('create','override'=>1);
		}
	foreach my $action (@{$self->{'@ACTIONS'}}) {
		if ($action->[2] > 0) {
			## this event has already been completed, don't re-run it
			}
		elsif ($params{'silent'}) {
			## we will not process events.
			}
		elsif ($action->[1] == 0) {
			## we need some sort of reliability check here.
			my ($pstmt) = &DBINFO::insert($udbh,'EVENT_RECOVERY_TXNS',{
				'MID'=>$self->mid(),
				'CREATED_GMT'=>$ts,
				'CLASS'=>'ORDER',
				'ACTION'=>$action->[0],
				'GUID'=>$self->oid()
				},'verb'=>'insert','sql'=>'1');
			print STDERR "$pstmt\n";
			my ($rv) = $udbh->do($pstmt);
			if (defined $rv) {
				push @REDIS_EVENTS, $action->[0];
				$action->[1] = $ts;
				}
			}
		}
	
	if (not $params{'from_event'}) {
		## we don't fire a SAVE event if we came from an event
		push @REDIS_EVENTS, 'SAVE'; ## ORDER.SAVE
		}

	my %copy = ();
	$copy{'v'} = $self->v();
	$copy{'USERNAME'} = $self->username();
	$copy{'PRT'} = $self->prt();
	$copy{'ORDERID'} = $self->oid();
	$copy{'*stuff2'}->{'@ITEMS'} = $self->stuff2()->{'@ITEMS'};

	foreach my $group (@CART2::VALID_GROUPS) {
		next if (not defined $self->{"%$group"});
		$copy{"%$group"} = $self->{"%$group"};
		}
	foreach my $group ('@SHIPMENTS','@PAYMENTS','@FEES','@ACTIONS','@HISTORY') {
		next if (not defined $self->{$group});
		$copy{$group} = $self->{$group};
		}

	$dbparams{'YAML'} = YAML::Syck::Dump(\%copy);
	if (length( $dbparams{'YAML'} ) > 100000) {
		$copy{'@HISTORY'} = [ {'ts'=>time(), 'content'=>'Large order - event history deleted', 'uuid'=>'HISTORY'} ];
		$dbparams{'YAML'} = YAML::Syck::Dump(\%copy);
		}


	print STDERR sprintf("ORDERDBID: %d\n",$self->order_dbid());


	if ($self->order_dbid()>0) { 
		## EXISTING ORDER
		$dbparams{'ID'} = $self->order_dbid(); 
		$dbparams{'*MODIFIED_GMT'} =  $modified_gmt;
		$dbparams{'*FLAGS'} = "(FLAGS|$FLAGS)";
		my $pstmt = &DBINFO::insert($udbh,$ORDER_TB,\%dbparams,'sql'=>1,'verb'=>'update',key=>['MID','ORDERID','ID']);
		my $rv = $udbh->do($pstmt);
		if (not defined $rv) {
			open F, sprintf(">>/tmp/order_%s_failed.sql",$self->{'order_id'});
			print F "$pstmt;\n";
			close F;
			}
		}
	else {
		## NEW ORDER
		$dbparams{'ID'} = 0;
		$dbparams{'CREATED_GMT'} = $CREATED_TS;
		$dbparams{'SDOMAIN'} = $self->__GET__('our/sdomain');
		if (not defined $dbparams{'SDOMAIN'}) {
			delete $dbparams{'SDOMAIN'};
			}
		$dbparams{'*MODIFIED_GMT'} = $CREATED_TS;
		if ($self->cartid() ne '') {
			$dbparams{'CARTID'} = $self->cartid();
			}
		$dbparams{'PRT'} = $self->prt();
		my $pstmt = &DBINFO::insert($udbh,$ORDER_TB,\%dbparams,'sql'=>1,'verb'=>'insert');
		my ($rv) = $udbh->do($pstmt);
		if (not defined $rv) {
			open F, sprintf(">>%s/order_%s_%s_failed.sql",&ZOOVY::memfs(),$self->username(),$self->{'order_id'});
			print F "$pstmt;\n";
			close F;
			}
		$pstmt = "select ID from $TB where MID=".$self->mid()." and ORDERID=".$udbh->quote($self->oid());
		my ($ID) = $udbh->selectrow_array($pstmt);
		if ($ID==0) {
			open F, sprintf(">>%s/order_create_%s_%s_failed.sql",&ZOOVY::memfs(),$self->username(),$self->{'order_id'});
			print F "$pstmt;\n";
			close F;
			}
		else {
			$self->__SET__('our/order_ts',$CREATED_TS);
			$self->{'ODBID'} = $ID;
			}
		}


	if ($is_new) {
		my $MKT = $self->{'mkt'};		## 'mkt' is initialized by initialize_new

		my $CARTID = $self->__GET__('cart/cartid');
		if (($CARTID eq '') || ($CARTID eq '*')) { $CARTID = undef; }
		}

	$self->__SET__('flow/modified_ts',$modified_gmt);

	## go through any tracking stuff, make sure we've triggered tracking events
	if (defined $self->{'@SHIPMENTS'}) {
		foreach my $trk (@{$self->{'@SHIPMENTS'}}) {
			if (not defined $trk->{'ins'}) {
				## no insurance
				}
			elsif ($trk->{'ins'} eq 'UPIC') {
				if ($trk->{'void'}>0) {
					my $pstmt = "update UPIC set VOID_GMT=".$trk->{'void'}." where ";
					$pstmt .= " MID=".$self->mid()." /* ".$self->username()." */ ";
					$pstmt .= " and ORDERID=".$udbh->quote($self->oid());
					$pstmt .= " and TRACK=".$udbh->quote($trk->{'track'});
					print STDERR $pstmt."\n";
					$udbh->do($pstmt);
					}
				elsif (defined $trk->{'upic'}) {
					## we've already recorded a upic transaction #
					}
				else {
					my $pstmt = &DBINFO::insert($udbh,'UPIC',{
						'MID'=>$self->mid(),
						'USERNAME'=>$self->username(),
						'ORDERID'=>$self->oid(),
						'CARRIER'=>$trk->{'carrier'},
						'TRACK'=>$trk->{'track'},
						'DVALUE'=>sprintf("%.2f",$trk->{'dval'}),
						'CREATED_GMT'=>$trk->{'created'},
						},key=>['MID','ORDERID','TRACK'],debug=>2,update=>0);
					print STDERR $pstmt."\n";
					if ($udbh->do($pstmt)) {							
						$trk->{'upic'} = &DBINFO::last_insert_id($udbh);
						}
					}
				
				}
			}
		}


	## update elastic search
	if ((defined $params{'elastic'}) && ($params{'elastic'} == 0)) {
		}
#	elsif ($dbparams{'ID'} > 0) {
#		## don't bother indexing on a CREATE
#		}
#	elsif ($params{'from_event'}) {
#		## we don't fire a SAVE event if we came from an event
#		}
	elsif ($params{'silent'}) {
		}
	else {
		my $do_create = 0;
		my %ALREADYDID = ();
		foreach my $eventname (@REDIS_EVENTS) {
			print STDERR "EVENT: ORDER.$eventname\n";
			$eventname = lc($eventname);
			
			next if (defined $ALREADYDID{$eventname});
			$ALREADYDID{$eventname}++;
			&ZOOVY::add_event($self->username(),
				uc("ORDER.$eventname"),'ORDERID'=>$self->oid(),'PRT'=>$self->prt(),'SRC'=>join("|",caller(1))
				);
			if ($eventname eq 'create') { $do_create++; }
			## CLEANUP EVENT_RECOVERY_TXNS LOG
			my $pstmt = "delete from EVENT_RECOVERY_TXNS where MID=".$self->mid()." and ACTION=".$udbh->quote($eventname)." and GUID=".$udbh->quote($self->oid());	
			print STDERR "$pstmt\n";
			$udbh->do($pstmt);
			}

		# print STDERR "HAD!\n";
		if ($do_create) {
			## index immediate
			eval { $self->elastic_index(); };
			}
		}

	&DBINFO::db_user_close();
	return($self);
	}



##
##
## $params
##		'webdb'
##		'orderid'	
##		'use_order_cartid'
##		'payment_cgi_vars'
##		ORDER->from_cart(%params)
##
sub make_legacy_order {
	my ($self, %params) = @_;

	my $webdbref = $self->webdb();

	## normally we'll only pass orderid if we're re-creating an order.
	my $orderid = $params{'orderid'};
	if ($orderid eq '') { $orderid = undef; }

	if ($params{'use_order_cartid'}) {
		die "use_order_cartid parameter is deprecated -- we will always use our cart id (if we have one)";
		}

	if (ref($self) ne 'CART2') {
		&ZOOVY::confess($self->username(),"ATTEMPTED TO CALL CHECKOUT::finalie with a non CART2 object");
		}

	## 
	## NOTE: 
	##	need to write a script to run through the database and find duplicate cart id's and NULL them
	##		make sure to update the order object itself so it doesn't try to re-insert them/update them
	##		perhaps updates to the CARTID field should ONLY be made on create, otherwise left alone.
	##		the unique constraint should probably be tied to MID,BILL_EMAIL,CARTID so it doesn't collide
	##		across carts. 
	##

	my %cart2 = (); tie %cart2, 'CART2', CART2=>$self;  
	my ($C) = $self->customer();

	# my $DEBUG = 0;	
	# these are set by order_save depending on whether the order was successfully charged or not
	
	#my $ip = $ENV{'REMOTE_ADDR'};
	#if (defined $ENV{'HTTP_X_FORWARDED_FOR'}) { $ip =	$ENV{'HTTP_X_FORWARDED_FOR'}; }
	## Default to the server's address if the remote address is internal (on some payment methods, invalid IPs are automatically declined as fraud)
	#if (($ip =~ /^127\..*$/) || ($ip =~ /^192\.168\..*$/) || ($ip =~ /^10\..*$/)) { $ip = $ENV{'SERVER_ADDR'}; }
	

	$cart2{'bill/email'} =~ s/[\n\r]+//gs;	# not sure how the fuck these get here! (see ticket 107508)

	require XMLTOOLS;
	my %legacy = (
		'erefid'						 => $cart2{'want/erefid'},
		'ship/firstname'			 => $cart2{'ship/firstname'},
		'ship_middlename'		  => $cart2{'ship/middlename'},
		'ship_lastname'			 => $cart2{'ship/lastname'},
		'ship_phone'				 => $cart2{'ship/phone'},
		'ship_address1'			 => $cart2{'ship/address1'},
		'ship_address2'			 => $cart2{'ship/address2'},
		'ship_city'				  => $cart2{'ship/city'},
		'ship_zip'				  => $cart2{'ship/postal'},
		'ship_state'				  => $cart2{'ship/region'},
		'ship_company'			  => $cart2{'ship/company'},
		'ship_country'			  => $cart2{'ship/countrycode'},
		'bill_firstname'			=> $cart2{'bill/firstname'},
		'bill_middlename'		  => $cart2{'bill/middlename'},
		'bill_lastname'			 => $cart2{'bill/lastname'},
		'bill_phone'				 => $cart2{'bill/phone'},
		'bill_address1'			 => $cart2{'bill/address1'},
		'bill_address2'			 => $cart2{'bill/address2'},
		'bill_city'				  => $cart2{'bill/city'},
		'bill_zip'				  => $cart2{'bill/postal'},
		'bill_state'				  => $cart2{'bill/region'},
		'bill_company'			  => $cart2{'bill/company'},
		'bill_country'			  => $cart2{'bill/countrycode'},
		'bill_email'				 => $cart2{'bill/email'},
		'payment_status'			=> 100, # Pending
		'payment_method'			=> $cart2{'want/payby'},
		'ip_address'				 => $cart2{'cart/ip_address'},
		'order_subtotal'			=> sprintf("%.2f", $cart2{'sum/items_total'}),
		'tax_subtotal'			  => sprintf("%.2f", $cart2{'sum/items_taxable'}),
		'state_tax_rate'			=> $cart2{'sum/tax_rate_state'},
		'local_tax_rate'			=> $cart2{'sum/tax_rate_zone'},
		'tax_rate'					=> $cart2{'sum/tax_rate_state'} + $cart2{'sum/tax_rate_zone'},
		'tax_zone'					 => $cart2{'our/tax_zone'},
		'buysafe_val'				 => $cart2{'cart/buysafe_val'},
		'is_giftorder'				 => ($cart2{'is/giftorder'})?1:0,
		'tax_total'				  => sprintf("%.2f", $cart2{'sum/tax_total'}),
		'shp_total'					 => sprintf("%.2f", $cart2{'sum/shp_total'}),
		'shp_method'		 		 => &XMLTOOLS::xml_decode($cart2{'sum/shp_method'}), ## Prevents double-encoding in order XML file (see incident 5603)
		'shp_id'		 		 	 => &XMLTOOLS::xml_decode($cart2{'want/shipping_id'}), ## Prevents double-encoding in order XML file (see incident 5603)
		'shp_carrier'				 => $cart2{'sum/shp_carrier'},
		'shp_taxable'				 => $cart2{'is/shp_taxable'},
		'schedule'					 => $cart2{'our/schedule'},
#		'profile'					 => sprintf("%s",$cart2{'our/profile'}),
		'prt'						 	 => $self->prt(),
		'order_total'				=> sprintf("%.2f", $cart2{'sum/order_total'}),
		'order_notes'				=> $cart2{'want/order_notes'},
#		'ebaycheckout'				 => $cart{'ebaycheckout'},
#		'aolsn'						 => $cart{'aolsn'},
		'meta'						 => $cart2{'cart/refer'},
		'meta_src'					 => $cart2{'cart/refer_src'},
		'cartid'						 => $self->cartid(),
		'multivarsite'				 => $cart2{'cart/multivarsite'},
		'account_manager'			 => $cart2{'customer/account_manager'},
		);

	## key cart fields
	## $self->{'id'} = &CART2::generate_cart_id();	
	# perl -e 'use lib "/backend/lib"; use CART2; my $cart2 = CART2->new_persist("zephyrsports",7,"AgI1Xu9OYU3ufWNRxPOspU6gK");'
	#my %legacy = ();
	if (defined $cart2{'want/referred_by'}) { $legacy{'referred_by'} = $cart2{'want/referred_by'}; }
	foreach my $group ('ship','bill','want','must','our','flow','this','sum','customer','app') {
		foreach my $k (sort keys %{$self->{"%$group"}}) {
			my $ref = $CART2::VALID_FIELDS{"$group/$k"};
			if (defined $ref->{'order1'}) {
				$legacy{ $ref->{'order1'} } = $self->in_get("$group/$k");
				}
			}
		}

	foreach my $k (keys %legacy) {
		$legacy{$k} =~ s/\&apos;/\'/g;
		$legacy{$k} =~ s/\&quot;/\"/g;
		$legacy{$k} =~ s/\&amp;/\&/g;
		}

	#if ($self->is_memory()) {
	#	## no cartid for memory cart's.
	#	}
	#else {
	#	$legacy{'cartid'} = $params{'use_order_cartid'};
	#	}

	## events is an array of event parameters.
	my @HISTORY = ();

	if (length($legacy{'ship_country'})==2) {
		## two digit country code in country field support
		$legacy{'ship_countrycode'} = $legacy{'ship_country'};
		$legacy{'ship_country'} = &ZSHIP::fetch_country_shipname($legacy{'ship_countrycode'});
		}
	elsif (defined $cart2{'ship/countrycode'}) {
		$legacy{'ship_countrycode'} = $cart2{'ship/countrycode'};
		if (not defined $legacy{'ship_country'}) {
			$legacy{'ship_country'} = &ZSHIP::fetch_country_shipname($legacy{'ship_countrycode'});
			}
		}
	else {
		## need zship function to set ISO code
		}


	if (length($legacy{'bill_country'})==2) {
		$legacy{'bill_countrycode'} = $legacy{'bill_country'};
		$legacy{'bill_country'} = &ZSHIP::fetch_country_shipname($legacy{'bill_country'});
		}
	elsif (defined $cart2{'bill/countrycode'}) {
		$legacy{'bill_countrycode'} = $cart2{'bill/countrycode'};
		if (not defined $legacy{'bill_country'}) {
			$legacy{'bill_country'} = &ZSHIP::fetch_country_shipname($legacy{'bill_countrycode'});
			}
		}
	else {
		## need zship function to set ISO code
		}


	if ((defined $cart2{'sum/hnd_total'}) && ($cart2{'sum/hnd_total'}>0)) {
		$legacy{'hnd_total'} = $cart2{'sum/hnd_total'};
		$legacy{'hnd_method'} = $cart2{'sum/hnd_method'};
		$legacy{'hnd_taxable'} = $cart2{'is/hnd_taxable'};
		}
	
	if ((defined $cart2{'sum/spc_total'}) && ($cart2{'sum/spc_total'}>0)) {
		$legacy{'spc_total'} = $cart2{'sum/spc_total'};
		$legacy{'spc_method'} = $cart2{'sum/spc_method'};
		$legacy{'spc_taxable'} = $cart2{'is/spc_taxable'};
		}

	## if insurance is optional, and wasn't purchased, then set the insurance total to zero
	if ($cart2{'is/ins_optional'}) {
		if (not $cart2{'want/ins_purchased'}) { $cart2{'sum/ins_total'} = 0; }
		}

	## wow.. insurance was zero dollars, or wasn't purchased
	if ($cart2{'sum/ins_total'}) {
		$legacy{'ins_total'} = $cart2{'sum/ins_total'};
		$legacy{'ins_method'} = $cart2{'sum/ins_method'};
		$legacy{'ins_taxable'} = $cart2{'is/ins_taxable'};
		}

	#if (($cart{'jf_mid'} ne '') || ($cart{'jf_mid'} ne '')) {
	#	## JELLYFISH is enabled.
	#	$legacy{'jf_mid'} = $cart{'jf_mid'};
	#	$legacy{'jf_tid'} = $cart{'jf_tid'};
	#	}

	#if ($cart{'ebates_ebs'}) {
	#	## eBates is enabled!
	#	$legacy{'ebates_ebs'} = $cart{'ebates_ebs'};
	#	}

	#if (not defined $legacy{'mkt'}) { 
	#	$legacy{'mkt'} = 0; 
	#	}

	if ((defined $webdbref->{'buysafe_mode'}) && ($cart2{'cart/buysafe_val'}>0)) {
		## if bond is optional, and wasn't purchased, then set the bond total to zero

		## wow.. insurance was zero dollars, or wasn't purchased!
		## hmm.. that could mean that bonding was free.
	  	$legacy{'bnd_total'} = $cart2{'sum/bnd_total'};
		$legacy{'bnd_method'} = $cart2{'sum/bnd_method'};
		$legacy{'bnd_taxable'} = $cart2{'is/bnd_taxable'};
		$legacy{'bnd_purchased'} = $cart2{'want/bnd_purchased'};
		# $legacy{'buysafe_token'} = $cart2{'/buysafe_token'};
		# $legacy{'mkt'} = $legacy{'mkt'} | 16384;		# bit 16384 is buysafe!
		}
	

#	if (defined $SITE::URL && $SITE::URL->wrapper() =~ /^ebay/) {
#		$legacy{'sdomain'} = 'ebay.com';
#		# $legacy{'mkt'} = $legacy{'mkt'} | 1;
#		}
#	elsif ($SITE::URL->wrapper() =~ /^aol/) {
#		$legacy{'sdomain'} = 'aol.com';
#		$legacy{'mkt'} += (($legacy{'mkt'} & 8)==0)?8:0;
#		}

	#if ((defined $SITE::SREF) && ($SITE::SREF->{'+sdomain'} ne '')) { 
	#	$legacy{'sdomain'} = $SITE::SREF->{'+sdomain'};
	#	}
	#elsif ($cart{'chkout.sdomain'} ne '') {
	#	$legacy{'sdomain'} = $cart{'chkout.sdomain'};
	#	}
	#else {
	#	$legacy{'sdomain'} = 'unknown';
	#	}
	$legacy{'sdomain'} = $cart2{'our/sdomain'};

	## sdomain
	#if (($legacy{'profile'} eq '') && ($legacy{'sdomain'} ne '')) {
	#	## profile really is recommended on an order, lookup sdomain, if profile is not set then
	#	## emails won't work right in zid.
	#	require DOMAIN::QUERY;
	#	my ($DNSINFO) = &DOMAIN::QUERY::lookup($legacy{'sdomain'});
	#	if (defined $DNSINFO) {
	#		$legacy{'profile'} = $DNSINFO->{'PROFILE'};
	#		}
	#	}

	if (defined $cart2{'want/po_number'}) { $legacy{'po_number'} = $cart2{'want/po_number'}; }
	if ($cart2{'cusstomer/tax_id'}) { $legacy{'tax_id'} = $cart2{'customer/tax_id'};  }

	# U.S. Orders' state and zip get saved to a different place than international ones
	# Shipping...
	if ($cart2{'ship/countrycode'} eq '') {
		$legacy{'ship_state'} = $cart2{'ship/region'};
		$legacy{'ship_zip'}	= $cart2{'ship/postal'};
		}
	else {
		delete $legacy{'ship_state'};
		$legacy{'ship_province'} = $cart2{'ship/region'};
		$legacy{'ship_int_zip'}  = $cart2{'ship/postal'};
		}

	# Billing...
	if ($cart2{'bill/countrycode'} eq '') {
		$legacy{'bill_state'} = $cart2{'bill/region'};
		$legacy{'bill_zip'}	= $cart2{'bill/postal'};
		}
	else {
		delete $legacy{'bill_state'};
		$legacy{'bill_province'} = $cart2{'bill/region'};
		$legacy{'bill_int_zip'}  = $cart2{'bill/postal'};
		}


	## NOTE: since ORDER->new calls CART->reserve_oid() we can assume we're good to go unless
	##			had_problem() is set.	
	# print STDERR "FROM_CART\n";
#	my ($o,$ERROR) = ();
#
#	if (ref($self) ne 'CART2') {
#		print STDERR Carp::confess("ORDER::from_cart -- CART2 is required");
#		die("ORDER::from_cart -- CART2 is required\n");
#		}
#	elsif ($self->cartid() eq '*') {
#		($o,$ERROR) = (undef,"METHOD-ORDER::FROM_CART-WAS-PASSED-TEMP-CART");
#		}
#	elsif (ref($self->stuff()) ne 'STUFF') {
#		($o,$ERROR) = (undef,"METHOD-ORDER::FROM_CART-DID-NOT-FIND-VALID-STUFF-OBJECT");
#		}
#	elsif ((defined $orderid) && ($orderid ne '')) {
#		## load from database
#		($o,$ERROR) = ORDER->new($self->username(),$orderid,new=>0);
#		if (ref($o) eq 'ORDER') { $ERROR = "DEFINITELY-EXISTS-IN-DB"; }
#		}
#	else { 
#		($o,$ERROR) = ORDER->new($self->username(),'*');
#		}
#	#elsif (($self->stuff()->count()==0) && (not $options{'no_stuff_is_okay'})) {
#	#	## not: it's okay 
#	#	return(undef,"METHOD-ORDER::FROM_CART-GOT-NO-STUFF");
#	#	}

#	## at this point we're going to assume all the stupid stuff that never should have happened,
#	## hasn't happened.	
#	if ($ERROR eq '') {
	my ($o) = undef;
	if (1) {
		$o = {};
		$o->{'username'} = $self->username();
		$o->{'version'} = 10;
		$o->{'events'}	= [];
		$o->{'@PAYMENTS'}	= [];

		$o->{'data'} = \%legacy;
		$o->{'data'}->{'created'} = time();
		$o->{'data'}->{'timestamp'} = time();
		$o->{'data'}->{'prt'} = $self->prt();
		$o->{'data'}->{'cartid'} = $self->cartid();

		#if ((defined $options{'use_order_cartid'}) && ($options{'use_order_cartid'} ne '')) {
		#	## some modules (like eBay) use a temp cart to create orders.
		#	$o->{'data'}->{'cartid'} = $options{'use_order_cartid'};
		#	}
		## NOTE: there is a pool called "MISSING" on ZID for orders that were deleted on the server but exist in sync.
		$o->{'orderid'} = $self->oid();
		$o->{'data'}->{'pool'} = 'NEW';
		$o->{'fees'} = $self->{'@FEES'};
		$o->{'events'} = $self->{'@HISTORY'};
		$o->{'tracking'} = $self->{'@SHIPMENTS'};
		$o->{'@dispatch'} = $self->{'@ACTIONS'};
		$o->{'payments'} = $self->{'@PAYMENTS'};

		bless $o, 'ORDER';
		$o->set_stuff($self->stuff2()->as_legacy_stuff());
		}

	return($o);
	}











##############################################
##
## pass in a $RULE returns a $RESULTREF
##
sub rulematch {
	my ($self,$rule,%params) = @_;

	my ($STUFF2) = $self->stuff2();
	my $LM = $params{'*LM'};

	my ($FILTER) = $rule->{'FILTER'};

	my $DEBUG = 0;

	# on disabled return a false match
	$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+START MATCH='$rule->{'MATCH'}' FILTER='$FILTER'"); 

	if (defined $rule->{'MATCHVALUE'}) {
		$rule->{'MATCHVALUE'} =~ s/\$//gs;
		}


	## 
	## PHASE1: expand filters
	##
	my $MATCH_RULE_REF = undef;
	foreach my $MREF (@ZSHIP::RULES::MATCH) {
		if ($rule->{'MATCH'} eq $MREF->{'id'}) { 
			$MATCH_RULE_REF = $MREF;
			}
		}

	
	my $evalsub = undef;
	if ($rule->{'MATCH'} eq 'FILTER_IS_SUBSTRING') {
		## substring filters that work off substrings are special.
		$evalsub = sub {
			my ($stid,$item,$FILTER,$self) = @_;
			my $RESULT = 0;
			my $filt = &ZSHIP::RULES::filter_to_regex($FILTER);
			if ($item->{'description'} =~ m/$filt/i) { 
				$RESULT++;
				}
			return($RESULT);
			};
		}
	#elsif ((defined $MATCH_RULE_REF) && (defined $MATCH_RULE_REF->{'use_filter'}) && ($MATCH_RULE_REF->{'use_filter'}==0)) {
	#	## THIS RULE DOES NOT USE A FILTER.
	#	$evalsub = sub { return(1); }
	#	}
	#elsif ($rule->{'FILTER'} eq '') {
	#	## NO FILTER SPECIFIED.
	#	$evalsub = sub { return(1); }
	#	}
	elsif ($FILTER =~ /^\@\@/) {
		## okay .. extend version 2 e.g.:
		## @@
		##	zoovy:profile==PROFILE
		##	zoovy:profile==ASDF
		# print STDERR "FILTER: $FILTER\n";

		$evalsub = sub {
			my ($stid,$item,$FILTER,$self) = @_;
			my $RESULT = 0;
			$FILTER = substr($FILTER,2);
			foreach my $rule (split(/[\n\r]+/s,$FILTER)) {
				next if ($rule eq '');
				next if ($RESULT);
				
				if ($rule =~ /^([a-z0-9\_\:]+)(==|\<\>|\>\=|\<\=)(.*)$/) {
					my ($attrib,$op,$match) = ($1,$2,$3);

					my $val = $item->{'%attribs'}->{$attrib};
					if ((not defined $val) && (defined $item->{'full_product'}->{$attrib})) { 
						# &ZOOVY::confess($self->username(),"LEGACY RULES referenced $attrib in full product",justkidding=>1);
						$val = ($item->{'%attribs'}->{$attrib} = $item->{'full_product'}->{$attrib}); 
						}

					if ($op eq '==') {
						if ($val eq $match) { $RESULT++; }
						}
					elsif ($op eq '<>') {
						if ($val ne $match) { $RESULT++; }
						}
					elsif ($op eq '>=') {
						if ($val >= $match) { $RESULT++; }
						}
					elsif ($op eq '<=') {
						if ($val <= $match) { $RESULT++; }
						}

					# print STDERR "EXTENDED RULE: attr=[$attrib] op=[$op] match=[$match] val=[$val] RESULT[$RESULT]\n";
					}
				}
			return($RESULT);
			};
		}
	else {
		## LEGACY PRODUCT ID FILTER e.g.
		## 
		$evalsub = sub {
			my ($stid,$item,$FILTER,$self) = @_;
			my $sku = $stid;
			if ($sku =~ /\*(.*?)$/) { $sku = $1; }		# remove claims
			if ($sku =~ /^(.*?)\/.*$/) { $sku = $1; }		# strip non-inventoriable options
			# since we expanded $FILTER to a regex, life is grand!
			($FILTER) = &ZSHIP::RULES::filter_to_regex($FILTER);
			my $result = ($sku =~ /^(?:$FILTER)$/i)?1:0;
			$self->is_debug() && $LM->pooshmsg(sprintf("RULE[$rule->{'.line'}]-%s|+SKU[$sku] FILTER[$FILTER] PASS=$result",$result?'MATCH':'SKIP'));
			return($result)
			}
		}


	## 
	## PHASE1: compute %RESULT
	##

	my @stids = $STUFF2->stids();
	my %prices = ();
	my %RESULT = (
		'matches'=>0,		## $matches is used to keep track of the # of times we match (just SKUs)
		'totalitem'=>0,	## Total sum (in dollars) of all the prices, extended by qty.
		'totalsku'=>0,		## Total sum (in dollars) of all the prices, NOT extended by qty
		'qtymatch'=>0,		## $qtymatch is used to keep track of how many actual products we matched.
		'skus'=>',',			## the final result will be ,sku1,sku2,sku3
		);

	foreach my $item (@{$STUFF2->items()}) {
		# if $it is an external product then go ahead strip off the piece BEFORE and including the *
		my $stid = $item->{'stid'};

		my $sku = $item->{'stid'};
		if ($sku =~ /\*(.*?)$/) { $sku = $1; }		# remove claims
		if ($sku =~ /^(.*?)\/.*$/) { $sku = $1; }		# strip non-inventoriable options

		next if ($sku eq ''); 
		## Skip legacy promotions
		next if (not defined $item); ## Should probably scream here since the laws of the universe are likely broken at this point.

		if ((defined $self) && ($self->is_debug())) { 
			my ($result) = $evalsub->($stid,$item,$FILTER,$self);
			$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+rulematch_cart // CHECKING: stid=[$stid] sku=[$sku] AGAINST=[$FILTER] RESULT=[$result]"); 
			}

		next unless $evalsub->($stid,$item,$FILTER,$self);

		$prices{$stid} = $item->{'price'};
		# $matches++; # move matches forward

		$RESULT{'matches'}++;
		$RESULT{'totalsku'} += $item->{'price'};
		$RESULT{'totalitem'} += ($item->{'qty'} * $item->{'price'});
		$RESULT{'qtymatch'} += $item->{'qty'};
		$RESULT{'skus'} .= $sku.',';
		if (not defined $RESULT{'%PRICES'}) { $RESULT{'%PRICES'} = (); }
		$RESULT{'%PRICES'}->{$stid} = $item->{'price'};
		if (not defined $RESULT{'%QUANTITIES'}) { $RESULT{'%QUANTITIES'} = (); }
		$RESULT{'%QUANTITIES'}->{$stid} = $item->{'qty'};

#		$totalsku  += $item->{'price'};
#		$totalitem += ($item->{'qty'} * $item->{'price'});
#		$qtymatch  += $item->{'qty'};
#		$skus .= $sku.',';
		}
	$RESULT{'@FILTER'} = $FILTER;

	## Guide to variables
	## $matches contains the SKU matches
	if ((defined $self) && ($self->is_debug())) { 
		$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+MATCH:$rule->{'MATCH'} rulematch_cart finished // results: ".&ZOOVY::debugdump(\%RESULT));
		}

	## 
	## PHASE3: apply MATCH to determine *IF* we should do the EXEC (the actual EXEC is handled by each subsystem)
	##


	my $DOACTION = undef;
	my ($skumatch,$qtymatch) = (undef,undef);

	# 0 = disabled .. so we don't do anything
	if ($rule->{'MATCH'} eq 'IGNORE') {
		$DOACTION = undef;
		}
	# 100, 101, 102, 103 - not handled here 
	elsif ($rule->{'MATCH'} eq 'IS_TRUE') {
		($skumatch,$qtymatch) = (1,1);
		}
	elsif ($rule->{'MATCH'} eq 'NOTHING_IN_FILTER') {
		# 4 = all products match

#		print STDERR 'RESULT: '.Dumper(\%RESULT);
#		die();

		if ($RESULT{'matches'}==0) { 
			$DOACTION = $rule->{'EXEC'}; 
			($skumatch,$qtymatch) = (1, $RESULT{'qtymatch'});
			}
		$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+ ** NOTHING IN FILTER HAD ".int($RESULT{'matches'})." MATCHES (SETTING DOACTION=$DOACTION)");
		}
	elsif ($rule->{'MATCH'} eq 'ALL_IN_FILTER') {
		# 5 = all products match
		if ($RESULT{'matches'} == $STUFF2->count('show'=>'real')) { $DOACTION = $rule->{'EXEC'}; }
		$self->is_debug() && $LM->pooshmsg(sprintf("RULE[$rule->{'.line'}]|+ALL_IN_FILTER RESULT MATCHES:$RESULT{'matches'} needs (%d items in cart)",$STUFF2->count('show'=>'real')));
		}
	elsif ($rule->{'MATCH'} eq 'ALL_NOT_PRESENT') {
		# the inverse of ALL_IN_FILTER
		if ($RESULT{'matches'} != $STUFF2->count('show'=>'real')) { $DOACTION = $rule->{'EXEC'}; }
		$self->is_debug() && $LM->pooshmsg(sprintf("RULE[$rule->{'.line'}]|+ALL_NOT_PRESENT RESULT MATCHES:$RESULT{'matches'} cannot be (%d items in cart)",$STUFF2->count('show'=>'real')));
		}
	elsif ($rule->{'MATCH'} eq 'SANDBOX/YES') {
		## true if cart is in sandbox mode.
		if ($self->{'+sandbox'}) { $DOACTION = $rule->{'EXEC'}; }
		}
	elsif ($rule->{'MATCH'} eq 'SANDBOX/NO') {
		## true if cart is in sandbox mode.
		if (not $self->{'+sandbox'}) { $DOACTION = $rule->{'EXEC'}; }
		}
	## 6 = three or more matches?? whats up with that
	## 7 = state (not handled here)
	## 8 = country (not handled here)
	## these are all discount rules.
	elsif ($rule->{'MATCH'} eq 'POGMATCH') {
		## FILTER SYNTAX:
		## :A0
		## :B001
		## /A001
		$RESULT{'matches'} = 0;
		$RESULT{'qtymatch'} = 0;
		my @matches = ();
		foreach my $line (split(/[\n\r\,]+/,$rule->{'FILTER'})) {
			$line =~ s/[\s]+//g;
			push @matches, $line;
			}

		my @stids = $STUFF2->stids();
		$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 64 Rule[$rule->{'.line'}] stids: ".join("!",@stids));

		foreach my $stid (@stids) {
			my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($stid);
			foreach my $matches (@matches) {
				$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 128 Rule[$rule->{'.line'}] test if \"$matches\" is in \":$invopts\/$noinvopts\"");
				if (index(":$invopts/$noinvopts",$matches)>=0) { 
					$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 128 Rule[$rule->{'.line'}] MATCHED!"); 
					$RESULT{'skus'} .= "$stid,"; $RESULT{'matches'}++; $RESULT{'qtymatch'}++; 
					}				
				}
			}
		if ($RESULT{'matches'}>0) { $DOACTION = $rule->{'EXEC'}; }
		# $RESULT{'skus'}; 
		}
	elsif ($rule->{'MATCH'} =~ /^STIDMATCH\/(GT|LT|EQ)$/) {
		## STIDMATCH/GT STIDMATCH/LT STIDMATCH/EQ
		my ($OP) = $1;
		if (not defined $RESULT{'qtymatch'}) { $RESULT{'qtymatch'} = 0; }
		if (($OP eq 'GT') && ($RESULT{'qtymatch'} > $rule->{'MATCHVALUE'})) { $DOACTION = $rule->{'EXEC'}; }
		if (($OP eq 'EQ') && ($RESULT{'qtymatch'} == $rule->{'MATCHVALUE'})) { $DOACTION = $rule->{'EXEC'}; }
		if (($OP eq 'LT') && ($RESULT{'qtymatch'} < $rule->{'MATCHVALUE'})) { $DOACTION = $rule->{'EXEC'}; }
		}
	elsif ($rule->{'MATCH'} =~ /^STIDTOTAL\/(GT|LT|EQ)$/) {
		## STIDMATCH/GT STIDMATCH/LT STIDMATCH/EQ
		my ($OP) = $1;
		if (not defined $RESULT{'totalitem'}) { $RESULT{'totalitem'} = 0; }
		if (($OP eq 'GT') && ($RESULT{'totalitem'} > $rule->{'MATCHVALUE'})) { $DOACTION = $rule->{'EXEC'}; }
		if (($OP eq 'EQ') && ($RESULT{'totalitem'} == $rule->{'MATCHVALUE'})) { $DOACTION = $rule->{'EXEC'}; }
		if (($OP eq 'LT') && ($RESULT{'totalitem'} < $rule->{'MATCHVALUE'})) { $DOACTION = $rule->{'EXEC'}; }
		}
	elsif ($rule->{'MATCH'} eq 'STATE_MATCH') {
		## 7 - Handles STATE matches
		my $STATE = uc($self->in_get('ship/region'));	
		$rule->{'FILTER'} =~ s/[\n\r]+//g;
		$rule->{'FILTER'} = uc($rule->{'FILTER'});
		# print STDERR "STATE:$STATE FILTER:$rule->{'FILTER'}\n";
		# print STDERR "STATE: $STATE -- CART:".$self->cartid()."\n";
		if ($STATE eq '') {
			## don't run when no state is selected.
			}
		elsif (index( ",$rule->{'FILTER'}," , ",$STATE,") > -1) { 
			$DOACTION = $rule->{'EXEC'}; 
			}
		# print STDERR "!!!!!!!!!!!!!!!!!!! STATE_MATCH: $STATE|$rule->{'FILTER'}|$DOACTION\n";
		}
	elsif ($rule->{'MATCH'} eq 'SCHEDULE_MATCH') {
		## 7 - Handles STATE matches
		my $SCHEDULE = uc($self->in_get('our/schedule'));	
		$rule->{'FILTER'} =~ s/[\n\r]+//g;
		# print STDERR "STATE:$STATE FILTER:$rule->{'FILTER'}\n";
		if (index( ','.uc($rule->{'FILTER'}).',' , ','.$SCHEDULE.',') > -1) { 
			$DOACTION = $rule->{'EXEC'}; 
			}
		}
#	elsif ($rule->{'MATCH'} eq 'PROFILE/EQ') {
#		## 7 - Handles STATE matches
#		my $STATE = $self->fetch_property('');	
#		$rule->{'FILTER'} =~ s/[\n\r]+//g;
#		# print STDERR "STATE:$STATE FILTER:$rule->{'FILTER'}\n";
#		if (index( ','.uc($rule->{'FILTER'}).',' , ','.$STATE.',') > -1) { 
#			$DOACTION = $rule->{'EXEC'}; 
#			}
#		}
	elsif ($rule->{'MATCH'} eq 'COUNTRY_MATCH') {
		# $rule->{'PROCESS'} == 8) {
		## 8 - Handles COUNTRY matches
		my $COUNTRYCODE = uc($self->in_get('ship/countrycode'));	
		if ((not defined $COUNTRYCODE) || ($COUNTRYCODE eq '')) { $COUNTRYCODE = 'US'; }
		my $info = ZSHIP::resolve_country('ISO'=>$COUNTRYCODE);
		my $COUNTRY = $info->{'ZOOVY'};
		if ($COUNTRY eq '') { $COUNTRY = 'United States'; }

		$rule->{'FILTER'} =~ s/[\n\r]+//g;
		if ($rule->{'FILTER'} eq '') {
			$self->is_debug() && $LM->pooshmsg("WARN|+COUNTRY_MATCH rules has blank filter");
			}
		else {
			$COUNTRY =~ s/[ ,]/_/g;
			if (index(','.uc($rule->{'FILTER'}).',',','.uc($COUNTRY).',') > -1) { 
				$DOACTION = $rule->{'EXEC'};
				}
			}
		# print STDERR "COUNTRY: $COUNTRY  $rule->{'FILTER'}\n";
		}
#	elsif ($rule->{'MATCH'} eq 'SUBTOTAL/GT') {
#		# 53 = total price is greater than match value
#		# rulematch with process 1 returns how many skumatches, and qty matches.
#		my ($subtotal, $totalweight, $totaltax, $totaltaxable, $itemcount) = $STUFF->totals(0,1);
#		if ($subtotal > $rule->{'MATCHVALUE'}) { $DOACTION = $rule->{'EXEC'}; }					
#		}
#	elsif ($rule->{'MATCH'} eq 'SUBTOTAL/LT') {
#		# 54 = total price is less than match value
#		# rulematch with process 1 returns how many skumatches, and qty matches.
#		my ($subtotal, $totalweight, $totaltax, $totaltaxable, $itemcount) = $STUFF->totals(0,1);
#		if ($subtotal < $rule->{'MATCHVALUE'}) { $DOACTION = $rule->{'EXEC'}; }
#		}
	elsif (($rule->{'MATCH'} eq 'DATE/GT') || ($rule->{'MATCH'} eq 'DATE/LT')) {
		# 61 = date is past match value
		# 60 = date is before match value

		## this is a little confusing, because SHIPPING_RULES use date in FILTER, but PROMOTION rules use
		##	date in MATCHVALUE (ugh)
		my $mv = $rule->{'MATCHVALUE'};
		if ($mv eq '') { $mv = $rule->{'FILTER'}; }
		if (not defined $mv) { $mv = $rule->{'FILTER'}; }
		$mv =~ s/[^\d]+//g; # strip all non-numeric characters
		if (length($mv) == 14) {
			# print STDERR "apply DATE/GT: $rule->{'MATCHVALUE'}\n";
			require Date::Manip;
			my $secs=&Date::Manip::Date_SecsSince1970GMT(
				substr($mv,  4, 2),
				substr($mv,  6, 2),
				substr($mv,  0, 4),
				substr($mv,  8, 2),
				substr($mv, 10, 2),
				substr($mv, 12, 2),
			);
			my $now = time();
			if ($rule->{'MATCH'} eq 'DATE/LT') {
				if ($secs < $now) { $DOACTION = $rule->{'EXEC'}; }
				}
			elsif ($rule->{'MATCH'} eq 'DATE/GT') {
				if ($secs > $now) { $DOACTION = $rule->{'EXEC'}; }
				}
			else {
				$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 128 Rule[$rule->{'.line'}] MATCH=$rule->{'MATCH'} IS INVALID **INTERNAL ERROR**");		
				}
			$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 64 Rule[$rule->{'.line'}] TESTING IS ruleseconds=$secs $rule->{'MATCH'} now=$now (if it is we'd $rule->{'EXEC'})");		
			}
		else {
			$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 64 Rule[$rule->{'.line'}] ERROR Length of date in FILTER/MATCHVALUE must be 14 characters");
			}
		}
	elsif ($rule->{'MATCH'} eq 'COUPON/ANY') {
		## 
		my $couponar = $self->coupons();
		if (scalar($couponar)>0) {
			$rule->{'FILTER'} =~ s/[\n\r]//g;
			my $re = ZSHIP::RULES::filter_to_regex2($rule->{'FILTER'});
			my $match = 0;
			my $count = 0;
			foreach my $cpnref (@{$couponar}) {
				my ($couponid) = $cpnref->{'id'};
				if ($couponid =~ /$re/) { $match++; }
				$count++;
				}
			if ($match) { $DOACTION = $rule->{'EXEC'}; }
			}
		}
	elsif ($rule->{'MATCH'} eq 'TRUE') {
		## this is always true
		$DOACTION = $rule->{'EXEC'};
		}
	elsif ($rule->{'MATCH'} eq 'HAS_CLAIM') {
		# 70 = at least one external item exists
		$DOACTION = undef;
		foreach my $item (@{$STUFF2->items()}) {
			if (index($item->{'stid'}, '*') > 0) { $DOACTION = $rule->{'EXEC'}; }
			elsif ($item->{'claim'}>0) { $DOACTION = $rule->{'EXEC'}; }
			}
		}
	#elsif ($rule->{'MATCH'} eq 'HAS_EBATES') {
	#	# 70 = at least one external item exists
	#	$DOACTION = undef;
	#	if ($self->'ebates_ebs') ne '') {
	#		$DOACTION = $rule->{'EXEC'};
	#		}
	#	}
	elsif ($rule->{'MATCH'} eq 'FILTER_IS_SUBSTRING') {
		# 80 = the filter appears in the substring
		$DOACTION = undef;
		if ($RESULT{'matches'}>0) { $DOACTION = $rule->{'EXEC'}; }
		}
	elsif ($rule->{'MATCH'} =~ /^META\/(EXACT|FUZZY)$/) {
		# META/FUZZY META/EXACT
		$DOACTION = undef;
		my $submatch = $1;
		my ($meta) = uc($self->in_get('cart/refer'));
		if ($submatch eq 'EXACT') {
			## EXACT uses MATCHVALUE
			if ($meta eq uc($rule->{'MATCHVALUE'})) { $DOACTION = $rule->{'EXEC'}; }
			}
		elsif ($submatch eq 'FUZZY') {
			## FUZZY MATCH - split on lines, PIPES, or COMMAS, the FILTER should appear as a substring of the META
			foreach my $term (split(/[\n\r\,\|]+/,$rule->{'FILTER'})) {
				$term =~ s/[\s]+//g;
				$term = uc($term);
				if (index($meta,$term)>=0) { 
					$DOACTION = $rule->{'EXEC'}; 
					$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 64 Rule[$rule->{'.line'}] FOUND \"$term\" in \"$meta\"\n"); 
					}
				else {
					$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 64 Rule[$rule->{'.line'}] MISSED \"$term\" in \"$meta\"\n"); 
					}
				}
			}
		else {
			$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 2 Rule[$rule->{'.line'}] UNKNOWN SUBMATCH TYPE: $submatch\n");
			}
		}
	elsif ($rule->{'MATCH'} =~ /^META\/(EXACT|FUZZY)$/) {
		$DOACTION = undef;
		my $submatch = $1;
		my ($meta) = uc($self->in_get('cart/refer'));
		$skumatch = 0; $qtymatch = 0; 
		if ($submatch eq 'EXACT') {
			## EXACT uses MATCHVALUE
			if ($meta eq $rule->{'MATCHVALUE'}) { 
				$DOACTION = $rule->{'EXEC'}; 
				$skumatch = 1; $qtymatch = 1; 
				}
			}
		elsif ($submatch eq 'FUZZY') {
			## FUZZY MATCH - split on lines, PIPES, or COMMAS, the FILTER should appear as a substring of the META
			foreach my $term (split(/[\n\r\,\|]+/,$rule->{'FILTER'})) {
				$term =~ s/[\s]+//g;
				$term = uc($term);
				if (index($meta,$term)>=0) { 
					$DOACTION = $rule->{'EXEC'}; 
					$skumatch = 1; $qtymatch = 1; 
					$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 64 Rule[$rule->{'.line'}] FOUND \"$term\" in \"$meta\"\n");
					}
				else {
					$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 64 Rule[$rule->{'.line'}] MISSED \"$term\" in \"$meta\"\n"); 
					}
				}
			}
		else {
			$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 2 Rule[$rule->{'.line'}] UNKNOWN SUBMATCH TYPE: $submatch\n"); 
			}
		}
	elsif ($rule->{'MATCH'} =~ /^MULTIVARSITE\/(A|B)$/) {
		## SITE-A/SITE-B
		$DOACTION = undef;
		my ($AB) = $1;
		my ($cartside) = $self->in_get('cart/multivarsite');				
		if ($AB eq $cartside) { 
			$DOACTION = $rule->{'EXEC'}; 
			$skumatch = 1; $qtymatch = 1;
			}
		}
	elsif ($rule->{'MATCH'} eq 'SOME_IN_FILTER') {
		($skumatch,$qtymatch) = (0,0);
		if ($RESULT{'matches'} > 0) { 
			($skumatch,$qtymatch) = ($RESULT{'matches'}, $RESULT{'qtymatch'});
			}
		}
	elsif (($rule->{'MATCH'} eq 'ALL_IN_FILTER') || ($rule->{'MATCH'} eq 'ALL_NOT_PRESENT')) {
		($skumatch,$qtymatch) = (0,0);
		if ($RESULT{'matches'} == $STUFF2->count('show'=>'real')) {
			($skumatch,$qtymatch) = ($RESULT{'matches'}, $RESULT{'qtymatch'});
			}			
		# ($skumatch,$qtymatch) = &rulematch_cart($rule,2,$self);
		}
	elsif ($rule->{'MATCH'} eq 'TWO_IN_FILTER') {
		if ($RESULT{'qtymatch'} >= 2) { 
			($skumatch,$qtymatch) = ($RESULT{'matches'}, $RESULT{'qtymatch'});
			}
		# ($skumatch,$qtymatch) = &rulematch_cart($rule,3,$self);
		}
#	elsif ($rule->{'MATCH'} eq 'NOTHING_IN_FILTER') {
#		if ($RESULT{'matches'} == 0) { 
#			($skumatch,$qtymatch) = (1, $RESULT{'qtymatch'});
#			}
#		# ($skumatch,$qtymatch) = &rulematch_cart($rule,4,$self);
#		}
	elsif ($rule->{'MATCH'} eq 'CRAZY_FILTER') {
		# 2 = all products in filter MUST match
		my $sane = 1;
		## note @FILTER is set by the &rulematch_cart
		foreach my $element (split(/\|/, $RESULT{'@FILTER'})) {
			## Now verify the filter string contains one of each of the elements.
			if ($RESULT{'skus'} !~ /,$element,/i) { 
				$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 64 SKU[$RESULT{'skus'}] was not in /,$element,/ -- will not continue"); 
				$sane=0; 
				}
			}
		if ($DEBUG) { 
			if (($sane==0) && ($RESULT{'@FILTER'} =~ /\*/)) {
				$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 64 **CRAZY_FILTER WARNING** method all items in cart logic is not compatible with wildcard characters, you must hardcode skus implicitly.");
				}
			use Data::Dumper; 
			$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+promo 128 CRAZY_FILTER CONTINUE[$sane] on result: ".Dumper(\%RESULT)); 
			}
		if ($sane) { 
			$DOACTION = $rule->{'EXEC'}; 
			($skumatch,$qtymatch) = (1, 0);
			}
		}
	#elsif ($rule->{'MATCH'} eq 'CRAZY_FILTER') {
	#	# ($skumatch,$qtymatch) = &rulematch_cart($rule,5,$self);
	#	($skumatch,$qtymatch) = (1, 0);
	#	foreach my $element (split(/\|/, $rule->{'FILTER'})) {
	#		## Now verify the filter string contains one of each of the elements.
	#		if ($RESULT{'skus'} !~ /,$element,/i) { ($skumatch,$qtymatch) = (0, 0); }
	#		}
	#	}
	elsif ($rule->{'MATCH'} eq 'THREE_IN_FILTER') {
		# ($skumatch,$qtymatch) = &rulematch_cart($rule,6,$self);
		if ($RESULT{'qtymatch'} >= 3) { 
			($skumatch,$qtymatch) = ($RESULT{'matches'}, $RESULT{'qtymatch'}); 
			}
		}
	elsif ($rule->{'MATCH'} eq 'STATE_MATCH') {
		# $rule->{'PROCESS'} == 7) {
		## 7 - Handles STATE matches
		my $STATE = uc($self->in_get('ship/region'));	
		$rule->{'FILTER'} =~ s/[\n\r]+//g;
		if (index( ','.uc($rule->{'FILTER'}).',' , ','.$STATE.',') > -1) { 
			$skumatch = 1; $qtymatch = 1; 
			} 
		else { 
			$skumatch = 0; $qtymatch = 0; 
			}

		print STDERR "SKU MATCH: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!skumatch:$skumatch qtymatch:$qtymatch\n";
		}
	#elsif ($rule->{'MATCH'} eq 'COUNTRY_MATCH') {
	#	# $rule->{'PROCESS'} == 8) {
	#	## 8 - Handles COUNTRY matches
	#	my $COUNTRYCODE = $self->in_get('ship/countrycode');	
	#	#if (not defined $COUNTRY) { $COUNTRY = 'USA'; }
	#	#elsif ($COUNTRY eq '') { $COUNTRY = 'USA'; }
	#	my $info = 
	#	my ($COUNTRY) = 
	#	$rule->{'FILTER'} =~ s/[\n\r]+//g;
	#	$COUNTRY =~ s/[ ,]/_/g;
	#	if (index(','.uc($rule->{'FILTER'}).',',','.uc($COUNTRY).',') > -1) { $skumatch = 1; $qtymatch = 1; } else { $skumatch = 0; $qtymatch = 0; }
	#	# print STDERR "COUNTRY: $COUNTRY  $rule->{'FILTER'}\n";
	#	}
	elsif ($rule->{'MATCH'} eq 'COUNTRYCODE_MATCH') {
		# ($rule->{'PROCESS'} == 18) {
		## 18 - Handles COUNTRY CODE matches
		my $COUNTRYCODE = uc($self->in_get('ship/countrycode'));	
		#if (not defined $COUNTRY) { $COUNTRY = 'USA'; }
		#elsif ($COUNTRY eq '') { $COUNTRY = 'USA'; }
		# my $ref = &ZSHIP::resolve_country(ZOOVY=>$COUNTRY);
		my $ref = &ZSHIP::resolve_country('ISO'=>$COUNTRYCODE);
		$rule->{'FILTER'} =~ s/[\n\r]+/,/g;
		my $ISOX = (defined $ref)?$ref->{'ISOX'}:'';
		$ISOX =~ s/[^A-Z\,]//g;
		if (index(','.uc($rule->{'FILTER'}).',',','.uc($ISOX).',') > -1) { 
			$skumatch = 1; $qtymatch = 1; 
			$DOACTION = $rule->{'EXEC'};
			} 
		# print STDERR "ISOX: $ISOX  $rule->{'FILTER'}\n";
		}
	elsif ($rule->{'MATCH'} eq 'IPADDR_MATCH') {
		# ($rule->{'PROCESS'} == 9) {
		## 9 - good guess?
		$rule->{'FILTER'} =~ s/[\n\r]+//g;
		$rule->{'FILTER'} = &ZSHIP::RULES::filter_to_regex($rule->{'FILTER'});
		($skumatch,$qtymatch) = (0,0);
		if ($ENV{'REMOTE_ADDR'} =~ /$rule->{'FILTER'}/) {
			($skumatch,$qtymatch) = (1,1);
			}
		}
	elsif ($rule->{'MATCH'} eq 'IS_POBOX') {
		# ($rule->{'PROCESS'} == 10) {
		## 10 - Matches PO Boxes.
		my $IS_POBOX = $self->is_pobox();
		if ($IS_POBOX>0) {
			$skumatch=1; $qtymatch=1;
			}
		}
	elsif ($rule->{'MATCH'} eq 'HAS_DOM_ADDRESS') {
		if ($self->in_get('ship/postal')>0) {
			$skumatch=1; $qtymatch=1;
			}
		}
	elsif (($rule->{'MATCH'} eq 'WEIGHT/LT') || ($rule->{'MATCH'} eq 'WEIGHT/GT')) {
		# ($rule->{'PROCESS'} == 100 || $rule->{'PROCESS'} == 101) {
		## 100 - Weight of cart is greater than filter criteria (filter critera must be a valid weight)
		## 101 - Weight of cart is less than filter criteria (filter critera must be a valid weight)
		my ($result) = $STUFF2->sum({'show'=>'real+nogift'});
		my $WEIGHT = $result->{'pkg_weight'};  
		if ((not defined $WEIGHT) || ($WEIGHT == 0)) {
			$WEIGHT = $self->in_get('sum/pkg_weight');	
			}
		my $TOTALWEIGHT = $WEIGHT;
		require ZSHIP;
		my $filterweight = &ZSHIP::smart_weight($rule->{'FILTER'});		
		# load the variables that we'll be using 
		$skumatch = 0; $qtymatch = 0;

		#if (($rule->{'PROCESS'} == 100) && ($TOTALWEIGHT > $filterweight)) { $skumatch = 1; $qtymatch = 1; }
		#elsif (($rule->{'PROCESS'} == 101) && ($TOTALWEIGHT < $filterweight)) { $skumatch = 1; $qtymatch = 1; }
		if (($rule->{'MATCH'} eq 'WEIGHT/GT') && ($TOTALWEIGHT > $filterweight)) { $skumatch = 1; $qtymatch = 1; }
		elsif (($rule->{'MATCH'} eq 'WEIGHT/LT') && ($TOTALWEIGHT < $filterweight)) { $skumatch = 1; $qtymatch = 1; }

		$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+RULES DEBUG PROCESS 100 - TOTALWEIGHT=[$TOTALWEIGHT]");
		}
	elsif (
		($rule->{'MATCH'} eq 'SUBTOTAL/GT') || ($rule->{'MATCH'} eq 'SUBTOTAL/LT') ||
		($rule->{'MATCH'} eq 'TRUE_SUBTOTAL/GT') || ($rule->{'MATCH'} eq 'TRUE_SUBTOTAL/LT')
		) {

		
		# my ($SUBTOTAL, $totalweight, $totaltax, $totaltaxable, $itemcount) = $STUFF2->totals(0,$SKIP_PROMOTIONS);
		my $SHOW = (($rule->{'MATCH'} =~ /TRUE_SUBTOTAL/)?'':'real+nogift');
		my ($result) = $STUFF2->sum({'show'=>$SHOW});
		my ($SUBTOTAL) = $result->{'items_total'};

		if ($self->is_debug()) { 
			if ($self->__GET__('sum/items_total') != $SUBTOTAL) {
				$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+NOTE - SHOWING=$SHOW TOTALPRICE=[$SUBTOTAL]"); 
				}
			}
		
		
		# my $SUBTOTAL = $self->in_get('data.order_subtotal');	
		# ($rule->{'PROCESS'} == 102 || $rule->{'PROCESS'} == 103) {
		## 102 - Subtotal of cart is greater than filter criteria (filter critera must be a number of dollars)
		## 103 - Subtotal of cart is less than filter criteria (filter critera must be a number of dollars)


		my $VALUE = $rule->{'MATCHVALUE'};
		## NOTE: when shipping rules and promotion rules were merged one used filter criteria, one used match value.
		if ($VALUE eq '') { $VALUE = $rule->{'FILTER'}; }

		$VALUE =~ s/[^0123456789\.]//gs;
		if ($VALUE eq '') { $VALUE = 0; }
		
		$skumatch = 0; $qtymatch = 0;
		my ($M,$OP) = split('/',$rule->{'MATCH'},2);
		if ($OP eq 'GT') {
			if ($VALUE < $SUBTOTAL) { $qtymatch = 1; $skumatch = 1; }
			}
		elsif ($OP eq 'LT') {
			if ($VALUE > $SUBTOTAL) { $qtymatch = 1; $skumatch = 1; }
			}
		else { 
			$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+UNKNOWN OP[$OP] for MATCH $rule->{'MATCH'}"); 
			}
		}
	#elsif (($rule->{'MATCH'} eq 'DATE/LT') || ($rule->{'MATCH'} eq 'DATE/GT')) {
	#	# $rule->{'PROCESS'} == 60 || $rule->{'PROCESS'} == 61) {
	#	# 60 = date is before match value
	#	# 61 = date is past match value
	#	my $mv = $rule->{'FILTER'};
	#	$mv =~ s/[^\d]+//g; 	# strip all non-numeric characters
	#	($skumatch,$qtymatch) = (0,0);
	#	if (length($mv) == 14) {
	#		# print STDERR "do_ship_rules: $rule->{'FILTER'}\n";
	#		require Date::Manip;
	#		my $secs=&Date::Manip::Date_SecsSince1970GMT(substr($mv,4,2),substr($mv,6,2),substr($mv,0,4),substr($mv,8,2),substr($mv,10,2),substr($mv,12,2));
	#		#if (($rule->{'PROCESS'} == 60) && ($secs > time())) { ($skumatch,$qtymatch) = (1,1); } 
	#		#elsif (($rule->{'PROCESS'} == 61) && ($secs <= time())) { ($skumatch,$qtymatch) = (1,1); } 
	#		if (($rule->{'MATCH'} eq 'DATE/LT') && ($secs > time())) { ($skumatch,$qtymatch) = (1,1); } 
	#		elsif (($rule->{'MATCH'} eq 'DATE/GT') && ($secs <= time())) { ($skumatch,$qtymatch) = (1,1); } 
	#		else {
	#			$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+ship 128 rule[$rule->{'.line'}] DATE DID NOT QUALIFY RULE=$secs CURRENT=".time());				
	#			}
	#		}
	#	else {
	#		$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+ship 128 rule[$rule->{'.line'}] DATE FORMAT ERR - SHOULD BE YYYYMMDDHHMMSS");			
	#		}
	#	}
	elsif (($rule->{'MATCH'} eq 'DAY_OF_WEEK') || ($rule->{'MATCH'} eq 'TIME_PAST')) {
		# $rule->{'PROCESS'} == 62 || $rule->{'PROCESS'} == 63) {
		# 62 = day of week (1 = Monday, 7=Sunday)
		# 63 = after time of day HH:MM
		my $mv = $rule->{'FILTER'};
		($skumatch,$qtymatch) = (0,0);
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
		if ($wday == 0) { $wday = 7; } 
		# if ($rule->{'PROCESS'}==62) {
		if ($rule->{'MATCH'} eq 'DAY_OF_WEEK') {
			## day of week
			$mv =~ s/[^\d,]+//g; 	# strip all non-numeric characters and commas
			foreach my $testdow (split(/\,/,$mv)) {
				if ($testdow == $wday) { $skumatch=1; $qtymatch=1; }
				}
			}
		# elsif ($rule->{'PROCESS'} == 63) {
		elsif ($rule->{'MATCH'} eq 'TIME_PAST') {
			$mv =~ s/[^\d\:]+//g; 	# strip all non-numeric characters and commas
			## HH:MM
			if (length($mv)==5) {
				my ($mvhr,$mvmin) = split(/:/,$mv); 
				if ($hour>$mvhr && $min>$mvmin) { $skumatch=1; $qtymatch=1; }
				}
			}
		}
	elsif ($rule->{'MATCH'} eq 'HAS_CLAIM') {
		# $rule->{'PROCESS'} == 70) {
		# 70 = at least one external item exists
		($skumatch,$qtymatch) = (0,0);
		foreach my $item (@{$STUFF2->items()}) {
			if ($item->{'claim'}>0) { $skumatch++; $qtymatch += $item->{'qty'}; }
			elsif (index($item->{'stid'},'*') > 0) { $skumatch++; $qtymatch += $item->{'qty'}; }
			}
		}
	elsif ($rule->{'MATCH'} eq 'SUBSTRING_MATCH') {
		# ($rule->{'PROCESS'} == 80) {
		# 80 = the filter appears in the substring
		my $filt = &ZSHIP::RULES::filter_to_regex($rule->{'FILTER'});
		foreach my $item (@{$STUFF2->items()}) {
			my $desc = $item->{'description'};
			$desc =~ s/ /_/g;
			if ($desc =~ /$filt/i) { 
				$skumatch++; $qtymatch += $item->{'qty'}; 
				}
			}
		}
	elsif (($rule->{'MATCH'} eq 'SHIPPING/GT') || ($rule->{'MATCH'} eq 'SHIPPING/LT')) {
		## 104,105 shipping greater than or less than amount
		# Sanity, clean up current price
		my $CURRENTPRICE = $params{'CURRENTPRICE'};
		if (not defined $CURRENTPRICE) { warn "CURRENTPRICE not set"; }
		$CURRENTPRICE =~ s/[^0-9|^\.]+//g;

		$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+SHIPPING/XX DEBUG ... MATCH=$rule->{'MATCH'} CURRENT=$CURRENTPRICE FILTER=".sprintf("%.2f",$rule->{'FILTER'})); 
		if (($rule->{'MATCH'} eq 'SHIPPING/GT') && ($CURRENTPRICE>sprintf("%.2f",$rule->{'FILTER'}))) { 
			$DOACTION = $rule->{'EXEC'};
			}
		elsif (($rule->{'MATCH'} eq 'SHIPPING/LT') && ($CURRENTPRICE<sprintf("%.2f",$rule->{'FILTER'}))) { 
			$DOACTION = $rule->{'EXEC'};
			}
		else {
			$DOACTION = undef;
			}
		}
	else {
		($skumatch,$qtymatch) = (0,0);
		$self->is_debug() && $LM->pooshmsg("RULE[$rule->{'.line'}]|+ ****** WARNING ******: unhandled MATCH type ".$rule->{'MATCH'});
		}


	if (defined $DOACTION) { 
		## DOACTION is already set.
		if (not defined $skumatch) { $skumatch++; }
		if (not defined $qtymatch) { $qtymatch++; }
		}
	elsif ((defined $skumatch) && ($skumatch)) { 
		$DOACTION = $rule->{'EXEC'}; 
		}
	$RESULT{'DOACTION'} = $DOACTION;
	if (defined $skumatch) {
		$RESULT{'_skumatch'} = $skumatch;
		}
	if (defined $qtymatch) {
		$RESULT{'_qtymatch'} = $qtymatch;
		}


	return(\%RESULT);
	}



##
## Creates an order event - bitwise value
##		if etype is unset then it should be set to 64
##		1: (on=safe to display to end user, off=merchant only)
##		2: designates it as a payment event
##		4: desginates it as a status change message
##		8: designates it as a priority message (warning/error and/or 
##		16: supply chain and/or shipping messages
##		32: marketplace events
##		64: reserved/other
##		128: debug message
##		256: order manager put this message in.
##
## on params pass:
##		is=>error  or is=>['payment','error']
sub add_history {
	my ($self, $msg, %params) = @_;

	if (not defined $params{'ts'}) { $params{'ts'} = time(); }
	elsif ($params{'ts'} == 0) { $params{'ts'} = time(); }	
	

	my $luser = $params{'luser'};
	my $uuid = $params{'uuid'};

	## p for patti!
	$msg =~ s/[\<\>]+/-/g;

	my $etype = $params{'etype'};
	if (not defined $etype) { $etype = 64; }

	## 'is' param /is/ a handy way to set the type of message.
	my @IS = ();
	if (not defined $params{'is'}) {
		}
	elsif (ref($params{'is'}) eq '') {
		push @IS, $params{'is'};
		}
	elsif (ref($params{'is'}) eq 'ARRAY') {
		foreach my $is (@{$params{'is'}}) { push @IS, $is; }
		}

	foreach my $IS (@IS) {
		if ($IS eq 'error') { $etype |= 8; }
		if ($IS eq 'payment') { $etype |= 2; }
		if ($IS eq 'status') { $etype |= 4; }
		if ($IS eq 'public') { $etype |= 1; }
		if ($IS eq 'private') { $etype &= (0xFF-1); }
		}

	if (not defined $self->{'@HISTORY'}) { $self->{'@HISTORY'} = []; }
	if (not defined $uuid) { $uuid = Data::GUID->new()->as_string(); };

	my $e = { 
		'ts' =>sprintf("%d",$params{'ts'}),
		'content' =>$msg,
		'etype'=>sprintf("%d",$etype),
		'uuid'=>$uuid,
		'luser'=>$luser,
		'app'=>sprintf("%s:%s",&ZOOVY::servername(),&ZOOVY::appname()),
		};

	push @{$self->{'@HISTORY'}}, $e;
	}

## Adds multiple events with the current timestamp
sub add_historys {
	my ($self, @events) = @_;
	my $ts = time();
	foreach (@events) { 
		my ($msg,$status,$luser) = split(/\|/,$_);
		$self->add_history($msg, 'ts'=>$ts,'etype'=>$status,'luser'=>$luser); 
		}
	}

## Gets all order events
sub history {
	my ($self) = @_;
	return $self->{'@HISTORY'};
	}






##
## returns a stat-set for 
##
sub order_kpistats {
	my ($self) = @_;

	require KPIBI;

	my %cart2 = (); 
	tie %cart2, 'CART2', CART2=>$self;  

	my ($ts) = $cart2{'our/order_ts'};
	my @set = ();
	my $stuff2 = $self->stuff2();
	## Overall sales
	push @set, [ '=', 'OGMS', $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];
	$cart2{'flow/flags'} = sprintf("%d",$cart2{'flow/flags'});

	if ($cart2{'flow/flags'} & (1<<1)) {
		## Expedited shipping
		push @set, [ '=', "OEXP", $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];
		}
	if ($cart2{'flow/flags'} & (1<<2)) {
		## repeat sales
		push @set, [ '=', "ORPT", $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];
		}
	if ($cart2{'flow/flags'} & (1<<14)) {
		## repeat sales
		push @set, [ '=', "OGFT", $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];
		}

	if ($cart2{'ship/countrycode'} ne '') {
		## International
		push @set, [ '=', "OINT", $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];
		}
	## Partition
	push @set, [ '=PRT', sprintf("%02X",$self->prt()), $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];
	

	## Sdomain
	if (my $sdomain = $cart2{'our/sdomain'}) {
		push @set, [ '~D', $sdomain, $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];
		}
	## Wholesale Schedule
	if (my $schedule = $cart2{'our/schedule'}) {
		push @set, [ '$W', $schedule, $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];
		}

	## Marketplace
	my $mkts = $cart2{'our/mkts'};
	my $is_web = 1;
	my $affiliate = $cart2{'cart/refer'};
	if ($mkts ne '') {
		my @BITS = @{&ZOOVY::bitstr_bits($mkts)};
		foreach my $bit (@BITS) {
			my $sref = &ZOOVY::fetch_integration('id'=>$bit);

			if ($sref->{'grp'} eq '') {}
			elsif ($sref->{'grp'} ne 'WEB') { $is_web = 0; }

			my $dst = $sref->{'dst'};
			push @set, [ '=', "S$dst", $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];

			## if it's a known destination, then don't track it as an affiliate
			if (not defined $sref->{'meta'}) {}
			elsif ($sref->{'meta'} eq $affiliate) { $affiliate = ''; }
			}
		}

	## affiliate sales
	if ($affiliate) {
		push @set, [ '$A', $affiliate, $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];
		}

	if ($is_web) {
		## website sale (this is kinda tricky to figure out)	
		## a special track for "web" sources
		push @set, [ '=', "OWEB", $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];
		if ($cart2{'cart/multivarsite'} ne '') {
			## track multivarsite A/B/C
			if ($cart2{'cart/multivarsite'} eq 'A') {
				push @set, [ '=PRA', sprintf("%02X",$self->prt()), $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];
				}
			elsif ($cart2{'cart/multivarsite'} eq 'B') {
				push @set, [ '=PRB', sprintf("%02X",$self->prt()), $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];
				}
			elsif ($cart2{'cart/multivarsite'} ne '') {
				push @set, [ '=PRC', sprintf("%02X",$self->prt()), $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];
				}
			}
		}


	#if (my $mkt = $o->legacy_order_get('mkt')) {
	#	push @set, [ '$S', $mkt
	#	}
	foreach my $item (@{$stuff2->items()}) {
		my $stid = $item->{'stid'};
		if ((substr($stid,0,1) eq '%') || ($item->{'is_promo'})) {
			## this is a coupon
			push @set, [ '$C', $stid, $ts, $cart2{'sum/order_total'}, 1, $stuff2->count('real') ];
			}
		if (my $SUPPLIER = $item->{'%attribs'}->{'zoovy:prod_supplier'}) {
			## Supplier
			push @set, [ '~Q', $SUPPLIER, $ts, $item->{'extended'}, 1, $item->{'qty'} ];
			}
		if (my $MFG = $item->{'%attribs'}->{'zoovy:prod_mfg'}) {
			## Manufacturer
			push @set, [ '~M', $MFG, $ts, $item->{'extended'}, 1, $item->{'qty'} ];
			}

		if (not defined $item->{'%attribs'}) {}
		elsif (not defined $item->{'%attribs'}->{'zoovy:prod_is'}) {}
		elsif ((my $prodis = int($item->{'%attribs'}->{'zoovy:prod_is'})) > 0) {
			## PROD_IS fields
			foreach my $ref (@ZOOVY::PROD_IS) {
				if (($prodis & (1<<$ref->{'bit'}))>0) {
					push @set, [ '=PIS', sprintf("%02X",$ref->{'bit'}), $ts, $item->{'extended'}, 1, $item->{'qty'} ];
					}
				}
			}
		}

	untie %cart2;

	return(\@set);
	}


##
## %filter can be 'grp' or 'id' ex: EBA or WEB
##
sub is_origin {
	my ($self,%filter) = @_;
	my $mkts = $self->__GET__('our/mkts');
	my $matches = undef;
	if ($mkts ne '') {
		$matches = 0;
		my @BITS = @{&ZOOVY::bitstr_bits($mkts)};
		foreach my $bit (@BITS) {
			my $sref = &ZOOVY::fetch_integration('id'=>$bit);
			if (defined $filter{$sref->{'grp'}}) { $matches |= 2; }	# matches group
			if (defined $filter{$sref->{'id'}}) { $matches |= 1; }	# matches id
			}
		}	
	if (defined $matches) {
		## mkts wasn't populated (how bizarre) -- so lets use sdomain, if it's not a well known marketplace
		}
	elsif ($self->__GET__('our/sdomain') =~ /^(ebay|amazon|buy|sears|hsn|newegg)\.com$/) {
		## well known marketplaces
		if ($filter{'WEB'}) { return(0); }
		}
	else {
		if ($filter{'WEB'}) { return(2); }
		}

	return($matches);
	}


sub is_shipped {
	my ($self) = @_;
	return( int($self->__GET__('flow/shipped_ts')) );
	}

##
##
##
sub is_paidinfull {
	my ($self) = @_;
	return(	
		(substr($self->__GET__('flow/payment_status'),0,1) eq '0')?1:0 
		);
	}

##
##
##
sub is_payment_success {
	my ($self) = @_;

	my $ps = $self->__GET__('flow/payment_status');
	if (substr($ps,0,1) eq '0') { return($ps); }
	if (substr($ps,0,1) eq '1') { return($ps); }
	if (substr($ps,0,1) eq '4') { return($ps); }
	return(0);
	}



##
## returns a set of formatted variables suitable for interpolation into html or text
##
sub addr_vars {
	my ($self, $type) = @_;

	my %cart2 = (); tie %cart2, 'CART2', 'CART2'=>$self;

	my %vars = ();
	$vars{'%FULLNAME%'} = $cart2{"$type/firstname"}.' '.$cart2{"$type/lastname"};
	$vars{'%COMPANY%'} = '';
	$vars{'%ADDR1%'} = $cart2{"$type/address1"};
	$vars{'%ADDR2%'} = $cart2{"$type/address2"};

	## City, State, Country
	$vars{'%ADDRCSZ%'} = '';


	my $country = $cart2{"$type/country"};
	if (not defined $country) { $country = ''; }
	if ($country eq 'United States') { $country = ''; }
	elsif ($country eq 'US') { $country = ''; }
	elsif ($country eq 'USA') { $country = ''; }
	if ($country eq '') {
		$vars{'%ADDRCSZ%'} = sprintf("%s, %s %s",$cart2{"$type/city"}, $cart2{"$type/region"}, $cart2{"$type/postal"});
		}
	else {
		$vars{'%ADDRCSZ%'} = sprintf("%s, %s",$cart2{"$type/city"},$cart2{"$type/region"});
		if ($cart2{"$type/postal"} ne '') {
			$vars{'%ADDRCSZ%'} .= ' '.$cart2{"$type/postal"};
			}
		$vars{'%ADDRCSZ%'} .= $cart2{"$type/country"}."<br>\n";
		}

	$vars{'%PHONE%'} = '';
	if ($cart2{"$type/phone"} ne '') {
		$vars{'%PHONE%'} = $cart2{"$type/phone"};
		}

	$vars{'%EMAIL%'} = '';
	if ($cart2{"$type/email"} ne '') {
		$vars{'%EMAIL%'} = $cart2{"$type/email"};
		}

	$vars{'%TXT'} = "".
		sprintf("%s\n",$vars{'%FULLNAME%'}).
		(($vars{'%COMPANY%'} ne '')?sprintf("%s\n",$vars{'%COMPANY%'}):"").
		sprintf("%s\n",$vars{'%ADDR1%'}).
		(($vars{'%ADDR2%'} ne '')?sprintf("%s\n",$vars{'%ADDR2%'}):"").
		sprintf("%s\n",$vars{'%ADDRCSZ%'}).
		(($vars{'%PHONE%'} ne '')?sprintf("Ph: %s\n",$vars{'%PHONE%'}):"").
		(($vars{'%EMAIL%'} ne '')?sprintf("Email: %s\n",$vars{'%EMAIL%'}):"").
		"\n";

	$vars{'%HTML'} = "<table class=\"zadminpanel_table ${type}addr\">".
		sprintf("<tr><td class=\"zadminpanel_table_row ${type}_fullname\">%s</td></tr>\n",$vars{'%FULLNAME%'}).
		(($vars{'%COMPANY%'} ne '')?sprintf("<tr><td class=\"zadminpanel_table_row ${type}_company\">%s</td></tr>\n",$vars{'%COMPANY%'}):"").
		sprintf("<tr><td class=\"zadminpanel_table_row ${type}_address\">%s</td></tr>\n",$vars{'%ADDR1%'}).
		(($vars{'%ADDR2%'} ne '')?sprintf("<tr><td class=\"zadminpanel_table_row ${type}_address\">%s</td></tr>\n",$vars{'%ADDR2%'}):"").
		sprintf("<tr><td class=\"zadminpanel_table_row ${type}_address\">%s</td></tr>\n",$vars{'%ADDRCSZ%'}).
		(($vars{'%PHONE%'} ne '')?sprintf("<tr><td class=\"zadminpanel_table_row ${type}_phone\">Ph: %s</td></tr>\n",$vars{'%PHONE%'}):"").
		(($vars{'%EMAIL%'} ne '')?sprintf("<tr><td class=\"zadminpanel_table_row ${type}_email\">Email: %s</td></tr>\n",$vars{'%EMAIL%'}):"").
		"</table>\n";

	untie %cart2;

	return(\%vars); 
	}


##
## there is an issue  when google (with it's numerous async callbacks) processes something out of order
##	 this works with the googlechkout code to ensure we never go backwards on a notification by using the db
##	 id's of the google checkout notifications.
##
sub is_googlecheckout_outoforder {
	my ($self, $GSID) = @_;

	my $last_gsid = $self->__GET__('flow/google_sequenceid');
	if (not $last_gsid) {
		}
	elsif ($last_gsid > $GSID) {
		$self->add_history("Google appears to be processing out of order - discarding GSID:$GSID since we already did:$last_gsid");
		return(1);
		}

	## this is the proper exit (false)
	$self->__SET__('flow/google_sequenceid',$GSID);	
	return(0);
	}

##
## this tests to see what type of fraud screen the client uses.
##
sub fraud_check {
	my ($self,$payrec,$webdbref) = @_;

	my ($gref) = $self->gref();

	if (not defined $gref->{'%kount'}) {
		}
	elsif (ref($gref->{'%kount'}) ne 'HASH') {
		}
	elsif (int($gref->{'%kount'}->{'enable'})>0) {
		require PLUGIN::KOUNT;
		my ($pk) = PLUGIN::KOUNT->new($self->username(),prt=>$self->prt(),webdb=>$self->webdb());
		my ($r) = $pk->doRISRequest($self);
		# AUTO=D&BRND=VISA&GEOX=JP&KAPT=Y&MERC=200090&MODE=Q&NETW=N&ORDR=2010%2d09%2d2640&REAS=SCOR&REGN=JP_17&SCOR=20&SESS=hSxKMI0mOVxKcTSrXktq0Wkm8&TRAN=69HX012LMZN1&VELO=0&VERS=0320&VMAX=0
		my ($zoovyrs) = PLUGIN::KOUNT::RIStoZoovyReviewStatus($r);
		$self->add_history("Kount RIS[$zoovyrs]: ".&ZTOOLKIT::buildparams($r),'etype'=>4,luser=>"*KOUNT");
		$self->__SET__('flow/review_status',$zoovyrs);
		}
	else {
		## no fraud screen service installed.
		}
	return();
	}




sub payment_status { return($_[0]->in_get('flow/payment_status')); }
sub payment_method { return($_[0]->in_get('flow/payment_method')); }
sub pool { return($_[0]->in_get('flow/pool'));  }
sub profile { 
	my ($self) = @_;
	warn "attempted to call profile\n";
	return("INVALID");
	}
#	my $profile = $self->__GET__('our/profile');
#	if ((not defined $profile) || ($profile eq '')) { 
#		$profile = &ZOOVY::prt_to_profile($self->username(),$self->prt()); 
#		$self->__SET__('our/profile',$profile);
#		}
#	return($profile);
#	}



## 
## example input commands:
##
##		SETPOOL?pool=[pool]\n
##		CAPTURE?amount=[amount]\n
##		ADDTRACKING?carrier=[UPS|FDX]&track=[1234]\n
##		EMAIL?msg=[msgname]\n
##		ADDNOTE?note=[note]\n
##		SET?key=value	 (for setting attributes)
## 	SETSHIPADDR? 
#						"ship_company=" + Me.txtShipToCompany.Text + _
#						"&ship_firstname=" + Me.txtShipToFirst.Text + _
#								"&ship_lastname=" + Me.txtShipToLast.Text + _
#								"&ship_phone=" + Me.txtShipToPhone.Text + _
#								"&ship_address1=" + Me.txtShipToAddress1.Text + _
#								"&ship_address2=" + Me.txtShipToAddress2.Text + _
#								"&ship_city=" + Me.txtShipToCity.Text + _
#								"&ship_country=" + Me.txtShipToCountry.Text + _
#								"&ship_email=" + Me.txtShipToEmail.Text + _
#								"&ship_state=" + ShipState + _
#								"&ship_province=" + shipProvince + _
#								"&ship_zip=" + ShipZip + _
#								"&ship_int_zip=" + shipIntZip
##
# EVENTTYPE = "SETBILLADDR"
#						  EVENTPARAMS = "bill_company=" + Me.txtBillToCompany.Text + _
#								"&bill_firstname=" + Me.txtBillToFirst.Text + _
#								"&bill_lastname=" + Me.txtBillToLast.Text + _
#								"&bill_phone=" + Me.txtBillToPhone.Text + _
#								"&bill_address1=" + Me.txtBillToAddress1.Text + _
#								"&bill_address2=" + Me.txtBillToAddress2.Text + _
#								"&bill_city=" + Me.txtBillToCity.Text + _
#								"&bill_country=" + Me.txtBillToCountry.Text + _
#								"&bill_email=" + Me.txtBilltoEmail.Text + _
#								"&bill_state=" + BillState + _
#								"&bill_province=" + BillProvince + _
#								"&bill_zip=" + BillZip + _
#								"&bill_int_zip=" + BillIntZip
#
# SETSHIPPING
# [4:21:14 PM] Becky Horakh says: shp_total=" & String.Format("{0:#######0.00}", CStr(Me.objShip.ZShp_Total)) & _
#						  ", shp_taxable=" & CStr(Me.objShip.ZShp_Tax) & _
#						  ",shp_carrier='" & CStr(Me.objShip.ZShp_Carrier) & "'" & _
#						  ", hnd_total=" & String.Format("{0:#######0.00}", CStr(Me.objShip.Zhnd_Total)) & _
#						  ", hnd_taxable=" & CStr(Me.objShip.Zhnd_Tax) & _
#						  ", ins_total=" & String.Format("{0:#######0.00}", CStr(Me.objShip.Zins_Total)) & _
#						  ", ins_taxable=" & CStr(Me.objShip.Zins_Tax) & _
#						  ", spc_total=" & String.Format("{0:#######0.00}", CStr(Me.objShip.Zspc_Total)) & _
#						  ", spc_taxable=" & CStr(Me.objShip.Zspc_Tax) & _
#
# SETATTRS
#	any attributes 
# SETTAX
#	state_tax_rate local_tax_rate
##
##
##		MULTISET?key=value&key=value&key=value
##
##	NOT IMPLEMENTED (YET):
##		ECHO		(returns a copy of the order in the xml result)
##		STOPIFERROR?id=[#]
##		SETATTRIB?attrib=[attrib]&val=[value]
##		ADDITEM?stid=stid&price=price
##		DELITEM?stid=stid
##
##	Each MACRO command has a reserved field entitled "ID" which is a number
##
##	the response format is:
##		ID#?success=[0|1]&xml=&otherparams=&
##
##
sub run_macro {
	my ($self, $script) = @_;
	## previously this ran a macroscript, it seems like it was a better idea to parse the macroscript earlier and pass
	## in the commands, this gives us insight into the commands *BEFORE* we run them blindly, and this is useful if 
	## (for example) we need to create an order.
	my $CMDS = &CART2::parse_macro_script($script);
	return($self->run_macro_cmds($CMDS));
	}


##
## cmds is a parsed arrayref of cmds, one per line
##		[CMD,hashref_of_parameters]
##
##	$params{'is_buyer'} = 0;
##
sub run_macro_cmds {
	my ($self, $CMDS, %params) = @_;

	my $R = $params{'%R'} || {};
	$R->{'errors'} = 0;

	my $errs = 0;
	my $lm = $params{'*LM'};
	if (not defined $lm) { $lm = LISTING::MSGS->new(); }

	my ($INV2) = undef;

	my ($echo) = 0;
	my @RESULTS = ();
	foreach my $CMDSET (@{$CMDS}) {
		my ($cmd,$pref) = @{$CMDSET};
		my $result = undef;
		$self->sync_action("MACRO/$cmd");

		if ($cmd eq 'SETPOOL') {
			($result) =	$self->__SET__('flow/pool',$pref->{'pool'});
			if (defined $pref->{'subpool'}) { $self->__SET__('flow/subpool',$pref->{'subpool'}); }
			$self->add_history("run_macro set pool to $pref->{'pool'} subpool=$pref->{'subpool'}",ts=>$pref->{'ts'},etype=>4,luser=>$pref->{'luser'});
			if ($pref->{'pool'} eq 'DELETED') {
				$self->cancelOrder(LUSER=>$pref->{'luser'});
				}
			}
		elsif ($cmd eq 'SET') {
			foreach my $key (keys %{$pref}) {
				my ($val) = $pref->{$key};
				$self->legacy_order_set($key,$val);
				$self->add_history("run_macro set $key to $val",ts=>$pref->{'ts'},etype=>4,luser=>$pref->{'luser'});
				}
			}
		elsif ($cmd eq 'CAPTURE') {
			## this will go through and settle any outstanding payments
			foreach my $payrec (@{$self->payments('can_capture'=>1)}) {
				$self->add_history("runmacro capture uuid=$payrec->{'uuid'} ps=$payrec->{'ps'}",etype=>2,luser=>'*MACRO');			
				($payrec) = $self->process_payment('CAPTURE',$payrec);
				}
			}
		elsif ($cmd eq 'ADDTRACKING') {
			if ((not defined $pref->{'track'}) && (defined $pref->{'value'})) { 
				$pref->{'track'} = $pref->{'value'};	## admin app uses 'value' instead of 'track'
				}
			$self->set_tracking($pref->{'carrier'},$pref->{'track'},$pref->{'notes'},$pref->{'cost'},$pref->{'actualwt'});
			$self->add_history(
				"runmacro set tracking $pref->{'carrier'},$pref->{'track'}",
				'ts'=>$pref->{'created_ts'},'etype'=>2,'luser'=>$pref->{'luser'});			
			}
		elsif ($cmd eq 'ADDEVENT') {
			$self->add_history($pref->{'msg'},
				'ts'=>$pref->{'ts'},
				'etype'=>$pref->{'etype'},
				'luser'=>$pref->{'luser'},
				'uuid'=>$pref->{'uuid'}
				);
			}
#		elsif ($cmd eq 'LINK-CUSTOMER-ID') {
#			$self->in_set('customer/cid',$pref->{'CID'});
#			$lm->pooshmsg("SUCCESS|+Linked customer $pref->{'CID'}");
#			}
		elsif ($cmd eq 'SETTRACKING') {
			## this is a more direct call than ADDTRACKING and (in the future) can also update 
			##		based on the "track" field.
			$self->set_trackref($pref);
			}
		elsif ($cmd eq 'CREATECUSTOMER') {
			$self->add_history("runmacro created customer",'etype'=>2);
			require CUSTOMER;
			my ($C) = CUSTOMER->new($self->username(),
				PRT=>$self->prt(),
				EMAIL=>$self->__GET__('bill/email'),
				ORDER=>$self,
				CREATE=>3,
				);
			}
		elsif ($cmd =~ /^ITEM-UUID-(DONE|SPLIT|PAID|ROUTE|RESET)$/) {
			## ITEM-ROUTE  ITEM-UUID-ROUTE
			my ($CMD) = $1;
			if (not defined $INV2) { $INV2 = INVENTORY2->new($self->username(),$pref->{'luser'}); }
			my ($UUID) = $pref->{'UUID'};
			$INV2->orderinvcmd($self,$UUID,"ITEM-$CMD", %{$pref});
			if ($CMD eq 'ROUTE') {
				my $ROUTEDEST = &ZTOOLKIT::buildparams($pref);
				if ($pref->{'ROUTE'} eq 'WMS') { $ROUTEDEST = $pref->{'WMS_GEO'}; }
				elsif ($pref->{'ROUTE'} eq 'SIMPLE') {  $ROUTEDEST = ''; }
				elsif ($pref->{'ROUTE'} eq 'SUPPLIER') { $ROUTEDEST = $pref->{'SUPPLIER_ID'}; }
				$self->add_history(sprintf("SKU:%s (uuid:$UUID) was ROUTE to %s %s",$pref->{'SKU'},$pref->{'ROUTE'},$ROUTEDEST),luser=>$pref->{'luser'});
				}
			else {
				$self->add_history(sprintf("item-uuid:$UUID was %s",$CMD),luser=>$pref->{'luser'});
				}
			}
		elsif ($cmd eq 'SPLITORDER') {
			}
		elsif ($cmd eq 'MERGEORDER') {
			my ($oid) = $pref->{'oid'};
			my ($osrc) = CART2->new_from_oid($self->username(),$oid);
			## phase1: copy any tracking, payments, events, and items into the new order.
			foreach my $e (@{$osrc->history()}) {
				push @{$self->{'@HISTORY'}}, $e;
				}
			foreach my $p (@{$osrc->payments()}) {
				## change the UUID to make sure it's unique
				push @{$self->{'@PAYMENTS'}}, $p;
				}
			$osrc->add_payment('ADJUST',
				sprintf("%.2f", 0 - $osrc->__GET__('sum/balance_paid_total')),
				note=>sprintf("Payments transferred to oid:%s",$self->oid()),
				uuid=>$self->oid(),
				);

			foreach my $t (@{$osrc->tracking()}) {
				push @{$self->{'@SHIPMENTS'}}, $t;
				}
			my @stids = $osrc->stuff2()->stids();
			foreach my $item (@{$osrc->stuff2()->items()}) {
				my $stid = $item->{'stid'};
				if (my $existitem = $self->stuff2()->item($stid)) {
					$self->add_history("item:$stid qty: $existitem->{'qty'} +$item->{'qty'} during merge oid:$pref->{'oid'}");
					$existitem->{'qty'} += $item->{'qty'};
					}
				else {
					## new item - add it
					# $self->stuff()->recram($item);
					$self->stuff2()->fast_copy_cram($item);
					}
				}
			$osrc->order_save();
			}
		elsif ($cmd eq 'EMAIL') {
			## $pref->{'msg'} =~ s/^MAIL\|//gs;	 # strip MAIL| from msg
			## $self->email($pref->{'msg'});
			#my ($SITE) = $params{'*SITE'};
			#if (not defined $SITE) {
			#	($SITE) = SITE->new($self->username(),'PRT'=>$self->prt(),'DOMAIN'=>$self->sdomain());
			#	}
			#require SITE::EMAILS;
			#my ($se) = SITE::EMAILS->new($SITE->username(),'*SITE'=>$SITE);
			#my %msgparams = ('CID'=>$self->cid(),'CUSTOMER'=>$self->customer(),'*CART2'=>$self);
			#if ($pref->{'body'}) { $msgparams{'MSGBODY'} = $pref->{'body'}; }
			#if ($pref->{'subject'}) { $msgparams{'MSGSUBJECT'} = $pref->{'subject'}; }
			#$se->sendmail($pref->{'msg'},%msgparams);
			#$se = undef;
			my ($BLAST) = BLAST->new($self->username(),$self->prt());
			my $recipientStr = $pref->{'recipient'};

			my $rcpt = undef;
			if ($recipientStr =~ /\@/) {
				($rcpt) = $BLAST->recipient('EMAIL',$recipientStr,{'%ORDER'=>$self,'%RUPDATES'=>$R});
				}
			else {
				($rcpt) = $BLAST->recipient('CUSTOMER',$self->customer(),{'%ORDER'=>$self,'%CUSTOMER'=>$self->customer(),'%RUPDATES'=>$R});
				}
			if ($pref->{'msg'} eq 'PTELLAF') { $pref->{'msg'} = 'PRODUCT.SHARE'; }
			my ($msg) = $BLAST->msg($pref->{'msg'}, $pref);

			$BLAST->send($rcpt,$msg);
			}
		elsif (($cmd eq 'ADDNOTE') || ($cmd eq 'ADDPUBLICNOTE') || ($cmd eq 'SETPUBLICNOTE')) {
			if (not $pref->{'note'}) {
				$lm->pooshmsg(sprintf("ERROR|+ADDPUBLICNOTE macro requires 'note' parameter"));
				}
			else {
				my $note = '';
				if ($cmd =~ /^ADD/) { $note = $self->__GET__('want/order_notes'); }
				$note .= $pref->{'note'};
				$self->__SET__('want/order_notes',$note);
				$self->add_history("updated public order notes",ts=>$pref->{'ts'},etype=>1+4,luser=>$pref->{'luser'});
				}
			}
		elsif (($cmd eq 'ADDPRIVATE') || ($cmd eq 'ADDPRIVATENOTE') || ($cmd eq 'SETPRIVATENOTE')) {
			if (not $pref->{'note'}) {
				$lm->pooshmsg(sprintf("ERROR|+ADDPRIVATENOTE macro requires 'note' parameter"));
				}
			else {
				my $note = '';
				if ($cmd =~ /^ADD/) { $note = $self->__GET__('flow/private_notes'); }
				$note .= $pref->{'note'};
				$self->__SET__('flow/private_notes',$note);
				$self->add_history("updated private order notes",ts=>$pref->{'ts'},etype=>4,luser=>$pref->{'luser'});
				}
			}
		elsif ($cmd eq 'ADDCUSTOMERNOTE') {
			my ($C) = undef;

			if ($self->__GET__('customer/cid') > 0) {
				$C = $self->customer();
				}

			if (not $pref->{'note'}) {
				$lm->pooshmsg(sprintf("ERROR|+ADDCUSTOMERNOTE macro requires 'note' parameter"));
				}
			elsif (not defined $C) {
				$lm->pooshmsg(sprintf("ERROR|+ADDCUSTOMERNOTE macro could not access customer record."));
				}
			else {
				my ($ID) = $C->save_note($pref->{'luser'},$pref->{'note'});
				if ($ID <= 0) {
					$lm->pooshmsg(sprintf("ERROR|+ADDCUSTOMERNOTE macro could not save note to customer record."));
					}
				}
			print STDERR "CMD: ".Dumper($cmd,$pref,$lm);
			}
		elsif ($cmd eq 'SETBILLADDR') {
			$self->add_history("updated billing address",'ts'=>$pref->{'created_ts'},etype=>1,luser=>$pref->{'luser'});
			if ($::XCOMPAT > 210) {
				foreach my $k ('company','firstname','lastname','phone','address1','address2','city','state','countrycode','email','region','postal') {
					$self->in_set("bill/$k",$pref->{$k});
					}
				}
			else {
				foreach my $k ('bill_company','bill_firstname','bill_lastname','bill_phone','bill_address1','bill_address2','bill_city','bill_state','bill_country','bill_email','bill_state','bill_province','bill_zip','bill_int_zip') {
					$self->legacy_order_set($k,$pref->{$k});
					}
				}
			
			}
		elsif ($cmd eq 'SETSHIPADDR') {
			$self->add_history("updated shipping address",'ts'=>$pref->{'created_ts'},etype=>1,luser=>$pref->{'luser'});
			if ($::XCOMPAT > 210) {
				foreach my $k ('company','firstname','lastname','phone','address1','address2','city','state','countrycode','email','region','postal') {
					$self->in_set("ship/$k",$pref->{$k});
					}
				}
			else {
				foreach my $k ('ship_company','ship_firstname','ship_lastname','ship_phone','ship_address1','ship_address2','ship_city','ship_state','ship_country','ship_email','ship_state','ship_province','ship_zip','ship_int_zip') {
					$self->legacy_order_set($k,$pref->{$k});
					}
				}
			}
		elsif ($cmd eq 'SETSHIPPING') {
			$self->add_history("updated shipping configuration",'ts'=>$pref->{'created_ts'},etype=>1,luser=>$pref->{'luser'});
			## $pref->{"is/origin_staff"} = "admin";

			foreach my $k (%{$pref}) {
				my $fieldref = $CART2::VALID_FIELDS{$k};
				if (not defined $fieldref) {
					}
				elsif ($fieldref->{'group'} eq 'ship') {
					$self->in_set($k,$pref->{$k});
					}
				}
			
			if (not $self->is_order()) {
				my %method = ();
				$method{'is_admin'}++;
				$method{'carrier'} = $pref->{'sum/shp_carrier'};
				$method{'name'} = $pref->{'sum/shp_method'};
				$method{'amount'} = $pref->{'sum/shp_total'};
				$method{'id'} = Digest::MD5::md5_hex(sprintf("%s-%s-%s",$method{'carrier'},$method{'name'},$method{'amount'}));
				push @{$self->{'@shipmethods'}}, \%method;
				$self->in_set('want/shipping_id',$method{'id'});
				};

			open F, ">/tmp/shipping.set";
			print F Dumper($self);
			close F;
			}
		elsif ($cmd eq 'SETATTRS') {
			$self->add_history("updated order properties",'ts'=>$pref->{'created_ts'},'etype'=>1,'luser'=>$pref->{'luser'});
			foreach my $k (keys %{$pref}) {
				next if ($k eq 'luser');  
				next if ($k eq 'created_ts');

				if ($k eq 'flow/BATCHID') { 
					## stupid ZID 2/14/2013 11.204
					$self->in_set('flow/batchid',$pref->{$k});
					}
				elsif ($::XCOMPAT > 210) {
					$self->in_set($k,$pref->{$k});
					}
				else {
					$self->legacy_order_set($k,$pref->{$k});
					}
				}
			}
		elsif ($cmd eq 'SETTAX') {
			# print STDERR Dumper($pref);
			$self->add_history("updated tax geometry",'ts'=>$pref->{'created_ts'},'etype'=>1,'luser'=>$pref->{'luser'});
			if ($::XCOMPAT > 210) {
				my $TAX_CHANGED = 0;
				foreach my $k (keys %{$pref}) {
					my $fieldref = $CART2::VALID_FIELDS{$k};
					if (($k eq 'luser') || ($k eq 'ts')) {
						## nothing to see here, move along.
						}
					elsif (not defined $fieldref) {
						$lm->pooshmsg("ERROR|+SETTAX invalid field: $k");
						}
					elsif ($fieldref->{'group'} eq 'tax') {
						$TAX_CHANGED |= $self->in_set($k,$pref->{$k});
						}
					else {
						$lm->pooshmsg("ERROR|+SETTAX cannot access non-tax field: $k");
						}
					}

				if ($TAX_CHANGED) {
					## so the assumption here is that if TAX_CHANGED (any fields changed) then 
					my $tax_rate = $self->in_get('sum/tax_rate_state')+$self->in_get('sum/tax_rate_zone');
					$self->in_set('our/tax_rate',$tax_rate);
					$self->add_history("combined tax rate is now: $tax_rate",'ts'=>$pref->{'created_ts'},'etype'=>1,'luser'=>$pref->{'luser'});
					}
				}
			else {
				foreach my $k ('state_tax_rate','local_tax_rate') {
					$self->legacy_order_set($k,$pref->{$k});
					}
				}
			}
		elsif ($cmd eq 'SETSTUFFXML') {
			## this will overwrite any items which are already here

			my ($count_before) = $self->stuff2()->count();

			if ($::XCOMPAT < 210) {
				require STUFF;
				my ($stuff,$errors) = STUFF->new($self->username(),'xml'=>$pref->{'xml'},'xmlcompat'=>$::XCOMPAT);
				if (defined $errors) {
					ZOOVY::confess($self->username(),"Unable to parse STUFF sent from ZOM ".Dumper($pref),justkidding=>1);
					}
				else {
					# print STDERR Dumper($pref,$stuff);
					$self->{'*stuff2'} = STUFF2::upgrade_legacy_stuff($stuff);
					}
				}
			else {
				## VERSION 220
				$self->stuff2()->empty();
				require XML::Simple;
				
				#my (@items) = STUFF2->new($self->username());
				#my (@items) = STUFF2->new($self->username())->from_xml($::XCOMPAT);
				
				my ($rs) = XML::Simple::XMLin($pref->{'xml'},'ForceArray'=>1,'KeyAttr'=>'_');
				my @ITEMS = ();
				foreach my $item (@{$rs->{'item'}}) {
					$item->{'src'} = $::XCLIENTCODE;
					$item->{'stid'} = $item->{'id'};
					if (not defined $item->{'uuid'}) { $item->{'uuid'} = $item->{'stid'}; }
					if ($item->{'attribs'}) {
						my %attribs = ();
						$item->{'%attribs'} = \%attribs;
						foreach my $ref (@{$item->{'attribs'}->[0]->{'attrib'}}) {
							$attribs{ $ref->{'id'} } = $ref->{'value'};
							}
						delete $item->{'attribs'};
						}

					if ($item->{'options'}) {
						my %options = ();
						$item->{'%options'} = \%options;
						foreach my $ref (@{$item->{'options'}->[0]->{'option'}}) {
							$options{ $ref->{'id'} } = $ref;
							delete $ref->{'id'};
							}
						delete $item->{'options'};
						}
					push @ITEMS, $item;
					$self->stuff2()->fast_copy_cram($item);
					}

				#open F, ">/tmp/data";
				#use Data::Dumper;
				#print F Dumper($pref->{'xml'},\@ITEMS,$self->stuff2());
				#close F;
				}

			my ($count_after) = $self->stuff2()->count();
			$self->add_history("updated item geometry before=$count_before after=$count_after",
				'ts'=>$pref->{'created_ts'},'etype'=>1,'luser'=>$pref->{'luser'});
			}
		elsif ($cmd eq 'ITEMADDBASIC') {
			my ($item) = $self->stuff2()->basic_cram($pref->{'stid'},$pref->{'qty'},$pref->{'price'},$pref->{'title'},%{$pref});
			push @{$self->{'@CHANGES'}}, [ 'added_item_basic' ];				
			}
		elsif ($cmd eq 'ITEMADDSTRUCTURED') {
			my $uuid = $pref->{'uuid'};
			my $sku = $pref->{'sku'};
			if (not defined $sku) { $sku = $pref->{'product_id'}; }

			my $qty = $pref->{'qty'};
			my ($pid) = &PRODUCT::stid_to_pid($sku);
			my $P = PRODUCT->new($self->username(),$pid);

			my $variations = {};
			if (defined $P) {
				my $suggestions = $P->suggest_variations('stid'=>$sku);
				foreach my $k (sort keys %{$pref}) {
					if (length($k)!=2) {
						## must be a two digit variation group code
						}
					elsif (uc($k) ne $k) {
						## AA != aa
						}
					elsif (substr($pref->{$k},0,1) eq '~') {
						## text option
						push @{$suggestions}, [ $k, '##', substr($pref->{$k},1), 0 ];
						}
					else {
						push @{$suggestions}, [ $k, $pref->{$k}, undef, 0 ];
						}
					}
				$variations = STUFF2::variation_suggestions_to_selections($suggestions);
				}

			my %params = ();
			$params{'*P'} = $P;
			$params{'*LM'} = $lm;
			$params{'notes'} = $pref->{'notes'};
			if ($pref->{'mkt'}) {
				$params{'mkt'} = $pref->{'mkt'};
				$params{'mktid'} = $pref->{'mktid'};
				}
			
			if (defined $pref->{'force_qty'}) { $params{'force_qty'} = $pref->{'force_qty'}; }
			if (defined $pref->{'force_price'}) { $params{'force_price'} = $pref->{'force_price'}; }
			my ($item) = $self->stuff2()->cram($pid,$qty,$variations,%params);

			push @{$self->{'@CHANGES'}}, [ 'added_item_structured' ];				
			}
		elsif ($cmd eq 'ITEMREMOVE') {
			my $matched = undef;
			if ($pref->{'stid'}) {
				($matched) = $self->stuff2()->drop('stid'=>$pref->{'stid'});
				}
			elsif ($pref->{'uuid'}) {
				($matched) = $self->stuff2()->drop('uuid'=>$pref->{'uuid'});
				}
			if (not defined $matched) {
				$lm->pooshmsg("ERROR|+Invalid filter passed to ITEMREMOVE");
				}
			elsif ($matched == 0) {
				$lm->pooshmsg("WARN|+No items matching filter were found");
				}
			else {
				push @{$self->{'@CHANGES'}}, [ 'removed_item' ];				
				}
			}
		elsif ($cmd eq 'ITEMUPDATE') {
			$self->add_history("item(s) updated",ts=>$pref->{'ts'},etype=>4,luser=>$pref->{'luser'});
			my ($item) = $self->stuff2()->item('uuid'=>$pref->{'uuid'});

			if (not defined $item) {
				$lm->pooshmsg("WARN|+No items matching uuid were found");
				}
			else {
				if (defined $pref->{'price'}) {
					$item->{'price'} = $item->{'force_price'} = $pref->{'price'};					
					}
				if (defined $pref->{'qty'}) {
					# $item->{'qty'} = $item->{'force_qty'} = $pref->{'qty'};
					## NOT SURE IF THIS SHOULD USE A FORCE QTY OR NOT.
					my $qty = $pref->{'qty'};
					$self->stuff2()->update_item_quantity('%item',$item,$qty,'force_qty'=>$qty);
					}
				$self->stuff2()->sum();
				push @{$self->{'@CHANGES'}}, [ 'changed_item' ];
				}
			}
		elsif (($cmd eq 'ADDPAYMENT') || ($cmd eq 'ADDPROCESSPAYMENT') || ($cmd eq 'ADDPAIDPAYMENT')) {
			## tender is a valid type of payment as found in @ZPAY::PAY_METHODS ~line 353
			## ex: 'CREDIT'
			## amt is the amount in dollars (this can be set to zero)
			## other fields are those commonly found in a payment as attrib 
			## uuid, ts, note  	are common, the default ps is 500 (but can be set to something else ex: 501)		
			## ADDPROCESSPAYMENT?VERB=INIT&tender=CREDIT&amt=0.20&UUID=&ts=&note=&CC=&CY=&CI=&amt=
			## look in ZPAY line 14 for the various CC,CM etc. fields
			my $VERB = undef;


			if ($cmd eq 'ADDPROCESSPAYMENT') {
				## this allows becky to make one call - for both "adding" and "processing" which is 
				## more convenient for her.
				$VERB = $pref->{'VERB'};
				delete $pref->{'VERB'};
				}

			if	($pref->{'tender'} =~ /^WALLET\:([\d]+)$/) {
				$pref->{'tender'} = "WALLET";
				$pref->{'WI'} = $1;
				$VERB = 'CHARGE';
				if ($cmd eq 'ADDPAYMENT') { $cmd = 'ADDPROCESSPAYMENT'; } 	 ## pre 201312 compat
				}

			## TODO: amt is a required parameter
			## TODO: on "ADDPAYMENT" uuid is a required parameter

			if (($cmd eq 'ADDPAYMENT') || ($cmd eq 'ADDPAIDPAYMENT')) {
				## fix uppercase UUID (fixed in version 12)
				if (defined $pref->{'UUID'}) { $pref->{'uuid'} = $pref->{'UUID'}; delete $pref->{'UUID'}; }
				## 'amount' fixed in version 12 ( but was released to prod )
				if (defined $pref->{'amount'}) { $pref->{'amt'} = $pref->{'amount'}; delete $pref->{'amount'}; }
				}

#			open F, ">>/tmp/dump";
#			print F 'PHASE1: '.Dumper($pref)."\n--------------------\n";
#			close F;

			if (defined $pref->{'ps'}) {
				## we got a payment status
				}
			elsif ($cmd eq 'ADDPAIDPAYMENT') {
				if ($pref->{'tender'} eq 'MO') { $pref->{'ps'} = '065'; }
				if ($pref->{'tender'} eq 'WIRE') { $pref->{'ps'} = '066'; }
				if ($pref->{'tender'} eq 'PO') { $pref->{'ps'} = '067'; }
				if ($pref->{'tender'} eq 'CHECK') { $pref->{'ps'} = '068'; }
				if ($pref->{'tender'} eq 'CASH') { $pref->{'ps'} = '069'; }
				if ($pref->{'tender'} eq 'PICKUP') { $pref->{'ps'} = '094'; }
				if ($pref->{'tender'} eq 'ADJUST') { $pref->{'ps'} = '088'; }
				if (not defined $pref->{'ps'}) { $pref->{'ps'} = '003'; }
				}
			else {
				## try and guess a good payment status
				if ($pref->{'tender'} eq 'MO') { $pref->{'ps'} = '165'; }
				if ($pref->{'tender'} eq 'WIRE') { $pref->{'ps'} = '166'; }
				if ($pref->{'tender'} eq 'PO') { $pref->{'ps'} = '167'; }
				if ($pref->{'tender'} eq 'CHECK') { $pref->{'ps'} = '168'; }
				if ($pref->{'tender'} eq 'CASH') { $pref->{'ps'} = '169'; }
				if ($pref->{'tender'} eq 'PICKUP') { $pref->{'ps'} = '194'; }
				}

			my ($payrec) = $self->add_payment($pref->{'tender'},$pref->{'amt'},%{$pref});
			if ((defined $VERB) && ($VERB ne '')) {
				($payrec) = $self->process_payment($VERB,$payrec,%{$pref});
				}
		
			push @{$self->{'@CHANGES'}}, [ 'add_payment' ];
			}
		elsif ($cmd eq 'PROCESSPAYMENT') {
			## this must be passed a VERB and UUID 
			## VERB=	INIT|AUTHORIZE|CAPTURE|CHARGE|VOID|REFUND
			## UUID =  the uuid of the payment which was added.
			## amt= (and any other %payment variables)
			my $VERB = $pref->{'VERB'};
			my $UUID = $pref->{'uuid'};
			## not sure how many requests have uppercase UUID (none should)
			if ((defined $pref->{'UUID'}) && ($UUID eq '')) { $UUID = $pref->{'UUID'}; }
			
			my ($payrec) = $self->payment_by_uuid($UUID);
			if (defined $payrec) {
				$self->process_payment($VERB,$payrec,%{$pref});
				}
			else {
				$self->add_history(sprintf("runmacro received unknown UUID:%s so process payment could not run",$pref->{'UUID'}));	
				if (defined $lm) {
					$lm->pooshmsg(sprintf("ERROR|+runmacro received unknown UUID:%s so process payment could not run",$pref->{'UUID'}));
					}
				}
			}
		elsif ($cmd eq 'PAYMENTACTION') {
			## a friendlier, less error prone way to update payments than making a raw call to ADDPAYMENT or 
			## PROCESSPAYMENT .. supports many verbs, it is one PAYMENTMODIFY to rule them all.
			my $ACTION = uc($pref->{'ACTION'});
			my $TXNUUID = $pref->{'uuid'};
			my $AMT = $pref->{'amt'};
			my $NOTE = $pref->{'note'};
			my $PS = $pref->{'ps'};
			my $ERROR = undef;

			my $payrec = $self->payment_by_uuid($TXNUUID);
			if (not defined $payrec) {
				$ERROR = "Unable to lookup TXN '$TXNUUID'";
				}
			elsif ($ACTION eq 'MARKETPLACE-VOID') {
				$payrec->{'voided'} = time();
				$payrec->{'note'} = $NOTE;
				my ($newpayrec) = $self->add_payment($payrec->{'tender'},$payrec->{'amt'},'puuid'=>$payrec->{'uuid'},ps=>619,note=>$NOTE,'luser'=>$pref->{'luser'});
				}
			elsif ($ACTION eq 'MARKETPLACE-REFUND') {
				if (not &ZTOOLKIT::isdecnum($AMT)) {
					$ERROR = "Sorry but refund amount: $AMT is not valid";
					}
				elsif ($AMT<=0) {
					$ERROR = "Sorry but refund amount: $AMT must be a positive decimal number.";
					}
				else {
					my ($newpayrec) = $self->add_payment($payrec->{'tender'},$AMT,'puuid'=>$payrec->{'uuid'},ps=>319,note=>$NOTE);
					}
				}
			elsif ($ACTION eq 'RETRY') {
				$self->process_payment('INIT',$payrec,'luser'=>$pref->{'luser'});		
				}
			elsif ($ACTION eq 'CAPTURE') {
				if (not &ZTOOLKIT::isdecnum($AMT)) {
					$ERROR = "Sorry but capture amount: $AMT is not valid";
					}
				elsif ($AMT<=0) {
					$ERROR = "Sorry but capture amount: $AMT must be a positive decimal number.";
					}
				else {
					$self->process_payment('CAPTURE',$payrec,amt=>$AMT,'luser'=>$pref->{'luser'});
					}
				}
			elsif ($ACTION eq 'OVERRIDE') {
				my $wasps = $payrec->{'ps'};
				if ($PS eq '') {
					$ERROR = "You must specify a payment status for transaction #$TXNUUID";
					}
				elsif (not defined $ZPAY::PAYMENT_STATUS{$PS}) {
					$ERROR = "Payment status [$PS] is not a valid payment status.";
					}
				elsif ($wasps ne $PS) {
					## update the payment status
					$payrec->{'ps'} = $PS;
					$payrec->{'note'} = $NOTE;
					$self->add_history("Override payment status to $PS (was: '$wasps') for txn:$TXNUUID",etype=>2+8,luser=>$pref->{'luser'});
					}
				}
			elsif ($ACTION eq 'SET-PAID') {
				if (not &ZTOOLKIT::isdecnum($payrec->{'amt'})) {
					$ERROR = "Sorry but payment amount: $payrec->{'amt'} is not valid";
					}
				elsif ($payrec->{'amt'}<=0) {
					$ERROR = "Sorry but payment amount: $payrec->{'amt'} must be a positive decimal number.";
					}
				else {
					$payrec->{'ps'} = '000';
					$payrec->{'amt'} = $AMT;
					$payrec->{'note'} = $NOTE;
					}
				}
			elsif ($ACTION eq 'ALLOW-PAYMENT') {
				## this converts and old 4xx directly to it's 0xx counterpart, unless it's a 499 then it goes to 199
				if ($payrec->{'ps'} eq '499') {
					$payrec->{'ps'} = 199; 
					}
				else {
					$payrec->{'ps'} = '0'.substr($payrec->{'ps'},-2);
					}
				$payrec->{'note'} = $NOTE;
				$self->add_history("Set $payrec->{'uuid'} as allowed",etype=>2+8);
				}
			elsif ( 
				(($ACTION eq 'REFUND') || ($ACTION eq 'CREDIT')) && 
				($payrec->{'tender'} =~ /^(CASH|CHECK|PO)$/)) {
				if (not &ZTOOLKIT::isdecnum($AMT)) {
					$ERROR = "Sorry but capture amount: $AMT is not valid";
					}
				elsif ($AMT<=0) {
					$ERROR = "Sorry but capture amount: $AMT must be a positive decimal number.";
					}
				elsif ($AMT == $payrec->{'amt'}) { 
					## amount is the same, void the transaction
					$payrec->{'voided'} = time();
					$payrec->{'ps'} = 602; 
					$payrec->{'note'} = $NOTE;
					}
				else {
					## amount differs
					my ($newpayrec) = $self->add_payment($payrec->{'tender'},$AMT,
						'puuid'=>$payrec->{'uuid'},'ps'=>302,'note'=>$NOTE,'luser'=>$pref->{'luser'});
					$newpayrec->{'puuid'} = $payrec->{'uuid'};
					}
				}
			elsif ($ACTION eq 'VOID') {
				$self->process_payment('VOID',$payrec,'note'=>$NOTE,'luser'=>$pref->{'luser'});
				}
			elsif (($ACTION eq 'REFUND') || ($ACTION eq 'CREDIT')) {
				if (not &ZTOOLKIT::isdecnum($AMT)) {
					$ERROR = "Sorry but capture amount: $AMT is not valid";
					}
				elsif ($AMT<=0) {
					$ERROR = "Sorry but capture amount: $AMT must be a positive decimal number.";
					}
				else {
					$self->process_payment('REFUND',$payrec,'amt'=>$AMT,'note'=>$NOTE,'luser'=>$pref->{'luser'});
					# $self->order_save();
					}
				}
			else {
				$ERROR = "UNKNOWN ACTION:$ACTION";
				#  TXN-UUID:$TXNUUID RAW-PAYREC:".Dumper($payrec);
				}

			if (not $ERROR) {
				$self->sync_action('payment',"$ACTION/$TXNUUID");
				$self->order_save();
				}

			if ($ERROR) {
				$lm->pooshmsg("ERROR|+PAYMENTACTION $ERROR");
				}		
			}
		elsif ($cmd eq 'LINK-CUSTOMER-ID') {
			$self->in_set('customer/cid',$pref->{'CID'});
			delete $self->{'*CUSTOMER'};		## remove customer from memory
			my ($C) = $self->customer();
			if (defined $C) {
				$lm->pooshmsg("SUCCESS|+Linked customer $pref->{'CID'}");
				}
			}
		elsif ($cmd eq 'FLAGASPAID') {
			## FLAGORDERASPAID
			my $method = $self->legacy_order_get('payment_method');
			my $PS = $self->legacy_order_get('payment_status');

			if ((substr($PS,0,1) eq '1') || (substr($PS,0,1) eq '4')) {
				foreach my $payrec (@{$self->payments()}) {
					if (
						($payrec->{'ps'} eq '109') ||
						($payrec->{'ps'} eq '189') || ($payrec->{'ps'} eq '199') ||
						($payrec->{'ps'} eq '489') || ($payrec->{'ps'} eq '499')
						) {
						$self->process_payment('CAPTURE',$payrec,{});
						}
					elsif (substr($payrec->{'ps'},0,1) eq '1') {
						if ($payrec->{'tender'} eq 'CASH') { $payrec->{'ps'} = '069';  }
						elsif ($payrec->{'tender'} eq 'CHECK') { $payrec->{'ps'} = '068'; }
						elsif ($payrec->{'tender'} eq 'PO') { $payrec->{'ps'} = '067'; }
						elsif ($payrec->{'tender'} eq 'WIRE') { $payrec->{'ps'} = '066'; }
						elsif ($payrec->{'tender'} eq 'MO') { $payrec->{'ps'} = '065'; }
						else {
							$self->add_history("Non understood pending tender type=$payrec->{'tender'}");				
							if (defined $lm) {
								$lm->pooshmsg(sprintf("ERROR|+Non understood pending tender type=$payrec->{'tender'}"));
								}
							}
						}
					else {
						$self->add_history("Cannot move from pending to paid tender=$payrec->{'tender'} ps=$payrec->{'ps'}");				
						if (defined $lm) {
							$lm->pooshmsg(sprintf("WARNING|+Cannot move from pending to paid tender=$payrec->{'tender'} ps=$payrec->{'ps'}"));
							}
						}
					}
				}
			else {
				$self->add_history("Cannot flag as paid ps=$PS");	
				if (not defined $lm) {
					$lm->pooshmsg(sprintf("ERROR|+Cannot flag as paid ps=$PS"));
					}
				}
			}
		elsif ($cmd eq 'CREATE') {
			## not sure what this is supposed to do.?!
			## NOTE: this blocks an error from appearing in the events.
			}
		elsif ($cmd eq 'SAVE') {
			}
		elsif ($cmd eq 'ECHO') {
			$echo++;
			}
		else {
			$self->add_history("runmacro unknown command [$cmd]",
				'ts'=>$pref->{'created_ts'},'etype'=>8,'luser'=>$pref->{'luser'});	
			$errs++;
			if (defined $lm) {
				$lm->pooshmsg("ERROR|+runmacro unknown command [$cmd]");
				}
			}

		## RESULTS is an array, first element is ID
		##		second element is ?
		if (defined $pref->{'ID'}) {
			push @RESULTS, [ $pref->{'ID'} ];
			}
		}

	if ($self->is_cart()) {
		$self->cart_save();
		}
	else {
		$self->order_save();
		}

	if ($errs) {
		open F, ">>/tmp/macro-debug.txt";
		print F  Dumper($self->username(),$self->oid(),\@{$CMDS});
		close F;
		}

	return($echo);	
	}


##
## converts macro into cmds array.
##	this is designed to be called *outside* the object (that's useful if for example the first command is CREATE)
##
sub parse_macro_script {
	my ($script) = @_;

	#open F, ">/dev/shm/macro-debug.tmp";
	#print F $script;
	#close F;

	my @CMDS = ();
	my $TS = time();
	foreach my $line (split(/[\n\r]+/,$script)) {
		my ($cmd,$uristr) = split(/\?/,$line,2);
		my $pref = &ZTOOLKIT::parseparams($uristr);		
		if (not defined $pref->{'luser'}) { $pref->{'luser'} = '*MACRO'; }
		if (not defined $pref->{'ts'}) { $pref->{'ts'} = $TS; }
		push @CMDS, [ $cmd, $pref ];
		}
	return(\@CMDS);
	}



##
## causes events to be dispatched 
##
sub queue_event {
	my ($self, $eventname, %params) = @_;

#	my $override = $params{'override'};
	$eventname = lc($eventname);
	if (not defined $self->{'@ACTIONS'}) {
		$self->{'@ACTIONS'} = [];
		}
		
	my $found = 0;
	my $has_create = 0;
	foreach my $d (@{$self->{'@ACTIONS'}}) {
		if ($d->[0] eq 'create') { $has_create++; }
		if ($d->[0] eq $eventname) { $found++; }
		}

	my $override = $params{'override'};
	if ($found) {
		if ($override) { $found = 0; }
		}

	my $ts = time();
	
	if ($found) {
		}
	else {
		push @{$self->{'@ACTIONS'}}, [ $eventname, 0, 0 ];
		}

	return(not $found);
	}




##
## lookup by:  erefid
##		PAID_TXN=>
##		EREFID=>
##
# perl -e 'use lib "/backend/lib"; use ORDER; use Data::Dumper; print Dumper(ORDER::lookup("toynk",DST=>"BUY",EREFID=>"58347056"));'
sub lookup {
	my ($USERNAME, %options) = @_;

	require DBINFO;

	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($TB) = &DBINFO::resolve_orders_tb($USERNAME,$MID);

	my $pstmt = "select ORDERID from $TB where MID=$MID /* $USERNAME */ ";
	if (scalar(keys %options)==0) {
		Carp::confess("%options must be populated");
		}

	foreach my $KEY (keys %options) {
		if ($KEY eq 'PAID_TXN') {
			## max length is 12 digits
			$pstmt .= " and PAID_TXN=".$odbh->quote(substr($options{$KEY},0,12));
			}
		elsif (($KEY eq 'EREFID') || ($KEY eq 'ORDER_EREFID')) {
			## maxlength: 24 digits
			$pstmt .= " and ORDER_EREFID=".$odbh->quote(substr($options{$KEY},0,30));
			}
		elsif (($KEY eq 'MKT') || ($KEY eq 'DST')) {
			## maxlength: 24 digits
			my $intref = &ZOOVY::fetch_integration('dst'=>$options{$KEY});
			if (defined $intref) {
				$pstmt .= " and ".&ZOOVY::bitstr_sql('MKT_BITSTR',[$intref->{'id'}]); 
				}
			else {
				$pstmt .= " /* INVALID MKT:$options{$KEY} */ ";
				}
			}
		else {
			## this line should never be reached.
			Carp::confess("Please pass a valid KEY");
			}
		}

	print STDERR $pstmt."\n";
	my ($ORDERID) = $odbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();

	return($ORDERID);
	}




##
## this is the meat and potatoes that does the actual work
##
## VERB:
##		INIT - looks up gateway, does the initial processing of either auth or charge
##		AUTH|AUTHORIZE	- requests an authorization
##		CAPTURE|SETTLE	- requests a capture/settlement (same thing) of a card
##		CHARGE			- does a auth+settle in one step aka INSTANT-CAPTURE
##		VOID
##		CREDIT|REFUND
##		SET	(for tender types CASH|CHECK)
##
sub process_payment {
	my ($self,$VERB,$payrec,%payment) = @_;

	$VERB = uc($VERB);
	if ($VERB eq 'AUTH') { $VERB = 'AUTHORIZE'; }
	if ($VERB eq 'CREDIT') { $VERB = 'REFUND'; }

	## these are the return values
	my ($USERNAME) = $self->username();

	##
	## PHASE 1: decide who the processor is!
	##
	require ZPAY;
	my $webdbref = $payment{'webdb'};
	if (not defined $payment{'webdb'}) { 
		$webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME, $self->prt()); 
		}

	## the luser making the request, if set, we'll update the payment with their LUSER id.
	if ($payment{'luser'}) {
		$payrec->{'luser'} = $payment{'luser'};
		$payment{'LU'} = $payment{'luser'};
		delete $payment{'luser'};
		}
	elsif ($payment{'LU'}) {
		$payrec->{'luser'} = $payment{'LU'};
		}

	my $ERROR = undef;
	if (not defined $payrec->{'tender'}) { 
		$ERROR = "998|Unknown TENDER[$payrec->{'tender'}]";
		}

	my $ZP = undef;
	my $processor = undef;


	## WALLET CODE
	if (defined $ERROR) {
		## ignore wallet code if we already got an error
		}
	elsif (
		($payrec->{'tender'} eq 'WALLET') || 
		(($payrec->{'tender'} eq 'CREDIT') && (int($payment{'WI'})>0)) 
		) {
		## WALLET's for operations AUTHORIZE or CHARGE are converted into a CREDIT
		$payment{'WI'} = int($payment{'WI'});
		if ((not defined $payment{'WI'}) || ($payment{'WI'} == 0)) {
			$ERROR = "998|WALLET must have WI passed as a payment parameter";
			}
		elsif (($VERB ne 'CHARGE') && ($VERB ne 'AUTHORIZE') && ($VERB ne 'INIT')) {
			$ERROR = "998|WALLET may only perform CHARGE or AUTHORIZE";
			}
		if (not $ERROR) {
			my ($C) = $self->customer();
			if ((not defined $C) || (ref($C) ne 'CUSTOMER')) {
				$ERROR = "291|Customer record could not be loaded from order";
				}
			my $wpayref = $C->wallet_retrieve($payment{'WI'});
			if (defined $wpayref) {
				foreach my $k ('CC','YY','MM','WI','ID','TD','TC','TE','##') {	$payment{$k} = $wpayref->{$k}; }
				$C->wallet_update($payment{'WI'},'attempts'=>1);
				## for now, we pass wallet
				$payrec->{'tender'} = 'CREDIT';
				}
			else {
				$ERROR = "291|Customer is not associated with wallet $payment{'ID'}";
				}
			}
		}

	if ($ERROR) {
		}
	elsif ($payrec->{'tender'} eq 'ADJUST') {
		## SUPERVISOR ADJUSTMENT
		$ZP = undef;
		my $USERNAME = $self->username();
		my ($udbh) = &DBINFO::db_user_connect($self->username());

		if (defined $payment{'note'}) {
			$payrec->{'note'} = $payment{'note'};
			}
		if ($VERB eq 'PAIDINFULL') {
			## this will change the AMT to "PAID IN FULL"
			$payrec->{'amt'} = $self->in_get('sum/balance_due_total');
			}

		my ($MID) = $self->mid();
		my $qtORDERID = $udbh->quote($self->oid());
		my $qtTXNID = $udbh->quote($payrec->{'txn'});
		my ($pstmt) = &DBINFO::insert($udbh,'ORDER_PAYMENT_ADJUSTMENTS',{
			'NOTE'=>$payrec->{'note'},
			'AMOUNT'=>$payrec->{'amt'},
			},
				update=>2,sql=>1,
				'key'=>{
				'MID'=>$self->mid(),
				'ORDERID'=>$self->oid(),
				'UUID'=>$payrec->{'uuid'},			
				});
		print STDERR "PSTMT: $pstmt\n";
		$udbh->do($pstmt);
		&DBINFO::db_user_close();
		}
	elsif (
		($payrec->{'tender'} eq 'CHECK') || 
		($payrec->{'tender'} eq 'CASH') || 
		($payrec->{'tender'} eq 'CHKOD') ||
		($payrec->{'tender'} eq 'WIRE')
		) {
		## CASH and CHECK
		if ($VERB eq 'SET') {
			if (defined $payment{'ps'}) {
				$payrec->{'ps'} = $payment{'ps'};
				}
			if (defined $payment{'acct'}) {
				$payrec->{'acct'} = $payment{'acct'};
				}
			if (defined $payment{'note'}) {
				$payrec->{'note'} = $payment{'note'};
				}
			}
		}
	elsif ($payrec->{'tender'} eq 'PAYPAL') {
		}
#	elsif ($payrec->{'tender'} eq 'GOOGLE') { 
#		require ZPAY::GOOGLE;
#		($ZP) = ZPAY::GOOGLE->new($USERNAME,$webdbref);
#		}
	elsif ($payrec->{'tender'} eq 'PAYPALEC') { 
		require ZPAY::PAYPALEC;
		($ZP) = ZPAY::PAYPALEC->new($USERNAME,$webdbref);
		## INIT means we just added the payment method, for EC that means we need to do a DoExpressCheckoutPayment
		if ($VERB eq 'INIT') { 
			if ($webdbref->{'cc_instant_capture'} eq 'ALWAYS') { $VERB = 'CHARGE'; }
			elsif ($webdbref->{'cc_instant_capture'} eq 'NOAUTH_DELAY') { $VERB = 'AUTHORIZE'; }
			elsif ($webdbref->{'cc_instant_capture'} eq 'NEVER') { $VERB = 'AUTHORIZE'; }
			else {
				$ERROR = "998|Unknown webdb:cc_instant_capture setting[$webdbref->{'cc_instant_capture'}]";
				}
			}
		if (substr($payrec->{'acct'},0,1) eq '|') {
			&ZPAY::unpackit($payrec->{'acct'},\%payment);
			}
		}
	elsif ($payrec->{'tender'} eq 'CREDIT') {
		#if ($payrec->{'acct'} eq '') {
		#	$payrec->{'acct'} = sprintf('CC:%s|MM:%s|YY:%s|CV:%s',
		#		);
		#	}


		use Data::Dumper; 
		if ((not defined $payment{'CC'}) && (not defined $payment{'CM'})) {
			## no payments, so we attempt to load from payrec->{'acct'} into payment
			if (substr($payrec->{'acct'},0,1) eq '|') {
				&ZPAY::unpackit($payrec->{'acct'},\%payment);
				}
			}
		# print STDERR Dumper(\%payment);

		if (length($payment{'YY'})==4) {
			## 4 digit credit card year, lets shorten it to two digits
			$payment{'YY'} = substr($payment{'YY'},2,2);
			}

		if (defined $webdbref->{'cc_processor'}) { $processor = $webdbref->{'cc_processor'}; }
		if ($processor eq 'VERISIGN') { $processor = 'PAYFLOW'; }

		if ($processor eq '') {
			$ERROR = '998|No credit card processor was found for this partition.';
			}
		elsif ($VERB eq 'FAKEAUTHORIZE') {
			$ERROR = '998|FAKEAUTHORIZE is not a valid verb at this stage in credit card processing'; 
			}
		elsif ($VERB eq 'INIT') {
			## for INIT we need to determine if we do a CHARGE or AUTHORIZE 
			if ($webdbref->{'cc_instant_capture'} eq 'ALWAYS') { $VERB = 'CHARGE'; }
			elsif ($webdbref->{'cc_instant_capture'} eq 'NEVER') { $VERB = 'AUTHORIZE'; }
			## some manual customers don't have a cc_instant_capture setting
			elsif ($webdbref->{'cc_processor'} eq 'MANUAL') { $VERB = 'AUTHORIZE'; }
			## NOAUTH_DELAY is an obscure Authorize.net setting
			elsif ($webdbref->{'cc_instant_capture'} eq 'NOAUTH_DELAY') { $VERB = 'FAKEAUTHORIZE'; }
			else {
				$ERROR = "998|Unknown webdb:cc_instant_capture setting[$webdbref->{'cc_instant_capture'}]";
				}
			}
		elsif (($VERB eq 'CAPTURE') && ($payrec->{'ps'} eq '109')) {
			## NOAUTH_DELAY
			## ps status 109 is a special auth.net option called "NOAUTH_DELAY" where it store the payment in a wallet
			## then uses ID to load it, but effectively it's a fake AUTH so we need to do a CHARGE (instead of a capture)
			my $acct = &ZPAY::unpackit($payrec->{'acct'});
			$self->add_history("NOAUTH_DELAY VARS: $payrec->{'acct'}",'ts'=>time(),'etype'=>2,'luser'=>$payrec->{'luser'});
			if ($acct->{'WI'}) {
				$self->add_history("NOAUTH_DELAY[PS=109] loading from wallet:$payrec->{'WI'}",'etype'=>2,'luser'=>$payrec->{'luser'});
				my ($C) = $self->customer();
				my $wpayref = undef;
				if ((not defined $C) || (ref($C) ne 'CUSTOMER')) {
					$ERROR = "291|Customer record could not be loaded from order";
					}
				else {
					$wpayref = $C->wallet_retrieve($payment{'WI'});
					}

				if (defined $wpayref) {
					foreach my $k ('CC','YY','MM','WI') { $payment{$k} = $wpayref->{$k};	}
					$C->wallet_update($payment{'WI'},'attempts'=>1);
					}	
				}
			else {
				$self->add_history("WARNING NOAUTH_DELAY[PS=109] did not find wallet 'WI' in payrec acct field falling back to CC vars",'etype'=>2,'luser'=>$payrec->{'luser'});
				foreach my $k ('CC','YY','MM','CV') { $payment{$k} = $acct->{$k}; } 	# copy CC,YY,MM into $payment
				}
			$self->add_history("NOAUTH_DELAY[PS=109] changed VERB=CAPTURE to VERB=CHARGE",'etype'=>2,'luser'=>$payrec->{'luser'});
			$VERB = 'CHARGE';
			}
		}
	elsif ($payrec->{'tender'} eq 'ECHECK') {
		if (defined $webdbref->{'echeck_processor'}) { $processor = $webdbref->{'echeck_processor'}; }
		if ($processor eq 'VERISIGN') { $processor = 'PAYFLOW'; }

		## i do'nt think any echeck providers support anything other than capture.
		if ($VERB eq 'INIT') { $VERB = 'CHARGE'; }

		if ($processor eq '') {
			$ERROR = '998|No eCheck processor was found for this partition.';
			}
		}
	elsif ($payrec->{'tender'} eq 'GIFTCARD') {
		if ($VERB eq 'INIT') { $VERB = 'CHARGE'; }
		elsif ($VERB eq 'AUTHORIZE') { $VERB = 'CHARGE'; }

		$processor = 'GIFTCARD';
		if ($VERB eq 'REFUND') {
			## copy the payment details out of the original payment.
			my $paymentref = &ZPAY::unpackit($payrec->{'acct'});
			foreach my $k (keys %{$paymentref}) {
				$payment{$k} = $paymentref->{$k};
				}
			}

		if ((not defined $payment{'GC'}) && (not defined $payment{'GI'})) { 
			$ERROR = "998|Giftcard GCID or CODE is required for process_payment";
			}
		elsif ($VERB eq 'CAPTURE') {
			$ERROR = "998|Giftcards do not support CAPTURE - use CHARGE";
			}
		elsif (($VERB eq 'REFUND') || ($VERB eq 'CHARGE')) {
			## all good
			}
		else {
			$ERROR = "998|Unsupported Giftcard VERB:$VERB";
			}
		}
	elsif ($VERB eq 'SET') {
		## a "SET" verb is allowed for any type of payment, regardless of tender type.
		}
	else {
		## Unknown tender[ECHECK]
		$ERROR = sprintf('998|Unknown tender[%s]',$payrec->{'tender'});
		}

	##
	## PHASE 2: load the processor object
	##

	if ($ERROR) {
		## something bad happened.
		}
	elsif (defined $ZP) {
		## based on the tender type, we've already loaded a module.
		}
	elsif (not defined $processor) {
		## based on the tender type, we probably won't be loading a module at all.
		}
	elsif ($processor eq 'AUTHORIZENET') {
		require ZPAY::AUTHORIZENET;
		($ZP) = ZPAY::AUTHORIZENET->new($USERNAME,$webdbref);		
		}
#	elsif ($processor eq 'QBMS') {
#		require ZPAY::QBMS;
#		($ZP) = ZPAY::QBMS->new($USERNAME,$webdbref);
#		}
	elsif (($processor eq 'PAYPALWP') || ($processor eq 'PAYPALVT')) {
		require ZPAY::PAYPALWP;
		($ZP) = ZPAY::PAYPALWP->new($USERNAME,$webdbref);
		}
	elsif ($processor eq 'AMZPAY') {
		require ZPAY::AMZPAY;
		($ZP) = ZPAY::AMZPAY->new($USERNAME,$webdbref);
		}
	elsif ($processor eq 'PAYPALEC') {
		require ZPAY::PAYPALEC;
		($ZP) = ZPAY::PAYPALEC->new($USERNAME,$webdbref);
		}
	elsif ($processor eq 'PAYPALWP') {
		require ZPAY::PAYPALWP;
		($ZP) = ZPAY::PAYPALWP->new($USERNAME,$webdbref);
		}
	elsif ($processor eq 'LINKPOINT') {
		require ZPAY::LINKPOINT;
		($ZP) = ZPAY::LINKPOINT->new($USERNAME,$webdbref);
		}
	elsif (($processor eq 'PAYFLOW') && ($payrec->{'tender'} eq 'CREDIT')) {
		require ZPAY::PAYFLOW;
		($ZP) = ZPAY::PAYFLOW->new($USERNAME,$webdbref);
		}
	elsif (($processor eq 'SKIPJACK') && ($payrec->{'tender'} eq 'CREDIT')) {
		require ZPAY::SKIPJACK;
		($ZP) = ZPAY::SKIPJACK->new($USERNAME,$webdbref);
		}
	elsif ($processor eq 'ECHO') {
		require ZPAY::ECHO;
		($ZP) = ZPAY::ECHO->new($USERNAME,$webdbref);
		}
	elsif ($processor eq 'MANUAL') {
		require ZPAY::MANUAL;
		($ZP) = ZPAY::MANUAL->new($USERNAME,$webdbref);
		}
#	elsif ($processor eq 'GOOGLE') {
#		## GOOGLE is still a bit wonky, it doesn't really use $ZP like other methods do.		
#		## there is some specialized "if google" code below
#		##  which could probably be forced into the $ZP model with a bit of work
#		require ZPAY::GOOGLE;
#		($ZP) = ZPAY::GOOGLE->new($USERNAME,$webdbref);
#		}
	elsif ($processor eq 'TESTING') {
		require ZPAY::TESTING;
		($ZP) = ZPAY::TESTING->new($USERNAME,$webdbref);
		}
	elsif ($processor eq 'GIFTCARD') {
		require ZPAY::GIFTCARD;
		($ZP) = ZPAY::GIFTCARD->new($USERNAME,$webdbref);
		}
	elsif ($processor eq 'POINTS') {
		require ZPAY::POINTS;
		($ZP) = ZPAY::POINTS->new($USERNAME,$webdbref);
		}
	else {
		$ERROR = sprintf('998|Unknown gateway processor[%s]',$processor);
		}


	if (not $ERROR) {
		## check for corruption in the order.
		my $ise = $self->check($self->username(), $self->oid());
		if ($ise ne '') { $ERROR = "998|$ERROR"; }
		}


	if (not $ERROR) {
		$payrec->{'GW'} = $processor;		
		}


	##
	## PHASE 3: run the action!
	##
	if ($ERROR) {
		}
	elsif ($VERB eq 'FAKEAUTHORIZE') {
		$payrec->{'ps'} = '109';
		delete $payment{'CV'};		# yeah sorry, but no storing CV numbers.
		my ($WALLETID) = &ZPAY::insert_payment_into_wallet($self,\%payment);		
		if ($WALLETID>0) {
			$payment{'CM'} = &ZTOOLKIT::cardmask($payment{'CC'});
			delete $payment{'CC'};
			}
		$payment{'WI'} = $WALLETID;
		$payrec->{'acct'} = &ZPAY::packit(\%payment);
		$self->add_history(
			sprintf('PAY::fakeauthorize p=%s uuid=%s amt=%s wallet=%d',$processor,$payrec->{'uuid'},$payrec->{'amt'},$WALLETID),
			'etype'=>2,'luser'=>$payrec->{'luser'}
			);
		$self->fraud_check($webdbref);
		}
	elsif ($VERB eq 'AUTHORIZE') {
		$self->add_history(sprintf('PAY::authorize p=%s uuid=%s amt=%s',$processor,$payrec->{'uuid'},$payrec->{'amt'}),'etype'=>2,'luser'=>$payrec->{'luser'});
		($payrec) = $ZP->authorize($self,$payrec,\%payment);
		if (($payrec->{'tender'} eq 'CREDIT') && (&ZPAY::ispsa($payrec->{'ps'},['2','9']))) {
			## store credit cardin wallet on denied payment (eventually we might filter the status here to which ones save
			## and which ones don't.
			my ($WALLETID) = &ZPAY::insert_payment_into_wallet($self,\%payment);
			$self->add_history("PAY::authorize created wallet:$WALLETID on failure",'etype'=>2,'luser'=>$payrec->{'luser'});
			}
		$self->fraud_check($webdbref);
		}
	elsif ($VERB eq 'CAPTURE') {
		if (substr($payrec->{'ps'},0,1) eq '0') {
			$ERROR = sprintf("%s|PAY::capture aborted because ps[%s] - already captured!'",$payrec->{'ps'},$payrec->{'ps'});
			}
		elsif ( 
			($payrec->{'ps'} != 109) && 
			($payrec->{'ps'} != 189) && ($payrec->{'ps'} != 199) && 
			($payrec->{'ps'} != 299) && ($payrec->{'ps'} != 499)) {
			$ERROR = sprintf('%d|PAY::capture - failed: system cannot locate previous authorization',$payrec->{'ps'});
			}
		elsif (not defined $payment{'amt'}) {
			## amount was not set on this capture, so we assume we're capturing the full amount.
			$payment{'amt'} = $payrec->{'amt'};
			}
		elsif ($payment{'amt'} != $payrec->{'amt'}) {
			## amount was set, and differs from the capture amount.
			$self->add_history("TXN[$payrec->{'uuid'}] WARN[capture differs from auth] AUTH-AMT[$payrec->{'amt'}] CAPTURE-AMT[$payment{'amt'}]",'etype'=>2,'luser'=>$payrec->{'luser'});
			$payrec->{'amt'} = $payment{'amt'};
			}
	
		if (defined $ERROR) {
			## something already happened!
			}
		else {
			$self->add_history(sprintf('PAY::capture p=%s uuid=%s amt=%s',$processor,$payrec->{'uuid'},$payrec->{'amt'}),'etype'=>2,'luser'=>$payrec->{'luser'});
			($payrec)= $ZP->capture($self,$payrec,\%payment);
			}
		## END OF CAPTURE
		}
	elsif ($VERB eq 'CHARGE') {
		if (($payrec->{'tender'} eq 'ECHECK') && ($payrec->{'ps'} eq '120')) {
			# eChecks they don't capture, they just get flagged as paid.			
			my %clone = %{$payrec};
			$clone{'puuid'} = $clone{'uuid'};
			delete $clone{'txn'};
			delete $clone{'uuid'};
			$clone{'ps'} = '006';
			($payrec) = $self->add_payment('ECHECK',$payrec->{'amt'},%clone);
			}
		else {
			## BAD: this writes the cvv to the order:
			# $self->add_history(sprintf('PAY::charge payment=%s',&ZTOOLKIT::buildparams(\%payment)));
			$self->add_history(sprintf('PAY::charge p=%s uuid=%s amt=%s',$processor,$payrec->{'uuid'},$payrec->{'amt'}),'etype'=>2,'luser'=>$payrec->{'luser'});
			($payrec)= $ZP->charge($self,$payrec,\%payment);
			$self->fraud_check($webdbref);

			if (($payrec->{'tender'} eq 'CREDIT') && (&ZPAY::ispsa($payrec->{'ps'},['2','9']))) {
				## store credit cardin wallet on denied payment (eventually we might filter the status here to which ones save
				## and which ones don't.
				my ($WALLETID) = &ZPAY::insert_payment_into_wallet($self,\%payment,'IS_FAILED'=>1);
				$self->add_history("PAY::authorize created wallet:$WALLETID on failure",'etype'=>,'luser'=>$payrec->{'luser'});
				}
			}
		}
	elsif ($VERB eq 'REFUND') {		
		$self->add_history(sprintf('PAY::credit p=%s uuid=%s amt=%s pamt=%s',$processor,$payrec->{'uuid'},$payrec->{'amt'},$payment{'amt'}),'etype'=>2,'luser'=>$payrec->{'luser'});
		($payrec) = $ZP->credit($self,$payrec,\%payment);
		if ((defined $payment{'note'}) && (not defined $payrec->{'note'})) {
			$payrec->{'note'} = $payment{'note'};
			}
		}
	elsif ($VERB eq 'VOID') {
		$self->add_history(sprintf('PAY::void p=%s uuid=%s',$processor,$payrec->{'uuid'}),'etype'=>2,'luser'=>$payrec->{'luser'});
		($payrec) = $ZP->void($self,$payrec,\%payment);
		if ((defined $payment{'note'}) && (not defined $payrec->{'note'})) {
			$payrec->{'note'} = $payment{'note'};
			}
		}
	elsif ($VERB eq 'SET') {
		## this is used to put in manual (external) payments
		$self->add_history(sprintf("PAY::set ps=%s",$payment{'ps'}),'etype'=>2,'luser'=>$payrec->{'luser'});
		if (defined $payment{'ps'}) { 
			$payrec->{'ps'} = $payment{'ps'}; 
			delete $payment{'ps'};
			}
		if (defined $payment{'note'}) { 
			$payrec->{'note'} = $payment{'note'}; 
			delete $payment{'note'};
			}	
		if ($payment{'CC'}) {
			$payment{'CM'} = &ZTOOLKIT::cardmask($payment{'CC'});
			delete $payment{'CC'};
			}
		$payrec->{'acct'} = &ZPAY::packit(\%payment);
		}
	elsif ($VERB eq 'PAIDINFULL') {
		
		}
	else {
		$ERROR = "998|Unknown VERB[$VERB]";		
		}

	if ($ERROR) {
		my ($ps,$txt) = split(/\|/,$ERROR);
		$payrec->{'ps'} = $ps;
		$payrec->{'note'} = "ERROR:$txt";
		}


	if ((substr($payrec->{'ps'},0,1) eq '0') || (substr($payrec->{'ps'},0,1) eq '4')) {
		## payment is paid, so we should add fees
		my @FEES = $self->payment_fees($payrec,apply=>1,webdb=>$webdbref);		
		}

	push @{$self->{'@CHANGES'}}, [ 'add_payment' ];

	##
	## One save to bind them all!
	##
	$self->order_save();
	return($payrec);
	}


## this generates a unique uuid (which is typically order.#
sub next_payment_uuid {
	my ($self) = @_;	
	my $payments = $self->payments();
	my $i = scalar(@{$payments});

	my $uuid = undef;

	while (not defined $uuid) {
		$uuid = sprintf("%sZ%d",$self->oid(),$i);
		foreach my $payref (@{$payments}) {
			if ($payref->{'uuid'} eq $uuid) { 
				## shit, we found this uuid! wtf! try again.
				$i++; $uuid = undef;
				}
			}
		if ($i > 100) { $uuid = ''; }
		}
	if ($uuid eq '') {
		## hmm.. somethign went horribly horribly wrong, this will try and recover.
		$uuid = Data::GUID->new()->as_string();
		}
	return($uuid);
	}

##
##
##
sub add_payment {
	my ($self, $tender, $amt, %options) = @_;

	## default to 
	## TODO: check to see if a payment is unique!

	$amt = &ZOOVY::f2money($amt);


	##
	## valid tenders:
	##		CASH
	##		PO
	##		ECHECK
	##		CHECK
	##		GIFTCARD
	##		PAYPAL
	##	
	## if more than one tender type appears then it becomes "MIXED"
	##		payment_method 
	##
	##		
	##
	if (not defined $options{'ts'}) { $options{'ts'} = time(); }		
	if (not defined $options{'txn'}) { $options{'txn'} = ''; }
	## NOTE: we need to make sure payment ID's are sufficiently unique before implementing this:
	#if ((not defined $options{'uuid'}) && ($options{'ID'})) { 
	#	$options{'uuid'} = $options{'ID'};	## this should be consolidated at some point and just referred to as ID
	#	if ($options{'uuid'} eq '') { delete $options{'uuid'}; }
	#	}
	if (not defined $options{'uuid'}) { $options{'uuid'} = $self->next_payment_uuid(); }

	if (not defined $options{'note'}) { $options{'note'} = "$tender Payment"; }
	if (not defined $options{'voided'}) { $options{'voided'} = sprintf("%d",0); }

	if (not defined $options{'luser'}) { $options{'luser'} = $options{'LU'}; }
	if (not defined $options{'luser'}) { $options{'luser'} = ''; }

	if (not defined $options{'voidtxn'}) { $options{'voidtxn'} = sprintf("%d",0); }
	if (not defined $options{'ps'}) { $options{'ps'} = '500'; }
	if (not defined $options{'debug'}) { $options{'debug'} = ''; }	
	if (not defined $options{'r'}) { $options{'r'} = ''; }	

	## puuid is "ptxn" on sync prior xcompat 200
	if (not defined $options{'puuid'}) { $options{'puuid'} = ''; }	

	my $acctref = &ZPAY::unpackit($options{'acct'} || "");
	foreach my $key (keys %options) {
		next unless (length($key) == 2);	# must be two digits
		next unless (uc($key) eq $key);	# must be upper case
		next if ($key eq 'CC');	# must NOT be a credit card.
		next if ($key eq 'TN');	# don't need to save this
		next if (substr($key,0,1) eq '$');	# skip $# $$, etc.
		$acctref->{$key} = $options{$key};
		}

	## hmm.. we should probably try and validate amt

	##
	## run through the payments to recompute any balances
	##
	my %payment = ( 
		ts=>$options{'ts'},		# time it was created
		tender=>$tender,			# GIFTCARD, PAYPAL, CREDIT
		uuid=>$options{'uuid'}, # unique identifier (order#.##)
		txn=>$options{'txn'},	# external settlement transaction (usually this is what merchants search by)
		amt=>$amt,					# amount of the transaction
		note=>$options{'note'},	# a pretty description of the transaction e.g. "Giftcard 1234-xxxx-xxxx-5678"
		acct=>&ZPAY::packit($acctref),	# buyer account # e.g. ####-xxxx-xxxx-#### for a credit card 
		voided=>$options{'voided'},	# when the transaction was voided (if it was or 0 if it hasn't been)
		voidtxn=>sprintf("%d",$options{'voidtxn'}),	# void transaction #
		puuid=>$options{'puuid'},		# parent txn for chainging (credits should be chained to the parent txn)
												# NOTE: in order for a transaction to be chained it must have a txn set
		ps=>$options{'ps'},		# payment status
		debug=>$options{'debug'},			# gateway response	
		r=>$options{'r'},
		auth=>$options{'auth'},	# external auth transaction
		luser=>$options{'luser'},	# which user created this transaction
		);
	if (not defined $self->{'@PAYMENTS'}) { $self->{'@PAYMENTS'} = []; }
	push @{$self->{'@PAYMENTS'}}, \%payment;

	if ($payment{'tender'} eq 'GOOGLE') {
		}
	if (($payment{'tender'} eq 'PAYPAL') || ($payment{'tender'} eq 'PAYPALEC')) {
		}

	if (($payment{'tender'} eq 'CASH') || ($payment{'tender'} eq 'CHECK') || 
		 ($payment{'tender'}) || ($payment{'tender'} eq 'WIRE') ) {
		## let the user pass in a 'ps' (payment status) for cash
		if ($options{'ps'}) { $payment{'ps'} = $options{'ps'}; }
		}

	if ($payment{'tender'} eq 'ADJUST') {
		$payment{'ps'} = '088';	# adjust payments are always treated as 'paid in full'
#create table ORDER_PAYMENT_ADJUSTMENTS (
#	ID integer unsigned auto_increment,
#	USERNAME varchar(20) default '' not null,
#	MID integer unsigned default 0 not null,
#	PRT tinyint unsigned default 0 not null,
#	ORDERID varchar(20) default '' not null,
#	CREATED_GMT integer unsigned default 0 not null,
#	UUID varchar(32) default '' not null,
#	AMOUNT decimal(10,2) default 0 not null,
#	NOTE tinytext default '' not null,
#	LUSER varchar(10) default '' not null,
#	unique(MID,ORDERID,UUID),
#	index(MID,PRT,CREATED_GMT),
#	primary key(ID)
#);
		my ($udbh) = &DBINFO::db_user_connect($self->username());
		my $pstmt = &DBINFO::insert($udbh,'ORDER_PAYMENT_ADJUSTMENTS',{
			'USERNAME'=>$self->username(),
			'MID'=>$self->mid(),
			'PRT'=>$self->prt(),
			'ORDERID'=>$self->oid(),
			'CREATED_GMT'=>$payment{'ts'},
			'UUID'=>$payment{'uuid'},
			'AMOUNT'=>sprintf("%.2f",$amt),
			'NOTE'=>$payment{'note'},
			'LUSER'=>$payment{'luser'},
			},'update'=>0,'sql'=>1);
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		&DBINFO::db_user_close();
		}

	## note: due is set in memory *after* recalculate recomputes the balance. 
	$payment{'due'} = $self->in_get('sum/balance_due_total');
	# print STDERR Dumper('AFTER: ',\%payment);

	if ($options{'event'}) {
		$self->add_history($options{'note'},$options{'ts'},'etype'=>2,'luser'=>$options{'luser'});
		}

	push @{$self->{'@CHANGES'}}, [ 'add_payment' ];

	return(\%payment);
	}



#
#	my %payment = (
#		ts=>$options{'ts'},	  # time it was created  - 4 byte unsigned int.
#		tender=>$tender,		  # GIFTCARD, PAYPAL, CREDIT	varchar(10)
#		uuid=>$options{'uuid'}, # unique identifier (order#.##)	varchar(32)
#		auth=>$options{'auth'}, # external auth transaction	varchar(20) 
#		txn=>$options{'txn'},	# external settlement transaction varchar(20)
#										 # (usually this is what merchants search by) varchar(20)
#		settled=>$options{'settled'}	# a date/time the transaction was settled.
#		amt=>$amt,				  # amount of the transaction	decimal(10,2)
#		acct=>$options{'acct'}, # buyer account # e.g. ####-xxxx-xxxx-#### for a credit card	varchar(64)
#		note=>$options{'note'}, # a pretty description of the transaction e.g. "Giftcard 1234-xxxx-xxxx-5678"
#		voided=>$options{'voided'},	# when the transaction was voided (if it was or 0 if it hasn't been)
#		voidtxn=>$options{'voidtxn'}, # void transaction #
#		puui=>$options{'puuid'},	# parent txn for chainging (credits should be chained to the parent uuid) varchar(20)
#		debug=>""		# response from the last api transaction
#		ps=>"",			# payment_status - for this specific payment
#		);
#	question: how do we store credit card + dates or echeck
#


##
##  accepts 'tender'=>'GOOGLE' (or other tender types) and will only return payments of that type.
##
sub payments {
	my ($self,%options) = @_;

	if (not defined $self->{'@PAYMENTS'}) {
		$self->{'@PAYMENTS'} = [];		
		}
	my $result = $self->{'@PAYMENTS'};
	
	if (scalar(keys %options)) {
		$result = [];
		foreach my $payrec (@{$self->{'@PAYMENTS'}}) {
			my $add = 1;
			if ((defined $options{'tender'}) && ($payrec->{'tender'} ne $options{'tender'})) { 
				## must be tender=>''
				$add = 0;
				}
			elsif ((defined $options{'is_parent'}) && ($options{'is_parent'}>0) && ($payrec->{'puuid'} ne '')) { 
				## is_parent=>1|0
				$add = 0;
				}
			elsif ((defined $options{'skip_uuid'}) && ($payrec->{'uuid'} eq $options{'skip_uuid'})) { 
				## skip_uuid=>  
				$add = 0;
				}
			elsif ((defined $options{'is_child'}) && ($options{'is_child'}>0) && ($payrec->{'puuid'} ne $options{'uuid'})) { 
				## is_child=>1|0, uuid=>
				$add = 0;
				}

			if ((defined $options{'can_capture'}) && ($options{'can_capture'}>0)) {
				if (not $add) {}
				elsif ($payrec->{'puuid'} ne '') { $add = 0; }
				elsif ($payrec->{'ps'} eq '109') { $add = 1; }
				elsif ($payrec->{'ps'} eq '179') { $add = 1; }
				elsif ($payrec->{'ps'} eq '189') { $add = 1; }
				elsif ($payrec->{'ps'} eq '199') { $add = 1; }
				else { $add = 0; }	# not capturable
				}

			if ($add) {
				push @{$result}, $payrec; 
				}
			}
		}

	return($result);
	}


##
## this returns an interesting structure, it's an arrayref where the first element
##		is a reference to the parent transaction, and the second element is an array of
##		chained transactions sorted by timestamp (the order they were created)
##		
##		the second position is an empty arrayref if there are no chained transactions
##
sub payments_as_chain {
	my ($self) = @_;

	my %puuids = (''=>[]);
	## build a list of ptxn (parent transactions) - first level sort, this is necessary because
	##	there is no implicit guarantee that payments are stored in any particular order.
	## puuids =
	foreach my $pref (@{$self->payments()}) {
		if ($pref->{'puuid'}) {
			push @{$puuids{ $pref->{'puuid'} }}, $pref; 
			}
		else {
			push @{$puuids{ '' }}, $pref;
			}
		}

	my @output = ();
	foreach my $pref (@{$puuids{''}}) {
		my $thischain = [];
		if (defined $puuids{$pref->{'uuid'}}) {
			## eventually we'll probably actually need to sort the chained payments here.
			foreach my $cref (@{$puuids{$pref->{'uuid'}}}) {
				push @{$thischain}, $cref;
				}
			}
		push @output, [ $pref, $thischain ];
		}

	return(\@output);
	} 





##
## this set's variables on a payment if you know the uuid of the payment
##
sub update_payment_uuid {
	my ($self,$uuid,%vars) = @_;

	my ($payrec) = $self->payment_by_uuid($uuid);
	#if ((not defined $payrec) && ($self->__GET__('created')<1289466060)) {
	#	## 1289466060 =  2010-11-11 01:01:00 
	#	## hmm.. the proper UUID doesn't exist, SO we'll try falling back to ORDERV4
	#	($payrec) = $self->payment_by_uuid("ORDERV4");
	#	}

	if (not defined $payrec) {
		$self->add_history("ERROR update_payment_uuid uuid[$uuid] vars[".&ZTOOLKIT::buildparams(\%vars)."]");
		}
	elsif ($payrec) {
		foreach my $k (keys %vars) { $payrec->{$k} = $vars{$k}; }
		}

	push @{$self->{'@CHANGES'}}, [ 'add_payment' ];
	return($payrec);
	}


##
## this searches through payments, looking for a uuid
##
sub payment_by_uuid {
	my ($self,$uuid) = @_;

	my $presult = undef;
	foreach my $payrec (@{$self->payments()}) {
		if ($payrec->{'uuid'} eq $uuid) {
			$presult = $payrec; 	
			}
		}
	return($presult);
	}


##
## this searches through payments, looking for a uuid
##	NOTE: this will NOT find chained transactions, only parents.
sub payment_lookup_uuid {
	my ($self,$key,$value,%options) = @_;

	my $include_chained = 0;
	if ($options{'include_chained'}) { $include_chained++; }

	my $presult = undef;
	my $uuid = undef;
	foreach my $payrec (@{$self->payments()}) {
		next if (($payrec->{'puuid'} ne '') && (not $include_chained));
		if ($payrec->{$key} eq $value) {
			$presult = $payrec; 	
			}
		}

	if (defined $presult) {
		$uuid = $presult->{'uuid'};
		}

	return($uuid);
	}






##
## returns an orderid for a cart that was checked out in the last hour.
##
sub lookup_cartid {
	my ($USERNAME,$CARTID,$SINCE) = @_;

	## if we have a cartid, lets do a quick duplicate order check.
	my ($odbh) = &DBINFO::db_user_connect($USERNAME);
	my ($ORDERID) = (undef);
	if (defined $CARTID) {
		my $qtCARTID = $odbh->quote($CARTID);
		my $recentts = time()-3600;	# right now, minus an hour .. so no duplicate carts allowed within an hour.
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		my $TB = &DBINFO::resolve_orders_tb($USERNAME,$MID);
		my $pstmt = "select ORDERID from $TB where MID=$MID /* $USERNAME */ and CARTID=$qtCARTID";
		if ($SINCE>0) { $SINCE = int($SINCE); $pstmt .= " and CREATED_GMT>$SINCE"; }
		# print "$pstmt\n";
		($ORDERID) = $odbh->selectrow_array($pstmt);
		}
	&DBINFO::db_user_close();
	return($ORDERID);
	}


######################################################################################
## $o->check()
######################################################################################
## Purpose: Checks the order object to make sure everything is in order (if you'll
##			 pardon the pun)
## Accepts: Order Object,
##			 $username (optional makes sure the username stored in the object is right)
##			 $order_id (optional makes sure the ID stored in the object is the same)
##			 $strict (whether or not we should check that pool, etc. are set)
## Returns: An error string on failure, and a blank string on success
sub check {
	my ($self, $username, $order_id, $strict) = @_;
	## Make sure the order object is defined
	return '';
	}


## Gets the next available order ID
## note: normally $COUNT will be one unless we're requesting a block, don't
##		 ask for ZERO since it will simply return the last order ID issued.
## returns the last number in the sequence, if you fetch a count block, then
## you can assume RETURN_VAL-n through RETURN_VAL where n is the count you 
## requested is a valid bank of numbers.
sub next_id {
	my ($USERNAME, $count, $CARTID) = @_;

	if (defined $CARTID) {
		if ($CARTID eq '') { $CARTID = undef; }
		}

	my $REGISTER_GUID = 0;
	if (($count==0) && ($CARTID ne '')) {
		## a count of zero means a permanent, forever kind of CARTID (EREFID)
		$REGISTER_GUID++;
		my ($ORDERID) = &DBINFO::guid_lookup($USERNAME,"EREFID",$CARTID);
		if (defined $ORDERID) {
			return($ORDERID);
			}
		}

	if ((not defined $count) || ($count <= 0)) { $count = 1; }

	## SANITY: at this point we're not going to be able to short circuit!

	my @t = localtime();
	my $YEARMON = &ZTOOLKIT::zeropad(4,($t[5] + 1900)) . '-' . &ZTOOLKIT::zeropad(2,($t[4] + 1));

	my $redis = undef;
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $ID = 0;

	if ($MID <= 0) { 
		$ID = "99".time()%86400;
		#print STDERR "WARNING: MID for $USERNAME is [$MID]\n"; 
		}
	else {
		$redis = &ZOOVY::getRedis($USERNAME);
		}

	if (($ID==0) && (defined $redis) && (defined $CARTID) && ($CARTID ne '')) {
		$ID = $redis->get("OIDRSV+$USERNAME+$CARTID");
		}
	
	while ($ID == 0) {
		my $udbh = &DBINFO::db_user_connect($USERNAME);
		my $host = $udbh->quote( ((defined $ENV{'SERVER_ADDR'})?$ENV{'SERVER_ADDR'}:'').'');	

		my $pstmt = "update ORDER_COUNTERS set COUNTER=COUNTER+$count,LAST_PID=$$,LAST_SERVER=$host where MID=$MID limit 1";
		## if the record doesn't exist then $dbh->do will return a zero, then we should insert
		if ($udbh->do($pstmt)==0) {
			## order_counters record doesn't exist. 
			$ID = 1000;
			$pstmt = "insert into ORDER_COUNTERS (MID,MERCHANT,COUNTER,LAST_PID,LAST_SERVER) values($MID,".$udbh->quote($USERNAME).",$ID,$$,$host)";
			print STDERR $pstmt."\n";
			if ($udbh->do($pstmt)==0) { 
				print "Content-type: text/plain\n\nCould not create entry in ORDER_COUNTERS table - fatal error.\n<br>insert into ORDER_COUNTERS (MID,MERCHANT,COUNTER,LAST_PID,LAST_SERVER) values($MID,".$udbh->quote($USERNAME).",$ID,$$,$host)"; 	
				print STDERR Carp::confess("COULD NOT CREATE ENTRY IN ORDER_COUNTERS table");
				die(); 
				}
			}
		else {
			$pstmt = "select COUNTER from ORDER_COUNTERS where MID=$MID and LAST_PID=$$ and LAST_SERVER=$host limit 0,1";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();		
			if ($sth->rows()) {
				($ID) = $sth->fetchrow();
				}
			if ($ID>$^T) { 
				$ID = 1000; 
				$pstmt = "update ORDER_COUNTERS set COUNTER=$ID,LAST_PID=$$,LAST_SERVER=$host where MID=$MID /* $USERNAME */ limit 1";
				print STDERR $pstmt."\n";
				$udbh->do($pstmt);
				}
			$sth->finish();	
			}
			

		my $TB = &DBINFO::resolve_orders_tb($USERNAME,$MID);
		$pstmt = "select count(*) from $TB where MID=$MID and ORDERID=".$udbh->quote($YEARMON.'-'.$ID);
		my ($count) = $udbh->selectrow_array($pstmt);
		
		if ($count>0) { 		
			warn "FOUND DUPLICATE DBID: $ID\n";
			$ID = 0; 
			}
		&DBINFO::db_user_close();

		if (($ID>0) && (defined $redis) && (defined $CARTID) && ($CARTID ne '')) {
			$redis->set("OIDRSV+$USERNAME+$CARTID","$ID");
			$redis->expire("OIDRSV+$USERNAME+$CARTID",86400*7);
			}
		} 


	if ($REGISTER_GUID) {
		&DBINFO::guid_register($USERNAME,"EREFID",$CARTID,sprintf("$YEARMON-$ID"));
		}

	return($YEARMON.'-'.$ID);
	}


##
## creates a temporary recovery log
##
sub paymentlog {
   my ($self, $msg) = @_;
   open F, ">>/dev/shm/payment.log";
   print F sprintf("%s\t%s\t%s\t%s\n", &ZTOOLKIT::pretty_date($self->__GET__('our/order_ts'),1),$self->username(),$self->oid(),$msg);
   close F;
   }



##
##	returns a ref to the tracking array
##		the array contains a hashref with {code=>'' amount=>'')
##		if you enable resolve then you also get:
##			name=>'',
##
sub fees {
	my ($self,$resolve) = @_;
	if (not defined $self->{'@FEES'}) { my @ar = (); $self->{'@FEES'} = \@ar; }
	## eventually we should probably do some resolution here!

	if ($resolve) {
		foreach my $fee (@{$self->{'@FEES'}}) {
			my $sub = '';
			my $code = $fee->{'code'};
			$fee->{'code'} = substr($fee->{'code'},0,15);		# maximum length for a fee is 15 characters
			($code) = split(/\./,$code,2);
			if (defined $CART2::FEES_MAP{$code}) { $fee->{'name'} = $CART2::FEES_MAP{$code}; }
			}
		}

	return($self->{'@FEES'});
}

##
## sub: set_fee
##	parameters:
##		product - blank if an "order fee", or the product id (without options/claim/whatever)
##		feecode - should match the table in "CART2::FEES_MAP" trailed with a .subcode e.g.
##			EBAY.feetype
##		amount - should match the amount of the fee.
##		posted - the gmt time this was posted (if known)
##		memo - a memo describing the transaction.		
##		uuid - 
##
sub set_fee {
	my ($self,$product,$code,$amount,$posted,$memo,$uuid) = @_;

	if (not defined $uuid) { $uuid = ''; } 

	if (scalar(@_)==2) {
		## backward compatibility to old  ($code, $amount) = @_ format
		($code,$amount) = @_;
		$product = '';
		}

	## check to see if the fee already exists
	$code = uc($code);

	## verify this item doesn't already exist.
	my @EXISTING_FEES = ();
	foreach my $feeref (@{$self->{'@FEES'}}) {
		if (($uuid ne '') && ($feeref->{'uuid'} eq $uuid)) {
			## if a UUID is set, then the UUID's must match.
			push @{$self->{'@CHANGES'}}, [ 'fee_removed_by_uuid' ];
			}
		elsif ($feeref->{'code'} eq $code) {
			## UUID is not set, so then CODES must match
			push @{$self->{'@CHANGES'}}, [ 'fee_removed_by_code' ];
			}
		else {
			## 
			push @EXISTING_FEES, $feeref;
			}
		}

	if ($amount > 0) {
		my %NEW = ();
		## SANITY: at this point $setthis is initialized to a blank hash in the array, 
		##				or to the existing hash in the array.

		$NEW{'code'} = substr($code,0,15);
		$NEW{'amount'} = $amount;

		if ((defined $memo) && ($memo ne '')) { $NEW{'memo'} = $memo; } 
		if ((defined $posted) && ($posted ne '')) { $NEW{'posted'} = $posted; }
		if ($uuid ne '') { $NEW{'uuid'} = $uuid; }
		if ($product ne '') { $NEW{'product'} = $product; }

		push @{$self->{'@CHANGES'}}, [ 'fee_added' ];
		push @EXISTING_FEES, \%NEW;
		}

	$self->{'@FEES'} = \@EXISTING_FEES;
	return(0);
	}

##
## NOTE: this is NOT multi-order safe.
## use a:
#		while ($DATA =~ s/\<ORDER(.*?)\<\/ORDER\>//is) {
#			my ($o,$err) = ORDER->create($USERNAME,tmp=>1);
#			$o->from_xml('<ORDER'.$1.'</ORDER>');
#			$o->save(1);
#			}
# to upload handle multiple orders!
#
 
sub from_xml {
	my ($self,$XML,$xcompat,$app) = @_;

#	if (not defined $xcompat) { $xcompat = 107; }
#
#	open F, ">>/tmp/from_xml";
#	print F Dumper($XML,$xcompat,$app);
#	close F;


	if ((not defined $xcompat) && ($XML =~ /\<order.*? v\=\"([\d]+)\".*?\>/)) {
		$xcompat = $1;
		warn "AUTO-DETECT VERSION: $xcompat\n";
		}

	my $error = ''; 
	if ($xcompat < 210) {

		my ($ATTRIB) = '';
		if ($XML =~ /<ORDER(.*?)>(.*?)<\/ORDER>/s) {
			($ATTRIB,$XML) = ($1,$2);
			}

		$self->{'V'} = $xcompat;

		my %data = ();
		$self->{'@HISTORY'} = [];
		$self->{'*stuff2'} = undef;
		$self->{'@SHIPMENTS'} = [];


		if ($ATTRIB =~ / ID="(.*?)"/) { $self->__SET__('our/orderid',$1); }
		if ($ATTRIB =~ / VERSION="(.*?)"/) { $self->{'V'} = int($1); }

		my $diskorder = undef;
		if ($self->__GET__('our/orderid') ne '') {
			($diskorder) = CART2->new_from_oid($self->username(),$self->__GET__('our/orderid'));
			if ((defined $diskorder) && (ref($diskorder) eq 'CART2')) {
				$self->{'ODBID'} = $diskorder->order_dbid();		## make sure we set ODBID otherwise we won't be able to save
				}
			# ($diskorder,my $err) = ORDER->new($self->username(),$self->{'order_id'});
			## preserve dispatch data
			#if ((defined $err) && ($err ne '')) {
			#	warn "diskorder error: $self->username(),$self->{'order_id'} [$err]\n";
			#	$diskorder = undef;
			#	}
			}
	
		if (defined $diskorder) {
			$self->{'@ACTIONS'} = $diskorder->{'@ACTIONS'};
			}

		if ($XML =~ /<DATA>(.*)<\/DATA>/s) {
			my $dataref = &ZTOOLKIT::xmlish_to_hashref($1,'decoder'=>'latin1');
			foreach my $k (keys %{$dataref}) {
				next if ($k =~ /^dst\_/);	## ignore dst_xxx crap
				next if ($k =~ /^(bill|ship)\_country$/);
				$self->legacy_order_set($k,$dataref->{$k});
				}
			## NOTE: legacy_order_set has support for bill_country and ship_country
			}

			#	## LOCK is passed inside <DATA> but it's a special field.
			#	$self->set_lock($self->__GET__('APPLOCK'));
			#	delete $self->__GET__('APPLOCK');

		#print STDERR "XML0 [$xcompat]\n";
		if ($XML =~ /<STUFF>(.*)<\/STUFF>/s) {
			my $data = $1;
			require STUFF;
			my ($stuff1) = STUFF->new($self->username(),'xml'=>$data,'xmlcompat'=>$xcompat);
			#if (defined $error) { 
			#	$self->add_history('STUFF ERROR: '.$error,etype=>8,'*SYSTEM'); 
			#	}
			my ($s2) = STUFF2::upgrade_legacy_stuff($stuff1);
			$self->{'*stuff2'} = $s2;
			}

		if ($XML =~ /<TRACKING>(.*)<\/TRACKING>/s) {
			## step1: copy the old tracking numbers.
			if (defined $diskorder) {
				$self->{'@SHIPMENTS'} = $diskorder->{'@SHIPMENTS'};
				}
					
			my $trkref = &ZTOOLKIT::xmlish_list_to_arrayref($1,'decoder'=>'latin1');
			if (defined $trkref) {
				foreach my $trk (@{$trkref}) {
					$self->set_trackref( $trk );
					}
				}
			}

		if ($XML =~ /<PAYMENTS>(.*?)<\/PAYMENTS>/s) {
			#<PAYMENTS>
			#<payment due="5.00" ts="1269989658" uuid="61613241C7C3C4FH.1" note="Giftcard 6161-xxxx-xxxx-C4FH [#487]" acct="6161-xxxx-xxxx-C4FH" auth="" puuid="" voidtxn="0" voided="0" txn="61613241C7C3C4FH.1" ps="070" amt="7.75" tender="GIFTCARD"></payment>
			#<payment uuid="LEGACY" note="3715xxxxxxx4001" auth="2916469383" txn="" debug="Successfully charged account - AVS No match on address or ZIP (Authorizenet Return Codes - Reason 1 - Response 1 - AVS N)" ps="199" tender="CREDIT" amt="0"></payment>
			#</PAYMENTS>
			my $payments = &ZTOOLKIT::xmlish_list_to_arrayref($1,'decoder'=>'latin1','content_attrib'=>'content');
			if (not defined $payments) { $payments = []; }
			$self->{'@PAYMENTS'} = $payments;
			if ($xcompat < 200) {
				foreach my $pref (@{$payments}) { $pref->{'puuid'} = $pref->{'ptxn'}; }
				}
			}
	
		if ($XML =~ /<EVENTS>(.*)<\/EVENTS>/s) {
			my $newevents = &ZTOOLKIT::xmlish_list_to_arrayref($1,'decoder'=>'latin1','content_attrib'=>'content');			
			if (not defined $newevents) { $newevents = []; }

			if ((defined $diskorder) && (ref($diskorder) eq 'CART2')) {
				my %ev = ();		# a hash keyed by uuid, value = event data
				my %evts = ();		# a hash keyed by uuid, value = timestamp
					
				## MERGE EVENTS FROM OLD ORDER + NEW ORDER
				if (not defined $newevents) { $newevents = []; }
				foreach my $e (@{$diskorder->history()},@{$newevents}) {
					$ev{ $e->{'uuid'} } = $e;
					$evts{ $e->{'uuid'} } = $e->{'ts'};
					}

				foreach my $k (&ZTOOLKIT::value_sort(\%evts)) {
					my $event = $ev{$k};
					$self->add_history($event->{'content'},%{$event});
					}
	
				my $pool = $diskorder->legacy_order_get('pool');
				my $payment = $diskorder->legacy_order_get('payment_status');
				$self->add_history("Synced from desktop client was pool=$pool payment=$payment $::XCLIENTCODE=$::XCOMPAT app=$app",'etype'=>4);
	
				if (($payment ne '') && ($self->legacy_order_get('payment_status') ne $payment)) {
					#$self->set_payment_status($self->legacy_order_get('payment_status'),"webapi-sync",[
					#	"Detected payment status change to: $payment - running events"
					#	]);
					}
				}
			else {
				$self->{'events'} = $newevents;
				}
			}	

		if ($XML =~ /<FEES>(.*)<\/FEES>/s) {
			$self->{'@FEES'} = &ZTOOLKIT::xmlish_list_to_arrayref($1,'decoder'=>'latin1');			
			}
	
		## reconcile order events, order notes, add an event
		if ((defined $diskorder) && (ref($diskorder) eq 'CART2')) {
			if (not defined $diskorder->legacy_order_get('timestamp')) {}
			elsif (not defined $self->legacy_order_get('timestamp')) {}
			elsif ($diskorder->legacy_order_get('timestamp') == 0) {}
			elsif ($self->legacy_order_get('timestamp') == 0) {}
			elsif ($diskorder->legacy_order_get('timestamp') > $self->legacy_order_get('timestamp')) {
				my $diskts = $diskorder->legacy_order_get('timestamp');
				my $clientts = $self->legacy_order_get('timestamp');
				$self->add_history("CORRUPT DATA: order has changed online since last sync. disk[$diskts] client[$clientts]",etype=>2+4+8+128);
				}
			}
		## write the synced changes to the database.
		}
	elsif ($xcompat == 210) {
		die("NOT AVAILABLE");
		}
	elsif ($xcompat == 211) {
		die("NOT AVAILABLE");
		}
	elsif ($xcompat>220) {
		## 220 and 222 are very similar



		my ($io) = IO::String->new($XML);
		my $rx = XML::SAX::Simple::XMLin($io,ForceArray=>1,KeyAttr=>{},ContentKey=>'_');	
		# &ZTOOLKIT::XMLUTIL::stripNamespace($rx);
		# print Dumper($rx);
		foreach my $grp (@CART2::VALID_GROUPS) {
			next if (not defined $rx->{$grp});

			my %FIELDS = ();
			foreach my $k (keys %{$rx->{$grp}[0]}) {
				$FIELDS{"$grp/$k"} = $rx->{$grp}[0]->{$k};
				}
			
			if ($xcompat < 222) {
				if ($grp eq 'our') {
					$FIELDS{"our/domain"} = $FIELDS{'our/sdomain'};
					delete $FIELDS{"our/sdomain"};
					delete $FIELDS{"our/profile"};
					}
				}

			# print Dumper($rx->{$grp});
			foreach my $k (keys %FIELDS) {
				$self->in_set("$grp/$k",$FIELDS{$k});
				}
			delete $rx->{$grp};
			}

		my $v = $rx->{'v'};
		delete $rx->{'v'};		

		foreach my $grp (keys %{$rx}) {
			if ($grp eq 'id') {
				## ignore this (for now)
				}
			elsif ($grp eq 'this') {
				## ignore this (for now)
				}
			elsif ($grp eq 'fees') {
				## ignore this (for now)
				}
			elsif ($grp eq 'history') {
				## ignore this (for now)
				}
			elsif (($grp eq 'stuff') || ($grp eq 'STUFF')) {
				foreach my $item (@{$rx->{'stuff'}->[0]->{'item'}}) {

					if (defined $item->{'options'}) {
						my %options = ();
						foreach my $opt (@{$item->{'options'}->[0]->{'option'}}) {
							$options{ $opt->{'id'} } = $opt;
							}
						$item->{'%options'} = \%options;
						delete $item->{'options'};
						}

					if (defined $item->{'attribs'}) {
						my %attribs = ();
						foreach my $attrib (@{$item->{'attribs'}[0]->{'attrib'}}) {
							$attribs{ $attrib->{'id'} } = $attrib->{'value'};
							}
						$item->{'%attribs'} = \%attribs;
						delete $item->{'attribs'};
						}
					## now add it.
					$self->stuff2()->drop('uuid'=>$item->{'uuid'});
					$self->stuff2()->fast_copy_cram($item);
					}
				}
			elsif ($grp eq 'actions') {
				## will not update from xml
				}
			elsif ($grp eq 'payments') {
				# # print Dumper($grp,$rx->{$grp});
				}
			elsif ($grp eq 'shipments') {
				# # print Dumper($grp,$rx->{$grp});
				}
			else {
				warn "grp: $grp\n";
				open F, ">>/tmp/unknown_grp";
				print F "$grp\n";
				close F;
				die();
				}
			}

		}

	return($error);
	}









## possible %options
##		format=>	email|checkout
##		uuid=>	(if undef, then we show an overall order status)
##		
## perl -e 'use lib "/backend/lib"; use ORDER; use Data::Dumper; my ($o) = ORDER->new("liz","2010-11-115"); print Dumper($o->explain_payment_status(format=>"email"));'
## perl -e 'use lib "/backend/lib"; use SITE::MSGS; $SITE::msgs = SITE::MSGS->new("liz"); use ORDER; use Data::Dumper; my ($o) = ORDER->new("liz","2010-11-115"); print Dumper($o->explain_payment_status(format=>"checkout"));'

##
##
## valid options:
##		skip_voided=>1|0
##		html=>1|0
##
#sub explain_payment_status {
#	my ($self, %options) = @_;
#
#	my $out = undef;
#
#	## default behavior is to skip chained payments	
#	if (not defined $options{'skip_chained'}) { $options{'skip_chained'}++; }
#
#	if (ref($options{'*SITE'}) ne 'SITE') {
#		warn Carp::confess("CART2::explain payment status *requires* *SITE  paramter to be passed"); 
#		}
#	my $SITE = $options{'*SITE'};
#
#	my $ERROR = $self->check();
#	if ($ERROR eq '') { $ERROR = undef; }
#
#	my $PACSREF = [];	# an arrayref, each element is a two position array
#							# 0: parent payrec
#							# 1: an array of chained payrecs (associated to element 0)
#
#	if (defined $ERROR) {
#		}
#	elsif (defined $options{'uuid'}) {
#		## did we receive a specific uuid, or do we need to show an "overall" status
#		my $payrec = $self->payment_by_uuid($options{'uuid'});
#		if (not defined $payrec) {
#			$ERROR = "UUID:$options{'uuid'} does not exist";
#			}
#		else {
#			push @{$PACSREF}, [ $payrec, $self->payments(is_child=>1,uuid=>$options{'uuid'}) ];
#			}
#		}
#	else {
#		$PACSREF = $self->payments_as_chain();
#		if (scalar(@{$PACSREF})==0) {
#			$ERROR = "no payments were attached to order, or the order was not fully processed when this status message was generated.";
#			}
#		}
#
#	#if ($0 eq '-e') {
#	#	print STDERR 'CART2::explain_payment_status (payments_as_chain) '.Dumper($PACSREF);
#	#	}
#
#	## SANITY: at this point @PAYRECS will be initalized or $out will be set to an error message
#	require ZPAY;	
#	if (defined $ERROR) {
#		}
#	elsif ($options{'format'} eq 'summary') {
#		}
#	elsif ($options{'format'} eq 'detail') {
#		}
#	else {
#		$ERROR = "function tell_payment_status 'format' param=$options{'format'} is invalid";
#		}
#
#
#	if (defined $ERROR) {
#		## SHIT ALREADY HAPPENED
#		$out = "EXPLAIN PAYMENT STATUS ERROR: $ERROR";
#		}
#	elsif ($options{'format'} eq 'summary') {
#		## SUMMARY MODE
#		$out = '';
#		if (scalar(@{$PACSREF})==0) {
#			$out .= "<div class=\"ztxt\">There are no payments currently applied to this order.</div>\n";
#			}
#		elsif (scalar(@{$PACSREF})==1) {
#			## nothing to do here!
#			}
#		elsif (scalar(@{$PACSREF})>1) {	
#			$out .= sprintf("<div class=\"ztxt\">[%d PAYMENTS TOTAL]</div>\n",scalar(@{$PACSREF}));
#			}
#		
#		foreach my $pacref (@{$PACSREF}) {			
#			my ($payrec,$cpayrecs) = @{$pacref};
#			next if (($payrec->{'voided'}) && ($options{'skip_voided'}));
#			next if (($payrec->{'puuid'} ne '') && ($options{'skip_chained'}==1)); # chained payment
#
#			my $acct = &ZPAY::unpackit($payrec->{'acct'});
#			my $line = '';
#			my $amt = $payrec->{'amt'};
#			if ($payrec->{'voided'}) { $amt = 0; }
#			$line .= sprintf("\$%.2f ",$amt);
#
#			if ($payrec->{'tender'} eq 'CREDIT') {
#				my ($CCorCM) = ($acct->{'CC'})?$acct->{'CC'}:$acct->{'CM'};
#				if ((not defined $CCorCM) || ($CCorCM eq '')) { 
#					$line .= 'Credit Card';
#					}
#				else {
#					$line .= &ZPAY::cc_type_from_number($CCorCM).' '; 
#					$line .= 'Credit Card';	
#					$line .= ' '.('X' x (length($CCorCM) - 4)).substr($CCorCM,-4,4); 
#					}
#				}
#			elsif (defined $payrec) {
#				# my %methods = &ZPAY::fetch_payment_methods_general();
#				my $pretty = $payrec->{'tender'};
#				foreach my $paymethod (@ZPAY::PAY_METHODS) {
#					if ($paymethod->[0] eq $payrec->{'tender'}) { $pretty = $paymethod->[1]; }
#					}
#				$line .= sprintf('%s',$pretty);
#				}
#			
#			if ($payrec->{'voided'}) {
#				$line .= " (VOIDED)";
#				}
#			else {
#				$line .= sprintf(" (%s)",,&ZPAY::payment_status_short_desc($payrec->{'ps'}));
#				}
#			$out .= "<div class=\"ztxt\">$line</div>\n";
#			## if we have any chained payment records, lets show them here:
#			}
#		}
#	elsif ($options{'format'} eq 'detail') {
#		$out .= '';
#
#
#		#if ((scalar(@{$PACSREF})>1) || ($o->legacy_order_get('payment_method') eq 'MIXED')) {
#		#	## this is a mixed type, it has one or more payment methods on it.
#		#	}
#
#		my %global_macros = ();
#		$global_macros{'%ORDERID%'} = $self->oid();
#		$global_macros{'%GRANDTOTAL%'} = $self->in_get('sum/order_total');
#		$global_macros{'%BALANCEDUE%'} = $self->in_get('sum/balance_due_total');
#		$global_macros{'%CUSTOMER_REFERENCE%'} = sprintf("%s",$self->in_get('want/po_number'));
#
#		if (scalar(@{$PACSREF})>0) {
#			## there is more than one payment method we will be displaying!
#			if (&ZPAY::ispsa($self->legacy_order_get('payment_status'),['0','1','4'])) {
#				$out .= $SITE->msgs()->get('invoice_mixed_success',\%global_macros);
#				}
#			else {
#				$out .= $SITE->msgs()->get('invoice_mixed_failure',\%global_macros);
#				}
#			}
#
#
#		foreach my $pacref (@{$PACSREF}) {
#			my ($payrec,$cpayrecs) = @{$pacref};
#
#			next if (($payrec->{'voided'}) && ($options{'skip_voided'}));
#			next if ($payrec->{'puuid'} ne ''); # chained payment
#
#
#			# Depending on the type of payment method of the order, return
#			# pay instructions for that particular payment type.
#			my $line = '';
#			my %macros = %global_macros;
#			# $macros{'%GRANDTOTAL%'} = $payrec->{'amt'};
#			# $macros{'%ORDERSTATUSURL%'} = '';
#
#			my $acctref = &ZPAY::unpackit($payrec->{'acct'});
#			if ($payrec->{'acct'} ne '') {
#				## copy in any acct fields, such as %PAYMENT_CC% or %PAYMENT_CY%
#				foreach my $id (keys %{$acctref}) {
#					$macros{ uc('%PAYMENT_'.$id.'%') } = $acctref->{$id};
#					}
#				}
#
#			$macros{'%PAYMENT_FIXNOWURL%'} = $SITE->URLENGINE()->get('customer_url').'/order/status?orderid='.$self->oid();
#
#			if ($payrec->{'tender'} eq 'CREDIT') {
#				#%CCTYPE%	Type of credit card the customer has entered
#				# $macros{'%CCTYPE%'} = q~<% /* CCTYPE macro */ loadurp("CART::chkout.cc_number"); format(payment=>"cc_type"); default(""); print(); %>~;
#				$macros{'%CREDIT_TYPE%'} = &ZPAY::cc_type_from_number( ($acctref->{'CC'})?$acctref->{'CC'}:$acctref->{'CM'} );
#				#%CCNUMBER%	Credit card number the customer has entered, with only the last few numbers showing
#				# $macros{'%CCNUMBER%'} = q~<% /* CCNUMBER macro */ loadurp("CART::chkout.cc_number"); format(payment=>"cc_masked"); default(""); print(); %>~;
#				$macros{'%CREDIT_NUMBER%'} = ($acctref->{'CM'})?$acctref->{'CM'}:&ZPAY::cc_hide_number($acctref->{'CC'});
#				#%CCEXPMONTH%	Customer-entered credit card expiration month
#				# $macros{'%CCEXPMONTH%'} = q~<% /* CCEXPMONTH macro */ loadurp("CART::chkout.cc_exp_month"); default(""); print(); %>~;
#				$macros{'%CREDIT_EXPMONTH%'} = $acctref->{'MM'};
#				#%CCEXPYEAR%	Customer-entered credit card expiration year				
#				# $macros{'%CCEXPYEAR%'} = q~<% /* CCEXPYEAR macro */ loadurp("CART::chkout.cc_exp_year"); default(""); print(); %>~;
#				$macros{'%CREDIT_EXPYEAR%'} = $acctref->{'YY'};
#				}
#
#			$macros{'%PAYMENT_TENDER%'} = $payrec->{'tender'};
#			$macros{'%PAYMENT_AMT%'} = $payrec->{'amt'};
#			$macros{'%PAYMENT_AMT_CURRENCY%'} = 'USD';
#			$macros{'%PAYMENT_AMT_PRETTY%'} = sprintf("\$%.2f",$payrec->{'amt'});
#			$macros{'%PAYMENT_NOTE%'} = $payrec->{'note'};
#			$macros{'%PAYMENT_TXN%'} = $payrec->{'txn'};
#			$macros{'%PAYMENT_AUTH%'} = $payrec->{'auth'};
#			$macros{'%PAYMENT_DEBUG%'} = $payrec->{'debug'};
#			$macros{'%PAYMENT_UUID%'} = $payrec->{'uuid'};
#
#			my @TRY_MSGID = ();
#			push @TRY_MSGID, sprintf('payment_%s_%s',lc($payrec->{'tender'}),$payrec->{'ps'});
#
#			if (&ZPAY::ispsa($payrec->{'ps'},['1'])) {
#				## payinstruction messages are for payments which are pending/waiting
#				push @TRY_MSGID, sprintf("payment_%s_pending",lc($payrec->{'tender'}));
#				push @TRY_MSGID, sprintf("payment_pending");
#				}
#			elsif (&ZPAY::ispsa($payrec->{'ps'},['2'])) {
#				## denied payment
#				push @TRY_MSGID, sprintf("payment_%s_denied",lc($payrec->{'tender'}));
#				push @TRY_MSGID, sprintf("payment_denied");
#				}
#			elsif (&ZPAY::ispsa($payrec->{'ps'},['0','4'])) {
#				## PAID/REVIEW
#				push @TRY_MSGID, sprintf("payment_%s_success",lc($payrec->{'tender'}));
#				push @TRY_MSGID, sprintf("payment_success");
#				}
#			elsif (&ZPAY::ispsa($payrec->{'ps'},['6'])) {
#				## voided payment
#				push @TRY_MSGID, sprintf('payment_%s_void',lc($payrec->{'tender'}));
#				push @TRY_MSGID, sprintf('payment_void');
#				}
#			elsif (&ZPAY::ispsa($payrec->{'ps'},['5'])) {
#				## processing payment
#				push @TRY_MSGID, sprintf('payment_%s_processing',lc($payrec->{'tender'}));
#				push @TRY_MSGID, sprintf('payment_processing');
#				}
#			elsif (&ZPAY::ispsa($payrec->{'ps'},['3'])) {
#				## voided payment
#				push @TRY_MSGID, sprintf('payment_%s_returned',lc($payrec->{'tender'}));
#				push @TRY_MSGID, sprintf('payment_returned');
#				}
#			elsif (&ZPAY::ispsa($payrec->{'ps'},['9'])) {
#				## error payment
#				push @TRY_MSGID, sprintf('payment_%s_error',lc($payrec->{'tender'}));
#				push @TRY_MSGID, sprintf('payment_%d_error',lc($payrec->{'ps'}));
#				push @TRY_MSGID, sprintf('payment_error');
#				}
#			else {
#				push @TRY_MSGID, sprintf('payment_unknown_status');
#				}
#
#			if (defined $options{'try_prefix'}) {
#				## if we get a try prefix ex: admin_ then we'll try those messages first ex:
#				## msgid=payment_credit_success  try_prefix=admin_ then we try: admin_payment_credit_success
#				my @NEW = ();
#				foreach my $msgid (@TRY_MSGID) { push @NEW, sprintf("%s%s",$options{'try_prefix'},$msgid); }
#				foreach my $msgid (@TRY_MSGID) {	push @NEW, $msgid; }
#				@TRY_MSGID = @NEW;
#				}
#			
#			foreach my $msgid (@TRY_MSGID) {
#				# print sprintf("MSGID: $msgid %d\n",($SM->exists($msgid));
#				next if ($line ne '');
#				if ($SITE->msgs()->exists($msgid)) { 
#					$line = $SITE->msgs()->get($msgid,\%macros); 
#					}
#				if ($line ne '') {
#					$line = sprintf("<!-- $msgid  --><div class=\"ztxt %s\">%s</div><!-- /$msgid -->",join(" ",@TRY_MSGID),$line);
#					}
#				}
#			
#			if ($line eq '') {
#				$line = "UNKNOWN PAYMENT STATUS TENDER=$payrec->{'tender'} PS=$payrec->{'ps'} UUID=$payrec->{'uuid'}\n";
#				$line .= "THE FOLLOWING MSGID'S COULD NOT BE FOUND: ".join(",",@TRY_MSGID);
#				}
#
#			$out .= qq~
#<!-- TENDER=$payrec->{'tender'} UUID=$payrec->{'uuid'} PS=$payrec->{'ps'} -->
#<div id="$payrec->{'uuid'}" class="payment_tender_$payrec->{'tender'} payment_ps_$payrec->{'ps'}">\n$line\n</div>
#~;
#			}
#
#
#
#		## PAID IN FULL/BALANCE DUE MESSAGING
#		if ($options{'uuid'}) {
#			## skip when we're just looking at one transaction.
#			}
#		elsif ($self->legacy_order_get('balance_due')>0) {
#			## balance due
#			$out .= sprintf("<!-- invoice_has_balancedue --><div class=\"ztxt invoice_has_balancedue\">%s</div><!-- /invoice_has_balancedue -->\n",$SITE->msgs()->get('invoice_has_balancedue',\%global_macros));
#			}
#		elsif ($self->is_paidinfull()) {
#			## paid in full
#			$out .= sprintf("<!-- invoice_is_paidinfull --><div class=\"ztxt invoice_is_paidinfull\">%s</div><!-- /invoice_is_paidinfull -->\n",$SITE->msgs()->get('invoice_is_paidinfull',\%global_macros));
#			}
#
#		## REVIEW STATUS
#		my $RS = $self->__GET__('flow/review_status');
#		if (not defined $RS) { $RS = ''; } else { $RS = substr($RS,0,1); }	# just keep the A of AOK
#		if ($options{'uuid'}) {
#			## skip when we're just looking at one transaction.
#			}
#		elsif ($RS eq '') {
#			## risk: not initialized!
#			}
#		elsif ($RS eq 'A') {
#			## risk: approved
#			$out .= sprintf("<!-- invoice_risk_approved --><div class=\"ztxt invoice_risk_approved\">%s</div><!-- /invoice_risk_approved -->\n",$SITE->msgs()->get('invoice_risk_approved',\%global_macros));
#			}
#		elsif (($RS eq 'R') || ($RS eq 'E')) {
#			## risk: risking
#			$out .= sprintf("<!-- invoice_risk_review --><div class=\"ztxt invoice_risk_review\">%s</div><!-- /invoice_risk_review -->\n",$SITE->msgs()->get('invoice_risk_review',\%global_macros));
#			}
#		elsif ($RS eq 'D') {
#			## risk: declined
#			$out .= sprintf("<!-- invoice_risk_declined --><div class=\"ztxt invoice_risk_declined\">%s</div><!-- /invoice_risk_declined -->\n",$SITE->msgs()->get('invoice_risk_declined',\%global_macros));
#			}	
#		}
#
#	if (not $options{'html'}) {
#		$out = &ZTOOLKIT::htmlstrip($out);
#		}
#
#
#	return($out);
#	}




##
## adds/updates tracking number(s)
##		$self->{'track'} format: array of hashrefs [ { 'carrier'=>'', track=>'' } ]
##		carrier should be: FEDX,USPS,UPS,AIRB,CUST	
##
sub set_tracking {
	my ($self, $carrier, $track, $notes, $cost, $actualwt, $luser, $created) = @_;

	my %trk = ();
	$trk{'carrier'} = $carrier;
	$trk{'track'} = $track;
	if (not defined $created) { $created = time(); }

	if (defined $notes) { $trk{'notes'} = $notes; }
	if (defined $cost) { $trk{'cost'} = $cost; }
	if (defined $actualwt) { $trk{'actualwt'} = $actualwt; }
	if (defined $created) { $trk{'created'} = $created; } 

	return($self->set_trackref(\%trk));
	}



##
## nuke a cart (useful for things like google checkout where we don't convert *THIS* into an order)
## 
sub nuke {
	my ($self) = @_;

	if ($self->is_cart()) {
		my ($redis) = &ZOOVY::getRedis($self->username());
		my $REDIS_ID = &CART2::redis_cartid($self->username(),$self->prt(),$self->cartid());
		if ($redis->exists($REDIS_ID)) {
			$redis->del($REDIS_ID);
			return(1);
			}
		return(0);
		}
	return(-1);
	}


##
## a trkref is a hash with the following fields:
##
## carrier - e.g. FDXG
## track - the tracking # provided by carrier.
##	notes - any notes associated with the package. 
## dval - declared value
##	ins - insurance provider (UPS,FDX,UPIC)
##	cost - the cost of the package from the carrier. 
##	actualwt - the actual weight of the package. 
##	void <-- unixtime (used by order manager)
##	created <-- unixtime (used by order manager)
##
sub set_trackref {
	my ($self, $trkref) = @_;

	if (not defined $self->{'@SHIPMENTS'}) {
		$self->{'@SHIPMENTS'} = [];
		}

	my $track = $trkref->{'track'};
	$trkref->{'carrier'} = uc($trkref->{'carrier'});
	my $carrier = $trkref->{'carrier'};

	## verify this item doesn't already exist.
	my $found = 0;
	my $i = scalar( @{$self->{'@SHIPMENTS'}} );
	if ($i>1) { $self->set_order_flag(1<<7); } ## set flag 7: multiple shipments.
	while ((not $found) && ($i>0)) {
		$i--;
		if ($self->{'@SHIPMENTS'}->[$i]->{'track'} eq $track) {
			$self->{'@SHIPMENTS'}->[$i] = $trkref;
			$found++;
			}
		}

	if (not $found) {
		push @{$self->{'@SHIPMENTS'}},$trkref;
		$self->queue_event('ship');
		#if (($self->legacy_order_get('payment_method') eq 'GOOGLE') && ($track ne '')) {
		#	## DISPATCH/NOTIFY GOOGLE OF TRACKING #'s
		#	require ZPAY::GOOGLE;
		#	&ZPAY::GOOGLE::deliverOrder($self, $carrier, $track);
		#	}
		}
	##
	## SANITY: at this point $setthis is initialized to a blank hash in the array, 
	##				or to the existing hash in the array.

#	if ((not defined $self->__GET__('shipped_gmt')) || 
#		($self->__GET__('shipped_gmt')==0)) {
		## record the shipped date.
#		$self->legacy_order_set('shipped_gmt',time());
#		}
	## changed to ship_date 2009-05-19, this is what ZID uses
	if ((not defined $self->__GET__('flow/shipped_ts')) || ($self->__GET__('flow/shipped_ts')==0)) {
		## record the shipped date.
		$self->__SET__('flow/shipped_ts',time());
		# $self->legacy_order_set('ship_date',time());
		}

	return($found);
	}

##
##	returns a ref to the tracking array
##		the array contains a hashref { carrier=>'' track=>'' cost=>'' notes=>'' }
##
sub tracking {
	my ($self) = @_;
	if (not defined $self->{'@SHIPMENTS'}) { my @ar = (); $self->{'@SHIPMENTS'} = \@ar; }
	return($self->{'@SHIPMENTS'});
	}




##
## masks a credit card
##
sub strip_payment {
	my ($self) = @_;

	my $cc = $self->legacy_order_get('card_number');
	if ($cc eq '') {
		## no cc in order!
		}
	elsif ($cc =~ m/^([\d]{4,4})(.*?)([\d]{4,4})$/) {
		my ($pre,$mid,$end) = ($1,$2,$3);
		if ($mid !~ /^[x]+$/) {
			$cc = ''; while (length($cc)<length($mid)) { $cc .= 'x'; }
			$cc = $pre.$cc.$end;
			$self->legacy_order_set('card_number',$cc);
			}
		}
	# $self->unr_set('cvvcid_number'); 	## remove the cvv for anything other than denied cards
	return();
	}





##
## all the behaviors which are necessary when we're cancelling an order.
##
sub cancelOrder {
	my ($self,%options) = @_;

	my ($luser) = $options{'LUSER'};
	if (not defined $luser) { $luser = ''; }

	require EXTERNAL;
	
	if (not defined $self->__GET__('flow/cancelled_ts')) {
		my ($USERNAME) = $self->username();
		my ($INV2) = INVENTORY2->new($USERNAME,$luser);
		my ($LM) = LISTING::MSGS->new($USERNAME);

		my ($detail) = $INV2->detail(WHERE=>["ORDERID","EQ",$self->oid()]);
		my %UUIDS = ();
		foreach my $row (@{$detail}) {
			$UUIDS{$row->{'UUID'}} = $row;
			}

		foreach my $item (@{$self->stuff2()->items()}) {
			my $qty = $item->{'qty'};
			my $stid = $item->{'stid'};
			$INV2->synctag($item->{'sku'});

			## AHH.. THE GOOD OLD DAYS:
			#my $TYPE = 'I';
			#if ($item->{'virtual'} =~ /^JEDI:/) { $TYPE = 'J'; }
			## Release inventory
			# &INVENTORY::add_incremental($self->username(),$prod,'I',$qtys{$prod});
		
			my $rowis = $UUIDS{$item->{'uuid'}};
			if (not defined $rowis) {
				## Yipes, doesn't exist in the INVENTORY_DETAIL, create an ERROR record as a marker. (QTY=>0)
				$self->add_history(
					sprintf("SKU:%s UUID:%s does not exist in INVENTORY_DETAIL - setting ERROR",$item->{'sku'},$item->{'uuid'}),
					'is'=>['error'],
					);
				$INV2->skuinvcmd($item->{'uuid'},"ERROR/INIT","ORDERID"=>$self->oid(),"NOTE"=>sprintf("cancelled non-existant sku from order %s",$self->oid()));
				}
			elsif ($rowis->{'BASETYPE'} eq 'PICK') {
				$INV2->uuidinvcmd($item->{'uuid'},"PICK/ITEM-CANCEL","NOTE"=>"Cancelled PICK","*LM"=>$LM);				
				}
			elsif ($rowis->{'BASETYPE'} eq 'DONE') {
				## try and figure out how we can add this back into inventory
				$INV2->uuidinvcmd($item->{'uuid'},"DONE/ITEM-CANCEL","ORDERID"=>$self->oid(),"~ROUTE"=>"SIMPLE","NOTE"=>sprintf("from %s",$self->oid()),"*LM"=>$LM);
				$self->add_history(
					sprintf("Cancel returned %d $item->{'sku'} to SIMPLE (result:%s)",$rowis->{'QTY'},($LM->has_win()?"success":"failed")),
					'is'=>(not $LM->has_win()?['status']:['error'])
					);
				}
			elsif ($rowis->{'BASETYPE'} eq 'BACKORDER') {
				$INV2->uuidinvcmd($item->{'uuid'},"BACKORDER/ITEM-CANCEL","ORDERID"=>$self->oid(),"NOTE"=>"Cancelled BACKORDER","*LM"=>$LM);
				$self->add_history(
					sprintf("PREORDER $item->{'sku'} %s",($LM->has_win()?"cancelled":"cancel failed")),
					'is'=>(not $LM->has_win()?['status','error']:['status'])
					);
				}
 			elsif ($rowis->{'BASETYPE'} eq 'PREORDER') {
				$INV2->uuidinvcmd($item->{'uuid'},"PREORDER/ITEM-CANCEL","ORDERID"=>$self->oid(),"NOTE"=>"Cancelled PREORDER","*LM"=>$LM);
				$self->add_history(
					sprintf("PREORDER $item->{'sku'} %s",($LM->has_win()?"cancelled":"cancel failed")),
					'is'=>(not $LM->has_win()?['status','error']:['status'])
					);
				}
			elsif ($rowis->{'BASETYPE'} eq 'UNPAID') {
				$INV2->uuidinvcmd($item->{'uuid'},"UNPAID/ITEM-CANCEL","ORDERID"=>$self->oid(),"NOTE"=>"Cancelled UNPAID","*LM"=>$LM);
				$self->add_history(
					sprintf("PREORDER $item->{'sku'} %s",($LM->has_win()?"cancelled":"cancel failed")),
					'is'=>(not $LM->has_win()?['status','error']:['status'])
					);
				}
			else {
				$INV2->skuinvcmd($item->{'uuid'},"ERROR/INIT","ORDERID"=>$self->oid(),"NOTE"=>sprintf("cancelled sku in unknown status %s from order %s",$rowis->{'BASETYPE'},$self->oid()));
				}
		
			## Flag external items as complete w/o feedback.
			## if the item is an external item
			if (int($self->{'claim'})>0) {
				my ($claim) = $self->{'claim'};
				&EXTERNAL::update_stage($self->username(),$claim,'C','N',$self->{'order_id'});
				$self->add_history("Updated claim $claim to Completed without Feedback",etype=>32);
				}
			#elsif (index($stid,'*')>=0) {
			#	my ($claim,$prod) = split(/\*/,$stid);
			#	&EXTERNAL::update_stage($self->username(),$claim,'C','N',$self->{'order_id'});
			#	$self->add_history("Updated claim $claim to Completed without Feedback",etype=>32);
			#	}
			}
		
		$self->__SET__('flow/cancelled_ts',time());
		$self->queue_event('cancel');			
		$self->strip_payment();
		$INV2->sync();
		}
	else	{
		$self->add_history('Loopback detection: Cannot cancel an item a second time!',etype=>4);
		}

#	if (1) {
#		}
#	elsif (int($self->__GET__('flow/buysafe_notified_ts'))>0) {
#		require PLUGIN::BUYSAFE;
#		&PLUGIN::BUYSAFE::SetShoppingCartCancelOrder($self);
#		$self->add_history("Notified buysafe of order cancellation",etype=>1);
#		}

	}


##
## returns a list of open tickets associated with an order.
##
sub tickets {
	my ($self,%options) = @_;

	my @RESULTS = ();
	my $USERNAME = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = $self->mid();
	my $pstmt = "select TKTCODE,STATUS,CREATED_GMT,CLOSED_GMT from TICKETS where MID=$MID /* $USERNAME */ and ORDERID=".$udbh->quote($self->oid());
	# print STDERR "$pstmt\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $ticketref = $sth->fetchrow_hashref() ) {
		push @RESULTS, $ticketref;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@RESULTS);
	}





##
## note: this is included for posterity, don't actually use it unless you
## want to suffer the consequences.
##
sub reset_order_id {
	my ($USERNAME, $VALUE) = @_;
	
	$VALUE = int($VALUE);
	if ($VALUE==0) { $VALUE = 1000; }
	if ($VALUE>999999) { $VALUE = 1000; }
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "update ORDER_COUNTERS set COUNTER=$VALUE,LAST_PID=0,LAST_SERVER='reset' where MID=$MID limit 1";
	my $dbh = &DBINFO::db_user_connect($USERNAME);
	$dbh->do($pstmt);
	&DBINFO::db_user_close();
	return();
	}




##
##
##
sub elastic_index {
	my	($self,%options) = @_;

	my $USERNAME = $self->username();
	my $OID = $self->oid();


	my @ES_PAYLOADS = ();
	if (1) {
		my %properties = ();
		#foreach my $group ('flow','our','mkt','this') {
		#	next if (not defined $self->{"%$group"});
		#	foreach my $k (keys %{$self->{"%$group"}}) {
		#		$properties{"$group/$k"} = $self->{"%$group"}->{$k};
		#		}
		#	}
		#print "OID: $OID.order\n";

		my @REFERENCES = ();
		# push @REFERENCES, $self->oid();		## no, include 'orderid'
		foreach my $item (@{$self->stuff2()->items()}) {
			if ($item->{'mktid'}) {
				push @REFERENCES, $item->{'mktid'};
				if (index('-',$item->{'mktid'})) {
					foreach my $id (split(/-/,$item->{'mktid'})) {
						next if ($id eq '');
						push @REFERENCES, $id;
						}
					}
				}
			}

		foreach my $k (keys %CART2::VALID_FIELDS) {
			my $ref = $CART2::VALID_FIELDS{ $k };
			if (not defined $ref->{'es'}) {
				## no index for you!
				}
			elsif (substr($ref->{'es'},0,1) eq '*') {
				if ($self->in_get($k) eq '') {
					## blank field, skip it.
					}
				elsif ($ref->{'es'} eq '*REFERENCE') {
					push @REFERENCES, $self->__GET__($k);				
					}
				}
			elsif (not defined $self->in_get($k)) {
				}
			elsif (index($ref->{'es'},'/')>=0) {
				}
			elsif ($k eq 'flow/flags') {
				my @FLAGS = ();
				my $val = $self->__GET__($k);
				push @FLAGS, ($val&1)?'SINGLE_ITEM':'MULTI_ITEM';
				push @FLAGS, ($val&2)?'SHIP_EXPEDITED':'SHIP_GROUND';
				push @FLAGS, ($val&4)?'CUSTOMER_NEW':'CUSTOMER_REPEAT';
				push @FLAGS, ($val&8)?'WAS_SPLIT':'NOT_SPLIT';
				if ($val&16) {
					push @FLAGS, ($val&16)?'SPLIT_RESULT':'';
					}
				push @FLAGS, ($val&32)?'PAYMENT_SINGLE':'PAYMENT_MULTI';
				if ($val&64) {
					push @FLAGS, ($val&64)?'IS_SUPPLYCHAIN':'';
					}
				push @FLAGS, ($val&128)?'IS_MULTIBOX':'IS_SINGLEBOX';
				push @FLAGS, ($val&256)?'HAS_RMA':'NOT_RMA';
				push @FLAGS, ($val&512)?'HAS_EDIT':'NOT_EDIT';
				$properties{'flags'} = \@FLAGS;
				}
			elsif ($ref->{'format'} eq 'date') {
				if ($self->__GET__($k)>0) {
					$properties{$ref->{'es'}} = &ZTOOLKIT::elastic_datetime($self->__GET__($k));
					}
				}
			elsif ($ref->{'format'} eq 'intamt') {
				$properties{$ref->{'es'}} = sprintf("%d",$self->__GET__($k)*100);
				}
			else {	
				$properties{$ref->{'es'}} = sprintf("%s",$self->__GET__($k));
				}
			}
		if (not defined $properties{'email'}) { $properties{'email'} = $self->__GET__('bill/email'); }
		if (not defined $properties{'fullname'}) { $properties{'fullname'} = sprintf("%s %s",$self->__GET__('bill/firstname'),$self->__GET__('bill/lastname')); }

		if (not defined $properties{'ip_address'}) {
			}
		elsif ($properties{'ip_address'} =~ /^[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}$/) {
			## format: 1.2.3.4
			}
		elsif (index(',',$properties{'ip_address'})) {
			$properties{'ip_address'} =~ s/[\s]+//gs;
			my @IPS= split(/,/,$properties{'ip_address'});
			$properties{'ip_address'} = \@IPS;			
			}
						
		if (scalar(@REFERENCES)) {
			$properties{'references'} = \@REFERENCES;
			}

		push @ES_PAYLOADS, 
			{
			type              => "order",
			id                => "$OID",
			'source'=>\%properties,	# was 'data' in elastic 0.xx
			};
		}
	

	if (1) {
		foreach my $group ('ship','bill') {
			my %properties = ();
			$properties{'type'} = $group;
			# $properties{'_parent'} = $self->oid();
			foreach my $k (keys %{$self->{"%$group"}}) {
				my $ref = $CART2::VALID_FIELDS{ "$group/$k" };
				if ($ref->{'es'}) {
					$properties{"$k"} = $self->in_get("$group/$k");
					}
				}
			if ($properties{'phone'}) {
				$properties{'phone'} =~ s/[^\d]+//gs;	# strip non-numeric
				if (substr($properties{'phone'},0,1) eq '1') {
					$properties{'phone'} = substr($properties{'phone'},1);	# strip leading 1 from phone number
					}
				if (length($properties{'phone'})==10) {
					$properties{'phone'} = substr($properties{'phone'},0,3).'-'.substr($properties{'phone'},3,3).'-'.substr($properties{'phone'},6,4);
					}
				}
			# print "ADDRESS: $OID.$group\n";
			push @ES_PAYLOADS, 
				{
				type              => "order/address",
				id                => "$OID.$group",
				parent => "$OID",
				'source'=>\%properties, # was 'data' in elastic 0.xx
				};
			}
		}

	if (1) {
		foreach my $item (@{$self->stuff2()->items()}) {
			my %properties = ();
			if (not defined $item->{'uuid'}) { $item->{'uuid'} = $item->{'stid'}; }
			$properties{'sku'} = $item->{'sku'};
			$properties{'price'} = sprintf("%d",$item->{'price'}*100);
			$properties{'qty'} = sprintf("%d",$item->{'qty'}*100);

			$properties{'mkt'} = sprintf("%s",$item->{'mkt'});
			$properties{'mktid'} = $item->{'mktid'};
			$properties{'mktuser'} = $item->{'mktuser'};

			push @ES_PAYLOADS,
				{
				type              => "order/item",
				id                => "$OID.$item->{'uuid'}",
				parent => "$OID",
				'source'=>\%properties, # was 'data' in elastic 0.xx
				};
			}
		}


	if (1) {
		foreach my $payment (@{$self->payments()}) {
			next unless ($payment->{'acct'} ne '');		## only index payments which have acct info

			# print "PAYMENT: $OID.payment.$payment->{'uuid'}\n";
			# print Dumper($payment);
			my %store = ();
			&ZPAY::unpackit($payment->{'acct'},\%store);
			foreach my $k ('uuid','txn','amt','auth') {
				$store{$k} = sprintf("%s",$payment->{$k});
				}

			if (defined $store{'C4'}) {}
			elsif (defined $store{'CM'}) { $store{'C4'} = substr($store{'CM'},-4); }
			elsif (defined $store{'CC'}) { $store{'CC'} = substr($store{'CC'},-4); }

			push @ES_PAYLOADS, 
				{
				type              => "order/payment",
				id                => "$OID.$payment->{'uuid'}",
				parent => "$OID",
				'source'=>\%store,	# was 'data' in elastic 0.xx
				};
			}
		}

	if (1) {
		my $i = 0;
		foreach my $shipment (@{$self->tracking()}) {
			# print "SHIPMENT: $OID.$i\n";
			my %store = ();
			$store{'track'} = sprintf("%s",$shipment->{'track'});
			$store{'carrier'} = sprintf("%s",$shipment->{'carrier'});
			$store{'luser'} = sprintf("%s",$shipment->{'luser'});
			if ($shipment->{'created'}>0) {
				$store{'created'} = &ZTOOLKIT::elastic_datetime($shipment->{'created'});
				}
			$i++;
		   push @ES_PAYLOADS,
				{
				type              => "order/shipment",
				id                => "$OID.$i",
				parent => "$OID",
				'source'=>\%store, # was 'data' in elastic 0.xx
				};
			}
		}


	
	print STDERR "ELASTIC START $USERNAME $OID\n";
	my ($es) = $options{'*es'};
	if (not defined $es) { $es = &ZOOVY::getElasticSearch($USERNAME); }
	if ($options{'reset'}) {
		$es->delete_by_query();
		$es->delete(
			parent => 1,
			);
		}


	my $bulk = Elasticsearch::Bulk->new('es'=>$es,'index'=>lc("$USERNAME.private"));
	if (defined $bulk) {
		## ES requires we specify a command ex: 'index'
		# my @ES_BULK_ACTIONS = ();
		foreach my $payload (@ES_PAYLOADS) {
			## print Dumper($payload)."\n";
			$bulk->index($payload);	
			# push @ES_BULK_ACTIONS, { 'index'=>$payload };
			}
		$bulk->flush();	## I ReALLY CANT STRESS HOW IMPORTANT THIS IS!!!
		}

	print STDERR "ELASTIC -STOP $USERNAME $OID\n";
	return(0);
	}




##
## Call this to set the orders SYNCED_GMT
##
##	note: eventually we might actually want to try and add a log here!
##
sub synced {
	my ($self) = @_;

	my $USERNAME = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($TB) = &DBINFO::resolve_orders_tb($USERNAME,$MID);
	my $qtOID = $udbh->quote($self->oid());
	my $pstmt = "update $TB set SYNCED_GMT=".time()." where MID=$MID /* $USERNAME */ and ORDERID=$qtOID";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	}	







##
##
sub TO_JSON {
	my ($self) = @_;

	## hmm.. this TO_JSON was an old function that is no longer used, well.. at least the format is no longer used
	return($self->jsonify());

	my %O = %{Clone::clone($self)};
	$O{'@ITEMS'} = $self->stuff2()->TO_JSON();
	delete $O{'*stuff2'};

	return(\%O);
	}



##
## so packages are items which will be shipped together, they contain one or more uuids 
##		which correspond to uuid's in the order.  
##		each uuid receives a corresponding package id. 
##
##		@PACKAGES = (
##			{ 'id'=>groupid1, @ITEMS=>[ uuid1a,uuid1b,uuid1c ], 'dsn'=>'', '@rates'=>[ {} ] },
##			{ 'id'=>groupid2, @ITEMS=>[ uuid2a,uuid2b ], 'dsn'=>'', '@rates'=>[ {} ] },
##			)
##
sub packages {
 	my ($self) = @_;
	if (not defined $self->{'@PACKAGES'}) { $self->{'@PACKAGES'} = []; }
	return($self->{'@PACKAGES'});	
	}



#######################################################################################
##
## Universal ship is a new call that lets us simply "pass it and forget it" -- we don't care about intracies such as
##		is it international, domestic, etc. 
##	This code should handle the "virtual calls"
##	This code should handle the handling and insurance since so much of that logic is redundant it doesn't make sense to maintain
##		it in two different locations (domestic_ship, and international_ship)
## This also formats the cart with the proper shipping values .. 
##
## NOTE: ideally this would *ONLY* be called from the following applications:
##		CART->shipping()
##
## in universal ship for virtualization the process goes like this:
##		preserve original stuff
##		go through items, 
##			assemble into hashref keyed by "virtual" value = stuff items
##			assemble another hashref of virtual providers and api urls
##			virtual->{''} is the zoovy (non-virtual)
##		set cart.property "ship.virtual"
##		iterate through virtual providers
##			next if blank provider ($virtual->{''})
##			re-calc totals for cart
##			call ZSHIP::EXTERNAL
##		map cart stuff to virtual->{''}
##		process domestic/international
##		replace original stuff in CART 
##
#sub universal_shipping {
#	my ($self) = @_;
#
#	return(\@RESULTS);
#	}








##############################################################################
## NON-OO below here!
##############################################################################


sub nuke_order {
	my ($USERNAME,$ORDER_ID) = @_;

#	my $ORDERDIR = "ORDERS/".(substr($ORDER_ID,0,rindex($ORDER_ID,'-')));
#	my $THIS_ID = substr($ORDER_ID,rindex($ORDER_ID,'-')+1);

	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &DBINFO::resolve_orders_tb($USERNAME,$MID);

	my $qtORDERID = $odbh->quote($ORDER_ID);
	my $pstmt = "select SYNCED_GMT from $TB where MID=$MID /* $USERNAME */ and ORDERID=$qtORDERID";
	# print "$pstmt\n";
	my ($SYNCED_GMT) = $odbh->selectrow_array($pstmt);

	#if ($SYNCED_GMT==0) {
	#	my ($o) = ORDER->new($USERNAME,$ORDER_ID);
	#	if ($o->lock()) {
	#		$SYNCED_GMT = 1;
	#		}
	#	}
	

	if ($SYNCED_GMT==0) {
		## safe to delete
		my $pstmt = "delete from $TB where  ORDERID=$qtORDERID and MID=$MID /* $USERNAME */ and SYNCED_GMT=0 limit 1";
		$odbh->do($pstmt);
		}
	&DBINFO::db_user_close();

	# my $RESULT = 0;
	# my $path = &ZOOVY::resolve_userpath_zfs1($USERNAME);
	# if (defined $path) { unlink("$path/$ORDERDIR/$THIS_ID.bin") }
	# should I unlike the orders file? and possibly search the customer
	# and annihiliate the bastard??

	return($SYNCED_GMT);
	}











1;







