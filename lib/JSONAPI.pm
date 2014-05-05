package JSONAPI;


$JSONAPI::PARTITION_OFFSET = 0;				## use this to identify code.

##
## SessionKey --- the thing that binds them all together
##						created by the client (or requested via appCartCreate)
##						this is a 32 byte guid field that is guaranteed to be unique
##
##		SessionKeys can be transferred over non-secure channels
##	
##		For a unique SessionKey the server can/will issue:
##		* CustomerKey  ==  returned by server appBuyerLogin -- 32-64 byte cryptographic hash in KEY format
##		* AdminKey 		==	 returned by server appAdminLogin -- 32-64 byte cryptographic hash in KEY format
##	
##	KEY FORMAT:
##		basic		: t=1234;k=key
##		admin		: t=1234;a=mid*luser;k=key
##		customer	: t=1234;c=cid;k=key
##
## GOAL:
##		using the SessionKey+unique signature per partition be able to verify the authenticity and 
##		identity of a request. Need to lookup what type of crypto might work best here, signature length, etc.
##

#
# Syntax:
#	<purpose></purpose>
#	<input hint="" id="parameter" required="1" optional="1" example="">description</input>
#	<response hint="" id="_cartid"></response>
#	<hint>a hint that belongs to this</hint>
#	<example></example>
#	<caution></caution>
#  <errors><err id="" type="">message</err></errors>
#

# 	&JSONAPI::set_error($R, 'apperr', 111,sprintf("A required parameter \"%s\" was not set, and is required.",$key));


use strict;

## 
$JSONAPI::MAX_CARTS_PER_SESSION = 8;

$JSONAPI::VERSION = "201403";
$JSONAPI::VERSION_MINIMUM = 201312;
@JSONAPI::TRACE = ();

# http://api-writing.blogspot.com/2008/04/api-template.html
# https://github.com/blog/1081-instantly-beautiful-project-pages

=pod

<SECTION>
<h1>Version</h1>
API RELEASE DATE: 2014/02

</SECTION>

<SECTION>
<h1>Types of Messages</h1>
success	: yay!
missing  : this is not an error, but 
warning  : something odd happened, but the request was otherwise successful
challenge: you will need to complete the task in order to continue.
youerr : user (probably correctable) error, ex: invalid phone number
youwarn: user (possibly ignorable) error, ex: no firstname in email
fileerr : an error occurred with an external file
apperr : developer error (probably not correctable by user), ex: data formatting -- this is something the app developer can fix.
apierr : server error (probably not correctable by app), ex: facebook plugin did not work, site offline for maintenance, but usually an uncorrectable 3rd party error.
iseerr : reserved for application to handle 'server down', 'unreachable' or otherwise 'invalid response format' errors
cfgerr : configuration error (something in the server configuration prohibits the request)
</SECTION>

=cut

use locale;
use utf8 qw();
use Encode qw();
use Data::Dumper qw();
use JSON::XS qw();
use Data::GUID qw();
use strict;
use File::Slurp;
use File::Path;
use Text::CSV_XS;
use Try::Tiny;
use URI::Escape qw();
use URI::Escape::XS;
use MIME::Base64 qw();
use Image::Magick qw();
use Data::Dumper qw(Dumper);
use Digest::SHA1 qw();
use strict;
use MIME::Types qw();
use XML::SAX::Simple qw();
use XML::Simple qw();
use Compress::Bzip2 qw();
use Compress::Zlib qw();
use Data::Dumper;
use LWP::UserAgent;
use Data::Dumper;
use YAML::Syck;
use Storable;
use IO::Scalar;		## we should stop using IO::Scalar
use String::MkPasswd;
use IO::String;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use IO::Socket::INET;
use IO::Socket::SSL qw(inet4);
use HTTP::Tiny;
use IO::Compress::Gzip;
use XML::Writer;
use IO::File;
use Git::Repository;
#use JavaScript::V8;

use lib '/backend/lib';
require NAVCAT;
require CUSTOMER;
require CUSTOMER::TICKET;
require CART2;
require STUFF2;
require PRODUCT;
require OAUTH;
require ZTOOLKIT;
require DOMAIN;
require DBINFO;
require ZOOVY;
require PLUGIN::FILEUPLOAD;
require WHOLESALE;
require INVENTORY2;
## note: webdoc 51609 references this module!
require PRODUCT;
require STUFF;
require LUSER;
require ORDER::BATCH;
require ZTOOLKIT::XMLUTIL;
require SITE;
require CART2;
require GIFTCARD;
require ZWEBSITE;	
require ZTOOLKIT;
require DBINFO;
require NAVCAT;
require DOMAIN::TOOLS;
require SYNDICATION;
require AMAZON3;
require PRODUCT::FLEXEDIT;
require PROJECT;
require ACCOUNT;
require ZSHIP;
require ZSHIP::UPSAPI;	# ZSHIP::UPSAPI::global vars are used here
require BLAST;
require POGS;
require BLAST;
require TLC;
use strict;



##
## documentation:
##
@JSONAPI::GROUP_HEADERS = (
	## format is: group,title,subtitle
	['app','Application','API calls used by many different types of applications dealing with products,configuration data,categories,payment methods'],
	['boss','Boss','API calls intended for people in charge of managing the data fair and setting up administrative users.' ],
	['cart','Cart/Shopping','API calls specific to managing a shopping cart and checkout payment', ],
	['customer','Buyer/Customer','API calls that can be used by registered customer/buyers'],
	['admin','Administrative','API calls intended for site owners (and require administrative authentication)'],
	['admin-ui','Administrative User Interface','Administrative Compatibility Calls (internal use only)'],
	['utility','Utilities','API calls that can be used by anybody, and are mostly useful for diagnostic reasons (ex: echo, time, geolocation)'],
	['deprecated','Legacy/Deprecated','DO NOT USE THESE - deprecated calls will be removed in future releases after a period of notification, followed by a period of selective availability'],
	);



%JSONAPI::CMDS = (
	## LEGACY ##

	## 201324
	'adminWholesaleScheduleList'=>[ \&JSONAPI::adminPriceSchedule, { 'deprecated'=>201324, 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'L' } ],

	## 201330
	'adminPrivateDownload'=>[ \&JSONAPI::adminPrivateFile, { 'deprecated'=>201330, 'admin'=>1, }, 'admin', { 'REPORT'=>'L' } ],

	## 201336
	'appCategoryDetail'=>[ \&JSONAPI::adminNavcat,  { 'deprecated'=>201335 }, 'deprecated', ],
	
	## 201352
	'cartCheckoutValidate'=>[ \&JSONAPI::cartCheckoutValidate,  { 'cart'=>1 }, 'deprecated', ],
	'cartGoogleCheckoutURL'=>[ \&JSONAPI::cartGoogleCheckoutURL,  { 'cart'=>1 }, 'cart', ],

	#######
	## 'xslMagic'=>[ \&JSONAPI::xslMagic, {}, 'utility', ],
	'ping'=>[ \&JSONAPI::ping,  { }, 'utility', ],
	'time'=>[ \&JSONAPI::utilityTime,  { }, 'utility', ],
	'platformInfo'=>[ \&JSONAPI::platformInfo,  { }, 'utility', ],
	'whoAmI'=>[ \&JSONAPI::whoAmI,  { 'cart'=>1 }, 'utility', ],	## use JSONAPI::CART2 on non-admin so cart=>1 
	'whereAmI'=>[ \&JSONAPI::whereAmI,  {}, 'utility', ],
	'canIUse'=>[ \&JSONAPI::canIUse,  {}, 'utility', ],			# is functionality (bundle) available {} ],
	'helpWiki'=>[ \&JSONAPI::helpWiki, { }, 'utility' ],

	'domainLookup'=>[ \&JSONAPI::domainLookup, { }, 'utility' ],
	'cryptoTool'=>[ \&JSONAPI::cryptoTool, {}, 'utility' ],

	## future utility methods:
	## &ZSHIP::correct_state
	## &ZSHIP::correct_zip 
	## ZSHIP::validate_address

	## app level (no cart rqeuired)
	'appProductGet'=>[ \&JSONAPI::appProductGet,  { }, 'app', ],
	'appProductList'=>[ \&JSONAPI::appProduct,  { }, 'app', ],
	'appProductSelect'=>[ \&JSONAPI::appProduct,  { }, 'app', ],
	'appPublicSearch'=>[ \&JSONAPI::appPublicSearch,  { }, 'app', ],
	'appConfig'=>[ \&JSONAPI::appConfig, { }, 'app', ],
	'appCategoryList'=>[ \&JSONAPI::appCategoryList,  { }, 'app', ],
	'appNavcatDetail'=>[ \&JSONAPI::adminNavcat,  { }, 'app', ],
	'appEmailSend'=>[ \&JSONAPI::appEmailSend,  { }, 'app', ],
	'appPaymentMethods'=>[ \&JSONAPI::appPaymentMethods,  { }, 'app', ],
	'appCheckoutDestinations'=>[ \&JSONAPI::appCheckoutDestinations,  { }, 'app', ],
	'appNewsletterList' =>[  \&JSONAPI::appNewsletterList,  { }, 'app', ],
	'appGiftcardValidate' =>[  \&JSONAPI::appGiftcardValidate,  { }, 'app', ],
	'appFAQs'=>[ \&JSONAPI::appFAQs,  { }, 'app', ],
	'appSendMessage'=>[ \&JSONAPI::appSendMessage,  { }, 'app', ],
	'appPageGet'=>[ \&JSONAPI::appPageGet,  { }, 'app', ],
	'appPageSet'=>[ \&JSONAPI::appPageSet,  { }, 'app', ],
	'appEventAdd'=>[  \&JSONAPI::appEventAdd,  { }, 'app', ],
	'appResource'=>[ \&JSONAPI::appResource,  { }, 'app', ],
	'appReviewAdd'=>[ \&JSONAPI::appReviewAdd,  { }, 'app', ],
	'appReviewsList'=>[ \&JSONAPI::appReviewsList,  { }, 'app', ],
	'appProfileInfo'=>[ \&JSONAPI::appProfileInfo,  { }, 'app', ],
	#'appCaptchaGet'=>[ \&JSONAPI::appCaptchaGet,  {}, 'app', ],
	'appShippingTransitEstimate'=>[ \&JSONAPI::appShippingTransitEstimate, { }, 'app' ],

	## Step1: OAuthAuthorize - register 
	# 'authAuthorize'=>[ \&JSONAPI::appOAuthAuthorize, {},  ],
		
	## User Authentication
	'authAdminLogin'=>[ \&JSONAPI::authAdminLogin, { 'auth'=>1 }, 'auth' ],
	'authAdminLogout'=>[ \&JSONAPI::authAdminLogout, { 'auth'=>1 }, 'auth' ],
	'authPasswordRecover'=>[ \&JSONAPI::authPassword, {  'auth'=>1 }, 'auth' ],
	'adminPasswordUpdate'=>[ \&JSONAPI::authPassword, { 'auth'=>1 }, 'auth' ],
	'authNewAccountCreate'=>[ \&JSONAPI::authNewAccountCreate, { 'auth'=>1 }, 'auth' ],

	##
	## support provider calls
	'providerExecLogin'=>[ \&JSONAPI::providerExec, { 'provider'=>1 } ],
	'providerExecTodoCreate'=>[ \&JSONAPI::providerExec, { 'provider'=>1 } ],
	'providerExecAccountGet'=>[ \&JSONAPI::providerExec, { 'provider'=>1 } ],
	'providerExecFileRead'=>[ \&JSONAPI::providerExec, { 'provider'=>1 } ],
	'providerExecFileWrite'=>[ \&JSONAPI::providerExec, { 'provider'=>1 } ],
	
	## 
	## cart
	'appCartCreate'=>[ \&JSONAPI::appCartCreate,  { }, 'cart', ],
	'appCartExists'=>[ \&JSONAPI::appCartExists,  { }, 'cart', ],
	'cartSet'=>[ \&JSONAPI::cartSet,  { }, 'cart', ],
	'cartItemAppend'=>[ \&JSONAPI::cartItemAppend,  { 'cart'=>1 }, 'cart', ],
	'cartDetail'=>[ \&JSONAPI::cartDetail,  { 'cart'=>1 }, 'cart', ],
	'cartItemUpdate'=>[ \&JSONAPI::cartItemUpdate,  { 'cart'=>1 }, 'cart', ],
	'cartCSRShortcut'=>[ \&JSONAPI::cartCSRShortcut, { 'cart'=>1 }, 'cart', ],	# 6 digit id for call center {} ],
	'cartShippingMethods'=>[ \&JSONAPI::cartShippingMethods,  { 'cart'=>1 }, 'cart', ],	
	'cartPaymentQ' => [ \&JSONAPI::cartPaymentQ, { 'cart'=>1 }, 'cart' ],
	'cartPaypalSetExpressCheckout'=>[ \&JSONAPI::cartPaypalSetExpressCheckout,  { 'cart'=>1 }, 'cart', ],
	'cartAmazonPaymentURL'=>[ \&JSONAPI::cartAmazonPaymentURL,  { 'cart'=>1 }, 'cart', ],
	'cartItemsInventoryVerify'=>[ \&JSONAPI::cartItemsInventoryVerify,  { 'cart'=>1 }, 'cart', ],
	'cartOrderCreate'=>[ \&JSONAPI::cartOrder,  { 'cart'=>1 }, 'cart', ],
	'cartOrderStatus'=>[ \&JSONAPI::cartOrder,  { }, 'cart', ],
	'cartGiftcardAdd' =>[  \&JSONAPI::cartPromoCodeOrGiftcardOrCouponToCartAdd,  { 'cart'=>1 }, 'cart', ],
	'cartCouponAdd' =>[  \&JSONAPI::cartPromoCodeOrGiftcardOrCouponToCartAdd,  { 'cart'=>1 }, 'cart', ],
	'cartPromoCodeAdd' =>[  \&JSONAPI::cartPromoCodeOrGiftcardOrCouponToCartAdd,  { 'cart'=>1 }, 'cart', ],
	'cartMessageList'=>[ \&JSONAPI::cartMessageList, { 'cart'=>1 }, 'cart', ],
	'cartMessagePush'=>[ \&JSONAPI::cartMessagePush, { 'cart'=>1 }, 'cart', ],

	## adminCart
	'adminCartMacro'=>[ \&JSONAPI::adminCartOrderMacro, { 'cart'=>1, 'admin'=>1, }, 'admin', { 'ORDER'=>'U' } ],
	'adminCSRLookup'=>[ \&JSONAPI::adminCSRLookup, { 'admin'=>1, }, 'admin', { 'ORDER'=>'U' } ],
	
	## Control Panel
	'adminControlPanelAction'=>[ \&JSONAPI::adminControlPanel, { 'admin'=>1 }, 'admin', { 'CPANEL'=>'U' } ],
	'adminControlPanelQuery'=>[ \&JSONAPI::adminControlPanel, { 'admin'=>1 }, 'admin', { 'CPANEL'=>'U' } ],


	## SEO functions
	'adminSEOInit'=>[ \&JSONAPI::appSEO, { 'admin'=>1 }, 'seo' ],
	'appSEOFetch'=>[ \&JSONAPI::appSEO, {}, 'seo' ],
	'appSEOStore'=>[ \&JSONAPI::appSEO, {}, 'seo'  ],
	'appSEOFinish'=>[ \&JSONAPI::appSEO, {}, 'seo' ],

	## Admin
	## 'appAdminInit'=>[ \&JSONAPI::appAdminInit,  { 'cart'=>0, 'cart'=>0 }, 'admin', ],
	## 'appAdminAuthenticate'=>[ \&JSONAPI::appAdminAuthenticate,  { 'cart'=>0 }, 'admin', ],
	## 'appAdminPasswordRecover'=>[ \&JSONAPI::appAdminPasswordRecover,  { 'cart'=>0 }, 'admin', ],
	'adminOrderReserve'=>[ \&JSONAPI::adminOrderReserveId, { 'admin'=>1, } , 'admin', { 'ORDER'=>'C' } ],
	'adminOrderList'=>[ \&JSONAPI::adminOrderList,  { 'admin'=>1, }, 'admin', { 'ORDER'=>'L'} ],
	'adminOrderSearch'=>[ \&JSONAPI::adminOrderList,  { 'admin'=>1, }, 'admin', { 'ORDER'=>'L'}  ],
	'adminOrderDetail'=>[ \&JSONAPI::adminOrderDetail,  { 'admin'=>1, }, 'admin', { 'ORDER'=>'R'} ],
	'adminOrderMacro'=>[ \&JSONAPI::adminCartOrderMacro,  { 'admin'=>1, }, 'admin', { 'ORDER'=>'U'} ],
	'adminOrderCreate'=>[ \&JSONAPI::cartOrder, { 'admin'=>1, }, 'admin', { 'ORDER'=>'C'} ],
	'adminOrderPaymentAction'=>[ \&JSONAPI::adminOrderPaymentAction, { 'admin'=>1, }, 'admin', { 'ORDER/PAYMENT'=>'U' } ],
	'adminOrderPaymentMethods'=>[ \&JSONAPI::adminOrderPaymentMethods,  { 'admin'=>1, }, 'admin', { 'ORDER/PAYMENT'=>'U' } ],
	'adminOrderRouteList'=>[ \&JSONAPI::adminOrderRouteList,  { 'admin'=>1, }, 'admin', { 'ORDER'=>'U' } ],
	'adminOrderItemList'=>[ \&JSONAPI::adminOrderList, { 'admin'=>1, }, 'admin', { 'ORDER'=>'L' }  ],

	'bossUserCreate'=>[ \&JSONAPI::bossUser, { 'boss'=>1, 'admin'=>1, }, 'boss' ],
 	'bossUserList'=>[ \&JSONAPI::bossUser, { 'boss'=>1, 'admin'=>1, }, 'boss' ],
	'bossUserUpdate'=>[ \&JSONAPI::bossUser, { 'boss'=>1, 'admin'=>1, }, 'boss' ],
	'bossUserDelete'=>[ \&JSONAPI::bossUser, { 'boss'=>1, 'admin'=>1, }, 'boss' ],
	'bossUserDetail'=>[ \&JSONAPI::bossUser, { 'boss'=>1, 'admin'=>1, }, 'boss' ],
	'bossRoleCreate'=>[ \&JSONAPI::bossRole, { 'boss'=>1, 'admin'=>1, }, 'boss' ],
	'bossRoleList'=>[ \&JSONAPI::bossRole, { 'boss'=>1, 'admin'=>1, }, 'boss' ],
	'bossRoleUpdate'=>[ \&JSONAPI::bossRole, { 'boss'=>1, 'admin'=>1, }, 'boss' ],
	'bossRoleDelete'=>[ \&JSONAPI::bossRole, { 'boss'=>1, 'admin'=>1, }, 'boss' ],

	## 
	'billingPendingCharges'=>[ \&JSONAPI::billingInvoice, { 'boss'=>1, 'admin'=>1, }, 'boss' ],
	'billingInvoiceList'=>[ \&JSONAPI::billingInvoice, { 'boss'=>1, 'admin'=>1, }, 'boss' ],
	'billingInvoiceView'=>[ \&JSONAPI::billingInvoice, { 'boss'=>1, 'admin'=>1, }, 'boss' ],
	'billingPaymentMethodsList'=>[ \&JSONAPI::billingPayment, { 'boss'=>1, 'admin'=>1, }, 'boss' ],
	'billingPaymentMacro'=>[ \&JSONAPI::billingPayment, { 'boss'=>1, 'admin'=>1, }, 'boss' ],

	##
	'adminPlatformMacro'=>[ \&JSONAPI::adminPlaform, { 'admin'=>1, }, 'admin', { 'PLATFORM'=>'R' } ],
	'adminPlatformHealth'=>[ \&JSONAPI::adminPlaform, { 'admin'=>1, }, 'admin', { 'PLATFORM'=>'R' } ],
	'adminPlatformLogList'=>[ \&JSONAPI::adminPlatform, { 'admin'=>1, }, 'admin', { 'PLATFORM'=>'R' } ],
	'adminPlatformLogDownload'=>[ \&JSONAPI::adminPlatform, { 'admin'=>1, }, 'admin', { 'PLATFORM'=>'R' } ],
	'adminPlatformQueueList'=>[ \&JSONAPI::adminPlatform, { 'admin'=>1, }, 'admin', { 'PLATFORM'=>'R' } ],

	'adminDataQuery'=>[ \&JSONAPI::adminDataQuery, { 'admin'=>1, }, 'admin' ],
	'adminLUserTagList'=>[ \&JSONAPI::adminLUser,  { 'admin'=>1, }, 'admin', ],
	'adminLUserTagSet'=>[ \&JSONAPI::adminLUser,  { 'admin'=>1, }, 'admin', ],
	'adminLUserTagGet'=>[ \&JSONAPI::adminLUser,  { 'admin'=>1, }, 'admin', ],

	## SOG
	'adminSOGDetail'=>  [ \&JSONAPI::adminSOG, { 'auth'=>1, }, 'auth' ],
	'adminSOGList'=>    [ \&JSONAPI::adminSOG, { 'auth'=>1, }, 'auth' ],
	'adminSOGComplete'=>[ \&JSONAPI::adminSOG, { 'auth'=>1, }, 'auth' ],
	'adminSOGUpdate'=>  [ \&JSONAPI::adminSOG, { 'auth'=>1, }, 'auth' ],
	'adminSOGCreate'=>  [ \&JSONAPI::adminSOG, { 'auth'=>1, }, 'auth' ],
	'adminSOGDelete'=>  [ \&JSONAPI::adminSOG, { 'auth'=>1, }, 'auth' ],

	'adminImageList'=>[ \&JSONAPI::adminImageList,  { 'admin'=>1, }, 'admin',  { 'IMAGE'=>'L'} ],
	'adminImageDetail'=>[ \&JSONAPI::adminImageDetail,  { 'admin'=>1, }, 'admin', { 'IMAGE'=>'R' }  ],
	'adminImageFolderList'=>[ \&JSONAPI::adminImageFolderList,  { 'admin'=>1, }, 'admin', { 'IMAGE'=>'L'} ],
	'adminImageFolderCreate'=>[ \&JSONAPI::adminImageFolderCreate,  { 'admin'=>1, }, 'admin', { 'IMAGE'=>'C' } ],
	'adminImageFolderDelete'=>[ \&JSONAPI::adminImageFolderDelete,  { 'admin'=>1, }, 'admin', { 'IMAGE'=>'D' } ],
	'adminImageUpload'=>[ \&JSONAPI::adminImageUploadMagick,  { 'admin'=>1, }, 'admin', { 'IMAGE'=>'U' } ],
	'adminImageMagick'=>[ \&JSONAPI::adminImageUploadMagick,  { 'admin'=>1, }, 'admin', { 'IMAGE'=>'U' } ],
	'adminImageDelete'=>[ \&JSONAPI::adminImageDelete,  { 'admin'=>1, }, 'admin', { 'IMAGE'=>'D' } ],

	'adminNavTreeList'=>[ \&JSONAPI::adminNavTree,  { 'admin'=>0,, 'navcat'=>1, }, 'admin', ], 
	'appNavcatDetail'=>	[ \&JSONAPI::adminNavcat,  { 'admin'=>0,, 'navcat'=>1, }, 'admin', ],
	'adminNavcatDetail'=>[ \&JSONAPI::adminNavcat, 	{ 'admin'=>1,, 'navcat'=>1, }, 'admin', { 'NAVCAT'=>'R' } ],
	'adminNavcatDelete'=>[ \&JSONAPI::adminNavcat,  { 'admin'=>1,, 'navcat'=>1, }, 'admin', { 'NAVCAT'=>'D' } ],
	'adminNavcatModify'=>[ \&JSONAPI::adminNavcat,  { 'admin'=>1,, 'navcat'=>1, }, 'admin', { 'NAVCAT'=>'U' } ],
	'adminNavcatCreate'=>[ \&JSONAPI::adminNavcat,  { 'admin'=>1,, 'navcat'=>1, }, 'admin', { 'NAVCAT'=>'C' } ],
	'adminNavcatMacro'=>[ \&JSONAPI::adminNavcat,  { 'admin'=>1,, 'navcat'=>1, }, 'admin', { 'NAVCAT'=>'C' } ],
	'adminNavcatProductInsert'=>[ \&JSONAPI::adminNavcat,  { 'admin'=>1,, 'navcat'=>1, }, 'admin', { 'NAVCAT'=>'C' } ],
	'adminNavcatProductDelete'=>[ \&JSONAPI::adminNavcat,  { 'admin'=>1,, 'navcat'=>1, }, 'admin', { 'NAVCAT'=>'D' } ],
	'adminPrivateSearch'=>[ \&JSONAPI::adminPrivateSearch, { 'admin'=>1,, 'navcat'=>1, }, 'admin', { 'ORDER'=>'S' } ],
	'adminProductList'=>[ \&JSONAPI::adminProductList,  { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'L' } ],
	'adminProductCreate'=>[ \&JSONAPI::adminProduct,  { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'C' } ],
	'adminProductUpdate'=>[ \&JSONAPI::adminProduct,  { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'U' } ],
	'adminProductDelete'=>[ \&JSONAPI::adminProduct,  { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'D' } ],
	'adminProductDetail'=>[ \&JSONAPI::adminProduct,  { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'R' } ],

	'adminProductAmazonDetail'=>[ \&JSONAPI::adminProduct,  { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'D' } ],
	'adminProductAmazonValidate'=>[ \&JSONAPI::adminProduct,  { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'D' } ],
	'adminProductEBAYDetail'=>[ \&JSONAPI::adminProduct,  { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'D' } ],
	'adminProductDebugLog'=>[ \&JSONAPI::adminProduct,  { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'D' } ],

	'adminProductInventoryDetail'=>[  \&JSONAPI::adminProduct,  { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'U' } ],
	'adminProductMacro'=>[ \&JSONAPI::adminProduct,  { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'U' } ],
	'adminProductSelectorDetail'=>[ \&JSONAPI::adminProduct,  { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'R' } ],
	'adminProductOptionsUpdate'=>[ \&JSONAPI::adminProduct,  { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'U' } ],
	'adminProductNavcatList'=>[ \&JSONAPI::adminProduct, { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'R' } ],
	'adminProductManagementCategoriesList'=>[ \&JSONAPI::adminProductManagementCategoriesList, { 'admin'=>1, }, 'admin', {} ],
	'adminProductManagementCategoriesDetail'=>[ \&JSONAPI::adminProductManagementCategoriesDetail, { 'admin'=>1, }, 'admin' ],
	'adminProductManagementCategoriesComplete'=>[ \&JSONAPI::adminProductManagementCategoriesComplete, { 'admin'=>1, }, 'admin' ],
	'adminProductReviewList'=>[ \&JSONAPI::adminProductReview, { 'admin'=>1, }, 'admin', { 'REVIEW'=>'L' } ],
	'adminProductReviewCreate'=>[ \&JSONAPI::adminProductReview, { 'admin'=>1, }, 'admin', { 'REVIEW'=>'C' } ],
	# 'adminProductReviewDetail'=>[ \&JSONAPI::adminProductReview, { 'admin'=>1, }, 'admin', { 'REVIEW'=>'R' } ],
	'adminProductReviewUpdate'=>[ \&JSONAPI::adminProductReview, { 'admin'=>1, }, 'admin', { 'REVIEW'=>'U' } ],
	'adminProductReviewRemove'=>[ \&JSONAPI::adminProductReview, { 'admin'=>1, }, 'admin', { 'REVIEW'=>'D' } ],
	'adminProductReviewApprove'=>[ \&JSONAPI::adminProductReview, { 'admin'=>1, }, 'admin', { 'REVIEW'=>'U' } ],
	'adminPageGet'=>[ \&JSONAPI::adminPage,  { 'admin'=>1, }, 'admin', { 'PAGE'=>'R' } ],
	'adminPageSet'=>[ \&JSONAPI::adminPage,  { 'admin'=>1, }, 'admin', { 'PAGE'=>'U' } ],
	'adminPageList'=>[ \&JSONAPI::adminPageList, { 'admin'=>1, }, 'admin', { 'PAGE'=>'L' } ],


	'adminCustomerSelectorDetail'=>[ \&JSONAPI::adminCustomer,  { 'admin'=>1, }, 'admin', { 'PRODUCT'=>'R' } ],
	'adminCustomerSearch'=>[\&JSONAPI::adminCustomer, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'S' } ],
	'adminCustomerCreate'=>[\&JSONAPI::adminCustomerCreateUpdate, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'C' } ],
	'adminCustomerUpdate'=>[\&JSONAPI::adminCustomerCreateUpdate, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'U' } ],
	'adminCustomerDetail'=>[\&JSONAPI::adminCustomerDetail, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'R' } ],
	'adminCustomerRemove'=>[\&JSONAPI::adminCustomerRemove, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'D' } ],
	'adminCustomerWalletPeek'=>[ \&JSONAPI::adminCustomerWalletPeek, { 'admin'=>1, }, 'admin', { 'CUSTOMER/WALLET'=>'R' } ],
	'adminCustomerOrganizationSearch'=>[\&JSONAPI::adminCustomerOrganization, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'S' } ],
	'adminCustomerOrganizationCreate'=>[\&JSONAPI::adminCustomerOrganization, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'C' } ],
	'adminCustomerOrganizationUpdate'=>[\&JSONAPI::adminCustomerOrganization, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'U' } ],
	'adminCustomerOrganizationDetail'=>[\&JSONAPI::adminCustomerOrganization, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'R' } ],
	'adminCustomerOrganizationRemove'=>[\&JSONAPI::adminCustomerOrganization, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'D' } ],
	'adminNewsletterList' =>[  \&JSONAPI::appNewsletterList,  { 'admin'=>1, }, 'admin', ],

	## Email/Blast
	'adminBlastMacroPropertyDetail'=>[\&JSONAPI::adminBlastMacro, { 'admin'=>1, }, 'admin', { 'BLAST'=>'L' } ],
	'adminBlastMacroPropertyUpdate'=>[\&JSONAPI::adminBlastMacro, { 'admin'=>1, }, 'admin', { 'BLAST'=>'L' } ],
	'adminBlastMacroList'=>[\&JSONAPI::adminBlastMacro, { 'admin'=>1, }, 'admin', { 'BLAST'=>'L' } ],
	'adminBlastMacroDetail'=>[\&JSONAPI::adminBlastMacro, { 'admin'=>1, }, 'admin', { 'BLAST'=>'R' } ],
	'adminBlastMacroCreate'=>[\&JSONAPI::adminBlastMacro, { 'admin'=>1, }, 'admin', { 'BLAST'=>'C' } ],
	'adminBlastMacroUpdate'=>[\&JSONAPI::adminBlastMacro, { 'admin'=>1, }, 'admin', { 'BLAST'=>'U' } ],
	'adminBlastMacroRemove'=>[\&JSONAPI::adminBlastMacro, { 'admin'=>1, }, 'admin', { 'BLAST'=>'D' } ],
	'adminBlastMsgList'=>[\&JSONAPI::adminBlastMsg, { 'admin'=>1, }, 'admin', { 'BLAST'=>'L' } ],
	'adminBlastMsgDetail'=>[\&JSONAPI::adminBlastMsg, { 'admin'=>1, }, 'admin', { 'BLAST'=>'R' } ],
	'adminBlastMsgCreate'=>[\&JSONAPI::adminBlastMsg, { 'admin'=>1, }, 'admin', { 'BLAST'=>'C' } ],
	'adminBlastMsgUpdate'=>[\&JSONAPI::adminBlastMsg, { 'admin'=>1, }, 'admin', { 'BLAST'=>'U' } ],
	'adminBlastMsgRemove'=>[\&JSONAPI::adminBlastMsg, { 'admin'=>1, }, 'admin', { 'BLAST'=>'D' } ],
	'adminBlastMsgSend'=>[\&JSONAPI::adminBlastMsg, { 'admin'=>1, }, 'admin', { 'BLAST'=>'R' } ],

	## WMS
	'adminWarehouseMacro'=>[\&JSONAPI::adminWarehouse, { 'admin'=>1, }, 'admin', { 'WMS'=>'S' } ],
	'adminWarehouseDetail'=>[\&JSONAPI::adminWarehouse, { 'admin'=>1, }, 'admin', { 'WMS'=>'S' } ],
	'adminWarehouseList'=>[\&JSONAPI::adminWarehouse, { 'admin'=>1, }, 'admin', { 'WMS'=>'S' } ],
	'adminWarehouseInventoryQuery'=>[\&JSONAPI::adminWarehouse, { 'admin'=>1, }, 'admin', { 'WMS'=>'S' } ],

	## Vendor
	'adminVendorSearch'=>[\&JSONAPI::adminVendor, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'S' } ],
	'adminVendorCreate'=>[\&JSONAPI::adminVendor, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'C' } ],
	'adminVendorUpdate'=>[\&JSONAPI::adminVendor, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'U' } ],
	'adminVendorMacro'=>[\&JSONAPI::adminVendor, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'U' } ],
	'adminVendorDetail'=>[\&JSONAPI::adminVendor, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'D' } ],
	'adminVendorRemove'=>[\&JSONAPI::adminVendor, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'R' } ],

	## Competitive Intelligence
	'adminCIEngineConfig'=>[ \&JSONAPI::adminCIEngine, { 'admin'=>1, }, 'admin', { 'CIENGINE'=>'C' } ],
	'adminCIEngineMacro'=>[ \&JSONAPI::adminCIEngine, { 'admin'=>1, }, 'admin', { 'CIENGINE'=>'U' } ],
	'adminCIEngineAgentList'=>[ \&JSONAPI::adminCIEngine, { 'admin'=>1, }, 'admin', { 'CIENGINE'=>'L' } ], 
	'adminCIEngineAgentCreate'=>[ \&JSONAPI::adminCIEngine, { 'admin'=>1, }, 'admin', { 'CIENGINE'=>'C' } ], 
	'adminCIEngineAgentUpdate'=>[ \&JSONAPI::adminCIEngine, { 'admin'=>1, }, 'admin', { 'CIENGINE'=>'U' } ], 
	'adminCIEngineAgentDetail'=>[ \&JSONAPI::adminCIEngine, { 'admin'=>1, }, 'admin', { 'CIENGINE'=>'D' } ], 
	'adminCIEngineAgentRemove'=>[ \&JSONAPI::adminCIEngine, { 'admin'=>1, }, 'admin', { 'CIENGINE'=>'R' } ], 
	'adminCIEngineLogSearch'=>[ \&JSONAPI::adminCIEngine, { 'admin'=>1, }, 'admin', { 'CIENGINE'=>'C' } ], 

	##
	## TEMPLATES
	##
	'adminTemplateInstall'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminTemplateList'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'L' } ],
	'adminTemplateCreateFrom'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'L' } ],
	'adminTemplateDetail'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'D' } ],
	
	## FILES
	'adminFileContents'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'FILE'=>'L' } ],
	'adminFileSave'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'FILE'=>'L' } ],

	## 
	## APP PROJECT:
	##
	'adminSiteTemplateInstall'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'L' } ],
	'adminSiteTemplateList'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'L' } ],
	'adminSiteTemplateCreateFrom'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'L' } ],
	'adminSiteTemplateDetail'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'D' } ],
#	'adminSiteAvailableCoupons'=>[\&JSONAPI::adminSite, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'S' } ],
#	'adminSiteList'=>[\&JSONAPI::adminSite, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'S' } ],
#	'adminSiteMacro'=>[\&JSONAPI::adminSite, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'S' } ],
#	'adminSiteCreate'=>[\&JSONAPI::adminSite, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'C' } ],
#	'adminSiteUpdate'=>[\&JSONAPI::adminSite, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'U' } ],
#	'adminSiteRemove'=>[\&JSONAPI::adminSite, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'R' } ],
#	'adminSiteStart'=>[\&JSONAPI::adminSite, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'R' } ],
	'adminSiteFileContents'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminSiteFileSave'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminSiteFileUpload'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminSiteZipDownload'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],

	##
	## CIAgent
	##
	'adminCIAgentTemplateInstall'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'L' } ],
	'adminCIAgentTemplateList'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'L' } ],
	'adminCIAgentTemplateCreateFrom'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'L' } ],
	'adminCIAgentTemplateDetail'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'D' } ],
#	'adminCIAgentAvailableCoupons'=>[\&JSONAPI::adminCIAgent, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'S' } ],
#	'adminCIAgentList'=>[\&JSONAPI::adminCIAgent, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'S' } ],
#	'adminCIAgentMacro'=>[\&JSONAPI::adminCIAgent, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'S' } ],
#	'adminCIAgentCreate'=>[\&JSONAPI::adminCIAgent, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'C' } ],
#	'adminCIAgentUpdate'=>[\&JSONAPI::adminCIAgent, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'U' } ],
#	'adminCIAgentRemove'=>[\&JSONAPI::adminCIAgent, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'R' } ],
#	'adminCIAgentStart'=>[\&JSONAPI::adminCIAgent, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'R' } ],
	'adminCIAgentFileContents'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminCIAgentFileSave'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminCIAgentFileUpload'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminCIAgentZipDownload'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],


	## 
	## CAMPAIGN:
	##
	'adminCampaignTemplateInstall'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'L' } ],
	'adminCampaignTemplateList'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'L' } ],
	'adminCampaignTemplateCreate'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'L' } ],
	'adminCampaignTemplateCreateFrom'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'L' } ],
	## 'adminCampaignTemplateCreateFrom'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'L' } ],
	'adminCampaignTemplateDetail'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'D' } ],
	'adminCampaignAvailableCoupons'=>[\&JSONAPI::adminCampaign, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'S' } ],
	'adminCampaignList'=>[\&JSONAPI::adminCampaign, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'S' } ],
	'adminCampaignMacro'=>[\&JSONAPI::adminCampaign, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'S' } ],
	'adminCampaignCreate'=>[\&JSONAPI::adminCampaign, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'C' } ],
	'adminCampaignUpdate'=>[\&JSONAPI::adminCampaign, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'U' } ],
	'adminCampaignRemove'=>[\&JSONAPI::adminCampaign, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'R' } ],
	'adminCampaignStart'=>[\&JSONAPI::adminCampaign, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'R' } ],
	'adminCampaignTest'=>[\&JSONAPI::adminCampaign, { 'admin'=>1, }, 'admin', { 'CAMPAIGN'=>'R' } ],
	'adminCampaignFileContents'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminCampaignFileSave'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminCampaignFileUpload'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminCampaignZipDownload'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],

	##
	## HTML WIZARD / LISTING TEMPLATE
	##
	'adminEBAYTemplateInstall'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYTemplateList'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYTemplateCreate'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYTemplateCreateFrom'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYTemplateDetail'=>[ \&JSONAPI::adminTemplate, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'D' } ],

	'adminEBAYCategory'=>[ \&JSONAPI::adminEBAYCategory, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYStoreCategoryList'=>[ \&JSONAPI::adminEBAY, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYMacro'=>[ \&JSONAPI::adminEBAY, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYListingCreate'=>[ \&JSONAPI::adminEBAY, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYListingTest'=>[ \&JSONAPI::adminEBAY, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYTokenList'=>[ \&JSONAPI::adminEBAY, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYTokenDetail'=>[ \&JSONAPI::adminEBAY, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYProfileList'=>[ \&JSONAPI::adminEBAY, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYProfileDetail'=>[ \&JSONAPI::adminEBAY, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYProfileCreate'=>[ \&JSONAPI::adminEBAY, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYProfileUpdate'=>[ \&JSONAPI::adminEBAY, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYProfileRemove'=>[ \&JSONAPI::adminEBAY, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYProfileTest'=>[ \&JSONAPI::adminEBAY, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYProfilePreview'=>[ \&JSONAPI::adminEBAY, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],

	'adminEBAYProfileFileContents'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYProfileFileSave'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYProfileFileUpload'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminEBAYProfileZipDownload'=>[ \&JSONAPI::adminFile, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],


	##
	## 
	##
	'adminAppTicketList'=>[ \&JSONAPI::adminAppTicket, { 'admin'=>1, }, 'admin', { 'TICKET'=>'L' } ],
	'adminAppTicketSearch'=>[ \&JSONAPI::adminAppTicket, { 'admin'=>1, }, 'admin', { 'TICKET'=>'S' } ],
	'adminAppTicketCreate'=>[ \&JSONAPI::adminAppTicket, { 'admin'=>1, }, 'admin', { 'TICKET'=>'C' } ],
	'adminAppTicketRemove'=>[ \&JSONAPI::adminAppTicket, { 'admin'=>1, }, 'admin', { 'TICKET'=>'R' } ],
	'adminAppTicketMacro'=>[ \&JSONAPI::adminAppTicket, { 'admin'=>1, }, 'admin', { 'TICKET'=>'U' } ],
	'adminAppTicketDetail'=>[ \&JSONAPI::adminAppTicket, { 'admin'=>1, }, 'admin', { 'TICKET'=>'D' } ],

	## FAQ
	'adminFAQDetail'=>[ \&JSONAPI::adminFAQ, { 'admin'=>1, }, 'admin', { 'FAQ'=>'L' } ],
	'adminFAQList'=>[ \&JSONAPI::adminFAQ, { 'admin'=>1, }, 'admin', { 'FAQ'=>'L' } ],
	'adminFAQMacro'=>[ \&JSONAPI::adminFAQ, { 'admin'=>1, }, 'admin', { 'FAQ'=>'S' } ],

	## wholesale/schedule manager
	'adminPriceScheduleList'=>[ \&JSONAPI::adminPriceSchedule, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'L' } ],
	'adminPriceScheduleCreate'=>[ \&JSONAPI::adminPriceSchedule, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'C' } ],
	'adminPriceScheduleRemove'=>[ \&JSONAPI::adminPriceSchedule, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'R' } ],
	'adminPriceScheduleUpdate'=>[ \&JSONAPI::adminPriceSchedule, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'U' } ],
	'adminPriceScheduleDetail'=>[ \&JSONAPI::adminPriceSchedule, { 'admin'=>1, }, 'admin', { 'CUSTOMER'=>'D' } ],

	## adminProject
	'adminProjectList'=>[ \&JSONAPI::adminProject, { 'admin'=>1, }, 'admin', { 'PROJECT'=>'L' } ],
	'adminProjectClone'=>[ \&JSONAPI::adminProject, { 'admin'=>1, }, 'admin', { 'PROJECT'=>'R' } ],
	'adminProjectCreate'=>[ \&JSONAPI::adminProject, { 'admin'=>1, }, 'admin', { 'PROJECT'=>'C' } ],
	'adminProjectRemove'=>[ \&JSONAPI::adminProject, { 'admin'=>1, }, 'admin', { 'PROJECT'=>'R' } ],
	'adminProjectUpdate'=>[ \&JSONAPI::adminProject, { 'admin'=>1, }, 'admin', { 'PROJECT'=>'U' } ],
	'adminProjectDetail'=>[ \&JSONAPI::adminProject, { 'admin'=>1, }, 'admin', { 'PROJECT'=>'D' } ],
	'adminProjectGitCommand'=>[ \&JSONAPI::adminProject, { 'admin'=>1, }, 'admin', { 'PROJECT'=>'D' } ],

	## adminRSS
	'adminRSSList'=>[ \&JSONAPI::adminRSS, { 'admin'=>1, }, 'admin', { 'RSS'=>'L' } ],
	'adminRSSClone'=>[ \&JSONAPI::adminRSS, { 'admin'=>1, }, 'admin', { 'RSS'=>'R' } ],
	'adminRSSCreate'=>[ \&JSONAPI::adminRSS, { 'admin'=>1, }, 'admin', { 'RSS'=>'C' } ],
	'adminRSSRemove'=>[ \&JSONAPI::adminRSS, { 'admin'=>1, }, 'admin', { 'RSS'=>'R' } ],
	'adminRSSUpdate'=>[ \&JSONAPI::adminRSS, { 'admin'=>1, }, 'admin', { 'RSS'=>'U' } ],
	'adminRSSDetail'=>[ \&JSONAPI::adminRSS, { 'admin'=>1, }, 'admin', { 'RSS'=>'D' } ],

	## adminAffiliates (not live)
	'adminAffiliateList'=>[ \&JSONAPI::adminAffiliates, { 'admin'=>1, }, 'admin', { 'AFFILIATE'=>'L' } ],
	'adminAffiliateClone'=>[ \&JSONAPI::adminAffiliates, { 'admin'=>1, }, 'admin', { 'AFFILIATE'=>'R' } ],
	'adminAffiliateCreate'=>[ \&JSONAPI::adminAffiliates, { 'admin'=>1, }, 'admin', { 'AFFILIATE'=>'C' } ],
	'adminAffiliateRemove'=>[ \&JSONAPI::adminAffiliates, { 'admin'=>1, }, 'admin', { 'AFFILIATE'=>'R' } ],
	'adminAffiliateUpdate'=>[ \&JSONAPI::adminAffiliates, { 'admin'=>1, }, 'admin', { 'AFFILIATE'=>'U' } ],
	'adminAffiliateDetail'=>[ \&JSONAPI::adminAffiliates, { 'admin'=>1, }, 'admin', { 'AFFILIATE'=>'D' } ],


	## adminSyndication
	'adminSyndicationList'=>[ \&JSONAPI::adminSyndication, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'L' } ],
	'adminSyndicationDetail'=>[ \&JSONAPI::adminSyndication, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'D' } ],
	'adminSyndicationPublish'=>[ \&JSONAPI::adminSyndication, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'C' } ],
	'adminSyndicationHistory'=>[ \&JSONAPI::adminSyndication, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'S' } ],
	'adminSyndicationFeedErrors'=>[ \&JSONAPI::adminSyndication, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'S' } ],
	'adminSyndicationDebug'=>[ \&JSONAPI::adminSyndication, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'S' } ],
	'adminSyndicationListFiles'=>[ \&JSONAPI::adminSyndication, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'R' } ],
#	'adminSyndicationCategories'=>[ \&JSONAPI::adminSyndication, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'R' } ],
	'adminSyndicationBUYDownloadDBMaps'=>[ \&JSONAPI::adminSyndication, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'R' } ],
	'adminSyndicationAMZOrders'=>[ \&JSONAPI::adminSyndication, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'R' } ],
	'adminSyndicationAMZLogs'=>[ \&JSONAPI::adminSyndication, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'R' } ],
	'adminSyndicationMacro'=>[ \&JSONAPI::adminSyndication, { 'admin'=>1, }, 'admin', { 'SYNDICATION'=>'U' } ],


	## adminGiftcard 
	'adminGiftcardList'=>[ \&JSONAPI::adminGiftcard, { 'admin'=>1, }, 'admin', { 'GIFTCARD'=>'L' } ],
	'adminGiftcardSeriesList'=>[ \&JSONAPI::adminGiftcard, { 'admin'=>1, }, 'admin', { 'GIFTCARD'=>'L' } ],
	'adminGiftcardSearch'=>[ \&JSONAPI::adminGiftcard, { 'admin'=>1, }, 'admin', { 'GIFTCARD'=>'L' } ],
	'adminGiftcardSetupProduct'=>[ \&JSONAPI::adminGiftcard, { 'admin'=>1, }, 'admin', { 'GIFTCARD'=>'L' } ],
	'adminGiftcardCreate'=>[ \&JSONAPI::adminGiftcard, { 'admin'=>1, }, 'admin', { 'GIFTCARD'=>'C' } ],
	'adminGiftcardMacro'=>[ \&JSONAPI::adminGiftcard, { 'admin'=>1, }, 'admin', { 'GIFTCARD'=>'U' } ],
	'adminGiftcardDetail'=>[ \&JSONAPI::adminGiftcard, { 'admin'=>1, }, 'admin', { 'GIFTCARD'=>'D' } ],

	## adminDSAgent
	'adminDSAgentList'=>[ \&JSONAPI::adminDSAgent, { 'admin'=>1, }, 'admin', { 'DSAGENT'=>'L' } ],
	'adminDSAgentClone'=>[ \&JSONAPI::adminDSAgent, { 'admin'=>1, }, 'admin', { 'DSAGENT'=>'R' } ],
	'adminDSAgentCreate'=>[ \&JSONAPI::adminDSAgent, { 'admin'=>1, }, 'admin', { 'DSAGENT'=>'C' } ],
	'adminDSAgentRemove'=>[ \&JSONAPI::adminDSAgent, { 'admin'=>1, }, 'admin', { 'DSAGENT'=>'R' } ],
	'adminDSAgentUpdate'=>[ \&JSONAPI::adminDSAgent, { 'admin'=>1, }, 'admin', { 'DSAGENT'=>'U' } ],
	'adminDSAgentDetail'=>[ \&JSONAPI::adminDSAgent, { 'admin'=>1, }, 'admin', { 'DSAGENT'=>'D' } ],

	##	
	'adminConfigMacro'=>[ \&JSONAPI::adminConfigMacro, { 'admin'=>1, }, 'admin', { 'CONFIG'=>'U' } ],
	'adminConfigDetail'=>[ \&JSONAPI::adminConfigDetail, { 'admin'=>1, }, 'admin', { 'CONFIG'=>'L' } ],
	'adminDebugSite'=>[ \&JSONAPI::adminDebugSite, { 'admin'=>1, }, 'admin', { 'CONFIG'=>'L' } ],
	'adminDebugTaxes'=>[ \&JSONAPI::adminDebugShippingPromoTaxes, { 'admin'=>1, }, 'admin', { 'CONFIG'=>'L' } ],
	'adminDebugShipping'=>[ \&JSONAPI::adminDebugShippingPromoTaxes, { 'admin'=>1, }, 'admin', { 'CONFIG'=>'L' } ],
	'adminDebugProduct'=>[ \&JSONAPI::adminDebugProduct, { 'admin'=>1, }, 'admin', { 'CONFIG'=>'L' } ],
	'adminDebugPromotion'=>[ \&JSONAPI::adminDebugShippingPromoTaxes, { 'admin'=>1, }, 'admin', { 'CONFIG'=>'L' } ],
	'adminDebugSearch'=>[ \&JSONAPI::adminDebugSearch, { 'admin'=>1, }, 'admin', { 'CONFIG'=>'L' } ],
	'adminSearchLogList'=>[ \&JSONAPI::adminSearchLog, { 'admin'=>1, }, 'admin', { 'CONFIG'=>'L' } ],
	'adminSearchLogRemove'=>[ \&JSONAPI::adminSearchLog, { 'admin'=>1, }, 'admin', { 'CONFIG'=>'L' } ],

	'appStash'=>[ \&JSONAPI::appStashSuck, { 'admin'=>1, }, 'admin', { } ],
	'appSuck'=>[ \&JSONAPI::appStashSuck, { 'admin'=>1, }, 'admin', { } ],

	'adminTaskList'=>[ \&JSONAPI::adminTask, { 'admin'=>1, }, 'admin', { 'TASK'=>'L' } ],
	'adminTaskCreate'=>[ \&JSONAPI::adminTask, { 'admin'=>1, }, 'admin', { 'TASK'=>'C' } ],
	'adminTaskRemove'=>[ \&JSONAPI::adminTask, { 'admin'=>1, }, 'admin', { 'TASK'=>'D' } ],
	'adminTaskUpdate'=>[ \&JSONAPI::adminTask, { 'admin'=>1, }, 'admin', { 'TASK'=>'U' } ],
	'adminTaskDetail'=>[ \&JSONAPI::adminTask, { 'admin'=>1, }, 'admin', { 'TASK'=>'R' } ],
	'adminTaskComplete'=>[ \&JSONAPI::adminTask, { 'admin'=>1, }, 'admin', { 'TASK'=>'U' } ],
	'adminBatchJobList'=>[ \&JSONAPI::adminBatchJob, { 'admin'=>1, }, 'admin', { 'JOB'=>'L' } ],
	'adminBatchJobCreate'=>[ \&JSONAPI::adminBatchJob, { 'admin'=>1, }, 'admin', { 'JOB'=>'C' } ],
	'adminBatchJobStatus'=>[ \&JSONAPI::adminBatchJob, { 'admin'=>1, }, 'admin', { 'JOB'=>'R' } ],
	'adminBatchJobCleanup'=>[ \&JSONAPI::adminBatchJob, { 'admin'=>1, }, 'admin', { 'JOB'=>'D' } ],
	'adminBatchJobDownload'=>[ \&JSONAPI::adminBatchJob, { 'admin'=>1, }, 'admin', { 'JOB'=>'R' } ],
	'adminBatchJobParametersList'=>[ \&JSONAPI::adminBatchJob, { 'admin'=>1, }, 'admin', { 'JOB'=>'L' } ],
	'adminBatchJobParametersCreate'=>[ \&JSONAPI::adminBatchJob, { 'admin'=>1, }, 'admin', { 'JOB'=>'C' } ],
	'adminBatchJobParametersRemove'=>[ \&JSONAPI::adminBatchJob, { 'admin'=>1, }, 'admin', { 'JOB'=>'R' } ],

	'adminSupplierList'=>[ \&JSONAPI::adminSupplier, { 'admin'=>1, }, 'admin', { 'SUPPLIER'=>'L' } ],
	'adminSupplierCreate'=>[ \&JSONAPI::adminSupplier, { 'admin'=>1, }, 'admin', { 'SUPPLIER'=>'C' } ],
	'adminSupplierDetail'=>[ \&JSONAPI::adminSupplier, { 'admin'=>1, }, 'admin', { 'SUPPLIER'=>'R' } ],
	'adminSupplierMacro'=>[ \&JSONAPI::adminSupplier, { 'admin'=>1, }, 'admin', { 'SUPPLIER'=>'U' } ],
	'adminSupplierRemove'=>[ \&JSONAPI::adminSupplier, { 'admin'=>1, }, 'admin', { 'SUPPLIER'=>'D' } ],
	'adminSupplierAction'=>[ \&JSONAPI::adminSupplier, { 'admin'=>1, }, 'admin', { 'SUPPLIER'=>'D' } ],
	'adminSupplierOrderList'=>[ \&JSONAPI::adminSupplier, { 'admin'=>1, }, 'admin', { 'SUPPLIER'=>'R','ORDER'=>'R' } ],
	'adminSupplierOrderItemList'=>[ \&JSONAPI::adminSupplier, { 'admin'=>1, }, 'admin', { 'SUPPLIER'=>'R','ORDER'=>'R' } ],
	'adminSupplierUnorderedItemList'=> [ \&JSONAPI::adminSupplier, { 'admin'=>1, }, 'admin', { 'SUPPLIER'=>'R','PRODUCT'=>'R' } ],
   'adminSupplierInventoryList'=> [ \&JSONAPI::adminSupplier, { 'admin'=>1, }, 'admin', { 'SUPPLIER'=>'R','PRODUCT'=>'R' } ], ## added by JT

#	'adminProfileDetail'=>[ \&JSONAPI::adminProfileDetail, { 'admin'=>1, }, 'admin', undef, { 'DOMAIN'=>'D' } ],
#	'adminProfileUpdate'=>[ \&JSONAPI::adminProfileUpdate, { 'admin'=>1, }, 'admin', undef, { 'DOMAIN'=>'U' } ],
	
	'adminTicketList'=>[ \&JSONAPI::adminTicket, { 'admin'=>1, }, 'admin', { 'HELP'=>'L' } ],
	'adminTicketCreate'=>[ \&JSONAPI::adminTicket, { 'admin'=>1, }, 'admin', { 'HELP'=>'C' } ],
	'adminTicketMacro'=>[ \&JSONAPI::adminTicket, { 'admin'=>1, }, 'admin', { 'HELP'=>'U' } ],
	'adminTicketDetail'=>[ \&JSONAPI::adminTicket, { 'admin'=>1, }, 'admin', { 'HELP'=>'R' } ],
	'adminTicketFileAttach'=>[  \&JSONAPI::adminTicket, { 'admin'=>1, }, 'admin', { 'HELP'=>'U'} ],
	'adminTicketFileRemove'=>[  \&JSONAPI::adminTicket, { 'admin'=>1, }, 'admin', { 'HELP'=>'U'} ],
   'adminTicketFileList'=>[  \&JSONAPI::adminTicket, { 'admin'=>1, }, 'admin', { 'HELP'=>'L'} ], ## added by jt
	'adminTicketFileGet'=>[  \&JSONAPI::adminTicket, { 'admin'=>1, }, 'admin', { 'HELP'=>'R'} ],

	'adminPartnerSet'=>[ \&JSONAPI::adminPartner, { 'admin'=>1, }, 'admin' ],
	'adminPartnerGet'=>[ \&JSONAPI::adminPartner, { 'admin'=>1, }, 'admin' ],

	'adminPrivateFileList'=>[ \&JSONAPI::adminPrivateFile, { 'admin'=>1, }, 'admin', { 'REPORT'=>'L' } ],
	'adminPrivateFileRemove'=>[ \&JSONAPI::adminPrivateFile, { 'admin'=>1, }, 'admin', { 'REPORT'=>'L' } ],
	'adminPrivateFileDownload'=>[ \&JSONAPI::adminPrivateFile, { 'admin'=>1, }, 'admin', { 'REPORT'=>'L' } ],
	'adminReportDownload'=>[ \&JSONAPI::adminReportDownload, { 'admin'=>1, }, 'admin', { 'REPORT'=>'L' } ],

	## KPI Calls
	'adminKPIDBCollectionList'=>[ \&JSONAPI::adminKPIDB, { 'admin'=>1, }, 'admin', { 'DASHBOARD'=>'L' } ],
	'adminKPIDBCollectionCreate'=>[ \&JSONAPI::adminKPIDB, { 'admin'=>1, }, 'admin' ],
	'adminKPIDBCollectionUpdate'=>[ \&JSONAPI::adminKPIDB, { 'admin'=>1, }, 'admin' ],
	'adminKPIDBCollectionRemove'=>[ \&JSONAPI::adminKPIDB, { 'admin'=>1, }, 'admin' ],
	'adminKPIDBCollectionDetail'=>[ \&JSONAPI::adminKPIDB, { 'admin'=>1, }, 'admin' ],
	'adminKPIDBUserDataSetsList'=>[ \&JSONAPI::adminKPIDB, { 'admin'=>1, }, 'admin', { 'DASHBOARD'=>'L' } ],
	'adminKPIDBDataQuery'=>[ \&JSONAPI::adminKPIDB, { 'admin'=>1, }, 'admin', { 'DASHBOARD'=>'L' } ],

	## DNS
	## 'adminDomain'=>[ \&JSONAPI::adminDomain,  { 'admin'=>1, }, 'admin', { 'DOMAIN'=>'S' } ],
	'adminDomainList'=>[\&JSONAPI::adminDomain, { 'admin'=>1, }, 'admin', { 'DOMAIN'=>'L' } ],
   'adminDomainDetail'=>[\&JSONAPI::adminDomain, { 'admin'=>1, }, 'admin', { 'DOMAIN'=>'L' } ],
   'adminDomainDiagnostics'=>[\&JSONAPI::adminDomain, { 'admin'=>1, }, 'admin', { 'DOMAIN'=>'L' } ],
	'adminDomainMacro'=>[\&JSONAPI::adminDomain, { 'admin'=>1, }, 'admin', { 'DOMAIN'=>'L' } ],

	'adminPartitionList'=>[\&JSONAPI::adminPartitionList, { 'admin'=>1, }, 'admin' ],
	'adminUIExecuteCGI'=>[\&JSONAPI::adminUIExecuteCGI, { 'admin'=>1, }, 'admin-ui', ],
	'adminUIBuilderPanelExecute'=>[\&JSONAPI::adminUIBuilderPanelExecute, { 'admin'=>1,, }, 'admin-ui', { 'LEGACY'=>'U'} ],
	'adminUIMediaLibraryExecute'=>[ \&JSONAPI::adminUIMediaLibraryExecute, { 'admin'=>1,, }, 'admin-ui', { 'IMAGE'=>'C' } ],
	'adminTOXMLSetFavorite'=>[\&JSONAPI::adminTOXMLSetFavorite, { 'admin'=>1,, }, 'admin-ui', { 'LEGACY'=>'U' } ],

	'adminTechnicalRequest'=>[ \&JSONAPI::adminTechnicalRequest, { 'admin'=>1, }, 'admin', { 'HELP'=>'C' } ],
	'adminMySystemHealth'=>[ \&JSONAPI::adminMySystemHealth, { 'admin'=>1, }, 'admin', { 'HELP'=>'C' } ],

	'adminMessagesList'=>[ \&JSONAPI::adminMessages, { 'admin'=>1, }, 'admin', ],
	'adminMessagesEmpty'=>[ \&JSONAPI::adminMessages, { 'admin'=>1, }, 'admin', ],
	'adminMessageRemove'=>[ \&JSONAPI::adminMessages, { 'admin'=>1, }, 'admin', ],

	'adminVersionCheck'=>[ \&JSONAPI::adminVersionCheck, {}, 'admin', ],
	'adminAccountDetail'=>[ \&JSONAPI::adminAccountDetail, { 'admin'=>1, }, 'admin', ],
	'adminCSVImport'=>[ \&JSONAPI::adminCSVImport, { 'admin'=>1, }, 'admin', { 'JOB'=>'C' } ],
	'adminCSVExport'=>[ \&JSONAPI::adminCSVExport, { 'admin'=>1, }, 'admin', { 'JOB'=>'C' } ],
	'adminPublicFileUpload'=>[ \&JSONAPI::adminPublicFileUpload, { 'admin'=>1, }, 'admin', { 'IMAGE'=>'C' } ],
	'adminPublicFileList'=>[ \&JSONAPI::adminPublicFileList, { 'admin'=>1, }, 'admin', { 'IMAGE'=>'L' } ],
	'adminPublicFileDelete'=>[ \&JSONAPI::adminPublicFileDelete, { 'admin'=>1, }, 'admin', { 'IMAGE'=>'D' } ],
	'adminWalletList'=>[ \&JSONAPI::adminWalletList, { 'admin'=>1, }, 'admin', { 'CUSTOMER/WALLET'=>'L' } ],

	## Suppliers
	'appSupplierInit'=>[ \&JSONAPI::appSupplierInit,  {}, 'supplier', ],
	'appSupplierAuthorize'=>[ \&JSONAPI::appSupplierAuthorize,  {}, 'supplier', ],

	## MashUp
	'appMashUpSQS'=>[ \&JSONAPI::appMashUp, {}, 		'mashup' ],
	'appMashUpSQL'=>[ \&JSONAPI::appMashUp, {}, 		'mashup' ],
	'appMashUpHTTP'=>[ \&JSONAPI::appMashUp, {}, 		'mashup' ],
	'appMashUpHTTPS'=>[ \&JSONAPI::appMashUp, {}, 	'mashup' ],
	'appMashUpMemCache'=>[ \&JSONAPI::appMashUp, {}, 'mashup' ],
	'appMashUpRedis'=>[ \&JSONAPI::appMashUp, {}, 	'mashup' ],
	'appMashUpSMTP'=>[ \&JSONAPI::appMashUp, {}, 		'mashup' ],
	'appMashUpFTP'=>[ \&JSONAPI::appMashUp, {}, 		'mashup' ],
	'appMashUpSFTP'=>[ \&JSONAPI::appMashUp, {}, 		'mashup' ],
	'appInteractInternalMemCache'=>[ \&JSONAPI::appInteractInternal, {}, 	'mashup' ],
	'appInteractInternalRedis'=>[ \&JSONAPI::appInteractInternal, {}, 		'mashup' ],

	## flow control
	'appAccidentDataRecorder'=>[ &JSONAPI::appAccidentDataRecorder, {}, 'utility' ],

	## Buyer
	'appBuyerCreate'=>[ \&JSONAPI::appBuyerCreate, {}, 'customer' ],
	'appBuyerLogin'=>[ \&JSONAPI::appBuyerLogin,  {}, 'customer', ],
	'appBuyerAuthenticate'=>[ \&JSONAPI::appBuyerAuthenticate, {}, 'customer', ],
	'appBuyerDeviceRegistration'=>[ \&JSONAPI::appBuyer, {}, 'customer' ],
	'appBuyerPasswordRecover'=>[  \&JSONAPI::appBuyerPasswordRecover,  {}, 'customer', ],
	'appBuyerExists'=>[ \&JSONAPI::appBuyerExists,  {}, 'customer', ],
	'buyerNotificationAdd'=>[ \&JSONAPI::buyerNotificationAdd,  { 'buyer'=>1 }, 'customer', ],
	'buyerDetail'=>				[ \&JSONAPI::buyerInfo,  { 'buyer'=>1 }, 'customer', ],
	'buyerUpdate'=>				[ \&JSONAPI::buyerInfo,  { 'buyer'=>1 }, 'customer', ],
	'buyerAddressList'=>			[ \&JSONAPI::buyerInfo,  { 'buyer'=>1 }, 'customer', ],
	'buyerAddressAddUpdate'=>	[ \&JSONAPI::buyerInfo,  { 'buyer'=>1 }, 'customer', ],
	'buyerAddressDelete'=>		[ \&JSONAPI::buyerInfo,  { 'buyer'=>1 }, 'customer', ],
	# 'buyerOrganizationApply'=>[ \&JSONAPI::appOrganizationCreate, {}, 'customer' ],

	## BuyerOrder
	'buyerOrderGet'=>[ \&JSONAPI::buyerOrder, { 'buyer'=>3 }, 'customer', ],
	'buyerOrderPaymentAdd'=>[ \&JSONAPI::buyerOrder, { 'buyer'=>3 }, 'customer', ],
	'buyerOrderUpdate'=>[ \&JSONAPI::buyerOrderUpdate,  { 'buyer'=>1 }, 'customer', ],
	'buyerPurchaseHistory'=>[ \&JSONAPI::buyerPurchaseHistory,  { 'buyer'=>1 }, 'customer', ],
	'buyerPasswordUpdate'=>[ \&JSONAPI::buyerPasswordUpdate,  { 'buyer'=>1 }, 'customer', ],
	'buyerLogout'=>[ \&JSONAPI::buyerLogout,  { 'buyer'=>1 }, 'customer', ],

	## BuyerLists
	'buyerProductListDetail'=>[ \&JSONAPI::buyerProductListDetail,  { 'buyer'=>1 }, 'customer', ],
	'buyerProductLists'=>[ \&JSONAPI::buyerProductLists,  { 'buyer'=>1 }, 'customer', ],
	'buyerProductListAppendTo'=>[ \&JSONAPI::buyerProductListAppendTo,  { 'buyer'=>1 }, 'customer', ],
	'buyerProductListRemoveFrom'=>[ \&JSONAPI::buyerProductListRemoveFrom,  { 'buyer'=>1 }, 'customer', ],

	## BuyerWallet
	'buyerWalletList'=>[ \&JSONAPI::buyerWalletList,  { 'buyer'=>1 }, 'customer', ],
	'buyerWalletAdd'=>[ \&JSONAPI::buyerWalletAdd,  { 'buyer'=>1 }, 'customer', ],
	'buyerWalletDelete'=>[ \&JSONAPI::buyerWalletDelete,  { 'buyer'=>1 }, 'customer', ],
	'buyerWalletSetPreferred'=>[ \&JSONAPI::buyerWalletSetPreferred,  { 'buyer'=>1 }, 'customer', ],

	## NewsLetters
	#'buyerNewsletters' =>[  \&JSONAPI::buyerNewsletters,  { 'buyer'=>1 }, 'customer', ],

	## BuyerTicket
	'buyerTicketList' => [ \&JSONAPI::buyerTicketList, { 'buyer'=>1 }, 'customer', ],
	'buyerTicketCreate' => [ \&JSONAPI::buyerTicketCreate, { 'buyer'=>1 }, 'customer', ],
	'buyerTicketUpdate' => [ \&JSONAPI::buyerTicketUpdate, { 'buyer'=>1 }, 'customer', ],

	## Merchandising
	## 'getMerchandising' =>[  \&JSONAPI::getMerchandising,  {}, 'merchandising', ],	
	);



##
## a payment queue that is outside the cart.
##
sub paymentQ {
	my ($self, $ref) = @_;
	if (defined $ref) { $self->{'@PAYMENTQ'} = $ref; }
	if (not defined $self->{'@PAYMENTQ'}) { $self->{'@PAYMENTQ'} =  []; }
	return($self->{'@PAYMENTQ'});
	}

##
##	this manipulates the carts payment queue
##
sub paymentQCMD {
	my ($self, $R, $cmd, $v) = @_;

	if (not defined $v) { $v = {}; }	# certain commands like 'sync' need no parameters.
	my $webdbref = $self->webdb();

	## CART2 is required for PAYPALEC
	my $CART2 = undef;
	if ($v->{'_cartid'}) {
		my $cartid = sprintf("%s",$v->{'_cartid'});
		$CART2 = $self->cart2($cartid);
		if (not defined $CART2) {
			&JSONAPI::set_error($R,'apierr','91217',"cart could not be loaded");
			}
		}		

	$self->{'@PAYMENTQ'} = $self->paymentQ();

	if ($cmd eq 'sync') {
		## nothing to do here.
		}
	elsif ($cmd eq 'reset') {
		$self->{'@PAYMENTQ'} = [];
		}
	elsif ($cmd eq 'insert') {
		my $ID = $v->{'ID'};		## this is for a wallet (really everything ought to have an ID)
		if (not defined $ID) { $ID = Digest::MD5::md5_hex($v->{'TN'}."|".$v->{'CC'}."|".$v->{'WI'}); }
		
		if ($self->apiversion()<201314) {
			## no error checking.
			}
		elsif ($v->{'TN'} eq 'PAYPALEC') {
			require ZPAY::PAYPALEC;
			my ($result) = &ZPAY::PAYPALEC::GetExpressCheckoutDetails($CART2,$v->{'PT'},$v->{'PI'},$v);
			if ($result->{'ERR'}) {
				&JSONAPI::append_msg_to_response($R,'apierr',3599,$result->{'ERR'});
				}
			elsif ($result->{'ACK'} eq 'Failure') {
				if ($result->{'ERR'} eq '') { $result->{'ERR'} = sprintf("Paypal error[%d] %s",$result->{'L_ERRORCODE0'},$result->{'L_LONGMESSAGE0'}); }
				if ($result->{'ERR'} eq '') { $result->{'ERR'} = "Paypal ACK=Failure but no ERR message set"; }
				&JSONAPI::append_msg_to_response($R,'apierr',3598,$result->{'ERR'});
				}
			elsif ($result->{'ACK'} eq 'Success') {
				&JSONAPI::append_msg_to_response($R,'success',0);
				}
			else {
				&JSONAPI::append_msg_to_response($R,'iseerr',3592,sprintf('Unhandled internal ACK status:%s',$result->{'ACK'}));
				}
			}
		elsif ($self->apiversion() < 201403) {
			## the stricter validation checks here are not appreciated by earlier version.
			}
		## wallets don't pass a 'TN'
		#elsif (not &JSONAPI::validate_required_parameter($R,$v,'TN')) {
		#	}
		elsif ($v->{'TN'} eq 'CREDIT') {
			## credit cards require some special parameters
			if (not &JSONAPI::validate_required_parameter($R,$v,'CC')) {
				}
			elsif (not &JSONAPI::validate_required_parameter($R,$v,'YY')) {
				}
			elsif (not &JSONAPI::validate_required_parameter($R,$v,'MM')) {
				}
			#elsif (
			#	($ENV{'REMOTE_ADDR'} eq '66.240.244.204') && (substr($paymentref->{'CC'},0,1) eq '9')) {
			#	## any card number starting with a "9" can be skipped when you're on the office network.
			#	}
			elsif ($v->{'CC'} =~ /[^\d]+/) {
				&JSONAPI::set_error($R,'apperr',50505,'Credit card number contains space or other non-numeric characters.');
				}
			elsif (not &ZPAY::cc_verify_length($v->{'CC'})) {
				&JSONAPI::set_error($R,'apperr',50506,'Credit card number does not have the appropriate length.');
				}
			elsif (not &ZPAY::cc_verify_checksum($v->{'CC'})) {
				&JSONAPI::set_error($R,'apperr',50507,'Credit card number supplied does not have a valid checksum (please verify the digits).');
				}
			elsif (not &ZPAY::cc_verify_expiration($v->{'MM'},$v->{'YY'})) {
				&JSONAPI::set_error($R,'apperr',50508,'Credit card has expired.');
				}

			## cvv length check
			if (&JSONAPI::hadError($R)) {
				}
			elsif (defined($webdbref->{'cc_cvvcid'}) && ($webdbref->{'cc_cvvcid'} > 0)) {
				if ($v->{'CV'}) { 
				# CIDCVV is requested
					if (not &ZPAY::cc_verify_cvvcid($v->{'CC'},$v->{'CV'})) {
						&JSONAPI::set_error($R,'apperr',50509,'CID or CVV number is invalid for card type.');
						}
					}
				elsif ($webdbref->{'cc_cvvcid'} == 2) {
					# CIDCVV is required		
					&JSONAPI::set_error($R,'apperr',50510,'CID or CVV number must be provided.');
					}
				}
			
			## cc type check
			if (&JSONAPI::hadError($R)) {
				}
			else {
				my $TYPE = &ZPAY::cc_type_from_number($v->{'CC'});
				if (not $webdbref->{sprintf("cc_type_%s",lc($TYPE))}) {
					&JSONAPI::set_error($R,'apperr',50508,'Credit card is not a type this merchant accepts.' );
					}
				}
			#if (substr($self->fetch_property('chkout.cc_number'),0,1) eq '3') {
			#	## american express does not process CVV #'s anymore, so lets remove it!
			#	## apparently authorize.net still requires a code be sent.
			#	# $self->fetch_property('chkout.cc_cvvcid') = '';
			#	}

			}
		elsif ($v->{'TN'} eq 'PO') {
			if (&ZTOOLKIT::wordlength($v->{'PO'}) < 1) {
				&JSONAPI::set_error($R,'apperr',50520,'PO # is required for tender PO');
				}
			}
		elsif ($v->{'TN'} eq 'ECHECK') {
			if (&ZTOOLKIT::wordlength($v->{'EB'}) < 4) {
				&JSONAPI::set_error($R,'apperr',50530,'You must provide the name of the bank which of the checking account');
				}
			$v->{'ER'} =~ s/[^\d]+//gs;
			if ($v->{'ER'} !~ m/^\d\d\d\d\d\d\d\d\d$/ && $v->{'ER'} !~ m/^\d\d\d\d\d\d\d\d$/) {
				&JSONAPI::set_error($R,'apperr',50531,'ABA Routing Number must be 8 or 9 numeric digits - please re-enter the number)');
				}
			$v->{'EA'} =~ s/[^\d]+//gs;
			if ($v->{'EA'} !~ m/^\d\d\d\d\d\d\d\d[\d]+$/) {
				&JSONAPI::set_error($R,'apperr',50532,'Account Number must be at least 9 numeric digits - please re-enter the number)');
				}
			#if (defined($webdbref->{'echeck_request_acct_name'}) && $webdbref->{'echeck_request_acct_name'}) {
			#	if (&ZTOOLKIT::wordlength($v->{'EN'}) < 4) {
			#		push @ISSUES, [ 'ERROR', 'ec_en_required', 'payment.en', 'You must provide the name which appears on the checking account' ];
			#		}
			#	}
			#if (defined($webdbref->{'echeck_request_check_number'}) && $webdbref->{'echeck_request_check_number'}) {
			#	if ($v->{'EI'} !~ m/^\d+$/) {
			#		push @ISSUES, [ 'ERROR', 'ec_ei_required', 'payment.ei', 'You must provide a check number' ];
			#		}
			#	}
			}
		#elsif ($v->{'TN'} eq 'PAYPALEC') {
		#	if ($v->{'PT'} eq '') {
		#		&JSONAPI::set_error($R,'apperr',50540,'Paypal Payment Token is invalid');
		#		}
		#	}
		else {
			## other payment type!
			}

		if (not &JSONAPI::hadError($R)) {
			## never let developers pass $$ (calc amount to charge) onto the paymentQ (we might *eventually* let admin users do this)
			## if ($v->{'$$'}<=0 && $v->{'$#'}>0) { $v->{'$#'} = $v->{'$$'}; delete $v->{'$$'}; }

			my $thisRow = undef;
			foreach my $row (@{ $self->{'@PAYMENTQ'} }) { 
				if ($row->{'ID'} eq $ID) { $thisRow = $row; } 
				}

			if (not defined $thisRow) {
				$thisRow = $v;
				push @{$self->{'@PAYMENTQ'}}, $thisRow;
				}

			if (not defined $thisRow) {
				&JSONAPI::set_error($R,'iseerr',7835,sprintf("unknown logic failure - row was not be added to paymentQ"));
				}

			open F, ">/tmp/payq";
			print F Dumper($self->{'@PAYMENTQ'},$thisRow,$R)."\n";
			close F;
			}



		}
	elsif (not &JSONAPI::validate_required_parameter($R,$v,'ID')) {
		## ID is required for DELETE
  		}
	elsif ($cmd eq 'delete') {
		my $ID = $v->{'ID'};
		my $thisRow = undef;

		$self->paymentQCMD( $R, 'sync');
		foreach my $row (@{ $self->{'@PAYMENTQ'} }) { 
			if ($row->{'ID'} eq $ID) { $thisRow = $row; } 
			}

		if (not defined $thisRow) {
			&JSONAPI::set_error($R,'apperr',7836,sprintf("logic failure - row did not exist in paymentQ"));
			}
		else {
			$self->paymentQCMD($R, 'delete',{ 'ID'=>$ID });
			}
		# $CART2->in_set('want/payby',undef);
		}
	else {
		&JSONAPI::set_error($R,'apperr',7834,sprintf("logic failure - invalid cmd parameter \"$cmd\" "));
		}
	$self->{'paymentQ'} = $self->paymentQ();

	return($R);
	}


##
## serialize a call to disk.
##
#sub call_serialize {
#	my ($self, $v) = @_;
#
#	my %out = ();
#	foreach my $k (keys %{$self}) {
#		if (substr($k,0,1) eq '*') {
#			## no support for *LU at the moment
#			}
#		elsif ($k eq uc($k)) { 
#			## ex. APIVERSION
#			$out{'%_'}->{$k} = $self->{$k}; 
#			}
#		}
#	$out{'%CMD'} = $v;
#	my $CALLID = sprintf("%s-%s-%s-%s-%s",$self->username(),$v->{'_cmd'},$v->{'_uuid'},&ZTOOLKIT::timestamp(),Data::GUID->new()->as_string());
#	open F, sprintf(">/dev/shm/call-%s.json",$CALLID);
#	JSON::XS::encode_json(\%out);
#	close F;
#	return($CALLID);
#	}

##
##
##
#sub call_deserialize {
#	my ($CALLID) = @_;
#
#	my ($JSONAPI,$v) = ();
#	my $IN = undef;
#	if (-f "/dev/shm/call-%s.json") {
#		open F, sprintf("</dev/shm/call-%s.json",$CALLID);
#		$/ = undef; my $json = <F>; $/ = "\n";
#		close F;
#
#		$IN = JSON::XS::decode_json($json);
#		}
#
#	if (not defined $IN) {
#		$JSONAPI = JSONAPI->new();
#		foreach my $k (keys %{$IN->{'%_'}}) {
#			$JSONAPI->{$k} = $IN->{'%_'};
#			}
#		$v = $IN->{'%CMD'};
#		}	
#		
#	## first, establish .. 
#	return($JSONAPI,$v); 
#	}




##
##
##
sub async_fetch {
	my ($token) = @_;

	$/ = undef;
	open F, "</dev/shm/async-$token.json"; my ($JSON) = <F>; close F;
	$/ = "\n";


	return();
	}
	


##
##
##
#sub lookup_client {
#	my ($clientid) = @_;
#
#	@OAUTH::CLIENTS = (
#		{ 'clientid'=>'1pc', 'secret'=>'cheese' },
#		{ 'clientid'=>'mvc', 'secret'=>'cheese' },		## JT's typo fixed in 201342
#		{ 'clientid'=>'zmvc', 'secret'=>'cheese' },
#		{ 'clientid'=>'droid-inv', 'secret'=>'cheese' },
#		{ 'clientid'=>'admin', 'secret'=>'cheese' } ,
#		{ 'clientid'=>'michael', 'secret'=>'cheese' },
#		{ 'clientid'=>'wms-client' },
#		);
#	
#	my $this = undef;
#	foreach my $client (@OAUTH::CLIENTS) {
#		if ($client->{'clientid'} eq $clientid) { $this = $client; }
#		}
#	if (not defined $this) {
#		$this = { 'clientid'=>$clientid };
#		}
#
#	return($this);
#	}
#





=pod

<API id="adminControlPanelAction">
<input  id="verb">config-rebuild|nginx-restart|uwsgi-restart</input>
</API>

<API id="adminControlPanelQuery">
<input  id="file"></input>
<output  id="contents"></input>
</API>

=cut

sub adminControlPanel {
	my ($self,$v) = @_;

	my %R = ();
	my ($CFG) = CFG->new();
	if ($CFG->get('system','saas')) {
		&JSONAPI::had_error(\%R,'apperr',18822,sprintf("%s cmd is not allowed on saas systems"));
		}
	elsif ($v->{'_cmd'} eq 'adminControlPanelAction') {
		if ($v->{'verb'} eq 'config-rebuild') {
			system("sudo /httpd/platform/dump-domains.pl");
			}
		elsif ($v->{'verb'} eq 'nginx-restart') {
			system("sudo /etc/init.d/nginx restart");
			}
		elsif ($v->{'verb'} eq 'uwsgi-restart') {
			system("sudo touch /dev/shm/reload");
			}
		elsif ($v->{'verb'} eq 'reboot') {
			system("sudo reboot");
			}
		}
	elsif ($v->{'_cmd'} eq 'adminControlPanelQuery') {
		#my %WHITELIST = (
		#	'/dev/shm/kevorkian'=>1
		#	);
		#if ($WHITELIST{$v->{'file'}}) {
		#	$R{'contents'} = File::Slurp::read_file("/dev/shm/kevorkian");
		#	}

		#http://mmonit.com/monit/documentation/monit.html#program_status_testing
		$R{'contents'} = wget('http://127.0.0.1:2812');

		}
	return(\%R);
	}


=pod

<API id="cryptTool">

<input  id="verb">make-key|make-csr|make-self-signed-crt</input>

<input  if="verb:make-key" id="length" optional="1">1024|2048|4096</input>
<output if="verb:make-key" id="key">key text</output>

<input  if="verb:make-csr" id="key"></input>
<input  if="verb:make-csr" id="company">any company, inc.</input>
<input  if="verb:make-csr" id="city"></input>
<input  if="verb:make-csr" id="state"></input>
<input  if="verb:make-csr" id="fqdn">www.domain.com</input>
<output if="verb:make-csr" id="csr">csr text</output>

<input  if="verb:make-self-signed-crt" id="key"></input>
<input  if="verb:make-self-signed-crt" id="csr"></input>
<output if="verb:make-self-signed-crt" id="crt">crt text</output>

</API>

=cut

sub cryptoTool {
   my ($self, $v) = @_;

   my %R = ();
#			if ($ERROR) {
#				}
#			elsif ($SSL_CERT eq '') {
#				}
#			elsif ($SSL_CERT !~ /-----BEGIN CERTIFICATE-----/) {
#				print "CERT: $SSL_CERT\n";
#				$ERROR = "$HOSTDOMAIN CERTIFICATE MISSING ----BEGIN";
#				}
#			elsif ($SSL_CERT !~ /-----END CERTIFICATE-----/) {
#				$ERROR = "$HOSTDOMAIN CERTIFICATE MISSING ----END";
#				}
#	
#			if ($ERROR) {
#				}	
#			elsif ($SSL_KEY eq '') {
#				}
#			elsif ($SSL_KEY !~ /-----END RSA PRIVATE KEY-----/) {
#				$ERROR = "$HOSTDOMAIN KEY MISSING ----END";
#				}
#			elsif ($SSL_KEY !~ /-----BEGIN RSA PRIVATE KEY-----/) {
#				$ERROR = "$HOSTDOMAIN KEY MISSING ----BEGIN";
#				}

#				print Fn "# Key\n";
#				print Fn $SSL_KEY."\n";
#				print Fn "# Certificate\n";
#				print Fn $SSL_CERT."\n";
#				my ($txt) = '';		
#				($txt) = join("",File::Slurp::read_file("/httpd/platform/ssl/geotrust.pem"));
#				print Fn "# Geotrust\n$txt\n";
#				($txt) = join("",File::Slurp::read_file("/httpd/platform/ssl/20110225-rapidssl-primary-intermediate.txt"));
#				print Fn "# RapidSSL Primary\n$txt\n";
#				($txt) = join("",File::Slurp::read_file("/httpd/platform/ssl/20110225-rapidssl-secondary-intermediate.txt"));	
#				print Fn "# Geotrust EV1\n$txt\n";
#		      ($txt) = join("",File::Slurp::read_file("/httpd/platform/ssl/20120901-geotrust-evssl.txt"));
#				print Fn "\n";
#				close Fn;

	my $tmpfile = File::Temp::tmpnam();
	if ($v->{'verb'} eq 'make-key') {
		# openssl genrsa -out server.key 1024
		my $length = int($v->{'length'}) || 2048;
		system("/usr/bin/openssl genrsa -out $tmpfile $length");
		my ($contents) = File::Slurp::read_file($tmpfile);
		unlink($tmpfile);
		$R{'key'} = $contents;
		}
	elsif ($v->{'verb'} eq 'make-csr') {
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'key')) {
			}
		elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'company')) {
			}
		elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'city')) {
			}
		elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'state')) {
			}
		elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'fqdn')) {
			}
		else {
			open F, ">$tmpfile.key";
			print F $v->{'key'};
			close F;
			# openssl req -new -key server.key -out server.csr
		   my $company = $v->{'company'};
		   $company =~ s/[^\w\s]+//gs; # remove '", etc.
   		my $city = $v->{'city'};
		   $city =~ s/[^\w\s]+//gs; # remove '", etc.
		   my $state = $v->{'state'};
		   $state =~ s/[^\w\s]+//gs; # remove '", etc.
			my $HOSTDOMAIN = $v->{'fqdn'};
		   $state =~ s/[^\w\s]+//gs; # remove '", etc.
		   # /CN=www.mydom.com/O=My Dom, Inc./C=US/ST=Oregon/L=Portland
		   my $params = sprintf("/CN=%s/O=%s/C=US/ST=%s/L=%s",$HOSTDOMAIN,$company,$state,$city);
		   # system("/usr/bin/openssl req -new -key /tmp/domain.key -out /tmp/domain.csr -subj '$params'");
		   system("/usr/bin/openssl req -new -key $tmpfile.key -out $tmpfile.csr -subj '$params'");
			my ($contents) = File::Slurp::read_file("$tmpfile.csr");
			unlink("$tmpfile.key");
			unlink("$tmpfile.csr");
			$R{'csr'} = $contents;
			}
		}
	elsif ($v->{'verb'} eq 'make-self-sign-crt') {
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'csr')) {
			}
		elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'key')) {
			}
		else {
			open F, ">$tmpfile.csr"; print F $v->{'csr'}; close F;
			open F, ">$tmpfile.key"; print F $v->{'key'}; close F;
			system("/usr/bin/openssl x509 -req -days 3650 -in $tmpfile.csr -signkey $tmpfile.key -out $tmpfile.crt");
			my ($contents) = File::Slurp::read_file("$tmpfile.crt");
			$contents = $contents . "\n" . $v->{'key'};
			unlink("$tmpfile.key");
			unlink("$tmpfile.csr");
			unlink("$tmpfile.crt");
			$R{'crt'} = $contents;
			}
		}
	elsif ($v->{'verb'} eq 'pkcs-to-pem') {
			#if ($SSL_CERT =~ /-----BEGIN PKCS #7 SIGNED DATA-----/) {
			#	## so the type PKCS #7 SIGNED DATA isn't understood by openssl, they see it as just a nested certificate
			#	## this apparently is as simple as replacing -----BEGIN PKCS #7 SIGNED DATA----- with -----BEGIN CERTIFICATE-----
			#	## and -----END PKCS #7 SIGNED DATA----- with -----END CERTIFICATE-----
			#	$SSL_CERT =~ s/PKCS #7 SIGNED DATA/CERTIFICATE/gs;
			#	print "CERT: $HOSTDOMAIN appears to be p7b format, we'll convert to PEM\n";
			#	## NOTE: these files are /usr/local/etc/certs instead of /usr/local/nginx/certs
			#	my $P7BFILE = sprintf("/var/local/certs/%s.p7b",$HOSTDOMAIN);
			#	my $PEMFILE = sprintf("/var/local/certs/%s.cer",$HOSTDOMAIN);
			#	## write out the file we'll use for openssl
			#	open F, ">$P7BFILE"; 	print F $SSL_CERT; close F;
			#	# print "/usr/bin/openssl pkcs7 -print_certs -in $P7BFILE -out $PEMFILE\n";
			#	system("/usr/bin/openssl pkcs7 -print_certs -in $P7BFILE -out $PEMFILE");
			#	## $PKCS7TXT = $SSL_CERT;
			#	$SSL_CERT = '';
			#	open F, "<$PEMFILE"; while(<F>) { $SSL_CERT .= $_; } close F;
			#	if ($SSL_CERT =~ /\-\-\-\-\-BEGIN CERTIFICATE\-\-\-\-\-/s) {
			#		unlink($P7BFILE);
			#		unlink($PEMFILE);
			#		}
			#	else {
			#		die("Error converting $P7BFILE to $PEMFILE in PKCS #7 decode");
			#		}
			#	}
		}
	# openssl rsa -in server.key.org -out server.key
	# openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt 

   # www.sslshopper.com/article-most-common-openssl-commands.html
   ## generate txt key
   return(\%R);
   }




##
## providerExec
##		
##
sub providerExec {
	my ($self,$v) = @_;

	my %R = ();

	require DBINFO;
	require LUSER;
	require OAUTH;

	my $PROVIDER = $v->{'provider'};
	my $REMOTE_USER = $v->{'support'};
	my ($USERNAME) = $self->username();

	my $userpath = &ZOOVY::resolve_userpath($USERNAME);
	if (! -d $userpath) {
		&JSONAPI::set_error(\%R,'iseerr',8383,"Path $userpath does not exist.");
		}
	elsif (not $v->{'secret'}) {
		&JSONAPI::set_error(\%R,'iseerr',8384,"requires a secret");
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'cmd'} eq 'providerExecTodoCreate') {
		require TODO;
		my ($todo) = TODO->new($USERNAME,writeonly=>1);
		$todo->add( %{$v} );
		}
	elsif (($v->{'_cmd'} eq 'providerExecFileWrite') || ($v->{'_cmd'} eq 'providerExecFileRead')) {
		my $filepath = $v->{'filename'};
		$filepath =~ s/[\.]+/\./gs;	## security!
		$filepath = sprintf("%s/%s",$userpath,$filepath);
		$R{'filepath'} = $filepath;
		if ($v->{'_cmd'} eq 'providerExecFileWrite') {
			my ($body) = $v->{'body'};
			File::Slurp::write_file($filepath,$body);
			chmod 0666, $filepath;
			}
		elsif ($v->{'_cmd'} eq 'providerExecFileRead') {
		   if (-f $filepath) {
				$R{'MIMETYPE'} = 'text/plain';
				$R{'body'} = join("",File::Slurp::read_file($filepath));
				}
			}
		}
	elsif ($v->{'_cmd'} eq 'providerExecAccountGet') {
		my ($ACCT) = ACCOUNT->new($USERNAME);
		$R{'%ACCOUNT'} = $ACCT;
		}
	elsif ($v->{'_cmd'} eq 'providerExecLogin') {
	
		my $note = $v->{'note'};
		my $TICKET = $v->{'ticket'};
		if ($note ne '') {
			}
		elsif ($TICKET>0) {
			$note = "Ticket #$TICKET";
			}

		my $sendto = $v->{'sendto'};
		$sendto = URI::Escape::uri_escape($sendto);
	
		my $LUSER = uc("SUPPORT/$REMOTE_USER");
		my $USERID = lc("SUPPORT/$REMOTE_USER\@$USERNAME");
		$USERNAME = lc($USERNAME);
		my ($DEVICEID) = &OAUTH::device_initialize($USERNAME,$LUSER,$self->ipaddress(),sprintf("%s",$note));
		my ($AUTHTOKEN) = OAUTH::create_authtoken($USERNAME,$LUSER,"admin",$DEVICEID,'trusted'=>1);
		#print STDERR 'providerExecLogin: '.Dumper({
		#	LUSER=>$LUSER,NOTE=>sprintf("%s",$note),CLIENTID=>$CLIENTID,
		#	USERNAME=>$USERNAME,CLIENT=>&JSONAPI::lookup_client("admin"),AUTHTOKEN=>$AUTHTOKEN,DEVICEID=>$DEVICEID,
		#	VALIDATE=>OAUTH::validate_authtoken($USERNAME,$LUSER,&JSONAPI::lookup_client("admin"),$DEVICEID,$AUTHTOKEN),
		#	STR=>sprintf("%s-%s-%s-%s-%s-%s",lc($USERNAME),lc($LUSER),$CLIENTID,$DEVICEID,$SECRET,$AUTHTOKEN)
		#	});
	

		my ($LU) = LUSER->new_app($USERNAME,"admin");
		$LU->log('ZOOVY.SUPPORT',"User $REMOTE_USER support login reason=[$note] ","INFO");

		$R{'version'} = $JSONAPI::VERSION;
		$R{'%params'} = { 
			"trigger"=>"support", "username"=>$USERNAME, "userid"=>$USERID,
			"authtoken"=>$AUTHTOKEN, "deviceid"=>$DEVICEID,"flush"=>1 
			};
		}
	else {
		&JSONAPI::set_error(\%R,'youerr',8382,sprintf('Invalid _cmd:%s (this line should never be reached',$v->{'_cmd'}));
		}

	return(\%R);
	}


##
##
##
sub appAccidentDataRecorder {
	my ($self,$v) = @_;
	my %R = ();

	open F, ">>/tmp/adr";
	print F Dumper($v);
	close F;

	return(\%R);
	};



sub domainLookup {
	my ($self, $v) = @_;

	my %R = ();

	my $DOMAIN = $v->{'domain'};
	my $D = undef;
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'domain')) {
		## 
		}	
	else {
		$DOMAIN =~ s/[Hh][Tt][Tt][Pp][Ss]?\:\/\///gs;
		$DOMAIN =~ s/www\.//gs;
		($D) = DOMAIN::QUERY::lookup($DOMAIN);
		}

	if (&JSONAPI::hadError(\%R)) {
		## 
		}
	elsif (not defined $D) {
		&JSONAPI::set_error(\%R, 'youerr', 2075, "Domain $DOMAIN was not found in local database.");
		}
	elsif (ref($D) ne 'DOMAIN') {
		&JSONAPI::set_error(\%R, 'iseerr', 2076, "Domain $DOMAIN internal resolution was corrupt. (bad memcache?)");	
		}
	else {
		$R{'USERNAME'} = $D->username();
		$R{'MID'} = $D->mid();
		$R{'LOGO'} = $D->logo();
		$R{'adminDOMAIN'} = sprintf('admin.%s',$D->domainname());
		$R{'provider'} = 'zoovy.com';
		$R{'adminURL'} = 'https://'.&ZWEBSITE::domain_to_checkout_domain($R{'adminDOMAIN'}).'/latest/index.html';
		}
	return(\%R);
	}


##
##
##
sub appHostForUser {
	my ($self,$v) = @_;
	my %R = ();

		
	
	return(\%R);
	}



=pod

<SECTION>
<h1></h1>
<note>
{
	"_version":201318,
	"_start":"xyz",			// default starting position
	"_inputs":[
	   { "required":1,"var":"email","type":"text","label":"Email" },
	   { "required":1,"var":"firstname","type":"text","label":"Purchasing Contact Firstname" },
	   { "required":1,"var":"lastname","type":"text","label":"Purchasing Contact Lastname" },

	   { "required":1,"var":"register_password","type":"text","label":"Registration Password" },
	 
	   // *** HOW TO OVERRIDE _start ***
	   // example1: variable starting points, user specified, no security, no validation.
	   { "required":0, "type":"text", "var":"_start", "label":"This is a horrible idea." },
	 
	   // example2: using plain text passwords (poor security) 
	   // for 'match/plain' - we have two passwords "TURTLE" and "LLAMA", both use the same starting points 'start-insecure'
	   { "required":0, "type":"match", "if":"register_password", "is":"TURTLE", "var":"_start", "value":"start-insecure" },
	   { "required":0, "type":"match", "if":"register_password", "is":"LLAMA" , "var":"_start", "value":"start-insecure" },
	   
	   // example3: using md5 digest for best security
	   // for 'match-md5' - we will prepend the "saltedby" 'concatenateMe' with the users password 
		// (which *MUST* not be stored in the file - but for this example it is 'KITTEN')
	   // the md5 digest for 'concatenateMeKITTEN' is c3b9ba2823f9c2ba02a4ee89f8ac4450
	   // since digests aren't reversible, they can be stored safely in public repos.
	   { "required":0, "type":"match-md5", "if":"register_password", "saltedby":"concatenateMe", 
							"is":"c3b9ba2823f9c2ba02a4ee89f8ac4450", "var":"_start", "value":"start-secure" },
	   
	],
}
</note>
</SECTION>

=cut

sub loadPlatformJSON {
	my ($self,$API,$SCRIPT,$v,$R) = @_;


	## PHASE1: verify there is a file.
	my $file = undef;
	my $PROJECTDIR = $self->projectdir($self->projectid());

	if (not defined $self->projectid()) {
		&JSONAPI::append_msg_to_response($R,'apierr',74220,'projectid is not set.');
		}
	elsif (! -d $PROJECTDIR) {
		&JSONAPI::append_msg_to_response($R,'apierr',74222,'project directory does not seem to exist');
		}
	if (&JSONAPI::hadError($R)) {
		## shit happened
		}
	elsif ($SCRIPT =~ /^([a-z0-9]+)$/) {
		my $SCRIPT = $1;
		if (! -f "$PROJECTDIR/platform/$API-$SCRIPT.json") {
			&JSONAPI::append_msg_to_response($R,'iseerr',74223,sprintf('platform/%s-%s.json file does not seem to exist in project',$API,$SCRIPT));
			}
		}
	else {
		&JSONAPI::append_msg_to_response($R,'apperr',74224,'_vendor must be alphanumeric and be in the platform directory and end with .json');
		}

	## PHASE2: verify it contains json
	my $json = '';
	my $cfg = undef;
	if (not &JSONAPI::hadError($R)) {
		print STDERR "FILE: $PROJECTDIR/platform/$API-$SCRIPT.json\n";
		open F, "<$PROJECTDIR/platform/$API-$SCRIPT.json";
		while (<F>) {
			next if (substr($_,0,2) eq '//');
			$json .= $_;
			} 
		close F;

		## PHASE2B: parse the file.	
		if ($json eq '') {
			&JSONAPI::append_msg_to_response($R,'apierr',74220,"permissions file has no json");
			}
		else {
			eval { $cfg  = JSON::XS::decode_json($json) };
			if ($@) {
				&JSONAPI::append_msg_to_response($R,'apierr',74228,"permissions file specified is corrupt cause: $@");
				}
			elsif (ref($cfg) ne 'HASH') {
				&JSONAPI::append_msg_to_response($R,'apierr',74225,'permissions json did not decode into array');
				}
			elsif (ref($cfg->{'_inputs'}) ne 'ARRAY') {
				&JSONAPI::append_msg_to_response($R,'apierr',74226,'permissions json did not have required fields ARRAY attribute');
				} 
			}
		}

	## PHASE3: process the macros/input against validation rules.
	my %VARS = ();
	if (not &JSONAPI::hadError($R)) {
		## all the save magic happens here!
		if (not defined $cfg->{'_inputs'}) { $cfg->{'_inputs'} = []; }
		foreach my $f (@{$cfg->{'_inputs'}}) {
			my $value = $v->{ $f->{'var'} };

			if (not defined $f->{'filter'}) { $f->{'filter'} = 'safe'; }
			if (not defined $f->{'label'}) { $f->{'label'} = sprintf("field %s",$f->{'field'}); }

			if ($f->{'filter'} eq 'unsafe') {
				## we're going to allow unsafe characters, hope you know what you're doing!
				}
			elsif ($f->{'filter'} eq 'int') {
				$value = int($value);
				}
			elsif ($f->{'filter'} eq 'safe') {
				## for now, we'll remove <> to make things safe!
				$value =~ s/[\<\>]+/_/gs;
				}

			if ($f->{'type'} eq 'text') {
				if (not defined $f->{'var'}) {
					&JSONAPI::append_msg_to_response($R,'iseerr',74219,"$f->{'label'} does not have a 'var' specified.");
					}
				elsif (($f->{'required'}) && ($value eq '')) { 
					&JSONAPI::append_msg_to_response($R,'youerr',74227,"$f->{'label'} is required field.");
					}
				}
			elsif ($f->{'type'} eq 'match') {
				if ( $VARS{ $f->{'if'} } ne $f->{'is'} ) {
					$value = undef;
					}
				else {
					$value = $f->{'value'};
					}
				}
			elsif ($f->{'type'} eq 'match-md5') {
				if ( $VARS{ $f->{'if'} } ne Digest::MD5::md5_hex( $f->{'saltedby'}.$f->{'is'} )) {
					$value = undef;
					}
				else {
					$value = $f->{'value'};
					}
				}

			if (not defined $value) {
				}
			elsif (substr( $f->{'var'},0,1) eq '_') {
				$cfg->{ $f->{'var'} } = $value;
				}
			else {
				$VARS{ $f->{'var'} } = $value; 
				}
			}

		$R->{'%VARS'} = \%VARS;
		}

	## PHASE4: parse security token, set start execution.
	if (&JSONAPI::hadError($R)) {
		}
	elsif ((not defined $cfg->{'_start'}) || ($cfg->{'_start'} eq '')) {
		&JSONAPI::append_msg_to_response($R,'iseerr',74229,"$API-$SCRIPT _start point is not specified or set properly.");		
		}
	elsif ( not defined $cfg->{ $cfg->{'_start'} }) {
		&JSONAPI::append_msg_to_response($R,'iseerr',74230,sprintf("$API-$SCRIPT _start point '%s' is not valid.",$cfg->{'_start'}));		
		}
	
	return($cfg);
	}















##
## converts macro into cmds array.
##	this is designed to be called *outside* the object (that's useful if for example the first command is CREATE)
##
sub parse_macros {
	## $LINES will usually be $v->{'@updates'}
	## $CMDSREF will USUALLY be @CMDS
	my ($self, $LINES, $CMDSREF) = @_;

	my $TS = time();
	if (not defined $CMDSREF) { $CMDSREF = []; }
	my $count = 0;
	foreach my $line (@{$LINES}) {
		my ($cmd,$uristr) = split(/\?/,$line,2);
		my %params = ();

		## NOTE: we can't use &ZTOOLKIT::parseparams here because it doesn't handle +'s properly!
		foreach my $keyvalue (split /\&/, $uristr) {
			my ($key, $value) = split(/\=/, $keyvalue, 2);
			## print STDERR "KEY:$key VALUE:$value\n";
			next if (not defined $key);		## not sure how this happens!? but needs this line
			if ((defined $value) && ($value ne '')) {
				$params{ URI::Escape::XS::uri_unescape($key) } = URI::Escape::XS::uri_unescape($value);
				}
			else {
				$params{$key} = '';
				}
			}
		## my $pref = &ZTOOLKIT::parseparams($uristr);		
		## if (not defined $pref->{'luser'}) { $pref->{'luser'} = '*MACRO'; }
		$params{'luser'} = $self->luser();
		if (not defined $params{'ts'}) { $params{'ts'} = $TS; }
		push @{$CMDSREF}, [ uc($cmd), \%params, $line, $count++ ];
		}
	return($CMDSREF);
	}









sub configJS {
	my ($self, %params) = @_;

	my $webdbref = $self->webdbref();
	my ($globalref) = $self->globalref(); # SITE->globalref();
	my ($prtinfo) = &ZOOVY::fetchprt($self->username(), $self->prt());

	my ($SITE) = $params{'*SITE'} || $self->_SITE();
	my $NORMAL_URL = sprintf("%s.%s",$SITE->domain_host(),$SITE->domain_only());
	my $SECURE_URL = &ZWEBSITE::domain_to_checkout_domain($NORMAL_URL);
	## don't do this: it will rewrite secure-domain-com.
	# my $SECURE_URL = $SITE->secure_domain();
	

	## NOTE: eventually for admin api calls we ought to point this at www.zoovy.com
	my %PLUGINS = ();
	foreach my $k (keys %{$webdbref}) {
		if (substr($k,0,8) eq '%plugin.') {
			if ($webdbref->{$k}->{'enable'}) {
				my $ref = Storable::dclone($webdbref->{$k});
				foreach my $kk (keys %{$ref}) {
					if (substr($kk,0,1) eq '~') { delete $ref->{$kk}; }
					}
				$PLUGINS{ substr($k,8) } = $ref;
				}
			}
		}

	$NORMAL_URL = lc($NORMAL_URL); 		## note when this is uppercase (is breaks checks for http_app_url before 201342)
	$SECURE_URL = lc($SECURE_URL);		## if you remove this line, make sure you test app sites loading 

	my $DNSINFO = $SITE->dnsinfo();
	if ($DNSINFO->{'%HOSTS'}->{ uc($DNSINFO->{'HOST'}) }->{'CHKOUT'}) {
		$SECURE_URL = $DNSINFO->{'%HOSTS'}->{ uc($DNSINFO->{'HOST'}) }->{'CHKOUT'};
		}
	
	my %zGlobals = (
		#'DEBUG'=>{
		#	'SITE'=>Dumper($SITE),
		#	'SITE->domain_host'=>$SITE->domain_host(),
		#	'SITE->domain_only'=>$SITE->domain_only()
		#	},
		'apiSettings'=>{
			'version'=>$JSONAPI::VERSION,
			'minimum'=>$JSONAPI::VERSION_MINIMUM,
			},
		'appSettings'=>{
			'domain_host'=>$SITE->domain_host(),
			'domain_only'=>$SITE->domain_only(),
			'username'=>$SITE->username(),
			'sdomain'=>$SITE->sdomain(),
			'profile'=>sprintf(".%s",$SITE->sdomain()),
			'prt'=>$SITE->prt(),
			'rootcat'=>$SITE->rootcat(),
			'http_api_url'=>'/jsonapi/',
			'https_api_url'=>'/jsonapi/',
			'http_app_url'=>lc("http://$NORMAL_URL/"),			
			'https_app_url'=>lc("https://$SECURE_URL/"),
			'projectid'=>$self->projectid(),
			},
		'plugins'=>\%PLUGINS,
		'checkoutSettings'=>{
			'googleCheckoutMerchantId'=>'', # sprintf("%s",$webdbref->{'google_merchantid'}),
			'amazonCheckoutMerchantId'=>sprintf("%s",$webdbref->{"amz_merchantid"}),
			'amazonCheckoutEnable'=>sprintf("%d",$webdbref->{'amzpay_env'}),
			'paypalCheckoutApiUser'=>sprintf("%s",$webdbref->{'paypal_email'}),

			"chkout_order_notes" => $webdbref->{"chkout_order_notes"}, #  //form field id is chkout.order_notes
			'customer_management'=>$webdbref->{'customer_management'},
			'preference_request_login'=>(
				($webdbref->{'customer_management'} eq 'STRICT') ||
				($webdbref->{'customer_management'} eq 'NICE') ||
				($webdbref->{'customer_management'} eq 'STANDARD')
				)?1:0,
			'preference_require_login'=>(
				($webdbref->{'customer_management'} eq 'STRICT') ||
				($webdbref->{'customer_management'} eq 'MEMBER') ||
				($webdbref->{'customer_management'} eq 'PRIVATE')
				)?1:0,
			'preference_always_create_account'=>(
				($webdbref->{'customer_management'} eq 'PASSIVE')
				)?1:0,
			'preference_never_create_account'=>(
				($webdbref->{'customer_management'} eq 'MEMBER') ||
				($webdbref->{'customer_management'} eq 'PRIVATE')
				)?1:0,
			},
		'cartSettings'=>{
			'getZipForShipQuote'=>(
				(int($webdbref->{'cart_quoteshipping'})==2) || 
				(int($webdbref->{'cart_quoteshipping'})==4))?1:0,
			'canQuoteShippingWithoutZip'=>(
				(int($webdbref->{'cart_quoteshipping'})==1) || 
				(int($webdbref->{'cart_quoteshipping'})==3) || 
				(int($webdbref->{'cart_quoteshipping'})==4))?1:0,
			'showLowestShipQuoteOnly'=>(
				(int($webdbref->{'cart_quoteshipping'})==3))?1:0,						
				},
			'globalSettings'=>{
			  "inv_mode" => $globalref->{'inv_mode'}, # //0, 2 and 3 appear to be acceptable values
			  "inv_police" => $globalref->{'inv_police'}, # //0, 1 and 2 appear to be acceptable values
				},
			'thirdParty'=>{
			  "facebook" => {"appId"=>$webdbref->{'facebook_appid'}}
				},
			);

	return(\%zGlobals);
	}




##
##
##
sub new {
	my ($CLASS, $sessionid) = @_;

	my $self = {};
	bless $self, 'JSONAPI';
	$self->{'%CARTS'} = {};
	## this is a cheap hack for is_config_js
	if ($sessionid eq '__config.js__') { $self->{'__config.js__'}++; }

	return($self);
	}


## a lot of things that would normally error shoudln't on config.js
sub is_config_js { return($_[0]->{'__config.js__'}); }

sub init {
	## no longer used (i think)
	}

##
## for internal testing
##
#sub init_test_harness {
#	my ($self, %options) = @_;
#	$self->{'APIVERSION'} = $options{'version'};	
#	$self->{'USERNAME'} = $options{'username'};
#	$self->{'PRT'} = $options{'prt'};
#	$self->{'SDOMAIN'} = $options{'domain'};
#	if ($options{'domain'}) {
#		$self->{'*SITE'} = SITE->new($options{'username'}, 'PRT'=>$options{'prt'}, 'DOMAIN'=>$options{'domain'});
#		}
#
#	if ($options{'admin'}) {
#		$self->{'*LU'} = LUSER->new_trusted($self->{'USERNAME'},'ADMIN',$options{'prt'});
#		}
#
#	return($self);
#	}


## 
sub trace { if ($_[1]) { $_[0]->{'TRACE'} = $_[1]; } return($_[0]->{'TRACE'}); }

##
## a spooler initialized api
##
sub spoolinit {
	my ($self, $env) = @_;

	## keys that are copied in a spool environment
	foreach my $k ('USERNAME','LUSER','APIVERSION','SESSION','CLIENTID','DEVICEID','DOMAIN','PRT') {
		$self->{$k} = $env->{$k};
		}
	if ($env->{'json:@PAYMENTQ'}) {
		$self->{'@PAYMENTQ'} = JSON::XS::decode_json($env->{'json:@PAYMENTQ'});
		}

	if ($self->domain()) {
		## instantiate a site object
		$self->{'*SITE'} = SITE->new($self->username(), 'PRT'=>$self->prt(), 'DOMAIN'=>$self->domain());
		}

	## VERY IMPORTANT (KEEPS US FROM LOOPING ON ASYNC MODE)
	$self->{'_IS_SPOOLER'}++;

	return($self);
	}

##
##
##
sub psgiinit {
	my ($self, $plackreq, $v, %options) = @_;

	my $HEADERS = $plackreq->headers();
	$ENV{'REMOTE_ADDR'} = $plackreq->address();

	foreach my $header ($HEADERS->header_field_names()) {
		# print STDERR sprintf("HEADER: $header %s\n",$HEADERS->header($header));
		my $ENV_HEADER = uc("HTTP-$header"); $ENV_HEADER =~ s/-/_/gs;
		$ENV{$ENV_HEADER} = $HEADERS->header($header);
		}

	my $R = undef;
	## check/set version
	my $VERSION = 0;
	if (defined $R) {
		}
	elsif ($self->is_config_js()) {
		## we're being init'd for config.js, nothing to see here.
		}
	elsif ($options{'ws'}) {
		## websockets, no version check
		}
	elsif ($VERSION > 0) {
		## shit happened.
		}
	elsif ((defined $HEADERS) && (defined $HEADERS->header('x-version')) && ($HEADERS->header('x-version')>0)) {
		## first use the environment
		$VERSION = $HEADERS->header('x-version');  	## set by application
		}
	elsif ((defined $v->{'_version'}) && ($v->{'_version'}>0)) { 
		## then use the top level version
		$VERSION = $v->{'_version'}; 
		}
	elsif ((defined $v->{'@cmds'}) && (defined $v->{'@cmds'}->[0]) && (defined $v->{'@cmds'}->[0]->{'_v'})) {
		# sample: "zmvc:201231.20120906075800;browser:mozilla-15.0;OS:WI;"
		if ($v->{'@cmds'}->[0]->{'_v'} =~ /^zmvc\:(20[\d]{4,4})\./) { $VERSION = int($1); }
		}
	elsif (defined $v->{'_v'}) {
		## TOP LEVEL $v->{'_cmd'}
		# sample: "zmvc:201231.20120906075800;browser:mozilla-15.0;OS:WI;"
		if ($v->{'_v'} =~ /^zmvc\:(20[\d][\d][\d][\d])\./) { $VERSION = int($1); }
		}

	if (defined $R) {
		}
	elsif ($self->is_config_js()) {
		## we're being init'd for config.js, nothing to see here.
		}
	elsif ($options{'ws'}) {
		## websockets, no version check
		}
	elsif (($VERSION eq '') || ($VERSION==0)) {
		&JSONAPI::set_error($R = {}, 'apperr', 7, "X-VERSION header, _version or acceptable _v is required");
		warn "NO APIVERSION was detected .. this request probably won't work well. (dumping v below)\n";
		open F, ">>/tmp/noapi";
		print F Dumper($v)."\n\n";
		close F;
		
		print STDERR Dumper($v);
		}
	elsif ($VERSION < $JSONAPI::VERSION_MINIMUM) {
		my $BROKE_FOR = ((time()%7200) - 6000);
		if ($VERSION < ($JSONAPI::VERSION_MINIMUM-126)) {
			## minimum version + 18 months is the lowest we'll support, period.
			&JSONAPI::set_error($R = {}, 'apperr', 18, sprintf("Application version '%d' is below minimum '%d' - too old. api service suspended permanently.",$VERSION,$JSONAPI::VERSION_MINIMUM));
			}
		elsif ($BROKE_FOR > 0) {
			&JSONAPI::set_error($R = {}, 'apperr', 17, sprintf("Application version '%d' is below minimum '%d' - api service suspended for %d seconds (please upgrade to a new version)",$VERSION,$JSONAPI::VERSION_MINIMUM,$BROKE_FOR));
			}
		}
	else {
		$self->{'APIVERSION'} = $VERSION;
		}

	$::XCOMPAT = &CART2::v();	

	##
	## now, when we're passed a *SITE object we use that to initialize -- since that's from the domain
	##
	my $SITE = $options{'*SITE'};
	if (defined $SITE) {
		$self->{'USERNAME'} = $SITE->username();
		$self->{'MID'} = &ZOOVY::resolve_mid($self->{'USERNAME'});
		$self->{'PRT'} = $SITE->prt();
		$self->{'*SITE'} = $SITE;
		if (defined $options{'SDOMAIN'}) { $self->{'SDOMAIN'} = $options{'SDOMAIN'};  }
		if (defined $options{'*SITE'}) 	{ 
			$self->{'*SITE'} 	= $options{'*SITE'}; 
			}
		$self->{'_PROJECTID'} = $SITE->projectid();
		}

	##
	##	next we check the environment to see what we can glean out. 
	##	(note: NOTHING is required here)
	##
	my ($DOMAIN,$DEVICEID,$AUTHTOKEN) = ();

	my $URI = $plackreq->uri();
	my ($HOSTDOMAIN) =  $URI->host();
	my ($DNSINFO) = &DOMAIN::QUERY::lookup($HOSTDOMAIN);
	if (defined $DNSINFO) {
		$self->{'SDOMAIN'} = $DNSINFO->{'DOMAIN'};
		$self->{'_PROJECTID'} = $DNSINFO->{'PROJECT'};
		## print STDERR "$self->{'_PROJECTID'} = $DNSINFO->{'PROJECT'}\n"; die();
		}
	

	if (defined $R) {
		}
	elsif ($self->is_config_js()) {
		## we're being init'd for config.js, nothing to see here.
		}
	#elsif ($v->{'_userid'} || $HEADERS->header('x-userid')) {
	#	#$USERID = $v->{'_userid'} || $HEADERS->header('x-userid'); 		## obtained from user/prompt
	#	#if (defined $USERID) {
	#	#	my ($USERNAME,$LUSER) = &OAUTH::resolve_userid($USERID);
	#	#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	#	#	if ($MID<=0) {
	#	#		&JSONAPI::set_error($R = {}, 'youerr', 7, sprintf("USERID '%s' is not valid.",$USERID));			
	#	#		}
	#	#	}
	#	}	
	elsif ((defined $DNSINFO) && ($DNSINFO->{'USERNAME'})) {
		## yay, we got the dnsinfo from the username
		$self->{'USERNAME'} = $DNSINFO->{'USERNAME'};
		$self->{'USERID'} = $v->{'_userid'} || $HEADERS->header('x-userid') || "";
		}
	else {
		## wow. no userid, much bad.
		&JSONAPI::set_error($R = {}, 'youerr', 7, sprintf("DNS Lookup error, cannot resolve database"));			
		}

	##
	##	_clientid or the HTTP Header HTTP_X_CLIENTID is required.
	##
	$self->{'CLIENTID'} = $v->{'_clientid'} || $HEADERS->header('x-clientid');   ## set by application
	if (not defined $self->{'CLIENTID'}) {
		}
	elsif ($self->is_config_js()) {
		## we're being init'd for config.js, nothing to see here.
		}
	elsif (($options{'ws'}) && (not defined $self->{'CLIENTID'})) {
		## websockets, no clientid check required (it is optional)
		}
	#else {
	#	&JSONAPI::set_error($R = {}, 'apperr', 6, sprintf("CLIENTID not registered."));
	#	}

	##
	##
	##
	if (defined $R) {
		}
	elsif ($self->is_config_js()) {
		## we're being init'd for config.js, nothing to see here.
		}
	elsif ($options{'ws'}) {
		## websockets, no version check
		}
	elsif ($self->{'USERID'} ne '') {
		## try and detect the LUSER

		if (lc($self->{'USERID'}) eq lc($self->{'USERNAME'})) {
			$self->{'LUSER'} = 'admin';
			}
		elsif (index($self->{'USERID'},'@')>0) {
			($self->{'LUSER'},my $null) = split(/\@/,$self->{'USERID'});
			}
		elsif (index($self->{'USERID'},'*')>0) {
			(my $null,$self->{'LUSER'}) = split(/\*/,$self->{'USERID'});
			}
		else {		
			$self->{'LUSER'} = $self->{'USERID'};
			}

		$DOMAIN = $v->{'_domain'} || $HEADERS->header('x-domain'); 		## not required (optional, sets focus)
		$self->{'SDOMAIN'} = $DOMAIN;

		$DEVICEID = $v->{'_deviceid'} || $HEADERS->header('x-deviceid'); 	## initialized by device/stored locally
		$self->{'DEVICEID'} = $DEVICEID;

		$AUTHTOKEN = $v->{'_authtoken'} || $HEADERS->header('x-authtoken'); 	## returned by authUserLogin
		}
	
	##
	## SANITY: at this point $self->username() better fuckin be set!
	##

	if (defined $R) {
		}
	elsif (defined $SITE) {
		if (not defined $self->{'SDOMAIN'}) { $self->{'SDOMAIN'} = $SITE->sdomain(); }
		if (not defined $self->{'SDOMAIN'}) { $self->{'SDOMAIN'} = ''; }
		}

	## SANITY: at this point SDOMAIN better be valid.
	if ($self->sdomain()) {
		my $SDOMAIN = $self->sdomain();
		my ($USERNAME,$PRT) = &DOMAIN::TOOLS::domain_to_userprt($SDOMAIN);
		$self->{'PRT'} = $PRT;
		$self->{'*SITE'} = $SITE = SITE->new($self->username(), 'PRT'=>$PRT, 'DOMAIN'=>$SDOMAIN);
		}
	else {
		$self->{'*SITE'} = $SITE = SITE->new($self->username());
		}
			
	my $HTTP_ORIGIN = $HEADERS->header('Origin');		## 
	## print STDERR "ORIGIN: $HTTP_ORIGIN CLIENTID:$self->{'CLIENTID'} DEVICEID:$DEVICEID AUTHTOKEN:$AUTHTOKEN USERID:$USERID VERSION:$VERSION\n";
	if (defined $SITE) {
		print STDERR sprintf("SITE: DOMAIN:%s PRT:%d\n",$SITE->sdomain(),$SITE->prt());
		}



	$self->{'_IS_ADMIN'} = 0;
	if (defined $R) {
		}
	elsif ($self->is_config_js()) {
		## we're being init'd for config.js, nothing to see here.
		}
	elsif (defined $R) {
			}
	elsif ($self->username() eq '') {
		&JSONAPI::set_error($R = {}, 'apperr', 5, sprintf("Authentication issue - USERID not valid"));
		}
	elsif ($AUTHTOKEN ne '') {
		## AUTHENTICATION: they are attempting to be a specific user

		#open F, ">/tmp/security";
		#use Data::Dumper; print F Dumper($self->username(),$self->luser(),$self->clientid(),$DEVICEID,$AUTHTOKEN);
		#close F;

		if ($self->luser() eq '') {
			&JSONAPI::set_error($R = {}, 'apperr', 8, sprintf("Authentication issue - LUSER not valid"));
			}
		elsif (my $ACL = &OAUTH::validate_authtoken($self->username(),$self->luser(),$self->clientid(),$DEVICEID,$AUTHTOKEN)) {
			$self->{'_IS_ADMIN'}++;
			$self->{'_AUTHTOKEN'} = $AUTHTOKEN;
			$self->{'_DEVICEID'} = $DEVICEID;
			}
		else {
			print STDERR "IS *NOT* AUTHENTICATED\n";
			&JSONAPI::set_error($R = {}, 'apperr', 10, sprintf("Authentication issue ".$self->username()." ".$self->luser()." - token no longer valid"));
			}
		}


	##
	## initialize carts
	##
	if (defined $R) {
		## shit already happened.
		warn "skipping session because R is set to: ".Dumper($R);
		}
	elsif ($self->is_config_js()) {
		## we're being init'd for config.js, nothing to see here.
		}
	else {
		## version 201311+ 
		##		pass $v->{'_session'} at the root level with @cmds and cmd=pipeline
		my $session = $HEADERS->header('x-session');
		if (not defined $session) {
			$session = $v->{'_session'};
			}

		if ((not $session) && ($v->{'_version'}<=201310)) { $session = time(); }

		if (not $session) {
			&JSONAPI::set_error($R = {}, 'apperr', 15, sprintf("X-SESSION header, _session is required for apiversion>201310"));
			}
		else {
			$self->sessionInit($session);
			}
		}

	if (defined $R) {
		}	
	elsif (not $self->is_admin()) {
		##
		## if we're authenticated then we can continue, otherwise we check all commands before returning to make sure
		## we have credentials.. eventually we'll probably do access control at this level.
		##
		my $CMDS = [];
		if (defined $R) {
			}
		elsif ((defined $v->{'_cmd'}) && ($v->{'_cmd'} eq 'pipeline') && (defined $v->{'@cmds'}) && (ref($v->{'@cmds'}) eq 'ARRAY')) {
			$CMDS = $v->{'@cmds'};
			}
		elsif (defined $v->{'_cmd'}) {
			$CMDS = [ $v ];
			}
		else {
			&JSONAPI::set_error($R = {}, 'apperr', 1, "No CMDS found in request"); 
			}

		foreach my $cmdref (@{$CMDS}) {
			my $cmd = $cmdref->{'_cmd'};
			my $apiref = $JSONAPI::CMDS{$cmd};
	
			if (not defined $apiref) {
				&JSONAPI::set_error($R = {}, 'apperr', 4, sprintf("CMD '%s' is not a valid command.",$cmd));
				}
			elsif ($cmd =~ /^auth/) {
				}
			elsif ($apiref->[1]->{'admin'} == 0) {
				## does not require admin
				}
			else {
				&JSONAPI::set_error($R = {}, 'apperr', 5, sprintf("CMD '%s' requires authentication",$cmd));
				}
			}
		}

	## per JT's request:
	if (defined $R) { $R->{'_uuid'} = $v->{'_uuid'}; }

	## this will be undef if there were no errors.
	return($R);
	}













##
## UTILITY/READONLY FUNCTIONS
##
sub apiversion { 
	if (not defined $_[0]->{'APIVERSION'}) { $_[0]->{'APIVERSION'} = $JSONAPI::VERSION; }
	return($_[0]->{'APIVERSION'}); 
	}

##
## 
##
sub checkACL {
	my ($self,$R,@PARAMS) = @_;
	
	return(1);
	my $LU = $self->LU();
	if (not $LU->hasACL(@PARAMS)) {
		&JSONAPI::set_error($R,'youerr',150,'Insufficient admin priviledges');
		return(0);
		}
	return(1);
	}


sub log { &JSONAPI::accesslog(@_); }		## deprecated
sub accesslog {
	my ($self,$AREA,$MSG,$TYPE) = @_;
	##
	## NOTE: this is also called directly (not from an object) via WEBAPI::userlog and LUSER::log
	##

	if ($TYPE eq '') { $TYPE = 'INFO'; }
	my $LUSER = $self->{'LUSER'};
	if ((not defined $LUSER) || ($LUSER eq '')) { $LUSER = 'ADMIN'; }

	my $yyyymm = POSIX::strftime("%Y%m",localtime(time()));

	my ($logfile) = &ZOOVY::resolve_userpath($self->{'USERNAME'})."/access-$yyyymm.log";
	open F, ">>$logfile";
	my $date = POSIX::strftime("%Y%m%dt%H%M%S",localtime(time()));
	if (ref($MSG) eq 'ARRAY') {
		## pass in an array ref of [msg,type],[msg,type],...
		foreach my $set (@{$MSG}) {
			print F sprintf("%s\t%s\t%s\t%s\t%s\n",$date,$LUSER,$AREA,$set->[0],$set->[1]);		
			}
		}
	else {
		print F sprintf("%s\t%s\t%s\t%s\t%s\n",$date,$LUSER,$AREA,$MSG,$TYPE);
		}
	close F;
	chmod 0666, $logfile;
	return();
	}

## LU returns an LUSER object, drawing educated conclusions about the proper course of action.
sub LU { 
	my ($self, $LU) = @_;
	require LUSER;

	if (defined $LU) {
		## LU was sent to us, trust it implicitly!
		$self->{'*LU'} = $LU;
		}
	elsif (defined $self->{'*LU'}) {
		## *LU reference was already set, lets return that
		$LU = $self->{'*LU'};
		}
	elsif ($self->authtoken() ne '') {
		## since we have an authtoken we'll use the LUSER from OAUTH
		$LU = $self->{'*LU'} = LUSER->new_authtoken($self->username(),$self->luser(),$self->authtoken());
		if (defined $LU) {
			$LU->prt($self->prt());
			$LU->domain($self->sdomain());
			}
		}
	elsif ($self->luser() ne '') {
		$LU = $self->{'*LU'} = LUSER->new_trusted($self->username(),$self->luser());	
		if (defined $LU) {
			$LU->prt($self->prt());
			$LU->domain($self->sdomain());
			}
		}
	else {
		$LU = $self->{'*LU'} = LUSER->new_app($self->username(),"jsonapi");	
		if (defined $LU) {
			$LU->prt($self->prt());
			$LU->domain($self->sdomain());
			}
		}


	return($LU);
	}


## NEED TO MAKE THIS WORK!
sub ipaddress { return( $ENV{'REMOTE_ADDR'} || '1.2.3.4'); }

sub luser { return($_[0]->{'LUSER'}); }
sub username {  return($_[0]->{'USERNAME'});  }
sub projectid { 
	if (defined $_[1]) { $_[0]->{'_PROJECTID'} = $_[1]; }
	return($_[0]->{'_PROJECTID'});  
	}

sub load_platform_action {
	my ($self,$api,$action) = @_;
	my $json = '';
 	my $arrayref  = JSON::XS::decode_json($json);
	return($arrayref);
	}

##
## blank/zero same thing
##
sub dateify_to_gmt {
	my ($self,$value) = @_;
	$value = int($value);
	if ($value == 0) { $value = 0; }
	return(&ZTOOLKIT::mysql_to_unixtime($value));
	}

##
##
sub dateify {	
	my ($self,$type,$value) = @_;
		
	my $out = undef;
	if ($type eq 'mysqldate') {
		$value = &ZTOOLKIT::mysql_to_unixtime($value);
		$type = 'gmt'; 
		}

	## these are assumed to be the only other supported values
	## if (($type eq 'epoch') || ($type eq 'gmt')) {
	if (defined $out) {
		}
	elsif ($value == 0) { 
		$out = 0; 
		}
	else {
		$out = &ZTOOLKIT::pretty_date($value,3);
		}

	return($out);
	}


sub userid { return(sprintf("%s\@%s",$_[0]->luser(),$_[0]->username())); }
sub prt { 
	if (not defined $_[0]->{'PRT'}) {
		warn "PRT is undefined .. this probably won't work well.\n";
		}
	return($_[0]->{'PRT'}); 
	}
sub mid { 
	if (not defined $_[0]->{'MID'}) { 
		$_[0]->{'MID'} = &ZOOVY::resolve_mid($_[0]->username()); 
		}
	return($_[0]->{'MID'});  
	}
sub sdomain { return($_[0]->{'SDOMAIN'}); }	## we're trying to phase our sdomain since it doesn't use host.domain or domain consisntently
sub domain { return($_[0]->{'DOMAIN'} || $_[0]->{'SDOMAIN'}); }
sub SITE { return($_[0]->{'*SITE'}); }

sub cache { 
	# what is the timestamp we can use? 
	if (defined $_[0]->{'CACHE'}) {
		return($_[0]->{'CACHE'});
		}
	else {
		return( $_[0]->{'CACHE'} = &ZOOVY::touched($_[0]->username()) );
		}
	}		

##
## internal method for caching navcats (since the requests are often sent pipelined)
##
sub cached_navcat { 
	my ($self) = @_;
	my $KEY = sprintf("%NAVCATS#%d",$self->prt());
	if (defined $_[0]->{$KEY}) { return($_[0]->{$KEY}); }
	$_[0]->{$KEY} = NAVCAT->new($self->username(),'PRT'=>$self->prt(),cache=>$self->cache());
	return($_[0]->{$KEY});
	}

sub clientid { return($_[0]->{'CLIENTID'}); }
sub deviceid { return($_[0]->{'DEVICEID'} || $_[0]->{'_DEVICEID'}); }

##
sub _SITE {
	my ($self) = @_;
	return($self->{'*SITE'});
	}

## UTILITY READ+WRITE FUNCTIONS
sub session { if (defined $_[1]) { $_[0]->{'SESSION'} = $_[1]; } return($_[0]->{'SESSION'}); }

##
## cartid (unique session id)
##
#sub has_cart2 { 
#	return( (defined $_[0]->{'*CART2'})?1:0 ); 
#	}




##
## returns a reference to internal %CARTS object
##
sub CARTS {
	my ($self) = @_;
	if (not defined $self->{'%CARTS'}) { $self->{'%CARTS'} = {}; }

	return($self->{'%CARTS'});
	}

## 
sub cartids {
	my ($self) = @_;
	my @cartids = ();
	foreach my $cartid (keys %{$self->{'%CARTS'}}) {
		push @cartids, $cartid;
		}
	return(@cartids);
	}

##
##
##
sub linkCART2 { 
	my ($self, $CART2) = @_;
	$self->{'%CARTS'}->{ $CART2->cartid() } = $CART2;
	}


##
##
## options:
##		onlycache=>1 	: only if cached
##		create=>0|1
##
sub cart2 {
	my ($self, $cartid, %options) = @_;

	my $CART2 = undef;
	if (not defined $cartid) {
		warn "JSONAPI::cart2 called without cartid\n";
		}
	elsif ($options{'onlycache'}) {
		## only return if it's in cache, otherwise UNDEF
		$CART2 = $self->{'%CARTS'}->{$cartid};
		}
	elsif ($self->{'%CARTS'}->{$cartid}) {
		## we can return it, because it's in cache
		$CART2 = $self->{'%CARTS'}->{$cartid};
		}
	else {
		## SANITY: at this point the cart isn't in cache
		if (not defined $options{'create'}) { $options{'create'} = 1; }
		$CART2 = CART2->new_persist( $self->username(), $self->prt(), $cartid, '*SESSION'=>$self, %options );
		if (defined $CART2) {
			$self->{'%CARTS'}->{ $CART2->cartid() } = $CART2;
			}
		}

	return($self->{'%CARTS'}->{$cartid});
	}



##
##
sub is_admin {	
	my ($self) = @_; return($self->{'_IS_ADMIN'});	
	}

sub is_spooler {	
	my ($self) = @_; return($self->{'_IS_SPOOLER'});	
	}

sub is_buyer { return($_[0]->isLoggedIn()); }
sub authenticateBuyer {
	my ($self) = @_;
	my $success = 0;
	return($success);
	}
## only if set/verified.
sub authtoken { return($_[0]->{'_AUTHTOKEN'}); }

##
##
##
sub sessionInit {
	my ($self, $session) = @_;

	my $REDISKEY = sprintf("session[%s].%s",$self->username(),$session);
	print STDERR "REDISKEY $REDISKEY\n";
	
	my ($redis) = &ZOOVY::getRedis($self->username(),0);
	my $YAML = '';
	if ($redis) {
		$YAML = $redis->get($REDISKEY);
		print STDERR "SESSION YAML [$REDISKEY]: $YAML\n";
		}
	else {
		warn sprintf("NO REDIS DATABASE FOR: %s\n",$self->username());
		}
	
	if ($YAML ne '') {
		require YAML::Syck;
		my $ref = $self->{'%SESSION'} = YAML::Syck::Load($YAML);
		
		if (scalar(keys %{$ref})>$JSONAPI::MAX_CARTS_PER_SESSION) {
			warn "session [$REDISKEY] too large, hopefully a bot. nuking.\n";
			$redis->del($REDISKEY);
			$ref = {};
			}

		my @PAYMENTQ = ();
		foreach my $k (keys %{$ref}) {
			if ($k eq '#CUSTOMER') {
				if ($ref->{'#CUSTOMER'} > 0) {
					$self->{'*CUSTOMER'} = CUSTOMER->new( $self->username(), 'PRT'=>$self->prt(), 'CID'=>$ref->{'#CUSTOMER'}, 'INIT'=>0x1 );
					}
				# print STDERR 'INSTANTIATED CUSTOMER: '.Dumper( $self->{'*CUSTOMER'}, $ref );
				}
			elsif ($k =~ /^#CART:(.*?)$/o) {
				my ($CART2) = CART2->new_persist( $self->username(), $self->prt(), $1, '*SESSION'=>$self );
				if (defined $CART2) {
					$self->{'%CARTS'}->{ $CART2->cartid() } = $CART2;
					}
				}
			elsif ($k =~ /^#(GIFTCARD|PAYPALEC)\:(.*?)$/o) {
				my ($payment) = &ZTOOLKIT::parseparams($ref->{$k});
				## it would be nice to refresh giftcards here.
				# my ($cardinfo) = GIFTCARD::lookup($self->username(),'CODE'=>$ref->{'#GIFTCARD'});
				push @PAYMENTQ, $payment;
				## the insert cmd below, don't use it, it gets an erro (although it'd be nice if we could someday)
				## $self->paymentQCMD({},'insert',$payment);	
				}
			else {
				## not sure wtf this is .. (just in case we'll copy it into $self)
				}
			}
		$self->paymentQ(\@PAYMENTQ);

		print STDERR "sessionInit: ".Dumper($ref,$self->paymentQ())."\n";
		}

	## print STDERR "!!!!!! INIT SESSION: [$session]\n";
	$self->sessionid( $session );

	## 
	## backward compatibility - this stuff is *probably* necessary as long as there are still vstores
	##
	## versions after 201311 store customer auth in the session and simply update the cart
	if ($self->{'*CUSTOMER'}) {
		foreach my $cartid (keys %{$self->{'%CARTS'}}) {
			$self->{'%CARTS'}->{ $cartid }->customer( $self->{'*CUSTOMER'} );
			}
		}

	return($self);
	}

##
##
##
sub sessionSave {
	my ($self) = @_;

	my %DATA = ();

	print STDERR sprintf("!!!! SAVE SESION: %s [%s]\n",$self->sessionid(),$self->username());

	if (($self->sessionid() ne '') && ($self->username() ne '')) {

		my $REDISKEY = sprintf("session[%s].%s",$self->username(),$self->sessionid());
		my ($redis) = &ZOOVY::getRedis($self->username(),0);
		## THINGS WE WANT TO SAVE GO INTO %DATA
		## NOTE: we will NOT save _IS_ADMIN because that is passed with each request.

		$DATA{'#CUSTOMER'} = 0;
		if (defined $self->{'*CUSTOMER'}) {
			## $self->{'*CUSTOMER'} is a SESSION AUTHENTICATED CUSTOMER! 
			$DATA{'#CUSTOMER'} = $self->{'*CUSTOMER'}->cid();
			if ($DATA{'#CUSTOMER'}==0) {
				delete $DATA{'#CUSTOMER'};
				}
			elsif ($DATA{'#CUSTOMER'}<0) {
				warn "FIXED ATTEMPT TO SAVE -1 CUSTOMER\n".Dumper($self->{'*CUSTOMER'});
				delete $DATA{'#CUSTOMER'};
				}
			}

		foreach my $k (keys %{$self->{'%CARTS'}}) {
			next if ($k eq '');
			$DATA{sprintf("#CART:%s",$k)}++;
			}


		foreach my $payment (@{$self->paymentQ()}) {
			## store any giftcard's that were added.
			if ($payment->{'TN'} eq 'PAYPALEC') {
				$DATA{sprintf("#PAYPALEC:%s",$payment->{'PI'})} = &ZTOOLKIT::buildparams($payment,1);
				}
			elsif ($payment->{'TN'} eq 'GIFTCARD') {
				$DATA{sprintf("#GIFTCARD:%s",$payment->{'GI'})} = &ZTOOLKIT::buildparams($payment,1);
				}
			else {
				warn sprintf("session Discarding payment %s\n",$payment->{'TN'});
				}
			}


		my $YAML = YAML::Syck::Dump(\%DATA);
		print STDERR "SESSION STORE YAML: $YAML\n".Dumper($self->paymentQ())."\n";
		if (not defined $redis) {
			warn "\$redis NOT DEFINED -wtf?\n";
			}
		else {
			$redis->setex($REDISKEY,3600*6,$YAML);
			}
		}

	
	## version 201311 started using %CARTS (with multi-cart support)
	foreach my $cartid (keys %{$self->{'%CARTS'}}) {
		next if ($cartid eq '');
		print STDERR "SAVING CART: $cartid\n";
		if ((not defined $self->{'%CARTS'}->{$cartid}) || (ref($self->{'%CARTS'}->{$cartid}) ne 'CART2')) {
			warn "sessionSave attempt to save a cart object $cartid that is invalid\n";
			}
		elsif ($self->{'%CARTS'}->{$cartid}->is_readonly()) {
			## no saving for you!
			}
		else {
			$self->{'%CARTS'}->{$cartid}->cart_save();
			}
		}

	return();
	}

## get/set a sessionid
sub sessionid {
	if (defined $_[1]) { $_[0]->{'SESSIONID'} = $_[1]; } return($_[0]->{'SESSIONID'});
	return($_[0]->{'SESSIONID'});
	}



sub gref { return(&JSONAPI::globalref(@_)); }	## legacy name
sub globalref {
	my ($self) = @_;
	if (not defined $self->{'*GLOBAL'}) {
		$self->{'*GLOBAL'} = &ZWEBSITE::fetch_globalref($self->username());
		}
	return($self->{'*GLOBAL'});
	};

sub webdbref { return(&JSONAPI::webdb(@_)); }
sub webdb { 
	my ($self) = @_;
	if (not defined $self->{'*WEBDB'} ) {
		$self->{'*WEBDB'} = &ZWEBSITE::fetch_website_dbref($self->username(),$self->prt());
		}
	return($self->{'*WEBDB'});
	# return($_[0]->_SITE()->webdbref()) 
	};
## seriously trying to get rid fo profile specific settings..



##
## if we set a customer at the JSONAPI level, it will inform any associated carts.
##
sub customer { 
	my ($self, $C) = @_;

	if (defined $C) { 
		$self->{'*CUSTOMER'} = $C; 
		}

	return($self->{'*CUSTOMER'}); 
	}







########################################################################################################
##
sub append_msg_to_response {
	my ($R,$msgtype,$msgid,$msgtxt) = @_;

	if (not defined $R->{'_msgs'}) { $R->{'_msgs'} = 0; }
	$R->{'_msgs'}++;
	$R->{sprintf('_msg_%d_type',$R->{'_msgs'})} = $msgtype;
	$R->{sprintf('_msg_%d_id',$R->{'_msgs'})} = $msgid;
	$R->{sprintf('_msg_%d_txt',$R->{'_msgs'})} = $msgtxt;
	return();
	}



sub error_cmd_removed_since {
	my ($R,$v,$release,$hint) = @_;
	if ($hint eq '') { $hint = 'not available'; }
	&JSONAPI::set_error($R,'apperr',152,sprintf("_cmd %s removed in release %d. hint: %s",$v->{'_cmd'},$release,$hint));
	}

##
## use this as an "else" handler so we don't have to burn a lot of unique error codes
##
sub validate_unknown_cmd {
	my ($R,$v) = @_;
	&JSONAPI::set_error($R,'iseerr',151,sprintf("Unhandled _cmd %s within %s",$v->{'_cmd'},join(";",caller(1))));
	}

##
##
sub dbh_do {
	my ($R,$dbh,$pstmt,$msg) = @_;

	my ($rv) = $dbh->do($pstmt);
	if ($dbh->err()) {
		my ($mod,undef,$line) = caller(0);
		if (not defined $msg) { $msg = sprintf("DB Error %s in %s line #%d", $dbh->errstr(), $mod,$line ); }
		&JSONAPI::set_error($R,'iseerr',154,$msg);
		if (defined $pstmt) { $R->{'_sql'} = $pstmt; }
		}
	return($rv);
	}

##
##
sub validate_required_parameter {
	my ($R,$v,$key,$validarrayref) = @_;
	my $is_valid = 0;
	my $value = $v->{$key};

	if (ref($validarrayref) eq 'ARRAY') {
		## array type has constant
		foreach my $valid (@{$validarrayref}) {
			if ($value eq $valid) { $is_valid++; }
			}
		}
	elsif (ref($validarrayref) eq '') {
		## scalar type: !? perhaps number, text, etc?
		if (not defined $value) {
			}
		# elsif ($validarrayref eq 'XYZ') {} 
		elsif ($value ne '') {  $is_valid++;  }
		}

	if ($is_valid) {
		}
	elsif ((not defined $v->{$key}) || ($value eq '')) {
		&JSONAPI::set_error($R, 'apperr', 109,sprintf("A required parameter \"%s\" was not found or was blank",$key));
		}
	elsif (ref($validarrayref) eq 'ARRAY') {
		&JSONAPI::set_error($R, 'apperr', 110,sprintf("A required parameter \"%s\" was set to \"%s\", allowed values (%s)",$key,$value,join(",",@{$validarrayref})));
		}
	else {
		&JSONAPI::set_error($R, 'apperr', 111,sprintf("A required parameter \"%s\" was not set, and is required.",$key));
		}
	return($is_valid);
	}

##
## returns true if they have a flag, false if they don't, and sets errid if if they don't (since we'll assume its' required)
##
sub hasFlag {
	my ($self,$R,$flag) = @_;
	
	my $hasFlag = 1;

	if (not defined $self->globalref()) {
		warn "SITE:->globalref() is not defined - hasFlag '$flag' will not work, so returning true.";
		}
	elsif ($self->globalref()->{'cached_flags'} !~ /,$flag,/) {
		$hasFlag = 0;
		&JSONAPI::set_error($R,"apierr",6000,"This feature requires the $flag bundle - which is not enabled on this account.");
		}
	return( $hasFlag );
	}


sub deprecated {
	my ($self,$R,$version) = @_;

	if ($version > 0) {
		if ($self->apiversion() >= $version) {
			&JSONAPI::set_error($R,'apperr',666,"Deprecated");		
			return(1);
			}
		}
	else {
		$version = 0-$version;
		if ($self->apiversion() <= $version) {
			&JSONAPI::set_error($R,'apperr',666,"Deprecated - please upgrade to $version");		
			return(1);
			}
		}
	return(0);
	}


sub projectdir {
	my ($self, $project) = @_;
	my $dir = undef;
	if ($project =~ /^[A-Z0-9\-]+/) {
		my $userpath = &ZOOVY::resolve_userpath($self->username());
		$dir = "$userpath/PROJECTS/$project";
		}
	return($dir);
	}




##
## internal function so code reads easier
##
sub hadError { 
	my ($R) = @_;  

	if (defined $R->{'errid'}) {
		return($R->{'errid'}); 
		}

	if ((defined $R->{'_msgs'}) && ($R->{'_msgs'}>0)) {
		## look in messages for errors.
		my $hadError = 0;
		foreach my $i (1.. int($R->{'_msgs'})) {
			## look for: youerr|apperr|apierr|iseerr

			if (substr($R->{sprintf("_msg_%d_type",$i)},3,3) eq 'err') {
				$hadError = $R->{sprintf("_msg_%d_id",$i)};
				}
			}
		return($hadError);
		}

	return(0);
	}



##
## internal function so code reads easier
##
sub hadSuccess { 
	my ($R) = @_;  

	my $success = 0;
	if (not defined $R->{'_msgs'}) {
		}
	elsif ($R->{'_msgs'}==0) {
		}
	else {
		foreach my $msg ( 1 .. $R->{'_msgs'}) {
			if ($R->{sprintf('_msg_%d_type',$msg)} eq 'success') { $success = $msg; }
			}
		}	
	return($success);
	}


##
## internal function so code reads easier
##
sub hadMissing { 
	my ($R) = @_;  

	my $success = 0;
	if (not defined $R->{'_msgs'}) {
		}
	elsif ($R->{'_msgs'}==0) {
		}
	else {
		foreach my $msg ( 1 .. $R->{'_msgs'}) {
			if ($R->{sprintf('_msg_%d_type',$msg)} eq 'missing') { $success = $msg; }
			}
		}	
	return($success);
	}


##
## 
##
sub isLoggedIn {
	my ($self,$R,$v) = @_;

	my $success = 0;
	
	if (not $self->customer()) {
		&JSONAPI::set_error($R,'apperr',123,"Buyer Authentication is required to make this call");
		}
	elsif (ref($self->customer()) ne 'CUSTOMER') {
		&JSONAPI::set_error($R,'apperr',124,"Customer object is not valid, or customer is not logged in.");
		}
	else {
		$success = $self->customer()->cid();		
		}

	return($success);
	}


##
## pass the $cmdset from the @CMDS
##		pass a message ex: ERROR|xyz
##
sub add_macro_msg {
	my ($R,$macrocmd,$msg) = @_;
	if (not defined $R->{'@RESPONSES'}) {
		$R->{'@RESPONSES'} = [];
		}

	my $macro = $macrocmd->[2];
	my $linecount = $macrocmd->[3];		

	my ($msgref,$status) = &LISTING::MSGS::msg_to_disposition($msg);
	$msgref->{'macro'} = $macro;
	$msgref->{'line'} = $linecount;

	if (defined $msgref->{'+'}) { $msgref->{'msg'} = $msgref->{'+'}; delete $msgref->{'+'}; }
	if (defined $msgref->{'!'}) { $msgref->{'msgtype'} = $msgref->{'!'}; delete $msgref->{'!'}; }	## SIMPLE SUCCSS|ERROR
	if (defined $msgref->{'_'}) { $msgref->{'msgsubtype'} = $msgref->{'_'}; delete $msgref->{'_'}; }	## detailed FAIL-SOFT
	
	push @{$R->{'@RESPONSES'}}, $msgref;
	return();
	}

##
##
##
sub set_error {
	my ($R,$errtype,$errid,$errmsg) = @_;

	$R->{'errtype'} = $errtype; 
	$R->{'errid'} = $errid;
	$R->{'errmsg'} = $errmsg;
	return($R);
	}

#
# incoming parameters:
# _uuid : the unique request id (should be reasonably unique)
# _cmd : the command you're asking us to do
# _cartid : zoovy jsonapi session identifier
# .. other params .. (depends on cmd)
# 
# cmd == addtocart
# 		pid : the product id
#		options..
# 		qty :
#
#



=pod

<SECTION>
<h1>API Usage</h1>
Jquery parameters are passed back and forth using a json hash containing 3 critical elements:
_uuid, _cartid, and either _cmd (for single commands) 
The API itself is designed to be asynchronous, however at this time only a synchronous responses are
available. 

*_uuid : a unique request id, this is passed back, and is used to identify duplicate requests.
*  _cartid : the unique cart id (cart id) for this cart, you will receive this after making a request if you do
not pass one, you must store this in the browser and pass it on subsequent requests.
* _cmd : a complete list of commands is passed below.  If _cmd is used then parameters to _cmd are passed in the
upper hash at the same level as _cmd.  If @cmds is used, then that is an array of hashes, each with their
own "_cmd" - the example below includes *both usages*, however you will only need to use one:

<CODE>
{
"_uuid" : 1234,
"_cartid" : "12345",
"_cmd" : "cartItemsAdd",
"_tag" : "some data you'd like returned",
"_v" : "unique mvc/app id (used for debugging)"
 }
</CODE>
</SECTION>

<SECTION>
<h1>Error Handling</h1>
handling errors is *critical* to a well behaved application, since there are literally hundreds of things
which can go wrong at any one time.  With each command (_cmd) request the Zoovy backend will return at a 
minimum: "rcmd", "rid", and "rmsg". 
The exact response format depends on how the request was made, if _cmd is used, then the response will 
include "rcmd" in the response, if @cmds was used, then both a top level "rcmd" indicating 
success/failure/ warnings of all commands, in addition to an array of hashes containing rcmds for
each individual request.
<CAUTION>
It is important when working with @cmds that you still check "rcmd" before looking at responses in 
@rcmds because based on the rcmd (ex: "ise") there may be no specific responses. 
</CAUTION>

* # : the unique request you sent in _uuid
* rcmd : the type of request you sent can be 'ise', or 'err'.
* if a fatal internal error if rcmd is 'ise', then an 'rid' (response error id) and 'rmsg') will be returned
* if 'rcmd' is 'err' then it's a formatting error that can be corrected.

A good rule of thumb is that an 'err' is 100% correctable by you, and an 'ise' *might* be correctable by you,
but it's probably on Zoovy's end.  (The example where an 'ise' might be correctable would include a non-
handled error on Zoovy's backend, if you fix the error the ise will go away). 
On a successful call the rcmd will be the same '_cmd' that was received, or 'ok' if '@cmds' was used.
<CAUTION>
*do not* check for the presence of 'errid' to determine if an error occurred. if '_rcmd' had a warning
(such as old call parameters) then errid and errmsg may also be returned, even though the request had
actually succeeded.
</CAUTION>
</SECTION>

<SECTION>
<h1>Pipelined Requests</h1>

Request:
<CODE>
{
"_cmd" : "pipeline",
"@cmds" : [
  { "_cmd" : "", .. other parameters .. }
  ],
}
</CODE>
Response:
<CODE>
{
"_rcmd" : "pipeline",
"@rcmds" : [
	{ "_rcmd" : "", .. other parameters .. }
	],
}
</CODE>
</SECTION>

<SECTION>
<h1>Errors</h1>
* rcmd 'ise', errid 1, request could not be processed.
* rcmd 'err', errid 2, errmsg Could not determine domain/associated site
* rcmd 'err', errid 3, errmsg Could not determine associated username
* rcmd 'err', errid 99, errmsg request did not deserialize properly
* rcmd 'err', errid 102,	errmsg Unknown _cartid parameter passed
* rcmd 'err',	errid	103,	errmsg No _cartid parameter passed
* rcmd 'err',	errid	104,	errmsg No _cmd parameter passed
* rcmd 'err',	errid	105,	errmsg Invalid _cmd parameter passed
* rcmd 'err',	errid	106,	errmsg Invalid inside _cmd parameter passed
* rcmd 'err', errid 107,  errmsg Unhandled else condition in _cmd @cmd detection
* rcmd 'err', errid 108,  errmsg No valid commands could be found, please check your formatting.
* rcmd 'err', errid 109,  errmsg A required parameter \"\" was not found or was blank
* rcmd 'err', errid 110,  errmsg A required parameter \"\" was set to \"\", allowed values (valid: x,y,z)
* rcmd 'err', errid 111,  errmsg Invalid or Corrupted Cart
* rcmd 'err', errid 123,  errmsg Cart Authentication is required to make this call
* rcmd 'err', errid 122,  errmsg Internal error in response from command stack.
* rcmd 'err', errid 149,  errmsg buyer login required.
* rcmd 'err', errid 150,  errmsg admin priviledges required.
* rcmd 'err', errid 151,  errmsg illegal parameter passed.
</SECTION>

=cut



## 
##
sub handle {
	my ($self,$v,%options) = @_;

	my %R = ();
	my $i = 0;

	my $TRACE = 0;
	if (&ZOOVY::servername() =~ /^(dev|staff)$/) { $TRACE++; }
	@JSONAPI::TRACE = ();

	if ($TRACE) {
		push @JSONAPI::TRACE, "--- START $$";
		push @JSONAPI::TRACE, sprintf("sdomain:%s prt:%s",$self->sdomain(),$self->prt());
		push @JSONAPI::TRACE, $v;
		}
	
	if (ref($v) eq 'HASH') {
		## hmm.. we need to make sure $v is a hash before we try and copy data out of it to prevent ise's
	 	if (defined $v->{'_uuid'}) { $R{'_uuid'} = $v->{'_uuid'}; }
	 	if (defined $v->{'_tag'}) { $R{'_tag'} = $v->{'_tag'}; }
		}
	elsif ((not defined $self->username()) || ($self->username() eq '')) {
		&JSONAPI::set_error(\%R, 'apperr', 2, 'Could not determine associated user');
		}

	if (defined $R{'errid'}) {
		## no sense going any further, something bad already happened.
		}
	elsif (ref($v) ne 'HASH') {
		&JSONAPI::set_error(\%R, 'apperr', 99,'Request did not deserialize properly.');
		}
	elsif (not defined $v->{'_uuid'}) {
		&JSONAPI::set_error(\%R, 'apperr',98,'Unknown _uuid parameter passed');
		}

	##
	## SANITY: at this point we've finished our structural check
	##		%R (response) has been set to errid>0 
	##			*OR* 
	##		we can assume we're dealing with a well formed set of cmds (no more structural checks)
	##		
	##	NEXT:
	##		we need to build @cmdlines which WILL be an array of [  [pos,cmdref,result], [pos,cmdref,result] ]
	##	 

	my @CMDLINES = ();	# array of arrayrefs [ pos, cmdset{_cmd,_cartid,etc}, response{} ]

	if (&JSONAPI::hadError( \%R )) {
		## no sense going any further, something bad already happened.
		}
	elsif (not defined $v->{'_cmd'}) {
		($R{'_rcmd'},$R{'_uuid'}) = ('err',0);
		&JSONAPI::set_error(\%R, 'apperr',97,'No _cmd or @cmds parameter passed');	
		}
	elsif ($v->{'_cmd'} eq 'pipeline') {
		## pipelined cmd request - check $v->{'@cmds'} for commands
		my $i = 1;

		foreach my $cmdset (@{$v->{'@cmds'}}) {
			if (not defined $cmdset->{'_cmd'}) {
				($R{'_rcmd'},$R{'_uuid'}) = ('err',0);
				&JSONAPI::set_error(\%R, 'apperr',96,'No inside _cmd parameter passed');
				}
			elsif (not defined $JSONAPI::CMDS{ $cmdset->{'_cmd'} }) {
				&JSONAPI::set_error(\%R, 'apperr',95,sprintf('Invalid inside _cmd "%s" parameter passed',$cmdset->{'_cmd'}));
				}
			else {
				## copy required variables from $v
				$cmdset->{'_is_pipelined'} = $i;
				foreach my $k ('_cartid','_admin','_uuid','_tag','_v') {
					if (not defined $cmdset->{$k}) { $cmdset->{$k} = $v->{$k}; }
					}
				push @CMDLINES, [ $i, $cmdset, undef ]; # see SANITY: for explanation
				$i++;	
				}
			}
		}
	elsif ($v->{'_cmd'}) {
		## non-pipelined request
		$v->{'_is_pipelined'} = 0;
		if (not defined $JSONAPI::CMDS{ $v->{'_cmd'} }) {
			$R{'_rcmd'} = 'err';
			&JSONAPI::set_error(\%R, 'apperr', 94,'Invalid _cmd parameter passed');
			}
		else {
			push @CMDLINES, [ 0, $v, undef ];		# pos[0] is reserved for non-pipelined cmds
			}
		}
	else {
		$R{'_rcmd'} = 'err';
		&JSONAPI::set_error(\%R, 'apperr', 93, 'Unhandled else condition in _cmd @cmd detection');
		}	

	##
	## SANITY: at this point @CMDLINES should be an array of
	##				[ pipepos, $cmdref, $responseref ],
	##				[ pipepos, $cmdref, $responseref ],
	##				[ pipepos, $cmdref, $responseref ],
	##				cmdref[1] is a hashref of variables ($v to the function)
	##				responseref[2] for each element is undefined at this point 
	##				each cmdref in @CMDLINES has the _is_pipelined set	to 0 (no), or 1+ (yes=pipepos)
	##			  we've also done some more high level checks to make sure that all the calls requested are possible
	##			  or %R is set with errid>0
	##			  
	##	NEXT: initialize global objects ex: cart, buyer auth, admin auth, etc.
	##

	my %CACHE = ();
	# $CACHE{"foo"}++;
	my %APICALLS = ();		## a hash of api calls and their counts

	if (defined $R{'errid'}) {
		## no sense going any further, something bad already happened.
		warn "ERR: $R{'errid'}\n";

		}
	elsif (scalar(@CMDLINES)==0) {
		$R{'_rcmd'} = 'err';
		&JSONAPI::set_error(\%R, 'apperr', 92, 'No valid commands could be found, please check your formatting.');
		}
	elsif ($self->apiversion()>201311) {
		##
		## version 201311+ can fail a command based strictly on permissions/formatting
		##

		foreach my $cmdline (@CMDLINES) {
			#print STDERR "JSONAPI::CMDS ".Dumper($JSONAPI::CMDS{ $cmd->[1]->{'_cmd'} })."\n";
			next if (not defined $JSONAPI::CMDS{ $cmdline->[1]->{'_cmd'} });

			my ($function, $params, $group, $permis) = @{$JSONAPI::CMDS{ $cmdline->[1]->{'_cmd'} }};
			next if (not defined $function);

			if (not defined $params->{'admin'}) { $params->{'admin'} = 0; }
			if (not defined $params->{'buyer'}) { $params->{'buyer'} = 0; }
			
			my $cmdv = $cmdline->[1];
			my $cmdr = $cmdline->[2];		## response (undef = good to go, defined = error)

			if ($params->{'cart'}) {
				if ($cmdv->{'_cartid'} eq '') {
					$cmdr = &JSONAPI::set_error($cmdr, 'apperr', 90, 'No _cartid parameter passed!');
					open F, ">/tmp/x";
					print F Dumper($cmdline);
					close F;
					}
				}			

			if (defined $cmdr) {
				}
			elsif ((defined $params->{'deprecated'}) && (int($params->{'deprecated'})>0) && (int($params->{'deprecated'}) < $self->apiversion())) {
				$cmdr = &JSONAPI::set_error({}, 'apperr', 99, sprintf("API CMD '%s' is not available beyond release %d %s.",$cmdv->{'_cmd'},$params->{'deprecated'}));
				}
			else {
				}

			if ((not defined $cmdr) && (($params->{'admin'} & 1)==1)) { 
				## requires hard auth
				if (not $self->is_admin()) {
					$cmdr = &JSONAPI::set_error($cmdr,'apperr',150,'Admin authentication is required');
					}
				else {
					my $okay = 1;
					my %R = ();
					my $LU = $self->LU();
	
					## open F, ">/tmp/foo";	print F Dumper($LU)."\n";	close F;
	
					foreach my $perm_key (keys %{$permis}) {
						next if (defined $cmdr);
						my $perm_val = $permis->{$perm_key};
						next if (not defined $perm_val);

						if (not $LU->hasACL($perm_key,$perm_val)) { 
							my $cmd = $cmdline->[1]->{'_cmd'};
							my $PRETTY_KEY = $perm_key;
							my $PRETTY_VAL = $OAUTH::ACL_PRETTY{$perm_val};
							$cmdr =  &JSONAPI::set_error($cmdr,'apperr',151,"Permission $PRETTY_KEY:$PRETTY_VAL($perm_val) is required for $cmd");
							}
						}
					}

				}

			if ((defined $cmdr) || (not defined $params->{'buyer'})) {
				## shit already happened
				## OR we don't need to check buyer permissions
				}
			elsif ($params->{'buyer'}==1) { 
				## allows requires hard auth only, so we can short circuit here
				if (not $self->is_buyer()) {
					$cmdr = &JSONAPI::set_error($cmdr,'apperr',89,'Buyer authentication is required'); 
					}
				}
			else {
				## requires either hard or soft auth
				my $success = 0;
				if ($self->is_buyer()) { $success |= 1; }

				if ( (not $success) && (defined $cmdv->{'softauth'}) && ($cmdv->{'softauth'} eq 'order')) {
					##
					## SOFT AUTHENTICATION
					## softauth is requested, and allowed so lets try that.
					##
					my ($orderid) = ($cmdv->{'orderid'});
					if ((not defined $orderid) || ($orderid eq '')) { $orderid = undef; }
					if ((not defined $orderid) && ($cmdv->{'erefid'} ne '')) {
						## lookup by erefid if orderid was not specified
						($orderid) = CART2::lookup($self->username(),'EREFID'=>$cmdv->{'erefid'});
						}

					my ($O2,$err) = (undef,undef);
					if ($orderid eq '') {
						&JSONAPI::set_error($cmdr,'apperr',184,'Soft-auth failure: order could not be found using orderid or erefid');
						}
					else {
						($O2) = CART2->new_from_oid($self->username(),$orderid);
						if (not defined $O2) {
							&JSONAPI::set_error($cmdr,'iseerr',180,sprintf('Soft-auth order error: %s',$err));
							}
						}

					if (&hadError($cmdr)) {
						## something went wrong, if we didn't go here, then $O2 is assumed to be valid.
						$O2 = undef;
						}	
					elsif ($O2->in_get('cart/cartid') eq '') {		
						&JSONAPI::set_error($cmdr,'apperr',185,'Soft-auth failure: cartid was specified in order.');
						$O2 = undef;
						}
					elsif ($O2->in_get('cart/cartid') ne $cmdv->{'cartid'}) {
						&JSONAPI::set_error($cmdr,'apperr',186,'Soft-auth failure: supplied cartid does not match order');	
						$O2 = undef;
						}
					else {
						$success |= 2;
						$cmdv->{'orderid'} = $O2->oid();
						$CACHE{ sprintf("*CART2[%s]",$O2->oid()) } = $O2;
						}

					if (not $success) {
						&JSONAPI::set_error($cmdr,'apperr',88,'Buyer authentication is required (hard or soft is acceptable)'); 
						}

					## print STDERR Dumper($cmdv,$cmdr);
					}

				## END BUYER/ORDER SOFTAUTH
				}

			if (defined $cmdr) {
				## $cmdr is already set, so we got some type of error.
				$cmdline->[2] = $cmdr;
				}

			$APICALLS{ $cmdline->[1]->{'_cmd'} }++;		## appCartExists=>1, etc.
			}		
		
				
		if ($self->{'_session'}) {
			}

		}
	else {
		## this line should never be reached, if it is - we have a problem.
		$self->{'*LU'} = undef;
		$self->{'*CART2'} = undef;
		$self->{'*CUSTOMER'} = undef;
		}



	##
	## SANITY: at this point $R{'errid'} is set
	##			  all global objects are initialized
	##	NEXT: start cmd processing!
	##

	if ($R{'errid'}>0) {
		($R{'_diagnostic_received_parameters'}) = 'Received parameters: '.join(",",keys %{$v});
		}
	# elsif (not defined $R{'errid'}) {
	elsif (not &JSONAPI::hadError(\%R)) {
		my $was_pipelined = 0;
		foreach my $cmdline (@CMDLINES) {

			my ($is_pipelined,$cmdset) = @{$cmdline};
			if ($is_pipelined) { $was_pipelined++; }
			my ($response) = (undef);

			## print STDERR "CMD: $cmdset->{'_cmd'}\n";

			if ( defined $cmdline->[2] ) {
				## array position #2 holds the response, if it's defined already we don't run the command.
				$response = $cmdline->[2];
				}
			elsif ( defined $JSONAPI::CMDS{ $cmdset->{'_cmd'} } ) {
				eval {  ($response) = $JSONAPI::CMDS{ $cmdset->{'_cmd'} }->[0]->( $self, $cmdset, \%CACHE ); };
				if ($@) {
					$response = { '_'=>$response, $self, $cmdset };
					## 122 usually means the command is missing a %R
					&JSONAPI::set_error($response, 'iseerr', 222, sprintf('ISE: %s',$@));	
					}
				elsif (ref($response) ne 'HASH') {
					## just a quick sanity check
					$response = { '_'=>$response };
					## 122 usually means the command is missing a %R
					&JSONAPI::set_error($response, 'iseerr', 122, 'Non-Hash Response format from command. (error response is stored in _)');	
					}
				}
			else {
			 	&JSONAPI::set_error($response, 'apierr', 104, 'Invalid _cmd parameter passed');
				}

			$response->{'_uuid'} = $cmdset->{'_uuid'};
			$response->{'_rcmd'} = $cmdset->{'_cmd'};
			$response->{'_rtag'} = $cmdset->{'_tag'};
			$cmdline->[2] = $response;
			}

		## SANITY: finished processing @CMDLINES at this point, now prepare \%R for a final response.

		if (not $was_pipelined) {
			## non pipelined request, so collapse the response ($cmdlines[0]->[2]) into $R for response
			foreach my $k (keys %{$CMDLINES[0]->[2]}) {
				$R{$k} = $CMDLINES[0]->[2]->{$k};
				}
			}
		else {
			$R{'_rcmd'} = 'pipeline';
			foreach my $cmdline (@CMDLINES) {
				push @{$R{'@rcmds'}}, $cmdline->[2];
				}
			}
		}

	if (-f sprintf("/dev/shm/%s.trace",$self->sdomain())) { $TRACE++; }

	# $TRACE++;
	if ($TRACE) {
		print STDERR "TRACE:$TRACE ".$self->sdomain()."\n";
		push @JSONAPI::TRACE, [ 'cmdlines', \@CMDLINES ];
		push @JSONAPI::TRACE, "--- END ---";

		open Fx, ">>/tmp/trace-".$self->sdomain().".log";
		print Fx Dumper(\@JSONAPI::TRACE);
		close Fx;
		}

	if ($self->is_spooler()) {
		## no running sessionSave (this will try and save the cart)
		}
	else {
		$self->sessionSave();
		}

	return(\%R,\@CMDLINES);
	}





=pod 

<API id="helpAPI">
<input id="keywords"></input>
<output id="@RESULTS">
[ 'docid':'doc1', 'score':'52.533', 'title':'title of document 1', 'summary':'plain text summary' ]
[ 'docid':'doc2', 'score':'42.232', 'title':'title of document 2', 'summary':'plain text summary' ]
</output>
</API>

<API id="helpDocumentGet">
<input id="docid">documentid</input>
<output id="body">html document</output>
</API>

=cut

##
##
##
sub helpWiki {
	my ($self, $v) = @_;
	my %R = ();

	my %params = ();
	foreach my $k (keys %{$v}) {
		next if (substr($k,0,1) eq '_');
		$params{$k} = $v->{$k};
		}
	my $paramstr = &ZTOOLKIT::buildparams(\%params);
	my $response = HTTP::Tiny->new->get("http://wiki.commercerack.com/wiki/api.php?$paramstr");

	if ($response->{success}) {
		if ($v->{'format'} eq 'json') {
			%R = %{JSON::XS::decode_json($response->{'content'})};
			}
		else {
			&JSONAPI::append_msg_to_response(\%R,'warn','format=json not passed, so response is html');				
			$R{'html'} = $response->{'content'};
			}
		&JSONAPI::append_msg_to_response(\%R,'success',0);				
		}
	else {
		&JSONAPI::set_error(\%R,'apierr',89113,sprintf("wiki.commercerack.com/wiki/api.php?$paramstr got $response->{status} $response->{reason}"));
		}
	
	## print STDERR 'RESPONSE: '.Dumper(\%R);

	return(\%R);
	}



=pod 

<API id="authAdminLogin">
<purpose>performs authentication and returns an admin session id which can be used to make adminXXXXX calls.</purpose>
<input id="device_note"></input>
<input id="ts" type="timestamp">current timestamp YYYYMMDDHHMMSS</input>
<input id="authtype" optional="1">md5|sha1|facebook|googleid|paypal</input>
<input id="authid" optional="1">for md5 or sha1 - it is a digest of hashtype(password+ts)</input>

<hint>
userid identifies a user (not a domain) within a specific account. A single user may have access to many partitions and many domains. There are
several valid ways to write a user.  Each account is assigned a 20 character "username", in addition there is a 10 digit sub-user called the "luser". 
the security administrator for every account is called "admin" and so the login for admin would be "admin*username" or simply "username" in addition
if a domain.com is associated to an account then it is also allowed to login as admin@domain.com.  The same applies for luser which would simply be 
luser*username or luser@domain.com.  Please note that login id's are NOT the same as email addresses, it is not possible to login with an email address
unless the users email address also happens to be luser@domain.com (which would be configured by security administrator)
</hint>

<hint>
authentication information (USERID, CLIENTID, DOMAIN, VERSION, AUTHTOKEN) can be passed in either of two ways - using HTTP Headers, or in the data payload.
The following is a mapping of HTTP Header to payload parameter.   X-USERID = _userid, X-DOMAIN = _domain, X-VERSION = _version, X-CLIENTID = _clientid,
X-DEVICEID = _deviceid, X-AUTHTOKEN = _authtoken.  Avoid using HTTP headers when making requests via the XHR XMLHTTPRequest from a browser, there are
numerous compatibility issues with the CORS (Cross Origin Resource Sharing) specification 2119 so use the payload version instead. Ex:
{ "_cmd":"someThing", "_clientid":"your client id", "_version":201249, } 
</hint>

<hint>
authAdminLogin calls do not require an authtoken (since they return it), depending on the circumstances the api may return a challenge 
which complies with the supported challenge methods. The list of acceptable challenge methods is determined by comparing the allowed challenge 
methods of the client (which were specified when the clientid was requested/assigned) and also the challenge types allowed by the administrator -
if no mutually acceptable challenge types can be identified then an error is returned and access is denied.  Challenges are issued based on the
accounts security administrator settings. 
</hint>

<hint>
authtype of md5|sha1 refers to the digest protocol being used (in all cases we will accept the hexadecimal notation)
the authid is generated by computing the md5 or sha1 hexadecimal digest value of the concatenation of plain_text_password and ts .
Given the following inputs password="A", ts="1B" then it would be md5("A1B") or sha1("A1B") respectively.
Both MD5 and SHA1 are widely implemented protocols and sufficiently secure for this exercise - 
we have included the appropriate security tokens as generated by the md5 and sha1 functions in 
mysql below (use these as a reference to test your own functions)

mysql> select md5('A1B');
+----------------------------------+
| md5('A1B')                       |
+----------------------------------+
| 9c8c7d6da17f5b90b9c2b8aa03812ab4 |
+----------------------------------+

mysql> select sha1('A1B');
+------------------------------------------+
| sha1('A1B')                              |
+------------------------------------------+
| 7b6bfc9420addb09c8cfb1ae5f71f8e797d4685d |
+------------------------------------------+

The ts value of "1B" would not be valid, it should be a date in YYYYMMDDHHMMSS format. 
The date must be within 60 seconds of the actual time or the request will be refused. 
In addition the random security string is ONLY valid for one request within a 1 hour period.
</hint>

<response id="authtoken">secret user key</response>
<response id="deviceid">deviceid</response>
<response id="userid">userid</response>
<response id="ts"></response>


<example>
X-USERID: user@domain.com
X-CLIENT: your.app.client.id
X-VERSION: 201246
X-DEVICEID: user_specified
X-DOMAIN: domain.com
Content-Type: application/json

{ "_cmd":"authAdminLogin", "ts":"YYYYMMDDHHMMSS or seconds since 1970", "authtype":"md5", "authid"  }
</example>

</API>



<API id="authNewAccountCreate">
<purpose>
establish a new anycommerce account (this data should be collected during the registration process)
</purpose>
<input id="domain"></input>
<input id="email"></input>
<input id="firstname"></input>
<input id="lastname"></input>
<input id="company"></input>
<input id="phone"></input>
<input id="verification">sms|voice</input>
<notes>returns a valid token to the account</notes>
<response id="ts">timestamp</response>
<response id="userid">login@username</response>
<response id="deviceid">login@username</response>
<response id="authtoken">login@username</response>
</API>

=cut


sub authNewAccountCreate {
	my ($self, $v) = @_;

	my %R = ();
	my $SOURCE = undef;
	## some other lead source, we at least know this came in from the web.
	my ($src,$opid,$meta) = split(/\|/,$SOURCE,3); 

	my $UUID = &ZTOOLKIT::xssdeclaw($v->{'UUID'});
	if ($UUID eq '') { 
		$UUID = Data::GUID->new()->as_string(); 
		}

	foreach my $k (keys %{$v}) {
		$v->{$k} = ZTOOLKIT::xssdeclaw($v->{$k});
		}

	if ($v->{'company'} eq '') { $v->{'company'} = $v->{'domain'}; }
	$v->{'company'} =~ s/^http\:\/\///g;
	$v->{'company'} =~ s/[\<\>\"\']+//gs;
	$v->{'phone'} =~ s/-//gs;

	if (!defined($v->{'phone'})) { &JSONAPI::set_error(\%R,"youerr",6002,"Sorry, phone number is required"); }
 	if ($v->{'firstname'} =~ /[\d]+/) { &JSONAPI::set_error(\%R,"youerr",6003,"Sorry, numbers are not allowed in your first name"); }
 	elsif ($v->{'lastname'} =~ /[\d]+/) { &JSONAPI::set_error(\%R,"youerr",6004,"Sorry, numbers are not allowed in your last name"); }
	elsif ( 
		($v->{'phone'} =~ /^[1]+$/) || ($v->{'phone'} =~ /^[2]+$/) || ($v->{'phone'} =~ /^[3]+$/) || 
		($v->{'phone'} =~ /^[1]+$/) || ($v->{'phone'} =~ /^[2]+$/) || ($v->{'phone'} =~ /^[3]+$/) || 
		($v->{'phone'} =~ /^[1]+$/) || ($v->{'phone'} =~ /^[2]+$/) || ($v->{'phone'} =~ /^[3]+$/)) {
		&JSONAPI::set_error(\%R,"youerr",6005,"Wow! Thats a pretty amazing phone number, are you sure it's correct? (Try again)");
		}
	elsif ($v->{'phone'} =~ /5551212$/) {
		&JSONAPI::set_error(\%R,"youerr",6006,"Please supply a valid phone number.");
		}
 	elsif (not &ZTOOLKIT::validate_phone($v->{'phone'},'')) {
		&JSONAPI::set_error(\%R,"youerr",6007,"Phone number missing or invalid.");
 		}
	if ($v->{'firstname'} eq '' || $v->{'lastname'} eq '') {
		&JSONAPI::set_error(\%R,"youerr",6008,"Please supply a first and last name.");
		} 

	if ($v->{'email'} eq '') {
		&JSONAPI::set_error(\%R,"youerr",6009,'Please supply a valid email address.');
		} 
 	elsif (!&ZTOOLKIT::validate_email($v->{'email'})) {
		&JSONAPI::set_error(\%R,"youerr",6010,'Email address appears invalid. Please try again.');
		} 
 	else {
		# email okay
		}

	my $IP = $ENV{'REMOTE_ADDR'};
	if (&JSONAPI::hadError(\%R)) {
		require SITE;
		my ($whatis) = &SITE::whatis($IP,$ENV{'HTTP_USER_AGENT'},$ENV{'SERVER_NAME'},$ENV{'REQUEST_URI'});
		if (($whatis eq 'SCAN') || ($whatis eq 'BOT')) {
			&JSONAPI::set_error(\%R,"apperr",6000,"Sorry, this computer is flagged as a bot and cannot make calls");
			}
		}

	if (&JSONAPI::hadError(\%R)) {
		&JSONAPI::set_error(\%R,"apperr",6000,"Sorry, online signup not currently available.");
		}

	return(\%R);
	}



#=pod
#
#<API id="appSessionRegister">
#<purpose>Using the client's identifier.</purpose>
#</API>
#
#<API id="appSessionStatus">
#</API>
#
#=cut
#
#
#sub appSessionRegister {
#	my ($self,$v) = @_;
#
##	'appSessionRegister'=>[ \&JSONAPI::appSessionRegister, { }, 'app', ],
##	'appSessionStatus'=>[ \&JSONAPI::appSessionStatus, { }, 'app', ],
#
#
#	}
#


=pod

<SECTION>
<h1>MashUps</h1>
MashUps are used to send/receive data with "external systems" via a variety of protocols including:
SQS, SQL, HTTP, HTTPS, MemCache, Rredis, SMTP, FTP, or SFTP.

MashUps require platform/ action files to do anything, and the specific action must be specified in the api call.
The action file is a json configuration file included with the application that specifies which data to send, 
and what to do with the response.  

Because the contents of platform/actions files are controlled by the developer they are an easy and useful way
to communicate with 3rd party "trusted" systems and provide escalated permissions.

There are many mashup code patterns, and designs can contain a lot, or a little security - as dictated by the 
business requirements and role of the response.   

Examples: 
1. A simple mashup which uses no authentication might be an HTTP call to an external node.js hosted application that
displays the "deal of the day" and optionally includes a coupon/or special code to discount that item.

2. A more complicated example might be interact with a 3rd party customer login/authentication system, where 
bidirectional information is passed back and forth creating a secure three way handshake between the app, the platform,
and the authentication system.

Mashup services can be hosted anywhere in the cloud. Examples might include Google AppEngine, Amazon EC2, or 
Heroku are all frequently used. 

Action files may specify call limits on a per session basis (ex: only one deal per session per hour), and call limits 
(and of course session limits) will be enforced by the platform -- thereby eliminating the opportunity for abusive 
behavior and reducing the planning complexity of deploying the mashup.

Mashup authentication can be none (public), private (obscured uri), secured via secret password/key/token, 
or with some protocols use PKI client certificates for the highest level of security.

Some Mashup protocols are one way (ex: SMTP), some have high latency (ex: FTP) and use notifications/messaging when
data is available, and finally some are bi-directional. 
Payload input and output are identical across protocols.
However Request/Response formatting is designed to be familiar across protocols, but obviously intended to utilize the
specifics.


appMashUpRedis
platform=appMashUpRedis-XXX.json

_cartid=xyz
%vars: [
  	key1:value1, 
	key2:value2
	]

@redis : [
	[ command1, param1, param1b, param1c, .. ]
	[ command2, param2, param2b, param2c, .. ]
	]



</SECTION>

<API id="appMashUpSQS">
<concept>mashup</concept>
<purpose></purpose>
<notes></notes>
</API>

<API id="appMashUpSQL">
<concept>mashup</concept>
<purpose></purpose>
<notes></notes>
</API>

<API id="appMashUpHTTP">
<concept>mashup</concept>
<purpose></purpose>
<notes></notes>
</API>

<API id="appMashUpHTTPS">
<concept>mashup</concept>
<purpose></purpose>
<notes></notes>
</API>

<API id="appMashUpMemCache">
<concept>mashup</concept>
<purpose></purpose>
<notes></notes>
</API>

<API id="appMashUpRedis">
<concept>mashup</concept>
<purpose></purpose>
<notes></notes>
</API>

<API id="appMashUpSMTP">
<concept>mashup</concept>
<purpose></purpose>
<notes></notes>
<input id="permission">.mashups/smtp-sample.json</input>
<input id="sender" optional="1"></input>
<input id="recipient" optional="1"></input>
<input id="subject" optional="1"></input>
<input id="body"></input>
<example id=".mashups/smtp-sample.json">
{
	"call":"appMashUpSMTP",			/* required */
	"call-limit-daily":"10",		/* recommended: max of 10 calls per day */
	"call-limit-hourly":"2",		/* recommended: max of 2 calls per hour */
	"min-version":201338,			/* recommended: minimum api version */
	"max-version":201346,			/* recommended: maximum api version */
	"@whitelist":[
		/* the line below will force the sender to you@domain.com */
		{ "id":"sender",    "verb":"set", "value":"you@domain.com" },
		/* the line above will use the recipient provided in the app call */
		{ "id":"recipient", "verb":"get" },
		/* this is an optional parameter, provided by the app, defaulting to "unknown" */
		{ "id":"eyecolor",  "verb":"get", "default":"unknown" },
		/* the default behavior is "verb":"get" .. so this is basically whitelisting subject */
		{ "id":"subject"    },
		/* the body message, which will substitute %eyecolor% */
		{ "id":"body", 	  "verb":"sub", "value":"Your eye color is: %eyecolor%" }
		]
}
</example>
</API>

<API id="appMashUpFTP">
<concept>mashup</concept>
<purpose></purpose>
<notes></notes>
</API>

<API id="appMashUpSFTP">
<concept>mashup</concept>
<purpose></purpose>
<notes></notes>
</API>

<API id="appInteractInternalMemCache">
<concept>mashup</concept>
<purpose></purpose>
<notes></notes>
</API>

<API id="appInteractInternalRedis">
<concept>mashup</concept>
<purpose></purpose>
<notes></notes>
</API>

=cut

sub appMashUp {
	my ($self, $v) = @_;
	##

	my $CART2 = undef;
	my %R = ();

	if ($v->{'_cartid'}) {
		my $cartid = sprintf("%s",$v->{'_cartid'});
		$CART2 = $self->cart2($cartid);
		if (not defined $CART2) {
			&JSONAPI::set_error(\%R,'apierr','91217',"cart could not be loaded");
			}
		}	

	my $VARS = $v->{'%vars'};

	my $PROJECTDIR = $self->projectdir($self->projectid());
	my $FILEREF = undef;

	my $platform = $v->{'platform'};
	if ($platform eq '') {
		&JSONAPI::set_error(\%R,'apierr',91218,"platform file must be referenced (was blank).");
		}
	elsif ($platform !~ /^appMashUp(HTTP|HTTPS|SQS|MemCache|Redis|SMTP|FTP|SFTP)\-(.*?)\.json$/) {
		&JSONAPI::set_error(\%R,'apierr',91219,"platform referenced must be appMashUpXXXX-ID.json");
		}
	elsif (not $self->projectid()) {
		## usually this means somebody is referencing the wrong domain (ex: vstore)
		&JSONAPI::append_msg_to_response(\%R,'iseerr',91220,"projectid is not set for host.domain (check DNS config)");
		}
	elsif (! -d $PROJECTDIR) {
		&JSONAPI::append_msg_to_response(\%R,'apierr',91222,"project directory $PROJECTDIR does not seem to exist");
		}
	## appMashUpRedis-EMAILCART.json
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'%vars')) {
		}
	elsif (-f "$PROJECTDIR/platform/$platform") {
		my $json = '';
		open F, "<$PROJECTDIR/platform/$platform";
		while (<F>) {
			next if (substr($_,0,2) eq '//');
			$json .= $_;
			} 
		close F;

		## PHASE2B: parse the file.	
		if ($json eq '') {
			&JSONAPI::append_msg_to_response(\%R,'apierr',74220,"permissions file has no json");
			}
		else {
			eval { $FILEREF  = JSON::XS::decode_json($json) };
			if ($@) {
				&JSONAPI::append_msg_to_response(\%R,'iseerr',91218,"mashup json platform file $platform decode error: $@");
				}
			}
		
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'iseerr',91218,"platform file requested [$platform] does not exist.");
		}

	my %SUB = ();
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (not defined $FILEREF) {
		&JSONAPI::append_msg_to_response(\%R,'iseerr',91218,"mashup platform file could not be decoded.");
		}
	elsif (not $FILEREF->{'version'}) {
		&JSONAPI::append_msg_to_response(\%R,'iseerr',91218,"no 'version' key found in platform json file $platform");
		}
	else {
		foreach my $line (@{$FILEREF->{'@whitelist'}}) {
			if ($line->{'verb'} eq 'get') { $SUB{ $line->{'id'} } = $v->{'%vars'}->{ $line->{'value'} }; }
			}
		}


	print STDERR 'FILEREF: '.Dumper($FILEREF,\%SUB,$v,\%R)."\n";
	if (not defined $FILEREF->{'@CART-MACROS'}) {
		}
	elsif (not defined $CART2) {
		&JSONAPI::append_msg_to_response(\%R,'iseerr',91215,"received \@CART-MACROS but don't have a valid CART2");		
		}
	else {
		foreach my $line (@{$FILEREF->{'@CART-MACROS'}}) {	
			$R{'%SUB'} = \%SUB;
			my $copy = $line;
			foreach my $k (keys %SUB) {
				my $qk = quotemeta($k);
				if ($copy =~ /$qk/) { $copy =~ s/$qk/$SUB{$k}/gs; }
				}
			my $CMDS = &CART2::parse_macro_script($copy);
			push @{$R{'@LINES'}}, $copy;
			push @{$R{'@CMDS'}},  $CMDS;
			$CART2->run_macro_cmds($CMDS);
			}
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (($v->{'_cmd'} eq 'appMashUpHTTP') || ($v->{'_cmd'} eq 'appMashHTTPS')) {
		}
	elsif ($v->{'_cmd'} eq 'appMashUpSQS') {
		}
	elsif ($v->{'_cmd'} eq 'appMashUpMemCache') {
		}
	elsif ($v->{'_cmd'} eq 'appMashUpRedis') {
		my ($redis) = &ZOOVY::getRedis($self->username(),1);
		if (ref($FILEREF->{'@redis'}) ne 'ARRAY') {
			&JSONAPI::append_msg_to_response(\%R,'apierr',91100,"\@redis is required and must be an array");
			}
		else {
			my $i = 0;
			foreach my $lineref (@{$FILEREF->{'@redis'}}) {
				foreach my $id (@{$lineref}) {
					if (defined $SUB{$id}) { $id = $SUB{$id}; }
					}
				
				my ($cmd,@params) = @{$lineref};
				$redis->$cmd(@params);
				}
			}
		}
	elsif ($v->{'_cmd'} eq 'appMashUpSMTP') {
		}
	elsif (($v->{'_cmd'} eq 'appMashUpFTP') || ($v->{'_cmd'} eq 'appMashUpSFTP')) {
		}
#	'appMashUpSQS'=>[ \&JSONAPI::appMashUp, {}, 		'mashup' ],
#	'appMashUpSQL'=>[ \&JSONAPI::appMashUp, {}, 		'mashup' ],
#	'appMashUpHTTP'=>[ \&JSONAPI::appMashUp, {}, 		'mashup' ],
#	'appMashUpHTTPS'=>[ \&JSONAPI::appMashUp, {}, 	'mashup' ],
#	'appMashUpMemCache'=>[ \&JSONAPI::appMashUp, {}, 'mashup' ],
#	'appMashUpRedis'=>[ \&JSONAPI::appMashUp, {}, 	'mashup' ],
#	'appMashUpSMTP'=>[ \&JSONAPI::appMashUp, {}, 		'mashup' ],
#	'appMashUpFTP'=>[ \&JSONAPI::appMashUp, {}, 		'mashup' ],
#	'appMashUpSFTP'=>[ \&JSONAPI::appMashUp, {}, 		'mashup' ],

	return(\%R);
	}

sub appInteractInternal {
	##
	}


##
##
##

=pod

<API id="authAdminLogout">
<purpose>destroy/invalidate an admin session.</purpose>
<notes>
Does not need any parameters, destroys the current session (if any), always returns a success.
</notes>
</API>

=cut

sub authAdminLogout {
	my ($self, $v) = @_;

	my %R = ();
	#my $DEVICEID = $self->deviceid();
	# my ($USERNAME,$LUSERNAME,$DOMAIN) = &OAUTH::resolve_userid($self->userid());
	&OAUTH::destroy_authtoken($self->username(),$self->luser(),$self->authtoken());
	&JSONAPI::append_msg_to_response(\%R,'success',0);

	return(\%R);
	}

##
##
##
sub authAdminLogin {
	my ($self, $v) = @_;

	my %R = ();
	my $ts = time();
	my $clientts = 0;

	if (length($v->{'ts'})==14) {
		## YYYYMMDDHHMMSS
		$clientts = &ZTOOLKIT::mysql_to_unixtime($v->{'ts'});
		}
	elsif ($v->{'ts'}>0) {
		$clientts = $v->{'ts'};
		}

	my $ALLOWED_DEVIATION = 86400*2;
	if (int($v->{'ts'}) == 0) {
		}
	elsif ($v->{'authtype'} eq 'google:access_token') {
		}
	elsif (($clientts < $ts-$ALLOWED_DEVIATION) || ($clientts > $ts+$ALLOWED_DEVIATION)) {
		## do not change the err id from '100' -- it's a special case that will be coded for in authAdminLogin
		my $diff = ($clientts - $ts);
		$R{'ts'} = $ts;
		my $errmsg = "Device clock must be synchronized for administrative security level. ";
		 
		if ($errmsg > 3500) {
			$errmsg = "\nVerify system time-zone is set for proper region and then reset clock.\n";
			}
		else {
			$errmsg .= "\nLocal clock drifts $diff seconds from official world-time ($ALLOWED_DEVIATION max allowed)";
			}
		&JSONAPI::set_error(\%R,'youerr',100,$errmsg);
		}

	my $USERID = $v->{'userid'} || $v->{'_userid'} || $self->userid() || $ENV{'HTTP_X_USERID'};			## obtained from user/prompt
	$USERID = lc($USERID);
	if ($USERID eq $self->username()) { $USERID = 'admin'; }

	my ($USERNAME,$LUSER,$DOMAIN) = ();	
	$USERNAME = lc($self->username());
	$LUSER = lc($self->luser());

	if ($v->{'authtype'} eq 'google:id_token') {
		}
	elsif (uc($USERID) eq 'ADMIN') {
		$LUSER = 'admin';
		}
	elsif (index($USERID,'@')>0) {
		($LUSER,my $null) = split(/\@/,$USERID);
		}
	elsif (index($USERID,'*')>0) {
		(my $null,$LUSER) = split(/\*/,$USERID);
		}
	elsif (uc($USERID) eq uc($USERNAME)) {
		$LUSER = 'admin';
		}
	elsif ($USERID) {
		$LUSER = $USERID;
		}


   if (&JSONAPI::hadError(\%R)) {
      }
	elsif ($v->{'authtype'} eq 'google:id_token') {
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'id_token')) {
			}
		}
 	elsif ($USERID eq '') {
		&JSONAPI::set_error(\%R,'apperr',55,"USERID is required (and was blank)");
		}
	elsif ($USERNAME eq '') {
		&JSONAPI::set_error(\%R,'apperr',55,"USERNAME is required (and was blank)");
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'authtype',['sha1','md5','password','challenge','facebook','google:id_token','paypal'])) {
		}
	elsif ($v->{'authid'} eq '') {
		&JSONAPI::set_error(\%R,'apperr',8801,"Missing required parameter authid=");	
		}


	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (not defined $self->clientid()) {
		&JSONAPI::set_error(\%R,'apperr',8803,"Sorry, the clientid is not valid/not set (this is highly unusual)");
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'authtype'} eq 'google:id_token') {
		## https://developers.google.com/accounts/docs/OAuth2UserAgent
		## 626088021483

		## https://developers.google.com/google-apps/sso/saml_reference_implementation
		## https://developers.google.com/+/web/signin/server-side-flow
		## https://developers.google.com/accounts/docs/OAuth2Login
		## THESE PARAMETERS ARE ONLY NEEDED FOR A REDIRECT/AUTH (we don't need them for apps)
		# $vars{'code'} = $v->{'googlesso:code'};
		# $vars{'client_id'} = '464875398878.apps.googleusercontent.com';
		# $vars{'client_secret'} = 'CLg_TBRKBvIu0o7cFwr-tfcl';
		## NOTE: both access_token and id_token work, i think id_token is better.
		## 		long term we *should* be able to validate id_token without doing a callback to google.
		##			by validating the signed JWT
		# $URL = 'https://www.googleapis.com/oauth2/v1/tokeninfo?access_token='.$api->{'access_token'};

		my $authid = $v->{'id_token'};
		my $URL = 'https://www.googleapis.com/oauth2/v1/tokeninfo?id_token='.$v->{'id_token'};

		my $ua = LWP::UserAgent->new();
		$ua->timeout(5);
		$ua->agent('CommerceRack/'.$JSONAPI::VERSION);
		my $req = new HTTP::Request('GET', $URL);
		my $result  = $ua->request($req);
		my $body = $result->content();

		#my $api = {
		#	'issued_at' => 1372366662,
		#	'audience' => '464875398878.apps.googleusercontent.com',
		#	'issuer' => 'accounts.google.com',
		#	'email_verified' => bless( do{\(my $o = 1)}, 'JSON::XS::Boolean' ),
		#	'issued_to' => '464875398878.apps.googleusercontent.com',
		# 	'email' => 'sportsworldchicago@gmail.com',
		# 	'expires_in' => 2841,
		# 	'user_id' => '111603568822579329477'
		#	};

		my $api = JSON::XS::decode_json($body);

		print STDERR Dumper($req,$api);
		if (not defined $api) {
			&JSONAPI::set_error(\%R,'apierr',156,'Invalid api response');			
			}
		elsif (not $api->{'email'}) {
			&JSONAPI::set_error(\%R,'apierr',156,'No email in Google response (using provided access/id token)');			
			}
		elsif (not $api->{'email_verified'}) {
			&JSONAPI::set_error(\%R,'youerr',156,'Google reports associated email is not verified');
			}
#		elsif ($api->{'issued_at'}+30 < $ts) {
#			&JSONAPI::set_error(\%R,'youerr',156,'The GoogleID token was issued more than 30 seconds ago and is no longer valid.');
#			}
		else {
			my ($udbh) = &DBINFO::db_user_connect($USERNAME);
			my ($MID) = &ZOOVY::resolve_mid($USERNAME);
			my $pstmt = "select LUSER from LUSERS where MID=$MID and EMAIL=".$udbh->quote($api->{'email'});
			($LUSER) = $udbh->selectrow_array($pstmt);
			&DBINFO::db_user_close();
			if ($LUSER eq '') {
				&JSONAPI::set_error(\%R,'youerr',156,sprintf('No users matching verified email "%s" found in account.',$api->{'email'}));
				}
			else {
				&JSONAPI::append_msg_to_response(\%R,'success',0);				
				}
			#$R{'email'} = $api->{'email'};
			### https://developers.google.com/+/api/latest/people
			#$R{'user_id'} = $api->{'user_id'};
			}
		}
 	elsif (($v->{'authtype'} eq 'md5') || ($v->{'authtype'} eq 'sha1')) {
		&JSONAPI::set_error(\%R,'apperr',8802,"Sorry, the authtype md5/sha1 is no longer supported (please shift+refresh to make sure you are on the latest version).");
		}
	elsif ($v->{'authtype'} eq 'password') {
		print STDERR "$USERNAME $LUSER HASH:$v->{'authtype'} $v->{'authid'}\n";

		print STDERR Dumper($v);
		#my ($ERROR) = OAUTH::verify_credentials($USERNAME,$LUSER,"$v->{'ts'}",$v->{'authtype'},$v->{'authid'});
		#if ($ERROR) {
		#	&JSONAPI::set_error(\%R,'apperr',155,$ERROR);
		#	}
		my $TRYPASS = $v->{'authid'};

		my $ERROR = undef;
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	
		my ($redis) = &ZOOVY::getRedis($USERNAME,2);
		my $FAILURES = undef;


		my $pstmt = "select PASSHASH, PASSSALT from LUSERS where MID=".$MID." and LUSER=".$udbh->quote($LUSER);
		print STDERR "$pstmt\n";
		my ($ACTUALPASSHASH,$SALT) = $udbh->selectrow_array($pstmt);
		my $TRYPASSHASH = Digest::SHA1::sha1_hex( $TRYPASS.$SALT );

		print STDERR "ACTUAL: $ACTUALPASSHASH,$SALT TRY:$TRYPASSHASH\n";

		if ($ACTUALPASSHASH ne $TRYPASSHASH) {
			$FAILURES++
			}

		if (defined $ERROR) {
			}
		elsif ($FAILURES>0) {
			## passwords don't match check redis for recovery passwords in REDIS db #2
			if ($redis->llen(uc("PASSWORD.$USERNAME.$LUSER"))>0) {
				foreach my $recovery ($redis->lrange(uc("PASSWORD.$USERNAME.$LUSER"),0,10)) {
					if ($TRYPASSHASH eq $recovery) { 
						$FAILURES = 0; 
						$R{'recovery'}++;
						}		## yay, we got a recovery
					}
				}
			}

		if ($FAILURES) {
			&JSONAPI::set_error(\%R,'apperr',155,"Incorrect password.");
			}
		&DBINFO::db_user_close();
		}
	else {
		&JSONAPI::set_error(\%R,'apperr',8802,"Sorry, the authtype '$v->{'authtype'}' is not yet implemented");
		}

	if (not &JSONAPI::hadError(\%R)) {
		my $IP = $ENV{'REMOTE_ADDR'};

		$R{'ts'} = $ts;
		my $DEVICE_NOTE = $v->{'device_note'};
		if ($DEVICE_NOTE eq '') { $DEVICE_NOTE = 'Device Name Not Specified'; }
		$R{'clientid'} = $self->clientid();
		$R{'deviceid'} = &OAUTH::device_initialize( $USERNAME, $LUSER, $IP, $DEVICE_NOTE );
		$R{'luser'} = $LUSER;
		$R{'authtoken'} = &OAUTH::create_authtoken($USERNAME,$LUSER,$self->clientid(),$R{'deviceid'});
		$R{'userid'} = sprintf("%s\@%s",$LUSER,$USERNAME);
		$R{'username'} = lc($USERNAME);
		$R{'authtype'} = $v->{'authtype'};
		}

	return(\%R);
	}




=pod 

<API id="authPasswordRecover">
<purpose>
employs the password recovery mechanism for the account (currently only email).
a temporary password is created and emailed, up to 10 times in a 3 hour period.
</purpose>
<input id="email">email</input>
</API>

<API id="adminPasswordUpdate">
<purpose>changes a users password</purpose>
<input id="old">old password</input>
<input id="new">new passowrd</input>
</API>



=cut

sub authPassword {
	my ($self, $v) = @_;

	my %R = ();

	my ($redis) = &ZOOVY::getRedis($self->username(),2);
	my $udbh = &DBINFO::db_user_connect($self->username());
	my ($USERNAME) = $self->username();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	if ($v->{'_cmd'} eq 'authPasswordRecover') {
	
		my $EMAIL = $v->{'email'};	
		if ($EMAIL eq '') {
			&JSONAPI::set_error(\%R,'apperr',8802,"no email received.");
			}

		my @USERS = ();
		if (not &JSONAPI::hadError(\%R)) {

			my $qtLOOKFOR = $udbh->quote($EMAIL);
			my $pstmt = "select LUSER,EMAIL,PASSSALT from LUSERS where EMAIL=$qtLOOKFOR and MID=$MID";
			print STDERR "$pstmt\n";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while (my ($LUSER,$EMAIL,$SALT) = $sth->fetchrow() ) {
				if ($redis->llen(uc("PASSWORD.$USERNAME.$LUSER"))>10) {
					&JSONAPI::set_error(\%R,'apperr',8804,"Too many recovery attempts, try again later");
					}
				else {
					my $PASSWORD =  String::MkPasswd::mkpasswd(-length=>16,-minnum=>10,-minlower=>2,-minupper=>2,-minspecial=>0,-distribute=>1);
					$redis->lpush(uc("PASSWORD.$USERNAME.$LUSER"),Digest::SHA1::sha1_hex($PASSWORD.$SALT));
					$redis->expire(uc("PASSWORD.$USERNAME.$LUSER"),60*60);	# 1 hour
					push @USERS, [ $LUSER, $EMAIL, $PASSWORD ];
					}
				}
			$sth->finish();
			}
		
		if (&JSONAPI::hadError(\%R)) {
			}
		elsif (scalar(@USERS)==0) {
			&JSONAPI::set_error(\%R,'apperr',8801,"no matching users found.");
			}
		else {
			foreach my $ref (@USERS) {
				my ($LUSER,$EMAIL,$PASSWORD) = @{$ref};
				next if (not &ZTOOLKIT::validate_email_strict($EMAIL));
				if (open MH, '|/usr/sbin/sendmail -t') {
					print MH "From: $EMAIL\n";
					print MH "To: $EMAIL\n";
					print MH "Subject: Password Recovery\n";
					print MH "\n";
					print MH "Hi, you or somebody who thinks they're you requested a password recovery.\n";
					print MH "Don't worry, this is the only copy of the password we sent out and you've got it.\n";
					print MH "\n";
					print MH "\n";
					print MH "Your login information is:\n";
					print MH "Login: $LUSER\n";
					print MH "*TEMPORARY* Password: $PASSWORD\n";
					print MH "\n";
					print MH 
					close MH;
					}
				}
			}
		}
	elsif ($v->{'_cmd'} eq 'adminPasswordUpdate') {
		## 
		
		my $LUSER = $udbh->quote($self->luser());
		if (&JSONAPI::validate_required_parameter(\%R,$v,'old')) {
			}
		elsif (&JSONAPI::validate_required_parameter(\%R,$v,'new')) {
			}

		my $SUCCESS = 0;
		if (not &JSONAPI::hadError(\%R)) {
			my $pstmt = "select UID,PASSHASH,PASSSALT from LUSERS where MID=$MID /* $self->{'USERNAME'} */ and LUSER=".$udbh->quote($self->luser());
			print STDERR "$pstmt\n";
			my ($UID,$PASSHASH,$PASSSALT) = $udbh->selectrow_array($pstmt);
			my $NEWSALTED = Digest::SHA1::sha1_hex($v->{'new'}.$PASSSALT);
			my $OLDSALTED = Digest::SHA1::sha1_hex($v->{'old'}.$PASSSALT);
			if ($PASSHASH eq $OLDSALTED) { $SUCCESS++; }

			if ($SUCCESS) {
				}
			elsif ($redis->llen(uc("PASSWORD.$USERNAME.$LUSER"))>0) {
				foreach my $RECOVERYSALTED ($redis->lrange(uc("PASSWORD.$USERNAME.$LUSER"),0,10)) {
					if ($NEWSALTED eq $RECOVERYSALTED) { $SUCCESS++; }
					}
				}

			if ($SUCCESS) {
				my $qtNEWSALTED = $udbh->quote($NEWSALTED);
				my $qtNEW = $udbh->quote($v->{'new'});
				my $pstmt = "update LUSERS set PASSWORD_CHANGED=now(),PASSHASH=$qtNEWSALTED,PASSWORD=$qtNEW where MID=$MID and UID=$UID /* $self->{'LUSER'} */";		
				print STDERR "$pstmt\n";
				$udbh->do($pstmt);
				}
			else {
				&JSONAPI::set_error(\%R,'apperr',8801,"previous/temporary password did not match.");
				}
			}
		}
	&DBINFO::db_user_close();
	return(\%R);
	}




#################################################################################
##
##
##

#=pod
#
#<API id="appAdminInit">
#<purpose>creates a new administrative session</purpose>
#<input id="login" optional="1">merchant*subuser</input>
#<input id="login" optional="1">username</input>
#<response id="_cartid"></response>
#<hint>An admnistrative _cartid is *REQUIRED* for appAdminAuthenticate</hint>
#</API>
#
#=cut
##
## first call of a new session 
##
#sub appAdminInit {
#	my ($self,$v) = @_;
#
#	require AUTH;
#	my ($USERNAME,$LUSER) = AUTH::parse_login($v->{'login'});
#
#	my %R = ();
#	if (not $USERNAME) {
#		&JSONAPI::set_error(\%R,'youerr',55,"USERNAME[$USERNAME] is not defined");
#		}
#	elsif (&ZOOVY::resolve_mid($USERNAME)<=0) {
#		&JSONAPI::set_error(\%R,'youerr',56,"USERNAME[$USERNAME] is not valid (could not lookup mid)");
#		}
#
#	my $token = undef;
#	if (not &JSONAPI::hadError(\%R)) {
#		($token) = AUTH::create_session($USERNAME,$LUSER,$ENV{'REMOTE_ADDR'},sprintf("%s",$v->{'_v'}));
#		$R{'_cartid'} = "*$token|USERNAME=$USERNAME|TS=".time();
#		}
#
#	return(\%R);
#	}







#=pod
#
#<API id="appAdminAuthenticate">
#<purpose>upgrades an existing session with administrative priviledges. currently the session must be created by using appAdminInit</purpose>
#<input id="_cartid" optional="1">must start with a '*') as returned by appAdminInitAdminSession</input>
#<input id="hashtype" optional="1">md5|sha1</input>
#<input id="hashpass" optional="1">hashtype(password+_cartid)</input>
#<hint>
#hashpass is generated by computing the md5 or sha1 hexadecimal value of the concatenation 
#of both the plain text password, and the _cartid. Here are some examples (all examples assume password is 'secret' and 
#the cartid is '*1234' 
#MySQL: md5(concat('secret','*1234')) = 856f3822e74dd1ba30cde256c8810204
#MySQL: sha1(concat('secret','*1234')) = bb7ee41a37b553162aff5b5c2d0bd295343fecd0
#</hint>
#</API>
#
#=cut
#
###
### second call of a new session
###
#sub appAdminAuthenticate {
#	my ($self,$v) = @_;
#
#	# use Digest::MD5;
#	# my ($tryhash) = Digest::MD5::md5_hex($PASSWORD.$token);
#	my %R = ();
#
#	require AUTH;
#	my ($USERNAME,$LUSER) = AUTH::parse_login($v->{'login'});
#	## *TOKEN|USERNAME=xyz|TS=123
#	my ($token) = split(/\|/,$v->{'_cartid'});
#
#	if ($v->{'login'} eq '') {
#		&JSONAPI::set_error(\%R,'apperr',55,"login is required (and was blank)");
#		}
#	elsif (not $USERNAME) {
#		&JSONAPI::set_error(\%R,'apperr',55,"USERNAME[$USERNAME] is not defined in login string.");
#		}
#	elsif ($v->{'hashpass'} eq '') {
#		&JSONAPI::set_error(\%R,'apperr',8801,"Missing required parameter hashpass=");				
#		}
#	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'hashtype',['sha1','md5'])) {
#		}
#	elsif (substr($token,0,1) ne '*') {
#		&JSONAPI::set_error(\%R,'apperr',8802,"Valid admin sessions will begin with a asterisk.");
#		}
#
#
#	if (not &JSONAPI::hadError(\%R)) {
#		require AUTH;
#		print STDERR "TOKEN: $token HASH:$v->{'hashtype'} $v->{'hashpass'}\n";
#		my ($ERROR) = AUTH::verify_credentials($USERNAME,$LUSER,substr($v->{'_cartid'},1),$v->{'hashtype'},$v->{'hashpass'});
#		if ($ERROR) {
#			&JSONAPI::set_error(\%R,'apperr',155,$ERROR);
#			}
#		}
#
#	if (not &JSONAPI::hadError(\%R)) {
#		my ($cartid) = &AUTH::authorize_session($USERNAME,$LUSER,substr($token,1));
#		if (not defined $cartid) {
#			&JSONAPI::set_error(\%R,'apperr',156,"Cart could not be upgraded to authorized status");
#			}
#		else {
#			$R{'_cartid'} = $cartid;
#			&JSONAPI::append_msg_to_response(\%R,'success',0);
#			}
#		}
#
#	return(\%R);
#	}
#






=pod

<API id="adminPlatformMacro">
</API>

<API id="adminPlatformHealth">
</API>

<API id="adminPlatformLogList">
</API>

<API id="adminPlatformLogDownload">
<input id="GUID"></input>
</API>


<API id="adminPlatformQueueList">
</API>

=cut 

sub adminPlatform {
	my ($self, $v) = @_;

	my %R = ();
	require ZOOVY;
	require LUSER;

	my $LU = $self->LU();
	my ($USERNAME) = $self->username();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

	if ($v->{'_cmd'} eq 'adminPlatformLogList') {
		my ($path) = &ZOOVY::resolve_userpath($USERNAME);
		my $D;
		opendir $D, $path;
		my @FILES = ();

		push @FILES, { 'TITLE'=>"Current Disk Usage", 'GUID'=>"\@DISKUSAGE" }; 
		push @FILES, { 'TITLE'=>"Current Event Queue", 'GUID'=>"\@EVENTS_QUEUE" };
		push @FILES, { 'TITLE'=>"Current Navcat Memory", 'GUID'=>"\@NAVCAT_MEMORY" };
		# push @FILES, { 'TITLE'=>"Current Event Queue", 'GUID'=>"\@EVENT_QUEUE" };
		# push @FILES, { 'TITLE'=>"Current Inventory Event Queue", 'GUID'=>"\@INVENTORY_EVENT_QUEUE" };

		while ( my $file = readdir($D) ) {
			next if (substr($file,0,1) eq '.');
			if ($file =~ /^(.*?[\d]+)\.log$/) {
				push @FILES, { 'TITLE'=>$1, 'GUID'=>$file };
				}
			elsif ($file =~ /^(.*?)(\.log\.gz)$/) {
				push @FILES, { 'TITLE'=>"$1 (compressed)", 'GUID'=>$file };
				}			
			}
		closedir $D;
		$R{'@LOGS'} = \@FILES;
		}
	elsif ($v->{'_cmd'} eq 'adminPlatformLogDownload') {
		my $FILENAME = $v->{'GUID'};
		# $FILE =~ s/[^access\-[\d]//g;

		my ($path) = &ZOOVY::resolve_userpath($USERNAME);
		my $buffer = undef;
		if (substr($FILENAME,0,1) eq '@') {
			if ($FILENAME eq '@DISKUSAGE') {
				system("/usr/bin/du -kh $path > /tmp/$USERNAME.du.log");
				my $OUTPUT = '';
				open F, "</tmp/$USERNAME.du.log";
				my $len = length($path);
				my $total = 0;
				while (<F>) {
					my ($space,$path) = split(/[\t ]+/s,$_);
					$total += $space;
					$path = substr($path,$len);
					if (length($path)==1) { $path = 'TOTAL USAGE'; }
					$buffer .= "$space\t$path\n";
					}
				close F;
				}			
			elsif ($FILENAME eq '@EVENTS_QUEUE') {
				## perl -e '$USERNAME = "2bhip"; use lib "/backend/lib"; use ZOOVY; my ($redis) = &ZOOVY::getRedis("2bhip",1); use Data::Dumper; print Dumper($redis->lrange("EVENTS",0,100)); '
				my ($redis) = &ZOOVY::getRedis($USERNAME,1);
				my ($LENGTH) = $redis->llen("EVENTS");
				$buffer .= "Queue Length: $LENGTH\n";
				my $i = 0;
				foreach my $YAML ($redis->lrange("EVENTS",0,$LENGTH)) {
					my $yref = YAML::Syck::Load($YAML);
					$buffer .= sprintf("[%d]",++$i);
					if ($yref->{'_USERNAME'} ne $USERNAME) {
						$buffer .= "\t_USERNAME=".&ZOOVY::resolve_mid($USERNAME)."\n";
						}
					else {
						foreach my $k (keys %{$yref}) {
							$buffer .= sprintf("\t%s=%s",$k,$yref->{$k});
							}
						$buffer .= "\n";
						}
					}
				}
			elsif ($FILENAME eq '@NAVCAT_MEMORY') {
				my ($udbh) = &DBINFO::db_user_connect($USERNAME);
				my $pstmt = "select count(*) from NAVCAT_MEMORY where MID=$MID /* $USERNAME */";
				my ($count) = $udbh->selectrow_array($pstmt);
				$buffer = "TOTAL: $count\n";
				$pstmt = "select PRT,CREATED_GMT,PID,SAFENAME from INVENTORY_UPDATES where MID=$MID order by ID desc";
				my $sth = $udbh->prepare($pstmt);
				$sth->execute();
				my @ROWS = ();
				$buffer .= "PRT,CREATED_GMT,PID,SAFENAME\n";
				while ( my $row = $sth->fetchrow_arrayref() ) {
					$row->[1] = &ZTOOLKIT::pretty_date($row->[1]);
					$buffer .= join("\t",@ROWS)."\n";
					}
				$sth->finish();
				&DBINFO::db_user_close();
				}
			#elsif ($FILENAME eq '@INVENTORY_EVENT_QUEUE') {
			#	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
			#	my $pstmt = "select count(*) from INVENTORY_UPDATES where MID=$MID /* $USERNAME */";
			#	my ($count) = $udbh->selectrow_array($pstmt);
			#	$buffer = "TOTAL: $count\n";
			#	$pstmt = "select LUSER,TIMESTAMP,TYPE,SKU,QUANTITY,APPID,ORDERID from INVENTORY_UPDATES where MID=$MID order by ID desc limit 0,200";
			#	my $sth = $udbh->prepare($pstmt);
			#	$sth->execute();
			#	my @ROWS = ();
			#	while ( my $hashref = $sth->fetchrow_hashref() ) {
			#		$buffer .= join(",",@ROWS)."\n";
			#		}
			#	$sth->finish();
			#	&DBINFO::db_user_close();
			#	}
			if (substr($FILENAME,0,1) eq '@') { $FILENAME = substr($FILENAME,1); } # strip leading @
			$FILENAME = "$FILENAME.txt";
			}
		elsif (-f "$path/$FILENAME") {
			if ($FILENAME =~ /^[a-z].*?(\.log|\.log\.gz)$/) {
				open F, "<$path/$FILENAME"; $/ = undef; $buffer = <F>; $/ = "\n"; close F;
				if ($FILENAME =~ /\.log\.gz$/) {
					require Compress::Zlib;
					$buffer = Compress::Zlib::memGunzip($buffer);
					}
				}
			}
		else {
			$buffer = "File not found.";
			}

		$R{'FILENAME'} = $FILENAME;
		$R{'MIMETYPE'} = 'text/plain';
		$R{'body'} = $buffer;
		}
	elsif ($v->{'_cmd'} eq 'adminPlatformMacro') {
		require BATCHJOB;

		## validation phase
		my @CMDS = ();
		if (&JSONAPI::hadError(\%R)) {
			## shit happened!
			}
		elsif (not defined $v->{'@updates'}) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9002,'Could not find any @updates');
			}
		elsif (ref($v->{'@updates'}) eq 'ARRAY') {
			my $count = 0;
			foreach my $line (@{$v->{'@updates'}}) {
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					$cmdset->[1]->{'luser'} = $self->luser();
					$cmdset->[2] = $line;
					$cmdset->[3] = $count++;
					push @CMDS, $cmdset;
					}
				}
			}
	
		my @MSGS = ();
		my $FLAGS = '';
		if (not &JSONAPI::hadError(\%R)) {
			## Validation Phase
			foreach my $cmdset (@CMDS) {
				my ($VERB,$params,$line,$linecount) = @{$cmdset};

				if ($VERB eq 'CREATE-UTILITY-BATCH') {
					my ($bj) = BATCHJOB->create($USERNAME,
						PRT=>$self->prt(),
						DOMAIN=>$self->sdomain(),
						EXEC=>sprintf("UTILITY/%s",$params->{'APP'}),
						'%VARS'=>$params,
						'*LU'=>$LU,
						);
					push @MSGS, "SUCCESS|JOBTYPE: $v->{'APP'} JOBID: ".$bj->id();
					}
				elsif ($VERB eq 'RESET-ORDER-CHANGED') {
					my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	
					my $from = &ZTOOLKIT::mysql_to_unixtime($v->{'FROMYYYYMMDDHHMMSS'});
					my $till = &ZTOOLKIT::mysql_to_unixtime($v->{'TILLYYYYMMDDHHMMSS'});
					if ($from == 0) {
						&JSONAPI::set_error(\%R,'youerr','19003','FROM time evaluated to zero');
						}
					elsif ($till == 0) {
						&JSONAPI::set_error(\%R,'youerr','19004','TILL time evaluated to zero');
						}
					else {
						require ORDER::BATCH;
						my @oids = ();
						my ($set) = ORDER::BATCH::report($USERNAME,'CREATED_GMT'=>$from,'CREATEDTILL_GMT'=>$till);
						foreach my $s (@{$set}) { push @oids, $s->{'ORDERID'}; }
						my ($tb) = &DBINFO::resolve_orders_tb($USERNAME);
						my $pstmt = "update $tb set SYNCED_GMT=0 where MID=$MID and ORDERID in ".&DBINFO::makeset($udbh,\@oids);
						print STDERR $pstmt."\n";
						if (not &JSONAPI::dbh_do(\%R,$udbh,$pstmt)) {
							&JSONAPI::set_error(\%R,'youerr','19005',"SQL ERROR<pre>".join(',',@oids));
							}
						else {
							$LU->log("UTILITIES.TECHTOOLS","Reset sync on orders from[$from] to[$till]","WARN");
							&JSONAPI::append_msg_to_response(\%R,'success',0,"Reset sync on orders from[$from] to[$till]");
							}
						}
					&DBINFO::db_user_close();
					}
				
				}
			}
		}

	return(\%R);
	}




=pod

<API id="adminDataQuery">
<purpose>accesses local management database for a variety of fields/reports</purpose>
<input id="query">
	listing-active,listing-active-fixed,listing-active-store,listing-active-auction,listing-all,listing-allwattempts,
	event-warnings,event-success,event-pending,event-target-powr.auction,event-target-ebay.auction,event-target-ebay.fixed
</input>
<input id="since_gmt">epoch timestamp - returns all data since that time</input>
<input id="batchid">batchid (only valid with event- requests)</input>
<output id="@HEADER"></output>
<output id="@ROWS"></output>
<acl want="EBAY">
</acl>
</API>

=cut 

sub adminDataQuery {
	my ($self, $v) = @_;

	my %R = ();
	my @HEADERS = ();
	my @ROWS = ();

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $PRT = $self->prt();
	my $MID = $self->mid();
	my $USERNAME = $self->username();
	my $PERIOD_GMT = int($v->{'since_gmt'});

	if (not $self->checkACL(\%R,'LISTING','L')) {
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'query')) {
		}
	elsif ($v->{'query'} =~ /^listing\-(active|active-fixed|active-store|active-auction|all|allwattempts)$/) {

		push @HEADERS, "EBAY_ID";
		push @HEADERS, "PRODUCT";
		push @HEADERS, "TYPE";
		push @HEADERS, "TITLE";
		push @HEADERS, "ENDS";
		push @HEADERS, "PROFILE";
		push @HEADERS, "IS_GTC";
		push @HEADERS, "CLASS";
		push @HEADERS, 'ITEMS_REMAIN';

		my $pstmt = "select EBAY_ID,PRODUCT,TITLE,ENDS_GMT,IS_GTC,PROFILE,CLASS,ITEMS_REMAIN from EBAY_LISTINGS where MID=$MID /* $USERNAME */ and PRT=$PRT ";
		if ($v->{'query'} eq 'listing-active') {
			$pstmt .= " and IS_ENDED=0 and EBAY_ID>0";
			}
		elsif ($v->{'query'} eq 'listing-active-fixed') {
			$pstmt .= " and CLASS='FIXED' and IS_ENDED=0 and EBAY_ID>0";
			}
		elsif ($v->{'query'} eq 'listing-active-store') {
			$pstmt .= " and CLASS='STORE' and IS_ENDED=0 and EBAY_ID>0";
			}
		elsif ($v->{'query'} eq 'listing-active-auction') {
			$pstmt .= " and CLASS='AUCTION' and IS_ENDED=0 and EBAY_ID>0";
			}
		elsif ($v->{'query'} eq 'listing-all') {
			$pstmt .= " and EBAY_ID>0";
			}
		elsif ($v->{'query'} eq 'listing-allwattempts') {
			# $pstmt .= "";
			}

		print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $ref = $sth->fetchrow_hashref() ) {
			my @row = ();
			if ($ref->{'IS_GTC'}) {
				$ref->{'ENDS'} = 'GTC';
				}
			else {
				$ref->{'ENDS'} = &ZTOOLKIT::pretty_date($ref->{'ENDS_GMT'},2);
				}
			
			foreach my $h (@HEADERS) {
				push @row, $ref->{$h};
				}
			push @ROWS, \@row;
			}
		}
	elsif ($v->{'query'} =~ /^event\-(error|success|pending|target-)/) {
		push @HEADERS, "ID";
		push @HEADERS, "PRODUCT";
		push @HEADERS, "VERB";
		push @HEADERS, "SKU";
		push @HEADERS, "QTY";
		push @HEADERS, "CREATED";
		push @HEADERS, "TARGET";
		push @HEADERS, "TARGET_LISTINGID";
		push @HEADERS, "REQUEST_APP";
		push @HEADERS, "REQUEST_BATCHID";
		push @HEADERS, "RESULT";
		push @HEADERS, "RESULT_ERR_SRC";
		push @HEADERS, "RESULT_ERR_CODE";
		push @HEADERS, "RESULT_ERR_MSG";
		push @HEADERS, "LUSER";

		my $pstmt = "select ID,VERB,REQUEST_APP,REQUEST_BATCHID,PRODUCT,SKU,QTY,from_unixtime(CREATED_GMT) CREATED,TARGET,TARGET_LISTINGID,RESULT,RESULT_ERR_SRC,RESULT_ERR_CODE,RESULT_ERR_MSG,LUSER from LISTING_EVENTS ";
		$pstmt .= " where MID=$MID /* $USERNAME */ ";
		if ($v->{'query'} eq 'event-error') {
			$pstmt .= " and RESULT in ('FAIL-SOFT','FAIL-FATAL') ";
			}
		elsif ($v->{'query'} eq 'event-warnings') {
			$pstmt .= " and RESULT in ('SUCCESS-WARNING') ";
			}
		elsif ($v->{'query'} eq 'event-success') {
			$pstmt .= " and RESULT in ('SUCCESS','SUCCESS-WARNING') ";
			}
		elsif ($v->{'query'} eq 'event-pending') {
			$pstmt .= " and RESULT in ('PENDING','RUNNING') ";
			}
		elsif ($v->{'query'} eq 'event-target-ebay.auction') {
			$pstmt .= " and TARGET='EBAY.AUCTION' ";
			}
		elsif ($v->{'query'} eq 'event-target-ebay.fixed') {
			$pstmt .= " and TARGET='EBAY.FIXED' ";
			}

		if ($v->{'batchid'} ne '') {
			$pstmt .= " and REQUEST_BATCHID=".int($v->{'batchid'});
			}
		if ($PERIOD_GMT>0) { 
			$pstmt .= " and CREATED_GMT>".int($PERIOD_GMT); 
			}

		$pstmt .= " order by ID";

		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $ref = $sth->fetchrow_hashref() ) {
			my @row = ();
			foreach my $h (@HEADERS) {
				push @row, $ref->{$h};
				}
			push @ROWS, \@row;
			}
		}

	&DBINFO::db_user_close();

	$R{'@ROWS'} = \@ROWS;
	$R{'@HEADER'} = \@HEADERS;
		

#		print "Content-Type: text/csv\n\n";
#
#		my $status  = $csv->combine(@HEADERS);  # combine columns into a string
#		my $line    = $csv->string();           # get the combined string
#		print "$line\n";
#
#		foreach my $row (@rows) {
#			$status  = $csv->combine(@{$row});  # combine columns into a string
#			$line    = $csv->string();           # get the combined string
#			print "$line\n";
#			}
#		}

	return(\%R);
	}




=pod 

<API id="adminOrderSearch">
<purpose>returns a list of orders based on the results of an elastic search</purpose>
<input id="ELASTIC">elastic search parameters</input>
<input id="DETAIL" optional="1">1,3,5</input>
<input id="DEBUG"></input>
</API>


<API id="adminOrderList">
<purpose>returns a list of orders based on one or more filter criteria</purpose>
<input id="_admin" required="1">admin session id</input>
<input id="TS" optional="1">modified since timestamp</input>
<input id="EREFID" optional="1">string (external reference id)</input>
<input id="CUSTOMER" optional="1">#CID</input>
<input id="DETAIL" optional="1">1,3,5</input>
<input id="POOL" optional="1">RECENT,PENDING,PROCESSING</input>
<input id="PRT" optional="1">0</input>
<input id="BILL_FULLNAME" optional="1">string</input>
<input id="BILL_EMAIL" optional="1">string</input>
<input id="BILL_PHONE" optional="1">string</input>
<input id="SHIP_FULLNAME" optional="1">string</input>
<input id="CREATED_GMT" optional="1">#epoch</input>
<input id="CREATEDTILL_GMT" optional="1">#epoch</input>
<input id="PAID_GMT" optional="1">#epoch</input>
<input id="PAIDTILL_GMT" optional="1">#epoch</input>
<input id="PAYMENT_STATUS" optional="1">001</input>
<input id="SHIPPED_GMT" optional="1">1/0</input>
<input id="NEEDS_SYNC" optional="1">1/0</input>
<input id="MKT" optional="1">EBY,AMZ</input>
<input id="LIMIT" optional="1">#int (records returned)</input>
<caution>
maximum number of records returned is 1,000
</caution>
<response id="@orders">an array of orders containing varied amounts of data based on the detail level requested</response>
<example title="response with DETAIL:1">
<![CDATA[
@orders:[
	[ 'ORDERID':'2012-01-1234', 'MODIFIED_GMT':123456 ],
	[ 'ORDERID':'2012-01-1235', 'MODIFIED_GMT':123457 ],
	[ 'ORDERID':'2012-01-1236', 'MODIFIED_GMT':123458 ]
	]
]]></example>
<note>
Detail level 3 includes POOL, CREATED_GMT
Detail level 5 includes CUSTOMER ID, ORDER_BILL_NAME, ORDER_BILL_EMAIL, ORDER_BILL_ZONE, ORDER_PAYMENT_STATUS, ORDER_PAYMENT_METHOD, ORDER_TOTAL, ORDER_SPECIAL, MKT, MKT_BITSTR
</note>
</API>

=cut

sub adminOrderList {
	my ($self,$v) = @_;

	my %R = ();	

	require ORDER::BATCH;
	my $res = [];

	if (not $self->checkACL(\%R,'ORDER','L')) {
		## this will set it's own error
		}
	elsif ($v->{'_cmd'} eq 'adminOrderItemList') {

		my ($INV2) = INVENTORY2->new($self->username());
		if ($v->{'backorder'}) {
			($R{'@INVDETAIL'},$R{'rowcount'}) = $INV2->pagedetail('+'=>'ALL','BASETYPE'=>'BACKORDER',limit=>($v->{'limit'}||50),page=>($v->{'page'}||0));
			}
		elsif ($v->{'preorder'}) {
			($R{'@INVDETAIL'},$R{'rowcount'}) = $INV2->pagedetail('+'=>'ALL','BASETYPE'=>'PREORDER',limit=>($v->{'limit'}||50),page=>($v->{'page'}||0));
			}
		elsif ($v->{'pick_noroute'}) {
			($R{'@INVDETAIL'},$R{'rowcount'}) = $INV2->pagedetail('+'=>'ALL','BASETYPE'=>'PICK','WHERE'=>[ 'PICK_ROUTE', 'EQ', 'TBD' ] ,limit=>($v->{'limit'}||50),page=>($v->{'page'}||0));
			}
		elsif ($v->{'pick_unshipped'}) {
			($R{'@INVDETAIL'},$R{'rowcount'}) = $INV2->pagedetail('+'=>'ALL','BASETYPE'=>'PICK',
				'@WHERE'=>
					[
					[ 'PICK_DONE_TS', 'EQ', 0 ],
					[ 'PICK_ROUTE', 'IN', [ 'WMS','SUPPLIER','PARTNER' ] ]
					]
				,  limit=>($v->{'limit'}||50),page=>($v->{'page'}||0));
			}
		}
	elsif ($v->{'_cmd'} eq 'adminOrderSearch') {
		my ($es) = &ZOOVY::getElasticSearch($self->username());
		if (not defined $es) {
			&JSONAPI::append_msg_to_response(\%R,"iseerr",201,"elasticsearch object is not available");			
			}
		elsif (not $self->checkACL(\%R,'ORDER','S')) {
			## this will set it's own error
			}

		if (not &hadError(\%R)) {
			## try
			my %params = %{$v->{'ELASTIC'}};

			## these became nested one level deeper in es v1.0
			if (defined $params{'query'}) { $params{'body'}->{'query'} = $params{'query'}; delete $params{'query'}; }
			if (defined $params{'filter'}) { $params{'body'}->{'filter'} = $params{'filter'}; delete $params{'filter'}; }
			$params{'index'} = sprintf("%s.private",$self->username());

			eval { %R = %{$es->search(%params)} };
			# open F, ">/tmp/foo";	print F Dumper(\%params,\%R);	close F;

			if (scalar(keys %R)==0) {
				&JSONAPI::append_msg_to_response(\%R,"iseerr",18201,"no keys returned from elastic");
				}
		 	elsif (not $@) {
				## yay, success!
				$R{'_count'} = scalar(@{$R{'hits'}->{'hits'}});
				#if ($R{'_count'}>0) {
				#	foreach my $hit (@{$R{'hits'}->{'hits'}}) {
				#		#$hit = $hit->{'_source'};
				#		#delete $hit->{'description'};
				#		#delete $hit->{'marketplaces'};
				#		#delete $hit->{'skus'};
				#		# $hit->{'prod_name'} = 'test';
				#		}
				#	}
				}
			elsif (ref($@) eq 'ElasticSearch::Error::Request') {
				my ($e) = $@;
				my $txt = $e->{'-text'};
				$txt =~ s/\[inet\[.*?\]\]//gs;	## remove: [inet[/192.168.2.35:9300]]
				&JSONAPI::append_msg_to_response(\%R,"apperr",18200,"search mode:$v->{'mode'} failed: ".$e->{'-text'});
			   }
			elsif (ref($@) eq 'ElasticSearch::Error::Missing') {
				&JSONAPI::append_msg_to_response(\%R,"iseerr",18202,sprintf("search mode:$v->{'mode'} %s",$@->{'-text'}));
				$R{'dump'} = Dumper($@);
				}
			else {
				&JSONAPI::append_msg_to_response(\%R,"iseerr",18201,"search mode:$v->{'mode'} failed with unknown error");
				$R{'dump'} = Dumper($@);
				}
			}

		my @OIDS = ();
		if (not &hadError(\%R)) {
			foreach my $record (@{$R{'hits'}->{'hits'}}) {
				push @OIDS, $record->{'_source'}->{'orderid'};
				}
			}
		elsif (not $v->{'DEBUG'}) {
			%R = ();
			}
	
		if (scalar(@OIDS)>0) {
			($res) = &ORDER::BATCH::report($self->username(), 'DETAIL'=>$v->{'DETAIL'}, '@OIDS'=>\@OIDS );		
			}
		}
	elsif ($v->{'_cmd'} eq 'adminOrderList') {
		($res) = &ORDER::BATCH::report($self->username(), %{$v});	
		}
	else {
		&JSONAPI::validate_unknown_cmd(\%R,$v);
		}

	$R{'@orders'} = [];
	foreach my $ref (@{$res}) {
		push @{$R{'@orders'}}, $ref;
		}

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);
		}

	return(\%R);
	}



=pod

<API id="adminOrderDetail">
<purpose>provides a full dump of data inside an order</purpose>
<input id="_cartid" required="1">admin session id</input>
<input id="orderid" required="1">Order ID</input>
<response id="order">a json representation of an order (exact fields depend on version/order source)</response>
</API>

=cut

 
sub adminOrderRouteList {
	my ($self, $v) = @_;
	my %R = ();	

	my ($o) = undef;
	#($o,my $err) = ORDER->new($self->username(),$v->{'orderid'},new=>0);
	my ($CART2) = CART2->new_from_oid($self->username(),$v->{'orderid'});
	$R{'orderid'} = $v->{'orderid'};		## this seemed like a good idea
	#if (defined $err) {
	#	&JSONAPI::append_msg_to_response(\%R,'apperr',9901,'error:'.$err);
	#	}
	if (not defined $CART2) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9901,'orderid is not valid/could not lookup order');
		}
	elsif (not $self->checkACL(\%R,'ORDER','R')) {
		## this will set it's own error
		}

	if (defined $CART2) {
		my $UUID = $v->{'uuid'};
		my ($item) = $CART2->stuff2()->item('uuid'=>$UUID);
		my $SKU = $item->{'sku'};
		print STDERR "SKU: $SKU\n";

		my ($LINKEDROUTES) = INVENTORY2->new($self->username())->detail('SKU'=>$SKU,'+'=>'ROUTE','@BASETYPES'=>['SIMPLE','WMS','SUPPLIER']);
		my @ROUTES = ();
		foreach my $route (@{$LINKEDROUTES}) {
			my $title = '';
			if ($route->{'BASETYPE'} eq 'SIMPLE') { 
				push @ROUTES, { 
					'cmdtxt'=>sprintf('Simple Inventory'),
					'cmd'=>sprintf("ITEM-UUID-ROUTE?SKU=$SKU&UUID=$UUID&ROUTE=SIMPLE"),
					'qty'=>$route->{'QTY'}
					};
				}
			elsif ($route->{'BASETYPE'} eq 'WMS') { 
				push @ROUTES, { 
					'cmdtxt'=>sprintf('WMS %s',$route->{'WMS_GEO'}),
					'cmd'=>sprintf("ITEM-UUID-ROUTE?SKU=$SKU&UUID=$UUID&ROUTE=WMS&WMS_GEO=%s",$route->{'WMS_GEO'}),
					'qty'=>$route->{'QTY'}
					};
				}
			elsif ($route->{'BASETYPE'} eq 'SUPPLIER') { 
				push @ROUTES, { 
					'cmdtxt'=>sprintf('SUPPLIER %s',$route->{'SUPPLIER_ID'}),
					'cmd'=>sprintf("ITEM-UUID-ROUTE?SKU=$SKU&UUID=$UUID&ROUTE=SUPPLIER&SUPPLIER_ID=%s",$route->{'SUPPLIER_ID'}),
					'qty'=>$route->{'QTY'}
					};
				}
			}
		push @ROUTES, { 'cmdtxt'=>'Backorder', 'cmd'=>"ITEM-UUID-ROUTE?UUID=$UUID&ROUTE=BACKORDER", 'qty'=>0 };
		$R{'@ROUTES'} = \@ROUTES;
		}
	
	return(\%R);
	}



=pod

<API id="adminOrderDetail">
<purpose>provides a full dump of data inside an order</purpose>
<input id="_cartid" required="1">admin session id</input>
<input id="orderid" required="1">Order ID</input>
<response id="order">a json representation of an order (exact fields depend on version/order source)</response>
</API>

=cut

 
sub adminOrderDetail {
	my ($self,$v) = @_;

	my %R = ();	

	my ($o) = undef;
	#($o,my $err) = ORDER->new($self->username(),$v->{'orderid'},new=>0);
	my ($CART2) = CART2->new_from_oid($self->username(),$v->{'orderid'});
	#if (defined $err) {
	#	&JSONAPI::append_msg_to_response(\%R,'apperr',9901,'error:'.$err);
	#	}
	if (not defined $CART2) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9901,'orderid is not valid/could not lookup order');
		}
	elsif (not $self->checkACL(\%R,'ORDER','R')) {
		## this will set it's own error
		}
	else {
		%R = %{$CART2->jsonify()};
		}

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
   return(\%R);
	}


=pod

<API id="adminOrderMacro">
<purpose>uses the embedded macro language to set order parameters, depending on access levels macros may not be available.</purpose>
<input id="orderid" required="1">order id of the order# to update</input>
<input id="@updates" required="1">macro content
</input>
<example>
<![CDATA[

@updates:[
	'cmd',
	'cmd?some=param',
	]

]]>
</example>
<hint>
<![CDATA[

**Using Order Macros (@updates)**

Order Macros provide a developer with a way to make easy, incremental, non-destructive updates to orders. 
The syntax for a macro payload uses a familiar dsn format cmd?key=value&key=value, along with the same
uri encoding rules, and one command per line (making the files very easy to read) -- here is an example:
"SETPOOL?pool=COMPLETED" (without the quotes). A complete list of available commands is below:

* CREATE
* SETPOOL?pool=[pool]\n
* CAPTURE?amount=[amount]\n
* ADDTRACKING?carrier=[UPS|FDX]&track=[1234]\n
* EMAIL?msg=[msgname]\n
* ADDPUBLICNOTE?note=[note]\n
* ADDPRIVATENOTE?note=[note]\n
* ADDCUSTOMERNOTE?note=[note]\n
* SET?key=value	 (for setting attributes)
* SPLITORDER
* MERGEORDER?oid=src orderid
* ADDPAYMENT?tender=CREDIT&amt=0.20&UUID=&ts=&note=&CC=&CY=&CI=&amt=
* ADDPROCESSPAYMENT?VERB=&same_params_as_addpayment<br>
	NOTE: unlike 'ADDPAYMENT' the 'ADDPROCESSPAYMENT' this will add then run the specified verb.
	Verbs are: 'INIT' the payment as if it had been entered by the buyer at checkout,
	other verbs: AUTHORIZE|CAPTURE|CHARGE|VOID|REFUND
* PROCESSPAYMENT?VERB=verb&UUID=uuid&amt=<br>
	Possible verbs: AUTHORIZE|CAPTURE|CHARGE|VOID|REFUND
* SETSHIPADDR?ship/company=&ship/firstname=&ship/lastname=&ship/phone=&ship/address1=&ship/address2=&ship/city=&ship/country=&ship/email=&ship/state=&ship/province=&ship/zip=&ship/int_zip=
* SETBILLADDR?bill/company=&bill/firstname=&bill/lastname=&bill/phone=&bill/address1=&bill/address2=&bill/city=&bill/country=&bill/email=&bill/state=&bill/province=&bill/zip=&bill/int_zip=
* SETSHIPPING?shp_total=&shp_taxable=&shp_carrier=&hnd_total=&hnd_taxable=&ins_total=&ins_taxable=&spc_total=&spc_taxable=
* SETADDRS?any=attribute&anyother=attribute
* SETTAX?sum/tax_method=&sum/tax_total&sum/tax_rate_state=&sum/tax_rate_zone=&
* SETSTUFFXML?xml=encodedstuffxml
* ITEMADD?uuid=&sku=xyz&
* ITEMREMOVE?uuid=
* ITEMUPDATE?uuid=&qty=&price=&
* SAVE
* ECHO

]]>
</hint>
</API>

=cut

 
sub adminCartOrderMacro {
	my ($self,$v) = @_;

	my %R = ();	

	my $CART2 = undef;
	if ($v->{'_cmd'} eq 'adminCartMacro') {
		my $cartid = $v->{'_cartid'};
		$CART2 = $self->cart2($cartid,'create'=>1);
		if (not defined $CART2) { 
			&JSONAPI::set_error(\%R, 'apperr', 94839,sprintf("cart '%s' not initialized for adminCartMacro",$cartid));		
			}
		}
	elsif ($v->{'_cmd'} eq 'adminOrderMacro') {
		my $ORDERID = $v->{'orderid'};
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'orderid') ) {
			}
		elsif (($CART2) = CART2->new_from_oid($self->username(),$v->{'orderid'})) {
			## yay
			}
		else {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9004,'Invalid/corrupt orderid');
			}
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9001,'request _cmd is invalid for adminCartOrderMacro');
		}


	my @CMDS = ();
	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	elsif (not defined $v->{'@updates'}) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9002,'Could not find any @updates for order');
		}
	elsif (ref($v->{'@updates'}) eq 'ARRAY') {
		my $count = 0;
		foreach my $line (@{$v->{'@updates'}}) {
			my $CMDSETS = &CART2::parse_macro_script($line);
			foreach my $cmdset (@{$CMDSETS}) {
				$cmdset->[1]->{'luser'} = $self->luser();
				$cmdset->[2] = $line;		
				$cmdset->[3] = $count++;
				push @CMDS, $cmdset;
				}
			}
		my $LM = LISTING::MSGS->new();
		$CART2->run_macro_cmds(\@CMDS,'*LM'=>$LM,'*SITE'=>$self->_SITE());

#		if ($CART2->is_cart()) {
#			$CART2->cart_save();
#			}
#		else {
#			$CART2->order_save();
#			}

		if (my $iseref = $LM->had(['WARNING'])) {
			&JSONAPI::append_msg_to_response(\%R,"warning",7200,$iseref->{'+'});
			}
		elsif (my $appref = $LM->had(['ERROR'])) {
			&JSONAPI::append_msg_to_response(\%R,"apperr",7201,$appref->{'+'});
			}
		else {
			&JSONAPI::append_msg_to_response(\%R,'success',0);		
			}
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9005,'Issue with @updates formatting [we did not understand the format you sent]');
		}

   return(\%R);
	}
		


#################################################################################
##
##

=pod

<API id="adminOrderPaymentAction">
<purpose>interally runs the PAYMENTACTION orderUpdate Macro, but can be called as a separate API</purpose>
<response id="orderid"> 2011-01-1234</response>
<response id="payment"> </response>

</API>

=cut

sub adminOrderPaymentAction {
	my ($self,$v) = @_;

	my %R = ();

	my $ORDERID = $v->{'orderid'};
	my $O2 = undef;
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'orderid') ) {
		}
	elsif (($O2) = CART2->new_from_oid($self->username(),$v->{'orderid'})) {
		## yay
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9004,'Invalid/corrupt orderid');
		}

	my $LM = LISTING::MSGS->new();
	my %ref = ();
	$ref{'luser'} = $self->luser();
	$ref{'ACTION'} = uc($v->{'ACTION'});
	$ref{'amt'} = $v->{'amt'};
	$ref{'ps'} = $v->{'ps'};
	$ref{'uuid'} = $v->{'uuid'};
	$ref{'note'} = $v->{'note'};

	$O2->run_macro_cmds([ [ 'PAYMENTACTION', \%ref ] ],'*LM'=>$LM);		

	if (my $iseref = $LM->had(['WARNING'])) {
		&JSONAPI::append_msg_to_response(\%R,"warning",200,$iseref->{'+'});
		}
	elsif (my $appref = $LM->had(['ERROR'])) {
		&JSONAPI::append_msg_to_response(\%R,"apperr",201,$appref->{'+'});
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
	return(\%R);	
	}








=pod

<API id="adminImageDetail">
<purpose>returns stored details about an media library image file.</purpose>
<input id="file" example="path/to/image.jpg">filename of the image</input>
<response id="FILENAME"></response>
<response id="EXT"></response>
<response id="H"></response>
<response id="W"></response>
<response id="SIZE"></response>
<response id="TS"></response>
<response id="FID"></response>
</API>

=cut

 
sub adminImageDetail {
	my ($self,$v) = @_;

	my %R = ();	

	if (not &JSONAPI::validate_required_parameter(\%R,$v,'file') ) {
		}
	else {
		require MEDIA;
		my $result = &MEDIA::getinfo($self->username(),$v->{'file'});
		if (not defined $result) {
			&JSONAPI::set_error(\%R,'apperr',5162,sprintf("file referenced '%s' is invalid",$v->{'file'}));
			}
		else {
			%R = %{$result};
			}
		}

	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}	
	$R{'file'} = $v->{'file'};

   return(\%R);
	}


=pod

<API id="adminImageFolderList">
<purpose>returns a list of image categories and timestamps for each category</purpose>
<response id="@folders"></response>
<example>
<![CDATA[
<Folder ImageCount="5" TS="123" Name="Path1" FID="1" ParentFID="0" ParentName="|"/>
<Folder ImageCount="2" TS="456" Name="Path1b" FID="2" ParentFID="1" ParentName="|Path1"/>
<Folder ImageCount="1" TS="567" Name="Path1bI" FID="3" ParentFID="2" ParentName="|Path1|Pathb"/>
<Folder ImageCount="0" TS="789" Name="Path2" FID="4" ParentFID="0" ParentName="|"/>
]]>
</example>
</API>


=cut

 
sub adminImageFolderList {
	my ($self,$v) = @_;

	my %R = ();	

	require MEDIA;
	$R{'@folders'} = [];
	foreach my $fref (@{&MEDIA::folderlist($self->username())}) {
		push @{$R{'@folders'}}, $fref;
		}

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}

   return(\%R);
	}



=pod

<API id="adminImageList">
<purpose>returns the list of images for a given folder (if specified). </purpose>
<input id="folder">folder to view</input>
<input id="reindex">if a folder is requested, this will reindex the current folder</input>
<input id="keyword">keyword (uses case insensitive substring)</input>
<input id="orderby">NONE|TS|TS_DESC|NAME|NAME_DESC|DISKSIZE|DISKSIZE_DESC|PIXEL|PIXEL_DESC</input>
<input id="detail">NONE|FOLDER</input>
<response id="@images"></response>
<example>
<![CDATA[
<Image Name="abc" TS="1234" Format="jpg" />
<Image Name="abc2" TS="1234" Format="jpg" />
<Image Name="abc3" TS="1234" Format="jpg" />
<Image Name="abc4" TS="1234" Format="jpg" />
<Image Name="abc5" TS="1234" Format="jpg" />
]]>
</example>
</API>

=cut

 
sub adminImageList {
	my ($self,$v) = @_;

	my %R = ();	
	$R{'@images'} = [];	

	my ($USERNAME) = $self->username();

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	my %result = ();
	my $DETAIL = $v->{'detail'};

	my $pstmt = "select I.ImgName,I.Format,I.TS from IMAGES I where I.MID=$MID ";
	if ($DETAIL eq '') {}
	elsif ($DETAIL eq 'NONE') { $DETAIL = ''; }
	elsif ($DETAIL eq 'FOLDER') {
		$pstmt = "select I.ImgName,I.Format,I.TS,F.FID,F.FName from IMAGES I,IFOLDERS F where F.MID=$MID and I.MID=$MID and F.FID=I.FID ";
		}
	else {
		&JSONAPI::set_error(\%R,'apperr',74230,'invalid detail parameter (NONE|FOLDER)');
		}


	if (defined $v->{'folder'}) { 
		require MEDIA;

		if ((substr($v->{'folder'},0,1) eq '_') || ($v->{'reindex'})) {
			## _ebay/something -- force a reindex
			MEDIA::reindex($self->username(),$v->{'folder'},1);
			}

		my $FID = &MEDIA::resolve_fid($USERNAME,$v->{'folder'});
		if ($FID > 0) { 
			$pstmt .= " and I.FID=".$FID; 
			}
		else {
			&JSONAPI::set_error(\%R,'youerr',74231,'Invalid folder requested');
			}
		}

	if ($v->{'keyword'} ne '') {
		if ($v->{'keyword'} eq '') {
			&JSONAPI::set_error(\%R,'apperr',74232,'keyword parameter is required for adminImageFolderSearch cmd');
			}
		else {
			my $qtKEYWORD = $udbh->quote($v->{'keyword'});
			$pstmt .= " and I.ImgName like concat('%',$qtKEYWORD,'%') ";
			}
		}

	if (($v->{'folder'} eq '') && ($v->{'keyword'} eq '')) {
		&JSONAPI::set_error(\%R,'apperr',74233,'sorry i will not return all images, folder or keyword parameter must be specified');
		}

	if ($v->{'orderby'}) {
		# NONE|TS|TS_DESC|NAME|NAME_DESC|DISK|DISK_DESC|PIXEL|PIXEL_DESC";
		my $direction = ($v->{'orderby'} =~ /\_DESC$/)?'DESC':'ASC';
		$v->{'orderby'} =~ s/\_DESC$//gs;	# strip _DESC so we just have TS, NAME, etc.
		if ($v->{'orderby'} eq 'NONE') {
			$direction = '';
			}
		elsif ($v->{'orderby'} eq 'TS') {
			$pstmt .= " order by I.TS $direction";
			}
		elsif ($v->{'orderby'} eq 'NAME') {
			$pstmt .= " order by I.ImgName $direction";
			}
		elsif ($v->{'orderby'} eq 'DISKSIZE') {
			$pstmt .= " order by I.Size $direction";
			}
		elsif ($v->{'orderby'} eq 'PIXEL') {
			$pstmt .= " order by I.H*I.W $direction";
			}
		else {
			&JSONAPI::set_error(\%R,'apperr',74233,'invalid orderby requested');
			}
		}

	## at this point we're going to run the actual query OR we have an error
	if (not &JSONAPI::hadError(\%R)) {
		# print STDERR "$pstmt\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($i,$e,$ts,$fid,$fname) = $sth->fetchrow() ) { 
			my $filename = $i.(($e ne '')?'.'.$e:'');
			if ($DETAIL eq '') {
				push @{$R{'@images'}}, { 'Name'=>$filename, 'TS'=>$ts };
				}
			elsif ($DETAIL eq 'FOLDER') {
				push @{$R{'@images'}}, { 'FID'=>$fid, 'Folder'=>$fname, 'Name'=>$filename, 'TS'=>$ts };
				}
			}
		$sth->finish();
		}

	&DBINFO::db_user_close();

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}

   return(\%R);
	}


=pod

<API id="adminImageFolderCreate">
<purpose>creates a new folder in the media library, folder names must be in lower case.</purpose>
<input id="folder">DIR1|DIR2</input>
<response id="fid">the internal folder id#</response>
<response id="name">the name the folder was created</response>
<hint>you can call these in any order, subpaths will be created.</hint>
<example>
<![CDATA[
<Category FID="1234" Name=""/>
]]>
</example>
</API>

=cut

 
sub adminImageFolderCreate {
	my ($self,$v) = @_;

	my %R = ();	

	require MEDIA;
	my $PWD = &MEDIA::mkfolder($self->username(),$v->{'folder'});
	if ($PWD eq '') {
		# $XML = "<Category FID=\"-1\" Error=\"Could not create category $PARAMS[0]\"/>\n";
		}
	else {
		my $FID = &MEDIA::resolve_fid($self->username(),$PWD);
		$R{'fid'} = $FID;
		$R{'name'} = $PWD;
		}

	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}	

   return(\%R);
	}

=pod

<API id="adminImageFolderDelete">
<purpose>request the deletion of a category (do not implement this right now)</purpose>
<input id="folder"></input>
</API>

=cut

 
sub adminImageFolderDelete {
	my ($self,$v) = @_;

	my %R = ();	

	require MEDIA;
	require WEBAPI;
	$self->accesslog("IMAGE.FOLDERDELETE","Deleted $v->{'folder'}");
	&MEDIA::rmfolder($self->username(),$v->{'folder'});

	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}	

   return(\%R);
	}


=pod

<API id="adminImageUpload">
<purpose>uses the file upload api to link a fileguid into a media library directory.</purpose>
<input id="folder">folder</input>
<input id="filename"></input>
<input optional="1" id="base64">base64 encoded image data</input>
<input optional="1" id="fileguid">fileguid (from file upload)</input>
</API>

<API id="adminImageMagick">
<purpose>accepts an image, and performs Image::Magick functions on it.</purpose>
<input optional="1" id="base64">base64 encoded image data</input>
<input optional="1" id="fileguid">fileguid (from file upload)</input>
<input optional="1" id="@updates"><![CDATA[
a list of macros which will convert/mogrify the image
see: http://www.imagemagick.org/script/perl-magick.php#manipulate
@updates:[
	'Resize?width=100&height=100,blur=1'
	]
]]>
<output id="mime">image/png|image/gif|image/jpg</output>
<output id="base64">base64 encoded copy of the result file</output>
<output id="%properties.area">integer - 	current area resource consumed</output>
<output id="%properties.base-columns">integer - base image width (before transformations)</output>
<output id="%properties.base-filename">string - base image filename (before transformations)</output>
<output id="%properties.base-rows">integer - base image height (before transformations)</output>
<output id="%properties.class">{Direct - Pseudo} 	image class</output>
<output id="%properties.colors">integer - number of unique colors in the image</output>
<output id="%properties.columns">integer - image width</output>
<output id="%properties.copyright">string - get PerlMagick's copyright</output>
<output id="%properties.directory">string - tile names from within an image montage</output>
<output id="%properties.elapsed-time">double - elapsed time in seconds since the image was created</output>
<output id="%properties.error">double - the mean error per pixel computed with methods Compare() or Quantize()</output>
<output id="%properties.bounding-box">string - image bounding box</output>
<output id="%properties.disk">integer - current disk resource consumed</output>
<output id="%properties.filesize">integer - number of bytes of the image on disk</output>
<output id="%properties.format">string - get the descriptive image format</output>
<output id="%properties.geometry">string - image geometry</output>
<output id="%properties.height">integer - the number of rows or height of an image</output>
<output id="%properties.id">integer - ImageMagick registry id</output>
<output id="%properties.mean-error">double - the normalized mean error per pixel computed with methods Compare() or Quantize()</output>
<output id="%properties.map">integer - current memory-mapped resource consumed</output>
<output id="%properties.matte">{True - False} 	whether or not the image has a matte channel</output>
<output id="%properties.maximum-error">double - the normalized max error per pixel computed with methods Compare() or Quantize()</output>
<output id="%properties.memory">integer - current memory resource consumed</output>
<output id="%properties.mime">string - MIME of the image format</output>
<output id="%properties.montage">geometry - tile size and offset within an image montage</output>
<output id="%properties.page.x">integer - x offset of image virtual canvas</output>
<output id="%properties.page.y">integer - y offset of image virtual canvas</output>
<output id="%properties.rows">integer - the number of rows or height of an image</output>
<output id="%properties.signature">string - SHA-256 message digest associated with the image pixel stream</output>
<output id="%properties.taint">{True - False} 	True if the image has been modified</output>
<output id="%properties.total-ink-density">double - returns the total ink density for a CMYK image</output>
<output id="%properties.transparent-color">color - ame 	set the image transparent color</output>
<output id="%properties.user-time">double - user time in seconds since the image was created</output>
<output id="%properties.version">string - get PerlMagick's version</output>
<output id="%properties.width">integer - the number of columns or width of an image</output>
<output id="%properties.x-resolution">integer - x resolution of the image</output>
<output id="%properties.y-resolution">integer - y resolution of the image</output>

</API>

=cut

 
sub adminImageUploadMagick {
	my ($self,$v) = @_;

	my %R = ();	

	require MEDIA;

	my $PWD = undef;
	if ($v->{'_cmd'} eq 'adminImageMagick') {
		## folder is optional for adminImageMagick
		if ($v->{'folder'}) { $PWD = &MEDIA::from_webapi($v->{'folder'}); }
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'folder')) {
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'filename')) {
		}
	else {
		$PWD = &MEDIA::from_webapi($v->{'folder'});
		}


	my $filename = $v->{'filename'};
	my $DATA = undef;

	if (JSONAPI::hadError(\%R)) {
		}
	elsif (defined $v->{'base64'}) {
		$DATA = MIME::Base64::decode_base64($v->{'base64'});
		if ($DATA ne '') {
			## base64 decode success
			}
		elsif ($v->{'base64'} eq '') {
			&JSONAPI::set_error(\%R,'apperr',23412,'adminImageUpload base64 parameter was specified as blank');
			}
		else {
			&JSONAPI::set_error(\%R,'iseerr',23411,'adminImageUpload could not decode base64 payload');
			}
		}
	elsif (defined $v->{'fileguid'}) {
		my ($pfu) = PLUGIN::FILEUPLOAD->new($self->username());
		$DATA = $pfu->fetch_file($v->{'fileguid'});
		if ($DATA ne '') {
			## fileguid retrieve decode success
			}
		elsif ($v->{'fileguid'} eq '') {
			# 1FACD566-343A-11E2-9979-63493A9CF7B1
			&JSONAPI::set_error(\%R,'apperr',23419,'adminImageUpload fileguid parameter was specified as blank');
			}
		else {
			&JSONAPI::set_error(\%R,'iseerr',23413,sprintf('adminImageUpload not locate file from fileguid %s',$v->{'fileguid'}));
			}			
		}
	else {
		&JSONAPI::set_error(\%R,'apperr',23411,'adminImageUpload requires either fileguid or base64 parameter');
		}


	my $ext = ''; ## default
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($filename) {
		## default upload
		# see if we can get an extension from filename, otherwise assume it's a XXX (unknown)
		if (index($filename,'.')>=0) { $ext = substr($filename,rindex($filename,'.')+1); } else { $ext = 'xyz'; }
		## if we still have xyz here, we should probably use image blob detection
		## $mimetypes->type('text/plain');

		print STDERR "Assuming Filename is [$filename]\n";
		if (index($filename,'.')>=0) {
			# has file extension
			$ext = substr($filename,rindex($filename,'.')+1);
			$filename = substr($filename,0,rindex($filename,'.'));
			print STDERR "overwriting defaults with best guess [$ext] [$filename]\n";
			} 
		else {
			# no extension?? Hmm..
			}
		}

	##
	##	
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'_cmd'} eq 'adminImageMagick') {
		## 
		my $p = Image::Magick->new();
		$p->BlobToImage($DATA);

		## validation phase
		my @CMDS = ();
		if (&JSONAPI::hadError(\%R)) {
			## shit happened!
			}
		elsif (not defined $v->{'@updates'}) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9002,'Could not find any @updates');
			}
		elsif (ref($v->{'@updates'}) eq 'ARRAY') {
			my $count = 0;
			foreach my $line (@{$v->{'@updates'}}) {
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					## ** VERY IMPORTANT DIFFERENCE ** don't add luser, remove 'ts'
					delete $cmdset->[1]->{'ts'};
					delete $cmdset->[1]->{'luser'};
					$cmdset->[2] = $line;
					$cmdset->[3] = $count++;
					push @CMDS, $cmdset;
					}
				}
			}

		my @MSGS = ();
		foreach my $CMDSET (@CMDS) {
			my ($VERB, $pref) = @{$CMDSET};
			my $result = sprintf('invalid command: %s',$VERB);
			if ($VERB eq 'MinimalResize') {
				## MinimalResize?width=100&height=100&pixel=1|0
				## finds the best way to fit an image (maintaining it's aspect ratio) into a give width/height
				## uses pixel (for logo) or standard sampling to scale
				my $source_width = $p->get('width');
				my $source_height = $p->get('height');
				my ($scale_width,$scale_height) = &MEDIA::minsize($source_width,$source_height,$pref->{'width'},$pref->{'height'});
				if (($source_width == $scale_width) && ($source_height == $scale_height)) {
					## nothing to do here.
					}
				elsif ($pref->{'pixel'}) {
					## use pixel simple scaling (better for logos)
					$result = $p->Sample('width' => $scale_width,'height' => $scale_height);
					}
				else {
					$result = $p->Scale('width' => $scale_width,'height' => $scale_height);
					}
				}
			elsif ($p->can($VERB)) {
				$result = $p->$VERB(%{$pref});
				}

			if ($result eq '') { 
				push @MSGS, sprintf("SUCCESS|+[#%d] %s",$CMDSET->[3],$CMDSET->[2]);
				}
			else {
				my ($errnum) = ($result =~ m/(\d+)/);
				if ($errnum >= 400) {
					push @MSGS, sprintf("ERROR|+[#%d] %s = %s",$CMDSET->[3],$CMDSET->[2],$result);
					}
				elsif (($errnum == 325) && ($result =~ m/extraneous bytes before marker/)) {
					## Happens for a lot of images and appears to be completely non-critical
					push @MSGS, sprintf("INFO|+[#%d] %s = %s",$CMDSET->[3],$CMDSET->[2],$result);
					}
				else {
					push @MSGS, sprintf("ERROR|+[#%d] %s = %s",$CMDSET->[3],$CMDSET->[2],$result);
					}
				}
			}
		
		my %properties = ();
		foreach my $key ('area','base-columns','base-filename','base-rows','class','colors','columns','copyright','directory','elapsed-time','error','bounding-box','disk','filesize','format','geometry','height','id','mean-error','map','matte','maximum-error','memory','mime','montage','page.x','page.y','rows','signature','taint','total-ink-density','transparent-color','user-time','version','width','x-resolution','y-resolution') {
			$properties{$key} = $p->get($key);
			}


		$R{'%properties'} = \%properties;
		$R{'mime'} = $p->get('mime');
		if ($R{'mime'} =~ /image\/(.*?)$/) {
			$ext = $1; 
			}
		if ($ext eq 'jpeg') { $ext = 'jpg'; }

		if (scalar(@MSGS)>0) {
			## changes were made, images will be output.
			$R{'base64'} = MIME::Base64::encode_base64($DATA = $p->ImageToBlob());

			$R{'@MSGS'} = [];
			foreach my $msg (@MSGS) {
				my ($msgref,$status) = LISTING::MSGS::msg_to_disposition($msg);
				if (substr($msgref->{'+'},0,1) eq '+') { $msgref->{'+'} = substr($msgref->{'+'},1); }
				push @{$R{'@MSGS'}}, $msgref;
				}
			}

		}


	## 
	##
	##
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($filename && $ext) {
		# Quick sanity
		# print STDERR "storing $USERNAME - $PWD/$filename.$ext\n";
		my ($iref) = &MEDIA::store($self->username(),"$PWD/$filename.$ext",$DATA);
		if ($iref->{'err'}>0) {
			&JSONAPI::set_error(\%R,'iseerr',(23000+$iref->{'err'}),sprintf("MEDIA ERROR %s",$iref->{'errmsg'}));
			}
		}
	elsif ($v->{'_cmd'} eq 'adminImageMagick') {
		## doen't need a filename.
		}
	elsif ($ext eq '') {
		&JSONAPI::set_error(\%R,'apperr',23419,"adminImageUpload could not determine extension for file.");
		}
	else {
		# print STDERR "No data\n";
		&JSONAPI::set_error(\%R,'apperr',23420,"adminImageUpload did not receive a usable filename");
		}

	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}	

   return(\%R);
	}

=pod

<API id="adminImageDelete">
<purpose>deletes an image</purpose>
<input id="file">filename</input>
<input id="folder">folder</input>
</API>

=cut

 
sub adminImageDelete {
	my ($self,$v) = @_;

	my %R = ();	

	require MEDIA;
	my $PWD = &MEDIA::from_webapi($v->{'folder'});
	my $filename = lc($v->{'file'});		# note: must be lowercased since extension .JPG doesn't work when passed to nuke*
	&MEDIA::nuke($self->username(),"$PWD/$filename");
	$self->accesslog("IMAGE.NUKEIMG","Deleted $PWD/$filename");

	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}	
	$R{'file'} = $v->{'file'};

   return(\%R);
	}







=pod

<API id="adminSupplierList">
<purpose></purpose>
<concept>supplier</concept>
</API>


<API id="adminSupplierMacro">
<purpose></purpose>
<concept>supplier</concept>
</API>

<API id="adminSupplierCreate">
<purpose></purpose>
<concept>supplier</concept>
</API>

<API id="adminSupplierDetail">
<purpose></purpose>
<concept>supplier</concept>
<input id="VENDORID">6-8 digit supplier/vendor id</input>
</API>

<API id="adminSupplierRemove">
<purpose></purpose>
<concept>supplier</concept>
<input id="VENDORID">6-8 digit supplier/vendor id</input>
<input id="products">0|1</input>
</API>

<API id="adminSupplierOrderList">
<purpose></purpose>
<concept>supplier</concept>
<input id="VENDORID">6-8 digit supplier/vendor id</input>
<input id="FILTER" required="1">UNCONFIRMED|RECENT</input>
<input id="FILTER=UNCONFIRMED" optional="1">The last 300 non corrupt/non error orders which have no confirmed timestamp</input>
<input id="FILTER=RECENT" optional="1">The last 100 unarchived orders</input>
<input id="DETAIL" required="1">1|0 includes an optional @ORDERDETAIL in response</input>
<output id="@ORDERS">detail about the vendor/supplier orders</output>
<output id="@ORDERDETAIL"></output>
</API>

<API id="adminSupplierOrderItemList">
<purpose></purpose>
<concept>supplier</concept>
<input id="FILTER" required="1">OPEN</input>
</API>

<API id="adminSupplierProductList">
<purpose></purpose>
<concept>supplier|product</concept>
</API>



=cut

sub adminSupplier {
	my ($self,$v) = @_;
	my %R = ();

	require SUPPLIER;
	require PRODUCT::BATCH;

	my $USERNAME = $self->username();
	my $MID = $self->mid();
	my $VENDORID = undef;
	my $S = undef;
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($INV2) = undef;

	if ($v->{'_cmd'} eq 'adminSupplierList') {
		my ($supref) = SUPPLIER::list_suppliers($USERNAME);
		$R{'@SUPPLIERS'} = $supref;
		}
	elsif (($v->{'_cmd'} eq 'adminSupplierUnorderedItemList') && (not $v->{'VENDORID'})) {
		## adminSupplierUnorderedItemList doesn't REQUIRE VENDORID (but will use it it passed)
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'VENDORID')) {
		## everythign else requires a vendor ID
		}
	else {
		## okay we've got a vendor id, let's make sure it looks good.
		$VENDORID = uc($v->{'VENDORID'});
		if ($VENDORID eq '') { &JSONAPI::set_error(\%R,'apperr',4900,'Vendor ID cannot be blank'); }
		if ($VENDORID !~ /^([0-9A-Z]+)$/) { &JSONAPI::set_error(\%R,'apperr',4900,"Vendor ID is invalid."); }
		if ($VENDORID eq 'GIFTCARD') { &JSONAPI::set_error(\%R,'apperr',4900,"The Code 'GIFTCARD' is reserved."); }
		if (not &JSONAPI::hadError(\%R)) {
			($S) = SUPPLIER->new($USERNAME,$VENDORID);
			}
		}


	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'_cmd'} eq 'adminSupplierUnorderedItemList') {
		##
		## BUILD ITEMS TO BE ORDERED
		##
	 	my $MID = &ZOOVY::resolve_mid($USERNAME);
		my $qtVENDORID = undef;
		if (defined $S) { $qtVENDORID = $udbh->quote($R{'VENDORID'} = $S->id()); }

		my $pstmt = "select SKU,QTY,VENDOR_STATUS,OUR_ORDERID,CREATED_TS,VENDOR_ORDER_DBID,ID from INVENTORY_DETAIL where MID=$MID ";
		if (defined $qtVENDORID) { $pstmt .= " and VENDOR=$qtVENDORID "; }

		if (not &JSONAPI::validate_required_parameter(\%R,$v,'FILTER',['OPEN'])) {
			}
		elsif ($v->{'FILTER'} eq 'OPEN') {
			$pstmt .= " and VENDOR_STATUS in ('NEW','ADDED') ";
			$pstmt .= " order by ID ";
			}
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		my @ROWS = ();
		while ( my $hashref = $sth->fetchrow_hashref() ) {
			if ($self->apiversion()<201338) {
				$hashref->{'STATUS'} = $hashref->{'VENDOR_STATUS'}; delete $hashref->{'VENDOR_STATUS'};
				}
			push @ROWS, $hashref;
			}
		$sth->finish();	
		$R{'@ITEMS'} = \@ROWS;
		$S = undef;		## we set this so we don't error later on.
		}
	elsif ($v->{'_cmd'} eq 'adminSupplierCreate') {
		if (SUPPLIER::exists($USERNAME,$VENDORID)) { 
			&JSONAPI::set_error(\%R,'apperr',4900,"Vendor ID [$VENDORID] already exists"); 
			}
		else {
			($VENDORID,my $ERROR) = SUPPLIER::create($USERNAME,$VENDORID,'NEW'=>1,'PROFILE'=>$VENDORID);	
			if (defined $VENDORID) {	
				$self->accesslog('SUPPLIER.CREATE',"[VENDORID: $VENDORID] was created",'INFO');
				($S) = SUPPLIER->new($USERNAME,$VENDORID);
				if (not defined $S) {
					&JSONAPI::set_error(\%R,'iseerr',4900,"SUPPLIER::create returned success, but supplier could not be instantiated after create!?!?");
					}	
				}
			else {
				&JSONAPI::set_error(\%R,'iseerr',4900,$ERROR);
				}
			}
		}
	elsif ($v->{'_cmd'} eq 'adminSupplierRemove') {
		if (not SUPPLIER::exists($USERNAME,$VENDORID)) { 
			&JSONAPI::set_error(\%R,'apperr',4900,"Vendor ID [$VENDORID] does not exist."); 
			}
		else {
			&SUPPLIER::nuke($USERNAME,$VENDORID,products=>$v->{'products'});
			&JSONAPI::append_msg_to_response(\%R,'success',0);				
			}
		}
	elsif ($VENDORID ne '') {
		($S) = SUPPLIER->new($USERNAME,$VENDORID); 
		if (not defined $S) {
			&JSONAPI::set_error(\%R,'apperr',4900,"Vendor ID [$VENDORID] not found"); 
			}
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (not defined $S) {
		## SANITY: this is *OKAY* -- if we did a remove, or list or something, we don't need a supplier.
		}
	elsif ($v->{'_cmd'} eq 'adminSupplierDetail') {
		$S->for_json(\%R);
		}
	elsif ($v->{'_cmd'} eq 'adminSupplierRemove') {
		## already handled!
		}
	elsif ($v->{'_cmd'} eq 'adminSupplierInventoryList') {
		$R{'@ROWS'} = INVENTORY2->new($USERNAME)->detail( 'WHERE'=>[ 'SUPPLIER_ID', 'EQ', $VENDORID ]);
		#my ($sup_to_prodref,$prod_to_supref) = $S->fetch_supplier_products();
		#my @skus = (sort keys %{$prod_to_supref});
		}
	elsif (($v->{'_cmd'} eq 'adminSupplierCreate') || ($v->{'_cmd'} eq 'adminSupplierMacro')) {
		## NOTE: adminSupplierCreate ALSO supports @updates
		## validation checks
		#if (not &WHOLESALE::validate_formula($v->{'MARKUP'})) { &JSONAPI::set_error(\%R,'apperr',4900,Markup formula does not appear to be valid."; }
		#	if ($v->{'FORMAT'} eq '') {	&JSONAPI::set_error(\%R,'apperr',4900,Supplier Order Format does not appear to be set";}
		#	if ($v->{'MODE'} eq '') { &JSONAPI::set_error(\%R,'apperr',4900,Supplier Data Integration Type does not appear to be set"; }
		#	if (uc($v->{'MODE'}) eq 'API' && $FLAGS !~ /,API/) { &JSONAPI::set_error(\%R,'apperr',4900,API bundle needs to be added to your account."; }

		if ($v->{'_cmd'} eq 'adminSupplierMacro') {
			if (not defined $v->{'@updates'}) {
				&JSONAPI::set_error(\%R,'apperr',4916,"adminSupplierMacro requires \@updates with macro commands (not defined)");
				}
			elsif (scalar(@{$v->{'@updates'}})==0) {
				&JSONAPI::set_error(\%R,'apperr',4915,"adminSupplierMacro requires \@updates with macro commands (field exists, but empty)");
				}
			}
		elsif ($v->{'_cmd'} eq 'adminSupplierCreate') {
			## since adminSupplierCreate doesn't require @updates, we'll initialize it if not set.
			if (not defined $v->{'@updates'}) { $v->{'@updates'} = []; }
			}

		my @CMDS = ();
		my $count = 0;
		if (not &JSONAPI::hadError(\%R)) {
			foreach my $line (@{$v->{'@updates'}}) {		
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					$cmdset->[1]->{'luser'} = $self->luser();
					$cmdset->[2] = $line;
					$cmdset->[3] = $count++;
					push @CMDS, $cmdset;
					}
				}
			}

		
		# print STDERR 'CMDS: '.Dumper(\@CMDS);
		foreach my $CMDSET (@CMDS) {
			my ($VERB, $pref) = @{$CMDSET};	
			if ($VERB eq 'INIT-DEFAULTS') {
				## initalize sane defaults
				if ($S->code() eq 'FBA') {
					$S->save_property('INVENTORY_CONNECTOR'=>'FBA');
					}
				}
			elsif ($VERB eq 'SET') {
				foreach my $k (keys %{$pref}) {
					next unless (uc($k) eq $k); ## only uppercase variables are allowed
					$S->save_property($k,$pref->{$k});
					$self->accesslog("SUPPLIER.INFO.CHANGE","[VENDORID: $VENDORID] $k=$pref->{$k}",'INFO');
					}
				&JSONAPI::add_macro_msg(\%R,$CMDSET,"SUCCESS|+general settings were updated");
				}
			elsif ($VERB eq 'OURSET') {
				foreach my $k ('email','company_name','phone','address1','address2','city','region','postal','countrycode','fba_marketplaceid','fba_merchantid') {
					$S->save_property(lc(".our.$k"),$pref->{$k});
					}
				&JSONAPI::add_macro_msg(\%R,$CMDSET,"SUCCESS|+company settings were updated");
				}
			elsif ($VERB eq 'ORDERSET') {
				foreach my $k (keys %{$pref}) { $S->save_property(lc(".order.$k"),$pref->{$k}); }
				$self->accesslog('SUPPLIER.ORDERING.CHANGE',"[VENDORID: $VENDORID] ordering settings were updated.",'INFO');
				&JSONAPI::add_macro_msg(\%R,$CMDSET,"SUCCESS|+order settings were updated");
				}
			elsif ($VERB eq 'SHIPSET') {
				foreach my $k (keys %{$pref}) { $S->save_property(lc(".ship.$k"),$pref->{$k}); }
				$self->accesslog('SUPPLIER.SHIPPING.CHANGE',"[VENDORID: $VENDORID] shipping settings were updated.",'INFO');
				&JSONAPI::add_macro_msg(\%R,$CMDSET,"SUCCESS|+shipping settings were updated");
				}
			elsif ($VERB eq 'INVENTORYSET') {
				foreach my $k (keys %{$pref}) { $S->save_property(lc(".inv.$k"),$pref->{$k}); }
				$self->accesslog('SUPPLIER.INVENTORY.CHANGE',"[VENDORID: $VENDORID] inventory settings were updated.",'INFO');
				&JSONAPI::add_macro_msg(\%R,$CMDSET,"SUCCESS|+inventory settings were updated");
				}
			elsif ($VERB eq 'TRACKINGSET') {
				foreach my $k (keys %{$pref}) { $S->save_property(lc(".tracking.$k"),$pref->{$k}); }
				$self->accesslog('SUPPLIER.TRACKING.CHANGE',"[VENDORID: $VENDORID] tracking settings were updated.",'INFO');
				&JSONAPI::add_macro_msg(\%R,$CMDSET,"SUCCESS|+tracking settings were updated");
				}
			else {
				&JSONAPI::add_macro_msg(\%R,$CMDSET,"ERROR|+Unknown/unhandled VERB:$VERB");
				}

			}
		## print STDERR Dumper($S);

		$S->save();

		if (not &JSONAPI::hadError(\%R)) {
			# SUCCESS|Your Supplier $VENDORID has been successfully added.";
			}
		}
	elsif ($v->{'_cmd'} eq 'adminSupplierOrderList') {
		##
		## Non-Confirmed Orders tab for all Suppliers
		##
	 	my $MID = &ZOOVY::resolve_mid($USERNAME);
		my $qtVENDORID = $udbh->quote($S->id());
		my $pstmt = '';
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'FILTER',['UNCONFIRMED','RECENT'])) {
			}
		elsif ($v->{'FILTER'} eq 'UNCONFIRMED') {
			$pstmt = "select * from VENDOR_ORDERS where MID=$MID and status not in ('CORRUPT','ERROR') ".
						" and CONF_GMT=0 order by OUR_ORDERID desc limit 300";
			}
		elsif ($v->{'FILTER'} eq 'RECENT') {
			$pstmt = "select * from VENDOR_ORDERS where MID=$MID and VENDOR=$qtVENDORID and ARCHIVED_TS=0 order by ID desc limit 0,100";
			}

		print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		my @ORDERS = ();
		my @SOIDS = ();
		while ( my $orderref = $sth->fetchrow_hashref() ) {
			push @ORDERS, $orderref;
			push @SOIDS, $orderref->{'OUR_ORDERID'};
			}
		$sth->finish();
		$R{'@ORDERS'} = \@ORDERS;

		if ($v->{'DETAIL'}) {
			my ($orefs) = ORDER::BATCH::report($USERNAME,'@OIDS'=>\@SOIDS,DETAIL=>3);
			$R{'@ORDERDETAIL'} = $orefs;
			}
		}
	elsif ($v->{'_cmd'} eq 'adminSupplierOrderItemDetail') {
		##	
		## BUILD ITEMS TO BE ORDERED	
		##
		my ($ID) = $v->{'VENDORORDERID'};
		my $pstmt = "select VOI.SKU,VOI.description,VOI.qty,VOI.cost,VOI.CREATED_TS from VENDOR_ORDERS VO,INVENTORY_DETAIL VOI ".
			 		" where VOI.VENDOR_ORDER_DBID=VO.ID and VO.ID=".$udbh->quote($ID). " and VO.mid=$MID and VOI.MID=VO.MID ".
			 		" order by VOI.CREATED_TS,VOI.SKU";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		my @ITEMS = ();
		while( my ($sku,$desc,$qty,$cost,$added) = $sth->fetchrow()) {
			push @ITEMS, { sku=>$sku, desc=>$desc, qty=>$qty, cost=>$cost, added=>$added };
			}
		$sth->finish();
		my $itemref = \@ITEMS;
		}
	elsif ($v->{'_cmd'} eq 'adminProductCreate') {
		my $SKU = $v->{'sku'};
		## get current product information
		my ($P) = PRODUCT->new($USERNAME,$SKU,'create'=>1);
	
		## if values are put in, use those otherwise you current properties
		$P->store('zoovy:prod_name', ($v->{'prod_name'} ne ''?$v->{'prod_name'}:$P->fetch('zoovy:prod_name')));
		$P->store('zoovy:base_cost', ($v->{'cost'} ne ''?$v->{'cost'}:$P->fetch('zoovy:base_cost')));

		$P->store('zoovy:ship_cost1', ($v->{'suppliership'} ne ''?$v->{'suppliership'}:$P->fetch('zoovy:ship_cost1')));
		$P->store('zoovy:base_weight', ($v->{'base_weight'} ne ''?$v->{'base_weight'}:$P->fetch('zoovy:base_weight')));
		$P->store('zoovy:prod_supplierid', ($v->{'suppliersku'} ne ''?$v->{'suppliersku'}:$P->fetch('zoovy:prod_supplierid')));
		$P->store('zoovy:prod_supplier', $VENDORID);
		$P->store('zoovy:virtual', "SUPPLIER:$VENDORID");
	
		#$P->store('zoovy:inv_enable',1);
		#if (defined $v->{'inv_unlimited'}) {
		#	$P->store('zoovy:inv_enable', 33);
		#	## INVENTORY::add_incremental($USERNAME,$SKU,'I',9999);
		#	}

		## set price based on MARKUP
		if ($P->fetch('zoovy:base_price') eq '') {
			my $formula = $S->fetch_property('MARKUP');
			my $price = '';
	
			require Math::Symbolic;
			my $tree = Math::Symbolic->parse_from_string($formula);			
			if (defined $tree) {
				$tree->implement('COST'=> sprintf("%.2f",$P->fetch('zoovy:base_cost')) );
				$tree->implement('BASE'=> sprintf("%.2f",$P->fetch('zoovy:base_price')) );
				$tree->implement('SHIP'=> sprintf("%.2f",$P->fetch('zoovy:ship_cost1')) );
				$tree->implement('MSRP'=> sprintf("%.2f",$P->fetch('zoovy:prod_msrp')) );
	
				my ($sub) = Math::Symbolic::Compiler->compile_to_sub($tree);
				$price = sprintf("%.2f",$sub->());
				}
			$P->store('zoovy:base_price', $price);
			}
			
		$P->folder("/$VENDORID");	
		$P->save();
	
		&JSONAPI::append_msg_to_response(\%R,'success',0,"edited product $SKU");
		$self->accesslog('SUPPLIER.PRODUCT.MAP',"[VENDORID: $VENDORID] product $SKU was associated",'INFO');
		}
	elsif ($v->{'_cmd'} eq 'adminSupplierAction') {

		my @CMDS = ();
		my $count = 0;
		if (not defined $v->{'@updates'}) {
			&JSONAPI::set_error(\%R,'apperr',4916,"adminSupplierAction requires \@updates with macro commands (not defined)");
			}
		elsif (scalar(@{$v->{'@updates'}})==0) {
			&JSONAPI::set_error(\%R,'apperr',4915,"adminSupplierAction requires \@updates with macro commands (field exists, but empty)");
			}
		
		if (not &JSONAPI::hadError(\%R)) {
			foreach my $line (@{$v->{'@updates'}}) {		
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					$cmdset->[1]->{'luser'} = $self->luser();
					$cmdset->[2] = $line;
					$cmdset->[3] = $count++;
					push @CMDS, $cmdset;
					}
				}
			}

		my @MSGS = ();
		foreach my $cmd (@CMDS) {
			my ($VERB, $pref) = @{$cmd};	

			if ($VERB eq 'INVENTORY:UPDATE') {
				require SUPPLIER::GENERIC;
				my ($LU) = $self->LU();
				my ($JOBID,$lm) = &SUPPLIER::GENERIC::update_inventory($S,'*LU'=>$LU);
				foreach my $msg (@{$lm->msgs()}) { push @MSGS, $msg; }
				if ($JOBID > 0) {
					push @MSGS, "SUCCESS|JOBID:$JOBID|+Created Job #$JOBID";
					}
				}
			elsif ($VERB eq 'ORDER:CONFIRM') {
				my ($OID) = $pref->{'orderid'};
				my $qtOID = $udbh->quote($OID);

				#if ($v->{'name'} eq '' || $v->{'email'} eq '') {
				#	&JSONAPI::set_error(\%R,'apperr',4900,"Both name and email are required when confirming orders from this screen.");
				#	}
				#elsif (not ZTOOLKIT::validate_email($v->{'email'})) {
				#	&JSONAPI::set_error(\%R,'apperr',4900,"Email is invalid");
				#	}
				my %vars = ();
				$vars{'MID'} = $MID;
				$vars{'OUR_ORDERID'} = $OID;
				$vars{'CONF_GMT'} = time();
				if ($v->{'email'}) { $vars{'CONF_EMAIL'} = $v->{'email'}; }		## probably not implemented in UI
				if ($v->{'name'}) { $vars{'CONF_PERSON'} = $v->{'name'}; }
				my $pstmt = &DBINFO::insert($udbh,'VENDOR_ORDERS',\%vars,'verb'=>'update','sql'=>1,'keys'=>['MID','OUR_ORDERID']);

				$pstmt = "update VENDOR_ORDERS set STATUS='CONFIRMED' where STATUS in ('PLACED') and MID=$MID /* $USERNAME */ and OUR_ORDERID=$qtOID";
				print STDERR "$pstmt\n";
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);				
				}
			elsif ($VERB eq 'ORDER:APPROVE') {
				## only orders which arae hold
				my ($OID) = $pref->{'orderid'};
				my $qtOID = $udbh->quote($OID);
				my $pstmt = "update VENDOR_ORDERS set STATUS='OPEN' where STATUS='HOLD' and MID=$MID /* $USERNAME */ and OUR_ORDERID=$qtOID";
				print STDERR $pstmt."\n";
				$self->accesslog('SUPPLIER.ORDERS.APPROVE',"[ORDER: $OID] was approved",'INFO');
               my ($rv) = &JSONAPI::dbh_do(\%R,$udbh,$pstmt);
				if ($rv==1) {
					push @MSGS, "SUCCESS|APPROVED ORDER: $OID";
					}
				else {
					&JSONAPI::set_error(\%R,'apperr',4900,"APPROVE FAILURE ON ORDER: $OID");
					}
				}
			elsif ($VERB eq 'ORDER:CLOSE') {
				## only orders which are open 
				## NOTE: this may fail because it happens automatically.
				my ($OID) = $pref->{'orderid'};
				my $qtOID = $udbh->quote($OID);
				my $pstmt = "update VENDOR_ORDERS set STATUS='CLOSED' where STATUS in ('','OPEN','HOLD') and MID=$MID /* $USERNAME */ and OUR_ORDERID=$qtOID";
				print STDERR $pstmt."\n";
				my ($rv) = &JSONAPI::dbh_do(\%R,$udbh,$pstmt);
				if ($rv==1) {
					push @MSGS, "SUCCESS|CLOSED ORDER: $OID";
					}
				else {
					push @MSGS, "ERROR|+CLOSE FAILURE ON ORDER: $OID";
					}
				}	
			elsif ($VERB eq 'ORDER:RECEIVE') {
				my ($OID) = $pref->{'orderid'};
				my $qtOID = $udbh->quote($OID);
				my $pstmt = "update ITEM_DETAIL VOI,VENDOR_ORDERS set 
					VO.RECEIVED_TS=now(),VO.STATUS='RECEIVED',VOI.STATUS='RECEIVED' 
					where VO.MID=$MID and VOI.MID=$MID and VOI.VENDOR_ORDER_DBID=VO.ID and VO.OUR_ORDERID=$qtOID";
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
				push @MSGS, "SUCCESS|RECEIVED ORDER $OID";
				}
			elsif ($VERB eq 'ORDER:ARCHIVE') {
				my ($OID) = $pref->{'orderid'};
				if ($OID eq '') {
					push @MSGS, "ERROR|+no orderid parameter passed";
					}
				else {
					my $qtOID = $udbh->quote($OID);
					my $pstmt = "update VENDOR_ORDERS set ARCHIVED_TS=now() where OUR_ORDERID=$qtOID and MID=$MID";
					&JSONAPI::dbh_do(\%R,$udbh,$pstmt);	
					push @MSGS, "SUCCESS|+Archived $OID";
					}
				}
			elsif ($VERB eq 'ORDER:REDISPATCH') {
				my ($OID) = $pref->{'orderid'};
				my $qtOID = $udbh->quote($OID);
				my $pstmt = "update VENDOR_ORDERS set DISPATCHED_TS=0,STATUS='CLOSED',LOCK_PID=0 where OUR_ORDERID=$qtOID and MID=$MID";
				my $results = &JSONAPI::dbh_do(\%R,$udbh,$pstmt);
				$self->accesslog('SUPPLIER.ORDERS.REDISPATCH',"[ORDER: $OID] was redispatched",'INFO');
				push @MSGS, "SUCCESS|Redispatched $OID";
				}
			elsif ($VERB eq 'ORDER:CONFIRM') {
				my ($OID) = $pref->{'orderid'};
				my $qtOID = $udbh->quote($OID);
				$self->accesslog('SUPPLIER.ORDERS.CONFIRM',"[ORDER: $OID] was confirmed",'INFO');
				my (@errors) = SUPPLIER::confirm_order($USERNAME,$OID,'NA','','','',$pref->{'name'},$pref->{'email'});
				foreach my $error (@errors) {
					push @MSGS, "ERROR|+$error\n";
					}
				}	
			elsif ($VERB =~ /^(PID|SKU):(LINK|UNLINK)$/) {
				my ($TARGETPIDSKU,$VERB) = ($1,$2);
				my $PIDSKU = ($TARGETPIDSKU eq 'PID')?$pref->{'PID'}:$pref->{'SKU'};

				if (not defined $INV2) { $INV2 = INVENTORY2->new($self->username(),$self->luser()); }
				## PRODUCT:LINK PID:UNLINK 
				## SKU:LINK SKU:UNLINK

				## Disassociate product from SUPPLIER
				if ((not defined $PIDSKU || $PIDSKU eq '')) {
					push @MSGS, "ERROR|+no pid or sku passed to $VERB";
					}
				elsif ($VERB eq 'LINK') {
					$INV2->supplierinvcmd($S,"SUPPLIER/INIT", QTY=>$pref->{'QTY'},'@MSGS'=>\@MSGS, $TARGETPIDSKU=>$PIDSKU);
					}
				elsif ($VERB eq 'DELINK') {
					$INV2->supplierinvcmd($S,"SUPPLIER/NUKE",'@MSGS'=>\@MSGS, $TARGETPIDSKU=>$PIDSKU);
					}
				}
			else {
				&JSONAPI::set_error(\%R,'apperr',4900,"Unknown Macro:$VERB");
				}
			}

		$R{'@MSGS'} = [];
		foreach my $msg (@MSGS) {
			my ($msgref,$status) = LISTING::MSGS::msg_to_disposition($msg);
			if (substr($msgref->{'+'},0,1) eq '+') { $msgref->{'+'} = substr($msgref->{'+'},1); }
			push @{$R{'@MSGS'}}, $msgref;
			}
		}
	else {
		## this line should never be reached!
		&JSONAPI::set_error(\%R,'apperr',4999,"Unknown verb in adminSupplierXXXXXXX");
		}

	if (defined $INV2) {
		$INV2->sync();
		}

	&DBINFO::db_user_close();
	return(\%R);
	}



=pod

<API id="adminPrivateFileDownload">
<purpose></purpose>
<concept>report</concept>
<input id="GUID"></input>
</API>

<API id="adminPrivateFileList">
<purpose></purpose>
<concept>report</concept>
<input optional="1" id="type"></input>
<input optional="1" id="guid"></input>
<input optional="1" id="active"></input>
<input optional="1" id="keyword"></input>
<input optional="1" id="limit"></input>
</API>

=cut

sub adminPrivateFile {
	my ($self,$v) = @_;
	my %R = ();

	require REPORT;
	require LUSER::FILES;

	my $USERNAME = $self->username();
	my $MID = $self->mid();
	my $VENDORID = undef;
	my $S = undef;
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	## changed in version 201330
	if ($self->apiversion() < 201330) {
		if ($v->{'_cmd'} eq 'adminPrivateDownload') { $v->{'_cmd'} = 'adminPrivateFileDownload'; }
		}

	my ($lf) = LUSER::FILES->new($USERNAME);
	if ($v->{'_cmd'} eq 'adminPrivateFileList') {
		#   {
		#	'ID' => '9012892',
		#  'USERNAME' => 'sporks',
		#  'META' => '',
		#  'CREATED_GMT' => 1371618385,
		#  'GUID' => 'FDBBD7A0-D89D-11E2-A408-517F9C787A02',
		#  '%META' => {},
		#  'CREATED' => '2013-06-18 22:06:25',
		#  'TITLE' => '/tmp/EBAY-sporks-0-5140621767-5150171447.xml',
		#  'EXPIRES' => '0000-00-00 00:00:00',
		#  'REFERENCE' => '0',
		#  'CREATEDBY' => '',
		#  'FILETYPE' => 'SYNDICATION',
		#  'FILENAME' => 'EBAY-sporks-0-5140621767-5150171447.xml',
		#  'MID' => '4175'
		#  },
		$R{'@files'} = $lf->list( %{$v} );
		}

	if ($v->{'_cmd'} eq 'adminPrivateFileList') {
		## doesn't require GUID or FILENAME
		}
	elsif ($v->{'FILENAME'} ne '') {
		$R{'FILENAME'} = $v->{'FILENAME'};
		}
	elsif ($v->{'GUID'} ne '') {
		my $GUID = $v->{'GUID'};
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'GUID')) {
			}

		my $contents = undef;
		my $privatefileref = ();

		## filter by GUID
		my $filesref = $lf->list('guid'=>$GUID);
		$privatefileref = $filesref->[0];
		$R{'FILENAME'} = $privatefileref->{'FILENAME'};
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'apperr',2398,'GUID or FILENAME are required');
		}


	
	if ($v->{'_cmd'} eq 'adminPrivateFileList') {
		## doesn't require GUID or FILENAME
		}
	elsif ($v->{'_cmd'} eq 'adminPrivateFileRemove') {
		$lf->nuke('FILE'=>$R{'FILENAME'});
		}
	elsif ($v->{'_cmd'} eq 'adminPrivateFileDownload') {

		$R{'MIMETYPE'} = 'application/unknown';
		my ($mime_type, $encoding) = MIME::Types::by_suffix($R{'FILENAME'});
		if ($mime_type eq '') {
			if ($R{'FILENAME'} =~ /\.yaml$/) { $mime_type = 'application/yaml'; }
			}
		if ($mime_type ne '') {
			$R{'MIMETYPE'} = "$mime_type";
			}

		if ($R{'FILENAME'} ne '') { 
			$R{'body'} = $lf->file_contents($R{'FILENAME'}); 

			if ((defined $v->{'base64'}) && ($v->{'base64'})) {
				$R{'body'} = MIME::Base64::encode_base64($R{'body'},'');
				}

			if ($self->apiversion() < 201324) {
				$R{'data'} = $R{'body'}; delete $R{'body'};
				}

			}
		else {
			&JSONAPI::set_error(\%R,'iseerr', 234, 'File could not be loaded.');
			}
		}
	else {
		&JSONAPI::set_error(\%R,'iseerr',4900,"Unknown _cmd:$v->{'_cmd'}");
		}

	return(\%R);
	}




=pod

<API id="adminReportDownload">
<purpose>
<![CDATA[
Inside "$R" (the REPORT object) there are following output values:
@HEAD the header object (below)
@BODY the body object (further below)

	that is all that is *required* @DASHBOARDS and @GRAPHS are discussed later.


	@HEAD is an array, of "header columns" structured as such:
		[
		'name'=>'Name of Column',
		'type'=>  	NUM=numeric,  CHR=character, ACT=VERB (e.g. button), 
						LINK=http://www.somelink.com
						ROW (causes the contents to placed in it's own row e.g. a detail summary)
					(see specialty types below)
		'pre'=>	?? pretext
		'post'=> ?? posttext
		],

 
	@BODY is an array of arrays 
		the array is re-ordered based on the current sort (and then re-saved)
		[
			[ 'abc','1','2','3' ],
			[ 'def','4','5','6' ]
		]

	@SUMMARY = [
		{ type=>'BREAK,CNT,SUM,AVG', src=>col#, sprintf=>"formatstr" },
		{ type=>'BREAK,CNT,SUM,AVG', src=>col#, sprintf=>"formatstr" },
		]

	@DASHBOARD = [
		{ 
			title=>'', subtitle=>'', groupby=>col#, 
			@HEAD=>[ 
				{ type=>'NUM|CHR|VAL|SUM|AVG|TOP|LOW|CNT', name=>'name of column', src=col# }
				{ type=>'NUM|CHR|VAL|SUM|AVG|TOP|LOW|CNT', name=>'name of column', src=col# }
				],
			@GRAPHS=>[ 'file1', 'file2', 'file3' ]
		}, 
		{ 
			title=>'', subtitle=>'', groupby=>col#, 
			@HEAD=>[ 
				{ type=>'NUM|CHR|VAL|SUM|AVG|TOP|LOW|CNT', name=>'name of column', src=col# }
				{ type=>'NUM|CHR|VAL|SUM|AVG|TOP|LOW|CNT', name=>'name of column', src=col# }
				],
			@GRAPHS=>[ 'file1', 'file2', 'file3' ]
		}, 
		]

== specialty column types: ==
	YJH - Year/JulianDay/Hour
	YJJ - Year/JulianDay
	YWK - Year/Week
 	YMN - Year/Month
	YDT - takes a gmt time and returns the pretty date
	YDU - how many days/hours/minutes/seconds the duration is

	NUM=numeric
	CHR=character
	ACT=VERB (e.g. button) "<input type=\"button\" value=\"Start Dispute\" class=\"button2\" onClick=\"customAction('OPEN','$claim');\">";
	ROW 
]]>
</purpose>
<concept>report</concept>
<input id="GUID">the globally unique id assigned to this report (probably obtained from a batch job list)</input>
</API>

=cut


sub adminReportDownload {
	my ($self,$v) = @_;
	my %R = ();

	require REPORT;
	require PRODUCT::BATCH;

	my $USERNAME = $self->username();
	my $MID = $self->mid();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	if ($v->{'_cmd'} eq 'adminReportDownload') {
		my $GUID = $v->{'GUID'};
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'GUID')) {
			}
		else {
			require REPORT;
			my $RPT = REPORT->new_from_guid($USERNAME,$GUID); 
			if (not defined $RPT) {
				&JSONAPI::set_error(\%R,'iseerr', 234, 'Report could not be loaded.');
				}
			elsif (ref($RPT) eq '') {
				&JSONAPI::set_error(\%R,'iseerr', 235, $RPT);
				}
			else {
				%R = %{$RPT->{'%META'}};
				$R{'@HEAD'} = $RPT->{'@HEAD'};
				$R{'@BODY'} = $RPT->{'@BODY'};
				&JSONAPI::append_msg_to_response(\%R,'success',0);				
				}
			}
		}
	else {
		&JSONAPI::set_error(\%R,'iseerr',4900,"Unknown _cmd:$v->{'_cmd'}");
		}

	&DBINFO::db_user_close();
	return(\%R);
	}



=pod

<API id="adminNavTreeList">
<output id="@NAVS">
a list of nav elements
[
{	"type":"navcat", "prt":"0", "nav":"PRT000", "title":"Partition 0"  },
{	"type":"navcat", "prt":"1", "nav":"PRT001", "title":"Partition 1"  },
]
</output>
</API>

=cut

sub adminNavTree {
	my ($self,$v) = @_;
	my %R = ();

	if ($v->{'_cmd'} eq 'adminNavTreeList') {
		my @NAVS = ();
		my @prts = @{&ZWEBSITE::list_partitions($self->username(),'has_navcats'=>1,'output'=>'prtonly')};
		foreach my $PRT (@prts)	{
			my %nav = ();
			$nav{'type'} = "navcat";
			$nav{'prt'} = $PRT;
			$nav{'navtree'} = sprintf("PRT%03d",$PRT);
			$nav{'title'} = "Partition #$PRT"; 
			push @NAVS, \%nav;

			#my ($NC) = NAVCAT->new($self->username(),'prt'=>$PRT);
			#$nav{'@paths'} = [];
			#foreach my $path ($NC->paths('.')) {
			#	my ($pretty) = $NC->get($path);
			#	push @{$nav{'@paths'}}, { 'path'=>$path, 'pretty'=>$pretty };
			#	}

			}
	
		$R{'@NAVS'} = \@NAVS;
		}

	return(\%R);
	}



 



 
sub adminNavcat {
	my ($self,$v) = @_;

	my %R = ();	

	require NAVCAT;
	require NAVCAT::CHOOSER;

	my ($PRT) = $self->prt();

	my $cache = $self->cache();
	if ($self->is_admin()) { 
		$cache = 0; 
		if (defined $v->{'prt'}) { $PRT = int($v->{'prt'}); }
		if (defined $v->{'navtree'}) { $PRT = int(substr($v->{'navtree'},3)); }
		}

	my $VERB = $v->{'_cmd'};
	my ($NC) = undef;
	if ($cache == 0) {
		$NC = NAVCAT->new($self->username(),'PRT'=>$PRT,cache=>$cache);
		}
	else {
		$NC = $self->cached_navcat();
		}

	my $safe = $v->{'path'};
	if (not defined $safe) { $safe = $v->{'safe'}; }		## i think the appNavcat version uses safe

	if ($self->apiversion()<201332) {
		if ($VERB eq 'categoryDetail') { $VERB = 'appNavcatDetail'; }
		if ($VERB eq 'appNavcat') { $VERB = 'appNavcatDetail'; }
		if ($VERB eq 'appCategoryDetail') { $VERB = 'appNavcatDetail'; }
		}
	elsif ($VERB eq 'appNavcat') {
		&JSONAPI::error_cmd_removed_since(\%R,201332,'use appNavcatDetail');
		}
	elsif ($VERB eq 'appCategoryDetail') {
		&JSONAPI::error_cmd_removed_since(\%R,201332,'use appNavcatDetail');
		}
	elsif ($VERB eq 'categoryDetail') {
		&JSONAPI::error_cmd_removed_since(\%R,201332,'use appNavcatDetail');
		}

=pod

<API id="appCategoryDetail">
<purpose></purpose>
<input id="safe">.safe.path</input>
<input id="detail">fast|more|max</input>
<input hint="detail:max only" id="depth">#changes pretty from "Category C" to "Category A / Category B / Category C", 0 = no breadcrumbs</input>
<input hint="detail:max only" id="delimiter">xyz the separator between category names in the breadcrumb (default " / ")</input>
<note>skips hidden categories</note>
<response id="exists">1|0</response>
<response id="pretty"></response>
<response id="sort"></response>
<response id="%meta">[ "dst":"value", "dst":"value" ]</response>
<response id="@products">[pid1,pid2,pid3]</response>
<note>detail=fast is the same as detail=more</note>
<response id="subcategoryCount"># of children</response>
<response id="@subcategories">[ '.safe.sub1', 'safe.sub2', '.safe.sub3' ];</response>
<input id="@subcategoryDetail" hint="detail:more or detail:max">
	[
	[ 'id':'.safe.sub1', 'pretty':'Sub Category 1', '@products':['pid1','pid2','pid3'] ],
	[ 'id':'.safe.sub2', 'pretty':'Sub Category 2', '@products':['pid1','pid2','pid3'] ],
	];
</input>
<errors>
	<err id="8001" type="warning">Requested Category does not exist.</err>
</errors>

</API>

<API id="adminNavcatDetail">
<purpose>returns detailed information about a navigation category or product list.</purpose>\
<input optional="1" id="prt">returns the navigation for partition</input>
<input optional="1" id="navtree">returns the navigation for navtree specified (use the navtree parameter from adminNavTreeList)</input>
<concept>navcat</concept>
<output>
path:.safe.name or path:$listname
returns:
pretty:'some pretty name',
@products:['pid1','pid2','pid3'],
%meta:['prop1':'data1','prop2':'data2']
</output>
</API>

<API id="appNavcatDetail">
<purpose>see adminNavcatDetail (identical)</purpose>
</API>

=cut
	
#	if ($VERB eq 'adminNavcatList') {
#		my $root = $v->{'safe'};
#		my $depth = int($v->{'depth'});
#		my %RESULT = ();
#		foreach my $safe (@{$NC->paths($root)}) {
#			my @branches = split(/\./,$safe);
#			my $PTR = \%RESULT;
#			foreach my $branch (@branches) {
#				next if ($branch eq '');
#				if (not defined $PTR->{ $branch }) {
#					}
#				$PTR = $PTR->{$branch};
#				}
#			}
#		}

	if (($VERB eq 'adminNavcatDetail') || ($VERB eq 'appNavcatDetail')) {
		my ($pretty,$children,$products,$sort,$meta) = $NC->get($safe);
		$R{'path'} = $safe;
		$R{'exists'} = 1;
		$R{'pretty'} = $pretty;
		$R{'@products'} = [ split(/,/,$products) ];
		$R{'%meta'} = $meta;

		if (not defined $v->{'detail'}) {
			## detail not passed. .. just return what we got.
			}
		elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'detail',['fast','more','max'])) {
			}
		elsif (not $NC->exists($safe)) {
			$R{'exists'} = 0;
			&JSONAPI::append_msg_to_response(\%R,'warning',8001,sprintf('Category %s does not exist prt[%d]',$safe,$self->prt()));
			}
		elsif ($v->{'detail'} eq 'fast') {
			## this is cool, nothing else to do.
			}
		elsif ($v->{'detail'} eq 'more') {
			my $children = $NC->fetch_childnodes($safe);
			$R{'subcategoryCount'} = scalar(@{$children});
			$R{'@subcategories'} = $children;
			}
		elsif ($v->{'detail'} eq 'max') {
			my $children = $NC->fetch_childnodes($safe);
			$R{'subcategoryCount'} = scalar(@{$children});
			foreach my $subsafe (@{$children}) {
				my ($pretty,undef,my $products,my $sort,my $metaref) = $NC->get($subsafe);
				my @products = split(/,/,$products);
				if ($self->apiversion()<201336) {
					push @{$R{'@subcategoryDetail'}}, { 'id'=>$subsafe, 'pretty'=>$pretty, '@products'=>\@products, '%meta'=>$metaref };
					}
				else {
					push @{$R{'@subcategoryDetail'}}, { 'path'=>$subsafe, 'pretty'=>$pretty, '@products'=>\@products, '%meta'=>$metaref };
					}
				}
			}
		else {
			## never reached!
			&JSONAPI::set_error(\%R,'apperr','8000',"Invalid detail xxx requested");
			}

		}

=pod

<API id="adminNavcatDelete">
<purpose>permanently removes a navigation category or list.</purpose>
<concept>navcat</concept>
<input id="path">.safe.name or path:$listname</input>
</API>

=cut

	if ($VERB eq 'adminNavcatDelete') {
		$NC->nuke($safe); 
		$safe = $NC->parentOf($safe);		# go up a level in the tree.
		}	

=pod

<API id="adminNavcatModify">
<purpose>changes the pretty name of a navigation category or list</purpose>
<concept>navcat</concept>
<input id="path">.safe.name or path:$listname</input>
<input id="pretty">new name for category</input>
<hint>
will support %meta tags in the future.
</hint>
</API>

=cut

	if ($VERB eq 'adminNavcatModify') {
		my $pretty = $v->{'pretty'};
			
		$NC->set($safe, pretty=>$pretty);
		$safe = $NC->parentOf($safe);
		}

=pod

<API id="adminNavcatCreate">
<purpose>Creates a new navigation category or product list with a given pretty name.</purpose>
<concept>navcat</concept>
<input id="pretty">new name for category</input>
<input id="root">.root.category (set to $ for list)</input>
</API>

=cut

	if ($VERB eq 'adminNavcatCreate') {
		my $pretty = $v->{'pretty'};
		my $subsafe = &NAVCAT::safename($pretty,new=>1);
		my $root = $v->{'root'};

		if ($v->{'root'} eq '$') {
			## list
			$NC->set( '$'.$subsafe, pretty=>$pretty);
			}
		elsif (substr($v->{'root'},0,1) eq '.') {
			## navcat
			$safe = $v->{'root'};
			# print STDERR "SAFE BEFORE: $safe\n";
			$safe = (($safe ne '.')?$safe.'.':'.').$subsafe;
			# print STDERR "Saving safe[$safe] pretty=[$pretty]\n";
			$NC->set( $safe, pretty=>$pretty);
			}
		}

=pod

<API id="adminNavcatProductInsert">
<purpose>adds a single product to a navigation category or list.</purpose>
<input id="path">.root.category or $list</input>
<input id="pid">pid1</input>
<input id="position"># (0=first element in the list, -1=last element in the list)</input>
</API>

=cut

	if ($VERB eq 'adminNavcatProductInsert') {
		my ($pos) = int($v->{'position'});
		$NC->set($safe,'insert_product'=>$v->{'pid'},'position'=>$pos);
		}

=pod

<API id="adminNavcatProductDelete">
<purpose>removes a single product from a navigation category or list.</purpose>
<input id="path">.root.category or $list</input>
<input id="pid">pid1</input>
</API>

=cut

	if ($VERB eq 'adminNavcatProductDelete') {
		$NC->set($safe,delete_product=>$v->{'pid'});			
		}

	if ($VERB eq 'adminNavcatMacro') {
		## validation phase
		my @CMDS = ();
		if (&JSONAPI::hadError(\%R)) {
			## shit happened!
			}
		elsif (not defined $v->{'@updates'}) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9002,'Could not find any @updates');
			}
		elsif (ref($v->{'@updates'}) eq 'ARRAY') {
			my $count = 0;
			foreach my $line (@{$v->{'@updates'}}) {
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					$cmdset->[1]->{'luser'} = $self->luser();
					$cmdset->[2] = $line;
					$cmdset->[3] = $count++;
					push @CMDS, $cmdset;
					}
				}
			}
	

		my @MSGS = ();
		if (scalar(@CMDS)==0) {
			push @MSGS, "ERROR|+No CMDS found";
			}

		## Validation Phase
		foreach my $cmdset (@CMDS) {
			next if (&JSONAPI::hadError(\%R));

			my ($VERB,$params,$line,$linecount) = @{$cmdset};
			my $path = $params->{'path'};

			if ((not defined $path) || ($path eq '')) {
				push @MSGS, sprintf("ERROR|+Invalid macro '%s'",$VERB);
				}
			elsif ($VERB eq 'DELETE') {
				$NC->nuke($path); 
				push @MSGS, "SUCCESS|+did delete $path";
				$path = $NC->parentOf($path);		# go up a level in the tree.
				# print STDERR "NEW SAFE: $path\n";
				}	
			elsif ($VERB eq 'RENAME') {
				my $pretty = $params->{'pretty'};
				$NC->set($path, pretty=>$pretty);
				push @MSGS, "SUCCESS|+did RENAME $path";
				}
			elsif ($VERB eq 'CREATE') {
				my $pretty = $params->{'pretty'};
				my $subpath = &NAVCAT::safename($pretty,new=>1);
				my $path = '';
				if ($params->{'type'} eq 'list') {
					## list
					$NC->set( '$'.$subpath, pretty=>$pretty);
					$path = "\$$path";
					}
				else {
					## navcat
					$path = $params->{'path'};
					# print STDERR "SAFE BEFORE: $path\n";
					$path = (($path ne '.')?$path.'.':'.').$subpath;
					# print STDERR "Saving path[$path] pretty=[$pretty]\n";
					$NC->set( $path, pretty=>$pretty);
					}
				push @MSGS, "SUCCESS|PATH:$path|+did CREATE $path";
				}
			else {
				push @MSGS, sprintf("ERROR|+Invalid macro '%s'",$VERB);
				}

			if (defined $path) {
				push @{$R{'@PATHS_MODIFIED'}}, $path;
				}
			}

		$R{'@MSGS'} = [];
		foreach my $msg (@MSGS) {
			my ($msgref,$status) = LISTING::MSGS::msg_to_disposition($msg);
			if (substr($msgref->{'+'},0,1) eq '+') { $msgref->{'+'} = substr($msgref->{'+'},1); }
			push @{$R{'@MSGS'}}, $msgref;
			}
		$NC->save();
		}

	undef $NC;

	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}	

	return(\%R);
	}



=pod

<API id="adminProductList">
<purpose>accesses the product database to return a specific hardcoded list of products</purpose>
<input id="CREATED_BEFORE">modified since timestamp</input>
<input id="CREATED_SINCE">modified since timestamp</input>
<input id="SUPPLIER">supplier id</input>
<hint>
indexed attributes: zoovy:prod_id,zoovy:prod_name,
zoovy:prod_supplierid,  zoovy:prod_salesrank, zoovy:prod_mfgid,
zoovy:prod_upc, zoovy:profile
</hint>
</API>

=cut 
 
sub adminProductList {
	my ($self,$v) = @_;

	my %R = ();	

	require PRODUCT::BATCH;
	$R{'@PIDS'} = PRODUCT::BATCH::report($self->username(),%{$v});

	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}	

   return(\%R);
	}




=pod

<API id="adminProductSelectorDetail">
<purpose>a product selector is a relative pointer to a grouping of products.</purpose>
<concept>product</concept>
<input id="selector">
NAVCAT=.safe.path
NAVCAT=$list
CSV=pid1,pid2,pid3
CREATED=YYYYMMDD|YYYYMMDD
RANGE=pid1|pid2
MANAGECAT=/path/to/category
SEARCH=saerchterm
PROFILE=xyz
SUPPLIER=xyz
MFG=xyx
ALL=your_base_are_belong_to_us
</input>
<output id="@products">an array of product id's</output>
</API>



=cut


sub adminProductSelectorDetail {
	my ($self,$v) = @_;

	my %R = ();

	if (not &JSONAPI::validate_required_parameter(\%R,$v,'selector')) {
		}
	else {
		require PRODUCT::BATCH;
		my @PRODUCTS = PRODUCT::BATCH::resolveProductSelector($self->username(),$self->prt(),[ $v->{'selector'} ]);
		$R{'@products'} = \@PRODUCTS;
		}

	return(\%R);
	}


=pod


<API id="adminProductDelete">
<purpose>removes a product id (and all variations) from the database</purpose>
<concept>product</concept>
<input id="pid">pid : an A-Z|0-9|-|_ -- max length 20 characters, case insensitive</input>
</API>

<API id="adminProductCreate">
<purpose>creates a new product in the database</purpose>
<concept>product</concept>
<input id="pid">pid : an A-Z|0-9|-|_ -- max length 20 characters, case insensitive</input>
<input id="%attribs">[ 'zoovy:prod_name':'value' ]</input>
<example>
%attribs:[ 'zoovy:prod_name':'value' ]
</example>
</API>

<API id="adminProductUpdate">
<purpose></purpose>
<input id="pid">pid : an A-Z|0-9|-|_ -- max length 20 characters, case insensitive</input>
<input id="%attribs">[ 'attribute':'value', 'anotherattrib':'value' ]</input>
<example>
%attribs:[ 'attribute':'value', 'anotherattrib':'value' ]
</example>
</API>

<API id="adminProductDetail">
<purpose></purpose>
<input id="pid">pid1</input>
<output id="%attribs">
</output>
<output id="@skus">
@skus = [
  { 'sku':'sku1', '%attribs':{ key1a:val1a, key1b:val1b } },
  { 'sku':'sku2', '%attribs':{ key2b:val2a, key2b:val2b } }
  ]
</output>
</API>

<API id="adminProductDebugLog">
<purpose>see reports for @HEAD,@BODY format</purpose>
<input id="pid">pid1</input>
<input id="GUID"></input>
<output id="@HEAD"></output>
<output id="@BODY"></output>
</API>

<API id="adminProductEBAYDetail">
</API>

<API id="adminProductAmazonDetail">
<output id="%thesaurus"></output>
<output id="@DETAIL"></output>
</API>

<API id="adminProductAmazonVerify">
<output id="@MSGS"></output>
<note>
TITLE|SUCCESS|INFO|WARN|STOP|PAUSE|ERROR|DEPRECATION|DEBUG|XML
</note>
</API>

<API id="adminProductBUYDetail">
<input id="pid">pid1</input>
<output id="@DBMAPS"></output>
<output id="buycom/dbmap"></output>
<output id="%FLEX"></output>
</API>


<API id="adminProductOptionsUpdate">
<input id="pid">pid1</input>
<input id="@pogs">an array of pog options</input>
</API>

<API id="adminProductEventsDetail">
<input id="pid">pid1</input>
</API>

<API id="adminProductMacro">
<purpose></purpose>
<input id="pid">pid1</input>
<input id="@updates"></input>
</API>

=cut


sub adminProduct {
	my ($self,$v) = @_;


	require PRODUCT;
	require ELASTIC;
	my %R = ();	

	my $PID = $v->{'pid'};
	my $USERNAME = $self->username();
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $LUSERNAME = $self->luser();
	my $PRT = $self->prt();
	my $t = time();
	my ($INV2) = INVENTORY2->new($USERNAME,$LUSERNAME);
	my $INVENTORY_SUMMARIZE_PLEASE = 0;

	my ($exists) = &ZOOVY::productidexists($self->username(),$PID);
	if ($v->{'_cmd'} eq 'adminProductCreate') {
		if ($exists) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',12031,sprintf('Product:%s already exists',$PID));
			}
		else {
			my ($P) = PRODUCT->new($self->username(),$PID,'create'=>1);
			foreach my $k (keys %{$v->{'%attribs'}}) {
				$P->store($k,$v->{'%attribs'}->{$k});
				}
			$P->save();
			## index it right away so it appears in search asap.
			ELASTIC::add_products($self->username(),[ $P ]);
			}
		}
	elsif (not $exists) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',12032,sprintf('Product:%s does not exist',$PID));
		}
	elsif ($v->{'_cmd'} eq 'adminProductDelete') {
		&ZOOVY::deleteproduct($self->username(),$PID);
		}
	elsif (($v->{'_cmd'} eq 'adminProductUpdate') || ($v->{'_cmd'} eq 'adminProductMacro') || ($v->{'_cmd'} eq 'adminProductOptionsUpdate')) {
		my ($P) = PRODUCT->new($self->username(),$PID);

		if ($v->{'_cmd'} eq 'adminProductOptionsUpdate') {
			if (not &JSONAPI::validate_required_parameter(\%R,$v,'@pogs')) {
				}
			elsif (ref($v->{'@pogs'}) ne 'ARRAY') {
				&JSONAPI::append_msg_to_response(\%R,'apperr',9007,'@pogs parameter not passed to adminProductOptionsUpdate');
				}
			elsif ($v->{'@pogs'}) {
				## pass autoid=1 as a parameter to auto correct/add pog id's & option id's.
				my $pogsref = $v->{'@pogs'};
				my @NEEDS_POG_AUTOID = ();
				my @NEESD_OPTION_AUTOID = ();
				my %USED_POG_IDS = ();

				## VALIDATE OPTIONS
				foreach my $pog (@{$pogsref}) {
					## first we make a map of any pogs which need autoid
					if ((defined $pog->{'id'}) && ($pog->{'id'} ne '')) {
						$USED_POG_IDS{$pog->{'id'}} = $pog;
						}
					elsif (not $pog->{'autoid'}) {
						&JSONAPI::append_msg_to_response(\%R,'apperr',9019,'variation id is blank, and autoid is not set');
						}
					elsif ($pog->{'sog'}) {
						## ignore sogs, we don't fancy their type here.
						&JSONAPI::append_msg_to_response(\%R,'apperr',9018,'sog is set, but id is blank, cannot autoid on sogs. corrupt variation');
						}
					else {
						push @NEEDS_POG_AUTOID, $pog;
						}

					#if ($self->apiversion()==201324) {
					#	## band-aid to keep 201324 working.
					#	if ($pog->{'v'}==2) {
					#		}
					#	elsif ((defined $pog->{'options'}) && (ref($pog->{'options'}) eq 'ARRAY')) {
					#		delete $pog->{'options'};
					#		$pog->{'@options'} = $pog->{'options'};
					#		}
					#	}

					if ((defined $pog->{'@options'}) && (ref($pog->{'@options'}) eq 'ARRAY')) {
						## check to see if any options in this pog that don't have options.
						my %USED_OPTION_VS = ();
						my @NEED_OPTION_VS = ();
						foreach my $opt (@{$pog->{'@options'}}) {
							if ((defined $opt->{'v'}) && ($opt->{'v'} ne '')) {
								$USED_OPTION_VS{$opt->{'v'}}++;
								}
							elsif (not $pog->{'autoid'}) {
								&JSONAPI::append_msg_to_response(\%R,'apperr',9020,'option in pog is blank, and autoid is not set');
								}
							elsif ($pog->{'sog'}) {
								## ignore sogs, we don't fancy their type here.
								&JSONAPI::append_msg_to_response(\%R,'apperr',9021,'sog is set, but optoin id is blank, cannot autoid on sogs. corrupt variation option');
								}
							else {
								push @NEED_OPTION_VS, $opt; 
								}
							}

						my $i = -1;
						foreach my $opt (@NEED_OPTION_VS) {
							next if ((defined $opt->{'v'}) && (length($opt->{'v'}) == 2));
							my $ATTEMPTVID = undef;
							do {
								last if ($i > 1296);
								$ATTEMPTVID = &POGS::base36( ++$i );
								} while (defined $USED_OPTION_VS{$ATTEMPTVID});
							if ((not defined $USED_OPTION_VS{$ATTEMPTVID}) && ($i<1296)) {
								$opt->{'v'} = $ATTEMPTVID;
								}
							}
						}
					delete $pog->{'autoid'};
					}

				## assign any autoid's to pogs.
				if (scalar(@NEEDS_POG_AUTOID)>0) {
					my $i = 0;
					## assign ID's to any option that doesn't have one!
					my $counter = 36;
					foreach my $pog (@NEEDS_POG_AUTOID) {
						last if ($counter <= 0);
						my $ATTEMPTID = '';
						do {
							$ATTEMPTID = sprintf("#%s",&ZTOOLKIT::base36(--$counter));
							} while (defined $USED_POG_IDS{$ATTEMPTID});
						if (($counter < 36) && ($counter>9)) {
							$pog->{'id'} = $ATTEMPTID;
							$USED_POG_IDS{$ATTEMPTID} = $pog;
							}
						}
					}

				if (not &JSONAPI::hadError(\%R)) {
					$P->store_pogs($pogsref); 			
					}
				}
			}

		if (($v->{'_cmd'} eq 'adminProductUpdate') || ($v->{'_cmd'} eq 'adminProductOptionsUpdate')) {
			foreach my $k (keys %{$v->{'%attribs'}}) {
				# $ref->{$k} = $v->{'%attribs'}->{$k};
				if (index("\r",$v->{'%attribs'}->{$k})) {
					$v->{'%attribs'}->{$k} =~ s/[\r]+//gs;	# strip line feeds on incoming data.
					}
				$P->store($k,$v->{'%attribs'}->{$k});
				}

			if (defined $v->{'%skus'}) {
				foreach my $SKU (keys %{$v->{'%skus'}}) {
					foreach my $k (keys %{$v->{'%skus'}->{$SKU}}) {
						$P->skustore($SKU,$k,$v->{'%skus'}->{$SKU}->{$k});
						}
					}
				}

			}

		## validation phase
		my @CMDS = ();
		if (&JSONAPI::hadError(\%R)) {
			## shit happened!
			}
		elsif ( not defined $v->{'@updates'} ) {
			if ($v->{'%attribs'}) {
				## not an error, it's okay.
				}
			elsif ($v->{'_cmd'} eq 'adminProductUpdate') {
				## adminProductMacro and adminProductOptionsUpdate
				&JSONAPI::append_msg_to_response(\%R,'apperr',9002,'Could not find any @updates for order');
				}
			}
		elsif (ref($v->{'@updates'}) eq 'ARRAY') {
			my $count = 0;
			foreach my $line (@{$v->{'@updates'}}) {
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					$cmdset->[1]->{'luser'} = $self->luser();
					$cmdset->[2] = $line;
					$cmdset->[3] = $count++;
					push @CMDS, $cmdset;
					}
				}
			}

		if (($v->{'_cmd'} eq 'adminProductMacro') && (scalar(@CMDS)==0)) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9012,'Could not find any @updates which is required for adminProductMacro');
			}

		if (not &JSONAPI::hadError(\%R)) {
			## Validation Phase
			my ($udbh) = &DBINFO::db_user_connect($USERNAME);
			my ($NC) = undef;
			my ($RP) = undef;

			my @MSGS = ();	
			my ($lm) = LISTING::MSGS->new($USERNAME,'@MSGS'=>\@MSGS);


			foreach my $cmdset (@CMDS) {
				my ($VERB,$params,$line,$linecount) = @{$cmdset};

				if ($self->apiversion() < 201332) {
					if ($VERB eq 'SET/SKU') { $VERB = 'SET-SKU'; }
					}

				if (not $lm->can_proceed()) {
					}
				elsif ($VERB eq 'SET-EBAY') {
					my $SITE = $params->{'site'};
					if ($params->{'category'}) { $P->store('ebay:category', $params->{'category'}); }
					if ($params->{'category2'}) { $P->store('ebay:category2', $params->{'category2'}); }
					if ($params->{'attributeset'}) { $P->store('ebay:attributeset', $params->{'attributeset'}); }
					if ($params->{'itemspecifics'}) {
						$P->store('ebay:itemspecifics', $params->{'itemspecifics'});
						}
					}
				elsif ($VERB eq 'SET-SKU') {
					my $SKU = $params->{'SKU'};
					foreach my $k (keys %{$params}) {
						next if (lc($k) ne $k);
						next if ($k eq 'luser');
						$P->skustore($SKU,$k,$params->{$k});
						}
					}
				elsif ($VERB eq 'SET-SKU-PRICETAG') {
					my $SKU = $params->{'SKU'};
					my ($tag, $price) = ($params->{'tag'},	$params->{'price'});
					$P->skustore($SKU,"sku:pricetags.$tag",$price);
					}
				elsif ($VERB eq 'SET') {
					foreach my $k (keys %{$params}) {
						next if (lc($k) ne $k);
						next if ($k eq 'luser');
						$P->store($k,$params->{$k});
						}
					}
				elsif ($VERB eq 'NUKE') {
					if ($params->{'IMAGES'}) {
						require MEDIA;
						my @images = ();
						push @images, 'zoovy:prod_thumb';
						foreach my $i (1..9999) { push @images, 'zoovy:prod_image'.$i; }
						foreach my $img (@images) {
							next if ($P->fetch($img) eq '');
							print STDERR "NUKE: $img\n";
							$self->log('PRODEDIT.NUKEIMG',"[PID:$PID] Nuking image $img=".$P->fetch($img),'INFO');
							&MEDIA::nuke($USERNAME,$P->fetch($img));
							}
						}
					$self->log('PRODEDIT.NUKE',"Nuking Product $PID",'INFO');
					&ZOOVY::deleteproduct($USERNAME,$PID);
					$P = undef;
					}
				#elsif ($VERB eq 'SET-SKU-SCHEDULE') {
				#	my $SKU = $params->{'SKU'};
				#	my $SCHEDULE = $params->{'SCHEDULE'};
				#	## [1:39:50 PM] Brian Horakh: SKU-SET-SCHEDULE?SKU=xyz&SCHEDULE=xyz&price=&discounts=&minqty=&incqty=	
				#	}
				elsif ($VERB eq 'SET-SCHEDULE-PRICE') {
					## set-schedule-price
					my $SKU = $params->{'SKU'};
					my $SCHEDULE = $params->{'schedule'};
					my $PRICE = $params->{'price'};
					my $KEY = sprintf('zoovy:schedule_%s',lc($SCHEDULE));
					$P->skustore($SKU,$KEY,$PRICE);
					}
				elsif (($VERB eq 'SET-SCHEDULE') || ($VERB eq 'SET-SCHEDULE-PROPERTIES')) {
					## as of 201342 it's SET-SCHEDULE-PROPERTIES
					my $SCHEDULEID = $params->{'schedule'};
					if ($SCHEDULEID eq '*') {
						$P->store('zoovy:qty_price', $params->{'qtyprice'});
						}
					#elsif ($SCHEDULEID =~ /^[MQ]P/) {
					else {
						$P->store(sprintf('zoovy:qtymin_%s',lc($SCHEDULEID)), $params->{'qtymin'});
						$P->store(sprintf('zoovy:qtyinc_%s',lc($SCHEDULEID)), $params->{'qtyinc'});
						$P->store(sprintf('zoovy:qtyprice_%s',lc($SCHEDULEID)), $params->{'qtyprice'});
						}
					#else {
					#	$P->store(sprintf('zoovy:qtyprice_%s',lc($SCHEDULEID)), $params->{'qtyprice'});
					#	}
					}
				elsif (($VERB eq 'CLONE') || ($VERB eq 'RENAME')) {
					my $NEWID = $params->{'NEWID'};
					$NEWID =~ s/[^\w-]+//g;

					if (($VERB eq 'RENAME') && ($NEWID eq '')) { 	
						push @MSGS, "ERROR|+You must input a Product ID for $PID to be renamed to"; $NEWID = '';
						}
					if (($VERB eq 'CLONE') && ($NEWID eq '')) { 	
						push @MSGS, "ERROR|+You must input a Product ID for $PID to be cloned to"; $NEWID = '';
						}
					if (&ZOOVY::productidexists($USERNAME,$NEWID)) { 
						push @MSGS, "ERROR|+A product with the id $NEWID already exists"; $NEWID = '';
						}

					my $Pnew = undef;
					if ($lm->can_proceed()) {
						$Pnew = PRODUCT->new($USERNAME,$NEWID,'create'=>1);
						}

					if (defined $Pnew) {
						require NAVCAT;
						$INV2->pidinvcmd($PID,'RENAME','NEW_PID'=>$NEWID);
		
						#my ($onref,$reserveref,$locref,$reorderref,$onorderref) = &INVENTORY::fetch_incrementals($USERNAME,[$PID],undef,8+16+32+64+128);
						#foreach my $sku (keys %{$onref}) {
						#	my ($pid,$claim,$invopts,$noinvopts) = &PRODUCT::stid_to_pid($sku);
						#	next if ($pid ne $PID);	## wtf, sometimes fetch_incrementals returns us products that we didn't ask for. (yeah it's supposed to do that)
						#	my $NEWSKU = $NEWID.(($invopts ne '')?':'.$invopts:'').(($noinvopts ne '')?'/'.$noinvopts:'');
						#	if ($VERB eq 'RENAME') { 
						#		&INVENTORY::save_record($USERNAME,$NEWSKU,$onref->{$sku},'U',$locref->{$sku},'CHANGEPID');
						#		&INVENTORY::nuke_record($USERNAME,$PID,$sku,"Rename to $NEWSKU"); 
						#		}
						#	## NOTE: inventory on cloned products may not be set to unlimited properly. not sure why? 8/16/2012
						#	## 		but inventory changes are coming soon so i'm not going to fix?
						#	}		

						## NOTE: we need to copy the product if we're cloning or renaming (but we only need to delete if we're renaming)
						my $PREF = $P->prodref();

						if ($VERB eq 'CLONE') {
							$self->log('PRODEDIT.CLONE',"PID[$PID] cloned to PID[$NEWID]",'INFO');
							}
						elsif ($VERB eq 'RENAME') {
							$self->log('PRODEDIT.RENAME',"PID[$PID] renamed to PID[$NEWID]",'INFO');
							}

						foreach my $k (keys %{$PREF}) { 
							my $skip = 0;
							if ($VERB eq 'RENAME') {}					## on a rename, don't destory fields.
							elsif ($k =~ /^zoovy\:/) {} 												## always CLONE zoovy: fields
							elsif (substr($k,0,1) eq '%') { $skip++; }		## ex: %SKU 
							elsif (substr($k,0,1) eq '@') { $skip++; }		## ex: @POGS
							elsif (($k =~ /^ebay/) && ($params->{'CLONE_EBAY'})) {}	## only CLONE ebay: fields if indicated by merchant
							elsif ($params->{'CLONE_OTHER'} && $k ne 'amz:asin') {}	## only CLONE other: (amz:, etc) fields if indicated by merchant
							else {				
								$skip++;																			## never CLONE amz:asin, this causes major merging issues!!	
								}
				
							if (not $skip) { $Pnew->store($k,$PREF->{$k}); }
							}
	
						if (scalar(@{$P->fetch_pogs()})>0) {
							## copy product options and sku level data.
							$Pnew->store_pogs($P->pogs());
	
							foreach my $skuset (@{$P->list_skus('verify'=>1)}) {
								my ($SKU,$dataref) = @{$skuset};
								next if ($SKU eq '');
								next if ($SKU eq '.');
								my $NEWSKU = $NEWID.substr($SKU,0,length($SKU));
								foreach my $k (keys %{$dataref}) {
									$Pnew->skustore($NEWSKU,$k,$dataref->{$k});
									}
								}
							}

						if ($params->{'CLONE_DISABLESYNDICATION'}) {
							## forces syndication off for all products.
							foreach my $ref (@ZOOVY::INTEGRATIONS) {
								if ($ref->{'attr'}) { 
									$Pnew->store($ref->{'attr'},0);
									}
								}
							}
						$Pnew->save();
						}
	
					if ($VERB eq 'RENAME') {
						# handle navcats
						if (not defined $NC) { ($NC) = NAVCAT->new($USERNAME,PRT=>$PRT); }
						$self->log('PRODEDIT.RENAME',"PID[$PID] renamed to PID[$NEWID]",'INFO');
						require NAVCAT;
						foreach my $prttext (@{&ZWEBSITE::list_partitions($USERNAME)}) {		
							my ($prt) = split(/:/,$prttext);
							my $arref = $NC->paths_by_product($PID);
							foreach my $safe (@{$arref}) {
								$NC->set( $safe, insert_product=>$NEWID, delete_product=>$PID);
								}
							}
	
						require PRODUCT::REVIEWS;
						&PRODUCT::REVIEWS::rename_product($USERNAME,$PID,$NEWID);
						&ZOOVY::deleteproduct($USERNAME,$PID);
						}

					$P = $Pnew;
					if ((defined $P) &&  (ref($P) eq 'PRODUCT')) {
						require ELASTIC;
						ELASTIC::add_products($USERNAME,[ $P ]);
						$PID = $P->pid();
						}
					else { 
						warn "\$P is not defined -- ERROR!\n";
						}

					}
				elsif ($VERB eq 'EVENT-REDISPATCH') {
					$params->{'LEID'} = int($params->{'LEID'});
					my ($le) = LISTING::EVENT->new(USERNAME=>$USERNAME,LEID=>$params->{'LEID'});
					if (not defined $le) {
						push @MSGS, "ERROR|+Unable to instantiate LISTING::EVENT for LEID=$params->{'LEID'}";
						}
					else {
						$le->dispatch($udbh,$P);
						}
					# use Data::Dumper; $ERROR = '<pre>'.Dumper({le=>$le,RESULT=>$RESULT,METAREF=>$METAREF}).'</pre>';
					my ($result) = $le->whatsup();
					}
				elsif ($VERB =~ /^NAVCAT-(CLEARALL|INSERT|DELETE)$/) {
					if (not defined $NC) { $NC = NAVCAT->new($USERNAME,PRT=>$PRT); }
					if ($VERB eq 'NAVCAT-CLEARALL') {
						$NC->nuke_product($PID);
						}
					elsif ($VERB eq 'NAVCAT-DELETE') {
						$NC->set($params->{'path'},delete_product=>$PID); 
						}
					elsif ($VERB eq 'NAVCAT-INSERT') {
						$NC->set($params->{'path'},insert_product=>$PID);
						}
					}
				#elsif ($VERB eq 'WMS') {
				#	my $SKU = $params->{'SKU'};
				#	my $QTY = $params->{'qty'};
				#	my $LOC = $params->{'loc'};
				#	my $COST = $params->{'cost'};
				#	my $COND = $params->{'cond'};
				#	my $CONTAINER = $params->{'container'};
				#	my $NOTE = $params->{'note'};
				#	my $ORIGIN = $params->{'origin'};
				#	my ($WH,$ZONE,$POS) = ZWMS::locparse($LOC);
				#	if ($WH eq '') { $lm->pooshmsg("ERROR|+Warehouse not found in location"); }
				#	elsif ($ZONE eq '') { $lm->pooshmsg("ERROR|+Zone not found in location"); }
				#	elsif ($POS eq '') { $lm->pooshmsg("ERROR|+Location not found"); }
				#	elsif (not &ZWMS::is_valid_location($USERNAME,$LOC,'*LM'=>$lm)) {
				#		## note: is_valid_location sets *LM with error
				#		push @MSGS, "ERROR|+Invalid Location '$LOC' cannot store";
				#		}

				#	if ($lm->can_proceed()) {
				#		&ZWMS::parse_update($USERNAME,[
				#			sprintf("PUT:%d %s %s %s",
				#				$QTY,$SKU,$LOC,
				#				&ZWMS::xenc({'LU'=>$LUSERNAME,'COND'=>$COND,'COST'=>$COST,'NOTE'=>$NOTE,'CONTAINER'=>$CONTAINER,'ORIGIN'=>$ORIGIN})
				#				),
				#			]);
				#		}
				#	}
				## INV-CONSTANT
				elsif ($VERB =~ /^INV-(PREORDER|SUPPLIER|RETURN|BACKORDER|ERROR|PICK|SIMPLE|WMS|MARKET|CONSTANT|BASETYPE)-(UUID|SKU|PID)-(INIT|SET|ANNOTATE|PREFERENCE|ADD|SUB|NUKE)$/) {
					my ($BASETYPE,$TARGET,$CMD) = ($1,$2,$3);

					if ($TARGET eq 'PID') { 
						$INV2->invcmd($CMD,'BASETYPE'=>$BASETYPE,'@MSGS'=>\@MSGS,'PID'=>$PID,%{$params});
						}
					elsif ($TARGET eq 'SKU') {
						$INV2->invcmd($CMD,'BASETYPE'=>$BASETYPE,'@MSGS'=>\@MSGS,'SKU'=>$params->{'SKU'},%{$params});
						}
					elsif ($TARGET eq 'UUID') {
						$INV2->invcmd($CMD,'BASETYPE'=>$BASETYPE,'@MSGS'=>\@MSGS,'UUID'=>$params->{'UUID'},%{$params});
						}
					else {
						push @MSGS, "ERROR|+Invalid target: $TARGET";
						}
					$INVENTORY_SUMMARIZE_PLEASE++;
					}
				elsif (($VERB eq 'INVENTORY') && ($self->apiversion()<=201336)) {

					#if (defined $params->{'UNLIMITED'}) {
					#	my $inv_enable |= 1;
					#	if ($params->{'UNLIMITED'}) { $inv_enable |= 32; }
					#	if ($P->has_variations('inv')) { $inv_enable |= 4; }
					#	$P->store('zoovy:inv_enable',$inv_enable); 
					#	&ZOOVY::log($USERNAME,$LUSERNAME,sprintf("PID:%s.INVENTORY",$P->pid()),"save panel","SAVE");
					#	## &INVENTORY::update_reserve($USERNAME,$PID);
					#	}
		
					my $BLANKRECORDS = 0;
					if ($params->{'SKU'}) {
						my $NOTE = $params->{'LOC'};
						my $SKU = $params->{'SKU'};
						if ((defined $params->{'WAS'}) && (defined $params->{'IS'})) {
							my $INC = int($params->{'IS'} - $params->{'WAS'});
							$INV2->skuinvcmd($SKU,"ADD",QTY=>$INC,NOTE=>$NOTE);
							## &INVENTORY::add_incremental($USERNAME,$SKU,'I',$INC);
							}
						elsif ($params->{'IS'}) {
							$BLANKRECORDS++;
							## &INVENTORY::save_record($USERNAME,$SKU,$params->{'IS'},'U',$params->{'IS'},'MOD5');
							$INV2->skuinvcmd($SKU,"INIT",QTY=>$INC,NOTE=>$NOTE);
							}
						#if (defined $params->{'LOC'}) {
						#	&INVENTORY::set_meta($USERNAME,$SKU,'LOCATION'=>$params->{'LOC'});
						#	}

						}

					## If we had blank records, then we really ought to check for phantoms since it means inventory has changed!
					## this mainly to catch boneheads to try and restructure they're inventoriable options
					if ($BLANKRECORDS) {
						# my ($invref,$reserveref) = &INVENTORY::fetch_qty($USERNAME,[$PID]);
						my ($invref,$reserveref) = $INV2->fetch_qty([$PID]);
						## clear out the legitimate records
						foreach my $set (@{$P->list_skus('verify'=>1)}) { delete $invref->{ $set->[0] }; }
						## do we have any phantoms?? 
						foreach my $PHANTOM (keys %{$invref}) {
							next unless ($PHANTOM =~ /^$PID/);		# 4/20/06 bh - phantom SKU's *must* be a subset of the current PID 
																# note: if we don't do this then we can accidentally blow out 
																# any pending incremental updates which were returned in INV::fetch_qty
							## &INVENTORY::nuke_record($USERNAME,$PID,$PHANTOM);
							$INV2->skuinvcmd($PHANTOM,'NUKE');
							my ($t) = TODO->new($USERNAME,writeonly=>1,LUSER=>$LUSERNAME);
							if (defined $t) {
								$t->add(title=>"Inventory corrupt found on product $PID",link=>"product:$PID",class=>"ERROR",detail=>"Inventory record was destroyed because a phantom $PHANTOM was found for pid: $PID");
								}
							}
						}
					}
				elsif ($VERB =~ /^AMAZON-(REMOVE|QUEUE|QUEUE-LATER)$/) {
					## AMAZON-QUEUE AMAZON-QUEUE-LATER
					my ($VERB) = ($1);
					require SYNDICATION::EVENT;
					my ($userref) = &AMAZON3::fetch_userprt($USERNAME);
					#if ($VERB eq 'LOG-DROP') {
					#	&AMAZON3::item_set_status(
					#		$userref,
					#		[ $P->pid() ],
					#		[],
					#		'USE_PIDS'=>1,
					#		'ERROR'=>TXLOG::addline(0,'INIT','_'=>'SUCCESS','+'=>sprintf('Log was reset by %s',$self->luser()))
					#		);
					#	push @MSGS, "SUCCESS|+Log has been dropped.";
					#	}
					if ($VERB eq 'REMOVE') {
						&AMAZON3::item_set_status($userref,[ $P->pid() ],['=this.delete_please'],'USE_PIDS'=>1,'+ERROR'=>TXLOG::addline(0,'PRODUCTS','_'=>'SUCCESS','+'=>'Delete Requested via User Interface'));
						push @MSGS, "SUCCESS|+Delete Issued";
						}
					elsif ($VERB eq 'QUEUE') {
						&AMAZON3::item_set_status($userref,[ $P->pid() ],['=this.create_please'],'USE_PIDS'=>1,'ERROR'=>TXLOG::addline(0,'PRODUCTS','_'=>'SUCCESS','+'=>'Re-Queue Requested Via User Interface'));
						push @MSGS, "SUCCESS|+Re-Queue Issued";
						}
					elsif ($VERB eq 'QUEUE-LATER') {		
						my ($ID) = SYNDICATION::EVENT::add($USERNAME,$P->pid(),'AMZ','CREATE','CREATE_LATER'=>3600*30);
						if ($ID==0) {
							push @MSGS, "ERROR|+VERB:$VERB could not be run";
							}
						else {
							push @MSGS, "SUCCESS|+VERB:$VERB was successfully queued ($ID)";
							}
						}
					}
				elsif ($VERB =~ /^EBAY-(REFRESH|ARCHIVE|RESET|DISABLE|END|REFRESH|CREATE|TEST)-(LISTING|FIXED|AUCTION|SYNDICATION)$/) {
					## EBAY-TEST-SYNDICATION
					my ($VERB,$LISTINGTYPE) = ($1,$2);
				
					my $prodref = $P->prodref();
					my $requuid = undef;

					if ($VERB eq 'DISABLE') {
						$P->store('ebay:ts',0);
						&ZOOVY::log($USERNAME,$LUSERNAME,sprintf("PID:%s.EBAY",$P->pid()),"syndication ended and listing removed","SAVE");
						$VERB = 'END';
						}
					
					## this MUST be placed after the SAVE for the SAVE-AND-REFRESH function
					if (($VERB eq 'END') || ($VERB eq 'REFRESH')) {
						require LISTING::EVENT;
						my $TARGET = sprintf("EBAY.%s",$LISTINGTYPE);
						print STDERR "TARGET:$TARGET\n";
						($TARGET) = LISTING::EVENT::normalize_target($TARGET);

						my $LAUNCH_MESSAGE = undef;
						my $leVERB = $VERB;
						if ($leVERB eq 'REFRESH') { $leVERB = 'UPDATE-LISTING'; }
						if ($leVERB eq 'SAVE-AND-REFRESH') { $leVERB = 'UPDATE-LISTING'; }

						my ($le) = undef;	
						if (not defined $TARGET) {
							push @MSGS, "ERROR|+Could not ascertain target";
							}
						else {
							($le) = LISTING::EVENT->new(USERNAME=>$USERNAME,LUSER=>$LUSERNAME,
								'@MSGS'=>\@MSGS,
								REQUEST_APP=>'PRODEDIT',
								REQUEST_APP_UUID=>$requuid,
								SKU=>$P->pid(),
								TARGET=>$TARGET,
								TARGET_UUID=>$params->{'OOID'},
								TARGET_LISTINGID=>$params->{'LISTINGID'},
								PRT=>$PRT,VERB=>$leVERB,LOCK=>1);	
							}

						if ($LAUNCH_MESSAGE ne '') {
							}		
						elsif (ref($le) eq 'LISTING::EVENT') {
							$le->dispatch($udbh,$P);
							}
						else {
							push @MSGS, "ERROR|+INTERNAL-ERROR - was not able to create/process a listing event";
							}
						}



					if (($VERB eq 'CREATE') || ($VERB eq 'TEST')) {
						## NOTE: TARGET might have changed since save.
						my ($QTY,$QTYFIELD,$TARGET) = (0,'');
						my $le = undef;
				
						## if a QTY field (e.g. ebay:qty) is set in the product then use it, otherwise default to 1
						if (not $lm->can_proceed()) {
							}
						elsif ($LISTINGTYPE eq 'SYNDICATION') {
							$TARGET = 'EBAY.SYND';
							$QTY = -1;
							}
						elsif ($LISTINGTYPE eq 'FIXED') {
							$QTY = $prodref->{'ebay:fixed_qty'};
							if (not defined $QTY) { $QTY = 1; }
							if (int($QTY)==0) { push @MSGS, "ERROR|+Quantity field (ebay:fixed_quantity) is zero"; }
							$TARGET = 'EBAY.FIXED';
							}
						elsif ($LISTINGTYPE eq 'AUCTION') {
							$QTY = $prodref->{'ebay:qty'};
							if (not defined $QTY) { $QTY = 1; }
							if (int($QTY)==0) { push @MSGS, "ERROR|+Quantity field (ebay:qty) is zero"; }
							$TARGET = 'EBAY.AUCTION';
							}
				
						require LISTING::EVENT;
						if ($lm->can_proceed()) {
							my $LEVERB = 'INSERT';
							if ($VERB =~ /^TEST/) { $LEVERB = 'PREVIEW'; }
							($le) = LISTING::EVENT->new(USERNAME=>$USERNAME,LUSER=>$LUSERNAME,
								'@MSGS'=>\@MSGS,
								REQUEST_APP=>'PRODEDIT',
								REQUEST_APP_UUID=>$requuid,
								SKU=>$P->pid(),
								QTY=>$QTY,
								TARGET=>$TARGET,
								PRT=>$PRT,VERB=>$LEVERB,LOCK=>1);
							}


						if (not $lm->can_proceed()) {
							}
						elsif (($le->id()>0) || ($VERB =~ /^TEST/)) {
							$le->dispatch($udbh,$P);
							## $LAUNCH_MESSAGE = $le->html_result();				
							#require LISTING::EBAY;
							#($RESULT,$METAREF) = LISTING::EBAY::event_handler($udbh,$le,$prodref);
							#if ($RESULT =~ /SUCCESS/) {
							#	$LAUNCH_MESSAGE = "<div class='blue'>$RESULT</div>";
							#	# $LAUNCH_MESSAGE = '<pre>'.&ZOOVY::incode(Dumper({RESULT=>$RESULT,META=>$METAREF})).'</pre>';
							#	}
							#elsif ((defined $METAREF->{'@MSGS'}) && (scalar($METAREF->{'@MSGS'})>0)) {
							#	foreach my $msg (grep(/(ERR|WARN)\|/,@{$METAREF->{'@MSGS'}})) {
							#		$LAUNCH_MESSAGE .= "<li> $msg<br>";				
							#		}
							#	if ($LAUNCH_MESSAGE eq '') { $LAUNCH_MESSAGE = "<li> Please preview listing for more info.<br>"; }
							#	$LAUNCH_MESSAGE = "<div class=\"error\">The following errors were encountered:<br>$LAUNCH_MESSAGE</div>";
							#	# $LAUNCH_MESSAGE .= '<pre>'.&ZOOVY::incode(Dumper({RESULT=>$RESULT,META=>$METAREF})).'</pre>';
							#	}
							}
						else {
							push @MSGS, "ERROR|+Internal error processing macro";
							}				
						}


					#if ($VERB eq 'CHANGE-LISTINGTYPE') {
					#	# &ZOOVY::log($USERNAME,$LUSERNAME,sprintf("PID:%s.EBAY",$P->pid()),"change listing type to $prodref->{'ebay:listingtype'}","SAVE");
					#	}
					#else {
					#	&ZOOVY::log($USERNAME,$LUSERNAME,sprintf("PID:%s.EBAY",$P->pid()),"save panel","SAVE");
					#	}

					if ($VERB eq 'ARCHIVE') {
						my $pstmt = "update EBAY_LISTINGS set EXPIRES_GMT=$^T where MID=$MID /* $USERNAME */ and ID=".int($params->{'OOID'});
						&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
						$self->log("PRODEDIT.EBAY2","Archived OOID=$params->{'OOID'} LISTINGID=$params->{'LISTINGID'}","SAVE");
						}
					elsif ($VERB eq 'RESET') {
						## reset the product data
						foreach my $k (keys %{$P->prodref()}) {
							next if ($k eq 'ebay:category');
							next if ($k eq 'ebay:category2');
							if ($k =~ /^ebay\:/) { $P->store($k,undef); }
							if ($k =~ /^ebaystore\:/) { $P->store($k,undef); }
							if ($k =~ /^ebaymotor\:/) { $P->store($k,undef); }
							}
						&ZOOVY::log($USERNAME,$LUSERNAME,sprintf("PID:%s.EBAY",$P->pid()),"Reset eBay data","SAVE");
						}

					print STDERR "MSGS IS: ".Dumper(\@MSGS);
					}
				elsif ($VERB =~ /^CIAGENT-UPDATE$/) {
					if (not defined $RP) { ($RP) = REPRICE->new($P); }
					tie my %rp, 'REPRICE', $RP; 
					my $SKU = $params->{'SKU'};
					$rp{"$SKU.STRATEGY"} = $params->{"STRATEGY"};
					$rp{"$SKU.MINPRICE"} = $params->{"MINPRICE"};
					$rp{"$SKU.MINSHIP"} = $params->{"MINSHIP"};
					$RP->save();
					
					}
				elsif ($VERB =~ /^REVIEW-(SAVE|ADDNEW|DELETE)$/) {
					my ($VERB) = ($1); 
				   if ($VERB eq 'SAVE') {
						## note: ACTION=ADDNEW is set by the "SAVE" button (so we can tell the difference between just closing
						##			the form, and requesting we save)
						$VERB = '';
						}
					elsif ($VERB eq 'ADDNEW') {
						if ($params->{'ID'} eq '') { delete $params->{'ID'}; }	# if ID is blank, insert a new row.
						$params->{'APPROVED_GMT'} = $^T;
						my ($err) = &PRODUCT::REVIEWS::add_review($USERNAME,$P->pid(),$params);	
						$VERB = '';
						}
					elsif ($VERB eq 'DELETE') {
						&PRODUCT::REVIEWS::update_review($USERNAME,$params->{'ID'},'_NUKE_'=>1);
						$VERB = '';
						}
					}
				#elsif ($VERB eq 'DEBUG-INVENTORY-OVERRIDE-RESERVE') {
				#	my ($SKU) = $v->{'SKU'};
				#	my ($APPKEY) = $v->{'APPKEY'};
				#	my ($LISTINGID) = $v->{'LISTINGID'};
				#	&INVENTORY2->new($USERNAME)->mktinvcmd("EBAY",$EBAY_ID,"SET",$SKU,"QTY"=>0,"ENDS_GMT"=>time()-1,"NOTE"=>sprintf("Reason:%s",$params{"REASON"}));
				#	&INVENTORY::set_other($USERNAME,$APPKEY,$SKU,0,'expirets'=>time()-1,'uuid'=>$LISTINGID);
				#	$self->log("PRODEDIT.DEBUG.RESINVOVERRIDE","Reserve Inventory Override SKU=$SKU APPKEY=$APPKEY LISTINGID=$LISTINGID");
				#	}
				elsif ($VERB eq 'DEBUG-INVENTORY-REFRESH') {
					## &INVENTORY::update_reserve($USERNAME,$PID,1+2+4+8);
					## INVENTORY2->new($USERNAME)->skuinvcmd($PID,'UPDATE-RESERVE');
					push @MSGS, "SUCCESS|+Reserve Inventory for product $PID has been updated.";
					# NOTE: if this changes any values, it indicates a critical error in the inventory system. Do not use this feature unless instructed by technical support.
					}
				else {
					push @MSGS, "ERROR|+Invalid adminProductMacro VERB:$VERB";
					}
				}

			$R{'@MSGS'} = [];
			foreach my $msg (@{$lm->msgs()}) {
				my ($msgref,$status) = LISTING::MSGS::msg_to_disposition($msg);
				if (substr($msgref->{'+'},0,1) eq '+') { $msgref->{'+'} = substr($msgref->{'+'},1); }
				next if ( ($msgref->{'!'} eq 'DEBUG') && (&ZOOVY::servername() ne 'dev') );
				push @{$R{'@MSGS'}}, $msgref;
				}

			if (defined $NC) { $NC->save(); }
			&DBINFO::db_user_close();
			}
			
		# &ZOOVY::saveproduct_from_hashref($USERNAME,$PID,$ref);
		if ((defined $P) && ($INVENTORY_SUMMARIZE_PLEASE)) {
			$INV2->summarize($P);
			}

		if ((defined $P) && (ref($P) eq 'PRODUCT')) {
			$P->save();
			}

		}
	elsif ($v->{'_cmd'} eq 'adminProductDetail') {
		my ($P) = PRODUCT->new($self->username(),$PID);
		$R{'pid'} = $PID;
		$R{'%attribs'} = $P->dataref();

		if (not $v->{'schedules'}) {
			}
		else {
			## old schedule pricing (not per variation)
			$R{'@schedules'} = [];
			push @{$R{'@schedules'}}, { 'schedule'=>'*', 'qtyprice'=>$P->fetch('zoovy:qty_price') };
			foreach my $SCHEDULEID (@{WHOLESALE::list_schedules($self->username())}) {
				my %ref = ();
				$ref{'schedule'} = $SCHEDULEID;
				$ref{'qtyprice'} = $P->fetch(sprintf('zoovy:qtyprice_%s',lc($SCHEDULEID)));
				if (not $P->has_variations('inv')) {
					## if it has variations they'll need to look in @variations
					$ref{'price'} =  $P->fetch(sprintf('zoovy:schedule_%s',lc($SCHEDULEID)));
					}
				$ref{'qtymin'} = $P->fetch(sprintf('zoovy:qtymin_%s',lc($SCHEDULEID)));
				$ref{'qtyinc'} = $P->fetch(sprintf('zoovy:qtyinc_%s',lc($SCHEDULEID)));
				push @{$R{'@schedules'}}, \%ref;
				}
			}

		if ($v->{'variations'}) {
			$R{'@variations'} = $P->fetch_pogs();
			}

		my %PIDINVSUMMARY = ();
		if ($v->{'skus'}) {
			$R{'@skus'} = [];

			my @WMS = ();
			my $INVSKUSUMMARY = {};
			my ($inv,$reserve,$loc) = ({},{},{});
			if (($v->{'inventory'}) && ($self->apiversion()<=201336)) {
				# ($inv,$reserve,$loc) = &INVENTORY::fetch_qty($self->username(),[$PID],undef,{$PID=>$P});
				($inv,$reserve) = $INV2->fetch_qty('@PIDS'=>[$PID],'%PIDS'=>{$PID=>$P});
				}
			if ($v->{'inventory'}) {
				($INVSKUSUMMARY) = $INV2->summary('@PIDS'=>[$PID],'%PIDS'=>{$PID=>$P});
				}
	
			my @SCHEDULES = ();
			if ($v->{'schedules'}) {
				@SCHEDULES = @{&WHOLESALE::list_schedules($self->username())};
				}
		
			foreach my $set (@{$P->list_skus('verify'=>1)}) {
				my $SKU = $set->[0];
				my %ROW = ( 'sku'=>$SKU );

				if ($self->apiversion()>=201336) {
					## breaks releases before 201336
					if ($SKU =~ /:/) { $ROW{'%attribs'} = $set->[1]; }		## only send %attribs on inv. products
					}	
				else {
					## versions before 201336 REQUIRE %attribs
					$ROW{'%attribs'} = $set->[1];
					}
				
				$ROW{'%pricetags'} = $P->pricetags($SKU);

				if ($v->{'schedules'}) {
					foreach my $id (@SCHEDULES) {
						my %SCHEDULE = ();
						$ROW{'@schedule_prices'} = [];
						foreach my $SCHEDULEID (@{WHOLESALE::list_schedules($self->username())}) {
							my %ref = ();
							$ref{'schedule'} = $SCHEDULEID;
							$ref{'price'} =  $P->skufetch($SKU,sprintf('zoovy:schedule_%s',lc($SCHEDULEID)));
							push @{$ROW{'@schedule_prices'}}, \%ref;
							}
						};
					}


				if ($v->{'inventory'}) {
					$PIDINVSUMMARY{'AVAILABLE'} += ($INVSKUSUMMARY->{$SKU}->{'AVAILABLE'}>0)?($INVSKUSUMMARY->{$SKU}->{'AVAILABLE'}):0;
					$PIDINVSUMMARY{'MARKETS'} += ($INVSKUSUMMARY->{$SKU}->{'MARKETS'}>0)?($INVSKUSUMMARY->{$SKU}->{'MARKETS'}):0;
					$PIDINVSUMMARY{'SALEABLE'} += ($INVSKUSUMMARY->{$SKU}->{'SALEABLE'}>0)?($INVSKUSUMMARY->{$SKU}->{'SALEABLE'}):0;
					$PIDINVSUMMARY{'ONSHELF'} += ($INVSKUSUMMARY->{$SKU}->{'ONSHELF'}>0)?($INVSKUSUMMARY->{$SKU}->{'ONSHELF'}):0;
					$ROW{'%invsummary'} = $INVSKUSUMMARY->{$SKU};
					}

				if (($v->{'inventory'}) && ($self->apiversion()<=201336)) {
					$ROW{'qty'} = int($inv->{$SKU});
					$ROW{'loc'} = sprintf("%s",$loc->{$SKU});
					}
				#elsif (($v->{'wms'}) && ($self->apiversion()>201336)) {
				#	$ROW{'@wms'} = [];
				#	if ($loc->{$SKU} eq 'WMS') {
				#		## ignore this.
				#		}
				#	elsif ($inv->{$SKU}) {
				#		push @{$ROW{'@wms'}}, { 'geo'=>"QQQ", 'loc'=>sprintf("%s",$loc->{$SKU}), 'qty'=>int($inv->{$SKU}) };
				#		}
				#	}
				push @{$R{'@skus'}}, \%ROW;
				}

			if ($v->{'inventory'}) {
				foreach my $k (keys %PIDINVSUMMARY) { $PIDINVSUMMARY{$k} = sprintf("%s",$PIDINVSUMMARY{$k}); }		## convert to a string.
				$R{'%invsummary'} = \%PIDINVSUMMARY;
				}
			}

	

		#if ($v->{'inventory'}) {
		#	my ($inv,$reserve,$loc) = &INVENTORY::fetch_qty($self->username(),[$PID],undef,{$PID=>$P});
		#	foreach my $set (@{$P->list_skus('verify'=>1)}) {
		#		my $SKU = $set->[0];
		#		my $SKUREF = $set->[1];
		#		## start by copying any SKU specific fields from %SKU
		#		$SKUREF = Storable::dclone($SKUREF);
		#		delete $SKURREF->{'zoovy:base_cost'};	# cheap hack (for now)
		#		$SKUREF->{'inv'} = $inv->{$sku};
		#		$SKUREF = $reserve->{$sku};
		#		}
		#	$R{'@inventory'} = $skuref;
		#	}

		}
	elsif ($v->{'_cmd'} eq 'adminProductCIAgentDetail') {
		my ($P) = PRODUCT->new($self->username(),$PID);
		my $prodref = $P->prodref();

		require REPRICE;
		
		my ($RP) = REPRICE->new($P); 
		$R{'@STRATEGIES'} = $RP->strategies();
		$R{'@SKUS'} = $RP->skus();
		}
	#elsif ($v->{'_cmd'} eq 'adminProductDiagnostics') {		
	#	}
	elsif ($v->{'_cmd'} eq 'adminProductDebugLog') {
		my $udbh = &DBINFO::db_user_connect($USERNAME);
		my ($qtPID) = $udbh->quote($PID);
		## future: show events
		## select * from USER_EVENTS where MID='62321' and PID='SCUBA-AS-BEIGE-BLK' order by ID;

		my @MSGS = ();
		my $pstmt = '';
		my $FILENAME = $v->{'GUID'};
		my $buffer = undef;
		my @HEAD = ();
		my @ROWS = ();
		
		if ($FILENAME eq '@AMAZON_DOCUMENT_CONTENTS') {
			## select a PID or any matching SKU of a PID 
		   ## patti is a fucking crappy ass programmer, i swear to god, this type of shit kills me.
			push @HEAD, { 'id'=>'DOCID' };
			push @HEAD, { 'id'=>'MSGID' };
			push @HEAD, { 'id'=>'FEED' };
			push @HEAD, { 'id'=>'SKU' };
			push @HEAD, { 'id'=>'CREATED_TS' };
			push @HEAD, { 'id'=>'DEBUG' };
			push @HEAD, { 'id'=>'ACK_GMT' };
			my $pstmt = "select DOCID,MSGID,FEED,SKU,CREATED_TS,DEBUG,ACK_GMT from AMAZON_DOCUMENT_CONTENTS where MID=$MID and SKU REGEXP concat('^',$qtPID,'(\\:[A-Z0-9\\#]{4,4}){0,3}\$') and CREATED_TS>date_sub(now(),interval 60 day) order by DOCID desc limit 30;";
		   print STDERR "$pstmt\n";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my $row = $sth->fetchrow_arrayref() ) {
				push @ROWS, $row;
				}
			$sth->finish();
			}
		elsif ($FILENAME eq '@SKU_LOOKUP') {
			## select a PID or any matching SKU of a PID 
			my ($TB) = &ZOOVY::resolve_lookup_tb($USERNAME,$MID);
			push @HEAD, { 'id'=>'ID' };
			push @HEAD, { 'id'=>'MID' };
			push @HEAD, { 'id'=>'PID' };
			push @HEAD, { 'id'=>'INVOPTS' };
			push @HEAD, { 'id'=>'GRP_PARENT' };
			push @HEAD, { 'id'=>'SKU' };
			push @HEAD, { 'id'=>'TITLE' };
			push @HEAD, { 'id'=>'COST' };
			push @HEAD, { 'id'=>'PRICE' };
			push @HEAD, { 'id'=>'UPC' };
			push @HEAD, { 'id'=>'MFGID' };
			push @HEAD, { 'id'=>'SUPPLIERID' };
			push @HEAD, { 'id'=>'PRODASM' };
			push @HEAD, { 'id'=>'ASSEMBLY' };
			push @HEAD, { 'id'=>'INV_AVAILABLE' };
			push @HEAD, { 'id'=>'QTY_ONSHELF' };
			push @HEAD, { 'id'=>'QTY_ONORDER' };
			push @HEAD, { 'id'=>'QTY_NEEDSHIP' };
			push @HEAD, { 'id'=>'QTY_MARKETS' };
			push @HEAD, { 'id'=>'QTY_LEGACY' };
			push @HEAD, { 'id'=>'QTY_RESERVED' };
			push @HEAD, { 'id'=>'AMZ_ASIN' };
			push @HEAD, { 'id'=>'AMZ_FEEDS_DONE' };
			push @HEAD, { 'id'=>'AMZ_FEEDS_TODO' };
			push @HEAD, { 'id'=>'AMZ_FEEDS_SENT' };
			push @HEAD, { 'id'=>'AMZ_FEEDS_WAIT' };
			push @HEAD, { 'id'=>'AMZ_FEEDS_WARN' };
			push @HEAD, { 'id'=>'AMZ_FEEDS_ERROR' };
			push @HEAD, { 'id'=>'AMZ_PRODUCTDB_GMT' };
			push @HEAD, { 'id'=>'AMZ_ERROR' };
			push @HEAD, { 'id'=>'INV_ON_SHELF' };
			push @HEAD, { 'id'=>'INV_ON_ORDER' };
			push @HEAD, { 'id'=>'INV_IS_BO' };
			push @HEAD, { 'id'=>'INV_REORDER' };
			push @HEAD, { 'id'=>'INV_IS_RSVP' };
			push @HEAD, { 'id'=>'DSS_AGENT' };
			push @HEAD, { 'id'=>'DSS_RUN' };
			push @HEAD, { 'id'=>'DSS_MOOD' };
			push @HEAD, { 'id'=>'DSS_CONFIG' };
			push @HEAD, { 'id'=>'RP_IS' };
			push @HEAD, { 'id'=>'RP_STRATEGY' };
			push @HEAD, { 'id'=>'RP_NEXTPOLL_TS' };
			push @HEAD, { 'id'=>'RP_LASTPOLL_TS' };
			push @HEAD, { 'id'=>'RP_CONFIG' };
			push @HEAD, { 'id'=>'RP_MINPRICE_I' };
			push @HEAD, { 'id'=>'RP_MINSHIP_I' };
			push @HEAD, { 'id'=>'RP_DATA' };
			push @HEAD, { 'id'=>'IS_CONTAINER' };
			push @HEAD, { 'id'=>'TS' };
			push @HEAD, { 'id'=>'DIRTY' };

			my $pstmt = "select * from $TB where MID=$MID and PID=$qtPID order by ID desc";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my $dbref = $sth->fetchrow_hashref() ) {
				my @ROW = ();
				foreach my $head (@HEAD) { push @ROW, $dbref->{ $head->{'id'} }; 	}
				push @ROWS, \@ROW;
				}
			$sth->finish();
			}
		elsif ($FILENAME eq '@SYNDICATION_QUEUED_EVENTS') {
			## select a PID or any matching SKU of a PID 
			my $pstmt = "select SKU,CREATED_GMT,PROCESSED_GMT,DST,VERB,ORIGIN_EVENT from SYNDICATION_QUEUED_EVENTS where MID=$MID and PRODUCT=$qtPID order by ID desc";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();

			push @HEAD, { 'id'=>'SKU' };
			push @HEAD, { 'id'=>'CREATED_GMT' };
			push @HEAD, { 'id'=>'PROCESSED_GMT' };
			push @HEAD, { 'id'=>'DST' };
			push @HEAD, { 'id'=>'VERB' };
			push @HEAD, { 'id'=>'ORIGIN_EVENT' };
			while ( my $dbref = $sth->fetchrow_hashref() ) {
				my @ROW = ();
				foreach my $head (@HEAD) { push @ROW, $dbref->{ $head->{'id'} }; 	}
				push @ROWS, \@ROW;
				}
			$sth->finish();
			}
		elsif ($FILENAME eq '@INVENTORY_DETAIL') {
			#my $TB = &INVENTORY::resolve_tb($USERNAME,$MID,'INVENTORY');
			my $qtPID = $udbh->quote($PID);
			my $pstmt = "select * from INVENTORY_DETAIL where MID=$MID /* $USERNAME */ and PRODUCT=$qtPID";
			print STDERR $pstmt."\n";
			push @HEAD, { 'id'=>'ID' };
			push @HEAD, { 'id'=>'UUID' };
			push @HEAD, { 'id'=>'PID' };
			push @HEAD, { 'id'=>'SKU' };
			push @HEAD, { 'id'=>'WMS_GEO' };
			push @HEAD, { 'id'=>'WMS_ZONE' };
			push @HEAD, { 'id'=>'WMS_POS' };
			push @HEAD, { 'id'=>'QTY' };
			push @HEAD, { 'id'=>'COST_I' };
			push @HEAD, { 'id'=>'NOTE' };
			push @HEAD, { 'id'=>'CONTAINER' };
			push @HEAD, { 'id'=>'ORIGIN' };
			push @HEAD, { 'id'=>'BASETYPE' };
			push @HEAD, { 'id'=>'SUPPLIER_ID' };
			push @HEAD, { 'id'=>'SUPPLIER_SKU' };
			push @HEAD, { 'id'=>'MARKET_DST' };
			push @HEAD, { 'id'=>'MARKET_REFID' };
			push @HEAD, { 'id'=>'MARKET_ENDS_TS' };
			push @HEAD, { 'id'=>'MARKET_SOLD_QTY' };
			push @HEAD, { 'id'=>'MARKET_SALE_TS' };
			push @HEAD, { 'id'=>'PREFERENCE' };
			push @HEAD, { 'id'=>'CREATED_TS' };
			push @HEAD, { 'id'=>'MODIFIED_TS' };
			push @HEAD, { 'id'=>'MODIFIED_BY' };
			push @HEAD, { 'id'=>'MODIFIED_INC' };
			push @HEAD, { 'id'=>'MODIFIED_QTY_WAS' };
			push @HEAD, { 'id'=>'VERIFY_TS' };
			push @HEAD, { 'id'=>'VERIFY_INC' };
			push @HEAD, { 'id'=>'OUR_ORDERID' };
			push @HEAD, { 'id'=>'PICK_BATCHID' };
			push @HEAD, { 'id'=>'PICK_ROUTE' };
			push @HEAD, { 'id'=>'PICK_DONE_TS' };
			push @HEAD, { 'id'=>'GRPASM_REF' };
			push @HEAD, { 'id'=>'DESCRIPTION' };
			push @HEAD, { 'id'=>'VENDOR_STATUS' };
			push @HEAD, { 'id'=>'VENDOR' };
			push @HEAD, { 'id'=>'VENDOR_ORDER_DBID' };
			push @HEAD, { 'id'=>'VENDOR_SKU' };

			$pstmt = "select * from INVENTORY_DETAIL where MID=$MID and PID=$qtPID order by ID desc";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my $dbref = $sth->fetchrow_hashref() ) {
				my @ROW = ();
				foreach my $head (@HEAD) { push @ROW, $dbref->{ $head->{'id'} }; 	}
				push @ROWS, \@ROW;
				}
			$sth->finish();
			}
		elsif ($FILENAME eq '@INVENTORY_TRANSACTIONS') {
			#my $TB = &INVENTORY::resolve_tb($USERNAME,$MID,'INVENTORY');
			my $qtPID = $udbh->quote($PID);
			my $pstmt = "select * from INVENTORY_LOG where MID=$MID /* $USERNAME */ and PID=$qtPID order by TS desc";
			print STDERR $pstmt."\n";
			push @HEAD, { 'id'=>'ID' };
			push @HEAD, { 'id'=>'TS' };
			push @HEAD, { 'id'=>'UUID' };
			push @HEAD, { 'id'=>'PID' };
			push @HEAD, { 'id'=>'SKU' };
			push @HEAD, { 'id'=>'CMD' };
			push @HEAD, { 'id'=>'QTY' };

			push @HEAD, { 'id'=>'~ORDERID' };
			push @HEAD, { 'id'=>'LUSER' };
			push @HEAD, { 'id'=>'PARAMS' };

			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my $dbref = $sth->fetchrow_hashref() ) {
				my $kv = &ZTOOLKIT::parseparams($dbref->{'PARAMS'});
				foreach my $k (keys %{$kv}) { $dbref->{"~$k"}->{$v}; }

				my @ROW = ();
				foreach my $head (@HEAD) { push @ROW, $dbref->{ $head->{'id'} }; 	}
				push @ROWS, \@ROW;
				}
			$sth->finish();
			}
		elsif ($FILENAME eq '@NAVCATS') {
			require NAVCAT;
			foreach my $prttext (@{&ZWEBSITE::list_partitions($USERNAME)}) {
				my ($prt) = split(/:/,$prttext); 
				my ($nc) = NAVCAT->new($USERNAME,PRT=>$prt);
				my $paths = $nc->paths_by_product($PID);
				push @HEAD, { 'id'=>'PATH' };
				push @HEAD, { 'id'=>'PRT' };
				foreach my $path (@${paths}) {
				 	my @ROW = ();	
					push @ROW, $path;
					push @ROW, $prttext;
					push @ROWS, \@ROW;
					}
				}
			}
		elsif ($FILENAME eq '@DIAGNOSTICS') {
			my $P = PRODUCT->new($USERNAME,$PID);
			my $SKUS = {};
		   if (defined $P) { 
		      $SKUS = $P->list_skus(); 
		      }
		   else {
		      push @MSGS, "ERROR|+Product record '$PID' is corrupt/could not be loaded or there is another reason the product object could not be created.";
		      }
   
			my %VARS = ();
			if (scalar(@{$SKUS})>0) {
				foreach my $set (@{$SKUS}) {
					my ($sku,$skuref) = @{$set};
					foreach my $k (keys %{$skuref}) {
						$VARS{"$k\~$sku"} = $skuref->{$k};
						}
					}
				}
	
		   if (defined $P) { foreach my $k (keys %{$P->prodref()}) { $VARS{$k} = $P->fetch($k); } }

			## POG checks
			foreach my $pog (@{$P->pogs()}) {
				my $ID = $pog->{'id'};
				if (not defined $pog->{'inv'}) { 
					push @MSGS, "WARNING|+POG $ID does not have inv= set implicitly. Undefined behaviors.";
					}
				}

			## append any earlier messages to the header.
			if (scalar(@MSGS)==0) {
				push @MSGS, "INFO|+no product messages generated.";
				}
			foreach my $MSG (@MSGS) {
				my ($msgref,$status) = &LISTING::MSGS::msg_to_disposition($MSG);
				push @ROWS, [ 
					$PID,	
					'MSG',
					$msgref->{'_'},
					$msgref->{'+'}
					];
				}


			push @HEAD, { 'name'=>'SKU', 'type'=>'CHR' };
			push @HEAD, { 'name'=>'ATTRIB' };
			push @HEAD, { 'name'=>'VALUE' };
			push @HEAD, { 'name'=>'warnings' };

			foreach my $skukey (sort keys %VARS) {
				next if ($skukey eq '');

				my @R = ();
				my $sku = undef;
				my $k = undef;
				if ($skukey =~ /(.*?)\~(.*?)/) { 
					## zoovy:prod_desc<sku:#010>
					$k = $1; $sku = $2;
					push @R, sprintf("%s",$sku); 
					push @R, sprintf("%s",$k);
					}
				else {
					$k = $skukey;
					push @R, $P->pid();
					push @R, sprintf("%s",$k);
					}
		
				push @R, sprintf("%s",$VARS{$skukey});

				my @WARNINGS;
				if (($k =~ /(.*?):prod_image[\d]+$/) || ($k =~ /:prod_thumb/)) {
					## REMINDER: make sure we don't match zoovy:prod_image[\d]_alt -- which can have spaces
					if (index($VARS{$skukey},' ')>=0) {
						push @WARNINGS, "attribute $skukey contains a space in the data (not valid for images)";
						}
					}
				if ($skukey =~ /[\s]+/) {
					push @WARNINGS, "attribute $skukey contains a space in the key '$skukey'.";
					}
				elsif ($skukey =~ /^[^a-z]+/) {
					push @WARNINGS, "attribute $skukey contains an invalid leading character.";
					}
		
				
				my $fieldref = $PRODUCT::FLEXEDIT::fields{$k};
				if ($k =~ /^user:/) {
					## user defined fields.
					}
				elsif (defined $fieldref) {
					## valid field, but we can still perform some global checks.
					if ($fieldref->{'type'} eq 'legacy') {		
						push @WARNINGS, "attribute $skukey is a legacy field and should probably be removed.";
						}
					if ((defined $sku) && (not $fieldref->{'sku'})) {
						push @WARNINGS, "attribute $skukey is set at the sku level, but is not considered a sku level field.";
						}
					}
				elsif (not &PRODUCT::FLEXEDIT::is_valid($k,$USERNAME)) {
					push @WARNINGS, "attribute $k is not valid and should be removed.";
					}
		
				## field specific type checks
				if (not defined $fieldref) {
					}
				elsif ($fieldref->{'type'} eq 'textbox') {
					if (not defined $fieldref->{'minlength'}) { 
						## no minimum length check
						}
					elsif ( length($VARS{$skukey}) < $fieldref->{'minlength'}) {
						push @WARNINGS, "attribute $skukey does not meet minimum length requirement of $fieldref->{'minlength'}.";
						}
		
					if (not defined $fieldref->{'maxlength'}) {}
					elsif ( length($VARS{$skukey}) > $fieldref->{'maxlength'}) {
						push @WARNINGS, "attribute $skukey is longer than the maximum length requirement of $fieldref->{'maxlength'}.";
						}
					}
		
				## check data
				if ($VARS{$skukey} =~ /^[\s]+/) {
					push @WARNINGS, "attribute $skukey contains one or more leading spaces in data.";
					}
				elsif ($VARS{$skukey} =~ /^[\t]+/) {
					push @WARNINGS, "attribute $skukey contains one or more leading TAB characters in data.";
					}
				elsif ($VARS{$skukey} =~ /[\s]+$/) {
					push @WARNINGS, "attribute $skukey contains one or more trailing spaces in data.";
					}
				elsif ($VARS{$skukey} =~ /[\t]$/) {
					push @WARNINGS, "attribute $skukey contains one or more trailing TAB characters in data.";
					}

				push @R, sprintf("%s",join("\n",@WARNINGS));
				push @ROWS, \@R;
				}
			}
		else {
			&JSONAPI::append_msg_to_response(\%R,'apperr',93429,sprintf('invalid GUID selected.'));
			}

		if (&JSONAPI::hadError(\%R)) {
			}
		elsif (defined $buffer) {
			$R{'title'} = "File $R{'GUID'}";
			$R{'MIMETYPE'} = 'text/plain';
			$R{'body'} = $buffer;
			}
		elsif (scalar(@HEAD)>0) {
			## THIS SHOULD ALWAYS FOLLOW THE SAME FORMAT AS REPORTS.
			$R{'title'} = "Report $R{'GUID'}";
			$R{'MIMETYPE'} = 'data/head+body';
			$R{'@HEAD'} = \@HEAD;
			$R{'@BODY'} = \@ROWS;
			}
		else {
			&JSONAPI::append_msg_to_response(\%R,'ise',93430,sprintf('this isnt the guid you\'re looking for, move along.'));
			}

		&DBINFO::db_user_close();
		}
	elsif ($v->{'_cmd'} eq 'adminProductListingDetail') {
		my ($P) = PRODUCT->new($self->username(),$PID);
		my ($profile) = $P->fetch('ebay:profile');

		my $epnsref = {};
		require EBAY2::PROFILE;
		($epnsref) = &EBAY2::PROFILE::fetch($USERNAME,$PRT,$profile);

		$R{'#v'} = $epnsref->{'#v'};
		if ($epnsref->{'#v'} >= 201324) {	
			require TEMPLATE::KISSTLC;
			my $elements = TEMPLATE::KISSTLC::getFlexedit($USERNAME,$profile);
			$R{'@elements'} = $elements;
			}
		else {
			$R{'@elements'} = [];
			$R{'msg'} = "Version too low, not supported.";
			}
			
		}
#	elsif ($v->{'_cmd'} eq 'adminProductBUYDetail') {
#		my ($P) = PRODUCT->new($self->username(),$PID);
#		require SYNDICATION::BUYCOM;
#
#		my @maps = &SYNDICATION::BUYCOM::fetch_dbmaps($USERNAME,detail=>1);	
#		$R{'@DBMAPS'} = \@maps;
#	
#		require SYNDICATION::BUYCOM;
#		my ($MAP) = &SYNDICATION::BUYCOM::fetch_dbmap($USERNAME, $R{'buycom/dbmap'} = $P->fetch('buycom:dbmap') );
#		
#		if (defined $MAP) {
#			my $flexfields = &SYNDICATION::BUYCOM::maptxt_to_flexedit($USERNAME,$MAP->{'MAPTXT'},$P->prodref());
#			$R{'%FLEX'} = $flexfields;
#			}
#		}
#	elsif ($v->{'_cmd'} eq 'adminProductBUYValidate') {
#		my ($P) = PRODUCT->new($self->username(),$PID);
#		my $plm = LISTING::MSGS->new($USERNAME);
#		&SYNDICATION::BUYCOM::validate(undef,$P->pid(),$P,$plm,{ 'PRT'=>$PRT, 'VALIDATION'=>1 });
#		foreach my $msg (@{$plm->msgs()}) {
#			my ($ref) = &LISTING::MSGS::msg_to_disposition($msg);
#			push @{$R{'@MSGS'}}, $ref;
#			}
#		}
	elsif ($v->{'_cmd'} eq 'adminProductAmazonDetail') {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		require AMAZON3;
		my ($P) = PRODUCT->new($self->username(),$PID);
		my $thesref = &AMAZON3::fetch_thesaurus($USERNAME);
		$R{'%thesaurus'} = $thesref;
		
		my %SKUS = ();
		## alright, now it's time to get the products which are either related (base, options,or vchildren)
		## NOTE: the line below is very bad since we can't use an index with an OR statement
		## NOTE: select * from AMAZON_PID_UPCS where (PID=$qtPID or PARENT=$qtPID) and MID=$MID /* $USERNAME */

		my $LOOKUP_TB = &ZOOVY::resolve_lookup_tb($USERNAME,$MID);
		my $RELATIONSHIPS = &AMAZON3::relationships($P);
		my @LOOKUP_SKUS = ();
		push @LOOKUP_SKUS, $P->pid();
		my %RELATIONSHIP_LOOKUP = ();
		foreach my $RELDATA (@{$RELATIONSHIPS}) {
			next if ($RELDATA->[1] eq '');
			push @LOOKUP_SKUS, $RELDATA->[1];
			$RELATIONSHIP_LOOKUP{ $RELDATA->[1] } = $RELDATA->[0];
			}

		## get the relations for each sku.
		my @DETAIL = ();
		my $pstmt = "select * from $LOOKUP_TB where MID=$MID /* $USERNAME */ and SKU in ".&DBINFO::makeset($udbh,\@LOOKUP_SKUS);
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $rowref = $sth->fetchrow_hashref() ) {
			$rowref->{'AMZ_RELATIONSHIP'} = $RELATIONSHIP_LOOKUP{ $rowref->{'SKU'} };
			if ($rowref->{'AMZ_RELATIONSHIP'} eq '') { $rowref->{'AMZ_RELATIONSHIP'} = 'PRODUCT'; }
			# $SKUS{$rowref->{'SKU'}} = $rowref;
			
			my %ROW = (
				'PID'=>$rowref->{'PID'},
				'SKU'=>$rowref->{'SKU'},
				'AMZ_RELATIONSHIP'=>$rowref->{'AMZ_RELATIONSHIP'},
				'AMZ_ERROR'=>$rowref->{'AMZ_ERROR'},	## converted into @LOG
				'AMZ_SYNC' =>'UNKNOWN|DETAIL_MISSING',
				'%IS'=>{
					'TODO'=>$rowref->{'AMZ_FEEDS_TODO'},
					'WAIT'=>$rowref->{'AMZ_FEEDS_WAIT'},
					'SENT'=>$rowref->{'AMZ_FEEDS_SENT'},
					'ERROR'=>$rowref->{'AMZ_FEEDS_ERROR'},
					'DONE'=>$rowref->{'AMZ_FEEDS_DONE'}
					}
				);
			if ($rowref->{'AMZ_ASIN'} ne '') {
				($ROW{'AMZ_UUID_TYPE'},$ROW{'AMZ_UUID'}) = ('ASIN',$rowref->{'AMZ_ASIN'});
				}
			elsif ($rowref->{'UPC'} ne '') {
				($ROW{'AMZ_UUID_TYPE'},$ROW{'AMZ_UUID'}) = ('UPC',$rowref->{'UPC'});
				}
			#elsif ($row->{'MFGID'} ne '') {				
			#	($ROW{'AMZ_UUID_TYPE'},$ROW{'AMZ_UUID'}) = ('UPC',$row->{'UPC'});
			#	}
			elsif ($rowref->{'SKU'} ne '') {
				($ROW{'AMZ_UUID_TYPE'},$ROW{'AMZ_UUID'}) = ('SKU',$rowref->{'SKU'});
				}
			push @DETAIL, \%ROW;
			}
		$sth->finish();
		$R{'@DETAIL'} = \@DETAIL;

		## find a list of errors for all those products
		#my %SKU_ERRORS = ();
		#if (scalar(@LOOKUP_SKUS)>0) {
		#	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		#	$pstmt = "select * from SYNDICATION_PID_ERRORS where DSTCODE='AMZ' and MID=$MID /* $USERNAME */ and SKU in ".&DBINFO::makeset($udbh,\@LOOKUP_SKUS)." and ARCHIVE_GMT=0 order by FEED";
		#	$sth = $udbh->prepare($pstmt);
		#	$sth->execute();
		#	while ( my $errref = $sth->fetchrow_hashref() ) {
		#		push @{$SKU_ERRORS{ $errref->{'SKU'}} }, $errref;
		#		}
		#	$sth->finish();
		#	&DBINFO::db_user_close();
		#	}
		&DBINFO::db_user_close();

		foreach my $row (@{$R{'@DETAIL'}}) {
			## don't show related items unless axed to!
			my %IS = %{$row->{'%IS'}};
			if ($IS{'DONE'} & $AMAZON3::BW{'deleted'}) {
				$row->{'AMZ_SYNC'} = 'DELETED';
				# $row->{'STATE'} = 'Deleted';
				# $row->{'MSG'} = "Amazon Ack Delete\n";
				}
			elsif ($IS{'DONE'} & $AMAZON3::BW{'not_needed'}) {
				$row->{'AMZ_SYNC'} = 'NA|NOT_NEEDED';
				# $row->{'STATE'} = '<font color="#CCCCCC">Not Sent</font>';
				# $row->{'MSG'} = "Transmission to Amazon not necessary\n";
				}
			elsif ($IS{'ERROR'}>0) { 
				$row->{'AMZ_SYNC'} = 'ERROR';
				# $row->{'STATE'} = '<font color=red>Error</font>'; 
				# $row->{'MSG'} = undef;
				}
			elsif ($IS{'TODO'}>0) {
				$row->{'AMZ_SYNC'} = 'TODO';
				# $row->{'STATE'} = '<font color=orange>Sync Pending</font>';
				# $row->{'MSG'} = undef;
				# $row->{'STATE_DETAIL'} = 'This will be included in a future feed to Amazon.'; 
				}
			elsif ($IS{'WAIT'}>0) {
				$row->{'AMZ_SYNC'} = 'WAIT';
				# $row->{'STATE'} = '<font color=green>Transmitted to Amazon</font>';
				# $row->{'MSG'} = undef;
				}
			elsif ($IS{'DONE'}>0) {
				$row->{'AMZ_SYNC'} = 'DONE';
				# $row->{'STATE'} = '<font color=blue>InSync</font>';
				# $row->{'MSG'} = undef;
				}
			else {
				$row->{'AMZ_SYNC'} = 'UNKNOWN';
				# $row->{'STATE'} = "<font color=red>Unknown</font>";
				# $row->{'MSG'} = undef;
				}

			$row->{'PROD_MODIFIED'} = ($P->fetch('zoovy:prod_modified_gmt') > $row->{'AMZ_PRODUCTDB_GMT'})?1:0;

			my @LOG = ();
			my ($tx) = TXLOG->new($row->{'AMZ_ERROR'},'detail'=>1);
			foreach my $line (@{$tx->lines()}) {
				my ($FEED,$TS,$PARAMSREF) = &TXLOG::parseline($line);
				push @LOG, { 
					ts=>$TS, feed=>$FEED, 
					type=>$PARAMSREF->{'_'}, 
					msg=>$PARAMSREF->{'+'}, 
					detail=>($PARAMSREF->{'_detail'})?1:0,  
					};
				}
			$row->{'@LOG'} = \@LOG;
			delete $row->{'AMZ_ERROR'};		## don't send this to jt!
			}
		
		
		## Amazon Shipping Overrides, merchant can set multiple overrides per PID
		## AMZ SHIPPING OVERRIDE -- TYPE
		## set on a per product basis
		## - Additive => add AMOUNT to shipping total
		## - Exclusive => use AMOUNT for shipping total
		#		foreach my $type ('','Additive','Exclusive') {
		#			my $selected = '';
		#			if ($type eq $v->{'amz:so_type'}) { $selected = ' selected'; }
		#			$html .= qq~<option $selected value="$type">$type~;
		#			}
		#	my @ship_options = 
		#		('',
		#		'Std APO/FPO PO Box',
		#		'Std APO/FPO Street Addr',
		#		'Std Alaska Hawaii PO Box',
		#		'Std Alaska Hawaii Street Addr',
		#		'Std Asia',
		#		'Std Canada',
		#		'Std Cont US PO Box',
		#		'Std Cont US Street Addr',
		#		'Std Europe',
		#		'Std Outside US, EU, CA, Asia',
		#		'Std US Prot PO Box',
		#		'Std US Prot Street Addr',
		#		'Exp APO/FPO PO Box',
		#		'Exp APO/FPO Street Addr',
		#		'Exp Alaska Hawaii PO Box',
		#		'Exp Alaska Hawaii Street Addr',
		#		'Exp Asia',
		#		'Exp Canada',
		#		'Exp Cont US PO Box',
		#		'Exp Cont US Street Addr',
		#		'Exp Europe',
		#		'Exp Outside US, EU, CA, Asia',
		#		'Exp US Prot PO Box',
		#		'Exp US Prot Street Addr ',
		#		'Second ',
		#		'Next ');
		}
	elsif ($v->{'_cmd'} eq 'adminProductAmazonValidate') {
		require SYNDICATION::AMAZON;
		my ($P) = PRODUCT->new($self->username(),$PID);
		my ($lm) = SYNDICATION::AMAZON::product_validate($USERNAME,$P);
		$R{'@MSGS'} = [];
		foreach my $msg (@{$lm->msgs()}) {
			my ($msgref,$status) = LISTING::MSGS::msg_to_disposition($msg);
			if (substr($msgref->{'+'},0,1) eq '+') { $msgref->{'+'} = substr($msgref->{'+'},1); }
			push @{$R{'@MSGS'}}, $msgref;
			}
		}
	elsif ($v->{'_cmd'} eq 'adminProductEBAYDetail') {

		require EBAY2;
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my ($eb2) = EBAY2->new($USERNAME,PRT=>$PRT);		
		if (defined $eb2) {
			my ($existing_gtc_ebay_id,$existing_gtc_ooid) = $eb2->sku_has_gtc($PID,'fast'=>1);	
			$R{'has_gtc'} = $existing_gtc_ebay_id;
			}

		my $pstmt = "select * from EBAY_LISTINGS where MID=$MID and PRODUCT=".$udbh->quote($PID)." order by ENDS_GMT";
		print STDERR "$pstmt\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $hashref = $sth->fetchrow_hashref() ) {
			my $links = '';
			## EXPIRES_GMT = ARCHIVED .. but IS_ENDED needs to be true else it's a zombie!
			next if (($hashref->{'EXPIRES_GMT'}>0) && ($hashref->{'IS_ENDED'}));
		
			## refresh
			## end
			my $ooid = $hashref->{'ID'};
			my $class = $hashref->{'CLASS'};
			my $listingid = $hashref->{'EBAY_ID'};

			if ($hashref->{'IS_ENDED'}) { 
				if (not defined $EBAY2::IS_ENDED_REASONS{$hashref->{'IS_ENDED'}}) {
					$EBAY2::IS_ENDED_REASONS{$hashref->{'IS_ENDED'}} = "Unknown Ended Reason: $hashref->{'IS_ENDED'}";
					}
				$hashref->{'_IS_ENDED'} = $EBAY2::IS_ENDED_REASONS{$hashref->{'IS_ENDED'}};
				}
	
			my $type = '';
			if ($hashref->{'CHANNEL'}==-1) { $type = 'SYNDICATED'; }

			if ($class eq '') {
				$links .= qq~**CLASS NOT SET**~;
				}
			elsif ($hashref->{'_IS_ENDED'}) {
				push @{$hashref->{'@MACROS'}}, { 'cmdtxt'=>'Archive', 'cmd'=>"EBAY-ARCHIVE-LISTING?OOID=$ooid&LISTINGID=$listingid" };
				}
			elsif ($hashref->{'EBAY_ID'}==0) {
				push @{$hashref->{'@MACROS'}}, { 'cmdtxt'=>'Archive', 'cmd'=>"EBAY-ARCHIVE-LISTING?OOID=$ooid&LISTINGID=$listingid" };
				}
			elsif ($hashref->{'CHANNEL'}==-1) {
				push @{$hashref->{'@MACROS'}}, { 'cmdtxt'=>'Refresh', 'cmd'=>"EBAY-REFRESH-SYNDICATION?OOID=$ooid&LISTINGID=$listingid" };
				push @{$hashref->{'@MACROS'}}, { 'cmdtxt'=>'End Now', 'cmd'=>"EBAY-END-SYNDICATION?OOID=$ooid&LISTINGID=$listingid&CLASS=$class" };
				}
			else {
				push @{$hashref->{'@MACROS'}}, { 'cmdtxt'=>'Refresh', 'cmd'=>"EBAY-REFRESH-$class?OOID=$ooid&LISTINGID=$listingid" };
				push @{$hashref->{'@MACROS'}}, { 'cmdtxt'=>'End Now', 'cmd'=>"EBAY-END-$class?OOID=$ooid&LISTINGID=$listingid" };
				}

			if ($hashref->{'EBAY_ID'}) {	
				$hashref->{'EBAY_LINK'} = "http://cgi.ebay.com/ws/eBayISAPI.dll?ViewItem&item=$hashref->{'EBAY_ID'}";
				}
			push @{$R{'@LISTINGS'}}, $hashref;
			}
		$sth->finish();

		&DBINFO::db_user_close();
		}
	elsif ($v->{'_cmd'} eq 'adminProductSKUDetail') {
		my ($P) = PRODUCT->new($self->username(),$PID);
		if ($P->has_variations('inv')) {
			$R{'@SKUS'} = $P->list_skus();
			}
		}
	elsif ($v->{'_cmd'} eq 'adminProductFlexEditFields') {
		#my $flexfields = &PRODUCT::FLEXEDIT::userfields($USERNAME,$P->prodref());
		#$R{'@flexfields'} = $flexfields;
		## my $html = PRODUCT::FLEXEDIT::output_html($P,$flexfields);
		}
	elsif ($v->{'_cmd'} eq 'adminProductEventList') {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select * from LISTING_EVENTS where MID=$MID /* $USERNAME */ and PRODUCT=".$udbh->quote($PID)." order by ID";
		print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		my $t = time();
		while ( my $ref = $sth->fetchrow_hashref() ) {
			push @{$R{'@EVENTS'}}, $ref;
			if (($ref->{'RESULT'} eq 'RUNNING') && ($ref->{'LOCK_GMT'}>0)) {
				$ref->{'NOTE'} = qq~STARTED: %s Target:$ref->{'TARGET_LISTINGID'}~;
				}
			elsif ($ref->{'RESULT'} eq 'PENDING') {
				if ($ref->{'LAUNCH_GMT'} < $t - 600) {
					$ref->{'NOTE'} = sprintf("IN QUEUE - OVERDUE: %s",&ZTOOLKIT::pretty_date($ref->{'LAUNCH_GMT'},2));
					}
				elsif ($ref->{'LAUNCH_GMT'} <= $t+30) {
					$ref->{'NOTE'} = sprintf("IN QUEUE: %s",&ZTOOLKIT::pretty_date($ref->{'LAUNCH_GMT'},2));
					}
				else {
					$ref->{'NOTE'} = sprintf("IN QUEUE - SCHEDULED: %s",&ZTOOLKIT::pretty_date($ref->{'LAUNCH_GMT'},2));
					}
				}
			elsif (($ref->{'RESULT'} eq 'FAIL-SOFT') || ($ref->{'RESULT'} eq 'FAIL-FATAL')) {
				$ref->{'NOTE'} = $ref->{'RESULT_ERR_SRC'}; #$ref->{'RESULT_ERR_CODE'} $ref->{'RESULT_ERR_MSG'}</td>";
				}
			elsif ($ref->{'RESULT'} eq 'SUCCESS') {
				if (($ref->{'VERB'} eq 'INSERT') && ($ref->{'TARGET_LISTINGID'}>0)) {
					if ($ref->{'TARGET'} =~ /^EBAY/) {
						$ref->{'NOTE'} = "EBAY $ref->{'TARGET_LISTINGID'}";
						$ref->{'LINK'} = "http://cgi.ebay.com/ws/eBayISAPI.dll?ViewItem&item=$ref->{'TARGET_LISTINGID'}";
						}
					else {
						$ref->{'NOTE'} = "NEW LISTING: $ref->{'TARGET_LISTINGID'}";
						}
					}
				elsif ($ref->{'TARGET_LISTINGID'}>0) {
					$ref->{'NOTE'} = "UPDATED LISTING:$ref->{'TARGET_LISTINGID'}";
					}
				elsif ($ref->{'TARGET_UUID'}>0) {
					$ref->{'NOTE'} = qq~UPDATED UUID:$ref->{'TARGET_UUID'}~;
					}
				}
			else {
				$ref->{'NOTE'} = qq~INTERNAL-ERROR-UNHANDLED-STATUS RESULT-IS:$ref->{'RESULT'}~;
				}
			}
		$sth->finish();
		&DBINFO::db_user_close();
		}
	#elsif ($v->{'_cmd'} eq 'adminProductReviewList') {
	#	require PRODUCT::REVIEWS;
   #   $R{'@REVIEWS'} = PRODUCT::REVIEWS::fetch_product_reviews($USERNAME,$PID);
   #   }
	elsif ($v->{'_cmd'} eq 'adminProductNavcatList') {
		my ($NC) = NAVCAT->new($USERNAME,PRT=>$PRT);
		$R{'@PATHS'} = $NC->paths_by_product($PID);
		}
	elsif ($v->{'_cmd'} eq 'adminProductInventoryDetail') {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my ($P) = PRODUCT->new($self->username(),$PID);

		my $HAS_WMS = 0;
		my $globalref = $self->globalref();
		if ($globalref->{'wms'} == 1) { $HAS_WMS++; }
		my $SKULIST = $P->list_skus();
	
		# my @pogs = &POGS::text_to_struct($USERNAME,$prodref->{'zoovy:pogs'},1);
		my $PID = $P->pid();
		
		my @ALLSKUS = ();
		if ($v->{'SKU'}) { 
			push @ALLSKUS, $v->{'SKU'}; 
			}
		else {
			my $ALL_SKUS_LIST = $P->list_skus('verify'=>1);
			foreach my $set (@{$ALL_SKUS_LIST}) { 
				push @ALLSKUS, $set->[0]; 
				}
			}

		$R{'@SKUS'}  = \@ALLSKUS;
		$R{'%INVENTORY'} = {};

		#my ($instockref,$reserveref,$locref) = &INVENTORY::fetch_incrementals($USERNAME,\@ALLSKUS,undef,8+16+32+64+128);
		#$R{'%LEGACY_INSTOCK'} = $instockref;
		#$R{'%LEGACY_RESERVE'} = $reserveref;
		#$R{'%LEGACY_LOCATION'} = $locref;
		#foreach my $SKU (keys %{$instockref}) {
		#	if (not defined $R{'%INVENTORY'}->{ $SKU }) { $R{'%INVENTORY'}->{ $SKU } = []; }
		#	push @{ $R{'%INVENTORY'}->{ $SKU }  }, { 
		#		'ORIGIN'=>"LEGACY", 'UUID'=>"INV1!$SKU", 
		#		'QTY'=>$instockref->{$SKU}, 'BASETYPE'=>"SIMPLE", 
		#		'NOTE'=>$locref->{$SKU} 
		#		};
		#	}

		require ZWMS;
		require LISTING::MSGS;
		
		my $pstmt = "select SKU,UUID,BASETYPE,PREFERENCE,SUPPLIER_ID,SUPPLIER_SKU,WMS_GEO,WMS_ZONE,WMS_POS,QTY,COST_I,NOTE,CONTAINER,ORIGIN,MARKET_DST,MARKET_REFID,OUR_ORDERID from INVENTORY_DETAIL where MID=$MID and PID=".$udbh->quote($PID);
		$pstmt .= " order by PREFERENCE desc";
		print STDERR "$pstmt\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		my @SKU_INVENTORY = ();
		while ( my $row = $sth->fetchrow_hashref() ) {

			next if (($row->{'BASETYPE'} eq 'DONE') && (&ZTOOLKIT::mysql_to_unixtime($row->{'MODIFIED_TS'}) < time()-(86400*3)));

			foreach my $k (keys %{$row}) {
				if (not defined $row->{$k}) {	delete $row->{$k}; }
				}
			my $SKU = $row->{'SKU'};
			$row->{'COST'} = sprintf("%.2f",$row->{'COST_I'}/100); delete $row->{'COST_I'};

			if (not defined $R{'%INVENTORY'}->{ $SKU }) { $R{'%INVENTORY'}->{ $SKU } = []; }
			push @{ $R{'%INVENTORY'}->{ $SKU } }, $row;
			}
		$sth->finish();
		&DBINFO::db_user_close();
		}

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}

	
   return(\%R);
	}










=pod

<API id="adminTaskList">
<purpose></purpose>
sort=id
class=
</API>

<API id="adminTaskCreate">
<purpose></purpose>
class=INFO|WARN|ERROR|SETUP|TODO
class=>"INFO|WARN|ERROR|SETUP|TODO",		## SETUP = setup tasks, TODO=user created.
title=>"100 character short message",
detail=>"long description",
errcode=>"AMZ#1234,EBAY#1234,",		## see %TODO::CODES below
dstcode=>"GOO", ## check SYNDICATION.pm for dstcodes
link=>"order:####-##-###|product:ABC|ticket:1234", 
		or: ticket=>$ticketid, order=>$oid, pid=>$pid,		## this is preferred because it will set other fields.
guid=>$related_private_file_guid|$bj->guid(),
priority=>1|2|3		## you don't need to set this unless you want to override 1=high,2=warn,3=error
group=>		## another way of referencing errcode.
panel=>		## the name of the panel which contains a tutorial video (for SETUP tasks)
</API>

<API id="adminTaskRemove">
<purpose></purpose>
taskid 
pid+dstcode
class+panel
class+group
class

</API>

<API id="adminTaskUpdate">
<purpose></purpose>
</API>

<API id="adminTaskDetail">
<purpose></purpose>
</API>

<API id="adminTaskComplete">
<purpose></purpose>
</API>

=cut

sub adminTask {
	my ($self,$v) = @_;

	require TODO;
	my ($T) = TODO->new($self->username(),'LUSER'=>$self->luser());
	my %R = ();
	if ($v->{'_cmd'} eq 'adminTaskList') {

		my @RESULT = ();
		foreach my $TASKREF (@{$T->list()}) {
			## filter by class e.g. class=>'SETUP'
			next if ((defined $v->{'class'}) && ($v->{'class'} ne $TASKREF->{'CLASS'}));
			my %TASK = ();
			foreach my $k (keys %{$TASKREF}) {
				$TASK{lc($k)} = $TASKREF->{$k};
				}
			push @RESULT, \%TASK;
			}

		$R{'@TASKS'} = \@RESULT;
		}
	elsif ($v->{'_cmd'} eq 'adminTaskRemove') {
		$T->delete($v->{'taskid'},%{$v});
		}
	elsif ($v->{'_cmd'} eq 'adminTaskCreate') {
		$T->add(%{$v});
		}
	elsif ($v->{'_cmd'} eq 'adminTaskUpdate') {
		$R{'rows'} = $T->update($v->{'taskid'},%{$v});
		if ($R{'rows'}==0) {
			&JSONAPI::set_error(\%R,'youerr',7480,'no rows update');
			}
		}
	elsif ($v->{'_cmd'} eq 'adminTaskComplete') {
		$T->complete($v->{'taskid'});
		}

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
	
   return(\%R);
	}




=pod

<API id="adminTicketList">
<purpose></purpose>
<input id="detail" required="1">open|all|projects|waiting</input>
<output id="@FILES"></output>
</API>

<API id="adminTicketCreate">
<purpose></purpose>
<input id="disposition"></input>
<input id="body"></input>
<input id="subject"></input>
<input id="callback"></input>
<input id="private"></input>
<input id="priority"></input>
</API>

<API id="adminTicketMacro">
<purpose></purpose>
Not finished
</API>

<API id="adminTicketDetail">
<purpose></purpose>
Not finished
</API>

<API id="adminTicketFileList">
<purpose></purpose>
</API>

<API id="adminTicketFileAttach">
<purpose></purpose>
ticketid,
uuid
</API>

<API id="adminTicketFileGet">
<purpose>download a file attached to a ticket.</purpose>
<input id="ticketid">ticket #</input>
<input optional="1" id="remote">remote stored filename obtained from @FILES[] in adminTicketFileList</input>
<input optional="1" id="orig">original (uploaded) file name obtained from @FILES[] in adminTicketFileList</input>
</API>

<API id="adminTicketFileRemove">
<purpose></purpose>
</API>


=cut

sub adminTicket {
	my ($self,$v) = @_;

	require PLUGIN::HELPDESK;
	my ($R) = PLUGIN::HELPDESK::execute($self,$v);
	if (not &JSONAPI::hadError($R)) {
		&JSONAPI::append_msg_to_response($R,'success',0);		
		}
	
   return($R);
	}



=pod

<API id="adminBlastMacroPropertyDetail">
<output id="%PRT">
</output>
</API>

<API id="adminBlastMacroPropertyUpdate">
<input id="%PRT.PHONE"></input>
<input id="%PRT.DOMAIN"></input>
<input id="%PRT.MAILADDR"></input>
<input id="%PRT.EMAIL"></input>
<input id="%PRT.LINKSYNTAX">APP|VSTORE</input>
</API>

<API id="adminBlastMacroUpdate">
<output id="@MSGS"></output>
</API>

<API id="adminBlastMacroList">
<input id="custom" default="1" optional="1">set to zero to exclude custom macros</input>
<input id="system" default="1" optional="1">set to zero to exclude system macros (note: if a CUSTOM macro has been created with the same name it will NOT appear in the system list)</input>
<output id="@MACROS">
</output>
</API>

<API id="adminBlastMacroCreate">
<input id="MSGID"></input>
</API>

<API id="adminBlastMacroUpdate">
<input id="MSGID"></input>
</API>

<API id="adminBlastMacroRemove">
<input id="MSGID"></input>
</API>

=cut

sub adminBlastMacro {
	my ($self, $v) = @_;

	my %R = ();
	require BLAST::DEFAULTS;

	my ($MID) = &ZOOVY::resolve_mid($self->username());
	my $PRT = int($self->prt());
	my ($udbh) = &DBINFO::db_user_connect($self->username());

	$v->{'MACROID'} = uc($v->{'MACROID'});
	if ($v->{'_cmd'} eq 'adminBlastMacroPropertyDetail') {
		my ($webdb) = &ZWEBSITE::fetch_website_dbref($self->username(),$self->prt());
		$R{'%PRT'} = $webdb->{'%BLAST'} || {}; 
		}
	elsif ($v->{'_cmd'} eq 'adminBlastMacroPropertyUpdate') {
		my %PRT = ();
		print STDERR Dumper($v);
		foreach my $k (keys %{$v}) { if ($k =~ /^PRT\.(.*?)$/) { $PRT{$1} = $v->{$k}; } }
		my ($webdb) = &ZWEBSITE::fetch_website_dbref($self->username(),$self->prt());
		$webdb->{'%BLAST'} = \%PRT;
		&ZWEBSITE::save_website_dbref($self->username(),$webdb,$self->prt());
		}
	elsif ($v->{'_cmd'} eq 'adminBlastMacroList') {
		my @MSGS = ();
		if (not defined $v->{'custom'}) { $v->{'custom'} = 1; }
		if (not defined $v->{'system'}) { $v->{'system'} = 1; }

		my %HAS_CUSTOM = ();
		my $pstmt = "select MACROID,TITLE,BODY,CREATED_TS,LUSER from BLAST_MACROS where MID=$MID";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $row = $sth->fetchrow_hashref() ) {
			$HAS_CUSTOM{$row->{'MACROID'}}++;
			next if (not $v->{'custom'});
			push @MSGS, $row;
			}
		$sth->finish();

		## now show the system list.
		foreach my $macroid (keys %BLAST::DEFAULTS::MACROS) {
			next if ($HAS_CUSTOM{$macroid});
			next if (not $v->{'system'});
			next if ($BLAST::DEFAULTS::DEPRECATED{$macroid});		## never show deprecated macros
			my %ROW = ();
			$ROW{'MACROID'} = $macroid;
			$ROW{'BODY'} = $BLAST::DEFAULTS::MACROS{$macroid};
			$ROW{'LUSER'} = '*system';
			push @MSGS, \%ROW;
			}

		$R{'@MACROS'} = \@MSGS;
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'MACROID')) {
		}
	elsif ($v->{'MACROID'} !~ /^%[A-Z0-9]+%$/) {
		&JSONAPI::had_error(\%R,'apperr',48822,'MACROID must be %VALUE%');
		}
	#elsif (defined $BLAST::MACRO::DEFAULTS{$v->{'MACROID'}}) {
	#	&JSONAPI::had_error(\%R,'apperr',48822,'MACROID cannot have the same name as a system macro');
	#	}
	elsif (($v->{'_cmd'} eq 'adminBlastMacroCreate') || ($v->{'_cmd'} eq 'adminBlastMacroUpdate')) {
		my %params = ();
		$params{'MID'} = $self->mid();
		$params{'MACROID'} = uc($v->{'MACROID'});
		$params{'BODY'} = $v->{'BODY'};
		$params{'PRT'} = $PRT;
		$params{'TITLE'} = $v->{'TITLE'};
		$params{'BODY'} =  $v->{'BODY'};
		$params{'*CREATED_TS'} = 'now()';
		$params{'LUSER'} = $self->luser();
		my $pstmt = sprintf("select count(*) from BLAST_MACROS where MID=%d and PRT=%d and MACROID=%s",$params{'MID'},$params{'PRT'},$udbh->quote($params{'MACROID'}));
		print STDERR "$pstmt\n";
		my ($exists) = $udbh->selectrow_array($pstmt); 

		my $pstmt =	&DBINFO::insert($udbh,'BLAST_MACROS',\%params,debug=>2,key=>['MID','MACROID','PRT'],sql=>1,verb=>($exists)?'update':'insert');
		print STDERR "$pstmt\n";
		JSONAPI::dbh_do(\%R,$udbh,$pstmt);
		}
	elsif ($v->{'_cmd'} eq 'adminBlastMacroRemove') {
		my $pstmt = "delete from BLAST_MACROS where MID=$MID and MACROID=".$udbh->quote($v->{'MACROID'});
		$udbh->do($pstmt);
		}
	&DBINFO::db_user_close();

	return(\%R);
	}



=pod

<API id="adminBlastMsgList">
<output id="@MSGS"></output>
</API>

<API id="adminBlastMsgDetail">
<input id="MSGID"></input>
<output id="%MSG"></output>
</API>

<API id="adminBlastMsgCreate">
<input id="MSGID"></input>
</API>

<API id="adminBlastMsgUpdate">
<input id="MSGID"></input>
</API>

<API id="adminBlastMsgRemove">
<input id="MSGID"></input>
</API>

<API id="adminBlastMsgSend">
<input id="FORMAT">HTML5|LEGACY</input>
<input id="MSGID">ORDER.CREATED</input>
<input id="RECIEVER">EMAIL|CUSTOMER|GCN|APNS|ADN</input>
<input id="EMAIL" optional="1" hint="only if RECIPIENT=EMAIL">user@domain.com</input>
<input id=""></input>
</API>


=cut

sub adminBlastMsg {
	my ($self, $v) = @_;

	my %R = ();
	require BLAST::DEFAULTS;

	my ($MID) = &ZOOVY::resolve_mid($self->username());
	my $PRT = int($self->prt());
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	if ($v->{'_cmd'} eq 'adminBlastMsgList') {
		
		my @MSGS = ();
		my %HAS_MSGID = ();

		my $pstmt = "select MSGID,FORMAT,SUBJECT,OBJECT,CREATED_TS,MODIFIED_TS,LUSER from SITE_EMAILS where MID=$MID and PRT=$PRT";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $row = $sth->fetchrow_hashref() ) {
			$HAS_MSGID{$row->{'MSGID'}}++;
			push @MSGS, $row;
			}
		$sth->finish();

		## load in the default messages
		foreach my $msgid (keys %BLAST::DEFAULTS::MSGS) {
			next if ($HAS_MSGID{$msgid});
			push @MSGS, {
				'MSGID'=>$msgid,
				'FORMAT'=>$BLAST::DEFAULTS::MSGS{$msgid}->{'MSGFORMAT'},
				'SUBJECT'=>$BLAST::DEFAULTS::MSGS{$msgid}->{'MSGSUBJECT'},
				'OBJECT'=>( $BLAST::DEFAULTS::MSGS{$msgid}->{'MSGOBJECT'} || 'UNKNOWN' ),
				'MODIFIED_TS'=>'0',
				'CREATED_TS'=>'0',
				};
			}
	
		if ($self->apiversion()<201403) {
			foreach my $msg (@MSGS) {
				if ($msg->{'OBJECT'} eq 'CUSTOMER') { $msg->{'OBJECT'} = 'ACCOUNT'; }
				}
			}

		$R{'@MSGS'} = \@MSGS;
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'MSGID')) {
		}
	elsif ($v->{'_cmd'} eq 'adminBlastMsgDetail') {
		my $pstmt = "select * from SITE_EMAILS where MID=$MID and PRT=$PRT and MSGID=".$udbh->quote($v->{'MSGID'});
		($R{'%MSG'}) = $udbh->selectrow_hashref($pstmt);
		
		if (defined $R{'%MSG'}) {
			## we have a custom message matching the MSGID
			$R{'%MSG'}->{'%META'} = {};
			if ($R{'%MSG'}->{'METAJSON'} ne '') { 
				$R{'%MSG'}->{'%META'} = JSON::XS->new()->decode($R{'%MSG'}->{'METAJSON'});
				}
			delete $R{'%MSG'}->{'METAJSON'};

			## THESE FIELD WERE RENAMED AS PART OF A DB ALTER!			
			#$R{'%MSG'}->{'BODY'} = $R{'%MSG'}->{'MSGBODY'}; delete $R{'%MSG'}->{'MSGBODY'};
			#$R{'%MSG'}->{'FORMAT'} = $R{'%MSG'}->{'MSGFORMAT'}; delete $R{'%MSG'}->{'MSGFORMAT'};
			#$R{'%MSG'}->{'SUBJECT'} = $R{'%MSG'}->{'MSGSUBJECT'}; delete $R{'%MSG'}->{'MSGSUBJECT'};
			#$R{'%MSG'}->{'OBJECT'} = $R{'%MSG'}->{'MSGOBJECT'}; delete $R{'%MSG'}->{'MSGOBJECT'};
			}
		elsif (defined $BLAST::DEFAULTS::MSGS{$v->{'MSGID'}}) {
			my $msgid = $v->{'MSGID'};
			$R{'%MSG'} = {
				'MSGID'=>$msgid,
				'FORMAT'=>$BLAST::DEFAULTS::MSGS{$msgid}->{'MSGFORMAT'},
				'OBJECT'=>( $BLAST::DEFAULTS::MSGS{$msgid}->{'MSGOBJECT'} || 'UNKNOWN' ),
				'SUBJECT'=>$BLAST::DEFAULTS::MSGS{$msgid}->{'MSGSUBJECT'},
				'BODY'=>$BLAST::DEFAULTS::MSGS{$msgid}->{'MSGBODY'},
				'MODIFIED_TS'=>'0',
				'CREATED_TS'=>'0',
				};			
			}
		else {
			&JSONAPI::set_error(\%R, 'youerr', 83481,sprintf("Sorry Mario, your message \"%s\" is in another castle.",$v->{'MSGID'}));			
			}

#		open F, ">/tmp/foo";
#		print F Dumper($v,\%R)."\n";
#		close F;

		if (&ZOOVY::is_true($v->{'TLC'})) {
			## interpolate %SUBS% into their tlc counterparts
			my ($BLAST) = BLAST->new($self->username(),$self->prt());
			$R{'%MSG'}->{'BODY'} = &ZTOOLKIT::interpolate( $BLAST->macros(), $R{'%MSG'}->{'BODY'} );
			$R{'%MSG'}->{'SUBJECT'} = &ZTOOLKIT::interpolate( $BLAST->macros(), $R{'%MSG'}->{'SUBJECT'} );
			$R{'%MSG'}->{'FORMAT'} = 'HTML5';
			
			}
		

		}
	elsif (($v->{'_cmd'} eq 'adminBlastMsgCreate') || ($v->{'_cmd'} eq 'adminBlastMsgUpdate')) {
		my %params = ();
		$params{'USERNAME'} = $self->username();
		$params{'MID'} = $self->mid();
		$params{'PRT'} = $self->prt();
		my $MSGID = uc($v->{'MSGID'});
		$params{'MSGID'} = $MSGID;
		$params{'OBJECT'} = $v->{'OBJECT'} || $BLAST::DEFAULTS::MSGS{$MSGID}->{'MSGOBJECT'};
		if ($params{'OBJECT'} ne '') {
			}
		elsif ($MSGID =~ /^PRINTABLE\.ORDER\./) { 
			$params{'OBJECT'} = 'ORDER'; 
			}
		elsif ($MSGID =~ /^(.*?)\./) {
			## so customer ORDER.XYZ will become OBJECT 'ORDER'
			$params{'OBJECT'} = $1;
			}
		$params{'SUBJECT'} = $v->{'SUBJECT'};
		$params{'BODY'} =  $v->{'BODY'};
		my %META = ();
		foreach my $k (keys %{$v}) {
			if ($k =~ /^\%META\.(.*?)$/) { $META{$1} = $v->{$k}; }
			}
		$params{'METAJSON'} = JSON::XS->new()->encode(\%META);
		$params{'*CREATED_TS'} = 'now()';
		$params{'*MODIFIED_TS'} = 'now()';
		$params{'LUSER'} = $self->luser();
		$params{'FORMAT'} = 'HTML';
		$params{'LANG'} = 'ENG';

		## backward compat to old fields.
      $params{'MSGFROM'} = $META{'email_from'};
      $params{'MSGBCC'} = $META{'email_bcc'};

		if ($v->{'_cmd'} eq 'adminBlastMsgCreate') {
			if (not defined $params{'BODY'}) { $params{'BODY'} = 'New Message'; }
			if (not defined $params{'SUBJECT'}) { $params{'SUBJECT'} = $MSGID; }
			}

		## messages can be sent as 'update' even if they don't really exist in the db (so we need this hack!)
		my $pstmt = "select count(*) from SITE_EMAILS where MID=".$self->mid()." and PRT=".$self->prt()." and MSGID=".$udbh->quote($params{'MSGID'})." and LANG=".$udbh->quote($params{'LANG'});
		my ($exists) = $udbh->selectrow_array($pstmt);
		my $VERB = ($exists)?'update':'insert';
	
		$pstmt =	&DBINFO::insert($udbh,'SITE_EMAILS',\%params,debug=>2,key=>['MID','PRT','MSGID','LANG'],sql=>1,verb=>$VERB);
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		}
	elsif ($v->{'_cmd'} eq 'adminBlastMsgRemove') {
		my $pstmt = "delete from SITE_EMAILS where MID=$MID and PRT=$PRT and MSGID=".$udbh->quote($v->{'MSGID'});
		$udbh->do($pstmt);
		}
	elsif ($v->{'_cmd'} eq 'adminBlastMsgSend') {
		require BLAST;
		my ($blast) = BLAST->new( $self->username(), $self->prt() );
		## my ($rcpt) = $blast->recipient('CUSTOMER',$CID,{'%GIFTCARD'=>$GCOBJ});
		my ($rcpt) = undef;
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'RECEIVER',['CUSTOMER','EMAIL','GCM','APNS'])) {
			}
		elsif ($v->{'RECEIVER'} eq 'EMAIL') {
			if (not &JSONAPI::validate_required_parameter(\%R,$v,'EMAIL')) {
				}
			elsif (not &ZTOOLKIT::validate_email($v->{'EMAIL'})) {
				&JSONAPI::set_error(\%R,'apperr',83482,'EMAIL parameter appears to be invalid');
				}
			else {
				($rcpt) = $blast->recipient('EMAIL',$v->{'EMAIL'},{});
				}
			}
		elsif ($v->{'RECEIVER'} eq 'CUSTOMER') {
			if (&JSONAPI::validate_required_parameter(\%R,$v,'CID')) {
				($rcpt) = $blast->recipient('CUSTOMER', $v->{'CID'}, {});
				}
			}
		elsif ($v->{'RECEIVER'} eq 'GCM') {
			}
		elsif ($v->{'RECEIVER'} eq 'APNS') {
			}

		if (defined $rcpt) {} 
		elsif (&JSONAPI::hadError(\%R)) {} 
		else { &JSONAPI::set_error(\%R,'iseerr',83483,'RECEIVER is invalid/unknown'); }

		if (not defined $v->{'FORMAT'}) { $v->{'FORMAT'} = 'AUTO'; }
		my $msg = undef;
		if (&JSONAPI::hadError(\%R)) {
			}
		elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'FORMAT',['AUTO','HTML5'])) {
			}
		else {
			my %objects = ();
			if ($v->{'CID'}>0) {
				my ($C) = CUSTOMER->new($self->username(),'PRT'=>$self->prt(),'CID'=>$v->{'CID'},'INIT'=>0xFF);
				$objects{'%CUSTOMER'} = $C->TO_JSON();
				}
			if ($v->{'ORDERID'} ne '') {
				my ($O2) = CART2->new_from_oid($self->username(),$v->{'ORDERID'});
				$objects{'%ORDER'} = $O2->TO_JSON();
				}

			if ($v->{'BODY'} ne '') { $objects{'BODY'} = $v->{'BODY'}; }
			if ($v->{'SUBJECT'} ne '') { $objects{'SUBJECT'} = $v->{'SUBJECT'}; }

			($msg) = $blast->msg($v->{'MSGID'},\%objects);
			}

		if (defined $msg) {} 
		elsif (&JSONAPI::hadError(\%R)) {} 
		else { &JSONAPI::set_error(\%R,'iseerr',83484,'MSG is invalid/unknown'); }

		if (defined $msg) {
			$blast->send( $rcpt, $msg );
			}

		}
	&DBINFO::db_user_close();

	return(\%R);
	}




=pod

<API id="billingTransactions">
<purpose></purpose>
</API>

<API id="billingInvoiceList">
<purpose></purpose>
</API>

<API id="billingInvoiceDetail">
<purpose></purpose>
</API>

<API id="billingPaymentMacro">
<purpose></purpose>
</API>

<API id="billingPaymentList">
<purpose></purpose>
</API>

=cut


sub billingPayment {
	my ($self,$v) = @_;

	require PLUGIN::HELPDESK;
	my ($R) = PLUGIN::HELPDESK::execute($self,$v);
	if (not &JSONAPI::hadError($R)) {
		&JSONAPI::append_msg_to_response($R,'success',0);		
		}
	
   return($R);
	}


sub billingInvoice {
	my ($self,$v) = @_;

	require PLUGIN::HELPDESK;
	my ($R) = PLUGIN::HELPDESK::execute($self,$v);
	if (not &JSONAPI::hadError($R)) {
		&JSONAPI::append_msg_to_response($R,'success',0);		
		}
	
   return($R);
	}



=pod

<API id="adminProductReviewList">
<purpose>returns a list of all reviews with a filter</purpose>
<input id="filter">ALL|UNAPPROVED|RECENT</input>
<input id="PID" optional="1">product id</input>
</API>

<API id="adminProductReviewCreate">
<purpose></purpose>
Not finished
</API>

<API id="adminProductReviewApprove">
<purpose></purpose>
<input id="RID">review id</input>
Not finished
</API>

<API id="adminProductReviewRemove">
<input id="RID">review id</input>
<purpose></purpose>
Not finished
</API>

<API id="adminProductReviewUpdate">
<input id="RID">review id</input>
<input id="CUSTOMER_NAME"></input>
<input id="LOCATION"></input>
<input id="RATING"></input>
<input id="SUBJECT"></input>
<input id="MESSAGE"></input>
<input id="BLOG_URL"></input>
<purpose></purpose>
Not finished
</API>

<API id="adminProductReviewDetail">
<input id="RID">review id</input>
<input id="PID">review id</input>
<purpose></purpose>
Not finished
</API>


=cut

sub adminProductReview {
	my ($self,$v) = @_;

	require PRODUCT::REVIEWS;
	my @MSGS = ();

	my $USERNAME = $self->username();
	my $PID = $v->{'PID'};

	my %R = ();
	if ($v->{'_cmd'} eq 'adminProductReviewList') {
		my $result = [];
		if ($v->{'filter'} eq '') {
			$result = &PRODUCT::REVIEWS::fetch_product_reviews($USERNAME,$PID,undef);
			}
		elsif ($v->{'filter'} eq 'UNAPPROVED') {
			$result = &PRODUCT::REVIEWS::fetch_product_reviews($USERNAME,$PID,-1);
			}
		else {
			&JSONAPI::set_error(\%R,'apperr',12309,'Unknown filter');
			}
		$R{'@REVIEWS'} = $result;
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'PID')) {
		}
	elsif ($v->{'_cmd'} eq 'adminProductReviewCreate') {
		if ($v->{'APPROVE'}) { $v->{'APPROVED_GMT'} = time(); }
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'PID')) {
			}
		else {
			my ($err) = &PRODUCT::REVIEWS::add_review($USERNAME,$v->{'PID'},$v);
			}
		}
	#elsif ($v->{'_cmd'} eq 'adminProductReviewDetail') {
	#	my ($RID) = int($v->{'RID'});
	#	my ($ref) = @{&PRODUCT::REVIEWS::fetch_product_reviews($USERNAME,$PID,$RID)};
	#	$R{'@REVIEWS'} = $ref;
	#	}
	elsif ($v->{'_cmd'} eq 'adminProductReviewApprove') {
		my ($RID) = int($v->{'RID'});
		&PRODUCT::REVIEWS::update_review($USERNAME,$RID,APPROVED_GMT=>time());	
		}
	elsif ($v->{'_cmd'} eq 'adminProductReviewRemove') {
		my ($RID) = int($v->{'RID'});
		&PRODUCT::REVIEWS::update_review($USERNAME,$RID,_NUKE_=>1);	
		}
	elsif ($v->{'_cmd'} eq 'adminProductReviewUpdate') {
		my ($RID) = int($v->{'RID'});
		my ($ref) = @{&PRODUCT::REVIEWS::fetch_product_reviews($USERNAME,$PID,$RID)};
		delete $ref->{'MID'};
		delete $ref->{'ID'};
		my %options = ();
		foreach my $f ('CUSTOMER_NAME','LOCATION','RATING','SUBJECT','MESSAGE','BLOG_URL') {
			$options{$f} = $v->{$f};
			}
		if ($v->{'APPROVE'}) { $options{'APPROVED_GMT'} = time(); }
		&PRODUCT::REVIEWS::update_review($USERNAME,$RID,%options);	
		push @MSGS, "SUCCESS|+Updated review $RID";
		}

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
	
   return(\%R);
	}





=pod

<API id="adminDSAgentList">
<purpose>returns a list of projects</purpose>
</API>

<API id="adminDSAgentCreate">
<purpose></purpose>
</API>

<API id="adminDSAgentRemove">
<purpose></purpose>
</API>

<API id="adminDSAgentUpdate">
<purpose></purpose>
</API>

<API id="adminDSAgentDetail">
<purpose></purpose>
</API>


=cut

sub adminDSAgent {
	my ($self,$v) = @_;

	my %R = ();

	require PROJECT;
	require WATCHER;

	my $USERNAME = $self->username();
	my $LU = $self->LU();
	my $MID = $self->mid();
	my $PRT = $self->prt();

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($gref) = $self->globalref();
	my $DST = 'AMZ';
	my ($w) = WATCHER->new($USERNAME,$DST);

#	my $VERB = uc($v->{'VERB'});
#	if ($VERB eq '') { 
#		$VERB = 'GLOBAL'; 
#		if ($gref->{'amz_merchantname'} ne '') {
#			$VERB = 'STRATEGIES';
#			}
#		}

	&DBINFO::db_user_close();
	return(\%R);
	}





=pod

<API id="adminCIEngineConfig">
<concept>CIENGINE</concept>
</API>

<API id="adminCIEngineMacro">
<concept>CIENGINE</concept>
</API>

<API id="adminCIEngineAgentList">
<concept>CIENGINE</concept>
</API>

<API id="adminCIEngineAgentCreate">
<concept>CIENGINE</concept>
<input id="NAME"></input>
<input id="GUID"></input>
<input id="SCRIPT"></input>
</API>

<API id="adminCIEngineAgentUpdate">
<concept>CIENGINE</concept>
<input id="NAME"></input>
<input id="GUID"></input>
<input id="SCRIPT"></input>
</API>

<API id="adminCIEngineAgentDetail">
<concept>CIENGINE</concept>
</API>

<API id="adminCIEngineAgentRemove">
<concept>CIENGINE</concept>
</API>

<API id="adminCIEngineLogSearch">
<concept>CIENGINE</concept>
</API>


=cut

sub adminCIEngine {
	my ($self,$v) = @_;

#create table CIENGINE_AGENTS (
#    USERNAME varchar(20) default '' not null,
#	MID integer unsigned default 0 not null,
#	GUID varchar(36) default '' not null,
#	CREATED_TS timestamp not null,
#	AGENTID varchar(20) default '' not null,
#	SCRIPT text default '' not null,
#    primary key(MID,FILENAME)
#	);

	my %R = ();
	my $USERNAME = $self->username();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	if ($v->{'_cmd'} eq 'adminCIEngineConfig') {
		
		}
	elsif ($v->{'_cmd'} eq 'adminCIEngineMacro') {

		my @CMDS = ();
		if (&JSONAPI::hadError(\%R)) {
			## shit happened!
			}
		elsif (not defined $v->{'@updates'}) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9002,'Could not find any @updates for order');
			}
		elsif (ref($v->{'@updates'}) eq 'ARRAY') {
			my $count = 0;
			foreach my $line (@{$v->{'@updates'}}) {
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					$cmdset->[1]->{'luser'} = $self->luser();
					$cmdset->[2] = $line;
					$cmdset->[3] = $count++;
					push @CMDS, $cmdset;
					}
				}
			}

		my @MSGS = ();
		my $FLAGS = '';
		if (not &JSONAPI::hadError(\%R)) {
			## Validation Phase
			foreach my $cmdset (@CMDS) {
				my ($VERB,$params,$line,$linecount) = @{$cmdset};

				}
			}
		}
	elsif ($v->{'_cmd'} eq 'adminCIEngineAgentList') {
		my @AGENTS = ();
		my ($pstmt) = "select GUID,AGENTID,
				LINE_COUNT,CREATED_TS,UPDATED_TS,REVISION,INTERFACE from 
				CIENGINE_AGENTS where MID=$MID";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $agentref = $sth->fetchrow_hashref() ) {
			push @AGENTS, $agentref;
			}
		$sth->finish();
		$R{'@AGENTS'} = \@AGENTS;
		}
	elsif (
			($v->{'_cmd'} =~ /^adminCIEngineAgent(Create|Update|Detail|Remove)$/) &&
			(not &JSONAPI::validate_required_parameter(\%R,$v,'AGENTID')) 
			){
			## all the remaining adminCIEngineAgent calls require AGENTID 
			}
	elsif (($v->{'_cmd'} eq 'adminCIEngineAgentCreate') || ($v->{'_cmd'} eq 'adminCIEngineAgentUpdate')) {
		my %db = ();
		$db{'USERNAME'} = $USERNAME;
		$db{'MID'} = $MID;
		$db{'GUID'} = $v->{'GUID'};
		$db{'AGENTID'} = $v->{'AGENTID'};
		$db{'SCRIPT'} = $v->{'SCRIPT'};
		my @LINES = split(/\n/,$db{'SCRIPT'});
		$db{'LINE_COUNT'} = scalar(@LINES);

		if (not &JSONAPI::validate_required_parameter(\%R,$v,'GUID')) {
			}
		else {
			## AutoDetect Interface
			my $INTERFACE = 0;
			my $context = JavaScript::V8::Context->new();
			$context->bind_function( init=>sub { ($INTERFACE) = @_; } );
			$context->eval($db{'SCRIPT'});
			if ($@) {
				&JSONAPI::set_error(\%R,'apierr',3704,"Script error: $@");
				$INTERFACE = '000000';
				}
			$context = undef;
			$db{'INTERFACE'} = $INTERFACE;

			if (&JSONAPI::hadError(\%R)) {
				}
			elsif ($INTERFACE == 0) {
				&JSONAPI::set_error(\%R,'apierr',3703,sprintf('Sorry - the requested interface level is either zero or could not be detected -- check the init() function'));
				}
			elsif ($INTERFACE < 201320) {
				&JSONAPI::set_error(\%R,'apierr',3702,sprintf('Sorry - the interface requested by init(%d) is too low/no longer available.',$INTERFACE));
				}
			elsif ($INTERFACE > $self->apiversion()) {
				&JSONAPI::set_error(\%R,'apierr',3701,sprintf('Sorry - the interface requested by init(%d) is too high for this system (%d).',$INTERFACE,$self->apiversion()));
				}

			}

		if (&JSONAPI::hadError(\%R)) {
			}
		elsif ($v->{'_cmd'} eq 'adminCIEngineAgentCreate') {		
			$db{'*CREATED_TS'} = 'now()';
			$db{'*UPDATED_TS'} = 'now()';
			$db{'REVISION'} = 1;
			my ($pstmt) = &DBINFO::insert($udbh,'CIENGINE_AGENTS',\%db,'verb'=>'insert','sql'=>1);
			&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
			}
		elsif ($v->{'_cmd'} eq 'adminCIEngineAgentUpdate') {
			$db{'*REVISION'} = "REVISION+1";
			$db{'*UPDATED_TS'} = 'now()';
			
			my ($pstmt) = &DBINFO::insert($udbh,'CIENGINE_AGENTS',\%db,'verb'=>'update','key'=>['GUID','AGENTID','MID'],sql=>1);
			print STDERR "$pstmt\n";
			if (&JSONAPI::dbh_do(\%R,$udbh,$pstmt)==0) {
				 &JSONAPI::set_error(\%R,'apperr',74724,'AGENTID did not exist, or something else in the database went horribly wrong.');
				}
			}
		else {
			## never reached!
			}
		}
	elsif ($v->{'_cmd'} eq 'adminCIEngineAgentDetail') {
		my ($pstmt) = "select GUID,AGENTID,SCRIPT,CREATED_TS from CIENGINE_AGENTS where MID=$MID and AGENTID=".$udbh->quote($v->{'AGENTID'});
		if (my ($agentref) = $udbh->selectrow_hashref($pstmt)) {
			%R = %{$agentref};
			}
		else {
			&JSONAPI::set_error(\%R,'apperr',74723,'AGENTID did not exist');
			}
		}
	elsif ($v->{'_cmd'} eq 'adminCIEngineAgentRemove') {
		my ($pstmt) = "delete from CIENGINE_AGENTS where MID=$MID and AGENTID=".$udbh->quote($v->{'AGENTID'});
		if (&JSONAPI::dbh_do(\%R,$udbh,$pstmt)) {
			&JSONAPI::append_msg_to_response(\%R,'success',0);				
			}
		else {
			&JSONAPI::set_error(\%R,'apperr',74723,'AGENTID did not exist');
			}
		}
	elsif ($v->{'_cmd'} eq 'adminCIEngineLogSearch') {
		}

	&DBINFO::db_user_close();
	return(\%R);
	}



=pod


<API id="adminTemplateList">
<purpose></purpose>
<input id="CONTAINERID">ebay profile or campaign id</input>
<input id="TYPE">EBAY|CPG|CIA|APP</input>
<output id="@TEMPLATES"></output>
</API>

<API id="adminTemplateInstall">
<purpose>installs a template into a container</purpose>
<input id="CONTAINERID">ebay profile or campaign id</input>
<input id="TYPE">EBAY|CPG|CIA|APP</input>
<input id="PROJECTID">optional (defaults to TEMPLATES)</input>
<input id="SUBDIR"></input>
</API>

<API id="adminTemplateCreateFrom">
<purpose>copies from a container into a template</purpose>
<input id="CONTAINERID">ebay profile or campaign id</input>
<input id="TYPE">EBAY|CPG|CIA|APP</input>
<input id="PROJECTID">optional (defaults to TEMPLATES)</input>
<input id="SUBDIR"></input>
<output id="files"># of files copied</output>
<output id="dirs"># of sub-directories copied</output>
</API>

<API id="adminTemplateDetail">
<purpose>displays the details of a TEMPLATE</purpose>
<input id="TYPE">EBAY|CPG|CIA|APP</input>
<input id="PROJECTID"></input>
<input id="SUBDIR"></input>
</API>

=cut


## adminTemplateInstall
sub adminTemplate {
	my ($self, $v) = @_;
	my %R = ();

	require TEMPLATE;

	my $USERNAME = $self->username();
	my ($TYPE) = lc($v->{'TYPE'});
	my $VERB = $v->{'_cmd'};

	my $CONTAINERID = undef;
	my $CONTAINERPATH = undef;

	if ($v->{'_cmd'} =~ /adminCampaignTemplate(.*?)$/) { 
		$TYPE = 'CPG'; 
		$VERB = "adminTemplate$1"; 

		if ($v->{'_cmd'} eq 'adminCampaignTemplateList') {
			}
		elsif (not JSONAPI::validate_required_parameter(\%R,$v,'CAMPAIGNID')) {
			}
		else {
			$CONTAINERID = $v->{'CONTAINERID'} = $v->{'CAMPAIGNID'};
			}
		}
	elsif ($v->{'_cmd'} =~ /adminEBAYTemplate(.*?)$/) { 
		$TYPE = 'EBAY'; 	
		$VERB = "adminTemplate$1"; 

		if ($v->{'_cmd'} eq 'adminEBAYTemplateList') {
			}
		elsif (not JSONAPI::validate_required_parameter(\%R,$v,'PROFILE')) {
			}
		else {
			$CONTAINERID = $v->{'CONTAINERID'} = $v->{'PROFILE'};
			}
		}
	elsif ($v->{'_cmd'} =~ /adminSiteTemplate(.*?)$/) { 
		$TYPE = 'SITE'; 	
		$VERB = "adminTemplate$1"; 

		if ($v->{'_cmd'} eq 'adminSiteTemplateList') {
			}
		elsif (not JSONAPI::validate_required_parameter(\%R,$v,'HOSTDOMAIN')) {
			}
		else {
			$CONTAINERID = $v->{'CONTAINERID'} = $v->{'HOSTDOMAIN'};
			}
		}
	elsif ($v->{'_cmd'} =~ /adminCIAgentTemplate(.*?)$/) { 
		$TYPE = 'CIA'; 	
		$VERB = "adminTemplate$1"; 
		if ($v->{'_cmd'} eq 'adminCIAgentTemplateList') {
			}
		elsif (not JSONAPI::validate_required_parameter(\%R,$v,'AGENTID')) {
			}
		else {
			$CONTAINERID = $v->{'CONTAINERID'} = $v->{'AGENTID'};
			}
		}
	elsif (JSONAPI::validate_required_parameter(\%R,$v,'TYPE',['EBAY','CPG','CIA','SITE'])) {
		$TYPE = $v->{'TYPE'};
		$CONTAINERID = $v->{'CONTAINERID'};
		}
	else {
		## hmm?? error?
		}

	if (not defined $CONTAINERID) {
		}
	elsif ($TYPE eq 'EBAY') {
		if ((length($CONTAINERID)>8) || ($CONTAINERID =~ /[^A-Z0-9]/)) {
			&JSONAPI::set_error(\%R,'youerr',9319,sprintf("Invalid Profile: %s (8 character max - no spaces)",$CONTAINERID));
			}
		else {
			$CONTAINERPATH = &ZOOVY::resolve_userpath($self->username()).'/IMAGES/_ebay/'.$CONTAINERID;
			}
		}
	elsif ($TYPE eq 'CPG') {
		$CONTAINERID = uc($CONTAINERID);
		if ((length($CONTAINERID)>20) || ($CONTAINERID =~ /[^A-Z0-9\_\-]/)) {
			&JSONAPI::set_error(\%R,'youerr',9320,sprintf("Invalid Campaign: %s (20 character max - no spaces)",$CONTAINERID));
			}
		else {
			$CONTAINERPATH = &ZOOVY::resolve_userpath($self->username()).'/IMAGES/_campaigns/'.$CONTAINERID;
			}
		}
	elsif ($TYPE eq 'CIA') {
		$CONTAINERID = uc($CONTAINERID);
		if ((length($CONTAINERID)>10) || ($CONTAINERID =~ /[^A-Z0-9\_\-]/)) {
			&JSONAPI::set_error(\%R,'youerr',9321,sprintf("Invalid Agent: %s (10 character max - no spaces)",$CONTAINERID));
			}
		else {
			$CONTAINERPATH = &ZOOVY::resolve_userpath($self->username()).'/AGENTS/'.$CONTAINERID;
			}
		}
	elsif ($TYPE eq 'SITE') {
		$CONTAINERID = lc($CONTAINERID);
		if ((length($CONTAINERID)>75) || ($CONTAINERID =~ /[^a-z0-9\-\.]/)) {
			&JSONAPI::set_error(\%R,'youerr',9322,sprintf("Invalid Site Domain: %s (75 character max - no spaces)",$CONTAINERID));
			}
		else {
			$CONTAINERPATH = &ZOOVY::resolve_userpath($self->username()).'/DOMAINS/'.$CONTAINERID;
			}
		}

	if ($VERB eq 'adminTemplateCreateFrom') {
		## a good, sane location to copy templates to
		if ($v->{'PROJECTID'} eq '') { $v->{'PROJECTID'} = 'TEMPLATES'; }
		}

	my $BASEURL = undef;
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (($TYPE ne 'EBAY') && ($TYPE ne 'CPG') && ($TYPE ne 'SITE')) {
		&JSONAPI::set_error(\%R,'youerr',9320,'Invalid or Unknown Template Type');
		}
	elsif ($VERB eq 'adminTemplateList') {
		$R{'@TEMPLATES'} = TEMPLATE::list($USERNAME,$TYPE);
		}
   elsif (not JSONAPI::validate_required_parameter(\%R,$v,'PROJECTID')) {
		}
	elsif (not JSONAPI::validate_required_parameter(\%R,$v,'SUBDIR')) {
		}
	elsif ($VERB eq 'adminTemplateInstall') {
		if (not JSONAPI::validate_required_parameter(\%R,$v,'CONTAINERID')) {
			}
		elsif ($TYPE eq 'EBAY') {
			require EBAY2::PROFILE;
			$BASEURL = EBAY2::PROFILE::baseurl($self->username(),$self->sdomain(),$CONTAINERID);
			}
		elsif ($TYPE eq 'CPG') {
			require CAMPAIGN;
			$BASEURL = CAMPAIGN::baseurl($self->username(),$self->sdomain(),$CONTAINERID);
			}
		elsif ($TYPE eq 'CIA') {
			$BASEURL = undef;
			}
		elsif ($TYPE eq 'SITE') {
			$BASEURL = $self->sdomain();
			}

		my ($T) = undef;
		if (&JSONAPI::hadError(\%R)) {
			}
		elsif ((not defined $CONTAINERID) || ($CONTAINERID eq '')) {
			&JSONAPI::set_error(\%R,'iseerr',9319,sprintf("Project:%s Template:%s no container specified.",$v->{'PROJECTID'},$v->{'SUBDIR'}));
			}
		elsif (not (($T) = TEMPLATE->new($USERNAME,$TYPE,$v->{'PROJECTID'},$v->{'SUBDIR'})) ) {
			&JSONAPI::set_error(\%R,'iseerr',9320,sprintf("Project:%s Template:%s object could not be created.",$v->{'PROJECTID'},$v->{'SUBDIR'}));
			}
		elsif (not $T->exists()) {
			&JSONAPI::set_error(\%R,'apierr',9321,sprintf("Project:%s Template:%s does not exist",$v->{'PROJECTID'},$v->{'SUBDIR'}));
			}
		elsif ( $T->install($CONTAINERID,'origin'=>sprintf("%s:%s",$T->projectid(),$T->subdir()),'base'=>$BASEURL,'luser'=>$self->luser(),'api'=>$self->apiversion()) ) {
			&JSONAPI::append_msg_to_response(\%R,'success',0);	
			}
		else {
			&JSONAPI::set_error(\%R,'iseerr',9322,sprintf("Project:%s Template:%s copy to Dest:%s was not completed",$v->{'PROJECTID'},$v->{'SUBDIR'},$CONTAINERID));
			}
		}
	elsif ($VERB eq 'adminTemplateCreateFrom') {
		my ($P) = PROJECT->new($USERNAME,'UUID'=>"TEMPLATES");
		if ((not defined $P) || ($P->id() == 0)) {
			$P = PROJECT->create($USERNAME,"$USERNAME Templates",UUID=>'TEMPLATES','TYPE'=>'TEMPLATE');
			}

		my $SUBDIR = lc($v->{'SUBDIR'});
		my $PROJECTDIR = $P->dir();
		# mkdir( $PROJECTDIR = "$PROJECTDIR/templates" );
		mkdir( $PROJECTDIR = sprintf("$PROJECTDIR/%s",lc($TYPE)) );
		mkdir( $PROJECTDIR = sprintf("$PROJECTDIR/%s",$SUBDIR) );

		## CONTAINERID is the source!	
		require File::Copy::Recursive;
		$File::Copy::Recursive::CPRFComp = 1;
		my ($num_of_files_and_dirs,$num_of_dirs,$depth_traversed) = File::Copy::Recursive::dircopy( "$CONTAINERPATH/*", $PROJECTDIR );
	
		$R{'files'} = $num_of_files_and_dirs - $num_of_dirs;
		$R{'dirs'} = $num_of_dirs;

		if ($R{'files'}>0) {
			my ($T) = TEMPLATE::create($USERNAME,$TYPE,'TEMPLATES',$SUBDIR);
			}
		}
	elsif ($VERB eq 'adminTemplateDetail') {
		my $T = undef;
		if (not (($T) = TEMPLATE->new($USERNAME,$TYPE,$v->{'PROJECTID'},$v->{'SUBDIR'}) )) {
			&JSONAPI::set_error(\%R,'iseerr',9320,sprintf("Project:%s Template:%s object could not be created.",$v->{'PROJECTID'},$v->{'SUBDIR'}));
			}
		else {
			$R{'%TEMPLATE'} = $T;
			}
		}

	return(\%R);
	}




=pod





=cut


sub adminFile {
	my ($self, $v) = @_;
	my %R = ();

	require TEMPLATE;

	my $USERNAME = $self->username();
	my ($TYPE) = lc($v->{'TYPE'});
	my $ID = undef;
	my $VERB = $v->{'_cmd'};
	my $dir = undef;
	if ($v->{'_cmd'} =~ /adminCampaign(.*?)$/) { 
		$TYPE = 'CPG'; 
		$VERB = "admin$1"; 

		$ID = $v->{'CAMPAIGNID'};
		require CAMPAIGN;
		if (not JSONAPI::validate_required_parameter(\%R,$v,'CAMPAIGNID')) {
			}
		else {
			$dir = CAMPAIGN::campaigndir($USERNAME,$v->{'CAMPAIGNID'});
			}
		}
	elsif ($v->{'_cmd'} =~ /adminEBAYProfile(.*?)$/) { 
		$TYPE = 'EBAY'; 	
		$VERB = "admin$1"; 
		$ID = $v->{'PROFILE'};

		require EBAY2::PROFILE;
		if (not JSONAPI::validate_required_parameter(\%R,$v,'PROFILE')) {
			}
		else {
			$dir = EBAY2::PROFILE::profiledir($USERNAME,$v->{'PROFILE'});
			}
		}
	elsif ($v->{'_cmd'} =~ /adminCIAgent(.*?)$/) { 
		$TYPE = 'CIA'; 	
		$VERB = "admin$1"; 
		$ID = $v->{'AGENT'};
		if (not JSONAPI::validate_required_parameter(\%R,$v,'AGENT')) {
			}
		else {
			# $dir = EBAY2::PROFILE::profiledir($USERNAME,$v->{'AGENT'});
			}
		}
	elsif ($v->{'_cmd'} =~ /adminSite(.*?)$/) { 
		$TYPE = 'SITE'; 	
		$VERB = "admin$1"; 
		$ID = $v->{'SITE'};
		if (not JSONAPI::validate_required_parameter(\%R,$v,'DOMAIN')) {
			}
		else {
			$dir = PROJECT::projectdir($USERNAME,lc($v->{'DOMAIN'}));
			# $dir = EBAY2::PROFILE::profiledir($USERNAME,$v->{'DOMAIN'});
			}
		}
	else {
		&JSONAPI::set_error(\%R,'iseerr',9387,"invalid type .. calling parameters");
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'_cmd'} eq 'adminEBAYProfileZipDownload') {
		## adminEBAYProfileZipDownload generates it's own filename
		$R{'FILENAME'} = sprintf("%s-%s-%s.zip",$USERNAME,$TYPE,$ID);
		}
	elsif ($v->{'_cmd'} eq 'adminCampaignZipDownload') {
		## adminCampaignDownload generates it's own filename
		$R{'FILENAME'} = sprintf("%s-%s-%s.zip",$USERNAME,$TYPE,$ID);
		}
	elsif ($v->{'_cmd'} eq 'adminSiteZipDownload') {
		## adminSiteDownload generates it's own filename
		$R{'FILENAME'} = sprintf("%s-%s-%s.zip",$USERNAME,$TYPE,$ID);
		}
	elsif ($v->{'_cmd'} eq 'adminCIAgentZipDownload') {
		## adminCIAgentDownload generates it's own filename
		$R{'FILENAME'} = sprintf("%s-%s-%s.zip",$USERNAME,$TYPE,$ID);
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'FILENAME')) {
		}
	elsif ($v->{'FILENAME'} =~ /([^A-Za-z0-9\.\-\_]+)/) {
		&JSONAPI::set_error(\%R,'apperr',9390,"Invalid characters in filename '$v->{'FILENAME'}' the character '$1' is not allowed");
		}
	elsif ($v->{'FILENAME'} =~ /\.\./) {
		&JSONAPI::set_error(\%R,'apperr',9391,"Invalid characters in filename .. is not allowed");
		}
	elsif (! -d $dir) {
		&JSONAPI::set_error(\%R,'iseerr',9389,"Folder $dir does not exist");
		}
	elsif ($VERB eq 'adminFileUpload') {
		## It's okay if the file doesn't exist on upload
		}
	elsif (! -f sprintf("$dir/%s",$v->{'FILENAME'})) {
		&JSONAPI::set_error(\%R,'iseerr',9388,"File does not exist");
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($VERB eq 'adminFileContents') {
		## adminFileContents
		$R{'body'} = join('',File::Slurp::read_file(sprintf("$dir/%s",$v->{'FILENAME'}),'array_ref'=>0));
		$R{'FILENAME'} = $v->{'FILENAME'};

		my ($mime_type, $encoding) = MIME::Types::by_suffix($R{'FILENAME'});
		$R{'MIMETYPE'} = 'application/unknown';
		if ($mime_type eq '') {
			## NEED MORE?? 
			MIME::Types::import_mime_types("/httpd/conf/mime.types");
			($mime_type, $encoding) = MIME::Types::by_suffix($R{'FILENAME'});
			}
		if ($mime_type ne '') {
			$R{'MIMETYPE'} = "$mime_type";
			}
				
		if ((defined $v->{'base64'}) && ($v->{'base64'})) {
			$R{'body'} = MIME::Base64::encode_base64($R{'body'},'');
			}
		}
	elsif ($VERB eq 'adminFileSave') {
		#print STDERR sprintf("FILE: $dir/%s\n",$v->{'FILENAME'});
		#print STDERR "BODY: $v->{'body'}\n";
		eval {
			if ($v->{'FILENAME'} =~ /\.(txt|html|csv|json)$/) {
				File::Slurp::write_file(sprintf("$dir/%s",$v->{'FILENAME'}),{binmode => ':utf8', buf_ref => \$v->{'body'} });
				}
			else {
				## don't set utf8 flag on images, or other binary files.
				File::Slurp::write_file(sprintf("$dir/%s",$v->{'FILENAME'}),{binmode => ':raw', buf_ref => \$v->{'body'} });
				}
			chmod 0666, sprintf("$dir/%s",$v->{'FILENAME'});
			};
		if ($@) {
			&JSONAPI::set_error(\%R,'apierr',9379,sprintf('adminFileSave write file error [%s]',$@));
			}
		}
	elsif ($VERB eq 'adminFileUpload') {
		my $DATA = undef;
		if (defined $v->{'base64'}) {
			$DATA = MIME::Base64::decode_base64($v->{'base64'});		
			if ($DATA ne '') {
				## base64 decode success
				}
			elsif ($v->{'base64'} eq '') {
				&JSONAPI::set_error(\%R,'apperr',9370,'adminFileUpload base64 parameter was specified as blank');
				}
			else {
				&JSONAPI::set_error(\%R,'iseerr',9371,'adminFileUpload could not decode base64 payload');
				}
			}
		elsif (defined $v->{'fileguid'}) {
			my ($pfu) = PLUGIN::FILEUPLOAD->new($self->username());
			$DATA = $pfu->fetch_file($v->{'fileguid'});
			if ($DATA ne '') {
				## fileguid retrieve decode success
				}
			elsif ($v->{'fileguid'} eq '') {
				# 1FACD566-343A-11E2-9979-63493A9CF7B1
				&JSONAPI::set_error(\%R,'apperr',9372,'adminFileUpload fileguid parameter was specified as blank');
				}
			else {
				&JSONAPI::set_error(\%R,'iseerr',9373,sprintf('adminFileUpload not locate file from fileguid %s',$v->{'fileguid'}));
				}			
			}
		else {
			&JSONAPI::set_error(\%R,'iseerr',9374,'adminFileUpload received incomplete parameters');
			}

		if (not defined $DATA) {
			&JSONAPI::set_error(\%R,'youerr',9371,'adminFileUpload file was empty / no files found');
			}
		elsif ($v->{'FILENAME'} =~ /\.[Zz][Ii][Pp]$/) {
			mkdir($dir);
			chmod 0777, $dir;
			my $SH = new IO::String($DATA);
			my ($zip) = Archive::Zip->new();
			$zip->readFromFileHandle($SH);
			my @names = $zip->memberNames();
			my $file_count = 0;
			my @FILES = ();
			foreach my $m (@names) {
				my $contents = $zip->contents($m);
				## NOTE: dont do binmode:utf8, if there is utf8 in the file then raw will handle it properly
				File::Slurp::write_file(sprintf("$dir/%s",$m),{binmode => ':raw', buf_ref => \$contents });
				push @FILES, $m;
				}
			$R{'@FILES'} = \@FILES;
			if (scalar(@FILES)==0) {
				&JSONAPI::set_error(\%R,'youerr',9375,'adminFileUpload file was empty / no files found');
				}
			}
		else {
			my $SH = new IO::String($DATA);
			## NOTE: dont do binmode:utf8, if there is utf8 in the file then raw will handle it properly
			print STDERR sprintf("FILE: $dir/%s\n",$v->{'FILENAME'});
			File::Slurp::write_file(sprintf("$dir/%s",$v->{'FILENAME'}),{binmode => ':raw', buf_ref => \$DATA });
			chmod 0666, sprintf("$dir/%s",$v->{'FILENAME'});
			}
		}
	elsif ($VERB eq 'adminZipDownload') {
		my $DATA = '';
		my $SH = new IO::Scalar \$DATA;
		my $zip = Archive::Zip->new();		
		$zip->addTree("$dir");
		$R{'MIMETYPE'} = 'application/x-zip';
		if ($zip->writeToFileHandle($SH) != $Archive::Zip::AZ_OK) {
			&JSONAPI::set_error(\%R,'iseerr',9360,'adminFileUpload could not create zip file');
			}
		else {
			$R{'body'} =  MIME::Base64::encode_base64($DATA,'');
			}
		}

	return(\%R);
	}













=pod

<API id="adminCampaignDetail">
<purpose>returns a campaign object in %CAMPAIGN</purpose>
<input id="CAMPAIGNID"></input>
<output id="%CAMPAIGN"></output>
</API>

<API id="adminCampaignAvailableCoupons">
<purpose>a campaign can be associated with a coupon</purpose>
<output id="@COUPONS"></output>
</API>

<API id="adminCampaignCreate">
<purpose>Creates a new campaign</purpose>
<input id="CAMPAIGNID"></input>
<input id="TITLE"></input>
<input id="SEND_EMAIL">1|0</input>
<input id="SEND_APPLEIOS">1|0</input>
<input id="SEND_ANDROID">1|0</input>
<input id="SEND_FACEBOOK">1|0</input>
<input id="SEND_TWITTER">1|0</input>
<input id="SEND_SMS">1|0</input>
<input id="QUEUEMODE">FRONT|BACK|OVERWRITE</input>
<input id="EXPIRES">YYYYMMDD</input>
<input id="COUPON">CODE</input>
</API>

<API id="adminCampaignUpdate">
<purpose>see adminCampaignCreate for parameters</purpose>
<input id="CPG">campaign id#</input>
</API>

<API id="adminCampaignRemove">
<input id="CAMPAIGNID">campaign id#</input>
</API>

<API id="adminCampaignMacro">
<purpose></purpose>
<input id="CPG"></input>
<input id="@updates">
* CPGCOPY
* CPGTEST?
* CPGSTART?STARTTS=timestamp
* CPGSTOP?
* SUBADD?email=
* SUBDEL?email=
* 
</input>

</API>

<API id="adminCampaign">
<purpose></purpose>
</API>

<API id="adminCampaign">
<purpose></purpose>
</API>

=cut

sub adminCampaign {
	my ($self,$v) = @_;

	require CAMPAIGN;
	require CUSTOMER;
	require LUSER;

	my %R = ();
	my $LU = $self->LU();
	my $USERNAME = $self->username();
	my $MID = $self->mid();
	my $PRT = $self->prt();

	my @MSGS = ();
	my $udbh = &DBINFO::db_user_connect($USERNAME);

	if ($v->{'_cmd'} eq 'adminCampaignList') {
		$R{'@CAMPAIGNS'} = &CAMPAIGN::list($self->username(),'PRT'=>$self->prt());
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'CAMPAIGNID')) {
		}
	elsif ($v->{'CAMPAIGNID'} =~ /[^A-Z0-9\_\-]+/) {
		&JSONAPI::set_error(\%R, 'apperr', 4960,sprintf('Campaign %s contains invalid character \'%s\'',$v->{'CAMPAIGNID'},$1));
		}
	elsif ($v->{'_cmd'} eq 'adminCampaignStart') {
		my ($CPG) = CAMPAIGN->new($self->username(),$self->prt(),$v->{'CAMPAIGNID'});
		my $RESULTS = $CPG->start(%{$v});
		}
	elsif ($v->{'_cmd'} eq 'adminCampaignTest') {
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'RECIPIENTS')) {
			}
		else {
			my ($CPG) = CAMPAIGN->new($self->username(),$self->prt(),$v->{'CAMPAIGNID'});
			my $LM = $CPG->test(%{$v});
			
			$R{'@LM'} = $LM;

			foreach my $msg (@{$LM->msgs()}) {
				my ($result,$status) = LISTING::MSGS::msg_to_disposition($msg);
				if (($status eq 'ERROR') || ($status eq 'FATAL') || ($status eq 'ISE')) {
					&JSONAPI::append_msg_to_response(\%R,'iseerr',4200,$result->{'+'});
					}
				elsif (($status eq 'INFO') || ($status eq 'DEBUG')) {
					## &JSONAPI::append_msg_to_response(\%R,'success',0,$result->{'+'});
					}
				elsif ($status eq 'SENT') {
					&JSONAPI::append_msg_to_response(\%R,'success',4200,$result->{'+'});
					}
				elsif ($status eq 'FAIL') {
					&JSONAPI::append_msg_to_response(\%R,'apierr',4200,$result->{'+'});
					}
				elsif ($status eq 'SUCCESS') {
					&JSONAPI::append_msg_to_response(\%R,'success',0,sprintf('CID #%d (%s)',$result->{'CID'},$result->{'_'}));
					}
				elsif ($status eq 'STOP') {
					&JSONAPI::append_msg_to_response(\%R,'youerr',4200,sprintf('CID #%d NOT sent (%s:%s)',$result->{'CID'},$result->{'_'},$result->{'+'}));
					}
				else {
					&JSONAPI::append_msg_to_response(\%R,'fileerr',4200,sprintf('CID #%d NOT sent (%s:%s)',$result->{'CID'},$result->{'_'},$result->{'+'}));
					}
				}
			}
		}
	elsif ($v->{'_cmd'} eq 'adminCampaignDetail') {
		my ($CPG) = CAMPAIGN->new($self->username(),$self->prt(),$v->{'CAMPAIGNID'});
		if (not defined $CPG) {
			&JSONAPI::set_error(\%R, 'apperr', 4961,sprintf('Campaign with campaignid %s does not exist',$v->{'CAMPAIGNID'}));
			}
		else {
			$R{'%CAMPAIGN'} = $CPG;
			}
		}
	elsif ($v->{'_cmd'} eq 'adminCampaignRemove') {
		my ($CPG) = CAMPAIGN->new($self->username(),$self->prt(),$v->{'CAMPAIGNID'});
		if (not defined $CPG) {
			&JSONAPI::set_error(\%R, 'apperr', 4959,sprintf('Campaign with campaignid %s does not exist',$v->{'CAMPAIGNID'}));
			}
		else {
			$CPG->nuke();
			}
		}
	elsif ($v->{'_cmd'} eq 'adminCampaignAvailableCoupons') {
		## COUPONS
		my @COUPONS = ();
		require CART::COUPON;
		my $results = CART::COUPON::list($self->webdb());
		foreach my $ref (@{$results}) {
			$ref->{'coupon'} = $ref->{'code'};  delete $ref->{'code'};
			next if ($ref->{'disabled'}>0);
			next if ($ref->{'expires_gmt'}<$^T);
			push @COUPONS, $ref;
  			}
		$R{'@COUPONS'} = \@COUPONS;
		}
	elsif (($v->{'_cmd'} eq 'adminCampaignCreate') || ($v->{'_cmd'} eq 'adminCampaignUpdate')) {
		my ($CPG) = CAMPAIGN->new($self->username(),$self->prt(),$v->{'CAMPAIGNID'});
		foreach my $k (@CAMPAIGN::KEYS) {
			if (defined $v->{$k}) { $CPG->set($k,$v->{$k}); }
			}
		$CPG->save();
		$R{'%CAMPAIGN'} = $CPG;
		
		}
	elsif ($v->{'_cmd'} eq 'adminCampaignConfigDetail') {
		my ($webdb) = $self->webdb();
		}
	elsif ($v->{'_cmd'} eq 'adminCampaignMacro') {
		my @CMDS = ();
		if (&JSONAPI::hadError(\%R)) {
			## shit happened!
			}
		elsif (not defined $v->{'@updates'}) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9002,'Could not find any @updates for order');
			}
		elsif (ref($v->{'@updates'}) eq 'ARRAY') {
			my $count = 0;
			foreach my $line (@{$v->{'@updates'}}) {
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					$cmdset->[1]->{'luser'} = $self->luser();
					$cmdset->[2] = $line;
					$cmdset->[3] = $count++;
					push @CMDS, $cmdset;
					}
				}
			}


		my $CPGID = sprintf("%s",$v->{'CAMPAIGNID'});
		$R{'CPGID'} = $CPGID;

		foreach my $CMDSET (@CMDS) {
			my ($VERB,$params) = @{$CMDSET};
			## push @MSGS, "DEBUG|+Did $VERB";

			if($VERB eq "CPGNUKE"){
				my $pstmt = "delete from CAMPAIGNS where MID=$MID and CAMPAIGNID=".$udbh->quote($CPGID);
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
				push @MSGS, "SUCCESS|+Deleted Campaign $CPGID";
				$LU->log('UTILITIES.NEWSLETTER',"Deleted Campaign $CPGID","SAVE");
				}
			elsif ($VERB eq "CPGCOPY") {
				my $PREVIOUS_ID = $CPGID;
				my $pstmt = "select * from CAMPAIGNS where CAMPAIGNID=".$udbh->quote($PREVIOUS_ID)." and MID=$MID /* $USERNAME */";
				my $sth = $udbh->prepare($pstmt);
				$sth->execute();
				my ($CREF) = $sth->fetchrow_hashref();
				$sth->finish;

				$CPGID = $CREF->{'CAMPAIGNID'} = time();
				$CREF->{'STATUS'} = 'PENDING';

				$CREF->{'STAT_QUEUED'} = 0;
				$CREF->{'STAT_SENT'} = 0;
				$CREF->{'STAT_VIEWED'} = 0;
				$CREF->{'STAT_OPENED'} = 0;
				$CREF->{'STAT_BOUNCED'} = 0;
				$CREF->{'STAT_CLICKED'} = 0;
				$CREF->{'STAT_PURCHASED'} = 0;
				$CREF->{'STAT_TOTAL_SALES'} = 0;
				$CREF->{'STAT_UNSUBSCRIBED'} = 0;
				$pstmt = &DBINFO::insert($udbh,'CAMPAIGNS',$CREF,debug=>2);
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);

				if ($CPGID ne '') {
					push @MSGS, "SUCCESS|+Created campaign $CPGID from campaign $PREVIOUS_ID";
					}	
				
				}	
			elsif ($VERB eq "CPGSTART"){
				# format SEND_DATE to GMT format

				if (not &CAMPAIGN::exists($USERNAME,$CPGID)) {
					push @MSGS, "WARN|+Campaign $CPGID was not found";
					}
				else {
			   	## The GMT bit is important here or else it'll assume PST/PDT
			 		## only update PENDING CAMPAIGNS
					my ($CPG) = CAMPAIGN->new($USERNAME,$PRT,$CPGID);
					$R{'*CPG'} = $CPG;

					my ($STARTTIME) = $CPG->property('STARTTIME');	
					my $START_GMT = &ZTOOLKIT::mysql_to_unixtime($STARTTIME);

				  	my $pstmt = "update CAMPAIGNS set STATUS='WAITING' where MID=$MID and CAMPAIGNID=".$udbh->quote($CPGID);
				 	print STDERR $pstmt."\n";
				  	my $rows = &JSONAPI::dbh_do(\%R,$udbh,$pstmt);
					$LU->log('UTILITIES.NEWSLETTER',"Approved Campaign $CPGID","SAVE");
				  	if ($rows == 0) {
						push @MSGS, "ERROR|+Campaign $CPGID failed to start";
						}
					elsif ($START_GMT > time()+3600) {
						## queued in future
						push @MSGS, "SUCCESS|+Queued for future $STARTTIME";
						}
					else {
						## send immediate.
						require BATCHJOB;
						my ($bj) = BATCHJOB->create($USERNAME,PRT=>$CPG->prt(),EXEC=>sprintf("CAMPAIGN/%s",$CPGID));
						push @MSGS, sprintf("SUCCESS|+Queued for immediate -- jobid: %d",$bj->id());
						}

#					elsif ($CREF->{'STATUS'} eq 'APPROVED') {
#						push @MSGS, "WARN|+Your Campaign has already been APPROVED.";
#						}
#					else {
#						push @MSGS, "ISE|+Internal error campaign status:$CREF->{'STATUS'}";
#						$VERB = 'CAMPAIGN-APPROVE';
#						}
			   	}
				}
			#elsif ($VERB eq "CPGSTOP"){
			#	## Move CAMPAIGN back to PENDING
			#	my $pstmt = "update CAMPAIGNS set STATUS='PENDING' where MID=$MID and STATUS in ('PENDING','APPROVED') and CAMPAIGNID=".$udbh->quote($CPGID);
			#	my $rv = &JSONAPI::dbh_do(\%R,$udbh,$pstmt);
			#	if ($rv == 1) {
			#		$pstmt = "delete from CAMPAIGN_RECIPIENTS where CPG=".int($CPGID);
			#		&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
			#		$LU->log('UTILITIES.NEWSLETTER',"Stopped Campaign $CPG","SAVE");
			#		push @MSGS, "SUCCESS|+Stopped Campaign: $CPG";
			#		}
			#	else {
			#		push @MSGS, "ERROR|+Could not stop campaign: $CPG";
			#		}
			#	}
			#elsif (($VERB eq 'SUBADD') || ($VERB eq 'SUBREM')) {
			#	require CUSTOMER;
			#	my $EMAIL = $params->{'email'};
			#	$EMAIL =~ s/^[\s]+//g;	# strip leading whitespace
			#	$EMAIL =~ s/[\s]$+//g;  # strip trailing whitepsace
			#	if ($EMAIL =~ /^[\d\-]+$/) {
			#		## EMAIL is a phone #!?
			#		}
			#	elsif (not &ZTOOLKIT::validate_email($EMAIL)) {
			#		push @MSGS, "ERROR|+$EMAIL does not appear to be valid";
			#		$EMAIL = '';
			#		}
			#	else {
			#		my $changed = 0;
			#		my ($C) = CUSTOMER->new($USERNAME,EMAIL=>$EMAIL,PRT=>$PRT,INIT=>0x1,CREATE=>2);
			#		my ($newsletter) = $C->fetch_attrib('INFO.NEWSLETTER');
			#		my $BITMASK = 1 << ($CPG-1);
			#		if ($VERB eq 'SUBADD') {
			#			if (($newsletter & $BITMASK)>0) {
			#				push @MSGS, "WARNING|+$EMAIL is already subscribed.";
			#				}
			#			else {
			#				$newsletter |= $BITMASK; $changed++;
			#				push @MSGS, "SUCCESS|+$EMAIL was added.";
			#				}
			#			}
			#		elsif ($VERB eq 'SUBREM') {
			#			if (($newsletter & $BITMASK)==0) {
			#				push @MSGS, "WARNING|+$EMAIL was already removed.";
			#				}
			#			else {
			#				$newsletter = $newsletter & (0xFFFF-$BITMASK); $changed++;
			#				push @MSGS, "SUCCESS|+$EMAIL was removed.";
			#				}
			#			}
			#		if ($changed) {
			#			$C->set_attrib('INFO.NEWSLETTER',$newsletter);
			#			$C->save();
			#			}
			#		}
			#	}
			#elsif ($VERB eq 'CPGCREATE') {
			#	## checks if ID exists, then
			#	## updates/inserts user input into NEWSLETTER table as appropriate
			#	if(defined $params->{'NAME'} && $params->{'NAME'} ne ''){
			#		my $pstmt = "select count(*) from NEWSLETTERS where MID=$MID and PRT=$PRT and CAMPAIGNID=".$udbh->quote($CPGID);
			#		print STDERR $pstmt."\n";
			#		my ($count) = $udbh->selectrow_array($pstmt);
			#		# strip out html and quotes, then
			#		# quote for DB update/insert
			#		### switched from AUTOEMAIL::htmlStrip to ZTOOLKIT::htmlstrip
			#		### patti - 2008-03-17
			#		$params->{'NAME'} =~ s/\n$//;
			#		my $qtNAME = $udbh->quote(&ZTOOLKIT::htmlstrip($params->{'NAME'}));
			#		my $qtMODE = $udbh->quote(int($params->{'mode'}));
			#		my $qtES = $udbh->quote(&ZTOOLKIT::htmlstrip($params->{'desc'}));
			#		if ($count>0) {
			#			my $pstmt = "update NEWSLETTERS set NAME=$qtNAME,MODE=$qtMODE,EXEC_SUMMARY=$qtES where MID=$MID and PRT=$PRT and CAMPAIGNID=".$udbh->quote($CAMPAIGNID);
			#			&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
			#			}
			#		else {
			#			my $pstmt = "insert into NEWSLETTERS (ID,MID,USERNAME,PRT,NAME,MODE,EXEC_SUMMARY,CREATED_GMT) values ";
			#			$pstmt .= "($CPGID,$MID,".$udbh->quote($USERNAME).",$PRT,$qtNAME,$qtMODE,$qtES,".time().')';
			#			&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
			#			}
			#
			#		$LU->log('UTILITIES.NEWSLETTER',"Changed Subscriber List $CPG","SAVE");
			#		
			#		}
			#	else{
			#		push @MSGS, "ERROR|+Please be sure to fill out the name of the Subscription List.";
			#		}
			#	}
			}

		print STDERR Dumper(\@MSGS);
		foreach my $msg (@MSGS) {
			my ($ref) = LISTING::MSGS::msg_to_disposition($msg);
			if (substr($ref->{'+'},0,1) eq '+') { $ref->{'+'} = substr($ref->{'+'},1); }
			push @{$R{'@MSGS'}}, $ref;
			}

		}
	elsif ($v->{'_cmd'} eq 'adminCampaignListRecipients') {
		require CUSTOMER::BATCH;
		my $BITMASK = $v->{'MASK'};
		my (%ref) = &CUSTOMER::BATCH::list_customers($USERNAME,$PRT,NEWSLETTERMASK=>$BITMASK);

		my @CUSTOMERS = ();	
		foreach my $email (sort keys %ref) {
			push @CUSTOMERS, $email;
			}
		$R{'@RECIPIENTS'} = \@CUSTOMERS;
		}
	elsif ($v->{'_cmd'} eq 'adminCampaignSubscriberLists') {
		my $c = '';
		my $CREF = &CUSTOMER::NEWSLETTER::fetch_newsletter_sub_counts($USERNAME,$PRT);
	   my @RESULTS = &CUSTOMER::NEWSLETTER::fetch_newsletter_detail($USERNAME,$PRT);
		my @sorted = ();

		my %modes = ();
		$modes{-1} = 'Not Configured';
		$modes{0} = 'Exclusive';
		$modes{1} = 'Default';
		$modes{2} = 'Targeted';

		my $count = 0;
		my $class = '';
		my @ROWS = ();
		foreach my $list (@RESULTS) {
			my ($id, $name, $created, $mode) = ($list->{'ID'},$list->{'NAME'},$list->{'CREATED_GMT'},$modes{$list->{'MODE'}});
			next if ($id == 0);
			next if ($id >= 1000);	## this is an automated list.
			push @ROWS, $list;
			}	
		$R{'@LISTS'} = \@ROWS;
		}
	elsif ($v->{'_cmd'} eq 'adminCampaignList') {
		## CAMPAIGNS
		## Build 3 separate tables:
		##  PENDING, APPROVED, FINISHED
		## where the header may be different for all
		my $pstmt = "select * from CAMPAIGNS where MID=$MID /* $USERNAME */ and PRT=$PRT and CPG_TYPE='NEWSLETTER' order by STATUS,FINISHED_GMT desc,ID desc";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
	
		my @CAMPAIGNS = ();
		while ( my $CREF = $sth->fetchrow_hashref() ) {
			# my $CREATE_DATE = &ZTOOLKIT::pretty_date($CREF->{'CREATED_GMT'}, -1);
			$CREF->{'CREATE_DATE'} = &ZTOOLKIT::pretty_date($CREF->{'CREATED_GMT'}, -1);
	
			# my $START_DATE = &ZTOOLKIT::pretty_date($CREF->{'STARTS_GMT'}, -1);
			$CREF->{'START_DATE'} = &ZTOOLKIT::pretty_date($CREF->{'FINISHED_GMT'}, 1);
			#if ($CREF->{'STATUS'} eq 'PENDING') {
			#	push @UNSENT, $CREF;
			#	}
			#elsif ($CREF->{'STATUS'} eq 'APPROVED') {
			#	push @ACTIVE, $CREF;
			#	}
			#elsif ($CREF->{'STATUS'} eq 'QUEUED') {
			#	push @ACTIVE, $CREF;
			#	}
			#elsif ($CREF->{'STATUS'} eq 'FINISHED') {
			#	push @FINISHED, $CREF;
			#	}
			#else {
			#	$CREF->{'STATUS'} = "UNKNOWN-$CREF->{'STATUS'}";
			#	push @FINISHED, $CREF;
			#	}
			push @CAMPAIGNS, $CREF;
			}
		$sth->finish();
		$R{'@CAMPAIGNS'} = \@CAMPAIGNS;
		}
	else {
		&JSONAPI::set_error(\%R,'apperr',120,"invalid _cmd");
		}


	&DBINFO::db_user_close();

	return(\%R);
	}






















=pod

<API id="adminEBAYTemplateDownload">
<purpose>lists the fields on an html wizard</purpose>
<input id="ebay:template"></input>
</API>

<API id="adminEBAYAPI-AddItem">
<purpose>runs an eBay API calls</purpose>
<input id="Item/SKU">product id</input>
<input id="Item/Quantity">quantity to launch (must be 1 for auctions)</input>
<input id="Item/UUID">a unique # for this request</input>
<input id="Profile">zoovy launch profile to load settings from, if profile is not set, then ebay:profile will be used.</input>
</API>

<API id="adminEBAYAPI-VerifyAddItem">
<purpose>runs an eBay VerifyAddItem (see adminEBAYAPI-AddItem)</purpose>
</API>

<API id="adminEBAYAPI-AddFixedPriceItem">
<purpose>runs an eBay AddFixedPriceItem (see adminEBAYAPI-AddItem)</purpose>
</API>

<API id="adminEBAYAPI-VerifyAddFixedPriceItem">
<purpose>runs an eBay VerifyAddFixedPriceItem (see adminEBAYAPI-AddItem)</purpose>
</API>


<API id="adminEBAYTokenList">
<purpose>lists all tokens across all partitions (one token per partition)</purpose>
<output id="@ACCOUNTS"></output>
</API>

<API id="adminEBAYTokenDetail">
<purpose>performs ebay 'GetUser' call to verify current token, returns info associated with the partition</purpose>
<output id="@PROFILES"></output>
<output id="%TOKEN"></output>
</API>

<API id="adminEBAYProfileDetail">
<purpose>Returns the data in an eBay launch profile</purpose>
</API>

<API id="adminEBAYProfileList">
<purpose>Returns the list of possible profiles</purpose>
</API>

<API id="adminEBAYShippingDetail">
<purpose>Parses and returns a structured version of the shipping configuration for the profile requested</purpose>
<input id="PROFILE"></input>
<output id="@OUR_DOMESTIC"></output>
<output id="@OUR_INTERNATIONAL"></output>
<output id="@ALL_LOCATIONS"></output>
<output id="@OUR_LOCATIONS"></output>
<output id="@PREFERENCES"></output>
<output id="@SERVICES_DOMESTIC"></output>
<output id="@SERVICES_INTERNATIONAL"></output>
</API>

<API id="adminEBAYWizardPreview">
<purpose>-- will need some love --</purpose>
</API>

<API id="adminEBAYMacro">
<purpose>Modify the eBay Configuration</purpose>
<input id="PROFILE" optional="1">Profile specific calls require admin</input>
</API>

=cut


sub adminEBAY {
	my ($self,$v) = @_;

	my %R = ();

	use lib "/backend/lib";
	require EBAY2::PROFILE;
	require EBAY2;
	require TEMPLATE;
	require PRODUCT::FLEXEDIT;

	my ($LU) = $self->LU();
	my ($USERNAME) = $self->username();
	my ($PRT) = $self->prt();
	my ($MID) = $self->mid();

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my @PROFILE_INFO = @{&PRODUCT::FLEXEDIT::get_GTOOLS_Form_grp("ebay.profile")};

	my $NSREF = {};
	if (defined $v->{'PROFILE'}) {
		$NSREF = &EBAY2::PROFILE::fetch($USERNAME,$PRT,$v->{'PROFILE'});
		}

	if ($v->{'_cmd'} eq '') {	
		}
	elsif ($v->{'_cmd'} eq 'adminEBAYStoreCategoryList') {
		$R{'@STORECATS'} = &EBAY2::fetchStoreCats($USERNAME,'eias'=>$v->{'eias'});
		}
	elsif ($v->{'_cmd'} eq 'adminEBAYTokenList') {
		my ($accountsref) = &EBAY2::list_accounts($USERNAME);
		$R{'@ACCOUNTS'} = $accountsref;
		}
	elsif ($v->{'_cmd'} eq 'adminEBAYTokenDetail') {
		my %hash = ();
		$hash{'#Site'} = 0;
		$hash{'DetailLevel'} = 'ReturnAll';
		my $r = undef; 
		my ($eb2) = EBAY2->new($USERNAME,PRT=>$PRT);
		if (defined $eb2) {
			($r) = $eb2->api('GetUser',\%hash,preservekeys=>['User']);
			}
		}
	elsif ($v->{'_cmd'} =~ /^adminEBAYAPI\-(AddItem|VerifyAddItem|AddFixedPricedItem|VerifyAddFixedPriceItem)$/) {
		# Note: Seller-level call rate limits were introduced in Version 793 for Add and Revise Listing calls. 
		# Each user is allowed 1200 Add Listing calls and 1200 Revise Listing calls per 30 seconds, which equates to 
		# about 3.5 million calls per 24-hour period. Add Listing calls include AddItem, AddFixedPriceItem, AddItems, 
		# AddSellingManagerTemplate, VerifyAddItem, and VerifyAddFixedPriceItem. Revise Listing calls include ReviseItem, 
		# ReviseFixedPriceItem, and ReviseSellingManagerTemplate.  

		if (not JSONAPI::validate_required_param(\%R,$v,'Item/UUID')) {
			}
		elsif (not JSONAPI::validate_required_param(\%R,$v,'Item/Quantity')) {
			}

		my $P = undef;
		if (&JSONAPI::hadError(\%R)) {
			}
		elsif ($v->{'Item/SKU'} ne '') {
				$P = PRODUCT->new($USERNAME,$v->{'Item/SKU'});
			}
		elsif ($v->{'Profile'} ne '') {
			$P = PRODUCT->new($USERNAME,$v->{'Item/UUID'});
			}

		my $TARGET = undef;
		if (&JSONAPI::hadError(\%R)) {
			}
		elsif ($v->{'_cmd'} =~ /AddFixedPriceItem$/) {
			my $QTY = int($v->{'Item/Quantity'});
			if ($QTY == 0) { $v->{'Item/Quantity'} = $P->fetch('ebay:fixed_qty'); }
			if (int($QTY)==0) { &JSONAPI::set_error(\%R,'youerr',9288,"Quantity field (ebay:fixed_qty) is zero"); }
			$TARGET = 'EBAY.FIXED'; 
			}
		elsif ($v->{'_cmd'} =~ /AddItem$/) {
			$v->{'Item/Quantity'} = 1;
			$TARGET = 'EBAY.AUCTION'; 
			}
		else {
			&JSONAPI::set_error(\%R,'apperr',9290,"Unknown TYPE");
			}

		require LISTING::EVENT;
		if (not &JSONAPI::hadError(\%R)) {
			my ($udbh) = &DBINFO::db_user_connect($USERNAME);
			my ($le) = LISTING::EVENT->new(USERNAME=>$USERNAME,LUSER=>$self->luser(),
				REQUEST_APP=>sprintf("api#%d/%s",$self->apiversion(),$self->clientid()),
				REQUEST_APP_UUID=>$v->{'Item/UUID'},
				SKU=>$P->pid(),
				QTY=>int($v->{'Item/Quantity'}),
				TARGET=>$TARGET,
				PRT=>$PRT,
				VERB=>(($v->{'_cmd'} eq 'adminEBAYListingTest')?'PREVIEW':'INSERT'),
				LOCK=>1
				);

			if (ref($le) eq 'LISTING::EVENT') {
				$le->dispatch($udbh,$P);
				$R{'RESULT'} = $le->html_result();
				}
			else {
				$R{'RESULT'} = "INTERNAL-ERROR - was not able to create/process a listing event";
				}
			&DBINFO::db_user_close();
			}
		
		}
	elsif ($v->{'_cmd'} eq 'adminEBAYProfileDetail') {
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'PROFILE')) {
			}
		else {
			my $epnsref = &EBAY2::PROFILE::fetch($USERNAME,$PRT,$v->{'PROFILE'});		
			$epnsref->{'PROFILE'} = $v->{'PROFILE'};
			$R{'%PROFILE'} = $epnsref;
			}
		}
	elsif ($v->{'_cmd'} eq 'adminEBAYProfileList') {
		my $prefs = &EBAY2::PROFILE::list($USERNAME);
		my @PROFILES = ();
		foreach my $pref (@{$prefs}) {
			next if ($pref->{'CODE'} eq '');
			$pref->{'PROFILE'} = $pref->{'CODE'}; delete $pref->{'CODE'};
			push @PROFILES, $pref;
			}
		$R{'@PROFILES'} = \@PROFILES;
		}
	elsif ($v->{'_cmd'} eq 'adminEBAYProfileRemove') {
		my ($PROFILE) = $v->{'PROFILE'};
		$LU->log('SETUP.PROFILE',"REMOVED PROFILE: $PROFILE",'INFO');
		EBAY2::PROFILE::nuke($USERNAME,$PRT,$PROFILE);
		&JSONAPI::append_msg_to_response(\%R,'success',0,"REMOVED PROFILE: $PROFILE");
		}
	elsif (
		($v->{'_cmd'} eq 'adminEBAYProfileCreate') || 
		($v->{'_cmd'} eq 'adminEBAYProfileUpdate') || 
		($v->{'_cmd'} eq 'adminEBAYProfileTest') ||
		($v->{'_cmd'} eq 'adminEBAYProfilePreview')
		) {
		require EBAY2::PROFILE;
		my ($PROFILE) = $v->{'PROFILE'};


		if (not &JSONAPI::validate_required_parameter(\%R,$v,'PROFILE')) {
			## this will set \%R to error
			}
	
		my %epnsref = ();
		if (JSONAPI::hadError(\%R)) {
			}
		elsif ($v->{'_cmd'} eq 'adminEBAYProfileCreate') {
			## make sure we create a test dir.
			my ($t) = TEMPLATE->new($USERNAME,'EBAY','$SYSTEM','blank');
			## warn "TEMPLATE! (PROFILE:$PROFILE)\n";
			$t->install($PROFILE);
			}
		elsif (
				($v->{'_cmd'} eq 'adminEBAYProfileUpdate') || 
				($v->{'_cmd'} eq 'adminEBAYProfileTest') || 
				($v->{'_cmd'} eq 'adminEBAYProfilePreview')
			) {
			my ($ref) = EBAY2::PROFILE::fetch($USERNAME,$PRT,$PROFILE);
			foreach my $k (keys %{$ref}) {
				$epnsref{$k} = $ref->{$k};
				}
			}
		
		if (not &JSONAPI::hadError(\%R)) {
			if ($v->{'#destroy'}) {
				## this is used to cleanup Item\\ tags.
				foreach my $k (keys %epnsref) {
					if ($k =~ /^Item\\/) { delete $epnsref{$k}; }
					}
				}

			foreach my $k (keys %{$v}) {
				if (substr($k,0,1) eq '#') {
					## these cannot be saved, they are set by us!
					}
				elsif (substr($k,0,1) eq '@') {
					## @ship_domservices = service=<ShippingServiceOption.ShippingService>&free=<ShippingServiceOption.FreeShipping>&cost=<ShippingServiceOption.ShippingServiceCost>&addcost=<ShippingServiceOption.ShippingServiceAdditionalCost>&farcost=<ShippingServiceOption.ShippingSurcharge>
					if (ref($v->{$k}) eq 'ARRAY') {
						$epnsref{ $k } = $v->{$k};
						}
					else {
						&JSONAPI::set_error(\%R,'apperr',9392,"Field $k was expected to be type ARRAY");
						}
					}
				else {
					## scalar ebay field
					$epnsref{ $k } = $v->{$k};
					}
				}
			$epnsref{'#v'} = $self->apiversion();	
			}


		if (($v->{'_cmd'} eq 'adminEBAYProfileTest') || ($v->{'_cmd'} eq 'adminEBAYProfilePreview')) {
			require LISTING::EVENT;
			require LISTING::EBAY;

			my ($P) = undef;		
			if ((not defined $v->{'pid'}) || ($v->{'pid'} eq '')) {
				my %prod = ();
				$prod{'zoovy:prod_name'} = 'Test eBay Listing';
				$prod{'ebay:title'} = 'Test Listing';
				$prod{'ebay:fixed_qty'} = 1;
				$prod{'ebay:fixed_price'} = 1.00;
				$prod{'ebay:fixed_duration'} = 7;
				$prod{'ebay:category'} = 30120;	## test only
				$prod{'zoovy:base_weight'} = '#1';
				$prod{'zoovy:profile'} = $PROFILE;
				($P) = PRODUCT->new($self->username(),'_EBAYTEST_','%prodref'=>\%prod);
				}
			else {
				$P = PRODUCT->new($self->username(),$v->{'pid'});
				$R{'pid'} = $v->{'pid'};
				}

			my $prodref = $P->prodref();

			if (not defined $P) {
				&JSONAPI::set_error(\%R,'apperr',9394,sprintf("Product (pid:%s) was specified, but is not valid",$v->{'pid'}));
				}
			elsif ($epnsref{'#v'} < 201324) {
				&JSONAPI::set_error(\%R,'apperr',9398,sprintf("Unsupported profile[%s] version[%d]",$PROFILE,$epnsref{'#v'}));
				}
			elsif ($v->{'_cmd'} eq 'adminEBAYProfileTest') {
				my ($le) = LISTING::EVENT->new('TARGET'=>'EBAY.FIXED','USERNAME'=>$self->username(),'PRT'=>$self->prt(),'VERB'=>'PREVIEW','PRODUCT'=>'_EBAYTEST_','PROFILE'=>$PROFILE,'%DATA'=>$prodref);
 				LISTING::EBAY::event_handler($udbh,$le,$P,'%profile'=>\%epnsref);
				foreach my $msg (@{$le->msgs()}) {
					my ($ref) = LISTING::MSGS::msg_to_disposition($msg);
					if (substr($ref->{'+'},0,1) eq '+') { $ref->{'+'} = substr($ref->{'+'},1); }
					push @{$R{'@MSGS'}}, $ref;
					}
				}
			elsif ($v->{'_cmd'} eq 'adminEBAYProfilePreview') {
				## new style launch template
				print STDERR "PROFILE: $PROFILE\n";
				require TEMPLATE::KISSTLC;
				my @MSGS = ();
				my ($MSGS) = LISTING::MSGS->new($self->username());
				my ($html) = TEMPLATE::KISSTLC::render($self->username(),'EBAY',$PROFILE,'SKU'=>$P->pid(),'@MSGS'=>\@MSGS,'*PRODUCT'=>$P);
				$R{'html'} = TEMPLATE::KISSTLC::ebayify_html($html);
				$R{'@MSGS'} = [];
				foreach my $msgline (@MSGS) {
					my ($ref) = LISTING::MSGS::msg_to_disposition($msgline);
					if (($ref->{'+'} eq 'ERROR') || ($ref->{'+'} eq 'WARN')) {
						if (substr($ref->{'+'},0,1) eq '+') { $ref->{'+'} = substr($ref->{'+'},1); }
						&JSONAPI::set_error(\%R,'youerr',9399,$ref->{'+'}); 
						}
					push @{$R{'@MSGS'}}, $ref;
					}
				if ($R{'html'} eq '') {
					$R{'hadError'} = 1;
					$R{'html'} = sprintf("<i>Preview could not be generated using PROFILE[%s] PID[%s] (template issues)</i>", $PROFILE, $P->pid());
					}
				}
			}
		else {
			## adminEBAYProfileCreate adminEBAYProfileTest
			&EBAY2::PROFILE::store($USERNAME,$PRT,$PROFILE,\%epnsref);
			if (not &JSONAPI::hadError(\%R)) {
				&JSONAPI::append_msg_to_response(\%R,'success',0); #,"Successfully updated EBAY_PROFILE:$PROFILE PRT:$PRT");
				}
			}

		}
	elsif ($v->{'_cmd'} eq 'adminEBAYMacro') {
		my @CMDS = ();
		my $edbh = &DBINFO::db_user_connect($self->username());

		$self->parse_macros($v->{'@updates'},\@CMDS);
		my $LM = LISTING::MSGS->new();
				
		foreach my $CMDSET (@CMDS) {
			my ($VERB,$params) = @{$CMDSET};
			my @MSGS = ();
			my $CODE = $v->{'PROFILE'};

			if ($VERB eq 'FEEDBACK-SAVE') {
				my $pstmt = "select EBAY_EIAS from EBAY_TOKENS where MID=$MID /* $USERNAME */ and PRT=$PRT order by ID";
				my $sth = $udbh->prepare($pstmt);
				$sth->execute();
				while ( my ($eias) = $sth->fetchrow() ) {
					my $qtMSG = $udbh->quote($v->{"MSG!$eias"});
					my $qtEIAS = $udbh->quote($eias);
					my $mode = int($v->{"MODE!$eias"});
					my $pstmt = "update EBAY_TOKENS set FB_POLLED_GMT=0,FB_MESSAGE=$qtMSG,FB_MODE=$mode where MID=$MID and PRT=$PRT and EBAY_EIAS=$qtEIAS";
					print STDERR $pstmt."\n";
					&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
					}
				$sth->finish();	
				}
			#elsif ($VERB eq 'PROFILE-SAVEAS-TEMPLATE') {
			#	## not finished yet
			#	## my ($ref) = EBAY2::PROFILE::fetch($USERNAME,$self->prt(),$CODE);
			#	my ($PROFILE) = $params->{'profile'}; 
			#	if (not defined $PROFILE) { $PROFILE = $params->{'PROFILE'}; }				
			#	my ($TEMPLATE) = $params->{'template'}; 
			#	if (not defined $TEMPLATE) { $TEMPLATE = $params->{'TEMPLATE'}; }				
			#	}
			elsif ($VERB eq 'PROFILE-UPGRADE') {
				my ($PROFILE) = $params->{'PROFILE'};
				require EBAY2::PROFILE;
				my ($epnsref) = EBAY2::PROFILE::fetch($USERNAME,$self->prt(),$PROFILE);

				if ($epnsref->{'#v'} < 201324) {
					my ($ebaytemplate) = $epnsref->{'ebay:template'};

					my %new = ();
					require LISTING::EBAY;
					my $fields = &LISTING::EBAY::ebay_fields('UPGRADE');
					foreach my $field (@{$fields}) {
						print STDERR " $field->{'ebay'} => $epnsref->{$field->{'id'}}\n";
						if ($field->{'ebay'}) { $new{$field->{'ebay'}} = $epnsref->{$field->{'id'}}; }
						}
					my @ship_domservices = ();
					my @lines = split(/[\n\r]+/,$epnsref->{'ebay:ship_domservices'});
					foreach my $line (@lines) { my $svc = &ZTOOLKIT::parseparams($line);	push @ship_domservices, $svc;	}
					$new{'@ship_domservices'} = \@ship_domservices;
					my @ship_intservices = ();

					@lines = split(/[\n\r]+/,$epnsref->{'ebay:ship_intservices'});
					foreach my $line (@lines) { my $svc = &ZTOOLKIT::parseparams($line);	push @ship_intservices, $svc;	}
					$new{'@ship_intservices'} = \@ship_intservices;
					
					my $BASEURL = EBAY2::PROFILE::baseurl($self->username(),$self->sdomain(),$PROFILE);
					if ($ebaytemplate eq '') {
						}
					elsif (substr($ebaytemplate,0,1) ne '~') {
						## system template, copy to profile
						my $BASEURL = EBAY2::PROFILE::baseurl($self->username(),$self->sdomain(),$ebaytemplate);
						my ($T) = TEMPLATE->new($USERNAME,'EBAY','$SYSTEM',$ebaytemplate,'base'=>$BASEURL);
						if (not $T->install($PROFILE,'base'=>$BASEURL)) {
							push @MSGS, "ERROR|+Could not copy legacy template: $ebaytemplate";
							}
						}
					#else {
					#	require TEMPLATE::TOXML;
					#	my ($PROJECT,$TEMPLATE) = TEMPLATE::TOXML::upgradeLegacy($USERNAME,$ebaytemplate);
					#	my ($T) = TEMPLATE->new($USERNAME,'EBAY',$PROJECT,$TEMPLATE);
					#	if (not $T->install($PROFILE,'base'=>$BASEURL)) {
					#		push @MSGS, "ERROR|+Could not copy legacy template: $PROJECT:$TEMPLATE";
					#		}
					#	}
					$new{'#v'} = $self->apiversion();	
					&EBAY2::PROFILE::store($USERNAME,$PRT,$PROFILE,\%new);
					}
				}
			elsif ($VERB eq 'SETTOKEN') {
				## SETTOKEN is returned from https://webapi.zoovy.com/webapi/ebayapi/accept.cgi
				###	the following variables are set:
				###		USERNAME
				###		eb - ebayusername
				###		ebaytkn - ebay authentication token
				###		tknexp - expiration date [2005-02-04 19:38:37]
				}
			elsif ($VERB eq 'TOKEN-REMOVE') {
				my $qtEIAS = $udbh->quote($params->{'eias'});
				my $pstmt = "delete from EBAY_TOKENS where MID=$MID /* $USERNAME */ and EBAY_EIAS=$qtEIAS limit 1";
				print STDERR "$pstmt\n";
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);

				$pstmt = "delete from EBAYSTORE_CATEGORIES where MID=$MID /* $USERNAME */ and EIAS=$qtEIAS";
				print STDERR "$pstmt\n";
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
				$LU->log("SETUP.EBAY","Token Removed EIAS=$qtEIAS","SAVE");
				}
			elsif ($VERB eq 'LOAD-STORE-CATEGORIES') {
				require EBAY2::STORE;
				my ($count) = &EBAY2::STORE::rebuild_categories($USERNAME,$params->{'eias'});
				}
			## END CMDS
			}

		&DBINFO::db_user_close();
		## END adminEBAYMacro
		}
	else {
		&JSONAPI::set_error(\%R,'apperr',120,"invalid _cmd");
		}

	&DBINFO::db_user_close();
	return(\%R);
	## END adminEBAY
	}























=pod

<API id="adminSyndicationList">
<purpose>returns a list of marketplaces and their configuration status</purpose>
</API>

<API id="adminSyndicationDetail">
<purpose></purpose>
<input id="DST">marketplace destination code (usually 3 or 4 digits) which can be obtained from the dst code in appResourceGet 'integrations' file</input>
</API>


<API id="adminSyndicationPublish">
<input id="DST">marketplace destination code (usually 3 or 4 digits) which can be obtained from the dst code in appResourceGet 'integrations' file</input>
<input id="FEEDTYPE">PRODUCT|INVENTORY</input>
<output id="JOBID"></output>
<purpose>creates a batch job for publishing</purpose>
</API>

<API id="adminSyndicationHistory">
<input id="DST">marketplace destination code (usually 3 or 4 digits) which can be obtained from the dst code in appResourceGet 'integrations' file</input>
<output id="@ROWS">
	[ msgtype1, timestamp1, message1 ],
	[ msgtype2, timestamp2, message2 ],
</output>
<purpose></purpose>
</API>

<API id="adminSyndicationFeedErrors">
<input id="DST">marketplace destination code (usually 3 or 4 digits) which can be obtained from the dst code in appResourceGet 'integrations' file</input>
<purpose>displays up to 500 to remove/hide these.</purpose>
<output id="@ROWS">
	[ timestamp1, sku1, feedtype1, errcode1, errmsg1, batchjob#1 ],
	[ timestamp2, sku2, feedtype2, errcode2, errmsg2, batchjob#2 ],
</output>
</API>

<API id="adminSyndicationDebug">
<input id="DST">marketplace destination code (usually 3 or 4 digits) which can be obtained from the dst code in appResourceGet 'integrations' file</input>
<input id="FEEDTYPE">PRODUCT|INVENTORY</input>
<input id="PID" optional="1">PRODUCTID</input>
<output id="HTML">Html messaging describing the syndication process + any errors</output>
<purpose>runs the syndication process in realtime and returns an html response describing 'what happened'</purpose>
</API>




<API id="adminSyndicationBUYDownloadDBMaps">
<input id="DST">BUY|BST</input>
<purpose>
	buy.com/bestbuy.com have support for json dbmaps, which allow uses to create ad-hoc schema that maps existing product attributes to buy.com data.
	since buy.com product feeds are no longer sent in an automated fasion the utility of this feature is somewhat limited, but can still be used to perform additional validation
	during/prior to export.
	each dbmap has a 1-8 digit code, and associated json (which uses a modified flexedit syntax).
	each product would then have a corresponding buycom:dbmap or bestbuy:dbmap field set.
</purpose>
</API>

<API id="adminSyndicationAMZThesaurii">
<input id="DST">AMZ</input>
<output id="@CATEGORIES">
	[ safename, prettyname, thesauruskey, thesaurusvalue ]
</output>
<purpose>
	store categories may have one or more amazon thesauruses associated with it a thesaurus helps amazon classify a product similar to a category+tag might in other systems.
	for example 'color' 'navy' in the amazon system might be equivalent to 'color' 'blue' when somebody does a search, but not 'color' 'teal' (which might also map to both blue/green).
	a single category may have many thesaurus keys/values.
</purpose>
</API>

<API id="adminSyndicationAMZOrders">
<input id="DST">AMZ</input>
<purpose>displays orders created in the last 50 days which have not been flagged as fulfilled/processed. </purpose>
</API>

<API id="adminSyndicationAMZLogs">
<input id="DST">marketplace destination code (usually 3 or 4 digits) which can be obtained from the dst code in appResourceGet 'integrations' file</input>
<output id="@ROWS">
	[ pid, sku, feed, ts, msgtype, msg ]
</output>
<purpose>returns up to 1000 products where the amazon error flag is set in the SKU Lookup table.</purpose>
</API>

<API id="adminSyndicationListFiles">
<input id="DST">marketplace destination code (usually 3 or 4 digits) which can be obtained from the dst code in appResourceGet 'integrations' file</input>
<output id="@FILES">
	{ FILENAME, FILETYPE, GUID }
</output>
<purpose></purpose>
</API>

<API id="adminSyndicationMacro">
<input id="DST">marketplace destination code (usually 3 or 4 digits) which can be obtained from the dst code in appResourceGet 'integrations' file</input>
<input id="@updates"><![CDATA[
DELETE
ENABLE
DISABLE
UNSUSPEND
CLEAR-FEED-ERRORS
SAVE?fields=from&input=form
DBMAP-NUKE?MAPID=
DBMAP-SAVE?MAPID=&CATID=&STOREID=&MAPTXT=
AMZ-THESAURUS-DELETE?guid=
AMZ-THESAURUS-SAVE?name=&guid=&search_terms&itemtype=&subjectcontent&targetaudience&isgiftwrapavailable&
AMZ-SHIPPING-SAVE?Standard=XXX&Expedited=XXY&Scheduled=XXZ&NextDay=XYY&SecondDay=XYZ
AMZ-TOKEN-UPDATE?marketplaceId=&merchantId=
]]>
</input>
<purpose></purpose>
</API>


=cut

sub adminSyndication {
	my ($self,$v) = @_;

	my %R = ();

	my $USERNAME = $self->username();
	my $LU = $self->LU();
	my $MID = $self->mid();
	my $PRT = $self->prt();

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my $MKT = uc($v->{'DST'});

	my @CONFIG_FIELDS = ();

	my ($DST,$MARKETPLACE) = (undef,undef);
	my @CSV_PRODUCT_EXPORT = ();

	my @TABS = ();
	my @FIELDS = ();


	if ($self->apiversion() < 201332) {
		&JSONAPI::set_error(\%R,'apperr',39122,"Please upgrade to version 201332 or higher to access syndication.");
		}
	elsif ($MKT eq 'NXT') {
		## NEXTAG
		($DST,$MARKETPLACE) = ('NXT','Nextag.com');
		#push @TABS, { name=>"Categories",  link=>"$PATH?VERB=CATEGORIES&PROFILE=$PROFILE", };
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP Username', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Server', id=>'.ftp_server', required=>1, hint=>'example: upload.nextag.com' };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	#elsif ($MKT eq 'GSM') {
	#	## GOOGLE SITEMAP
	#	($DST,$MARKETPLACE) = ('GSM','Google Sitemap');
	#	# push @BC, { name=>'SiteMap',link=>"$PATH",'target'=>'_top', };
	#	push @FIELDS, { type=>'checkbox', name=>'Enable', id=>'.enable', required=>1 };
	#	push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
	#	}
	elsif ($MKT eq 'BUY') {
		require SYNDICATION::BUYCOM;
		($DST,$MARKETPLACE) = ('BUY','Buy.com');
		#push @TABS, {  'name'=>'DB Maps', 'link'=>"$PATH?VERB=DBMAP&PROFILE=$PROFILE" };
		#push @TABS, {  'name'=>'Files', 'link'=>"$PATH?VERB=FILES&PROFILE=$PROFILE" };
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP Username', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'Seller ID', id=>'.sellerid', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'Seller Password', id=>'.sellerpass', required=>1 };
		}
	elsif ($MKT eq 'BST') {
		require SYNDICATION::BUYCOM;
		($DST,$MARKETPLACE) = ('BST','BestBuy.com');
		#push @TABS, {  'name'=>'DB Maps', 'link'=>"$PATH?VERB=DBMAP&PROFILE=$PROFILE" };
		#push @TABS, {  'name'=>'Files', 'link'=>"$PATH?VERB=FILES&PROFILE=$PROFILE" };
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP Username', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'Seller ID', id=>'.sellerid', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'Seller Password', id=>'.sellerpass', required=>1 };
		}
	elsif ($MKT eq 'CJ') {
		require SYNDICATION::CJUNCTION;
		($DST,$MARKETPLACE) = ('CJ','Commission Junction');
		#push @TABS, {  'name'=>'Categories', 'link'=>'/biz/syndication/cj/index.cgi?VERB=CATEGORIES&PROFILE='.$PROFILE };
		#push @TABS, { name=>"Logs",  link=>"?VERB=LOGS&PROFILE=$PROFILE", };
		#push @TABS, { name=>"Diagnostics",  link=>"?VERB=DEBUG&PROFILE=$PROFILE", };
		push @FIELDS, { type=>'textbox', id=>'.cjcid' };
		push @FIELDS, { type=>'textbox', id=>'.cjaid' };
		push @FIELDS, { type=>'textbox', id=>'.cjsubid' };
		push @FIELDS, { type=>'textbox', id=>'.host' };
		push @FIELDS, { type=>'textbox', id=>'.user' };
		push @FIELDS, { type=>'textbox', id=>'.pass' };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	elsif ($MKT eq 'PGR') {
		($DST,$MARKETPLACE) = ('PGR','PriceGrabber.com');
		#push @TABS, { name=>"Categories", selected=>($VERB eq 'CATEGORIES')?1:0, link=>"$PATH?VERB=CATEGORIES&PROFILE=$PROFILE", };
		#push @TABS, { selected=>($VERB eq 'FILES')?1:0, 'name'=>'Files', 'link'=>"$PATH?VERB=FILES&PROFILE=$PROFILE" };
		## NOTE: even though this is type FTP, it uses the .user and .pass fields
			##			because pricegrabber doesn't separate the fields.
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP/Web Username', id=>'.user', required=>1, hint=>'hint: uploaded filename is always username.csv',};
		push @FIELDS, { type=>'textbox', name=>'FTP/Web Password', id=>'.pass', required=>1 };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	elsif ($MKT eq 'APA') {
		($DST,$MARKETPLACE) = ('APA','Amazon Product Ads');
		#push @TABS, { selected=>($VERB eq 'FILES')?1:0, 'name'=>'Files', 'link'=>"$PATH?VERB=FILES&PROFILE=$PROFILE" };
		## NOTE: even though this is type FTP, it uses the .user and .pass fields
		##			because pricegrabber doesn't separate the fields.
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP/Web Username', id=>'.ftp_user', required=>1, hint=>'hint: uploaded filename is always username.csv',};
		push @FIELDS, { type=>'textbox', name=>'FTP/Web Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Server', id=>'.ftp_server', required=>1 };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	elsif (($MKT eq 'EBF') || ($MKT eq 'EBAY')) {
		($DST,$MARKETPLACE) = ('EBF','eBay Syndication');
		#push @TABS, { name=>"eBay Categories", selected=>($VERB eq 'EBAY-CATEGORIES')?1:0, link=>"$PATH?VERB=EBAY-CATEGORIES&PROFILE=$PROFILE", };
		#push @TABS, { selected=>($VERB eq 'FILES')?1:0, 'name'=>'Files', 'link'=>"$PATH?VERB=FILES&PROFILE=$PROFILE" };
		#push @TABS, { name=>"Feed Errors", selected=>($VERB eq 'FEED-ERRORS')?1:0, link=>"$PATH?VERB=FEED-ERRORS&PROFILE=$PROFILE", };
		#push @TABS, { name=>"Diagnostics", selected=>($VERB eq 'DEBUG')?1:0, link=>"$PATH?VERB=DEBUG&PROFILE=$PROFILE", };
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Submit New Products', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Use AutoPilot on New Items', id=>'.autopilot',
			hint=>q~[RECOMMENDED] 
			Auto-Pilot allows Zoovy's eBay Syndication Engine to make 'reasonable guesses' about getting 
			your products up on eBay.  
			This includes using fields such as the price on the website as the eBay Fixed price.
			Without Auto-Pilot, it will be necessary for you to choose eBay settings per product.
			If settings are not configured the product will generate listing event errors which you will need to correct.
			If the syndication engine encounters too many errors - then your token could be deactivated and all eBay processing will be suspended.
			~ };
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Detailed Logging', id=>'.logging', 
			hint=>q~[NOT RECOMMENDED] 
			What this does:
			The syndication engine generates detailed log files (which can be obtained by asking support), 
			that include the decision logic that was used to perform a listing. These log files consume significantly 
			more disk space. You should probably only enable this if instructed to by Zoovy support, but it can be invaluable
		   in diagnosing issues with auto-pilot.
			~ };
		}
	elsif ($MKT eq 'AMZ') {
		($DST,$MARKETPLACE) = ('AMZ','Amazon Syndication');
		push @FIELDS, { type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'Merchant Name', id=>'.amz_merchantname', required=>1, hint=>"This is your registered business name with Amazon" };
		push @FIELDS, { type=>'textbox', name=>'User ID', id=>'.amz_userid', required=>1, hint=>"The email address you use to sign into seller central or payment central" };
		push @FIELDS, { type=>'textbox', name=>'Password', id=>'.amz_password', required=>1, hint=>"The password you use to sign into seller central or payment central" };
		push @FIELDS, { type=>'textbox', name=>'Merchant Token', id=>'.amz_merchanttoken', required=>1, hint=>"The merchant token for account e.g. M_COMPANY_#######" };
		push @FIELDS, { type=>'textbox', name=>'Merchant ID', id=>'.amz_merchantid', required=>0, hint=>"Number used by Amazon to identify a Checkout by Amazon account" };
		push @FIELDS, { type=>'textbox', name=>'AWS Access Key', id=>'.amz_accesskey', required=>0, hint=>"Required for Checkout by Amazon, or Amazon Web Services" };
		push @FIELDS, { type=>'textbox', name=>'Signing Secret Key', id=>'.amz_secretkey', required=>0, hint=>"Required for Checkout by Amazon" };
		}
	elsif ($MKT eq 'WSH') {
		($DST,$MARKETPLACE) = ('WSH','Wishpot');
		}
	elsif ($MKT eq 'SAS') {
		($DST,$MARKETPLACE) = ('SAS','ShareASale.com');
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'Merchant ID', id=>'.merchantid', required=>1 };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	elsif ($MKT eq 'SHO') {
		($DST,$MARKETPLACE) = ('SHO','Shopping.com');
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP User', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Server', id=>'.ftp_server', required=>1 };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	elsif ($MKT eq 'FND') {
		($DST,$MARKETPLACE) = ('FND','TheFind.com');
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP User', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Server', id=>'.ftp_server', required=>1 };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	elsif ($MKT eq 'BIN') {
		($DST,$MARKETPLACE) = ('BIN','Bing.com');
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP User', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Server', id=>'.ftp_server', required=>1 };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	elsif ($MKT eq 'GOO') {
		($DST,$MARKETPLACE) = ('GOO','Google Shopping');
		push @FIELDS, { type=>'textbox', name=>'FTP User', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Server', id=>'.ftp_server', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Filename', id=>'.ftp_filename', required=>1, hint=>qq~(ex: products.xml)~};
		push @FIELDS, { type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'checkbox', id=>'.trusted_feed', name=>'Enable Trusted Stores Shipping/Cancel Feed', required=>1 };
		push @FIELDS, { type=>'checkbox', id=>'.upc_exempt' };
		push @FIELDS, { type=>'checkbox', id=>'.include_shipping' };
		push @FIELDS, { type=>'checkbox', id=>'.ignore_validation' };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	elsif ($MKT eq 'BZR') {
		($DST,$MARKETPLACE) = ('BZR','Shopzilla');
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'Web Login Username', id=>'.user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'Web Login Password', id=>'.pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP User', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Server', id=>'.ftp_server', required=>1 };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	elsif ($MKT eq 'PTO') {
		($DST,$MARKETPLACE) = ('PTO','Pronto.com');
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP User', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Server', id=>'.ftp_server', required=>1 };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	elsif ($MKT eq 'BCM') {
		($DST,$MARKETPLACE) = ('BCM','Become.com');
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP User', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Server', id=>'.ftp_server', required=>1 };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	elsif ($MKT eq 'SMT') {
		($DST,$MARKETPLACE) = ('SMT','Smarter.com');
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP User', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Server', id=>'.ftp_server', required=>1 };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	elsif ($MKT eq 'DIJ') {
		($DST,$MARKETPLACE) = ('DIJ','Dijipop.com');
		#push @TABS, { selected=>($VERB eq 'FILES')?1:0, 'name'=>'Files', 'link'=>"$PATH?VERB=FILES&PROFILE=$PROFILE" };
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP User', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Server', id=>'.ftp_server', required=>1 };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	elsif ($MKT eq 'LNK') {
		($DST,$MARKETPLACE) = ('LNK','Linkshare.com');
		#push @TABS, { selected=>($VERB eq 'FILES')?1:0, 'name'=>'Files', 'link'=>"$PATH?VERB=FILES&PROFILE=$PROFILE" };
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP User', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Server', id=>'.ftp_server', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'Linkshare MID', id=>'.linkshare_mid', required=>1, hint=>qq~Linkshare Merchant ID is assigned by LinkShare.~, };
		push @FIELDS, { type=>'textbox', name=>'Linkshare Company', id=>'.linkshare_company', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'Linkshare Default ClassID', id=>'.linkshare_default_classid', size=>3, required=>1, hint=>qq~(ex: 140 is electronics)~, };
		push @FIELDS, { type=>'textbox', id=>'.linkstyle' };
		}
	elsif ($MKT eq 'HSN') {
		($DST,$MARKETPLACE) = ('HSN','HSN.com');
		#push @TABS, { selected=>($VERB eq 'FILES')?1:0, 'name'=>'Files', 'link'=>"$PATH?VERB=FILES&PROFILE=$PROFILE" };
		#push @TABS, { name=>"Categories", selected=>($VERB eq 'CATEGORIES')?1:0, link=>"$PATH?VERB=CATEGORIES&PROFILE=$PROFILE", };
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP User', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Server', id=>'.ftp_server', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'Vendor ID', id=>'.vendorid', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'Order FTP Server', id=>'.order_ftp_server', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'Order FTP Username', id=>'.order_ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'Order FTP Password', id=>'.order_ftp_pass', required=>1 };
		}
	elsif ($MKT eq 'SRS') {
		($DST,$MARKETPLACE) = ('SRS','Sears');
		# push @BC, { name=>$MARKETPLACE,link=>'/biz/syndication/sears/index.cgi','target'=>'_top', };
		#push @TABS, { selected=>($VERB eq 'FILES')?1:0, 'name'=>'Files', 'link'=>"$PATH?VERB=FILES&PROFILE=$PROFILE" };
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'API User', id=>'.user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'API Password', id=>'.pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'Location ID', id=>'.location_id', required=>1, hint=>"This ID is created when a location is configured in the Sears UI." };
		push @FIELDS, { type=>'checkbox', name=>'Use Safe SKU Algorithm', id=>'.safe_sku', default=>1, hint=>"When necessary, an alternate SKU that is compatible with the marketplace will be generated. (Recommended)" };

		push @CSV_PRODUCT_EXPORT, 'Item Id|%SAFESKU';						# required
		push @CSV_PRODUCT_EXPORT, 'Action Flag|';								# optional, indicate D for DELETE
		push @CSV_PRODUCT_EXPORT, 'FBS Item|No';								# required, Yes=>Sell on Sears item (Fulfillment By Sears)
		push @CSV_PRODUCT_EXPORT, 'Variation Group ID|';					# optional, group id to associate variations together in your inventory
		push @CSV_PRODUCT_EXPORT, 'Title|zoovy:prod_name';					# required
 		push @CSV_PRODUCT_EXPORT, 'Short Description|zoovy:prod_desc';	# required, NEED to STRIP HTML/WIKI
 		push @CSV_PRODUCT_EXPORT, 'Long Description|';						# optional, NEED to STRIP HTML/WIKI
  		push @CSV_PRODUCT_EXPORT, 'Packing Slip Description|';			# NA (only used for FBS)
  		push @CSV_PRODUCT_EXPORT, 'Category|sears:category';				# required
  		push @CSV_PRODUCT_EXPORT, 'UPC|zoovy:prod_upc';						# optional
  		push @CSV_PRODUCT_EXPORT, 'Manufacturer Model #|zoovy:mfgid';	# required (40 characters max, letters, number, dash, underscores only)
  		push @CSV_PRODUCT_EXPORT, 'Cost|';										# NA (only used for FBS)
  		push @CSV_PRODUCT_EXPORT, 'Standard Price|zoovy:base_price';	# required (US dollars, without a $ sign, commas, text, or quotation marks)
  		push @CSV_PRODUCT_EXPORT, 'Sale Price|';								# optional (US dollars, without a $ sign, commas, text, or quotation marks)
  		}
	elsif ($MKT eq 'EGG') {
		# push @BC, { name=>$MARKETPLACE,link=>'/biz/syndication/newegg/index.cgi','target'=>'_top', };
		#push @TABS, { selected=>($VERB eq 'FILES')?1:0, 'name'=>'Files', 'link'=>"$PATH?VERB=FILES&PROFILE=$PROFILE" };
		#push @TABS, { name=>"Categories", selected=>($VERB eq 'CATEGORIES')?1:0, link=>"$PATH?VERB=CATEGORIES&PROFILE=$PROFILE", };
		push @FIELDS, { align=>'left', type=>'checkbox', name=>'Is Active', id=>'.enable', default=>1, hint=>"Checkbox must be selected or syndication will not be attempted." };
		push @FIELDS, { type=>'textbox', name=>'FTP User', id=>'.ftp_user', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Password', id=>'.ftp_pass', required=>1 };
		push @FIELDS, { type=>'textbox', name=>'FTP Server', id=>'.ftp_server', required=>1 };
	   }
	else {
		&JSONAPI::set_error(\%R,'apperr',39102,sprintf('Unknown DST code \'%s\'',$DST));
		}

	## some of the syndications can create a generic product csv export.
	if (scalar(@CSV_PRODUCT_EXPORT)>0) {
		## commenting out until this is ready to go to production.
		#push @TABS, { name=>"Product Export", selected=>($VERB eq 'PRODUCT-CSV')?1:0, link=>"$PATH?VERB=PRODUCT-CSV&PROFILE=$PROFILE", };
		}

	my ($so) = undef;
	#my ($DOMAIN) = $self->domain();
	if (defined $DST) {
		# print STDERR "$USERNAME,$DST,\n";
		($so) = SYNDICATION->new($USERNAME,$DST,'DOMAIN'=>$self->sdomain(),'PRT'=>$self->prt(),'AUTOCREATE'=>1,'type'=>'config');
		}

	if (&JSONAPI::hadError(\%R)) {
		}
 	elsif ($v->{'_cmd'} eq 'adminSyndicationList') {
		## my $profref = &DOMAIN::TOOLS::syndication_profiles($USERNAME,PRT=>$PRT);
		## probably better ways to deal with this... maybe change /httpd/servers/syndication/batch.pl instead
		## some syndications [SRS currently, but more to come] only syndicate inv, so PUBLISH NOW link should 
		##		default to the INVENTORY FEEDTYPE
		my @SYNDICATIONS = ();
		foreach my $int (@ZOOVY::INTEGRATIONS) {
			next unless ($int->{'grp'} eq 'MKT');
			my $DST = $int->{'dst'};
			my ($so) = SYNDICATION->new($USERNAME,$DST,'PRT'=>$self->prt(),'DOMAIN'=>$self->sdomain(),'type'=>'config');
			my ($enabled,$suspended) = (0,0);
			if (defined $so) {
				$enabled = $so->get('IS_ACTIVE');
				$suspended = $so->get('IS_SUSPENDED');
				}
			push @SYNDICATIONS, { 'mkt'=>$DST, 'enabled'=>$enabled, 'suspended'=>$suspended };
			}
		$R{'@SYNDICATIONS'} = \@SYNDICATIONS;
		}
	elsif (not defined $v->{'DST'}) {
		&JSONAPI::set_error(\%R,'apperr',30993,"syndication object could not be loaded because DST value was not provided..");
		}
	elsif (not defined $so) {
		&JSONAPI::set_error(\%R,'apperr',30992,"syndication object ($DST) could not be loaded or was corrupt.");
		}
	elsif ($v->{'_cmd'} eq 'adminSyndicationDetail') {
		tie my %s, 'SYNDICATION', THIS=>$so;

		#my $nsref = $so->nsref();
		#if ($nsref->{'zoovy:site_rootcat'} eq '') { $nsref->{'zoovy:site_rootcat'} = '.'; }
		#$R{'root'} = $nsref->{'zoovy:site_rootcat'};
		#$R{'prt'} = $nsref->{'prt:id'};
		$R{'root'} = undef;
		$R{'prt'} = undef;

		$R{'linkstyle'} = 'vstore' || $so->get('.linkstyle');
		foreach my $fref (@FIELDS) {
			## removes periods.
			$R{ substr($fref->{'id'},1) } = $s{ $fref->{'id'} };
			}
	
		if ($DST eq 'AMZ') {
			my $feedpermissions = $so->get('.feedpermissions');
			$R{'feed_inventory'} = ($feedpermissions&1)?1:0;
			$R{'feed_price'} = ($feedpermissions&2)?1:0;
			$R{'feed_product'} = ($feedpermissions&4)?1:0;

			## FBA Settings
			## - check if merchant wants us to import FBA Order and Tracking
			##	- Tracking includes orders that originate from Amazon 
			##		and those that are manually put into FBA via the merchant (ie manual FWS)
			$R{'fbapermissions'} = $so->get('.fbapermissions');
			$R{'orderpermissions'} = $so->get('.orderpermissions');

			## check to make sure they only have one profile enabled for syndication!
			my $pstmt = "select ID,DOMAIN from SYNDICATION where MID=$MID /* $USERNAME */ and DSTCODE='AMZ'";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			my @ACTIVE = ();
			if (($so->get('.feedpermissions')&7)>0) { push @ACTIVE, $so->dbid(); }
			while ( my ($ID,$DST,$DOMAIN) = $sth->fetchrow() ) { 
				next if ($so->dbid() == $ID);
				my ($so2) = SYNDICATION->new($USERNAME,"AMZ",'ID'=>$ID,'DOMAIN'=>$DOMAIN,'type'=>'config');
				if ( ($so2->get('.feedpermissions')&7)>0) {
					push @ACTIVE, $ID; 
					}	
				}
			$sth->finish();
			if (scalar(@ACTIVE)>1) {
				&JSONAPI::append_msg_to_response(\%R,'warning',30993,"You must only have one partition setup to transmit products/inventory currently partitions:" .join(',',@ACTIVE)." have products configured to syndicate.");
				}

			my ($userref) = AMAZON3::fetch_userprt($USERNAME,$PRT);
			## if Product Syndication has been turned, ALERT merchant
			#if ($s{'IS_ACTIVE'}==0) {
			#	push @MSGS, "WARN|all syndication has been turned off";
			#	}

			$R{'private_label'} = $s{'.private_label'};
			$R{'upc_creation'} = $s{'.upc_creation'};			
			## $R{'mws_token'} = $userref->{'AMAZON_MWSTOKEN'};

			my $MAP = $so->get('.shipping');
			my $MAPREF = ZTOOLKIT::parseparams($MAP);
			my @SHIPPING_MAPS = ();
			foreach my $amzshiptype ("Standard", "Expedited","Scheduled","NextDay","SecondDay") {
				push @SHIPPING_MAPS, [ $amzshiptype, $MAPREF->{$amzshiptype} ];
				$R{lc("amzship_$amzshiptype")} = $MAPREF->{$amzshiptype};
				}
			# $R{'@SHIPPING_MAPS'} = \@SHIPPING_MAPS;


			## adminSyndicationAMZThesaurii  Thesauruses
			my @THESAURII = ();
			$pstmt = "select ID as THID,
				NAME as name,
				GUID as guid,
				ITEMTYPE as itemtype,
				USEDFOR as usedfor,
				SUBJECTCONTENT as subjectcontent,
				OTHERITEM as otheritem,
				TARGETAUDIENCE as targetaudience,
				ADDITIONALATTRIBS as additionalattribs,
				ISGIFTWRAPAVAILABLE as isgiftwrapavailable,
				ISGIFTMESSAGEAVAILABLE as isgiftmessageavailable,
				SEARCH_TERMS as search_terms
				from AMAZON_THESAURUS where MID=$MID order by NAME";

			$sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my $ref = $sth->fetchrow_hashref()) {
				## note: THID is no longer used as of 201334
				push @THESAURII, $ref;
				}
			$sth->finish();
			$R{'@THESAURII'} = \@THESAURII;
			}
		elsif ($DST eq 'GOO') {
			$R{'navcat_skiphidden'} = (($s{'.feed_options'}&1)>0)?1:0;
			$R{'navcat_skiplists'} = (($s{'.feed_options'}&4)>0)?1:0;
			$R{'include_shippping'} = (($s{'.include_shipping'}&1)>0)?1:0;
			$R{'ignore_validation'} = (($s{'.ignore_validation'}&1)>0)?1:0;
			# $s{'.ignore_validation'} = 0;
			}	

		$R{'enable'} = $s{'IS_ACTIVE'};
		$R{'schedule'} = $s{'.schedule'};
		}
	elsif ($v->{'_cmd'} eq 'adminSyndicationFeedErrors') {
		my @RESULTS = ();

		my $pstmt = "select CREATED_GMT,SKU,FEED,ERRCODE,ERRMSG,BATCHID from SYNDICATION_PID_ERRORS where MID=$MID /* $USERNAME */  and DSTCODE=".$udbh->quote($so->dstcode())." ";
		$pstmt .= " and ARCHIVE_GMT=0 ";
		$pstmt .= " order by CREATED_GMT desc limit 0,500";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my @row = $sth->fetchrow() ) {
			push @RESULTS, \@row;
			}
		$sth->finish();
		$R{'@ROWS'} = \@RESULTS;
		}
	elsif ($v->{'_cmd'} eq 'adminSyndicationHistory') {
		my @RESULTS = ();
		require TXLOG;
		my @ROWS = ();
		foreach my $line (reverse split(/\n/,$so->{'TXLOG'})) {
			my ($UNI,$TS,$PARAMSREF) = TXLOG::parseline($line);
			push @ROWS, [ $UNI, $TS, $PARAMSREF->{'+'} ];
			}
		$R{'@ROWS'} = \@ROWS;
		}
	elsif ($v->{'_cmd'} eq 'adminSyndicationBUYDownloadDBMaps') {
		require SYNDICATION::BUYCOM;
		my @maps = &SYNDICATION::BUYCOM::fetch_dbmaps($USERNAME);
		$R{'@MAPS'} = \@maps;
		}
	elsif ($v->{'_cmd'} eq 'adminSyndicationAMZOrders') {
		require CART2;
		## only select from the last 50 days
		my $pstmt = "select CREATED_GMT,AMAZON_ORDERID,OUR_ORDERID from AMAZON_ORDERS ".
					"where CREATED_GMT >unix_timestamp(now())-(50*86400) and FULFILLMENT_ACK_REQUESTED_GMT>0 and FULFILLMENT_ACK_PROCESSED_GMT=0 and MID=".$udbh->quote($MID).
					" and PRT=$PRT /* $USERNAME */ and OUR_ORDERID <> '' order by ID desc";
		print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute;
		my @ORDERS = ();
		while ( my $ref = $sth->fetchrow_hashref() ) {
			my $cancelled = 0;
			my ($O2) = CART2->new_from_oid($USERNAME,$ref->{'OUR_ORDERID'});
			if (not defined $O2) {
				$cancelled = 1;
				}
			elsif (defined $O2->in_get('flow/cancelled_ts') && $O2->in_get('flow/cancelled_ts') > 0) {
				$cancelled = 1;
				}
			$ref->{'cancelled'} = $cancelled;
			push @ORDERS, $ref;
			}		
 		$sth->finish;
		$R{'@ORDERS'} = \@ORDERS;
		}
	elsif ($v->{'_cmd'} eq 'adminSyndicationListFiles') {
		require LUSER::FILES;
		my ($LF) = LUSER::FILES->new($USERNAME,LU=>$LU);
		my $results = $LF->list(type=>$DST);
		my @FILES = ();
		foreach my $file (@{$results}) {
			push @FILES, $file;
			}
		$R{'@FILES'} = \@FILES;
		}
	elsif ($v->{'_cmd'} eq 'adminSyndicationDebug') {
		my ($feed_type) = $v->{'FEEDTYPE'};
		if (not JSONAPI::validate_required_parameter(\%R,$v,'FEEDTYPE',['PRODUCT','INVENTORY'])) {
			}
		else {
			my ($PID) = $v->{'PID'};

			my ($lm) = $so->runDebug(type=>$feed_type,TRACEPID=>$PID);
			my $out = '';
			foreach my $msg (@{$lm->msgs()}) {
				my ($d) = LISTING::MSGS::msg_to_disposition($msg);

				my $type = $d->{'_'};
				my $style = '';
				if ($type eq 'HINT') { 
					$style = 'style="color: green; border: thin dashed;"'; 
					}
				elsif (($type eq 'GOOD') || ($type eq 'SUCCESS') || ($type eq 'PAUSE')) { 
					$style = 'style="color: blue"'; 
					}
				elsif (($type eq 'FAIL') || ($type eq 'STOP') || ($type eq 'PRODUCT-ERROR')) { 
					$style = 'style="color: red"'; 
					}
				elsif ($type eq 'ISE') {
					$style = 'style="color: red; font-weight: heavy";';
					}
				elsif (($type eq 'WARN')) { 
					$style = 'style="color: orange; border: thin dashed;"'; 
					}
				elsif ($type eq 'DEBUG') {
					$style = 'style="color: gray;"';
					}
				elsif ($type eq 'INFO') { 
					$style = 'style="font-size: 8pt; color: CCCCCC;"'; 
					}
				else {
					}
				$out .= "<div $style>$type: $d->{'+'}</div>";
				}

			$R{'HTML'} = $out;
			}
		}
	elsif ($v->{'_cmd'} eq 'adminSyndicationAMZLogs') {
		my ($TB) = &ZOOVY::resolve_lookup_tb($USERNAME,$MID);
		my $pstmt = "select PID,SKU,AMZ_FEEDS_ERROR,AMZ_FEEDS_TODO,AMZ_ERROR from $TB where MID=$MID /* $USERNAME */ and AMZ_FEEDS_ERROR>0  order by AMZ_PRODUCTDB_GMT  desc limit 0,1000";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		require TXLOG;
		my @ROWS = ();
		while ( my ($product,$sku,$feed_error,$feed_todo,$errmsg) = $sth->fetchrow() ) {
			my $txmsgs = '';
			my $tx = TXLOG->new($errmsg);
			foreach my $feed (split(/,/,&AMAZON3::describe_bw($feed_error))) {
				if ($feed eq 'init') { $feed = 'products'; }	## there are no errors for init per se.
				my ($UNI,$TS,$PARAMSREF) = $tx->get($feed);	
				my $txmsg = '';
				my $txmsgtype = '?';
				if (not defined $UNI) {
					$TS = 0;
					}
				else {
					$txmsg = $PARAMSREF->{'+'};
					if ($txmsg eq '') { $txmsg = 'No error message was provided'; }
					$txmsgtype = $PARAMSREF->{'_'};
					}
				my %ROW = ();
				$ROW{'pid'} = $product;
				$ROW{'sku'} = $sku;
				$ROW{'feed'} = $feed;
				$ROW{'ts'} = $TS;
				$ROW{'msgtype'} = $txmsgtype;
				$ROW{'msg'} = $txmsg;
				push @ROWS, \%ROW;
				}
			}
		$sth->finish();
		$R{'@ROWS'} = \@ROWS;			
		}
	elsif ($v->{'_cmd'} eq 'adminSyndicationPublish') {
		## .FEEDTYPE
		my $FEEDTYPE = $v->{'FEEDTYPE'};
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'FEEDTYPE',['PRODUCT','INVENTORY'])) {
			## PRODUCTS,IMAGES,ORDERS,ORDERSTATUS,TRACKING,INVENTORY,SHIPPING,ACCESSORIES,RELATIONS,PRICING
			}
		else {
			require URI::Escape;
			#$PROFILE = URI::Escape::uri_escape($PROFILE);
			#$FEEDTYPE = URI::Escape::uri_escape($FEEDTYPE);

			require BATCHJOB;
			my $GUID = &BATCHJOB::make_guid();
			my %VARS = ( 'VERB'=>'ADD', 'DST'=>$DST, 'FEEDTYPE'=>$FEEDTYPE );
			my ($bj) = BATCHJOB->create($USERNAME,
				PRT=>$PRT,
				DOMAIN=>$self->sdomain(),
				GUID=>$v->{'GUID'},
				EXEC=>sprintf('SYNDICATION/%s',$DST),
				'%VARS'=>\%VARS,
				'*LU'=>$LU,
				);
			if (not defined $bj) {
				&JSONAPI::set_error(\%R,'apierr',32921,'Could not create/start job');
				}
			else {
				$bj->start();
				&JSONAPI::set_error(\%R,'success',0,"BATCH:".$bj->id()."|+Job ".$bj->id()." has been started.");
				$R{'jobid'} = $bj->id();
				}
			}
		}
	elsif ($v->{'_cmd'} eq 'adminSyndicationMacro') {
		my @CMDS = ();
		if (not defined $v->{'@updates'}) {
			&JSONAPI::set_error(\%R,'apperr',34002,'Could not find any @updates for syndication');
			}
		elsif (ref($v->{'@updates'}) eq 'ARRAY') {
			$self->parse_macros($v->{'@updates'}, \@CMDS);
			}

		my ($NC) = undef;
		foreach my $CMDSET (@CMDS) {
			my $ERROR = undef;
			my ($VERB,$params,$line,$count) = @{$CMDSET};

			if ($VERB eq 'DELETE') {
  				$so->nuke();
				}
			elsif ($VERB eq 'ENABLE') {
				$so->set('IS_ACTIVE',1);
				}
			elsif ($VERB eq 'DISABLE') {
				$so->set('IS_ACTIVE',0);
				}
			elsif ($VERB eq 'UNSUSPEND') {
				$so->set('IS_SUSPENDED',0);
				}
			elsif ($VERB eq 'SAVE') {
				tie my %s, 'SYNDICATION', THIS=>$so;

				## (almost!!) all syndication use FTP settings to push feeds
				foreach my $fref (@FIELDS) {
					my $user_data = $params->{ $fref->{'id'} };
					if (not defined $user_data) { $user_data = $params->{ substr($fref->{'id'},1) }; }	# sometimes we don't get the leading .
					if ($fref->{'type'} eq 'checkbox') {
						## checkboxes are special! converts to 1/0
						$user_data = ($user_data eq 'on')?1:0;
						}

					$user_data =~ s/^[\s]+//gs;	 # strip leading space
					$user_data =~ s/[\s]+$//gs;	# strip trailing space
					if ($fref->{'id'} eq '.ftp_server') {
						$user_data =~ s/^ftp\:\/\///igs;
						if ($user_data =~ /[^A-Za-z0-9\.\-]+/) { $ERROR = "$MARKETPLACE FTP Server contains invalid characters (perhaps you're sending a URI?)"; }
						elsif (($DST eq 'BCM') && ($user_data !~ /\.become\.com$/)) { $ERROR = "FTP server [$user_data] does not end with .become.com - it's probably not valid!"; }
						elsif (($DST eq 'GOO') && ($user_data !~ /google\.com$/)) { $ERROR = "FTP server does not end with .google.com - it's probably not valid!"; }
						}
					elsif ($fref->{'id'} eq '.linkshare_mid') {
						if ($user_data==0) { $ERROR = "Linkshare Merchant ID is required"; }
						}
			
					$s{ $fref->{'id'} } = $user_data;
					if (($fref->{'required'}) && ($user_data eq '')) {
						$ERROR = "$MARKETPLACE $fref->{'name'} is required";
						}
					}

				## it doesnt appear that username or password is required for FTP but we will store for tech troubleshooting
				if ($DST eq 'GOO') {
					$s{'.feed_options'} = 0;
					$s{'.feed_options'} |= ($params->{'navcat_skiphidden'})?1:0;
					$s{'.feed_options'} |= ($params->{'navcat_skiplists'})?4:0;
					$s{'.upc_exempt'} = (&ZOOVY::is_true($params->{'upc_exempt'}))?1:0;
					$s{'.include_shipping'} = (&ZOOVY::is_true($params->{'include_shipping'}))?1:0;
					$s{'.ignore_validation'} = (&ZOOVY::is_true($params->{'ignore_validation'}))?1:0;
					$s{'.trusted_feed'} = (&ZOOVY::is_true($params->{'trusted_feed'}))?1:0;
					}

				if ($DST eq 'AMZ') {
					$s{'.fbapermissions'} = ($params->{'fba_permissions'})?1:0;
					$s{'.orderpermissions'} = ($params->{'order_permissions'})?1:0;
					$s{'.private_label'} = ($params->{'private_label'})?1:0;
					$s{'.upc_creation'} = ($params->{'upc_creation'})?1:0;
					$s{'.emailconfirmations'} = 1; # Always set to 1 to suppress email
		
					my $FEED_PERMISSIONS = 0;
					$FEED_PERMISSIONS |= ($params->{'feed_inventory'})?1:0;		## inventory
					$FEED_PERMISSIONS |= ($params->{'feed_price'})?2:0;				## prices/shipping
					$FEED_PERMISSIONS |= ($params->{'feed_product'})?4:0;			## products/relations/images
					if ($FEED_PERMISSIONS==0) {
						}
					elsif ($s{'.orderpermissions'}==0) {
						$FEED_PERMISSIONS = 0;
						$ERROR = "Products/Inventory/Pricing cannot be enabled without ORDER processing also enabled.";
						}
					$s{'.feedpermissions'} = $FEED_PERMISSIONS;
		
					if ($FEED_PERMISSIONS > 0) {
						my ($gref) = $self->globalref();
						if ((not defined $gref->{'amz_prt'}) || ($gref->{'amz_prt'} != $PRT)) {
							## amz_prt ensures that product feeds are only sent from one partition 
							&JSONAPI::add_macro_msg(\%R,$CMDSET,"SUCCESS|+Configured amazon to send products from prt# $PRT");
							$LU->log("SETUP.AMAZON","Configured amazon to send products from prt# $PRT");
							$gref->{'amz_prt'} = $PRT;
							&ZWEBSITE::save_globalref($USERNAME,$gref);
							}
						}
					if ((not $s{'.feedpermissions'}) && (not $s{'.orderpermissions'}) && (not $s{'.fbapermissions'})) {
						&JSONAPI::add_macro_msg(\%R,$CMDSET,"WARNING|+Due to current configuration - syndication has been disabled.");
						$s{'IS_ACTIVE'} = 0;
						}
					}

				## done with validation

				$s{'.schedule'} = $params->{'SCHEDULE'};
				if (defined $ERROR) {
					}
				else {
					if ($s{'IS_SUSPENDED'}>0) {
						$s{'IS_SUSPENDED'} = 0;
						$so->appendtxlog("SETUP","Set IS_SUSPENDED=0 by ".$self->luser());
						}
					$so->save();
					}
				untie %s;
				}
			elsif ($VERB eq 'DBMAP-NUKE') {
				my $pstmt = "delete from BUYCOM_DBMAPS where MID=$MID /* $USERNAME */ and ID=".int($params->{'MAPID'});
				print STDERR $pstmt."\n";
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
				&DBINFO::db_user_close();
				}
			elsif ($VERB eq 'DBMAP-SAVE') {
				if (($ERROR eq '') && ($params->{'CATID'} eq '')) {
					$ERROR = "CatID not defined.";
					}
				if (($ERROR eq '') && ($params->{'STOREID'} == 0)) {
					$ERROR = "StoreID not defined.";
					}
				if (($ERROR eq '') && ($params->{'MAPID'} eq '')) {
					$ERROR = "MapID cannot be blank.";
					}
				if (($ERROR eq '') && ($params->{'MAPTXT'} eq '')) {
					$ERROR = "You must specify some JSON in the DBMAP";
					}
				if ($ERROR eq '') {
					require JSON;
					my $json = JSON->new();
					my $txt = $params->{'MAPTXT'};
					$txt =~ s/[\r]+//g;
					my $p = eval { $json->decode($txt) } or $ERROR = "JSON Validation Error: $@";
					$ERROR =~ s/ at \/.*?$//;	 ## get rid of at /httpd/htdocs/.... line 120
					if ($ERROR =~ /offset ([\d]+) /) {
						my ($offset) = int($1);
						my $bytes = 0;
						my $linecount = 0;
						foreach my $line (split(/[\n]/,$txt)) {
							$linecount++;
							if ( (($bytes+length($line)+5) >= $offset) && ($offset>=$bytes) ) {
								$ERROR .= "\nLINE[$linecount] $line";
								}
							$bytes += length($line)+1;
							}
						}
					if (($ERROR eq '') && (int($params->{'CATID'})==0)) {
						## DBMAPS with CategoryID==0 means we need to be setting buycom:categoryid in the dbmap as an attribute.
						## this is a *required* field.
						my $found = 0;
						foreach my $dbmapset (@{$p}) {
							if ($dbmapset->{'id'} eq 'buycom:categoryid') { $found++; }
							}
						if (not $found) {
							$ERROR = "Please specify the buycom:categoryid product attribute in the dbmap to use CategoryID 0";
							}
						}
					}
				if (not defined $ERROR) {
					&DBINFO::insert($udbh,'BUYCOM_DBMAPS',{
						USERNAME=>$USERNAME, MID=>$MID,
						MAPID=>uc($params->{'MAPID'}),
						STOREID=>int($params->{'STOREID'}),
						CATID=>int($params->{'CATID'}),
						MAPTXT=>$params->{'MAPTXT'},
						},key=>['MID','MAPID']);
					&JSONAPI::add_macro_msg(\%R,$CMDSET,"SUCCESS|+Added DBMAP $params->{'MAPID'}");
					}
				}	
			elsif ($VERB eq 'AMZ-TOKEN-UPDATE') {
				$so->set('.aws_mktid',$params->{'marketplaceId'});
				$so->set('.aws_mid',$params->{'merchantId'});
				$so->set('.amz_token',sprintf("marketplaceId=%s&merchantId=%s",$params->{'marketplaceId'},$params->{'merchantId'}));
				$so->save();
				}
			elsif ($VERB eq 'AMZ-THESAURUS-DELETE') {
				if ($self->apiversion() < 201334) {
					my $pstmt = "delete from AMAZON_THESAURUS where MID=$MID and ID=".int($params->{'ID'});
					print STDERR $pstmt."\n";
					&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
					}
				else {
					my $pstmt = "delete from AMAZON_THESAURUS where MID=$MID and GUID=".$udbh->quote($params->{'guid'});
					print STDERR $pstmt."\n";
					&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
					}
				}
			elsif ($VERB eq 'AMZ-THESAURUS-SAVE') {
				## Thesaurus 
				my $name = $params->{'name'};
				$name = uc($name);
				$name =~ s/[^\w]+/_/gs;

				my ($ID,$GUID) = (0,undef);
				if (($ID>0) && (defined $params->{'guid'})) {
					my $pstmt = "select ID from AMAZON_THESAURUS where MID=$MID and GUID=".$udbh->quote($params->{'guid'});
					($ID) = $udbh->selectrow_array($pstmt);
					}
				if (($ID>0) && (defined $params->{'name'})) {
					my $pstmt = "select ID from AMAZON_THESAURUS where MID=$MID and NAME=".$udbh->quote($params->{'name'});
					($ID) = $udbh->selectrow_array($pstmt);
					}

				my %vars = (
					ID=>$ID,
					MID=>$MID, 
					GUID=>$params->{'guid'},
					USERNAME=>$USERNAME,
					NAME=>sprintf("%s",$name),
					ITEMTYPE=>sprintf("%s",$params->{'itemtype'}),
					SEARCH_TERMS=>sprintf("%s",$params->{'search_terms'}),
					SUBJECTCONTENT=>sprintf("%s",$params->{'subjectcontent'}),
					TARGETAUDIENCE=>sprintf("%s",$params->{'targetaudience'}),
					ISGIFTWRAPAVAILABLE=>sprintf("%d",$params->{'isgiftwrapavailable'}),
					ISGIFTMESSAGEAVAILABLE=>sprintf("%d",$params->{'isgiftmessageavailable'})
					);
				if (not defined $vars{'GUID'}) { $vars{'GUID'} = Data::GUID->new()->as_string();  }

				if ($params->{'guid'}) {
					my $pstmt = "delete from AMAZON_THESAURUS where MID=$MID and GUID=".$udbh->quote($params->{'guid'});
					&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
					}
				if ($params->{'name'}) {
					my $pstmt = "delete from AMAZON_THESAURUS where MID=$MID and NAME=".$udbh->quote($params->{'name'});
					&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
					}

				$params->{'search_terms'} =~ s/\s+/ /g;
				$params->{'search_terms'} =~ s/, /,/g;
				$params->{'search_terms'} = substr($params->{'search_terms'},0,250);
				my ($pstmt) = &DBINFO::insert($udbh,'AMAZON_THESAURUS',\%vars,sql=>1,verb=>'insert');
				print STDERR "$pstmt\n";
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
				}
			elsif ($VERB eq 'AMZ-SHIPPING-SAVE') {
				print STDERR "VERB: $VERB\n";
				$VERB = 'AMAZON-SHIPPING';
				my $mapref = {};
				## THE NEW WAY:
				foreach my $amzshiptype ("Standard", "Expedited","Scheduled","NextDay","SecondDay") {
					$mapref->{ $amzshiptype } = $params->{$amzshiptype};
					## possible values: ("Standard", "Expedited","Scheduled","NextDay","SecondDay") {
					}
				## THE OLD WAY:
				my $map = ZTOOLKIT::buildparams($mapref);
				my ($so) = SYNDICATION->new($USERNAME,"AMZ","PRT"=>"$PRT",'type'=>'config');
				$so->set('.shipping',$map);
				$so->save();
				}
			#elsif ($VERB eq 'BATCH-UPDATE') {
			#	if (not defined $NC) { $NC = NAVCAT->new($USERNAME,PRT=>$PRT); }
			#	my $batchregex = '^'.quotemeta($params->{'batch-path'});
			#	foreach my $safe (sort $NC->paths($ROOTPATH)) {
			#		next unless ($safe =~ /$batchregex/);
			#		print STDERR "SAVED: $safe\n";
			#		my ($pretty, $children, $productstr, $sortby, $metaref) = $NC->get($safe);
			#		$metaref->{$DST} = $params->{'batch-category'};
			#		$NC->set($safe,metaref=>$metaref);
			#		}
			#	$NC->save(); 
			#	$VERB = 'CATEGORIES';
			#	}
			#elsif ($VERB eq 'SAVE-AMAZON-CATEGORIES') {
			#	my $changed = 0;
			#	if (not defined $NC) { ($NC) = NAVCAT->new($USERNAME,PRT=>$PRT); }
			#	foreach my $safe (sort $NC->paths()) {
			#		next if (not defined $params->{'navcat-'.$safe});
			#		#next if ($q->param('navcat-'.$safe) eq '');
			#		my ($pretty, $children, $productstr, $sortby, $metaref) = $NC->get($safe);
			#		next if ($metaref->{'AMAZON_THE'} eq $params->{'navcat-'.$safe});
			#		$metaref->{'AMAZON_THE'} = $params->{'navcat-'.$safe};
			#		$NC->set($safe,metaref=>$metaref);
			#		}
			#	$NC->save();
			#	}	
			#elsif ($VERB eq 'SAVE-EBAY-CATEGORIES') {
			#	if (not defined $NC) { $NC = NAVCAT->new($USERNAME,PRT=>$PRT); }
			#	foreach my $safe ($NC->paths()) {
			#		next if (not defined $params->{'navcat-'.$safe});
			#		my ($pretty, $children, $productstr, $sortby, $metaref) = $NC->get($safe);
			#		next if (($metaref->{'EBAYSTORE_CAT'} eq $params->{'navcat-'.$safe}) && ($metaref->{'EBAY_CAT'} eq $params->{'ebay-'.$safe}));
			#		$metaref->{'EBAYSTORE_CAT'} = $params->{'navcat-'.$safe};
			#		$metaref->{'EBAY_CAT'} = $params->{'ebay-'.$safe};
			#		$NC->set($safe,metaref=>$metaref);
			#		}
			#	$NC->save();
			#	push @MSGS, "SUCCESS|Updated eBay.com/eBay Store relationships with Website Categories";
			#	}
			#elsif ($VERB eq 'SAVE-CATEGORIES') {
			#	if (not defined $NC) { ($NC) = NAVCAT->new($USERNAME,PRT=>$PRT); }
			#	foreach my $safe (sort $NC->paths($ROOTPATH)) {
			#		my ($pretty, $children, $productstr, $sortby, $metaref) = $NC->get($safe);
			#		my $SUBMIT = ($params->{'navcat-'.$safe} ne '')?$params->{'navcat-'.$safe}:'';
			#		if ($SUBMIT eq '- Ignore -') { $SUBMIT = ''; }
			#		## googlebase has GOO as DSTCODE and GOOGLEBASE as navcatMETA
			#		## - product syndication and index.cgi?VERB=CATEGORIES currently use the navcatMETA vs DSTCODE
			#		#$metaref->{$DST} = $SUBMIT;
			#		$metaref->{$DST} = $SUBMIT;
			#		$NC->set($safe,metaref=>$metaref);
			#		}
			#	$NC->save();
			#	}
			elsif ($VERB eq 'CLEAR-FEED-ERRORS') {
				my $pstmt = "update SYNDICATION_PID_ERRORS set ARCHIVE_GMT=$^T where MID=$MID /* $USERNAME */ and DSTCODE=".$udbh->quote($so->dstcode());
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
				}

			if (defined $ERROR) {
				&JSONAPI::add_macro_msg(\%R,$CMDSET,"ERROR|+$ERROR");
				}
			else {
				&JSONAPI::add_macro_msg(\%R,$CMDSET,"SUCCESS|+$VERB Completed");
				}
			
			}
		&JSONAPI::append_msg_to_response(\%R,'success',0);				

		## NOTE: each macro will save on it's own
		}
	else {
		&JSONAPI::set_error(\%R,'apperr',120,"invalid _cmd");
		}


	&DBINFO::db_user_close();
	return(\%R);
	}

















=pod

<API id="adminAffiliateList">
<purpose>returns a list of projects</purpose>
</API>

<API id="adminAffiliateCreate">
<purpose></purpose>
Not finished
</API>

<API id="adminAffiliateRemove">
<purpose></purpose>
Not finished
</API>

<API id="adminAffiliateUpdate">
<purpose></purpose>
Not finished
</API>

<API id="adminAffiliateDetail">
<purpose></purpose>
Not finished
</API>


=cut

sub adminAffiliate {
	my ($self,$v) = @_;

	my %R = ();

	require PROJECT;

	my $USERNAME = $self->username();
	my $LU = $self->LU();
	my $MID = $self->mid();
	my $PRT = $self->prt();


#if ($VERB eq 'ENROLL-SAVE') {
#	my ($EMAIL) = $v->{'EMAIL'};
#	my ($c) = CUSTOMER->new($USERNAME,EMAIL=>$EMAIL,PRT=>$CPRT,CREATE=>3,INIT=>0x1);
#	$c->set_attrib('INFO.IS_AFFILIATE',int($v->{'PACKAGE'}));
#	$c->save();
#	$VERB = 'ENROLL';
#	}

#if ($VERB eq 'ENROLL') {
#	my $c = '';
#	my $pstmt = "select ID,OFFER_TITLE from AFFILIATE_PACKAGES where MID=$MID /* $USERNAME */ and PRT=$CPRT order by ID desc";
#	print STDERR $pstmt."\n";
#	my $sth = $udbh->prepare($pstmt);
#	$sth->execute();
#	while ( my ($ID,$TITLE) = $sth->fetchrow() ) {
#		$c .= "<option value=\"$ID\">$TITLE</option>";
#		}
#	$sth->finish();
#	$template_file = 'enroll.shtml';
#	}


#if ($VERB eq 'PACKAGE-NUKE') {
#	my $pstmt = "delete from AFFILIATE_PACKAGES where MID=$MID /* $USERNAME */ and PRT=$CPRT and ID=".int($v->{'ID'});
#	print STDERR $pstmt."\n";
#	&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
#	$VERB = '';
#	}

#if ($VERB eq 'PACKAGE-SAVE') {
#	&DBINFO::insert($udbh,'AFFILIATE_PACKAGES',{
#		MID=>$MID,USERNAME=>$USERNAME,PRT=>$CPRT,
#		OFFER_TITLE=>$v->{'TITLE'},
#		ORDER_BOUNTY_FEE=>sprintf("%.2f",$v->{'ORDER_BOUNTY_FEE'}),
#		ORDER_BOUNTY_PCT=>sprintf("%.2f",$v->{'ORDER_BOUNTY_PCT'}),
#		});
#	$VERB = '';
#	}

#if ($VERB eq 'PACKAGE-NEW') {
#	$template_file = 'new.shtml';
#	}

#if ($VERB eq '') {
#	$template_file = 'index.shtml';
#
#	my (%cids) = CUSTOMER::BATCH::list_customers($USERNAME,$CPRT,IS_AFFILIATE=>1,HASHKEY=>'CID');
#	print STDERR Dumper(\%cids);
#	my %PROGRAM_COUNTS = ();
#	foreach my $cid (keys %cids) {
#		$PROGRAM_COUNTS{ $cids{$cid}->{'IS_AFFILIATE'} }++;
#		}
#
#	my $c = '';
#	my $pstmt = "select * from AFFILIATE_PACKAGES where MID=$MID /* $USERNAME */ and PRT=$CPRT";
#	my $sth = $udbh->prepare($pstmt);
#	$sth->execute();
#	while ( my $hashref = $sth->fetchrow_hashref() ) {
#		$c .= "<tr>";
#		$c .= "<td>";
#
#		if ($PROGRAM_COUNTS{ $hashref->{'ID'} }==0) {
#			## only show delete if no participants.
#			$c .= qq~<a href="/biz/manage/affiliates/index.cgi?VERB=PACKAGE-NUKE&ID=$hashref->{'ID'}">[Delete]</a>~;
#			}
#
#		$c .= "</td>";
#		$c .= "<td>".&ZOOVY::incode($hashref->{'OFFER_TITLE'})."</td>";
#		$c .= "<td>\$$hashref->{'ORDER_BOUNTY_FEE'}</td>";
#		$c .= "<td>$hashref->{'ORDER_BOUNTY_PCT'}%</td>";
#		$c .= "<td>".int($PROGRAM_COUNTS{ $hashref->{'ID'} })."</td>";
#		$c .= "</tr>";
#		}
#	$sth->finish();
#	if ($c eq '') {
#		$c .= "<tr><td colspan=5><i>No affiliate packages have been defined. Please add one</td></tr>";
#		}
#	else {
#		$c = qq~
#<tr class='zoovysub1header'>
#	<td></td>
#	<td>Title</td>
#	<td>Order-\$</td>
#	<td>Order-\%</td>
#	<td># Enrolled</td>
#</tr>
#$c
#~;
#		}
#
#
#	$c = '';
#	foreach my $cid (keys %cids) {
#		$c .= "<tr>";
#		$c .= "<td>".$cids{$cid}->{'EMAIL'}."</td>";
#		$c .= "<td>".$cids{$cid}->{'IS_AFFILIATE'}."</td>";
#		$c .= "</tr>";
#		}
#	if ($c eq '') {
#		$c .= "<tr><td colspan=5><i>No affiliates enrolled at this time.</td></tr>";
#		}
#	else {
#		$c = qq~
#<tr class="zoovysub1header">
#	<td>Customer Email</td>
#	<td>Program</td>
#</tr>
#</tr>
#$c
#~;
#		}
#
#	}

	return(\%R);
	}






=pod

<API id="adminGiftcardList">
<purpose>returns a list of projects</purpose>
</API>

<API id="adminGiftcardSeriesList">
<purpose>returns a list of projects</purpose>
</API>

<API id="adminGiftcardSearch">
</API>

<API id="adminGiftcardSetupProduct">
</API>

<API id="adminGiftcardCreate">
<purpose></purpose>
<input id="expires">YYYYMMDD</input>
<input id="balance">currency</input>
<input id="quantity">defaults to 1 (if not specified)</input>
<input id="email" optional="1">if a customer exists this will be matched to the cid, if a customer cannot be found a new customer account will be created, not compatible with qty > 1</input>
<input id="series" optional="1">a mechanism for grouping cards, usually used with quantity greater than 1</input>
</API>

<API id="adminGiftcardMacro">
<purpose></purpose>
<example>
<![CDATA[
[1:00:00 PM] Brian Horakh: @updates
[1:00:10 PM] Brian Horakh: SET/EMAIL?email=&note=
[1:00:11 PM] jt: adminGiftcardMacro
[1:00:18 PM] Brian Horakh: SET/BALANCE?email=&note=
[1:00:35 PM] Brian Horakh: SET/EXPIRES?expires=&note=
[1:00:43 PM] Brian Horakh: SET/CARDTYPE?cardtype=&note=
Not finished
]]></example>
</API>

<API id="adminGiftcardDetail">
<purpose></purpose>
Not finished
</API>

<API id="adminGiftcardSetupProduct">
<purpose>creates a product that when purchased automatically creates a giftcard</purpose>
</API>

=cut

sub adminGiftcard {
	my ($self,$v) = @_;

	my %R = ();

	require Archive::Zip;
	require PROJECT;

	my $USERNAME = $self->username();
	my $LU = $self->LU();
	my $MID = $self->mid();
	my $PRT = $self->prt();

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	require  URI::Escape;
	require GIFTCARD;
	require CUSTOMER;
	require ZWEBSITE;
	require PRODUCT;

	my ($GCID) = int($v->{'GCID'});
	my @MSGS = ();

	#my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	#if (($webdbref->{'pay_giftcard'} eq 'NONE') || ($webdbref->{'pay_giftcard'} eq '')) {
	#	my $c = qq~<div class="warning">WARNING: You do not have giftcards enabled. Please go to Setup / Payment Settings and enable this as a payment method.</div>~;
	#	}
	my $LUSERNAME = $self->luser();

	if (($v->{'_cmd'} eq 'adminGiftcardSearch') || ($v->{'_cmd'} eq 'adminGiftcardList')) {

		my %VARS = ();
		$VARS{'PRT'} = $PRT;
		$VARS{'LIMIT'} = 250; 
		$VARS{'SERIES'} = $v->{'SERIES'};

		if ($v->{'_cmd'} eq 'adminGiftcardSearch') {
			$VARS{'CODE'} = $v->{'CODE'};
			$VARS{'CODE'} =~ s/-//g;
			if (GIFTCARD::checkCode($v->{'CODE'})==0) {
				my ($cardinfo) = GIFTCARD::lookup($USERNAME,'CODE'=>$v->{'CODE'});
				if (not defined $cardinfo) {
					push @MSGS, "WARN|Sorry, the giftcard you are searching for is not valid";
					}
				}
			else {
				push @MSGS, "WARN|Giftcard number is incorrect/incomplete"; 
				}
			}

		if (scalar(@MSGS)>0) {
			$R{'@GIFTCARDS'} = [];
			}
		else {
			my $inforef = &GIFTCARD::list($USERNAME,%VARS);	
			$R{'@GIFTCARDS'} = $inforef;
			}
		}
	elsif ($v->{'_cmd'} eq 'adminGiftcardSetupProduct') {
		
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'SKU')) {
			}

		my $SKU = uc($v->{'SKU'});
		$SKU =~ s/[^\w\-]+//g;
		$SKU =~ s/^[^A-Z0-9]+//og; # strips anything which not a leading A-Z0-9
		my ($P) = PRODUCT->new($USERNAME,$SKU,'create'=>1);

		my @POGS = ();
		if ($v->{'ALLOW_NOTE'}) {
			push @POGS, {
				hint=>"Don't forget to include your name and the reason you're sending the giftcard!",
				id=>"#C",
				prompt=>"Gift Message",
				inv=>"0", type=>"textarea", maxlength=>"128", cols=>"40", rows=>"3"			
				};
			}
		if ($v->{'ALLOW_RECIPIENT'}) {
			push @POGS, {
				id=>"#B", prompt=>"Recipient Email", inv=>"0", type=>"text"
				};
			push @POGS, {
				id=>"#A", prompt=>"Recipient Name", inv=>"0", type=>"text"
				};
			};

		my $PRICE = $v->{'PRICE'};
		$PRICE =~ s/^\$//;

		$P->store('zoovy:base_price',(defined $PRICE)?sprintf("%.2f",$PRICE):'0');
		$P->store('zoovy:base_cost',(defined $PRICE)?sprintf("%.2f",$PRICE):'0');
		$P->store('zoovy:taxable',0);
		$P->store('zoovy:prod_name',($PRICE>0)?sprintf("\$%.2f GiftCard",$PRICE):'Giftcard');
		# $P->store('zoovy:inv_enable',33);
		$P->store('zoovy:fl','p-giftcard');
		$P->store('zoovy:virtual',"PARTNER:GIFTCARD");
		$P->store('zoovy:prod_desc',q~Or giftcard is the perfect one size fits all gift for any occasion!~);

		if (int($PRICE)==0) {
			$PRICE = undef;
		
			push @POGS,
				{'id'=>"#Z", 'flags'=>1, 'prompt'=>"Gift Amount", 'inv'=>0, 'type'=>'select', 'optional'=>0,
				'@options'=>[
					{ 'v'=>'05', p=>'$5', w=>'0', 'prompt'=>'$5' },
					{ 'v'=>'0A', p=>'$10', w=>'0', 'prompt'=>'$10' },
					{ 'v'=>'19', p=>'$25', w=>'0', 'prompt'=>'$25' },
					{ 'v'=>'32', p=>'$50', w=>'0', 'prompt'=>'$50' },
					{ 'v'=>'64', p=>'$100', w=>'0', 'prompt'=>'$100' },
					]
				};
			}

		$P->store_pogs(\@POGS);
		$P->folder("/GIFTCARD");
		$P->save();
		$R{'SKU'} = $SKU;
		}
	elsif ($v->{'_cmd'} eq 'adminGiftcardSeriesList') {
		$R{'@SERIES'} = GIFTCARD::list_series($USERNAME);
		}
	elsif ($v->{'_cmd'} eq 'adminGiftcardMacro') {

		if (not $GCID) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',39001,'Missing GCID on adminGiftcardMacro this will not go well.');
			}

		my @CMDS = ();
		if (&JSONAPI::hadError(\%R)) {
			## shit happened!
			}
		elsif (not defined $v->{'@updates'}) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',39002,'Could not find any @updates');
			}
		elsif (ref($v->{'@updates'}) eq 'ARRAY') {
			my $count = 0;
			foreach my $line (@{$v->{'@updates'}}) {
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					$cmdset->[1]->{'luser'} = $self->luser();
					$cmdset->[2] = $line;
					$cmdset->[3] = $count++;
					push @CMDS, $cmdset;
					}
				}
			}
	
		my @MSGS = ();
		if (not &JSONAPI::hadError(\%R)) {
			## Validation Phase
			my @LOGS = ();
			foreach my $cmdset (@CMDS) {
				my ($VERB,$params,$line,$linecount) = @{$cmdset};

				if ($VERB eq 'SET/EMAIL') {
					require CUSTOMER;
					my $CID = &CUSTOMER::resolve_customer_id($USERNAME,$PRT,$params->{'email'});
					if ($CID==0) {
						## the customer doesn't exist, create an account.
						my ($c) = CUSTOMER->new($USERNAME,PRT=>$PRT,CREATE=>2,EMAIL=>$params->{'email'});
						$c->save();
						($CID) = $c->cid();
						push @LOGS, "Created customer account #$CID";
						}
					&GIFTCARD::update($USERNAME,$GCID,LUSER=>$LUSERNAME,CID=>$CID,NOTE=>$params->{'note'});
					}
				elsif ($VERB eq 'SET/BALANCE') {
					&GIFTCARD::update($USERNAME,$GCID,LUSER=>$LUSERNAME,BALANCE=>$params->{'balance'},NOTE=>$params->{'note'});
					push @LOGS, "Balance Updated: $params->{'balance'}";
					}
				elsif ($VERB eq 'SET/EXPIRES') {
					&GIFTCARD::update($USERNAME,$GCID,LUSER=>$LUSERNAME,EXPIRES=>$params->{'expires'},NOTE=>$params->{'note'});
					push @LOGS, "Expires set $params->{'expires'}";
					}
				elsif ($VERB eq 'SET/CARDTYPE') {
					&GIFTCARD::update($USERNAME,$GCID,LUSER=>$LUSERNAME,CARDTYPE=>$params->{'cardtype'},NOTE=>$params->{'note'});
					push @LOGS, "Expires set $params->{'expires'}";
					}
				}

			foreach my $note (@LOGS) {
				GIFTCARD::addLog($USERNAME,$LUSERNAME,$GCID,$note);
				}
			}

		}
	elsif (($v->{'_cmd'} eq 'adminGiftcardCreate') || ($v->{'_cmd'} eq 'adminGiftcardUpdate')) {
		my $gcref = {};
		my @LOGS = ();

		if (($v->{'_cmd'} eq 'adminGiftcardUpdate') && (not $GCID)) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',39003,'Missing GCID on adminGiftcardUpdate this will not go well.');
			}

		my $EXPIRES_GMT = 0;
		if ($v->{'expires'}) {
			require Date::Parse;
			$EXPIRES_GMT = Date::Parse::str2time(sprintf("%s 23:59:59",$v->{'expires'})); 	
			# $EXPIRES_GMT = int($v->{'expires'});
			}

		my $BALANCE = sprintf("%.2f",$v->{'balance'});
		my $CID = 0;
		my $QUANTITY = int($v->{'quantity'});
		if ($QUANTITY==0) { $QUANTITY = 1; }
	
		if ($QUANTITY > 1) {
			## we can never create individual gift cards in bulk.
			}
		elsif ($v->{'email'} ne '') {
			require CUSTOMER;
			$CID = &CUSTOMER::resolve_customer_id($USERNAME,$PRT,$v->{'email'});
			if ($CID==0) {
				## the customer doesn't exist, create an account.
				my ($c) = CUSTOMER->new($USERNAME,PRT=>$PRT,CREATE=>2,EMAIL=>$v->{'email'});
				$c->save();
				($CID) = $c->cid();
				push @LOGS, "Created customer account #$CID";
				}
			}

		my $cardtype = int($v->{'cardtype'});

		if ($GCID==0) {
			## some checks before we create new cards.
			if ($v->{'series'} eq '') {
				## no series specified, no warnings.
				}
			elsif ($QUANTITY==1) {
				&JSONAPI::set_error(\%R,'apperr',45001,"A SERIES identifier is only intended/available for issuing multiple giftcards. hint: try leaving series blank, or re-read the documentation. Series identifiers are optional when issuing less than 50 cards.");
				}
			elsif ($v->{'email'}) {
				&JSONAPI::set_error(\%R,'apperr',45002,"A SERIES identifier is only intended/available for situations where a giftcard has no specific email address associated with it.");
				}
			elsif ($CID>0) {
				&JSONAPI::set_error(\%R,'apperr',45003,"A SERIES identifier is only intended/available when no customer is specified.");
				}
	
			if (&JSONAPI::hadError(\%R)) {
				}
			elsif ($QUANTITY==1) {
				}
			elsif (($QUANTITY>0) && ($v->{'email'})) {
				&JSONAPI::set_error(\%R,'apperr',45005,"Sorry, as a safety mechanism you can only create quantity 1 of a giftcard for a specified customer email. If you actually intended to create multiple giftcards for the same person, you will need to do it by issuing multiple requests.");
				}
			elsif (($QUANTITY>50) && ($v->{'series'} eq '')) {
				&JSONAPI::set_error(\%R,'apperr',45006,"If you are creating more than 50 giftcards at a time, you MUST use the SERIES functionality");
				}			
			}

		my $GIFTCARD_REF = undef;
		my @CARDS = ();
		if (JSONAPI::hadError(\%R)) {
			}
		elsif ($GCID==0) {
			## new card
	
			my %CARD_VARS = ();
			$CARD_VARS{'NOTE'} = $v->{'note'};
			$CARD_VARS{'CID'} = $CID;
			$CARD_VARS{'EXPIRES_GMT'} = $EXPIRES_GMT;
			$CARD_VARS{'CREATED_BY'} = $LUSERNAME;
			$CARD_VARS{'CARDTYPE'} = $cardtype;

			if ($v->{'series'} ne '') {
				$CARD_VARS{'SRC_SERIES'} = uc($v->{'series'});
				} 
	
			my ($udbh) = &DBINFO::db_user_connect($USERNAME);
			foreach my $qty (1..$QUANTITY) {		
				if ($CARD_VARS{'SRC_SERIES'} ne '') { 
					$CARD_VARS{'SRC_GUID'} = sprintf("%s---#%s",$CARD_VARS{'SRC_SERIES'},$qty); 
					}
	
				my ($CODE) = &GIFTCARD::createCard($USERNAME,$PRT,$BALANCE,%CARD_VARS);
				push @CARDS, $CODE;
			
				my ($gcid) = &GIFTCARD::resolve_GCID($USERNAME,$CODE);			
				$LU->log("manage.giftcards.create","Created new card GCID: $gcid","INFO");

				if ($QUANTITY==1) {
					$v->{'GCID'} = $gcid;
					push @MSGS, "SUCCESS|Created new card: $gcid";
					}
				}
			&DBINFO::db_user_close();
			$GIFTCARD_REF = \%CARD_VARS;
			## NOTE: Don't set $GCID if we are bulk creating cards.
			}
		else {
			## save an (always single) existing card.
			# ($gcref) = &GIFTCARD::lookup($USERNAME,GCID=>$GCID);				
			&GIFTCARD::update($USERNAME,$GCID,
				CID=>$CID,BALANCE=>$BALANCE,NOTE=>$v->{'note'},
				EXPIRES_GMT=>$EXPIRES_GMT,CID=>$CID,LUSER=>$LUSERNAME,
				CARDTYPE=>$cardtype,
				);
			push @MSGS, "SUCCESS|Updated Card!";
			$LU->log("manage.giftcards.update","Updated new card GCID: $v->{'GCID'}","INFO");
			}
		## if we had an errors/logs add them to the gift card.
		if ($GCID>0) {
			foreach my $note (@LOGS) {
				GIFTCARD::addLog($USERNAME,$LUSERNAME,$GCID,$note);
				}
			}
	
		if (($CID==0) || ($QUANTITY>1)) {
			## never send email when we don't have a customer account, or we created multiple giftcards.
			}
		elsif ($v->{'sendemail'} eq 'on') {
			my ($BLAST) = BLAST->new( $self->username(), $self->prt() );
			my ($rcpt) = $BLAST->recipient('CUSTOMER',$CID);
			my ($msg) = $BLAST->msg('CUSTOMER.GIFTCARD.RECEIVED',{ '%GIFTCARD'=>$GIFTCARD_REF });
			$BLAST->send($rcpt,$msg);
			}
		else {
			warn "No email sent";
			}
		$R{'@CARDS'} = \@CARDS;
		}
	elsif ($v->{'_cmd'} eq 'adminGiftcardDetail') {
		#if (int($v->{'CID'})>0) {
		#	## we'll get passed a CID (customer id) from customer edit		
		#	$gcref->{'CID'} = int($v->{'CID'});
		#	}
		if (($v->{'_cmd'} eq 'adminGiftcardUpdate') && (not $GCID)) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',39003,'Missing GCID on adminGiftcardUpdate this will not go well.');
			}

		if (not &JSONAPI::hadError(\%R)) {
			my ($gcref) = &GIFTCARD::lookup($USERNAME,PRT=>$PRT,GCID=>$GCID);	
			%R = %{$gcref};

			my $logsref = &GIFTCARD::getLogs($USERNAME,$GCID);
			$R{'@LOGS'} = $logsref;
			}

		}
	else {
		&JSONAPI::set_error(\%R,'apperr',120,"invalid _cmd");
		}

	return(\%R);
	}



=pod

<API id="adminEmailMessageList">
<purpose>returns a list of projects</purpose>
</API>

<API id="adminEmailMessageCreate">
<purpose></purpose>
<input id="feed_title"></input>
<input id="feed_link"></input>
<input id="feed_link_override"></input>
<input id="feed_subject"></input>
<input id="max_products"></input>
<input id="cycle_interval"></input>
<input id="schedule"></input>
<input id="profile"></input>
<input id="list"></input>
<input id="image_h"></input>
<input id="image_w"></input>
<input id="translation"></input>
<input id="coupon"></input>
</API>

<API id="adminEmailMessageClone">
<purpose></purpose>
<input id="CPG"></input>
</API>

<API id="adminEmailMessageRemove">
<purpose></purpose>
<input id="CPG"></input>
</API>

<API id="adminEmailMessageUpdate">
<purpose></purpose>
<input id="CPG"></input>
</API>

<API id="adminEmailMessageDetail">
</API>


=cut

sub adminEmailMessage {
	
	}





=pod

<API id="adminRSSList">
<purpose>returns a list of projects</purpose>
</API>

<API id="adminRSSCreate">
<purpose></purpose>
<input id="feed_title"></input>
<input id="feed_link"></input>
<input id="feed_link_override"></input>
<input id="feed_subject"></input>
<input id="max_products"></input>
<input id="cycle_interval"></input>
<input id="schedule"></input>
<input id="profile"></input>
<input id="list"></input>
<input id="image_h"></input>
<input id="image_w"></input>
<input id="translation"></input>
<input id="coupon"></input>
</API>

<API id="adminRSSClone">
<purpose></purpose>
<input id="CPG"></input>
</API>

<API id="adminRSSRemove">
<purpose></purpose>
<input id="CPG"></input>
</API>

<API id="adminRSSUpdate">
<purpose></purpose>
<input id="CPG"></input>
</API>

<API id="adminRSSDetail">
</API>


=cut

sub adminRSS {
	my ($self,$v) = @_;

	my %R = ();

	my $USERNAME = $self->username();
	my $LU = $self->LU();
	my $MID = $self->mid();
	my $PRT = $self->prt();

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my $CPG = uc(sprintf("%s",$v->{'CPG'}));
	

	#mysql> desc CAMPAIGNS;
	#+--------------------+--------------------------------------------------------+------+-----+---------+----------------+
	#| Field				  | Type					                                    | Null | Key | Default | Extra          |
	#+--------------------+--------------------------------------------------------+------+-----+---------+----------------+
	#| ID                 | int(11)                                                | NO   | PRI | NULL    | auto_increment |
	#| CPG_CODE           | varchar(6)                                             | NO   |     | NULL    |                |
	#| CPG_TYPE           | enum('NEWSLETTER','RSS','PRINT','SMS','')              | NO   |     | NULL    |                |
	#| MERCHANT           | varchar(20)                                            | NO   |     | NULL    |                |
	#| MID                | int(10) unsigned                                       | NO   | MUL | 0       |                |
	#| CREATED_GMT        | int(11)                                                | NO   |     | 0       |                |
	#| NAME               | varchar(30)                                            | NO   |     | NULL    |                |
	#| SUBJECT            | varchar(100)                                           | NO   |     | NULL    |                |
	#| SENDER             | varchar(65)                                            | NO   |     | NULL    |                |
	#| DATA               | mediumtext                                             | NO   |     | NULL    |                |
	#| STATUS             | enum('PENDING','APPROVED','QUEUED','FINISHED','ERROR') | YES  | MUL | PENDING |                |
	#| TESTED             | int(11)                                                | YES  |     | NULL    |                |
	#| STARTS_GMT         | int(10) unsigned                                       | NO   |     | 0       |                |
	#| STAT_QUEUED        | int(10) unsigned                                       | NO   |     | 0       |                |
	#| STAT_SENT          | int(10) unsigned                                       | NO   |     | 0       |                |
	#| STAT_OPENED        | int(10) unsigned                                       | NO   |     | 0       |                |
	#| STAT_BOUNCED       | int(10) unsigned                                       | NO   |     | 0       |                |
	#| STAT_CLICKED       | int(10) unsigned                                       | NO   |     | 0       |                |
	#| STAT_PURCHASED     | int(10) unsigned                                       | NO   |     | 0       |                |
	#| STAT_TOTAL_SALES   | int(10) unsigned                                       | NO   |     | 0       |                |
	#| STAT_UNSUBSCRIBED  | int(10) unsigned                                       | NO   |     | 0       |                |
	#| RECIPIENT          | varchar(20)                                            | YES  |     | NULL    |                |
	#| SCHEDULE           | varchar(10)                                            | NO   |     | NULL    |                |
	#| SCHEDULE_COUNTDOWN | tinyint(4)                                             | NO   |     | 0       |                |
	#| PROFILE            | varchar(10)                                            | NO   |     | NULL    |                |
	#| PRT                | smallint(5) unsigned                                   | NO   |     | 0       |                |
	#+--------------------+--------------------------------------------------------+------+-----+---------+----------------+
	#26 rows in set (0.03 sec)

	my @MSGS = ();
	if (($v->{'_cmd'} eq 'adminRSSUpdate') || ($v->{'_cmd'} eq 'adminRSSCreate')) {
		push @MSGS, "SUCCESS|+Changes have been saved";

		$CPG =~ s/[^A-Z0-9]+//gs; 	# strip non-alpha num
		if (($CPG eq '') && ($v->{'_cmd'} eq 'adminRSSCreate')) {
			$CPG = time();
			}
		elsif ($CPG eq '') {
			## cheaphack!
			&JSONAPI::set_error(\%R,'apperr',103292,'CPG parameter not specified');
			}

		if (not &JSONAPI::hadError(\%R)) {	
			my %info = ();
			$info{'title'} = $v->{'feed_title'};
			$info{'link'} = $v->{'feed_link'};
			$info{'link_override'} = (defined $v->{'feed_link_override'})?1:0;
			$info{'subject'} = $v->{'feed_subject'};
			$info{'max_products'} = $v->{'max_products'};
			$info{'cycle_interval'} = $v->{'cycle_interval'};
			$info{'schedule'} = $v->{'schedule'};
			$info{'profile'} = $v->{'profile'};
			$info{'list'} = $v->{'list'};
			$info{'image_h'} = $v->{'image_h'};
			$info{'image_w'} = $v->{'image_w'};
			$info{'translation'} = $v->{'translation'};
			my $COUPON = sprintf("%s",$v->{'coupon'});

			my $pstmt = &DBINFO::insert($udbh,'RSS_FEEDS',{
				USERNAME=>$USERNAME,
				MID=>$MID,
				CREATED_GMT=>time(),
				CPG_CODE=>$CPG, 
				CPG_TYPE=>'RSS',
				NAME=>$v->{'feed_title'},
				SUBJECT=>$v->{'feed_subject'},
				# SCHEDULE=>$v->{'schedule'},
				COUPON=>$COUPON,
				PROFILE=>$v->{'profile'},
				PRT=>$PRT,
				DATA=>&ZTOOLKIT::buildparams(\%info),
				},debug=>2,key=>['MID','CPG_CODE','CPG_TYPE']);
			print STDERR $pstmt."\n";
			&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
			}
		$R{'CPG'} = $CPG;
		}
	elsif ($v->{'_cmd'} eq 'adminRSSList') {
		my @ROWS = ();
		my $pstmt = "select * from RSS_FEEDS where CPG_TYPE='RSS' and MID=$MID and PRT=$PRT order by CREATED_GMT";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $hashref = $sth->fetchrow_hashref() ) {
			$hashref->{'CPG'} = $hashref->{'CPG_CODE'};
			delete $hashref->{'CPG_CODE'};
			push @ROWS, $hashref;
			$hashref->{'LINK'} = "/media/rss/$USERNAME/$hashref->{'CPG_CODE'}.xml";
			}
		$sth->finish();
		$R{'@RSSFEEDS'} = \@ROWS;
		}
	elsif ($v->{'_cmd'} eq 'adminRSSDetail') {
		my $pstmt = "select * from RSS_FEEDS where CPG_TYPE='RSS' and MID=$MID and CPG_CODE=".$udbh->quote($CPG);
		my $sth = $udbh->prepare($pstmt);	
		$sth->execute();
		my ($dbinfo) = $sth->fetchrow_hashref();
		$sth->finish();
		delete $dbinfo->{'ID'};
	
		## cheapo hacko for jt-dog
		%R = %{$dbinfo};

		my ($info) = &ZTOOLKIT::parseparams($dbinfo->{'DATA'});
		$R{'image_h'} = $info->{'image_h'};
		$R{'image_w'} = $info->{'image_w'};
		$R{'CPG'} = $CPG;
		$R{'feed_title'} = $info->{'title'};
		$R{'LINK'} = "/media/rss/$USERNAME/$CPG.xml";;
		$R{'feed_link_override'} = $info->{'link_override'};
		$R{'feed_subject'} = $info->{'subject'};
		$R{'max_products'} = $info->{'max_products'};
		$R{'cycle_interval'} = $info->{'cycle_interval'};
		$R{'schedule'} = $dbinfo->{'SCHEDULE'};
		$R{'coupon'} = $dbinfo->{'COUPON'};
		$R{'profile'} = $dbinfo->{'PROFILE'};
		$R{'list'} = $info->{'list'};
		$R{'translation'} = $info->{'translation'};
		$LU->log('SETUP.RSS',"Edited Campaign $CPG","INFO");
		}
	elsif ($CPG eq '') {
		## cheaphack!
		&JSONAPI::set_error(\%R,'apperr',103292,'CPG parameter not specified');
		}
	elsif ($v->{'_cmd'} eq 'adminRSSRemove') {
		my $pstmt = "delete from RSS_FEEDS where CPG_TYPE='RSS' and MID=$MID and PRT=$PRT and CPG_CODE=".$udbh->quote($CPG);
		print STDERR "pstmt:$pstmt\n";
		&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
		$LU->log('SETUP.RSS',"Deleted Campaign $CPG","INFO");
		}
	else {
		&JSONAPI::set_error(\%R,'apperr',120,"invalid _cmd");
		}

	#require NAVCAT;
	#my ($nc) = NAVCAT->new($USERNAME,PRT=>$PRT);
	#foreach my $safe (sort $nc->paths()) {
	#	next if (substr($safe,0,1) ne '$');	
	#	my ($pretty) = $nc->get($safe);
	#	if ($pretty eq '') { $pretty = "Untitled $safe"; }
	#	my $selected = ($v->{'list'} eq $safe)?' selected ':'';
	#	$c .= "<option $selected value=\"$safe\">$pretty</option>\n";
	#	}

	return(\%R);
	}





=pod

<API id="adminProjectList">
<purpose>returns a list of projects</purpose>
</API>

<API id="adminProjectCreate">
<purpose></purpose>
Not finished
</API>

<API id="adminProjectClone">
<purpose></purpose>
Not finished
</API>

<API id="adminProjectRemove">
<purpose></purpose>
Not finished
</API>

<API id="adminProjectUpdate">
<purpose></purpose>
Not finished
</API>

<API id="adminProjectDetail">
<purpose></purpose>
Not finished
</API>

<API id="adminProjectGitMacro">
<purpose></purpose>
Not finished
</API>


=cut

sub adminProject {
	my ($self,$v) = @_;

	my %R = ();
	require Archive::Zip;
	require PROJECT;

	my $USERNAME = $self->username();
	my $LU = $self->LU();
	my $MID = $self->mid();
	my $PRT = $self->prt();

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my @MSGS = ();
	my $P = undef;
	
	if ($v->{'_cmd'} eq 'adminProjectList') {
		## NEVER NEEDS A UUID!
		}
	elsif (defined $v->{'UUID'}) { 
		if ($v->{'_cmd'} eq 'adminProjectCreate') {
			
			}
		else {
			$P = PROJECT->new($USERNAME,'UUID'=>$v->{'UUID'}); 
			if (not defined $P) {
				&JSONAPI::set_error(\%R,'youerr',324101,'Project UUID is invalid');
				}
			}
		}

	#elsif ($v->{'_cmd'} eq 'adminProjectList') {
	#	my @PROJECTS = ();
	#	$R{'@FILES'} = \@PROJECTS;
	#	my $c = '';
	#	opendir my $D, "/httpd/static/apps";
	#	while ( my $file = readdir($D) ) {
	#		next if (substr($file,0,1) eq '.');
	#		next if (substr($file,0,1) eq '_');	# hidden
	#		push @PROJECTS, { 'id'=>$file };
	#		}
	#	closedir $D;
	#	}
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'_cmd'} eq 'adminProjectList') {
		my %PROJECTS = ();
      my $pstmt = "select HOSTNAME,DOMAINNAME,CONFIG from DOMAIN_HOSTS where HOSTTYPE in ('APPTIMIZER');";
      my $sth = $udbh->prepare($pstmt);
      $sth->execute();
      while ( my ( $HOSTNAME,$DOMAIN,$CONFIG ) = $sth->fetchrow() ) {
         my $cfg = ZTOOLKIT::parseparams($CONFIG);
         $PROJECTS{ $cfg->{'PROJECT'} } = sprintf("%s.%s",$HOSTNAME,$DOMAIN);
         }
		$sth->finish();

		$pstmt = "select * from PROJECTS where MID=$MID /* $USERNAME */ order by ID";
		($sth) = $udbh->prepare($pstmt);
		my @ROWS = ();
		$sth->execute();
		while ( my $row = $sth->fetchrow_hashref() ) {
			push @ROWS, $row;
			if (not defined $PROJECTS{ $row->{'UUID'} }) { 
				$PROJECTS{ $row->{'UUID'} } = [];
				}
			my $branch = $row->{'GITHUB_BRANCH'};
			if ($branch eq '') { $branch = 'master'; }

			}
		$sth->finish();
		$R{'@PROJECTS'} = \@ROWS;
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'UUID')) {
		}
	elsif (($v->{'_cmd'} ne 'adminProjectCreate') && (not defined $P)) {
		&JSONAPI::set_error(\%R,'iseerr',324102,'Project UUID is invalid');
		}
	elsif ($v->{'_cmd'} eq 'adminProjectRemove') {
		$P->delete();
		push @MSGS, "SUCCESS|+Deleted project $v->{'UUID'}";
		}
	elsif ($v->{'_cmd'} eq 'adminProjectClone') {
		my ($ERROR) = $P->copyfrom($v->{'project'});
		if ($ERROR ne '') {
			&JSONAPI::set_error(\%R,'iseerr',94313,$ERROR);
			}
		else {
			$R{'uuid'} = $P->uuid();
			}
		}
#	elsif ($v->{'_cmd'} eq 'adminProjectGitCommand') {
#		my $path = sprintf("%s/PROJECTS/%s",&ZOOVY::resolve_userpath($USERNAME),$UUID);
#		my ($r) = Git::Repository->run( 'pull', @params );
#		
#		}
	elsif ($v->{'_cmd'} eq 'adminProjectDetail') {
		%R = %{$P};
		if ($v->{'files'}) {
			my $filesref = $P->allFiles();
			if	(scalar(@{$filesref})==0) {
				}
			else {
				my $found_index = 0;
				foreach my $file (@{$filesref}) {
					# push @MSGS, "WARN|$file->[1]|$file->[2]|$file->[3]";
					if (($file->[2] eq 'index.html') && ($file->[1] eq '/')) {
						$found_index++;
						}
					}
				if (not $found_index) {
					push @MSGS, "WARN|+Missing index.html file, this project will not work.";
					}
				}
			my @FILES = ();
			foreach my $file (@{$filesref}) {
				next if ($file->[0] ne 'F');
				push @FILES, { 'DIR'=>$file->[1], 'FILE'=>$file->[2], 'SIZE'=>$file->[3], 'MODIFIED'=>$file->[4] };
				}
			$R{'@FILES'} = \@FILES;
			}
		}
	elsif (($v->{'_cmd'} eq 'adminProjectUpdate') || ($v->{'_cmd'} eq 'adminProjectCreate')) {
		my $TITLE = $v->{'title'};
		my $ERROR = undef;	
		my $REPO = $v->{'repo'};
		if ($REPO ne '') {
			if ($REPO =~ /^http[s]?\:/) {
				if ($REPO !~ /^http[s]?\:/) { $ERROR = "REPO must be http:"; }
				if ($REPO !~ /^http[s]?\:\/\/[a-z0-9A-Z\-\_\:\/\.]+$/) { $ERROR = "REPO contains prohibited characters"; }
				if ($REPO =~ /^http\:\/\/www\.github\.com/) { $ERROR = "GITHUB repos must be either ssh or https"; }
				if ($REPO =~ /^http\:\/\/github\.com/) { $ERROR = "GITHUB repos must be either ssh or https"; }
				}
			elsif ($REPO =~ /^ssh\:/) {
				}
			}

		my $domain = ($v->{'domain'})?1:0;
		my $TYPE = $v->{'type'};
		if ($TYPE eq '') {
			$ERROR = "PROJECT TYPE is required";
			}

		if ($domain) {
			if ($TYPE eq 'DSS') { $ERROR = "DSS Projects do not require a domain"; }
			}

		if ($TITLE eq '') {
			$ERROR = "TITLE is required";
			}
		
		my $UUID = Data::GUID->new()->as_string();
		$UUID = substr($UUID,0,32); ## restrict to 32 characters for db length
		if ($TYPE eq 'DSS') {	$UUID = "dss"; }
		if ($v->{'UUID'}) {
			$UUID = $v->{'UUID'};
			if ($UUID =~ /[^A-Z0-9\-\_a-z\.]/) {
				$ERROR = "PROJECT UUID contains invalid characters";
				}
			}

		## NOTE: branch names are most likely case sensitive (so don't uc them)
		my $BRANCH = sprintf("%s",$v->{'branch'});
		if (($ERROR eq '') && ($BRANCH ne '')) {
			if ($BRANCH =~ /^[^a-zA-Z0-9]/) { $ERROR = "invalid characters in start of branch name"; }
			if ($BRANCH =~ /[^a-zA-Z0-9\-\_]/) { $ERROR = "invalid characters in branch name '$BRANCH' (allowed A-Z 0-9 - _)"; }
			}

		my $path = sprintf("%s/PROJECTS/%s",&ZOOVY::resolve_userpath($USERNAME),$UUID);
		if (-d $path) { 
			$ERROR = "Will not create PROJECTS/$UUID folder (already exists)";
			}

		if (defined $ERROR) {
			push @MSGS, "ERROR|+$ERROR";
			&JSONAPI::set_error(\%R,'apperr',3200,$ERROR);
			}
		elsif (scalar(@MSGS)==0) {	
			if ($REPO ne '') {
				
				## /usr/local/bin/git clone http://github.com/brianhorakh/linktest.git /remote/snap/users/b/brian/PROJECTS/e8b9f059-a695-11e1-9cc4-1560a415
				## git clone https://github.com/zephyrsports/zephyrapp.git /users/zephyrsports/PROJECTS/ZEPHYR-201402B -b 201402

				my @params = ();
				push @params, $REPO;
				push @params, $path;
				if ($BRANCH) { push @params, "-b"; push @params, $BRANCH; }

				chdir("/tmp");
				open F, ">/tmp/cmd";
				print F sprintf("git clone %s\n",join(' ',@params));
				close F;

				my ($r) = Git::Repository->run( 'clone', @params );
				push @MSGS, "SUCCESS|+$r";
				
				if (-d $path) {
					push @MSGS, "SUCCESS|+REPO was cloned";
					}
				else {
					push @MSGS, $ERROR = "REPO could not be created, please try again";
					&JSONAPI::set_error(\%R,'apperr',3200,$ERROR);
					}
				}
			else {
				push @MSGS, "SUCCESS|+Added project $UUID";
				}
			}

		if ($TITLE eq '') { 
			$TITLE = "Untitled Project ".&ZTOOLKIT::pretty_date(time()); 
			}

		if (not defined $ERROR) {
			my ($pstmt) = &DBINFO::insert($udbh,'PROJECTS',{
				MID=>&ZOOVY::resolve_mid($USERNAME),
				USERNAME=>$USERNAME,
				TITLE=>$TITLE,
				UUID=>"$UUID",
				SECRET=>'secret',
				GITHUB_REPO=>$REPO,
				GITHUB_BRANCH=>$BRANCH,
				TYPE=>$TYPE,
				},sql=>1);
			print STDERR $pstmt."\n";
			&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
			}

		$R{'@MSGS'} = \@MSGS;
		}
	else {
		&JSONAPI::set_error(\%R,'apperr',120,"invalid _cmd");
		}

	&DBINFO::db_user_close(); 
	return(\%R);
	}




=pod

<API id="adminFAQList">
<purpose></purpose>
</API>

<API id="adminFAQSearch">
<purpose></purpose>
<input optional="1" id="lookup">any string</input>
<input optional="1" id="lookup-orderid">order #</input>
<input optional="1" id="lookup-email">email</input>
<input optional="1" id="lookup-phone">phone</input>
<input optional="1" id="lookup-ticket">ticket #</input>
</API>

<API id="adminFAQCreate">
<purpose></purpose>
</API>

<API id="adminFAQRemove">
<purpose></purpose>
</API>

<API id="adminFAQMacro">
<purpose></purpose>
<example>
<![CDATA[
* ADDNOTE?note=xyz&private=1|0
* ASK?
* UPDATE?escalate=1|0&class=PRESALE|POSTSALE|EXCHANGE|RETURN
* CLOSE
* 
]]>
</example>
</API>

<API id="adminFAQDetail">
<purpose></purpose>
</API>

=cut

sub adminFAQ {
	my ($self,$v) = @_;

	my %R = ();


	my @MSGS = ();
	my ($USERNAME) = $self->username();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($PRT) = $self->prt();
	my ($LU) = $self->LU();

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	if ($v->{'_cmd'} eq 'adminFAQList') {
		my $pstmt = "select * from FAQ_TOPICS where PRT=$PRT and MID=$MID";
		my ($sth) = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $row = $sth->fetchrow_hashref() ) {
			$row->{'TOPIC_ID'} = $row->{'ID'}; delete $row->{'ID'};
			push @{$R{'@TOPICS'}}, $row;
			}
		$sth->finish();
		
		$pstmt = "select * from FAQ_ANSWERS where PRT=$PRT and MID=$MID";
		($sth) = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $row = $sth->fetchrow_hashref() ) {
			$row->{'FAQ_ID'} = $row->{'ID'}; delete $row->{'ID'};
			push @{$R{'@FAQS'}}, $row;
			}
		$sth->finish();
		}
	elsif ($v->{'_cmd'} eq 'adminFAQMacro') {
		my @CMDS = ();

		$self->parse_macros($v->{'@updates'},\@CMDS);
		my $LM = LISTING::MSGS->new();

		foreach my $CMDSET (@CMDS) {
			my ($VERB,$params) = @{$CMDSET};
			my @MSGS = ();
			my $CODE = $v->{'PROFILE'};

			if ($VERB =~ /^TOPIC-(UPDATE|CREATE)$/) {
				$VERB = ($1 eq 'UPDATE')?'update':'insert';
				my %cols = (MID=>$MID,USERNAME=>$USERNAME,PRT=>$PRT);
				foreach my $k ('TITLE','PRIORITY') { $cols{$k} = $params->{$k}; }
				if ($VERB eq 'insert') { $cols{'ID'} = 0; }
				if ($VERB eq 'update') { $cols{'ID'} = $params->{'TOPIC_ID'}; }
				my ($pstmt) = DBINFO::insert($udbh,'FAQ_TOPICS',\%cols,sql=>1,verb=>$VERB,key=>['ID','MID','PRT']);				
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt,$VERB);
				}
			elsif ($VERB eq 'TOPIC-DELETE') {
				my $pstmt = "delete from FAQ_TOPICS where MID=$MID and PRT=$PRT and ID=".$udbh->quote($params->{'TOPIC_ID'});
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt,$VERB);
				}
			elsif ($VERB =~ /^FAQ-(UPDATE|CREATE)$/) {
				$VERB = ($1 eq 'UPDATE')?'update':'insert';
				my %cols = (MID=>$MID,USERNAME=>$USERNAME,PRT=>$PRT);
				foreach my $k ('TOPIC_ID','KEYWORDS','QUESTION','ANSWER','PRIORITY') { $cols{$k} = $params->{$k}; }
				if ($VERB eq 'insert') { $cols{'ID'} = 0; }
				if ($VERB eq 'update') { $cols{'ID'} = $params->{'FAQ_ID'}; }
				my ($pstmt) = DBINFO::insert($udbh,'FAQ_ANSWERS',\%cols,sql=>1,verb=>$VERB,key=>['ID','MID','PRT']);				
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
				}
			elsif ($VERB eq 'FAQ-DELETE') {
				my $pstmt = "delete from FAQ_ANSWERS where MID=$MID and PRT=$PRT and ID=".$udbh->quote($params->{'FAQ_ID'});
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt,$VERB);
				}
			}
		
		}

	&DBINFO::db_user_close();
	return(\%R);
	}





=pod

<API id="adminAppTicketList">
<purpose></purpose>
</API>

<API id="adminAppTicketSearch">
<purpose></purpose>
<input optional="1" id="lookup">any string</input>
<input optional="1" id="lookup-orderid">order #</input>
<input optional="1" id="lookup-email">email</input>
<input optional="1" id="lookup-phone">phone</input>
<input optional="1" id="lookup-ticket">ticket #</input>
</API>

<API id="adminAppTicketCreate">
<purpose></purpose>
</API>

<API id="adminAppTicketRemove">
<purpose></purpose>
</API>

<API id="adminAppTicketMacro">
<purpose></purpose>
<example>
<![CDATA[
* ADDNOTE?note=xyz&private=1|0
* ASK?
* UPDATE?escalate=1|0&class=PRESALE|POSTSALE|EXCHANGE|RETURN
* CLOSE
* 
]]>
</example>
</API>

<API id="adminAppTicketDetail">
<purpose></purpose>
</API>

=cut

sub adminAppTicket {
	my ($self,$v) = @_;

	my @MSGS = ();
	my ($USERNAME) = $self->username();
	my ($PRT) = $self->prt();
	my ($LU) = $self->LU();

	my %R = ();

	require Text::Wrap;
	$Text::Wrap::columns = 80;

	require CUSTOMER::TICKET;
	require CUSTOMER;

	my $TKTCODE = $v->{'TKTCODE'};

	#mysql> desc CHECKOUTS;
	#+----------------+-------------------------------+------+-----+---------+----------------+
	#| Field          | Type                          | Null | Key | Default | Extra          |
	#+----------------+-------------------------------+------+-----+---------+----------------+
	#| ID             | int(11)                       | NO   | PRI | NULL    | auto_increment |
	#| MID            | int(10) unsigned              | NO   | MUL | 0       |                |
	#| USERNAME       | varchar(20)                   | NO   |     | NULL    |                |
	#| SDOMAIN        | varchar(50)                   | NO   |     | NULL    |                |
	#| ASSIST         | enum('NONE','CALL','CHAT','') | NO   |     | NULL    |                |
	#| CARTID         | varchar(36)                   | NO   |     | NULL    |                |
	#| CID            | int(10) unsigned              | NO   |     | 0       |                |
	#| CREATED_GMT    | int(10) unsigned              | NO   |     | 0       |                |
	#| HANDLED_GMT    | int(10) unsigned              | NO   |     | 0       |                |
	#| CLOSED_GMT     | int(10) unsigned              | NO   |     | 0       |                |
	#| ASSISTID       | varchar(5)                    | NO   |     | NULL    |                |
	#| CHECKOUT_STAGE | varchar(8)                    | NO   |     | NULL    |                |
	#+----------------+-------------------------------+------+-----+---------+----------------+
	#12 rows in set (0.02 sec)

	#if ($VERB eq 'CHECKOUTASSIST') {
	#	$template_file = 'checkoutassist.shtml';

	#	my $c = '';
	#	my $pstmt = "select * from CHECKOUTS where MID=$MID /* $USERNAME */";
	#	my $sth = $udbh->prepare($pstmt);
	#	$sth->execute();
	#	while ( my $ref = $sth->fetchrow_hashref() ) {
	#		$c .= "<tr><td>$ref->{'ASSIST'}</td><td>$ref->{'ASSISTID'}</td><td>$ref->{'CREATED_GMT'}</td></tr>";
	#		}
	#	$sth->finish();	
	#	}

	if ($v->{'_cmd'} eq 'adminAppTicketSearch') {
		## this gets only one value: lookup so we use pattern matching to try and figure out what the heck
		##		we're looking for

		if ($v->{'scope'} eq 'auto') {
			my $lookup = $v->{'searchfor'};
			$lookup = uc($lookup);
			$lookup =~ s/^[\s]+//gs;	# strip leading whitespace
			$lookup =~ s/[\s]+$//gs;	# strip trailing whitespace
			$v->{'searchfor'} = $lookup;

			if ($lookup =~ /^[\d]{4,4}\-[\d]{2,2}\-[\d]+$/) {
				## this is an order #
				$v->{'scope'} = 'orderid';
				}
			elsif ($lookup =~ /\@/) {
				## this is an email 
				$v->{'scope'} = 'email';
				}
			elsif ($lookup =~ /^[\d]{3,3}-[\d]{3,3}-[\d]{1,7}$/) {
				## PHONE NUMBER: ###-###-####
				$v->{'scope'} = 'phone';
				}
			else {
				$v->{'scope'} = 'ticket';
				}
			}

		$R{'scope'} = $v->{'scope'};
		$R{'searchfor'} = $v->{'searchfor'};

		if ($R{'scope'} eq 'ticket') {
			my ($T) = CUSTOMER::TICKET->new($USERNAME,sprintf("+%s",$R{'searchfor'}),PRT=>$PRT);
			if (defined $T) {
				$R{'TID'} = $T->tid();				
				}
			}
		
		if ($R{'scope'} eq 'email') {
			my $lookup = $v->{'searchfor'};
			if ($lookup eq '') { $lookup = '*'; }
			my ($O2) = CART2->new_from_oid($USERNAME,$lookup);
			if ((defined $O2) && (ref($O2) eq 'CART2')) {
				my ($CID) = &CUSTOMER::searchfor_cid($USERNAME,$PRT,'EMAIL',$O2->in_get('bill/email'));
				if ((defined $CID) && ($CID > 0)) {	$R{'CID'} = $CID; }
  				}
			}
	
		# if (($VERB eq '') && ($lookup =~ /^[\d]{3,3}\-[\d]{3,3}-[\d]{4,4}$/)) {
		if ($R{'scope'} eq 'phone') {
			my $lookup = $v->{'searchfor'};
			my ($CID) = &CUSTOMER::searchfor_cid($USERNAME,$PRT,'PHONE',$lookup);
			if ((defined $CID) && ($CID > 0)) { $R{'CID'} = $CID; }
			}

		# if (($VERB eq '') && (&ZTOOLKIT::validate_email($lookup))) {
		if ($R{'scope'} eq 'email') {
			my $lookup = $v->{'searchfor'};
			## EMAIL user@domain.com
			my ($CID) = &CUSTOMER::searchfor_cid($USERNAME,$PRT,'EMAIL',$lookup);
			if ((defined $CID) && ($CID > 0)) { $R{'CID'} = $CID; }
			}

		}
	elsif ($v->{'_cmd'} eq 'adminAppTicketCreate') {
		my $CID = int($v->{'cid'});
		my $orderid = $v->{'orderid'};
		my $email = $v->{'email'};
		my $phone = $v->{'phone'};

		if (($CID<=0) && ($orderid ne '')) {
			my ($O2) = CART2->new_from_oid($USERNAME,$orderid);
			if (not defined $O2) {
				$orderid = '';
				}
			else {
				$email = $O2->in_get('bill/email');
				$phone = $O2->in_get('bill/phone');
				}
			}

		if (($CID<=0) && (&ZTOOLKIT::validate_email($email))) {
			## Lookup by email
			($CID) = &CUSTOMER::resolve_customer_id($USERNAME,$PRT,$email);
			}
	
		if (($CID<=0) && ($phone ne '')) {
			## Lookup by phone
			($CID) = &CUSTOMER::searchfor_cid($USERNAME,$PRT,'PHONE',$phone);
			}

		if (($CID<=0) && ($v->{'create'})) {
			if (&ZTOOLKIT::validate_email($email)) {
				my ($c) = CUSTOMER->new($USERNAME,PRT=>0,CREATE=>1,EMAIL=>$email,PRT=>$PRT);
				$c->save();
				$CID = $c->cid();
				}
			}
	
		if (($CID>0) || ($orderid ne '')) {
			## created a ticket.
			my ($t) = CUSTOMER::TICKET->new($USERNAME,$PRT,ORDERID=>$orderid,CID=>$CID,
						PRT=>$PRT,
						SUBJECT=>$v->{'subject'},
						NOTE=>$v->{'body'},
						CLASS=>$v->{'class'},
						);
			if (defined $t) {
				$TKTCODE = $t->tktcode();
				}
			else {
				&JSONAPI::set_error(\%R,'iseerr',93292,'INTERNAL ERROR OCCURRED ATTEMPTING TO CREATE TICKET');
				}
			}
		else {
			## FAILED
			&JSONAPI::set_error(\%R,'apperr',93293,'INTERNAL ERROR OCCURRED ATTEMPTING TO CREATE TICKET (no customer or order provided)');
			}
		}
	elsif ($v->{'_cmd'} eq 'adminAppTicketMacro') {

		my $VERB = '';
		my $TKTCODE = $v->{'tktcode'};
		my ($T) = CUSTOMER::TICKET->new($USERNAME,"+$TKTCODE",PRT=>$PRT);

		## validation phase
		my @CMDS = ();
		if (&JSONAPI::hadError(\%R)) {
			## shit happened!
			}
		elsif (not defined $v->{'@updates'}) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9002,'Could not find any @updates for order');
			}
		elsif (ref($v->{'@updates'}) eq 'ARRAY') {
			my $count = 0;
			foreach my $line (@{$v->{'@updates'}}) {
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					$cmdset->[1]->{'luser'} = $self->luser();
					$cmdset->[2] = $line;
					$cmdset->[3] = $count++;
					push @CMDS, $cmdset;
					}
				}
			}
	
		foreach my $CMDSET (@CMDS) {
			my ($cmd,$params) = @{$CMDSET};

			if ($cmd eq 'ADDNOTE') {
				$T->addMsg($self->luser(),$params->{'note'},($params->{'private'})?1:0);
				}
			elsif ($cmd eq 'ASK') {
				## ASK CUSTOMER A QUESTION
				$T->changeState('WAIT');
				$LU->log('TICKET.ASK',"Set Ticket: ".$T->tktcode()." to waiting","SAVE");
				}
			elsif ($cmd eq 'UPDATE') {
				## UPDATE A TICKET
				my %vars = ();
				if (defined $params->{'escalate'}) {
					$vars{'escalate'} = ($params->{'escalate'})?1:0;
					}
				if (defined $params->{'class'}) {
					$vars{'class'} = $v->{'class'};
					}
				if (($vars{'class'} eq 'PRESALE') || ($vars{'class'} eq 'POSTSALE')) {
					$T->cdSet("tags",$v->{'CD*tags'});
					}
				elsif (($vars{'class'} eq 'EXCHANGE') || ($vars{'class'} eq 'RETURN')) {
					$T->cdSet("rtnauth",(defined $v->{'CD*rtnauth'})?1:0);
					$T->cdSet("rtncredit",$v->{'CD*rtncredit'});
					$T->cdSet("rtnvia",$v->{'CD*rtnvia'});
					}
				$T->changeState('ACTIVE',%vars);
				$LU->log('TICKET.UPDATE',"Updated Ticket: ".$T->tktcode(),"SAVE");
				}
			elsif ($cmd eq 'CLOSE') {
				## CLOSE A TICKET
				my %vars = ();
				$T->changeState('CLOSE',%vars);
				$LU->log('TICKET.CLOSE',"Closed Ticket: ".$T->tktcode(),"SAVE");
				}
			}
		}
	elsif ($v->{'_cmd'} eq 'adminAppTicketDetail') {
		my ($T) = CUSTOMER::TICKET->new($USERNAME,"+$TKTCODE",PRT=>$PRT);
	 	if (not defined $T) {
			&JSONAPI::set_error(\%R,'apperr',9882,'requested ticket does not exist or could not be loaded.');
			}
		else {
			my ($ts,$user) = $T->getLock();
			my $tsdiff = time()-$ts;
			if ( $tsdiff < 15*60 ) {
				push @MSGS, "WARNING|+Warning user \"$user\" accessed the ticket ".&ZTOOLKIT::pretty_time_since(1,$tsdiff)." ago, they may still be editing.";
				}
			else {
				$T->setLock($self->luser());
				}
	
			my $inforef = $T->buildInfo();
			foreach my $k ('ID','SUBJECT','STATUS','LAST_ACCESS_USER','CLASSDATA','ORDERID','STAGE','CLOSED_GMT',
							'MID','LAST_ACCESS_GMT','PROFILE','TKTCODE','CID','CLASS','ESCALATED','CREATED_GMT',
							'UPDATES','REFUND_AMOUNT','UPDATED_GMT','IS_REFUND','PRT') {
				$R{$k} = $T->get($k);
				}
			$R{'%meta'} = $inforef;

	  		my $note = Text::Wrap::wrap("","",$T->{'NOTE'});
	     	$note = &ZOOVY::incode($note);
			$R{'NOTE'} = $note;
			}

		if (&JSONAPI::hadError(\%R)) {
			}
		elsif (($T->{'CLASS'} eq 'RETURN') || ($T->{'CLASS'} eq 'EXCHANGE')) {
			my $rtnauth = ($T->cdGet("rtnauth")?'checked':'');
			my $rtncredit = &ZOOVY::incode($T->cdGet("rtncredit"));
			my $rtnvia = &ZOOVY::incode($T->cdGet("rtnvia"));

			my ($O2) = undef;
			if (defined $T->oid()) {
				($O2) = CART2->new_from_oid($USERNAME,$T->oid(),'create'=>0);
				}

			if (defined $O2) {
				my @ITEMS = ();
				foreach my $item (@{$O2->stuff2()->items()}) {
					push @ITEMS, $item;
					}
				$R{'@ITEMS'} = \@ITEMS;		
				}
			}

		if (not &JSONAPI::hadError(\%R)) {
			my $msgsref = $T->getMsgs();
			if ((defined $msgsref) && (ref($msgsref) eq 'ARRAY')) {
				foreach my $msg (reverse @{$msgsref}) {
	  	    		my $note = Text::Wrap::wrap("","",$msg->{'NOTE'});
  		       	$note = &ZOOVY::incode($note);
					}
				$R{'@MSGS'} = $msgsref;
				}
			}
		}

	if (($v->{'_cmd'} eq 'adminAppTicketList') || ($v->{'_cmd'} eq 'adminAppTicketSearch')) {
		##############################################################################################
		## TICKET LISTING CODE (displays a list of crm in various status, also used for search)
		my %filters = ();
		if ($v->{'STATUS'}) { $filters{'STATUS'} = $v->{'STATUS'}; }
		if ((defined $v->{'CID'}) && ($v->{'CID'}>0)) { $filters{'CID'} = int($v->{'CID'}); }
		if ((defined $v->{'TID'}) && ($v->{'TID'}>0)) { $filters{'TID'} = int($v->{'TID'}); }

		if ($v->{'_cmd'} eq 'adminAppTicketSearch') {
			$filters{'CID'} = $R{'CID'};
			$filters{'TID'} = $R{'TID'};
			}
		elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'STATUS',['NEW','OPEN','WAIT','ALL'])) {
			}

		if (&JSONAPI::hadError(\%R)) {
			}
		elsif (scalar(keys %filters)==0) {
			&JSONAPI::set_error(\%R,'apperr',9883,'filter not set');
			}
		else {
			my $ticketsref = &CUSTOMER::TICKET::getTickets($USERNAME,%filters);
			if (defined $ticketsref) {
				foreach my $tkt (@{$ticketsref}) {
					if ($tkt->{'SUBJECT'} eq '') { $tkt->{'SUBJECT'} = 'No subject given.'; }
					if ($tkt->{'CLASS'} eq '') { $tkt->{'CLASS'} = '?'; }
					elsif ($tkt->{'CLASS'} eq 'EXCHANGE') { $tkt->{'CLASS'} = 'EXCHG'; }
					}
				$R{'@TICKETS'} = $ticketsref;
				}
			$R{'_found'} = scalar(@{$ticketsref});
			}
		}

	return(\%R);
	}









=pod

<API id="adminPriceScheduleList">
<purpose>Returns a list of available schedule id's.  
Each schedule has a unique 6 digit alphanumeric code that is used as an identifier.
</purpose>
<output id="@SCHEDULES">
{ 'id':'SCHED1' },
{ 'id':'SCHED2' },
{ 'id':'SCHED3' },
</output>
</API>

<API id="adminPriceScheduleCreate">
<purpose></purpose>
</API>

<API id="adminPriceScheduleRemove">
<purpose></purpose>
<input id="SID">schedule</input>
</API>

<API id="adminPriceScheduleUpdate">
<purpose></purpose>
</API>

<API id="adminPriceScheduleDetail">
<purpose></purpose>
<input id="SID">schedule</input>
</API>


=cut

sub adminPriceSchedule {
	my ($self,$v) = @_;

	my @MSGS = ();
	my ($USERNAME) = $self->username();
	my ($PRT) = $self->prt();

	if ($v->{'_cmd'} eq 'adminWholesaleScheduleList') { $v->{'_cmd'} = 'adminPriceScheduleList'; }

	my %R = ();
	if ($v->{'_cmd'} eq 'adminPriceScheduleList') {	
		my @SCHEDULES = ();
		foreach my $schedule (@{&WHOLESALE::list_schedules($self->username())}) {
			my ($detail) = &WHOLESALE::load_schedule($USERNAME,$schedule); 
			$detail->{'SID'} = $schedule;
			$detail->{'title'} = $detail->{'TITLE'}; delete $detail->{'TITLE'};
			if ($self->apiversion()<=201324) { 
				$detail->{'ID'} = $detail->{'SID'}; 
				$detail->{'id'} = $detail->{'SID'}; 
				}
			push @SCHEDULES, $detail;
			}
		$R{'@SCHEDULES'} = \@SCHEDULES;
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'SID')) {
		}
	elsif (($v->{'_cmd'} eq 'adminPriceScheduleUpdate') || ($v->{'_cmd'} eq 'adminPriceScheduleCreate')) {
		my %S = ();
		$S{'SID'} = uc(substr($v->{'SID'},0,4));
		$S{'SID'} =~ s/[^\w]+//gs;
		$S{'TITLE'} = $v->{'title'};
		$S{'discount_amount'} = $v->{'discount_amount'};
		$S{'discount_amount'} = &WHOLESALE::sanitize_formula($S{'discount_amount'});
		$S{'discount_default'} = ($v->{'discount_default'})?1:0;

		$S{'currency'} = $v->{'currency'};
		$S{'promotion_mode'} = $v->{'promotion_mode'};
		$S{'shiprule_mode'} = $v->{'shiprule_mode'};
	
		$S{'incomplete'} = ($v->{'incomplete'})?1:0;
		$S{'rewards'} = ($v->{'rewards'})?1:0;
		$S{'export_inventory'} = ($v->{'export_inventory'})?1:0;
		$S{'realtime_orders'} = ($v->{'realtime_orders'})?1:0;
		$S{'realtime_products'} = ($v->{'realtime_products'})?1:0;
		$S{'realtime_inventory'} = ($v->{'realtime_inventory'})?1:0;
		$S{'dropship_invoice'} = ($v->{'dropship_invoice'})?1:0;
		$S{'inventory_ignore'} = ($v->{'inventory_ignore'})?1:0;
		$S{'welcome_txt'} = $v->{'welcome_txt'};

		&WHOLESALE::save_schedule($USERNAME,\%S);
		push @MSGS, "SUCCESS|+Saved Schedule $S{'SID'}";
		}
	elsif ($v->{'_cmd'} eq 'adminPriceScheduleRemove') {
		require CUSTOMER::BATCH;
		my %ref = CUSTOMER::BATCH::list_customers($USERNAME,$PRT,'SCHEDULE'=>$v->{'SID'});
		if ( (my $count = (scalar(keys %ref)))>0) {
			push @MSGS, "ERROR|+NOTE: schedule $v->{'SID'} cannot be removed because it has $count customers still using it.";
			}
		else {
			&WHOLESALE::nuke_schedule($USERNAME,$v->{'SID'});
			push @MSGS, "ERROR|+NOTE: schedule $v->{'SID'} has been removed.";
			}
		}
	elsif ($v->{'_cmd'} eq 'adminPriceScheduleDetail') {
		my ($detail) = &WHOLESALE::load_schedule($USERNAME,$v->{'SID'}); 
		$detail->{'title'} = $detail->{'TITLE'}; delete $detail->{'TITLE'};
		$R{'%SCHEDULE'} = $detail;
		}

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
	
   return(\%R);
	}





=pod


<API id="adminKPIDBCollectionList">
<purpose></purpose>
<output id="@COLLECTIONS"></output>
</API>

<API id="adminKPIDBCollectionCreate">
<purpose></purpose>
<input id="title">Title of the Collection</input>
<input id="uuid">Unique identifier (36 characters) for the collection</input>
<input id="priority">The position/priority/sequence of the collection</input>
<input id="@GRAPHS">an array of graphs which will be serialized and returned</input>
</API>

<API id="adminKPIDBCollectionUpdate">
<purpose>same as collection create (pass uuid of previous collection)</purpose>
</API>

<API id="adminKPIDBCollectionRemove">
<purpose>removes a collection</purpose>
<input id="uuid">Unique identifier (36 characters) for the collection</input>
</API>

<API id="adminKPIDBCollectionDetail">
<purpose>returns the contents of a collection</purpose>
<input id="uuid">Unique identifier for this collection</input>
</API>

<API id="adminKPIDBUserDataSetsList">
<purpose>returns a list of datasets accessible to the user</purpose>
<output id="@DATASETS">
[ 'GROUP', 'DATASET-ID', 'Pretty name' ],
[ 'GROUP', 'DATASET-ID', 'Pretty name' ],
[ 'GROUP', 'DATASET-ID', 'Pretty name' ],
</output>
<hint>
The DATASET-ID is what is passed into adminKPIDBDataQuery as the "dataset" parameter
</hint>
</API>

<API id="adminKPIDBDataQuery">
<purpose></purpose>
<input required="1" id="@datasets">['dataset1','dataset2']</input>
<input required="1" id="grpby">day|dow|quarter|month|week|none</input>
<input required="1" id="column">gms|distinct|total</input>
<input required="1" id="function">sum|min|max|avg</input>
<input optional="1" id="period">a formula ex: months.1, weeks.1</input>
<input optional="1" id="startyyyymmdd">(not needed if period is passed)</input>
<input optional="1" id="stopyyyymmdd">(not needed if period is passed)</input>
</API>

=cut

sub adminKPIDB {
	my ($self,$v) = @_;

	my $USERNAME = $self->username();
	my $PRT = $self->prt();
	my $MID = $self->mid();

	require KPIBI;
	my $KPI = KPIBI->new($USERNAME,$PRT);
	my ($kpiv) = &ZWEBSITE::globalfetch_attrib($USERNAME,'kpi-version');
	#my $JSON = $KPI->makejson($g,$containerid);

	my %R = ();
	if ($v->{'_cmd'} eq 'adminKPIDBCollectionList') {
		$R{'@COLLECTIONS'} = $KPI->user_collections();
		}
	elsif (($v->{'_cmd'} eq 'adminKPIDBCollectionCreate') || ($v->{'_cmd'} eq 'adminKPIDBCollectionUpdate')) {
		my %params = ();
		$params{'VERSION'} = $self->apiversion();
		if ($v->{'title'} || ($v->{'_cmd'} eq 'adminKPIDBCollectionCreate')) {
			$params{'TITLE'} = $v->{'title'};
			}
		if ($v->{'priority'} || ($v->{'_cmd'} eq 'adminKPIDBCollectionCreate')) {
			$params{'PRIORITY'} = int($v->{'priority'});
			}
		if (&JSONAPI::validate_required_parameter(\%R,$v,'uuid')) {
			$params{'UUID'} = $v->{'uuid'};
			}

		if (not &JSONAPI::hadError(\%R)) {
			$params{'YAML'} = YAML::Syck::Dump($v->{'@GRAPHS'});
			my ($ID) = $KPI->create_collection(%params);
			if (($ID<=0) && ($v->{'_cmd'} eq 'adminKPIDBCollectionCreate')) {
				&JSONAPI::set_error(\%R,'apperr',98123,'Could not create/update UUID');
				}
			}
		}
	elsif ($v->{'_cmd'} eq 'adminKPIDBCollectionRemove') {
		if (&JSONAPI::validate_required_parameter(\%R,$v,'uuid')) {
			if ($KPI->nuke_collection($v->{'uuid'})) {
				&JSONAPI::append_msg_to_response(\%R,'success',0);				
				}
			}
		}
	elsif ($v->{'_cmd'} eq 'adminKPIDBCollectionDetail') {
		if (&JSONAPI::validate_required_parameter(\%R,$v,'uuid')) {
			my $DETAIL = $KPI->collection_detail($v->{'uuid'});
			if (defined $DETAIL) { 
				%R = %{$DETAIL}; 
				&JSONAPI::append_msg_to_response(\%R,'success',0);				
				}
			}
		}
	elsif ($v->{'_cmd'} eq 'adminKPIDBUserDataSetsList') {
		$R{'@DATASETS'} = $KPI->mydatasets();
		&JSONAPI::append_msg_to_response(\%R,'success',0);				
		}
	elsif ($v->{'_cmd'} eq 'adminKPIDBDataQuery') {

		my @DSNs = ();
		if (not defined $v->{'@datasets'}) {
			&JSONAPI::set_error(\%R,'apperr',98183,'No @datasets parameter found');
			}
		elsif (ref($v->{'@datasets'}) ne 'ARRAY') {
			&JSONAPI::set_error(\%R,'apperr',98184,'The @datasets parameter could not be processed as an array.');
			}
		elsif (scalar(@{$v->{'@datasets'}})==0) {
			&JSONAPI::set_error(\%R,'apperr',98185,'No datasets found in @datasets received');
			}
		else {
			@DSNs = @{$v->{'@datasets'}};
			}

		if ((scalar(@DSNs)==1) && ($v->{'dataColumns'} eq 'dynamic')) {
			## 
			my $DDSNs = $R{'@YAxis'} = $KPI->dynamic_dsn($DSNs[0]);
			@DSNs = ();
			foreach my $row (@{$DDSNs}) { push @DSNs, $row->[0]; }
			}

		# DSN: PRTA or FORMULA:xyz
		my $column = 0;
		my $func = '';
		
		if (&JSONAPI::validate_required_parameter(\%R,$v,'column',['gms','distinct','total'])) {
			if ($v->{'column'} eq 'gms') { $column = 1; }
			if ($v->{'column'} eq 'distinct') { $column = 2; }
			if ($v->{'column'} eq 'total') { $column = 3; }
			}
		$R{'response_column_position'} = $column;

		if (&JSONAPI::validate_required_parameter(\%R,$v,'function',['sum','min','max','avg'])) {
			$func = $v->{'function'};
			}

		my $startyyyymmdd = $v->{'startyyyymmdd'};
		my $stopyyyymmdd = $v->{'stopyyyymmdd'};
		if ($v->{'period'}) {
			($startyyyymmdd,$stopyyyymmdd) = &KPIBI::relative_to_current($v->{'period'});
			}		

		my ($startdt) = &KPIBI::yyyymmdd_to_dt($startyyyymmdd);
		my ($stopdt) = &KPIBI::yyyymmdd_to_dt($stopyyyymmdd);
		$R{'startdt'} = $startdt;
		$R{'stopdt'} = $stopdt;
		$R{'startyyyymmdd'} = $startyyyymmdd;
		$R{'stopyyyymmdd'} = $stopyyyymmdd;

		my ($dtlookup,$grpby_sequence) = &KPIBI::initialize_xaxis($startdt,$stopdt,$v->{'grpby'});
		$R{'@xAxis'} = $grpby_sequence;
		
		foreach my $DSN (@DSNs) {
			## SANITY: now retrieve the results from the DSN, and store them into $RAW_DATA
			my %RAW_DATA = ();

			my $results = $KPI->get_data($DSN,$startyyyymmdd,$stopyyyymmdd);
			#if ($v->{'detail'} eq 'RAW') {
			#	$R{"%PREGROUP-$DSN"} = \%RAW_DATA;	# for debugging
			#	$R{"%DBRESULT-$DSN"} = $results;
			#	}

			foreach my $line (@{$results}) {
				my $summarykey = $dtlookup->{ $line->[0] };
				push @{$RAW_DATA{$summarykey}}, $line->[ $column ];
				}				

			## SANITY: at this point %RAW_DATA is a hash, keyed by $summarytype (ex: Jan), and an arrayref containing set of data point matching that summary as the value
			##			  $grpby_sequence is an arrayref containing a list of keys (ex: Jan, Feb, Mar) in the proper sorted order.
			my $val = 0;
			my @RESULT_DATA = ();
			foreach my $summarykey (@{$grpby_sequence}) {
				my $sum = 0;
				my $min = undef;
				my $max = undef;
				my $count = 0;
				foreach my $v (@{$RAW_DATA{$summarykey}}) {
					$count++;
					$sum += $v;
					if ((not defined $min) || ($v<$min)) { $min = $v; }
					if ((not defined $max) || ($v<$max)) { $max = $v; }
					}
	
				if ($func eq 'sum') { $val = $sum; }
				elsif ($func eq 'min') { $val = $min; }
				elsif ($func eq 'max') { $val = $max; }
				elsif ($func eq 'avg') { 
					if ($count==0) { $val = 0; }
					else { $val = int($sum/$count); }
					}
				else {
					$val = -1;
					warn "unknown func:$func\n";
					}
	
				## finally, if there is a format we need to apply eq '#' or '$' then lets do that
				if ($column == 1) { $val = int($val/100); }	# highcharts crashes on decimals
				else { $val = int($val); }

				push @RESULT_DATA, $val;
				}

			$R{"$DSN"} = \@RESULT_DATA;
			}
		}

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
	
   return(\%R);
	}









#=pod
#
#<API id="adminInventoryUpdate">
#<input id="sku">sku : an A-Z|0-9|-|_ -- max length 20 characters, case insensitive</input>
#<input id="type">type</input>
#</API>
#
#=cut
#sub adminInventoryUpdate {
#	my ($self,$v) = @_;
#
#
#
#	}


=pod 

<API id="adminIncompleteList">
</API>

<API id="adminIncompleteCreate">
</API>

<API id="adminIncompleteUpdate">
</API>

=cut



sub adminIncomplete {
	my ($self,$v) = @_;

	my %R = ();	

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}	

	#elsif ($v->{'_cmd'} =~ /^adminIncomplete(List|Create|Update)$/) {
   return(\%R);
	}



=pod 

<API id="adminPageGet">
<purpose></purpose>
<input id="PATH"> .path.to.page or @CAMPAIGNID</input>
<input id="@get"> [ 'attrib1', 'attrib2', 'attrib3' ]</input>
<input id="all"> set to 1 to return all fields (handy for json libraries which don't return @get=[]) </input>
<example>
attrib1:xyz
attrib2:xyz
</example>
<note>leave @get blank for all page attributes</note>
</API>

<API id="adminPageSet">
<purpose></purpose>
<input id="PATH">.path.to.page or @CAMPAIGNID</input>
<input id="%set"> { 'attrib1'=>'newvalue', 'attrib2'=>'new value', 'attrib3'=>undefined }</input>
<hint>set value to "undefined" to delete it.</hint>
</API>

<API id="adminPageList">
<purpose></purpose>
<input id="@PAGES"></input>
</API>

=cut

sub adminPageList {
	my ($self,$v) = @_;

	my %R = ();
	my @PAGES = ();
	require PAGE::BATCH;
	my $ref = &PAGE::BATCH::fetch_pages($self->username(),'quick'=>1);
	foreach my $ref ( values %{$ref} ) {
		push @PAGES, $ref;
		}
	$R{'@PAGES'} = \@PAGES;
	&JSONAPI::append_msg_to_response(\%R,'success',0);

	return(\%R);
	}


sub adminPage {
	my ($self,$v) = @_;

	my %R = ();	

	## adminPageGet adminPageSet
	my $p = undef;
	if ($v->{'PATH'} eq '') {
		&JSONAPI::set_error(\%R,'apperr',5603,"PATH not specified");
		}
	else {
		($p) = PAGE->new($self->username(),$v->{'PATH'},PRT=>$self->prt(),DOMAIN=>$self->sdomain());
		if (not defined $p) {
			&JSONAPI::set_error(\%R,'apperr',5602,sprintf("invalid PATH=%s",$v->{'PATH'}));			
			}
		}

	## cheap hack.
	if ($v->{'all'}) { $v->{'@get'} = []; }

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'_cmd'} eq 'adminPageGet') {
		if (not defined $v->{'@get'}) { 
			&JSONAPI::set_error(\%R,'apperr',5603,"\@get is required (and was not included) for call adminPageGet");
			}
		elsif (ref($v->{'@get'}) ne 'ARRAY') {
			&JSONAPI::set_error(\%R,'apperr',5604,"\@get must be an array of attributes for call adminPageGet");
			}
		else {
			foreach my $attr (@{$v->{'@get'}}) {
				$R{$attr} = $p->get($attr);
				}
			&JSONAPI::append_msg_to_response(\%R,'success',0);						
			}
		}
	elsif ($v->{'_cmd'} eq 'adminPageSet') {
		if (not defined $v->{'%set'}) { 
			&JSONAPI::set_error(\%R,'apperr',5613,"\%set is required (and was not included) for call adminPageSet");
			}
		elsif (ref($v->{'%set'}) ne 'HASH') {
			&JSONAPI::set_error(\%R,'apperr',5614,"\%set must be an associative array of attribute key:value for call adminPageSet");
			}
		else {
			foreach my $k (keys %{$v->{'%set'}}) {
				$p->set($k,$v->{'%set'}->{$k});
				}
			$p->save();
			&JSONAPI::append_msg_to_response(\%R,'success',0);						
			}
		}
	else {
		&JSONAPI::set_error(\%R,'iseerr',5601,"invalid cmd. (this line should never be reached)");			
		}

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}	

	return(\%R);
	}




=pod

<API id="adminCustomerOrganizationSearch">
<purpose>find an organization</purpose>
<input id="CONTACT"></input>
<input id="PHONE"></input>
<input id="DOMAIN"></input>
<input id="EMAIL"></input>
<input id="ORGID"></input>
<input id="IS_LOCKED"></input>
<input id="ACCOUNT_MANAGER"></input>
<input id="ACCOUNT_TYPE"></input>
<input id="SCHEDULE"></input>


<response id=""></response>
</API>

<API id="adminCustomerOrganizationCreate">
<purpose></purpose>
<code><![CDATA[
** THESE WILL PROBABLY CHANGE **

| ID              | int(10) unsigned    | NO   | PRI | NULL    | auto_increment |
| MID             | int(10) unsigned    | NO   | MUL | 0       |                |
| USERNAME        | varchar(20)         | NO   |     |         |                |
| PRT             | tinyint(3) unsigned | NO   |     | 0       |                |
| CID             | int(10) unsigned    | NO   |     | 0       |                |
| EMAIL           | varchar(65)         | NO   |     |         |                |
| DOMAIN          | varchar(65)         | YES  |     | NULL    |                |
| firstname       | varchar(25)         | NO   |     |         |                |
| lastname        | varchar(25)         | NO   |     |         |                |
| company         | varchar(100)        | NO   |     |         |                |
| address1        | varchar(60)         | NO   |     |         |                |
| address2        | varchar(60)         | NO   |     |         |                |
| city            | varchar(30)         | NO   |     |         |                |
| region          | varchar(10)         | NO   |     |         |                |
| postal          | varchar(9)          | NO   |     |         |                |
| countrycode     | varchar(9)          | NO   |     |         |                |
| phone           | varchar(12)         | NO   |     |         |                |
| LOGO            | varchar(60)         | NO   |     |         |                |
| BILLING_CONTACT | varchar(60)         | NO   |     |         |                |
| BILLING_PHONE   | varchar(60)         | NO   |     |         |                |
| ALLOW_PO        | tinyint(3) unsigned | NO   |     | 0       |                |
| RESALE          | tinyint(3) unsigned | NO   |     | 0       |                |
| RESALE_PERMIT   | varchar(20)         | NO   |     |         |                |
| CREDIT_LIMIT    | decimal(10,2)       | NO   |     | NULL    |                |
| CREDIT_BALANCE  | decimal(10,2)       | NO   |     | NULL    |                |
| CREDIT_TERMS    | varchar(25)         | NO   |     |         |                |
| ACCOUNT_MANAGER | varchar(10)         | NO   |     |         |                |
| ACCOUNT_TYPE    | varchar(20)         | NO   |     |         |                |
| ACCOUNT_REFID   | varchar(36)         | NO   |     |         |                |
| JEDI_MID        | int(11)             | NO   |     | 0       |                |
| BUYER_PASSWORD

]]></code>
<response id=""></response>
</API>

<API id="adminCustomerOrganizationUpdate">
<purpose></purpose>
<input id="ORGID"></input>
<response id=""></response>
</API>

<API id="adminCustomerOrganizationDetail">
<purpose></purpose>
<input id="ORGID"></input>
<response id=""></response>
</API>

<API id="adminCustomerOrganizationRemove">
<purpose>remove an organization</purpose>
<input id="ORGID"></input>
<response id=""></response>
</API>

=cut

sub adminCustomerOrganization {
	my ($self,$v) = @_;
	my %R = ();

	my $MID = $self->mid();
	my $PRT = $self->prt();
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	if (not defined $self->prt()) {
		&JSONAPI::set_error(\%R,'iseerr',23403,'No partition set!');
		}
	elsif ($v->{'_cmd'} eq 'adminCustomerOrganizationSearch') {
		my $pstmt = "select ID as ORGID,DOMAIN,company as COMPANY,BILLING_CONTACT,BILLING_PHONE,EMAIL,DOMAIN,IS_LOCKED,ACCOUNT_MANAGER from CUSTOMER_WHOLESALE where MID=$MID and PRT=$PRT ";
		my @LIKES = ();
		if ($v->{'CONTACT'}) { push @LIKES, " CONTACT like concat('%',".$udbh->quote($v->{'CONTACT'}).",'%') "; }
		if ($v->{'ORGID'}) { push @LIKES, " ID=".int($v->{'ORGID'}); }
		if ($v->{'PHONE'}) { push @LIKES, " PHONE like concat('%',".$udbh->quote($v->{'PHONE'}).") "; }
		if ($v->{'DOMAIN'}) { push @LIKES, " DOMAIN like concat(".$udbh->quote($v->{'DOMAIN'}).",'%') "; }
		if ($v->{'COMPANY'}) { push @LIKES, " company like concat(".$udbh->quote($v->{'COMPANY'}).",'%') "; }
		if ($v->{'EMAIL'}) { push @LIKES, " EMAIL like concat(".$udbh->quote($v->{'EMAIL'}).",'%') "; }

		if (scalar(@LIKES)>0) {
			$pstmt .= " and ( ".join(" OR ",@LIKES)." ) ";
			}

		if ($v->{'IS_LOCKED'}) { $pstmt .= " and IS_LOCKED>0 "; push @LIKES, ''; }
		if ($v->{'ACCOUNT_MANAGER'}) { $pstmt .= " and ACCOUNT_MANAGER=".$udbh->quote($v->{'ACCOUNT_MANAGER'}); push @LIKES, ''; }
		if ($v->{'ACCOUNT_TYPE'}) { $pstmt .= " and ACCOUNT_TYPE=".$udbh->quote($v->{'ACCOUNT_TYPE'}); push @LIKES, ''; }
		if ($v->{'SCHEDULE'}) { $pstmt .= " and SCHEDULE=".$udbh->quote($v->{'SCHEDULE'}); push @LIKES, ''; }

		if (scalar(@LIKES)==0) { 
			$pstmt .= " order by ID desc limit 0,50";
			&JSONAPI::set_error(\%R,'warn',484153,'limited to 50 results because no search criteria was passed');
			}

		my @ROWS = ();
		print STDERR "$pstmt\n";		
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $row = $sth->fetchrow_hashref() ) {
			push @ROWS, $row;
			}
		$sth->finish();
		$R{'@ORGANIZATIONS'} = \@ROWS;
		}
	elsif ($v->{'_cmd'} eq 'adminCustomerOrganizationCreate') {
		my %params = ();
		foreach my $k (keys %CUSTOMER::ORGANIZATION::VALID_FIELDS) { $params{$k} = $v->{$k}; }
		
		$params{'DOMAIN'} = lc($params{'DOMAIN'});
		$params{'PHONE'} =~ s/[^\d]+//gs;		## remove non numeric from phone
		$params{'PHONE'} =~ s/^[01]+//gs;		## strip leading 0/1 from phone
		if ($params{'DOMAIN'} eq '') {
			}
		elsif (($params{'DOMAIN'} =~ /[^a-z0-9\-\.]+/) || ($params{'DOMAIN'} =~ /^www\./)) {
			&JSONAPI::set_error(\%R,'apperr',484143,'DOMAIN must only contain a-z0-9. and should not begin with www.');
			}

		if (not &JSONAPI::hadError(\%R)) {
			my ($org) = CUSTOMER::ORGANIZATION->create( $self->username(), $self->prt(), \%params );
			$org->save('create'=>1);
			$R{'ORGID'} = $org->orgid();
			if ($R{'ORGID'} == 0) {
				&JSONAPI::set_error(\%R,'iseerr',484140,'internal error - could not create organization');
				}
			}
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'ORGID')) {
		## require ORGID parameter
		}
	elsif ($v->{'_cmd'} eq 'adminCustomerOrganizationDetail') {
		my ($org) = CUSTOMER::ORGANIZATION->new_from_orgid($self->username(),$self->prt(),$v->{'ORGID'});
		$R{'ORG'} = $org;
		}
	elsif ($v->{'_cmd'} eq 'adminCustomerOrganizationUpdate') {
		my ($org) = CUSTOMER::ORGANIZATION->new_from_orgid($self->username(),$self->prt(),$v->{'ORGID'});
		if (not defined $org) {
			&JSONAPI::set_error(\%R,'apperr',484151,'Organization not found');
			}
		else {
			foreach my $k (keys %{$v}) { $org->set( $k, $v->{$k} ); }
			$org->save();
			$R{'ORG'} = $org;
			}
		}
	elsif ($v->{'_cmd'} eq 'adminCustomerOrganizationRemove') {
		my ($org) = CUSTOMER::ORGANIZATION->new_from_orgid($self->username(),$self->prt(),$v->{'ORGID'});
		if (not defined $org) {
			&JSONAPI::set_error(\%R,'apperr',484151,'Organization not found');
			}
		else {
			$org->nuke();		
			}
		}
	&DBINFO::db_user_close();

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}

	return(\%R);
	}




=pod 

<API id="adminCustomerSearch">
<purpose></purpose>
<concept>customer</concept>
<input id="scope">GIFTCARD|SCHEDULE|ORDER|NAME|CID|EMAIL|PHONE|NOTES</input>
<input id="searchfor">any text</input>
<response id="@CUSTOMERS">Customer ID</response>
<deprecated version="201318">
	<input id="email"></input>
	<response id="CID"></response>
</deprecated>
</API>

<API id="adminCustomerSelectorDetail">
<purpose>a product customer is a relative pointer to a grouping of customers.</purpose>
<concept>customer</concept>
<input id="selector">
CIDS=1,2,3,4
EMAILS=user@domain.com,user2@domain.com
SUBLIST=0	all subscribers (any list)
SUBLIST=1-15	a specific subscriber list
ALL=*			all customers (regardless of subscriber status)
</input>
<output id="@CIDS">an array of product id's</output>
</API>


=cut

sub adminCustomer {
	my ($self,$v) = @_;

	my %R = ();	

	if ($v->{'_cmd'} eq 'adminCustomerSelectorDetail') {
		require CUSTOMER::BATCH;
		my @CIDS = CUSTOMER::BATCH::resolveCustomerSelector($self->username(),$self->prt(),[ $v->{'selector'} ]);
		$R{'@CIDS'} = \@CIDS;
		}
	elsif ($v->{'_cmd'} eq 'adminCustomerSearch') {
		print STDERR sprintf("%s %s %s\n",$self->username(),$self->prt(),$v->{'email'});

		$R{'myPRT'} = $self->prt();
		if ($self->apiversion() < 201318) {
			if (not &JSONAPI::validate_required_parameter(\%R,$v,'email')) {
				}
			elsif (not defined $self->prt()) {
				&JSONAPI::set_error(\%R,'iseerr',23403,'No partition set!');
				}
			elsif ($v->{'email'}) {
				require CUSTOMER;
				## currently only using DEFAULT profile
				# print STDERR sprintf("adminCustomerSearch %s %d %s\n",$self->username(),$self->prt(),$v->{'email'});
				my ($CID) = CUSTOMER::resolve_customer_id($self->username(),$self->prt(),$v->{'email'});
				if ($CID <= 0) {
					$R{'CID'} = 0;
					}
				else {
					$R{'CID'} = $CID; 
					}
				&JSONAPI::append_msg_to_response(\%R,'success',0);
				}
			}
		else {
		## 201318 and beyond
			if (not &JSONAPI::validate_required_parameter(\%R,$v,'scope',['GIFTCARD','ORDER','NAME','SCHEDULE','ACCOUNT_MANAGER','CID','EMAIL','PHONE','NOTES'])) {
				}
			elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'searchfor')) {
				}
			else {
				require CUSTOMER::BATCH;
				my ($result) = &CUSTOMER::BATCH::find_customers($self->username(),$v->{'searchfor'},$v->{'scope'},365);
				$R{'@CUSTOMERS'} = $result;
				if (scalar(@{$result})==1) {
					## compatibility with pre 201318 releases
					$R{'CID'} = $result->[0]->{'CID'};
					}
				}
			}
		}
		
	return(\%R);
	}




=pod 

<API id="adminCustomerRemove">
<purpose></purpose>
<input id="CID">customer id #</input>
</API>

=cut

sub adminCustomerRemove {
	my ($self,$v) = @_;

	my %R = ();	

	print STDERR sprintf("%s %s %s\n",$self->username(),$self->prt(),$v->{'CID'});
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'CID')) {
		}
	elsif (not defined $self->prt()) {
		&JSONAPI::set_error(\%R,'iseerr',23403,'No partition set!');
		}
	else {
		require CUSTOMER;
		## currently only using DEFAULT profile
		my ($CID) = int($v->{'CID'});
		&CUSTOMER::delete_customer($self->username(),$CID);
		&JSONAPI::append_msg_to_response(\%R,'success',0);
		}
	
  	return(\%R);
	}


=pod 

<API id="adminCustomerWalletPeek">
<concept>wallet</concept>
<purpose></purpose>
</API>

=cut

sub adminCustomerWalletPeek {
	my ($self,$v) = @_;

	my $LU = $self->LU();
	my %R = ();

	open F, ">/tmp/luser";
 	print F Dumper($LU);
	close F;

	if ($LU->is_support()) {
		## sorry but zoovy employees cannot view the contents of wallets
		&JSONAPI::set_error(\%R,'iseerr',23403,'Provider employee not allowed');
		}
	elsif ($LU->is_admin()) {
		my $CID = $v->{'CID'};
		my $SECUREID = int($v->{'SECUREID'});
		my ($C) = CUSTOMER->new($self->username(),PRT=>$self->prt(),CID=>$CID);
		$R{'CID'} = $CID;
		$R{'SECUREID'} = $SECUREID;
		my ($wallet) = $C->wallet_retrieve($SECUREID);
		foreach my $k ('CC','YY','MM') {
			$R{$k} = $wallet->{$k};
			}
		$self->accesslog("WALLET.VIEW","INFO","Opened cid#$CID wallet#$SECUREID");
		}
	else {
		&JSONAPI::set_error(\%R,'iseerr',23404,'access denied (requires admin)');
		}
	return(\%R);
	}



=pod 

<API id="adminCustomerDetail">

<purpose></purpose>
<input id="CID">Customer ID</input>
adminCustomerDetail supports additional parameters:
<input id="newsletters">1 (returns @NEWSLETTERS)</input>
<input id="addresses">1  (returns @BILLING @SHIPPING)   [[ this may duplicate data from %CUSTOMER ]]</input>
<input id="wallets">1   (returns @WALLETS)</input>
<input id="wholesale">1  (returns %WS)</input>
<input id="giftcards">1 (returns @GIFTCARDS)</input>
<input id="tickets">1 (returns @TICKETS)</input>
<input id="notes">1 (returns @NOTES)</input>
<input id="events">1 (returns @EVENTS)</input>
<input id="orders">1 (returns @ORDERS)</input>
<response id="%CUSTOMER">Customer Object</response>
<concept>wallet</concept>
</API>

=cut

sub adminCustomerDetail {
	my ($self,$v) = @_;

	my %R = ();	

	require CUSTOMER;
	## currently only using DEFAULT profile

	my ($C) = CUSTOMER->new($self->username(),'CID'=>$v->{'CID'},'INIT'=>0xFF,'PRT'=>$self->prt());
	if (not defined $C) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',5969,'No customer for CID');
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);
		if ($self->apiversion() < 201307) {
			$R{'%CUSTOMER'} = $C;
			}
		else {
			%R = %{$C};
			delete $R{'*ORG'};	## don't ever return this!
			}
		}



	if ($v->{'newsletters'}) {	
		my $newsletter = $C->fetch_attrib('INFO.NEWSLETTER');
		require CUSTOMER::NEWSLETTER;
		my @RESULTS = CUSTOMER::NEWSLETTER::fetch_newsletter_detail($self->username(),$self->prt());
		my @NEWSLETTERS = ();
		foreach my $i (1..16) {
			next if (not defined $RESULTS[$i]);
			next if ($RESULTS[$i]->{'MODE'} == -1);	## not initialized!

			push @NEWSLETTERS, { 'id'=>$i, 'subscribed'=>( (($newsletter & (1<< ($i-1)) )>0)?1:0), 'name'=>$RESULTS[$i]->{'NAME'} };
			}	
		$R{'@NEWSLETTERS'} = \@NEWSLETTERS;
		}
	
	
	if ($v->{'addresses'}) {
		my @BILL = ();
		
		$CUSTOMER::ADDRESS::JSON_EXPORT_FORMAT = $self->apiversion();
		foreach my $addr (@{$C->fetch_addresses('BILL')}) {
			push @BILL, $addr;			
			}
		my @SHIP = ();
		foreach my $addr (@{$C->fetch_addresses('SHIP')}) {
			push @SHIP, $addr;
			}
		$R{'@BILLING'} = \@BILL;
		$R{'@SHIPPING'} = \@BILL;
		}

	if ($v->{'wallets'}) {
		my @WALLETS = ();
		foreach my $payref (@{$C->wallet_list()}) {
			push @WALLETS, $payref;
			}
		$R{'@WALLETS'} = \@WALLETS;
		}

	if ($self->apiversion()<=201318) {
		if ($v->{'wholesale'}) {
			#require WHOLESALE;
			#my $schedule = $C->fetch_attrib('INFO.SCHEDULE');
			#my $wsaddr = undef;
			#if ($schedule ne '') {
			#	$wsaddr = $C->fetch_address('WS');
			#	}
			#$R{'%WS'} = $wsaddr;
			my ($org) = $C->org();
			if ((defined $org) && (ref($org) eq 'CUSTOMER::ORGANIZATION')) {
				$R{'%WS'} = $org->as_legacy_wholesale_hashref();
				}
			}
		}

	if ($v->{'organization'}) {
		if ($C->orgid()>0) {
			$R{'%ORG'} = $C->org();
			$R{'%ORG'}->{'ORGID'} = $C->orgid();
			}
		}

	if ($v->{'giftcards'}) {
		require GIFTCARD;
		my $giftcardsref = &GIFTCARD::list($self->username(),CID=>$C->cid());
		my @GIFTCARDS = ();
		foreach my $gcref (@{$giftcardsref}) {
			$gcref->{'CODE'} = GIFTCARD::obfuscateCode($gcref->{'CODE'});
			push @GIFTCARDS, $gcref;
			}
		$R{'@GIFTCARDS'} = \@GIFTCARDS;
		}

	if ($v->{'tickets'}) {
      my $tickets = &CUSTOMER::TICKET::getTickets($self->username(),CID=>$C->cid());
		my @TICKETS = ();
      foreach my $t (@{$tickets}) {
			push @TICKETS, $t;
         }
		$R{'@TICKETS'} = \@TICKETS;
		}

	if ($v->{'notes'}) {
		my @NOTES = ();
		if ($C->fetch_attrib('INFO.HAS_NOTES')>0) {
			foreach my $noteref (sort @{$C->fetch_notes()}) {
				push @NOTES, $noteref;
				}
			}
		$R{'@NOTES'} = \@NOTES;
		}

	if ($v->{'events'}) {
		my $eventref = $C->fetch_events();
		my @EVENTS = ();
		if (scalar(@{$eventref})>0) {
			foreach my $e (sort @{$eventref}) {
				next if ($e->{'*PRETTY'} eq '');
				push @EVENTS, $eventref;
				}
			}
		$R{'@EVENTS'} = \@EVENTS;
		}

	if ($v->{'orders'}) {
		$R{'@ORDERS'} = $C->fetch_orders();
		}

   return(\%R);
	}












=pod 

<API id="adminCustomerUpdate">
<purpose></purpose>
<input id="CID">Customer ID</input>
<input id="@updates">
<![CDATA[
<ul>
* PASSWORDRESET?password=xyz    (or leave blank for random)
* HINTRESET
* SET?firstname=&lastname=&is_locked=&newsletter_1=
* ADDRCREATE?SHORTCUT=DEFAULT&TYPE=BILL|SHIP&firstname=&lastname=&phone=&company=&address1&email=.. 
* ADDRUPDATE? [see ADDRCREATE]
* ADDRREMOVE?TYPE=&SHORTCUT=
* SENDEMAIL?MSGID=&MSGSUBJECT=optional&MSGBODY=optional
* ORGCREATE?firstname=&middlename=&lastname=&company=&address1=&address2=&city=&region=&postal=&countrycode=&phone=&email=&ALLOW_PO=&SCHEDULE=&RESALE=&RESALE_PERMIT=&CREDIT_LIMIT=&CREDIT_BALANCE=&CREDIT_TERMS=&ACCOUNT_MANAGER=&ACCOUNT_TYPE=&ACCOUNT_REFID=&JEDI_MID=&DOMAIN=&LOGO=&IS_LOCKED=&BILLING_PHONE=&BILLING_CONTACT=&
* ORDERLINK?OID=
* NOTECREATE?TXT=
* NOTEREMOVE?NOTEID=
* WALLETCREATE?CC=&YY=&MM=
* WALLETDEFAULT?SECUREID=
* WALLETREMOVE?SECUREID=
* REWARDUPDATE?i=&reason=&
* SETORIGIN?origin=integer
* ADDTODO?title=&note=
* ADDTICKET?title=&note=
* DEPRECATED: WSSET?SCHEDULE=&ALLOW_PO=&RESALE=&RESALE_PERMIT=&CREDIT_LIMIT=&CREDIT_BALANCE=&ACCOUNT_MANAGER=& 
</ul>
]]>
</input>
<response id="*C">Customer Object</response>
<example>
<![CDATA[
example needed.
]]>
</example>
<concept>wallet</concept>
</API>

<API id="adminCustomerCreate">
<purpose></purpose>
<input id="@updates">
<![CDATA[
* CREATE?email=
see adminCustomerUpdate
]]>
</input>
<response id="*C">Customer Object</response>
<example>
<![CDATA[
example needed.
]]>
</example>
</API>


=cut

sub adminCustomerCreateUpdate {
	my ($self,$v) = @_;

	my %R = ();	

	my @CMDS = ();
	my $count = 0;
	foreach my $line (@{$v->{'@updates'}}) {
		my $CMDSETS = &CART2::parse_macro_script($line);
		foreach my $cmdset (@{$CMDSETS}) {
			$cmdset->[1]->{'luser'} = $self->luser();
			push @CMDS, $cmdset;
			}
		}

	if (scalar(@CMDS)==0) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',5966,'Super Cool SKI Instructor says: if you dont pass any @updates you\'re gonna have a bad time.');
		}

	require CUSTOMER;
	## currently only using DEFAULT profile
	my $C = undef;
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'_cmd'} eq 'adminCustomerCreate') {
		my $email = $CMDS[0]->[1]->{'email'};
		if ($email eq '') {
			&JSONAPI::append_msg_to_response(\%R,'apperr',5967,'email= is required parameter to CREATE');
			}
		else {
			($C) = CUSTOMER->new($self->username(),'PRT'=>$self->prt(),'CREATE'=>1,'EMAIL'=>$email);
			}
		}
	elsif ($v->{'_cmd'} eq 'adminCustomerUpdate') {
		if ($v->{'CID'} > 0) {
			($C) = CUSTOMER->new($self->username(),'CID'=>$v->{'CID'},'INIT'=>0xFF,'PRT'=>$self->prt());
			}
		else {
			&JSONAPI::append_msg_to_response(\%R,'apperr',5967,'CID must be passed to adminCustomerUpdate');
			}
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'iseerr',5968,'Unknown/invalid CMD passed to adminCustomerCreateUpdate');
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (not defined $C) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',5969,'No customer for CID');
		}
	elsif (not defined $v->{'@updates'}) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9002,'Could not find any @updates for CUSTOMER');
		}
	elsif (ref($v->{'@updates'}) eq 'ARRAY') {
		my $LM = LISTING::MSGS->new();
		$C->run_macro_cmds(\@CMDS,'*LM'=>$LM,'*SITE'=>$self->_SITE(),'*LU'=>$self->LU(),'%R'=>\%R);

		if (my $iseref = $LM->had(['WARNING'])) {
			&JSONAPI::append_msg_to_response(\%R,"warning",7200,$iseref->{'+'});
			}
		elsif (my $appref = $LM->had(['ERROR'])) {
			&JSONAPI::append_msg_to_response(\%R,"apperr",7201,$appref->{'+'});
			}
		else {
			&JSONAPI::append_msg_to_response(\%R,'success',0);		
			}
		$R{'%CUSTOMER'} = $C;
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		$R{'%CUSTOMER'} = $C;
		}

	if (defined $C) {
		$R{'CID'} = $C->cid();
		}

   return(\%R);
	}









=pod 

<API id="adminProductManagementCategoriesList">
<purpose></purpose>
<response id="@CATEGORIES"></response>
</API>

=cut 

sub adminProductManagementCategoriesList {
	my ($self, $v) = @_;
	my %R = ();
	require CATEGORY;
	$R{'@CATEGORIES'} = CATEGORY::listcategories($self->username());
	return(\%R);
	}


=pod 

<API id="adminProductManagementCategoriesComplete">
<purpose></purpose>
<response id="%CATEGORIES"></response>
</API>

=cut 

sub adminProductManagementCategoriesComplete {
	my ($self, $v) = @_;
	my %R = ();
	require CATEGORY;
	$R{'%CATEGORIES'} = CATEGORY::fetchcategories($self->username());
	&JSONAPI::append_msg_to_response(\%R,'success',0);		
	return(\%R);
	}


=pod 

<API id="adminProductManagementCategoriesDetail">
<purpose></purpose>
<input id="category"></input>
<response id="@PRODUCTS"></response>
</API>

=cut 

sub adminProductManagementCategoriesDetail {
	my ($self, $v) = @_;
	my %R = ();
	require CATEGORY;
	$R{'@PRODUCTS'} = CATEGORY::products_by_category($self->username(),$v->{'category'});
	&JSONAPI::append_msg_to_response(\%R,'success',0);		
	return(\%R);
	}


=pod

<API id="adminDomainList">
<purpose></purpose>
<input optional="1" id="prt">partition (optional)</input>
<input optional="1" id="hosts">0|1  (optional)</input>
<response id="@DOMAINS">an array of domains, each row contains { id:domainname prt:# }</response>
</API>

<API id="adminDomainDetail">
<input id="DOMAINNAME"></input>
<output id="@MSGS"></output>
</API>

<API id="adminDomainDetail">
<input id="DOMAINNAME"></input>
<output id="@HOSTS">
	{ "HOSTNAME":"www", "HOSTTYPE":"APP|REDIR|VSTORE|CUSTOM" },
	HOSTTYPE=APP		will have "PROJECT"
	HOSTTYPE=REDIR	will have "REDIR":"www.domain.com" "URI":"/path/to/301"  (if URI is blank then it will redirect with previous path)
	HOSTTYPE=VSTORE	will have @REWRITES
<output id="%EMAIL">
	EMAIL_TYPE=FUSEMAIL
	EMAIL_TYPE=GOOGLE
	EMAIL_TYPE=NONE
	EMAIL_TYPE=MX		MX1,MX2 parameters
	
</output>
</output>
</API>

<API id="adminDomainMacro">
<input id="DOMAINNAME">domain.com</input>
<input id="@updates">
<![CDATA[
DOMAIN-RESERVE		(note: leave DOMAINNAME blank/empty)
DOMAIN-TRANSFER
DOMAIN-REGISTER
DOMAIN-DELEGATE
DOMAIN-REMOVE
DOMAIN-PRT-SET?PRT=###
HOST-ADD?HOSTNAME=www|app|m
HOST-SET?HOSTNAME=www|app|m&HOSTTYPE=PROJECT|VSTORE|REDIR|CUSTOM
HOST-KILL?HOSTNAME=www
EMAIL-DKIM-INIT
EMAIL-SET?TYPE=FUSEMAIL|GOOGLE|NONE|MX&MX1=&MX2=
VSTORE-MAKE-PRIMARY
VSTORE-KILL-REWRITE?PATH=
VSTORE-ADD-REWRITE?PATH=&TARGETURL=
]]>
</input>
</API>



=cut

sub adminDomain {
	my ($self, $v) = @_;

	my %options = ();
	my %R = ();	
	if ($v->{'prt'}) { $options{'PRT'} = int($v->{'prt'}); }
	require DOMAIN;
	require DOMAIN;
	require DOMAIN::TOOLS;

	my ($udbh) = &DBINFO::db_user_connect($self->username());

	if ($v->{'_cmd'} eq 'adminDomainList') {
		my @RESULTS = ();

		foreach my $domain (&DOMAIN::list($self->username(),%options)) {
			my ($D) = DOMAIN->new($self->username(),$domain);

			$R{'media-host'} = &ZOOVY::resolve_media_host($self->username());
			my %DOMAIN = ( 'DOMAINNAME'=>$domain, 'IS_FAVORITE'=>int($D->get('IS_FAVORITE')), 'PRT'=>$D->prt()+$JSONAPI::PARTITION_OFFSET, 'LOGO'=>$D->logo() );
			if ($v->{'hosts'}) { $DOMAIN{'@HOSTS'} = $D->hosts(); }

			push @RESULTS, \%DOMAIN;
			}

		
		$R{'@DOMAINS'} = \@RESULTS;
		&JSONAPI::append_msg_to_response(\%R,'success',0);	
		}
	elsif ($v->{'_cmd'} eq 'adminDomainDiagnostics') {
		my $DOMAINNAME = $v->{'DOMAINNAME'};
		$DOMAINNAME =~ s/^[\s]+//g;	 # strip leading whitespace
		$DOMAINNAME =~ s/[\s]$+//g;	 # strip trailing whitespace.
		my ($D) = undef;
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'DOMAINNAME')) {
			}
		else {
			$D = DOMAIN->new($self->username(),$DOMAINNAME);
			if ((not defined $D) || (ref($D) ne 'DOMAIN')) {
				&JSONAPI::set_error(\%R,'apperr',3911,"adminDomainMacro requires \@updates with macro commands (not defined)");
				}
			}

		if (not &JSONAPI::hadError(\%R)) {

			my ($LM) = LISTING::MSGS->new($self->username());
			$LM->pooshmsg(sprintf('INFO|+DOMAIN:%s',$DOMAINNAME));

			my @HOSTS = @{$D->hosts()};
			
			if (scalar(@HOSTS)==0) {
				$LM->pooshmsg(sprintf("ERROR|+No hosts configured for domain"));
				}

			require Net::DNS;
			my @TEST_SERVERS = ();
			my @LINES = File::Slurp::read_file("/etc/resolv.conf");
			foreach my $SERVER (@LINES) {
				$SERVER =~ s/[\n\r]+//gs;
				$SERVER =~ s/^.*?([\d]+\.[\d]+\.[\d]+\.[\d]+).*?$/$1/;
				push @TEST_SERVERS, $SERVER;
				}

			$LM->pooshmsg("INFO|+TEST SERVERS: ".join(",",@TEST_SERVERS));

			foreach my $HOST (@{$D->hosts()}) {
				my $HOSTNAME = $HOST->{'HOSTNAME'};
				my $IPV4 = $HOST->{'IP4'};
				if ((not defined $IPV4) || ($IPV4 eq '')) {
					$IPV4 = &DOMAIN::whatis_public_vip($self->username());
					}

				$LM->pooshmsg(sprintf("INFO|+HOST:%s TYPE:%s IP:%s",$HOST->{'HOSTNAME'},$HOST->{'HOSTTYPE'},$IPV4));
	

				foreach my $SERVER (@TEST_SERVERS) {
					# $LM->pooshmsg("INFO|+server: [$SERVER]");
					my $res   = Net::DNS::Resolver->new(nameservers => [$SERVER]);

					# my $res   = Net::DNS::Resolver->new;
					my $query = $res->query(sprintf('%s.%s',$HOSTNAME,$DOMAINNAME),'A');
					if ($query) {
				 		foreach my $rr ($query->answer) {
					  		next unless $rr->type eq "A";
							my ($MATCH) = ($rr->address() eq $IPV4)?'MATCH':'**NO_MATCH**';
							$LM->pooshmsg(sprintf("INFO|+- %s(A) = %s  %s",$SERVER, $rr->address,$MATCH));
				 			}
						} 
					else {
						$LM->pooshmsg(sprintf("INFO|+ERROR %s query failed: %s",$SERVER,$res->errorstring));
						}		

					}

				}

			foreach my $msg (@{$LM->msgs()}) {
				my ($ref) = &LISTING::MSGS::msg_to_disposition($msg);
				if (substr($ref->{'+'},0,1) eq '+') { $ref->{'+'} = substr($ref->{'+'},1); }
				push @{$R{'@MSGS'}}, $ref;
				}
			}
		}
	elsif ($v->{'_cmd'} eq 'adminDomainDetail') {
		my $DOMAINNAME = $v->{'DOMAINNAME'};
		$DOMAINNAME =~ s/^[\s]+//g;	 # strip leading whitespace
		$DOMAINNAME =~ s/[\s]$+//g;	 # strip trailing whitespace.
		my ($D) = undef;
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'DOMAINNAME')) {
			}
		else {
			$D = DOMAIN->new($self->username(),$DOMAINNAME);
			if ((not defined $D) || (ref($D) ne 'DOMAIN')) {
				&JSONAPI::set_error(\%R,'apperr',3911,"adminDomainMacro requires \@updates with macro commands (not defined)");
				}
			}

		if (not &JSONAPI::hadError(\%R)) {
			$R{'DOMAINNAME'} = $DOMAINNAME;
			$R{'PRT'} = $D->prt()+$JSONAPI::PARTITION_OFFSET;
			$R{'LOGO'} = $D->logo();
			my @HOSTS = ();
			foreach my $HOSTNAME (keys %{$D->{'%HOSTS'}}) {
				$D->{'%HOSTS'}->{$HOSTNAME}->{'HOSTNAME'} = $HOSTNAME;
				push @HOSTS, $D->{'%HOSTS'}->{$HOSTNAME};
				}

			$R{'@HOSTS'} = \@HOSTS;

			$R{'%EMAIL'} = &ZTOOLKIT::parseparams($D->{'EMAIL_CONFIG'});
			$R{'%EMAIL'}->{'TYPE'} = $D->{'EMAIL_TYPE'};
			$R{'@HISTORY'} = [];
			if ($self->apiversion()<201334) {
				push @{$R{'@HISTORY'}}, { CREATED_GMT=>time(), TXT=>"Please use a newer version" };
				}

			my $udbh = &DBINFO::db_user_connect($self->username());
			my $MID = int($self->{'MID'});
			my $qtDOMAIN = $udbh->quote($self->{'DOMAIN'});
			my $pstmt = "select * from DOMAIN_LOGS where MID=$MID and DOMAIN=$qtDOMAIN order by ID";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			my @result = ();
			while ( my $ref = $sth->fetchrow_hashref() ) {
				push @{$R{'@HISTORY'}}, $ref;
				}
			$sth->finish();
			&DBINFO::db_user_close();

			my %STATUS = ();
			$R{'@READONLY'} = \%STATUS;
			$STATUS{'REG_TYPE'} = $D->{'REG_TYPE'};
			$STATUS{'REG_TYPE_TXT'} = $DOMAIN::REG_TYPES{$D->{'REG_TYPE'}};
			$R{'IS_SYNDICATION'} = int($D->{'SYNDICATION_ENABLE'});
			$R{'IS_PRIMARY'} = int($D->{'IS_PRT_PRIMARY'});
			$R{'IS_FAVORITE'} = int($D->{'IS_FAVORITE'});

			#if ($D->{'REG_TYPE'} eq 'ZOOVY') {
			#	$STATUS{'CREATED_GMT'} = $D->{'CREATED_GMT'};
			#	$STATUS{'REG_STATUS'} = $D->{'REG_STATUS'};
			#	}
			my $USERPATH = &ZOOVY::resolve_userpath($self->username());
			$R{'PROJECTID'} = (-d PROJECT::projectdir($self->username(),lc($DOMAINNAME)))?lc($DOMAINNAME):'';
			}
		}
	elsif ($v->{'_cmd'} eq 'adminDomainMacro') {
		my $DOMAINNAME = $v->{'DOMAINNAME'};
		$DOMAINNAME =~ s/^[\s]+//g;	 # strip leading whitespace
		$DOMAINNAME =~ s/[\s]$+//g;	 # strip trailing whitespace.

		if ($v->{'_cmd'} eq 'adminDomainMacro') {
			if (not defined $v->{'@updates'}) {
				&JSONAPI::set_error(\%R,'apperr',3916,"adminDomainMacro requires \@updates with macro commands (not defined)");
				}
			elsif (scalar(@{$v->{'@updates'}})==0) {
				&JSONAPI::set_error(\%R,'apperr',3915,"adminDomainMacro requires \@updates with macro commands (field exists, but empty)");
				}
			}

		my @CMDS = ();
		my $count = 0;
		if (not &JSONAPI::hadError(\%R)) {
			foreach my $line (@{$v->{'@updates'}}) {		
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					$cmdset->[1]->{'luser'} = $self->luser();
					$cmdset->[2] = $line;
					$cmdset->[3] = $count++;
					push @CMDS, $cmdset;
					}
				}
			}

		my ($D) = undef;
		if (&JSONAPI::hadError(\%R)) {
			}
		elsif ($CMDS[0]->[0] eq 'DOMAIN-RESERVE') {
			## $D will be initialized by the first parameter.
			}
		elsif ($DOMAINNAME eq '') {
			&JSONAPI::set_error(\%R,'apperr',3921,"Domain name is required for all types except 'RESERVE'");
			}
		elsif ($DOMAINNAME =~ /^www\./) {
			&JSONAPI::set_error(\%R,'apperr',3921,"The leading www. is part of the hostname, not the domain name. Please remove the www. and try again.");
			}
			elsif ($DOMAINNAME =~ /^app\./) {
			&JSONAPI::set_error(\%R,'apperr',3921,"The leading app. is part of the hostname, not the domain name. Please remove the www. and try again.");
			}
		elsif ($DOMAINNAME =~ /^m\./) {
			&JSONAPI::set_error(\%R,'apperr',3921,"The leading m. is part of the hostname, not the domain name. Please remove the www. and try again.");
			}
		elsif ($DOMAINNAME !~ /\./) {
			&JSONAPI::set_error(\%R,'apperr',3921,"Domain names must have at least one . in them");
			}
		elsif (length($DOMAINNAME)>50) {
			&JSONAPI::set_error(\%R,'apperr',3921,"Domain name may not exceed 50 characters total");
			}
		elsif (($CMDS[0]->[0] eq 'DOMAIN-DELEGATE') || ($CMDS[0]->[0] eq 'DOMAIN-CREATE')) {
			## $D will be initialized by the first parameter.
			}
		else {
			($D) = DOMAIN->new($self->username(),$DOMAINNAME);
			if (not $D) {
				&JSONAPI::set_error(\%R,'apperr',3921,"Domain $DOMAINNAME is not currently setup in your account, please register,transfer,delegate it first.");
				}
			}

		# print STDERR 'CMDS: '.Dumper(\@CMDS);
		foreach my $CMDSET (@CMDS) {
			my ($VERB, $params) = @{$CMDSET};	
			my @MSGS = ();

			if (&JSONAPI::hadError(\%R)) {
				push @MSGS, "WARN|+Command skipped due to error";
				}
			elsif ($VERB eq 'DOMAIN-RESERVE') {
				#($DOMAINNAME) = &DOMAIN::POOL::reserve($self->username(),$self->prt());
				require PLUGIN::FREEDNS;
				my $R = PLUGIN::FREEDNS::register($self->username());
				if (($R->{'err'}==0) && ($R->{'domain'})) {
					$DOMAINNAME = $R->{'domain'};
					($D) = DOMAIN->create($self->username(),$DOMAINNAME);
					$D->save();
					push @MSGS, "SUCCESS|+Reserved domain: $DOMAINNAME";
					}
				elsif ($R->{'err'}>0) {
					push @MSGS, sprintf("PLUGIN::FREEDNS issue[%d] %s",$R->{'err'},$R->{'msg'});
					}
				else {
					push @MSGS, "ERROR|Could not reserve a domain, unspecified error - please open a support ticket.";
					}
				}
			elsif ($VERB eq 'DOMAIN-TRANSFER') {
				push @MSGS, "ERROR|+DOMAIN-TRANSFER functionality no longer available.";
				#if (DOMAIN::REGISTER::DomainAvailable($DOMAINNAME)) {
				#	&JSONAPI::set_error(\%R,'apperr',3921,"Sorry, but domain $DOMAINNAME is not registered [cannot be transferred], use REGISTER instead");
				#	}
				#elsif (&DOMAIN::REGISTER::BelongsToRsp($DOMAINNAME)) {
				#	## already belongs to us
				#	# my ($BILL_ID) = &DOMAIN::REGISTER::verify_billing($self->username(),$DOMAINNAME);
				#	#my ($D) = DOMAIN->create($self->username(),$DOMAINNAME,'REG_TYPE'=>'ZOOVY','REG_STATUS'=>"Billing Record: $BILL_ID");
				#	#push @MSGS, "SUCCESS|+Performed simulated transfer for domain:$DOMAINNAME";
				#	}
				#elsif (DOMAIN::REGISTER::is_locked($DOMAINNAME)) {
				#	&JSONAPI::set_error(\%R,'apperr',3921,"Domain is currently locked and cannot be transferred, please ask your current register to unlock it.");
				#	}
				#else {
				#	push @MSGS, "ERROR|+We are no longer allowing non-registered domains to be transferred, please use delegate instead";
				#	}
				}
			elsif ($VERB eq 'DOMAIN-REGISTER') {
				push @MSGS, "ERROR|+DOMAIN-REGISTER functionality no longer available.";
				## subdomain.domain.com
				##	domain.com
				##	somedomain.co.uk
				#my @parts = split(/\./,$v->{'DOMAIN'});
				#my $subdomain = shift @parts;
				#$DOMAINNAME = join(".",@parts);

				#my @errors = &DOMAIN::TOOLS::valid_domain($DOMAINNAME);
				#if (scalar(@errors)==0) {
				#	require DOMAIN::REGISTER;
				#	if (not &DOMAIN::REGISTER::DomainAvailable($DOMAINNAME)) {
				#		push @MSGS, "ERROR|+Sorry, the domain [$DOMAINNAME] is not available and has already been registered by somebody else, (if you are the owner perhaps you meant to do a transfer)";
				#		}
				#	}

				#my $lm = LISTING::MSGS->new($self->username(),logfile=>'domains.log');
				#my ($RESULT) = DOMAIN::REGISTER::register($self->username(),$DOMAINNAME,'*LM'=>$lm,'reg_type'=>'new');
				#if (defined $RESULT) {
				#	($D) = DOMAIN->create($self->username(),$DOMAINNAME,%{$RESULT});
				#	}
				}
			elsif (($VERB eq 'DOMAIN-DELEGATE') || ($VERB eq 'DOMAIN-CREATE')) {		
				## DOMAIN-DELEGATE was unclear and was deprecated as of 201404
				my $lm = LISTING::MSGS->new($self->username(),logfile=>'domains.log');
				my %RESULT = ();
				$RESULT{'REG_STATUS'} = 'External Registrar';
				$RESULT{'REG_TYPE'} = 'OTHER';
				if (($D) = DOMAIN->create($self->username(),$DOMAINNAME,%RESULT)) {
					push @MSGS, "SUCCESS|+Created entry in DOMAINS database (please allow 3-4 hours for changes to be visible)";
					}
				else {
					push @MSGS, "ERROR|+Domain $DOMAINNAME could not be added";
					$D = undef;
					}
				}
			elsif ($VERB eq 'DOMAIN-REMOVE') {
				my $ALLOWED = 1;
				#if (&DOMAIN::REGISTER::BelongsToRsp($D->{'DOMAIN'})) { $ALLOWED = 0; }
				if ($self->LU()->is_support()) { $ALLOWED++; }

				if (not $ALLOWED) {
					push @MSGS, qq~ERROR|+Sorry, this domain appears to be registered with us and cannot be removed as a safety precaution. Please contact support to have it set to expire/unlocked before it can be removed.~;
					}
				elsif ($D->nuke('*LU'=>$self->LU())) {
					push @MSGS, "SUCCESS|+Removed Domain";
					$D = undef;
					}
				else {
					push @MSGS, qq~ERROR|+Sorry, something went horribly wrong when trying to remove domain.~;
					}
				
				}
			elsif (not defined $D) {
				## NOTE: all macros below this line require a $D to be set (earlier ones might have trashed $D)
				push @MSGS, "ERROR|+Skipped command $VERB because no domain is in scope.";
				}
			elsif (($VERB eq 'HOST-ADD') || ($VERB eq 'HOST-SET')) {
				my $HOSTNAME = lc($params->{'HOSTNAME'});
				$HOSTNAME =~ s/^[\s]+//g;	 # strip leading whitespace
				$HOSTNAME =~ s/[\s]$+//g;	 # strip trailing whitespace.
				$HOSTNAME =~ s/^[\d]+//g;	 # sub-domains may not start iwth a number.
				$HOSTNAME =~ s/[^a-z0-9]+//g;	 # sub-domains may not have dashes, or other funny characters
				$DOMAINNAME = $HOSTNAME.'.'.$DOMAINNAME;
				$D->{"$HOSTNAME\_HOST_TYPE"} = $params->{'HOSTTYPE'};
				$D->host_set($HOSTNAME,%{$params});
				push @MSGS, "SUCCESS|HOST:$HOSTNAME|+Host '$HOSTNAME' type:$params->{'HOSTTYPE'} was modified.";
 				}
			elsif ($VERB eq 'DOMAIN-SET-FAVORITE') {
				$D->set('IS_FAVORITE',int($params->{'IS'}));
				push @MSGS, qq~SUCCESS|+set favorite to $params->{'IS'}~;
				}
			elsif ($VERB eq 'DOMAIN-SET-PRIMARY') {
				$D->set('IS_PRT_PRIMARY',int($params->{'IS'}));
				push @MSGS, qq~SUCCESS|+set primary to $params->{'IS'}~;
				}
			elsif ($VERB eq 'DOMAIN-SET-SYNDICATION') {
				$D->set('SYNDICATION_ENABLE',int($params->{'IS'}));
				push @MSGS, qq~SUCCESS|+set syndication to $params->{'ENABLE'}~;
				}
			elsif ($VERB eq 'DOMAIN-SET-PRT') {
				$D->set('PRT',int($params->{'PRT'}));
				push @MSGS, qq~SUCCESS|+changed partition to $params->{'PRT'}~;
				}
			elsif ($VERB eq 'DOMAIN-SET-LOGO') {
				$D->set('our/company_logo', $params->{'LOGO'});
				push @MSGS, qq~SUCCESS|+changed logo to $params->{'LOGO'}~;
				}
			#elsif ($VERB eq 'HOST-SET') {
			#	my $HOSTNAME = uc($params->{'HOSTNAME'});
			#	## $D->{"$HOSTNAME\_HOST_TYPE"} = $params->{'HOSTTYPE'};
			#	$D->host_set($HOSTNAME,%{$params});
			#	if ($params->{'HOSTTYPE'} eq 'APP') {
			#		}
			#	else {
			#		push @MSGS, "SUCCESS|HOST:$HOSTNAME|+$HOSTNAME is now $params->{'HOSTTYPE'}";
			#		}
			#	}
			elsif ($VERB eq 'HOST-KILL') {
				my $HOSTNAME = uc($params->{'HOSTNAME'});
				push @MSGS, "WARN|HOST:$HOSTNAME|+$HOSTNAME has been removed";
				$D->host_kill($HOSTNAME);
				}
			elsif ($VERB eq 'HOST-SSL-UPDATE-CRT') {
				my $HOSTDOMAIN = lc(sprintf("%s.%s",$params->{'HOSTNAME'},$DOMAINNAME));
				my $DATE = &ZTOOLKIT::pretty_date(time(),3);
				my $userpath = &ZOOVY::resolve_userpath($D->username());
				my $ERROR = undef;

				if ($params->{'CRT'} eq '') {
					$ERROR = "Certificate is blank";
					}
				elsif ($params->{'CRT'} !~ /-----BEGIN CERTIFICATE-----/) {
					$ERROR = "$HOSTDOMAIN CERTIFICATE MISSING ----BEGIN";
					}
				elsif ($params->{'CRT'} !~ /-----END CERTIFICATE-----/) {
					$ERROR = "$HOSTDOMAIN CERTIFICATE MISSING ----END";
					}
	
				if ($ERROR) {
					push @MSGS, "ERROR|+$ERROR";
					}
				else {
					if (-f "$userpath/$HOSTDOMAIN.crt") {
						rename "$userpath/$HOSTDOMAIN.crt", "$userpath/$HOSTDOMAIN.crt-$DATE";
						}
					open F, ">$userpath/$HOSTDOMAIN.crt";
					print F $params->{'CRT'}."\n";
					close F;	
					}
				}
			elsif ($VERB eq 'HOST-SSL-UPDATE-KEY') {
				my $HOSTDOMAIN = lc(sprintf("%s.%s",$params->{'HOSTNAME'},$DOMAINNAME));
				my $DATE = &ZTOOLKIT::pretty_date(time(),3);
				my $userpath = &ZOOVY::resolve_userpath($D->username());
				my $ERROR = undef;

				if ($params->{'KEY'} eq '') {
					$ERROR = "Key is blank";
					}
				elsif ($params->{'KEY'} !~ /-----END (RSA )?PRIVATE KEY-----/) {
					$ERROR = "$HOSTDOMAIN KEY MISSING ----END";
					}
				elsif ($params->{'KEY'} !~ /-----BEGIN (RSA )?PRIVATE KEY-----/) {
					$ERROR = "$HOSTDOMAIN KEY MISSING ----BEGIN";
					}

				if ($ERROR) {
					push @MSGS, "ERROR|+$ERROR";
					}
				else {
					if (-f "$userpath/$HOSTDOMAIN.key") {
						rename "$userpath/$HOSTDOMAIN.key", "$userpath/$HOSTDOMAIN.key-$DATE";
						}
					open F, ">$userpath/$HOSTDOMAIN.key";
					print F $params->{'KEY'}."\n";
					close F;		
					}
				}
			elsif ($VERB eq 'EMAIL-DKIM-INIT') {
				$D->gen_dkim_keys('save'=>0);
				push @MSGS, "SUCCESS|+Initialized Domain Key (DKIM) parameters";
				}
			elsif ($VERB eq 'EMAIL-SET') {
				$D->{'EMAIL_TYPE'} = $params->{'TYPE'};
				my %EMAIL_CONFIG = ();
				foreach my $k (keys %{$params}) {
					if (uc($k) eq $k) { $EMAIL_CONFIG{$k} = $params->{$k}; }
					}
				$D->{'%EMAIL'} = \%EMAIL_CONFIG;
				$D->{'EMAIL_CONFIG'} = &ZTOOLKIT::buildparams(\%EMAIL_CONFIG);
				push @MSGS, "SUCCESS|+Email set to $D->{'EMAIL_TYPE'}";
				}
			elsif ($VERB eq 'VSTORE-ADD-REWRITE') {
				$D->add_map($params->{'PATH'},$params->{'TARGETURL'});		
				}
			elsif ($VERB eq 'VSTORE-KILL-REWRITE') {
				$D->del_map($params->{'PATH'});	
				}
			elsif ($VERB eq 'VSTORE-MAKE-PRIMARY') {
				&DOMAIN::make_domain_primary($D);
				}


			if (&JSONAPI::hadError(\%R)) {
				}
			elsif (scalar(@MSGS)>0) {	

				if (defined $D) { 
					my ($LM) = LISTING::MSGS->new($self->username(),'@MSGS'=>\@MSGS);
					$D->save(); 
					$D->update($LM);
					}		
				foreach my $msg (@MSGS) {

					if (defined $D) {
						my ($ref,$status) = LISTING::MSGS::msg_to_disposition($msg);
						$D->dlog($ref->{'_'},$ref->{'+'},$ref);
						}

					&JSONAPI::add_macro_msg(\%R,$CMDSET,$msg);
					}
				}			
			}
		
		## 
		}


	&DBINFO::db_user_close();
	return(\%R);
	}



=pod


<API id="adminPartitionList">
<purpose></purpose>
<response id="@PRTS">An array of partitions</response>
</API>

=cut


sub adminPartitionList {
	my ($self, $v) = @_;

	my %R = ();	
	my @prts = @{&ZWEBSITE::list_partitions($self->username())};
	$R{'@PRTS'} = \@prts;
	&JSONAPI::append_msg_to_response(\%R,'success',0);			
	return(\%R);	
	}




#	'adminUIExecuteCGI'=>[\&JSONAPI::adminUIExecuteCGI, { 'admin'=>1, 'cart'=>0 }, 'admin-ui', ],
=pod

<API id="adminUIExecuteCGI">
<purpose></purpose>
<input id="uri">/biz/setup/shipping/index.cgi</input>
<input id="%vars">{ x:1, y:2, z:3 }</input>
</API>

=cut

sub adminUIExecuteCGI {
   my ($self, $v) = @_;

	require GTOOLSUI;
	my $vars = $v->{'%vars'};
	if (ref($vars) ne 'HASH') { $vars = {}; }
	my ($R) = &GTOOLSUI::transmogrify($self, $v->{'uri'},$vars);
	return($R);
	}


=pod

<API id="adminUIBuilderPanelExecute">
<purpose></purpose>
<input id="sub">EDIT|SAVE|SAVE-EDIT</input>
<input id="id">element id</input>

<input id="panel">Panel Identifier (the 'id' field returned by adminUIProductList</input>
<response id="html">the html content of the product editor panel</response>
<response id="js">the js which is required by the panel.</response>
</API>

=cut

sub adminUIBuilderPanelExecute {
	my ($self,$v) = @_;

	my %R = ();
	require TOXML::EDIT;
	require TOXML::SAVE;
	require TOXML::PREVIEW;
	require SITE;


	my $USERNAME = $self->username();
	my $SUB = uc($v->{'sub'});
	my $ID = $v->{'id'};

	require LUSER;

	my $SITE = 	undef; ## SITE->new($USERNAME,'PRT'=>$self->prt(),'DOMAIN'=>$self->sdomain());
	if ($v->{'_SREF'}) {
		$SITE = SITE::sitedeserialize($USERNAME,$v->{'_SREF'});
		}
	else {
		&JSONAPI::set_error(\%R,'apperr',9134,"_SREF (SITE) was not passed to method BUILDER!\n");		
		}

	my $html = '';
	my ($t,$el,$TYPE);
	my $LOGTYPE = '';
	my $out = '';

	my $FORMAT = $SITE->format();
	my $LAYOUT = $SITE->layout();

	if (&JSONAPI::hadError(\%R)) {
		## skip if we encountered an error
		}				
	elsif ($SITE->format() eq 'WRAPPER') {
		# $LAYOUT = $SITE->layout();
		$LOGTYPE = "WRAPPER=$LAYOUT";
		}
	elsif ($SITE->format() eq 'PRODUCT') {	## if sku is set, then set $SREF->{'
		# $LAYOUT = PRODUCT->new($USERNAME,$SITE->sku())->fetch('zoovy:fl');
		# $LAYOUT = &ZOOVY::fetchproduct_attrib($USERNAME,$SITE->sku(),'zoovy:fl');
		# set flow style to 'P' for proper defaulting?!?! (probably not necessary)
		$LOGTYPE = sprintf("PRODUCT=%s LAYOUT=$LAYOUT",$SITE->sku());
		}
	elsif ($SITE->format() eq 'PAGE') { 		## default 
		$LOGTYPE = sprintf("PAGE=%s LAYOUT=$LAYOUT",$SITE->pageid());
		}
	else {	
		## yeah it's all good.
		}

	print STDERR "LOG TPE $LOGTYPE\n";
	
	if (&JSONAPI::hadError(\%R)) {
		}
	else {
		($t) = TOXML->new($SITE->format(),$SITE->layout(),USERNAME=>$USERNAME,SUBTYPE=>$SITE->fs());
		if (not defined $t) { 
			&JSONAPI::set_error(\%R,'apperr',9135,"Could not load TOXML layout FORMAT=[$FORMAT] LAYOUT=[$LAYOUT]");
			}
		}

	if (not &JSONAPI::hadError(\%R)) {
		($el) = $t->fetchElement($ID,$SITE->div());
		$LOGTYPE .= " ELEMENT=".$el->{'ID'};
		if (not defined $el) { 
			&JSONAPI::set_error(\%R,'apperr',9136,"Could not find element ID[$ID] from Toxml file FORMAT[$FORMAT] LAYOUT[$LAYOUT]");
			}
		}

	##
	## SANITY: at this point the following variables are either setup or $ERROR is set.
	##		p=Current Page, t=Current TOXML document, el=current element in focus, type=>
	##

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (($SUB eq 'SAVE') || ($SUB eq 'SAVE-EDIT')) {	
		## note if we recive a variable of ACTION=reload then we'll go back and try editing again.
		## used to reload options based on a choice (e.g. prodlist)
		$TYPE = $el->{'TYPE'};
		if (($TYPE eq 'PRODLIST') && ($v->{'func'} eq 'LISTEDITOR')) {	$TYPE = 'LISTEDITOR'; }
		if ($TYPE eq '') { 
			&JSONAPI::set_error(\%R,'apperr',9140,"Element type was not set (how odd??)[1]");
			}
		elsif (not defined $TOXML::EDIT::edit_element{ $TYPE }) { 
			&JSONAPI::set_error(\%R,'apperr',9141,"Undefined editor for TYPE=[$TYPE]"); 
			}
		else {
			# use Data::Dumper; print STDERR Dumper($el,$v,$SREF); 
			# print STDERR "SAVING: $TYPE\n";
			($TYPE,my $prompt,$html) = $TOXML::SAVE::save_element{$TYPE}->($el,$v,$SITE); 
			$self->accesslog("AJAX.BUILDER.SAVE",$LOGTYPE,"INFO");
			}

		# push @CMDS, { m=>'hideeditor' };
		# $out .= "?m=hideeditor";
		# if (uc($v->{'ACTION'}) eq 'RELOAD') { $SUB = 'EDIT'; $out =''; }	

		## we always return the full page because an element earlier on a page might affect an element later
		my ($html) = $t->render('*SITE'=>$SITE);

		#$html = qq~
		#	<div id="editorDiv" style="width: 780px; display: none"></div>
		#	<div style="border: 1px solid #999999">
		#		<table  bgcolor="<!-- BGCOLOR -->" width="100%">
		#		<tr><td align="left" valign='top'><div style="text-align: left" id="contentDiv">$html</div></td></tr>
		#		</table>
		#	</div>
		#	~;

		$html .= qq~<button class="button2" onClick="navigateTo('/biz/vstore/builder/index.cgi');">Exit</button>~;
		$R{'html'} = $html;

		# $html = "FL: $SREF->{'_FL'} | PG: $SREF->{'_PG'} | SKU: $SREF->{'_SKU'} | FS: $SREF->{'_FS'}<br><hr>".$html;
		# $out .= "?m=loadcontent&html=".&js_encode($html);
		
		# push @CMDS, { m=>'loadcontent', html=>$html };

		if ($SUB eq 'SAVE-EDIT') { $SUB = 'EDIT'; }
		# if (uc($CMD) eq 'RELOAD') { $SUB = 'EDIT'; }
		}


	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($SUB eq 'EDIT') {
		$TYPE = $el->{'TYPE'};
		if (($TYPE eq 'PRODLIST') && ($v->{'func'} eq 'LISTEDITOR')) {	$TYPE = 'LISTEDITOR'; }

		# print STDERR "TYPE IS: $TYPE\n";
		if ($TYPE eq '') { 
			&JSONAPI::set_error(\%R,'apperr',9144,"Element type was not set (how odd??)[2]");
			}
		elsif (not defined $TOXML::EDIT::edit_element{ $TYPE }) { 
			&JSONAPI::set_error(\%R,'apperr',9142,"Undefined editor for TYPE=[$TYPE]");
			}
		else { 
			# $el->{'_FORM'} = "thisFrm-$ID";
			(my $STYLE,my $prompt,$html,my $extra) = $TOXML::EDIT::edit_element{$TYPE}->($el,$t,$SITE,$v); 
			
			## normally we'd just call saveElement, but for LISTEDITOR we need to do some other stuff.
			# my $jsaction = qq~saveElement('$TYPE','$ID');~;
			#if ($TYPE eq 'LISTEDITOR') {
			#	$jsaction = qq~setorder(document.thisFrm.list1,document.thisFrm.listorder); $jsaction~;
			#	}
				## NOTE: textarea's return the input in the PROMPT (how dumb!)
			if ($STYLE eq 'TEXTAREA') {
				$html = $prompt; $prompt = $el->{'PROMPT'};
				}
			elsif ($STYLE eq 'IMAGE') {
				$html = "<table border=0><tr><td valign='top'>$html</td><td valign='top'>$extra</td></tr></table>";
				}

			$R{'id'} = $ID;
			$R{'type'} = $TYPE;
			$R{'prompt'} = $prompt;
			$R{'html'} = $html;
			$R{'_SREF'} = $SITE->siteserialize();
			}
		}
	
	if ($SUB eq 'RELOAD') {
		# use Data::Dumper; print STDERR Dumper($SREF);
		my ($html) = $t->render('*SITE'=>$SITE);
		# $html = "FL: $SREF->{'_FL'} | PG: $SREF->{'_PG'} | SKU: $SREF->{'_SKU'} | FS: $SREF->{'_FS'}<br><hr>".$html;
		# $out = "?m=loadcontent&id=$ID&html=".&js_encode($html);
		# push @CMDS, { m=>'loadcontent', id=>$ID, html=>$html };
		$R{'html'} = $html;
		}

	if ($R{'html'}) {
		## strip head and body tags
		$R{'html'} =~ s/\<[\/]?[Hh][Tt][Mm][Ll]>//gs;
		$R{'html'} =~ s/\<[Hh][Ee][Aa][Dd]\>.*?\<\/[Hh][Ee][Aa][Dd]\>//gs;
		$R{'html'} =~ s/\<[\/]?[Bb][Oo][Dd][Yy].*?\>//gs;
		}
	
	undef $t; undef $el;
	# $R{'@CMDS'} = \@CMDS;

	return(\%R);
	}




=pod

<API id="adminUIMediaLibraryExecute">
<purpose></purpose>
<input id="verb">LOAD|SAVE</input>
<input id="src">(required for LOAD|SAVE)</input>
<input id="IMG">(required for SAVE)</input>
<response id="IMG"></response>
</API>

=cut

sub adminUIMediaLibraryExecute {
	my ($self,$v) = @_;

	my %R = ();
	# $R{'img'} = $s->{'IMG'};
	my $s = &ZTOOLKIT::parseparams($v->{'src'});
	my $mode = $s->{'mode'};
	print STDERR 'MEDIALIB INCOMING PARAMETERS (PARSED): '.Dumper($s);

	my $VERB = $v->{'verb'};
	my $USERNAME = $self->username();
	my $PRT = $self->prt();
	my $JS = '';

	if ($VERB eq 'LOAD') {
		}
	elsif ($VERB eq 'SAVE') {
		}
	else {
		&JSONAPI::set_error(\%R, 'apperr', 3234, "verb must be LOAD|SAVE");
		}

	##
	## parameters:
	##
	## 	mode=logo			(popup)
	##			-> sets zoovy:company_logo
	##			-> sets webdb - company_logo
	##
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'src'} eq '') {
		&JSONAPI::set_error(\%R, 'apperr', 3236, "src is required");
		}
	elsif ($mode eq 'logo') {
		my ($D) = DOMAIN->new($self->username(),$self->sdomain());
		# my $profile = $s->{'profile'};	
		if ($VERB eq 'LOAD') {
			# $R{'IMG'} = &ZOOVY::fetchmerchantns_attrib($USERNAME,$profile,'zoovy:logo_website');
			$R{'IMG'} = $D->get('our/logo_website');
			}
		elsif ($VERB eq 'SAVE') {
			# &ZOOVY::savemerchantns_attrib($USERNAME,$profile,'zoovy:logo_website',$v->{'IMG'});
			$D->set('our/logo_website',$v->{'IMG'});
			$D->save();
			}
		&JSONAPI::append_msg_to_response(\%R,'success',0);
		}
	##		mode=ilogo			(popup)
	##			-> sets zoovy:invoice_logo
	##
	elsif ($mode eq 'ilogo') {
		my ($D) = DOMAIN->new($self->username(),$self->sdomain());
		#my $profile = $s->{'profile'};
		if ($VERB eq 'LOAD') {
			$R{'IMG'} = $D->get('our/logo_invoce');
			# $R{'IMG'} = &ZOOVY::fetchmerchantns_attrib($USERNAME,$profile,'zoovy:logo_invoice');
			}
		elsif ($VERB eq 'SAVE') {
			$D->set('our/logo_invoice',$v->{'IMG'});
			$D->save();
			# &ZOOVY::savemerchantns_attrib($USERNAME,$profile,'zoovy:logo_invoice',$v->{'IMG'});
			}
		&JSONAPI::append_msg_to_response(\%R,'success',0);
		}
	##		mode=customerlogo	(popup)	(myForm.logoImg)
	##			-> sets CUSTOMER->{'WS'}->{'LOGO'} property!
	##			-> this is passed CID (customer id) 
	##
	elsif ($mode eq 'customerlogo') {
		require CUSTOMER;
		my ($C) = CUSTOMER->new($USERNAME,CID=>$s->{'CID'},'INIT'=>16);

		if ($VERB eq 'LOAD') {
			$R{'IMG'} = $C->fetch_attrib('WS.LOGO');
			require MEDIA;
			&MEDIA::mkfolder($USERNAME,'protected');
			$s->{'PWD'} = 'protected';
			}
		elsif ($VERB eq 'SAVE') {
			$C->set_attrib('WS.LOGO',$v->{'IMG'});
			$C->save_wholesale(1);
			$C->save();
			}
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
	elsif ($mode eq 'prodsku') {
		my ($PID) = &PRODUCT::stid_to_pid($s->{'sku'});
		my ($P) = PRODUCT->new($USERNAME,$PID,'create'=>0);
		my $skuref = $P->skuref($s->{'sku'});
		my $attrib = $s->{'img'};  
		$attrib =~ s/^Image([\d])+:.*$/$1/; 
		$attrib = lc("zoovy:prod_image$attrib");

		print STDERR "VERB:$VERB\n";
		if ($VERB eq 'LOAD') {
			$R{'IMG'} = $P->skufetch($s->{'sku'},$attrib);
			}
		elsif ($VERB eq 'SAVE') {
			# &ZOOVY::fetchsku_as_hashref($USERNAME,$s->{'sku'});
			print STDERR "$s->{'sku'},$attrib,$v->{'IMG'}\n";
			$P->skustore($s->{'sku'},$attrib,$v->{'IMG'});
			$P->save();
			}
		&JSONAPI::append_msg_to_response(\%R,'success',0);
		}
	##		mode=prodimgmgr (myForm)
	##			-> product=PRODUCT
	##			-> attrib=zoovy:prod_image1,zoovy:prod_image2
	elsif ($mode eq 'prodimgmgr') {
		my ($P) = PRODUCT->new($USERNAME,$s->{'prod'},'create'=>0);
		if (not defined $P) {
			}
		elsif ($VERB eq 'LOAD') {
			$R{'IMG'} = $P->fetch( lc($s->{'attrib'}) );
			}
		elsif ($VERB eq 'SAVE') {
			$P->store($s->{'attrib'},$v->{'IMG'}); $P->save();
			}
		&JSONAPI::append_msg_to_response(\%R,'success',0);
		}
	##
	##		mode=prodflexedit (myForm)
	##				-> product=PRODUCT
	##			-> attrib=zoovy:prod_image1,zoovy:prod_image2
	elsif ($mode eq 'prodflexedit') {
		my $PID = $s->{'prod'};
		if ($PID eq '') { $PID = $s->{'product'}; }
		my ($P) =  PRODUCT->new($USERNAME,$PID,'create'=>0);
		if ($VERB eq 'LOAD') {
			$R{'IMG'} = $P->fetch( lc($s->{'attrib'}) );
			}
		elsif ($VERB eq 'SAVE') {
			$P->store($s->{'attrib'},$v->{'IMG'}); $P->save();
			}
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
	##
	##		mode=prod						(myForm.Thumb)
	##			-> prod=PRODUCT
	##			-> img=Thumb,Image1,Image2,..
	elsif ($mode eq 'prod') {
		my ($P) = PRODUCT->new($USERNAME,$s->{'prod'},'create'=>0);
		if (not defined $P) { 
			&JSONAPI::set_error(\%R,'apperr',234,sprintf("Product '%s' could not be loaded",$s->{'prod'}));
			}
		elsif ($VERB eq 'LOAD') {
			$R{'IMG'} = $P->fetch( lc('zoovy:prod_'.$s->{'img'}) ); 
			}
		elsif ($VERB eq 'SAVE') {
			$P->store(lc('zoovy:prod_'.$s->{'img'}),$v->{'IMG'});	
			$P->save();
			}
		else {
			&JSONAPI::set_error(\%R,'apperr',235,'Invalid mode');
			}
		}
	##
	##			mode=navcat						(myForm.imgX)
	##			-> safe=category safename
	##			-> img=image name
	##			-> thumb= where to save the image preview
	elsif ($mode eq 'navcat') {
		require NAVCAT;
		my ($NC) = NAVCAT->new($USERNAME,PRT=>$PRT);
		(undef,undef,undef,undef,my $metaref) = $NC->get($s->{'safe'});
		if ($VERB eq 'LOAD') {
			$R{'IMG'} = $metaref->{'CAT_THUMB'};
			}
		elsif ($VERB eq 'SAVE') {
			$metaref->{'CAT_THUMB'} = $v->{'IMG'};
			$NC->set($s->{'safe'}, metaref=>$metaref);
			$NC->save();
			}
		&JSONAPI::append_msg_to_response(\%R,'success',0);
		}
	else {
		&JSONAPI::set_error(\%R, 'iseerr', 3235, sprintf("embedded mode '%s' (in src '%s') is not supported",$mode,$v->{'src'}));
		}

	$s->{'USERNAME'} = $USERNAME;

	## Speciality Logo
	return(\%R);
	}




=pod

<API id="adminTOXMLSetFavorite">
<purpose></purpose>
<input id="format">WRAPPER|LAYOUT|EMAIL</input>
<input id="docid"></input>
<input id="favorite">true|false</input>
</API>

=cut

#	'adminTOXMLRemember'=>[\&JSONAPI::adminTOXMLRemember, { 'admin'=>1, }, 'admin-ui', ],
sub adminTOXMLSetFavorite {
	my ($self, $v) = @_;
	my %R = ();

	require TOXML::UTIL;
	my $FORMAT = $v->{'format'};
	my $DOCID = $v->{'docid'};
	my $USERNAME = $self->username();
	if (not JSONAPI::validate_required_parameter(\%R,$v,'favorite')) {
		}
	elsif (not JSONAPI::validate_required_parameter(\%R,$v,'docid')) {
		}
	elsif (not JSONAPI::validate_required_parameter(\%R,$v,'format')) {
		}
	elsif ($v->{'favorite'}) {
		TOXML::UTIL::remember($USERNAME,$FORMAT,$DOCID);
		}
	else {
		TOXML::UTIL::forget($USERNAME,$FORMAT,$DOCID);
		}
	return(\%R);
	}




=pod

<API id="adminLUserTagList">
<purpose></purpose>
<input id="tag"></input>
</API>


<API id="adminLUserTagSet">
<purpose></purpose>
<input id="tag">data	</input>
<hint>Limited to 128 bytes per tag, 10,000 tags max (then old tags are auto-expired)</hint>
</API>


<API id="adminLUserTagGet">
<purpose></purpose>
<input id="tag1">''</input>
<input id="tag2">''</input>
</API>

=cut

sub adminLUserTag {
	my ($self,$v) = @_;

	my %R = ();	
	my ($LU) = $self->LU();

	if ($v->{'_cmd'} eq 'adminLUserTagList') {
		#foreach my $tag (keys %{$v}) {
		#	$LU->set($tag,$v->{$tag}); 
		#	}	
		#$LU->save();
		}	
	elsif ($v->{'_cmd'} eq 'adminLUserTagSet') {
		foreach my $tag (keys %{$v}) {
			$LU->set($tag,$v->{$tag}); 
			}	
		$LU->save();
		}	
	elsif ($v->{'_cmd'} eq 'adminLUserTagGet') {
		foreach my $tag (keys %{$v}) {
			$R{$tag} = $LU->get($tag);
			}	
		}

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}

	return(\%R);
	}






=pod

<API id="bossUserCreate">
<purpose></purpose>
<input id="tag"></input>
</API>

<API id="bossUserList">
<purpose></purpose>
<input id="tag"></input>
</API>

<API id="bossUserUpdate">
<purpose></purpose>
<input id="tag"></input>
</API>

<API id="bossUserDelete">
<purpose></purpose>
<input id="tag"></input>
</API>

<API id="bossUserDetail">
<purpose></purpose>
<input id="tag"></input>
</API>


=cut

sub bossUser {
	my ($self,$v) = @_;

#mysql> desc LUSERS;
#+--------------------+----------------------------+------+-----+---------------------+----------------+
#| Field              | Type                       | Null | Key | Default             | Extra          |
#+--------------------+----------------------------+------+-----+---------------------+----------------+
#| UID                | smallint(5) unsigned       | NO   | PRI | NULL                | auto_increment |
#| MID                | int(11)                    | NO   | MUL | 0                   |                |
#| USERNAME           | varchar(20)                | NO   | MUL | NULL                |                |
#| LUSER              | varchar(20)                | NO   |     | NULL                |                |
#| PRT                | int(11)                    | NO   |     | 0                   |                |
#| FULLNAME           | varchar(50)                | NO   |     | NULL                |                |
#| JOBTITLE           | varchar(50)                | NO   |     | NULL                |                |
#| EMAIL              | varchar(60)                | NO   |     | NULL                |                |
#| PHONE              | varchar(20)                | NO   |     | NULL                |                |
#| CREATED_GMT        | int(11)                    | NO   |     | 0                   |                |
#| LASTLOGIN_GMT      | int(11)                    | NO   |     | 0                   |                |
#| LOGINS             | int(10) unsigned           | NO   |     | 0                   |                |
#| IS_BILLING         | enum('Y','N')              | NO   |     | N                   |                |
#| IS_CUSTOMERSERVICE | enum('Y','N')              | YES  |     | NULL                |                |
#| IS_ADMIN           | enum('Y','N')              | YES  |     | NULL                |                |
#| EXPIRES_GMT        | int(11)                    | NO   |     | 0                   |                |
#| PASSWORD           | varchar(50)                | NO   |     | NULL                |                |
#| PASSWORD_CHANGED   | datetime                   | NO   |     | 0000-00-00 00:00:00 |                |
#| DT_CUID            | varchar(128)               | NO   |     | NULL                |                |
#| DT_REGISTER_GMT    | int(11)                    | NO   |     | 0                   |                |
#| DT_LASTPOLL_GMT    | int(11)                    | NO   |     | 0                   |                |
#| DATA               | mediumtext                 | NO   |     | NULL                |                |
#| ALLOW_FORUMS       | enum('Y','N')              | NO   |     | N                   |                |
#| HAS_EMAIL          | enum('Y','N','WAIT','ERR') | NO   |     | N                   |                |
#| WMS_DEVICE_PIN     | varchar(10)                | YES  |     | NULL                |                |
#+--------------------+----------------------------+------+-----+---------------------+----------------+
#32 rows in set (0.00 sec)

	my %R = ();	

	require BOSSTOOLS;	

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	if (($v->{'_cmd'} eq 'bossUserCreate') || ($v->{'_cmd'} eq 'bossUserUpdate')) {
		my $LOGIN = lc($v->{'login'});
 		my $ERROR = undef;

		if ((not defined $ERROR) && ($ERROR = &BOSSTOOLS::isLoginValid($self->username(),$LOGIN))) {
			&JSONAPI::set_error(\%R,'apierr',78001,"login not allowed - reason: $ERROR");
			}

		my $MID = $self->mid();
		my %UREF = ();
		$UREF{'USERNAME'} = $self->username();
		$UREF{'MID'} = $self->mid();
		$UREF{'LUSER'} = $LOGIN;

		my $pstmt = "select count(*) from LUSERS where MID=$MID and LUSER=".$udbh->quote($LOGIN);
		my ($exists) = $udbh->selectrow_array($pstmt);

		if ($v->{'_cmd'} eq 'bossUserCreate') {
			if ($exists) {
				&JSONAPI::set_error(\%R,'youerr',78002,"login already exists");
				}
			$UREF{'CREATED_GMT'} = time();
			}

		if ($v->{'_cmd'} eq 'bossUserUpdate') {
			if (not $exists) {
				&JSONAPI::set_error(\%R,'youerr',78002,"login does not exist.");
				}
			}


		my $PASSWORD = $v->{'password'};
		if (defined $PASSWORD) {
			$UREF{'PASSWORD'} = $PASSWORD;
			$UREF{'*PASSWORD_CHANGED'} = 'now()';
			$UREF{'PASSSALT'} = time();
			$UREF{'PASSHASH'} = Digest::SHA1::sha1_hex($PASSWORD.$UREF{'PASSSALT'});
			}
		

		if (not &JSONAPI::hadError(\%R)) {			
			if (defined $v->{'phone'}) { $UREF{'PHONE'} = sprintf("%s",$v->{'phone'}); }
			if (defined $v->{'jobtitle'}) { $UREF{'JOBTITLE'} = sprintf("%s",$v->{'jobtitle'}); }
			if (defined $v->{'fullname'}) { $UREF{'FULLNAME'} = sprintf("%s",$v->{'fullname'}); }
			if (defined $v->{'email'}) { $UREF{'EMAIL'} = sprintf("%s",$v->{'email'}); }
			if (defined $v->{'passpin'}) { $UREF{'PASSPIN'} = sprintf("%s",$v->{'passpin'}); }

			if (defined $v->{'@roles'}) {	
				$UREF{'ROLES'} = ';'.sprintf("%s",join(";",@{$v->{'@roles'}})).';';
				}
			$UREF{'IS_ADMIN'} = 'N';
			if ($UREF{'ROLES'} =~ /;(SUPER|BOSS|AD1);/) { $UREF{'IS_ADMIN'} = 'Y'; }

			if ($v->{'_cmd'} eq 'bossUserCreate') {
				$self->accesslog('SETUP.USERMGR',"ACTION: CREATE SUB-USER: $LOGIN",'INFO');
				my $pstmt = &DBINFO::insert($udbh,'LUSERS',\%UREF,'verb'=>'insert','sql'=>1);
				print STDERR "$pstmt\n";
				$udbh->do($pstmt);
				}
			if ($v->{'_cmd'} eq 'bossUserUpdate') {
				$self->accesslog('SETUP.USERMGR',"ACTION: UPDATE SUB-USER: $LOGIN",'INFO');
				delete $UREF{'LUSER'};
				my $pstmt = &DBINFO::insert($udbh,'LUSERS',\%UREF,'verb'=>'update',key=>{'MID'=>$self->mid(),'LUSER'=>$LOGIN},'sql'=>1);
				print STDERR "$pstmt\n";
				$udbh->do($pstmt);
				}
	
			&JSONAPI::append_msg_to_response(\%R,'success',0);		
			}
		}
	elsif (($v->{'_cmd'} eq 'bossUserList') || ($v->{'_cmd'} eq 'bossUserDetail')) {
		my ($MID) = $self->mid();
		my $pstmt = '';
		if ($v->{'_cmd'} eq 'bossUserList') {
			$pstmt = "select UID,LUSER,FULLNAME,EMAIL,PASSPIN,JOBTITLE,PHONE,CREATED_GMT,PASSWORD_CHANGED,ROLES from LUSERS where MID=$MID order by LUSER";
			}
		if ($v->{'_cmd'} eq 'bossUserDetail') {
			my $LOGIN = lc($v->{'login'});
			if ($LOGIN eq '') {
				&JSONAPI::set_error(\%R,'apperr',23094,'login parameter was not received');
				}
			$pstmt = "select * from LUSERS where MID=$MID and LUSER=".$udbh->quote($LOGIN);
			}
		print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		my @ROWS = ();
		# push @ROWS, { UID=>0, LUSER=>'BOSS', FULLNAME=>'Administrator', JOBTITLE=>'Master Account', HAS_EMAIL=>(($FLAGS =~ /,ZM,/)?'Y':'N') };
		while ( my $rowref = $sth->fetchrow_hashref() ) {
			my %user = ();
			#delete $rowref->{'PASSWORD'};
			$user{'@roles'} = [ split(/\;/,$rowref->{'ROLES'}) ];
			delete $rowref->{'ROLES'};
			$user{'password_changed_gmt'} = &ZTOOLKIT::mysql_to_unixtime($rowref->{'PASSWORD_CHANGED'});
			delete $rowref->{'PASSWORD_CHANGED'};
			foreach my $k (keys %{$rowref}) { $user{lc($k)} = $rowref->{$k}; } # lower case all fields
			push @ROWS, \%user; 
			}
		$sth->finish();
		if ($v->{'_cmd'} eq 'bossUserList') {
			$R{'@USERS'} = \@ROWS;
			}
		if ($v->{'_cmd'} eq 'bossUserDetail') {
			if (scalar(@ROWS)==1) {
				%R = %{$ROWS[0]};
				}
			else {
				&JSONAPI::set_error(\%R,'youerr',23095,'Could not lookup requested user');
				}
			}

		}	
	elsif ($v->{'_cmd'} eq 'bossUserDelete') {
		
		my $LOGIN = lc($v->{'login'});
		my $MID = $self->mid();
		my $pstmt = "select count(*) from LUSERS where MID=$MID and LUSER=".$udbh->quote($LOGIN);
		print STDERR "$pstmt\n";
		my ($exists) = $udbh->selectrow_array($pstmt);

		if (not &JSONAPI::validate_required_parameter(\%R,$v,'login')) {
			}
		elsif ($v->{'login'} eq 'admin') {
			&JSONAPI::set_error(\%R,'youerr',23095,'Cannot remove the admin user');
			}
		elsif ($exists) {
			my $pstmt = "delete from LUSERS where MID=$MID and LUSER=".$udbh->quote($LOGIN);
			print STDERR "$pstmt\n";
			$udbh->do($pstmt);
			}		
		else {
			&JSONAPI::set_error(\%R,'apperr',23093,'User does not exist');
			}
		}
	&DBINFO::db_user_close();

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}

	return(\%R);
	}



=pod

<API id="bossRoleCreate">
<purpose></purpose>
<input id="tag"></input>
</API>

<API id="bossRoleList">
<purpose></purpose>
<input id="tag"></input>
</API>

<API id="bossRoleUpdate">
<purpose></purpose>
<input id="tag"></input>
</API>

<API id="bossRoleDelete">
<purpose></purpose>
<input id="tag"></input>
</API>

=cut

sub bossRole {
	my ($self,$v) = @_;

	my %R = ();	
	my ($LU) = $self->LU();

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	if ($v->{'_cmd'} eq 'bossRoleCreate') {
		&JSONAPI::set_error(\%R,'apierr',1234,sprintf("Call name reserved - but not yet implemented"));		
		}	
	elsif ($v->{'_cmd'} eq 'bossRoleList') {
		my $ALLROLES = OAUTH::list_roles($self->username());
		my @ROLES = ();
		foreach my $roleid (sort keys %{$ALLROLES}) {
			push @ROLES, $ALLROLES->{$roleid};
			}
		$R{'@ROLES'} = \@ROLES;
		}
	elsif ($v->{'_cmd'} eq 'bossRoleUpdate') {
		&JSONAPI::set_error(\%R,'apierr',1234,sprintf("Call name reserved - but not yet implemented"));
		}
	elsif ($v->{'_cmd'} eq 'bossRoleDelete') {
		&JSONAPI::set_error(\%R,'apierr',1234,sprintf("Call name reserved - but not yet implemented"));		
		}

	&DBINFO::db_user_close();
	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}

	return(\%R);
	}









=pod

<API id="adminSOGDetail">
<purpose>Returns a list of Store Option Groups (SOGs), see the SOG xml format for more specific information.</purpose>
<input id="id">sog-id</input>
</API>

<API id="adminSOGList">
<purpose></purpose>
</API>

<API id="adminSOGComplete">
<purpose></purpose>
</API>

<API id="adminSOGCreate">
<purpose></purpose>
<input id="%sog">json nested sog structure</input>
</API>

<API id="adminSOGUpdate">
<purpose></purpose>
<input id="%sog">json nested sog structure</input>
</API>

=cut


sub adminSOG {
	my ($self,$v) = @_;

	my %R = ();	

	my $USERNAME = $self->username();
	if ($v->{'_cmd'} eq 'adminSOGList') {
		my $listref = POGS::list_sogs($USERNAME);
		$R{'@SOGS'} = $listref;
		}
	elsif ($v->{'_cmd'} eq 'adminSOGDetail') {
		my $sogref = &POGS::load_sogref($USERNAME,$v->{'id'});
		$R{$v->{'id'}} = $sogref;
		}
	elsif ($v->{'_cmd'} eq 'adminSOGComplete') {
		my $listref = POGS::list_sogs($USERNAME);
		$R{'%SOGS'} = {};
		foreach my $sogid (sort keys %{$listref}) {
			my $sogref = &POGS::load_sogref($USERNAME,$sogid);
			$R{'%SOGS'}->{$sogid} = $sogref;
			}
		$R{'@SOGS'} = $listref;
		}
	elsif ($v->{'_cmd'} eq 'adminSOGDelete') {
		&POGS::kill_sog($USERNAME,$v->{'id'});
		}
	elsif (($v->{'_cmd'} eq 'adminSOGUpdate') || ($v->{'_cmd'} eq 'adminSOGCreate')) {

		if (not defined $v->{'%sog'}) {
			&JSONAPI::set_error(\%R, 'apperr', 74723, 'Missing %sog parameter');
			}
		elsif (ref($v->{'%sog'}) ne 'HASH') {
			&JSONAPI::set_error(\%R, 'apperr', 74724, '%sog parameter appears to be corrupt');
			}
		elsif ($v->{'%sog'}->{'v'} < 2) {
			&JSONAPI::set_error(\%R, 'apperr', 74725, '%sog internal requires version (v) to be 2 or higher');
			}

		my $new = 0;
		if (&JSONAPI::hadError(\%R)) {
			}
		elsif ($v->{'_cmd'} eq 'adminSOGCreate') { 
			$new++;
			if (not defined $v->{'%sog'}->{'id'}) {
				$v->{'%sog'}->{'id'} = &POGS::next_available_sogid($USERNAME);
				}
			}

		if (($v->{'_cmd'} eq 'adminSOGCreate') || ($v->{'_cmd'} eq 'adminSOGUpdate')) {
			my $sog = $v->{'%sog'};
			if ((defined $sog->{'@options'}) && (ref($sog->{'@options'}) eq 'ARRAY')) {
				## check to see if any options in this pog that don't have options.
				my %USED_OPTION_VS = ();
				my @NEED_OPTION_VS = ();
				foreach my $opt (@{$sog->{'@options'}}) {
					if ((defined $opt->{'v'}) && ($opt->{'v'} ne '')) {
						$USED_OPTION_VS{$opt->{'v'}}++;
						}
					else {
						push @NEED_OPTION_VS, $opt; 
						}
					}

				my $i = -1;
				foreach my $opt (@NEED_OPTION_VS) {
					next if ((defined $opt->{'v'}) && (length($opt->{'v'}) == 2));
					my $ATTEMPTVID = undef;
					do {
						last if ($i > 1296);
						$ATTEMPTVID = &POGS::base36( ++$i );
						} while (defined $USED_OPTION_VS{$ATTEMPTVID});
					if ((not defined $USED_OPTION_VS{$ATTEMPTVID}) && ($i<1296)) {
						$opt->{'v'} = $ATTEMPTVID;
						}
					}
				}
			delete $sog->{'autoid'};
			}


		if (&JSONAPI::hadError(\%R)) {
			}
		elsif ($v->{'%sog'}->{'prompt'} eq '') {
			&JSONAPI::set_error(\%R, 'apperr', 74726, '%sog internal prompt is required');
			}
		elsif ((!$new) && ($v->{'%sog'}->{'id'} eq '')) {
			&JSONAPI::set_error(\%R, 'apperr', 74727, '%sog internal id is required');
			}
		elsif ((!$new) && (length($v->{'%sog'}->{'id'})!=2)) {
			&JSONAPI::set_error(\%R, 'apperr', 74728, '%sog internal id must be two characters');
			}
		elsif ($v->{'%sog'}) {
			my $ID = $v->{'%sog'}->{'id'};
			my $NAME = $v->{'%sog'}->{'prompt'};
			$v->{'%sog'}->{'USERNAME'} = $self->username();
			&POGS::store_sog($self->username(),$v->{'%sog'},'new'=>$new);
			$self->accesslog("SETUP.IMPORT.SOG","Uploaded/Saved SOG ID=$ID NAME=$NAME","SAVE");

			$R{'sogid'} = $ID;
			}
		#elsif ($v->{'xml'}) {
		#	my $XML = $v->{'xml'};
		#	($sogref) = @{&POGS::deserialize($XML)};
		#	$sogref->{'debug'} = "XML-IMPORT.".$self->luser().".".time();
		#	}
		## &POGS::store_sog($USERNAME,$sogref);
		}

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}

	return(\%R);
	}














#################################################################################
##
##
##

=pod
<API id="ping">
<purpose></purpose>
<note>Accepts: nothing</note>
<note>Returns: (nothing of importance)</note>
<response id="pong">1</response>
</API>

=cut

sub ping {
	my ($self,$v) = @_;

	my %R = ();
	$R{'pong'} = 1;
	return(\%R);
	}



#################################################################################
##
##
##

=pod

<API id="whoAmI">
<purpose>Utility function that returns who the current session is authenticated as.</purpose>
<response id="cid"> #### (customer [buyer] id)</response>
<response id="email"> user@fromloggedindomain.com</response>

<hint>
If logged in as an admin sessino you'll get fun stuff like USERNAME,MID,RESELLER and more.
</hint>

</API>

=cut

sub whoAmI {
	my ($self,$v) = @_;

	my %R = ();

	my $cartid = $v->{'_cartid'};

	$R{'cid'} = 0;
	if (substr($cartid,0,2) eq '**') {
		require AUTH;
		my $result = AUTH::fast_validate_session($cartid);	
		if (defined $result) {
			foreach my $k (keys %{$result}) {
				$R{$k} = $result->{$k};
				}
			}
		}

	##
	##	in version 201311 we switched from using *CUSTOMER in CART2 to using a customer object linked to the
	##		session .. this causes a bunch of *fun* (not really) issues with vstore, etc.
	##

	if ($self->clientid() eq '1pc') {
		## this is specifically to address an issue with legacy vstore, where the the customer is stored in the cart
		## there can be only one cart in these circumstances and we must have it as _cartid
		if (ref($self->customer()) eq 'CUSTOMER') {
			## we're already cool. 
			}
		elsif (not $v->{'_cartid'}) {
			## no cart id, this will not go well.
			}
		else {
			## alright, no NEW CUSTOMER, so we need to try and lookup old customer. 
			my $CART2 = undef;
			if ((defined $self->{'%CARTS'}) && ($self->{'%CARTS'}->{$v->{'_cartid'}})) {
				$CART2 = $self->{'%CARTS'}->{$v->{'_cartid'}};
				}
			if (not $CART2) {
				$CART2 = CART2->new_persist($self->username(),$self->prt(),$v->{'_cartid'},'is_fresh'=>0,'*SESSION'=>$self); 
				}

			if ((defined $CART2) && (ref($CART2) eq 'CART2')) {
				if ($CART2->in_get('customer/cid')>0) {
					$self->{'#CUSTOMER'} = $CART2->in_get('customer/cid');
					$self->{'*CUSTOMER'} = CUSTOMER->new($self->username(), 'PRT'=>$self->prt(), 'CID'=>$self->{'#CUSTOMER'}, 'INIT'=>0x1);
					}
				}
			}
		}

	if (ref($self->customer()) eq 'CUSTOMER') {
		$R{'cid'} = $self->customer()->cid();
			$R{'email'} = $self->customer()->email();
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'warning',8001,'Sorry, but we have no clue who you are.');		
		}

	return(\%R);
	}




#################################################################################
##
##
##

=pod

<API id="whereAmI">
<purpose></purpose>
<purpose>Utility function that returns the city/state/zip of the IP making the call.</purpose>
<response id="city"></response>
<response id="state"></response>
<response id="zip"></response>
<response id="country"></response>
</API>

=cut

sub whereAmI {
	my ($self,$v) = @_;

	my %R = ();

	my $cartid = $v->{'_cartid'};

	require Geo::IP;
	my $gi = Geo::IP->open("/usr/local/share/GeoIP/GeoLiteCity.dat", Geo::IP::GEOIP_STANDARD());
	
	my $IP = $ENV{'REMOTE_ADDR'};
	if ($IP =~ /^192\.168\./) { $IP = '66.240.244.217'; }	# our external ip

	my $record = $gi->record_by_addr($IP);
	# my $record = undef;

	if (defined $record) {
		$R{'country'} = $record->country_code;
		$R{'city'} = $record->city;
		$R{'zip'} = $record->postal_code;
		$R{'region'} = $record->region;
		$R{'region_name'} = $record->region_name;
		$R{'areacode'} = $record->area_code;
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'apierr',7095,"Failure in Geo::IP lookup on IP:$IP");		
		}
	
	return(\%R);
	}







#################################################################################
##
##
##

=pod

<API id="canIUse">
<purpose>Utility function which checks access to a specific bundle ex: CRM, XSELL</purpose>
<input id="flag"></input>
<response id="allowed">1|0</response>
</API>

=cut

sub canIUse {
	my ($self,$v) = @_;

	my %R = ();

	if (defined $v->{'flag'}) {
		## this will always return a success (for the call), but that won't necessarily indicate that they have access
		$R{'allowed'} = ($self->globalref()->{'cached_flags'} !~ /,$v->{'flag'},/)?1:0;
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'apperr',8801,"Missing required parameter flag=");		
		}

	return(\%R);
	}








#################################################################################
##
##
##

=pod

<API id="time">
<purpose>Utility/Diagnostic Function</purpose>
<response id="unix"> ########</response>
<hint>
Unix is an epoch timestamp (which represents the number of seconds since midnight january 1st, 1970)
</hint>
</API>

=cut

sub utilityTime {
	my ($self,$v) = @_;

	my %R = ();
	my $t = time();
	$R{'unix'} = $t;

	return(\%R);
	}



=pod

<API id="info">
<purpose>Utility Function</purpose>
<response id="time">########</response>
<response id="media-host">########</response>
<response id="api-max-version">########</response>
<response id="api-min-version">########</response>
<response id="api-our-version">########</response>
<hint>
Time is an epoch timestamp (which represents the number of seconds since midnight january 1st, 1970)
</hint>
</API>

=cut


sub platformInfo {
	my ($self,$v) = @_;
	my %R = ();

	$R{'connected-server'} = &ZOOVY::servername();
	$R{'server-time'} = time();
	$R{'media-host'} = &ZOOVY::resolve_media_host($self->username());
	$R{'api-max-version'} = $JSONAPI::VERSION;
	$R{'api-min-version'} = $JSONAPI::VERSION_MINIMUM;
	$R{'api-our-version'} = $self->apiversion();
	$R{'db-version'} = &ZOOVY::myrelease($self->username());
	## $R{'cluster'} = &ZOOVY::resolve_cluster($self->username());
	$R{'mid'} = &ZOOVY::resolve_mid($self->username());
	
	my ($redis) = &ZOOVY::getRedis($self->username(),1);
	$R{'events-queued'} = $redis->llen("EVENTS");

	# $R{'uptime'} = 
	if ($R{'db-version'}==0) { $R{'db-version'} = 'SHARED'; }

	return(\%R);
	}




#################################################################################
##
##
##

=pod

<API id="appCategoryList">
<purpose></purpose>
<note>Accepts no parameters</note>
<input id="root" optional="1">.root.category.path</input>
<response id="@paths">['.','.safe1','.safe2']</response>
</API>

=cut

sub appCategoryList {
	my ($self,$v) = @_;

	my %R = ();

	my $cache = $self->cache();
	if ($self->is_admin()) { $cache = 0; }
	if (defined $v->{'cache'}) { $cache = int($v->{'cache'}); }

	my ($NC) = undef;
	if ($cache) {
		$NC = $self->cached_navcat();
		}
	else {
		$NC = NAVCAT->new($self->username(),'PRT'=>$self->prt(),cache=>$cache);
		}

	my $root = undef;
	if ($v->{'root'} ne '') { 
		$root = $v->{'root'}; 
		}
	else {
		$root = $self->_SITE()->rootcat();
		}

	## 20131003 -- jt requested we alphabetize them	
	my (@paths) = sort $NC->paths($root);
	undef $NC;

	$R{'@paths'} = \@paths;
	if (not defined $v->{'filter'}) {
		}
	elsif ($v->{'filter'} eq 'lists') {
		my @lists = ();
		foreach my $p (@paths) {
			if (substr($p,0,1) eq '$') {
				push @lists, $p
				}
			}
		$R{'@paths'} = \@lists;
		}
	
	return(\%R);
	}








#################################################################################
##
##
##

=pod

<API id="appConfig">
<purpose></purpose>
<note>Accepts no parameters</note>
</API>

=cut

sub appConfig {
	my ($self,$v) = @_;

	## this basically mirrors the config.js file
	my %R = %{$self->configJS()};
	$R{'server'} = &ZOOVY::servername();
	&JSONAPI::append_msg_to_response(\%R,'success',0);		

	return(\%R);
	}




#################################################################################
##
##
##

#sub appCategoryDetail {
#	my ($self,$v) = @_;
#
#	my $cache = $self->cache();
#	if ($self->is_admin()) { $cache = 0; }
#	if (defined $v->{'cache'}) { $cache = int($v->{'cache'}); }
#	# if (substr($v->{'_cartid'},0,2) eq '**') { $cache = 0; }
#
#	my %R = ();
#
#	my ($NC) = undef;
#	if ($cache == 0) {
#		$NC = NAVCAT->new($self->username(),'PRT'=>$self->prt(),cache=>$cache);
#		}
#	else {
#		$NC = $self->cached_navcat();
#		}
#
#	if (not &JSONAPI::validate_required_parameter(\%R,$v,'detail',['fast','more','max'])) {
#		}
#	elsif ($NC->exists($v->{'safe'})) {
#		$R{'exists'} = 1;
#		($R{'pretty'},undef,my $products,$R{'sort'},$R{'%meta'}) = $NC->get($v->{'safe'});
#		my @products = split(/\,/,$products);
#		$R{'@products'} = \@products;
#		}
#	else {
#		$R{'exists'} = 0;
#		&JSONAPI::append_msg_to_response(\%R,'warning',8001,sprintf('Category %s does not exist prt[%d]',$v->{'safe'},$self->prt()));
#		}
#
#	if (not $R{'exists'}) {
#		}
#	elsif ($v->{'detail'} eq 'fast') {
#		## this is cool, nothing else to do.
#		}
#	elsif ($v->{'detail'} eq 'more') {
#		my $children = $NC->fetch_childnodes($v->{'safe'});
#		$R{'subcategoryCount'} = scalar(@{$children});
#		$R{'@subcategories'} = $children;
#		}
#	elsif ($v->{'detail'} eq 'max') {
#		my $children = $NC->fetch_childnodes($v->{'safe'});
#		$R{'subcategoryCount'} = scalar(@{$children});
#		foreach my $subsafe (@{$children}) {
#			my ($pretty,undef,my $products,my $sort,my $metaref) = $NC->get($subsafe);
#			my @products = split(/,/,$products);
#			push @{$R{'@subcategoryDetail'}}, { 'id'=>$subsafe, 'pretty'=>$pretty, '@products'=>\@products };
#			}
#		}
#	else {
#		## never reached!
#		&JSONAPI::set_error(\%R,'apperr','8000',"Invalid detail xxx requested");
#		}
#
#	undef $NC;
#	
#	return(\%R);
#	}








#################################################################################
##
##
##

=pod

<API id="cartDetail">
<purpose>Lists the contents/settings in a cart along with summary values</purpose>
<input id="_cartid"></input>
<input id="create">1/0 - shall we create a cart if the cart requested doesn't exit?</input>
</API>

=cut

sub cartDetail {
	my ($self,$v) = @_;

	my %R = ();

	my $create_if_missing = 0;
	if ($self->apiversion()<201352) { $create_if_missing = 1; }
	if (defined $v->{'create'}) { $create_if_missing = int($v->{'create'}); }

	my $CART2 = undef;
	my $cartid = $v->{'_cartid'};

	if (not &JSONAPI::validate_required_parameter(\%R,$v,'_cartid')) {
		## yeah, umm.. so if you could just pass that, that'd be ummm.. great.
		}
	else {

		$CART2 = $self->cart2($cartid,'create'=>$create_if_missing);
		$R{'*CART2'} = $CART2;

		if (defined $CART2) { 
			$CART2->__SYNC__(); 
			}
		elsif ($self->apiversion() >= 201352) {
			&JSONAPI::set_error(\%R, 'missing', 94839,sprintf("cart '%s' not initialized for cartDetail",$cartid));
			}
		else {
			## this was changed to a missing in 201352
			&JSONAPI::set_error(\%R, 'apperr', 94839,sprintf("cart '%s' not initialized for cartDetail",$cartid));		
			}
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (&JSONAPI::hadMissing(\%R)) {
		}
	else {
		%R = %{$CART2->make_public()->jsonify()};
		}


	return(\%R);
	}



#################################################################################
##
##
##

=pod

<API id="appEventAdd">
<purpose>
User events are the facility for handling a variety of "future" and "near real time" backend operations.
Each event has a name that describes what type of object it is working with ex: CART, ORDER, PRODUCT, CUSTOMER
then a period, and what happened (or should happen in the future) ex: CART.GOTSTUFF, ORDER.CREATED, PRODUCT.CHANGED
custom program code can be associated with a users account to "listen" for specific events and then take action.
</purpose>
<input id="event">CART.REMARKET</input>
<input id="pid" optional="1">product id</input>
<input id="pids" optional="1">multiple product id's (comma separated)</input>
<input id="safe" optional="1">category id</input>
<input id="sku" optional="1">inventory id</input>
<input id="cid" optional="1">customer(buyer) id</input>
<input id="email" optional="1">customer email</input>
<input id="more" optional="1">a user defined field (for custom events)</input>
<note>in addition each event generated will record: sdomain, ip, and cartid</note>
<input id="uuid" optional="1" hint="to create a future event" >a unique identifier (cart id will be used if not specified)</input>
<input id="dispatch_gmt" optional="1" hint="to create a future event"> an epoch timestamp when the future event should dispatch</input>
</API>

=cut

sub appEventAdd {
	my ($self,$v) = @_;

	my %R = ();
	my $cartid = $v->{'_cartid'};
	my $EVENT = $v->{'event'};

	if ($EVENT eq '') {
		&JSONAPI::append_msg_to_response(\%R,'apperr',7201,"event was not specified");
		}
	elsif ($EVENT !~ /^CART\.(REMARKET)$/) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',7202,"event is not valid");
		}

	my %options = ();
	$options{'CARTID'} = $cartid;
	$options{'SDOMAIN'} = $self->sdomain();
	$options{'IP'} = $ENV{'REMOTE_ADDR'};

	foreach my $field ('more') {
		## whitelist optional parameters (these stay lowercase)
		if (defined $v->{$field}) { $options{$field} = $v->{$field}; }
		}
	foreach my $field ('pid','pids','safe','sku','cid','email') {
		## whitelist optional parameters (these are uppercase)
		if (defined $v->{$field}) { $options{uc($field)} = $v->{$field}; }
		}

	my ($EVENTID) = &ZOOVY::add_event($self->username(),$EVENT,%options);
	if ($EVENTID == 0) {
		&JSONAPI::append_msg_to_response(\%R,'apierr',7203,"event could not be created (unknown reason)");
		}
	else {
		$R{'eventid'} = $EVENTID;
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
		
	return(\%R);
	}








#################################################################################
##
##
##

=pod

<API id="appBuyerAuthenticate">
<purpose>Authenticates a buyer against an enabled/supported trust service</purpose>
<input id="auth">facebook|google</input>
<input id="create">0|1</input>
<input hint="auth=facebook" id="token">token</input>
<input hint="auth=google" id="id_token">required for auth=google, only id_token or access_token are required (but both can safely be passed)</input>
<input hint="auth=google" id="access_token">required for auth=google, only id_token or access_token are required (but both can safely be passed)</input>
<output id="CID"></output>
</API>

=cut

sub appBuyerAuthenticate {
	my ($self,$v) = @_;

	my %R = ();
	$R{'verified'} = 0;
	$R{'CID'} = 0;
	$R{'fullname'} = "customer";

	require CUSTOMER;
	my $cfg = undef;

	my ($webdb) = $self->webdb();
	my $WEBDBKEY = sprintf("%%plugin.auth_%s",$v->{'auth'});

	if (not &JSONAPI::validate_required_parameter(\%R,$v,'auth')) {
		}
	elsif (not defined $webdb->{ $WEBDBKEY }) {
		&JSONAPI::set_error(\%R,'apperr',45313,'invalid provider requested, never configured.');
		}
	elsif (ref($webdb->{ $WEBDBKEY }) ne 'HASH') {
		&JSONAPI::set_error(\%R,'iseerr',45314,'requested provider is corrupt.');
		}
	elsif (not $webdb->{ $WEBDBKEY }->{'enable'}) {
		&JSONAPI::set_error(\%R,'apierr',45315,'requested provider is not enabled');
		}
	else {
		$cfg = $webdb->{ $WEBDBKEY };
		}


	#if ($v->{'partner'} eq 'facebook') {
	#	# appid:
	#	# token:
	#	# App ID/API Key
	#	require Facebook::Graph;
	#	my $facebook_application_id = '138949346126479';
	# 	my $facebook_application_secret = 'a98fed29d00b747de42b8d633884487f';
	#	#my $token = '138949346126479|2.AQADrM873bXoD9mM.3600.1316113200.1-1647098833|057kTrkxPHpFLbjyWPLQ8S_ZESU';
	#	#my $token = '138949346126479|2.AQBJrs7uoJ9WCgaW.3600.1316116800.1-1647098833|GGiutsBej5lFHCwjXZK5UI_h_eo';
	#	#my $token = '138949346126479|2.AQD0AzNy4sdRTgQN.3600.1316116800.1-1647098833|schy_bFzB_4wbYA-1BHn32WmEtY';
	#	my $token = $v->{'token'};
	#	my $user = undef;
	#	if ($token eq '') {
	#		&JSONAPI::append_msg_to_response(\%R,'apperr',600,"token is a required parameter for partner:facebook");
	#		}
	#	elsif (not &JSONAPI::hadError(\%R)) {
	#		my $fb = Facebook::Graph->new(
	#			app_id          => $facebook_application_id,
	#			secret          => $facebook_application_secret,
	#			access_token	 => $token,
	#			# postback        => 'https://www.zoovy.com/facebook/',
	#			);
	#		$user = $fb->fetch('me');
	#		}
	#	if ($user->{'verified'}>0) {
	#		$R{'verified'}++;
	#		$R{'id'} = $user->{'id'};
	#		}
	#	else {
	#		&JSONAPI::append_msg_to_response(\%R,'youerr',600,"authentication to facebook failed.");
	#		}
	#	}
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'auth'} eq 'facebook') {
		## https://developers.facebook.com/docs/facebook-login/getting-started-web/
		## http://developers.facebook.com/docs/reference/api/user/
		## http://search.cpan.org/CPAN/authors/id/R/RI/RIZEN/Facebook-Graph-1.0600.tar.gz
		#Sports World Chicago
		#App ID:  640221622672702
		#App Secret:  289a53b309981e3570ecb2e7c7afd62f(reset)
		#This app is in Sandbox Mode(Only visible to Admins, Developers and Testers)

		#	{
		# "authResponse": {
		#  "accessToken": "CAAJGRzZAlnT4BAJZCFf06FqZAzJAPuwxMoMKkTFT8Kz3JrGkhjf7LNZCaqZByB3vuDLQKkf0lMZBDCxdP1fLQnwg2aQFPD0PMkeZB5LVAgq5uHOHKPG16ZA3HsMcDGWDyICAU01SApzMdNZCqQgZAG9GCmZBzGbsZB6ibDPxCSejvM0LugZDZD",
		#  "userID": "1509019142",
		#  "expiresIn": 5786,
		#  "signedRequest": "DQSkZ7KqIKqOw16K43TS3xppYCQgjnMHxGj8OBvjRJU.eyJhbGdvcml0aG0iOiJITUFDLVNIQTI1NiIsImNvZGUiOiJBUUN6TjJJbnZwXzhnNm9TYUJLU1hRY0xhb0c5ZTVOYkxUNy03VGhodzQ5OEt5WWtvdU1mMkhmNDlpUk5EUkQ1N3E1THhLcWQ4eldYeDk3NDEzOFRaQ0NSTHdWamFwQ1JGMl9FTUozYnhCR3h6NTZ4LWlIM01wVDR5OTVuOWtNR2NwZnNBQmxWMC1LWHBLNjNJblNDM3dIQXpSMjRCeTF1cDB0T1JVbnYtdnFqVHNSZFRlTUt3dVotN2lwOGpIZlk2LTl2LVgzS0hPQnl6eUNFNC1MTDJvd3B2MWVLbjl4eTRHTEo3eGpseVdhcDd1am03VFZRUWpEQnpBbjRibmZobi1ZM1djbFM1N2R1bEFSX2JxRktRc2JuOEhWTF9qV0tYRnNyOWNGWnktMXFVbFBGdlcxWVFsSktqTHo1WXhPQ3ZxUSIsImlzc3VlZF9hdCI6MTM3MjM2ODIxNCwidXNlcl9pZCI6IjE1MDkwMTkxNDIifQ"
		# },
		# "status": "connected"
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'token')) {
			&JSONAPI::append_msg_to_response(\%R,"apperr",6000,"email parameter is required for method=unsecure requests");
			}
		elsif ($cfg->{'appid'} eq '') {
			&JSONAPI::append_msg_to_response(\%R,"iseerr",6004,"required appid is not set in configuration");
			}
		else {
			require Facebook::Graph;
			my $fb = Facebook::Graph->new(
				'app_id'          => $cfg->{'appid'},
				'secret'				=> $cfg->{'~appsecret'},
				);

			$fb->access_token($v->{'token'});
			my $user = $fb->fetch('me');
			if ($user->{'email'} ne '') {
				$R{'email'} = $user->{'email'};
				$R{'verified'}++;
				$R{'CID'} = &CUSTOMER::resolve_customer_id($self->username(),$self->prt(),$user->{'email'});
				}
			}
		}
	elsif ($v->{'auth'} eq 'google') {
		## https://developers.google.com/google-apps/sso/saml_reference_implementation
		## https://developers.google.com/+/web/signin/server-side-flow
		## https://developers.google.com/accounts/docs/OAuth2Login

		## THESE PARAMETERS ARE ONLY NEEDED FOR A REDIRECT/AUTH (we don't need them for apps)
		# $vars{'code'} = $v->{'googlesso:code'};
		# $vars{'client_id'} = '464875398878.apps.googleusercontent.com';
		# $vars{'client_secret'} = 'CLg_TBRKBvIu0o7cFwr-tfcl';

		## NOTE: both access_token and id_token work, i think id_token is better.
		## 		long term we *should* be able to validate id_token without doing a callback to google.
		##			by validating the signed JWT
		# $URL = 'https://www.googleapis.com/oauth2/v1/tokeninfo?access_token='.$api->{'access_token'};

		my $URL = 'https://www.googleapis.com/oauth2/v1/tokeninfo?id_token='.$v->{'id_token'};
		my $ua = LWP::UserAgent->new();
		$ua->timeout(5);
		$ua->agent('CommerceRack/'.$JSONAPI::VERSION);
		my $req = new HTTP::Request('GET', $URL);
		my $result  = $ua->request($req);
		my $body = $result->content();

		#my $api = {
		#	'issued_at' => 1372366662,
		#	'audience' => '464875398878.apps.googleusercontent.com',
		#	'issuer' => 'accounts.google.com',
		#	'email_verified' => bless( do{\(my $o = 1)}, 'JSON::XS::Boolean' ),
		#	'issued_to' => '464875398878.apps.googleusercontent.com',
		# 	'email' => 'sportsworldchicago@gmail.com',
		# 	'expires_in' => 2841,
		# 	'user_id' => '111603568822579329477'
		#	};
		my $api = JSON::XS::decode_json($body);
		if ($api->{'email_verified'}) {
			$R{'email'} = $api->{'email'};	
			## https://developers.google.com/+/api/latest/people
			$R{'user_id'} = $api->{'user_id'};
			$R{'verified'}++;
			$R{'CID'} = &CUSTOMER::resolve_customer_id($self->username(),$self->prt(),$api->{'email'});
			}
		}
	elsif ($v->{'auth'} eq 'emailpass') {
		if ($v->{'email'} eq '') {
			&JSONAPI::append_msg_to_response(\%R,"apperr",6000,"email parameter is required for method=unsecure requests");
			}
		elsif ($v->{'password'} eq '') {
			&JSONAPI::append_msg_to_response(\%R,"apperr",6002,"password parameter is required for method=unsecure requests");
			}
		else {
			my ($login,$password) = ($v->{'email'},$v->{'password'});
			my ($customer_id) = &CUSTOMER::authenticate($self->username(), $self->prt(), $login, $password);
			if ($customer_id <= 0) { $customer_id = 0; }	# handles situations where customer is locked CID -100
			## Did we get authenticated
			$R{'CID'} = $customer_id;
			}
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'apperr',601,"not a valid auth provider");
		}



	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (($R{'CID'}==0) && ($R{'verified'}) && ($v->{'create'})) {
		my ($error,$errmsg) = &CUSTOMER::new_subscriber($self->username(),$self->prt(),$R{'email'},$R{'fullname'},$ENV{'REMOTE_ADDR'});		
		if (not $error) {
			($R{'CID'}) = &CUSTOMER::resolve_customer_id($self->username(),$self->prt(),$R{'email'});
			$self->customer( CUSTOMER->new( $self->username(), PRT=>$self->prt(), CID=>$R{'CID'} ) );
			&JSONAPI::append_msg_to_response(\%R,'success',0);				
			}
		else {
			&JSONAPI::append_msg_to_response(\%R,'apperr',602,"create error: $errmsg");
			}
		}
	elsif ($R{'CID'}>0) {
		$self->customer( CUSTOMER->new( $self->username(), PRT=>$self->prt(), CID=>$R{'CID'} ) );
		&JSONAPI::append_msg_to_response(\%R,'success',0);				
		}

	if ($R{'CID'}>0) {
		## tell the app the new schedule.
		$R{'schedule'} = $self->customer()->is_wholesale();
		}

	#elsif ($R{'verified'}) {
	#	&append_msg_to_response(\%R,'success',0);
	#	}
	else {
		&JSONAPI::append_msg_to_response(\%R,'youerr',600,"authentication failed.");
		}

	return(\%R);
	}




#################################################################################
##
##
##

=pod

<API id="appCartCreate">
<purpose></purpose>
<input id="_cartid"></input>
<input id="cartDetail"></input>
<hint>
You should take care to maintain your cart in a local persisent cookie.  
This is *your* responsibility to pass this value on subsequent requests. (use appCartExists to test to see if it's valid)
</hint>
</API>

=cut

sub appCartCreate {
	my ($self,$v) = @_;

	my %R = ();
	my $cartid = undef;
	my $CART2 = undef;

	$cartid = sprintf("%s",$v->{'_cartid'});
	$CART2 = $self->cart2($cartid);

	## they want a new cart (we'll give them a persistent one)
	my ($newid) = &CART2::generate_cart_id();
	$CART2 = CART2->new_persist( $self->username(), $self->prt(), $newid, 'cartid'=> $newid, 'create'=>1, '*SESSION'=>$self );
	$v->{'_cartid'} = $newid;		## make sure this $v is using the right cartid

	if (defined $CART2) {
		$CART2->in_set('cart/ip_address',$self->ipaddress());		## this will create "changes" which is necessary for a save
		$self->linkCART2( $CART2 );
		$R{'_cartid'} = $CART2->cartid();
		$R{'*CART2'} = $CART2;
		$CART2->cart_save('force'=>1);	## we *MUST* have a save here.
		}

	if ($v->{'cartDetail'}) {
		## sometimes its useful to have appCartCreate return cartDetail format
		return($self->cartDetail($v));
		}
	else {
		return(\%R);
		}
	}








#################################################################################
##
##
##

=pod

<API id="appCartExists">
<purpose>This call tells if a cart/session has been previously created/saved. Since release 201314 it is not necessary to use because cart id's can now be created on the fly by an app.</purpose>
<input id="_cartid"></input>
<response id="_cartid"> </response>
<response id="exists"> 1/0</response>
</API>

=cut

sub appCartExists {
	my ($self,$v) = @_;

	my %R = ();

	## NOTE: this call cannot be loaded *WITHOUT* a cart
	my $cartid = $v->{'_cartid'};
	my ($CART2) = $self->cart2($cartid,'create'=>0);
	$R{'exists'} = (defined $CART2)?1:0;
	$R{'valid'} = 1;

	return(\%R);
	}






=pod

<API id="cartItemAppend">
<purpose></purpose>
</API>

=cut

sub cartItemAppend {
	my ($self,$v) = @_;

	my %R = ();

	my $CART2 = undef;
	my $cartid = $v->{'_cartid'};
	my $olddigest = undef;
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'_cartid')) {
		}
	else {
		$CART2 = $self->cart2($cartid);
		if (not defined $CART2) {	
			&JSONAPI::set_error(\%R, 'apperr', 392, "requested cartid is not valid");
			}
		elsif (ref($CART2) ne 'CART2') {
			&JSONAPI::set_error(\%R, 'iseerr', 393, "CART2 object is corrupt.");
			}
		else {
			$olddigest = $CART2->stuff2()->digest();
			}
		}

	my $lm = LISTING::MSGS->new($self->username()); 
	print STDERR Dumper($v);

	#if ($cgiv->{'_trustedparams'}) {
	#	my %trustedparams = ();
	#	## do md5 check here, recompile a list of trusted params
	#	my $webdbref = &ZWEBSITE::fetch_website_dbref($s2->username(),0);
	#	my ($shared_secret) = $webdbref->{'softcart_secret'};

	#	my @VALUES_TO_BE_DIGESTED = ();
	#	foreach my $tryparam (split(/;/,$cgiv->{'_trustedparams'})) {
	#		if ($tryparam eq 'secret') {
	#			push @VALUES_TO_BE_DIGESTED, $shared_secret;
	#			}
	#		else {
	#			push @VALUES_TO_BE_DIGESTED, sprintf("%s",$cgiv->{$tryparam});
	#			$trustedparams{$tryparam} = $cgiv->{$tryparam};
	#			}
	#		}

	#	## SANITY: at this point @VALUES_TO_BE_DIGESTED is fully built
	#	$softcart = 0;
	#	if (defined $cgiv->{'_md5b64'}) {
	#		require Digest::MD5;
	#		my ($md5_base64_digest) = Digest::MD5::md5_base64(join(";",@VALUES_TO_BE_DIGESTED));
	#		if ($md5_base64_digest eq $cgiv->{'_md5b64'}) {
	#			## yay! trust the parameters - this softcart is good. (re-enable the softcart)
	#			$cgiv = \%trustedparams;
	#			$softcart++;
	#			}
	#		else {
	#			$lm->pooshmsg("ERROR|+_md5b64 digest did not match");
	#			}
	#		}
	#	else {
	#		$lm->pooshmsg("ERROR|+_trustedparams must be used with _md5b64 parameter, softcart functionality disabled");
	#		}

	my $variations = undef;
	my $P = undef;
	my	$quantity = $v->{'qty'};
	my ($PID,$CLAIM,$INV_OPS,$NON_OPS,$VIRTUAL) = &PRODUCT::stid_to_pid($v->{'sku'});

	if (&JSONAPI::hadError(\%R)) {
		}	
	elsif (not JSONAPI::validate_required_parameter(\%R,$v,'uuid')) {
		}
	elsif (not JSONAPI::validate_required_parameter(\%R,$v,'sku')) {
		}
	elsif (not JSONAPI::validate_required_parameter(\%R,$v,'qty')) {
		}
	else {
		my $uuid = $v->{'uuid'};
		$uuid =~ s/^[\s]*(.*?)[\s]*$/$1/gso;
		$uuid = uc($uuid);
		$uuid =~ s/[^A-Z0-9\_\-\:\/\*\#]+/_/gs;

		my %options = ();	## hash keyed by groupID, value is optionID |OR| text value

		$variations = undef;
		($P) = PRODUCT->new($self->username(), $PID);

		if (not defined $P) {
			}
		elsif ($P->has_variations('any')) {
			##
			## STAGE1: first parse any options which were passed as part of the $product_id	
			##			  e.g. $PID:1234/ABCD/QFGD  becomes 12=>34,AB=>CD,QF=>GD
			$variations = $v->{'%variations'};
			}
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($quantity == 0) {
		## ignore situations where quantity is zero.
		}
	elsif (defined $P) {
		my %cramparams = ();
		$cramparams{'claim'} = $CLAIM;
		$cramparams{'*P'} = $P;
		$cramparams{'*LM'} = $lm;
		$cramparams{'zero_qty_okay'} = 1;

		if (($self->is_admin()) && (defined $v->{'price'}))  {
			$cramparams{'force_price'} = &SITE::untaint(&ZTOOLKIT::def($v->{'price'}));
			}

		$lm = $CART2->stuff2()->cram( $PID, $quantity, $variations, %cramparams );
		foreach my $msg (@{$lm->msgs()}) {
			my ($msgref,$status) = LISTING::MSGS::msg_to_disposition($msg);

			print STDERR "MSG:".Dumper($msgref,$status);

			my ($errtype,$errid);
			if ($status eq 'ERROR') { $errtype = 'youerr'; $errid = 9001; }
			if ($status eq 'WARN') { $errtype = 'warn'; $errid = 9000; }
			# if ($status eq 'STOP') { $errtype = 'youerr'; $errid = 9003; }
			if ($msgref->{'+'} =~ /is no longer available/) { $errtype = 'youerr'; $errid = 9001; }			# these older style errors don't return error id's.
			if ($msgref->{'+'} =~ /has already been purchased/) { $errtype = 'youerr'; $errid = 9002; }
			if ($errid>0) {
				&JSONAPI::append_msg_to_response(\%R,$errtype,$errid,$msgref->{'+'});
				}
			}
	

		#	my $price = &SITE::untaint(def($cgiv->{'price'.$suffix}));
		#	my $description = &SITE::untaint(def($cgiv->{'desc'.$suffix}));			
		#	my %softitem = ();
		#	$softitem{'taxable'}     = &SITE::untaint(def($cgiv->{'taxable'.$suffix}));
		#   if (uc($softitem{'taxable'}) eq 'NO') { $softitem{'taxable'} = 0; }
		#	elsif (uc($softitem{'taxable'}) eq 'N') { $softitem{'taxable'} = 0; }

		#	$softitem{'base_weight'} = &SITE::untaint(def($cgiv->{'weight'.$suffix}));

		#	## added for stateofnine softcart integration - patti - 20111011, ticket 468088
		#	$softitem{'%attribs'} = {};
		#	$softitem{'%attribs'}->{'zoovy:prod_supplierid'}     = &SITE::untaint(def($cgiv->{'prod_supplierid'.$suffix}));
		#	$softitem{'%attribs'}->{'zoovy:prod_supplier'} = &SITE::untaint(def($cgiv->{'prod_supplier'.$suffix}));
		#	$softitem{'%attribs'}->{'zoovy:virtual'} = &SITE::untaint(def($cgiv->{'virtual'.$suffix}));
			
		#	$softitem{'is_softcart'} = 1;

		#	if (def($cgiv->{'notes'.$suffix})) {
		#		$softitem{'notes'}        = &SITE::untaint(def($cgiv->{'notes'.$suffix}));
		#		$softitem{'notes_prompt'} = &SITE::untaint(def($cgiv->{'notes_prompt'.$suffix}));
		#		}

		#	$lm->pooshmsg("SUCCESS|+Added $stid quantity $quantity to cart");
		}
	else {
		my ($stid) = $v->{'stid'};
		my ($price) = $v->{'price'};
		my ($description) = $v->{'description'};
		my %params = ();

		my ($item) = $CART2->stuff2()->basic_cram( $stid, $quantity, $price, $description, %params);
		# $lm->pooshmsg("STOP|+Product $stid is no longer available for purchase / does not exist.");
		}

	# $CART2->stuff2()->drop( 'stid'=>$item->{'stid'} );
	if (not &hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);				
		}
#	my $nowdigest = $CART2->stuff2()->digest();
#	if ($olddigest ne $nowdigest) {
#		## yay! something (stid+qty) changed 
#		}
#	elsif ($i==0) {
#		## $i keeps track of how many items were successfully parsed
#		&JSONAPI::append_msg_to_response(\%R,'warning',10000,'No items added/removed from cart');
#		}
#	else {
#		## we never get here unless the cart geometry was not modified.
#		&JSONAPI::append_msg_to_response(\%R,'warning',10001,'All items were already in cart.');
#		}

	return(\%R);
	}





#################################################################################
##
##

=pod

<API id="cartItemUpdate">
<purpose></purpose>
<input id="_cartid"></input>
<input id="stid">xyz</input>
<input id="uuid">xyz</input>
<input id="quantity">1</input>
<input id="_msgs">(contains a count of the number of messages)</input>
<errors>
<err id="9101" type="cfgerr">Item cannot be added to cart due to price not set.</err>
<err id="9102" type="cfgerr">could not lookup pogs</err>
<err id="9103" type="cfgerr">Some of the items in this kit are not available for purchase: </err>
<err id="9000" type="cfgerr">Unhandled item detection error</err>
<err id="9001" type="cfgerr">Product xyz is no longer available</err>
<err id="9002" type="cfgerr">Product xyz has already been purchased</err>
</errors>

</API>

=cut

sub cartItemUpdate {
	my ($self,$v) = @_;

	my $cartid = $v->{'_cartid'};
	
	push @JSONAPI::TRACE, [ 'cartItemUpdate-v', $v ];

	require STUFF::CGI;
	# print STDERR 'UPDATE CART: '.Dumper($CART2);

	my %R = ();	
	
	my $item = undef;
	my $CART2 = undef;

	if (not &JSONAPI::validate_required_parameter(\%R,$v,'_cartid')) {
		}
	else {
		$CART2 = $self->cart2( $cartid );
		}

	my $stuff2 = undef;
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (not defined $CART2) { 
		&JSONAPI::set_error(\%R,'apperr',9009,"CART no longer valid.");
		}
	else {
		$stuff2 = $CART2->stuff2(); 
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (($v->{'stid'} eq '') && ($v->{'uuid'} eq '')) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9000,"passed stid/uuid was blank");
		}
	elsif (not defined $v->{'quantity'}) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9002,"passed quantity was blank");
		}
	elsif ($v->{'uuid'}) {
		## we can only update what we have in the cart already.
		$item = $stuff2->item('uuid'=>$v->{'uuid'});

		if (not defined $item) {
			&JSONAPI::append_msg_to_response(\%R,'youerr',9001,"item uuid:$v->{'uuid'} is no longer available");
			}
		}
	elsif ($v->{'stid'}) {
		## we can only update what we have in the cart already.
		$item = $stuff2->item('stid'=>$v->{'stid'});

		if (not defined $item) {
			&JSONAPI::append_msg_to_response(\%R,'youerr',9001,"item $v->{'stid'} is no longer available");
			}
		}
	else {
		## NOTE: this line should never be reached because it's also checked implicitly above
		&JSONAPI::append_msg_to_response(\%R,'apperr',9003,"invalid item selector specified by app use stid|uuid");
		}

	if (&JSONAPI::hadError(\%R)) {
		## shit happened.
		}
	elsif ($v->{'quantity'}<=0) {
		$stuff2->drop('stid'=>$v->{'stid'});
		}
	elsif ($item->{'qty'} == int($v->{'quantity'})) {
		&JSONAPI::append_msg_to_response(\%R,'warn',9050,"Quantity did not change");
		}
	elsif ($v->{'quantity'}>0) {
		my $lm = LISTING::MSGS->new();
		$stuff2->update_item_quantity('stid',$v->{'stid'},int($v->{'quantity'}),'*LM'=>$lm);
		# $item->{'extended'} = sprintf('%.2f', ($item->{'qty'} * $item->{'price'}));
		if (not $lm->can_proceed()) {
			## NOTE: really need to use update_quantities here, but can't it needs to some love to return valid
			##			well structured responses. it's unsuitable as-is
			foreach my $msg (@{$lm->msgs()}) {
				my ($errtype,$errid) = ('apperr',0);
				my ($msgref,$status) = LISTING::MSGS::msg_to_disposition($msg);
				if ($status eq 'ERROR') { $errtype = 'youerr'; $errid = 9051; }
				elsif ($status eq 'STOP') { $errtype = 'youerr'; $errid = 9052; }
				else { $errtype = 'iseerr'; $errid = 9053; }
				&JSONAPI::append_msg_to_response(\%R,$errtype,$errid,$msgref->{'+'});
				}				
			}
		$R{'qty'} = $item->{'qty'};
		}

	if (not &JSONAPI::hadError(\%R)) {
		##
		## note: eventually we'll need to pipeline these (inspect the queue to see if the next call is cartItemUpdate)
		##			and NOT run these commands:
		##
		# $CART2->shipping();
		&JSONAPI::append_msg_to_response(\%R,'success',0);	
		}

	return(\%R);
	}




#################################################################################
##
##
##

=pod

<API id="appProductList">
<purpose>deprecated</purpose>
<concept>PRODUCT,PRODUCT_SELECTOR</concept>
<input id="src">navcat:.path.to.safename</input>
<input id="src">search:keywords</input>
<input id="src">cart:</input>
<response id="@products">['pid1','pid2','pid3']</response>
</API>

<API id="appProductSelect">
<purpose></purpose>
<input id="product_selector">
navcat=.path.to.safename
CSV=pid1,pid2,pid3
CREATED=STARTYYYMMDD|ENDYYYMMDD
RANGE=pid1|pid2
MANAGECAT=/managecat
SEARCH=keyword
PROFILE=PROFILE
</input>
<response id="@products">['pid1','pid2','pid3']</response>
</API>


=cut

sub appProduct {
	my ($self,$v) = @_;

	my $cache = $self->cache();
	if ($self->is_admin()) { $cache = 0; }
	if (defined $v->{'cache'}) { $cache = int($v->{'cache'}); }

	my %R = ();
	my @products = ();

	if ($v->{'_cmd'} eq 'appProductSelect') {
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'product_selectors')) {
			}
		else {
			require PRODUCT::BATCH;
			my @SELECTORS = ();
			foreach my $line (split(/[\n\r]+/,$v->{'product_selectors'})) { push @SELECTORS, $line; }
			@products = PRODUCT::BATCH::resolveProductSelector($self->username(),$self->prt(),\@SELECTORS);
			}
		}
	elsif ($self->apiversion()>201330) {
		## 8/24/13 -- JT is pretty sure this isn't in use.
		&JSONAPI::append_msg_to_response(\%R,'apperr',9999,"API call appProductsList not available in api > 201330");
		}
	elsif ($v->{'_cmd'} eq 'appProductList') {

		my ($src) = $v->{'src'};

		my @DEBUG = ();
		my $productsref = {};
		if ($src =~ /navcat:(.*?)$/) {	
			## .path.to.category
			## $some_list
			my $othercat = $1;
	
			# my ($pretty, $children, $productstr) = &NAVCAT::fetch_info($USERNAME, $othercat);
			my ($NC) = undef;
			if ($cache) {
				($NC) = $self->cached_navcat();
				}
			else {
				($NC) = NAVCAT->new($self->username(),'PRT'=>$self->prt(),cache=>$cache);
				}
			my (undef,undef,$productstr) = $NC->get($othercat);
			undef $NC;

			if (scalar(@DEBUG)) { push @DEBUG, "Using products from category: $othercat\nproducts: $productstr\n"; }
	
			if (substr($productstr,0,1) eq ',') { $productstr = substr($productstr,1); }	# strip leading ,
			if (substr($productstr,-1) eq ',') { $productstr = substr($productstr,0,-1); }	# strip trailing ,		
			if (not defined $productstr) { $productstr = ''; }
			@products = split (/\,/, $productstr);
			}
		elsif ($src =~ /search:(.*?)$/) {
			## search:catalog?keywords=xyz
			## search:?keywords	 (will use default catalog)
			my $NC = undef;
			if ($cache) {
				($NC) = $self->cached_navcat();
				}
			else {
				($NC) = NAVCAT->new($self->username(),'PRT'=>$self->prt(),cache=>$cache);
				}
			my $catalog = '';
			my $params = {};
	
			(my $resultref) = &SEARCH::search($self->_SITE(),
				MODE=>$params->{'mode'},
				KEYWORDS=>$params->{'keywords'},
				PRT=>$self->prt(),
				# i think this is what that asshole JT wants:
		 		ROOT=>$params->{'root'},
				CATALOG=>$catalog,
				'*NC'=>$NC,
				'debug'=>$params->{'debug'});
			@products = @{$resultref};		
			}
		#elsif ($src =~ /product:pid<owner:tag>/$/) {
		#	## product:pid<owner:tag>
		#	}
		elsif ($src =~ /cart:/) {
			@products = ();
			&JSONAPI::append_msg_to_response(\%R,'apperr',9999,"API call appProductsList not available in api > 201310");
			}
		#elsif ($src =~ /csv:(.*?)/) {
		#	}
		#elsif ($src =~ /rss:(.*?)/) {
		#	}
		}
	
	$R{'@products'} = \@products;
	return(\%R);
	}



#################################################################################
##
##
##

=pod

<API id="getKeywordAutoComplete">
<purpose>returns a list of matching possible keywords (note: currently disabled pending rewrite)</purpose>
<input id="_cartid"></input>
<input id="keywords"></input>
<input id="catalog"></input>
<hint>
pass value of catalog=TESTING to always generate an auto-complete result
</hint>

</API>

=cut

# dictionary
sub getKeywordAutoComplete {
	my ($self,$v) = @_;

	my %R = ();
	my $keywords = $v->{'keywords'};
	my @AR = ();
	if (($v->{'catalog'} eq '') || ($v->{'catalog'} eq 'TESTING')) {
		@AR = ('keywords:'.$keywords,'catalog:'.$v->{'catalog'},'Test Result 1', 'Test Result 2', 'Test Result 3', 'If you are', 'seeing this, you', 'probably did not', 'specify a', 'search catalog', 'Test Result 9', 'Test Result 10');
		}
	else {
#		require SEARCH::DICTIONARY;
#		@AR = SEARCH::DICTIONARY::dictionary_match($self->username(),$v->{'catalog'},$keywords);
		@AR = ();
		}

	$R{'@result'} = \@AR;
	
	return(\%R);
	}











#################################################################################
##
##
##

=pod

<API id="searchResult">
<purpose></purpose>
<input id="_cartid"></input>
<input hint="Required" id="KEYWORDS"></input>
<input hint="Recommended" id="MODE">EXACT|STRUCTURED|AND|OR</input>
<input hint="Recommended" id="CATALOG"></input>
<input hint="Override" id="PRT">0</input>
<input hint="Override" id="ISOLATION_LEVEL">0-9</input>
<input hint="Override" id="ROOT">.</input>
<input hint="Diagnostic" id="LOG">1</input>
<input hint="Diagostic" id="TRACEPID">productid</input>
<response id="@products">an array of product ids</response>
<response id="@LOG">an array of strings explaining how the search was performed (if LOG=1 or TRACEPID non-blank)</response>
<caution>
Using LOG=1 or TRACEPID in a product (non debug) environment will result in the search feature being
disabled on a site.
</caution>

</API>

=cut

sub searchResult {
	my ($self,$v) = @_;

	my %R = ();
	my ($src) = $v->{'src'};

	# print STDERR Dumper($v);

	require SEARCH;
	my ($pids,$prodsref,$logref) = SEARCH::search($self->_SITE(),%{$v});
	$R{'@products'} = $pids;
	$R{'_v'} = $v;
	if (($v->{'LOG'}) || 
		((defined $v->{'TRACEPID'}) && ($v->{'TRACEPID'} ne ''))
		) {
		$R{'@tracelog'} = $logref;
		}
	return(\%R);
	}



#################################################################################
##
##
##

=pod

<API id="getSearchCatalogs">
<purpose></purpose>
<input id="_cartid"></input>
</API>

=cut


sub getSearchCatalogs {
	my ($self,$v) = @_;

	my %R = ();
	require SEARCH;
	my $catref = SEARCH::list_catalogs($self->username());
	my @catalogs = ();
	foreach my $ref (values %{$catref}) {
		delete $ref->{'ID'};
		push @catalogs, $ref;
		}
	$R{'@catalogs'} = \@catalogs;
	return(\%R);
	}






#################################################################################
##
##
##

=pod

<API id="appPublicSearch">
<purpose></purpose>
<input id="_cartid"></input>
<input id="type">product|faq|blog</input>
<input id="type">['product','blog']</input>
<note>if not specified then: type:_all is assumed.</note>
<note>www.elasticsearch.org/guide/reference/query-dsl/</note>

<input id="mode">elastic-search,elastic-count,elastic-msearch,
elastic-mlt,elastic-suggest,elastic-explain,elastic-scroll,elastic-scroll-helper,elastic-scroll-clear</input>
<hint>
elastic-search: a query or filter search, this is probably what you want.
elastic-count: same parameters as query or search, but simply returns a count of matches
elastic-msearch: a method for passing multiple pipelined search requests (ex: multiple counts) in one call
elastic-mlt: "More Like This" uses field/terms to find other documents (ex: products) which are similar
elastic-suggest: used to run did-you-mean or search-as-you-type suggestion requests, 
	which can also be run as part of a "search()" request.
	## http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/search-suggesters-completion.html
elastic-explain: explains why the specified document did or did not match a query, and how the relevance score was calculated. 
elastic-scroll,elastic-scroll-helper,elastic-scroll-clear: used to interate through scroll results using a scroll_id


http://search.cpan.org/~drtech/Search-Elasticsearch-1.10/lib/Search/Elasticsearch/Client/Direct.pm
</a>
<input hint="mode:elastic-*" id="filter"> { 'term':{ 'profile':'DEFAULT' } };</input>
<input hint="mode:elastic-*" id="filter"> { 'term':{ 'profile':['DEFAULT','OTHER'] } };	## invalid: a profile can only be one value and this would fail</input>
<input hint="mode:elastic-*" id="filter"> { 'or':{ 'filters':[ {'term':{'profile':'DEFAULT'}},{'term':{'profile':'OTHER'}}  ] } };</input>
<input hint="mode:elastic-*" id="filter"> { 'constant_score'=>{ 'filter':{'numeric_range':{'base_price':{"gte":"100","lt":"200"}}}};</input>
<input hint="mode:elastic-*" id="query"> {'text':{ 'profile':'DEFAULT' } };</input>
<input hint="mode:elastic-*" id="query"> {'text':{ 'profile':['DEFAULT','OTHER'] } }; ## this would succeed, </input>

<input hint="mode:elastic-mlt" id="id">the document id you want to use for the mlt operation</input>
<input hint="mode:elastic-mlt" id="more_like_this">
"more_like_this" : {
        "fields" : ["name.first", "name.last"],
        "like_text" : "text like this one",
        "min_term_freq" : 1,
        "max_query_terms" : 12
    }
http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-mlt-query.html
</input>

<response id="size">100 # number of results</response>
<response id="sort">['_score','base_price','prod_name']</response>
<response id="from">100	# start from result # 100</response>
<response id="scroll">30s,1m,5m</response>

<note>
<![CDATA[
Filter is an exact match, whereas query is a token/substring match - filter is MUCH faster and should be used
when the exact value is known (ex: tags, profiles, upc, etc.)

<ul> KNOWN KEYS:
* pid
* skus: [ 'PID:ABCD', 'PID:ABCE' ]
* options : [ 'Size: Large', 'Size: Medium', 'Size: Small' ]
* pogs: [ 'AB', 'ABCD', 'ABCE' ]
* tags: [ IS_FRESH, IS_NEEDREVIEW, IS_HASERRORS, IS_CONFIGABLE, IS_COLORFUL, IS_SIZEABLE, IS_OPENBOX, IS_PREORDER, IS_DISCONTINUED, IS_SPECIALORDER, IS_BESTSELLER, IS_SALE, IS_SHIPFREE, IS_NEWARRIVAL, IS_CLEARANCE, IS_REFURB, IS_USER1, ..]
* images: [ 'path/to/image1', 'path/to/image2' ]
* ean, asin, upc, fakeupc, isbn, prod_mfgid
* accessory_products: [ 'PID1', 'PID2', 'PID3' ]
* related_products: [ 'PID1', 'PID2', 'PID3' ]
* base_price: amount*100 (so $1.00 = 100)
* keywords: [ 'word1', 'word2', 'word3' ]
* assembly: [ 'PID1', 'PID2', 'PID3' ],
* prod_condition: [ 'NEW', 'OPEN', 'USED', 'RMFG', 'RFRB', 'BROK', 'CRAP' ]
* prod_name, description, detail
* prod_features
* prod_is
* prod_mfg
* profile
* salesrank
</ul>
]]>
</note>

<response id="@products">an array of product ids</response>
<response id="@LOG">an array of strings explaining how the search was performed (if LOG=1 or TRACEPID non-blank)</response>
<caution>
Using LOG=1 or TRACEPID in a product (non debug) environment will result in the search feature being
disabled on a site.
</caution>

</API>

=cut

sub appPublicSearch {
	my ($self,$v) = @_;

	my %R = ();


	if ($self->apiversion()<201403) {
		if ($v->{'mode'} eq 'elastic-native') { $v->{'mode'} = 'elastic-search'; }
		}


	if ($v->{'mode'} eq 'elastic-searchbuilder') {
		## removed by elasticsearch
		$self->deprecated(\%R,0);
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'mode',['elastic-search','elastic-count','elastic-explain','elastic-msearch','elastic-scroll','elastic-mlt','elastic-suggest','elastic-explain'])) {
		## currently, only elastic-modes are supported
		}
	elsif ($v->{'mode'} =~ /^elastic-(search|count|msearch|mlt|suggest|explain|scroll|scroll-helper|scroll-clear)$/) {

		my ($es) = &ZOOVY::getElasticSearch($self->username());
		if (not defined $es) {
			&JSONAPI::append_msg_to_response(\%R,"iseerr",201,"elasticsearch object is not available");			
			}

		## whitelist parameters
		my %params = ();
		# index           => multi,
		# type            => multi,
		if (defined $v->{'type'}) { $params{'type'} = $v->{'type'}; }
		# $params{'type'} = ['product','sku'];

		## $params{'index'} = sprintf("%s.public",lc($self->username()));
		if (defined $v->{'query'}) { $params{'body'}->{'query'} = $v->{'query'};	}
		if (defined $v->{'filter'}) {	$params{'body'}->{'filter'} = $v->{'filter'};	}

		## size            => $no_of_results
		if (defined $v->{'size'}) {	$params{'size'} = $v->{'size'};	}
		##  sort            => ['_score',$field_1]
		if (defined $v->{'sort'}) {	$params{'body'}->{'sort'} = $v->{'sort'};	}

# 		$v->{'scroll'} = '1m';
		if (defined $v->{'scroll'}) { 	$params{'scroll'} = $v->{'scroll'}; }
		if (defined $v->{'from'}) { 	$params{'from'} = $v->{'from'}; }
		if (defined $v->{'explain'}) { 	$params{'explain'} = $v->{'explain'}; }

		if (defined $params{'body'}) {
			## require body->query or body->filter
			}
		elsif ($v->{'mode'} eq 'elastic-mlt') {
			}
		else {
			&JSONAPI::append_msg_to_response(\%R,"apperr",18233,"search mode:$v->{'mode'} requires either query and/or filter parameter.");
			}

		my $R = undef;
		if (not &hadError(\%R)) {
			## try
			$params{'index'} = sprintf("%s.public",lc($self->username()));
			if ($v->{'mode'} eq 'elastic-count') {
				# mode:elastic-count
				if (defined $params{'body'}->{'filter'}) {
					&JSONAPI::append_msg_to_response(\%R,"apperr",18232,"elastic-count is only compatible with query (not filter)");
					}
				else {
					delete $params{'timeout'}; ## count doesn't allow a timeout
					$params{'ignore'} = [400,404];
					try { 
						$R = $es->count( %params ); 
						} 
					catch { 
						warn "caught error: $_";
						};
					if ($@) { $R = Storable::dclone($@); }
					}

				}
			elsif ($v->{'mode'} eq 'elastic-explain') {
				# mode:elastic-explain
				eval { $R = $es->explain(%params) };
				if ($@) { $R = $@; }
				}
			elsif ($v->{'mode'} eq 'elastic-scroll') {
				# mode:elastic-scroll
				eval { $R = $es->scroll('index'=>sprintf("%s.public",lc($self->username())), %params) };
				if ($@) { $R = $@; }
				}
			elsif ($v->{'mode'} eq 'elastic-scroll-helper') {
				# mode:elastic-scroll
				eval { $R = $es->scroll_helper( %params ) };
				if ($@) { $R = $@; }
				}
			elsif ($v->{'mode'} eq 'elastic-scroll-clear') {
				# mode:elastic-scroll
				eval { $R = $es->scroll_clear( %params ) };
				if ($@) { $R = $@; }
				}
			elsif ($v->{'mode'} eq 'elastic-mlt') {
				# mode:elastic-more-like-this
				if (not JSONAPI::validate_required_parameter(\%R,$v,'id')) {
					}
				else {
					$params{'id'} = $v->{'id'};
					delete $params{'timeout'};
					delete $params{'size'};
					foreach my $k (qw(boost_terms max_doc_freq max_query_terms max_word_length
						min_doc_freq min_term_freq min_word_length mlt_fields percent_terms_to_match routing
						search_from search_indices search_query_hint search_scroll search_size search_source
						search_type search_types stop_words)) {
						if (defined $v->{$k}) { $params{$k} = $v->{$k}; }
						}

					eval { $R = $es->mlt(%params) };
					if ($@) { $R = $@; }
					}
				}
			elsif ($v->{'mode'} eq 'elastic-suggest') {
				# mode:elastic-suggest
				eval { $R = $es->suggest(%params) };
				if ($@) { $R = $@; }
				}
			elsif ($v->{'mode'} eq 'elastic-explain') {
				# mode:elastic-suggest
				eval { $R = $es->explain(%params) };
				if ($@) { $R = $@; }
				}
			elsif ($v->{'mode'} eq 'elastic-msearch') {
				# mode:elastic-count
				eval { $R = $es->count(%params) };
				if ($@) { $R = $@; }
				}
			elsif ($v->{'mode'} eq 'elastic-search') {
				# mode:elastic-search
				$params{'timeout'} = '5s';

				print STDERR 'params: '.Dumper(\%params);

				eval { $R = $es->search(%params) };
				if ($@) { $R = $@; }
				}
			else {
				&JSONAPI::append_msg_to_response(\%R,"iseerr",18201,"search mode:$v->{'mode'} failed with unknown error");
				## &JSONAPI::append_msg_to_response(\%R,"apperr",18234,"unknown mode");
				}

			open F, ">/dev/shm/elastic"; print F Dumper($v,\%params,$R); close F;

		   #if ($R) {
			#	&JSONAPI::append_msg_to_response(\%R,"iseerr",18239,"elastic ise: $@");	
			#	}
			if (&JSONAPI::hadError(\%R)) {
				## no sense going any further.
				}
			elsif (ref($R) eq 'ElasticSearch::Error::Request') {
				my $txt = $R->{'-text'};
				$txt =~ s/\[inet\[.*?\]\]//gs;	## remove: [inet[/192.168.2.35:9300]]
				&JSONAPI::append_msg_to_response(\%R,"apperr",18200,"search mode:$v->{'mode'} failed: ".$R->{'-text'});
			   }
			elsif (ref($@) eq 'ElasticSearch::Error::Missing') {
				&JSONAPI::append_msg_to_response(\%R,"iseerr",18202,sprintf("search mode:$v->{'mode'} %s",$R->{'-text'}));
				$R{'dump'} = Dumper($R);
				}
			elsif (ref($@) eq 'ElasticSearch::Error::Param') {
				&JSONAPI::append_msg_to_response(\%R,"iseerr",18202,sprintf("search mode:$v->{'mode'} %s",$R->{'text'}));
				$R{'dump'} = Dumper($R);
				}
			elsif ($v->{'mode'} eq 'elastic-search') {
				%R = %{$R};
				if ( scalar(keys %R)== 0 ) {
					&JSONAPI::append_msg_to_response(\%R,"iseerr",18235,"empty response from elastic");	
					}
				elsif ( defined $R{'hits'} ) {
					## yay, success!
					$R{'_count'} = scalar(@{$R{'hits'}->{'hits'}});
					}
				}
			else {
				## no special handlers here, although there probably ought to be.
				%R = %{$R};
				}
			}

		}
	else {
		## NOTE: this line should NEVER be reached!
		&JSONAPI::append_msg_to_response(\%R,"iseerr",18234,"search mode, not supported.");
		}

	return(\%R);
	}









#################################################################################
##
##
##

=pod

<API id="appProductGet">
<purpose></purpose>
<input id="_cartid"></input>
<input id="pid">productid</input>
<input id="ver">version#</input>
<input id="withVariations">1</input>
<input id="withInventory">1</input>
<input id="withSchedule">1</input>
<note>NOT IMPLEMENTED: navcatsPlease=1 = showOnlyCategories=1</note>
<example>
[
	'pid' : product-id,
	'%attribs' : [ 'zoovy:prod_name'=>'xyz' ],
	'@variations' : [ JSON POG OBJECT ],
	'@inventory' : [ 'sku1' : [ 'inv':1, 'res':2 ], 'sku2' : [ 'inv':3, 'res':4 ] ],
]
</example>
<caution>
This does not apply schedule pricing.
</caution>
<hint>
to tell if a product exists check the value "zoovy:prod_created_gmt".
It will not exist, or be set to zero if the product has been deleted or does not exist OR is not 
accessible on the current partition.
</hint>
</API>

=cut
sub appProductGet {
	my ($self,$v) = @_;

	my $PID = $v->{'pid'};
	my %R = ();

	my %result = ();
	my ($P) = PRODUCT->new($self->username(),$PID);
	if ((not defined $P) || (ref($P) ne 'PRODUCT')) {
		&JSONAPI::set_error(\%R,"youerr",3000,"The product you requested '$PID' does not exist.");		
		}

	$R{'pid'} = $PID;
	my $SCHEDULE = undef;
	if ($v->{'withSchedule'}==1) {
		my $CART2 = undef;
		if ($v->{'_cartid'} eq '') {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9998,"_cartid parameter is required for $v->{'_cmd'} version > 201310");			
			}
		else {
			$CART2 = $self->cart2( $v->{'_cartid'} );
			}

		if (not defined $CART2) { 
			$CART2 = CART2->new_memory($self->username(),$self->prt(),'cartid'=>$v->{'_cartid'});
			}

		if ($CART2->schedule() ne '') {
			$SCHEDULE = $CART2->schedule();
			}
		$R{'schedule'} = $SCHEDULE;
		}


	if (not &JSONAPI::hadError(\%R)) {
		my $prodref = $P->prodref();
		foreach my $k (keys %{$prodref}) {
			## implement a public filter here.
			next if (substr($k,0,1) eq '%');
			next if (substr($k,0,1) eq '@');
			$result{$k} = &ZTOOLKIT::stripUnicode($prodref->{$k});
			}
	
		## THIS IS USED INCORRECTLY:
		# $R{'%SKU'} = $P->skuref();

		if (not $self->is_admin()) {
			delete $result{'zoovy:base_cost'};
			delete $result{'zoovy:supplier'};		## safe: info disclosure
			## NOTE: at some point we're going to want to summarize %SKU
			}

		if ($v->{'withSKU'}==1) {
			$R{'%SKU'} = $P->list_skus('verify'=>0);
			}

		if ($v->{'withVariations'}==1) {
			if ($self->apiversion()<201324) {
				require TOXML::RENDER;
				# my @pogs = POGS::text_to_struct($self->username(),$prodref->{'zoovy:pogs'},1,1);
				my $pogsref = $P->pogs();
				if (not defined $pogsref) { $pogsref = []; }
				$pogsref = Storable::dclone($pogsref);
				&TOXML::RENDER::pogs2jsonpogs($PID,$pogsref); 	# changes @options to options and adds some cb_ fields..
				$R{'@variations'} = $pogsref;
				}
			#elsif ($self->apiversion()==201324) {
			#	## due to a bug in 201324 where it sometimes required old version, and sometimes wants options
			#	my $pogsref = $P->pogs();
			#	if (not defined $pogsref) { $pogsref = []; }
			#	$pogsref = Storable::dclone($pogsref);
			#	foreach my $pog (@{$pogsref}) {
			#		if (defined $pog->{'@options'}) {
			#			$pog->{'options'} = $pog->{'@options'};
			#			}
			#		}
			#	$R{'@variations'} = $pogsref;				
			#	}
			elsif ($self->apiversion()<201403) {
				## everything since 201324 should just use the native pogs format
				$R{'@variations'} = $P->pogs(); ## <-- this uses cache and does not resolve sogs
				}
			else {
				$R{'@variations'} = $P->fetch_pogs();
				}
			}

		if (defined $SCHEDULE) {
			my $schdata = $P->wholesale_tweak_product($SCHEDULE);
			foreach my $k (keys %{$schdata}) {
				$result{$k} = $schdata->{$k};
				}
			}

		
		if ($v->{'withInventory'}==0) {
			## doesn't want withInventory
			}
		elsif ($self->apiversion() < 201338) {
			## PRE201338
			my $skuref = undef; # $prodref->{'%SKU'};
			if (not defined $skuref) { $skuref = {}; }
	
			my ($INV2) = INVENTORY2->new($self->username());
			my ($inv,$reserve,$loc) = $INV2->fetch_qty('@PIDS'=>[$PID],'%PIDS'=>{$PID=>$P});
			#print STDERR Dumper($inv,$reserve,$loc);
			foreach my $sku (keys %{$inv}) {

				if (defined $prodref->{'%SKU'}->{$sku}) {
					## start by copying any SKU specific fields from %SKU
					$skuref->{$sku} = Storable::dclone($prodref->{'%SKU'}->{$sku});
					delete $skuref->{$sku}->{'zoovy:base_cost'};	# cheap hack (for now)
					}
			
				$skuref->{$sku}->{'inv'} = $inv->{$sku};
				$skuref->{$sku}->{'res'} = $reserve->{$sku};
				}
			$R{'@inventory'} = $skuref;
			}
		else {
			## POST 201338
			my ($INV2) = INVENTORY2->new($self->username());
			my $SUMREF = $INV2->summary('PID'=>$PID);
			$R{'@inventory'} = $SUMREF;
			#foreach my $sku (keys %{$inv}) {
			#	if (defined $prodref->{'%SKU'}->{$sku}) {
			#		## start by copying any SKU specific fields from %SKU
			#		$skuref->{$sku} = Storable::dclone($prodref->{'%SKU'}->{$sku});
			#		delete $skuref->{$sku}->{'zoovy:base_cost'};	# cheap hack (for now)
			#		}
			#
			#	$skuref->{$sku}->{'inv'} = $inv->{$sku};
			#	$skuref->{$sku}->{'res'} = $reserve->{$sku};
			#	}
			#$R{'@inventory'} = $skuref;
			}

		$R{'%attribs'} = \%result;
		}

	return(\%R);
	}


#################################################################################
##
##
##

=pod

<API id="appProductCategories">
<purpose></purpose>
<input id="_cartid"></input>
<input id="pid">productid</input>
<input id="showOnlyCategories">1</input>
<input id="detail">less</input>

<response id="@categories">[ '.safe.path.1', '.safe.path.2' ];</response>

</API>

=cut
sub appProductCategories {
	my ($self,$v) = @_;

	my $cache = $self->cache();
	if ($self->is_admin()) { $cache = 0; }
	if (defined $v->{'cache'}) { $cache = int($v->{'cache'}); }

	my %R = ();
	
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'detail',['less'])) {
		}
	else {
		my ($NC) = undef;
		if ($cache) {
			($NC) = $self->cached_navcat();
			}
		else {
			($NC) = NAVCAT->new($self->username(),'PRT'=>$self->prt(),cache=>$cache);
			}
		
		my $paths = $NC->paths_by_product($v->{'pid'},$v->{'showOnlyCategories'});
		$R{'@categories'} = $paths;
		}

#	my %INIREF = ();
#	$INIREF{'DEPTH'} = $v->{'depth'};
#	if (not defined $INIREF{'DEPTH'}) { $INIREF{'DEPTH'} = 255; }	# max
#	$INIREF{'DELIMITER'} = $v->{'delimiter'};
#	my ($ordered,$named,$metaref) = $NC->build_turbomenu($v->{'safe'},\%INIREF);
#	$R{'subcategoryCount'} = scalar(@{$ordered});
#	$R{'@subcategories'} = $ordered;
#	$R{'%pretty'} = $named;
#	$R{'%meta'} = $metaref;
	return(\%R);
	}



#################################################################################
##
##
##

=pod

<API id="appReviewAdd">
<purpose></purpose>
<input id="_cartid"></input>
<input id="pid">productid</input>
<input id="SUBJECT"></input>
<input id="RATING"></input>
<input id="CUSTOMER_NAME"></input>
<input id="LOCATION"></input>
<input id="SUBJECT"></input>
<input id="MESSAGE"></input>
<input id="BLOG_URL"></input>
</API>

=cut

sub appReviewAdd {
	my ($self,$v) = @_;

	my %R = ();

	#if (not $self->hasFlag(\%R,'CRM')) {
	#	## hasFlag set's it's own error!
	#	}
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'pid')) {
		}
	elsif (not &JSONAPI::hadError(\%R)) {
		delete $v->{'ID'};	# protected
		delete $v->{'APPROVED_GMT'}; # protected
		$v->{'IPADDRESS'} = $self->ipaddress();
		require PRODUCT::REVIEWS;
		my ($ERROR) = PRODUCT::REVIEWS::add_review($self->username(),$v->{'pid'},$v);
		if ($ERROR) {
			&append_msg_to_response(\%R,'err','777',$ERROR);
			}	
		else {
			&append_msg_to_response(\%R,'success',0);
			}
		}

	return(\%R);
	}



#################################################################################
##
##
##

=pod

<API id="appReviewsList">
<purpose></purpose>
<input id="_cartid"></input>
<input id="pid">productid</input>
</API>

=cut

sub appReviewsList {
	my ($self,$v) = @_;

	my %R = ();
	#if (not $self->hasFlag(\%R,'CRM')) {
	#	## this sets it's own errors
	#	}
	if ($v->{'pid'} eq '') {
		&append_msg_to_response(\%R,'err','778',"pid is required");
		}
	
	if (not &JSONAPI::hadError(\%R)) {
		require PRODUCT::REVIEWS;
		my $results = PRODUCT::REVIEWS::fetch_product_reviews($self->username(),$v->{'pid'});
		$R{'@reviews'} = $results;
		&append_msg_to_response(\%R,'success',0);
		}

	return(\%R);
	}




#################################################################################
##
##
##
#
#=pod
#
#<API id="appProfileInfo">
#<purpose></purpose>
#<input id="_cartid"></input>
#<input id="profile"></input>
#<input id="domain"></input>
#<note>Returns: profile data in key value format. </note>
#<errors>
#<err id="10000" type="apperr">Profile %s could not be loaded.</err>
#<err id="10001" type="apperr">Profile request was blank/empty.</err>
#<err id="10002" type="apperr">No profile was requested.</err>
#</errors>
#</API>
#
#=cut
#
sub appProfileInfo {
	my ($self,$v) = @_;

	my %R = ();

	my ($nsref) = undef;

	if (not defined $v->{'domain'}) { $v->{'domain'} = $self->sdomain();	}
	## remove leading period if "profile" was obtained from configJS 'profile' variable (which is .domain)
	if (substr($v->{'domain'},0,1) eq '.') { $v->{'domain'} = substr($v->{'domain'},1); }
	my ($D) = DOMAIN->new($self->username(),$v->{'domain'});
	if (not defined $D) {
		my @PIECES = split(/\./,$v->{'domain'});
		shift @PIECES;	
		$v->{'hostdomain'} = $v->{'domain'};
		$v->{'domain'} = join(".",@PIECES);
		$D = DOMAIN->new( $self->username(), $v->{'domain'} );
		}

	if ((defined $D) && (ref($D) eq 'DOMAIN')) { 
		$nsref = $D->as_legacy_nsref();
		}
	
	if (scalar keys %R) {
		## short circuit if we got an error.
		return(\%R);
		}

	if (not defined $nsref) {
		$nsref = { 'error'=>sprintf("domain %s does not have profile info",$v->{'domain'}) };
		}

	return($nsref);
	}






#################################################################################
##
##
##

=pod

<API id="appCaptchaGet">
<purpose></purpose>
<input id="_cartid"></input>
<errors>
<err id="10000" type="apperr">Profile %s could not be loaded.</err>
<err id="10001" type="apperr">Profile request was blank/empty.</err>
<err id="10002" type="apperr">No profile was requested.</err>
</errors>
<note>***** NOT FINISHED ****</note>
</API>

=cut

sub appCaptchaGet {
	my ($self,$v) = @_;

	my %R = ();

	require PLUGIN::RECAPTCHA;
	

	if (scalar keys %R) {
		## short circuit if we got an error.
		return(\%R);
		}

	return();
	}












#################################################################################
##
##
##

=pod

<API id="buyerNotificationAdd">
<purpose>Used to register a buyer for a notification when a inventory is back in stock.</purpose>
<input id="_cartid"></input>
<input id="type">inventory</input>
<input hint="type:inventory" id="email">user@somedomain.com</input>
<input hint="type:inventory" id="sku"></input>
<input hint="type:inventory" id="msgid"></input>
</API>

=cut
sub buyerNotificationAdd {
	my ($self,$vref) = @_;
	my ($v) = @_;
	my %R = ();

	if (defined $self->customer()) {
		# $v->{'email'} = sprintf("#%d",$self->customer()->cid());
		$v->{'email'} = $self->customer()->email();
		}

	if (not &JSONAPI::validate_required_parameter(\%R,$v,'method',['inventory'])) {
		## validate_required_parameter will append it's own error when the required parameter is missed.
		}
	elsif ($v->{'email'} eq '') {
		&JSONAPI::set_error(\%R,"apperr",6000,"missing parameter - either authentication or email parameter is required for requests");
		}
	elsif ($v->{'method'} eq 'inventory') {
	
		if ($v->{'sku'} eq '') {
			&JSONAPI::set_error(\%R,"apperr",6001,"sku parameter is required for type=inventory requests");
			}
		else {
			my ($error) = &INVENTORY2::UTIL::request_notification( $self->username(), $v->{'sku'}, 
				PRT=>$self->prt(),
				EMAIL=>$v->{'email'}, 
				MSGID=>$v->{'msgid'},
				VARS=>&ZTOOLKIT::buildparams($vref,1));
			if ($error ne '') {
				&JSONAPI::set_error(\%R,"apierr",6002,"$error");
				}
			}
		}
	return(\%R);
	}









#################################################################################
##
##

=pod
<API id="appGiftcardValidate">
<purpose></purpose>
<caution>a single ip is limited to 25 requests in a 24 hour period.</caution>
<input id="giftcard"></input>
</API>

=cut

sub appGiftcardValidate {
	my ($self,$v) = @_;
	my %R = ();

	my $CODE = $v->{'giftcard'};

	require SITE;
	require GIFTCARD;
	my ($attempts) = &SITE::log_email($self->username(),$ENV{'REMOTE_ADDR'});
	#if (not $self->hasFlag(\%R,'CRM')) {
	#	## hasFlag set's it's own error!
	#	}
	if ($attempts>25) {
		&JSONAPI::set_error(\%R,"apierr",6002,"daily email threshold exceeded.");
		}
	elsif ($CODE eq '') {
		&JSONAPI::set_error(\%R,"apperr",109,"giftcard parameter is required.");		
		}
	elsif (&GIFTCARD::checkCode($CODE)) {
		&JSONAPI::set_error(\%R,"youerr",10001,"giftcard checksum code is invalid, please check the number.");
		}
	else {
		my ($GC) = &GIFTCARD::lookup($self->username(),'PRT'=>$self->prt(),'CODE'=>$CODE);
		if (not defined $GC) {
			&JSONAPI::set_error(\%R,"youerr",10002,"giftcard does not exist.");
			}
		else {
			%R = %{$GC};
			&JSONAPI::set_error(\%R,"success",$GC->{'ID'});
			}
		}		

	return(\%R);
	}


#####################################################################################
##
##

=pod
<API id="cartPaymentQ">
<purpose>Manipulate or display the PaymentQ (a list of payment types for a given cart/order)</purpose>
<input id="cmd" required="1">reset|delete|insert|sync</input>
<input id="ID" optional="0">required for cmd=delete|insert</input>
<input id="TN" optional="0">required for cmd=insert ex: CASH|CREDIT|PO|etc.</input>
<input id="$$" optional="0">optional for cmd=insert (max to charge on this payment method)</input>
<input id="TWO_DIGIT_TENDER_VARIABLES" optional="0">required for cmd=insert, example: CC, MM, YY, CV for credit card</input>
<response id="paymentQ[].ID">unique id # for this</response>
<response id="paymentQ[].TN">ex: CASH|CREDIT|ETC.</response>
<response id="paymentQ[].OTHER_TWO_DIGIT_TENDER_VARIABLES"></response>
</API>

=cut

sub cartPaymentQ {
	my ($self, $v) = @_;

	my %R = ();
	my $CART2 = undef;
	my $webdbref = $self->webdb();

	if ($v->{'_cartid'} eq '') {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9998,"_cartid parameter is required for $v->{'_cmd'} version > 201310");			
		}
	else {
		$CART2 = $self->cart2( $v->{'_cartid'} );
		}

	#print STDERR "cartPaymentQ cmd: $v->{'cmd'}\n";
	if (&hadError(\%R)) {
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'cmd',['reset','delete','insert','sync'])) {
		}
	else {
		$self->paymentQCMD(\%R,$v->{'cmd'},$v);
		}

	if (not &JSONAPI::hadError(\%R)) {
		$self->paymentQCMD( \%R, 'sync' );
		$CART2->{'@PAYMENTQ'} = $self->paymentQ();
		}
	# print STDERR "cartPaymentQ Dump: ".Dumper($self->paymentQ())."\n";

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}

	return(\%R);
	}




#####################################################################################
##
##


=pod

<API id="cartGiftcardAdd">
<purpose></purpose>
<input id="_cartid"></input>
<input id="giftcard"></input>
</API>

<API id="cartCouponAdd">
<purpose></purpose>
<input id="_cartid"></input>
<input id="coupon"></input>
</API>

<API id="cartPromoCodeAdd">
<purpose></purpose>
<note>A promo code can be either a giftcard, or a coupon (we'll detect which it is)</note>
<input id="_cartid"></input>
<input id="promocode"></input>
</API>

=cut

sub cartPromoCodeOrGiftcardOrCouponToCartAdd {
	my ($self,$v) = @_;

	## TRACK ATTEMPTS

	my @ERRORS = ();
	my %R = ();	

	my $cartid = $v->{'_cartid'};
	my $CART2 = undef;
	if ($v->{'_cartid'} eq '') {
		push @ERRORS, "9998|apperr|_cartid parameter is required for $v->{'_cmd'} version > 201310";
		&JSONAPI::append_msg_to_response(\%R,'apperr',9998,"_cartid parameter is required for $v->{'_cmd'} version > 201310");			
		}
	else {
		$CART2 = $self->cart2( $v->{'_cartid'} );
		}

	if (defined $v->{'promocode'}) {
		}
	elsif (defined $v->{'coupon'}) {
		}
	elsif (defined $v->{'giftcard'}) {
		}
	else {
		push @ERRORS, "8200|apperr|promocode, giftcard, or coupon parameter was not passed";
		}
	
	if (defined $v->{'promocode'}) {
		if (defined $v->{'coupon'}) {
			push @ERRORS, "8290|apperr|do not pass promocode and coupon together";
			}
		if (defined $v->{'giftcard'}) {
			push @ERRORS, "8290|apperr|do not pass giftcard and coupon together";
			}

		## eventually we'll need code here to determine which one it is.
		## ***NOTE*** this code is highly duplicated in PAGE::cart

		## NOTE: the input length is *intentionally* 10 characters so merchants can use "shared" coupon codes with
		##			other foreign systems, but after 10 characters, they are just being fucking stupid and
		##			we should smack them in the head!
		if (length($v->{'promocode'})<=10) {
			## a promo code of less than 6 digits is a coupon!
			$v->{'coupon'} = substr($v->{'promocode'},0,8);
			}

		my $x = $v->{'promocode'};
		$x =~ s/[\-\t\n\r\s]+//gs;	## users might put in dashes, but we kill 'em.

		if (length($x)==16) {
			require GIFTCARD;
			if (GIFTCARD::checkCode($x)==0) {
				$v->{'giftcard'} = $x;
				}
			}
		}

	## TODO: eventually it'd be nice to check if a coupon was passed ONLY on a cartCouponAdd call
	if (scalar(@ERRORS)>0) {
		## bad stuff has already happened, no sense adding more errors.
		}
	elsif ((defined $v->{'coupon'}) && ($v->{'coupon'} eq '')) {
		push @ERRORS, "8200|apperr|coupon was not passed";
		}
	elsif (defined $v->{'coupon'}) {
		my ($errs) = $CART2->add_coupon($v->{'coupon'},[],undef,'SITE');
		## note: all coupon "add" errors receive a generic 8252
		foreach my $e (@{$errs}) { push @ERRORS, "8252|youerr|$e"; }
		if (scalar(@{$errs})==0) {
			## double check the coupon is actually in the cart
			if (not defined $CART2->{'%coupons'}->{ uc($v->{'coupon'}) }) {
				push @ERRORS, "8205|iseerr|internal logic failure - non-error response from add_coupon, but coupon did not get added.";
				}
			}
		}

	## TODO: eventually it'd be nice to check if a giftcard was passed ONLY on a cartGiftcardAdd call
	if (scalar(@ERRORS)>0) {
		## bad stuff has already happened, no sense adding more errors.
		}
	elsif ((defined $v->{'giftcard'}) && ($v->{'giftcard'} eq '')) {
		push @ERRORS, "8200|apperr|giftcard was not passed";
		}
	elsif (defined $v->{'giftcard'}) {
		require GIFTCARD;
		my $giftcard = uc($v->{'giftcard'});
		# $giftcard =~ s/\[A-Z0-9\]//gs;	# wtf is this shit?  I can't imagine this actually works!
		$giftcard =~ s/[^A-Z0-9]+//gs;
		
		if (my $failure = &GIFTCARD::checkCode($giftcard)) {
			push @ERRORS, "8201|youerr|giftcard checksum was invalid (reason: $failure).";
			}
		else {
			## first thing we need to do is figure out
			## my ($errs) = $CART2->add_giftcard($v->{'giftcard'},[]);
			## note: all giftcards "add" errors receive a generic 8202
			## foreach my $e (@{$errs}) { push @ERRORS, "8202|youerr|$e"; }


			my $code = uc($v->{'giftcard'});
			$code =~ s/[\s\t\n\r\-]+//gs;	# remove bad characters.
			my $err = &GIFTCARD::checkCode($code);
			if ($err>0) { 
				push @ERRORS, "8203|The code you supplied [$code] is not a valid giftcard (reason: $err)";
				}
			elsif ($CART2->has_giftcard($code)) {
				push @ERRORS, "8204|The giftcard $code is already in the cart.";
				}
			else {
				my ($GCREF) = &GIFTCARD::lookup($self->username(),PRT=>$self->prt(),CODE=>$code);
				# my ($newpayq) = &GIFTCARD::giftcard_to_payment($GCREF,'mask'=>0);
				## returns the giftcard in fields suitable for paymentq format

				my %newpayq = ();
				$newpayq{'TN'} = 'GIFTCARD';
				$newpayq{'GC'} = $GCREF->{'CODE'};	# giftcard code (can be masked)
				#if ($options{'obfuscate'}) {
				# $newpayq{'GC'} = &GIFTCARD::obfuscateCode($newpayq{'GC'},$options{'obfuscate'});
				#	}
				$newpayq{'GI'} = $GCREF->{'GCID'}; # giftcard gcid
				$newpayq{'T$'} = $GCREF->{'BALANCE'}; # balance (if known) 
				$newpayq{'GP'} = 'GNN'; 
				$newpayq{'$#'} = $GCREF->{'BALANCE'};	# when they add this way, we always try and use the full balance.

				if ($GCREF->{'CARDTYPE'} > 0) {
					$newpayq{'GP'} = sprintf("X%1s%1s", 
						(($GCREF->{'COMBINABLE'}&2)>0)?'Y':'N',
						(($GCREF->{'CASHEQUIV'}&4)>0)?'Y':'N'
						);
					}
		
				if (not defined $GCREF) {
					push @ERRORS, "8205|Could not find giftcard [$code]";
					}
				elsif ($GCREF->{'GCID'} == 0) {
					push @ERRORS, "8206|Giftcard GCID [$code] not valid for this partition."; # 
					}
				elsif ($newpayq{'T$'}==0) {
					push @ERRORS, "8207|Giftcard has no available balance.";
					}
				elsif ($newpayq{'T$'} < 0) {
					push @ERRORS, "8208|Giftcard has a negative balance -- cannot use.";
					}
				else {
					my ($X0,$X1,$X2) = split(//,$newpayq{'GP'});
					my $HAS_NON_COMBINABLE = (&ZOOVY::is_true($X1))?1:0;
			
					my @NEW_PAYMENTQ = ();
					push @NEW_PAYMENTQ, \%newpayq;		## always add the current card.
					foreach my $payq (@{$self->paymentQ()}) {
						if ($payq->{'TN'} ne 'GIFTCARD') {
							# preserve non-giftcards
							push @NEW_PAYMENTQ, $payq;
							}
						elsif ($payq->{'GI'} eq $newpayq{'GI'}) {
							## attempting to re-add the same card - we can ignore this.
							}
						else {
							## more giftcards.
							my ($X0,$X1,$X2) = split(//,$payq->{'GP'});
							if ($X2 eq 'Y') {	
								## NON_COMBINABLE-- there can only be one!
								if ($HAS_NON_COMBINABLE == 0) {
									$HAS_NON_COMBINABLE++;  
									push @NEW_PAYMENTQ, $payq;
									}
								else {
									push @ERRORS, "820X|The giftcard $payq->{'GC'} is promotional and may not be combined with other promotional giftcards";
									}
								}					
							}
						}

					$self->paymentQ(\@NEW_PAYMENTQ);

					print STDERR "paymentQ: ".Dumper($self->paymentQ())."\n";
					# $self->log(Dumper( $self, $newpayq ));
					}
				push @{$CART2->{'@CHANGES'}}, [ 'add_giftcard' ];
				}

			$CART2->__SYNC__();
			}
		}

	## SANITY: now let's format the resposne

	if (scalar(@ERRORS)>0) {
		foreach my $e (@ERRORS) {
			my ($errcode,$errtype,$errmsg) = split(/\|/,$e,3);
			&JSONAPI::append_msg_to_response(\%R,$errtype,$errcode,$errmsg);
			}
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		$CART2->sync_action('cartPromoCodeOrGiftcardOrCouponToCartAdd');
		}

	return(\%R);
	}





#################################################################################
##
## appEmailSend
##

=pod
<API id="appEmailSend">
<purpose></purpose>
<caution>a single ip is limited to 25 emails in a 24 hour period.</caution>
<input id="_cartid"></input>
<input id="method">tellafriend</input>
<input hint="method:tellafriend" id="product">productid</input>
<input hint="method:tellafriend" id="recipient">user@someotherdomain.com</input>
</API>

=cut

sub appEmailSend {
	my ($self,$v) = @_;
	my %R = ();

	require SITE;
	my ($attempts) = &SITE::log_email($self->username(),$ENV{'REMOTE_ADDR'});
	#if ($ENV{'REMOTE_ADDR'} eq '192.168.99.15') { $attempts = 0; }
	#$attempts = 0;

	#if (not $self->hasFlag(\%R,'XSELL')) {
	#	## hasFlag set's it's own error!
	#	}
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'method',['tellafriend'])) {
		}
	elsif ($attempts>25) {
		&JSONAPI::append_msg_to_response(\%R,"apierr",6002,"daily email threshold exceeded.");
		}
	elsif ($v->{'method'} eq 'tellafriend') {
		#require SITE::EMAILS;
		#my ($se) = SITE::EMAILS->new($self->username(),'*SITE'=>$self->_SITE());
		#my ($ERRORID) = $se->sendmail('PRODUCT.SHARE',
		#	PRODUCT=>$v->{'product'},
		#	TO=>$v->{'recipient'},
		#	VARS=>$v
		#	);
		#if ($ERRORID>0) {
		#	my $ERRMSG = $SITE::EMAILS::ERRORS{$ERRORID};
		#	if ($ERRMSG eq '') { $ERRMSG = "Unknown SITE::EMAILS::ERROR ID=$ERRORID"; }
		#	&JSONAPI::append_msg_to_response(\%R,"apierr",$ERRORID,$ERRMSG);
		#	}
		#else {
		#	&JSONAPI::append_msg_to_response(\%R,"success",0);
		#	}
		my ($P) = PRODUCT->new($self->username(),$v->{'product'});
		my ($BLAST) = BLAST->new($self->username(),$self->prt());
		my ($rcpt) = $BLAST->recipient('EMAIL',$v->{'recipient'},$v);
		my ($msg) = $BLAST->msg('PRODUCT.SHARE',{ '%PRODUCT'=>$P } );
		$BLAST->send($rcpt,$msg);
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,"apierr",6660,"unknown method, or something else went horribly wrong - possibly demonic possession.");
		}
	
	return(\%R);
	}








#################################################################################
##
##
##

=pod

<API id="buyerProductLists">
<purpose></purpose>
<input id="_cartid"></input>
<example>
@lists = [
	[ LISTID:listid1, ITEMS:# ],
	[ LISTID:listid2, ITEMS:# ],
	]
</example>
</API>

<API id="buyerProductListDetail">
<purpose></purpose>
<input id="_cartid"></input>
listid:
<example>
@listid = [
	[ SKU:sku1, QTY:#, NOTE:"", PRIORITY:"", MODIFIED_TS:"YYYY-MM-DD HH:MM:SS" ],
	[ SKU:sku1, QTY:#, NOTE:"", PRIORITY:"", MODIFIED_TS:"YYYY-MM-DD HH:MM:SS" ],
	]
</example>
</API>

<API id="buyerProductListAppendTo">
<purpose></purpose>
<input id="_cartid"></input> 
listid=
sku=
OPTIONAL:
	qty=(will default to zero)
	priority=# (will defualt to zero)
	note=	(optional string up to 255 characters)
	replace=1	(will delete any existing value from the list, and re-add this one)
</API>


<API id="buyerProductListRemoveFrom">
<purpose></purpose>
<input id="_cartid"></input>
listid=
sku=
</API>

=cut

sub buyerProductLists {
	my ($self,$v) = @_;
	my %R = ();
	
	if (not $self->isLoggedIn(\%R,$v)) {
		## handles it's own errors
		}
	else {
		my $listsref = $self->customer()->get_all_lists();
		$R{'@lists'} = $listsref;
		}
	return(\%R);
	}

sub buyerProductListDetail {
	my ($self,$v) = @_;
	my %R = ();
	
	if (not $self->isLoggedIn(\%R,$v)) {
		## handles it's own errors
		}
	else {
		my $listref = $self->customer()->get_list($v->{'listid'});
		$R{sprintf("@%s",$v->{'listid'})} = $listref;
		}
	return(\%R);
	}

sub buyerProductListAppendTo {
	my ($self,$v) = @_;
	my %R = ();
	
	if (not $self->isLoggedIn(\%R,$v)) {
		## handles it's own errors
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'sku')) {
		}
	else {
		my ($ID) = $self->customer()->add_to_list($v->{'listid'},$v->{'sku'},%{$v});
		if ((substr($ID,0,1) eq '0') && (int($ID)>0)) {
			## return 0#### if the result previously existed in the database and was updated.
			$R{'success'} = $ID;
			$R{'existed'} = 1;
			}
		elsif ($ID>0) {
			$R{'success'} = $ID;
			$R{'existed'} = 0;
			}
		else {
			&append_msg_to_response(\%R,'err',776,'Could not insert list into database');
			}
		}
	return(\%R);
	} 

sub buyerProductListRemoveFrom {
	my ($self,$v) = @_;
	my %R = ();
	
	if (not $self->isLoggedIn(\%R,$v)) {
		## handles it's own errors
		}
	else {
		my ($ID) = $self->customer()->remove_from_list($v->{'listid'},$v->{'sku'});
		}
	return(\%R);
	}





#################################################################################
##
##
##

=pod

<API id="buyerAddressList">
<purpose></purpose>
<input id="_cartid"></input>
Returns:
<CODE>
@bill : [
	... format may change ...
	]
@ship : [
	... format may change ...
	]
</CODE>
</API>


<API id="buyerAddressAddUpdate">
<purpose></purpose>
<input id="_cartid"></input>
<notes>
<![CDATA[
shortcut:tag for this address ex: 'HOME' (must be unique within bill or ship)

type:bill
	bill/countrycode:US
	bill/email:user@domain
	bill/firstname:
	bill/lastname:
	bill/fullname:
	bill/phone:
	bill/state:
	bill/zip: 

type:ship    
	ship/address1:
	ship/address2:
	ship/city:
	ship/countrycode:US
	ship/fullname:
	ship/firstname:
	ship/lastname:
	ship/phone:
	ship/region:
	ship/postal:

NOTE: (fullname) or (firstname lastname)
NOTE: (country) or (countrycode) 
]]>
</notes>
</API>

<API id="buyerAddressDelete">
<purpose></purpose>
<concept>buyer</concept>
<input id="_cartid"></input>
Returns:
<CODE>
type:SHIP|BILL
shortcut:DEFAULT
</CODE>
</API>

<API id="buyerDetail">
<purpose></purpose>
<concept>buyer</concept>
</API>

<API id="buyerUpdate">
<purpose></purpose>
<concept>buyer</concept>
<input id="@updates"></input>
Returns:
</API>

=cut


sub buyerInfo {
	my ($self,$v) = @_;
	my %R = ();

	my ($C) = undef;	
	if (not $self->isLoggedIn(\%R,$v)) {
		## handles it's own errors
		}
	else {
		## contractually guaranteed to be set!
		($C) = $self->customer();
		if (ref($C) ne 'CUSTOMER') {
			&JSONAPI::append_msg_to_response(\%R,"iseerr",18349,"customer object was not available or valid.");	
			}
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'_cmd'} eq 'buyerAddressList') {
		$CUSTOMER::ADDRESS::JSON_EXPORT_FORMAT = $self->apiversion();		## used for CUSTOMER::ADDRESS::TO_JSON
		$R{'@bill'} = $self->customer()->fetch_addresses('BILL');
		$R{'@ship'} = $self->customer()->fetch_addresses('SHIP');
		}
	elsif ($v->{'_cmd'} eq 'buyerDetail') {
		$R{'%info'} = $self->customer()->TO_JSON();
		}
	elsif ($v->{'_cmd'} eq 'buyerUpdate') {
		## need to build this.		

		my @CMDS = ();
		if (not defined $v->{'@updates'}) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9002,'Could not find any @updates');
			}
		elsif (ref($v->{'@updates'}) eq 'ARRAY') {
			my $count = 0;
			foreach my $line (@{$v->{'@updates'}}) {
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					$cmdset->[1]->{'luser'} = $self->luser();
					$cmdset->[2] = $line;
					$cmdset->[3] = $count++;
					push @CMDS, $cmdset;
					}
				}
			}
		$C->run_macro_cmds(\@CMDS,'is_buyer'=>1,'%R'=>\%R);

		}
	elsif ($v->{'_cmd'} eq 'buyerAddressDelete') {

		$v->{'type'} = uc($v->{'type'});
		my $SHORTCUT = uc((defined $v->{'shortcut'})?$v->{'shortcut'}:'');
		$SHORTCUT =~ s/[^A-Z0-9]//gs;

		if (not &validate_required_parameter(\%R,$v,'type',['BILL','SHIP'])) {
			}
		elsif ($v->{'_cmd'} ne 'buyerAddressDelete') {	
			}
		elsif ($SHORTCUT eq '') {
			&JSONAPI::append_msg_to_response(\%R,"apperr",18348,"shortcut is required to delete an address.");	
			}
		else {
			my $TYPE = uc($v->{'type'});
			$C->nuke_addr($TYPE,$SHORTCUT);
			&JSONAPI::append_msg_to_response(\%R,"success",0,"address shortcut $SHORTCUT deleted");	
			}	

		}
	elsif ($v->{'_cmd'} eq 'buyerAddressAddUpdate') {
		require CUSTOMER::ADDRESS;
		my %addr = ();
		$v->{'type'} = uc($v->{'type'});

		if (not &validate_required_parameter(\%R,$v,'type',['BILL','SHIP'])) {
			}
		elsif ($v->{'type'} eq 'BILL') {
			foreach my $k (keys %{$v}) {
				my $field = $k;
				my $prefix = 'bill/';	## either bill/ (current) or bill_ (legacy)
				if ($field =~ /^bill\/(.*?)$/) { $prefix = 'bill/'; $field = $1; }
				if ($self->apiversion()<201338) {
					if ($field =~ /^bill_(.*?)$/) { $prefix = 'bill_'; $field = $1; }
					}
  	       if ($CUSTOMER::ADDRESS::VALID_FIELDS{ $field }) {
					$addr{"$field"} = $v->{$k};
					}
				}
			}
		elsif ($v->{'type'} eq 'SHIP') {
			foreach my $k (keys %{$v}) {
				my $field = $k;
				my $prefix = 'ship/';
				if ($field =~ /^ship\/(.*?)$/) { $prefix = 'ship/'; $field = $1; }
				if ($self->apiversion()<201338) {
					if ($field =~ /^ship_(.*?)$/) { $prefix = 'ship_'; $field = $1; }
					}
  	       if ($CUSTOMER::ADDRESS::VALID_FIELDS{ $field }) {
					$addr{"$field"} = $v->{$k};
					}
				}
			}

		my $SHORTCUT = uc((defined $v->{'shortcut'})?$v->{'shortcut'}:'DEFAULT');
		if ($SHORTCUT eq '') { $SHORTCUT = 'DEFAULT'; }
		$SHORTCUT =~ s/[^A-Z0-9]//gs;
	
		## contractually guaranteed to be set!
		# my ($C) = $self->customer();
		my ($C) = $self->customer();
		if (ref($C) ne 'CUSTOMER') {
			&JSONAPI::append_msg_to_response(\%R,"iseerr",18349,"customer object was not available or valid.");	
			}
		elsif (not &validate_required_parameter(\%R,$v,'type',['BILL','SHIP'])) {
			}
		else {
			my $TYPE = uc($v->{'type'});
			my ($addr) = CUSTOMER::ADDRESS->new($C,$TYPE,\%addr);
			if (not defined $addr) {
				&JSONAPI::append_msg_to_response(\%R,"iseerr",18350,"address object could not be instantiated");	
				}
			else {
				$C->add_address($addr,'SHORTCUT'=>$SHORTCUT);
				&JSONAPI::append_msg_to_response(\%R,"success",0,"shortcut $SHORTCUT added");	
				}		
			}
	
		if (not &JSONAPI::hadError(\%R)) {
			$C->save();
			}

		}

	return(\%R);
	}


#################################################################################
##
##
##




#################################################################################
##
##
##

=pod

<API id="buyerWalletList">
<concept>wallet</concept>
<concept>buyer</concept>
<purpose>Displays a list of wallets</purpose>
<output id="@wallets">an array of wallets
</output>
<code type="json" title="@wallets sample output">
[
	{ ID:walletid1, IS_DEFAULT:1|0, DESCRIPTION:description },
	{ ID:walletid2, IS_DEFAULT:1|0, DESCRIPTION:description },
	{ ID:walletid3, IS_DEFAULT:1|0, DESCRIPTION:description },
]
</code>
</API>

=cut

sub buyerWalletList {
	my ($self,$v) = @_;
	my %R = ();
	
	my ($C) = $self->customer();
	if (ref($C) ne 'CUSTOMER') {
		&JSONAPI::append_msg_to_response(\%R,"iseerr",18349,"customer object was not available or valid.");	
		}
	else {
		my $payments_on_file = $C->wallet_list();	
		if (not defined $payments_on_file) {
			$payments_on_file = [];
			}
		$R{'@wallets'} = $payments_on_file;
		}

	return(\%R);
	}


#################################################################################
##
##
##

=pod

<API id="buyerWalletAdd">
<concept>wallet</concept>
<purpose>creates a new wallet for the associated buyer</purpose>
<input id="CC">Credit Card #</input>
<input id="YY">2 Digit Year</input>
<input id="MM">2 Digit Month</input>
<input id="IP">4 digit numeric ip address</input>
<output id="ID">wallet id # (on success)</output>
</API>

=cut

sub buyerWalletAdd {
	my ($self,$v) = @_;
	my %R = ();

	my ($C) = $self->customer();
	if (ref($C) ne 'CUSTOMER') {
		&JSONAPI::append_msg_to_response(\%R,"iseerr",18349,"customer object was not available or valid.");	
		}
	elsif (not &validate_required_parameter(\%R,$v,'CC','')) {
		}
	elsif (not &validate_required_parameter(\%R,$v,'YY','')) {
		}
	elsif (not &validate_required_parameter(\%R,$v,'MM','')) {
		}
	else {
		my %params = ();
		$params{'CC'} = $v->{'CC'};
		$params{'YY'} = $v->{'YY'};
		$params{'MM'} = $v->{'MM'};
		$params{'IP'} = $ENV{'REMOTE_ADDR'};
		my ($ID,$ERROR) = $C->wallet_store(\%params);
		$R{'ID'} = $ID;
		if ($ERROR) {
			&JSONAPI::append_msg_to_response(\%R,"iseerr",18350,"wallet error: $ERROR");	
			}
		else {
			&JSONAPI::append_msg_to_response(\%R,"success",0,"wallet added (ID:$ID)");	
			}
		}

	return(\%R);
	}


#################################################################################
##
##
##

=pod

<API id="buyerWalletDelete">
<purpose></purpose>
<input id="_cartid"></input>
walletid:#####
</API>

=cut

sub buyerWalletDelete {
	my ($self,$v) = @_;
	my %R = ();

	## contractually guaranteed to be set!
	my ($C) = $self->customer();
	if (ref($C) ne 'CUSTOMER') {
		&JSONAPI::append_msg_to_response(\%R,"iseerr",18349,"customer object was not available or valid.");	
		}
	elsif (not &validate_required_parameter(\%R,$v,'walletid','')) {
		}
	else {
		my ($ID) = int($v->{'walletid'});
		$C->wallet_nuke($ID);
		&JSONAPI::append_msg_to_response(\%R,"success",0,"wallet $ID deleted");	
		}

	return(\%R);
	}



#################################################################################
##
##
##

=pod

<API id="buyerWalletSetPreferred">
<purpose></purpose>
<input id="_cartid"></input>
walletid:#####
</API>

=cut

sub buyerWalletSetPreferred {
	my ($self,$v) = @_;
	my %R = ();

	## contractually guaranteed to be set!
	my ($C) = $self->customer();
	if (ref($C) ne 'CUSTOMER') {
		&JSONAPI::append_msg_to_response(\%R,"iseerr",18349,"customer object was not available or valid.");	
		}
	elsif (not &validate_required_parameter(\%R,$v,'walletid','')) {
		}
	else {
		my ($ID) = int($v->{'walletid'});
		$C->wallet_update($ID,'default'=>1);
		&JSONAPI::append_msg_to_response(\%R,"success",0,"wallet $ID set to preferred");	
		}

	return(\%R);
	}












#################################################################################
##
##
##

=pod

<API id="appBuyerLogin">
<purpose></purpose>
<input id="method">unsecure</input>
<input id="login">email address</input>
<input id="password">clear text password</input>
<output id="cid">customer id</output>
<output id="schedule">schedule</output>
</API>

=cut

#customerlogin
sub appBuyerLogin {
	my ($self,$v) = @_;
	my %R = ();

	## for now - this uses the *CUSTOMER record in the cart, eventually the JSON object will store it's own
	##	per session.

	delete $self->{'*CUSTOMER'};
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'method',['unsecure'])) {
		}
	elsif ($v->{'method'} eq 'unsecure') {	
		if ($v->{'login'} eq '') {
			&JSONAPI::append_msg_to_response(\%R,"apperr",6000,"login parameter is required for method=unsecure requests");
			}
		elsif ($v->{'password'} eq '') {
			&JSONAPI::append_msg_to_response(\%R,"apperr",6002,"password parameter is required for method=unsecure requests");
			}
		else {
			require CUSTOMER;
			my ($login,$password) = ($v->{'login'},$v->{'password'});
			my ($customer_id) = &CUSTOMER::authenticate($self->username(), $self->prt(), $login, $password);
			print STDERR "login:$login password:$password\n";

			## Did we get authenticated
			if ($customer_id == -100) {
				&JSONAPI::append_msg_to_response(\%R,"youerr",6006,"customer account is locked.");
				}
			elsif ($customer_id <= 0) {
				&JSONAPI::append_msg_to_response(\%R,"youerr",6005,"login attempt failed");
				}
			else {
				## version >=201311 auth to session, not a specific cart.
				$R{'cid'} = $customer_id;
				$self->customer( CUSTOMER->new( $self->username(), PRT=>$self->prt(), CID=>$customer_id ) );
				&JSONAPI::append_msg_to_response(\%R,'success',0);	
				$R{'schedule'} = $self->customer()->is_wholesale();
				}
			}
		}

	return(\%R);
	}








=pod

<API id="appBuyerDeviceRegistration">
<purpose>verify or create a client registration</purpose>
<input id="verb">verifyonly|create</input>
<input id="deviceid">client generated device key (guid), or well known identifier from device</input>
<input id="os">android|appleios</input>
<input optional="1" id="devicetoken">devicetoken (appleios) or registrationid (android) is required 
	(to avoid religious debatesboth are equivalent -- either is acceptable)</input>
<input optional="1" id="registrationid">devicetoken (appleios) or registrationid (android) is required 
	(to avoid relgious debates, both are equivalent -- either is acceptable)</input>
<input optional="1" id="email">email registration is insecure and may not always be available</input>
<output id="CID">client id</output>
</API>

=cut


sub appBuyer {
	my ($self,$v) = @_;

	my %R = ();

	if (not &JSONAPI::validate_required_parameter(\%R,$v,'os',['android','appleios'])) {
		}
	elsif ($v->{'_cmd'} eq 'appBuyerDeviceRegistration') {
		my $DEVICEREGISTRATIONTOKENID = undef;
		if ($v->{'os'} eq 'android') {
			$DEVICEREGISTRATIONTOKENID = $v->{'registrationid'}; 
			}
		if ($v->{'os'} eq 'appleios') {
			$DEVICEREGISTRATIONTOKENID = $v->{'devicetoken'}; 
			}
		my $KEY = sprintf("REGISTRATION-%s-%s-%s",$self->username(),$self->deviceid(),$DEVICEREGISTRATIONTOKENID);
		
		$R{'CID'} = 0;
		if (-f "/tmp/$KEY") { 
			$R{'CID'} = File::Slurp::read_file("/tmp/$KEY");
			}


		if (($R{'CID'} == 0) && ($v->{'verb'} eq 'create')) {

			if (not &JSONAPI::validate_required_parameter(\%R,$v,'email')) {
				}
			else {
				$R{'CID'} = CUSTOMER::resolve_customer_id($self->username(),$self->prt(),$v->{'email'});
				}

			if ($R{'CID'}>0) {
				## yay, we're verified.
				open F, ">/tmp/$KEY"; print F $R{'CID'}; 	close F;
				}
			}
		}


	return(\%R);
	}




#################################################################################
##
##
##

=pod

<API id="appBuyerCreate">
<purpose>
create a buyer account (currently requires form=wholesale)
long term goal is to support flexible *per project* account signups w/parameters
</purpose>
<input id="form">wholesale</input>
<note>
See adminCustomerUpdate for a full list of macros
</note>
</API>

=cut

sub appBuyerCreate {
	my ($self, $v) = @_;

	my $R = {};

	if ($self->apiversion() < 201318) {
		&JSONAPI::deprecated($self,$R,0);
		}
	else {
		## PRE201318 -- can be removed at 201320
		## 1. look /platform
		## 2. load file my $cfg = undef; if (not &JSONAPI::hadError($R)) {

		my $script = $v->{'_script'} || 'default';
		if (($v->{'_vendor'}) && ($self->apiversion()<201402)) { 
			$script = $v->{'_vendor'}; 
			}
		if (($v->{'vendor'}) && ($self->apiversion()<201402)) { 
			## i think this is the right one.
			$script = $v->{'vendor'}; 
			}
		if ((not defined $v->{'_script'}) && ($v->{'vendor'} || $v->{'_vendor'}) && ($self->apiversion()>201402) ) { 
			&JSONAPI::append_msg_to_response($R,'apperr',74229,'_script parameter is required (historically called /vendor/)');
			}

		my ($cfg) = $self->loadPlatformJSON('appBuyerCreate',$script,$v,$R);
		$R->{'%VARS'} = {};

		my $START = $cfg->{'_start'} || "appBuyerCreate";
		my @CMDS = ();
		if (&JSONAPI::hadError($R)) {
			}
		elsif (ref( $cfg->{$START} ) ne 'ARRAY') {
			&JSONAPI::append_msg_to_response($R,'apperr',74221,'_start point is not a well formed array.');
			}
		else {
			## HAPPY FUN MACRO PARSING TIME!!
			my $count = 0;
			foreach my $line (@{$cfg->{$START}}) {
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					if ($cmdset->[0] eq 'RUN') {
						## RUN?_start= IS A SPECIAL COMMAND THAT LOADS ANOTHER _start, and pushes those onto @CMDS
						my $INCLUDEREF = $cfg->{ $cmdset->[1]->{'_start'} };
						if ((defined $INCLUDEREF) && (ref($INCLUDEREF) eq 'ARRAY')) {
							foreach my $line2 (@{$INCLUDEREF}) {
								my $CMDSETS2 = &CART2::parse_macro_script($line2);
								foreach my $cmdset (@{$CMDSETS2}) {
									# $cmdset->[1]->{'luser'} = $self->luser();
									push @CMDS, $cmdset;
									}
								}
							}
						}
					else {
						# $cmdset->[1]->{'luser'} = $self->luser();
						push @CMDS, $cmdset;
						}
					}								
				}

			## HAPPY FUN INTERPOLATION TIME!!
			##		note: we intentionally only parse the values, and intentionally only if they match.
			foreach my $cmd (@CMDS) {
				foreach my $k (keys %{$cmd->[1]}) {
					my $var = $cmd->[1]->{$k};
					if (substr($var,0,1) eq '$') {
						$cmd->[1]->{$k} = $v->{ substr($var,1) };
						}
					}				
				}

			$R->{'@CMDS'} = \@CMDS;
			}

		if (&JSONAPI::hadError($R)) {
			}
		elsif (not &JSONAPI::validate_required_parameter($R,$v,'email')) {
			}
		elsif (&CUSTOMER::customer_exists($self->username(),$v->{'email'},$self->prt())) {
			## 665 is ALWAYS 'customer always exists'
			&JSONAPI::append_msg_to_response($R,'youerr',665,'Customer already exists.');
			}
		else {

			# my $IP = $ENV{'REMOTE_ADDR'};
			my ($C) = CUSTOMER->new($self->username(),'EMAIL'=>$v->{'email'},'PRT'=>$self->prt(),'CREATE'=>2, 'INIT'=>0xFF);
			if (not defined $C) {
				&JSONAPI::append_msg_to_response($R,'youerr',74221,'Could not create customer, possibly a duplicate.');
				}
			else {
				## we really ought to change the LU here to be the script id.
				$R = $C->run_macro_cmds(\@CMDS,'*LU'=>$self->LU(),'%R'=>$R);
				$R->{'CID'} = $C->cid();	## this seems useful
				if ($R->{'AUTHENTICATE'}->{'please'}) {
					$self->customer( $C );
					}
				if ($R->{'UNAUTHENTICATE'}->{'please'}) {
					$self->{'*CUSTOMER'} = undef;
					}
				}
			}
		}
#	elsif (($v->{'permissions'}) && ($self->apiversion()<=201318)) {
#		## GKWORLD -- PRE201318 -- can be removed at 201320
#		## 1. look /platform
#		my $file = undef;
#		my $PROJECTDIR = undef;
#		if (not $v->{'project'}) {
#			&JSONAPI::append_msg_to_response(\%R,'apperr',74221,'project not specified');
#			}
#		else {
#			$PROJECTDIR = $self->projectdir($v->{'project'});
#			if (! -d $PROJECTDIR) {
#				&JSONAPI::append_msg_to_response(\%R,'apierr',74222,'project directory does not seem to exist');
#				}
#			}
#
#		if (&JSONAPI::hadError(\%R)) {
#			## shit happened
#			}
#		elsif ($v->{'permissions'} =~ /^platform\/([A-Za-z0-9\-]+)\.json$/) {
#			$file = $1;
#			print STDERR "FILEX: $1\n";
#			if (! -f "$PROJECTDIR/platform/$file.json") {
#				&JSONAPI::append_msg_to_response(\%R,'apierr',74223,'permissions file does not seem to exist');
#				}
#			}
#		else {
#			&JSONAPI::append_msg_to_response(\%R,'apperr',74224,'permissions file must be alphanumeric and be in the platform directory and end with .json');
#			}
#
#		## 2. load file
#		my $cfg = undef;		
#		if (not &JSONAPI::hadError(\%R)) {
#			require WHOLESALE::SIGNUP;
#			## my ($cfg) = WHOLESALE::SIGNUP::load_config($self->username(),int($self->prt()));
#			my $json = '';
#			print STDERR "FILE: $PROJECTDIR/platform/$file.json\n";
#			open F, "<$PROJECTDIR/platform/$file.json";
#			while (<F>) {
#				next if (substr($_,0,2) eq '//');
#				$json .= $_;
#				} 
#			close F;
#			eval { $cfg = WHOLESALE::SIGNUP::json_to_ref($json); };
#			if ($@) {
#				&JSONAPI::append_msg_to_response(\%R,'apierr',74228,"permissions file specified is corrupt cause: $@");
#				}
#			elsif (ref($cfg) ne 'HASH') {
#				&JSONAPI::append_msg_to_response(\%R,'apierr',74225,'permissions json did not decode into array');
#				}
#			elsif (ref($cfg->{'fields'}) ne 'ARRAY') {
#				&JSONAPI::append_msg_to_response(\%R,'apierr',74226,'permissions json did not have required fields ARRAY attribute');
#				} 
#			}
#
#		## 3. execute file
#		my $fieldsandvalues = undef;
#		if (not &JSONAPI::hadError(\%R)) {
#			## all the save magic happens here!
#			$fieldsandvalues = WHOLESALE::SIGNUP::ref_to_vars($cfg->{'fields'},$v);
#			foreach my $f (@{$fieldsandvalues}) {
#				if ($f->{'err'}) { 
#					&JSONAPI::append_msg_to_response(\%R,'youerr',74227,"$f->{'label'} ($f->{'err'})");
#					}
#				}
#			}
#
#		if (not JSONAPI::hadError(\%R)) {
#			my ($err) = &WHOLESALE::SIGNUP::save_form($self->username(),int($self->prt()),$cfg,$fieldsandvalues);
#			if ($err) {
#				&JSONAPI::append_msg_to_response(\%R,'youerr',74229,"$err");
#				}
#			else {
#				&JSONAPI::append_msg_to_response(\%R,'success',0);
#				}
#			}		
#		}
#	elsif (($v->{'form'} eq 'wholesale') && ($self->apiversion()<=201314)) {
#		##
#		## LEGACY: REPLICATES OLD "WHOLESALE" FUNCTIONALITY -- NO LONGER SUPPORTED AFTER 201314
#		##
#		require WHOLESALE::SIGNUP;
#		my ($cfg) = WHOLESALE::SIGNUP::load_config($self->username(),int($self->prt()));
#		my $fields = WHOLESALE::SIGNUP::json_to_ref($cfg->{'json'});
#		
#		if (not $cfg->{'enabled'}) {
#			&JSONAPI::append_msg_to_response(\%R,'apperr',74211,'form not enabled');
#			}
#
#		if (not &JSONAPI::hadError(\%R)) {
#			## all the save magic happens here!
#			my $fieldsandvalues = WHOLESALE::SIGNUP::ref_to_vars($fields,$v);
#
#			# use Data::Dumper; print STDERR 'WHOLESALE: '.Dumper($fieldsandvalues);
#
#			my $err = undef;
#			foreach my $f (@{$fieldsandvalues}) {
#				next if $err;
#				if ($f->{'err'}) { $err = "$f->{'label'} ($f->{'err'})"; }
#				}
#
#			if (not defined $err) {
#				($err) = &WHOLESALE::SIGNUP::save_form($self->username(),int($self->prt()),$cfg,$fieldsandvalues);
#				}
#
#			if ($err) {
#				&JSONAPI::append_msg_to_response(\%R,'youerr',74219,"$err");
#				}
#			else {
#				&JSONAPI::append_msg_to_response(\%R,'success',0);
#				}
#			}
#		}
#	else {
#		&JSONAPI::append_msg_to_response(\%R,'apperr',74210,'permissions parameter is required');
##		}
	return($R);
	}





#################################################################################
##
##
##

=pod

<API id="appBuyerExists">
<purpose></purpose>
<input id="_cartid"></input>
login=email address

buyer: returns a positive number if buyer exists, or zero if it does not.

</API>

=cut

#appBuyerExists
sub appBuyerExists {
	my ($self,$v) = @_;
	my %R = ();


	if ($v->{'login'} eq '') {
		&JSONAPI::append_msg_to_response(\%R,"apperr",6000,"login parameter is required requests");
		}
	elsif (uc($self->webdb()->{'customer_management'}) eq 'DISABLED') {
		$R{'customer'} = 0;
		}
	else {
		require CUSTOMER;
	
		my ($CID) = &CUSTOMER::resolve_customer_id($self->username(), $self->prt(), $v->{'login'});
		if ($CID<0) { $CID = 0; }
		$R{'customer'} = $CID;
		}

	return(\%R);
	}




#	'buyerUpdateMacro'=>[ \&JSONAPI::buyerUpdateMacro, { 'buyer'=>1 } ],
#	'buyerPasswordUpdate'=>[ \&JSONAPI::buyerPasswordUpdate, { 'buyer'=>1 } ],

#################################################################################
##
##
##

=pod

<API id="buyerPasswordUpdate">
<purpose></purpose>
<input id="_cartid"></input>

password:newpassword

</API>

=cut

sub buyerPasswordUpdate {
	my ($self,$v) = @_;
	my %R = ();

	my ($C) = $self->customer();
	if (ref($C) ne 'CUSTOMER') {
		&JSONAPI::append_msg_to_response(\%R,"iseerr",18349,"customer object was not available or valid.");	
		}
	elsif ($v->{'password'} eq '') {
		&JSONAPI::append_msg_to_response(\%R,"apperr",18340,"password cannot be set to blank");			
		}
	elsif ($v->{'password'} eq 'abc123') {
		&JSONAPI::append_msg_to_response(\%R,"youerr",18340,"password is too simple, try another");			
		}
	elsif (length($v->{'password'})<6) {
		&JSONAPI::append_msg_to_response(\%R,"youerr",18341,"password should 6 or more characters");			
		}
	elsif (($v->{'password'} !~ /[a-zA-Z]/) || ($v->{'password'} !~ /[0-9]/)) {
		&JSONAPI::append_msg_to_response(\%R,"youerr",18342,"password should contain at least one letter and at least one number");
		}
	else {
		$C->set_attrib('INFO.PASSWORD',$v->{'password'});
		$C->save();
		&JSONAPI::append_msg_to_response(\%R,'success',0,'password was updated.');		
		}

	return(\%R);
	}




#################################################################################
##
##
##

=pod

<API id="buyerOrderUpdate">
<purpose>
A macro is a set of commands that will be applied to an order, they are useful because they are applied (whenever possible)
as a single atomic transaction. buyers have access to a subset of macros from full order processing, but enough to adjust
payment, and in some cases cancel orders.
</purpose>
<input id="_cartid"></input>
<input id="orderid">2012-01-1234</input>
<input id="@updates">see example below</input>
<note>
This uses the same syntax as adminCartMacro adminOrderMacro, but only a subset are supported (actually at this point ALL commands are supported, but we'll restrict this eventually), 
and may (eventually) differ based on business logic and/or add some custom ones. 
</note>
<example>
@updates:[
	'cmd',
	'cmd?some=param',
	]
</example>
<example>
Allowed commands:
ADDNOTE
</example>

</API>

=cut

sub buyerOrderUpdate {
	my ($self,$v) = @_;
	my %R = ();

	my $USERNAME = $self->username();

	my $ORDERID = $v->{'orderid'};

	my @CMDS = ();
	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	elsif (not defined $v->{'@updates'}) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9002,'Could not find any @updates for order');
		}
	elsif (ref($v->{'@updates'}) eq 'ARRAY') {
		foreach my $line (@{$v->{'@updates'}}) {
			my $CMDSETS = &CART2::parse_macro_script($line);
			foreach my $cmdset (@{$CMDSETS}) {
				push @CMDS, $cmdset;
				}
			}
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9002,'Issue with @updates formatting [we did not understand the format you sent]');
		}

	if (&ZOOVY::servername() eq 'dev') {
		open Fx, ">/tmp/ordermacros-$USERNAME.".time();
		print Fx Dumper(\@CMDS);
		close Fx;
		}

	# my ($o,$oerr) = (undef,undef);
	my ($O2) = undef;
	my $is_new = 0;

	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	elsif ($ORDERID eq '') {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9805,'ORDERID is required to update an order.');
		}
	else {
		($O2) = CART2->new_from_oid($USERNAME,$ORDERID);
		#($o,$oerr) = ORDER->new($USERNAME,$ORDERID,new=>0);
		#if (defined $oerr) {
		#	&JSONAPI::append_msg_to_response(\%R,'apperr',9801,'error:'.$oerr);
		#	}
		}

	if (&JSONAPI::hadError(\%R)) {	
		## shit happened!
		}
	else {
		my $ps = $O2->payment_status();
		if ($O2->pool() ne "RECENT") {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9806,'order is no longer in RECENT state and cannot be updated.');
			}
		}

	## PREFLIGHT CHECK
	## check the macros against the whitelist
   if (&JSONAPI::hadError(\%R)) {
		}
	else {
		my $line = 0;
		foreach my $CMDSET (@CMDS) {
			$line++;
			my ($cmd,$pref) = @{$CMDSET};

			if ($cmd eq 'ADDNOTE') {
				}
			#elsif ($cmd eq 'BUYERADDPAYMENT') {
			#	# || ($cmd eq 'ADDPAYMENT') || ($cmd eq 'ADDPROCESSPAYMENT')) {
			#	my $ps = $o->get_attrib('payment_status');
			#	if (scalar(@{$o->payments()})>10) {
			#		&JSONAPI::append_msg_to_response(\%R,'apperr',9809,"macro[$line] $cmd - too many payments (10+) on order.");
			#		}
			#	elsif ((substr($ps,0,1) eq '2') || (substr($ps,0,1) eq '9')) {
			#		## denied, and error status can have payments added.
			#		}
			#	else {
			#		&JSONAPI::append_msg_to_response(\%R,'apperr',9808,"macro[$line] $cmd - not allowed on payment_status[$ps]");
			#		}
			#	}
			else {
				&JSONAPI::append_msg_to_response(\%R,'apperr',9807,sprintf("macro[$line] not allowed: %s?%s",$cmd,&ZTOOLKIT::buildparams($pref)));
				}			
			}
		}

	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	elsif ((not defined $O2) || (ref($O2) ne 'CART2')) {
		# if ((not defined $oerr) || ($oerr eq '')) { $oerr = "Could not instantiate Order OBJ:$ORDERID (reason unknown)"; }
		warn  "Could not instantiate Order OBJ:$ORDERID (reason unknown)";
		}
	else {
		$R{'orderid'} = $ORDERID;
		$O2->add_history("called buyerOrderUpdate::MACRO",etype=>128);
		my ($echo) = $O2->run_macro_cmds(\@CMDS);

		$O2->order_save();
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}

	if (not &JSONAPI::hadError(\%R)) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
   return(\%R);
	}




#################################################################################
##
##
##

=pod

<API id="buyerOrderPaymentAdd">
<purpose>
Adds and processes a new payment transaction on an order.
</purpose>
<input id="_cartid"></input>
<input id="orderid">2012-01-1234</input>
<input id="tender">CREDIT</input>
<input id="amt">(optional - will default to order balance_due) transaction amount</input>
<input id="uuid">(optional - will be autogenerated if not supplied) unique identifier for this transaction</input>
<input id="payment.cc">(required on tender=CREDIT) Credit card #</input>
<input id="payment.yy">(required on tender=CREDIT) Credit card Expiration Year</input>
<input id="payment.mm">(required on tender=CREDIT) Credit card Expiration Month</input>
<input id="payment.cv">(required on tender=CREDIT) Credit card CVV/CID #</input>

</API>

<API id="buyerOrderGet">
<purpose>
Grabs a raw order object (buyer perspective) so that status information can be displayed. 
</purpose>
<input id="_cartid"></input>
<hint>In order to access an order status the user must either be an authenticated buyer, OR use softauth=order with
cartid + either orderid or erefid</hint>
<input id="softauth">order</input>
<input id="erefid">(conditionally-required for softauth=order) external reference identifier (ex: ebay sale #) or amazon order #</input>
<input id="orderid">(conditionally-required for softauth=order) internal zoovy order #</input>
<input id="cartid">(conditionally-required for softauth=order) internal cartid #</input>
<input id="orderid">(required for softauth=order) original cart session id</input>
</API>

=cut

sub buyerOrder {
	my ($self,$v, $CACHEREF) = @_;
	my %R = ();

	my ($O2) = $CACHEREF->{sprintf("*CART2[%s]",$v->{'orderid'})};

	if (not defined $O2) {
		# ($o,my $err) = ORDER->new($self->username(),$v->{'orderid'},new=>0);
		($O2) = CART2->new_from_oid($self->username(),$v->{'orderid'});

		if (not defined $O2) {
			&JSONAPI::append_msg_to_response(\%R,"apperr",34903,"order error");
			}
	 	elsif ( not defined $self->customer() ) {
			&JSONAPI::append_msg_to_response(\%R,"apperr",34904,"customer object not set for global cart");
			}
		elsif ( $O2->in_get('customer/cid') == $self->customer()->cid() ) {
			## YAY the two customer id's match
			}
	 	elsif ( lc($O2->in_get('bill/email')) ne lc($self->customer()->email()) ) {
			&JSONAPI::append_msg_to_response(\%R,"apperr",34905,"requested customer record does not match the order");
			$O2 = undef;
			}
		}

	if (&hadError(\%R)) {
		}
	elsif ($v->{'_cmd'} eq 'buyerOrderGet') {
		## nothign else to do here, we're just going to return the order
		}
	elsif ($v->{'_cmd'} eq 'buyerOrderPaymentAdd') {
		##
		my $ps = $O2->in_get('flow/payment_status');
		if (scalar(@{$O2->payments()})>10) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',34909,"not allowed - many payments (10+) on order.");
			}
		elsif ((substr($ps,0,1) eq '2') || (substr($ps,0,1) eq '9')) {
			## denied, and error status can have payments added.
			}
		else {
			&JSONAPI::append_msg_to_response(\%R,'apperr',34908,"not allowed on payment_status[$ps]");
			}
		
		my $TENDER = $v->{'TN'};
		my $AMOUNT = sprintf("%.2f",$v->{'amt'});
		if ($AMOUNT < 0) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',34908,"nice try, but sorry - you cant add a negative payment amount to an order");
			}
		elsif ($AMOUNT == 0) {
			## if amount is not set, then use balance due
			$AMOUNT = $O2->in_get('sum/balance_due_total');
			}
		elsif ($AMOUNT > $O2->in_get('sum/balance_due_total')) {
			$AMOUNT = $O2->in_get('sum/balance_due_total');
			}
		
		my %paymentvars = ();
		if (not &hadError(\%R)) {
			## SANITY: check the tender type
			my $TENDER_IS_OKAY = 0;
			my $paymethods = &ZPAY::payment_methods($O2->username(),'webdb'=>$self->webdb(),'ordertotal'=>$O2->in_get('sum/order_total'));
			foreach my $methodset (@{$paymethods}) {
				if ($methodset->{'ID'} eq $v->{'TN'}) { $TENDER_IS_OKAY++; }
				}
			foreach my $k (keys %{$v}) {
				if ($k =~ /^payment\.(.*?)$/) { $paymentvars{uc($1)} = $v->{$k}; }
				}
			## TODO: check payment variables
			if ($v->{'TN'} eq 'CREDIT') {
				my ($cc_verify_errors) = &ZPAY::verify_credit_card($paymentvars{'CC'},$paymentvars{'MM'},$paymentvars{'YY'});
				if ($cc_verify_errors ne '') { 
					&JSONAPI::append_msg_to_response(\%R,"youerr",34001,sprintf("TENDER:CREDIT error: %s %s",$cc_verify_errors));
					}
				}
			}

		my $payrec = undef;
		if (not &hadError(\%R)) {
			($payrec) = $O2->add_payment($v->{'TN'},$AMOUNT,
				'note'=>'Added by Customer after Order was placed',
				'luser'=>'*CUSTOMER',
				'app'=>$self->clientid(),
				);
			$O2->process_payment('INIT',$payrec,%paymentvars);
			$O2->add_history("Payment information updated on website by customer.",etype=>3,luser=>'*CUSTOMER');
			$O2->save_order();

			if (substr($payrec->{'ps'},0,1) eq '0') {
				## success: paid
				}
			elsif (substr($payrec->{'ps'},0,1) eq '1') {
				## success: pending
				}
			elsif (substr($payrec->{'ps'},0,1) eq '4') {
				## success: review
				}
			else {
				&JSONAPI::append_msg_to_response(\%R,"youerr",34000,sprintf("Payment result[%d]: %s",$payrec->{'ps'},$ZPAY::PAYMENT_STATUS{ $payrec->{'ps'} }));
				}			
			}

		if (not &hadError(\%R)) {
			#&ZOOVY::add_event($O2->username(),"PAYMENT.UPDATE",
			#	'ORDERID'=>$O2->oid(),
			#	'PRT'=>$O2->prt(),
			#	'SDOMAIN'=>$self->sdomain(),
			#	'SRC'=>'Customer Account @ '.$self->sdomain(),
			#	);
			#my $orderid = $O2->oid();
			#require TODO;
			#&TODO::easylog($self->username(),
			#	title=>"Customer Updated Order $orderid via website",
			#	detail=>"Customer Updated Payment Information for $orderid has been changed.",
			#	order=>$orderid,
			#	link=>"ORDER:$orderid",
			#	code=>40001
			#	);
			my $orderid = $O2->oid();
			&ZOOVY::add_event($O2->username(),"PAYMENT.UPDATE",
				title=>"Customer Updated Order $orderid via website",
				detail=>"Customer Updated Payment Information for $orderid has been changed.",
				order=>$O2->oid(),
				prt=>$O2->prt(),
				link=>"ORDER:$orderid",
				src=>'Customer Account @ '.$self->sdomain(),
				);
			}

		}
	else {
		&JSONAPI::append_msg_to_response(\%R,"iseerr",34903,"this was an invalid cmd - this line should never be reached");
		}

	if (&hadError(\%R)) {
		}
	elsif (defined $O2) {
		$R{'order'} = $O2->make_public()->jsonify();
		&JSONAPI::append_msg_to_response(\%R,'success',0);	
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,"iseerr",34902,"this line should never be reached");
		}

	return(\%R);
	}



#################################################################################
##
##
##

=pod

<API id="buyerTicketList">
<purpose>
shows a list of ticket for a buyer
</purpose>
<input id="_cartid"></input>
</API>

=cut

sub buyerTicketList {
	my ($self,$v) = @_;

	my %R = ();

	return(\%R);
	}


#################################################################################
##
##
##

=pod

<API id="buyerTicketCreate">
<purpose>
creates a new ticket for a customer
</purpose>
<input id="_cartid"></input>

</API>

=cut

sub buyerTicketCreate {
	my ($self,$v) = @_;
	my %R = ();

	return(\%R);
	}


#################################################################################
##
##
##

=pod

<API id="buyerTicketUpdate">
<purpose>
updates a ticket for a buyer
</purpose>
<input id="_cartid"></input>
</API>

=cut

sub buyerTicketUpdate {
	my ($self,$v) = @_;

	my %R = ();
	return(\%R);
	}







#################################################################################
##
##
##

=pod

<API id="buyerLogout">
<purpose></purpose>
<input id="_cartid"></input>
</API>

=cut

sub buyerLogout {
	my ($self,$v) = @_;
	my %R = ();

	delete $self->{'*CUSTOMER'};
	$R{'schedule'} = '';

	&JSONAPI::append_msg_to_response(\%R,'success',0);		

	return(\%R);
	}




#################################################################################
##
##
##

=pod

<API id="appBuyerPasswordRecover">
<purpose></purpose>
<input id="_cartid"></input>
<input id="login"></input>
<input id="method">email</input>
</API>

=cut

sub appBuyerPasswordRecover {
	my ($self,$v) = @_;
	my %R = ();

	my $CID = 0;
	if ($v->{'login'} eq '') {
		&JSONAPI::append_msg_to_response(\%R,"apperr",6000,"login parameter is required requests");
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'method',['email'])) {
		}
	else {
		require CUSTOMER;
		($CID) = &CUSTOMER::resolve_customer_id($self->username(), $self->prt(), $v->{'login'});
		if ($CID<0) { $CID = 0; }
		if ($CID==0) { &JSONAPI::append_msg_to_response(\%R,"youerr",6002,"account does not exist."); }
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($CID==0) {
		&JSONAPI::append_msg_to_response(\%R,"iseerr",6006,"internal logic error CID=0 but no error set.");
		}
	elsif ($v->{'method'} eq 'email') {
		my ($C) = CUSTOMER->new($self->username(),'PRT'=>int($self->prt()),'CID'=>$CID,'INIT'=>0xFF);
		my @CMDS = ();
		push @CMDS, ['PASSWORD-RECOVER', {}];
		push @CMDS, ['BLAST-SEND', { 'MSGID'=>'CUSTOMER.PASSWORD.RECOVER' }];
		$C->run_macro_cmds(\@CMDS);
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,"iseerr",6005,"unknown password recovery method line is never reached."); 
		}

	# $CART2->logout();

	return(\%R);
	}












#################################################################################
##
##
##

=pod

<API id="adminOrderPaymentMethods">
<purpose>
displays a list of payment methods available for an order (optional), there are a few scenarios where things
get wonky.
first - if the logged in user is admin, then additional methods like cash, check, all become available (assuming they are
enabled).
second - if the order has a zero dollar total, only ZERO will be returned.
third - if the order has giftcards, no paypalec is available. (which is fine, because paypalec is only available for the client)
fourth - if the order has paypalec payment (already) then other methods aren't available, because paypal doesn't support mixing and matching payment types.
</purpose>
<input id="_cartid"></input>
<input optional="1" id="orderid">orderid #</input>
<input optional="1" id="customerid">customerid #</input>
<input optional="1" id="country">ISO country cod</input>
<input optional="1" id="ordertotal">#####.##</input>

<response id="@methods"></response>
<example>
@methods = [
	[ id:"method", pretty:"pretty title", fee:"##.##" ],
	[ id:"method", pretty:"pretty title", fee:"##.##" ]
	]
</example>


</API>

=cut

sub adminOrderPaymentMethods {
	my ($self,$v) = @_;
	my %R = ();

	my %options = ();

	$options{'webdb'} = $self->webdb();

	$options{'prt'} = $self->prt();
	if (&ZOOVY::servername() eq 'dev') {
		$options{'trust_me_im_secure'} = 1;
		}
	$options{'admin'} = $self->is_admin();
	if (defined $v->{'country'}) { $options{'country'} = $v->{'country'}; }
	if (defined $v->{'ordertotal'}) { $options{'ordertotal'} = $v->{'ordertotal'}; }

	if ((defined $v->{'orderid'}) && ($v->{'orderid'} ne '')) {
		$options{'orderid'} = $v->{'orderid'};
		$options{'cart2'} = CART2->new_from_oid($self->username(),$v->{'orderid'});
		if (not defined $options{'cart2'}) {
			&JSONAPI::set_error(\%R,'youerr',7476,'the order id specified does not exist or could not be loaded.');
			}
		}

	if ((defined $v->{'customer'}) && ($v->{'customer'} ne '')) {
		my ($CID) = int($v->{'customer'});
		$options{'*C'} = CUSTOMER->new($self->username(),'PRT'=>$self->prt(),'CID'=>$CID);
		if (not defined $options{'*C'}) {
			&JSONAPI::set_error(\%R,'youerr',7477,'the order id specified does not exist or could not be loaded.');
			}
		}

	## print STDERR "IS_ADMIN: ".$self->is_admin()."\n";
	if (not &JSONAPI::hadError(\%R)) {
		require ZPAY;
		$R{'@methods'} = &ZPAY::payment_methods($self->username(),%options);
		}
 
	return(\%R);
	}



#################################################################################
##
##
##

=pod

<API id="appPaymentMethods">
<purpose></purpose>
<input id="_cartid"></input>
<input optional="1" id="country">ISO country cod</input>
<input optional="1" id="ordertotal">#####.##</input>

<response id="@methods"></response>
<example>
@methods = [
	[ id:"method", pretty:"pretty title", fee:"##.##" ],
	[ id:"method", pretty:"pretty title", fee:"##.##" ]
	]
</example>


</API>

=cut

sub appPaymentMethods {
	my ($self,$v) = @_;
	my %R = ();

	my %options = ();

	$options{'webdb'} = $self->webdb();

	$options{'prt'} = $self->prt();
	if (&ZOOVY::servername() eq 'dev') {
		$options{'trust_me_im_secure'} = 1;
		}
	$options{'admin'} = $self->is_admin();
	if (defined $v->{'country'}) { $options{'country'} = $v->{'country'}; }
	if (defined $v->{'ordertotal'}) { $options{'ordertotal'} = $v->{'ordertotal'}; }

	if ($v->{'_cartid'}) {
		$options{'cart2'} = $self->cart2( $v->{'_cartid'} );
		}

	require ZPAY;
	$R{'@methods'} = &ZPAY::payment_methods($self->username(),%options);

#	open F, ">/tmp/appPaymentMethods";
#	print F Dumper(\%options,\%R,\%ENV);
#	close F;

	return(\%R);
	}









#################################################################################
##
##
##

=pod

<API id="appCheckoutDestinations">
<purpose></purpose>
<input id="_cartid"></input>
<example>
@destinations = [
	[ z:"Pretty Name", iso:"US", isox:"USA" ],
	[ z:"Pretty Name", iso:"US", isox:"USA" ],
	]
</example>
</API>

=cut

sub appCheckoutDestinations {
	my ($self,$v) = @_;
	my %R = ();

	my $CART2 = undef;

	if ($v->{'_cartid'} eq '') {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9998,"_cartid parameter is required for $v->{'_cmd'} version > 201310");			
		}
	else {
		$CART2 = $self->cart2( $v->{'_cartid'} );
		}

	require ZSHIP;
	$R{'@destinations'} = &ZSHIP::available_destinations($CART2,$self->webdb());

	return(\%R);
	}


#################################################################################
##
##
##

=pod

<API id="cartPaypalSetExpressCheckout">
<purpose></purpose>
<input id="_cartid"></input>
<input id="getBuyerAddress"> 0|1 (if true - paypal will ask shopper for address)</input>
<input id="cancelURL"> ''   (required, but may be blank for legacy checkout)</input>
<input id="returnURL"> ''	 (required, but may be blank for legacy checkout)</input>

<input optional="1" id="useShippingCallbacks"> 0|1 (if true - forces shipping callbacks,
generates an error when giftcards are present and shipping is not free) 
if set to zero, then store settings (enable/disabled) will be used.
</input>

<response id="URL">url to redirect checkout to (checkout will finish with legacy method, but you CAN build your own)</response>
<response id="TOKEN">paypal token</response>
<response id="ACK">paypal "ACK" message</response>
<response id="ERR">(optional message from paypal api)</response>
<response id="_ADDRESS_CHANGED">1|0</response>
<response id="_SHIPPING_CHANGED">methodid (the new value of CART->ship.selected_id)</response>

</API>

=cut

sub cartPaypalSetExpressCheckout {
	my ($self,$v) = @_;
	my %R = ();

	my $CART2 = undef;

	if ($v->{'_cartid'} eq '') {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9998,"_cartid parameter is required for $v->{'_cmd'} version > 201310");			
		}
	else {
		$CART2 = $self->cart2( $v->{'_cartid'} );

		if ($CART2->cartid() ne $v->{'_cartid'}) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9997,"_cartid requested is not valid.");			
			}
		elsif (scalar(@{$CART2->stuff2()->items()})==0) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9996,"requested cart is empty.");			
			}

		}

	if (JSONAPI::hadError(\%R)) {
		}
	elsif (not defined $v->{'useShippingCallbacks'}) {
		$v->{'useShippingCallbacks'} = 0;
		}
	elsif ($v->{'useShippingCallbacks'}) {
		if ($CART2->get_in('sum/shp_total')==0) {
			## free shippping, it's fine!
			}
		elsif (scalar(@{$CART2->has_giftcards()})>0) {
			## if they are using giftcards, and shipping is not free- throw an error.
			&JSONAPI::append_msg_to_response(\%R,'apperr',3549,"paypal shipping callbacks not compatible with giftcards (except with free shipping)");
			}
		}

	if (&JSONAPI::hadError(\%R)) {
		## shit already happened.
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'getBuyerAddress',['0','1'])) {
		## this is required
		}
	elsif (not defined $v->{'cancelURL'}) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',3550,"cancelURL must be defined (even if blank)");
		}
	elsif (not defined $v->{'returnURL'}) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',3551,"returnURL must be defined (even if blank)");		
		}
	else {
		my $mode = ($v->{'getBuyerAddress'}?'cartec':'checkoutec');
		require ZPAY::PAYPALEC;
		my ($api) = ZPAY::PAYPALEC::SetExpressCheckout($self->_SITE(),$CART2,$mode,
			'cancelURL'=>$v->{'cancelURL'},
			'returnURL'=>$v->{'returnURL'},
			'useShippingCallbacks'=>$v->{'useShippingCallbacks'},
			);

		my @MSGS = ();
		while (defined $api->{sprintf("L_ERRORCODE%d",scalar(@MSGS))}) {
			push @MSGS, sprintf("PAYPAL[%d] %s",$api->{sprintf("L_ERRORCODE%d",scalar(@MSGS))},$api->{sprintf("L_LONGMESSAGE%d",scalar(@MSGS))});
			}

		if ($api->{'ERR'}) {
			&JSONAPI::append_msg_to_response(\%R,'apierr',3500,$api->{'ERR'});
			}
		elsif (($api->{'ACK'} eq 'Failure') || ($api->{'URL'} eq '')) {
			&JSONAPI::append_msg_to_response(\%R,'apierr',3501,join("|",@MSGS));
			}
		elsif ($api->{'URL'} ne '') {
			%R = %{$api};
			}
		else {
			%R = %{$api};
			&JSONAPI::append_msg_to_response(\%R,'success',0);
			}		
		}

	return(\%R);
	}








#################################################################################
##
##
##

=pod

<API id="cartGoogleCheckoutURL">
<purpose></purpose>
<input id="_cartid"></input>
<input id="analyticsdata"> (required, but may be blank) obtained by calling getUrchinFieldValue() 
in the pageTracker or _gaq Google Analytics object.
</input>
<input id="edit_cart_url"></input>
<input id="continue_shopping_url"></input>

<hint>
<![CDATA[
Google has extensive documentation on it's checkout protocols, you need use buttons served by google.
MORE INFO: http://code.google.com/apis/checkout/developer/index.html#google_checkout_buttons

NOTE: googleCheckoutMerchantId is passed in the config.js if it's blank, the configuration is incomplete and don't
try using it as a payment method.

To select a button you will need to know the merchant id (which is returned by this call), the style and
variant type of the button. Examples are provided below so hopefully you can skip reading it! 
You must use their button(s). Possible: style: white|trans, Possible variant: text|disable
]]>
</hint>

<caution>
<![CDATA[
note: if one or more items in the cart has 'gc:blocked' set to true - then google checkout button must be
shown as DISABLED using code below:
https://checkout.google.com/buttons/checkout.gif?merchant_id=[merchantid]&w=160&h=43&style=[style]&variant=[variant]&loc=en_US

These are Googles branding guidelines, hiding the button (on a website) can lead to stern reprimand and even termination from 
Google programs such as "trusted merchant".
]]>
</caution>

<hint>
<![CDATA[
Here is example HTML that would be used with the Asynchronous Google Analytics tracker (_gaq).

<a href="javascript:_gaq.push(function() {
   var pageTracker = _gaq._getAsyncTracker();setUrchinInputCode(pageTracker);});
   document.location='$googlecheckout_url?analyticsdata='+getUrchinFieldValue();">
<img height=43 width=160 border=0 
	src="https://checkout.google.com/buttons/checkout.gif?merchant_id=[merchantid]&w=160&h=43&style=[style]&variant=[variant]&loc=en_US"
	></a>
]]>
</hint>

<response id="googleCheckoutMerchantId"></response>
<response id="URL"></response>

</API>

=cut

sub cartGoogleCheckoutURL {
	my ($self,$v) = @_;
	my %R = ();

	if (&JSONAPI::deprecated($self,\%R,201352)) {
		## discontinued by Google Nov 2013
		}

	return(\%R);
	}






#################################################################################
##
##
##

=pod

<API id="cartAmazonPaymentURL">
<purpose></purpose>
<input id="_cartid"></input>
<input id="shipping"> 1|0 	(prompt for shipping address)</input>
<input id="CancelUrl"> URL to redirect user to if cancel is pressed.</input>
<input id="ReturnUrl"> URL to redirect user to upon order completion</input>
<input id="YourAccountUrl"> URL where user can be directed to by amazon if they wish to lookup order status. (don't stree about this, rarely used)</input>

<hint>
<![CDATA[
Returns parameters necessary for CBA interaction:

merchantid: the checkout by amazon assigned merchantid (referred to as [merchantid] in the example below)
b64xml: a base64 encoded xml order object based on the current cart geometry referred to as [b64xml], BUT passed to amazon following "order:"
signature: a sha1, base64 encoded concatenation of the b64xml and the configured cba secret key refrerred to as [signature] in the example below, AND passed to amazon following "signature:"
aws-access-key-id: a public string cba needs to identify this merchant refrred to as [aws-access-key-id] AND passed to amazon following the "aws-access-key-id:" parameter

To generate/create a payment button, suggested parameters are: color: orange, size: small, background: white
https://payments.amazon.com/gp/cba/button?ie=UTF8&color=[color]&background=[background]&size=[size]
ex:
https://payments.amazon.com/gp/cba/button?ie=UTF8&color=orange&background=white&size=small
Use this as the **your button image url** in the example.

The [formurl] is created by the developer using the merchant id, specify either sandbox or non-sandbox (live):
https://payments.amazon.com/checkout/[merchantid]
https://payments-sandbox.amazon.com/checkout/[merchantid]?debug=true
]]>
</hint>

<example title="Example"><![CDATA[

&lt;!- NOTE: you do NOT need to include jquery if you already are using jquery -&gt;
<script type="text/javascript" src="https://images-na.ssl-images-amazon.com/images/G/01/cba/js/jquery.js"></script>

<script type="text/javascript" src="https://images-na.ssl-images-amazon.com/images/G/01/cba/js/widget/widget.js"></script>
<form method=POST action="https://payments.amazon.com/checkout/[merchantid]">
<input type="hidden" name="order-input" value="type:merchant-signed-order/aws-accesskey/1;order:[b64xml];signature:[signature];aws-access-key-id:[aws-access-key-id]">
<input type="image" id="cbaImage" name="cbaImage" src="**your button image url**" onClick="this.form.action='[formurl]'; checkoutByAmazon(this.form)">
</form>

]]>
</example>

</API>

=cut

sub cartAmazonPaymentURL {
	my ($self,$v) = @_;
	my %R = ();


	if (not defined $self->webdb()) {
		&JSONAPI::append_msg_to_response(\%R,'iseerr',3510,"webdb object is corrupt/undefined");
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'shipping','')) {
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'CancelUrl','')) {
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'ReturnUrl','')) {
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'YourAccountUrl','')) {
		}

	my $CART2 = undef;
	if ($v->{'_cartid'} eq '') {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9998,"_cartid parameter is required for $v->{'_cmd'} version > 201310");			
		}
	else {
		$CART2 = $self->cart2( $v->{'_cartid'} );
		}

	require ZPAY::AMZPAY;
	if (not &JSONAPI::hadError(\%R)) {
		## excellent! lets generate the xml we'll need
		($R{'xml'}) = &ZPAY::AMZPAY::xmlCart($CART2,$self->_SITE(),
			'shipping'=>$v->{'shipping'},
			'ReturnUrl'=>$v->{'ReturnUrl'},
			'CancelUrl'=>$v->{'CancelUrl'},
			'YourAccountUrl'=>$v->{'YourAccountUrl'}
			);

		if ($R{'xml'} eq '') {
			&JSONAPI::append_msg_to_response(\%R,'iseerr',3545,"xml response from AMZPAY::xmlCart is blank");		
			}
		}

	if (not &JSONAPI::hadError(\%R)) {
		my $PBP = &ZPAY::AMZPAY::payment_button_params($self->username(),$CART2,$self->webdb(),$R{'xml'});

		if ($PBP->{'ERRCODE'}>0) {
			## apperr
			&JSONAPI::append_msg_to_response(\%R,'iseerr',3544,sprintf("AMZPAY button_params error[%d]:%s",$PBP->{'ERRCODE'},$PBP->{'ERRMSG'}));
			}
		elsif ((not defined $PBP->{'b64xml'}) || ($PBP->{'b64xml'} eq '')) {
			&JSONAPI::append_msg_to_response(\%R,'iseerr',3543,"AMZPAY button_params returned blank/null b64xml");
			}
		elsif ((not defined $PBP->{'signature'}) || ($PBP->{'signature'} eq '')) {
			&JSONAPI::append_msg_to_response(\%R,'iseerr',3542,"AMZPAY button_params returned blank/null signature");
			}
		elsif ((not defined $PBP->{'aws-access-key-id'}) || ($PBP->{'aws-access-key-id'} eq '')) {
			&JSONAPI::append_msg_to_response(\%R,'iseerr',3541,"AMZPAY button_params returned blank/null aws-access-key-id");
			}
		elsif ((not defined $PBP->{'referenceId'}) || ($PBP->{'referenceId'} eq '')) {
			&JSONAPI::append_msg_to_response(\%R,'iseerr',3540,"AMZPAY button_params returned blank/null referenceId");
			}
		else {
			## whitelist parameters
			foreach my $k ('b64xml','signature','aws-access-key-id','referenceId') {
				$R{$k} = $PBP->{$k};
				}
			&JSONAPI::append_msg_to_response(\%R,'success',0);
			}
		}

	return(\%R);
	}








#################################################################################
##
##
##

=pod

<API id="cartSet">
<purpose></purpose>
<input id="_cartid"></input>
</API>

=cut

sub cartSet {
	my ($self,$v) = @_;
	my %R = ();

	# print STDERR Dumper($v);

	my $CART2 = undef;
	if ($v->{'_cartid'} eq '') {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9998,"_cartid parameter is required for $v->{'_cmd'} version > 201310");			
		}
	else {
		$CART2 = $self->cart2( $v->{'_cartid'} );
		}

	if (not defined $CART2) {
		&set_error(\%R,'apperr',111,'Invalid or Corrupted Cart');
		}
	elsif ($self->is_admin()) {
		## enables the ability to set special fields in the order
		$CART2->in_set('is/origin_staff',$self->luser());
		}

	if (&JSONAPI::hadError(\%R)) {
		## shit happened
		}
	else {
		## CURRENT RELEASE

		foreach my $k (keys %{$v}) {
			next if (substr($k,0,1) eq '_');	# skip reserved variables
			next if ($k eq 'payment/CC');
			next if ($k eq 'payment/CV');
			next if ($k eq 'payment/MM');
			next if ($k eq 'payment/YY');
			$CART2->pu_set($k,$v->{$k});
			}		
		}

	

	return(\%R);
	}



#################################################################################
##
##
##

=pod

<API id="cartCSRShortcut">
<purpose>Returns a 4-6 digit authorization token that can be used by a 
call center operator to identify a session.  CSR shortcuts are only valid for approximately 10 minutes.</purpose>
<input id="_cartid"></input>
<output id="csr"></output>
</API>

=cut

sub cartCSRShortcut {
	my ($self,$v) = @_;
	my %R = ();

	my ($redis) = &ZOOVY::getRedis($self->username(),0);
	my $CART2 = undef;

	if (not &JSONAPI::validate_required_parameter(\%R,$v,'_cartid')) {
		}
	else {
		$CART2 = $self->cart2( $v->{'_cartid'}, 'create'=>0 );
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (not defined $CART2) {
		&JSONAPI::set_error(\%R,'apperr',3023,"Requested cart is not valid");
		}
	else {
		srand( time() ^ ($$ + ($$ << 15)) * (rand()+1) );
		$R{'cartid'} = $CART2->cartid();
		$R{'csr'} = sprintf("%04d",rand()*$$ % 10000);	## 4 digit codes.
		}

	if ($R{'cartid'}) {
		$redis->setex(
			sprintf("shortcut.%d",$R{'csr'}),
			3600,
			$R{'cartid'}
			);
		}


	return(\%R);
	}



=pod

<API id="adminCSRLookup">
<purpose>Lookups a 4-6 digit code</purpose>
<input id="csr"></input>
<input id="cartid"></input>
</API>


=cut

sub adminCSRLookup {
	my ($self,$v) = @_;
	my %R = ();

	my ($redis) = &ZOOVY::getRedis($self->username(),0);
	my $CART2 = undef;
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'csr')) {
		}
	else {
		$R{'csr'} = $v->{'csr'};
		$R{'cartid'} = $redis->get(sprintf("shortcut.%d",$R{'csr'}));
		if ($R{'cartid'} eq '') {
			&JSONAPI::set_error(\%R,'missing',3023,"Requested csr is not valid");
			}
		}

	if (not &JSONAPI::hadError(\%R)) {
		}

	return(\%R);
	}


=pod

cart.change	: a message informing either side the cart has changed and should be reloaded

chat.join	: should be posted whenever a person enters a channel
chat.post	: you know, a message to be displayed
chat.exit	: posted whenever somebody leaves

view.product	: to indicate the client is viewing a product
view.category	:   viewing category
view.search     : 	viewing search

goto.product : a suggestion (which could be taken by the app as a direction) to navigate to the product
goto.category
goto.search
goto.url

=cut

sub cartMessagePush {
	my ($self,$v) = @_;
	my %R = ();
	
	my ($redis) = &ZOOVY::getRedis($self->username(),0);
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'_cartid')) {
		}
	else {
		my %KEEP = ();
		foreach my $k ('WHAT','FOR','WHY') { 
			if (defined $v->{$k}) { $KEEP{$k} = $v->{$k}; }
			}

		if ($self->is_admin()) {
			$KEEP{'FROM'} = 'ADMIN';
			}
		else {
			$KEEP{'FROM'} = 'CLIENT';
			}

		foreach my $k (keys %{$v}) {
			next if (substr($k,0,1) eq '_');
			if (lc($k) eq $k) { $KEEP{$k} = $v->{$k}; }
			}

		my $REDISKEY = sprintf("msgs+%s.%d+%s",$self->username(),$self->prt(),$v->{'_cartid'});
		$R{'SEQ'} = $redis->hincrby($REDISKEY,"SEQ",1);
		$redis->hsetnx($REDISKEY,sprintf("#%d",$R{'SEQ'}), JSON::XS::encode_json(\%KEEP));
		$redis->expire($REDISKEY,86400);
		}
	return(\%R);
	}

=pod

SEQ
SINCE

=cut 

sub cartMessageList {
	my ($self,$v) = @_;
	my %R = ();

	my ($redis) = &ZOOVY::getRedis($self->username(),0);
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'_cartid')) {
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'since')) {
		}
	else {
		my $REDISKEY = sprintf("msgs+%s.%d+%s",$self->username(),$self->prt(),$v->{'_cartid'});
		my $SEQ = $R{'SEQ'} = int($redis->hget($REDISKEY,"SEQ"));
		my $SINCE = int($v->{'since'});
		my @MSGS = ();
		while (++$SINCE <= $SEQ) {
			my $json = $redis->hget($REDISKEY,sprintf("#%d",$SINCE));
			my $ref = JSON::XS::decode_json($json);
			push @MSGS, $ref;
			}	
		$R{'@MSGS'} = \@MSGS;
		}
	return(\%R);
	}





#################################################################################
##
##
##

=pod

<API id="cartShippingMethods">
<purpose></purpose>
<input id="_cartid"></input>
<input id="trace">0|1	(optional)</input>
<input id="update">0|1 (optional - defaults to 0): set the shipping address, etc. in the cart to the new values.</input>

<hint>
in cart the following pieces of data must be set:
	data.ship_address
	data.ship_country
	data.ship_zip
	data.ship_state
</hint>
<example>
@methods = [
	[ id:, name:, carrier:, amount
	]
</example>

</API>

=cut

## NOTE: JT says this may not be necessary since 201311 -- need to check
sub cartShippingMethods {
	my ($self,$v) = @_;
	my %R = ();

	my $CART2 = undef;
	if ($v->{'_cartid'} eq '') {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9998,"_cartid parameter is required for $v->{'_cmd'} version > 201310");			
		}
	else {
		$CART2 = $self->cart2( $v->{'_cartid'} );
		if (not defined $CART2) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9997,sprintf('_cartid %s is invalid',$v->{'_cartid'}));
			}
		}

	require ZSHIP;
	if (not defined $v->{'update'}) { $v->{'update'} = 0; }

	if (&JSONAPI::hadError(\%R)) {
		}
	else {
		$R{'@methods'} = $CART2->shipmethods();
		}
	
	if ($v->{'trace'}) {	
		$R{'@trace'} = $CART2->msgs(); 
		}

	return(\%R);
	}











#################################################################################
##
##
##

=pod

<API id="cartItemsInventoryVerify">
<purpose></purpose>
<input id="_cartid"></input>
<input id="trace">0|1	(optional)</input>
<example>
%changes = [
	[ sku1: newqty, sku2:newqty ]
	]
</example>
</API>

=cut

sub cartItemsInventoryVerify {
	my ($self,$v) = @_;
	my %R = ();

	my $CART2 = undef;
	if ($v->{'_cartid'} eq '') {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9998,"_cartid parameter is required for $v->{'_cmd'} version > 201310");			
		}
	else {
		$CART2 = $self->cart2( $v->{'_cartid'} );
		}

	my ($resultref) = INVENTORY2->new($self->username())->verify_cart2($CART2,'%GREF'=>$self->globalref());
	$R{'%changes'} = $resultref;

	return(\%R);
	}









#################################################################################
##
##
##

=pod

<API id="adminPrivateSearch">
<purpose></purpose>
<input id="_cartid"></input>
<input id="type">order</input>
<input id="type">['order']</input>
<note>if not specified then: type:_all is assumed.</note>
<note>www.elasticsearch.org/guide/reference/query-dsl/</note>

<input id="mode">elastic-native</input>
<input hint="mode:elastic-native" id="filter"> { 'term':{ 'profile':'DEFAULT' } };</input>
<input hint="mode:elastic-native" id="filter"> { 'term':{ 'profile':['DEFAULT','OTHER'] } };	## invalid: a profile can only be one value and this would fail</input>
<input hint="mode:elastic-native" id="filter"> { 'or':{ 'filters':[ {'term':{'profile':'DEFAULT'}},{'term':{'profile':'OTHER'}}  ] } };</input>
<input hint="mode:elastic-native" id="filter"> { 'constant_score'=>{ 'filter':{'numeric_range':{'base_price':{"gte":"100","lt":"200"}}}};</input>
<input hint="mode:elastic-native" id="query"> {'text':{ 'profile':'DEFAULT' } };</input>
<input hint="mode:elastic-native" id="query"> {'text':{ 'profile':['DEFAULT','OTHER'] } }; ## this would succeed, </input>

<response id="size">100 # number of results</response>
<response id="sort">['_score','base_price','prod_name']</response>
<response id="from">100	# start from result # 100</response>
<response id="scroll">30s,1m,5m</response>

<note>
<![CDATA[
Filter is an exact match, whereas query is a token/substring match - filter is MUCH faster and should be used
when the exact value is known (ex: tags, profiles, upc, etc.)

<ul> KNOWN KEYS:

</ul>
]]>
</note>

<response id="@products">an array of product ids</response>
<response id="@LOG">an array of strings explaining how the search was performed (if LOG=1 or TRACEPID non-blank)</response>
<caution>
Using LOG=1 or TRACEPID in a product (non debug) environment will result in the search feature being
disabled on a site.
</caution>

</API>

=cut

sub adminPrivateSearch {
	my ($self,$v) = @_;

	my %R = ();

	if (not &JSONAPI::validate_required_parameter(\%R,$v,'mode',['elastic-native','elastic-searchbuilder'])) {
		}
	elsif ($v->{'mode'} =~ /^elastic-(native|searchbuilder)$/) {

		my ($es) = &ZOOVY::getElasticSearch($self->username());
		if (not defined $es) {
			&JSONAPI::append_msg_to_response(\%R,"iseerr",201,"elasticsearch object is not available");			
			}

		## whitelist parameters
		my %params = ();
		# index           => multi,
		# type            => multi,
		if (defined $v->{'type'}) { $params{'type'} = $v->{'type'}; }
		# $params{'type'} = ['product','sku'];

		$params{'index'} = sprintf("%s.private",lc($self->username()));
		if (defined $v->{'query'}) { $params{'body'}->{'query'} = $v->{'query'};	}
		if (defined $v->{'filter'}) {	$params{'body'}->{'filter'} = $v->{'filter'};	}

		## size            => $no_of_results
		if (defined $v->{'size'}) {	$params{'size'} = $v->{'size'};	}
		##  sort            => ['_score',$field_1]
		if (defined $v->{'sort'}) {	$params{'body'}->{'sort'} = $v->{'sort'};	}

# 		$v->{'scroll'} = '1m';
		if (defined $v->{'scroll'}) { 	$params{'scroll'} = $v->{'scroll'}; }
		if (defined $v->{'from'}) { 	$params{'from'} = $v->{'from'}; }
		if (defined $v->{'explain'}) { 	$params{'explain'} = $v->{'explain'}; }

		$params{'timeout'} = '5s';
		if (defined $params{'filter'}) {}
		elsif (defined $params{'query'}) {}
		else {
			&JSONAPI::append_msg_to_response(\%R,"apperr",18233,"search mode:$v->{'mode'} requires either query and/or filter parameter.");
			}

#		my $sb = ElasticSearch::SearchBuilder->new();
#		my $es_filter = $sb->filter("foo");
#		print Dumper($es_filter);
#		print Dumper(\%R);

		if (not &hadError(\%R)) {

			## try
			eval { %R = %{$es->search(%params)} };
			# open F, ">/tmp/foo";	print F Dumper(\%params,\%R);	close F;

		   if (not $@) {
				## yay, success!
				$R{'_count'} = scalar(@{$R{'hits'}->{'hits'}});
				#if ($R{'_count'}>0) {
				#	foreach my $hit (@{$R{'hits'}->{'hits'}}) {
				#		#$hit = $hit->{'_source'};
				#		#delete $hit->{'description'};
				#		#delete $hit->{'marketplaces'};
				#		#delete $hit->{'skus'};
				#		# $hit->{'prod_name'} = 'test';
				#		}
				#	}
				}
			elsif (ref($@) eq 'ElasticSearch::Error::Request') {
				my ($e) = $@;
				my $txt = $e->{'-text'};
				$txt =~ s/\[inet\[.*?\]\]//gs;	## remove: [inet[/192.168.2.35:9300]]
				&JSONAPI::append_msg_to_response(\%R,"apperr",18200,"search mode:$v->{'mode'} failed: ".$e->{'-text'});
			   }
			elsif (ref($@) eq 'ElasticSearch::Error::Missing') {
				&JSONAPI::append_msg_to_response(\%R,"iseerr",18202,sprintf("search mode:$v->{'mode'} %s",$@->{'-text'}));
				$R{'dump'} = Dumper($@);
				}
			else {
				&JSONAPI::append_msg_to_response(\%R,"iseerr",18201,"search mode:$v->{'mode'} failed with unknown error");
				$R{'dump'} = Dumper($@);
				}

			}

		}
	else {
		## NOTE: this line should NEVER be reached!
		&JSONAPI::append_msg_to_response(\%R,"iseerr",18234,"search mode, not supported.");	
		}

	return(\%R);
	}




#################################################################################
##
##
##

=pod

<API id="adminPartnerSet">
<purpose></purpose>
<input id="partner">EBAY</input>
<note>
<![CDATA[
Generic call to save data retrieved from partner return URL's, parameters vary.
]]>
</note>
</API>

<API id="adminPartnerGet">
<purpose></purpose>
<input id="partner">EBAY</input>
<note>
<![CDATA[
]]>
</note>
</API>

=cut

sub adminPartner {
	my ($self,$v) = @_;

	my %R = ();

	my $USERNAME = $self->username();
	my $MID = $self->mid();
	my $PRT = $self->prt();
	my ($udbh) = &DBINFO::db_user_connect($self->username());

	if (not &JSONAPI::validate_required_parameter(\%R,$v,'partner',['EBAY'])) {
		## wtf - no partner parameter
		}
	elsif (($v->{'_cmd'} eq 'adminPartnerGet') && ($v->{'partner'} eq 'EBAY')) {
		require EBAY2;
		my ($eb2) = EBAY2->new_for_auth($self->username(),$self->prt());
		&EBAY2::load_production();
		$R{'RuName'} = $EBAY2::runame;
		if ($R{'RuName'} eq '') {
			&JSONAPI::append_msg_to_response(\%R,"iseerr",18123,"Server has no eBay Developer License (RuName) installed");	
			}
			
		my $ref = $eb2->api("GetSessionID",{ RuName=>$EBAY2::runame },NO_TOKEN=>1,NO_DB=>1,xml=>3);
		$R{'SessionID'} = $ref->{'.'}->{'SessionID'}->[0];
		}
	elsif (($v->{'_cmd'} eq 'adminPartnerSet') && ($v->{'partner'} eq 'EBAY')) {
		my $REC_ID = 0;
		my $tkn = $v->{'ebaytkn'};
		my $tknexp = $v->{'tknexp'};

		my $SessionID = $v->{'SessionID'};
		my $RuName = $v->{'RuName'};
		if (($SessionID ne '') && ($RuName ne '')) {
			# CwQAAA**33eb97ea1420a2a6c3f57915fffff243
			require EBAY2;
			my ($eb2) = EBAY2->new_for_auth($self->username(),$self->prt());
			&EBAY2::load_production();
			my ($ref) = $eb2->api("FetchToken",{ "SessionID"=>$SessionID }, NO_TOKEN=>1,NO_DB=>1,xml=>3);
			if ($ref->{'.'}->{'Errors'}) {
				foreach my $err (@{$ref->{'.'}->{'Errors'}}) {
					my $errid = $err->{'ErrorCode'}->[0];
					my $errmsg = $err->{'LongMessage'}->[0];
					&JSONAPI::set_error(\%R,'apierr',83829,sprintf("eBay error[%d] %s",$errid,$errmsg));
					}
				}
			elsif ($ref->{'.'}->{'eBayAuthToken'}->[0]) {
				$tkn = $ref->{'.'}->{'eBayAuthToken'}->[0];
				$tknexp = $ref->{'.'}->{'HardExpirationTime'}->[0];
				}
			else {
				&JSONAPI::set_error(\%R,'apierr',89382,"eBay send invalid response from FetchToken, not sure what to do");
				}
			}

		my $sb = 0;
		if (not &JSONAPI::hadError(\%R)) {
			my $pstmt = "select ID,EBAY_EIAS from EBAY_TOKENS where MID=$MID /* ".$udbh->quote($USERNAME)." */";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my ($ID,$EIAS) = $sth->fetchrow() ) {
				my $pstmt = "delete from EBAY_TOKENS where MID=$MID /* $USERNAME */ and ID=$ID limit 1";
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
		
				## clear out any store categories.	
				$pstmt = "delete from EBAYSTORE_CATEGORIES where MID=$MID /* $USERNAME */ and EIAS=".$udbh->quote($EIAS);
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);	
				}
			$sth->finish();

			## clear out any tokens on this partition.
			$pstmt = "delete from EBAY_TOKENS where MID=$MID /* $USERNAME */ and PRT=$PRT";
			&JSONAPI::dbh_do(\%R,$udbh,$pstmt);

			$sb = $v->{'sb'};
			if (not defined $sb) { $sb = 0; } else { $sb = int($sb); }
	
			my $is_epu = 0;
			#my ($flags) = &ZOOVY::RETURN_CUSTOMER_FLAGS($USERNAME);
			#if ($flags =~ /,EPU,/) { $is_epu++; }
	
			## now insert the new TOKEN
			if ($REC_ID==0) {
				$pstmt = &DBINFO::insert($udbh,'EBAY_TOKENS',{
					MID=>$MID,
					PRT=>$PRT,
					USERNAME=>$USERNAME,
					EBAY_USERNAME=>"UNKNOWN_".time(),
					IS_SANDBOX=>$sb,
					IS_EPU=>$is_epu,
					EBAY_TOKEN=>$tkn,
					'*EBAY_TOKEN_EXP'=>'date_add(now(),interval 12 month)',
					GALLERY_POLL_INTERVAL=>300,
					GALLERY_NEXT_POLL_GMT=>$^T,
					GALLERY_VARS=>'',
					},debug=>1+2);
				print STDERR $pstmt."\n";
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
		
				$pstmt = "select last_insert_id()";
				($REC_ID) = $udbh->selectrow_array($pstmt);
				}
			}

		my $EIAS = undef;
		my %hash = ();
		my ($hasStore,$USERID) = (0,'');
		if ($REC_ID>0) {
			## now we verify the eBay Username
			$hash{'#Site'} = 0;
			$hash{'DetailLevel'} = 'ReturnAll';
	
			require EBAY2;
			my ($eb2) = EBAY2->new($USERNAME,PRT=>$PRT);
			my ($r) = $eb2->api('GetUser',\%hash,preservekeys=>['User'],xml=>3);
			my $info = &ZTOOLKIT::XMLUTIL::SXMLflatten($r->{"."});
			$hasStore = ($info->{'.User.SellerInfo.StoreOwner'} eq 'true')?1:0;
			$EIAS = $info->{'.User.EIASToken'};

			$USERID = $info->{'.User.UserID'};
			if (($REC_ID>0) && ($USERID ne '')) {
				my $qtEIAS = $udbh->quote($info->{'.User.EIASToken'});
				my $qtSUBSCRIPTION = $udbh->quote($info->{'.User.UserSubscription'}?$info->{'.User.UserSubscription'}:'');
				my $qtFEEDBACK = int($info->{'.User.FeedbackScore'});
				my $qtEBAYUSERID = $udbh->quote($info->{'.User.UserID'});
				my $pstmt = "update EBAY_TOKENS set EBAY_USERNAME=$qtEBAYUSERID,EBAY_FEEDBACKSCORE=$qtFEEDBACK,EBAY_EIAS=$qtEIAS,EBAY_SUBSCRIPTION=$qtSUBSCRIPTION,HAS_STORE=$hasStore,EBAY_USERNAME=".$udbh->quote($USERID)." where ID=$REC_ID and MID=$MID";
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
	
				## remove any duplicate tokens that might be left over.
				$pstmt = "delete from EBAY_TOKENS where EBAY_EIAS=$qtEIAS and ID!=$REC_ID";
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
				}

			$self->accesslog("SETUP.EBAY","Token Updated! prt=$PRT","SAVE");
			&JSONAPI::append_msg_to_response(\%R,'success',0);

			## store the ebay username in all the important fields		
			#my ($epnsref) = &EBAY2::PROFILE::fetch($USERNAME,$PRT,$CODE);
			#$epnsref->{'ebay:username'} = $USERID;
			#$epnsref->{'ebaystores:username'} = $USERID;
			#$epnsref->{'ebaymotor:username'} = $USERID;
			#&EBAY2::PROFILE::store($USERNAME,$PRT,$CODE,$epnsref);
			#&JSONAPI::append_msg_to_response(\%R,'success',0);			
			}

		## validate sandbox users!
		if (($REC_ID>0) && ($sb)) {
			%hash = ();
			$hash{'FeedbackScore'} = 1000;
			my ($eb2) = EBAY2->new($USERNAME,PRT=>$PRT);
			my ($r) = $eb2->api('ValidateTestUserRegistration',\%hash);
			}
		
		if	($REC_ID==-1) {
			&JSONAPI::append_msg_to_response(\%R,"iseerr",18234,"eBay token Failure.");				
			}
		elsif ($hasStore) { 
			require EBAY2::STORE;
			my ($count) = &EBAY2::STORE::rebuild_categories($USERNAME,$EIAS);
			&JSONAPI::append_msg_to_response(\%R,'success',0,"eBay Store Categories were updated");
			}	

		}
	else {
		## NOTE: this line should NEVER be reached! (since we validated the list of parameters earlier)
		&JSONAPI::append_msg_to_response(\%R,"iseerr",18201,"unknown cmd/partner");
		}

	&DBINFO::db_user_close();
	return(\%R);
	}








#################################################################################
##
## cartCreateOrder (you mean cartOrderCreate)

=pod

<API id="adminOrderCreate">
<purpose></purpose>
<input id="_cartid"></input>
<input id="@PAYMENTS">
@PAYMENTS : [
  'insert?ID=xyz&TN=credit',
  'insert?ID=xyz&TN=credit'
]
</input>
<response id="orderid"> 2011-01-1234</response>
<response id="payment"> </response>
</API>

<API id="cartOrderCreate">
<purpose></purpose>
<input id="_cartid"></input>
<response id="iama"> some string that makes sense to you</response>
<response id="orderid"> 2011-01-1234</response>
<response id="payment"> </response>
</API>

<API id="cartOrderStatus">
<purpose></purpose>
<input id="cartid"></input>
<input id="orderid"></input>
<response id="orderid"> 2011-01-1234</response>
<response id="payment"> </response>
</API>

=cut

sub cartOrder {
	my ($self,$v) = @_;

	my %R = ();
	$R{'version'} = $self->apiversion();

	my %payment = ();
	## populate %payment 
 	##ex : "chkout.payby":"CREDIT","payment.cc":"4111111111111111","payment.mm":"1","payment.yy":"2013","payment.cv":"123",

	my $redis = &ZOOVY::getRedis($self->username(),0);
	my $UUID = $v->{'_uuid'};
	my $CART2 = undef;
	my ($CARTID,$OID) = (undef,undef);

	if ($v->{'_cartid'} eq '') {
		&JSONAPI::set_error(\%R,9998,'apperr',"_cartid parameter is required for $v->{'_cmd'} version > 201310");			
		}
	elsif ($v->{'_cartid'} =~ /^(.*?)\$\$(.*?)$/) {
		## reallylongcartid$$orderid
		($CARTID,$OID) = ($1,$2);
		$CART2 = CART2->new_from_oid($self->username(),$OID,'create'=>0);

		## NOTE: this line is bad, because we're dealing with an ORDER
		## $CART2->make_readonly();		

		if (not defined $CART2) {
			}
		elsif ($CART2->cartid() ne $CARTID) {
			$CART2 = undef;
			&JSONAPI::set_error(\%R,'iseerr',9997,sprintf("requested cart/order \"%s\" is not valid.",$v->{'_cartid'}));
			}
		}
	else {
		$CART2 = $self->cart2( $v->{'_cartid'} );
		$CARTID = $CART2->cartid();
		if ($v->{'iama'}) {
			## used by cartOrderCreate
			$CART2->add_history(sprintf("%s\@%s: %s",$self->clientid(),$self->apiversion(),$v->{'iama'}));
			}
		}

	my $REDIS_ASYNC_KEY = sprintf("FINALIZE.%s.CART.%s",$self->username(), $CARTID );
	print STDERR "REDIS_ASYNC_KEY: $REDIS_ASYNC_KEY\n";

	## SITE::URL is required for SITE::EMAIL ->sendmail
	my $webdbref = $self->webdb();
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'_cmd'} eq 'cartOrderCreate') {
		if ((not defined $webdbref->{'chkout_deny_ship_po'}) || ($webdbref->{'chkout_deny_ship_po'}==0)) {
			## po boxes are no problem
			}
		elsif ($CART2->is_pobox()>0) {
			# only check pobox address on shipping (not billing)
			&JSONAPI::set_error(\%R,'youerr',9996,'Shipping to PO boxes not allowed by business rules.');
			}

		if ($webdbref->{'banned'} ne '') {
			## BANNED LIST
			my $banned = 0;
			foreach my $line (split(/[\n\r]+/,$webdbref->{'banned'})) {
				my ($type,$match,$ts) = split(/\|/,$line);
				$match = quotemeta($match);
				$match =~ s/\\\*/.*/g; 
				if (($type eq 'IP') && ($ENV{'REMOTE_ADDR'} =~ /^$match$/)) { $banned++; }
				elsif (($type eq 'EMAIL') && ($CART2->in_get('bill/email') =~ /^$match$/i)) { $banned++; }
				elsif (($type eq 'ZIP') && ($CART2->in_get('ship/postal') =~ /^$match$/)) { $banned++; }
				elsif (($type eq 'ZIP') && ($CART2->in_get('bill/postal') =~ /^$match$/)) { $banned++; }
				}
			if ($banned) {
				&JSONAPI::set_error(\%R,'youerr',9995,'Order blocked by store settings - cannot process (this is not an error).');
				}
			}
		}


	print STDERR 'v: '.Dumper($v);


	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ((defined $v->{'@PAYMENTS'}) && (ref($v->{'@PAYMENTS'}) eq 'ARRAY')) {
		## we're setting payments passed into the cart
		#@PAYMENTS : [
		#  'insert?ID=xyz&TN=credit',
 		# 'insert?ID=xyz&TN=credit'
		# ]
		my @CMDS = ();
		&JSONAPI::parse_macros($self,$v->{'@PAYMENTS'},\@CMDS);

		print STDERR '@CMDS: '.Dumper(\@CMDS)."\n";
		foreach my $CMDSET (@CMDS) {
			my ($VERB, $pref) = @{$CMDSET};
			$VERB = lc($VERB);
			$self->paymentQCMD(\%R,$VERB,$pref);
			}
		$CART2->{'@PAYMENTQ'} = $self->paymentQ();
		delete $v->{'@PAYMENTS'};
		}


	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'_cmd'} eq 'cartOrderCreate') {
		if (scalar(@{$self->paymentQ()})==0) {
			&JSONAPI::set_error(\%R,'yourerr',9994,'No payments, cannot process order');
			}
		}

	print STDERR "RESPONSE: ".Dumper($CART2->{'@PAYMENTQ'},\%R);

	##
	## request processing starts here
	##
	my ($LM) = LISTING::MSGS->new( $self->username() );
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'_cmd'} eq 'cartOrderStatus') {
		## 
		$redis->append($REDIS_ASYNC_KEY,sprintf("\nPOLLED|%s",time()));

		$R{'@MSGS'} = [];
		my ($redis) = &ZOOVY::getRedis($self->username(),0);
		$R{'finished'} = 0;
		my ($POLLED_COUNT) = 0;
		my ($FINISHED) = 0;
		foreach my $line (split(/[\n]+/,$redis->get($REDIS_ASYNC_KEY))) {
			print STDERR "$REDIS_ASYNC_KEY: $line\n";
			my %MSG = ();
			($MSG{'_'},$MSG{'+'}) = split(/\|/,$line,2);

			if ($MSG{'_'} eq 'POLLED') { $POLLED_COUNT++; }
			next if ($MSG{'_'} eq 'POLLED');
			if ($MSG{'_'} =~ /^SPOOLER\*(.*?)$/) {
				## we'll pass out SPOOLER*SUCCESS or SPOOLER*FAILURE messages and treat them as if we had done them
				$LM->pooshmsg("$1|$MSG{'+'}");
				}

			if ($MSG{'_'} eq 'SPOOLER*FINISHED') { $R{'finished'} = int($MSG{'+'}); }
			if ($MSG{'_'} eq 'FINISHED') { $R{'finished'} = int($MSG{'+'}); }

			if (substr($MSG{'+'},0,1) eq '+') { $MSG{'+'} = substr($MSG{'+'},1); }
			push @{$R{'@MSGS'}}, \%MSG;
			}


		if ((defined $CART2) && ($R{'finished'})) {
			$R{'payment_status'} = $CART2->payment_status();
			$R{'orderid'} = $CART2->oid();
			$R{'finished'} = $R{'finished'};
			$LM->pooshmsg("SUCCESS|+Finished $OID");
			$redis->append($REDIS_ASYNC_KEY,sprintf("\nWIN|cart2 exists, polls[%d].",$POLLED_COUNT));
			}
		elsif ($LM->had(['ERROR'])) {
			$R{'payment_status'} = '911';
			$R{'orderid'} = $OID;
			$R{'finished'} = time();
			$LM->pooshmsg("FAILURE|+Detected spooler error");
			$redis->append($REDIS_ASYNC_KEY,sprintf("\nERROR|max polling [%d] was reached.",$POLLED_COUNT));
			}
		elsif ($POLLED_COUNT>500) {
			## a failsafe to stop polling.
			$R{'payment_status'} = '911';
			$R{'orderid'} = $OID;
			$R{'finished'} = time();
			$LM->pooshmsg("FAILURE|+Max polling reached.");
			$redis->append($REDIS_ASYNC_KEY,sprintf("\nERROR|max polling [%d] was reached.",$POLLED_COUNT));
			## 
			## &JSONAPI::set_error(\%R,'apierr',911,'max polling was reached - order status is unknown');
			}

		$R{'status-cartid'} = $v->{'_cartid'};		## jt needs this to make his code easy.

		#if ((not &JSONAPI::hadError(\%R)) && (defined $CART2) && ($CART2->cartid() ne '')) {
		#	## this will prevent it from saving within this session! (very important)
		#	$CART2->make_readonly();		
		#	delete $self->{'%CARTS'}->{ $CART2->cartid() };
		#	}
		print STDERR 'CARTORDERSTATUS: '.Dumper(\%R,$LM)."\n";
		}
	elsif (($v->{'async'}) && (not $self->is_spooler())) {
		##
		## ASYNC CHECKOUT (WILL QUEUE TO SPOOLER)
		##
		$R{'async'} = $v->{'async'};
		$CART2->in_set('want/payby','PAYMENTQ');
		my %SERIAL = ();
		$SERIAL{'USERNAME'} = $self->username();
		$SERIAL{'LUSER'}  = $self->luser();
		$SERIAL{'APIVERSION'} = $self->apiversion();
		$SERIAL{'SESSION'} = $self->session();
		$SERIAL{'CLIENTID'} = $self->clientid();
		$SERIAL{'DEVICEID'} = $self->deviceid();
		$SERIAL{'DOMAIN'} = $self->domain();
		$SERIAL{'PRT'} = $self->prt();
		$SERIAL{'ASYNC'} = $v->{'async'};
		$SERIAL{'REDIS_ASYNC_KEY'} = $REDIS_ASYNC_KEY;
		$SERIAL{'json:@PAYMENTQ'} = JSON::XS->new->ascii->pretty->allow_nonref->encode($self->paymentQ());
		print STDERR "json:PAYMENTQ: ".$SERIAL{'json:@PAYMENTQ'}."\n";

		my $EREFID = '';
		if ((not defined $EREFID) || ($EREFID eq '')) { $EREFID = $CART2->in_get('mkt/erefid'); }
		if ((not defined $EREFID) || ($EREFID eq '')) { $EREFID = $CART2->in_get('want/erefid'); }
		if ((not defined $EREFID) || ($EREFID eq '')) { $EREFID = $CART2->cartid(); }

		$R{'previous-cartid'} = $CARTID;
		my ($OID) = &CART2::next_id($self->username(),0,$EREFID);
		$CART2->in_set('our/orderid',$OID);	
		$R{'orderid'} = $OID;
		$R{'status-cartid'} = sprintf("%s\$\$%s",$CARTID,$OID);	## this is the key that tells JT everything is gonna be fine.
		
		$v->{'*CART2'} = $CART2;
		$SERIAL{'body'} = JSON::XS->new->ascii->pretty->allow_nonref->convert_blessed->encode($v);

		if ($redis->append($REDIS_ASYNC_KEY,sprintf("\nSTART|%d\nORDERID|%s",time(),$OID))>0) {
			## the line below apparently has zero effect (contrary to the docs)
 			## $SERIAL{'spooler'} = '/dev/shm/spooler';
			## we should probably test permissions here!
			## at, priority

			try {
				#require Net::uwsgi;
				#Net::uwsgi::uwsgi_spool('/var/run/uwsgi-spooler.sock',\%SERIAL);
				uwsgi::spool(\%SERIAL);
				$redis->append($REDIS_ASYNC_KEY,sprintf("\nSPOOLED"));
				}
			catch {
				&JSONAPI::append_msg_to_response(\%R,"iseerr",212,"spooler error - $_");
				$redis->append($REDIS_ASYNC_KEY,sprintf("\nSPOOLER-ERROR|$_"));
				}
			finally {
				if (not @_) {
					&JSONAPI::append_msg_to_response(\%R,"processing",200,"request is processing");
					}	
				};
			}
		else {
			$redis->append($REDIS_ASYNC_KEY,sprintf("\n***DID-NOT-SPOOL***"));
			}

		## we need this to save here.
		#if (not &JSONAPI::hadError(\%R)) {
		#	$CART2->make_readonly();		## this will prevent it from saving within this session! (very important)
		#	delete $self->{'%CARTS'}->{$CARTID};
		#	}

		$R{'finished'} = 0;
		}
	elsif ($self->is_spooler()) {
		##
		## SPOOLER PROCESSING
		##

		print STDERR 'paymentQ: '.Dumper($self->paymentQ());

		if ($OID eq '') { $OID = $CART2->in_get('our/orderid'); }
		$redis->append($REDIS_ASYNC_KEY,sprintf("\nSPOOLER*START|%s.%s.%s",time(),$OID,$CART2->is_readonly()));
		$CART2->in_set('want/payby','PAYMENTQ');

		##
		## TODO: we should add some reasonable checking for duplicate orderid's here
		## 
		my $CARTID = $CART2->cartid();
		($LM) = $CART2->finalize_order( 
			'*LM'=>$LM, 
			'our_orderid'=>$OID,
			'app'=>sprintf("SPOOLER %s",$self->apiversion()), 
			'domain'=>$self->domain(),
			'R_A_K'=>$REDIS_ASYNC_KEY,
			'skip_oid_creation'=>($OID?1:0),
			);		
		foreach my $msg (@{$LM->msgs()}) {
			my ($ref,$status) = LISTING::MSGS::msg_to_disposition($msg);
			next if ($ref->{'_'} eq 'INFO');
			$redis->append($REDIS_ASYNC_KEY,sprintf("\nSPOOLER*%s|%s",$ref->{'_'},$ref->{'+'}));
			}

		$redis->append($REDIS_ASYNC_KEY,sprintf("\nSPOOLER*FINISHED|%s",time()));
		delete $self->{'%CARTS'}->{$CARTID};

		$CART2->reset_session("CHECKOUT");
		## END SPOOLER PROCESSING
		}
	elsif ($self->apiversion()>201402) {	
		&JSONAPI::set_error(\%R,'apperr',9293,'versions 201403 and later require async=1 flag');
		}
	else {
		## a conventional, non-async, non-spooler checkout
		$CART2->in_set('want/payby','PAYMENTQ');
		($LM) = $CART2->finalize_order( 
			'*LM'=>$LM, 
			'app'=>sprintf("JSONAPI %s",$self->apiversion()), 
			'domain'=>$v->{'domain'},
			'R_A_K'=>$REDIS_ASYNC_KEY,
			);

		my ($BLAST) = BLAST->new($self->username(),$self->prt());
		my ($TLC) = TLC->new('username'=>$self->username());
		$R{'payment_status_msg'} = $BLAST->macros()->{'%PAYINFO%'} || "%PAYINFO% macro";
		$R{'payment_status_msg'} = $TLC->render_html($R{'payment_status_msg'}, { '%ORDER'=>$CART2->jsonify() });
		$R{'payment_status_detail'} = $BLAST->macros()->{'%PAYINSTRUCTIONS%'} || "%PAYINSTRUCTIONS% macro";
		$R{'payment_status_detail'} = $TLC->render_html($R{'payment_status_detail'}, { '%ORDER'=>$CART2->jsonify() });
		$R{'finished'} = time();

		$R{'orderid'} = $CART2->oid();
		$R{'payment_status'} = $CART2->payment_status();
		}

	##
	## now output trackers (if appropriate)
	##
	my $DISPLAY_TRACKERS = 0;
	$DISPLAY_TRACKERS |= ($self->webdb()->{'chkout_roi_display'}) ?1:0;
	$DISPLAY_TRACKERS |= ($LM->has_win())?2:0;

	if (($v->{'async'}) || (not $R{'finished'}) || ($self->is_spooler())) {
		}
	elsif (&JSONAPI::hadError(\%R)) {
		}
	elsif (not $R{'finished'}) {
		## don't display trackers till we're finished
		}
	elsif ($self->apiversion() >= 201338) {
		$R{'@TRACKERS'} = [];
		if (not $DISPLAY_TRACKERS) {
			push @{$R{'@TRACKERS'}}, { owner=>'nobody', 'script'=>'<!-- TRACKERS NOT OUTPUT DUE TO DISPLAY SETTING -->' };
			}
		elsif ($DISPLAY_TRACKERS) {
			foreach my $trackset (@{$self->_SITE()->conversion_trackers_as_array($CART2)}) {
				my ($trackid, $trackhtml) = @{$trackset};
				push @{$R{'@TRACKERS'}}, { owner=>$trackid, script=>$trackhtml };
				}
			}
		$redis->append($REDIS_ASYNC_KEY,sprintf("\nTRACKERS|%s.%d",time(),$R{'finished'}));
		}
	else {
		## on successfully paid, the output all the tracking codes.
		if ($DISPLAY_TRACKERS) {
			$R{'html:roi'} = $self->_SITE()->conversion_trackers($CART2);
			}
		else {
			$R{'html:roi'} = '<!-- TRACKERS NOT OUTPUT DUE TO PAYMENT STATUS -->';
			}
		}

	##
	##
	##
	if ($v->{'_cmd'} eq 'cartOrderStatus') {
		## an entirely different way of handling responses!
		if (not $R{'finished'}) {
			}
		elsif ((not defined $CART2) || (ref($CART2) ne 'CART2')) {
			$redis->append($REDIS_ASYNC_KEY,"\nERROR|CART2 is not defined");
			}
		else {
			my ($BLAST) = BLAST->new($self->username(),$self->prt());
			my ($TLC) = TLC->new('username'=>$self->username());
			$R{'payment_status_msg'} = $BLAST->macros()->{'%PAYINFO%'} || "%PAYINFO% macro";
			$R{'payment_status_msg'} = $TLC->render_html($R{'payment_status_msg'}, { '%ORDER'=>$CART2->jsonify() });
			$R{'payment_status_detail'} = $BLAST->macros()->{'%PAYINSTRUCTIONS%'} || "%PAYINSTRUCTIONS% macro";
			$R{'payment_status_detail'} = $TLC->render_html($R{'payment_status_detail'}, { '%ORDER'=>$CART2->jsonify() });

			$R{'order'} = $CART2->make_readonly()->make_public()->jsonify();
			}
		}
	elsif ($v->{'async'}) {
		## an entirely different way of handling responses!
		}
	elsif ($self->apiversion()>201402) {
		## ALL OLD NON-ASYNC CHECKOUT METHODS	
		$CART2->empty(0xFF); 
		}
	elsif ($LM->has_win()) {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		$R{'order'} = $CART2->make_public()->jsonify();
		$CART2->empty(0xFF); 
		}
	elsif (my $iseref = $LM->had(['ISE'])) {
		&JSONAPI::set_error(\%R,"apierr",200,$iseref->{'+'});
		if ($iseref->{'OID'}) { 
			$CART2->empty(0xFF); 
			if ($v->{'_cmd'} eq 'cartOrderCreate') { &JSONAPI::append_msg_to_response(\%R,'success',0); }
			}
		}
	elsif (my $appref = $LM->had(['ERROR'])) {
		&JSONAPI::set_error(\%R,"apperr",201,$appref->{'+'});
		}
	elsif ($appref = $LM->had(['STOP'])) {
		&JSONAPI::set_error(\%R,"youerr",501,$appref->{'+'});
		}
	else {
		my @OUTPUT = ();
		foreach my $msg (@{$LM->msgs()}) {
			my ($ref,$status) = LISTING::MSGS::msg_to_disposition($msg);
			next if ($ref->{'_'} eq 'INFO');
			push @OUTPUT, sprintf("%s[%s] ",$ref->{'_'},$ref->{'+'});
			}
		&JSONAPI::set_error(\%R,"apierr",202,"UNHANDLED ERROR(s): ".join(";",@OUTPUT));
		}

	return(\%R);
	}




#################################################################################
##
##
##

=pod

<API id="cartCheckoutValidate">
<purpose></purpose>
<input id="_cartid"></input>
<input id="sender"> stage (LOGIN,BILLING_LOCATION,SHIPPING_LOCATION,ORDER_CONFIRMATION,ADMIN)</input>
<response id="@issues"></response>
</API>


=cut

sub cartCheckoutValidate { 
	my ($self,$v) = @_;
	my %R = ();

	&JSONAPI::append_msg_to_response(\%R,'success',0);		
	return(\%R);
	}









#################################################################################
##
##
##

=pod

<API id="appNewsletterList">
<purpose>shows all publically available newsletters/lists</purpose>
</API>

<API id="adminNewsletterList">
<purpose>see appNewsletterList, unlike public call also show hidden and not provisioned newsletters</purpose>
</API>

=cut

sub appNewsletterList {
	my ($self,$v) = @_;
	my %R = ();

	## ADDITION of SUBSCRIPTION LISTS
	require CUSTOMER::NEWSLETTER;
	## fetch TARGETED (mode=2) lists
	my (@lists) = CUSTOMER::NEWSLETTER::fetch_newsletter_detail($self->username(),$self->prt());
	if ((scalar @lists)==0) {
		@lists = (  { NAME=>'General', MODE=>1, ID=>1 } );
		}
	
	my $ONLY_VALID = 1;
	if ($v->{'_cmd'} eq 'adminNewsletterList') { $ONLY_VALID = 0; }

	my $list_count = 0;
	my @available_lists = ();
	foreach my $list (@lists) {
		$list->{'NAME'} =~ s/\n//;
		next if ($ONLY_VALID && $list->{'NAME'} eq '');
		next if ($ONLY_VALID && $list->{'MODE'} == 0);		# skip exclusive newsletters.
		push @available_lists, $list;
		}
	$R{'@lists'} = \@available_lists;

	return(\%R);
	}




#################################################################################
##
##
##
#
#=pod
#
#<API id="buyerNewsletters">
#<purpose></purpose>
#<input id="_cartid"></input>
#<input id="login"> email address</input>
#<input id="fullname"> (optional)</input>
#<input id="newsletter-1"> 1/0</input>
#<input id="newsletter-2"> 1/0</input>
#<caution>
#Displays a list of newsletters the customer is/isn't subscribed to.
#</caution>
#
#</API>
#
#=cut
#
#sub buyerNewsletters {
#	my ($self,$v) = @_;
#	my %R = ();
#
#
#	my $login = $v->{'login'};
#	if ($login eq '') {
#		&JSONAPI::append_msg_to_response(\%R,"apperr",2600,"No Login provided.");
#		}
#
#	my $fullname = $v->{'fullname'};
#	my $IP = $ENV{'REMOTE_ADDR'};
#
#	if (not &JSONAPI::hadError(\%R)) {
#		my $SUBSCRIPTIONS = 0;
#		for my $i (0..15) {
#			if ($v->{sprintf("newsletter-%d",$i+1)}) { $SUBSCRIPTIONS += (1<<$i); }
#			}
#		my ($err,$message) = &CUSTOMER::new_subscriber($self->username(), $self->prt(), $login, $fullname, $IP, 3, $SUBSCRIPTIONS);
#		if ($err) {
#			&JSONAPI::append_msg_to_response(\%R,"youerr",2600,"$message");
#			}
#		}
#
#
#	if (&JSONAPI::hadError(\%R)) {
#		## shit happened!
#		}
#	else {
#		&JSONAPI::append_msg_to_response(\%R,'success',0);		
#		}
#	
#	return(\%R);
#	}






#################################################################################
##
##
##

=pod

<API id="getMerchandising">
<purpose></purpose>
<input id="_cartid"></input>
<input optional="1" id="category"> .some.path|.some.other.path</input>
<input optional="1" id="tags"> x|y|z</input>
<input optional="1" id="keywords">	word1|word2|word3</input>

<example>
	@ELEMENTS = [
		{ id=>'xyz', trigger=>'category:.some.path', format=>'image', .. element specific data .. },
	];
</example>


myControl.registerMerchandizerificURL("/jsonapi", formatResponseFunction); 
myControl.registerMerchandizerificURL("putContentHereElement", "http://domain.com/someurl/handler",
	["keywords","/xyz*/"], 
	"targetElement");
myControl.registerMerchandizerific(function {},"category","/.*?/");
myControl.registerMerchandizerific("/","category","/accessories\..*?/");



</API>

=cut

sub getMerchandising {
	my ($self,$v) = @_;
	my %R = ();

	my @ELEMENTS = ();

	if ($v->{'category'}) {
		}

#
	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
	
	return(\%R);
	}



#################################################################################
##
##
##

=pod

<API id="buyerPurchaseHistory">
<purpose></purpose>
<input id="_cartid"></input>
<input optional="1" id="POOL"> RECENT,COMPLETED, etc.</input>
<input optional="1" id="TS"> modified timestamp from</input>
<input optional="1" id="CREATED_GMT"> created since ts</input>
<input optional="1" id="CREATEDTILL_GMT"> created since ts</input>
<input optional="1" id="PAID_GMT"> paid since</input>
<input optional="1" id="PAIDTILL_GMT"> paid until ts</input>
<input optional="1" id="PAYMENT_STATUS"> </input>
<input optional="1" id="PAYMENT_METHOD"> tender type (ex: CREDIT)</input>
<input optional="1" id="SDOMAIN"> </input>
<input optional="1" id="MKT">  a report by market (use bitwise value)</input>
<input optional="1" id="EREFID"> </input>
<input optional="1" id="LIMIT"> max record sreturns</input>
<input optional="1" id="CUSTOMER">  the cid of a particular buyer.</input>
<input optional="1" id="DETAIL">  1 - minimal (orderid + modified)
         3 - all of 1 + created, pool
			5 - full detail
         0xFF - just return objects
</input>

<caution>
This can ONLY be used for authenticated buyers.
</caution>

</API>

=cut

sub buyerPurchaseHistory {
	my ($self,$v) = @_;
	my %R = ();

	if (not $self->isLoggedIn(\%R,$v)) {
		## handles it's own errors
		}

	if (defined $v->{'CUSTOMER'}) {
		&JSONAPI::append_msg_to_response(\%R,"apperr",2600,"CUSTOMER is not a valid parameter");
		}

	my $IP = $ENV{'REMOTE_ADDR'};

	my $CID = 0;
	if (not &JSONAPI::hadError(\%R)) {
		($CID) = $self->customer()->cid();
		}

	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	elsif ($CID>0) {
		require ORDER::BATCH;
		my ($r) = ORDER::BATCH::report($self->username(),CUSTOMER=>$CID,%{$v});
		$R{'count'} = scalar(@{$r});
		$R{'@orders'} = $r;
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,"iseerr",2601,"Internal logic error, no CID not caught earlier");
		}

	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
	
	return(\%R);
	}




#################################################################################
##
##
##

=pod

<API id="buyerPurchaseHistoryDetail">
<purpose></purpose>
<input id="_cartid"></input>
<input id="orderid"></input>
<caution>
This can ONLY be used for authenticated buyers.
</caution>

</API>

=cut

sub buyerPurchaseHistoryDetail {
	my ($self,$v) = @_;
	my %R = ();

	if (not defined $v->{'orderid'}) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9001,'orderid is a required parameter');
		}
	elsif (not $self->isLoggedIn(\%R,$v)) {
		## handles it's own errors
		}

	my $IP = $ENV{'REMOTE_ADDR'};

	my $O2 = undef;
	if (&JSONAPI::hadError(\%R)) {
		}
	else {
		($O2) = CART2->new_from_oid($self->username(),$v->{'orderid'},new=>0);
		}

	if (not defined $O2) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9001,'orderid is not valid/could not lookup order');
		}
	else {
		%R = %{$O2->make_public()->jsonify()};
		}

	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
	
	return(\%R);
	}




#################################################################################
##
##
##

=pod

<API id="appFAQs">
<purpose></purpose>
<input id="_cartid"></input>
<input optional="1" id="filter-keywords"> keywords</input>
<input optional="1" id="filter-topic"> id</input>
<input optional="1" hint="default:all" id="method"> topics|detail|all</input>
<response hint="method:topics|all" id="@topics"> an array of faq topics</response>
<response hint="method:detail|all" id="@detail"> an array of detail faq data for topics</response>
</API>

=cut

sub appFAQs {
	my ($self,$v) = @_;
	my %R = ();

	require SITE::FAQS;
	my ($faqs) = SITE::FAQS->new($self->username(),$self->prt());
	
	if (defined $v->{'filter-keywords'}) {
		$faqs->restrict('KEYWORDS'=>$v->{'filter-keywords'});
		}
	if (defined $v->{'filter-topic'}) {
		$faqs->restrict('TOPIC_ID'=>$v->{'filter-topic'});
		}

	if (not defined $v->{'method'}) {
		$v->{'method'} = 'all';
		}

	if (not &JSONAPI::validate_required_parameter(\%R,$v,'method',['topics','detail','all'])) {
		## no method specified.
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (($v->{'method'} eq 'topics') || ($v->{'method'} eq 'all')) {
		my ($topicsar) = $faqs->list_topics();
		foreach my $topic (@{$topicsar}) {
			## iterate through each topic, add 
			$topic->{'TOPIC_ID'} = $topic->{'ID'};
			delete $topic->{'ID'};
			$topic->{'TOPIC_TITLE'} = $topic->{'TITLE'};
			delete $topic->{'TITLE'};
			}
		$R{'@topics'} = $topicsar;
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (($v->{'method'} eq 'detail') || ($v->{'method'} eq 'all')) {
		my ($faqsref) = $faqs->list_faqs();
		$R{'@detail'} = $faqsref;
		}

#	print STDERR Dumper($v,\%R);

	return(\%R);
	}



#################################################################################
##
##
##

=pod

<API id="appSendMessage">
<purpose></purpose>
<input id="_cartid"></input>
<input id="msgtype"> feedback</input>
<input id="sender"> user@domain.com   [the sender of the message]</input>
<input id="subject"> subject of the message</input>
<input id="body"> body of the message</input>
<input optional="1" id="PRODUCT">product-id-this-tellafriend-is-about</input>
<input optional="1" id="OID">2012-01-1234  [the order this feedback is about]</input>
<note>
msgtype:feedback requires 'sender', but ignores 'recipient'
msgtype:tellafriend requires 'recipient', 'product'
msgtype:tellafriend requi 'product'
</note>

</API>

=cut

sub appSendMessage {
	my ($self,$v) = @_;
	my %R = ();

	my $from = $v->{'sender'};
	my $subject = $v->{'subject'};
	my $message = $v->{'body'};

	if (not &JSONAPI::validate_required_parameter(\%R,$v,'msgtype',['feedback'])) {
		}
	elsif ($v->{'body'} eq '') {
		&JSONAPI::set_error(\%R,'youerr',3103,"blank or empty message body");
		}
	elsif ((my ($attempts) = &SITE::log_email($self->username(),$ENV{'REMOTE_ADDR'})) > 25) {
		&JSONAPI::set_error(\%R,'youerr',3105,"sorry, too many attempts today.");
		}
	elsif ($v->{'msgtype'} eq 'feedback') {
		if (not &ZTOOLKIT::validate_email($v->{'sender'})) {			
			&JSONAPI::set_error(\%R,'youerr',3102,"invalid formatted sender email address");
			}
		elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'subject','')) {
			## auto appends error.
			}
		else {
			# If we have no errors, send it off!

			#if ($order_id ne '') {
			#	require ORDER;
			#	my ($o,$error) = ORDER->new($self->username(),$order_id);
			#	if (defined $o) {
			#		my ($status,$created) = ($o->get_attrib('pool'),$o->get_attrib('created'));
			#	}
	
			if ((defined $v->{'OID'}) && ($v->{'OID'} ne '') && ($v->{'OID'} !~ /[<>"']+/)) {
				## cheap way to append OID (if present)
				$message = "Order: $v->{'OID'}\n\n$message";
				}

			require TODO;
			
         my ($t) = TODO->new($self->username(),writeonly=>1);
			my $LINKTO = "mailto:$from";
			if ($self->apiversion()<201336) { $message = "from:$from\n".$message; }
			if ($v->{'OID'} eq '') { 
				&ZOOVY::add_enquiry($self->username(),"ENQUIRY.ORDER",link=>$LINKTO,orderid=>$v->{'OID'},from=>$from,title=>$subject,detail=>$message);
				$LINKTO = "order:$v->{'OID'}"; 
				}
			else {
				&ZOOVY::add_enquiry($self->username(),"ENQUIRY",from=>$from,title=>$subject,detail=>$message);
				}

			&JSONAPI::append_msg_to_response(\%R,'success',0);					
			}
		}
	else {
		&JSONAPI::set_error(\%R,'iseerr',3104,"internal error handling msgtype:$v->{'msgtype'}");
		}

	return(\%R);
	}





#################################################################################
##
##
##

=pod

<API id="appPageGet">
<purpose></purpose>
<input id="PATH"> .path.to.page or @CAMPAIGNID</input>
<input id="@get"> [ 'attrib1', 'attrib2', 'attrib3' ]</input>
<input id="all"> set to 1 to return all fields (handy for json libraries which don't return @get=[]) </input>
<response id="%page"> [ 'attrib1':'xyz', 'attrib2':'xyz' ],</response>
<note>leave @get empty @get = [] for all page attributes</note>
</API>

=cut

sub appPageGet {
	my ($self,$v) = @_;
	my %R = ();

	my $p = undef;

	my $WIKI = undef;
	if ($v->{'PATH'} eq '') {
		&JSONAPI::set_error(\%R,'apperr',5603,"PATH not specified");
		}
	elsif (($self->clientid() ne 'admin') && ($self->apiversion() >= 201317)) {
		my $PROJECTDIR = $self->projectdir($self->projectid());

		if (not $self->projectid()) {
			## usually this means somebody is referencing the wrong domain (ex: vstore)
			&JSONAPI::append_msg_to_response(\%R,'iseerr',71220,"projectid is not set for host.domain (check DNS config)");
			}
		elsif (! -d $PROJECTDIR) {
			&JSONAPI::append_msg_to_response(\%R,'apierr',71222,"project directory $PROJECTDIR does not seem to exist");
			}
		elsif (-f "$PROJECTDIR/platform/pages.json") {
			my $PATH = $v->{'PATH'};
			print STDERR "LOADFILE:$v->{'PATH'}\n";
			my $PAGES = undef;
			require JSON::Syck;
			eval { $PAGES = JSON::Syck::LoadFile("$PROJECTDIR/platform/pages.json"); };
			if ($@) {
				&JSONAPI::append_msg_to_response(\%R,'apierr',71221,"project platform/pages.json file did not decode properly. $@");
				}
			else { 
				my $ref = $PAGES->{$PATH};
				if (not defined $ref) { $ref = {}; }
				$p = PAGE->new($self->username(),$PATH,PRT=>$self->prt(),DATAREF=>$ref,DOMAIN=>$self->sdomain());

				print STDERR Dumper($p);

				$R{'%debug'} = $ref;

				}
			}
		else {
			&JSONAPI::append_msg_to_response(\%R,'apierr',71223,"project does not appear to have a pages.json file");
			}
		}
	else {
		($p) = PAGE->new($self->username(),$v->{'PATH'},'PRT'=>$self->prt(),DOMAIN=>$self->sdomain());
		if (not defined $p) {
			&JSONAPI::set_error(\%R,'apperr',5602,sprintf("invalid PATH=%s",$v->{'PATH'}));			
			}
		if ($v->{'wikify'}>0) {
			require HTML::WikiConverter; 
			require HTML::WikiConverter::Creole;
			$WIKI = new HTML::WikiConverter(dialect => 'Creole');
			}
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'all'}) { 
		$v->{'@get'} = [ $p->attribs() ]; 
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (not defined $v->{'@get'}) { 
		&JSONAPI::set_error(\%R,'apperr',5603,"\@get is required (and was not included) for call appPageGet");
		}
	elsif (ref($v->{'@get'}) ne 'ARRAY') {
		&JSONAPI::set_error(\%R,'apperr',5604,"\@get must be an array of attributes for call appPageGet");
		}
	else {
		## request only wants specific attributes returned
		$R{'%page'} = {};
		foreach my $attr (@{$v->{'@get'}}) {
			$R{'%page'}->{$attr} = $p->get($attr);
			if (($v->{'wikify'}) && ($R{'%page'}->{$attr} =~ /<.*?>/)) {
				$R{'%page'}->{$attr} = $WIKI->html2wiki( $R{'%page'}->{$attr} );
				$R{'%page'}->{$attr} = &ZTOOLKIT::htmlstrip($R{'%page'}->{$attr},1);
				}
			}
		&JSONAPI::append_msg_to_response(\%R,'success',0);						
		}
#	else {
#		## no attributes in $v->{'@get'} (blank array) so return all attributes
#		foreach my $k ($p->attribs()) {
#			$R{'%page'}->{$k} = $p->get($k);
#			}
#		}


	#use Data::Dumper;
	#print STDERR Dumper($v,\%R);

	return(\%R);
	}








=pod

<API id="appStash">
<purpose>store a key</purpose>
<input id="key">key you want to store</input>
<input id="value">value you want to store</input>
</API>

<API id="appSuck">
<purpose>retrieve a key</purpose>
<input id="key">key you want to store</input>
<response id="value">key you want to store</response>
</API>

=cut


sub appStashSuck {
	my ($self,$v) = @_;

	my %R = ();
	my $memd = &ZOOVY::getMemd($self->username());

	my $key = sprintf("%s:%s",$self->username(),$v->{'key'});
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'key')) {
		## key is required!
		}
	elsif ($v->{'_cmd'} eq 'appStash') {
		if (not &JSONAPI::validate_required_parameter(\%R,$v,'value')) {
			## value is required!
			}
		else {
			$memd->set($key,$v->{'value'});
			&JSONAPI::append_msg_to_response(\%R,'success',0);
			}
		}
	elsif ($v->{'_cmd'} eq 'appSuck') {
		$R{'value'} = $memd->get($key);
		}
	else {
		&JSONAPI::set_error(\%R,'apperr',120,"invalid _cmd");
		}

	return(\%R);
	}



=pod

<API id="appSearchLogList">
<purpose>lists available search log files</purpose>
</API>

<API id="appSearchLogRemove">
<purpose>permanently remove/delete all search logs</purpose>
<input id="FILE">reference file id</input>
</API>

=cut

sub adminSearchLog {
	my ($self,$v) = @_;
	my %R = ();
	my $USERNAME = $self->username();

	if ($v->{'_cmd'} eq 'adminSearchLogRemove') {
		my $path = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES';
		my $file = $v->{'FILE'};
		$file =~ s/[\.]+/./g;	# remove multiple periods.
		$file =~ s/[\/\\]+//gs;	# remove all slashes
		unlink("$path/$file");
		}

	if ($v->{'_cmd'} eq 'adminSearchLogList') {
		##
		my $c = '';
		require BATCHJOB;
		my $GUID = &BATCHJOB::make_guid();
		my $path = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES';
		my $D = undef;
		opendir $D, $path;
  		my ($MEDIAHOST) = &ZOOVY::resolve_media_host($USERNAME);
		my @FILES = ();
		while ( my $file = readdir($D) ) {
			next if (substr($file,0,1) eq '.');
			my $CATALOG = '';
			if ($file =~ /^SEARCH-(.*?)\.(log|csv)$/) {
				$CATALOG = $1;
				if ($CATALOG eq '') { $CATALOG = 'N/A'; }
				my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($path.'/'.$file);
				push @FILES, { 'FILE'=>$file, 'CATALOG'=>$CATALOG, 'TS'=>$mtime, 'DOWNLOAD'=>"//$MEDIAHOST/media/merchant/$USERNAME/$file" };
				}
			}
		closedir $D;
		$R{'@FILES'} = \@FILES;
		}
	return(\%R);
	}





=pod

<API id="adminDebugSearch">
<purpose>runs a debug search query through the analyzer</purpose>
<input id="VERB">RAWE-QUERY|RAWE-SCHEMA-PID-LIVE|RAWE-SCHEMA-PID-CONFIGURED|RAWE-SHOWPID|RAWE-INDEXPID</input>
<input id="PID">product id (optional)</input>
</API>

=cut

sub adminDebugSearch {
	my ($self,$v) = @_;
	my %R = ();

	require PRODUCT::FLEXEDIT;
	my ($USERNAME) = $self->username();
	my ($MID) = $self->mid();

	my $VERB = $v->{'VERB'};
	my $QUERY = undef;
	my $PID = $v->{'PID'};
	my ($es) = &ZOOVY::getElasticSearch($USERNAME);		
	if ($VERB eq 'RAWE') {
		## not a "RUN"
		$es = undef;
		}
	elsif ($VERB eq 'RAWE-QUERY') {
		$QUERY = $v->{'QUERY'};
		if ($v->{'QUERY'} eq '') {
			&JSONAPI::set_error(\%R,'youerr',2394,'No query specified');
			}
		}

	if (not defined $es) {
		## bad things alreadly happens.
		}
	elsif ($VERB eq 'RAWE-SCHEMA-PID-LIVE') {
  		## my ($schema) = &ELASTIC::rebuild_product_index($USERNAME,'schemaonly'=>1);
		my ($path) = &ZOOVY::resolve_userpath($USERNAME);
		open F, "<$path/public-index.dmp";
		my $schema = undef;
		while (<F>) { $schema .= $_; }
		close F;
		$v->{'schema-current'} = $schema;
      }
	elsif ($VERB eq 'RAWE-SCHEMA-PID-CONFIGURED') {
		my ($schema) = &ELASTIC::rebuild_product_index($USERNAME,'schemaonly'=>1);
		$v->{'schema-future'} = $schema;
      }
	elsif ($VERB eq 'RAWE-QUERY') {

		my $Q = $v->{'QUERY'};
		if (not defined $Q) { 
			eval { $Q = JSON::XS::decode_json($v->{'JSON'}); };
			if ($@) {
				&JSONAPI::set_error(\%R,'youerr',2392,"JSON Decode Error: $@"); 
				$Q = undef;
				}
			}

		if (defined $Q) {
			## $Q->{'index'} = lc("$USERNAME.public");
			foreach my $k (keys %{$Q}) {
				if (substr($k,0,1) eq '_') { 
					&JSONAPI::set_error(\%R,'warn',2392,"removed key '$k' because it started with an underscore and is not valid (just being helpful)");
					delete $Q->{$k};
					}
				}
			if ((not defined $Q->{'filter'}) && (not defined $Q->{'query'})) {
				&JSONAPI::set_error(\%R,'youerr',2394,"WARN|+No 'filter' or 'query' was specified, so this probably won't work real well.");
				}

			## www.elasticsearch.org/guide/reference/query-dsl/term-query.html
			## filter should use:
			
			## query should use: 
			}

		my $results = undef;	
		if ((defined $Q) && (defined $es)) {
		   eval { $results = $es->search('index'=>lc("$USERNAME.public"), 'body'=>$Q); };
			if ($@) {
				&JSONAPI::set_error(\%R,'apperr',2394,"Elastic Search Error:$@");
				}
			}

		$v->{'QUERY'} = $Q;
		$v->{'RESULTS'} = $results;
		}
	elsif (($VERB eq 'RAWE-SHOWPID') || ($VERB eq 'RAWE-INDEXPID')) {

		if ($PID eq '') {
			&JSONAPI::set_error(\%R,'apperr',2394,"ERROR|PID not specified");
			}
		elsif ($VERB eq 'RAWE-INDEXPID') {
			my ($P) = PRODUCT->new($USERNAME,$PID);
			if (not defined $P) {
				&JSONAPI::set_error(\%R,'apperr',2394,"Product '$PID' does not exist in product database");
				}
			else {
				&JSONAPI::set_error(\%R,'success',0,"Product '$PID' was immediately indexed into elastic");
				&ELASTIC::add_products($USERNAME,[$P],'*es'=>$es);
				sleep(5);	# make them wait (avoids abuse, gives elastic a chance to catch up)
				}
			}
	
		if ($PID ne '') {
	     	my $result = undef;
			eval { $result = $es->get(index =>lc("$USERNAME.public"),'type'=>'product','id'=>$PID); };
       	if ($@) {
        		&JSONAPI::set_error(\%R,'apperr',2394,"Elastic retrieval error - $@");
          	}
			$R{'result'} = $result;
			}
		}
	else {
		&JSONAPI::set_error(\%R,'apperr',2394,"+Invalid VERB:$VERB");
		}

	return(\%R);
	}



=pod

<API id="adminDebugSite">
<purpose></purpose>
<input id="check-global"></input>
<input id="check-domains"></input>
</API>

=cut


sub adminDebugSite {
	my ($self,$v) = @_;
	my %R = ();

	my ($USERNAME) = $self->username();
	my ($MID) = $self->mid();
	my ($PRT) = $self->prt();

	my ($PID) = $v->{'PID'};

	my @DIAGS = ();

	if ($v->{'check-global'}) {
		my ($globalref) = $self->globalref();
		my $i = 0;
		push @DIAGS, "INFO||Evaulating ".scalar(@{$globalref->{'@partitions'}})." partitions";
		my %USED = ();
		foreach my $prt ( @{$globalref->{'@partitions'}} ) {
			if ($prt->{'profile'} eq '') { $prt->{'profile'} = 'DEFAULT'; }
			if (not defined $prt->{'p_navcats'}) { $prt->{'p_navcats'}=0; }
			if (not defined $prt->{'p_customers'}) { $prt->{'p_customers'}=$i; }

			push @DIAGS, "INFO||PRT#$i PROFILE($prt->{'profile'}) CATEGORIES($prt->{'p_navcats'}) CUSTOMERS($prt->{'p_customers'})";

			if (defined $USED{$prt->{'profile'}}) {
				push @DIAGS, "ERR||WARNING: prt $USED{$prt->{'profile'}} and prt $i are both mapped to $prt->{'profile'}<br>== reminder: Profiles should never be shared by partition";
				}
			else {
				push @DIAGS, "INFO||Partition $i uses profile $prt->{'profile'}";
				$USED{$prt->{'profile'}} = $i;
				}

			my ($dbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$i);
			if ($dbref->{'profile'} ne $prt->{'profile'}) {
				push @DIAGS, "ERR|webdb:$i?profile=$prt->{'profile'}|Global partition says profile[$prt->{'profile'}] but webdb has profile=[$dbref->{'profile'}]*";
#				if ($FIX) {
#					$dbref->{'profile'} = $prt->{'profile'};
#					&ZWEBSITE::save_website_dbref($USERNAME,$dbref,$i);
#					push @DIAGS, "FIX||Set webdb(partition settings) for prt[$i] to profile $prt->{'profile'}";
#					}
				}

			## some profile checks.
#			my $nsref = &ZOOVY::fetchmerchantns_ref($USERNAME,$prt->{'profile'});
#			if (int($nsref->{'prt:id'}) != int($i)) {
#				push @DIAGS, "ERR|profile:$prt->{'profile'}?prt:id=$i|Profile[$prt->{'profile'}] has prt:id field set to: $nsref->{'prt:id'} (should be *$i)";
##				if ($FIX) {
##					$nsref->{'prt:id'} = $i;
##					&ZOOVY::savemerchantns_ref($USERNAME,$prt->{'profile'},$nsref);
##					push @DIAGS, "FIX||Profile[$prt->{'profile'} set prt:id=$i";
##					}
#				}


#			if ($prt->{'p_navcats'} == $i) {
#				push @DIAGS, "INFO||Partition[$i] has federated navigation - so we'll check that too.";
#				if ($nsref->{'zoovy:site_rootcat'} ne '.') {
#					push @DIAGS, "ERR|profile:$prt->{'profile'}?zoovy:site_rootcat=.|Profile[$prt->{'profile'}] has specialty rootcat(zoovy:site_rootcat)='$nsref->{'zoovy:site_rootcat'}'  should be (*)'.'";
##					if ($FIX) {
##						push @DIAGS, "FIX||Profile[$prt->{'profile'}] set rootcat for prt $i to . (was: $nsref->{'zoovy:site_rootcat'})";
##		         	$nsref->{'zoovy:site_rootcat'} = '.';
##						&ZOOVY::savemerchantns_ref($USERNAME,$prt->{'profile'},$nsref);
##						}
#					}
#				}

			## we should probably eventually add some domain checks here.
			my ($udbh) = &DBINFO::db_user_connect($USERNAME);
			my $pstmt = "select DOMAIN from DOMAINS where IS_PRT_PRIMARY>0 and PRT=$PRT and MID=$MID";
			my @DOMAINS = ();
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my ($domain) = $sth->fetchrow() ) { 
				push @DOMAINS, $domain; 
				}
			$sth->finish();
			if (scalar(@DOMAINS)==0) {
				push @DIAGS, "ERR||Partition[$i] needs at least one domain designated as primary";
				}
			elsif (scalar(@DOMAINS)==1) {
				push @DIAGS, "INFO||Partition[$i] has one primary domain '$DOMAINS[0]' (good)";
				}
			else {
				push @DIAGS, "ERR||Partition[$i] has more than one primary domain (confusing) - ".join(",",@DOMAINS);
				}

			&DBINFO::db_user_close();

			$i++;
			}	
		}

	if ($v->{'check-domains'} ) {
		my @domains = DOMAIN::TOOLS::domains($USERNAME);
		my %USED_PROFILES = ();
		my %USED_PRIMARY = ();
		foreach my $domainname (@domains) {
			my ($d) = DOMAIN->new($USERNAME,$domainname);
			my $PRT = $d->prt();
			# my $nsref = &ZOOVY::fetchmerchantns_ref($USERNAME,$PROFILE);

			my $SKIP = 0;
			#if ($d->{'HOST_TYPE'} eq 'REDIR') {
			#	push @DIAGS, "INFO||DOMAIN: $domainname is type REDIRECT, nothing to check";
			#	$SKIP++;
			#	}
			#if ($d->{'HOST_TYPE'} eq 'MINISITE') {
			#	push @DIAGS, "INFO||DOMAIN: $domainname is type MINISITE, nothing to check";
			#	$SKIP++;
			#	}
			# next if ($SKIP);
			
			#elsif ($d->{'HOST_TYPE'} eq 'NEWSLETTER') {
			#	}
			#elsif ($d->{'HOST_TYPE'} eq 'PRIMARY') {
			#	## primary domain .. should share same profile as partition.
			#	my $prt = &ZOOVY::fetchprt($USERNAME,$PRT);

			#if ($USED_PROFILES{$PROFILE}) {
			#	push @DIAGS, "ERR||DOMAIN: $domainname has same profile[$PROFILE] as domain $USED_PROFILES{$PROFILE} -- these should not be shared.";
			#	#if ($FIX) {
			#	#	push @DIAGS, "FAIL||Cannot resolve which domain $domainname or $USED_PROFILES{$PROFILE} should be using profile $PROFILE";
			#	#	}
			#	}
			#else {
			#	$USED_PROFILES{$PROFILE} = $domainname;
			#	}

			if ($USED_PRIMARY{$PRT}) {
				push @DIAGS, "ERR||DOMAIN: $domainname is primary for partition $PRT, but domain $USED_PRIMARY{$PRT} claims to be primary for same partition.";
				#if ($FIX) {
				#	push @DIAGS, "FAIL||I'm sorry, but I will not conduct a domain deathmatch between $domainname and $USED_PRIMARY{$PRT} for partition $PRT, please work it out yourself.";
				#	}
				}
			else {
				$USED_PRIMARY{$PRT} = $domainname;
				}

			#if ($nsref->{'prt:id'} != $PRT) {
			#	push @DIAGS, "ERR||DOMAIN: $domainname has profile($PROFILE) which says prt:id=$nsref->{'prt:id'}) .. but domain says PRT=$PRT";
			#	#if ($FIX) {
			#	#	push @DIAGS, "FAIL||Cannot resolve PRT/prt:id discrepancy automatically! .. I have no idea who to trust here.";
			#	#	}					
			#	}
			#if ($PRT != $nsref->{'prt:id'}) {
			#	push @DIAGS, "ERR||DOMAIN: $domainname has partition=$PRT but also profile[$PROFILE] which has prt:id=$nsref->{'prt:id'}";				
			#	#if ($FIX) {
			#	#	push @DIAGS, "FIX||DOMAIN: $domainname set partition=$nsref->{'prt:id'} .. was partition=$PRT";
			#	#	$PRT = $nsref->{'prt:id'};
			#	#	$d->save();
			#	#	}
			#	}
			
#			## $PRT is assumed to be correct.
#			if ($PRT != $nsref->{'prt:id'}) {
#				push @DIAGS, "ERR||DOMAIN: $domainname found issue w/profile($PROFILE) has prt:id=$nsref->{'prt:id'}) but (should be same as domain *$PRT)";	
#				#if ($FIX) {
#				#	push @DIAGS, "FIX||DOMAIN: $domainname profile($PROFILE) setting prt:id=$PRT (was $nsref->{'prt:id'})";
#				#	$nsref->{'prt:id'} = $PRT;
#				#	&ZOOVY::savemerchantns_ref($USERNAME,$PROFILE,$nsref);
#				#	}
#				}
			}
		}


	if (scalar(@DIAGS)==0) {
		push @DIAGS, "INFO||No checks conducted.";
		}

	my @RESULTS = ();
	foreach my $msg (@DIAGS) {
		my ($type,$cmd,$txt) = split(/\|/,$msg,3);
		push @RESULTS, { 'msgtype'=>$type, 'cmd'=>$cmd, 'msgtxt'=>$txt };
		}
	$R{'@RESULTS'} = \@RESULTS;
	return(\%R);
	}




=pod

<API id="adminDebugProduct">
<purpose></purpose>
<input id="PID">product id</input>
</API>

=cut


sub adminDebugProduct {
	my ($self,$v) = @_;
	my %R = ();

	my ($USERNAME) = $self->username();
	my ($MID) = $self->mid();
	my ($PID) = $v->{'pid'};
	
#	if ($v->{'ACTION'} eq 'OVERRIDE_RESERVE') {
#		my ($SKU) = $v->{'SKU'};
#		my ($APPKEY) = $v->{'APPKEY'};
#		my ($LISTINGID) = $v->{'LISTINGID'};
#		&INVENTORY::set_other($USERNAME,$APPKEY,$SKU,0,'expirets'=>time()-1,'uuid'=>$LISTINGID);
#		$LU->log("PRODEDIT.DEBUG.RESINVOVERRIDE","Reserve Inventory Override SKU=$SKU APPKEY=$APPKEY LISTINGID=$LISTINGID");
#		$v->{'ACTION'} = 'REFRESH';
#		}


	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $c = '';

	my $qtPID = $udbh->quote($PID);

	## OTHER RESERVE
	## $R{'INVENTORY_OTHER'} = &INVENTORY::list_other(undef,$USERNAME,$PID,0);

	## INVENTORY DEBUG LOG
	
	if (1) {
		my @INVENTORY_LOG = ();
		$R{'@INVENTORY_LOG'} = \@INVENTORY_LOG; 
		my $LIMIT = 100;
		my $pstmt = "select * from INVENTORY_LOG where MID=$MID and PID=".$udbh->quote($PID)." order by ID desc limit 0,$LIMIT";
		print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $hashref = $sth->fetchrow_hashref() ) { 
			push @INVENTORY_LOG, $hashref;
	   	}
		$sth->finish();

   	## prepend finalization pending records.
		#my @INVENTORY_UPDATES = ();
   	#$pstmt = "select LUSER,TIMESTAMP,TYPE,PRODUCT,SKU,QUANTITY,APPID,ORDERID from INVENTORY_UPDATES where MID=$MID /* $USERNAME */ and PRODUCT=".$udbh->quote($PID)." order by ID desc";
   	#print STDERR $pstmt."\n";
   	#$sth = $udbh->prepare($pstmt);
   	#$sth->execute();
   	#while ( my $hashref = $sth->fetchrow_hashref() ) {
		#	push @INVENTORY_UPDATES, $hashref;
	   #	}
	   #$sth->finish();
		#$R{'@INVENTORY_UPDATES'} = \@INVENTORY_UPDATES;
	   }

	if (1) {
		my @AMAZON_DOCS = ();
		$R{'@AMAZON_DOCUMENT_CONTENTS'} = \@AMAZON_DOCS;
		## select a PID or any matching SKU of a PID 
		my $pstmt = "select DOCID,MSGID,FEED,SKU,CREATED_TS,DEBUG,ACK_GMT from AMAZON_DOCUMENT_CONTENTS where MID=$MID and SKU REGEXP concat('^',$qtPID,'(\\:[A-Z0-9\\#]{4,4}){0,3}\$') and CREATED_TS>date_sub(now(),interval 60 day) order by DOCID desc limit 30;";
		print STDERR "$pstmt\n";
		# $c .= $pstmt;
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $ref = $sth->fetchrow_hashref() ) {
			push @AMAZON_DOCS, $ref;
			}
		$sth->finish();
		}

	if (1) {
		my $c = '';
		## select a PID or any matching SKU of a PID 
		my @SKU_LOOKUP = ();
		my ($TB) = &ZOOVY::resolve_lookup_tb($USERNAME,$MID);
		my $pstmt = "select * from $TB where MID=$MID and PID=$qtPID order by ID desc";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $ref = $sth->fetchrow_hashref() ) {
			push @SKU_LOOKUP, $ref;
			}
		$sth->finish();
		$R{'@SKU_LOOKUP'} = \@SKU_LOOKUP;
		}

	if (1) {
		my @SYNDICATION_QUEUED_EVENTS = ();
		## select a PID or any matching SKU of a PID 
		my $pstmt = "select SKU,CREATED_GMT,PROCESSED_GMT,DST,VERB,ORIGIN_EVENT from SYNDICATION_QUEUED_EVENTS where MID=$MID and PRODUCT=$qtPID order by ID desc";
		# $c .= $pstmt;
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $ref = $sth->fetchrow_hashref() ) {
			push @SYNDICATION_QUEUED_EVENTS, $ref;
			}
		$sth->finish();
		$R{'@SYNDICATION_QUEUED_EVENTS'} = @SYNDICATION_QUEUED_EVENTS;
		}
	
	if (1) {
		my $c = '';
		# my $TB = &INVENTORY::resolve_tb($USERNAME,$MID,'INVENTORY');
		my $qtPID = $udbh->quote($PID);
		my $pstmt = "select * from INVENTORY_DETAIL where MID=$MID /* $USERNAME */ and PRODUCT=$qtPID";
		print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		my @INVENTORY = ();
		while ( my $hashref = $sth->fetchrow_hashref() ) {
			push @INVENTORY, $hashref;
			}
		$R{'@INVENTORY'} = \@INVENTORY;
		$sth->finish();
		}

	if (1) {
		my @NAVCATS = ();
		require NAVCAT;
		foreach my $prttext (@{&ZWEBSITE::list_partitions($USERNAME)}) {
			my ($prt) = split(/:/,$prttext); 
			my ($nc) = NAVCAT->new($USERNAME,PRT=>$prt);
			my $paths = $nc->paths_by_product($PID);
			foreach my $path (@${paths}) {
				push @NAVCATS, { 'safe'=>$path, prt=>$prt, 'prtpretty'=>$prttext };
				}
			}
		$R{'@NAVCATS'} = \@NAVCATS;
		}

	if (1) {
		my $P = PRODUCT->new($USERNAME,$PID);
		my $SKUS = [];
  		if (defined $P) { 
  	  		$SKUS = $P->list_skus(); 
  			}
		else {
			&JSONAPI::set_error(\%R,'iseerr',8473,"ERROR|+Product record '$PID' is corrupt/could not be loaded or there is another reason the product object could not be created.");
			}
   
		my %VARS = ();
		if (scalar(@{$SKUS})>0) {
			foreach my $set (@{$SKUS}) {
				my ($sku,$skuref) = @{$set};
				foreach my $k (keys %{$skuref}) {
					$VARS{"$k\~$sku"} = $skuref->{$k};
					}
				}
			}

	   if (defined $P) {
			foreach my $k (keys %{$P->prodref()}) {
  	 			$VARS{$k} = $P->fetch($k);
   			}
	      }

		my @ATTRIBS = ();
		foreach my $skukey (sort keys %VARS) {
			next if ($skukey eq '');

			my $sku = undef;
			my $k = undef;
			if ($skukey =~ /(.*?)\~(.*?)/) { 
				## zoovy:prod_desc<sku:#010>
				$k = $1; $sku = $2;
				}
			else {
				$k = $skukey;
				}

			my %REF = ();
			$REF{'SKU'} = $skukey;
			if (ref($VARS{$skukey}) eq '') {
				$REF{'DATA'} = &ZOOVY::incode($VARS{$skukey});
				}
			elsif (ref($VARS{$skukey}) eq 'HASH') {
				$REF{'DATA'} = &ZOOVY::incode(Dumper($VARS{$skukey}));
				}
			else {
				$REF{'DATA'} = '**ERR**';
				}

			if (($k =~ /(.*?):prod_image[\d]+$/) || ($k =~ /:prod_thumb/)) {
				## REMINDER: make sure we don't match zoovy:prod_image[\d]_alt -- which can have spaces
				if (index($VARS{$skukey},' ')>=0) {
					push @{$REF{'@MSGS'}},"WARNING: attribute $skukey contains a space in the data (not valid for images).";
					}
				}
			if ($skukey =~ /[\s]+/) {
				push @{$REF{'@MSGS'}},"WARNING: attribute $skukey contains a space in the key '$skukey'.";
				}
			elsif ($skukey =~ /^[^a-z]+/) {
				push @{$REF{'@MSGS'}},"WARNING: attribute $skukey contains an invalid leading character.";
				}
		
			my $fieldref = $PRODUCT::FLEXEDIT::fields{$k};
			if ($k =~ /^user:/) {
				## user defined fields.
				}
			elsif (defined $fieldref) {
				## valid field, but we can still perform some global checks.
				if ($fieldref->{'type'} eq 'legacy') {
					push @{$REF{'@MSGS'}},"WARNING: attribute $skukey is a legacy field and should probably be removed.";
					}
				if ((defined $sku) && (not $fieldref->{'sku'})) {
					push @{$REF{'@MSGS'}},"WARNING: attribute $skukey is set at the sku level, but is not considered a sku level field.";
					}
				}
			elsif (not &PRODUCT::FLEXEDIT::is_valid($k,$USERNAME)) {
				push @{$REF{'@MSGS'}},"WARNING: attribute $k is not valid and should be removed.";
				}
	
			## field specific type checks
			if (not defined $fieldref) {
				}
			elsif ($fieldref->{'type'} eq 'textbox') {
				if (not defined $fieldref->{'minlength'}) { 
					## no minimum length check
					}
				elsif ( length($VARS{$skukey}) < $fieldref->{'minlength'}) {
					push @{$REF{'@MSGS'}},"ERROR: attribute $skukey does not meet minimum length requirement of $fieldref->{'minlength'}.";
					}
	
				if (not defined $fieldref->{'maxlength'}) {}
				elsif ( length($VARS{$skukey}) > $fieldref->{'maxlength'}) {
					push @{$REF{'@MSGS'}},"ERROR: attribute $skukey is longer than the maximum length requirement of $fieldref->{'maxlength'}.";
					}
				}
	
			## check data
			if ($VARS{$skukey} =~ /^[\s]+/) {
				push @{$REF{'@MSGS'}},"WARNING: attribute $skukey contains one or more leading spaces in data.";
				}
			elsif ($VARS{$skukey} =~ /^[\t]+/) {
				push @{$REF{'@MSGS'}},"WARNING: attribute $skukey contains one or more leading TAB characters in data.";
				}
			elsif ($VARS{$skukey} =~ /[\s]+$/) {
				push @{$REF{'@MSGS'}},"WARNING: attribute $skukey contains one or more trailing spaces in data.";
				}
			elsif ($VARS{$skukey} =~ /[\t]$/) {
				push @{$REF{'@MSGS'}},"WARNING: attribute $skukey contains one or more trailing TAB characters in data.";
				}
			}
		$R{'@ATTRIBS'} = \@ATTRIBS;
		}


	return(\%R);
	}




=pod


<API id="adminDebugShipping">
<purpose>does a shipping debug</purpose>
<input id="SRC">ORDER|DEST|CART</input>
<input id="_cartid">SRC:CART</input>
<input id="ITEM1">SRC=DEST: ITEM1,ITEM2,ITEM3</input>
<input id="QTY1">SRC=DEST: QTY1, QTY2, QTY3</input>
<input id="ZIP">SRC=DEST:</input>
<input id="ZIP">SRC=DEST:</input>
<input id="STATE">SRC=DEST:</input>
<input id="COUNTRY">SRC=DEST:</input>
<input id="ORDERID">SRC=ORDER</input>
<input id=""></input>
</API>

<API id="adminDebugPromotion">
<purpose>does a promotion debug</purpose>
<input id="SRC">ORDER|DEST|CART</input>
<input id="_cartid">SRC:CART</input>
<input id="ITEM1">SRC=DEST: ITEM1,ITEM2,ITEM3</input>
<input id="QTY1">SRC=DEST: QTY1, QTY2, QTY3</input>
<input id="ZIP">SRC=DEST:</input>
<input id="ZIP">SRC=DEST:</input>
<input id="STATE">SRC=DEST:</input>
<input id="COUNTRY">SRC=DEST:</input>
<input id="ORDERID">SRC=ORDER</input>
<input id=""></input>
</API>

<API id="adminDebugTaxes">
<purpose>does a tax debug</purpose>
<input id="SRC">ORDER|DEST|CART</input>
<input id="_cartid">SRC:CART</input>
<input id="ITEM1">SRC=DEST: ITEM1,ITEM2,ITEM3</input>
<input id="QTY1">SRC=DEST: QTY1, QTY2, QTY3</input>
<input id="ZIP">SRC=DEST:</input>
<input id="ZIP">SRC=DEST:</input>
<input id="STATE">SRC=DEST:</input>
<input id="COUNTRY">SRC=DEST:</input>
<input id="ORDERID">SRC=ORDER</input>
<input id=""></input>
</API>

=cut


sub adminDebugPromotion {
	my ($self,$v) = @_;
	my %R = ();

	

	return(\%R);
	}




sub adminDebugShippingPromoTaxes {
	my ($self,$v) = @_;
	my %R = ();

	my $USERNAME = $self->username();
	my $PRT = $self->prt();

	my $SRC = $v->{'SRC'};
	require LISTING::MSGS;
	my ($lm) = LISTING::MSGS->new($USERNAME);

	my $TRACE = 0;
	$TRACE += ($v->{'detail_1'})?1:0;			# general trace info (always enabled)
	$lm->pooshmsg("INFO|+Setting trace level to: $TRACE (going to build cart)");

	my $CART2 = undef;

	if ($SRC eq 'ORDER') {
		## LOAD FROM ORDER
		my $orderid = $v->{'ORDER'};
		print STDERR "DEBUGGER USING ORDER: $v->{'ORDER'}\n";
		$CART2 = CART2->new_from_oid($USERNAME,$orderid);
		$CART2->msgs($lm);
		$CART2->is_debug($TRACE);
		}
	elsif ($SRC eq 'DEST') {
		## CREATE A CART
		$CART2 = CART2->new_memory($USERNAME,$PRT);
		$CART2->msgs($lm);
		$CART2->is_debug($TRACE);
		foreach my $x (1..3) {
			
			my $STID = $v->{'ITEM'.$x};
			next if ($STID eq '');
			my $QTY = $v->{'QTY'.$x};

			my ($pid,$claim,$invopts,$noinvopts,$virtual) = PRODUCT::stid_to_pid($STID);
			my ($P) = PRODUCT->new($USERNAME,$pid);
			my ($suggested_variations) = $P->suggest_variations('guess'=>1,'stid'=>$STID);
			foreach my $suggestion (@{$suggested_variations}) {
				if ($suggestion->[4] eq 'guess') {
					$lm->pooshmsg("WARN|+STID:$STID POG:$suggestion->[0] VALUE:$suggestion->[1] was guesssed (reason: not specified or invalid)");
					}
				}
			my $variations = STUFF2::variation_suggestions_to_selections($suggested_variations);
			$CART2->stuff2()->cram( $STID, $QTY, $variations, '*P'=>$P, '*LM'=>$lm );
			}	
		$CART2->in_set('ship/postal', $v->{'ZIP'});
		$CART2->in_set('ship/region', $v->{'STATE'});
		$CART2->in_set('ship/countrycode', $v->{'COUNTRY'});
		}
	elsif ($SRC eq 'CART') {
		## USE AN EXISTING CART
		my $CARTID = $v->{'_cart'};
		if ($CARTID =~ /^c=(.*?)$/) { 
			&JSONAPI::set_error(\%R, 'warning', 7232, "The prefix c= is not needed for the cartid and was removed.");
			$CARTID = $1; 
			}
		print STDERR "USING CART:$CARTID PRT:$PRT\n";
		$CART2 = CART2->new_persist($USERNAME,$PRT,$CARTID,'is_fresh'=>0,'*SESSION'=>$self);
		if ((not defined $CART2) && (ref($CART2) ne 'CART2')) {
			&JSONAPI::set_error(\%R, 'youerr', 7233, "Cart:$CARTID Prt:$PRT does not exist");
			}
		else {
			$CART2->msgs($lm);
			$CART2->is_debug($TRACE);
			}
		}
	else {
		&JSONAPI::set_error(\%R, 'apperr', 7233, "Please select a valid source for products/destination information");
		$CART2->new_memory($USERNAME,$PRT);
		}

	##
	## SANITY: at this point $SITE::CART is set.
	##
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'_cmd'} eq 'adminDebugPromotion') {

      if ($CART2->is_order()) {
         $lm->pooshmsg("WARN|+Appears we have an order, converting back into a cart");
         delete $CART2->{'ODBID'};
         }

		$CART2->is_debug(0xFF);
		$CART2->msgs($lm);
      # $CART2->is_debug($DEBUG);
      push @{$CART2->{'@CHANGES'}}, [ 'DEBUG' ];
      $CART2->__SYNC__();
		my @MSGS = ();
		foreach my $line (@{$lm->msgs()}) {
			my ($msg,$status) = &LISTING::MSGS::msg_to_disposition($line);
			next if ($msg->{'TYPE'} eq 'SHIP');
			# $out .= Dumper($msg);
			push @MSGS, $status;
			}
		$R{'@MSGS'} = \@MSGS;
		}
	elsif ($v->{'_cmd'} eq 'adminDebugShipping') {

 		$lm = $CART2->msgs($lm);
		$lm->pooshmsg("INFO|+Requesting shipmethods (setting debug to 0xFF)");
		$CART2->is_debug(0xFF);
		$CART2->shipmethods('flush'=>1);

		my ($stuff2) = $CART2->stuff2();
		foreach my $item (@{$stuff2->items()}) {
			my $stid = $item->{'stid'};
			if ($item->{'virtual'} =~ /[\s]/) { $lm->pooshmsg("ERROR|+Preflight: STID[$stid] has space in supplier virtual field \"$item->{'virtual'}\""); }
			if ($item->{'%attribs'}->{'zoovy:virtual'} =~ /[\s]/) { $lm->pooshmsg("ERROR|+Preflight: STID[$stid] has space in zoovy:virtual field"); }
			if ($item->{'%attribs'}->{'zoovy:virtual'} ne $item->{'virtual'}) { $lm->pooshmsg("ERROR|+Preflight: STID[$stid] has non-matching zoovy:virtual and item.virtual (internal error!?)"); }
			}
	
		$R{'lm'} = $lm;

		my @MSGS = ();
		foreach my $msg (@{$lm->msgs()}) {
			my ($d) = LISTING::MSGS::msg_to_disposition($msg);
			push @MSGS, $d;
			}
		$R{'@MSGS'} = \@MSGS;

		my @RESULTS = ();	
		foreach my $shipmethod (@{$CART2->shipmethods()}) {
			push @RESULTS, $shipmethod;
			}
		$R{'@RESULTS'} = \@RESULTS;

		## open F, ">/tmp/msgs"; print F Dumper(\%R); close F;
		}
	elsif ($v->{'_cmd'} eq 'adminDebugTaxes') {
		my ($webdbref) = my $webdb = $self->webdb();
		my (%result) = &ZSHIP::getTaxes($USERNAME,$PRT,
			webdb=>$webdb,
			city=>$v->{'city'},
			state=>$v->{'state'},
			zip=>$v->{'zip'},
			address1=>$v->{'address1'},
			country=>$v->{'country'},
			subtotal=>$v->{'order_total'},
			shp_total=>$v->{'shipping_total'},
			debug=>1);
		$R{'%RESULTS'} = \%result;
#	<td>Overall:</td>
#	<td>$result{'tax_rate'}%</td>
#	<td>\$$result{'tax_subtotal'}</td>
#	<td><b>\$$result{'tax_total'}</b></td>
#	<td> &lt;-- what the customer will pay</td>
#	<td>_state:</td>
#	<td>$result{'state_rate'}%</td>
#	<td>\$$result{'tax_subtotal'}</td>
#	<td>\$$result{'state_total'}</td>
#	<td>_local:</td>
#	<td>$result{'local_rate'}%</td>
#	<td>\$$result{'tax_subtotal'}</td>
#	<td>\$$result{'local_total'}</td>
#	<b>TRANSACTION LOG:</b><br>
#	<pre>$result{'debug'}</pre>
		}



	return(\%R);
	}



=pod

<API id="adminConfigDetail">
<purpose>to obtain detail on a configuration object</purpose>
<input id="order">include %ORDER in response (contains current order sequence #)</input>
<input id="wms">include %WMS in response</input>
<input id="plugins">include @PLUGINS in response</input>
<input id="erp">include %ERP in response</input>
<input id="inv">include %INVENTORY in response</input>
<input id="prts">include @PRTS in response</input>
<input id="payments">include @PAYMENTS in response</input>
<input id="shipping">include %SHIPPING in response</input>
<input id="shipmethods">include @SHIPMENTS in response</input>
<input id="blast">include %BLAST in response</input>
</API>

=cut

# adminConfigDump
sub adminConfigDetail {
	my ($self,$v) = @_;
	
	my $USERNAME = $self->username();
	my $PRT = $self->prt();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my %R = ();
	my ($gref) = $self->globalref();
	my ($webdbref) = my $webdb = $self->webdb();
	my $LUSERNAME = $self->luser();

	if ($v->{'flexedit'}) {
		require PRODUCT::FLEXEDIT;
		require JSON::XS;

		## DO NOT AMEND THIS DATA THIS IS NECESARY FOR HAVING AN ONLINE %flexedit editor
		my %SET = ();
		my $fref = &PRODUCT::FLEXEDIT::userfields($USERNAME,undef);
		foreach my $id (@{$fref}) {
			$SET{$id}++;
			}
		$R{'%flexedit'} = $fref;
		}

	if ($v->{'tuning'}) {
		require ZWEBSITE;
		my ($gref) = $self->globalref();
		$R{'%tuning'} = $gref->{'%tuning'};
		}


	if ( not $v->{'notifications'}) {
		}
	elsif ($self->deprecated(\%R,-201402) ) {
		}
	elsif ($v->{'notifications'}) {
		my @EVENTS = ();
		require NOTIFICATIONS;
		$R{'@NOTIFICATIONS'} = NOTIFICATIONS::list($webdbref);
		}




	if ($v->{'plugins'}) {
		##

#returns @PLUGINS
#[
#  { 'plugin':'auth_google', 'enable':1|0, 'field1':'value1','field2:value2' },
#  { 'plugin':'auth_facebook', 'enable':1|0, 'field1':'value1','field2:value2' },
#  { 'plugin':'platform_android', 'enable':1|0, 'field1':'value1','field2:value2' },
#  { 'plugin':'platform_appleios', 'enable':1|0, 'field1':'value1','field2:value2' },
#]
# in plugins -- i picture an interface similar to shipping with the following tabs:
#Authentication
#Cloud Services [future]
#Communications [future]
#Infrastructure [future]
#Native Platforms
#Payments [future]
#Other [future]

		my @PLUGINS = ();
		my $PLUGINS = $gref->{'%plugins'} || {};
		foreach my $k (keys %{$PLUGINS}) {
			my $ref = $PLUGINS->{$k};
			$ref->{'plugin'} = $k;
			$ref->{'global'} = 1;
			$ref->{'enable'} = int($ref->{'enable'});
			push @PLUGINS, $ref;
			}

		if (1) {
			my ($ref) = $webdbref->{'%plugin.auth_google'};
			if (not defined $ref) { $ref = {}; }
			$ref->{'plugin'} = 'auth_google';
			$ref->{'enable'} = int($ref->{'enable'});
			## 
			push @PLUGINS, $ref;
			}

		if (1) {
			my ($ref) = $webdbref->{'%plugin.auth_facebook'};
			if (not defined $ref) { $ref = {}; }
			$ref->{'plugin'} = 'auth_facebook';
			$ref->{'enable'} = int($ref->{'enable'});
			## appid appsecret
			push @PLUGINS, $ref;
			}

		if (1) {
			my ($ref) = $webdbref->{'%plugin.client_android'};
			if (not defined $ref) { $ref = {}; }
			$ref->{'plugin'} = 'platform_android';
			$ref->{'enable'} = int($ref->{'enable'});
			## apikey
			push @PLUGINS, $ref;
			}

		if (1) {
			my ($ref) = $webdbref->{'%plugin.client_appleios'};
			if (not defined $ref) { $ref = {}; }
			$ref->{'plugin'} = 'platform_appleios';
			$ref->{'enable'} = int($ref->{'enable'});
			## cert, key, password
			push @PLUGINS, $ref;
			}

		if (1) {
			my ($ref) = $webdbref->{'%plugin.esp_awsses'};
			if (not defined $ref) { $ref = {}; }
			$ref->{'plugin'} = 'esp_awsses';
			$ref->{'enable'} = int($ref->{'enable'});
			## cert, key, password
			push @PLUGINS, $ref;
			}

		$R{'@PLUGINS'} = \@PLUGINS;
		}


	if ($v->{'order'}) {
		my $order_num = &CART2::next_id($self->username(),1);
		(undef,undef,$order_num) = split(/-/,$order_num,3);
		$order_num -= 1;
		$R{'%ORDER'} = {
			'sequence'=>$order_num
			};
		}

	if ($v->{'wms'}) {
		$R{'%WMS'} = {
			'active'=>$gref->{'wms'}
			};
		}

	if ($v->{'erp'}) {
		$R{'%ERP'} = {
			'active'=>$gref->{'erp'}
			};
		}

	if ($v->{'crm'}) {
		my $CRM = &ZTOOLKIT::parseparams($webdbref->{'crmtickets'});
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select EMAIL_ADDRESS,EMAIL_CLEANUP,TICKET_COUNT,TICKET_SEQ from CRM_SETUP where MID=$MID /* $USERNAME */ and PRT=$PRT";
		my ($crm_ref) = $udbh->selectrow_hashref($pstmt);
		foreach my $k (keys %{$crm_ref}) {
			$CRM->{ lc($k) } = $crm_ref->{$k};
			}
		&DBINFO::db_user_close();
		$R{'%CRM'} = $CRM;
		}

	if ($v->{'account'}) {
		require ACCOUNT;
		my %ref = ();
		my ($ACCT) = ACCOUNT->new($USERNAME,$LUSERNAME); 
		foreach my $k (keys %ACCOUNT::VALID_FIELDS) {
			my ($group,$groupfield) = split(/\./,$k,2);
			if (not defined $ref{$group}) { $ref{$group} = {}; }
			$ref{$group}->{$groupfield} = $ACCT->get($k);
			}
		$R{'%ACCOUNT'} = \%ref;
		}


	## TAX
	if ($v->{'tax-rules-raw'}) {
		$R{'tax-rules-raw'} = &ZOOVY::incode($webdbref->{'tax_rules'});
		}

	if ($v->{'taxes'}) {
		my @MSGS = ();

		my $csv = Text::CSV_XS->new ();
		##
		## tax is a csv, one per line:
		##	0 = type
		## 1 = match value
		## 2 = rate
		##	3 = bwvalue
		## 4 = zone (comment/hint)
		## 5 = expires
		##

		my @TAXES = ();
		$R{'@TAXES'} = \@TAXES;
		my $count = 0;
		my %USED_ZIPS = ();
		my $row = 0;
		foreach my $line (split(/[\n\r]+/,$webdbref->{'tax_rules'})) {
			my $status  = $csv->parse($line);       # parse a CSV string into fields
			my @data = $csv->fields();           # get the parsed fields
			my %rule = (
				'guid'=>$row,
				'type'=>$data[0],
				'match'=>$data[1],
				'rate'=>$data[2],
				'enable'=>$data[3],
				'zone'=>$data[4],
				'expires'=>$data[5],
				'group'=>$data[6],
				);

			if ($data[0] eq 'state') { $rule{'state'} = $rule{'match'}; }
			if ($data[0] eq 'city') { ($rule{'citys'},$rule{'city'}) = split(/\+/,$rule{'match'}); }
			if ($data[0] eq 'zipspan') { ($rule{'zipstart'},$rule{'zipend'}) = split(/\-/,$rule{'match'},2); }
			if ($data[0] eq 'zip4') { $rule{'zip4'} = $rule{'match'}; }
			if ($data[0] eq 'country') { $rule{'country'} = $rule{'match'}; }
			if ($data[0] eq 'intprovince') { ($rule{'ipcountry'},$rule{'ipstate'}) = split(/\+/,$rule{'match'},2); }
			if ($data[0] eq 'intzip') { ($rule{'izcountry'},$rule{'izzip'}) = split(/\+/,$rule{'match'},2); }

			$rule{'enable_handling'} = ($rule{'enable'}&2)?2:0;
			$rule{'enable_shipping'} = ($rule{'enable'}&4)?4:0;
			$rule{'enable_insurance'} = ($rule{'enable'}&8)?8:0;
			$rule{'enable_special'} = ($rule{'enable'}&16)?16:0;

			$row++;
			push @TAXES, \%rule;
			}
		}



	if ($v->{'domains'}) {
		my @domains = &DOMAIN::TOOLS::domains($USERNAME);
		my @DOMAINS = ();
		foreach my $dname (sort @domains) {
			my %ROW = ();
			my ($D) = DOMAIN->new($USERNAME,$dname);
			my $prt = int($D->prt());
			my $domainname = $D->domainname();

			## don't show redirect domains in the list.
			## next if ($d->{'HOST_TYPE'} eq 'REDIR');

			#my $nsref = &ZOOVY::fetchmerchantns_ref($USERNAME,$ns);
			$ROW{'image'} = $D->get('our/logo_website');
			#foreach my $host ('WWW','M','APP') {
			#	my $params = &ZTOOLKIT::parseparams($D->{"$host\_CONFIG"});
			#	$ROW{'%'.$host} = $params;
			#	}
			}
		$R{'@DOMAINS'} = \@DOMAINS;
		}

	## PROFILES (pulled from /biz/sites)
	if ($v->{'profiles'}) {
		my @domains = &DOMAIN::TOOLS::domains($USERNAME);
		my @PROFILES = ();
		my %DOMAIN_TO_PROFILE = ();
		foreach my $dname (@domains) {
			my ($d) = DOMAIN->new($USERNAME,$dname);
			my $ns = $d->{'PROFILE'};

			## skip domains that don't have a profile selected
			next if ($ns eq '');
			## my $nsref = &ZOOVY::fetchmerchantns_ref($USERNAME,$ns);
			push @PROFILES, { 'NS'=>$ns, 'DOMAIN'=>$d->domainname(), 'PRT'=>$d->prt(), 'DATA'=>$d->as_legacy_nsref() };
			}
		$R{'@PROFILES'} = \@PROFILES;
		}


	## SEARCH!
	if ($v->{'search'}) {
		my $USER_PATH = &ZOOVY::resolve_userpath($USERNAME);	
		if (-f "$USER_PATH/elasticsearch-product-synonyms.txt") {
			$R{'elasticsearch-product-synonyms.txt'} = File::Slurp::read_file("$USER_PATH/elasticsearch-product-synonyms.txt") ;
			}
		if (-f "$USER_PATH/elasticsearch-product-stopwords.txt") {
			$R{'elasticsearch-product-stopwords.txt'} = File::Slurp::read_file("$USER_PATH/elasticsearch-product-stopwords.txt") ;
			}
		if (-f "$USER_PATH/elasticsearch-product-charactermap.txt") {
			$R{'elasticsearch-product-charactermap.txt'} = File::Slurp::read_file("$USER_PATH/elasticsearch-product-charactermap.txt") ;
			}

		require PRODUCT::FLEXEDIT;
		my ($gref) = $self->globalref();
		my @FIELDS = ();
		if (defined $gref->{'@flexedit'}) {
			foreach my $set (@{$gref->{'@flexedit'}}) {
				next unless (defined $set->{'index'});
				if (defined $PRODUCT::FLEXEDIT::fields{$set->{'id'}}) {
					## copy custom fields into global.bin ex: type, options, etc.
					foreach my $k (keys %{$PRODUCT::FLEXEDIT::fields{$set->{'id'}}}) {
						next if (defined $set->{$k});
						$set->{$k} = $PRODUCT::FLEXEDIT::fields{$set->{'id'}}->{$k};
						}
					}
				push @FIELDS, $set;	
				}	
			}

		if (scalar(@FIELDS)==0) {
			$R{'@INDEX_ATTRIBUTES'} = [];
			}
		else {
			$R{'@INDEX_ATTRIBUTES'} = \@FIELDS;
			}
		}
	
	## INVENTORY!
	if ($v->{'inventory'}) {
		$R{'%INVENTORY'} = {
			'inv_mode'=>$gref->{'inv_mode'},
		#	'inv_notify'=>$gref->{'inv_notify'},
			'inv_website_remove'=>($gref->{'inv_rexceed_action'})?1:0,
			}
		}

	## BLAST SETTINGS 
	if ($v->{'blast'}) {
		my ($webdb) = $self->webdbref();
		$R{'%BLAST'} = {
			'from_email'=>sprintf("%s",$webdb->{'from_email'}),
			};
		}

	## 'prt'
	if ($v->{'prts'}) {
		my $i = 0;
		foreach my $prt ( @{$gref->{'@partitions'}} ) {
			$prt->{'id'} = $i;
			if (not defined $prt->{'p_navcats'}) { $prt->{'p_navcats'}=0; }
			if (not defined $prt->{'p_customers'}) { $prt->{'p_customers'}=$i; }
			## update the website dbref
			my ($dbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$i);

#			my $nsref = &ZOOVY::fetchmerchantns_ref($USERNAME,$prt->{'profile'});
#			$nsref->{'prt:id'} = $i;
			my @domains = DOMAIN::list($USERNAME,PRT=>$i - $JSONAPI::PARTITION_OFFSET);	
			$i++;
			push @{$R{'@PRTS'}}, $prt;
			}
		}


	if ($v->{'coupons'}) {
		my @MSGS = ();
		require CART::COUPON;
		my $results = CART::COUPON::list($webdb);	
		if ( (my $sizeof = &ZOOVY::sizeof($results)) > 100000) {
			push @MSGS, "WARNING|You have $sizeof bytes allocated to coupons - which is more than recommended 100,000 bytes of coupons.\n\nTry and reduce the number and/or size of each coupon.";
			}
		if ( (my $count = scalar(@{$results})) >200) {
			push @MSGS, "WARNING|You have $count coupons - this more than the recommended 250 coupons.\n\nThis number seems excessive, you're probably using coupons in a way other than how they were intended.";
			}
		my @COUPONS = ();
		foreach my $cpnref (@{$results}) {
			## upgrade 'code' to 'coupon'
			$cpnref->{'coupon'} = $cpnref->{'code'};  
			delete $cpnref->{'code'};
		
			my ($cpnref) = &CART::COUPON::load($webdb,$cpnref->{'coupon'});
#			if (not defined $cpnref) {
#				$cpnref->{'coupon'} = $cpnref->{'coupon'};
#				}

			## 201334 uses these values:		
			$cpnref->{'expires_ts'} = $self->dateify('gmt'=>$cpnref->{'expires_gmt'});
			$cpnref->{'modified_ts'} = $self->dateify('gmt'=>$cpnref->{'modified_gmt'});
			$cpnref->{'created_ts'} = $self->dateify('gmt'=>$cpnref->{'created_gmt'});
			$cpnref->{'begins_ts'} = $self->dateify('gmt'=>$cpnref->{'begins_gmt'});
			push @COUPONS, $cpnref;

			my $COUPON = $cpnref->{'coupon'};
			my @rules = &ZSHIP::RULES::export_rules($webdb,"COUPON-$COUPON");
			if ( (my $sizeof = &ZOOVY::sizeof(\@rules)) > 2500) {
				push @MSGS, "WARNING|This coupon is more than 2500 bytes. Try using product tagging to reduce the size of the coupon and get some performance.";
				}
			$cpnref->{'@RULES'} = \@rules;
			}		
		$R{'@COUPONS'} = \@COUPONS;
		}


	if ($v->{'shipping'}) {
		## REMINDER: U/I should include:
		## "WARN|Paypal Express checkout, Google Checkout, and Checkout by Amazon use the respective fraud filters for each payment type, purchasers will be able to place orders that avoid this block list (refer to each payment types individual fraud policies.)";

		$R{'%SHIPPING'} = {};
		$R{'primary_shipper'} = $webdb->{'primary_shipper'};

		foreach my $k ('ship_int_risk','ship_origin_zip','ship_latency','ship_cutoff') {
			$R{$k} = $webdbref->{$k};
			}

		my @BANNED = ();
		foreach my $line (split(/[\n\r]+/,$webdbref->{'banned'})) {
			my ($type,$match,$created) = split(/\|/,$line);
			push @BANNED, { 'type'=>$type, 'match'=>$match, 'created'=>$created };
			}
		$R{'%SHIPPING'}->{'@BANNED'} = \@BANNED;
		
		my @BLACKLIST = ();
		foreach my $isox (split(/,/,$webdbref->{'ship_blacklist'})) {
			next if ($isox eq '');
			push @BLACKLIST, $isox;
			}
		$R{'%SHIPPING'}->{'@BLACKLIST'} = \@BLACKLIST;
		}
	
	
	if ($v->{'schedules'}) {
		require WHOLESALE;
		$R{'@SCHEDULES'} = &WHOLESALE::list_schedules($USERNAME);
		}

	my @SHIPMETHODS = ();
	if ($v->{'shipmethods'}) {
		require ZSHIP;
		$R{'@SHIPMETHODS'} = \@SHIPMETHODS;

		## TODO: go through suppliers and load settings per supplier
		#$S = SUPPLIER->new($USERNAME, $SUPPLIER_ID);
		#my $params = ZTOOLKIT::parseparams($S->fetch_property(".ship.meter"));
	
		## FEDEX
		require ZSHIP::FEDEXWS;
		my ($fdxcfg) = ZSHIP::FEDEXWS::load_webdb_fedexws_cfg($USERNAME,$PRT,$webdbref);
		$fdxcfg->{'dom.evening'} = $fdxcfg->{'dom.home_eve'}; delete $fdxcfg->{'dom.home_eve'};
		foreach my $k (keys %{$fdxcfg}) {
			# change fedex.meter to fedex__meter
			my $outk = $k;
			$outk =~ s/\./_/gs;		
			if ($outk ne $k) { $fdxcfg->{ $outk } = $fdxcfg->{$k};  delete $fdxcfg->{$k}; }
			}

		$fdxcfg->{'dom'} = (($fdxcfg->{'enable'}&1)?1:0);
		$fdxcfg->{'int'} = (($fdxcfg->{'enable'}&2)?2:0);
		$fdxcfg->{'provider'} = 'FEDEX';
		foreach my $ruleset (
			'DOM','DOM_NEXTEARLY','DOM_NEXTNOON','DOM_NEXTDAY','DOM_2DAY','DOM_3DAY','DOM_GROUND','DOM_HOME_EVE','DOM_HOME',
			'INT','INT_NEXTEARLY','INT_NEXTNOON','INT_2DAY','INT_GROUND') {
			my @rules = &ZSHIP::RULES::export_rules($webdb,"SHIP-FEDEXAPI_$ruleset");
			if ($ruleset eq 'DOM_HOME_EVE') { 
				$fdxcfg->{"\@DOM_EVENING"} = \@rules;
				}
			else {
				$fdxcfg->{"\@$ruleset"} = \@rules;	
				}
			}
		push @SHIPMETHODS, $fdxcfg;
		## TBD: 
		## ($fdxcfg) = ZSHIP::FEDEXWS::load_supplier_fedexws_cfg($USERNAME,$SUPPLIER_ID,$webdbref);	

		## USPS
		my %usps = ();
		$usps{'provider'} = 'USPS';
		foreach my $k ('usps_dom','usps_int',
							'usps_dom_express','usps_dom_priority','usps_dom_bulkrate',
							'usps_int_parcelpost','usps_int_priority','usps_int_express','usps_int_expressg') {
			$usps{$k} = $webdbref->{$k};
			foreach my $k ('usps_int_priority','usps_int_express','usps_int_expressg') {
				foreach my $kb (1,2,4) {
					$usps{$k.'_'.$kb} = ($usps{$k} & $kb)?$kb:0;
					}
				}
			}

		foreach my $ruleset ('DOM','INT') {
			my @rules = &ZSHIP::RULES::export_rules($webdb,"SHIP-USPS_$ruleset");
			$usps{"\@$ruleset"} = \@rules;
			}

		push @SHIPMETHODS, \%usps;

		require ZSHIP::UPSAPI;
		my %ups = ();
		$ups{'provider'} = 'UPS';
		$webdb = &ZSHIP::UPSAPI::upgrade_webdb($webdb);
		## $webdb->{'upsapi_config'} = %2elicense=xxxx&%2epassword=xxxxx&%2eshipper_number=xxxxxx&%2euserid=xxxxx
		my $UPS_CONFIG = &ZTOOLKIT::parseparams($webdb->{'upsapi_config'});
		$ups{'%HASH'} = $UPS_CONFIG;
		foreach my $k (keys %{$UPS_CONFIG}) { 
			if (substr($k,0,1) eq '.') {
				$ups{substr($k,1)} = $UPS_CONFIG->{$k};
				}
			else {
				$ups{$k} = $UPS_CONFIG->{$k}; 
				}
			}
		$ups{'dom'} = $ups{'enable_dom'}; delete $ups{'enable_dom'};
		$ups{'int'} = $ups{'enable_int'}; delete $ups{'enable_int'};
		foreach my $k (values %ZSHIP::UPSAPI::DOM_METHODS) {
			## dom_gnd is set to GND
			$ups{lc(sprintf("dom_%s",$k))} = $ups{$k};
			delete $ups{$k};
			}
		foreach my $k (values %ZSHIP::UPSAPI::INT_METHODS) {
			## int_std is set to STD
			$ups{lc(sprintf("int_%s",$k))} = $ups{$k};
			delete $ups{$k};
			}
		
		foreach my $ruleset (
			'DOM','DOM_GND','DOM_3DS','DOM_2DA','DOM_2DM','DOM_1DP','DOM_1DA','DOM_1DM',
			'INT','INT_STD','INT_XPR','INT_XDM','INT_XPD') {
			my @rules = &ZSHIP::RULES::export_rules($webdb,"SHIP-UPSAPI_$ruleset");
			$ups{"\@$ruleset"} = \@rules;
			}
		$ups{'%DEBUG'} = $UPS_CONFIG;
		push @SHIPMETHODS, \%ups;

		## UNIVERSAL FLAT RATE METHODS (universal)
		my $methods = &ZWEBSITE::ship_methods($webdb);
		## now go through each method (so we do this 3 times, or once per region)
		foreach my $m (@{$methods}) {
			#          {
			#            'country' => 'US',
			#            'price1' => '2.81',
			#            'name' => 'USPS: First Class',
			#            'carrier' => '',
			#            'handler' => 'WEIGHT',
			#            'weight' => '5',
			#            'id' => 'WEIGHT_US_0'
			#          }

			# next if ($m->{'region'} ne $region);	
			my $summary = '';
			if ($m->{'handler'} eq 'FIXED') {
				$summary = '';
				}
			elsif ($m->{'handler'} eq 'WEIGHT') {
				my @ROWS = ();
				my $hashref = &ZTOOLKIT::parseparams($m->{'data'});
				foreach my $k (sort { $a <=> $b; } keys %{$hashref}) { 
					push @ROWS, { 'guid'=>$k, 'weight'=>$k, 'fee'=>$hashref->{$k} };
					};
				$m->{'min_wt'} = &ZSHIP::smart_weight($m->{'min_wt'});
				$m->{'@TABLE'} = \@ROWS;
				# $summary = 'Range: '.$m->{'min_wt'}.'oz to '.$max.'oz';
				}
			elsif ($m->{'handler'} eq 'PRICE') {
				my @ROWS = ();
				my $hashref = &ZTOOLKIT::parseparams($m->{'data'});
				foreach my $k (sort { $a <=> $b; } keys %{$hashref}) { 
					push @ROWS, { 'guid'=>$k, 'subtotal'=>$k, 'fee'=>$hashref->{$k} };
					};
				$m->{'min_price'} = sprintf("%.2f",$m->{'min_price'});
				$m->{'@TABLE'} = \@ROWS;
				# $summary = 'Range: '.$m->{'min_wt'}.'oz to '.$max.'oz';
				}
			elsif ($m->{'handler'} eq 'LOCAL') {
				my @ROWS = ();
				my $hashref = &ZTOOLKIT::parseparams($m->{'data'});
				foreach my $k (sort { $a <=> $b; } keys %{$hashref}) {
					my ($range) = $hashref->{$k};
					my ($startzip,$endzip) = split(/-/,$k);
					push @ROWS, { 'guid'=>$k, 'zip1'=>$startzip, 'zip2'=>$endzip, 'fee'=>$hashref->{$k} };
					}
				$m->{'@TABLE'} = \@ROWS;
				# $summary = 'Range: '.$m->{'min_wt'}.'oz to '.$max.'oz';
				}
			elsif ($m->{'handler'} eq 'LOCAL_CANADA') {
				my @ROWS = ();
				my $hashref = &ZTOOLKIT::parseparams($m->{'data'});
				foreach my $zippattern (sort keys %{$hashref}) {
					my ($fee,$instructions) = split(/\|/,$hashref->{$zippattern},2);
					my $outputzip = sprintf("%s %s",substr($zippattern,0,3),substr($zippattern,3));
					push @ROWS, { 'guid'=>$zippattern, 'fee'=>$fee, 'txt'=>$instructions, 'postal'=>$zippattern };
					}
				$m->{'@TABLE'} = \@ROWS;
				# $summary = 'Range: '.$m->{'min_wt'}.'oz to '.$max.'oz';
				}

			$m->{'provider'} = sprintf("FLEX:%s",$m->{'id'});
			# $m->{'enable'} = ($m->{'active'}?0:1);			## note: at one point this was 'active' (not sure when/if that changed)
	
			my @MSGS = ();
			if ($m->{'carrier'} eq '') {
				push @MSGS, "using carrier codes can improve your shipping efficiency.";
				}
			elsif ($m->{'carrier'} eq 'FOO') {
				push @MSGS, "carrier code \"FOO\" is a placeholder and doesn't actually work! You should probably change it.";
				}

			my @AVAILABLE_REGIONS = (
				['US','United States'],
				['CA','Canada'],
				['INT','International']
				);
			if ($m->{'handler'} eq 'LOCAL') {
				@AVAILABLE_REGIONS = ( ['US','United States'] );
				}
			if ($m->{'handler'} eq 'LOCAL_CANADA') {
				@AVAILABLE_REGIONS = ( ['CA', 'Canada'] );
				}
			$m->{'@REGIONS'} = \@AVAILABLE_REGIONS;			
			if ($m->{'enable'}==0) {	
				push @MSGS, "WARN|This method is currently not enable and will be ignored except during tests.";
				}		

			my $WEBDBKEY = uc(sprintf("SHIP-%s",$m->{'id'}));
			my @rules = &ZSHIP::RULES::export_rules($webdb,$WEBDBKEY);
			$m->{'@RULES'} = \@rules;

			if (scalar(@MSGS)) { $m->{'@MSGS'} = \@MSGS; }
			push @SHIPMETHODS, $m;
			}


		## HANDLING
		my %handling = ();
		$handling{'provider'} = 'HANDLING';
		$handling{'enable'} = $webdb->{'handling'};
		$handling{'product'} = int($webdb->{'hand_product'});		## bitwise
		$handling{'flat'} = ($webdb->{'hand_flat'})?1:0;
		foreach my $k ('hand_dom_item1','hand_can_item1','hand_int_item1','hand_dom_item2','hand_can_item2','hand_int_item2') {
			my $kk = substr($k,5); 	# strip hand_
			$handling{$kk} = $webdb->{$k};
			}				
		$handling{'enable_weight_table'} = ($webdb->{'hand_weight'})?1:0;
		foreach my $k ('hand_weight_dom','hand_weight_can','hand_weight_int') {
			my $TB = undef;
			if ($k eq 'hand_weight_dom') { $TB = 'WEIGHT_US'; }
			if ($k eq 'hand_weight_can') { $TB = 'WEIGHT_CA'; }
			if ($k eq 'hand_weight_int') { $TB = 'WEIGHT_INT'; }
			my $ref = &ZTOOLKIT::parseparams($webdb->{$k});
			my @ROWS = ();
			foreach my $oz (sort { $a <=> $b; } keys %{$ref}) {
				push @ROWS, { 'guid'=>$oz, 'weight'=>$oz, 'fee'=>$ref->{$oz} };
				}
			$handling{sprintf("\@%s",$TB)} = \@ROWS;
			}
		my @RULES = &ZSHIP::RULES::export_rules($webdb,"SHIP-HANDLING");
		$handling{'@RULES'} = \@RULES;
		push @SHIPMETHODS, \%handling;


		## INSURANCE
		my %insurance = ();
		$insurance{'provider'} = 'INSURANCE';
		$insurance{'enable'} = $webdb->{'insurance'};
		foreach my $k ('ins_optional','ins_flat','ins_product','ins_dom_item1','ins_dom_item2','ins_can_item1','ins_can_item2',	'ins_int_item1','ins_int_item2') { 
			my $kk = substr($k,4);
			$insurance{$kk} = $webdb->{$k}; 
			}
		$insurance{'enable_weight_table'} = ($webdb->{'ins_weight'})?1:0;
		foreach my $k ('ins_weight_dom','ins_weight_can','ins_weight_int') {
			# $insurance{$k} = $webdb->{$k};
			my $TB = undef;
			if ($k eq 'ins_weight_dom') { $TB = 'WEIGHT_US'; }
			if ($k eq 'ins_weight_can') { $TB = 'WEIGHT_CA'; }
			if ($k eq 'ins_weight_int') { $TB = 'WEIGHT_INT'; }
			my $ref = &ZTOOLKIT::parseparams($webdb->{$k});
			my @ROWS = ();
			foreach my $oz (sort { $a <=> $b; } keys %{$ref}) {
				push @ROWS, { 'guid'=>$oz, 'weight'=>$oz, 'fee'=>$ref->{$oz} };
				}
			$insurance{sprintf("\@%s",$TB)} = \@ROWS;
			}
		$insurance{'enable_price_table'} = ($webdb->{'ins_price'})?1:0;
		foreach my $k ('ins_price_dom','ins_price_can','ins_price_int') {
			# $insurance{$k} = $webdb->{$k};
			my $TB = undef;
			if ($k eq 'ins_price_dom') { $TB = 'PRICE_US'; }
			if ($k eq 'ins_price_can') { $TB = 'PRICE_CA'; }
			if ($k eq 'ins_price_int') { $TB = 'PRICE_INT'; }
			my $ref = &ZTOOLKIT::parseparams($webdb->{$k});
			my @ROWS = ();
			foreach my $price (sort { $a <=> $b; } keys %{$ref}) {
				push @ROWS, { 'guid'=>$price, 'subtotal'=>$price, 'fee'=>$ref->{$price} };
				}
			$insurance{sprintf("\@%s",$TB)} = \@ROWS;
			}

		@RULES = &ZSHIP::RULES::export_rules($webdb,"SHIP-INSURANCE");
		$insurance{'@RULES'} = \@RULES;
		push @SHIPMETHODS, \%insurance;
		## RE: WHOLESALE
		#			push @MSGS, qq~WARN|+NOTE: the 'Any' setting requires a schedule be set.\n\n
		#If no schedule is set the rule will be ignored/skipped.<br>
		#The Match_All is provided as a convenience shortcut rule for stores that have many pricing schedules, <br>
		#but desire to have only one set of rules for all schedules.<br>
		#MOST IMPORTANTLY: If a customer does NOT have schedule pricing, the "Any" setting will NOT apply the rule.
		#</div>~;	
		}


	if ($v->{'payment'}) {
		$R{'@PAYMENTS'} = [];

		## CREDIT CARD
		my %CC_PAYMENT = ();	
		$CC_PAYMENT{'tender'} = 'CC'; 
		$CC_PAYMENT{'enable'} = int($webdbref->{'pay_credit'});
		$CC_PAYMENT{'processor'} = $webdbref->{'cc_processor'};
		if ($CC_PAYMENT{'processor'} eq '') { $CC_PAYMENT{'processor'} = 'NONE'; }
		foreach my $k (
			'cc_avs_review','cc_cvv_review','cc_cvvcid','cc_instant_capture',
			'cc_type_visa','cc_type_mc','cc_type_amex','cc_type_novus'
			) {
			$CC_PAYMENT{$k} = $webdbref->{$k};
			}
  
		my $feesref = &ZTOOLKIT::parseparams($webdbref->{'cc_fees'});
		foreach my $k (keys %{$feesref}) { $CC_PAYMENT{$k} = $feesref->{$k}; }
		my @SPECIAL = ();
		if ($CC_PAYMENT{'processor'} eq 'MANUAL') {
			push @SPECIAL, 'cc_emulate_gateway';
			}
		if ($CC_PAYMENT{'processor'} eq 'SKIPJACK') {
			push @SPECIAL, 'skipjack_htmlserial';
			}
		if ($CC_PAYMENT{'processor'} eq 'VERISIGN') {
			push @SPECIAL, 'verisign_username';
			push @SPECIAL, 'verisign_partner';
			push @SPECIAL, 'verisign_vendor';
			}
		if ($CC_PAYMENT{'processor'} eq 'ECHO') {
			push @SPECIAL, 'echo_cybersource';
			push @SPECIAL, 'echo_username';
			push @SPECIAL, 'echo_password';
			}
		if ($CC_PAYMENT{'processor'} eq 'AUTHORIZENET') {
			push @SPECIAL, 'authorizenet_username';
			push @SPECIAL, 'authorizenet_password';
			push @SPECIAL, 'authorizenet_key';
			}
		if ($CC_PAYMENT{'processor'} eq 'PAYPALWP') {
			push @SPECIAL, 'paypal_email';
			}
		if ($CC_PAYMENT{'processor'} eq 'TESTING') {
			require ZPAY::TESTING;
			$CC_PAYMENT{'@TEST_CARDS'} = \@ZPAY::TESTING::CARDS;
			}
		if ($CC_PAYMENT{'processor'} eq 'LINKPOINT') {
			my $pemfile = &ZOOVY::resolve_userpath($USERNAME) . "/linkpoint.pem";
			## .pem files must be installed by support, currently account wide (should probably be user-uploadable and one per partition/payment type)
			$CC_PAYMENT{'pem_installed'} = (!-f $pemfile)?1:0;
			push @SPECIAL, 'storename';
			}
		foreach my $k (@SPECIAL) {
			$CC_PAYMENT{$k} = $webdbref->{$k};
			}
		if ($CC_PAYMENT{'processor'} ne 'NONE') {
			push @{$R{'@PAYMENTS'}}, \%CC_PAYMENT;
			}

		## ECHECK
		my %ECHK_PAYMENT = ();
		$ECHK_PAYMENT{'tender'} = 'ECHECK'; 
		$ECHK_PAYMENT{'enable'} = int($webdbref->{'pay_echeck'});
		$ECHK_PAYMENT{'processor'} = $webdbref->{'echeck_processor'};
		foreach my $k ('echeck_payable_to') {
			$ECHK_PAYMENT{$k} = $webdbref->{$k};
			}
		if ($ECHK_PAYMENT{'processor'} eq '') { $ECHK_PAYMENT{'processor'} = 'NONE'; }
		if ($ECHK_PAYMENT{'processor'} ne 'NONE') {
			push @{$R{'@PAYMENTS'}}, \%ECHK_PAYMENT;
			}
	
		## AMZ PAY
		my %AMZ_PAYMENT = ();
		$AMZ_PAYMENT{'enable'} = int($webdbref->{'amzpay_env'}>0)?1:0;
		$AMZ_PAYMENT{'amzpay_env'} = $webdbref->{'amzpay_env'};		## 0=disable, 1=sandbox, 2=production
		$AMZ_PAYMENT{'tender'} = 'AMZCBA';
		require ZPAY::AMZPAY;
		foreach my $k ('amz_merchantid','amz_accesskey','amz_secretkey','amzpay_button') {
			$AMZ_PAYMENT{$k} = $webdbref->{$k};
			}
		#if ($AMZ_PAYMENT{'enable'}) {
		my $buttonref = &ZTOOLKIT::parseparams($webdb->{'amzpay_button'});
		foreach my $k ('color','size','background') {
			## color, size, background
			$AMZ_PAYMENT{$k} = $buttonref->{$k};
			}

		if (1) {
			my ($CART2) = CART2->new_memory($USERNAME,$PRT);
			$AMZ_PAYMENT{'button_html'} = &ZPAY::AMZPAY::button_html($CART2,$self->SITE());
			push @{$R{'@PAYMENTS'}}, \%AMZ_PAYMENT;
			}

		my %GOOGLE_PAYMENT = ();
		$GOOGLE_PAYMENT{'enable'} = int($webdbref->{'google_api_env'});
		$GOOGLE_PAYMENT{'tender'} = 'GOOGLE';
		# $GOOGLE_PAYMENT{'callback_url'} = "https://webapi.zoovy.com/webapi/google/callback.pl/u=$USERNAME/v=1";
		foreach my $k ('google_merchantid','google_key','google_dest_zip','google_api_analytics','google_api_env','google_api_merchantcalc','google_int_shippolicy','google_tax_tables','google_pixelurls') {
			$GOOGLE_PAYMENT{$k} = $webdbref->{$k};
			}
		$GOOGLE_PAYMENT{'@WARNINGS'} = [];
		my $has_bad_pixel = 0;
		if ($webdbref->{'google_pixelurls'} =~ /\<parameterized\-url/s) {
			push @{$GOOGLE_PAYMENT{'@WARNINGS'}}, "WARNING|The tag 'parameterized-url' appears the Pixel URL field, this is almost certainly not correct and will not work.";
			$has_bad_pixel++;
			}
		if ($webdbref->{'google_pixelurls'} =~ /\<input/s) {
			push @{$GOOGLE_PAYMENT{'@WARNINGS'}}, "WARNING|The xml/html tag 'input' appears the Pixel URL field, this absolutely not correct and will not work. ";
			$has_bad_pixel++;
			}
		if ($webdbref->{'google_pixelurls'} =~ /<.*?>/s) {
			push @{$GOOGLE_PAYMENT{'@WARNINGS'}}, "WARNING|It appears there is HTML or XML in the Pixel URL field. This is most likely incorrect and probably won't work, and it will probably break google checkout.";
			$has_bad_pixel++;
			}
		if ($has_bad_pixel) {
			push @{$GOOGLE_PAYMENT{'@WARNINGS'}}, "WARNING|You definitely have one or more issues with your Pixel URL (because you didn't create a URL at all and gave us XML/HTML instead), the documentation you are using is wrong/outdated and probably not written for Zoovy anyway.  The standard way Google provides examples make their integration only compatible with ONE PIXEL -- since many of our clients need MORE THAN ONE PIXEL -- we had to build something different - please refer to webdoc #50737";
			}
		my $i = 0;
		foreach my $line (split(/[\n\r]+/,$webdbref->{'tax_rules'})) {
			next if (($line eq '') || (substr($line,0,1) eq '#'));
			$i++;
			}	
		if ($i>100) {
			push @{$GOOGLE_PAYMENT{'@WARNINGS'}}, "WARNING|You have more than 100 tax rules, GoogleCheckout will only utilize the first 100";
			}
		# if ($GOOGLE_PAYMENT{'enable'}) {
		if (1) {
			push @{$R{'@PAYMENTS'}}, \%GOOGLE_PAYMENT;
			}
		
		if ($webdbref->{"pay_custom"}) {
			my %PAYMENT = ();
			$PAYMENT{'enable'} = int($webdbref->{"pay_custom"});
			$PAYMENT{'tender'} = 'CUSTOM';
			$PAYMENT{'pay_custom_desc'} = $webdbref->{'pay_custom_desc'};
			push @{$R{'@PAYMENTS'}}, \%PAYMENT;
			}
		
		## WALLET-PAYPAL
		if (1) {
			my %PAYPAL_PAYMENT = ();
			$PAYPAL_PAYMENT{'tender'} = 'PAYPALEC';
			$PAYPAL_PAYMENT{'enable'} = int($webdbref->{'paypal_api_env'});
			$PAYPAL_PAYMENT{'capture'} = $webdbref->{'cc_instant_capture'};
			foreach my $k ('paypal_email','paypal_api_env','paypal_api_user','paypal_api_pass','paypal_api_sig','paypal_api_reqconfirmship','paypal_api_callbacks','paypal_paylater') {
				$PAYPAL_PAYMENT{$k} = $webdbref->{$k};
				}
			push @{$R{'@PAYMENTS'}}, \%PAYPAL_PAYMENT;
			}

		# if (int($webdbref->{"pay_po"})){
		if (1) {
			my %PAYMENT = ();
			$PAYMENT{'enable'} = int($webdbref->{"pay_po"});
			$PAYMENT{'tender'} = 'PO';
			$PAYMENT{'payable_to'} = $webdbref->{'payable_to'};
			push @{$R{'@PAYMENTS'}}, \%PAYMENT;
			}

		#if ($webdbref->{"pay_mo"}) {
		if (1) {
			my %PAYMENT = ();
			$PAYMENT{'enable'} = int($webdbref->{"pay_mo"});
			$PAYMENT{'tender'} = 'MO';
			$PAYMENT{'payable_to'} = $webdbref->{'payable_to'};
			push @{$R{'@PAYMENTS'}}, \%PAYMENT;
			}

		#if ($webdbref->{"pay_cash"}) {
		if (1) {
			my %PAYMENT = ();
			$PAYMENT{'enable'} = int($webdbref->{"pay_cash"});
			$PAYMENT{'tender'} = 'CASH';
			push @{$R{'@PAYMENTS'}}, \%PAYMENT;
			}

		#if ($webdbref->{"pay_pickup"}) {
		if (1) {
			my %PAYMENT = ();
			$PAYMENT{'enable'} = int($webdbref->{"pay_pickup"});
			$PAYMENT{'tender'} = 'PICKUP';
			push @{$R{'@PAYMENTS'}}, \%PAYMENT;
			}

		#if ($webdbref->{"pay_giftcard"}) {
		if (1) {
			my %PAYMENT = ();
			$PAYMENT{'enable'} = int($webdbref->{"pay_giftcard"});
			$PAYMENT{'tender'} = 'GIFTCARD';
			push @{$R{'@PAYMENTS'}}, \%PAYMENT;
			}

		#if ($webdbref->{"pay_wire"}) {
		if (1) {
			my %PAYMENT = ();
			$PAYMENT{'enable'} = int($webdbref->{"pay_wire"});
			$PAYMENT{'fee'} = $webdbref->{"pay_wire_fee"};
			$PAYMENT{'instructions'} = $webdbref->{"pay_wire_instructions"};
			$PAYMENT{'tender'} = 'WIRE';
			push @{$R{'@PAYMENTS'}}, \%PAYMENT;
			}

		#if ($webdbref->{"pay_check"}) {
		if (1) {
			my %PAYMENT = ();
			$PAYMENT{'enable'} = int($webdbref->{"pay_check"});
			$PAYMENT{'fee'} = $webdbref->{"pay_check_fee"};
			$PAYMENT{'tender'} = 'CHECK';
			push @{$R{'@PAYMENTS'}}, \%PAYMENT;
			}

		#if ($webdbref->{"pay_cod"}) {
		if (1) {
			my %PAYMENT = ();
			$PAYMENT{'enable'} = int($webdbref->{"pay_cod"});
			$PAYMENT{'fee'} = $webdbref->{"pay_cod_fee"};
			$PAYMENT{'tender'} = 'COD';
			push @{$R{'@PAYMENTS'}}, \%PAYMENT;
			}

		#if ($webdbref->{"pay_chkod"}) {
		if (1) {
			my %PAYMENT = ();
			$PAYMENT{'enable'} = int($webdbref->{"pay_chkod"});
			$PAYMENT{'fee'} = $webdbref->{"pay_chkod_fee"};
			$PAYMENT{'tender'} = 'CHKOD';
			push @{$R{'@PAYMENTS'}}, \%PAYMENT;
			}
		}


	return(\%R);
	}




=pod

<API id="adminVendorSearch">
</API>

<API id="adminVendorCreate">
</API>

<API id="adminVendorUpdate">
</API>

<API id="adminVendorMacro">
</API>

<API id="adminVendorDetail">
</API>

<API id="adminVendorRemove">
</API>

=cut

sub adminVendor {
	my ($self,$v) = @_;

	require VENDOR;

	my %R = ();
	my $USERNAME = $self->username();
	my $MID = $self->mid();
	my $PRT = $self->prt();
	my $LU = $self->LU();

	my @MSGS = ();

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	#$/*
	#   VENDORS: businesses we buy from
	#   each vendor is assigned a 6 digit code that is used to create a unique inventory zone
	#*/
	# create table VENDORS (
	#     ID integer unsigned auto_increment,
	#     USERNAME varchar(20) default '' not null,
	#     MID integer unsigned default 0 not null,
	#     CREATED_TS timestamp  default 0 not null,
	#     MODIFIED_TS timestamp  default 0 not null,
	#     VENDOR_CODE varchar(6) default '' not null,
	#     VENDOR_NAME varchar(41) default '' not null,
	#     QB_REFERENCE_ID varchar(41) default '' not null,
	#     ADDR1 varchar(41) default '' not null,
	#     ADDR2 varchar(41) default '' not null,
	#     CITY varchar(31) default '' not null,
	#     STATE varchar(21) default '' not null,
	#     POSTALCODE varchar(31) default '' not null,
	#     PHONE varchar(21) default '' not null,
	#     CONTACT varchar(41) default '' not null,
	#     EMAIL varchar(100) default '' not null,
	#     primary key(ID),
	#     unique (MID,VENDOR_CODE)
	#   );

	my $CODE = $v->{'CODE'};
	if ($v->{'_cmd'} eq 'adminVendorList') {
		my ($vendorsref) = VENDOR::lookup($USERNAME);
		$R{'@vendors'} = $vendorsref;
		}
	elsif ($v->{'_cmd'} eq 'adminVendorCreate') {
		if (&VENDOR::exists($USERNAME,$CODE)) {
			push @MSGS, "WARN|Vendor Code:$CODE already exists";
			}
		else {	
			($v) = VENDOR->new($USERNAME,'NEW'=>$CODE);
			$v->set('VENDOR_NAME',$v->{'VENDOR_NAME'});
			$v->set('ADDR1',$v->{'ADDR1'});
			$v->set('ADDR2',$v->{'ADDR2'});
			$v->set('CITY',$v->{'CITY'});
			$v->set('STATE',$v->{'STATE'});
			$v->set('POSTALCODE',$v->{'POSTALCODE'});
			$v->set('PHONE',$v->{'PHONE'});
			$v->set('CONTACT',$v->{'CONTACT'});
			$v->set('EMAIL',$v->{'EMAIL'});
			$v->save();
			}
		}
	elsif ($v->{'_cmd'} eq 'adminVendorUpdate') {
		if (not &VENDOR::exists($USERNAME,$CODE)) {
			push @MSGS, "WARN|Vendor Code:$CODE does not exist - cannot edit.";
			}
		else {
			($v) = VENDOR->new($USERNAME,'CODE'=>$CODE);
			$v->set('VENDOR_NAME',$v->{'VENDOR_NAME'});
			$v->set('ADDR1',$v->{'ADDR1'});
			$v->set('ADDR2',$v->{'ADDR2'});
			$v->set('CITY',$v->{'CITY'});
			$v->set('STATE',$v->{'STATE'});
			$v->set('POSTALCODE',$v->{'POSTALCODE'});
			$v->set('PHONE',$v->{'PHONE'});
			$v->set('CONTACT',$v->{'CONTACT'});
			$v->set('EMAIL',$v->{'EMAIL'});
			$v->save();
			}
		}
	elsif ($v->{'_cmd'} eq 'adminVendorDelete') {
		my ($CODE) = &VENDOR::valid_vendor_code($v->{'CODE'});
		my ($v) = VENDOR->new($USERNAME,'CODE'=>$CODE);
		if (defined $v) {
			$v->nuke();
			push @MSGS, "SUCCESS|Deleted vendor: $CODE";
			}
		else {
			push @MSGS, "ERROR|Unknown vendor: $CODE";
			}
		}

	return(\%R);
	}



=pod

<API id="adminWarehouseList">
<output id="@WAREHOUSES"></output>
</API>

<API id="adminWarehouseDetail">
</API>

<API id="adminWarehouseInventoryQuery">
<input id="GEO">geocode of warehouse</input>
<input id="SKU" optional="1">SKU to filter by</input>
<input id="SKUS" optional="1">SKU1,SKU2,SKU3 to filter by</input>
<input id="LOC" optional="1">LOC to filter by</input>
<output id="@ROWS">
</output>
</API>

<API id="adminWarehouseMacro">
<purpose>to create/update/delete/modify (via macro) the wms system</purpose>
<input id="WAREHOUSE"></input>
<input id="@updates">an array of cmd objects</input>
<example><![CDATA[
* 
]]></example>
</API>


=cut

sub adminWarehouse {
	my ($self,$v) = @_;

	require WAREHOUSE;
	require ZTOOLKIT::BARCODE;

	my %R = ();
	my $USERNAME = $self->username();
	my $PRT = $self->prt();
	my $LU = $self->LU();
	my $LUSERNAME = $self->luser();
	my ($INV2) = INVENTORY2->new($USERNAME,$self->luser());

	## WAREHOUSE was pre 201338
	my ($GEO) = $v->{'WAREHOUSE'} || $v->{'GEO'};

	my @MSGS = ();
	if ($v->{'_cmd'} eq 'adminWarehouseList') {
		my ($warehousesref) = WAREHOUSE::lookup($USERNAME);
		my @ROWS = ();
		foreach my $vref (@{$warehousesref}) {
			my ($W) = WAREHOUSE->new($USERNAME,'DBREF'=>$vref);
			push @ROWS, $W;
			if ($v->{'zones'}) {
				foreach my $zone (@{$W->list_zones()}) {
					$zone->{'_OBJECT'} = 'ZONE';
					push @ROWS, $zone;
					}
				}
			}
		$R{'@ROWS'} = \@ROWS;
		}
	elsif ($v->{'_cmd'} eq 'adminWarehouseMacro') {

		## my $WHCODE = &WAREHOUSE::valid_warehouse_code($GEO);
		my ($W) = undef;

		## validation phase
		my @CMDS = ();
		#elsif ($v->{'WAREHOUSE'} ne $WHCODE) {
		#	&JSONAPI::set_error(\%R,'apperr',23924,sprintf('Invalid WAREHOUSE Code was attempted, perhaps you meant: %s',$WHCODE));
		#	}

		if (&JSONAPI::hadError(\%R)) {
			## shit happened!
			}
		elsif (not defined $v->{'@updates'}) {
			&JSONAPI::append_msg_to_response(\%R,'apperr',9002,'Could not find any @updates for order');
			}
		elsif (ref($v->{'@updates'}) eq 'ARRAY') {
			my $count = 0;
			foreach my $line (@{$v->{'@updates'}}) {
				my $CMDSETS = &CART2::parse_macro_script($line);
				foreach my $cmdset (@{$CMDSETS}) {
					$cmdset->[0] = uc($cmdset->[0]);
					$cmdset->[1]->{'luser'} = $self->luser();
					$cmdset->[2] = $line;
					$cmdset->[3] = $count++;
					push @CMDS, $cmdset;
					}
				}
			}
	
		my @MSGS = ();
		my $TS = time();
		foreach my $CMDSET (@CMDS) {
			my ($VERB,$PREF) = @{$CMDSET};
			$PREF->{'luser'} = $LUSERNAME;
			$PREF->{'ts'} = $TS;

			my $ZONE = $PREF->{'ZONE'};
			if (not defined $ZONE) { $ZONE = $v->{'ZONE'}; }

			if (not defined $PREF->{'BASETYPE'}) { $PREF->{'BASETYPE'} = 'WMS'; }

			## parameter expansion.
			if ($PREF->{'LOC'}) {
				my ($GEO,$ZONE,$POS) = &ZWMS::locparse($PREF->{'LOC'});
				if (defined $GEO) { $PREF->{'GEO'} = $GEO; }
				if (defined $ZONE) { $PREF->{'ZONE'} = $ZONE; }
				if (defined $POS) { $PREF->{'POS'} = $POS; }
				}
			if ($PREF->{'LOCO'}) {
				my ($GEOO,$ZONEO,$POSO) = &ZWMS::locparse($PREF->{'LOC'});
				if (defined $GEO) { $PREF->{'GEOO'} = $GEOO; }
				if (not defined $PREF->{'GEOO'}) { $PREF->{'GEOO'} = $GEO; }
				if (defined $ZONEO) { $PREF->{'ZONEO'} = $ZONEO; }
				if (defined $POSO) { $PREF->{'POSO'} = $POSO; }
				}
			if (not defined $PREF->{'GEO'}) { $PREF->{'GEO'} = $GEO; }
			## end parameter expansion.

			print STDERR Dumper($VERB,$PREF);
	
			if (defined $W) {
				}
			elsif ($VERB eq 'WAREHOUSE-CREATE') {
				if ((not defined $GEO) || ($GEO eq '')) { $GEO = $PREF->{'GEO'}; }
				($W) = WAREHOUSE->new($USERNAME,'NEW'=>$GEO);
				$VERB = 'WAREHOUSE-UPDATE';
				}
			elsif (not &WAREHOUSE::exists($USERNAME,$GEO)) {
				push @MSGS, "WARN|+Warehouse GEO:$GEO does not exist - cannot edit, switching to create.";
				}
			else {
				($W) = WAREHOUSE->new($USERNAME,'GEO'=>$GEO);
				}

			if ((not defined $W) || (ref($W) ne 'WAREHOUSE')) {
				push @MSGS, "ERROR|+Invalid warehouse: $GEO";
				$VERB = 'NULL';
				}


			if ($VERB eq 'NULL') {
				}
			elsif ($VERB eq 'WAREHOUSE-UPDATE') {
				$W->set('WAREHOUSE_TITLE',sprintf("%s",$PREF->{'WAREHOUSE_TITLE'}));
				$W->set('WAREHOUSE_ZIP',sprintf("%s",$PREF->{'WAREHOUSE_ZIP'}));
				$W->set('WAREHOUSE_CITY',sprintf("%s",$PREF->{'WAREHOUSE_CITY'}));
				$W->set('WAREHOUSE_STATE',sprintf("%s",$PREF->{'WAREHOUSE_STATE'}));
				$W->set('SHIPPING_LATENCY_IN_DAYS',sprintf("%d",$PREF->{'SHIPPING_LATENCY_IN_DAYS'}));
				$W->set('SHIPPING_CUTOFF_HOUR_PST',sprintf("%d",$PREF->{'SHIPPING_CUTOFF_HOUR_PST'}));
				$W->save();
				push @MSGS, "SUCCESS|+Updated warehouse";
				}
			elsif ($VERB eq 'WAREHOUSE-DELETE') {
				if (defined $W) {
					$W->nuke();
					push @MSGS, "SUCCESS|+Deleted warehouse: $GEO";
					}
				else {
					push @MSGS, "ERROR|+Unknown invalid/warehouse: $GEO";
					}
				}
			elsif ($VERB =~ /^(UUID|SKU)-LOCATION-(SET|ADD|SUB|MOVE|NUKE|ANNOTATE)$/) {
				my ($FUNC,$CMD) = ($1,$2);
				#SKU-LOCATION-(SET|ADD|SUB|MOVE)
				## SKU (required)
				## LOC (required)
				## QTY=###
				## SET = new inventory level at that location
				## ADD = add inventory to that location
				## SUB = remove inventory from that location
				## (MOVE) FROMLOC=   does an ADD @LOC and a SUB at @FROMLOC
				$INV2->invcmd($CMD,'@MSGS'=>\@MSGS,%{$PREF});
				}
			elsif ($VERB eq 'WAREHOUSE-LOOKUP') {
				}
			elsif ($VERB eq 'ZONE-DELETE') {
				my $ZONE_CODE = $PREF->{'ZONE'};
				$W->delete_zone($ZONE_CODE);
				}
			elsif ($VERB eq 'ZONE-POSITIONS-ADD') {	
				my $ERROR = undef;

				my ($Z) = $W->zone($ZONE);
				print STDERR "ZONE: ".Dumper($Z)."\n";
				if (not $ZONE) {
					$ERROR = "No ZONE was passed (and it's kinda required)";
					}
				elsif (not defined $Z) {
					$ERROR = sprintf("ZONE '%s' is invalid/cannot be loaded.",$ZONE);
					}
				elsif ($Z->zonetype() eq 'STANDARD') {
					foreach my $k ('row','shelf','shelf_end','slot','slot_end') {
						if ($PREF->{$k} eq '') { $ERROR = sprintf("Zone %s Type %s requires field $k",$Z->zone(),$Z->zonetype()); }
						}
					}

				if (not defined $ERROR) {
					$Z->add_positions_row(%{$PREF})->save();
					push @MSGS, "SUCCESS|+Added position/row";
					}
				else {
					push @MSGS, "ERROR|+Failed $ERROR";
					}
				}
			elsif ($VERB eq 'ZONE-POSITIONS-DELETE') {	
				my ($Z) = $W->zone($ZONE)->delete_positions_row($PREF->{'uuid'})->save();
				push @MSGS, "SUCCESS|+Postion removed";
				}
			elsif (($VERB eq 'ZONE-UPDATE') || ($VERB eq 'ZONE-CREATE')) {
				my $ZONE_TYPE = $PREF->{'ZONE_TYPE'};
				my ($ERROR) = $W->add_zone(
					$ZONE,
					$ZONE_TYPE,
					'TITLE'=>$PREF->{'ZONE_TITLE'},
					'PREFERENCE'=>int($PREF->{'ZONE_PREFERENCE'})
					);
				if ($ERROR) { 
					push @MSGS, "ERROR|+ZONE ERROR:$ERROR";
					}
				else {
					push @MSGS, "SUCCESS|+Added zone:$ZONE to $GEO";
					}
				}
			elsif (($VERB eq 'ZONE-ADD') || ($VERB eq 'ZONE-EDIT')) {	
				my $ZONE = $PREF->{'ZONE'};
				my $zoneref = undef;
				if ($VERB eq 'ZONE-ADD') {
					$zoneref->{'ZONE_TYPE'} = $PREF->{'ZONE_TYPE'};
					$zoneref->{'ZONE_TITLE'} = $PREF->{'ZONE_TITLE'};
					$zoneref->{'ZONE_PREFERENCE'} = $PREF->{'ZONE_PREFERENCE'};
					}
				else {
					($zoneref) = $W->get_zone($ZONE);
					}
				}
			else {
				push @MSGS, "ERROR|+Unknown macro $VERB";
				}


			if (scalar(@MSGS)>0) {	
				foreach my $msg (@MSGS) {
					&JSONAPI::add_macro_msg(\%R,$CMDSET,$msg);
					}
				}
			## END OF FOR CMDSET
			}
		}
	elsif ((not defined $GEO) || ($GEO eq '')) {
		&JSONAPI::set_error(\%R,'apperr',23923,'Invalid GEO Code for warehouse');	
		}
	elsif ($v->{'_cmd'} eq 'adminWarehouseDetail') {
		my ($W) = WAREHOUSE->new($USERNAME,'GEO'=>$GEO);
		if (not defined $W) {
			push @MSGS, "ERROR|Sorry, warehouse $GEO does not exist";
			}
		else {
			foreach my $k (keys %{$W}) {
				next if (substr($k,0,1) eq '_');
				next if (substr($k,0,1) eq '*');
				next if (substr($k,0,1) eq '%');
				$R{$k} = $W->{$k};
				}
			$R{'%ZONES'} = {};
			foreach my $Z (@{ $W->list_zones() }) {
				$R{'%ZONES'}->{$Z->zone()} = $Z;
				}
			}
		}
	elsif ($v->{'_cmd'} eq 'adminWarehouseInventoryQuery') {
		my %options = ();

		$options{'GEO'} = $GEO;
		push @{$options{'@BASETYPES'}}, 'WMS';	## always
		if ($v->{'SKU'}) { push @{$options{'@SKUS'}}, $v->{'SKU'}; }
		if ($v->{'SKUS'}) { foreach my $SKU (split(/,/,$v->{'SKUS'})) { next if ($SKU eq ''); push @{$options{'@SKUS'}}, $SKU; }	}	## SKUS = SKU1,SKU2,SKU3
		if ($v->{'LOC'}) { $options{'LOC'} = $v->{'LOC'}; }
		$options{'+'} = 'WMS';

		$R{'@ROWS'} = $INV2->detail(%options);
		}
	else {
		## UNKNOWN VERB
		}
	
#	my @zonetype_options = ();
#	foreach my $ztref (@WAREHOUSE::ZONE_TYPES) {
#		push @zonetype_options, [ $ztref->{'type'}, sprintf("%s: %s",$ztref->{'title'},$ztref->{'hint'}) ];
#		}

	return(\%R);
	}








=pod

<API id="appConfigMacro">
<purpose>to create/update/delete/modify (via macro) a configuration object</purpose>
<input id="@updates">an array of cmd objects</input>
<example><![CDATA[
* PLUGIN/SET?plugin=domain.com
* BLAST/SET?from_email=
* GLOBAL/WMS?active=1|0
* GLOBAL/ERP?active=1|0
* GLOBAL/ORDERID?start=####
* GLOBAL/ACCOUNT?
* GLOBAL/FLEXEDIT-SAVE?json=
* GLOBAL/SITE-FIX 		(not finished)
* GLOBAL/ADD-RESERVED-DOMAIN?
* GLOBAL/SEARCH?SYNONYMS=&STOPWORDS=&CHARACTERMAP=
* GLOBAL/PARTITIONCREATE?name=&domain=&navcats=
* GLOBAL/INVENTORY?inv_mode=1|3&inv_website_remove=1|0
* NOTIFICATION/DATATABLE-EMPTY?event=ENQUIRY.ORDER
* NOTIFICATION/DATATABLE-INSERT?event=ENQUIRY.ORDER
* CRM-CONFIG?ticket_number=&sequence=&email_cleanup&email=
* TAXRULES/EMPTY?tax_rules=
* TAXRULES/INSERT?type=&state=&city=&zipspan=&zip4=&country=&intprovince=&intzip=&rate=&zone=&expires=
* COUPON/INSERT?coupon=&begins=YYYYMMDDHHMMSS&expires=YYYYMMDDHHMMSS&taxable=&stackable=&disabled=&limiteduse=&title=&image=
* COUPON/UPDATE?coupon=&begins=YYYYMMDDHHMMSS&expires=YYYYMMDDHHMMSS&taxable=&stackable=&disabled=&limiteduse=&title=&image=
* COUPON/REMOVE?coupon=
* PROMOTIONS?promotion_advanced=0|1
* COUPON/RULESTABLE-EMPTY?coupon=
* COUPON/RULESTABLE-REMOVE?coupon=
* COUPON/RULESTABLE-MOVEUP?coupon=&ID=
* COUPON/RULESTABLE-MOVEDOWN?coupon=&ID=
* COUPON/RULESTABLE-INSERT?coupon=&match=&name=&filter=&exec=&value=&weight=&matchvalue
* SHIPPING/CONFIG?ship_origin=zip&chkout_deny_ship_po&ship_int_risk=&ship_latency=&ship_cutoff&ship_blacklist=isox,isox,isox&banned=type|match|ts\ntype|match|ts
* SHIPPING/BANNEDTABLE-EMPTY
* SHIPPING/BANNEDTABLE-INSERT?type=&match=&created=
* SHIPMETHOD/FEDEX-REGISTER?account=&address1=&address2=&city=&state=&zip=&country=&firstname=&lastname=&company=&phone=&email=&SUPPLIER=[optional]
* SHIPMETHOD/UPSAPI-REGISTER?shipper_number=&url=&address1=&address2=&city=&state=&zip=&country=&company=&phone=&email=&supplier=optional
* SHIPMETHOD/UPDATE?provider=USPS&usps_dom=&usps_dom_handling&usps_dom_ins&usps_dom_insprice&usps_int_priority=&usps_int_express&usps_int_expressg
* SHIPMETHOD/UPDATE?provider=UPSAPI&upsapii_dom&upsapi_int&supplier=
* SHIPMETHOD/UPDATE?provider=FEDEX&rates=&dom=1|0&int=1|0&supplier=
* SHIPMETHOD/UPDATE?provider=FLEX:CODE&active=1|0&rules=1|0&region=&name=&carrier=&
* SHIPMETHOD/INSERT?provider=FLEX:CODE
* SHIPMETHOD/REMOVE?provider=FLEX:CODE
* SHIPMETHOD/DATATABLE-EMPTY&provider=FLEX:CODE
* SHIPMETHOD/DATATABLE-INSERT&provider=FLEX:CODE&key1=value1&key2=value2
* SHIPMETHOD/DATATABLE-REMOVE&provider=FLEX:CODE&guid=xyz
* SHIPMETHOD/RULESTABLE-EMPTY?provider=&table=
* SHIPMETHOD/RULESTABLE-INSERT?provider=&table=&guid=&name=&filter=&exec=&match=&value=&schedule=&
* SHIPMETHOD/RULESTABLE-UPDATE?provider=&table=&guid=&name=&filter=&exec=&match=&value=&schedule=&
* SHIPMETHOD/RULESTABLE-REMOVE?provider=&table=&guid=&name=&filter=&exec=&match=&value=&schedule=&
* PAYMENT/OFFLINE?tender=CASH|GIFTCARD|PICKUP|CHECK|COD|CHKOD|PO|WIRE&fee=&instructions=&payto=
* PAYMENT/GATEWAY?tender=CC&
* PAYMENT/GATEWAY?tender=ECHECK&
* PAYMENT/WALLET-AMZPAY?tender=AMZPAY&color=&size=&background&env=0|1|2
* PAYMENT/WALLET-GOOGLE?tender=GOOGLE&google_key=&google_merchantid=&google_api_env=&google_api_analytics=&google_api_merchantcalc=&google_dest_zip=&google_int_shippolicy=&google_pixelurls=&google_tax_tables=
* PAYMENT/WALLET-PAYPALEC?tender=PAYPALEC&paypal_api_env&paypal_api_reqconfirmship&paypal_api_callbacks&paypal_email&paypal_api_user&paypal_api_pass&paypal_api_sig&paypal_paylater&
* PAYMENT/CUSTOM?tender=CUSTOM&description=

]]></example>
</API>

=cut


sub adminConfigMacro {
	my ($self,$v) = @_;

	my %R = ();
	my $USERNAME = $self->username();
	my $PRT = $self->prt();
	my $LU = $self->LU();

	## validation phase
	my @CMDS = ();
	if (&JSONAPI::hadError(\%R)) {
		## shit happened!
		}
	elsif (not defined $v->{'@updates'}) {
		&JSONAPI::append_msg_to_response(\%R,'apperr',9002,'Could not find any @updates for order');
		}
	elsif (ref($v->{'@updates'}) eq 'ARRAY') {
		my $count = 0;
		foreach my $line (@{$v->{'@updates'}}) {
			my $CMDSETS = &CART2::parse_macro_script($line);
			foreach my $cmdset (@{$CMDSETS}) {
				$cmdset->[1]->{'luser'} = $self->luser();
				$cmdset->[2] = $line;
				$cmdset->[3] = $count++;
				push @CMDS, $cmdset;
				}
			}
		}

	my $gref = undef;
	my $webdb = $self->webdbref();

	my $FLAGS = '';
	if (not &JSONAPI::hadError(\%R)) {
		## Validation Phase
		foreach my $cmdset (@CMDS) {
			my ($cmd,$params,$line,$linecount) = @{$cmdset};
			my @MSGS = ();
			
			if ($cmd eq 'PLUGIN/SET') {
				my $PLUGIN = lc($params->{'plugin'});

				if ($PLUGIN eq '') {
					push @MSGS, "ERROR|+No plugin name specified";
					}
				elsif ($params->{'global'}) {
					if (not defined $gref) { $gref = $self->globalref(); }
					if (not defined $gref->{'%plugins'}) { $gref->{'%plugins'} = {}; }
					$gref->{'%plugins'}->{ $PLUGIN } = $params;
					delete $params->{'plugin'};
					}
				else {
					$webdb->{"%plugin.$PLUGIN"} = $params;
					delete $params->{'plugin'};
					}
				}
			elsif ($cmd eq 'BLAST/SET') {
				$webdb->{'from_email'} = $params->{'from_email'};
				}
			elsif ($cmd eq 'GLOBAL/WMS') {
				if (not defined $gref) { $gref = $self->globalref(); }
				if (defined $params->{'active'}) {
					$gref->{'wms'} = int($params->{'active'});
					}
				}
			elsif ($cmd eq 'GLOBAL/ERP') {
				if (not defined $gref) { $gref = $self->globalref(); }
				if (defined $params->{'active'}) {
					$gref->{'erp'} = int($params->{'active'}); 
					}
				}
			elsif ($cmd eq 'CRM-CONFIG') {
				my %CRM = ();
            $CRM{'v'} = 1;
            $CRM{'is_external'} = 0;
				$webdb->{'crmtickets'} = &ZTOOLKIT::buildparams(\%CRM);

				my $ticket_count = $params->{'ticket_number'};
				my $ticket_seq = $params->{'sequence'};
				my $email_cleanup = (defined $params->{'email_cleanup'})?1:0;

				my ($MID) = &ZOOVY::resolve_mid($USERNAME);
				my $EMAIL = $params->{'email'};
				my ($udbh) = &DBINFO::db_user_connect($USERNAME);
				my $pstmt = DBINFO::insert($udbh,'CRM_SETUP',{
                MID=>$MID, PRT=>$PRT, USERNAME=>$USERNAME,
                EMAIL_ADDRESS=>$EMAIL,
                EMAIL_CLEANUP=>$email_cleanup,
                TICKET_COUNT=>$ticket_count,
                TICKET_SEQ=>$ticket_seq,
                },debug=>2,key=>['MID','PRT']);
				&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
				&DBINFO::db_user_close();

				push @MSGS, "ERROR|+CRM Case Management/Returns is not currently configured/enabled.";
				}
			elsif ($cmd eq 'GLOBAL/ORDERID') {
				if (defined $params->{'start'}) {
					&CART2::reset_order_id($USERNAME,int($params->{'start'}));
					}
				}
			elsif ($cmd eq 'GLOBAL/ACCOUNT') {
				my ($LUSERNAME) = $self->luser();
				require ACCOUNT;
				my ($ACCT) = ACCOUNT->new($USERNAME,$LUSERNAME);
				my $ERRORS = 0;
				foreach my $k (keys %{$params}) {
					my $ERROR = undef;
					if (($k eq 'ts') || ($k eq 'luser')) {
						}
					elsif (not defined $ACCOUNT::VALID_FIELDS{$k}) {
						$ERROR = "Field $k is unknown/invalid";
						}
					elsif ($params->{$k} =~ /[<>\"]+/) {
						$ERROR = "Field $k attempted to store one or more disallowed characters";
						}
			
					if (not defined $ERROR) {
						$ACCT->set($k,$params->{$k});
						}
					else {
						$ERRORS++;
						push @MSGS, "ERROR|+$ERROR";
						}
					}

				if (not $ERRORS) {
					push @MSGS, "SUCCESS|+Successfully updated account information";
					$ACCT->save();
					}
				}
			elsif ($cmd eq 'GLOBAL/FLEXEDIT-SAVE') {
				if (not defined $gref) { $gref = $self->globalref(); }
				require ZWEBSITE;
				require JSON::XS;
				require PRODUCT::FLEXEDIT;

				my $coder = JSON::XS->new->ascii->pretty->allow_nonref;
				my $fref = $coder->decode($params->{'json'});

				#foreach my $id (sort keys %PRODUCT::FLEXEDIT::fields) {
				#	if (defined $v->{$id}) {
				#		push @{$fref}, { id=>"$id" };
				#		}
				#	}
				# print STDERR Dumper($fref);
		
				$gref->{'@flexedit'} = $fref;

				}
			elsif ($cmd eq 'GLOBAL/SITE-FIX') {
				if (not defined $gref) { $gref = $self->globalref(); }
#				my ($data,$action) = ('','');		## DOES NOT WORK YET
#				if ($data =~ /^profile:(.*?)$/) {
#					my $NS = $1;
#					my ($nsref) = &ZOOVY::fetchmerchantns_ref($USERNAME,$NS);
#					my ($k,$v) = split(/=/,$action,2);
#					$nsref->{$k} = $v;
#					&ZOOVY::savemerchantns_ref($USERNAME,$NS,$nsref);
#					push @DIAGS, "FIX||$CMD ===> PROFILE[$NS] set $k=$v";
#					}
#				elsif ($data =~ /^webdb:([\d]+)$/) {
#					my $PRT = int($1);
#					my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
#					my ($k,$v) = split(/=/,$action,2);
#					$webdbref->{$k} = $v;
#					&ZWEBSITE::save_website_dbref($USERNAME,$webdbref,$PRT);
#					push @DIAGS, "FIX||$CMD ===> WEBDB[$PRT] set $k=$v";
#					}
#				elsif ($data =~ /^domain:(.*?)$/) {		
#					my $DOMAIN = $1;
#					my $d = DOMAIN->new($USERNAME,$DOMAIN);
#					my ($k,$v) = split(/=/,$action,2);
#					$d->set($k,$v);
#					$d->save();
#					push @DIAGS, "FIX||$CMD ===> DOMAIN[$DOMAIN] set $k=$v";
#					}
				}
			elsif ($cmd eq 'GLOBAL/ADD-RESERVED-DOMAIN') {
				my ($PRT) = $params->{'PRT'};
				require DOMAIN::POOL;
			 	my ($DOMAINNAME) = &DOMAIN::POOL::reserve($USERNAME,$PRT);
				if ($DOMAINNAME) {
					push @MSGS, "SUCCESS|DOMAIN=$DOMAINNAME|+Reserved domain: $DOMAINNAME";
					}
				else {
					push @MSGS, "ERROR|+Could not find a free domain to reserve";
					}
				}
			elsif ($cmd eq 'GLOBAL/SEARCH') {
				my $USER_PATH = &ZOOVY::resolve_userpath($USERNAME);
				unlink "$USER_PATH/elasticsearch-product-synonyms.txt";
				if ($params->{'SYNONYMS'}) {
					File::Slurp::write_file("$USER_PATH/elasticsearch-product-synonyms.txt",$params->{'SYNONYMS'});
					chmod 0666, "$USER_PATH/elasticsearch-product-synonyms.txt";
					push @MSGS, "SUCCESS|+Saved product synonyms (reindex-needed)";
					}

				unlink "$USER_PATH/elasticsearch-product-stopwords.txt";
				if ($params->{'STOPWORDS'}) {
					File::Slurp::write_file("$USER_PATH/elasticsearch-product-stopwords.txt",$params->{'STOPWORDS'});
					chmod 0666, "$USER_PATH/elasticsearch-product-stopwords.txt";
					push @MSGS, "SUCCESS|+Saved product stopwords (reindex-needed)";
					}

				unlink "$USER_PATH/elasticsearch-product-charactermap.txt";
				if ($params->{'CHARACTERMAP'}) {
					my @LINES = ();
					my %DUPS = ();
					my $linecount = 0;
					foreach my $line (split(/[\n\r]+/,$params->{'CHARACTERMAP'})) {
						$linecount++;
						my ($k,$v) = split(/\=\>/,$line);
						$k =~ s/^[s]+//gs;
						$k =~ s/[s]+$//gs;
						if (not defined $DUPS{$k}) {
							push @LINES, $line;
							}
						else {
							push @MSGS, "WARN|+Line[$linecount] \"$line\" was ignored because it was duplicated earlier.";
							$DUPS{$k}++;
							}
						}
					File::Slurp::write_file("$USER_PATH/elasticsearch-product-charactermap.txt",join("\n",@LINES));
					chmod 0666, "$USER_PATH/elasticsearch-product-charactermap.txt";
					push @MSGS, "SUCCESS|+Saved product character map (reindex-needed)";
					}
				}
			elsif ($cmd eq 'GLOBAL/PARTITIONCREATE') {
				if (not defined $gref) { $gref = $self->globalref(); }
				my $i = scalar(@{$gref->{'@partitions'}});
				my %prt = ();
				$prt{'name'} = $params->{'name'};

				if (($params->{'domain'}) && ($params->{'domain'} eq '')) {
					$prt{'domain'} = $params->{'domain'};
					}
				# $prt{'profile'} = $params->{'profile'};

				$prt{'p_navcats'} = ($params->{'navcats'})?$i:0;
				$prt{'p_customers'} = $i;
				$gref->{'@partitions'}->[$i] = \%prt;

				# push @MSGS, "SUCCESS|+Created Partition $i";
				# $LU->log("SETUP.PARTITION","Created partition \#$i $prt{'name'} profile=$prt{'profile'} $prt{'p_checkout'}|$prt{'p_messages'}|$prt{'p_customer'}","INFO");
				## &ZWEBSITE::prt_set_profile($USERNAME,$i,$params->{'profile'});

				}
			elsif ($cmd eq 'GLOBAL/INVENTORY') {
				if (not defined $gref) { $gref = $self->globalref(); }
				foreach my $k (keys %{$params}) {
					if ($k =~ /inv_/) { $gref->{$k} = $params->{$k}; }
					}

				$gref->{'inv_reserve'} = 0;
				$gref->{'inv_police_checkout'} = 0; 
				$gref->{'inv_police'} = 0;
				$gref->{'inv_channel'} = 0;

				$gref->{'inv_reserve_action'} = 0;
				$gref->{'inv_rexceed_action'} = 0;
				$gref->{'inv_safety_action'} = 0;

				$gref->{'inv_outofstock_action'} = 0;
				#foreach my $i (1,2,4,8,16,32,64,128,256) {
				#	$gref->{'inv_notify'} |= (defined $params->{'inv_notify_'.$i})?$i:0;
				#	$gref->{'inv_outofstock_action'} |= (defined $params->{'inv_outofstock_action_'.$i})?$i:0;
				#	}
				if ($params->{'inv_mode'} == 0) { $params->{'inv_mode'} = 1; }

				#if ($FLAGS =~ /,API2,/) {
				#	## don't run the rest of these cases (we'll use our own custom settings later)
				#	}
				if ($params->{'inv_mode'} == 1) {
					$gref->{'inv_mode'} = 1;
					$gref->{'inv_reserve'} = 1;
					}
				elsif (($params->{'inv_mode'}==3) || ($params->{'inv_mode'}==2)) { 
					$gref->{'inv_mode'} = int($params->{'inv_mode'});
					$gref->{'inv_reserve'} = 1;
					$gref->{'inv_police'} = 2;
					$gref->{'inv_police_checkout'} = 1;
					$gref->{'inv_channel'} = 4;
					$gref->{'inv_reserve_action'} = 0;
					$gref->{'inv_rexceed_action'} = 3;
					$gref->{'inv_outofstock_action'} |= 2;
					}

				if (not $params->{'inv_website_remove'}) {
					$gref->{'inv_rexceed_action'} = 0;
					$gref->{'inv_outofstock_action'} = 0;
					}
				else {
					## turns on remove from website action.
					$gref->{'inv_rexceed_action'} |= 1;
					$gref->{'inv_outofstock_action'} |= 1;
					}

				}
			elsif ($cmd eq 'TAXRULES/EMPTY') {
				$webdb->{'tax_rules'} = '';
				}
			elsif ($cmd eq 'TAXRULES/SET') {
				$webdb->{'tax_rules'} = $params->{'tax_rules'};
				}
			elsif ($cmd eq 'TAXRULES/INSERT') {
				my %ref = ();
				my @ref = ();
				my $ERROR = undef;

				if ($params->{'type'} eq '') { $ERROR = "Please select a match type"; }
				my $type = $params->{'type'};
				push @ref, $type;

				my $match = '';
				if ($type eq 'state') { 
					$match = uc($params->{'state'}); 
					if ($match eq '') { $ERROR = "state cannot be left blank!"; }
					}
				elsif ($type eq 'city') {
					$match = uc($params->{'citys'}).'+'.$params->{'city'};
					if ($match eq '+') { $ERROR = "City and State cannot be left blank!"; }
					elsif ($params->{'citys'} eq '') { $ERROR = "State (for city state) cannot be left blank!"; }
					elsif ($params->{'city'} eq '') { $ERROR = "City (for city state) cannot be left blank!"; }
					}
				elsif ($type eq 'zipspan') {
					my $zipstart = int($params->{'zipstart'});
					my $zipend = int($params->{'zipend'});

					if ($zipstart == $zipend) { $match = sprintf("%05d",$zipend); }
					elsif ($zipend<$zipstart) { $match = sprintf("%05d-%05d",$zipend,$zipstart); }
					else { $match = sprintf("%05d-%05d",$zipstart,$zipend); }
					if ($match eq '') { $ERROR = "Zip code must be provided!"; }
					}
				elsif ($type eq 'zip4') {
					$match = uc($params->{'zip4'});
					if ($match eq '') { $ERROR = "Zip code + 4 must be provided!"; }
					}
				elsif ($type eq 'country') {
					$match = uc($params->{'country'});		
					if ($match eq '') { $ERROR = "Country must be provided!"; }
					}
				elsif ($type eq 'intprovince') {
					$match = uc($params->{'ipcountry'});		
					if ($match eq '') { $ERROR = "Country must be provided!"; }
					if ($params->{'ipstate'} eq '') { 
						$ERROR = "Province must be provided!"; 
						}
					else {
						my $tmp = lc($params->{'ipstate'});
						$match = "$match+$tmp";
						}
					}
				elsif ($type eq 'intzip') {
					$match = uc($params->{'izcountry'});		
					if ($match eq '') { $ERROR = "Country must be provided!"; }
					if ($params->{'izzip'} eq '') { 
						$ERROR = "ZIP must be provided!"; 
						}
					else {
						my $tmp = lc($params->{'izzip'});
						$match = "$match+$tmp";
						}
					}

				push @ref, $match;
				if ($params->{'rate'} eq '') { $ERROR = "You must provide a number for tax rate"; }
				elsif ($params->{'rate'} =~ /[^0-9\.]/) { $ERROR = "You must provide a number for tax rate"; }

				push @ref, sprintf("%.3f",$params->{'rate'});
				my $val = 0;
				if ($params->{'enable'}) { $val |= 1; }
				if ($params->{'enable_shipping'}) { $val |= 2; }
				if ($params->{'enable_handling'}) { $val |= 4; }
				if ($params->{'enable_insurance'}) { $val |= 8; }
				if ($params->{'enable_special'}) { $val |= 16; }
				if ($val>0) { $val |= 1; }
				push @ref, $val;
	
				my $zone = $params->{'zone'};
				$zone =~ s/,/ /g;
				push @ref, $zone;
	
				my $expires =  $params->{'expires'};
				$expires =~ s/[^\d]+//g;
				push @ref, $expires;

				my $group = sprintf("%s",$params->{'group'});
				push @ref, $group;

				my $csv = Text::CSV_XS->new ();
				if ($ERROR eq '') {
					my $status = $csv->combine(@ref);  # combine columns into a string
					my $line = $csv->string();
					$webdb->{'tax_rules'} .= $line."\n";
					}
				else {
		 			push @MSGS, "ERROR|+$ERROR";
					}
				}
			elsif ($cmd =~ /NOTIFICATION\/DATATABLE\-(INSERT|EMPTY|REMOVE)$/) {
				## DATATABLE-INSERT DATATABLE-EMPTY DATATABLE-REMOVE
				my ($VERB) = $1;
				
				my $EVENT = uc($params->{'event'});
				if (not defined $webdb->{"%NOTIFICATIONS"}) { $webdb->{"%NOTIFICATIONS"} = {}; }
				my $EVENTROWS = $webdb->{"%NOTIFICATIONS"}->{$EVENT} || [];

				## my $tableref = &ZTOOLKIT::parseparams($webdb->{$WEBDBKEY});
				if ($VERB eq 'EMPTY') {
					$EVENTROWS = [];
					}
				elsif ($VERB eq 'INSERT') {
					push @{$EVENTROWS}, &ZTOOLKIT::buildparams($params);
					}
				else {		
					push @MSGS, "ERROR|+Remove not specified";
					}

				$webdb->{"%NOTIFICATIONS"}->{$EVENT} = $EVENTROWS;
				if (scalar(@{$EVENTROWS})==0) {
					delete $webdb->{"%NOTIFICATIONS"}->{$EVENT};
					}

				#elsif ($VERB eq 'REMOVE') {
				#	#if (defined $tableref->{ $params->{'guid'} }) {
				#	#	delete $tableref->{ $params->{'guid'} };
				#	#	}
				#	#else {
				#	#	push @MSGS, "ERROR|+Specified guid does not exist CMD:$cmd WEBDBKEY:$WEBDBKEY VERB:$VERB provider:$params->{'provider'} table:$params->{'table'}";
				#	#	}
				#	}
				}
			elsif ($cmd eq 'PROMOTIONS') {
				$LU->log("SETUP.PROMO","Configured Advanced Promotions","SAVE");
				$webdb->{'promotion_advanced'} = 0;
				if (defined($params->{'promotion_advanced'})) { $webdb->{"promotion_advanced"} = 1; }
				}
			elsif ($cmd =~ /COUPON\/(INSERT|UPDATE|REMOVE)/) {
				my ($COUPON) = $params->{'coupon'};
				if ($COUPON eq '') { $params->{'coupon'} = substr(time(),-5); }

				require Date::Parse;
				my %ref = ();

				#$ref{'begins_gmt'} = int($params->{'begins_gmt'});
				#if ($params->{'begins'} ne '') { $ref{'begins_gmt'} = Date::Parse::str2time($params->{'begins'}); }
				#$ref{'expires_gmt'} = int($params->{'expires_gmt'});
				#if ($params->{'expires'} ne '') { $ref{'expires_gmt'} = Date::Parse::str2time($params->{'expires'});	}
				$ref{'begins_gmt'} = $self->dateify_to_gmt($params->{'begins_ts'});
				$ref{'expires_gmt'} = $self->dateify_to_gmt($params->{'expires_ts'});

				$ref{'auto'} = ($params->{'auto'})?1:0;
				$ref{'taxable'} = ($params->{'taxable'})?1:0;
				$ref{'stackable'} = ($params->{'stackable'})?1:0;
				$ref{'disable'} = ($params->{'disable'})?1:0;
				$ref{'limiteduse'} = ($params->{'limiteduse'})?1:0;
				$ref{'title'} = $params->{'title'};
				## $ref{'profile'} = $params->{'profile'};
				$ref{'image'} = $params->{'image'};

				require CART::COUPON;
				if ($cmd eq 'COUPON/INSERT') {
					CART::COUPON::add($webdb,$COUPON);
					CART::COUPON::save($webdb,$COUPON,%ref);
					$LU->log("SETUP.PROMO","Created Coupon $COUPON","SAVE");
					}
				elsif ($cmd eq 'COUPON/UPDATE') {
					CART::COUPON::save($webdb,$COUPON,%ref);
					$LU->log("SETUP.PROMO","Updated/Saved Coupon $COUPON","SAVE");
					}
				elsif ($cmd eq 'COUPON/REMOVE') {
					CART::COUPON::delete($webdb,$COUPON);
					$LU->log("SETUP.PROMO","Deleted Coupon for $COUPON","SAVE");
					}
				}
			elsif ($cmd =~ /^COUPON\/RULESTABLE-(EMPTY|UPDATE|INSERT|REMOVE)$/) {
				my $COUPON = $params->{'coupon'};
				## $COUPON =~ s/[\W]+//sg;
				my ($RULESETID) = "COUPON-$COUPON";				
					
				if ($COUPON eq '') {
					push @MSGS, "ERROR|+coupon field was blank";
					}
				elsif ($cmd eq 'COUPON/RULESTABLE-DELETE') {
					$LU->log("SETUP.PROMO","Deleted Promotion for $RULESETID","SAVE");
					my $ID = my $THIS = $params->{'ID'};
				   &ZSHIP::RULES::delete_rule($webdb, $RULESETID,$THIS);
					}
				elsif ($cmd eq 'COUPON/RULESTABLE-MOVEUP') {
					my $ID = my $THIS = $params->{'ID'};
				 	&ZSHIP::RULES::swap_rule($webdb, $RULESETID,$THIS,$THIS-1);
					}
				elsif ($cmd eq 'COUPON/RULESTABLE-MOVEDOWN') {
					my $ID = my $THIS = $params->{'ID'};
					&ZSHIP::RULES::swap_rule($webdb,$RULESETID,$THIS,$THIS+1);
					}
				elsif (($cmd eq 'COUPON/RULESTABLE-INSERT') || ($cmd eq 'COUPON/RULESTABLE-UPDATE')) {
					my %hash = ();
					$hash{'CODE'} = $COUPON;
					$hash{'MATCH'} = $params->{'match'};
				 	$hash{'NAME'} = $params->{'name'};
				  	$hash{'FILTER'} = $params->{'filter'};
				  	$hash{'EXEC'} = $params->{'exec'};
				  	$hash{'VALUE'} = $params->{'value'};
					$hash{'HINT'} = $params->{'hint'};
	
					my $WEIGHT = $params->{'weight'};
					$WEIGHT =~ s/[^\d]+//g;
					$hash{'WEIGHT'} = $WEIGHT;
					$hash{'MATCHVALUE'} = $params->{'matchvalue'};

					if ($cmd eq 'COUPON/RULESTABLE-INSERT') {
						&ZSHIP::RULES::append_rule($webdb, $RULESETID,\%hash);  
						}
					elsif ($cmd eq 'COUPON/RULESTABLE-UPDATE') {
						my $ID = my $THIS = $params->{'ID'};
						&ZSHIP::RULES::update_rule($webdb, $RULESETID,$ID,\%hash);  
						}
					}
				elsif ($cmd eq 'COUPON/RULESTABLE-EMPTY') {
					&ZSHIP::RULES::empty_rules($webdb,$RULESETID);					
					}
				
				}
			elsif ($cmd eq 'SHIPMETHOD/UPSAPI-REGISTER') {
				my %upscfg = ();
				foreach my $k ('shipper_number','company_name','address1','address2','city','state','zip','country','name','title','email','phone','url','contact') {
					$upscfg{$k} = $params->{$k};
					}
				$upscfg{'state'} = uc($upscfg{'state'});
				require ZSHIP::UPSAPI;
				my ($error,$license,$user,$pass) = &ZSHIP::UPSAPI::get_ups_registration($USERNAME,\%upscfg);
				my $shipper_number = $params->{'shipper_number'};
				if ($error ne '') {
					push @MSGS, "ERROR|+$error";
					}
				elsif ((defined $params->{'VENDORID'}) && ($params->{'VENDORID'} ne '')) {
					# &ZWEBSITE::save_website_attrib($USERNAME,'upsapi_VENDORID',$VENDORID);
					my ($VENDORID) = $params->{'VENDORID'};
					my $S = SUPPLIER->new($USERNAME, $VENDORID);
					## NOTE; we should probably auto-configure ups settings here
					$S->save_property(".ship.meter", "type=UPS&user=$user&pass=$pass&license=$license&shipper_number=$shipper_number");
					$S->save_property(".ship.meter_createdgmt", time());
					$S->save();
					print STDERR "saving supplier: type=UPS&supplier_id=$VENDORID&user=$user&pass=$pass&license=$license&shipper_number=$shipper_number\n";
					$LU->log("SETUP.SHIPPING.UPSAPI","Intialized Supplier $VENDORID UPS License","SAVE");
					push @MSGS, "SUCCESS|+Registered VENDOR $VENDORID";
					}
				else {
					my %UPSCONFIG = ();
					$UPSCONFIG{'.userid'} = $user;
					$UPSCONFIG{'.password'} = $pass;
					$UPSCONFIG{'.license'} = $license;
					$UPSCONFIG{'.shipper_number'} = $shipper_number;

					# print STDERR Dumper(\%UPSCONFIG);
					$webdb->{'upsapi_config'} = &ZTOOLKIT::buildparams(\%UPSCONFIG,1);
					$LU->log("SETUP.SHIPPING.UPSAPI","Intialized UPS License","SAVE");
					&ZWEBSITE::save_website_dbref($USERNAME,$webdb,$PRT);
					push @MSGS, "SUCCESS|+Initialized UPS";
					}
				
				}
			elsif ($cmd eq 'SHIPMETHOD/FEDEX-REGISTER') {
				my $fdxcfg = {};
				$fdxcfg->{'account'} = $params->{'account'};
				if ($fdxcfg->{'account'} eq '') { push @MSGS, "ERROR|+Account # is required"; }

				$fdxcfg->{'register.streetlines'} = $params->{'address1'}.' '.$params->{'address2'};
				$fdxcfg->{'register.city'} = $params->{'city'};
				if ($fdxcfg->{'register.city'} eq '') { push @MSGS, "ERROR|+City is required"; }
				$fdxcfg->{'register.state'} = $params->{'state'};
				if ($fdxcfg->{'register.state'} eq '') { push @MSGS, "ERROR|+State is required"; }
				$fdxcfg->{'register.zip'} = $params->{'zip'};
				if ($fdxcfg->{'register.zip'} eq '') { push @MSGS, "ERROR|+Zip is required"; }
				$fdxcfg->{'register.country'} = $params->{'country'};
				if ($fdxcfg->{'register.country'} eq '') { push @MSGS, "ERROR|+Country is required"; }

				$fdxcfg->{'register.firstname'} = $params->{'firstname'};
				if ($fdxcfg->{'register.firstname'} eq '') { push @MSGS, "ERROR|+Firstname is required"; }
				$fdxcfg->{'register.lastname'} = $params->{'lastname'};
				if ($fdxcfg->{'register.firstname'} eq '') { push @MSGS, "ERROR|+Lastname is required"; }
				$fdxcfg->{'register.company'} = $params->{'company'};
				if ($fdxcfg->{'register.company'} eq '') { push @MSGS, "ERROR|+Company is required"; }
				$fdxcfg->{'register.phone'} = $params->{'phone'};
				if ($fdxcfg->{'register.phone'} eq '') { push @MSGS, "ERROR|+Phone is required"; }
				$fdxcfg->{'register.email'} = $params->{'email'};
				if ($fdxcfg->{'register.email'} eq '') { push @MSGS, "ERROR|+Email is required"; }

				$fdxcfg->{'origin.country'} = $fdxcfg->{'register.country'};
				$fdxcfg->{'origin.state'} = $fdxcfg->{'register.state'};
				$fdxcfg->{'origin.zip'} = $fdxcfg->{'register.zip'};

				if (scalar(@MSGS)==0) {
					require ZSHIP::FEDEXWS;
					delete $fdxcfg->{'registration.key'};
					delete $fdxcfg->{'registration.password'};
					$fdxcfg->{'registration.created'} = 0;
					$fdxcfg->{'meter'} = 0;
					## APP uses 'meter' to denote registration
					($fdxcfg) = &ZSHIP::FEDEXWS::register($USERNAME,$fdxcfg,\@MSGS);
					#push @MSGS, "SUCCESS|".Dumper($fdxcfg);
					if ($fdxcfg->{'registration.created'}>0) { 
						&ZSHIP::FEDEXWS::subscriptionRequest($USERNAME,$fdxcfg,\@MSGS); 
						}

					my $VENDORID = $params->{'VENDORID'};
					if ($fdxcfg->{'meter'}==0) {
						push @MSGS, "ERROR|+Meter was not set following subscriptionRequest";
						}
					elsif ($VENDORID eq '') { 
						push @MSGS, "SUCCESS|+Created meter #$fdxcfg->{'meter'}"; 
						&ZSHIP::FEDEXWS::save_webdb_fedexws_cfg($USERNAME,$PRT,$fdxcfg);
						}
					elsif ($VENDORID ne '') {
						push @MSGS, "SUCCESS|+Created Meter for Supplier:$VENDORID (meter: #$fdxcfg->{'meter'})"; 
						## force these supplier settings
						$fdxcfg->{'enable'} |= 1;
						$fdxcfg->{'dom.home'} |= 1;
						$fdxcfg->{'dom.ground'} |= 1;
						&ZSHIP::FEDEXWS::save_supplier_fedexws_cfg($USERNAME,$VENDORID,$fdxcfg);
						}
					}
				}
			elsif ($cmd eq 'SHIPPING/CONFIG') {
				if ($webdb->{'ship_origin_zip'} eq '') {
					push @MSGS, "WARN|+ship_origin_zip is not set - many types of zone based shipping will not work";
					}

				if (defined $params->{'chkout_deny_ship_po'}) {
					$webdb->{"chkout_deny_ship_po"} = ($params->{'chkout_deny_ship_po'})?1:0;
					}
	  
				## DESTINATIONS
				if (defined $params->{'ship_int_risk'}) {
					$webdb->{'ship_int_risk'} = $params->{'ship_int_risk'};
					}
	
				## ORIGIN ZIP	
				if (defined $params->{'ship_origin_zip'}) {
					$params->{'ship_origin_zip'} =~ s/[^\d]+//g;
					my ($state) = &ZSHIP::zip_state($params->{'ship_origin_zip'});
					if ($state eq '') {
						push @MSGS, "ERROR|+ZIP code does not appear to be valid!";
						}
					else { 		
						$webdb->{'ship_origin_zip'} = $params->{'ship_origin_zip'};
						}
					}
	
				## FULFILLMENT LATENCY
				$params->{'ship_latency'} =~ s/\D//g;
				if ($params->{'ship_latency'} eq '') {
					}
				elsif ($params->{'ship_latency'} !~ /\d/) {
					push @MSGS, "ERROR|+Default Fulfillment latency is invalid!";
			      }
			   else { 
					$webdb->{'ship_latency'} = $params->{'ship_latency'};
					}

				## FULFILLMENT CUTOFF
				if ($params->{'ship_cutoff'} ne '') {
					if ($params->{'ship_cutoff'} !~ /\d\d:\d\d/) {
						push @MSGS, "ERROR|+Fulfillment cut off time is invalid! (Ex. 14:00 or 08:00)";
						}
					else { 
						$webdb->{'ship_cutoff'} =  $params->{'ship_cutoff'};
						}
					}

				## BANNED COUNTRIES
				#my $type = uc($params->{'type'});
				#my $matches = uc($params->{'matches'});
				#$matches =~ s/^[\s]+//g;	# strip leading space
				#$matches =~ s/[\s]+$//g;	# strip trailing space
				# my $line = $type.'|'.$matches."|".time()."\n";
				if (defined $params->{'banned'}) {
					$webdb->{'banned'} = $params->{'banned'};
					}

				## BLACKLIST:
				if (defined $params->{'blacklist'}) {
					$webdb->{'ship_blacklist'} = $params->{'blacklist'};		## comma separate list of ISOX codes
					}
				}	
			elsif ($cmd =~ /^SHIPPING\/BANNEDTABLE\-(EMPTY|INSERT)$/) {
				my $VERB = $1;
				if ($VERB eq 'EMPTY') {
					$webdb->{'banned'} = '';
					}
				elsif ($VERB eq 'INSERT') {
					my $line = sprintf("%s|%s|%s\n",$params->{'type'},$params->{'match'},$params->{'created'});
					$webdb->{'banned'} .= $line;
					}
				else {
					## this line should never be reached.
					push @MSGS, "ERROR|+Unknown SHIPPING/BANNEDTABLE-VERB ($VERB)";
					}
				}
			elsif ($cmd eq 'SHIPMETHOD/REMOVE') {
				if ($params->{'provider'} =~ /FLEX\:(.*?)$/) {
					my $ID = $1;
					&ZWEBSITE::ship_del_method($webdb,$ID);
					}
				else {
					push @MSGS, "ERROR|+requested provider is not FLEX: and cannot be removed";
					}
				}
			elsif ($cmd =~ /SHIPMETHOD\/DATATABLE\-(INSERT|EMPTY|REMOVE)$/) {
				## DATATABLE-INSERT DATATABLE-EMPTY DATATABLE-REMOVE
				my ($VERB) = $1;

				if ($params->{'provider'} =~ /^(HANDLING|INSURANCE)$/) {

					## HANDLING:WEIGHT_US INSURANCE:WEIGHT_US INSURANCE:PRICE_US
					my $WEBDBKEY = undef;
					if (($params->{'provider'} eq 'HANDLING') && ($params->{'table'} eq 'WEIGHT_US')) { $WEBDBKEY = 'hand_weight_dom'; }
					if (($params->{'provider'} eq 'HANDLING') && ($params->{'table'} eq 'WEIGHT_CA')) { $WEBDBKEY = 'hand_weight_can'; }
					if (($params->{'provider'} eq 'HANDLING') && ($params->{'table'} eq 'WEIGHT_INT')) { $WEBDBKEY = 'hand_weight_int'; }
					if (($params->{'provider'} eq 'INSURANCE') && ($params->{'table'} eq 'WEIGHT_US')) { $WEBDBKEY = 'ins_weight_dom'; }
					if (($params->{'provider'} eq 'INSURANCE') && ($params->{'table'} eq 'WEIGHT_CA')) { $WEBDBKEY = 'ins_weight_can'; }
					if (($params->{'provider'} eq 'INSURANCE') && ($params->{'table'} eq 'WEIGHT_INT')) { $WEBDBKEY = 'ins_weight_int'; }
					if (($params->{'provider'} eq 'INSURANCE') && ($params->{'table'} eq 'PRICE_US')) { $WEBDBKEY = 'ins_price_dom'; }
					if (($params->{'provider'} eq 'INSURANCE') && ($params->{'table'} eq 'PRICE_CA')) { $WEBDBKEY = 'ins_price_can'; }
					if (($params->{'provider'} eq 'INSURANCE') && ($params->{'table'} eq 'PRICE_INT')) { $WEBDBKEY = 'ins_price_int'; }
					
					my $tableref = &ZTOOLKIT::parseparams($webdb->{$WEBDBKEY});
					if (not defined $WEBDBKEY) {
						push @MSGS, "ERROR|+Could not resolve WEBDBKEY CMD:$cmd VERB:$VERB provider:$params->{'provider'} table:$params->{'table'}";						
						}
					elsif ($VERB eq 'EMPTY') {
						$tableref = {};
						}
					elsif ($VERB eq 'REMOVE') {
						if (defined $tableref->{ $params->{'guid'} }) {
							delete $tableref->{ $params->{'guid'} };
							}
						else {
							push @MSGS, "ERROR|+Specified guid does not exist CMD:$cmd WEBDBKEY:$WEBDBKEY VERB:$VERB provider:$params->{'provider'} table:$params->{'table'}";
							}
						}
					elsif (($params->{'table'} =~ /^WEIGHT_/) && ($VERB eq 'INSERT')) {
						my $wt = &ZSHIP::smart_weight($params->{'weight'});
						$tableref->{$wt} = sprintf("%0.2f",$params->{'fee'});
						}
					elsif (($params->{'table'} =~ /^PRICE_/) && ($VERB eq 'INSERT')) {
						my $subtotal = sprintf("%0.2f",$params->{'subtotal'});
						$tableref->{$subtotal} = sprintf("%0.2f",$params->{'fee'});
						}
					else {
						push @MSGS, "ERROR|+Unhandlable request CMD:$cmd WEBDBKEY:$WEBDBKEY VERB:$VERB provider:$params->{'provider'} table:$params->{'table'}";
						}
			
					if (scalar(@MSGS)==0) {
						$webdb->{$WEBDBKEY} = &ZTOOLKIT::buildparams($tableref); 
						}
					}
				elsif ($params->{'provider'} =~ /FLEX\:(.*?)$/) {
					my $ID = $1;
					my %ref = ();
					my $exist = &ZWEBSITE::ship_get_method($webdb,$ID);
					if (defined $exist) {
						## okay so we've already got some existing data, we'll load that
						%ref = %{$exist};
						}

					my $tableref =  &ZTOOLKIT::parseparams($ref{'data'});
					if ($VERB eq 'EMPTY') {
						$tableref = {};
						}
					elsif ($VERB eq 'REMOVE') {
						delete $tableref->{ $params->{'guid'} };
						}
					elsif (($VERB eq 'INSERT') && (not defined $exist)) {
						push @MSGS, "ERROR|+Could not locate shipping provider $ID";
						}
					elsif (($ref{'handler'} eq 'LOCAL') && ($VERB eq 'INSERT')) {
						my $startzip = $params->{'zip1'};
						$startzip =~ s/[^0-9]//g;
						my $endzip = $params->{'zip2'};
						$endzip =~ s/[^0-9]//g;
						my $price = $params->{'fee'};
						my $key = $startzip.'-'.$endzip;
						if (length($startzip)!=5) {
 							push @MSGS, "ERROR|+Starting zip is invalid, cannot save.";
							}
						elsif (length($endzip)!=5) {
							push @MSGS, "ERROR|+Ending zip is invalid, cannot save.";
							}
						else {
							$tableref->{$key} = sprintf("%.2f",$price);		
							}
						}
					elsif (($ref{'handler'} eq 'LOCAL_CANADA') && ($VERB eq 'INSERT')) {
						my $zippattern = uc($params->{'postal'});
						$zippattern =~ s/[^A-Z0-9]+//g;	 #strip whitespace
						my $instructions = $params->{'txt'};
						$instructions =~ s/^[\s]+//g;		# remove leading whitespace
						$instructions =~ s/[\s]+$//g;		# remove trailing whitespace
						$instructions =~ s/\|//g;			# pipes are now allowed
						my $price = $params->{'free'};
						$tableref->{$zippattern} = sprintf("%.2f|%s",$price,$instructions);
						}
					elsif (($ref{'handler'} eq 'PRICE') && ($VERB eq 'INSERT')) {
						my $subtotal = sprintf("%.2f",$params->{'subtotal'});
						## strip any whitespace
						$subtotal =~ s/[\s]+//g;
						my $price = 0;
						if (substr($params->{'fee'},0,1) eq '%') {
							## percentage!
							$price = $params->{'fee'};
							}
						else {
							$price = sprintf("%.2f",$params->{'fee'});
							}
						if (defined($subtotal) && defined($price)) {
							$tableref->{$subtotal} = $price;
							}
						}
					elsif (($ref{'handler'} eq 'WEIGHT') && ($VERB eq 'INSERT')) {
						## fee, weight, guid
						my $weight = &ZSHIP::smart_weight_new($params->{'weight'});
				      my $fee = $params->{'fee'};
				      if (defined($fee) && defined($weight)) {
				         $weight =~ s/[^0-9\.]//g;
				         $fee =~ s/[^0-9\.]//g;
							}
						if (($weight eq '') || ($weight<=0)) {
							push @MSGS, "ERROR|+Weight must be set, and greater than zero, not saved.";
							}
						elsif (($fee eq '') || (int($fee)<0)) {
							push @MSGS, "ERROR|+Price must be set to a non-negative number, not saved.";
							}
						else {
							$tableref->{$weight} = sprintf("%.2f",$fee);
							}
						}
					else {
						push @MSGS, sprintf("ERROR|+Unknown provider(%s)/verb(%s) pairing",$params->{'provider'},$VERB);
						}
			
					if (scalar(@MSGS)==0) {
						$ref{'data'} = &ZTOOLKIT::buildparams($tableref,1);						 
						&ZWEBSITE::ship_add_method($webdb,\%ref);
						}
					}
				else {
					push @MSGS, "ERROR|+Only FLEX:xxxxx provider types may be inserted";
					}
				}
			elsif ($cmd eq 'SHIPMETHOD/INSERT') {
				if ($params->{'provider'} =~ /FLEX\:(.*?)$/) {
					my $ID = $1;
					my %ref = ();
					$ref{'id'} = $ID;
					$ref{'active'} = 0;
					$ref{'rules'} = 0;
					$ref{'region'} = 'US';
					$ref{'name'} = sprintf("%s Shipping",$params->{'handler'});
					$ref{'carrier'} = 'FOO';
					$ref{'handler'} = $params->{'handler'};
					&ZWEBSITE::ship_add_method($webdb,\%ref);
					}
				else {
					push @MSGS, "ERROR|+Only FLEX:xxxxx provider types may be inserted";
					}
				}
			elsif ($cmd eq 'SHIPMETHOD/UPDATE') {
				if ($params->{'provider'} eq 'USPS') {
					$webdb->{'usps_dom'}          = $params->{'usps_dom'} ? 1 : 0 ;
					$webdb->{'usps_dom_handling'} = $params->{'usps_dom_handling'};
					$webdb->{'usps_dom_ins'}      = $params->{'usps_dom_ins'};
					$webdb->{'usps_dom_insprice'} = $params->{'usps_dom_insprice'};
	
					$webdb->{'usps_int_priority'} = 0;
					$webdb->{'usps_int_express'} = 0;
					$webdb->{'usps_int_expressg'} = 0;
					foreach my $k (1,2,4) {
						# 1=other package, 2=flat box, 4=flat envelope
						$webdb->{'usps_int_priority'} += ($params->{'usps_int_priority_'.$k})?int($k):0;
						# 1=other package, 2=flat envelope
						$webdb->{'usps_int_express'} += ($params->{'usps_int_express_'.$k})?int($k):0;
						# 1=other package, 2=rectangular, 4=non-rect.
						$webdb->{'usps_int_expressg'} += ($params->{'usps_int_expressg_'.$k})?int($k):0;
						}
	
					$webdb->{'usps_dom_express'}  = $params->{'usps_dom_express'};
					$webdb->{'usps_dom_priority'} = $params->{'usps_dom_priority'};
					$webdb->{'usps_dom_bulkrate'} = $params->{'usps_dom_bulkrate'};
	
					$webdb->{'usps_int'}                 = $params->{'usps_int'} ? 1 : 0 ;
					$webdb->{'usps_int_handling'}        = $params->{'usps_int_handling'};
					$webdb->{'usps_int_ins'}             = $params->{'usps_int_ins'};
					$webdb->{'usps_int_insprice'}        = $params->{'usps_int_insprice'};
					$webdb->{'usps_int_parcelpost'}		 = $params->{'usps_int_parcelpost'};

					}
				elsif (($params->{'provider'} eq 'UPSAPI') || ($params->{'provider'} eq 'UPS')) {
					## SHIPMETHOD/UPDATE?provider=UPS&rate_chart=01&option_multibox=0&option_residential=0&option_validation=0&option_use_rules=0&
					##		dom=0&dom_packaging=00&dom_gnd=1&dom_3ds=1&dom_2dm=0&dom_2da=0&dom_1dp=0&dom_1da=0&dom_1dm=0&int=0&int_packaging=00&int_std=0&
					##		int_xsv=0&int_xpr=0&int_xdm=0&int_xpd=0

					my %upsapi_config = %{&ZTOOLKIT::parseparams($webdb->{'upsapi_config'})};

					## TODO: WE SHOULD CONSOLIDATE ALL THE WEBDB LOGIC SO IT *JUST* STORES TO UPSAPI_CONFIG
					my $enable_dom = 0;
					my $UPSAPI_DOM = 0;
					if ($params->{'dom'}) {
						foreach my $bit (keys %ZSHIP::UPSAPI::DOM_METHODS) {
							my $name = lc($ZSHIP::UPSAPI::DOM_METHODS{$bit});
							if ($params->{"dom_$name"}) { $UPSAPI_DOM |= $bit; }
							if ($params->{lc("dom_$name")}) { $UPSAPI_DOM |= $bit; }
							}
						}
					## this code is copied verbatim from the &ZSHIP::UPSAPI::upgrade_webdb function
					foreach my $bit (keys %ZSHIP::UPSAPI::DOM_METHODS) {
						my $upscode = $ZSHIP::UPSAPI::DOM_METHODS{$bit};
						$upsapi_config{ "$upscode" } = (int($UPSAPI_DOM) & $bit)?1:0;
						$enable_dom++;
						## $upscode is the *UPS* code e.g. GND
						}
					$upsapi_config{'enable_dom'} = $enable_dom;

					my $enable_int = 0;
					my $UPSAPI_INT = 0;
					if ($params->{'int'}) {
						foreach my $bit (keys %ZSHIP::UPSAPI::INT_METHODS) {
							my $name = lc($ZSHIP::UPSAPI::INT_METHODS{$bit});
							if ($params->{"int_$name"}) { $UPSAPI_INT |= $bit; }
							if ($params->{lc("int_$name")}) { $UPSAPI_INT |= $bit; }
							}
						}
					foreach my $bit (keys %ZSHIP::UPSAPI::INT_METHODS) {
						my $upscode = $ZSHIP::UPSAPI::INT_METHODS{$bit};
						$upsapi_config{ "$upscode" } = (int($UPSAPI_INT) & $bit)?1:0;
						$enable_int++;
						}
					$upsapi_config{'enable_int'} = $enable_int;

					my $UPSAPI_OPTIONS = 0;
					# multibox, residential, validation, use_rules
					#foreach my $bit (keys %ZSHIP::UPSAPI::OPTIONS) {
					#	my $name = $ZSHIP::UPSAPI::OPTIONS{$bit};
					#	if ($params->{"option_$name"}) { $UPSAPI_OPTIONS += $bit; }
					#	}

					$upsapi_config{'.rate_chart'} = $params->{'rate_chart'};
					# $upsapi_config{'.product'} = ($UPSAPI_OPTIONS&2)?1:0;
					$upsapi_config{'.multibox'} = $params->{'multibox'}; # ($UPSAPI_OPTIONS&4)?1:0;
					$upsapi_config{'.residential'} = $params->{'residential'}; # ($UPSAPI_OPTIONS&8)?1:0;
					$upsapi_config{'.validation'} = $params->{'validation'}; # ($UPSAPI_OPTIONS&16)?1:0;
					# $upsapi_config{'.use_rules'} = ($UPSAPI_OPTIONS&32)?1:0;
					# $upsapi_config{'.disable_pobox'} = ($UPSAPI_OPTIONS&64)?1:0;

					$upsapi_config{'.dom_packaging'} = $params->{'dom_packaging'};
					$upsapi_config{'.int_packaging'} = $params->{'int_packaging'};
					$webdb->{'upsapi_config'} = &ZTOOLKIT::buildparams(\%upsapi_config,1);

					# Save stuff here!
					if (defined $params->{'PRIMARY_SHIPPER'}) {
						$webdb->{'primary_shipper'} = 'UPS';
						}

					$LU->log("SETUP.SHIPPING.UPS","Saved UPS Settings","SAVE");
					push @MSGS, "SUCCESS|+Saved license to prt $PRT";
					}
				elsif ($params->{'provider'} eq 'FEDEX') {
					require ZSHIP::FEDEXWS;
					my $fdxcfg = ZSHIP::FEDEXWS::load_webdb_fedexws_cfg($USERNAME,$PRT,$webdb);
					$webdb->{'primary_shipper'} = 'FEDEX';
					$fdxcfg->{'rates'} = $params->{'rates'};
					$fdxcfg->{'enable'} = 0;
					if ($params->{'dom'}) { $fdxcfg->{'enable'} |= 1; }
					if ($params->{'int'}) { $fdxcfg->{'enable'} |= 2; }
					$fdxcfg->{'dom.nextearly'} = ($params->{'dom_nextearly'})?1:0;
					$fdxcfg->{'dom.nextnoon'} = ($params->{'dom_nextnoon'})?1:0;
					$fdxcfg->{'dom.nextday'} = ($params->{'dom_nextday'})?1:0;
					$fdxcfg->{'dom.2day'} = ($params->{'dom_2day'})?1:0;
					$fdxcfg->{'dom.3day'} = ($params->{'dom_3day'})?1:0;
					$fdxcfg->{'dom.ground'} = ($params->{'dom_ground'})?1:0;
					$fdxcfg->{'dom.home'} = ($params->{'dom_home'})?1:0;
					$fdxcfg->{'dom.home_eve'} = ($params->{'dom_evening'})?1:0;
					$fdxcfg->{'int.nextearly'} = ($params->{'int_nextearly'})?1:0;
					$fdxcfg->{'int.nextnoon'} = ($params->{'int_nextnoon'})?1:0;
					$fdxcfg->{'int.2day'} = ($params->{'int_2day'})?1:0;
					$fdxcfg->{'int.ground'} = ($params->{'int_ground'})?1:0;
					if ($params->{'supplier'} eq '') { 
						&ZSHIP::FEDEXWS::save_webdb_fedexws_cfg($USERNAME,$PRT,$fdxcfg,$webdb);
						push @MSGS, "SUCCESS|+Saved website $fdxcfg->{'src'} Settings";
						}
					#elsif ($params->{'supplier'} ne '') {
					#	my $SUPPLIER_ID = $params->{'supplier'};
					#	&ZSHIP::FEDEXWS::save_supplier_fedexws_cfg($USERNAME,$SUPPLIER_ID,$fdxcfg);	
					#	push @MSGS, "SUCCESS|+Saved Supplier $fdxcfg->{'src'} Settings";
					#	}	
					else {
						push @MSGS, "ERROR|+Unknown src: $fdxcfg->{'src'}";
						}
					}	
				elsif ($params->{'provider'} =~ /FLEX\:(.*?)$/) {
					my ($ID) = $1;

					my %ref = ();
					my $exist = &ZWEBSITE::ship_get_method($webdb,$ID);
					if (defined $exist) {
						## okay so we've already got some existing data, we'll load that
						%ref = %{$exist};
						}

					$ref{'rules'} = ($params->{'rules'})?1:0;
					$ref{'enable'} = $ref{'active'} = ($params->{'enable'})?1:0;

					$ref{'region'} = $params->{'region'};
					my $HANDLER = $ref{'handler'};			## NOTE: loaded by the provider (this is *not* passed by client)
		
					$ref{'name'} = $params->{'name'};
					$ref{'name'} =~ s/^[\s]+(.*?)$/$1/g;
					$ref{'name'} =~ s/(.*?)[\s]+$/$1/g;

					$ref{'carrier'} = uc($params->{'carrier'});
					$ref{'carrier'} =~ s/^[\s]+(.*?)$/$1/g;
					$ref{'carrier'} =~ s/(.*?)[\s]+$/$1/g;
					$ref{'carrier'} = substr($ref{'carrier'},0,4);
					$ref{'region'} = $params->{'region'};

					if ($ref{'handler'} eq 'SIMPLE') {
						my $itemprice = sprintf("%.2f",$params->{'itemprice'});
						$ref{'itemprice'} = $itemprice;
						my $addprice = sprintf("%.2f",$params->{'addprice'});
						$ref{'addprice'} = $addprice;
						}
					elsif ($ref{'handler'} eq 'PRICE') {
						$ref{'min_price'} = $params->{'min_price'};
						}
					elsif ($ref{'handler'} eq 'FREE') {
						$ref{'total'} = sprintf("%.2f",$params->{'total'});
						}

					&ZWEBSITE::ship_add_method($webdb,\%ref);
					}
				elsif ($params->{'provider'} eq 'HANDLING') {
					## HANDLING:
					$webdb->{'handling'} = int($params->{'enable'});		## 0=disable, 1=inc. in shipping, 2. own line item
					$webdb->{'hand_flat'} = ($params->{'flat'})?1:0;
					$webdb->{'hand_dom_item1'} = $params->{'dom_item1'};
					$webdb->{'hand_can_item1'} = $params->{'can_item1'};
					$webdb->{'hand_int_item1'} = $params->{'int_item1'};
					$webdb->{'hand_dom_item2'} = $params->{'dom_item2'};
					$webdb->{'hand_can_item2'} = $params->{'can_item2'};
					$webdb->{'hand_int_item2'} = $params->{'int_item2'};
					$webdb->{'hand_product'} = int($params->{'product'});	## bitwise field
					$webdb->{'hand_weight'} = ($params->{'enable_weight_table'})?1:0;
					}
				elsif ($params->{'provider'} eq 'INSURANCE') {
					## INSURANCE:
					$webdb->{'insurance'} = int($params->{'enable'});			## 0=disable, 1=inc. in shipping, 2. own line item
					$webdb->{'ins_optional'} = int($params->{'optional'});
					$webdb->{'ins_flat'} = ($params->{'flat'})?1:0;
					$webdb->{'ins_dom_item1'} = $params->{'dom_item1'};
					$webdb->{'ins_can_item1'} = $params->{'can_item1'};
					$webdb->{'ins_int_item1'} = $params->{'int_item1'};
					$webdb->{'ins_dom_item2'} = $params->{'dom_item2'};
					$webdb->{'ins_can_item2'} = $params->{'can_item2'};
					$webdb->{'ins_int_item2'} = $params->{'int_item2'};	
					$webdb->{'ins_product'} = int($params->{'product'}); 	## bitwise field.
					$webdb->{'ins_weight'} = ($params->{'enable_weight_table'}?1:0);	
					$webdb->{'ins_price'} = ($params->{'enable_price_table'})?1:0;
					}
				else {
					push @MSGS, "ERROR|+Unknown provider $params->{'provider'}";
					}
				}
			elsif ($cmd =~ /^(SHIPMETHOD|COUPON)\/RULESTABLE\-(EMPTY|UPDATE|INSERT|REMOVE)$/) {
				## SHIPMETHOD/RULES	COUPON/RULES
				my ($NOUN) = $1;
				my ($VERB) = $2;

				my $RULESETID = undef;
				if ($NOUN eq 'SHIPMETHOD') { 
					my $PROVIDER = $params->{'provider'};
					if ($PROVIDER =~ /^FLEX\:(.*?)$/) { $PROVIDER = $1; }	# strip FLEX:
					if ($PROVIDER eq 'FEDEX') { $PROVIDER = 'FEDEXAPI'; }
					if ($PROVIDER eq 'UPS') { $PROVIDER = 'UPSAPI'; }
					my $TABLE = $params->{'table'};
					if (($TABLE eq 'RULES') || ($PROVIDER eq 'INSURANCE') || ($PROVIDER eq 'HANDLING')) {
						$RULESETID = sprintf("SHIP-%s",$PROVIDER);
						}
					elsif (($PROVIDER eq 'FEDEXAPI') && ($TABLE eq 'DOM_EVENING')) {
						## needed to modify ths key because dom.home_eve needed to become dom.evening for api naming convention
						## and it was out-of-scope to modify the source data.
						$RULESETID = 'SHIP-FEDEXAPI_DOM_HOME_EVE';
						}
					else {
						$RULESETID = sprintf("SHIP-%s_%s",$PROVIDER,$TABLE);
						}
					}
				elsif ($NOUN eq 'COUPON') { 
					my $COUPON = $params->{'coupon'};
					$RULESETID = sprintf("COUPON-%s",$COUPON);
					}
				else {
					push @MSGS, "ERROR|+Invalid noun:$NOUN";
					}
				
				if ($VERB eq 'EMPTY') {
					&ZSHIP::RULES::empty_rules($webdb,$RULESETID);
					push @MSGS, "SUCCESS|+Emptied rules for $RULESETID";
					}
				elsif (($VERB eq 'INSERT') || ($VERB eq 'UPDATE')) {
					my %rule = ();
					$rule{'GUID'} = $params->{'guid'};
			 		$rule{'NAME'} = $params->{'name'};
			  		$rule{'FILTER'} = $params->{'filter'};
			  		$rule{'EXEC'} = $params->{'exec'};
			  		$rule{'MATCH'} = $params->{'match'};
			  		$rule{'VALUE'} = $params->{'value'};
			  		$rule{'SCHEDULE'} = $params->{'schedule'};
					$rule{'HINT'} = $params->{'hint'};

					if ($VERB eq 'INSERT') {
						$LU->log("SETUP.SHIPPING.RULES","Added Rule for $RULESETID","SAVE");
						$rule{'CREATED'} = &ZTOOLKIT::mysql_from_unixtime(time());
						$rule{'MODIFIED'} = &ZTOOLKIT::mysql_from_unixtime(time());
						&ZSHIP::RULES::append_rule($webdb,$RULESETID,\%rule); 
						}
					elsif ($VERB eq 'UPDATE') {
						my @rules = &ZSHIP::RULES::export_rules($webdb,$RULESETID);
						my $ID = &ZSHIP::RULES::resolve_guid_index(\@rules,$params->{'guid'}); 
						$rule{'MODIFIED'} = &ZTOOLKIT::mysql_from_unixtime(time());
						$LU->log("SETUP.SHIPPING.RULES","Updated Rule Content for $RULESETID","SAVE");
						&ZSHIP::RULES::update_rule($webdb,$RULESETID,$ID,\%rule);  
						}
					else {
						push @MSGS, "ERROR|+Unknown INTERNAL VERB:$VERB";
						}
					}
				elsif ($VERB eq 'REMOVE') {
					$LU->log("SETUP.SHIPPING.RULES","Deleted Rule for $RULESETID","SAVE");
					my @rules = &ZSHIP::RULES::export_rules($webdb,$RULESETID);
					my $ID = &ZSHIP::RULES::resolve_guid_index(\@rules,$params->{'guid'}); 
					if ($ID>-1) {
						&ZSHIP::RULES::delete_rule($webdb,$RULESETID,$ID);
						}
					else {
						push @MSGS, "ERROR|+Could not locate rule-guid:$params->{'guid'}"; 
						}
					}
				else {
					push @MSGS, "ERROR|+Unknown outer VERB:$VERB";
					}

				}
			elsif ($cmd eq 'PAYMENT/OFFLINE') {				
#				$webdb->{'payable_to'} = $params->{'payable_to'};
#				$webdb->{"pay_cash"} = $params->{'pay_cash'}; 
#				$webdb->{"pay_mo"} = $params->{'pay_mo'}; 
#				$webdb->{"pay_giftcard"} = $params->{'pay_giftcard'}; 
#				$webdb->{"pay_pickup"} = $params->{'pay_pickup'}; 
#				$webdb->{"pay_check"} = $params->{'pay_check'}; 
#				$webdb->{"pay_check_fee"} = $params->{'pay_check_fee'}; 
#				$webdb->{"pay_cod"} = $params->{'pay_cod'}; 	
#				$webdb->{"pay_cod_fee"} = $params->{'pay_cod_fee'}; 
#				$webdb->{"pay_chkod"} = $params->{'pay_chkod'}; 
#				$webdb->{"pay_chkod_fee"} = $params->{'pay_chkod_fee'}; 
#				$webdb->{"pay_po"} = $params->{'pay_po'}; 
#				$webdb->{"pay_wire"} = $params->{'pay_wire'}; 
#				$webdb->{"pay_wire_fee"} = $params->{'pay_wire_fee'}; 
#				$webdb->{"pay_wire_instructions"} = $params->{'pay_wire_instructions'}; 
				$webdb->{lc(sprintf("pay_%s",$params->{'tender'}))} = $params->{'enable'};
				if ($params->{'fee'}) {
					$webdb->{lc(sprintf("pay_%s_fee",$params->{'tender'}))} = $params->{'fee'};
					}
				if ($params->{'instructions'}) {
					$webdb->{lc(sprintf("pay_%s_instructions",$params->{'tender'}))} = $params->{'instructions'};
					}
				if ($params->{'payable_to'}) {
					$webdb->{'payable_to'} = $params->{'payable_to'};
					}
				# $LU->log('SETUP.PAYMENT.OFFLINE',"Updated payment offline settings","SAVE");
				}
			elsif ($cmd eq 'PAYMENT/GATEWAY') {
				my $tender = uc($params->{'tender'});
				if ($tender eq 'CC') {
					## CREDIT CARD/CC GATEWAY
					## common save - saves the following:
					##		webdb/pay_credit - a list of payment methods accepted
					##		cc_types = VISA,MC,AMEX,NOVUS

					## HIGH LEVEL REQUIRED FIELDS:
					$webdb->{"cc_processor"}   		= $params->{"processor"};
					$webdb->{"cc_instant_capture"}   = $params->{"cc_instant_capture"};
					$webdb->{"cc_avs_require"}       = $params->{"cc_avs_require"};
					$webdb->{"cc_cvv_review"}       	= $params->{"cc_cvv_review"};
					$webdb->{'cc_cvvcid'} 				= $params->{'cc_cvvcid'};
					$webdb->{"cc_type_visa"}			= $params->{'cc_type_visa'};
					$webdb->{"cc_type_amex"}			= $params->{'cc_type_amex'};
					$webdb->{"cc_type_mc"}				= $params->{'cc_type_mc'};
					$webdb->{"cc_type_novus"}			= $params->{'cc_type_novus'};
					$webdb->{"pay_credit"}           = int($params->{"enable"});

					my %fees = ();
					foreach my $k ('CC_TRANSFEE','CC_DISCRATE','VISA_TRANSFEE','VISA_DISCRATE','MC_TRANSFEE','MC_DISCRATE','AMEX_TRANSFEE','AMEX_DISCRATE','NOVUS_TRANSFEE','NOVUS_DISCRATE') {
						$fees{$k} = $params->{$k};
						}
					if (scalar(keys %fees)) { $webdb->{'cc_fees'} = &ZTOOLKIT::buildparams(\%fees); }

					if ($webdb->{'cc_processor'} eq 'ECHO') {
						if ($params->{"echo_username"}) { $webdb->{"echo_username"} = $params->{"echo_username"}; }
						if ($params->{"echo_password"} && $params->{"echo_password"} ne '') { $webdb->{"echo_password"} = $params->{"echo_password"}; }
						$webdb->{'echo_cybersource'} = $params->{'echo_cybersource'};
						}
					elsif ($webdb->{'cc_processor'} eq 'SKIPJACK') {
						$webdb->{'skipjack_htmlserial'} = $params->{'skipjack_htmlserial'};
						}
					elsif ($webdb->{'cc_processor'} eq 'VERISIGN') {
						$webdb->{"verisign_username"} = $params->{"verisign_username"}; 
						if ($params->{"verisign_password"} ne '') {
							$webdb->{"verisign_password"} = $params->{"verisign_password"}; 
							}
						$webdb->{"verisign_partner"}  = $params->{"verisign_partner"}; 
						$webdb->{"verisign_vendor"}   = $params->{"verisign_vendor"};
						}
					elsif ($webdb->{'cc_processor'} eq 'AUTHORIZENET') {
						$webdb->{"authorizenet_username"}   = $params->{"authorizenet_username"};
						if ($params->{"authorizenet_password"} ne '') { 
							$webdb->{"authorizenet_password"} = $params->{"authorizenet_password"}; 
							}
						$webdb->{"authorizenet_key"}        = $params->{"authorizenet_key"};
						}
					elsif ($webdb->{'cc_processor'} eq 'PAYPALWP') {
						}
					elsif ($webdb->{'cc_processor'} eq 'LINKPOINT') {
						if ($params->{"storename"}) { $webdb->{"storename"} = $params->{"storename"}; }
						my $x = $webdb->{"storename"};
						$x =~ s/[^\d]+//gs;
						if ($x ne $webdb->{'storename'} || $x eq '') {
							push @MSGS, "WARNING|+Critical Error: Linkpoint Store Name must be given, it must contain only numbers.";
							}
						$webdb->{'linkpoint_storename'} = $x;
						$webdb->{'storename'}           = $x;
						$webdb->{'pay_echeck'}           = $params->{'pay_echeck'};
						}
					elsif ($webdb->{'cc_processor'} eq 'MANUAL') {
						$webdb->{'cc_emulate_gateway'} = (defined $params->{'cc_emulate_gateway'})?1:0;
						}
					}
				elsif ($tender eq 'ECHECK') {
					## ECHECK GATEWAY
					$webdb->{'pay_echeck'}           = $params->{'pay_echeck'};
					foreach my $k ('pay_echeck','echeck_processor','echeck_request_check_number') {
						if (defined $params->{$k}) { $webdb->{$k} = $params->{$k}; }
						}
					$webdb->{'pay_echeck'}           = $params->{'pay_echeck'};
					$webdb->{'echeck_request_check_number'} = 1; ## Used by checkout to determine which fields to ask for
					$webdb->{'echeck_request_drivers_license_number'} = 1;
					$webdb->{'echeck_request_drivers_license_state'}  = 1;
					$webdb->{'echeck_request_drivers_license_exp'}    = 1;
					$webdb->{'echeck_request_business_account'}       = 1;
					$webdb->{'echeck_success_code'}  = $params->{'echeck_success_code'};
					$webdb->{'echeck_payable_to'}    = $params->{'echeck_payable_to'};
					if ($webdb->{'echeck_processor'} eq 'ECHO') {
						if ($params->{"echo_username"}) { $webdb->{"echo_username"} = $params->{"echo_username"}; }
						if ($params->{"echo_password"} && $params->{"echo_password"} ne '') { $webdb->{"echo_password"} = $params->{"echo_password"}; }
						$webdb->{'echo_cybersource'} = $params->{'echo_cybersource'};
						}
					if ($webdb->{'echeck_processor'} eq 'AUTHORIZENET') {
						$webdb->{"authorizenet_username"}   = $params->{"authorizenet_username"};
						if ($params->{"authorizenet_password"} ne '') { $webdb->{"authorizenet_password"} = $params->{"authorizenet_password"}; }
						$webdb->{"authorizenet_key"}        = $params->{"authorizenet_key"};
						$webdb->{'echeck_request_acct_name'} = 1; 
						}
					if ($webdb->{'echeck_processor'} eq 'LINKPOINT') {
						$webdb->{'echeck_processor'}   = 'LINKPOINT';
						if ($params->{"storename"}) { $webdb->{"storename"} = $params->{"storename"}; }

						my $x = $webdb->{"storename"};
						$x =~ s/[^\d]+//gs;
						if ($x ne $webdb->{'storename'} || $x eq '') {
							push @MSGS, "WARNING|+Critical Error: Linkpoint Store Name must be given, it must contain only numbers.";
							}
						$webdb->{'linkpoint_storename'} = $x;
						$webdb->{'storename'}           = $x;
						}
					}
				else {
					push @MSGS, "ERROR|+PAYMENT/GATEWAY tender type must be CC or ECHECK";
					}
				}
			elsif (($cmd eq 'PAYMENT/WALLET-AMZPAY') || ($cmd eq 'PAYMENT/WALLET-AMZCBA')) {
				$webdb->{'amzpay_button'} = &ZTOOLKIT::buildparams({
					color=>$params->{'color'},
					size=>$params->{'size'},
					background=>$params->{'background'},
					});
				$webdb->{'amzpay_env'} = int($params->{'amzpay_env'});
				## we don't set these fields here.
				$webdb->{'amz_merchantid'} = $params->{'amz_merchantid'};
				$webdb->{'amz_accesskey'} = $params->{'amz_accesskey'};
				$webdb->{'amz_secretkey'} = $params->{'amz_secretkey'};

				## no longer configurable
				## we currently only support these settings
				## - tax is always pulled from Amazon
				## - shipping is always pulled from Zoovy
				## - simple pay is not yet supported??
				$webdb->{'amzpay_tax'} = 1; 
				$webdb->{'amzpay_shipping'} = 1;
				$webdb->{'amzpay_simplepay'} = 0;
				}
			elsif ($cmd eq 'PAYMENT/WALLET-GOOGLE') {
				$params->{'google_key'} =~ s/[^A-Za-z0-9\-\_\+]+//gs;	# clean out unallowed chars.
				$webdb->{'google_key'} = $params->{'google_key'};
				$params->{'google_merchantid'} =~ s/[^\d]+//gs;	# clean out unallowed chars.
				$webdb->{'google_merchantid'} = $params->{'google_merchantid'};
				$webdb->{'google_api_env'} = $params->{'google_api_env'};
				$webdb->{'google_api_analytics'} = $params->{'google_api_analytics'};
				$webdb->{'google_api_merchantcalc'} = $params->{'google_api_merchantcalc'};
				$webdb->{'google_dest_zip'} = $params->{'google_dest_zip'};
				$webdb->{'google_int_shippolicy'} = int($params->{'google_int_shippolicy'});
				$webdb->{'google_pixelurls'} = $params->{'google_pixelurls'};
				$webdb->{'google_tax_tables'} = $params->{'google_tax_tables'};
				} 
			elsif ($cmd eq 'PAYMENT/WALLET-PAYPALEC') {
				$webdb->{'paypal_api_reqconfirmship'} = $params->{'paypal_api_reqconfirmship'};
				$webdb->{'paypal_api_callbacks'} = $params->{'paypal_api_callbacks'};
				$webdb->{'paypal_email'} = $params->{'paypal_email'};
				$webdb->{'paypal_email'} =~ s/[\s]+//g;

				$params->{'paypal_api_user'} =~ s/^[\s]+//gs;
				$params->{'paypal_api_user'} =~ s/[\s]+$//gs;
				$webdb->{'paypal_api_user'} = $params->{'paypal_api_user'};

				$params->{'paypal_api_pass'} =~ s/^[\s]+//gs;
				$params->{'paypal_api_pass'} =~ s/[\s]+$//gs;
				$webdb->{'paypal_api_pass'} = $params->{'paypal_api_pass'};

				$params->{'paypal_api_sig'} =~ s/^[\s]+//gs;
				$params->{'paypal_api_sig'} =~ s/[\s]+$//gs;
				$webdb->{'paypal_api_sig'} = $params->{'paypal_api_sig'};

				$webdb->{'paypal_paylater'} = (defined $params->{'paypal_paylater'})?1:0;
				
				$webdb->{'cc_instant_capture'} = $params->{'capture'};
				$webdb->{'paypal_api_env'} = $params->{'paypal_api_env'};
				$webdb->{'pay_paypalec'} = ($webdb->{'paypal_api_env'}>0)?0xFF:00;
				# $LU->log('SETUP.PAYMENT.PAYPALEC',"Updated Paypal Express Checkout settings","SAVE");
				}
			elsif ($cmd eq 'PAYMENT/CUSTOM') {
				$webdb->{'pay_custom'} = $params->{'tender'};
				$webdb->{'pay_custom_desc'} = $params->{'description'};
				# $LU->log('SETUP.PAYMENT.ADVANCED',"Updated Advanced Payment settings","SAVE");
				}
			else {
				push @MSGS, "ERROR|+Alas, the macro cmd you requested '$cmd not valid.";
				}

			if (scalar(@MSGS)>0) {	
				foreach my $msg (@MSGS) {
					&JSONAPI::add_macro_msg(\%R,$cmdset,$msg);
					}
				}
			} 



		if (defined $webdb) {
			&ZWEBSITE::save_website_dbref($USERNAME,$webdb,$self->prt());
			}

		if (defined $gref) {
			&ZWEBSITE::save_globalref($USERNAME,$gref);
			}

		}	
	
	return(\%R);
	}




#################################################################################
##
##
##

=pod

<API id="appPageSet">
<purpose></purpose>
<input id="PATH"> .path.to.page or @CAMPAIGNID</input>
<input id="%page"> an associative array of values you want updated</input>
<response id="attrib"></response>
<note>leave @get empty @get = [] for all page attributes</note>
</API>

=cut

sub appPageSet {
	my ($self,$v) = @_;
	my %R = ();

	my $p = undef;

	if ($v->{'PATH'} eq '') {
		&JSONAPI::set_error(\%R,'apperr',5603,"PATH not specified");
		}
	else {
		($p) = PAGE->new($self->username(),$v->{'PATH'},'PRT'=>$self->prt(),DOMAIN=>$self->sdomain());
		if (not defined $p) {
			&JSONAPI::set_error(\%R,'apperr',5602,sprintf("invalid PATH=%s",$v->{'PATH'}));			
			}
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (defined $v->{'%page'}) {
      foreach my $attr (keys %{$v->{'%page'}}) {
         if (lc($attr) eq $attr) {
            $p->set($attr,$v->{$attr});
            }
         }
      $p->save();
      &JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
	else {
		## request only wants specific attributes returned
		foreach my $attr (keys %{$v}) {
			if (lc($attr) eq $attr) {
				$p->set($attr,$v->{$attr});
				}
			}
		$p->save();
		&JSONAPI::append_msg_to_response(\%R,'success',0);						
		}


	#use Data::Dumper;
	#print STDERR Dumper($v,\%R);

	return(\%R);
	}






=pod

<API id="appShippingTransitEstimate">
<purpose></purpose>
<input id="@products">[pid1,pid2,pid3]</input>
<input id="ship_postal">92012</input>
<input id="ship_country">US</input>
<note></note>
<response hint="@Services">
<![CDATA[
                           {
                             'arrival_time' => '23:00:00',
                             'amzcc' => 'UPS',
                             'UPS.Service.Description' => 'UPS Ground',
                             'UPS.EstimatedArrival.DayOfWeek' => 'TUE',
                             'carrier' => 'UPS',
                             'expedited' => '0',
                             'UPS.Guaranteed' => 'Y',
                             'method' => 'UPS Ground',
                             'code' => 'UGND',
                             'ups' => 'GND',
                             'arrival_date' => '20120715',
                             'amzmethod' => 'UPS Ground',
                             'buycomtc' => '1',
                             'upsxml' => '03',
                             'UPS.EstimatedArrival.PickupDate' => '2012-07-10',
                             'transit_days' => 5
                           } 
]]></response>
<response hint="ships_yyyymmdd">which day the order is expected to ship (not arrive)</response>
<response hint="cutoff_hhmm">hour and minute (pst) that the order must be placed by</response>
<response hint="latency_days">maximum days before order ships</response>

</API>

=cut

sub appShippingTransitEstimate {
	my ($self,$v) = @_;
	my %R = ();


	if ($v->{'@products'} eq '') {
		&JSONAPI::set_error(\%R,'apperr',12000,"\@products is a required parameter");
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'ship_postal','')) {
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'ship_country','')) {
		}
	else {
		%R = %{&ZSHIP::time_in_transit($self->username(), $self->prt(), 'webdb'=>$self->webdb(), %{$v})};
		## do some error handling!?!
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	else {
		&JSONAPI::append_msg_to_response(\%R,'success',0);						
		}

	#use Data::Dumper;
	#print STDERR Dumper($v,\%R);

	return(\%R);
	}








#################################################################################
##
##
##

=pod

<API id="appSupplierInit">
<purpose></purpose>
<input id="supplier">xyz\@domain.com</input>
<input id="password">1234</input>
</API>

<API id="appSupplierAuthorize">
<purpose></purpose>
<input id="_cartid"> (must start with a ':') as returned by appSupplierInit</input>
<input id="hashtype"> md5|sha1</input>
<input id="hashpass"> hashtype(password+_cartid)</input>
<hint>
hashpass is generated by computing the md5 or sha1 hexadecimal value of the concatenation 
of both the plain text password, and the _cartid. Here are some examples (all examples assume password is 'secret' and 
the cartid is ':1234' 
MySQL: md5(concat('secret',':1234')) = 1ed15901cfc0cb8c61b43a440d853d45
MySQL: sha1(concat('secret',':1234')) = d9bc94d9c90e5de7a1c43a34f262d348244e9505
</hint>

</API>

=cut

##
##
sub appSupplierAuthorize {
	my ($self,$v) = @_;

	# use Digest::MD5;
	# my ($tryhash) = Digest::MD5::md5_hex($PASSWORD.$token);
	my %R = ();

	require AUTH;
	my ($MUSER,$DOMAIN,$USERNAME) = ();
	if ($v->{'supplier'} eq '') {
		&JSONAPI::set_error(\%R,'apperr',55,"supplier is required (and was blank)");
		}
	elsif ($v->{'supplier'} =~ /\@/) {
		($MUSER,$DOMAIN) = split(/\@/,$v->{'supplier'});
		($USERNAME) = &DOMAIN::TOOLS::domain_to_userprt($DOMAIN);
		}

	if (not &JSONAPI::hadError(\%R)) {
		}
	elsif (not $USERNAME) {
		&JSONAPI::set_error(\%R,'apperr',55,"USERNAME[$USERNAME] is not defined or could not be resolved.");
		}
	elsif ($v->{'hashpass'} eq '') {
		&JSONAPI::set_error(\%R,'apperr',8801,"Missing required parameter hashpass=");				
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'hashtype',['sha1','md5'])) {
		}
	elsif (substr($v->{'_cartid'},0,1) ne ':') {
		&JSONAPI::set_error(\%R,'apperr',8802,"Valid supplier sessions will begin with a colon.");
		}

	if (not &JSONAPI::hadError(\%R)) {
		require AUTH;
#		my ($ERROR) = AUTH::verify_credentials($USERNAME,$LUSER,substr($v->{'_cartid'},1),$v->{'hashtype'},$v->{'hashpass'});
#		if ($ERROR) {
#			&JSONAPI::set_error(\%R,'apperr',155,$ERROR);
#			}
		}

	if (not &JSONAPI::hadError(\%R)) {
#		my ($cartid) = &AUTH::authorize_session($USERNAME,$LUSER,substr($v->{'_cartid'},1));
#		if (not defined $cartid) {
#			&JSONAPI::set_error(\%R,'apperr',156,"Cart could not be upgraded to authorized status");
#			}
#		else {
#			$R{'_cartid'} = $cartid;
#			}
		}

	return(\%R);
	}


#################################################################################
##
##
##

=pod

<API id="appResource">
<purpose></purpose>
<input id="filename">filename.json</input>
<note>
* shipcodes.json
* shipcountries.json
* payment_status.json
* flexedit.json 
* review_status.json : a complete list of all valid review codes
* integrations.json : used to identify the MKT values in syndication/orders
* email_macros.json : 
* inventory_conditions.json : a complete list of all inventory conditions
* ups_license.json :
* syndication_buy_storecodes.json
* syndication_buy_categories.json
* syndication_wsh_categories.json
* syndication_goo_categories.json
* definitions/amz/[catalog].json : replace [catalog] with contents of amz:catalog field.
</note>
<response id="json">content to eval</response>



NOTE: You may also request filename.yaml or filename.xml (and the corresponding xml: or yaml: format will be returned)

</API>

=cut

sub appResource {
	my ($self,$v) = @_;
	my %R = ();

	my $EXT = '';
	my $FILENAME = undef;
	if ($v->{'filename'} eq '') {
		&JSONAPI::set_error(\%R,'apperr',18801,"no filename specified.");
		}
	elsif ($v->{'filename'} =~ /\.(json)$/) {
		$EXT = $1;
		$FILENAME = $v->{'filename'};
		}
	elsif ($v->{'filename'} =~ /\.(xml)$/) {
		$EXT = $1;
		$FILENAME = $v->{'filename'};
		}
	elsif ($v->{'filename'} =~ /\.(yaml)$/) {
		$EXT = $1;
		$FILENAME = $v->{'filename'};
		}
	else {
		&JSONAPI::set_error(\%R,'apperr',18802,"invalid file format requested.");
		}

	my $ref = undef;
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($FILENAME =~ /^shipcodes\.(.*?)$/) {
		$ref = \%ZSHIP::SHIPCODES;
		}
	elsif ($FILENAME =~ /^shipcountries\.(.*?)$/) { 
		$ref = Storable::retrieve("/httpd/static/country-highrisk.bin");
		}
	elsif ($FILENAME =~ /^product_attribs_all\.(.*?)$/) { 
		require PRODUCT::FLEXEDIT;
		$ref = \%PRODUCT::FLEXEDIT::fields;
		}
	elsif ($FILENAME =~ /^product_attribs_popular\.(.*?)$/) { 
		require PRODUCT::FLEXEDIT;
		$ref = Storable::dclone(\%PRODUCT::FLEXEDIT::fields);
		foreach my $id (keys %{$ref}) {
			if (not $ref->{$id}->{'popular'}) { delete $ref->{$id}; }
			}
		}
	elsif ($FILENAME =~ /^elastic_public\.(.*?)$/) { 
		require PRODUCT::FLEXEDIT;
		my ($elastic_product_fields) = PRODUCT::FLEXEDIT::elastic_fields($self->username());
		$ref = {
			'@products'=>$elastic_product_fields
			};
		}
	elsif ($FILENAME =~ /^payment_status\.(.*?)$/) { 
		require ZPAY;
		$ref = [];
		foreach my $ps (sort keys %ZPAY::PAYMENT_STATUS) {
			push @{$ref}, { 'ps'=>$ps, 'txt'=>$ZPAY::PAYMENT_STATUS{$ps} };
			}
		}
	elsif ($FILENAME =~ /^review_status\.(.*?)$/) { 
		require ZPAY;
		$ref = [];
		foreach my $rs (sort keys %ZPAY::REVIEW_STATUS) {
			push @{$ref}, { 'rs'=>$rs, 'txt'=>$ZPAY::REVIEW_STATUS{$rs} };
			}
		}
	elsif ($FILENAME =~ /^integrations\.(.*?)$/) {
		$ref = \@ZOOVY::INTEGRATIONS;
		}
	#elsif ($FILENAME =~ /^email_macros\.(.*?)$/) {
	#	require SITE::EMAILS;
	#	$ref = \@SITE::EMAILS::MACRO_HELP;
	#	}
	elsif ($FILENAME =~ /^amazon_catalogs\.(.*?)$/) {
		require AMAZON3;
		$ref = \%AMAZON3::CATALOGS;
		}
	elsif ($FILENAME =~ /^inventory_conditions\.(.*?)$/) {
		require ZOOVY;
		$ref = \@ZOOVY::INVENTORY_CONDITIONS;
		}
	elsif ($FILENAME =~ /^wms_conditions\.(.*?)$/) {
		require WMS;
		$ref = \@WMS::INVENTORY_CONDITIONS;
		}
	elsif ($FILENAME =~ /^ups_license\.(.*?)$/) {
		require ZSHIP::UPSAPI;
		$ref = {
			'brandstatement'=>$ZSHIP::UPSAPI::BRANDSTATEMENT,
			'license'=>$ZSHIP::UPSAPI::DISCLAIMER,
			'logo'=>$ZSHIP::UPSAPI::LOGO
			};
		}
	elsif ($FILENAME =~ /^ship_rules\.(.*?)$/) {
		require ZSHIP::RULES;
		$ref = {
			'match'=>$ZSHIP::RULES::MATCH,
			'exec'=>$ZSHIP::RULES::EXEC
			};
		}
	elsif ($FILENAME =~ /^return_stages\.(.*?)$/) {
		require ZOOVY;
		$ref = \@ZOOVY::RETURN_STAGES;
		}
	elsif ($FILENAME =~ /^recentnews\.(.*?)$/) {
		$EXT = $1;
		require HTTP::Tiny;
		require HTTP::Tiny;
		my $URL = "http://s3-us-west-1.amazonaws.com/commercerack-configs/resources/recentnews.json";
		my $response = HTTP::Tiny->new()->get($URL);
		if (not $response->{success}) {
			&JSONAPI::set_error(\%R,'apierr',18804,sprintf("%s %s %s",$URL,$response->{status},$response->{reason}));
			}
		elsif ($response->{'content'} !~ /^\[\{/) {
			&JSONAPI::set_error(\%R,'apierr',18805,sprintf("%s contained invalid json (%d bytes).",$URL,length($response->{'content'})));
			}
		else {
			$ref = JSON::XS::decode_json($response->{'content'});
			}
		}
	elsif ($FILENAME =~ /^quickstats\/(.*?)\.(.*?)$/) {
		require KPIBI;		
		my $ID = $1;
		my ($gms,$count,$units) = KPIBI::quick_stats($self->username(),$ID);
		$ref = { 'id'=>$ID, 'gms'=>$gms, 'count'=>$count, 'units'=>$units };
		}
	elsif ($FILENAME =~ /^syndication_buy_storecodes.(.*?)$/) {
		require SYNDICATION::BUYCOM;
		$ref = $SYNDICATION::BUYCOM::STORECODES;
		}
	elsif ($FILENAME =~ /^syndication_(.*?)_categories.(.*?)$/) {
		require SYNDICATION::CATEGORIES;
		my $DST = $1;
		my ($CDS) = SYNDICATION::CATEGORIES::CDSLoad($DST);
		if (defined $DST) {
			$ref = SYNDICATION::CATEGORIES::CDSByPath($CDS);
			}
		}
	elsif ($FILENAME =~ /^ebay\/(ShippingServiceDetails|ShippingLocationDetails)\.(.*?)$/) {
		my ($FILE,$EXT) = ($1,$2);
		$ref = {};
		if (-f "/httpd/static/ebay/$FILE.yaml") {
			$ref = YAML::Syck::LoadFile("/httpd/static/ebay/$FILE.yaml");
			}
		}
	elsif ($FILENAME =~ /^definitions\/([A-Z0-9a-z]+)\/(.*?)\.(json|yaml|xml)$/) {
		## ex: definitions/amz/CAMERA.OTHERACCESSORY.json
		my ($DST,$FILE,$EXT) = ($1,$2,$3);
		$DST = lc($DST);
	   $FILE =~ s/[^A-Za-z0-9\.]+//gs;
		$FILE = lc($FILE);
		$R{'src_file'} = $FILE;
		if ($DST eq 'amz') { $FILE = "amz.$FILE"; }
	   my $filepath = sprintf("/httpd/static/definitions/%s/%s.json",lc($DST),$FILE);
	   if (-f $filepath) { 
			my $json = &File::Slurp::read_file($filepath); 
		   if ($json ne '') {$ref = JSON::XS::decode_json($json); }
			}
		else {
			## HMM.. this might be a handy way to load static fields from FLEXEDIT
			#if ($FILE =~ /^\~(.*?)$/) {  
			#	$ref = PRODUCT::FLEXEDIT::get_GTOOLS_Form_grp($1); 
			#	}
			}
		}
	elsif ($FILENAME =~ /^sog-([0-Z][0-Z])\.(json|yaml|xml)/) {
		}
	else {
		&JSONAPI::set_error(\%R,'apperr',18803,"invalid file '$FILENAME' requested.");
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($EXT eq 'yaml') {
		require YAML::Syck;
		$R{'yaml'} = YAML::Syck::Dump($ref);
		}
	elsif ($EXT eq 'xml') { 
		require XML::Simple;
		my $xs = new XML::Simple(ForceArray=>1,KeyAttr=>"");
		$R{'xml'} = $xs->XMLout($ref);
		}
	elsif ($EXT eq 'json') { 
		$R{'contents'} = $ref;
		}
	return(\%R);
	}



#################################################################################
##
##
##

=pod

<API id="stub">
<purpose></purpose>
<input id="_cartid"></input>
<note>Does nothing, just a stub.</note>
</API>

=cut

sub stub {
	my ($self,$v) = @_;
	my %R = ();
	return(\%R);
	}



##
## legacy functions copied from prototype
##

## converts a hashref to a set of js_encoded key value pairs 
sub serialize_hashref {
	my ($ref) = @_;

	my $str = '';
	foreach my $k (keys %{$ref}) {
		$str .= sprintf("%s=%s&",&js_encode($k),&js_encode($ref->{$k}));
		}
	chop($str); 	# remove trailing &
	# print STDERR "serialized result: $str\n";
	return($str);
	}




##
## performs minimal uri encoding
##
sub js_encode {
	my ($str) = @_;

	if (not Encode::is_utf8($str)) {
		$str = Encode::encode_utf8($str);
		}

	my $string = '';
	foreach my $ch (split(//,$str)) {
		my $oi = ord($ch);
		if ((($oi>=48) && ($oi<58)) || (($oi>64) &&  ($oi<=127))) { $string .= $ch; }
		## don't encode <(60) or >(62) /(47)
		elsif (($oi==32) || ($oi==60) || ($oi==62) || ($oi==47)) { $string .= $ch; }
		else { $string .= '%'.sprintf("%02x",ord($ch));  }
		}
	return($string);
	}



=pod

<SECTION>
<h1>Releases Notes</h1>
* 2011/05/04: Added CUSTOMERPROCESS API call.
[[/SUBSECTION]]


</SECTION>

<SECTION>
<h1>Compatibility Levels</h1>
Current minimum compatibility level: 200 (released 11/15/10)
[[BREAK]]
[[STAFF]]
** when bumping compatibility level we should also change $WEBAPI::MAX_ALLOWED_COMPAT_LEVEL 
[[/STAFF]]

* 210: 9/17/12	 addition of uuid= in stuff
* 205: 1/5/12   ADDPRIVATE macro does an overrite, not an append. (backward compatibility release)
* 204: 12/29/11 fixes issues with payment processing (not explicitly declared in code, because they're "SAFE"/forward compat)
* 203: 10/24/11	has strict encoding rules for options, modifier must be encoded or there will be an error.
* 202: 10/24/11	(version 202 and lower adds backward support (via strip) for double quotes in stuff item options modifier=)
* 202: 5/6/11	 extends MSGID in emails node from 24 characters from 10
* 201: 2/16/11   adds MSGTYPE TICKET in emails node to WEBDBSYNC
* 200: 11/15/10  order generation version 5
* 117: 4/7/09  changes webdb sync in versioncheck
* 116: 5/21/08 re-enables image delete (for 116 and higher)
* 116: 4/10/08 note: 115 is was never apparently released due to bugs, skipping to 116 to be safe.
* 115: 2/23/08  [note: released to 114] changed format for stids (cheap hack: e.g.  abc/123*xyz:ffff  becomes 12
* 114: 12/26/07 new email changes (shuts down sendmail)
* 113: skipped for bad luck
* 112: 10/27/07 versions below have backward compatibility for company_logo in merchant sync
* 111: 10/09/07 convert ZOM and ZWM clients to ZID
* 110: 8/21/07 changes to events (ts was time)
* 109: 4/19/07 implements zoovy.virtual zoovy.prod_supplier zoovy.prod_supplierid removes supplier from skulist.
* 108: 3/13/07 changes xml output of stuff for orders
</SECTION>

=cut



## goes through and replaces all the keys that have colons with dashes e.g.
##		zoovy:prod_name becomes zoovy-prod_name
sub hashref_colon_to_dashxml {
	my ($hashref) = @_;

	my $BUFFER = "";
	my $k2 = '';
	foreach my $k (keys %{$hashref}) {
		next if (index($k,':')<0);
		$k2 = lc($k);
		$k2 =~ s/\:/-/;
		$BUFFER .= "<$k2>".&ZOOVY::incode($hashref->{$k})."</$k2>\n";
		}
	return($BUFFER);
	}


##
## SUPPLIERSYNC
##	
#=pod
#
#<SECTION>
#<h1>API: SUPPLIERSYNC</h1>
#sends XML data from pub1 to Supply Chain
#ie Order Confirmations
#</SECTION>
#
#=cut
#
sub supplierSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;
	
	require SUPPLIER;
	my ($API,$METHOD,$ACTION) = split(/\//,$XAPI,3);

	## SUPPLIER::from_xml deals with error handling
	my ($ERROR,$XML) = SUPPLIER::from_xml($USERNAME,$DATA,$METHOD,$ACTION,$::XCOMPAT);

	## embed error in XML as needed
	if ($ERROR ne '') { $XML .= "<Errors><Error>$ERROR</Error></Errors>"; }
	$XML = "<supplier$METHOD$ACTION>$XML</supplier$METHOD$ACTION>";

	return($ERROR,$XML);
	}


##
## Records the registration of a client.
##
sub registerSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	require ZTOOLKIT::SECUREKEY;
	my $securekey = &ZTOOLKIT::SECUREKEY::gen_key($USERNAME,'ZO');

	##
	## insert overly elaborate seat registration process here.
	##

	my $XML = qq~<SecureKey>$securekey</SecureKey>~;
	$XML = "<Registration>$XML</Registration>";
	
	return($XML);
	}




##
##
##

=pod


<API id="adminBatchJobParametersList">
<purpose></purpose>
<input id="BATCH_EXEC" value=""></input>
<output id="@PARAMETERS">
[
{ UUID:"", TITLE:"", BATCH_EXEC:"", LASTRUN_TS:"", LASTJOB_ID:"", PRIVATE:1  }
]
</output>
</API> 

<API id="adminBatchJobParametersCreate">
<purpose></purpose>
UUID:(optional)
TITLE: 
BATCH_EXEC: 
%vars: { variables based on type }
PRIVATE : 1|0 (will only appear in list for this user)
</API> 

<API id="adminBatchJobParametersRemove">
<purpose></purpose>
UUID:(optional)
</API> 

<API id="adminBatchJobList">
<purpose></purpose>
<output id="@JOBS">
type:job, id:####, guid:(guid), status:, title:
</output>
</API> 

<API id="adminBatchJobCreate">
<purpose></purpose>
guid:(optional)
type: SYNDICATION|REPORT|UTILITY,etc.
%vars: { variables based on type }
</API> 


<API id="adminBatchJobStatus">
<purpose></purpose>
</API> 

<API id="adminBatchJobCleanup">
<purpose></purpose>
</API> 

<API id="adminBatchJobDownload">
<purpose></purpose>
<input id="GUID"></input>
<input id="base64"></input>
<output id="FILENAME"></output>
<output id="MIME"></output>
<output id="body"></output>
</API> 

=cut



sub adminBatchJob {	
	my ($self,$v) = @_;


	my %R = ();
	my ($GUID) = $v->{'guid'};
	require BATCHJOB;

	my $USERNAME = $self->username();
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

#mysql> desc BATCH_PARAMETERS;
#+------------+------------------+------+-----+---------------------+-----------------------------+
#| Field      | Type             | Null | Key | Default             | Extra                       |
#+------------+------------------+------+-----+---------------------+-----------------------------+
#| ID         | int(10) unsigned | NO   | PRI | 0                   |                             |
#| UUID       | varchar(36)      | NO   |     |                     |                             |
#| MID        | int(11)          | NO   | MUL | 0                   |                             |
#| USERNAME   | varchar(20)      | NO   |     |                     |                             |
#| LUSER      | varchar(10)      | NO   |     |                     |                             |
#| TITLE      | varchar(80)      | YES  |     | NULL                |                             |
#| CREATED_TS | timestamp        | NO   |     | CURRENT_TIMESTAMP   | on update CURRENT_TIMESTAMP |
#| CREATED_BY | varchar(10)      | NO   |     |                     |                             |
#| LASTRUN_TS | timestamp        | NO   |     | 0000-00-00 00:00:00 |                             |
#| LASTJOB_ID | int(10) unsigned | NO   |     | 0                   |                             |
#| BATCH_EXEC | varchar(45)      | NO   |     |                     |                             |
#| APIVERSION | int(10) unsigned | NO   |     | 0                   |                             |
#| YAML       | text             | NO   |     | NULL                |                             |
#+------------+------------------+------+-----+---------------------+-----------------------------+
#13 rows in set (0.02 sec)

	my $BJ = undef;
	if ($v->{'_cmd'} eq 'adminBatchJobParametersList') {
		my $qtLUSER = $udbh->quote($self->luser());
		my $pstmt = "select UUID,TITLE,LASTRUN_TS,LASTJOB_ID,BATCH_EXEC,YAML from BATCH_PARAMETERS where MID=$MID /* $USERNAME */ and LUSER in ('',$qtLUSER) ";	
		if ($v->{'BATCH_EXEC'}) { $pstmt .= " and BATCH_EXEC=".$udbh->quote($v->{'BATCH_EXEC'}); }
		
		my $LIMIT = int($v->{'limit'});
		if ($LIMIT == 0) { $LIMIT = 50; }
		$pstmt .= " order by ID desc limit 0,$LIMIT";

		print STDERR "$pstmt\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $paramsref = $sth->fetchrow_hashref() ) {
			push @{$R{'@PARAMETERS'}}, $paramsref;
			}
		$sth->finish();
		&JSONAPI::append_msg_to_response(\%R,'success',0);
		}
	elsif ($v->{'_cmd'} eq 'adminBatchJobParametersCreate') {

		if (not &JSONAPI::validate_required_parameter(\%R,$v,'BATCH_EXEC')) {
			}
		elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'%vars')) {
			}

		if (not &JSONAPI::hadError(\%R)) {
			my %dbvars = ();
			$dbvars{'UUID'} = $v->{'UUID'} || Data::GUID->new()->as_string(); 
			$dbvars{'MID'} = $self->mid();
			$dbvars{'USERNAME'} = $self->username();
			$dbvars{'LUSER'} = ($v->{'PRIVATE'})?$self->luser():'';
			$dbvars{'TITLE'} = ($v->{'TITLE'} || sprintf("%s by %s on %s",$v->{'BATCH_EXEC'}, $self->luser(),&ZTOOLKIT::pretty_date(time(),1)));
			$dbvars{'*LASTRUN_TS'} = 0;
			$dbvars{'*LASTJOB_ID'} = 0;
			$dbvars{'BATCH_EXEC'} = $v->{'BATCH_EXEC'};
			$dbvars{'*CREATED_TS'} = 'now()';
			$dbvars{'CREATED_BY'} = $self->luser();
			$dbvars{'APIVERSION'} = $self->apiversion();
			$dbvars{'YAML'} = YAML::Syck::Dump($v->{'%vars'} || {});
	
			my $pstmt = &DBINFO::insert($udbh,'BATCH_PARAMETERS',\%dbvars,'verb'=>'insert','sql'=>1);
			print STDERR "$pstmt\n";
			&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
			if (not &JSONAPI::hadError(\%R)) {
				$R{'UUID'} = $dbvars{'UUID'};
				&JSONAPI::append_msg_to_response(\%R,'success',0);
				}
			}
		}
	elsif ($v->{'_cmd'} eq 'adminBatchJobParametersRemove') {
		## if you know the UUID its probably safe to assume you have permission to delete it.
		my $pstmt = "delete from BATCH_PARAMETERS where MID=$MID and UUID=".$udbh->quote($v->{'UUID'});
		print STDERR "$pstmt\n";
		&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
		&JSONAPI::append_msg_to_response(\%R,'success',0);
		}
	elsif ($v->{'_cmd'} eq 'adminBatchJobList') {
		my $pstmt = "select ID,TITLE,LUSERNAME,GUID,JOB_TYPE,STATUS,BATCH_EXEC,CREATED_TS,START_TS,IS_RUNNING,IS_CRASHED,IS_ABORTABLE from BATCH_JOBS where MID=$MID /* $USERNAME */ and ARCHIVED_TS=0 ";	
		if ($v->{'status'}) { $pstmt .= " and STATUS=".$udbh->quote($v->{'status'}); }
		if (not $v->{'archived'}) { $pstmt .= " and ARCHIVED_TS=0 ";  }
		
		my $LIMIT = int($v->{'limit'});
		if ($LIMIT == 0) { $LIMIT = 50; }
		$pstmt .= " order by ID desc limit 0,$LIMIT";

		print STDERR "$pstmt\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $hashref = $sth->fetchrow_hashref() ) {
			if ($self->apiversion()<=201334) {
				## convert EXPORT/whatever to EXPORT
				my ($MODULE,$VERB) = split(/\//,$hashref->{'BATCH_EXEC'},2);
				$hashref->{'BATCH_EXEC'} = $MODULE;
				}
			if ($self->apiversion()<201338) {
				if ($hashref->{'JOB_TYPE'} ne '') {
					($hashref->{'JOB_TYPE'}) = split(/\//,$hashref->{'BATCH_EXEC'});
					}
				}

			$hashref->{'JOBID'} = $hashref->{'ID'};
			push @{$R{'@JOBS'}}, $hashref;
			}
		$sth->finish();
		# print STDERR Dumper(\%R);
		&JSONAPI::append_msg_to_response(\%R,'success',0);
		}
	elsif ($v->{'_cmd'} eq 'adminBatchJobCreate') {

		my $JOBID = 0;
		my $GUID = $v->{'guid'};
		if ($v->{'guid'}) {
			($JOBID) = &BATCHJOB::resolve_guid($USERNAME,$v->{'guid'});
			}
		else {
			$GUID = &BATCHJOB::make_guid();
			}

		if (not &JSONAPI::validate_required_parameter(\%R,$v,'type')) {
			}
		else {
			## create the job
			## type = EXEC => BATCH_EXEC which should be something like EXPORT/PAGES
			## 	$menu.append("<li><a href='#' data-app-click='admin_batchjob|adminBatchJobExec' data-type='EXPORT/PAGES' >Export Pages.json</a></li>");


			## didn't feel like versioning 'type' in 201338 .. but we should be using BATCH_EXEC
			($BJ) = BATCHJOB->create($USERNAME,
				JOBID=>$JOBID,
				DOMAIN=>$self->sdomain(),
				PRT=>$self->prt(),
				GUID=>$GUID,
				VERSION=>$self->apiversion(),
				EXEC=>$v->{'type'},
				PARAMETERS_UUID=>$v->{'parameters_uuid'},
				'%VARS'=>$v->{'%vars'},
				'*LU'=>$self->LU(),
				);
			
			}

		if (&JSONAPI::hadError(\%R)) {
			## shit happened.
			}
		elsif ((defined $BJ) && (ref($BJ) eq 'BATCHJOB')) {
			}
		elsif ((ref($BJ) eq 'HASH') && ($BJ->{'err'})) {
			&JSONAPI::set_error(\%R, 'apperr', 9734, 'Batchjob was not created ('.$BJ->{'err'}.')');
			}
		else {
			&JSONAPI::set_error(\%R, 'apperr', 9735, 'Batchjob was not created (reason not specified)');
			}
		
		}
	else {
		## LOAD a job
		my $JOBID = 0;
		if ($v->{'guid'}) {
			($JOBID) = &BATCHJOB::resolve_guid($USERNAME,$v->{'guid'});
			if ($JOBID <= 0) {
				&JSONAPI::set_error(\%R, 'apperr', 9738,sprintf("batch job guid \"%s\" could not be located..",$v->{'guid'}));
				}
			}
		elsif ($v->{'jobid'}>0) {
			$JOBID = $v->{'jobid'};
			}
		else {
			&JSONAPI::set_error(\%R, 'apperr', 9739, sprintf("batch job guid \"%s\" could not be located..",$v->{'guid'}));
			}

		if ($JOBID>0) {
			($BJ) = BATCHJOB->new($USERNAME,$JOBID);
			}
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (&JSONAPI::hadSuccess(\%R)) {
		}
	elsif ($v->{'_cmd'} eq 'adminBatchJobList') {
		## this is fine to not have a $BJ
		}
	elsif (not defined $BJ) {
		&JSONAPI::set_error(\%R, 'iseerr', 9740, "batch job object not set");
		}
	elsif ($v->{'_cmd'} eq 'adminBatchJobCreate') {
		## stop throwing a 9742 error
		}
	elsif ($v->{'_cmd'} eq 'adminBatchJobDownload') {
		## CONFIRM REMOTE SIDE GOT IT.
		require LUSER::FILES;
		my ($lf) = LUSER::FILES->new($USERNAME);
		my ($TYPE,$FILENAME,$xGUID) = $lf->lookup(GUID=>$GUID);

		$R{'GUID'} = $GUID;
		$R{'FILENAME'} = $FILENAME;
		$R{'body'} = $lf->file_contents($FILENAME);

		my ($mime_type, $encoding) = MIME::Types::by_suffix($R{'FILENAME'});
		$R{'MIMETYPE'} = 'application/unknown';
		if ($mime_type eq '') {
			## NEED MORE?? 
			MIME::Types::import_mime_types("/httpd/conf/mime.types");
			($mime_type, $encoding) = MIME::Types::by_suffix($R{'FILENAME'});
			}
		if ($mime_type ne '') {
			$R{'MIMETYPE'} = "$mime_type";
			}

		## open F, ">/httpd/zoovy-htdocs/test.jpg"; print F $R{'body'}; close F;
		if (not defined $R{'FILENAME'}) {
			&JSONAPI::set_error(\%R,'apperr',23422,'File not found');			
			}
		elsif ((defined $v->{'base64'}) && ($v->{'base64'})) {
			($R{'body'}) = MIME::Base64::encode_base64($R{'body'},'');
			}
		else {
			&JSONAPI::append_msg_to_response(\%R,'success',0);
			}

		}
	elsif ($v->{'_cmd'} eq 'adminBatchJobCleanup') {
		## sets the "clean up" flag
		#	my $pstmt = "update BATCH_JOBS set CLEANUP_GMT=".time()." where MID=$MID /* $USERNAME */ and GUID=".$udbh->quote($GUID);
		#	print STDERR "$pstmt\n";
		#	&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
		$BJ->cleanup();
		&JSONAPI::append_msg_to_response(\%R,'success',0);
		}
	elsif ($v->{'_cmd'} eq 'adminBatchJobStatus') {
		## should probably be called: adminBatchJobDetail
		%R = $BJ->read();
		&JSONAPI::append_msg_to_response(\%R,'success',0);
		}
	else {
		&JSONAPI::set_error(\%R, 'iseerr', 9742, sprintf("adminBatchJobCMD unknown CMD '%s'",$v->{'_cmd'}));
		}

	if (&JSONAPI::hadError(\%R)) {
		}
	elsif (&JSONAPI::hadSuccess(\%R)) {
		}
	elsif ((defined $BJ) && (ref($BJ) eq 'BATCHJOB')) {
		$R{'guid'} = $BJ->guid();
		$R{'jobid'} = $BJ->id();
		if (defined $BJ->{'err'}) {
			&JSONAPI::set_error(\%R, 'iseerr', 9741, sprintf("batch job error '%s'",$BJ->{'err'}));
			}
		}
	else {
		## this line should never be reached.
		&JSONAPI::set_error(\%R,'iseerr', 9745, 'Batch error - something went horribly horribly wrong');
		}

	&DBINFO::db_user_close();

	return(\%R);
	}



##
## SYSTEM HEALTH
##



=pod

<API id="adminMySystemHealth">
<purpose>
Runs a series of diagnostics and returns 3 arrays @SYSTEM, @MYAPPS, @MARKET
the call itself may be *VERY* slow - taking up to 30 seconds.

each array will contain one or more responses ex:
{ 
	'type':'critical|issue|alert|bad|fyi|good',
	'system':'a short (3-12 char) global unique identifier for the system ex: Inventory',
	'title':'a pretty title for the message',
	'detail':'not always included, but provides more detail about a specific issue what that could mean, ex:
an unusually large number of unprocessed events does not mean there is a problem per-se,
it means many automation systems such as inventory, supply chain, 
marketplace tracking notifications and more could be delayed.',
	'debug':'xozo some internal crap that means something to a developer',
}

</purpose>
<response id="@SYSTEM"></response>
<response id="@MYAPPS"></response>
<response id="@MARKET"></response>
</API>

=cut

sub adminMySystemHealth {
	my ($self,$v) = @_;

	my %R = ();

	my @CLUSTER = ();
	my @MYAPPS = ();
	my @MARKET = ();

	$R{'ts'} = time();
	$R{'@CLUSTER'} = \@CLUSTER;
	push @CLUSTER, { 'type'=>'critical', 'title'=>'this is the alert ..', 'detail'=>'this is the detail about what this error means' };
	push @CLUSTER, { 'type'=>'issue', 'title'=>'this is the alert ..', 'detail'=>'this is the detail about what this error means' };
	push @CLUSTER, { 'type'=>'alert', 'title'=>'this is the alert ..', 'detail'=>'this is the detail about what this error means' };
	push @CLUSTER, { 'type'=>'bad', 'title'=>'this is the alert ..', 'detail'=>'this is the detail about what this error means' };
	push @CLUSTER, { 'type'=>'fyi', 'title'=>'this is the alert ..', 'detail'=>'this is the detail about what this error means' };
	push @CLUSTER, { 'type'=>'good', 'title'=>'this is the alert ..', 'detail'=>'this is the detail about what this error means' };

	$R{'@MYAPPS'} = \@MYAPPS;
	$R{'@MARKET'} = \@MARKET;

	&JSONAPI::append_msg_to_response(\%R,'success',0);				
	return(\%R);
	}



##
## SUPPORT/TICKET/CREATE
##


=pod

<API id="adminTechnicalRequest">
<purpose></purpose>
<input id="METHOD">CREATE</input>
</API>

=cut

sub adminTechnicalRequest {
	my ($self,$v) = @_;

	my %R = ();

	my ($USERNAME) = $self->username();
	require PLUGIN::HELPDESK;
	my ($globalref) = $self->globalref();
	my $overrides = $globalref->{'%overrides'};
	if (not defined $overrides) { $overrides = {}; }
	
	## NOTE: usually $::XCLIENTCODE is something like: ZID.OM.SOHO:8.077
	##			it is output in the subject of the ticket following a "v" e.g. "vZID.OM.SOHO:8.077"
	my $zidkey = $::XCLIENTCODE;
	if ((defined $overrides) && (defined $overrides->{$zidkey})) {
		## HEY SYSOPS: 
		##		in merchant global.bin put in key %overrides and then specific overrides in a key/value format:
		##		'%overrides'=> { 'ZID.OM.SOHO:8.077'=>'tickets_allowed_allowed=0' }
		##		specify multiple parameters in uri encoded format e.g.:
		##		'%overrides'=> { 'ZID.OM.SOHO:8.077'=>'tickets_allowed_allowed=0&future_compatibility=is_fun', }
		
		my ($versionsettings) = &ZTOOLKIT::parseparams($overrides->{$zidkey});
		foreach my $k (keys %{$versionsettings}) {	
			## copy keys from version specific overrides
			$overrides->{$k} = $versionsettings->{$k};
			}
		}

	my $tickets_allowed = 1;
	my $METHOD = $v->{'method'};
	if (defined $overrides->{'tickets_allowed'}) {
		## this key globally turns off webapi support tickets.
		$tickets_allowed = int($overrides->{'tickets_allowed'}); 	## allow by default.
		}

	if (not $tickets_allowed) {
		## no ticket functionality allowed.
		$R{'ticket_id'} = 0;
		}
	elsif ($METHOD eq 'CREATE') {
		my ($ticket) = PLUGIN::HELPDESK::create_ticket($USERNAME,
			ORIGIN=>'ZID',
			DISPOSITION=>'LOW',
			TECH=>'@ZID',
			BODY=>$v->{'body'},
			NOTIFY=>0,
			SUBJECT=>"WebAPI Ticket Dump v$::XCLIENTCODE",
			);
		$R{'ticket_id'} = $ticket;
		}
	else {
		&JSONAPI::set_error(\%R,"apperr",6077,"invalid method");		
		}
	
	return(\%R);
	}



################################################################################################################################
##
## sub: versioncheck
##

=pod

## &ZOOVY::msgAppend($self->username(),"",{
##         origin=>sprintf("job.%d",$self->id()),
##         icon=>"done",
##         msg=>"job.finished",
##         note=>sprintf("Job #%d $exec $verb has completed",$self->id()),
##         });

<API id="adminMessagesList">
<purpose></purpose>
<input id="msgid"></input>
<example><![CDATA[
ConfigVersion
Response
ResponseMsg
]]></example>
</API>

<API id="adminMessagesRemove">
<purpose></purpose>
<input id="msgid"></input>
<example><![CDATA[
ConfigVersion
Response
ResponseMsg
]]></example>
</API>


=cut

sub adminMessages {
	my ($self,$v) = @_;

	my %R = ();
	if ($v->{'_cmd'} eq 'adminMessagesList') {
		$R{'@MSGS'} = &ZOOVY::msgsGet($self->username(),'',int($v->{'msgid'}));
		}
	elsif ($v->{'_cmd'} eq 'adminMessagesEmpty') {
		&ZOOVY::msgClear($self->username(),'',-1);
		}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'msgid')) {
		}
	elsif ($v->{'_cmd'} eq 'adminMessageRemove') {
		&ZOOVY::msgClear($self->username(),'',int($v->{'msgid'}));
		}
	else {
		&JSONAPI::set_error(\%R,'iseerr',183832,sprintf("invalid command %s",$v->{'_cmd'}));		
		}

	return(\%R);
	}


##
## Sets up a sync token for the warehouse manager, sync manager, and order manager.
##

=pod

<API id="adminAccountDetail">
<purpose>Generates a new securekey for a given client. You must be given a client code by Zoovy to use this.</purpose>
</API>

=cut

sub adminAccountDetail {
	my ($self,$v) = @_;

	my $XAPI = '';
	my $USERNAME = $self->username();

	my ($API,$LOGIN) = split(/\//,$XAPI,2);
	my $LUSER = '';
	if (index($LOGIN,'*')>=0) { (undef,$LUSER) = split(/\*/,lc($LOGIN)); }
	my ($CODE,$VERSION) = split(/\:/,$::XCLIENTCODE,3);


	## 
	## Generate a new Token - and save that in the webdb (assuming this isn't support syncing)
	##
	my %R = ();
	my $TOKEN = '';

	my $gref = $self->globalref();
	my $cached_flags = ','.$gref->{'cached_flags'}.',';

	## needed for version 7 compatibility
	$cached_flags .= ',SOHONET,ZWM,';

	my @ERRORS = ();

	my $SEATS = 0;
#	if ($ENV{'SERVER_ADDR'} eq '192.168.99.14') {
#		## Dev is always authorized for everything.
#		}
	if ($CODE =~ /^ZID[\.]?(.*?)/) {
		## Currently ZID is authorized for everything.
		$CODE = 'ZID';
		}
	else {
		push @ERRORS, "Unknown Client $CODE";
		}

	if (($LUSER =~ /support/) || ($ENV{'SERVER_ADDR'} eq '192.168.99.14')) {	
		$TOKEN =  $gref->{'webapi_'.lc($CODE)};
		if (not defined $TOKEN) {
			my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,0);
			$TOKEN = $webdbref->{'token_'.lc($CODE)};
			}
		}
	else {
		my @characters = ('A' .. 'Z', 'a' .. 'z', 0 .. 9);
		my $cs = scalar(@characters);
		## my $s = (time()%$$) ^ $$ << time();
		my $s = (time()%$$) ^ $$ * time();
		srand($s);
		for (1 .. 1024) { $TOKEN .= $characters[rand $cs]; }

		## for now we'll save to both webdb and gref
		my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,0);
		$webdbref->{'token_'.lc($CODE)} = $TOKEN;
		&ZWEBSITE::save_website_dbref($USERNAME,$webdbref,0);

		$gref->{'webapi_'.lc($CODE)} = $TOKEN;
		&ZWEBSITE::save_globalref($USERNAME,$gref);
		}

	
	if (@ERRORS>0) {
		foreach my $err (@ERRORS) {
			&JSONAPI::set_error(\%R,'apierr',6085,"$err");
			}
		}
	else {
		## NO ERRORS, OUTPUT XML
		my $USERXML4XSL = '';
		my $MID = &ZOOVY::resolve_mid($USERNAME);
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select * from LUSERS where MID=$MID /* $USERNAME */";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		my @USERS = ();
		require Digest::MD5;
		while ( my $u = $sth->fetchrow_hashref() ) {
			$u->{'MD5PASS'} = Digest::MD5::md5_hex( $u->{'PASSWORD'} . $TOKEN );
			# delete $u->{'PASSWORD'};
			delete $u->{'MERCHANT'};
			delete $u->{'MID'};
			push @USERS, $u;
			}
		# &DBINFO::db_user_close();
		&DBINFO::db_user_close();

		require ZTOOLKIT::SECUREKEY;
		my $securekey = &ZTOOLKIT::SECUREKEY::gen_key($USERNAME,'ZO');

		my ($prtsref) = &ZWEBSITE::list_partitions($USERNAME);
		my $i = 0;
		my @PRTS = ();
		foreach my $prtref (@{$prtsref}) {
			my ($prtref) = &ZWEBSITE::prtinfo($USERNAME,$i);
			$prtref->{'id'} = $i;
			push @PRTS, $prtref;
			$i++;
			}

		$R{'SecureKey'} = $securekey;
		$R{'Seats'} = $SEATS;
		$R{'@Partitions'} = \@PRTS;
		$R{'@Users'} = \@USERS;
		}

	$R{'Username'} = $USERNAME;
	$R{'Flags'} = $cached_flags;

	return(\%R);
	}







################################################################################################################################
##
## sub: versioncheck
##

=pod

<API id="adminVersionCheck">
<purpose></purpose>
<input id="client"></input>
<input id="version"></input>
<input id="stationid"></input>
<input id="subuser"></input>
<input id="localip"></input>
<input id="osver"></input>
<input id="finger"></input>
<purpose>Checks the clients version and compatibility level against the API's current compatibility level.</purpose>
<output><![CDATA[
RESPONSE can be either
* OKAY - proceed with normal
* FAIL - a reason for the failure
* WARN - a warning, but it is okay to proceed
]]></output>
<example><![CDATA[
ConfigVersion
Response
ResponseMsg
]]></example>
</API>

=cut

sub adminVersionCheck {
	my ($self,$v) = @_;

	my ($CLIENT) = $v->{'client'};
	my ($VERSION) = $v->{'version'};
	my ($STATIONID) = $v->{'stationid'};
	my ($SUBUSER) = $v->{'subuser'};
	my ($LOCALIP) = $v->{'localip'};
	my ($OSVER) = $v->{'osver'};
	my ($FINGER) = $v->{'finger'};

	my ($MAJOR,$MINOR) = split(/\./,$VERSION,2);
	if (not defined $OSVER) { $OSVER = '?'; }
	if (not defined $FINGER) { $FINGER = '?'; }
	
	$OSVER =~ s/^Microsoft//gs;

	##
	## RESPONSE can be either
	##		OKAY - proceed with normal
	##		FAIL - a reason for the failure
	##		WARN - a warning, but it is okay to proceed
	##
	my $RESPONSE = 'FAIL';
	my $RESPONSEMESG = 'Unknown client: '.$CLIENT;
	my $USERNAME = $self->username();


#	if (1) {
#		$RESPONSE = 'FAIL'; $RESPONSEMESG = 'We are currently performing system maintenance'; 
#		}
	if ($CLIENT =~ /^ZID[\.](.*?)?/) {
		## ZID.????
		## NOTE: after version 8 -- this is the only client.
		$RESPONSE = 'OKAY'; $RESPONSEMESG = 'Elvis lives!';
		if ($MAJOR<11) {
#			$RESPONSE = 'WARN'; $RESPONSEMESG = 'Zoovy has upgraded our payment infrastructure. Please upgrade to the latest version of this software. If you continue to use this software we do not recommend processing payments.';
			$RESPONSE = 'WARN'; $RESPONSEMESG = 'This version will stop functioning on January 31st, 2011. You MUST upgrade before this date.';
			}
		elsif ($MAJOR<=8) {
			$RESPONSE = 'FAIL'; $RESPONSEMESG = 'This version has expired. Please upgrade to the latest version of this software';
			}
		}
	elsif ($CLIENT eq 'FOO') {
		$RESPONSE = 'WARN'; $RESPONSEMESG = 'Run away!';
		}

	my $udbh = &DBINFO::db_user_connect($USERNAME);	
	my $qtCLIENT = $udbh->quote($CLIENT.'='.$VERSION);
	$/ = undef; open F, "</proc/sys/kernel/hostname"; my $hostname = <F>; close F; $/ = "\n";
	$hostname =~ s/\W+//g;
	if (not defined $hostname) { $hostname = '?'; }
	
	&DBINFO::insert($udbh,'SYNC_LOG',{
		'USERNAME'=>$USERNAME,
		'MID'=>&ZOOVY::resolve_mid($USERNAME),
		'*CREATED'=>'now()',
		'CLIENT'=>"$CLIENT=$VERSION",
		'HOST'=>$hostname,
		'PUBLICIP'=>$ENV{'REMOTE_ADDR'},
		'REMOTEIP'=>$LOCALIP,
		'SYNCTYPE'=>$SUBUSER,
		'OSVER'=>$OSVER,
		'FINGERPRINT'=>$FINGER,
		});
	&DBINFO::db_user_close();

	my ($ts) = &ZOOVY::touched($USERNAME);
	my %R = ();
	$R{'Version'} = $ts;
	$R{'Response'} = $RESPONSE;
	$R{'ResponseMsg'} = $RESPONSEMESG;
	return(\%R);
	}



=pod

<API id="adminPublicFileList">
<purpose>
Public files are hosted at a URL and can be downloaded, they are usually things like short videos, etc.
</purpose>
<input id="fileguid">guid from fileupload</input>
<input id="filename"></input>
</API>

=cut

sub adminPublicFileList {
	my ($self,$v) = @_;

	my %R = ();
	my $USERNAME = $self->username();
	my $path = &ZOOVY::resolve_userpath($self->username());

	my $MEDIAHOST = &ZOOVY::resolve_media_host($self->username());

	my @FILES = ();
	my $D = ();
	opendir($D,$path.'/IMAGES');
	while (my $file = readdir($D)) {
		next if ($file =~ /^\./);
		next if (-d $path.'/IMAGES/'.$file);

		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($path.'/IMAGES/'.$file);
		push @FILES, { 'file'=>$file, 'created'=>$ctime, 'size'=>$size, link=>sprintf("http://$MEDIAHOST/media/merchant/$USERNAME/$file") };
		}
	closedir($D);
	&JSONAPI::append_msg_to_response(\%R,'success',0);		
	$R{'@files'} = \@FILES;
	
	return(\%R);
	}


=pod

<API id="adminPublicFileDelete">
<purpose>
Public files are hosted at a URL and can be downloaded, they are usually things like short videos, etc.
</purpose>
<input id="fileguid">guid from fileupload</input>
<input id="filename"></input>
</API>

=cut

#	'adminPublicFileDelete'=>[ \&JSONAPI::adminPublicFileDelete, { 'admin'=>1, 'cartid'=>0 }, 'admin' ],
sub adminPublicFileDelete {
	my ($self,$v) = @_;

	my %R = ();
	my $USERNAME = $self->username();
	my $path = &ZOOVY::resolve_userpath($self->username());

	## error anything which begins with a period, or begins with a slash
	my $filename = $v->{'filename'};
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'filename')) {
		}
	elsif ((substr($filename,0,1) eq '/') || (substr($filename,0,1) eq '.')) {
		&JSONAPI::set_error(\%R,'apperr',23423,'adminPublicFileDelete filename parameter is invalid');
		} 
	else {
		unlink($path.'/IMAGES/'.$filename);	
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		}
	return(\%R);
	}

	
=pod

<API id="adminPublicFileUpload">
<purpose>
Public files are hosted at a URL and can be downloaded, they are usually things like short videos, etc.
</purpose>
<input id="fileguid">guid from fileupload</input>
<input id="filename"></input>
</API>

=cut

#	'adminPublicFileList'=>[ \&JSONAPI::adminPublicFileList, { 'admin'=>1, 'cartid'=>0 }, 'admin' ],
#	'adminPublicFileDelete'=>[ \&JSONAPI::adminPublicFileDelete, { 'admin'=>1, 'cartid'=>0 }, 'admin' ],

sub adminPublicFileUpload {
	my ($self,$v) = @_;

	my %R = ();
	my $path = &ZOOVY::resolve_userpath($self->username());

	my $DATA = "";
	my ($pfu) = PLUGIN::FILEUPLOAD->new($self->username());
	$DATA = $pfu->fetch_file($v->{'fileguid'});
	if ($DATA ne '') {
		## fileguid retrieve decode success
		}
	elsif ($v->{'fileguid'} eq '') {
		&JSONAPI::set_error(\%R,'apperr',23219,'adminPublicFileUpload fileguid parameter was specified as blank');
		}
	else {
		&JSONAPI::set_error(\%R,'iseerr',23213,'adminPublicFileUpload not locate file from fileguid');
		}			

	#if (length($DATA)==0) {
	#	if ($filename =~ /http/i) {
	#		require ZURL;
	#		$DATA = &ZURL::snatch_url($filename);
	#		}
	#	}
	# at this point $DATA has the contents.
	if (length($DATA)>=3000000) {
		&JSONAPI::set_error(\%R,'apperr',23421,"File was too large, must be less than 3,000,000 bytes.");
		} 
	elsif (length($DATA)>0) {
		my ($f,$e) = &PLUGIN::FILEUPLOAD::strip_filename($v->{'filename'});
		if (! -d "$path/IMAGES") { mkdir (0777,"$path/IMAGES"); }
		open F, ">$path/IMAGES/$f.$e";
		print F $DATA;
		close F;
		&JSONAPI::append_msg_to_response(\%R,'success',0);		
		} 
	else {
		&JSONAPI::set_error(\%R,'apperr',23422,'File cannot be zero bytes');
		}

	return(\%R);
	}







############################################################################
## 
##	CSVIMPORT/PRODUCT
##



=pod


<API id="adminCSVExport">
<input id="export">CATEGORY|REWRITES</input>
<output id="lines"># of lines in the file</output>
<output id="body"></output>
<output id="base64">base64</output>
</API>


<API id="adminCSVImport">
<purpose><![CDATA[
This is a wrapper around the CSV file import available in the user interface.
Creates an import batch job. Filetype may be one of the following:
* PRODUCT
* INVENTORY
* CUSTOMER
* ORDER
* CATEGORY
* REVIEW
* REWRITES
* RULES
* LISTINGS

]]></purpose>
<hint>
The file type may also be overridden in the header. See the CSV import documentation for current
descriptions of the file. 
</hint>
<input id="filetype">PRODUCT|INVENTORY|CUSTOMER|ORDER|CATEGORY|REVIEW|REWRITES|RULES|LISTINGS</input>
<input id="fileguid" optional="1"> (required if base64 not set) guid from fileupload</input>
<input id="base64" optional="1"> (required if fileguid not set) base64 encoded payload</input>
<input id="[headers]">any specific headers for the file import</input>
<output id="JOBID"></output>
</API>

=cut


sub adminCSVExport {
	my ($self,$v) = @_;

	my $csv = Text::CSV_XS->new({binary=>1});          # create a new object

	my @HEADERS = ();
	my @OTHER_COLUMNS = ();
	my @LINES = ();


	print STDERR Dumper($v);

	if (defined $v->{'@headers'}) {
		foreach my $line (@{$v->{'@headers'}}) {
			push @HEADERS, $line;
			}
		}
	if (defined $v->{'@columns'}) {
		foreach my $col (@{$v->{'@columns'}}) {
			push @OTHER_COLUMNS, $col;
			}
		}
	if (defined $v->{'@OTHER_COLUMNS'}) {
		foreach my $col (@{$v->{'@OTHER_COLUMNS'}}) {
			push @OTHER_COLUMNS, $col;
			}
		}

	my %R = ();
	my $udbh = &DBINFO::db_user_connect($self->username());
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'export',['REWRITES','CATEGORY'])) {
		}
	elsif ($v->{'export'} eq 'REWRITES') {

		push @HEADERS, "#TYPE=REWRITES";
		
		my @COLUMNS = ();
		push @COLUMNS, "%DOMAIN";
		push @COLUMNS, "%PATH";
		push @COLUMNS, "%TARGERTURL";
		push @COLUMNS, "%CREATED";
		push @HEADERS, join("\r\n",@COLUMNS);

		#+-----------+--------------+------+-----+---------------------+----------------+
		#| Field     | Type         | Null | Key | Default             | Extra          |
		#+-----------+--------------+------+-----+---------------------+----------------+
		#| ID        | int(11)      | NO   | PRI | NULL                | auto_increment |
		#| USERNAME  | varchar(20)  | NO   |     |                     |                |
		#| MID       | int(11)      | NO   | MUL | 0                   |                |
		#| DOMAIN    | varchar(50)  | NO   |     |                     |                |
		#| PATH      | varchar(100) | NO   |     |                     |                |
		#| TARGETURL | varchar(200) | NO   |     |                     |                |
		#| CREATED   | datetime     | YES  |     | 0000-00-00 00:00:00 |                |
		#+-----------+--------------+------+-----+---------------------+----------------+

		my $MID = &ZOOVY::resolve_mid($self->username());
		my $DOMAIN = $self->sdomain();

		my $pstmt = "select DOMAIN,PATH,TARGETURL,CREATED from DOMAINS_URL_MAP where MID=$MID and DOMAIN=".$udbh->quote($DOMAIN);
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $row = $sth->fetchrow_hashref() ) {
			push @LINES, $row;
			}
		$sth->finish();
		}
	elsif ($v->{'export'} eq 'CATEGORY') {
		push @HEADERS, "#TYPE=CATEGORY";
		push @HEADERS, "# -- note: you need to keep the header line in here!";

		my @COLUMNS = ();
		push @COLUMNS, "%SAFE";
		push @COLUMNS, "%PRETTY";
		push @COLUMNS, "%SORT";
		push @COLUMNS, "%PRODUCTS";
		push @COLUMNS, "%METASTR";
		push @COLUMNS, "%LAYOUT";
		foreach my $col (@OTHER_COLUMNS) { 
			$col =~ s/^[\s]+//gs;	# strip leading spaces
			$col =~ s/[\s]+$//gs;	# strip trailing spaces
			push @COLUMNS, $col; 
			}
		push @HEADERS, sprintf("%s", join(',',@COLUMNS));

		require PAGE::BATCH;
		my ($ref) = PAGE::BATCH::fetch_pages($self->username(),PRT=>$self->prt());
		my $nc = NAVCAT->new($self->username(),PRT=>$self->prt());
		my $buf = '';
		foreach my $safe (sort $nc->paths()) {
			my ($pretty, $children, $productstr,$sortby,$metaref) = $nc->get($safe);
			my $meta = &NAVCAT::encode_meta($metaref);
		
			my @cols = ();
			push @cols, $safe;
			push @cols, $pretty;
			push @cols, $sortby;
			push @cols, $productstr;
			push @cols, $meta;	

			my $pg = $safe;
			if ($pg eq '.') { $pg = 'homepage'; }
			if ($pg eq '*cart') { $pg = 'cart'; }

			if (substr($safe,0,1) eq '$') {
				## not a category/page .. no page properties.
				}
			elsif (not defined $ref->{$pg}) {
				## hhmm.. doesn't exist.
				push @cols, '';
				}
			else {
				push @cols, $ref->{$pg}->{'fl'};
				foreach my $h (@OTHER_COLUMNS) {
					push @cols, &ZTOOLKIT::stripUnicode($ref->{$pg}->{lc($h)});
					}
				}
	
			my $status  = $csv->combine(@cols);  # combine columns into a string
			my $line    = $csv->string();           # get the combined string
			push @LINES, $line;
			}
		undef $nc;
		}
	&DBINFO::db_user_close();

	if (&JSONAPI::hadError(\%R)) {
		}
	else {
		$R{'lines'} = scalar(@LINES);
		$R{'MIMETYPE'} = "text/csv";
		$R{'body'} = join("\r\n",@HEADERS);		
		$R{'body'} .= "\r\n"; ## <-- the \r\n is necessary since join won't terminate with one.
		$R{'body'} .= join("\r\n",@LINES);	

		if ((defined $v->{'base64'}) && ($v->{'base64'})) {
			$R{'body'} = MIME::Base64::encode_base64($R{'body'},'');
			}


		}

	return(\%R);
	}


sub adminCSVImport {
	my ($self,$v) = @_;

	my %R = ();
	if (not &JSONAPI::validate_required_parameter(\%R,$v,'filetype')) {
		}

	# print STDERR Dumper($v)."\n";

	my $DATA = undef;
	if (&JSONAPI::hadError(\%R)) {
		}
	elsif ($v->{'base64'}) {
		$DATA = MIME::Base64::decode_base64($v->{'base64'});
		if ($DATA ne '') {
			## base64 decode success
			}
		elsif ($v->{'base64'} eq '') {
			&JSONAPI::set_error(\%R,'apperr',23412,'adminCSVImport base64 parameter was specified as blank');
			}
		else {
			&JSONAPI::set_error(\%R,'iseerr',23411,'adminCSVImport could not decode base64 payload');
			}
		
		}
	elsif ($v->{'fileguid'} ne '') {
		my ($pfu) = PLUGIN::FILEUPLOAD->new($self->username());
		$DATA = $pfu->fetch_file($v->{'fileguid'});
		if ($DATA ne '') {
			## fileguid retrieve decode success
			}
		else {
			&JSONAPI::set_error(\%R,'iseerr',23313,sprintf('fileguid \'%s\' is invalid',$v->{'fileguid'}));
			}			
		}
	else {
		&JSONAPI::set_error(\%R,'iseerr',23314,'no fileguid was received');
		}


	if (not &JSONAPI::hadError(\%R)) {
		
		delete $v->{'type'};		## the browser sents a type like APPLICATION/OCTET-STREAM

		require LUSER;
		require ZCSV;
		my ($LU) = $self->LU();
		my ($JOBID,$ERROR) = &ZCSV::addFile(
			'*LU'=>$LU,
			SRC=> sprintf("CSV.%d",$self->apiversion()),
			TYPE=>$v->{'filetype'},
			'%DIRECTIVES'=>$v,
			BUFFER=>$DATA
			);

		$R{'JOBID'} = $JOBID;
		if ($JOBID == 0) {
			&JSONAPI::set_error(\%R,'iseerr',23315,"$ERROR");
			}
		else {
			&JSONAPI::append_msg_to_response(\%R,'success',0);		
			}
		}
	
	return(\%R);
	}


=pod

<API id="API: adminSEOInit">
<purpose>Starts an SEO Session</purpose>
<output id="token"></input>
</API>

<API id="API: appSEOFetch">
<purpose></purpose>
<input id="token"></input>
<output id="@OBJECTS">
[
{ type:"product", pid:"" },
{ type:"product", pid:"", noindex:"1", xyz:"abc" },
{ type:"navcat", pid:"" }
]
</output>
</API>

<API id="API: appSEOStore">
<purpose></purpose>
<input id="token"></input>
<input id="_escaped_fragment_"></input>
<input id="html"></input>
</API>

<API id="API: appSEOFinish">
<purpose>Makes the token live, generates sitemap.xml based on submitted objects</purpose>
<input id="token"></input>
</API>

=cut


sub appSEO {
	my ($self, $v) = @_;

	my %R = ();
	my $USERNAME = $self->username();

	my ($redis) = &ZOOVY::getRedis($USERNAME,1);
	my $REDIS_KEY = undef;
	my $MID = $self->mid();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	if ($v->{'_cmd'} eq 'adminSEOInit') {
		if (not &validate_required_parameter(\%R,$v,'hostdomain')) {
			}
		else {
			my $GUID = Data::GUID->new()->as_string();
			if ($v->{'token'}) { $GUID = $v->{'token'}; }	## for debug
			$R{'token'} = $GUID;
			$redis->hset("SEO+$GUID","##",0);
			$redis->hset("SEO+$GUID","hostdomain",$v->{'hostdomain'});
			$redis->expire("SEO+$GUID",86400);
			}
		}
	elsif (($redis->exists($REDIS_KEY = sprintf("SEO+%s",$v->{'token'}))) eq '') {
		&JSONAPI::set_error(\%R,'apperr',65653,'SEO token does not exist, has completed, or has expired.');
		}
	elsif ($v->{'_cmd'} eq 'appSEOFetch') {
		my @OBJECTS = ();
		my $NC = NAVCAT->new($USERNAME,PRT=>$self->prt());	
		foreach my $path ($NC->paths("/")) {
			next if ($path eq '');
			next if (substr($path,0,1) eq '*');
			if (substr($path,0,1) eq '$') {
				push @OBJECTS, { 'type'=>'list', 'id'=>$path };
				}
			elsif (substr($path,0,1) eq '.') {
				push @OBJECTS, { 'type'=>'navcat', 'id'=>$path };
				}
			}
		foreach my $pid (&ZOOVY::fetchproduct_list_by_merchant($USERNAME)) {
			my ($P) = PRODUCT->new($USERNAME,$pid);
			my %TAGS = ( 'type'=>'pid', 'id'=>$pid, %{$P->seo_tags()} );
			push @OBJECTS, \%TAGS;
			}
		
		$R{'@OBJECTS'} = \@OBJECTS;
		}
	elsif (($v->{'_cmd'} eq 'appSEOStore') && (not &validate_required_parameter(\%R,$v,'html')) ) {
		}
	#elsif (not $self->projectid()) {
	#	&JSONAPI::set_error('iseerr',7847,'No projectid set.');
	#	}
	elsif (not &JSONAPI::validate_required_parameter(\%R,$v,'token')) {
		}
	elsif ($v->{'_cmd'} eq 'appSEOStore') {
		my $hostdomain = $redis->hget($REDIS_KEY,"hostdomain");


		my $fragment = $v->{'_escaped_fragment_'};
		if ((not $v->{'_escaped_fragment_'}) && ($v->{'#!'} ne '')) {
			$fragment = $v->{'#!'};  
			$fragment =~ s/\&/%26/gs;	
			}

		my $score = $v->{'score'} || 1;

		print STDERR "REDIS_KEY:$REDIS_KEY FRAGMENT:$fragment\n";
		if ($fragment eq '') {
			&JSONAPI::set_error(\%R,'apperr',65652,'fragment not set - please use _escaped_fragment_ or #!');
			}
		elsif ($hostdomain eq '') {
			&JSONAPI::set_error(\%R,'apperr',65652,'hostdomain is not set.');
			}
		else {
			if ($redis->hget($REDIS_KEY,$fragment) ne '') {
				my $pstmt = "delete from SEO_PAGES where MID=$MID and ESCAPED_FRAGMENT=".$udbh->quote($fragment);
				$udbh->do($pstmt);
				}

			my $pstmt = &DBINFO::insert($udbh,'SEO_PAGES',{
				'MID'=>&ZOOVY::resolve_mid($USERNAME),
				'*CREATED_TS'=>'now()',
				'GUID'=>$v->{'token'},
				'DOMAIN'=>$hostdomain,
				'ESCAPED_FRAGMENT'=>$fragment,
				'SITEMAP_SCORE'=>$score,
				'BODY'=>$v->{'html'}
				},'verb'=>'insert','sql'=>1);
			print STDERR "$pstmt\n";
			$udbh->do($pstmt);

			$redis->hincrby($REDIS_KEY, "##", 1);
			$redis->hset( $REDIS_KEY, $fragment, length($v->{'html'}) );
			}
		}
	elsif ($v->{'_cmd'} eq 'appSEOFinish') {
		my $qtGUID = $udbh->quote($v->{'token'});
		my $hostdomain = $redis->hget($REDIS_KEY,"hostdomain");

		my $PROJECTDIR = $self->projectdir($self->projectid());
		print STDERR "PROJECTDIR:$PROJECTDIR\n";

		my $qtHOSTDOMAIN = $udbh->quote($hostdomain);
		my $MID = $self->mid();

		my $pstmt = "select ESCAPED_FRAGMENT,SITEMAP_SCORE from SEO_PAGES where MID=$MID and DOMAIN=$qtHOSTDOMAIN and GUID=$qtGUID order by SITEMAP_SCORE";
		print STDERR "$pstmt\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		my @DATA = ();
		while ( my ($FRAGMENT, $SCORE) = $sth->fetchrow() ) {
			push @DATA, [ $FRAGMENT, $SCORE ];
			}
		$sth->finish();

		my $gmtdatetime = &ZTOOLKIT::pretty_date(time(),6);

		my $indexxml = '';
		my $inwriter = new XML::Writer(OUTPUT => \$indexxml, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');
		$inwriter->xmlDecl("UTF-8");	
		$inwriter->startTag("sitemapindex", "xmlns"=>"http://www.google.com/schemas/sitemap/0.84");

		my $batches = &ZTOOLKIT::batchify(\@DATA,2500);
		my $i = 0;
		foreach my $set (@{$batches}) {
	
			my $FILENAME = sprintf("sitemap-%s-%d.xml.gz",$hostdomain,++$i);

			$inwriter->startTag("sitemap");
			$inwriter->dataElement("loc","/$FILENAME");
			$inwriter->dataElement("lastmod",$gmtdatetime);
			$inwriter->endTag("sitemap");
	
			my $filexml = '';
			my $filewriter = new XML::Writer(OUTPUT => \$filexml, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');
			$filewriter->xmlDecl("UTF-8");	
			$filewriter->startTag("sitemapindex","xmlns"=>"http://www.sitemaps.org/schemas/sitemap/0.9");
			$filewriter->startTag("urlset","xmlns"=>"http://www.google.com/schemas/sitemap/0.84");
			foreach my $row (@{$set}) {
				$filewriter->startTag("url");
				$filewriter->dataElement("loc","/#!$row->[0]");
				$filewriter->dataElement("priority",$row->[1]);
				$filewriter->endTag();
				}
			$filewriter->endTag();
			$filewriter->endTag("sitemapindex");
			$filewriter->end();
	
			## SANITY: at this point $xml is built
			my $z = IO::Compress::Gzip->new("$PROJECTDIR/$FILENAME") or die("gzip failed\n");
			$z->print($filexml);
			$z->close();
			}
	
		$inwriter->endTag("sitemapindex");
		$inwriter->end();

		my $out = new IO::File ">$PROJECTDIR/sitemap.xml";
		print $out $indexxml;
		$out->close();

		$pstmt = "delete from SEO_PAGES where MID=$MID and DOMAIN=$qtHOSTDOMAIN and GUID!=$qtGUID";
		print STDERR $pstmt."\n";
		$udbh->do($pstmt);
		}
	&DBINFO::db_user_close();

	return(\%R);
	}



=pod

<API id="API: adminOrderReserve">
<purpose></purpose>
<input id="count"></input>
<response>
Returns an array, a list of order #'s
</response>
</API>

=cut


sub adminOrderReserve {
	my ($self,$v) = @_;

	my %R = ();
	my $BLOCK = int($v->{'count'});
	# if (!$BLOCK) { $BLOCK = "10"; }
	# if ($BLOCK<0) { $BLOCK = 1; }

	my $NEXTID = CART2::next_id($self->username(),$BLOCK);
	my ($YEAR,$MON,$THIS_ID) = split(/-/,$NEXTID,3);
	my $FIRST_ID = $THIS_ID;
	my $YEARMON = "$YEAR-$MON";
	my @RESERVED = ();
	while ($BLOCK-- > 0)  { push @RESERVED, "$YEARMON-".($THIS_ID-$BLOCK); }
	$R{'@RESERVED'} = \@RESERVED;

	$self->accesslog("WEBAPI.ORDERBLOCK","RESERVED $YEARMON range: $FIRST_ID - $THIS_ID");

	return(\%R);
	}




=pod

<API id="adminWalletList">
<purpose></purpose>

<input id="method">CHANGED</input>
<input id="limit">###</input>
<example><![CDATA[

@WALLETS : [
{ ID="" CID="" CREATED="" EXPIRES="" IS_DEFAULT="" DESCRIPTION="" ATTEMPTS="" FAILURES="" IS_DELETED="" }
{ ID="" CID="" CREATED="" EXPIRES="" IS_DEFAULT="" DESCRIPTION="" ATTEMPTS="" FAILURES="" IS_DELETED="" }
{ ID="" CID="" CREATED="" EXPIRES="" IS_DEFAULT="" DESCRIPTION="" ATTEMPTS="" FAILURES="" IS_DELETED="" }

]]>
</example>
<input id="method">ACK</input>
<input id="@WALLETS">an array of wallets to ack.</input>
</API>

=cut

sub adminWalletList {
	my ($self,$v) = @_;

	my %R = ();
	my ($USERNAME) = $self->username();
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	require GIFTCARD;
	
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	if ($v->{'method'} eq 'CHANGED') {
		my $LIMIT = int($v->{'limit'});
		my @wallets = ();
		my $pstmt = "select ID,CID,CREATED,EXPIRES,IS_DEFAULT,DESCRIPTION,ATTEMPTS,FAILURES,IS_DELETED from CUSTOMER_SECURE where MID=$MID /* $USERNAME */ and SYNCED_GMT=0 limit 0,$LIMIT";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $ref = $sth->fetchrow_hashref() ) {
			push @wallets, $ref;
			}
		$sth->finish();
		$R{'@WALLETS'} = \@wallets;
		}
	elsif ($v->{'method'} eq 'ACK') {
	#	$xml = qq~<WALLET>
	#	<GIFTCARD ID="1" ACK="Y"/>
	#	<GIFTCARD ID="2" ACK="Y"/>
	#	<GIFTCARD ID="3" ACK="Y"/>
	#	</WALLET>
	#	~;
		my @ACKS = ();
		foreach my $incref (@{$v->{'@WALLETS'}}) {
			# print STDERR Dumper($incref);
			if ($incref->{'ACK'} eq 'Y') {
				push @ACKS, $incref->{'ID'};
		      }
			else {
				warn "no acks for $incref->{'ID'}\n";
				}
			}
		my $ts = time();
		# print STDERR 'ACKS:'.Dumper(\@ACKS);
		if (scalar(@ACKS)>0) {
			my $pstmt = "update CUSTOMER_SECURE set SYNCED_GMT=$ts where MID=$MID /* $USERNAME */ and ID in ".&DBINFO::makeset($udbh,\@ACKS);
			print STDERR $pstmt."\n";
			&JSONAPI::dbh_do(\%R,$udbh,$pstmt);
			}	
		}
	elsif ($v->{'method'} eq 'CREATE') {
		#my ($code) = &GIFTCARD::createCard($USERNAME,$BALANCE);
		#$XML = "<GIFTCARDS><GIFTCARD CODE=\"$code\"></GIFTCARD></GIFTCARDS>";	
		}
	&DBINFO::db_user_close();

	return(\%R)
	}




##
#   since this ebay change is going to be disruptive. I've copied an old version of adminEBAYCategory
#	 in to JSONAPI and named it adminEBAYCategory201330
#
#	then in adminEBAYCategory I've done -- this should make it safe to push JSONAPI and will 
#		leave the old categories on production.
#
#	if ($self->apiversion()<201332) {
#      ## short circuit for legacy ebay categories.
#      return(&JSONAPI::adminEBAYCategory201330($self,$v));
#      }

sub adminEBAYCategory {	
	my ($self,$v) = @_;
	my %R = ();

	require EBAY2;
	require EBAY2::ATTRIBUTES;

	print STDERR "-------------------- APIVERSION: ".$self->apiversion()."\n";

	my ($MID) = $self->mid();
	my ($USERNAME) = $self->username();
	#my ($udbh) = &DBINFO::db_user_connect($self->username());
	my ($edbh) = &EBAY2::db_resource_connect($self->apiversion());
	if (not $edbh) {
		&JSONAPI::set_error(\%R,'iseerr',2392,'eBay resource database not available');
		return(\%R);
		}

	my $REDIS_RECENTCATEGORIES_KEY = sprintf("ebay.recent_categories.%s",$USERNAME);

	my ($SITE) = undef;
	if ($v->{'site'}) { $SITE = $v->{'site'};  }
	if ($v->{'categoryid'} =~ /\.([\d]+)$/) { $SITE = $1;  }
	if (not defined $SITE) { $SITE = 0; }
	$R{'#site'} = $SITE;

	if (&hadError(\%R)) {
		}
	elsif ($v->{'pid'}) {
		## if we already saved category and user wants to review
		## lets begin from category + saved specifics form
		my ($P) = PRODUCT->new($USERNAME,$v->{'pid'},'create'=>0);
		$R{'ebay:category'} = $P->fetch('ebay:category');
		if ($R{'ebay:category'} =~ /\.([\d])+$/) { $R{'#site'} = $1; }
		#$R{'ebay:category_name'} = &EBAY2::get_cat_fullname($USERNAME,$R{'ebay:category'});

		$R{'ebay:category2'} = $P->fetch('ebay:category2');
		# $R{'ebay:category2_name'} = &EBAY2::get_cat_fullname($USERNAME,$R{'ebay:category2'});

		$R{'ebay:itemspecifics'} = $P->fetch('ebay:itemspecifics');
		$R{'ebay:attributeset'} = $P->fetch('ebay:attributeset');

		if (($R{'ebay:itemspecifics'} eq '') && ($R{'ebay:attributeset'} =~ /<ItemSpecifics>/)) {
			## upgrade old compat structure
			my ($ATTRSREF,$CUSTOMREF) = &EBAY2::ATTRIBUTES::ebayattributeset_to_attributesreference($R{'ebay:attributeset'});
			$R{'ebay:itemspecifics'} = &PRODUCT::FLEXEDIT::wikihash_encode($CUSTOMREF);
			}

		# my $ebaycat = $R{'ebay:category'};
		# if ($ebaycat =~ /(\d+)\./) { $ebaycat = $1; }	## strip site ex: 1234.100 (100=ebay motors)
		# my ($res) = $edbh->selectrow_array("SELECT id FROM ebay_categories WHERE id=".int($ebaycat));		## NOTE: we must *int* to drop the site
		}

	if (&hadError(\%R)) {
		}
	elsif ($v->{'categoryid'} == 0) {
		my @categories;

		my ($redis) = &ZOOVY::getRedis($self->username(),2);
		my @RECENT_CATEGORIES = $redis->lrange($REDIS_RECENTCATEGORIES_KEY,0,100);

		my %SEEN = ();
		foreach my $catid (@RECENT_CATEGORIES) {
			next if ($SEEN{$catid});
			my $pstmt = qq~SELECT ec.site, ec.name FROM ebay_categories ec where ec.id=~.int($catid);
			my ($siteid,$name) = $edbh->selectrow_array($pstmt);
			if (defined $siteid) {
				push @categories, { 'site'=>$siteid, 'categoryid'=>$catid, 'name'=>$name };
				}
			$SEEN{$catid}++;			
			}
		
		#my $pstmt = qq~SELECT ec.id, ec.site, ec.name FROM ebay_categories ec, ebay_last_categories elc WHERE	(elc.user_id=$MID) AND (ec.id=elc.category_id) ORDER BY elc.create_timestamp DESC~;			
		#my $sth = $edbh->prepare($pstmt);
		#$sth->execute or die $sth->errstr;
		#while ( my ($cat_id, $site, $cat_name) = $sth->fetchrow_array ) {
		#	my $cat = {};
		#	$cat->{'categoryid'} = $cat_id;
		#	$cat->{name} = $cat_name;
		#	push @categories, $cat;
		#	}
		#$sth->finish();
		$R{'@USER_RECENT'} = \@categories;

		## ROOT LEVEL CHILDREN parent_id=id
		my @CHILDREN = ();
		my $sth = $edbh->prepare("SELECT id as categoryid, site, name, leaf, item_specifics_enabled from ebay_categories where parent_id=id");
		$sth->execute;
		while ( my $catref = $sth->fetchrow_hashref ) {
			$catref->{'children_count'} = $edbh->selectrow_array("SELECT count(id) FROM ebay_categories WHERE parent_id=".int($catref->{'categoryid'}));
			push @CHILDREN, $catref;
			}
		$R{'@CHILDREN'} = \@CHILDREN;
		}



	if (&hadError(\%R)) {
		}
	elsif ($v->{'categoryid'}>0) {
		my %INFO = ();
		$R{'%INFO'} = \%INFO;
	
		## extract this category with all children from db
		my $ref = $edbh->selectrow_hashref("SELECT id as categoryid, site, name, leaf, level, parent_id, item_specifics_enabled, product_search_page_available, catalog_enabled FROM ebay_categories WHERE id=".int($v->{'categoryid'}));
		if (defined $ref) { foreach my $k (keys %{$ref}) { $INFO{$k} = $ref->{$k}; } }	## copy info $INFO
		if ($INFO{'parent_id'} == $INFO{'category_id'}) { $INFO{'parent_id'} = 0; }

		my @CHILDREN = ();
		my $sth = $edbh->prepare("SELECT id as categoryid, site, name, leaf, item_specifics_enabled, parent_id from ebay_categories where parent_id=".int($v->{'categoryid'}));
		$sth->execute;
		while ( my $catref = $sth->fetchrow_hashref ) {
			next if ($catref->{'categoryid'} == $catref->{'parent_id'});	## ignore root level categories
			$catref->{'children_count'} = $edbh->selectrow_array("SELECT count(id) FROM ebay_categories WHERE parent_id=".int($catref->{'categoryid'}));
			push @CHILDREN, $catref;
			}
		$INFO{'children_count'} = scalar(@CHILDREN);
		$R{'@CHILDREN'} = \@CHILDREN;

		## recurse current category, and get all parent categories up to the root (usefor for showing a breadcrumb) -- eventually might be used to find item specifics
		my @PARENTS = ();
		my $PARENTID = $INFO{'parent_id'};
		while ($PARENTID>0) {
			my $catref = $edbh->selectrow_hashref('SELECT id as categoryid, site, name, leaf, item_specifics_enabled, level, parent_id from ebay_categories where id='.$PARENTID);
			push @PARENTS, $catref;
			if ($PARENTID == $catref->{'parent_id'}) {
			## if we are our own parent, then we're really root
				$PARENTID = 0;
				}
			else {
				## set parent to our parent, so we can move up the tree towards the root.
				$PARENTID = $catref->{'parent_id'};
				}
			}
		$R{'@PARENTS'} = \@PARENTS;

		if ($INFO{'leaf'}) {
			## leaf category is a place where you can add your item.
			## so we gonna to render One-Attribute Search form (for categories with
			## ProductSearchPageAvailable) or Product Finder form (for categories,
			## supportion product finders) or simply render 'Describe your item'
			## with choose custom specifics form if any.

			my ($redis) = &ZOOVY::getRedis($self->username(),2);
			print STDERR "STORING: $REDIS_RECENTCATEGORIES_KEY,$INFO{'categoryid'}\n";
			$redis->lpush($REDIS_RECENTCATEGORIES_KEY,$INFO{'categoryid'});
			$redis->ltrim($REDIS_RECENTCATEGORIES_KEY,0,100);	## only remember the last 100 categories used. (dups removed later)
			$redis->expire($REDIS_RECENTCATEGORIES_KEY,86400*15);	## don't remember any categories after 15 days.
			}

		if ($INFO{'leaf'} && $INFO{'item_specifics_enabled'}) {
			## we don't use ebay:attributeset and ID-based attributes anymore
			## hovewer ebay:itemspecifics will stay and new recommended specifics also will go there

			## read ebay recommended item specifics .json chunk for the current category
			## and return in to the app-admin, where it will produce html form from this data
			#my $PATH_TO_STATIC = &EBAY2::resolve_resource_path($self->apiversion());
			my $rec = $edbh->selectrow_hashref("SELECT * FROM ebay_specifics WHERE site=? AND cid=?",{},$INFO{site},$INFO{'categoryid'});
        			if($rec && $rec->{json} && $rec->{json} !~ /^null/) {
					require JSON::XS;
					require Compress::Zlib;
					my $recommended_json = Compress::Zlib::memGunzip($rec->{json});
					#$recommended_json = &ZTOOLKIT::stripUnicode($recommended_json);
                			$R{'@RECOMMENDATIONS'} = JSON::XS::decode_json($recommended_json); 
				}
			}
		}


	#&DBINFO::db_user_close();
	$edbh->disconnect() if $edbh;
	return(\%R);
	}








