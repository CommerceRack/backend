package REPORT::SALES;

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
	$meta->{'title'} = "Sales Report: ".'Period '.&ZTOOLKIT::pretty_date($meta->{'.start_gmt'},1).' to '.&ZTOOLKIT::pretty_date($meta->{'.end_gmt'},1);

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
		{ id=>0, 'name'=>'Order Id', type=>'CHR', linksto=>'ORDER', target=>'_blank' },
		{ id=>1, 'name'=>'Full Name', type=>'CHR', },
		{ id=>2, 'name'=>'Ship Address', type=>'CHR', },
		{ id=>3, 'name'=>'Ship City', type=>'CHR', },
		{ id=>4, 'name'=>'Ship Zip', type=>'NUM', },
		{ id=>5, 'name'=>'Ship State', type=>'CHR', },
		{ id=>6, 'name'=>'Ship Country', type=>'CHR' },
		{ id=>7, 'name'=>'Item Count', type=>'NUM' },
		{ id=>8, 'name'=>'Grand Total', type=>'NUM', 'pretext'=>'$', },
		{ id=>9, 'name'=>'Sales Tax', type=>'NUM', 'pretext'=>'$', },
		{ id=>10, 'name'=>'Shipping', type=>'NUM', 'pretext'=>'$', },
		{ id=>11, 'name'=>'Taxable Total', type=>'NUM', hidden=>1 },
		{ id=>12, 'name'=>'Created Date', type=>'CHR' },
		{ id=>13, 'name'=>'PayType', type=>'CHR' },
		{ id=>14, 'name'=>'Paid Date', type=>'CHR' },
		{ id=>15, 'name'=>'Ship Date', type=>'CHR' },
		{ id=>16, 'name'=>'SDomain', type=>'CHR' },
		{ id=>17, 'name'=>'Meta', type=>'CHR' },
		{ id=>18, 'name'=>'A/B', type=>'CHR' },
		{ id=>19, 'name'=>'Pool', type=>'CHR' },
		];

	$r->{'@SUMMARY'} = [
		{ 'name'=>'Reporting Period', type=>'TITLE' },
		{ 'name'=>'Begins', type=>'LOAD', meta=>'.start_gmt', transform=>'EPOCH-TO-DATETIME', },
		{ 'name'=>'End', type=>'LOAD', meta=>'.end_gmt', transform=>'EPOCH-TO-DATETIME', },

		{ 'name'=>'Totals', type=>'TITLE' },
		{ 'name'=>'Grand Total Sum', type=>'SUM', src=>8, sprintf=>'$%.2f' },
		{ 'name'=>'Sales Tax', type=>'SUM', src=>9, sprintf=>'$%.2f' },
		{ 'name'=>'Taxable Total', type=>'SUM', src=>11, sprintf=>'$%.2f' },
		{ 'name'=>'Shipping', type=>'SUM', src=>10, sprintf=>'$%.2f'},
		{ 'name'=>'Order Count', type=>'CNT', src=>0 },
		{ 'name'=>'Items Sold', type=>'SUM', src=>7 },

		{ 'name'=>'Averages', type=>'TITLE' },
		{ 'name'=>'Average Sale', type=>'AVG', src=>8, sprintf=>'$%.2f' },
		{ 'name'=>'Average Shipping', type=>'AVG', src=>10, sprintf=>'$%.2f' },
		];

	$r->{'@DASHBOARD'} = [
			{ 
			'name'=>'Sales by Country', 
			'@HEAD'=>[ 
				{ type=>'CHR', name=>'Country', src=>6 },
				{ type=>'CNT', name=>'Order Count', src=>0 },
				{ type=>'SUM', name=>'Item Count', src=>7 },
				{ type=>'SUM', name=>'Order Total', src=>8 },
				{ type=>'SUM', name=>'Sales Tax', src=>9 },
				{ type=>'SUM', name=>'Shipping', src=>10 },
				],
			'groupby'=>6, 			
			'@GRAPHS'=>[ 'sales-country-pie', 'sales-country-bar' ],
			},

			{ 
			'name'=>'Sales by State', 
			'@HEAD'=>[ 
				{ type=>'CHR', name=>'State', src=>5 },
				{ type=>'CNT', name=>'Order Count', src=>0 },
				{ type=>'SUM', name=>'Item Count', src=>7 },
				{ type=>'SUM', name=>'Order Total', src=>8 },
				{ type=>'SUM', name=>'Sales Tax', src=>9 },
				{ type=>'SUM', name=>'Shipping', src=>10 },
				],
			'groupby'=>5, 			
			'@GRAPHS'=>[ 'sales-state-pie', 'sales-state-bar' ],
			},

			{ 
			'name'=>'Sales by Zip', 
			'@HEAD'=>[ 
				{ type=>'CHR', name=>'Zip', src=>4 },
				{ type=>'SUM', name=>'Item Count', src=>7 },
				{ type=>'CNT', name=>'Order Count', src=>0 },
				{ type=>'SUM', name=>'Order Total', src=>8, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Sales Tax', src=>9, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Shipping', src=>10, sprintf=>'$%.2f' },
				],
			'groupby'=>4, 			
			},
			{ 
			'name'=>'Sales by SDomain', 
			'@HEAD'=>[ 
				{ type=>'CHR', name=>'SDomain', src=>16 },
				{ type=>'SUM', name=>'Item Count', src=>7 },
				{ type=>'CNT', name=>'Order Count', src=>0 },
				{ type=>'SUM', name=>'Order Total', src=>8, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Sales Tax', src=>9, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Shipping', src=>10, sprintf=>'$%.2f' },
				],
			'groupby'=>16, 			
			},
			{ 
			'name'=>'Sales for A/B', 
			'@HEAD'=>[ 
				{ type=>'CHR', name=>'SDomain', src=>16 },
				{ type=>'CHR', name=>'A/B', src=>18 },
				{ type=>'SUM', name=>'Item Count', src=>7 },
				{ type=>'CNT', name=>'Order Count', src=>0 },
				{ type=>'SUM', name=>'Order Total', src=>8, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Sales Tax', src=>9, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Shipping', src=>10, sprintf=>'$%.2f' },
				],
			'groupby'=>[16,18], 			
			},
			{ 
			'name'=>'Sales by Meta/Affiliate', 
			'@HEAD'=>[ 
				{ type=>'CHR', name=>'Meta', src=>17 },
				{ type=>'SUM', name=>'Item Count', src=>7 },
				{ type=>'CNT', name=>'Order Count', src=>0 },
				{ type=>'SUM', name=>'Order Total', src=>8, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Sales Tax', src=>9, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Shipping', src=>10, sprintf=>'$%.2f' },
				],
			'groupby'=>17, 			
			},
		];

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

	my $odbh =&DBINFO::db_user_connect($USERNAME);
   my $ORDERTB = &DBINFO::resolve_orders_tb($USERNAME,$MID);
	my @orders = ();
   my $pstmt = "select ORDERID,POOL from $ORDERTB where MID=$MID /* $USERNAME */ and CREATED_GMT>=".int($metaref->{'.start_gmt'})." and CREATED_GMT<".int($metaref->{'.end_gmt'});
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

	my $batch = pop @{$self->{'@JOBS'}};
	foreach my $orderid (@orders) {
		# print STDERR "USERNAME=[$USERNAME] [$orderid]\n";
		my ($O2) = CART2->new_from_oid($USERNAME,$orderid);

		next if (not defined $O2);
		next if (ref($O2->stuff2()) ne 'STUFF2');

		my $country = $O2->in_get('ship/countrycode');
		my $state = $O2->in_get('ship/region');
		my $zip = $O2->in_get('ship/postal');
		my $city = $O2->in_get('ship/city');
		my $address = $O2->in_get('ship/address1'). " ". $O2->in_get('ship/address2');
		my $name = $O2->in_get('ship/firstname')." ".$O2->in_get('ship/lastname');
		my $pool = $O2->pool();

		if ($country eq '') { 
			if ($state eq '') { $state = $O2->in_get('ship/region'); }
			if ($zip eq '') { $state = $O2->in_get('ship/postal'); }
			$country = 'UNITED STATES'; 
			}

		# we only keep the taxable total if the tax_rate > 0
		my $tax_total = 0;
		if ($O2->in_get('our/tax_rate') > 0) { $tax_total = $O2->in_get('sum/items_total'); }		
		my $c_gmt = $O2->in_get('our/order_ts');
		my $p_gmt = $O2->in_get('flow/paid_ts');
		my $s_gmt = $O2->in_get('flow/shipped_ts');
		my $sdomain = $O2->in_get('our/domain');
		my $meta = $O2->in_get('cart/refer');
		my $mvs = $O2->in_get('cart/multivarsite');

		my @ROW = (	$orderid,
						$name,
						$address,
						$city, 
						$zip, 
						$state, 
						$country, 
						$O2->in_get('sum/items_count'), 
						sprintf("%.2f",$O2->in_get('sum/order_total')),
						sprintf("%.2f",$O2->in_get('sum/tax_total')),
						sprintf("%.2f",$O2->in_get('sum/shp_total')),
						$tax_total,
						($c_gmt)?BATCHJOB::REPORT::yyyy_mm_dd_time($c_gmt):'',
						$O2->payment_method(),
						($p_gmt)?BATCHJOB::REPORT::yyyy_mm_dd_time($p_gmt):'',
						($s_gmt)?BATCHJOB::REPORT::yyyy_mm_dd_time($s_gmt):'',
						$sdomain,
						$meta,
						$mvs,
						$pool,
						);
		push @{$r->{'@BODY'}}, \@ROW;

		$reccount++;
		if (substr($orderid,-2) eq '00') {
			$r->progress($reccount,$rectotal,"processed order: $orderid");
			}
		}
	

	$r->progress($rectotal,$rectotal,"included $reccount/$rectotal orders");
   &DBINFO::db_user_close();
	return();
	}




1;

