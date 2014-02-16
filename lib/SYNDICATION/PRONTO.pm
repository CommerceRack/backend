#!/usr/bin/perl

package SYNDICATION::PRONTO;


##
## this creatse a csv file for pricegrabber.. liz will need to change this for THEFIND.
##


use strict;
use lib "/backend/lib";
use DBINFO;
use ZOOVY;
use NAVCAT;
use NAVCAT::FEED;
use ZSHIP;
use ZTOOLKIT;
use SYNDICATION;
use SITE;
use LWP::UserAgent;
use Net::FTP;
use LWP::Simple;
use Data::Dumper;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );


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

	# my $ftp_file = $s{'.ftp_file'};
	#if ($ftp_file eq '') { $ftp_file = '

	## according to feed file: yourdomain.com.txt or simply yourdomain.txt (it's unclear)
	my $ftp_file = sprintf("%s.txt",$so->domain());

	$so->set('.url',sprintf("ftp://%s:%s\@%s/%s/%s",$s{'.ftp_user'},$s{'.ftp_pass'},$s{'.ftp_server'},$s{'.ftp_dir'},$ftp_file));
	## don't worry about this line -- *YET* .. it creates an object but you don't need to understand it.
	bless $self, 'SYNDICATION::PRONTO';  
	untie %s;

	return($self);
	}


