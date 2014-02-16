#!/usr/bin/perl

## 88101

package SYNDICATION::SHAREASALE;

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


sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;

   tie my %s, 'SYNDICATION', THIS=>$so;
	
	$so->set('.url',sprintf("site://shareasale-%s.txt",$so->domain()));
	bless $self, 'SYNDICATION::SHAREASALE';  
	untie %s;

	return($self);
	}

sub header_products {
	my ($self) = @_;

	$self->{'_csv'} = Text::CSV_XS->new({binary=>1,sep_char=>","});              # create a new object
	my $csv = $self->{'_csv'};

	# http://static.zoovy.com/merchant/froggysfog/TICKET_187764-YahooFieldNameDetails.pdf
	my @columns = ();

#1	SKU	Text	255 characters	No	Mandatory Unique Value
	push @columns, "SKU";
#2	Name	Text	255 characters	Yes	Product Name
	push @columns, "Name";
#3	URL	URL	255 characters	No	Direct URL to the product
	push @columns, "URL";
#4	Price	Numeric	2 decimal places	No	Product Price
	push @columns, "Price";
#5	RetailPrice	Numeric	2 decimal places	Yes	"Retail" or "List" price
	push @columns, "RetailPrice";
#6	FullImage	URL	255 characters	Yes	URL to product full size image
	push @columns, "FullImage";
#7	ThumbnailImage	URL	255 characters	Yes	URL to product thumbnail image
	push @columns, "ThumbnailImage";
#8	Commission	Float	
	push @columns, "Commission";
#	Yes	Dollar amount of product commission (do not enter in a commission percentage). This will not affect the tracking or the actual commission rewarded on the sale, and is only for a quick reference for the affiliate.
#9	Category	Integer	
	push @columns, "Category";
#	No	Product Category - see ShareASale defined category numbers below
#10	Subcategory	Integer	
	push @columns, "Subcategory";
#	No	Product Subcategory - see ShareASale defined subcategory numbers below
#11	Description	Text	No character limit	Yes	Product Description
	push @columns, "Description";
#12	SearchTerms	Text	255 characters	Yes	Comma separated list of product search terms
	push @columns, "SearchTerms";
#13	Status	Text	50 characters	Yes	Stock Status.
	push @columns, "Status";
#    * instock - Indicates an In Stock item
#    * backorder - Indicates an item on backorder
#    * cancelled - Indicates an item no longer offered
#    * soldout - Indicates an item that is sold out. 
#14	MerchantID	Integer	
	push @columns, "MerchantID";
#-
#	No	Your ShareASale MerchantID is 7867
#15	Custom1	Text	255 characters	Yes	Any extra data you would like to add.
	push @columns, "Custom1";
#16	Custom2	Text	255 characters	Yes	Any extra data you would like to add.
	push @columns, "Custom2";
#17	Custom3	Text	255 characters	Yes	Any extra data you would like to add.
	push @columns, "Custom3";
#18	Custom4	Text	255 characters	Yes	Any extra data you would like to add.
	push @columns, "Custom4";
#19	Custom5	Text	255 characters	Yes	Any extra data you would like to add.
	push @columns, "Custom5";
#20	Manufacturer	Text	255 characters	Yes	Product Manufacturer
	push @columns, "Manufacturer";
#21	PartNumber	Text	255 characters	Yes	This should be a manufacturer provided value that uniquely identifies this product. This could be a model number, part number, etc. Typically, this field is used by affiliates to price match an item across multiple merchants.
	push @columns, "PartNumber";
#22	MerchantCategory	Text	255 characters	Yes	This is your category for the product.
	push @columns, "MerchantCategory";
#23	MerchantSubcategory	Text	255 characters	Yes	This is your subcategory for the product.
	push @columns, "MerchantSubcategory";
#24	ShortDescription	Text	255 characters	Yes	This is a short text only description of this product. Do not include any HTML markup in this field.
	push @columns, "ShortDescription";
#25	ISBN	Text	25 characters	Yes	ISBN for this product, if applicable.
	push @columns, "ISBN";
#26	UPC	Text	25 characters	Yes	UPC for this product, if applicable.
	push @columns, "UPC";
#27	CrossSell	Text	255 characters	Yes	Comma separated list of SKU values that cross sell with the product.
	push @columns, "CrossSell";
#28	MerchantGroup	Text	255 characters	Yes	This is your 3rd level category (sub subcategory) for the product
	push @columns, "MerchantGroup";
#29	MerchantSubgroup	Text	255 characters	Yes	This is your 4th level cateogy (sub sub subcategory) for the product.
	push @columns, "MerchantSubgroup";
#30	CompatibleWith	Text	255 characters	Yes	Comma separated list of compatible items in format of Manufacturer~Part Number.
	push @columns, "CompatibleWith";
#31	CompareTo	Text	255 characters	Yes	Comma separated list of items this can replace in format of Manufacturer~Part Number.
	push @columns, "CompareTo";
#32	QuantityDiscount	Text	255 characters	Yes	Comma separated list in the format of minQuantity~maxQuantity~itemCost. Leave Max Quantity blank for top tier. You should include a tier with a minQuantity of 1 in this list, and the itemCost for this tier should match the value specified in the price column.
	push @columns, "QuantityDiscount";
#33	Bestseller	Bit	1	Yes	Populate with a 1 to indicate a best selling product. Null values or zero are non-bestsellers.
	push @columns, "Bestseller";
#34	AddToCartURL	URL	255 characters	Yes	URL that adds this product directly into the shopping cart.
	push @columns, "AddToCartURL";
#35	ReviewsRSSURL	URL	255 characters	Yes	URL to RSS formatted reviews for this product.
	push @columns, "ReviewsRSSURL";
#36	Option1	Text	255 characters	Yes	Comma separated list of product options in the format optionName~priceChangeInDollarsPerUnit. Options with no price change should have a 0 for the priceChangeInDollarsPerUnit value.
	push @columns, "Option1";
#37	Option2	Text	255 characters	Yes	Comma separated list of product options in the format optionName~priceChangeInDollarsPerUnit. Options with no price change should have a 0 for the priceChangeInDollarsPerUnit value.
	push @columns, "Option2";
#38	Option3	Text	255 characters	Yes	Comma separated list of product options in the format optionName~priceChangeInDollarsPerUnit. Options with no price change should have a 0 for the priceChangeInDollarsPerUnit value.
	push @columns, "Option3";
#39	Option4	Text	255 characters	Yes	Comma separated list of product options in the format optionName~priceChangeInDollarsPerUnit. Options with no price change should have a 0 for the priceChangeInDollarsPerUnit value.
	push @columns, "Option4";
#40	Option5	Text	255 characters	Yes	Comma separated list of product options in the format optionName~priceChangeInDollarsPerUnit. Options with no price change should have a 0 for the priceChangeInDollarsPerUnit value.
	push @columns, "Option5";
#41	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "ReservedForFutureUse";
#42	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "ReservedForFutureUse";
#43	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "ReservedForFutureUse";
#44	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "ReservedForFutureUse";
#45	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "ReservedForFutureUse";
#46	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "ReservedForFutureUse";
#47	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "ReservedForFutureUse";
#48	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "ReservedForFutureUse";
#49	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "ReservedForFutureUse";
#50	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "ReservedForFutureUse";

	my $status = $csv->combine(@columns);    # combine columns into a string
	my $line = $csv->string();               # get the combined string
	return($line."\n");
	}

