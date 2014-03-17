package SITE::MSGS;

use Storable;
use strict;
use lib "/backend/lib";
require ZOOVY;
require ZTOOLKIT;
require DBINFO;
require ZWEBSITE;
require TOXML::SPECL3;

@SITE::MSGS::MACROS = (
	[ 50, '', 'Payment Specific: (only available within a specific payment message)' ],
	[ 50,'%BILLADDR%','Customer\'s Billing Address'],
	[ 50,'%SHIPADDR%','Customer\'s Shipping Address'],
	[ 50,'%BILLPHONE%','Customer\'s Billing Phone'],
	[ 50,'%SHIPPHONE%','Customer\'s Shipping Phone'],
	[ 50,'%BILLEMAIL%','Customer\'s Billing Email'],
	[ 50,'%CUSTOMER_REFERENCE%','Customers reference #'],
	[ 50,'%MYNAME%','Company Name - from Zoovy account config'],
	[ 50,'%MYEMAIL%','Company Support Email - from Zoovy account config'],
	[ 50,'%MYPHONE%','Company Support Phone - from Zoovy account config'],
	[ 50,'%PAYABLETO%','Who to make checks/money orders/wire transfers/etc. payable to'],
	[ 50,'%ORDERID%','The Order ID (not available until the invoice stage)'],
	[ 50,'%MYADDRESS%','Company Mailing Address - from Zoovy Account Config'],
	[ 50,'%BALANCEDUE%','The total remaining amount due (minus any pre-authorized amounts)'],
	[ 50,'%GRANDTOTAL%','The total amount of the order without a dollar sign ($)'],
	[ 50,'%SUBTOTAL%','The subtotal (amount not including shipping+handling) of the order without a dollar sign'],
	[ 50, '', 'Payment Account Data: (optional/may not always be included within a payment)' ],
	[ 50,'%PAYMENT_FIXNOWURL%','The URL to "fix" a payment that had an error'],
	[ 50,'%PAYMENT_TENDER%','Zoovy tender type ex:: CREDIT, GOOGLE'],
	[ 50,'%PAYMENT_AMT%','Amount of payment (just numbers, no currency symbol)'],
	[ 50,'%PAYMENT_AMT_CURRENCY%','The currency format ex: USD for US Dollars'],
	[ 50,'%PAYMENT_AMT_PRETTY%','The amount of the payment formatted with currency symbol ex: $1.23'],
	[ 50,'%PAYMENT_NOTE%','The note attached to the payment'],
	[ 50,'%PAYMENT_DEBUG%','The debug note, or reason for failure, usually returned by the gateway, which may or may not be customer-comprehensible'],
	[ 50,'%PAYMENT_UUID%','Zoovy\'s unique payment tracking number for this payment'],
	[ 50,'%PAYMENT_TXN%','External gateway transaction'],
	[ 50,'%PAYMENT_AUTH%','External gateway authorization'],
	[ 50,'%PAYMENT_GC%','Giftcard Payment Only: Giftcard Masked'],
	[ 50,'%PAYMENT_AO%','Amazon Payment Only: Amazon Order'],
	[ 50,'%PAYMENT_BO%','Buy.com Payment Only: Buy.com Order'],
	[ 50,'%PAYMENT_GO%','Google Payment Only: Google Order'],
	[ 50,'%PAYMENT_EA%','Tender - E-Check Payment Only: Electronic Check Account'],
	[ 50,'%PAYMENT_ER%','Tender - E-Check Payment Only: Electronic Check Routing'],
	[ 50,'%PAYMENT_C4%','Tender - Credit Payment Only: Last 4 digits of the card'],
	[ 50,'%PAYMENT_CM%','Tender - Credit Payment Only: Credit card masked'],
	[ 50,'%PAYMENT_YY%','Tender - Credit Payment Only: Credit card expiration year'],
	[ 50,'%PAYMENT_MM%','Tender - Credit Payment Only: Credit card month'],
	[ 50,'%PAYMENT_PO%','Tender - Purchase Order: Purchase Order #'],
	[ 50, '', 'Tender Specific: (special fields, only available with specific payment tender types)' ],
	[ 50,'%CREDIT_TYPE%','The type of credit card. (ex: VISA, MasterCard)'],
	[ 50,'%CREDIT_NUMBER%','Credit card number the customer entered, with only the last few numbers showing'],
	[ 50,'%CREDIT_EXPMONTH%','Customer-entered credit card expiration month'],
	[ 50,'%CREDIT_EXPYEAR%','Customer-entered credit card expiration year'],
	);


##
## http://www.xe.com/symbols.php
##
%SITE::MSGS::CURRENCIES = (
	'USD'=>{ pretty=>"US Dollar", region=>"United States", symbol=>"24" },
	'CAN'=>{ pretty=>"Candian Dollar", region=>"Canada", symbol=>"24", },
	'EUR'=>{ pretty=>"Euro", region=>"European Union", symbol=>"20ac" },
	'GBP'=>{ pretty=>'Pounds', region=>'England (United Kingdom)', symbol=>"a3" },
	'MXN'=>{ pretty=>'Pesos', region=>'Mexico', symbol=>"24" },
	'AUD'=>{ pretty=>"Australian Dollar", region=>"Australia",  symbol=>"24" },
	);


