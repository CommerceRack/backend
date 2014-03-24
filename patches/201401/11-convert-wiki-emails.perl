#!/usr/bin/perl

use lib "/httpd/modules";
use ZWEBSITE;
use DOMAIN;
use DOMAIN::TOOLS;
use Text::WikiCreole;

if ($USERNAME eq '') { $USERNAME |= $ARGV[0]; }
#print "USERNAME:$USERNAME\n";
if (not defined $USERNAME) { die(); }

my ($udbh) = &DBINFO::db_user_connect($USERNAME);
my $pstmt = "select MSGID,PRT,BODY,FORMAT from SITE_EMAILS";
my $sth = $udbh->prepare($pstmt);
$sth->execute();
while ( my ($MSGID,$PRT,$BODY,$FORMAT) = $sth->fetchrow() ) {
  print "MSGID:$MSGID\n";
  
  my $changed = 0;
  if ($BODY =~ /%HTMLCONTENTS%/) { $BODY =~ s/%HTMLCONTENTS%/%ORDERITEMS%/gs; $changed++; }
  if ($BODY =~ /%CONTENTS%/) { $BODY =~ s/%CONTENTS%/%ORDERITEMS%/gs; $changed++; }
  if ($BODY =~ /%WEBSITE%/) { $BODY =~ s/%WEBSITE%/%LINKWEBSITE%/gs; $changed++; }
  if ($BODY =~ /%SUPPORTEMAIL%/) { $BODY =~ s/%SUPPORTEMAIL%/%HELPEMAIL%/gs; $changed++; }
  if ($BODY =~ /%SUPPORTPHONE%/) { $BODY =~ s/%SUPPORTPHONE%/%LINKPHONE%/gs; $changed++; }
  if ($BODY =~ /%LINKWEBSITE%/) { $BODY =~ s/%LINKWEBSITE%/%LINKDOMAIN%/gs; $changed++; }
  if ($BODY =~ /\<a href=\"%LINKDOMAIN%.*?\"\>.*?\<\/a\>/) { $BODY =~ s/\<a href=\"%LINKDOMAIN%(.*?)\"\>(.*?)\<\/a\>/$2/gs; $changed++; }

  if (($FORMAT eq 'WIKI') || ($FORMAT eq 'NULL') || ($FORMAT eq '')) {
    $BODY = &Text::WikiCreole::creole_parse($BODY);
    $FORMAT = 'HTML';
    $changed++;
    };
    
  if ($changed) {
    my $pstmt = "update SITE_EMAILS set BODY=".$udbh->quote($BODY).',FORMAT='.$udbh->quote($FORMAT).' where MSGID='.$udbh->quote($MSGID).' and PRT='.$udbh->quote($PRT);
    print STDERR "$pstmt\n";
    $udbh->do($pstmt);
    }

  }
$sth->finish();
&DBINFO::db_user_close();

__DATA__

