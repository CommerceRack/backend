#!/usr/bin/perl

use strict;
use lib "/httpd/modules/";
use Data::Dumper;

open (FILE, "pg_cats.txt");


my @cats = ();

while (<FILE>) {
	my $cat = $_;
	push @cats, $cat;
	}

close FILE;

open (OUT, "> pg_cats_sort2.out");
foreach my $full (sort @cats) {

	my($cat,$num) = split(/\|/,$full);
	print OUT $cat."\n";
	}

close OUT;
exit;
