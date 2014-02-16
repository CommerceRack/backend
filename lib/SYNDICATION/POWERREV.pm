package SYNDICATION::POWERREV;

use Text::CSV_XS;
use lib "/backend/lib";
require SITE; 
use strict;


##
## Power Reviews
##

sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;
	$so->set('.url','site://'.$so->profile().'-powerreviews.txt');
	bless $self, 'SYNDICATION::POWERREV';  
	return($self);
	}

sub header_products {
	my ($self) = @_;

	$self->{'_csv'} = Text::CSV_XS->new({binary=>1,sep_char=>"\t"});              # create a new object
	my $csv = $self->{'_csv'};

	my @columns = ();
	push @columns, 'link'; #  URL to the product detail page.
	push @columns, 'id'; #  A unique identifier for the page being reviewed.typically your style number, item name, or UPC. To ensure that reviews are grouped together for similar products (which may be different sizes or colors), reviews are associated with a Page ID.
	push @columns, 'brand'; # The product brand or manufacturer if applicable.
	push @columns, 'title'; #  Display name of the product.
	push @columns, 'description'; # Longer product description, which may include model number or other attributes. May contain HTML.
   push @columns, 'image_link'; # URL to the product image. This should be the highest quality image possible. Thumbnails or images less that 100px by 100px should only be used if a high-resolution image is not available.
   push @columns, 'price'; # The current sales prices for the product.
	push @columns, 'category'; # Product category of the product being reviewed. Show the category as a hierarchy, separated by the .>. character (e.g. Cameras > Digital Cameras > SLRs).
   push @columns, 'quantity'; # Quantity of stock available, or alternatively, '0' or out-of-stock and '1' for in stock	
	# Recommended Fields
	push @columns, 'model_number'; # The manufacturer-assigned model number.
	push @columns, 'upc';  # The UPC or list of UPC.s for the product.
	push @columns, 'add_to_cart_link'; # 

	my $status = $csv->combine(@columns);    # combine columns into a string
	my $line = $csv->string();               # get the combined string

	return($line."\n");
	}

sub so { return($_[0]->{'_SO'}); }
  
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my $csv = $self->{'_csv'};
	
	my @columns = ();
	push @columns, $OVERRIDES->{'zoovy:link2'};
	push @columns, $SKU;
	push @columns,	$P->fetch('zoovy:prod_mfg');
	push @columns, $P->fetch('zoovy:prod_name');

	my $DESC = $P->fetch('zoovy:prod_desc');
	$DESC = &ZTOOLKIT::wikistrip($DESC);
	$DESC = substr($DESC,0,200);
	push @columns,	$DESC;

	my $USERNAME = $self->so()->{'USERNAME'};
	push @columns, &ZOOVY::mediahost_imageurl($USERNAME,$P->thumbnail($SKU),0,0,'FFFFFF',0,'jpg'); 
	push @columns,	$P->skufetch($SKU,'zoovy:base_price');

	my $CATEGORY = $OVERRIDES->{'navcat:prod_category'};
	$CATEGORY =~ s/\//\>/g;		# power reviews wants > instead of /
   push @columns, $CATEGORY;
	push @columns, 1;

	push @columns, $P->skufetch($SKU,'zoovy:prod_mfgid');
   push @columns, $P->skufetch($SKU,'zoovy:prod_upc');
	push @columns, $P->fetch('zoovy:prod_link_atc');
 
	my $i = scalar(@columns);
	while ($i-->0) {
		$columns[$i] =~ s/[\n\r]+/ /sg;
		$columns[$i] = &ZTOOLKIT::stripUnicode($columns[$i]);
		}
	
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