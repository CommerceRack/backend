package DOMAIN::POOL;

use strict;
use lib "/backend/lib";
require ZOOVY;
require DBINFO;
require DOMAIN;


##
## 
##
sub reserve {
	my ($USERNAME,$PRT,%options) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	#my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	#my $pstmt = "select ID from DOMAINS_POOL where MID=0 order by ID limit 0,1";
	#my ($ID) = $udbh->selectrow_array($pstmt);

	#my ($DOMAIN) = undef;
	#if ($ID>0) {
	#	$pstmt = "update DOMAINS_POOL set MID=$MID /* $USERNAME */ where ID=$ID and MID=0";
	#	$udbh->do($pstmt);
	#
	#	$pstmt = "select DOMAIN from DOMAINS_POOL where MID=$MID and ID=$ID";
	#	($DOMAIN) = $udbh->selectrow_array($pstmt);
	#	}
	#my $PROFILE = sprintf("%s",$options{'PROFILE'});
	#if (($DOMAIN ne '') && ($PROFILE eq '')) {
	#	## if profile is blank, they want to auto-generate, so we use the hostname as the profile (since it's pretty random, it's probably safe/collision free)
	#	$PROFILE = substr($DOMAIN,0,index($DOMAIN,'.'));
	#	$PROFILE = uc($PROFILE);
	#	$PROFILE =~ s/[^\w]+//gs;
	#	$PROFILE = substr($PROFILE,0,8);	# reduce to 8 characters
	#	}

	my $ID = 0;
	my $DOMAIN = '';
	my @POOLS = ();
	

	if ($DOMAIN ne '') {
		$options{'REG_TYPE'} = 'VSTORE';
		$options{'REG_STATE'} = 'ACTIVE';
		$options{'PRT'} = $PRT;
		
		my ($D) = DOMAIN->create($USERNAME,$DOMAIN,%options);
		}

	&DBINFO::db_user_close();

	if (($ID>0) && ($DOMAIN eq '')) {
		return(&DOMAIN::POOL::reserve($USERNAME));
		}

	return($DOMAIN);
	}

1;