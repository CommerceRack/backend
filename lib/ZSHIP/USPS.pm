package ZSHIP::USPS;

use strict;

use lib '/backend/lib/';
require CFG;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use strict;
use Data::Dumper;
use XML::Writer;

##
## WEB HELP DESK: 800-344-7779
##

$ZSHIP::USPS::CFG = CFG->new();
$ZSHIP::USPS::USERNAME = $ZSHIP::USPS::CFG->get("usps","username") || "";
$ZSHIP::USPS::PASSWORD = $ZSHIP::USPS::CFG->get("usps","password") || "";
$ZSHIP::USPS::URL      = "http://production.shippingapis.com/ShippingAPI.dll";

# https://www.usps.com/webtools/_pdf/Rate-Calculators-v1-3.pdf
# Document Version 1.3 (04/17/2011)

## 
## http://production.shippingapis.com/ShippingAPITest.dll?API=Verify&XML=<AddressValidateRequest USERID="xxxxxxx"><Address ID="0"><Address1></Address1><Address2>6406 Ivy Lane</Address2><City>Greenbelt</City><State>MD</State><Zip5></Zip5><Zip4></Zip4></Address></AddressValidateRequest>
##
##
## DOCS:
## https://www.usps.com/business/web-tools-apis/rate-calculator-api.htm#_Toc412108429


# This returns two arrays of all of the places that are acknowledged as domestic by USPS
# which are regarded as international by everyone else.  One is arrayref is the state
# code, the other is the international name.  Used by checkout.cgi
sub is_really_usps_domestic {
	my ($SHIP_TO_COUNTRY,$SHIP_TO_ISO) = @_;

	my $is_usps_domestic = 0;
	my @ALMOST_STATE_ISO = ('AS', 'FM', 'GU', 'MH', 'PW', 'PR', 'VI');
	my @ALMOST_STATE_COUNTRY = ('American Samoa', 'Micronesia', 'Guam', 'Marshall Islands', 'Palau', 'Puerto Rico', 'Virgin Islands');

	foreach my $iso (@ALMOST_STATE_ISO) {
		if ($iso eq $SHIP_TO_ISO) {
			$is_usps_domestic++;
			}
		}

	foreach my $country (@ALMOST_STATE_COUNTRY) {
		if ($country eq $SHIP_TO_COUNTRY) {
			$is_usps_domestic++;
			}
		}

	return($is_usps_domestic);
	}


