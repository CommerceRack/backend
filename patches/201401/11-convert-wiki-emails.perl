#!/usr/bin/perl

use lib "/httpd/modules";
use ZWEBSITE;
use DOMAIN;
use DOMAIN::TOOLS;
use Text::WikiCreole;

$USERNAME |= $ARGV[0];
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


## get a list of partitions
foreach my $PRT ( @{&ZWEBSITE::list_partitions($USERNAME,'output'=>'prtonly')}) {
	print "PRT: $PRT\n";

	my ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select MSGFROM from SITE_EMAILS where MID=$MID and MSGID='ORDER.CONFIRM' and PRT=$PRT";
	my ($FROM) = $udbh->selectrow_array($pstmt);

	if ($FROM eq '') {
		my $pstmt = "select MSGFROM from SITE_EMAILS where MID=$MID and MSGID='OCREATE' and PRT=$PRT";
		($FROM) = $udbh->selectrow_array($pstmt);
		}

	if ($FROM eq '') {
		my $DOMAIN = &DOMAIN::TOOLS::domain_for_prt($USERNAME,$PRT);
		print "DOMAIN:$DOMAIN\n";
      my $D = DOMAIN->new($USERNAME,$DOMAIN);
      if (defined $D) { $FROM = $D->get('our/support_email'); }
      }

	print "FROM: $FROM\n";

	if ($FROM ne '') {
		$webdbref->{'from_email'} = $FROM;
		&ZWEBSITE::save_website_dbref($USERNAME,$webdbref,$PRT);
		}

	&DBINFO::db_user_close();
	}


