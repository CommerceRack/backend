#!/usr/bin/perl

use lib "/httpd/modules";
use ZWEBSITE;
use DOMAIN;
use DOMAIN::TOOLS;

#$USERNAME |= $ARGV[0];
print "USERNAME:$USERNAME\n";
if (not defined $USERNAME) { die(); }

## get a list of partitions
foreach my $PRT ( @{&ZWEBSITE::list_partitions($USERNAME,'output'=>'prtonly')}) {
	print "PRT: $PRT\n";

	my ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	my $BLAST = $webdbref->{'%BLAST'};
	if ($BLAST->{'EMAIL'}) {
		$BLAST->{'HELPEMAIL'} = $BLAST->{'EMAIL'};
		delete $BLAST->{'EMAIL'};
		&ZWEBSITE::save_website_dbref($USERNAME,$webdbref,$PRT);
		}

	}


