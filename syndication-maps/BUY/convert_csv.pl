#!/usr/bin/perl

##
## convert_csv.pl
## convert csv file into Category and category identifier
##
## name csv files after category (ie store identifiers)
##

use strict;
use lib "/httpd/modules/";
use Data::Dumper;


## usage: ./convert_csv.pl ComputerHardware.csv
if (!$ARGV[0]) { 
	print "usage: ./convert_csv.pl Computer_Hardware.csv\n";
	exit;
	}


my $file = $ARGV[0];
my $store_identifier = $file;
$store_identifier =~ s/\.csv//;
$store_identifier =~ s/_/ /g;

## open file
open(CSV, $file) or die "can't open $file";
my %cats = ();
my $ctr = 0;
## parse file
while(<CSV>) {
	my $line = $_;
	$line =~ s/\r\n//;

	my $cat = '';
	my $catid = '';

	## parse line
	my ($catid1,$cat1,$catid2,$cat2,$catid3,$cat3,$catid4,$cat4,$catid5,$cat5,$catid6,$cat6) = split(/\t/,$line);

	if (int($catid1) > 0) { $cats{$catid1} = "$store_identifier > $cat1"; }
	if (int($catid2) > 0) { $cats{$catid2} = "$store_identifier > $cat1 > $cat2"; }
	if (int($catid3) > 0) { $cats{$catid3} = "$store_identifier > $cat1 > $cat2 > $cat3"; }
	if (int($catid4) > 0) { $cats{$catid4} = "$store_identifier > $cat1 > $cat2 > $cat3 > $cat4"; }
	if (int($catid5) > 0) { $cats{$catid5} = "$store_identifier > $cat1 > $cat2 > $cat3 > $cat4 > $cat5"; }
	if (int($catid6) > 0) { $cats{$catid6} = "$store_identifier > $cat1 > $cat2 > $cat3 > $cat4 > $cat5 > $cat6"; }

	}

close(CSV);

my $new_file = "all_cats.csv";

open(NEW,">>$new_file") or die "can't open $new_file";
foreach my $key (sort keys %cats) {
	print NEW $key. "\t".$cats{$key}."\n";
	}
close(NEW);

exit;
