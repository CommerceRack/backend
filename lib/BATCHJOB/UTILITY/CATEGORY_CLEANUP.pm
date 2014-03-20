package BATCHJOB::UTILITY::PRODUCT_CLEANUP;

use strict;
use lib "/backend/lib";

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	my $USERNAME = $bj->username();
	my $MID = $bj->mid();
	my $PRT = $bj->prt();

	## remove product cache file to get a clean build.
	my $path = &ZOOVY::resolve_userpath($USERNAME);
	unlink("$path/cache-products-byname.bin");

	$bj->progress(0,0,"Getting list of products.");	
	my (@PIDS) = &ZOOVY::fetchproduct_list_by_merchant($USERNAME);

	my %EXISTS = ();		## a hashref of products which exist.
	foreach my $pid (@PIDS) { $EXISTS{$pid}++; }

	my @RECORDS = ();
	my $reccount = 0;
	my $rectotal = scalar(@PIDS);

	foreach my $productarref (@{&ZTOOLKIT::batchify(\@PIDS,100)}) {
		my $Pidsref = &PRODUCT::group_into_hashref($USERNAME,$productarref);
		foreach my $P (values %{$Pidsref}) {
			my $PID = $P->pid();
			my $changes = 0;
			my $delete = 0;

			# go through the vars
			foreach my $k ('zoovy:prod_desc', 'zoovy:prod_detail') {
				my $new = ZTOOLKIT::stripUnicode($P->fetch($k));
				## only mark as changed if strip took place
				if ($new ne $P->fetch($k)) {
					$P->store($k,$new);
					$changes++;
					}
				}

			## cleanup prod_related
			# $changes += &BATCHJOB::UTILITY::PRODUCT::CLEANUP::reset_prod_finder($prodref,'zoovy:prod_related',\%EXISTS);
			$changes += &BATCHJOB::UTILITY::PRODUCT_CLEANUP::reset_prod_finder($P,'zoovy:related_products',\%EXISTS);
			# $changes += &BATCHJOB::UTILITY::PRODUCT::CLEANUP::reset_prod_finder($prodref,'zoovy:prod_accessories',\%EXISTS);
			$changes += &BATCHJOB::UTILITY::PRODUCT_CLEANUP::reset_prod_finder($P,'zoovy:accessory_products',\%EXISTS);

			if (($P->fetch('zoovy:base_price') eq '') && 
				($P->fetch('zoovy:prod_name') eq '') && 
				($P->fetch('zoovy:prod_desc') eq '')) {
				## blank product, can safely be deleted.
				$delete++;
				delete $EXISTS{$PID};
				}

			if ($delete) {
				&ZOOVY::deleteproduct($USERNAME,$PID);
				}		
			elsif ($changes) {
				$P->save();
				}


			if ((++$reccount % 100)==1) {
				$bj->progress($reccount,$rectotal,"Parsing product $PID");
				}
		   }
		}
	$bj->progress($rectotal,$rectotal,"Finished product cleanup");

	return(undef);
	}


sub reset_prod_finder {
	my ($P,$attrib,$EXISTSREF) = @_;
	my $changes = 0;
	my $str = '';
	foreach my $PID (split(/,/,$P->fetch($attrib))) {
		next if (not $EXISTSREF->{$PID});
		$str .= "$PID,";
		}
	chomp($str);

	if ( $P->fetch($attrib) ne $str ) {
		$P->store($attrib,$str);
		$changes++;
		}
	return($changes);
	}

1;
