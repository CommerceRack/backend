#!/usr/bin/perl

use lib "/httpd/modules";
use DBINFO:

my $CLUSTER = 'crackle';
my ($udbh) = &DBINFO::db_user_connect($CLUSTER);

my $pstmt = "update SSL_IPADDRESSES set IP_ADDRESS=''";
$udbh->do($pstmt);

my $pstmt = "select DOMAIN,PROVISIONED_TS from SSL_IPADDRESSES where IP_ADDRESS=''";
$sth = $udbh->prepare($pstmt);
$sth->execute();
while ( my ($DOMAIN,$PROVISIONED) = $sth->fetchrow() ) {
	
	}
$sth->finish();

&DBINFO::db_user_close();

