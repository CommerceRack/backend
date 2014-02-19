package SITE::EMAILS;

use Storable;
use strict;
use Data::Dumper;

use lib "/backend/lib";
require SITE;
require ZOOVY;
require PRODUCT;
require ZTOOLKIT;
require ZSHIP;
require DBINFO;
require CART2;

##
## remember: CUSTOMER and ORDER will also appear in TICKET emails!
##
@SITE::EMAILS::MACRO_HELP = (
	[ 'TICKET', '%TKTCODE%', 'Ticket Identifier' ],
	[ 'TICKET', '%TKTSUBJECT%', 'Ticket Subject' ],
	[ 'TICKET', '%CUSTOMER_URL%', 'Customer URL' ],
	[ 'PRODUCT', '%PROD_IMAGE_TAG%', 'a 200x200 version of an image (can be overidden)' ],
	[ 'PRODUCT', '%PRODUCTID%', 'Product ID' ],
	[ 'PRODUCT', '%SENDER_NAME%', 'The name of the person who sent the email (cgi variable: sender_name)' ],
	[ 'PRODUCT', '%SENDER_SUBJECT%', 'The subject that was supplied by the user (cgi variable: sender_subject)' ],
	[ 'PRODUCT', '%SENDER_BODY%', 'The body that was supplied by the user (cgi variable sender_body)' ],
	[ 'ORDER', '%ORDERID%', 'The Order ID number as assigned by Zoovy' ],
	[ 'ORDER', '%CARTID%', 'The cart id (session id) that the order was generated from - used for soft authentication' ],
	[ 'ORDER', '%EREFID%', 'The external reference id that the order was generated from - used for soft authentication' ],
	[ 'ORDER', '%EMAIL%', 'The billing email address for the customer' ],
	[ 'ORDER', '%ORDERURL%', 'A fully qualified URL (with http://) that will allow any user receiving the email to access the order status.'],
	[ 'ORDER', '%ORDERFEEDBACK%', 'A fully qualified URL (with http://) that will allow any user receiving the email to access the order feedback page.'],
	[ 'ORDER', '%CONTENTS%', 'A formatted list of the contents of the order with prices' ],
	[ 'ORDER', '%PACKSLIP%', 'A formatted list of the contents of the order without prices' ],
	[ 'ORDER', '%ORDERNOTES%', 'The order notes as entered by the customer' ],
	[ 'ORDER', '%SHIPADDR%', 'A multiline statement of the shipping address' ],
	[ 'ORDER', '%BILLADDR%', 'A multiline statement of the billing address' ],
	[ 'ORDER', '%SHIPMETHOD%', 'The shipping method and price' ],
	[ 'ORDER', '%PAYINFO%', 'Payment Type (eg: Paypal, credit card, etc.)' ],
	[ 'ORDER', '%PAYINSTRUCTIONS%', 'Payment Instructions (specific to the payment type)' ],
	[ 'ORDER', '%HTMLPAYINSTRUCTIONS%', 'Payment Instructions (specific to the payment type) - includes HTML for clickable links for use in HTML messages' ],
	[ 'ORDER', '%HTMLPACKSLIP%', q~
		An HTML formatted packing slip table (contains the same data as the plaintext &#37;PACKSLIP&#37; just intended for HTML messages).<br>
		The table includes the following style sheet elements which can be customized and tuned by you:<br>
			<table>
				<tr><td>table.packslip</td><td>the body of the table</td></tr>
				<tr><td>td.title</td><td> used for each cell in the title</td></tr>
				<tr><td>td.item1</td><td> this covers all the cells in the odd rows in the table.</td></tr>
				<tr><td>td.item0</td><td> this covers all the cells in even rows in the table.</td></tr>
			</table>
		~],
	[ 'ORDER', '%HTMLBILLADDR%', q~
		An HTML formatted billing address table (contains the same data as the plaintext &#37;BILLADDR&#37; just intended for HTML messages).<br>
		The table includes the following style sheet elements which can be customized and tuned by you:<br>
			<table>
				<tr><td>table.billaddr</td><td>the body of the table</td></tr>
				<tr><td>td.bill_fullname</td><td> the billing name (always on the first line)</td></tr>
				<tr><td>td.bill_company</td><td> the company name (always on the second line)</td></tr>
				<tr><td>td.bill_address</td><td> the address (always on the third line, multiple lines are separated by &lt;br&gt;'s)</td></tr>
				<tr><td>td.bill_phone</td><td> the phone (if available)</td></tr>
			</table>
	~],
	[ 'ORDER', '%HTMLSHIPADDR%', q~
		An HTML formatted shipping address table (contains the same data as the plaintext &#37;SHIPADDR&#37; just intended for HTML messages).<br>
		The table includes the following style sheet elements which can be customized and tuned by you:<br>
			<table>
				<tr><td>table.shipaddr</td><td>the body of the table</td></tr>
				<tr><td>td.ship_fullname</td><td> the shipping name (always on the first line)</td></tr>
				<tr><td>td.ship_company</td><td> the company name (always on the second line)</td></tr>
				<tr><td>td.ship_address</td><td> the address (always on the third line, multiple lines are separated by &lt;br&gt;'s)</td></tr>
				<tr><td>td.ship_phone</td><td> the shipping phone (if available)</td></tr>
			</table>
			~ ],
	[ 'ORDER', '%TRACKINGINFO%', q~
		An Text (hardline formatted) shipping table (contains the same data as the plaintext &#37;HTMLTRACKINGINFO&#37; just intended for Text messages).<br>
		~ ],
	[ 'ORDER', '%HTMLTRACKINGINFO%', q~
		An HTML formatted shipping address table (contains the same data as the plaintext &#37;TRACKINFO&#37; just intended for HTML messages).<br>
		The table includes the following style sheet elements which can be customized and tuned by you:<br>
			<table>
				<tr><td>table.trackinfo</td><td>the body of the table</td></tr>
				<tr><td>td.line</td><td> a line in the tracking table.</td></tr>
			</table>
		~ ],
	[ 'ORDER', '%DATE%', q~Date the order was created.~ ],
	[ 'ORDER', '%TODAY%', q~Todays date.~],	# used by kyle for RA's 
	[ 'ACCOUNT', '%PASSWORD%', 'The password assigned' ],
	[ 'ACCOUNT', '%FULLNAME%', 'The customer\'s full name, e.g. Bob Jones' ],
	[ 'ACCOUNT', '%FIRSTNAME%', 'The customer\'s first name, e.g. Bob' ],
	[ 'ACCOUNT', '%LASTNAME%', 'The customer\'s last name, e.g. Jones' ],
	[ 'ACCOUNT', '%IPADDRESS%', 'The numeric ip address of the computer which requested the email' ],
	[ 'ACCOUNT', '%REWARD_BALANCE%', 'The current rewards balance for the account' ],
	[ 'ACCOUNT', '%EMAIL%', 'The email address (login name) for the customer' ],
	[ 'CUSTOMER', '%ADDITIONAL_TEXT%', 'Giftcard Note from issuer' ],
	[ 'CUSTOMER', '%GIFTCARDS%', 'HTML Table of giftcards and balances for the customer receiving the email' ],
	);


##
## NOTE: do not add new message types without consulting w/becky (zid has enum on msgtype)
##
##
%SITE::EMAILS::ERRORS = (
	0=>'Success',
	## 50 - 100 are reserved for webapi
	50=>"API ERROR - Empty body and no MSGID specified",
	## 900 series errors are internal errors
	900=>"Could not load toxml file",
	901=>"Could not load msg from database",

	## 1000 series errors are formatting errors
	1000=>"Message is blank or contains nothing but whitespace",
	1001=>"Recipient email is not set",
	1002=>"Recipient is not a properly formatted email address",
	1003=>"Message has a blank subject",	
	1004=>"From email address is not setup",
	1005=>"From email address is not properly formatted",

	## 2000 series errors are really warnings
	2000=>"FOOTER ERROR: Company name is required.",
	2001=>"FOOTER ERROR: Support Phone Number is required.",
	2002=>"FOOTER ERROR: Company Address is required.",
	2003=>"FOOTER ERROR: Company City is required.",
	2004=>"FOOTER ERROR: Company State is required.",
	2005=>"FOOTER ERROR: Company Zip is required.",
	2006=>"FOOTER Users cannot receive HTML Email designed in microsoft office (incompatible MIME Encoding).",
	
	## 3000 series are content errors
	3001=>"Any SPLIT order email requires NEWOID be set to a non-blank value",
	);

sub def { return (defined $_[0]) ? $_[0] : ''; }

%SITE::EMAILS::DEFAULTS = (
	'BLANK'=>{
		MSGBODY=>'',MSGTITLE=>'',MSGTYPE=>'',
		},
#	'CUSTOMER.WHOLESALE.SIGNUP'=>{
#		},
	'ORDER.NOTE'=>{
		MSGFORMAT=>'TEXT',
		MSGTYPE=>'ORDER',
		MSGSUBJECT=>'Order %ORDERID%',
		MSGBODY=>'%BODY%',
		},
	'ORDER.ARRIVED.EBF'=>{
		MSGFORMAT=>'TEXT',
		MSGTYPE=>'ORDER',
		MSGTITLE=>'Order Arrived: eBay Follow Up',
		MSGSUBJECT=>'Your eBay order has arrived - please leave us feedback',
		MSGBODY=>q~
Based on the shipment date, and the method we shipped your package - 
your order should have arrived, if you have not received it please contact us.

We appreciate your business and ask that you take a moment of your busy schedule to rate us.  Please give us 5 out of 5 in all categories, unless you feel we do not
deserve that score - in which case we'd greatly appreciate your feedback as to how we could have improved.  
Please take a moment to review your order on our website:

%ORDERFEEDBACK%

By giving us 5 out of 5 you are ensuring that we'll continue to bring you the best possible service at the most competitive prices!
~,
		},
	'ORDER.ARRIVED.BUY'=>{
		MSGFORMAT=>'TEXT',
		MSGTYPE=>'ORDER',
		MSGTITLE=>'Order Arrived: Buy.com Follow Up',
		MSGSUBJECT=>'Your Buy.com order has arrived!',
		MSGBODY=>q~
Based on the shipment date, and the method we shipped your package - 
your order should have arrived, if you have not received it please contact us.

We appreciate your business and ask that you take a moment of your busy schedule to rate us on Buy.com.  
Please give us the highest possible score in all categories, unless you feel we do not deserve that score - in which case we'd greatly appreciate your feedback as to how 
we could have improved.  
Please take a moment to review your order on our website:

%ORDERFEEDBACK%

By giving us a good rating you are ensuring that we'll continue to bring you the best possible service at the most competitive prices!
~,
		},
### SRS orders dont include email addresses
#	'ORDER.ARRIVED.SRS'=>{
#		MSGFORMAT=>'TEXT',
#		MSGTYPE=>'ORDER',
#		MSGTITLE=>'Order Arrived: Sears.com Follow Up',
#		MSGSUBJECT=>'Your Sears.com order has arrived!',
#		MSGBODY=>q~
#Based on the shipment date, and the method we shipped your package - 
#your order should have arrived, if you have not received it please contact us.
#
#We appreciate your business and ask that you take a moment of your busy schedule
#to rate us on Sears.com.  
#Please give us the highest possible score in all categories, unless you feel we do not
#deserve that score - in which case we'd greatly appreciate your feedback as to how 
#we could have improved.  
#
#By giving us a good rating you are ensuring that we'll continue to bring you the best
#possible service at the most competitive prices!
#~,
#		},
	'ORDER.ARRIVED.AMZ'=>{
		MSGFORMAT=>'TEXT',
		MSGTYPE=>'ORDER',
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
		MSGTYPE=>'ORDER',
		MSGTITLE=>'Order Arrived: Website Follow Up',
		MSGSUBJECT=>'Your order has arrived - please leave us feedback',
		MSGBODY=>q~
Based on the shipment date, and the method we shipped your package - 
your order should have arrived, if you have not received it please contact us.

Hopefully by now you've opened the package and had a bit of time with the product. Please take a moment to review your order on our website:

%ORDERFEEDBACK%

Reviews help us continue to deliver a great online shopping experience for customers just like you.
~,
		},

		'ORDER.MERGED'=>{
			MSGTYPE=>'ORDER',
			MSGFORMAT=>'WIKI',
			MSGSUBJECT=>'Your order has been merged',
			MSGBODY=>q~
Hi %FULLNAME%,

This is a notification of a recent order consolidation.
The resulting order number is %ORDERID%.

There is no need to reply to this email if everything is correct with your order.

Contact Email: %SUPPORTEMAIL%

Combined Order Contents: 
%CONTENTS%

If you have any questions or concerns please contact us immediately. Thank You!
~,
			},
		'ORDER.SPLIT'=>{
			MSGTYPE=>'ORDER',
			MSGFORMAT=>'WIKI',
			MSGSUBJECT=>'Changes to your order',
			MSGBODY=>q~
Hi %FULLNAME%,

This is a notification that your #%ORDERID% has been split into
two pieces, and a new order id #%SPLITID% has been created.

|=Contents of #%ORDERID%:
|%CONTENTS%<br>

|=Contents of #%SPLITID%:
|%SPLITCONTENTS%

There is no need to reply to this email if everything is correct.<br>

If not please contact us immediately at <a href="mailto:%SUPPORTEMAIL%">%SUPPORTEMAIL%</a><br>
Thank You.
~,
			},
		'ORDER.SHIPPED' => {
			MSGTYPE=>'ORDER',
			MSGFORMAT=>'WIKI',
			MSGSUBJECT=>'Order %ORDERID% shipped',
			MSGBODY=>q~An item from your %ORDERID% has been shipped. 
The tracking numbers (if available) appear below:

%TRACKINGINFO%
~,
			},
		'ORDER.SHIPPED.EBAY'=>{
			MSGTYPE=>'ORDER',
			MSGFORMAT=>'TEXT',
			MSGSUBJECT=>'Your order has been shipped.',
			MSGBODY=>q~
Your order has been shipped.  
If available the tracking numbers will appear below:
%TRACKINGINFO%


To see the tracking status for this order, or to contact us with any
questions please visit our website using the following url:
%ORDERURL%

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
			MSGTYPE=>'ORDER',
			MSGFORMAT=>'WIKI',
			MSGTITLE=>q~Amazon Feedback Request~,
			HINT=>q~This message is usually generated from an event.~,
			MSGSUBJECT=>q~Amazon Feedback Request~,
			MSGBODY=>q~Hi %FIRSTNAME%,
Thank you for your order, we hope it has arrived intact. 
We would appreciate if you would take a few moments from your busy day
to go and leave us feedback on Amazon.~,		
			},
		'ORDER.MOVE.RECENT' => {
			MSGTYPE=>'ORDER',
			MSGFORMAT=>'WIKI',
			MSGSUBJECT=>'Order %ORDERID% moved to Recent',
			MSGBODY=>q~Your order has been moved back to recent status.~,
			},
		'ORDER.MOVE.APPROVED' => {
			MSGTYPE=>'ORDER',
			MSGFORMAT=>'WIKI',
			MSGSUBJECT=>'Order %ORDERID% Approved',
			MSGBODY=>q~Your order has been approved and should ship shortly.~,
			},
		'ORDER.MOVE.PENDING' => {
			MSGTYPE=>'ORDER',
			MSGFORMAT=>'WIKI',
			MSGSUBJECT=>'Order %ORDERID% Pending',
			MSGBODY=>q~Your order is currently pending, and may require additional interaction by you.~,
			},
		'ORDER.MOVE.BACKORDER' => {
			MSGTYPE=>'ORDER',
			MSGFORMAT=>'WIKI',
			MSGSUBJECT=>'Order %ORDERID% Backordered',
			MSGBODY=>q~Your order %ORDERID% has been placed into "Back order" status because one or
more items is not in-stock. You will be notified when the information becomes available.~,
			},
		'ORDER.MOVE.PREORDER' => {
			MSGTYPE=>'ORDER',
			MSGFORMAT=>'WIKI',
			MSGSUBJECT=>'Order %ORDERID% Preordered',
			MSGBODY=>q~Your order %ORDERID% has been placed into "Preorder" status. 
You will be notified when information becomes available.~,
			},
		'ORDER.MOVE.CANCEL' => {
			MSGTYPE=>'ORDER',
			MSGFORMAT=>'WIKI',
			MSGSUBJECT=>'Order %ORDERID% Cancelled',
			MSGBODY=>q~Your order %ORDERID% has been cancelled.~,
			},
		'ORDER.MOVE.PROCESSING' => {
			MSGTYPE=>'ORDER',
			MSGFORMAT=>'WIKI',
			MSGSUBJECT=>'Order %ORDERID% Processing',
			MSGBODY=>q~Your order is currently being processed.~,
			},
		'ORDER.MOVE.COMPLETED' => {
			MSGTYPE=>'ORDER',
			MSGFORMAT=>'WIKI',
			MSGSUBJECT=>'Order %ORDERID% shipped',
			MSGBODY=>q~Your order %ORDERID% has been shipped. 
The tracking numbers (if available) appear below:

%TRACKINGINFO%
~,
			},
	'ORDER.FEEDBACK.EBAY'=>{
		MSGTYPE=>'ORDER',
		MSGFORMAT=>'WIKI',
		MSGTITLE=>'eBay Positive Feedback Request',
		MSGSUBJECT=>q~eBay Feedback~,
		HINT=>q~
<b>Positive Feedback Message:</b><br>
When Zoovy leaves feedback the message below will be automatically sent to the person receiving the feedback.
If you leave feedback when an item is paid you should ask the person to leave feedback for you.
If you require them to leave feedback before you leave feedback then you should change this message to thank them
for their purchase and encourage them to purchase from you again.
~,
		MSGBODY=>q~
Hello,

Thank you for your purchase..
We appreciate your patronage, and have left you feedback.

We hope you had a pleasant purchasing experience, and we hope you'll remember us for your next purchase.

If you have not already done so, please leave us feedback by visiting:
[[%FEEDBACKURL%]:url=%FEEDBACKURL%] 

We hope to serve you in the future.
Customer support is very important to us. If you have any questions or comments.

Thank You!
~,
		},

	'ORDER.CONFIRM'=>{ 	# OCREATE
		MSGTYPE=>'ORDER',
		MSGFORMAT=>'WIKI',
		MSGTITLE=>q~Order Created~,
		MSGSUBJECT=>q~Order %ORDERID% Created~,
		HINT=>q~<b>Orders Created Message:</b><br>
This message is generated whenever an order is placed in your store. Sort of an Email receipt.
<br><br>
HINT: to specify multiple CC addresses, use a comma to separate each one;
~,			
		MSGBODY=>q~
		
Hello %NAME%,


Thank you for placing order %ORDERID%.

We appreciate your business. If you need to contact us please make sure to include the following order number:

==Order Number: %ORDERID%==

Created: %DATE%


=Customer Billing Address
%BILLADDR%


=Customer Shipping Address
%SHIPADDR%


=Order Contents
%CONTENTS%


=Shipping Method
%SHIPMETHOD%


=Payment Information
%PAYINFO%


=Payment Instructions
%PAYINSTRUCTIONS%


Please visit [[%ORDERURL%]:url=%ORDERURL%] to check status on this order.

Customer support is very important to us. If you have any questions or comments, please contact us at [[%SUPPORTEMAIL%]:url=mailto:%SUPPORTEMAIL%] or call us at %SUPPORTPHONE%.  We can also be reached through our website at:

[[%CONTACT_URL%]:url=%CONTACT_URL%] 



Thank You,


[[%HOME_URL%]:url=%HOME_URL%] 
~,
		},


	'ORDER.CONFIRM_DENIED'=>{ # ODENIED
		MSGTYPE=>'ORDER',
		MSGFORMAT=>'WIKI',
		MSGTITLE=>q~Order Payment Denied~,
		HINT=>q~
This message is sent when an order is created, but the payment is denied (ex: credit card declined).
~,		
		MSGSUBJECT=>q~Order %ORDERID% requires assistance~,
		MSGBODY=>q~
Hello %NAME%,

Unfortunately there was a problem processing your order %ORDERID%.

|=Payment Instructions
|%PAYINSTRUCTIONS%

Please visit [[%ORDERURL%]:url=%ORDERURL%] to correct this order or cancel it.

Customer support is very important to us. If you have any questions or comments, 
please contact us at [[%SUPPORTEMAIL%]:url=mailto:%SUPPORTEMAIL%] or call us at %SUPPORTPHONE%.  


==Order Details: %ORDERID%==
Created: %DATE%

|=Customer Billing Address |=Customer Shipping Address
|%BILLADDR%|%SHIPADDR%

|=Order Contents
|%CONTENTS%

|=Shipping Method
|%SHIPMETHOD%

|=Payment Information
|%PAYINFO%


~,
		},

	'ORDER.PAYMENT_REMINDER'=>{   # PAYREMIND
		MSGFORMAT=>'WIKI',
		MSGTYPE=>'ORDER',
		MSGTITLE=>q~Payment Reminder~,
		HINT=>q~
<b>Payment Reminder:</b><br>
This message sent regularly (every 7 days) on Pending orders that have an unpaid status.
~,
		MSGSUBJECT=>q~Payment Reminder for Order %ORDERID%~,
		MSGBODY=>q~
Hello %FIRSTNAME%, thank you for placing order %ORDERID%.
We appreciate your business, however we have not received payment 
for your order which was created on %DATE%. If you believe this is an error please contact us at:

[[%CONTACT_URL%]:url=%CONTACT_URL%]

Please follow the payment instructions below to remit payment as soon as possible.

=Order Contents=
%CONTENTS%


=Shipping Method=
%SHIPMETHOD%


=Payment Information=
%PAYINFO%

=Payment Instructions=
%PAYINSTRUCTIONS%

----

Please visit [[%ORDERURL%]:url=%ORDERURL%] to check status on this order.

Customer support is very important to us. If you have any questions or comments, please contact us at [[%SUPPORTEMAIL%]:url=mailto:%SUPPORTEMAIL%] or call us at %SUPPORTPHONE%.  We can also be reached through our website at:

[[%CONTACT_URL%]:url=%CONTACT_URL%] 



Thank You,


[[%HOME_URL%]:url=%HOME_URL%]
~,		
		},
	'ORDER.CUSTOM_MESSAGE1'=>{	# OCUSTOM1
		MSGTYPE=>'ORDER',
		MSGFORMAT=>'WIKI',
		MSGTITLE=>q~Order Custom 1~,
		HINT=>q~<b>Order Custom Message #1:</b>~,
		MSGSUBJECT=>q~Notification for Order %ORDERID%~,
		MSGBODY=>q~~,		
		},
#	'OCUSTOM2'=>{
#		MSGTYPE=>'ORDER',
#		MSGFORMAT=>'WIKI',
#		MSGTITLE=>q~Order Custom 2~,
#		HINT=>q~<b>Order Custom Message #2:</b>~,
#		MSGSUBJECT=>q~Notification for Order %ORDERID%~,
#		MSGBODY=>q~~,		
#		},
	'CUSTOMER.GIFTCARD.REMINDER'=>{	# AGIFT_RTRY
		MSGTYPE=>'ACCOUNT',
		MSGFORMAT=>'WIKI',
		MSGTITLE=>q~Customer GiftCard Reminder~,
		MSGSUBJECT=>q~%COMPANYNAME% gift card reminder~,
		MSGBODY=>q~
Hi %FIRSTNAME%,

%ADDITIONAL_TEXT%

This is a friendly reminder that you have the following giftcards available
to you:

%GIFTCARDS%

~,
		},
	'CUSTOMER.GIFTCARD.RECEIVED'=>{	# AGIFT_NEW
		MSGTYPE=>'ACCOUNT',
		MSGFORMAT=>'WIKI',
		MSGTITLE=>q~Customer New GiftCard Notification~,
		MSGSUBJECT=>q~%COMPANYNAME% gift card notification~,
		MSGBODY=>q~
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

~,
		},
	'CUSTOMER.SIGNUP'=>{		# ASIGNUP
		MSGTYPE=>'ACCOUNT',
		MSGFORMAT=>'WIKI',
		MSGTITLE=>q~Customer Account Signup~,
		MSGSUBJECT=>q~%COMPANYNAME% Account Information~,
		MSGBODY=>q~
Welcome!
~,
		},
	'CUSTOMER.CREATED'=>{ 	# ACREATE
		MSGTYPE=>'ACCOUNT',
		MSGFORMAT=>'WIKI',
		MSGTITLE=>q~Customer Account Created~,
		HINT=>q~<b>Account Created Message:</b><br>
This email is sent to a customer if they request to have an account created (or you implicity create accounts) after an
order has been placed. It contains the password and should serve to inform them about the various tools they may use to
contact you.
<br><br>
HINT: to specify multiple CC addresses, use a comma to separate each one;
~,
		MSGSUBJECT=>q~%COMPANYNAME% account information~,
		MSGBODY=>q~
Welcome %FIRSTNAME%!

A password for your account has been automatically generated.
Your password is "%PASSWORD%"

To login to your account and check the status of orders, or to make sure
our records have your most current contact information please visit:

[[%WEBSITE%/customer]:url=%WEBSITE%/customer]

Customer support is very important to us. If you have any questions or comments, please contact us at [[%SUPPORTEMAIL%]:url=mailto:%SUPPORTEMAIL%] or call us at %SUPPORTPHONE%.  We can also be reached through our website at:

[[%CONTACT_URL%]:url=%CONTACT_URL%] 



Thank You,


[[%HOME_URL%]:url=%HOME_URL%]~,		
		},
	'CUSTOMER.PASSWORD.REQUEST'=>{  # PREQUEST
		MSGTYPE=>'ACCOUNT',
		MSGFORMAT=>'WIKI',
		MSGTITLE=>q~Password Request~,
		HINT=>q~<b>Password Request Message:</b><br>
This is sent to a customer if they request the password associated with their email address.
~,
		MSGSUBJECT=>q~%COMPANYNAME% account information~,
		MSGBODY=>q~
Hello!

You (or someone who thinks they're you) has requested that your password be sent to this email address.

Your username is %EMAIL%
Your password is %PASSWORD%


=Security info=
Password request originated from IP address %IPADDRESS%



Customer support is very important to us. If you have any questions or comments, please contact us at [[%SUPPORTEMAIL%]:url=mailto:%SUPPORTEMAIL%] or call us at %SUPPORTPHONE%.  We can also be reached through our website at:

[[%CONTACT_URL%]:url=%CONTACT_URL%] 



Thank You,


[[%HOME_URL%]:url=%HOME_URL%]
~,		
		},
	'TICKET.CREATED'=>{
		MSGTYPE=>'TICKET',
		MSGFORMAT=>'WIKI',
		MSGTITLE=>q~Ticket Created~,
		HINT=>q~This messagee is sent to a customer when a ticket is created.~,
		MSGSUBJECT=>q~Ticket %TKTCODE%: %TKTSUBJECT%~,
		MSGBODY=>q~
This is to inform you that ticket %TKTCODE% has been created regarding:
%TKTSUBJECT%

To manage or update this ticket please use the URL below:
%CUSTOMER_URL%/ticket/view?tktcode=%TKTCODE%
		~,
		},
	'TICKET.REPLY'=>{
		MSGTYPE=>'TICKET',
		MSGFORMAT=>'WIKI',
		MSGTITLE=>q~Ticket Ask Question~,
		HINT=>q~This email is sent to a customer when a response is requested.~,
		MSGSUBJECT=>q~Ticket %TKTCODE%: %TKTSUBJECT%~,
		MSGBODY=>q~
Subject: %TKTSUBJECT%
This is to inform you that ticket %TKTCODE% is awaiting your response.

To manage or update this ticket please use the URL below:
%CUSTOMER_URL%/ticket/view?tktcode=%TKTCODE%
		~,
		},
	'TICKET.CLOSED'=>{
		MSGTYPE=>'TICKET',
		MSGFORMAT=>'WIKI',
		MSGTITLE=>q~Ticket Closed~,
		HINT=>q~This email is sent to a customer when a ticket is closed.~,
		MSGSUBJECT=>q~Ticket %TKTCODE%: %TKTSUBJECT%~,
		MSGBODY=>q~
Subject: %TKTSUBJECT%
This is to inform you that ticket %TKTCODE% has been closed.

To manage or update this ticket please use the URL below:
%CUSTOMER_URL%/ticket/view?tktcode=%TKTCODE%
		~,
		},
	'SUBSCRIBE'=>{
		MSGTYPE=>'ACCOUNT',
		MSGFORMAT=>'WIKI',
		MSGTITLE=>q~Newsletter Subscribe~,
		HINT=>q~<b>This email is sent to a customer to thank them for joining your mailing list:</b><br>~,
		MSGSUBJECT=>q~%COMPANYNAME% account information~,
		MSGBODY=>q~
Welcome! Thank you for signing up for our mailing list.

A password for your account has been automatically generated.

Login/Username: %EMAIL%
Password: %PASSWORD%

To unsubscribe from our mailing list please visit:

[[%WEBSITE%/customer]:url=%WEBSITE%/customer]

Customer support is very important to us. If you have any questions or comments, please contact us at [[%SUPPORTEMAIL%]:url=mailto:%SUPPORTEMAIL%] or call us at %SUPPORTPHONE%.  We can also be reached through our website at:

[[%CONTACT_URL%]:url=%CONTACT_URL%] 



Thank You,


[[%HOME_URL%]:url=%HOME_URL%]
~,		
		},


	'PINSTOCK'=>{
		MSGTYPE=>'PRODUCT',
		MSGFORMAT=>'WIKI',
		MSGTITLE=>'Product instock notification (to customer)',
		MSGSUBJECT=>q~%PROD_NAME% now in stock~,
		MSGBODY=>q~
The product %PRODUCTID%: %PRODUCTID% is now available for purchase.

%PROD_IMAGE_TAG%

Price: %BASE_PRICE%

%ADDTOCART%

To purchase please visit: 
%WEBSITE%/product/%PRODUCTID%

~,
		},

	'PTELLAF'=>{
		MSGTITLE=>q~Tell A Friend Email~,
		MSGTYPE=>'PRODUCT',
		MSGFORMAT=>'HTML',
		HINT=>q~The "Tell A Friend" email feature must be configured in your product layout.~,
		MSGSUBJECT=>q~Msg. from %SENDER_NAME% RE: %PROD_NAME%~,
		MSGBODY=>q~
<table cellspacing=0 cellpadding=2 border=0 width="100%">
<tr>
   <td valign=top width="1%">
	<a href="%WEBSITE%/product/%PRODUCTID%">%PROD_IMAGE_TAG%</a>
	</td>

   <td align="left">
	<p style="font-family: arial; font-size: 10pt; font-weight: bold;">%SENDER_SUBJECT%</p>
	<p>%SENDER_BODY%</p>
<p><strong>%PROD_NAME%</strong><br>
%PROD_DESC%</p>
<p><strong>Price: </strong>%BASE_PRICE%</p>

%ADDTOCART%
<p><a href="%WEBSITE%/product/%PRODUCTID%">Click Here for more information about this product</a></p>
</td>
</tr></table>
~,		
		},
#	'PIDSTOCK'=>{
#		MSGTITLE=>q~Product Back in Stock Notice~,
#		MSGTYPE=>'PRODUCT',
#		HINT=>q~The "Tell A Friend" email feature must be configured in your product layout.~,
#		MSGSUBJECT=>q~Item %PID%: %PROD_NAME% now in stock~,
#		MSGBODY=>q~~,		
#		},
#	'PIDPRICE'=>{
#		MSGTITLE=>q~Product has reached Target Price Notice~,
#		MSGTYPE=>'PRODUCT',
#		HINT=>q~The "Tell A Friend" email feature must be configured in your product layout.~,
#		MSGSUBJECT=>q~Item %PID%: %PROD_NAME% now in stock~,
#		MSGBODY=>q~~,		
#		},
	
);



##
## formats a text aaddress.
##	 NOTE: this should be converted over to use $o->addr_vars
##
sub text_addr {
	my ($type, $hashref) = @_;
	my $out = '';
	my $htmlout = "<!-- $type --><table class='${type}addr'>";
	
	$out = "     ".$hashref->{$type.'_firstname'}.' '.$hashref->{$type.'_lastname'}."\n";
	$htmlout .= "<tr><td class='${type}_fullname'>".$hashref->{$type.'_firstname'}.' '.$hashref->{$type.'_lastname'}."</td></tr>\n";

	if (not defined $hashref->{$type.'_company'}) { $hashref->{$type.'_company'} = ''; }
	if ($hashref->{$type.'_company'} ne '') {
		$out .= "     ".$hashref->{$type.'_company'}."\n";
		$htmlout .= "<tr><td class='${type}_company'>".$hashref->{$type.'_company'}."</td></tr>\n";
		}

	$out .= "     ".$hashref->{$type.'_address1'}."\n";
	$htmlout .= "<tr><td class='${type}_address'>".$hashref->{$type.'_address1'}."<br>";

	if (not defined $hashref->{$type.'_address2'}) { $hashref->{$type.'_address2'} = ''; }
	if ($hashref->{$type.'_address2'} ne '') {
		$out .= "     $hashref->{$type.'_address2'}\n";
		$htmlout .= $hashref->{$type.'_address2'}."<br>\n";
		}

	if (not defined $hashref->{$type.'_country'}) { $hashref->{$type.'_country'} = ''; }
	if ($hashref->{$type.'_country'} eq 'United States') { $hashref->{$type.'_country'} = ''; }
	elsif ($hashref->{$type.'_country'} eq 'US') { $hashref->{$type.'_country'} = ''; }
	elsif ($hashref->{$type.'_country'} eq 'USA') { $hashref->{$type.'_country'} = ''; }

	if ($hashref->{$type.'_countrycode'} eq '') {
		$out .= "     $hashref->{$type.'_city'}, $hashref->{$type.'_region'} $hashref->{$type.'_postal'} $hashref->{$type.'_countrycode'}\n";
		$htmlout .= $hashref->{$type.'_city'}.", $hashref->{$type.'_region'} $hashref->{$type.'_postal'} $hashref->{$type.'_countrycode'}<br>\n";
		}
	elsif ($hashref->{$type.'_country'} eq '') {
		$out .= "     $hashref->{$type.'_city'}, $hashref->{$type.'_state'} $hashref->{$type.'_zip'}\n";
		$htmlout .= $hashref->{$type.'_city'}.", $hashref->{$type.'_state'} $hashref->{$type.'_zip'}<br>\n";
		}
	else {
		$out .= "     ".$hashref->{$type.'_city'}.", ".$hashref->{$type.'_province'}."\n";
		$htmlout .= $hashref->{$type.'_city'}.', '.$hashref->{$type.'_province'}."<br>\n";
		if ($hashref->{$type.'_int_zip'} ne '') {
			$out .= "     ".$hashref->{$type.'_int_zip'}."\n";
			$htmlout .= $hashref->{$type.'_int_zip'}."<br>\n";
			}
		$out .= "     ".$hashref->{$type.'_country'}."\n";
		$htmlout .= $hashref->{$type.'_country'}."<br>\n";
		}
	
	$htmlout .= "</td></tr>";

	if (not defined $hashref->{$type.'_phone'}) { $hashref->{$type.'_phone'} = ''; }
	if ($hashref->{$type.'_phone'} ne '') {
		$out .= "     Ph: $hashref->{$type.'_phone'}\n";
		$htmlout .= "<tr><td class='${type}_phone'>Ph: $hashref->{$type.'_phone'}</td></tr>\n";
		}

	if (not defined $hashref->{$type.'_email'}) { $hashref->{$type.'_email'} = ''; }
	if ($hashref->{$type.'_email'} ne '') {
		$out .= "     Email: $hashref->{$type.'_email'}\n";
		$htmlout .= "<tr><td class='${type}_email'>Email: $hashref->{$type.'_email'}</td></tr>\n";
		}

	$htmlout .= "</table>\n";

#	print STDERR "OUT:$out\n";
#	print STDERR "HTML:$htmlout\n";


	return ($out,$htmlout);
	}



##
## remove any characters which don't belong in a mail header, or body of message (e.g. html, stuff like that)
##
sub untaint {
	my ($msg) = @_;
	
	$msg =~ s/[\n\r]+//gs;

	return($msg);
	}


##
## NOTE: MSGID (parameter 2) can be left blank and specified as MSGID in $options
##
##	options:
##		TO=>[email]
##		TEST=>1
##		DOCID=> toxml wrapper (optional)
##		SRC=>'SUPPLYCHAIN',
##
## returns:
#	return($ERR, { 
#		SUBJECT=>$SUBJECT, 
#		FORMAT=>$MSGREF->{'MSGFORMAT'},
#		DOCID=>$docid,
#		FROM=>$FROM,
#		TO=>$RECIPIENT,
#		BCC=>$MSGREF->{'MSGBCC'},
#		BODY=>$BODY,
#		}
#		);
##
##
sub createMsg {
	my ($self,$MSGID,%options) = @_;

	require TOXML; 	

	if (defined $options{'CART2'}) {
		&ZOOVY::confess($self->username(),"createMSg would **MUCH** rather receive *CART2 instead of simply *CART",justkidding=>1);
		$options{'*CART2'} = $options{'CART2'};
		}

	my $SITE = $options{'*SITE'};
	if (not defined $SITE) { $self->_SITE(); }

	my $USERNAME = $SITE->username();
	my $RECIPIENT = lc($options{'TO'});
	if (not defined $RECIPIENT) { 
		$RECIPIENT = $options{'RECIPIENT'}; 
		}
	my $ERR = 0;


	## Figure out which docid.
	my $docid = '';
	if (defined $options{'DOCID'}) { $docid = $options{'DOCID'}; }

	## added for Amazon compliance, 2011-10-03, patti
	## ie use the 'amazon' docid that doesn't have any merchant links
	if ($docid eq '') {
		## check if this an ORDER email
		#if ((defined $options{'ORDER'}) && (ref($options{'ORDER'}) eq 'ORDER')) {
		#	my ($o) = $options{'ORDER'};
		#	if ($o->get_attrib('sdomain') eq 'amazon.com') {
		#		$docid = 'amazon';
		#		}
		#	#print STDERR "DOCID setting: $docid order: ".$o->id()." sdomain: ".$o->get_attrib('sdomain')."\n";
		#	}
		if ((defined $options{'*CART2'}) && (ref($options{'*CART2'}) eq 'CART2')) {
			my ($O2) = $options{'*CART2'};
			if ($O2->in_get('our/sdomain') eq 'amazon.com') {
				$docid = 'amazon';
				}
			#print STDERR "DOCID setting: $docid order: ".$o->id()." sdomain: ".$o->get_attrib('sdomain')."\n";
			}
		}

	# if ($docid eq '') { $docid = &ZOOVY::fetchmerchantns_attrib($SITE->username(),$self->profile(),'email:docid'); }
	if ($docid eq '') { 
		if (not defined $SITE->nsref()) {
			warn "SITE::EMAIL cannot load profile";
			}
		else {
			$docid = $SITE->nsref()->{'email:docid'}; 
			}	
		}
	if ($docid eq '') { $docid = 'standard'; }

	print STDERR "DOCID:$docid\n";

	my ($toxml) = undef;
	if ($docid ne '') { 
		($toxml) = TOXML->new('ZEMAIL',$docid,'USERNAME'=>$SITE->username()); 
		}

	if (not defined $toxml) { 
		$SITE::EMAILS::ERRORS{900} = "Could not load toxml file [$docid]";
		$ERR = 900;
		}

	## SANITY: at this point docid is loaded, or $ERR is set.
	##			  now lets go check out message.

	if ($MSGID eq '') { $MSGID = $options{'MSGID'}; }
	my $MSGREF = $self->getref($MSGID);
	if (not defined $MSGREF) {
		$SITE::EMAILS::ERRORS{$ERR=901} = "Could not load msg [$MSGID] from database";
		}

	my $BODY = $MSGREF->{'MSGBODY'};
	if ($options{'MSGBODY'} ne '') { $BODY = $options{'MSGBODY'}; }

	my $SUBJECT = $MSGREF->{'MSGSUBJECT'};
	if ($options{'SUBJECT'} ne '') { $SUBJECT = $options{'SUBJECT'}; }
	elsif ($options{'MSGSUBJECT'} ne '') { $SUBJECT = $options{'MSGSUBJECT'}; }
	print STDERR "SUBJECT[$SUBJECT]\n";

	$SUBJECT =~ s/[\n\r]+//gs;
	if ($SUBJECT eq '') { $ERR = 1003;  }


	## note: we need to resolve OID up here, so we have $options{'ORDER'} set.
	#if ((not $ERR) && (defined $options{'OID'}) && ($options{'OID'} ne '') && (not defined $options{'ORDER'})) {
	#	## okay so we got an OID but not an ORDER
	#	($options{'ORDER'}) = ORDER->new($USERNAME,$options{'OID'},new=>0);
	#	}
	if ((not $ERR) && (defined $options{'OID'}) && ($options{'OID'} ne '') && (not defined $options{'*CART2'})) {
		## okay so we got an OID but not an ORDER
		($options{'*CART2'}) = CART2->new_from_oid($USERNAME,$options{'OID'},new=>0);
		}

	## note we need to resolve CID up here, so we have $options{'BUYER_EMAIL'} set.
	if ((not $ERR) && (defined $options{'CID'}) && ($options{'CID'}>0)) {
		# my ($CID) = &CUSTOMER::resolve_customer_id($SITE::merchant_id,  $cart{'data.bill_email'});
		$options{'CUSTOMER'} = CUSTOMER->new($USERNAME,PRT=>$options{'PRT'},CID=>int($options{'CID'}),INIT=>0xFF);

		# use Data::Dumper;
		# print STDERR "[sendmail] to ".Dumper($options{'CID'},$options{'BUYER_EMAIL'})."\n";
		}


	if ((not $ERR) && ($RECIPIENT eq '') && ($options{'CUSTOMER'})) {
		## if we're sending a customer email, we can default to the current recipient.
		$RECIPIENT = $options{'CUSTOMER'}->email();
		}

	if (not $ERR) {
		if ($BODY =~ /^[\s]+$/) { $ERR = 1000; }
		elsif (($RECIPIENT eq '') && ($options{'*CART2'})) {} 	## orders don't need a valid recipient!
		elsif (($RECIPIENT eq '') && ($options{'CLAIM'})) {}	## claims don't need a valid recipient!
		elsif (($RECIPIENT eq '') && ($options{'CUSTOMER'})) {}	## customers don't need a valid recipient!
		elsif ($RECIPIENT eq '') { $ERR = 1001; }
		elsif (not &ZTOOLKIT::validate_email($RECIPIENT)) { 
			$SITE::EMAILS::ERRORS{1002} = "Recipient email [$RECIPIENT] does not appear to be valid."; 
			$ERR = 1002;
			}
		}


	## multiple addresses can be specified email1@isp1.com,email2@isp2.com
	my $FROM = $MSGREF->{'MSGFROM'};
	if ($options{'FROM'} ne '') { $FROM = $options{'FROM'}; }
	## DO NOT USE our/email
	## if ($FROM eq '') { $FROM = $SITE->Domain()->get('our/email'); }
	if ($FROM eq '') { 
		my $D = $SITE->Domain();
		if (defined $D) { $FROM = $D->get('our/support_email'); } 
		}
	if ($FROM eq '') { $FROM = $SITE->webdb()->{'from_email'}; }

	if (index($FROM,',')>=10) { $FROM = substr($FROM,0,index($FROM,',')); }
	if ($FROM =~ /<(.*?\@.*?)>/) { $FROM = $1; }	# Noah Webster <noah@dictionary.com>
	$FROM =~ s/[^A-Za-z0-9\.@\-\_]//gs;
	if ($FROM eq '') { $ERR = 1004; }
	print STDERR "FROM: $FROM\n";
	if (not &ZTOOLKIT::validate_email($FROM)) { 
		$SITE::EMAILS::ERRORS{$ERR=1005} = "From email address [$FROM] does not appear to be valid."; 
		}

	use Data::Dumper;
	print STDERR "ERRS: ".Dumper($ERR,$SITE::EMAILS::ERRORS{$ERR});
	##
	## SANITY: at this point %BODY% and %SUBJECT% are setup in the interpolation variables, and our 
	##			  RECIPIENT + FROM are both good.
	##			  lets start interpolating variables.
	##

	my %MACROS = (
		'%title1%' => '<br><b>',  	'%/title1%' => '</b><br>', 
		'%title2%' => '<br><b>',  	'%/title2%' => '</b>', 
		'%title3%' => '<b>', 		'%/title3%' => '</b>', 
		'%list%' => '<ul>',  		'%/list%' => '</ul>', 
		'%listitem%' => '<li>', 	'%/listitem%' => '</li>', 
		'%section%' => '<p>',  	'%/section%' => '</p>', 
		'%softbreak%' => '<br>',  
		'%hardbreak%' => '<hr>',  
		'%table%' => '<table>',  	'%/table%' => '</table>',
		'%tablerow%' => '<tr>',  	'%/tablerow%' => '</tr>',
		'%tabledata%' => '<td>',  	'%/tabledata%' => '</td>',
		'%tablehead%' => '<td><b>',  	'%/tablehead%' => '</b></td>',
		);
	if (ref($options{'MACROS'}) eq 'HASH') {
		foreach my $k (keys %{$options{'MACROS'}}) {
			$MACROS{$k} = $options{'MACROS'}->{$k};
			}
		}

	$MACROS{'%USERNAME%'} = $SITE->username();
	
	my $html = '';

#	## NOTE: this *MUST* come after the MACRO's section to work properly.
#	if ((not $ERR) && (($RECIPIENT =~ /aol\.com$/is) || $options{'TEST'})) { 
#		## BUILD THE AOL INFOBOX
#		my $ERRORS = 0;
#		my ($inforef) = &ZOOVY::fetchmerchantns_ref($SITE->username(),$self->profile());
#		if ($inforef->{'zoovy:company_name'} eq '') { $ERR = 2000; }
#		if (length($inforef->{'zoovy:support_phone'}) < 10) { $ERR = 2001; }
#		if (length($inforef->{'zoovy:address1'}) < 10) { $ERR = 2002; }
#		if (length($inforef->{'zoovy:city'}) < 2) { $ERR = 2003; }
#		if (length($inforef->{'zoovy:state'}) < 2) { $ERR = 2004; }
#		if (length($inforef->{'zoovy:zip'}) < 5) { $ERR = 2005; }
#		if ($html =~ /xmlns\:o\=\"urn\:schemas-microsoft-com\:office\:office\"/s) { $ERR = 2006; }
#
#		if (not $ERR) {
#			$html .= qq~<center><table><tr><td><div style="font-family:Arial, Helvetica, sans-serif; font-size: 8pt;">~;
#		#	if (($MSGREF->{'MSGTYPE'} eq 'INCOMPLETE') && ($MACROS{'%PORTAL%'} =~ /ebay/)) {
#		#		$html .= "<b>Please note: you are receiving this email as part of an eBay transaction.</b>";
#		#		$html .= "You have an obligation under the eBay terms of service to complete this transaction, and we have an obligation to contact you.";
#		#		$html .= "Failure to complete this transaction will result in a non-paying bidder flag being added to your eBay account, and/or your eBay account being terminated.";
#		#		$html .= "Use the link below if you do not wish to receive any additional reminders:<br>";
#		#		$html .= "<a href=\"%SDOMAIN%/unsubscribe.cgi?aolemail=$RECIPIENT&claim=$options{'CLAIM'}\">";
#		#		$html .= "http://%SDOMAIN%/unsubscribe.cgi?aolemail=$RECIPIENT&claim=$options{'CLAIM'}";
#		#		$html .= "</a><br>";
#		#		}
#			if ( ($MSGREF->{'MSGTYPE'} eq 'ORDER') && (ref($options{'*CART2'}) eq 'CART2') ) {
#				$MACROS{'%ORDERID%'} = $options{'*CART2'}->oid();
#				## Has to do with an order
#				$html .= "This message is informational regarding order $MACROS{'%ORDERID%'}.<br><br>";
#				$html .= "<b>If you do not wish to receive future advertising emails please unsubscribe at:</b><br>";
#				$html .= "<a href=\"http://%SDOMAIN%/customer/newsletter/unsubscribe?aolemail=$RECIPIENT\">";
#				$html .= "http://%SDOMAIN%/customer/newsletter/unsubscribe?aolemail=$RECIPIENT";
#				$html .= "</a><br>";
#				}
#			elsif ((defined $options{'CLAIM'}) && ($options{'CLAIM'} ne '')) {
#				$html .= "<b>Unsubscribe from receiving additional reminders for this transaction:</b><br>";
#				$html .= "<a href=\"http://%SDOMAIN%/customer/newsletter/unsubscribe?aolemail=$RECIPIENT\">";
#				$html .= "<a href=\"http://%SDOMAIN%/customer/newsletter/unsubscribe?aolemail=$RECIPIENT&claim=$options{'CLAIM'}\">";
#				$html .= "http://%SDOMAIN%/customer/newsletter/unsubscribe?aolemail=$RECIPIENT&claim=$options{'CLAIM'}";
#				$html .= "</a><br>";
#				}	
#			else {
#				my $tmp = $RECIPIENT; $tmp =~ s/\@/%40/;		# replace the @ with a %40
#				$html .= "<b>If you do not wish to receive future emails please unsubscribe at:</b><br>\n";
#				$html .= "<a href=\"http://%SDOMAIN%/customer/newsletter/unsubscribe?aolemail=$tmp\">\n";
#				$html .= "http://%SDOMAIN%/customer/newsletter/unsubscribe?aolemail=$tmp";
#				$html .= "</a><br>";
#				}
#		
#			$html .= "<br>If you prefer, you may contact us in either following ways:<br>\n";
#			$html .= "By Phone: $inforef->{'zoovy:support_phone'}<br>\n";
#			$html .= "Mailing Address:<br>";
#			$html .= "&nbsp;&nbsp;&nbsp; $inforef->{'zoovy:company_name'}<br>";
#			$html .= "&nbsp;&nbsp;&nbsp; $inforef->{'zoovy:address1'}<br>";
#			if ($inforef->{'zoovy:address2'} ne '') { $html .= "&nbsp;&nbsp;&nbsp; $inforef->{'zoovy:address2'}<br>"; }
#			$html .= "&nbsp;&nbsp;&nbsp; $inforef->{'zoovy:city'}, $inforef->{'zoovy:state'}. $inforef->{'zoovy:zip'}<br>";
#			$html .= "<br><i>If any of the information above appears invalid please notify abuse\@zoovy.com immediately.</i><br>";
#			$html .= "</div></td></tr></table></center><br>";
#			}
#		}



	if (not $ERR) {

		if ($options{'CLAIM'}) {
			require EXTERNAL;
			my ($eref) = EXTERNAL::fetchexternal_full($USERNAME,$options{'CLAIM'});

			$eref->{'NOWIS'} = time();
			$MACROS{'%ID%'} = $options{'CLAIM'};
			$MACROS{'%NAME%'} = $eref->{'BUYER_EMAIL'};
			# $MACROS{'%WEBSITE%'} = 'http://'.lc($eref->{'MERCHANT'}).'.zoovy.com';
			$MACROS{'%ORIGIN%'} = $eref->{'MKT'}.' '.$eref->{'MKT_LISTINGID'};
			$MACROS{'%PRODUCT%'} = $eref->{'PROD_NAME'};
			$MACROS{'%PRICE%'} = $eref->{'PRICE'};
			$MACROS{'%QUANTITY%'} = $eref->{'QTY'};
			$MACROS{'%PORTAL%'} = $eref->{'MKT'};

			$MACROS{'%CHANNEL%'} = $eref->{'CHANNEL'};
			$MACROS{'%PRODUCTID%'} = $eref->{'SKU'};
			$MACROS{'%MARKETURL%'} = &EXTERNAL::linkto($eref);
			$MACROS{'%MARKETID%'} = $eref->{'MKT_LISTINGID'};
			$MACROS{'%DAYSREMAINING%'} = int( ($eref->{'EXP'} - $eref->{'NOWIS'}) / 86400 );
			$MACROS{'%FEEDBACKURL%'} = $options{'FB_URL'};
			$RECIPIENT = $MACROS{'%NAME%'};
			}


		if (defined $options{'PRODUCT'}) {

			if (defined $options{'VARS'}) {
				if (defined $options{'VARS'}->{'sentfrom'}) {
					## OLD TELL A FRIEND VARS:
					## sentfrom  - name of sender
					## sender - (email of sender)
					## recipient - 
					## title - (now is sender_subject)
					## message -  (now is sender_body)
					$options{'VARS'}->{'sender_subject'} = $options{'VARS'}->{'title'};
					$options{'VARS'}->{'sender_body'} = $options{'VARS'}->{'message'};
					$options{'VARS'}->{'sender_name'} = $options{'VARS'}->{'sentfrom'};
					}
				}

			my $PID = $options{'PRODUCT'};
			my ($P) = PRODUCT->new($USERNAME,$options{'PRODUCT'},'create'=>0);
			
			if (defined $P) {
				$SITE->sset('_SKU',$PID);
				my $prodimage = $P->thumbnail();
	
				$MACROS{'%PRODUCTID%'} = $PID;
				$MACROS{'%PROD_IMAGE_TAG%'} = '<img src="'.
					&ZOOVY::mediahost_imageurl($USERNAME, $P->thumbnail(), 200, 200, 'FFFFFF', 0, 'jpg').
					'" width=200 height=200 border=0>';
				$MACROS{'%PROD_NAME%'} = $P->fetch('zoovy:prod_name');

				$MACROS{'%PROD_DESC%'} = $SITE->URLENGINE()->wiki_format($P->fetch('zoovy:prod_desc'));
				$MACROS{'%BASE_PRICE%'} = $P->fetch('zoovy:base_price');

				## copy in some user content, and take out characters that may muck with headers.	
				$MACROS{'%SENDER_NAME%'} = &SITE::EMAILS::untaint($options{'VARS'}->{'sender_name'});
				$MACROS{'%SENDER_BODY%'} = &SITE::EMAILS::untaint($options{'VARS'}->{'sender_body'});
				$MACROS{'%SENDER_SUBJECT%'} = &SITE::EMAILS::untaint($options{'VARS'}->{'sender_subject'});
				$MACROS{'%ADDTOCART%'} = $P->button_buyme($self->_SITE());
				}
			}

		## CUSTOMER EMAILS:
		if ((defined $options{'CUSTOMER'}) && (ref($options{'CUSTOMER'}) eq 'CUSTOMER') ) {
			my $c = $options{'CUSTOMER'};
			$MACROS{'%PASSWORD%'} = $c->get('INFO.PASSWORD');
			if ($MSGID eq 'CUSTOMER.PASSWORD.REQUEST') {
				&ZOOVY::log($USERNAME,"*SYSTEM","EMAIL-CUSTOMER.PASSWORD.REQUEST","INFO",sprintf("reset password for customer %d",$c->cid()));
				$MACROS{'%PASSWORD%'} = $c->initpassword();
				}

			$MACROS{'%FIRSTNAME%'} = $c->get('INFO.FIRSTNAME'); 
			$MACROS{'%LASTNAME%'} = $c->get('INFO.LASTNAME'); 
			if ((defined $MACROS{'%FIRSTNAME%'}) && ($MACROS{'%FIRSTNAME%'} ne '')) {
				$MACROS{'%FULLNAME%'} = $MACROS{'%FIRSTNAME%'}.' '.$c->get('INFO.LASTNAME')
				}
			$MACROS{'%EMAIL%'} = $c->get('INFO.EMAIL');
			if ($RECIPIENT eq '') { $RECIPIENT = $c->get('INFO.EMAIL'); }
	
			$MACROS{'%REWARD_BALANCE%'} = $c->get('INFO.REWARD_BALANCE');

			if ($MSGID =~ /^CUSTOMER\.GIFTCARD/) {
				require GIFTCARD;
				$MACROS{'%ADDITIONAL_TEXT%'} = '';
				my $html = '';
				my $has_multiple = ( scalar( @{$c->giftcards()} )>1 )?1:0;
				if ($has_multiple) {
					# we include NOTES on each line if there is more than one giftcard
					$MACROS{'%ADDITIONAL_TEXT%'} = 'A list of your giftcards is below';
					}

				foreach my $gcref (@{$c->giftcards()}) {
					if (not $has_multiple) { $MACROS{'%ADDITIONAL_TEXT%'} = $gcref->{'NOTE'}; }
					$html .= "<tr>";
					$html .= sprintf("<td>%s</td>\n",&GIFTCARD::obfuscateCode($gcref->{'CODE'},-1));
					$html .= sprintf("<td>\$%.2f</td>\n",$gcref->{'BALANCE'});
					$html .= sprintf("<td>%s</td>\n",&ZTOOLKIT::pretty_date($gcref->{'EXPIRES_GMT'},0));
					if ($has_multiple) { $html .= sprintf("<td>%s</td>\n",$gcref->{'NOTE'}); }
					$html .= "</tr>\n";
					}
				if ($html ne '') {
					$html = qq~<table cellpadding=2 cellspacing=2>
<tr>
	<td><b>Giftcard</b></td>
	<td><b>Balance</b></td>
	<td><b>Expires</b></td>
	~.(($has_multiple)?"<td><b>Note</b></td>":'').qq~
</tr>
$html
</table>~;
					}
				$MACROS{'%GIFTCARDS%'} = $html;
				}


			}

		$MACROS{'%IPADDRESS%'} = $ENV{'REMOTE_ADDR'};


		if (not defined $options{'NEWOID'}) {}
		elsif ($MSGID ne 'OSPLIT') {}
		elsif ($options{'NEWOID'} eq '') {
			$ERR = 3001;  ## OSPLIT messages *require* NEWOID so we don't create blank orders
			}
		else {
			## SPLIT ORDERS
			# my ($o2) = ORDER->new($SITE->username(), $options{'NEWOID'}, new=>0, turbo=>1);
			my ($O2) = CART2->new_from_oid($SITE->username(), $options{'NEWOID'});
			if ((defined $O2) && (ref($O2) eq 'CART2')) {			
				##
				## before 12/22/11:
				## cheap hack rationale:
				##		a few minutes before zero hour (launch) of a new release of ZID we find out that it doesn't support
				##		split emails.. how f'd up is that?? it's 7:30pm .. and I gotta solve it. here's the solution:
				##
				##		so we grab the element ID cart out of the template (gee I hope that exists!)
				##		then we copy the cart element, change the ID to **SPLITCART**, and set 
				##		the *OID and *ORDER fields in the iniref to ORDER objects [[yeah i know how bad this is]]
				##		and push the whole mess onto the TOXML _ELEMENTS stack! [[haha yeah i know how f'd up this is]]
				##		finally we push one more element on to _ELEMENTS which creates a sub called HTMLSPLITCONTENTS
				##

				## 12/22/11: we are no longer rendering cart elements in emails (this was a very bad idea), and it 
				##				 didn't work.
			
				$MACROS{'%HTMLSPLITCONTENTS%'} = &order_contents($O2,price=>1);
				$MACROS{'%SPLITCONTENTS%'} = $MACROS{'%HTMLSPLITCONTENTS%'}; 
				$MACROS{'%HTMLSPLITSKUQTY%'} = &order_contents($O2);
				$MACROS{'%SPLITSKUQTY%'} = $MACROS{'%HTMLSPLITSKUQTY%'}; 

				$MACROS{'%SPLITID%'} = $options{'NEWOID'};
				}
			}


		## 
		## TICKET EMAILS
		## 
		if ((defined $options{'*CT'}) && (ref($options{'*CT'}) eq 'CUSTOMER::TICKET')) {
			my ($CT) = $options{'*CT'};
			$MACROS{'%TKTCODE%'} = $CT->tktcode();
			$MACROS{'%TKTSUBJECT%'} = $CT->get('SUBJECT');
			require DOMAIN::TOOLS;
			$MACROS{'%CUSTOMER_URL%'} = sprintf("http://%s/customer",&DOMAIN::TOOLS::domain_for_prt($CT->username(),$CT->prt()));
			}
			
		##
		## ORDER EMAILS
		##
		if ((defined $options{'*CART2'}) && (ref($options{'*CART2'}) eq 'CART2')) {
			my ($O2) = $options{'*CART2'};

			## use the global $SITE::URL if it's set (note: this should *probably* be explicitly passed in at some point)
			if (not defined $self->_SITE()->URLENGINE()) {
				my $sdomain = $O2->in_get('our/sdomain');
				if ($sdomain eq 'ebay.com') { $sdomain = undef; }
				if ($sdomain eq 'amazon.com') { $sdomain = undef; }
				if ($sdomain eq 'newegg.com') { $sdomain = undef; }
				$self->_SITE()->sset('sdomain',$sdomain);				
				}

			my $attribs = $O2->get_legacy_order_attribs_as_hashref();
			foreach my $attr (keys %{$attribs}) {
				$MACROS{'%'.lc($attr).'%'} = $attribs->{$attr};
				}


			## the fundamental question is:
			##		 if sdomain is set to "zoovy", "amazon", "sdomain", etc. then what do we do?
			##		answer -- figure out which profile and use the primary domain
	
			if ((not defined $options{'DOMAIN'}) && ($O2->in_get('our/sdomain') ne '')) {
				$options{'DOMAIN'} = $O2->in_get('our/sdomain');
				## these domains are not configured for rewrites (use the profile instead!)
				if ($options{'DOMAIN'} eq 'ebay.com') { $options{'DOMAIN'} = ''; }
				elsif ($options{'DOMAIN'} eq 'unknown') { $options{'DOMAIN'} = ''; }
				elsif ($options{'DOMAIN'} eq 'amazon.com') { $options{'DOMAIN'} = ''; }
				elsif ($options{'DOMAIN'} eq 'zoovy') { $options{'DOMAIN'} = ''; }
				if ($options{'DOMAIN'} eq '') {
					require DOMAIN::TOOLS;
					$options{'DOMAIN'} = &DOMAIN::TOOLS::domain_for_prt($O2->username(),$O2->prt());					
					}
				}
			elsif (not defined $options{'PROFILE'}) {
				warn("SITE::EMAIL Profile no longer supported");
				$options{'DOMAIN'} = '';
				}


			if ($O2->in_get('mkt/amazon_orderid') ne '') {
				$MACROS{'%PORTAL%'} = "Amazon";
				$MACROS{'%AMAZON_ORDERID%'} = $O2->in_get('mkt/amazon_orderid');
				$MACROS{'%MARKETID%'} = $MACROS{'%AMAZON_ORDERID%'};
				$MACROS{'%MARKETURL%'} = "http://www.amazon.com";
				$MACROS{'%ORIGIN%'} = $MACROS{'%PORTAL%'}." ".$MACROS{'%AMAZON_ORDERID%'};
				}
	
			my $stuff2 = $O2->stuff2();
			$MACROS{'%TRACKINGINFO%'} = '';
			$MACROS{'%HTMLTRACKINGINFO%'} = '';

			$MACROS{'%HTMLTRACKINGINFO%'} = '<table class="trackinfo">';
			if (defined $O2->tracking()) {
				foreach my $trkref (@{$O2->tracking()}) {
					next if ($trkref->{'void'} > 0);
					my $shipref = &ZSHIP::shipinfo($trkref->{'carrier'});
					my ($link,$text) = ('','');
					if ($trkref->{'track'} ne '') {
						($link,$text) = &ZSHIP::trackinglink($shipref,$trkref->{'track'});
						}

					$MACROS{'%TRACKINGINFO%'} .= "$trkref->{'carrier'} - $trkref->{'track'}\n";
					if ($link ne '') { $MACROS{'%TRACKINGINFO%'} .= "$text: $link\n"; }

					$MACROS{'%HTMLTRACKINGINFO%'} .= "<tr>
<td class='line'>$trkref->{'method'}</td>
<td class='line'>$trkref->{'track'}</td>
<td class='line'><a href=\"$link\">$text</a></td>
</tr>
";
					}
				}
			$MACROS{'%HTMLTRACKINGINFO%'} .= '</table>';

			$MACROS{'%HTMLPAYINFO%'} = $O2->explain_payment_status('format'=>'summary','html'=>1,'*SITE'=>$self->_SITE());
			$MACROS{'%PAYINFO%'} = &ZTOOLKIT::htmlstrip($MACROS{'%HTMLPAYINFO%'});
			$MACROS{'%HTMLPAYINSTRUCTIONS%'} = $O2->explain_payment_status('format'=>'detail','html'=>1,'*SITE'=>$self->_SITE());
			$MACROS{'%PAYINSTRUCTIONS%'} = &ZTOOLKIT::htmlstrip($MACROS{'%HTMLPAYINSTRUCTIONS%'});

			$MACROS{'%ORDERID%'} = $O2->oid();
			$MACROS{'%CARTID%'} = $O2->in_get('cart/cartid');
			$MACROS{'%EREFID%'} = $O2->in_get('want/erefid');


			$MACROS{'%ORDERURL%'} = $self->_SITE()->URLENGINE()->get('customer_url').'/order/status?'.&ZTOOLKIT::buildparams({'orderid'=>$O2->oid(),'cartid'=>$O2->in_get('cart/cartid')});
			$MACROS{'%ORDERFEEDBACK%'} = $self->_SITE()->URLENGINE()->get('customer_url').'/order/feedback?'.&ZTOOLKIT::buildparams({'orderid'=>$O2->oid(),'cartid'=>$O2->in_get('cart/cartid')});

			$MACROS{'%REFNUM%'} = $O2->oid();
			$MACROS{'%NAME%'} = $attribs->{'bill_firstname'}.' '.$attribs->{'bill_lastname'};
			$MACROS{'%FULLNAME%'} = $attribs->{'bill_firstname'}.' '.$attribs->{'bill_lastname'},
			$MACROS{'%FIRSTNAME%'} = $attribs->{'bill_firstname'},
			$MACROS{'%EMAIL%'} = $attribs->{'bill_email'},
			$MACROS{'%ORDERNOTES%'} = $attribs->{'order_notes'},
			$MACROS{'%ORDERNOTES%'} =~ s/[\n]/<br>/g;
			$MACROS{'%DATE%'} = &ZTOOLKIT::pretty_date($attribs->{'created'}, 0),
			$MACROS{'%TODAY%'} = &ZTOOLKIT::pretty_date(time(), 0),
			$MACROS{'%SHIPMETHOD%'} = $attribs->{'shp_method'},
			# $MACROS{'%HTMLPAYINSTRUCTIONS%'} = $MACROS{'%PAYINSTRUCTIONS%'};
	
			require STUFF;
			my $txtout = sprintf("%25s\t%55s\t%5s\n",'SKU','DESCRIPTION','QTY');
			my $htmlout = '<table class="invoice">';
			$htmlout .= "<tr><td class='title'>SKU</td><td class='title'>Description</td><td class='title'>Qty</td></tr>";		
			my $class = '';
			foreach my $item (@{$O2->stuff2()->items()}) {
				my $stid = $item->{'stid'};

				# Extract all of the components of the cart
				my ($pid,$claim,$invopts) = &PRODUCT::stid_to_pid($stid);
				my $SKU = $pid . ((defined $invopts)?$invopts:'');

				$class = ($class eq 'item0')?'item1':'item0';

				$txtout .= sprintf("%25s\t%55s\t%5s\n",$SKU,$item->{'description'},$item->{'qty'});
				$htmlout .= sprintf("<tr class=\"$class\"><td valign=\"top\" nowrap>%s</td valign=\"top\"><td valign=\"top\">%s</td valign=\"top\"><td valign=\"top\">%s</td valign=\"top\"></tr>",$SKU,$item->{'description'},$item->{'qty'});
				}
			$htmlout .= "</table>";
			$MACROS{'%PACKSLIP%'} = $txtout;
			$MACROS{'%HTMLPACKSLIP%'} = $htmlout;

			## NOTE: CONTENTS IS GENERATED IN THE EMAIL TEMPLATE ITSELF VIA A CART ELEMENT!		
#			($MACROS{'%HTMLCONTENTS%'}) = &order_contents($o);
#			$MACROS{'%CONTENTS%'} = $MACROS{'%HTMLCONTENTS%'}; 

			(undef,$MACROS{'%HTMLBILLADDR%'}) = &SITE::EMAILS::text_addr('bill',$attribs);
			$MACROS{'%BILLADDR%'} = $MACROS{'%HTMLBILLADDR%'};
			(undef,$MACROS{'%HTMLSHIPADDR%'}) = &SITE::EMAILS::text_addr('ship',$attribs);
			$MACROS{'%SHIPADDR%'} = $MACROS{'%HTMLSHIPADDR%'};
		
		# strip HTML in cart contents (non HTML)
		# $TAGS{'%CONTENTS%'} =~ s/<(.*?)>//g;
		# $TAGS{'%PACKSLIP%'} =~ s/<(.*?)>//g;	

			$MACROS{'%NOTE%'} = $options{'NOTE'};

			if ($RECIPIENT eq '') { $RECIPIENT = $O2->in_get('bill/email'); }
			print STDERR "FINISHED O!\n";
			}


		#print STDERR "[tagref] ".Dumper($tagref);
		$options{'PROFILE'} = "#".$SITE->prt();
		$options{'PROFILEREF'} = $SITE->nsref();

		$MACROS{'%WEBSITE%'} = "http://$USERNAME.zoovy.com";
		$MACROS{'%SDOMAIN%'} = "$USERNAME.zoovy.com";
		if ($options{'DOMAIN'} ne '') {
			$MACROS{'%WEBSITE%'} = "http://$options{'DOMAIN'}";
			$MACROS{'%SDOMAIN%'} = "$options{'DOMAIN'}";
			}
		$MACROS{'%COMPANYNAME%'} = $options{'PROFILEREF'}->{'zoovy:company_name'};
		$MACROS{'%SUPPORTEMAIL%'} = $options{'PROFILEREF'}->{'zoovy:support_email'};
		$MACROS{'%COMPANY_EMAIL%'} = $options{'PROFILEREF'}->{'zoovy:support_email'};
		$MACROS{'%SUPPORTPHONE%'} = $options{'PROFILEREF'}->{'zoovy:support_phone'};
		##
		## SANITY: at this point we really ought to have the following stuff set:
		## 
		my $output = '';

		# print Dumper($toxml);

		## wiki 1 = enable
		## wiki 2 = html strip
		## wiki 4 = creole wiki
		my $WIKI = 2+4;
		if ($MSGREF->{'MSGFORMAT'} eq 'HTML') { $WIKI = 0; }
		elsif ($MSGREF->{'MSGFORMAT'} eq 'TEXT') { $WIKI = 0;  $BODY = "<pre>$BODY</pre>"; }


		my %SUBS = ();

		if ((defined $options{'LAYOUT'}) && ($options{'LAYOUT'}==0)) {
			## don't put the email message inside a wrapper (used inside notify)
			## this used by eBay to send a message
			warn Carp::cluck("SITE::EMAIL took layout path [ebay?] (*** NEEDS LOVE ***)");
			} 
		else {
			##
			## AT LITTLE REFRESHER HOW THIS WORKS
			##		all email toxml layouts reference a DIV called 'EMAILBODY'
			##		we automatically create that div below and push it onto the TOXML document
			##		then it gets processed like any other document with DIV's
			##

			($BODY) = &interpolate_macros($MSGREF->{'MSGTYPE'},$BODY,\%MACROS);
			# $WIKI = 2 + 4;
			warn "SITE::EMAIL took standard render route\n";
			my %ELEMENT = (
				ID=>'EMAILBODY', TYPE=>'TEXT', WIKI=>$WIKI, RAW=>1,DATA=>'', DEFAULT=>$BODY,
				);
			push @{$toxml->{'_DIVS'}}, { ID=>'EMAILBODY', _ELEMENTS=>[ \%ELEMENT ] };

			## PHASE 1: Preprocess, this will go through and do simple interpolation and layout.
			# ($BODY) = $toxml->render('*SITE'=>$self->_SITE(),'%SUBS'=>\%SUBS,'*CART2'=>$options{'*CART2'});
			($BODY) = $toxml->render('*SITE'=>$self->_SITE(),'%SUBS'=>\%SUBS,'*CART2'=>$options{'*CART2'});
			$BODY = $BODY.$html;
			}

		

#		open F, ">>/tmp/blah";	print F $BODY; 	close F; die();
#		open F, ">/tmp/body";
#		print F Dumper($BODY,$toxml);
#		close F;
		

		## PHASE 2: We run a final specl translation layer.

		##	
		## first we use any defaults macros that may be necessary.  
		## 	(keep in mind that they wouldn't appear, if they were also set in the toxml document)
		##		
		($BODY) = &interpolate_macros($MSGREF->{'MSGTYPE'},$BODY,\%MACROS);
		## next we interpolate any variables setup by the LAYOUT across the top of our new macros we added.
		($BODY) = &interpolate_macros(undef,$BODY,\%SUBS);

		## finally we run any specl code.. that might have been added.
		require TOXML::SPECL3;
		my ($txspecl) = $self->_SITE()->txspecl();
		# ($BODY) = &TOXML::SPECL3::translate3($BODY,[\%SUBS,$options{'VARS'}],replace_undef=>0);
		($BODY) = $txspecl->translate3($BODY,[\%SUBS,$options{'VARS'}],replace_undef=>0);

#		print STDERR "BODY: $BODY\n";
#		print STDERR Dumper(\%SUBS);

		($SUBJECT) = &interpolate_macros($MSGREF->{'MSGTYPE'},$SUBJECT,\%MACROS);
		# ($SUBJECT) = &TOXML::SPECL::translate($SUBJECT,[\%SUBS,$options{'VARS'}],replace_undef=>0);
		$SUBJECT = $txspecl->translate3($SUBJECT,[\%SUBS,$options{'VARS'}],replace_undef=>0);
		}

	my $BCC = $MSGREF->{'MSGBCC'};
	if (defined $options{'BCC'}) { $BCC = $options{'BCC'}; }

	return($ERR, { 
		SUBJECT=>$SUBJECT, 
		FORMAT=>$MSGREF->{'MSGFORMAT'},
		DOCID=>$docid,
		FROM=>$FROM,
		TO=>$RECIPIENT,
		BCC=>$BCC,
		BODY=>$BODY,
		}
		);
	}

##
## determines if a specific message id exists.
##
sub exists {
	my ($self,$MSGID) = @_;
	my ($MSGREF) = $self->getref($MSGID);
	return( (defined $MSGREF->{'ID'})?1:0 );
	}

##
## 
##
sub send { return(sendmail(@_)); }
sub sendmail {
	my ($self,$MSGID,%options) = @_;

	if ($MSGID eq 'OCREATE') { $MSGID = 'ORDER.CONFIRM'; }
	if ($MSGID eq 'OCUSTOM1') { $MSGID = 'ORDER.CUSTOM_MESSAGE1'; }
	if ($MSGID eq 'OCUSTOM2') { $MSGID = 'ORDER.CUSTOM_MESSAGE2'; }
	if ($MSGID eq 'ODENIED') { $MSGID = 'ORDER.CONFIRM_DENIED'; }
	if ($MSGID eq 'OMERGE') { $MSGID = 'ORDER.MERGED'; }

	if ($MSGID eq 'OFBAMAZON') { $MSGID = 'ORDER.FEEDBACK.AMZ'; }
	if ($MSGID eq 'FEEDBACK') { $MSGID = 'ORDER.FEEDBACK.EBAY'; }
	if ($MSGID eq 'OSPLIT') { $MSGID = 'ORDER.SPLIT'; }

	if ($MSGID eq 'ORDER.SHIP.EBAY') { $MSGID = 'ORDER.SHIPPED.EBAY'; }
	if ($MSGID eq 'ORDER.SHIP.AMZ') { $MSGID = 'ORDER.SHIPPED.AMZ'; }

	if ($MSGID eq 'PAYREMIND') { $MSGID = 'ORDER.PAYMENT_REMINDER'; }
	if ($MSGID eq 'STATAPPR') { $MSGID = 'ORDER.MOVE.APPROVED'; }
	if ($MSGID eq 'STATBACK') { $MSGID = 'ORDER.MOVE.BACKORDER'; }
	if ($MSGID eq 'STATCOMP') { $MSGID = 'ORDER.MOVE.COMPLETED'; }
	if ($MSGID eq 'STATKILL') { $MSGID = 'ORDER.MOVE.CANCEL'; }
	if ($MSGID eq 'STATPEND') { $MSGID = 'ORDER.MOVE.PENDING'; }
	if ($MSGID eq 'STATPRE') { $MSGID = 'ORDER.MOVE.PREORDER'; }
	if ($MSGID eq 'STATPROC') { $MSGID = 'ORDER.MOVE.PROCESSING'; }
	if ($MSGID eq 'STATRECN') { $MSGID = 'ORDER.MOVE.RECENT'; }
	if ($MSGID eq 'TRACKING') { $MSGID = 'ORDER.SHIPPED'; }

	use Data::Dumper;

	if (not defined $options{'PRT'}) {
		$options{'PRT'} = $self->prt();
		}

	my $SITE = $options{'*SITE'};
	if (not defined $SITE) { $SITE = $self->_SITE(); }
	$options{'*SITE'} = $SITE;

	my ($ERR, $result) = $self->createMsg($MSGID,%options);

	## add the body and /html tags back in!
	if ($ERR) {
		warn Carp::cluck("EMAIL ERR:$ERR\n");
		}
	elsif ($result->{'FORMAT'} eq 'DONOTSEND') {
		## don't send this message - no matter what.		
		}
	else {
		# use MIME::Lite package
		require MIME::Lite;
		my $SUBJECT = $result->{'SUBJECT'};
		my $docid = $result->{'DOCID'};
		my $FROM = $result->{'FROM'};
		my $RECIPIENT = $result->{'TO'};
		my $BCC = $result->{'BCC'};
		my $BODY = $result->{'BODY'};

		my %v = ();
		if ($ENV{'REMOTE_ADDR'}) { $v{'ip'} = $ENV{'REMOTE_ADDR'}; }

		$v{'u'} = sprintf("%s.%d",$SITE->username(),int($options{'PRT'}));
		# $v{'p'} = $self->profile();
		$v{'prt'} = $self->prt();
		$v{'doc'} = $docid;
		$v{'msg'} = $MSGID;
		$v{'ex'} = lc($result->{'TO'});
		$v{'ex'} =~ tr/abcdefghijklmnopqrstuvwyz/zywvutsrqponmlkjihgfedcba/; # simple reverse substition
		my $str = '';
		foreach my $k (sort keys %v) { $str .= "$k=$v{$k}:"; }
		chop($str);
		# print "STR: $str\n";

		my $msg = MIME::Lite->new( 
			'X-Mailer'=>"Zoovy-Automail/4.1 [ip=:d=:u=".$SITE->username().":prt=".$self->prt().":doc=$docid:msg=$MSGID]",
			'Reply-To'=>$FROM,
			'Errors-To'=>$FROM,
			'Return-Path'=>$FROM,
			'Disposition'=>'inline',
			From => $FROM, 
			To => $RECIPIENT, 
			Bcc => $BCC,
			Subject => $SUBJECT, 
			Type=>'text/html',
			Data => $BODY, 
#			Encoding => 'quoted-printable'
			);

		$msg->attr("content-type"         => "text/html");
		$msg->attr("content-type.charset" => "US-ASCII");
#		$msg->attr("content-type.name"    => "homepage.html");

		my $qtFROM = quotemeta($FROM);
		$msg->send("sendmail", "/usr/lib/sendmail -t -oi -B 8BITMIME -f $FROM");
		# MIME::Lite->send("sendmail", "/bin/cat >/tmp/foo");
		
		}
	

#	print STDERR "DONE WITH SENDMAIL\n";
	return($ERR);
	}


##
## UTILITIES:
##
## sub profile { return($_[0]->{'_PROFILE'}); }
sub username { return($_[0]->{'_USERNAME'}); }
sub prt { return($_[0]->{'_PRT'}); }

##
## dumb function, will return the best email for a particular user
##
#sub from; {
#	my ($self) = @_;
#
#	my $nsref = &ZOOVY::fetchmerchantns_ref($self->username(), $self->profile());
#	my $email = $nsref->{'zoovy:support_email'};
#	if ((!defined($email)) || ($email eq '')) { 
#		$email = $nsref->{'zoovy:email'};
#		}
#	
#	#my $email = &ZOOVY::fetchmerchantns_attrib($SITE->username(),$self->profile(),"zoovy:support_email");
#	#if ((!defined($email)) || ($email eq '')) { 
#	#	$email = &ZOOVY::fetchmerchantns_attrib($SITE->username(),$self->profile(),"zoovy:email"); 
#	#	}
#
#	return($email);
#	}



sub _SITE { return($_[0]->{'*SITE'}); }
sub export { return($_[0]->{'_GLOBALS'}); }

##
## VALID OPTIONS: 
##
## RAW = no interpolation will occur.
##	an object:
##		CUSTOMER = a reference to a customer object
##		ORDER = a reference to the cart we should use for interpolation
##		INCOMPLETE = a reference to the webdb file
##
##	PRT = the partition in focus
## NS = the profile in focus
##
sub new {
	my ($class, $USERNAME, %options) = @_;

	my $self = {};

	my $SITE = undef;
	if (defined $options{'*SITE'}) {
		$SITE = $self->{'*SITE'} = $options{'*SITE'};		
		}
	else {
		&ZOOVY::confess($USERNAME,"SITE::EMAILS->new requires *SITE object -- emulating one");
		}

	#if ($options{'GLOBALS'}) {
	#	## hmm.. we need to initialize global variables.
	#	$SITE::SREF = $SITE->export();
	#	$self->{'_GLOBALS'}++;
	#	# $SITE::SREF->{'%NSREF'} = &ZOOVY::fetchmerchantns_ref($USERNAME,$PROFILE);	
	#	#$SITE::webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,$options{'PRT'});
	#	#$SITE::SREF->{'+prt'} = $options{'PRT'};
	#	}


	if (not defined $options{'LANG'}) { $options{'LANG'} = 'ENG'; }
	
	$self->{'_DOMAIN'} = $options{'DOMAIN'};
	$self->{'_LANG'} = $options{'LANG'};
	$self->{'_MID'} = int(&ZOOVY::resolve_mid($USERNAME));
	$self->{'_USERNAME'} = $SITE->username();
	$self->{'_PROFILE'} = '#'.$SITE->prt();
	$self->{'_PRT'} = $SITE->prt();

	if (defined $options{'RAW'}) { 
		$self->{'_RAW'}++; 
		$self->{'%VARS'} = {};
		}
	else {
#		if (defined $options{'CART'}) { $self->{'_CART'} = $options{'CART'}; }
#		if (defined $options{'WEBDB'}) { $self->{'_WEBDB'} = $options{'WEBDB'}; }
		}
	
	bless $self, 'SITE::EMAILS';

	if ($self->{'_RAW'}==0) {
		# $self->refresh();
		}

#	use Data::Dumper; print Dumper($self);

	return($self);
	}





##
## returns a list of available msgid's
##		which is an arrayref of MSGID,MSGSUBJECT,MSGTYPE,CREATED_GMT,LUSER
##
## MSGTYPE can be:
##		ORDER
##		INCOMPLETE
##		ACCOUNT
sub available {
	my ($self,$msgtype) = @_;

	$msgtype = uc($msgtype);
	my $MID = $self->{'_MID'};
	# my $PROFILE = $self->profile();
	my $PRT = $self->prt();

	my %RESULTS = ();
	my $dbh = &DBINFO::db_user_connect($self->username());
	my $pstmt = "select MSGID,MSGSUBJECT,MSGTYPE,MSGFORMAT,CREATED_GMT,LUSER,MSGBODY,MSGBCC from SITE_EMAILS where MID=$MID and PRT=".int($PRT);
	if ($msgtype ne '') { $pstmt .= ' and MSGTYPE='.$dbh->quote($msgtype); }
	$pstmt .= " order by MSGID";

	print STDERR $pstmt."\n";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		my $MSGID = $hashref->{'MSGID'};

		if (defined $SITE::EMAILS::DEFAULTS{$MSGID}) {
			$hashref->{'MSGTITLE'} = $SITE::EMAILS::DEFAULTS{$MSGID}->{'MSGTITLE'};
			}
		$RESULTS{$MSGID} = $hashref;
		}
	$sth->finish();

	##
	## LOAD DEFAULTS
	##
	foreach my $MSGID (keys %SITE::EMAILS::DEFAULTS) {
		my $msgref = $SITE::EMAILS::DEFAULTS{$MSGID};
		next if (($msgtype ne '') && ($msgref->{'MSGTYPE'} ne $msgtype));
		next if (defined $RESULTS{$MSGID});
		$RESULTS{$MSGID} = $SITE::EMAILS::DEFAULTS{$MSGID};
		$RESULTS{$MSGID}->{'MSGID'} = $MSGID;
		}


	my @X = values(%RESULTS);

	&DBINFO::db_user_close();
	return(\@X);
	}


##
##
##
sub getref {
	my ($self, $msgid, $lang) = @_;

	$msgid = uc($msgid);
	my %ref = ();

	if (defined $SITE::EMAILS::DEFAULTS{$msgid}) {
		## note: we make a fresh copy of variables in SITE::EMAILS in case we add MSGFROM or something like that.
		%ref = %{$SITE::EMAILS::DEFAULTS{$msgid}};
		$ref{'DEFAULTBODY'} = $ref{'MSGBODY'};
		$ref{'DEFAULTTITLE'} = $ref{'MSGTITLE'};
		}
	$ref{'CREATED_GMT'} = 0;
	$ref{'LUSER'} = '';

	if (not defined $lang) { $lang = $self->{'_LANG'}; }

	my $dbh = &DBINFO::db_user_connect($self->username());
	my $qtMSGID = $dbh->quote($msgid);
	my $qtLANG = $dbh->quote($lang);
	my $PRT = int($self->prt());

	my $pstmt = "select * from SITE_EMAILS where MID=$self->{'_MID'} /* $self->{'_USERNAME'} */ and PRT=$PRT and MSGID=".$qtMSGID." and LANG=".$qtLANG;
	print STDERR $pstmt."\n";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	if ($sth->rows()) {
		my $hashref = $sth->fetchrow_hashref();
		foreach my $k (keys %{$hashref}) {
			$ref{$k} = $hashref->{$k};
			}
		}
	$sth->finish();
	&DBINFO::db_user_close();

	## a couple of quick fixup rules
	if ($ref{'MSGTITLE'} eq '') { $ref{'MSGTITLE'} = $ref{'MSGID'}; }

	return(\%ref);
	}



##
## Okay, so the idea EVENTUALLY is to have the MACROS's not contain content, but rather contain specl
##		that outputs the correct values.. but for now, the MACROS contain the actual content (making it
##		unusable to JT)
##
sub interpolate_macros {
	my ($MSGTYPE,$txt,$MACREF) = @_;

	foreach my $m (keys %{$MACREF}) {
		next unless (index($txt,$m)>=0);
		$txt =~ s/$m/$MACREF->{$m}/g;
		}
	
	# '%NAME%'=>'<% print("Brian"); %>',

	## NO MACRO INTERPOLATION YET!
	return($txt);
	}


##
##
##
sub save {
	my ($self, $msgid, %options) = @_;

	$msgid = lc($msgid);

#mysql> desc SITE_EMAILS;
#+-------------+----------------------+------+-----+---------+----------------+
#| Field       | Type                 | Null | Key | Default | Extra          |
#+-------------+----------------------+------+-----+---------+----------------+
#| ID          | int(10) unsigned     | NO   | PRI | NULL    | auto_increment |
#| USERNAME    | varchar(20)          | NO   |     | NULL    |                |
#| MID         | int(10) unsigned     | NO   | MUL | 0       |                |
#| PROFILE     | varchar(10)          | NO   |     | NULL    |                |
#| PRT         | smallint(5) unsigned | NO   |     | 0       |                |
#| LANG        | varchar(3)           | NO   |     | ENG     |                |
#| MSGID       | varchar(10)          | NO   |     | NULL    |                |
#| MSGSUBJECT  | varchar(60)          | NO   |     | NULL    |                |
#| MSGBODY     | mediumtext           | NO   |     | NULL    |                |
#| MSGFROM     | varchar(65)          | NO   |     | NULL    |                |
#| MSGBCC      | mediumtext           | NO   |     | NULL    |                |
#| CREATED_GMT | int(10) unsigned     | YES  |     | 0       |                |
#| LUSER       | varchar(10)          | NO   |     | NULL    |                |
#+-------------+----------------------+------+-----+---------+----------------+
#13 rows in set (0.00 sec)

	if (not defined $options{'FORMAT'}) { $options{'FORMAT'} = $options{'MSGFORMAT'}; }
	if (not defined $options{'BODY'}) { $options{'BODY'} = $options{'MSGBODY'}; }
	if (not defined $options{'SUBJECT'}) { $options{'SUBJECT'} = $options{'MSGSUBJECT'}; }
	if (not defined $options{'TYPE'}) { $options{'TYPE'} = $options{'MSGTYPE'}; }
	if (not defined $options{'BCC'}) { $options{'BCC'} = $options{'MSGBCC'}; }
	if (not defined $options{'FROM'}) { $options{'FROM'} = $options{'MSGFROM'}; }

	if (not defined $options{'LUSER'}) { $options{'LUSER'} = ''; }

	my $dbh = &DBINFO::db_user_connect($self->username());

	if (not defined $options{'LANG'}) { $options{'LANG'} = 'ENG'; }
	my $qtLANG = $dbh->quote($options{'LANG'});
	my $pstmt = '';
	my $result = undef;
	if ($options{'NUKE'}) { # $SITE::EMAILS::DEFAULTS->{$msgid}->{'msg'} eq $msgtxt) {
		## we should be doing a delete!
		my ($PRT) = int($options{'PRT'});
		$pstmt = "delete from SITE_EMAILS where MID=".int($self->{'_MID'})." and PRT=$PRT and MSGID=".$dbh->quote($msgid)." and LANG=$qtLANG";
		$result = 0;
		}
	else {
		my %params = ();
		$params{'USERNAME'} = $self->username();
		$params{'MID'} = $self->{'_MID'};
		# $params{'PROFILE'} = $self->profile();
		$params{'PRT'} = $self->prt();
		$params{'MSGID'} = uc($msgid);
		$params{'MSGTYPE'} = $options{'TYPE'};
		$params{'MSGSUBJECT'} = $options{'SUBJECT'};
		$params{'MSGBODY'} =  $options{'BODY'};
		if (defined $options{'FROM'}) {
			$params{'MSGFROM'} =  $options{'FROM'};
			}
		if (defined $options{'FORMAT'}) {
			$params{'MSGFORMAT'} = $options{'FORMAT'};
			}
		if (defined $options{'BCC'}) {
			$params{'MSGBCC'} =  $options{'BCC'};
			}
		$params{'CREATED_GMT'} = time();
		$params{'LUSER'} = $options{'LUSER'};
		$params{'LANG'} = $options{'LANG'};
		$pstmt =	&DBINFO::insert($dbh,'SITE_EMAILS',\%params,debug=>2,key=>['MID','PRT','MSGID','LANG'],update=>1);
		$result = 1;
		}
	print STDERR $pstmt."\n";
	$dbh->do($pstmt);

	# my $PROFILE = $self->profile();
	my $PRT = $self->prt();
	&ZOOVY::log($self->username(),$options{'LUSER'},"SYSTEM.EMAIL","Saved email $msgid on PRT:$PRT");

	&DBINFO::db_user_close();
	return($result);
	}


##
## removes characters that are non-email safe, including html.
##
sub htmlStrip {
	my ($body) = @_;
	$body =~ s/&nbsp;/ /gs;

	$body =~ s/<a.*?href=[\"\'](.*?)[\"\']>(.*?)<\/a>/$2 $1/gs;	# convert links!
	$body =~ s/\<style.*?\<\/style\>//igs;
	$body =~ s/\<script.*?\<\/script\>//igs;
	$body =~ s/\<br\>/\n\r/gs;
	$body =~ s/\<li\>/\[\*\] /gs;
	$body =~ s/<\/tr>/\n\r/igs;
	$body =~ s/<\/td>/\t/igs;
	$body =~ s/\<.*?\>//gs;
	$body =~ s/[\t]+//g; 

	$body =~ s/[\r]+//gs;	# remove lf's 
	$body =~ s/\n[\n]+/\r/gs;	# remove 2+ \n's with a \r

	my $new = '';
	foreach my $line (split(/[\n]+/,$body)) {
		$line =~ s/[ ]+/ /gs;	# strip unnecessary whitespace
		$line =~ s/^[ ]+//g; 	# strip leading whitespace
		$line =~ s/[ ]+$//g;	# strip trailing whitespace
		if ($line ne '') { 
			$new .= $line."\n";
			}
		$line =~ s/[\r]+/\n/gs;
		}
	$body = $new;
		# $body =~ s/[\n\r]+/\n\r/gs;
	return($body);
}


##
## options
##		price=>1
sub order_contents {
	my ($CART2,%options) = @_;
	require PRODUCT;

	# stuff->make_contents(),$attribs->{'tax_rate'},$attribs->{'shp_method'},$attribs->{'shp_total'}

	my $htmlout = '<table class="invoice">';
	$htmlout .= "<tr><td class='title'>SKU</td><td class='title'>Description</td><td class='title'>Qty</td>";
	if ($options{'price'}>0) {
		$htmlout .= "<td class='title'>Price</td><td class='title'>Extended</td>";
		}
	$htmlout .= "</tr>";

	my $odd = 0;
	# Loop over all of the items in the shopping cart
	my $subtotal = 0;

	foreach my $item (@{$CART2->stuff2()->items()}) {
		# my $item = $o->stuff()->{$stid};
		my $stid = $item->{'stid'};
		$odd++;
		# Extract all of the components of the cart
		my ($pid,$claim,$invopts) = &PRODUCT::stid_to_pid($stid);
		my $display = $pid . ((defined $invopts)?$invopts:'');

		my $price = $item->{'price'};
		my $qty = $item->{'qty'};
		my $description = $item->{'description'};

		my $extended = 0;
		if (&ZTOOLKIT::isdecnum($price) && &ZTOOLKIT::isnum($qty)) { $extended = $price * $qty; }
		$subtotal += $extended;

		# If we're not a special cart item, display it
		if ($item->{'qty'} > 0) {

			# Make sure the data is valid (good for extetnal items)
			my @display_ar = &ZTOOLKIT::multi_line($display,15,'left');
			my @description_ar = &ZTOOLKIT::multi_line($description,33,'left');
			my @qty_ar = &ZTOOLKIT::multi_line($qty,3,'right');
			my @price_ar = &ZTOOLKIT::multi_line(&ZTOOLKIT::moneyformat($price),10,'right');
			my @extended_ar = &ZTOOLKIT::multi_line(&ZTOOLKIT::moneyformat($extended),10,'right');

			# Get the length of the longest array
			my $max = scalar(@display_ar);
			if (scalar(@description_ar) > $max) {$max = scalar(@description_ar)}
			if (scalar(@qty_ar) > $max) {$max = scalar(@qty_ar)}
			if (scalar(@price_ar) > $max) {$max = scalar(@price_ar)}
			if (scalar(@extended_ar) > $max) {$max = scalar(@extended_ar)}
			for (my $count = 0; $count < $max; $count++) {
				my $_display = defined($display_ar[$count]) ? $display_ar[$count] : ' 'x15 ;
				my $_description = defined($description_ar[$count]) ? $description_ar[$count] : ' 'x33 ;
				my $_qty = defined($qty_ar[$count]) ? $qty_ar[$count] : ' 'x3 ;
				my $_price = defined($price_ar[$count]) ? $price_ar[$count] : ' 'x10 ;
				my $_extended = defined($extended_ar[$count]) ? $extended_ar[$count] : ' 'x10 ;

				if ($count % 2 == 0) { $item = 'item0'; } else { $item = 'item1'; }			
				$htmlout .= "<tr>";
				$htmlout .= "<td nowrap class='$item'>$_display</td>";
				$htmlout .= "<td class='$item'>$_description</td>";
				$htmlout .= "<td class='$item'>$_qty</td>";
				if ($options{'price'}>0) {
					$htmlout .= "<td class='$item'>$_price</td>";
					$htmlout .= "<td class='$item'>$_extended</td>";
					}
				$htmlout .= "</tr>\n";
				}
			}
		}

	$htmlout .= "<tr><td class='item' colspan='4' align='right'><font class='sum'>Subtotal:</td><td class='sumresult'>". &ZTOOLKIT::moneyformat($subtotal)."</td></tr>\n";
	# my $attribs = $o->get_attribs();

	if (($CART2->in_get('sum/tax_total') != 0) && ($CART2->in_get('sum/tax_total') != 0)) {
		$htmlout .= "<tr><td class='item' colspan='4' align='right'><font class='sum'>State Tax (" . $CART2->in_get('our/tax_rate') . "%):</td><td class='sumresult'>". &ZTOOLKIT::moneyformat($CART2->in_get('sum/tax_total'))."</td></tr>\n";
		}
	## SPC_ handler display the payment surcharge special cart item.
	my ($shipper,$shipping) = ();

	if (defined $shipper) { $CART2->in_get('sum/shp_method') = $shipper; }
	if (defined $shipping) { $CART2->in_get('sum/shp_total') = $shipping; }
	$shipper = $CART2->in_get('sum/shp_method');
	$shipping = $CART2->in_get('sum/shp_total');
	my $otherfees = 0;

	foreach my $x ('shp','ins','hnd','spc','bnd','spx','spy','spz') {
		## sum/shp_total sum/shp_taxable sum/bnd_taxable sum/ins_total
		next if (not defined $CART2->in_get(sprintf("sum/%s_total",$x)));
		next if (($x ne 'shp') && ($CART2->in_get(sprintf("sum/%s_total",$x)) == 0));		# always show shipping regardless of price
			## NOTE: the following line isn't needed anymore since ins_total won't be set if the insurance is optional and not selected!
			## next if (($x eq 'ins') && ($cart_webdb->{'ins_optional'}) && (not $CART2->in_get(('ins_purchased'))); # don't show insurance if it's 

		## sum/shp_method, etc.
		my $description = $CART2->in_get(sprintf("sum/%s_method",$x));
		if (($description eq '') && ($x eq 'shp')) { $description = 'Shipping'; $shipper = 'Shipping'; }
		my $total = $CART2->in_get(sprintf("sum/%s_total",$x)); 

		$htmlout .= "<tr><td class='item' colspan='4' align='right'><font class='sum'>$description</td><td class='sumresult'>". &ZTOOLKIT::moneyformat($total)."</td></tr>\n";
		next if ($x eq 'shp');
		$otherfees += $CART2->in_get(sprintf("sum/%s_total",$x));
		}
		
	# display the grand total
	# calculate the grand total (perhaps we should be calculating this in calc_producthash_totals above?)
	my $tax = $CART2->in_get('sum/tax_total');
	my $grandtotal = $subtotal + $tax + $shipping + $otherfees;
	my $_grandtotal = &ZTOOLKIT::moneyformat($grandtotal);
	$htmlout .= "<tr><td class='item' colspan='4' align='right'><font class='sum'>Grand Total</td><td class='sumresult'>$_grandtotal</td></tr>\n";
	$htmlout .= "</table>";

	return ($htmlout);
	
}




1;