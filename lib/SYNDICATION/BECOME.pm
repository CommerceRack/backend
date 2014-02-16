#!/usr/bin/perl

package SYNDICATION::BECOME;


##
## this creatse a csv file for 
##	https://merchants.become.com/datafeed.html
##


use strict;
use lib "/backend/lib";
use DBINFO;
use ZOOVY;
use NAVCAT;
use NAVCAT::FEED;
use ZTOOLKIT;
use Data::Dumper;


##
## creates a new SYNDICATION::THEFIND object 
##		$so is the SYNDICATION object which created it (the parent)
sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;

   tie my %s, 'SYNDICATION', THIS=>$so;
	
	if ($s{'.ftp_server'} =~ /^ftp\:\/\//i) { $s{'.ftp_server'} = substr($s{'.ftp_server'},6); }
	#if ($s{'.ftp_server'} !~ /yahoo\.com$/) {
	#	$ERROR = 'FTP Server must end in .yahoo.com'; 
	#	}

	## how do we send the data to the find?  .. the actual data transfer happens in $so -- but when we create
	##	our object we need to tell $so how/where it's going to send the file to thefind. 

	$so->set('.url',sprintf("ftp://%s:%s\@%s/%s/data.txt",$s{'.ftp_user'},$s{'.ftp_pass'},$s{'.ftp_server'},$s{'.ftp_dir'}));
	## don't worry about this line -- *YET* .. it creates an object but you don't need to understand it.
	bless $self, 'SYNDICATION::BECOME';  
	untie %s;

	require SYNDICATION::CATEGORIES;
	$self->{'%CATEGORIES'} = SYNDICATION::CATEGORIES::CDSasHASH("BCM",">");

	return($self);
	}

@SYNDICATION::BECOME::ATTRIBS = (
	'zoovy:prod_image1',
	'zoovy:prod_thumb',
	'zoovy:prod_desc',
	'zoovy:prod_name',
	'become:category',
	'zoovy:prod_isbn',
	'zoovy:prod_asin',
	'zoovy:prod_upc',
	'zoovy:prod_mfgid',
	'zoovy:prod_mfg',
	'zoovy:prod_name',
	'zoovy:prod_desc',
	'zoovy:prod_condition',
	'become:is_hot',
	'zoovy:ship_cost1',
	'zoovy:base_weight',
	'zoovy:prod_keywords',
	'zoovy:prod_msrp',
	);


sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	my $ERROR = undef;
	my %valid =  ();
	foreach my $k (@SYNDICATION::BECOME::ATTRIBS) {
		my $val = $P->fetch($k);
		$val =~ s/<java.*?>.*?<\/java.*?>//gis;
		$val =~ s/<script.*?<\/script>//gis;

		## strip out advanced wikitext (%softbreak%, %hardbreak%)
		$val =~ s/%\w+%//gs;

		$val =~ s/<.*?>//gs;
		$val =~ s/[\t]+/ /g;
		$val =~ s/[^\"\w\.\:\:\!\@\#\$\%\^\&\*\(\)]+/ /g;
		$val =~ s/[\n\r]+//gs;		
		$valid{$k} = $val;
		}
		
	if ($valid{'zoovy:prod_image1'} eq '') { $valid{'zoovy:prod_image1'} = $valid{'zoovy:prod_thumb'}; }

	#if ($valid{'zoovy:prod_image1'} eq '') { 
	#	$ERROR = "{zoovy:prod_image1}product image (BECOME Image_Link) is not specified";
	#	}
	if ($valid{'zoovy:prod_desc'} eq '') {
		$plm->pooshmsg("VALIDATION|ATTRIB=zoovy:prod_desc|+product description is required");
		}
	elsif ($valid{'zoovy:prod_name'} eq '') {
		$plm->pooshmsg("VALIDATION|ATTRIB=zoovy:prod_name|+product name is required");
		}
	
	if (defined $valid{'become:category'}) {
		if (not defined $self->{'%CATEGORIES'}->{  $valid{'become:category'} }) {
			$plm->pooshmsg("VALIDATION|ATTRIB=become:category|+BECOME category[$valid{'become:category'}] (set in product) is not a valid category # for become");
			}
		}

	return();
	}


