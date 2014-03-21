#!/usr/bin/perl

use lib "/httpd/modules";
use ZWEBSITE;
use DOMAIN;
use DOMAIN::TOOLS;

$USERNAME |= $ARGV[0];
print "USERNAME:$USERNAME\n";
if (not defined $USERNAME) { die(); }

## get a list of partitions
foreach my $PRT ( @{&ZWEBSITE::list_partitions($USERNAME,'output'=>'prtonly')}) {
	print "PRT: $PRT\n";

	my ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select MSGFROM from SITE_EMAILS where MID=$MID and MSGID='ORDER.CONFIRM'";
	my ($FROM) = $udbh->selectrow_array($pstmt);

	if ($FROM eq '') {
		my $pstmt = "select MSGFROM from SITE_EMAILS where MID=$MID and MSGID='OCREATE'";
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


