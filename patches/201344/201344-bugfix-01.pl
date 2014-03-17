#!/usr/bin/perl

use strict;
use lib "/httpd/modules";
use CFG;
use DBINFO;

my ($CFG) = CFG->new();


my ($SQL) = '';
while (<DATA>) { $SQL .= $_; }
print "SQL:$SQL\n";

foreach my $USERNAME (@{$CFG->users()}) {
	print "USERNAME:$USERNAME\n";
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	if (not defined $udbh) {
		warn "ERROR: NO DB\n";
		}
	else {
		$udbh->do($SQL);
		}
	&DBINFO::db_user_close();
	}

__DATA__

update SKU_LOOKUP set AMZ_FEEDS_TODO=AMZ_FEEDS_TODO|16;