##
## http://www.loc.gov/standards/iso639-2/php/code_list.php
##
%SITE::MSGS::LANGUAGES = (
#	ALB => { short=>'SQ', pretty=>'ALBANIAN', in=>'ALBANAIS', },
	ARA => { short=>'AR', pretty=>'ARABIC', in=>'ARABE', },
#	BEL => { short=>'BE', pretty=>'BELARUSIAN', in=>'BIORUSSE', },
#	BUL => { short=>'BG', pretty=>'BULGARIAN', in=>'BULGARE', },
#	CZE => { short=>'CS', pretty=>'CZECH', in=>'TCHUE', },
#	HI => { short=>'ZH', pretty=>'CHINESE', in=>'CHINOIS', },
#	WEL => { short=>'CY', pretty=>'WELSH', in=>'GALLOIS', },
#	CZE => { short=>'CS', pretty=>'CZECH', in=>'TCHUE', },
	DAN => { short=>'DA', pretty=>'DANISH', in=>'DANOIS', },
	GER => { short=>'DE', pretty=>'GERMAN', in=>'ALLEMAND', },
	DUT => { short=>'NL', pretty=>'DUTCH', in=>'FLAMAND', },
#	GRE => { short=>'EL', pretty=>'GREEK MODERN', in=>'', },
	ENG => { short=>'EN', pretty=>'ENGLISH', in=>'ANGLAIS', },
#	EPO => { short=>'EO', pretty=>'ESPERANTO', in=>'ESPANTO', },
#	EST => { short=>'ET', pretty=>'ESTONIAN', in=>'ESTONIEN', },
#	FIN => { short=>'FI', pretty=>'FINNISH', in=>'FINNOIS', },
#	FRE => { short=>'FR', pretty=>'FRENCH', in=>'FRANIS', },
	FRE => { short=>'FR', pretty=>'FRENCH', in=>'FRANIS', },
#	GEO => { short=>'KA', pretty=>'GEORGIAN', in=>'GRGIEN', },
#	GER => { short=>'DE', pretty=>'GERMAN', in=>'ALLEMAND', },
#	GLA => { short=>'GD', pretty=>'GAELIC', in=>'OSSAIS', },
#	GLE => { short=>'GA', pretty=>'IRISH', in=>'IRLANDAIS', },
#	GRE => { short=>'EL', pretty=>'GREEK', in=>'1453)', },
#	HEB => { short=>'HE', pretty=>'HEBREW', in=>'HREU', },
#	HIN => { short=>'HI', pretty=>'HINDI', in=>'HINDI', },
#	SCR => { short=>'HR', pretty=>'CROATIAN', in=>'CROATE', },
#	HUN => { short=>'HU', pretty=>'HUNGARIAN', in=>'HONGROIS', },
#	ARM => { short=>'HY', pretty=>'ARMENIAN', in=>'ARMIEN', },
#	ICE => { short=>'IS', pretty=>'ICELANDIC', in=>'ISLANDAIS', },
#	IND => { short=>'ID', pretty=>'INDONESIAN', in=>'INDONIEN', },
#	ICE => { short=>'IS', pretty=>'ICELANDIC', in=>'ISLANDAIS', },
	ITA => { short=>'IT', pretty=>'ITALIAN', in=>'ITALIEN', },
	JPN => { short=>'JA', pretty=>'JAPANESE', in=>'JAPONAIS', },
#	GEO => { short=>'KA', pretty=>'GEORGIAN', in=>'GRGIEN', },
#	KAZ => { short=>'KK', pretty=>'KAZAKH', in=>'KAZAKH', },
	KOR => { short=>'KO', pretty=>'KOREAN', in=>'CORN', },
#	KUR => { short=>'KU', pretty=>'KURDISH', in=>'KURDE', },
#	LAO => { short=>'LO', pretty=>'LAO', in=>'LAO', },
#	LIT => { short=>'LT', pretty=>'LITHUANIAN', in=>'LITUANIEN', },
#	LTZ => { short=>'LB', pretty=>'LUXEMBOURGISH', in=>'LUXEMBOURGEOIS', },
#	NOR => { short=>'NO', pretty=>'NORWEGIAN', in=>'NORVIEN', },
#	PER => { short=>'FA', pretty=>'PERSIAN', in=>'PERSAN', },
#	POL => { short=>'PL', pretty=>'POLISH', in=>'POLONAIS', },
#	POR => { short=>'PT', pretty=>'PORTUGUESE', in=>'PORTUGAIS', },
#	RUM => { short=>'RO', pretty=>'ROMANIAN', in=>'ROUMAIN', },
#	RUM => { short=>'RO', pretty=>'ROMANIAN', in=>'ROUMAIN', },
#	RUS => { short=>'RU', pretty=>'RUSSIAN', in=>'RUSSE', },
#	SCC => { short=>'SR', pretty=>'SERBIAN', in=>'SERBE', },
#	SCR => { short=>'HR', pretty=>'CROATIAN', in=>'CROATE', },
#	SLV => { short=>'SL', pretty=>'SLOVENIAN', in=>'SLOVE', },
	SPA => { short=>'ES', pretty=>'SPANISH', in=>'CASTILLAN', },
#	SCC => { short=>'SR', pretty=>'SERBIAN', in=>'SERBE', },
#	SWE => { short=>'SV', pretty=>'SWEDISH', in=>'SUOIS', },
#	THA => { short=>'TH', pretty=>'THAI', in=>'THA', },
#	TUR => { short=>'TR', pretty=>'TURKISH', in=>'TURC', },
#	UKR => { short=>'UK', pretty=>'UKRAINIAN', in=>'UKRAINIEN', },
#	VIE => { short=>'VI', pretty=>'VIETNAMESE', in=>'VIETNAMIEN', },
#	WEL => { short=>'CY', pretty=>'WELSH', in=>'GALLOIS', },
#	YID => { short=>'YI', pretty=>'YIDDISH', in=>'YIDDISH', },
#	ZHA => { short=>'ZA', pretty=>'ZHUANG', in=>'CHUANG', },
	CHI => { short=>'ZH', pretty=>'CHINESE', in=>'CHINOIS', },
	);



