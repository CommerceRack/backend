#!/usr/bin/perl

package SYNDICATION::NEWEGG;

### 
## NEWEGG.pm
##  ftp transfer
## - only building for inventory syndication
## - product syndication may be built later
## - uses ftp to transfer inv files
##
## per docs
######
##	2. Inventory Update File. This file can help update item.s inventory, price, shipping and activation settings. 
##	Seller can download the Batch Inventory Update file through Seller Portal -> Batch Upload Inventory function. 
##	Seller can choose to download the template with items populated in the file or just an empty template. 
##	Please do not alter the file.s sheets. names and format within the file. Simply fill in the necessary information 
##	in the .BatchInventoryAndPriceUpdate. sheet.
##
##	Once seller downloads the template and is done updating the item price / inventory information, rename the file to:
##
##		BatchInventoryUpdate_YYYYMMDD_HHMMSS.xls
##
##	Once the file is renamed, upload file to Inbound folder -> Inventory subfolder on FTP and Newegg system will
##	process the file.
##
##	When Newegg system is done processing the file, it will create a result file in the Outbound folder -> Inventory 
##	subfolder with the following format:
##
##	Result_ BatchInventoryUpdate_YYYYMMDD_HHMMSS.xls
##
##	Seller can download this file to see the item inventory update result. 
#####

use strict;
use lib "/backend/lib";
use Data::Dumper;
use XML::Writer;
use POSIX qw(strftime);

##
##
##
sub new {
	my ($class, $so) = @_;

	if (not defined $so) {
		die("No syndication object");
		}

	my ($self) = {};
	$self->{'_SO'} = $so;

	my $ftpserv = $so->get('.ftp_server');
	$ftpserv =~ s/ //g;
	if ($ftpserv =~ /^ftp\:\/\//i) { $ftpserv = substr($ftpserv,6); }

	my $fuser = $so->get('.ftp_user');
	$fuser =~ s/ //g;

	my $fpass = $so->get('.ftp_pass');
	$fpass =~ s/ //g;

	## couldnt find in docs what these files should be called
	if ($so->{'%options'}->{'type'} eq 'inventory') {
		my $remotefile = strftime("BatchInventoryUpdate_%Y%m%d_%H%M%S.csv",localtime());
		$so->set(".url","ftp://$fuser:$fpass\@$ftpserv/Inbound/Inventory/$remotefile");
		# $so->addsummary('NOTE',NOTE=>qq~check inventory feed results: <a href="ftp://$fuser:$fpass\@$ftpserv/Outbound/Inventory/Result_~.$remotefile.qq~">$remotefile</a>~);	
		}
	else {
		$so->set(".url","ftp://$fuser:$fpass\@$ftpserv/Inbound");
		}


	bless $self, 'SYNDICATION::NEWEGG';  

	return($self);
	}

## only doing inventory syndication
sub header_inventory {
	my ($self) = @_;

	my $csv = "Seller Part #,NE Part #,Currency,Selling Price,Inst Rebate,Inventory,Shipping,Activation Mark\n";

	return($csv);
	}

##
## not used, ie no current product syndication
sub header_products {
	my ($self) = @_;
	
   return(undef);
	}

sub so { return($_[0]->{'_SO'}); }

##
##
sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	## format:
	##		field, prod_name, validation
	my $ERROR = '';

	## check newegg:ts
	if ($ERROR) {}
	elsif ($P->fetch('newegg:ts')<1) {
		$ERROR = "VALIDATION|ATTRIB=newegg:ts|+newegg:ts is not enabled .. cannot syndicate";
		}
	elsif (length($SKU) > 20) {
		$ERROR = "VALIDATION|+SKU length is too long: ".length($SKU);
		}
#	elsif ($pid =~ m/[^a-zA-Z0-9-]/) {
#		$ERROR = "{pid}only alphanumberic chars plus and - are allowed in PID: ".$pid;
#		}
	
	if ($ERROR ne '') {
		## just kidding!
		if ($self->so()->get('.ignore_validation')) { $ERROR = ''; }
		}
	return($ERROR);
	}

  
##
##
sub inventory {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	## if the inventory is negative or not defined, set it to 0
	if ($OVERRIDES->{'zoovy:qty_instock'} < 0 || $OVERRIDES->{'zoovy:qty_instock'} eq '') {
		$OVERRIDES->{'zoovy:qty_instock'} = 0;
		}

	##*Shipping => What kind of Shipping setting for the item, the available two options are default and free
	my $shipping = 'default';
	if ($P->fetch('newegg:shipping_type') ne '') {
		$shipping = $P->fetch('newegg:shipping_type');
		}

	my $price = '';
	if ($OVERRIDES->{'zoovy:base_price'}) {
		$price = $OVERRIDES->{'zoovy:base_price'};
		}
	else {
		$price = $P->fetch('zoovy:base_price');
		}


	## create CSV 
	## note: required fields (*), Price is required... this could cause issues if the merchant manually creates a product
	##		on newegg wanting a different price than the one on Zoovy (add functionality for newegg:base_price, if needed)	
	my $output = 	"$SKU,".											## *Seller Part #
						",".												##  NE Part #
						",".												##  Currency
						$price.",".										## *Price
						",".												##  Instant Rebate
						$OVERRIDES->{'zoovy:qty_instock'}.",".	## *Inventory
						$shipping.",".									## *Shipping => What kind of Shipping setting for the item, the available two options are default and free
						"\n";												##  Activation Mark

	return($output);
	}

##
## this is used to implicitly delete inventory.
##
## note: switched off, process was sending an inventory for all products... 
##
#sub INVENTORY_DELETE_NOT_WORKING {
#	my ($self,$SKU,$stash,$was_processed) = @_;
#
#	my ($so) = $self->so();
#	$so->pooshmsg("INFO|+$SKU is deleted/blocked, sending 0 as qty");
#
#	$prodref->{'zoovy:qty_instock'} = 0;
#
#	my ($xCBL) = $self->inventory($SKU,$prodref);
#
#	return($xCBL);
#	}
  

##
##
## not currently used 
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my $ERROR = undef;
	my $xCBL = '';
	return($xCBL);
	}



##
## logs an internal NEWEGG error.
##
sub log {
  my ($self,$pid,$err) = @_;

  if (not defined $self->{'@errs'}) {
    $self->{'@errs'} = [];
    }
  push @{$self->{'@errs'}}, $err;
  return();
  }


  
sub footer_products {
	my ($self) = @_;

	return(undef);
	}

  
sub footer_inventory {
	my ($self) = @_;

	return(undef);
	}


1;
