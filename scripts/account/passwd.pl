#!/usr/bin/perl

use strict;
use lib "/backend/lib";
use DBINFO;
use Getopt::Long;

my $create = 0;
my $USERNAME = '';
my $LUSER = '';
my $PASS = '';

GetOptions(
	"user=s" => \$USERNAME, # numeric
	"luser=s" => \$LUSER, # string
	"pass=s" => \$PASS, # string
	"create" => \$create) # flag
or die("Error in command line arguments\n");


if (not $USERNAME || not $LUSER || not $PASS) {
	die("./passwd.pl --user username --luser luser --pass password [--create]\n");
	}

my ($udbh) = &DBINFO::db_user_connect($USERNAME);
my $pstmt = "select UID,PASSHASH,PASSSALT,count(*) from LUSERS where LUSER=".$udbh->quote($LUSER)."\n";
my ($UID,$HASH,$SALT,$COUNT) = $udbh->selectrow_array($pstmt);

if ($COUNT == 0) {
	die("LUSER: $LUSER does not exist\n");
	}

my $qtSALT = $udbh->quote(&ZTOOLKIT::make_password());
my $qtPASS = $udbh->quote($PASS);

$pstmt = "update LUSERS set PASSSALT=$qtSALT,PASSWORD=$qtPASS,PASSHASH=sha1(concat($qtPASS,$qtSALT)) where UID=$UID";
print STDERR "$pstmt\n";
$udbh->do($pstmt);

print "$HASH:$SALT\n";

&DBINFO::db_user_close();