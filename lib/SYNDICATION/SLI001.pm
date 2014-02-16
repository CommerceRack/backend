package SYNDICATION::SLI001;

use strict;

sub new {
  my ($class, $so) = @_;
  my ($self) = {};
  $self->{'_SO'} = $so;
  bless $self, 'SYNDICATION::SLI001';  
  return($self);
  }

sub header_products {
  my ($self) = @_;
  return("<product_list>");
  }

sub so { return($_[0]->{'_SO'}); }
  
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;
  
  my $out = "<product>";
  my %hash = ();
  $hash{'product_name'} = $P->fetch('zoovy:prod_name');
  $hash{'url'} = $OVERRIDES->{'zoovy:link'};
  $hash{'short_des'} = $P->fetch('zoovy:prod_desc');
  $hash{'long_des'} = $P->fetch('zoovy:prod_detail');
  my $USERNAME = $self->so()->{'USERNAME'};
  $hash{'image'} = &ZOOVY::mediahost_imageurl($USERNAME,$P->fetch('zoovy:prod_image1'),0,0,'FFFFFF',0,'jpg'); 
  $hash{'category'} = $P->fetch('sli:category');
  $hash{'sub_category'} = $P->fetch('sli:subcategory');
  $hash{'price'} = $P->fetch('zoovy:base_price');
  $hash{'availability'} = 1;
  $hash{'mfn_no'} = $P->fetch('zoovy:prod_mfgid');
  $hash{'brand'} = $P->fetch('zoovy:prod_mfg');
  foreach my $k (keys %hash) {
    $out .= "<$k>".&ZOOVY::incode($hash{$k})."</$k>\n";
    }
  $out .= "</product>";

  return($out);
  }
  
sub footer_products {
  my ($self) = @_;
  return("</product_list>");
  }


1;