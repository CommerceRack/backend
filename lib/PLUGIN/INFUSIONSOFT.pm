package PLUGIN::INFUSIONSOFT;

## 
## Infusionsoft 
##		per infusionsoft... Infusionsoft is the #1 all-in-one marketing automation 
##		software used by thousands of small businesses to generate leads and grow sales.
##
##	- ledinsider asked for project integration 02/2011, ticket 376107 
## - call has been added to app6:/httpd/servers/dispatch/orders.pl
##	-- adds a contact and order info for every PAID order (for ledinsider)
##
## 
## API dev documentation: 
##		http://developers.infusionsoft.com
## 

use strict;

use lib '/backend/lib';
require PRODUCT;
use Frontier::Client;
use Frontier::RPC2;
use Data::Dumper;



## 
## create infusionsoft object
##
sub new {
	my ($class, $USERNAME) = @_;

	my ($self) = {};

	my ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME);
	my $URL = $webdbref->{'infusionsoft_url'};
	my $KEY = $webdbref->{'infusionsoft_key'};

	print "Found Key: $KEY $URL\n";
	## Service URL and Secret Key are required!!
	if ($URL eq '' || $KEY eq '') {
		warn "Need URL and KEY to create PLUGIN::INFUSIONSOFT object";
		return(undef);
		}

	my $client = Frontier::Client->new( 'url' 	=> $URL,
													'debug' 	=> 1,		## shows all request and response XML
													'encoding' => 'iso-8859-1'); 
	
	if (defined $client) {
		$self->{'USERNAME'} = $USERNAME;
		$self->{'KEY'} = $KEY;
		$self->{'CLIENT'} = $client;
		
		}
	else {
		$self->{'ERROR'} = "Client was not created!!";
		}	
	
	bless $self, 'PLUGIN::INFUSIONSOFT';  

	return($self);
	}

## do some logging
sub log {
	my ($self, $MSG) = @_;

	$MSG = ZTOOLKIT::pretty_date(time(),1)."\t".$MSG;
	push @{$self->{'@MSGS'}}, $MSG;
	}


sub log_results {
	my ($self) = @_;

	open(LOG, ">>/tmp/infusionsoft.log");
	print LOG "\n\nMSGS:\n".join("\n",@{$self->{'@MSGS'}})."\n";
	close(LOG);

	}