sub def { return (defined $_[0]) ? $_[0] : ''; }

%SITE::MSGS::CATEGORIES = (
	1=>'Inventory',
	50=>'Payment Messages',
	11=>'Special Pages',
	15=>'Errors',
	16=>'Checkout Errors',
	20=>'Call Center',
	);



##
## returns a single hashref, keyed by msgid, value is a hashref
##		custom ones are merged with default ones.
##
sub fetch_msgs {
	my ($self) = @_;

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $pstmt = "select MSGTXT,MSGID,CUSTOM_CATEGORY,CUSTOM_TITLE,LANG,LUSER,CREATED_GMT from SITE_MSGS where MID=".int($self->{'_MID'})." and PRT=".int($self->{'_PRT'});
	# print STDERR "$pstmt\n"; 
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my %result = ();

	foreach my $msgid (reverse sort keys %SITE::MSGS::DEFAULTS) {
		$result{$msgid} = $SITE::MSGS::DEFAULTS{$msgid};
		}

	while ( my ($msgtxt,$msgid,$category,$title,$lang,$luser,$created_gmt) = $sth->fetchrow() ) {
		# print "MSGID: $msgid\n";
		my $hint = 'Custom Message';
		if ($result{$msgid}->{'pretty'}) { $title =  $result{$msgid}->{'pretty'}; }
		if ($result{$msgid}->{'cat'}) { $category =  $result{$msgid}->{'cat'}; }
		if ($result{$msgid}->{'hint'}) { $hint =  $result{$msgid}->{'hint'}; }

		$result{$msgid} = {
			msg=>$msgtxt,
			hint=>$hint,
			cat=>$category,
			pretty=>$title,
			luser=>$luser,
			created_gmt=>$created_gmt,
			};		
		}
	$sth->finish();
	
	&DBINFO::db_user_close();
	
	return(\%result);
	}




