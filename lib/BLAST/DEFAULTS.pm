package BLAST::DEFAULTS;

##
## remember: CUSTOMER and ORDER will also appear in TICKET emails!
##

# %PRT.LINKSTYLE

%BLAST::DEFAULTS::MACROS = (
#	[ 'TICKET', '%TKTCODE%', 'Ticket Identifier' ],
#	[ 'TICKET', '%TKTSUBJECT%', 'Ticket Subject' ],
#	[ 'TICKET', '%CUSTOMER__URL%', 'Customer URL' ],
#	[ 'PRODUCT', '%PROD_IMAGE_TAG%', 'a 200x200 version of an image (can be overidden)' ],
#	[ 'PRODUCT', '%PRODUCTID%', 'Product ID' ],

#	[ 'PRODUCT', '%SENDER_NAME%', 'The name of the person who sent the email (cgi variable: sender_name)' ],
#	[ 'PRODUCT', '%SENDER_SUBJECT%', 'The subject that was supplied by the user (cgi variable: sender_subject)' ],
#	[ 'PRODUCT', '%SENDER_BODY%', 'The body that was supplied by the user (cgi variable sender_body)' ],


	'%PRODUCT_VIEWLINK%'=> q|<span data-tlc="bind '.%PRODUCT.ADDLINK'; apply --append;"></span>|,
	'%PRODUCT_ADDLINK%'=> q|<span data-tlc="bind '.%PRODUCT.ADDLINK'; apply --append;"></span>|,
	'%PRODUCT_PRICE%'=> q|<span data-tlc="bind '.%PRODUCT.PRICE'; apply --append;"></span>|,
	'%PRODUCT_IMAGE%'=> q|<span data-tlc="bind '.%PRODUCT.IMAGE'; apply --append;"></span>|,
	'%PRODUCT_ID%'=> q|<span data-tlc="bind '.%PRODUCT.PID'; apply --append;"></span>|,
	'%PRODUCT_TITLE%'=> q|<span data-tlc="bind '.%PRODUCT.TITLE'; apply --append;"></span>|,

	'%TKTURL%'=> q|<span data-tlc="bind '.%TICKET.URL'; apply --append;"></span>|,
	'%TKTSUBJECT%'=> q|<span data-tlc="bind '.%TICKET.SUBJECT'; apply --append;"></span>|,
	'%TKTCODE%'=> q|<span data-tlc="bind '.%TICKET.CODE'; apply --append;"></span>|,
	
	'%PHONE%'=> q|<span data-tlc="bind '.%PRT.PHONE'; apply --append;"></span>|,
	'%DOMAIN%'=> q|<span data-tlc="bind '.%PRT.DOMAIN'; apply --append;"></span>|,
	'%MAILADDR%'=> q|<span data-tlc="bind '.%PRT.MAILADDR'; apply --append;"></span>|,
	'%EMAIL%'=> q|<span data-tlc="bind '.%PRT.EMAIL'; apply --append;"></span>|,
	'%LINKSTYLE%'=> q|<span data-tlc="bind '.%PRT.LINKSTYLE'; apply --append;"></span>|,

	'%LINKDOMAIN%'=> q|<span data-tlc="bind '.%PRT.DOMAIN'; format --prepend='http://'; apply --attrib='href'; apply --append;"></span>|,
	'%LINKPHONE%'=> q|<span data-tlc="bind '.%PRT.PHONE'; format --prepend='callto://'; apply --attrib='href'; apply --append;"></span>|,
	'%LINKEMAIL%'=> q|<span data-tlc="bind '.%PRT.EMAIL'; format --prepend='mailto://'; apply --attrib='href'; apply --append;"></span>|,


	'%HEADER%'=>q|
<head>
<style>
<!-- http://www.campaignmonitor.com/css/ -->
<!-- note: gmail will be modified to use embedded styles for max compat. -->
body { font-family: helvetica; }
</style>
</head>
<body>|,
	'%FOOTER%'=>q|
<hr>
<table>
<tr>
<td>
<b>Unsubscribe from receiving additional reminders for this transaction:</b><br>
<a href="http://%SDOMAIN%/customer/newsletter/unsubscribe?aolemail=$RECIPIENT">
<a href="http://%SDOMAIN%/customer/newsletter/unsubscribe?aolemail=$RECIPIENT&claim=$options{'CLAIM'}">
</td>
</tr>
</table>
</body>
|,

	'%AMAZON_ORDERID%' => q|<span data-tlc="bind $var '.%ORDER.%mkt.amazon_orderid'; apply --append;"></span>|,
	'%ORDERID%'=> q|<span data-tlc="bind $var '.%ORDER.%our.orderid'; apply --append;"></span>|,
	'%CARTID%'=> 	q|<span data-tlc="bind $var '.%ORDER.%cart.cartid'; apply --append;"></span>|,
	'%EREFID%'=> 	q|<span data-tlc="bind $var '.%ORDER.%want.erefid'; apply --append;"></span>|,
	'%BILLEMAIL%'=> 	q|<span data-tlc="bind $var '.%ORDER.%bill.email'; apply --append;"></span>|,
	'%LINKORDER%'=> q|<a href="#" data-tlc="
bind $orderid '.%ORDER.%our.orderid'; bind $softauth '.%ORDER.%cart.cartid'; bind $domain '.%PRT.DOMAIN'; set $link '';
format $link --append='http://' --append=$domain --append='?#verb=orderview&order=' --append=$orderid --append='&softauth=' --append=$softauth;
apply --attrib='href'; apply --append;"></a>
|,

	'%ORDERITEMS%'=> q|
<table id="contents">
<thead>
<tr>
	<th>IMG</th>
	<th>DESC</th>
	<th>PRICE</th>
	<th>QTY</th>
	<th>EXT</th>
</tr>
</thead>
<tbody data-tlc="bind $items '.%ORDER.@ITEMS'; foreach $item in $items {{ transmogrify --templateid='skuTemplate' --dataset=$item; apply --append; }};">
<template id="skuTemplate">
<tr>
	<td>
	 <img data-tlc="
bind $var '.%attribs.zoovy:prod_image1'; 
if (is $var --blank) {{ bind $var '.%attribs.zoovy:prod_image1'; }};
apply --img --media=$var --width=75 --height=75 --bgcolor='#ffffff' --replace;" src="blank.gif" class="prodThumb" alt="" height="55" width="55">
	</td>
	<td>
	<b data-tlc="bind $var '.prod_name'; if (is $var --notblank) {{apply --append;}};"></b>
	<div data-tlc="bind $var '.sku'; format --prepend='Sku: '; if (is $var --notblank) {{apply --append;}};"></div>
	</td>
	<td data-tlc="bind $var '.price'; if (is $var --notblank) {{ format --currency='USD'; format --prepend='x '; apply --append;}};"></td>
 	<td data-tlc="bind $var '.qty'; if (is $var --notblank) {{ apply --append;}};"></td>
	<td data-tlc="bind $var '.extended'; if (is $var --notblank) {{ format --currency='USD'; format --prepend='= ';apply --append;}};"></td>
</tr>

</template>
</tbody>
</table>
|,

	'%PACKSLIP%'=> q|
<table id="contents" data-tlc="bind $items '.@ITEMS'; foreach $item in $items {{ transmogrify --templateid='skuTemplate' --dataset=$item; apply --append; }}; ">
<thead>
<tr>
	<th>QTY</th>
	<th>SKU</th>
	<th>DESC</th>
</tr>
</thead>
<tbody>
<template id="skuTemplate">
<tr>
	<td data-tlc="bind $var '.qty'; if (is $var --notblank) {{ apply --append;}};"></td>
	<td data-tlc="bind $var '.sku'; apply --append;"></td>
	<td data-tlc="bind $var '.prod_name'; if (is $var --notblank) {{apply --append;}};"></td>
</tr>
</template>
</tbody>
</table>
|,

	'%ORDERNOTES%'=> q|
<div data-tlc="bind $var '.%want.order_notes'; apply --append;"></div>
|,

	'%DEBUG%'=> q|
<div data-tlc="bind $var '.'; stringify $var; apply --append;"></div>
|,

	'%SHIPADDR%'=> q|
 <div class="addressFullname">
  <span data-tlc="bind $var '.%ORDER.%ship.firstname'; if (is $var --notblank) {{apply --append;}};" title="first name"></span>
  <span data-tlc="bind $var '.%ORDER.%ship.lastname'; if (is $var --notblank) {{apply --append;}};" title="last name"></span>
 </div>
 <div class="address">
  <div data-tlc="bind $var '.%ORDER.%ship.address1'; if (is $var --notblank) {{apply --append;}};" title="address"></div>
  <div data-tlc="bind $var '.%ORDER.%ship.address2'; if (is $var --notblank) {{apply --append;}};" title="address 2"></div>
  <span data-tlc="bind $var '.%ORDER.%ship.city'; if (is $var --notblank) {{apply --append;}};" title="city"></span>,
  <span data-tlc="bind $var '.%ORDER.%ship.region'; if (is $var --notblank) {{apply --append;}};" title="state"></span>.
  <span data-tlc="bind $var '.%ORDER.%ship.postal'; if (is $var --notblank) {{apply --append;}};" title="zip"></span>
  <div data-tlc="bind $var '.%ORDER.%ship.countrycode'; if (is $var --notblank) {{apply --append;}};" title="country"></div>
 </div>
|,

	'%BILLADDR%'=> q|
 <div class="addressFullname">
  <span data-tlc="bind $var '.%ORDER.%bill.firstname'; if (is $var --notblank) {{apply --append;}};" title="first name"></span>
  <span data-tlc="bind $var '.%ORDER.%bill.lastname'; if (is $var --notblank) {{apply --append;}};" title="last name"></span>
 </div>
 <div class="address">
  <div data-tlc="bind $var '.%ORDER.%bill.address1'; if (is $var --notblank) {{apply --append;}};" title="address"></div>
  <div data-tlc="bind $var '.%ORDER.%bill.address2'; if (is $var --notblank) {{apply --append;}};" title="address 2"></div>
  <span data-tlc="bind $var '.%ORDER.%bill.city'; if (is $var --notblank) {{apply --append;}};" title="city"></span>,
  <span data-tlc="bind $var '.%ORDER.%bill.region'; if (is $var --notblank) {{apply --append;}};" title="state"></span>.
  <span data-tlc="bind $var '.%ORDER.%bill.postal'; if (is $var --notblank) {{apply --append;}};" title="zip"></span>
  <div data-tlc="bind $var '.%ORDER.%bill.countrycode'; if (is $var --notblank) {{apply --append;}};" title="country">
  </div>
  <div data-tlc="bind $var '.%ORDER.%bill.phone'; if (is $var --notblank) {{apply --append;}};" title="phone">
  </div>
 </div>
|,

	'%SHIPMETHOD%'=> q|<div data-tlc="bind $var '.%ORDER.%sum.shp_method'; apply --append;"></div>|,

	'%PAYINFO%'=> q|

<div data-tlc="
bind $payments '.%ORDER.@PAYMENTS';
set $info '';
foreach $payment in $payments {{
	export '%payment' --dataset=$payment;
	set $info '';
	set $tender $payment --path='.tender';
	set $ps 		$payment --path='.ps';

	/* acct is a pipe delimed, colon separated key value pairs, each key is two digits */
	bind $acct '.%payment.acct';
	format $acct --split='\|';
	export '%paymentacct' --dataset=$acct;

	set $expmmyy '';
	foreach $keyvalue in $acct {{
		set $key $keyvalue;	
		set $value $keyvalue;
		if (is $keyvalue --notblank) {{ format $key --truncate=2; format $value --chop=3; }};
	
		if (is $key --eq='CM') {{ format $info --append='Credit Card: ' --append=$value; }};
		if (is $key --eq='YY') {{ format $expmmyy --append='/' --append=$value; }};
		if (is $key --eq='MM') {{ format $expmmyy --prepend=$value; }};
		}};

	if (is $info --blank) {{ set $info $tender; }};

	/* append expiration date */
	if (is $expmmyy --notblank) {{ format $info --append=' Exp:' --append=$expmmyy; }};
	apply --append=$info;

	/* stringify $acct; apply --append; */
	/* stringify $payment; apply --append; */
	}};

/* no payments .. default to payment_method in order */
if (is $info --blank) {{ 
	bind $info '.%ORDER.%flow.payment_method';
	apply --append;
	}};

set $info '';
format $info --crlf;
apply --append=$info;

bind $ps '.%ORDER.%flow.payment_status';
format $ps --truncate=1;
if (is $ps --eq='0') {{ set $info 'Paid in Full'; }};
if (is $ps --eq='1') {{ set $info '(Pending)'; }};
if (is $ps --eq='2') {{ set $info '(Denied)'; }};
if (is $ps --eq='3') {{ set $info '(Cancelled)'; }};
if (is $ps --eq='4') {{ set $info '(Paid/Review)'; }};
if (is $ps --eq='9') {{ bind $ps '.%ORDER.%flow.payment_status'; format $info --append='(Error:' --append=$ps --append=')'; }};
if (is $info --blank) {{ bind $ps '.%ORDER.%flow.payment_status'; format $info --append='(Unknown:' --append=$ps --append=')'; }};

/* apply --append='payment status: ' --append=$ps; */
apply --append=$info;
">
</div>
|,

	'%PAYINSTRUCTIONS%'=> q|
<div data-tlc="

set $skip_chained 1;
bind $dataset '.';
bind $payments '.%ORDER.@PAYMENTS';
/* stringify $payments; apply --append; */
set $summary '';
set $paymentscount 0;
foreach $payment in $payments {{
	set $info '';
	set $tender $payment --path='.tender';
	set $ps 		$payment --path='.ps';

	/* acct is a pipe delimed, colon separated key value pairs, each key is two digits */
	set $acct $payment --path='.acct' --split='\|';

	set $expmmyy '';
	foreach $keyvalue in $acct {{
		set $key $keyvalue;	
		set $value $keyvalue;
		if (is $keyvalue --notblank) {{ format $key --truncate=2; format $value --chop=3; }};
	
		if (is $key --eq='CM') {{ format $info --append='Credit Card: ' --append=$value; }};
		if (is $key --eq='YY') {{ format $expmmyy --append='/' --append=$value; }};
		if (is $key --eq='MM') {{ format $expmmyy --prepend=$value; }};
		}};

	if (is $info --blank) {{ set $info $tender; }};

	/* append expiration date */
	if (is $expmmyy --notblank) {{ format $info --append=' Exp:' --append=$expmmyy; }};
	format $summary --append=$info --crlf;
	math $paymentscount --add=1;
	}};

if ( is $paymentscount --eq=0 ) {{
	set $summary 'There are no payments currently applied to this order.';
	}};
if ( is $paymentscount --gt=1 ) {{
	/* [2 Payments Total] */
	format $summary --crlf --append='[' --append=$paymentscount --append=' Payments Total]';
	}};

bind $orderid '.%ORDER.%our.orderid';
bind $grandtotal '.%ORDER.%sum.order_total';
bind $balancedue '.%ORDER.%sum.balance_due_total';
bind $customerref '.%ORDER.%want.po_number';
bind $ps '.%ORDER.%flow.payment_status';
format $ps --truncate=1;

if (is $ps --eq='0') {{ set $info 'Paid in Full'; }};
if (is $ps --eq='1') {{ set $info '(Pending)'; }};
if (is $ps --eq='2') {{ set $info '(Denied)'; }};
if (is $ps --eq='3') {{ set $info '(Cancelled)'; }};
if (is $ps --eq='4') {{ set $info '(Paid/Review)'; }};
if (is $ps --eq='9') {{ bind $ps '.%ORDER.%flow.payment_status'; format $info --append='(Error:' --append=$ps --append=')'; }};
if (is $info --blank) {{ bind $ps '.%ORDER.%flow.payment_status'; format $info --append='(Unknown:' --append=$ps --append=')'; }};

if ( is $paymentscount --gt=1 ) {{
	set $success false;
	if ( is $ps --eq=0 ) {{ set $success true; }};
	if ( is $ps --eq=1 ) {{ set $success true; }};
	if ( is $ps --eq=4 ) {{ set $success true; }};
	if ( is $success ) {{
		transmogrify --templateid='invoice_mixed_success' --dataset=$dataset;
		}}
	else {{
		transmogrify --templateid='invoice_mixed_failure' --dataset=$dataset;
		}};
	}};

foreach $payment in $payments {{
	export '%payment' --dataset=$payment;
	bind $voided '.%payment.voided';	
	bind $puuid '.%payment.puuid';
	bind $tender '.%payment.tender';
	bind $ps '.%payment.ps';
	set $pss $ps;
	format $pss --truncate=1;
	
	/* Depending on the type of payment method of the order, return pay instructions for that particular payment type. */
	set $paytemplateids '';
	format $paytemplateids --append='payment_' --append=$tender --append='_' --append=$ps; 	/* payment_tender_### */
	if (is $pss --eq='4') {{ set $pss '0'; }};	/* review is the same as 'paid' to the end user */
	if (is $pss --eq='0') {{ 
		format $paytemplateids --append=',' --append='payment_' --append=$tender --append='_success'; 
		format $paytemplateids --append=',' --append='payment_success';
		}};
	if (is $pss --eq='1') {{ 
		format $paytemplateids --append=',' --append='payment_' --append=$tender --append='_pending'; 
		format $paytemplateids --append=',' --append='payment_pending';
		}};
	if (is $pss --eq='2') {{ 
		format $paytemplateids --append=',' --append='payment_' --append=$tender --append='_denied'; 
		format $paytemplateids --append=',' --append='payment_denied';
		}};
	if (is $pss --eq='6') {{ 
		format $paytemplateids --append=',' --append='payment_' --append=$tender --append='_void'; 
		format $paytemplateids --append=',' --append='payment_void';
		}};
	if (is $pss --eq='5') {{ 
		format $paytemplateids --append=',' --append='payment_' --append=$tender --append='_processing'; 
		format $paytemplateids --append=',' --append='payment_processing';
		}};
	if (is $pss --eq='3') {{ 
		format $paytemplateids --append=',' --append='payment_' --append=$tender --append='_returned'; 
		format $paytemplateids --append=',' --append='payment_returned';
		}};
	if (is $pss --eq='9') {{ 
		format $paytemplateids --append=',' --append='payment_' --append=$ps --append='_error'; 
		format $paytemplateids --append=',' --append='payment_' --append=$tender --append='_error'; 
		format $paytemplateids --append=',' --append='payment_error';
		}};
		
	if (is $voided) {{ set $paytemplateids ''; }};	/* voided */
	if (is $puuid) {{ set $paytemplateids ''; }};	/* chained payment */
	if (is $paytemplateids --notblank) {{
		set $paytemplatearray $paytemplateids --split='\|';
		set $selectedtemplateid '';
		foreach $paytemplateid in $paytemplatearray {{
			if (is $selectedtemplateid --blank) {{
				if (is $paytemplateid --templateidexists) {{
					set $selectedtemplateid $paytemplateid;
					}};
				}};
			}};

		if (is $selectedtemplateid --notblank) {{
			
			/* acct is a pipe delimed, colon separated key value pairs, each key is two digits */
			set $accts $payment --path='.acct' --split='\|';
			foreach $acctkv in $accts {{
				set $key $keyvalue;	
				set $value $keyvalue;
				if (is $keyvalue --notblank) {{ 
					format $key --truncate=2; format $value --chop=3;
					set $exportstr '';
					format $exportstr --append='.%payment.acct-' --append=$key;
					export $exportstr --dataset=$value;
					}};				
				}};
			
			transmogrify --templateid=$selecteditemplateid --dataset=$dataset;
			apply --append;
			}};
		}};
	}};


/* REVIEW STATUS */
set $rs '.%ORDER.%flow.review_status';
format --truncate=1;		/* keep 'A' instead of 'AOK' */
set $rstemplateid '';
if (is $rs --notblank) {{ 
	if (is $rs --eq='A') {{ set $rstemplateid 'invoice_risk_approved'; }};
	if (is $rs --eq 'R') {{ set $rs 'E'; }};
	if (is $rs --eq 'E') {{ set $rstemplateid 'invoice_risk_review'; }};
	if (is $rs --eq 'D') {{ set $rstemplateid 'invoice_risk_decline'; }};
	}};

if (is $rstemplateid --notblank) {{
	apply --append='&lt;!-- ' --append=$rstemplateid --append=' --&gt;';
	transmogrify $rsout --templateid='invoice_risk_approved';
	apply --append=$rsout;
	apply --append='&lt;!-- /' --append=$rstemplateid --append=' --&gt;';
	}};

/* /REVIEW STATUS */

set $balancedue '.%ORDER.%sum.balance_due_total';
if (is $balancedue --gt=0) {{
	transmogrify --templateid='invoice_has_balancedue' --dataset=$dataset;
	apply --append;
	}};
set $paidate '.%ORDER.%flow.paid_ts';
if (is $paiddate --gt=0) {{
	transmogrify --templateid='invoice_is_paidinfull' --dataset=$dataset;
	}};
"></div>

<template id='payment_buy_success'>
<!-- payment_buy_success  --><p align="left">
We have received and processed the payment for the amount of: $%GRANDTOTAL%
The Buy.com Transaction ID (if available) is: <span data-tlc="bind $txn '.txn'; apply --append;"></span>
</p>
</template>

<template id='payment_cash_pending'>
<!-- Displayed when cash payment is waiting (usually this is only for point of sale) Checkout cash pending --><div align="left">
<p>You have chosen to pay by cash.  Please do not send cash by mail.
This payment should be made in person at our location:</p>
<b>%MYADDRESS%</b>
<p><i>we are not responsible for lost or stolen payments.</i></p>
</div>
</template>

<template id='payment_cash_success'>
<!-- Displayed when cash payment has been received (usually this is for point of sale). Checkout cash success --><div align="left">
<p>Your cash payment is appreciated.</p>
</template>

<template id='payment_check_pending'>
<!-- Pending Company Check Payment Message (EMAIL)  --><p>You must make the check for the amount $%GRANDTOTAL% payable to %PAYABLETO%.</p>

<p>To speed processing of the order, please print "Order Number %ORDERID%" in the memo of the check.</p>

<p>If payment is not received within 2 weeks, your order will be automatically cancelled.</p>
Please send the payment to the mailing address located on our website.

<p><i>we are not responsible for lost or stolen payments.</i></p>
			
</template>

<template id='payment_check_success'>
<!-- Checkout check success Displayed to customers who are paying by check (includes name, address, mailing instructions). -->
<div align="left"><p>You paid by check.  Thank you!</p></div>
</template>

<template id='payment_chkod_pending'>
<!-- Pending Check OD Payment Message (EMAIL)  -->
The check you will present upon delivery must be payable to %PAYABLETO%
made for the amount $%GRANDTOTAL%.

To speed processing of the order, please print "Order Number %ORDERID%"
in the memo of the check.
</template>

<template id='payment_chkod_success'>
<!-- Checkout Check on Delivery message Displayed to customers who have selected Check on Delivery. -->
<p align="left">You have chosen to pay by personal or company check on delivery.  
You must have the check for the amount <b>$%GRANDTOTAL%</b> ready when your delivery arrives, 
please contact us if you have any questions.
In the memo of the check please put "Order %ORDERID%".</p>
</template>

<template id='payment_cod_pending'>
<!-- Pending COD Payment Message (EMAIL)  -->
The cashier check or money order you will present upon delivery must be
payable to %PAYABLETO% for the amount $%GRANDTOTAL%.

To speed processing of the order, please print "Order Number %ORDERID%" in
the memo of the cashier check or money order.

</template>

<template id='payment_cod_success'>
<!-- Checkout COD message Displayed to customers who have selected COD. -->
<p align="left">You have chosen to pay by cashier's check or money order on delivery. 
You must have the cashier's check or money order for the amount <b>$%GRANDTOTAL%</b> ready when your delivery arrives, 
payable to <b>%PAYABLETO%</b>.  In the memo of the cashier's check or money order please put "Order %ORDERID%".</p>
</template>

<template id='payment_credit_denied'>
<!-- Denied Credit Card  payment  -->
<p>Your Credit Card payment has been denied.  If you do not have a customer account, please contact %MYEMAIL% for assistance.  
If you have an account, please login to your account to correct your payment</p>
</template>

<template id='payment_credit_failure'>
<!-- Credit card failed charge. Checkout credit charge failed (2xx and 3xx result codes) -->
<p align="left">There was a problem processing your order.  Please contact us by email or phone.</p>
<p align="left">%REASON%</p>
</template>

<template id='payment_credit_pending'>
<!-- Pending Credit Payment Message  -->
<p align="left">You have chosen to pay via Credit Card.  Your Credit Card payment is considered Pending and funds have not been released at this time.</p><br>
</template>

<template id='payment_credit_success'>
<!-- Credit card successfully charged message. Checkout credit charge success (0xx and 1xx result codes) -->
<p align="left">Thank you for your order!</p>
</template>

<template id='payment_custom_success'>
<!-- Checkout custom success message Displayed to customers who have selected the custom payment option for payment. -->
<p align="left">You have chosen to pay via a custom method.</p><br>
<p align="left">If you are the merchant, you really ought to configure this message to something other than it's default.</p>
</template>

<template id='payment_denied'>
<!-- Denied Payment Message (EMAIL)  -->
<p>Your payment has been denied.  Please login to your account to fix the payment.</p>
</template>

<template id='payment_ebay_success'>
<!-- payment_ebay_success  -->
<p align="left">
We have received and processed the payment for your eBay order for the amount of: $%GRANDTOTAL%
The eBay/Paypal Transaction ID (if available) is: %PAYMENT_TXN%
</p>
</template>

<template id='payment_echeck_pending'>
<!-- Checkout electronic checkout payment is pending (funds waiting transfer) Electronic check is pending. -->
<p align="left">Thank you for your order!</p>
</template>

<template id='payment_echeck_success'>
<!-- Checkout electronic check charge success Success message for electronic check processed. -->
<p align="left">Thank you for your order!</p>
</template>

<template id='payment_giftcard_pending'>
<!-- Pending Giftcard payment  -->
<p align="left">You have chosen to pay by use of Store Giftcard.  Your payment is considered Pending and your Giftcard has not been debited at this time.</p><br>
</template>

<template id='payment_giftcard_success'>
<!-- Credit card successfully charged message. Checkout giftcard success (0xx and 1xx result codes) -->
<p align="left">Thank you for your payment!</p>
</template>

<template id='payment_google_denied'>
<!-- Denied Google Checkout Payment Message (EMAIL)  -->
<p>Your Google Checkout payment has been denied.  Please click the link below to correct your payment:</p>
<a href="%PAYMENT_FIXNOWURL%">%PAYMENT_FIXNOWURL%</a>
</template>

<template id='payment_google_pending'>
<!-- Pending Google Checkout Payment Message (EMAIL)  -->
<p>You have chosen to pay via Google Checkout.  Your payment is considered Pending and funds have not been released at this time<p>
</template>

<template id='payment_layaway_pending'>
<!-- Pending Layaway Payment Message (EMAIL)  -->
<p>You have chosen to pay via Layaway.  Your payment is considered Pending and funds have not been released at this time<p>
</template>

<template id='payment_mixed_failure'>
<!-- Mixed Payment Method Failure Checkout credit charge success (non succes error codees) -->
<p align="left">Thank you for your order! Your order used more than one payment method, and experienced at least one failure. Please review below.</p>
</template>

<template id='payment_mixed_success'>
<!-- Mixed Payment successfully charged message. Checkout mixed payment success (0xx and 1xx result codes) -->
<p align="left">Thank you for your order! Your order used more than one payment method, below is a summary of each method.</p>
</template>

<template id='payment_mo_pending'>
<!-- Pending Cashiers Check Payment Message (EMAIL)  -->
<p>You should prepare a cashiers check or money order for the amount $%GRANDTOTAL% payable to %PAYABLETO%.</p>
<p>To speed processing of the order, please print "Order Number %ORDERID%" in the memo of the check.</p>
<p>If payment is not received within 2 weeks, your order will be automatically cancelled.</p>
<div>
Please send the payment to the mailing address located on our website.
</div>
<p><i>we are not responsible for lost or stolen payments.</i></p>
</template>

<template id='payment_mo_success'>
<!-- Displayed when a cashiers check or money order has been received. Checkout cash success -->
<div align="left"><p>Your cashiers check or money order payment was received.</p></div>
</template>

<template id='payment_other_pending'>
<!-- Other Pending Payment Message (EMAIL)  -->
<p>Thank you for your order.</p>
</template>

<template id='payment_paypalec_denied'>
<!-- Denied Paypal Express Checkout payment  -->
<p>The PayPal Express Checkout payment has been denied.  Please click the link below to correct your payment:</p>
<a href="%PAYMENT_FIXNOWURL%">%PAYMENT_FIXNOWURL%</a>
</template>

<template id='payment_paypalec_pending'>
<!-- Pending Paypal Express Checkout payment  -->
<p align="left">You have chosen to pay via PayPal Express Checkout.  Your payment is considered Pending and funds have not been released at this time.</p><br>
</template>

<template id='payment_paypalec_success'>
<!-- Successful Paypal Express Checkout payment  -->
<p align="left">Thank you for your PayPal Express Checkout payment. </p><br>
</template>

<template id='payment_pickup_pending'>
<!-- Checkout pickup pending Displayed to customers who are paying at pickup -->
<p align="left">You have chosen to pay upon pickup.  Thank you for your order, we look forward to seeing you!</p>
</template>

<template id='payment_pickup_success'>
<!-- Checkout pickup success Displayed to customers who are paying at pickup -->
<p align="left">Your order during pickup was received. Thank you!</p>
</template>

<template id='payment_po_pending'>
<!-- Checkout PO success message Thank you displayed to PO users after PO is put in. -->
<p align="left">You have chosen to pay by purchase order, 
we will ship your order once we have confirmed your available credit limit. 
If there is an issue we will contact you.</p>
</template>

<template id='payment_po_success'>
<!-- Checkout PO success message Thank you displayed to PO users after PO is put in. -->
<p align="left">Thank you for your order!</p>
</template>

<template id='payment_wire_pending'>
<!-- Pending Wire Transfer Message  -->
<p>You send a wire transfer for the amount $%GRANDTOTAL%.
Our account number is: [[PLEASE CONTACT US FOR ROUTING / ACCOUNT NUMBER]]
<p>To speed processing of the order, please print "Order Number %ORDERID%" in the memo of the transfer.</p>
<p>If payment is not received within 2 weeks, your order will be automatically cancelled.</p>
</template>

<template id='payment_wire_success'>
<!-- Checkout wire transfer message Displayed to customers who have selected wire transfer -->
Please contact us for wire transfer instructions.
</template>

</div>
|,
	#[ 'ORDER',
	'%TRACKINGINFO%'=> q|
<table>
<thead>
<tr>
	<th>Carrier</th>
	<th>Tracking#</th>
	<th>Notes</th>
</tr>
</thead>
<tbody data-tlc="
/* iterate through each shipment and apply it to the template 'shipmentTemplate', then append it to the document. */
bind $shipments '.@SHIPMENTS'; 
foreach $shipment in $shipments {{ transmogrify --templateid='shipmentTemplate' --dataset=$shipment; apply --append; }};
">
</tbody>
</table>

<template id="shipmentTemplate">
<tr>
	<td data-tlc="bind $carrier '.carrier'; apply --append;"></td>
	<td data-tlc="
bind $carrier '.carrier'; 
set $link '';

if (is $carrier --eq='U1DP') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='U1DA') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='U1DAS') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='U1DM') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='U1DMS') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='UGND') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='U2DA') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='U2DAS') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='U2DM') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='U3DS') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='USTD') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='UXPR') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='UXDM') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='UXPD') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='UXSV') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='UPMI') {{ set $carrier 'UPS'; }};
if (is $carrier --eq='UPS') {{ 
	set $link 'http://wwwapps.ups.com/etracking/tracking.cgi?TypeOfInquiryNumber=T&InquiryNumber1=';
	}};