sub so { return($_[0]->{'_SO'}); }


##
##
##  
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my $csv = $self->{'_csv'};
	
	my @columns = ();

#1	SKU	Text	255 characters	No	Mandatory Unique Value
	push @columns, uc($SKU);
#2	Name	Text	255 characters	Yes	Product Name
	push @columns, $P->fetch('zoovy:prod_name');
#3	URL	URL	255 characters	No	Direct URL to the product
	push @columns, $OVERRIDES->{'zoovy:link2'};
#4	Price	Numeric	2 decimal places	No	Product Price
	push @columns, sprintf("%.2f",$P->skufetch($SKU,'zoovy:base_price'));
#5	RetailPrice	Numeric	2 decimal places	Yes	"Retail" or "List" price
	push @columns, sprintf("%.2f",$P->fetch('zoovy:prod_msrp'));
#6	FullImage	URL	255 characters	Yes	URL to product full size image
	if ($P->fetch('zoovy:prod_image1')) { 
		push @columns, &ZOOVY::mediahost_imageurl($self->so->username(),$P->fetch('zoovy:prod_image1'),0,0,'FFFFFF',0,'jpg'); 
		}
	else {
		push @columns, "";
		}
#7	ThumbnailImage	URL	255 characters	Yes	URL to product thumbnail image
	if ($P->thumbnail()) { 
		push @columns, &ZOOVY::mediahost_imageurl($self->so->username(),$P->thumbnail(),0,0,'FFFFFF',0,'jpg'); 
		}
	else {
		push @columns, "";
		}
