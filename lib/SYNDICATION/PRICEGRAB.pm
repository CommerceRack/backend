#!/usr/bin/perl

package SYNDICATION::PRICEGRAB;

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
##
##
sub fields {
	my $fields = [
	{ id=>'pricegrabber:masterid', type=>'textbox', title=>'PriceGrabber MasterID', },
	{ id=>'zoovy:prod_name', },
	{ id=>'zoovy:base_price', },
	{ id=>'pricegrabber:saleqty', type=>'numeric', title=>'Sale Qty', },
	{ id=>'zoovy:prod_image1', },
	{ id=>'pricegrabber:condition', type=>'textbox', title=>'Pricegrabber Condition', },
	{ id=>'zoovy:prod_desc', },
	{ id=>'zoovy:prod_mfg',  },
	{ id=>'zoovy:prod_mfgid', },
	{ id=>'zoovy:prod_upc',  },
	{ id=>'zoovy:prod_isbn',  },
	{ id=>'zoovy:ship_cost1', },
	{ id=>'zoovy:base_weight', },
	{ id=>'zoovy:prod_height',  },
	{ id=>'zoovy:prod_width', },
	{ id=>'zoovy:prod_length', },
	{ id=>'pricegrabber:url', type=>'hidden', title=>'URL to Product (uses zoovy:link2)', },
	{ id=>'pricegrabber:category', type=>'textbox', title=>'Pricegrabber Category', },
	{ id=>'pricegrabber:availability', type=>'hidden', title=>'Availability (uses zoovy:qty_instock)', },
	];
	
	return($fields);
	}


sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;

   tie my %s, 'SYNDICATION', THIS=>$so;
	
	$self->{'@ATTRIBS'} = [];
	foreach my $f (@{&SYNDICATION::PRICEGRAB::fields()}) {
		push @{$self->{'@ATTRIBS'}}, $f->{'id'};
		}


	$so->set('.url',sprintf("ftp://%s:%s\@ftp.pricegrabber.com/%s.csv",$s{'.user'},$s{'.pass'},$s{'.user'}));
	bless $self, 'SYNDICATION::PRICEGRAB';  
	untie %s;

	## this functionality should work for any marketplace using the number-generated category values
	require SYNDICATION::CATEGORIES;
	$self->{'%CATEGORIES'} = SYNDICATION::CATEGORIES::CDSasHASH("PGR",">");
				

	return($self);
	}

##
##
##
sub header_products {
	my ($self) = @_;

	#$self->{'_csv'} = Text::CSV_XS->new({binary=>1,sep_char=>"\t"});              # create a new object
	$self->{'_csv'} = Text::CSV_XS->new({binary=>1});              # create a new object
	my $csv = $self->{'_csv'};

	# http://static.zoovy.com/merchant/froggysfog/TICKET_187764-YahooFieldNameDetails.pdf
	my $HEADER = '%PRODUCT,';
	foreach my $attrib (@{$self->{'@ATTRIBS'}}) { 
		## some headers shouldn't be imported.
		if (($attrib eq 'zoovy:prod_image1') || 
			 ($attrib eq 'zoovy:prod_name') ||
			 ($attrib eq 'zoovy:prod_desc')) { 
			$HEADER .= '!'.$attrib.','; 
			}
		else {
			$HEADER .= $attrib.','; 
			}
		}
	chop($HEADER);
	return($HEADER."\n");
	}

sub so { return($_[0]->{'_SO'}); }


##
##
##  
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my $csv = $self->{'_csv'};

	my $USERNAME = $self->so->username();

	my $CATEGORY = undef;
	if (defined $P->fetch('pricegrabber:category')) {
		## if they set pricegrabber:category in the product, use that!
		$CATEGORY = $P->fetch('pricegrabber:category');
		}
	elsif ($P->fetch('navcat:meta') =~ /^\d+$/) {
		$CATEGORY = $self->{'%CATEGORIES'}->{ $P->fetch('navcat:meta') };
		$CATEGORY =~ s/\//>/g;
		}
	else {
		## hmm.. not sure what to do here.
		}

	my @columns = ();
	push @columns, uc($SKU);
	foreach my $attrib (@{$self->{'@ATTRIBS'}}) {
		
		## rewrite rules!
		my %data = ();
		$data{ $attrib } = $P->fetch($attrib);

		if ($attrib eq 'pricegrabber:condition') {
			if ($data{$attrib} eq '') { $data{$attrib} = $P->fetch('pricegrabber:prod_condition'); }
			if ($data{$attrib} eq '') { $data{$attrib} = $P->fetch('zoovy:prod_condition'); }
			}
		if ($attrib eq 'zoovy:base_price') {
			$data{$attrib} = sprintf("%.2f",$P->fetch('zoovy:base_price'));
			}
		
		if ($attrib eq 'zoovy:base_weight') {
			$data{$attrib} = sprintf("%.2f",ZSHIP::smart_weight($data{$attrib})/16);
			}
		
		if ($attrib eq 'pricegrabber:saleqty') {
			## we should eventually do some more inventory stuff here!
			# $data{$attrib} = $qty;
			}

		if ($attrib eq 'pricegrabber:availability') {
			$data{$attrib} = ($OVERRIDES->{'zoovy:qty_instock'})?'Yes':'No';
			}

		## yeah, we'll need this!
		# $data{'pricegrabber:url'} = "http://$merchant.zoovy.com/product/$pid?meta=PRICEGRABBER";
		# $data{'pricegrabber:url'} = "$LINK/product/$pid?meta=PRICEGRABBER";
		## added product to the end of the link, patti - 2007-04-10

		$data{'pricegrabber:url'} = $OVERRIDES->{'zoovy:link2'};
		# "$LINK/product/$pid?meta=PRICEGRABBER-$pid$analytics";

		## cleanup data
		if ($attrib eq 'zoovy:prod_image1') {
			$data{'zoovy:prod_image1'} = &ZOOVY::mediahost_imageurl($USERNAME,$P->thumbnail($SKU),0,0,'FFFFFF',0,'jpg'); 
			}
		elsif ( ($attrib eq 'zoovy:prod_name') || ($attrib eq 'zoovy:prod_desc')) {
			$data{$attrib} = SYNDICATION::declaw($data{$attrib});
			}
		else {
			$data{$attrib} =~ s/[\n\r]+//gs;
			}

		push @columns, $data{$attrib};
		}

	my $status = $csv->combine(@columns);    # combine columns into a string
	my $line = $csv->string();               # get the combined string
	$line .= "\r\n";
	return($line);
	}

  
sub footer_products {
  my ($self) = @_;
  return("");
  }


1;
