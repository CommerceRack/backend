package REPORT::SALES_BY_ORDER_ITEM;



#Top Sellers
#- By Category
#-- Category 1
#-- Category 2
#- By Manufacturer
#-- Manufacturer 1
#-- Manufacturer 2
#- By Promo Type
#-- Promo type 1
#-- Promo type 2
#
#Worst Sellers
#- By Category
#-- Category 1
#-- Category 2
#- By Manufacturer
#-- Manufacturer 1
#-- Manufacturer 2
#- By Promo Type
#-- Promo type 1
#-- Promo type 2
#
#die();



use strict;

use lib "/backend/lib";
require DBINFO;
require CART2;
use Data::Dumper;


##
## REPORT: SALES
##	PARAMS: 
##		period
##			start_gmt
##			end_gmt
##

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub r { return($_[0]->{'*PARENT'}); }


###########################################################################
##
##
##
sub init {
	my ($self, %params) = @_;

	my $r = $self->r();

	my $meta = $r->meta();
	$meta->{'title'} = "Sales by Order Item: ".'Period '.&ZTOOLKIT::pretty_date($meta->{'.start_gmt'},1).' to '.&ZTOOLKIT::pretty_date($meta->{'.end_gmt'},1);

	# $meta->{'subtitle'} = 
	if ($meta->{'.include_deleted'}) { 
		$meta->{'subtitle'} .= 'GROSS Sales: Includes Cancelled Invoices'; 
		}
	else {
		$meta->{'notes'} = "Deleted orders are not included.\n";
		}

	##
	## TODO: throw a warning when start .start_gmt and .end_gmt are the same.	
	##

	$r->{'@HEAD'} = [
		{ id=>0, 'name'=>'Pool', type=>'CHR' },	
		{ id=>1, 'name'=>'Order Id', type=>'CHR' },
		{ id=>2, 'name'=>'Full Name', type=>'CHR' },
		{ id=>3, 'name'=>'SKU', type=>'CHR', },
		{ id=>4, 'name'=>'Product Name', type=>'CHR' },
		{ id=>5, 'name'=>'Units Sold', type=>'NUM', },
		{ id=>6, 'name'=>'Dollars Sold', type=>'NUM', sprintf=>'%.2f' },
		{ id=>7, 'name'=>'Created Date', type=>'CHR', },
		{ id=>8, 'name'=>'Ship Date', type=>'CHR', },
		];

	#$r->{'@SUMMARY'} = [
	#	{ 'name'=>'Reporting Period', type=>'TITLE' },
	#	{ 'name'=>'Begins', type=>'LOAD', meta=>'.start_gmt', transform=>'EPOCH-TO-DATETIME', },
	#	{ 'name'=>'End', type=>'LOAD', meta=>'.end_gmt', transform=>'EPOCH-TO-DATETIME', },
	#	{ 'name'=>'Totals', type=>'TITLE' },
	#	{ 'name'=>'Items Sold', type=>'SUM', src=>5 },
	#	{ 'name'=>'Dollars Sold', type=>'SUM', src=>6,  sprintf=>'$%.2f' },
	#	{ 'name'=>'Averages', type=>'TITLE' },
	#	{ 'name'=>'Average Sale Price', type=>'AVG', src=>6, sprintf=>'$%.2f' },
	#	];

	#$r->{'@DASHBOARD'} = [
	#	];

	$r->{'@BODY'} = [];
	return($self);
	}

##################################################################################
##
##
##
sub work {
	my ($self) = @_;

	my $r = $self->r();
	my $metaref = $r->meta();
	my $USERNAME = $r->username();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	$r->progress(0,0,"Loading Orders");

	print "###### Metaref: ".Dumper($metaref);
	
	my $odbh =&DBINFO::db_user_connect($USERNAME);
   my $ORDERTB = &DBINFO::resolve_orders_tb($USERNAME,$MID);
	my @orders = ();
	my $KEY = '**REPORT_KEY_NOT_SET**';
	if ($metaref->{'.key'}) {$metaref->{'key'} = $metaref->{'.key'}; }	# old jobs
	if ($metaref->{'key'} eq 'CREATED') { $KEY = 'CREATED_GMT'; }
	if ($metaref->{'key'} eq 'PAID') { $KEY = 'PAID_GMT'; }
	if ($metaref->{'key'} eq 'SHIP') { $KEY = 'SHIPPED_GMT'; }

	print "###### KEY: ".Dumper($KEY);
   my $pstmt = "select ORDERID,POOL from $ORDERTB where MID=$MID /* $USERNAME */ and $KEY>=".int($metaref->{'.start_gmt'})." and $KEY<".int($metaref->{'.end_gmt'});
   print STDERR $pstmt."\n";
   my $sth = $odbh->prepare($pstmt);
   $sth->execute();
   while ( my ($orderid,$status) = $sth->fetchrow() ) {
      next if (($metaref->{'.include_deleted'}==0) && ($status eq 'DELETED'));
      next if (($metaref->{'.include_deleted'}==0) && ($status eq 'CANCELLED'));
      push @orders, $orderid;
      }

	my $reccount = 1;
	my $rectotal = scalar(@orders);
	$r->progress($reccount,$rectotal,"Loading orders");

	my %SKU_TO_ROW_MAP = ();	# contains a map of SKU to row #

	my $batch = pop @{$self->{'@JOBS'}};
	foreach my $orderid (@orders) {
		# print STDERR "USERNAME=[$USERNAME] [$orderid]\n";
		my ($O2) = CART2->new_from_oid($USERNAME,$orderid);

		next if (not defined $O2);

		foreach my $item (@{$O2->stuff2()->items()}) {
			my $SKU = $item->{'sku'};
			if ($SKU eq '') { $SKU = $item->{'product'}; }
			my @ROW = ( 
				$O2->in_get('flow/pool'),
				$orderid,
				$O2->in_get('ship/firstname')." ".$O2->in_get('ship/lastname'), 
				$SKU, 
				$item->{'description'}, 
				$item->{'qty'}, 
				$item->{'extended'}, 
				($O2->in_get('our/order_ts'))?BATCHJOB::REPORT::yyyy_mm_dd_time($O2->in_get('our/order_ts')):'',
				($O2->in_get('flow/shipped_ts'))?BATCHJOB::REPORT::yyyy_mm_dd_time($O2->in_get('flow/shipped_ts')):'');
			$SKU_TO_ROW_MAP{$SKU} = scalar(@{$r->{'@BODY'}});	# record row #
			push @{$r->{'@BODY'}}, \@ROW;
			}
		

		$reccount++;
		if (substr($orderid,-2) eq '00') {
			$r->progress($reccount,$rectotal,"processed order: $orderid");
			}
		}
	

	$r->progress($rectotal,$rectotal,"included $reccount/$rectotal orders");
	&DBINFO::db_user_close();
	}




1;