#8	Commission	Float	
	push @columns, $P->fetch('sas:prod_commission');
#	Yes	Dollar amount of product commission (do not enter in a commission percentage). This will not affect the tracking or the actual commission rewarded on the sale, and is only for a quick reference for the affiliate.

	my ($cat,$subcat) = (0,0);
	if ((defined $P->fetch('sas:category')) && ($P->fetch('sas:category') ne '')) {
		($cat,$subcat) = split(/\./,$P->fetch('sas:category'));
		}
	elsif ($OVERRIDES->{'navcat:meta'} ne '') {
		($cat,$subcat) = split(/\./,$OVERRIDES->{'navcat:meta'});
		}

#9	Category	Integer	
	push @columns, $cat;
#	No	Product Category - see ShareASale defined category numbers below
#10	Subcategory	Integer	
	push @columns, $subcat;
#	No	Product Subcategory - see ShareASale defined subcategory numbers below
#11	Description	Text	No character limit	Yes	Product Description
	my ($short,$long) = ($P->fetch('zoovy:prod_desc'),$P->fetch('zoovy:prod_detail'));
	if ($long eq '') { $long = $short; $short = '';	}
	push @columns, &SYNDICATION::declaw($long);

#12	SearchTerms	Text	255 characters	Yes	Comma separated list of product search terms
	push @columns, $P->fetch('zoovy:prod_keywords');

#13	Status	Text	50 characters	Yes	Stock Status.

	my $status = 'instock';
	if ($P->fetch('is:preorder') == 1) {
		$status = 'backorder';
		}
	elsif ($P->fetch('is:specialorder') == 1) {
		$status = 'available for order';
		}
	elsif ($P->fetch('is:discontinued') == 1) {
		$status = 'cancelled';
		}
	elsif ($OVERRIDES->{'zoovy:qty_instock'} <= 0) {
		$status = 'soldout';
		}
	push @columns, $status;
#    * instock - Indicates an In Stock item
#    * backorder - Indicates an item on backorder
#    * cancelled - Indicates an item no longer offered
#    * soldout - Indicates an item that is sold out. 


#14	MerchantID	Integer	
	push @columns, $self->so->get('.merchantid');
#-
#	No	Your ShareASale MerchantID is 7867
#15	Custom1	Text	255 characters	Yes	Any extra data you would like to add.
	push @columns, "";
#16	Custom2	Text	255 characters	Yes	Any extra data you would like to add.
	push @columns, "";
#17	Custom3	Text	255 characters	Yes	Any extra data you would like to add.
	push @columns, "";
#18	Custom4	Text	255 characters	Yes	Any extra data you would like to add.
	push @columns, "";
#19	Custom5	Text	255 characters	Yes	Any extra data you would like to add.
	push @columns, "";
#20	Manufacturer	Text	255 characters	Yes	Product Manufacturer
	push @columns, $P->skufetch($SKU,'zoovy:prod_mfg');
#21	PartNumber	Text	255 characters	Yes	This should be a manufacturer provided value that uniquely identifies this product. This could be a model number, part number, etc. Typically, this field is used by affiliates to price match an item across multiple merchants.
	push @columns, $P->skufetch($SKU,'zoovy:prod_mfgid');

	my (@BREADCRUMBS) = split(/[\|\>]+/,$OVERRIDES->{'navcat:bc'});
	foreach my $bc (@BREADCRUMBS) {
		$bc =~ s/^[\s]+//gs;  # strip leading space
		$bc =~ s/[\s]+$//gs;  # strip trailing space
		}

