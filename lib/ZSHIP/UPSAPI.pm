package ZSHIP::UPSAPI;


use strict;

use XML::Writer;
use XML::Simple;
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use XML::Parser;
use XML::Parser::EasyTree;
use Data::Dumper;
use utf8;

use lib '/backend/lib';
require ZSHIP;
require XMLTOOLS;
require ZTOOLKIT;
require ZWEBSITE;

## to access api docs - try:
## http://www.ups.com/gec/techdocs/pdf/RatesandServiceHTML.pdf
## http://www.ups.com/e_comm_access/laServ?CURRENT_PAGE=DOWNLOAD_TOOLS&START_PAGE=WELCOME&
##	OPTION=DOCUMENTATION&TOOL_ID=RateXML&loc=en_US
## 


##
## Zoovy Accunt #: 63F43F
##

$ZSHIP::UPSAPI::DEBUG    = 1;
$ZSHIP::UPSAPI::VERSION  = '1.0';
#$ZSHIP::UPSAPI::ROOT_URI = 'https://wwwcie.ups.com/ups.app/xml'; ## Test Server, Add /ServiceName to this
$ZSHIP::UPSAPI::ROOT_URI = 'https://www.ups.com/ups.app/xml'; ## Real Server, Add /ServiceName to this
@ZSHIP::UPSAPI::MONTHS   = qw(x January February March April May June July August September October November December);

my ($CFG) = CFG->new();
$ZSHIP::UPSAPI::DEFAULT_PARAMS = {
	'shipper_number'=> $CFG->get("ups","shipper_number") || '',
	'access_key'    => $CFG->get("ups","access_key") || '',
	'user'          => $CFG->get("ups","user") || '',
	'password'      => $CFG->get("ups","password") || '',
	'developer_key' => $CFG->get("ups","developer_key") || '',
	};



##	 
##

# WEBAPI FIELDS USED:
# upsapi_dom BITWISE MNEMONICS
%ZSHIP::UPSAPI::DOM_METHODS = (
	2   => 'GND', # UPS Ground
	4   => '3DS', # UPS 3 Day Select
	8   => '2DA', # UPS 2nd Day Air
	16  => '2DM', # UPS 2nd Day Air AM
	32  => '1DP', # UPS Next Day Air Saver
	64  => '1DA', # UPS Next Day Air
	128 => '1DM', # UPS Next Day Air Early AM
	);

# upsapi_int BITWISE MNEMONICS
%ZSHIP::UPSAPI::INT_METHODS = (
	2  => 'STD', # UPS Canada Standard
	4  => 'XPR', # UPS Worldwide Express
	8  => 'XDM', # UPS Worldwide Express Plus
	16 => 'XPD', # UPS Worldwide Expedited
	32 => 'XSV', # UPS Worldwide Saver
	);

# upsapi_options BITWISE MNEMONICS
#%ZSHIP::UPSAPI::OPTIONS = (
#	2  => 'product',
#	4  => 'multibox',
#	8  => 'residential',
#	16 => 'validation',
#	64 => 'disable_pobox',
#	);

#upsapi_dom_packaging
#upsapi_int_packaging
#	'00' => 'Your Packaging',
#	'01' => 'UPS Letter Envelope',
#	'03' => 'UPS Tube',
#	'04' => 'UPS Pak',
#	'21' => 'UPS Express Box',
#	'24' => 'UPS Worldwide 25KG Box', # International Only
#	'25' => 'UPS Worldwide 10KG Box', # International Only
#SMART --> value="SMART">UPS Letter Envelope up 4 oz, Your Packaging for more
#upsapi_rate_chart
#	'01' => 'Daily Pickup',
#	'03' => 'Customer Counter',
#	'06' => 'One Time Pickup',
#	'07' => 'On Call Air',
#	'19' => 'Letter Center',
#	'20' => 'Air Service Center',
## For some reason I thought the old codes used by the original UPS API we called would be used in the new one.
## Silly me.  We keyed off of them, they're vaguely mnemonic.  The XMLCODES hash translated them into what is
## actually used by the API.  -AK
#%ZSHIP::UPSAPI::CODES = (
#	'GND' => 'UGND|UPS Ground',
#	'3DS' => 'U3DS|UPS 3 Day Select®',
#	'2DA' => 'U2DA|UPS 2nd Day Air®',
#	'2DM' => 'U2DM|UPS 2nd Day Air A.M.®',
#	'1DP' => 'U1DP|UPS Next Day Air Saver®',
#	'1DA' => 'U1DA|UPS Next Day Air®',
#	'1DM' => 'U1DM|UPS Next Day Air Early A.M.®',
#	'STD' => 'USTD|UPS Standard to Canada',
#	'XPR' => 'UXPR|UPS Worldwide Express',
#	'XDM' => 'UXDM|UPS Worldwide Express Plus',
#	'XPD' => 'UXPD|UPS Worldwide Expedited',
#);
%ZSHIP::UPSAPI::CODES = (
#	'GND' => 'UGND|UPS Ground',
#	'3DS' => 'U3DS|UPS 3 Day Select',
#	'2DA' => 'U2DA|UPS 2nd Day Air',
#	'2DM' => 'U2DM|UPS 2nd Day Air A.M.',
#	'1DP' => 'U1DP|UPS Next Day Air Saver',
#	'1DA' => 'U1DA|UPS Next Day Air',
#	'1DM' => 'U1DM|UPS Next Day Air Early A.M.',
#	'STD' => 'USTD|UPS Standard to Canada',
#	'XPR' => 'UXPR|UPS Worldwide Express',
#	'XDM' => 'UXDM|UPS Worldwide Express Plus',
#	'XPD' => 'UXPD|UPS Worldwide Expedited',
#	'XSV' => 'UXSV|UPS Worldwide Saver',
	);
%ZSHIP::UPSAPI::XMLCODES = (
#	'03' => 'GND',
#	'12' => '3DS',
#	'02' => '2DA',
#	'59' => '2DM',
#	'13' => '1DP',
#	'01' => '1DA',
#	'14' => '1DM',
#	'11' => 'STD',
#	'07' => 'XPR',
#	'54' => 'XDM',
#	'08' => 'XPD',
#	'65' => 'XSV',
);


foreach my $carrierid (keys %ZSHIP::SHIPCODES) {
	my $ref = $ZSHIP::SHIPCODES{$carrierid};
	next if (not defined $ref->{'ups'});
	$ZSHIP::UPSAPI::XMLCODES{ $ref->{'upsxml'} } = $ref->{'ups'};
	$ZSHIP::UPSAPI::CODES{ $ref->{'ups'} } = sprintf("%s|%s",$carrierid,$ref->{'method'});
	}


##
## this is a temporary method intended to facilitate the migration of the upsapi_ legacy settings
## 
sub upgrade_webdb {
	my ($webdb) = @_;

	if (defined $webdb->{'upsapi_config'}) {
		## this webdb has already been upgraded and has a upsapi_config
		return($webdb);
		}

	$webdb->{'upsapi_dom'} = int($webdb->{'upsapi_dom'});
	$webdb->{'upsapi_int'} = int($webdb->{'upsapi_int'});

	my %ref = ();
	my $enable_dom = 0;
	foreach my $bit (keys %ZSHIP::UPSAPI::DOM_METHODS) {
		my $upscode = $ZSHIP::UPSAPI::DOM_METHODS{$bit};
		$ref{ "$upscode" } = (int($webdb->{'upsapi_dom'}) & $bit)?1:0;
		$enable_dom++;
		## $upscode is the *UPS* code e.g. GND
		}
	$ref{'enable_dom'} = $enable_dom;

	my $enable_int = 0;
	foreach my $bit (keys %ZSHIP::UPSAPI::INT_METHODS) {
		my $upscode = $ZSHIP::UPSAPI::INT_METHODS{$bit};
		$ref{ "$upscode" } = (int($webdb->{'upsapi_int'}) & $bit)?1:0;
		$enable_int++;
		}
	$ref{'enable_int'} = $enable_int;

#	## %ref contains a 1/0 for each of the UPSAPI CODES
#	NOTE: if you delete these keys, then things like ZSHIP which rely on them will break.
#	delete $webdb->{'upsapi_dom'};
#	delete $webdb->{'upsapi_int'};
#	delete $webdb->{'ups_dom'};
#	delete $webdb->{'ups_int'};

	## now copy the license, and password
	$ref{'.license'} = $webdb->{'upsapi_license'};		delete $webdb->{'upsapi_license'};
	$ref{'.userid'} = $webdb->{'upsapi_userid'};		delete $webdb->{'upsapi_userid'};
	$ref{'.password'} = $webdb->{'upsapi_password'};	delete $webdb->{'upsapi_password'};
	$ref{'.shipper_number'} = $webdb->{'upsapi_shipper_number'};	delete $webdb->{'upsapi_shipper_number'};
	$ref{'.rate_chart'} = $webdb->{'upsapi_rate_chart'};	delete $webdb->{'upsapi_rate_chart'};

	#$ref{'.product'} = ($webdb->{'upsapi_options'}&2)?1:0;
	#$ref{'.multibox'} = ($webdb->{'upsapi_options'}&4)?1:0;
	#$ref{'.residential'} = ($webdb->{'upsapi_options'}&8)?1:0;
	#$ref{'.validation'} = ($webdb->{'upsapi_options'}&16)?1:0;
	#$ref{'.disable_pobox'} = ($webdb->{'upsapi_options'}&64)?1:0;
	#delete $webdb->{'upsapi_options'};

	$ref{'.dom_packaging'} = $webdb->{'upsapi_dom_packaging'}; delete $webdb->{'upsapi_dom_packaging'};
	$ref{'.int_packaging'} = $webdb->{'upsapi_int_packaging'}; delete $webdb->{'upsapi_int_packaging'};

	$webdb->{'upsapi_config'} = &ZTOOLKIT::buildparams(\%ref,1);
	
   #       'upsapi_license' => '7C2411DA7CCA97CC',
   #       'upsapi_options' => 56,
   #       'upsapi_password' => 'uocsid1217',
   #       'ups_dom' => '',
   #       'upsapi_rate_chart' => '03',
   #       'upsapi_shipper_number' => '987092',
   #       'ups_int' => '',
   #       'upsapi_dom_packaging' => '00',
   #       'upsapi_userid' => 'discou866',
   #       'upsapi_config' => '1DA=1&1DM=1&1DP=1&2DA=1&2DM=1&3DS=1&GND=1&STD=0&XDM=0&XPD=0&XPR=0&XSV=0',
   #       'upsapi_int_packaging' => '00',

	return($webdb);
	}