%SITE::MSGS::DEFAULTS = (

		'page_forgot_login_msg'=>{
			msg=>q~If you've forgotten your password, please enter your email address below.<br>
<form action="%FORGET_URL%" method="post">
<input type="hidden" name="verb" value="question">
<input type="hidden" name="url" value="%REDIRECT_URL%">
Login : <input type="text" class="zform_textbox" length="30" maxlength="60" name="login" value="%LAST_LOGIN_FROM_COOKIE%">
<input type="submit" class="zform_button" name="submit" value="Go"><br>
<div class="zhint">(This is usually your email address)</div>
</form>~,
			hint=>q~~,
			cat=>11,
			pretty=>'Forgot Password Login Version',
			},
		'page_customer_signup_notenabled'=>{
			pretty=>'Customer Signup Not Enabled/Available',
			msg=>q~We apologize, but we are not accepting new clients via our online signup form at this time.~,
			hint=>q~Displayed to clients when they attempt to access /customer/signup and online customer signup is not enabled.~,
			cat=>11,
			},
		'page_customer_signup_success'=>{
			pretty=>'Customer Signup Success',
			msg=>q~We have created an account, however it is not yet active, and depending on our business rules may be locked. You will need to wait for us to approve your account before your final pricing discount level is established.~,
			hint=>q~Displayed to clients after a success at /customer/signup.~,
			cat=>11,
			},
		'page_contact_success'=>{
			msg=>q~
<div id="page_contact_success_msg">Thank you, your message has been sent successfully</div>
<div id="contact_success_sitebutton" align="center"><br><a href="%CONTINUE_URL%">
<% element(TYPE=>"SITEBUTTON",button=>"continue_shopping",alt=>"Continue Shopping"); print(); %>
</a><br></div>
~,
			hint=>q~This message is displayed when the user successfully executes the contact us form.~,
			cat=>11,
			pretty=>'Contact Us Success Message',
			},
		'chkout_amazoncba_success'=>{
			pretty=>'Checkout By Amazon - Success Page',
			hint=>'This is displayed when a customer complets an Checkout by Amazon, or Amazon Simple Pay purchase',
			msg=>q~
<div class="ztext">
Thank you for placing your order via Checkout by Amazon. <br>
Your Order Number is: %ORDERID%<br>
<br>
Your order status may take up to 6 hours to be processed and be available online, you will receive
a notification when this order ships.<br>
</div>
~,
			'cat'=>10,
			},
		## CATEGORY 1 is "SYSTEM MESSAGES"
		'inv_cart_add_warning'=> {
			msg=>q~<%
/* SPECL code to display what happened */
load("%%ACTUALQTY%%");
goto(gt=>"0",label=>"REDUCEDQTY");
:NOQTY();
print("Item %%SKU%% not added to cart");
stop();
:REDUCEDQTY();
print("Changed quantity of %%SKU%%, from %%REQUESTQTY%% to %%ACTUALQTY%%");
stop();

%><%

/* SPECL code to display reason */
strindex(haystack=>"%%SKU%%",needle=>":");
goto(gt=>"0",label=>"HASOPTIONS");
:NOOPTIONS();
print(" due to availability.");
stop();
:HASOPTIONS();
print(" for specific set of product options.");
stop();

%><%

/* SPECL code to output the out of stock message (if appropriate) */
load("%%ACTUALQTY%%");
goto(eq=>"0",label=>"OUTOFSTOCK");
print("");
stop();
:OUTOFSTOCK();
sysmesg(id=>"inv_outofstock");
default("");
print();
%>~,

			hint=>'Displayed when an item is added to the cart and insufficient inventory is available or no inventory is available',
			pretty=>'Inventory Add To Cart w/none-available',
			in=>'textbox', size=>60, maxlength=>200, cat=>1,
			},

		'inv_available'=> { 
			msg=>'Normally Ships Within 1-2 Days.', hint=>'', cat=>'1', 
			pretty=>'Inventory Available Message', in=>'textbox', size=>45, maxlength=>120 
			},
		'inv_reserved'=> {
			msg=>'This item is available in limited quantities.',
			hint=>'', cat=>'1', 
			pretty=>'Inventory Reserved Status Message', in=>'textbox',
			},
		'inv_safety'=> {
			msg=>'Inventory totals may not reflect quantities.',
			hint=>'', cat=>'1', 
			pretty=>'Inventory Safety Status Message', in=>'textbox',
			},
		'inv_outofstock'=> {
			msg=>'Currently out of stock.',
			hint=>'', cat=>'1', 
			pretty=>'Inventory Out of Stock Message', in=>'textbox',
			},
		'claim_message'=> {
			msg=>q~Thank you for coming to our store.  To complete your purchase, please select "Add To Cart" below.~,
			hint=>'', cat=>'1', 
			pretty=>'Claim Page Message', in=>'textbox',
			},
		'product_blank_price_message'=> {
			msg=>q~<p align="left">Not available for purchase</p>~,
			hint=>'This message is displayed above the continue shopping/cancel button for products which have a blank price and are not purchasable (e.g. Call for Price).', 
			cat=>'1', 
			pretty=>'Product Blank Price Message', in=>'textbox',
			},

		## CATEGORY 10 is CHECKOUT

		'chkout_choose_new' => {
			msg=> q~<p align="left">If you have never made a purchase at this web site and have never subscribed to this store's mailing list, please choose this option.</p>~,
			hint=>'CHOOSE PAGE: Create account instructions displayed during checkout', 
			cat=>'10', 
			pretty=>'CHOOSE PAGE TOP', in=>'',
			},
		'chkout_choose_existing' => {
			msg=> q~<p align="left">If you have made a purchase at this web site or have subscribed to this store's mailing list, please choose this option</p>~,
			hint=>'CHOOSE PAGE: Existing account instructions display during checkout',
			cat=>'10', 
			pretty=>'CHOOSE PAGE BOTTOM', in=>'',
			},
		'chkout_choose_usertxt' => {
			msg=> q~~,
			hint=>'This is normally blank, but you can but your own content in here.',
			cat=>'10', 
			pretty=>'CHOOSE PAGE USER Text', in=>'',
			},
		'chkout_login_public' => {
			msg=> q~<p align="left">If you have an existing login and password with this store, please enter it now.  If you have never made a purchase at this web site before, please hit Previous/Back and go through checkout under "New Customers".</p>~,
			hint=>'This is usually only displayed when a user enters an incorrect password.',
			cat=>'10', 
			pretty=>'Login page for public stores.', in=>'',
			},
		'chkout_login_restricted' => {
			msg=> q~<p align="left">Please enter your login and password now.</p>~,
			hint=>'This is displayed instead of the Create Account / Existing Account instructions above.',
			cat=>'10', 
			pretty=>'Login page for Member\'s Only and Private stores.', in=>'',
			},
		'chkout_shipping_billing' => {
			msg=> q~<p align="center">Please enter your billing/shipping location.  This store's policy is that the shipping and billing addresses be the same.</p>~,
			hint=>'',
			cat=>'10', 
			pretty=>'Checkout shipping and billing must match message.', in=>'',
			},
		'chkout_shipping' => {
			msg=> q~<p align="center">Please enter the location this order will be shipped to.</p>~,
			hint=>'',
			cat=>'10', 
			pretty=>'Checkout shipping location request.', in=>'',
			},
		'chkout_billing' => {
			msg=> q~<p align="center">Please enter your billing address.</p>~,
			hint=>'',
			cat=>'10', 
			pretty=>'Checkout billing location request.', in=>'',
			},
		'chkout_billing_footer' => {
			msg=> q~<img src="/media/graphics/general/blank.gif" height="10" width="1">~,
			hint=>'',
			cat=>'10', 
			pretty=>'Checkout billing location request.', in=>'',
			},
		'chkout_preflight' => {
			msg=> q~<div align="center" class="ztxt"><b>Checkout</b></div>~,
			hint=>'This is only displayed if you have a preflight stage to your checkout.',
			cat=>'10', 
			pretty=>'Checkout Preflight Top of Page.', in=>'',
			},
		'chkout_preflight_footer' => {
			msg=> q~<img src="/media/graphics/general/blank.gif" height="10" width="1">~,
			hint=>'This is only displayed if you have a preflight stage to your checkout.',
			cat=>'10', 
			pretty=>'Checkout Preflight Bottom of Page.', in=>'',
			},
		'chkout_confirm_notes'=>{
			msg=>q~
<div style="text-align:center; padding: 3px;" class="ztable_head">Order Notes</div>
<div style="margin-bottom: 10px;" class="ztxt">
Please include any special instructions or comments here:<br>
<textarea cols="60" rows="4" name="chkout.order_notes"><% 
/* note: it appears that the cart actually stores the order_notes data entity encoded. */
loadurp("CART2::want/order_notes"); default(""); print(); 
%></textarea>
</div>
~,
			hint=>'Please make sure your form field is named order_notes',
			cat=>'10', 
			pretty=>'Checkout Order Notes Title', in=>'',			
			},		
		'chkout_confirm_insurance'=>{
			msg=>q~<br><input type="checkbox" onChange="this.form.submit();" class="zcheckbox" %INS_CHECKED% name="ship.ins_purchased"> I would like to purchase optional shipping insurance (%INS_QUOTE%)<br>~,
			hint=>'Please make sure your form field is named order_notes',
			cat=>'10', 
			pretty=>'Checkout Shipping Insurance Title', in=>'',			
			},
		'chkout_confirm' => {
			msg=> q~<p align="left">Please review your order for accuracy.  Orders may be delayed or declined if your billing information does not match what's on file with your bank / credit card company.</p>~,
			hint=>'',
			cat=>'10', 
			pretty=>'Checkout confirm order prompt.', in=>'',
			},
		'chkout_confirm_middle' => {
			msg=> '',
			hint=>'Special field used for additional instructions above order notes.',
			cat=>'10', 
			pretty=>'Checkout special prompt: confirm middle', in=>'',
			},
		'chkout_confirm_end' => {
			msg=> '',
			hint=>'Special field used for displaying additional post order instructions.',
			cat=>'10', 
			pretty=>'Checkout special prompt: confirm end', in=>'',
			},
		'chkout_confirm_specl' => {
			msg=> '',
			hint=>'CONFIRM SPECL: Additional layer of validation/flow control for
checkout.<br>
DO NOT USE THIS UNLESS INSTRUCTED TO BY TECHNICAL SUPPORT OR YOU COULD BREAK
YOUR CHECKOUT.',
			cat=>'10', 
			pretty=>'Checkout special prompt: confirm specl', in=>'',
			},
		'chkout_login_exists' => {
			msg=> q~That email address already exists as a user in our system, please go back and log in using that account.  In case you do not know your password, it has been automatically mailed to you.~,
			hint=>'Message displayed when a duplicate account creation is attempte.',
			cat=>'10', 
			pretty=>'Login exists', in=>'',
			},
		'chkout_create_account' => {
			msg=> q~<i>This allows you to check your order's status online and optionally receive periodic updates via email.</i>~,
			hint=>'Message displayed which explains why user needs an account.',
			cat=>'10', 
			pretty=>'Account explanation', in=>'',
			},
		'chkout_new_customer' => {
			msg=> q~<p align="center">This is some information we need to set up your new account with our store.</p>~,
			hint=>'Message displayed to new users who are creating an account.',
			cat=>'10', 
			pretty=>'New customer message', in=>'',
			},
		'chkout_prohibited' => {
			msg=>q~
			<p align="center" class="zalert"><b>
			CHECKOUT LOGIC ERROR: an unspecified fatal error has occurred within checkout.
			</b></p>
			~,
			hint=>'this message is displayed when the buyer is prevented due to the ban list.',
			cat=>'10',
			pretty=>'Checkout Not Allowed',
			},
		'input_credit' => {
			msg=> q~<div align="left"><p>Please review your billing information.  
If the billing address does not match the information on file with your credit card company, 
please go back and change it so that it matches.</p>
<b>%BILLADDR%</b><br>Phone: <b>%BILLPHONE%</b></div>~,
			hint=>'Instructions to make sure credit card works with AVS.',
			cat=>'10', 
			pretty=>'Checkout input credit message', in=>'',
			},
		'input_credit_onfile' => {
			msg=> q~<div align="left">
<p>We have the following credit card information on file for you.</p>
<p><b>%CCTYPE% %CCNUMBER% expiring on %CCEXPMONTH%/%CCEXPYEAR%</b></p>
<p>To use this credit card leave the text box below blank, or to use a different card enter it now.</p>
</div>~,
			hint=>'Additional instructions if the user has a credit card already on-file.',
			cat=>'10', 
			pretty=>'Checkout input credit on-file message', in=>'',
			},

		'input_echeck' => { 
			msg=>q~<div align="left">
<p>Please enter the relevant information for the check you want to use to pay for this order.</p>
</div>~,
			hint=>'Instructions for user inputting their check number.',
			cat=>'10', 
			pretty=>'Checkout electronic check prompt', in=>'',
			},
		'input_po' => {
			msg=> q~<div align="left">
<p>Please review your billing information and enter the purchase order number below.</p>
<b>%BILLADDR%</b>
<br>
Phone: <b>%BILLPHONE%</b>
</div>~,
			hint=>'Displayed to users before they input their PO number.',
			cat=>'10', 
			pretty=>'Checkout PO input message', in=>'',
			},

);