if (is $carrier --eq='FEDEX') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FDX') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FDXG') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FXGR') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FXHD') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FXHE') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FXES') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FXSO') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FXPO') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FXFO') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FXIP') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FXIG') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FXIF') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FXIE') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FX2D') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FX2A') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FXSP') {{ set $carrier 'FEDX'; }};
if (is $carrier --eq='FEDX') {{ 
	set $link 'https://www.fedex.com/Tracking?action=track&language=english&template_type=plugin&ascend_header=1&cntry_code=us&initial=x&mps=y&tracknumbers=';
	}};

if (is $carrier --eq='EFCM') {{ set $carrier 'USPS'; }};
if (is $carrier --eq='EPRI') {{ set $carrier 'USPS'; }};
if (is $carrier --eq='ESPP') {{ set $carrier 'USPS'; }};
if (is $carrier --eq='ESMM') {{ set $carrier 'USPS'; }};
if (is $carrier --eq='ESLB') {{ set $carrier 'USPS'; }};
if (is $carrier --eq='ESBM') {{ set $carrier 'USPS'; }};
if (is $carrier --eq='EXPR') {{ set $carrier 'USPS'; }};
if (is $carrier --eq='EPFC') {{ set $carrier 'USPS'; }};
if (is $carrier --eq='EPFC') {{ set $carrier 'USPS'; }};
if (is $carrier --eq='EIFC') {{ set $carrier 'USPS'; }};
if (is $carrier --eq='EIEM') {{ set $carrier 'USPS'; }};
if (is $carrier --eq='EIPM') {{ set $carrier 'USPS'; }};
if (is $carrier --eq='EGEG') {{ set $carrier 'USPS'; }};
if (is $carrier --eq='EGGN') {{ set $carrier 'USPS'; }};
if (is $carrier --eq='USPS') {{
	set $link 'http://trkcnfrm1.smi.usps.com/PTSInternetWeb/InterLabelInquiry.do?CAMEFROM=OK&origTrackNum=';
	}};
