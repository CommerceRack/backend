#!/usr/bin/perl

package SYNDICATION::BIZRATE;

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
use XML::Parser;
use XML::Parser::EasyTree;
use strict;
use LWP::UserAgent;
use Data::Dumper;

use lib "/backend/lib";
require DBINFO;
require ZOOVY;
require XMLTOOLS;


$SYNDICATION::BIZRATE::PARTNERID = '47893023';

sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;

	my ($DOMAIN,$ROOTCAT) = $so->syn_info();

	## addition of ftp integration vs API, 2009-07-22
	my $ftpserv = $so->get('.ftp_server');
	$ftpserv =~ s/ //g;
	my $fuser = $so->get('.ftp_user');
	$fuser =~ s/ //g;
	my $fpass = $so->get('.ftp_pass');
	$fpass =~ s/ //g;
	my $ffile = $so->domain()."-bizrate.txt";
	$so->set(".url","ftp://$fuser:$fpass\@$ftpserv/$ffile");

 
	$self->{'_domain'} = $DOMAIN;
	bless $self, 'SYNDICATION::BIZRATE';  
	return($self);
	}

sub header_products {
	my ($self) = @_;

	$self->{'_csv'} = Text::CSV_XS->new({binary=>1,sep_char=>"\t"});              # create a new object
	my $csv = $self->{'_csv'};

	# http://static.zoovy.com/merchant/froggysfog/TICKET_187764-YahooFieldNameDetails.pdf
	my @columns = ();
	push @columns, "Category";
	push @columns, "Manufacturer";
	push @columns, "Title";
	push @columns, "Description";
	push @columns, "Link";
	push @columns, "Image";
	push @columns, "SKU";
	push @columns, "Quantity on Hand";
	push @columns, "Condition";
	push @columns, "Shipping Weight";
	push @columns, "Shipping Cost";
	push @columns, "Bid";
	push @columns, "Promo Text";
	push @columns, "UPC";
	push @columns, "Price";

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

	my $csv = $self->{'_csv'};

	my ($USERNAME) = $self->so()->username();

	my $c = '';
	#foreach my $k (keys %{$prodref}) {
	#	next if ($k eq 'zoovy:prod_thumb'); 
	#	next if ($k eq 'zoovy:prod_image1');
	#	next if ($k eq 'zoovy:link2');
	#	$prodref->{$k} =~ s/<java.*?>.*?<\/java.*?>//gis;
	#	$prodref->{$k} =~ s/<script.*?<\/script>//gis;
	#	$prodref->{$k} =~ s/<.*?>//gs;
	#	$prodref->{$k} =~ s/[\t]+/ /g;
	#	$prodref->{$k} =~ s/[^\"\w\.\:\:\!\@\#\$\%\^\&\*\(\)\-\+]+/ /g;
	#	}


	## Step 1: figure out hte category
	my $CATEGORY = '';
	if ((defined $P->fetch('bizrate:category')) && ($P->fetch('bizrate:category') ne '')) {
		$CATEGORY = $P->fetch('bizrate:category');
		$CATEGORY =~ s/[^0-9]+//g;
		}
	elsif (defined $OVERRIDES->{'navcat:meta'}) {
		$CATEGORY = $OVERRIDES->{'navcat:meta'};
		$CATEGORY =~ s/[^0-9]+//g;
		}

	##
	## HEY!! if we're not including a product - check this line!
	##
	if ($CATEGORY eq '') { 
		$plm->pooshmsg("VALIDATION|ATTRIB=bizrate:category|+bizrate:category was not set on product, or on navcat");
		return(); 
		}

	# *Category	
	my @columns = ();
	push @columns, "$CATEGORY";

	# Mfr
	my $key = undef;
	if (not defined $key) { $key = $P->fetch('zoovy:prod_mfg'); if ($key eq '') { $key = undef; } }
	if (not defined $key) { $key = $P->fetch('zoovy:prod_mfgid'); if ($key eq '') { $key = undef; } }
	if (not defined $key) { $key = $SKU; }
	push @columns, "$key";

	# *Title
	push @columns, $P->fetch('zoovy:prod_name')."";

	# Description
	## only the first 1000 chars are allowed
	push @columns, SYNDICATION::declaw(substr($P->fetch('zoovy:prod_desc'),0,940)." $SKU");

	# *Link

	## not sure why GOOGLE analytics info has been taken out, this happened to during the move to CUSTOM
	## the actual LINK was also accidently removed
	##

	## LINK readded 2009-05-18 (w/o analytics)
	## $c .= "$LINK/product/$product?META=bizrate-$product$analytics\t";
	push @columns, $OVERRIDES->{'zoovy:link2'};
	
	# Image
	if ($P->thumbnail($SKU) =~ /http[s]:/) {
		## http://www.someimage.com
		push @columns, $P->thumbnail($SKU);
		}
	elsif ($P->thumbnail($SKU)) {
		push @columns, &ZOOVY::mediahost_imageurl($USERNAME,$P->thumbnail($SKU),0,0,'FFFFFF',0,'jpg');
		}
	else {
		push @columns, '';
		}

	# *SKU
	my $BSKU = undef;
	if ((defined $P->fetch('zoovy:prod_mfgid')) && ($P->fetch('zoovy:prod_mfgid') ne '')) { $BSKU = $P->fetch('zoovy:prod_mfgid'); }
	if ((defined $P->fetch('zoovy:prod_isbn')) && ($P->fetch('zoovy:prod_isbn') ne '')) { $BSKU = $P->fetch('zoovy:prod_isbn'); }
	if ((defined $P->fetch('zoovy:prod_upc')) && ($P->fetch('zoovy:prod_upc') ne '')) { $BSKU = $P->fetch('zoovy:prod_upc'); }
	push @columns, $BSKU;

	# qty on Hand	
	my $QTY = $OVERRIDES->{'zoovy:qty_instock'};
	if ((not defined $QTY) || ($QTY == 0)) { 
		push @columns, "0"; 
		} 
	else {
		push @columns, "In Stock"; 
		}

	# Condition	
	push @columns, (($P->fetch('zoovy:prod_condition') ne '')?$P->fetch('zoovy:prod_condition'):'New');

	# Ship. Weight	
	## is this supposed to be in pounds or ounces?
	push @columns, sprintf("%.1f",&ZSHIP::smart_weight($P->fetch('zoovy:base_weight'))/16);

	# Ship. Cost	
	push @columns, $P->fetch('zoovy:ship_cost1')."";

	# Bid	
	push @columns, $P->fetch('bizrate:bid')."";

	# Promo Designation
	push @columns, SYNDICATION::declaw((($P->fetch('shopzilla:promo_text') ne '')?$P->fetch('shopzilla:promo_text'):""));

	# Other notes
	## BizRate now want UPC in this field, requires it to numerical or blank
	## patti - 09/20/2006
	## (set to blank if any non-digits)
	push @columns, (($P->fetch('zoovy:prod_upc') =~ m/\D+/)?'':$P->fetch('zoovy:prod_upc'));

	# *Price	
	print STDERR "Adding price:".$P->fetch('zoovy:base_price')." ".sprintf("%.2f",$P->fetch('zoovy:base_price'))."\n"; 
	push @columns, sprintf("%.2f",$P->fetch('zoovy:base_price'));

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


##
## API is no longer used, integration has been switched to ftp
##
#sub upload_old {
#	my ($self) = @_;
#
#	my $so = $self->so();
#
#	my $USERNAME = $so->get('USERNAME');
#	my $PROFILE = $so->get('PROFILE');
#
#	my %params = ();
#	$params{'username'} = $so->get('.user');
#	$params{'password'} = $so->get('.pass');
#	$params{'feed_location'} = "http://static.zoovy.com/merchant/".(lc($USERNAME))."/".$so->filename();
#
#	my ($bmid,$bresult,$ERR) = &SYNDICATION::BIZRATE::apiRequest($so,'set_http_account',\%params);
#	if ($bmid == 0) {
#		## indicates an internal error.
#		print STDERR "BMID: $bmid BRESULT: $bresult ERROR: $ERR\n";
#		}
#	elsif ($bmid>0) {
#		## success!
#		}
#
#	return($ERR);	
#	}


##
## API is no longer used, integration has been switched to ftp
## 
sub apiRequest {
	my ($so,$VERB,$params) = @_;

	if (ref($so) ne 'SYNDICATION') { 
		die("Attempted to do API request with non-syndication object");
		}
 
	if (not defined $params) { $params = {}; }
 
	my $URL = "http://merchant.shopzilla.com/sag";
	
	my $xml = qq~<?xml version="1.0" encoding="utf-8"?><SARequest partnerid="$SYNDICATION::BIZRATE::PARTNERID"><action function="$VERB">\n~;
	foreach my $k (keys %{$params}) {
		$xml .= "<$k>".&ZOOVY::incode($params->{$k})."</$k>\n";
		}
	$xml .= qq~</action></SARequest>~;
	print "XML: $xml\n";

	my $header = HTTP::Headers->new;
	my $agent = LWP::UserAgent->new;
	my $result =	$agent->request(HTTP::Request->new("GET", "$URL?xml=$xml", $header));
	print Dumper($result);
	
	my $t = {};
	my $mid = 0;
	my $bresult = 0;
	my $ERROR = '';
	if ($result->content() eq '') {
		$mid = 0; $ERROR = 'No response from bizrate';
		}
	elsif ($result->content() !~ /^\<\?xml/) {
		$mid = 0; $ERROR = 'Non xml response returned from bizrate';
		}
	else {
		my $p = new XML::Parser(Style=>'EasyTree');
 	 my $tree = $p->parse($result->content());
 	 #$tree = $tree->[0];
 	 #print Dumper($tree);
	 $t = &XMLTOOLS::easytree_flattener($tree);	
	}

	if ($t->{'SAResponse.exception'} eq 'unknown_merchant') {
		$mid = -1; $ERROR = 'Bizrate says Unknown Merchant';
		}
	elsif ($t->{'SAResponse.result.mid'}) {
		$mid = $t->{'SAResponse.result.mid'};
		# a job will always be created if the login and password are validated
		if ($t->{'SAResponse.result.account_status_ok'} ne 'yes') { $bresult += 4; $ERROR = 'Bizrate account status needs to be checked.'; }
		# .yes. if: merchant revenue status is CPC (2) or (rev status is NR (3) and balance > $50)
		if ($t->{'SAResponse.result.job_created'} ne 'yes') { $bresult += 2; $ERROR = 'Bizrate says account not funded.'; }
		# -check login/password against merchant login table	
		if ($t->{'SAResponse.result.account_exists'} ne 'yes') { $bresult += 1; $ERROR = 'Invalid username/password'; }
		print STDERR Dumper($t)."\n";
		}
	else {
		$mid = -1; $ERROR = 'Bizrate says account does not exist!'; 
		}
	
	print STDERR "MID: $mid ERROR: $ERROR\n";

	return($mid,$bresult,$ERROR);	
	}


1;
