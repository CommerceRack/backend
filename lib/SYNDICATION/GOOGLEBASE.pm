package SYNDICATION::GOOGLEBASE;

use Data::Dumper;
use strict;
use lib '/backend/lib';
require SYNDICATION::HELPER;
require PRODUCT;

##
##
##
sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;
	bless $self, 'SYNDICATION::GOOGLEBASE';  

	my $ERROR = '';
	my $ftpserv = $so->get('.ftp_server');
	$ftpserv =~ s/ //g;
	if ($ftpserv =~ /^ftp\:\/\//i) { $ftpserv = substr($ftpserv,6); }
	if ($ftpserv !~ /google\.com$/) {
		$ERROR = 'FTP Server must end in .google.com'; 
		}
	my $fuser = $so->get('.ftp_user');
	$fuser =~ s/ //g;
	my $fpass = $so->get('.ftp_pass');
	$fpass =~ s/ //g;
	my $ffile = $so->get('.ftp_filename');
	$ffile =~ s/ //g;
	$so->set(".url","ftp://$fuser:$fpass\@$ftpserv/$ffile");
  
	$self->{'_NC'} = NAVCAT->new($so->username(),$so->prt());

	my $profile = '';
	if ($profile eq '') { $profile = 'DEFAULT'; }
	if (not defined $so) {
		die("No syndication object");
		}
#	my ($DOMAIN,$ROOTCAT,$nsref) = $so->syn_info();
#	$self->{'_nsref'} = $nsref;
#	$self->{'_missing'} = {};
#	$self->{'_domain'} = $DOMAIN;

	@SYNDICATION::GOOGLEBASE::COLUMNS = @{SYNDICATION::HELPER::get_headers($so->dstcode())};

	return($self);
	}

##
##
##
sub header_products {
	my ($self) = @_;

	my $nsref = $self->{'_nsref'};
	my $DOMAIN = $self->{'_domain'};

#	my %CHANNEL = ();
#	$CHANNEL{'title'} = $nsref->{'zoovy:company_name'};
#	$CHANNEL{'description'} = $nsref->{'zoovy:about'};
#	$CHANNEL{'link'} = 'http://'.$DOMAIN;

	# my $c = '<?xml version="1.0"?>';
	my $c = "<?xml version='1.0' encoding='UTF-8' ?>\n";
   $c .= '<rss version="2.0" xmlns:g="http://base.google.com/ns/1.0">';
#   $c .= '<channel>'.&ZTOOLKIT::hashref_to_xmlish(\%CHANNEL,encoder=>'latin1',sanitize=>0)."\n\n";
   $c .= '<channel>'."\n\n";
   return($c);
	}

sub so { return($_[0]->{'_SO'}); }

## NOTE: the line below *DOES NOT* work
#$SYNDICATION::GOOGLEBASE::ATTRIBUTES = [
#	[ 'gbase:sku_name', 'gbase:prod_name', 'zoovy:prod_name', { 'required'=>1, 'maxlength'=>70, 'nb'=>1 } ],
#	];


sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	## format:
	##		field, prod_name, validation
	# i need somethign more complex to describe these relationships!
