
package REPORT::SALES_BY_SCHEDULE;

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
	$meta->{'title'} = "Sales By Schedule: ".'Period '.&ZTOOLKIT::pretty_date($meta->{'.start_gmt'},1).' to '.&ZTOOLKIT::pretty_date($meta->{'.end_gmt'},1);

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
		{ id=>1, 'name'=>'Item Count', type=>'NUM' },
		{ id=>2, 'name'=>'Grand Total', type=>'NUM', 'pretext'=>'$', },
		{ id=>3, 'name'=>'Subtotal', type=>'NUM', 'pretext'=>'$', },
		{ id=>4, 'name'=>'Sales Tax', type=>'NUM', 'pretext'=>'$', },
		{ id=>5, 'name'=>'Shipping and Handling', type=>'NUM', 'pretext'=>'$', },
		{ id=>6, 'name'=>'Cost Total', type=>'NUM', 'pretext'=>'$', },
		{ id=>7, 'name'=>'Subtotal Minus Cost', type=>'NUM', 'pretext'=>'$', },
		{ id=>8, 'name'=>'Schedule', type=>'CHR', },
		{ id=>9, 'name'=>'Has Schedule', type=>'CHR', },
		];

	$r->{'@SUMMARY'} = [
		{ 'name'=>'Reporting Period', type=>'TITLE' },
		{ 'name'=>'Begins', type=>'LOAD', meta=>'.start_gmt', transform=>'EPOCH-TO-DATETIME', },
		{ 'name'=>'End', type=>'LOAD', meta=>'.end_gmt', transform=>'EPOCH-TO-DATETIME', },

		{ 'name'=>'Totals', type=>'TITLE' },
		{ 'name'=>'Grand Total Sum', type=>'SUM', src=>2, sprintf=>'$%.2f' },
		{ 'name'=>'Subtotal', type=>'SUM', src=>3, sprintf=>'$%.2f' },
		{ 'name'=>'Sales Tax', type=>'SUM', src=>4, sprintf=>'$%.2f' },
		{ 'name'=>'Order Count', type=>'CNT', src=>0 },
		{ 'name'=>'Items Sold', type=>'SUM', src=>1 },
		{ 'name'=>'Cost Total', type=>'SUM', src=>6, sprintf=>'$%.2f'  },

		{ 'name'=>'Averages', type=>'TITLE' },
		{ 'name'=>'Average Sale', type=>'AVG', src=>2, sprintf=>'$%.2f' },
		{ 'name'=>'Average Shipping and Handling', type=>'AVG', src=>5, sprintf=>'$%.2f' },
		];

	$r->{'@DASHBOARD'} = [
			{ 
			'name'=>'Sales by schedule', 
			'@HEAD'=>[ 
				{ type=>'CHR', name=>'Schedule', src=>8 },
				{ type=>'CNT', name=>'Order Count', src=>0 },
				{ type=>'SUM', name=>'Item Count', src=>1 },
				{ type=>'SUM', name=>'Subtotal', src=>3, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Order Total', src=>2, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Sales Tax', src=>4 },
				{ type=>'SUM', name=>'Shipping and Handling', src=>5, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Cost Total', src=>6, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Subtotal Minus Cost', src=>7, sprintf=>'$%.2f' },
				],
			'groupby'=>8, 			
			},
			{ 
			'name'=>'Retail vs Wholesale', 
			'@HEAD'=>[ 
				{ type=>'CHR', name=>'Has Schedule', src=>9 },
				{ type=>'CNT', name=>'Order Count', src=>0 },
				{ type=>'SUM', name=>'Item Count', src=>1 },
				{ type=>'SUM', name=>'Subtotal', src=>3, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Order Total', src=>2, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Sales Tax', src=>4, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Shipping and Handling', src=>5, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Cost Total', src=>6, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Price Minus Cost', src=>7, sprintf=>'$%.2f' },
				],
			'groupby'=>9, 			
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

	my $KEY = '**REPORT_KEY_NOT_SET**';
	if ($metaref->{'.key'}) { $metaref->{"key"} = $metaref->{'.key'}; }	# old jobs
	if ($metaref->{'key'} eq 'CREATED') { $KEY = 'CREATED_GMT'; }
	if ($metaref->{'key'} eq 'PAID') { $KEY = 'PAID_GMT'; }
	if ($metaref->{'key'} eq 'SHIP') { $KEY = 'SHIPPED_GMT'; }

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

	my $batch = pop @{$self->{'@JOBS'}};
	foreach my $orderid (@orders) {
		# print STDERR "USERNAME=[$USERNAME] [$orderid]\n";
		my ($O2) = CART2->new_from_oid($USERNAME,$orderid);

		next if (not defined $O2);

		my $total_cost = 0;
		foreach my $item (@{$O2->stuff2()->items()}) {
 			$total_cost += ($item->{'cost'} * $item->{'qty'});
 			}

		# calculate profits
		my $profit = ($O2->in_get('sum/items_total') - $total_cost);

		# calculate ahipping and handling
		my $shp_hnd = ($O2->in_get('sum/shp_total') + $O2->in_get('sum/hnd_total'));

		# merchant wants to be able to view retail vs wholesale as well as sales by schedule
		my $schedule = $O2->in_get('our/schedule');
		my $has_schedule = '';
		if ($schedule eq '') {
			$has_schedule = 'No';
			}
		else {
			$has_schedule = 'Yes';
			}

		my @ROW = (	$orderid,
						$O2->in_get('sum/items_count'), 
						sprintf("%.2f",$O2->in_get('sum/order_total')),
						sprintf("%.2f",$O2->in_get('sum/items_total')),
						sprintf("%.2f",$O2->in_get('sum/tax_total')),
						sprintf("%.2f",$shp_hnd),
						sprintf("%.2f",$total_cost),
						sprintf("%.2f",$profit),
						$schedule,
						$has_schedule,
						);
		push @{$r->{'@BODY'}}, \@ROW;

		$reccount++;
		if (substr($orderid,-2) eq '00') {
			$r->progress($reccount,$rectotal,"processed order: $orderid");
			}
		}
	

	$r->progress($rectotal,$rectotal,"included $reccount/$rectotal orders");
   &DBINFO::db_user_close();
	}




1;