sub username { return($_[0]->{'_USERNAME'}); }
sub profile { return($_[0]->{'_PROFILE'}); }
sub prt { return($_[0]->{'_PRT'}); }
sub lang { return($_[0]->{'_LANG'}); }


##
## VALID OPTIONS: 
##
## RAW = no interpolation will occur.
##	CART = a reference to the cart we should use for interpolation
##	WEBDB = a reference to the webdb file
##	PRT = the partition in focus
##
sub new {
	my ($class, $USERNAME, %options) = @_;

	my $PROFILE = 'DEFAULT';
	if ($options{'RAW'}) {
		## for when we're editing messages
		}
	elsif (defined $options{'*SITE'}) {
		## this is what makes us happy.
		}
	elsif (not defined $options{'*SITE'}) {
		warn "SITE::msgs really likes it when it's passed a *SITE object: ".join("|",caller(0))."\n";
		}

	my $self = {};

	if (not defined $options{'LANG'}) { $options{'LANG'} = 'ENG'; }
	
	$self->{'_LANG'} = $options{'LANG'};
	$self->{'_MID'} = int(&ZOOVY::resolve_mid($USERNAME));
	$self->{'_USERNAME'} = $USERNAME;
	$self->{'_PROFILE'} = $PROFILE;	
	$self->{'_PRT'} = int($options{'PRT'});	
	if (defined $options{'RAW'}) { 
		$self->{'_RAW'}++; 
		$self->{'%VARS'} = {};
		}
	else {
		if (defined $options{'*CART2'}) { $self->{'*CART2'} = $options{'*CART2'}; }
		if (defined $options{'*SITE'}) { $self->{'*SITE'} = $options{'*SITE'}; }
		}
	
	bless $self, 'SITE::MSGS';

	if ($self->{'_RAW'}==0) {
		## load $self->{'%VARS'}
		# $self->refresh();
		}

#	use Data::Dumper; print Dumper($self);

	return($self);
	}