#	my $ERROR = SYNDICATION::validate($SYNDICATION::GOOGLEBASE::ATTRIBUTES,$prodref);
	my $ERROR = undef;


	## title
	if (defined $ERROR) {
		}
	elsif ($P->fetch('zoovy:sku_name') ne '') {
		if (length($P->fetch('zoovy:sku_name'))>70) { $ERROR = "VALIDATION|+ATTRIB=gbase:sku_name|+GoogleBase product name must be less than 70 characters"; 	}
		}
	elsif ($P->fetch('gbase:prod_name') ne '') {
		if (length($P->fetch('gbase:prod_name'))>70) { $ERROR = "VALIDATION|+ATTRIB=gbase:prod_name|+GoogleBase product name must be less than 70 characters"; 	}
		}
	elsif ((defined $P->fetch('zoovy:prod_name')) && ($P->fetch('zoovy:prod_name') eq '')) {
		$ERROR = "VALIDATION|+ATTRIB=zoovy:prod_name|+prod_name required.";
		}
	elsif (length($P->fetch('zoovy:prod_name'))>70) {
		$ERROR = "VALIDATION|+ATTRIB=zoovy:prod_name|+GoogleBase requires product titles shorter than 70 characters, use gbase:prod_name",
		}


	## gtin or mfgid
	if ($P->fetch('zoovy:prod_upc') ne '') {
		}
	elsif ($P->fetch('gbase:prod_upc') ne '') {
		}
	elsif ($P->fetch('zoovy:prod_mfgid') ne '') {
		}
	elsif ($P->fetch('zoovy:prod_isbn') ne '') {
		}
	elsif ($self->so()->get('.upc_exempt')) { 
		## they told us they have an exemption!
		}
	else {
		$ERROR = "VALIDATION|+ATTRIB=zoovy:prod_upc|+product upc, or mfgid must be set unless Google has given a unique identifier exemption.";
		}


	## description
	if (defined $ERROR) {
		}
	elsif ((defined $P->fetch('zoovy:prod_desc')) && ($P->fetch('zoovy:prod_desc') eq '')) {
		$ERROR = "VALIDATION|+ATTRIB=zoovy:prod_desc|+prod_desc required.";
		}

	## image
	if (defined $ERROR) {
		}
	elsif ((defined $P->fetch('zoovy:prod_image1')) && ($P->fetch('zoovy:prod_image1') eq '')) {
		$ERROR = "VALIDATION|+ATTRIB=zoovy:prod_image1|+prod_image1 required.";
		}

	## price
	if (defined $ERROR) {
		}
	elsif ((not defined $P->fetch('zoovy:base_price')) || ($P->fetch('zoovy:base_price')<=0)) {
		$ERROR = "VALIDATION|+ATTRIB=zoovy:base_price|+base_price required.";
		}

	## mfg/brand
	if (defined $ERROR) {
		}
	elsif ($P->fetch('zoovy:prod_mfg') ne '') {
		}
	elsif ($P->fetch('zoovy:prod_brand') ne '') {
		}
	elsif ($P->fetch('zoovy:prod_publisher') ne '') {
		}
	else {
		$ERROR = "VALIDATION|+ATTRIB=zoovy:prod_mfg|+prod_mfg, prod_brand or prod_publisher is required";
		}

	## apparel attribs: size/color/

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

	my %SPECIAL = %{$OVERRIDES};

=pod


[[SUBSECTION]%TITLE_WITH_OPTIONS]

the special field %TITLE_WITH_OPTIONS will be set to the description of an inventoriable sku.
[[BREAK]]

The field will be non-blank value under the following conditions:
product has inventoriable options, AND either gbase:prod_name OR zoovy:prod_name are set to non-blank.
The value will be either gbase:prod_name, gbase:prod_name_before_options OR zoovy:prod_name (in that order) concatenated with
zoovy:pogs_desc (an auto-generated field) and a space between the fields.  
[[BREAK]]
Example: Deluxe Fluffy Pillow Case Color:Blue
[[BREAK]]
In the example above the zoovy:prod_name is "Deluxe Fluffy Pillow" and one option inventoriable group
was set on the product called "Pillow Case Color" and the option group had at least one option with the 
prompt value "Blue"

[[HINT]]
The decision to display options or not is up to your SEO 
advisor, and this recommendation may change from time to time based on new updates from Google.
At the time this was written googlebase titles must be 70 characters.
Depending on how googlebase indexes a product it may be beneficial (or even required) to have options appear in
the title.  If gbase:prod_name is set then it will be sent and NO OPTIONS will be appended. That means all options
will be sent individually as separate products, but with the same gbase:prod_name title.  
If gbase:prod_name_before_options is set (and non blank) then options will be appended, otherwise the options will
be appended to zoovy:prod_name (which is the default behavior).
[[/HINT]]

[[/SUBSECTION]]


