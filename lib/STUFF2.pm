package STUFF2;

use strict;

use Clone;
use Data::Dumper;
use Carp;
use Digest::MD5;
use Data::GUID;
use lib '/backend/lib';
require ZWEBSITE;
require PRODUCT;
require PRODUCT::FLEXEDIT;
require POGS;
require ZSHIP;
require ZTOOLKIT;
require ZTOOLKIT;
require LISTING::MSGS;




##
##
##
sub def { ZTOOLKIT::def(@_); }
sub username { 
	if (not defined $_[0]->{'USERNAME'}) { warn Carp::cluck("USERNAME is not set on STUFF2 object\n"); }
	return($_[0]->{'USERNAME'}); 
	}



##
## the TO_JSON method is used by JSON::XS->new->utf8->allow_blessed(1)->convert_blessed(1)->encode($R);
##	(PAGE::JQUERY)
##
sub TO_JSON {
	my ($self) = @_;
	my @r = ();

	foreach my $item (@{$self->{'@ITEMS'}}) {
		my $i = Clone::clone($item);
		delete $i->{'%attribs'}->{'zoovy:base_cost'};
		push @r, $i;
		}
	return(\@r);
	}



sub getPRODUCT {
	my ($self, $pid) = @_;

	if (not defined $self->{'%PRODUCT_CACHE'}) {
		# warn "STUFF2 '%PRODUCT_CACHE'} was not pre-set on getP request\n";
		$self->{'%PRODUCT_CACHE'} = {};
		}

	my $P = $self->{'%PRODUCT_CACHE'}->{$pid};
	if (not defined $P) {
		$P = $self->{'%PRODUCT_CACHE'}->{$pid} = PRODUCT->new($self->username(),$pid,'create'=>0);
		# print STDERR 'FETCH P: '.Dumper($P,$self->username(),$pid);

		if (not defined $P) { $self->{'%PRODUCT_CACHE'}->{$pid} = ''; }
		}
	elsif (ref($P) eq '') {
		## this line is reached when getP has attempted this sku before, it failed, we shouldn't try it again.
		$P = undef;
		}

	return($P);
	}


## suggestions is an arrayref,.. 
##		[ A0, 00, 1, 'select', 'guess' ],
##		[ A1, 01, 2, 'checkbox', '..' ],
##
##	but cram needs selections (not suggestions) which are
##		'A0'=>00, 'A1'=>01'
##
sub variation_suggestions_to_selections {
	my ($suggested_variations) = @_;
	my %selections = ();
	foreach my $r (@{$suggested_variations}) {
		$selections{ $r->[0] } = $r->[1]; 
		}
	return(\%selections);
	}


##
## this is here temporarily as a compat. level for rules. somes rules get packages, which inherit lm,
##		othertimes (ex: global handling do_ship_rules gets a reference to stuff2->items() .. ugh, yeah so 
##		we have pooshmsg here for when $CART2->is_debug is true, these should ALWAYS 
##
sub pooshmsg {
	my ($self, $msg) = @_;
	if (not defined $_[0]->{'*CART2'}) {
		warn "STUFF2->pooshmsg -- no linked cart!?!? what should I do with: $msg\n";
		}
	else {
		$_[0]->{'*CART2'}->msgs()->pooshmsg($msg);
		}
	}


##
## NOTE: these fields are also set by hand when a CART is loaded from disk.
##			if they aren't set, all hell breaks loose.
##
sub cart2 { return($_[0]->{'*CART2'});  }
sub link_cart2 { 
	my ($self, $CART2, %params) = @_;

	## so when a cart is linked, certain properties of ours are pulled/synced with the cart
	##		starting with schedule, but possibly more.

	if (ref($CART2) ne 'CART2') {
		warn "COULD NOT STUFF::LINK_CART2 -- NON CART OBJECT PASSSED\n";
		}
	else {
		$self->{'*CART2'} = $CART2;

		if ($self->schedule() ne $CART2->schedule()) {
			$self->schedule($CART2->schedule());
			}
	
		if ($params{'caller'} eq 'init') {		
			}
		else {
			if (defined $self->cart2()) { $self->cart2()->sync_action("link2_cart",""); }
			}

		}

	return();
	}

##
## used to get/set a schedule
##
sub schedule { 
	my ($self, $schedule, %params) = @_;

	if (not defined $schedule) { 
		## no updates
		if (defined $self->cart2()) {
			## we're linked to a cart, so when this changes, we should use the value from the cart
			return( $self->cart2()->in_get('our/schedule') );
			}
		else {
			return($self->{'SCHEDULE'}); 
			}
		}
	else {
		## okay,we're not aking, we want to update the schedule
		$self->{'SCHEDULE'} = $schedule; 
		## now drop + re-add the items
		$self->{'@OLD'} = $self->{'@ITEMS'};
		$self->{'@ITEMS'} = [];
		foreach my $item (@{$self->{'@OLD'}}) {
			my %options = ();
			if ($item->{'%options'}) {
				foreach my $vdata (values %{$item->{'%options'}}) {
					## note: vdata is the VALUE -- we can discard the key
					$options{ $vdata->{'id'} } = $vdata->{'v'};
					if ($vdata->{'v'} eq '##') {  $options{ $vdata->{'id'} } = "~$vdata->{'data'}"; }
					}
				}
			my $item = $self->cram( 
				$item->{'product'}, $item->{'qty'}, \%options, 'added_gmt'=>$item->{'added_gmt'}, 
				);
			print STDERR Dumper($item)."\n";

			}
		delete $self->{'@OLD'};
		if (defined $self->cart2()) { $self->cart2()->sync_action("schedule","$schedule"); }
		}

	return($self->{'SCHEDULE'}); 
	}

## count($filter) 
## LEGACY COUNT USED BITWISE VALUE:
## purpose: returns a count of all items in the cart
##	opts is a bitwise operator
##		undef = all values default to false
##			1 = only count real items (e.g. no !META) 
##			2 = only count each item once, regardless of quantity
##			4 = include in count % items (this was added for amz orders)
##			8 = include in count only master assembly items, skip children (this was added for amz orders)
sub count { my ($self, %params) = @_; return( scalar( @{$self->items(%params)} )); }



sub new {
	my ($class, $USERNAME, %overrides) = @_;

	if ($USERNAME eq '') {
		Carp::confess("USERNAME is a required parameter for STUFF2");
		}

	my $self = {};
	$self->{'USERNAME'} = $USERNAME;
	$self->{'@ITEMS'} = [];
	$self->{'%PRODUCT_CACHE'} = {};	## a hashref (keyed by PID) for products in the cart (not serialized)

#	if ($params{'xml'}) {
#		## load this from xml
#		## $params{'xmlcompat'}
#		foreach my $item (@{STUFF::from_xml($params{'xml'},$params{'xmlcompat'})}) {
#			my $stid = $item->{'stid'};
#			if ($stid eq '') { $stid = $item->{'sku'}; $item->{'_warn'} = 'stid missing in new->from_xml'; }
#			if ($stid eq '') { $stid = Data::GUID->new()->as_string(); $item->{'_warn'} = 'stid,sku not set in new->from_xml - using random guid'; }
#			$self->{ $stid } = $item;
#			}
#		}

#	if ($params{'stuff'}) {
##		legacy method? do we still need this?
#		}

	bless $self, 'STUFF2';
	return($self);
	}


##
## returns an array (not ref) of stid's in items
##
sub stids {
	my ($self) = @_;

	my @STIDS = ();
	foreach my $item (@{$self->items()}) {
		push @STIDS, $item->{'stid'}; 
		}
	return(@STIDS);
	}

##
## returns an arrayref of items
## even if no items are found, it still returns an empty array 
##
## NOTE: replaces as_array() functionality
##	
sub items {
	my ($self, %params) = @_;

	if ($params{'@ITEMS'}) {
		## used by STUFF2::PACKAGE->sum
		return($params{'@ITEMS'});
		}

	my $show = $params{'show'};
	# if ($show eq 'real') { $show = 'real_only'; }

	my @ITEMS = ();
	if ((not defined $show) || ($show eq '')) {
		## no filter, all items (most dangerous)
		@ITEMS = @{$self->{'@ITEMS'}};
		}
	## NOTE: look at $CART2->has_supplychain_items
	#elsif ($show eq 'virtual') {
	#	foreach my $item ( @{$self->{'@ITEMS'}} ) {		
	#		next if ($item->{'is_promo'});
	#		my $virtual = undef;
	#		if (defined $item->{'virtual_ship'}) { $virtual = $item->{'virtual_ship'}; }
	#		if (defined $item->{'virtual'}) { $virtual = $item->{'virtual'}; }
	#		if ((not defined $virtual) || ($virtual eq '')) { $virtual = 'LOCAL'; }
	#		if ($virtual eq $show) {
	#			push @ITEMS, $item;
	#			}
	#		}
	#	}
	elsif ($show eq 'real') {
		foreach my $item ( @{$self->{'@ITEMS'}} ) {
			if (substr($item->{'stid'},0,1) eq '%') {
				## promo item
				}
			elsif ($item->{'is_promo'}) {
				## promo item
				}
			else {
				push @ITEMS, $item;
				}
			}
		}
	elsif ($show eq 'real+nogift') {
		## used for promotional calculations (real items, gift cards don't count)
		foreach my $item ( @{$self->{'@ITEMS'}} ) {
			if (substr($item->{'stid'},0,1) eq '%') {}			## promo item
			elsif ($item->{'is_promo'}) {}	## promo item
			elsif ($item->{'virtual'} eq 'GIFTCARD') {}	## giftcard
			else { push @ITEMS, $item; }
			}
		}
	elsif ($show eq 'real+noasm') {
		foreach my $item ( @{$self->{'@ITEMS'}} ) {
			if (substr($item->{'stid'},0,1) eq '%') {
				## promo item
				}
			elsif ($item->{'is_promo'}) {
				## promo item
				}
			elsif ($item->{'asm_master'}) {
				## assembly item
				}
			else {
				push @ITEMS, $item;
				}
			}
		}
	else {
		warn Carp::cluck("UNKNOWN STUFF2->items(".&ZTOOLKIT::buildparams(\%params).") [[[returning empty --hope that's what you wanted]]]\n");	
		}

	return(\@ITEMS);
	}


##
## ex: 
##		item('stid'=>$stid)
##		item('uuid'=>$uuid)
##
sub item {
	my ($self, $lookup, $value) = @_;
	my ($itemref) = undef;
	foreach my $item (@{$self->items()}) {
		next if (not defined $item->{$lookup});
		if ($item->{$lookup} eq $value) {
			$itemref = $item;
			}
		}
	return($itemref);
	}



##
##
##
sub drop {
	my ($self, $filter, $identifier) = @_;


	my @NEW_ITEMS = ();
	my $matched = 0;
	foreach my $itemref (@{$self->{'@ITEMS'}}) {
		if (($filter eq 'uuid') && ($itemref->{'uuid'} eq $identifier)) {
			$matched++;
			}
		elsif (($filter eq 'stid') && ($itemref->{'stid'} eq $identifier)) {
			$matched++;
			}
		elsif (($filter eq 'stid') && ($itemref->{'asm_master'} eq $identifier)) {
			## this doesn't technically count as a match (but it will be removed) 
			}
		else {
			push @NEW_ITEMS, $itemref;
			}
		}
	if ($matched>0) {
		$self->{'@ITEMS'} = \@NEW_ITEMS;
		if (defined $self->cart2()) { $self->cart2()->sync_action("drop","$filter=$identifier"); }
		}
	return($matched);
	}



## 
## this is used to copy an item from STUFF::CGI into @ITEMS once it's passed a few other validation checks
##
sub fast_copy_cram {
	my ($self, $item) = @_;
	push @{$self->{'@ITEMS'}}, $item;
	if (defined $self->cart2()) { $self->cart2()->sync_action("fast_copy_cram","$item->{'stid'}"); }
	}