sub cart2 { return($_[0]->{'*CART2'}); }
sub site { return($_[0]->{'*SITE'}); }
sub txspecl { return($_[0]->{'*SITE'}->txspecl()); }

##
##
##
sub getref {
	my ($self, $msgid, $lang) = @_;

	$msgid = lc($msgid);

	my %result = ();
	my $ref = $SITE::MSGS::DEFAULTS{$msgid};
	if (defined $ref) { %result = %{$ref}; }

	if (substr($msgid,0,1) eq '~') {
		## custom field -- won't exist in $ref
		$result{'cat'} = -1;
		}

	$result{'defaultmsg'} = $ref->{'msg'};
	$result{'created_gmt'} = 0;
	$result{'luser'} = '';

	if (not defined $lang) { $lang = $self->{'_LANG'}; }


	my $dbh = &DBINFO::db_user_connect($self->username());
	my $qtMSGID = $dbh->quote($msgid);
	my $qtLANG = $dbh->quote($lang);
	my $PRT = int($self->{'_PRT'});

	my $pstmt = "select MSGTXT,CREATED_GMT,LUSER,CUSTOM_CATEGORY,CUSTOM_TITLE from SITE_MSGS where MID=$self->{'_MID'} /* ".$self->username()." */ and PRT=$PRT and MSGID=".$qtMSGID." and LANG=".$qtLANG;
	# print STDERR $pstmt."\n";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	if ($sth->rows()) {
		($result{'msg'},$result{'created_gmt'},$result{'luser'},my $category,my $title)  = $sth->fetchrow();
		if (not defined $result{'cat'}) { $result{'cat'} = $category; }
		if (not defined $result{'pretty'}) { $result{'pretty'} = "Custom: $title"; }
		}
	$sth->finish();
	&DBINFO::db_user_close();

	return(\%result);
	}





sub exists {
	my ($self, $msgid) = @_;

	my $webdbref = $self->site()->webdbref(); 

	my $exists = 0;
	if ((defined $webdbref) && (defined $webdbref->{'@SITEMSGS'})) {
		## lookup from webdb file
		foreach my $set (@{$webdbref->{'@SITEMSGS'}}) {
#			print STDERR "CUSTOM SITEMSG: $set->{'id'} $set->{'msgtxt'}";
			next unless ($set->{'id'} eq $msgid);
			next unless ($set->{'lang'} = $self->{'_LANG'});
			$exists |= 1;
			}
		}
	else {
		## hmm.. legacy method, go to database.
		my $udbh = &DBINFO::db_user_connect($self->username());
		my $qtMSGID = $udbh->quote($msgid);
		my $qtLANG = $udbh->quote($self->{'_LANG'});
		my $PRT = int($self->{'_PRT'});
		my $pstmt = "select count(*) from SITE_MSGS where MID=$self->{'_MID'} /* ".$self->username()." */ and PRT=$PRT and MSGID=".$qtMSGID." and LANG=".$qtLANG;
		# print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		my ($count) = $sth->fetchrow();
		$sth->finish();
		&DBINFO::db_user_close();
		if ($count) { $exists |= 1; }
		}


	if (not $exists) {
		if (defined $SITE::MSGS::DEFAULTS{ $msgid }->{'msg'}) { $exists |= 2; }
		}
	
	return($exists);	
	}


