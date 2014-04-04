#!/usr/bin/perl

package SYNDICATION::THEFIND;


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

	$so->set('.url',sprintf("ftp://%s:%s\@%s/%s/data.txt",$s{'.ftp_user'},$s{'.ftp_pass'},$s{'.ftp_server'},$s{'.ftp_dir'}));
	## don't worry about this line -- *YET* .. it creates an object but you don't need to understand it.
	bless $self, 'SYNDICATION::THEFIND';  
	untie %s;

	require SYNDICATION::CATEGORIES;
	$self->{'%CATEGORIES'} = SYNDICATION::CATEGORIES::CDSasHASH("FND",">");

	return($self);
	}


sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	my $ERROR = undef;
		
	if ($P->thumbnail() eq '') {
		$ERROR = "VALIDATION|ATTRIB=zoovy:prod_image1|+product image (THEFIND Image_Link) is not specified";
		}
	elsif ($P->fetch('zoovy:prod_desc') eq '') { 
		$ERROR = "{zoovy:prod_desc}product description (THEFIND Description) is not specified";
		}
	elsif ($P->fetch('zoovy:prod_name') eq '') {
		$ERROR = "{zoovy:prod_name}product name (THEFIND Title) is not set";
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

	# TheFind, Inc. 310 Villa Street Mountain View, CA 94041 www.thefind.com
	# Version 1.12
	# https://merchant.thefind.com/doc/TheFind_Product_Feed_Specification1_1.pdf
	my @columns = ();

	# Required Attributes
	# The following attributes are required for products to appear on TheFind:
	push @columns, "Title"; # The name of the product. Please ensure that the title only includes information about the product and not about anything else.
	push @columns, "Description"; # A description of the product. Please ensure that the description only includes information about the product and not about anything else. No keyword spamming/stuffing.
	push @columns, "Image_Link"; # The URL of an image of the product. For best viewing on TheFind, the image referred to by this URL should be the largest, best quality picture available online, at least 150 pixels wide and 150 pixels high. If a product has no image please specify .no image..
	push @columns, "Page_URL"; # The URL of the product page. A product page typically shows the details of a single product, along with a button to buy the product.
	push @columns, "Price"; # The price of the product.

	# Highly Recommended Attributes
	# The following attributes are not required but are highly recommended to increase visibility on TheFind:
	push @columns, "SKU"; # The item's SKU number in your store. This does not need to be unique as many items may share the same SKU.
	push @columns, "UPC-EAN"; # Universal Product Code or EAN number
	push @columns, "MPN"; # The item's Manufacturer's Product Number, the unique number assigned to the product by the manufacturer.
	push @columns, "ISBN"; # The ISBN number for a book.
	push @columns, "Unique_ID"; # If the item you are listing has a unique id in your system, please include it.
	push @columns, "Style_ID"; # The id number for a particular style of a product. The style should be labeled distinctly in the Style_Label field. Styles may have the same SKU but different prices, UPCs, available sizes, etc.
	push @columns, "Style_Name"; # The style name given to a variation of a product. Styles often share the same SKU number but may have different colors, materials, or price. (e.g. a particular shoe.s style may be "Black snake" or "Silver soft kid")
	push @columns, "Sale"; # If the item is on sale enter Yes.
	push @columns, "Sale_Price"; # The sale price of the product. This differs from the value of the Price attribute if this product is on sale. If the product is not on sale, the Sale_Price value may be left empty or may be equal to the price attribute.
	push @columns, "Shipping Cost"; # Enter a shipping cost to override TheFind Merchant Center settings.
	push @columns, "Free"; # Shipping If shipping is free for this product, specify as Free Shipping. This will override Merchant Center settings and any amount in Shipping Cost field.
	push @columns, "Online_Only"; # If the item is only sold online, specify Yes. Otherwise, No or leave blank.
	push @columns, "Stock_Quantity"; # How many are in stock. 0=out of stock online, but may be available locally.
	push @columns, "User_Rating"; # How well users rate the product, from 1 to 5 with 5 being the best rating.
	push @columns, "User_Review_Link"; # The URL of the user reviews page.

	# Other Recommended Attributes
	push @columns, "Brand"; # The brand of the product.
	push @columns, "Categories"; # Categorize the item in a single category or in a breadcrumb format (e.g. Appliances > Washing Machines)
	push @columns, "Color"; # A comma.separated list of colors a product comes in. For example, "red,green,teal".
	push @columns, "Compatible_With"; # A list of SKUs that are compatible with the product (e.g. ink toner with a list of printers, or belts with a pair of shoes)
	push @columns, "Condition"; # Whether the product is new or used. Acceptable values for this field include "new", "used", and "refurbished".
	push @columns, "Coupons"; # A list of the ids of coupons or discounts in TheFind Merchant Center that this product is eligible for.
	push @columns, "Made_In"; # The country where the product was made.
	push @columns, "Model"; # The model name of the product (for example, Powershot SD660).
	push @columns, "Model_Number"; # Just the number/letter string given to the model (for example, SD660).
	push @columns, "Similar_To"; # A list of SKUs that may be similar to the product.
	push @columns, "Tags-Keywords"; #.Keywords Provide up to 10 additional keywords describing the product.
	push @columns, "Unit_Quantity"; # The quantity of items included (e.g. package contains 8 units of toothpaste)
	push @columns, "Video_Link"; # The URL of a product video.
	push @columns, "Video"; # Title The title of the product video.
	push @columns, "Weight"; # The weight of the product. This can be used in the Merchant Center to trigger Shipping Costs.

	# Product-Specific Attributes
	# The following are optional, product-specific attributes. Including this information will increase the likelihood of your products appearing in more searches or filtered searches.
	push @columns, "Actors"; # The actors starring in the product.
	push @columns, "Age_Range"; # Suggested age range for the toy.
	push @columns, "Artist"; # The artists who created the product.
	push @columns, "Aspect_Ratio"; # The aspect ratio of the screen. (e.g. 16:9)
	push @columns, "Author"; # The author of the book.
	push @columns, "Battery_Life"; # The average life of the battery, if the computer is a laptop, in hours.
	push @columns, "Binding"; # The binding of the product. (Hardcover, softcover, e.book)
	push @columns, "Capacity"; # For electronic devices, the amount of memory included in a product. For appliances, the volume of space within the appliance.
	push @columns, "Color_Output"; # Information about whether or not the printer is a color printer.
	push @columns, "Department"; # The department of a clothing item (e.g. Mens or Womens).
	push @columns, "Director"; # The director of the movie.
	push @columns, "Display_Type"; # The type of display on the television or monitor (e.g. LCD)
	push @columns, "Edition"; # The edition of the product. (E.g. Collectors, box set, etc.)
	push @columns, "Focus_Type"; # The type of focus a camera has. (E.g. Auto)
	push @columns, "Format"; # Format of the product (e.g. DVD)
	push @columns, "Genre"; # The genre of the product. (e.g. rock and roll, country)
	push @columns, "Heel_Height"; # The heel height of a shoe.
	push @columns, "Height"; # The height of the product.
	push @columns, "Installation"; # How a product is installed (e.g. wall.mount)
	push @columns, "Length"; # The length of a product (can be a comma.separated list of the lengths).
	push @columns, "Load_Type"; # The type of loading for a washer.
	push @columns, "Material"; # The material the product is made out of.
	push @columns, "Media_Rating"; # The rating of the product. For example, PG.13.
	push @columns, "Megapixels"; # The resolution of a digital imaging device.
	push @columns, "Memory_Card_Slot"; # The available memory card slots in a printer.
	push @columns, "Occasion"; # The special occasion the jewelry is intended for, if applicable.
	push @columns, "Optical_Drive"; # The type of optical drive included with a computer.
	push @columns, "Pages"; # Number of pages in the book.
	push @columns, "Gaming_Platform"; # The platform the game operates on.
	push @columns, "Processor_Speed"; # The processor speed for the product.
	push @columns, "Publisher"; # The publisher of the product.
	push @columns, "Recommended_Usage"; # Recommended usage of a computer. (e.g. home or office)
	push @columns, "Screen_Resolution"; # Maxiumum resolution of the screen.
	push @columns, "Sales_Rank"; # The rank of this product in terms of sales in your store. Lower numbers indicate they are sold more often.
	push @columns, "Screen_Size"; # The diagonal screen size. (E.g. 42 inches)
	push @columns, "Shoe_Width"; # The widths that a shoe comes in.
	push @columns, "Sizes"; # The sizes that a product comes in (e.g. S,M,L, XL, or shoe sizes)
	push @columns, "Sizes_In_Stock"; # The sizes that are currently in stock (e.g. 4,7,8,9,11)
	push @columns, "Subject"; # The subject of a book.
	push @columns, "Tech_Spec_Link"; # The URL of technical specifications of the product, if available. This should not forward to another URL; it must point directly to the target page. The domain name may not be an IP address.
	push @columns, "Width"; # The width of a product (can be a comma separated list of the widths).
	push @columns, "Wireless_Interface"; # Wireless interface that the cell phone uses.
	push @columns, "Year"; # The year of the product's issue.
	push @columns, "Zoom"; # The maximum amount a camera can zoom. (E.g. 6x)
	push @columns, "Alt_Image_1"; # URL for alternate image view of product.
	push @columns, "Alt_Image_2"; # URL for alternate image view of product.
	push @columns, "Alt_Image_3"; # URL for alternate image view of product.
	push @columns, "Option_1"; # Reserved for custom feed attributes.
	push @columns, "Option_2"; # Reserved for custom feed attributes.
	push @columns, "Option_3"; # Reserved for custom feed attributes

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

	# Required Attributes
	# The following attributes are required for products to appear on TheFind:
	# "Title"; # The name of the product. Please ensure that the title only includes information about the product and not about anything else. 
	push @columns, $P->fetch('zoovy:prod_name');

	# "Description"; # A description of the product. Please ensure that the description only includes information about the product and not about anything else. No keyword spamming/stuffing.
	push @columns, &ZTOOLKIT::wikistrip($P->fetch('zoovy:prod_desc'));

	# "Image_Link"; # The URL of an image of the product. For best viewing on TheFind, the image referred to by this URL should be the largest, best quality picture available online, at least 150 pixels wide and 150 pixels high. If a product has no image please specify .no image..
	if ($P->fetch('zoovy:prod_image1')) { 
		push @columns, &ZOOVY::mediahost_imageurl($self->so->username(),$P->fetch('zoovy:prod_image1'),0,0,'FFFFFF',0,'jpg'); 
		}
	else {
		push @columns, "";
		}


	# "Page_URL"; # The URL of the product page. A product page typically shows the details of a single product, along with a button to buy the product.
	push @columns, $OVERRIDES->{'zoovy:link2'};

	# "Price"; # The price of the product.
	push @columns, sprintf("%.2f",$P->fetch('zoovy:base_price'));


	# Highly Recommended Attributes
	# The following attributes are not required but are highly recommended to increase visibility on TheFind:
	# "SKU"; # The item's SKU number in your store. This does not need to be unique as many items may share the same SKU.
	push @columns, $SKU;

	# "UPC-EAN"; # Universal Product Code or EAN number
	push @columns, $P->fetch('zoovy:prod_upc');

	# "MPN"; # The item's Manufacturer's Product Number, the unique number assigned to the product by the manufacturer.
	push @columns, $P->fetch('zoovy:prod_mfgid');

	# "ISBN"; # The ISBN number for a book.
	push @columns, $P->fetch('zoovy:prod_isbn');

	# "Unique_ID"; # If the item you are listing has a unique id in your system, please include it.
	push @columns, $SKU;

	# "Style_ID"; # The id number for a particular style of a product. The style should be labeled distinctly in the Style_Label field. Styles may have the same SKU but different prices, UPCs, available sizes, etc.
	push @columns, $P->fetch('zoovy:prod_styleid');

	# "Style_Name"; # The style name given to a variation of a product. Styles often share the same SKU number but may have different colors, materials, or price. (e.g. a particular shoe.s style may be "Black snake" or "Silver soft kid")
	push @columns, $P->fetch('zoovy:prod_styles');

	# "Sale"; # If the item is on sale enter Yes.
	push @columns, ($P->fetch('is:sale'))?'Yes':'';

	# "Sale_Price"; # The sale price of the product. This differs from the value of the Price attribute if this product is on sale. If the product is not on sale, the Sale_Price value may be left empty or may be equal to the price attribute.
	push @columns, '';

	# "Shipping Cost"; # Enter a shipping cost to override TheFind Merchant Center settings.
	push @columns, $P->fetch('zoovy:ship_cost1');

	# "Free"; # Shipping If shipping is free for this product, specify as Free Shipping. This will override Merchant Center settings and any amount in Shipping Cost field.
	push @columns, ($P->fetch('is:shipfree'))?'Yes':'';

	# "Online_Only"; # If the item is only sold online, specify Yes. Otherwise, No or leave blank.
	push @columns, '';

	# "Stock_Quantity"; # How many are in stock. 0=out of stock online, but may be available locally.
	push @columns, $OVERRIDES->{'zoovy:qty_instock'};

	# "User_Rating"; # How well users rate the product, from 1 to 5 with 5 being the best rating.
	push @columns, $P->fetch('zoovy:prod_rating');

	# "User_Review_Link"; # The URL of the user reviews page.
	push @columns, $OVERRIDES->{'zoovy:link2'};


	# 	# Other Recommended Attributes
	# "Brand"; # The brand of the product.
	push @columns, $P->fetch('zoovy:prod_mfg');

	# "Categories"; # Categorize the item in a single category or in a breadcrumb format (e.g. Appliances > Washing Machines)
	push @columns, $self->{'%CATEGORIES'}->{ $OVERRIDES->{'navcat:meta'} };

	# "Color"; # A comma.separated list of colors a product comes in. For example, "red,green,teal".
	push @columns, $P->fetch('zoovy:prod_color');

	# "Compatible_With"; # A list of SKUs that are compatible with the product (e.g. ink toner with a list of printers, or belts with a pair of shoes)
	push @columns, $P->fetch('zoovy:prod_accessories');

	# "Condition"; # Whether the product is new or used. Acceptable values for this field include "new", "used", and "refurbished".
	push @columns, $P->fetch('zoovy:prod_condition');

	# "Coupons"; # A list of the ids of coupons or discounts in TheFind Merchant Center that this product is eligible for.
	push @columns, $P->fetch('zoovy:prod_coupons');

	# "Made_In"; # The country where the product was made.
	push @columns, $P->fetch('zoovy:prod_madein');

	# "Model"; # The model name of the product (for example, Powershot SD660).
	push @columns, $P->fetch('zoovy:prod_model');

	# "Model_Number"; # Just the number/letter string given to the model (for example, SD660).
	push @columns, $P->fetch('zoovy:prod_mfgid');

	# "Similar_To"; # A list of SKUs that may be similar to the product.
	push @columns, $P->fetch('zoovy:prod_similar_to');

	# "Tags-Keywords"; #.Keywords Provide up to 10 additional keywords describing the product.
	push @columns, $P->fetch('zoovy:prod_keywords');

	# "Unit_Quantity"; # The quantity of items included (e.g. package contains 8 units of toothpaste)
	push @columns, $P->fetch('zoovy:prod_unit_quantity');

	# "Video_Link"; # The URL of a product video.
	push @columns, $P->fetch('zoovy:prod_video_link');

	# "Video"; # Title The title of the product video.
	push @columns, $P->fetch('zoovy:prod_video');

	# "Weight"; # The weight of the product. This can be used in the Merchant Center to trigger Shipping Costs.
	push @columns, &ZSHIP::smart_weight($P->fetch('zoovy:base_weight'));

	# 	# Product-Specific Attributes
	# # The following are optional, product-specific attributes. Including this information will increase the likelihood of your products appearing in more searches or filtered searches.
	# "Actors"; # The actors starring in the product.
	push @columns, $P->fetch('zoovy:prod_actors');

	# "Age_Range"; # Suggested age range for the toy.
	push @columns, $P->fetch('zoovy:prod_age_range');

	# "Artist"; # The artists who created the product.
	push @columns, $P->fetch('zoovy:prod_artist');

	# "Aspect_Ratio"; # The aspect ratio of the screen. (e.g. 16:9)
	push @columns, $P->fetch('zoovy:prod_aspect_ratio');

	# "Author"; # The author of the book.
	push @columns, $P->fetch('zoovy:prod_author');

	# "Battery_Life"; # The average life of the battery, if the computer is a laptop, in hours.
	push @columns, $P->fetch('zoovy:prod_battery_life');

	# "Binding"; # The binding of the product. (Hardcover, softcover, e.book)
	push @columns, $P->fetch('zoovy:prod_binding');

	# "Capacity"; # For electronic devices, the amount of memory included in a product. For appliances, the volume of space within the appliance.
	push @columns, $P->fetch('zoovy:prod_capacity');

	# "Color_Output"; # Information about whether or not the printer is a color printer.
	push @columns, $P->fetch('zoovy:prod_color_output');

	# "Department"; # The department of a clothing item (e.g. Mens or Womens).
	push @columns, $P->fetch('zoovy:prod_department');

	# "Director"; # The director of the movie.
	push @columns, $P->fetch('zoovy:prod_director');

	# "Display_Type"; # The type of display on the television or monitor (e.g. LCD)
	push @columns, $P->fetch('zoovy:prod_display_type');

	# "Edition"; # The edition of the product. (E.g. Collectors, box set, etc.)
	push @columns, $P->fetch('zoovy:prod_edition');

	# "Focus_Type"; # The type of focus a camera has. (E.g. Auto)
	push @columns, $P->fetch('zoovy:prod_focus_type');

	# "Format"; # Format of the product (e.g. DVD)
	push @columns, $P->fetch('zoovy:catalog');

	# "Genre"; # The genre of the product. (e.g. rock and roll, country)
	push @columns, $P->fetch('zoovy:prod_genre');

	# "Heel_Height"; # The heel height of a shoe.
	push @columns, $P->fetch('zoovy:prod_heel_height');

	# "Height"; # The height of the product.
	push @columns, $P->fetch('zoovy:prod_height');

	# "Installation"; # How a product is installed (e.g. wall.mount)
	push @columns, $P->fetch('zoovy:prod_installation');

	# "Length"; # The length of a product (can be a comma.separated list of the lengths).
	push @columns, $P->fetch('zoovy:prod_length');

	# "Load_Type"; # The type of loading for a washer.
	push @columns, $P->fetch('zoovy:prod_load_type');

	# "Material"; # The material the product is made out of.
	push @columns, $P->fetch('zoovy:prod_material');

	# "Media_Rating"; # The rating of the product. For example, PG.13.
	push @columns, $P->fetch('zoovy:prod_mpaa_rating');

	# "Megapixels"; # The resolution of a digital imaging device.
	push @columns, $P->fetch('zoovy:prod_megapixels');

	# "Memory_Card_Slot"; # The available memory card slots in a printer.
	push @columns, $P->fetch('zoovy:prod_slot_type');

	# "Occasion"; # The special occasion the jewelry is intended for, if applicable.
	push @columns, $P->fetch('zoovy:prod_occasion');

	# "Optical_Drive"; # The type of optical drive included with a computer.
	push @columns, $P->fetch('zoovy:prod_optical_drive');

	# "Pages"; # Number of pages in the book.
	push @columns, $P->fetch('zoovy:prod_pages');

	# "Gaming_Platform"; # The platform the game operates on.
	push @columns, $P->fetch('zoovy:prod_game_platform');

	# "Processor_Speed"; # The processor speed for the product.
	push @columns, $P->fetch('zoovy:prod_processor_speed');

	# "Publisher"; # The publisher of the product.
	push @columns, $P->fetch('zoovy:prod_publisher');

	# "Recommended_Usage"; # Recommended usage of a computer. (e.g. home or office)
	push @columns, $P->fetch('zoovy:prod_recommendedusage');

	# "Screen_Resolution"; # Maxiumum resolution of the screen.
	push @columns, $P->fetch('zoovy:prod_resolution');

	# "Sales_Rank"; # The rank of this product in terms of sales in your store. Lower numbers indicate they are sold more often.
	push @columns, $P->fetch('zoovy:prod_salesrank');

	# "Screen_Size"; # The diagonal screen size. (E.g. 42 inches)
	push @columns, $P->fetch('zoovy:prod_screen_size');

	# "Shoe_Width"; # The widths that a shoe comes in.
	push @columns, $P->fetch('zoovy:prod_shoe_width');

	# "Sizes"; # The sizes that a product comes in (e.g. S,M,L, XL, or shoe sizes)
	push @columns, $P->fetch('zoovy:prod_sizes');

	# "Sizes_In_Stock"; # The sizes that are currently in stock (e.g. 4,7,8,9,11)
	push @columns, $P->fetch('zoovy:prod_sizes_instock');

	# "Subject"; # The subject of a book.
	push @columns, $P->fetch('zoovy:prod_subject');

	# "Tech_Spec_Link"; # The URL of technical specifications of the product, if available. This should not forward to another URL; it must point directly to the target page. The domain name may not be an IP address.
	push @columns, $P->fetch('zoovy:prod_pdf_link');

	# "Width"; # The width of a product (can be a comma separated list of the widths).
	push @columns, $P->fetch('zoovy:prod_width');

	# "Wireless_Interface"; # Wireless interface that the cell phone uses.
	push @columns, $P->fetch('zoovy:prod_interface');

	# "Year"; # The year of the product's issue.
	push @columns, $P->fetch('zoovy:prod_year');

	# "Zoom"; # The maximum amount a camera can zoom. (E.g. 6x)
	push @columns, $P->fetch('zoovy:prod_zoom');

	# "Alt_Image_1"; # URL for alternate image view of product.
	push @columns, $P->fetch('zoovy:prod_image2');

	# "Alt_Image_2"; # URL for alternate image view of product.
	push @columns, $P->fetch('zoovy:prod_image3');

	# "Alt_Image_3"; # URL for alternate image view of product.
	push @columns, $P->fetch('zoovy:prod_image4');

	# "Option_1"; # Reserved for custom feed attributes.
	push @columns, '';

	# "Option_2"; # Reserved for custom feed attributes.
	push @columns, '';

	# "Option_3"; # Reserved for custom feed attributes
	push @columns, '';

	
	my $kill = 0;
	foreach my $c (@columns) {
	   $c =~ s/[\n\r]+//gs;	# strip all cr/lf from data 
		$c =~ s/[\t]+/ /gs;	# tab delimited file - don't allow tabs
		# if ($c =~ /\t/) { $kill++; }
	   }

	if ($kill) { @columns = (); }

	my $status = $csv->combine(@columns);    # combine columns into a string
	my $line = $csv->string();               # get the combined string

	if ($line ne '') {
		$line = "$line\n";
		}

	return($line);
	}
  


##
## this generates a footer_products, it's called by $so after all the products are done.
##  since csv files don't have footer_productss (but XML files do) it can probably output blank.. unless it's xml
## then it should return </endtag> or whatever the ending is. 
sub footer_products {
  my ($self) = @_;
  return("");
  }


1;
