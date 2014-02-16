package SYNDICATION::BUYSAFE;

use strict;


##
## CPC Strategies.net
##

sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;
	bless $self, 'SYNDICATION::BUYSAFE';  

	$so->set('.url',sprintf('ftp://Zoovy:Zoovy_9dd71@feed.buysafe.com/%s.txt',$so->get('.bsstoken')));

	return($self);
	}

sub header_products {
	my ($self) = @_;

	my @columns = ();
	push @columns, 'link'; # The URL of the product page. A product page typically shows the details of a single product, along with a button to buy the product.
	push @columns, 'title'; # The name of the product. Please ensure that the title only includes information about the product and not about anything else. No keyword spamming/stuffing.
	push @columns, 'description'; # A description of the product. Please ensure that the description only includes information about the product and not about anything else. No keyword spamming/stuffing.
	push @columns, 'price'; # The price of the product in U.S. dollars.
	push @columns, 'image_link'; # The URL of an image of the product. For best viewing on buySAFEshopping.com, the image referred to by this URL should be at least 150 pixels wide and 150 pixels high. If a product does not have an image please leave this attribute field blank.
	## The following attributes are recommended wherever applicable, as products with these attributes may appear before products without these attributes in the results for some queries (depending on the product's category):
	push @columns, 'sale_price'; # The price of the product in U.S. dollars. The value of this attribute differs from the value of the price attribute if this product is on sale. In this case, the original price is given for the price attribute and the sale price is given for the sale_price attribute. If the product is not on sale, the sale_price value may be left empty or the sale_price attribute may be equal to the price attribute.
	push @columns, 'brand'; # The brand of the product.
	push @columns, 'breadcrumb'; # A hierarchical description of the category of merchandise the product falls into. Examples:
										  # Clothing > Mens Clothing > Mens Shirts
										  # Appliances > Washing Machines
	push @columns, 'tags'; # Additional keywords describing the product. No more than ten keywords please.
	push @columns, 'department'; # The department of a clothing item (for example, Mens or Womens).
	push @columns, 'model'; # The model name of the product (for example, Powershot SD660).
	push @columns, 'model_number'; # Number given to the model (for example, SD660).
	push @columns, 'mpn'; # Manufacturer's Product Number. The unique number assigned to the product by the manufacturer.
	## Additional Attributes
	## The following attributes are also understood by buySAFEshopping.com:
	push @columns, 'rating'; # How well users rate the product, from 1 to 5, with 5 being the highest rating. The value of this field may be a number (for example, "2" or "5") or may be explicitly "2 stars" or "5 stars".
	push @columns, 'shipping'; # The shipping cost in U.S. dollars.
	push @columns, 'upc'; # Universal Product Code
	push @columns, 'subject'; # The subject of a book.
	push @columns, 'isbn'; # The ISBN number for a book.
	push @columns, 'color'; # A comma-separated list of colors a product comes in. For example, "red,green,teal".
	push @columns, 'condition'; # Whether the product is new or used. Acceptable values for this field include "new", "used", and "refurbished".	

	my $line = join("\t",@columns);

	return($line."\n");
	}

sub so { return($_[0]->{'_SO'}); }
  
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my $USERNAME = $self->{'_SO'}->username();

	my $c = '';
	#foreach my $k ('zoovy:prod_name','zoovy:prod_desc') {
	#	## remove &nbsp;, &amp;
	#	$prodref->{$k} =~ s/\&.*?\;/ /gs;
	#	$prodref->{$k} =~ s/<java.*?>.*?<\/java.*?>//gis;
	#	$prodref->{$k} =~ s/<script.*?<\/script>//gis;
	#	$prodref->{$k} =~ s/<.*?>//gs;
	#	$prodref->{$k} =~ s/[\t]+/ /g;
	#	$prodref->{$k} =~ s/[^\"\w\.\:\:\!\@\#\$\%\^\&\*\(\)]+/ /g;
	#	}
   # foreach my $k ('zoovy:link','zoovy:base_price','zoovy:prod_image1','zoovy:prod_mfg','zoovy:prod_category',
   #   'zoovy:keywords','zoovy:prod_mfgid','zoovy:ship_cost1','zoovy:prod_upc','zoovy:prod_condition') {
   #   $prodref->{$k} =~ s/[\t\n\r]+/ /gs;
   #   }

	my @COLS = ();

	## link
	## not sure what bss:content/campaign should be
	my $analytics = '';
	#if ($nsref->{'analytics:syndication'} eq 'GOOGLE') {
	#	$analytics = sprintf("&utm_source=BSS&utm_medium=CPC&utm_content=%s&utm_campaign=%s",
	#		$prodref->{'bss:content'},$prodref->{'bss:campaign'});
	#	}
	push @COLS, $OVERRIDES->{'zoovy:link2'}; # ."?meta=bss-$pid$analytics";
	## title
	push @COLS, &SYNDICATION::declaw($P->fetch('zoovy:prod_name'));
	## description
	push @COLS, &SYNDICATION::declaw($P->fetch('zoovy:prod_desc'));
	## price
	push @COLS, &SYNDICATION::declaw($P->skufetch($SKU,'zoovy:base_price'));
	## image_link
	push @COLS, &ZOOVY::mediahost_imageurl($USERNAME,$P->fetch('zoovy:prod_image1'),0,0,'FFFFFF',0,'jpg');	 
	## sale_price
	push @COLS, &SYNDICATION::declaw($P->fetch('zoovy:base_price'));
	## brand
	push @COLS, &SYNDICATION::declaw($P->fetch('zoovy:prod_mfg'));
	## breadcrumb
	push @COLS, &SYNDICATION::declaw($OVERRIDES->{'navcat:prod_category'});
	## tags
	push @COLS, &SYNDICATION::declaw($P->fetch('zoovy:keywords'));	
	## mpn
	push @COLS, &SYNDICATION::declaw($P->fetch('zoovy:prod_mfgid'));
	## rating - let's just send 4stars???
	push @COLS, 5;
	## shipping
	push @COLS, &SYNDICATION::declaw($P->fetch('zoovy:ship_cost1'));
	## upc
	push @COLS, &SYNDICATION::declaw($P->skufetch($SKU,'zoovy:prod_upc'));
	## condition
	push @COLS, &SYNDICATION::declaw($P->fetch('zoovy:prod_condition'));

	return(join("\t",@COLS)."\n");
	}
  
sub footer_products {
  my ($self) = @_;
  return("");
  }


1;