/* sanity: at this point if $link is set, we should append the tracking # */
bind $track '.track'; 
if (is $link --notblank) {{
	format $link --append=$track;
	format $link --prepend='&lt;a href=&quot;' --append='&quot;&gt;' --append=$track --append='&lt;/a&gt;';
	apply --append=$link;
	}}
else {{
	apply --append=$track;
	}};
"></td>
	<td data-tlc="
bind $var '.created'; datetime $var --epoch --out='mdy'; format --prepend='shipped: ' --crlf; apply --append; 
bind $var '.notes'; apply --append;
"></td>
</tr>
</template>
|,	
	#[ 'ORDER',
	'%ORDERDATE%'=> q|<div data-tlc="bind $var '.%ORDER.%our.order_ts'; datetime --gmt=$var --out='pretty'; apply --append;"></div>|,
	'%TODAY%'=> q|<div data-tlc="datetime --now --out='ymd'; apply --append;"></div>|,
	'%FULLNAME%'=> q|
<span data-tlc="bind $var '.%CUSTOMER.INFO.FIRSTNAME'; apply --replace;"></span>
<span data-tlc="bind $var '.%CUSTOMER.INFO.LASTNAME'; apply --replace;"></span>|,
##	[ 'ACCOUNT',
	'%FIRSTNAME%'=> q|<span data-tlc="bind $var '.%CUSTOMER.INFO.FIRSTNAME'; apply --replace;"></span>|,
