#!/usr/bin/perl

use strict;

#open (FILE, "sporting_goods.txt");
#open (FILE, "home.txt");
#open (FILE, "apparel.txt");
#open (FILE, "jewelry.txt");
#open (FILE, "babies.txt");
#open (FILE, "flowers.txt");
#open (FILE, "health_beauty.txt");
#open (FILE, "sporting_goods.txt");
open (FILE, "toys.txt");






my @lines = ();
my $content = '';

while (<FILE>) {
#	print $_;
#	exit;

	my $line = $_;
	$line =~ s/\n$/ /;
	$content .= $line;
	}

@lines = split(/\|/, $content);

my $last_cat = '';
foreach my $line (@lines) {
	$line =~ m/(.*)(\(.*\))(.*)(\(.*\))/;
	my $cat = $1;
	my $cat_id = $2;
	my $sub = $3;
	my $sub_id = $4;
	
	$cat =~ s/ $//;
	
	$cat_id =~ s/\(//;
	$cat_id =~ s/\)//;

	$sub =~ s/^ //;
	$sub =~ s/ $//;
	
	$sub_id =~ s/\(//;
	$sub_id =~ s/\)//;

	if ($cat ne $last_cat) {
		print "\"$cat\", $cat_id,\n";
		}

	print "\"$cat $sub\", ".$sub_id.",\n";
	$last_cat = $cat;
	}

exit;	