##
##
##	$macroref 
##		*NOTE: macros should *ALWAYS* be language independent.
##		a hashref of shortcuts for common macros used in this message or specific to this message e.g.
##		{ '%SKU%'=>value  }
##
##	%options
##		not used yet, but we'll probably be able to override language this way.
##
sub get {
	my ($self, $msgid, $macroref, %options) = @_;

	$msgid = lc($msgid);


	my $msgtxt = undef;
	my $webdbref = $self->site()->webdbref(); 

	if ((defined $webdbref) && (defined $webdbref->{'@SITEMSGS'})) {
		## lookup from webdb file
		foreach my $set (@{$webdbref->{'@SITEMSGS'}}) {
			next unless ($set->{'id'} eq $msgid);
			next unless ($set->{'lang'} = $self->{'_LANG'});
			$msgtxt = $set->{'msgtxt'};
			}
		}
	else {
		## hmm.. legacy method, go to database.
		my $udbh = &DBINFO::db_user_connect($self->username());
		my $qtMSGID = $udbh->quote($msgid);
		my $qtLANG = $udbh->quote($self->{'_LANG'});
		my $PRT = int($self->{'_PRT'});
		my $pstmt = "select MSGTXT from SITE_MSGS where MID=$self->{'_MID'} /* ".$self->username()." */ and PRT=$PRT and MSGID=".$qtMSGID." and LANG=".$qtLANG;
		# print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		($msgtxt) = $sth->fetchrow();
		$sth->finish();
		&DBINFO::db_user_close();
		}


	if (not defined $msgtxt) {
		$msgtxt = $SITE::MSGS::DEFAULTS{ $msgid }->{'msg'};		
		}

	if ($self->{'_RAW'}) {
		## we don't interpolate in RAW mode
		}
	else {
		# $msgtxt = &SITE::MSGS::interpolate($msgtxt,$self->{'%VARS'});

		if ((index($msgtxt,'%')>=0) && (defined $macroref) && (ref($macroref) eq 'HASH')) {
			## we have at least one macro (or we probably do), but we might be able to short circuit
			##	using constants passed into this site msg.
			$msgtxt = &interpolate_macroref($msgtxt,$macroref);
			}

		#if (index($msgtxt,'%')>=0) {
		#	## we *STILL* have at least one macro (or we probably do)
		#	## this will go through and convert any macros e.g. %BILLEMAIL% to their
		#	## respective specl command <% loadurp("CART::chkout.bill_email"); default(""); print(); %>
		#	$msgtxt = &interpolate_macroref($msgtxt,\%SITE::EMAIL::CART_MACROS);
		#	}

		my @vars = ();		

		($msgtxt) = $self->txspecl()->translate3($msgtxt, [], replace_undef=>0);
		}

	

	return($msgtxt);
	}





sub show {
	my ($self,$msgtxt) = @_;

	#if (index($msgtxt,'%')>=0) {
	#	## we have at least one macro (or we probably do)
	#	## this will go through and convert any macros e.g. %BILLEMAIL% to their
	#	## respective specl command <% loadurp("CART::chkout.bill_email"); default(""); print(); %>
	#	$msgtxt = &interpolate_macroref($msgtxt,\%SITE::EMAIL::CART_MACROS);
	#	}

	require TOXML::SPECL3;
	my @vars = ();		

	if (not defined $self->txspecl()) {
		warn Carp::confess("CANNOT CALL TXSPECL (NOT DEFINED) -- YOU SHOULD REALLY DEFINE IT!");
		die();
		}
	else {
		($msgtxt) = $self->txspecl()->translate3($msgtxt, [], replace_undef=>0);
		}
	
	return($msgtxt);
	}



sub interpolate_macroref { return(fast_interpolate_macroref(@_)); }

##
##
##
sub safe_interpolate_macroref {
	my ($txt, $macroref) = @_;

	foreach my $k (keys %{$macroref}) {
		next unless (index($txt,$k)>=0);	## regex's are more expensive than index!
		$txt =~ s/$k/$macroref->{$k}/gis;
		}

	return($txt);
	}

## wow.. that was easy once I figured it out.
## 	and it doesn't replace macro's inside of itself.
sub fast_interpolate_macroref {
	my ($txt, $macroref) = @_;
	## sometimes messages have a %%SKU%% or something in them.. wtf? no clue.
	$txt =~ s/(\%\%?[A-Z\_]+\%\%?)/{((defined $macroref->{$1})?$macroref->{$1}:$1)}/oegis;
	return($txt);
	}



##
##
##
sub interpolate_macros {
	my ($txt) = @_;

	#my %q = %SITE::EMAIL::CART_MACROS;
	#foreach my $k (keys %q) {
	#	next unless (index($txt,$k)>=0);	## regex's are more expensive than index!
	#	$txt =~ s/$k/$q{$k}/gis;
	#	}

	return($txt);
	}



