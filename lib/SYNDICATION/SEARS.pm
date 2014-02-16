

use strict;

package SYNDICATION::SEARS;
use YAML::Syck;
use URI::Escape::XS;
$YAML::Syck::ImplicitBinary++;
$YAML::Syck::ImplicitUnicode++;
$YAML::Syck::SingleQuote++;		# do not fucking enable this. it has issues with cr/lf 183535


##
## records a doc for later processing
##
sub record_doc {
	my ($so,$docid,$doctype,$ref) = @_;

	my ($udbh) = &DBINFO::db_user_connect($so->username());
	my $YAML = YAML::Syck::Dump($ref);
	my ($pstmt) = &DBINFO::insert($udbh,'SEARS_DOCS',{
		'MID'=>$so->mid(),
		'PRT'=>$so->prt(),
		'DOCID'=>$docid,
		'DOCTYPE'=>$doctype,
		'*CREATED_TS'=>'now()',
		'YAML'=>$YAML,
		},'verb'=>'insert',sql=>1);
	print "$pstmt\n";	
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	return();
	}

### 
## SEARS.pm
##  REST API
## - only building for inventory syndication
## - product syndication may be built later
## - uses PUTs to transfer XML, DOCID is returned on SUCCESS
##
## all URLS start with [https://seller.marketplace.sears.com/]
##
##	inventory XSD:
##		/SellerPortal/s/schema/inventory/fbm/inventory-xml-feed-v4.xsd
##		https://seller.marketplace.sears.com/SellerPortal/s/schema/samples/rest/inventory/import/v6/store-inventory.xml?view=markup
##		https://seller.marketplace.sears.com/SellerPortal/s/schema/samples/rest/inventory/import/v6/store-inventory.xml?view=markup
##		PUT URL: https://seller.marketplace.sears.com/SellerPortal/api/inventory/fbm-lmp/v6?email={emailaddress}&password={password}  
## 	XSD: https://seller.marketplace.sears.com/SellerPortal/s/schema/rest/inventory/import/v6/store-inventory.xsd?view=markup
##
##	price XSD
##		Version 4: AVAILABLE 5/24
##		XSD:  https://seller.marketplace.sears.com/SellerPortal/s/schema/rest/pricing/import/v4/pricing.xsd
##		Sample:  https://seller.marketplace.sears.com/SellerPortal/s/schema/samples/rest/pricing/import/v4/pricing.xml
##		PUT URL:  https://seller.marketplace.sears.com/SellerPortal/api/pricing/fbm/v4?email={emailaddress}&password={password}
##
## response XSD [returns DOCID upon SUCCESS, error otherwise]:
##		/SellerPortal/s/schema/shared/api-response-v4.xsd
##
## processing report XSD:
##		/SellerPortal/s/schema/shared/seller-error-report-v4.xsd
## processing report API call [GET]:
##		/SellerPortal/api/reports/v4/processing-report/{document-id}?email={emailaddress}&password={password}
##	processing report example XML:
##		/SellerPortal/s/schema/samples/seller-error-report-v4-example.xml	
##
## notes:
##		- upgraded from v2 to v4, 2011-06-10
##
use strict;
use lib "/backend/lib";
use Data::Dumper;
use XML::Writer;
use POSIX;

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
	my $ERROR = '';

	my $user = $so->get('.user');
	$user = URI::Escape::XS::uri_escape($user);
	my $pass = $so->get('.pass');
	
	## setup PUT url
	my $url = '';
	if ($so->type() eq 'inventory') {
		## 	  https://seller.marketplace.sears.com/SellerPortal/api/inventory/fbm-lmp/v6
		$url = "https://seller.marketplace.sears.com/SellerPortal/api/inventory/fbm-lmp/v6";
		}
	elsif ($so->type() eq 'pricing') {
		$url = "https://seller.marketplace.sears.com/SellerPortal/api/pricing/fbm/v4";
		}
	else {
		die "UNKNOWN TYPE: ".$so->type()."\n";
		}
	$url .= "?email=$user&password=$pass";
	$so->set(".url",$url);
	

	bless $self, 'SYNDICATION::SEARS';  

	return($self);
	}

