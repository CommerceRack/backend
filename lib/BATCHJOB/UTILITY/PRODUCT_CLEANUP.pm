package BATCHJOB::UTILITY::PRODUCT_CLEANUP;

use strict;
use lib "/backend/lib";
require PRODUCT;
require NAVCAT;
require INVENTORY2;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	my $USERNAME = $bj->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my $MID = $bj->mid();
	my $PRT = $bj->prt();

	## remove product cache file to get a clean build.
	my $path = &ZOOVY::resolve_userpath($USERNAME);
	unlink("$path/cache-products-byname.bin");

	$bj->progress(0,0,"Getting list of products.");	
	my (@PIDS) = &ZOOVY::fetchproduct_list_by_merchant($USERNAME);

	my %EXISTS = ();		## a hashref of products which exist.
	foreach my $pid (@PIDS) { $EXISTS{$pid}++; }

	my %INVENTORY = ();
	my $REMOVE_FROM_WEBSITE_IF_OUT_OF_STOCK = 0;
	my $NAVCATS_CHANGED = 0;

	my $gref = &ZWEBSITE::fetch_globalref($USERNAME);
	$REMOVE_FROM_WEBSITE_IF_OUT_OF_STOCK++;
	#if (($gref->{'inv_rexceed_action'} & 1)	|| ($gref->{'inv_outofstock_action'} & 1)) {
	#	$REMOVE_FROM_WEBSITE_IF_OUT_OF_STOCK++;
	#	}

	my $NAVCATS_CHANGED = 0;
	my @NAVCATS = ();
	my $prtlist = &ZWEBSITE::list_partitions($USERNAME,has_navcats=>1,output=>'prtonly');
	if (scalar(@{$prtlist})>0) {
		foreach my $PRT (@{$prtlist}) {
			my $nc = NAVCAT->new($USERNAME,PRT=>$prtlist);
			push @NAVCATS, $nc;
			}
		}

	if ($REMOVE_FROM_WEBSITE_IF_OUT_OF_STOCK) {
		foreach my $productarref (@{&ZTOOLKIT::batchify(\@PIDS,100)}) {
			my ($instock) = INVENTORY2->new($USERNAME)->fetch_qty('@PIDS'=>$productarref);
			foreach my $stid (keys %{$instock}) {
				my ($PID) = &PRODUCT::stid_to_pid($stid);
				if ($instock->{$stid}>0) {
					$INVENTORY{$PID} += $instock->{$stid};
					}
				else {
					$INVENTORY{$PID} += 0;
					}
				}
			}
		}
	## SANITY: at this point $REMOVE_FROM_WEBSITE_IF_OUT_OF_STOCK is set
	##			and if it is true, then %INVENTORY has total quantity for any sku

	my @RECORDS = ();
	my $reccount = 0;
	my $rectotal = scalar(@PIDS);

	foreach my $productarref (@{&ZTOOLKIT::batchify(\@PIDS,100)}) {
		my $pidsref = &PRODUCT::group_into_hashref($USERNAME,$productarref);
		foreach my $PID (sort keys %{$pidsref}) {

#			next if ($PID ne 'CHANELSOLEIL4FACET');
#			print "PID: $PID\n";

			my $changes = 0;
			my $delete = 0;
			# my $prodref = $pidsref->{$PID};

			my ($P) = $pidsref->{$PID};
			my $prodref = $P->prodref();

			# go through the vars
			foreach my $k ('zoovy:prod_desc', 'zoovy:prod_detail') {
				my $new = ZTOOLKIT::stripUnicode($prodref->{$k});
				## only mark as changed if strip took place
				if ($new ne $prodref->{$k}) {
					$prodref->{$k} = $new;
					$changes++;
					}
				}

			## cleanup prod_related
			# $changes += &BATCHJOB::UTILITY::PRODUCT::CLEANUP::reset_prod_finder($prodref,'zoovy:prod_related',\%EXISTS);
			$changes += &BATCHJOB::UTILITY::PRODUCT_CLEANUP::reset_prod_finder($PID,$prodref,'zoovy:related_products',\%EXISTS);
			# $changes += &BATCHJOB::UTILITY::PRODUCT::CLEANUP::reset_prod_finder($prodref,'zoovy:prod_accessories',\%EXISTS);
			$changes += &BATCHJOB::UTILITY::PRODUCT_CLEANUP::reset_prod_finder($PID,$prodref,'zoovy:accessory_products',\%EXISTS);
#			print "CHANGES: $changes\n";

			if (($prodref->{'zoovy:base_price'} eq '') && 
				($prodref->{'zoovy:prod_name'} eq '') && 
				($prodref->{'zoovy:prod_desc'} eq '')) {
				## blank product, can safely be deleted.
				$delete++;
				delete $EXISTS{$PID};
				}

			if ($delete) {
				&ZOOVY::deleteproduct($USERNAME,$PID);
				}		
			elsif ($changes) {
				# &ZOOVY::saveproduct_from_hashref($USERNAME,$PID,$prodref);
				$P->save();
				}

			if ($INVENTORY{$PID}) {
				print "KEEPING: $PID\n";
				}
			elsif (not $REMOVE_FROM_WEBSITE_IF_OUT_OF_STOCK) {
				## leave it alone.
				}
			elsif (($REMOVE_FROM_WEBSITE_IF_OUT_OF_STOCK) && ($INVENTORY{$PID}<=0)) {
				foreach my $nc (@NAVCATS) {
					print "NUKING: $PID\n";
					$nc->nuke_product($PID,memory=>1);
					$NAVCATS_CHANGED++;
					}
				}
				

			if ((++$reccount % 100)==1) {
				$bj->progress($reccount,$rectotal,"Parsing product $PID");
				}
		   }
		}
	$bj->progress($rectotal,$rectotal,"Finished product cleanup");

	if ($NAVCATS_CHANGED) {
		foreach my $nc (@NAVCATS) {
			$nc->save();
			}
		}

	&DBINFO::db_user_close();
	return(undef);
	}


## deletes products that do not exist
##	does not give a shit about inventory.
sub reset_prod_finder {
	my ($THISPID,$prodref,$attrib,$EXISTSREF) = @_;
	my $changes = 0;
	my $str = '';
	foreach my $CSVPID (split(/,/,$prodref->{$attrib})) {
		next if (not $EXISTSREF->{$CSVPID});
		next if (uc($CSVPID) eq uc($THISPID));
		$str .= "$CSVPID,";
		}
	chomp($str);

	if ( $prodref->{$attrib} ne $str ) {
		$prodref->{$attrib} = $str;
		$changes++;
		}
	return($changes);
	}

1;