foreach my $code (keys %ZSHIP::UPSAPI::CODES) {
	utf8::upgrade($ZSHIP::UPSAPI::CODES{$code});
	}

#$ZSHIP::UPSAPI::DISCLAIMER = 'UPS&reg;, UPS &amp; Shield Design&reg; and UNITED PARCEL SERVICE&reg; are registered trademarks of United Parcel Service of America, Inc.';
$ZSHIP::UPSAPI::DISCLAIMER = 'UPS, THE UPS SHIELD TRADEMARK, THE UPS READY MARK, THE UPS ONLINE TOOLS MARK AND THE COLOR BROWN ARE TRADEMARKS OF UNITED PARCEL SERVICE OF AMERICA, INC. ALL RIGHTS RESERVED.';
$ZSHIP::UPSAPI::LOGO = qq~<img src="/media/graphics/general/ups_logo.gif" width="45" height="50" border="0" align="left">~;
$ZSHIP::UPSAPI::BRANDSTATEMENT = 'UPS, THE UPS SHIELD TRADEMARK, THE UPS READY MARK, THE UPS ONLINE TOOLS MARK AND THE COLOR BROWN ARE TRADEMARKS OF UNITED PARCEL SERVICE OF AMERICA, INC. ALL RIGHTS RESERVED.';

## URL Used to get a rates request
$ZSHIP::UPSAPI::RATE_URI = $ZSHIP::UPSAPI::ROOT_URI.'/Rate';
## XML Used to get a rates request



#$ZSHIP::UPSAPI::RATE_XML = <<'END';
#<?xml version="1.0"?>
#<RatingServiceSelectionRequest xml:lang="en-US">
#	<Request>
#		<RequestAction>Rate</RequestAction>
#		<RequestOption>shop</RequestOption>
#	</Request>
#	<PickupType>
#		<Code>%pickup_type%</Code>
#	</PickupType>
#	<Shipment>
#		<Shipper>
#			<Address>
#				<PostalCode>%sender_zip%</PostalCode>
#			</Address>
#		</Shipper>
#		<ShipTo>
#			<Address>
#				<PostalCode>%recipient_zip%</PostalCode>
#				<CountryCode>%recipient_country%</CountryCode>
#				<ResidentialAddress>%residential%</ResidentialAddress>
#			</Address>
#		</ShipTo>
#		<Service>
#			<Code>11</Code>
#		</Service>
#		<Package>
#			<PackagingType>
#				<Code>%packaging_type%</Code>
#				<Description>Package</Description>
#			</PackagingType>
#			<Description>Rate Shopping</Description>
#			<PackageWeight>
#				<Weight>%weight%</Weight>
#			</PackageWeight>
#		</Package>
#	</Shipment>
#</RatingServiceSelectionRequest>
#END
#

$ZSHIP::UPSAPI::LICENSE_URI = $ZSHIP::UPSAPI::ROOT_URI.'/License';
$ZSHIP::UPSAPI::LICENSE_XML = <<'END';
<?xml version="1.0"?>
<AccessLicenseAgreementRequest>
	<Request>
		<RequestAction>AccessLicense</RequestAction>
		<RequestOption>AllTools</RequestOption>
	</Request>
	<DeveloperLicenseNumber>%developer_key%</DeveloperLicenseNumber>
	<AccessLicenseProfile>
		<CountryCode>US</CountryCode>
		<LanguageCode>EN</LanguageCode>
	</AccessLicenseProfile>
</AccessLicenseAgreementRequest>
END





