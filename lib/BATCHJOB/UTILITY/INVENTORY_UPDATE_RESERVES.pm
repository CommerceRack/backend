package BATCHJOB::UTILITY::INVENTORY_UPDATE_RESERVES;

use strict;
use Data::Dumper;
use lib "/backend/lib";
require INVENTORY2;
require EBAY2;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	my $USERNAME = $bj->username();
	print "USERNAME: $USERNAME\n";



#	$bj->progress(0,0,"Getting list of inventory records.");
#
#	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
#
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#
#	my $reserves = &INVENTORY::list_other(undef,$USERNAME,undef);
#	foreach my $r (@{$reserves}) {
#		my $EBAY_ID = 0;
#		if (($r->{'APPKEY'} eq 'EBAY.STORE') 
#			|| ($r->{'APPKEY'} eq 'EBAY.FIXED') 
#			|| ($r->{'APPKEY'} eq 'EBAY.AUCTN') 
#			|| ($r->{'APPKEY'} eq 'EBAYSTFEED')) {
#			$EBAY_ID = $r->{'LISTINGID'};
#			}
#		else {
#			print "UNKNOWN INVENTORY_OTHER $r->{'ID'} $r->{'APPKEY'}\n";
#		#	print 'FOUND OTHER: '.Dumper($r);
#			}
#
#		my $EXPIRE = 0;
#		if ($EBAY_ID>0) {
#			my $pstmt = "select count(*),IS_ENDED,ENDS_GMT from EBAY_LISTINGS where MID=$MID /* $USERNAME */ and EBAY_ID=".int($EBAY_ID);
#			my ($exists,$is_ended) = $udbh->selectrow_array($pstmt);
#			if (not $exists) { $EXPIRE++; }
#			elsif ($is_ended) { $EXPIRE++; }
#			}
#
#		if ($EXPIRE) {
#		#	print STDERR "EXPIRE: $EXPIRE\n";
#			&INVENTORY::set_other($USERNAME,$r->{'APPKEY'},$r->{'SKU'},$r->{'QTY'},'expirets'=>time(),'uuid'=>$r->{'LISTINGID'},'delete'=>1);
#			}
#
#		}
#
#	my ($onhandref,$reserveref) = &INVENTORY::load_records($USERNAME,undef);
#	my @PIDS = keys %{$onhandref};
#	my $reccount = 0;
#	my $rectotal = scalar(@PIDS);
#
#	foreach my $prod (@PIDS) {
#	
#		&INVENTORY2->new($self->username())->pidinvcmd($prod,'UPDATE-RESERVE');
#		## &INVENTORY::update_reserve($USERNAME,$prod);
#		if ((++$reccount % 100)==1) {
#			$bj->progress($reccount,$rectotal,"Updating Reserves");
#			}
#	   }
#	&DBINFO::db_user_close();

	$bj->progress(0,0,"Utility offline.");

	return(undef);
	}

1;
