package BATCHJOB::UTILITY::PRODUCT_BESTSELLERS;


## utility to create product best seller list
## 	to be put in a category's products list
##
## originally built - patti - 2011-10-21
##	ticket designed2bsweet 471993
##
##	meta
##		days = grab orders from the last $days
##		best_seller_cnt = the number of products that should be in the product list
##


use strict;
use lib "/backend/lib";
use Data::Dumper;
require ORDER::BATCH;
require LISTING::MSGS;
require NAVCAT;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	my $USERNAME = $bj->username();
	my $MID = $bj->mid();
	my $PRT = $bj->prt();
	my $meta = $bj->meta();
	my $DEFAULT_DAYS = 30;
	my $DEFAULT_MAX_BEST_SELLERS = 64;
	
	print "bj:\n";
	print Dumper($bj);
	print "\n";
	print "Meta:\n";
	print Dumper($meta);
	die;

	## by default, find the best sellers from the last 30days
	my $days = $meta->{'.days'};
	if ($days eq '') {
		$days = $DEFAULT_DAYS;
		}
	
	## max_best_sellers, max of amount of products to be put in navcat list
	my $max_best_sellers = $meta->{'.max_best_sellers'};
	if ($max_best_sellers eq '') {
		$max_best_sellers = $DEFAULT_MAX_BEST_SELLERS;
		}
	

	$bj->progress(0,0,"Starting Bestseller Update","REGRETFULLY THIS UTILITY IS NOT INTERACTIVE AND WILL NOT UPDATE STATUS UNTIL IT IS FINISHED.");
	my $lm = LISTING::MSGS->new($USERNAME,logfile=>"~/bestsellers-%YYYYMM%.log");
	$lm->pooshmsg("INFO|+Finding new bestsellers");

	## get orders from the last $days days
	my ($tsref) = &ORDER::BATCH::report($USERNAME,PAID_GMT=>time()-($days*86400));


	my %pids = ();
	my $order_cnt = 0;	## only for merchant info
	## go thru orders, populate %pids with product and qty from order
	foreach my $order (@{$tsref}) {
		#my $o = ORDER->new($USERNAME,$order->{'ORDERID'});
		my $CART2 = CART2->new_from_oid($USERNAME,$order->{'ORDERID'});

		foreach my $item (@{$CART2->stuff2()->items()}) {
			$pids{$item->{'product'}} += $item->{'qty'};
			}
		$order_cnt++;
		}
	$lm->pooshmsg("INFO|+Found $order_cnt from the last $days days");


	## get products with the highest qty first in list
	my @best = reverse sort { $pids{$a} <=> $pids{$b} } keys %pids;

	
	my $prodnew = '';		## new navcat products list
	my $ctr = 1;
	## go thru the top 64 best sellers
	foreach my $pid (@best) {
		$lm->pooshmsg("INFO|+".$ctr++.". ".$pid." : ".$pids{$pid});
		$prodnew .= $pid.",";
		last if $ctr > $max_best_sellers;
		}


	## remove trailing comma
	chop($prodnew);
	$lm->pooshmsg("INFO|+New product list: $prodnew");

	my $NC = NAVCAT->new($USERNAME,PRT=>0);
	my $safe = ".promotional.best_sellers";
	$NC->set($safe,products=>$prodnew);


	$bj->progress(0,0,"Finished Bestseller Update",'');

	return(undef);
	}

1;
