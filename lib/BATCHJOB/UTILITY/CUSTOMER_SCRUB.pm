package BATCHJOB::UTILITY::CUSTOMER_SCRUB;

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
	
	my $rectotal = 0;

	
	

	$bj->progress($rectotal,$rectotal,"Finished list scrub");
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
