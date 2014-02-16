package SYNDICATION::BATCH;

use strict;
use lib "/backend/lib";
require SYNDICATION;



##
## Returns a hash of syndication objects keyed by unique dst code
##
#sub syndications_by_profile {
#	my ($USERNAME,$PROFILE) = @_;
# 
#	my $udbh = &DBINFO::db_user_connect($USERNAME);
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#	my %INFO = ();
#	my $qtPROFILE = $udbh->quote($PROFILE);
#	my $pstmt = "select DSTCODE,DOMAIN,ID from SYNDICATION where MID=$MID and PROFILE=$qtPROFILE";
#	my $sth = $udbh->prepare($pstmt);
#	$sth->execute();
#	while ( my ($DST,$DOMAIN,$ID) = $sth->fetchrow() ) {
#		$INFO{$DST} = SYNDICATION->new($USERNAME,$DST,'DOMAIN'=>$DOMAIN,'ID'=>$ID);
#		}
#	$sth->finish();
#	&DBINFO::db_user_close();
#
#	return(\%INFO);
#	}
#



1;