package REPORT::INVENTORY;


use strict;

use lib "/backend/lib";
require DBINFO;
require PRODUCT;
require ZOOVY;
require PRODUCT;
require INVENTORY2;
use Data::Dumper;

##
## these methods should be included in the header of every report::module
##
sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub r { return($_[0]->{'*PARENT'}); }


sub init {
	my ($self) = @_;

	my $r = $self->r();
	my $meta = $r->meta();
	my $USERNAME = $r->username();
	my $MID = $r->mid();
	
	$meta->{'title'} = 'Inventory Detail Report';
	$meta->{'subtitle'} = '';

	$r->{'@BODY'} = [];

	return();
	}


###################################################################################
##
##
sub work {
	my ($self) = @_;

	my $r = $self->r();
	my ($bj) = $r->bj();
	my $meta = $r->meta();
	my $USERNAME = $r->username();
	my $MID = $r->mid();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my $INV2 = INVENTORY2->new($USERNAME);	

	$r->progress(0,0,"Generating report.");

	my @HEAD = ();
#	push @HEAD, { id=>0, 'name'=>'SKU', type=>'CHR', };
#	push @HEAD, { id=>1, 'name'=>'Product', type=>'CHR', link=>'/biz/product/index.cgi?goto=modify_product.cgi%3Fproduct%3D', target=>'_blank' };
#	push @HEAD, { id=>2, 'name'=>'Options', type=>'CHR', };
#	push @HEAD, { id=>3, 'name'=>'Product Name', type=>'CHR', width=>'200'};
#	push @HEAD, { id=>4, 'name'=>'Unlimited', type=>'CHR', };
#	push @HEAD, { id=>5, 'name'=>'In Stock', type=>'NUM' };
#	push @HEAD, { id=>6, 'name'=>'Reserved', type=>'NUM' };
#	push @HEAD, { id=>7, 'name'=>'Reorder Qty', type=>'NUM' };
#	push @HEAD, { id=>8, 'name'=>'Cost', type=>'NUM', 'pretext'=>'$' };
#	push @HEAD, { id=>9, 'name'=>'Sale Price', type=>'NUM', 'pretext'=>'$' };
#	push @HEAD, { id=>10, 'name'=>'Catalog', type=>'CHR' };
#	push @HEAD, { id=>11, 'name'=>'Manufacturer', type=>'CHR' };
#	push @HEAD, { id=>12, 'name'=>'Manufacturer ID', type=>'CHR' };
#	push @HEAD, { id=>13, 'name'=>'Supplier', type=>'CHR' };
#	push @HEAD, { id=>14, 'name'=>'Consigner', type=>'CHR' };
#	push @HEAD, { id=>15, 'name'=>'UPC', type=>'CHR' };
#	push @HEAD, { id=>16, 'name'=>'Location', type=>'CHR' };

	my %options = ();
	if ($meta->{'where'}) {
		## WHERE=AVAILABLE,GT,0
		my @WHERES = ();
		foreach my $line ( split(/[\n\r]+/,$meta->{'where'}) ) {
			next if ($line eq '');
			my @VALS = split(/\,/,$meta->{'META'},3);
			## in is an array for a set.
			if ($VALS[1] eq 'IN') { $VALS[2] = [ split(/,/,$VALS[2]) ]; }
			push @WHERES, \@VALS;
			}
		$options{'@WHERE'} = \@WHERES;
		}


	if ($meta->{'BASETYPE'}) {
		$options{'BASETYPE'} = $meta->{'BASETYPE'};
		$meta->{'headers'} = 'SIMPLE';
		}

	if ((defined $meta->{'product_selectors'}) && ($meta->{'product_selectors'} ne '')) {
		$r->progress(0,0,"resolving product selectors.");
		require PRODUCT::BATCH;
		my @SELECTORS = split(/\n/,$meta->{'product_selectors'});
		print Dumper(\@SELECTORS);
		my @PIDS = &PRODUCT::BATCH::resolveProductSelector($bj->username(),$bj->prt(),\@SELECTORS);
		$options{'@PIDS'} = \@PIDS;
		}

	if (not defined $meta->{'headers'}) { $meta->{'headers'} = 'ALL'; }
	if ($meta->{'headers'} eq 'ALL') {
		push @HEAD, { 'id'=>'UUID', 'name'=>'UUID', type=>'CHR' };
		push @HEAD, { 'id'=>'PID', 'name'=>'PID', type=>'CHR' };
		push @HEAD, { 'id'=>'SKU', 'name'=>'SKU', type=>'CHR' };
		push @HEAD, { 'id'=>'WMS_GEO', 'name'=>'WMS_GEO', type=>'CHR' };
		push @HEAD, { 'id'=>'WMS_ZONE', 'name'=>'WMS_ZONE', type=>'CHR' };
		push @HEAD, { 'id'=>'WMS_POS', 'name'=>'WMS_POS', type=>'CHR' };
		push @HEAD, { 'id'=>'QTY', 'name'=>'QTY', type=>'CHR' };
		push @HEAD, { 'id'=>'COST_I', 'name'=>'COST', type=>'CURRENCY' };
		push @HEAD, { 'id'=>'NOTE', 'name'=>'NOTE', type=>'CHR' };
		push @HEAD, { 'id'=>'CONTAINER', 'name'=>'CONTAINER', type=>'CHR' };
		push @HEAD, { 'id'=>'ORIGIN', 'name'=>'ORIGIN', type=>'CHR' };
		push @HEAD, { 'id'=>'BASETYPE', 'name'=>'BASETYPE', type=>'CHR' };
		push @HEAD, { 'id'=>'SUPPLIER_ID', 'name'=>'SUPPLIER_ID', type=>'CHR' };
		push @HEAD, { 'id'=>'SUPPLIER_SKU', 'name'=>'SUPPLIER_SKU', type=>'CHR' };
		push @HEAD, { 'id'=>'MARKET_DST', 'name'=>'MARKET_DST', type=>'CHR' };
		push @HEAD, { 'id'=>'MARKET_REFID', 'name'=>'MARKET_REFID', type=>'CHR' };
		push @HEAD, { 'id'=>'MARKET_ENDS_TS', 'name'=>'MARKET_ENDS_TS', type=>'TS' };
		push @HEAD, { 'id'=>'MARKET_SOLD_QTY', 'name'=>'MARKET_SOLD_QTY', type=>'CHR' };
		push @HEAD, { 'id'=>'MARKET_SALE_TS', 'name'=>'MARKET_SALE_TS', type=>'TS' };
		push @HEAD, { 'id'=>'PREFERENCE', 'name'=>'PREFERENCE', type=>'INT' };
		push @HEAD, { 'id'=>'CREATED_TS', 'name'=>'CREATED_TS', type=>'TS' };
		push @HEAD, { 'id'=>'MODIFIED_TS', 'name'=>'MODIFIED_TS', type=>'TS' };
		push @HEAD, { 'id'=>'MODIFIED_BY', 'name'=>'MODIFIED_BY', type=>'CHR' };
		push @HEAD, { 'id'=>'MODIFIED_INC', 'name'=>'MODIFIED_INC', type=>'INT' };
		push @HEAD, { 'id'=>'MODIFIED_QTY_WAS', 'name'=>'MODIFIED_QTY_WAS', type=>'INT' };
		push @HEAD, { 'id'=>'VERIFY_TS', 'name'=>'VERIFY_TS', type=>'CHR' };
		push @HEAD, { 'id'=>'VERIFY_INC', 'name'=>'VERIFY_INC', type=>'CHR' };
		push @HEAD, { 'id'=>'OUR_ORDERID', 'name'=>'OUR_ORDERID', type=>'CHR' };
		push @HEAD, { 'id'=>'PICK_BATCHID', 'name'=>'PICK_BATCHID', type=>'CHR' };
		push @HEAD, { 'id'=>'PICK_ROUTE', 'name'=>'PICK_ROUTE', type=>'CHR' };
		push @HEAD, { 'id'=>'PICK_DONE_TS', 'name'=>'PICK_DONE_TS', type=>'CHR' };
		push @HEAD, { 'id'=>'GRPASM_REF', 'name'=>'GRPASM_REF', type=>'CHR' };
		push @HEAD, { 'id'=>'DESCRIPTION', 'name'=>'DESCRIPTION', type=>'CHR' };
		push @HEAD, { 'id'=>'VENDOR_STATUS', 'name'=>'VENDOR_STATUS', type=>'CHR' };
		push @HEAD, { 'id'=>'VENDOR', 'name'=>'VENDOR', type=>'CHR' };
		push @HEAD, { 'id'=>'VENDOR_ORDER_DBID', 'name'=>'VENDOR_ORDER_DBID', type=>'CHR' };
		push @HEAD, { 'id'=>'VENDOR_SKU', 'name'=>'VENDOR_SKU', type=>'CHR' };
		$options{'+'} = 'ALL';
		}
	elsif ($meta->{'headers'} eq 'WMS') {
		push @HEAD, { 'id'=>'UUID', 'name'=>'UUID', type=>'CHR' };
		push @HEAD, { 'id'=>'PID', 'name'=>'PID', type=>'CHR' };
		push @HEAD, { 'id'=>'SKU', 'name'=>'SKU', type=>'CHR' };
		push @HEAD, { 'id'=>'PREFERENCE', 'name'=>'PREFERENCE', type=>'CHR' };
		push @HEAD, { 'id'=>'WMS_GEO', 'name'=>'WMS_GEO', 'type'=>'CHR' };
		push @HEAD, { 'id'=>'WMS_ZONE', 'name'=>'WMS_ZONE', 'type'=>'CHR' };
		push @HEAD, { 'id'=>'WMS_POS', 'name'=>'WMS_POS', 'type'=>'CHR' };
		push @HEAD, { 'id'=>'COST_I', 'name'=>'COST', 'type'=>'CURRENCY' };
		push @HEAD, { 'id'=>'NOTE', 'name'=>'NOTE', 'type'=>'NOTE' };
		$options{'+'} = 'WMS';
		}
	elsif ($meta->{'headers'} eq 'SIMPLE') {
		push @HEAD, { 'id'=>'PID', 'name'=>'PID', type=>'CHR' };
		push @HEAD, { 'id'=>'SKU', 'name'=>'SKU', type=>'CHR' };
		push @HEAD, { 'id'=>'QTY', 'name'=>'QTY', 'type'=>'CHR' };
		push @HEAD, { 'id'=>'COST_I', 'name'=>'COST', 'type'=>'CURRENCY' };
		push @HEAD, { 'id'=>'NOTE', 'name'=>'NOTE', 'type'=>'NOTE' };
		$options{'+'} = 'SIMPLE';
		}
	elsif ($meta->{'headers'} eq 'SUPPLIER') {
		push @HEAD, { 'id'=>'UUID', 'name'=>'UUID', type=>'CHR' };
		push @HEAD, { 'id'=>'PID', 'name'=>'PID', type=>'CHR' };
		push @HEAD, { 'id'=>'SKU', 'name'=>'SKU', type=>'CHR' };
		push @HEAD, { 'id'=>'PREFERENCE', 'name'=>'PREFERENCE', type=>'CHR' };
		push @HEAD, { 'id'=>'SUPPLIER_ID', 'name'=>'SUPPLIER_ID', 'type'=>'CHR' };
		push @HEAD, { 'id'=>'NOTE', 'name'=>'NOTE', 'type'=>'NOTE' };
		$options{'+'} = 'SUPPLIER';
		}
	elsif ($meta->{'headers'} eq 'ORDER') {
		push @HEAD, { 'id'=>'UUID', 'name'=>'UUID', type=>'CHR' };
		push @HEAD, { 'id'=>'PID', 'name'=>'PID', type=>'CHR' };
		push @HEAD, { 'id'=>'SKU', 'name'=>'SKU', type=>'CHR' };
		push @HEAD, { 'id'=>'BASETYPE', 'name'=>'BASETYPE', type=>'CHR' };
		push @HEAD, { 'id'=>'OUR_ORDERID', 'name'=>'OUR_ORDERID', type=>'CHR' };
		push @HEAD, { 'id'=>'PICK_BATCHID', 'name'=>'PICK_BATCHID', type=>'CHR' };
		push @HEAD, { 'id'=>'PICK_ROUTE', 'name'=>'PICK_ROUTE', type=>'CHR' };
		push @HEAD, { 'id'=>'PICK_DONE_TS', 'name'=>'PICK_DONE_TS', type=>'TS' };
		push @HEAD, { 'id'=>'DESCRIPTION', 'name'=>'DESCRIPTION', type=>'CHR' };
		push @HEAD, { 'id'=>'VENDOR_STATUS', 'name'=>'VENDOR_STATUS', type=>'CHR' };
		push @HEAD, { 'id'=>'VENDOR', 'name'=>'VENDOR', type=>'CHR' };
		push @HEAD, { 'id'=>'VENDOR_ORDER_DBID', 'name'=>'VENDOR_ORDER_DBID', type=>'CHR' };
		push @HEAD, { 'id'=>'VENDOR_SKU', 'name'=>'VENDOR_SKU', type=>'CHR' };
		push @HEAD, { 'id'=>'NOTE', 'name'=>'NOTE', 'type'=>'NOTE' };
		$options{'+'} = 'ORDER';
		}
	elsif ($meta->{'headers'} eq 'ROUTE') {
		$options{'+'} = 'ROUTE';
		push @HEAD, { 'id'=>'UUID', 'name'=>'UUID', type=>'CHR' };
		push @HEAD, { 'id'=>'PID', 'name'=>'PID', type=>'CHR' };
		push @HEAD, { 'id'=>'SKU', 'name'=>'SKU', type=>'CHR' };
		push @HEAD, { 'id'=>'PICK_BATCHID', 'name'=>'PICK_BATCHID', type=>'CHR' };
		push @HEAD, { 'id'=>'PICK_ROUTE', 'name'=>'PICK_ROUTE', type=>'CHR' };
		push @HEAD, { 'id'=>'PICK_DONE_TS', 'name'=>'PICK_DONE_TS', type=>'TS' };
		push @HEAD, { 'id'=>'NOTE', 'name'=>'NOTE', 'type'=>'NOTE' };
		}
	if (defined $meta->{'basetypes'}) {
		my @BASETYPES = split(/,/,$meta->{'basetypes'});
		$options{'@BASETYPES'} = \@BASETYPES;
		}

	if (defined $meta->{'wms_geo'}) { $options{'GEO'} = $meta->{'wms_geo'}; }

	$r->progress(0,0,"compiling data.");
	$r->{'@HEAD'} = \@HEAD;
	my $rows = $INV2->detail(%options);

	# my $mref = $P->skuref($SKU);

	$r->progress(0,0,"compiling data.");
	foreach my $row (@{$rows}) {
		my @ROW = ();
		foreach my $h (@HEAD) {	
			if ($h->{'type'} eq 'CURRENCY') {
				push @ROW, sprintf("%.2f",$row->{ $h->{'id'} }/100); 
				}
			else {
				push @ROW, $row->{ $h->{'id'} }; 
				}
			}
		push @{$r->{'@BODY'}}, \@ROW;
		}


	my $rectotal = scalar(@{$r->{'@BODY'}});
	$r->progress($rectotal,$rectotal,"did $rectotal records");
	&DBINFO::db_user_close();	
	}



1;

