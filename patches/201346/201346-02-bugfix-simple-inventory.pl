#!/usr/bin/perl

use strict;
use lib "/httpd/modules";
use CFG;
use DBINFO;

my ($CFG) = CFG->new();

my @LINES = ();
my ($SQL) = '';
while (<DATA>) { 
	$SQL .= $_; 
	if ($_ eq "\n") { chomp($SQL); if ($SQL ne '') { push @LINES, $SQL; } $SQL = ''; }
	}

foreach my $SQL (@LINES) { 
	print "$SQL";
	}

foreach my $USERNAME (@{$CFG->users()}) {
	print "USERNAME:$USERNAME\n";
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	foreach my $SQL (@LINES) {
		print "SQL:$SQL\n";
		if (not defined $udbh) {
			warn "ERROR: NO DB\n";
			}
		else {
			$udbh->do($SQL);
			}	
		}
	&DBINFO::db_user_close();
	}

__DATA__

update ignore INVENTORY_DETAIL set UUID=SKU where BASETYPE='SIMPLE';

delete from INVENTORY_DETAIL where BASETYPE='SIMPLE' and UUID!=SKU;

alter table INVENTORY_DETAIL change UUID UUID varchar(48) default '' not null;

update ignore INVENTORY_DETAIL set UUID=concat(SKU,'*',SUPPLIER_ID) where BASETYPE='SUPPLIER';

delete from INVENTORY_DETAIL where BASETYPE='SUPPLIER' and UUID!=concat(SKU,'*',SUPPLIER_ID);