##	[ 'ACCOUNT',
	'%LASTNAME%'=> q|<span data-tlc="bind $var '.%CUSTOMER.INFO.LASTNAME'; apply --replace;"></span>|,
##	[ 'ACCOUNT',
##	[ 'ACCOUNT',
	'%REWARD_BALANCE%'=> q|<span data-tlc="bind $var '.%CUSTOMER.INFO.REWARD_BALANCE'; apply --replace;"></span>|,
##	[ 'ACCOUNT',
	'%CUSTOMER_USERNAME%'=> q|<span data-tlc="bind $var '.%CUSTOMER.INFO.EMAIL'; apply --replace;"></span>|,
	'%CUSTOMER_INITPASS%'=> q|<span data-tlc="bind $var '.%CUSTOMER.INFO.PASSWORD'; apply --replace;"></span>|,
	'%CUSTOMER_UNSUBSCRIBE%' => q|<span data-tlc="bind '.%PRT.DOMAIN'; format --prepend='http://'; apply --attrib='href'; apply --append;"></span>|,
	'%REMOTEIPADDRESS%'=> q|<span data-tlc="bind $ip '.%ENV.REMOTE_ADDR'; format --default='unknown'; apply --replace;"></span>|,
##	[ 'CUSTOMER',
	'%ADDITIONAL_TEXT%'=> q||,
