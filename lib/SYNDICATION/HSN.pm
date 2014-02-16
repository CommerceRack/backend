#!/usr/bin/perl

package SYNDICATION::HSN;

### 

use strict;
use lib "/backend/lib";
use Data::Dumper;
use XML::Writer;


##
##
##


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
	my ($lm) = $so->msgs();

	my $ftpserv = $so->get('.ftp_server');
	$ftpserv =~ s/ //g;
	$ftpserv = "192.234.237.115";
	if ($ftpserv =~ /^ftp\:\/\//i) { $ftpserv = substr($ftpserv,6); }
#	if ($ftpserv !~ /hsn\.com$/) {
#		$ERROR = 'FTP Server must end in .hsn.com'; 
#		}

	## NOTE: **HSN** is special with it's urls

	## THESE ARE FOR INVENTORY/PRODUCTS
	## "ftp_pass": 'A~yI%PO<XR_.9.5M'
	## "ftp_server": '192.234.237.115'
	## "ftp_user": 'Toynk'

	## THESE ARE FOR ORDERS (use FTPS)
	## "order_ftp_pass": '419348Ftps'
	## "order_ftp_server": 'hsnedi.hsn.net:990'
	## "order_ftp_user": 'ftps419348'

	my $fuser = $so->get('.ftp_user');
	if ($fuser =~ / /) { $lm->pooshmsg("ERROR|+space in .ftp_user (not allowed)"); }

	my $fpass = $so->get('.ftp_pass');
	if ($fpass =~ / /) { $lm->pooshmsg("ERROR|+space in .ftp_pass (not allowed)"); }

	## couldnt find in docs what these files should be called
	if ($so->{'%options'}->{'type'} eq 'product') {
		$so->set(".url","ftp://$fuser:$fpass\@$ftpserv/products/products.xml");
		}
	elsif ($so->{'%options'}->{'type'} eq 'inventory') {
		$so->set(".url","ftp://$fuser:$fpass\@$ftpserv/inventories/inventory.xml");
		}
	else {
		$lm->pooshmsg("ISE|+Unknown type [[cannot properly setup url]]");
		}

	use POSIX qw(strftime);
	my $date = strftime("%m/%d/%Y %H:%M:%S",localtime(time()));
	$self->{'_DATE'} = $date;

	## this should be pulled only once
	## defaulting to 'N', not sure if this is the right way to go
	$self->{'_CANSHIPTOPOBOX'} = 'N';
	my $webdbref = &ZWEBSITE::fetch_website_dbref($so->username(),$so->prt());
	if ($webdbref->{'chkout_deny_ship_po'} == 0) { $self->{'_CANSHIPTOPOBOX'} = 'Y'; }

	#$self->{'_IMAGEPATH'} = &ZOOVY::resolve_userpath_zfs1($so->username()).'/IMAGES/';

	bless $self, 'SYNDICATION::HSN';  

	require SYNDICATION::CATEGORIES;
	$self->{'%CATEGORIES'} = SYNDICATION::CATEGORIES::CDSasHASH("HSN",">");

	return($self);
	}

## Looks like we send the same header for inv and product feeds
sub header_inventory {
	my ($self) = @_;
	return($self->header());
	}

## ex: <Message VendorID="44" CreatedDate="10/03/2006 16:00:00">
sub header_products {
	my ($self) = @_;
	
	my $c = 
qq~<?xml version="1.0"?>
	<Message VendorID="~.$self->so()->get('.vendor_id').qq~" CreatedDate="~.$self->{'_DATE'}.qq~">
<Products>\n~;
	
   return($c);
	}

sub so { return($_[0]->{'_SO'}); }

sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	## format:
	##		field, prod_name, validation
	my $RESULT = '';

	## check hsn:ts
	if ($RESULT) {}
	elsif ($P->fetch('hsn:ts')<1) {
		$RESULT = "STOP|+ATTRIB=hsn:ts|+hsn:ts is not enabled .. cannot syndicate";
		}

	## check TITLE
	if ($RESULT) {}
	elsif ($P->fetch('hsn:prod_name') ne '') {}
	elsif ($P->fetch('zoovy:prod_name') eq '') {
		$RESULT = "STOP|+ATTRIB=zoovy:prod_name|+Name required.";
		}

	## check DESCRIPTION
	if ($RESULT) {}
	elsif ($P->fetch('hsn:prod_desc') ne '') {}
	elsif ($P->fetch('zoovy:prod_desc') eq '') {
		$RESULT = "STOP|+ATTRIB=zoovy:prod_desc|+Description required.";
		}

	## check IMAGE1
	if ($RESULT) {}
	elsif ($P->fetch('zoovy:prod_image1') eq '') {
		$RESULT = "STOP|+ATTRIB=zoovy:prod_image1|+Image required.";
		}

	## check PRICE
	if ($RESULT) {}
	elsif ($P->fetch('zoovy:base_price')<=0) {
		$RESULT = "STOP|+ATTRIB=zoovy:base_price|+Price required.";
		}

	## check HSN COST
	if ($RESULT) {}
	elsif ($P->fetch('hsn:base_cost')<=0) {
		$RESULT = "STOP|+ATTRIB=hsn:base_cost|+Cost required.";
		}

	## check Country of Origin (ie where product was manufacturered)
	if ($RESULT) {}
	elsif ($P->fetch('zoovy:ship_mfgcountry') eq '') {
		$RESULT = "STOP|+ATTRIB=zoovy:ship_mfgcountry|+Country of Origin required.";
		}

	## check PID  
	## per Docs...
	## Item numbers can contain numbers, text, and/or dashes.  
	##	Item numbers cannot contain spaces, underscores, periods, or other special characters.   
	##
	if ($RESULT) {}
	elsif  ($SKU =~ m/[^a-zA-Z\-0-9]+/) {
		$RESULT = "STOP|+ATTRIB=PID|+PID can only contain numbers, letters, and/or dashes.";
		}

	## check CATEGORY
	if ($RESULT) {}
	elsif ($self->{'%CATEGORIES'}->{$P->fetch('navcat:meta')} eq '' && $P->fetch('hsn:category') eq '') {
		$RESULT = "STOP|+ATTRIB=CATEGORY|+Category must be defined.";
		}

	## check DIMENSIONS
	if ($RESULT) {}
	elsif ($P->fetch('zoovy:base_weight') eq '' || $P->fetch('zoovy:pkg_width') eq '' || 
		$P->fetch('zoovy:pkg_height') eq '' || $P->fetch('zoovy:pkg_depth') eq '') {
		$RESULT = "STOP|+ATTRIB=zoovy:pkg_depth/width/height zoovy:base_weight|+All dimensions must be defined.";
		}  

	## check BRAND
	if ($RESULT) {}
	elsif ($P->fetch('zoovy:prod_mfg') eq '') {
		$RESULT = "STOP|+ATTRIB=zoovy:prod_mfg|+Brand/Mfg must be defined.";
		}  

	if ($RESULT ne '') {
		## just kidding!
		if ($self->so()->get('.ignore_validation')) { 
			$RESULT = '';
			}
		}

	return($RESULT);
	}

  