##
##
##
sub domestic_compute {
	my ($CART2, $PKG, $WEBDBREF, $METAREF) = @_;

	my $ORIG_ZIP = defined($WEBDBREF->{'ship_origin_zip'}) ? $WEBDBREF->{'ship_origin_zip'} : '92101';
	my $DEST_ZIP = $CART2->in_get('ship/postal');
	$DEST_ZIP =~ s/^(\d\d\d\d\d).*$/$1/;

	# my $WEIGHT = $PKG->get('pkg_weight');
	my $WEIGHT = $PKG->get('legacy_usps_weight_194');
	# my $WEIGHT = $PKG->get('pkg_weight');
	my $USERNAME = $CART2->username();
	my $PRICE = $PKG->get('items_total');

	# Strip off zip+4 info (don't use \d because it will eval 0#### as ####)
	$DEST_ZIP =~ s/^([0-9]{5}).*$/$1/;

	if (length($DEST_ZIP) != 5) { warn "no DEST_ZIP"; return([]); }
	if ($WEIGHT == 0) { warn "WEIGHT=0"; return([]); }

	my $xmlin = '';
	my $writer = new XML::Writer(OUTPUT => \$xmlin, NEWLINES => 0);

	$WEIGHT = &ZSHIP::smart_weight($WEIGHT);
	if ($WEIGHT<1) { $WEIGHT = 1; }
	my $POUNDS = int($WEIGHT / 16);
	my $OZ     = int($WEIGHT % 16);
	if (($POUNDS==0) && ($OZ == 0)) { $OZ = 1; }
	if ( $OZ < 1) { $OZ = 1; }


	$writer->startTag("RateV4Request","USERID" => "$ZSHIP::USPS::USERNAME","PASSWORD"=>"$ZSHIP::USPS::PASSWORD");
	# $writer->dataElement("Revision", '2');
	## note: allows up to 25 packages
	$writer->startTag("Package","ID"=>"1");
		$writer->dataElement("Service","ALL"); 	 # ''|FIRST CLASS|FIRST CLASS COMMERCIAL|FIRST CLASS HFP COMMERCIAL|PRIORITY|PRIORITY COMMERCIAL|PRIORITY HFP COMMERCIAL|EXPRESS|EXPRESS COMMERCIAL|EXPRESS SH|EXPRESS SH COMMERCIAL|EXPRESS HFP|EXPRESS HFP COMMERCIAL|PARCEL|MEDIA|LIBRARY|ALL|ONLINE|
		$writer->dataElement("FirstClassMailType","PARCEL"); # LETTER|FLAT|PARCEL|POSTCARD 
		$writer->dataElement("ZipOrigination",$ORIG_ZIP);
		$writer->dataElement("ZipDestination",$DEST_ZIP);
		$writer->dataElement("Pounds",$POUNDS);
		$writer->dataElement("Ounces",$OZ);
		$writer->dataElement("Container","VARIABLE"); # default=VARIABLE|VARIABLE|FLAT RATE ENVELOPE|PADDED FLAT RATE ENVELOPE|LEGAL FLAT RATE ENVELOPE|SM FLAT RATE ENVELOPE|WINDOW FLAT RATE ENVELOPE|GIFT CARD FLAT RATE ENVELOPE|FLAT RATE BOX|SM FLAT RATE BOX|MD FLAT RATE BOX|LG FLAT RATE BOX|REGIONALRATEBOXA|REGIONALRATEBOXB|RECTANGULAR|NONRECTANGULAR|

		# REGULAR: Package dimensions are 12.. or less;
		# LARGE: Any package dimension is larger than 12...
		$writer->dataElement("Size","REGULAR");	# LARGE|REGULAR

		# RateV4Request / Package / Girth
		# RateV4Request / Package / Value: Package value. Used to determine availability and cost of extra services.
		# RateV4Request / Package / AmountToCollect
		# RateV4Request / Package / SpecialServices SpecialServices (not available to type ALL)

		# RateV4Request / Package / SortBy : Returns all mailing services available based on item shape. When specified, value in <Container> is ignored.
		# 												 Available when: RateV4Request[Service='ALL'] RateV4Request[Service='ONLINE'] For example: <SortBy>PACKAGE</SortBy>

		# RateV4Request / Package / Machinable: RateV4Request/Machinable is required when: RateV4Request[Service='FIRST CLASS' and (FirstClassMailType='LETTER' or FirstClassMailType='FLAT')]
		#													 RateV4Request[Service='PARCEL POST'], RateV4Request[Service='ALL'], RateV4Request[Service='ONLINE']
		#													 For example: <Machinable>true</Machinable>
		$writer->dataElement("Machinable","true");

		# RateV4Request / Package / ReturnLocations: Include Dropoff Locations in Response if available. Requires "ShipDate" tag.
		# RateV4Request / Package / ShipDate / @Option
	#	$writer->dataElement("ShipDate","2011-12-30");
	$writer->endTag("Package");
	$writer->endTag("RateV4Request");
	$writer->end();

	# print "OUTPUT: $xmlin\n";

	my ($xmlout) = &ZSHIP::USPS::api('RateV4',$xmlin);

	open F, ">/dev/shm/usps.out";
	print F Dumper($xmlout,$xmlin,$PKG);
	close F;

	require XML::Simple;
	my $ref = XML::Simple::XMLin($xmlout, ForceArray=>1, KeyAttr=>[]);
	$CART2->is_debug() && $PKG->pooshmsg("INFO|+HASHES ".Dumper($ref));

	# print Dumper($ref);
	if (not defined $WEBDBREF->{'usps_dom_bulkrate'}) { $WEBDBREF->{'usps_dom_bulkrate'} = 0; }
	if (not defined $WEBDBREF->{'usps_dom_express'}) { $WEBDBREF->{'usps_dom_express'} = 0; }
	if (not defined $WEBDBREF->{'usps_dom_priority'}) { $WEBDBREF->{'usps_dom_priority'} = 0; }

	if ($WEBDBREF->{'usps_dom_bulkrate'} > 0) { }
	elsif ($WEBDBREF->{'usps_dom_express'}  > 0) { }
	elsif ($WEBDBREF->{'usps_dom_priority'} > 0) { }
	elsif ($CART2->is_debug()) {
		$PKG->pooshmsg("INFO|+ERROR: NO SHIPPING METHODS WERE ENABLED.");
		}

	my @USPSMETHODS = ();
	# $methods = {};
	foreach my $pkg (@{$ref->{'Package'}}) {
		my $PKGID = $pkg->{'ID'};
		my %AVAILABLE_CLASSES = ();
		foreach my $postage (@{$pkg->{'Postage'}}) {
			### NOTE: CLASSID is *according to docs* not necessarily unique within a package.
			 #		 {
			 #			  'CLASSID' => '3',
			 #			  'Rate' => [
			 #					'16.55'
			 #					 ],
			 #			  'MailService' => [
			 #					 'Express Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt;'
			 #					  ]
			 #			},
			$AVAILABLE_CLASSES{$postage->{'CLASSID'}} = [ $postage->{'Rate'}->[0], $postage->{'MailService'}->[0] ];
			}

		if ($WEBDBREF->{'usps_dom_bulkrate'}==00) {}
			# 4: Parcel Post&lt;sup&gt;&amp;reg;&lt;/sup&gt
		elsif (defined $AVAILABLE_CLASSES{4}) { 
			# $methods->{"EXPP|U.S.P.S Parcel Post Mail"} = $AVAILABLE_CLASSES{4}->[0]; 
			push @USPSMETHODS, { 'carrier'=>'EXPP', 'name'=>'U.S.P.S Parcel Post Mail', 'amount'=>$AVAILABLE_CLASSES{4}->[0] };
			}
			# 6: Media Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt
			# 7: Library Mail
		else {
			$PKG->pooshmsg('INFO|+No usps_dom_bulkrate method available');
			}

		# print 'AVAILABLE CLASSES: '.Dumper(\%AVAILABLE_CLASSES)."\n";

		if ($WEBDBREF->{'usps_dom_express'}==0) {}
			# 3: Express Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt;
		elsif (defined $AVAILABLE_CLASSES{3}) { 
			# $methods->{"EXPR|U.S.P.S Express Mail"} = $AVAILABLE_CLASSES{3}->[0]; 
			push @USPSMETHODS, { 'carrier'=>'EXPR', 'name'=>'U.S.P.S Express Mail', 'amount'=>$AVAILABLE_CLASSES{3}->[0] };
			}
			# 2: Express Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Hold For Pickup
			# 23: Express Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Sunday/Holiday Delivery
			# 13: Express Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Flat Rate Envelope
			# 27: Express Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Flat Rate Envelope Hold
			# 25: Express Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Sunday/Holiday Delivery
			# 30: Express Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Legal Flat Rate Envelop
			# 31: Express Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Legal Flat Rate Envelop Hold For Pickup
			# 32: Express Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Sunday/Holiday Deliver#
		else {
			$PKG->pooshmsg('INFO|+No usps_dom_express method available');
			}

		if ($WEBDBREF->{'usps_dom_priority'}==0) {}
			# 3: Express Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt;
		elsif (defined $AVAILABLE_CLASSES{1}) { 
			# $methods->{"EPRI|U.S.P.S Priority Mail"} = $AVAILABLE_CLASSES{1}->[0]; 
			push @USPSMETHODS, { 'carrier'=>'EPRI', 'name'=>'U.S.P.S Priority Mail', 'amount'=>$AVAILABLE_CLASSES{1}->[0] };
			}
			# 1: Priority Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt
			# 22: Priority Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Large Flat Rate Box
			# 17: Priority Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Medium Flat Rate Box
			# 28: Priority Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Small Flat Rate Box
			# 16: Priority Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Flat Rate Envelope
			# 44: Priority Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Legal Flat Rate Envelo
			# 29: Priority Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Padded Flat Rate Envel
			# 38: Priority Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Gift Card Flat Rate En
			# 42: Priority Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Small Flat Rate Envelo
			# 40: Priority Mail&lt;sup&gt;&amp;reg;&lt;/sup&gt; Window Flat Rate Envel
		else {
			$PKG->pooshmsg('INFO|+No usps_dom_priority method available');
			}
		}

	# print 'METHODS: '.Dumper($methods);

	#if ($CART2->is_debug()) { 
	#	$PKG->pooshmsg("INFO|+USPS: methods before calc_handling_insurance: ".Dumper()); 
	#	}
	
	## Get the new prices 
	my @OURMETHODS = ();	
	foreach my $shipmethod (@USPSMETHODS) {
		# &ZSHIP::USPS::calc_handling_insurance($WEBDBREF->{'usps_dom_handling'},$WEBDBREF->{'usps_dom_ins'},$WEBDBREF->{'usps_dom_insprice'},$PRICE,$methods);
		push @OURMETHODS, $shipmethod;
		my $amount = $shipmethod->{'amount'};
		$shipmethod->{'id'} = sprintf("USPS-%s",$shipmethod->{'carrier'});

		if ($WEBDBREF->{'usps_dom_handling'}) {
			my ($actual_handling, undef) = &ZOOVY::calc_modifier($amount, $WEBDBREF->{'usps_dom_handling'}, 0);
			$shipmethod->{'amount-before-usps-handling'} = $amount;
			$shipmethod->{'amount'} = $amount = $amount + $actual_handling;
			}

		if (not $WEBDBREF->{'usps_dom_insprice'}) {
			}
		elsif ($WEBDBREF->{'usps_dom_ins'}>1) {
			my ($actual_insurance, undef) = &ZOOVY::calc_modifier($PRICE, $WEBDBREF->{'usps_dom_insprice'}, 0);
			$shipmethod->{'amount-before-usps-handling'} = $amount;
			$shipmethod->{'amount'} = $amount = $amount + $actual_insurance;
			}
		elsif ($WEBDBREF->{'usps_dom_ins'}==1) {
			## Quote both with and without shipping (make another separate insured version)
			my ($actual_insurance, undef) = &ZOOVY::calc_modifier($PRICE, $WEBDBREF->{'usps_dom_insprice'}, 0);
			my %insmethod = %{$shipmethod};
			$insmethod{'amount-before-usps-handling'} = $amount;
			$insmethod{'amount'} = $amount = $amount + $actual_insurance;
			$insmethod{'id'} = sprintf("USPS-%s-INSURED",$insmethod{'carrier'});
			$insmethod{'name'} .= " (insured)";
			push @OURMETHODS, \%insmethod;
			}
		}

	if ($CART2->is_debug()) { 
		$PKG->pooshmsg("INFO|+USPS: methods after calc_handling_insurance: ".Dumper(\@OURMETHODS)); 
		}

	return(\@OURMETHODS);
	}

