#!/usr/bin/perl


## cat_convert.pl
##
##
## (keep in mind that this should have been done differently)
## to add more categories...
## - decrement @AVAIL to (7000..7800) ## this is used for parent cats
## - increment ctr to 5834 ## this is used for children
## - add new categories to the bottom of pg_cats (without an id)
## - rename new_pg_cats.txt to pg_cats.txt
## - push info.bin to production

use lib "/httpd/modules";
use Data::Dumper;
use ZTOOLKIT;

use SYNDICATION::CATEGORIES;

my $CDS = {};

my (@AVAIL) = (6000..7850);

my %NAME2CATID = ();  # contains "path|to|category"=>catid
my %TREE = ();		# parent=>[catid1,catid2,catid3]
my %INFO = ();

## some categories don't have an associated number
## making up a number for Eletronics, Consumer Electronics
## and Sporting Goods
open NEW, ">new_pg_cats.txt";
open F, "<pg_cats.txt";
my $ctr = 5560;
while (<F>) {
	$line = $_;
	$line =~ s/[\n\r]+//gs;

   my ($txt,$catid) = split(/\|/,$line);
	if ($catid eq '') { 
		$catid = $ctr++;
		print "Using ctr: $catid\n";
		}
	
	my (@nodes) = split(/[\s]+\>[\s]+/,$txt);

	print "[$catid][$txt]\n";
	print NEW "$txt|$catid\n"; 

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
			$x = pop @AVAIL; 
			print "Using AVAIL: $x\n";
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

		}

	}
close F;
close NEW;

SYNDICATION::CATEGORIES::CDSSave('PGR',$CDS);

#print Dumper($CDS);

exit;