## only doing inventory syndication
sub header_inventory {
	my ($self) = @_;

	my $xml = 
qq~<?xml version="1.0" encoding="UTF-8" ?>
	<store-inventory xmlns="http://seller.marketplace.sears.com/catalog/v6" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://seller.marketplace.sears.com/catalog/v6 http://seller.marketplace.sears.com/SellerPortal/s/schema/rest/inventory/import/v6/store-inventory.xsd">~;

	return($xml);
	}

sub header_pricing {
	my ($self) = @_;

	my $xml = 
qq~<?xml version="1.0" encoding="UTF-8" ?>
	<pricing-feed xmlns="http://seller.marketplace.sears.com/pricing/v4" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://seller.marketplace.sears.com/pricing/v4 http://seller.marketplace.sears.com/SellerPortal/s/schema/rest/pricing/import/v4/pricing.xsd">
		<fbm-pricing>
	~;

	return($xml);
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

	## check sears:ts
	if ($ERROR) {}
	elsif ($P->fetch('sears:ts')<1) {
		$ERROR = "{sears:ts}sears:ts is not enabled .. cannot syndicate";
		}


	## check if merchant allows SAFESKUs -- allow : and _
	if ($self->so()->get('.safe_sku') == 1) {
		my $safesku = ZOOVY::to_safesku($SKU);
		#if ($pid =~ m/[^a-zA-Z0-9-:_]/) {
		if ($safesku =~ m/[^a-zA-Z0-9-]/) {
			$ERROR = "{pid}only alphanumberic chars and - are allowed in safe SKU: ".$safesku;
			}
		## check length
		else {
			if (length($safesku) > 20) {
				$ERROR = "{pid}safesku: ".$safesku." length is too long: ".length($safesku);
				}
			}
		}
	## otherwise, dont allow : and _
	else {
		if ($SKU =~ m/[^a-zA-Z0-9-]/) {
			$ERROR = "{pid}only alphanumberic chars are allowed in SKU: ".$SKU.". Turn on safeskus to allow : and _.";
			}
		else {
			if (length($SKU) > 20) {
				$ERROR = "{pid}pid: $SKU length is too long: ".length($SKU);
				}
			}
		}

	if ($ERROR ne '') {
		## just kidding!
		if ($self->so()->get('.ignore_validation')) { $ERROR = ''; }
		}
	return($ERROR);
	}


## 
sub validatesku {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;
	
	my ($ERROR) = '';
	## this is always a SKU and therefore always has a :, never validates if safe_sku is off
	if ($self->so()->get('.safe_sku') == 1) {
		$ERROR = $self->validate($SKU,$P,$plm,$OVERRIDES);
		}
	else {
		$ERROR = "{pid}only alphanumberic chars, -, :, #, and _ are allowed in SKU: ".$SKU;
		}

	return($ERROR);
	}