=cut 

	$SPECIAL{'%TITLE_WITH_OPTIONS'} = '';	## constants are required and must be set.
	if ($P->has_variations('inv')) {
		if ((defined $P->fetch('gbase:prod_name_before_options')) && ($P->fetch('gbase:prod_name_before_options') ne '')) {
			$SPECIAL{'%TITLE_WITH_OPTIONS'} = sprintf("%s %s",$P->fetch('gbase:prod_name_before_options'),$SPECIAL{'zoovy:pogs_desc'});
			}
		elsif ((defined $P->fetch('gbase:prod_name')) && ($P->fetch('gbase:prod_name') ne '')) {
			$SPECIAL{'%TITLE_WITH_OPTIONS'} = sprintf("%s %s",$P->fetch('gbase:prod_name'),$SPECIAL{'zoovy:pogs_desc'});
			}
		elsif ((defined $P->fetch('zoovy:sku_name')) && ($P->fetch('zoovy:sku_name') ne '')) {
			$SPECIAL{'%TITLE_WITH_OPTIONS'} = $P->fetch('zoovy:sku_name');
			}		
		elsif ((defined $P->fetch('zoovy:prod_name')) && ($P->fetch('zoovy:prod_name') ne '')) {
			$SPECIAL{'%TITLE_WITH_OPTIONS'} = sprintf("%s %s",$P->fetch('zoovy:prod_name'),$SPECIAL{'zoovy:pogs_desc'});
			}		
		$SPECIAL{'%TITLE_WITH_OPTIONS'} = &ZTOOLKIT::stripUnicode($SPECIAL{'%TITLE_WITH_OPTIONS'});
		$SPECIAL{'%TITLE_WITH_OPTIONS'} =~ s/[\n\r]+/ /gs;
		$SPECIAL{'%TITLE_WITH_OPTIONS'} =~ s/[\s]+/ /gs;
		}
			
=pod


[[SUBSECTION]%IDENTIFIER_EXISTS]

The special field %IDENTIFIER_EXISTS is used to indicate whether the product has an identifier such as a UPC.

The field should only be set if the product does not have an identifier and the merchant has an exemption.

If the product does not have an identifier and 'Google Shopping Account has unique identifer exemption' is set to 'on'
in the Google syndication page, g:identifier_exists will automatically be sent to Google as 'FALSE'
[[BREAK]]

[[HINT]]
Identifier Exemption is usually only given if the merchant is selling custom products
[[/HINT]]

[[/SUBSECTION]]


=cut 

	$SPECIAL{'%IDENTIFIER_EXISTS'} = '';	## constants are required and must be set.
	if ($P->skufetch($SKU, 'zoovy:prod_upc') ne '') {
		}
	elsif ($P->skufetch($SKU, 'gbase:prod_upc') ne '') {
		}
	elsif ($P->skufetch($SKU, 'zoovy:prod_mfgid') ne '') {
		}
	elsif ($P->skufetch($SKU, 'zoovy:prod_isbn') ne '') {
		}
	elsif ($self->so()->get('.upc_exempt')) {
		## they told us they have an exemption!
		$SPECIAL{'%IDENTIFIER_EXISTS'} = 'FALSE';
		}
	else {
		# this should never be reached as the product should already have failed validation.
		}
			

=pod

[[SUBSECTION]%G_DIMENSIONS]
if zoovy:prod_width, zoovy:prod_height, and zoovy:prod_length are all set then %G_DIMENSIONS will be set to
a concatenated string: zoovy:prod_width+'x'+zoovy:prod_height+'x'+zoovy:prod_length
[[/SUBSECTION]]

=cut

	$SPECIAL{'%G_DIMENSIONS'} = '';
	if (($P->fetch('zoovy:prod_width')) && ($P->fetch('zoovy:prod_height')) && ($P->fetch('zoovy:prod_length'))) {
		$SPECIAL{'%G_DIMENSIONS'} = $P->fetch('zoovy:prod_width').'x'.$P->fetch('zoovy:prod_height').'x'.$P->fetch('zoovy:prod_length');
		}

=pod

[[SUBSECTION]%G_ADWORDS_REDIRECT]
A tracking link that includes code to designate adwords as the recipient of htis.
[[/SUBSECTION]]

=cut

	## probably could handle this a bit better -- splitting url, etc.
	if ($SPECIAL{'zoovy:link2'} =~ /^(.*?)\?(.*?)$/) {
		my ($url,$params) = ($1,$2);
		my ($paramsref) = &ZTOOLKIT::parseparams($params);
		$paramsref->{'meta'} = 'GAW';
		$SPECIAL{'%G_ADWORDS_REDIRECT'} = sprintf("%s?%s",$url,&ZTOOLKIT::buildparams($paramsref));
		}
	else {
		## just append ?meta=GAW to link
		$SPECIAL{'%G_ADWORDS_REDIRECT'} = $SPECIAL{'zoovy:link2'}.'?meta=GAW';
		}


=pod

[[SUBSECTION]%IN_STOCK]

the special field %IN_STOCK will be set to the inventory summary of a SKU
[[BREAK]]