##
##
##
sub compute {
	my ($CART2, $PKG, $WEBDBREF, $METAREF) = @_;

	my $MERCHANT_ID = $CART2->username();
	if (not defined $WEBDBREF) {
		$WEBDBREF = &ZWEBSITE::fetch_website_dbref($CART2->username(),$CART2->prt());
		}

	my $error = '';
	&ZSHIP::UPSAPI::upgrade_webdb($WEBDBREF);
	my $ORIG_ZIP = defined($WEBDBREF->{'ship_origin_zip'}) ? $WEBDBREF->{'ship_origin_zip'} : '92101';

	my $UPS_CONFIG = &ZTOOLKIT::parseparams($WEBDBREF->{'upsapi_config'});
	# print STDERR Dumper($UPS_CONFIG);

	my $DEST_ZIP = undef;

	my $IS_COD = 0; # $CART2->in_get('data.cod'); # no longer supported
	my $STATE = $CART2->in_get('ship/region');
	my $ISO = $CART2->in_get('ship/countrycode');
	my $PRICE = $PKG->get('items_total'); 
	my $ITEMCOUNT = $PKG->get('items_count'); 
	# print STDERR "DEST: $DEST_ZIP [$UPS_COUNTRY_CODE]\n";

	my $is_domestic = 0;
	my $WEIGHT = undef;
	if (($ISO eq '') || (uc($ISO) eq 'USA') || (uc($ISO) eq 'UNITED STATES') || (uc($ISO) eq 'US')) {
		$WEIGHT = $PKG->value('legacy_usps_weight_194');
		$DEST_ZIP = $CART2->in_get('ship/postal');
		if ($DEST_ZIP eq '') { 
			$DEST_ZIP = '92021'; 
			$PKG->pooshmsg("INFO|+Setting default destination zip code of $DEST_ZIP");
			}
		$is_domestic++;
		$DEST_ZIP =~ s/^(\d\d\d\d\d).*$/$1/;
		if ($DEST_ZIP eq '00602') { $ISO = 'PR'; $is_domestic = 0; }
		elsif ($DEST_ZIP eq '00603') { $ISO = 'PR'; $is_domestic = 0; }
		elsif ($DEST_ZIP eq '00693') { $ISO = 'PR'; $is_domestic = 0; }
		elsif ($STATE eq 'PR') { $ISO = 'PR'; $is_domestic = 0; }
		if ($STATE eq 'PR') { $ISO = 'PR'; $is_domestic = 0; }
		}
	else {
		$WEIGHT = $PKG->value('legacy_usps_weight_166');
		$DEST_ZIP = $CART2->in_get('ship/postal');
		}

	if ($DEST_ZIP eq '') { $DEST_ZIP = '92011'; }

	##
	## SANITY: at this point $is_domestic will not change, nor will COUNTRY
	##

	## need to send at least 5 ounces (total weight) to UPS to get a quote
	if ($WEIGHT < 5 && $WEIGHT > 0) { $WEIGHT = 5; }

	if (int($WEIGHT)>(16*150)) {
		## cart exceeds 150lbs, switching to multi-box
		$UPS_CONFIG->{'.multibox'}++;
		$CART2->is_debug() && $PKG->pooshmsg("INFO|+WARNING: Cart is more than 150lbs ($WEIGHT) switching to multibox.");
		}	
	$PKG->pooshmsg("INFO|+UPS DimWeight[$WEIGHT] Price[$PRICE] IsDomestic[$is_domestic]"); 

	##
	## SANITY: at this point we've established the weight, and it will not change.
	##
	my $UPS_COUNTRY_CODE = 'NOT_SET';
	if ($is_domestic) {
		# Strip off zip+4 info
		$UPS_COUNTRY_CODE = 'US';	
		}
	else {
		if ((uc($ISO) eq 'AU') && ($DEST_ZIP eq '')) {
			$DEST_ZIP = '3129';	## some random australia zip code
			}
		# Get the UPS country code from the Zoovy country name
		#(undef, $UPS_COUNTRY_CODE, undef) = &ZSHIP::fetch_country_shipcodes($ISO);
		#if ($UPS_COUNTRY_CODE eq '') {
		#	$error = "Could not resolve UPS country code for $ISO";
		#	$PKG->pooshmsg("INFO|+ERROR: $error");
		#	}	
		my ($info) = &ZSHIP::resolve_country('ISO'=>$ISO);

		if (not defined $info) {
			warn "ZSHIP::resolve_country(ISO=>$ISO) failed to have 'UPS' value -- we'll try ISO";
			$UPS_COUNTRY_CODE = $ISO;
			}
		elsif ($info->{'UPS'}) { 
			$UPS_COUNTRY_CODE = $info->{'UPS'}; 
			}
		else {
			$UPS_COUNTRY_CODE = $ISO;
			}
		}

	##
	## SANITY: at this point we've established the destination country
	##

	my $packaging = 'NOT_SET';
	if ($is_domestic) {
		$packaging = $UPS_CONFIG->{'.dom_packaging'};
		if ($packaging eq 'SMART') {
			if ($WEIGHT <= 4) { $packaging = '01'; }
			else { $packaging = '00'; }
			}
		}
	else {
		$packaging = $UPS_CONFIG->{'.int_packaging'};
		if ($packaging eq 'SMART') {
			if ($WEIGHT <= 4) { $packaging = '01'; }
			else { $packaging = '00'; }
			}
		}


	##
	## SANITY: at this point we're done "guessing" .. time to build our xml.
	## 


	my @PACKAGES = ();
	my $is_multibox = 0;
	if ($UPS_CONFIG->{'.multibox'}>0) { $is_multibox++; }

#	$is_multibox++;

	if ($is_multibox) {
		my %sets = ();

		my $stuff2 = $CART2->stuff2();
		my $mcount = 0;
		foreach my $item (@{$stuff2->items()}) {
			my $stid = $item->{'stid'};
			my $qty = $item->{'qty'};
			my @pkg_notes = ();
							
			my $weight = $item->{'weight'};
			if (($item->{'weight'}==0) && ($item->{'pkg_cubic_inches'}==0)) {
				if (defined $item->{'%attribs'}->{'zoovy:pkg_multibox_ignore'}) {
					## ignore this item in multi-box
					## useful for "warranty" products
					$PKG->pooshmsg("INFO|+WARNING: Item $stid has zoovy:pkg_multibox_ignore"); 
					$weight = -1;
					}
				elsif ((substr($stid,0,1) eq '%') || ($item->{'is_promo'})) {
					$PKG->pooshmsg("INFO|+WARNING: Item $stid is promotional item and was skipped."); 
					$weight = -1;
					}
				elsif ($item->{'asm_master'} ne '') {
					$PKG->pooshmsg("INFO|+WARNING: Item $stid is an assembly component, and won't have shipping computed."); 
					$weight = -1;
					}
				else {
					$error = 'at least one box in multibox shipment has no weight, and no dimensions (hint: set zoovy:pkg_multibox_ignore to avoid this)';
					}
				}
			## compute dimensional weight per item if applicable.

			if ($item->{'pkg_cubic_inches'}==0) {
				push @pkg_notes, "item has no dimensions specified";
				}		## no dim weight.
			elsif ( ($is_domestic) && ($weight>=(($item->{'pkg_cubic_inches'}/194) * 16)) ) {
				push @pkg_notes, "used actual weight of item (because it's greater than domestic dimensional)";
				} # actual weight is greater
			elsif ($is_domestic) {
				push @pkg_notes, "used domestic dimensional weight of item";
				$weight = ($item->{'pkg_cubic_inches'}/194) * 16;
				}
			elsif ( (!$is_domestic) && ($weight>=(($item->{'pkg_cubic_inches'}/166) * 16)) ) {
				push @pkg_notes, "used actual of item (because it's greater than international dimensional)";
				} # actual weight is greater
			elsif (!$is_domestic) {
				$weight = ($item->{'pkg_cubic_inches'}/166) * 16;
				push @pkg_notes, "used international dimensional weight of item";
				}


			## skip coupons/promotions which don't have a weight (otherwise they cause errors)
			if ((substr($stid,0,1) eq '%') && ($weight==-1)) {
				$PKG->pooshmsg("INFO|+skipping promotion");
				}
			next if ($weight==-1);

			

			## does the package have dimensions?
			my %pkg = ( 'weight'=>$weight );
			if (defined $item->{'%attribs'}->{'zoovy:pkg_height'}) {
				$pkg{'height'} = sprintf("%2.1f",$item->{'%attribs'}->{'zoovy:pkg_height'});
				}
			if (defined $item->{'%attribs'}->{'zoovy:pkg_width'}) {
				$pkg{'width'} = sprintf("%2.1f",$item->{'%attribs'}->{'zoovy:pkg_width'});
				}
			if (defined $item->{'%attribs'}->{'zoovy:pkg_depth'}) {
				$pkg{'length'} = sprintf("%2.1f",$item->{'%attribs'}->{'zoovy:pkg_depth'});
				}

			$pkg{'qty'} = $qty;
			$pkg{'_name'} = "ITEM_$stid";
			if (scalar(@pkg_notes)) {
				$pkg{'_notes'} = join("\n",@pkg_notes);
				}
			if ($error) {
				## don't add package
				}
			elsif (not $is_domestic) {
				$CART2->is_debug() && $PKG->pooshmsg("INFO|+Adding package #$mcount x qty $qty because UPS API for international is broken.");

				$pkg{'_combined_qty'} = $qty;
				$pkg{'qty'} = 1;

				while ($qty-->0) {
					push @PACKAGES, \%pkg;
					}
				}
			else {
				## domestic.. we'll figure out qty's later.
				push @PACKAGES, \%pkg;
				}

			## END FOREACH PACKAGE/STID 
			}
		}
	elsif ($WEIGHT==0) {
		## no sense adding zero lbs. packages.
		$error = 'cart weighs zero pounds (hint: try configuring the item weight.)';
		}
	else {
		push @PACKAGES, { weight=>$WEIGHT, qty=>1, '_name'=>"ONE_BIG_BOX" };
		## UPS Always overrides all others if it returns a result.
		}

	

	if ($error ne '') {
		$PKG->pooshmsg("INFO|+ERROR: UPS error: $error (stopped computation)");
		@PACKAGES = ();
		}
	elsif (scalar(@PACKAGES)==0) {
		$PKG->pooshmsg("INFO|+ERROR: UPS quote shipping found no possible packages. (stopped computation)");
		$error = 'No Valid Packages!'; 
		}
	elsif ($CART2->is_debug()) { 
		my $out = '';
		my $i = 0;
		foreach my $pkg (@PACKAGES) {
			$i++;
			$out .= "BOX[$i]: ";
			foreach my $k (sort keys %{$pkg}) { $out .= "$k=$pkg->{$k}, "; }
			$out .= "\n";
			}
		$PKG->pooshmsg("INFO|+PACKAGE(S):\n".$out); 
		}

	

	##
	## at this point @PACKAGES is fixed.
	##

#	my %options = ();
#	foreach my $bit (keys %ZSHIP::UPSAPI::OPTIONS) {
#		my $upscode = $ZSHIP::UPSAPI::OPTIONS{$bit};
#		$options{$upscode} = (int($WEBDBREF->{'upsapi_options'}) & $bit) ? 1 : 0;
#		}

	my $params = {
		'access_key'		  => $UPS_CONFIG->{'.license'},
		'shipper_number'	  => $UPS_CONFIG->{'.shipper_number'},
		'sender_zip'        => $ORIG_ZIP,
		'recipient_zip'     => $DEST_ZIP,
		'recipient_country' => $UPS_COUNTRY_CODE,
		'packaging_type'    => $packaging,
		'customer_code'	  => $UPS_CONFIG->{'.rate_chart'},
		'pickup_type'       => $UPS_CONFIG->{'.rate_chart'},
		'weight'            => sprintf("%.1f", ($WEIGHT/16)),
		'residential'       => ($UPS_CONFIG->{'.residential'} ? 1 : 0),
		};

	my $xml = '';
	my $w = new XML::Writer(OUTPUT => \$xml, DATA_MODE => 1, DATA_INDENT => 3, ENCODING => 'utf-8');
	$w->startTag("RatingServiceSelectionRequest","xml:lang"=>"en-US");
	$w->startTag("Request");
		$w->dataElement("RequestAction","Rate");
		$w->dataElement("RequestOption","shop");
	$w->endTag("Request");
	$w->startTag("PickupType");	
		## Default value is 01. Valid values are:
		## 01 . Daily Pickup
		## 03 . Customer Counter
		## 06 . One Time Pickup
		## 07 . On Call Air
		## 11 . Suggested Retail Rates
		## 19 . Letter Center
		## 20 . Air Service Center
		$w->dataElement("Code",$UPS_CONFIG->{'.rate_chart'});
	$w->endTag("PickupType");
	$w->startTag("Shipment");
		$w->startTag("Shipper");
#			$w->dataElement("Name","Zoovy");
#			$w->dataElement("ShipperNumber","63F43F");
			$w->startTag("Address");
				$w->dataElement("PostalCode",$ORIG_ZIP);
			$w->endTag("Address");
		$w->endTag("Shipper");
		$w->startTag("ShipTo");	
			$w->startTag("Address");
				$w->dataElement("PostalCode",$DEST_ZIP);
				$w->dataElement("CountryCode",$UPS_COUNTRY_CODE);
				$w->dataElement("ResidentialAddress",($UPS_CONFIG->{'.residential'} ? 1 : 0) );
			$w->endTag("Address");
		$w->endTag("ShipTo");
		$w->startTag("Service");
			$w->dataElement("Code","11");
		$w->endTag("Service");

	my $i = 0; 
	foreach my $pkg (@PACKAGES) {
		$pkg->{'id'} = ++$i;
		if (not defined $pkg->{'packaging'}) { $pkg->{'packaging'} = $packaging; }
		if (not defined $pkg->{'length'}) { $pkg->{'length'} = 0; }
		if (not defined $pkg->{'width'}) { $pkg->{'width'} = 0; }
		if (not defined $pkg->{'height'}) { $pkg->{'height'} = 0; }

		$w->startTag("Package");
			$w->startTag("PackagingType");
				$w->dataElement("Code",$pkg->{'packaging'});
				$w->dataElement("Description","Package #$i");
			$w->endTag("PackagingType");
			$w->startTag("Dimensions");
				$w->startTag("UnitOfMeasure");
					$w->dataElement("Code","IN");
					$w->dataElement("Description","Package #$i");

				$w->endTag("UnitOfMeasure");

				#if ($pkg->{'length'}==0) {
				#	}
				#elsif ($pkg->{'width'}==0) {
				#	}
				#elsif ($pkg->{'height'}==0) {
				#	}
				#else {

				## NOTE: these elements are required!
				$w->dataElement("Length",sprintf("%.2f",$pkg->{'length'}));
				$w->dataElement("Width",sprintf("%.2f",$pkg->{'width'}));
				$w->dataElement("Height",sprintf("%.2f",$pkg->{'height'}));
				#	}
			## Dimensions
			##		UnitOfMeasure
			##			Code	IN		(for inches)
			##			Description	
			##			Length
			##			Width
			##			Height
			$w->endTag("Dimensions");
			$w->dataElement("Description","Rate Shopping #$i");
			$w->startTag("PackageWeight");
				$w->dataElement("Weight",sprintf("%.1f", $pkg->{'weight'}/16)),
			$w->endTag("PackageWeight");
			##	LargePackageIndicator
			##	PackageServiceOptions
			##		InsuredValue
			##			CurrencyCode
			##			MonetaryValue
			##			
		$w->endTag("Package");
		}

# NegotiatedRatesIndicator
#		$w->startTag("RateInformation");
#			$w->dataElement("NegotiatedRatesIndicator",0);
#		$w->endTag("RateInformation");		

	$w->endTag("Shipment");
	$w->endTag("RatingServiceSelectionRequest");
	$w->end();

	$xml = '<?xml version="1.0"?>'.$xml;	


	$CART2->is_debug() && $PKG->pooshmsg("API|+REQUEST: $xml");
	my $prices_xml = '';

	if ($error eq '') {
		$prices_xml = &ZSHIP::UPSAPI::call_ups({},$xml,$ZSHIP::UPSAPI::RATE_URI,$CART2->username(),$WEBDBREF);
		if (not defined $CART2) {
			## sometimes we make calls for non-CART stuff (ex: address validation, registration, etc.)
			}
		elsif ($CART2->is_debug()) { 
			$prices_xml =~ s/></>\n</g;
			$PKG->pooshmsg("API|+UPS output: ".$prices_xml);
			}
		}


	open F, ">/dev/shm/upscall.xml";
	print F "error:$error\n";
	print F "input:$xml\n";
	print F "output:$prices_xml\n";
	# print F $PKG->pretty_dump();
	print F Dumper($PKG);
	close F;


	my %DAYS_TO_DELIVERY = ();
	my %PRICES = ();
	if ($error ne '') {
		## something bad already happened!
		}
	elsif ($prices_xml =~ /<ErrorSeverity>Transient<\/ErrorSeverity>/) {	
		## something bad happened for a little while.
		$PKG->pooshmsg("INFO|+ERROR: UPS experienced transient (will most likely be fixed by UPS) error: $prices_xml");
		$prices_xml = ''; 
		}
	elsif ($prices_xml ne '') {
		my $xs = new XML::Simple(force_array=>1);
		my $ref = undef;
		eval { $ref = $xs->XMLin($prices_xml,KeyAttr=>'RatingServiceSelectionResponse') };

#		print STDERR Dumper($ref,$prices_xml)."\n";
		if (not defined $ref) {
			$CART2->is_debug() && $PKG->pooshmsg("ISE|+UPS ERROR: ".$prices_xml); 
			}
		elsif ($ref->{'Response'}->[0]->{'ResponseStatusDescription'}->[0] ne 'Success') { 
			$CART2->is_debug() && $PKG->pooshmsg("INFO|+UPS ERROR: ".$prices_xml); 
			}
		elsif ($ref->{'Response'}->[0]->{'ResponseStatusCode'}->[0] != 1) {
			## yeoch.. not sure what this is!
			}
		else {

			foreach my $x (@{$ref->{'RatedShipment'}}) {

				my $upscode = $x->{'Service'}->[0]->{'Code'}->[0];
				my $zoovycode = $ZSHIP::UPSAPI::XMLCODES{$upscode};
#				$PKG->pooshmsg("INFO|+ANDREW $upscode $zoovycode".&ZOOVY::incode(Dumper($x)));
				my $pkgcount = scalar(@PACKAGES);
				my $total = 0;
				for $i (0..($pkgcount-1)) {
					next if (not defined $total); ## an error has occurred!
					if (not defined $PACKAGES[$i]->{'qty'}) { $PACKAGES[$i]->{'qty'} = 1; }
					my $price = $x->{'RatedPackage'}->[$i]->{'TotalCharges'}->[0]->{'MonetaryValue'}->[0];
					$total = $total + ($PACKAGES[$i]->{'qty'} * $price);
					$PACKAGES[$i]->{"UPS_$zoovycode"} = $price;		## for debugging, we can just dump @PACKAGES

					}

				if (ref($x->{'GuaranteedDaysToDelivery'}->[0]) ne '') {
					## empty values are passed as <GuaranteedDaysToDelivery/> and result in ->[0] = {} 
					}
				elsif ($x->{'GuaranteedDaysToDelivery'}->[0] > 0) {
					$DAYS_TO_DELIVERY{"$zoovycode"} = $x->{'GuaranteedDaysToDelivery'}->[0];
					}

				if ((not $is_domestic) || ($total == 0)) {
					## so international orders don't always return a price per package (it returns $0.00).. 
					## they only return a total .. so fuck you ups.
#					print Dumper($x);
					$PKG->pooshmsg("INFO|+Using international work around. (is_domestic=$is_domestic|total=$total)");
					$total = $x->{'TotalCharges'}->[0]->{'MonetaryValue'}->[0];
					}

#				print STDERR "TOTAL: pkgcount=$pkgcount zoovycode=$zoovycode upscode=$upscode total=$total\n";
				next unless (defined($total) && $total);
				## REMINDER: we need to do something with quantity
				$PRICES{$zoovycode} = $total;
				}
			}
		}

	###
	### SANITY: at this point we've got %PRICES which is a hash keyed by UPS service code.
	### 

	if ($CART2->is_debug()) {
		my $out = '';
		foreach my $k (keys %PRICES) {
			$out .= "RAW UPS $k QUOTE = \$$PRICES{$k} (before rules)\n";
			}
		$out .= "[[reminder: UPS returns all possible service rates, regardless of which are enabled!]]\n";
		$PKG->pooshmsg("INFO|+RATES(S):\n".$out); 
		}	


	# print STDERR Dumper(\%PRICES,\%DAYS_TO_DELIVERY);
	
#	$PKG->pooshmsg("INFO|+ANDREW ".Dumper($UPS_CONFIG));

	my @RESULTS = ();
	my $rates = {};
	foreach my $upscode (keys %{$UPS_CONFIG}) {
		my $skip = undef;

		## $upscode is the *UPS* code e.g. GND
		next unless defined($upscode);
		next if (substr($upscode,0,1) eq '.');

#		$PKG->pooshmsg("INFO|+ANDREW UPSCODE: $upscode ($UPS_CONFIG->{$upscode})\n");		

		## skip methods which are disabled.

		## $name is the zoovy name e.g. UGND|UPS Ground
		my $name = $ZSHIP::UPSAPI::CODES{$upscode};
		if (not defined($PRICES{$upscode})) { $skip |= 1; }
		elsif (not $PRICES{$upscode}) { $skip |= 2; }
		elsif (not defined($name)) { $skip |= 4; }
		elsif ($UPS_CONFIG->{$upscode}==0) { 
			## disabled method 
			$skip |= 8;
			}

		my ($carrier,$pretty) = split(/\|/,$name,2);
		if (($carrier eq 'USTD') && ($UPS_COUNTRY_CODE ne 'CA')) {
			$skip |= 16;
			}

		next if ($skip);
		
		my $ruleset = ($is_domestic)?("UPSAPI_DOM,UPSAPI_DOM_".uc($upscode)):("UPSAPI_INT,UPSAPI_INT_".uc($upscode));
		#if (not $UPS_CONFIG->{'.use_rules'}) { 
		#	$ruleset = undef; 
		#	$PKG->pooshmsg("INFO|+UPSAPI rules were disabled by uspapi_options directive");
		#	}
			
		push @RESULTS, {
			id=>"UPSAPI:".uc($upscode),
			carrier=>$carrier,
			name=>$pretty,
			zone=>1,
			ruleset=>$ruleset,
			amount=>$PRICES{$upscode},
			guaranteed_delivery_days=>$DAYS_TO_DELIVERY{$upscode}
			};
		}

	my $did_rules = 0;
	foreach my $set (@RESULTS) {
		$set->{'pre_rule_amount'} = $set->{'amount'};
		my $amount = $set->{'amount'};
		foreach my $ruleset (split(/,/,$set->{'ruleset'})) {
			next if (not defined $amount);
			## RULESET is normally UPSAPI_DOM_ and UPSAPI_DOM_xxx
			my $note = $set->{'carrier'} .'|'. $set->{'name'};
			($amount) = &ZSHIP::RULES::do_ship_rules($CART2, $PKG, $ruleset, $amount, $note);				
			}
		$set->{'amount'} = $amount;

		if ($set->{'pre_rule_amount'} != $set->{'amount'}) {
			$set->{'used_rules'} = int(($set->{'amount'} - $set->{'pre_rule_amount'})*100);
			if ($set->{'used_rules'}<=0) { $set->{'used_rules'} = 0; }	 ## probably free shipping!
			}

		}

	if (scalar(@RESULTS)==0) {
		$PKG->pooshmsg("INFO|+NO UPS METHODS WERE RETURNED/AVAILABLE");		
		}
	else {
		$PKG->pooshmsg('INFO|+UPS @RESULT'.Dumper(\@RESULTS));
		}

	return(\@RESULTS);
	}





