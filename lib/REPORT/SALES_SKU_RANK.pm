package REPORT::SALES_SKU_RANK;



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
	$meta->{'title'} = "Product Sales Rank: ".'Period '.&ZTOOLKIT::pretty_date($meta->{'.start_gmt'},1).' to '.&ZTOOLKIT::pretty_date($meta->{'.end_gmt'},1);

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
		{ id=>0, 'name'=>'SKU', type=>'CHR', link=>'https://www.zoovy.com/biz/product/edit.cgi?PID=', target=>'_blank' },
		{ id=>1, 'name'=>'Product Name', type=>'CHR' },
		{ id=>2, 'name'=>'Units Sold', type=>'NUM', },
		{ id=>3, 'name'=>'Dollars Sold', type=>'NUM', sprintf=>'%.2f' },
		{ id=>4, 'name'=>'Order Count', type=>'NUM', },
#		{ id=>3, 'name'=>'Avg. Sale Price', type=>'NUM', },
#		{ id=>4, 'name'=>'High Sale Price', type=>'NUM', },
#		{ id=>5, 'name'=>'Low Sale price', type=>'NUM', },
		];

	$r->{'@SUMMARY'} = [
		{ 'name'=>'Reporting Period', type=>'TITLE' },
		{ 'name'=>'Begins', type=>'LOAD', meta=>'.start_gmt', transform=>'EPOCH-TO-DATETIME', },
		{ 'name'=>'End', type=>'LOAD', meta=>'.end_gmt', transform=>'EPOCH-TO-DATETIME', },

		{ 'name'=>'Totals', type=>'TITLE' },
		{ 'name'=>'Items Sold', type=>'SUM', src=>2 },
		{ 'name'=>'Dollars Sold', type=>'SUM', src=>3,  sprintf=>'$%.2f' },

		{ 'name'=>'Averages', type=>'TITLE' },
		{ 'name'=>'Average Sale Price', type=>'AVG', src=>3, sprintf=>'$%.2f' },
		];

	$r->{'@DASHBOARD'} = [
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
	print STDERR Dumper($metaref)."\n";

	my $KEY = '**REPORT_KEY_NOT_SET**';
	if ($metaref->{'.key'}) { $metaref->{"key"} = $metaref->{'.key'}; }
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

	my %SKU_TO_ROW_MAP = ();	# contains a map of SKU to row #

	my $batch = pop @{$self->{'@JOBS'}};
	foreach my $orderid (@orders) {
		# print STDERR "USERNAME=[$USERNAME] [$orderid]\n";
		my ($O2) = CART2->new_from_oid($USERNAME,$orderid);

		next if (not defined $O2);

		foreach my $item (@{$O2->stuff2()->items()}) {
			my $SKU = $item->{'sku'};
			if ($SKU eq '') { $SKU = $item->{'product'}; }

			if (defined $SKU_TO_ROW_MAP{$SKU}) {
				## row already exists
				my $ROW = $SKU_TO_ROW_MAP{$SKU};
				$r->{'@BODY'}->[ $ROW ]->[2] += $item->{'qty'};
				$r->{'@BODY'}->[ $ROW ]->[3] += $item->{'extended'};
				$r->{'@BODY'}->[ $ROW ]->[4]++;
				}
			else {
				## doesn't exist
				my @ROW = ( $SKU, $item->{'description'}, $item->{'qty'}, $item->{'extended'}, 1 );
				$SKU_TO_ROW_MAP{$SKU} = scalar(@{$r->{'@BODY'}});	# record row #
				push @{$r->{'@BODY'}}, \@ROW;
				}

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