## do_work
## 
##	determine if contact already exists for this order
##	- add/update as necessary
##	- add/update group information
## - add/update order
##
## input: order object
## output: contactid, inf_orderid
##
sub do_work {
	my ($self, $O2) = @_;

	
	my $phone = ($O2->in_get('bill/phone') ne '')?$O2->in_get('bill/phone'):$O2->in_get('ship/phone');
	## define params, will be used for ADD/UPDATE of CONTACT
	my %params = (
		"Email"						=> $O2->in_get('bill/email'),
		"FirstName" 				=> $O2->in_get('bill/firstname'),
		"LastName"					=> $O2->in_get('bill/lastname'),	
		"Company"					=>	$O2->in_get('bill/company'),
		"StreetAddress1"			=> ($O2->in_get('bill/address1') ne '')?$O2->in_get('bill/address1'):$O2->in_get('ship/address1'),
		"City"						=> ($O2->in_get('bill/city') ne '')?$O2->in_get('bill/city'):$O2->in_get('ship/city'),	
		"State"						=> ($O2->in_get('bill/region') ne '')?$O2->in_get('bill/region'):$O2->in_get('ship/region'),	
		"PostalCode"				=>	($O2->in_get('bill/postal') ne '')?$O2->in_get('bill/postal'):$O2->in_get('ship/postal'),	
		"Phone1"						=>	$self->validated_phone($phone),	
		"CreatedBy"					=> "Zoovy via API",
		## custom fields
		"_OrderID"					=> $o->id(),								
		"_ItemCount"				=> $O2->in_get('sum/items_count'),		
		"_GrandTotal"				=> $O2->in_get('sum/order_total'),		
		"_Salestax"					=> $O2->in_get('sum/tax_total'),		## not working
		"_Shipping"					=> $O2->in_get('sum/shp_total'),
		"_TaxableTotal"			=> $O2->in_get('sum/items_taxable'),	
		"_DateCreated"				=> $self->convert_to_datetime($O2->in_get('our/order_ts')),	
		"_PayType"					=> $O2->in_get('our/payment_method'),	
		"_PaidDate"					=> $self->convert_to_datetime($O2->in_get('flow/paid_ts')),	
		"_ShipDate"					=> $self->convert_to_datetime($O2->in_get('flow/shipped_ts')),	
		"_SDomain"					=> $O2->in_get('our/domain'), 
		#"_Meta"						=> $O2->in_get(('/'meta'),				## not pulling from Zoovy, not sure its needed... use sdomain
		"_AB"							=> $O2->in_get('cart/multivarsite'),	
		"_Pool"						=> $O2->in_get('flow/pool'),	
		#"_NoOfEmployees"			=> 0,										## not sure where to pull from
		);	

	## group mappings
	my %groups = (
		"CheckoutCompleteZoovy" => 2424,
	#	"ZoovyCustAdded" =>
	#	"ZoovyCheckoutStart" =>
		);

	## Step 1. check if contact has been added to the CONTACT table
	my ($contacts) = $self->{'CLIENT'}->call(
											"ContactService.findByEmail",
											$self->{'KEY'},
											$O2->in_get('bill/email'),
											["Id","Groups"]);

	my $contactid = $contacts->[0]->{'Id'};
	my @groupids = split(",",$contacts->[0]->{'Groups'});

	## Step 1a. contact exists, update
	if ($contactid ne '') {
		$self->log("contact_work: found contact $contactid $contacts->[0]->{'Groups'}");

		## update CONTACT
		($contactid) = $self->{'CLIENT'}->call(
										"ContactService.update",
										$self->{'KEY'},
										$contactid,
										\%params);

		}
	## Step 1b. contact doesnt exist, add it
	elsif ($contactid eq '') {
		## add CONTACT
		($contactid) = $self->{'CLIENT'}->call(	
										"ContactService.add",
										$self->{'KEY'},
										\%params);
		$self->log("contact_work: added contact $contactid");
		}

	## Step 2. add group if necessary
	## determine if contact is already in group "CheckoutCompleteZoovy"
	my $match = 0;
	foreach my $gid (@groupids) {
		if ($gid == $groups{"CheckoutCompleteZoovy"}) {
			## found a match
			$match++;
			}
		}

	## add GROUP 
	if ($match == 0) {
		my (%cg_params) = (
			"GroupId"		=> $groups{"CheckoutCompleteZoovy"},
			"ContactId"	=> $contactid); 
		## not sure where to add group info, GroupAssign, etc only have READ access
		my ($contactgroupid) = $self->{'CLIENT'}->call(	
										"ContactService.addToGroup",
										$self->{'KEY'},
										$contactid,
										$groups{"CheckoutCompleteZoovy"});
		$self->log("contact_work: added ContactGroup (CheckoutCompleteZoovy)");
		print Dumper($contactgroupid);
		}


	#####	
	## Step 3. check if order has been added to INVOICE table
	## can't tell which table order information is being stored in
	##	- if you figured Order or Invoice, you'd be wrong
	#my ($inf_orderid) = $self->get_orderinfo($o);		
	my ($inf_orderid) = '';

	## Step 3a. Order already exists, we are assuming order is correct in infusionsoft and not updating
	if ($inf_orderid ne '') {
		}
	## Step 3b. Order needs to be created (returns infusionsoft orderid)
	elsif ($inf_orderid eq '') {
		($inf_orderid) = $self->{'CLIENT'}->call(	
										"InvoiceService.createBlankOrder",
										$self->{'KEY'},
										$contactid,
										"Zoovy Order: ".$o->id(),												## Description
										$self->convert_to_datetime($O2->in_get('our/order_ts')),			## convert to infusionsoft dateTime format 	
										0,0
										);
		print Dumper($inf_orderid);
		$self->log("order_work: added order $inf_orderid");
		}

	## Step 4. Add products to order
	my @products = ();
	foreach my $item (@{$o->stuff2()->items()}) {
		# $item->{'qty'} $item->{'base_price'}
		my $stid = $item->{'stid'};
		my ($PID) = PRODUCT::stid_to_pid($stid);
		my ($P) = PRODUCT->new($self->{'USERNAME'},$PID);

		my ($inf_productid) = $self->get_productinfo($PID);
	
		## Step 4a. Product already exists
		if ($inf_productid ne '') {
			}
		## Step 4b. Product needs to be added
		elsif ($inf_productid eq '') {
			my (%params) = (
				'Description' 	=> $P->fetch('zoovy:prod_desc'),
				'ProductName' 	=> $P->fetch('zoovy:prod_name'),
				'ProductPrice'	=> $P->fetch('zoovy:base_price'),
				'Sku'				=>	$PID);

			($inf_productid) = $self->{'CLIENT'}->call(
											"DataService.add",
											$self->{'KEY'},
											'Product',
											\%params);			
			}

		## Step 5. check if products have been added to ORDERITEM table
		my ($inf_orderitemid) = $self->get_orderiteminfo($inf_orderid,$inf_productid);

		## Step 5a. OrderItem already exists
		if ($inf_orderitemid ne '') {
			}
		## Step 5b. Create OrderItem
		elsif ($inf_orderitemid eq '') {
			($inf_orderitemid) = $self->{'CLIENT'}->call(	
										"InvoiceService.addOrderItem",
										$self->{'KEY'},
										$inf_orderid,
										$inf_productid,
										4,					#.type . one of [UNKNOWN = 0; SHIPPING = 1; TAX = 2; SERVICE = 3; PRODUCT = 4; 
															# UPSELL = 5; FINANCECHARGE = 6; SPECIAL = 7;]
										$P->fetch('zoovy:base_price'),
										$item->{'qty'},
										'',''	
										);
			}	
		}
	
	$self->log_results();
	return();
	}