sub time_in_transit {
	my ($USERNAME,$WEBDBREF, %options) = @_;

	&ZSHIP::UPSAPI::upgrade_webdb($WEBDBREF);
	my $UPS_CONFIG = &ZTOOLKIT::parseparams($WEBDBREF->{'upsapi_config'});

	my $uri = $ZSHIP::UPSAPI::ROOT_URI.'/TimeInTransit';
	my $xml = '';

	my %RESPONSE = ();

	my $w = new XML::Writer(OUTPUT => \$xml, DATA_MODE => 1, DATA_INDENT => 3, ENCODING => 'utf-8');
	$w->startTag('TimeInTransitRequest',"xml:lang"=>"en-US");
      $w->startTag('Request');
			$w->startTag('TransactionReference');
				$w->dataElement('CustomerContext','TNT_D Origin Country Code');
				$w->dataElement('XpciVersion','1.0002');
			$w->endTag('TransactionReference');
			$w->dataElement('RequestAction','TimeInTransit');
		$w->endTag('Request');
		$w->startTag('TransitFrom');
			$w->startTag('AddressArtifactFormat');
				#$w->dataElement('PoliticalDivision1',$options{'origin_region'});
				#if ($options{'origin_region'} eq '') {	$RESPONSE{'@Error'}  = [50,'APP','parameter origin_region is required']; }
				$w->dataElement('CountryCode',$options{'origin_country'});
				if ($options{'origin_country'} eq '') {	$RESPONSE{'@Error'}  = [51,'APP','parameter origin_country is required']; }
				$w->dataElement('PostcodePrimaryLow',$options{'origin_postal'});
				if ($options{'origin_postal'} eq '') {	$RESPONSE{'@Error'}  = [52,'APP','parameter origin_postal is required']; }
#				$w->dataElement('','');
#				$w->dataElement('','');
			$w->endTag('AddressArtifactFormat');
		$w->endTag('TransitFrom');
		$w->startTag('TransitTo');
			$w->startTag('AddressArtifactFormat');
				#$w->dataElement('PoliticalDivision1',$options{'ship_region'});
				#if ($options{'ship_region'} eq '') {	$RESPONSE{'@Error'}  = [55,'APP','parameter ship_region is required']; }
				$w->dataElement('CountryCode',$options{'ship_country'});
				if ($options{'ship_country'} eq '') {	$RESPONSE{'@Error'}  = [56,'APP','parameter ship_country is required']; }
				$w->dataElement('PostcodePrimaryLow',$options{'ship_postal'});
				if ($options{'ship_postal'} eq '') {	$RESPONSE{'@Error'}  = [57,'APP','parameter ship_postal is required']; }
#				$w->dataElement('','');
#				$w->dataElement('','');
#				$w->dataElement('','');
			$w->endTag('AddressArtifactFormat');
		$w->endTag('TransitTo');
#		$w->startTag('ShipmentWeight');
#			$w->startTag('UnitOfMeasurement');
#				$w->dataElement('Code','LBS');
#			$w->endTag('UnitOfMeasurement');
#			$w->dataElement('Weight','50');
#		$w->endTag('ShipmentWeight');
		$w->dataElement('PickupDate',$options{'pickup_yyyymmdd'});
		if ($options{'pickup_yyyymmdd'} eq '') { $RESPONSE{'@Error'}  = [60,'ISE','parameter pickup_yyyymmdd is required']; }
	$w->endTag('TimeInTransitRequest');
	$w->end();
	$xml = '<?xml version="1.0"?>'.$xml;	

#	print STDERR "XML: $xml\n";

	my $response_xml = '';
	if (defined $RESPONSE{'@Error'}) {
		## shit already happened
		}
	else {
		$response_xml = &ZSHIP::UPSAPI::call_ups({},$xml,$uri,$USERNAME,$WEBDBREF);
		if ($response_xml !~ /^\<\?xml version\=\"1\.0\"\?\>/) {
			$RESPONSE{'ResponseStatusDescription'} = 'Failure';
			$RESPONSE{'@Error'}  = [1,'API','NON XML response returned from UPS'];
			}
		elsif ($response_xml !~ /\<TimeInTransitResponse\>.*\<\/TimeInTransitResponse\>/s) {
			$RESPONSE{'ResponseStatusDescription'} = 'Failure';
			$RESPONSE{'@Error'}  = [2,'API','Invalid response returned from UPS (expected TimeInTransitResponse)'];
			}
		}

	my $r = undef;
	if (not defined $RESPONSE{'@Error'}) {
		my $xs = new XML::Simple(force_array=>1);
		$r = $xs->XMLin($response_xml,KeyAttr=>'');
		if (not defined $r) {
			$RESPONSE{'@Error'}  = [10,'ISE','Could not process XML resposne from UPS'];
			}
		elsif (not defined $r->{'Response'}) {
			$RESPONSE{'@Error'}  = [11,'ISE','Cannot process unexpected XML response structure from UPS - expected Response'];
			}
		elsif ($r->{'Response'}->[0]->{'ResponseStatusDescription'}->[0] eq 'Success') {
			## Success, yay!
			$RESPONSE{'ResponseStatusDescription'} = $r->{'Response'}->[0]->{'ResponseStatusDescription'}->[0];
			}
		elsif ($r->{'Response'}->[0]->{'ResponseStatusDescription'}->[0] eq 'Failure') {
			## Failure, boo!
			$RESPONSE{'ResponseStatusDescription'} = $r->{'Response'}->[0]->{'ResponseStatusDescription'}->[0];
			require ZTOOLKIT::XMLUTIL;
			my ($flat) = &ZTOOLKIT::XMLUTIL::SXMLflatten($r);
			$RESPONSE{'@Error'} = [20,'API',sprintf('UPS API Error[%d] %s',$flat->{'.Response.Error.ErrorCode'},$flat->{'.Response.Error.ErrorDescription'}),$response_xml];
         # '@Error' => {
         #               '.Response.TransactionReference.XpciVersion' => '1.0002',
         #               '.Response.Error.ErrorCode' => '270020',
         #               '.Response.ResponseStatusDescription' => 'Failure',
         #               '.Response.TransactionReference.CustomerContext' => 'TNT_D Origin Country Code',
         #               '.Response.ResponseStatusCode' => '0',
         #               '.Response.Error.ErrorSeverity' => 'Hard',
         #               '.Response.Error.ErrorDescription' => 'Pickupdate is outside of the acceptable range'
         #             }
 			}
		else {
			## Unhandled (not Failure, or Success) responses
			$RESPONSE{'ResponseStatusDescription'} = $r->{'Response'}->[0]->{'ResponseStatusDescription'}->[0];
			$RESPONSE{'@Error'} = [13,'API',sprintf("Unknown API ResponseStatusDescription:%s",$RESPONSE{'ResponseStatusDescription'}),$response_xml];
			}
		}

	if (defined $RESPONSE{'@Error'}) {
		## shit already happened
		}
	elsif ($RESPONSE{'ResponseStatusDescription'} eq 'Success') {
		foreach my $k (keys %{$r->{'TransitResponse'}->[0]}) {
			if ($k eq 'ServiceSummary') {
				my @SERVICES = ();
				foreach my $s (@{$r->{'TransitResponse'}->[0]->{'ServiceSummary'}}) {
					my %SERVICE = ();
					$SERVICE{'Guaranteed'} = $s->{'Guaranteed'}->[0]->{'Code'}->[0];
					$SERVICE{'EstimatedArrival.Time'} = $s->{'EstimatedArrival'}->[0]->{'Time'}->[0];
					$SERVICE{'EstimatedArrival.BusinessTransitDays'} = $s->{'EstimatedArrival'}->[0]->{'BusinessTransitDays'}->[0];
					$SERVICE{'EstimatedArrival.PickupDate'} = $s->{'EstimatedArrival'}->[0]->{'PickupDate'}->[0];
					$SERVICE{'EstimatedArrival.DayOfWeek'} = $s->{'EstimatedArrival'}->[0]->{'DayOfWeek'}->[0];
					$SERVICE{'Service.Code'} = $s->{'Service'}->[0]->{'Code'}->[0];
					$SERVICE{'Service.Description'} = $s->{'Service'}->[0]->{'Description'}->[0];
					push @SERVICES, \%SERVICE;
					}
				$RESPONSE{"\@ServiceSummary"} = \@SERVICES;
				}
			elsif (ref($r->{'TransitResponse'}->[0]->{$k}->[0]) eq '') {
				$RESPONSE{"TransitResponse.$k"} = $r->{'TransitResponse'}->[0]->{$k}->[0]
				}
			}
		$RESPONSE{'TransitResponse.Disclaimer'} = $r->{'TransitResponse'}->[0]->{'Disclaimer'}->[0];
		}
	return(\%RESPONSE);
	}