##
## this creates the header row. 
##
sub header_products {
	my ($self) = @_;

	$self->{'_csv'} = Text::CSV_XS->new({binary=>1,sep_char=>"\t"});              # create a new object
	my $csv = $self->{'_csv'};

	my @columns = ();

	## Unique Identifier
	## ISBN: A 10 or 13 digit unique identifier associated with books. Omit dashes
	push @columns, "ISBN";
	## ASIN: A 10 digit alphanumeric Amazon stock number for this product	
	push @columns, "ASIN";
	## UPC: A UPC (Universal Product Code) is a 12 digit unique identifier that lets us match your products to existing ones in our catalog; this allows us to correctly list your products on the site and optimize your exposure.
	push @columns, "UPC";
	## Mft Part: The manufacturer part number is used together with the manufacturer to accurately identify the product and match it with our existing database (similar to UPC).
	push @columns, "Mft Part #";
	## Manufacturer: The manufacturer name or brand of the product. This is used in conjunction with the manufacturer part number.	
	push @columns, "Manufacturer";
	
	## Product URL: This URL must take the user directly to the product page on your site for the advertised item. Tracking URLs are acceptable, though we also offer tracking information through the merchant dashboard (please sign into your account for more information). URLs must begin with http://
	push @columns, "Product URL";
	## Product Title: The product name should be clear and concise. Maximum length is 80 characters. No HTML and no promotional text is permitted.
	push @columns, "Product Title";
	## Price: The current price the item is being sold for. Do not include a dollar sign ($) or USD
	push @columns, "Price";

	## Recommended
	## Product Descriptions: A short description of the product, maximum 250 characters. It is highly recommended, since good descriptions will optimize your products' exposure on the site.
	push @columns, "Product Descriptions";
	## ex: This 100% cotton polo from Hanes is a great shirt for all occasions. Faded for a more comfortable look.

	## Category: It is highly recommended that you categorize your products as close to our taxonomy to ensure the most accurate results.  Home & Garden > Kitchen > Cookware
	push @columns, "Category";

	## Image URL: Minimum recommended picture size is 100x100 pixels. We accept both .GIF and .JPG formats. We do not allow any embedded information in the picture, such as merchant phone number or logo
	## http://www.yoursite.com/image123.jpg
	push @columns, "Image URL";
	
	## Promotional Text: A message visible to users, noting special offers or information. 30 character max. More information available at https://merchants.become.com/promoText.html  Free Shipping for Orders Over $20 
	push @columns, "Promotional Text";

	## Condition: New, Used, Refurbished. If it's not provided, the products are assumed to be new. Refurbished
	push @columns, "Condition";
	## Stock Status: Denotes if a product is available or not (ex: In Stock / Out of Stock)
	push @columns, "Stock Status";

	# Optional: 
	## Shipping Price: The cost of shipping anywhere in the Continental US. Use '0' or 'free' to denote free shipping. Do not use a dollar sign ($). ex: 7.99
	push @columns, "Shipping Price";
	## Shipping Weight: The weight, in pounds, of the product. Numerical values only, do not include "lbs" 1.5
	push @columns, "Shipping Weight";
	

	## Bid Price: This is the CPC you would like to be charged for the item. Bids can be entered by category in the dashboard, but bids provided in the feed will override those entered through the dashboard. If no bid is entered your product will list at the category minimum rate. ex: 0.35
	push @columns, "Bid Price";
	## Keywords: Brief, relevant keywords or search terms for the specific item (separated by ";"). Helps us optimize your listings' exposure. ex: rims; wheels; car rims
	push @columns, "Keywords";
	## Attributes: Add a collection of attributes (height, width, gigabyte, voltage) not available in the title or description of the product 32" lcd tv
	push @columns, "Attributes";
	## MSRP: Manufacturer Suggested Retail Price. 199.95
	push @columns, "MSRP";

	my $status = $csv->combine(@columns);    # combine columns into a string
	my $line = $csv->string();               # get the combined string

	return($line."\n");
	}

## 
## a quick and dirty sub to our parent.
##		so we can go $self->so()->____  where ___ is a function in SYNDICATION.pm such as "addLog"
##
sub so { return($_[0]->{'_SO'}); }