##
##
sub inventory {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	my $ERROR = undef;
	my $xml = '';
	my $writer = new XML::Writer(OUTPUT => \$xml, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');

	## if the inventory is negative or not defined, set it to 0
	if ($OVERRIDES->{'zoovy:qty_instock'} < 0 || $OVERRIDES->{'zoovy:qty_instock'} eq '') {
		$OVERRIDES->{'zoovy:qty_instock'} = 0;
		}

	## use safe SKU...
	my $safesku = $SKU;
	if ($self->so()->get('.safe_sku') == 1) {
		$safesku = ZOOVY::to_safesku($SKU);
		}

	#### switch to v2
	## Sears added location in v2
	##		location id is set in their UI and then merchant needs to set that id in the Zoovy UI
	my $location_id = $self->so()->get('.location_id');
	$writer->startTag("item", "item-id"=>$safesku);
		$writer->startTag("locations");
			$writer->startTag("location", "location-id"=>$location_id);
				$writer->dataElement("quantity",$OVERRIDES->{'zoovy:qty_instock'});
				$writer->dataElement("pick-up-now-eligible",'false');
				$writer->dataElement('inventory-timestamp',POSIX::strftime("%Y-%m-%dT%H:%M:%S",localtime($^T)));
			$writer->endTag("location");
		$writer->endTag("locations");
	$writer->endTag("item");
	$writer->end();	

	# print STDERR "xml: $xml\n";

	## this may eventually move to inventory_validate
	if (length($safesku)>20) {
		$plm->pooshmsg("WARN-INV|+SKU:$SKU converts to safesku:$safesku which is longer than 20 characters and would cause file to fail so it was skipped");
		$xml = '';
		}
	elsif ($safesku =~ m/[^a-zA-Z0-9-]/) {
		$plm->pooshmsg("WARN-INV|+SKU:$SKU, only alphanumberic chars and - are allowed. Turn on safeskus to allow :, #,  and _.");
		$xml = '';
		}


	return($xml);
	}

##
## sample: https://seller.marketplace.sears.com/SellerPortal/s/schema/samples/rest/pricing/import/v4/pricing.xml
## xsd:  https://seller.marketplace.sears.com/SellerPortal/s/schema/rest/pricing/import/v4/pricing.xsd
sub pricing {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	my $ERROR = undef;
	my $xml = '';
	my $writer = new XML::Writer(OUTPUT => \$xml, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');

	## use safe SKU...
	my $safesku = $SKU;
	if ($self->so()->get('.safe_sku') == 1) {
		$safesku = ZOOVY::to_safesku($SKU);
		}

		$writer->startTag("item", "item-id"=>$safesku);
			# $writer->dataElement("standard-price", sprintf("%.2f",$P->skufetch($SKU,'zoovy:base_price')));
			#if ($SKU =~ /:/) {
			#	$writer->dataElement("standard-price", sprintf("%.2f", $OVERRIDES->{'zoovy:base_price'}));
			#	}
			if ($OVERRIDES->{'zoovy:base_price'}) {
				$writer->dataElement("standard-price", sprintf("%.2f", $OVERRIDES->{'zoovy:base_price'}));
				}
			else {
				$writer->dataElement("standard-price", sprintf("%.2f", $P->fetch('zoovy:base_price')));
				}
			# <sale>
			# 	<sale-price>39.99</sale-price>
			#  <sale-start-date>2010-01-30</sale-start-date>
			#	<sale-end-date>2010-12-30</sale-end-date>
			# </sale>
			# <map-price-indicator>strict</map-price-indicator>
			# <shipping-override><!-- optional -->
			#		<shipping-method-ground status="enabled">
			#			<!-- each shipping method is optional; set status=.disabled. if item cannot be shipped by a method -->
			#			<shipping-cost>6.25</shipping-cost><!-- min: $0.01; max: $500; format: XXX.XX -->
			#			<free-shipping><!-- free shipping applicable to ground shipping method only -->
			#				<free-shipping-start-date>2011-06-30</free-shipping-start-date><!-- must be at least 2 days from today? -->
			#				<free-shipping-end-date>2011-07-30</free-shipping-end-date><!-- optional element -->
			#				<free-shipping-promotional-text>free shipping is available</free-shipping-promotional-text><!-- optional element -->
			#			</free-shipping>
			#		</shipping-method-ground><shipping-method-expedited status="disabled"><!-- optional -->
			# 		</shipping-method-expedited>
			#		<shipping-method-premium status="enabled"><!-- optional; will use weight based rate if method is enabled but no shipping-cost present -->
			#		</shipping-method-premium>
			# </shipping-override>

			## SHIPPING
			if (($P->fetch('sears:ship_cost')) || ($P->fetch('sears:shipexp_cost'))) {
				## the merchant has configured at least 1 Sears shipping method
				$writer->startTag("shipping-override");

				## STANDARD SHIPPING
				if (not defined $P->fetch('sears:ship_cost')) {
					#nothing to do for standard shipping
					}
				elsif ($P->fetch('sears:ship_cost') == 0) {
					# sears:ship_cost can't be 0
					$plm->pooshmsg("WARN-PRICING|+SKU:$SKU has a sears:ship_cost value of $P->fetch('sears:ship_cost'). sears:ship_cost cannot be 0");
					}
				elsif ($P->fetch('sears:ship_cost') < 0) {
					#disable standard shipping
					$writer->startTag("shipping-method-ground", "status" => "disabled");
					$writer->endTag("shipping-method-ground");
					}
				elsif ($P->fetch('sears:ship_cost') > 0) {
					# we have a positive standard shipping cost so lets send it
					$writer->startTag("shipping-method-ground", "status" => "enabled");
						$writer->dataElement("shipping-cost", sprintf("%.2f", $P->fetch('sears:ship_cost')));
						if ($P->fetch('sears:freeship_date') eq '') {
							# no need to do anything with free shipping
							}
						elsif ($P->fetch('sears:freeship_date') =~ /^(\d\d\d\d)(\d\d)(\d\d)$/ ) {
							# valid freship date
							$writer->startTag("free-shipping");
								$writer->dataElement("free-shipping-start-date", $1."-".$2."-".$3);
							$writer->endTag("free-shipping");
							}
						else {
							# freeshap date has an invalid format
							$plm->pooshmsg("WARN-PRICING|+SKU:$SKU has an invalid freeship date of $P->fetch('sears:freeship_date'). Valid format is YYYYMMDD");
							}
					$writer->endTag("shipping-method-ground");
					}
				else {
					# something went wrong - we should never reach this point
					}
				## EXPIDITED SHIPPING				
				if (not defined $P->fetch('sears:shipexp_cost')) {
					#nothing to do for espidited shipping
					}
				elsif ($P->fetch('sears:shipexp_cost') < 0) {
					#disable expidited shipping
					$writer->startTag("shipping-method-expedited", "status" => "disabled");
					$writer->endTag("shipping-method-expedited");
					}
				elsif ($P->fetch('sears:shipexp_cost') == 0) {
					# sears:shipexp_cost can't be 0
					}
				elsif ($P->fetch('sears:shipexp_cost') > 0) {
					# we have a positive expidited shipping cost so lets send it
					$writer->startTag("shipping-method-expedited", "status" => "enabled");
						$writer->dataElement("shipping-cost", sprintf("%.2f", $P->fetch('sears:shipexp_cost')));
					$writer->endTag("shipping-method-expedited");
					}
				else {
					# something went wrong - we should never reach this point
					}
				$writer->endTag("shipping-override");				
				}
			else {
				# shipping not configured - this is fine
				}
		$writer->endTag("item");
	$writer->end();	

	# print STDERR "xml: $xml\n";

	## this may eventually move to inventory_validate
	if (length($safesku)>20) {
		$plm->pooshmsg("WARN-PRICING|+SKU:$SKU converts to safesku:$safesku which is longer than 20 characters and would cause file to fail so it was skipped");
		$xml = '';
		}
	elsif ($safesku =~ m/[^a-zA-Z0-9-]/) {
		$plm->pooshmsg("WARN-PRICING|+SKU:$SKU, only alphanumberic chars are allowed. Turn on safeskus to allow :, #, and _.");
		$xml = '';
		}


	return($xml);
	}

##
##
## not currently used 
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	## not used
	return();

	my $ERROR = undef;
	my $xml = '';
	#my $writer = new XML::Writer(OUTPUT => \$xml, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');

	#$writer->end();
			
	if (defined $ERROR) {
		warn("$SKU got $ERROR");
		}
	else {	
		print STDERR "Successful products: ".$self->{'_success_ctr'}++;
		print STDERR "should be returning XML: $xml\n\n";
		}

	return($xml);
	}



##
## logs an internal SEARS error.
##
sub log {
  my ($self,$SKU,$err) = @_;

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
	return("</store-inventory>\n");
	}
sub footer_pricing {
	my ($self) = @_;
	return("</fbm-pricing>\n</pricing-feed>\n");
	}


##
## API upload for SEARS
sub upload {
	my ($self,$file,$tlm) = @_;
	
	my $type = uc($self->so()->type());
	print STDERR "TYPE: $type\n";

	## we don't syndicate SEARS products!
	if ($type eq "PRODUCT") {
		return(undef);
		}
	## we only syndicate inventory!
	elsif ($type eq "INVENTORY" || $type eq "PRICING") {
		use HTTP::Request;
		use HTTP::Headers;
		use LWP::UserAgent;
	
		## get XML contents of file
		my $xml = '';
		open(FILE,$file);
		while(<FILE>) {
			$xml .= $_;
			}
		close(FILE);
		
		#	print "XML: $xml\n";
		## credentials
		my $URL = $self->so()->get('.url');
		my $length = length($xml);
		my $header = HTTP::Headers->new('Content-Length' => $length, 'Content-Type' => 'application/xml', 'connection'=>'close', 'date' => 'Wed, 08 Dec 2010 21:43:29 GMT',);	
		my $request = HTTP::Request->new("PUT", $URL, $header, $xml);

		## my $ua = new LWP::UserAgent;
		## ASSHATS @ SEARS DON'T ALLOW SSLv1/SSLv2 connections anymore!
		my ($ua) =  LWP::UserAgent->new(ssl_opts=>{"verify_hostname"=>0,"SSL_version"=>"SSLv3"}); 
		my $response = $ua->request($request);
		my $USERNAME = $self->so()->username();
	
		my $response_xml = $response->content;
	
		print STDERR "\n\nRESPONSE: ".$response_xml."\n";
		my $responseref = XML::Simple::XMLin($response_xml,ForceArray=>1,ContentKey=>'_');
	
		## if a docid exists, let's get the full submittal report
		if ($responseref->{'document-id'}[0] ne '') {
			my $docid = $responseref->{'document-id'}[0];
			&SYNDICATION::SEARS::record_doc($self->so(),$docid,'inventory',{});
			$tlm->pooshmsg("SUCCESS|DOCID:$docid|+Uploaded Inventory");
			}
		## otherwise, there's an error in the submittal (ill-formed XML, etc)
		elsif ($responseref->{'error-detail'}[0] ne '') {
			my $ERROR = $responseref->{'error-detail'}[0];
			## INVENTORY UPLOAD or PRODUCTS UPLOAD
			## reminder to self: sears does not have error messages to key off of (how lame)
			if ($ERROR =~ /^Your account has been suspended/) {
				## The specified credentials are not valid, please verify the login and password values are specified and are correct.
				$self->so()->msgs()->pooshmsg("ERROR|+$type UPLOAD - Account Suspended '$ERROR'");
				}
			elsif ($ERROR =~ /^The specified credentials are not valid/) {
				## Your account has been suspended; please contact Seller Support to resolve.
				$self->so()->msgs()->pooshmsg("ERROR|+$type UPLOAD - Invalid User/Pass '$ERROR'");
				}
			else {
				## UNKNOWN ERROR
				$self->so()->msgs()->pooshmsg("ISE|+$type UPLOAD Unknown Error '$ERROR'");
				}
			## $self->so()->addsummary("NOTE",NOTE=>"ERROR(s): $ERROR.");
			}

		if (not $tlm->has_win()) {
			my $file = "/tmp/$USERNAME-sears-$type.html";
			$tlm->pooshmsg("DEBUG|+created diagnostics file $file");
			open F, ">$file"; print F "$URL\nrequest_xml:\n$xml\n\nresponse_xml:\n$response_xml\nLM:\n".Dumper($tlm); close F;
			}
		}
	else {
		$tlm->pooshmsg("ISE|+Unknown type: $type");
		}
		
	return($tlm);
	}


##
##
##
sub get_docid {
	my ($so,$docid) = @_;
	
	my $ERROR = '';
	my $errored_items = 0;

	my $user = $so->get('.user');
	my $pass = $so->get('.pass');
	
	my $URL = "https://seller.marketplace.sears.com/SellerPortal/api/reports/v1/processing-report/$docid?email=$user&password=$pass";
	# $so->addsummary("NOTE",NOTE=>"<a href=\"$URL\">Feed results</a>");
	
	print STDERR "GET DOCID: $URL\n";
	
	my $ua = LWP::UserAgent->new();
	$ua->timeout(10);
	my $attempts = 0;

	my $xml = undef;
	do {                                 
		print "ATTEMPT: $attempts\n";
		my $request = HTTP::Request->new("GET", $URL);
		my $response = $ua->request($request);
		$xml = $response->content;
		}
	until (($attempts++>3) || ($xml ne ''));

	my ($errorref) = XML::Simple::XMLin($xml,ForceArray=>1,ContentKey=>'_');			
	
	## if ERROR
	## 	bummer, this doesn't really work because Sears hasnt populated this URL yet
	## 	maybe in the future it will be faster...
	#$ERROR = $errorref->{'report'}[0]->{'detail'}[0]->{'errors'}[0]->{'error'}[0]->{'error-info'}[0];
	$errored_items = $errorref->{'report'}[0]->{'summary'}[0]->{'records-with-errors'}[0];

	if ($errored_items > 0) {
		$ERROR = "$errored_items items failed with errors.";
		}
	
	return($ERROR);
	}

1;



__DATA__

