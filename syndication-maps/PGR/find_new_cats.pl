#!/usr/bin/perl

use strict;
use lib "/httpd/modules/";
use Data::Dumper;

open (CURRENT, "pg_cats_sort2.out");


my %current_cats = ();
my %new_cats = ();


while (<CURRENT>) {
	my $cat = $_;
	chop($cat);
	$current_cats{$cat}++;
	}

close CURRENT;


open (NEW, "pg_cats_new.txt");
while (<NEW>) {
	my $cat = $_;
	chop($cat);
	

	if (not defined $current_cats{$cat}) {
		my $new_cat = $cat;
		$new_cat =~ s/and/\&/g;
		$new_cat =~ s/Clothing/Apparel/g;

		if (not defined $current_cats{$new_cat}) {

	 		print $cat." ".$current_cats{$cat}."\n";	
			$new_cats{$cat}++;
			}
		}
	}
close NEW;

open (OUT, "> need_cats.out");
foreach my $cat (sort keys %new_cats) {	
	print OUT $cat."\n";
	}

close OUT;
exit;
