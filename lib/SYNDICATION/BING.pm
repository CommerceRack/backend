#!/usr/bin/perl

package SYNDICATION::BING;
require SYNDICATION::CATEGORIES;


# 10/29/10 http://static.zoovy.com/merchant/barefoottess/TICKET_0-Bing_Shopping_program_Merchant_Integration_Guide_October_2010.pdf


use strict;
use lib "/backend/lib";
use DBINFO;
use ZOOVY;
use NAVCAT;
use NAVCAT::FEED;
use ZSHIP;
use ZTOOLKIT;
use SYNDICATION;




sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;

   tie my %s, 'SYNDICATION', THIS=>$so;

	$s{'.ftp_server'} = 'feeds.adcenter.microsoft.com';
	
	## 2008-06-27 - patti
	## changed per ticket 174182.
	# $so->set('.url',sprintf("ftp://%s:%s\@%s%s/cashback.txt",$s{'.ftp_user'},$s{'.ftp_pass'},$s{'.ftp_server'},$s{'.ftp_dir'}));
	$so->set('.url',sprintf("ftp://%s:%s\@%s%s/bingshopping.txt",$s{'.ftp_user'},$s{'.ftp_pass'},$s{'.ftp_server'},$s{'.ftp_dir'}));
	bless $self, 'SYNDICATION::BING';  
	untie %s;

	return($self);
	}

##
##
##
sub header_products {
	my ($self) = @_;

	$self->{'_csv'} = Text::CSV_XS->new({binary=>1,quote_char=>"",escape_char=>"",sep_char=>"\t"});              # create a new object
	my $csv = $self->{'_csv'};

	my ($CDS) = SYNDICATION::CATEGORIES::CDSLoad('BIN','/');
	$self->{'_cds'} = $CDS;

	my @columns = ();
	push @columns, 'MerchantProductID';
	push @columns, 'Title';
	push @columns, 'BrandorManufacturer';
	push @columns, 'MPN';
	push @columns, 'UPC';
	push @columns, 'ISBN';
	push @columns, 'SKU';
	push @columns, 'ProductURL';
	push @columns, 'Price';
	push @columns, 'Availability';
	push @columns, 'Description';
	push @columns, 'ImageURL';
	push @columns, 'Shipping';
	push @columns, 'MerchantCategory';
	push @columns, 'ShippingWeight';
	push @columns, 'Condition';
	push @columns, 'BingCategory';

	my $status = $csv->combine(@columns);    # combine columns into a string
	my $line = $csv->string();               # get the combined string
	return($line."\r\n");
	}

sub so { return($_[0]->{'_SO'}); }


sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	my ($ERROR) = undef; 
	my $CDS = $self->{'_cds'};

	my $prodref = $P->prodref();

	## validate title, don't allow "discontinued" descriptor in the title
	my $title = '';
	if (defined $prodref->{'bing:prod_name'}) { $title = $prodref->{'bing:prod_name'}; }
	elsif ($prodref->{'zoovy:prod_name'}) { $title = $prodref->{'zoovy:prod_name'}; }
	if ($title =~ /discontinued/i) {
		$ERROR = "ERROR|ATTRIB=zoovy:prod_name|+Product name has word 'discontinued' which causes Bing to ignore it. (use bing:prod_name to specify an alternate bing title)";
		}

	## lookup/validate category
	my $bingcat = $OVERRIDES->{'navcat:meta'};			## new storage method (by number)	
	my $catpath = '';		## this is what we ultimately need to set (it becomes OVERRIDES->bing:categorypath

#	print Dumper($OVERRIDES); die();
	
	if ($ERROR ne '') {
		}
	elsif ($prodref->{'bing:categorypath'} eq '') {
		}
