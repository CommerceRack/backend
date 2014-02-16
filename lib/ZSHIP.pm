package ZSHIP;
##
## NOTICE:
## 	if you plan to add international types, then make sure you add them to int_destinations_by_merchant
##
## 4/2/01 added simple_dom shipping bitwise operators 2 and 4 
## 4/2/01 disabled fedex, ups, and usps if we don't have a destination zip int dom_marshal.
## 10/20/02 Reformatted using perl tidy, added in a bunch of comments.  Changed error reporting to use standardized &msg function
## 4/8/02 Added use strict, fixed a typo in the virtuals section (both $qty and $quantity were being used, looked like a copy-paste flub) and added a couple of "my $foo" to foreach loops to make it pass muster
## 12/19/04 - removed &msg functions!
##


use strict;

use Data::Dumper;
use Storable;
use CDB_File;
use Text::CSV_XS;
use POSIX;
use LWP::UserAgent;
use XML::Simple;

use lib "/backend/lib";
require ZOOVY;
require PRODUCT;
require ZWEBSITE;
require ZSHIP::RULES;
require ZTOOLKIT;
require SUPPLIER;
sub def { ZTOOLKIT::def(@_); }

$ZSHIP::OUTPUT = '';		# holds output

## The format for these files is as follows:
## "ZOOVY NAME", "Fedex Code", "USPS Code", "UPS Code"\n
## If a country is not available for a specific carrier then it should have a "" entry.
## NOTE: Quotes are REQUIRED
#$ZSHIP::INT_CANADAONLY_FILE = "/httpd/static/canadaonly.txt";
#$ZSHIP::INT_HIGHRISK_FILE   = "/httpd/static/highrisk.txt";
#$ZSHIP::INT_LOWRISK_FILE    = "/httpd/static/lowrisk.txt";


#$VAR1 = {
#          'DHL' => 3,
#          'OTHR' => 250,
#          'FDXG' => 1165,
#          'UPS' => 3539,
#          'USPS' => 8485,
#          'FEDX' => 854,
#          'FDXE' => 108
#        };


