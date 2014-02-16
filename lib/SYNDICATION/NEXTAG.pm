package SYNDICATION::NEXTAG;

use Text::CSV_XS;
use lib "/backend/lib";
require SITE; 
use strict;


##
## nextag loads it's file from a private file
## http://webapi.zoovy.com/webapi/nextag/index.cgi/<!-- USERNAME -->.<!-- PROFILE -->.txt
##


sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;
	# $so->set('.url','site://'.$so->profile().'-nextag.txt');

	## we don't need to do anything since nextag will load our private file we generate
   my $ERROR = '';
   my $ftpserv = $so->get('.ftp_server');
	if ($ftpserv ne '') {
		## send file via ftp
	   $ftpserv =~ s/ //g;
		if ($ftpserv =~ /^ftp\:\/\//i) { $ftpserv = substr($ftpserv,6); }
		if ($ftpserv !~ /nextag\.com$/) {
			$ERROR = 'FTP Server must end in .nextag.com';
			}
   	my $fuser = $so->get('.ftp_user');
	   $fuser =~ s/ //g;
   	my $fpass = $so->get('.ftp_pass');
	   $fpass =~ s/ //g;

		my $fpath = $so->get('.ftp_path');
		$fpath = "/";	# 2012-09-12 -- it appears nextag chroots to the proper dir anyway
		if ($fpath eq '') {
			$ERROR = "required field ftp file path is blank";
			}
#	   my $ffile = $so->get('.ftp_filename');
#	   $ffile =~ s/ //g;
#		if ($ffile eq '') {
#			$ERROR = "no file name set");
#			}
		if (substr($fpath,0,1) eq '/') { $fpath = substr($fpath,1); } # strip leading /
		if (substr($fpath,-1) eq '/') { $fpath = substr($fpath,0,length($fpath)-1); } # strip tailing /
	
		my $filename = sprintf("%s.%s.txt",lc($so->username()),lc($so->domain()));

	   $so->set(".url","ftp://$fuser:$fpass\@$ftpserv/$fpath/$filename");
		}
	else {
		## legacy method where nextag pulls file
		$so->set(".url","null");
		}


	$self->{'_FORMAT'} = $so->get('.format');

	$self->{'+PRODUCT_COUNT'} = 0;

	if ($self->{'_FORMAT'}==0) {
		## SOFT GOODS
		## http://merchants.nextag.com/serv/main/buyer/SoftGoodsFeedSpec.jsp?nxtg=2a2b81_3209B333E7964B4B
		}
	elsif ($self->{'_FORMAT'}==1) {
		## Tech Feed
		## http://merchants.nextag.com/serv/main/buyer/TechFeedSpec.jsp?nxtg=2a2b81_3209B333E7964B4B
		}

	bless $self, 'SYNDICATION::NEXTAG';  
	return($self);
	}


