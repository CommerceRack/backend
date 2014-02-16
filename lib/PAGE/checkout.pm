package PAGE::checkout;

use strict;

use URI::Escape::XS qw();

require SITE::EMAILS;
require SITE;
require TOXML::SPECL3;
use lib '/backend/lib';
require CART2;
require CART2::VIEW;
require LISTING::MSGS;
require ZPAY;     # Not verified use strict yet
require ZSHIP;    # Not verified use strict yet
require CUSTOMER;
require ZTOOLKIT;
require SITE::MSGS;
use Data::Dumper;

sub def { ZTOOLKIT::def(@_); }

use Data::Dumper;



# Makes a pretty address out of a checkout info hash (only used by and checkout.cgi)
sub html_address {
	my ($CART2,$type) = @_;

	my $line = '';
	my @LINES = ();
	if ((not defined $type) || ($type eq '') || (($type ne 'bill') && ($type ne 'ship'))) {
		$type = 'bill';
		}


	# Billing Address
	$line = '';
	$line .= $CART2->in_get(sprintf("%s/firstname",$type)).' ';
	# if ($CART2->in_get(sprintf("%s/mi",$type))) { $addr .= $CART2->in_get(sprintf("%s/middlename",$type)).' ' };
	if ($CART2->in_get(sprintf("%s/middlename",$type))) { 
		$line .= $CART2->in_get(sprintf("%s/middlename",$type)).' ' 
		};
	$line .= $CART2->in_get(sprintf("%s/lastname",$type));
	push @LINES, $line;

	if ($CART2->in_get(sprintf("%s/company",$type))) { 
		push @LINES, $CART2->in_get(sprintf("%s/company",$type));
		}

	push @LINES, $CART2->in_get(sprintf("%s/address1",$type));
	if ($CART2->in_get(sprintf("%s/address2",$type))) { 
		push @LINES, $CART2->in_get(sprintf("%s/address2",$type));
		}

	my $countrycode = $CART2->in_get(sprintf("%s/countrycode",$type));
	$line = '';
	if (($countrycode eq '') || ($countrycode eq 'US')) {
		if ($CART2->in_get(sprintf("%s/city",$type)) ne '') { $line .= $CART2->in_get(sprintf("%s/city",$type)).', '; }			
		if ($CART2->in_get(sprintf("%s/region",$type)) ne '') { $line .= $CART2->in_get(sprintf("%s/region",$type)).' '; }
		if ($CART2->in_get(sprintf("%s/postal",$type)) ne '') { $line .= $CART2->in_get(sprintf("%s/postal",$type)); }
		}
	else {
		my ($info) = &ZSHIP::resolve_country(ISO=>$countrycode);
		my $pretty_country = "$countrycode";
		if (defined $info->{'Z'}) { $pretty_country = $info->{'Z'}; }
		if ($CART2->in_get(sprintf("%s/city",$type)) ne '') { $line .= $CART2->in_get(sprintf("%s/city",$type)).', '; }
		if ($CART2->in_get(sprintf("%s/region",$type)) ne '') { $line .= $CART2->in_get(sprintf("%s/region",$type)).' '; }
		if ($CART2->in_get(sprintf("%s/postal",$type)) ne '') { $line .= $CART2->in_get(sprintf("%s/postal",$type)).', '; }
		$line .= "$pretty_country";
		}
	push @LINES, $line;

	my ($addr) = '';
	foreach my $line (@LINES) {
		next if ($line eq '');
		$addr .= "$line<br>\n";
		}
	
	return $addr;
	}