#22	MerchantCategory	Text	255 characters	Yes	This is your category for the product.
	push @columns, $BREADCRUMBS[0];

#23	MerchantSubcategory	Text	255 characters	Yes	This is your subcategory for the product.
	push @columns, $BREADCRUMBS[1];
#24	ShortDescription	Text	255 characters	Yes	This is a short text only description of this product. Do not include any HTML markup in this field.
	push @columns, $short;

#25	ISBN	Text	25 characters	Yes	ISBN for this product, if applicable.
	push @columns, $P->skufetch($SKU,'zoovy:prod_isbn');

#26	UPC	Text	25 characters	Yes	UPC for this product, if applicable.
	push @columns, $P->skufetch($SKU,'zoovy:prod_upc');
#27	CrossSell	Text	255 characters	Yes	Comma separated list of SKU values that cross sell with the product.
	push @columns, $P->fetch('zoovy:prod_related');
#28	MerchantGroup	Text	255 characters	Yes	This is your 3rd level category (sub subcategory) for the product
	push @columns, $BREADCRUMBS[2];
#29	MerchantSubgroup	Text	255 characters	Yes	This is your 4th level cateogy (sub sub subcategory) for the product.
	push @columns, $BREADCRUMBS[3];
#30	CompatibleWith	Text	255 characters	Yes	Comma separated list of compatible items in format of Manufacturer~Part Number.
	push @columns, "";
#31	CompareTo	Text	255 characters	Yes	Comma separated list of items this can replace in format of Manufacturer~Part Number.
	push @columns, "";
#32	QuantityDiscount	Text	255 characters	Yes	Comma separated list in the format of minQuantity~maxQuantity~itemCost. Leave Max Quantity blank for top tier. You should include a tier with a minQuantity of 1 in this list, and the itemCost for this tier should match the value specified in the price column.
	push @columns, "";
#33	Bestseller	Bit	1	Yes	Populate with a 1 to indicate a best selling product. Null values or zero are non-bestsellers.
	push @columns, $P->fetch('is:bestseller');
#34	AddToCartURL	URL	255 characters	Yes	URL that adds this product directly into the shopping cart.
	# my ($url) = &PRODUCT::BUYME::button(
	push @columns, "";

#35	ReviewsRSSURL	URL	255 characters	Yes	URL to RSS formatted reviews for this product.
	push @columns, "";

#36	Option1	Text	255 characters	Yes	Comma separated list of product options in the format optionName~priceChangeInDollarsPerUnit. Options with no price change should have a 0 for the priceChangeInDollarsPerUnit value.
	push @columns, "";
#37	Option2	Text	255 characters	Yes	Comma separated list of product options in the format optionName~priceChangeInDollarsPerUnit. Options with no price change should have a 0 for the priceChangeInDollarsPerUnit value.
	push @columns, "";
#38	Option3	Text	255 characters	Yes	Comma separated list of product options in the format optionName~priceChangeInDollarsPerUnit. Options with no price change should have a 0 for the priceChangeInDollarsPerUnit value.
	push @columns, "";
#39	Option4	Text	255 characters	Yes	Comma separated list of product options in the format optionName~priceChangeInDollarsPerUnit. Options with no price change should have a 0 for the priceChangeInDollarsPerUnit value.
	push @columns, "";
#40	Option5	Text	255 characters	Yes	Comma separated list of product options in the format optionName~priceChangeInDollarsPerUnit. Options with no price change should have a 0 for the priceChangeInDollarsPerUnit value.
	push @columns, "";

#41	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "";
#42	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "";
#43	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "";
#44	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "";
#45	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "";
#46	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "";
#47	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "";
#48	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "";
#49	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "";
#50	ReservedForFutureUse	-	-	Yes	Reserved for future use.
	push @columns, "";

	my $status = $csv->combine(@columns);    # combine columns into a string
	my $line = $csv->string();               # get the combined string

	if ($line eq '') {
	  use Data::Dumper;
	 #  print Dumper(\@columns);
	  }

	return($line."\n");
	}
  
sub footer_products {
  my ($self) = @_;
  return("");
  }


1;
