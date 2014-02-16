#!/usr/bin/perl

package SYNDICATION::SHOPPINGCOM;

use strict;
use lib "/backend/lib";
use DBINFO;
use ZOOVY;
use NAVCAT;
use NAVCAT::FEED;
use ZTOOLKIT;
use SYNDICATION;


sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;

   tie my %s, 'SYNDICATION', THIS=>$so;
	my $USERNAME = $so->username();

#	my $FILE = "$USERNAME.xml";
#	if ($so->profile() ne 'DEFAULT') { $FILE = sprintf("%s-%s.xml",$USERNAME,$so->profile()); }
	my $FILE = sprintf("%s-%s.xml",$USERNAME,$so->domain());
	
	$so->set('.url',sprintf("ftp://%s:%s\@%s%s/%s",$s{'.ftp_user'},$s{'.ftp_pass'},$s{'.ftp_server'},$s{'.ftp_dir'},$FILE));
	bless $self, 'SYNDICATION::SHOPPINGCOM';  
	untie %s;

	return($self);
	}


sub preflight {
	my ($self, $lm) = @_;

	my $so = $self->{'_SO'};
	if ($so->get('.ftp_server') eq '') {
		$lm->pooshmsg("ERROR|+FTP Server not set. Please check your configuration");
		}	
	}



sub header_products {
	my ($self) = @_;

	my $xml = '';
	$xml .= "<?xml version=\"1.0\"?>\n";	
	$xml .= "<Products>\n";
	$xml .= "<!-- File generated ".&ZTOOLKIT::pretty_date(time(),1)." -->\n";
	return($xml);
	}


sub footer_products {
	my ($self) = @_;
	return("</Products>\n");
	}

sub so { return($_[0]->{'_SO'}); }

##
##
##  
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my $c = '';
	my $USERNAME = $self->so()->username();

	my $DEBUG = 0;
	if ($self->so()->is_debug($SKU)) {
		$DEBUG++;
		}


	## check current inventory using inv and reserve values
	if ($OVERRIDES->{'zoovy:qty_instock'} > 0) { 
		$OVERRIDES->{'shopping:inventory'} = 'Y'; 
		}
	## check if inventory is set to unlimited
	else{
		$OVERRIDES->{'shopping:inventory'} = 'N';
		}


	## Step 1: figure out the category
	my $CATEGORY = undef; 
	if (($P->fetch('shopping:category') ne '') && (defined $P->fetch('shopping:category'))) {
		$CATEGORY = $P->fetch('shopping:category');
		if ($DEBUG) {
			$plm->pooshmsg("INFO|+Category($CATEGORY) loaded from shopping:category\n");
			}
		}
	elsif (defined $OVERRIDES->{'navcat:meta'}) {
		$CATEGORY = $OVERRIDES->{'navcat:meta'};
		if ($DEBUG) {
			$plm->pooshmsg("INFO|+Category($CATEGORY) loaded from navigation category (navcat:meta)\n");
			}
		}
	else {
		$plm->pooshmsg("ERROR|+Required category($CATEGORY) was not set and is undef.\n");
		}

	if (defined $P->fetch('zoovy:prod_condition')) { $OVERRIDES->{'shopping:prod_condition'} = $P->fetch('zoovy:prod_condition'); }
	$OVERRIDES->{'shopping:prod_condition'} = 'New';

	my @fields = ();
	push @fields,	{ 'id'=>'mpn', try=>'shopping:prod_mfgid|zoovy:prod_mfgid', };
	push @fields,	{ 'id'=>'upc', try=>'shopping:prod_upc|zoovy:prod_upc', };
	push @fields,	{ 'id'=>'manufacturer', try=>'shopping:prod_mfg|zoovy:prod_mfg', };
	push @fields,	{ 'id'=>'ProductName', try=>'shopping:prod_name|zoovy:prod_name', };
	push @fields,	{ 'id'=>'ProductDescription', try=>'shopping:prod_desc|zoovy:prod_desc', };
	push @fields,	{ 'id'=>'Price', try=>'shopping:base_price|zoovy:base_price', };
	push @fields,	{ 'id'=>'Condition', try=>'shopping:prod_condition|zoovy:prod_condition', };

	push @fields,	{ 'id'=>'Stock', data=>($OVERRIDES->{'zoovy:qty_instock'}>0)?'Y':'N' };
	push @fields,	{ 'id'=>'ImageUrl', data=> &ZOOVY::mediahost_imageurl($USERNAME,$P->thumbnail($SKU),0,0,'FFFFFF',0,'jpg') };
	# push @fields,	{ 'id'=>'Image', data=> &ZOOVY::mediahost_imageurl($USERNAME,$P->thumbnail($SKU),0,0,'FFFFFF',0,'jpg') };
	push @fields,	{ 'id'=>'Category', data=>$CATEGORY };
	push @fields,	{ 'id'=>'Zip', try=>'shopping:prod_origin_zip|zoovy:prod_origin_zip', };

	if ($P->fetch('shopping:ship_ground') ne '') {
		push @fields, { 'id'=>'ShippingCost', try=>'shopping:ship_ground' };
		}
	elsif ($P->fetch('zoovy:ship_cost1') ne '') {
		push @fields, { 'id'=>'ShippingCost', try=>'zoovy:ship_cost1' };
		}
	else {
		## Zone based shipping.
		## changed to pounds per ticket 149017 & docs
		## (https://merchant.shopping.com/sc/docs/Feed_Uploading_Specifications.pdf)
		#$P->fetch('zoovy:base_weight') = &ZSHIP::smart_weight_new($prodref->{'zoovy:base_weight'});
		my $WEIGHT_IN_POUNDS = sprintf("%.1f",&ZSHIP::smart_weight_new($P->fetch('zoovy:base_weight'))/16);
		push @fields, { 'id'=>'Weight', data=>$WEIGHT_IN_POUNDS };

		if ($P->fetch('zoovy:prod_origin_zip') ne '') {
			push @fields, { 'id'=>'Zip', try=>'shopping:prod_origin_zip,zoovy:prod_origin_zip' },
			}
		}


	my $xml = '';
	if ($plm->can_proceed()) {
		$xml .= '<Product>';
		$xml .= "<MerchantSKU>".$SKU."</MerchantSKU>\n";
		# $xml .= "<ProductURL>".ZOOVY::incode($prodref->{'zoovy:link2'}."?meta=shopping-$pid&".$prodref->{'zoovy:analytics_data'})."</ProductURL>\n";
		$xml .= "<ProductURL>".ZOOVY::incode($OVERRIDES->{'zoovy:link2'})."</ProductURL>\n";
		foreach my $field (@fields) {
			my $data = undef;
			if (defined $field->{'data'}) { $data = $field->{'data'}; }
			if (defined $field->{'try'}) {
				foreach my $k (split(/\|/,$field->{'try'})) {
					if (not defined $data) { $data = $OVERRIDES->{$k}; }
					if (not defined $data) { $data = $P->fetch($k); }
					}
				}
			next if (not defined $data);
	
			## added stripUnicode, 20090127
			#$xml .= "<$field>".&ZOOVY::incode($data)."</$field>";		
			$xml .= "<".$field->{'id'}.">".&ZOOVY::incode(&ZTOOLKIT::stripUnicode($data))."</".$field->{'id'}.">";		
			}	
		$xml .= "</Product>\n";
		}

	return($xml);
	}


1;
