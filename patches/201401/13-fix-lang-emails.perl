#!/usr/bin/perl

use lib "/httpd/modules";
use ZWEBSITE;
use DOMAIN;
use DOMAIN::TOOLS;

#$USERNAME |= $ARGV[0];
print "USERNAME:$USERNAME\n";
if (not defined $USERNAME) { die(); }

## get a list of partitions
my ($udbh) = &DBINFO::db_user_connect($USERNAME);

my $pstmt = "alter table SITE_EMAILS drop key MIDX";
print "$pstmt\n";
$udbh->do($pstmt);

my $pstmt = "select MSGID,PRT from SITE_EMAILS where LANG='EN'";
my $sth = $udbh->prepare($pstmt);
$sth->execute();
while ( my ($MSGID,$PRT) = $sth->fetchrow() ) {
	my $qtMSGID = $udbh->quote($MSGID);
	my $PRT = int($PRT);
	my $pstmt = "delete from SITE_EMAILS where MSGID=$qtMSGID and PRT=$PRT and LANG='ENG'";
	print "$pstmt\n";
	$udbh->do($pstmt);
	
	##
	}
$sth->finish();

my $pstmt = "update SITE_EMAILS set LANG='ENG' where LANG='EN'";
print "$pstmt\n";
$udbh->do($pstmt);

&DBINFO::db_user_close();