%ZSHIP::SHIPCODES = (
	## these are for amazon, it's a lookup table for the generic carriers which are sometimes used
	## when the specific method ex: FDXG or FXSP isn't known - we just get FDX
	#'FDX'=>{ carrier=>'FDX', },
	#'UPS'=>{ carrier=>'UPS', },
	#'USPS'=>{ carrier=>'USPS', },
	#'DHL'=>{ carrier=>'DHL', },
	# 'OTHR'=>{ wtf? used by amazon - maybe?
	# Amazon carrier codes:

	'CALL'=>{ method=>"Call for arrangements" },
	'ELSE'=>{ method=>"Shipping Method of Last Resort" },
	'ESD'=>{ expedited=>'1', method=>"Electronic Download", defaultable=>1 },
	'CPU'=>{ expedited=>'0', method=>"Customer Pickup", defaultable=>0 },
	'DELI'=>{ expedited=>'0', method=>"Local Deliver", defaultable=>1 },
	## GENERIC OVERNIGHT.
	#FAST|Carrier not determined - expedited shipping
	'BEST'=>{  expedited=>'1', method=>'Primary Carrier - Priority Overnight', carrier=>'', is_nextday=>1 },
	'FAST'=>{  expedited=>'1', method=>'Primary Carrier - Expedited', carrier=>'', is_nextday=>0 },
	'SLOW'=>{  expedited=>'0', method=>'Primary Carrier - Non-Expedited (usually ground)', carrier=>'', is_nextday=>0 },

	## IDEAS:
	## 	LOOK
	## 	HELP

	'1DAY'=>{  expedited=>'1', method=>'1 Day Shipping', carrier=>'', is_nextday=>1, },
	'2DAY'=>{  expedited=>'1', method=>'2 Day Shipping', carrier=>'', is_nextday=>0, },
	'3DAY'=>{  expedited=>'0', method=>'3 Day Shipping', carrier=>'', is_nextday=>0, },
	## replaces 1DAY,2DAY,3DAY
	'DAY1'=>{  expedited=>'1', method=>'1 Day Shipping', carrier=>'', is_nextday=>1, },
	'DAY2'=>{  expedited=>'1', method=>'2 Day Shipping', carrier=>'', is_nextday=>0, },
	'DAY3'=>{  expedited=>'0', method=>'3 Day Shipping', carrier=>'', is_nextday=>0, },
#	'BOB'=>{ expedited=>0, method=>"Bobs Intergalactic Teleportation Service", carrier=>'' },

	###################################################
	## FEDEX
	# FXGR|FedEx Ground
	'FEDEX'=>{  expedited=>'0', method=>'FedEx', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx Ground', buycomtc=>'2', is_alias=>1, },
	'FEDX'=>{  expedited=>'0', method=>'FedEx', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx Ground', buycomtc=>'2', is_alias=>1, },
	'FDX'=>{  expedited=>'0', method=>'FedEx', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx Ground', buycomtc=>'2', is_alias=>1, },
	## generic fedex ground
	'FDXG'=>{  carrier=>'FDX', method=>'FedEx Ground' },
	'FXGR'=>{  expedited=>'0', method=>'FedEx Ground', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx Ground', buycomtc=>'2' },
	# FXHD|FedEx Home Delivery
	'FXHD'=>{  expedited=>'0', method=>'FedEx Home Delivery', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx Home Delivery', buycomtc=>'2' },
	# FXHE|FedEx Evening Home
	'FXHE'=>{  expedited=>'0', method=>'FedEx Evening Home', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx Evening Home', buycomtc=>'2' },
	# FXES|FedEx Express Saver: 3 Day
	'FXES'=>{  expedited=>'0', method=>'FedEx Express Saver', deliverby=>'3 days', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx Express Saver', buycomtc=>'2' },
	# FXSO|FedEx Standard Overnight: 3pm next day
	'FXSO'=>{  expedited=>'1', method=>'FedEx Standard Overnight', deliverby=>'3pm next day', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx Standard Overnight', buycomtc=>'2', is_nextday=>1 },
	# FXPO|FedEx Priority Overnight: 10:30am next day
	'FXPO'=>{  expedited=>'1', method=>'FedEx Priority Overnight', deliverby=>'10:30am next day', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx Priority Overnight', buycomtc=>'2', is_nextday=>1 },
	# FXFO|FedEx First Overnight: 8:30am next day
	'FXFO'=>{  expedited=>'1', method=>'FedEx First Overnight', deliverby=>'8:30am next day', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx First Overnight', buycomtc=>'2', is_nextday=>1, is_fastest=>1 },
	# FXIP|FedEx International Priority
	'FXIP'=>{  expedited=>'1', method=>'FedEx International Priority', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx International Priority', buycomtc=>'2' },
	'FXIG'=>{  expedited=>'0', method=>'FedEx International Ground', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx International Ground', buycomtc=>'2' },
	'FXIF'=>{  expedited=>'1', method=>'FedEx International First', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx International First', buycomtc=>'2', is_nextday=>1 },
	#FXIE|FedEx International Economy
	'FXIE'=>{  expedited=>'1', method=>'FedEx International Economy', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx International Economy', buycomtc=>'2' },
	#FX2D|FedEx 2 Day
	'FX2D'=>{  expedited=>'1', method=>'FedEx Second Day', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx Second Day', buycomtc=>'2' },
	'FX2A'=>{  expedited=>'0', method=>'Fedex Second Day AM', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx Second Day (AM)', buycomtc=>'2' },
	'FXSP'=>{  expedited=>'0', method=>'FedEx Smart Post', carrier=>'FDX', amzcc=>'FedEx', amzmethod=>'FedEx Smart Post', buycomtc=>'2' },
	##################################################
	## UPS
	#U1DP|UPS Next Day Air Saver
	'UPS'=>{  expedited=>'0', method=>'United Parcel Service (UPS)', carrier=>'UPS', amzcc=>'UPS', amzmethod=>'UPS', buycomtc=>'1', is_alias=>1, },
	'U1DP'=>{  expedited=>'1', method=>'UPS Next Day Air Saver', carrier=>'UPS', amzcc=>'UPS', amzmethod=>'UPS Next Day Air Saver', buycomtc=>'1', ups=>'1DP', upsxml=>'13', is_nextday=>1 },
	#U1DA|UPS Next Day Air?
	'U1DA'=>{  expedited=>'1', method=>'UPS Next Day Air', carrier=>'UPS', amzcc=>'UPS', amzmethod=>'UPS Next Day Air', buycomtc=>'1', ups=>'1DA', upsxml=>'01', is_nextday=>1 },
	#U1DAS|UPS Next Day Air (Saturday)
	'U1DAS'=>{  expedited=>'1', method=>'UPS Next Day Air Saturday Delivery', carrier=>'UPS', amzcc=>'UPS', amzmethod=>'UPS Next Day Air (SAT)', buycomtc=>'1', ups=>'1DAS', upsxml=>'01', is_nextday=>1, is_saturday=>1 },
	#U1DM|UPS Next Day Air Early A.M.
	'U1DM'=>{  expedited=>'1', method=>'UPS Next Day Air Early A.M.', carrier=>'UPS', amzcc=>'UPS', amzmethod=>'UPS Next Day Air Early A.M.', buycomtc=>'1', ups=>'1DM', upsxml=>'14', is_nextday=>1, is_fastest=>1 },
	#U1DMS|UPS Next Day Air Early A.M. (Saturday)
	'U1DMS'=>{   expedited=>'1', method=>'UPS Next Day Air Early A.M. Saturday Delivery', carrier=>'UPS', amzcc=>'UPS', amzmethod=>'UPS Next Day Air Early A.M. (Sat)', buycomtc=>'1', ups=>'1DMS', upsxml=>'14', is_nextday=>1, is_saturday=>1, is_fastest=>1 },
	#UGND|UPS Ground
	'UGND'=>{   expedited=>'0', method=>'UPS Ground', carrier=>'UPS', amzcc=>'UPS', amzmethod=>'UPS Ground', buycomtc=>'1', ups=>'GND', upsxml=>'03' },
	#U2DA|UPS 2nd Day Air
	'U2DA'=>{   expedited=>'1', method=>'UPS 2nd Day Air', carrier=>'UPS', amzcc=>'UPS', amzmethod=>'UPS 2nd Day Air', buycomtc=>'1', ups=>'2DA', upsxml=>'02' },
	#U2DAS|UPS 2nd Day Air
	'U2DAS'=>{  expedited=>'1', method=>'UPS 2nd Day Air (Saturday)', carrier=>'UPS', amzcc=>'UPS', amzmethod=>'UPS 2nd Day Air (Saturday)', buycomtc=>'1', ups=>'2DAS', upsxml=>'02', is_saturday=>1 },
	#U2DM|UPS 2nd Day Air A.M.
	'U2DM'=>{  expedited=>'1', method=>'UPS 2nd Day Air A.M.', carrier=>'UPS', amzmethod=>'UPS 2nd Day Air A.M.', amzcc=>'UPS', buycomtc=>'1', ups=>'2DM', upsxml=>'59' },
	#U3DS|UPS 3 Day Select
	'U3DS'=>{  expedited=>'0', method=>'UPS 3 Day Select', amzcc=>'UPS', amzmethod=>'UPS 3 Day Select', buycomtc=>'1', ups=>'3DS', upsxml=>'12' },
	#USTD|UPS Standard to Canada
	'USTD'=>{   expedited=>'0', method=>'UPS Standard to Canada', carrier=>'UPS', amzcc=>'UPS', amzmethod=>'UPS Standard to Canada', buycomtc=>'1', ups=>'STD', upsxml=>'11' },
	#UXPR|UPS Worldwide Express
	'UXPR'=>{   expedited=>'1', method=>'UPS Worldwide Express', carrier=>'UPS', amzcc=>'UPS', amzmethod=>'UPS Worldwide Express', buycomtc=>'1', ups=>'XPR', upsxml=>'07' },
	#UXDM|UPS Worldwide Express Plus
	'UXDM'=>{   expedited=>'1', method=>'UPS Worldwide Express Plus', carrier=>'UPS', amzcc=>'UPS', amzmethod=>'UPS Worldwide Express Plus', buycomtc=>'1', ups=>'XDM', upsxml=>'54' },
	#UXPD|UPS Worldwide Expedited
	'UXPD'=>{  expedited=>'1', method=>'UPS Worldwide Expedited', carrier=>'UPS', amzcc=>'UPS', amzmethod=>'UPS Worldwide Expedited', buycomtc=>'1', ups=>'XPD', upsxml=>'08' },
	'UXSV'=>{  expedited=>'1', method=>'UPS Worldwide Saver', carrier=>'UPS', amzcc=>'UPS', amzmethod=>'UPS Worldwide Saver', buycomtc=>'1', ups=>'XSV', upsxml=>'65' },

	## UPS Mail Innovations
	'UPMI'=>{  expedited=>'0', 'ebay'=>'UPS-MI', method=>'UPS Mail Innovations', carrier=>'UPS', amzcc=>'UPSMI', amzmethod=>'UPS Mail Innovations', buycomtc=>1, },
	'BLUE'=>{ expedited=>'0', amzcc=>'', amzmethod=>'Blue Package' },
	'DHLG'=>{ expedited=>'0', amzcc=>'', amzmethod=>'DHL Global Mail' },
	'FAWA'=>{ expedited=>'0', amzcc=>'', amzmethod=>'Fastway' },
#	''=>{ expedited=>'0', amzmethod=>'UPS Mail Innovations' },
	'LASH'=>{ expedited=>'0', amzcc=>'', amzmethod=>'Lasership' },
	'ROMA'=>{ expedited=>'0', amzcc=>'', amzmethod=>'Royal Mail' },
#	''=>{ expedited=>'0', amzmethod=>'FedEx SmartPost' },
#	## OSM Worldwide osmworldwide.com
	'OSMW'=>{ expedited=>'0', method=>'OSM Worldwide', amzcc=>'OSM', amzmethod=>'OSM Worldwide' },
	'ONTR'=>{ expedited=>'0', amzcc=>'', amzmethod=>'OnTrac' },
#	''=>{ expedited=>'0', amzmethod=>'Streamlite' },
	'NEWG'=>{ expedited=>'0', amzcc=>'', amzmethod=>'Newgistics' },
	'CADP'=>{ expedited=>'0', amzcc=>'', amzmethod=>'Canada Post' },
#	''=>{ expedited=>'0', amzmethod=>'City Link' },
	'GLS'=>{ expedited=>'0', amzcc=>'', amzmethod=>'GLS' },
	'GO'=>{ expedited=>'0', amzcc=>'', amzmethod=>'GO!' },
	'PAFO'=>{ expedited=>'0', amzcc=>'', amzmethod=>'Parcelforce' },
	'TNT'=>{ expedited=>'0', amzcc=>'', amzmethod=>'TNT' },
	'TARG'=>{ expedited=>'0', amzcc=>'', amzmethod=>'Target' },
	'SAEX'=>{ expedited=>'0', amzcc=>'', amzmethod=>'SagawaExpress' },
	'NIEX'=>{ expedited=>'0', amzcc=>'', amzmethod=>'NipponExpress' },
	'YATR'=>{ expedited=>'0', amzcc=>'', amzmethod=>'YamatoTransport' },
#	''=>{ expedited=>'0', amzmethod=>'Other' },

	## EBAY SPECIFIC CARRIERS 
	'CHPO'=>{ method=>'Chronopost', ebay=>'Chronopost', 'carrier'=>'Chronopost' },
	'CODO'=>{ method=>'Coliposte Domestic',  ebay=>'ColiposteDomestic', 'carrier'=>'Coliposte Domestic'},
	'COIN'=>{ method=>'Coliposte International',  ebay=>'ColiposteInternational', 'carrier'=>'Coliposte International'},
	'CORR'=>{ method=>'Correos',  ebay=>'Correos', 'carrier'=>'Correos'},
	'DEPO'=>{ method=>'Deutsche Post',  ebay=>'DeutschePost', 'carrier'=>'Deutsche Post'},
	'DHL'=>{ method=>'DHL service',  ebay=>'DHL', 'carrier'=>'DHL service', amzcc=>'', amzmethod=>'DHL' },
	'EBGM'=>{ method=>'eBay GlobalShipping MultiCarrier',  ebay=>'GlobalShipping_MultiCarrier', 'carrier'=>''},
	'HERM'=>{ method=>'Hermes',  ebay=>'Hermes', 'carrier'=>'Hermes', amzcc=>'', amzmethod=>'Hermes Logistik Gruppe' },
	'ILOX'=>{ method=>'iLoxx',  ebay=>'iLoxx', 'carrier'=>'iLoxx'},
	'NACE'=>{ method=>'Nacex',  ebay=>'Nacex', 'carrier'=>'Nacex'},
	'SERU'=>{ method=>'Seur',  ebay=>'Seur', 'carrier'=>'Seur'},

	########################################################
	## USPS
	#EFCM|FIRST|First Class Mail
	'USPS'=>{   expedited=>'0', method=>'US Postal Service', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS priority mail', buycomtc=>'1', is_alias=>1, },
	'EFCM'=>{  expedited=>'0', endicia=>'FIRST', method=>'First Class Mail', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS First Class Mail', buycomtc=>'3'  },
	#EPRI|PRIORITY|Priority Mail
	'EPRI'=>{   expedited=>'0', endicia=>'PRIORITY', method=>'Priority Mail', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS Priority Mail', buycomtc=>'3' },
	#ESPP|PARCELPOST|Parcel Post
	'ESPP'=>{   expedited=>'0', endicia=>'PARCELPOST', method=>'Parcel Post', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS Parcel Post', buycomtc=>'3' },
	#ESMM|MEDIAMAIL|Media Mail
	'ESMM'=>{   expedited=>'0', endicia=>'MEDIAMAIL', method=>'Media Mail', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS Media Mail', buycomtc=>'3' },
	#ESLB|LIBRARYMAIL|Library Mail
	'ESLB'=>{   expedited=>'0', endicia=>'LIBRARYMAIL', method=>'Library Mail', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS Library Mail', buycomtc=>'3' },
	#ESBM|BOUNDPRINTEDMATTER|Bound Printed Matter
	'ESBM'=>{   expedited=>'0', endicia=>'BOUNDPRINTEDMATTER', method=>'Bound Printed Matter', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS Bound Printed Matter', buycomtc=>'3' },
	#EXPR|EXPRESS|Express Mail
	'EXPR'=>{   expedited=>'1', endicia=>'EXPRESS', method=>'Express Mail', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS Express Mail', buycomtc=>'3' },
	#EPFC|PRESORTEDFIRST|Presorted, First-Class
	'EPFC'=>{   expedited=>'0', endicia=>'PRESORTEDFIRST', method=>'Presorted, First-Class', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS First-Class', buycomtc=>'3' },
	#EPFC|PRESORTEDSTANDARD|Presorted, Standard Class
	'EPFC'=>{   expedited=>'0', endicia=>'PRESORTEDSTANDARD', method=>'Presorted, Standard Class', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS Standard Class', buycomtc=>'3' },
	#EIFC|INTLFIRST|International First Class
	'EIFC'=>{   expedited=>'0', endicia=>'INTLFIRST', method=>'International First Class', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS International First Class', buycomtc=>'3' },
	#EIEM|INTLEXPRESS|International Express Mail
	'EIEM'=>{   expedited=>'1', endicia=>'INTLEXPRESS', method=>'International Express Mail', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS International Express Mail', buycomtc=>'3' },
	#EIPM|INTLPRIORITY|International Priority Mail
	'EIPM'=>{   expedited=>'0', endicia=>'INTLPRIORITY', method=>'International Priority Mail', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS International Priority Mail', buycomtc=>'3' },
	#EGEG|INTLGXG|Global Express Guaranteed
	'EGEG'=>{   expedited=>'1', endicia=>'INTLGXG', method=>'Global Express Guaranteed', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS Global Express Guaranteed', buycomtc=>'3' },
	#EGGN|INTLGXGNODOC|Global Express Guaranteed, Non-Documents
	'EGGN'=>{   expedited=>'1', endicia=>'INTLGXGNODOC', method=>'Global Express Guaranteed, Non-Documents', carrier=>'USPS', amzcc=>'USPS', amzmethod=>'USPS Global Express Guaranteed', buycomtc=>'3' },
	#NONE|NONE|Do not print postage
	'NONE'=>{ expedited=>'0', endicia=>'NONE', method=>'Do not print postage', },

	);


sub has_ups_restriction {
	my ($USERNAME) = @_;

	if ($USERNAME eq 'spaparts') { return(0); }
	return(1);
	}


##
## creates a line for a row in @SHIPMETHODS
##	optional parameters:
##		carrier=>
##		id=>
##		ruleset=>
##		api_err_msg=>
##		api_err_code=>
##	other optional parameters:
##
##
sub build_shipmethod_row {
	my ($pretty,$price,%options) = @_;

	if ($price < 0) { $price = 0; }

	my %SHIPROW = %options;
	$SHIPROW{'pretty'} = $pretty;
	$SHIPROW{'name'} = $pretty;
	$SHIPROW{'amount'} = sprintf("%.2f",$price);
	if (not defined $SHIPROW{'carrier'}) {
		$SHIPROW{'carrier'} = 'SLOW';
		}
	if (not defined $SHIPROW{'id'}) {
		## all shipping rows require a unique id.
		$SHIPROW{'id'} = uc(sprintf("%s-%s-%s",$SHIPROW{'carrier'},$SHIPROW{'pretty'},$SHIPROW{'amount'}));
		$SHIPROW{'id'} =~ s/[^A-Z0-9\-]/-/gs;
		}
	if ((not defined $SHIPROW{'carrier'}) || ($SHIPROW{'carrier'} eq '')) {
		$SHIPROW{'carrier'} = 'SLOW';
		}

	return(\%SHIPROW);
	}


#

##
##
sub time_in_transit {
	my ($USERNAME,$PRT,%options) = @_;

	require Date::Calc;

	my $WEBDBREF = $options{'webdb'};
	if (not defined $WEBDBREF) { $WEBDBREF = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT); }

	my @LOG = ();
	my @RESPONSES = ();

	require ZSHIP::UPSAPI;
	&ZSHIP::UPSAPI::upgrade_webdb($WEBDBREF);

	if (not defined $options{'ship_postal'}) {
		# $options{'ship_region'} = 'CA';
		$options{'ship_postal'} = '92024';
		$options{'ship_country'} = 'US';
		}

	
   ## ORIGIN ZIP
	$options{'origin_postal'} = $WEBDBREF->{'ship_origin_zip'};
	# $options{'origin_region'} = &ZSHIP::zip_state($WEBDBREF->{'ship_origin_zip'});
	$options{'origin_country'} = 'US';	

   ## FULFILLMENT LATENCY
	my $latency = int($WEBDBREF->{'ship_latency'});
	$latency++;

   ## FULFILLMENT CUTOFF
	my $cutoff = $WEBDBREF->{'ship_cutoff'};
  	# push @MSGS, "ERROR|Fulfillment cut off time is invalid! (Ex. 14:00 or 08:00)";

	
	my $origin_region = $options{'origin_region'};
	my $origin_country = $options{'origin_country'};
	my $origin_postal = $options{'origin_postal'};
	my $pickup_yyyymmdd = &ZTOOLKIT::pretty_date(time()+($latency*86400),-2); 
	
	my %RESPONSE = ();
	$RESPONSE{'cutoff_hhmm'} = sprintf("%02d%02d",substr($cutoff,0,2),substr($cutoff,2,2));
	$RESPONSE{'latency_days'} = $latency;
	$RESPONSE{'ships_yyyymmdd'} = $pickup_yyyymmdd;

	my $pickup_yyyy = substr($pickup_yyyymmdd,0,4);
	my $pickup_mm = substr($pickup_yyyymmdd,4,2);
	my $pickup_dd = substr($pickup_yyyymmdd,6,2);

	my $pickup_date = Date::Calc::Mktime($pickup_yyyy,$pickup_mm,$pickup_dd,0,0,1);
	

	my @SERVICES = ();
	if ($WEBDBREF->{'upsapi_config'} ne '') {
		require ZSHIP::UPSAPI;
		my $config = &ZTOOLKIT::parseparams($WEBDBREF->{'upsapi_config'});

		if (not $config->{'enable_dom'}) {
			push @LOG, "Skipped Domestic/UPS because not enabled.";
			}
		else {
			my ($UPSRESPONSE) = &ZSHIP::UPSAPI::time_in_transit($USERNAME,$WEBDBREF,
				'origin_region'=>$origin_region,
				'origin_country'=>$origin_country,
				'origin_postal'=>$origin_postal,
				'ship_region'=>$options{'ship_region'},
				'ship_country'=>$options{'ship_country'},
				'ship_postal'=>$options{'ship_postal'},
				'pickup_yyyymmdd'=>$pickup_yyyymmdd,
				);

			if ($UPSRESPONSE->{'@Error'}) {
				## Shit happened.
				$RESPONSE{'ErrorId'} = $UPSRESPONSE->{'@Error'}->[0];
				$RESPONSE{'ErrorMsg'} = $UPSRESPONSE->{'@Error'}->[1];
				$RESPONSE{'ErrorDetail'} = $UPSRESPONSE->{'@Error'}->[2];
				}
			else {
				## SUCCESS: Parse the UPS Responses

				require Date::Calendar;	
				require Date::Calendar::Profiles;	
				my %UPS_HOLIDAY_PROFILE = (
			    # For labeling only (defaults, may be overridden):
			    # "Valentine's Day"               => "#Feb/14",
					# "Maundy Thursday"               => "#-3",
					# "Good Friday"                   => "#-2",
  		  			# "Election Day"                  => \&US_Election,
    				"New Year's Eve"                => "#Dec/31",
    				# Common legal holidays (in all federal states):
    				"New Year's Day"                => \&Date::Calendar::Profiles::US_New_Year,
 				   # "Martin Luther King's Birthday" => "3/Mon/Jan",
	    			# "President's Day"               => "3/Mon/Feb",
  		  			"Memorial Day"                  => "5/Mon/May",
  	  				"Independence Day"              => \&Date::Calendar::Profiles::US_Independence,
  	  				"Labor Day"                     => "1/Mon/Sep",
	    			# "Columbus Day"                  => "2/Mon/Oct",
   	 			# "Halloween"                     => "#Oct/31",
    				# "All Saints Day"                => "#Nov/1",
    				# "All Souls Day"                 => "#Nov/2",
					# "Veterans' Day"                 => \&Date::Calendar::Profiles::US_Veteran(),
					"Thanksgiving Day"              => "4/Thu/Nov",
					"Day After Thanksgiving Day"    => "4/Fri/Nov",
					"Christmas Day"                 => \&Date::Calendar::Profiles::US_Christmas
					);
				my $calendar  = Date::Calendar->new( \%UPS_HOLIDAY_PROFILE );

				foreach my $k (keys %{$UPSRESPONSE}) {
					## copy UPS Specific keys
					next if ($k eq '@ServiceSummary');
					$RESPONSE{"UPS.$k"} = $UPSRESPONSE->{$k};
					}
            #                     {
            #                       'Service.Description' => 'UPS 3 Day Select',
            #                       'EstimatedArrival.BusinessTransitDays' => '3',
            #                       'EstimatedArrival.Time' => '23:00:00',
            #                       'Guaranteed' => 'Y',
            #                       'Service.Code' => '3DS',
            #                       'EstimatedArrival.DayOfWeek' => 'FRI',
            #                       'EstimatedArrival.PickupDate' => '2012-07-10'
            #                     },
	#			print STDERR Dumper('UPSRESPONSE',$UPSRESPONSE);
 				foreach my $ups (@{$UPSRESPONSE->{'@ServiceSummary'}}) {
					my %SERVICE = ();
					foreach my $k (keys %{$ups}) { 
						next if ($k eq 'Service.Code');
						next if ($k eq 'EstimatedArrival.BusinessTransitDays');
						$SERVICE{"UPS.$k"} = $ups->{$k}; 
						}
					$SERVICE{'id'} = sprintf("U%s",$ups->{"Service.Code"});
					my $shipref = &ZSHIP::shipinfo($SERVICE{'id'});
					foreach my $k (keys %{$shipref}) {
						$SERVICE{"$k"} = $shipref->{$k};
						}
					$SERVICE{'transit_days'} = $ups->{"EstimatedArrival.BusinessTransitDays"};
					$SERVICE{'arrival_hhmm'} = sprintf("%02d%02d",substr($ups->{"EstimatedArrival.Time"},0,2),substr($ups->{"EstimatedArrival.Time"},2,2));
					# my @YYYY__MM__DD = Date::Calc::Add_Delta_Days($pickup_yyyy,$pickup_mm,$pickup_dd,int($SERVICE{'transit_days'}));
					my @YYYY__MM__DD = $calendar->add_delta_workdays($pickup_yyyy,$pickup_mm,$pickup_dd,int($SERVICE{'transit_days'}));
					$SERVICE{'arrival_yyyymmdd'} = sprintf("%04d%02d%02d",$YYYY__MM__DD[0],$YYYY__MM__DD[1],$YYYY__MM__DD[2]);
			
					push @SERVICES, \%SERVICE;
					}
				}

			}
		}
	else {
		push @LOG, "INFO|UPS not configured";
		}
	$RESPONSE{'@Services'} = \@SERVICES;
	$RESPONSE{'@DEBUG'} = \@LOG;
	
	return(\%RESPONSE);
	}


##
## returns data from the ZSHIP::SHIPCODES table
##
sub shipinfo {
	my ($SHIPCODE,$key) = @_;

	my $shipref = undef;
	if (defined $ZSHIP::SHIPCODES{$SHIPCODE}) {
		$shipref = $ZSHIP::SHIPCODES{$SHIPCODE};
		}
	else {
		$shipref = {
			'carrier'=>$SHIPCODE,
			'method'=>"Carrier: $SHIPCODE",
			'is_alias'=>1,
			'is_error'=>1,	# not used? but seems like a good idea
			};
		}

	if (not defined $key) {
		## returns the full hash
		return($shipref);
		}
	else {
		$key = lc($key);
		return($shipref->{$key});
		}
	}

##
##
##
# usage:  
# my $shipref = &ZSHIP::shipinfo($trkref->{'carrier'})
# my ($link,$text) = &ZSHIP::trackinglink($shipref,$trkref->{'track'});
#
sub trackinglink {
	my ($shipinforef, $tracking) = @_;

	my ($link,$text) = ('#','n/a');

	my $CARRIER = $shipinforef->{'carrier'};

	if ($CARRIER eq 'UPS') {
		$link = sprintf("http://wwwapps.ups.com/WebTracking/processInputRequest?HTMLVersion=5.0&loc=en_US&Requester=UPSHome&tracknum=%s&AgreeToTermsAndConditions=yes",$tracking);
		$text = 'visit UPS.com';
		}
	elsif ($CARRIER eq 'USPS') {
		## updated 11/01/2006
		#$c .= "<td bgcolor='FFFFFF'><a target=\"track\" href=\"http://www.usps.com/shipping/trackandconfirm.htm?CUT_AND_PASTE=$value\">visit USPS.com</a>";
		# Apparently usps can have numbers now too! 2/15/07 $value =~ s/[^\d]+//g;
		$link = sprintf('http://trkcnfrm1.smi.usps.com/PTSInternetWeb/InterLabelInquiry.do?CAMEFROM=OK&origTrackNum=%s',$tracking);
		$text = 'visit USPS.com';
		}
	elsif ($CARRIER eq 'FDX') {
		## updated 08/04/2005, added &tracknumbers=
		#$c .= "<td bgcolor='FFFFFF'><a target=\"track\" href=\"http://www.fedex.com/cgi-bin/tracking?last_action=track&ascend_header=1&action=track&language=english&mps=y&ssc=n&ssd=&dsc=n&dsd=&msc=n&msd=&track_type=&cntry_code=us&generic_tracknumber_list=$value%2C&tracknumber_list=&track_number_0=$value&tracknumbers=$value\">visit FedEx.com</a>";

		## updated 10/10/2006
		$link = sprintf('http://www.fedex.com/Tracking?ascend_header=1&clienttype=dotcom&cntry_code=us&language=english&tracknumbers=%s',$tracking);
		$text = 'visit FedEx.com';
		## updated 3/1/02
		##http://www.fedex.com/us/tracking/?action=track&language=english&ascend_header=1&cntry_code=1&tracknumbers=$value
		}
	else {
		}

	return($link,$text);
	}


%ZSHIP::STATE_ABBREVIATIONS = (
	'AK'=>'Alaska',
	'AL'=>'Alabama',
	'AR'=>'Arkansas',
	'AZ'=>'Arizona',
	'CA'=>'California',
	'CO'=>'Colorado',
	'CT'=>'Connecticut',
	'DC'=>'District of Columbia',
	'DE'=>'Delaware',
	'FL'=>'Florida',
	'GA'=>'Georgia',
	'HI'=>'Hawaii',
	'IA'=>'Iowa',
	'ID'=>'Idaho',
	'IL'=>'Illinois',
	'IN'=>'Indiana',
	'KS'=>'Kansas',
	'KY'=>'Kentucky',
	'LA'=>'Louisiana',
	'ME'=>'Maine',
	'MD'=>'Maryland',
	'MA'=>'Massachusetts',
	'MI'=>'Michigan',
	'MN'=>'Minnesota',
	'MO'=>'Missouri',
	'MS'=>'Mississippi',
	'MT'=>'Montana',
	'NC'=>'North Carolina',
	'ND'=>'North Dakota',
	'NE'=>'Nebraska',
	'NH'=>'New Hampshire',
	'NJ'=>'New Jersey',
	'NM'=>'New Mexico',
	'NV'=>'Nevada',
	'NY'=>'New York',
	'OH'=>'Ohio',
	'OK'=>'Oklahoma',
	'OR'=>'Oregon',
	'PA'=>'Pennsylvania',
	'RI'=>'Rhode Island',
	'SC'=>'South Carolina',
	'SD'=>'South Dakota',
	'TN'=>'Tennessee',
	'TX'=>'Texas',
	'UT'=>'Utah',
	'VA'=>'Virginia',
	'VT'=>'Vermont',
	'WA'=>'Washington',
	'WI'=>'Wisconsin',
	'WV'=>'West Virginia',
	'WY'=>'Wyoming'
);


## Run string through uc then s/[^A-Z]//gs before comparing to the keys of this hash
%ZSHIP::STATE_NAMES = (
	'ALABAMA'                     => 'AL',
	'ALAB'                        => 'AL',
	'ALB'                         => 'AL',
	'ALBMA'                       => 'AL',
	'ALASKA'                      => 'AK',
	'ALASK'                       => 'AK',
	'ALSK'                        => 'AK',
	'ALK'                         => 'AK',
	'ARIZONA'                     => 'AZ',
	'ARIZ'                        => 'AZ',
	'ARI'                         => 'AZ',
	'ARKANSAS'                    => 'AR',
	'ARKS'                        => 'AR',
	'ARK'                         => 'AR',
	'CALIFORNIA'                  => 'CA',
	'CALIF'                       => 'CA',
	'CALI'                        => 'CA',
	'CAL'                         => 'CA',
	'COLORADO'                    => 'CO',
	'COL'                         => 'CO',
	'CONNECTICUT'                 => 'CT',
	'CONNETICUT'                  => 'CT',
	'CONN'                        => 'CT',
	'CON'                         => 'CT',
	'DELAWARE'                    => 'DE',
	'DELAWR'                      => 'DE',
	'DEL'                         => 'DE',
	'FLORIDA'                     => 'FL',
	'FLOR'                        => 'FL',
	'FLRDA'                       => 'FL',
	'FLO'                         => 'FL',
	'FLR'                         => 'FL',
	'GEORGIA'                     => 'GA',
	'GRGA'                        => 'GA',
	'GRG'                         => 'GA',
	'GGA'                         => 'GA',
	'HAWAII'                      => 'HI',
	'HAW'                         => 'HI',
	'HWI'                         => 'HI',
	'IDAHO'                       => 'ID',
	'IDAH'                        => 'ID',
	'IDH'                         => 'ID',
	'ILLINOIS'                    => 'IL',
	'ILLIN'                       => 'IL',
	'ILL'                         => 'IL',
	'INDIANA'                     => 'IN',
	'INDNA'                       => 'IN',
	'IND'                         => 'IN',
	'IOWA'                        => 'IA',
	'KANSAS'                      => 'KS',
	'KANS'                        => 'KS',
	'KAN'                         => 'KS',
	'KENTUCKY'                    => 'KY',
	'KENT'                        => 'KY',
	'KTY'                         => 'KY',
	'LOUISIANA'                   => 'LA',
	'LOUIS'                       => 'LA',
	'LSNA'                        => 'LA',
	'MAINE'                       => 'ME',
	'MNE'                         => 'ME',
	'MARYLAND'                    => 'MD',
	'MRYLND'                      => 'MD',
	'MRY'                         => 'MD',
	'MASSACHUSETTS'               => 'MA',
	'MASSECHUSETTS'               => 'MA',
	'MASS'                        => 'MA',
	'MICHIGAN'                    => 'MI',
	'MICHGN'                      => 'MI',
	'MICH'                        => 'MI',
	'MINNESOTA'                   => 'MN',
	'MINNES'                      => 'MN',
	'MINN'                        => 'MN',
	'MISSISSIPPI'                 => 'MS',
	'MIPPIPPIPPI'                 => 'MS',
	'MISSPI'                      => 'MS',
	'MISS'                        => 'MS',
	'MIS'                         => 'MS',
	'MISSOURI'                    => 'MO',
	'MSRI'                        => 'MO',
	'MONTANA'                     => 'MT',
	'MONT'                        => 'MT',
	'NEBRASKA'                    => 'NE',
	'NBRSKA'                      => 'NE',
	'NEBR'                        => 'NE',
	'NEB'                         => 'NE',
	'NBR'                         => 'NE',
	'NEVADA'                      => 'NV',
	'NEVDA'                       => 'NV',
	'NEV'                         => 'NV',
	'NEWHAMPSHIRE'                => 'NH',
	'NWHMPSHR'                    => 'NH',
	'NEWHAMP'                     => 'NH',
	'NHAMP'                       => 'NH',
	'NEWJERSEY'                   => 'NJ',
	'NEWJERS'                     => 'NJ',
	'NEWJRSY'                     => 'NJ',
	'NWJERSEY'                    => 'NJ',
	'NWJERS'                      => 'NJ',
	'NWJRSY'                      => 'NJ',
	'NJERSEY'                     => 'NJ',
	'NJERS'                       => 'NJ',
	'NJRSY'                       => 'NJ',
	'NEWMEXICO'                   => 'NM',
	'NWMEXICO'                    => 'NM',
	'NMEXICO'                     => 'NM',
	'NEWMEX'                      => 'NM',
	'NWMEX'                       => 'NM',
	'NMEX'                        => 'NM',
	'NEWYORK'                     => 'NY',
	'NYORK'                       => 'NY',
	'NWYRK'                       => 'NY',
	'NYRK'                        => 'NY',
	'NORTHCAROLINA'               => 'NC',
	'NORCAROLINA'                 => 'NC',
	'NOCAROLINA'                  => 'NC',
	'NCAROLINA'                   => 'NC',
	'NORTHCAR'                    => 'NC',
	'NORCAR'                      => 'NC',
	'NCAR'                        => 'NC',
	'NORTHDAKOTA'                 => 'ND',
	'NORDAKOTA'                   => 'ND',
	'NODAKOTA'                    => 'ND',
	'NDAKOTA'                     => 'ND',
	'NORTHDAK'                    => 'ND',
	'NORDAK'                      => 'ND',
	'NODAK'                       => 'ND',
	'NDAK'                        => 'ND',
	'OHIO'                        => 'OH',
	'OKLAHOMA'                    => 'OK',
	'OKLAH'                       => 'OK',
	'OKLA'                        => 'OK',
	'OKL'                         => 'OK',
	'OREGON'                      => 'OR',
	'OREGN'                       => 'OR',
	'ORGN'                        => 'OR',
	'OREG'                        => 'OR',
	'ORG'                         => 'OR',
	'PENNSYLVANIA'                => 'PA',
	'PENNS'                       => 'PA',
	'PENN'                        => 'PA',
	'RHODEISLAND'                 => 'RI',
	'RHISLAND'                    => 'RI',
	'RHISL'                       => 'RI',
	'RHIS'                        => 'RI',
	'RISLAND'                     => 'RI',
	'RISL'                        => 'RI',
	'RIS'                         => 'RI',
	'SOUTHCAROLINA'               => 'SC',
	'SOCAROLINA'                  => 'SC',
	'SCAROLINA'                   => 'SC',
	'SOUTHCAR'                    => 'SC',
	'SOCAR'                       => 'SC',
	'SCAR'                        => 'SC',
	'SOUTHDAKOTA'                 => 'SD',
	'SDAKOTA'                     => 'SD',
	'SOUTHDAK'                    => 'SD',
	'SDAK'                        => 'SD',
	'TENNESSEE'                   => 'TN',
	'TENNES'                      => 'TN',
	'TENN'                        => 'TN',
	'TEN'                         => 'TN',
	'TEXAS'                       => 'TX',
	'TEX'                         => 'TX',
	'TXS'                         => 'TX',
	'UTAH'                        => 'UT',
	'UTH'                         => 'UT',
	'VERMONT'                     => 'VT',
	'VERMNT'                      => 'VT',
	'VRMNT'                       => 'VT',
	'VERM'                        => 'VT',
	'VER'                         => 'VT',
	'VIRGINIA'                    => 'VA',
	'VIRG'                        => 'VA',
	'VIR'                         => 'VA',
	'WASHINGTON'                  => 'WA',
	'WASH'                        => 'WA',
	'WESTVIRGINIA'                => 'WV',
	'WESTVIRG'                    => 'WV',
	'WESTVIR'                     => 'WV',
	'WVIRGINIA'                   => 'WV',
	'WVIRG'                       => 'WV',
	'WVIR'                        => 'WV',
	'WISCONSIN'                   => 'WI',
	'WISC'                        => 'WI',
	'WIS'                         => 'WI',
	'WYOMING'                     => 'WY',
	'WYOM'                        => 'WY',
	'WYO'                         => 'WY',
	'DISTRICTOFCOLUMBIA'          => 'DC',
	'DISTCOLUMB'                  => 'DC',
	'DISTCOL'                     => 'DC',
	'DCOL'                        => 'DC',
	'ARMEDFORCESAMERICAS'         => 'AA',
	'AFAMERICAS'                  => 'AA',
	'ARMEDFORCESAFRICA'           => 'AE',
	'AFAFRICA'                    => 'AE',
	'ARMEDFORCESCANADA'           => 'AE',
	'AFCANADA'                    => 'AE',
	'ARMEDFORCESEUROPE'           => 'AE',
	'AFEUROPE'                    => 'AE',
	'ARMEDFORCESMIDDLEEAST'       => 'AE',
	'ARMEDFORCESME'               => 'AE',
	'AFMIDDLEEAST'                => 'AE',
	'AFME'                        => 'AE',
	'ARMEDFORCESPACIFIC'          => 'AP',
	'ARMEDFORCESPAC'              => 'AP',
	'AFPACIFIC'                   => 'AP',
	'AFPAC'                       => 'AP',
	'AMERICANSAMOA'               => 'AS',
	'SAMOA'                       => 'AS',
	'FEDERATEDSTATESOFMICRONESIA' => 'FM',
	'FEDERATEDSTATESMICRONESIA'   => 'FM',
	'MICRONESIA'                  => 'FM',
	'FSOM'                        => 'FM',
	'FSM'                         => 'FM',
	'GUAM'                        => 'GU',
	'GWAM'                        => 'GU',
	'MARSHALLISLANDS'             => 'MH',
	'MARSHALLISLANDS'             => 'MH',
	'MARSHALLISLS'                => 'MH',
	'MARSHALLISL'                 => 'MH',
	'MARSHALLIS'                  => 'MH',
	'MARSHISLANDS'                => 'MH',
	'MARSHISLS'                   => 'MH',
	'MARSHISL'                    => 'MH',
	'MARSHIS'                     => 'MH',
	'NORTHERNMARSHALLISLANDS'     => 'MP',
	'NORTHERNMARSHALLISLANDS'     => 'MP',
	'NORTHERNMARSHALLISLS'        => 'MP',
	'NORTHERNMARSHALLISL'         => 'MP',
	'NORTHERNMARSHALLIS'          => 'MP',
	'NORTHERNMARSHISLANDS'        => 'MP',
	'NORTHERNMARSHISLS'           => 'MP',
	'NORTHERNMARSHISL'            => 'MP',
	'NORTHERNMARSHIS'             => 'MP',
	'NORMARSHALLISLANDS'          => 'MP',
	'NORMARSHALLISLANDS'          => 'MP',
	'NORMARSHALLISLS'             => 'MP',
	'NORMARSHALLISL'              => 'MP',
	'NORMARSHALLIS'               => 'MP',
	'NORMARSHISLANDS'             => 'MP',
	'NORMARSHISLS'                => 'MP',
	'NORMARSHISL'                 => 'MP',
	'NORMARSHIS'                  => 'MP',
	'NOMARSHALLISLANDS'           => 'MP',
	'NOMARSHALLISLANDS'           => 'MP',
	'NOMARSHALLISLS'              => 'MP',
	'NOMARSHALLISL'               => 'MP',
	'NOMARSHALLIS'                => 'MP',
	'NOMARSHISLANDS'              => 'MP',
	'NOMARSHISLS'                 => 'MP',
	'NOMARSHISL'                  => 'MP',
	'NOMARSHIS'                   => 'MP',
	'NMARSHALLISLANDS'            => 'MP',
	'NMARSHALLISLANDS'            => 'MP',
	'NMARSHALLISLS'               => 'MP',
	'NMARSHALLISL'                => 'MP',
	'NMARSHALLIS'                 => 'MP',
	'NMARSHISLANDS'               => 'MP',
	'NMARSHISLS'                  => 'MP',
	'NMARSHISL'                   => 'MP',
	'NMARSHIS'                    => 'MP',
	'PALAU'                       => 'PW',
	'PUERTORICO'                  => 'PR',
	'PERTORICO'                   => 'PR',
	'PTORICO'                     => 'PR',
	'PRICO'                       => 'PR',
	'VIRGINISLANDS'               => 'VI',
	'VIRGINISLS'                  => 'VI',
	'VIRGINISL'                   => 'VI',
	'VIRGINIS'                    => 'VI',
	'VIRGISLANDS'                 => 'VI',
	'VIRGISLS'                    => 'VI',
	'VIRGISL'                     => 'VI',
	'VIRGIS'                      => 'VI',
	'VIRISLANDS'                  => 'VI',
	'VIRISLS'                     => 'VI',
	'VIRISL'                      => 'VI',
	'VIRIS'                       => 'VI',
);
@ZSHIP::STATE_CODES = qw(
	AK AL AR AZ CA CO CT DE FL GA HI IA ID IL IN KS KY
	LA MA MD ME MI MN MO MS MT NC ND NE NH NJ NM NV NY
	OH OK OR PA RI SC SD TN TX UT VA VT WA WI WV WY
	DC AA AE AP AS FM GU MH MP PR PW VI
);

##
## NOTE: FedEx has different codes (Yipes!)
##		YT = Yukown (Zoovy is YK)
##		PQ = Quebec (Zoovy is QC)
##		NF = Newfoundland (Zoovy is NL)
##
%ZSHIP::CANADA_PROVINCE_NAMES = (
	'ALBERTA'              => 'AB',
	'ALBRTA'               => 'AB',
	'ALB'                  => 'AB',
	'AL'                   => 'AB',
	'BRITISHCOLUMBIA'      => 'BC',
	'BRITISHCOLUMB'        => 'BC',
	'BRITISHCOL'           => 'BC',
	'BRITCOLUMBIA'         => 'BC',
	'BRITCOLUMB'           => 'BC',
	'BRITCOL'              => 'BC',
	'BCOLUMBIA'            => 'BC',
	'BCOLUMB'              => 'BC',
	'BCOL'                 => 'BC',
	'MANITOBA'             => 'MB',
	'MANIT'                => 'MB',
	'MAN'                  => 'MB',
	'MNT'                  => 'MB',
	'MN'                   => 'MB',
	'NEWBRUNSWICK'         => 'NB',
	'NEWBRUNS'             => 'NB',
	'NEWB'                 => 'NB',
	'NWBRUNSWICK'          => 'NB',
	'NWBRUNS'              => 'NB',
	'NBRUNSWICK'           => 'NB',
	'NBRUNS'               => 'NB',
	'NWB'                  => 'NB',
	'NF'                   => 'NL',
	'NEWFOUNDLAND'         => 'NL',
	'NWFNDLND'             => 'NL',
	'NWFND'                => 'NL',
	'NORTHWESTTERRITORIES' => 'NT',
	'NWTERRITORIES'        => 'NT',
	'NWTERR'               => 'NT',
	'NWTER'                => 'NT',
	'NWT'                  => 'NT',
	'NOVASCOTIA'           => 'NS',
	'NOVASCOT'             => 'NS',
	'NOVSCOT'              => 'NS',
	'NOV'                  => 'NS',
	'NV'                   => 'NS',
	'NO'                   => 'NS',
	'NUNAVUT'              => 'NU',
	'NUNA'                 => 'NU',
	'NUN'                  => 'NU',
	'ONTARIO'              => 'ON',
	'ONT'                  => 'ON',
	'PRINCEEDWARDISLAND'   => 'PE',
	'PRINCEEDWARDISL'      => 'PE',
	'PRINCEEDWARDIS'       => 'PE',
	'PRINCEEDISLAND'       => 'PE',
	'PRINCEEDISL'          => 'PE',
	'PRINCEEDIS'           => 'PE',
	'PREDWARDISLAND'       => 'PE',
	'PREDWARDISL'          => 'PE',
	'PREDWARDIS'           => 'PE',
	'PREDISLAND'           => 'PE',
	'PREDISL'              => 'PE',
	'PREDIS'               => 'PE',
	'PREISL'               => 'PE',
	'PREIS'                => 'PE',
	'PREI'                 => 'PE',
	'PEISL'                => 'PE',
	'PEIS'                 => 'PE',
	'PEI'                  => 'PE',
	'PR'                   => 'PE',
	'QUEBEC'               => 'QC',
	'QUEB'                 => 'QC',
	'QU'                   => 'QC',
	'SASKATCHEWAN'         => 'SK',
	'SSKTCHWN'             => 'SK',
	'SKTCHWN'              => 'SK',
	'SKWN'                 => 'SK',
	'SKN'                  => 'SK',
	'SKW'                  => 'SK',
	'YUKON'                => 'YK',
	'YUK'                  => 'YK',
	'YU'                   => 'YK',
);
@ZSHIP::CANADA_PROVINCE_CODES = qw(
	AB BC MB NB NL NT NS NU ON PE QC SK YT
);

## Run string through uc then s/[^A-Z]//gs before comparing to the keys of this hash
## New Zealand must be in this list or it will be interpreted to "Cook Islands" in checkout - god only knows how many others there are like this!
%ZSHIP::COUNTRY_CORRECTIONS = (
	'UNITEDSTATES'             => '',
	'THEUNITEDSTATES'          => '',
	'UNITEDSTATESOFAMERICA'    => '',
	'THEUNITEDSTATESOFAMERICA' => '',
	'AMERICA'                  => '',
	'US'                       => '',
	'USA'                      => '',
	'USOFA'                    => '',
	'UNITEDKINGDOM'            => 'United Kingdom',
	'GREATBRITAIN'             => 'United Kingdom',
	'BRITAIN'                  => 'United Kingdom',
	'UK'                       => 'United Kingdom',
	'GB'                       => 'United Kingdom',
	'CAN'                      => 'Canada',
	'NEWZEALAND'               => 'New Zealand',
);


sub smart_weight {
	return(smart_weight_new(@_));
	}

##
## 5/4/04 - added support for $mods - modifiers to pass through function unscathed. -BH
##		$options  is a bitwise, 1 means allow ='s to pass through (used to compute weight)
##
sub smart_weight_new {
	my ($weight,$options) = @_;

	if (not defined $options) { $options = 0; }
	$weight = def($weight); ## Make sure its defined
	$weight =~ s/\s+//gs; ## Strip spaces

	my $mods = '';
	if (($options & 1)==1) {
		if (substr($weight,0,1) eq '+') { $mods .= '+'; $weight = substr($weight,1); }	# strip +'s (don't need 'em)
		elsif (substr($weight,0,1) eq '-') { $mods .= '-'; $weight = substr($weight,1); }
		elsif (substr($weight,0,1) eq '=') { $mods .= '='; $weight = substr($weight,1); }
		if (index($weight,'%')>=0) { $mods .= '%'; $weight =~ s/\%//gs; }
		}

	if ($weight eq '') { $weight = '0'; }
	my $oz = 0;
	my $lbs = 0;
	if ($weight =~ m/^(\d+\.?|\d*\.\d+)$/) { $oz = $1; }
	elsif ($weight =~ m/^(\d+\.?|\d*\.\d+)?\#(\d+\.?|\d*\.\d+)?$/) { $lbs = def($1,0); $oz = def($2,0); }
	else { return undef; }
	return ($mods . ($oz + ($lbs * 16)));
}





## Checks the contents of the shipping meta hash to see if we're supposed to handle
## any more shipping types (if a shipping type doesn't want to play with others, it will
## set force_single to 1
sub good_to_go {
	my ($metaref) = @_;
	if ((defined $metaref->{'force_single'}) && $metaref->{'force_single'}) {
		return 0;
		}
	return 1;
	}

## There's a lot of places where we need a 0 if not defined, and an int if
## so, namely checking the flags that say which shipping types are available...
## this is just is just a shortcut function to save some space
sub num { 
	my ($x) = @_; 
	if (not defined $x) { $x = 0; }
	elsif ($x eq 'on') { $x = 1; } 
	return (defined $x) ? (($x ne '')?int($x):0) : 0; }

# We have webdb fields where people can enter dollar values...  this can normalize this data
sub bucks
{
	my ($bucks) = @_;
	if ((not defined $bucks) || ($bucks eq '')) { return 0; }
	$bucks =~ s/[^0-9\.\-]//gis;
	$bucks = sprintf("%.2f",$bucks) + 0;
	return $bucks;
}

## strips spaces
sub stripSP {
	my ($str) = @_;
	$str =~ s/^[\s]*(.*?)[\s]*$/$1/s;
	return($str);
	}

	
sub is_usps_only {
	my ($addr,$state) = @_;

	$addr = def($addr);
	$state = def($state);
	if ($addr eq '' || $state eq '') { return(0); }
	$addr = " $addr "; ## Make it so the regex below matches a space at the front or end
	return 1 if ($addr =~ m/\s*P\.{1}\s*O\.{1}(\s*BOX){1}\s+/i);
	return 1 if ($state eq 'AA' || $state eq 'AE' || $state eq 'AP');
	return 0;
}

######################################################################
######################################################################
## DOMESTIC MARSHALLING
######################################################################
######################################################################



################################################### END OF COMPATIBILITY CODE ##########################################

##
## outputs the shipping in a cart 
##		version is which output format we want
##			1 = <METHOD ID="name" VALUE="1.00">name</METHOD>
##
##	returns: $XML
##
sub xml_out {
	my ($CART2, $VERSION) = @_;

	my $XML = '';
	if (($VERSION == 1) || ($VERSION == 2)) {
		require ZWEBAPI;
				
#		use Data::Dumper;
#		print STDERR Dumper($CART);


		my $shipmethods = $CART2->shipmethods();
		foreach my $shipmethod (@{$shipmethods}) {
			next if ($shipmethod eq '');
			$XML .= "<METHOD TAXABLE=\"".($CART2->in_get('sum/shp_taxable'))."\"";
			$XML .= ' ID="'.&ZWEBAPI::xml_incode($shipmethod->{'id'}).'" ';
			$XML .= ' NAME="'.&ZWEBAPI::xml_incode($shipmethod->{'name'}).'" ';
			$XML .= ' CARRIER="'.&ZWEBAPI::xml_incode($shipmethod->{'carrier'}).'" ';
			$XML .= 'VALUE="'.&ZWEBAPI::xml_incode($shipmethod->{'amount'}).'">';
			$XML .= &ZWEBAPI::xml_incode($shipmethod->{'name'});
			$XML .= " (\$".&ZWEBAPI::xml_incode($shipmethod->{'amount'}).")</METHOD>\n";
			}

		if ($VERSION == 2) {
			if ($CART2->in_get('sum/hnd_total')) {
				$XML .= "<HND TAXABLE=\"".$CART2->in_get('sum/hnd_taxable')."\" VALUE=\"".($CART2->in_get('sum/hnd_total'))."\">";;
				$XML .= &ZWEBAPI::xml_incode($CART2->in_get('sum/hnd_method'));
				$XML .= "</HND>";
				}

			if ($CART2->in_get('sum/ins_total')) {
				$XML .= "<INS PURCHASED=\"".($CART2->in_get('sum/ins_purchased'))."\" TAXABLE=\"".$CART2->in_get('sum/ins_taxable')."\" VALUE=\"".($CART2->in_get('sum/ins_total'))."\">";;
				$XML .= &ZWEBAPI::xml_incode($CART2->in_get('sum/ins_method'));
				$XML .= "</INS>";
				}

			if ($CART2->in_get('sum/spc_total')) {
				$XML .= "<SPC TAXABLE=\"".$CART2->in_get('sum/spc_taxable')."\" VALUE=\"".($CART2->in_get('sum/spc_total'))."\">";;
				$XML .= &ZWEBAPI::xml_incode($CART2->in_get('sum/spc_method'));
				$XML .= "</SPC>";
				}
			}
		}
#	print STDERR "VERSION=[$VERSION] XML: $XML\n";
	
	return($XML);		
	}





######################################################################
######################################################################
## DOMESTIC UTILITIES (TAXES, ZIPCODES, ETC)
######################################################################
######################################################################


##
## returns tax info
##
## accepts:
##		webdb => reference to a webdb
##		debug => 1|0
##
##		city=>
##		state=>
##		zip=>
##		country=>	
##		address1=>
##	
##		subtotal=>
##		shp_total=>
##		hnd_total=>
##		ins_total=>
##		spc_total=>
##
## returns:
##		tax_rate, tax_total
##		state_rate, state_total
##		local_rate, local_total
##		tax_applyto		(bitwise value 2=shipping)
##		
##
sub getTaxes {
	my ($USERNAME,$PRT,%options) = @_;

	my $webdbref = $options{'webdb'};
	if (not defined $webdbref) {
		($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
		}

	# use Data::Dumper; print STDERR Dumper($options{'subtotal'});


	my @dlog = ();
	my $DEBUG = int($options{'debug'});
	# $DEBUG++;
	my $csv = Text::CSV_XS->new();
	my %result = ();

	if (($DEBUG) && ($options{'subtotal'}==0)) {
		push @dlog,"*** WARNING: order subtotal is not set!";
		}

	## cleanup some data
	if (defined $options{'state'}) { 
		$options{'state'} = uc($options{'state'}); 
		push @dlog,"STATE is: $options{'state'}";
		}
	if (defined $options{'city'}) { 
		$options{'city'} = uc($options{'city'}); 
		push @dlog,"CITY is: $options{'city'}";
		}

	if (defined $options{'country'}) { 
		$options{'country'} = uc($options{'country'}); 
		push @dlog,"COUNTRY is: $options{'country'}";
		}
	else {
		$options{'country'} = '';
		push @dlog,"COUNTRY was *NOT* set -- defaulting to United States"; 
		}

	if ($options{'country'} eq '') { 
		$options{'country'} = 'US'; 
		}

	if ($options{'country'} eq 'CA') {
		## CANADIAN TAXES - attempt to validate or lookup province codes
		my $is_valid_province = 0;
		foreach my $code (@ZSHIP::CANADA_PROVINCE_CODES) {
			if ($code eq $options{'state'}) { $is_valid_province++; }
			}

		if ($is_valid_province) {
			push @dlog,"VALID CANADIAN PROVINCE: $options{'state'}";
			}
		elsif ($options{'state'} eq '') {
			push @dlog,"MISSING CANADIAN PROVINCE (STATE)";
			}
		else {
			my $province = uc($options{'state'});
			$province =~ s/[^A-Z]+//gs;	# remove any non A-Z
			if (defined $ZSHIP::CANADA_PROVINCE_NAMES{$province}) {
				$options{'state'} = $ZSHIP::CANADA_PROVINCE_NAMES{$province}; $is_valid_province++;
				}
			else {
				push @dlog, "INVALID CANADIAN PROVINCE: $options{'state'}";
				}
			}
		
		if (not $is_valid_province) {
			push @dlog, "CANADIAN STATE/PROVINCE TAXES WILL NOT BE COMPUTED PROPERLY.";
			}
		}

	if (defined $options{'address1'}) { 
		$options{'address1'} = uc($options{'address1'}); 
		push @dlog,"ADDRESS1 is: $options{'address1'}";
		}

	if ((defined $options{'zip'}) && ($options{'zip'} =~ /^(\d\d\d\d\d)[\+\-](\d\d\d\d)$/)) {
		## detect and handle zip+4 scenarios
		($options{'zip'},$options{'zip4'}) = ($1,2);
		}

	if ((defined $options{'zip'}) && ($options{'state'} eq '')) {
		$options{'state'} = &ZSHIP::zip_state($options{'zip'});
		push @dlog, "*** WARNING: No State! used zip $options{'zip'} to get state $options{'state'}\n";
		}

	if ($DEBUG) { push @dlog,"ZIP is: $options{'zip'}"; }
	my $tax_rules_txt = $webdbref->{'tax_rules'};

	## NY: http://www8.nystax.gov/UTLR/utlrHome
	## OH: 
	if (1) {}
	elsif ($options{'state'} eq 'WA') {
		## washington state web-service
		##	 http://dor.wa.gov/Content/FindTaxesAndRates/RetailSalesTax/DestinationBased/ClientInterface.aspx
		##  note: on success we'll overwrite $tax_rules_txt
		push @dlog, "*** Found state of WA - using http://dor.wa.gov/AddressRates service.";
		my $ua = LWP::UserAgent->new;
		my $url = 'http://dor.wa.gov/AddressRates.aspx?'.
			&ZTOOLKIT::buildparams({ output=>'xml', servername=>"zoovy.com", addr=>$options{'address1'}, city=>$options{'city'}, zip=>$options{'zip'}});
		my ($response) = $ua->get($url);
		if ($response->is_success()) {
			# LocationCode=3406 Rate=0.084 ResultCode=0
			my $xml = $response->content();
			# <response loccode="3406" localrate="0.019" rate="0.084" code="0">
			if ($DEBUG) { push @dlog, "API Response: ".&ZOOVY::incode($xml); }

			## we need to clear out a superfelous rate="" for this to parse nicely.
			$xml =~ s/ rate="[\d\.]+"//g;
			if ($xml !~ /<response/) { $xml = "<err><![CDATA[$xml]]></err>"; }
			my $ref = XML::Simple::XMLin($xml,ForceArray=>0,KeyAttr=>['rate']);
			# $ref = { 'rate' => {  'localrate' => '0.019', 'staterate' => '0.065','name' => 'TUMWATER', 'code' => '3406' } }
			#use Data::Dumper; print Dumper($ref,$xml);
			if ((not defined $ref) || (ref($ref) eq '')) {
				push @dlog, "API got malformed resonse";
				}
			elsif ($ref->{'loccode'} ne '') {
				$ref = $ref->{'rate'};
				$result{'tax_zone'} = 'API.WA;'.$ref->{'name'}.';'.$ref->{'code'};
				$result{'tax_zone'} =~ s/[\s]+/_/g;
				$result{'local_rate'} = sprintf("%.4f",$ref->{'localrate'}*100);
				$result{'state_rate'} = sprintf("%.4f",$ref->{'staterate'}*100);
				$tax_rules_txt = '';  ## ignore other rules.
				push @dlog, "Got API response local=$result{'local_rate'} state=$result{'state_rate'}; ignoring other rules";
				}
			else {
				push @dlog, "API call failed due to lack of loccode attribute in response";
				}
			}
		else {
			push @dlog, "API Error: ".$response->status_line;
			}
		}

	push @dlog, "";
	my $count = 0;
	my ($yyyymmdd) = POSIX::strftime("%Y%m%d",localtime());
	foreach my $line (split(/[\n\r]+/,$tax_rules_txt)) {
		$count++;
		next if (($line eq '') || (substr($line,0,1) eq '#'));
		if ($DEBUG) { push @dlog,"RULE[$count]: ".$line.""; }
		my $status  = $csv->parse($line);       # parse a CSV string into fields
		my ($method,$match,$rate,$apply,$zone,$expires) = $csv->fields();           # get the parsed fields

		my ($is_match) = (undef);

		
		## skip the rule if we're going to expire
		if (($expires ne '') && ($expires =~ /^[\d]{8,8}$/) && ($yyyymmdd >= $expires)) {
			push @dlog, "skipping rule because it expired on $yyyymmdd";
			}
		elsif (($method eq 'state') && ($options{'country'} eq 'US')) {
			## NOTE: this is a domestic, US state.
			if ($options{'state'} eq $match) { $is_match = 'state'; }
			}
		elsif ($method eq 'city') {
			my ($state,$city) = split(/[ \+\-\.\,]+/,$match,2);
			$city = uc($city);

			if ($options{'state'} ne $state) {
				# if ($DEBUG) { push @dlog, "=======> \"$options{'state'}\" ne \"$state\""; }
				}
			elsif (index($city,'*')>=0) {
				## contains regex
				$city =~ s/\*/.*/;
				$city = '^'.$city.'$';
				if ($options{'city'} =~ /$city/) { 
					$is_match = 'local'; $result{'tax_zone'} = $zone; 
					}
				}
			else {
				## no regex
				# if ($DEBUG) { push @dlog, "========> \"$options{'city'}\" eq \"$city\""; }
				if ($options{'city'} eq $city) { 
					$is_match = 'local'; $result{'tax_zone'} = $zone; 
					}
				}
			}
		elsif (($method eq 'zipspan') && ($options{'country'} eq 'US')) {
			my ($start,$end) = split(/\-/,$match,2);
			if ($end eq '') { $end = $start; }
			if ($start>$end) { my $a = $start; $start = $end; $end = $start; }
			if ($end eq '') { $end = $start; }
			# push @dlog, "start=$start end=$end\n";

			if ($options{'zip'} < $start) {}
			elsif ($options{'zip'} > $end) {}
			else { 
				$is_match = 'local'; $result{'tax_zone'} = $zone; 
				}									
			}
		elsif (($method eq 'zip4') && ($options{'country'} eq 'US')) {
			if (($options{'zip'}.'-'.$options{'zip4'}) eq $match) { 
				$is_match = 'local'; $result{'tax_zone'} = $zone; 
				}
			}
		elsif ($method eq 'country') {
			if ($options{'country'} eq $match) { 
				$is_match = 'state'; $result{'tax_zone'} = $zone; 
				}
			}
		elsif ($method eq 'intprovince') {
			my ($country,$province) = split(/\+/,$match,2);
			$province =~ s/\*/.*/;
			$province = uc('^'.$province.'$');

			# push @dlog, "state[$options{'state'}] =~ province[$province]";
			if ($options{'country'} ne $country) {}
			elsif ($options{'state'} =~ /$province/) {
				$is_match = 'local'; $result{'tax_zone'} = $zone; 
				}
			}
		elsif ($method eq 'intzip') {
			my ($country,$zip) = split(/\+/,$match,2);
			$zip =~ s/\*/.*/;
			$zip = uc('^'.$zip.'$');
			
			# push @dlog, "state[$options{'state'}] =~ province[$zip]";
			if ($options{'country'} ne $country) {}
			elsif ($options{'zip'} =~ /$zip/) {
				$is_match = 'local'; $result{'tax_zone'} = $zone; 
				}
			}

		## okay so we did we get a rate back
		if ((defined $is_match) && ($is_match ne '')) {
			if ($DEBUG) { push @dlog,"==> MATCH[$count] TAX_TYPE=$is_match"; }

			## state_rate || local_rate
			$result{$is_match."_rate"} = $rate;

			my $total = undef;
			if (not defined $options{'subtotal'}) {
				## no subtotal, so we're just going to return a rate!
				push @dlog,"==> SET $is_match\_rate=$rate";
				if (($apply & 1)==1) {
					## make sure we preserve the applies to value
					$result{'tax_applyto'} = $apply;
					}
				}
			elsif (($apply & 1)==0) {
				push @dlog,"==> SKIP apply ship/hand/ins/spec modifiers (because val is zero)"; 
				$result{"tax_subtotal"} = sprintf("%.2f",$options{'subtotal'});
				$result{$is_match."_total"} = sprintf("%.2f",($rate/100)*$options{'subtotal'});
				}
			else {
				$total = $options{'subtotal'};
				$result{'tax_applyto'} = $apply;

				## SHIPPING
				if (($apply & 2)==2) { 
					$total += $options{'shp_total'}; 
					push @dlog,"==> SHIPPING is taxable"; 
					}
				else {
					push @dlog,"==> SHIPPING is *NOT* taxable";
					}
				## HANDLING
				if (($apply & 4)==4) { 
					$total += $options{'hnd_total'}; 
					push @dlog,"==> HANDLING is taxable";
					}
				else {
					push @dlog,"==> HANDLING is *NOT* taxable";
					}
				## INSURANCE
				if (($apply & 8)==8) { 
					$total += $options{'ins_total'}; 
					push @dlog,"==> INSURANCE is taxable";
					}
				else {
					push @dlog,"==> INSURANCE is *NOT* taxable";
					}
				## SPECIAL
				if (($apply & 16)==16) { 
					$total += $options{'spc_total'}; 
					push @dlog,"==> SPECIALTY is taxable";
					}
				else {
					push @dlog,"==> SPECIALTY is *NOT* taxable";
					}

				$result{"tax_subtotal"} = $total;
				$result{$is_match."_total"} = sprintf("%.2f",($rate/100)*$total);
				push @dlog,"==> SET $is_match\_rate=$rate $is_match\_subtotal=\$$total $is_match\_total=\$".$result{$is_match."_total"};
				}
	
			}

		}
	push @dlog, "END - finished all rules\n";

	## compute the overall tax_rate
	$result{'tax_rate'} = sprintf("%.3f", $result{'state_rate'} + $result{'local_rate'});
	if (defined $options{'subtotal'}) {
		$result{'tax_total'} = sprintf("%.2f", ($result{'tax_rate'}/100) * $result{'tax_subtotal'});
		}

	if ($DEBUG) { 
		## eventually we might want to do more color coding here.
		$result{'debug'} = join("\n",@dlog); 
		print STDERR "DEBUG: $result{'debug'}\n";
		}


	return(%result);
	}



########################################
## parameters: an origin zip and a set of zip ranges eg: 00000-11111,00001-999999 
## returns: 1 if the zip appears in the ranges, 0 if not.
## note: don't use this with zip spans for sales tax since they use a different format completely
sub is_in_zip_range {
	my ($dest, $zipranges) = @_;
	$dest = num($dest);
	$zipranges = def($zipranges);
	foreach my $rate (split (',', $zipranges)) {
		my ($start, $end) = split ('-', $rate);
		$start = num($start);
		$end   = num($end);
		if (($dest >= $start) && ($dest <= $end)) { return 1; }
		}
	return 0;
	}


sub fetch_us_state_codes
{
	return @ZSHIP::STATE_CODES;
}

sub fetch_us_state_names
{
	return %ZSHIP::STATE_NAMES;
}

## zip_to_state
## Send zip_state ZIP or a ZIP+4 and it sends back the proper 2-letter USPS
## state code for that ZIP.
## The ZIP *must* be contain 5 or 9 digits (zip+4) or it will be kicked back
## to the user as blank. Any non-numeric character(s) will be ignored.
## To refresh the .db files to match what is currenlty valid with USPS, run
## /httpd/scripts/getzips.pl
## zip_state
sub zip_state {
	my ($zip) = @_;
	if (not defined $zip) { return ''; } ## Well, duh.
	$zip =~ s/\D//gs; ## Strip all non-digits
	## Make a plain zip out of a zip+4
	if ($zip =~ m/^(\d\d\d\d\d)\d\d\d\d$/) { $zip = "$1"; }
	## If it's not a 5-digit zip at this point, kick it back
	if ($zip !~ m/^\d\d\d\d\d$/) { return ''; } 
	my %zips = ();
	my $state = ''; ## Default to no state being sent back (zip not found)
	## File name for zips < 10000 is ZIP0.db
	## zips >= 10000 and < 20000 is ZIP10000.db
	## zips >= 20000 and < 30000 is ZIP20000.db ... etc.
#	my $file = '/httpd/static/ZIPS'.(int($zip/10000)*10000).'.db';
#	if (tie (%zips, 'DB_File', $file, O_NONBLOCK|O_RDONLY)) {
#		if (defined $zips{$zip}) { $state = $zips{$zip}; }
#		untie %zips;
#		}
	if (tie %zips, 'CDB_File', '/httpd/static/zips.cdb') {
		if (defined $zips{$zip}) { $state = $zips{$zip}; } else { warn "zip:$zip is not valid\n"; }
		untie %zips;
		}
	
	unless (&ZTOOLKIT::isin(\@ZSHIP::STATE_CODES,$state)) { $state = ''; } 

	# print "STATE: $state\n";

	return $state;
	}




######################################################################
######################################################################
## INTERNATIONAL UTILITIES (DETERMINE RISK, FIND ALLOWED DESTINATIONS)
######################################################################
######################################################################

########################################
## Takes a country name and returns 1 if the country is low-risk, 0 if not
sub is_low_risk {
	my ($ZCOUNTRY) = @_;

	#my $line = '';
	#$country = def($country);
	#if ($country eq '') { return 1; }
	#my $lowrisk = 0;
	#open(FILE, $ZSHIP::INT_LOWRISK_FILE);
	#foreach $line (<FILE>) {
	#	if (($line =~ m/^"$country".*$/i) || ($line =~ m/^$country.*$/)) {
	#		$lowrisk = 1;
	#		}
	#	}
	my $lowrisk = 0;
	my ($info) = &ZSHIP::resolve_country(ZOOVY=>$ZCOUNTRY);
	if (defined $info) { $lowrisk = $info->{'SAFE'}; }

	return $lowrisk;
	}

########################################
## Fetches the country names/codes as used by FEDEX UPS and USPS
sub fetch_country_shipcodes {
	my ($ZCOUNTRY) = @_;
	my ($FEDEX, $UPS, $USPS) = ();

   $ZCOUNTRY =~ s/[\s\n\r]+//gs;

	my ($info) = &ZSHIP::resolve_country(ZOOVY=>$ZCOUNTRY);
	if (defined $info) {
		($FEDEX,$UPS,$USPS) = ($info->{'FDX'},$info->{'UPS'},$info->{'PS'});
		}

	return (($FEDEX, $UPS, $USPS));
}


##
## this returns a country reference, or undef on failure.
##		you can pass the following:
##		ZOOVY=>"country name"
##		ISO=>"lookup"
##
sub resolve_country {
	my (%options) = @_;

	my $info = undef;
	if ((not defined $info) && ($options{'PAYPAL'})) {
		my $ref = retrieve "/httpd/static/country-paypallookup.bin";
		if (defined $ref) {
			$info = $ref->{uc($options{'PAYPAL'})};
			if (not defined $info) {
				## try stripping out spacing and whatnot and lookup again before failing!
				my $x = uc($options{'PAYPAL'});
				$x =~ s/[^A-Z]+//gs;
				$info = $ref->{$x};
				}
			}
		}

	## for some odd reason USA data isn't always defined in every file.
	my $USA = { Z=>'United States',ISO=>'US',FDX=>'US',PAYPAL=>'US',ISOX=>'US',UPS=>'US',PS=>'United States' };
	
	##
	## SANITY: put any gateway/country specific lookups above.
	##
	if (defined $options{'ZOOVY'}) {
		## united states isn't actually defined in our countries file since we don't want it appearing
		## accidentally.
		if (
			($options{'ZOOVY'} eq 'US') || 
			($options{'ZOOVY'} eq 'USA') || 
			($options{'ZOOVY'} eq 'United States') ||
			($options{'ZOOVY'} eq 'UnitedStates')
			) {
			## the most common lookup we end up doing!
			$info = $USA;
			}
		}
	elsif ((defined $options{'ISO'}) && ($options{'ISO'} eq 'US')) {
		$info = $USA;
		}
	elsif ((defined $options{'ISOX'}) && ($options{'ISOX'} eq 'US')) {
		$info = $USA;
		}

	if (defined $info) {
		## cool.. we got a hit already on a more specific type
		}
	elsif ($options{'ZOOVY'}) {

		if ($options{'ZOOVY'} eq 'USA') { $options{'ZOOVY'} = 'US'; }

		my $ref = retrieve "/httpd/static/country-zoovylookup.bin";
		if (defined $ref) {
			$info = $ref->{uc($options{'ZOOVY'})};
			if (not defined $info) {
				## try stripping out spacing and whatnot and lookup again before failing!
				my $x = uc($options{'ZOOVY'});
				$x =~ s/[^A-Z]+//gs;
				$info = $ref->{$x};
				}

			if (not defined $info) {
				warn "Missed on zoovy country lookup for ZCOUNTRY=[$options{'ZOOVY'}]";
				}
			}
		else {
			warn "Could not load /httpd/static/country-zoovylookup.bin";
			}
		}
	elsif ($options{'ISO'}) {
		my $ref = retrieve "/httpd/static/country-isolookup.bin";
		if (defined $ref) {
			$info = $ref->{uc($options{'ISO'})};
			if (not defined $info) {
				warn "Missed on iso lookup for ISO[$options{'ISO'}]";
				}
			}
		else {
			warn "Could not load /httpd/static/country-isolookup.bin";
			}
		}
	elsif ($options{'ISOX'}) {
		my $ref = retrieve "/httpd/static/country-isoxlookup.bin";
		if (defined $ref) {
			$info = $ref->{uc($options{'ISOX'})};
			if (not defined $info) {
				warn "Missed on iso lookup for ISOX[$options{'ISOX'}]";
				}
			}
		else {
			warn "Could not load /httpd/static/country-isoxlookup.bin";
			}
		}

	return($info);
	}



########################################
##
## given the country code from amazon, fetches the country names
##
sub fetch_country_shipname {
	my ($ISOCODE) = @_;
	my $COUNTRY = '';

	$ISOCODE = uc($ISOCODE);
	if ($ISOCODE eq 'US') { return("United States") }

	## we need a special line here since "Wales" can be either WL or GB (and most of the time GB should be United Kingdom)
	if ($ISOCODE eq 'GB') { return("United Kingdom"); }
	if ($ISOCODE eq 'UK') { return("United Kingdom"); }

	my ($info) = &ZSHIP::resolve_country(ISO=>$ISOCODE);
	if (defined $info) { 
		$COUNTRY = $info->{'Z'};
		}

	#open F, "<$ZSHIP::INT_HIGHRISK_FILE";
	#while (<F>) {
	#	if ($_ =~ /\"$ISOCODE\"/i) {
	#		($COUNTRY, undef, undef, undef) = split (/\"\:|\",/, $_);
	#		$COUNTRY =~ s/\"//g;
	#		}
	#	}
	#close F;
#
#	if ($COUNTRY eq '') {
#		open F, "<$ZSHIP::INT_LOWRISK_FILE";
#		while (<F>) {
#			if ($_ =~ /\"$ISOCODE\"/i) {
#				($COUNTRY, undef, undef, undef) = split (/\"\:|\",/, $_);
#				$COUNTRY =~ s/\"//g;
#				}
#			}
#		close F;
#		}
#
#	if ($COUNTRY eq '') {
#      open F, "<$ZSHIP::INT_CANADAONLY_FILE";
#      while (<F>) {
#         if ($_ =~ /\"$ISOCODE\"/i) {
#            ($COUNTRY, undef, undef, undef) = split (/\"\:|\",/, $_);
#            $COUNTRY =~ s/\"//g;
#            }
#         }
#      close F;
#      }

	## these countries could not be found
	if ($COUNTRY eq '') { 
		warn "Country not found for ISOCODE[$ISOCODE]\n";
		$COUNTRY = 'ZOOVYLAND'; 
		&ZOOVY::confess("brian","Country not found for ISOCODE[$ISOCODE]\n".join(";",caller(0)),justkidding=>1);
		}
	
	return (($COUNTRY));
	}

########################################
## What a bitch?? 
##		returns a hashref of countries and methods supported.
##
sub available_destinations {
	my ($CART2,$webdbref) = @_;

	if (defined $webdbref) {
		## screw it .. we don't really need to know who this is
		}
	#elsif (ref($CART2) ne 'CART') {
	#	warn "LEGACY SUPPORT FOR FETCH_INT_DESTINATIONS ENABLED!\n";
	#	my $USERNAME = $CART;
	#	$webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,0);  	# backup-non prt friendly
	#	}
	else {
		$webdbref = &ZWEBSITE::fetch_website_dbref($CART2->username(),$CART2->prt()); 
		}

	my @AVAILABLE_COUNTRIES = ();
	push @AVAILABLE_COUNTRIES, { 'Z'=>'United States', ISO=>'US', ISOX=>'USA' };

	$webdbref->{'ship_int_risk'} = uc($webdbref->{'ship_int_risk'});
	if ($webdbref->{'ship_int_risk'} eq 'NONE') { 
		return \@AVAILABLE_COUNTRIES;
		}

	# figure out which file (if any) has the right countries.
	my $FILE = '';
	if ($webdbref->{'ship_int_risk'} eq 'ALL51') { $FILE = '/httpd/static/country-canada.bin'; }
	elsif ($webdbref->{'ship_int_risk'} eq 'SOME')  { $FILE = '/httpd/static/country-lowrisk.bin'; }
	elsif ($webdbref->{'ship_int_risk'} eq 'FULL')  { $FILE = '/httpd/static/country-highrisk.bin'; }
	if ($FILE eq '') { 
		return(\@AVAILABLE_COUNTRIES);
		}

	my %blocks = ();
	foreach my $isox (split(/,/,$webdbref->{'ship_blacklist'})) {
		next if ($isox eq '');
		$blocks{$isox}++;
		}

	my $countries = retrieve $FILE;
	foreach my $cnt (@{$countries}) {
		my $COUNTRY = $cnt->{'Z'};
		my $ISOX = $cnt->{'ISOX'};
		next if ($cnt->{'ISO'} eq '');	## skip countries which don't have an ISO code as available destinations

		next if (defined $blocks{$ISOX});
		next if ($COUNTRY eq '');
		push @AVAILABLE_COUNTRIES, { 'Z'=>$COUNTRY, 'ISO'=>$cnt->{'ISO'}, 'ISOX'=>$ISOX };
		}
	
	return(\@AVAILABLE_COUNTRIES);
	}

##
## LEGACY FUNCTION: 6/9/11
## 
# currently used in:
#/httpd/htdocs/biz/setup/shipping/index.cgi:             my %hash = &ZSHIP::fetch_int_destinations_by_merchant(undef,$webdbref);
#/httpd/htdocs/webapi/merchant/calcshipinfo.cgi: my %dest = &ZSHIP::fetch_int_destinations_by_merchant($USERNAME);
#/httpd/htdocs/webapi/shipping/locations.cgi:    my %dest = &ZSHIP::fetch_int_destinations_by_merchant($USERNAME);=
sub fetch_int_destinations_by_merchant {
	my ($CART2,$webdbref) = @_;

	my %HASH = ();
	foreach my $dst (@{&ZSHIP::available_destinations($CART2,$webdbref)}) {
		$HASH{ $dst->{'Z'} } = $dst->{'ISO'};
		}

	return (%HASH);
	} ## end sub fetch_int_destinations_by_merchant






##
## 
##
#sub validate_address {
#	my ($CART2, $webdbref) = @_;
#
#	## deprecated - use $CART->verify_address instead.
#	warn "running legacy ZSHIP::validate_address()\n";
#
#	if (not defined $cartref->{'data.bill_country'}) { $cartref->{'data.bill_country'} = ''; }
#	if (not defined $webdbref) {
#		warn("no webdb passed [which partition?!?!?]");
#		$webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME); # non-prt friendly
#		}
#	## The suggestions hash is keyed on a pretty name for the suggested address, with a value of another hash
#	## The hash in the value is keyed by address, address2, city, state, zip, and country
#	## When the suggestion is selected from the drop-down, those fields should be overwritten with the
#	## suggested information.
#	my $suggestions = {};
#	my $meta = {};
#	my $err_ref = {};
#		
#	if (($cartref->{'data.bill_country'} ne '') && ($cartref->{'data.bill_country'} ne 'USA') && ($cartref->{'data.bill_country'} ne 'United States')) {
#		## international address 
#		}
#	elsif ((defined $webdbref->{'endicia_avs'}) && ($webdbref->{'endicia_avs'}>0)) {
##		require ZSHIP::ENDICIA;
##		($err_ref) = &ZSHIP::ENDICIA::validate_address($USERNAME,
##				$cartref->{'data.bill_address1'},$cartref->{'data.bill_address2'},
##				$cartref->{'data.bill_city'},$cartref->{'data.bill_state'},$cartref->{'data.bill_zip'},$cartref->{'data.bill_country'},$webdbref);
#		}
#
#	if (($cartref->{'data.bill_country'} ne '') && ($cartref->{'data.bill_country'} ne 'USA') && ($cartref->{'data.bill_country'} ne 'United States')) {
#		## international address 
#		}
#	elsif (num($webdbref->{'upsapi_dom'})) {
#		require ZSHIP::UPSAPI;		
#		($suggestions,$meta) = &ZSHIP::UPSAPI::validate_address($USERNAME,
#				$cartref->{'data.bill_address1'},$cartref->{'data.bill_address2'},
#				$cartref->{'data.bill_city'},$cartref->{'data.bill_state'},$cartref->{'data.bill_zip'},$cartref->{'data.bill_country'},$webdbref);
#		}
#
#	return($suggestions,$meta,$err_ref);
#	}

## Checks to see if a state/province is valid for the country given
## Non-alphanums in the zip are ignored
## Returns a 2 if it doesn't know how to process the request (we should assume the result is good)
## Returns a 1 if the state/province looks valid for the country
## Returns a 0 if it looks invalid for the country
## Note: We should probably eventually use Locale::SubCountry for this purpose
sub check_state {
	my ($state,$country) = @_;
	if (not defined $country) { return 2; }
	if (not defined $state) { return 2; }
	$country = &ZSHIP::correct_country($country);
	if ($country eq '') {
		$state = &ZSHIP::correct_state($state,$country);
		return 1 if &ZTOOLKIT::isin(\@ZSHIP::STATE_CODES,$state);
		return 0;
		}
	elsif ($country eq 'Canada') {
		$state = &ZSHIP::correct_state($state,$country);
		return 1 if &ZTOOLKIT::isin(\@ZSHIP::CANADA_PROVINCE_CODES,$state);
		return 0;
		}
	elsif ($country eq 'United Kingdom') {
		return 1 if ($state =~ m/\w\w+/); ## At least 2 characters
		return 0;
		}
	return 2;
	}

## Checks to see if a postal code is valid for the country given
## Non-alphanums in the zip are ignored
## Returns a 2 if it doesn't know how to process the request (we should assume the result is good)
## Returns a 1 if the zip looks valid for the country
## Returns a 0 if it looks invalid for the country

##
##	http://www.magma.ca/~djcl/postcd.txt
##
sub check_zip {
	my ($zip,$country) = @_;

	if (not defined $country) { return 2; }
	if (not defined $zip) { return 2; }

	$country = &ZSHIP::correct_country($country);
	$zip = uc($zip);
	$zip =~ s/[^A-Z0-9]//gs;
	## Most of the info below here was gleaned from Regexp-Common-2.113/lib/Regexp/Common/zip.pm
	if ($country eq '') {
		## NNNNN
		return 1 if ($zip =~ m/^\d\d\d\d\d$/);
		return 1 if ($zip =~ m/^\d\d\d\d\d\d\d\d\d$/);
		return 0;
		}
	elsif (($country eq 'Canada') || ($country eq 'CA')) {
		## ANA NAN
		return 1 if ($zip =~ m/^[A-Z]\d[A-Z]\d[A-Z]\d$/);
		return 0;
		}
	elsif (($country eq 'United Kingdom') || ($country eq 'GB') || ($country eq 'UK')) {
		## AANANAA AANNNAA ANNAA ANANAA ANNNAA 
		return 1 if ($zip =~ m/^([A-Z][A-Z][A-Z]|[A-Z][A-Z]?\d\d?|[A-Z][A-Z]?\d[A-Z])\d[A-Z][A-Z]$/);
		return 0;
		}
	elsif (($country eq 'Australia') || ($country eq 'AU')) {
		## NNNN
		return 1 if ($zip =~ m/^\d\d\d\d?$/);
		return 0;
		}
	elsif (($country eq 'Belgium') || ($country eq 'Denmark')) {
		## NNNN
		return 1 if ($zip =~ m/^[1-9]\d\d\d$/);
		return 0;
		}
	elsif (
		($country eq 'France') || ($country eq 'FR') ||
		($country eq 'Germany') || ($country eq 'DE') ||
		($country eq 'Greece') || ($country eq 'GR') 
		) {
		## NNNNN
		return 1 if ($zip =~ m/^\d\d\d\d\d$/);
		return 0;
		}
	elsif (($country eq 'Greenland') || ($country eq 'GL')) {	
		return 1 if ($zip =~ m/^39\d\d$/);
		return 0;
		}
	elsif (($country eq 'Netherlands') || ($country eq 'NL')) {
		return (($zip =~ m/^\d\d\d\d[A-Z][A-Z]/)?1:0); 
		}
	elsif (
			($country eq 'Austria') || ($country eq 'AT') ||
			($country eq 'Norway') || ($country eq 'NO') ||
			($country eq 'Philippines') || ($country eq 'PH') ||
			($country eq 'Switzerland') || ($country eq 'CH')
			) { 
		## NNNN
		return (($zip =~ m/^\d\d\d\d$/)?1:0); 
		} 		
	elsif (
			($country eq 'Indonesia') ||  ($country eq 'ID') ||
			($country eq 'Italy') ||  ($country eq 'IT') ||
			($country eq 'Malaysia')  || ($country eq 'MY') ||
			($country eq 'Mexico') ||  ($country eq 'MX') ||
			($country eq 'Puerto Rico') || ($country eq 'PR') ||
			($country eq 'Spain') || ($country eq 'ES') ||
			($country eq 'Sweden') ||  ($country eq 'SE') ||
			($country eq 'Thailand') || ($country eq 'TH') 
			) {
		## NNNNN
		return (($zip =~ m/^\d\d\d\d\d$/)?1:0); 
		} 	
	elsif (
		($country eq 'China') || ($country eq 'CN') ||
		($country eq 'India') || ($country eq 'IN') ||
		($country eq 'Singapore') || ($country eq 'SG') 
		) { 
		## NNNNNN
		return (($zip =~ m/^\d\d\d\d\d\d$/)?1:0); 
		} 
	elsif (($country eq 'Japan') || ($country eq 'JP')) { 
		return (($zip =~ m/^\d\d\d\d\d\d\d$/)?1:0); 		## NNNNNNN
		}
	elsif (($country eq 'Brazil') || ($country eq 'BR')) { 
		## NNNNNNNN
		return (($zip =~ m/^\d\d\d\d\d\d\d\d$/)?1:0); 
		} 	
	
	return 2;
	}

## Sometimes users get imported with incorrect countries that we can
## reasonably correct to Zoovy's internal country names.
## Accepts: a country name that we think is suspect
## Returns: the corrected country name, or what it was sent if we were unable to make a guess
##   Undefs are changed to blank strings
sub correct_country {
	my ($country) = @_;

	if (not defined $country) { $country = ''; }
	$country =~ s/^\s*(.*)\s*$/$1/s; # Strip leading/trailing whitespace
	my $country_orig = $country;
	$country = uc($country);
	$country =~ s/[^A-Z]//gs;
	if ($country eq '') { return ''; }

	## This will catch most odd countries
	if (defined $ZSHIP::COUNTRY_CORRECTIONS{$country}) {
		return $ZSHIP::COUNTRY_CORRECTIONS{$country};
		}

	my $result = undef;
	my $ref = retrieve '/httpd/static/country-zoovylookup.bin';
	if (defined $ref->{$country}) {
		$result = $ref->{$country}->{'Z'};
		}
	else {
		foreach my $cntid (keys %{$ref}) {
			next if (defined $result);
			my $x = $cntid;
			$x =~ s/[^A-Z]//gs;
			if ($x eq $country) { $result = $cntid; }
			}
		}
	$ref = undef;

	## Check the countries file to see if this is a country one of our shippers knows about
	#my $result = undef;
	#if (open COUNTRIES, "<$ZSHIP::INT_HIGHRISK_FILE")
	#{
	#	while ((not defined $result) && (my $line = <COUNTRIES>))
	#	{
	#		next if ($line =~ m/^\#/);
	#		next if ($line !~ m/^\"(.*?)\"/);
	#		my $zoovy_country = $1;
	#		my $linecopy = uc($line);
	#		$linecopy =~ s/[^A-Z\"]//gs;
	#		if ($linecopy =~ m/\"$country\"/) { $result = $zoovy_country; }
	#	}
	#	close COUNTRIES;
	#}

	return (defined $result)?$result:$country_orig;
	}

## Attempts to normalize a US state into to a two-letter USPS state code as used by the Zoovy system
## For international it will do what it can (not implemented yet though)
## If it can't normalize it, it spits back what was sent to it.  Undefs are changed to blank strings
## Note: We should probably eventually use Locale::SubCountry for this purpose
sub correct_state {
	my ($state,$country) = @_;
	if (not defined $state) { $state = ''; }
	if (not defined $country) { $country = ''; }
	$state =~ s/^\s*(.*)\s*$/$1/s; # Strip leading/trailing whitespace
	my $state_orig = $state;
	$state = uc($state);
	$state =~ s/[^A-Z]//gs;
	if ($country eq '') {
		if ($state eq '') { return ''; }
		if ((length($state) == 2) && &ZTOOLKIT::isin(\@ZSHIP::STATE_CODES,$state)) { return $state; }
		if (defined $ZSHIP::STATE_NAMES{$state}) { return $ZSHIP::STATE_NAMES{$state}; }
		}
	elsif ($country eq 'Canada') {
		if ($state eq '') { return ''; }
		if ((length($state) == 2) && &ZTOOLKIT::isin(\@ZSHIP::CANADA_PROVINCE_CODES,$state)) { return $state; }
		if (defined $ZSHIP::CANADA_PROVINCE_NAMES{$state}) {
			return $ZSHIP::CANADA_PROVINCE_NAMES{$state};
			}
		}
	return $state_orig;
	}

## Attempts to normalize a zip/postal code into what it should be depending on country
## If it can't normalize it, it spits back what was sent to it.  Undefs are changed to blank strings
sub correct_zip {
	my ($zip,$country) = @_;
	if (not defined $zip) { $zip = ''; }
	if (not defined $country) { $country = ''; }
	$zip =~ s/^\s*(.*)\s*$/$1/s; # Strip leading/trailing whitespace
	my $zip_orig = $zip;
	$zip = uc($zip);
	$zip =~ s/[^A-Z0-9 -]//gs;
	$zip =~ s/^\s*(.*)\s*$/$1/s; # Strip leading/trailing whitespace
	my $zip_num = $zip_orig;
	$zip_num =~ s/\D//gs;
	if (($country eq '') || ($country eq 'US')) {
		if ($zip_num =~ m/^\d\d\d\d\d$/) { return $zip_num; }
		if ($zip_num =~ m/^(\d\d\d\d\d)(\d\d\d\d)$/) { return "$1-$2"; }
		}
	elsif (($country eq 'United Kingdom') || ($country eq 'UK')) {
		if ($zip =~ m/^([A-Z][A-Z][A-Z]|[A-Z][A-Z]?\d\d?|[A-Z][A-Z]?\d[A-Z])[ -]?(\d[A-Z][A-Z])$/) { return "$1 $2"; }
		return $zip;
		}
	elsif (($country eq 'Canada') || ($country eq 'CA')) {
		if ($zip =~  m/^([A-Z]\d[A-Z])[ -]?(\d[A-Z]\d)$/) { return "$1 $2"; }
		return $zip;
		}
	elsif ($country eq 'Australia') { return $zip_num; }
	elsif ($country eq 'Belgium')   { return $zip_num; }
	elsif ($country eq 'Denmark')   { return $zip_num; }
	elsif ($country eq 'France')    { return $zip_num; }
	elsif ($country eq 'Germany')   { return $zip_num; }
	elsif ($country eq 'Greenland') { return $zip_num; }
	return $zip_orig;
	}


1;
