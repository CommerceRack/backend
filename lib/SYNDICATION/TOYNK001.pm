package SYNDICATION::TOYNK001;


## custom syndication feed for toynk
## XML feed, very similar to GOO
## dstcode => TY1

use Data::Dumper;
use strict;
require SYNDICATION::HELPER;
use URI::Escape::XS;

##
##
##
sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;
	bless $self, 'SYNDICATION::TOYNK001';  

	my $ERROR = '';
	my $ftpserv = $so->get('.ftp_server');
	$ftpserv =~ s/ //g;
	if ($ftpserv =~ /^ftp\:\/\//i) { $ftpserv = substr($ftpserv,6); }
	my $fuser = URI::Escape::XS::uri_escape($so->get('.ftp_user'));
	$fuser =~ s/ //g;
	my $fpass = URI::Escape::XS::uri_escape($so->get('.ftp_pass'));
	$fpass =~ s/ //g;
	my $ffile = $so->get('.ftp_filename');
	$ffile =~ s/ //g;
	$so->set(".url","ftp://$fuser:$fpass\@$ftpserv/$ffile");
  
	$self->{'_NC'} = NAVCAT->new($so->username(),$so->prt());

	if (not defined $so) {
		die("No syndication object");
		}

	@SYNDICATION::TOYNK001::COLUMNS = @{SYNDICATION::HELPER::get_headers($so->dstcode())};

	return($self);
	}

##
##
##
sub header_products {
	my ($self) = @_;

	my $nsref = $self->{'_nsref'};
	my $DOMAIN = $self->{'_domain'};

	my %CHANNEL = ();
	$CHANNEL{'title'} = $nsref->{'zoovy:company_name'};
	$CHANNEL{'description'} = $nsref->{'zoovy:about'};
	$CHANNEL{'link'} = 'http://'.$DOMAIN;

	my $c = '<?xml version="1.0"?>';
   $c .= '<rss version="2.0" xmlns:g="http://base.google.com/ns/1.0">';
   $c .= '<channel>'.&ZTOOLKIT::hashref_to_xmlish(\%CHANNEL,encoder=>'latin1',sanitize=>0)."\n\n";
   return($c);
	}

sub so { return($_[0]->{'_SO'}); }


sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	## format:
	##		field, prod_name, validation
	my $ERROR = undef;


	if (defined $ERROR) {
		}
	## added 2011-10-10
	elsif ($P->fetch('us1:ts') < 1) {
		$ERROR = "VALIDATION|ATTRIB=us1:ts|+User Custom Application 1 must be greater 0";
		}
	elsif ($P->fetch('gbase:sku_name') ne '') {
		if (length($P->fetch('gbase:sku_name'))>70) { $ERROR = "{gbase:sku_name}GoogleBase product name must be less than 70 characters"; 	}
		}
	elsif ($P->fetch('gbase:prod_name') ne '') {
		if (length($P->fetch('gbase:prod_name'))>70) { $ERROR = "{gbase:prod_name}GoogleBase product name must be less than 70 characters"; 	}
		}
	elsif ((defined $P->fetch('zoovy:prod_name')) && ($P->fetch('zoovy:prod_name') eq '')) {
		$ERROR = "{zoovy:prod_name}prod_name required.";
		}
	elsif (length($P->fetch('zoovy:prod_name'))>70) {
		$ERROR = "{zoovy:prod_name}GoogleBase requires product titles shorter than 70 characters, use gbase:prod_name",
		}

	if ($P->fetch('zoovy:prod_upc') ne '') {
		}
	elsif ($P->fetch('gbase:prod_upc') ne '') {
		}
	elsif ($P->fetch('zoovy:prod_mfgid') ne '') {
		}
	elsif ($P->fetch('zoovy:prod_isbn') ne '') {
		}
	elsif ($self->so()->get('.upc_exemption')) { 
		## they told us they have an exemption!
		}
	else {
		$ERROR = "{zoovy:prod_upc}product upc, or mfgid must be set unless Google has given a unique identifier exemption.";
		}



	if (defined $ERROR) {
		}
	elsif ((defined $P->fetch('zoovy:prod_desc')) && ($P->fetch('zoovy:prod_desc') eq '')) {
		$ERROR = "{zoovy:prod_desc}prod_desc required.";
		}

	if (defined $ERROR) {
		}
	elsif ((defined $P->fetch('zoovy:prod_image1')) && ($P->fetch('zoovy:prod_image1') eq '')) {
		$ERROR = "{zoovy:prod_image1}prod_image1 required.";
		}

	if (defined $ERROR) {
		}
	elsif ((not defined $P->fetch('zoovy:base_price')) || ($P->fetch('zoovy:base_price')<=0)) {
		$ERROR = "{zoovy:base_price}base_price required.";
		}

	if (defined $ERROR) {
		}
	elsif ($P->fetch('zoovy:prod_mfg') ne '') {
		}
	elsif ($P->fetch('zoovy:prod_brand') ne '') {
		}
	elsif ($P->fetch('zoovy:prod_publisher') ne '') {
		}
	else {
		$ERROR = "{zoovy:prod_mfg}prod_mfg or prod_publisher is required";
		}

	if ($ERROR ne '') {
		## just kidding!
		if ($self->so()->get('.ignore_validation')) { $ERROR = ''; }
		## group parent, no need to validate, we don't syndicate grp parents
		if ($P->fetch('zoovy:grp_type') eq 'PARENT') { $ERROR = ''; }
		}

	return($ERROR);
	}

  
