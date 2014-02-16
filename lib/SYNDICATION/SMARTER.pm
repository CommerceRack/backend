#!/usr/bin/perl

package SYNDICATION::SMARTER;


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
	bless $self, 'SYNDICATION::SMARTER';  
	untie %s;

	require SYNDICATION::CATEGORIES;
	$self->{'%CATEGORIES'} = SYNDICATION::CATEGORIES::CDSasHASH("SMT",">");

	return($self);
	}


sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	my $ERROR = undef;
		
	#if ($prodref->{'zoovy:prod_image1'} eq '') { 
	#	$ERROR = "{zoovy:prod_image1}product image (BECOME Image_Link) is not specified";
	#	}
	if ($P->thumbnail() eq '') {
		$ERROR = "VALIDATION|ATTRIB=zoovy:prod_image1|+product image missing";
		}
	if ($P->fetch('zoovy:prod_desc') eq '') { 
		$ERROR = "VALIDATION|ATTRIB=zoovy:prod_desc|+product description is not specified";
		}
	elsif ($P->fetch('zoovy:prod_name') eq '') {
		$ERROR = "VALIDATION|ATTRIB=zoovy:prod_name|+product name is not set";
		}
	
	return($ERROR);
	}


##
## this creates the header row. 
##
sub header_products {
	my ($self) = @_;

	$self->{'_csv'} = Text::CSV_XS->new({binary=>1,sep_char=>"\t"});              # create a new object
	my $csv = $self->{'_csv'};

	my @columns = ();


	# * Product Name
	push @columns, "Product Name";

   # * Product Description
	push @columns, "Product Description";

   # * Brand Name
	push @columns, "Brand Name";

   # * Smarter.com Categorization
	push @columns, "Smarter.com Categorization";

   # * MPN/UPC/ISBN/ UniqueCode
	push @columns, "MPN/UPC/ISBN";

   # * Regular Price
	push @columns, "Regular Price";

   # * Sale Price
	push @columns, "Sale Price";

   # * Product URL
	push @columns, "Product URL";

   # * Image URL
	push @columns, "Image URL";

   # * Stock Availability
	push @columns, "Stock Availability";

   # * Product Condition
	push @columns, "Product Condition";

   # * Shipping Costs
	push @columns, "Shipping Costs";

   # * Shipping Weight
	push @columns, "Shipping Weight";

   # * Shipping Zip
	push @columns, "Shipping Zip";

   # * Promotion
	push @columns, "Promotion";

   # * Keywords
	push @columns, "Keywords";

   # * Bid Amount
	push @columns, "Bid Amount";

   # * Coupon Code
	push @columns, "Coupon Code";

   # * Coupon Start Date
	push @columns, "Coupon Start Date";

   # * Coupon End Date
	push @columns, "Coupon End Date";

   # * Coupon Description
	push @columns, "Coupon Description";

   # * Coupon Restriction
	push @columns, "Coupon Restriction";


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

	# * Product Name
	push @columns, $P->fetch('zoovy:prod_name');

   # * Product Description
	push @columns, $P->fetch('zoovy:prod_desc');

   # * Brand Name
	push @columns, $P->fetch('zoovy:prod_mfg');

   # * Smarter.com Categorization
	push @columns, $self->{'%CATEGORIES'}->{ $OVERRIDES->{'navcat:meta'} };

   # * MPN/UPC/ISBN/ UniqueCode
	my $ID = $P->skufetch($SKU,'zoovy:prod_upc');
	if ((not defined $ID) || ($ID eq '')) { $ID = $P->skufetch($SKU,'zoovy:prod_isbn'); }
	if ((not defined $ID) || ($ID eq '')) { $ID = $P->skufetch($SKU,'zoovy:prod_mfgid'); }
	if ((not defined $ID) || ($ID eq '')) { $ID = $SKU; }
	push @columns, $ID;

   # * Regular Price
	push @columns, $P->skufetch($SKU,'zoovy:base_price');
   # * Sale Price
	push @columns, $P->skufetch($SKU,'zoovy:base_price');

   # * Product URL
	push @columns, $OVERRIDES->{'zoovy:link2'};

   # * Image URL
	if ($P->thumbnail()) { 
		push @columns, &ZOOVY::mediahost_imageurl($self->so->username(),$P->thumbnail(),0,0,'FFFFFF',0,'jpg'); 
		}
	else {
		push @columns, "";
		}

   # * Stock Availability
	push @columns, ($OVERRIDES->{'zoovy:qty_instock'})?'In Stock':'Out of Stock';

   # * Product Condition
	push @columns, $P->fetch('zoovy:prod_condition');

   # * Shipping Costs
	push @columns, $P->fetch('zoovy:ship_cost1');
   # * Shipping Weight
	push @columns, &ZSHIP::smart_weight($P->fetch('zoovy:base_weight'));

   # * Shipping Zip
	push @columns, '';
   # * Promotion
	push @columns, '';
   # * Keywords
	push @columns, $P->fetch('zoovy:prod_keywords');

   # * Bid Amount
	push @columns, '';
   # * Coupon Code
	push @columns, '';
   # * Coupon Start Date
	push @columns, '';
   # * Coupon End Date
	push @columns, '';
   # * Coupon Description
	push @columns, ''; 
   # * Coupon Restriction
	push @columns, '';

	my $status = $csv->combine(@columns);    # combine columns into a string
	my $line = $csv->string();               # get the combined string

	if ($line eq '') {
	  use Data::Dumper;
	 #  print Dumper(\@columns);
	  }

	return($line."\n");
	}
  


##
## this generates a footer_products, it's called by $so after all the products are done.
##  since csv files don't have footers (but XML files do) it can probably output blank.. unless it's xml
## then it should return </endtag> or whatever the ending is. 
sub footer_products {
  my ($self) = @_;
  return("");
  }


1;
