package REPORT::SALE_SUMMARY;

use strict;
use lib "/backend/lib";
use PRODUCT;
use ZOOVY;

require DBINFO;
require CART2;
use Data::Dumper;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub r { return($_[0]->{'*PARENT'}); }


##
## REPORT: SALE_SUMMARY
##	PARAMS: 
##		period
##			start_gmt
##			end_gmt
##

sub init {
	my ($self) = @_;

	my $r = $self->r();

	my $begins = 0;
	my $ends = 0;

	my $meta = $self->r()->meta();

   $begins = $meta->{'start_gmt'};
	$ends = $meta->{'end_gmt'};
	if ($begins > $ends) { my $tmp = $begins; $begins = $ends; $ends = $tmp; }	# swap backwards values!

	$meta->{'title'} = 'Sale Summary Report';
	$meta->{'subtitle'} = 'Period '.&ZTOOLKIT::pretty_date($begins,1).' to '.&ZTOOLKIT::pretty_date($ends,1);
	

	$r->{'@HEAD'} = [
		{ id=>0, 'name'=>'SKU', type=>'CHR', link=>'/product/index.cgi?VERB=QUICKSEARCH&VALUE=', target=>'_blank' },
		{ id=>1, 'name'=>'Payment Method', type=>'CHR', },		
		{ id=>2, 'name'=>'SKU Name', type=>'CHR', },
		{ id=>3, 'name'=>'SKU Cost', type=>'NUM', },
		{ id=>4, 'name'=>'SKU Price', type=>'NUM', },
		{ id=>5, 'name'=>'Quantity Sold', type=>'NUM', },
		{ id=>6, 'name'=>'Total Cost', type=>'NUM', },
		{ id=>7, 'name'=>'Total', type=>'NUM', },
		{ id=>8, 'name'=>'Meta', type=>'CHR', },		
		{ id=>9, 'name'=>'UPC', type=>'CHR', },
		];

	$r->{'@SUMMARY'} = [
		{ 'name'=>'Totals', type=>'TITLE' },
		{ 'name'=>'Grand Total Sum', type=>'SUM', src=>7, sprintf=>'$%.2f' },
		{ 'name'=>'Grand Total Cost', type=>'SUM', src=>6, sprintf=>'$%.2f' },
		{ 'name'=>'Items Sold', type=>'SUM', src=>5 },

		{ 'name'=>'Averages', type=>'TITLE' },
		{ 'name'=>'Average Sales Per Item', type=>'AVG', src=>7, sprintf=>'$%.2f' },
		];

	$r->{'@DASHBOARD'} = [
			{ 
			'name'=>'Sales by Product (w/o Payment Method)', 
			'@HEAD'=>[ 
				{ type=>'CHR', name=>'SKU', link=>'/biz/product/index.cgi?VERB=QUICKSEARCH&VALUE=', target=>'_blank', src=>0 },
				{ type=>'CHR', name=>'SKU Name', src=>2, },
				{ type=>'NUM', name=>'SKU Cost', src=>3, sprintf=>'$%.2f' },
				{ type=>'NUM', name=>'SKU Price', src=>4, sprintf=>'$%.2f'},
				{ type=>'SUM', name=>'Quantity Sold', src=>5, },
				{ type=>'SUM', name=>'Total Cost', src=>6, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Total', src=>7, sprintf=>'$%.2f'},
				],
			'groupby'=>0, 			
			},

		];

	$r->{'@BODY'} = [];

	return(0);
	}



###################################################################################
##
## added $self->{'PIDSMAP'}, so mapping we be shared across batches
sub work {
	my ($self) = @_;

	my $r = $self->r();
	my $meta = $r->meta();

	my $begins = int($meta->{'.start_gmt'}); 
	my $ends = int($meta->{'.end_gmt'});

	my $USERNAME = $r->username();
	my $MID = $r->mid();

	$r->progress(0,0,"Downloading order summary from database");

	my $odbh =&DBINFO::db_user_connect($USERNAME);
   my $ORDERTB = &DBINFO::resolve_orders_tb($USERNAME,$MID);
	my @orders = ();
   my $pstmt = "select ORDERID,POOL from $ORDERTB where MID=$MID /* $USERNAME */ and CREATED_GMT>=$begins and CREATED_GMT<$ends";
   print STDERR $pstmt."\n";
   my $sth = $odbh->prepare($pstmt);
   $sth->execute();
   while ( my ($orderid,$status) = $sth->fetchrow() ) {
      next if (($meta->{'.include_deleted'}==0) && ($status eq 'DELETED'));
      next if (($meta->{'.include_deleted'}==0) && ($status eq 'CANCELLED'));
      push @orders, $orderid;
      }

	## now lookup the row, to see if it already exists.			
	my %pidsmap = ();
	if (defined $self->{'PIDSMAP'}) { %pidsmap = %{$self->{'PIDSMAP'}}; }
	## NOTE: pidsmap is a hash keyed by product where value is the pos in @BODY

	my %pids = ();
	my $rectotal = scalar(@orders);
	my $reccount = 0;
	foreach my $orderid (@orders) {
		# print STDERR "USERNAME=[$self->{'USERNAME'}] [$orderid]\n";
		my ($O2) = CART2->new_from_oid($USERNAME,$orderid);
		next if (not defined $O2);
		
		my $pt = $O2->payment_method();
		$pt =~ s/ //g;

		my $meta = $O2->in_get('cart/refer');
		if ($meta =~ /\@CAMPAIGN:(.*):(.*)/) {
			$meta = "\@CAMPAIGN:".$1;
			}

		foreach my $item (@{$O2->stuff2()->items()}) {
			my $price = $item->{'price'};
			my $pid = uc($item->{'sku'});
			if ($pid eq '') { $pid = uc($item->{'stid'}); }
			my $upc = $item->{'%attribs'}->{'zoovy:prod_upc'};
			
			## added 09/07/2006
			## take out channel from PID
			## CHANNEL*PID => PID
			if ($pid =~ /(.*)\*(.*)/) {
				my $channel = $1;	
				$pid = $2;
				}

			my $value = $pid.":".$pt.":".$meta;
			if (not defined $pidsmap{$value}) {
				## SKU, PAYMENT METHOD, NAME,  COST, PRICE, QTY, TOTAL COST, TOTAL
				my @ROW = ($pid, $pt, $item->{'description'}, 0, 0, 0, 0, 0, $meta, $upc);
				push @{$r->{'@BODY'}}, \@ROW;
				
				$pidsmap{$value} = scalar(@{$r->{'@BODY'}})-1;
				}
			
			my $element = '';
			$element = $pidsmap{$value};
			$r->{'@BODY'}->[$element]->[3] = sprintf("%.2f",$item->{'cost'});
			# $r->{'@BODY'}->[$element]->[4] = sprintf("%.2f",$item->{'price'});
			
			$r->{'@BODY'}->[$element]->[5] += $item->{'qty'};

			$r->{'@BODY'}->[$element]->[6] += ($item->{'qty'} * $item->{'cost'});
			$r->{'@BODY'}->[$element]->[6] = sprintf("%.2f",$r->{'@BODY'}->[$element]->[6]);

			$r->{'@BODY'}->[$element]->[7] += ($item->{'qty'} * $item->{'price'});
			$r->{'@BODY'}->[$element]->[7] = sprintf("%.2f",$r->{'@BODY'}->[$element]->[7]);			


			if ($item->{'qty'} > 0) {
				$r->{'@BODY'}->[$element]->[4] = sprintf("%.2f",$r->{'@BODY'}->[$element]->[7] / $r->{'@BODY'}->[$element]->[5]);
				}
			}

		$reccount++;
		if (substr($orderid,-2) eq '00') {
			$r->progress($reccount,$rectotal,"processed order: $orderid");
			}
		}

	$self->{'PIDSMAP'} = \%pidsmap;	
	$r->progress($rectotal,$rectotal,"included $reccount/$rectotal orders");
   &DBINFO::db_user_close();
	}




1;