##
## create a custom message
##
sub create {
	my ($self, $msgid, $lang, $luser, $title, $category) = @_;

	my $udbh = &DBINFO::db_user_connect($self->username());
	
	if (1) {
		my $pstmt =	&DBINFO::insert($udbh,'SITE_MSGS',{
			'USERNAME'=>$self->username(),
			'MID'=>$self->{'_MID'},
			'PRT'=>$self->prt(),
			'MSGID'=>lc($msgid),
			'MSGTXT'=> '',
			'CREATED_GMT'=>time(),
			'LUSER'=>$luser,
			'LANG'=>$lang,
			'CUSTOM_TITLE'=>$title,
			'CUSTOM_CATEGORY'=>$category,
			},debug=>2,key=>['MID','PRT','MSGID','LANG'],update=>1);
		print STDERR $pstmt."\n";
		$udbh->do($pstmt);
		}

	$self->compile();
	
	&DBINFO::db_user_close();
			

	}



##
##
##
sub save {
	my ($self, $msgid, $msgtxt, $lang, $luser) = @_;

	$msgid = lc($msgid);

#mysql> desc SITE_MSGS;
#+-------------+------------------+------+-----+---------+----------------+
#| Field       | Type             | Null | Key | Default | Extra          |
#+-------------+------------------+------+-----+---------+----------------+
#| ID          | int(10) unsigned | NO   | PRI | NULL    | auto_increment |
#| USERNAME    | varchar(20)      | NO   |     | NULL    |                |
#| MID         | int(10) unsigned | NO   | MUL | 0       |                |
#| MSGSET      | varchar(8)       | NO   |     | NULL    |                |
#| MSGID       | varchar(48)      | NO   |     | NULL    |                |
#| MSGTXT      | mediumtext       | NO   |     | NULL    |                |
#| CREATED_GMT | int(10) unsigned | YES  |     | 0       |                |
#| LUSER       | varchar(10)      | NO   |     | NULL    |                |
#+-------------+------------------+------+-----+---------+----------------+
#8 rows in set (0.01 sec)

	if (not defined $luser) { $luser = ''; }

	my $dbh = &DBINFO::db_user_connect($self->username());

	if (not defined $lang) { $lang = 'ENG'; }
	my $qtLANG = $dbh->quote($lang);
	my $pstmt = '';
	my $result = undef;
	if ($SITE::MSGS::DEFAULTS->{$msgid}->{'msg'} eq $msgtxt) {
		## we should be doing a delete!
		$pstmt = "delete from SITE_MSGS where MID=".int($self->{'_MID'})." and PRT=".int($self->{'_PRT'})." and MSGID=".$dbh->quote($msgid)." and LANG=$qtLANG";
		$result = 0;
		}
	else {
		$pstmt =	&DBINFO::insert($dbh,'SITE_MSGS',{
			'USERNAME'=>$self->username(), 
			'MID'=>$self->{'_MID'},
			'PRT'=>$self->prt(),
			'MSGID'=>lc($msgid),
			'MSGTXT'=> $msgtxt,
			'CREATED_GMT'=>time(),
			'LUSER'=>$luser,
			'LANG'=>$lang,
			},debug=>2,key=>['MID','PRT','MSGID','LANG'],update=>1);
		$result = 1;
		}
	$dbh->do($pstmt);

	$self->compile();

	&DBINFO::db_user_close();
	return($result);
	}



sub compile {
	my ($self) = @_;

#+-------------+----------------------+------+-----+---------+----------------+
#| Field       | Type                 | Null | Key | Default | Extra          |
#+-------------+----------------------+------+-----+---------+----------------+
#| ID          | int(10) unsigned     | NO   | PRI | NULL    | auto_increment |
#| USERNAME    | varchar(20)          | NO   |     | NULL    |                |
#| MID         | int(10) unsigned     | NO   | MUL | 0       |                |
#| PRT         | smallint(5) unsigned | NO   |     | 0       |                |
#| MSGID       | varchar(48)          | NO   |     | NULL    |                |
#| LANG        | varchar(3)           | NO   |     | ENG     |                |
#| MSGTXT      | mediumtext           | NO   |     | NULL    |                |
#| CREATED_GMT | int(10) unsigned     | YES  |     | 0       |                |
#| LUSER       | varchar(10)          | NO   |     | NULL    |                |
#+-------------+----------------------+------+-----+---------+----------------+

   my $dbh = &DBINFO::db_user_connect($self->username());
	my $pstmt = "select MSGID,LANG,MSGTXT from SITE_MSGS where MID=".int($self->{'_MID'})." /* ".$self->username()."  */ and PRT=".int($self->{'_PRT'});
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my @SET = ();
	while ( my ( $msgid,$lang,$txt) = $sth->fetchrow() ) {		
		push @SET, { id=>$msgid, lang=>$lang, msgtxt=>$txt };
		}
	$sth->finish();
	&DBINFO::db_user_close();

	my $webdbref = &ZWEBSITE::fetch_website_dbref($self->username(),$self->prt());
	$webdbref->{'@SITEMSGS'} = \@SET;
	&ZWEBSITE::save_website_dbref($self->username(),$webdbref,$self->prt());
	}


1;