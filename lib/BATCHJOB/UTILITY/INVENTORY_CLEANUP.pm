package BATCHJOB::UTILITY::INVENTORY_CLEANUP;

use strict;

##
## 
##

use lib "/backend/lib";
use ZOOVY;
require PRODUCT;
use DBINFO;
use LISTING::MSGS;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	my $USERNAME = $bj->username();
	print "USERNAME: $USERNAME\n";
#
#	$bj->progress(0,0,"Getting list of inventory records.");
#	$bj->progress(0,0,"Not available");

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my $pstmt = '';
	my $LM = $bj->lm();

	$pstmt = "select count(*) from INVENTORY_DETAIL where BASETYPE='MARKET' and ISNULL(MARKET_DST)=1";
	my ($count) = $udbh->selectrow_array($pstmt);
	if ($count>0) {
		$bj->progress(0,0,"Removing $count listings where BASETYPE='MARKET' and MARKET_DST=NULL");
		$pstmt = "delete from INVENTORY_DETAIL where BASETYPE='MARKET' and ISNULL(MARKET_DST)=1;";
		$udbh->do($pstmt);
		}

	$pstmt = "select count(*) from INVENTORY_DETAIL where BASETYPE='SIMPLE' and UUID!=SKU";
	print "$pstmt\n";
	($count) = $udbh->selectrow_array($pstmt);

	if ($count>0) {
		$LM->pooshmsg("WARN|+fixing $count listings where BASETYPE='SIMPLE' and UUID's are wrong");
		my $pstmt = "update ignore INVENTORY_DETAIL set UUID=SKU where BASETYPE='SIMPLE' and UUID!=SKU";
		$udbh->do($pstmt);

		$pstmt = "select count(*) from INVENTORY_DETAIL where UUID!=SKU and BASETYPE='SIMPLE'";
		print $pstmt."\n";
		($count) = $udbh->selectrow_array($pstmt);

		if ($count>0) {
			## SH*T DUPLICATE RECORDS
			$LM->pooshmsg("WARN|+Found duplication of $count records in BASETYPE='SIMPLE'");

			$pstmt = "select ID,SKU,NOTE,QTY from INVENTORY_DETAIL where BASETYPE='SIMPLE' and UUID!=SKU";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my ($ID,$SKU,$NOTE,$QTY) = $sth->fetchrow() ) {
				$QTY = int($QTY);
				my $qtSKU = $udbh->quote($SKU);
				my $qtNOTE = $udbh->quote($NOTE);
				$pstmt = "update INVENTORY_DETAIL set NOTE=concat(NOTE,$qtNOTE),QTY=QTY+$QTY where BASETYPE='SIMPLE' and SKU=$qtSKU and UUID=$qtSKU";
				$udbh->do($pstmt);
				print $pstmt.";\n";
				$pstmt = "delete from INVENTORY_DETAIL where ID=$ID and BASETYPE='SIMPLE' and SKU=$qtSKU and UUID!=$qtSKU";
				$udbh->do($pstmt);
				print $pstmt.";\n";
				}
			$sth->finish();
			

			#$pstmt = "delete from INVENTORY_DETAIL where BASETYPE='SIMPLE' and UUID!='SKU'";
			#$udbh->do($pstmt);
			}
		}



	&DBINFO::db_user_close();
#
#	my $udbh = &DBINFO::db_user_connect($USERNAME);
#
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#	my $INVTB = &INVENTORY::resolve_tb($USERNAME,$MID,'INVENTORY');
#
#	my %SKU_DONE = ();
#	my @SQL = ();
#	####
#	#### CHANGED to select SKU vs PRODUCT - patti - 12/4/2006
#	####
#	my $lm = LISTING::MSGS->new($USERNAME);
#	$lm->set_batchjob($bj);
#
#	my $pstmt = "select ID,SKU,IN_STOCK_QTY from $INVTB where /* $USERNAME */ MID=".$udbh->quote($MID);
#	print $pstmt."\n";
#
#	my $sth = $udbh->prepare($pstmt);
#	$sth->execute();
#	my $ctr = 0;
#	# my %POGS_HINT = ();
#
#	my %CACHE_PRODS = ();
#	my %DID_SKUS = ();
#
#
#	while ( my ($id,$SKU,$qty) = $sth->fetchrow() ) {
#
#		my $RESULT = undef;
#		if ($SKU =~ /[^A-Z0-9\:\-\_\#]/) {
#			$RESULT = "WARN|+sku '$SKU' has invalid characters";
#			}
#
#		my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($SKU);
#		my $P = $CACHE_PRODS{$pid};
#			
#		if (defined $RESULT) {
#			}
#		elsif (not defined $P) {
#			$P = PRODUCT->new($USERNAME,$pid,'create'=>0); 
#			if (not defined $P) {
#				$RESULT = "WARN|+PRODUCT '$pid' does not exist";
#				}
#			elsif ($P->has_variations('inv')) { 
#				$CACHE_PRODS{$pid} = $P; 
#				}
#			}
#
#		if (defined $RESULT) {
#			}
#		elsif (not defined $P) {
#			$RESULT = "WARN|+sku '$SKU' invalid product record";
#			}
#		elsif ($SKU =~ /\:/) {
#			## has options!
#
#			if (not $P->has_variations('inv')) {
#				$RESULT = "WARN|+sku '$SKU' (but product has no inv pogs)";
#				}
#			else {
#				my $found = 0;
#				foreach my $set (@{$P->list_skus('verify'=>1)}) {
#					if ($set->[0] eq $SKU) { $found++; }
#					last if ($found);
#					}
#				if (not $found) {
#					$RESULT = "WARN|+sku '$SKU' is not valid (options do not match product configuration)";
#					}
#				else {
#					$RESULT = ''; # Success
#					}
#				}
#			}
#		elsif ($SKU !~ /\:/) {
#			## never do the same product twice.
#
#			if ($P->has_variations('inv')>0) {
#				## contains inv_options (should never have a base pid record)
#				$RESULT = "WARN|+sku '$SKU' is not valid (because product has inventoriable options)";
#				}
#			else {
#				$RESULT = ''; 	# success!
#				}
#      	}
#		else {
#			warn "never reached!\n";
#			}
#
#	   if ((defined $RESULT) && ($RESULT ne '')) {
#			$lm->pooshmsg($RESULT);
#			push @SQL, "delete from $INVTB where ID=$id limit 1 /* $SKU_DONE{$SKU} */";
#	      }
#	   }
#
#	foreach $pstmt (@SQL) {
#	   print $pstmt."\n";
#		$udbh->do($pstmt);
#   	}
#
#	&DBINFO::db_user_close();
#	%CACHE_PRODS = ();
#
#	my $rectotal = 1;
#	$bj->progress($rectotal,$rectotal,"Finished Cleaning Orphans");
#
#	########################################################################
#
#	$bj->progress(0,0,"Phase2: Initialize missing inventory records (no longer applicable)");

	########################################################################

	return(undef);
	}

1;