##
##
## HSN Inventory XSD and notes
## https://view.hsn.net/WebDocuments/ECODocuments/ECOXMLTech_Documentation.doc
##
sub inventory {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	my $xCBL = '';
	my $writer = new XML::Writer(OUTPUT => \$xCBL, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');

	## if the inventory is negative or not defined, set it to 0
	if ($OVERRIDES->{'zoovy:qty_instock'} < 0 || $OVERRIDES->{'zoovy:qty_instock'} eq '') {
		$OVERRIDES->{'zoovy:qty_instock'} = 0;
		}

	# 	Item numbers can contain numbers, text, and/or dashes.  
	#	Item numbers cannot contain spaces, underscores, periods, or other special characters.   
	$writer->startTag("Product");															
		$writer->dataElement("VendorProduct_ID",$SKU);
		$writer->dataElement("QtyAvailable",$OVERRIDES->{'zoovy:qty_instock'});
		## per docs... 
		##		You will only receive an EDI orders file once a day, 
		##		so <OrdersProcessed> should be sent as N throughout the day.  
		##		Send Y once you have processed HSN orders from the previous day.  
		my $ORDERS_PROCESSED = 'N';
		$writer->dataElement("OrdersProcessed",$ORDERS_PROCESSED);
	$writer->endTag("Product");											
	$writer->end();
	
	return($xCBL);
	}

##
## this is used to implicitly delete inventory.
## 
## per docs...
##		IMPORTANT: If you need for HSN to no longer sell an item, do not simply remove it from either feed; 
##		instead, send over a zero value for the quantity available in the inventory feed.  The item will be 
##		removed automatically from HSN.com once an inventory of zero is reached.  If an item is just removed 
##		from the product catalog feed, HSN will still retain the last inventory value and will continue to sell the item.
##
##
## note: switched off, process was sending an inventory for all products... 
##		even those that had never been configured to use HSN
##
#sub INVENTORY_DELETE_NOT_WORKING {
#	my ($self,$SKU,$stash,$was_processed) = @_;
#
#	my ($so) = $self->so();
#	$so->pooshmsg("INFO|+$SKU is deleted/blocked, sending 0 as qty");
#
#	my $prodref = ZOOVY::fetchproduct_as_hashref($so->username(),$SKU);
#	$prodref->{'zoovy:qty_instock'} = 0;
#
#	my ($xCBL) = $self->inventory($SKU,$prodref);
#
#	return($xCBL);
#	}
  

##
##
## HSN Product XSD and notes
## https://view.hsn.net/WebDocuments/ECODocuments/ECOXMLTech_Documentation.doc
##
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my $xCBL = '';
	my $writer = new XML::Writer(OUTPUT => \$xCBL, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');

	# 	Item numbers can contain numbers, text, and/or dashes.  
	#	Item numbers cannot contain spaces, underscores, periods, or other special characters.   
	$writer->startTag("Product","ItemNumber" => $SKU);															
		# Code => (always send 'F', which indicates "Finished Good")
		$writer->startTag("Status", "Code" => "F", "ModifiedDate" => $self->{'_DATE'});
		$writer->endTag("Status");
		## UPC should be 12 zeros if not defined (per HSN)
		my $UPC = ($P->fetch('zoovy:prod_upc') eq '')?'000000000000':$P->fetch('zoovy:prod_upc');
		$writer->dataElement("UPC",$UPC);
		## According to dave (toynk) cost is what HSN pay for the product
		$writer->dataElement("UnitCost",$P->fetch('hsn:base_cost'));
		if ($P->fetch('zoovy:prod_msrp') ne '') {
			$writer->dataElement("MSRP",$P->fetch('zoovy:prod_msrp'));
			}
		$writer->dataElement("Price",$P->fetch('zoovy:base_price'));
		## Are any products shipping via LTL? If not, then ShippingCharge should always be left out.
		#$writer->dataElement("ShippingCharge",$P->fetch('zoovy:ship_cost1'));
		$writer->dataElement("CountryOfOrigin",$P->fetch('zoovy:ship_mfgcountry'));
		$writer->dataElement("CanShipToPOBox",$self->{'_CANSHIPTOPOBOX'});
		$writer->dataElement("GiftReceipt","Y");
		$writer->dataElement("GiftMessage","Y");
		$writer->dataElement("PersonalizationAvailable","N");
		$writer->dataElement("PersonalizationRequired","N");
		# If your drop ship contract supports an extended delivery 
		#	window, use the Lead Time elements to designate how many 
		#	more days [past the standard 10] are needed (for each item).  
		#$writer->dataElement("MinLeadTime","");
		#$writer->dataElement("MaxLeadTime","");
		my $category = ($P->fetch('hsn:category') eq '')?$P->fetch('navcat:meta'):$P->fetch('hsn:category');
		$writer->startTag("Categories");
			$writer->dataElement("Category",$category,"Position"=>1);
		$writer->endTag("Categories");
		## DESCRIPTIONS, use hsn fields if they are defined	
		my $prod_name = ($P->fetch('hsn:prod_name') ne '')?$P->fetch('hsn:prod_name'):$P->fetch('zoovy:prod_name');

		## take each bullet out the desc, then re-add with html tagging (per HSN)
		my $prod_desc = '';
		my @bullets = ();
		foreach my $line (split(/\n/,($P->fetch('hsn:prod_desc') ne '')?$P->fetch('hsn:prod_desc'):$P->fetch('zoovy:prod_desc'))) {
			if ($line =~ /^\*(.*)/) {
				push @bullets, $1;
				}
			else {
				$prod_desc .= "\n".$line;
				}
			}

		## add bullets
		if (scalar(@bullets) > 0) {
			$prod_desc .= "\n<ul>\n<li>";
			$prod_desc .= join("\n<li>",@bullets);
			$prod_desc .= "\n</ul>";
			}

		$writer->startTag("Descriptions");
			$writer->dataElement("Description",$prod_name,"Type"=>"LongName");
			$writer->dataElement("Description",$prod_desc,"Type"=>"Web Description");
		$writer->endTag("Descriptions");

		## CPSIA WARNING (Consumer Product Safety Improvement Act 2008)
		## [doc: ToysCPSCComplianceforHSN.wps]
		## possible warnings include the following:	
		my %cpsia_warnings = (
			"choking_hazard_balloon"					=> 1037,
			"choking_hazard_contains_a_marble"		=> 1041,
			"choking_hazard_contains_small_ball"	=> 1039,
			"choking_hazard_is_a_marble"				=> 1040,
			"choking_hazard_is_a_small_ball"			=> 1038,
			"choking_hazard_small_parts"				=> 1036,
			);
		my @warnings = split(/(,| )/, $P->fetch('zoovy:prod_cpsiawarning'));
		my $warning = '';
		foreach my $entry (@warnings) {
			$warning .= $cpsia_warnings{$entry}."\;";		## separate codes with ; (per HSN docs trailing ; is allowed)
			}

		## MANUFACTURER CERTIFICATE - the filename of a manufactirer certificate must be added for each product.
		##		- the actual certificates are all saved on HSN's servers and are uploaded by Toynk

		## add cpsia warning and mfg certificate to the output
		if ($warning ne '') {
		$writer->startTag('ProductInformation');
			$writer->dataElement("CareAndInstructions",$warning);
			$writer->startTag("ProductSpecSheets");
				$writer->dataElement("ProductSpecSheet",$P->fetch('hsn:mfg_certificate'));
			$writer->endTag("ProductSpecSheets");
		$writer->endTag('ProductInformation');
			}

		## IMAGES
		## changed to send path to image vs ftping image
		$writer->startTag("Images");			
		for (my $cnt=1;$cnt<4;$cnt++) {
			my $image_name = "zoovy:prod_image$cnt";
			next if ($P->fetch($image_name) eq '');	
			#my $url = &IMGLIB::Lite::url_to_orig($self->so()->username(),$P->fetch($image_name));
			my $imgurl = &ZOOVY::mediahost_imageurl($self->so()->username(),$P->fetch($image_name),1200,1200,'FFFFFF',0,'jpg');
			## first image is the main image, type=Product, all others are Alternates
			my $type = ($cnt == 1)?"Product":"Alt";
			$writer->dataElement("Image","", "Type"=>$type, "File"=>$imgurl);
			}
		$writer->endTag("Images");			
		
		#  DIMENSIONS
		## 	all dimensions are required
		#	Weight in lbs
		#	Length,Width,Height in inches
		$writer->startTag("Dimensions");
			$writer->startTag("Dimension", "Type"=>"Packaging");
				## convert from ounces to lbs
				my $weight = sprintf("%.1f",&ZSHIP::smart_weight($P->fetch('zoovy:base_weight'))/16);
				$writer->dataElement("Weight",$weight);
				$writer->dataElement("Height",$P->fetch('zoovy:pkg_height'));
				$writer->dataElement("Length",$P->fetch('zoovy:pkg_depth'));
				$writer->dataElement("Width",$P->fetch('zoovy:pkg_width'));
			$writer->endTag("Dimension");
		$writer->endTag("Dimensions");

		## SHIPPING
		#	basically this indicates which methods this product can be shipped by
		#	10	Ground, 20	Express (2-Day Air or 3-Day Air), 25	Super Express (Next Day Air)
		# 	assuming that all products will offer all of these, but not sure
		#	- there are also codes for freight, etc
		$writer->startTag("Shipping");
			$writer->startTag("Methods");
				$writer->dataElement("MinMethod",10);
				$writer->dataElement("MaxMethod",25);
			$writer->endTag("Methods");	
		$writer->endTag("Shipping");

		# MANUFACTURER
		$writer->startTag("Manufacturer");
			$writer->dataElement("Name",$P->fetch('zoovy:prod_mfg'));
		$writer->endTag("Manufacturer");		

		# RETURN ADDRESS
		#	only needs to be included if different than main merchant address

		# VARIANT PRODUCTS
		#	left out for now... toynk doesnt need it and we more info to support it


	$writer->endTag("Product");		
	$writer->end();

	#$self->{'_%IMAGES'} = {$self->{'_%IMAGES'},%images_to_push};

	return($xCBL);
	}



##
## logs an internal hsn error.
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

	## this needs to be after we gathered all the images to be uploaded
	## 	I absolutely hate where this is, no current spot in SYNDICATION.pm, will need to change
	#my $image_url = $self->so()->get(".url");
	#$image_url =~ s/products\/products\.xml/images/;
	#my $ERROR = $self->so()->transfer_ftp($image_url,$self->{'_@IMAGES'});
	#print STDERR "IMAGE ERROR: $ERROR\n";

	return("</Products>\n</Message>\n");
	}

  