sub header_products {
	my ($self) = @_;

	$self->{'_csv'} = Text::CSV_XS->new({always_quote=>1,binary=>1,sep_char=>"\t"});              # create a new object
	my $csv = $self->{'_csv'};

	my @columns = ();
	if ($self->{'_FORMAT'}==0) {
		## SOFT GOODS
		## http://merchants.nextag.com/serv/main/buyer/SoftGoodsFeedSpec.jsp?nxtg=2a2b81_3209B333E7964B4B
		push @columns, "Product Name";
		push @columns, "Manufacturer";
		push @columns, "Price";
		push @columns, "Click-Out URL";
		push @columns, "Manufacturer Part #";
		push @columns, "Product Category";
		push @columns, "Image URL";
		push @columns, "Description";
		push @columns, "Distributor ID";
		push @columns, "List Price";
		push @columns, "Stock Status";
		push @columns, "Ground shipping";
		push @columns, "Weight";
		push @columns, "UPC";
		push @columns, "Marketing Message";
#		push @columns, "Warranty";
		}
	elsif ($self->{'_FORMAT'}==1) {
		## Tech Feed
		## http://merchants.nextag.com/serv/main/buyer/TechFeedSpec.jsp?nxtg=2a2b81_3209B333E7964B4B
		push @columns, "Product Name";
		push @columns, "Manufacturer";
		push @columns, "Manufacturer Part Number";
		push @columns, "Price";
		push @columns, "URL";
		push @columns, "Product Image URL";
		push @columns, "MUZE ID";
		push @columns, "Shipping Cost";
		push @columns, "Weight";
		push @columns, "Description";
		push @columns, "Product Category";
		push @columns, "Warranty Info";
		push @columns, "Product Condition";
		push @columns, "Promotional Details";
		push @columns, "CPC Rate";
		push @columns, "Max CPC";
		}

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

	my $USERNAME = $self->so()->{'USERNAME'};
	my $csv = $self->{'_csv'};


	# Mfr
	my $key = undef;
	if (not defined $key) { $key = $P->fetch('zoovy:prod_mfg'); if ($key eq '') { $key = undef; } }
	if (not defined $key) { $key = $P->fetch('zoovy:prod_mfgid'); if ($key eq '') { $key = undef; } }
	if (not defined $key) { $key = $SKU; }

	my $IMGURL = '';
	if ($P->thumbnail($SKU) =~ /http[s]:/) {
		## http://www.someimage.com
		$IMGURL = $P->thumbnail($SKU);
		}
	elsif ($P->thumbnail($SKU)) {
		$IMGURL = &ZOOVY::mediahost_imageurl($USERNAME,$P->thumbnail($SKU),0,0,'FFFFFF',0,'jpg');
		}

	my $MFGID = $P->fetch('zoovy:prod_mfgid');
	if ($MFGID eq '') { $MFGID = $SKU; }

##  no longer defaults to local company name (this is wrong most of the time)
#	if ($P->fetch('zoovy:prod_mfg') eq '') { $P->fetch('zoovy:prod_mfg') = &ZOOVY::fetchmerchant_attrib($USERNAME,'zoovy:company_name'); }
#	if ($P->fetch('zoovy:prod_mfg') eq '') { $P->fetch('zoovy:prod_mfg') = $USERNAME; }
	
	my @columns = ();
	if ($self->{'_FORMAT'} == 0) {
		## SOFT GOODS
		## http://merchants.nextag.com/serv/main/buyer/SoftGoodsFeedSpec.jsp?nxtg=2a2b81_3209B333E7964B4B

		## Product Title	Yes	See restrictions below
		
		if ((defined $P->fetch('nextag:prod_name')) && ($P->fetch('nextag:prod_name') ne '')) { 
			push @columns, SYNDICATION::declaw($P->fetch('nextag:prod_name'));
			}
		else {
			push @columns, SYNDICATION::declaw($P->fetch('zoovy:prod_name'));
			}
		## Manufacturer Name	Yes	This name is used as the brand of the product on the site
		push @columns, $P->fetch('zoovy:prod_mfg');
		## Price	Yes	Merchant List Price
		push @columns, $P->fetch('zoovy:base_price');

		## URL of product page	Yes	 
		# push @columns, "http://$USERNAME.zoovy.com/product/$PID?META=nextag-$P;

		push @columns, $OVERRIDES->{'zoovy:link2'};

		## Manufacturer SKU	Yes	 
		push @columns, $MFGID;

		## Product Category	Yes	If you categorize products using a hierarchical taxonomy, please include one field for each level of the taxonomy
		push @columns, $OVERRIDES->{'navcat:meta'};	# nextag (pretty) category
		# push @columns, $P->fetch('zoovy:prod_category'); # website (pretty) category
		## NOTE: 11/15/11 - according to kims this should use nextag category not website category

		## Image URL of product	Yes	Please provide largest available image size with highest resolution. Images should be at least 100 by 100 pixels
		push @columns, $IMGURL;
		## Product Description	Yes	Approximately the first 180 characters are displayed on the search results page
		push @columns, &SYNDICATION::declaw($P->fetch('zoovy:prod_desc'));
		## Distributor ID	No	 
		push @columns, $P->fetch('zoovy:prod_supplierid');
		## MSRP Price	No	Recommended
		push @columns, $P->fetch('zoovy:prod_msrp');
		## Stock Status	No	Values: Christi said this needs to be set to 'In Stock' or 'Out of stock' 2011-01-11
		push @columns, ($OVERRIDES->{'zoovy:qty_instock'})?'In Stock':'Out of Stock';
		## Ground shipping	No	If you cannot provide, please provide the calculation for ground shipping
		push @columns, $P->fetch('zoovy:ship_cost1');
		## 2nd day shipping	No	If you cannot provide, please provide the calculation for 2nd day shipping
#		$c .=	"\t";
		## Overnight	No	If you cannot provide, please provide the calculation for overnight shipping
#		$c .= "\t";
		## Product Weight	No	Only required for weight-based shipping calculations. At a minimum, it is recommended that this field or the ground-shipping field is included
		push @columns, sprintf("%.1f",&ZSHIP::smart_weight($P->fetch('zoovy:base_weight'))/16);
		## UPC	No	Only required if Manufacturer SKU and Manufacturer name are not both specified
		push @columns, $P->skufetch($SKU,'zoovy:prod_upc');
		## Marketing Message	No	Promotional tag (24 character limit) Ex: Free shipping, 20% off sale, $3.00 flat shipping
		push @columns, &SYNDICATION::declaw($P->fetch('zoovy:prod_promotxt'));
#		## Warranty	No	Information on warranty and service programs		
#		push @columns, $P->fetch('zoovy:prod_warranty');
		}
	else {
		## Product Title	Yes	Under 40 characters - see below for *important* restrictions
		if ((defined $P->fetch('nextag:prod_name')) && ($P->fetch('nextag:prod_name') ne '')) { 
			push @columns, SYNDICATION::declaw($P->fetch('nextag:prod_name'));
			}
		else { 
			push @columns, SYNDICATION::declaw($P->fetch('zoovy:prod_name')); 
			}
		## Manufacturer Name	Yes	Under 40 characters
		push @columns, $P->fetch('zoovy:prod_mfg');
		## Manufacturer Part Number	Yes	Under 40 characters
		push @columns, $MFGID;
		## Price	Yes	U.S. Dollars
		push @columns, $P->skufetch($SKU,'zoovy:base_price');
		## URL of product page	Yes	URL
		push @columns, $OVERRIDES->{'zoovy:link2'};
		## Product Image URL	No	URL For better success with conversion rates, it is strongly suggested that you include a link to your largest, highest resolution images
		push @columns, $IMGURL;
		## MUZE ID	No	Applicable only for Music and Video Products
		push @columns, $P->fetch('nextag:muze_id');
		## Shipping Cost	No	For ground - if you cannot provide, let us know what your shipping calculation is
		push @columns, $P->fetch('zoovy:ship_cost1');
		## Product Weight	No	For weight-based shipping calculations
		push @columns, sprintf("%.1f",&ZSHIP::smart_weight($P->fetch('zoovy:base_weight'))/16);
		## Product Description	No	Under 255 characters, no HTML tags or special characters
		push @columns, SYNDICATION::declaw($P->fetch('zoovy:prod_desc'));
		## Product Category	No	 
		push @columns, $OVERRIDES->{'navcat:prod_category'};
		## Warranty Info	No	 
		push @columns, $P->fetch('zoovy:prod_warranty');
		## Product Condition	No	New, Used, Refurbished, Blank
		push @columns, $P->fetch('zoovy:prod_condition');
		## Promotional Details	No	 
		push @columns, SYNDICATION::declaw($P->fetch('zoovy:prod_promotxt'));
		## CPC Rate	No	For setting CPC product-by-product in your feed
		push @columns, $P->fetch('nextag:cpc_rate');
		## Max CPC	No	For defining CPC as the maximum you want to bid for this product
		push @columns, $P->fetch('nextag:max_cpc');
		}

	my $i = scalar(@columns);
	while ($i-->0) {
		$columns[$i] =~ s/[\n\r]+/ /sg;
		$columns[$i] = &ZTOOLKIT::stripUnicode($columns[$i]);
		}
	
	my $status = $csv->combine(@columns);	 # combine columns into a string
	my $line = $csv->string();					# get the combined string

	if ($line eq '') {
	  use Data::Dumper;
	 #  print Dumper(\@columns);
	  }
	else {
		$self->{'+PRODUCT_COUNT'}++;
		}

	return($line."\n");
	}
  
sub footer_products {
  my ($self) = @_;

	if ($self->{'+PRODUCT_COUNT'}>0) {
		$self->so()->msgs()->pooshmsg("INFO|+Appended $self->{'+PRODUCT_COUNT'} products to file.");
		}
	else {
		$self->so()->msgs()->pooshmsg("WARN|+No products could be appended to nextag file.");
		}

  return("");
  }



1;