sub handler {
	my ($iniref,undef,$SITE) = @_;
	##
	## Note: i didn't write this, i just figured out how it worked .. -BH
	##
	## basically the order variables are stored inside the CART in the checkout_info property
	##	
	##	each form passes the SENDER (it's own name) and based on the $SENDER (cgi var) and the data the
	##		each page figures out what the next page ought to be and sets the $STAGE variable (which in turn
	##		becomes the next SENDER)
	##
	##	here are the various senders:
	##		LOGIN - 
	##		CHOOSE - the asks the customer if they want to login 
	##		BILLING_LOCATION - collects billing info
	##		SHIPPING_LOCATION - collects shipping info
	##		ORDER_CONFIRMATION - 
	##		NEW_CUSTOMER - 
	##		PAYMENT_INFORMATION - 
	##		ERROR -- ?? not sure what this does.
	##		INVOICE_DISPLAY -- this is the final stage where the order confirmation is displayed
	##
	my $OUTPUT = '';
	# if (not defined $SITE) { $SITE = $SITE::SREF; }
	if (ref($SITE) ne 'SITE') { warn Carp::confess("PAGE::checkout::handler requires valid SITE object passed as SREF"); }

	my $LM = LISTING::MSGS->new($SITE->username());


	my $DEBUG = 0;
	my %payment = ();	# this holds the payment information the user submitted 
							# (it's only kept in memory, never in the cart)
	
	$SITE->URLENGINE()->set('sessions'=>1,'secure'=>1);
	$SITE->pageid( '*checkout' );


	## THIS CART is a reference to the cart we're rendering, normally this will be SITE::CART2 except
	##				 immediately after a checkout_finalize when $THIS_CART is then an order, and $SITE::CART2 is still
	##				 our current site cart
	my $THIS_CART = $SITE->cart2();
	$THIS_CART->{'IS_LEGACY_CHECKOUT'}++;
	
	########################################
	# GLOBALS
	my %cart2 = ();
	tie %cart2, 'CART2', CART2=>$THIS_CART;

	my %hints             = ();
	my @addrs = ();
	my $webdbref = $SITE->webdb();
	my $gref = $SITE->globalref();
	my @ISSUES = ();

	my $cart_changed = 0;
	my $orig_cart_digest = $THIS_CART->digest();

	my %fields = (
#	  'cart_id'=>'id',
	  'chkout.create_customer'=>'want/create_customer',	# 0 = do not create customer
																			# 1 = prompt user to create a customer
																			# 100 = user already has a customer
	  'chkout.new_password'=>'want/new_password',
	  'chkout.new_password2'=>'want/new_password2',
	  'chkout.recovery_hint'=>'want/recovery_hint',
	  'chkout.recovery_answer'=>'want/recovery_answer',
	  'chkout.payby'=>'want/payby',
	  'chkout.bill_to_ship'=>'want/bill_to_ship',
	  # cod=>'data.cod',
	  'data.erefid'=>'want/erefid',
	  # keepcart=>'chkout.keepcart',
	  'chkout.po_number'=>'want/po_number',
	  'chkout.order_notes'=>'want/order_notes',
	  # 'meta'=>'meta',
	  'ship.selected_id'=>'want/shipping_id',
	  'data.bill_firstname'=>'bill/firstname',
	  'data.bill_middlename'=>'bill/middlename',
	  'data.bill_lastname'=>'bill/lastname',
	  'data.bill_company'=>'bill/company',
	  'data.bill_address1'=>'bill/address1',
	  'data.bill_address2'=>'bill/address2',
	  'data.bill_city'=>'bill/city',
	  'data.bill_state'=>'bill/region',
	  'data.bill_zip'=>'bill/postal',
	  'data.bill_country'=>'bill/countrycode',
	  'data.bill_phone'=>'bill/phone',
	  'data.bill_email'=>'bill/email',
	  'data.ship_firstname'=>'ship/firstname',
	  'data.ship_middlename'=>'ship/middlename',
	  'data.ship_lastname'=>'ship/lastname',
	  'data.ship_company'=>'ship/company',
	  'data.ship_address1'=>'ship/address1',
	  'data.ship_address2'=>'ship/address2',
	  'data.ship_city'=>'ship/city',
	  'data.ship_state'=>'ship/region',
	  'data.ship_zip'=>'ship/postal',
	  'data.ship_country'=>'ship/countrycode',
	  'data.ship_phone'=>'ship/phone',

	  'chkout.shipping_residential'=>'want/shipping_residential',
	  'ship.ins_purchased'=>'want/ins_purchased',
	  'ship.bnd_purchased' =>'want/bnd_purchased',
	  # tax_total=>'data.tax_total',
	  # order_subtotal=>'chkout.order_subtotal',
	  # resale_permit=>'chkout.resale_permit'
		);

 
	if ($webdbref->{'customer_management'} eq '') {
		$webdbref->{'customer_management'} = 'DEFAULT';
		}
	if ($webdbref->{'customer_management'} eq 'DEFAULT') {
		$webdbref->{'customer_management'} = 'STANDARD';
		}

	
	my $preference_request_login = 0;			# first stage of checkout requests login.
	my $preference_require_login = 0;			# to get to order confirmation they must have a login.
	my $preference_create_customer = 0;			# prompt user to create a customer
	my $preference_always_create_account = 0;	# no matter what, create an account at the end of checkout
	my $preference_never_create_account = 0;	# no matter what, never create an account (for private sites)

	# value='STANDARD'><b>Default:</b> Require customers to use/create accounts, require existing customers to login.<br>
	# value='NICE'><b>Nice:</b> Prompt customers to use/create accounts, but always let them purchase, even without logging into their account.<br>
	# value='STRICT'><b>Strict:</b> Prompt customers to use/create accounts, and require a customer to login if they have an account.<br>
	# value='PASSIVE'><b>Passive:</b> Never ask customers to create an account, let Zoovy automatically correlate multiple sales by the same customer.<br>
	# value='DISABLED'><b>Disabled:</b> Turn off all customer management and tracking.<br>
	# value='MEMBER'><b>Members Only:</b> Allow anybody to browse site, but do NOT allow new customers to create an account, or make a purchase (customers must have an account on record to purchase).<br>
	# value='PRIVATE'><b>Private:</b> REQUIRE customer to login before they can access site, do NOT allow new customers to create an account, or make a purchase.<br>
	if ($webdbref->{'customer_management'} eq 'PASSIVE') {
		$preference_always_create_account++;
		}
	elsif ($webdbref->{'customer_management'} eq 'NICE') {
		$preference_request_login++;

		if (not defined $cart2{'want/create_customer'}) { 
			## not set, so lets choose a sane value (yes)
			$cart2{'want/create_customer'} = 1;
#			push @ISSUES, [ 'WARNING', '', '', "EARLY: cart{'chkout.create_customer'} = $cart{'chkout.create_customer'} $cart{'chkout.email_update'}" ];
			}
		}
	elsif ($webdbref->{'customer_management'} eq 'STRICT') {
		$preference_request_login++;
		$preference_require_login++;
		}
	elsif ($webdbref->{'customer_management'} eq 'STANDARD') {
		$preference_request_login++;
		}
	elsif ($webdbref->{'customer_management'} eq 'DISABLED') {
		}
	elsif ($webdbref->{'customer_management'} eq 'MEMBER') {
		$preference_require_login++;		
		$preference_never_create_account++;				
		}
	elsif ($webdbref->{'customer_management'} eq 'PRIVATE') {
		$preference_require_login++;		
		$preference_never_create_account++;				
		}
	my $CUSTOMER_MANAGEMENT = $webdbref->{'customer_management'};

	if ($SITE->username() eq 'liz') {
		$OUTPUT .= '<li> CUSTOMER MANAGEMENT: '.$webdbref->{'customer_management'};
		$OUTPUT .= '<li> <a href="?sender=NUKE">Nuke Cart</a>';
		$OUTPUT .= '<li> LOGGED IN AS: #'.$THIS_CART->cid();
		}


	# Conditions where some variables should always be set to certain values
#	if (($cart{'login'} ne '') && (ref($cart{'customer'}) eq 'CUSTOMER')) {
#		## customer is already authenticated to the cart.
#		$STAGE = 'BILLING_LOCATION';
#		&CHECKOUT::stage_login($SITE->username(),\%cart,$webdbref);
#		}

	if ($SITE::v->{'sender'} eq 'CART.LOGIN') {
		## HALEBOB CHEAP HACK
		$SITE::v->{'login.user'} = $SITE::v->{'login'};
		$SITE::v->{'login.pass'} = $SITE::v->{'password'};
		}

	if (
		($SITE::v->{'login.user'} ne '') || 
		($SITE::v->{'login.pass'} ne '')
		) {

		print STDERR "LOGIN !!!!!  user:$SITE::v->{'login.user'}, pass$SITE::v->{'login.pass'}\n";
		my ($cid) = $THIS_CART->login( $SITE::v->{'login.user'}, $SITE::v->{'login.pass'} );
		if ($cid>0) {
			## success, hurrah.
			$OUTPUT .= 'you are logged in as customer '.$cart2{'customer/login'}.'<br>';
			}
		elsif ($preference_require_login) {
			push @ISSUES, [ 'ERROR', 'login.required', 'login.user', 'You must login to purchase on this site, please try again.' ];
			}
		}



	my $allowphone = defined($webdbref->{'chkout_allowphone'}) ? $webdbref->{'chkout_allowphone'} : 0;
	$DEBUG && warn("\$allowphone = '$allowphone'");
	
	my $require_phone = 0;
	if (not defined $webdbref->{'chkout_phone'}) {}
	elsif ($webdbref->{'chkout_phone'} eq 'REQUIRED') { $require_phone = 1; }
	elsif ($webdbref->{'chkout_phone'} eq 'OPTIONAL') { $require_phone = 0; }
	elsif ($webdbref->{'chkout_phone'} eq 'UNREQUESTED') { $require_phone = -1; }
		
	my $forcebilltoship = defined($webdbref->{'chkout_billshipsame'}) ? $webdbref->{'chkout_billshipsame'} : 0;
	if ($forcebilltoship) { $cart2{'must/bill_to_ship'} = 1; }
	$DEBUG && warn("\$forcebilltoship = '$forcebilltoship'");
	
	my $forceresidential = defined($webdbref->{'shipping_force_residential'}) ? $webdbref->{'shipping_force_residential'} : 1;
	$DEBUG && warn("\$forceresidential = '$forceresidential'");
		
	my $getnotes = defined($webdbref->{'chkout_order_notes'}) ? $webdbref->{'chkout_order_notes'} : 0;
	$DEBUG && warn("\$getnotes = '$getnotes'");
	
	# This is how we know which fields are valid ones to pass through for processing.
	# Its essentially a white-list of form fields
	
	my $pay_info_stages = ['CREDIT', 'PO', 'ECHECK','GIFTCARD'];
	
	#########################################
	# INVENTORY POLICING DURING CHECKOUT
	#########################################
	if ((defined $gref->{'inv_police_checkout'}) && ($gref->{'inv_police_checkout'} == 1)) {
		# If there's nothing in the shopping cart, then the cart must have expired.
		if ((defined $gref->{'inv_mode'}) && ($gref->{'inv_mode'} > 1)) {
	
			my $update = $THIS_CART->check_inventory('*SITE'=>$SITE);
	
			if ((defined $update) && (scalar(@{$update}) > 0)) {
				push @ISSUES, [ 'ISE', 'inv_police', '', 'At least one of the items of your cart are no longer available for purchase. Please go back and update the cart.' ];
				}
			}
		} ## end if ((defined $webdbref->{'inv_police_checkout'...
	
	########################################
	# SENDER
	
	# Set the sender (The stage of the previous form)
	my $SENDER = defined($SITE::v->{'sender'}) ? uc($SITE::v->{'sender'}) : '';
	if ($SENDER eq 'CHECKOUT-TEST') {
		## populate a test cart.
		$SENDER = 'START';
		}

	$DEBUG && warn("\$SENDER : '$SENDER'");


#	push @ISSUES, [ 'WARNING', '', '', "MIDDLE TRY: cart{'chkout.create_customer'} = $cart{'chkout.create_customer'} $cart{'chkout.email_update'}" ];
	
	if (ref($THIS_CART) ne 'CART2') {
		push @ISSUES, [ 'ISE', 'non_cart_reference', '', 'Sorry, but we could not load the cart you created. (Object was not correct reference)' ];
		}

	########################################
	# DECODE (AND OVERRIDE) ENCODED FIELDS


	if ((not defined $cart2{'will/payby'}) || ($cart2{'will/payby'} eq '')) {
		## no payby set.. so we don't do any payment checks.
		}
	elsif ($cart2{'will/payby'} eq 'CREDIT') {
		#  cc_number=>'chkout.cc_number',
		#  cc_exp_month=>'chkout.cc_exp_month',
		#  cc_exp_year=>'chkout.cc_exp_year',
		#  cc_cvvcid=>'chkout.cc_cvvcid',
		$payment{'CC'} = $SITE::v->{'payment.cc'};
		$payment{'CC'} =~ s/[^\d]+//gs; # strip non-numeric
		$payment{'MM'} = $SITE::v->{'payment.mm'};
		$payment{'MM'} =~ s/[^\d]+//gs; # strip non-numeric
		$payment{'YY'} = $SITE::v->{'payment.yy'};
		$payment{'YY'} =~ s/[^\d]+//gs; # strip non-numeric
		$payment{'CV'} = $SITE::v->{'payment.cv'};
		$payment{'CV'} =~ s/[^\d]+//gs;	# strip non-numeric
		}
	elsif ($cart2{'will/payby'} eq 'PO') {
		$payment{'PO'} = $SITE::v->{'chkout.po_number'};
		$payment{'PO'} =~ s/^[\s]+//gs; # leading spaces
		$payment{'PO'} =~ s/[\s]+$//gs; # leading spaces
		}
	elsif ($cart2{'will/payby'} eq 'ECHECK') {
		$payment{'EA'} = $SITE::v->{'payment.ea'};
		$payment{'EA'} =~ s/[^\d]+//gs; # strip non-numeric
		$payment{'ER'} = $SITE::v->{'payment.er'};
		$payment{'ER'} =~ s/[^\d]+//gs; # strip non-numeric
		$payment{'EN'} = $SITE::v->{'payment.en'};
		$payment{'ES'} = $SITE::v->{'payment.es'};
		$payment{'EB'} = $SITE::v->{'payment.eb'};
		$payment{'EI'} = $SITE::v->{'payment.ei'};
		}
	elsif ($cart2{'will/payby'} eq 'PAYPALEC') {
		## paypal requires billing and shipping be the same!
		## 	hmm.. maybe it's a repeat customer placing an order with an account, and they paid by pp_express checkout
		##		last time..	this is so jacked up. .. either way, if we don't have this info, we better end this ride now.
		my ($ppec) = &ZPAY::unpackit($cart2{'cart/paypalec_result'});
		if ($SENDER eq 'PAYPALEC.RESET') {
			## the user no longer wants to pay via paypal
			delete $cart2{'must/payby'};
			delete $cart2{'our/paypalec'};
			}
		elsif ($cart2{'cart/paypalec_result'} eq '') { 
			push @ISSUES, [ 'ERROR', 'paypalec_blank', '', 'Sorry, but it appears your paypal express checkout session is no longer valid [chkout/paypalec_result blank] , please try again.' ];
			$cart2{'must/payby'} = ''; 
			$cart2{'cart/paypalec_result'} = '';
			}
		elsif ( ($ppec->{'TE'}>0) && ($ppec->{'TE'}<&ZTOOLKIT::pretty_date(time(),3)) ) {
			push @ISSUES, [ 'ERROR', 'paypalec_blank', '', 'Sorry, but it appears your paypal express checkout session is no longer valid [PV='.$ppec->{'PV'}.'], please try again.' ];
			$cart2{'must/payby'} = ''; 
			$cart2{'cart/paypalec_result'} = '';
			}
		else {
			%payment = %{$ppec};
			}
		}
	foreach my $k (keys %payment) {
		if ($payment{$k} eq '') { delete $payment{$k}; } 	# don't save blank payment values.
		}
	## NOTE: at this point %payment if it has *ANYTHING* in it will be validated.
	## regardless of stage.

	
	##
	##	SANITY: at this point %payment either has zero keys, OR it has information populated.
	## 


	if ($THIS_CART->cartid() eq '') {
		push @ISSUES, [ 'ISE', 'cart_id_blank', '', 'Sorry, but we could not load the cart you created. (Cart ID was blank)' ];
		}
	elsif ($THIS_CART->is_memory()) {
		push @ISSUES, [ 'ISE', 'cart_id_temp', '', 'Sorry, but we could not load the cart you created. (Cart ID was temporary)' ];
		}

	# Default everything to blank first so perl strict doesn't complain
	if (not defined $cart2{'will/bill_to_ship'}) { 
		$cart2{'want/bill_to_ship'} = '1'; 
		}
		
#	# Override anything in $info with any newly defined fields passed via last form
#	open F, ">>/tmp/checkout-$SITE->username().log";
#	print F Dumper(time(),$SENDER,$SITE::CART,$SITE::v);
#	close F;

#	push @ISSUES, [ 'WARNING', '', '', "BEFORE cart{'chkout.create_customer'} = $cart{'chkout.create_customer'} $cart{'chkout.email_update'}" ];

	foreach my $field (keys %fields) {
		if (defined($SITE::v->{$field})) {
			$SITE::v->{$field} =~ s/^[\s]+//gso;
			$SITE::v->{$field} =~ s/[\s]+$//gso;
			$SITE::v->{$field} =~ s/[\<\>]+//gso;	# removes <> to virtually eliminate cross site scripting attacks
			## all these fields should be ignored and will be handled later.
			next if ($field eq 'chkout.payby');
			next if ($field eq 'ship.ins_purchased');
			next if ($field eq 'ship.bnd_purchased');

			if ($field eq 'chkout.create_customer') {
				## this has some weird behaviors because of where the checkbox appears, this was just easier.
				if ($SITE::v->{$field} eq 'true') { $SITE::v->{'chkout.create_customer'} = 1; }
				if ($SITE::v->{$field} eq 'checked') { $SITE::v->{'chkout.create_customer'} = 1; }
				if ($SITE::v->{$field} eq 'false') { $SITE::v->{'chkout.create_customer'} = 0; }
				if ($SITE::v->{$field} eq '') { $SITE::v->{'chkout.create_customer'} = 0; }
				}

			$cart2{ $fields{$field} } = $SITE::v->{$field};
			}
		}
	

#	push @ISSUES, [ 'WARNING', '', '', "AFTER: cart{'chkout.create_customer'} = $cart{'chkout.create_customer'} $cart{'chkout.email_update'}" ];


		
	########################################
	# PARSE VARIABLES
	
	# Handle checkboxes from forms here, and other interpolated variables.
	# We have to look directly at the CGI param instead of $info since $info will
	# contain a value if it got decoded from encoded_fields.   Furthermore we
	# should only process this for forms on which the checkbox appears (so that
	# it doesn't get defaulted when we process a different form)

	my $NEXT = '';
	if ($SENDER eq '') {
		## THEY RESTARTED CHECKOUT - so lets do some clean up.
		warn "restarted checkout, reset .. payby\n";
		delete $cart2{'must/payby'};
		$SENDER = 'START';
		## how do we decide what the first stage of checkout is? possible choices are CHOOSE, LOGIN, BILLING_LOCATION
		}

	## CART.LOGIN, CART.NEW are handed off from the cart's which link directly into checkout
	if ($SENDER eq 'CART.LOGIN') {
		$SENDER = 'CHOOSE.LOGIN';
		}
	elsif ($SENDER eq 'CART.NEW') {
		$SENDER = 'CHOOSE.NEW';
		}
	elsif ($SENDER eq 'PAYPALEC.RESET') {
		$SENDER = 'START';
		}

	# SUBMIT BUTTON...
	# Put whatever it said on the verb button into $VERB
	my $VERB = defined($SITE::v->{'verb'}) ? uc($SITE::v->{'verb'}) : 'NEXT';
	
	# This allows us to use images for the verb buttons
	if (defined $SITE::v->{'next.x'}) { $VERB = 'NEXT'; }
	if (defined $SITE::v->{'last.x'}) { $VERB = 'LAST'; }
	if (defined $SITE::v->{'edit.x'}) { $VERB = 'EDIT'; }
	if (defined $SITE::v->{'ship.x'}) { $VERB = 'EDIT SHIPPING'; }
	if (defined $SITE::v->{'bill.x'}) { $VERB = 'EDIT BILLING'; }

	my $STAGE = undef;

	if ((defined $cart2{'customer/login'}) && ($cart2{'customer/login'} eq '')) { delete $cart2{'customer/login'}; }
#	if ($SITE::CART->cid()>0) {
#		## yay, they are logged in -- so we're going to let this go.
#		}
#	elsif ($webdbref->{'customer_management'} eq 'STRICT') {
#		if (&CUSTOMER::customer_exists($SITE->username(),$SITE::CART->fetch_property('data.bill_email'),$SITE::CART->prt())) {
#			$STAGE = 'LOGIN';
#			push @ISSUES, [ 'ERROR', 'checkout.crm_is_strict', '', $SITE::msgs->get('chkout_login_exists') ];
#			}
#		}

	if ($SENDER eq 'NUKE') {
		## for debuggin!
		$THIS_CART->nuke();
		}


	if ($SENDER eq 'JCHECKOUT') {
		## Jquery (JT) Checkout, just does a blank/secure layout
		$STAGE = ['JCHECKOUT',{'title'=>'Checkout'}];
		}

	##
	## sender START is an alias for the first stage of checkout, this will be overridden to something else.
	##
	if (defined $STAGE) {
		}
	elsif ($SENDER eq 'START') {
		## okay so we should decide where to start now.. depending on preferences it will be CHOOSE, LOGIN, BILLING_LOCATION
		if ($THIS_CART->cid()>0) {
			## customer is already logged in.
			$STAGE = ['BILLING_LOCATION'];
			}
		elsif ($preference_request_login) {
			$STAGE = ['CHOOSE'];
			}
		elsif ($preference_require_login) {
			$STAGE = ['LOGIN']; 
			}
		else {
			$STAGE = ['BILLING_LOCATION'];
			}
		}


	##
	## check to see if we got a successful login.
	##
	if (defined $STAGE) {
		## must be nice to already know where we're going!
		}
	elsif (($SENDER eq 'CHOOSE.LOGIN') || ($SENDER eq 'LOGIN')) {
		## we attempted to login, so lets see if we got a customer id
		if ($THIS_CART->cid()>0) {
			$STAGE = ['BILLING_LOCATION',{'reason'=>'customer_id_set'}];
			}
		elsif ($SENDER eq 'CHOOSE.LOGIN') {
			push @ISSUES, [ 'WARNING', 'login.failed', '', 'Login failed' ];
			$STAGE = ['CHOOSE',{'reason'=>'login failed'}];
			}
		elsif ($SENDER eq 'LOGIN') {
			push @ISSUES, [ 'WARNING', 'login.failed', '', 'Login failed' ];
			$STAGE = ['LOGIN',{'reason'=>'login failed'}];
			}
		}
	elsif ($SENDER eq 'PAYPALEC') {
		## this is sent to us from express checkout.				
		## NOTE: chkout.payby = 'PAYPALEC' was already set before the redirect to here 
		$STAGE = ['ORDER_CONFIRMATION',{'reason'=>'sender is paypal ec'}];
		if ($ZOOVY::cgiv->{'addrwarn'}) {
			push @ISSUES, [ 'WARNING', '', '', 'Paypal has altered the shipping and/or billing address, please verify for accuracy' ];
			}
		}


	## 
	## Validation login, this will throw us back to our SENDER *IF* we got errors.
	## 	

	if (defined $STAGE) {
		## no need to check the sender, because we already know where we're going.
		if ($STAGE->[0] eq 'CHOOSE') {
			## we can definitely skip the CHOOSE stage if they are already logged in.
			if ($THIS_CART->cid()>0) { 
				my $REASON = sprintf('Already logged in as customer: %d',$THIS_CART->cid());
				$OUTPUT .= $REASON;
				$STAGE = ['BILLING_LOCATION',{'reason'=>$REASON,'@chain'=>$STAGE}];
				}
			}
		}
	elsif ($SENDER eq 'CHOOSE') {
		## this line should never be reached!
		push @ISSUES, [ 'ISE', '', '', 'CHOOSE SENDER is INVALID - use CHOOSE.NEW, or CHOOSE.LOGIN' ];
		}
	elsif ($SENDER eq 'CHOOSE.NEW') {
		## CHOOSE = NEW CUSTOMER
		$STAGE = ['BILLING_LOCATION',{'reason'=>'sender:choose.new'}];
		}
	elsif ($SENDER eq 'BILLING_LOCATION') {
		$cart2{'bill/region'} = &ZSHIP::correct_state($cart2{'bill/region'},$cart2{'bill/countrycode'});
		$cart2{'bill/postal'} = &ZSHIP::correct_zip($cart2{'bill/postal'},$cart2{'bill/countrycode'});
	
		delete $cart2{'want/bill_to_ship'};
		if ($cart2{'will/payby'} eq 'PAYPALEC') {
			$STAGE = ['ORDER_CONFIRMATION',{'reason'=>'payby:paypalec'}];
			}
		elsif ($cart2{'must/bill_to_ship'}) {
			## doesn't matter what you want.
			}
		elsif ((defined($SITE::v->{'chkout.bill_to_ship'}) && $SITE::v->{'chkout.bill_to_ship'})) {
			$cart2{'want/bill_to_ship'} = 1;
			}
	

		## 
		## check for existing duplicate login
		##		if they aren't logged in, and ONLY if we are in DEFAULT or STRICT modes.
		##
		if ($THIS_CART->cid()>0) {
			## they are authenticated
			}
		elsif ($VERB eq 'LAST') {
			## always let them go back a stage.
			}
		elsif ($CUSTOMER_MANAGEMENT eq 'NICE') {			
			my ($CID) = (0);
			if ($cart2{'bill/email'} ne '') {
				($CID) = CUSTOMER::resolve_customer_id($SITE->username(),$SITE->prt(),$cart2{'bill/email'});
				}
			if ($CID>0) {
				push @ISSUES, [ 'WARNING', 'chkout_login_exists_nice', 'data.bill_email', 'The email address you specified already has an account, you can continue without logging in and we will automatically link this order to the account.' ];
				}
			}
		elsif (
			($CUSTOMER_MANAGEMENT eq 'STANDARD') || 
			($CUSTOMER_MANAGEMENT eq 'STRICT')
			) {

			my $CID = 0;
			if ($cart2{'customer/login'} ne $cart2{'bill/email'}) {
				$cart2{'customre/login'} = '';		# log them out.
				}

			if ($cart2{'customer/login'} eq '') {
				($CID) = CUSTOMER::resolve_customer_id($SITE->username(),$SITE->prt(),$cart2{'bill/email'});
				}

			if ($CID>0) {

				my ($se) = SITE::EMAILS->new($SITE->username(),'*SITE'=>$SITE);
				$se->sendmail('PREQUEST',CID=>$CID);
				$se = undef;
				
				# require TOXML::EMAIL;
				# TOXML::EMAIL::sendmail($SITE->username(),'PREQUEST',$cart2{'bill/email'},CID=>$CID);
				# &CUSTOMER::mail_password($SITE->username(),$cart2{'bill/email'},0);
				# $errors{'bill_email'} = &CHECKOUT::get_message($SITE->username(),'chkout_login_exists');
				push @ISSUES, [ 'ERROR', 'chkout_login_exists', 'data.bill_email', $SITE->msgs()->get('chkout_login_exists') ];
				$STAGE = ['BILLING_LOCATION',{'reason'=>'chkout_login_exists','cid'=>$CID}];
				}
			}
	
		} ## end elsif ($SENDER eq 'BILLING_LOCATION'...
	elsif ($SENDER eq 'SHIPPING_LOCATION') {
		## Massage state / zip into proper formatting
	
		$cart2{'ship/region'} = &ZSHIP::correct_state($cart2{'ship/region'},$cart2{'ship/countrycode'});
		$cart2{'ship/postal'} = &ZSHIP::correct_zip($cart2{'ship/postal'},$cart2{'ship/countrycode'});
	
		# If they edited the shipping (say, from the "Edit Shipping" button in
		# the confirmation stage) then we don't want to over-write the shipping
		# with the billing
		## Alleviated this need by adding a hidden bill_to_ship form fielf on the edit shipping page
		$cart2{'want/bill_to_ship'} = 0;
		}
	elsif ($SENDER eq 'ORDER_CONFIRMATION') {
		if (CUSTOMER::resolve_customer_id($SITE->username(),$SITE->prt(),$cart2{'bill/email'})>0) {
			$cart2{'want/create_customer'} = 0;
			}
		$cart2{'want/email_update'} = 0;
		for (my $i =1; $i<17;$i++) {
			# print STDERR "[PAGE::checkout NEW_CUSTOMER] email_update".$i."=".$cart{'chkout.email_update'}.": ". $cart{'chkout.email_update'.$i}."\n";
			$cart2{'want/email_update'} += ( $SITE::v->{'chkout.email_update'.$i}>0 )?(1<<($i-1)):0;
			}
		}
	else {
		## this sender does not have specific handler.
		}
	
	########################################
	## BILL TO SHIP HANDLING
	## If we have the billing and shipping the same then auto populate the billing with the shipping destination
	#if ($cart2{'will/payby'} eq 'PAYPALEC') {
	#	## PAYPALEC locks the info -- so no copying fields around!
	#	}
	#elsif ($cart2{'will/bill_to_ship'}) {
	#	## STOP NUKING data.ship_zip -- a real nasty issue occurs can occur in this code, where the data.ship_zip
	#	##		is overwritten with "null" (the current bill_zip) .. because it resets the shipping choice the 
	#	##		user made back at cgi.shipmethod (because that method gets deselected).
	#	## OLD CODE: delete $cart2{'ship/postal'}; delete $cart2{'ship/countrycode'}; delete $cart2{'ship/region'};
	#	## NEW CODE:
	#	foreach my $field ('zip','country','state') {
	#		next if (defined $cart{"data.bill_$field"});	# if data.bill_zip is set, then we'll overwrite data.ship_zip later
	#		## if we get here, data.bill_zip isn't set. 
	#		next if (not defined $cart{"data.ship_$field"});
	#		## if we get here, data.ship_zip *IS* set.. so lets copy it into the billing as a sane default .. so it
	#		## 	won't get lost!
	#		$cart{"data.bill_$field"} = $cart{"data.ship_$field"};
	#		}
	#
	#	foreach my $field (qw(firstname lastname middlename company address1 address2 city state zip country phone)) {
	#		# next if (defined $cart{"data.ship_$field"});
	#		$cart{"data.ship_$field"} = $cart{"data.bill_$field"};
	#		}
	#	delete $cart{'ship.email'};
	#	} ## end if ($cart{'chkout.bill_to_ship'...
	


	if ($THIS_CART->count('show'=>'real')>0) {
		# If there's something in the shopping cart, then the cart is cool.
		}
	elsif ($SITE->client_is() eq 'BOT') {
		push @ISSUES, [ 'ISE', 'user_is_bot', '', qq~Your IP address has been designated as owned by a robot.
This is probably because you accessed the robots.txt on one or more Zoovy hosted sites.
Please contact Zoovy support and request that your IP address: $ENV{'REMOTE_ADDR'} be white listed.
		~ ];
		}
	elsif ($SITE->client_is() eq 'KILL') {
		push @ISSUES, [ 'ISE', 'user_is_kill', '', qq~
Your IP address has been black listed.
This is probably because you had a traffic usage pattern that does not reflect a typical session.
Please contact Zoovy support and request that your IP address: $ENV{'REMOTE_ADDR'} be white listed.
		~ ];
		}
	else {
		## OH SHIT - this cart is empty, so we should probably throw an error...

		my $OID = '';
		if (($OID eq '') && ($ENV{'REQUEST_URI'} =~ m/\/c=(.*?)\//)) {
			($OID) = &CART2::lookup_cartid($THIS_CART->username(),$1,time()-3600);
			}
		if ($OID eq '') {
			($OID) = &CART2::lookup_cartid($THIS_CART->username(),$THIS_CART->cartid(),time()-3600);
			}

		if ($OID ne '') {
			push @ISSUES, [ 'ISE', 'order_already_placed', '', qq~
<p>
Your order $OID has already been placed, please check your the email address provided on this order for a confirmation message. <br>
<br>
What to do from here:<br>
<ul>
<li> If you pressed the reload/refresh button on your browser, and resubmitted the checkout form then you will need to get a copy of your invoice from your email.
<li> If you didn't receive the email, first check your spam folder and then contact us - please include the order #$OID.
<li> You can review the order (and possibly make changes/cancel it) by logging into your customer account.
<li> If you wish to place another order please add one or more items to your cart and try checkout again.
</ul>
</p>~ ];
			}
		else {
			push @ISSUES, [ 'ISE', 'cart_expired', '', qq~
<p>The shopping cart you were using has expired or
you have already placed your order and the shopping cart
has been cleared, you must re-fill your shopping cart to
make another purchase!<br>
Sender: $SENDER<br>
Merchant: ~.$SITE->username().qq~<br>
IP: $ENV{'REMOTE_ADDR'}<br>
Cart: ~.$THIS_CART->cartid() ];

			}
		}


	if (defined($webdbref->{'disable_checkout'}) && $webdbref->{'disable_checkout'}) {
		push @ISSUES, [ 'ISE', 'checkout_disabled', '', qq~<p>Checkout has been disabled for this merchant.</p>~ ];
		}

	my ($got_ise,$found_errors) = (0,0);
	foreach my $issue (@ISSUES) {
		if ($issue->[0] eq 'ERROR') { $found_errors++; }
		if ($issue->[0] eq 'ISE') { $got_ise++; }
		}

	if ($got_ise) {
		## SHIT HAPPENED.
		$STAGE = ['ERROR',{'reason'=>"got_ise: $got_ise"}];
		}
	elsif ($SENDER eq 'ORDER_CONFIRMATION') {

		# the !payfee element is an extra fee applied to the order if you payby a method 
		# which the merchant charges extra for. (this is good because we can consolidate COD, CHKOD, and 
		# future payment methods which present their own "opportunities" into this field.
		if ($found_errors) {
			# print STDERR "FOUND_ERRORS: ".Dumper(\@ISSUES);
			}
		else {
			if ($SITE::v->{'chkout.payby'}) {
				$cart2{'want/payby'} = $SITE::v->{'chkout.payby'};
				open F, ">/tmp/asdf"; print F Dumper($THIS_CART);	close F;
				}

			# print STDERR Dumper($SITE::v);

			# delete $cart2{'cgi.shipmethod'};
			if ($SITE::v->{'ship.selected_id'}) {
				## A little bit o kludge below: so the selected method doesn't match the new method.
				##		so by setting cgi.shipmethod to !methodname we'll force the cart to recalculate later on, but at the
				## 	the same time guarantee the digest below changes as well 
				##		(this avoid having to call SITE::CART->shipping here, which is what we really SHOULD be doing)
				if ($SITE::v_mixed->{'ship.selected_id'} ne $cart2{'will/shipping_id'}) {
					$cart2{'want/shipping_id'} = $SITE::v_mixed->{'ship.selected_id'};	## use the tainted variable
					}
				}
	
			if ($cart2{'is/ins_optional'}) {
				$cart2{'want/ins_purchased'} = (defined $SITE::v->{'ship.ins_purchased'})?1:0;
				}
			else {
				$cart2{'want/ins_purchased'} = 0;
				}

			if (defined $SITE::v->{'ship.bnd_purchased'}) {
				$cart2{'want/bnd_purchased'} = ($SITE::v->{'ship.bnd_purchased'})?1:0;
				}			
			else {
				$cart2{'want/bnd_purchased'} = 0;
				}
			}
		} 
	

	########################################
	# STAGE SETTING
	
	# $SENDER tells us which screen we came from, and then we figure out where we are going.
	# the basic flow is:
	
	# cart
	# choose
	# login
	# shipping_location
	# billing_location
	# new_customer
	# order_confirmation
	# payment_information
	# invoice_display
	# error
	
	my $POSSIBLE_ADDRESSES      = [];
	my $ADDRESS_VALIDATION_META = {};
	

	# The errors hash is for non-critical errors (such as incorrect field entry, etc.).  If there is a fatal
	# error, the stage should be set to ERROR and the string $error_message set.
	# If we're attempting to move forward and we have errors, keep us in the same place
	if ($SENDER eq 'START') {
		## we never try to check errors on the start stage.
		}
	elsif ($THIS_CART->count()==0) {
		push @ISSUES, [ 'ERROR', 'cart_empty', '', 'The shopping cart you are using is empty' ];
		}
	elsif ($VERB eq 'NEXT') {
		# Find if there's anything wrong with the input
			
		(my $validation_issues) = $THIS_CART->verify_checkout($SENDER,$SITE);
		foreach my $issue (@{$validation_issues}) {
			push @ISSUES, $issue;
			}

		if (scalar(keys %payment)>0) {
			# print STDERR 'PAYMENT: '.Dumper(\%payment);
 			# push @ISSUES, [ 'ERROR', 'payment', '', 'Generic error' ];
			my ($payment_issues) = $THIS_CART->verify_payment(\%payment,$webdbref);
			print STDERR 'PAYMENT_ISSUES: '.Dumper($payment_issues);
			foreach my $issue (@{$payment_issues}) {
				push @ISSUES, $issue;
				}
			}

		if ($SENDER eq 'SHIPPING_LOCATION') {
			($POSSIBLE_ADDRESSES, $ADDRESS_VALIDATION_META) = $THIS_CART->validate_address('ship');
			if (defined $SITE::v->{'chkout.ship_address_suggestions'}) {
				## we don't need to validate, since they already were displayed 
				}
			elsif ((scalar(@{$POSSIBLE_ADDRESSES})>0) && ($ADDRESS_VALIDATION_META->{'is_valid'}==0)) {
				push @ISSUES, [ 'ERROR', 'ship_validation', '', 'The shipping address provided is not accurate, please choose one of the suggestions' ];
				}
			}

		if ($SENDER eq 'BILLING_LOCATION') {
			($POSSIBLE_ADDRESSES, $ADDRESS_VALIDATION_META) = $THIS_CART->validate_address('bill');
			# print STDERR Dumper($POSSIBLE_ADDRESSES, $ADDRESS_VALIDATION_META);
			if (defined $SITE::v->{'chkout.bill_address_suggestions'}) {
				## we don't need to validate, since they already were displayed validation options
				}
			elsif ((scalar(@{$POSSIBLE_ADDRESSES})>0) && ($ADDRESS_VALIDATION_META->{'is_valid'}==0)) {
				push @ISSUES, [ 'ERROR', 'bill_validation', '', 'The billing address provided is not accurate, please choose one of the suggestions' ];
				}
			}
		# ERRORS: If we got anything back then there's something wrong
		}

	# print Dumper($SENDER,$STAGE,$errors);	
	my $DEBUGLINE = $SITE->username()." ".$THIS_CART->cartid()." email[$cart2{'bill/email'}] VERB[$VERB] SENDER[$SENDER] ";
	if (defined $STAGE) {
		$DEBUGLINE .= " STAGE[$STAGE->[0]] REASON[".((defined $STAGE->[1])?&ZTOOLKIT::buildparams($STAGE->[1]):'')."]\n";
		}
	else {
		$DEBUGLINE .= " NO STAGE.\n";
		}
	foreach my $issue (@ISSUES) {
		if ($issue->[0] eq 'ERROR') { $found_errors++; }
		if ($issue->[0] eq 'ISE') { $got_ise++; }
		$DEBUGLINE .= $SITE->username()." ".$THIS_CART->cartid()." ISSUE: ".Dumper($issue)."\n";
		}
	print STDERR "$DEBUGLINE\n";

	###########################################################################
	## 
	## this is the code which choose the $STAGE (what we're going to show)
	##
	if ($found_errors) {
		## we're going to send them back where they came from, unless we've been sent someplace else already.
		if ($VERB eq 'LAST') {
			## we should always let them go backwards.
			}
		elsif (not defined $STAGE) {
			$STAGE = [ $SENDER, { 'reason'=>"found_errors: $found_errors" }];
			}
		}
	elsif ($got_ise) {
		$STAGE = [ 'ERROR', { 'reason'=>"got_ise: $got_ise" }];
		}

	if (defined $STAGE) {
		## we already got a stage, so we can skip the rest here.

		if ($STAGE->[0] eq '') {
			$STAGE->[0] = 'ERROR'; $STAGE->[1]->{'err'} = 'stage not set, internal error';
			}

		}
	elsif ($SENDER eq 'LOGIN') {
		if ($VERB eq 'NEXT') {
			$STAGE = ['ORDER_CONFIRMATION',{"reason"=>"LOGIN/next"}];
			} 
		else {
			$STAGE = ['CHOOSE',{"reason"=>"LOGIN/$VERB"}];
			}
		} ## end elsif ($SENDER eq 'LOGIN'...
	elsif (($SENDER eq 'BILLING_LOCATION') || ($SENDER eq 'BILLING_LOCATION_WITH_LOGIN')) {
		if ($VERB eq 'NEXT') {
			# Are we billing to the shipping address? If so, go on to to confirmation
			$STAGE = [ (($cart2{'will/bill_to_ship'})?'ORDER_CONFIRMATION':'SHIPPING_LOCATION'), { "reason"=>"$SENDER/$VERB" }];
			}
		else {
			$STAGE = [ 'CHOOSE', {"reason"=>"$SENDER/$VERB"}];
			}
		} ## end elsif ($SENDER eq 'BILLING_LOCATION'...
	elsif ($SENDER eq 'SHIPPING_LOCATION') {
		if ($VERB eq 'NEXT') {
			$STAGE = ['ORDER_CONFIRMATION',{"reason"=>"$SENDER/$VERB"}];
			}
		else {
			# If we're going backwards, go to BILLING_LOCATION (so you don't get the login dialog, you're either already logged in or will be putting login information later)
			$STAGE = ['BILLING_LOCATION',{"reason"=>"$SENDER/$VERB"}];
			}
		}
	elsif ($SENDER eq 'ORDER_CONFIRMATION') {

		my $add_this_giftcard = undef;
		if ($VERB ne 'NEXT') {
			}
		elsif ($cart2{'will/payby'} =~ /^GIFTCARD\:(.*?)$/) {
			## they selected a giftcard payment method (which isn't really a payment method at all)
			$add_this_giftcard = $1;
			delete $cart2{'want/payby'};
			}
		elsif ($SITE::v->{'chkout.giftcard_number'} ne '') {
			## they added a giftcard number at checkout
			$add_this_giftcard = $SITE::v->{'chkout.giftcard_number'};
			}
	
		if (defined $add_this_giftcard) {
			my ($errors) = $THIS_CART->add_giftcard($add_this_giftcard);
			if (defined $errors) {					
				# use Data::Dumper; print STDERR Dumper($errors);
				foreach my $err (@{$errors}) {
					push @ISSUES, [ 'WARNING', 'giftcard.error', '', $err ];
					}
				}
			else {
				$cart2{'want/giftcard_number'} = '';
				}
			$VERB = 'REDO';
			}


		if ($VERB eq 'REDO') {
			$STAGE = ['ORDER_CONFIRMATION',{"reason"=>"$SENDER/$VERB"}];
			}
		elsif ($VERB eq 'NEXT') {
			$STAGE = [''];
	
			if ($SITE::DEBUG) { 
				$OUTPUT .= "ORIG CART DIGEST: \"$orig_cart_digest\" --- CURRENT DIGEST: \"".$THIS_CART->digest()."\"<br>"; 
				}

			# my $cart_changed = $THIS_CART->digest_has_changed($cart2{'cart/checkout_digest'},$THIS_CART->digest());
			print STDERR sprintf("DIGEST_ORIG:%s\nDIGEST_NOW::%s\n",$orig_cart_digest,$THIS_CART->digest());
			$cart_changed |= ($orig_cart_digest ne $THIS_CART->digest())?1:0;
			## hmm.. not sure why this line is here:
			## *** NEEDS LOVE *** does the checkout recognize when geometry/fees has changed and make them re- confirm order 
			#if ((($cart_changed & 4)==0) && (defined $cart2{'cgi.shipmethod'}) && ($cart2{'cgi.shipmethod'} ne '')) { 
			#	$cart_changed|=4; 
			#	}

			if ($SITE::DEBUG) { 
				$OUTPUT .= "CART/CHECKOUT_DIGEST: $cart2{'cart/checkout_digest'} changed: $cart_changed<br>"; 
				}

			if ($webdbref->{'banned'} ne '') {
				## BANNED LIST
				my $banned = 0;
				foreach my $line (split(/[\n\r]+/,$webdbref->{'banned'})) {
					my ($type,$match,$ts) = split(/\|/,$line);
					$match = quotemeta($match);
					$match =~ s/\\\*/.*/g; 
					if (($type eq 'IP') && ($ENV{'REMOTE_ADDR'} =~ /^$match$/)) { $banned++; }
					elsif (($type eq 'EMAIL') && ($cart2{'bill/email'} =~ /^$match$/i)) { $banned++; }
					elsif (($type eq 'ZIP') && ($cart2{'ship/postal'} =~ /^$match$/)) { $banned++; }
					elsif (($type eq 'ZIP') && ($cart2{'bill/postal'} =~ /^$match$/)) { $banned++; }
					}
				if ($banned) { $cart_changed |= 512; }
				}
				
			if ($cart_changed) {
				print STDERR "CHANGED: $cart_changed\n";
				}

			if ($cart_changed) {	
				$THIS_CART->shipmethods('flush'=>1);		# this forces the cart to re-update the SHIPPING values
				# now recompute the checksum, so that we don't accidentally loop here twice.
				$cart2{'cart/checkout_digest'} = $THIS_CART->digest();
				if ($SITE::DEBUG) {
					$OUTPUT .= sprintf("FLUSHED SHIPPING METHODS - CHECKSUM IS NOW: %s<br>",$cart2{'cart/checkout_digest'});
					}
				}
			if ($cart_changed) {
				# Don't let them go forward if they've changed something...  they need to see the new total!
				$STAGE = ['ORDER_CONFIRMATION',{'reason'=>'ORDER_CONFIRMATION cart_changed'}];
				}
	
			if ($STAGE->[0] eq '') {
				## this can output BLANK or "ORDER_CONFIRMATION"
				$STAGE = [$SITE->msgs()->get('chkout_confirm_specl')];
				if ($STAGE->[0] ne 'ORDER_CONFIRMATION') { $STAGE = ['']; }
				}
	
			if ($STAGE->[0] eq '') {
				if ($cart2{'bill/firstname'} eq '') {
					## arragh.. people get to the payment stage, and they've put in payment info, but they've nuked their 
					## address.. those bastards! send 'em back to the beginning.
					$STAGE = ['BILLING_LOCATION'];
					}
				elsif ($cart2{'will/payby'} eq '') {
					## somehow customers figure out how to get here without selecting a payment method - BAD CUSTOMER.
					## NOTE: this does NOT solve the problem of info mysteriously disappearing from the order.
					## However this does stop blank orders from being created processed, since without this block then
					## when we come from ORDER_CONFIRMATION and payby is blank, it isn't "isin" $payinfo_stages and
					## we head straight to INVOICE_DISPLAY
					$STAGE = ['ORDER_CONFIRMATION',{'reason'=>'ORDER_CONFIRMATION will/payby is blank'}];
					#open F, ">/tmp/cart2asdf"; print F Dumper($SITE);	close F;
					}
				elsif (&ZTOOLKIT::isin($pay_info_stages, $cart2{'will/payby'})) {
					# If we're paying by a method that needs more info, go get it
					$STAGE = ['PAYMENT_INFORMATION'];
					}
				else {
					$STAGE = ['INVOICE_DISPLAY'];
					}
				}
	
			} ## end if ($VERB eq 'NEXT')
		elsif ($VERB eq 'EDIT') {
			$STAGE = ['BILLING_LOCATION'];
			}
		elsif ($VERB eq 'EDIT SHIPPING') {
			$STAGE = ['SHIPPING_LOCATION'];
			}
		elsif ($VERB eq 'EDIT BILLING') {
			# Need to do this or we'll not be able to get back to billing info
			##$cart2{'will/bill_to_ship'} = 0; 
			$STAGE = ['BILLING_LOCATION'];
			}
		else {
			# Going backwards
			if ($cart2{'will/bill_to_ship'}) {
				# Bill_to_ship means we go back here
				$STAGE = ['BILLING_LOCATION'];
				}
			else {
				# Otherwise we go back here!
				$STAGE = ['SHIPPING_LOCATION'];
				}
			}
		} ## end elsif ($SENDER eq 'ORDER_CONFIRMATION'...
	#elsif ($SENDER eq 'NEW_CUSTOMER') {
	#	if ($VERB eq 'NEXT') {
	#		if ($cart2{'bill/firstname'} eq '') {
	#			## arragh.. people get to the new customer stage, and they've put in payment info, but they've nuked their 
	#			## address.. those bastards! send 'em back to the beginning.
	#			$STAGE = ['BILLING_LOCATION'];
	#			}
	#		elsif (&ZTOOLKIT::isin($pay_info_stages, $cart2{'will/payby'})) {
	#			# If we're paying by a method that needs more info, go get it
	#			$STAGE = ['PAYMENT_INFORMATION'];
	#			}
	#		elsif ($cart2{'will/payby'} eq '') {
	#			## somehow customers figure out how to get here without selecting a payment method - BAD CUSTOMER.
	#			## NOTE: this does NOT solve the problem of info mysteriously disappearing from the order.
	#			## However this does stop blank orders from being created processed, since without this block then
	#			## when we come from ORDER_CONFIRMATION and payby is blank, it isn't "isin" $payinfo_stages and
	#			## we head straight to INVOICE_DISPLAY
	#			$STAGE = ['ORDER_CONFIRMATION']; 
	#			}
	#		else {
	#			$STAGE = ['INVOICE_DISPLAY'];
	#			}
	#		}
	#	else {
	#		# Going backwards
	#		$STAGE = ['ORDER_CONFIRMATION'];
	#		}
	#	} 
	elsif ($SENDER eq 'PAYMENT_INFORMATION') {
		if ($VERB eq 'NEXT') {
			# Final checkout!
			if ($cart2{'bill/firstname'} eq '') {
				## arragh.. people get to the new customer stage, and they've put in payment info, but they've nuked their 
				## address.. those bastards! send 'em back to the beginning.
				$STAGE = ['BILLING_LOCATION'];
				}
			elsif ($cart2{'will/payby'} eq '') {
				## somehow customers figure out how to get here without selecting a payment method - BAD CUSTOMER.
				## NOTE: this does NOT solve the problem of info mysteriously disappearing from the order.
				## However this does stop blank orders from being created processed, since without this block then
				## when we come from ORDER_CONFIRMATION and payby is blank, it isn't "isin" $payinfo_stages and
				## we head straight to INVOICE_DISPLAY
				$STAGE = ['ORDER_CONFIRMATION',{'reason'=>'PAYMENT_INFORMATION will/payby is blank'}]; 
				}
			else {
				$STAGE = ['INVOICE_DISPLAY'];
				}
			}
		else {
			# Going backwards
			$STAGE = ['ORDER_CONFIRMATION',{'reason'=>'back button from PAYMENT_INFORMATION'}];
			} ## end else
		} ## end elsif ($SENDER eq 'PAYMENT_INFORMATION'...
	else {
		# No stage defined, use the default for the merchant's checkout setup
		warn "UNKNOWN SENDER: $SENDER\n";
		}

	
	########################################
	# CART TOTALS

	
	## Calculates a ton of stuff, including applicable shipping, totals, etc.
	my $fulladdr = $cart2{'ship/address1'};
	if ($cart2{'ship/address2'} ne '') { $fulladdr .= "\n".$cart2{'ship/address2'}; }

	
	if (not defined $cart2{'ship/countrycode'}) { $cart2{'ship/countrycode'} = $cart2{'bill/countrycode'}; }	
	if (not defined $cart2{'ship/region'}) { $cart2{'ship/region'} = $cart2{'bill/region'}; }	
	if (not defined $cart2{'ship/postal'}) { $cart2{'ship/postal'} = $cart2{'bill/postal'}; }	

	if ($cart2{'ship/countrycode'} eq '') { $cart2{'ship/countrycode'} = 'US'; }
	if ($cart2{'bill/countrycode'} eq '') { $cart2{'bill/countrycode'} = 'US'; }

	# my ($changed) = $THIS_CART->shipping();

	########################################
	# PAYMENT PROCESSING

	# Get the possible mayment methods
	my ($paymentsref) = &ZPAY::payment_methods($SITE->username(), 
		cart2=>$THIS_CART, 
		country=>$cart2{'ship/countrycode'}, 
		ordertotal=>$cart2{'sum/balance_due_total'}, 
		webdb=>$webdbref);

#	print STDERR Dumper($SITE::CART,$paymentsref); die();

	if ((scalar @{$paymentsref})==0) {
		# The ERROR stage is used specifically for critical errors that can't be circumvented
		push @ISSUES, [ 'ERROR', 'no_available_payment_methods', '', "<p>Merchant selected shipping methods, but no payment methods are available for destination country ($cart2{'ship/countrycode'}). Cannot check out. </p>\n" ];
		$cart2{'ship/countrycode'} = '';
		$cart2{'bill/countrycode'} = '';
		$THIS_CART->save();
		}
	elsif ($STAGE->[0] eq 'INVOICE_DISPLAY') {
		## lets quickly verify that this payment method is still valid 
		## (and wasn't copied from the customer record and is no longer actually available)
		my $found = 0;
		foreach my $m (@{$paymentsref}) {
			if ($m->{'id'} eq $cart2{'will/payby'}) { $found++; }
			}

		if (not $found) {
			warn "seems we should not offer $cart2{'will/payby'}";
			$cart2{'want/payby'} = '';
			}
		}

	
	# at this point we have $cart->shipmethods() populated
	# we also have $grandtotal, $cart2{'order/subtotal'}, $cart{'ship.selected_price'}, $cart2{'tax/total'} all set.
	
	########################################
	# SAVE ORDER INTO SYSTEM
	if (($STAGE->[0] eq 'INVOICE_DISPLAY') && ($cart2{'will/payby'} eq '')) {
		## silly customer probably emptied the cart right before checkout
		warn $SITE->username()." ".$THIS_CART->cartid()." DANGER: seems the silly customer appears to have emptied the cart right before checkout";
		$STAGE = ['ORDER_CONFIRMATION',{"reason"=>"chkout.payby is empty"}];
		if (($cart_changed & 2)==0) { $cart_changed |= 2; }		# show them the "your payment type changed" message
		}


	if ($STAGE->[0] eq 'INVOICE_DISPLAY') {
		## *** NEEDS LOVE *** (seriously)
		## $cart2{'our/profile'} = $SITE->profile();

		if ($cart2{'cart/ip_address'} eq '') {
			my $ip = $ENV{'REMOTE_ADDR'};
			if (defined $ENV{'HTTP_X_FORWARDED_FOR'}) { $ip =	$ENV{'HTTP_X_FORWARDED_FOR'}; }
			# Default to the server's address if the remote address is internal (on some payment methods, invalid IPs are automatically declined as fraud)
			if (($ip =~ /^127\..*$/) || ($ip =~ /^192\.168\..*$/) || ($ip =~ /^10\..*$/)) { $ip = $ENV{'SERVER_ADDR'}; }
			if ($ip =~ /,[\s]*(.*?)$/) { $ip = $1; }	## strip proxy
			$cart2{'cart/ip_address'} = $ip;
			}

		# $CART2->paymentQ('insert',$cart2{'will/payby'},0,\%payment);
		# 'payment_cgi_vars'=>\%payment
		# $THIS_CART->balance_payments(keep_auto=>1);
		# $THIS_CART->__SYNC__();
		# $THIS_CART->log('CHECKOUT '.Dumper($THIS_CART));

		## *** MAGIC AND TRICKERY STARTS HERE ***
		my $O2 = Storable::dclone($THIS_CART);
		$O2->add_auto_payby(\%payment);

		($LM) = $O2->finalize_order(
			'*LM'=>$LM, 
			'app'=>sprintf("LegacyCheckout/%s",&ZOOVY::servername())
			);
		## NOW -- pay attention below:
		##		* $THIS_CART is *NORMALLY* a reference to $SITE::CART2 -- however if we just created an order
		##		* then it's really it's own copy (this lets us trash the $SITE::CART or whatever)
		if ($LM->has_win()) { $THIS_CART = $O2; }
		## *** /END MAGIC ***

		if ($SITE::CART2->in_get('customer/login') ne '') {
			my $USERNAME = $THIS_CART->username();
			push @SITE::cookies, {'name' => "$USERNAME-login", 'value' => $THIS_CART->in_get('customer/login'), 'hours' => 8760};
			}

		} 
	
	########################################
	# ENCODE CURRENT FORM FIELDS
	
	# This takes all of the fields in $info and creates a string called $encoded_fields that can be used to retrieve the contents.
	# my $encoded_fields = &ZTOOLKIT::ser($info, 1, 1);
	
	# Store the info hash in the cart in case they want to go somewhere else in the middle of the checkout process.
	#my $clean_info = {};
	#foreach my $key (keys %{$info}) {
	#	next if ($key =~ m/^cc_/);
	#	next if ($key =~ m/password/);
	#	next if (($STAGE eq 'INVOICE_DISPLAY') && ($key !~ m/^(shipping|billing)\_/));
	#	$clean_info->{$key} = $info->{$key};
	#	}
	#$THIS_CART->save_property('checkout_info', $clean_info);
	
	#  Basically at this point all the initialization is done, now the HTML output of the variables starts. 
	
	##############################################################################
	## Set Up FLOW Variables
	

	require TOXML::RENDER;
	$SITE->title( 'Checkout: '.$STAGE->[0] );	
	if ((defined $STAGE->[1]) && (defined $STAGE->[1]->{'title'})) {
		$SITE->title( $STAGE->[1]->{'title'} );
		}
	# $SITE::SREF->{'+stage'} = $STAGE->[0];
	if ($SITE::DEBUG) { $OUTPUT .= "SITE::DEBUG[$SITE::DEBUG] STAGE:".Dumper($STAGE)."<hr>DEBUG: ".Dumper($SITE::v)."<br>"; }

	##############################################################################
	## Output Page
	
	my $graphics_url = $SITE->URLENGINE()->get('graphics_url');
	my $checkout_url = $SITE->URLENGINE()->get('checkout_url');
	my $forgot_url   = $SITE->URLENGINE()->get('forgot_url') . "?url=" . &CGI::escape($checkout_url);
		
	## NOTE: we create a "hidden" forward button (width=0,height=0) and pre-pend it to all previous buttons in case the user presses enter on the form
	my $back_button       = &TOXML::RENDER::RENDER_SITEBUTTON({'button' => 'back',  id=>'backButton', 'name' => 'last', 'alt' => 'Previous'},undef,$SITE);
	## note: we prepend a "forward" button of 0x0 so that when a user presses enter it will submit forward (not backward)
	
	my $next_button       = &TOXML::RENDER::RENDER_SITEBUTTON({'button' => 'forward', 'id'=>'nextButton', 'name' => 'next', 'alt' => 'Next',
		'onclick' => 'changeButton();'
		},undef,$SITE);

#<!-- NOTE - the return false is here just to keep the form from submitting, otherwise the page reloaded and you can't see how cool this is -->
#<form action="" id='myForm' name='myForm' onsubmit='changeButton(); return false;'>
#
#<input type='image' src='http://snapcdn.wrapper.lg1x8.simplecdn.net/merchant/gkworld/_ticket_195084/gk09_checkout-160x63.gif' id='checkoutButton' name='checkoutButton'>
#
#
#</form>

#	push @ISSUES, [ 'WARNING', '', '', "WAY AFTER: cart{'chkout.create_customer'} = $cart{'chkout.create_customer'} $cart{'chkout.email_update'}" ];
	
	########################################
	# BEGIN FIELD ERROR DISPLAY

	
	my %field_indicators = ();
	foreach (keys %fields) { $field_indicators{$_} = ''; }
	print STDERR 'ISSUES: '.Dumper(\@ISSUES);
	foreach my $issue (@ISSUES) {
		my ($type,$source,$field,$errmsg) = @{$issue};
		next if (($type ne 'ERROR') && ($type ne 'WARNING'));

		$field_indicators{$field} = qq~<font class="zwarn"><blink>*</blink></font>~;

		if (ref($errmsg) eq 'HASH') { $errmsg = '<pre>'.Dumper($errmsg).'</pre>'; }
		$OUTPUT .= qq~<div class="zwarn"><!-- $type:$source -->$errmsg</div>\n~;
		# $OUTPUT .= qq~<font class="zwarn"><pre>~.Dumper($issue).qq~</pre></font>~;
		}
	
	# END FIELD ERROR DISPLAY
	########################################
	
	########################################
	# BEGIN ERROR
	if ($STAGE->[0] eq 'ERROR') {
		$SITE->title( 'Checkout Error' ); 
		if ($SENDER eq 'SOFT-ERROR') { $SITE->title( "Something went wrong." ); }
		foreach my $issue (@ISSUES) {
			$OUTPUT .= qq~
<div class="zwarn">
<!-- 
[0]:$issue->[0]
[1]:$issue->[2]
[2]:$issue->[3]
-->
$issue->[3]
</div>
~;
			warn "$issue->[0].$issue->[1].$issue->[2]: $issue->[3]\n";
			}

		if ($SENDER eq 'SOFT-ERROR') {
			}
		else {
			#if ($shop !~ /^$SITE->username()/) { $shop = $SITE->username() . "/$shop"; }
			$OUTPUT .= qq~This issue may resolve itself in a few moments, please try again.<br>
If the issue persists please try emptying your cart.
<br>~;
			my $shop = $SITE->URLENGINE()->get('continue_url');
			$OUTPUT .= qq~<a href="$shop">Continue Shopping</a><br>~;
			}	
		}
	# END ERROR
	########################################
	
	$OUTPUT .= qq~
	<script language="JavaScript">
	<!--
	var clicks=0;
	function prevent_double() {
	clicks++; if (clicks > 1) { alert('Your order is being processed, please stand by.'); return false; }
	}
	//-->
	</script>

<div id='pleaseWaitDiv' style='display:none;'>Please wait....</div>

<script type='text/javascript'>
	loading_img = new Image();
	loading_img.src='//static.zoovy.com/graphics/paymentlogos/loading.gif';
	function changeButton()	{

//		btn = document.getElementById('nextButton');
//		btn.src = loading_img.src;
		// alert("yellow");
//		btn.disabled = true;
//		btn.style.cursor = 'wait';

//		btn = document.getElementById('backButton');
//		btn.disabled = true;

//		document.getElementById('pleaseWaitDiv').style.display = 'block';		
		return(true);
		}
</script>


	~;

	## track the stage we're in.
	$cart2{'cart/checkout_stage'} = $STAGE->[0];
	
	########################################
	# BEGIN CHOOSE

	if ($STAGE->[0] eq 'PREFLIGHT') {
		$SITE->title( 'Checkout' );
		$OUTPUT .= qq~
<br>
<center>
<form method="post" action="$checkout_url" name="checkout">
<input type="hidden" name="sender" value="PREFLIGHT">
<table cellpadding="2" cellspacing="0" border="0">
	<tr>
		<td colspan="2">~.$SITE->msgs()->get('chkout_preflight').qq~</td>
	</tr>
	<tr>
		<td width="33%" align="right" valign="middle">
		<font class="ztxt">
		Name ($field_indicators{'data.bill_firstname'}First, MI, $field_indicators{'data.bill_lastname'}Last):
		</font>
		</td>
		<td width="67%" align="left" valign="middle">
			<input type="textbox" class="ztextbox" size="20" maxlength="20" name="data.bill_firstname" value="$cart2{'bill/firstname'}">
			<input type="textbox" class="ztextbox" size="1" maxlength="1" name="data.bill_middlename" value="$cart2{'bill/middlename'}">
			<input type="textbox" class="ztextbox" size="20" maxlength="20" name="data.bill_lastname" value="$cart2{'bill/lastname'}">
		</td>
	</tr>
	<tr>
		<td width="33%" align="right" valign="middle">
			<font class="ztxt">
			$field_indicators{'data.bill_email'}Email:
			</font>
		</td>
		<td width="67%" align="left" valign="middle">
			<input type="textbox" class="ztextbox" size="45" maxlength="60" name="data.bill_email" value="$cart2{'bill/email'}">
		</td>
	</tr>
	<tr>
		<td width="33%" align="right" valign="middle">
		<font class="ztxt">
		$field_indicators{'data.bill_phone'}Phone:
		</font>
		</td>
		<td width="67%" align="left" valign="middle">
			<input type="textbox" class="ztextbox" size="20" maxlength="20" name="data.bill_phone" value="$cart2{'bill/phone'}">
		</td>
	</tr>
	<tr>
		<td colspan="2">~.$SITE->msgs()->get('chkout_preflight_footer').qq~</td>
	</tr>
	<tr>
		<td class="chkout_bottom_nav" colspan="2">
			<div style="float:right;">$next_button</div>
			<div style="float:left;">$back_button</div>
			<div style="clear:both;"></div>
		</td>	
	</tr>
</table>
</form>
</center>
		~;
		}


	if ($STAGE->[0] eq 'CHOOSE') {
		$SITE->title( 'Checkout' );	

		my $newcustomers = 'New Customers';
		my $oldcustomers = 'Existing Customers';
	
		if ($CUSTOMER_MANAGEMENT eq 'NICE') {
			$newcustomers = 'New / Unregistered Customers';
			$oldcustomers = 'Registered Customers';
			}

		#if (($SITE::v->{'login.user'} eq '') && &SITE::last_login()) {
		#	## HEY HEY HEY -- this will cause us to look up the last login by the cookie.
		#	$SITE::v->{'login.user'} = &SITE::last_login();
		#	}
	
		my $checkout_button = &TOXML::RENDER::RENDER_SITEBUTTON({'button' => 'checkout', 'name' => 'next', 'alt' => 'Checkout'},undef,$SITE);
		my $choose_new      = $SITE->msgs()->get('chkout_choose_new');
		my $choose_existing = $SITE->msgs()->get('chkout_choose_existing');
		my $choose_usertxt = $SITE->msgs()->get('chkout_choose_usertxt');

		my $googlebutton = '';
		#if ($THIS_CART->{'+sandbox'}==0) {}
#		if ($webdbref->{'google_api_env'}>0) {
#			## 
#			require ZPAY::GOOGLE;
#			$googlebutton = &ZPAY::GOOGLE::button_html($THIS_CART,$SITE);
#			my $gmid = $webdbref->{'google_merchantid'};
#			my $cartid = $SITE->username()."!".$THIS_CART->cartid();
#			my $url = "https://sandbox.google.com/checkout/cws/v2/Merchant/$gmid/checkout?cart=$cartid&signature=";
#			my $secure_url = $SITE->URLENGINE()->get('secure_url');
#			$googlebutton = qq~
#<script src="https://checkout.google.com/files/digital/urchin_post.js" type="text/javascript">
#<a href="javascript:document.location='$secure_url/_googlecheckout?urchin='+getUrchinFieldValue();"><img height=43 width=160 border=0 src="https://checkout.google.com/buttons/checkout.gif?merchant_id=$gmid&w=160&h=43&style=white&variant=text&loc=en_US"></a>~;
#			}
	
		$OUTPUT .= qq~
			<div align="center">
			<table border="0" cellpadding="5" cellspacing="3" width="560">
				<tr>
					<td align="left" height="25" class="ztable_head" width="280">
						<b>$newcustomers</b><br>
					</td>
					<td align="left" height="25" class="ztable_head" width="280">
						<b>$oldcustomers</b><br>
					</td>
				</tr>
				<tr>
					<td align="left" valign="top" width="280">
					<form method="post" action="$checkout_url">
					<input type="hidden" name="sender" value="CHOOSE.NEW">
						<font class="ztxt">
						$choose_new
						$checkout_button<br>
						</font>
						<br>
					</form>
					</td>

					<td rowspan="3" align="left" valign="top" width="280">
					<form method="post" action="$checkout_url">
					<input type="hidden" name="sender" value="CHOOSE.LOGIN">
						<font class="ztxt">
						$choose_existing
						<table>
							<tr>
								<td><font class="ztxt">Login/Email:</font></td>
								<td><input type="textbox" class="ztextbox" size="20" maxlength="60" name="login.user" value="$SITE::v->{'login.user'}"></td>
							</tr>
							<tr>
								<td><font class="ztxt">Password:</font></td>
								<td><input type="password" class="ztextbox" size="20" maxlength="20" name="login.pass" value="$SITE::v->{'login.pass'}"></td>
							</tr>
							<tr>
								<td colspan='2'>
								<i><font class="ztxt"><a href="$forgot_url" target="$SITE::target">Forgot your password?</font></a></i><br>
								</td>
							</tr>
						</table>
						<br>
						$checkout_button<br>
						<br>
						</font>
					</form>
					</td>
				</tr>
				<tr>
					<td colspan=1>$googlebutton</td>
				</tr>
				<tr>
					<td colspan=1>$choose_usertxt</td>
				</tr>
			</table>
			</div>
		~;

#	$OUTPUT .= q~<table width=100%><tr><td align="left">
#<font size=1>Checkout Assistance Code: <% loadurp("CART::chkout.assistid"); default(""); print(); %></font><br>
#</td></tr></table>
#~;
		} 
	# END CHOOSE
	########################################

	
	########################################
	# BEGIN LOGIN
	if ($STAGE->[0] eq 'LOGIN') {
		$SITE->title( 'Login' );	
		#if (($SITE::v->{'login.user'} eq '') && &SITE::last_login()) {
		#	$SITE::v->{'login.user'} = &SITE::last_login();
		#	}
	
		my $login_message;
		if (($CUSTOMER_MANAGEMENT eq 'MEMBER') || ($CUSTOMER_MANAGEMENT eq 'PRIVATE')) {
			$login_message = $SITE->msgs()->get('chkout_login_restricted');
			$back_button = '';
			}
		else {
			$login_message = $SITE->msgs()->get('chkout_login_public');
			}
	
		$OUTPUT .= qq~
	<table width="100%" cellpadding="2" cellspacing="0" border="0">
		<form method="post" action="$checkout_url">
		<input type="hidden" name="sender" value="LOGIN">
		<tr>
			<td colspan="2" align="center">
				<table width="300" cellpadding="0" cellspacing="0" border="0">
					<tr>
					<td align="left">
						<font class="ztxt">
						$login_message
						$field_indicators{'login.user'}<b>Login:</b> <font size="-1"><i>(This is usually your email address)</i></font><br>
						<input type="textbox" class="ztextbox" size="30" maxlength="60" name="login.user" value="$SITE::v->{'login.user'}"><br>
						$field_indicators{'login.pass'}<b>Password:</b> <i><a href="$forgot_url" target="$SITE::target"><font size="-1">Forgot your password?</font></a></i><br>
						<input type="password" class="ztextbox" size="20" maxlength="20" name="login.pass" value=""><br>
						</font>
					</td>
					</tr>
				</table>
			</td>
		</tr>					
		<tr>
			<td colspan="2"><img src="$graphics_url/blank.gif" height="10" width="1"></td>
		</tr>
	<tr>
		<td class="chkout_bottom_nav" colspan="2">
			<div style="float:right;">$next_button</div>
			<div style="float:left;">$back_button</div>
			<div style="clear:both;"></div>
		</td>	
	</tr>
	</table>
</form>
~;
		} 	
	# END LOGIN
	########################################
	
	########################################
	# BEGIN BILLING_LOCATION
	if ($STAGE->[0] eq 'BILLING_LOCATION') {
		if ($forcebilltoship) { 
			$SITE->title( 'Billing and Shipping Address' ); }
		else { 
			$SITE->title( 'Billing Address' ); 
			}

		if ($SITE::DEBUG) { $OUTPUT .= "LOGIN[$cart2{'customer/login'}]<br>\n"; }

		if ($THIS_CART->cid()>0) {
			## they are already logged in.
			}
		elsif ($cart2{'will/create_customer'}==100) {
			$OUTPUT .= "<a href=\"?sender=LOGIN\">Click here to Login</a>";
			}


	
		if ($forcebilltoship) {
			$OUTPUT .= $SITE->msgs()->get('chkout_shipping_billing');
			}
		else {
			$OUTPUT .= $SITE->msgs()->get('chkout_billing');
			}

		## BEGIN ADDRESS VALIDATION	
		my $correction            = '';
		my $correction_disclaimer = '';
		if (defined $ADDRESS_VALIDATION_META->{'force_blurb'}) {
			$correction_disclaimer .= $ADDRESS_VALIDATION_META->{'force_blurb'};
			}
		if (($ADDRESS_VALIDATION_META->{'is_valid'}==0) && (scalar(@{$POSSIBLE_ADDRESSES})>0)) {
			require JSON::XS;
			# JSON::XS::encode_json([{"foo"=>"faa"}]);
			$correction = qq~<script language="JavaScript">
			<!--
			function change_fields(suggestion) {
				var addresses = ~.JSON::XS::encode_json($POSSIBLE_ADDRESSES).qq~;

				for (var i = 0; i < addresses.length; i++) {
					if (addresses[i]['id'] == suggestion) {
						document.checkout['data.bill_city'].value = addresses[i]['city'];			
						document.checkout['data.bill_state'].value = addresses[i]['state'];			
						document.checkout['data.bill_zip'].value = addresses[i]['zip'];			
						}
					}
				}
			//-->
			</script>
			<select class="zselect" name="chkout.bill_address_suggestions" 
				onChange="change_fields(this.options[this.selectedIndex].value)">
			~;
			foreach my $possibility (@{$POSSIBLE_ADDRESSES}) {
				my $selected = (($SITE::v->{'chkout.bill_address_suggestions'} eq $possibility->{'id'})?'selected':'');
				$correction .= "<option value=\"$possibility->{'id'}\">$possibility->{'prompt'}</option>\n";
				}
			$correction .= qq~
			</select>
			<i>This will automatically update the appropriate fields below.</i><br>
			~;
			}
		## END ADDRESS VALIDATION 

		if ($cart2{'customer/login'} ne '') {
			$OUTPUT .= $SITE->login_trackers($THIS_CART);
			}
	
		my $state          = 'State';
		my $statesize      = '2';
		my $statemax       = '2';
		my $zip            = 'ZIP';
		my $zipsize        = '10';
		my $zipmax         = '10';
		my $choose_country = "United States (we do not accept international orders)";

		my $available_destinations = &ZSHIP::available_destinations($THIS_CART,$webdbref);
		if ((scalar @{$available_destinations})>1) {
			$state          = 'State / Province';
			$statesize      = '20';
			$statemax       = '30';
			$zip            = 'ZIP / Postal Code';
			$zipsize        = '20';
			$zipmax         = '20';
			$choose_country = qq~<select class="zselect" name="data.bill_country">\n~;
			foreach my $shipto (@{$available_destinations}) {
				$choose_country .= 
					sprintf(q~<option value="%s" %s>%s</option>\n~,
						$shipto->{'ISO'},
						(($shipto->{'ISO'} eq $cart2{'bill/countrycode'})?'selected':''),
						$shipto->{'Z'}
						);
				}
			$choose_country .= qq~</select>\n~;
			} 


		$OUTPUT .= qq~
			<table width="100%" cellpadding="2" cellspacing="0" border="0">
				<form method="post" action="$checkout_url" name="checkout">
				<input type="hidden" name="sender" value="BILLING_LOCATION">
				<tr>
					<td colspan="2"><img src="$graphics_url/blank.gif" height="10" width="1"></td>
				</tr>
			~;

		############## EXISTING BILL ADDRESS
		my ($C) = $THIS_CART->customer();

		if ((defined $C) && (scalar(@{$C->fetch_addresses('BILL')})>0)) {			
			$OUTPUT .= qq~
<tr>
	<td width="33%" align="right" valign="top">
		<font class="ztxt">
		Address On File:
		</font>
	</td>
	<td width="67%" align="left" valign="middle">
		<select class="zform_select" onChange="
	var addr = this.value.toString().split('|');
	if (this.selectedIndex>0) {
		document.checkout['data.bill_firstname'].value = addr[0];
		document.checkout['data.bill_lastname'].value = addr[1];
		document.checkout['data.bill_company'].value = addr[2];
		document.checkout['data.bill_address1'].value = addr[3];
		document.checkout['data.bill_address2'].value = addr[4];
		document.checkout['data.bill_city'].value = addr[5];
		document.checkout['data.bill_state'].value = addr[6];
		document.checkout['data.bill_zip'].value = addr[7];
		if (document.checkout['data.bill_country'].value) {
			document.checkout['data.bill_country'].value = addr[8];
			}
		document.checkout['data.bill_phone'].value = addr[9];
		if (addr[10] != '') {
			document.checkout['data.bill_email'].value = addr[10];
			}
		}
	" name="addr_on_file">
			<option value="">--</option>
			~;
		foreach my $custaddr (@{$C->fetch_addresses('BILL')}) {
			my $addr = $custaddr->as_hash();
			my $val = '';
			$val .= $addr->{'firstname'}.'|';
			$val .= $addr->{'lastname'}.'|';
			$val .= $addr->{'company'}.'|';
			$val .= $addr->{'address1'}.'|';
			$val .= $addr->{'address2'}.'|';
			$val .= $addr->{'city'}.'|';
			$val .= $addr->{'region'}.'|';
			$val .= $addr->{'postal'}.'|';
			$val .= $addr->{'countrycode'}.'|';
			$val .= $addr->{'phone'}.'|';
			$val .= $addr->{'email'}.'|';
			$OUTPUT .= "<option value=\"$val\">$addr->{'ID'}: $addr->{'address1'}; $addr->{'city'}, $addr->{'state'}</option>";
			}
$OUTPUT .= "</select>";
$OUTPUT .= qq~
		</font>
		</td>
</tr>
<tr>
	<td colspan=3><hr></td>
</tr>
	~;
			}
		################

		if ($correction) {
			$OUTPUT .= qq~
				<tr>
					<td width="33%" align="right" valign="top">
						<font class="ztxt">
						Address Correction:
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<font class="ztxt">
						$correction
						</font>
					</td>
				</tr>
			~;
			}

		if ($correction_disclaimer && $correction) {
			$OUTPUT .= qq~
				<tr>
					<td colspan="2" align="center" valign="top">
						<font class="ztxt">
						$correction_disclaimer
						</font>
					</td>
				</tr>
			~;
			}
		$OUTPUT .= qq~
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						Name ($field_indicators{'data.bill_firstname'}First, MI, $field_indicators{'data.bill_lastname'}Last):
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="20" maxlength="20" name="data.bill_firstname" value="$cart2{'bill/firstname'}">
						<input type="textbox" class="ztextbox" size="1" maxlength="1" name="data.bill_middlename" value="$cart2{'bill/middlename'}">
						<input type="textbox" class="ztextbox" size="20" maxlength="20" name="data.bill_lastname" value="$cart2{'bill/lastname'}">
					</td>
				</tr>
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						Company:
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="45" maxlength="45" name="data.bill_company" value="$cart2{'bill/company'}">
					</td>
				</tr>
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						$field_indicators{'bill_address1'}Address:
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox"  size="35" maxlength="35" name="data.bill_address1" value="$cart2{'bill/address1'}">
					</td>
				</tr>
				<tr>
					<td width="33%" align="right" valign="middle">
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="35" maxlength="35" name="data.bill_address2" value="$cart2{'bill/address2'}">
					</td>
				</tr>
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						$field_indicators{'bill_city'}City:
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="20" maxlength="40" name="data.bill_city" value="$cart2{'bill/city'}">
					</td>
				</tr>
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						$field_indicators{'bill_state'}$state : 
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="$statesize" maxlength="$statemax" name="data.bill_state" value="$cart2{'bill/region'}">
					</td>
				</tr>
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						$field_indicators{'bill_zip'}$zip : 
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="$zipsize" maxlength="$zipmax" name="data.bill_zip" value="$cart2{'bill/postal'}">
					</td>
				</tr>
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						Country :
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<font class="ztxt">
						$choose_country
						</font>
					</td>
				</tr>
		~;

		if ($require_phone >= 0) {
			my $phone_optional = ($require_phone==0) ? '(Optional)' : '';
			$OUTPUT .= qq~
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						$field_indicators{'bill_phone'}Phone:
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="20" maxlength="20" name="data.bill_phone" value="$cart2{'bill/phone'}">
						<font class="ztxt">
						$phone_optional
						</font>
					</td>
				</tr>
			~;
			}

		$OUTPUT .= qq~
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						$field_indicators{'data.bill_email'}Email:
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="20" maxlength="60" name="data.bill_email" value="$cart2{'bill/email'}">
					</td>
				</tr>
		~;

		unless ($forcebilltoship) {
			my $checked = '';
			if ($cart2{'will/bill_to_ship'}) { $checked = ' checked'; }
			# Only allow the ability to bill to a different address as the shipping address only if not international
			$OUTPUT .= qq~
				<tr>
					<td width="33%" align="right" valign="top">
						<input class="zcheckbox" type="checkbox" name="chkout.bill_to_ship" value="1"$checked>
					</td>
					<td width="67%" align="left" valign="middle">
						<font class="ztxt">
						Ship to the Billing Address above
						</font>
					</td>
				</tr>
			~;
			}

		unless ($forceresidential) {
			my $checked = '';
			if ($cart2{'want/shipping_residential'}) { $checked = ' checked'; }
			# Only allow the ability to bill to a different address as the shipping address only if not international
			$OUTPUT .= qq~
				<tr>
					<td width="33%" align="right" valign="top">
						<input class="zcheckbox" type="checkbox" name="chkout.shipping_residential" value="1"$checked>
					</td>
					<td width="67%" align="left" valign="middle">
						<font class="ztxt">
						Residential Delivery (This will be shipped to a home, not a business)
						</font>
					</td>
				</tr>
			~;
			}
	

		
		

		print STDERR "CUSTOMER_MANAGEMENT: $CUSTOMER_MANAGEMENT\n";

		if (($CUSTOMER_MANAGEMENT eq 'NICE') || ($CUSTOMER_MANAGEMENT eq 'STRICT')) {

			if ($cart2{'customer/login'} eq '') {
				my $create_account = $SITE->msgs()->get('chkout_create_account');
				my $checked = ($cart2{'will/create_customer'})?'checked':'';
				my $onoff = ($cart2{'will/create_customer'})?1:0;

				$OUTPUT .= qq~
					<tr>
						<td width="33%" align="right" valign="top">
							<input type="hidden" name="chkout.create_customer" value="$onoff"> 
							<input class="zcheckbox" type="checkbox" name="chkout.create_customer_cb" onChange="document.forms['checkout']['chkout.create_customer'].value = (this.checked?1:0);" value="ignore" $checked> 
						</td>
						<td width="67%" align="left" valign="middle">
							<font class="ztxt">
							Create customer account<br>
							$create_account
							</font>
						</td>
					</tr>
				~;
				}
			else {
				$OUTPUT .= qq~<tr><td colspan=2><font class="ztxt">You are currently logged in as: $cart2{'customer/login'}</font></td></tr>~;
				}
			} ## end if (($cart2{'customer/login'} ...

		if ($correction_disclaimer && !$correction)
		{
			$OUTPUT .= qq~
				<tr>
					<td colspan="2" align="center" valign="top">
						<font class="ztxt">
						$correction_disclaimer
						</font>
					</td>
				</tr>
			~;
		}

		my $footmsg = $SITE->msgs()->get('chkout_billing_footer');

		if (($CUSTOMER_MANAGEMENT eq 'DISABLED') || ($CUSTOMER_MANAGEMENT eq 'PASSIVE')) { $back_button = ''; }
		$OUTPUT .= qq~
				<tr>
					<td colspan="2">~.$SITE->msgs()->get('chkout_billing_footer').qq~</td>
				</tr>
	<tr>
		<td class="chkout_bottom_nav" colspan="2">
			<div style="float:right;">$next_button</div>
			<div style="float:left;">$back_button</div>
			<div style="clear:both;"></div>
		</td>	
	</tr>
			</table>
		</form>
		~;
		} 
	# END BILLING_LOCATION
	########################################
	
	########################################
	# BEGIN SHIPPING LOCATION
	if ($STAGE->[0] eq 'SHIPPING_LOCATION') {
		$SITE->title( 'Shipping Address' );	

		$OUTPUT .= $SITE->msgs()->get('chkout_shipping');
		## BEGIN ADDRESS VALIDATION	
		my $correction            = '';
		my $correction_disclaimer = '';
		if (defined $ADDRESS_VALIDATION_META->{'force_blurb'}) {
			$correction_disclaimer .= $ADDRESS_VALIDATION_META->{'force_blurb'};
			}
		if (($ADDRESS_VALIDATION_META->{'is_valid'}==0) && (scalar(@{$POSSIBLE_ADDRESSES})>0)) {
			require JSON::XS;
			# JSON::XS::encode_json([{"foo"=>"faa"}]);
			$correction = qq~<script language="JavaScript">
			<!--
			function change_fields(suggestion) {
				var addresses = ~.JSON::XS::encode_json($POSSIBLE_ADDRESSES).qq~;

				for (var i = 0; i < addresses.length; i++) {
					if (addresses[i]['id'] == suggestion) {
						document.checkout['data.ship_city'].value = addresses[i]['city'];			
						document.checkout['data.ship_state'].value = addresses[i]['state'];			
						document.checkout['data.ship_zip'].value = addresses[i]['zip'];			
						}
					}
				}
			//-->
			</script>
			<select class="zselect" name="chkout.ship_address_suggestions" 
				onChange="change_fields(this.options[this.selectedIndex].value)">
			~;
			foreach my $possibility (@{$POSSIBLE_ADDRESSES}) {
				my $selected = (($SITE::v->{'chkout.ship_address_suggestions'} eq $possibility->{'id'})?'selected':'');
				$correction .= "<option value=\"$possibility->{'id'}\">$possibility->{'prompt'}</option>\n";
				}
			$correction .= qq~
			</select>
			<i>This will automatically update the appropriate fields below.</i><br>
			~;
			}
		## END ADDRESS VALIDATION 


	
		my $state          = 'State';
		my $statesize      = '2';
		my $statemax       = '2';
		my $zip            = 'ZIP';
		my $zipsize        = '10';
		my $zipmax         = '10';
		my $choose_country = "United States (we do not accept international orders)";
		my $available_destinations = &ZSHIP::available_destinations($THIS_CART,$webdbref);
		if ((scalar @{$available_destinations})>1) {
			$state          = 'State / Province';
			$statesize      = '20';
			$statemax       = '30';
			$zip            = 'ZIP / Postal Code';
			$zipsize        = '20';
			$zipmax         = '20';
			$choose_country = qq~<select class="zselect" name="data.ship_country">\n~;
			foreach my $shipto (@{$available_destinations}) {
				$choose_country .= 
					sprintf(q~<option value="%s" %s>%s</option>\n~,
						$shipto->{'ISO'},
						(($shipto->{'ISO'} eq $cart2{'ship/countrycode'})?'selected':''),
						$shipto->{'Z'}
						);
				}
			$choose_country .= qq~</select>\n~;
			} ## end if (scalar keys %countries...
	
		$OUTPUT .= qq~
			<table width="100%" cellpadding="2" cellspacing="0" border="0">
				<form method="post" action="$checkout_url" name="checkout">
				<input type="hidden" name="sender" value="SHIPPING_LOCATION">
				<input type="hidden" name="chkout.bill_to_ship" value="0">
		~;
		if ($correction) {
			$OUTPUT .= qq~
				<tr>
					<td width="33%" align="right" valign="top">
						<font class="ztxt">
						Address Correction:
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<font class="ztxt">
						$correction
						</font>
					</td>
				</tr>
			~;
			}
		if ($correction_disclaimer && $correction) {
			$OUTPUT .= qq~
				<tr>
					<td colspan="2" align="center" valign="top">
						<font class="ztxt">
						$correction_disclaimer
						</font>
					</td>
				</tr>
			~;
			}
	
		############## EXISTING SHIP ADDRESS 
		my $C = $THIS_CART->customer();

		if ((defined $C) && (scalar(@{$C->fetch_addresses('SHIP')})>0)) {			
			
			$OUTPUT .= qq~
<tr>
	<td width="33%" align="right" valign="top">
		<font class="ztxt">
		Address On File:
		</font>
	</td>
	<td width="67%" align="left" valign="middle">
		<select class="ztxt" onChange="
	var addr = this.value.toString().split('|');
	if (this.selectedIndex>0) {
		document.checkout['data.ship_firstname'].value = addr[0];
		document.checkout['data.ship_lastname'].value = addr[1];
		document.checkout['data.ship_company'].value = addr[2];
		document.checkout['data.ship_address1'].value = addr[3];
		document.checkout['data.ship_address2'].value = addr[4];
		document.checkout['data.ship_city'].value = addr[5];
		document.checkout['data.ship_state'].value = addr[6];
		document.checkout['data.ship_zip'].value = addr[7];
		if ( document.checkout['data.ship_country'] ) {
			document.checkout['data.ship_country'].value = addr[8];
			}
		document.checkout['data.ship_phone'].value = addr[9];
		}
	" name="addr_on_file">
			<option value="">--</option>
~;
		foreach my $custaddr (@{$C->fetch_addresses('SHIP')}) {
			my $addr = $custaddr->as_hash();

			my $val = '';
			$val .= $addr->{'firstname'}.'|';
			$val .= $addr->{'lastname'}.'|';
			$val .= $addr->{'company'}.'|';
			$val .= $addr->{'address1'}.'|';
			$val .= $addr->{'address2'}.'|';
			$val .= $addr->{'city'}.'|';
			$val .= $addr->{'region'}.'|';
			$val .= $addr->{'postal'}.'|';
			$val .= $addr->{'countrycode'}.'|';
			$val .= $addr->{'phone'}.'|';
			$val .= $addr->{'email'}.'|';
			
			$OUTPUT .= "<option value=\"$val\">$addr->{'ID'}: $addr->{'address1'}; $addr->{'city'}, $addr->{'state'}</option>";
			}
$OUTPUT .= "</select>";
$OUTPUT .= qq~
		</font>
		</td>
</tr>
<tr>
	<td colspan=3><hr></td>
</tr>
~;
			}
		################


		$OUTPUT .= qq~
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						Name ($field_indicators{'data.ship_firstname'}First, MI, $field_indicators{'data.ship_lastname'}Last):
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="20" maxlength="20" name="data.ship_firstname" value="$cart2{'ship/firstname'}">
						<input type="textbox" class="ztextbox" size="1" maxlength="1" name="data.ship_middlename" value="$cart2{'ship/middlename'}">
						<input type="textbox" class="ztextbox" size="20" maxlength="20" name="data.ship_lastname" value="$cart2{'ship/lastname'}">
					</td>
				</tr>
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						Company:
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="45" maxlength="45" name="data.ship_company" value="$cart2{'ship/company'}">
					</td>
				</tr>
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						$field_indicators{'ship_address1'}Address:
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="35" maxlength="35" name="data.ship_address1" value="$cart2{'ship/address1'}">
					</td>
				</tr>
				<tr>
					<td width="33%" class="ztextbox" align="right" valign="middle">
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" size="35" class="ztextbox" maxlength="35" name="data.ship_address2" value="$cart2{'ship/address2'}">
					</td>
				</tr>
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						$field_indicators{'ship_city'}City:
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" size="20" class="ztextbox" maxlength="40" name="data.ship_city" value="$cart2{'ship/city'}">
					</td>
				</tr>
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						$field_indicators{'ship_state'}$state : 
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="$statesize" maxlength="$statemax" name="data.ship_state" value="$cart2{'ship/region'}">
					</td>
				</tr>
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						$field_indicators{'ship_zip'}$zip : 
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="$zipsize" maxlength="$zipmax" name="data.ship_zip" value="$cart2{'ship/postal'}">
					</td>
				</tr>
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						Country :
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<font class="ztxt">
						$choose_country
						</font>
					</td>
				</tr>
				~;

		if ($require_phone>=0) {
			my $phone_optional = ($require_phone==0) ? '(Optional)' : '';
			$OUTPUT .= qq~
				<tr>
					<td width="33%" align="right" valign="middle">
						<font class="ztxt">
						$field_indicators{'data.ship_phone'}Phone:
						</font>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="20" maxlength="20" name="data.ship_phone" value="$cart2{'ship/phone'}">
						<font class="ztxt">
						$phone_optional
						</font>
					</td>
				</tr>
			~;
		}
		if ($correction_disclaimer && !$correction)
		{
			$OUTPUT .= qq~
				<tr>
					<td colspan="2" align="center" valign="top">
						<font class="ztxt">
						$correction_disclaimer
						</font>
					</td>
				</tr>
			~;
		}
		$OUTPUT .= qq~
				<tr>
					<td colspan="2"><img src="$graphics_url/blank.gif" height="10" width="1"></td>
				</tr>
	<tr>
		<td class="chkout_bottom_nav" colspan="2">
			<div style="float:right;">$next_button</div>
			<div style="float:left;">$back_button</div>
			<div style="clear:both;"></div>
		</td>	
	</tr>
				</form>
			</table>
		~;
		} 
	# END SHIPPING_LOCATION
	########################################
	
	########################################
	# BEGIN ORDER_CONFIRMATION
	if ($STAGE->[0] eq 'ORDER_CONFIRMATION') {


		print STDERR Dumper($STAGE);

		$SITE->title( 'Order Confirmation' );

		#open F, ">/dev/shm/cart.before"; use Data::Dumper; print F Dumper($SITE::CART); close F;
		$THIS_CART->shipmethods('flush'=>1);		# this forces the cart to re-update the SHIPPING values
		#open F, ">/dev/shm/cart.after"; use Data::Dumper; print F Dumper($SITE::CART); close F;

#		if ($cart{'chkout.checksum'} eq '') {
#			## okay, so if for some reason we haven't computed a checksum yet, then now would be a good time.
#			##	since the next time this page is run (with SENDER eq 'ORDER_CONFIRMATION') we're going to check
#			## the checksum
#			(undef,$cart{'chkout.checksum'}) = $THIS_CART->checksum($cart{'chkout.checksum'});	
#			}
		##
		## 12/21/08: okay so in reality, if we're going to show data.. we might as well *always* update
		## the checksum based on whatever is about to be displayed (regardless if the checksum is blank or whatever)
		##
		## NOTE: I think the comment out hack above was because we used to use one value to store checksum, 
		##			but now %cache.ship.chksum is it's own value!
 		$cart2{'cart/checkout_digest'} = $THIS_CART->digest();
	
		my $ship_blurb = '';
		### *** NEEDS LOVE ***
		#if (defined($cart2{'ship.%meta'}->{'force_blurb'}) && ($cart{'ship.%meta'}->{'force_blurb'} ne '')) {
		#	$ship_blurb = qq~\n<br>$cart{'ship.%meta'}->{'force_blurb'}\n~;
		#	}
		## $ship_blurb = '<pre>'.&ZOOVY::incode(Dumper(\%cart))."</pre>";
	
		my $ship_options;
	
		if ($cart2{'want/shipping_id'} eq '') { 
			## default $cart{'ship.selected_id'} so we don't need to refresh on INVOICE_DISPLAY if they like the defaults
			if (scalar(@{$THIS_CART->shipmethods()})>0) {
				$cart2{'want/shipping_id'} = $THIS_CART->shipmethods()->[0]->{'id'}; 
				}
			}

		

		if (ref( $THIS_CART->shipmethods() ) ne 'ARRAY') {
			## hmm.. no shipping methods, maybe they pressed the back button.
			}
		elsif ((scalar @{ $THIS_CART->shipmethods() }) > 1) {
			# my $picker = 'radio';
			#if (defined($cart{'ship.%meta'}->{'force_picker'})) { $picker = $cart{'ship.%meta'}->{'force_picker'}; }
			#elsif ($webdbref->{'chkout_shipradio'}) { $picker = 'radio'; }
			#if ($picker eq 'radio') {

			## NOTE: UPS requires a radio button select list
			$ship_options .= qq~<table border="0" cellpadding="0" cellspacing="0" align="center">\n~;
			foreach my $shipmethod (@{ $THIS_CART->shipmethods() }) {
				my $name = $shipmethod->{'name'};
				my $checked = '';
				if ($shipmethod->{'id'} eq $cart2{'want/shipping_id'}) { $checked = ' checked'; }
				my $sprice = &ZTOOLKIT::moneyformat($shipmethod->{'amount'});
				$ship_options .= qq~
					<tr>
						<td valign="top" align="left"><input class="zradio" onClick="this.form.submit();" type="radio" name="ship.selected_id" value="$shipmethod->{'id'}" $checked></td>
						<td valign="top" align="left"><font class="ztxt">$name &nbsp;</font></td>
						<td valign="top" align="right"><font class="ztxt">$sprice</font></td>
					</tr>
				~;
				}
			$ship_options .= qq~</table>\n~;
			#	}
			#else {
			#	$ship_options = qq~I would like my order delivered by:<br>\n~;
			#	$ship_options .= qq~<select onChange="this.form.submit();" class="zselect" name="ship.selected_id">\n~;
			#	foreach my $shipmethod (@{ $THIS_CART->shipmethods() }) {
			#		my $selected = '';
			#		if ($shipmethod->{'id'} eq $cart{'ship.selected_id'}) { $selected = ' selected'; }
			#		my $sprice = &ZTOOLKIT::moneyformat($shipmethod->{'amount'});
			#		$ship_options .= qq~<option value="$shipmethod->{'id'}" $selected>$shipmethod->{'name'}: $sprice</option>\n~;
			#		}
			#	$ship_options .= qq~</select>\n~;
			#	}
			} ## end if has >1 shipping method
		else {
			my $name = 'Actual cost to be determined';
			my $val = 0;
			my $id = 'ACTBD';
			if ((scalar @{$THIS_CART->shipmethods()}) == 1) {
				my ($shipmethod) = @{$THIS_CART->shipmethods()};
				$name = $shipmethod->{'name'};
				$val = $shipmethod->{'amount'};		
				$id = $shipmethod->{'id'};
				# $ship_options .= Dumper($shipmethod);
				}
			$cart2{'want/shipping_id'} = $id;
			my $sprice = &ZTOOLKIT::moneyformat($val);
			$ship_options .= qq~$name: $sprice<br>\n~;
			$ship_options .= qq~<input type="hidden" name="ship.selected_id" value="$id">\n~;
			$ship_options .= qq~<input type="hidden" name="old_shipmethod" value="$id">\n~;
			}
	
		# If there's only one payment method, display a message saying so, otherwise give them a drop-down of payment methods.

		#if ($cart{'is_wholesale'}) {
		#	my ($C) = $cart{'customer'};
	   #   my $wsinfo = $C->fetch_attrib('WS');
	   #   if ($wsinfo->{'ALLOW_PO'}) {
		#		$payby{'PO'} = 'Purchase Order (Established Terms)'; 
		#		push @pay_methods, 'PO';
		#		}
	
		#	if ($wsinfo->{'RESALE'}) {
		#		$cart{'chkout.resale_permit'} = $wsinfo->{'RESALE_PERMIT'};
		#		}
		#	}
		
	
		if ($cart2{'will/payby'} eq 'PAYPALEC') {
			if ($cart2{'cart/paypalec_result'} eq '') {
				## Oooh shit, something bad happened.
				delete $cart2{'must/payby'};
				delete $cart2{'want/payby'};
				}
			else {
				## paypal express payment (they've put in an auth, so we don't let them select payment again)
				$paymentsref = [ { 'id'=>'PAYPALEC', pretty=>'Paypal EC' } ];
				$back_button = '';
				}
			}

		my $pay_options;
		if (
			($cart2{'will/payby'} eq 'PAYPALEC') && 
			($cart2{'cart/paypalec_result'} ne '')
			) {
			## the person is paying via Paypal EC, and has a token (meaning they've auth'd paypal)
			$pay_options .= qq~Payment by: Paypal Express Checkout<br>\n~;
			if ($ZOOVY::cgiv->{'addrwarn'}) {
				$pay_options .= "<div class=\"zwarn\">Paypal has altered the shipping and/or billing address, please verify.</div>\n";
				}
			$pay_options .= qq~<div><a href=\"?sender=PAYPALEC.RESET\">[Change Payment Method]</a></div>~;
			}
		elsif (scalar(@{$paymentsref}) == 0) {
			$pay_options = qq~No payment methods available. Please contact store owner.~;
			}
		elsif ((scalar(@{$paymentsref}) == 1) && ($cart2{'will/payby'} eq 'ZERO')) {
			$cart2{'will/payby'} = $paymentsref->[0]->{'id'};
			$pay_options = qq~<input type="hidden" name="chkout.payby" value="$cart2{'will/payby'}">\n~;
			$pay_options .= qq~No payment is required<br>\n~;
			}
		elsif ((scalar(@{$paymentsref}) == 1) && ($cart2{'will/payby'} eq 'PAYPALEC')) {
			$cart2{'will/payby'} = $paymentsref->[0]->{'id'};
			$pay_options = qq~<input type="hidden" name="chkout.payby" value="$cart2{'will/payby'}">\n~;
			my $paypal_button = &TOXML::RENDER::RENDER_SITEBUTTON({'button' => 'paypal'},undef,$SITE);
			$pay_options .= qq~We prefer Paypal (please click button below):<br>$paypal_button<br>~;
			}
		else {
			## payment radio.
			## default payby
			my $DEFAULT = $cart2{'will/payby'};					# if we've already selected a payment method - use that
			#if ((defined $payby{'PAYPAL'}) && ($DEFAULT eq '')) { $DEFAULT = 'PAYPAL'; }	# if we don't have a default use PAYPAL
			if ($DEFAULT eq '') {
				$DEFAULT = $paymentsref->[0]->{'id'};	# choose the first payment method!
				}

			my $HAS_PAYPAL_EC = 0;

			$pay_options = qq~<table cellspacing=0 border=0 cellpadding=0>~;

			foreach my $payref (@{$paymentsref}) {
				if ($payref->{'id'} eq 'PAYPALEC') {
					$HAS_PAYPAL_EC++; 
					}
				elsif (scalar(@{$paymentsref})==1) {
					my $checked = ($payref->{'id'} eq $DEFAULT)?'checked':'';
					$pay_options .= qq~
					<tr>
						<td valign='top' colspan=2>
						<input type="hidden" name="chkout.payby" value="$payref->{'id'}">
						<font class="ztxt">$payref->{'pretty'}</font>
						</td>
					</tr>
					\n~;
					}
				else {
					my $checked = ($payref->{'id'} eq $DEFAULT)?'checked':'';
					$pay_options .= qq~
					<tr>
						<td valign='top'><font class="ztxt"><input class="zradio" $checked type="radio" name="chkout.payby" value="$payref->{'id'}"></font></td>
						<td valign='top'><font class="ztxt">$payref->{'pretty'}</font></td>
					</tr>
					\n~;
					}
				}

			if ($HAS_PAYPAL_EC) {	
				use Data::Dumper;
				my $paypal_button = &TOXML::RENDER::RENDER_SITEBUTTON({'button' => 'paypal'},undef,$SITE);
				$pay_options .= qq~
				<tr><td colspan=2 height="5"><center><span class="ztxt"></span></center></td></tr>
				<tr><td valign="top"><font class="ztxt">or</font></td><td valign=top>$paypal_button</td></tr>
				~;
				}

			if ($THIS_CART->{'+sandbox'}==0) {
				## not on sandbox, no amazon payment method.
				}
			elsif ($webdbref->{'amzpay_env'}>0) {
				require ZPAY::AMZPAY;
				$pay_options .= "<tr><td valign=\"middle\">".&ZPAY::AMZPAY::button_html($THIS_CART,$SITE,shipping=>1)."</td></tr>";
				}
			$pay_options .= qq~</table>\n~;
			}
	
		my $edit_shipping = 'Edit Shipping';
		my $edit_billing  = 'Edit Billing';
		if ($cart2{'cart/paypalec_result'} ne '') {
			$edit_shipping = '';
			$edit_billing = '';
			}
		elsif ($forcebilltoship) {
			$edit_shipping = 'Edit';
			$edit_billing  = 'Edit';
			}

	
		my $billaddress = &PAGE::checkout::html_address($THIS_CART, 'bill');
		if ($cart2{'bill/phone'} ne '') { $billaddress .= "$cart2{'bill/phone'}<br>\n"; }
		if ($cart2{'bill/email'} ne $cart2{'bill/phone'}) { $billaddress .= "$cart2{'bill/email'}<br>\n"; }
	
		my $shipaddress = &PAGE::checkout::html_address($THIS_CART, 'ship');
		if ($cart2{'bill/phone'} ne '') { $shipaddress .= "$cart2{'ship/phone'}<br>\n"; }
		## We don't use shipping_email -BH 1/9/04
		## if ($cart{'ship.selected_price_email'} ne $cart2{'ship/phone'}) { $shipaddress .= "$cart{'ship.selected_price_email'}<br>\n"; }
	
		#if ($cart_changed & 512) {
		#	$OUTPUT .= $SITE->msgs()->get('chkout_prohibited');
		#	}
		#elsif ($cart_changed & 2) {
		#	$OUTPUT .= qq~<p align="center"><b>\n~;
		#	$OUTPUT .= qq~This is your revised total, based on your new choice of payment type.\n~;
		#	$OUTPUT .= qq~</b></p>\n~;
		#	}
		#elsif ($cart_changed & 4) {
		#	$OUTPUT .= qq~<p align="center"><b>\n~;
		#	$OUTPUT .= qq~This is your revised total, based on your new choice of shipping method.\n~;
		#	$OUTPUT .= qq~</b></p>\n~;
		#	}
		#elsif ($cart_changed & 16) {
		#	$OUTPUT .= qq~<p align="center"><b>\n~;
		#	$OUTPUT .= qq~This is your revised total, based on your new choice of bonding method.\n~;
		#	$OUTPUT .= qq~</b></p>\n~;
		#	}
		if ($cart_changed) {
			my $interjection = '';
			#my $payby = $cart2{'will/payby'};
			#unless (($payby eq 'COD') || ($payby eq 'CHKOD')) { $interjection = 'a payment type which is not'; }
			#$OUTPUT .= qq~<p align="left"><b>\n~;
			#$OUTPUT .= qq~You have selected $interjection payment on delivery.  Since payment on delivery\n~;
			#$OUTPUT .= qq~shipping has different prices you must re-select your shipping method now.\n~;
			#$OUTPUT .= qq~</b></p>\n~;
			$OUTPUT .= "<p align=\"left\">[$cart_changed] Cart items, shipping, or grand total have changed based on your selection, please take a moment to confirm the order before proceeding.</p>";
			}
	
		$OUTPUT .= $SITE->msgs()->get('chkout_confirm');
		$OUTPUT .= qq~
			<form name="thisFrm" method="POST" action="$checkout_url">
			<table border="0" cellpadding="2" cellspacing="1" width="100%">
				<input type="hidden" name="sender" value="ORDER_CONFIRMATION">
				<tr>
					<td colspan="2"><img src="$graphics_url/blank.gif" height="10" width="1"></td>
				</tr>
				<tr>
					<td align="left" width="50%"  class="ztable_head" >Billing Information</td>
					<td align="left" width="50%"  class="ztable_head" >Shipping Information</td>
				</tr>
				<tr>
					<td valign="top">
						<font class="ztxt">
						$billaddress
						</font>
					</td>
					<td valign="top">
						<font class="ztxt">
						$shipaddress
						</font>
					</td>
				</tr>
				<tr>
					<td>
						<font class="ztxt">
						~;
		if ($edit_billing ne '') {
			$OUTPUT .= qq~<input class="zform_button zverb" type="submit" name="verb" value="$edit_billing">~;
			}
		$OUTPUT .= qq~
						</font>
					</td>
					<td>
						<font class="ztxt">
						~;
		if ($edit_shipping ne '') {
			$OUTPUT .= qq~<input class="zform_button zverb" type="submit" name="verb" value="$edit_shipping">~;
			}
		$OUTPUT .= qq~
						</font>
					</td>
				</tr>
			</table>


			<img src="$graphics_url/blank.gif" width="1" height="8"><br>
			~;

		#require CART::VIEW;	
		#$OUTPUT .= &CART::VIEW::as_html(
		#	$SITE::CART, 'CHECKOUT', $webdbref,undef,$SITE,
		#	);
		my $iniref = undef;
		$OUTPUT .= &CART2::VIEW::as_html($THIS_CART, 'CHECKOUT', $iniref,$SITE);

		## NOTE: I don't think this actually gets saved anyplace.
		# $cart2{'chkout.old_shipmethod'} = $cart{'ship.selected_id'};
			
		$OUTPUT .= $SITE->msgs()->get('chkout_confirm_middle');
	
		if ($getnotes) {
			$OUTPUT .= $SITE->msgs()->get('chkout_confirm_notes');
			}


#		if ($SITE->username() eq 'secondact') {
#			my $warning = '';
#			if ($SENDER eq 'ORDER_CONFIRMATION') {
#				$warning = "<div class=\"zwarn\">You must agree to the terms of service!</div><br>";
#				}
#			$OUTPUT .= qq~
#				<tr>
#					<td colspan="2" align="center" class="ztable_head">Terms of Service</td>
#				</tr>
#				<tr>
#					<td align="center" colspan="2">
#						<font class="ztxt">
#						$warning
#						<input type="checkbox" name="agree_tos"> I have read and agree to the terms and conditions.<br>
#<a target="_returns" href="http://www.secondact.com/returns.cgi">http://www.secondact.com/returns.cgi</a>
#						</font>
#					</td>
#				</tr>
#			~;
#			}
#
## secondact code	
#		if (scalar($webdbref->{'@CHECKFIELD'})>0) {
#			foreach my $fieldref (@{$webdbref->{'@CHECKFIELD'}}) {
#				$OUTPUT .= qq~<tr><td>~.Dumper($fieldref).qq~</td></tr>~;
#				}
#			}
	
		my $ins_blurb = '<!-- ins is not offered -->';
		if (($cart2{'is/ins_optional'}) && ($cart2{'sum/ins_quote'}>0)) {
			$ins_blurb = $SITE->msgs()->get('chkout_confirm_insurance',{
				'%INS_CHECKED%'=>(($cart2{'want/ins_purchased'})?'checked':''), 
				'%INS_QUOTE%'=>&ZTOOLKIT::moneyformat(sprintf("%.2f",$cart2{'sum/ins_quote'})),
				});
			}


	
		## WHOLESALE SUBSCRIBERS:
		##		Let people who provide a company address, include an optional PO Number.
		if (($cart2{'bill/company'} ne '') && ($gref->{'cached_flags'} =~ /,WS,/)) {
			$pay_options .= qq~
			Reference/PO Number: 
			<input type="textbox" class="ztextbox" name="chkout.po_number" size="20" maxlength="20" value="$payment{'PO'}">
			(Optional)<br>	
			~;
			}

		if (int($webdbref->{'pay_giftcard'}) == 0) {
			## GIFTCARDS are disabled!
			}
		else {
			$pay_options .= qq~<div class="zgiftcards">~;
			my $giftcard_count = $THIS_CART->has_giftcards();
			if ($giftcard_count>0) {
				$pay_options .= sprintf("%d giftcards in cart:<br>",$giftcard_count);
				foreach my $payq (@{$THIS_CART->paymentQshow('tender'=>'GIFTCARD')}) {
					$pay_options .= sprintf("<li> %s \$%.2f<br>",&GIFTCARD::obfuscateCode($payq->{'GC'}),$payq->{'T$'});
					}
				}
			$pay_options .= qq~<br>Gift Certificate: <input type="textbox" size="20" maxlength="20" name="chkout.giftcard_number">~;
			$pay_options .= qq~</div>~;
			}


		my $bnd_blurb = '';	
		$OUTPUT .= qq~
		<table width=100% border=0>
			<tr>
				<td width=49% colspan="1" align="center" class="ztable_head">Shipping Method</td>
				<td width=2% colspan="1" align="center">&nbsp;</td>
				<td width=49% colspan="1" align="center" class="ztable_head">Payment Method</td>
			</tr>
			<tr>
				<td align="center" valign="top" colspan="1">
					<font class="ztxt">
					$ship_options
					$ship_blurb
					$ins_blurb
					$bnd_blurb
					</font>
				</td>
				<td></td>
				<td align="center" valign="top" colspan="1">
					<font class="ztxt">
					$pay_options						
					~.$SITE->msgs()->get('chkout_confirm_end').qq~
					</font>
				</td>
			</tr>
		</table>
		~;


		if ($THIS_CART->cid()>0) {
			## they are already have an account so we don't need to prompt them.
			$cart2{'must/create_customer'} = 0;
			}
		elsif ($CUSTOMER_MANAGEMENT eq 'STANDARD') {
			$cart2{'want/create_customer'} = 1;
			}
		elsif (($CUSTOMER_MANAGEMENT eq 'NICE') || ($CUSTOMER_MANAGEMENT eq 'STRICT')) {
			## we already prompted the user earlier, so we'll just respect whatever they told us.
			#$cart{'chkout.create_customer'} = 1;
			#if (not defined $SITE::v->{'chkout.create_customer'}) {
			#	$cart{'chkout.create_customer'} = 0;
			#	}
			}
		elsif ($CUSTOMER_MANAGEMENT eq 'PASSIVE') {
			$cart2{'want/create_customer'} = 1;
			}
	
		if ($CUSTOMER_MANAGEMENT eq 'PASSIVE') {
			## passive customer account creation doesn't prompt user to enter password, etc.
			}
		elsif ($cart2{'customer/login'} ne '') {
			## they are already logged in.
			}
		elsif ($cart2{'want/create_customer'}) {
			## 
			## create customer account.
			##
			$OUTPUT .= qq~
			<table width=100% border=0>
				<tr>
					<td width=100% colspan="3" align="center" class="ztable_head">Customer Account</td>
				</tr>
				~;
			$OUTPUT .= "<tr><td colspan=\"3\">".$SITE->msgs()->get('chkout_new_customer')."</td></tr>";


			if ($CUSTOMER_MANAGEMENT eq 'NICE') {
				my $create_account = $SITE->msgs()->get('chkout_create_account');
				my $checked = ($cart2{'want/create_customer'})?'checked':'';
				my $onoff = ($cart2{'want/create_customer'})?1:0;

				$OUTPUT .= qq~
					<tr>
						<td width="33%" align="right" valign="top">
							<input type="hidden" name="chkout.create_customer" value="$onoff"> 
							<input class="zcheckbox" type="checkbox" name="chkout.create_customer_cb" onChange="document.forms['thisFrm']['chkout.create_customer'].value = (this.checked?1:0);" value="ignore" $checked> 
						</td>
						<td width="67%" align="left" valign="middle">
							<font class="ztxt">
							Create customer account<br>
							$create_account
							</font>
						</td>
					</tr>
					~;
				}
	
			$OUTPUT .= qq~
				<tr>
					<td width="33%" nowrap align="right" valign="top">
						<div class="ztxt">Email Address/Login:</div>
					</td>
					<td colspan=2 width="67%" align="left" valign="top">
						<div class="zttxt">$cart2{'bill/email'}</div>
						</font>
					</td>
				</tr>
				<tr>
					<td width="33%" nowrap align="right" valign="middle">
						<div class="ztxt">
						$field_indicators{'chkout.new_password'}Pick a password:
						</div>
					</td>
					<td colspan=2 width="67%" align="left" valign="middle">
						<input class="ztextbox" type="password" size="20" maxlength="20" name="chkout.new_password" value="$cart2{'want/new_password'}">
					</td>
				</tr>
				<tr>
					<td width="33%" nowrap align="right" valign="middle">
						<div class="ztxt">
						$field_indicators{'chkout.new_password2'}Retype your password:
						</div>
					</td>
					<td width="67%" align="left" valign="middle">
						<input class="ztextbox" type="password" size="20" maxlength="20" name="chkout.new_password2" value="$cart2{'want/new_password2'}">
					</td>
				</tr>
				<tr>
					<td width="33%" nowrap align="right" valign="middle">
						<div class="ztxt">Recovery Question:</div>
					</td>
					<td width="67%" align="left" valign="middle">
				~;
			my %recovery_hints = &CUSTOMER::fetch_password_hints();
			$OUTPUT .= qq~<select class="zselect" name="chkout.recovery_hint">\n~;
			foreach my $hint (sort keys %recovery_hints) {
				next if ($hint == 1); ## don't ask mothers maiden name anymore!
				my $selected = '';
				if ($cart2{'want/recovery_hint'} eq $hint) { $selected = ' selected'; }
				$OUTPUT .= qq~<option value="$hint"$selected>$recovery_hints{$hint}</option>\n~;
				}
			$OUTPUT .= qq~</select>\n~;
			$OUTPUT .= qq~
					</td>
				</tr>
				<tr>
					<td width="33%" nowrap align="right" valign="middle">
						<div class="ztxt">$field_indicators{'chkout.recovery_answer'} Recovery Answer:</div>
					</td>
					<td width="67%" align="left" valign="middle">
						<input type="textbox" class="ztextbox" size="20" maxlength="20" name="chkout.recovery_answer" value="$cart2{'want/recovery_answer'}">
					</td>
				</tr>
				~;
			$OUTPUT .= "</table>";
			}

		if ($cart2{'want/create_customer'}) {
			##
			## Newsletters
			##

			$OUTPUT .= qq~
			<table width=100% border=0>
				<tr>
					<td width=100% colspan="3" align="center" class="ztable_head">Newsletter Subscriptions</td>
				</tr>
				<tr>
					<td>
				~;

			## ADDITION of SUBSCRIPTION LISTS
			require CUSTOMER::NEWSLETTER;
			## fetch TARGETED (mode=2) lists
			my (@lists) = CUSTOMER::NEWSLETTER::fetch_newsletter_detail($SITE->username(),$SITE->prt());
			if ((scalar @lists)==0) {
				@lists = (  { NAME=>'General', MODE=>1, ID=>1 } );
				}

			foreach my $list (@lists) {
				$list->{'NAME'} =~ s/\n//;
				next if ($list->{'NAME'} eq '');
				next if ($list->{'MODE'} <= 0);		# skip exclusive newsletters.
				
				my $value = (1<<($list->{'ID'}-1));
				my $var = "chkout.email_update".$list->{'ID'};

				# default ON for the first DEFAULT newsletter
				if (($list->{'MODE'}==1) && (not defined $cart2{'want/email_update'})) { 
					#$cart2{$var} = $value;
					$cart2{'want/email_update'} = $value; 
					} 
				my $checked = (($cart2{'want/email_update'} & $value)>0)?' checked':'';
				
				$OUTPUT .= qq~
				<div style='float:left; margin:5px; width: 200px'>
				<div class="ztxt">
				<input type="checkbox" class="zcheckbox" name="$var" value="$value" $checked>
					$list->{'NAME'}~.($list->{'EXEC_SUMMARY'}?": <span size=-1>$list->{'EXEC_SUMMARY'}</span":"").qq~
				</div>
				</div>
				~;
				}

			$OUTPUT .= qq~
				</td>
				</tr>
			</table>
			~;
			}

		## some padding
		$OUTPUT .= qq~
		<table>
		<tr>
			<td colspan="2">
			<img src="$graphics_url/blank.gif" height="10" width="1"></td>
		</tr>
		</table>
		~;


		$OUTPUT .= qq~
			<div style="clear:both;"></div>
			<div style="float:right;">$next_button</div>
			<div style="float:left;">$back_button</div>
			<div style="clear:both;"></div>
		</form>
		~;
		} 
	# END ORDER_CONFIRMATION
	########################################
	
	if ($STAGE->[0] eq 'PAYMENT_INFORMATION') { 
		$SITE->title( 'Payment Information: '.$cart2{'will/payby'} ); 
		}

	########################################
	# BEGIN PAYMENT_INFORMATION (po)
	if (($STAGE->[0] eq 'PAYMENT_INFORMATION') && ($cart2{'will/payby'} eq 'PO')) {
		my $input_po = $SITE->msgs()->get('input_po');
		$OUTPUT .= qq~
			<table border="0" cellpadding="2" cellspacing="1" width="100%">
				<form method="post" action="$checkout_url">
				<input type="hidden" name="sender" value="PAYMENT_INFORMATION">
				<tr>
					<td>
						$input_po
						<div align="center">
						<table>
							<tr>
								<td align="right">
									<font class="ztxt">
									$field_indicators{'chkout.po_number'}Purchase Order Number:
									</font>
								</td>
								<td>
									<input type="textbox" class="ztextbox" name="chkout.po_number" size="20" maxlength="20" value="$payment{'PO'}">
								</td>
							</tr>
						</table>
						</div>
					</td>
				</tr>
			</table>
			<table border="0" cellpadding="2" cellspacing="1" width="100%">
	<tr>
		<td class="chkout_bottom_nav" colspan="2">
			<div style="float:right;">$next_button</div>
			<div style="float:left;">$back_button</div>
			<div style="clear:both;"></div>
		</td>	
	</tr>
			</table>
</form>
		~;
		} 

	if (($STAGE->[0] eq 'PAYMENT_INFORMATION') && ($cart2{'will/payby'} eq 'GIFTCARD')) {
		my $input_giftcard = $SITE->msgs()->get('input_giftcard');
		$OUTPUT .= qq~
			<table border="0" cellpadding="2" cellspacing="1" width="100%">
				<form method="post" action="$checkout_url">
				<input type="hidden" name="sender" value="PAYMENT_INFORMATION">
				<tr>
					<td>
						$input_giftcard
						<div align="center">
						<table>
							<tr>
								<td align="right">
									<font class="ztxt">
									$field_indicators{'giftcard_number'}Giftcard Number:
									</font>
								</td>
								<td>
									<input type="textbox" class="ztextbox" name="giftcard_number" size="20" maxlength="20" value="$cart2{'want/giftcard_number'}">
								</td>
							</tr>
						</table>
						</div>
					</td>
				</tr>
			</table>
			<table border="0" cellpadding="2" cellspacing="1" width="100%">
	<tr>
		<td class="chkout_bottom_nav" colspan="2">
			<div style="float:right;">$next_button</div>
			<div style="float:left;">$back_button</div>
			<div style="clear:both;"></div>
		</td>	
	</tr>
			</table>
</form>
		~;
		} 
	# END PAYMENT_INFORMATION (po)
	########################################
	
	########################################
	# BEGIN PAYMENT_INFORMATION (echeck)
	if (($STAGE->[0] eq 'PAYMENT_INFORMATION') && ($cart2{'will/payby'} eq 'ECHECK')) {
	
		my $input_echeck = $SITE->msgs()->get('input_echeck');
		if ($cart2{'payment/en'} eq '') {
			if ($cart2{'bill/middlename'}) {
				$cart2{'payment/en'} = "$cart2{'bill/firstname'} $cart2{'bill/middlename'} $cart2{'bill/lastname'}";
				}
			else	{
				$cart2{'payment/en'} = "$cart2{'bill/firstname'} $cart2{'bill/lastname'}";
				}
			}
		$OUTPUT .= qq~
			<table border="0" cellpadding="2" cellspacing="1" width="100%">
				<form method="post" action="$checkout_url">
				<input type="hidden" name="sender" value="PAYMENT_INFORMATION">
				<tr>
					<td>
						$input_echeck
						<div align="center">
						<table border="0" cellpadding="2" cellspacing="2">
			~;
		if (defined($webdbref->{'echeck_request_acct_name'}) && $webdbref->{'echeck_request_acct_name'}) {
			$OUTPUT .= qq~
							<tr>
								<td align="right">
									<font class="ztxt">
									$field_indicators{'payment.en'}Name on Account:
									</font>
								</td>
								<td>
									<input type="textbox" class="ztextbox" name="payment.en" size="30" maxlength="50" value="$cart2{'payment/en'}">
								</td>
							</tr>
			~;
			}
		$OUTPUT .= qq~
							<tr>
								<td align="right">
									<font class="ztxt">
									$field_indicators{'payment.eb'}Bank Name:
									</font>
								</td>
								<td>
									<input type="textbox" class="ztextbox" name="payment.eb" size="30" maxlength="50" value="$cart2{'payment/eb'}">
								</td>
							</tr>
		~;
		if ((defined $webdbref->{'echeck_request_bank_state'}) && $webdbref->{'echeck_request_bank_state'}) {
			$OUTPUT .= qq~
							<tr>
								<td align="right">
									<font class="ztxt">
									$field_indicators{'payment.es'}Bank State:
									</font>
								</td>
								<td>
	 								<input type="textbox" class="ztextbox" name="payment.es" size="2" maxlength="2" value="$cart2{'payment/es'}">
								</td>
							</tr>
			~;
			}
		$OUTPUT .= qq~
							<tr>
								<td align="right">
									<font class="ztxt">
									$field_indicators{'echeck_aba_number'}ABA / Routing Number:
									</font>
								</td>
								<td bgcolor="#FFFFFF">
									<img src="$graphics_url/mirc1.gif" border="0" width="14" height="14"><input type="textbox" class="ztextbox" name="payment.er" size="9" maxlength="9" value="$cart2{'payment/er'}"><img src="$graphics_url/mirc1.gif" border="0" width="14" height="14">
								</td>
							</tr>
							<tr>
								<td align="right">
									<font class="ztxt">
									$field_indicators{'payment.ea'}Account Number:
									</font>
								</td>
								<td bgcolor="#FFFFFF">
									<input type="textbox" class="ztextbox" name="payment.ea" size="20" maxlength="20" value="$cart2{'payment/ea'}"><img src="$graphics_url/mirc2.gif" border="0" width="14" height="14"><br>
								</td>
							</tr>
		~;
		if (defined($webdbref->{'echeck_request_check_number'}) && $webdbref->{'echeck_request_check_number'}) {
			$OUTPUT .= qq~
							<tr>
								<td align="right">
									<font class="ztxt">
									$field_indicators{'payment.ei'}Check Number:
									</font>
								</td>
								<td bgcolor="#FFFFFF">
									<input type="textbox" class="ztextbox" name="payment.ei" size="8" maxlength="8" value="$cart2{'payment/ei'}"><br>
								</td>
							</tr>
				~;
			}

		#if ((defined $webdbref->{'echeck_request_business_account'}) && $webdbref->{'echeck_request_business_account'}) {
		#	## Default the business account setting depending on whether they have a billing company name or not
		#	if ((not defined $cart2{'payment/business_account'}) || ($cart2{'payment/business_account'} eq ''))	{
		#		$cart2{'payment/business_account'} = $cart2{'bill/company'} ? 1 : 0;
		#		}
		#	my $options = '<option value="0" selected>Personal</option><option value="1">Business</option>';
		#	if ($cart2{'payment/business_account'}) {
		#		$options = '<option value="0">Personal</option><option value="1" selected>Business</option>';
		#		}
		#	$OUTPUT .= qq~
		#					<tr>
		#						<td align="right">
		#							<font class="ztxt">
		#							$field_indicators{'business_account'}Account Type:
		#							</font>
		#						</td>
		#						<td>
		#							<select class="zselect"  name="payment.business_account">$options</select>
		#						</td>
		#					</tr>
		#	~;
		#	} ## end if ((defined $webdbref->{'echeck_request_business_account'...
		if ((defined $webdbref->{'echeck_notice'}) && $webdbref->{'echeck_notice'}) {
			$OUTPUT .= qq~
							<tr>
								<td align="left" colspan="2">
									<font class="ztxt">
									$webdbref->{'echeck_notice'}
									</font>
								</td>
							</tr>
			~;
			}
		$OUTPUT .= qq~
						</table>
						</div>
					</td>
				</tr>
			</table>
			<table border="0" cellpadding="2" cellspacing="1" width="100%">
	<tr>
		<td class="chkout_bottom_nav" colspan="2">
			<div style="float:right;">$next_button</div>
			<div style="float:left;">$back_button</div>
			<div style="clear:both;"></div>
		</td>	
	</tr>
			</table>
</form>
		~;
		} 
	# END PAYMENT_INFORMATION (echeck)
	########################################
	
	########################################
	# BEGIN PAYMENT_INFORMATION (credit)
	if (($STAGE->[0] eq 'PAYMENT_INFORMATION') && ($cart2{'will/payby'} eq 'CREDIT')) {
	
		my $select_months = '';
		my $count = 1;
		foreach my $month (qw(January February March April May June July August September October November December)) {
			my $selected = '';
			my $value = ($count < 10) ? "0$count" : $count;
			if ($value eq $payment{'MM'}) { $selected = ' selected'; }
			$select_months .= qq~<option value="$value"$selected>$month ($count)</option>~;
			$count++;
			}
	
		my $select_years = '';
		foreach my $year (qw(13 14 15 16 17 18 19 20 21 22)) {
			my $selected = '';
			if ($year eq $payment{'YY'}) { $selected = ' selected'; }
			$select_years .= qq~<option value="$year"$selected>20$year</option>~;
			}
	
		my $payment_images = '';
		my @cc_types = &ZPAY::cc_merchant_types($SITE->username(), $webdbref);
		foreach my $type (@cc_types) {
			my $lc_type = lc($type);
			$payment_images .= qq~<td align=center><img src="$graphics_url/cc_$lc_type.gif" alt="$ZPAY::cc_names{$type}" width="59" height="38"></td>\n~;
			}
		$payment_images = "<table><tr>$payment_images</tr></table>";
	
	
		my $input_credit = $SITE->msgs()->get('input_credit');		
		$OUTPUT .= qq~
			<table border="0" cellpadding="2" cellspacing="1" width="100%">
				<form method="post" action="$checkout_url">
				<input type="hidden" name="sender" value="PAYMENT_INFORMATION">
				<tr>
					<td>
						<br>
						<div align="center">
						<table width="480">
							<tr>
								<td colspan="2" align="center">
								$payment_images<br><br>
								</td>
							</tr>
							<tr>
								<td colspan="2">
									<div class="ztxt">$input_credit</div>
									<br>
								</td>
							</tr>
							<tr>
								<td align="right" valign="top" width="50%">
									<font class="ztxt">
									$field_indicators{'payment.CC'}Credit Card Number:<br>
									</font>
								</td>
								<td valign="top" width="50%">
									<input type="textbox" class="ztextbox" name="payment.cc" size="20" maxlength="20" value="$payment{'CC'}">
								</td>
							</tr>
							<tr>
								<td align="right">
									<font class="ztxt">
									$field_indicators{'payment.yy'}Expiration: 
									</font>
								</td>
								<td>
									<select class="zselect" onChange="window.focus();" name="payment.mm">$select_months</select>
									<select class="zselect" onChange="window.focus();" name="payment.yy">$select_years</select>
								</td>
							</tr>
			~;
		## fuck it, i think cvv #'s should be on all cards by now.
		$webdbref->{'cc_cvvcid'} = 2;
		if ((defined $webdbref->{'cc_cvvcid'}) && $webdbref->{'cc_cvvcid'}) {
			my $word;
			if ($webdbref->{'cc_cvvcid'} == 1) { $word = 'can'; }
			else { $word = 'must'; }
	
			my %types = map { $_ => 1, } @cc_types;
	
			my $amex_desc = '';
			my $amex_image = '';
			if (defined($types{'AMEX'})) {
				$amex_image .= qq~<td><img src="$graphics_url/blank.gif" width="4" height="150" border="0"></td><td><img src="$graphics_url/sec_code_amex.gif" width="238" height="150" border="0"></td>~;
				$amex_desc .= 'For American Express the security code is the 4-digit number ';
				$amex_desc .= 'found in small print next to your account number on the front, ';
				$amex_desc .= 'usually above it on the right.';
				delete $types{'AMEX'};
				}
	
			my $desc = '';
			my $sec_image = '';
			if (keys %types) {
				if ($amex_desc eq '') {
					$desc .= "The security code is the last section of ";
					$desc .= "numbers in the signature area on the back of the card.";
					}
				else {
					my $cardnames = '';
					foreach ('VISA', 'MC', 'NOVUS', keys %types) {
						next unless defined ($types{$_});
						$cardnames .= $ZPAY::cc_names{$_} . ', ';
						delete $types{$_};
						}
					$cardnames =~ s/\, $//; # Remove last comma
					$cardnames =~ s/^(.*)\, (.*?)$/$1 and $2/; # Change new last comma to the word "and"
					$desc .= "For $cardnames the security code is the last section of ";
					$desc .= "numbers in the signature area on the back of the card.";
					}
				$sec_image = qq~<td><img src="$graphics_url/sec_code.gif" width="238" height="150" border="0"></td>~;
				}
	
			$OUTPUT .= qq~
							<tr>
								<td colspan="2">
									<div align="center">
									<font class="ztxt">
									$field_indicators{'payment.cv'}Card Security Code:
									</font>
									<input type="textbox" class="ztextbox" name="payment.cv" size="4" maxlength="4" value="$payment{'CV'}"><br>
									</div>
									<div align="center">
									<br>
									<table><tr>$sec_image$amex_image</tr></table><br>
									</div>
									<p>For higher security and more efficient processing of your payment, you $word
									provide a card security code to make this purchase.  $desc  $amex_desc
									</p>
								</td>
							</tr>
			~;		
			} ## end if ((defined $webdbref->{'cc_cvvcid'...
		$OUTPUT .= qq~
						</table>
						</div>
					</td>
				</tr>
			</table>
	
	<div style="float:right;">$next_button</div>
	<div style="float:left;">$back_button</div>
	<div style="clear:both;"></div>
</form>
		~;
		} 
	# END PAYMENT_INFORMATION (credit)
	########################################
	
	
	########################################
	# BEGIN INVOICE_DISPLAY


	if ($STAGE->[0] ne 'INVOICE_DISPLAY') {
		## NOT INVOICE_DISPLAY
		}
	elsif (not $THIS_CART->is_order()) {
		$OUTPUT .= qq~
<br><div class="zbody">There was a serious internal error when we attempted to create your order. Please try again.
Diagnostic Information:
</div>
<ul>
<li> CART#: ~.$THIS_CART->cartid().qq~<br>
~;
		foreach my $msg (@{$LM->msgs()}) {
			my ($ref) = LISTING::MSGS::msg_to_disposition($msg);
			$OUTPUT .= qq~<li> $ref->{'_'}: $ref->{'+'}</li>~;
			}
		$OUTPUT .= qq~</ul></div>~;
		}
#	elsif ($THIS_CART->is_order()) {
#We apologize, however we seem to have experienced an error during processing this order.
#The status cannot not be displayed for security reasons, however the order $OID appears to have been 
#created successfully. You should have received an email confirmation of your order.
#</div>
#<div class="zbody">
#The most common cause of this error is submitting the same checkout request twice. The most common reasons this happens are:
#<ul>
#<li> Pressing the back/reload button while the order was being created.
#<li> Double clicking the "next" button on the previous page.
#<li> This error can be caused by a browser plugin/handler such as a virus, mal-ware which causes the page to sent more than once.
#<li> A double-request can also be sent by some invasive virus scanners, or firewalls which perform https-proxy services.
#<li> It is also possible third-party javascript (roi trackers) on the invoice page could have triggered a refresh to avoid caching, thus submitting a duplicate transaction.
#<li> Ultimately it is extremely difficult/impossible to determine exactly what caused this to happen (unless you know).
#</ul>
#</div>
#<div class="zbody zcaution">
#If you do not know what happened we highly recommend you scan your computer for viruses and/or spyware using a 
#reputable virus scanner such as "AVG" which can be downloaded for free <a href="http://free.avg.com/us-en/homepage">click here</a>.</i><br>
#</div>
#<br>
#<br>
#<h3>PLEASE NOTE:</h3>
#<div class="zbody">
#You do not need to re-create your order. 
#You should have received an email with the details of the order, please leave this browser window open and go check.
#If you did not receive an email confirmation - then please forward the ERROR, ORDER#, and CART reference above
#to our customer support department.
#</div>
#~;
#		open F, ">>/tmp/checkout-error.log";
#		print F time()."\t$SITE->username()\t$OID\t$errmsg\t$CARTID\n";
#		close F;
#		}
	elsif ($STAGE->[0] eq 'INVOICE_DISPLAY') {
		## e.g. invoice_check_success

#		if ((not defined $o) || (ref($o) ne 'ORDER')) {
#			my ($TICKETID) = &ZOOVY::confess($SITE->username(),"ORDER OBJECT INVALID\n".Dumper($o),justkidding=>1);
#			$OUTPUT .= "*** ORDER OBJECT INVALID - SUPPORT TICKET# $TICKETID ***";
#			$o = undef;			
#			}
#		use Data::Dumper;
#		print STDERR Dumper($o);

		$SITE->title( "Invoice for Order Number ".$THIS_CART->in_get('our/orderid') );


		#my @PAYMSGS = ();	# an array, of arrayrefs 0=success|failure 1=message_id 2=reference to msg
		#my $payment_method = $o->get_attrib('payment_method');
		#if ($payment_method eq 'MIXED') {
		#	push @PAYMSGS, [ $msgtype, sprintf('invoice_mixed_%s',$msgtype), {} ];
		#	}
		
		my $PAYMENTMSGSOUTPUT = '*** UNKNOWN PAYMENT STATUS ***';
		if ($THIS_CART->is_order()) {
			$PAYMENTMSGSOUTPUT = $THIS_CART->explain_payment_status('html'=>1,'format'=>'detail','*SITE'=>$SITE);
			}

		my $billaddress = &PAGE::checkout::html_address($THIS_CART, 'bill');
		$billaddress .= $THIS_CART->in_get('bill/phone')."<br>\n";
		if ($THIS_CART->in_get('bill/email') ne $THIS_CART->in_get('bill/phone')) { 
			$billaddress .= $THIS_CART->in_get('bill/email')."<br>\n"; 
			}
	
		my $shipaddress = &PAGE::checkout::html_address($THIS_CART, 'ship');
		$shipaddress .= $THIS_CART->in_get('ship/phone')."<br>\n";
	
		$OUTPUT .= $SITE->msgs()->get('invoice_header');
		my $nsref = $SITE->nsref();
		if ($nsref->{'plugin:invoicejs'} ne '') {
			$OUTPUT .= '<!-- plugin:invoicejs -->'.$SITE->msgs()->show($nsref->{'plugin:invoicejs'}).'<!-- /plugin:invoicejs -->';
			}

		if ($webdbref->{'buysafe_mode'}==3) {
			## this should only be shown when configured in buysafe guaranteed
			my $buysafe_hash = URI::Escape::XS::uri_escape($webdbref->{'buysafe_token'});
			$OUTPUT .= $SITE->msgs()->show(qq~
<!-- BEGIN: buySAFE Guarantee -->
<script src="https://seal.buysafe.com/private/rollover/rollover.js"></script>
<span id="BuySafeGuaranteeSpan"></span>
<script type="text/javascript">
 buySAFE.Hash = '$buysafe_hash';
 buySAFE.Guarantee.order = '%ORDERID%';
 buySAFE.Guarantee.total = '%SUBTOTAL%';
 buySAFE.Guarantee.email = '%BILLEMAIL%';
 WriteBuySafeGuarantee("JavaScript");
</script>
<!-- END: buySAFE Guarantee -->		
~);
			}

		
		if ((defined $THIS_CART) && (not $THIS_CART->is_paidinfull())) { 
			$OUTPUT .= $PAYMENTMSGSOUTPUT; 
			}

		if ($THIS_CART->in_get('want/shipping_id') eq 'Customer Pickup') {
			$OUTPUT .= $webdbref->{'ship_pickup_help'};
			}
	
		$OUTPUT .= qq~
			<table border="0" cellpadding="2" cellspacing="1" width="100%">
				<tr>
					<td colspan="2"><img src="$graphics_url/blank.gif" height="10" width="1"></td>
				</tr>
				<tr>
					<td align="left" width="50%"  class="ztable_head">Billing Information</td>
					<td align="left" width="50%"  class="ztable_head">Shipping Information</td>
				</tr>
				<tr>
					<td valign="top">
						<font class="ztxt">
						$billaddress
						</font>
					</td>
					<td valign="top">
						<font class="ztxt">
						$shipaddress
						</font>
					</td>
				</tr>
			</table>
			<img src="$graphics_url/blank.gif" width="1" height="8"><br>
		~;
	
		my $iniref = undef;
		#$OUTPUT .= &ORDER::VIEW::as_html($o,'INVOICE',$webdbref,$iniref,$SITE);
		#$OUTPUT .= &CART::VIEW::as_html(
		#	$SITE::CART, 'INVOICE', $webdbref,undef,$SITE,
		#	);
		if (defined $THIS_CART) {
			$OUTPUT .= &CART2::VIEW::as_html( $THIS_CART, 'INVOICE',undef,$SITE	);
			}


		### *** NEED LOVE ***
		#if (defined($THIS_CART->in_get('ship.%meta')->{'force_blurb'}) && ($cart{'ship.%meta'}->{'force_blurb'} ne '')) {
		#	$OUTPUT .= qq~\n<br>$cart{'ship.%meta'}->{'force_blurb'}\n~;
		#	}

		if ((defined $THIS_CART) && ($THIS_CART->is_paidinfull())) {
			$OUTPUT .= $PAYMENTMSGSOUTPUT;
			}
	
		if ($nsref->{'facebook:chkout'}) {
			## output Facebook follow 
			$OUTPUT .= qq~<!-- facebook --><a target="_facebook" href="$nsref->{'facebook:url'}"><img border=0 width='181' height='54' src="https://static.zoovy.com/graphics/paymentlogos/facebook_flw_181x54.png"></a><br>~;
			}

		## start "partner bar"
		$OUTPUT .= "<table cellspacing=5><tr>";
		if ($webdbref->{'branding'} < 3) {
			## zoovy logo
			$OUTPUT .= qq~<td valign=top><a target="_blank" href="http://www.zoovy.com/track.cgi?P=~.$SITE->username().qq~"><img align="left" border=0 src="https://www.zoovy.com/images/poweredby.gif"></a></td>\n~;
			}
		if ($webdbref->{'kount'}>0) {
			## kount is enabled!
			require PLUGIN::KOUNT;
			my ($pk) = PLUGIN::KOUNT->new($SITE->username(),prt=>$SITE->prt(),webdb=>$webdbref);
			if (defined $pk) {
				$OUTPUT .= "<td valign=top>\n<!-- KOUNT START -->\n".$pk->kaptcha($THIS_CART->cartid(),$SITE->sdomain())."\n<!-- END KOUNT -->\n</td>";
				}
			}
	
		$OUTPUT .= "</tr></table>";
	
		} ## end if 

	if (&ZOOVY::servername() eq 'dev') {
		## dev always gets ROI trackers
		$webdbref->{'chkout_roi_display'}++;
		}
	
	if ($STAGE->[0] ne 'INVOICE_DISPLAY') {
		}
	elsif ((not $THIS_CART->is_payment_success()) && (not $webdbref->{'chkout_roi_display'})) {
		$OUTPUT .= "<!-- ROI TRACKERS NOT SHOWN BECAUSE OF PAYMENT FAILURE! -->";
		}
	else {
		## on successfully paid, the output all the tracking codes.
		$OUTPUT .= $SITE->conversion_trackers($THIS_CART);
		}


	if ($SITE::CART2->in_get('want/keepcart')>0) {
		warn($SITE->username().": ".$THIS_CART->cartid()." cart preserved");
		}
	elsif ($STAGE->[0] eq 'INVOICE_DISPLAY') {
		## empty the cart if we're displaying an invoice.
		print STDERR "EMPTY BEFORE: ".$SITE::CART2->cartid()."\n";
		$SITE::CART2->empty(0xFF);   
		# $THIS_CART->reset_session('empty');
		print STDERR "EMPTY AFTER: ".$SITE::CART2->cartid()."\n";
		warn($SITE->username().": ".$SITE::CART2->cartid()." was EMPTIED.");
		}
	else {
		warn($SITE->username().": ".$THIS_CART->cartid()." STAGE: $STAGE->[0] (not EMPTIED)");
		}

	# Nuke the cart
	untie %cart2;
	## Moved the \%cart/cart save function to the bottom since we make changes during the RENDER stage (very bad)
	push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT, };

	return();	
	}


1;	