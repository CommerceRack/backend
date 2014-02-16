package REPORT::_STUB;

use strict;

use lib "/backend/lib";
require DBINFO;
require ZOOVY;

##
## these methods should be included in the header of every report::module
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
	my $USERNAME = $r->username();
	my $MID = $r->mid();
	
	if ($meta->{'.userparamter'}) {
		}

	$meta->{'title'} = '** YOUR REPORT TITLE **';
	$meta->{'subtitle'} = '** SOMETHING SET BY PARAMTERS **';
	if ($params{'.include_deleted'}) { 
		$meta->{'subtitle'} .= 'GROSS Sales: Includes Cancelled Invoices'; 
		}
	else {
		$meta->{'notes'} = "Deleted orders are not included.\n";
		}

	$r->{'@HEAD'} = [
		{ id=>0, 'name'=>'Order Id', type=>'CHR', link=>'/biz/orders/view.cgi?ID=', target=>'_blank' },
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
		{ id=>18, 'name'=>'Pool', type=>'CHR' },
		];

	$r->{'@SUMMARY'} = [
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
				{ type=>'SUM', name=>'Order Total', src=>8, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Sales Tax', src=>9, sprintf=>'$%.2f' },
				{ type=>'SUM', name=>'Shipping', src=>10, sprintf=>'$%.2f' },
				],
			'groupby'=>16, 			
			},
			{ 
			'name'=>'Sales by Meta/Affiliate', 
			'@HEAD'=>[ 
				{ type=>'CHR', name=>'Meta', src=>17 },
				{ type=>'SUM', name=>'Item Count', src=>7 },
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
## this module is what does the actual work, all t
##
sub work {
	my ($self) = @_;

	my $r = $self->r();
	my $meta = $r->meta();
	my $USERNAME = $r->username();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	$r->progress(0,0,"Starting .. ");

	my $udbh =&DBINFO::db_user_connect($USERNAME);

	my @records = ();

	my $reccount = 1;
	my $rectotal = scalar(@records);
	$r->progress($reccount,$rectotal,"Loading records");

	my $jobs = &ZTOOLKIT::batchify(\@records,100);

	foreach my $records (@{$jobs}) {
		foreach my $record (@{$records}) {
			my @ROW = ();

			push @{$r->{'@BODY'}}, @ROW;
			$reccount++;
			#if (($reccount % 100)==0) {
			#	$r->progress($reccount,$rectotal,"processed record: $reccount");
			#	}
			}
		$r->progress($reccount,$rectotal,"processed record: $reccount");
		}
	

	$r->progress($rectotal,$rectotal,"did $reccount/$rectotal records");
   &DBINFO::db_user_close();
	}




1;