##
## 
##
sub validate_address {
	my ($USERNAME,$WEBDBREF,$ADDRESSREF) = @_;

	if (not defined $WEBDBREF) {
		die "ISE: Invalid WEBDBREF passed to ZSHIP::UPSAPI::validate_address";
		}

	#my %options = ();
	#foreach my $bit (keys %ZSHIP::UPSAPI::OPTIONS) {
	#	my $upscode = $ZSHIP::UPSAPI::OPTIONS{$bit};
	#	$options{$upscode} = (int($WEBDBREF->{'upsapi_options'}) & $bit) ? 1 : 0;
	#	}
	#if (not (int($WEBDBREF->{'upsapi_options'}) & 16)  ) { 
	#	return ({},{}); 
	#	} 

	&ZSHIP::UPSAPI::upgrade_webdb($WEBDBREF);
	my $UPS_CONFIG = &ZTOOLKIT::parseparams($WEBDBREF->{'upsapi_config'});

	## URL Used to get a address validation
	my $uri = $ZSHIP::UPSAPI::ROOT_URI.'/AV';
	my $xml = '';
	my $w = new XML::Writer(OUTPUT => \$xml, DATA_MODE => 1, DATA_INDENT => 3, ENCODING => 'utf-8');
	$w->startTag('AddressValidationRequest',"xml:lang"=>"en-US");
		$w->startTag('Request');
			$w->dataElement('RequestAction','AV');
		$w->endTag('Request');
		$w->startTag('Address');
			$w->dataElement('City',$ADDRESSREF->{'city'});
			$w->dataElement('State',$ADDRESSREF->{'region'});
			$w->dataElement('PostalCode',$ADDRESSREF->{'postal'});
		$w->endTag('Address');
	$w->endTag('AddressValidationRequest');
	$w->end();

	$xml = '<?xml version="1.0"?>'.$xml;	
#	my $xml = q~<?xml version="1.0"?>
#<AddressValidationRequest xml:lang="en-US">
#	<Request>
#		<RequestAction>AV</RequestAction>
#	</Request>
#	<Address>
#		<City>%city%</City>
#		<StateProvinceCode>%state%</StateProvinceCode>
#		<PostalCode>%zip%</PostalCode>
#	</Address>
#</AddressValidationRequest>~;

	# print STDERR "XML: $xml\n";

	my $suggestions = {};
	my $response_xml = call_ups({},$xml,$uri,$USERNAME,$WEBDBREF);

	my $xs = new XML::Simple(force_array=>1);
	open F, ">/dev/shm/response_xml"; print F $response_xml; close F;
	my $ref = {};
	if ($response_xml eq '') {
		warn "UPS ADDRESS VALIDATION FAILURE\n";
		}
	else {
		$ref = $xs->XMLin($response_xml,KeyAttr=>'AddressValidationResponse');
		}
	# print Dumper($ref);

	my %META = ();
	my @POSSIBILITIES = ();

	if ($ref->{'Response'}->[0]->{'ResponseStatusDescription'}->[0] eq 'Failure') {
		# $ref->{'Response'}->[0]->{'Error'}->[0]->{'ErrorCode'}
		$META{'error'} = $ref->{'Response'}->[0]->{'Error'}->[0]->{'ErrorDescription'}->[0];
		$META{'is_valid'} = -1;
		}
	elsif ($ref->{'Response'}->[0]->{'ResponseStatusDescription'}->[0] ne 'Success') {
		## hmm.. we didn't get a success
		$META{'error'} = $ref->{'Response'}->[0]->{'ResponseStatusDescription'}->[0];
		$META{'is_valid'} = -1;	# unknown
		}
	elsif (scalar($ref->{'AddressValidationResult'})>0) {
		## we got responses
		$META{'is_valid'} = 0;
		foreach my $avr (@{$ref->{'AddressValidationResult'}}) {
			foreach my $zip ($avr->{'PostalCodeLowEnd'}->[0] .. $avr->{'PostalCodeHighEnd'}->[0]) {
				next if ($META{'is_valid'});	# no sense continuing if we've got a valid address
				my $score = int($avr->{'Quality'}->[0]*100);
				if ($score >= 99) { $META{'is_valid'} = 1; }
				push @POSSIBILITIES, { 
					'score'=>$score,
					'state'=>$avr->{'Address'}->[0]->{'StateProvinceCode'}->[0],
					'city'=>$avr->{'Address'}->[0]->{'City'}->[0],
					'zip'=>$zip,
					};
				}
			}
		}
	else {
		## unknown!?
		$META{'error'} = 'unknown response';
		$META{'is_valid'} = -1; # unknown
		}

	if ($META{'is_valid'} == -1) {
		}
	elsif (scalar(@POSSIBILITIES)>0) {
		$META{'force_blurb'} = qq~
<small><i>
$ZSHIP::UPSAPI::LOGO
NOTICE: UPS assumes no liability for the information provided by the address validation functionality.  
The address validation functionality does not support the identification of occupants at an address,
and will validate P.O. Boxes, though UPS will not deliver to them.  
Attempts by customer to ship to a P.O. Box via UPS may result in additional charges.<br><br>
$ZSHIP::UPSAPI::DISCLAIMER.
</i></small>
		~;
		}

	return (\@POSSIBILITIES,\%META);
	}


