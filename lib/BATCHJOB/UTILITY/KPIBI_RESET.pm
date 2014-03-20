package BATCHJOB::UTILITY::KPIBI_RESET;

use strict;
use lib "/backend/lib";
use KPIBI;
use ORDER::BATCH;
use CART2;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	my $USERNAME = $bj->username();
	my $MID = $bj->mid();
	my $PRT = $bj->prt();

	$bj->progress(0,0,"Deleting all current KPI data");
	my ($KPIBI) = KPIBI->new($USERNAME,undef);
	my $TB = $KPIBI->tb();
	my $pstmt = "delete from $TB where MID=$MID /* RESET */";
	my ($udbh) = $KPIBI->udbh();
	$udbh->do($pstmt);

	my ($startyyyymmdd) = KPIBI::relative_to_current("year.last");
	my ($startdt) = KPIBI::yyyymmdd_to_dt($startyyyymmdd);
	my ($startts) = KPIBI::dt_to_ts($startdt);
	
   my ($rs) = ORDER::BATCH::report($USERNAME,'CREATEDTILL_GMT'=>time(),'CREATED_GMT'=>$startts);
	my $reccount = 0;
	my $rectotal = scalar(@{$rs});
   foreach my $set (@{$rs}) {
      my $OID = $set->{'ORDERID'};
      my ($O2) = CART2->new_from_oid($USERNAME,$OID);
      next if (not defined $O2);
      $KPIBI->set_prt($O2->prt());

      my ($data) = $O2->order_kpistats();
      $KPIBI->stats_store($data);

		if ((++$reccount % 100)==1) {
			$bj->progress($reccount,$rectotal,"Processed order $OID");
			}
      }
	$bj->progress($rectotal,$rectotal,"Finished re-indexing KPI data");

	return(undef);
	}

1;
