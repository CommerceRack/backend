package BATCHJOB::UTILITY::PRODUCT_RELATED_ITEMS;

##
## created for custom project but totally generic
##
## - go thru all categories
## - create hash of product to related items by using product list in category
## - remove keyed product from list
##	- product may be in multiple categories, append to list
##	- list may only have a max of 15 products 
##	-- (this could be made a param if other merchants need a different limit)
## 
##	- add batch job 
## - add nightly running of cronjob to app7
##
## author: patti 2011-09-12
## ticket: bamtar, 426402
## batchjob to run modules: 221450 ==>  /backend/lib/batch.pl 221450
##
##


use strict;
use lib "/backend/lib";
use ZOOVY;
use NAVCAT;

use Data::Dumper;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	## standard preamble for batchjob/utilities.
	my $USERNAME = $bj->username();
	my $MID = $bj->mid();
	my $PRT = $bj->prt();

	my (%products) = ();

	$bj->progress(0,0,"Getting list of products");
	my $NC = NAVCAT->new($USERNAME,PRT=>$PRT);


	my $cat_ctr = 0;

	## Step 1. Loop thru Navcats
	foreach my $safe ($NC->paths()) {
		
		my ($pretty,$children,$products) = $NC->get($safe);
		my @PIDS = split (/,/, $products);

		## Step 2. Go thru each PID
		foreach my $pid (@PIDS) {
			next if $pid eq '';
			
			my (%related_items) = ();

			## get prev related items added to this product
			my @prev_items = split(/,/,$products{$pid});
			my @prev_and_new = (@prev_items,@PIDS);

			my $ctr = 0;
			## create related items list
			foreach my $item (@prev_and_new) {
				if ($item ne $pid) {	## skip the PID we're working on
					$related_items{$item}++;
					if ($related_items{$item} == 1) { $ctr++; }
					}
				else {
					## skip it
					}
				## only 15 items needed in list
				last if $ctr == 15;
				}
			## product may be multiple cats, so we want to combine lists
			my (@items) = keys %related_items;
			if (scalar(@items) > 0) {
				$products{$pid} = join(",",@items);		
				}
 			}
		}

	## get product attribs
	my @allPIDS = keys %products;
	my $Prodsref = &PRODUCT::group_into_hashref($USERNAME,\@allPIDS);

	## see if list is different from current and save
	foreach my $P (values %{$Prodsref}) {
		my $PID = $P->pid();
		my $new_list = $products{$PID};
		if ($new_list ne $P->fetch('zoovy:prod_list1')) {
			$P->store('zoovy:prod_list1',$new_list);
			$P->save();
			}
		}
	}

1;