##
##
##
sub track_package {
	my ($USERNAME,$WEBDBREF,$tracking_number,%params) = @_;

	my $html = $params{'html'};
	if (not defined $WEBDBREF) {
		$WEBDBREF = &ZWEBSITE::fetch_website_dbref($USERNAME,0);
		}

	my $ERROR = undef;
	&ZSHIP::UPSAPI::upgrade_webdb($WEBDBREF);
	my $UPS_CONFIG = &ZTOOLKIT::parseparams($WEBDBREF->{'upsapi_config'});

	if (defined $ERROR) {}
	elsif ($tracking_number eq '') { $ERROR = "UPS Tracking number is invalid"; }
	elsif ($UPS_CONFIG->{'.license'} eq '') { $ERROR = "UPS Configuration (license key) not set"; }
	elsif ($UPS_CONFIG->{'.shipper_number'} eq '') { $ERROR = "UPS Configuration (shipper number) not set"; }

	my $params = {
		'access_key' => $UPS_CONFIG->{'.license'},
		'shipper_number'	  => $UPS_CONFIG->{'.shipper_number'},
		'tracking_number' => $tracking_number,
		};
	
	my $uri = $ZSHIP::UPSAPI::ROOT_URI.'/Track';
	## XML Used to get a address validation
	my $xml = qq~<?xml version="1.0"?>
<TrackRequest xml:lang="en-US">
	<Request>
		<RequestAction>Track</RequestAction>
		<RequestOption>activity</RequestOption>
	</Request>
	<TrackingNumber>$tracking_number</TrackingNumber>
</TrackRequest>~;

	my $content = call_ups($params,$xml,$uri,$USERNAME,$WEBDBREF);
	if ($content =~ m/^\s*$/) { $ERROR = "Invalid content returned from UPS"; }

	print STDERR "CONTENT: $content\n";

	#require XML::Simple;
	#my ($ref) = XML::Simple::XMLin($content,ForceArray=>1);

	my $parser = new XML::Parser(Style=>'EasyTree');
	my $tree = $parser->parse($content);
	$parser = undef;
	my $subtree = &XMLTOOLS::prune_easytree($tree,'TrackResponse.Shipment');
	my $packages = {};
	my $service = '';
	my $pickup = '';
	my $delivery = '';
	foreach my $element (@{$subtree})
	{
		my $name = $element->{'name'};
		next unless (defined $name);
		my $hash = &XMLTOOLS::easytree_flattener($element->{'content'});
		if ($name eq 'Service')
		{
			$service = $hash->{'Description'};
		}
		elsif ($name eq 'PickupDate')
		{
			$pickup = &ZSHIP::UPSAPI::ups_date($hash->{''});
		}
		elsif ($name eq 'ScheduledDeliveryDate')
		{
			$delivery = &ZSHIP::UPSAPI::ups_date($hash->{''});
		}
		elsif ($name eq 'Package')
		{
			my $actions = {};
			my $number = '';
			foreach my $subelement (@{$element->{'content'}})
			{
				my $subname = $subelement->{'name'};
				next unless (defined $subname);
				my $subhash = &XMLTOOLS::easytree_flattener($subelement->{'content'});
				if ($subname eq 'TrackingNumber')
				{
					$number = $subhash->{''};
				}
				elsif ($subname eq 'Activity') {
					my $id = $subhash->{'Date'}.$subhash->{'Time'};
					if (defined $subhash->{'ActivityLocation.Address.City'}) {
						$actions->{$id} = &ZSHIP::UPSAPI::ups_date($subhash->{'Date'}) . ' ' . &ZSHIP::UPSAPI::ups_time($subhash->{'Time'}) . ' :';
						$actions->{$id} .= " $subhash->{'ActivityLocation.Address.City'}, $subhash->{'ActivityLocation.Address.StateProvinceCode'} $subhash->{'ActivityLocation.Address.CountryCode'} -";
						$actions->{$id} .= " $subhash->{'Status.StatusType.Description'}";
						if (defined $subhash->{'ActivityLocation.Description'}) { $actions->{$id} .= " ($subhash->{'ActivityLocation.Description'})"; }
						}
					elsif ($subhash->{'Status.StatusType.Code'} eq 'M') {
						$actions->{$id} = &ZSHIP::UPSAPI::ups_date($subhash->{'Date'}) . ' ' . &ZSHIP::UPSAPI::ups_time($subhash->{'Time'}) . ' :';
						$actions->{$id} .= ' UPS Received package information';			
						}
				}
			}
			next if ($number eq '');
			foreach my $action (sort keys %{$actions})
			{
				$packages->{$number} .= $actions->{$action}."\n";
			}
		}
	}
	my $out = '';
	my $num_pkg = (scalar keys %{$packages});
	if ($num_pkg) {
		$out .= "Shipped Via: UPS $service\n";
		if ($pickup ne '') { $out .= "Picked Up: $pickup\n"; }
		if ($delivery ne '') { $out .= "Scheduled Delivery Date: $delivery\n"; }
		foreach my $pkg (keys %{$packages}) {
			my $tmp = $packages->{$pkg};
			if ($num_pkg > 1)	{
				$out .= "Tracking Number: $pkg\n";
				my $new_tmp = '';
				foreach (split /\n/,$tmp) { $new_tmp .= '    '.$_."\n"; }
				$tmp = $new_tmp;
				}
			$out .= $tmp;
			}
		}
	elsif ($ERROR) {
		$out = "Internal Error: $ERROR";
		}
	else {
		my $hash = &XMLTOOLS::easytree_flattener($tree);
		my $error = $hash->{'TrackResponse.Response.Error.ErrorDescription'};
		$out = "Error tracking number $tracking_number via UPS: $error.\n";
		# &msg($hash,'*hash');
		}

	if ($html) {
		$out =~ s/\n/<br>\n/gs;
		my $new_out = '';
		foreach (split /\n/,$out) { s/^\s+/&nbsp;&nbsp;&nbsp;&nbsp;/; $new_out .= $_."\n"; }
		$out = $new_out;
		}
	my $meta = {
		'force_blurb'  => &ZTOOLKIT::untab(qq~
			<small><i>
            $ZSHIP::UPSAPI::LOGO
			Notice: The UPS package tracking systems accessed via this service (the "Tracking Systems")
			and tracking information obtained through this service (the "Information") are the private
			property of UPS. UPS authorizes you to use the Tracking Systems solely to track shipments
			tendered by or for you to UPS for delivery and for no other purpose. Without limitation, you
			are not authorized to make the Information available on any web site or otherwise reproduce,
			distribute, copy, store, use or sell the Information for commercial gain without the express
			written consent of UPS. This is a personal service, thus you right to use the Tracking Systems
			or Information is non-assignable. Any access or use that is inconsistent with these terms is 
			unauthorized and strictly prohibited.  
			$ZSHIP::UPSAPI::DISCLAIMER
			</i></small>
		~)
		};


	return ($out, $meta);
}