##
##
##
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	#print "$pid QTY: ".$P->fetch('zoovy:qty_instock')."\n";

	my %SPECIAL = %{$OVERRIDES};

=pod

[[SUBSECTION]%TITLE_WITH_OPTIONS]

the special field %TITLE_WITH_OPTIONS will be set to the description of an inventoriable sku.
[[BREAK]]

The field will be non-blank value under the following conditions:
product has inventoriable options, AND either gbase:prod_name OR zoovy:prod_name are set to non-blank.
The value will be either gbase:prod_name OR zoovy:prod_name (in that order) concatenated with
zoovy:pogs_desc (an auto-generated field) and a space between the fields.  
[[BREAK]]
Example: Deluxe Fluffy Pillow Case Color:Blue
[[BREAK]]
In the example above the zoovy:prod_name is "Deluxe Fluffy Pillow" and one option inventoriable group
was set on the product called "Pillow Case Color" and the option group had at least one option with the 
prompt value "Blue"
[[/SUBSECTION]]

=cut 

	$SPECIAL{'%TITLE_WITH_OPTIONS'} = '';
	if ($P->has_variations('inv')) {
		if ((defined $P->fetch('gbase:prod_name')) && ($P->fetch('gbase:prod_name') ne '')) {
			$SPECIAL{'%TITLE_WITH_OPTIONS'} = sprintf("%s %s",$P->fetch('gbase:prod_name'),$P->fetch('zoovy:pogs_desc'));
			}
		elsif ((defined $P->fetch('zoovy:prod_name')) && ($P->fetch('zoovy:prod_name') ne '')) {
			$SPECIAL{'%TITLE_WITH_OPTIONS'} = sprintf("%s %s",$P->fetch('zoovy:prod_name'),$P->fetch('zoovy:pogs_desc'));
			}		
		}
			

=pod

[[SUBSECTION]%G_SIZE]
if zoovy:prod_width, zoovy:prod_height, and zoovy:prod_length are all set then %G_SIZE will be set to
a concatenated string: zoovy:prod_width+'x'+zoovy:prod_height+'x'+zoovy:prod_length
[[/SUBSECTION]]

=cut

	$SPECIAL{'%G_SIZE'} = '';
	if (($P->fetch('zoovy:prod_width')) && ($P->fetch('zoovy:prod_height')) && ($P->fetch('zoovy:prod_length'))) {
		$SPECIAL{'%G_SIZE'} = $P->fetch('zoovy:prod_width').'x'.$P->fetch('zoovy:prod_height').'x'.$P->fetch('zoovy:prod_length');
		}

	my ($arrayref) = &SYNDICATION::HELPER::do_product($self->so(),\@SYNDICATION::TOYNK001::COLUMNS,\%SPECIAL,$SKU,$P,$plm);

=pod

[[SUBSECTION]gbase:product_type2 .. gbase:product_typeN]
if the attributes gbase:product_type2, gbase:product_type3, etc. are set, they will be appended to the xml
as <g:product_type></g:product_type>
[[/SUBSECTION]]

=cut

	if (not $plm->can_proceed()) {
		}
	else {
		my $i = 2;
		while ((defined $P->fetch('gbase:product_type'.$i)) && ($P->fetch('gbase:product_type'.$i) ne '')) {
			push @{$arrayref}, [ 'product_type', $P->fetch('gbase:product_type'.$i) ];
			$i++;	
			}
		}



=pod

[[SUBSECTION]OPTION XML: include_shippping]
If the zoovy:ship_cost1 (fixed price, first item) shipping cost is set to non-blank, 
AND the syndication option "include shipping" 
is selected in the shipping panel, then the following additional code will be appended to the xml:
[[HTML]]
<g:shipping>
<g:country>US</g:country>
<g:service>Ground</g:service>
<g:price>zoovy:ship_cost1</g:price>
</g:shipping>
[[/HTML]]
[[/SUBSECTION]]

=cut
	
	my $xml = '';	
	foreach my $set (@{$arrayref}) {
		$xml .= sprintf(" <%s>%s</%s>\n",$set->[0],&ZOOVY::incode($set->[1]),$set->[0]);
		}

	if (($P->fetch('zoovy:ship_cost1') ne '') && ($self->so()->get('.include_shipping'))) {
	  $xml .= qq~ <shipping><country>US</country><service>Ground</service><price> ~.$P->fetch('zoovy:ship_cost1') .qq~</price></shipping>\n~;
	  }

	my $out = '';
	if (not $plm->can_proceed()) {
		}
	else {	
		$self->{'_success_ctr'}++;
		$plm->pooshmsg("SUCCESS|+item id=$self->{'_success_ctr'}");
		$out .= "<item id=\"$self->{'_success_ctr'}\">\n".$xml."\n</item>\n";
		}
	return($out);
	}



  
sub footer_products {
  my ($self) = @_;

  return("</channel></rss>");
  }


1;