if the inventory of the SKU is less than or equal to zero, then send "out of stock"
[[BREAK]]
if the inventory of the SKU is greater than zero, then send "in stock"
[[BREAK]]
Example: -56
[[BREAK]]
Send: out of stock
[[BREAK]]
Example: 109
[[BREAK]]
Send: in stock

If tag "is:preorder" is set to 1, send "pre-order".
If tag "is:specialorder" is set to 1, send "available for order"

[[/SUBSECTION]]

=cut 

	$SPECIAL{'%IN_STOCK'} = 'in stock';
	if ($P->fetch('is:preorder') == 1) {
		$SPECIAL{'%IN_STOCK'} = 'preorder';
		}
#	elsif ($P->fetch('is:backorder') == 1) {
#		$SPECIAL{'%IN_STOCK'} = 'preorder';
#		}
	elsif ($P->fetch('is:specialorder') == 1) {
		$SPECIAL{'%IN_STOCK'} = 'available for order';
		}
	elsif ($SPECIAL{'zoovy:qty_instock'} <= 0) {
		$SPECIAL{'%IN_STOCK'} = 'out of stock';
		}

=pod

[[SUBSECTION]%OPTION_*]

the special field %OPTION_SIZE %OPTION_COLOR %OPTION_MATERIAL %OPTION_PATTERN 
will be set to the size/color/material/pattern of the SKU only used for OPTIONS.

[[/SUBSECTION]]


=cut 

	## SPECIAL OPTION vars
	my (@options) = ("SIZE","COLOR","MATERIAL","PATTERN");
	foreach my $option (@options) {
		$SPECIAL{'%OPTION_'.$option} = '';
		}


	## determine if there are any inv options
	my $found = 0;
	if ($P->has_variations('inv')) {
		## ABC:A001
		my ($product,@opts) = split(/:/,$SKU);
		foreach my $opt (@opts) {
			## $val=01
			my $val = substr($opt,2,4);

			## do we still resolve_sog? will grab Google Variation Keyword from SOG level
			my $pogs2 = $P->fetch_pogs();
			foreach my $pog (@{$pogs2}) {
				
				## get Google Variation Keyword
				my $cat = $pog->{'goo'};

				## not used, yet
				## find variation:$val_goo

				## no need to go on if we dont have Google Variation Keyword
				if ($cat ne '') {
					foreach my $row (@{$pog->{'@options'}}) {
  		  		   	if ($row->{'v'} eq $val) {
							## set %OPTION_COLOR/SIZE/MATERIAL/PATTERN
							$SPECIAL{"%OPTION_".uc($cat)} = $row->{'prompt'};
							$found++;
							}
						}
					}
				}
			}
		}

=pod

[[SUBSECTION]%PARENT_PID]

the special field %PARENT_PID will be set to the SKUs PID (only used for OPTIONS!!)
[[/SUBSECTION]]

=cut 
	
	$SPECIAL{'%PARENT_PID'} = '';
	if ($found > 0) {		## if one of the SPECIAL variation fields have been set, set PARENT_PID
		my ($product) = &PRODUCT::stid_to_pid($SKU);
		$SPECIAL{'%PARENT_PID'} = $product;
		}
	## this is a group child, populate PARENT_PID with its group parent
	elsif ($found == 0 && $P->fetch('zoovy:grp_parent') ne '') {
		$SPECIAL{'%PARENT_PID'} = $P->fetch('zoovy:grp_parent');
		}
	else { 
		## dont set, this isnt a child/option
		}

	my ($arrayref) = &SYNDICATION::HELPER::do_product($self->so(),\@SYNDICATION::GOOGLEBASE::COLUMNS,\%SPECIAL,$SKU,$P,$plm);

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
			push @{$arrayref}, [ 'g:product_type', $P->fetch('gbase:product_type'.$i) ];
			$i++;	
			}
		}




	if (not $plm->can_proceed()) {
		my @LABELS = ();
	      ## add merchant-defined labels

	      #my ($LEGACY_LABEL) = split(/[,\n]+/,$P->fetch('adwords:labels'));
	      #$LABELS[0] = $LEGACY_LABEL;
	      #$LABELS[1] = $P->fetch('zoovy:prod_folder');
	      #$LABELS[2] = $P->fetch('zoovy:prod_mfg');
	      #$LABELS[3] = $P->fetch('zoovy:prod_brand');

		## we use the .custom_label_#_attrib in the syndication object to figure out which product attribute we should pull the data from
		}
	else {
		foreach my $i (0..4) {
			my $attrib = $self->so()->get(".custom_label_$i\_attrib") || "g:custom_label_$i";
			 my ($DATA) = $P->fetch($attrib);
			next if (not defined $DATA);
         		push @{$arrayref}, [ "g:custom_label_$i", $DATA ];
    		     	}
	  	}