##
##
##
sub international_compute {
	my ($CART2, $PKG, $WEBDBREF, $INS, $METAREF) = @_;

	my $WEIGHT = $PKG->get('pkg_weight');
	## PER TICKET: 160020 (Toynk) - USPS does not use dimensional weights
	# my $WEIGHT = $PKG->get('pkg_weight_166');
	my $USERNAME = $CART2->username();
	my $PRICE = $PKG->get('items_total');

	# Strip off zip+4 info
	my $DEST_ZIP = $CART2->in_get('ship/postal');
	my $DEST_ISO = $CART2->in_get('ship/countrycode');
	$DEST_ZIP =~ s/^(\d\d\d\d\d).*$/$1/;
	#	my (undef,undef,$DEST_COUNTRY) = &ZSHIP::fetch_country_shipcodes($DEST_COUNTRY);

	if ($DEST_ISO eq '') {
		$CART2->is_debug() && $PKG->pooshmsg("STOP|+USPS DESTINATION ISO is blank (this will be a bumpy ride)"); 
		}
	else {
		$CART2->is_debug() && $PKG->pooshmsg("INFO|+USPS International quote for ISO '$DEST_ISO' ZIP '$DEST_ZIP'");
		}

	if ($WEIGHT == 0) { 
		$CART2->is_debug() && $PKG->pooshmsg("WARN|+USPS International cannot quote weight of zero lbs.");
		return([]); 
		}


	# $DEST_COUNTRY = $CART2->in_get('ship/country');
	my ($info) = &ZSHIP::resolve_country('ISO'=>$DEST_ISO);
	my $DEST_COUNTRY = $info->{'PS'};
	if ($DEST_COUNTRY eq '') {
		$CART2->is_debug() && $PKG->pooshmsg("FAIL|+USPS does not ship to ISO '$DEST_ISO'");
		return([]);
		}

	if (&ZSHIP::USPS::is_really_usps_domestic($DEST_COUNTRY,$DEST_ISO)) {
		$CART2->is_debug() && $PKG->pooshmsg("WARN|+USPS treats Country '$DEST_COUNTRY' ISO '$DEST_ISO' as DOMESTIC (switching modes)");
		return(&ZSHIP::USPS::domestic_compute($CART2,$PKG,$WEBDBREF,$METAREF));
		}

	# $API = 'IntlRateV2';
	my $xmlin = '';
	my $writer = new XML::Writer(OUTPUT => \$xmlin, NEWLINES => 0);

	$writer->startTag("IntlRateV2Request","USERID" => "$ZSHIP::USPS::USERNAME","PASSWORD"=>"$ZSHIP::USPS::PASSWORD");
 	$writer->dataElement("Revision", '2');	## required if we're passing OriginZip (not sure what else this will break)

#	$CONTENT .= build_usps_intpackage("Letters or Letter Packages", 0, $DEST_COUNTRY, $WEIGHT);
	$WEIGHT = &ZSHIP::smart_weight($WEIGHT);
	if ($WEIGHT<1) { $WEIGHT = 1; }
	my $POUNDS = int($WEIGHT / 16);
	my $OZ     = int($WEIGHT % 16);
	if (($POUNDS==0) && ($OZ == 0)) { $OZ = 1; }
	if ( $OZ < 1) { $OZ = 1; }

   $writer->startTag("Package","ID"=>"1");
	$writer->dataElement("Pounds",$POUNDS);
	$writer->dataElement("Ounces",$OZ);
#	$writer->dataElement("Machinable",'True');
	$writer->dataElement("MailType","Package");
	$writer->startTag("GXG");
		$writer->dataElement("POBoxFlag","N");
		$writer->dataElement("GiftFlag","N");
	$writer->endTag();
	$writer->dataElement("ValueOfContents",($INS)?$PRICE:0);
	$writer->dataElement("Country",$DEST_COUNTRY);
	$writer->dataElement("Container","RECTANGULAR");
	# $writer->dataElement("Container","VARIABLE");
	$writer->dataElement("Size","LARGE");
	# $writer->dataElement("Size","REGULAR");
	$writer->dataElement("Width",1);
	$writer->dataElement("Length",1);
	$writer->dataElement("Height",1);
	$writer->dataElement("Girth",0);

	## if we include these parameters the call fails
	my $ORIG_ZIP = defined($WEBDBREF->{'ship_origin_zip'}) ? $WEBDBREF->{'ship_origin_zip'} : '92101';
	my $DEST_ZIP = $CART2->in_get('ship/postal');
	$DEST_ZIP =~ s/^(\d\d\d\d\d).*$/$1/;
	if ($ORIG_ZIP) { $writer->dataElement("OriginZip",$ORIG_ZIP); }
	if ($DEST_ZIP) { 
		## DestinationPostalCode requires AcceptanceDateTime
		# $writer->dataElement("CommercialFlag","Y");
		$writer->dataElement("AcceptanceDateTime", POSIX::strftime("%Y-%m-%dT%H:%M:%S-00:00",localtime()));
		$writer->dataElement("DestinationPostalCode",$DEST_ZIP); 
		}

   $writer->endTag("Package");
	$writer->endTag("IntlRateV2Request");


	my ($xmlout) = &ZSHIP::USPS::api('IntlRateV2',$xmlin);

	open F, ">/dev/shm/usps.xml";
	print F "$xmlin\n\n$xmlout\n";
	close F;
	if ($CART2->is_debug()) {
		$xmlin =~ s/USERID="(.*?)"/USERID="xxxx"/gs;
		$xmlin =~ s/PASSWORD="(.*?)"/PASSWORD="xxxx"/gs;
		$PKG->pooshmsg("API-REQUEST|+$xmlin");
		$PKG->pooshmsg("API-RESPONSE|+$xmlout");
		}

	require XML::Simple;
	my $ref = XML::Simple::XMLin($xmlout, ForceArray=>1, KeyAttr=>[]);

	my @USPSMETHODS = ();
	foreach my $pkg (@{$ref->{'Package'}}) {
		my $PKGID = $pkg->{'ID'};
		my %AVAILABLE_CLASSES = ();
		
		if ($pkg->{'Error'}) {
			foreach my $err (@{$pkg->{'Error'}}) {
				my $src = $err->{'Source'}->[0];
				my $desc = $err->{'Description'}->[0];
				$CART2->is_debug() && $PKG->pooshmsg("FAIL|+USPS API Failure '$src' $desc");
				}
			}

		foreach my $service (@{$pkg->{'Service'}}) {
			my $okay = 0;

			my $ID = $service->{'ID'};

			my %rec = ();
			$rec{'usps_id'} = $ID;
			$rec{'amount'} = $service->{'Postage'}->[0];
			$rec{'delivery'} = $service->{'SvcCommitments'}->[0];
			$rec{'txt'} = $service->{'SvcDescription'}->[0];

			my $name = "USPS: $rec{'txt'} ($rec{'delivery'})";
			$name =~ s/mail//i;
			$name =~ s/[\s]+/ /g;
			$name =~ s/\(single\)//i;

			## 1/2/2011 - USPS added <sup> symbols
			$name =~ s/\<sup\>\&reg\;\<\/sup\>//gs;
			$name =~ s/&lt;sup&gt;&amp;reg;&lt;\/sup&gt;//gs;
			$name =~ s/&lt;sup&gt;&amp;trade;&lt;\/sup&gt;//gs;
			## 8/29/2013
			$name =~ s/\<.*?\>//gs;
			$name =~ s/&lt;.*?&gt;//gs;		# <-- this is possibly the specialist fucking sauce i've seen. 8/29/2013
			
			$name =~ s/[\s]+/ /gs;	#replace multiple spaces with one space
			$rec{'name'} = $name;
			# print STDERR "PRETTY: $name\n";

			# 4 USPS: Global Express Guaranteed (1 - 3 Days)
			# 6 USPS: Global Express Guaranteed Non-Document Rectangular (1 - 3 Days)
			# 7 USPS: Global Express Guaranteed Non-Document Non-Rectangular (1 - 3 Days)
			$okay = 0;
			if (($ID == 4) && ($WEBDBREF->{'usps_int_expressg'}&4)) { $okay++; $rec{'carrier'} = "EGEG"; }
			if (($ID == 6) && ($WEBDBREF->{'usps_int_expressg'}&2)) { $okay++; $rec{'carrier'} = "EGEG"; }
			if (($ID == 7) && ($WEBDBREF->{'usps_int_expressg'}&1)) { $okay++; $rec{'carrier'} = "EGEG"; }
	
			# 1 USPS: Express International (EMS) (5 Days)
			# 10 USPS: Express International (EMS) Flat-Rate Envelope (5 Days)
			if (($ID == 1) && ($WEBDBREF->{'usps_int_express'}&1)) { $okay++; $rec{'carrier'} = 'EIEM'; }
			if (($ID == 10) && ($WEBDBREF->{'usps_int_express'}&2)) { $okay++; $rec{'carrier'} = 'EIEM'; }

			# 2 USPS: Priority International (6 - 10 Days)
			# 8 USPS: Priority International Flat-Rate Envelope (6 - 10 Days)
			# 9 USPS: Priority International Flat-Rate Box (6 - 10 Days)
			# 11 USPS: Priority International Large Flat-Rate Box (6 - 10 Days)
			if (($ID==2) && ($WEBDBREF->{'usps_int_priority'}&1)) { $okay++; $rec{'carrier'} = 'EIPM';  }
			if (($ID==8) && ($WEBDBREF->{'usps_int_priority'}&4)) { $okay++; $rec{'carrier'} = 'EIPM'; }
			if (($ID==9) && ($WEBDBREF->{'usps_int_priority'}&2)) { $okay++; $rec{'carrier'} = 'EIPM'; }
			if (($ID==11) && ($WEBDBREF->{'usps_int_priority'}&2)) { $okay++; $rec{'carrier'} = 'EIPM'; }
	
			# 14 USPS: First Class International Large Envelope (Varies)
			# 15 USPS: First Class International Package (Varies)
			if (($ID==14) && ($WEBDBREF->{'usps_int_parcelpost'}>0)) { 
				## NOTE: there is (currently) no option for parcel post "envelope", but if they only ship in 
				##			"other" box, on the other shipping types, then we won't show it!
				if (($WEBDBREF->{'usps_int_priority'}<=1) && 
					($WEBDBREF->{'usps_int_express'}<=1) && 
					($WEBDBREF->{'usps_int_expressg'}<=1)) {}
				else {
					$rec{'carrier'} = 'ESPP';
					$okay++; 
					}
				}
			if (($ID==15) && ($WEBDBREF->{'usps_int_parcelpost'}>0)) { $okay++; $rec{'carrier'} = 'ESPP'; }

			# 12 USPS: USPS GXG Envelopes (1 - 3 Days)

			if ($okay) { 
				push @USPSMETHODS, \%rec; 
				}
			}		

		}

	## All this section does is check to see if a shipping method is enabled, and if so add it to a new hash
	return \@USPSMETHODS;
	}



##
##
##
sub api {
	my ($API,$xml) = @_;

	my $XMLOUT = '';
	my $FULLURL = $ZSHIP::USPS::URL . "?API=$API&XML=$xml";

	# print "$FULLURL\n";

	# Do LWP Stuff! 
	my $ua = new LWP::UserAgent;
	$ua->agent("Zoovy.com/1.0");
	$ua->timeout(10);
	my $req = new HTTP::Request(GET => $FULLURL);
	my $res = $ua->request($req);
	my $ref = undef;

	# print Dumper($res);ks

	if (not $res->is_success) {
		$XMLOUT = sprintf("<APIError><Code>%d</Code><Msg>%s</Msg></APIError>",$res->code,$res->status_line());
		}
	else {
		$XMLOUT = $res->content();
		if ($XMLOUT eq '') {
			$XMLOUT = sprintf("<APIError><Code>%d</Code><Msg>%s</Msg></APIError>",-1,"Internal error - empty response.");		
			}
		}


	return($XMLOUT);
	}



1;
