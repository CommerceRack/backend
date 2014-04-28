#!/usr/bin/perl

use lib "/httpd/modules";
use ZWEBSITE;
use DOMAIN;
use DOMAIN::TOOLS;

#$USERNAME |= $ARGV[0];
print "USERNAME:$USERNAME\n";
if (not defined $USERNAME) { die(); }

my $path = &ZOOVY::resolve_userpath($USERNAME);

## get a list of partitions
if (-f "$path/webdb.bin") {
    unlink("$path/webdb.bin");
     }
foreach my $PRT ( @{&ZWEBSITE::list_partitions($USERNAME,'output'=>'prtonly')}) {
	print "PRT: $PRT\n";

	if (-f "$path/webdb-$PRT.bin") {
	    unlink("$path/webdb-$PRT.bin");
      }
	}


