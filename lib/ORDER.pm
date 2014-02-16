package ORDER;

use Math::BigInt;
use bignum;

##
## @INVENTORY = [
##		{ txn=>'2012011234', stid=>'', sku=>'abc', qty=>'1', supplier=>'xyz', notes=>'', debug=>'', confirmed=>'', track=>'FDX=12234|XYZ=1234' },
##		{ txn=>'2012011234', stid=>'', sku=>'xyz', qty=>'2', supplier=>'xyz', notes=>'', debug=>'', confirmed=>'', track=>'' },
##		];
##

##
##
##	checkout_info fields:
##		old_payby
##		old_shipmethod
## 	ins_optional, ins_purchased, ins_total, ins_quote
##		old_ins_purchased

## bill_to_ship
##	cod
## keepcart
##	shipping_residential
## shipmethod
## email_update

## password, new_password, new_password2, password_hint  (integer, represents hint #)
## payby	
##	- CREDIT:card_number,card_exp_month,card_exp_year,card_cvvcid,
##	- PO: po_number
##	- ECHECK: echeck_bank_name, echeck_bank_state, echeck_aba_number, echeck_acct_number, echeck_acct_name, echeck_check_number
##	- COD
##	- CHKOD
## orderid
## resultmessage
## order_total
## order_subtotal
## shp_total
## tax_total
## meta
## batchid	- varchar(8) - an internal grouping code for the order to be processed within
##


##
## ORDER "FLAGS" COLUMN: flags
# 1 1<<0 = true if +1 items in order (at creation)
# 2 1<<1 = true if high priority shipping  (based on known PRIORITY carrier codes)
# 4 1<<2 = true if repeat customer  
# 8 1<<3 = true if order was *involved* in a split.
# 16 1<<4 = true if split-result (new orders will get this set)
# 32 1<<5 = true if order has multiple payments    (not supported yet)
# 64 1<<6 = true if one or more items has a supply chain (virtual) item. 
# 128 1<<7 = true if multiple shipments           -- a flag set when shipping
# 256 1<<8 = true if one or more items returned   -- to be implemented
# 512 1<<9 = true if the order was edited by merchant
# 1024 1<<10 = one or more items is backordered
# 2048 1<<11 = user set "high priority" bit
# 4096 1<<12 = order was on the 'a' side of a/b test
# 8192 1<<13 = order was on the 'b' side of a/b test
# 4096+8192 (1+2)<<12 = multivarsite was set, but not to 'A' or 'B'
# 16384 1<<14 = order is a gift order (does not print out prices)
# 
# 
# VALUE=VALUE+1
# VALUE=VALUE|(1<<1);
#

## payments
##		an array of:
##		{ uuid=>"", txn=>"", tender=>"", ts=>time, amt=>1.00, note=>"" }
##	the sum of all amt=> becomes paid_total   (and  order_total - balancedue_total)





## login, create_customer
## suggestions	(don't understand - possible: ignore)

## bill_to_ship
## bill_country	ship_country
## bill_state	ship_state
## bill_zip	ship_zip
## bill_firstname	ship_firstname
## bill_lastname	ship_lastname
## bill_address1	ship_address1
## bill_address2	ship_address2
## bill_phone bill_email

## ip_address
##
##
##

use warnings;
no warnings 'once';
no warnings 'redefine';
use strict;
use POSIX;

#use lib '/usr/local/src/CPAN-20120615/YAML-Syck-1.20/lib/';
use YAML::Syck;
require PRODUCT;
# use YAML::XS;

require Storable;
require Data::Dumper;
require Data::GUID;
require Digest::MD5;

use lib '/backend/lib';
require STUFF;
require ZTOOLKIT;
require ZOOVY;
require DBINFO;
require CUSTOMER;
require CUSTOMER::ADDRESS;
require ZWEBSITE;
require ZSHIP;
require ZPAY;
sub def { &ZTOOLKIT::def(@_); }
sub gnum { &ZTOOLKIT::gnum(@_); }
sub pint { &ZTOOLKIT::pint(@_); }
sub bool { &ZTOOLKIT::bool(@_); }
sub cashy { &ZTOOLKIT::cashy(@_); }

$::DEBUG_VERSION = &ZOOVY::servername();
if (not defined $::DEBUG_VERSION) { $::DEBUG_VERSION = ''; }
$::DEBUG_VERSION .= '.1a';


##
##
##
sub TO_JSON {
	my ($self) = @_;

	my %O = %{Clone::clone($self)};
#	Clone::clone($self->item($stid));
#
#	foreach my $stid ($self->stids()) {
#		my $i = Clone::clone($self->item($stid));
#		delete $i->{'full_product'}->{'zoovy:base_cost'};
#		delete $i->{'full_product'}->{'zoovy:pogs'};
#		#$i->{'pogs'} = $i->{'%attribs'}->{'zoovy:pogs'};
#		#delete $i->{'%attribs'}->{'zoovy:pogs'};
#		#if ($i->{'pogs'} ne '') {
#		#	#my @pogs = &POGS::text_to_struct("", $i->{'full_product'}->{'zoovy:pogs'}, 1);
#		#	#$i->{'@pogs'} = \@pogs;
#		#	my @pogs = &POGS::text_to_struct("", $i->{'pogs'}, 0);
#		#	$i->{'@pogs'} = \@pogs;
#		#	delete $i->{'pogs'};
#		#	}
#
#		delete $i->{'%attribs'}->{'zoovy:pogs'};
#		$i->{'*pogs'} = $i->{'@pogs'};
#		delete $i->{'@pogs'};
#		
#		push @r, $i;
#		}
	return(\%O);
	}



# perl -e 'use lib "/backend/lib"; use ORDER; my ($o) = ORDER->new("toynk","2012-05-665160"); $o->elastic_index();'
#sub elastic_index {
#	my ($self, $es) = @_;
#
#	my $USERNAME = lc($self->username());
#	if (not defined $es) {
#		($es) = &ZOOVY::getElasticSearch($USERNAME);
#		}
#
#	my %store = ();
#	$store{'oid'} = $self->oid();
#	$store{'customer'} = $self->customerid();
#	$store{'pool'} = $self->pool();
##	$store{'mkts'} = \@MKTS;
##	$store{'payment_methods'} = \@PAY_METHODS;
##	$store{'payment_tokens'} = \@PAY_TOKENS;
##	$store{'shipping_methods'} = \@SHIP_METHODS;
##	$store{'tracking_methods'} = \@TRACKING_METHODS;
##	$store{'flags'} = \@FLAGS;
#	$store{'order_total'} = sprintf("%d",$self->get_attrib('order_total')*100);
#	$store{'shipping_total'} = sprintf("%d",$self->get_attrib('shp_total')*100);
##	$store{'date_created'} =  #
#	$store{'date_shipped'} =  
#	$store{'date_paid'} =  
#	if (defined $self->get_attrib('ip_address')) {
#		$store{'ip'} = $self->get_attrib('ip_address');
#		}
#
#	my @ADDRESSES = ();
#	foreach my $type ('bill','ship') {
#		push @ADDRESSES, {
#			'type'=> ($type eq 'bill')?'B':'S',
#			'first_name'=>$self->get_attrib("$type\_firstname"),
#			'last_name'=>$self->get_attrib("$type\_lastname"),
#			'address'=>sprintf("%s %s",$self->get_attrib("$type\_address1"),$self->get_attrib("$type\_address2")),
#			'city'=>$self->get_attrib("$type\_city"),
#			'state'=>$self->get_attrib("$type\_state"),
#			'zip'=>$self->get_attrib("$type\_zip"),
#			};
#		};
#	$store{'order_addresses'} = \@ADDRESSES;
#
#	my @PAYMENTS = ();
#	foreach my $payrec (@{$self->payments()}) {
#		push @PAYMENTS, {
#			# $payrec->{'created_date'} = 
#			'ps' => $payrec->{'ps'},
#			'txn' => $payrec->{'txn'},
#			'acct' => $payrec->{'acct'},
#			'created_date'=>'asdf',
#			};
#		}
#	$store{'order_payments'} = \@PAYMENTS;
#	
##	$store{'date_created'} = strftime("%Y-%m-%d",
#
#	my @TRACKING = ();
#	foreach my $tref (@{$self->tracking()}) {
#		push @TRACKING, {
#			'carrier'=>$tref->{'carrier'},
#			'track'=>$tref->{'track'},
#			# 'created_date'=> $tref->{'created'}
#			};
#		}
#	$store{'order_tracking'} = \@TRACKING;
#
#	my @STUFF = ();
#	foreach my $stid ($self->stuff()->stids()) {
#		my ($item) = $self->stuff()->item($stid);
#		push @STUFF, {
#			'sku'=>$item->{'sku'},
#			'qty'=>$item->{'qty'},
#			'mktid'=>$item->{'mktid'}
#			};
#		}
#	$store{'order_stuff'} = \@STUFF;
#
#	print Dumper(\%store);
#	
#   my $result = $es->index(
#		index				 => "$USERNAME.private",
#		type				  => "order",
#		id					 => $self->oid(),
#		data=>\%store
#		);
#	print Dumper($result);
#
#	}
#
#

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
## returns a stat-set for 
##
#sub kpistats {
#	my ($self) = @_;
#
#	require KPIBI;
#
#	my ($ts) = $self->get_attrib('created');
#	my @set = ();
#	my $stuff = $self->stuff();
#	## Overall sales
#	push @set, [ '=', 'OGMS', $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#	$self->{'data'}->{'flags'} = sprintf("%d",$self->{'data'}->{'flags'});
#
#	if ($self->{'data'}->{'flags'} & (1<<1)) {
#		## Expedited shipping
#		push @set, [ '=', "OEXP", $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#		}
#	if ($self->{'data'}->{'flags'} & (1<<2)) {
#		## repeat sales
#		push @set, [ '=', "ORPT", $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#		}
#	if ($self->{'data'}->{'flags'} & (1<<14)) {
#		## repeat sales
#		push @set, [ '=', "OGFT", $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#		}
#
#	if ($self->{'data'}->{'ship_country'} ne '') {
#		## International
#		push @set, [ '=', "OINT", $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#		}
#	## Partition
#	push @set, [ '=PRT', sprintf("%02X",$self->prt()), $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#	
#
#	## Sdomain
#	if (my $sdomain = $self->get_attrib('sdomain')) {
#		push @set, [ '~D', $sdomain, $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#		}
#	## Wholesale Schedule
#	if (my $schedule = $self->get_attrib('schedule')) {
#		push @set, [ '$W', $schedule, $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#		}
#
#	## Marketplace
#	my $mkts = $self->get_attrib('mkts');
#	my $is_web = 1;
#	my $affiliate = $self->get_attrib('meta');
#	if ($mkts ne '') {
#		my @BITS = @{&ZOOVY::bitstr_bits($mkts)};
#		foreach my $bit (@BITS) {
#			my $sref = &ZOOVY::fetch_integration('id'=>$bit);
#
#			if ($sref->{'grp'} eq '') {}
#			elsif ($sref->{'grp'} ne 'WEB') { $is_web = 0; }
#
#			my $dst = $sref->{'dst'};
#			push @set, [ '=', "S$dst", $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#
#			## if it's a known destination, then don't track it as an affiliate
#			if (not defined $sref->{'meta'}) {}
#			elsif ($sref->{'meta'} eq $affiliate) { $affiliate = ''; }
#			}
#		}
#
#	## affiliate sales
#	if ($affiliate) {
#		push @set, [ '$A', $affiliate, $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#		}
#
#	if ($is_web) {
#		## website sale (this is kinda tricky to figure out)	
#		## a special track for "web" sources
#		push @set, [ '=', "OWEB", $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#		if ($self->{'data'}->{'multivarsite'} ne '') {
#			## track multivarsite A/B/C
#			if ($self->{'data'}->{'multivarsite'} eq 'A') {
#				push @set, [ '=PRA', sprintf("%02X",$self->prt()), $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#				}
#			elsif ($self->{'data'}->{'multivarsite'} eq 'B') {
#				push @set, [ '=PRB', sprintf("%02X",$self->prt()), $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#				}
#			elsif ($self->{'data'}->{'multivarsite'} ne '') {
#				push @set, [ '=PRC', sprintf("%02X",$self->prt()), $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#				}
#			}
#		}
#
#
#	#if (my $mkt = $o->get_attrib('mkt')) {
#	#	push @set, [ '$S', $mkt
#	#	}
#	foreach my $stid ($stuff->stids()) {
#		my $item = $stuff->item($stid);
#		if (substr($stid,0,1) eq '%') {
#			## this is a coupon
#			push @set, [ '$C', $stid, $ts, $self->get_attrib('order_total'), 1, $stuff->count(1) ];
#			}
#		if (my $SUPPLIER = $item->{'%attribs'}->{'zoovy:prod_supplier'}) {
#			## Supplier
#			push @set, [ '~Q', $SUPPLIER, $ts, $item->{'extended'}, 1, $item->{'qty'} ];
#			}
#		if (my $MFG = $item->{'%attribs'}->{'zoovy:prod_mfg'}) {
#			## Manufacturer
#			push @set, [ '~M', $MFG, $ts, $item->{'extended'}, 1, $item->{'qty'} ];
#			}
#
#		if (not defined $item->{'%attribs'}) {}
#		elsif (not defined $item->{'%attribs'}->{'zoovy:prod_is'}) {}
#		elsif ((my $prodis = int($item->{'%attribs'}->{'zoovy:prod_is'})) > 0) {
#			## PROD_IS fields
#			foreach my $ref (@ZOOVY::PROD_IS) {
#				if (($prodis & (1<<$ref->{'bit'}))>0) {
#					push @set, [ '=PIS', sprintf("%02X",$ref->{'bit'}), $ts, $item->{'extended'}, 1, $item->{'qty'} ];
#					}
#				}
#			}
#		}
#	return(\@set);
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


##
## %filter can be 'grp' or 'id' ex: EBA or WEB
##
sub is_origin {
	my ($self,%filter) = @_;
	my $mkts = $self->get_attrib('mkts');
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
	elsif ($self->get_attrib('sdomain') =~ /^(ebay|amazon|buy|sears|hsn|newegg)\.com$/) {
		## well known marketplaces
		if ($filter{'WEB'}) { return(0); }
		}
	else {
		if ($filter{'WEB'}) { return(2); }
		}

	return($matches);
	}

sub is_paidinfull {
	my ($self) = @_;
   return(   
		(substr($self->{'data'}->{'payment_status'},0,1) eq '0')?1:0 
		);
   }


sub expandyyyymm {
	my ($rym) = @_;

	my $yyyymm = 0;
	$rym = &ZTOOLKIT::unbase36($rym);

	my $mm = $rym & 15;
	$rym = $rym >> 4;
	$rym+= 2000;
	$yyyymm = sprintf("%04d-%02d",$rym,$mm);

	return($yyyymm);
	}

sub db_save {
	my ($self,$options) = @_;
	require ORDER::DBNATIVE;
	return(&ORDER::DBNATIVE::db_save($self,$options));
	}

sub db_load {
	my ($class, $ORDER_ID) = @_;

	my $self = {};
	bless $self, 'ORDER';
	my $error = undef;

	require ORDER::DBNATIVE;
	($self,$error) = &ORDER::DBNATIVE::db_load($self,$ORDER_ID);
	
	return($self,$error);
	}


##
## intended to be called within the event framework.
##
sub e_get {
	my ($self, $property) = @_;

	my $result = undef;
	$property = lc($property);
	if ($property =~ /^data.(.*?)$/) {
		$result = $self->get_attrib($1);
		}
	elsif ($property =~ /^stuff\:\:stids$/) {
		$result = join(",",$self->stuff()->stids());
		}
	elsif ($property =~ /^stuff\:\:stid\[(.*?)\]\:\:(.*?)$/) {
		my ($stid,$property) = ($1,$2);
		my $item = $self->stuff()->item(uc($stid));
		$result = $item->{$property};
		}

	return($result);
	}