##
## this function is called by our parent $self->so() once per product
##	 it's job is to create a line per product, or return blank if no line should be created.
##  
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my $csv = $self->{'_csv'};
	
	my @columns = ();

	## Unique Identifier
	## ISBN: A 10 or 13 digit unique identifier associated with books. Omit dashes
	push @columns, $P->skufetch($SKU,'zoovy:prod_isbn');

	## ASIN: A 10 digit alphanumeric Amazon stock number for this product	
	push @columns, $P->skufetch($SKU,'amz:asin');

	## UPC: A UPC (Universal Product Code) is a 12 digit unique identifier that lets us match your products to existing ones in our catalog; this allows us to correctly list your products on the site and optimize your exposure.
	push @columns, $P->skufetch($SKU,'zoovy:prod_upc');

	## Mft Part: The manufacturer part number is used together with the manufacturer to accurately identify the product and match it with our existing database (similar to UPC).
	push @columns, $P->skufetch($SKU,'zoovy:prod_mfgid');

	## Manufacturer: The manufacturer name or brand of the product. This is used in conjunction with the manufacturer part number.	
	push @columns, $P->skufetch($SKU,'zoovy:prod_mfg');
	
	## Product URL: This URL must take the user directly to the product page on your site for the advertised item. Tracking URLs are acceptable, though we also offer tracking information through the merchant dashboard (please sign into your account for more information). URLs must begin with http://
	push @columns, $OVERRIDES->{'zoovy:link2'};

	## Product Title: The product name should be clear and concise. Maximum length is 80 characters. No HTML and no promotional text is permitted.
	if ($OVERRIDES->{'zoovy:sku_name'}) {
		push @columns, $OVERRIDES->{'zoovy:sku_name'};
		}
	else {
		push @columns, $P->fetch('zoovy:prod_name');
		}

	## Price: The current price the item is being sold for. Do not include a dollar sign ($) or USD
	if ($OVERRIDES->{'zoovy:base_price'}) {
		push @columns, sprintf("%.2f",$OVERRIDES->{'zoovy:base_price'});		
		}
	else {
		push @columns, sprintf("%.2f",$P->fetch('zoovy:base_price'));
		}

	## Recommended
	## Product Descriptions: A short description of the product, maximum 250 characters. It is highly recommended, since good descriptions will optimize your products' exposure on the site.
	push @columns, SYNDICATION::declaw($P->fetch('zoovy:prod_desc'));

	## ex: This 100% cotton polo from Hanes is a great shirt for all occasions. Faded for a more comfortable look.

	## Category: It is highly recommended that you categorize your products as close to our taxonomy to ensure the most accurate results.  Home & Garden > Kitchen > Cookware
	if (defined $P->fetch('become:category')) {
		push @columns, $self->{'%CATEGORIES'}->{ $P->fetch('become:category') };
		}
	else {
		## does a lookup based on the category the product is in.
		push @columns, $self->{'%CATEGORIES'}->{ $OVERRIDES->{'navcat:meta'} };
		}

	## Image URL: Minimum recommended picture size is 100x100 pixels. We accept both .GIF and .JPG formats. We do not allow any embedded information in the picture, such as merchant phone number or logo
	## http://www.yoursite.com/image123.jpg
	if ($P->fetch('zoovy:prod_image1')) { 
		push @columns, &ZOOVY::mediahost_imageurl($self->so->username(),$P->fetch('zoovy:prod_image1'),0,0,'FFFFFF',0,'jpg'); 
		}
	else {
		push @columns, "";
		}
	
	## Promotional Text: A message visible to users, noting special offers or information. 30 character max. More information available at https://merchants.become.com/promoText.html  Free Shipping for Orders Over $20 
	push @columns, "";

	## Condition: New, Used, Refurbished. If it's not provided, the products are assumed to be new. Refurbished
	push @columns, $P->fetch('zoovy:prod_condition');

	## Stock Status: Denotes if a product is available or not (ex: In Stock / Out of Stock)
	## sending 'Hot' instead makes the product appear higher in a search - limited to 100 products

	## REVIEW - need to discuss code with patti or brian. hot attribute to be determined.  
	my $hot_count = 0;
	if (($hot_count < 100) && (int($P->fetch('become:is_hot')) == 1) && ($OVERRIDES->{'zoovy:qty_instock'} > 0)) {
		push @columns, 'Hot';
		$hot_count ++;
		}
	elsif ($OVERRIDES->{'zoovy:qty_instock'} > 0) {
		push @columns, 'In Stock';
		}
	else {
		push @columns, 'Out of Stock';
		}


#	my $hot_count = 0;
#	if ($prodref->{'zoovy:qty_instock'} > 0) {
#		if (($hot_count < 100) && (int($P->fetch('become:is_hot')) == 1)) {
#			push @columns, 'Hot';
#			$hot_count ++;
#			}
#		else {
#			push @columns, 'In Stock';
#			}
#	else {
#		push @columns, 'Out of Stock';
#		}
		


	# Optional: 
	## Shipping Price: The cost of shipping anywhere in the Continental US. Use '0' or 'free' to denote free shipping. Do not use a dollar sign ($). ex: 7.99
	push @columns, $P->fetch('zoovy:ship_cost1');

	## Shipping Weight: The weight, in pounds, of the product. Numerical values only, do not include "lbs" 1.5
	push @columns, &ZSHIP::smart_weight($P->fetch('zoovy:base_weight'));
	

	## Bid Price: This is the CPC you would like to be charged for the item. Bids can be entered by category in the dashboard, but bids provided in the feed will override those entered through the dashboard. If no bid is entered your product will list at the category minimum rate. ex: 0.35
	push @columns, '';

	## Keywords: Brief, relevant keywords or search terms for the specific item (separated by ";"). Helps us optimize your listings' exposure. ex: rims; wheels; car rims
	push @columns, $P->fetch('zoovy:prod_keywords');

	## Attributes: Add a collection of attributes (height, width, gigabyte, voltage) not available in the title or description of the product 32" lcd tv
	push @columns, '';

	## MSRP: Manufacturer Suggested Retail Price. 199.95
	push @columns, $P->skufetch($SKU,'zoovy:prod_msrp');

	my $status = $csv->combine(@columns);    # combine columns into a string
	my $line = $csv->string();               # get the combined string

	if ($line eq '') {
	  use Data::Dumper;
	 #  print Dumper(\@columns);
	  }

	return($line."\n");
	}
  


##
## this generates a footer, it's called by $so after all the products are done.
##  since csv files don't have footers (but XML files do) it can probably output blank.. unless it's xml
## then it should return </endtag> or whatever the ending is. 
sub footer_products {
  my ($self) = @_;
  return("");
  }


1;
