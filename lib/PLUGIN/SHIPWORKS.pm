package PLUGIN::SHIPWORKS;

use strict;
use Data::Dumper;
use XML::Writer;
use Date::Parse;
use Date::Format;
use lib "/backend/lib";
require ORDER::BATCH;
require CART2;
require STUFF2;

sub username { return($_[0]->dnsinfo()->{'USERNAME'}); }
sub prt { return($_[0]->dnsinfo()->{'USERNAME'}); }

sub vars { return($_[0]->{'%VARS'} || {}); }
sub dnsinfo { return($_[0]->{'%DNSINFO'} || {}); }

sub new {
	my ($class, $DNSINFO, $VARSREF) = @_;

	my ($self) = {
		'%DNSINFO'=>$DNSINFO,
		'%VARS'=>$VARSREF,
		};
	bless $self, 'PLUGIN::SHIPWORKS';

	return($self);
	}

%PLUGIN::SHIPWORKS::STATUS_CODES = (
	'RECENT'=>100,
	'REVIEW'=>200,
	'HOLD'=>300,
	'PENDING'=>400,
	'APPROVED'=>500,
	'PROCESS'=>600,
	'COMPLETED'=>700,
	'DELETED'=>800,
	'QUOTE'=>900,
	'BACKORDER'=>1000,
	'PREORDER'=>50,
	'ARCHIVE'=>2000,
	);