##	[ 'CUSTOMER',
	'%GIFTCARDS%'=> q|
<table>
<thead>
</thead>
<tbody data-tlc="
bind $giftcards '.%CUSTOMER.@GIFTCARDS'; foreach $giftcard in $giftcards {{	transmogrify --templateid='giftcardrow' --dataset=$giftcard;	apply --append;	}};">
<template id="giftcardrow">
	<tr>
		<td data-tlc="bind $code '.CODE'; apply --append;"></td>
		<td data-tlc="bind $code '.BALANCE'; format --currency; apply --append;"></td>
		<td data-tlc="bind $expires '.EXPIRES_GMT'; datetime $expires --epoch --out='mdy'; apply --append;"></td>
		<td data-tlc="bind $expires '.NOTE'; apply --append;"></td>
	</tr>
</template>
</tbody>
</table>
|,
	);









$BLAST::DEFAULTS::MACROS{'%PASSWORD%'} = $BLAST::DEFAULTS::MACROS{'%CUSTOMER_INITPASS%'};
$BLAST::DEFAULTS::MACROS{'%HTMLPACKSLIP%'} = $BLAST::DEFAULTS::MACROS{'%PACKSLIP%'};
$BLAST::DEFAULTS::MACROS{'%HTMLBILLADDR%'} = $BLAST::DEFAULTS::MACROS{'%BILLADDR%'};
$BLAST::DEFAULTS::MACROS{'%HTMLSHIPADDR%'} = $BLAST::DEFAULTS::MACROS{'%SHIPADDR%'};
$BLAST::DEFAULTS::MACROS{'%HTMLPAYINSTRUCTIONS%'} = $BLAST::DEFAULTS::MACROS{'%PAYINSTRUCTIONS%'};
$BLAST::DEFAULTS::MACROS{'%HTMLTRACKINGINFO%'} = $BLAST::DEFAULTS::MACROS{'%TRACKINGINFO%'};
$BLAST::DEFAULTS::MACROS{'%ORDERFEEDBACK%'} = $BLAST::DEFAULTS::MACROS{'%LINKORDER%'};
$BLAST::DEFAULTS::MACROS{'%CONTENTS%'} = $BLAST::DEFAULTS::MACROS{'%ORDERITEMS%'};
$BLAST::DEFAULTS::MACROS{'%NAME%'} = $BLAST::DEFAULTS::MACROS{'%FULLNAME%'};
$BLAST::DEFAULTS::MACROS{'%DATE%'} = $BLAST::DEFAULTS::MACROS{'%ORDERDATE%'};
$BLAST::DEFAULTS::MACROS{'%IPADDRESS%'} = $BLAST::DEFAULTS::MACROS{'%REMOTEIPADDRESS%'};