#	elsif ($prodref->{'bing:categorypath'} =~ /Invalid Category/) {
#		$bingcat = 0;			
#		$ERROR = "ERROR|ATTRIB=bing:category|+Bing category set to 'Invalid'";
#		}
	else {
		$catpath = $prodref->{'bing:categorypath'};
		}

	if (($ERROR ne '') || ($catpath ne '')) {
		## something really bad, or really good has already happened.
		}
	elsif ($prodref->{'bing:category'}>0) {
      my ($iref)= SYNDICATION::CATEGORIES::CDSInfo($CDS,$prodref->{'bing:category'});
      my $path = $iref->{'Path'};

      $path =~ s/&gt;/>/gos;
      $path =~ s/ > / > /gos;
      $catpath = $path;
      $path =~ s/[\s]+/ /gos;
      if ($catpath eq '') {
         $ERROR = "ERROR|ATTRIB=bing:category|+Bing category $prodref->{'bing:category'} could not be resolved";
         }		  
		}

	if (($ERROR ne '') || ($catpath ne '')) {
		## something really bad, or really good has already happened.
		}
	elsif (($OVERRIDES->{'navcat:meta'} =~ /^\d+$/) && ($OVERRIDES->{'navcat:meta'}>0)) {
      my ($iref)= SYNDICATION::CATEGORIES::CDSInfo($CDS,$OVERRIDES->{'navcat:meta'});
      my $path = $iref->{'Path'};

      $path =~ s/&gt;/>/gos;
      $path =~ s/ > / > /gos;
      $catpath = $path;
      $path =~ s/[\s]+/ /gos;
      if ($catpath eq '') {
         $ERROR = "ERROR|+Bing category (from navcat) $OVERRIDES->{'navcat:meta'} could not be resolved";
         }		  
		}

	if ($ERROR ne '') {
		}
	elsif ($catpath eq '') {
		$ERROR = "ERROR|ATTRIB=bing:category|+Could not ascertain category in either navigation meta, bing:category, or bing:categorypath field.";
		}
	else {
		$OVERRIDES->{'bing:categorypath'} = $catpath;
		}

	
	# word count isn't relevant
	#if (scalar(split(/[\s]+/,$title))>

	# save money isn't allowed in description:
	# ProductDescription should not contain hard-sell terminology. Use the PromotionalNotes attribute instead.

	## WARNING:
	# * discounted
   # * save money	
	
	## ERRORS:

	# free shipping
	# buy one get one
	# 15% off
	# last chance
	# % left
	# while supplies last

	# giftcards
	# store value
	# coupons

	## conditions: 
	# reconditioned
	# refurbished
	# used
	# great good working
	# REALLY SHOULD BE NEW
	
	## 10/22/09 - travis - if no category is set, this won't show up rank, so no point in failing it.
	if ($ERROR ne '') {
		}
	elsif ($OVERRIDES->{'bing:categorypath'} eq '') {
		$ERROR = "ERROR|ATTRIB=bing:categorypath|+Bing category or category path is not set, cannot include in the file.";
		}

	if ($ERROR) {
		$plm->pooshmsg($ERROR);
		}

	return($ERROR);
	}






##
##
##  
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my $csv = $self->{'_csv'};


	my $c = '';


	my $prodref = $P->prodref();	