## cram_promo
##
## overwrites any identical promo in the stuff
##
sub promo_cram {
	my ($self, $code, $qty, $amount, $title, %params) = @_;

	if (substr($code,0,1) ne '%') {
		warn "promo_cram code should always have a leading % -- adding one";
		$code = "%$code";
		}
	if ($code eq '%') {
		warn "promo code was not set, making something up";
		$code = "%promo-not-set-".time();
		}
	$code = uc($code);
	if ($code !~ /^\%[A-Z0-9\-\_\/\#]+$/) {
		warn "invalid charaters in promo_cram '$code' -- fixing";
		$code =~ s/[^A-Z0-9\-\_\/\#]+//gs;
		$code = "%$code";
		}
	if (length($code)>20) { 
		warn "promo code '$code' should not exceed 20 characters in length -- truncating to 20";
		$code = substr($code,0,20);
		}
	$params{'is_promo'} = 1;
	if (defined $self->cart2()) { 
		$self->cart2()->sync_action("promo_cram","$code qty=$qty amount=$amount"); 
		}
	if (not defined $qty) { $qty = 0; }

	return($self->basic_cram($code,$qty,$amount,$title,%params));
	}

##
## basic_cram is used to add items which aren't really products, 
##
sub basic_cram {
	my ($self, $stid, $qty, $amount, $title, %params) = @_;

#	print "CODE:$code\n";

	my $basicref = undef;
	foreach my $item (@{$self->{'@ITEMS'}}) {
		if ($item->{'stid'} eq $stid) {
			## replace this item.
			$basicref = $item;
			}
		}
	if (not defined $basicref) {
		$basicref = {};
		push @{$self->{'@ITEMS'}}, $basicref;
		}
	
	## at this point $promoref points at the promo ref we're updating
	if (not $params{'is_promo'}) { $params{'is_basic'}++; }
	$basicref->{'stid'} = $stid;
	$basicref->{'product'} = $stid;
	$basicref->{'sku'} = $stid;
	## fixed qty bug @ Sat Sep 15 10:16:27 PDT 2012
	$basicref->{'qty'} = $qty;
	$basicref->{'prod_name'} = $title;
	$basicref->{'prod_desc'} = $title;
	$basicref->{'price'} = $amount;

	foreach my $p (keys %params) {
		$basicref->{$p} = $params{$p};
		}

	if (defined $self->cart2()) { $self->cart2()->sync_action("basic_cram","$stid qty=$qty amount=$amount"); }
	return($basicref);
	}

##
##
##		pid =>
##		optionsref = { POGID=>POGVAL, or POGID=>~text (for textboxes)
##   	qty => the quantity of the item.  Zeros will delete the item
##
##		*P => reference to product object we're working with
##		make_pogs_optional		turns the "optional" flag on each option on, so that it is less likely to fail
##		*LM			references to an LISTING::MSGS object will be returned
##		check_inventory = 
##		asm_qty		# the quantity per parent 
##		force_qty
##		force_price => $price (with options)
##		optionstr => :A000/1234
##		mkt	(turns on some sane 'safe' fill in the blank (ex: checkbox goes from ON NO to "Not Set")
##		claim=>####
##		asm_master=> the sku in this list which is the assembly master sku
##		asm_processed=> tells us that the assemblies for this have already been processed.
##		zero_qty_okay
##
##	note: to emulate the old sku=>auto_detect_options behavior use $params{'optionstr'} = $invstr.$noninvstr;
#		if ((defined $item->{'sku'}) && ($params{'auto_detect_options'})) {
#			## this is perhaps a better way to do this, this is an elsif because we might still want to leave optionstr
#			## for example if we have a unique giftcard message or something then 'sku' is PID:ABCD and optionstr 
#			##	might be: /##01 
#			if (defined $LM) { $LM->pooshmsg("WARN|+using auto_detect_options sku: $SKU"); }
#	      ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($SKU);
#			$optionstr .= (($invopts)?":$invopts":"") . (($noinvopts)?"/$noinvopts":"");			
#			}
##					
## 
sub cram {
	my ($self, $pid, $qty, $optionsref, %params) = @_;


# price can be modified by any of the following:
#	claim
#	force_price (ex: marketplace)
#	wholesale/schedule or qtyprice
#	option modifiers (+/- % based on then current price, and subsequent modifiers)
#	

	my $item = {};
	if (defined $params{'uuid'}) {
		$item->{'uuid'} = substr($params{'uuid'},0,32);
		$item->{'uuid'} =~ s/-//gs;
		}
	else {
		$item->{'uuid'} = Data::GUID->new()->as_string();
		$item->{'uuid'} =~ s/-//gs;
		$item->{'uuid'} = substr($item->{'uuid'}, 0, 32);
		}

	my $lm = undef;
	if ((defined $params{'*LM'}) && (ref($params{'*LM'}) eq 'LISTING::MSGS')) { $lm = $params{'*LM'}; }
	if (not defined $lm) { $lm = LISTING::MSGS->new($self->username()); }

	$lm->{'STDERR'}++;

	my ($P) = $params{'*P'};
	if (not defined $P) { $P = PRODUCT->new($self->username(),$pid, 'CLAIM'=>int($params{'claim'})); }
	if (not defined $P) {
		$lm->pooshmsg("ERROR|msgid:9087|+Product '$pid' is not valid");
		}
	elsif (ref($P) ne 'PRODUCT') {
		$lm->pooshmsg("ERROR|msgid:9086|+PRODUCT pid=$pid is not defined");
		$P = undef;
		}

	## price 		: the price the person will pay
	## price_base	: the zoovy:base_price set by the item
	## price_schedule : price derived from schedule (and/or qtyprice)
	## price_options : price after option modifier fees are added 

	if ($lm->can_proceed()) {
		$item->{'product'} = uc($P->pid());
		$item->{'price'} = $item->{'base_price'} = $P->fetch('zoovy:base_price');
		$item->{'prod_name'} = $P->fetch('zoovy:prod_name');


		$item->{'base_weight'} = $P->fetch('zoovy:base_weight');
		$item->{'base_weight'} = ZSHIP::smart_weight($item->{'base_weight'});
		if (defined $item->{'base_weight'}) { $item->{'weight'} = $item->{'base_weight'}; }
		## TODO: validate weight ex: '1 lb.'

		if (not defined $item->{'taxable'}) { $item->{'taxable'} = $P->fetch('zoovy:taxable'); }
		$item->{'taxable'}     = &ZOOVY::is_true($item->{'taxable'});

		## do wholesale schedule stuff here.
		#my $check_inventory = 1;
		#if ($params{'check_inventory'}==0) {
		#	}
		#elsif (int($item->{'claim'}) > 0) {
		#	## i guess we probably shouldn't check inventory on claims 
		#	## note: this is important for the shipping calculator
		#	$check_inventory  = 0;
		#	}
		#elsif ($self->schedule() ne '') {
		#	require WHOLESALE;
		#	my $S = WHOLESALE::load_schedule($self->username(),$schedule);
		#	if (int($S->{'inventory_ignore'})==1) { $check_inventory = 0; }
		#	}
		}


	my $gref = &ZWEBSITE::fetch_globalref($self->username());


#	## BEGIN CLAIM/EXTERNAL ITEM
	if (not defined $P) {
		}
	elsif ($P->claim()>0) {
		
		foreach my $set (@{$P->claim_item_properties}) {
			## claim, mktuser, mktid, mkturl, mkt, claim_qty, claim_price, prod_name
			$item->{$set->[0]} = $set->[1];
			}		
		## re-add the claim back, if it got nuked during the option handling.
		$item->{'stid'} = sprintf("%s*%s",$item->{'claim'},$item->{'stid'});
		}
	else {
		if (defined $params{'mkt'}) { $item->{'mkt'} = $params{'mkt'}; }
		if (defined $params{'mktid'}) { $item->{'mktid'} = $params{'mktid'}; }
		}
#
#		## now scan the items to make sure another item with the same claim isn't already in the stuff
#		foreach my $sitem (@{$self->items()}) {
#			if ($sitem->{'claim'} == $item->{'claim'}) {
#				$lm->pooshmsg("WARN|claim #$sitem->{'claim'} ($sitem->{'prod_name'}) was removed");
#				$self->drop('stid'=>$sitem->{'stid'});
#				}
#			}
#
#		my $claimref = &EXTERNAL::fetchexternal_full($self->username(),$params{'claim'});
#		$item->{'force_price'} = $claimref->{'zoovy:base_price'};
#		$item->{'force_qty'} = $claimref->{'zoovy:quantity'};
#		$item->{'mkt'} = $claimref->{'zoovy:market'};
#		$item->{'mktid'} = $claimref->{'zoovy:marketid'};
#		$item->{'mkturl'} = $claimref->{'zoovy:marketurl'};
#		$item->{'mktuser'} = $claimref->{'zoovy:marketuser'};
#		$item->{'channel'} = $claimref->{'zoovy:channel'};
#		}
#	## END CLAIM/EXTERNAL ITEM

	if (not $lm->can_proceed()) {
		}
	elsif (not $P->has_variations('inv')) {
		$item->{'sku'} = $item->{'pid'};
		}
	else {
		## parse through the options, figure out what the SKU is .. we'll need this to figure out the price and assemblies.
		my $invopts = '';
		foreach my $pog (@{$P->fetch_pogs()}) {
			next unless ($pog->{'inv'});

			my $id = $pog->{'id'};
			next if ($id eq '');

			my $value  = $optionsref->{$id};
			foreach my $opt (@{$pog->{'@options'}}) {
				if ($opt->{'v'} eq $value) { $invopts .= ":$id$value"; }
				}
			}
		$item->{'sku'} = sprintf("%s%s",$pid,$invopts);

		if (my $price = $P->skufetch($item->{'sku'},'sku:price')) {
			if (defined $price) { $item->{'price'} = $price; }
			}
		if (my $cost = $P->skufetch($item->{'sku'},'sku:cost')) {
			if (defined $cost) { $item->{'cost'} = $cost; }
			}
		if (my $assembly = $P->skufetch($item->{'sku'},'sku:assembly')) {
			if (defined $assembly) { $item->{'assembly'} = $assembly; }
			}
		if (my $weight = $P->skufetch($item->{'sku'},'sku:weight')) {
			if (defined $weight) { $item->{'weight'} = $weight; }
			}
		}

	if ($params{'asm_master'}) {
		$item->{'orig_price'} = $item->{'price'};
		$item->{'price'} = 0;
		$item->{'asm_master'} = $params{'asm_master'};
		}
	elsif (defined $params{'force_price'}) {
		$item->{'orig_price'} = $item->{'price'};
		$item->{'price'} = $item->{'force_price'} = $params{'force_price'};
		}
	elsif ($item->{'claim_price'}) {
		$item->{'orig_price'} = $item->{'price'};
		$item->{'price'} = $item->{'claim_price'};
		}

	if (defined $params{'asm_qty'}) {
		$item->{'asm_qty'} = $params{'asm_qty'}; 
		}
	
	$item->{'qty'} = $qty;
	if ($params{'force_qty'}) {
		$item->{'qty'} = $item->{'force_qty'} = $params{'force_qty'};
		}
	elsif ($item->{'claim_qty'}) {
		$item->{'qty'} = $item->{'claim_qty'};
		}



	## BEGIN WHOLESALE PRICING
	if (not defined $P) {
		}
	elsif ($params{'claim'}>0) {
		## claim does not ever reference a schedule
		}
	elsif ($item->{'force_price'}>0) {
		## some other forced price (marketplace?)
		}
	elsif ($params{'asm_master'} ne '') {
		## we don't really compute price for assembly items (regardless of schedule)
		}
	elsif ($P->has_variations('inv')) {
		## we don't do schedule pricing here, it will be handled in the option section
		}
	elsif ($self->schedule() ne '') {
		my $result = $P->wholesale_tweak_product($self->schedule());
		foreach my $k ('schedule','qty_price') {
			$item->{$k} = $result->{"zoovy:$k"};			
			}

		$item->{'schedule_formula'} = $result->{'zoovy:schedule_price'};
		$item->{'schedule_price'} = $result->{'zoovy:base_price'};
		$item->{'schedule'} = $self->schedule();
		$item->{'qty_price'} = $result->{'zoovy:qty_price'};
		$item->{'price'} = $item->{'schedule_price'};	
		if (defined $result->{'schedule:minqty'}) {
			$item->{'minqty'} = $result->{'schedule:minqty'};
			}
		if (defined $result->{'schedule:incqty'}) {
			$item->{'incqty'} = $result->{'schedule:incqty'};
			}
		}		
	elsif ($P->fetch('zoovy:qty_price')) {
		my $result = $P->wholesale_tweak_product($self->schedule());
		foreach my $k ('schedule','qty_price') {
			$item->{$k} = $result->{"zoovy:$k"};	
			}
		}
	## END WHLESALE PRICING


	## note: force_qty is only run at the very beginning
	if (not defined $P) {
		}
	elsif (defined $item->{'force_qty'}) {
		}
	elsif (defined $item->{'claim_qty'}) {
		}
	elsif ($item->{'asm_master'}) {
		## note: minqty, incqty, maxqty, etc. don't apply to assemblies
		}
	elsif ($P->has_variations('inv')) {
		## we'll need to figure out the options before we can figure out the pricing.
		}
	else {
		# Compatibility for old qty users nytape, candlemakers, etc.
		if (defined $item->{'minqty'}) {
			}
		elsif (defined $P->fetch(sprintf("%s:minqty",$self->username()))) {
			$item->{'minqty'} = int($P->fetch(sprintf("%s:minqty",$self->username())));
			}

		if (defined $item->{'incqty'}) {
			}
		elsif (defined $P->fetch(sprintf("%s:incqty",$self->username()))) {
			$item->{'incqty'} = int($P->fetch(sprintf("%s:incqty",$self->username())));
			}

		if (defined $item->{'maxqty'}) {
			## not currently used
			}
		elsif (defined $P->fetch(sprintf("%s:maxqty",$self->username()))) {
			$item->{'maxqty'} = int($P->fetch(sprintf("%s:maxqty",$self->username())));
			}

		if (not defined $item->{'minqty'}) {}
		elsif ($item->{'minqty'} eq '') {}
		elsif ($item->{'qty'} < $item->{'minqty'}) {
			$item->{'qty'} = int($item->{'minqty'});
			# $message = "Minimum quantity for $stid is $item->{'qty_min'}";
			$lm->pooshmsg("WARN|msgid:9048|+Minimum quantity for $item->{'stid'} is $item->{'minqty'}");
			## NOTE: we need to keep the qty_max values so we can enforce them if the quantities change!
			}

	
		if (not defined $item->{'incqty'}) {}
		elsif ($item->{'incqty'} eq '') {}
		elsif (int($item->{'incqty'})<=0) {}
		elsif (($item->{'qty'} % $item->{'incqty'})>0) {
			# qty30 += 30 % 25 
			# 1 += 1 % 25
			$item->{'qty'} = int($item->{'qty'});
			$item->{'incqty'} = int($item->{'incqty'});
			if ($item->{'qty'}<$item->{'incqty'}) {
				$item->{'qty'} = $item->{'incqty'};
				}
			else {
				$item->{'qty'} += $item->{'incqty'} - ($item->{'qty'} % $item->{'incqty'});
				}
			$lm->pooshmsg("WARN|msgid:9047|+$item->{'stid'} must be purchased in quantities of $item->{'incqty'}, setting to $item->{'qty'}");
			## NOTE: we need to keep the qty_max values so we can enforce them if the quantities change!
			## delete $item->{'qty_increment'};
			}	

		if ((def($item->{'maxqty'}) ne '') && ($item->{'qty'} > $item->{'maxqty'})) {
			$item->{'qty'} = int($item->{'maxqty'});
			$lm->pooshmsg("WARN|msgid:9046|+Maximum quantity for $item->{'stid'} is $item->{'qty_max'}");
			## NOTE: we need to keep the qty_max values so we can enforce them if the quantities change!
			## delete $item->{'qty_max'};
			}
		}




	if (not defined $P) {
		}
	elsif ((defined $item->{'force_qty'}) || (defined $item->{'force_price'})) {
		}
	elsif ($item->{'qty_price'} ne '') {
		## note: if we have option price differences between base_price and $item->{'price'} we should add those
		my $newprice;
		foreach my $entry (split /[\,\n\r]+/, $item->{'qty_price'}) {
			my ($qtylimit,$operator,$qtyprice) = ($entry =~ m/^(.+?)(\=|\/)(.+?)$/);
			## qtylimit is the starting # allowed ex: must by 5
			## operator can be either / or =  (5=125 means buy 5 @ $125ea., 5/125 means buy 5 @ $25ea.)
	
			$qtylimit =~ s/\D//gs;		# strip non numeric from limit
			$qtyprice =~ s/[^\d\.]//gs;	# strip non numeric + decimal

			next unless ($qtylimit <= $item->{'qty'});		## this wont look at qty's below our current qty
			if ($operator eq '=') {
				$newprice = sprintf('%.2f', $qtyprice);
				}
			elsif ($operator eq '/') {
				$newprice = sprintf('%.2f', ($qtyprice/$qtylimit));
				}
			}

		## OLD NOTES: 
		## okay, so what happens if we have option modifiers which alter the base price.
		##	holy shit, yeah i know thats fucked up. so i've left a clue in STUFF->process_pog
		##	at the end it should set a variable called "pog_price_diff" in the item which we can
		## use here to add to the final price, this way the difference between base_price, and 
		##	modified base_price can be REAPPLIED to the $newprice .. that is of course assuming
		## this can be a little confusing though because when adding an item to the cart
		##	qty_price is run BEFORE process_pogs, so this line here is really only used when
		##	the customer decides to change the qty on a qty_price item that has option price modifiers.
		## yeah, i know how fucked up that is.
	
		## REMINDER: $newprice won't be set if there were no applicable qty price fields.
		if (defined $newprice) {
			$item->{'qty_base_price'} = $newprice;
			$item->{'price'} = $newprice; 
			}
		}
	
	my $needs_unique = 0;
	if ((defined $params{'needs_unique'}) && ($params{'needs_unique'})) { $needs_unique |= 8; }
	if (defined $optionsref->{'##'}) {
		# if ((defined $item->{'%options'}->{'##'}) && ($item->{'pogs'} eq '')) {
		## if we've got one or more text based option, (e.g. notes) then we may not have zoovy:pogs set, and that's okay.
		## but subsequent checks need too see something in item->pogs
		$lm->pooshmsg("ERROR|msgid:9080|+## option group is no longer allowed, use 'notes' instead");
		}

	##
	## shipping notes, or other types of notes (for secondact)
	## 	(i believe these are actually set in the cart stuff, by the website via ajax)
	##
	if (not defined $P) {
		}
	elsif (not defined $params{'notes'}) { 
		}
	else {
		$item->{'notes'} = $params{'notes'}; 
		$item->{'notes'} =~ s/^[\s]*(.*?)[\s]*$/$1/;		# strip leading and trailing whitespace.
		$needs_unique |= 4;
		#push @ITEM_POGS, {
		#	'_'=>sprintf('##%02d',$i),
		#	'id'=>'##',
		#	'v'=>sprintf("%02d",$i),
		#	'prompt'=>'Notes',
		#	'pretty'=>$item->{'notes'}
		#	}
		}

	## option handling
	my @ITEM_POGS = ();
	if (not $lm->can_proceed()) {
		## shit happened.
		}
	elsif ($P->has_variations('any')) {
		# my ($pogs2) = $P->fetch_pogs();

		## stage1: make sure we have options selected for any optional inventoriable options
		#foreach my $pog (@{$P->fetch_pogs()}) {
		#	next if ($pog->{'type'} eq 'attribs');
      #   #elsif ((not defined $value) && ($pog->{'optional'}==0)) {
		#	#	$err = "Pog mismatch: - cannot find pog ID $id ($pog->{'prompt'}) for product $item->{'product'}";
		#	#	}
		#	}

		my @CONST_POGS = ();
		## THERE ARE NO TILDES HERE!
		#print STDERR Dumper($optionsref);
		# $lm->pooshmsg("DEBUG|+optionsref: ".Dumper($optionsref));

		foreach my $pog (@{$P->fetch_pogs()}) {
			next if ($pog->{'type'} eq 'attribs');
			next if ($pog->{'type'} eq 'assembly');		## hey, assembly's should not be added to %options
			next if ($pog->{'type'} eq 'readonly');		## ignore readonly options

			my $id = $pog->{'id'};
			next if ($id eq '');

			my $err = undef;
			## hmm.. the cases below shouldn't really ever happen, but this makes sure we handle it
			if (not defined $pog->{'inv'}) { $pog->{'inv'} = 1; } 	# by default we assume the inventory is ON
			if (not defined $pog->{'type'}) { $pog->{'type'} = 'text'; }			# by default we assume it's a text pog.

			my $value  = $optionsref->{$id};
			if (($pog->{'type'} eq 'readonly') && (not defined $value)) { $value = ''; }
			# if (($pog->{'type'} eq 'assembly') && (not defined $value)) { $value = ''; }	## NO LONGER VALID??
			# implicitly makes pogs optional
			if ($params{'make_pogs_optional'}>0) {	
				if (not $pog->{'inv'}) { $pog->{'optional'} = 1; }
				}

			# my $meta = '';
			if ($err) {
				}
			elsif (($value eq '') && ($pog->{'optional'}>0)) {
				## this is optional, so we don't add it to the sequence since we'll skip it later.
				}
			elsif ($pog->{'type'} eq 'assembly') {
				$err = "Product '$item->{'product'}' variation $id - type assembly not allowed";
				}
			elsif (($pog->{'type'} eq 'textarea') || ($pog->{'type'} eq 'text')) {
				## usually text boxes don't REQUIRE values if they do we'll validate that separately in the text area
				## later with fields like # of chars, etc.  this prevents people from having to do 'optional' text boxes
				## if you change this value below then it's likely to break a few merchants / hurt sales because a lot of 
				## people have things like 'additional notes' which are not explicitly optional.
				if (not defined $pog->{'optional'}) { $pog->{'optional'} = 1; }
				}

			## NOTE: **if** we ever want to be stupid enough to auto-select inventoriable options -- this is NOT the code
			##			as far we're concerned, we're just cramming.. and if they have an optional + inventoriable 
			##			option with no value, that's a freaking error -- because it's a suicidal horrible idea, and frankly
			##			i don't want it in this code.
			if ($err) {
				}			
			elsif ((defined $value) && ($value ne '')) {
				## we have a value, we'll validate this later.
				}
			elsif ($pog->{'inv'}) {
				$err = "Product '$item->{'product'}' variation $id ($pog->{'prompt'}) impacts inventory/sku, and was not selected";
				}
			elsif ($pog->{'optional'} == 1) {
				## not required, no error
				}
			elsif (($pog->{'type'} eq 'cb') && ($params{'mkt'} ne '')) {
				## when mkt is turned on the 'cb' are allowed to be 'Not Set'
				## NOTE: we *really* ought to do the same thing for textboxes.
				}
			else {
				$err = "Product '$item->{'product'}' variation $id ($pog->{'prompt'}) must be selected.";
				}
				
			## CALCULATE FEES
			my $selected_opt = undef;
			my $user_text = undef;
			my ($fee,$feetxt) = (0,''); 
			if ($err) {
				}
			elsif (($value eq '') && ($pog->{'optional'}>0)) {
				## this puppy is optional, so it's no big deal we didn't get a value.
				## optional and blank.
				}
			elsif (($pog->{'type'} eq 'text') 
				|| ($pog->{'type'} eq 'textarea') 
				|| ($pog->{'type'} eq 'number') 
				|| ($pog->{'type'} eq 'readonly')
				|| $pog->{'type'} eq 'hidden') {
				## this is required/non-optional *OR* not blank.

				#if (substr($value,0,1) eq '~') {
				#	## THIS LINE IS NOT BEING RUN?? WTF SERIOUSLY??
				#	## strip stupid tilde which is added by %options so it can distinguish between an option and non/option
				#	## thanks you cock sucker anthony
				#	$value = substr($value,1);
				#	}

				$user_text = $value;
				$value = '##';	
				## handle fees.

				if ($user_text eq '') { }		# no text?? -- so nothing to do.
				elsif ($user_text eq '##') { }	# "##" from suggest_variations, ie nothing -- so nothing to do.
				elsif (($pog->{'type'} eq 'text') || ($pog->{'type'} eq 'textarea')) {
					## TODO: add fee_char fee_line and fee_word code
					if ($pog->{'fee_char'}>0) {
						my $chars = 0;
						foreach my $ch (split(//,uc($user_text))) { if ($ch =~ /[A-Z0-9]/) { $chars++; } }
						$fee += sprintf("%.2f",$pog->{'fee_char'}*$chars);
						$feetxt = "$chars characters ";
						}
					if ($pog->{'fee_word'}>0) {
						my @words = split(/\W+/, $user_text);
						my $words = scalar(@words);
						$fee += sprintf("%.2f",$pog->{'fee_word'}*$words);
						$feetxt .= "$words words ";
						}
					if ($pog->{'fee_line'}>0) {
						my @lines = split(/[\n\r]+/, $user_text);
						my $lines = scalar(@lines);
						$fee += sprintf("%.2f",$pog->{'fee_line'}*$lines);
						$feetxt .= "$lines lines ";
						}
					chop($feetxt);
					}
				}
			elsif ($pog->{'type'} eq 'calendar') {
				## TODO: add fee_rush code.
				# FORMAT: 01/18/2006 
				$user_text = $value;
				$value = '##';	
				## handle fees.

				require Date::Calc;
				my ($srcyear,$srcmonth,$srcday) = Date::Calc::Decode_Date_US($user_text);

				## added check 2009-02-10
				## invalid date supplied (was causing Delta_Days to bomb)
				if ($srcyear eq '' || $srcmonth eq '' || $srcday eq '') {
					$fee = 0;
					## no rush needed
					if ($pog->{'fee_rush'} eq '') { $feetxt = ''; }
					## this could be an issue, ie invalid date used to bomb, now gives $0 fee
					else { $feetxt = 'Invalid data format'; }
					}
				else {
					## valid date
					my ($days) = Date::Calc::Delta_Days(Date::Calc::Today(),$srcyear,$srcmonth,$srcday);
					# print STDERR "DAYS: $days [$pog->{'rush_days'}]\n";
					if ($days <= $pog->{'rush_days'}) {
						$feetxt = $pog->{'rush_prompt'};
						$fee += $pog->{'fee_rush'}; 
						}
					}
				}
			##
			## AT THIS POINT WE'RE DEALING WITH A SELECT BASE
			##
			elsif ($pog->{'type'} eq 'cb') {
				if ($value eq 'ON') { 
					$user_text = 'Yes'; 
					} 
				elsif ($value eq 'NO') { 
					$user_text = 'No'; 
					}
				elsif (($value eq '') && ($params{'mkt'} ne '')) {
					## YIPES marketplace order (so lets try NOT to throw an error eh?)
					$value = '##';  $user_text = 'Not Set';
					}
				elsif (($value ne 'ON') && ($value ne 'NO')) {
					# if i am neither ON or NO e.g. I'm "CRAZY!"
					$err = "Pog $id ($pog->{'prompt'}) value:$value mkt:$params{'mkt'} - badly formatted, checkboxes can only specify values ON and NO";
					}
				}
			elsif (scalar($pog->{'@options'})==0) {
				$err = "Pog $id ($pog->{'prompt'}) is corrupt and has no options to select";
				}
			elsif ($value eq '') {
				$err = "Pog $id ($pog->{'prompt'}) requires a value";
				}
			elsif ($value !~ m/^[\$\#a-zA-Z0-9][a-zA-Z0-9]$/) {
				## remember: swogs (system wide option groups) might start with a $
				$err = "Pog $id ($pog->{'prompt'}) mismatch badly formatted pog value '$value'";
				}
			else {
				##
				## "SELECT" BASE TYPE
				##
				foreach my $opt (@{$pog->{'@options'}}) {
					if ($opt->{'v'} eq $value) {	$selected_opt = $opt; }
					}

				if (defined $selected_opt) {
					$user_text = $selected_opt->{'prompt'};
					}
				else {
					$err = "Pog $id ($pog->{'prompt'}) specified option '$value' not found/no longer available";
					$user_text = 'Not Found';
					}
				}

			if ($err) {
				}
			elsif (not defined $item->{'price'}) {
				## if price is undef, don't set price to modifier value, since it will overwrite our chance
				## to inherit from zoovy:base_price later
				}
			elsif (not defined $selected_opt) {
				## this might be okay, especially if it was a checkbox
				}
			elsif ((not defined $selected_opt->{'p'}) || ($selected_opt->{'p'} eq '')) {
				## there is no price modifier
				}
			elsif ($item->{'force_price'}) {
				$fee = 0;
				$lm->pooshmsg("DEBUG|msgid:9059|+POG $selected_opt->{'id'} '$selected_opt->{'prompt'}' price modifier '$selected_opt->{'p'}' was ignored because of force_price");
				}
			elsif ($item->{'asm_master'}) {
				$fee = 0;
				$lm->pooshmsg("DEBUG|msgid:9058|+POG $selected_opt->{'id'} '$selected_opt->{'prompt'}' price modifier '$selected_opt->{'p'}' was ignored because of asm_master");
				}
			elsif ($item->{'claim'}>0) {
				$fee = 0;
				$lm->pooshmsg("DEBUG|msgid:9057|+POG $selected_opt->{'id'} '$selected_opt->{'prompt'}' price modifier '$selected_opt->{'p'}' was ignored because of claim $item->{'claim'}");
				}
			elsif (defined($selected_opt->{'p'}) && ($selected_opt->{'p'} ne '')) {
				$fee = sprintf('%.2f', calc_pog_modifier($item->{'price'}, $selected_opt->{'p'})-$item->{'price'});
				}

	
			# print STDERR "POG: $pog->{'id'} FEE: $fee PRICE: $price\n";
			if ($fee == 0) {
				}
			elsif (not defined $item->{'price'}) {
				## don't ever set $price if it wasn't already set, otherwise it won't properly inherit from
				## zoovy:base_price
				$lm->pooshmsg("WARN|msgid:9045|+item->price was not set");
				}
			elsif ($fee>0) { 
				## note: at some point we should really break these out into separate fields in %options
				if ($feetxt ne '') { $user_text .= " ($feetxt)"	;  }
				}

			my $optionstr = '';
			if ($err ne '') {
				}
			elsif (($value eq '') && ($pog->{'optional'}>0)) {
				## yeah, this isn't fubar, it's just.. umm.. optional.
				}
			elsif ($value eq '') {
				$err = "Pog $id ($pog->{'prompt'}) has fubar value corrupt (this line should never be reached)";
				}
			elsif ($pog->{'inv'}) {
				$optionstr = ":$id$value";
				}
			else {
				$optionstr = "/$id$value";
				}

			if ($err ne '') {
				print STDERR "POGERR:$err\n";
				## note: we keep $err separately because there are cases were we still want to add this product 
				##			even if it had very severe errors
				$lm->pooshmsg("ERROR|msgid:9079|+POG:$pog->{'id'}|+$err");
				}
			else {
				## NOTE: if @ITEM_POGS changes also change in STUFF2::schedule (where it does a re-cram)
				## if you change this you should also change STUFF2->as_xml
				push @ITEM_POGS, { 
					'_'=>$optionstr,
					'id'=>$pog->{'id'},
					'v'=>$value,
					'prompt'=>$pog->{'prompt'},  
					'data'=>$user_text,
					'inv'=>$pog->{'inv'},
					'fee'=>$fee,
					'feetxt'=>$feetxt
					};
				}			
			}
		}


	foreach my $pog (@ITEM_POGS) {
		if ($pog->{'v'} eq '##') { $needs_unique |= 1; }	## this has a text field
		}

	if ( (scalar(@ITEM_POGS)>0) || ($needs_unique) ) {
		my $description = $item->{'prod_name'};
		my @pog_sequence = (); ##  pog_sequence. item->pog_sequence = P1,P2,P3
		my $fees = 0;
		my $invopts = '';
		my $optionstr = '';	 # should be :A001:A101
		foreach my $option (@ITEM_POGS) {
			if ($option->{'inv'}>0) { $invopts .= sprintf(":%s%s",$option->{'id'},$option->{'v'}); }
			}
		$item->{'sku'} = sprintf("%s%s",$item->{'product'},$invopts);

		if ((defined $item->{'force_price'}) && ($item->{'force_price'} ne '')) {
			## we don't touch the price .. not amazon adds options for giftcard/unique messaging.
			}
		elsif ($invopts eq '') {
			## there are no inventoriable options, we don't need to modify the price
			## note: if you change this consider how qty_price will work with invopts
			}
		else {
			## use sku level pricing, which may be per schedule (if a schedule is set)
			my $PRICEKEY = 'sku:price';
			if ($self->schedule() ne '') { $PRICEKEY = lc(sprintf('zoovy:schedule_%s',$self->schedule())); }
			$item->{'price'} = $P->skufetch($item->{'sku'},$PRICEKEY) || $P->skufetch($item->{'sku'},'sku:price');
			}

		foreach my $option (@ITEM_POGS) {
			$description .= " / $option->{'prompt'}: $option->{'data'}";
			$item->{'%options'}->{sprintf("%s%s",$option->{'id'},$option->{'v'})} = $option;
			push @pog_sequence, $option->{'id'};
			if ($option->{'inv'}>0) {
				## no fees on inv options .. inv modifiers are purely advisory
				}
			elsif ($option->{'fee'}) { 
				$fees += $option->{'fee'}; 
				}

			if (length($optionstr)>50) {}	## don't allow longer than 50 characters in non-inv options
			elsif ($option->{'id'} eq '##') {} 	## always skip the text (unique) id
			else {
				$optionstr .= sprintf("%s%s%s",($option->{'inv'}?":":"/"),$option->{'id'},$option->{'v'}); 
				}
			}
		if ($needs_unique) { push @pog_sequence, "##"; }	## uniqueness will be added later.

		$item->{'description'} = $description;
		$item->{'pog_sequence'} = join(",",@pog_sequence);
		$item->{'optionstr'} = $optionstr;
		if ($fees!=0) {
			$item->{'price_orig'} = $item->{'price'};
			$item->{'price'} = $item->{'price'} + $fees;
			}
		$item->{'stid'} = sprintf("%s%s",$item->{'product'},$optionstr);
		if ($item->{'claim'}>0) { $item->{'stid'} = sprintf("%d*%s",$item->{'claim'},$item->{'stid'}); }

		}
	else {
		##
		## hmm.. well it doesn't have options. 
		##
		$item->{'pog_sequence'} = '';
		$item->{'description'} = $item->{'prod_name'};
		if (defined $lm) { $lm->pooshmsg("DEBUG|msgid:9057|+$item->{'product'}|+found no options for product '$item->{'product'}'"); }
		$item->{'sku'} = $item->{'product'};
		$item->{'stid'} = $item->{'product'};
		if ($item->{'claim'}>0) { $item->{'stid'} = sprintf("%d*%s",$item->{'claim'},$item->{'stid'}); }
		}

	if ($needs_unique) {	
		## note: ## was already added to pog sequence
		my $stid_suffix = undef;
		my $i = 0;  
		my $stid = $item->{'stid'};
		if (not $stid) { $stid = $item->{'product'}; }	## if we had no inv. options then stid isn't set.	

		while (not defined $stid_suffix) {
			$stid_suffix = sprintf("##%02d",$i);
			## ABC:1234 becomes ABC:1234/##00
			($stid_suffix) = ($self->item('stid'=>uc(sprintf("%s/%s",$stid,$stid_suffix))))?undef:$stid_suffix;
			last if (++$i > 99);
			} 
	
		if (not defined $stid_suffix) {
			$lm->pooshmsg("ERROR|msgid:9078|+No more of item $stid can be added to the cart (99 max)");
			}
		else {
			$item->{'stid'} = sprintf("%s/%s",$stid,$stid_suffix);
			}

		if ($params{'asm_master'} eq '') {
			# not in an assembly, make sure this isn't already in the cart, if it is.. well then shit.
			}
		}

	##
	## end of option and non-optio processing 
	##	NOTE: stid is not fully formed (and might be updated) because we need to check 'note' to see if it's unique
	##



	if ((defined $item->{'asm_master'}) && ($item->{'asm_master'} ne '')) {
		$item->{'stid'} = $item->{'asm_master'}.'@'.$item->{'stid'};
		}

	
	##	
	## sanity: at this point item{'product'}, item{'sku'}, item{'stid'} is set (but might be modified)
	##


	##
	## at this point STID is set, and should not change.
	##

	## Promotion API stuff!
	#foreach my $attrib (split /\,/,  def($webdb->{'dev_promotionapi_attribs'})) {
	#	next unless (def($item->{'full_product'}->{$attrib}) ne '');
	#	$item->{'%attribs'}->{$attrib} = $item->{'full_product'}->{$attrib};
	#	}	

	##
	## standard attribs we always copy (eventually these might be different based on the type of account purchased)
	##
	if (defined $P) {
		#foreach my $attrib (
		#	'zoovy:catalog','zoovy:prod_upc','zoovy:prod_isbn','zoovy:prod_mfg','zoovy:prod_supplier',
		#	'gc:blocked','paypalec:blocked',
		#	'zoovy:prod_asm', 'zoovy:prod_is',
		#	'zoovy:ship_latency',
		#	'zoovy:prod_supplierid','zoovy:prod_image1','zoovy:ship_handling','zoovy:ship_markup','zoovy:ship_insurance',
		#	'zoovy:ship_cost1','zoovy:pkg_depth','zoovy:pkg_height','zoovy:pkg_width','zoovy:pkg_exclusive', 'zoovy:pkg_multibox_ignore',
		#	'zoovy:prod_mfgid','zoovy:ship_mfgcountry','zoovy:ship_harmoncode','zoovy:ship_nmfccode',
		#	## needed for rules
		#	'zoovy:ship_sortclass', 'zoovy:prod_promoclass',  'zoovy:prod_class', 'zoovy:profile', 
		#	'is:shipfree','is:user1','is:sale',
		#	'user:prod_store_warehouse_loc',		# zephyrsports / zephyrcrew
		#	) {
		my $USERNAME = $self->username();
		foreach my $attrib (@{&PRODUCT::FLEXEDIT::cart_fields($USERNAME)}) {
			my $val = undef;
			if ($item->{'sku'} ne $item->{'product'}) {
				## this item has inventoriable options, let's see if we have a 'sku'=>1 field and if so we do a 'SKU' level lookup
				my $fieldref = $PRODUCT::FLEXEDIT::fields{ $attrib };
				if ($fieldref->{'sku'}) { $val = $P->skufetch($item->{'sku'}, $attrib); }
				}

			if (not defined $val) {
				$val = $P->fetch($attrib);
				}

			if ((defined $val) && ($val ne '')) {
				$item->{'%attribs'}->{$attrib} = $val;
				}
			}
		}


	## proces assemblies
	if (defined $P) {
		if (not $P->has_variations('inv')) {
			$item->{'assembly'} = $P->fetch('pid:assembly');
			}
		else {
			$item->{'assembly'} = $P->skufetch($item->{'sku'}, 'sku:assembly');
			}
		}

	if (defined $P) {
#		$item->{'description'} = def($item->{'description'}, $item->{'prod_name'});
		$item->{'cost'} 		  = $P->skufetch($item->{'sku'},'zoovy:base_cost');

		if (defined $P->skufetch($item->{'sku'},'zoovy:virtual_ship')) {
			$item->{'virtual_ship'} = $P->skufetch($item->{'sku'},'zoovy:virtual_ship');
			$item->{'%attribs'}->{'zoovy:virtual_ship'} = $P->skufetch($item->{'sku'},'zoovy:virtual_ship');
			}
		elsif (defined $P->fetch('zoovy:virtual_ship')) {
			$item->{'virtual_ship'} = $P->fetch('zoovy:virtual_ship');
			$item->{'%attribs'}->{'zoovy:virtual_ship'} = $P->fetch('zoovy:virtual_ship');
			}
	
		if (defined $P->skufetch($item->{'sku'},'zoovy:virtual')) {
			$item->{'virtual'} = $P->skufetch($item->{'sku'},'zoovy:virtual');
			$item->{'%attribs'}->{'zoovy:virtual'} = $P->skufetch($item->{'sku'},'zoovy:virtual');
			}
		elsif (defined $P->fetch('zoovy:virtual')) {
			$item->{'virtual'} = $P->fetch('zoovy:virtual');
			$item->{'%attribs'}->{'zoovy:virtual'} = $P->fetch('zoovy:virtual');
			}	
		}


	if ($item->{'qty'} < 0) {
		$lm->pooshmsg(sprintf("ERROR|msgid:9077|+Cram for %s failed: Negative quantities not allowed in cart",$self->username()));
		}
	elsif ($item->{'qty'} > 0) {
		$lm->pooshmsg("DETAIL|msgid:9030|+SKU '$item->{'sku'}' was added to the cart.");
		}
	elsif ((defined $params{'zero_qty_okay'}) && ($params{'zero_qty_okay'})) {
		## this is necessary -- because there are situations where we transport legacy cart params in a stuff2 
		## (mainly because i think this will be an easier upgrade) of course legacy cart params allow zero qty .. so fuck.
		## used by pogwizard.cgi
		if ($item->{'sku'}) {
			$lm->pooshmsg("DEBUG|msgid:9056|+SKU '$item->{'sku'}' has zero quantity (this is okay)");
			}
		elsif ($item->{'product'}) {
			$lm->pooshmsg("DEBUG|msgid:9055|+PRODUCT '$item->{'sku'}' has zero quantity (this is okay)");
			}
		elsif ($item->{'stid'}) {
			$lm->pooshmsg("DEBUG|msgid:9054|+STID '$item->{'stid'}' has zero quantity (this is okay)");
			}
		elsif ($item->{'uuid'}) {
			$lm->pooshmsg("DEBUG|msgid:9053|+UUID '$item->{'uuid'}' has zero quantity (this is okay)");
			}
		else {
			$lm->pooshmsg("ERROR|msgid:9076|+Received a request with no sku,product,stid and zero quantity.");
			}
		# $lm->pooshmsg("INFO|+Item $item->{'stid'} has zero quantity (this is okay)");
		# $lm->pooshmsg("DEBUG|+".Dumper($item));
		}
	elsif ($item->{'qty'} == 0) {
		$lm->pooshmsg("STOP|msgid:9089|+Item $item->{'stid'} removed from cart");
		$self->drop('stid'=>$item->{'stid'});
		}

	# print "WEIGHT: $item->{'base_weight'} $item->{'weight'}\n";

	## NOTE: weight will get reset later if we end up running process_pogs!


	if ((defined $params{'asm_processed'}) && (int($params{'asm_processed'})>0)) {
		## ORDER::AMAZON passes asm_processed=>500 -- it's code for "hey, you don't need to do assembly processing"
		warn "overrode asm_processed to $params{'asm_processed'} via params";
		$item->{'asm_processed'} = $params{'asm_processed'};
		}

	my %ASSEMBLE_THIS= ();
	if ($item->{'asm_master'} ne '') {
		## wow.. this is already part of an assembly (no sub assemblies)
		}	
	elsif (defined $item->{'asm_processed'}) {
		## skip this, we've already done it!
		}	
	elsif ((defined $item->{'assembly'}) && ( $item->{'assembly'} ne '')) {			
		## item kits
		##		the items of a kit have no individual price, and no individual weight.
		##		if any items in the kit cannot be added, then the entire sku cannot be purchased.
		my $asm = $item->{'assembly'};
		$lm->pooshmsg("DEBUG|msgid:9052|+ STUFF2-ASSEMBLY-PROCESSING ".Dumper($item));
		$asm =~ s/[ ]+//gs;	# remove spaces
		foreach my $skuqty (split(/,/,$asm)) {
			my ($SKU,$QTY) = split(/\*/,$skuqty);
			if (not defined $QTY) { $QTY = 1; }
			if ($QTY < 1) { $QTY = 0; $lm->pooshmsg("ERROR|msgid:9075|+ITEM '$item->{'stid'} ' contains assembly '$asm' which references component '$SKU'. Detected invalid quantity (postitive integer) or bad assembly format, use assembly format: STID1*QTY1,STID2*QTY2"); }
			if ($QTY>0) {
				if (not defined $ASSEMBLE_THIS{$SKU}) { $ASSEMBLE_THIS{$SKU}=0; }
				$ASSEMBLE_THIS{$SKU} += int($QTY);
				}
			}
		}


	## SANITY: at this point %ASSEMBLE_THIS is built out.. it has SKU=>qty  (qty does not reflect qty being purchased)


	if (($item->{'force_qty'}) || ($item->{'claim_qty'}) || ($item->{'asm_qty'})) {
		## yeah no fucking around here, we can't update the qty because it's forced
		my ($existingref) = $self->item( 'stid'=>$item->{'stid'} );
		if (defined $existingref) {
			$self->drop('stid'=>$item->{'stid'});
			}
		}
	elsif ($item->{'asm_master'} ne '') {
		## i can't imagine a reason this would EVER be true and force_qty wasn't set.
		$lm->pooshmsg("ISE|msgid:9029|+$item->{'stid'} assembly master was set, and asm_qty was not");
		}
	else {
		my ($existingref) = $self->item( 'stid'=>$item->{'stid'} );
		if (defined $existingref) {
			## add the item
			$lm->pooshmsg(sprintf("WARN|msgid:9090|+Item %s already in cart, adding %d", $item->{'stid'}, $item->{'qty'}));
			$self->drop('stid'=>$item->{'stid'});
			if (not defined $params{'*LM'}) { $params{'*LM'} = $lm; }
			if (not defined $params{'added_gmt'}) { $params{'added_gmt'} = $existingref->{'added_gmt'}; }
			($item,$lm) = $self->cram( $pid, $qty + $existingref->{'qty'}, $optionsref, %params );
			$lm->pooshmsg("STOP|msgid:9088|+Item in cart updated");
			}
		}



	if ($item->{'asm_master'} ne '') {
		## wow.. this is already part of an assembly (no sub assemblies)
		}	
	elsif (defined $item->{'asm_processed'}) {
		## already processed this.
		# print STDERR 'SKIPPED: '.Dumper($item->{'stid'});
		}
	elsif (scalar(keys %ASSEMBLE_THIS)>0) {
		my $mystid = $item->{'stid'};	
		## force_qty claims always allow assemblies to be purchased!
		if ($item->{'force_qty'}>0) {
			}
		elsif ((defined $item->{'claim'}) && ($item->{'claim'}>0)) {
			}
		else {
			##	return(1, "Some of the items in this kit are not available for purchase: ".join(',',keys %{$result}));
			}


		print STDERR Dumper(\%ASSEMBLE_THIS)."\n";

		foreach my $asmstid (keys %ASSEMBLE_THIS) {
			my %newitem = ();

			my ($asmpid,$asmclaim,$asminvopts,$asmnoinvopts,$asmvirtual) = &PRODUCT::stid_to_pid($asmstid);
			if (($asminvopts ne '') && (substr($asminvopts,0,1) ne ':')) { $asminvopts = ":$asminvopts"; }
			if (($asmnoinvopts ne '') && (substr($asmnoinvopts,0,1) ne ':')) { $asmnoinvopts = "/$asmnoinvopts"; }
			my ($asmsku) = $asmpid.(($asminvopts ne '')?"$asminvopts":'');
			if ($item->{'product'} eq $asmpid) {
				$lm->pooshmsg("ERROR|msgid:9074|+Assembly in $asmpid cannot reference itself"); # if we're trying to cram the same product, stop.
				}
			elsif ($item->{'sku'} eq $asmsku) { # if we're trying to cram the same sku, stop.
				$lm->pooshmsg("ERROR|msgid:9073|+Assembly in $asmsku cannot reference itself");
				}

			# my $asmoptionstr = "$asminvopts$asmnoinvopts";
			# print STDERR 'BLAH: '.Dumper(\%newitem); die();

			## dimensions for assembly sub components do not apply, the dimensional weight from the master item is used.
			#$newitem{'%attribs'}->{'zoovy:pkg_depth'} = 0;
			#$newitem{'%attribs'}->{'zoovy:pkg_height'} = 0;
			#$newitem{'%attribs'}->{'zoovy:pkg_width'} = 0;

			my ($asmP) = PRODUCT->new($self->username(),$asmpid);
			if (not defined $asmP) {
				$lm->pooshmsg("ERROR|msgid:9072|+Product '$asmpid' which is part of assembly for $item->{'product'} could not be loaded");
				}
			elsif ($asmP->pid() eq $item->{'product'}) {
				$lm->pooshmsg("ERROR|msgid:9071|+Product '$asmpid' references itself as part of an assembly");			
				}
			else {
				my $suggestions = $asmP->suggest_variations('stid'=>$asmstid);
				my $variations = STUFF2::variation_suggestions_to_selections($suggestions);
				$lm->pooshmsg("DEBUG|msgid:9051|+Cramming assembly:$asmpid");
				$self->cram( $asmpid, int($ASSEMBLE_THIS{$asmstid} * $item->{'qty'}), $variations, '*P'=>$asmP, 'force_price'=>0, 'asm_qty'=>int($ASSEMBLE_THIS{$asmstid}), 'asm_master'=>$item->{'stid'}, 
					# 'optionstr'=>$asmoptionstr,  ## 2012/10/13
					'*LM'=>$lm );
				}

			## note: some assembly items might have modifiers. e.g. p=3.50 which set the price
			##		and that is bad (except on option based assemblies which aren't done here)
			##		so we force the price to zero.
			}	
		}


	#use Data::Dumper;
	#print STDERR Dumper($self);

	## michaelc thinks keeping extended price is a good idea for future qty pricing, etc.
	## extended line is duplicated multiple times to keep everything sane (all may not be necessary)
	$item->{'extended'} = sprintf('%.2f', ($item->{'qty'} * $item->{'price'}));
	if (defined $params{'added_gmt'}) {
		$item->{'added_gmt'} = int($params{'added_gmt'});
		}
	else {
		$item->{'added_gmt'} = time();
		}

	## NOTE: promotion rules work off full_product
	#if (defined $item->{'full_product'}) {
	#	delete $item->{'full_product'};
	#	}

	## just some sanity checks
	if (not $lm->can_proceed()) {
		## somethin went wrong
		}
	elsif ($item->{'stid'} eq '') {
		$lm->pooshmsg("ISE|msgid:9028|+stid not set");
		}
	elsif ($item->{'price'} eq '') {
		$lm->pooshmsg("ISE|msgid:9027|+price not set");
		}
	elsif ((not $params{'zero_qty_okay'}) && (not $item->{'qty'})) {
		$lm->pooshmsg("ISE|msgid:9026|+qty not set");
		}

	if ($lm->can_proceed()) {
		## we use unshift to get new items to the top
		unshift @{$self->{'@ITEMS'}}, $item;
		if (defined $self->cart2()) { 
			# print STDERR "UNSHIFT:  $item->{'stid'}\n";
			$self->cart2()->sync_action("cram","$item->{'stid'} qty=$item->{'qty'} amount=$item->{'amount'}"); 
			}
		}

	return($item,$lm);
	}


##
## returns a new stuff2 object based on a stuff1 object
##
sub upgrade_legacy_stuff {
	my ($s1) = @_;
	my $self = STUFF2->new($s1->username());
	foreach my $item ( $s1->as_array() ) {
		my $olditem = Storable::dclone($item);
		if (defined $olditem->{'assembly_master'}) {
			$olditem->{'asm_master'} = $olditem->{'assembly_master'};
			delete $olditem->{'assembly_master'};
			}
		if (not defined $olditem->{'*options'}) {
			}
		elsif ($olditem->{'*options'} eq '') {
			## broken order
			}
		elsif (defined $olditem->{'*options'}) {
			$olditem->{'%options'} = $olditem->{'*options'};
			delete $olditem->{'*options'};
			foreach my $ref (values %{$olditem->{'%options'}}) {
				## inside %options the 'data' field becomes 'value'
				$ref->{'data'} = $ref->{'value'};
				delete $ref->{'value'};
				}
			}

		push @{$self->{'@ITEMS'}}, $olditem;
		}
	bless $self, 'STUFF2';
	return($self);
	}


##
##
##
sub as_legacy_stuff {
	my ($self) = @_;

	my ($s1) = STUFF->new($self->username());
	foreach my $item (@{$self->items()}) {
		my $newitem = Storable::dclone($item);

		$s1->{ $item->{'stid'} } = $newitem;

		$newitem->{'assembly_master'} = $item->{'asm_master'};
		delete $item->{'asm_master'};

		$newitem->{'*options'} = $newitem->{'%options'};
		delete $newitem->{'%options'};
		my $brok3d_options = 0;
		foreach my $ref (values %{$newitem->{'*options'}}) {
			## inside %options the 'data' field becomes 'value'
			if (ref($ref) ne 'HASH') {
				$brok3d_options++; 
				}
			else {
				$ref->{'value'} = $ref->{'data'};
				delete $ref->{'data'};
				}
			}
		if ($brok3d_options) {
			delete $newitem->{'*options'};
			}

		#if (defined $newitem->{'@options'}) {
		#	$newitem->{'%options'} = {};
		#	foreach my $kv (@{$newitem->{'@options'}}) {
		#		$newitem->{'%options'}->{ sprintf("%s%s", $kv->{'id'}, $kv->{'v'}) } = $kv;
		#		}
		#	}

		my $P = PRODUCT->new($self->username(),$newitem->{'product'},create=>0,CLAIM=>$newitem->{'claim'});
		if (defined $P) {
			$newitem->{'full_product'} = $P->prodref();
			}
		#if (not defined $P) {
		#	}
		#elsif ($item->{'claim'}>0) {
		#	$newitem->{'full_product'} = &EXTERNAL::fetch_as_hashref( $self->username(), $newitem->{'claim'},$newitem->{'sku'});
		#	}
		#else {
		#	$newitem->{'full_product'} = &ZOOVY::fetchproduct_as_hashref($self->username(),$newitem->{'product'});
		#	}
		delete $newitem->{'full_product'}->{'%SKU'};
		}

	return($s1);
	}


##
##
##
#sub as_legacy_cram_items {
#	my ($self) = @_;
#
#	my @ar = ();
#	foreach my $item (@{$self->items()}) {
#		next if ($item->{'asm_master'});	# skip assembly children
#
#		my %cramitem = ();
#		
#		$cramitem{'product'} = $item->{'product'};
#
#		##
#		##	**** BEWARE ****
#		##
#		## NOTE: STUFF::CGI::parse_products (aka STUFF::CGI::legacy_parse) incorrectly returned non inventoriable
#		##			options in the SKU and that was passed in the SKU field to legacy STUFF->cram which of course led
#		##			down the path to insanity.. and much time wasted debugging because sku isn't really the sku, it's
#		##			some bastardized version .. blah balh..
#		##			SO we always set %options, and *pogs which overrides whatever the hell STUFF->cram gets -- it lets
#		##			us cut a TON of shit and middlemen out of the way.. hopefully that's okay with everybody.
#		##			-BH 2012/09/13
#
#		$cramitem{'sku'} = $item->{'sku'};
#		#$cramitem{'stid'} = $item->{'stid'};
#		$cramitem{'qty'} = $item->{'qty'};
#		$cramitem{'prod_name'} = $item->{'prod_name'};
#		$cramitem{'base_weight'} = $item->{'base_weight'};
#		$cramitem{'base_price'} = $item->{'base_price'};
#		
#		if (defined $item->{'is_softcart'}) {
#			$cramitem{'full_product'} = {};
#			$cramitem{'taxable'} = $item->{'taxable'};
#			$cramitem{'%attribs'} = $item->{'%attribs'};
#			$cramitem{'notes'} = $item->{'notes'};
#			$cramitem{'notes_prompt'} = $item->{'notes_prompt'};
#			}
#	
#		if (defined $item->{'%options'}) {
#			## format is: 
#			# $cramitem{'pogs'} = undef;
#			$cramitem{'%options'} = {};
#			foreach my $vdata (values %{$item->{'%options'}}) {
#				## note: vdata is the VALUE -- we can discard the key
#				$cramitem{'%options'}->{ $vdata->{'id'} } = $vdata->{'v'};
#				## note: do not append a tilde here to data .. it's not needed (not sure why)
#				if ($vdata->{'v'} eq '##') {  $cramitem{'%options'}->{ $vdata->{'id'} } = "$vdata->{'data'}"; }
#				}
#			my ($P) = PRODUCT->new($self->username(),$item->{'product'});
#			$cramitem{'*pogs'} = $P->fetch_pogs();
#			# $cramitem{'full_product'}->{'@POGS'} = $P->fetch_pogs();
#			}		
#
#		push @ar, \%cramitem;
#		}
#
#	print STDERR 'ITEMS RETURNED TO CRAM: '.Dumper(\@ar);
#
#	return(\@ar);
#	}


##
## change this function under penalty of death. it has bugs. it has big fucking bugs.  
## when we have a library, use it. then we only have to fix the bug in one fucking spot.
## this broke checkout for almost 3 weeks. caused lots of support tickets and generally ruined
## my fucking day. if you change this I will fire you. -BH
##
sub calc_pog_modifier {
	my ($value, $modification) = @_;

	## tweak for handling equal (=) modifiers
	if ($modification eq '=') { $modification = ''; }
	if ($modification eq '') { return($value); }
	elsif ($modification =~ /[\+\-]+/) {
	   my ($diff,$pretty) = &ZOOVY::calc_modifier($value,$modification,1);
  		return($diff);
		}
	else {
		$modification =~ s/[^\d\.]//gs;
		return($modification);
		}

#	if ($modification =~ /\=/) { 
#		return($modification); 
#		}


#	return unless (defined $value);
#	return $value unless (defined $modification);
#	return $value unless ($modification =~ m/(\+|\-|\=\+|\=\-|\=)(.+)$/);
#
#	no warnings 'numeric';
#
#	my $modifier = $1;
#	my $amount = $2;
#
#	if ($amount =~ s/\%//gs)
#	{
#		$amount = ($value * $amount) / 100;
#	}
#
#	if    ($modifier eq '=')  { $value  = $amount; }
#	elsif ($modifier eq '+')  { $value += $amount; }
#	elsif ($modifier eq '=+') { $value += $amount; }
#	elsif ($modifier eq '-')  { $value -= $amount; }
#	elsif ($modifier eq '=-') { $value -= $amount; }
#
#	return $value;	
}


#sub DESTROY {
#	my ($self) = @_;
#
#	##
#	## NOTE: destroying the cart as such causes unpleasantness inside ZSHIP virtual handling.
#	##
#	}



##
## a digest representing items in the cart, and quantities.
##		if the cart changes, this will change guaranteed NOT to include pipes.
##
sub digest {
	my ($self) = @_;

	my $str = '';
	$str .= $self->username()."|";
	$str .= $self->schedule()."|";
	foreach my $item (@{$self->{'@ITEMS'}}) {
		$str .= $item->{'stid'}.'='.$item->{'qty'}.',';
		}
	$str = Digest::MD5::md5_base64($str);
	return($str);
	}


sub empty {
	my ($self) = @_;
	$self->{'@ITEMS'} = [];
	return($self);
	}


##
## params are:
##		*LM (highly recommended)
##
sub update_item_quantity {
	my ($self, $filter, $value, $qty, %params) = @_;

	my $item = undef;
	if ($filter eq '%item') { 
		$item = $value; 
		}
	else {
		$item = $self->item($filter=>$value);
		}
	my $stid = $item->{'stid'};
	#if ($stid =~ /\/$/) {
	#	warn "FOUND TrAILING SLASH";
	#	$stid =~ s/\/$//; # Remove trailing slash if present. (since it won't appear that way in the cart)
	#	}

	my $lm = undef;
	if ((defined $params{'*LM'}) && (ref($params{'*LM'}) eq 'LISTING::MSGS')) { $lm = $params{'*LM'}; }
	if (not defined $lm) { $lm = LISTING::MSGS->new($self->username()); }
	$lm->pooshmsg("DEBUG|msgid:9049|+UPDATE QUANTITY filter:$filter value:$value qty:$qty");
	if (not defined $item) {
		$lm->pooshmsg("ERROR|msgid:9070|+cannot locate stid '$stid'");
		}

	my $changes = 0;
	if ($item->{'force_qty'}) {
		$lm->pooshmsg("ERROR|msgid:9069|+cannot change quantity for stid '$stid' due to force_qty");
		}
	if ($item->{'claim'}>0) {
		$lm->pooshmsg("ERROR|msgid:9068|+cannot change quantity for stid '$stid' due to claim");
		}
	if ($item->{'asm_master'}>0) {
		$lm->pooshmsg("ERROR|msgid:9067|+cannot change quantity for stid '$stid' due to assembly component");
		}
	if ($item->{'is_promo'}>0) {
		$lm->pooshmsg("ERROR|msgid:9066|+cannot change quantity for stid '$stid' due to promo");
		}
 	## If force_qty is set for the sku, ignore this update	

	
	if ($lm->can_proceed()) {
		## enforce qty min
		if ((defined $item->{'minqty'}) && ($item->{'minqty'} > $qty)) {
			$qty = $item->{'minqty'};
			$lm->pooshmsg("DEBUG|msgid:9049|+$stid enforced minqty[$item->{'minqty'}] qty:$qty");
			}

		## enforce qty inc
		if (not defined $item->{'incqty'}) {}
		elsif (int($item->{'incqty'})<=0) {}
		elsif (($qty % $item->{'incqty'}) > 0) {
			$qty += ($item->{'incqty'} - ($qty % $item->{'incqty'}));
			$lm->pooshmsg("DEBUG|msgid:9049|+$stid enforced incqty[$item->{'incqty'}] qty:$qty");
			}

		## enforce qty max
		if (not defined $item->{'maxqty'}) {}
		elsif (int($item->{'maxqty'}) < $qty) {
			$qty = int($item->{'maxqty'});
			$lm->pooshmsg("DEBUG|msgid:9049|+$stid enforced maxqty[$item->{'maxqty'}] qty:$qty");
			}

		if (($qty > 0) && ($item->{'qty'} == $qty)) {
			## same quantity, no changes!
			}
		elsif ($qty > 0) { 
			$item->{'qty'} = $qty;
			if ((def($item->{'qty_price'}) ne '') && ($stid !~ m/\*/)) {
				&qty_price($item)
				}
			}
		elsif ($qty <= 0) {
			$lm->pooshmsg("DEBUG|msgid:9049|+$stid was dropped from cart due to qty=$qty");
			$self->drop('stid'=>$stid);
			}
		##
		## NOTE: DO NOT, UNDER ANY FUCKING CIRCUMSTANCES TOUCH $item after this line
		## 	or you're likely to have zero qty items appearing in the cart!
	
		##
		## Update the quantity for any assembly components
		##
		foreach my $asmitem (@{$self->items()}) {
			if ((not defined $asmitem->{'asm_master'}) || ($asmitem->{'asm_master'} eq '')) {
				## not an assembly
				}
			elsif ($asmitem->{'asm_master'} eq $item->{'stid'}) {
				$asmitem->{'qty'} = $item->{'qty'} * $asmitem->{'asm_qty'};
				}
			}

		## michaelc thinks keeping extended price is a good idea for future qty pricing, etc.
		## extended line is duplicated multiple times to keep everything sane (all may not be necessary)
		$item->{'extended'} = sprintf('%.2f', ($item->{'qty'} * $item->{'price'}));

		if (defined $self->cart2()) { 
			$self->cart2()->sync_action("update_qty","$item->{'stid'} qty=$qty amount=$item->{'amount'}"); 
			}
		}

	# print STDERR Dumper($item,$lm);

	return();
	}





sub as_xml {
	my ($self,$xcompat) = @_;
	my $xml = '';
	my $errors = '';

	foreach my $stuffitem (@{$self->items()}) {
		my $item = Storable::dclone($stuffitem);
		my $stid = $item->{'stid'};
		if (not defined $item->{'uuid'}) { $item->{'uuid'} = substr($item->{'stid'},0,32); }

		if (defined $item->{'buysafe_html'}) {
			## list of variables which should copied into attribs when going to as_xml
			delete $item->{'%attribs'}->{'buysafe:html'};
			delete $item->{'buysafe_html'};
			}
		
		my $extra = '';
		if ((defined $item->{'%options'}) && (ref($item->{'%options'}) eq 'HASH')) {
			my %opts = %{$item->{'%options'}};
			my $opt_xml = '';
			foreach my $id (keys %opts) {
				## id should be #Y01
				my $opt = $opts{$id};
				if (not defined $opt->{'_'}) { 
					$opt->{'_'} = $id; 
					}
				if (length($opt->{'_'})==5) { $opt->{'_'} = substr($opt->{'_'},1); }	# convert :##01 to ##01
				my $prompt = &ZTOOLKIT::encode_latin1(def($opt->{'prompt'}));
				my $data = &ZTOOLKIT::encode_latin1(def($opt->{'data'}));
				my $fee = &ZTOOLKIT::encode_latin1(def($opt->{'fee'}));
				my $feetxt = &ZTOOLKIT::encode_latin1(def($opt->{'feetxt'}));
				if ($xcompat < 210) {
					$opt_xml .= qq~<option id="$opt->{'_'}" prompt="$prompt" value="$data" modifier=""/>\n~;
					}
				else {
					## XCOMPAT > 210
					$opt_xml .= qq~<option id="$opt->{'_'}" prompt="$prompt" data="$data" inv="$opt->{'inv'}" fee="$fee" feetxt="$feetxt"/>\n~;
					}
				}
			$extra .= "<options>\n" . &ZTOOLKIT::entab($opt_xml) . "</options>\n";
			delete $item->{'%options'};
			}
		elsif (defined $item->{'%options'})  {
			warn "this line should never be reached!";
			}

		#if (defined $item->{'%fees'}) {
		#	my %fees = %{$item->{'%fees'}};
		#	my $fee_xml = '';
		#	foreach my $feeid (keys %fees) {
		#		if ($feeid !~ m/^[\w\:]+$/) {
		#			$errors .= "Feeid $feeid does not look valid\n";
		#			next;
		#			}
		#		my $id = $feeid;
		#		$id =~ s/\:/-/gs;
		#		my $value = encode_latin1(def($fees{$feeid}));
		#		$fee_xml .= qq~<$id>$value</$id>\n~;
		#		}
		#	$extra .= "<fees>\n" . entab($fee_xml) . "</fees>\n";
		#	delete $item->{'%fees'};
		#	}

		if (defined $item->{'%attribs'}) {
			my %attribs = %{$item->{'%attribs'}};
			my $attribs_xml = '';
			foreach my $attrib (keys %attribs) {
				next if ($attrib eq 'zoovy:pogs');
				my $value = &ZTOOLKIT::encode_latin1(def($attribs{$attrib}));
				my $id = &ZTOOLKIT::encode_latin1($attrib);
				$attribs_xml .= qq~<attrib id="$id" value="$value"/>\n~;
				}
			$extra .= "<attribs>\n" . &ZTOOLKIT::entab($attribs_xml) . "</attribs>\n";
			delete $item->{'%attribs'};
			}

		delete $item->{'*pogs'};

		my $attribs = '';
		foreach my $key (keys %{$item}) {
			next if (substr($key,0,1) eq '*');
			next if ($key eq 'id');		## id is hardcoded below
			my $skip = 0;
			
			if ($key eq 'full_product') {
				## it's okay if we don't include this.
				$skip++;
				}
			elsif ($key !~ m/^\w+$/) {
				$errors .= "Unable to process root-level stuff item attribute $key (bad key name), not output in XML\n";
				$skip++;
				}
			elsif (ref($item->{$key}) ne '') {
				$errors .= "Unable to process root-level stuff item attribute $key (non-scalar value), not output in XML\n";
				$skip++;
				}
			if (not $skip) {
				my $value = &ZTOOLKIT::encode_latin1(def($item->{$key}));
				$attribs .= qq~ $key="$value"~;
				}
			}
		$stid = &ZTOOLKIT::encode_latin1($stid);

		#if ($xcompat>=114) {
		#	## stid munging for assembly items
		#	##		e.g.  abc/123*xyz:ffff  becomes 123*abc/xyz:ffff
		#	my $newstid = '';
		#	if ($stid =~ /^(.*?)\*(.*?)$/) {
		#		my ($claim,$sku) = ($1,$2);
		#		if ($claim =~ /^(.*?)\/(.*)$/) {
		#			$newstid = "$2*$1/$sku";
		#			}
		#		}
		#	if ($newstid ne '') { $stid = $newstid; }
		#	}

		$xml .= qq~<item id="$stid"$attribs>\n~ . &ZTOOLKIT::entab($extra) . qq~</item>\n~;
		}

	return $xml, $errors;
}



sub from_xml {
	my ($data,$xcompat) = @_;


	my @items = ();

	if ($xcompat >= 220) {
		die("not supported");
		}
	elsif ($xcompat < 220) {
		require XML::Parser;
		require XML::Parser::EasyTree;
		# <product id="OPTION/20AK:1" price="12.75" qty="1" cost="6" weight="8" taxable="1" channel="0" mktid="" mkt="" mkturl="" mktuser="" batchno="" description="" notes="" prod_name="This is test of option group / Simple Colors: Blue / Gift Message: Happy Birthday!" sku="" base_price="0.0000" force_qty="0" pogs_processed="0" pogs_price_diff="0.00" pog_sequence="" base_weight="0" special="0" schedule="" qty_price="0.00" added_gmt="0" inv_mode="" extended="0.0000">\r
		my $p1 = new XML::Parser(Style=>'EasyTree');
		foreach my $p (split(/<\/item>/s,$data)) {
			next unless ($p =~ /\<item(.*?)\>(.*)$/s);
			my ($attribsxml,$optsxml) = ($1,$2);
	
			# print STDERR "XML: <item $attribsxml/>\n";
			my $ref = $p1->parse("<item $attribsxml/>");
			next if (not defined $ref);
			$ref = $ref->[0]->{'attrib'};		## ditches everything but the attributes.

			# my $ref = &ZTOOLKIT::xmlish_list_to_arrayref("<item $attribsxml></item>",tag_attrib=>'item',content_attrib=>'')->[0];
			# next if (not defined $ref);
			my $stid = $ref->{'id'};
			if (not defined $ref->{'stid'}) {
				$ref->{'stid'} = $stid;		## NOTE: stid is *required* by SETSTUFF macro
				}

			delete $ref->{'id'};	 		## id contains the stid, which is redundant and not part of the record
			push @items, $ref;

			if ( (int($ref->{'claim'}) == 0) && (index($stid,'*')>0) ) {
				## add claim back into order, since zom apparently doesn't send it to us.
				$ref->{'claim'} = substr($stid,0,index($stid,'*'));
				}
	
			## SANITY: at this point the stid should be added to stuff.				
			if ($optsxml =~ /<options>(.*?)<\/options>/s) {
	  	    	# <option id="040C" prompt="Gender" value="Mens" modifier=""/>
		      # <option id="A2" prompt="Order notes" value="" modifier=""/>
  	   	 	# <option id="A501" prompt="Costume Shoe Size" value="Medium (Sizes 10-11)" modifier=""/> 
				# becomes:
	         # '%options' => {                      
				#		'040C' => { 'value' => 'Mens', 'modifier' => '', 'prompt' => 'Gender' },
				#		'A2' => { 'value' => '', 'modifier' => '', 'prompt' => 'Order notes' },


				foreach my $tag (split(/(\<.*?\/\>)/s,$1)) {
					next if ($tag =~ /^[\t\s\n\r]*$/s);

					if (($xcompat <= 202) && ($tag =~ /\|prompt=/)) {
						## 2011-10-24 - so when we upgraded options to parse via xml, turns out becky wasn't encoding the
						##			modifier= section. so we'd end up with the modifier= below (notice the 24")
						## TAG: <option id="0107" modifier="v=07|prompt=M - 24"" prompt="Size" value="M - 24&quot;"/>
						## 		this little tidbit takes the 
						## TAG: <option id="0107" modifier="v=07|prompt=M - 24" prompt="Size" value="M - 24&quot;"/>
						# print STDERR "BROKE TAG: $tag\n";
						$tag =~ s/modifier=\"(.*?)\" prompt\=/modifier=\"**MODIFIER**\" prompt\=/gs;	
						my $modifier = $1;
						$modifier =~ s/[\"\<\>]+//gs;
						$tag =~ s/\*\*MODIFIER\*\*/$modifier/gs;
						# print STDERR "FIXED TAG: $tag\n";
						}

					## TAG: <attrib id="zoovy:prod_image1" value="platsilverplats"/>
					my $x = $p1->parse($tag);
					$x = $x->[0]->{'attrib'};

					$ref->{'%options'}->{ $x->{'id'} } = $x;
					delete $x->{'id'};
					## use Data::Dumper; print Dumper($x);
					}
 
				}


			if ($optsxml =~ /<attribs>(.*?)<\/attribs>/s) {
				foreach my $tag (split(/(\<.*?\/\>)/s,$1)) {
					next if ($tag =~ /^[\t\s\n\r]*$/s);
					# print STDERR "TAG: $tag\n";
					## TAG: <attrib id="zoovy:prod_image1" value="platsilverplats"/>
					my $x = $p1->parse($tag);
					$x = $x->[0]->{'attrib'};
					$ref->{'%attribs'}->{ $x->{'id'} } = $x->{'value'};
					## use Data::Dumper; print Dumper($x);
					}
				}
	
			if (defined $ref->{'%attribs'}) {
				## list of variables which should copied into attribs when going to as_xml
				if (defined $ref->{'%attribs'}->{'buysafe:html'}) {
					$ref->{'buysafe_html'} = $ref->{'%attribs'}->{'buysafe:html'};
					delete $ref->{'%attribs'}->{'buysafe:html'};
					}
				}
	
			## assembly master should never be SET to blank!
			if ($ref->{'asm_master'} eq '') {
				delete $ref->{'asm_master'};
				}
	
			}
		}
	
	return(\@items);	
	}




##
## this creates sum's for various items in the cart. values are described below (in about 10 lines)
##
## this will return a hashref (see below)
###	$items will be passed (unmodified) to items
###	%params: 
##			tax_rate sets the tax rate
##	
sub sum {
	my ($self, $items, %params) = @_;
	# print STDERR Carp::cluck(Dumper($items));

	my $tax_rate = $params{'tax_rate'};
	if ((not defined $tax_rate) || ($tax_rate eq '') || ($tax_rate !~ m/[0-9]*\.?[0-9]*/)) {
		$tax_rate = 0;
		}
	
	my %result = ();
	$result{'items_count'} = 0;
	$result{'pkg_cubic_inches'} = 0;
	$result{'pkg_weight_194'} = 0;
	$result{'pkg_weight_166'} = 0;
	$result{'legacy_usps_weight_194'} = 0;
	$result{'legacy_usps_weight_166'} = 0;
	$result{'pkg_weight'} = 0;				
	$result{'items_total'} = 0;		# sum/items_total
	$result{'items_count'} = 0;
	$result{'items_taxable'} = 0;		## total amount that is considered taxable
	$result{'items_taxdue'} = 0;		## items taxdue (taxes owed on items) -- additional taxes on shipping, specialty, etc.

	###
	## NOTE: the .int version avoids the floating point precision issues
	##			so (items.subtotal == 17.10)  means (items.subtotal.int == 1710)
	##
	#$result{'items.subtotal'} = 0; ## The total dollar value of the stuff before adding tax/shipping/etc
	#$result{'items.subtotal.int'} = 0; ## The total dollar value of the stuff before adding tax/shipping/etc (as integer)
	#$result{'items.count'}    = 0; ## The number of items (not including promotion line items)
	#$result{'tax.subtotal'}  = 0; ## The total dollar value of the taxable stuff
	#$result{'tax.subtotal.int'}  = 0; ## The total dollar value of the taxable stuff (as integer)
	#$result{'tax.due'}  = 0; ## The total dollar amount of taxes owed.
	#$result{'tax.due.int'}  = 0; ## The total dollar amount of taxes owed (as integer)
	#$result{'weight'}   = 0; ## The total weight of the stuff

	## Loop over all of the items and add up the totals
	#$result{'pkg_weight_194'} = 0;
	#$result{'pkg_weight_166'} = 0;

	if (not defined $items) { $items = {}; }
	foreach my $item (@{$self->items( %{$items})} ) {
		#if ($item->{'price'})    eq '') { $item->{'price'}    = 0; }			# should have been handled properly by cram
		#if (def($item->{'qty'})      eq '') { $item->{'qty'}      = 0; }		# should have been handled properly by cram
		#if (def($item->{'weight'})   eq '') { $item->{'weight'}   = 0; }		# should have been handled properly by cram
		#	$item->{'taxable'} = taxable($item->{'taxable'});
		# $item->{'weight'} = &ZSHIP::smart_weight($item->{'weight'});


		my $qty = $item->{'qty'};
		if ($params{'qty'}) { $qty = $params{'qty'}; }

		## michaelc thinks keeping extended price is a good idea for future qty pricing, etc.
		## extended line is duplicated multiple times to keep everything sane (all may not be necessary)
		$item->{'extended'} = sprintf('%.2f', ($item->{'qty'} * $item->{'price'}));


		my $is_assembly = ((defined $item->{'asm_master'}) && ($item->{'asm_master'} ne ''))?1:0;
		if ($is_assembly) {
			## LEGACY BEHAVIOR: ASSEMBLIES DON'T GET THEIR OWN DIMENSIONS AND/OR WEIGHT .. it MIGHT BE BETTER
			##						  IN THE FUTURE TO LOOK AT THE PARENT AND SEE IF IT HAS ZERO WEIGHT, IF IT DOES
			##						  **THEN** WE USE THE CHILDREN 
			}
		else {
			my @PKG = ( 0, 0, 0, 0 );
			if (defined $item->{'%attribs'}) {  
				@PKG = ( 
					int($item->{'%attribs'}->{'zoovy:pkg_depth'}),  # [0]
					int($item->{'%attribs'}->{'zoovy:pkg_width'}), 	# [1]
					int($item->{'%attribs'}->{'zoovy:pkg_height'}), # [2]
					(&ZOOVY::is_true($item->{'%attribs'}->{'zoovy:pkg_exclusive'})? 1 : 0)
					); 
				}

			my $pkg_cubic_inches = $PKG[0] * $PKG[1] * $PKG[2];		
			$result{'pkg_cubic_inches'} += $pkg_cubic_inches;

			my $pkg_exclusive = ($PKG[3])?0:0.9999;	## dimensional rounding

			$result{'pkg_weight_194'} +=  $qty * ((((($pkg_cubic_inches/194)+$pkg_exclusive)*16) > $item->{'weight'} ) ? ((($pkg_cubic_inches/194)+$pkg_exclusive)*16) : $item->{'weight'});
			$result{'pkg_weight_166'} +=  $qty * ((((($pkg_cubic_inches/166)+$pkg_exclusive)*16) > $item->{'weight'} ) ? ((($pkg_cubic_inches/166)+$pkg_exclusive)*16) : $item->{'weight'});
			$result{'pkg_weight'} +=  $qty * $item->{'weight'};
			$result{'items_total'} +=  (&ZOOVY::f2int($item->{'price'}*100) * $qty);

			### BEGIN: BROKE ASS USPS COMPAT CODE
			if ($pkg_cubic_inches > 0) {
				
				## NOTE: pkg_exclusive **BUG** is intentionally copied from old stuff to keep legacy_calcs the same
				##			uncomment whenever you want to piss people off.
				my $pkg_exclusive = ((defined $item->{'%attribs'}->{'zoovy:pkg_exclusive'})?1:0);
				if ($pkg_exclusive==0) { $pkg_exclusive = 0; }  ## no dimensional rounding
				elsif ($pkg_exclusive==1) { $pkg_exclusive = 0.9999; }

				my $w = int(($pkg_cubic_inches / 194)+$pkg_exclusive)*16;
				if ($w>$item->{'weight'}) { $result{'legacy_usps_weight_194'} += ($w*$item->{'qty'}); }
				else { $result{'legacy_usps_weight_194'} += ($item->{'weight'} * $item->{'qty'}); }

				$w = int(($pkg_cubic_inches / 166)+$pkg_exclusive)*16;
				if ($w>$item->{'weight'}) { $result{'legacy_usps_weight_166'} += ($w*$item->{'qty'}); }
				else { $result{'legacy_usps_weight_166'} += ($item->{'weight'} * $item->{'qty'}); }
				}
			else {
				$result{'legacy_usps_weight_194'} += ($item->{'weight'} * $item->{'qty'});
				$result{'legacy_usps_weight_166'} += ($item->{'weight'} * $item->{'qty'});
				}
			## END: BROKE ASS USPS COMPAT CODE

			}

		if ($item->{'is_promo'}) {}
		elsif (substr($item->{'stid'},0,1) eq '%') {}
		else {
			$result{'items_count'} += $qty;
			}

		my $tax_rate = undef;
		if (not defined $tax_rate && defined $item->{'tax_rate'}) { $tax_rate = $item->{'tax_rate'}; }
		if (not defined $tax_rate && defined $params{'tax_rate'}) { $tax_rate = $params{'tax_rate'}; }

		if (not defined $item->{'taxable'}) {} ## assume we are taxable
		elsif (not $item->{'taxable'}) { $tax_rate = 0; }

		if (defined $tax_rate) {
			## sum of price * qty for all taxable items.
			$result{'items_taxable'} += sprintf("%.2f", &ZOOVY::f2int($item->{'price'}*100)*$qty );
			## sum of (price * $qty * taxrate) for all items (since individual items MAY have their own taxrate)
			$result{'items_taxdue'} += sprintf("%.2f", ($tax_rate / 100) * &ZOOVY::f2int($item->{'price'}*100) * $qty );		# tax.due?
			}

#		$result{'items_due'} = sprintf("%0.2f",$result{'items_total'}/100);
#		$result{'items_total'} = sprintf("%0.2f",$result{'items_total'}/100);
#		$result{'tax.due'} = sprintf("%.2f", $result{'tax.due.int'}/100);
#		if (int($result{'weight'}) < $result{'weight'}) { $result{'weight'} = int($result{'weight'})+1; }	# don't keep around decimals on the final weight

#		$item->{'cubic_inches'} = 0;
#		my $a = $item->{'%attribs'};
#		if (not defined $a->{'zoovy:pkg_depth'}) { $a->{'zoovy:pkg_depth'}=0; }
#		if (not defined $a->{'zoovy:pkg_width'}) { $a->{'zoovy:pkg_width'}=0; }
#		if (not defined $a->{'zoovy:pkg_height'}) { $a->{'zoovy:pkg_height'}=0; }
#		if ( (int($a->{'zoovy:pkg_depth'})>0) &&
#			(int($a->{'zoovy:pkg_width'})>0) && (int($a->{'zoovy:pkg_height'})>0) ) {
#
#
#			$item->{'cubic_inches'} = int($a->{'zoovy:pkg_depth'}) * int($a->{'zoovy:pkg_width'}) * int($a->{'zoovy:pkg_height'});
#
#			my $w = int(($item->{'cubic_inches'} / 194)+$pkg_exclusive)*16;
#			if ($w>$item->{'weight'}) { $result{'pkg_weight_194'} += ($w*$item->{'qty'}); } else { $result{'pkg_weight_194'} += ($item->{'weight'} * $item->{'qty'}); }
#
#			$w = int(($item->{'cubic_inches'} / 166)+$pkg_exclusive)*16;
#			if ($w>$item->{'weight'}) { $result{'pkg_weight_166'} += ($w*$item->{'qty'}); } else { $result{'pkg_weight_166'} += ($item->{'weight'} * $item->{'qty'}); }
#			}
#		else {
#			$result{'pkg_weight_194'} += ($item->{'weight'} * $item->{'qty'});
#			$result{'pkg_weight_166'} += ($item->{'weight'} * $item->{'qty'});
#			}
#		$item->{'extended'} = ($item->{'price'} * $item->{'qty'});
#		$result{'items.subtotal'} += sprintf("%.2f", $item->{'extended'});
#		$result{'items.subtotal.int'} += &f2int(($item->{'price'}*100)*$item->{'qty'});
#		if ($item->{'taxable'}) { 
#			$result{'tax.subtotal'} += sprintf("%.2f", ($item->{'price'} * $item->{'qty'})); 
#			$result{'tax.subtotal.int'} += &f2int(($item->{'price'}*100)*$item->{'qty'}); 
#			}
#		$result{'weight'} += ($item->{'qty'} * $item->{'weight'});
#		## Handle hidden items and discounts
#		$result{'tax.due.int'} = sprintf("%.2f", ($tax_rate / 100) * $result{'tax.subtotal.int'});
#		$result{'tax.due'} = sprintf("%.2f", $result{'tax.due.int'}/100);
#		if (int($result{'weight'}) < $result{'weight'}) { $result{'weight'} = int($result{'weight'})+1; }	# don't keep around decimals on the final weight
		}

	$result{'items_taxable'} = sprintf("%.2f",$result{'items_taxable'}/100);
	$result{'items_taxdue'} = sprintf("%.2f",$result{'items_taxdue'}/100);
	$result{'items_total'} = sprintf("%.2f",$result{'items_total'}/100);

	return (\%result);
	}



##
## returns all products as an array
##
#sub products {
#	my ($self) = @_;
#	my %products = ();
#
#	warn "STUFF2->products probably could use some love to handle promo items caller=".join("|",caller(0))."\n";
#	foreach my $stid ($self->stids()) {
#		my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($stid);
#		next if (substr($pid,0,1) eq '%');
#		next if (substr($pid,0,1) eq '_');
#		$products{$pid} += $self->{$stid}->{'qty'};
#		}
#
#	return(\%products);
#	}




##
## Takes in an $item ref, and computes the optimal quantity price
##		'3=24.95,12=23.95,36=22.00',
##		6/144
##
sub qty_price {
	my ($item) = @_;

	$item->{'price'} = $item->{'base_price'};
	if ($item->{'schedule_price'}>0) {
		$item->{'price'} = $item->{'schedule_price'};
		}

	## note: if we have option price differences between base_price and $item->{'price'} we should add those
	if (defined $item->{'pogs_price_diff'}) {
		$item->{'price'} += $item->{'pogs_price_diff'};
		}

	my $newprice;
	foreach my $entry (split /[\,\n\r]+/, $item->{'qty_price'}) {
		my ($qtylimit,$operator,$qtyprice) = ($entry =~ m/^(.+?)(\=|\/)(.+?)$/);
		## qtylimit is the starting # allowed ex: must by 5
		## operator can be either / or =  (5=125 means buy 5 @ $125ea., 5/125 means buy 5 @ $25ea.)
	
		$qtylimit =~ s/\D//gs;		# strip non numeric from limit
		$qtyprice =~ s/[^\d\.]//gs;	# strip non numeric + decimal

		next unless ($qtylimit <= $item->{'qty'});		## this wont look at qty's below our current qty
		if ($operator eq '=') {
			$newprice = sprintf('%.2f', $qtyprice);
			}
		elsif ($operator eq '/') {
			$newprice = sprintf('%.2f', ($qtyprice/$qtylimit));
			}
		}

	## okay, so what happens if we have option modifiers which alter the base price.
	##	holy shit, yeah i know thats fucked up. so i've left a clue in STUFF->process_pog
	##	at the end it should set a variable called "pog_price_diff" in the item which we can
	## use here to add to the final price, this way the difference between base_price, and 
	##	modified base_price can be REAPPLIED to the $newprice .. that is of course assuming
	## this can be a little confusing though because when adding an item to the cart
	##	qty_price is run BEFORE process_pogs, so this line here is really only used when
	##	the customer decides to change the qty on a qty_price item that has option price modifiers.
	## yeah, i know how fucked up that is.

	## REMINDER: $newprice won't be set if there were no applicable qty price fields.
	if (defined $newprice) {
		if (defined $item->{'pogs_price_diff'}) {
			$newprice += $item->{'pogs_price_diff'};
			}
		$item->{'price'} = $newprice; 
		}

	}






1;

__DATA__








##
## pass a stid id
##
#sub get {
#	my ($self,$stid,$property) = @_;
#
#	$stid = uc($stid); ## hmm.. STID's can't be lowercase, but yet sometimes we get them that way. dammit.
#	my ($item) = $self->item($stid);
#	if (defined $item) {
#		if (index($property,'.')>0) {
#			## we'll walk the tree.. e.g. full_product.zoovy:prod_name
#			foreach (split(/\./,$property)) { $item = $item->{$_}; }
#			return($item);
#			}
#		else {
#			return($item->{$property});
#			}
#		}
#	}

##
## property can be in the format:
##		full_product
##		attribs
##		yipes, this is pretty scary.
##
#sub set {
#	my ($self,$stid,$property,$value) = @_;
#
#	$stid = uc($stid); ## hmm.. for some odd reason $STID often gets us in lower case. - don't remove with out testing.
##	print STDERR "STUFF SETTING: $stid,$property,$value\n";
#
#	my ($item) = $self->item($stid);
#	if (defined $item) {
#		$item->{$property} = $value;
#		}
#	else {
#		warn("Could not save $stid");
#		}
#	}



##
## formats stids into an array suitable for output (where the master stid comes before its children
##		and promotions and stuff are at the bottom)
##
sub stids_output {
	my ($self) = @_;

	my %st = (); 	## hash keyed by stid, value = added_gmt
	my %asm = ();	## hash keyed by asssembly_master, value is arrayref of component stids
	my @other = ();	## hash of other stuff (special stids) e.g. ! % which are added at the end.
	foreach my $stid ($self->stids()) {
		my $item = $self->item($stid);
		
		if ((defined $item->{'asm_master'}) && ($item->{'asm_master'} ne '')) {
			## handle assembly components
			if (not defined $asm{$item->{'asm_master'}}) { $asm{$item->{'asm_master'}} = (); }
			push @{$asm{$item->{'asm_master'}}}, $stid;
			}
		elsif (index($stid,'%')==0) {
			push @other, $stid;
			}
		else {
			$st{$stid} = int($item->{'added_gmt'});
			}
		}

	my @result = ();	## the final result we'll return
	## go through and add master stids, plus their assembly components
	foreach my $stid (ZTOOLKIT::value_sort(\%st,'numerically')) {
		push @result, $stid;

		## add assembly components (if any)
		if (defined $asm{$stid}) {
			foreach my $stid (@{$asm{$stid}}) { push @result, $stid; }
			}
		}
	
	## okay add any other crap !DISC, %SHIT
	foreach my $stid (@other) { push @result, $stid; }

	return(@result);		## to make this similiar to stids() we'll return an array
	}


##
## Returns all Stuff ID's (stids) for a STUFF as an array
##
sub stids {
	my ($self) = @_;
	return grep !m/^\_/, sort keys %{$self};
	}






##
##
sub count {
	my ($self,$opts) = @_;
	if (not defined $opts) { $opts = 0; }

	# print STDERR Dumper($self);

	my %STIDQTY = ();
	foreach my $stid ($self->stids()) {
		my $item = $self->{$stid};
		next unless defined $item;

		#next if (substr($stid,0,1) eq '%');
		## only skip % items if opts _not_ & 4, this is to support legacy settings (see above)
		## ie always skip % items, unless opts & 4
		next if (!($opts & 4) && (substr($stid,0,1) eq '%'));

		next if (($opts & 1) && ($item->{'product'} eq '') && ($item->{'sku'} eq ''));						# skip blank items
		next if (($opts & 1) && (substr($item->{'sku'},0,1) eq '!'));	# skip !META, etc. hidden items
		next if (($opts & 1) && (substr($item->{'sku'},0,1) eq '!'));	# skip !META, etc. hidden items
		
		
		if (($opts & 8) && (defined $item->{'asm_master'}) && ($item->{'asm_master'} ne '')) {
			# skip assembly children items, note this will skip the next check if $opts&1 is on ..
			# because otherwise anytype of virtual item wouldn't appear.
			$STIDQTY{$stid} = 0;
			}
		elsif (($opts & 1) && (defined $item->{'asm_master'}) && ($item->{'asm_master'} ne '')) {
			# skip or zero out any asssembly_master items in the stuff object
			# WHY? well if we buy a gift basket with 3 items, we should say "3 items" not "4"
			$STIDQTY{$item->{'asm_master'}} = 0;
			}

		if (defined $STIDQTY{$stid}) {
			## hmm.. stids are unique, so this item has been blocked! (e.g. it was a master)
			}		
		elsif ($opts & 2) { 
			$STIDQTY{$stid} = 1; 
			} 
		else { 
			$STIDQTY{$stid} = $item->{'qty'};
			if (not defined $STIDQTY{$stid}) { $STIDQTY{$stid} = 0; }
			}

		}

	my $count = 0;
	foreach my $val (values %STIDQTY) {
		$count += int($val);
		}
	
	return $count;
	}