## converts timestamp to infusionsoft datetime
## 	includes date_time xml
##
## input: unix timestamp
## output: infusionsoft datetime (with datetime tags)
##
sub convert_to_datetime {
	my ($self,$date) = @_;

	$date = ZTOOLKIT::unixtime_to_gmtime($date);
	$date =~ s/ /T/;			## convert to infusionsoft dateTime format 	
	$date =~ s/-//g;
	
	$date = $self->{'CLIENT'}->date_time($date);

	return($date);
	}


## infusionsoft doesn't allow certain formats
##
## valid:
##		888-888-8888
##		(888) 888-8888
## invalid:
##		8881231234
##
sub validated_phone {
	my ($self,$phone) = @_;

	if ($phone eq '') {
		}
	## 888-888-8888
	elsif ($phone =~ /\d\d\d-\d\d\d-\d\d\d\d/) {
		}
	## (888) 888-8888
	elsif ($phone =~ /(\d\d\d) \d\d\d-\d\d\d\d/) {
		}
	## 8881231234
	elsif ($phone =~ /(\d\d\d)(\d\d\d)(\d\d\d\d)/) {
		$phone = $1."-".$2."-".$3;
		}
	
	return($phone);
	}


##########################
## BELOW subs are used for testing

## get_contactinfo
##	- only used for testing!!
##	- given a email, return info
##
## note:
## - infusionsoft allows duplicate contacts for an email
##	-- let's just grab the first contactid for this email
##
## input		=> email
##	output 	=> contactid, groupids
## 
sub get_contactinfo {
	my ($self,$email) = @_;

	my $contacts = $self->{'CLIENT'}->call(	
										"ContactService.findByEmail",
										$self->{'KEY'},
										$email,
										["Id","Groups","StreetAddress1","Phone1","State","PostalCode","_OrderID","_Shipping","_ItemCount","_GrandTotal","_Salestax","_Meta","_TaxableTotal","_DateCreated","_PayType","_PaidDate","_ShipDate","_SDomain","_Meta","_Pool","_NoOfEmployees","_AB"]);

	my $contactid = $contacts->[0]->{'Id'};
	#my @groups = split(',',$contacts->[0]->{'Groups'});		
	#my $meta = $contacts->[0]->{'_Meta'};	

	#print STDERR "\n\nget_contactinfo for $email: $contactid, ".join(",",@groups);
	return($contactid,$contacts);
	}

