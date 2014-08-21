#!/usr/bin/perl

## 
## NOTE:
##		the mapping of which category, goes to which syndication is in SYNDICATION.pm look for the webdoc=> key
##

use strict;
use lib "/httpd/modules";
require SYNDICATION::CATEGORIES;
require ZOOVY;
require GTOOLS;
use Data::Dumper;

my $MKT = $ARGV[0];
if ($MKT eq '') { 
	print "Please specify a MKT parameter e.g. SHO\n";
	}

my ($CDS) = &SYNDICATION::CATEGORIES::CDSLoad($MKT);
my ($flatref) = SYNDICATION::CATEGORIES::CDSFlatten($CDS);

my $c = '';
foreach my $ref (@{$flatref}) {
	$c .= "$ref->[0]\t$ref->[1]\n";
	}

print $c;

exit;