#	foreach my $k ('zoovy:prod_name','zoovy:prod_desc') {
#		next if ($k eq 'zoovy:prod_thumb'); 
#		next if ($k eq 'zoovy:prod_image1');
#		## remove &nbsp;, &amp;
#		$prodref->{$k} =~ s/\&.*?\;/ /gs;	
#		$prodref->{$k} =~ s/<java.*?>.*?<\/java.*?>//gis;
#		$prodref->{$k} =~ s/<script.*?<\/script>//gis;
#		$prodref->{$k} =~ s/<.*?>//gs;
#		$prodref->{$k} =~ s/[\t]+/ /g;
#		$prodref->{$k} =~ s/[^\"\w\.\:\:\!\@\#\$\%\^\&\*\(\)]+/ /g;		
#		}

	my @COLS = ();
	push @COLS, $P->pid();
	if ((defined $prodref->{'bing:prod_name'}) && ($prodref->{'bing:prod_name'} ne '')) { 
		push @COLS, &ZTOOLKIT::stripUnicode(&ZTOOLKIT::htmlstrip($prodref->{'bing:prod_name'}));
		}
	else {
		push @COLS, &ZTOOLKIT::stripUnicode(&ZTOOLKIT::htmlstrip($prodref->{'zoovy:prod_name'}));
		}
	
	if ($prodref->{'zoovy:prod_mfg'} eq '') { $prodref->{'zoovy:prod_mfg'} = $self->{'_SO'}->username(); }
	push @COLS, $prodref->{'zoovy:prod_mfg'};
	push @COLS, $prodref->{'zoovy:prod_mfgid'};
	push @COLS, sprintf("%s",$prodref->{'zoovy:prod_upc'});
	push @COLS, $prodref->{'zoovy:prod_isbn'};
	push @COLS, $P->pid();
	push @COLS, $OVERRIDES->{'zoovy:link2'}; #."?meta=jellyfish-$pid&".$prodref->{'zoovy:analytics_data'};
	push @COLS, sprintf("%.2f",$prodref->{'zoovy:base_price'});

	# Availability or StockStatus Recommended
	# The current availability for the offer. Choose only one of following values: In Stock; Out of Stock; Pre-Order; Back-Order
	# Text 0 15 In Stock; Out of Stock; Pre-Order; Back-Order 
	# At least 50% of your offers must be in stock at the time of onboarding.


	if ($OVERRIDES->{'zoovy:qty_instock'}>0) {
		push @COLS, "In Stock";
		}
	else {
		push @COLS, "Out of Stock";
		}

	if ((defined $prodref->{'bing:prod_desc'}) && ($prodref->{'bing:prod_desc'} ne '')) { 
		push @COLS, &ZTOOLKIT::stripUnicode(&ZTOOLKIT::htmlstrip($prodref->{'bing:prod_desc'}));
		}
	else {
		push @COLS, &ZTOOLKIT::stripUnicode(&ZTOOLKIT::htmlstrip($prodref->{'zoovy:prod_desc'}));
		}
	if ($prodref->{'zoovy:prod_thumb'} eq '') {  $prodref->{'zoovy:prod_thumb'} = $prodref->{'zoovy:prod_image1'}; }
	$prodref->{'bing:prod_thumb_url'} = &ZOOVY::mediahost_imageurl($self->so->username(),$prodref->{'zoovy:prod_thumb'},0,0,'FFFFFF',0,'jpg'); 
	push @COLS, $prodref->{'bing:prod_thumb_url'};

	my $shipcost = $prodref->{'bing:ship_cost1'};
	if (not defined $shipcost) { $shipcost = $prodref->{'zoovy:ship_cost1'}; }
	push @COLS, $shipcost;

	push @COLS, $OVERRIDES->{'navcat:bc'};

	$prodref->{'zoovy:base_weight'} = sprintf("%.1f",&ZSHIP::smart_weight_new($prodref->{'zoovy:base_weight'})/16);
	push @COLS, $prodref->{'zoovy:base_weight'};

#	if ($prodref->{'bing:prod_commission'} eq '') {
#		$prodref->{'bing:prod_commission'} = $nsref->{'bing:commission'};
#		}
	push @COLS, $prodref->{'zoovy:prod_condition'};

	## check the validate function for more about how this gets initialized
	if ($OVERRIDES->{'bing:categorypath'} eq '') { 
		$OVERRIDES->{'bing:categorypath'} = 'NOT SET'; 
		$plm->pooshmsg("WARN|override bing:categorypath not set, product will not rank");
		} 
	push @COLS, $OVERRIDES->{'bing:categorypath'};

	foreach my $col (@COLS) {
		$col =~ s/[\n\r]+/ /gs;	# strip hard returns
		$col =~ s/[\s]+/ /gs;	# replace multiple spaces with one
		}


	my $status = $csv->combine(@COLS);    # combine columns into a string
	my $line = $csv->string();               # get the combined string

	if ($line eq '') {
	  use Data::Dumper;
	 #  print Dumper(\@columns);
	  }

	return($line."\r\n");
	}
  
sub footer_products {
  my ($self) = @_;
  return("");
  }


1;