sub update_contactinfo {
	my ($self,$contactid,$params) = @_;

	($contactid) = $self->{'CLIENT'}->call(
										"ContactService.update",
										$self->{'KEY'},
										$contactid,
										$params);
	
	return($contactid);
	}

## get_orderinfo
##	- given a zvy_orderid, return inf_orderid 
##
## note:
## - infusionsoft prolly allows duplicate orders
##
## input		=> zoovy order object
##	output 	=> inf_orderid
## 
sub get_orderinfo {
	my ($self,$o) = @_;

	my $orders = $self->doQuery(	
										"DataService.findByField",{
										"Table"			=> "Invoice",
										"Column"			=> "Description",
										"Value"			=> "Zoovy Order: ".$o->id(),
										"ReturnFields"	=> ["Id"]});

	my $inf_orderid = $orders->[0]->{'Id'};
	
	$self->log("get_orderinfo for ".$o->id().": $inf_orderid");
	return($inf_orderid);
	}

## get_orderiteminfo
##	- given a inf_orderid and inf_productid return inf_orderitemid 
##
## note:
## - infusionsoft prolly allows duplicate orderitems
##
## 
sub get_orderiteminfo {
	my ($self,$inf_orderid,$inf_productid) = @_;

	my $inf_orderitems = $self->doQuery(	
										"DataService.findByField",{
										"Table"			=> "OrderItem",
										"Column"			=> "OrderId",
										"Value"			=> $inf_orderid,
										"ReturnFields"	=> ["ProductId"]});

	my $inf_orderitemid = $inf_orderitems->[0]->{'ProductId'};
	
	$self->log("get_orderiteminfo: $inf_orderitemid");

	return($inf_orderitemid);
	}



sub get_productinfo {
	my ($self,$PID) = @_;

	my $products = $self->doQuery(	
										"DataService.findByField",{
										"Table"			=> "Product",
										"Column"			=> "Sku",
										"Value"			=> $PID,
										"ReturnFields"	=> ["Id"]});

	my $inf_productid = $products->[0]->{'Id'};
	
	$self->log("get_productinfo for $PID: $inf_productid");
	return($inf_productid);
	}


## get current groupinfo for this merchant
sub get_groupinfo {
	my ($self) = @_;

	my $groups = $self->doQuery(	
										"DataService.findByField",{
										"Table"			=> "ContactGroup",
										"Column"			=> "GroupName",
										"Value"			=> '%',
										"ReturnFields"	=> ["Id","GroupName","GroupDescription","GroupCategoryId"]});

	$self->log("get_groupinfo: $groups");
	return($groups);
	}

## get current invoiceinfo for this merchant
sub get_invoiceinfo {
	my ($self) = @_;

	my $invoices = $self->doQuery(	
										"DataService.findByField",{
										"Table"			=> "OrderItem",
										"Column"			=> "ItemDescription",
										"Value"			=> '%',
										"ReturnFields"	=> ["Id","OrderId","ItemName","ItemDescription"]});

	$self->log("get_invoiceinfo: $invoices");
	return($invoices);
	}


##	doQuery = query the DB  
##
## input: Service Call, Call params
## output: Call results, array of hashrefs
##
sub doQuery {
	my ($self,$SERVICE,$paramsref) = @_;

	my $results = $self->{'CLIENT'}->call(
						$SERVICE, 
						$self->{'KEY'},
						$paramsref->{'Table'},				## query table
						100,0,									## return first X results, from the Y page
						$paramsref->{'Column'},				## query this column	
						$paramsref->{'Value'},				## using this value
						$paramsref->{'ReturnFields'});	## return these fields
								
	return($results);
	}

##	doSubmit = add/update the DB  
##
## input: Service Call, Call params
## output: Call results, normally just contactid
##
sub doSubmit {
	my ($self,$SERVICE,$paramsref) = @_;

	my $results = ();

		$results = $self->{'CLIENT'}->call(
						$SERVICE, 
						$self->{'KEY'},
#						$paramsref->{'Table'},				## submit to this table
						$paramsref->{'Values'});			## using this value

	return($results);
	}

1;