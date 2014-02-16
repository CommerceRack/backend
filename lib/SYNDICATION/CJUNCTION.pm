#!/usr/bin/perl

package SYNDICATION::CJUNCTION;

use strict;
use lib "/backend/lib";
use DBINFO;
use ZOOVY;
use NAVCAT;
use NAVCAT::FEED;
use ZTOOLKIT;
use SYNDICATION;
use SITE;


sub new {
	my ($class, $so) = @_;
	my ($self) = {};

	$self->{'_SO'} = $so;
   tie my %s, 'SYNDICATION', THIS=>$so;

	my $USERNAME = $so->username();
	$so->set('.url',sprintf("ftp://%s:%s\@%s%s/$USERNAME.xml",$s{'.user'},$s{'.pass'},$s{'.host'},$s{'.ftp_dir'}));

	bless $self, 'SYNDICATION::CJUNCTION';  
	untie %s;

	return($self);
	}


sub preflight {
	my ($self, $lm) = @_;

   tie my %s, 'SYNDICATION', THIS=>$self->{'_SO'};

	if ($s{'.host'} eq '') {
		$lm->pooshmsg("ERROR|+FTP Server not set. Please check your configuration");
		}
	}


sub header_products {
	my ($self) = @_;

	my $so = $self->{'_SO'};
   tie my %s, 'SYNDICATION', THIS=>$so;

	## get date time		
	my $datetime = &ZTOOLKIT::pretty_date(time(),2);
	$datetime =~ m/(\d\d\d\d)(\d\d)(\d\d) (\d\d):(\d\d):(\d\d)/;
	my $year = $1; my $mon = $2; my $day = $3; my $hour = $4; my $min = $5; my $timeofday = 'AM';
	if ($hour > 12) { $timeofday = 'PM'; $hour = $hour - 12; }
	elsif ($hour == 12) { $timeofday = 'PM'; }
	$datetime = "$mon/$day/$year $hour:$min $timeofday";
	

	my $xml = '';
	$xml .= qq~<?xml version="1.0"?>
<!DOCTYPE product_catalog_data SYSTEM "http://www.cj.com/downloads/tech/dtd/product_catalog_data_1_1.dtd">
<product_catalog_data>
<header>
<cid>$s{'.cjcid'}</cid>
<subid>$s{'.cjsubid'}</subid>
~;
## CJ wants the format of the date, not the actual date
#<!-- <datefmt>$datetime</datefmt> -->
    $xml .= qq~<datefmt>MM/DD/YYYY HH12:MI PM</datefmt>
<processtype>OVERWRITE</processtype>
<aid>$s{'.cjaid'}</aid>
</header>
~;
	$xml .= "<!-- File generated ".&ZTOOLKIT::pretty_date(time(),1)." -->\n";

	return($xml);
	}

sub so { return($_[0]->{'_SO'}); }



##
## 
##
sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	my $ERROR = undef;

	if ($OVERRIDES->{'parent:keywords'} ne '') {
		## this is fine, we'll get them from the parent
		}
	elsif ($P->fetch('zoovy:keywords') eq '') {
		$plm->pooshmsg("VALIDATION|+ATTRIB=zoovy:keywords|+zoovy:keywords is a required field and is blank");
		}

	return();
	}