=pod

[[SUBSECTION]SPECIAL BEHAVIOR: Adwords Labels (g:adwords_labels)]

Product attribute adwords:labels may contain one or more labels separated by commas/hard returns.

In addition for convenience automatic labels will be generated for:
<li> zoovy:prod_folder (becomes folder_xyz)
<li> zoovy:prod_mfg	(becomes mfg_xyz)

[[HINT]]
Any spaces in the labels will be replaced with underscores and lowercased ex: if the zoovy:prod_mfg contained the field
"Some Manufacturer" it would become label "mfg_some_manufacturer"
[[/HINT]]

[[/SUBSECTION]]

=cut

	if (not $plm->can_proceed()) {
		}
	else {
		my @LABELS = ();
		## add merchant-defined labels
		foreach my $label (split(/[,\n]+/,$P->fetch('adwords:labels'))) {
			next if ($label eq '');
			push @LABELS, $label;
			}
		## add folder label
		if ($P->fetch('zoovy:prod_folder') ne '') {
			push @LABELS, sprintf("folder_%s",$P->fetch('zoovy:prod_folder'));
			}
		## add mfg label
		if ($P->fetch('zoovy:prod_mfg') ne '') {
			push @LABELS, sprintf("mfg_%s",$P->fetch('zoovy:prod_mfg'));
			}
		elsif ($P->fetch('zoovy:prod_brand') ne '') {
			push @LABELS, sprintf("mfg_%s",$P->fetch('zoovy:prod_brand'));
			}

		# push @LABELS, sprintf("supplier_%s",$P->fetch('zoovy:prod_supplier'));

		foreach my $label (@LABELS) {
			#next if ($label eq '');	## moved to adwords:labels
			$label = lc($label);
			$label =~ s/^[\s]+//gs;	# strip leading spaces
			$label =~ s/[\s]+$//gs;	# strip trailing spaces
			$label =~ s/[\s]/_/gs;	# convert spaces to underscores
			push @{$arrayref}, [ 'g:adwords_labels', $label ];
			}

		}


=pod


[[SUBSECTION]SPECIAL BEHAVIOR if adwords:prefer_for_query is set]
When the field adwords:prefer_for_query is set, it should contain multiple lines, 
with each 'word' or 'term' appearing on one line.
these will be passed in individual g:adwords_prefer_for_query tags inside the XML.

example:
[[HTML]]
<g:adwords_prefer_for_query>line1</g:adwords_prefer_for_query>
<g:adwords_prefer_for_query>line2</g:adwords_prefer_for_query>
<g:adwords_prefer_for_query>line3</g:adwords_prefer_for_query>
[[/HTML]]

[[HINT]]
Don't look for adwords:prefer_for_query in the map.
It is appended to the output as a special record, although it does NOT appear 
in the map, it will appear in the actual generated feed.
[[/HINT]]

[[/SUBSECTION]]

=cut

	if (not $plm->can_proceed()) {
		}
	elsif ($P->fetch('adwords:prefer_for_query') ne '') {
		foreach my $line (split(/[\n\r]+/,$P->fetch('adwords:prefer_for_query'))) {
			$line =~ s/^[\s]+//gs;
			$line =~ s/[\s]+$//gs;
			push @{$arrayref}, [ 'g:adwords_prefer_for_query', $line ];
			}
		}

	## create the actual xml.			
	my $xml = '';
	foreach my $set (@{$arrayref}) {
		$xml .= sprintf(" <%s>%s</%s>\n",$set->[0],&ZOOVY::incode($set->[1]),$set->[0]);
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
			
	if (($P->fetch('zoovy:ship_cost1') ne '') && ($self->so()->get('.include_shipping'))) {
	  $xml .= qq~ <g:shipping><g:country>US</g:country><g:service>Ground</g:service><g:price>~.sprintf("%.2f",$P->fetch('zoovy:ship_cost1')).qq~</g:price></g:shipping>\n~;
	  }
	# $item{'g:service'} =
	#  <g:tax_region>California</g:tax_region>
	# $item{'g:tax_region'} =
	#  <g:tax_percent>8.2<g:/tax_percent>
	# $item{'g:tax_percent'} =				

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