##
##
##
##
%BLAST::DEFAULTS::MSGS = (
	'PRINTABLE.INVOICE'=>{
		MSGFORMAT=>'HTML',
		MSGOBJECT=>'ORDER',
		MSGSUBJECT=>'Printable Invoice',
		MSGBODY=>q|
<h1>Order Number: %ORDERID%</h1>
Created: %ORDERDATE%

<table>
<thead>
<tr>
	<td>Billing Address</td>
	<td>Shipping Address</td>
</tr>
</thead>
<tbody>
<tr>
	<td>%BILLADDR%</td>
	<td>%SHIPADDR%</td>
</tr>
</tbody>
</table>

<h2>Order Contents</h2>
%ORDERITEMS%

<h3>Shipping Method</h3>
%SHIPMETHOD%

<h3>Payment Information</h3>
%PAYINFO%

<h3>Payment Instructions</h3>
%PAYINSTRUCTIONS%
|,
		},
	'PRINTABLE.PACKSLIP'=>{
		'MSGFORMAT'=>'HTML',
		'MSGOBJECT'=>'ORDER',
		'MSGSUBJECT'=>'Printable Packing Slip',
		'MSGBODY'=>q|
<h1>Order Number: %ORDERID%</h1>
Created: %ORDERDATE%

<table>
<thead>
<tr>
	<td>Billing Address</td>
	<td>Shipping Address</td>
</tr>
</thead>
<tbody>
<tr>
	<td>%BILLADDR%</td>
	<td>%SHIPADDR%</td>
</tr>
</tbody>
</table>

<h2>Order Contents</h2>
%PACKSLIP%

<h3>Shipping Method</h3>
%SHIPMETHOD%
|
		},
	'PRINTABLE.PICKLIST'=>{
		'MSGFORMAT'=>'HTML',
		'MSGOBJECT'=>'ORDER',
		'MSGSUBJECT'=>'Printable Pick Slip',
		'MSGBODY'=>q|
Coming soon!
|
		},
	'BLANK'=>{
		MSGBODY=>'',MSGTITLE=>'',MSGOBJECT=>'',
		},
	'ORDER.NOTE'=>{
		MSGFORMAT=>'TEXT',
		MSGOBJECT=>'ORDER',
		MSGSUBJECT=>'Order %ORDERID%',
		MSGBODY=>'%BODY%',
		},
	'ORDER.ARRIVED.EBF'=>{
		MSGFORMAT=>'TEXT',
		MSGOBJECT=>'ORDER',
		MSGTITLE=>'Order Arrived: eBay Follow Up',
		MSGSUBJECT=>'Your eBay order has arrived - please leave us feedback',
		MSGBODY=>q~
%HEADER%
Based on the shipment date, and the method we shipped your package - 
your order should have arrived, if you have not received it please contact us.

We appreciate your business and ask that you take a moment of your busy schedule to rate us.  
Please give us 5 out of 5 in all categories, unless you feel we do not
deserve that score - in which case we'd greatly appreciate your feedback as to how we could have improved.  

By giving us 5 out of 5 you are ensuring that we'll continue to bring 
you the best possible service at the most competitive prices!
%FOOTER%
~,
		},
	'ORDER.ARRIVED.BUY'=>{
		MSGFORMAT=>'TEXT',
		MSGOBJECT=>'ORDER',
		MSGTITLE=>'Order Arrived: Buy.com Follow Up',
		MSGSUBJECT=>'Your Buy.com order has arrived!',
		MSGBODY=>q~

Based on the shipment date, and the method we shipped your package - 
your order should have arrived, if you have not received it please contact us.

We appreciate your business and ask that you take a moment of your busy schedule to rate us on Buy.com.  
Please give us the highest possible score in all categories, unless you feel we do not deserve that score - in which case we'd greatly appreciate your feedback as to how 
we could have improved.  
Please take a moment to review your order on our website:

%LINKORDER%

By giving us a good rating you are ensuring that we'll continue to bring you the best possible service at the most competitive prices!
~,
		},
	'ORDER.ARRIVED.AMZ'=>{
		MSGFORMAT=>'TEXT',
		MSGOBJECT=>'ORDER',
		MSGTITLE=>'Order Arrived: Amazon Follow Up',
		MSGSUBJECT=>'Your Amazon order has arrived - please leave us feedback',
		MSGBODY=>q~
Based on the shipment date, and the method we shipped your package - 
your order should have arrived, if you have not received it please contact us.
Contact Amazon Customer Service:
http://www.amazon.com/gp/help/contact-us/general-questions.html?orderId=%AMAZON_ORDERID%

We appreciate your business and ask that you take a moment of your busy schedule to rate us.  Please give us 5 out of 5 in all categories, unless you feel we do not
deserve that score - in which case we'd greatly appreciate your feedback as to how we could have improved.  

By giving us 5 out of 5 you are ensuring that we'll continue to bring you the best possible service at the most competitive prices!

Leave Seller Feedback!!!
http://www.amazon.com/gp/feedback/leave-customer-feedback.html?order=%AMAZON_ORDERID%
~,
		},
	'ORDER.ARRIVED.WEB'=>{
		MSGFORMAT=>'TEXT',
		MSGOBJECT=>'ORDER',
		MSGTITLE=>'Order Arrived: Website Follow Up',
		MSGSUBJECT=>'Your order has arrived - please leave us feedback',
		MSGBODY=>q~
%HEADER%
Based on the shipment date, and the method we shipped your package - 
your order should have arrived, if you have not received it please contact us.

Hopefully by now you've opened the package and had a bit of time with the product. 
Please take a moment to review your order on our website:

%LINKORDER%

Reviews help us continue to deliver a great online shopping experience for customers just like you.
%FOOTER%
~,
		},

		'ORDER.MERGED'=>{
			MSGOBJECT=>'ORDER',
			MSGFORMAT=>'HTML',
			MSGSUBJECT=>'Your order has been merged',
			MSGBODY=>q~
%HEADER%

Hi %FULLNAME%,

This is a notification of a recent order consolidation.
The resulting order number is %ORDERID%.

There is no need to reply to this email if everything is correct with your order.

Contact Email: %SUPPORTEMAIL%

Combined Order Contents: 
%ORDERITEMS%

If you have any questions or concerns please contact us immediately. Thank You!

%FOOTER%
~,
			},
		'ORDER.SPLIT'=>{
			MSGOBJECT=>'ORDER',
			MSGFORMAT=>'HTML',
			MSGSUBJECT=>'Changes to your order',
			MSGBODY=>q~
%HEADER%

Hi %FULLNAME%,

This is a notification that your #%ORDERID% has been split into
two pieces, and a new order id #%SPLITID% has been created.

<h2>Contents of #%ORDERID%</h2>
%PACKSLIP%

<h2>Contents of #<span data-tlc="bind $var '.%SPLIT.%our.orderid'; apply --append;"></span></h2>
<table id="contents" data-tlc="bind $items '.%SPLIT.@ITEMS'; foreach $item in $items {{ transmogrify --templateid='skuTemplate' --dataset=$item; apply --append; }}; ">
<thead>
<tr>
	<th>QTY</th>
	<th>SKU</th>
	<th>DESC</th>
</tr>
</thead>
<tbody>
<template id="skuTemplate">
<tr>
	<td data-tlc="bind $var '.qty'; if (is $var --notblank) {{ apply --append;}};"></td>
	<td data-tlc="bind $var '.sku'; apply --append;"></td>
	<td data-tlc="bind $var '.prod_name'; if (is $var --notblank) {{apply --append;}};"></td>
</tr>
</template>
</tbody>
</table>

There is no need to reply to this email if everything is correct.<br>

If not please contact us immediately at <a href="mailto:%SUPPORTEMAIL%">%SUPPORTEMAIL%</a><br>
Thank You.

%FOOTER%
~,
			},
		'ORDER.SHIPPED' => {
			MSGOBJECT=>'ORDER',
			MSGFORMAT=>'HTML',
			MSGSUBJECT=>'Order %ORDERID% shipped',
			MSGBODY=>q~
%HEADER%
An item from your %ORDERID% has been shipped. 
The tracking numbers (if available) appear below:

%TRACKINGINFO%

%FOOTER%
~,
			},
		'ORDER.SHIPPED.EBAY'=>{
			MSGOBJECT=>'ORDER',
			MSGFORMAT=>'TEXT',
			MSGSUBJECT=>'Your order has been shipped.',
			MSGBODY=>q~
Your order has been shipped.  
If available the tracking numbers will appear below:
%TRACKINGINFO%

To see the tracking status for this order, or to contact us with any
questions please visit or website, or download our app:
%LINKORDER%

We strive to deliver a professional customer experience, if you have any concerns
please do not hestitate to contact us.

We request that you please provide us with 5 stars on the eBay feedback survey.  
This will help us to move higher in the eBay rankings and continue to provide the 
best customer service possible.

Thank you!
~,
			MAXLENGTH=>3500,
			},
		'ORDER.SHIPPED.AMZ'=>{
			MSGOBJECT=>'ORDER',
			MSGFORMAT=>'HTML',
			MSGTITLE=>q~Amazon Feedback Request~,
			HINT=>q~This message is usually generated from an event.~,
			MSGSUBJECT=>q~Amazon Feedback Request~,
			MSGBODY=>q~
Hi %FIRSTNAME%,
Thank you for your order, we hope it has arrived intact. 
We would appreciate if you would take a few moments from your busy day
to go and leave us feedback on Amazon.~,		
			},
		'ORDER.MOVE.RECENT' => {
			MSGOBJECT=>'ORDER',
			MSGFORMAT=>'HTML',
			MSGSUBJECT=>'Order %ORDERID% moved to Recent',
			MSGBODY=>q~Your order has been moved back to recent status.~,
			},
		'ORDER.MOVE.APPROVED' => {
			MSGOBJECT=>'ORDER',
			MSGFORMAT=>'HTML',
			MSGSUBJECT=>'Order %ORDERID% Approved',
			MSGBODY=>q~Your order has been approved and should ship shortly.~,
			},
		'ORDER.MOVE.PENDING' => {
			MSGOBJECT=>'ORDER',
			MSGFORMAT=>'HTML',
			MSGSUBJECT=>'Order %ORDERID% Pending',
			MSGBODY=>q~Your order is currently pending, and may require additional interaction by you.~,
			},
		'ORDER.MOVE.BACKORDER' => {
			MSGOBJECT=>'ORDER',
			MSGFORMAT=>'HTML',
			MSGSUBJECT=>'Order %ORDERID% Backordered',
			MSGBODY=>q~Your order %ORDERID% has been placed into "Back order" status because one or
more items is not in-stock. You will be notified when the information becomes available.~,
			},
		'ORDER.MOVE.PREORDER' => {
			MSGOBJECT=>'ORDER',
			MSGFORMAT=>'HTML',
			MSGSUBJECT=>'Order %ORDERID% Preordered',
			MSGBODY=>q~Your order %ORDERID% has been placed into "Preorder" status. 
You will be notified when information becomes available.~,
			},
		'ORDER.MOVE.CANCEL' => {
			MSGOBJECT=>'ORDER',
			MSGFORMAT=>'HTML',
			MSGSUBJECT=>'Order %ORDERID% Cancelled',
			MSGBODY=>q~Your order %ORDERID% has been cancelled.~,
			},
		'ORDER.MOVE.PROCESSING' => {
			MSGOBJECT=>'ORDER',
			MSGFORMAT=>'HTML',
			MSGSUBJECT=>'Order %ORDERID% Processing',
			MSGBODY=>q~Your order is currently being processed.~,
			},
		'ORDER.MOVE.COMPLETED' => {
			MSGOBJECT=>'ORDER',
			MSGFORMAT=>'HTML',
			MSGSUBJECT=>'Order %ORDERID% shipped',
			MSGBODY=>q~Your order %ORDERID% has been shipped. 
The tracking numbers (if available) appear below:

%TRACKINGINFO%
~,
			},
	'ORDER.FEEDBACK.EBAY'=>{
		MSGOBJECT=>'ORDER',
		MSGFORMAT=>'HTML',
		MSGTITLE=>'eBay Positive Feedback Request',
		MSGSUBJECT=>q~eBay Feedback~,
		MSGBODY=>q~
Hello,

Thank you for your purchase!
We appreciate your patronage, and have left you feedback.

We hope you had a pleasant purchasing experience, and we hope you'll remember us for your next purchase.

We hope to serve you in the future.
Customer support is very important to us. If you have any questions or comments.

Thank You!
~,
		},

	'ORDER.CONFIRM'=>{ 	# OCREATE
		MSGOBJECT=>'ORDER',
		MSGFORMAT=>'HTML',
		MSGTITLE=>q~Order Created~,
		MSGSUBJECT=>q~Order %ORDERID% Created~,
		MSGBODY=>q~
%HEADER%
		
Hello %NAME%,


Thank you for placing order %ORDERID%.

We appreciate your business. 
If you need to contact us please make sure to include the following order number:

<h1>Order Number: %ORDERID%</h1>
Created: %ORDERDATE%

<table>
<thead>
<tr>
	<td>Billing Address</td>
	<td>Shipping Address</td>
</tr>
</thead>
<tbody>
<tr>
	<td>%BILLADDR%</td>
	<td>%SHIPADDR%</td>
</tr>
</tbody>
</table>

<h2>Order Contents</h2>
%ORDERITEMS%

<h3>Shipping Method</h3>
%SHIPMETHOD%

<h3>Payment Information</h3>
%PAYINFO%

<h3>Payment Instructions</h3>
%PAYINSTRUCTIONS%

Please visit %LINKORDER% to check status on this order.

Customer support is very important to us. If you have any questions or comments please contact us.
%LINKEMAIL%
%LINKPHONE%. 

%FOOTER%
~,
		},


	'ORDER.CONFIRM_DENIED'=>{ # ODENIED
		MSGOBJECT=>'ORDER',
		MSGFORMAT=>'HTML',
		MSGTITLE=>q~Order Payment Denied~,
		MSGSUBJECT=>q~Order %ORDERID% requires assistance~,
		MSGBODY=>q~
%HEADER%

Hello %FULLNAME%,

Unfortunately there was a problem processing your order %ORDERID%.

<h2>Payment Instructions</h2>
%PAYINSTRUCTIONS%

Customer support is very important to us. If you have any questions or comments,  please contact us.
%LINKEMAIL%
%LINKPHONE%

<h2>Order Details: %ORDERID%</h2>
Created: %ORDERDATE%

<table>
<thead>
<tr>
	<td>Billing Address</td>
	<td>Shipping Address</td>
</tr>
</thead>
<tbody>
<tr>
	<td>%BILLADDR%</td>
	<td>%SHIPADDR%</td>
</tr>
</tbody>
</table>

<h2>Order Contents</h2>
%ORDERITEMS%

<h2>Shipping Method</h2>
%SHIPMETHOD%

<h2>Payment Information</h2>
%PAYINFO%

%FOOTER%
~,
		},

	'ORDER.PAYMENT_REMINDER'=>{   # PAYREMIND
		MSGFORMAT=>'HTML',
		MSGOBJECT=>'ORDER',
		MSGTITLE=>q~Payment Reminder~,
		MSGSUBJECT=>q~Payment Reminder for Order %ORDERID%~,
		MSGBODY=>q~
%HEADER%

Hello %FIRSTNAME%, thank you for placing order %ORDERID%.
We appreciate your business, however we have not received payment 
for your order which was created on %ORDERDATE%. If you believe this is an error please contact us at:
%LINKDOMAIN%

Please follow the payment instructions below to remit payment as soon as possible.

<h2>Order Contents</h2>
%ORDERITEMS%

<h2>Shipping Method</h2>
%SHIPMETHOD%

<hr>
Please visit %LINKDOMAIN% to check status on this order.

Customer support is very important to us. If you have any questions or comments, please contact us.
%LINKPHONE%
%LINKEMAIL%

%FOOTER%
~,		
		},
	'CUSTOMER.GIFTCARD.REMINDER'=>{	# AGIFT_RTRY
		MSGOBJECT=>'ACCOUNT',
		MSGFORMAT=>'HTML',
		MSGTITLE=>q~Customer GiftCard Reminder~,
		MSGSUBJECT=>q~gift card reminder~,
		MSGBODY=>q~
%HEADER%

Hi %FIRSTNAME%,

%ADDITIONAL_TEXT%

This is a friendly reminder that you have the following giftcards available
to you:

%GIFTCARDS%

%FOOTER%
~,
		},
	'CUSTOMER.GIFTCARD.RECEIVED'=>{	# AGIFT_NEW
		MSGOBJECT=>'ACCOUNT',
		MSGFORMAT=>'HTML',
		MSGTITLE=>q~Customer New GiftCard Notification~,
		MSGSUBJECT=>q~gift card notification~,
		MSGBODY=>q~
%HEADER%

Hi %FIRSTNAME%,

%ADDITIONAL_TEXT%

You have the following giftcards available to you:

%GIFTCARDS%

TO USE THIS CARD:
Please visit our website, place an item in the shopping cart, 
then provide the code in the Giftcard box during checkout.

IF YOU LOSE THIS EMAIL:
Login to your customer account at our website and click on 
the gift card code.  If you have not setup an account then
we have already created one and you will need to recover the
password.

%FOOTER%
~,
		},
	'CUSTOMER.SIGNUP'=>{		# ASIGNUP
		MSGOBJECT=>'ACCOUNT',
		MSGFORMAT=>'HTML',
		MSGTITLE=>q~Customer Account Signup~,
		MSGSUBJECT=>q~Account Information~,
		MSGBODY=>q~
%HEADER%

Welcome!

If you wish to unsubscribe from our newsletter please visit
%LINKDOMAIN%

%FOOTER%
~,
		},
	'CUSTOMER.CREATED'=>{ 	# ACREATE
		MSGOBJECT=>'ACCOUNT',
		MSGFORMAT=>'HTML',
		MSGTITLE=>q~Customer Account Created~,
		MSGSUBJECT=>q~Account information~,
		MSGBODY=>q~
%HEADER%

Welcome %FIRSTNAME%!

A password for your account has been automatically generated.
Your password is: %CUSTOMER_INITPASS%

To login to your account and check the status of orders, or to make sure
our records have your most current contact information please our website.

Customer support is very important to us. 
If you have any questions or comments, please contact us.
We can also be reached through our website.

%FOOTER%
~,		
		},
	'CUSTOMER.PASSWORD.REQUEST'=>{  # PREQUEST
		MSGOBJECT=>'ACCOUNT',
		MSGFORMAT=>'HTML',
		MSGTITLE=>q~Password Request~,
		MSGSUBJECT=>q~Account information~,
		MSGBODY=>q~
%HEADER%

Hello!

You (or someone who thinks they're you) has requested that your password be sent to this email address.

Your username is %CUSTOMER_USERNAME%
Your password is %CUSTOMER_INITPASS%


=Security info=
Password request originated from IP address %REMOTEIPADDRESS%

Customer support is very important to us. 
If you have any questions or comments, please contact us.
%LINKDOMAIN%
%LINKEMAIL%
%LINKPHONE%

%FOOTER%
~,		
		},
	'TICKET.CREATED'=>{
		MSGOBJECT=>'TICKET',
		MSGFORMAT=>'HTML',
		MSGTITLE=>q~Ticket Created~,
		HINT=>q~This messagee is sent to a customer when a ticket is created.~,
		MSGSUBJECT=>q~Ticket %TKTCODE%: %TKTSUBJECT%~,
		MSGBODY=>q~
%HEADER%

This is to inform you that ticket %TKTCODE% has been created regarding:
%TKTSUBJECT%

To manage or update this ticket please use the URL below:
%TKTURL%

%FOOTER%
		~,
		},
	'TICKET.REPLY'=>{
		MSGOBJECT=>'TICKET',
		MSGFORMAT=>'HTML',
		MSGTITLE=>q~Ticket Ask Question~,
		HINT=>q~This email is sent to a customer when a response is requested.~,
		MSGSUBJECT=>q~Ticket %TKTCODE%: %TKTSUBJECT%~,
		MSGBODY=>q~
%HEADER%

Subject: %TKTSUBJECT%
This is to inform you that ticket %TKTCODE% is awaiting your response.

To manage or update this ticket please use the URL below:
%TKTURL%

%FOOTER%
		~,
		},
	'TICKET.CLOSED'=>{
		MSGOBJECT=>'TICKET',
		MSGFORMAT=>'HTML',
		MSGTITLE=>q~Ticket Closed~,
		HINT=>q~This email is sent to a customer when a ticket is closed.~,
		MSGSUBJECT=>q~Ticket %TKTCODE%: %TKTSUBJECT%~,
		MSGBODY=>q~
%HEADER%

Subject: %TKTSUBJECT%
This is to inform you that ticket %TKTCODE% has been closed.

To manage or update this ticket please use the URL below:
%TKTURL%

%FOOTER%
		~,
		},
	'ACCOUNT.SUBSCRIBE'=>{
		MSGOBJECT=>'ACCOUNT',
		MSGFORMAT=>'HTML',
		MSGTITLE=>q~Newsletter Subscribe~,
		HINT=>q~<b>This email is sent to a customer to thank them for joining your mailing list:</b><br>~,
		MSGSUBJECT=>q~Account information~,
		MSGBODY=>q~
%HEADER%

Welcome! Thank you for signing up for our mailing list.

A password for your account has been automatically generated.

Login/Username: %CUSTOMER_USERNAME%
Password: %CUSTOMER_INITPASS%

To unsubscribe from our mailing list please
%CUSTOMER_UNSUBSCRIBE%

Customer support is very important to us. 
If you have any questions or comments, please contact us.
%LINKDOMAIN%
%LINKEMAIL%
%LINKPHONE%

%FOOTER%
~,		
		},


	'PRODUCT.INSTOCK'=>{
		MSGOBJECT=>'PRODUCT',
		MSGFORMAT=>'HTML',
		MSGTITLE=>'Product instock notification (to customer)',
		MSGSUBJECT=>q~%PRODUCT_TITLE% now in stock~,
		MSGBODY=>q~
%HEADER%

The product %PRODUCT_ID%: 
%PRODUCT_ID% is now available for purchase.

%PRODUCT_IMAGE%

Price: %PRODUCT_PRICE%

%PRODUCT_ADDLINK%

To purchase please visit: 
%PRODUCT_VIEWLINK%

%FOOTER%
~,
		},

	'PRODUCT.SHARE'=>{
		MSGTITLE=>q~Tell A Friend Email~,
		MSGOBJECT=>'PRODUCT',
		MSGFORMAT=>'HTML',
		MSGSUBJECT=>q~Msg. from %SENDER_NAME% RE: %PROD_NAME%~,
		MSGBODY=>q~
%HEADER%

<table cellspacing=0 cellpadding=2 border=0 width="100%">
<tr>
   <td valign=top width="1%">
	%PRODUCT_IMAGE%
	%PRODUCT_LINK%
	</td>

   <td align="left">
	<p style="font-family: arial; font-size: 10pt; font-weight: bold;">%SENDER_SUBJECT%</p>
	<p>%SENDER_BODY%</p>
<p><strong>%PRODUCT_TITLE%</strong><br>
%PROD_DESC%</p>
<p><strong>Price: </strong>%PRODUCT_PRICE%</p>

%PRODUCT_ADDLINK%

</td>
</tr></table>

%FOOTER%

~,		
		},
	);





1;
