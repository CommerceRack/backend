package BATCHJOB::UTILITY::AMAZON_UPDATE;

use strict;
use Data::Dumper;
use lib "/backend/lib";
require INVENTORY2;
require AMAZON3;
require ZTOOLKIT;
require TXLOG;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }


##
## this has it's own custom "finish" function that provides a link back to the product.
##
sub finish {
	my ($self, $bj) = @_;

	my $meta = $bj->meta();
	
	my $msg = qq~Amazon Job done.<br>~;
	if ($meta->{'.product'} ne '') {
	$bj->finish('SUCCESS',$msg);	

	return();
	}

##
##
##
sub work {
	my ($self, $bj) = @_;


	my $USERNAME = $bj->username();
	my $LUSERNAME = $bj->lusername();
	my $MID = $bj->mid();
	my $PRT = $bj->prt();
	my $meta = $bj->meta();

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my $FUNCTION = $meta->{'.function'};

	my ($userref) = &AMAZON3::fetch_userprt($USERNAME);
	my ($TB) = &ZOOVY::resolve_lookup_tb($USERNAME,$MID);

	my @SKUS = ();
	my $VERB = '';
	if ($FUNCTION eq 'clear-errors') {
		$VERB = '=this.create_please';
		my $pstmt = "select SKU from $TB where MID=$MID /* $USERNAME */ and AMZ_FEEDS_ERROR>0";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();	
		while ( my ($SKU) = $sth->fetchrow() ) {
			push @SKUS, $SKU;
			}
		$sth->finish();	
		}
	elsif ($FUNCTION eq 'reset-waiting') {
		$VERB = '=this.create_please';
		my $pstmt = "select SKU from $TB where MID=$MID /* $USERNAME */ and AMZ_FEEDS_WAIT>0";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();	
		while ( my ($SKU) = $sth->fetchrow() ) {
			push @SKUS, $SKU;
			}
		$sth->finish();	
		}

	if (scalar(@SKUS)==0) {
		$bj->progress(0,0,"No records found");
		}
	else {
		my $BATCHESREF = &ZTOOLKIT::batchify(\@SKUS,100);
		my $max = scalar(@{$BATCHESREF});
		my $i = 0;
		$bj->progress($i,$max,sprintf("performing $VERB on %d products (%d batches)",scalar(@SKUS),$max));
		my $txline = &TXLOG::addline(0,'products','_'=>'INFO','+'=>sprintf('%s by batch %d',$VERB,$bj->id()));
		foreach my $batch (@{&ZTOOLKIT::batchify(\@SKUS,100)}) {
			$bj->progress($i,$max,sprintf("performed $VERB on batch %d",$i++));
			&AMAZON3::item_set_status($userref,$batch,[$VERB],'USE_PIDS'=>0,'+ERROR'=>$txline);
			}		
		$bj->progress($max,$max,"Finished $max batches");
		}

	&DBINFO::db_user_close();

	return(undef);
	}

1;