##
## this creates the header row. 
##
sub header_products {
	my ($self) = @_;

	$self->{'_csv'} = Text::CSV_XS->new({binary=>1,sep_char=>"\t"});              # create a new object
	my $csv = $self->{'_csv'};

	# https://merchant.pronto.com/html/Product_Listings_Data_Feed_Specifications.pdf

	my @columns = ();

	push @columns, "Title"; 	# [required]: the title of the product for sale
	push @columns, "SalePrice"; 	# [required]: the price for which the product is currently selling, in US dollars
	push @columns, "URL"; 	# [required]: the URL to a product detail page for which a user can effect a purchase
	push @columns, "Description"; 	# [required]: a detailed description of the product
	push @columns, "Category"; 	# [required]: a category label like 'Books' or 'Apparel > Women's > Coats'. Any categorization the merchant may already use themselves (greatest level of detail, like site breadcrumbs, is most helpful)
	push @columns, "ImageURL"; 	# [required for all merchants that display an image on their website]: a single URL to an image of the product. This is a required field for all merchant products for which an image is displayed an image on the merchant website
	push @columns, "Condition"; 	# [required for all products that are not of .new. condition]: the condition of the product. If the product is new, this field should be left blank or marked as .new.. *Please note: Pronto does not currently display products that are marked in this condition field as .used. or .refurb..
	push @columns, "Brand"; 	# [recommended]: the brand (or manufacturer) of the product
	push @columns, "Keywords"; 	# [recommended]: .search engine. type keywords that describe the product
	push @columns, "ISBN"; 	# [optional, recommended for all books]: Code, for books only
	push @columns, "ArtistAuthor"; 	# [optional, recommended for all books]: Artist or Author.s name, for books or music only
	push @columns, "ProductSKU"; 	# [highly recommended]: unique product identifier, such as Universal Product Code (UPC), Manufacturer Parts Number (MPN), or Manufacturer Model Number (MMN)
	push @columns, "Outlet"; 	# [optional]: designation of the product as offered via the retailer.s outlet distribution. Leave blank for all non-outlet products
	push @columns, "InStock"; 	# [required for all products .out of stock.]: designation of whether the product is currently available in inventory
	push @columns, "ShippingCost"; 	# [optional]: flat shipping cost for the item. Should represent the lowest cost a buyer would have to pay for shipping for that product only, in US dollars
	push @columns, "ShippingWeight"; 	# [optional]: weight of the item to be shipped, in pounds
	push @columns, "ZipCode"; 	# [optional]: zip code from which the item is shipped
	push @columns, "ProntoCategoryID"; 	# [highly recommended]: 1 to 3 digit number that represents the specific sub-category where the product fits within Pronto.s categorization schema. Use the Pronto Category Mapping document to obtain these numbers
	push @columns, "Other"; 	# [optional]: field not currently in use; no value should be supplied but column should remain
	push @columns, "ProductBid"; 	# [optional]: the cost-per-click bid price to be used for the product, in US dollars.
	push @columns, "RetailPrice"; 	# [optional]: the normal retail list price for the product (if different than the sales price), in US dollars
	push @columns, "SpecialOffer"; 	# [optional]: a specific offer provided for the product

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
	## Step 1: figure out the category

	#push @columns, "Title"; 	# [required]: the title of the product for sale
	if ($P->fetch('pronto:prod_name') ne '') {
		push @columns, $P->fetch('pronto:prod_name');
		}
	else {
		push @columns, $P->fetch('zoovy:prod_name');
		}

	#push @columns, "SalePrice"; 	# [required]: the price for which the product is currently selling, in US dollars
	push @columns, sprintf("%.2f",$P->skufetch($SKU,'zoovy:base_price'));

	#push @columns, "URL"; 	# [required]: the URL to a product detail page for which a user can effect a purchase
	my $URL = $OVERRIDES->{'zoovy:link2'}; 
	push @columns, "$URL";

	#push @columns, "Description"; 	# [required]: a detailed description of the product
	push @columns, &SYNDICATION::declaw($P->fetch('zoovy:prod_desc'));

	#push @columns, "Category"; 	# [required]: a category label like 'Books' or 'Apparel > Women's > Coats'. Any categorization the merchant may already use themselves (greatest level of detail, like site breadcrumbs, is most helpful)
	push @columns, $OVERRIDES->{'navcat:bc'};

	#push @columns, "ImageURL"; 	# [required for all merchants that display an image on their website]: a single URL to an image of the product. This is a required field for all merchant products for which an image is displayed an image on the merchant website
	if ($P->thumbnail($SKU)) { 
		push @columns, &ZOOVY::mediahost_imageurl($self->so->username(),$P->thumbnail($SKU),0,0,'FFFFFF',0,'jpg'); 
		}
	else {
		push @columns, "";
		}

	#push @columns, "Condition"; 	# [required for all products that are not of .new. condition]: the condition of the product. If the product is new, this field should be left blank or marked as .new.. *Please note: Pronto does not currently display products that are marked in this condition field as .used. or .refurb..
	my $condition = $P->fetch('yshop:prod_condition');
	if ($condition eq '') { $condition = $P->fetch('zoovy:prod_condition'); }
	if (not defined $condition) { $condition = ''; }
	push @columns, $condition;

	#push @columns, "Brand"; 	# [recommended]: the brand (or manufacturer) of the product
	push @columns, $P->fetch('zoovy:prod_manufacturer');

	#push @columns, "Keywords"; 	# [recommended]: .search engine. type keywords that describe the product
	push @columns, $P->fetch('zoovy:prod_keywords');

	#push @columns, "ISBN"; 	# [optional, recommended for all books]: Code, for books only
	push @columns, $P->fetch('zoovy:prod_isbn');

	#push @columns, "ArtistAuthor"; 	# [optional, recommended for all books]: Artist or Author.s name, for books or music only
	if ($P->fetch('zoovy:catalog') eq 'BOOK') {
		push @columns, $P->fetch('zoovy:prod_author');
		}
	else {
		push @columns, "";
		}
	
	#push @columns, "ProductSKU"; 	# [highly recommended]: unique product identifier, such as Universal Product Code (UPC), Manufacturer Parts Number (MPN), or Manufacturer Model Number (MMN)
	push @columns, uc($SKU);

	#push @columns, "Outlet"; 	# [optional]: designation of the product as offered via the retailer.s outlet distribution. Leave blank for all non-outlet products
	push @columns, "";

	#push @columns, "InStock"; 	# [required for all products .out of stock.]: designation of whether the product is currently available in inventory
	# push @columns, $P->fetch('zoovy:qty_instock');
	push @columns, "Y";

	#push @columns, "ShippingCost"; 	# [optional]: flat shipping cost for the item. Should represent the lowest cost a buyer would have to pay for shipping for that product only, in US dollars
	push @columns, $P->fetch('zoovy:ship_cost1');

	#push @columns, "ShippingWeight"; 	# [optional]: weight of the item to be shipped, in pounds
	push @columns, &ZSHIP::smart_weight($P->fetch('zoovy:base_weight'));

	#push @columns, "ZipCode"; 	# [optional]: zip code from which the item is shipped
	push @columns, "";

	#push @columns, "ProntoCategoryID"; 	# [highly recommended]: 1 to 3 digit number that represents the specific sub-category where the product fits within Pronto.s categorization schema. Use the Pronto Category Mapping document to obtain these numbers
	my $CATEGORY = '';
	if ((defined $P->fetch('pronto:category')) && ($P->fetch('pronto:category') ne '')) {
		$CATEGORY = $P->fetch('pronto:category');
		}
	elsif ($OVERRIDES->{'navcat:meta'} ne '') {
		$CATEGORY = $OVERRIDES->{'navcat:meta'};
		}
	# if ($CATEGORY eq '') { return(); }
	push @columns, $CATEGORY;

	#push @columns, "Other"; 	# [optional]: field not currently in use; no value should be supplied but column should remain
	push @columns, "";

	#push @columns, "ProductBid"; 	# [optional]: the cost-per-click bid price to be used for the product, in US dollars.
	push @columns, "";

	#push @columns, "RetailPrice"; 	# [optional]: the normal retail list price for the product (if different than the sales price), in US dollars
	push @columns, "";

	#push @columns, "SpecialOffer"; 	# [optional]: a specific offer provided for the product
	push @columns, "";

	my $status = $csv->combine(@columns);    # combine columns into a string
	my $line = $csv->string();               # get the combined string

	if ($line eq '') {
	  use Data::Dumper;
		print Dumper(\@columns);
		die();
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