sub footer_inventory {
	my ($self) = @_;
	return("</Products>\n</Message>\n");
	}

1;


__DATA__

Sample Product XML

<Message VendorID="44" CreatedDate="10/03/2006 16:00:00">
	<Products>
		<Product ItemNumber="BT-R1000-D">
			<Status Code="F" ModifiedDate="10/03/2006 16:00:00"></Status>
			<UPC>000000000000</UPC>
			<UnitCost>16.00</UnitCost>
			<MSRP>35.00</MSRP>
			<CountryOfOrigin>USA</CountryOfOrigin>
			<CanShipToPOBox>N</CanShipToPOBox>
			<GiftReceipt>Y</GiftReceipt>
			<GiftMessage>Y</GiftMessage>
			<PersonalizationAvailable>N</PersonalizationAvailable>
			<PersonalizationRequired>N</PersonalizationRequired>
			<MinLeadTime></MinLeadTime>
			<MaxLeadTime></MaxLeadTime>
			<Categories>
				<Category Position="1">BT</Category>
			</Categories>
			<Descriptions>
				<Description Type="LongName">Alaris Blue Retro Bedskirt Double</Description>
				<Description Type="Web Description">Web Description</Description>
			</Descriptions>
			<ProductInformation>
				<FabricContent>50/50 PLOYESTER COTTON</FabricContent>
				<CareAndInstructions></CareAndInstructions>
				<Features></Features>
				<NotesToEditor></NotesToEditor>
				<CustomerValue></CustomerValue>
				<ULETLListing></ULETLListing>
				<ProductSpecSheets>
					 <ProductSpecSheet></ProductSpecSheet>
				</ProductSpecSheets>
			</ProductInformation>
			<Images>
				<Image Type="Product" File="BT-R1000-D.jpg"></Image>
			</Images>
			<Dimensions>
				<Dimension Type="Packaging">
					<Height>7</Height>
					<Weight>5</Weight>
					<Length>5</Length>
					<Width>7</Width>
				</Dimension>
			</Dimensions>
			<Shipping>
				<Methods>
					<MinMethod></MinMethod>
					<MaxMethod></MaxMethod>
				</Methods>
				<ChargeOverrides>
						<WhiteGloveAmount></WhiteGloveAmount>
				</ChargeOverrides>
			</Shipping>
			<Manufacturer>
				<Name>Superior Quilting</Name>
			</Manufacturer>
			<ReturnAddress>
				<Address1></Address1>
				<Address2></Address2>
				<Address3></Address3>
				<City></City>
				<State></State>
				<ZIP></ZIP>
				<Country></Country>
			</ReturnAddress>
			<VariantProducts>
				<VariantProduct Name="" Color="" Var1Type="" Var1="" Var2Type="" Var2=""></VariantProduct>
				<VariantProduct Name="" Color="" Var1Type="" Var1="" Var2Type="" Var2=""></VariantProduct>
				<VariantProduct Name="" Color="" Var1Type="" Var1="" Var2Type="" Var2=""></VariantProduct>
			</VariantProducts>
		</Product>		
	</Products>
</Message>

Sample INVENTORY XML:
<Message VendorID='' CreatedDate=''>
  <Products>
	<Product>
	  <VendorProduct_ID></VendorProduct_ID>
	  <VendorProductP_ID></VendorProductP_ID>
	  <QtyAvailable></QtyAvailable>
	  <OrdersProcessed></OrdersProcessed>
  	</Product>
  </Products>
</Message>