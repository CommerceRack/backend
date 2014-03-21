package TOXML::RENDER;

use Data::Dumper;
use strict;
use URI::Escape::XS qw();
use IO::File;
use XML::Simple;
use HTML::Entities;
use encoding 'utf8';
use JSON::XS qw();
use utf8 qw();
use Encode qw();
no warnings 'once';    # Keeps perl -w from bitching about single-use variables

use lib '/backend/lib';
require TOXML;
require NAVCAT;
#require IMGLIB::Lite;
require ZOOVY;
require PRODUCT;
require SEARCH;
require TOXML::SPECL3;
require ZWEBSITE;
require CART2;
require CART2::VIEW;
require SITE;
#use ZTOOLKIT qw(def gstr num untab moneyformat value_sort pretty htmlstrip isin);
require ZTOOLKIT;
require INVENTORY2;

sub pint { ZTOOLKIT::pint(@_); }
sub def { return &ZTOOLKIT::def(@_); }
sub gstr { return &ZTOOLKIT::gstr(@_); }
sub num { return &ZTOOLKIT::num(@_); }
sub untab { return &ZTOOLKIT::untab(@_); }
sub value_sort { return &ZTOOLKIT::value_sort(@_); }
sub isin { return &ZTOOLKIT::isin(@_); }

$TOXML::RENDER::DEBUG = 0;

# These are all of the flow renderers
%TOXML::RENDER::render_element = (
	'OVERLOAD'		 => \&TOXML::RENDER::RENDER_OVERLOAD,
#	'JSON'			 => \&TOXML::RENDER::RENDER_JSON,
	'NULL'			 => \&TOXML::RENDER::RENDER_NULL,
	'FONT'          => \&TOXML::RENDER::RENDER_FONT,
	'TEXT'          => \&TOXML::RENDER::RENDER_TEXT,
	'PRODLIST'      => \&TOXML::RENDER::RENDER_PRODLIST,
	'BANNER'			 => \&TOXML::RENDER::RENDER_BANNER,
	'IMAGE'         => \&TOXML::RENDER::RENDER_IMAGE,
	'TEXTBOX'       => \&TOXML::RENDER::RENDER_TEXT,
	'TEXTAREA'		 => \&TOXML::RENDER::RENDER_TEXT,
	'READONLY'      => \&TOXML::RENDER::RENDER_READONLY,
	'TEXTCHOICE'    => \&TOXML::RENDER::RENDER_TEXTCHOICE,
	'HITGRAPH'      => \&TOXML::RENDER::RENDER_HITGRAPH,
	'CART'          => \&TOXML::RENDER::RENDER_CART,
	'DECAL'			 => \&TOXML::RENDER::RENDER_DECAL,
	'ORDER'     	 => \&TOXML::RENDER::RENDER_ORDER,
	'SLIDE'         => \&TOXML::RENDER::RENDER_SLIDE,
	'DYNIMAGE'      => \&TOXML::RENDER::RENDER_DYNIMAGE,
	'ADDTOCART'     => \&TOXML::RENDER::RENDER_ADDTOCART,
	'MAILFORM'      => \&TOXML::RENDER::RENDER_MAILFORM,
	'GALLERY'       => \&TOXML::RENDER::RENDER_PRODLIST,
	'GALLERYSELECT' => \&TOXML::RENDER::RENDER_GALLERYSELECT,
	'PRODGALLERY'   => \&TOXML::RENDER::RENDER_PRODLIST,
	'SITEMAP'		 => \&TOXML::RENDER::RENDER_SITEMAP,
	'REVIEWS'		 => \&TOXML::RENDER::RENDER_REVIEWS,
	'MENU'          => \&TOXML::RENDER::TURBOMENU,
	'CARTPRODCATS'  => \&TOXML::RENDER::TURBOMENU,
	'PRODCATS'      => \&TOXML::RENDER::TURBOMENU,
	'SUBCAT'        => \&TOXML::RENDER::TURBOMENU,
	'BREADCRUMB'    => \&TOXML::RENDER::TURBOMENU,
	'TURBOMENU'    => \&TOXML::RENDER::TURBOMENU,

	'SEARCH'        => \&TOXML::RENDER::RENDER_SEARCH,
	'SEARCHBOX'        => \&TOXML::RENDER::RENDER_SEARCHBOX,

	'MINICART'      => \&TOXML::RENDER::RENDER_MINICART,
	'QTYPRICE'      => \&TOXML::RENDER::RENDER_QTYPRICE,
	'TRISTATE'      => \&TOXML::RENDER::RENDER_TRISTATE,
	'SELECTED'      => \&TOXML::RENDER::RENDER_SELECTED,
	'TEXTLIST'      => \&TOXML::RENDER::RENDER_TEXTLIST,
	'HTML'			 => \&TOXML::RENDER::RENDER_TEXT,
	'SCRIPT'			 => \&TOXML::RENDER::RENDER_SCRIPT,
	'JAVASCRIPT'	 => \&TOXML::RENDER::RENDER_SCRIPT,
	'CONFIG'			 => \&TOXML::RENDER::RENDER_CONFIG,
	'BUTTON'			 => \&TOXML::RENDER::RENDER_BUTTON,
#	'EDITOR_ACTION' => \&TOXML::RENDER::RENDER_NULL,
	'FINDER'			 => \&TOXML::RENDER::RENDER_FINDER,
	'OUTPUT'			=> \&TOXML::RENDER::RENDER_OUTPUT,
	'BODY'			=> \&TOXML::RENDER::render_page,
	# 'INCLUDE'		=> \&TOXML::RENDER::render_page,
	# 'INCLUDE'		=> \&TOXML::RENDER::RENDER_INCLUDE,
	'HEAD'			=>	\&TOXML::RENDER::render_head,
	'LOGO'			=>	\&TOXML::RENDER::SITE_LOGO,
	'TITLE'			=>	\&TOXML::RENDER::render_title,
	'FOOTER'			=>	\&TOXML::RENDER::SITE_FOOTER,
	'SIDEBAR'	=>	\&TOXML::RENDER::SITE_SIDEBAR,
	'EXEC'		=> \&TOXML::RENDER::RENDER_EXEC,
	'SITEBUTTON'	=>\&TOXML::RENDER::RENDER_SITEBUTTON,

	'CHECKBOX'	=> \&TOXML::RENDER::RENDER_CHECKBOX,

	'IF'				 => \&TOXML::RENDER::RENDER_IF,
	'IMAGESELECT' => \&TOXML::RENDER::RENDER_TEXT,
	'SELECT'			 => \&TOXML::RENDER::RENDER_TEXT,
	'HIDDEN'			 => \&TOXML::RENDER::RENDER_HIDDEN,
	'SET'				=> \&TOXML::RENDER::RENDER_SET,
	'API'				=> \&TOXML::RENDER::RENDER_API,
	'FAQ'				=> \&TOXML::RENDER::RENDER_FAQ,
	'SPECL'			=> \&TOXML::RENDER::RENDER_SPECL,
	'PRODSEARCH' => \&TOXML::RENDER::RENDER_PRODLIST,
	);




%TOXML::RENDER::DECALS = (
#	'legacy'=> {
#		prompt=>'Sidebar HTML (Legacy)',
#		flexedit=>['zoovy:sidebar_html'],
#		html=>'%zoovy:sidebar_html%',
#		},
	'trustwave'=>{
		prompt=>'Trustwave SSL Seal',
		preview=>'n/a',
		html=>'%trustwave:sealhtml%',
		flexedit=>['trustwave:sealhtml'],		
		},
#	'upsellit'=>{
#		prompt=>'UpsellIT/Moxie ChatBot',
#		preview=>'n/a',
#		html=>'%upsellit:html%',
#		flexedit=>['upsellit:html'],		
#		},

	'rapidssl' => {
		prompt=>'RapidSSL (requires purchase of RapidSSL certificate)',
	  height=>50,
		width=>90,
		html=> "<img height='50' width='90' src=\"/media/graphics/general/rapidssl_ssl_certificate.gif\" alt='' />\n",
		},
	'googletrustedstores'=>{
		prompt=>'Google Trusted Stores',
		flexedit=>[ 'googlets:search_account_id','googlets:badge_code', ],
		html=>"%googlets:badge_code%",
		'exec'=>sub {
			my ($sref) = @_;
			return($sref->msgs()->show($sref->nsref()->{'googlets:badge_code'}));
			}
		},
	'providessupport'=>{
		prompt=>'ProvideSupport LiveChat',
		preview=>'n/a',
		html=>q~%pschat:html%~,
		flexedit=>['pschat:html'],		
		},
	'olark'=>{
		prompt=>'OLark Chat',
		preview=>'n/a',
		html=>q~%olark:html%~,
		flexedit=>['olark:html'],		
		},
#	'magicchat'=>{
#		prompt=>'ProvideSupport + UpSellIT Magic',
#		preview=>'n/a',
#		exec=>\sub {
#			return("<!-- no magic yet -->");
#			},
#		},
#	'providesupportupsellit'=>{
#		prompt=>'Provide Support + UpSellIt',
#		preview=>'',
#		exec=>sub 
#		},
	'mobile12043' => {
		prompt=>'Mobile Website Banner (120x43)',
		html=> "<a href='//m.%domain%' target='mobile'><img height='43' width='120' src=\"/media/graphics/general/mobile_website-120x43.png\" border='0' alt='Visit our Mobile Website at m.%domain%' /></a>\n",
		height=>43,
		width=>120,
		},
	'mobile120120' => {
		prompt=>'Mobile Website Banner (120x120)',
		html=> "<a href='//m.%domain%' target='mobile'><img height='120' width='120' src=\"/media/graphics/general/mobile_website-120x120.png\" border='0' alt='Visit our Mobile' /></a>\n",
		height=>43,
		width=>120,
		},
	'visa' => {
		prompt=>'Visa',
		html=> "<img height='38' width='59' src=\"/media/graphics/paymentlogos/VISA.gif\" alt='' />\n",
		height=>38,
		width=>59,
		},

	'visa3321' => {
		prompt=>'Visa (33x21)',
		html=> "<img height='21' width='33' src=\"/media/graphics/paymentlogos/cc_visa-33x21.gif\" alt='' />\n",
		height=>33,
		width=>21,
		},


	'mc' => {
		prompt=>'Mastercard',
		height=>38,
		width=>59,
		html=> "<img height='38' width='59' src=\"/media/graphics/paymentlogos/MC.gif\" alt='' />\n",
		},

	'mc3321' => {
		prompt=>'Mastercard (33x21)',
		html=> "<img height='21' width='33' src=\"/media/graphics/paymentlogos/cc_mc-33x21.gif\" alt='' />\n",
		height=>33,
		width=>21,
		},



	'amex' => {
		prompt=>'American Express',
		html=> "<img height='38' width='59' src=\"/media/graphics/paymentlogos/AMEX.gif\" alt='' />\n",
		height=>38,
		width=>59,
		},


	'amex3321' => {
		prompt=>'American Express (33x21)',
		html=> "<img height='21' width='33' src=\"/media/graphics/paymentlogos/cc_amex-33x21.gif\" alt='' />\n",
		height=>33,
		width=>21,
		},



	'disc' => {
		prompt=>'Discover',
		html=> "<img height='38' width='59' src=\"/media/graphics/paymentlogos/NOVUS.gif\" alt='' />\n",
		height=>38,
		width=>59,
		},

	'disc3321' => {
		prompt=>'Discover (33x21)',
		html=> "<img height='21' width='33' src=\"/media/graphics/paymentlogos/cc_discover-33x21.gif\" alt='' />\n",
		height=>33,
		width=>21,
		},


	'paypal3321' => {
		prompt=>'PayPal - static graphic (33x21)',
		html=> "<img height='21' width='33' src=\"/media/graphics/paymentlogos/paypal-33x21.gif\" alt='' />\n",
		height=>33,
		width=>21,
		},


	'paypal3723' => {
		height=>23,
		width=>37,
		prompt=>'PayPal EC (37x23)',
		html=>q~
<!-- PayPal Logo --><a href="#" onclick="javascript:window.open('https://www.paypal.com/us/cgi-bin/webscr?cmd=xpt/cps/popup/OLCWhatIsPayPal-outside','olcwhatispaypal','toolbar=no, location=no, directories=no, status=no, menubar=no, scrollbars=yes, resizable=yes, width=400, height=350')"><img  src="https://www.paypal.com/en_US/i/logo/PayPal_mark_37x23.gif" border="0" alt="Acceptance Mark" /></a><!-- PayPal Logo -->
~."\n"
		},
	'paypal5034' => {
		height=>50,
		width=>34,
		prompt=>'PayPal EC (50x34)',
		html=>q~
<!-- PayPal Logo --><a href="#" onclick="javascript:window.open('https://www.paypal.com/us/cgi-bin/webscr?cmd=xpt/cps/popup/OLCWhatIsPayPal-outside','olcwhatispaypal','toolbar=no, location=no, directories=no, status=no, menubar=no, scrollbars=yes, resizable=yes, width=400, height=350')"><img  src="https://www.paypal.com/en_US/i/logo/PayPal_mark_50x34.gif" border="0" alt="Acceptance Mark" /></a><!-- PayPal Logo -->
~."\n",
		},
	'paypal6038' => {
		height=>60,
		width=>38,
		prompt=>'PayPal EC (60x38)',
		html=>q~
<!-- PayPal Logo --><a href="#" onclick="javascript:window.open('https://www.paypal.com/us/cgi-bin/webscr?cmd=xpt/cps/popup/OLCWhatIsPayPal-outside','olcwhatispaypal','toolbar=no, location=no, directories=no, status=no, menubar=no, scrollbars=yes, resizable=yes, width=400, height=350')"><img  src="https://www.paypal.com/en_US/i/logo/PayPal_mark_60x38.gif" border="0" alt="Acceptance Mark" /></a><!-- PayPal Logo -->
~."\n",
		},
	'zoovy' => {
		height=>31,
		width=>88,
		prompt=>'Zoovy',
		html=> "<a href=\"http://www.zoovy.com/track.cgi?P=%USERNAME%\" target='_blank'><img border='0' height='31' width='88' src=\"/media/graphics/general/poweredby.gif\" alt='ecommerce by Zoovy' /></a>\n",
		},
	'ppbig' => {
		prompt=>'Paypal (Big Logo)',
		html=> "<img width='109' alt='paypal accepted' height='35' src=\"/media/graphics/general/paypal_logo.gif\" />\n",
		height=>35,
		width=>109,
		},
	'ups' => {
		prompt=>'UPS',
		html=> "<img border='0' height='50' width='45' alt='we ship ups' src=\"/media/graphics/general/ups.gif\" />\n",
		height=>50,
		width=>45,
		},
	'fedex' => {
		prompt=>'Federal Express',
		html=> "<img width='88' height='31' alt='we ship FedEx' src=\"/media/graphics/general/fedex.gif\" />\n",
		height=>31,
		width=>88,
		},
	'usps' => {
		prompt=>'US Postal Service',
		html=> "<img width='120' height='30' alt='we ship USPS' src=\"/media/graphics/general/usps.gif\" />\n",
		height=>120,
		width=>30,
		},
	'thawte' => {
		prompt=>'Thawte SSL Secure (Zoovy)',
		html=> '<!-- THAWTE NO LONGER SUPPORTED -->',
		},
#	'geotrust' => {
#		prompt=>'Geotrust SSL Logo Plain Non-Secure (ssl.zoovy.com)',
#		secure=>q~<!-- GeoTrust QuickSSL [tm] Smart Icon tag. Do not edit. --><SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript" SRC="//smarticon.geotrust.com/si.js"></SCRIPT>~,
#		html=>q~<a href="https://ssl.zoovy.com/%USERNAME%/cart.cgis"><img width='115' border='0' height='55' src="/media/graphics/general/ssl-geotrust.gif"></a><!-- end GeoTrust Smart Icon tag -->~,
#		hint=>q~This will only appear on secure pages, and is intended for sites which DO NOT have their own ssl certificate.~,
#		height=>55,
#		width=>115,
#		},
#	'geotrustso' => {
#		preview=>"<img src='/media/graphics/general/ssl-geotrust.gif' width='115' height='55' border='0' />",
#		prompt=>'Geotrust SSL Logo - SSL.ZOOVY.COM Secure Only',
#		secure=>q~<!-- GeoTrust QuickSSL [tm] Smart Icon tag. Do not edit. --><SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript" SRC="//smarticon.geotrust.com/si.js"></SCRIPT>~,
#		hint=>q~This will only appear on non-secure pages, and is intended for sites which DO NOT have their own ssl certificate.~,
#		html=>'',
#		height=>55,
#		width=>115,
#		},
	'geotrustxx' => {
		prompt=>'Geotrust SSL Logo Sitewide - requires SSL certificate',
		secure=>q~<!-- GeoTrust QuickSSL [tm] Smart Icon tag. Do not edit. --><SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript" SRC="//smarticon.geotrust.com/si.js"></SCRIPT>~,
		html=>q~<img width='115' border='0' height='55' src="/media/graphics/general/ssl-geotrust.gif"><!-- end GeoTrust Smart Icon tag -->~, ## as per darci, link removed (broken anyway) on 2012-06-14
		hint=>q~This will only appear on secure pages, and is intended for sites which DO NOT have their own ssl certificate.~,
		height=>55,
		width=>115,
		},
#	'geotbid'=> {
#		prompt=>'GeoTrust True Business ID (ssl provisioned before-10/22/2009) - requires ssl certificate',
#		html=> qq~<!-- webbot bot="HTMLMarkup" startspan -->
#<SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript" SRC="//smarticon.geotrust.com/si.js"></SCRIPT>
#<!-- webbot bot="HTMLMarkup" endspan -->
#~,
#		},
	'geotbid2'=>{
		# /httpd/static/graphics/general/geotrust-si-20091016-modified.js
		prompt=>'GeoTrust True Business ID v2 (ssl provisioned after-10/22/2009)',
		secure=> qq~<!-- webbot bot="HTMLMarkup" startspan -->
<SCRIPT TYPE="text/javascript" SRC="//smarticon.geotrust.com/si.js"></SCRIPT>
<!-- webbot bot="HTMLMarkup" endspan -->~,
		html=>qq~<!-- geotrust iframing breaks id -->~,
		},
	'geotbid3'=>{
		# /httpd/static/graphics/general/geotrust-si-20091016-modified.js
		prompt=>'GeoTrust True Business ID v3 (www.domain.com ssl provisioned after-3/1/2013)',
		html=> qq~<!-- webbot bot="HTMLMarkup" startspan -->
<SCRIPT TYPE="text/javascript" SRC="//smarticon.geotrust.com/si.js"></SCRIPT>
<!-- webbot bot="HTMLMarkup" endspan -->~,
		},
	'addthis' => {
		prompt=>'addThis',
		flexedit=>['addthis:pubid','addthis:html'],
		preview=>'<!-- no preview -->',
		html=>qq~
<script type='text/javascript'>
(function(){
	var fileref=document.createElement('script');
	fileref.setAttribute("type","text/javascript");
	fileref.setAttribute("src", "//s7.addthis.com/js/250/addthis_widget.js#pubid=%addthis:pubid%");
	document.getElementsByTagName("head")[0].appendChild(fileref);
	})();
</script>
%addthis:html%
		~
		},

	'bbbonlineh' => {
		prompt=>'BBB Online Seal (horizontal)',
		flexedit=>[ 'bbbonline:id' ],
		html=> "<a target=\"_blank\" href=\"http://www.bbbonline.org/cks.asp?id=%bbbonline:id%\"><img border=0 src=\"/media/graphics/general/bbb_hor-115x50.gif\" width='115' height='50' alt='' /></a>\n",
		height=>50,
		width=>115,
		},
	'bbbonlinev' => {
		prompt=>'BBB Online Seal (vertical)',
		flexedit=>[ 'bbbonline:id' ],
		html=> "<a target=\"_blank\" href=\"http://www.bbbonline.org/cks.asp?id=%bbbonline:id%\"><img border=0 src=\"/media/graphics/general/bbb_vertical-100x162.gif\" width='100' height='162 alt='' /></a>\n",
		height=>162,
		width=>100,
		},
	'bbbonlinevm' => {
		prompt=>'BBB Online Seal (vert small)',
		flexedit=>[ 'bbbonline:id' ],
		html=>"<a target=\"_blank\" href=\"http://www.bbbonline.org/cks.asp?id=%bbbonline:id%\"><img border=0 src=\"/media/graphics/general/bbb_vertical-45x89.gif\" width='45' height='89' alt='' /></a>\n",
		height=>89,
		width=>45,
		},

	'bbbonlinemeddated' => {
		prompt=>'BBB Online Seal (medium with rating and date)',
		flexedit=>[ 'bbbonline:url' ],
		html=>qq~<a id='bbblink' class='ruhzbus' href='%bbbonline:url%' title='Better Business Bureau Approved' style='display: block;position:relative;overflow: hidden; width: 100px; height: 45px; margin: 0px; padding:0px;'>
<img style='padding: 0px; border: none;' id='bbblinkimg' src='//seal-goldengate.bbb.org/logo/ruhzbus/kidsafe-80030.png' width='200' height='45' alt='' />
</a>
<script type='text/javascript'>
var bbbprotocol = ( ('https:' == document.location.protocol) ? 'https://' : 'http://' );
document.write(unescape("%3Cscript src='" + bbbprotocol + 'seal-goldengate.bbb.org' + unescape('%2Flogo%2Fkidsafe-80030.js') + "'type='text/javascript'%3E%3C/script%3E"));
</script>~,
		height=>45,
		width=>100,
		},



	'bidpay' => {
		prompt=>'Western Union Bidpay',
		html=> "<img width='88' height='31' src=\"/media/graphics/general/wubidpay.gif\" alt='' />\n",
		height=>31,
		width=>88,
		},
	'epubliceye' => {
		prompt=>'ePublicEye Seal',
		flexedit=>[ 'epubliceye:id' ],
		html=> "<a target=\"_blank\" href=\"http://pe.epubliceye.com/fl/report.cfm?key=%epubliceye:id%&lang=english\"><img border=0 src=\"/media/graphics/general/epubliceye.gif\"></a>\n",
		},
	'ebaylogo' => {
		prompt=>'eBay Logo',
		flexedit=>[ 'ebay:username' ],
		html=> "<a target=\"_blank\" href=\"http://cgi6.ebay.com/ws/eBayISAPI.dll?ViewSellersOtherItems&userid=%ebay:username%\"><img border=0 src=\"/media/graphics/general/ebaylogo.gif\" alt='' /></a>\n",
		},
	'ebaypowerseller' => {
		prompt=>'eBay Powerseller Logo (Large)',
		flexedit=>[ 'ebay:username' ],
		html=> "<a target=\"_blank\" href=\"http://cgi6.ebay.com/ws/eBayISAPI.dll?ViewSellersOtherItems&userid=%ebay:username%\"><img height='93' width='110' border=0 src=\"/media/graphics/general/ebaypowerseller.gif\" alt='' /></a>\n",
		height=>93,
		width=>100,
		},
	'ebaypowersellerm' => {
		prompt=>'eBay Powerseller Logo (Med)',
		flexedit=>[ 'ebay:username' ],
		html=> "<a target=\"_blank\" href=\"http://cgi6.ebay.com/ws/eBayISAPI.dll?ViewSellersOtherItems&userid=%ebay:username%\"><img height=63 width=75 border=0 src=\"/media/graphics/general/ebaypowerseller_medium.gif\" alt='' /></a>\n",
		height=>63,
		width=>75,
		},
	'ebaypowersellers' => {
		prompt=>'eBay Powerseller Logo (Small)',
		html=> "<a target=\"_blank\" href=\"http://cgi6.ebay.com/ws/eBayISAPI.dll?ViewSellersOtherItems&userid=%ebay:username%\"><img  border=0 width=55 height=47  src=\"/media/graphics/general/ebaypowerseller_small.gif\"></a>\n",
		height=>47,
		width=>55,
		},
	'ebaystores' => {
		prompt=>'eBay Stores Logo',
		flexedit=>[ 'ebay:username' ],
		html=> "<a target=\"_blank\" href=\"http://www.stores.ebay.com/%ebay:username%\"><img border=0 width=125 height=39 src=\"/media/graphics/general/ebaystores.gif\" alt='' /></a>\n",
		height=>39,
		width=>125,
		},
	'shopebay' => {
		prompt=>'Shop @ eBay Logo',
		flexedit=>[ 'ebay:username' ],
		html=> "<a target=\"_blank\" href=\"http://cgi6.ebay.com/ws/eBayISAPI.dll?ViewSellersOtherItems&userid=%ebay:username%\"><img border=0 src=\"/media/graphics/general/shopebay.gif\" alt='' /></a>\n",
		},
	'paypal' => {
		prompt=>'Paypal (small logo)',
		html=> "<img width='88' height='33' src=\"/media/graphics/general/paypal-small.gif\" alt='' />\n",
		height=>33,
		width=>88,
		},
	'internetsafeseal' => {
		prompt=>'Safe Shopping Seal',
		html=> "<img width='80' height='81' src=\"/media/graphics/general/internetsafeseal.jpg\" alt='' />\n",
		height=>81,
		width=>80,
		},
	'sslsecure' => {
		prompt=>'Secure Shopping',
		html=> "<img width='87' height='38' src=\"/media/graphics/general/generic-ssl-secure.gif\" alt='' />\n",
		height=>38,
		width=>87,
		},
	'usflag' => {
		prompt=>'US Flag',
		html=> "<img width='68' height='50' src=\"/media/graphics/general/usflag.gif\" alt='' />\n",
		height=>50,
		width=>680,
		},
	'buysafe' => {
		preview=>"<img src='/media/graphics/general/placeholders/buysafe-85x55.gif' width='85' height='55' alt='' />",
		prompt=>'Buysafe Seal HTML',
		flexedit=>['zoovy:buysafe_sealhtml'],
		html=> "%zoovy:buysafe_sealhtml%",
		},
	'pricegrabber' => {
		prompt=>'PriceGrabber User Ratings',
		flexedit=>[ 'pricegrabber:id' ],
		secure=>'<!-- pricegrabber does not offer secure version of their graphic -->',
		html=>q~<a target="_blank" href="http://www.pricegrabber.com/rating_getreview.php/retid=%pricegrabber:id%">
<img border=0 src="http://ah.pricegrabber.com/merchant_rating_image.php?retid=%pricegrabber:id%" alt="PriceGrabber User Ratings"></a>~,
		},
	'hackersafe' => {
	preview=>"<img src='/media/graphics/general/placeholders/mcafee-115x30.gif' width='115' height='30' alt='' />",
		prompt=>'HackerSafe',
		height=>30,
		width=>115,
		html=> qq~<!-- START SCANALERT CODE -->
<a target="_blank" href="https://www.mcafeesecure.com/RatingVerify?ref=www.%domain%">
<img width="115" height="30" border="0" src="//images.scanalert.com/meter/www.%domain%/32.gif" 
alt="HACKER SAFE certified sites prevent over 99.9% of hacker crime." 
oncontextmenu="alert('Copying Prohibited by Law - HACKER SAFE is a Trademark of ScanAlert'); return false;"></a>
<!-- END SCANALERT CODE -->
~,
		},
	'hackersafemini' => {
	preview=>"<img src='/media/graphics/general/placeholders/mcafee-94x54.gif' width='94' height='54' alt='' />",
		prompt=>'HackerSafe (Mini Logo)',
		height=>54,
		width=>94,
		html=> qq~
<!-- START SCANALERT CODE -->
<a target="_blank" href="https://www.mcafeesecure.com/RatingVerify?ref=www.%domain%">
<img width="94" height="54" border="0" src="//images.scanalert.com/meter/www.%domain%/13.gif" 
alt="HACKER SAFE certified sites prevent over 99.9% of hacker crime." 
oncontextmenu="alert('Copying Prohibited by Law - HACKER SAFE is a Trademark of ScanAlert'); return false;"></a>
<!-- END SCANALERT CODE -->
~,
		},
	'authnet' => {
		preview=>"<img src='/media/graphics/general/placeholders/authorizenet-90x72.gif' width='90' height='72' alt='' />",
		prompt=>'Authorize.Net',
		flexedit=>[ 'authnet:html' ],
		html=> qq~%authnet:html%~,
		},

	'googleaccepted'=> {
		prompt=>'Google Checkout Accepted 72x72',		
		height=>73,
		width=>72,
		html=>qq~<link rel="stylesheet" href="https://checkout.google.com/seller/accept/s.css" type="text/css" media="screen" />
<script type="text/javascript" src="https://checkout.google.com/seller/accept/j.js"></script>
<script type="text/javascript">showMark(3);</script>
<noscript><img src="https://checkout.google.com/seller/accept/images/sc.gif" width="72" height="73" alt="Google Checkout Acceptance Mark" /></noscript>\n~,
		},
	'googlevmad_vert'=> {
		prompt=>'Google Checkout Visa/MC/Disc/Amex 92x98',
		height=>98,
		width=>92,
		html=> qq~
<link rel="stylesheet" href="https://checkout.google.com/seller/accept/s.css" type="text/css" media="screen" />
<script type="text/javascript" src="https://checkout.google.com/seller/accept/j.js"></script>
<script type="text/javascript">showMark(1);</script>
<noscript><img src="https://checkout.google.com/seller/accept/images/st.gif" width="92" height="88" alt="Google Checkout Acceptance Mark" /></noscript>
\n~,
		},
	'googlevmad_horz'=> {
		prompt=>'Google Checkout Visa/MC/Disc/Amex Horizontal 180x46',
		height=>46,
		width=>180,
		html=> qq~
<link rel="stylesheet" href="https://checkout.google.com/seller/accept/s.css" type="text/css" media="screen" />
<script type="text/javascript" src="https://checkout.google.com/seller/accept/j.js"></script>
<script type="text/javascript">showMark(2);</script>
<noscript><img src="https://checkout.google.com/seller/accept/images/ht.gif" width="180" height="46" alt="Google Checkout Acceptance Mark" /></noscript>
\n~,
		},


	'googleaccepted3321' => {
		prompt=>'Google Payment Accepted - static graphic (33x21)',
		html=> "<img height='21' border='0' width='33' src=\"/media/graphics/paymentlogos/google_checkout-33x21.gif\" alt='' />\n",
		height=>33,
		width=>21,
		},


	'googleplusone_small' =>  {
		prompt=>'Google PlusOne (small and page specific)',
		html=>"<script type='text/javascript' src='//apis.google.com/js/plusone.js'></script><g:plusone size='small' count='false' href='%canonical_url%'></g:plusone>",
		height=>15,
		width=>24
		},


	'googleplusone_medium_count' =>	{
		prompt=>'Google PlusOne (medium w/ count and page specific)',
		html=>"<script type='text/javascript' src='//apis.google.com/js/plusone.js'></script><g:plusone size='medium' count='true' href='%canonical_url%'></g:plusone>",
		height=>20,
		width=>90
		},


	'googleplusone_tall' =>  {
		prompt=>'Google PlusOne (tall w/ count and page specific)',
		html=>"<script type='text/javascript' src='//apis.google.com/js/plusone.js'></script><g:plusone size='tall' count='true' href='%canonical_url%'></g:plusone>",
		height=>60,
		width=>50
		},


	'googleplusone_tall_sdomain' =>  {
		prompt=>'Google PlusOne (tall w/ count and domain specific)',
	  html=>"<script type='text/javascript' src='//apis.google.com/js/plusone.js'></script><g:plusone size='tall' count='true' href='http://%sdomain%'></g:plusone>",
		height=>60,
		width=>50
		},





	'facebook_flw_big'=> {
		prompt=>'Facebook (Big 181x54)',
		flexedit=>['facebook:url'],
		height=>54,
		width=>181,
		html=>qq~<!-- facebook --><a target="facebook" href="%facebook:url%"><img border='0' width='181' height='54' src="/media/graphics/paymentlogos/facebook_flw_181x54.png" alt='' /></a>\n~, 
		},
	'facebook_flw_med'=> {
		prompt=>'Facebook (Med 124x42)',
		flexedit=>['facebook:url'],
		height=>42,
		width=>124,
		html=> qq~<!-- facebook --><a target="facebook" href="%facebook:url%"><img border='0' width='125' height='42' src="/media/graphics/paymentlogos/facebook_flw_125x42.png" alt='' /></a>\n~, 
		},
	'facebook_flw_small'=> {
		prompt=>'Facebook (Small 100x42)',
		height=>42,
		width=>100,
		flexedit=>['facebook:url'],
		html=> qq~<!-- facebook --><a target="facebook" href="%facebook:url%"><img border='0' width='100' height='42' src="/media/graphics/paymentlogos/facebook_flw_100x42.png" alt='' /></a>\n~, 
		},



	'facebook_like_vertical_fbml'=> {
		prompt=>'Facebook Like button count (75 x 62 for page specific url)',
		height=>62,
		width=>75,
		secure=>"<!-- facebook like vertical is not supported on secure pages -->",
		hint=>"This decal will NOT appear on secure pages. facebook does not support ssl at this time.",
		html=> qq~

<!-- facebook like button_count  (canonical) -->
<script type='text/javascript'>
//check if the fb-root div already exists. if not, add it.
//assume if the fb-root already exists, the script is already added too.
if(!document.getElementById('fb-root')){
	var fbRootDiv = document.createElement('div');
	fbRootDiv.setAttribute('id', 'fb-root');
	document.body.appendChild(fbRootDiv);
	var fileref=document.createElement('script');
	fileref.setAttribute("type","text/javascript");
	fileref.setAttribute("src", "http://connect.facebook.net/en_US/all.js#xfbml=1");
	document.getElementsByTagName("head")[0].appendChild(fileref)
	}
</script>
<fb:like href='%canonical_url%' send='false' layout='box_count' show_faces='false' font=''></fb:like>
<!-- /facebook like button_count -->
~,
		},



	'facebook_like_buttoncount_fbml'=> {
		prompt=>'Facebook Like button count (75 x 25 for page specific url)',
		height=>20,
		width=>75,
		secure=>"<!-- facebook like buttoncount is not supported on secure pages -->",
		hint=>"This decal will NOT appear on secure pages. facebook does not support ssl at this time.",
		html=> qq~

<!-- facebook like button_count  (canonical) -->
<script type='text/javascript'>
//check if the fb-root div already exists. if not, add it.
//assume if the fb-root already exists, the script is already added too.
if(!document.getElementById('fb-root')){
	var fbRootDiv = document.createElement('div');
	fbRootDiv.setAttribute('id', 'fb-root');
	document.body.appendChild(fbRootDiv);
	var fileref=document.createElement('script');
	fileref.setAttribute("type","text/javascript");
	fileref.setAttribute("src", "http://connect.facebook.net/en_US/all.js#xfbml=1");
	document.getElementsByTagName("head")[0].appendChild(fileref)
	}
</script>
<fb:like href='%canonical_url%' send='false' layout='button_count' width='75' show_faces='false' font=''></fb:like>
<!-- /facebook like button_count -->
~,
		},


	 'facebook_like_iframe_narrow'=> {
		 prompt=>'Facebook Like button (190 x 70 for facebook url)',
		 height=>70,
		 width=>190,
		 secure=>"<!-- facebook like iframe is not supported on secure pages -->",
		 flexedit=>['facebook:url'],
		 hint=>"This decal will NOT appear on secure pages. facebook does not support ssl at this time.",
		 html=> qq~
<!-- facebook like (narrow) iframe -->
<iframe id='facebookLikeButtonNarrow' src="http://www.facebook.com/plugins/like.php?href=%facebook:url%&amp;layout=standard&amp;show_faces=true&amp;action=like&amp;font&amp;colorscheme=light&amp;height=80" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:190px; height:70px;" allowTransparency="true"></iframe>
<!-- /facebook like iframe -->
  ~,
		  },


	'facebook_like_iframe_wide'=> {
		prompt=>'Facebook Like button (350 x 70 for facebook url)',
		height=>70,
		width=>350,
		secure=>"<!-- facebook like iframe is not supported on secure pages -->",
		flexedit=>['facebook:url'],
		hint=>"This decal will NOT appear on secure pages. facebook does not support ssl at this time.",
		html=> qq~
<!-- facebook like (wide) iframe -->
<iframe id='facebookLikeButtonWide' src="http://www.facebook.com/plugins/like.php?href=%facebook:url%&amp;layout=standard&amp;show_faces=true&amp;action=like&amp;font&amp;colorscheme=light&amp;height=80" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:350px; height:70px;" allowTransparency="true"></iframe>
<!-- /facebook like iframe -->
~,
		},




	'facebook_like_iframe_wide_canonical'=> {
		prompt=>'Facebook Like button (350 x 70 for page specific url)',
		height=>70,
		width=>350,
		secure=>"<!-- facebook like iframe is not supported on secure pages -->",
		hint=>"This decal will NOT appear on secure pages. facebook does not support ssl at this time.",
		html=> qq~
<!-- facebook like (wide) iframe -->
<iframe id='facebookLikeButtonWideCanonical' src="http://www.facebook.com/plugins/like.php?href=%canonical_url%&amp;layout=standard&amp;show_faces=true&amp;action=like&amp;font&amp;colorscheme=light&amp;height=80" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:350px; height:70px;" allowTransparency="true"></iframe>
<!-- /facebook like iframe -->
~,
		},



	'facebook_facepile_iframe_narrow'=> {
		prompt=>'Facebook Facepile (190 x X)',
		width=>190,
		secure=>"<!-- facepile iframe is not supported on secure pages -->",
		flexedit=>['facebook:url'],
		hint=>"This decal will NOT appear on secure pages. facebook does not support ssl at this time.",
		html=> qq~
<!-- facebook facepile iframe -->
<iframe id='facebookFacePile' src="http://www.facebook.com/plugins/facepile.php?href=%facebook:url%&amp;width=190&amp;max_rows=1" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:190px;" allowTransparency="true"></iframe>
<!-- /facepile -->
~,
		},




	'facebook_likebox_iframe_narrow'=> {
		prompt=>'Facebook LikeBox (190 x X )',
		width=>190,
		secure=>"<!-- facebook LikeBox iframe is not supported on secure pages -->",
		flexedit=>['facebook:url'],
		hint=>"This decal will NOT appear on secure pages. facebook does not support ssl at this time. This decal is best added to the left or right column",
		html=> qq~
<!-- facebook likebox iframe -->
<iframe src='http://www.facebook.com/plugins/likebox.php?href=%facebook:url%&amp;width=190&amp;colorscheme=light&amp;show_faces=true&amp;stream=true&amp;header=false&amp;height=395' scrolling='no' frameborder='0' style='border:none; overflow:hidden; width:190px; height:395px;' allowTransparency='true' id='facebookLikeBox'></iframe>
<!-- /likebox -->
~,
		},



	'facebook_send_fbml'=> {
		prompt=>'Facebook Send button (56x25 )',
		width=>56,
		height=>25,
		secure=>"<!-- facebook send is not supported on secure pages -->",
		hint=>"This decal will NOT appear on secure pages. facebook does not support ssl at this time.",
		html=> qq~
<!-- facebook send button (js) -->

<div id='fb-root'></div>
<script src='http://connect.facebook.net/en_US/all.js#xfbml=1'></script>
<fb:send href='%canonical_url%' font=''></fb:send>
<!-- /send button -->
~,
		},




	'facebook_comments_fbml_canonical'=> {
		prompt=>'Facebook Comments for page specific url (400 by X)',
		width=>400,
		height=>80,
		secure=>"<!-- facebook comments are not supported on secure pages -->",
		hint=>"This decal will NOT appear on secure pages. facebook does not support ssl at this time.",
		html=> qq~
<!-- facebook comments  (canonical) -->
<script type='text/javascript'>
//check if the fb-root div already exists. if not, add it.
//assume if the fb-root already exists, the script is already added too.
if(!document.getElementById('fb-root')){
	var fbRootDiv = document.createElement('div');
	fbRootDiv.setAttribute('id', 'fb-root');
	document.body.appendChild(fbRootDiv);
	var fileref=document.createElement('script');
	fileref.setAttribute("type","text/javascript");
	fileref.setAttribute("src", "http://connect.facebook.net/en_US/all.js#xfbml=1");
	document.getElementsByTagName("head")[0].appendChild(fileref)
	}
</script>
<fb:comments href='%canonical_url%' num_posts='4'></fb:comments>
<!-- /facebook comments -->
~,
		},



	'facebook_comments_fbml_website'=> {
		prompt=>'Facebook Comments for website (400 by X)',
		width=>400,
		height=>80,
		secure=>"<!-- facebook comments are not supported on secure pages -->",
		hint=>"This decal will NOT appear on secure pages. facebook does not support ssl at this time.",
		html=> qq~
<!-- facebook comments  (canonical) -->
<script type='text/javascript'>
//check if the fb-root div already exists. if not, add it.
//assume if the fb-root already exists, the script is already added too.
if(!document.getElementById('fb-root')){
	var fbRootDiv = document.createElement('div');
	fbRootDiv.setAttribute('id', 'fb-root');
	document.body.appendChild(fbRootDiv);
	var fileref=document.createElement('script');
	fileref.setAttribute("type","text/javascript");
	fileref.setAttribute("src", "http://connect.facebook.net/en_US/all.js#xfbml=1");
	document.getElementsByTagName("head")[0].appendChild(fileref)
	}
</script>
<fb:comments href='http://%sdomain%' num_posts='4'></fb:comments>
<!-- /facebook comments -->
~,
		},




	'linkedin_share_vertical'=> {
		prompt=>'LinkedIn Share (vertical 61x62)',
		height=>62,
		width=>61,
		secure=>"<!-- linkedIn share not sll friendly -->",
		html=>qq~
<!-- linkedIn Share - vertical w/ count -->
<script src='http://platform.linkedin.com/in.js' type='text/javascript'></script>
<script type='IN/Share' data-url='%canonical_url%' data-counter='top'></script>
<!-- /linkedIn -->
	~,},




	'linkedin_share_horizontal_withcount'=> {
		prompt=>'LinkedIn Share (horizontal 61+ by 20)',
		height=>20,
		width=>61,
		secure=>"<!-- linkedIn share not sll friendly -->",
		html=>qq~
<!-- linkedIn Share - horizontal w/ count -->
<script src='http://platform.linkedin.com/in.js' type='text/javascript'></script>
<script type='IN/Share' data-url='%canonical_url%' data-counter='right'></script>
<!-- /linkedIn -->
	~,},






	'linkedin_share_horizontal'=> {
		prompt=>'LinkedIn Share (horizontal no count 61x20)',
		height=>20,
		width=>61,
		secure=>"<!-- linkedIn share not sll friendly -->",
		html=>qq~
<!-- linkedIn Share - horizontal w/o count -->
<script src='http://platform.linkedin.com/in.js' type='text/javascript'></script>
<script type='IN/Share' data-url='%canonical_url%'></script>
<!-- /linkedIn -->
	~,},



	'pinterest_follow_15226'=> {
		prompt=>'Pinterest (156x26)',
		flexedit=>['pinterest:userid'],
		height=>26,
		width=>156,
		html=>qq~<!-- pinterest-156x26 --><a title='follow us on Pinterest' target="Pinterest" href="http://pinterest.com/%pinterest:userid%/"><img border='0' width='156' height='26' src="/media/graphics/general/pinterest_follow-156x26.png" alt='follow us on pinterest' /></a>~
		},



	'youtube_12545'=> {
		prompt=>'YouTube (Med 125x45)',
		flexedit=>['youtube:url'],
		height=>45,
		width=>125,
		html=>qq~<!-- youtube --><a target="YouTube" href="%youtube:url%"><img border='0' width='125' height='45' src="/media/graphics/general/youtube-125x45.png" alt='' /></a>\n~, 
		},


	'blog_12545'=> {
		prompt=>'Blog (Med 125x45)',
		flexedit=>['blog:url'],
		height=>45,
		width=>125,
		html=>qq~<!-- blog --><a target="Blog" href="%blog:url%"><img border='0' width='125' height='45' src="/media/graphics/general/blog-125x45.png" alt='' /></a>\n~, 
		},


	'rss_12545'=> {
		prompt=>'RSS (Med 125x45)',
		flexedit=>['rss:url'],
		height=>45,
		width=>125,
		html=>qq~<!-- rss --><a target="RSS" href="%rss:url%"><img border='0' width='125' height='45' src="/media/graphics/general/rss-125x45.png" alt='' /></a>\n~, 
		},


## Twitter icons

	'twitter_flw_big'=> {
		prompt=>'Twitter (Big 181x74)',
		flexedit=>['twitter:userid'],
		height=>74,
		width=>181,
		html=>qq~<!-- twitter --><a target="twitter" href="http://www.twitter.com/%twitter:userid%"><img border='0' width='181' height='74' src="/media/graphics/paymentlogos/twitter_flw_181x74.png" alt='' /></a>\n~, 
		},
	'twitter_flw_med'=> {
		prompt=>'Twitter (Med 124x51)',
		flexedit=>['twitter:userid'],
		height=>51,
		width=>125,
		html=> qq~<!-- twitter --><a target="twitter" href="http://www.twitter.com/%twitter:userid%"><img border='0' width='125' height='51' src="/media/graphics/paymentlogos/twitter_flw_125x51.png" alt='' /></a>\n~, 
		},
	'twitter_flw_small'=> {
		prompt=>'Twitter (Small 100x41)',
		height=>41,
		width=>100,
		flexedit=>['twitter:userid'],
		html=> qq~<!-- twitter --><a target="twitter" href="http://www.twitter.com/%twitter:userid%"><img border='0' width='100' height='41' src="/media/graphics/paymentlogos/twitter_flw_100x41.png" alt='' /></a>\n~, 
		},


## at time of launch, twitter code was not ssl friendly.

	'twitter_tweetbtn_small' => {
		prompt=>'Twitter Tweet Button (55x20 for page specific url)',
		preview=>"<img src='/media/graphics/general/placeholders/twitter_tweet-55x20.png' width='55' height='20' alt='' />",
		height=>20,
		width=>55,
		html=>"<!-- tweetbtn small -->\n<a href='http://twitter.com/share' class='twitter-share-button' data-url='%canonical_url%' data-count='none'>Tweet</a>\n<script type='text/javascript' src='//platform.twitter.com/widgets.js'></script>\n<!-- /tweetbtn small -->"
		},





	'twitter_tweetbtn_horizontal' => {
		prompt=>'Twitter Tweet Button w/ count (107x10 for page specific url)',
		preview=>"<img src='/media/graphics/general/placeholders/twitter_tweet-107x20.png' width='107' height='20' alt='' />",
		height=>20,
		width=>107,
		html=>"<!-- tweetbtn small w/ count --><a href='http://twitter.com/share' class='twitter-share-button' data-url='%canonical_url%' data-count='horizontal'>Tweet</a><script type='text/javascript' src='//platform.twitter.com/widgets.js'></script><!-- /tweetbtn small w/ count -->"
		},


	'twitter_tweetbtn_vertical' => {
		prompt=>'Twitter Tweet Button w/ count (62x56 for page specific url)',
		preview=>"<img src='/media/graphics/general/placeholders/twitter_tweet-62x56.png' width='62' height='56' alt='' />",
		preview=>"",
		height=>56,
		width=>62,
		html=>"<!-- tweetbtn vertical --><a href='http://twitter.com/share' class='twitter-share-button' data-url='%canonical_url%' data-count='vertical'>Tweet</a><script type='text/javascript' src='//platform.twitter.com/widgets.js'></script><!-- /tweetbtn vertical -->"
		},



## skype: in front of skype:userid is necessary per skype's naming conventions
	'skypeme_12452'=> {
		prompt=>'Skype Me',
		height=>52,
		width=>124,
		flexedit=>['skype:userid'],
		html=> qq~<!-- skype --><script type="text/javascript" src="http://download.skype.com/share/skypebuttons/js/skypeCheck.js"></script><a href="skype:%skype:userid%"><img src="http://download.skype.com/share/skypebuttons/buttons/call_blue_white_124x52.png" style="border: medium none ;" alt="Skype Me.!" height="52" width="124"></a> ~, 
		secure=>'', # don't display http:// graphics on secure.
		},



	## Checkout By Amazon (CbA)
	'cba_p1'=> {
		prompt=>'Amazon Payments Orange Graphic 37x23',
		height=>23,
		width=>37,
		html=>qq~<img width='37' border='0' height='23' src="http://g-ecx.images-amazon.com/images/G/01/cba/b/p1.gif" alt='' />\n~,
		secure=>'', # don't display http:// graphics on secure.
		},
	'cba_p2'=> {
		prompt=>'Amazon Payments Orange Graphic 50x32',
		height=>32,
		width=>50,
		html=>qq~<img width='50' height='32' border='0' alt='' src="http://g-ecx.images-amazon.com/images/G/01/cba/b/p2.gif" />\n~,
		secure=>'', # don't display http:// graphics on secure.
		},
	'cba_p3'=> {
		prompt=>'Amazon Payments Orange Graphic 60x38',
		height=>38,
		width=>60,
		html=>qq~<img width='60' height='38' border='0' src="http://g-ecx.images-amazon.com/images/G/01/cba/b/p3.gif" alt='' />\n~,
		secure=>'', # don't display http:// graphics on secure.
		},
	'cba_p4'=> {
		prompt=>'Amazon Payments Orange Graphic 180x114',
		height=>114,
		width=>180,
		html=>qq~<img width='180' height='114' border='0' src="http://g-ecx.images-amazon.com/images/G/01/cba/b/p4.gif" alt='' />\n~,
		secure=>'', # don't display http:// graphics on secure.
		},
	'cba_s1'=> {
		prompt=>'Amazon Payments Combined Graphic 230x65',
		height=>65,
		width=>230,
		html=>qq~<img width='230' height='65' src="http://g-ecx.images-amazon.com/images/G/01/cba/b/s1.gif" alt='' />\n~,
		secure=>'', # don't display http:// graphics on secure.
		},
	'cba_s2'=> {
		prompt=>'Amazon Payments Combined Graphic 159x85',
		height=>85,
		width=>159,
		html=>qq~<img width='159' height='85' src="http://g-ecx.images-amazon.com/images/G/01/cba/b/s2.gif" alt='' />\n~,
		secure=>'', # don't display http:// graphics on secure.
		},
	'cba_i1'=> {
		prompt=>'Amazon Payments Introductory Graphic 120x90',
		height=>90,
		width=>120,
		html=>qq~<img width='120' height='90' src="http://g-ecx.images-amazon.com/images/G/01/cba/b/i1.jpg" alt='' />\n~,
		secure=>'', # don't display http:// graphics on secure.
		},
	'cba_i2'=> {
		prompt=>'Amazon Payments Introductory Graphic 150x40',
		height=>40,
		width=>150,
		html=>qq~<img width='150' height='40' src="http://g-ecx.images-amazon.com/images/G/01/cba/b/i2.jpg" alt='' />\n~,
		secure=>'', # don't display http:// graphics on secure.
		},
	'cba_i3'=> {
		prompt=>'Amazon Payments Introductory Graphic 150x60',
		height=>60,
		width=>150,
		html=>qq~<img width='150' height='60' src="http://g-ecx.images-amazon.com/images/G/01/cba/b/i3.jpg" alt='' />\n~,
		secure=>'', # don't display http:// graphics on secure.
		},
	'cba_sg1'=> {
		prompt=>'Amazon Payments -Pay Easily- Graphic 120x90',
		height=>90,
		width=>120,
		html=>qq~<img width='120' height='90' src="http://g-ecx.images-amazon.com/images/G/01/cba/b/sg1.jpg" alt='' />\n~,
		secure=>'', # don't display http:// graphics on secure.
		},
	'cba_sg2'=> {
		prompt=>'Amazon Payments -Pay Easily- Graphic 150x40',
		height=>40,
		width=>150,
		html=>qq~<img width='150' height='40' src="http://g-ecx.images-amazon.com/images/G/01/cba/b/sg2.jpg" alt='' />\n~,
		secure=>'', # don't display http:// graphics on secure.
		},
	'cba_sg3'=> {
		prompt=>'Amazon Payments -Pay Easily- Graphic 150x60',
		height=>60,
		width=>150,
		html=>qq~<img width='150' height='60' src="http://g-ecx.images-amazon.com/images/G/01/cba/b/sg3.jpg" alt='' />\n~,
		secure=>'', # don't display http:// graphics on secure.
		},
	''=> {
		prompt=>'Empty',
		html=>qq~<img width='3' height='3' src="/media/graphics/blank.gif"><br />\n~,
		},
	'user1'=>{
		prompt=>'User HTML 1',
		flexedit=>['user:decal1'],
		html=>'%user:decal1%',
		preview=>'--custom--',
		},
	'user2'=>{
		prompt=>'User HTML 2',
		flexedit=>['user:decal2'],
		html=>'%user:decal2%',
		preview=>'--custom--',
		},
	'user3'=>{
		prompt=>'User HTML 3',
		flexedit=>['user:decal3'],
		html=>'%user:decal3%',
		preview=>'--custom--',
		},
	'user4'=>{
		prompt=>'User HTML 4',
		flexedit=>['user:decal4'],
		html=>'%user:decal4%',
		preview=>'--custom--',
		},
	'user5'=>{
		prompt=>'User HTML 5',
		flexedit=>['user:decal5'],
		html=>'%user:decal5%',
		preview=>'--custom--',
		},

## Commented out on 7/6 by JT. This does not work and is what caused checkout to break in FF for ledinsider.

	'banner1'=>{
		prompt=>'User Banner 1',
		flexedit=>['user:banner1_img','user:banner1_link'],
##		html=>'<!-- <a href="%user:banner1_link%"><img src="%user:banner1_img%"></a> -->',
		html=>'<!-- this decal is broked. this output is a temp solution  -->',
		preview=>'--custom--',
		},
	);




## 
## renders a decal (based on decalid) for a site, 
##	assumes SITE::SREF is initialized with standard fields.
sub apply_decal {
	my ($SITE,$decalid) = @_;

	my $out = '';
	my $decalref = $TOXML::RENDER::DECALS{$decalid};
	if (not defined $decalref) {
		$out = "<!-- unknown decalid: $decalid -->";		
		}
	else {
		## this code BELOW should be kept in sync with SIDEBAR
		if (defined $decalref->{'exec'}) {
			## if we have an exec, it's a pointer a coderef.
			$decalref->{'html'} = $decalref->{'exec'}->($SITE);
			}
		$out = $decalref->{'html'};
		## if ((defined $decalref->{'secure'}) && ($SITE::SREF->{'+secure'})) {
		if ((defined $decalref->{'secure'}) && ($SITE->_is_secure()) ) {
			## secure is html that will display on a secure page.
			$out = $decalref->{'secure'};
			}

		if (defined $decalref->{'flexedit'}) {
			my $NSREF = $SITE->nsref();
			foreach my $k (@{$decalref->{'flexedit'}}) {
				$out =~ s/%$k%/$NSREF->{$k}/gs;
				}
			}
		## don't compile these regex's because they contain variable data
		$out =~ s/%canonical_url%/$SITE->canonical_url()/egs;
		$out =~ s/%sdomain%/$SITE->sdomain()/egs;
		$out =~ s/%ssl_domain%/$SITE->secure_domain()/egs;
		$out =~ s/%domain%/$SITE->domain_only()/egs;
		$out =~ s/%USERNAME%/$SITE->username()/egs;
		}

	return($out);
	}






#sub who_uses_this {
#	my ($ID,$iniref) = @_;
#	
#	my ($package,$file,$line,$sub,$args) = caller(1);
#
#	open MH, "|/usr/sbin/sendmail -t";
#	print MH "To: jt\@zoovy.com\n";
#	print MH "Cc: brian\@zoovy.com\n";
#	print MH "From: support\@zoovy.com\n";
#	print MH "Subject: who_uses_this: $SITE::merchant_id [ID: $ID][PROC: $$]\n\n";
#	require Data::Dumper;
#	print MH "PACKAGE: $package\nFILE: $file\nLINE: $line\nSUB: $sub\nARGS: $args\n\n";
#	print MH Data::Dumper::Dumper($iniref,$SITE::SREF,\%ENV);
#	close MH;
#	return();
#	}


##
## params:
##
#sub RENDER_INCLUDE {
#	my ($iniref,$wrapper,$SITE) = @_;
#	
#	## $TYPE is another element type
#	$TOXML::RENDER::render_element{$TYPE}->($iniref,$wrapper,$SITE);
#		
#	return($out);
#	}


##
##
##
sub RENDER_BANNER {
	my ($iniref,$toxml,$SITE) = @_;

	my $USERNAME = $SITE->username();
	my $TXSPECL = undef;
	if (ref($SITE) eq 'SITE') {
		$TXSPECL = $SITE->txspecl();		## populate *TXSPECL
		$USERNAME = $SITE->username();
		}
	else {
		die "SREF is not SITE OBJECT\n";
		}

	if (not defined $TXSPECL) { 
		# print STDERR Dumper($SITE);
		Carp::confess("RENDER_BANNER needs reference to *TXSPECL"); 
		}

	my $UREF = &ZTOOLKIT::parseparams(&TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'},undef,$iniref->{'DEFAULT'}));
	## UREF parameters are IMG, LINK, ALT

	if ((not $iniref->{'HEIGHT'}) || (not $iniref->{'WIDTH'})) { $iniref->{'MINIMAL'}++; }

	if ($iniref->{'MINIMAL'}) {
		($iniref->{'WIDTH'},$iniref->{'HEIGHT'}) = 
			&ZOOVY::image_minimal_size($USERNAME, $UREF->{'IMG'}, $iniref->{'WIDTH'}, $iniref->{'HEIGHT'}, $SITE->cache_ts());
		}
	#$UREF->{'IMGURL'} = &IMGLIB::Lite::url_to_image($SITE->username(), $UREF->{'IMG'}, $iniref->{'WIDTH'}, 
	#	$iniref->{'HEIGHT'}, $iniref->{'BGCOLOR'}, 0, 0, $SITE->{'+cache'});
	# $UREF->{'IMGURL'} = $SITE->URLENGINE()->image_url($UREF->{'IMG'}, $iniref->{'WIDTH'}, $iniref->{'HEIGHT'}, $iniref->{'BGCOLOR'});
	my $PROTOHOST = '';

	if (($toxml->getFormat() eq 'EMAIL') || ($SITE->_is_newsletter())) {
		$PROTOHOST = sprintf("https://%s",&ZOOVY::resolve_media_host($USERNAME));
		}
	elsif ($toxml->getFormat() eq 'WIZARD') {
		$PROTOHOST = sprintf("http://%s",&ZOOVY::resolve_media_host($USERNAME));
		}
	$UREF->{'IMGURL'} = $PROTOHOST.&ZOOVY::image_path($USERNAME,$UREF->{'IMG'}, W=>$iniref->{'WIDTH'}, H=>$iniref->{'HEIGHT'}, B=>$iniref->{'BGCOLOR'}, cache=>$SITE->cache_ts(), M=>$iniref->{'MINIMAL'});

	$UREF->{'LINKURL'} = $UREF->{'LINK'};
	## shortcut for handling %SESSION% and %CART% in links
	if (index($UREF->{'LINKURL'},'%')>=0) { $UREF->{'LINKURL'} = TOXML::RENDER::interpolate_vars($SITE,$UREF->{'LINK'}); }

	my $spec = q~<!-- BANNER: <% print($ID); %> --><% load($PRETEXT); default(""); print(); %><a onClick="if(typeof PleaseTrackClick == 'function') { PleaseTrackClick('banner-<% print($ID); %>','<% print($IMG); %>|<% print($LINK); %>'); }" id="<% print($ID); %>_href" title="<% 
load($ALT); default(""); format(encode=>"entity"); print(); 
%>" href="<%
load($LINKURL); default("#"); format(rewrite); print();
%>">
<img border="0" height="<% print($HEIGHT); %>" width="<% print($WIDTH); %>" id="<% print($ID); %>_img" src="<%
print($IMGURL);
%>" alt="<% load($ALT); default(""); format(encode=>"entity"); print(); %>" />
</a><% load($POSTTEXT); default(""); print(); %><!-- /BANNER: <% print($ID); %> -->~;
	if (defined $iniref->{'HTML'}) { $spec = $iniref->{'HTML'}; }

	if ($UREF->{'IMG'} eq '') { $spec = ''; }

	return($TXSPECL->translate3($spec,[$UREF,$iniref],replace_undef=>0));
	}


##
##
##
sub RENDER_DECAL {
	my ($iniref,undef,$SITE) = @_;


	my $out = '';
	my $decalid = '';
	if ($iniref->{'DECALID'}) {
		## if DECALID is passed in the iniref then use that.
		$decalid = $iniref->{'DECALID'};
		}
	else {
		## otherwise it's a user configurable decal
		$decalid = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'},$iniref->{'LOADFROM'},$iniref->{'DEFAULT'});
		}

	$out = '';
	if ($decalid ne '') {
		$out = &TOXML::RENDER::apply_decal($SITE,$decalid);
		if ($out ne '') {
			$out = ((defined $iniref->{'PRETEXT'})?$iniref->{'PRETEXT'}:'').$out.((defined $iniref->{'POSTTEXT'})?$iniref->{'POSTTEXT'}:'');
			}
		}


	return($out);
	}


##
## 
##
#sub RENDER_WIDGET {
#	my ($iniref,undef,$SITE) = @_;
#
#	# <ELEMENT ID="LIP1" TYPE="LIPSTICK" HEIGHT="200" WIDTH="200" PROMPT="" HELPER=""></ELEMENT>
#
#	}

##
## this element is intended to be called directly by specl, it's output options are less than useful
##	for direct end display to the user :-)
##
##	you must pass the following:
## MODE = AND|OR|EXACT|STRUCTURED|FINDER|SUBSTRING
##		
## CATALOG = the name of the catalog 
##				note: this is implicitly FINDER if MODE=FINDER, or SUBSTRING if mode=SUBSTRING
##
## QUERY =  search string which depends on the type of catalog
##				STRUCTURED: +(AA01 BB01) 
##				SUBSTRING: one or more terms/keywords.
##				FINDER: key1=val1&key2=val2 (probably not supported yet)
##				EXACT|AND|OR: one or more keywords/terms.
##
##	RESULT = 
##		CSV - comma separated list of product/skus
##		COUNT - the number of matches
##		
##
sub RENDER_SEARCH {
	my ($iniref,undef,$SITE) = @_;

	my $debug = (defined $SITE::v->{'debug'})?int($SITE::v->{'debug'}):0;

	if ($iniref->{'MODE'} eq 'FINDER') { $iniref->{'CATALOG'} = 'FINDER'; }
	if ($iniref->{'MODE'} eq 'SUBSTRING') { $iniref->{'CATALOG'} = 'SUBSTRING'; }

	## by default, use logging, unless told otherwise.
	if (not defined $iniref->{'LOG'}) { $iniref->{'LOG'} = 1; }

	my @products = ();
	my ($resultref) = &SEARCH::search(
		$SITE,MODE=>$iniref->{'MODE'},
		KEYWORDS=>$iniref->{'QUERY'},
		CATALOG=>$iniref->{'CATALOG'},
		PRT=>$SITE->prt(),
		LOG=>$iniref->{'LOG'},
		'*NC'=>$SITE->{'*NC'},
		'*SREF'=>$SITE,
		'debug'=>$debug,
		);
	if (defined $resultref) {
		@products = @{$resultref};
		}

#	if ($iniref->{'ID'} eq 'PINKY') {
#		print STDERR Dumper($iniref,$resultref,$err);
#		}

	my $RESULT = '';
	if ($iniref->{'RESULT'} eq 'CSV') {
		$RESULT = join(',',@products)
		}
	elsif ($iniref->{'RESULT'} eq 'COUNT') {
		$RESULT = int(scalar(@products));
		}
	else {
		$RESULT = "**Invalid RESULT [".$iniref->{'RESULT'}."] specified**";
		}

	return($RESULT);
	}


##
## MERCHANT
##		EXTREF is a hash keyed by claim #, with value as a hashref of the product.
##






##
## 
##
sub RENDER_SPECL {
	my ($iniref,undef,$SITE) = @_;

	my $TXSPECL = $SITE->txspecl();

	if (not defined $TXSPECL) { 
		## do not remove this line or shit will break (technically it wil break if you leave this line here too)
		print STDERR Carp::confess("RENDER_SPECL needs reference to *TXSPECL (why not pass SITE to render_page? to make this go away)"); 
		}

	return($TXSPECL->translate3(
			$iniref->{'HTML'},
			[$iniref],
			replace_undef=>0)
			);
	}


#
#	if (index($text,'%')>=0) { $text = TOXML::RENDER::interoplate_session($text); }
#
sub interpolate_vars {
	my ($SITE,$text) = @_;

	# my $is_bot = ($SITE->URLENGINE()->state()&8);
	## my $cart_id = $SITE::CART2->uuid();
	my $cart_id = $SITE->cart2(undef,1)->uuid();
	my $sdomain = $SITE->sdomain();

	my $is_bot = (&ZTOOLKIT::isin($SITE->client_is(),['BOT','SCAN']))?1:0;

	if (index($text,'%CART%')>=0) {
		## my $uri = "\/c\=".$SITE::CART2->cartid();
		my $uri = "\/c\=".$SITE->cart2(undef,0)->cartid();
		## don't interpolate for bots, or if we don't have a cart id.
		if ($is_bot) { $uri = '/'; }
		$text =~ s/\%CART\%/$uri/gs;
		}
	if (index($text,'%SESSION%')>=0) {
		my $uri = '/';
		if ($is_bot && (defined $sdomain)) { $uri = "/s\=$sdomain"; }
		elsif (($is_bot) && (defined $sdomain)) { $uri = "/s\=$sdomain"; }
		elsif ((not $is_bot) && (not defined $sdomain)) { $uri = "/c\=$cart_id"; }
		else { $uri = "\/c\=$cart_id".((defined $sdomain)?"/s\=$sdomain":''); }
		$text =~ s/\%SESSION\%/$uri/gs;
		}
	if (index($text,'%SDOMAIN%')>=0) {
		$text =~ s/\%SDOMAIN\%/$sdomain/gs;
		}
	return($text);
	}





##
## smart_load
## purpose: performs a smart load from determined namespace, etc.
## parameters: LOADFROM (eg: namespace:owner:tag) [should be called loadfrom but its saveto??]
##					DEFAULT (if available, a comma separated list of places to look for default data)
##					VOLR (value of last resort <-- used if nothing better can be found)
## note: uses $TOXML::EDIT::USERNAME it MUST be set or you'll get an undef
## returns: data on success, undef if variable doesn't exist (NOT a reference)
##
sub smart_load {
	my ($SITE, $DATASRC,$LOADFROM,$VOLR) = @_;
	my $RESULT = undef;

#	if (ref($SITE) ne 'HASH') {
#		print STDERR Dumper($SITE);
#		die("[".ref($SITE)."] smart_load called with old parameters");
#		}

#	print STDERR "SMART LOAD: $DATASRC,$LOADFROM,$VOLR PRT=$SITE->prt()\n";

	if (ref($SITE) ne 'SITE') {
		Carp::confess("TOXML::RENDER::smart_load requires SITE object as first parameter");
		}

	## SaNiTy!!
	## my $NS = $SITE->profile();
	my $USERNAME = $SITE->username();
	
	## DATASRC will be product:blah:something
	my ($namespace,$tag) = split(/\:/,lc($DATASRC),2);	
	if ($namespace eq 'channel') { $namespace = 'product'; }


	## first check the HIDEHASH to see if we've entered the data this session.
	# print STDERR "$DATASRC Checking ns[$namespace]tag[$tag]= $SITE->{$tag}\n";
	if (defined($SITE->{$tag})) {
		$RESULT = $SITE->{$tag};
		}
	
	## now lets go ahead and start checking NAME="" parameter
	## then on to LOADFROM 
	## finally use VALUE
	if (not defined($RESULT)) {
		if (!defined($namespace)) { $namespace = ''; }
		if (!defined($tag)) { $tag = ''; } 

		#	print STDERR "TOXML::EDIT::smart_load product=[$TOXML::EDIT::SKU] username=[$TOXML::EDIT::USERNAME] namespace=[$namespace] remainder=[$tag]\n";

		# this crazy hack should let me load FROM merchant namespace, if not SKU namespace is not saved.
		if ($namespace eq 'merchant') { $namespace = 'profile'; }
		if ($namespace eq 'wrapper') { $namespace = 'profile'; $tag = "wrapper:$tag"; }

		#print STDERR 'SMART LOAD: '.Dumper($DATASRC);
		# print STDERR "SREF: $SITE->prt()\n";
		if ($namespace eq 'page') {
			$RESULT = $SITE->pAGE()->get($tag);
			}
		elsif ($namespace eq 'profile') {
			my $nsref = undef;
			if (defined $SITE) { $nsref = $SITE->nsref(); }
			if (defined $nsref) { $RESULT = $nsref->{$tag}; }
			}
		elsif ($namespace eq "product") { 

			$RESULT = undef;
			if (defined $SITE->{'_DATAREF'}) {
				$RESULT = $SITE->{'_DATAREF'}->{$tag};
				}

			my $P = undef;
			if (defined $RESULT) {
				}
			else {
				($P) = $SITE->pRODUCT();
				}

			if (defined $RESULT) {
				}
			elsif ($SITE->pid() eq '') {
				warn "(smart load) - attempt to access $tag on PID ''\n";
				}
			elsif ((defined $P) && (ref($P) eq 'PRODUCT')) {
				if ($tag eq 'zoovy:base_price') {
					## special handling to emulate a schedule.
					## if ($SITE::CART2->in_get('our/schedule') ne '') {
					my $schedule = $SITE->cart2()->in_get('our/schedule');
					if ($schedule ne '') { 
						## we have a pricing schedule so override prices by putting those into %vars
						## my ($vars) = $P->wholesale_tweak_product($SITE::CART2->in_get('our/schedule'));
						my ($vars) = $P->wholesale_tweak_product($schedule);
						$RESULT = $vars->{'zoovy:base_price'};
						}
					else {
						$RESULT = $P->fetch($tag);
						}
					}
				else {
					$RESULT = $P->fetch($tag);
					}

#				print "$tag = $RESULT\n";					
				}
			else {
				print STDERR sprintf("(smart load) ISE? %s COULD NOT LOOKUP SKU '%s'\n",$SITE->username(),$SITE->pid());
				}


			#my $prodref = undef;
			#if (defined $SITE->{'%PRODREF'}) {
			#	$prodref = $SITE->{'%PRODREF'};
			#	}
			#elsif (defined $SITE::SREF->{'%PRODREF'}) {
			#	$prodref = $SITE::SREF->{'%PRODREF'};
			#	$FLOW::DEBUG && warn("smart_load(): product namespace buffer from SREF->%PRODREF->{'$tag'} for $USERNAME... [$RESULT]");
			#	}
			#else {
			#	$prodref = &ZOOVY::fetchproduct_as_hashref($USERNAME,$SKU);
			#	}
			#$RESULT = $prodref->{$tag};
	
			#if ((not $RESULT) && ($tag eq 'zoovy:prod_siblings') && ($SITE->{'+cache'}<0)) {
			#	## okay -- so this is a special field. (and it only works in publisher mode)
			#	my $PARENTSKU = $prodref->{'zoovy:grp_parent'};
			#	my $parentref = &ZOOVY::fetchproduct_as_hashref($USERNAME,$PARENTSKU);
			#	$RESULT = $parentref->{'zoovy:grp_children'};
			#	}

			}
		}

	## Check and see if this value was ever sticky. [sticky is *always* found in merchant namespace]
	## since products can't really be sticky [doesn't make sense??]
	## here's where we recursively look for defaults while not defined($BUF);
	if ((not defined $RESULT) && (defined $LOADFROM) && ($LOADFROM ne '')) {
		foreach my $attrib (split(/,/,$LOADFROM)) {
			next unless (not defined($RESULT));
			($RESULT) = &smart_load($SITE,$attrib,undef,undef);
			}
		}

	## finally, try to return VOLR (Value Of Last Resort)	
	if ((not defined($RESULT)) && defined($VOLR) && ($VOLR ne '')) { $RESULT = $VOLR; }

	#print STDERR "[$NS]smart_load: $DATASRC [$RESULT]\n";
	# if ($TOXML::EDIT::DEBUG) {	print STDERR "TOXML::EDIT::smart_load: pg=[$SITE->{'_PG'}] $namespace,$tag = ".(defined($RESULT)?$RESULT:'undef')."\n"; }

	#print STDERR "RETURNING: $RESULT\n";
	#my ($package,$file,$line,$sub,$args) = caller(1);
	#print STDERR "CALLED FROM: $package,$file,$line,$sub,$args)\n";
	#my ($package,$file,$line,$sub,$args) = caller(0);
	#print STDERR "CALLED FROM: $package,$file,$line,$sub,$args)\n";

	return($RESULT);
	}



########################################
##
## render_page
## returns: the outputted version of a page.
##		## NOTE: This is ALSO called from newsletter!
##		## NOTE: also called from TOXML->render
##
## SITE::run is basically this:
sub render_page {
	my ($iniref,$toxml,$SITE) = @_;

	if (not defined $toxml) { print STDERR Carp::confess("toxml parameter (now) must be passed to render_page"); }
	if (not defined $SITE) { print STDERR Carp::confess("SREF parameter (now) must be passed to render_page"); }
	if (ref($SITE) ne 'SITE') { print STDERR Carp::cluck("TOXML::RENDER::render_page was called with legacy SREF object"); }

	# my $IS_SANDBOX = 0;

	# use Data::Dumper; print STDERR "[render_page] ".Dumper($iniref,$toxml,$SITE);
	# ($page_name, $flow, $prod) = @_; # commented out after perl was bitching about $page_name, $prod
	# and $flow not being used (these things are being passed through globals nowadays). -AK 5-19-01

#	open F, ">>/tmp/asdf";	print F Dumper($toxml);	close F;

	my $USERNAME = $SITE->username();
	if (not defined $SITE::CART2) { 
		warn "GLOBAL SITE::CART2 should be set before calling TOXML::RENDER::render_page()\n";
		$SITE::CART2 = CART2->new_memory($USERNAME,$SITE->prt()); 
		}

	#if (defined $iniref->{'PREVIEW'}) {
	#	$iniref->{'_PREVIEW'} = $iniref->{'PREVIEW'};
	#	delete $iniref->{'PREVIEW'};
	#	}
	if ($SITE->_is_preview()) { $iniref->{'_PREVIEW'} = $SITE->_is_preview(); }

	my $BUF = '';
	#if ($iniref->{'TYPE'} eq 'INCLUDE') {
	#	($toxml) = TOXML->new($iniref->{'FORMAT'},$iniref->{'FILE'},USERNAME=>$USERNAME);
	#	if (not defined $toxml) { return("Could not render page due to missing TOXML Layout file FORMAT[$iniref->{'FORMAT'}] FILE=[$iniref->{'FILE'}] merchant[$USERNAME]"); }
	#	}
	my ($DOCID,$DOCFORMAT) = (undef,undef);
	#if (not defined $toxml) {
	#	if (defined $iniref->{'DOCID'}) { 
	#		## the DOCID has been overwritten in the element.
	#		$DOCID = $iniref->{'DOCID'}; 
	#		}
	#	else { 
	#		## try and get it from the SREF (this is the *normal* way this happens)
	#		$DOCID = $SITE->{'_DOCID'}; 
	#		}

	#	($toxml) = TOXML->new('LAYOUT',$DOCID,USERNAME=>$USERNAME,FS=>$SITE->{'_FS'},cache=>$SITE->{'+cache'});
	#	if (not defined $toxml) { ($toxml) = TOXML->new('LAYOUT','',USERNAME=>$USERNAME,FS=>$SITE->{'_FS'}); }
	#	if (not defined $toxml) { return("Could not render page due to missing TOXML Layout file (hint: try passing DOCID) FS[$SITE->{'_FS'}] DOCID[$DOCID] merchant[$USERNAME]"); }
	#	# print STDERR "DOCID: ".$toxml->docId()."\n";	
	#	}
	$DOCFORMAT = $toxml->getFormat();
	$DOCID = $toxml->docId();

	# if (defined $SITE::pbench) { $SITE::pbench->banner("start render $DOCFORMAT $DOCID"); }

	$SITE->URLENGINE()->set( layout=>$toxml->docuri() );

#  if (defined $iniref->{'MARKET'}) {
#      ## e.g. ebay, overstock,
#		$SITE->URLENGINE()->override('checkout_url','#');
#
#      # $FLOW::SECURE_URLS{'checkout_url'} = '#';
#      if (uc($iniref->{'MARKET'}) eq 'EBAY') {
#			$SITE->URLENGINE()->override('checkout_url',"https://ebaycheckout.zoovy.com/checkout.cgi?MERCHANT=$USERNAME&SKU=".$iniref->{'SKU'}."&CHANNEL=".$iniref->{'CHANNEL'}."&UUID=".$iniref->{'UUID'});
#        # $FLOW::SECURE_URLS->{'checkout_url'} = "https://ebaycheckout.zoovy.com/checkout.cgi?MERCHANT=$USERNAME&SKU=".$iniref->{'SKU'}."&CHANNEL=".$iniref->{'CHANNEL'}."&UUID=".$iniref->{'UUID'};
#        # $FLOW::URLS->{'checkout_url'} = "https://ebaycheckout.zoovy.com/checkout.cgi?MERCHANT=$USERNAME&SKU=".$iniref->{'SKU'}."&CHANNEL=".$iniref->{'CHANNEL'}."&UUID=".$iniref->{'UUID'};
#         }
#      elsif (uc($iniref->{'MARKET'}) eq 'OVERSTOCK') {
#			$SITE->URLENGINE()->override('checkout_url',"https://webapi.zoovy.com/webapi/overstock/checkout.cgi?MERCHANT=$USERNAME&SKU=".$iniref->{'SKU'}."&CHANNEL=".$iniref->{'CHANNEL'}."&UUID=".$iniref->{'UUID'});
#        # $FLOW::SECURE_URLS->{'checkout_url'} = "https://webapi.zoovy.com/webapi/overstock/checkout.cgi?MERCHANT=$USERNAME&SKU=".$iniref->{'SKU'}."&CHANNEL=".$iniref->{'CHANNEL'}."&UUID=".$iniref->{'UUID'};
#        # $FLOW::URLS->{'checkout_url'} = "https://webapi.zoovy.com/webapi/overstock/checkout.cgi?MERCHANT=$USERNAME&SKU=".$iniref->{'SKU'}."&CHANNEL=".$iniref->{'CHANNEL'}."&UUID=".$iniref->{'UUID'};
#         }
#		else {
#			$SITE->URLENGINE()->override('checkout_url',"#unknown/mkt=$iniref->{'MARKET'}");
#			# $FLOW::SECURE_URLS->{'checkout_url'} = "#unknown/mkt=$iniref->{'MARKET'}"; 
#			}
#      }


	##
	## SUBS code block.
	##
	my $SUBSREF = undef;
	if (not defined $toxml) {
		## oh shit, no toxml.. this line should never be reached!
		}
	elsif (defined $toxml) {
		if ($DOCFORMAT eq 'WRAPPER') {
			## wrappers are top level, they get their own SUBS - they don't inherit from another doc, we init them below
			$SUBSREF = undef;
			}
	
		## wiki text
		## NOTE: these are duplicated in SITE::EMAIL
		if (not defined $SUBSREF) { 
			$SUBSREF = {
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
			};
			## eventually we could probably add a few "sane" subs in here.
			}

		if (defined $iniref->{'SUBS'}) {
			## SUBS are passed to ourselves when we call ourselves from a DIV="SUB" element
			## we also pass from TYPE=BODY in site.pl
			my $kvpairs = &ZTOOLKIT::parseparams($iniref->{'SUBS'});
			foreach my $k (keys %{$kvpairs}) { $SUBSREF->{$k} = $kvpairs->{$k}; }
			}
		}


	##
	## WHAT SHOULD OUR OUTSKIP BE?
	##
	my $OUTPUTSKIP = 0;	
	if (defined $toxml) {
		## NOTE: THIS CODE IS BASICALLY **COPIED** in SITE::Vstore (search for OUTPUTSKIP)
		$OUTPUTSKIP = 0 + (($SITE->_is_secure())?2:4) + 
						( ($SITE::CART2->in_get('customer/login') eq '')?8:16 ) +
						( ($SITE::CART2->count('show'=>'')==0)?32:64 );		# 4096 = flow
		## a/b test output skips.
		$OUTPUTSKIP |= (($SITE::CART2->in_get('cart/multivarsite') eq 'A')?256:0);
		$OUTPUTSKIP |= (($SITE::CART2->in_get('cart/multivarsite') eq 'B')?512:0);
		## NOTE: when wrapper is passed implicitly then MULTIVARSITE isn't set
		# $OUTPUTSKIP |= (($SITE::SREF->{'_MULTIVARSITE'} eq '')?256+512:0);

		if ($DOCFORMAT eq 'WRAPPER') { $OUTPUTSKIP += 2048; }
		elsif ($DOCFORMAT eq 'LAYOUT') { $OUTPUTSKIP += 4096; }
		elsif ($DOCFORMAT eq 'WIZARD') { $OUTPUTSKIP += 8192; }
		elsif ($DOCFORMAT eq 'EMAIL') { $OUTPUTSKIP += 16384; }
		elsif ($DOCFORMAT eq 'ZEMAIL') { $OUTPUTSKIP += 16384; }

		if ($iniref->{'_PREVIEW'}) { $OUTPUTSKIP = 32768; }		# override all other skips.
		}
	else {
		$BUF = sprintf(q~<font color="red">There is a problem with layout %s</font><br>~,$SITE->layout());
		}
	# $BUF .= "<h1>OUTPUTSKIP: $OUTPUTSKIP<h1>";

	##
	## now lets create an array of elements
	##
	my $elementsref = [];
	if (not defined $toxml) {
		}
	elsif ($toxml->BLOCK_RECURSION() && (not $iniref->{'DIV'})) {
		## NOTE: DIV's are used by both eBay templates (ex: WARLOCK) and also SITE::EMAILS
		warn "RECURSION WAS BLOCKED!\n";
		}
	else {
		# print STDERR "OUTPUTSKIP: $OUTPUTSKIP\n";

		if (defined $iniref->{'DIV'}) {
			## load alternate elements from a DIV (if passed by the INI)
			## ** THIS IS DEFINITELY USED BY EMAILS ORDERMANAGER SENDMAIL **
			$elementsref = $toxml->getElements($iniref->{'DIV'});

			# print STDERR "Loading div: $iniref->{'DIV'} ".Dumper($iniref,$elementsref)."\n";
			# print STDERR Dumper($iniref->{'DIV'},$elementsref);
			}
		else {
			## we should only BLOCK_RECURSION on non DIV lookups (otherwise RECURSION is fine)
			$elementsref = $toxml->elements();
			$toxml->BLOCK_RECURSION(1);
			}

		## do some element rewrites (upgrades legacy elements, etc.)
		foreach my $el (@{$elementsref}) {
			## if we're doing a SUB, then by default enable RAW mode
			if ((defined $el->{'SUB'}) && (not defined $el->{'RAW'})) { 
				if ($el->{'TYPE'} ne 'IMAGE') { $el->{'RAW'} = 1; }
				}

			if ($iniref->{'_PREVIEW'})  {
				$el->{'_PREVIEW'}++;					# denotes that we're previewing an element.
				if (($el->{'TYPE'} eq 'BODY') && ($DOCFORMAT eq 'WRAPPER')) { $el->{'TYPE'} = 'NULL'; }
				}

			if (($DOCFORMAT ne 'WRAPPER') && ($el->{'TYPE'} eq 'BODY')) {
				push @SITE::ENDPAGE, { TYPE=>'OUTPUT', HTML=>qq~<h1><font color="RED">Critical Programming error - BODY of $DOCFORMAT contained another BODY element. PLEASE REMOVE IMMEDIATELY!</font></h1>~ };
				$el->{'TYPE'} = 'NULL';
				}
			}
		}





	foreach my $el (@{$elementsref}) {

		
		$el->{'_DOCID'} = $DOCID;
		# $el->{'_PG'} = $SITE->pageid();
		# $el->{'FS'} = $SITE->fs();
		$el->{'_FORMAT'} = $DOCFORMAT;		# this is specifically necessary for backwards compatibility on TURBOMENU
		$el->{'_DOCID'} = $DOCID;

		# print STDERR "INIT[$el->{'ID'}] $el->{'INIT'}\n";
	
		if ($el->{'INIT'}) {
			## this is a small chunk of specl code which can override various parameters.
			# print STDERR "INIT: $el->{'INIT'}\n";
			$SITE->txspecl()->translate3($el->{'INIT'},[$el],replace_undef=>1,initref=>$el);
			# print STDERR 'RESULT: '.Dumper($el);
			}

		my $TYPE = $el->{'TYPE'};
		next if ((not defined $TYPE) || ($TYPE eq ''));


		if (defined $el->{'OUTPUTIF'}) { $el->{'OUTPUTSKIP'} = 128; }
	
		if (not defined $el->{'OUTPUTSKIP'}) {}
		elsif (($OUTPUTSKIP & int($el->{'OUTPUTSKIP'})) >0) { $TYPE='NULL'; }
		elsif ( (int($el->{'OUTPUTSKIP'}) & 128)==128) {
			## no longer available 8/30/12
			# if (not &SITE::output_if($el->{'OUTPUTIF'})) { $TYPE='NULL'; }
			}
		elsif ( ( int($el->{'OUTPUTSKIP'}) & 1)==1) {

			##
			## if OUTPUTLIMIT is set to 1 in an element, then the elements OUTPUTFILTER is passed to this
			##		function, which then goes through and figures out if a page should be filtered. 
			##
			my ($FILTER) = $el->{'OUTPUTFILTER'};

			my $matches = 0;
			foreach my $kv (split(/\&/,$FILTER)) {
				my ($k,$v) = split(/=/,$kv,2);
				next if ($matches);

				my $negate = 0;
				if (substr($k,0,1) eq '!') { $k = substr($k,1); $negate = 1; }

				## comma separated list of page names.
				if ($k eq 'PG') {
					foreach my $pg (split(/,/,$v)) {
						# print STDERR "MATCHES[$matches]: lc($pg) eq lc()\n"; 
						if (lc($pg) eq lc($SITE->pageid())) { $matches++; }
						}
					}
				elsif ($k eq 'SDOMAIN') {
					foreach my $sdomain (split(/,/,$v)) {
						if (lc($sdomain) eq $SITE->sdomain()) { $matches++; }
						}
					}
				elsif ($k eq 'NAVCAT') {
					## 
					my $cwpath = lc($SITE->servicepath()->[1]);
					foreach my $navcat (split(/,/,$v)) {
						if (lc($navcat) eq $cwpath) { $matches++; }
						}
					}
				elsif ($k eq 'NAVTREE') {
					## the category + a subtree of categories (can be comma separated)	
					## HINT: if you only want descendants then use .cat1.
					my $cwpath = lc($SITE->servicepath()->[1]);
					foreach my $navcat (split(/,/,$v)) {
						$navcat = quotemeta($navcat);
						if ($cwpath =~ /^$navcat/) { $matches++; }
						}
					}
				elsif ($k eq 'FS') {
					foreach my $fl (split(/,/,$v)) {
						if (lc($fl) eq lc($SITE->fs())) { $matches++; }
						}
					}
				#elsif ($k eq 'PROFILE') {
				#	foreach my $mkt (split(/,/,$v)) {
				#		if (lc($v) eq lc($SITE->profile())) { $matches++; }
				#		}
				#	}
				elsif ($k eq 'SCHEDULE') {
					foreach my $schedule (split(/,/,$v)) {
						if ( lc($v) eq lc($SITE::CART2->schedule()) ) { $matches++; }
						}
					}
				elsif (($k eq 'DOCID') || ($k eq 'FL')) {
					foreach my $fl (split(/,/,$v)) {
						if (lc($fl) eq $SITE->layout()) { $matches++; }
						}		
					}

				## if we're returning a negated answer, then flip matches.
				if ($negate) { $matches = ($matches)?0:1; }
				}

			if ($matches) { $TYPE='NULL'; }
			}

		## NOTE: BODY element *MUST* be after OUTPUTSKIP so that body elements can be OUTPUTSKIPped
		if ($TYPE eq 'BODY') {
			$el->{'SUBS'} = &ZTOOLKIT::buildparams($SUBSREF,1);
			$BUF .= &SITE::run($SUBSREF,\@SITE::PREBODY,undef,$SITE);
			#print STDERR "BUF:".length($BUF)."\n";
			#die();

			if (scalar(@SITE::ERRORS)>0) {
				## output any errors
				foreach my $err (@SITE::ERRORS) {
					$BUF .= (qq~<div id=\"div_site_error\" class="zwarn"><font class=\"zwarn\">$err</font></div>~);
					}
				print STDERR Dumper(\@SITE::ERRORS);
				}

			}


		if ($TYPE eq 'NULL') {}		# don't do shit.
		elsif ($iniref->{'_PREVIEW'}) {
			require TOXML::PREVIEW;
			require TOXML::EDIT;
				if ($TYPE eq 'DISPLAY') {
				## preview display elements are event specialier
				my (undef,$TMP) = &TOXML::EDIT::element_display($el,$toxml,$SITE);
				foreach my $k (keys %{$SUBSREF}) {
					next unless (index($TMP,$k)>=0);
					$TMP =~ s/$k/$SUBSREF->{$k}/gs;
					}
				$BUF .= "<table>".$TMP."</table>";
				$TYPE = 'NULL';
				# if ($el->{'ID'} eq 'CVKNGSQ') { die(); }
				}
			elsif (($iniref->{'_PREVIEW'}) && (defined $TOXML::PREVIEW::preview_element{$TYPE}) && (not $el->{'READONLY'})) {
				## preview elements are special
				my ($TMP) = $TOXML::PREVIEW::preview_element{$TYPE}->($el,$toxml,$SITE);
				foreach my $k (keys %{$SUBSREF}) {
					next unless (index($TMP,$k)>=0);
					$TMP =~ s/$k/$SUBSREF->{$k}/gs;
					}
				$BUF .= $TMP;
				if (defined $el->{'SUB'}) {
					## if it was a SUB, then load up the rendered value for future subs that may rely on it.
					$SUBSREF->{'%'.$el->{'SUB'}.'%'} = $TOXML::RENDER::render_element{$TYPE}->($el,$toxml,$SITE);
					}								
				$TYPE = 'NULL';
				}
#			print STDERR "SRC=$el->{'ID'} EL: $el->{'TITLE'} $el->{'TYPE'} PRT: $SITE->prt() NS $SITE->{'_NS'}\n";
#			if ($el->{'ID'} eq 'CVKNGSQ') { die(); }
			}


		my $cache_id = undef;
		if ($TYPE eq 'NULL') {
			## if we had a NULL output, we should set the SUB value to blank
			if (defined $el->{'SUB'}) { $SUBSREF->{ '%'.$el->{'SUB'}.'%' } = ''; }
			}
		elsif (defined($TOXML::RENDER::render_element{$TYPE})) {
			## NOTE: this is only for renderable elements, not those with SUBS on them.
			my $tagout = undef;
		

			if ((not defined $tagout) && ($TYPE eq 'BODY')) {
				## BODY elements are a bit special
				$toxml->BLOCK_RECURSION(1);
				##
				## TODO:: evaluate caching capability for product, category pages (once session id's are removed)
				##
				if ((defined $iniref->{'DOCID'}) && ($iniref->{'DOCID'} ne '')) { 
					## the DOCID has been overwritten in the element.
					$DOCID = $iniref->{'DOCID'}; 
					}
				else { 
					## try and get it from the SREF (this is the *normal* way this happens)
					$DOCID = $SITE->layout();
					}

				if ($DOCID eq '') { 
					$tagout = "ERR: PAGE LAYOUT not specified.";
					# &ZOOVY::confess($USERNAME,"$tagout\n\n".Dumper($SITE),justkidding=>1); 
					}
				else {
					#my ($bodytoxml) = TOXML->new('LAYOUT',$DOCID,'USERNAME'=>$USERNAME,'FS'=>$SITE->fs(),cache=>$SITE->cache_ts());
					#if (not defined $bodytoxml) { ($toxml) = TOXML->new('LAYOUT','',USERNAME=>$USERNAME,FS=>$SITE->fs()); }
					#if (not defined $bodytoxml) { return("Could not render page due to missing TOXML Layout file (hint: try passing DOCID) FS[".$SITE->fs()."] DOCID[$DOCID] merchant[$USERNAME]"); }
					#$tagout = $TOXML::RENDER::render_element{'BODY'}->($el,$bodytoxml,$SITE);
					my ($bodytoxml) = TOXML->new('LAYOUT',$DOCID,'USERNAME'=>$USERNAME,'FS'=>$SITE->fs(),cache=>$SITE->cache_ts());
					if (not defined $bodytoxml) { 
						$tagout = "ERR: INVALID PAGE LAYOUT '$DOCID' SPECIFIED."; 
						# &ZOOVY::confess($USERNAME,"$tagout\n\n".Dumper($SITE),justkidding=>1); 
						}
					else {
						$tagout = $TOXML::RENDER::render_element{'BODY'}->($el,$bodytoxml,$SITE);
						}
					}

				# $tagout = 'BODY';
				}

			if ($el->{'CACHEABLE'}) {
				if (not $SITE->URLENGINE()->has_cookies()) {
					## turn off cachable anytime we don't have cookies. (since we're using session id's)
					$el->{'CACHEABLE'} = 0;
					}
				if ($SITE->globalref()->{'%tuning'}->{'disable_cacheable'}) {
					$el->{'CACHEABLE'} = 0;
					}
				}
			

			if (defined $tagout) {
				}
			elsif (not defined $SITE::memd) {
				}
			elsif (not $el->{'CACHEABLE'}) {
				}
			#elsif ($SITE::merchant_id eq 'redford') {
			#	# (defined $SITE->{'%GREF'}->{'%tuning'}->{'disable_memcache'}) && (not $SITE->{'%GREF'}->{'%tuning'}->{'disable_memcache'})) {
			#	# implicity disable memcache for a client who is abusing it.
			#	}
			else {
				$cache_id = $SITE->cache_id($el);
				
				if (defined $cache_id) {
					($tagout) = $SITE::memd->get($cache_id);
					}
				if (defined $tagout) { 
					$cache_id = "HIT/$cache_id"; 
					}
				#else {
				#	print STDERR "GOT MISS ON $cache_id\n";
				#	}
				}

			if (not defined $tagout) {
				($tagout) = $TOXML::RENDER::render_element{$TYPE}->($el,$toxml,$SITE);
				# use Data::Dumper; open F, ">>/tmp/foo2"; print F Dumper($SITE->sku(),$el,$tagout); close F;

				## an inline div
				##		pass DIV="OUTPUT" and then we attempt to load a div based on the value of "TAGOUT"
				if (defined $el->{'DIV'}) { 
					if (($el->{'DIV'} eq 'SUB') && ($tagout ne '')) {
						$el->{'DIV'} = $tagout;
						$el->{'SUBS'} = &ZTOOLKIT::buildparams($SUBSREF);
						$tagout = &TOXML::RENDER::render_page($el,$toxml,$SITE);
						}
					elsif ($el->{'DIV'} eq 'INCLUDE') {
						## include divs not supported yet.
						## allows another toxml file to be loaded and passed to FLOW::REND
						}
					else {
						## inline divs are not supported yet! 
						##	(inline elements should be added to the current stack as if they were there the whole time)
						$tagout = &TOXML::RENDER::render_page($el,$toxml,$SITE);
						# if ($el->{'DIV'} ne '') { print STDERR "ID: $el->{'ID'} $TYPE |$el->{'DIV'} [$tagout]\n"; }

						#print Dumper($el);
						#print "TAGOUT: $tagout\n\n\n\n\n\n"; 
						}
					}

				foreach my $k (keys %{$SUBSREF}) {
					#next unless (substr($k,0,2) ne '%/');	# if we have a %/VAR% then we ONLY do a 
					#													# sub when %VAR% is present
					next unless (index($tagout,$k)>=0);
					$tagout =~ s/$k/$SUBSREF->{$k}/gs;
					}
				if (defined $cache_id) {
					warn "Set: $cache_id ".length($tagout)."\n";
					$SITE::memd->set($cache_id,$tagout);
					$cache_id = "MISS/$cache_id";
					}				
				}


			if (defined $el->{'SUB'}) {
				## not for output!
				$SUBSREF->{'%'.$el->{'SUB'}.'%'} = $tagout;
				}
			#elsif (defined $SITE->{'*R'}) {
			#	## SREF->{'*R'} is a reference to the apache response object (that allows us to do 
			#	$SITE->{'*R'}->print($tagout);
			#	}
			else {
				$BUF .= $tagout;
				}

			#open F, ">>/tmp/subsref";
			#print F Dumper($SUBSREF);
			#close F;

			if ((int($SITE::v->{'debug'})&2)==2) {
				push @SITE::ENDPAGE, { TYPE=>'OUTPUT', HTML=>'<!-- PAGE: '.&ZOOVY::incode(Dumper($el))."\n\n RESULT: $BUF -->" };
				}

			}
		else {
			use Data::Dumper;
			# print STDERR 'UNKNOWN ELEMENT: '.Dumper($el);
			$BUF .= qq~<font color="red">Unknown element TYPE=[$TYPE]</font>\n~;
			}

		## PROFILER
		if (defined $SITE::pbench) { 
			$SITE::pbench->stamp("render_page TYPE=$el->{'TYPE'} ID=$el->{'ID'} PROMPT=$el->{'PROMPT'} CACHE=$cache_id"); 
			}
		}    # end of foreach


	$toxml = undef;

	if ($iniref->{'_PREVIEW'}) {
		$BUF =~ s/<!--(.*?)-->//gs;		
		$BUF =~ s/<script.*?<\/script>//igs;
		# $BUF =~ s/<script.*?<\/script>//gs;

		## NEWSLETTER CODE 
		if ($SITE->pageid() =~ /^\@CAMPAIGN:([\d]+)$/) {
			# require CUSTOMER::NEWSLETTER;
			# $BUF .= &CUSTOMER::NEWSLETTER::format_footer({USERNAME=>$USERNAME,PROFILE=>$SITE->{'_NS'}});
			}
		}

	# print STDERR "BUF: $BUF\n";

	if (defined $SITE::pbench) { $SITE::pbench->banner("end render $DOCFORMAT $DOCID"); }


	return ($BUF);
	} 






sub RENDER_IMAGESELECT {
	my ($iniref) = @_;
	}

##
## this is an internal object which lets us invoke certain object parameters
##	this might eventually be used to call a checkout object, create a customer on the fly,
##	or god only knows what.
##
sub RENDER_API {
	my ($iniref) = @_;

	if ($iniref->{'X'} eq 'CART') {		
		if ($iniref->{'METHOD'} eq 'shipping') {
			# $SITE::CART2->shipping();
			}
		}
	}


##
## 
##
sub RENDER_FAQ {
	my ($iniref,undef,$SITE) = @_;

	my $ID = $iniref->{'ID'}; 
	if (defined $SITE::v->{lc($ID.'.KEYWORDS')}) { $iniref->{$ID.'.KEYWORDS'} = $SITE::v->{lc($ID.'.KEYWORDS')}; }
	if (defined $SITE::v->{lc($ID.'.TOPIC_ID')}) { $iniref->{$ID.'.TOPIC_ID'} = $SITE::v->{lc($ID.'.TOPIC_ID')}; }

	require SITE::FAQS;
	my ($faqs) = SITE::FAQS->new($SITE->username(),$SITE->prt());
	
	if (defined $iniref->{$ID.'.KEYWORDS'}) {
		$faqs->restrict(KEYWORDS=>$iniref->{$ID.'.KEYWORDS'});
		}
	if (defined $iniref->{$ID.'.TOPIC_ID'}) {
		$faqs->restrict(TOPIC_ID=>$iniref->{$ID.'.TOPIC_ID'});
		}

	my $spec = $iniref->{'HTML'};
	my ($topicsar) = $faqs->list_topics();

	foreach my $topic (@{$topicsar}) {
		## iterate through each topic, add 
		$topic->{'TOPIC_ID'} = $topic->{'ID'};
		delete $topic->{'ID'};
		$topic->{'TOPIC_TITLE'} = $topic->{'TITLE'};
		delete $topic->{'TITLE'};
		}
	($iniref->{'TOPICSTACK'}) = $SITE->txspecl()->spush('',@{$topicsar});

	my $totalcount = 0;
	foreach my $topic (@{$topicsar}) {
		my ($faqsref) = $faqs->list_faqs($topic->{'TOPIC_ID'});
		print STDERR "FAQS: ".Dumper($faqsref);

		($topic->{'FAQSTACK'}) = $SITE->txspecl()->spush('',@{$faqsref});
		$topic->{'TOPICFAQ_TOTALCOUNT'} = scalar(@{$faqsref});
		$totalcount += $topic->{'TOPICFAQ_TOTALCOUNT'};
		}

	$iniref->{'FAQ_TOTALCOUNT'} = $totalcount;
	$iniref->{'TOPIC_TOTALCOUNT'} = scalar(@{$topicsar});

	my $out = '';
	if ($totalcount>0) {
		$out = $SITE->txspecl()->process_list(
			'id'=>$iniref->{'ID'},
			'replace_undef'	=> 0,
			'spec'            => $spec,
			'items'           => $topicsar,
			'lookup'          => [$iniref],
			'item_tag'        => 'TOPIC',
			'divider'			=> $iniref->{'DIVIDER'},
			);
		}
	else {
		$out = $SITE->txspecl()->translate3($iniref->{'EMPTY_MESSAGE'},[$iniref]);
		}



	return($out);
	}


##
## 
##
sub RENDER_SET {
	my ($iniref,undef,$SITE) = @_;

	# print STDERR 'RENDER_SET'.Dumper($iniref);
	my $USERNAME = $SITE->username();

	if ((defined $iniref->{'SRC'}) && (defined $iniref->{'DATA'})) {		
		$iniref->{'SRC'} = lc($iniref->{'SRC'});

		if ($iniref->{'SRC'} =~ /^sref\:\:(.*?)$/) {
			## SREF VARS can be:
			##		_PID	
			## 	_SKU	
			
			## print STDERR 'ELEMENT SET --'.Dumper($iniref);

			my $VAR = uc($1);
			if (($VAR eq 'PID') || ($VAR eq 'SKU')) {
				if ($iniref->{'FIX'}) {
					}
				elsif (substr($SITE->layout(),0,1) eq '~') {
				# 	&ZOOVY::confess($USERNAME,"SETE DATA=$iniref->{'DATA'} ".$SITE->layout()." $iniref->{'ID'}\n",justkidding=>1);
					}
				$SITE->setSTID($iniref->{'DATA'});
				}

			}
		elsif ($iniref->{'SRC'} =~ /^product\:\:(.*?)$/) {
			## silly - we can't set product attributes!
			}
		elsif ($iniref->{'SRC'} =~ m/^cart\:\:(.*?)$/) { 
			$iniref->{'SRC'} = $1;
			if (not defined $SITE::CART2) { $SITE::CART2 = CART2->new_persist($USERNAME,$SITE->prt(),$iniref->{'CART'},'is_fresh'=>0); }
			if (defined $SITE::CART2) { 
				$SITE::CART2->legacy_save_property($iniref->{'SRC'},$iniref->{'DATA'}); 
				} 
			}
		
		}
	return();
	}

##
## Syntax:
##		HTML may contain:
##			<!-- SUMMARY -->
##			<!-- /SUMMARY -->
##
sub RENDER_REVIEWS {
	my ($iniref,undef,$SITE) = @_;

	my $USERNAME = $SITE->username();
	require PRODUCT::REVIEWS;

	my $PID = $SITE->{'_PID'};
	if ($iniref->{'PRODUCT'}) { $PID = $iniref->{'PRODUCT'};  } ## override the product.
		

	my $review_url    = $SITE->URLENGINE()->get('cart_url');
	my $spec = (defined $iniref->{'HTML'})?$iniref->{'HTML'}:'';

	if ((not defined $spec) || ($spec eq '')) {
		$spec = qq~
		<!-- SUMMARY -->
		<!-- /SUMMARY -->
	
		<!-- DETAIL -->
		<table>
			<!-- ROW -->
			<!-- REVIEW -->
			<tr>
				
			</tr>
			<!-- /REVIEW -->
			<!-- /ROW -->
		</table>
		<!-- /DETAIL -->
		~;
		}


	my $summaryspec = undef;
	if (index($spec,'<!-- SUMMARY -->')>=0) { 
		($summaryspec, $spec) = $SITE->txspecl()->extract_comment($spec,'SUMMARY');
		}

	my $detailspec = undef;
	if (index($spec,'<!-- DETAIL -->')>=0) { 
		($detailspec, $spec) = $SITE->txspecl()->extract_comment($spec,'DETAIL');
		}

	my $out = '';
	if (defined $summaryspec) {
		## computes the summary variables.
		my ($count,$ratingsum) = &PRODUCT::REVIEWS::fetch_product_review_summary($USERNAME,$PID);
		my %vars = ();
		$vars{'AVG_RATING'} = ($count>0)?sprintf("%d",$ratingsum/$count):0;
		$vars{'AVG_RATINGDECIMAL'} = ($count>0)?sprintf("%.1d",($ratingsum/$count)/2):0;
		$vars{'TOTAL_REVIEWS'} = $count;
		$out = $SITE->txspecl()->translate3($summaryspec,[\%vars,$iniref]);
		}

	if (defined $detailspec) {		
		my ($reviewsref) = &PRODUCT::REVIEWS::fetch_product_reviews($USERNAME,$PID);

		## creates a detailed list.
		##
		## %RATING% e.g. [9] out of 10
		## %RATINGDECIMAL% [4.5] = 9/2
		## %PID% 						- the product id in focus 
		##	%CREATED%					- the date the review was created
		## %USEFUL_YES%				- how many people thought this review was useful.
		## %USEFUL_NO%					- how many people thought this review was NOT useful
		## %USEFUL_SUM%				- how many people answered the "useful" question
		## %BLOG_URL%					- the link to an independent review
		## %MESSAGE%					- the message
		## %TITLE%						- the title of the customer
		## %LOCATION%					- the location of the customer
		## %CID%							- the customers cid #
		## %CID_TOTALREVIEWS_SUM%	- how many reviews this individual has done
		## 
		$out =  $SITE->txspecl()->process_list(
			'id'=>$iniref->{'ID'},
			'spec'            => $detailspec,
			'items'           => [@{$reviewsref}],
			'lookup'          => [$iniref],
			'item_tag'        => 'REVIEW',
#			'alternate'       => $alternate,
#			'cols'            => $iniref->{'FORCECOLUMNS'},
			);
		}


	return($out);
	}


##
## RENDER_SITEMAP
##
sub RENDER_SITEMAP {
	my ($iniref,undef,$SITE) = @_;

	my $USERNAME = $SITE->username();
	if (not defined $iniref->{'HTML'}) {
		$iniref->{'HTML'} = q~
<table>
<!-- LEVEL1 -->
<tr><td><a href="<% load($safe1);  print(); %>"><% load($pretty1);  print(); %></a></td></tr>
<tr>
        <td><table>
        <!-- LEVEL2 -->
        <tr><td><a href="<% load($safe2);  print(); %>"><% load($pretty2);  print(); %></a></td></tr>
        <tr>
                <td>

                </td>
        </tr>
        </!-- LEVEL2 -->
        </table></td>
</tr>

<tr><td>&nbsp;</td></tr>
<!-- /LEVEL1 -->
</table>~;
		}

	my ($NC) = &SITE::get_navcats($SITE);
	foreach my $safe ($NC->paths($SITE->rootcat())) {
		next if (not defined $safe);
		}
	undef $NC;

	}


##
## 
##
sub RENDER_CHECKBOX {
	my ($iniref,$toxml,$SITE) = @_;

	# my $VALUE = def(&FLOW::smart_load($iniref->{'DATA'},$iniref->{'LOADFROM'},$iniref->{'DEFAULT'}));
	my $VALUE = def(&TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'},$iniref->{'LOADFROM'},$iniref->{'DEFAULT'}));
	if ($VALUE eq $iniref->{'ON'}) {
		## if available, display the "True" value
		if (defined $iniref->{'TRUE'}) { $VALUE = $iniref->{'TRUE'}; }		
		}
	else {
		## if avialable, display the "False" value
		if (defined $iniref->{'FALSE'}) { $VALUE = $iniref->{'FALSE'}; }
		}


	}


sub RENDER_NULL { return('') ; }

##
## NOTE: hidden just loads a value, sorta like readonly.
##
sub RENDER_HIDDEN {
	my ($iniref,$toxml,$SITE) = @_;	

	my $VALUE = undef;
	if (defined $iniref->{'DATA'}) {
		$VALUE = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'});
		}

	if (not defined $VALUE) {
		$VALUE = $iniref->{'DEFAULT'};
		}	
	
	if ($VALUE ne '') {
		$VALUE = ((defined $iniref->{'PRETEXT'})?$iniref->{'PRETEXT'}:'').$VALUE.((defined $iniref->{'POSTTEXT'})?$iniref->{'POSTTEXT'}:'');
		}

	return($VALUE);
	}


##
## NOTE: at somepoint this could probably be merged with tristate
##
sub RENDER_IF {
	my ($iniref,$toxml,$SITE) = @_;

	my $OPERATION = uc($iniref->{'OPERATION'});
	my $TRUE = $iniref->{'TRUE'};
	my $FALSE = $iniref->{'FALSE'};
	my $UNDEF = $iniref->{'UNDEF'};
	my $VALUE = def(&TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'}));

	if ($OPERATION eq 'NB') {
		## NB = Not Blank
		if ($VALUE ne '') { $VALUE = $TRUE; } else { $VALUE = $FALSE; }
		}	
	elsif ($OPERATION eq 'TFU') {
		## TFU = True / False / Undefined
		if ($VALUE eq '') {
			## Undefined
			$VALUE = $UNDEF;
			}
		elsif ($VALUE eq '0') {
			## False
			$VALUE = $FALSE;
			}
		else {
			## True
			$VALUE = $TRUE;
			}
		}
	elsif ($OPERATION eq 'GTZ') {	
		$VALUE = ($VALUE>0)?$iniref->{'TRUE'}:$iniref->{'FALSE'};
		}
	elsif ($OPERATION eq 'LEZ') {	
		$VALUE = ($VALUE<=0)?$iniref->{'TRUE'}:$iniref->{'FALSE'};
		}

	if ($VALUE ne '') {
		$VALUE = ((defined $iniref->{'PRETEXT'})?$iniref->{'PRETEXT'}:'').$VALUE.((defined $iniref->{'POSTTEXT'})?$iniref->{'POSTTEXT'}:'');
		}

	return($VALUE);
	}

##
##
##
##
##
sub TURBOMENU {
	my ($iniref,undef,$SITE) = @_;

	my $USERNAME = $SITE->username();
	if (ref($SITE) eq 'SITE') {
		$SITE->txspecl();		## populate *TXSPECL
		$USERNAME = $SITE->username();
		}

	if (not defined $SITE->txspecl()) { Carp::confess("TURBOMENU needs reference to *TXSPECL"); }
	
	my $out = '';
	## first things first, make sure we're working with uppercase variables.
	foreach my $k (keys %{$iniref}) {
		next if (uc($k) eq $k);
		$iniref->{uc($k)} = $iniref->{$k};
		delete $iniref->{$k};
		}

	# print STDERR Dumper($iniref);
	# if (not defined $SITE::SREF->{'_CWPATH'}) { $SITE::SREF->{'_CWPATH'} = '.'.$SITE->pageid(); }
 
	my $TURBOMENU = 0;
	if ($iniref->{'TYPE'} eq 'TURBOMENU') {
		$TURBOMENU++;
		$iniref->{'TYPE'} = $iniref->{'FORMAT'};
		}
	
	## now figure out what type
	## 	valid types are BREADCRUMB, SUBCAT, MENU
	my $TYPE = undef;
	if ($iniref->{'TYPE'} eq 'BREADCRUMB') {
		$TYPE = 'BREADCRUMB';
		}
	elsif ($iniref->{'TYPE'} eq 'SUBCAT') {
		$TYPE = 'SUBCAT';
		}
	elsif ($iniref->{'TYPE'} eq 'MENU') {
		$TYPE = 'MENU';
		}
	elsif ($iniref->{'TYPE'} eq 'PRODCATS') {
		## a list of categories that the current product in focus is in.
		## supports- MODE: PLAIN|LIST
		$TYPE = 'PRODCATS';		# becomes SUBCAT a little later
		}
	elsif ($iniref->{'TYPE'} eq 'CARTPRODCATS') {
#		who_uses_this('CARTPRODCATS',$iniref);
		$TYPE = 'CARTPRODCATS';
		}
	else {
		warn "Unknown TURBOMENU type of $iniref->{'TYPE'}";
		}
 

	## go get the data.
	my ($CATPATHS,$CATNAMES) = ();
	my ($NC) = &SITE::get_navcats($SITE);

	## NOTE: 
	##		CATPATHS is an arrayref of subcategory paths (safename)
	##		CATNAMES is a hashref keyed by safename, value is text
	##		CATMETA is a hashref keyed by safename, value is text
	if ($TYPE eq 'MENU') {
		# ($CATPATHS,$CATNAMES,$CATMETA) = &NAVCAT::fetch_children_names($USERNAME, $SITE::SREF->{'_ROOTCAT'});
		
		($CATPATHS,$CATNAMES) = $NC->build_turbomenu($SITE->rootcat());
		if (not defined $CATPATHS) { $CATPATHS = []; }
		unshift @{$CATPATHS}, '.';
		$CATNAMES->{'.'} = 'Home';

		 #print STDERR 'CATPATHS:'.Dumper($SITE::SREF->{'_ROOTCAT'},$CATPATHS,[caller(0)]);
		}
	elsif (($TYPE eq 'SUBCAT') && ($iniref->{'PRODCAT'}) && (defined $SITE->pid())) {
		# my @subcats = sort &NAVCAT::product_categories($USERNAME, $SITE->{'_PID'}, 0);
		my $ref = $NC->paths_by_product($SITE->{'_PID'},lists=>0,root=>$SITE->rootcat());
		my @subcats = ();
		if (defined $ref) { @subcats = sort @{$ref}; }

		$CATPATHS = \@subcats;
		# $CATNAMES = &NAVCAT::resolve_safenames($USERNAME, \@subcats);
		$CATNAMES = {};
		foreach my $safe (@subcats) {
			if ($safe eq '.') { 
				$CATNAMES->{'.'} = 'Home'; 
				}
			else { 
				($CATNAMES->{$safe}) = $NC->get($safe);
				}
			}

		$iniref->{'NOROOT'} = 0;		## Ignore NOROOT in this situation
		}	
	elsif ($TYPE eq 'SUBCAT') {
		# my $SRC = $SITE::SREF->{'_CWPATH'};
		my $SRC = $SITE->servicepath()->[1];
		if (defined $iniref->{'SRC'}) { 
			if ($iniref->{'SRC'} =~ /^navcat\:(.*?)$/i) { $iniref->{'SRC'} = $1; }	# remove stupid navcat: for JT to avoid simple mistakes
			$SRC = $iniref->{'SRC'};
			}		
		if (substr($SRC,0,1) ne '.') { $SRC = '.'.$SRC; }	# add leading period if we need it. (not sure if this is necssary)
		if ((defined $SITE->rootcat()) && ($SRC eq '.') && ($SITE->rootcat() ne '.')) { $SRC = $SITE->rootcat(); }

		($CATPATHS,$CATNAMES) = $NC->build_turbomenu($SRC);

		##
		## okay so DESCENDTREE -- how it works.
		## if you're on a subcategory and that has no children
		## 	then you should move up the tree one time
		##
		if ($SRC eq '.') {}
		elsif (($iniref->{'DESCENDTREE'}) && (scalar(@{$CATPATHS}) == 0)) {
			## if we have no categories, then go up the tree
			my $newpath = $SRC;
			$newpath = substr($newpath, 0, rindex($newpath, '.'));
			# ($CATPATHS, $CATNAMES, $CATMETA) = &NAVCAT::fetch_children_names($USERNAME, $newpath);
			($CATPATHS,$CATNAMES) = $NC->build_turbomenu($newpath);
			}
		undef $SRC;


#		print "Content-type: text/plain\n\n";
#		print Dumper($CATPATHS,$CATNAMES;
#		die();

#	if (not scalar(@{$CATPATHS})) {
#		die();
#		}

		}
	elsif ($TYPE eq 'BREADCRUMB') {
		# ($CATPATHS,$CATNAMES,$CATMETA) = &NAVCAT::path_breadcrumb($USERNAME, $SITE::SREF->{'_CWPATH'});
		if ($iniref->{'PATH'} eq '') { $iniref->{'PATH'} = $SITE->servicepath()->[1]; }
		($CATPATHS,$CATNAMES) = $NC->breadcrumb($iniref->{'PATH'},$iniref->{'SKIPHIDDEN'});
		unshift @{$CATPATHS}, '.';
		$CATNAMES->{'.'} = 'Home';
		if (not defined $iniref->{'MODE'}) {
			$iniref->{'MODE'} = 'LIST';
			}
		}
	elsif ($TYPE eq 'PRODCATS') {
		## supports two modes: PLAIN and LIST
		##		note: PLAIN is upgraded to LIST
		my @safepaths = ();
		my $ref = $NC->paths_by_product($SITE->{'_PID'},lists=>0,root=>$SITE->rootcat());
		if ((defined $ref) && (ref($ref) eq 'ARRAY')) {
			@safepaths = sort @{$ref};
			}
		# my ($CATPATHS,$CATNAMES,$CATMETA) = &NAVCAT::fetch_children_names($USERNAME, undef, $iniref, \@safepaths);
		($CATPATHS,$CATNAMES) = $NC->build_turbomenu(undef,$iniref,\@safepaths);
		undef @safepaths;

		if (($iniref->{'MODE'} eq '') || ($iniref->{'MODE'} eq 'PLAIN')) {
			$iniref->{'MODE'} = 'LIST';
			$iniref->{'HTML'} = q~<!-- CATEGORY --><a href="<% load($cat_url);  print(); %>" class="subcat"><% load($cat_pretty);  print(); %></a><br><!-- /CATEGORY -->~;
			}
		$TYPE = 'SUBCAT';	### note: this becomes SUBCAT since all the logic is the same.
		}
	elsif ($TYPE eq 'CARTPRODCATS') {
		my %categories   = ();                             # using a hash to easily avoid duplicates
		foreach my $item (@{$SITE::CART2->stuff2()->items()}) {
			#my ($pid) = &PRODUCT::stid_to_pid($stid);
			#foreach my $category (&NAVCAT::product_categories($USERNAME, $pid)) {
			my $pid = $item->{'product'};
			foreach my $category ( @{$NC->paths_by_product($pid)} ) {
				$categories{$category}++;
				}
			}

		my @safepaths = sort keys %categories;
		$CATPATHS = \@safepaths;
		if (($iniref->{'MODE'} eq '') || ($iniref->{'MODE'} eq 'PLAIN')) {
			## the default "plain" style.	
			$iniref->{'MODE'} = 'LIST';
			$iniref->{'HTML'} = q~<!-- CATEGORY --><a href="<% load($cat_url);  print(); %>" class="subcat"><% load($cat_pretty);  print(); %></a><br><!-- /CATEGORY -->~;

			foreach my $safename (sort keys %categories) {
				if ($safename eq '.') { $CATNAMES->{$safename} = 'Home'; }
				else {
					my $line = '';
					my $hidden = 0;
					# build hyperlink breadcrumb regular old navcat's
					# my ($path_order, $path_names) = &NAVCAT::path_breadcrumb($USERNAME, $safename, 0);
					my ($path_order, $path_names) = $NC->breadcrumb($safename,$iniref->{'SKIPHIDDEN'});
					foreach my $path (@{$path_order}) {
						my $name = $path_names->{$path};
						$CATNAMES->{$safename} .= '/'.$name;
						}
					if (not $hidden) { $out .= "$line<br>\n"; }
					}
				} ## end foreach my $safename (sort keys...
			}
		$TYPE = 'SUBCAT';
		}


	
	if ($SITE::OVERRIDES{'dev.no_categories'}>0) {
		## no categories at all (probably a shopping cart only)
		$CATPATHS = [];
		}
	elsif (($TYPE eq 'SUBCAT') && ($SITE::OVERRIDES{'dev.no_subcategories'})) {
		if ($iniref->{'_FORMAT'} eq 'LAYOUT') { 
			## if we have developer, and no_subcategories then stop here.
			## NOTE: this *ONLY* applies to subcat elements running under _FORMAT 'LAYOUT"
			$CATPATHS = []; 
			}
		}

	if (
		(&ZOOVY::is_true($iniref->{'NO_HOME'}, 0)) || 
		(&ZOOVY::is_true($iniref->{'NOHOME'}, 0)) ||
		( $SITE::OVERRIDES{'dev.no_home'} )
		) {
		## do not include home in list of categories.
		my @NEW = ();
		foreach my $safe (@{$CATPATHS}) {
			next if (($safe eq '.') || ($safe eq ''));
			push @NEW, $safe;
			}		
		undef $CATPATHS;
		$CATPATHS = \@NEW;
		}

	if (&ZOOVY::is_true($iniref->{'NOROOT'})) {
		## do not include "root level" categories or '.'
		## commonly used with DESCENDTREE
		my @NEW = ();
		foreach my $safe (@{$CATPATHS}) {
			next if ($safe =~ /^\.[A-Za-z0-9\_\-]+$/o);
			next if ($safe eq '.');		
			push @NEW, $safe;
			}
		undef $CATPATHS;
		$CATPATHS = \@NEW;
		# print STDERR Dumper($CATPATHS);
		}
	
	## 
	## at this point we should have the data.
	##		formats the list of categories and builds @CATURLS, @CATPRETTY (see below)
	##
	my @CATPRETTY = ();	# an array (sorted in order) of pretty names
	my @CATURLS = ();		# an array (sorted in order) of urls
	if (1) {
		my $category_url = $SITE->URLENGINE()->get('category');
		my @NEW = ();
		foreach my $safe (@{$CATPATHS}) {
			next if (substr($CATNAMES->{$safe},0,1) eq '!');	# never show hidden categories.
			push @NEW, $safe;
			push @CATPRETTY, $CATNAMES->{$safe};
			my $caturl = $safe;
			if ($caturl eq '.') {
				push @CATURLS, $SITE->URLENGINE()->get('home');
				}
			else {
				if (substr($caturl,0,1) eq '.') { $caturl = substr($caturl,1); } # strip leading . from safename
				push @CATURLS, "$category_url/$caturl/";
				}
			undef $caturl;
			}
		$CATPATHS = \@NEW;
		undef $category_url;
		}


	##
	## SANITY: at this point the following variables are set as such:
	##		$CATPATHS = an arrayref of safenames (sequenced in order)
	##		@CATPRETTY = an array of pretyt names (seqquenced in order)
	##		@CATURLS = an array of fully qualified urls to a specific category
	##

	## the subcat element supports three distinct modes of operation 
	##		LIST -
	##		PLAIN - is a generic text list
	##		BUTTONS - loads a sitebutton.ini and runs it.
	my $category_url = $SITE->URLENGINE()->get('category_url');
	if ($iniref->{'HTML'} eq '') {
		## default if no spec was set
		$iniref->{'HTML'} = q~<!-- CATEGORY --><div class='ztable_row'><a href='<% print($cat_url); %>' class='zlink'><% print($cat_pretty); %></a></div><!-- /CATEGORY -->~;
		}
	
	if (not defined $CATNAMES) { $out = ''; }
	## $SUBCATS is an arrayref of safenames (sorted)
	##	$SUBCATNAMES is a hashref keyed by safename, value is the pretty name
	##	$SUBCATMETA is a hashref keyed by safename, value is the meta of a category

	my @lookup = ();
	my $button_info = [];
	my $hasbuttons = ((not defined $iniref->{'BUTTONTYPE'}) || ($iniref->{'BUTTONTYPE'} eq ''))?0:1;
	if ($hasbuttons) {
		require NAVBUTTON;
		$button_info = &NAVBUTTON::cached_button_info($USERNAME, $iniref->{'BUTTONTYPE'}, $iniref->{'WIDTH'}, $iniref->{'HEIGHT'}, \@CATPRETTY);
		}

	if (scalar @{$CATPATHS}) {
		my $rownum = 0;
		my @items = ();
		foreach my $thiscat (@{$CATPATHS}) {
			$rownum++;
			$TOXML::RENDER::DEBUG && &msg("thiscat: $thiscat");
			next unless defined($thiscat);
			my $pretty = '';
			
			if (defined $CATNAMES->{$thiscat}) {
				# $pretty = &CGI::escapeHTML($CATNAMES->{$thiscat});
				$pretty = &ZOOVY::incode($CATNAMES->{$thiscat});
				}
			next if ($pretty =~ m/^\!/); ## Skip displaying hidden categories
			my %info = ();

			my (undef,undef,undef,undef,$metaref) = $NC->get($thiscat);
			if ((not defined $metaref) || (ref($metaref) ne 'HASH')) { $metaref = {}; }
			$info{'cat_thumb'}   = $metaref->{'CAT_THUMB'};
			$info{'cat_desc'}	  = $metaref->{'CAT_DESC'};

			$thiscat =~ s/^\.//; # Remove the leading dot

			$info{'cat_url'}    = "$category_url/$thiscat/";
			$info{'cat_pretty'} = $pretty;
			$info{'cat_safe'}   = $thiscat;
			$info{'cat_num'}    = $rownum;	
			# $info{'cat_itemcount'} = 

			if ($hasbuttons) {
				$info{'button_width'} = $button_info->[($rownum-1)]->[0]->{'width'};
				$info{'button_height'} = $button_info->[($rownum-1)]->[0]->{'height'};

				my $src;
				$src = $SITE->URLENGINE()->get('navbutton') . '/'; 
				$src .= $iniref->{'BUTTONTYPE'};
				if ($info{'button_width'})  { $src .= '_w' . $info{'button_width'}; }
				if ($info{'button_height'}) { $src .= '_h' . $info{'button_height'}; }
				$src .= '/'; 
				my $temp = $info{'cat_pretty'};
				$temp =~ s/\s/__/gs;
				$temp =~ s/(\W)/'_'.uc(sprintf('%1x',ord($1)))/egs;
				$src .= $temp . '.gif';
				$info{'button_imgsrc'} = $src;
				} ## end if ($buttons)		

			push @items, \%info;
			}
			
		my $alternate = ();
	
		if (not defined $iniref->{'FORCECOLUMNS'}) { $iniref->{'FORCECOLUMNS'} = 1; }
		$TOXML::RENDER::DEBUG && &msg("FORCECOLUMNS: $iniref->{'FORCECOLUMNS'}");
		$out =  $SITE->txspecl()->process_list(
			'id'=>$iniref->{'ID'},
			'spec'            => $iniref->{'HTML'},
			'items'           => [@items],
			'lookup'          => [@lookup],
			'item_tag'        => 'CATEGORY',
			'alternate'       => $alternate,
			'cols'            => $iniref->{'FORCECOLUMNS'},
			);
		}

	## handle pre and post text
	if (length($out)>0) {
		if (not defined $iniref->{'PRETEXT'}) { $iniref->{'PRETEXT'} = ''; }
		if (not defined $iniref->{'POSTTEXT'}) { $iniref->{'POSTTEXT'} = ''; }
		$out = $iniref->{'PRETEXT'}.$out.$iniref->{'POSTTEXT'};
		}
	else {
		if (not defined $iniref->{'DEFAULT'}) { $iniref->{'DEFAULT'} = ''; }
		$out = $iniref->{'DEFAULT'};
		}

	undef $NC;
	undef $CATPATHS;
	undef $CATNAMES;
	# undef $CATMETA;
	undef @CATPRETTY;
	undef @CATURLS;
	return($out);
	}







##
## allows us to execute a function at runtime.
##
sub RENDER_EXEC {
	my ($iniref,$toxml,$SITE,$dref) = @_;

	if (defined $iniref->{'FUNCTION'}) {
		if ($iniref->{'FUNCTION'} eq 'RUN_ADDTOCART') { $iniref->{'FUNC'} = \&PAGE::cart::handler; }
		if ($iniref->{'FUNCTION'} eq 'RUN_ADDTOSITE') { $iniref->{'FUNC'} = \&PAGE::HANDLER::add_to_site_handler; }
		if ($iniref->{'FUNCTION'} eq 'RUN_SUBSCRIBE') { $iniref->{'FUNC'} = \&PAGE::HANDLER::subscribe_handler; }
		if ($iniref->{'FUNCTION'} eq 'RUN_CONTACT') { $iniref->{'FUNC'} = \&PAGE::HANDLER::contact_handler; }
		if ($iniref->{'FUNCTION'} eq 'RUN_SEARCH') { $iniref->{'FUNC'} = \&PAGE::HANDLER::search_handler; }
		if ($iniref->{'FUNCTION'} eq 'RUN_LOGOUT') { $iniref->{'FUNC'} = \&PAGE::HANDLER::logout_handler; }
		if ($iniref->{'FUNCTION'} eq 'RUN_LOGIN') { $iniref->{'FUNC'} = \&PAGE::HANDLER::login_handler; }
		if ($iniref->{'FUNCTION'} eq 'RUN_POPUP') { $iniref->{'FUNC'} = \&PAGE::HANDLER::popup_handler; }
		# if ($iniref->{'FUNCTION'} eq 'SITE_LAST_LOGIN') { $iniref->{'FUNC'} = &SITE::last_login; }
		}


	if (defined $iniref->{'FUNC'}) {
		warn "FUNCTION:$iniref->{'FUNCTION'}\n";
		$iniref->{'FUNC'}->($iniref,$toxml,$SITE,$dref);
		}
	}




sub SITE_FOOTER {
	my ($iniref,undef,$SITE) = @_;

	my $webdb = $SITE->webdb();
	my $branding  = &ZTOOLKIT::def($webdb->{'branding'},    0);
	my $spec = '';
	my %vars = ();

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
	$vars{'year'} = $year+1900;

	$vars{'privacy_url'} = $SITE->URLENGINE()->get('privacy_url');
	$vars{'returns_url'} = $SITE->URLENGINE()->get('returns_url');
	# $vars{'about_zoovy_url'} = $SITE->URLENGINE()->get('about_zoovy_url');
	$vars{'about_zoovy_url'} = "https://www.zoovy.com/";

	$vars{'buysafe_seal_html'} = '';
   if ((defined $webdb->{'buysafe_mode'}) && ($webdb->{'buysafe_mode'}>0)) {
		my $token = $webdb->{'buysafe_token'};

		$token = URI::Escape::XS::uri_escape($token);
		$vars{'buysafe_seal_html'} = qq~<span id="BuySafeSealFooter">
<!-- buysafe_mode=$webdb->{'buysafe_mode'} -->
<script type="text/javascript">WriteBuySafeSeal( 'BuySafeSealFooter', 'Small', 'HASH=$token' );</script>
</span>
~;
		}

	$vars{'zoovy_footer_html'} = '';
	if ($branding < 3) {
		$vars{'zoovy_footer_html'} = q~<br><a target="_blank" href="<% load($about_zoovy_url);  print(); %>" style="text-decoration: none;"><font color="<% load($disclaimer_text_color);  print(); %>">E-Commerce solution</font></a> provided by <a href="<% load($about_zoovy_url);  print(); %>"><font color="<% load($disclaimer_text_color);  print(); %>">Zoovy</font></a>.~;
		}
	elsif ($branding < 7) {
		$vars{'zoovy_footer_html'} = q~<br><a target="_blank" href="<% load($about_zoovy_url);  print(); %>" style="text-decoration: none;"><font color="<% load($disclaimer_text_color);  print(); %>">E-Commerce solution</font></a> provided by <a href="<% load($about_zoovy_url);  print(); %>" style="text-decoration: none;"><font color="<% load($disclaimer_text_color);  print(); %>">Zoovy</font></a>.~;
		}
	else {
		$vars{'zoovy_footer_html'} = '<!-- web site generated by zoovy -->';
		}

	if ((defined $iniref->{'HTML'}) && ($iniref->{'HTML'} ne '')) {
		$spec = $iniref->{'HTML'};
		}
	else {

		$spec = qq~<table border="0" cellpadding="1"><tr>
<td class="zsmall" valign='top'>
Copyright &reg; <% load(\$year);  print(); %>.  Please read our <a href="<% load(\$privacy_url);  print(); %>">
<font color="<% loadurp("CSS::zsmall.color"); print(); %>">Privacy</font></a>
and 
<a href="<% load(\$returns_url);  print(); %>"><font color="<% loadurp("CSS::zsmall.color");  print(); %>">Returns</font></a> Policies.&nbsp;
<% load(\$buysafe_html); print(); %>
<% load(\$zoovy_footer_html); print(); %>
</td>
<td valign='top' style="padding-left:4px;"><% load(\$buysafe_seal_html); print(); %>
</td></tr>
</table>~;
		}

	$vars{'zoovy_footer_html'} = $SITE->txspecl()->translate3($vars{'zoovy_footer_html'},[\%vars,$iniref,$SITE::CONFIG->{'%THEME'}]);
	$vars{'buysafe_seal_html'} =$SITE->txspecl()->translate3($vars{'buysafe_seal_html'},[\%vars,$iniref,$SITE::CONFIG->{'%THEME'}]);

	my $nsref = $SITE->nsref();
	if ($nsref->{'omniture:enable'}>0) {
		$spec .= "<!-- begin omniture_footer -->".$nsref->{'omniture:footerjs'}."<!-- end omniture_footer -->";
		}
	if ($nsref->{'livechat:tracking'} ne '') {
		$spec .= "<!-- begin livechat_footer -->".$nsref->{'livechat:tracking'}."<!-- end livechat_footer -->";
		}
	if ($nsref->{'plugin:footerjs'}) {
		## Generic Plugin
		$spec .= "<!-- begin plugin_footer -->".$nsref->{'plugin:footerjs'}."<!-- end plugin_footer -->";
		}


	if ($nsref->{'fetchback:footerjs'}) {
#	NOTE: chkoutjs is for conversion code at the end of checkout, not for the footer!
#		if($SITE::SREF->{'+secure'})	{
#         $spec .= "<!-- begin fetchback_checkout_footer -->".$nsref->{'fetchback:chkoutjs'}."<!-- end fetchback_checkout_footer -->";
#			}
#		else	{
			$spec .= "<!-- begin fetchback_footer -->".$nsref->{'fetchback:footerjs'}."<!-- end fetchback_footer -->";
#			}
		}
	if ($nsref->{'upsellit:footerjs'}) {
		$spec .= "<!-- begin upsellit_footer -->".$nsref->{'upsellit:footerjs'}."<!-- end upsellit_footer -->";
		}

	if ($webdb->{'google_api_analytics'}) {
		my ($protocol) = ($SITE->_is_secure())?'https':'http';
		$spec .= qq~<script src="$protocol://checkout.google.com/files/digital/ga_post.js" type="text/javascript"></script>~;
		}
	
#	$webdb->{'amzpay_env'} = int($webdb->{'amzpay_env'});
#	if ($webdb->{'amzpay_env'}>0) {
#		my $widgeturl = 'https://images-na.ssl-images-amazon.com/images/G/01/cba/js/widget/widget.js';
#		if ($webdb->{'amzpay_env'}==1) {
#			$widgeturl = 'https://images-na.ssl-images-amazon.com/images/G/01/cba/js/widget/sandbox/widget.js';
#			}
#		$spec .= qq~<!-- begin amazon_footer -->
#<script type="text/javascript" src="https://images-na.ssl-images-amazon.com/images/G/01/cba/js/jquery.js"></script>
#<script type="text/javascript" src="$widgeturl"></script>
#<!-- end amazon_footer -->
#~;
#		}


	my $out = $SITE->txspecl()->translate3($spec,[\%vars,$iniref,$SITE::CONFIG->{'%THEME'}]);


	# print STDERR "OUT: $out\n";

	return($out);	
	}


##
##
##
sub SITE_SIDEBAR {
	my ($iniref,$toxml,$SITE) = @_;

	if (ref($SITE) ne 'SITE') {
		warn Carp::confess("SITE_SIDEBAR requires SREF to do it's thing");
		}

	#my $NSREF = {};
	#if (not defined $SITE::SREF->{'%NSREF'}) {
	#	my ($ref) = &ZOOVY::fetchmerchantns_ref($SITE::merchant_id,$SITE::REF->{'_NS'},$SITE::SREF->{'+cache'});
	#	$SITE::SREF->{'%NSREF'} = $ref;
	#	}
	#$NSREF = $SITE::SREF->{'%NSREF'};
	#if (not defined $NSREF) { $NSREF = {}; }

	my @lines = ();
	if (not defined $iniref->{'DATA'}) {
		## doesn't have a DATA setting, so this is probably a legacy.. so we'll perform a few standard upgrades
		$iniref->{'SLOTS'} = 10;
		$iniref->{'DATA'} = "profile:zoovy:sidebar_logos";
		}
	@lines = split(/[\|\n]/,&TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'},$iniref->{'LOADFROM'}));


	# print STDERR "SIDEBAR! SECURE[$SITE::SREF->{'+secure'}]\n";

	## SANITY: at this point each individual line is it's own decal.
	## this code should be kept in sync with DECAL
	my $out = '<!-- SIDEBAR -->';

	foreach my $decalid (@lines) {
		
		my $decalhtml = &TOXML::RENDER::apply_decal($SITE,$decalid);
		if ($decalhtml !~ /%pre%/) {
			## if the decalhtml has pre/post text (meaning it's a stacked decal) then don't add them again.
			$decalhtml = "%pre%$decalhtml%post%";
			}
		$out .= $decalhtml;
		}

	#if ((not $SITE::SREF->{'+secure'}) || ($SITE::SREF->{'+secure'} && $NSREF->{'zoovy:sidebar_issecure'})) {
	#	$out = def($NSREF->{'zoovy:sidebar_html'});
	#	}
			
	## unless we are secure, and we have the logo enabled.
#	if ( ($SITE::SREF->{'+secure'}) && (defined $webdb->{'sidebar_showssl'}) && ($webdb->{'sidebar_showssl'})) {
#		if ($webdb->{'branding'} == 0) {
#			$out = qq~<center><script src="https://siteseal.thawte.com/cgi/server/thawte_seal_generator.exe"></script></center>~;
#			}
#		}

	if ($SITE->_is_secure()) {
		## DISPLAY SECURE GRAPHICS.
		# my $out = '';

		#if ((defined $NSREF->{'zoovy:sidebar_showssl'}) && ($NSREF->{'zoovy:sidebar_showssl'})) {
		#	if ($webdb->{'branding'} == 0) {
		#		}
		#	## end sidebar_showssl
		#	}

		if ((defined $SITE->globalref()->{'%kount'}) && ($SITE->globalref()->{'%kount'}->{'enable'})) {
			## kount fraud screen will show up on sidebar.
			require PLUGIN::KOUNT;
			my ($pk) = PLUGIN::KOUNT->new($SITE->username(),prt=>$SITE->prt(),webdb=>$SITE->webdb());
			# print STDERR "PK: $pk\n";
			if (defined $pk) {
				$out .= "%pre%\n<!-- KOUNT START --><center>\n".(($pk->is_live()==2)?'KOUNT-TEST':'').$pk->kaptcha($SITE::CART2->cartid(),$SITE->sdomain())."\n</center><!-- END KOUNT -->\n%post%";
				}
			}
		}

	if (not defined $iniref->{'PRETEXT'}) {
		$out = "<center><table cellpadding='0' cellspacing='0' border='0'><tr><td><center>".$out;	
		}
	else {
		$out = $iniref->{'PRETEXT'}.$out;
		}
	
	if (not defined $iniref->{'LINEPRETEXT'}) { $iniref->{'LINEPRETEXT'} =	''; }
	if (not defined $iniref->{'LINEPOSTTEXT'}) { $iniref->{'LINEPOSTTEXT'} = ''; }
	
	$out =~ s/%sdomain%/$SITE->sdomain()/gos;
	$out =~ s/%pre%/$iniref->{'LINEPRETEXT'}/gos;
	$out =~ s/%post%/$iniref->{'LINEPOSTTEXT'}/gos;

	if (not defined $iniref->{'POSTTEXT'}) {
		$out .= "</center></td></tr></table></center>";
		}
	else {
		$out .= $iniref->{'POSTTEXT'};
		}


	return($out);
	}








sub SITE_LOGO {
	my ($iniref,$toxml,$SITE) = @_;
	my $logo_image = '';

	#	my ($package,$file,$line,$sub,$args) = caller(0);
	#use Data::Dumper; print STDERR Dumper($SITE,$package,$file,$line,$sub,$args);

	my $USERNAME = $SITE->username();
	
	## this is the LOGO election process

	my $found = 0;
	if (!$found) {
		## first check speciality site logo
		$logo_image = $SITE->{'_LOGO'};
		if ($logo_image ne '') { $found++; }
		}

	if (!$found) {
		$logo_image = &TOXML::RENDER::smart_load($SITE,'profile:zoovy:logo_website');
		if ($logo_image ne '') { $found++; }
		}

	## removed 7/7/09
	#if (!$found) {
	#	## storing the logo in the webdb is deprecated and will EVENTUALLY be removed.
	#	$webdb = $SITE->webdb();
	#	$logo_image = $SITE::webdbref->{'company_logo'};
	#	if ($logo_image ne '') { $found++; }
	#	}
	if (!$found) {
		$logo_image = &TOXML::RENDER::smart_load($SITE,'profile:zoovy:company_logo');
		}
			
	my $imgtag_src    = ''; my $imgtag_width  = ''; my $imgtag_height = '';
	if ($logo_image eq '') {
		$imgtag_src = $SITE->URLENGINE()->get('graphics') . "/blank.gif";
		if (def($iniref->{'WIDTH'})) { $imgtag_width = qq~ width="$iniref->{'WIDTH'}"~; }
		else { $imgtag_width = qq~ width="1"~; }
		if (def($iniref->{'HEIGHT'})) { $imgtag_height = qq~ height="$iniref->{'HEIGHT'}"~; }
		else { $imgtag_height = qq~ height="1"~; }
		}
	elsif ($logo_image =~ m/^[Hh][Tt][Tt][Pp][Ss]?\:\/\//) {
		$imgtag_src = $logo_image;
		if (def($iniref->{'WIDTH'}))  { $imgtag_width  = qq~ width="$iniref->{'WIDTH'}"~; }
		if (def($iniref->{'HEIGHT'})) { $imgtag_height = qq~ height="$iniref->{'HEIGHT'}"~; }
		}
	else {
		my $flags = '';
		
		my $bgcolor = undef;
		if ((defined $iniref->{'BGCOLOR'}) && ($iniref->{'BGCOLOR'} ne '')) { 
			$bgcolor = lc($iniref->{'BGCOLOR'}); 
			if (substr($bgcolor,0,1) eq '#') { $bgcolor = substr($bgcolor,1); } # strip leading # in #ABCDEF
			$flags .= "B$bgcolor-"; 
			}
		# $bgcolor =~ s/[^a-f0-9]//gis;
		# if (length($bgcolor) != 6) { $bgcolor = ''; }
				
		my $ext = '';
		my $minimal_mode = &ZOOVY::is_true($iniref->{'MINIMAL_MODE'}, 0);
		if ($minimal_mode) { 
			$flags .= 'M-'; 
			}
		elsif ($bgcolor eq 'tttttt') {
			$ext = '.png';
			}
		elsif (not defined $bgcolor) { 
			$ext = '.gif'; 
			}    
		# Default to GIF if we're in "max mode" so it's transparent
				
		#my $scale = &def($SITE::webdbref->{'logo_scale'}, 1);
		#if ($scale eq '') { $scale = 1; }
		my $width  = def($iniref->{'WIDTH'});
		my $height = def($iniref->{'HEIGHT'});
		#if ($scale) {

		## REMOVED FROM THE SETUP 1/28/13
		my $pixmode = &TOXML::RENDER::smart_load($SITE,'profile:zoovy:logo_website_pixelmode');
#		if (not defined $pixmode) { $pixmode = def($SITE::webdbref->{'logo_pixelmode'}, 1); }
		if ($pixmode) { $flags .= 'P-'; }
		if ($minimal_mode) { 
			($width, $height) = &ZOOVY::image_minimal_size($USERNAME, $logo_image, $width, $height, $SITE->cache_ts());
			$width  = def($width);
			$height = def($height);
			}
		#	}
		#else {
		#	# scaling disabled means we are always in max-mode
		#	$flags .= 'C-';    # C is the crop (no-scale) flag
		#	}
				
		## Note: these are PREpending, so they are in reverse order. :)
		if ($height) { $flags = "H$height-$flags"; $imgtag_height = qq~ height="$height"~; }
		if ($width) { $flags = "W$width-$flags"; $imgtag_width = qq~ width="$width"~; }

		if ($flags eq '') { $flags = '-'; }    # We need at least a dash
		else { $flags =~ s/\-$//; }            # Strip off the trailing slash
				
		if (rindex($logo_image,'.')>=0) {
			## strip trailing extension (since it will be re-added)
			$logo_image = substr($logo_image,0,rindex($logo_image,'.'));
			}
		if (($ext ne '.jpg') && ($ext ne '.gif')) {
			$ext = '.png';
			}

		## $imgtag_src .= &IMGLIB::Lite::get_static_url($USERNAME,'img')."/$flags/$logo_image$ext";
		
		my $PROTOHOST = '';
		if (not defined $toxml) {
			$PROTOHOST = sprintf("https://%s",&ZOOVY::resolve_media_host($USERNAME));
			}
		elsif (($toxml->format() eq 'WIZARD') || ($toxml->format() eq 'NEWSLETTER') || ($toxml->format() eq 'EMAIL') || $SITE->_is_newsletter()) {
			$PROTOHOST = sprintf("https://%s",&ZOOVY::resolve_media_host($USERNAME));
			}
		$imgtag_src = "$PROTOHOST/media/img/$USERNAME/$flags/$logo_image$ext";	# LOGO
		} ## end else
			
	if (not defined $iniref->{'ALT'}) {
		$iniref->{'ALT'} = &TOXML::RENDER::smart_load($SITE,'profile:zoovy:company_name');
		}

	my $tag = qq~<img alt="$iniref->{'ALT'}" src="$imgtag_src" border="0"$imgtag_width$imgtag_height />~;
	return($tag);
	}



##
## simply outputs a raw block of HTML
##
sub RENDER_OUTPUT {
	my ($iniref) = @_;
	return($iniref->{'HTML'});
	}



###########################################################################
## imageurl
## handles imagelib/legacy conversion 
## parameters: USERNAME, variable, height, width, background, ssl
## 
#sub imageUrl {
#   my ($USERNAME, $var, $h, $w, $bg, $ext) = @_;
#
#   my $ssl = 0;
#   
#	# if we don't have an image, pass that along.
#	if (!defined($var)) { return undef; }	
#	if ($var eq '' || $var eq ' ') { return undef; } 
#	if (substr($var,0,1) eq '/') { $var = substr($var,1); }	# remove leading /
#
#	# check for legacy
#	if ($var !~ /^http/i) {
#		# is from imagelibrary
#		if (!defined($bg)) { $bg = "FFFFFF"; }
#		$bg = lc($bg);	# IMGLIB.pm formats these as lowercase (this way we don't have to symlink)
#
#		if ( (int($h)==0) && (int($w)==0) ) {
#			$var = &ZOOVY::resolve_media_host($USERNAME)."/media/img/$USERNAME/-/$var";
#			} 
#		else {
#			$var = &ZOOVY::resolve_media_host($USERNAME)."/media/img/$USERNAME/W$w-H$h-B$bg/$var";
#			}
#		
#		if ( (defined $ext) && ($ext ne '')) {
#			$var .= '.'.$ext;
#			}
#		}
#
#
#	if (defined($ssl) && $ssl)
#		{
#		$var =~ s/http\:/https\:/i;
#		} else {
#		$var =~ s/https\:/http\:/i;
#		}
#
#	return($var);
#	}
#
########################################
##
##	parameters:
##		HEIGHT
##		WIDTH
##		BUTTONINI = 
##		DATA=product:zoovy:prod_name
##		set alt tag to text
##
#sub RENDER_BUTTON {
#	my ($iniref,undef,$SITE) = @_;
#
#	require NAVBUTTON;
#
#	my $USERNAME = $SITE->username();
#
#	my $out = &TOXML::RENDER::RENDER_MENU($iniref);
#	print $out."\n";
#
#	return('');
#	}


########################################
##
sub RENDER_FINDER {
	my ($iniref,$TOXML,$SITE) = @_;

	my $USERNAME = $SITE->username();
	require POGS;
	# ?prompt=Make%20+%20Model&any=1&type=&sog=98&
	my $DATA = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'});
	my $out = '';

	if (not defined $iniref->{'SPEC_DEFAULT'}) {
		$iniref->{'SPEC_DEFAULT'} = q~<!-- simple select list -->
        <tr><td><% load($finderprompt);  print(); %></td></tr>
        <tr><td>
                <select name="<% load($id);  print(); %>">
                <!-- OPTIONS -->
                <option value=":<% load($id);  print(); %><% load($v);  print(); %>"><% load($prompt);  print(); %></option>
                <!-- /OPTIONS -->
                </select>
        </td></tr>
		~;

		};

	if (not defined $iniref->{'HTML'}) {
		$iniref->{'HTML'} = q~
		<% load($FORM);  print(); %>
        <table><% load($FINDERS);  print(); %></table>
        <input class="button" type="submit" value=" Find "></input>
		</form>
		~;
		}


	##
	## A finder is a set of lines, each one starting with a ? or \n
	##	each line contains a uri encoded set of key/values -- converted to paramsref (described below)
	my $count = 0;
	foreach my $line (split(/[\n\r\?]+/,$DATA)) {
		next if ($line eq '');
		$count++;
		my $paramsref = &ZTOOLKIT::parseparams($line);
		if (not defined $paramsref->{'cols'}) { $paramsref->{'cols'} = 1; }
		## paramsref should contain:
		##		prompt=the prompt to be displayed
		##		any=0|1 (include the any option)
		##		type= select|radio|default
		##		sog= which sog id to load
		# my ($xml) = &POGS::load_sog($USERNAME,$paramsref->{'sog'},'',$SITE->{'+cache'});
		# next if ($xml eq '');
		my ($sogref) = &POGS::load_sogref($USERNAME,$paramsref->{'sog'});
		next if (not defined $sogref);

		my $spec = $iniref->{'SPEC_DEFAULT'};
		if (defined $iniref->{'SPEC_'.$paramsref->{'spec'}}) { $spec = $iniref->{'SPEC_'.$paramsref->{'spec'}}; }
	
		# my ($pog) = POGS::text_to_struct($USERNAME,$xml,0,0);
		## BACKWARD COMPATIBILITY: we should have named the FINDER variable prompt as finderprompt 
		## (because prompt will likely get whalefucked by process_list later on)
		if ($paramsref->{'prompt'} ne '') { 
			$paramsref->{'finderprompt'} = $paramsref->{'prompt'}; 
			}
		if ($paramsref->{'finderprompt'} eq '') {
			## if they don't set a finder prompt, then use the option prompt
			$paramsref->{'finderprompt'} = $sogref->{'prompt'};
			}
		delete $paramsref->{'prompt'};		## stop screwing the $pog->{'prompt'} over

		my $options = $sogref->{'@options'};
		if ($paramsref->{'any'}) {
			## push an "ANY" value onto the finder.
			if (not defined $iniref->{"OPTION_ANY_STRING"}) { $iniref->{'OPTION_ANY_STRING'} = 'ANY'; }
			unshift @{$options}, { v=>"", prompt=>$iniref->{'OPTION_ANY_STRING'} };
			}

#		if ($iniref->{'JAVASCRIPT'} eq 'v1') {
#			$iniref->{'JAVASCRIPT'} = TOXML::RENDER::RENDER_JSON(
#				{ ID=>$iniref->{'ID'}, IN=>'pogs', OUT=>'v1', STID=>$STID, DATA=>$prod->{'zoovy:pogs'} },undef,$SITE
#				);
#			}
#		else {
			$out .= $SITE->txspecl()->process_list(
				'id'=>$iniref->{'ID'},
				spec=>$spec,
				items=>$sogref->{'@options'},
				lookup=>[$iniref,$sogref,$paramsref],
				cols=>$paramsref->{'cols'},
				item_tag=>'OPTIONS',	
				);		
#			}
		# $out .= $spec;
		# $out .= "<pre>".Dumper($pog)."</pre>";
		}

	if ($count>0) {
		my ($headref) = $SITE->txspecl()->initialize_rows(1);
		my $results_url = $SITE->URLENGINE()->get('results_url');
		$out = $SITE->txspecl()->translate3( $iniref->{'HTML'}, [ 
			{ 
			FORM=>qq~<form id="form!$iniref->{'ID'}" name="form!$iniref->{'ID'}" method="GET" action="$results_url">
			<input type="hidden" name="MODE" value="FINDER"></input>~,
			FINDERS=>$out,
			}, $headref, $iniref ]);
		}

	return($out);
	}


########################################
##
##	render config
##	
##		mainly used for email templates, allows us to override the SITE config element
##		NOTE: elements are processed from top to bottom, so the config element *MUST* be 
##		at the very very very top.
##
##		okay so if we see iniref->{'theme'} set then we assume it's a-okay, (already from SITE.pm) 
##			otherwise if we see $iniref->{'THEME'} then we assume it's an element and we lowercase
##			all the values .. since the !@#$%^ SITE.pm uses lowercase and FLOW.pm uses uppercase for
##			element types
##
sub RENDER_CONFIG {
	my ($iniref,$toxml) = @_;

	## CART SITEBUTTON THEME
	# print STDERR "THEME: [$iniref->{'THEME'}]\n";
	require TOXML::CSS;

	if (not defined $SITE::CONFIG) { $SITE::CONFIG = {}; }
	
	my $format = '';
	if (defined $toxml) { $format = $toxml->getFormat(); }
	# print STDERR "FORMAT: $format\n";
	if (($format eq 'WRAPPER') || ($format eq 'EMAIL')) {
		foreach my $k (keys %{$iniref}) { $SITE::CONFIG->{$k} = $iniref->{$k}; }

		if (defined $iniref->{'CSS'}) {
			## we don't need a default CSS set if we got CSS
			}
		elsif ((not defined $iniref->{'THEME'}) || ($iniref->{'THEME'} eq '')) {
			## defaults the legacy THEME and CSS
			$iniref->{'THEME'} = 'name=default&pretty_name=Default&content_background_color=FFFFFF&content_font_face=Arial, Helvetica&content_font_size=3&content_text_color=000000&table_heading_background_color=CCCCCC&table_heading_font_face=Arial, Helvetica&table_heading_font_size=3&table_heading_text_color=000000&table_listing_background_color=FFFFFF&table_listing_background_color_alternate=EEEEEE&table_listing_font_face=Arial, Helvetica&table_listing_font_size=3&table_listing_text_color=000000&link_text_color=000033&link_active_text_color=000066&link_visited_text_color=000000&alert_color=FF0000&disclaimer_background_color=999999&disclaimer_font_face=Arial, Helvetica&disclaimer_font_size=1&disclaimer_text_color=000000';
			$iniref->{'CSS'} = TOXML::CSS::iniref2css(&ZTOOLKIT::parseparams($iniref->{'THEME'}));
			}

		if ((not defined $iniref->{'SITEBUTTONS'}) || ($iniref->{'SITEBUTTONS'} eq '')) {
			$iniref->{'SITEBUTTONS'} = 'default=default|gif|0|0&add_to_cart=default|gif|108|28&back=default|gif|80|28&cancel=default|gif|64|28&checkout=default|gif|84|28&continue_shopping=default|gif|164|28&empty_cart=default|gif|100|28&forward=default|gif|76|28&update_cart=default|gif|108|28&add_to_site=default|gif|122|32';
			}
		}


	if ($format ne 'LAYOUT') {
		#if (not defined $iniref->{'CSS'}) {
		#	## if no CSS attribute was set, then use the THEME to create one.
		#	$iniref->{'CSS'} = TOXML::CSS::iniref2css(&ZTOOLKIT::parseparams($iniref->{'THEME'}));
		#	}

		if (not defined $iniref->{'%CSSVARS'}) {
			$iniref->{'%CSSVARS'} = &TOXML::CSS::css2cssvar($iniref->{'CSS'});
			}
		$SITE::CONFIG->{'%CSSVARS'} = $iniref->{'%CSSVARS'};

		## at this point if $iniref->{'THEME'} is set, it is guaranteed 
		if (not defined $iniref->{'THEME'}) {
			$SITE::CONFIG->{'%THEME'} = &TOXML::CSS::cssvar2iniref($iniref->{'%CSSVARS'});
			}
		elsif (defined $iniref->{'THEME'}) {	
			$SITE::CONFIG->{'%THEME'} = &ZTOOLKIT::parseparams($iniref->{'THEME'});
			}

		#print STDERR Dumper( $SITE::CONFIG->{'%CSSVARS'}  );
		}


	##
	## SITEBUTTONS
	##
	if (not defined $iniref->{'SITEBUTTONS'}) {} # no SITEBUTTONS attrib here (probably not a wrapper)
	elsif (index($iniref->{'SITEBUTTONS'},'|')<=0) {
		$/ = undef;
		open F, "</httpd/static/graphics/sitebuttons/$iniref->{'SITEBUTTONS'}/info.txt"; 
		$iniref->{'SITEBUTTONS'} = <F>; 
		close F;
		$/ = "\n";
		}


	if (not defined $iniref->{'SITEBUTTONS'}) {} ## no SITEBUTTONS attrib in here (probably not a wrapper)
	else {
		$SITE::CONFIG->{'%SITEBUTTONS'} = &ZTOOLKIT::parseparams($iniref->{'SITEBUTTONS'});
		}	

	## jt shzez we don't need this (i don't believe him) 4/7/09
	# $SITE::OVERRIDES{'site.css'} = 0;			# by default assume we don't have style sheets (backward compatible)
	if (defined $iniref->{'OVERLOAD'}) {
#		print STDERR "CONFIG OVERLOADS: $iniref->{'OVERLOAD'}\n";
		## you can define an OVERLOAD= in a config element, OR in an OVERLOAD element
		my $ref = &ZTOOLKIT::parseparams($iniref->{'OVERLOAD'});
		foreach my $k (keys %{$ref}) {
			$SITE::OVERRIDES{$k} = $ref->{$k};
			}

		## NONE AS OF 2012/10/09
		#if ($ref->{'webdb.customer_management'} ne '') {
		#	open F, ">>/tmp/customer_management_overrides";
		#	print F "$SITE::merchant_id	$SITE::SREF->{'+sdomain'}	$ref->{'webdb.customer_management'}\n";
		#	close F;
		#	}
		}

	##
	## initialize the cart (for persistence)
	##	

	return('');
	}




########################################
##
##	render script
##	
##		javascript interpreter.
##
sub RENDER_SCRIPT {
	my ($iniref) = @_;

	return("<!-- SCRIPT_ELEMENT_DISABLED -->");

#	if (&ZOOVY::host_operating_system() ne 'LINUX') {
#		warn "SCRIPT element not available on this OS\n";
#		return("<!-- SCRIPT elements not available on non-LINUX host system -->");
#		}
#	else {
#		$SITE::JSOUTPUT = '';
#		my ($context) = &SITE::init_jsruntime();
#
#		#	open F, ">>/tmp/js";
#		# print F "render_script\t$SITE::merchant_id\t$iniref->{'HTML'}\n";
#		#	close F;
#		my $rval = $context->eval($iniref->{'HTML'});
#
#		## NOTE: this is used by A LOT of clients, it will be hard to kill off.
#		## at least one - tikimaster seems to have dynamically written javascript
#		return($SITE::JSOUTPUT);
#		}

	}


########################################
# render textlist
			###############################################################
			## TEXT LIST CODE
			##
			# ex: <INPUT TYPE="TEXTLIST" PROMPT="Songs - Optional (shared - Detailed Description)" PRETEXT="<p><span class="subhead">Play List: </span><ol>"
			# 		POSTTEXT="</ol></p>" LINEPRETEXT="<li>" LINEPOSTTEXT="</li>" READONLY="1" NAME="product:zoovy:prod_tracklist">_</INPUT>
			###############################################################
sub RENDER_TEXTLIST {
	my ($iniref,undef,$SITE) = @_; # iniref is a reference to a hash of the element's contents as defined in the flow file

	my $val = def(&TOXML::RENDER::smart_load($SITE,$iniref->{'LOAD'}));
	my @lines = split /\s*\n\s*/, $val;

	my $out = '';
	foreach my $line (0..$#lines) {
		next if ($lines[$line] eq '');
		$out .= def($iniref->{'LINEPRETEXT'}).$lines[$line].def($iniref->{'LINEPOSTTEXT'});
		if ($line != $#lines) { $out .= def($iniref->{'LINEDIVIDER'}); }
		}

	if ($out ne '') {
		$out = def($iniref->{'PRETEXT'}).$out.def($iniref->{'POSTTEXT'});
		if (not defined $iniref->{'RAW'}) { $iniref->{'RAW'} = $SITE::OVERLOADS{'site.css'}; }

		if (not $iniref->{'RAW'}) {
			$out = qq~<font class="ztxt">$out</font>~;
			}
		}

	return $out;
	} ## end sub RENDER_TEXTLIST


########################################
# render selected
sub RENDER_SELECTED
{
	my ($iniref,undef,$SITE) = @_; # iniref is a reference to a hash of the element's contents as defined in the flow file

	my $val = def(&TOXML::RENDER::smart_load($SITE,$iniref->{'LOAD'}));

	my $list = def($iniref->{'SELECTLIST'});

	my $out = '';
	if ($list =~ m/^\!(\w+)\!(\w+)\!(\w+)$/)
	{
		require DEFINITION::LIST;
		my $hash = DEFINITION::LIST::load_list($3,$1,$2);
		$out = def($hash->{$val});
	}
	if ($out ne '')
	{
		$out = def($iniref->{'PRETEXT'}).$out.def($iniref->{'POSTTEXT'});
		if (not defined $iniref->{'RAW'}) { $iniref->{'RAW'} = $SITE::OVERLOADS{'site.css'}; }
		if (not $iniref->{'RAW'}) {
			$out = qq~<font class="ztxt">$out</font>~;
			}
	}

	return $out;

} ## end sub RENDER_SELECTED

########################################
# render tristate
sub RENDER_TRISTATE {
	my ($iniref,undef,$SITE) = @_;    # iniref is a reference to a hash of the element's contents as defined in the flow file

	my $val = def(&TOXML::RENDER::smart_load($SITE,$iniref->{'LOAD'}));
	if (not defined $val) { $val = ''; }
	elsif ($val eq '-') { $val = ''; }
	else { $val = substr(uc($val),0,1); }	# only keep the first character e.g. yes becomes Y

	my $out = '';
	if ($val eq '') { $out = def($iniref->{'UNDEF'}, '');    }
	elsif ($val eq '1' || $val eq 'Y' || $val eq 'T')  { $out = def($iniref->{'TRUE'},  'Yes'); }
	else { $out = def($iniref->{'FALSE'}, 'No');  }

	if ($out ne '') {
		$out = def($iniref->{'PRETEXT'}).$out.def($iniref->{'POSTTEXT'});
		if (not defined $iniref->{'RAW'}) { $iniref->{'RAW'} = $SITE::OVERLOADS{'site.css'}; }
		if (not $iniref->{'RAW'}) {
			$out = qq~<font class="ztxt">$out</font>~;
			}
		}

	return $out;
	} ## end sub RENDER_TRISTATE


########################################
sub RENDER_QTYPRICE {
	my ($iniref,undef,$SITE) = @_;


	if ((defined $iniref->{'DATA'}) && ($iniref->{'DATA'} eq 'product:zoovy:qty_price')) {
		## backward compatibility: okay, so we're pointing at the default data field
		## but arrgh -- why is it hardcoded! so we'll *fix* it.
		delete $iniref->{'DATA'};
		}

	if (not defined $iniref->{'DATA'}) { 
		$iniref->{'DATA'} = 'product:zoovy:qty_price';  
		
		my $schedule = $SITE::CART2->in_get('our/schedule');
		if ($schedule ne '') {
			$iniref->{'DATA'} = sprintf("product:zoovy:qtyprice_%s",$schedule);
			}
		
		
## NOTE: AT THIS POINT &WHOLESALE::TWEAK_PRODUCT HAS ALREADY BEEN CALLED!
#		my $schedule = $SITE::CART2->in_get('our/schedule');
#		if ($schedule =~ /^QP/) {
#			$iniref->{'DATA'} = "product:zoovy:qtyprice_$schedule";
#			}
		}
	

	my $formula = $iniref->{'FORMULA'};
	if (not defined $formula) { $formula = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'}); }

   my %hash = ();
   foreach my $qty (split(/[\,\n\r]+/,$formula)) {
		next if ($qty == 1);
      if ($qty =~ m/^(.*?)(\=.*?)$/) {
         $hash{$1} = $2;
         }
      elsif ($qty =~ m/^(.*?)(\/.*?)$/) {
         $hash{$1} = $2;
         }
      }

	my $preline = $iniref->{'PRELINE'};
	if (not defined $preline) { $preline = ''; }
	my $postline = $iniref->{'POSTLINE'};
	if (not defined $postline) { $postline = '<br>'; }
	my $midline = $iniref->{'MIDLINE'};
	if (not defined $midline) { $midline = ' for '; }

   my $start = 2;
	my $text = '';
   foreach my $qty (sort {$a <=> $b} keys %hash) {
		my $foo = substr($hash{$qty},0,1);
		if ($qty == 0) {
			## what kind of asshat decides to use qty = 0
			require ZTOOLKIT;
			print STDERR "ASSHAT: ".$SITE->username()." ".&ZTOOLKIT::buildparams($iniref)."\n";
			}
		elsif ($foo eq '=') {
			## 2=$20 means 2+ for $20 each.
			$foo = substr($hash{$qty},1);
			$foo =~ s/[^\d\.]+//g;
			$text .= "$preline$qty\+$midline".&ZTOOLKIT::moneyformat($foo,$iniref->{'CURRENCY'})." each$postline";
			}
		elsif ($foo eq '/') {
			## 2/$20 means 2 for $20 -- $10 each.
			$foo = substr($hash{$qty},1);
			$foo =~ s/[^\d\.]+//g;
			$text .= "$preline$qty$midline".&ZTOOLKIT::moneyformat($foo/$qty,$iniref->{'CURRENCY'})." each$postline";
			}
		$start = $qty+1;
      }
   ## at this point $max is the highest matching rule

	if ($text eq '') { return(''); }
	$text = ((defined $iniref->{'PRETEXT'})?$iniref->{'PRETEXT'}:'').$text.((defined $iniref->{'POSTTEXT'})?$iniref->{'POSTTEXT'}:'');

	my $cssstyle = (defined $iniref->{'CSSSTYLE'}) ? $iniref->{'CSSSTYLE'} : '';
	my $cssclass = (defined $iniref->{'CSSCLASS'}) ? $iniref->{'CSSCLASS'} : '';
	if (not defined $iniref->{'FONT'}) { $iniref->{'FONT'} = $SITE::OVERLOADS{'site.css'}?0:1; }
	my $fontmode = (defined $iniref->{'FONT'})     ? $iniref->{'FONT'}     : 1;

	if ($cssclass || $cssstyle) {
		my $attribs = '';
		if ($cssstyle) { $attribs .= qq~ style="$cssstyle"~; }
		if ($cssclass) { $attribs .= qq~ class="$cssclass"~; }
		$text = qq~<span$attribs>$text</span>~;
		# Either CSSSTYLE or CSSCLASS specified is an implicit FONTMODE=DISABLED
		$fontmode = 0;
		}

	if ($fontmode) {
		$text = qq~<font class="ztxt">$text</font>~;
		}
	
	return($text);
	}




########################################
# render head
##
## NOTE: in layout, wizard, email (anything but wrapper) this will only output the CSS tags.
##
## sub RENDER_HEAD
sub render_head {
	my ($iniref,$toxml,$SITE) = @_;

	##
	## HEADSKIP= (bitwise)
	##		1 = NO CSS
	##		2 = NO META
	##		4 = NO FAVICO
	##		32 = NO JS
	##

	my $headskip = 0;
	if ((defined $iniref->{'HEADSKIP'}) && ($iniref->{'HEADSKIP'} ne '')) {
		$headskip = int($iniref->{'HEADSKIP'});
		}
	elsif (defined $toxml) {
		## FORMAT WILL BE: LAYOUT, WIZARD, WRAPPER, DEFINITION, EMAIL
		if ($toxml->getFormat() ne 'WRAPPER') { $headskip = 0xFF-1; } # hmm?!?! 0xFF-1
		}
		
	my $USERNAME = $SITE->username();
	$TOXML::RENDER::DEBUG && &msg("render_head(): \$USERNAME is '$USERNAME' [$SITE->pageid()]");

	# Get website DB
	my $webdbref = {};
	if ($headskip & (0xFF-1)) {
		## CSS ONLY (doesn't require webdb element)
		}		
	else {
		$webdbref = $SITE->webdbref();
		}


	my $out = '';

	## headskip=2 means don't output js
	if (($headskip & 2)==2) {}
	else {
		#########################################################
		## META NAME="AUTHOR"
		my $robot_deny = (def($SITE->pageid()) =~ m/^(cart|checkout)$/) ? 1 : 0 ;
		if ($SITE->sdomain() =~ /\.zoovy\.com/o) { $robot_deny |= 1; }

		# my $charset = def($webdbref->{'charset'}, 'ISO-8859-1');
		my $charset = def($webdbref->{'charset'}, 'UTF-8');
	
		###################################################
		## META NAME="DESCRIPTION"
		## META NAME="KEYWORDS"
		## META NAME="TITLE"
	
		my $metatitle = '';
		my $metadesc = '';
		my $metakeywords = '';
		$out = '';

		if ($SITE->{'_PID'} eq '') {
			$out .= def(&TOXML::RENDER::smart_load($SITE,'page:PAGE_HEAD'));		## page_head
			$metadesc = def(&TOXML::RENDER::smart_load($SITE,'page:META_DESCRIPTION'));
			$metakeywords = def(&TOXML::RENDER::smart_load($SITE,"page:META_KEYWORDS"));
			# default if we didn't find 'em.
			if ($metakeywords eq '') {
				# This is defined if you launch a search engine channel
				$metakeywords = &TOXML::RENDER::smart_load($SITE,'profile:zoovy:business_description');
				$metakeywords = &ZTOOLKIT::wikistrip($metakeywords);
				$metakeywords = &ZTOOLKIT::htmlstrip($metakeywords);
				}
			$metatitle = def(&TOXML::RENDER::smart_load($SITE,'page:HEAD_TITLE'));
			if ($metatitle eq '') { $metatitle = &TOXML::RENDER::smart_load($SITE,'page:PAGE_TITLE'); }
			if ($metatitle eq '') { $metatitle = &HTML::Entities::decode_entities( $SITE->title() ); }
			## *checkout, *cart, etc.
			if (($metatitle eq '') && (substr($SITE->pageid(),0,1) eq '*')) { $metatitle = uc(substr($SITE->pageid(),1)); }
			}
		else {
			###############################################
			## product specific head tag configuration

			#################
			## <meta title>
			$metatitle = &TOXML::RENDER::smart_load($SITE,'product:zoovy:prod_seo_title');
			if (not defined $metatitle) { $metatitle = ''; }
			
			if ($metatitle eq '') {
				$metatitle = &TOXML::RENDER::smart_load($SITE,'product:zoovy:prod_name');
				}

			###################
			## <meta keywords>
			$metakeywords = def(&TOXML::RENDER::smart_load($SITE,'product:zoovy:keywords')); 
			if (not defined $metakeywords) { $metakeywords = ''; }
			if ($metakeywords eq '') {
            $metakeywords = def(&TOXML::RENDER::smart_load($SITE,'product:zoovy:prod_desc'));
            $metakeywords = &ZTOOLKIT::wikistrip($metakeywords);
            $metakeywords = &ZTOOLKIT::htmlstrip($metakeywords);
 				}

			#################
			## <meta desc>
			$metadesc = &TOXML::RENDER::smart_load($SITE,'product:zoovy:meta_desc');
			if (not defined $metadesc) { $metadesc = ''; }
			if ($metadesc eq '') {
				$metadesc = def(&TOXML::RENDER::smart_load($SITE,'product:zoovy:prod_desc'));
				$metadesc = &ZTOOLKIT::wikistrip($metadesc);
				$metadesc = &ZTOOLKIT::htmlstrip($metadesc);
				}

			if (&TOXML::RENDER::smart_load($SITE,'product:seo:noindex')) {
				$robot_deny++;
				}
			}

		my $company_name = &TOXML::RENDER::smart_load($SITE,"profile:zoovy:company_name");

		my $seo_title_prepend = &TOXML::RENDER::smart_load($SITE,"profile:zoovy:seo_title");;
		my $seo_title_append = &TOXML::RENDER::smart_load($SITE,"profile:zoovy:seo_title_append");;
		if (not defined $seo_title_prepend) { $seo_title_prepend = ''; }
		if (not defined $seo_title_append) { $seo_title_append = ''; }
		if ($seo_title_prepend ne '') { $seo_title_prepend = "$seo_title_prepend "; }	 # add trailing space
		if ($seo_title_append ne '') { $seo_title_append = " $seo_title_append"; }		 # add leading space

		$metatitle = sprintf("%s%s%s",$seo_title_prepend,$metatitle,$seo_title_append);

				
		$TOXML::RENDER::DEBUG && &msg("render_head(): \$metadesc is '$metadesc'");
	
		####################################################
		## output
		$out .= "<title>".&ZOOVY::incode($metatitle)."</title>\n";
	
		if ($charset ne '') { 
			my $type = 'text/html';
			if (substr($SITE->domain_host(),0,2) eq 'm.') {
				## woot.. we're mobile!
				$type = 'application/xhtml+xml';
				}
			$out .= qq~<meta http-equiv="Content-Type" content="$type; charset=$charset" />\n~; 
			}
		if ($metadesc ne '') { 
				$metadesc =~ s/[\<\>\"]+/ /g; 
				$out .= qq~<meta name="description" content="$metadesc" />\n~; 
				}
		if ($metakeywords ne '') { 
				$metakeywords = &ZOOVY::incode($metakeywords);
				$out .= qq~<meta name="keywords" content="$metakeywords" />\n~; 
				}
		if ($robot_deny) { $out .= qq~<meta name="ROBOTS" content="NOFOLLOW, NOINDEX" />\n~; }
		# $out .= qq~<meta name="copyright" content="Copyright $company_name" />\n~;
		$out .= qq~<meta name="author" content="$company_name" />\n~;
		$out .= qq~<meta name="generator" content="Zoovy Commerce System http://www.zoovy.com/" />\n~;

		if ($SITE->canonical_url()) {
			$out .= sprintf("<link rel=\"canonical\" href=\"%s\" />\n",$SITE->canonical_url());
			}

		$out .= $SITE->generate_js_cookies_script();
		
		## handles both speciality sites, and anytime we are on a homepage.
		my $CWPATH = $SITE->servicepath()->[1];
		if (($SITE->rootcat() eq $CWPATH) || ($CWPATH eq '.')) {
			my ($DNSINFO) = $SITE->dnsinfo();
			$out .= $DNSINFO->{'+google_sitemap'};
			$out .= $DNSINFO->{'+bing_sitemap'}; 
			$out .= $DNSINFO->{'+yahoo_sitemap'}; 
			}

		}

	## headskip=4 means don't output favico.ico (somebody will hardcode them)
   if (($headskip & 4)==4) {}
	else {
		## added by PM 0729, added check for https 09142005
		## FAVICON
		## my $MEDIAHOST = &ZOOVY::resolve_media_host($USERNAME);
		$out .= qq~<link rel="SHORTCUT ICON" href="/media/merchant/$USERNAME/favicon.ico" />\n~;
		$out .= qq~<link rel="ICON" href="/media/merchant/$USERNAME/favicon.ico" />\n~;
		#$out .= qq~<link rel="SHORTCUT ICON" href="/media/merchant/$USERNAME/favicon.ico" />\n~;
		#$out .= qq~<link rel="ICON" href="/media/merchant/$USERNAME/favicon.ico" />\n~;
		}

	
	## headskip=1 means skip css
   if (($headskip & 1)==1) {}		
	elsif (defined $toxml) {
		my ($configel) = $toxml->findElements('CONFIG');
		if (not defined $configel->{'CSS'}) {
			require TOXML::CSS;
			$configel->{'CSS'} = TOXML::CSS::iniref2css($SITE::CONFIG->{'%THEME'});
			}

		if (defined $configel) {
			$out .= qq~<style type="text/css">\n<!--\n$configel->{'CSS'}\n-->\n</style>\n~;
			}
		}

	## headskip=32 means don't output js
	if (($headskip & 32)==32) {}
	else {
		## added ability to include javascript directly into header by BH 11/18/2005
		my $v = ($SITE->_is_secure())?'head_secure':'head_nonsecure';

		my $nsref = $SITE->nsref();

		if ($nsref->{'omniture:enable'}>0) {
			my %MACROS = (
				
				);
			$out .= "<!-- begin omniture block -->\n";
			$out .= $SITE->txspecl()->translate3($nsref->{'omniture:headjs'},[$iniref]);
			if ($SITE->fs() eq 'T') {
				## cart
				$out .= "<!-- begin_cart -->\n";
				$out .= $SITE->txspecl()->translate3($nsref->{'omniture:cartjs'},[$iniref]);
				$out .= "<!-- end_cart -->\n";
				}
			elsif ($SITE->fs() eq 'P') {
				$out .= "<!-- begin_product -->\n";
				$out .= $SITE->txspecl()->translate3($nsref->{'omniture:productjs'},[$iniref]);
				$out .= "<!-- end_product -->\n";
				}
			elsif ($SITE->fs() eq 'C') {
				$out .= "<!-- begin_category -->\n";
				$out .= $SITE->txspecl()->translate3($nsref->{'omniture:categoryjs'},[$iniref]);
				$out .= "<!-- end_category -->\n";
				}
			elsif ($SITE->fs() eq 'E') {
				$out .= "<!-- begin_search_result -->\n";
				$out .= $SITE->txspecl()->translate3($nsref->{'omniture:resultjs'},[$iniref]);
				$out .= "<!-- end_search_result -->\n";
				}
			$out .= "<!-- end omniture block -->\n";
			}
	
		if ($nsref->{'yahooshop:headjs'}) {
			## Yahoo Header JS code
			$out .= "<!-- yahooshop -->".$SITE->txspecl()->translate3($nsref->{'yahooshop:headjs'},[$iniref])."<!-- /yahooshop -->";
			}
		if ($nsref->{'analytics:headjs'}) {
			## Google Analytics
			$out .= "<!-- ganalytics -->".$SITE->txspecl()->translate3($nsref->{'analytics:headjs'},[$iniref])."<!-- ganalytics -->";
			}
		if ($nsref->{'plugin:headjs'}) {
			## Generic Plugin
			$out .= "<!-- plugin -->".$SITE->txspecl()->translate3($nsref->{'plugin:headjs'},[$iniref])."<!-- /plugin -->";
			}

		if ((not defined $nsref->{'powerreviews:enable'}) || ($nsref->{'powerreviews:enable'}==0)) {
			## No power reviews!
			}
		elsif ($SITE->pageid() eq 'powerreviews') {
			## don't output the powerreviews header code when we're on the powerreviews page!
			}
		elsif ($SITE->_is_secure()) {
			$out .= "<!-- power reviews disabled on secure page -->";
			}
		else {
			## POWERREVIEWS
			my $pwrmid = $nsref->{'powerreviews:merchantid'};
			my $pwrgid = $nsref->{'powerreviews:groupid'};
			$out .= qq~
<!-- powerreviews -->
<script type="text/javascript">
<!--
var pr_style_sheet="http://cdn.powerreviews.com/aux/$pwrgid/$pwrmid/css/powerreviews_express.css";
//-->
</script>
<script type="text/javascript"
src="http://cdn.powerreviews.com/repos/$pwrgid/pr/pwr/engine/js/full.js"></script>
<!-- /powerreviews -->
~;
			}

		# $webdbref->{'amzpay_env'} = 0;
		if ((defined $webdbref->{'amzpay_env'}) && ($webdbref->{'amzpay_env'}>0)) {
			my $merchantid = $webdbref->{'amz_merchantid'};
			$out .= qq~<!-- BEGIN_CBA -->
<script type="text/javascript" src="https://images-na.ssl-images-amazon.com/images/G/01/cba/js/jquery.js"></script>
<script type="text/javascript" src="https://images-na.ssl-images-amazon.com/images/G/01/cba/js/widget/widget.js"></script>
<script type="text/javascript">jQuery.noConflict();</script>

<script type="text/javascript">
function checkoutByAmazon(form) {
    form.action="https://payments.amazon.com/checkout/$merchantid";
    form.method="POST";

    showCBAWidget(form, jQuery("#cbaImage").offset().left + 10, jQuery("#cbaImage").offset().top + 25);
    form.submit();
}
</script>
<!-- END_CBA -->
~;
			}

	   if ((defined $webdbref->{'buysafe_mode'}) && ($webdbref->{'buysafe_mode'}>0)) {
			$out .= qq~<!-- BEGIN_BUYSAFE_HEADER_CODE -->
<script type="text/javascript" src="https://seal.buysafe.com/private/rollover/rollover.js"></script>
<!-- END_BUYSAFE_HEADER_CODE -->~;
			}



	#	if ($webdbref->{'google_api_env'}>0) {
	#		$out .= qq~<script src="http://checkout.google.com/files/digital/urchin_post.js" type="text/javascript"></script>\n~;
	#		}

		## zoovy:head_secure zoovy:head_nonsecure
		if (defined $nsref->{"zoovy:$v"}) {		
			$out .= ((index($nsref->{"zoovy:$v"},'%')>=0)?&TOXML::RENDER::interpolate_vars($SITE,$nsref->{"zoovy:$v"}):$nsref->{"zoovy:$v"})
			}
		}

	return $out;
	} ## end sub render_head





########################################
# render title
sub render_title {
	my ($iniref,undef,$SITE) = @_;

	my $namespace;
	if ((defined $SITE->{'_PID'}) && ($SITE->{'_PID'} ne '')) { $namespace = 'product'; }
	else { $namespace = 'page'; }

	my $USERNAME = $SITE->username();
	$TOXML::RENDER::DEBUG && &msg("render_title(): \$USERNAME is '$USERNAME'");

	# print STDERR "SMART: $SITE->prt(),$namespace:PAGE_TITLE\n";

	my $title = '';
	if ($namespace eq 'page') {
		## if BODY_TITLE is set, that always wins 
		$title = &ZTOOLKIT::def(&TOXML::RENDER::smart_load($SITE,"$namespace:BODY_TITLE"));
		}
	if ($title eq '') {
		$title = &ZTOOLKIT::def(&TOXML::RENDER::smart_load($SITE,"$namespace:PAGE_TITLE"));
		}
	$TOXML::RENDER::DEBUG && &msg("render_title(): \$namespace is '$namespace'");
	$TOXML::RENDER::DEBUG && &msg("render_title(): \$title is '$title'");
	if ($title eq '') { 
		# DEFAULT TO +title - WHICH is supposed to be entity encoded. 
		$title = HTML::Entities::decode_entities($SITE->title()); 
		}

	$title = &ZOOVY::incode($title);
	$title = ((defined $iniref->{'PRETEXT'})?$iniref->{'PRETEXT'}:'').$title.((defined $iniref->{'POSTTEXT'})?$iniref->{'POSTTEXT'}:'');

	return $title;
}

# This is a hash of references to subroutines, so we can make one simple call to
# generically reference a function for any of the element types byt the syntax
# $FLOW::flow_blah{FOO}->(params for foo);

###########################################################################
# RENDER ELEMENT

# Each of these function takes in a reference to an element's INI hash, and returns the
# HTML code to display the element

sub RENDER_SEARCHBOX {
	my ($iniref,undef,$SITE) = @_;
	my $tmp = '';

	my $catalog = &TOXML::RENDER::smart_load($SITE,$iniref->{'CATALOGATTRIB'});
	if (not defined($catalog)) { $catalog = ''; }

	my $prompt = &TOXML::RENDER::smart_load($SITE,$iniref->{'PROMPTATTRIB'});
	if (not defined($prompt)) { $prompt = $iniref->{'PROMPTDEFAULT'}; }

	my $button = &TOXML::RENDER::smart_load($SITE,$iniref->{'BUTTONATTRIB'});
	if (not defined($button)) { $button = $iniref->{'BUTTONDEFAULT'}; }

	my %vars = ();
	$vars{'CATALOG'} = $catalog;
	$vars{'PROMPT_TEXT'} = $prompt;
	$vars{'BUTTON_TEXT'} = $button;
	$vars{'results_url'} = $SITE->URLENGINE()->get('results_url');


	my $spec = $iniref->{'HTML'};
	if (not defined $spec) {
		$spec = q~<form class="z_searchform" id="<% load($ID);  print(); %>" action="<% load($results_url);  print(); %>" method="GET">
<input type="hidden" id="<% load($ID);  print(); %>!catalog" name="catalog" value="<% load($CATALOG);  print(); %>"></input>
<% print($PROMPT_TEXT); %> <input type="text" id="<% load($ID);  print(); %>!keywords" name="keywords" value=""></input>
<input type="submit" id="<% load($ID);  print(); %>!submit" value="<% load($BUTTON_TEXT);  print(); %>"></input>
</form>
~;
		}

	my $out = $SITE->txspecl()->translate3($spec,[\%vars,$iniref,$SITE::CONFIG->{'%THEME'}]);
	return $out;
} ## end sub RENDER_SEARCH



##
## this can be used to override certain global variables (such as SITEBUTTONCACHE)
##
sub RENDER_OVERLOAD {
	my ($iniref) = @_;

	if (defined $iniref->{'OVERLOAD'}) {
		## you can define an OVERLOAD= in a config element, OR in an OVERLOAD element
		## this is useful because CONFIGS cannot be run conditionally, whereas OVERLOADs can
		my $ref = &ZTOOLKIT::parseparams($iniref->{'OVERLOAD'});
		foreach my $k (keys %{$ref}) {
			$SITE::OVERRIDES{$k} = $ref->{$k};
			}		

#		if ($ref->{'webdb.customer_management'} ne '') {
#			open F, ">>/tmp/customer_management_overrides";
#			print F "$SITE::merchant_id	$SITE::SREF->{'+sdomain'}	$ref->{'webdb.customer_management'}\n";
#			close F;
#			}
		}

	## <ELEMENT BUTTON="add_to_cart" ID="CQLUVIA" LINK="addToCart();" TYPE="OVERLOAD"></ELEMENT>
	if (defined $iniref->{'BUTTON'}) {	
		## make sure we've already loaded our SITEBUTTONCACHE
		my $sb = $SITE::CONFIG->{'%SITEBUTTONS'};

		if (defined $iniref->{'LINK'}) {
			$sb->{ $iniref->{'BUTTON'}.'_link' } = $iniref->{'LINK'};
			}
		## eventually we might want to be able to override other button properties, but for now this ought to do.
		}
	else { 
		
		}

	return();
	}




########################################
# render sitebutton
sub RENDER_SITEBUTTON {
	my ($iniref,undef,$SITE) = @_;    # iniref is a reference to a hash of the element's contents as defined in the flow file
	if (not defined $iniref) { $iniref = {}; }

	my $USERNAME = $SITE->username();
	my $webdbref = $SITE->webdb();
	$TOXML::RENDER::DEBUG && &msg("render_sitebutton(): \$USERNAME is '$USERNAME'");



	## make sure all keys are lowercase
	foreach my $k (keys %{$iniref}) {
		$iniref->{lc($k)} = $iniref->{$k};
		}



	my $btn = $iniref->{'button'};		## e.g. add_to_cart
	if ((not defined $btn) || ($btn eq '')) { $btn = 'continue_shopping'; }

	## currently "next" is a transitional button .. meaning file is named "next" but file is named forward 7/28/09
	##		buttons should officially be "next" 
	if ($btn eq 'next') { $btn = 'forward'; }

	if ((not defined $iniref->{'alt'}) || ($iniref->{'alt'} eq '')) {
		$iniref->{'alt'} = lc($btn);
		$iniref->{'alt'} =~ s/\s/_/gis;
		$iniref->{'alt'} =~ s/\W//gis;
		}

	## CHEAP HACK TO MAKE GOOGLE AND PAYPAL SITEBUTTONS
	my $out = '';

	if ($btn eq 'paypal') {
		## PAYPAL SITEBUTTON
		$out = '<!-- PAYPAL_BUTTON -->';

		my $disabled = 0;
		if (ref($SITE::CART2) eq 'CART2') {
			## look for disabled items via the product attribute paypalec:blocked==1
			## if true, then we set $disabled
			my ($stuff2) = $SITE::CART2->stuff2();
			if (ref($stuff2) eq 'STUFF2') {
				foreach my $item (@{$stuff2->items()}) {
					# my $item = $stuff->item($stid);
					# next if (ref($item->{'full_product'}) ne 'HASH');
					next if (not defined $item->{'%attribs'}->{'paypalec:blocked'});
					if ($item->{'%attribs'}->{'paypalec:blocked'}==1) { $disabled++; }
					}
				}

			if (not $disabled) {
				if ($SITE::CART2->has_giftcard()) { $disabled++; }
				}
			}
	
		if ($disabled) {
			$out .= "<!-- PAYPAL DISABLED BY PRODUCT -->";
			}
		elsif ($webdbref->{'paypal_api_env'}>0) { 

			# my ($X,$Y,$IMGURL) = (142,42,'https://www.paypal.com/en_US/i/btn/btn_xpressCheckoutsm.gif');
			my ($X,$Y,$IMGURL) = (145,42,'https://www.paypal.com/en_US/i/btn/btn_xpressCheckoutsm.gif');
			if ($webdbref->{'paypal_paylater'}>0) {
				# $SITE::CART2->compute_sums();
				my $total = $SITE::CART2->in_get('sum/order_total');
				if (($total>=50) && ($total<=1500)) {
					($X,$Y,$IMGURL) = (142,54,'/media/graphics/general/paypal_mspf_ec1_142x54.png');
					}
				}

			my $url = $SITE->URLENGINE()->get('paypal_url');
			$url .= "?mode=cartec&cart=".$SITE::CART2->cartid()."&ts=".$^T;
			$out = qq~<a href="$url"><img width="$X" height="$Y" border="0" src="$IMGURL" alt='' /></a>~;
			}
		# print STDERR "OUT: $out\n";
		}
#	elsif ($btn eq 'google') {
#		## GOOGLE CHECKOUT SITEBUTTON
#		$out = '<!-- GOOGLE_BUTTON -->';
#		if ($webdbref->{'google_api_env'}>0) {
#			require ZPAY::GOOGLE;
#			$out = &ZPAY::GOOGLE::button_html($SITE::CART2,$SITE);
#			}
#		}
	elsif ($btn eq 'amzpay') {
		$out = '<!-- AMZPAY_BUTTON -->';
		if ($webdbref->{'amzpay_env'}>0) {
			require ZPAY::AMZPAY;
			$out = &ZPAY::AMZPAY::button_html($SITE::CART2,$SITE);
			}		
		}
	else {
		##
		## Regular "NAMED" site button
		## 

		if (not defined $iniref->{'name'}) { $iniref->{'name'} = ''; }

		my $imageurl  = '';

		my $X = $iniref->{'%SITEBUTTONS'};
		if (not defined $X) { 
			## this is the most common path, %SITEBUTTONS is only passed from the builder/chooser area.
			$X = $SITE::CONFIG->{'%SITEBUTTONS'};
			}


		my $btndata = $X->{'default'}; # $SITE::CONFIG->{'%SITEBUTTONS'}->{'default'};
		# if (defined $SITE::CONFIG->{'%SITEBUTTONS'}->{$btn}) { $btndata = $SITE::CONFIG->{'%SITEBUTTONS'}->{$btn}; }
		if (defined $X->{$btn}) { $btndata = $X->{$btn}; }
	
		## format for btndata is: file|extension|width|height
		my ($path,$ext,$width,$height) = split(/\|/,$btndata);

		my $proto = '';
		if (defined $SITE->_is_secure()) { $proto = 'https:'; }
		elsif ($iniref->{'HTTPS'}) { $proto = 'https:'; }

		# print STDERR Dumper($iniref,$SITE::CONFIG);

		## my $MEDIAHOST = &ZOOVY::resolve_media_host($USERNAME);
		$imageurl = "/media/graphics/sitebuttons/$path/$btn.$ext";
		if (substr($path,0,1) eq '~') {
			$path = substr($path,1);
			my ($FOLDER) = ($SITE::CONFIG->{'FOLDER'})?"$SITE::CONFIG->{'FOLDER'}/":'';
			# $imageurl = &SITE::URLS::get_static_url($USERNAME,'merchant',$proto)."$FOLDER/".substr($path,1)."_$btn.$ext";
			$imageurl = "/media/merchant/$USERNAME/$FOLDER$path\_$btn.$ext";
			# $imageurl = &SITE::URLS::get_static_url($USERNAME,'merchant',$proto)."$FOLDER/".substr($path,1)."_$btn.$ext";
			}

		if (defined $iniref->{'width'}) { $width = $iniref->{'width'}; }
		if (defined $iniref->{'height'}) { $height = $iniref->{'height'}; }
		my $LINK = $SITE::CONFIG->{'%SITEBUTTONS'}->{$btn . '_link'};

		my $onclick = '';
		if (defined $iniref->{'onclick'}) { $onclick = " onClick=\"$iniref->{'onclick'}\""; }
		if ((defined $LINK) && ($LINK ne '')) {
			## the "button_type_link" variable was probably set by an OVERLOAD element somewhere in the wrapper.
			$out .= "<a href=\"$LINK\"><img id=\"$iniref->{'id'}\" src=\"$imageurl\" width=\"$width\" height=\"$height\" border=\"0\" alt=\"$iniref->{'alt'}\" type=\"image\" name=\"$iniref->{'name'}\" $onclick /></a>";
			if (defined $iniref->{'ID'}) { $out =~ s/\%ID\%/$iniref->{'ID'}/gs; }
			if (defined $iniref->{'PID'}) { $out =~ s/\%PID\%/$iniref->{'PID'}/gs; }
			if (defined $iniref->{'SKU'}) { $out =~ s/\%SKU\%/$iniref->{'SKU'}/gs; }
			}
		else {
			## Legacy non-LINK method. (this is the most common method used)
			## border remobed from input by jt 5/2/2011 - not w3c compliant to have border on img input
		   if ($iniref->{'name'}) {
				$out .= qq~<input src="$imageurl" id="$iniref->{'id'}" alt="$iniref->{'alt'}" type="image" name="$iniref->{'name'}"$onclick />~;
  		 	   }
		   else {
   		   $out .= qq~<img src="$imageurl" id="$iniref->{'id'}" width="$width" height="$height" border="0" alt="$iniref->{'alt'}" />~;
     			}
			}


		# print STDERR "OUT: $out\n";
		}

	return $out;
	} ## end sub RENDER_SITEBUTTON





########################################
# render hitgraph
sub RENDER_HITGRAPH {
	my ($iniref,undef,$SITE) = @_;    # iniref is a reference to a hash of the element's contents as defined in the flow file

	return();

#	my $USERNAME = $SITE->username();
#	# These are VERY safe colors to choose from.  Monkeying with them will probably
#	# result in crappy looking charts in some themes.
#	my $TH = $SITE::CONFIG->{'%THEME'};
#	my $bgcolor   = $TH->{'content_background_color'};
#	my $fgcolor   = $TH->{'content_text_color'};
#	my $textcolor = $TH->{'link_color'};
#	my $axiscolor = $TH->{'content_text_color'};
#
#	# Strip off the leading pound sign (and any other garbage)
#	$bgcolor   =~ s/[^A-F0-9]//gi;
#	$fgcolor   =~ s/[^A-F0-9]//gi;
#	$textcolor =~ s/[^A-F0-9]//gi;
#	$axiscolor =~ s/[^A-F0-9]//gi;
#
#	my $channel;
#	if (defined $SITE::v->{'channel'}) { $channel = $SITE::v->{'channel'}; }
#	elsif (defined $SITE::v->{'id'}) { $channel = $SITE::v->{'id'}; }
#	else { $channel = 0; }
#
#	my $head = def(&TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'}));
#
#	my $BUF = qq~<img src="http://track.zoovy.com/chart.cgi?MERCHANT=$USERNAME&CHANNEL=$channel&BGCOLOR=$bgcolor&FGCOLOR=$fgcolor&TEXTCOLOR=$textcolor&AXISCOLOR=$axiscolor&WIDTH=$iniref->{'WIDTH'}&HEIGHT=$iniref->{'HEIGHT'}&HEAD=$head" alt="$head" width="$iniref->{'WIDTH'}" height="$iniref->{'HEIGHT'}"><br>~;

#	return ($BUF);
} ## end sub RENDER_HITGRAPH

########################################
# render font
# An unending font tag (you must end it)
sub RENDER_FONT {
	my ($iniref) = @_; ## iniref is a reference to a hash of the element's contents as defined in the flow file
	return(q~<font class="ztxt">~);
	}


########################################
# render text
# 		note: this is the function which does the wikitext
#
sub RENDER_TEXT {
	my ($iniref,undef,$SITE) = @_; ## iniref is a reference to a hash of the element's contents as defined in the flow file

	# use Data::Dumper; print STDERR 'SREF: '.Dumper($SITE);
	my $text = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'});
	if (not defined $text) { $text = $iniref->{'DEFAULT'};}

	## turn off wiki if javascript is present	
	##
	## 1 = enable wiki
	##	2 = strip html
	##	4 = creole wiki
	##
	
	if ((not defined $iniref->{'WIKI'}) && ($iniref->{'TYPE'} eq 'TEXTBOX')) {
		## if a textbox doesn't IMPLICITY set a WIKI state, we'll defualt to zero
		$iniref->{'WIKI'} = 0;
		}

	if ((not defined $iniref->{'WIKI'}) || ($iniref->{'WIKI'})) {
		if (not defined $iniref->{'WIKI'}) {
			## disable wiki if we have embeded javascript
			## Look for </SCRIPT> or </TABLE> tags.. or any </tag>
			$iniref->{'WIKI'} = ($text =~ /<\/([Tt][Aa][Bb][Ll][Ee]|[Ll][Ii]|[Ss][Cc][Rr][Ii][Pp][Tt])>/)?0:1;		
			}

		if (($iniref->{'WIKI'} & 2)==2) { $text = &ZTOOLKIT::htmlstrip($text,1); }	# strip HTML if bit 2 is on.
		if ($iniref->{'WIKI'}>0) {
			$text = $SITE->URLENGINE()->wiki_format($text); 
			}
		}


	if ($text eq '') { return(''); }
	$text = ((defined $iniref->{'PRETEXT'})?$iniref->{'PRETEXT'}:'').$text.((defined $iniref->{'POSTTEXT'})?$iniref->{'POSTTEXT'}:'');

   ##
   ## Look for href="/  (hint: the / indicates it's a relative URL and can be safely rewritten)
   ##
	## subs out %SESSION% %CART% etc.
	if (index($text,'%')>=0) { $text = TOXML::RENDER::interpolate_vars($SITE,$text); }

	my $cssstyle = (defined $iniref->{'CSSSTYLE'}) ? $iniref->{'CSSSTYLE'} : '';
	my $cssclass = (defined $iniref->{'CSSCLASS'}) ? $iniref->{'CSSCLASS'} : '';
	if (not defined $iniref->{'FONT'}) { $iniref->{'FONT'} = $SITE::OVERLOADS{'site.css'}?0:1; }
	my $fontmode = (defined $iniref->{'FONT'})     ? $iniref->{'FONT'}     : 1;

	if ($cssclass || $cssstyle) {
		my $attribs = '';
		if ($cssstyle) { $attribs .= qq~ style="$cssstyle"~; }
		if ($cssclass) { $attribs .= qq~ class="$cssclass"~; }
		$text = qq~<span$attribs>$text</span>~;
		# Either CSSSTYLE or CSSCLASS specified is an implicit FONTMODE=DISABLED
		$fontmode = 0;
		}

	if ($iniref->{'RAW'}) {}
	elsif ($fontmode > 0) {
		$text = qq~<font class="ztxt">$text</font>~;
		}

	## this does the WIKI formatting.

	return ($text);
}

########################################
# render image
sub RENDER_IMAGE {
	my ($iniref,$toxml,$SITE) = @_; # iniref is a reference to a hash of the element's contents as defined in the flow file

	my $USERNAME = $SITE->username();
	my $preview;
	if (defined($iniref->{'PREVIEW'}) && $iniref->{'PREVIEW'}) { $preview = 1; }
	else { $preview = 0; }

	my $protocol = ($SITE->URLENGINE()->secure()) ? 'https' : 'http';

	my $width   = defined($iniref->{'WIDTH'})   ? $iniref->{'WIDTH'}   : 0;
	my $height  = defined($iniref->{'HEIGHT'})  ? $iniref->{'HEIGHT'}  : 0;
	my $zoom    = defined($iniref->{'ZOOM'})    ? $iniref->{'ZOOM'}    : 0;
	if (not defined $iniref->{'MINIMAL'}) { $iniref->{'MINIMAL'} = 1; }

	my $image = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'});
	if (not defined $image) { $image = ''; }

	## sometimes we've got a path/./image in the filename.. which shoudln't happen, but the regex below is an easy fix.
	$image =~ s/\/\.\//\//g;

	my $link_url = '';
	my $USE_JS_ZOOM = '';
	if ($zoom) {
		## HTML Wizards shouldn't use the javascript:zoom feature, so we implicitly set the link_url to the orig image
		if ((not defined $toxml) || ($toxml->format() eq 'WIZARD') || ($toxml->format() eq 'EMAIL') || ($SITE->_is_newsletter())) {
			## absolute path
			$link_url = sprintf("http://%s/media/img/%s/-/%s",&ZOOVY::resolve_media_host($SITE->username()),$SITE->username(),$image);
			}
		else {
			## relative path
			$USE_JS_ZOOM++;
			$link_url = &ZOOVY::image_path($USERNAME,$image,H=>0,W=>0,shibby=>1);
			}
		# $link_url = &IMGLIB::Lite::url_to_orig($SITE->username(), $image);
		}
	elsif (defined($iniref->{'URL_SAVETO'})) {
		$link_url = &TOXML::RENDER::smart_load($SITE,$iniref->{'URL_SAVETO'});
		}
	if (not defined $link_url) { $link_url = ''; }
	
	if (not defined $iniref->{'ALT_FROM'}) {
		if ($SITE->{'_PID'} ne '') {
			## products will use product name.
			$iniref->{'ALT_FROM'} = "product:zoovy:prod_name";
			}
		}
	
	my $alt = (defined $iniref->{'ALT_FROM'}) ? &TOXML::RENDER::smart_load($SITE,$iniref->{'ALT_FROM'}) : '';
	if ($alt eq '') { $alt = $image; }
	$alt = &ZOOVY::incode($alt);
	
	# Now if we have smart saved values, lets override with those!
	# Normalize the width & height
	$width  =~ s/\D//gs; if ($width  eq '') { $width  = 0; }
 	$height =~ s/\D//gs; if ($height eq '') { $height = 0; }
	unless ($width && $height)  { $iniref->{'MINIMAL'} = 1; }
	# Set the image tag variables

	
	my $out = '';
	my $raw_out = '';
	if ($image eq '') {
		if ($preview) {
			my $imgtag_width  = ($width  && !$iniref->{'MINIMAL'}) ? qq~width="$width"~   : qq~width="1"~;
			my $imgtag_height = ($height && !$iniref->{'MINIMAL'}) ? qq~height="$height"~ : qq~height="1"~;
			$out = qq~<img $imgtag_width $imgtag_height name="$iniref->{'ID'}" id="$iniref->{'ID'}" src="/media/graphics/general/blank.gif" border="0" />~;
			$raw_out = "/media/graphics/general/blank.gif";
			}
		}
	elsif ($image =~ m/^[Hh][Tt][Tt][Pp][Ss]?\:/) {
		# Legacy format, where image URL is hardcoded!
	 	my $imgtag_width  = $width  ? qq~width="$width"~   : '';
		my $imgtag_height = $height ? qq~height="$height"~ : '';
		$out .= qq~<img $imgtag_width $imgtag_height name="$iniref->{'ID'}" id="$iniref->{'ID'}" src="$image" border="0" />~;
		$raw_out = $image;
		}
	else {
		my $bg = substr($SITE::CONFIG->{'%CSSVARS'}->{'zbody.bgcolor'},1);
		if (defined $iniref->{'BGCOLOR'}) { $bg = $iniref->{'BGCOLOR'}; }
		$bg = lc($bg);

		my ($actual_width,$actual_height) = ($width,$height);
		if ($iniref->{'MINIMAL'}) {
			($actual_width,$actual_height) = &ZOOVY::image_minimal_size($USERNAME, $image, $width, $height, $SITE->cache_ts());
			if (($actual_width==-1) || ($actual_height==-1)) {
				($actual_width,$actual_height) = ('X','X');
				}
			}
		#my $src = &IMGLIB::Lite::url_to_image($USERNAME, $image, $actual_width, $actual_height, $bg, 0, 0, $SITE->{'+cache'});
		# my $src = $SITE->URLENGINE()->image_url($image, $actual_width, $actual_height,$bg);
		my $src = &ZOOVY::image_path($USERNAME, $image, W=>$actual_width, H=>$actual_height, B=>$bg);
		if ((not defined $toxml) || ($toxml->format() eq 'EMAIL') || ($toxml->format() eq 'WIZARD') || ($SITE->_is_newsletter())) {
			$src = sprintf("https://%s%s",&ZOOVY::resolve_media_host($USERNAME),$src);
			}

		my $imgtag_width  = ($actual_width)?qq~width="$actual_width"~:'';
		my $imgtag_height = ($actual_height)?qq~height="$actual_height"~:'';
		$out .= qq~<img $imgtag_width $imgtag_height name="$iniref->{'ID'}" id="$iniref->{'ID'}" src="$src" alt="$alt" border="0" />~;
		$raw_out = $src;
		}

	if ($image eq '') {}	# don't do anything!
	elsif (not $link_url) {
		## no zoom for you!
		}
	elsif (($link_url) && (not $USE_JS_ZOOM)) { 
		## if URL_SAVETO is not set then we are probably just linking to the image, and so we ought to target _BLANK
		$out = qq~<a ~.((defined $iniref->{'URL_SAVETO'})?'':'target="_blank" ').qq~ href="$link_url">$out</a>~;  
		}
	elsif ($zoom) { 
		# $image = &IMGLIB::Lite::url_to_orig($SITE->username(), $image);
		# $out = sprintf("/media/img/%s/-/%s",$USERNAME,$image);
		#my $src = &ZOOVY::image_path($USERNAME, $image, W=>0, H=>0);
		#if ((defined $toxml) && ($toxml->format() eq 'EMAIL') || ($toxml->format() eq 'WIZARD')) {
		#	$src = sprintf("https://%s%s",&ZOOVY::resolve_media_host($USERNAME),$src);
		#	}
		$out = qq~<a href="javascript:zoom('$link_url')">$out</a>~; 
		}


	if (defined($iniref->{'RAW'}) && $iniref->{'RAW'}) { $out = $raw_out; }
	if ($out ne '') { $out = def($iniref->{'PRETEXT'}).$out.def($iniref->{'POSTTEXT'}); }

	# print STDERR "OUT: $out\n";

	return $out;

} ## end sub RENDER_IMAGE

########################################
# render dynimage
sub RENDER_DYNIMAGE {
	my ($iniref,undef,$SITE) = @_;    # iniref is a reference to a hash of the element's contents as defined in the flow file

	my $USERNAME = $SITE->username();
	my $protocol = ($SITE->URLENGINE()->secure()) ? 'https' : 'http';

	my $name   = lc($iniref->{'NAME'});
	if ($name eq '') { $name = 'X'.$iniref->{'ID'}; }	# js variables must start with letter
	
	my $width  = $iniref->{'WIDTH'};  $width  =~ s/\D//g; ## Remove all non-digits
	my $height = $iniref->{'HEIGHT'}; $height =~ s/\D//g;

	
	my $bg = $iniref->{'BGCOLOR'};
	if ($bg eq '') { $bg = lc(substr($SITE::CONFIG->{'%CSSVARS'}->{'zbody.bgcolor'},1)); }
## tttttt is used to denote transparency (png). 
	if(lc($bg) ne 'tttttt')	{
		$bg =~ s/[^0-9a-f]//g;
		}

	my %params = ();
	my @images = ();
	my @zooms  = ();
	my @urls   = ();

	my $BUF = &ZOOVY::dcode(&TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'}));
	if (not defined $BUF) { $BUF = ''; }
	foreach my $keyval (split /[\n\r]+/, $BUF) {
		my ($key, $value) = split (/\=/, $keyval, 2);
		$params{$key} = $value;
		}

	if (not defined $params{'images'})         { $params{'images'}         = ''; }
	if (not defined $params{'blank_behavior'}) { $params{'blank_behavior'} = ''; }
	if (not defined $params{'links'})          { $params{'links'}          = ''; }
	if (not defined $params{'pauses'})         { $params{'pauses'}         = ''; }

	my @links_tmp  = split (/\,/, $params{'links'});
	my @pauses_tmp = split (/\,/, $params{'pauses'});

	## my $imgbase = &IMGLIB::Lite::get_static_url($USERNAME,'img',$protocol);
	## my $imgbase = sprintf("/media/img/");
	my $count = 0;
	# my $MEDIAHOST = &ZOOVY::resolve_media_host($USERNAME);
	foreach my $image (split /\,/, $params{'images'}) {
		if ($image =~ m/^http\:/) {
			$params{'image_'.$count} = $image;
			if ($params{'blank_behavior'} eq 'zoom') { $params{'zoom_'.$count} = $image; }
			}
		else {
			## if there is no extension on the image, add one.
			if ($image !~ /\.(jpg|gif|png)$/) { $image = "$image.jpg"; }
			$params{'image_'.$count} = &ZOOVY::image_path($USERNAME,$image,W=>$width,H=>$height,B=>$bg,shibby=>1);
			if ($params{'blank_behavior'} eq 'zoom') { 
				$params{'zoom_'.$count} = &ZOOVY::image_path($USERNAME,$image,H=>0,W=>0,shibby=>1);
				}
			}

		if (defined($links_tmp[$count]) && $links_tmp[$count]) {
			$params{'link_'.$count} = &interpolate_vars($SITE,$links_tmp[$count]);
			}

		if (defined($pauses_tmp[$count]) && $pauses_tmp[$count])	{
			if ($pauses_tmp[$count] < 3000) { $params{'pause_'.$count} = 3000; }
			else { $params{'pause_'.$count} = $pauses_tmp[$count]; }
			}
		else {
			$params{'pause_'.$count} = 1800;
			}
		$count++;
		}
	delete $params{'links'};
	delete $params{'images'};
	delete $params{'pauses'};

	@links_tmp = ();
	@pauses_tmp = ();
	$params{'count'} = $count;

	my $guts = '';
	if ($iniref->{'OUTPUT'} eq 'URI') {
		$guts = &ZTOOLKIT::buildparams(\%params,1);
		}
	elsif ($iniref->{'OUTPUT'} eq 'HTML') {
		$guts = $SITE->txspecl()->translate3($iniref->{'HTML'},[\%params,$iniref]);
		}
	elsif ($count == 0) {
		## DEFAULT SHOULDN'T DISPLAY
		}
	else {
		my $buttonwidth = int($width / 2);
		$guts = untab(qq~
		<script type="text/javascript">
		<!--
		// RENDER_DYNIMAGE
		$name = new iList;
		$name.name = "$name";
		~); 

		for (my $i = 0 ; $i < $count; $i++) {
			my $image =	$params{'image_'.$i};
			my $zoom	=	$params{'zoom_'.$i};
			my $link = 	$params{'link_'.$i};
			my $pause =	$params{'pause_'.$i};

			$guts .= qq~$name.img[$i] = new Image;\n~;
			$guts .= qq~    $name.img[$i].src = "$image";\n~;
			if (defined $link)  { $guts .= qq~    $name.url[$i]     = "$link";\n~; }
			if (defined $zoom)  { $guts .= qq~    $name.zum[$i]     = "$zoom";\n~; }
			if (defined $pause) { $guts .= qq~    $name.pause[$i]   = "$pause";\n~; }
			}

		my $startstop = 'false';
		if ($params{'blank_behavior'} eq 'startstop') { $startstop = 'true'; }
		my $lastcount = ($count - 1);
			$guts .= untab(qq~
			$name.startstop = $startstop;
			$name.last = $lastcount;
			$name.buttons = false;
			$name.stopped = false;
			$name.defaultpause = 2000;
			iLoad($name);
			$name.current = 0;
			//-->
			</script>
			<a href="javascript:iLink($name)"><img width="$width" height="$height" name="image_$name" src="$params{'image_0'}" border="0" /></a>
			~);
		}

	if ($guts ne '') {
		$guts = ((defined $iniref->{'PRETEXT'})?$iniref->{'PRETEXT'}:'').$guts.((defined $iniref->{'POSTTEXT'})?$iniref->{'POSTTEXT'}:'');
		}


	# print STDERR "GUTS: $guts\n";

	return $guts;
	} ## end sub RENDER_DYNIMAGE





########################################
# render slide
sub RENDER_SLIDE
{
	my ($iniref,$toxml,$SITE) = @_;    # iniref is a reference to a hash of the element's contents as defined in the flow file

	my $USERNAME = $SITE->username();
	if (not defined $USERNAME) { $USERNAME = $SITE->username(); }
	my $SKU = $SITE->{'_PID'};
	if (not defined $SKU) { $SKU = $SITE->sku(); }

	my $protocol = ($SITE->URLENGINE()->secure()) ? 'https' : 'http';

	my $name   = lc($iniref->{'NAME'});
	if ($name eq '') { $name = 'X'.$iniref->{'ID'}; }	# js variables must start with letter
	my $width  = $iniref->{'WIDTH'};  $width  =~ s/\D//gs; ## Remove all non-digits
	my $height = $iniref->{'HEIGHT'}; $height =~ s/\D//gs;

	my $bg = lc(substr($SITE::CONFIG->{'%CSSVARS'}->{'zbody.bgcolor'},1));
	$bg =~ s/[^0-9a-f]//g;

	my (@images, @zooms);
	# Make the @images and @zooms arrays
	## my $imgbase = &IMGLIB::Lite::get_static_url($USERNAME,'img',$protocol);
	# my ($prodref) = &ZOOVY::fetchproduct_as_hashref($USERNAME,$SKU);
	my ($P) = PRODUCT->new($USERNAME,$SKU);
	foreach my $imagenum (1 .. 30) {
		# my $image = &ZOOVY::fetchproduct_attrib($USERNAME, $SKU, "zoovy:prod_image$imagenum");
		my $image = $P->fetch("zoovy:prod_image$imagenum"); # $prodref->{"zoovy:prod_image$imagenum"};
		if (defined($image) && $image) {
			if ($image =~ m/^http\:/) {
				push @images, $image;
				push @zooms,  $image;
				}
			else {
				push @images, &ZOOVY::image_path($USERNAME,$image,W=>$width,H=>$height,B=>$bg,shibby=>1);
				push @zooms,  &ZOOVY::image_path($USERNAME,$image,shibby=>1);
				}
			}
		}

	if (scalar(@images) == 0) {
		@images = ("/media/graphics/general/blank.gif");
		@zooms  = ("/media/graphics/general/blank.gif");
		}

	my $num_images  = scalar(@images);
	my $buttonwidth = int($width / 2);
	
	my $guts = untab(qq~
		<script type="text/javascript">
		<!--
		// RENDER_SLIDE
		$name = new iList;
		$name.name = "$name";
		$name.stopped = true;
		$name.buttons = true;
		~);
	my $count;
	for ($count = 0 ; $count < scalar(@images) ; $count++) {
		$guts .= qq~$name.img[$count] = new Image;\n~;
		$guts .= qq~    $name.img[$count].src = "$images[$count]";\n~;
		$guts .= qq~    $name.zum[$count]     = "$zooms[$count]";\n~;
		}

	my $lastcount = ($count - 1);
	$guts .= untab(qq~
		$name.last = $lastcount;
		iLoad($name);
		$name.current = 0;
		//-->
		</script>
		<table width="$width" border="0" cellpadding="0" cellspacing="0">
			<form name="form_$name">
			<tr>
				<td width="$width" height="$height" colspan="2" align="center"><a href="javascript:iLink($name)"><img width="$width" height="$height" name="image_$name" src="$images[0]" border="0" /></a></td>
			</tr>
			<tr>
				<td width="$buttonwidth" align="left"><input type="button" onclick="iPrev($name)" name="prevButton" value="Previous Image" style="width:${buttonwidth}px;" /></td>
				<td width="$buttonwidth" align="right"><input type="button" onclick="iNext($name)" name="nextButton" value="Next Image" style="width:${buttonwidth}px;" /></td>
			</tr>
			</form>
		</table>
	~);

	# $guts .= Dumper($USERNAME,$SKU);

	return $guts;
} ## end sub RENDER_SLIDE





###############################################################
##
## loadURP (Universal Resource Path)
##
sub loadURP {		## sub loadurp is really loadURP (you're here)
	my ($SITE,$src) = @_;

	my $USERNAME = $SITE->username();
	my $RESULT = undef;
	
	my ($f,$target) = (undef,undef);

	if ($src =~ /^CART2::(.*?)$/) {
		$f = 'CART2'; $target = $1;
		}
	elsif ($src =~ /^([A-Z]+)(\[[A-Za-z0-9_\-\.\#\:]+\])?\:\:(.*)$/o) {
		## FLOW:: VAR:: etc.
		## also PAGE[xyz]::
		$f = $1; 
		$src = $3; 
		$target = $2;
		## strip [] from target set.
		if ((defined $target) && ($target ne '')) { $target =~ s/^\[(.*)\]$/$1/o; }
		}
	else {
		$f = 'SMARTLOAD';
		}
#	print STDERR "PG: $PG TAG: $tag\n";
#	print STDERR "F: $f $src [$target]\n";

	my %FUNCS = (
		'FLOW'=>sub { 
			if ($_[0] eq 'USERNAME') { return($_[1]->username()); }
			elsif ($_[0] eq 'WRAPPER') { return($SITE->URLENGINE()->wrapper()); }
			elsif ($_[0] eq 'PROD') { return($_[1]->pid()); }
			elsif ($_[0] eq 'SKU') { return($_[1]->sku()); }
			elsif ($_[0] eq 'LAYOUT') { return($_[1]->docid()); }
			# elsif ($_[0] eq 'PROFILE') { return($_[1]->profile()); }
			elsif ($_[0] eq 'PG') { return($_[1]->pageid()); }
			# elsif ($_[0] eq 'LAST_LOGIN') { return(&SITE::last_login()); }
			# elsif ($_[0] eq 'LOGIN') { return(&SITE::request_login()); }
			elsif ($_[0] eq 'LAST_LOGIN') { return($_[1]->cart2(undef,0)->in_get('customer/login')); }
			elsif ($_[0] eq 'LOGIN') { return($_[1]->cart2(undef,0)->in_get('customer/login')); }
			elsif ($_[0] eq 'SDOMAIN') { return($_[1]->sdomain()); }
			},
		'URL'=>sub { return($_[1]->URLENGINE()->get($_[0])); },
		'VAR'=>sub { return($SITE::v->{lc($_[0])}); },
		'THEME'=>sub { return($SITE::CONFIG->{'%THEME'}->{lc($_[0])}); },
		'CSS'=>sub { return($SITE::CONFIG->{'%CSSVARS'}->{lc($_[0])}); },
		'CONFIG'=>sub { return($SITE::CONFIG->{$_[0]}); },
		'WEBDB'=>sub { return($_[1]->webdb()->{lc($_[0])}); },
		'SAFEVAR'=>sub { return(URI::Escape::XS::uri_escape($SITE::v->{lc($_[0])})); },
		'SREF'=>sub { 
			# print STDERR "GETTING: $_[0]\n";
			if ($_[0] eq '_CWPATH') { 
				return($_[1]->servicepath()->[1]);
				}
			else {
				return($_[1]->sget($_[0])); 
				}
			},
		'CART2'=>sub {
			my ($src,$SITE,$target) = @_;
			if (not defined $SITE->cart2(undef,0)) { 
				return("/*<!-- CORRUPT CART -->*/");
				}
			elsif ($CART2::VALID_FIELDS{$target}) {
				return( $SITE->cart2(undef,0)->pu_get( $target ) );
				}
			else {
				return("/*<--  INVALID $src -->*/");
				}
			},
		'CART'=>sub {
			if (not defined $_[1]->cart2(undef,0)) { 
				return([]);
				}
			elsif ($_[0] =~ /^\@(coupons)[\?]?(.*?)$/) {
				my $v = $1;
				my ($params) = &ZTOOLKIT::parseparams($2);
				## CART::@coupons?filterkey=filterparam			
				if (substr($v,0,7) eq 'coupons') {
					return($_[1]->cart2(undef,0)->coupons(%{$params}));
					}
				else {
					return(["unknown v: $_[0]"]);
					}
				}
			elsif (defined($CART2::LIVE_MACROS{$_[0]})) {
				## LIVE_MACROS in the cart are properties that are computed when requested ..
				## 2012/10/09 DEFINITELY STILL IN USE 
				## $CART2::LIVE_MACROS{$_[0]}->($SITE::CART2);
				## 2013/01/17
				$CART2::LIVE_MACROS{$_[0]}->( $_[1]->cart2(undef,0) );
				## &ZOOVY::confess($USERNAME,"LEGACY LIVE MACRO: $_[0]",justkidding=>1);
				}
			else {
				# print STDERR "FETCHING: $_[0]\n";
				return($_[1]->cart2(undef,0)->legacy_fetch_property($_[0])); 
				} 
			},
		'CUSTOMER'=>sub {
			## look in CUSTOMER.pm around line 35 for a list of variables.
			my ($var) = $_[0];

			print STDERR "VAR: [$var]\n";

			if ($var eq 'INFO.PASSWORD') { return(["password not available"]); }

			if (not defined $SITE::CART2) {
				return([]);
				}
			my ($C) = $SITE::CART2->customer();
			if (not defined $C) {
				return([]);
				}
			return($C->get($var));
			},
		'PAGE'=>sub {
			# PAGE[.secondact.brand]::meta_description
			## can be PAGE[pagename]::variable
			## or PAGE::variable for the current page
			my ($PG,$SITE,$tag) = ($_[2],$_[1],$_[0]);
			# print STDERR "SRC: $src [$PG] [$tag]\n";
		
			if ($PG eq '') {
				## loads from the current page in memory
				return($SITE->pAGE()->get($tag));
				# return(&TOXML::RENDER::smart_load($SITE,"page:$tag"));
				}
			else {
				## Loads a variable from a page OTHER than the one in focus
				$PG =~ s/^\[(.*)\]$/$1/;	# strip the [ and ] 
				my ($PG) = $SITE->pAGE($PG);
				return($PG->get($tag));
				}
			},			
		'PROFILE'=>sub { 
			if (not defined $SITE) { return(''); }
			if (not defined $SITE->nsref()) { return(''); }
			return($SITE->nsref()->{$_[0]}); 
			},
		'INVENTORY'=>sub {
			# elsif ($src =~ m/^INVENTORY(\[[A-Za-z0-9_\#\:]+\])?\:\:(INSTOCK|RESERVED|AVAILABLE)$/o) {
			## INVENTORY::INSTOCK will load the current SKU in focus
			## INVENTORY[XYZ]::INSTOCK will load the inventory for SKU xyz

			my ($SKU,$mode) = ($_[2],$_[0]);

			if ($SKU eq '') {
				$SKU = $SITE::SREF->{'_SKU'};
				}
			$SKU = uc($SKU);
			#if ($SITE::SREF->{'+published'}) {
			#	return('AVAILABLE');
			#	}
		
			my $RESULT = undef;
			my ($invref,$reserveref) = INVENTORY2->new($USERNAME)->fetch_qty('@SKUS'=>[$SKU]);
			if ($mode eq 'INSTOCK') { $RESULT = $invref->{$SKU}; }
			elsif ($mode eq 'RESERVED') { $RESULT = $reserveref->{$SKU}; }
			elsif ($mode eq 'AVAILABLE') { $RESULT = $invref->{$SKU} - $reserveref->{$SKU}; }
			return($RESULT);
			},
		'SMARTLOAD'=>sub {
			## $SITE,$src
			# print STDERR "SMART LOAD: $_[0]\n";
			return(&TOXML::RENDER::smart_load($_[1],$_[0])); 
			},
		);



	if (not defined $FUNCS{$f}) {
		warn "Unknown func: $f";
		}
	else {
		$RESULT = $FUNCS{$f}->($src,$SITE,$target);
		}

	# $RESULT = '';
	return($RESULT);
	}


########################################
# render readonly
sub RENDER_READONLY {
	my ($iniref,undef,$SITE) = @_;    
	# iniref is a reference to a hash of the element's contents as defined in the flow file

	## hmm.. some fucked up HTMLWIZARDs really want to use DATA instead of LOAD so we'll support both
	if (not defined $iniref->{'LOAD'}) { $iniref->{'LOAD'} = $iniref->{'DATA'}; }

	# $iniref->{'LOAD'} =~ s/[\n\r]+//igs;
	my $BUF = &TOXML::RENDER::loadURP($SITE,$iniref->{'LOAD'});
	# if ($SITE::pbench) { $SITE::pbench->stamp("Loading $iniref->{'LOAD'}"); }

	if (not defined $BUF) {
		if (defined $iniref->{'ERROR'}) { $BUF = $iniref->{'ERROR'}; }
		else { $BUF = ''; }
		}

	if (not defined $iniref->{'FORMAT'}) { $iniref->{'FORMAT'} = ''; }

	if (($iniref->{'FORMAT'} eq 'PRICE') || ($iniref->{'FORMAT'} eq 'PLAINPRICE')) {
		# FLOW::PRICE is used to override the price in a product listing
		# Override if we have a price set as a flow global (used for external sales, see claim.cgis)
		# We could do other things with this, like setting transparent discounts and such
		if (defined $SITE->{'_CLAIM'}) {
			$BUF = $SITE->{'%incompleteref'}->{'zoovy:base_price'};
			}
		if ($BUF eq '') { return ''; } # Blank prices return nothing
		if (($BUF == 0) && ($iniref->{'HIDEZERO'})) { return ''; }
		if ($iniref->{'CURRENCY'} eq '') { $iniref->{'CURRENCY'} = 'USD'; }

		if ($iniref->{'FORMAT'} eq 'PRICE') {
			## Pogs used to be username:pogs, now they're zoovy:pogs
			my $pogs = &TOXML::RENDER::smart_load($SITE,'product:zoovy:pogs');
			if (not defined $pogs) { $pogs = ''; }

			if (($BUF == 0) && ($pogs ne '')) {
				if (not defined $iniref->{'ZEROPRICEOPTIONMSG'}) { 
					$iniref->{'ZEROPRICEOPTIONMSG'} = 'Please select from options below.';
					}
				$BUF = '<b>Price: </b> ' . $iniref->{'ZEROPRICEOPTIONMSG'};
				}
			else {
				$BUF =~ s/^\$//;
				$BUF = '<b>Price: </b> ' . &ZTOOLKIT::moneyformat($BUF,$iniref->{'CURRENCY'});
				}
			}
		elsif ($iniref->{'FORMAT'} eq 'PLAINPRICE') {

			if ($iniref->{'CURRENCY'} eq 'USD') {
				$BUF = sprintf("%.2f",$BUF);
				}
			else {
				require ZTOOLKIT::CURRENCY;
				$BUF = &ZTOOLKIT::CURRENCY::convert($BUF,'USD',$iniref->{'CURRENCY'});
				}
			}
		
		}

	if ($BUF eq '') { return(''); }
	$BUF = ((defined $iniref->{'PRETEXT'})?$iniref->{'PRETEXT'}:'').$BUF.((defined $iniref->{'POSTTEXT'})?$iniref->{'POSTTEXT'}:'');

	if (not defined $iniref->{'RAW'}) { $iniref->{'RAW'} = $SITE::OVERLOADS{'site.css'}; }
	if (($BUF ne '') && (not $iniref->{'RAW'})) {
		$BUF = qq~<font class="ztxt">$BUF</font>~;
		}

	return ($BUF);
} ## end sub RENDER_READONLY


sub RENDER_TEXTCHOICE
{
	my ($iniref) = @_;

}




########################################
# render prodlist
#
# a bit screwy, so 
#		$iniref->{'DATA'} == where we load and save preference settings
#		$iniref->{'SRC'}  == where we retrieve the products from (can be configured in data)
#
sub RENDER_PRODLIST {
	my ($iniref,$toxml,$SITE) = @_;    # ini is a reference to a hash of the element's contents	


	# $iniref->{'DEBUG'} = 99;	# output to STDERR
	my @DEBUG = ();

	if ($iniref->{'DEBUG'}) {
		push @DEBUG, "DEBUGGING ELEMENT: $iniref->{'ID'}";
		push @DEBUG, "INPUT INIREF: ".&ZOOVY::incode(Dumper($iniref));
		# push @DEBUG, "SREF: ".&ZOOVY::incode(Dumper($SITE));
		}

	my $SKU = $SITE->{'_PID'};
	if (defined $SITE->{'_SKU'}) { $SKU = $SITE->{'_SKU'}; }
	my $USERNAME = $SITE->username();

	my $preview;
	if (defined($iniref->{'PREVIEW'}) && $iniref->{'PREVIEW'}) { $preview = 1; }
	else { $preview = 0; }

	# Set up %webdb
	my $webdbref = $SITE->webdb();

	my $out = '';

	# Load info from page
	my $DATA = &ZOOVY::dcode(&TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'}));

	## NOTE: DEFAULT must be loaded here, so we can treat it as either legacy format, or current format.
	if ($DATA eq '') { $DATA = &ZOOVY::dcode($iniref->{'DEFAULT'}); }
	my $params = &TOXML::RENDER::parse_prodlist_data($DATA,$iniref,$SITE);

   if ($params->{'FORMAT'} eq '') { $params->{'FORMAT'} = 'DEFAULT'; }
	if ($params->{'FORMAT'} eq 'DEFAULT') {
		$DATA = $webdbref->{'PRODLIST_DEFAULT'};
		$params = &TOXML::RENDER::parse_prodlist_data($DATA,$iniref,$SITE);		
		}

	## NOTE: eventually we should rename the following variables:
	##		MAX becomes PRODUCTS_MAX
	##		SMARTMAX gets copied into MAX
	if (not defined $params->{'FORMAT'}) { $params->{'FORMAT'} = 'THUMB';  }
	if (not defined $params->{'COLS'}) { $params->{'COLS'} = 3; }
	if (not defined $params->{'SORTBY'}) { $params->{'SORTBY'} = ''; }
	if (not defined $params->{'MAX'}) { $params->{'MAX'} = '500'; } # What is the maximum number of items we show from a category source

	if (not defined $params->{'ALTERNATE'}) 	{ $params->{'ALTERNATE'} 			= 1; } 	
	if (not defined $params->{'SMARTMAX'})  	{ $params->{'SMARTMAX'}				= '12'; } # What is the maximum number of items we show from a smart source
	if (not defined $params->{'VIEWDETAILS'}) { $params->{'VIEWDETAILS'}      	= 1; } # Show the View Details link in the list
	if (not defined $params->{'SHOWSKU'})     { $params->{'SHOWSKU'}	         = ''; } # Determines if/where the SKU will be shown with the product name
	if (not defined $params->{'SHOWQUANTITY'}){ $params->{'SHOWQUANTITY'}     	= 0; } # Add a quantity textbox for multiple-add to cart
	if (not defined $params->{'SHOWNOTES'})   { $params->{'SHOWNOTES'}        = 0; } # Have the ability to edit product notes right inside the prodlist element
	if (not defined $params->{'SHOWPRICE'})   { $params->{'SHOWPRICE'}        = 1; } # Have the showing of prices on by default
	if (not defined $params->{'SRC'}) { $params->{'SRC'}      = ''; } # Where do we get the smart source from (based on associated categories, etc)
	if (not defined $params->{'SHOWDEFAULT'}) {  $params->{'SHOWDEFAULT'} = 1; } # automatically load products from homepage if non found in a list.
	if (defined $iniref->{'SHOWDEFAULT'}) { $params->{'SHOWDEFAULT'} = $iniref->{'SHOWDEFAULT'}; }
	if (not defined $iniref->{'INVENTORY'}) { $iniref->{'INVENTORY'} = 0; } # GOLD ONLY: should we display inventory status in the prod list.  

	## We need to be able to force a prodlist to have the price selectable as being displayed or not.  
	my $changeprice = defined($iniref->{'CHANGESHOWPRICE'}) ? $iniref->{'CHANGESHOWPRICE'} : 0 ;

	my $max      = $params->{'MAX'} || 500;

	my @products = ();
	# my $productsref = undef;
	my $Productsref = undef;

	if (($SKU ne '') && ($SITE->fs() eq 'P')) {
		## DEFAULT PRODUCTS PAGES TO USE RELATED_PRODUCTS
		if ($params->{'SRC'} eq '') { 
			$params->{'SRC'} = 'PRODUCT:zoovy:related_products'; 
			if (scalar(@DEBUG)) { push @DEBUG, "SETTING SOURCE TO $params->{'SRC'} because SKU='' and FS=P"; }
			}		
		}

	if (($iniref->{'SRC'} eq '') && ($SITE->fs() eq 'C')) {
		## DEFAULT CATEGORY PAGES TO USE THEMSELVES
		my $CWPATH = $SITE->servicepath()->[1];
		if ($params->{'SRC'} eq '') { 
			$params->{'SRC'} = 'NAVCAT:'.$CWPATH;
			if (scalar(@DEBUG)) { push @DEBUG, "SETTING SOURCE TO $params->{'SRC'} because SRC='' and FS=C"; }
			}	
		}

	## The PRODSEARCH element is basically a wrapper around the PRODLIST element
	##	it takes a few unique variables (that we will *eventually* allow to be passed on SRC=SEARCH:)
	if ($iniref->{'TYPE'} eq 'PRODSEARCH') {
		require SEARCH; # Not verified use strict yet
		
		## you can either pass KEYWORDS= or KEYWORDSURP (which will LOADURP from the variable)
		##		the default variable if none is passed is VAR::keywords
		if (not defined $iniref->{'KEYWORDS'}) {
			if (not defined $iniref->{'KEYWORDSURP'}) { $iniref->{'KEYWORDSURP'} = 'VAR::keywords'; }
			$iniref->{'KEYWORDS'} = &loadURP($SITE,$iniref->{'KEYWORDSURP'});
			}
		if (not defined $iniref->{'MODE'}) {
			if (not defined $iniref->{'MODEURP'}) { $iniref->{'MODEURP'} = 'VAR::mode'; }
			$iniref->{'MODE'} = uc(&loadURP($SITE,$iniref->{'MODEURP'}));		
			}
		if ((not defined $iniref->{'MODE'}) || ($iniref->{'MODE'} eq '')) { 
			$iniref->{'MODE'} = 'AND'; 
			}

		if (($iniref->{'MODE'} eq 'FINDER') && (not defined $iniref->{'CATALOG'})) {
			## DEFAULT TO A CATALOG OF BLANK
			$iniref->{'CATALOG'} = uc(&loadURP($SITE,$iniref->{'CATALOGURP'}));
			if (not defined $iniref->{'CATALOG'}) { $iniref->{'CATALOG'} = ''; }
			}
		$params->{'SRC'} = 'SEARCH:';

		if (scalar(@DEBUG)) { push @DEBUG, "PRODSEARCH SRC=$params->{'SRC'} MODE=$iniref->{'MODE'} KEYWORDS=$iniref->{'KEYWORDS'}"; }
		}

	
	# print STDERR 'RENDER_PRODLIST final params! '.Dumper($params);

	if (scalar(@DEBUG)) { push @DEBUG, "GOING TO LOAD SRC=$params->{'SRC'}\n"; }


	$SITE::DEBUG && print STDERR sprintf("RENDER_PRODLIST iniref->ID=%s params->SRC=%s\n",$iniref->{'ID'},$params->{'SRC'});

#	my $MEMKEY = $SITE->username().$SITE->prt().$toxml->docid()."|";
#	$MEMKEY .= $SITE->pageid().'|';
#	$MEMKEY .= $SITE->pid().'|';
#	$MEMKEY .= $SITE->sdomain().'|';
#	foreach my $k (sort keys %{$params}) { $MEMKEY .= "|$params->{$k}"; }
#	foreach my $k (sort keys %{$iniref}) { $MEMKEY .= "|$iniref->{$k}"; }
#	foreach my $k (sort keys %{$SITE::v}) { $MEMKEY .= "|$SITE::v->{$k}"; }
#	my $MEMKEY = "prodlist+".Digest::MD5::md5_hex($MEMKEY);

#	my $memd = &ZOOVY::getMemd($USERNAME);
#	if (defined $memd) {
#		my $OUTPUT = $memd->get($MEMKEY);
#		if ((defined $OUTPUT) && ($OUTPUT ne '')) {
#			open F, ">>/tmp/prodlist.cache";
#			print F $MEMKEY."\n";
#			close F;	
#			return($OUTPUT);
#			}
#		}
	
	if (defined $SITE->{'@results'}) {
		## Umm... how does this get set? 
		## answer: SEARCH! search sets the sref->{@results} variable! 

		if ($iniref->{'TYPE'} ne 'PRODSEARCH') {
			open F, ">>/tmp/displayed-results-in-a-prodlist.log";
			print F sprintf("%d\t%s\t%s\t%s\t%s\t%s\t%s\n",time(),$SITE->username(),$SITE->username(),$SITE->docid(),$iniref->{'TYPE'},$iniref->{'ID'});
			close F;
			}

		if (scalar(@DEBUG)) { push @DEBUG, "PRODSEARCH using passed (in memory) \@results\n"; }
		$TOXML::RENDER::DEBUG && &msg("Using passed \@results list");
		@products = @{$SITE->{'@results'}};
		delete $SITE->{'@results'};
		}
	elsif ($params->{'SRC'} =~ /^SEARCH\:/) {
		## eventually .. SEARCH:mode=and&keywords=asdf perhaps? 
		## note the ^SEARCH:(.*?) was intentionally left blank so it's clear that we didn't
		## define the behavior when we created this element.
		my $debug = 0;

		$params->{'SHOWDEFAULT'} = 0;
		my $keywords = $iniref->{'KEYWORDS'};


		if ($iniref->{'MODE'} eq 'FINDER') {
			if (scalar(@DEBUG)>0) { push @DEBUG, "ENTERING FINDER"; }
			## FINDERVARS is a set of key value pairs e.g. A0=>"01"
			my ($resultref) = undef;
			if ((defined $iniref->{'QUERY'}) && ($iniref->{'QUERY'} ne '')) {
				## uri list of params e.g. A0=00&A1=01
				my $qvars = &ZTOOLKIT::parseparams($iniref->{'QUERY'});
				($resultref) = &SEARCH::finder($SITE, $qvars);
				}
			else {
				## use SITE::v 
				($resultref) = &SEARCH::finder($SITE, $SITE::v);
				}
		
			if ((((not defined $resultref) || (scalar @{$resultref})==0))) {
				@products = ();
				}
			else {
				@products = @{$resultref};
				}
			if (scalar(@DEBUG)>0) { push @DEBUG, "FINISHED FINDER"; }
			}
		elsif ((not defined $keywords) || ($keywords eq '')) {
			if (scalar(@DEBUG)>0) { push @DEBUG, "!!! KEYWORDS NOT SET DOING NOTHING"; }
			@products = ();
			}
		else {			
			## SEARCH code - non-finder
			if (scalar(@DEBUG)>0) { push @DEBUG, "ENTER SEARCH CODE"; }

			print STDERR $SITE->username()." MODE=>$iniref->{'MODE'} KEYWORDS=>$keywords\n";

			@products = ();
			## SEARCH::LEGACY was here 
			# require SEARCH::LEGACY;
			(my $resultref, my $pids, my $errlog) = &SEARCH::search($SITE,
				MODE=>$iniref->{'MODE'},
				KEYWORDS=>$keywords,
				PRT=>$SITE->prt(),
				# i think this is what that asshole JT wants:
		 		ROOT=>$iniref->{'ROOT'},
				CATALOG=>$iniref->{'CATALOG'},
				'*NC'=>$SITE->{'*NC'},
				'debug'=>$debug);

			if (defined $resultref) {
				@products = @{$resultref};
				}

			if ($debug) {
				foreach my $line (@{$errlog}) {
					push @DEBUG, $line;
					}
				}
			if (scalar(@DEBUG)>0) { push @DEBUG, "FINISHED SEARCH CODE"; }
			}		

		# print STDERR Dumper(\@products);
		}
	elsif ($params->{'SRC'} =~ /^PRODUCT\:(.*?)$/) {
		## SRC=PRODUCT:xxxx
		my $attrib = 'zoovy:related_products';
		if ($1 ne '') { $attrib = $1; }
		## This is a product flow (used in a product context)
		## so we'll use the zoovy:related_products
		# my ($pref) = &ZOOVY::fetchproduct_as_hashref($USERNAME,$SKU);
		my ($P) = PRODUCT->new($USERNAME,$SKU);
		# my $PRODS = $pref->{$attrib};
		my $PRODS = '';
		if (defined $P) { $PRODS = $P->fetch($attrib); }

		# my $PRODS = &ZOOVY::fetchproduct_attrib($USERNAME,$SKU,$attrib);
		# print STDERR "fetching: $USERNAME,$SKU,$attrib [$PRODS]\n";

		if ($PRODS eq '') {
			## if PRODS is blank, we use the homepage
			# (undef,undef,$PRODS) = &NAVCAT::fetch_info($USERNAME,'.');

			## NOTE: this should be handled later on, which respects the SHOWDEFAULT parameter. 
			#	my ($NC) = NAVCAT->new($USERNAME);
			#	(undef,undef,$PRODS) = $NC->get('.');
			#	undef $NC;
			}

		@products = ();
		foreach my $related_prod (split(/,/,$PRODS)) {	
			$related_prod = &ZTOOLKIT::trim($related_prod);
			next if ($related_prod eq '');
			push @products, $related_prod;
			}
		}
	elsif ($params->{'SRC'} =~ /^SMART\:(.*?)$/) {
		## SRC=SMART:xxxx
		my $type = $1; 

		if ($type eq 'BYCATEGORY') { $type = 'CART_RELATED_PRODCATS'; }
		elsif ($type eq 'BYPRODUCT') { $type = 'CART_RELATED_PRODUCTS'; }

		if ($type eq 'VISITED') {
			@products = split(/,/,$SITE::CART2->in_get('app/memory_visit'));
			}
		elsif ($type eq 'ADDEDCART') {
			@products = split(/,/,$SITE::CART2->in_get('app/memory_cart'));
			}
		elsif ($type eq 'CART_RELATED_PRODCATS') {
			$TOXML::RENDER::DEBUG && &msg("Using Smart Cart by category");
			my @SKUS = ();
			foreach my $item (@{$SITE::CART2->stuff2()->items('show'=>'real')}) { push @SKUS, $item->{'product'}; }
			@products = TOXML::RENDER::smartcart_by_category($SITE, \@SKUS,  $params->{'SMARTMAX'}, $SITE->prt());
			}
		elsif ($type eq 'CART_RELATED_PRODUCTS') {
			$TOXML::RENDER::DEBUG && &msg("Using Smart Cart by product");
			my @SKUS = ();
			foreach my $item (@{$SITE::CART2->stuff2()->items('show'=>'real')}) { push @SKUS, $item->{'product'}; }
			@products = TOXML::RENDER::smartcart_by_product($USERNAME, \@SKUS, $params->{'SMARTMAX'});
			}
		elsif ($type eq 'PROD_RELATED_PRODCATS') {
			## a little different, works off focus sku to detel
			@products = TOXML::RENDER::smartcart_by_category($SITE, [$SKU],  $params->{'SMARTMAX'}, $SITE->prt());			
			}
		elsif ($type eq 'ACCESSORIES') {
			$TOXML::RENDER::DEBUG && &msg("Using Smart Cart Accessories");
			@products = ();
			foreach my $item (@{$SITE::CART2->stuff2()->items('show'=>'real')}) {
				my ($P) = $SITE::CART2->stuff2()->getPRODUCT($item->{'product'});
				if (defined $P) {
				   my $accessories = $P->fetch('zoovy:accessory_products');
				   foreach (split(/\,/, $accessories)) {
				      next if ($_ eq '');
				      push @products, $_;
				      }
					}
			   }
			}

		if ($params->{'SMARTMAX'}>0) {
			## Set the length of the @products array to the limit if its past
			if (scalar(@products) > $params->{'SMARTMAX'}) { $#products = ($params->{'SMARTMAX'} - 1); } 
			}
		}
	elsif ($params->{'SRC'} =~ /^KEY\:(.*?)=(.*?)$/) {
		my $KEY = $1; my $VAL = $2;
		}
	elsif ($params->{'SRC'} =~ /^LIST\:(.*?)$/) {
		## SRC=LIST:xxxx
		my $othercat = $1;
		# $TOXML::RENDER::DEBUG = 1;
		$TOXML::RENDER::DEBUG && &msg("Using products from other category $othercat");

		my ($NC) = &SITE::get_navcats($SITE);
		my ($pretty,$children,$productstr,$sortby,$metaref) = $NC->get($othercat);
		undef $NC;

		if (substr($productstr,0,1) eq ',') { $productstr = substr($productstr,1); }	# strip leading ,
		if (substr($productstr,-1) eq ',') { $productstr = substr($productstr,0,-1); }	# strip trailing ,
		if (not defined $productstr) { $productstr = ''; }
		$TOXML::RENDER::DEBUG && &msg("Substitued comma $productstr = '$productstr'");
		@products = split (/\,/, $productstr);
		}
	elsif ($params->{'SRC'} =~ m/^[Nn][Aa][Vv][Cc][Aa][Tt]\:(\.[a-z0-9_\-\.]+)$/o) {
		## SRC=NAVCAT:xxxx
		## note: this regex needs to be insensitive because of the legacy "navcat:...." notation!
		my $othercat = $1;

		# my ($pretty, $children, $productstr) = &NAVCAT::fetch_info($USERNAME, $othercat);
		my ($NC) = &SITE::get_navcats($SITE);
		my (undef,undef,$productstr) = $NC->get($othercat);
		undef $NC;

		if (scalar(@DEBUG)) { push @DEBUG, "Using products from category: $othercat\nproducts: $productstr\n"; }

		if (substr($productstr,0,1) eq ',') { $productstr = substr($productstr,1); }	# strip leading ,
		if (substr($productstr,-1) eq ',') { $productstr = substr($productstr,0,-1); }	# strip trailing ,		
		if (not defined $productstr) { $productstr = ''; }
		$TOXML::RENDER::DEBUG && &msg("\$productstr = '$productstr'");
		@products = split (/\,/, $productstr);
		}
	elsif ($params->{'SRC'} =~ m/^PAGE\:(.*?)$/i) {
		my $var = $1;
		my $p = PAGE->new($USERNAME,$SITE->pageid(),DOMAIN=>$SITE->domain_only(),PRT=>$SITE->prt());
		
		my $productstr = '';
		if (defined $p) { ($productstr) = $p->get($var); }
		undef $p;

		if (substr($productstr,0,1) eq ',') { $productstr = substr($productstr,1); }	# strip leading ,
		if (substr($productstr,-1) eq ',') { $productstr = substr($productstr,0,-1); }	# strip trailing ,
		@products = split (/\,/, $productstr);
		}
	elsif ($params->{'SRC'} eq 'CART') {
		@products = ();
      if (defined $SITE::CART2) {
			warn "PRODLIST with CART as source will/may break in future\n";
			foreach my $item (@{$SITE::CART2->stuff2()->items()}) {
				@products = $item->{'stid'};
				}
			}		
		}
	elsif ($params->{'SRC'} =~ /^CSV:(.*?)$/) {
		@products = split(/,/,$1);
		}
	elsif ($params->{'SRC'} =~ /^RSS:(.*?)$/) {
		## ~/feeds/path.to.file.xml
		my $file = ($1); # "~/feeds/games-playstation_2.xml";
		my $buf = undef;

		my $cachefile = $file;
		$cachefile =~ s/[^\w]+/_/g;	## make 
		($cachefile) = &ZOOVY::cachefile($USERNAME,"$cachefile.bin");
		print STDERR "CACHE: $cachefile\n";
		my $ts = &ZOOVY::touched($USERNAME,0);
		(undef,undef,undef,undef,undef,undef,undef,undef,undef,my $mtime) = stat($cachefile);
		if (($ts <= $mtime) && ($mtime>0)) {
			## load from cache.
			warn "Loading from cache: $cachefile\n";
			my $ref = Storable::retrieve($cachefile);
			@products = @{$ref};
			$cachefile = undef;		## this tells us not to store cache later on.
			}
 		elsif (substr($file,0,2) eq '~/') {
			$file = substr($file,2);
			$file =~ s/[\/]+/\//g;	## replace // with /
			$file =~ s/[\.]+/\./g;	## replace .. with .
			
			my $userpath = &ZOOVY::resolve_userpath($USERNAME);
			my $localfile = $userpath.'/IMAGES/'.$file;

			my $fh = new IO::File "$localfile", "r"; 
			if (defined $fh) {
				$/ = undef; $buf = <$fh>; $/ = "\n";
				undef $fh;
				}			
			}
		else {
			die("remote RSS files not supported (YET)");
			}
		

		if (scalar(@products)>0) {
			## must have gotten this from a cache
			# die();
			}		
		elsif (defined($buf)) {
			# print STDERR Dumper($buf)."\n";
			if (substr($file,-4) eq '.txt') {
				@products = split(/[\,\t\n\r]+/,$buf);
				}
			else {	
				## assume we're dealing with .xml
				my $xs = new XML::Simple(KeyAttr=>'',ForceArray=>1);
				my ($ref) = $xs->XMLin($buf);
				$ref = $ref->{'item'};
				if (ref($ref) eq 'ARRAY') {
					foreach my $node (@{$ref}) {
						push @products, $node->{'ecommerce:SKU'}->[0];
						}
					}
				$ref = undef;
				}
			}

		if (defined $cachefile) {
			Storable::nstore(\@products, $cachefile);				
			chmod(0777, $cachefile);
			chown($ZOOVY::EUID,$ZOOVY::EGID, $cachefile);
			}
		
#		print STDERR Dumper(\@products);
		}


	# If smartcart returned nothing, or we never called smartcart, then use the category's products
	if ((scalar @products)>0) {
		## whoop we have products, don't go any further
		if (scalar(@DEBUG)) { push @DEBUG, sprintf("Found %d products",scalar(@products)); }
		}
	elsif (substr($SITE->pageid(),0,1) eq '@') {}	## SHOWDEFAULT doesn't work for CAMPAIGNS
	elsif (int($params->{'SHOWDEFAULT'})==1) {
		## show the products on the homepage
		if (scalar(@DEBUG)) { push @DEBUG, "No products found, using SHOWDEFAULT=1 settings.\n"; }

		$TOXML::RENDER::DEBUG && print STDERR sprintf("\$SITE->pageid() = SRC:'%s'\n",$SITE->pageid());
		# Get the path / products
		my $merchant_path;

		#if ($SITE->pageid() eq 'homepage') { $merchant_path = '.'; }
		#elsif ($SITE->pageid() eq 'product') { $merchant_path = '.'; }
		if ($SITE->pageid() eq 'homepage') { $merchant_path = $SITE->rootcat(); }
		elsif ($SITE->pageid() eq 'product') { $merchant_path = $SITE->rootcat(); }
		elsif ($SITE->pageid() eq 'cart') { $merchant_path = '*cart'; }
		elsif (substr($SITE->pageid(), 0, 1) eq '*') { $merchant_path = $SITE->pageid(); } # Special pages (don't encode)
		elsif (substr($SITE->pageid(), 0, 1) eq '.') { $merchant_path = $SITE->pageid(); } # pre-encoded pages! 
		else { $merchant_path = '.' . $SITE->pageid(); } # Category pages (need to be encoded)

		my ($NC) = &SITE::get_navcats($SITE);
		my ($pretty, $children, $productstr) = $NC->get($merchant_path); 
		undef $NC;
		# my ($pretty, $children, $productstr) = &NAVCAT::fetch_info($USERNAME, $merchant_path);
		if (not defined $productstr) { $productstr = ''; }
		if (substr($productstr,0,1) eq ',') { $productstr = substr($productstr,1); }	# strip leading ,
		if (substr($productstr,-1) eq ',') { $productstr = substr($productstr,0,-1); }	# strip trailing ,
		($TOXML::RENDER::DEBUG) && &msg("LOADING DEFAULTS: [$USERNAME] pretty[$pretty] safe=[$merchant_path] \$productstr = '$productstr'");
		@products = split (/\,/, $productstr);
		}

	#if ($iniref->{'ID'} eq 'SPECL_PRODLIST') {
	#	print STDERR "SORTBY: $params->{'SORTBY'}\n";
	#	}


	## Set the length of the @products array to the limit if its past
	if ($params->{'SORTBY'} eq 'RANDOM') {
		}	## RANDOM SORTS NEVER GET TRUNCATED
	elsif ($iniref->{'PRODUCTS_SKIP'}>0) {
		@products = splice @products, int($iniref->{'PRODUCTS_SKIP'}), $max;
		}
	else {
		## Truncate the list size
		if (($max > 0) && (scalar(@products) > $max)) { 
			$#products = ($max - 1); 
			}

		if ($params->{'SORTBY'} eq '') {}
		elsif ($params->{'SORTBY'} eq 'NONE') {}
		elsif (index($params->{'SORTBY'},':')>0) {
			## sort by product attribute 
			my $rev = 0;  
			if (substr($params->{'SORTBY'},0,1) eq '!') { 
				$params->{'SORTBY'} = substr($params->{'SORTBY'},1); 
				$rev++;
				}

			require PRODUCT::BATCH;
			@products = PRODUCT::BATCH::sort_by_attrib($USERNAME,$params->{'SORTBY'},\@products);
			if ($rev) { 
				@products = reverse @products;
				}
			if (scalar(@DEBUG)) { push @DEBUG, "Ran SORTBY=$params->{'SORTBY'}\n"; }
			}
		}



	$TOXML::RENDER::DEBUG && &msg(\@products, '*products');

	my ($Oref,$Rref) = (undef,undef);
	if (($iniref->{'INVENTORY'}>0) && (scalar(@products)>100)) {
		## no inventory results on more than 100 listings. 
		$iniref->{'INVENTORY'} = 0;
		}

	if (scalar(@products)==0) {
		## no products!
		}
	elsif ($iniref->{'INVENTORY'}>0) {
		## we need to check inventory		
		## +1 = load inventory values, and use "default legacy settings"
		## +2 = load inventory values
		## 	+4 = filter by on shelf
		##		+8 = filter by on shelf - reserve (available)
		## so the legacy value of "1" - is now "2+4"
		if ($iniref->{'INVENTORY'}==1) { $iniref->{'INVENTORY'} = 2+4; }

		if (scalar(@DEBUG)) { push @DEBUG, "Verifying INVENTORY (this could take a while)\n"; }
	
		## this is by far the fastest!
		## NOTE: we should probably run a scalar > 100 and then turn this off at that hard limit.
		## NOTE: highpointscientific was told he could use this in search results.

		## still better to call here, we might be able to use it later.
		#my ($prodsref) = &ZOOVY::fetchproducts_into_hashref($USERNAME,\@products);
		#my ($SKUSREF) = &ZOOVY::fetchskus_into_hashref($USERNAME,\@products,$prodsref);
		($Oref,$Rref) = INVENTORY2->new($USERNAME)->fetch_qty('@PIDS'=>\@products);
		foreach my $sku (keys %{$Oref}) {
			## if the product has options, combine them to come up with a "total" quantity.
			if (index($sku,':')>0) {
				my ($PID) = &PRODUCT::stid_to_pid($sku);
				$Oref->{$PID} += $Oref->{$sku};
				$Rref->{$PID} += $Rref->{$sku};
				}
			}

		## now only go through and show items which have quantity greater than zero.
		if ($iniref->{'INVENTORY'} & (4+8)) {
			my @availproducts = ();
			foreach my $prod (@products) {
				if (not defined $Oref->{$prod}) {
					# uhoh -- no inventory record! .. i guess this shouldn't show up. BH 4/1/09
					# push @availproducts, $prod;	
					}
				elsif ($iniref->{'INVENTORY'} & 4) {
					if ($Oref->{$prod}>0) {
						## hmm.. I wonder if we should pay attention to reserve? nahhh.. not now, this code should be tight.
						push @availproducts, $prod;
						}
					}
				elsif ($iniref->{'INVENTORY'} & 8) {
					if ($Oref->{$prod}-$Rref->{$prod}>0) {
						## hmm.. I wonder if we should pay attention to reserve? nahhh.. not now, this code should be tight.
						push @availproducts, $prod;
						}
					}
				}
			@products = @availproducts;
			if (scalar(@DEBUG)) { push @DEBUG, "After INVENTORY check we have ".scalar(@products)." products\n"; }
			}
		else {
			if (scalar(@DEBUG)) { push @DEBUG, "INVENTORY $iniref->{'INVENTORY'} did not filter products\n"; }		
			}
		}

	if ($iniref->{'LIMIT'}) {
		## LIMIT is different than "MAX" because "MAX" is done before sorts, inventory, etc. 
		## effectively reducing the size of the pool that we're working with - in some cases (e.g. a published element)
		## we possibly could ignore MAX and strictly use LIMIT (if LIMIT isn't set, we could use MAX then)
		my $limit = $iniref->{'LIMIT'};
		## Truncate the list size
		if (($limit > 0) && (scalar(@products) > $limit)) { 
			$#products = ($limit - 1); 
			}
		
		}


	##
	## SANITY: at this point @products contains the list of products we are going to display
	##
	if (defined $SITE::TRACK_PRODUCTS_DISPLAYED) {
		$SITE::TRACK_PRODUCTS_DISPLAYED .= ','.join(",",@products);	## e.g. nspace
		}

	## End of remove this code section

#	my $fakeproducts = 0;
#	unless (scalar @products) {
#		## Bail out if we have no products to show
#		return '' unless ($preview);
#		## OK, we got no products, and we're in preview mode...  show some example products
#		$fakeproducts = 1;
#		@products = ('EXAMPLE1','EXAMPLE2','EXAMPLE3');
#		}


	my $no_strip_html = defined($webdbref->{'prodlist_disable_strip'}) ? $webdbref->{'prodlist_disable_strip'} : 0;

	## Force_showprice is a kludge to work around the fact that SHOWPRICE
	## will be set for some themes and not for others
	my ($spec, $force_showprice) = &get_prodlist_spec($params->{'FORMAT'}, $iniref->{'HTML'});

	# print STDERR Dumper($spec);


#	use Data::Dumper;
#	return(Dumper($params,$spec));

	## Changeprice is a kludge on the kludge of force_showprice to allow custom themes
	## to have the price display selectable
	if ((not $changeprice) && $force_showprice) { $params->{'SHOWPRICE'} = 1; }
	
	
	## Get the colors, etc. we're going to use	
	## +PLINDEX  = what product number we're starting the list at (Defaults to 0)
	## +PLSIZE   = number of products shown per page (defaults to $params{'SIZE'} and secondarily to $iniref->{'SIZE'})
	## +PLURL  = URL to append params to to show other pages (Not implemented in apache/SITE.pm yet, but should be working here)
	## +PLMODE = Whether the $FLOW::PRODLISTURL is treated as a category or a CGI style page ('URL' = '/i=0/s=20') ('CGI' = '?i=0&s=20')
	
	## The default size based off of the parameters for the prodlist
	my $size = 0;
	if (($size==0) && (defined $params->{'SIZE'})) { $size = int($params->{'SIZE'}); }
	if (($size==0) && (defined $iniref->{'SIZE'})) { $size = int($iniref->{'SIZE'}); }

	# $SITE->{'+plsize'} = $size;

	my $total_pages = (scalar(@products));
	if (($total_pages==0) || ($size==0)) {
		## total_pages was zero (meaning no products) OR size was zero (no pagination)
		$size = 0;
		$total_pages = 0;
		## we have no items, so we're turning multipage off
		$iniref->{'MULTIPAGE'} = 0;
		}
	elsif (($total_pages>0) && ($size>0)) {
		## note, we have this setup like this so we only call scalar(@products) once, but we avoid the div by zero
		$total_pages = $total_pages / $size; ## Calculate the total pages based on page size and total number of products
		if ($total_pages != int($total_pages)) { $total_pages = int($total_pages+1); } ## Round $total_pages up
		
		if (defined $iniref->{'MULTIPAGE'}) {
			## multipage is already set, we don't need to do nothing!
			}
		elsif ($total_pages==1) {
			## we only have one total page, default to no multipage header.
			$iniref->{'MULTIPAGE'} = 0; 
			}
		else {
			## we have multiple pages, so default to display multipage header.
			$iniref->{'MULTIPAGE'} = 1;
			}
		}
	else {
		## this case should *never* be reached.
		warn "THIS LINE SHOULD NEVER BE REACHED. total_pages=$total_pages size=$size\n";
		}

	## This determines how we are going to treat +plsize (add a /p=1 [URL mode] or ?p=1 [CGI mode])
	# These are used by any flow with a prodlist
	my $this_page  = &ZTOOLKIT::def($iniref->{'plpage'}, $SITE::v->{'p'});

	## NOTE: the variable below (+plsize) can probably be safely removed.
	# $SITE->{'+plsize'}    = &ZTOOLKIT::def($iniref->{'plsize'}, $SITE::v->{'s'}, $SITE->{'+plsize'});
	## my $mode = defined($this_page) ? $this_page : 'CGI';
	my $mode = 'CGI';
	unless (defined($this_page) && ($this_page =~ m/^\d+$/) && $this_page) { $this_page = 1; } ## Default the page number to 1 if unavailable
	if ($this_page > 20) { $this_page = 1; }

	## Default global set of variable replacements
	## Set up some URLs we're going to use
	my $cart_url    = $SITE->URLENGINE()->get('cart_url');
	my $product_url = $SITE->URLENGINE()->get('product_url');

	my %general = (
		'HEADING'       => $params->{'SHOWQUANTITY'} ? 'Quantity' : 'Add', ## %HEADING% will be "Quantity" if SHOWQUANTITY = 1, "Add To Cart" if not
		'FORM'          => $preview ? qq~<form onSubmit="return false;">~ : qq~<form action="$cart_url" method="post">~, ## %FORM% will be Add to cart form start, bogus for preview mode
		'no_strip_html' => $no_strip_html, ## no_strip_html is just used as a param to the %blah/strip% syntax.  Passed as a parameter because that's the only easy way we could get it in there
		'TOTALPRODUCTS' => scalar(@products),
		);
	
	my %multipage = ();
	if ($iniref->{'MULTIPAGE'}) {
		## MULTI-PAGE LIST (unsorted only)
		## Make links to the next and previous pages if we're a multi-page product list

		## We can disable font tags in the element specification by setting LINKFONT=DISABLED
		# my $link_start = qq~<font color="#$TH->{'table_heading_text_color'}">~;
		my $max_pages = 11;
		my $urlstr = '';
		if (($mode eq 'URL') && ($urlstr !~ m/\/$/)) { $urlstr .= '/'; } ## Add a slash if one isn't there
		if ($mode eq 'CGI') {
			if    ($urlstr !~ m/\?/)  { $urlstr .= '?'; } ## Add a ? if the URL doesn't have one (CGI mode makes get queries)
			elsif ($urlstr !~ m/\&$/) { $urlstr .= '&'; } ## Add a & to the end so we can add more parameters
			}

		## handle multipage search results
		## added variables for FINDER search results : patti - 2006-04-11

		# print STDERR Dumper($SITE::v); die();

		my %param = ();
		foreach my $v (keys %{$SITE::v}) {
			if (defined $SITE::v->{$v} && $v ne 'p' && $v ne 's') {
				my $var = uc($v);
				$param{$var} = &ZTOOLKIT::decode($SITE::v->{$v});	# the decode unfixes parameters which were escaped for XSS
				}  
			}
		foreach my $var (keys %param) {
			$urlstr .= "$var=".&URI::Escape::XS::uri_escape($param{$var})."&";
			# $urlstr .= "$var=".&ZTOOLKIT::short_url_escape($param{$var})."&";
			}

		## Only modify URLs to include sizes if the size has been overridden (keeps URLs shorter)
		if ($size != 10) {
			$urlstr .= "s=$size&"; 
			}
		$urlstr .= 'p=';		

		if ($this_page > $total_pages) { $this_page = $total_pages; } ## Default to the last page if it's more than the total pages
		## Make the previous page link
		my $prevpage = ''; 
		my $prevurl = '';

		if ($this_page > 1) {
			$prevurl = $preview ? '#' : $urlstr.($this_page - 1);
			$prevpage .= qq~<a href="$prevurl"><font color="<% loadurp("CSS::ztable_head.color"); print(); %>">&nbsp;Previous Page</font></a>~;
			}
		## Make the next page link
		my $nextpage = ''; 
		my $nexturl = '';
		if ($this_page < $total_pages) {
			$nexturl = $preview ? '#' : $urlstr.($this_page + 1);
			$nextpage .= qq~<a href="$nexturl"><font color="<% loadurp("CSS::ztable_head.color"); default(); print(); %>">Next Page&nbsp;</font></a>~;
			}
		## Make the clickable list of pages
		my $pagelinks = '';
		## If we have just 2 pages, skip generating the link list of pages
		if ($total_pages > 2) {
			my ($firstpage,$lastpage,$start_page,$show_pages);
			if ($total_pages > $max_pages) {
				$show_pages = $max_pages; # We are going to show the maximum number of pages
				## If we have more pages to show than the amount of room we have, then we need to pick a subset of pages
				## Make the first page link (blanked out later if we don't need it)
				my $firsturl = $preview ? '#' : $urlstr.'1';
				$firstpage = qq~<a href="$firsturl"><font color="<% loadurp("CSS::ztable_head.color"); print(); %>">1</font></a>~;
				## Make the last page link (again, blanked out later if we don't need it)
				my $lasturl = $preview ? '#' : $urlstr.$total_pages;
				$lastpage = qq~<a href="$lasturl"><font color="<% loadurp("CSS::ztable_head.color"); print(); %>">$total_pages</font></a>~;
				## Add dots to show there is a range of pages missing only if there is a range missing (this prevents showing 1... 2 | 3 | 4)
				if ($total_pages > ($max_pages + 1)) { $firstpage = "$firstpage..."; $lastpage  = "...$lastpage"; }
				else                                 { $firstpage = "$firstpage |";  $lastpage  = "| $lastpage"; }
				## Are we picking a range from the beginning, middle or end of the list of pages?
				if ($this_page < (int($max_pages/2) + 3))	{
					## Beginning 
					$firstpage = ''; ## (No extra link to page 1)
					$start_page = 1; ## The first page is page 1
					}
				elsif ($this_page > ($total_pages - int($max_pages/2) - 2))	{
					## End
					$lastpage = ''; ## (No extra link to last page)
					$start_page = $total_pages - $max_pages + 1; ## The first page in the list is the last one minus the maximum number of pages
					}
				else {
					## Middle
					## (Links both to the first page and last page)
					$start_page = $this_page - int($max_pages/2); ## The first page is half the maximum back from the current one (this keeps the current page centered in the list)
					}
				}
			else {
				## We're showing the entire list of pages
				$show_pages = $total_pages;
				$start_page = 1; ## The first page is page 1
				}
			## Create the list of links to pages
			my $pages = '';
			foreach my $page ($start_page..($start_page+$show_pages-1))	{
				if ($pages ne '') { $pages .= '| ';}
				if ($page == $this_page) {
					## Don't link to the current page
					$pages .= "<b>$page</b> ";
					} 
				else {
					my $pageurl = $preview ? '#' : $urlstr.$page;
					$pages .= qq~<a href="$pageurl"><font color="<% loadurp("CSS::ztable_head.color"); print(); %>">$page</font></a> ~;
					}
				}
			$pagelinks = qq~Go To Page $firstpage $pages $lastpage~;
			}

		%multipage = (
			'PREVURL'	 => $SITE->txspecl()->translate3($prevurl,[]),
			'NEXTURL'	 => $SITE->txspecl()->translate3($nexturl,[]),
			'PREVPAGE'   => $SITE->txspecl()->translate3($prevpage,[]),
			'NEXTPAGE'   => $SITE->txspecl()->translate3($nextpage,[]),
			'THISPAGE'   => $SITE->txspecl()->translate3($this_page,[]),
			'TOTALPAGES' => $SITE->txspecl()->translate3($total_pages,[]),
			'PAGELINKS'  => $SITE->txspecl()->translate3($pagelinks,[]),
			);
		# print STDERR Dumper(\%multipage)."\n";

		@products = splice @products, (($this_page-1) * $size), $size;
		## number of items on the current page
		$multipage{'TOTALCOUNT'} = scalar(@products);
		}


	
	## After this section we'll have the following variables at our disposal:
	my $prod           = {}; ## hashref of hashes of the product properties.  $prod->{product_id}{property}
	my %availability   = (); ## hash of the availability of all the products (this determines whether we give them an "add to cart" link)
	                         ## keyed by SKU, value of 1 (product available) or 0 (product is not available)

	## SORT PRODUCT LIST (non-multipage only)
	if ($params->{'SORTBY'} eq 'RANDOM') {
		if (scalar(@DEBUG)) { push @DEBUG, "Running SORTBY=RANDOM\n"; }
		my $len = (scalar(@products) > $max) ? $max : scalar(@products);
		my @randomized = ();
		foreach (1..$len) {
			my $prod = splice(@products, int(rand(scalar @products)), 1);
			push @randomized, $prod;
			}
		@products = @randomized;
		}

	my $sch = undef;
	if ((defined $SITE::CART2) && ($SITE::CART2->in_get('our/schedule') ne '')) {
		require WHOLESALE;
		$sch = lc($SITE::CART2->in_get('our/schedule'));
		}

	## Get the product info (needed before sort)
	if (not defined $Productsref) {
		$Productsref = &PRODUCT::group_into_hashref($USERNAME,\@products);
		}

	$TOXML::RENDER::DEBUG && &msg("multipage: $iniref->{'MULTIPAGE'} / sortby : $params->{'SORTBY'}");
	## Add the SKU to the product name if we were told to
	## Alias merchant:var to actual_merchant_id:var
	$spec =~ s/\%merchant\:([\w\-\/\:]+)\%/%$USERNAME:$1%/gs;

	## Set up some variables that let us skip large sections of logic later on in the loop if the variables aren't used
	my $makepogs = 0;
	if ($spec =~ m/\%POGS\%/s)  { $makepogs  = 1; }
	if ($spec !~ m/\%NOTES\%/s) { $params->{'SHOWNOTES'} = 0; }

	if (not defined $iniref->{'POGS'}) {
		## this disables pog processing.
		$iniref->{'POGS'} = 1;
		}

	my @items = ();
	foreach my $product_id (@products) {
		next if ((not defined $product_id) || ($product_id eq ''));
		my $P = $Productsref->{$product_id}; # Shortcut variable so we don't have to dereference the product multiple times

		next if ((not defined $P) || (ref($P) ne 'PRODUCT'));
		my $prod_url = sprintf("%s%s",$product_url,$P->public_url('style'=>'vstore','internal'=>1));

		# $prod_url .= "/foo";

		## Override the URL and add to cart URL if we're in preview mode
		if ($preview) { $prod_url = '#'; }
		elsif ($P->fetch('zoovy:redir_url') ne '') { $prod_url = $P->fetch('zoovy:redir_url'); }

		my %HASH = ();

		foreach my $k (keys %{$P->prodref()}) {
			$HASH{$k} = $P->fetch($k);
			}

		if (defined $sch) {
			my $schresults = $P->wholesale_tweak_product($sch);
			# use Data::Dumper; print STDERR Dumper($schresults);
			foreach my $k (keys %{$schresults}) { $HASH{$k} = $schresults->{$k}; }
		 	}

		#open F, ">>/tmp/foo";
		#use Data::Dumper; print F Dumper($P->pid(),$P,\%HASH);
		#close F;

		if ($params->{'SHOWSKU'} eq 'before') {
			## Only add the product ID onto the name if it isn't already set
			}
		elsif ($params->{'SHOWSKU'} eq 'after') {
			$HASH{'zoovy:prod_name'} = sprintf("%s - %s",$HASH{'zoovy:prod_name'},$product_id);
			}

		## Blank out the price if we were told to.
		if (not $params->{'SHOWPRICE'}) {
			$HASH{'zoovy:base_price'} = ''; 
			}
	

		my $AVAILABLE = 1;
		## Spoof availability... we'll change it later if we restate inventory checking at the product list
		if (($iniref->{'INVENTORY'}&2) && (defined $Oref)) {
			$HASH{'zoovy:inv_qty_onhand'} = $Oref->{$product_id};
			$HASH{'zoovy:inv_qty_available'} = $Oref->{$product_id} - $Rref->{$product_id};
			$HASH{'zoovy:inv_qty_reserve'} = $Rref->{$product_id};
			if ($HASH{'zoovy:inv_qty_available'} <= 0) { $AVAILABLE = 0; }
			}

		$HASH{'PRODUCT_ID'} = $product_id;
		$HASH{'PROD_URL'} =  ($preview)?'#':$prod_url; ## Set the URL for this particular product
	
		$HASH{'ADD_URL'} = ($preview)?'#':("$cart_url?product_id=$product_id&amp;add=yes");
		if (defined $SITE::OVERRIDES{'prodlist.add_url'}) { $HASH{'ADD_URL'} = $SITE::OVERRIDES{'prodlist.add_url'}; }
		$HASH{'ADD_LINK'} = ''; ## Creates an add to cart link (turns into a Choose Options... link when the product has either notes or POGs)
		$HASH{'ADD_BUTTON'} = '';  ## Creates an add to cart link (turns into a Choose Options... link when the product has either notes or POGs)
		$HASH{'ADD_FIELD'} = '';   ## Makes a checkbox or quantity field (based on $params->{'SHOWQUANTITY'})...
		$HASH{'ADD_FIELD_DETAILS'} = ''; ## Same as add_field but will be overridden if pogs or product notes are present (turns into a Choose Options... link when the product has either notes or POGs)
		$HASH{'VIEW_DETAILS'} = ''; ## View Details link
		$HASH{'POGS'} = ''; ## Contains the select-list HTML version of the pog list
		$HASH{'NOTES'} = ''; ## Contains the HTML version of the notes field
			
		## Set up the "View details" link if we need one
		if ($params->{'VIEWDETAILS'}) {
			$HASH{'VIEW_DETAILS'} = qq~<a class="zlink" href="$HASH{'PROD_URL'}">View Details</a>~;
			}


		if ($AVAILABLE) {
			if (defined $SITE::OVERRIDES{'prodlist.add_field'}) {
				$HASH{'ADD_FIELD'} = $SITE::OVERRIDES{'prodlist.add_field'};
				}
			elsif ($params->{'SHOWQUANTITY'}) {
				$HASH{'ADD_FIELD'}  = qq~<input type="hidden" name="product_id:$product_id" value="1"></input>~;
				$HASH{'ADD_FIELD'} .= qq~Quantity <input type="text" name="quantity:$product_id" size="3" maxlength="3" value="0"></input>\n~;
				}
			else {
				$HASH{'ADD_FIELD'}  = qq~<input type="hidden" name="quantity:$product_id" value="1"></input>~;
				$HASH{'ADD_FIELD'} .= qq~Add To Cart<input type="checkbox" name="product_id:$product_id" value="1"></input>~;
				}
			$HASH{'ADD_FIELD_DETAILS'} = $HASH{'ADD_FIELD'}; ## Default to the same (unless we have pogs which will override this)
			
			if (not $P->has_variations('any')) {
				## Easy...  no pogs means we can add this item to the cart directly
				$HASH{'ADD_LINK'} = qq~<a class="zlink z_add_link" href="$HASH{'ADD_URL'}">Add To Cart</a>~;
				if (defined $SITE::OVERRIDES{'prodlist.add_link'}) { $HASH{'ADD_LINK'} = $SITE::OVERRIDES{'prodlist.add_link'}; }
				$HASH{'ADD_BUTTON'} = qq~<input type="hidden" name="product_id" value="$product_id"><input type="submit" value="Add To Cart"></input>~;
				if (defined $SITE::OVERRIDES{'prodlist.add_button'}) { $HASH{'ADD_LINK'} = $SITE::OVERRIDES{'prodlist.add_button'}; }
				}
			else {
				## Since we have POGS, we can't provide a simple add to cart link
				$HASH{'ADD_LINK'} = qq~<a class="zlink z_add_link" href="$HASH{'PROD_URL'}">Choose Options...</a>~;
				if (defined $SITE::OVERRIDES{'prodlist.add_link_options'}) { $HASH{'ADD_LINK'} = $SITE::OVERRIDES{'prodlist.add_link_options'}; }
				$HASH{'ADD_BUTTON'} = $HASH{'ADD_LINK'};
				if (defined $SITE::OVERRIDES{'prodlist.add_button_options'}) { $HASH{'ADD_LINK'} = $SITE::OVERRIDES{'prodlist.add_button_options'}; }
				$HASH{'ADD_FIELD_DETAILS'} = $HASH{'ADD_LINK'};
				## Begin new %POGS% code
				my $info = { 'PRODUCT_ID' => $product_id, 'POGLIST_POGS' => $HASH{'zoovy:pogs'} };
				## Gets POGS HTML from POGS::text_to_html or $SITE->txspecl()->process_list depending
				## on whether they're new or old style pogs.  A fundamental difference between
				## the old and new pog format is that the new one the display is tied to the
				## option
				if ($iniref->{'POGS'}==0) {
					}
				else {
					## NEW FORMAT OPTION CODE
					require POGS;
					$HASH{'POGS'} = POGS::struct_to_html($P, undef, 1, $product_id, $iniref);
					}
				}
			}
		else {
			## The product isn't avaialable...  set up the add links appropriately
			my $message = $SITE->msgs()->get('inv_outofstock');
			$HASH{'ADD_LINK'} = $message;
			if ($params->{'VIEWDETAILS'}) {
				$HASH{'ADD_LINK'} = qq~<a class="zlink" href="$HASH{'PROD_URL'}">$message</a>~;
				}
			$HASH{'ADD_BUTTON'} = $HASH{'ADD_LINK'};
			$HASH{'ADD_FIELD'} = $HASH{'ADD_LINK'};
			}
		push @items, \%HASH;
		}


	my @lookup = (\%general);
	if (defined($iniref->{'LOADMERCHANT'}) && $iniref->{'LOADMERCHANT'}) {
		push @lookup, $SITE->nsref();
		}
	#if (defined($iniref->{'LOADFLOW'}) && $iniref->{'LOADFLOW'}) {
	push @lookup, $iniref;
	#	}
	

	$out = '';
	my $TXSPECL = undef;
	if (ref($SITE) eq 'SITE') { $TXSPECL = $SITE->txspecl(); }
	elsif (defined $SITE->txspecl()) {  $SITE->txspecl() = $SITE->txspecl(); }

	if (scalar(@items)>0) {
		## default behavior is to replace unknown %BLAH% tags with nothing -- which is bad.
		if (not defined $iniref->{'REPLACE_UNDEF'}) { $iniref->{'REPLACE_UNDEF'} = 1; }

		$out = $TXSPECL->process_list(
			'id'=>$iniref->{'ID'},
			'replace_undef'	=> $iniref->{'REPLACE_UNDEF'},
			'spec'            => $spec,
			'items'           => [@items],
			'lookup'          => [@lookup],
			'item_tag'        => 'PRODUCT',
			'divider'			=> $iniref->{'DIVIDER'},
			'alternate'       => $params->{'ALTERNATE'},
			'cols'            => $params->{'COLS'},
			'sku'					=> 'PRODUCT_ID',	
			                     ## These fields may have %fg% and other &translatable elements and therefore need to be preprocessed
			'preprocess'      => ['ADD_LINK', 'ADD_BUTTON', 'ADD_FIELD', 'ADD_FIELD_DETAILS', 'VIEW_DETAILS', 'POGS', 'NOTES'], 
			);

		}
	elsif (defined $iniref->{'EMPTY_MESSAGE'}) {
		## we don't have any products, so use the empty message if we've got one.
		$out = $TXSPECL->translate3($iniref->{'EMPTY_MESSAGE'},\@lookup);
		$iniref->{'MULTIPAGE'} = 0;		
		}
	undef @items;


	## &get_prodlist_multipage_spec();
	if ($iniref->{'MULTIPAGE'}) {
		my ($headref,$evenref,$oddref) = $TXSPECL->initialize_rows(1);
		my $mp_lookup = [ \%multipage, @lookup, $headref ];
		my $replace_undef = 1;		# don't leave unsubstituted tags (if data not found)

		my ($header,$footer) = ($iniref->{'MULTIPAGE_HEADER'}, $iniref->{'MULTIPAGE_FOOTER'});
		if (not defined $header) { $header = &get_default_prodlist_multipage_spec(); }
		if (not defined $footer) { $footer = &get_default_prodlist_multipage_spec(); }
		$out = $TXSPECL->translate3($header,$mp_lookup,replace_undef=>$replace_undef) . 
				$out . $TXSPECL->translate3($footer,$mp_lookup,replace_undef=>$replace_undef);
		#undef $headref, $evenref, $oddref;
		#undef $header, $footer;
		#undef $mp_lookup;
		}

	# print STDERR 'RENDER_PRODLIST final params! '.Dumper($params);
	# $out = "FORMAT: $params->{'FORMAT'} ".(time())."\n".$out;
	undef %multipage;
	undef @lookup;

	if ($iniref->{'DEBUG'} == 99) {
		## for brian
		push @DEBUG, "OUTPUT: $out";
		# print STDERR Dumper(\@DEBUG);
		}

#	if (defined $memd) { 
#		$memd->set($MEMKEY,$out,3600); 
#		}

	return($out);
	}

##
## 
##
sub get_prodlist_spec {
	my ($format, $spec) = @_;

	## This section is the precursor to user-definable product lists
	my $showprice = 0;
	if ($format eq 'CUSTOM') { ## Custom product list
		$showprice = 1;
		if (not defined $spec) {
			$spec = "Unrecognized product list format $format";
			}
		else {
			$spec = untab($spec);
			}
		}
	elsif ($format eq 'PLAIN') ### PLAIN prodlist 
		{
		$showprice = 1;
		$spec = untab(q~
                        <table border="0" width="100%" cellpadding="3" cellspacing="0">
                                <tr>
                                        <td align="left" class="ztable_head"><b>Name</b></td>
                                        <td align="left" class="ztable_head"><b>Product Description</b></td>
                                        <td align="right" class="ztable_head"><b>Price</b></td>
                                </tr>
                                <!-- PRODUCT -->
                                <tr class="ztable_row<% print($row.alt); %>">
                                        <td align="left"  valign="top" class="ztable_row<% print($row.alt); %>"><a href="<% load($PROD_URL);  print(); %>"><% load($zoovy:prod_name);  print(); %></a></td>
                                        <td align="left"  valign="top" class="ztable_row<% print($row.alt); %>"><% load($zoovy:prod_desc); strip(length=>"55",breaks=>"1",html=>"1");  print(); %></td>
                                        <td align="right" valign="top" class="ztable_row<% print($row.alt); %>"><% load($zoovy:base_price); format(hidezero,skipblank=>"1"); format(money,skipblank=>"1");  print(); %></b></td>
                                </tr>
                                <!-- /PRODUCT -->
                        </table>
			~);
	}
	elsif ($format eq 'THUMB') ### THUMB prodlist
	{
		$spec = q~ <table border="0" width="100%" cellpadding="2" cellspacing="0">
<!-- ROW -->
<tr>
<!-- PRODUCT -->
<td align="center" valign="top" width="<% load($COLWIDTH);  print(); %>" class="ztable_row<% print($row.alt); %>">
<a href="<% load($PROD_URL);  print(); %>">
<% load($zoovy:prod_thumb);  default($zoovy:prod_image1); image(w=>"75",h=>"75",tag=>"1");  print(); %></a><br>
<a href="<% load($PROD_URL);  print(); %>"><% load($zoovy:prod_name);  print(); %></a>
<% load($zoovy:base_price); format(hidezero,skipblank=>"1"); format(money,skipblank=>"1");  format(around=>"bold",skipblank=>"1");  format(before=>"break",skipblank=>"1");  print(); %>
</td>
<!-- /PRODUCT -->
<!-- BLANK -->
<td width="<% load($COLWIDTH);  print(); %>" class="ztable_row<% print($row.alt); %>">&nbsp;</td>
<!-- /BLANK -->
</tr>
<!-- /ROW -->
</table>~;

	}
	elsif ($format eq 'BIGTHUMB') ### BIGTHUMB prodlist
	{
		$spec = q~ <table border="0" width="100%" cellpadding="2" cellspacing="0">
<!-- ROW -->
<tr class="ztable_row">
<!-- PRODUCT -->
<td align="center" valign="top" width="<% load($COLWIDTH);  print(); %>" class="ztable_row<% print($row.alt); %>">
<a href="<% load($PROD_URL);  print(); %>">
<% load($zoovy:prod_thumb);  default($zoovy:prod_image1); image(w=>"150",h=>"150",tag=>"1");  print(); %></a><br>
<a href="<% load($PROD_URL);  print(); %>"><% load($zoovy:prod_name);  print(); %></a>
<% load($zoovy:base_price); format(hidezero,skipblank=>"1"); format(money,skipblank=>"1");  format(around=>"bold",skipblank=>"1");  format(before=>"break",skipblank=>"1");  print(); %>

</td>
<!-- /PRODUCT -->
<!-- BLANK -->
<td width="<% load($COLWIDTH);  print(); %>" class="ztable_row<% print($row.alt); %>">&nbsp;</td>
<!-- /BLANK -->
</tr>
<!-- /ROW -->
</table>
~;
	}
	elsif ($format eq 'THUMBMSRP') ### THUMB prodlist
	{
		$showprice = 1;
		$spec = q~ <table border="0" width="100%" cellpadding="2" cellspacing="0">
<!-- ROW -->
<tr>
<!-- PRODUCT -->
<td align="center" valign="top" width="<% load($COLWIDTH);  print(); %>" class="ztable_row<% print($row.alt); %>">
<a href="<% load($PROD_URL);  print(); %>">
<% load($zoovy:prod_thumb);  default($zoovy:prod_image1); image(w=>"75",h=>"75",tag=>"1");  print(); %><br>
<% load($zoovy:prod_name);  print(); %></a><br>
<% 
load($zoovy:prod_msrp);  
format(money,skipblank=>"1");
format(pretext=>"Retail:&nbsp;&lt;span style=&quot;text-decoration: line-through;&quot;&gt;",posttext=>"&lt;/span&gt;&lt;br&gt;");
print(); %>
Our Price:&nbsp;<% load($zoovy:base_price); format(hidezero,skipblank=>"1"); format(money,skipblank=>"1");  format(around=>"bold",skipblank=>"1");   print(); %>
</a>
</td>
<!-- /PRODUCT -->
<!-- BLANK -->
<td width="<% load($COLWIDTH);  print(); %>" class="ztable_row<% print($row.alt); %>">&nbsp;</td>
<!-- /BLANK -->
</tr>
<!-- /ROW -->
</table>
~;
	}	
	elsif ($format eq 'DETAIL') ### DETAIL prodlist
	{
		$showprice = 1;
$spec = q~<table border="0" width="100%" cellpadding="5" cellspacing="0">
<!-- PRODUCT -->
<tr class="ztable_row<% print($row.alt); %>">
	<td align="left" valign="top" width="85" class="ztable_row<% print($row.alt); %>">
	<a href="<% load($PROD_URL);  print(); %>"><% load($zoovy:prod_thumb);  default($zoovy:prod_image1); image(w=>"75",h=>"75",tag=>"1");  print(); %></a></td>

	<td align="left" valign="middle" width="100%" class="ztable_row<% print($row.alt); %>">
	<strong><span class="ztable_row_title"><% load($zoovy:prod_name);  print(); %></span></strong><br>
	<% load($zoovy:prod_desc); strip(length=>"500",breaks=>"0",html=>"1");  print(); %>
	<i><% load($zoovy:base_price); format(hidezero,skipblank=>"1"); format(money,skipblank=>"1");  print(); %></i>
	
	<div align="right" class="ztable_row_small">
	<b><nobr><% load($VIEW_DETAILS);  format(after=>"space",skipblank=>"1");  format(after=>"slash",skipblank=>"1");  format(after=>"space",skipblank=>"1");  print(); %><% load($ADD_LINK);  print(); %></nobr></b>
	</div>
	</td>
</tr>
<!-- /PRODUCT -->
</table>
~;
	}
	elsif ($format eq 'DETAIL2') ### DETAIL2 prodlist
	{
		$showprice = 1;
		$spec = q~<table border="0" width="100%" cellpadding="5" cellspacing="0">
<!-- PRODUCT -->
<tr class="ztable_row<% print($row.alt); %>">
	<td align="left" valign="top" width="85" class="ztable_row<% print($row.alt); %>"><a href="<% load($PROD_URL);  print(); %>">
<% load($zoovy:prod_thumb);  default($zoovy:prod_image1); image(w=>"75",h=>"75",tag=>"1");  print(); %></a></td>
	
	<td align="left" valign="top" width="20%" class="ztable_row<% print($row.alt); %>"><div style="line-height:160%;">
	<b><% load($zoovy:base_price); format(hidezero,skipblank=>"1"); format(money,skipblank=>"1"); format(posttext=>"&lt;br /&gt;"); print(); %></b>
	<b><nobr><% load($VIEW_DETAILS);  print(); %></nobr></b><br>
	<b><nobr><% load($ADD_LINK);  print(); %></nobr></b><br></div>
	</td>

	<td align="left" valign="top" width="80%" class="ztable_row<% print($row.alt); %>">
	<b><span class="ztable_row_title"><% load($zoovy:prod_name);  print(); %></span></b><br>
	<% load($zoovy:prod_desc); strip(length=>"500",breaks=>"0",html=>"1");  print(); %>
	</td>
</tr>
<!-- /PRODUCT -->
</table>
	~;

	}
	elsif ($format eq 'MULTIADD') ### MULTIADD prodlist
	{
		$showprice = 1;
		$spec = q~<table border="0" width="100%" cellpadding="5" cellspacing="0">
<% load($FORM);  print(); %>
<input type="hidden" name="add" value="yes"></input>
<tr class="ztable_head">
	<td valign="top" class="ztable_head" width="85">&nbsp;</td>
	<td align="center" valign="middle" class="ztable_head" width="100%">
	<input type="submit" value="Add Selected Items To Cart"></input>
	</td>
</tr>
<!-- PRODUCT -->
<tr class="ztable_row<% print($row.alt); %>">
	<td align="left" valign="top" width="85" class="ztable_row<% print($row.alt); %>"><a href="<% load($PROD_URL);  print(); %>">
	<% load($zoovy:prod_thumb);  default($zoovy:prod_image1); image(w=>"75",h=>"75",tag=>"1");  print(); %></a>
	</td>
	<td align="left" valign="middle" width="100%" class="ztable_row<% print($row.alt); %>">
	<font class="ztable_row_title"><% load($zoovy:prod_name);  print(); %></font><br>
	<% load($zoovy:prod_desc); strip(length=>"500",breaks=>"0",html=>"1");  print(); %>
	<i><% load($zoovy:base_price); format(hidezero,skipblank=>"1"); format(money,skipblank=>"1");  print(); %></i>
	&nbsp; &nbsp; <nobr><% load($VIEW_DETAILS);  print(); %></nobr>
	<table border="0" cellpadding="1" cellspacing="0" width="100%">
	<tr>
		<td align="left" valign="top">
			<% load($POGS);  print(); %>
			<% load($NOTES);  print(); %>
		</td>
		<td align="right" valign="bottom" width="100">
			<% load($ADD_FIELD);  print(); %>
		</td>
	</tr>
	</table>
	</td>
</tr>
<!-- /PRODUCT -->
<tr class="ztable_head">
	<td valign="top" class="ztable_head" width="85">&nbsp;</td>
	<td align="center" valign="middle" class="ztable_head" width="100%">
	<input type="submit" value="Add Selected Items To Cart"></input>
	</td>
</tr>
</form>
</table>~;
	}
	elsif ($format eq 'PLAINMULTI') ### PLAINMULTI prodlist
	{
		$showprice = 1;
		$spec = q~ <table border="0" width="100%" cellpadding="3" cellspacing="0">
 <% load($FORM);  print(); %>
<input type="hidden" name="add" value="yes"></input>
<tr>
	<td align="left" class="ztable_head"><b>Name</b></td>
	<td align="left" class="ztable_head"><b>Product Description</b></font></font></td>
	<td align="right" class="ztable_head"><b>Price</b></td>
	<td align="center" class="ztable_head"><b><% load($HEADING);  print(); %></b></td>
</tr>
<!-- PRODUCT -->
<tr class="ztable_row<% print($row.alt); %>">
	
	<td align="left" valign="top" class="ztable_row<% print($row.alt); %>"><a href="<% load($PROD_URL);  print(); %>"><% load($zoovy:prod_name);  print(); %></a></td>
	
	<td align="left" valign="top" class="ztable_row<% print($row.alt); %>"><% load($zoovy:prod_desc); strip(length=>"55",breaks=>"1",html=>"1");  print(); %></td>
	
	<td align="right"  valign="top" class="ztable_row<% print($row.alt); %>"><% load($zoovy:base_price); format(hidezero,skipblank=>"1"); format(money,skipblank=>"1");  print(); %></b></td>
	
	<td align="center" valign="top" class="ztable_row<% print($row.alt); %>"><% load($ADD_FIELD_DETAILS);  print(); %></td>
	
</tr>
<!-- /PRODUCT -->
<tr class="ztable_head">
	<td align="right" colspan="4" valign="middle" class="ztable_head" width="100%">
	<input type="submit" value="Add Selected Items To Cart"></input>
	</td>
</tr>
</form>
</table>
~;
	}
	elsif ($format eq 'SMALLMULTI') ### SMALLMULTI prodlist
	{
		$showprice = 1;
$spec = q~<table border="0" width="100%" cellpadding="3" cellspacing="0">
<% load($FORM);  print(); %>
<input type="hidden" name="add" value="yes"></input>
<tr>
<td align="center" class="ztable_head" colspan="2"><b>Name</b></td>
<td align="left"   class="ztable_head"><b>Product Description</b></td>
<td align="right"  class="ztable_head"><b>Price</b></td>
<td align="center" class="ztable_head"><b><% load($HEADING);  print(); %></b></td>
</tr>
<!-- PRODUCT -->
<tr class="ztable_row<% print($row.alt); %>">
	<td align="left"   valign="top" class="ztable_row<% print($row.alt); %>"><a href="<% load($PROD_URL);  print(); %>"><% load($zoovy:prod_thumb);  default($zoovy:prod_image1); image(w=>"32",h=>"32",tag=>"1");  print(); %></a></td>

	<td><a href="<% load($PROD_URL);  print(); %>"><% load($zoovy:prod_name);  print(); %></a></td>

	<td align="left"   valign="top" class="ztable_row<% print($row.alt); %>"><% load($zoovy:prod_desc); strip(length=>"150",breaks=>"0",html=>"1");  print(); %></td>
	
	<td align="right"  valign="top" class="ztable_row<% print($row.alt); %>"><% load($zoovy:base_price); format(hidezero,skipblank=>"1"); format(money);  print(); %></b></td>
	<td align="center" valign="top" class="ztable_row<% print($row.alt); %>"><% load($ADD_FIELD_DETAILS);  print(); %></td>
</tr>
<!-- /PRODUCT -->
<tr class="ztable_head">
<td align="right" colspan="5" valign="middle" class="ztable_head" width="100%">
<input type="submit" value="Add Selected Items To Cart"></input>
</td>
</tr>
</form>
</table>
~;
	}
	elsif ($format eq 'BIG') ### BIG prodlist
	{
		$showprice = 1;
		$spec = q~<table border="0" width="100%" cellpadding="5" cellspacing="0">
<!-- PRODUCT -->
<tr class="ztable_row<% print($row.alt); %>">
	<td align="left" valign="top" rowspan="2" width="190" class="ztable_row<% print($row.alt); %>">
<a href="<% load($PROD_URL);  print(); %>">
<% load($zoovy:prod_thumb);  default($zoovy:prod_image1); image(w=>"180",h=>"180",tag=>"1");  print(); %>
</a>
	</td>

	<td align="left" valign="top" width="100%" class="ztable_row<% print($row.alt); %>">
	<font class="ztable_row_title"><% load($zoovy:prod_name);  print(); %></font><br>
	<% load($zoovy:prod_desc); strip(length=>"500",breaks=>"0",html=>"1");  print(); %>
	<i><% load($zoovy:base_price); format(hidezero,skipblank=>"1"); format(money);  print(); %></i>
	</td>
</tr>
<tr>
	<td align="right" valign="bottom" width="100%" class="ztable_row<% print($row.alt); %>">
	<div align="right">
	<b><nobr><% load($VIEW_DETAILS);  format(after=>"space",skipblank=>"1");  format(after=>"slash",skipblank=>"1");  format(after=>"space",skipblank=>"1");  print(); %><% load($ADD_LINK);  print(); %></nobr></b>
	</div>
	</td>
</tr>
<!-- /PRODUCT -->
</table>
~;
	}
	elsif ($format eq 'BIG2') ### BIG2 prodlist
	{
		$showprice = 1;
		$spec = q~<table border="0" width="100%" cellpadding="5" cellspacing="0">
<!-- PRODUCT -->
<tr class="ztable_row<% print($row.alt); %>">

	<td align="left" valign="top" width="190" class="ztable_row<% print($row.alt); %>"><a href="<% load($PROD_URL);  print(); %>"><% load($zoovy:prod_thumb);  default($zoovy:prod_image1); image(w=>"180",h=>"180",tag=>"1");  print(); %></a></td>

	<td align="left" valign="middle" width="20%" class="ztable_row<% print($row.alt); %>">
	<b><nobr><% load($zoovy:base_price); format(hidezero,skipblank=>"1"); format(money);  print(); %></nobr></b><br>
<br>
<b><nobr><% load($VIEW_DETAILS);  print(); %></nobr></b><br>
<br>
<b><nobr><% load($ADD_LINK);  print(); %></nobr></b><br>
	</td>
	
	<td align="left" valign="top" width="80%" class="ztable_row<% print($row.alt); %>">
	<font class="ztable_row_title"><% load($zoovy:prod_name);  print(); %></font><br>
	<% load($zoovy:prod_desc); strip(length=>"500",breaks=>"0",html=>"1");  print(); %>
	</td>
</tr>
<!-- /PRODUCT -->
</table>
~;
	}
	elsif ($format eq 'PLAINMSRP') ### PLAIN MSRP prodlist
	{
		$showprice = 1;
		$spec = q~
<table border="0" width="100%" cellpadding="3" cellspacing="0">
<tr>
<td align="left"  class="ztable_head"><b>Name</b></td>
<td align="left"  class="ztable_head"><b>Product Description</b></td>
<td align="right" class="ztable_head"><b>Retail&nbsp;Price</b></td>
<td align="right" class="ztable_head"><b>Our&nbsp;Price</b></td>
</tr>
<!-- PRODUCT -->
<tr class="ztable_row<% print($row.alt); %>">
<td align="left"  valign="top" class="ztable_row<% print($row.alt); %>"><a href="<% load($PROD_URL);  print(); %>"><% load($zoovy:prod_name);  print(); %></a></td>
<td align="left"  valign="top" class="ztable_row<% print($row.alt); %>"><% load($zoovy:prod_desc); strip(length=>"45",breaks=>"1",html=>"1");  print(); %></td>
<td align="right" valign="top" class="ztable_row<% print($row.alt); %>"><b><span style="color: #990000; text-decoration: line-through;"><% load($zoovy:prod_msrp);  format(money);  print(); %></span></b></td>
<td align="right" valign="top" class="ztable_row<% print($row.alt); %>"><b><% load($zoovy:base_price); format(hidezero,skipblank=>"1"); format(money);  print(); %></b></td>
</tr>
<!-- /PRODUCT -->
</table>~;
	}
	else
	{
		$spec = "Unrecognized product list format $format";
	}
	return ($spec,$showprice);
}








sub get_default_prodlist_multipage_spec
{
	return q~<table width="100%" cellpadding="8" cellspacing="0" border="0">
<tr>
<td align="left" valign="middle" width="20%" class="ztable_head">
<% load($PREVPAGE);  format(before=>"angle",skipblank=>"1");  print(); %>
</td>
<td align="center" valign="middle" width="60%" class="ztable_head">
<b>Page <% load($THISPAGE);  print(); %> of <% load($TOTALPAGES);  print(); %></b><br>
<font size="-1"><% load($PAGELINKS);  print(); %></font>
</td>
<td align="left" valign="middle" width="20%" class="ztable_head">
<% load($NEXTPAGE);  format(after=>"angle",skipblank=>"1");  print(); %>
</td>
</tr>
</table>~;
}





sub RENDER_GALLERYSELECT {
	my ($iniref,undef,$SITE) = @_;    # iniref is a reference to a hash of the element's contents as defined in the flow file
	return('');
	} 









sub RENDER_MAILFORM {
	my ($iniref,$toxml,$SITE) = @_;    # iniref is a reference to a hash of the element's contents as defined in the flow file

	my $preview = (defined $iniref->{'PREVIEW'} && $iniref->{'PREVIEW'}) ? 1 : 0;

	my $v = $SITE::v;
	#unless ((defined $v) && (ref($v) eq 'HASH')) {
	#	my $cgi = new CGI;
	#	$v = {map { lc($_) => ($cgi->param($_))[0] } $cgi->param}; # Cleaner than $v = $cgi->Vars() because it removes the null padding
	#	}

	my $contact_url = $SITE->URLENGINE()->get('contact_url');

	my $from    = defined($v->{'from'})    ? $v->{'from'}    : '';
	my $subject = defined($v->{'subject'}) ? $v->{'subject'} : '';
	my $message = defined($v->{'message'}) ? $v->{'message'} : '';
	my $form    = $preview ? qq~<form onSubmit="return false;">~ : qq~<form action="$contact_url" method="post">~;

	my $order_id  = '';
	my $req_order = 0;
	if (defined $iniref->{'REQORDER'} && $iniref->{'REQORDER'})
	{
		$req_order = 1;
		if (defined $v->{'order_id'}) { $order_id = $v->{'order_id'}; }
		else { $order_id = ''; }
	}

	my $out = untab(qq~
		<div align="center">
		<table border="0" cellapdding="0" cellspacing="0" align="center">
			<tr>
				<td align="left">
					<font class="ztxt">
					$form
						<input type="hidden" name="validate" value="1" />
						<b>From <i>(your email address)</i>:</b><br />
						<input type="text" name="from" value="$from" size="32" maxlength="80" /><br />
						<b>Subject:</b><br>
						<input type="text" name="subject" value="$subject" size="32" maxlength="80" /><br />
	~);
	if ($req_order)
	{
		$out .= untab(qq~
						<b>Regarding Order Number <i>(if applicable)</i>:</b><br>
						<input type="text" name="order_id" value="$order_id" size="32" maxlength="20" /><br />
		~);
	}
	$out .= untab(qq~
						<b>Message:</b><br>
						<textarea name="message" rows="10" cols="35">$message</textarea><br /><img src="/media/graphics/general/blank.gif" width="1" height="8" alt='' /><br>
						<input type="submit"value="Send Message"> <input type="reset"value="Reset Form" />
					</form>
					</font>
				</td>
			</tr>
		</table>
		</div>
	~);
	return $out;

} ## end sub RENDER_MAILFORM


#
# <ELEMENT IN="pogs" OUT="v1">
# <DATA><![CDATA[<pog id="A7" prompt="chair size" inv="0" global="0" type="attribs" amz="">
# <option v="00">small</option>
# <option v="01">less small</option>
# <option v="02">big</option>
# <option v="03">more big</option>
# <option v="04">back breakingly large</option>
# </pog>]]></DATA>
# </ELEMENT>
#
# element(TYPE=>"JSON",IN=>"pogs",OUT=>"v1",DATA=>$zoovy:pogs); 
#

##
## utility function: formats pogs into a more js friendly format
##
sub pogs2jsonpogs {
	my ($STID,$pogsref) = @_;

	# print STDERR Dumper($STID,$pogsref);

	foreach my $pogref (@{$pogsref}) {
		$pogref->{'fieldname'} = 'pog_'.$pogref->{'id'}.':'.$STID;
		$pogref->{'cb_fieldname'} = 'pog_'.$pogref->{'id'}.'_cb'.':'.$STID;
		if (defined $pogref->{'@options'}) {
			## version 2.0 of options, we don't use 'options' anymore, use '@options' instead.
			$pogref->{'options'} = $pogref->{'@options'};
			foreach my $poption (@{$pogref->{'@options'}}) {
				$poption->{'p'} = sprintf("%s",$poption->{'p'});
				}
			delete $pogref->{'@options'};
			}
		#elsif (defined $pogref->{'options'}) {
		#	## pogs version 1.0
		#	my $options = $pogref->{'options'};
		#	foreach my $optref (@{$options}) {
		#		&POGS::parse_meta($optref->{'m'},$optref);
		#		delete $optref->{'m'};
		#		}
		#	}
		}
	}

##
## A slightly different type of element, used to output JSON objects of various types
##	
##
##	IN=>"pogs",OUT=>"v1"
##		DATA=>"{zoovy:pogs}"
##	IN=>"sogs",OUT=>"v1"
##		SOG=>?? 
##
## 
##
#sub RENDER_JSON {
#	my ($iniref,undef,$SITE) = @_;
#
#	require Data::JavaScript;
#	require Data::JavaScript::LiteObject;
#	require JSON::XS;
#
#	my $USERNAME = $SITE->username();
#
#	my $out = '';
#	$iniref->{'IN'} = lc($iniref->{'IN'});
#	$iniref->{'OUT'} = lc($iniref->{'OUT'});
#
#
#
#	my $STID = $iniref->{'STID'};
#	if (($iniref->{'IN'} eq 'prodref') && ($iniref->{'OUT'} eq 'v2')) {
#		my $prodref = $iniref->{'DATA'};
#		# my @pogs = POGS::text_to_struct($USERNAME,$prodref->{'zoovy:pogs'},1,1);
#		my $pogs2 = &ZOOVY::fetch_pogs($USERNAME,$prodref);
#		&TOXML::RENDER::pogs2jsonpogs($STID,$pogs2);
#		my $utf8_encoded_json_text = JSON::XS::encode_json($pogs2);
#		$out = "var $iniref->{'ID'}_pogs = $utf8_encoded_json_text;\n";
#
#		my $skuref = undef; # $prodref->{'%SKU'};
#		if (not defined $skuref) { $skuref = {}; }
#
#		my ($inv,$reserve,$loc) = &INVENTORY::fetch_qty($USERNAME,[$STID],undef,{$STID=>$prodref});
#
#		#print STDERR Dumper($inv,$reserve,$loc);
#		foreach my $sku (keys %{$inv}) {
#			if (defined $prodref->{'%SKU'}->{$sku}) {
#				## start by copying any SKU specific fields from %SKU
#				$skuref->{$sku} = Storable::dclone($prodref->{'%SKU'}->{$sku});
#				delete $skuref->{$sku}->{'zoovy:base_cost'};	# cheap hack (for now)
#				}
#			
#			$skuref->{$sku}->{'inv'} = $inv->{$sku};
#			$skuref->{$sku}->{'res'} = $reserve->{$sku};
#			}
#		
#		my $utf8_encoded_sku_json = JSON::XS::encode_json($skuref);
#
#		$out .= "var $iniref->{'ID'}_sku = $utf8_encoded_sku_json;\n";
#		}
#	elsif (($iniref->{'IN'} eq 'pogs') && ($iniref->{'OUT'} eq 'v1')) {
#		##
#		## v1: deprecated format - only outputs pogs  1/19/2010
#		##	
#		Carp::croak("v1 deprecated 1/19/2010");
#		$iniref->{'OUT'} = '/* javascript v1 deprecated 1/19/2010 */';
##		my @pogs = POGS::text_to_struct($USERNAME,$iniref->{'DATA'},1,1);
##		&TOXML::RENDER::pogs2jsonpogs($STID,\@pogs);
##		my $utf8_encoded_json_text = JSON::XS::encode_json(\@pogs);
##		$out = "var $iniref->{'ID'}_pogs = $utf8_encoded_json_text;\n";
#		## TODO: build an option object in javascript for easy manip. of data.
#		## ogset = new ZOptionGroupSet($iniref->{'ID'}_pogs);
#		##	for (og in ogset.groups()) {
#		## 	document.write(sog.prompt);
#		##			for (opt in sog.options()) {
#		##				document.write(opt.prompt+"<br>");
#		##				}
#		##			}
#		##		}
#		}	
#	else {
#		$out = "/*<!-- invalid RENDER_JSON in=$iniref->{'IN'} eq 'pogs') out=$iniref->{'OUT'} -->*/";
#		}
#
#	return($out);
#	}
#

# Makes the "Add to Cart" button, along with POGs and product notes for a product flow
##
## PARAMETERS:
##		FORM
##
sub RENDER_ADDTOCART {
	my ($iniref,undef,$SITE) = @_;    # iniref is a reference to a hash of the element's contents as defined in the flow file
	my %vars = ();

	if (not defined $iniref->{'FORM'}) { $iniref->{'FORM'} = 1; }
	if (not defined $iniref->{'TOPHTML'}) { $iniref->{'TOPHTML'} = ''; }
	if (not defined $iniref->{'SHOWQUANTITY'}) { $iniref->{'SHOWQUANTITY'} = 0; }
	my $USERNAME = $SITE->username();

	require ZOOVY;
	require ZWEBSITE;

	my ($CART2) = $SITE->cart2();
	my ($webdbref) = $SITE->webdb();

	## by default, we get focus on a STID if one was implicitly passed to the addtocart element
	# my $STID = $iniref->{'STID'};
	## okay, next if, if it's not set, we use global STID
	#if (defined $STID) {
	#	($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($STID);
	#	}

	##
	## SANITY: at this point all the %vars are set, and should not be altered!
	##


	
	my $P = undef;
	my $STID = undef;
	if (defined $iniref->{'STID'}) {
		my ($PID,$CLAIM,$INVOPTS) = PRODUCT::stid_to_pid($iniref->{'STID'});
		$STID = $vars{'STID'} = $iniref->{'STID'};
		$vars{'SKU'} = $PID;
	 	if ($INVOPTS ne '') { $vars{'SKU'} = $PID.':'.$INVOPTS; }
		$vars{'PID'} = $PID;
		$P = $SITE->pRODUCT($PID);
		}
	else {
		$P = $SITE->pRODUCT();
		$STID = $vars{'STID'} = $SITE->stid();
		$vars{'SKU'} = $SITE->sku();
		$vars{'PID'} = $SITE->pid();
		# print STDERR Dumper(\%vars); die();
		}



	if ((not defined $P) || (ref($P) ne 'PRODUCT')) {
		return("");
		}

	## make a copy of the product into %vars
	foreach my $k (keys %{$P->prodref()}) {
		$vars{$k} = $P->fetch($k);
		}

	## This is handled a little differrent than prodlists for old-style pogs
	## Prodlists allow you to customize the look of them by passing POGHTML
	## but ADDTOCART doesn't.  In new-style pogs, the display format is tied
	## to the pog definition itself.
	$vars{'PURCHASABLE'} = 1;

	my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($STID);

	# Get the pogs associated with the product
	## Pogs used to be username:pogs and now they're zoovy:pogs
	$vars{'poghtml'} = '';
	$vars{'message'} = ''; # We can set a message that appears above the buttons
	if (not defined $P) {
		}
	elsif ($P->has_variations('any')) {
		require POGS;
		my %params = ();
		if (defined $SITE->stid()) {
			foreach my $kv (split(/\:/,$invopts.':'.$noinvopts)) {
				next if (length($kv)!=4);
				$params{ substr($kv,0,2) } = substr($kv,2,2);
				}
			}

##
## <% element(TYPE=>"ADDTOCART",POG_SPECL=>$specl); print(); %>
## <ELEMENT TYPE="ADDTOCART" POG_SPECL="">
##
#		if (1) {
#			$iniref->{'JAVASCRIPT'} = $STID;
#			}
		if ($iniref->{'JAVASCRIPT'} eq 'v1') {
			## JS: 
			#$iniref->{'JAVASCRIPT'} = TOXML::RENDER::RENDER_JSON(
			#	{ ID=>$iniref->{'ID'}, IN=>'pogs', OUT=>'v1', STID=>$STID, DATA=>$prod->{'zoovy:pogs'} },undef,$SITE
			#	);
			$iniref->{'JAVASCRIPT'} = "\n//Javascript v1 OUTPUT DEPRECATED\n";
			}
		elsif ($iniref->{'JAVASCRIPT'} eq 'v2') {
			## JS: 
			# &ZOOVY::confess($SITE->username(),"USING ADDTOCART with JAVASCRIPT = v2",'justkidding'=>1);
			## DEFINITELY STILL USED 8/21/12
			## REMOVEED AS SUBROUTINE - CALLD DIRECTLY 8/23/12
			#$iniref->{'JAVASCRIPT'} = TOXML::RENDER::RENDER_JSON(
			#	{ ID=>$iniref->{'ID'}, IN=>'prodref', OUT=>'v2', STID=>$STID, DATA=>$P->dataref() },undef,$SITE
			#	);
			my $pogs2 = Storable::dclone($P->fetch_pogs());
			#open F, ">>/tmp/opt-fu";
			#print F Dumper($pogs2);
			#close F;
			my @foo = ();
			foreach my $pogref (@{$pogs2}) {
				$pogref = Storable::dclone($pogref);
				$pogref->{'fieldname'} = 'pog_'.$pogref->{'id'}.':'.$STID;
				$pogref->{'cb_fieldname'} = 'pog_'.$pogref->{'id'}.'_cb'.':'.$STID;
				if (defined $pogref->{'@options'}) {
					## version 2.0 of options, we don't use 'options' anymore, use '@options' instead.
					$pogref->{'options'} = $pogref->{'@options'};
					foreach my $poption (@{$pogref->{'@options'}}) {
						$poption->{'p'} = sprintf("%s",$poption->{'p'});
						}
					delete $pogref->{'@options'};
					}
				push @foo, $pogref;
				}

			my $utf8_encoded_json_text = JSON::XS::encode_json(\@foo);
			my $out = "var $iniref->{'ID'}_pogs = $utf8_encoded_json_text;\n";

			my $skuref = {}; # $prodref->{'%SKU'};
			## my ($inv,$reserve) = INVENTORY2->new($USERNAME)->fetch_qty('@STIDS'=>[$STID],'GREF'=>$SITE->globalref(),'%PIDS'=>{$P->pid()=>$P});
			my ($inv,$reserve) = INVENTORY2->new($USERNAME)->fetch_qty('@PIDS'=>[$P->pid()],'GREF'=>$SITE->globalref(),'%PIDS'=>{$P->pid()=>$P});
			#print STDERR Dumper($inv,$reserve,$loc);
			foreach my $sku (keys %{$inv}) {
				if (defined $P->skuref($sku)) {
					## start by copying any SKU specific fields from %SKU
					$skuref->{$sku} = Storable::dclone($P->skuref($sku));
					delete $skuref->{$sku}->{'zoovy:base_cost'};	# cheap hack (for now)
					}		
				$skuref->{$sku}->{'inv'} = $inv->{$sku};
				$skuref->{$sku}->{'res'} = $reserve->{$sku};
				}
			my $utf8_encoded_sku_json = JSON::XS::encode_json($skuref);
			$out .= "var $iniref->{'ID'}_sku = $utf8_encoded_sku_json;\n";

			print STDERR "OUT: $out\n";

			$iniref->{'JAVASCRIPT'} = $out;
			}
		elsif ($iniref->{'POG_SPECL'}) {
			print STDERR "POG_SPECL\n";
			##
			##	
			##
		 	# my @pogs = POGS::text_to_struct($USERNAME,$prod->{'zoovy:pogs'},1,1);
			my ($pogs2) = $P->pogs();
			my @copypogs = ();
			foreach my $pogref (@{$pogs2}) {
				my $copyref = Storable::dclone($pogref);
				$copyref->{'fieldname'} = 'pog_'.$copyref->{'id'}.':'.$STID;
				$copyref->{'cb_fieldname'} = 'pog_'.$copyref->{'id'}.'_cb'.':'.$STID;
				$copyref->{'OPTIONSTACK'} = $SITE->txspecl()->spush('',@{$copyref->{'@options'}});
				delete $copyref->{'@options'};
				push @copypogs, $copyref;
				}
			## there is now a variable called $POGSTACK
			##		POGSTACK has a variety of variables, e.g. id, global, type, inv, etc.
			##		once that is popped, there is another variable in it called OPTIONSTACK
			##		which can be interated through.
			$iniref->{'POGSTACK'} = $SITE->txspecl()->spush('',@copypogs);
			

			##
			## example pog_specl spec:
			##
			$vars{'poghtml'} = $SITE->txspecl()->process_list(
				'id'=>$iniref->{'ID'},
				replace_undef=>0,
				spec=>$iniref->{'POG_SPECL'},
				items=>$pogs2,
				lookup=>[\%vars,$iniref],
				item_tag=>'POG',
				);
			}
		else {
			##
			## Standard HTML Output  
			##
			# my @struct = &POGS::text_to_struct($USERNAME, $prod->{'zoovy:pogs'}, 1, $SITE->{'+cache'});
			my ($pogs2) = $P->pogs();

			# print STDERR 'POGS2: '.Dumper($pogs2);
			# my $ignore_inventory = ($P->fetch('zoovy:inv_enable') & 64);

			my ($ignore_inventory) = ($CART2->in_get('is/inventory_exempt'))?1:0;
			#if ($CART2->schedule() ne '') {
			#	require WHOLESALE;
			#	my ($S) = WHOLESALE::load_schedule($USERNAME,$CART2->schedule());
			#	$ignore_inventory = (int($S->{'inventory_ignore'});
			#	## turn on unlimited inventory, and flag this as a "temporary unlimited"
			#	};
		
			foreach my $pogref (@{$pogs2}) {
				#if (($pogref->{'type'} eq 'assembly') && (not $ignore_inventory)) {
				#	my ($qtyref) = &POGS::tweak_asm($pogref,1);
				#	if (not defined $qtyref) {
				#		$vars{'PURCHASABLE'} = 0;
				#		$vars{'message'} = "One or more of the items in this assembly are not available.";
				#		}
				#	}
				}
			# my ($P, $selected, $context, $stid, $iniref) = @_;
			$vars{'poghtml'} = &POGS::struct_to_html($P, \%params, 16, $STID, $iniref);
			}
		}

#	print STDERR Dumper(\%vars);


	$vars{'continue_shopping'} = defined($webdbref->{'product_continue_shopping'}) ? $webdbref->{'product_continue_shopping'} : 0; ## Continue shopping button appears as Cancel button (1 sets it to "Continue Shopping")
	
	if (not $P->is_purchasable()) {
		## Show a blank price message...  this was added for GDC so products with blank prices can say "Call for pricing"
		$vars{'message'} = $SITE->msgs()->get('product_blank_price_message');
		$vars{'PURCHASABLE'}       = 0; ## If price is blank, don't give them an add to cart button
		$vars{'continue_shopping'} = 1; ## Change the "Cancel" button to a "Continue Shopping" button
		}
	else {
		## it is purchasable
		if ($SITE::CART2->in_get('our/schedule') ne '') {
			## we have a pricing schedule so override prices by putting those into %vars
			my $results = $P->wholesale_tweak_product($SITE::CART2->in_get('our/schedule'));
			foreach my $k (keys %{$results}) {
				$vars{$k} = $results->{$k};
				}
			}
		}



	my $gref = $SITE->globalref();
	# Product website display modes:
	# 0 : Inventory disabled (or inventory defaults to global preferences for product scope)
	# 1 : Inventory for internal use only
	# 2 : Disclose inventory status to customers
	# 3 : Disclose inventory quantity to customers
	my $mode         = (defined $gref->{'inv_mode'})          ? $gref->{'inv_mode'}          : 0;
	if ($mode == 0) { $mode = 1; }

	#if ( (defined $gref->{'inv_configproduct'}) && ( $gref->{'inv_configproduct'}>0 )) {
	#	if ((defined $P->fetch('zoovy:inv_mode')) && ($P->fetch('zoovy:inv_mode') != $mode)) { 
	#		&ZOOVY::confess($SITE->username(),"INVENTORY MODES DIVERGE $mode",justkidding=>1);
	#		$mode = int($P->fetch('zoovy:inv_mode')); 
	#		}
	#	}
	
	# my $inv_enabled  = (defined $P->fetch('zoovy:inv_enable')) ? $P->fetch('zoovy:inv_enable') : 0;
	# $inv_enabled |= 1;

	if ($vars{'PURCHASABLE'}) {
		# my $safety      = defined($gref->{'inv_safety'})  ? int($gref->{'inv_safety'})  : 0;
		my $police      = defined($gref->{'inv_police'})  ? int($gref->{'inv_police'})  : 0;
		#my $resmode     = defined($gref->{'inv_reserve'}) ? int($gref->{'inv_reserve'}) : 0;
	
		# print STDERR "resmode: $resmode\n inv_reserve: ".$gref->{'inv_reserve'}."\n";

		# my $reserve     = 0;
		my $onhand      = 0;
		# my $adjusted    = 0;

		my ($available) = $P->inv_qty('*','AVAILABLE');
		my $qty_message = '';

		my ($onhand_hash) = INVENTORY2->new($USERNAME)->fetch_qty('@PIDS'=>[$SITE->{'_PID'}],'GREF'=>$SITE->globalref(),'%PIDS'=>{$P->pid()=>$P});

		## which inventory mode to use!
		if ($claim>0) {
			$qty_message = " (Qty avail: Fixed)";
			}
		#elsif (not defined $P->fetch('zoovy:inv_enable')) {
		#	## CORRUPT
		#	$adjusted = -1;
		#	$qty_message = " (Inventory not properly configured)";
		#	}
		#elsif ($P->fetch('zoovy:inv_enable') & 32) {
		#	$onhand = 9999;
		#	$adjusted = 9999;
		#	$qty_message = " (Qty avail: unlimited)";
		#	}
		elsif ($P->has_variations('inv')) {
			foreach my $key (keys %{$onhand_hash})  { 
				next if ($onhand_hash->{$key}<=0);
				$onhand  += $onhand_hash->{$key}; 
				## if ($resmode) { $reserve += $reserve_hash->{$key}; }
				}
			##  $adjusted = ($onhand-$reserve);
			$qty_message = " (Qty avail: $onhand for all options)";
			}
		else {
			# if ($resmode) { $reserve = defined($reserve_hash->{$SITE->{'_PID'}}) ? $reserve_hash->{$SITE->{'_PID'}} : 0; }
			$onhand = defined($onhand_hash->{$SITE->{'_PID'}}) ? $onhand_hash->{$SITE->{'_PID'}} : 0;
			# $adjusted = ($onhand-$reserve);
			$qty_message = " (Qty avail: $onhand)";
			}
		
		# $onhand++; $adjusted++;

		$vars{'zoovy:inv_qty_onhand'} = $onhand;
		$vars{'zoovy:inv_qty_available'} = $onhand;
		$vars{'zoovy:inv_qty_reserve'} = 0; # $reserve;

		if ($claim>0) {
			$vars{'message'} = 'Inventory has been reserved for this purchase.';			
			}
		elsif ($available > 0) {
			$vars{'message'} = $SITE->msgs()->get('inv_available');
			if ($mode > 2) { $vars{'message'} .= $qty_message; }
			}
		#elsif ($adjusted > $safety) {
		#	$vars{'message'} = $SITE->msgs()->get('inv_available');
		#	if ($mode > 2) { $vars{'message'} .= $qty_message; }
		#	}
		#elsif ($adjusted > 0) {
		#	$vars{'message'} = $SITE->msgs()->get('inv_safety');
		#	if ($mode > 2) { $vars{'message'} .= $qty_message; }
		#	}
		#elsif ($onhand > 0) {
		#	$vars{'message'} = $SITE->msgs()->get('inv_reserved');
		#	if ($police > 1) { $vars{'PURCHASABLE'} = 0; }
		#	}
		else {
			$vars{'message'} = $SITE->msgs()->get('inv_outofstock');
			# $vars{'PURCHASABLE'} = 0;
			## NOTE: there are configs where the person wants to allow backorders
			if ($police > 0) { $vars{'PURCHASABLE'} = 0; }
			}
		}

	$vars{'CLAIM'} = 0;
	if ($SITE->{'_CLAIM'}) {
		$vars{'PURCHASABLE'} = 1;
		$vars{'CLAIM'} = $SITE->{'_CLAIM'}; 
		## always allow External items to be purchased
		$vars{'SKU'} = "$SITE->{'_CLAIM'}*$SITE->{'_PID'}";
		$vars{'PID'} = $SITE->{'_PID'};
		}
	elsif ($vars{'PURCHASABLE'}) {
		$vars{'qty'} = 1;
		if (defined $SITE::CART2) { 
			# quantity is set to price,quantity,weight,... blah if it succeeds!
			my $item = $SITE::CART2->stuff2()->item( $SITE->{'_PID'} );
			if (defined $item) {	$vars{'qty'} = $item->{'qty'}; }
			}
		if (not defined $vars{'qty'}) { $vars{'qty'} = 1; }			

		if (defined $SITE::TRACK_PRODUCTS_DISPLAYED) {
			$SITE::TRACK_PRODUCTS_DISPLAYED .= ','.$SITE->{'_PID'};	## e.g. nspace
			}
		}

	## Cheap hack that allows JT to add product ID's into inventory messages
	$vars{'message'} =~ s/\%SKU\%/$vars{'SKU'}/gs;
	$vars{'message'} =~ s/\%PID\%/$SITE->{'_PID'}/gs;
	$vars{'message'} =~ s/\%PROD_NAME\%/$P->fetch('zoovy:prod_name')/gs;

	$vars{'dev_no_continue'} = ($SITE::OVERRIDES{'dev.no_continue'})?1:0;

	######################  AT THIS POINT ALL LOGIC IS COMPLETE  ######################

	my $spec = q~
<!-- ADDTOCART -->
<font size="1"><br></font><%

/* IF NO FORM, SKIP TO END */
load($FORM); goto(lt=>"1",label=>"END");
load($PREVIEW); goto(gt=>"0",label=>"PREVIEW");
load("1"); goto(eq=>"1",label=>"ADDTOCART"); 

:PREVIEW();
/* PREVIEW FORM TAG */
print("<form onSubmit=&quot;return false;&quot; name=&quot;");
print($ID);
print("&quot; style=&quot;margin-top:0;margin-bottom:0&quot;>");
load("1"); goto(gt=>"0",label=>"END");

:ADDTOCART();
/* ACTUAL FORM TAG */
print("<form action=&quot;");
loadurp("URL::cart_url"); print();
print("&quot; method=&quot;POST&quot; id=&quot;");
print($ID);
print("&quot; name=&quot;");
print($ID);
print("&quot; style=&quot;margin-top:0;margin-bottom:0&quot;>");
load("1"); goto(gt=>"0",label=>"END");

:END();
print("");

%><% 

load($TOPHTML); print(); print(""); 

%><%  

load($CLAIM);
goto(eq=>"0",label=>"END");
	print("<b>Quantity:");
	load($zoovy:quantity); print();
	print("</b><br />");
	print("<input type='hidden' name='external' value='1' />");
:END();
print("");

%><% 

load($PURCHASABLE);
goto(eq=>"0",label=>"END");

	print("<input type=&quot;hidden&quot; name=&quot;product_id&quot; value=&quot;");
	print($SKU);
	print("&quot; /><input type=&quot;hidden&quot; name=&quot;add&quot; value=&quot;yes&quot; />");
	print($poghtml);

	load($SHOWQUANTITY);
	goto(eq=>"0",label=>"ENDSHOWQUANTITY");
		print("<div class='zform_qty_input'><b>");
		print($SHOWQUANTITY);
		print("</b>");
		print("<input type=&quot;text&quot; name=&quot;quantity&quot; size=&quot;5&quot; value=&quot;");
		print($qty);
		print("&quot; ");
		load($CSSCLASS); goto(unless=>$_,label=>"SKIPCSSCLASS");
			print(" class=&quot;"); print($CSSCLASS); print("&quot; ");
		:SKIPCSSCLASS();
		print(" /><br />");
		/* if quantity is displayed, then always override in cart. */
		print("<input type=&quot;hidden&quot; name=&quot;override&quot; value=&quot;1&quot; /></div>");
	:ENDSHOWQUANTITY();
	
:END();
print("");

%><%

/* This message usually has stuff like inventory disposition, or claim details. */
load($message);
goto(eq=>"",label=>"END");
	print("<div class=&quot;ztxt zsys_inventory&quot;>");
	print($message);
	print("</div><br />");
:END();
print("");

%><%

/* prints the actual ADDTOCART button */
load($PURCHASABLE);
goto(lt=>"1",label=>"END");
	load($ID);
	format(posttext=>":add_to_cart");
	set($ATCID=>$_);
	element(TYPE=>"SITEBUTTON",button=>"add_to_cart",SKU=>$SKU,PID=>$PID,ID=>$ATCID,alt=>"Add to Cart",name=>"add_to_cart");
	print();
:END();
print("");

%><%

load($dev_no_continue);
goto(gt=>"0",label=>"END");

	print(" <a href=&quot;");
	loadurp("URL::continue_url"); print();
	print("&quot;>");

	load($continue_shopping);
	goto(if=>$_,label=>"CONTINUE");
	goto(unless=>$_,label=>"CANCEL");

	:CONTINUE();
	load($ID);
	format(posttext=>":continue_shopping");
	set($BTNID=>$_);
	element(TYPE=>"SITEBUTTON",button=>"continue_shopping",SKU=>$SKU, PID=>$PID, ID=>$BTNID,alt=>"Continue Shopping");
	print();
	load("1"); goto(eq=>"1",label=>"ENDBUTTON");

	:CANCEL();
	load($ID);
	format(posttext=>":cancel");
	set($BTNID=>$_);
	element(TYPE=>"SITEBUTTON",button=>"cancel",SKU=>$SKU, PID=>$PID, ID=>$BTNID,alt=>"Cancel");
	print();
	load("1"); goto(eq=>"1",label=>"ENDBUTTON");

	:ENDBUTTON();
	print("</a>");

:END();
print("");

%><%

load($FORM);
goto(lt=>"1",label=>"END");
	print("</form>");
:END();
print("");

%>~;

	#if (defined $SITE::CART2) {
	#	my $is_wholesale = $SITE::CART2->in_get('this/is_wholesale');
	#	if ((defined $is_wholesale) && (($is_wholesale & 2)==2)) {
	#		my $addsite_url = $SITE->URLENGINE()->rewrite("/product/$SITE->{'_PID'}");
	#		$out .= "<a href=\"\">".&TOXML::RENDER::RENDER_SITEBUTTON({'button' => 'add_to_site', 'alt' => 'Add To My Site'},undef,$SITE)."</a>";
	#		}
	#	}

	if ((defined $iniref->{'HTML'}) && ($iniref->{'HTML'} ne '')) {
		$spec = $iniref->{'HTML'};
		}


#	print STDERR Dumper($spec,$iniref);

	my ($out) = $SITE->txspecl()->translate3($spec,[$iniref,\%vars],replace_undef=>0);
	# $out = "<!-- FRED -->$out<!-- /FRED -->";
	# $out = &ZOOVY::incode($spec);

	#print STDERR Carp::cluck(Dumper($iniref,$out));
	#return("<h1>************** ADD TO FUCKING CART **************</h1>");
	return $out;
	} ## end sub RENDER_ADDTOCART

##
## there are three optional variables:
##		LIST_CONTENTS 	- 
##		LIST_CART	 	-
##		LIST_BUTTONS	- 
##
#
#	PRODHTML
#


sub RENDER_ORDER {
	my ($iniref,undef,$SITE) = @_;

	my $out = '';
	#if ($iniref->{'_PREVIEW'}) {
	#	require ORDER;
	#	my $USERNAME = $SITE->username();
	#	# $SITE->{'*order'} = ORDER->create($USERNAME,tmp=>1,preview=>1);
	#	}
	
	#if (defined $iniref->{'*ORDER'}) {
	#	$iniref->{'*order'} = $iniref->{'*ORDER'};
	#	}

	if (defined $SITE->{'*CART2'}) {
		$out .= CART2::VIEW::as_html( $SITE->{'*CART2'}, $iniref->{'MODE'}, $iniref, $SITE);
		}
	else {
		$out .= "<!-- *CART2 not defined -->";
		}

	# Spit it back up the chain
	return $out;
	}

##
##	RENDER_CART
##
## pass in a VERB of the following:
##		VIEW (default)
##		UPDATE
##	possible future ones:
##		XML
##
sub RENDER_CART {
	my ($iniref,undef,$SITE) = @_;

	# This whole module is simply a wrapper around CART::VIEW::as_html.  The meat of the display code is there.
	my $out = '';
	if ($iniref->{'VERB'} eq '') { $iniref->{'VERB'} = 'VIEW'; }

	#if (1) {
	#	warn "CALLED TOXML::RENDER::RENDER_CART VERB=$iniref->{'VERB'} was ignored\n";
	#	}
	if ($iniref->{'VERB'} eq 'VIEW') {
		$out .= CART2::VIEW::as_html($SITE::CART2,'SITE', $iniref, $SITE);
		}
	elsif ($iniref->{'VERB'} eq 'UPDATE') {
		# $SITE::CART2->recalc();
		}
	elsif ($iniref->{'VERB'} eq 'SHIPPING') {
		## we're running it locally, and oh btw - we MUST force an update if this is called implicitly (hence the 0,1)
		$SITE::CART2->shipmethods('flush'=>1);
		}

	# Spit it back up the chain
	return $out;
	} ## end sub RENDER_CART



# Makes the "Add to Cart" button, along with POGs and product notes for a product flow
sub RENDER_MINICART {
	my ($iniref,undef,$SITE) = @_; # iniref is a reference to a hash of the element's contents as defined in the flow file

	return('<!-- MINICART_NO_LONGER_AVAILABLE -->');
	} ## end sub RENDER_MINICART


## Flows expect uppercase params, wrappers expect lowercase.
## This'll check for a hashref for both (and also returns undefs as blanks)
sub inifind
{
	my ($hash,$param) = @_;
	unless (defined($hash) && (ref($hash) eq 'HASH')) { return ''; }
	unless (defined($param) && ($param ne '')) { return ''; }
	if (defined $hash->{uc($param)}) { return $hash->{uc($param)}; }
	if (defined $hash->{lc($param)}) { return $hash->{lc($param)}; }
	return '';
}

########################################
# MSG
# Description: Prints an error message to STDERR (the apache log file)
# Accepts: An error message as a string, or a reference to a variable (if a reference,
#          the name of the variable must be the next item in the list, in the format
#          that Data::Dumper wants it in).  For example:
#          &msg("This house is ON FIRE!!!");
#          &msg(\$foo=>'*foo');
#          &msg(\%foo=>'*foo');
# Returns: Nothing

sub msg
{
	my $head = 'TOXML::RENDER: ';
	while ($_ = shift (@_))
	{
		if (ref) { require Data::Dumper; $_ = Data::Dumper->Dump([$_], [shift (@_)]); }
#		print STDERR $head, join ("\n$head", split (/\n/, $_)), "\n";
	}
}

# Description: Returns a list of products related by category
# Accepts: merhcant ID, a reference to an array of SKUs or a hash keyed by SKU (shopping cart),
#          and optionally a maximum number of products to be returned
# Returns: an array of product ID's ranked by how well the function matched
sub smartcart_by_category {
	my ($SITE, $skuref, $max, $PRT) = @_;
	
	unless (defined $max) { $max = 12; }
	$max =~ s/\D//gs; # Only numbers, mmmmm'kay?
	unless ($max) { $max = 12; }
	
	# Process the SKU list we were handed
	my @skus;
	if (ref $skuref eq 'ARRAY') { @skus = @{$skuref} }
	else { 
		&ZOOVY::confess($SITE->{'USERNAME'},"SMARTCART_BY_CATEGORY NOT PASSED SKUREF",justkidding=>1);
		return ""; 
		}
	
	# Get all of the unique, stripped skus that aren't special cart items (grep !/^\W/ strips skus that begin with % and !)
	@skus = &ZTOOLKIT::unique(&TOXML::RENDER::cleanskus(grep !m/^\W/, @skus));
	
	# Get a hash of categories, with a value of the number of times it appeared in @skus
	my %prod_hash = ();

	# my $product_categories = &NAVCAT::product_categories_multi($merchant_id, @skus);
	my ($NC) = &SITE::get_navcats($SITE);
	foreach my $sku (@skus) {
		my $paths = $NC->paths_by_product($sku);
		if (defined $paths) {
			foreach my $path (@{$NC->paths_by_product($sku)}) {
				my ($pretty,$children,$products) = $NC->get($path);
				foreach my $catpid (split(/,/,$products)) { 
					$prod_hash{$catpid}++;
					}
				}
			}
		}

	## strip out skus' that were used to generate the list (since we're going to assume they are already on the page)
	##	this is useful since sometimes we end up displaying duplicate add to cart buttons and shit like that.
	foreach my $sku (@skus) {
		delete $prod_hash{$sku};
		}
	
	# Process the outgoing SKU list
	# The product list is needs to be sorted by value to get a ranked array
	# We reverse it since its sorted lowest values first
	my @products = reverse(&ZTOOLKIT::value_sort(\%prod_hash, 'numerically'));
	## Set the length of the @products array to the limit if its past
	if (scalar(@products) > $max) { $#products = ($max - 1); } 
	
	return @products;
	}



# Description: Returns a list of products comma separated in the field zoovy:related_products
# Accepts: merchat ID, a reference to an array of SKUs or a hash keyed by SKU (shopping cart),
#          and optionally a maximum number of products to be returned
# Returns: an array of product ID's ranked by how well the function matched
sub smartcart_by_product {
	my ($USERNAME, $skuref, $max) = @_;
	
	unless (defined $max) { $max = 12; }
	$max =~ s/\D//gs; # Only numbers, mmmmm'kay?
	unless ($max) { $max = 12; }

	my @pids = ();
	if (ref $skuref eq 'ARRAY') { @pids = @{$skuref} }
	else { 
		&ZOOVY::confess($USERNAME,"SMARTCART_BY_PRODUCT NOT PASSED SKUREF",justkidding=>1);
		return ""; 
		}
		
	# Get all of the unique, stripped skus that aren't special cart items (grep !/^\W/ strips skus that begin with % and !)
	## @skus = &ZTOOLKIT::unique(&cleanskus(grep !m/^\W/, @skus));
	# Modified regex from above to allow @ products
	
	# Get a hash of products, with a value of the number of times it was recommended in @skus
	my %prod_hash = ();
	foreach my $pid (@pids) {
		# my $related = &ZOOVY::fetchproduct_attrib($USERNAME, $pid, 'zoovy:related_products');
		# my $prodref = &ZOOVY::fetchproduct_as_hashref($USERNAME,$pid);
		# my $prodref = &ZOOVY::fetchproduct_as_hashref($USERNAME,$pid);
		my ($P) = PRODUCT->new($USERNAME,$pid);
		my $related = (defined $P)?$P->fetch('zoovy:related_products'):'';

		next unless ((defined $related) && ($related ne ''));
		my @related_skus = split /,/, $related;
		foreach my $product (@related_skus)
		{
			$product = &ZTOOLKIT::trim($product);
			next unless ($product =~ m/\w+/);
			next if (&ZTOOLKIT::isin(\@pids, $product));
			if (not defined $prod_hash{$product})
			{
				$prod_hash{$product} = 0;
			}
			$prod_hash{$product}++;
		}
	}
	
	# Process the outgoing SKU list
	# The product list is needs to be sorted by value to get a ranked array
	# We reverse it since its sorted lowest values first
	my @products = &ZTOOLKIT::value_sort(\%prod_hash,'numerically');
	## Set the length of the @products array to the limit if its past
	if (scalar(@products) > $max) { $#products = ($max - 1); }
		
	return @products;

}


## 
sub cleanskus {
   my @newskus = @_;
   foreach (@newskus) {
      s/^.*\*(.*?)$/$1/;
      s/^(.*?)\:.*$/$1/;
      s/^(.*?)\/.*$/$1/;
      }
   return @newskus;
   }



# Functions for lists based on the following:
#	product popularity
#	rules
#	customer history

########################################
# MSG
# Description: Prints an error message to STDERR (the apache log file)
# Accepts: An error message as a string, or a reference to a variable (if a reference,
#          the name of the variable must be the next item in the list, in the format
#          that Data::Dumper wants it in).  For example:
#          &msg("This house is ON FIRE!!!");
#          &msg(\$foo=>'*foo');
#          &msg(\%foo=>'*foo');
# Returns: Nothing

##
## this basically is used to parse the old "SAVETO" (now DATA) element in prodlists
##		to load in default values for the menu designer. It used to be stored in FLOW::PRODLIST::parse_data
##		but seemed rather trivial to have it's own module. 9/15/05 -BH
sub parse_prodlist_data {
	my ($DATA,$iniref,$SITE) = @_;

	my $USERNAME = $SITE->username();
	my %params = ();
	if (not defined $DATA) { $DATA = ''; }

	if (substr($DATA,0,1) ne "&") {
		## LEGACY CODE
		($params{'FORMAT'},$params{'COLS'},$params{'ALTERNATE'},$params{'SORTBY'},my $otherparams) = split(/\,/, $DATA);
		# Parse additional parameters
		# NOTE: These parameters' names and values obvoiusly shouldn't contain ":", "=" or ","
		# since they are delimiters.  This is OK since we have control over what the meaning
		# of the names and values of these parameters are.
		if (defined $otherparams) {
			foreach my $nameval (split /\:/, $otherparams) {
				my ($name, $val) = split /\=/, $nameval; $params{$name} = $val;
				}
			}
		## END LEGACY CODE
		}
	else {
		## VERSION2 CODE
		foreach my $kv (split(/\&/,$DATA)) {
			next if ($kv eq '');
			my ($k,$v) = split(/=/,$kv,2);
			next if ((not defined $k) || (not defined $v));
			$params{$k}	= URI::Escape::XS::uri_unescape($v);
			}
		}

	if ((not defined $params{'SORTBY'}) || ($params{'SORTBY'} eq '')) {
		## NOTE: we're going to need to put an end to this soon.

		#require NAVCAT;
		#(undef,undef,undef,$params{'SORTBY'}) = &NAVCAT::fetch_info($USERNAME,&NAVCAT::resolve_navcat_from_page($SITE->pageid())); 
		# print STDERR "SORTby=[$params{'SORTBY'}] [$USERNAME] SITE::PG=[$SITE->pageid()]\n";
		my ($NC) = &SITE::get_navcats($SITE);
		(undef,undef,undef,$params{'SORTBY'}) = $NC->get($SITE->pageid());
		undef $NC;
		}

	# Catch everything else since I don't want to change every PRODLIST in every flow :)
	if (not defined $params{'SMARTSOURCE'}) { $params{'SMARTSOURCE'} = ''; } # Show the View Details link in the list
	if (not defined $params{'SMARTMAX'}) { $params{'SMARTMAX'} = '12'; } # Show the View Details link in the list

	if (not defined $params{'VIEWDETAILS'}) { $params{'VIEWDETAILS'} = 1; } # Show the View Details link in the list
	if (not defined $params{'SHOWSKU'}) { $params{'SHOWSKU'} = ''; } # Determines if/where the SKU will be shown with the product name
	if (not defined $params{'SHOWQUANTITY'}) { $params{'SHOWQUANTITY'} = 0; } # Add a quantity textbox for multiple-add to cart
	if (not defined $params{'SHOWNOTES'}) { $params{'SHOWNOTES'} = 0; } # Have the ability to edit product notes right inside the prodlist element
	if (not defined $params{'SHOWPRICE'}) { $params{'SHOWPRICE'} = 1; } # Have the showing of prices on by default
	if (not defined $params{'SIZE'}) { $params{'SIZE'} = ''; } # The number of products per page (blank means no paging)

	# These settings force the use of iniref settings (which always trump user values!)
	foreach my $k (keys %{$iniref}) {
		$params{$k} = $iniref->{$k};
		}


	if (defined $iniref->{'SOURCE'}) {
		##  not sure what the fuck this is.. looks like it lets us specify a different navigation category. uses navcat:xxxx notation.. so
		## just act like it was SRC the entire titme
		$params{'SRC'} = $iniref->{'SOURCE'};
		}

	if (not defined $params{'SRC'}) { 
		## "SRC" defaults to "SMARTSOURCE" (legacy .. dumb name!) 
		$params{'SRC'} = $params{'SMARTSOURCE'};
		}

	## All "SMART" types were remapped to "SMART:xxxx" for faster regex mapping e.g. /smart:/ /list:/ etc.
	if ($params{'SRC'} eq 'CHOOSE') { $params{'SRC'} = 'SMART:BYPRODUCT'; }
	elsif ($params{'SRC'} eq 'BYCATEGORY') { $params{'SRC'} = 'SMART:BYCATEGORY'; }

	return(\%params);
	}


1;