##
##
##



#####################################################
##
## get a current copy of the license text 
##
sub get_ups_license {
	my ($USERNAME) = @_;
	my $content = call_ups({},$ZSHIP::UPSAPI::LICENSE_XML,$ZSHIP::UPSAPI::LICENSE_URI,undef,undef);
	$content = &XMLTOOLS::scrub($content);
	my $license_text = '';
	if ($content =~ m/<AccessLicenseText>(.*?)<\/AccessLicenseText>/s) {
		$license_text = $1;
		}
	return $license_text;
}

#############################################
##
## returns:
##
sub get_ups_registration {
	my ($USERNAME,$params) = @_;

	my $password = substr(join("",reverse(split(//,$USERNAME))).(time()%3600),-10);
	my $userid = substr($USERNAME,0,6).(time()%9999);

	## $params shoudl include:
	##	company_name address1 address2 city state (2-letter) zip country (UPS country code)
	##	name title (Mr, etc) email phone url shipper_number

	$params->{'license_text'} = &get_ups_license($USERNAME);

	my $ACCESSLICENSE_XML = qq~<?xml version="1.0"?>
<AccessLicenseRequest xml:lang="en-US">
	<Request>
		<RequestAction>AccessLicense</RequestAction>
		<RequestOption>AllTools</RequestOption>
	</Request>
	<CompanyName>%company_name%</CompanyName>
	<Address>
		<AddressLine1>%address1%</AddressLine1>
		<AddressLine2>%address2%</AddressLine2>
		<City>%city%</City>
		<StateProvinceCode>%state%</StateProvinceCode>
		<PostalCode>%zip%</PostalCode>
		<CountryCode>%country%</CountryCode>
	</Address>
	<PrimaryContact>
		<Name>%name%</Name>
		<Title>%title%</Title>
		<EMailAddress>%email%</EMailAddress>
		<PhoneNumber>%phone%</PhoneNumber>
	</PrimaryContact>
	<CompanyURL>%url%</CompanyURL>
	<ShipperNumber>%shipper_number%</ShipperNumber>
	<DeveloperLicenseNumber>%developer_key%</DeveloperLicenseNumber>
	<AccessLicenseProfile>
		<CountryCode>US</CountryCode>
		<LanguageCode>EN</LanguageCode>
		<AccessLicenseText>%license_text%</AccessLicenseText>
	</AccessLicenseProfile>
	<ClientSoftwareProfile>
		<SoftwareInstaller>%contact%</SoftwareInstaller>
		<SoftwareProductName>Zoovy E-Commerce</SoftwareProductName>
		<SoftwareProvider>Zoovy, Inc.</SoftwareProvider>
		<SoftwareVersionNumber>N/A</SoftwareVersionNumber>
	</ClientSoftwareProfile>
</AccessLicenseRequest>
~;

	print STDERR "$ACCESSLICENSE_XML\n";
	print STDERR Dumper($params);

	my $content = call_ups($params,$ACCESSLICENSE_XML,$ZSHIP::UPSAPI::ROOT_URI.'/License',undef,undef);
	$content = &XMLTOOLS::scrub($content);
	return if ($content =~ m/^\s*$/);

	my $parser = new XML::Parser(Style=>'EasyTree');
	my $tree = $parser->parse($content);
	$parser = undef;
	$tree = &XMLTOOLS::prune_easytree($tree,'AccessLicenseResponse');
	my $hash = &XMLTOOLS::easytree_flattener($tree);
	my $error = '';
	my $license_number = '';
	if ((defined $hash->{'Response.Error.ErrorSeverity'}) &&
		($hash->{'Response.Error.ErrorSeverity'} eq 'Hard') &&
		(defined $hash->{'Response.Error.ErrorDescription'}) &&
		($hash->{'Response.Error.ErrorDescription'} ne '') ) {
			$error = $hash->{'Response.Error.ErrorDescription'};
		}
	elsif (
		(defined $hash->{'Response.ResponseStatusCode'}) &&
		($hash->{'Response.ResponseStatusCode'} eq '1') &&
		(defined $hash->{'AccessLicenseNumber'}) &&
		($hash->{'AccessLicenseNumber'} ne '')) {
		## Save off the merchant information here.
		$license_number = $hash->{'AccessLicenseNumber'};
		}
	else {
		$error = 'Unknown error contacting UPS, please try again later.';
		}

	#<AccessLicenseResponse>
	#     <Response>
	#         <TransactionReference/>
	#         <ResponseStatusCode>1</ResponseStatusCode>
	#         <ResponseStatusDescription>Success</ResponseStatusDescription>
	#     </Response>
	#     <AccessLicenseNumber>FB8D83DF81FC2FA6</AccessLicenseNumber>
	#</AccessLicenseResponse>
	#&ZWEBSITE::save_website_attrib('upsapi_license',$hash->{'AccessLicenseNumber'});

	if ($error eq '') {
		my $REGISTRATION_XML = qq~<?xml version="1.0"?>
			<RegistrationRequest>
			<Request>
				<TransactionReference>
				<CustomerContext>x893</CustomerContext>
				<XpciVersion>1.0001</XpciVersion>
				</TransactionReference>
				<RequestAction>Register</RequestAction>
			<RequestOption>suggest</RequestOption>
			</Request>
			<UserId>$userid</UserId>
			<Password>$password</Password>
			<RegistrationInformation>
				<UserName>$USERNAME</UserName>
				<CompanyName>%company_name%</CompanyName>
				<Title>%title%</Title>
				<Address>
					<AddressLine1>%address1%</AddressLine1>
					<City>%city%</City>
					<StateProvinceCode>%state%</StateProvinceCode>
					<PostalCode>%zip%</PostalCode>
					<CountryCode>%country%</CountryCode>
				</Address>
				<PhoneNumber>%phone%</PhoneNumber>
				<EMailAddress>%email%</EMailAddress>
				<ShipperNumber>%shipper_number%</ShipperNumber>
				<PickupPostalCode>%zip%</PickupPostalCode>
				<PickupCountryCode>US</PickupCountryCode>
			</RegistrationInformation>
		</RegistrationRequest>
		~;
		my $content = call_ups($params,$REGISTRATION_XML,$ZSHIP::UPSAPI::ROOT_URI.'/Register',undef,undef);
		$content = &XMLTOOLS::scrub($content);
		return if ($content =~ m/^\s*$/);
		my $parser = new XML::Parser(Style=>'EasyTree');
		my $tree = $parser->parse($content);
		$parser = undef;
		$tree = &XMLTOOLS::prune_easytree($tree,'RegistrationResponse');
		my $hash = &XMLTOOLS::easytree_flattener($tree);
		my $license_number = '';
		if ((defined $hash->{'Response.Error.ErrorSeverity'}) &&
			($hash->{'Response.Error.ErrorSeverity'} eq 'Hard') &&
			(defined $hash->{'Response.Error.ErrorDescription'}) &&
			($hash->{'Response.Error.ErrorDescription'} ne '') ) {
				$error = sprintf("(UPS#%d) %s",$hash->{'Response.Error.ErrorCode'},$hash->{'Response.Error.ErrorDescription'});
			}
		elsif (
			(defined $hash->{'Response.ResponseStatusCode'}) &&
			($hash->{'Response.ResponseStatusCode'} eq '1')) {
			## NO ERRORS! WHOOP!
			}
		else {
			$error = 'Unknown error when contacting UPS, please try again later.';
			}
		}

	if ($error ne '') {
		$userid = '';
		$password = '';
		}

	# print STDERR "$error,$license_number,$userid,$password\n";

	return ($error,$license_number,$userid,$password); ## You should only get back one or the other as non-blank
}

##############################################################################
## GENERAL UPS FUNCTIONS
##############################################################################



## Takes a UPS-formatted date code and makes it human-reabible
sub ups_date {
	return '' unless (defined $_[0]);
	return '' unless ($_[0] =~ m/^(\d\d\d\d)(\d\d)(\d\d)$/);
	return $ZSHIP::UPSAPI::MONTHS[$2].' '.$3.', '.$1;
	}

## Takes a UPS-formatted time code and makes it human-reabible
sub ups_time {
	return '' unless (defined $_[0]);
	return '' unless ($_[0] =~ m/^(\d\d)(\d\d)(\d\d)$/);
	my $hour = $1; my $min  = $2; my $ampm = 'a';
	if ($hour > 12) { $hour = $hour - 12; $ampm = 'p'; }
	return $hour.':'.$min.$ampm;
	}

##
##
##
sub call_ups {
	my ($params,$xml,$uri,$USERNAME,$WEBDBREF) = @_;

	if (not defined $USERNAME) { 
		$USERNAME = ''; 
		}

	my $UPS_CONFIG = &ZTOOLKIT::parseparams($WEBDBREF->{'upsapi_config'});

	if ($USERNAME ne '') {
		# Add on the access request to the beginning
		$params->{'access_key'} = $UPS_CONFIG->{'.license'};
		$params->{'shipper_number'} = $UPS_CONFIG->{'.shipper_number'};
		$xml = q~<?xml version="1.0"?>
<AccessRequest xml:lang="en-US">
	<AccessLicenseNumber>%access_key%</AccessLicenseNumber>
	<UserId>%user%</UserId>
	<Password>%password%</Password>
</AccessRequest>~ . $xml;

		if (not defined $WEBDBREF) { $WEBDBREF = &ZWEBSITE::fetch_website_dbref($USERNAME); }
		}

	my $new_params = $ZSHIP::UPSAPI::DEFAULT_PARAMS;
	if ($USERNAME ne '') {
		my $user = $UPS_CONFIG->{'.userid'};
		my $pass = $UPS_CONFIG->{'.password'};
		if ((defined $user) && ($user ne '')) {
			$new_params->{'user'} = $user;
			$new_params->{'pass'} = $pass;
			}
		}

	## Encoode all of the params for proper XML value formatting
	foreach my $key (keys %{$params}) {
		$new_params->{$key} = &XMLTOOLS::xml_incode($params->{$key});
		}

	## Override fields that should already be encoded (we need to send these back exactly how we got them)
	foreach my $key ('license_text') {
		next unless (defined $new_params->{$key});
		$new_params->{$key} = $params->{$key};
		}

	$xml =~ s/\%(\w+)\%/$new_params->{$1}/gs;
	
	#print STDERR $xml."\n";
	
	my $cached = 0;
	my $content = '';
	my $t = time();

	if ($uri eq $ZSHIP::UPSAPI::TRACK_URI) {
		$cached = -1;		# do not cache this request!
		}

	require DBINFO;
	require Digest::MD5;
	# my $dbh = &DBINFO::db_user_connect($USERNAME);
	my ($memd) = &ZOOVY::getMemd($USERNAME);
	my $md5 = Digest::MD5::md5_hex($xml);

	# print "XML: $xml\n";
	#my $pstmt = "select RESPONSE from UPS_QUERIES where MD5=".$dbh->quote($md5);
	#if ($cached == 0) {
	#	my $sth = $dbh->prepare($pstmt);
	#	$sth->execute();
	#	if ($sth->rows()) {
	#		$cached = 1;
	#		($content) = $sth->fetchrow();
	#		$sth->finish();
	#		$pstmt = "update UPS_QUERIES set LOOKUPS=LOOKUPS+1 where MD5=".$dbh->quote($md5);
	#		$dbh->do($pstmt);
	#		}
	#	$sth->finish();
	#	}
	my $MEMCACHE_KEY = "UPS::$USERNAME:$md5";
	$ZSHIP::UPSAPI::DEBUG && print STDERR "MEMCACHEKEY:$MEMCACHE_KEY\n";
	if ($cached == 0) {
		($content) = $memd->get($MEMCACHE_KEY);
		$ZSHIP::UPSAPI::DEBUG && print STDERR "GET KEY: $MEMCACHE_KEY\n";
		if ($content ne '') { $cached++; }
		}

	if ($cached <= 0) {
		my $ua = new LWP::UserAgent;
		$ua->agent('Zoovy UPS API Binding/'.$ZSHIP::UPSAPI::VERSION.' ('.$ua->agent.')');
		$ua->timeout(10); ## Inactivity timeout, not a whole transaciton timeout
		my $req = HTTP::Request->new(POST => $uri);
		$req->content_type('application/x-www-form-urlencoded');
		$req->content($xml);
		my $res = $ua->request($req);
		$content = $res->content;

		if (! $res->is_success) {
			$content = '';
			}
		elsif ($cached == -1) {
			## do not cache requests (e.g. tracking!)
			}
		else {
		#	$pstmt = "insert into UPS_QUERIES (DELAY,CREATED,MERCHANT,MD5,REQUEST,RESPONSE) values($t,now(),".$dbh->quote($USERNAME).",".$dbh->quote($md5).",".$dbh->quote($xml).",".$dbh->quote($content).")";
		#	# print STDERR $pstmt."\n";
		#	$dbh->do($pstmt);
			$ZSHIP::UPSAPI::DEBUG &&	print STDERR "SET KEY: $MEMCACHE_KEY\n";
			$memd->set($MEMCACHE_KEY,$content,60*60);
			}
		}
	# &DBINFO::db_user_close();


	# $ZSHIP::UPSAPI::DEBUG++;
	if ($ZSHIP::UPSAPI::DEBUG) {
		if (open DEBUG, '>/dev/shm/upsapi_call_debug.txt') {
			print DEBUG Dumper($xml,$content);
			close DEBUG;
			}
		}

	return ($content);
	}



##############################################################################
##
## ZSHIP::UPSAPI::msg
##
## Purpose: Prints an error message to STDERR (the apache log file)
## Accepts: An error message as a string, or a reference to a variable (if a
##          reference, the name of the variable must be the next item in the
##          list, in the format that Data::Dumper wants it in).  For example:
##          &msg("This house is ON FIRE!!!");
##          &msg(\$foo=>'*foo');
##          &msg(\%foo=>'*foo');
## Returns: Nothing
##

1;