##
## returns a set of formatted variables suitable for interpolation into html or text
##
sub addr_vars {
	my ($self, $type) = @_;

	my $hashref = $self->attribs();
	my %vars = ();
	$vars{'%FULLNAME%'} = $hashref->{$type.'_firstname'}.' '.$hashref->{$type.'_lastname'};
	$vars{'%COMPANY%'} = '';
	$vars{'%ADDR1%'} = $hashref->{$type.'_address1'};
	$vars{'%ADDR2%'} = $hashref->{$type.'_address2'};

	## City, State, Country
	$vars{'%ADDRCSZ%'} = '';


	my $country = $hashref->{$type.'_country'};
	if (not defined $country) { $country = ''; }
	if ($country eq 'United States') { $country = ''; }
	elsif ($country eq 'US') { $country = ''; }
	elsif ($country eq 'USA') { $country = ''; }
	if ($country eq '') {
		$vars{'%ADDRCSZ%'} = sprintf("%s, %s %s",$hashref->{$type.'_city'}, $hashref->{$type.'_state'}, $hashref->{$type.'_zip'});
		}
	else {
		$vars{'%ADDRCSZ%'} = sprintf("%s, %s",$hashref->{$type.'_city'},$hashref->{$type.'_province'});
		if ($hashref->{$type.'_int_zip'} ne '') {
			$vars{'%ADDRCSZ%'} .= ' '.$hashref->{$type.'_int_zip'};
			}
		$vars{'%ADDRCSZ%'} .= $hashref->{$type.'_country'}."<br>\n";
		}

	$vars{'%PHONE%'} = '';
	if ($hashref->{$type.'_phone'} ne '') {
		$vars{'%PHONE%'} = $hashref->{$type.'_phone'};
		}

	$vars{'%EMAIL%'} = '';
	if ($hashref->{$type.'_email'} ne '') {
		$vars{'%EMAIL%'} = $hashref->{$type.'_email'};
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

	return(\%vars); 
	}


##
##
##
sub e_set {
	my ($self, $property, $value) = @_;

	if ($property =~ /^data.(.*?)$/) {
		$self->set_attrib($1,$value);
		}
	elsif ($property =~ /^stuff\:\:stid\[(.*?)\]\:\:(.*?)$/) {
		
		}

	}



##
## there is an issue  when google (with it's numerous async callbacks) processes something out of order
##    this works with the googlechkout code to ensure we never go backwards on a notification by using the db
##    id's of the google checkout notifications.
##
sub is_googlecheckout_outoforder {
   my ($self, $GSID) = @_;

	my $last_gsid = $self->get_attrib('google_sequenceid');
	if (not $last_gsid) {
		}
	elsif ($last_gsid > $GSID) {
		$self->event(2+8,"Google appears to be processing out of order - discarding GSID:$GSID since we already did:$last_gsid");
		return(1);
		}

	## this is the proper exit (false)
	$self->set_attrib('google_sequenceid',$GSID);	
	return(0);
   }


sub payment_status { return($_[0]->{'data'}->{'payment_status'}); }
sub payment_method { return($_[0]->{'data'}->{'payment_method'}); }


#############################################################################
##
## options:
## 	is_global_cart=>0
##
## REPLACED BY: CART2->new_from_order
##
#sub as_cart {
#	my ($self, %options) = @_;
#
#	if (not defined $options{'is_global_cart'}) { 
#		$options{'is_global_cart'} = 1; 
#		}
#
#	require CART;
#	$SITE::merchant_id = $self->username();
#
#	my $cart = undef;
#	if ((defined $SITE::CART) && (ref($SITE::CART) eq 'CART')) {
#		## check to see if the global cart, is the same as this order 
#		if ($self->username() ne $SITE::CART->username()) {
#			## make sure we're starting with the same user!
#			## NOTE: eventually we might also compare orderid with chkout.orderid
#			}
#		elsif ($self->get_attrib('cartid') eq $SITE::CART->id()) {
#			## hurrah, we can use the global cart cuz it's the same things as we got.
#			$cart = $SITE::CART;
#			}
#		}
#	if (not defined $cart) {
#		($cart) = CART->new($self->username(),'*','tmp'=>1,order=>$self);
#		}
#
#	## PATCH TO HANDLE BLANK 'product' entry in item (caused by zom i think)
#	foreach my $stid ($self->stuff()->stids()) {
#		next if ($stid eq '');
#		
#		my $item = $self->stuff()->item($stid);
#		if (not defined $item->{'product'}) {
#			($item->{'product'},$item->{'claim'}) = PRODUCT::stid_to_pid($stid);
#			}
#		}
#
#	$cart->save_property('chkout.order_id',$self->oid());
#	## note: in the actual order this is cartid (blah.. but for consistency we're doing _id)
#	$cart->save_property('chkout.cart_id',$self->get_attrib('cartid'));
#	$cart->save_property('chkout.payment_status',$self->get_attrib('payment_status'));
#	$cart->save_property('data.order_total',$self->get_attrib('order_total'));
#
#	if ($options{'is_global_cart'}) {
#		warn "overwriting global cart (you probably ought to do this explicitly!)\n";
#		$SITE::CART = $cart;
#		}
#
#	return($cart);
#	}
#


##############################################################################
##
## CLIENT CAN BE EITHER:
##		WEB/ZOM
##
sub set_lock {
	my ($self, $CLIENT) = @_;

	delete $self->{'lock'};
	$self->{'applock'} = $CLIENT;

	return();
	}

##
## 
##
sub get_lock {
	my ($self) = @_;

	if ((not defined $self->{'applock'}) || ($self->{'applock'} eq '')) {
		$self->{'applock'} = 'WEB';
		}
	return($self->{'applock'});
	}


sub lock { return($_[0]->{'applock'}); }
sub username { return($_[0]->{'username'}); }
sub mid { return(&ZOOVY::resolve_mid($_[0]->{'username'})); }
sub oid { return($_[0]->{'order_id'}); }
sub pool { return($_[0]->{'data'}->{'pool'}); }
sub prt { 
	if (not defined $_[0]->{'data'}->{'prt'}) { $_[0]->{'data'}->{'prt'} = 0; }
	return( int($_[0]->{'data'}->{'prt'}) ); 
	}
sub profile { return($_[0]->{'data'}->{'profile'}); }

## 
## note: set customer_id to undef, or -1 to force a lookup
##
sub customerid { 
	my ($self) = @_;
	##
	## map customer if it exists (duplicated in save())
	##
	my ($cid) = $self->{'data'}->{'customer_id'};
	if (not defined $cid) { $cid = -1; }

	if ($cid>0) {
		## yay!
		}
	elsif (not defined $self->{'data'}->{'bill_email'}) {
		## oh shit, well this won't work!
		$cid = -1;	# we'll try looking it up later!
		}
	elsif (defined $self->{'data'}->{'bill_email'}) {
		## new order, and we don't have a customer to match to, we'll try to do a lookup.
		require CUSTOMER;
		($cid,my $ccreated_gmt) = &CUSTOMER::resolve_customer_info($self->{'username'}, $self->{'data'}->{'prt'},$self->{'data'}->{'bill_email'});
		if (not defined $cid) { $cid = 0; }

		if (($cid>0) && ($ccreated_gmt+86400 < $self->{'data'}->{'created'})) {
			## the customer existed 1 day before this order, so we should flag that it's a repeat customer here.
			$self->{'data'}->{'flags'} |= (1<<2);
			}
		$self->{'data'}->{'customer_id'} = $cid;
		}

	return( $cid );
	}

## returns a customer record associated with an order.
##		use_email=>1
#sub customer {
#	my ($self,%options) = @_;
#
#	my $C = undef;
#	
#	my ($CID) = $self->customerid();
#	if (defined $self->{'*C'}) { 
#		$C = $self->{'*C'};
#		}
#	elsif (($CID<=0) && ($options{'use_email'})) { 
#		## no customer id set in the order, lets do a last chance lookup
#		($CID) = CUSTOMER::resolve_customer_id($self->username(),$self->prt(),$self->get_attrib('bill_email'));
#		if ($CID>0) {
#			## woot, lets save the customer id for next time!
#			$self->set_attrib('customer_id',$CID);	
#			}
#		}
#	if ($CID>0) { 
#		($C) = CUSTOMER->new($self->username(),PRT=>$self->prt(),CID=>$CID,'CREATE'=>0); 
#		}
#
#	return($C);	
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
#                  "ship_company=" + Me.txtShipToCompany.Text + _
#                  "&ship_firstname=" + Me.txtShipToFirst.Text + _
#                        "&ship_lastname=" + Me.txtShipToLast.Text + _
#                        "&ship_phone=" + Me.txtShipToPhone.Text + _
#                        "&ship_address1=" + Me.txtShipToAddress1.Text + _
#                        "&ship_address2=" + Me.txtShipToAddress2.Text + _
#                        "&ship_city=" + Me.txtShipToCity.Text + _
#                        "&ship_country=" + Me.txtShipToCountry.Text + _
#                        "&ship_email=" + Me.txtShipToEmail.Text + _
#                        "&ship_state=" + ShipState + _
#                        "&ship_province=" + shipProvince + _
#                        "&ship_zip=" + ShipZip + _
#                        "&ship_int_zip=" + shipIntZip
##
# EVENTTYPE = "SETBILLADDR"
#                    EVENTPARAMS = "bill_company=" + Me.txtBillToCompany.Text + _
#                        "&bill_firstname=" + Me.txtBillToFirst.Text + _
#                        "&bill_lastname=" + Me.txtBillToLast.Text + _
#                        "&bill_phone=" + Me.txtBillToPhone.Text + _
#                        "&bill_address1=" + Me.txtBillToAddress1.Text + _
#                        "&bill_address2=" + Me.txtBillToAddress2.Text + _
#                        "&bill_city=" + Me.txtBillToCity.Text + _
#                        "&bill_country=" + Me.txtBillToCountry.Text + _
#                        "&bill_email=" + Me.txtBilltoEmail.Text + _
#                        "&bill_state=" + BillState + _
#                        "&bill_province=" + BillProvince + _
#                        "&bill_zip=" + BillZip + _
#                        "&bill_int_zip=" + BillIntZip
#
# SETSHIPPING
# [4:21:14 PM] Becky Horakh says: shp_total=" & String.Format("{0:#######0.00}", CStr(Me.objShip.ZShp_Total)) & _
#                    ", shp_taxable=" & CStr(Me.objShip.ZShp_Tax) & _
#                    ",shp_carrier='" & CStr(Me.objShip.ZShp_Carrier) & "'" & _
#                    ", hnd_total=" & String.Format("{0:#######0.00}", CStr(Me.objShip.Zhnd_Total)) & _
#                    ", hnd_taxable=" & CStr(Me.objShip.Zhnd_Tax) & _
#                    ", ins_total=" & String.Format("{0:#######0.00}", CStr(Me.objShip.Zins_Total)) & _
#                    ", ins_taxable=" & CStr(Me.objShip.Zins_Tax) & _
#                    ", spc_total=" & String.Format("{0:#######0.00}", CStr(Me.objShip.Zspc_Total)) & _
#                    ", spc_taxable=" & CStr(Me.objShip.Zspc_Tax) & _
#
# SETATTRS
#	any attributes 
# SETTAX
#	state_tax_rate local_tax_rate
#
# 


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
#sub run_macro {
#	my ($self, $script) = @_;
#	## previously this ran a macroscript, it seems like it was a better idea to parse the macroscript earlier and pass
#	## in the commands, this gives us insight into the commands *BEFORE* we run them blindly, and this is useful if 
#	## (for example) we need to create an order.
#	my $CMDS = &ORDER::parse_macro_script($script);
#	return($self->run_macro_cmds($CMDS));
#	}


##
## cmds is a parsed arrayref of cmds, one per line
##		[CMD,hashref_of_parameters]
##
##	$params{'is_buyer'} = 0;
##
#sub run_macro_cmds {
#	my ($self, $CMDS, %params) = @_;
#
#	my $errs = 0;
#
#	my ($echo) = 0;
#	my @RESULTS = ();
#	foreach my $CMDSET (@{$CMDS}) {
#		my ($cmd,$pref) = @{$CMDSET};
#		my $result = undef;
#
#		##
#		##  
#		## 
#
#		if ($cmd eq 'SETPOOL') {
#			($result) =	$self->set_attrib('pool',$pref->{'pool'});
#			if (defined $pref->{'subpool'}) { $self->set_attrib('subpool',$pref->{'subpool'}); }
#			$self->event("run_macro set pool to $pref->{'pool'} subpool=$pref->{'subpool'}",$pref->{'ts'},4,$pref->{'luser'});
#			if ($pref->{'pool'} eq 'DELETED') {
#				$self->cancelOrder(LUSER=>$pref->{'luser'});
#				}
#			}
#		elsif ($cmd eq 'SET') {
#			foreach my $key (keys %{$pref}) {
#				my ($val) = $pref->{$key};
#				$self->set_attrib($key,$val);
#				$self->event("run_macro set $key to $val",$pref->{'ts'},4,$pref->{'luser'});
#				}
#			}
#		elsif ($cmd eq 'CAPTURE') {
#			## this will go through and settle any outstanding payments
#			foreach my $payrec (@{$self->payments('can_capture'=>1)}) {
#				$self->event("runmacro capture uuid=$payrec->{'uuid'} ps=$payrec->{'ps'}",0,2,'*MACRO');			
#				($payrec) = $self->process_payment('CAPTURE',$payrec);
#				}
#			$self->recalculate();
#			}
#		#elsif ($cmd eq 'CAPTURE') {
#		#	$echo++;
#		#	require ZPAY;
#		#	my ($payment_status) = $self->get_attrib('payment_status');
#		#	if (substr($payment_status,0,1) eq '0') {
#		#		$self->event("runmacro attempted to capture an already paid order!",time(),2+8,$pref->{'luser'});			
#		#		$self->save();
#		#		}
#		#	elsif (($payment_status!=199) && ($payment_status!=499)) {
#		#		## if we're not 499, 199 (pending settlement) then we need to do a charge!
#		#		my ($result,$msg) = $self->payment('CHARGE');
#		#		}	
#		#	elsif (($payment_status==199) || ($payment_status==499)) {
#		#		## CC CAPTURE
#		#		my ($result,$msg) = $self->payment('CAPTURE');
#		#		}
#		#	elsif (($payment_status==189) || ($payment_status==489)) {
#		#		## PAYPAL CAPTURE
#		#		my ($result,$msg) = $self->payment('CAPTURE');
#		#		}
#		#	else {
#		#		$self->event("runmacro attempted to CAPTURE - not allowed already '".$payment_status."'",time(),2+8);
#		#		$self->save();
#		#		}
#		#	}
#		#elsif ($cmd eq 'REFUND') {
#		#	## deprecated
#		#	$echo++;
#		#	$self->event("runmacro attempt to refund order");
#		#	$self->payment("CREDIT",%{$pref});
#		#	}
#		elsif ($cmd eq 'ADDTRACKING') {
#			$self->set_tracking($pref->{'carrier'},$pref->{'track'},$pref->{'notes'},$pref->{'cost'},$pref->{'actualwt'});
#			$self->event("runmacro set tracking $pref->{'carrier'},$pref->{'track'}",$pref->{'created_ts'},2,$pref->{'luser'});			
#			}
#		elsif ($cmd eq 'ADDEVENT') {
#			$self->event($pref->{'msg'},$pref->{'ts'},$pref->{'etype'},$pref->{'luser'},$pref->{'uuid'});
#			}
#		elsif ($cmd eq 'SETTRACKING') {
#			## this is a more direct call than ADDTRACKING and (in the future) can also update 
#			##		based on the "track" field.
#			$self->set_trackref($pref);
#			}
#		elsif ($cmd eq 'CREATECUSTOMER') {
#			$self->event("runmacro created customer",time(),2);
#			require CUSTOMER;
#			my ($C) = CUSTOMER->new($self->username(),
#				PRT=>$self->prt(),
#				EMAIL=>$self->get_attrib('bill_email'),
#				ORDER=>$self,
#				CREATE=>3,
#				);
#			}
#		elsif ($cmd eq 'SPLITORDER') {
#			}
#		elsif ($cmd eq 'MERGEORDER') {
#			my ($oid) = $pref->{'oid'};
#			# my ($osrc) = ORDER->new($self->username(),$oid,create=>0);
#			my ($csrc) = CART2->new($self->username(),$oid,create=>0);
#			## phase1: copy any tracking, payments, events, and items into the new order.
#			foreach my $e (@{$osrc->history()}) {
#				push @{$self->{'history'}}, $e;
#				}
#			foreach my $p (@{$osrc->payments()}) {
#				## change the UUID to make sure it's unique
#				if ($p->{'uuid'} eq 'ORDERV4') { $p->{'uuid'} = sprintf("%s-%s",$p->{'uuid'},$osrc->oid()); }
#				push @{$self->{'payments'}}, $p;
#				}
#			$osrc->add_payment('ADJUST',
#				sprintf("%.2f",0-$osrc->get_attrib('balance_paid')),
#				note=>sprintf("Payments transferred to oid:%s",$self->oid()),
#				uuid=>$self->oid(),
#				);
#			$osrc->save();
#
#			foreach my $t (@{$osrc->tracking()}) {
#				push @{$self->{'tracking'}}, $t;
#				}
#			my @stids = $osrc->stuff()->stids();
#			foreach my $stid (@stids) {
#				my $item = $osrc->stuff()->item($stid);
#				if (my $existitem = $self->stuff()->item($stid)) {
#					$self->event("item:$stid qty: $existitem->{'qty'} +$item->{'qty'} during merge oid:$pref->{'oid'}");
#					$existitem->{'qty'} += $item->{'qty'};
#					}
#				else {
#					## new item - add it
#					$self->stuff()->recram($item);
#					}
#				}
#			}
#		elsif ($cmd eq 'EMAIL') {
#			$self->email($pref->{'msg'});
#			}
#		elsif ($cmd eq 'ADDNOTE') {
#			my $note = $self->get_attrib('order_notes');
#			$note .= $pref->{'note'};
#			$self->set_attrib('order_notes',$note);
#			}
#		elsif ($cmd eq 'ADDPRIVATE') {
#			my $note = $self->get_attrib('private_notes');
#			$note .= $pref->{'note'};
#			$self->set_attrib('private_notes',$note);
#			}
#		elsif ($cmd eq 'SETBILLADDR') {
#			$self->event("updated billing address",$pref->{'created_ts'},1,$pref->{'luser'});
#			foreach my $k ('bill_company','bill_firstname','bill_lastname','bill_phone','bill_address1','bill_address2','bill_city','bill_state','bill_country','bill_email','bill_state','bill_province','bill_zip','bill_int_zip') {
#				$self->set_attrib($k,$pref->{$k});
#				}
#			}
#		elsif ($cmd eq 'SETSHIPADDR') {
#			$self->event("updated shipping address",$pref->{'created_ts'},1,$pref->{'luser'});
#			foreach my $k ('ship_company','ship_firstname','ship_lastname','ship_phone','ship_address1','ship_address2','ship_city','ship_state','ship_country','ship_email','ship_state','ship_province','ship_zip','ship_int_zip') {
#				$self->set_attrib($k,$pref->{$k});
#				}
#			}
#		elsif ($cmd eq 'SETSHIPPING') {
#			$self->event("updated shipping configuration",$pref->{'created_ts'},1,$pref->{'luser'});
#			foreach my $k ('shp_method','shp_total','shp_taxable','shp_carrier','hnd_method','hnd_total','hnd_taxable','ins_method','ins_total','ins_taxable','spc_method','spc_total','spc_taxable') {
#				if (defined $pref->{$k}) {
#					$self->set_attrib($k,$pref->{$k});
#					}
#				}
#			}
#		elsif ($cmd eq 'SETATTRS') {
#			$self->event("updated order properties",$pref->{'created_ts'},1,$pref->{'luser'});
#			foreach my $k (keys %{$pref}) {
#				next if ($k eq 'luser');  
#				next if ($k eq 'created_ts');
#				$self->set_attrib($k,$pref->{$k});
#				}
#			}
#		elsif ($cmd eq 'SETTAX') {
#			print STDERR Dumper($pref);
#			$self->event("updated tax geometry",$pref->{'created_ts'},1,$pref->{'luser'});
#			foreach my $k ('state_tax_rate','local_tax_rate') {
#				$self->set_attrib($k,$pref->{$k});
#				}
#			}
#		elsif ($cmd eq 'SETSTUFFXML') {
#			## this will overwrite any items which are already here
#			$self->event("updated item geometry",$pref->{'created_ts'},1,$pref->{'luser'});
#			my ($stuff,$errors) = STUFF->new($self->username(),'xml'=>$pref->{'xml'},'xmlcompat'=>$::XCOMPAT);
#			if (defined $errors) {
#				ZOOVY::confess($self->username(),"Unable to parse STUFF sent from ZOM ".Dumper($pref),justkidding=>1);
#				}
#			else {
#				# print STDERR Dumper($pref,$stuff);
#				$self->{'stuff'} = $stuff;
#				}
#			}
##		elsif ($cmd eq 'BUYERADDPAYMENT') {
##			my $AMOUNT = $pref->{'amt'};
##			if ($AMOUNT == 0) {
##				$AMOUNT = $self->get_attrib('balance_due');
##				}
##			elsif ($AMOUNT > $self->get_attrib('balance_due')) {
##				$AMOUNT = $self->get_attrib('balance_due');
##				}
##			
##			my ($payrec) = $self->add_payment($pref->{'tender'},
##				$AMOUNT,
##				'note'=>'Added by Customer after Order was placed',
##				'luser'=>'*CUSTOMER'
##				);
##			$self->process_payment('INIT',$payrec,%{$pref});
##			$self->save();		
##
##			#&ZOOVY::add_event($self->username(),"PAYMENT.UPDATE",
##			#	'ORDERID'=>$self->oid(),
##			#	'PRT'=>$self->prt(),
##			#	'SDOMAIN'=>$SITE::SREF->{'+sdomain'},
##			#	'SRC'=>'Customer Account @ '.$SITE::SREF->{'+sdomain'},
##			#	);
##			}
#		elsif (($cmd eq 'ADDPAYMENT') || ($cmd eq 'ADDPROCESSPAYMENT')) {
#			## tender is a valid type of payment as found in @ZPAY::PAY_METHODS ~line 353
#			## ex: 'CREDIT'
#			## amt is the amount in dollars (this can be set to zero)
#			## other fields are those commonly found in a payment as attrib 
#			## uuid, ts, note  	are common, the default ps is 500 (but can be set to something else ex: 501)		
#			## ADDPROCESSPAYMENT?VERB=INIT&tender=CREDIT&amt=0.20&UUID=&ts=&note=&CC=&CY=&CI=&amt=
#			## look in ZPAY line 14 for the various CC,CM etc. fields
#			my $VERB = undef;
#			if ($cmd eq 'ADDPROCESSPAYMENT') {
#				## this allows becky to make one call - for both "adding" and "processing" which is 
#				## more convenient for her.
#				$VERB = $pref->{'VERB'};
#				delete $pref->{'VERB'};
#				}
#
#			## TODO: amt is a required parameter
#			## TODO: on "ADDPAYMENT" uuid is a required parameter
#
#			if ($cmd eq 'ADDPAYMENT') {
#				## fix uppercase UUID (fixed in version 12)
#				if (defined $pref->{'UUID'}) { $pref->{'uuid'} = $pref->{'UUID'}; delete $pref->{'UUID'}; }
#				## 'amount' fixed in version 12 ( but was released to prod )
#				if (defined $pref->{'amount'}) { $pref->{'amt'} = $pref->{'amount'}; delete $pref->{'amount'}; }
#				}
#
##			open F, ">>/tmp/dump";
##			print F 'PHASE1: '.Dumper($pref)."\n--------------------\n";
##			close F;
#
#			my ($payrec) = $self->add_payment($pref->{'tender'},$pref->{'amt'},%{$pref});
#			if ((defined $VERB) && ($VERB ne '')) {
#				($payrec) = $self->process_payment($VERB,$payrec,%{$pref});
#				}
#
#			$self->recalculate();
#
##			open F, ">>/tmp/dump";
##			print F 'PHASE2: '.Dumper($payrec,$VERB,$pref,$self)."\n--------------------\n";
##			close F;
#
#			}
#		elsif ($cmd eq 'PROCESSPAYMENT') {
#			## this must be passed a VERB and UUID 
#			## VERB=   INIT|AUTHORIZE|CAPTURE|CHARGE|VOID|REFUND
#			## UUID =  the uuid of the payment which was added.
#			## amt= (and any other %payment variables)
#			my $VERB = $pref->{'VERB'};
#			my $UUID = $pref->{'uuid'};
#			## not sure how many requests have uppercase UUID (none should)
#			if ((defined $pref->{'UUID'}) && ($UUID eq '')) { $UUID = $pref->{'UUID'}; }
#			
#			my ($payrec) = $self->payment_by_uuid($UUID);
#			if (defined $payrec) {
#				$self->process_payment($VERB,$payrec,%{$pref});
#				}
#			else {
#				$self->event(sprintf("runmacro received unknown UUID:%s so process payment could not run",$pref->{'UUID'}));
#				}
#			$self->recalculate();
#			}
#		elsif ($cmd eq 'FLAGASPAID') {
#			my $method = $self->get_attrib('payment_method');
#			my $PS = $self->get_attrib('payment_status');
#
#			if ((substr($PS,0,1) eq '1') || (substr($PS,0,1) eq '4')) {
#				foreach my $payrec (@{$self->payments()}) {
#					if (
#						($payrec->{'ps'} eq '109') ||
#						($payrec->{'ps'} eq '189') || ($payrec->{'ps'} eq '199') ||
#						($payrec->{'ps'} eq '489') || ($payrec->{'ps'} eq '499')
#						) {
#						$self->process_payment('CAPTURE',$payrec,{});
#						}
#					elsif (substr($payrec->{'ps'},0,1) eq '1') {
#						if ($payrec->{'tender'} eq 'CASH') { $payrec->{'ps'} = '069'; }
#						elsif ($payrec->{'tender'} eq 'CHECK') { $payrec->{'ps'} = '068'; }
#						elsif ($payrec->{'tender'} eq 'PO') { $payrec->{'ps'} = '067'; }
#						else {
#							$self->event("Non understood pending tender type=$payrec->{'tender'}");				
#							}
#						}
#					else {
#						$self->event("Cannot move from pendign to paid tender=$payrec->{'tender'} ps=$PS");				
#						}
#					}
#				}
#			else {
#				$self->event("Cannot flag as paid ps=$PS");				
#				}
#			}
#		elsif ($cmd eq 'CREATE') {
#			## not sure what this is supposed to do.?!
#			## NOTE: this blocks an error from appearing in the events.
#			}
#		elsif ($cmd eq 'SAVE') {
#			$self->save();
#			}
#		elsif ($cmd eq 'ECHO') {
#			$echo++;
#			}
#		else {
#			$self->event("runmacro unknown command [$cmd]",$pref->{'created_ts'},8,$pref->{'luser'});	
#			$errs++;
#			}
#
#		## RESULTS is an array, first element is ID
#		##		second element is ?
#		if (defined $pref->{'ID'}) {
#			push @RESULTS, [ $pref->{'ID'} ];
#			}
#		}
#
#	if ($errs) {
#		open F, ">>/tmp/macro-debug.txt";
#		print F  Dumper($self->username(),$self->oid(),\@{$CMDS});
#		close F;
#		}
#
#	return($echo);	
#	}


##
## converts macro into cmds array.
##	this is designed to be called *outside* the object (that's useful if for example the first command is CREATE)
##
sub parse_macro_script {
	my ($script) = @_;

	open F, ">/dev/shm/macro-debug.tmp";
	print F $script;
	close F;

	my @CMDS = ();
	foreach my $line (split(/[\n\r]+/,$script)) {
		my ($cmd,$uristr) = split(/\?/,$line,2);
		my $pref = &ZTOOLKIT::parseparams($uristr);		
		if (not defined $pref->{'luser'}) { $pref->{'luser'} = '*MACRO'; }
		if (not defined $pref->{'ts'}) { $pref->{'ts'} = time(); }
		push @CMDS, [ $cmd, $pref ];
		}
	return(\@CMDS);
	}



##
## this tests to see what type of fraud screen the client uses.
##
sub fraud_check {
	my ($self,$payrec,$webdbref) = @_;

	my ($globalref) = &ZWEBSITE::fetch_globalref($self->username());
	#if (not defined $webdbref) {
	#	$webdbref = &ZWEBSITE::fetch_website_dbref($self->username(), $self->prt());
	#	}

	if (not defined $globalref->{'%kount'}) {
		}
	elsif (ref($globalref->{'%kount'}) ne 'HASH') {
		}
	elsif (int($globalref->{'%kount'}->{'enable'})>0) {
		require PLUGIN::KOUNT;
		my ($pk) = PLUGIN::KOUNT->new($self->username(),prt=>$self->prt(),webdb=>$webdbref);
		my ($r) = $pk->doRISRequest($self);
		# AUTO=D&BRND=VISA&GEOX=JP&KAPT=Y&MERC=200090&MODE=Q&NETW=N&ORDR=2010%2d09%2d2640&REAS=SCOR&REGN=JP_17&SCOR=20&SESS=hSxKMI0mOVxKcTSrXktq0Wkm8&TRAN=69HX012LMZN1&VELO=0&VERS=0320&VMAX=0
		my ($zoovyrs) = PLUGIN::KOUNT::RIStoZoovyReviewStatus($r);
		$self->event("Kount RIS[$zoovyrs]: ".&ZTOOLKIT::buildparams($r),undef,4,"*KOUNT");
		$self->set_attrib('review_status',$zoovyrs);
		}
	else {
		## no fraud screen service installed.
		}
	return();
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
## causes events to be dispatched 
##
sub dispatch {
	my ($self, $eventname) = @_;


	$eventname = lc($eventname);
	if (not defined $self->{'@dispatch'}) {
		$self->{'@dispatch'} = [];
		}
		
	my $found = 0;
	foreach my $d (@{$self->{'@dispatch'}}) {
		if ($d->[0] eq $eventname) { $found++; }
		}

	my $ts = time();
	
	if ($self->get_attrib('created') < 1288594800) {
		## ORDERV4 
		$self->event("dispatch $eventname supressed because order is older than 90 days");
		open F, ">>/tmp/dispatch-blocked.sql";
		print F sprintf("%s|%s|%s\n",$self->username(),$self->oid(),$eventname);
		close F;
		$found = -1;
		}
	elsif (not $found) {
		my ($odbh) = DBINFO::db_user_connect($self->username());
		&ZOOVY::add_event($self->username(),"ORDER.$eventname",
			'ORDERID'=>$self->oid(),
			'PRT'=>$self->prt(),
			);

		#my $pstmt = &DBINFO::insert($odbh,'ORDER_EVENTS',{
		#	USERNAME=>$self->username(),
		#	MID=>&ZOOVY::resolve_mid($self->username()),
		#	ORDERID=>$self->oid(),
		#	CREATED_GMT=>time(),
		#	EVENT=>$eventname,
		#	LOCK_ID=>0,
		#	LOCK_GMT=>0,
		#	ATTEMPTS=>0,
		#	},sql=>1);

		#my ($rv) = $odbh->do($pstmt);
		#if (not defined $rv) {
		#	open F, ">>/tmp/dispatch.sql";
		#	print F $pstmt."; \n";
		#	# print F sprintf("/* %s */\n\n",$odbh->errstr()); 
		#	close F;
		#	$found = -1;
		#	}
		&DBINFO::db_user_close();
		}

	push @{$self->{'@dispatch'}}, [ $eventname, $found, $ts ];
	}


sub email {
	my ($self, $msg) = @_;
	}



#sub emailvars {
#	my ($self) = @_;
#
#	my %vars = ();
#	return(\%vars);
#
#	my $order_id = $self->{'order_id'};
#	my $stuff = $self->stuff();
#	my $attribs = $self->get_attribs();
#
#	my $tracking = '';
#	my $htmltracking = '<table class="trackinfo">';
#	if (defined $self->{'tracking'}) {
#		foreach my $item (@{$self->{'tracking'}}) {
#			$tracking .= "$item->{'carrier'} - $item->{'track'}\n";
#			$htmltracking .= "<tr><td class='line'>$item->{'carrier'}</td><td class='line'>$item->{'track'}</td></tr>";
#			}
#		}
#	$htmltracking .= '</table>';
#
#	## this is the old AUTOEMAIL::htmlify code:
#	my $paytxt = $self->payinstructions();
#	$paytxt =~ s/([Hh][Tt][Tt][Pp][Ss]?\:\/\/[\S]+)/<a href="$1">$1<\/a>/sg;
#	$paytxt =~ s/[\n\r]+/<br>/g;
#
#	## create an HTML packing slip
#
#	my %TAGS = (
#			'%ORDERID%' => $order_id,
#			'%NAME%' => $attribs->{'bill_firstname'}.' '.$attribs->{'bill_lastname'},
#			'%FULLNAME%' => $attribs->{'bill_firstname'}.' '.$attribs->{'bill_lastname'},
#			'%FIRSTNAME%' => $attribs->{'bill_firstname'},
#			'%EMAIL%' => $attribs->{'bill_email'},
#			'%ORDERNOTES%' => $attribs->{'order_notes'},
#			'%DATE%' => &ZTOOLKIT::pretty_date($attribs->{'created'}, 0),
#			'%SHIPMETHOD%' => $attribs->{'shp_method'},
#			'%PAYINFO%' => $self->payinfo(),
#			'%PAYINSTRUCTIONS%' => $paytxt,
#			'%TRACKINGINFO%'=>$tracking,
#			'%HTMLTRACKINGINFO%'=>$htmltracking,
#			);
#	
#		foreach my $attr (keys %{$attribs}) {
#			$TAGS{'%'.lc($attr).'%'} = $attribs->{$attr};
#			}
#
#		$TAGS{'%HTMLPAYINSTRUCTIONS%'} = $TAGS{'%PAYINSTRUCTIONS%'};
#
#		# my $webdbref = &ZWEBSITE::fetch_website_dbref($self->{'username'});
#		# (undef,$TAGS{'%HTMLCONTENTS%'}) = &TOXML::EMAIL::order_view_texthtml($o,$webdbref,0);
#		# $TAGS{'%CONTENTS%'} = $TAGS{'%HTMLCONTENTS%'}; 
#
#		#(undef,$TAGS{'%HTMLPACKSLIP%'}) = &TOXML::EMAIL::order_view_texthtml($self,$webdbref,1);
#		#$TAGS{'%PACKSLIP%'} = $TAGS{'%HTMLPACKSLIP%'}; 
#
#		#(undef,$TAGS{'%HTMLBILLADDR%'}) = &TOXML::EMAIL::text_addr('bill',$attribs);
#		#$TAGS{'%BILLADDR%'} = $TAGS{'%HTMLBILLADDR%'};
#		#(undef,$TAGS{'%HTMLSHIPADDR%'}) = &TOXML::EMAIL::text_addr('ship',$attribs);
#		#$TAGS{'%SHIPADDR%'} = $TAGS{'%HTMLSHIPADDR%'};
#		
#		# strip HTML in cart contents (non HTML)
#		# $TAGS{'%CONTENTS%'} =~ s/<(.*?)>//g;
#		# $TAGS{'%PACKSLIP%'} =~ s/<(.*?)>//g;	
#	return(\%TAGS);
#	}
#


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
#	foreach my $i ($self->stuff()->as_array()) {
#
#		my $virtual = '';
#
#		if (not defined $i->{'%attribs'}) {}
#		elsif (not defined $i->{'%attribs'}->{'zoovy:virtual'}) {}
#		else { $virtual = $i->{'%attribs'}->{'zoovy:virtual'}; }
#      ## SANITY: at this point $virtual is blank, or set to a valid value.
#
#		## make sure the $virtual value exists in %VIRTUALSTUFF
#		if (not defined $VIRTUALSTUFF{ $virtual }) { $VIRTUALSTUFF{$virtual} = (); }
#		push @{$VIRTUALSTUFF{$virtual}}, $i;
#		}
#
#	$count = scalar(keys %VIRTUALSTUFF);
#	if (defined $VIRTUALSTUFF{''}) { $count--; } # never count non-virtuals (normal products)
#
#	return($count,\%VIRTUALSTUFF);
#	}
#







##
## resolve payment_txn
##		note: this will only be able to lookup by the last payment txn number.
##
sub lookup_payment_txn {
	my ($USERNAME, $TXN) = @_;
	my ($ORDERID) = &ORDER::lookup($USERNAME,'PAID_TXN',$TXN);
	return($ORDERID);
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
			$pstmt .= " and ORDER_EREFID=".$odbh->quote(substr($options{$KEY},0,24));
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
## backward compatibility - should be removed by 1/1/2012
##
sub payment {
	my ($self,$ACTION) = @_;

	if ($ACTION ne 'CAPTURE') {
		$self->event("sorry, but payment($ACTION) is no longer supported please upgrade your software.");
		}
	else {
		my $ps = '';
		foreach my $payrec (@{$self->payments()}) {
			if ($payrec->{'ps'} eq '199') { 
				$self->event("oldpayment is attempting to run new process_payment for $payrec->{'uuid'}");
				$self->process_payment('CAPTURE',$payrec);
				$ps = $payrec->{'ps'};
				}
			}
		if ($ps ne '') {
			$self->event("guessing payment_status=$ps from legacy payment (please upgrade your software)");
			$self->set_attrib('payment_status',$ps);
			}
		}
	return();
	}


##
##
##	$action can be:
##		AUTH|CAPTURE|CHARGE|VOID|CREDIT|REFUND
##		
##	CREDIT == REFUND (CREDIT is deprecated)
##
#sub payment {
#	my ($self, $ACTION, %options) = @_;
#
#	$ACTION = uc($ACTION);
#	if ($ACTION eq 'AUTH') { $ACTION = 'AUTHORIZE'; }
#
#	## these are the return values
#
#	my ($result_success, $result_msg, $result_ps) = (undef,undef,undef);
#
#	my ($USERNAME) = $self->username();
#
#	##
#	## PHASE 1: decide who the processor is!
#	##
#	my $processor = undef;
#	my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME, $self->prt());
#
#	my $payment_method = $self->get_attrib('payment_method');
#	if (not defined $payment_method) { $payment_method = 'CREDIT'; }
#
#	if ($payment_method eq 'GOOGLE') { 
#		$processor = 'GOOGLE'; 
#		}
#	elsif ($payment_method eq 'PAYPALEC') { 
#		$processor = 'PAYPALEC'; 
#		}
#	elsif ($payment_method eq 'AMZSPAY') { 
#		$processor = 'AMZSPAY'; 
#		}
#	elsif ($payment_method eq 'CREDIT') {}
#	elsif ($payment_method ne 'ECHECK') {}
#
#
#	if (($payment_method eq 'CREDIT') && defined($webdbref->{'cc_processor'})) {
#		$processor = $webdbref->{'cc_processor'};
#    	}
#	elsif (($payment_method eq 'ECHECK') && defined($webdbref->{'echeck_processor'})) {
#		$processor = $webdbref->{'echeck_processor'};
#    	}
#	if ($processor eq '') { $processor = 'NONE'; }
#
#	##
#	## PHASE 2: load the processor object
#	##
#
#	my ($ZP) = undef;
#	if ($processor eq 'AUTHORIZENET') {
#		require ZPAY::AUTHORIZENET;
#		($ZP) = ZPAY::AUTHORIZENET->new($USERNAME,$webdbref);		
#		}
#	elsif ($processor eq 'QBMS') {
#		require ZPAY::QBMS;
#		($ZP) = ZPAY::QBMS->new($USERNAME,$webdbref);
#		}
#	elsif ($processor eq 'PAYPALWP') {
#		require ZPAY::PAYPALVT;
#		($ZP) = ZPAY::PAYPALVT->new($USERNAME,$webdbref);
#		}
#	elsif ($processor eq 'PAYPALVT') {
#		require ZPAY::PAYPALVT;
#		($ZP) = ZPAY::PAYPALVT->new($USERNAME,$webdbref);
#		}
#	elsif ($processor eq 'AMZPAY') {
#		require ZPAY::AMZPAY;
#		($ZP) = ZPAY::AMZPAY->new($USERNAME,$webdbref);
#		}
#	elsif ($processor eq 'PAYPALEC') {
#		require ZPAY::PAYPALVT;
#		($ZP) = ZPAY::PAYPALVT->new($USERNAME,$webdbref);
#		}
#	elsif ($processor eq 'LINKPOINT') {
#		require ZPAY::LINKPOINT;
#		($ZP) = ZPAY::LINKPOINT->new($USERNAME,$webdbref);
#		}
#	elsif (($processor eq 'VERISIGN') && ($payment_method eq 'CREDIT')) {
#		require ZPAY::VERISIGN;
#		($ZP) = ZPAY::VERISIGN->new($USERNAME,$webdbref);
#		}
#	elsif (($processor eq 'SKIPJACK') && ($payment_method eq 'CREDIT')) {
#		require ZPAY::SKIPJACK;
#		($ZP) = ZPAY::SKIPJACK->new($USERNAME,$webdbref);
#		}
#	elsif ($processor eq 'ECHO') {
#		require ZPAY::ECHO;
#		($ZP) = ZPAY::ECHO->new($USERNAME,$webdbref);
#		}
#	elsif ($processor eq 'MANUAL') {
#		require ZPAY::MANUAL;
#		($ZP) = ZPAY::MANUAL->new($USERNAME,$webdbref);
#		}
#	elsif ($processor eq 'GOOGLE') {
#		## GOOGLE is still a bit wonky, it doesn't really use $ZP like other methods do.		
#		## there is some specialized "if google" code below
#		##  which could probably be forced into the $ZP model with a bit of work
#		require ZPAY::GOOGLE;
#		($ZP) = ZPAY::GOOGLE->new($USERNAME,$webdbref);
#		}
#	elsif ($processor eq 'TESTING') {
#		require ZPAY::TESTING;
#		($ZP) = ZPAY::TESTING->new($USERNAME,$webdbref);
#		}
#	else {
#		($result_success,$result_msg, $result_ps) =
#			(0,"Gateway processor [$processor] not recognized",257);
#		}
#
#	##
#	## PHASE 3: run the action!
#	##
#	my $err = $self->check($self->username(), $self->oid());
#	if ((not defined $result_success) && ($err ne '')) { 
#		## okay, so we already got an error earlier!
#		## basic checks, this should return a 0, $err
#		($result_success,$result_msg, $result_ps) =
#			(0,"Check Failed: $err",257);
#		}
#
#
#	my $balance_due = $self->get_attrib('balance_due');
#	if (not defined $balance_due) { 
#		warn "\$balance_due was not set for user: ".$self->username()." order: ".$self->oid()." using order total";
#		$balance_due = $self->get_attrib('order_total'); 
#		}
#
#
#	if (defined $result_success) {
#		## we've already had a status set prior so we don't keep going!
#		}
#	elsif ($ACTION eq 'AUTHORIZE') {
#		# A zoovy 3-digit payment_status that the order should be set to.
#		# A message that describes what happened (should include relevant result codes returned from the processor)
#		# A hashref to the complete results of the attemp to charge (written to a debug file via &result_log)
#		# Authorization code for the charge
#		# Transaction ID for the charge
#		my ( $hash, $transid, $gwcode );
#
#		$self->event('Attempting to authorize the cart '.$balance_due,undef,2);
#		($result_ps, $result_msg, $hash, $transid, $gwcode) = $ZP->authorize($self,$balance_due);
#
#		if (not defined $result_ps)    { $result_ps    = 257; }
#		if (not defined $result_msg) { $result_msg = 'Undefined Message'; }
#		if (not defined $transid)   { $transid   = ''; }
#		if (not defined $gwcode)    { $gwcode    = ''; }
#		
#		if ($payment_method eq 'CREDIT') {
#			$self->set_attribs(
#				'payment_cc_results'  => $result_msg,
#				'cc_auth_transaction' => $transid,
#				'cc_authorization'    => $gwcode,
#				);
#			}
#		elsif ($payment_method eq 'ECHECK') {
#			$self->set_attribs(
#				'payment_echeck_results'  => $result_msg,
#				'echeck_auth_transaction' => $transid,
#				'echeck_authorization'    => $gwcode,
#				);
#			}
#
#		$self->set_payment_status(
#			$result_ps,
#			'gateway_authorize',
#			[ "$payment_method AUTH: trans=$transid auth=$gwcode r=$result_msg" ]
#			);
#
#		$result_success = 0;
#		if (($result_ps < 200) || (substr($result_ps, 0, 1) eq '4')) { 
#			$result_success = 1; 
#			}
#
#		$self->fraud_check($webdbref);
#		}
#	##
#	##
#	##
#	elsif ($ACTION eq 'CAPTURE') {
#		my $payment_status = $self->get_attrib('payment_status');
#
#		if (substr($payment_status,0,1) eq '0') {
#			$result_success = 0;
#			$result_msg = 'ZPAY: capture aborted because ps='.$payment_status.' - already captured!';
#			$result_ps = $payment_status;
#			$self->event($result_msg,time(),2+8);
#			}
#		elsif ( ($payment_status != 189) && ($payment_status != 199) && 
#			($payment_status != 299) && ($payment_status != 499)) {
#			$result_ps = $payment_status;
#			
#			($result_success,$result_msg,$result_ps) =
#				(0, 'ORDER::capture - Unable to process this order (System cannot locate previous authorization)', $result_ps);
#			}
#	
#		if (defined $result_success) {
#			## something already happened!
#			}
#		elsif ($processor eq 'GOOGLE') {	
#			require ZPAY::GOOGLE;
#			&ZPAY::GOOGLE::chargeOrder($self);
#			($result_ps, $result_msg) = ($self->get_attrib('payment_status'), "did Google ChargeOrder");
#			}
#		else {
#			# result_ps: A zoovy 3-digit payment_status that the order should be set to.
#			# result_msg: A message that describes what happened (should include relevant result codes returned from the processor)	
#			my ( $hash, $transid, $gwcode );
#			($result_ps, $result_msg, $hash, $transid, $gwcode) = $ZP->capture($self,$balance_due);
#
#			$self->event('ORDER::capture type='.$payment_method.' p='.$processor,time(),2);
#			if (not defined $result_ps)    { $result_ps    = 257; }
#			if (not defined $result_msg) { $result_msg = 'Undefined Message'; }
#	
#			if ($payment_method eq 'CREDIT') {
#				$self->set_attribs(
#					'payment_cc_results'  => $result_msg,
#					'cc_bill_transaction' => $transid,
#					'cc_authorization'    => $gwcode,
#					);
#				}
#			elsif ($payment_method eq 'ECHECK') {
#				$self->set_attribs(
#					'payment_echeck_results'  => $result_msg,
#					'echeck_bill_transaction' => $transid,
#					'echeck_authorization'    => $gwcode,
#					);
#				}
#			$self->set_payment_status(
#				$result_ps,
#				'gateway_capture',
#				[ "$payment_method Charge Authorized: [trans:$transid] [auth:$gwcode] $result_msg" ],
#				);
#			}
#
#		if (not defined $result_success) {
#			$result_success = 0;
#			if (($result_ps < 200) || (substr($result_ps, 0, 1) eq '4')) {
#				$result_success = 1;
#				}
#			}
#
#		## END OF CAPTURE
#		}
#	##
#	##
#	##
#	elsif ($ACTION eq 'CHARGE') {
#		my $payment_status = $self->get_attrib('payment_status');
#		if (($payment_method eq 'ECHECK') && ($payment_status eq '120')) {
#			# eChecks they don't capture, they just get flagged as paid.			
#			$self->set_payment_status(
#				'006',
#				'echeck_capture',
#				[ "eCheck flagged as paid." ]
#				);			
#			}
#		else {
#			##
#			# HOW THIS WORKS: each payment gateway returns the following variables -
#			#	$result_ps => the payment code e.g. 000 for paid
#			#	$result_msg => this becomes payment_cc_results (displayed to user to indicate why the code is what it is)
#			#	$hash => this is a bit misleading, it's really more for debugging than anything.
#			#		it's a hash ref, it can be empty, it won't hurt anything.
#			#	$transid => stored in cc_auth_transaction, this is the transaction reference #
#			#		(usually returned by the gateway)
#			#	$gwcode => this cc_authorization, this is the merchant account reference #
#			#		(usually this is the one used to settle)
#			#	(note: i didn't write this, but i do maintain it -bh)
#			##
#			$self->event("ZPAY Gateway is attempting to charge the card balance_due:$balance_due",undef,2);
#			my ( $hash, $transid, $gwcode );
#			($result_ps, $result_msg, $hash, $transid, $gwcode) = $ZP->charge($self,$balance_due);
#
#			if (not defined $result_ps)    { $result_ps    = 257; }
#			if (not defined $result_msg) { $result_msg = 'Undefined Message'; }
#			if (not defined $hash)    { $hash    = {}; }
#			if (not defined $transid)   { $transid   = ''; }
#			if (not defined $gwcode)    { $gwcode    = ''; }
#	
#			$self->set_attribs(
#				'payment_cc_results'  => $result_msg,
#				'cc_bill_transaction' => $transid,
#				'cc_authorization'    => $gwcode,
#				);
#	
#			## NOTE: don't say "CREDIT Charge" we say "CC Charge" instead so people (e.g. jackstoolshed) don't think
#			##			they are mistakenly giving a credit when they aren't.
#			$self->set_payment_status(
#				$result_ps,
#				'cc_charge',
#				[ (($payment_method eq 'CREDIT')?'CC':$payment_method)." Charge: [trans:$transid] [auth:$gwcode] $result_msg [$result_ps]" ]
#				);
#		
#			$result_success = 0;
#			if (($result_ps < 200) || (substr($result_ps, 0, 1) eq '4')) {
#				$result_success = 1;
#				}
#			}
#	
#		$self->fraud_check($webdbref);
#		}
#	##
#	##
#	##
#	elsif (($ACTION eq 'CREDIT') || ($ACTION eq 'REFUND')) {
#		my $amount = $options{'amount'};
#		if ($amount==0) { $amount = $self->get_attrib('order_total'); }
#		($result_ps, $result_msg) = $ZP->credit($self,$amount);
#
#	   if ((length($result_ps)==3) && (substr($result_ps,0,1) eq '2')) {
#			## $result must be a 2xx code to be considered a failure!
#			$self->set_payment_status(
#				$result_ps,
#				'gateway_credit',
#				[ "UNSUCCESSFUL attempt to credit order - $result_msg [$result_ps]" ],
#				);
#			$result_success = 0;
#			}
#		else {
#			$self->event("SUCCESSFULLY credited order \$$amount - $result_msg [$result_ps]",time(),2+8);
#			if (sprintf("%.2f",$amount) eq sprintf("%.2f",$self->get_attrib('order_total'))) {
#				$self->set_payment_status('302','payment.cgi',undef);
#				}
#			$result_success = 1;
#			}
#		}
#	##
#	##
#	##
#	elsif ($ACTION eq 'VOID') {
#		## BEGIN VOID
#		($result_ps,$result_msg) = $ZP->void($self);
#	
#	   if ((length($result_ps)==3) && (substr($result_ps,0,1) eq '2')) {
#			$self->set_payment_status(	
#				$result_ps,
#				'cc_void',
#				[ "Unsuccessful void order - $result_msg [$result_ps]" ],
#				);
#			$result_success = 0;
#			}
#		else {
#			$self->event("Success void order - $result_msg [$result_ps]",time(),2+8);
#			$result_success = 1;
#			}
#		## END VOID
#		}
#
#	
#	##
#	## One save to bind them all!
#	##
#	$self->save();
#
#	return($result_success,$result_msg,$result_ps);
#	}
#






##
## payments
##		an array of:
##		{ uuid=>"", txn=>"", tender=>"", ts=>time, amt=>1.00, note=>"" }
##	the sum of all amt=> becomes paid_total   (and  order_total - balancedue_total)
##



##
## this set's variables on a payment if you know the uuid of the payment
##
sub update_payment_uuid {
	my ($self,$uuid,%vars) = @_;

	my ($payrec) = $self->payment_by_uuid($uuid);
	if ((not defined $payrec) && ($self->{'data'}->{'created'}<1289466060)) {
		## 1289466060 =  2010-11-11 01:01:00 
		## hmm.. the proper UUID doesn't exist, SO we'll try falling back to ORDERV4
		($payrec) = $self->payment_by_uuid("ORDERV4");
		}

	if (not defined $payrec) {
		$self->event("ERROR update_payment_uuid uuid[$uuid] vars[".&ZTOOLKIT::buildparams(\%vars)."]");
		}
	elsif ($payrec) {
		foreach my $k (keys %vars) { $payrec->{$k} = $vars{$k}; }
		}
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

#	print STDERR "XYZ ".&ZTOOLKIT::buildparams(\%options)."\n";
#	print STDERR "XYZ $tender AMT BEFORE: $amt\n";
	$amt = &ZOOVY::f2money($amt);
#	print STDERR "XYZ $tender AMT AFTER: $amt\n";

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
	if (not defined $options{'uuid'}) { $options{'uuid'} = $self->next_payment_uuid(); }
	if (not defined $options{'note'}) { $options{'note'} = "$tender Payment"; }
	if (not defined $options{'acct'}) { $options{'acct'} = ''; }
	if (not defined $options{'voided'}) { $options{'voided'} = sprintf("%d",0); }
	if (not defined $options{'luser'}) { $options{'luser'} = ''; }
	if (not defined $options{'voidtxn'}) { $options{'voidtxn'} = sprintf("%d",0); }
	if (not defined $options{'ps'}) { $options{'ps'} = '500'; }
	if (not defined $options{'debug'}) { $options{'debug'} = ''; }	
	if (not defined $options{'r'}) { $options{'r'} = ''; }

	## puuid is "ptxn" on sync prior xcompat 200
	if (not defined $options{'puuid'}) { $options{'puuid'} = ''; }	

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
		acct=>$options{'acct'},	# buyer account # e.g. ####-xxxx-xxxx-#### for a credit card 
		voided=>$options{'voided'},	# when the transaction was voided (if it was or 0 if it hasn't been)
		voidtxn=>sprintf("%d",$options{'voidtxn'}),	# void transaction #
		puuid=>$options{'puuid'},		# parent txn for chainging (credits should be chained to the parent txn)
												# NOTE: in order for a transaction to be chained it must have a txn set
		ps=>$options{'ps'},		# payment status
		r=>$options{'r'},
		auth=>$options{'auth'},	# external auth transaction
		luser=>$options{'luser'},	# which user created this transaction
		);
	
	if (defined $options{'app'}) { $payment{'app'} = $options{'app'}; }
	if (defined $options{'debug'}) { $payment{'debug'} = $options{'debug'}; }

	if (not defined $self->{'payments'}) { $self->{'payments'} = []; }
	push @{$self->{'payments'}}, \%payment;

	if ($payment{'tender'} eq 'GOOGLE') {
		}
	if (($payment{'tender'} eq 'PAYPAL') || ($payment{'tender'} eq 'PAYPALEC')) {
		}

	if (($payment{'tender'} eq 'CASH') || ($payment{'tender'} eq 'CHECK')) {
		## let the user pass in a 'ps' (payment status) for cash
		if ($options{'ps'}) { $payment{'ps'} = $options{'ps'}; }
		}

	if ($payment{'tender'} eq 'ADJUST') {
		$payment{'ps'} = '088';	# adjust payments are always treated as 'paid in full'
#create table ORDER_PAYMENT_ADJUSTMENTS (
#   ID integer unsigned auto_increment,
#   USERNAME varchar(20) default '' not null,
#   MID integer unsigned default 0 not null,
#   PRT tinyint unsigned default 0 not null,
#   ORDERID varchar(20) default '' not null,
#   CREATED_GMT integer unsigned default 0 not null,
#   UUID varchar(32) default '' not null,
#   AMOUNT decimal(10,2) default 0 not null,
#   NOTE tinytext default '' not null,
#   LUSER varchar(10) default '' not null,
#   unique(MID,ORDERID,UUID),
#   index(MID,PRT,CREATED_GMT),
#   primary key(ID)
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

#	my $i = 0;
#	while (-f "/dev/shm/preserve.$i") {
#		$i++;
#		}
#	open F, ">/dev/shm/preserve.$i";
#	print F Dumper(caller(0),$self);
#	close F;

#	print STDERR Dumper('BEFORE: ',\%payment);
	$self->recalculate(1);
	## note: due is set in memory *after* recalculate recomputes the balance. 
	$payment{'due'} = $self->get_attrib('balance_due');
	# print STDERR Dumper('AFTER: ',\%payment);

	if ($options{'event'}) {
		$self->event($options{'note'},$options{'ts'},2,$options{'luser'});
		}

	return(\%payment);
	}



#
#   my %payment = (
#      ts=>$options{'ts'},     # time it was created  - 4 byte unsigned int.
#      tender=>$tender,        # GIFTCARD, PAYPAL, CREDIT	varchar(10)
#      uuid=>$options{'uuid'}, # unique identifier (order#.##)	varchar(32)
#      auth=>$options{'auth'}, # external auth transaction	varchar(20) 
#      txn=>$options{'txn'},   # external settlement transaction varchar(20)
#										 # (usually this is what merchants search by) varchar(20)
#		settled=>$options{'settled'}	# a date/time the transaction was settled.
#      amt=>$amt,              # amount of the transaction	decimal(10,2)
#      acct=>$options{'acct'}, # buyer account # e.g. ####-xxxx-xxxx-#### for a credit card	varchar(64)
#      note=>$options{'note'}, # a pretty description of the transaction e.g. "Giftcard 1234-xxxx-xxxx-5678"
#      voided=>$options{'voided'},   # when the transaction was voided (if it was or 0 if it hasn't been)
#      voidtxn=>$options{'voidtxn'}, # void transaction #
#      puui=>$options{'puuid'},   # parent txn for chainging (credits should be chained to the parent uuid) varchar(20)
#		debug=>""		# response from the last api transaction
#		ps=>"",			# payment_status - for this specific payment
#      );
#	question: how do we store credit card + dates or echeck
#


##
##  accepts 'tender'=>'GOOGLE' (or other tender types) and will only return payments of that type.
##
sub payments {
	my ($self,%options) = @_;

	if (not defined $self->{'payments'}) {
		$self->{'payments'} = [];		
		}
	my $result = $self->{'payments'};
	
	if (scalar(keys %options)) {
		$result = [];
		foreach my $payrec (@{$self->{'payments'}}) {
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
## assocaites a specific cartid with an order id in the database (permanently)
##
#sub reserve_cartid {
#	my ($USERNAME,$CARTID,$OID) = @_;
#
#	## if we have a cartid, lets do a quick duplicate order check.
#	my $odbh = &DBINFO::db_user_connect($USERNAME);
#
#	if (not defined $OID) { $OID = ORDER::next_id($USERNAME); }
#	my $qtUSERNAME = $odbh->quote($USERNAME);
#	my $qtOID = $odbh->quote($OID);
#	my $qtCARTID = $odbh->quote($CARTID);
#	my $recentts = time()-3600;	# right now, minus an hour .. so no duplicate carts allowed within an hour.
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#	my $TB = &DBINFO::resolve_orders_tb($USERNAME,$MID);
#	my $ts = time();
#
#	my $pstmt = "insert into $TB (MID,MERCHANT,ORDERID,CARTID,CREATED_GMT) values ($MID,$qtUSERNAME,$qtOID,$qtCARTID,$ts)";
#	$odbh->do($pstmt);
#
#	my ($realOID) = &ORDER::lookup_cartid($USERNAME,$CARTID,$recentts);
#	&DBINFO::db_user_close();
#
#	return($realOID);
#	}


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




##
## an internal handler for an order if got an error (it's best practice to check this)
##
#sub had_problem {
#	my ($self) = @_;
#	if ($self->{'+error'} eq 'OKAY') { return(undef); }
#	return($self->{'+error'});
#	}


##
## this will create a new order from a cart
##	%options
##		use_order_cartid
##
#sub from_cart {
#	my ($class,$CART,%options) = @_;
#	die("ORDER::from_cart no longer supported -- look at cart2->make_legacy_order");
#	return($self,$result);
#	}


## returns the version of the order.
sub v {
	return(sprintf("%d",$_[0]->{'version'}));
	}


sub is_tmp { if (defined $_[1]) { $_[0]->{'_is_tmp'} = int($_[1]); } return(int($_[0]->{'_is_tmp'}));  }


##
##
##
sub create {
	my ($class,$USERNAME, %options) = @_;

	my $self = {};

	## If we got here we're making a new order instead of loading an old one
	## Either load stuff from a passed stuff object, or create a new blank one
	bless $self, 'ORDER';

	my $stuff;
	$self->{'stuff'} = undef;
	$self->{'payments'} = [];

#	if (defined $options{'cart'}) {
#		## create an order from a cart.
#		warn "\n\n!!! PLEASE stop calling ORDER->new directly and passing a cart, instead use from_cart\n\n";
#		my $cart = $options{'cart'};
#		if (not defined $options{'data'}) {
#			$options{'data'} = $cart->fetch_data();
#			}
#		if (not defined $options{'stuff'}) {
#			$options{'stuff'} = $cart->stuff();
#			}			
#		}

	if (defined $options{'stuff'}) {
		$stuff = STUFF->new($self->username(), 'stuff'=>$options{'stuff'});
		}
	else {
		$stuff = STUFF->new($self->username());
		}
		
	## Load the initial attribs from a passed hashref or create a blank hashref
	my $data = {};
	if (defined $options{'data'}) {
		$data = $options{'data'};
		}

	## Set the pool if not included in the passed data
	if (not defined $data->{'pool'}) {
		$data->{'pool'} = 'RECENT';
		}

	$data->{'created'} = time();
	$data->{'timestamp'} = time();
	$self->{'applock'}	  = '';		
	$self->{'stuff'}	 = $stuff;
	$self->{'data'}	  = $data;
	$self->{'events'}	= [];
	$self->{'payments'}	= [];
	$self->{'username'} = $USERNAME;
	$self->{'version'} = int(8);

	if (defined $options{'mkts'}) { 
		## usually used for 'mkts'=>'0001KW', (order manager/point of sale)
		$self->{'mkts'} = $options{'mkts'}; 
		$self->{'data'}->{'mkts'} = $options{'mkts'}; 
		}
	
	if ($options{'tmp'}) {
		## Set the order ID to * and don't save
		$self->{'order_id'} = '*';
		$self->{'_is_tmp'}++;
		}
	## SHOULD WE CREATE A NEW ORDER?
	elsif ((defined $options{'new'}) && ($options{'new'}==0)) {
		## passing new=>0 means we're implicitly not allowed to create new orders
		warn("would have created new order but couldn't because new=0\n");
		}
	elsif ((defined $options{'useoid'}) && ($options{'useoid'} ne '')) {
		$self->{'order_id'} = $options{'useoid'};
		$self->event(sprintf("order initialized as oid[%s] by [%s:%s] on ",$options{'useoid'},&ZOOVY::servername(),&ZOOVY::appname()),undef,4+0);
		$self->recalculate(1);
		$self->save(1);
		$self->dispatch('create');
		}
	else {
		## Assign an order ID to the order object and save it
		bless $self, 'ORDER';
		$self->{'order_id'} = &next_id($USERNAME);
		my ($package,$file,$line,$sub,$args) = caller(1);
		$self->event(sprintf("order initialized by [%s:%s]",&ZOOVY::servername(),&ZOOVY::appname()),undef,4+0);
		$self->recalculate(1);

		if ((defined $options{'save'}) && ($options{'save'}==0)) {
			## we will save and dispatch ourselves.
			}
		else {
			$self->save(1);
			$self->dispatch('create');
			}
		}

	## !!!!!! EXIT !!!!!!!!!!!!
	bless $self, 'ORDER';
	return $self;
	}

######################################################################################
## ORDER->new
######################################################################################
## Purpose: Creates a new STUFF object (either loaded from disk, or made from scratch)
## Accepts: $USERNAME (required),
##			 $ORDER_ID (if blank or undef it will create new order with a number and
##			 save it, if '*' will create an order object without saving, and if passed
##			 an existing order ID it will load it from disk)
##			 %options: (only paid attention to when there's ORDER_ID is blank or *)
##				  stuff => reference to stuff object to create order with
##				  data => hashref of order attributes to be set initially
##				  events => arrayref of strings of events to creat the order with
##				  cart => a reference to a cart from which to create the order
##					 supplier => supplierid
##					 scoid => a supply chain order id
##						scoid_origin => the origin order which initiated this supply chain order.
##		
## Returns: The newly formed order object
sub new {
	my ($class, $USERNAME, $ORDER_ID, %options) = @_;

	
	#&msg("\$USERNAME is $USERNAME");
	
	my $self = {};

	unless (def($USERNAME)) {
		return undef, 'Username must be provided to new order call';
		}

	$ORDER_ID = (defined $ORDER_ID)?$ORDER_ID:'';

	if (($ORDER_ID eq '*') || ($ORDER_ID eq '')) {
		if ($ORDER_ID eq '*') { $options{'tmp'}++; } # backward compatibility
		$self = ORDER->create($USERNAME,%options);
		}


	my $CUSTOMER_ID = 0;
	if (ref($self) ne 'ORDER') {

		## NOTE: this line is not reached if we initialized a new order in memory

		## load an exising order from disk
		# print STDERR "ORDERID: $ORDER_ID\n";
		$self->{'order_id'} = $ORDER_ID;
		$self->{'username'} = $USERNAME;


		## first we check the new database
		my $odbh = &DBINFO::db_user_connect($USERNAME);
		my $mid = &ZOOVY::resolve_mid($USERNAME);
		my $order_id_qt = $odbh->quote($ORDER_ID);
		my $TB = &DBINFO::resolve_orders_tb($USERNAME,$mid);
		my $pstmt = "select ID,YAML, FLAGS, POOL, CREATED_GMT, MODIFIED_GMT, MKT_BITSTR, CUSTOMER from $TB where ORDERID=$order_id_qt and MID=$mid";
		(my $ODBID, my $YAML, my $FLAGS, my $POOL, my $CREATED_GMT, my $MODIFIED_GMT, my $MKTS, $CUSTOMER_ID) = $odbh->selectrow_array($pstmt);


		if ($YAML ne '') {
			## primarily load from YAML

			## make's it possible to load version 9 orders
			my $fixed = 0;
			if ($YAML =~ /CUSTOMER\:\:ADDRESS/) {
				$fixed++;
				$YAML =~ s/\"\*CUSTOMER\"\: \&1 \!\!perl\/hash\:CUSTOMER/"*CUSTOMER"\:/gs;
				$YAML =~ s/\!\!perl\/hash\:CUSTOMER\:\:ADDRESS//gs;
				}

			#$YAML =~ s/\!\!perl\/hash\:Math\:\:BigInt//gs;	
			$YAML =~ s/\&[\d]+ \&[\d]+ \!\!perl\/hash\:Math\:\:BigInt/\!\!perl\/hash\:Math\:\:BigInt/gs;
			#$YAML =~ s/\&1 \&2 !\!\perl\/hash\:Math\:\:BigInt/\!\!perl\/hash\:Math\:\:BigInt/gs; # zephyrsports - "2012-06-261019"
			($self) = YAML::Syck::Load($YAML);
			#print $YAML;
			#use YAML::XS;
			#($self) = YAML::XS::Load($YAML);

			$self->{'ODBID'} = $ODBID;			

			if ($fixed) {
				delete $self->{'data'}->{'*CUSTOMER'};
				delete $self->{'data'}->{'_CODE'};
				delete $self->{'data'}->{'ID'};
				delete $self->{'data'}->{'TYPE'};
				}


			$self->{'data'}->{'pool'} = $POOL;
			$self->{'data'}->{'created'} = $CREATED_GMT;
			$self->{'data'}->{'timestamp'} = $MODIFIED_GMT;
			$self->{'data'}->{'flags'} = $FLAGS;
			# $self->{'data'}->{'mkt'} = $MKT;
			if ($MKTS ne '') {
				$self->{'data'}->{'mkts'} = $MKTS;
				$self->{'mkts'} = $MKTS;
				}
			$self->{'data'}->{'customer_id'} = $CUSTOMER_ID;

	
			## make sure we initialize stuff properly
			($self->{'stuff'}) = STUFF->new($USERNAME,'stuff'=>$self->{'stuff'});

			bless $self, 'ORDER';
			}


		&DBINFO::db_user_close();
		}


	#if (ref($self) ne 'ORDER') {
	#	## for older orders we can safely load from disk.
	#	$self->{'order_id'} = $ORDER_ID;
	#	$self->{'username'} = $USERNAME;
	#	bless $self, 'ORDER';
	#	my $filename = def($self->filename());
	#	# print STDERR $filename."\n";

	#	## Look for the .bin filename first
	#	if ($filename && (-f $filename)) {
	#		## load old style order from disk.
	#		$self = eval { Storable::retrieve($filename); };
	#		if (not defined $self) {
	#			&ZOOVY::confess($USERNAME,"Could not load $filename from disk or db\n",justkidding=>1);
	#			}
	#		else {
	#			$self->{'data'}->{'customer_id'} = $CUSTOMER_ID;
	#			bless $self, 'ORDER';
	#			}
	#		}
	#	else {
	#		$self = undef;
	#		}
	#	}

	if ((not defined $self) || (ref($self) ne 'ORDER')) {
		## invalid order
		&msg("Unable to load information for $USERNAME $ORDER_ID (undef on load)");
		return undef, "Unable to load information for $USERNAME $ORDER_ID (undef on load)";
		}
	elsif ((defined $self->{'V'}) && (int($self->{'V'}) >= 210)) {
		## new format 'CART2' order
		bless $self, 'CART2';
		$self->make_legacy_order();
		}
	else {
		## valid order

		if ($self->{'version'} < 4) {
			if (def($self->{'data'}->{'shipping_total'}) ne '') {
				$self->{'data'}->{'shp_total'} = cashy($self->{'data'}->{'shipping_total'});
				delete $self->{'data'}->{'shipping_total'};
				}

			if (def($self->{'data'}->{'shipping_carrier'}) ne '') {
				$self->{'data'}->{'shp_method'} = $self->{'data'}->{'shipping_carrier'};
				delete $self->{'data'}->{'shipping_carrier'};
				}

			if (def($self->{'data'}->{'tax'}) ne '') {
				$self->{'data'}->{'local_tax_rate'} = $self->{'data'}->{'zip_tax_rate'};
				delete $self->{'data'}->{'zip_tax_rate'};
				if (not defined $self->{'data'}->{'state_tax_rate'}) {
					$self->{'data'}->{'state_tax_rate'} = gnum($self->{'data'}->{'tax_rate'}) - gnum($self->{'data'}->{'local_tax_rate'});
					}
				}

			delete $self->{'data'}->{'tax_rate'};
			delete $self->{'data'}->{'total_taxable'};
			delete $self->{'data'}->{'tax_subtotal'};
			delete $self->{'data'}->{'tax_total'};
			delete $self->{'data'}->{'tax'};
			}

		if ($self->{'version'} < 5) {
			# upgrade existing payment data in the order and make it appear as if it's a payment.
			my $legacyref = undef;
			my $i = 0;
			my @empty = ();
			my $paid_in_payments = 0;
			foreach my $pref (@{$self->{'payments'}}) {
				$i++;
				if ((keys %{$pref})==0) { 
					delete $self->{'payments'}->[$i];
					next;
					}

				if ($pref->{'uuid'} eq 'LEGACY') { 
					## LEGACY UUID is a payment which was upgraded - these are currently NOT SAVED.
					##	but in the future we'll auto-upgrade these, and remove the fields from the order.
					$legacyref = $pref; 
					}
				else {
					$paid_in_payments += $pref->{'amt'};
					}
				if (not defined $pref->{'ps'}) {
					$pref->{'ps'} = '999';
					}
				}

			
			if ($self->get_attrib('payment_method') eq '') {
				## no payment method on the order (probably a new order)
				}
			elsif (not $legacyref) {
				## this upgrades LEGACY payment settings (in order) so it appears that they came in payments
				## 	this is strictly a compatibility layer until 2010
				$legacyref = {};
				push @{$self->{'payments'}}, $legacyref;
				}

			if (defined $legacyref) {
				my ($ps) = $self->get_attrib('payment_status');

				my $payment_method = $self->get_attrib('payment_method');
				$legacyref->{'uuid'} = 'ORDERV4';
				$legacyref->{'tender'} = $payment_method;

				$legacyref->{'amt'} = 0;
				#if (substr($ps,0,1) eq '0') {
				$legacyref->{'amt'} = $self->get_attrib('order_total') - $paid_in_payments;
				#	}
		
				$legacyref->{'ps'} = $ps;
				if ($self->get_attrib('paid_date')>0) {
					$legacyref->{'ts'} = $self->get_attrib('paid_date');
					}

				if ($payment_method eq 'CREDIT') {
					$legacyref->{'note'} = sprintf("%s",&ZTOOLKIT::cardmask($self->get_attrib('card_number')));
					$legacyref->{'auth'} = $self->get_attrib('cc_auth_transaction');
					$legacyref->{'txn'} = $self->get_attrib('cc_bill_transaction');
					$legacyref->{'debug'} = $self->get_attrib('payment_cc_results');
					if (not defined $self->{'data'}->{'card_cvvcid'}) { $self->{'data'}->{'card_cvvcid'} = ''; }
					my ($CCorCM) = (($self->get_attrib('card_number') =~ /xxxx/)?'CM':'CC');
					$legacyref->{'acct'} = sprintf("|%s:%s|MM:%s|YY:%s|CV:%s",
						$CCorCM,
						$self->get_attrib('card_number'),
						$self->get_attrib('card_exp_month'),
						$self->get_attrib('card_exp_year'),
						$self->get_attrib('card_cvvcid'));
					}
				elsif ($payment_method eq 'ECHECK') {
					$legacyref->{'note'} = sprintf("eCheck %s",$self->get_attrib('echeck_acct_number'));
					$legacyref->{'auth'} = $self->get_attrib('echeck_auth_transaction');
					$legacyref->{'txn'} = $self->get_attrib('echeck_bill_transaction');
					$legacyref->{'debug'} = $self->get_attrib('payment_cc_results');
					$legacyref->{'acct'} = sprintf("|ER:%s|EA:%s",
						$self->get_attrib('echeck_aba_number'),
						$self->get_attrib('echeck_acct_number'));
						# echeck_bank_name, echeck_bank_state, echeck_aba_number, echeck_acct_number, echeck_acct_name, echeck_check_number
					}
				elsif ($payment_method eq 'PO') {
					$legacyref->{'note'} = sprintf("PO %s",$self->get_attrib('po_number'));
					}
				elsif ($payment_method eq 'EBAY') {
					$legacyref->{'note'} = sprintf("eBay %s",$self->get_attrib('payment_authorization'));
					}
				elsif (($payment_method eq 'PAYPALEC') || ($payment_method eq 'PAYPAL')) {
					$legacyref->{'note'} = sprintf("Paypal %s",$self->get_attrib('payment_authorization'));
					$legacyref->{'auth'} = $self->get_attrib('cc_auth_transaction');
					}
				elsif ($payment_method eq 'GOOGLE') {
					$legacyref->{'note'} = sprintf("Google %s",$self->get_attrib('google_orderid'));
					}
				elsif ($payment_method eq 'AMAZON') {
					$legacyref->{'note'} = sprintf("Amazon %s",$self->get_attrib('amazon_sessionid'));
					}
				elsif ($payment_method eq 'ZERO') {
					$legacyref->{'note'} = "No Payment Required";
					}
				elsif ($payment_method eq 'BUY') {
					}
				else {
					## eBay Paypal
					$legacyref->{'note'} = sprintf("%s",$payment_method);
					}
				}
			$self->{'version'} = 5;
			## end version 5 upgrade
			}

		## version 6 will remove the fields that were left by version 5
		if ($self->{'version'} < 6) {
			## upgrade mkt to mkts
			if (not defined $self->{'data'}->{'mkt'}) {
				# hmm.. must be one of those version 5 that has mkts set!
				}
			elsif (($self->{'data'}->{'mkts'} eq '') && ($self->{'data'}->{'mkt'}>0)) {
#				$self->{'data'}->{'mkts'} = &ZOOVY::bitstr(&ZOOVY::mkt_to_bitsref($self->{'data'}->{'mkt'}));
				}
			delete $self->{'data'}->{'mkt'};
			delete $self->{'mkt'};
			## remove commonly undef values.
			foreach my $key (
				'buysafe_totalbondcost',
				'buysafe_cartdetailsurl',
				'buysafe_bondingsignal',
				'buysafe_bondcostdisplaytext',
				'buysafe_cartdetailsdisplaytext',
				'ins_method',
				'ins_taxable',
				'ins_purchased',
				) {
				if (not defined $self->{'data'}->{$key}) { delete $self->{'data'}->{$key}; }
				}
			## remove full product details, and undef attributes.
			foreach my $stid ($self->stuff()->stids()) {
				my $item = $self->stuff()->item($stid);
				delete $item->{'full_product'};
				foreach my $k (keys %{$item}) {
					if (not defined $item->{$k}) { delete $item->{$k}; }
					}
				}
			$self->{'version'} = 6;
			}

		if ($self->{'version'} < 8) {
			foreach my $stid ($self->stuff()->stids()) {
				my $item = $self->stuff()->item($stid);
				if (not defined $item) {
					}
				elsif (not defined $item->{'mkt'}) {
					}
				elsif ($item->{'mkt'} eq 'EBAY') {
					my ($ebayid,$txn) = split(/-/,$item->{'mktid'},2);
					$item->{'mkt'} = ($txn==0)?'EBA':'EBF';
					my $result = &ZOOVY::bitstr_bits($self->{'data'}->{'mkts'});
					push @{$result}, ($item->{'mkt'} eq 'EBA')?1:2;
					# $self->{'data'}->{'mkts'} = &ZOOVY::bitstr($result);
					}
            }

			if (not defined $self->{'data'}->{'sdomain'}) { 
				}
			elsif ($self->{'data'}->{'sdomain'} eq 'ebay.com') {
				my $result = &ZOOVY::bitstr_bits($self->{'data'}->{'mkts'});		
				push @{$result}, 1;
				# $self->{'data'}->{'mkts'} = &ZOOVY::bitstr($result);
				}
			if ($self->{'mkts'} ne $self->{'data'}->{'mkts'}) {
				$self->{'mkts'} = $self->{'data'}->{'mkts'};
				my ($odbh) = &DBINFO::db_user_connect($USERNAME);
				my $qtMKTS = $odbh->quote($self->{'data'}->{'mkts'});
				my $qtORDERID = $odbh->quote($self->mid());
				my $MID = &ZOOVY::resolve_mid($USERNAME);
				my ($TB) = &DBINFO::resolve_orders_tb($USERNAME,$MID);
				my $order_id_qt = $odbh->quote($ORDER_ID);
				my $pstmt = "update $TB set MKT_BITSTR=$qtMKTS where ORDERID=$order_id_qt and MID=$MID /* $USERNAME */";
				print STDERR "$pstmt\n";
				$odbh->do($pstmt);
				&DBINFO::db_user_close();
				}
			$self->{'version'} = 8;
			}


		if ($self->{'version'} < 9) {
			## 2011/11/04
			## cleanup some variables (mkt, mkts)
			if (($self->{'data'}->{'mkts'} eq '') && ($self->{'mkts'} ne '')) {
				## copy mkts to data.mkts 
				$self->{'data'}->{'mkts'} = $self->{'mkts'};
				}
			## note: at this point mkts and data.mkts are assumed to be the same
			## 		and data.mkts is assumed to be authoritative
			if ((defined $self->{'data'}->{'mkts'}) && ($self->{'data'}->{'mkts'} eq '') && ($self->{'data'}->{'mkt'}>0)) {
				## copy mkt to data.mkts and mkts
				# $self->{'data'}->{'mkts'} = &ZOOVY::bitstr(&ZOOVY::mkt_to_bitsref($self->{'data'}->{'mkt'}));
				$self->{'mkts'} = $self->{'data'}->{'mkts'};
				}
			delete $self->{'data'}->{'mkt'};
			delete $self->{'mkt'};
			delete $self->{'data'}->{'cc_authorization'};
			delete $self->{'data'}->{'payment_cc_results'};
			delete $self->{'data'}->{'payment_echeck_results'};
			delete $self->{'data'}->{'echeck_auth_transaction'};
			delete $self->{'data'}->{'echeck_bill_transaction'};
			delete $self->{'data'}->{'cvvcid_number'};
			delete $self->{'data'}->{'card_number'};
			$self->{'version'} = 9;
			}

		if ($self->{'version'} < 10) {
			## orders created before 12/13/2011 should have order_notes copied to private_notes (since they weren't necessarily public before then)
			if ($self->{'data'}->{'created'}>1323763200) {
				## the order was created since 12/13/2011
				}
			elsif ((defined $self->{'data'}->{'private_notes'}) && ($self->{'data'}->{'private_notes'} ne '')) {
				## we already have private notes, nothing can be done.
				}
			elsif ((not defined $self->{'data'}->{'order_notes'}) || ($self->{'data'}->{'order_notes'} ne '')) {
				## copy order_notes into private_notes
				$self->{'data'}->{'private_notes'} = $self->{'data'}->{'order_notes'};
				delete $self->{'data'}->{'order_notes'};
				}
			else {
				## no order notes, so we're fine.
				}
			$self->{'version'} = 10;
			}


		if ($self->{'version'} < 12) {
			## 2012/09/19   version 12
			$self->{'version'} = 12;

			## BILL_COUNTRYCODE IS REQUIRED (EVEN FOR US)
			if (defined $self->{'data'}->{'bill_countrycode'}) {
				}
			elsif (($self->{'data'}->{'bill_country'} eq 'US') || 
				 ($self->{'data'}->{'bill_country'} eq 'USA') || 
				 ($self->{'data'}->{'bill_country'} eq '') || 
				 (uc($self->{'data'}->{'bill_country'}) eq 'UNITED STATES')) {
				## DOMESTIC ORDER
				$self->{'data'}->{'bill_countrycode'} = 'US';
				}
			else {
				## INTERNATIONAL ORDER
				if (not defined $self->{'data'}->{'bill_countrycode'}) {
					## lookup country code if we don't already have it!
					require ZSHIP;
					($self->{'data'}->{'bill_countrycode'}) = &ZSHIP::fetch_country_shipcodes($self->{'data'}->{'bill_country'});
					}
				}
			delete $self->{'data'}->{'bill_country'};

			## SHIP_COUNTRYCODE IS REQUIRED (EVEN FOR US)
			if (defined $self->{'data'}->{'ship_countrycode'}) {
				}
			elsif (($self->{'data'}->{'ship_country'} eq 'US') || 
				 ($self->{'data'}->{'ship_country'} eq 'USA') || 
				 ($self->{'data'}->{'ship_country'} eq '') || 
				 (uc($self->{'data'}->{'ship_country'}) eq 'UNITED STATES')) {
				## DOMESTIC ORDER
				$self->{'data'}->{'ship_countrycode'} = 'US';
				}
			else {
				## INTERNATIONAL ORDER
				if (not defined $self->{'data'}->{'ship_countrycode'}) {
					## lookup country code if we don't already have it!
					require ZSHIP;
					($self->{'data'}->{'ship_countrycode'}) = &ZSHIP::fetch_country_shipcodes($self->{'data'}->{'ship_country'});
					}
				}
			delete $self->{'data'}->{'ship_country'};

			if ($self->{'data'}->{'ship_fullname'} && $self->{'data'}->{'ship_firstname'}) {
				delete $self->{'data'}->{'ship_fullname'};
				}

			if ($self->{'data'}->{'bill_fullname'} && $self->{'data'}->{'bill_firstname'}) {
				delete $self->{'data'}->{'bill_fullname'};
				}

			#if ($self->{'data'}->{'ship_countrycode'} eq 'US') {
			#	if (not defined $self->{'data'}->{'ship_zip'}) { $self->{'data'}->{'ship_zip'} = $self->{'data'}->{'ship_int_zip'}; }
			#	delete $self->{'data'}->{'ship_int_zip'};
			#	}
			#elsif ($self->{'data'}->{'ship_int_zip'}) {
			#	$self->{'data'}->{'zip'} = $self->{'data'}->{'ship_int_zip'};
			#	delete $self->{'data'}->{'ship_int_zip'};
			#	}

			#if ($self->{'data'}->{'ship_countrycode'} eq 'US') {
			#	if (not defined $self->{'data'}->{'ship_city'}) { $self->{'data'}->{'ship_city'} = $self->{'data'}->{'ship_province'}; }
			#	delete $self->{'data'}->{'ship_province'};
			#	}
			#elsif ($self->{'data'}->{'ship_province'}) {
			#	$self->{'data'}->{'zip'} = $self->{'data'}->{'ship_province'};
			#	delete $self->{'data'}->{'ship_province'};
			#	}

			#if ($self->{'data'}->{'bill_countrycode'} eq 'US') {
			#	if (not defined $self->{'data'}->{'bill_zip'}) { $self->{'data'}->{'bill_zip'} = $self->{'data'}->{'bill_int_zip'}; }
			#	delete $self->{'data'}->{'bill_int_zip'};
			#	}
			#elsif ($self->{'data'}->{'bill_int_zip'}) {
			#	$self->{'data'}->{'zip'} = $self->{'data'}->{'bill_int_zip'};
			#	delete $self->{'data'}->{'bill_int_zip'};
			#	}

			if (defined $self->{'data'}->{'cvvcid_number'}) {
				## that's it.. no storing cvvcid_numbers
				delete $self->{'data'}->{'cvvcid_number'};
				}

			delete $self->{'data'}->{'payment_authorization'};
			delete $self->{'data'}->{'payment_last_message'};
			delete $self->{'data'}->{'ebaycheckout'};
			delete $self->{'data'}->{'aolsn'};
			delete $self->{'data'}->{'bnd_optional'};
			delete $self->{'data'}->{'account_manager'};
			delete $self->{'data'}->{'referred_by'};
			delete $self->{'data'}->{'jf_mid'};
			delete $self->{'data'}->{'jf_tid'};
			delete $self->{'data'}->{'ebates_ebs'};
			delete $self->{'data'}->{'buysafe_totalbondcost'};
			delete $self->{'data'}->{'buysafe_bondcostdisplaytext'};
			delete $self->{'data'}->{'buysafe_cartdetailsurl'};
			delete $self->{'data'}->{'buysafe_bondingsignal'};
			delete $self->{'data'}->{'buysafe_cartdetailsdisplaytext'};
			}


		## *** READ THIS WHEN ADDING NEW VERSIONS (AND UPGRADING TO THEM) ****
		## NOTE: if modified_gmt does not change, *AND* the order get's SYNCED_GMT set to zero,
		## then order manager will IGNORE the update (and not ack the order)
		##	order manager checks the pool, and modified_ts and if neither has changed then it assumes it's the
		## same order, and it basically goes on with it's life (and ignores the order).
		## not an ideal behavior, but hey.. we probably should have bumped the modified_gmt right?
		## this statement below runs in /root/configs/sql/clean-carts.sql
		## it sets the date to the international day of sanitition and water (jan 1st, 1980)
		## update ORDERS_0 set SYNCED_GMT=315561600 where SYNCED_GMT=0 and MODIFIED_GMT<unix_timestamp(date_sub(now(),interval 30 day));


#	if ( (uc($data->{'bill_country'}) eq 'USA') || (uc($data->{'bill_country'}) eq 'UNITED STATES') || (uc($data->{'bill_country'}) eq 'US')) {
#		$data->{'bill_country'} = '';
#		}
#	if ( (uc($data->{'ship_country'}) eq 'USA') || (uc($data->{'ship_country'}) eq 'UNITED STATES') || (uc($data->{'ship_country'}) eq 'US')) {
#		$data->{'ship_country'} = '';
#		}
#	if ($tax_rate>100) { $tax_rate = sprintf("%.2f",$tax_rate/100); }



		$self->{'version'} = int($self->{'version'});
		if ($options{'turbo'}) { return($self); }
		
		if (defined $self->{'data'}->{'shipped_gmt'}) {
			if (not defined $self->{'data'}->{'ship_date'}) {
				## migrate value.
				$self->{'data'}->{'ship_date'} = $self->{'data'}->{'shipped_gmt'};
				}
			delete $self->{'data'}->{'shipped_gmt'};
			}

		$self->recalculate(1);

		#if ($USERNAME eq 'digmodern') {
		#	if (defined $self->{'data'}->{'cvvcid_number'}) {
		#		## that's it.. no storing cvvcid_numbers
		#		delete $self->{'data'}->{'cvvcid_number'};
		#		}
		#	}

		return $self;
		}


	&msg("Unable to load information for $USERNAME $ORDER_ID (no file found)");
	return undef, "Unable to load information for $USERNAME $ORDER_ID (no file found)";
	}



##
## cardsref is a hashref keyed by cardid
##
##	OPTIONS
##		luser=>'*checkout'
##
sub addGiftCards {
	die();
	return();
	}





######################################################################################
## $o->check()
######################################################################################
## Purpose: Checks the order object to make sure everything is in order (if you'll
##          pardon the pun)
## Accepts: Order Object,
##          $username (optional makes sure the username stored in the object is right)
##          $order_id (optional makes sure the ID stored in the object is the same)
##          $strict (whether or not we should check that pool, etc. are set)
## Returns: An error string on failure, and a blank string on success
sub check {
	my ($self, $username, $order_id, $strict) = @_;
	## Make sure the order object is defined

	if (not defined $self) {
		return 'Order object not defined';
		}
	## Make sure the order object is hash-based and that its an oRDER object
	if ((not scalar keys %{$self}) && (ref($self) ne 'ORDER')) {
		return 'Order object appears to be corrupt';
		}
	## Make sure we got a hashref of attributes for the order
	if ((not defined $self->{'data'}) || (ref($self->{'data'}) ne 'HASH')) {
		return 'Order appears to have corrupt data';
		}
	## Make sure we got STUFF and that perl thinks the object is a STUFF
	if ((not defined $self->{'stuff'}) || (ref($self->{'stuff'}) ne 'STUFF')) {
		return 'Order does not appear to have STUFF format contents';
		}
	## Make sure there's a username
	if (not defined $self->{'username'}) {
		return 'Order does not contain merchant user';
		}
	## Make sure if there's a username passed to check against that it matches the one in the object
	if (def($username) && (uc(def($username)) ne uc($self->{'username'}))) {
		return 'Check failed: merchant parameter does not match merchant in order file.'
		}
	## Make sure there's an order_id
	if (not defined $self->{'order_id'}) {
		return 'Order ID does not exist in order file';
		}
	## If we were passed an order_id to check against, check that the one in the object matches
	if (def($order_id) && (def($order_id) ne $self->{'order_id'})) {
		return 'Check Order ID does not match object Order ID';
		}
	
	## Extra params to make sure weve got everything we need in the order object,
	## even stuff from the database
	if (pint($strict)) {
		if ((not defined $self->{'data'}->{'pool'}) || ($self->{'data'}->{'pool'} eq '')) {
			return 'Order appears not to have a pool/status';
			}
		if ((not defined $self->{'data'}->{'created'}) || (not $self->{'data'}->{'created'})) {
			return 'Order appears not to have a created timestamp';
			}
		if ((not defined $self->{'data'}->{'timestamp'}) || (not $self->{'data'}->{'timestamp'})) {
			return 'Order appears not to have a modified timestamp';
			}
		}

	return '';
	}




## Recalculate the order total.
## Returns a 1 if the new total is different than the old one, 0 if not.
sub recalculate {

	my ($self, $nosave) = @_;

	if ($self->{'order_id'} eq '*') { $nosave = 1; }

	## Get the original total so we can tell the caller whether the total changed

	my $data = $self->{'data'};
	my $orig_order_total = cashy($data->{'order_total'});
	my $totals = $self->stuff->sum();
	# (my $subtotal, my $weight, undef, my $tax_subtotal, my $items) = $stuff->totals();
	
	my $order_total_i = $totals->{'items.subtotal.int'};
	my $tax_subtotal_i = $totals->{'tax.subtotal.int'};

	foreach my $field (qw(shp hnd ins spc spx spy spz bnd)) {
		next if (not defined $data->{$field.'_total'});
		my $tot_i = &f2int($data->{$field.'_total'}*100); 
		next if ($tot_i == 0);
		my $is_taxable = bool($data->{$field.'_taxable'}); 
		$order_total_i += $tot_i;
		if ($is_taxable) { $tax_subtotal_i += $tot_i; }
		}


	$data->{'state_tax_rate'} = gnum($data->{'state_tax_rate'});
	$data->{'local_tax_rate'} = gnum($data->{'local_tax_rate'});

	if ( (uc($data->{'bill_country'}) eq 'USA') || (uc($data->{'bill_country'}) eq 'UNITED STATES') || (uc($data->{'bill_country'}) eq 'US')) {
		$data->{'bill_country'} = '';
		}
	if ( (uc($data->{'ship_country'}) eq 'USA') || (uc($data->{'ship_country'}) eq 'UNITED STATES') || (uc($data->{'ship_country'}) eq 'US')) {
		$data->{'ship_country'} = '';
		}
	my $tax_rate = $data->{'state_tax_rate'} + $data->{'local_tax_rate'};
	
	## Enterprise fix up - since enterprise stores tax as two integers (825) instead of 8.25
	## NOTE: this is safe because we never have a tax rate > 100) 
	if ($tax_rate>100) { $tax_rate = sprintf("%.2f",$tax_rate/100); }

	## NOTE: it seems like amazon truncates/doesn't round the sales tax (invalid) not sure.
	## NOTE: we need to do a sprintf("%0.0f") here so it rounds properly (ex: 622.75 becomes 623)
	my $take_a_penny_leave_a_penny = 0;
	my $tax_total_i = &f2int(sprintf("%0.0f",$tax_subtotal_i * ($tax_rate/100)));
	if (&f2int($tax_subtotal_i * ($tax_rate/100))+1 == $tax_total_i) {
		## sometimes we find cases where tax rounding didn't occur (ex. at the marketplace level)
		## so we institute take_a_penny_leave_a_penny mode which allows totals within 0.01 to match as paid.
		$take_a_penny_leave_a_penny++; 
		}
	$order_total_i += $tax_total_i;
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


	foreach my $payment (@{$self->{'payments'}}) {
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
		if (($order_total_i == 0) && ($totals->{'items.count'}>0)) {
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
	elsif (scalar(@{$self->{'payments'}})==1) {
		## we only have one payment (whew) so we'll use it's payment status.
		$payment_status = $self->{'payments'}->[0]->{'ps'};
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
		print STDERR "balance_due_i: $balance_due_i\n";
		print STDERR "balance_paid_i: $balance_paid_i\n";
		print STDERR "balance_authorized_i: $balance_authorized_i\n";
		print STDERR "order_total_i: $order_total_i\n";
		$payment_status = '990';
		# $data->{'990_reason'} = "balance_paid:$balance_paid order_total:$order_total";
		}


	# print "ORDER: $order_total BALANCE: $balance_due\n";
	if (not defined $data->{'paid_date'}) { $data->{'paid_date'} = 0; }

	if (not defined $data->{'payment_status'}) {
		push @{$self->{'@updates'}}, ['payment_status',$payment_status,'recalc payment_status initialized'];
		}
	elsif ($data->{'payment_status'} ne $payment_status) {
		push @{$self->{'@updates'}}, ['payment_status',$payment_status,'recalc payment_status changed'];
		}
	elsif (($data->{'paid_date'}==0) && ($balance_due_i == 0)) {
		push @{$self->{'@updates'}}, ['payment_status',$payment_status,'recalc detected paid_date was not set on balance_due'];
		}
	elsif ($data->{'paid_date'}>0) {
		## order is paid, make sure we have a payment event otherwise we run paid
		my $found_paid_event = 0;
		foreach my $d (@{$self->{'@dispatch'}}) {
			if ($d->[0] eq 'paid') { $found_paid_event++; }
			}
		if (not $found_paid_event) {
			push @{$self->{'@updates'}}, ['payment_status',$payment_status,'no paid event found'];
			}
		}

	if (($payment_method eq 'MIXED') && (substr($payment_status,0,1) eq '0')) {
		## if we have a 'MIXED' payment method on a PAID (0xx) order, then we will attempt to go through
		## and ONLY look at paid payment methods (so anything that isn't paid, is ignored as part of the payment)
		$payment_method = undef;
		foreach my $payment (@{$self->{'payments'}}) {
			next if ($payment->{'puuid'} ne '');

			## set payment method to either the tender type or "MIXED"
			if ($payment->{'voided'}) {}
			elsif (substr($payment->{'ps'},0,1) ne '0') {}
			elsif (not defined $payment_method) { $payment_method = $payment->{'tender'}; }
			elsif ($payment_method ne $payment->{'tender'}) { $payment_method = 'MIXED'; }
			}
		if (not defined $payment_method) { $payment_method = 'MIXED'; }
		}

 
	my @RESULTS = ();
	push @RESULTS, [ 'payment_method', $payment_method ];
	push @RESULTS, [ 'payment_status', $payment_status ];
	push @RESULTS, [ 'order_subtotal', sprintf("%.2f",$totals->{'items.subtotal'}) ];
	push @RESULTS, [ 'order_total', sprintf("%.2f",$order_total_i/100) ];
	push @RESULTS, [ 'balance_paid', sprintf("%.2f",$balance_paid_i/100) ];
	push @RESULTS, [ 'balance_due', sprintf("%.2f",$balance_due_i/100) ];
	push @RESULTS, [ 'balance_auth', sprintf("%.2f",$balance_authorized_i/100) ];
	push @RESULTS, [ 'tax_rate', $tax_rate ];
	push @RESULTS, [ 'tax_subtotal', sprintf("%.2f",$tax_subtotal_i/100) ];
	push @RESULTS, [ 'tax_total', sprintf("%.2f",$tax_total_i/100) ];
	push @RESULTS, [ 'product_count', $totals->{'items.count'} ];
	## now we see if any of the above attributes have changed and if so, we trigger a save (if necessary)

	# print Dumper(\@RESULTS);

	my $changed = 0;
	foreach my $set (@RESULTS) {
		if ((not defined $data->{$set->[0]}) || ($data->{$set->[0]} ne $set->[1])) {
			$changed++;
			$data->{$set->[0]} = $set->[1];
			}
		}

	
	if ($0 eq '-e') {
		# use Data::Dumper; print STDERR Dumper(\@RESULTS,$totals);
		}

	if (not $changed) {
		}
	elsif (bool($nosave)) {
		# if ($changed) { print STDERR "ORDER->recalculate detected changes, but did not save due to nosave"; }
		}
	else {
		$self->save();
		}

	return ($orig_order_total eq $data->{'order_total'}) ? 1 : 0;
	}

#sub filename {
#	my ($self) = @_;
#	unless (def($self->{'username'})) { return; }
#	unless (def($self->{'order_id'})) { return; }
#
#   if ($self->{'order_id'} !~ /^20[\d]{2,2}\-[\d]{2,2}\-[\d]{1,6}$/) {
##		warn "Requested filename for invalid order $self->{'order_id'}\n";
#		return('');
#		}
#
#	my $path = &ZOOVY::resolve_userpath($self->{'username'});
#	unless (def($path)) { return; }
#	my ($year, $month, $id) = split('-', $self->{'order_id'});
#
#	if ((not defined $self->{'type'}) || ($self->{'type'} eq '')) {
#		return "$path/ORDERS/$year-$month/$id.bin";
#		}
#	elsif ($self->{'type'} eq 'supply') {
#		return "$path/SUPPLIERS/$year-$month/$id.bin";
#		}
#	}

## Sets an order attribute
sub set_attrib {
	set_attribs(@_);
	}

sub set_attribs {
	my ($self, %attribs) = @_;
	return unless (scalar keys %attribs);

	use Data::Dumper;
#	print STDERR "ATTRIBS: ".Dumper(\%attribs);
	foreach my $attrib (keys %attribs) {
#		print STDERR "$attrib\n";
		next if ($attrib eq 'mkt');	## this value cannot be overridden
		next unless ($attrib =~ m/^\w+$/);
		my $value = def($attribs{$attrib});
		if ($value eq '') { $self->unset_attrib($attrib); }
		else { $self->{'data'}->{$attrib} = $value; }
		}

	use Data::Dumper;
#	print STDERR Dumper($self);
	$self->recalculate(1);
	}

sub unset_attrib {
	my ($self, $attrib) = @_;
	return unless def($attrib);
	delete $self->{'data'}->{$attrib};
	$self->recalculate(1);
	}

## Gets an order attribute
sub get_attrib {
	my ($self, $attrib) = @_;
	return ($self->{'data'}->{$attrib});
	}

## Gets all order attributes
sub get_attribs {
	my ($self) = @_;
	return $self->{'data'};
	}

sub attribs {
	my ($self) = @_;
	return $self->{'data'};
	}


sub id {
	my ($self) = @_;
	return $self->{'order_id'};
	}

## Retrieves the order contents as a STUFF object
sub stuff {
	my ($self) = @_;

	if (ref($self->{'stuff'}) eq 'STUFF') {
		## yay, already initialized
		return($self->{'stuff'});
		}
	elsif (defined $self->{'stuff'}) {
		## hmm.. perhaps we just came off a serialized order and we haven't been blessed, better upgrade!
		return(STUFF->new($self->username(),'stuff'=>$self->{'stuff'}));
		}
	else {
		## better initialize a new stuff object
		$self->{'stuff'} = STUFF->new($self->username());
		return($self->{'stuff'});
		}
	}

sub set_stuff {
	my ($self, $stuff) = @_;
	$self->{'stuff'} = STUFF->new($self->username(),'stuff'=>$stuff);
	$self->recalculate(1);
	}

##
## Creates an order event - bitwise value
##		if etype is unset then it should be set to 64
##	   1: (on=safe to display to end user, off=merchant only)
##		2: designates it as a payment event
##		4: desginates it as a status change message
##		8: designates it as a priority message (warning/error and/or 
##		16: supply chain and/or shipping messages
##		32: marketplace events
##		64: reserved/other
##		128: debug message
##		256: order manager put this message in.
##
sub event {
	my ($self, $event, $ts, $etype, $luser, $uuid) = @_;

	if (not defined $ts) { $ts = time(); }
	elsif ($ts == 0) { $ts = time(); }	

	if (not defined $event) { $event = ''; }

	## p for patti!
	$event =~ s/[\<\>]+/-/g;

	if (not defined $etype) { $etype = 64; }
	if (not defined $self->{'events'}) {
		$self->{'events'} = [];
		}
	if (not defined $uuid) { $uuid = Data::GUID->new()->as_string(); };

	my $e = {
		'ts' =>sprintf("%d",$ts),
		'content' =>$event,
		'etype'=>sprintf("%d",$etype),
		'uuid'=>$uuid,
		'luser'=>$luser,
		'app'=>sprintf("%s:%s",&ZOOVY::servername(),&ZOOVY::appname()),
		};

	push @{$self->{'events'}}, $e;
	}


#sub paymentlog {
#	my ($self, $msg) = @_;
#
#	open F, ">>/dev/shm/payment5.log";
#	print F sprintf("%s\t%s\t%s\t%s\n",&ZTOOLKIT::pretty_date($self->{'data'}->{'created'},1),$self->username(),$self->oid(),$msg);
#	close F;
#	}


## Adds multiple events with the current timestamp
#sub events {
#	my ($self, @events) = @_;
#	my $ts = time();
#	foreach (@events) { 
#		my ($msg,$status,$luser) = split(/\|/,$_);
#		$self->event($msg, $ts,$status,$luser); 
#		}
#	}

## Gets all order events
#sub list_events {
#	my ($self) = @_;
#	return $self->{'events'};
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

	if (not defined $self->{'tracking'}) {
		$self->{'tracking'} = [];
		}

	my $track = $trkref->{'track'};
	$trkref->{'carrier'} = uc($trkref->{'carrier'});
	my $carrier = $trkref->{'carrier'};

	## verify this item doesn't already exist.
	my $found = 0;
	my $i = scalar( @{$self->{'tracking'}} );
	if ($i>1) { $self->{'data'}->{'flags'} |= (1<<7); } ## set flag 7: multiple shipments.
	while ((not $found) && ($i>0)) {
		$i--;
		if ($self->{'tracking'}->[$i]->{'track'} eq $track) {
			$self->{'tracking'}->[$i] = $trkref;
			$found++;
			}
		}

	if (not $found) {
		push @{$self->{'tracking'}},$trkref;
		$self->dispatch('ship');
		#if (($self->get_attrib('payment_method') eq 'GOOGLE') && ($track ne '')) {
		#	## DISPATCH/NOTIFY GOOGLE OF TRACKING #'s
		#	require ZPAY::GOOGLE;
		#	&ZPAY::GOOGLE::deliverOrder($self, $carrier, $track);
		#	}
		}
	##
	## SANITY: at this point $setthis is initialized to a blank hash in the array, 
	##				or to the existing hash in the array.

#	if ((not defined $self->{'data'}->{'shipped_gmt'}) || 
#		($self->{'data'}->{'shipped_gmt'}==0)) {
		## record the shipped date.
#		$self->set_attrib('shipped_gmt',time());
#		}
	## changed to ship_date 2009-05-19, this is what ZID uses
	if ((not defined $self->{'data'}->{'ship_date'}) || 
		($self->{'data'}->{'ship_date'}==0)) {
		## record the shipped date.
		$self->set_attrib('ship_date',time());
		}

	return($found);
	}

##
##	returns a ref to the tracking array
##		the array contains a hashref { carrier=>'' track=>'' cost=>'' notes=>'' }
##
sub tracking {
	my ($self) = @_;
	if (not defined $self->{'tracking'}) { my @ar = (); $self->{'tracking'} = \@ar; }
	return($self->{'tracking'});
	}


##
##	returns a ref to the tracking array
##		the array contains a hashref with {code=>'' amount=>'')
##		if you enable resolve then you also get:
##			name=>'',
##
sub fees {
	my ($self,$resolve) = @_;
	if (not defined $self->{'fees'}) { my @ar = (); $self->{'fees'} = \@ar; }
	## eventually we should probably do some resolution here!

	return($self->{'fees'});
}





sub payinfo {
	my ($self) = @_;

	my $error = $self->check();
	if ($error) {
		return "Unable to generate payinfo: $error";
		}

	require ZPAY;

	my $attribs = $self->{'data'};

	my $out;
	my ($paymethodref) = &ZPAY::lookup_method($attribs->{'payment_method'});

	if ($attribs->{'payment_method'} eq 'CREDIT') {
		$out = 'Credit Card ';
		$out .= ('X' x (length($attribs->{'card_number'}) - 4));
		$out .= substr($attribs->{'card_number'},-4,4) ;
		}
	elsif (defined $paymethodref) {
		# my %methods = &ZPAY::fetch_payment_methods_general();
		$out = 'Payment by ' . $paymethodref->[0];
		}
	else {
		$out = "Payment by $attribs->{'payment_method'}";
		}

	if (substr($attribs->{'payment_status'},0,1) eq '0') {
		$out .= "(Paid in Full)";	
		}
	elsif (substr($attribs->{'payment_status'},0,1) eq '2') {
		$out .= "(Denied)";
		}
	else {
		$out .= "(Pending)";
		}

	$out .= "\n";

	return $out;
}


##
## NOTE: Pass a value of 108 or higher for xcompat and 
##			you'll get a different version of stuff
##
## current high version: 108
##
sub as_xml {
	my ($self, $xcompat) = @_;
	my $XML = '';

	if (not defined $xcompat) { $xcompat = 107; }

	if (defined $self->{'data'}->{'modified'}) {
		delete $self->{'data'}->{'modified'};		# not used. confusing. use timestamp
		}

   if (not defined $self->{'data'}->{'timestamp'}) { 
		$self->{'data'}->{'timestamp'} = time()-1; 
		}

	my $order_id = $self->{'order_id'};
	## supplier_order_id is usually the same as the source order id.
	##	but it COULD be something different, it's not order_id.
	if (($order_id eq '*') && (defined $self->{'supplier_order_id'})) { $order_id = $self->{'supplier_order_id'}; }

	$XML .= "<ORDER ID=\"$order_id\" USER=\"$self->{'username'}\" V=\"$self->{'version'}\">\n";

	$XML .= "<DATA>\n";
	if (0) {
		## need to work with becky on how this will be structured
		# $XML .= "<MKTS>".&ZOOVY::bitstr(\@MKTS)."</MKTS>";
		}

	my $lock = $self->{'data'}->{'applock'};
	if (not defined $lock) { $lock = ''; }
	$XML .= "<APPLOCK>$lock</APPLOCK>";
	delete $self->{'data'}->{'applock'};
	delete $self->{'data'}->{'990_reason'};

	if ($self->{'data'}->{'bill_country'} eq 'US') {
		$self->{'data'}->{'bill_country'} = '';
		}

	if ($self->{'data'}->{'ship_country'} eq 'US') {
		$self->{'data'}->{'ship_country'} = '';
		}
	
	if ((not defined $self->{'data'}->{'profile'}) || ($self->{'data'}->{'profile'} eq '')) {
		## initialize profile from the prt
		$self->{'data'}->{'profile'} = &ZOOVY::prt_to_profile($self->username(),$self->prt());
		}

	if (length($self->{'data'}->{'private_notes'})>32768) {
		## limit private notes to something *huge* - fix for a bug with large private notes.
		$self->{'data'}->{'private_notes'} = substr($self->{'data'}->{'private_notes'},0,32768);
		}


	$XML .= &ZTOOLKIT::hashref_to_xmlish($self->{'data'},'encoder'=>'latin1');
	$self->{'data'}->{'applock'} = $lock;

	$XML .= "</DATA>\n";

	$XML .= "<STUFF>\n";
	my ($c,$error) = $self->stuff()->as_xml($xcompat);
	$XML .= $c;
	$XML .= "</STUFF>\n";

	$XML .= "<EVENTS>\n";
	$XML .= &ZTOOLKIT::arrayref_to_xmlish_list($self->{'events'},'tag'=>'event','encoder'=>'latin1','content_attrib'=>'content');
	$XML .= "</EVENTS>\n";

	if (defined $self->{'payments'}) {
		$XML .= "<PAYMENTS>\n";
		## note: need to copy puuid to puuid
		## 		need to copy r
		
		if ($xcompat < 200) {
			foreach my $pref (@{$self->payments()}) {
				$pref->{'ptxn'} = $pref->{'puuid'};
				}
			}

		$XML .= &ZTOOLKIT::arrayref_to_xmlish_list($self->payments(),'tag'=>'payment','encoder'=>'latin1','content_attrib'=>'content');
		$XML .= "</PAYMENTS>\n";
		}

	if (defined $self->{'fees'}) {
		$XML .= "<FEES>\n";
		$XML .= &ZTOOLKIT::arrayref_to_xmlish_list($self->fees(1),'tag'=>'fee','encoder'=>'latin1');
		$XML .= "</FEES>\n";
		}

	if (defined $self->{'tracking'}) {
		$XML .= "<TRACKING>\n";
		$XML .= &ZTOOLKIT::arrayref_to_xmlish_list($self->{'tracking'},'tag'=>'pkg','encoder'=>'latin1');
		$XML .= "</TRACKING>\n";
		}
	$XML .= "</ORDER>\n";

	## this should correct the wide byte error when attempting to encode as base64
	require Encode;
	$XML = Encode::encode("UTF-8",$XML);

	return($XML);
	}


##############################################################################
##
## ORDER::msg
##
## Purpose: Prints an error message to STDERR (the apache log file)
## Accepts: An error message as a string, or a reference to a variable (if a
##  reference, the name of the variable must be the next item in the
##  list, in the format that Data::Dumper wants it in).  For example:
##  &msg("This house is ON FIRE!!!");
##  &msg(\$foo=>'*foo');
##  &msg(\%foo=>'*foo');
## Returns: Nothing
##
sub msg
{
	my $head = 'ORDER: ';
	while ($_ = shift (@_))
	{
		if (ref) { require Data::Dumper; $_ = Data::Dumper->Dump([$_], [shift (@_)]); }
		print STDERR $head, join ("\n$head", split (/\n/, $_)), "\n";
	}
};



__DATA__