sub jsonapi {
	my ($self, $path, $req, $HEADERS) = @_;

	my $VARS = $self->vars();
	my $HTTP_RESPONSE = 200;

	my $ACTION = $VARS->{'action'};
	my $BODY = '';

	open F, ">/dev/shm/shipworks.debug";
	print F Dumper($VARS);
	close F;

	my $USERNAME = $self->username();

	## ShipWorks username and password
	my $SHIPUSER = lc($VARS->{'username'});
	my $SHIPPASS = lc($VARS->{'password'});
	my $ERROR = undef;
	
	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
	my $SHIPCFG = $gref->{'%plugins'}->{'shipworks.com'} || {};

	#if ($SHIPCFG->{'password'} eq '') { $SHIPCFG->{'password'} = 'tryme'; }
	#if ($SHIPUSER ne $USERNAME) {
	#	$ERROR = [ 98, sprintf('Incorrect Shipworks username for this domain (use: %s)',$USERNAME) ];
	#	}
	if (not $SHIPCFG->{'enable'}) {
		$ERROR = [ 96, 'Shipworks Not enabled' ];
		}
	elsif ($SHIPCFG->{'~password'} eq '') {
		$ERROR = [ 97, 'Password is not set / Shipworks not initialized' ];
		}
	elsif ($SHIPCFG->{'~password'} ne $SHIPPASS) {
		$ERROR = [ 99, sprintf("Password '%s' invalid for '%s'",$SHIPPASS,$USERNAME) ];
		}

	my $FILTER_KEY = $VARS->{'filter'};
	my $FILTER_VALUE = $VARS->{'match'};

	my $REDIS_KEY = "SHIPWORKS";
	if ($FILTER_KEY) { $REDIS_KEY = sprintf("SHIPWORKS.%s.%s",$FILTER_KEY,$FILTER_VALUE); }

	my $writer = new XML::Writer(OUTPUT => \$BODY, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');
	$writer->startTag('ShipWorks', moduleVersion=>"$JSONAPI::VERSION.0.0", 'schemaVersion'=>'1.0.0' );
	

	if (defined $ERROR) {
		}
	elsif ($ACTION eq 'getmodule') {	
		## Call 1
		# ShipWorks makes this call to ensure the module capabilities are kept up-to-date.
		$writer->startTag('Module');
		$writer->dataElement('Platform',"CommerceRack");
		$writer->dataElement('Developer',"Zoovy, Inc. (billing\@zoovy.com)");
		$writer->startTag('Capabilities');
		$writer->dataElement('DownloadStrategy','ByModifiedTime');
		$writer->emptyTag('OnlineCustomerID', 'supported'=>'true' );
		$writer->emptyTag('OnlineStatus', 'supported'=>'true', 'dataType'=>'numeric', 'supportsComments'=>'true' );
		$writer->emptyTag('OnlineShipmentUpdate', 'supported'=>'true' );
		$writer->endTag('Capabilities');
		$writer->endTag('Module');
		}
	elsif ($ACTION eq 'getstore') {
		$writer->startTag('Store');
		$writer->dataElement('Name',sprintf("%s",$self->dnsinfo()->{'USERNAME'}));
		#$writer->dataElement('CompanyOrOwner','');
		#$writer->dataElement('Email','');
		$writer->endTag('Store');
		}
	elsif ($ACTION eq 'getstatuscodes') {
		## Call 2: Not used (perhaps we ought to use payment here)
		# This call will be made only when OnlineStatus was marked as supported in the GetModule
		# response. This happens on every download cycle to make sure all status codes are up-to-date
		# before download the orders which await.
		## WE DO NOT USE THIS!
		$writer->startTag('StatusCodes');
		foreach my $pool (keys %PLUGIN::SHIPWORKS::STATUS_CODES) {
			my $code = $PLUGIN::SHIPWORKS::STATUS_CODES{ $pool };
			$writer->startTag('StatusCode');
			$writer->dataElement('Code',$code);
			$writer->dataElement('Name',$pool);
			$writer->endTag('StatusCode');
			}
		$writer->endTag('StatusCodes');
		## $ERROR = [ 1, 'Not supported' ];
		}
	elsif ($ACTION eq 'getcount') {
		## Call 3: 
		# ShipWorks makes the request to determine how many orders exist to be downloaded. The
		# count returned is used to calculate and display download progress to the user. If the returned
		# count is 0, the download operation is considered complete and no further calls are made.

		## 2014-02-12T02:10:34
		## open F, ">/tmp/start"; print F Dumper($VARS); close F;

		my $TS = Date::Parse::str2time(sprintf("%s UTC",$VARS->{'start'})) || (86400*30);
		my $redis = &ZOOVY::getRedis($self->username());
		
		my ($tsref,$statref,$ctimeref) = &ORDER::BATCH::list_orders($self->username(),'',$TS,$FILTER_KEY,$FILTER_VALUE);
		foreach my $orderid (keys %{$tsref}) {
			$redis->sadd($REDIS_KEY,$orderid);
			}
		$redis->expire($REDIS_KEY,43200);

		my $count = $redis->scard($REDIS_KEY);
		$writer->dataElement('OrderCount',$count);	

		}
	elsif ($ACTION eq 'getorders') {
		# ShipWorks will continue making GetOrders calls, repeatedly, until no orders are returned in the
		# response. If orders are continually returned to ShipWorks, the download will proceed infinitely.
		# The maxcount parameter is simply a requested batch size, or number of orders desired to be in
		# this call’s response. Please beware this is simply a recommended response size – when the
		# download strategy is ByModifiedTime care must be taken to ensure that orders with matching
		# Modified Time do not span batches. This would result in orders being skipped since
		# ShipWorks would re-request orders with a new start value on the next GetOrders call which
		# would not include those skipped orders. If this scenario arises, simply return as many orders as
		# necessary without regard to the maxcount value.
		# Once again, downloading will be considered complete when no orders are returned.		

		my $redis = &ZOOVY::getRedis($self->username());
		my ($maxcount) = int($VARS->{'maxcount'}) || 1;
		if ($maxcount>25) { $maxcount = 10; }

		$writer->startTag('Orders');
		while (--$maxcount >= 0) {
			my ($orderid) = $redis->spop($REDIS_KEY);
			next if ($orderid eq '');

			my ($O2) = CART2->new_from_oid($self->username(),$orderid);

			$writer->startTag('Order');
			my $OID = $O2->oid();
			$OID =~ s/[^\d]+//gs;
			$writer->dataElement('OrderNumber',$OID);
			$writer->dataElement('OrderDate', Date::Format::time2str("%Y-%m-%dT%H:%M:%S",$O2->in_get('our/order_ts')));
			$writer->dataElement('LastModified', Date::Format::time2str("%Y-%m-%dT%H:%M:%S",$O2->in_get('flow/modified_ts')));
			$writer->dataElement('ShippingMethod', $O2->in_get('sum/shp_method'));
			$writer->dataElement('StatusCode', $PLUGIN::SHIPWORKS::STATUS_CODES{ $O2->in_get('flow/pool') } );
			$writer->dataElement('CustomerID', $O2->in_get('customer/cid') );
			$writer->startTag('Notes');
				if ($O2->in_get('want/order_notes') ne '') {
					$writer->dataElement('Note',$O2->in_get('want/order_notes'));
					}
				if ($O2->in_get('flow/private_notes') ne '') {
					$writer->dataElement('Note',$O2->in_get('flow/private_notes'),'public'=>'false');
					}
			$writer->endTag('Notes');
			$writer->startTag('ShippingAddress');
				# $writer->dataElement('FullName','');
				$writer->dataElement('FirstName', $O2->in_get('ship/firstname') );
				$writer->dataElement('MiddleName', $O2->in_get('ship/middlename'));
				$writer->dataElement('LastName',$O2->in_get('ship/lastname'));

				$writer->dataElement('Company',$O2->in_get('ship/company'));
				$writer->dataElement('Street1',$O2->in_get('ship/address1'));
				$writer->dataElement('Street2',$O2->in_get('ship/address2'));
				# $writer->dataElement('Street3',$O2->in_get(''));
				$writer->dataElement('City',$O2->in_get('ship/city'));
				$writer->dataElement('State',$O2->in_get('ship/region'));
				$writer->dataElement('PostalCode',$O2->in_get('ship/postal'));
				$writer->dataElement('Country',$O2->in_get('ship/countrycode'));
				#$writer->dataElement('Residential',$O2->in_get(''));
				$writer->dataElement('Phone',$O2->in_get('ship/phone'));
				#$writer->dataElement('Fax',$O2->in_get(''));
				#$writer->dataElement('Email',$O2->in_get(''));
				#$writer->dataElement('Website',$O2->in_get(''));
			$writer->endTag('ShippingAddress');
			$writer->startTag('BillingAddress');
				# $writer->dataElement('FullName','');
				$writer->dataElement('FirstName', $O2->in_get('bill/firstname') );
				$writer->dataElement('MiddleName', $O2->in_get('bill/middlename'));
				$writer->dataElement('LastName',$O2->in_get('bill/lastname'));

				$writer->dataElement('Company',$O2->in_get('bill/company'));
				$writer->dataElement('Street1',$O2->in_get('bill/address1'));
				$writer->dataElement('Street2',$O2->in_get('bill/address2'));
				# $writer->dataElement('Street3',$O2->in_get(''));
				$writer->dataElement('City',$O2->in_get('bill/city'));
				$writer->dataElement('State',$O2->in_get('bill/region'));
				$writer->dataElement('PostalCode',$O2->in_get('bill/postal'));
				$writer->dataElement('Country',$O2->in_get('bill/countrycode'));
				#$writer->dataElement('Residential',$O2->in_get(''));
				$writer->dataElement('Phone',$O2->in_get('bill/phone'));
				#$writer->dataElement('Fax',$O2->in_get(''));
				#$writer->dataElement('Email',$O2->in_get(''));
				#$writer->dataElement('Website',$O2->in_get(''));
			$writer->endTag('BillingAddress');
			##
		
#			$writer->startTag('Payment');
#				$writer->dataElement('Method',$O2->in_get(''));
#				$writer->startTag('CreditCard');
#					$writer->dataElement('Type',$O2->in_get(''));
#					$writer->dataElement('Owner',$O2->in_get(''));
#					$writer->dataElement('Number',$O2->in_get(''));
#					$writer->dataElement('Expires',$O2->in_get(''));
#					$writer->dataElement('CCV',$O2->in_get(''));
#				$writer->endTag('CreditCard');
#				$writer->startTag('Detail');
#					## he name of the payment detail item displayed in ShipWorks. Items are displayed as "Name: Value". For example "Discount Code: ABCDEFG"
#					$writer->dataElement('name',$O2->in_get(''));
#					$writer->dataElement('value',$O2->in_get(''));
#				$writer->endTag('Detail');
#			$writer->endTag('Payment');
			## 
			$writer->startTag('Items');
				foreach my $item ( @{$O2->stuff2()->items('real')} ) {
					$writer->startTag('Item');
					$writer->dataElement('ItemID',$item->{'stid'});
					$writer->dataElement('ProductID',$item->{'product'});
					$writer->dataElement('Code',$item->{'uuid'});
					$writer->dataElement('SKU',$item->{'sku'});
					$writer->dataElement('Name',$item->{'description'});
					$writer->dataElement('Quantity',$item->{'qty'});
					$writer->dataElement('UnitPrice',$item->{'price'});
					if ($item->{'cost'} ne '') {
						$writer->dataElement('UnitCost',$item->{'cost'});
						}

					if ($item->{'image'} ne '') {
						$writer->dataElement('Image',&ZOOVY::image_path($self->username(),$item->{'image'}));	# The URL to the full product image.
						$writer->dataElement('ThumbnailImage',&ZOOVY::image_path($self->username(),$item->{'image'}));	# The URL to the full product image.			
						}
					$writer->dataElement('Weight',sprintf("%0.2f",$item->{'weight'}/16));
					$writer->startTag('Attributes');
#                                                      '%options' => {
#                                                                     'AG##' => {
#                                                                               'fee' => '0',
#                                                                               'v' => '##',
#                                                                               'data' => '03/26/2014',
#                                                                               '_' => '/AG##',
#                                                                               'prompt' => 'calendar',
#                                                                               'feetxt' => '',
#                                                                               'inv' => '0',
#                                                                               'id' => 'AG'
#                                                                             }
#                                                                   },
					if ((defined $item->{'%options'}) && (ref($item->{'%options'}) eq 'HASH')) {
						foreach my $code (keys %{$item->{'%options'}}) {
							my $option = $item->{'%options'}->{$code};
							$writer->startTag('Attribute');
							$writer->dataElement('AttributeID',$option->{'id'});
							$writer->dataElement('Name',$option->{'prompt'});
							$writer->dataElement('Value',$option->{'data'} || $option->{'v'});
							if ($item->{'fee'}>0) { $writer->dataElement('Price',$option->{'fee'}); }
							# $writer->dataElement('Debug','');
							$writer->endTag('Attribute');
							}
						}
					$writer->endTag('Attributes');
					$writer->endTag('Item');
					}

			$writer->endTag('Items');
			##

			
			$writer->startTag('Totals');
			if ($O2->in_get('sum/tax_total')>0) {
				$writer->dataElement('Total',$O2->in_get('sum/tax_total'),'name'=>'Tax','class'=>'TAX','impact'=>'add');
				}
			if ($O2->in_get('sum/hnd_total')>0) {
				$writer->dataElement('Total',$O2->in_get('sum/hnd_total'),'name'=>'Handling','class'=>'HND','impact'=>'add');
				}
			if ($O2->in_get('sum/ins_total')>0) {
				$writer->dataElement('Total',$O2->in_get('sum/ins_total'),'name'=>'Insurance','class'=>'INS','impact'=>'add');
				}
			if ($O2->in_get('sum/spc_total')>0) {
				$writer->dataElement('Total',$O2->in_get('sum/spc_total'),'name'=>'Special Fee','class'=>'SPC','impact'=>'add');
				}
			$writer->endTag('Totals');

			$writer->dataElement('Debug',''); 	# Debugging and support data not processed by ShipWorks, but recorded in logs
			$writer->endTag('Order');
			} 
		$writer->endTag('Orders');


		#$writer->startTag('Order');
		#$writer->dataElement('OrderNumber',$o->oid());
		#$writer->endTag('Order');


		}
	elsif ($ACTION eq 'updatestatus') {
		# This call is made once per order being updated. The module should return a success or error
		# response to ShipWorks once the operation is complete.
		# <UpdateSuccess/>
		my ($orderid) = $VARS->{'order'};
		my ($status) = $VARS->{'status'};
		my ($comments) = $VARS->{'comments'};

		open F, ">/tmp/status"; print F Dumper($VARS); close F;
		#$VAR1 = {
      #    'password' => 'test1',
      #    'prt' => '1',
      #    'order' => '201403811',
      #    'status' => '700',
      #    'action' => 'updatestatus',
      #    'comments' => '',
      #    'username' => 'test'
      #  };

		my %LOOKUP = ();
		foreach my $pool (keys %PLUGIN::SHIPWORKS::STATUS_CODES) {
			$LOOKUP{ $PLUGIN::SHIPWORKS::STATUS_CODES{$pool} } = $pool;
			}

		my ($orderid) = $VARS->{'order'};
		$orderid = substr($orderid,0,4).'-'.substr($orderid,4,2).'-'.substr($orderid,6);

		my ($O2) = CART2->new_from_oid($self->username(),$orderid);
		if ((defined $O2) && (ref($O2) eq 'CART2')) {
			$writer->emptyTag('UpdateSuccess');
			$O2->in_set('flow/pool', $LOOKUP{ $VARS->{'status'} });
			$O2->add_history(sprintf("Shipworks set %s - %s", $LOOKUP{ $VARS->{'status'} }, $VARS->{'comments'} ));
			$O2->order_save();
			}
		


      #    'shippingcost' => '0',
      #    'shippingdate' => '2014-03-13T12:00:00',
      #    'username' => 'test',
      #    'carrier' => 'Other',
      #    'password' => 'test1',
      #    'order' => '201403811',
      #    'action' => 'updateshipment',
      #    'tracking' => 'tracking#'

		} 
	elsif ($ACTION eq 'updateshipment') {
		# This call is made once per shipment processed for an order. Like the UpdateStatus call, the
		# module should return a success or error response to ShipWorks once the operation is complete.
		# <UpdateSuccess/>
		my ($orderid) = $VARS->{'order'};
		$orderid = substr($orderid,0,4).'-'.substr($orderid,4,2).'-'.substr($orderid,6);

		my ($O2) = CART2->new_from_oid($self->username(),$orderid);
		if ((defined $O2) && (ref($O2) eq 'CART2')) {
			$writer->emptyTag('UpdateSuccess');
			$O2->set_tracking( $VARS->{'carrier'}, $VARS->{'tracking'}, '', $VARS->{'shippingcost'} );
			$O2->add_history(sprintf("Shipworks added tracking %s - %s", $VARS->{'carrier'}, $VARS->{'tracking'}));
			$O2->order_save();
			}

		}

	if (defined $ERROR) {
		$writer->startTag('Error');
		$writer->dataElement('Code',$ERROR->[0]);
		$writer->dataElement('Description',$ERROR->[1]);
		$writer->endTag('Error');
		}

	## ERROR:
	# <?xml version="1.0" standalone="yes" ?>
	# <ShipWorks moduleVersion="3.0.0" schemaVersion="1.0.0">
	# <Error>
	# <Code>FOO100</Code>
	# <Description>Something Failed. Internal Error.</Description>
	# </Error>
	# </ShipWorks>
	

	$writer->endTag('ShipWorks');
	$writer->end();

	$BODY .= "\n\n";

	open F, ">/dev/shm/shipworks.xml"; print F $BODY;	close F;

	return ($HTTP_RESPONSE, $HEADERS, $BODY);
	}

1;