##
##
##  
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	## check current inventory using inv and reserve values
	if (defined $P->fetch('cj:inventory')) {
		# already set in product (how bizarre)
		}
	elsif ($OVERRIDES->{'zoovy:qty_instock'} > 0) { 
		$OVERRIDES->{'%INSTOCK'} = 'yes'; 
		}
	else {
		$OVERRIDES->{'%INSTOCK'} = 'no';
		}

	$OVERRIDES->{'%BUYURL'} = $OVERRIDES->{'zoovy:link2'};

	my $so = $self->{'_SO'};
	my $c = '';

	## Step 1: figure out the category
	my $CATEGORY = undef; 
	if ((not defined $CATEGORY) && ($P->fetch('cj:category') ne '')) { $CATEGORY = $P->fetch('cj:category'); }
	if ((not defined $CATEGORY) && ($OVERRIDES->{'cj:category'} ne '')) { $CATEGORY = $OVERRIDES->{'cj:category'}; }
	if ((not defined $CATEGORY) && ($OVERRIDES->{'navcat:meta'} ne '')) { $CATEGORY = $OVERRIDES->{'navcat:meta'}; }

	if ($CATEGORY eq '') { 
		$plm->pooshmsg("ERROR|+Both navcat and cj:category CATEGORY are blank");
		return(""); 
		}

	$OVERRIDES->{'%CATEGORY'} = $CATEGORY;
	$OVERRIDES->{'%SKU'} = $SKU;

	my @keys = (
#<name>70-300mm f/4-5.6 APO Macro Super for Nikon AF</name>
#<keywords>Lense,Optics,Sigma</keywords>
#<description>Sigma&apos;s 70-300mm F4-5.6 APO MACRO SUPER is a compact Apochromatic tele
#zoom lens incorporating two Special Low Dispersion glass elements in the front lens group, plus one
#Special Low Dispersion glass element in the rear lens group, to minimize chromatic
#aberration.</description>
#<sku>0-85126-50444-1</sku>
		[ 'name', 'zoovy:prod_name', 1, 1 ],
		[ 'keywords', 'cj:keywords,zoovy:keywords,zoovy:prod_name', 1, 1 ],
		[ 'description', 'zoovy:prod_desc,zoovy:prod_name', 1, 1 ],
		[ 'sku', '%SKU', 0, 1 ],
#<buyurl>http://www.tors-cameras.com/shop/product.asp?id=0-85126-50444-1</buyurl>
#<available>Yes</available>
#<imageurl>http://www.tors-cameras.com/images/0-85126-50444-1.gif</imageurl>
#<price>289.95</price>
#<retailprice>612.00</retailprice>
#<saleprice>249.95</saleprice>
#<currency>USD</currency>
		[ 'buyurl', '%BUYURL', 0, 1 ],
		[ 'available', '%INSTOCK', 0, 1 ],
		[ 'imageurl', 'zoovy:prod_thumb,zoovy:prod_image1', 2+8, 0],
		[ 'price', 'zoovy:base_price', 4, 1 ],
		[ 'retailprice', 'zoovy:prod_msrp', 4, 0 ],
		[ 'saleprice', 'zoovy:base_price', 4, 0 ],
		[ 'currency', 'USD', 0, 1 ],
#<upc>085126504441</upc>
#<promotionaltext>Free shipping for a limited time</promotionaltext>
#<advertisercategory>Lenses</advertisercategory>
#<manufacturer>Sigma</manufacturer>
#<manufacturerid>504306</manufacturerid>
#<special>Yes</special>
#<thirdpartyid>546sdzo</thirdpartyid>
#<thirdpartycategory>Camera</thirdpartycategory>
#<offline>Yes</offline>
#<online>Yes</online>
		[ 'upc', 'zoovy:prod_upc' ],
		[ 'promotionaltext', 'zoovy:prod_title' ],
		[ 'advertisercategory', '%CATEGORY' ],
		[ 'manufacturer', 'zoovy:prod_mfg' ],
		[ 'manufacturerid', 'zoovy:prod_mfgid' ],
#<startdate>04/01/2003 12:00 AM</startdate>
#<enddate>05/01/2003 12:00 AM</enddate>
#<instock>Yes</instock>
#<condition>New</condition>
#<warranty>1 year parts and labor</warranty>
      [ 'instock', 'cj:inventory' ],
		[ 'condition', 'zoovy:prod_condition'],
		[ 'warranty', 'zoovy:prod_warranty' ],
#<standardshippingcost>7.59</standardshippingcost>

		## Merchandise Type/ Product List Defns
		## A product list is created (on CJ) and given the name "MiscItems", and a product in
		## the merchant's catalog with SKU ABC1234 is then given a cj:merchandisetype of "MiscItems".
		## The SKU for that product will be used in their item-based pixel calls - if they
		## send SKU ABC1234 in the pixel, our system will look for an entry in their
		## catalog with the exact same SKU. It looks at the MERCHANDISETYPE and if the publisher
		## is in a program term with that item list it will pay the proper amount. If the
		## system cannot find the SKU or item list, etc, it pays at the default rate.

		## Important Notes on item lists:
		## - To avoid encoding issues, use only alphanumeric SKUs or list names with
		## dashes or underscores. 
		## - Remember that all values must match exactly and are case sensitive. 
		## - If the SKU is not present in our system at the time the pixel fires, it will
		## pay out the default rate. 
		[ 'merchandisetype', 'cj:merchandisetype' ],
		
		);
	
	my $xml = '';	
	foreach my $set (@keys) {	
		my $val = undef;
		foreach my $attrib (split(/,/, $set->[1])) {
			next if (defined $val);
			if (defined $OVERRIDES->{$attrib}) {
				$val = $OVERRIDES->{$attrib};
				}
			else {
				$val = $P->fetch($attrib);
				}

			if ((defined $val) && ($val eq '') && ($set->[2] & 8)) {
				## 8 = require non-blank
				$val = undef;
				}
			}

		if (($set->[3] & 1)==1) { 
			## position 3 means required field
			if (not defined $val) { $val = ""; }
			}

		if (defined $val) {
			if ($set->[2] & 1) {
				## strip bad values
				$val = SYNDICATION::declaw($val);
				}

			if ($set->[2] & 2) {
				## format into image url
				$val = sprintf("http://%s/media/img/%s/-/%s",&ZOOVY::resolve_media_host($so->username()),$so->username(),$val);
				}
			if ($set->[2] & 4) {
				## format into number/currency
				$val = sprintf("%.2f",$val);
				}
				
			$xml .= sprintf("<%s>%s</%s>\n",$set->[0],&ZOOVY::incode($val),$set->[0]);
			}
		
		}
		
	if ($xml) {
		$xml = "<product>\n$xml</product>\n";
		}
		
	return($xml);
	}
  
##
##
sub footer_products {
  my ($self) = @_;
	my $xml = "</product_catalog_data>\n";
  return($xml);
  }


1;
