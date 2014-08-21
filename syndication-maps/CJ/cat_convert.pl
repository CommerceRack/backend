#!/usr/bin/perl


use lib "/httpd/modules";
use Data::Dumper;
use ZTOOLKIT;

use SYNDICATION::CATEGORIES;

my $CDS = {};

my %NAME2CATID = ();  # contains "path|to|category"=>catid
my %TREE = ();		# parent=>[catid1,catid2,catid3]
my %INFO = ();

## some categories don't have an associated number
## making up a number for Eletronics, Consumer Electronics
## and Sporting Goods
$ctr = 100;
open F, "<cj.txt";
while (<F>) {
	$line = $_;
	$line =~ s/[\n\r]+//gs;

   my ($txt,$catid) = split(/\|/,$line);
	if ($catid eq '') { $catid = $ctr++; }

	my (@nodes) = split(/[\s]+\>[\s]+/,$txt);

	print "[$catid][$txt]\n";

	my $count = 0;
#	my ($cid,$parent) = 0;
	my @new = ();
	my $PARENT = 0;
	my $isLeaf = 0;
	foreach my $n (@nodes) {
		push @new, $n;

		$catstr = join ('>',@new);
		print "CAT: $catstr\n";
		

		$count++;
		if (defined $NAME2CATID{$catstr}) { 
			#print "X\n";
			$x = $NAME2CATID{$catstr}; 
			}		
		elsif ((scalar(@nodes)==$count)) { 
			#print "Y\n";
			$x = $catid; 	$isLeaf++;
			} 
		else { 
			#print "Z\n";
			$x = pop @AVAIL; 
			}

		if (not defined $x) { print "$catstr\n"; die(); }

		$NAME2CATID{$catstr} = $x; 

		## SANITY: AT THIS POINT $NAME2CATID contains a reverse lookup of "cat1|cat2|cat3"=>catid
		##				ANY NON-LEAF CATEGORIES HAVE HAD NUMBERS MADE UP.

		$INFO{$x} = {
			Parent=>$x, Name=>$n, isLeaf=>$isLeaf, 'Path'=>$catstr
			};
		
		if (not defined $TREE{$PARENT}) { $TREE{$PARENT} = []; }
		if (not &ZTOOLKIT::isin($TREE{$PARENT},$x)) {
			## only add it to the tree if it doesn't already exist.
			push @{$TREE{$PARENT}}, $x;
			}
		$PARENT = $x;

		$CDS->{'_TREE'} = \%TREE;
		$CDS->{'_INFO'} = \%INFO;		

#		SYNDICATION::CATEGORIES::Add($CDS,$parent,$cid,$nodes);
#		SYNDICATION::CATEGORIES::Store($CDS);
		}

	}
close F;

SYNDICATION::CATEGORIES::CDSSave('CJ',$CDS);

#print Dumper(\%INFO);