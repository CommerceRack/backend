#!/usr/bin/perl

use Storable;
use JSON::XS;

use lib "/httpd/modules";
use Data::Dumper;

if (not defined $USERNAME) { 
  print "No USERNAME\n";
  die(); 
  }

my $USERPATH = &ZOOVY::resolve_userpath($USERNAME);
my ($udbh) = &DBINFO::db_user_connect($USERNAME);

my $MID = &ZOOVY::resolve_mid($USERNAME);
$pstmt = "delete from WHOLESALE_SCHEDULES where CODE like '%.%'";
$udbh->do($pstmt);

print "USER:$USERPATH\n";
opendir my $D, "$USERPATH/WHOLESALE";
while (my $file = readdir($D)) {
  next if (substr($file,0,1) eq '.');
  print "FILE:$file\n";
  my $CODE = undef;
  if ($file =~ /^(.*?)\.schedule\.bin$/) {
     ($CODE) = $1;
    }
     
  if ($CODE) {
     my $ref = Storable::retrieve("$USERPATH/WHOLESALE/$file");
     my ($pstmt) = &DBINFO::insert($udbh,'WHOLESALE_SCHEDULES',{
         MID=>$MID,
         CODE=>"$CODE",
         JSON=>JSON::XS::encode_json( $ref )
         },verb=>'insert','sql'=>1);
    print STDERR "$pstmt\n";
    $udbh->do($pstmt);
     }
  }
closedir $D;

&DBINFO::db_user_close();