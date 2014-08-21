package SYNDICATION::CATEGORIES;

use lib "/backend/lib";
use Storable;
use strict;

$SYNDICATION::CATEGORIES::PATH = "/backend/syndication-maps/"; 


##
## Category Data Structure ($CDS) is a hashref:
##		
##		first key is "_TREE" - contains a list of parent->[c1,c2,c2]
##		second key is "_INFO" - is a hashref of id->{ Name=>'', Parent=>'', isLeaf=> }
##	
##	we should avoid accessing this data structure directly in the application -
##		instead write primitives that parse the data for us, based on receiving 
##		$CDS as a parameter .. (that way we can add/remove functionality as necessary)
##
##


##
## MKT == SYNDICATION MARKETPLACE CODE (e.g. JLY for JELLYFISH)
##



##
## returns categories as a hash keyed by category id, full path breadcrumb as value
##
sub CDSasHASH {
	my ($MKT,$DELIM) = @_;

	$MKT = uc($MKT);
	my $FILE = "$SYNDICATION::CATEGORIES::PATH/$MKT/list.bin";

	my $ar = Storable::retrieve $FILE;
	my %hash = ();

	foreach my $r (@{$ar}) {
		if (defined $DELIM) { $r->[1] =~ s/\//$DELIM/g; }
		$hash{$r->[0]} = $r->[1];
		}
	return(\%hash);
	}


##
## Stores a CDS (see comments above)
##
sub CDSSave {
	my ($MKT, $CDS) = @_;

	$MKT = uc($MKT);
	my $FILE = "$SYNDICATION::CATEGORIES::PATH/$MKT/info.bin";

	unlink $FILE;
	Storable::nstore $CDS, $FILE;
	chmod 0666, $FILE;
	return($FILE);
	}


## you can access info.bin or list.bin in this dir:
sub CDSPath { my ($MKT) = @_; return(sprintf("$SYNDICATION::CATEGORIES::PATH/%s",uc($MKT))); }

##
## loads a CDS (see comments above)
##
sub CDSLoad {
	my ($MKT) = @_;

	$MKT = uc($MKT);
	my ($CDS) = Storable::retrieve "$SYNDICATION::CATEGORIES::PATH/$MKT/info.bin";
	$CDS->{'_MKT'} = $MKT;
	return($CDS);
	}


##
## builds a CDS Tree from an array ref
## 	[
##			[ catid, level1, level2, level3 ],
##			[ catid, level1, level2, level3 ]
##		]
##
## note: params changed on 12/31/10 added $DST to front
sub CDSBuildTree {
	my ($DST,$ref) = @_;

	my $CDS = {};
	my %NAME2CATID = ();  # contains "path|to|category"=>catid
	my %TREE = ();		# parent=>[catid1,catid2,catid3]
	my %INFO = ();

	my %USED_CATIDS = ();

	foreach my $rowref (@{$ref}) {
	   my ($catid,@nodes) = @{$rowref};
		$USED_CATIDS{$catid}++;
		if ($DST eq 'WSH') {
			}
		elsif ($DST eq 'GOO') {
			}
		elsif ($catid == 0) { 
			die "category id of zero not supported\n";
			}
		}

	foreach my $rowref (@{$ref}) {
	   my ($catid,@nodes) = @{$rowref};
	
		my $count = 0;
	#	my ($cid,$parent) = 0;
		my @new = ();
		my $PARENT = 0;
		my $isLeaf = 0;
		foreach my $n (@nodes) {
			push @new, $n;

			my $catstr = join ('>',@new);
			print "CAT[$catid] $catstr\n";
		
			$count++;
			my $x = undef;
			if (defined $NAME2CATID{$catstr}) { 
				#print "X\n";
				$x = $NAME2CATID{$catstr}; 
				}		
			elsif ((scalar(@nodes)==$count)) { 
				#print "Y\n";
				$x = $catid; 	$isLeaf++;
				} 
			else { 
				# $x = pop @AVAIL;
				my $avail = 100;
				while (defined $USED_CATIDS{++$avail}) {};
				$x = $avail;
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
			}

		$CDS->{'_TREE'} = \%TREE;
		$CDS->{'_INFO'} = \%INFO;		
		}

	return($CDS);
	}


##
## returns a ref
##		isLeaf
##		Name
##		Parent
##		Path  (HTML output ready)
##
sub CDSInfo {
	my ($CDS,$catid) = @_;

#	if ($catid==-2) {
#		return( {'Name'=>'-- Block --',Path=>'-- Block Products --',Parent=>0} );
#		}
	if ($CDS->{'_MKT'} eq 'WSH') {
		if ($catid>0) {
			return( {'Name'=>'Send Products',Path=>'-- Send Products --',Parent=>0} );
			}
		else {
			return( {'Name'=>'Suppress',Path=>'-- Suppress --',Parent=>0} );
			}
		}
	else {
		if ($catid==-1) {
			return( {'Name'=>'-- Block --',Path=>'-- Block --',Parent=>0} );
			}
		if ($catid==0) {
			return( {'Name'=>'Ignore',Path=>'-- Ignore --',Parent=>0} );
			}
		}

	if (not defined $CDS->{'_INFO'}->{$catid}) {
		$CDS->{'_INFO'}->{$catid} = { Name=>"Invalid Category: $catid", Parent=>-1, Path=>"** Invalid Category: $catid **" };
		}
	else {
		$CDS->{'_INFO'}->{$catid}->{'Path'} =~ s/\>/ &gt; /gs;
		}

	if ($CDS->{'_MKT'} eq 'BUY') {
		## prepare info for buy.com - to show in Products->Buy.com syndication
		## need to show store-name, category-name and NEVER show Invalid Category (because our tree is old)
        	my $storecode;
		($storecode,$catid) = ($1,$2) if $catid =~ /(\d+)\.(\d+)/;

		my %storenames = (
			1000=>'Computers',
			2000=>'Software',
			3000=>'Books',
			4000=>'DVD/Movies',
			5000=>'Games',
			6000=>'Music',
			7000=>'Electronics',
			14000=>'Bags',
			16000=>'Toys'
		);

		my $storename = $storenames{$storecode} ? $storenames{$storecode} : 'Unknown/Not Selected';
		$CDS->{'_INFO'}{"$catid"}{Path} = '' if $CDS->{'_INFO'}{"$catid"}{Path} =~ /^\*\* Invalid Category/;
		$CDS->{'_INFO'}{"$catid"}{Path} = "Buy.com store-code: $storecode - $storename<br>Category: $catid - ".$CDS->{'_INFO'}{"$catid"}{Path};
		}

	return($CDS->{'_INFO'}->{$catid});
	}




##
## returns a ref
##		key : Path  (HTML output ready)
##		value : ID
##
## used for legacy navcat.bin files that have the path (vs the id) stored
##
sub CDSByPath {
	my ($CDS) = @_;

	my %paths = ();
	foreach my $id (keys %{$CDS->{'_INFO'}}) {
		$paths{$CDS->{'_INFO'}->{$id}->{'Path'}} = $id;
		}
	return(\%paths);
	}

##
## CDSFlatten when passed a CDS this returns an array of:
##		[
##			[catid1, "path>to>leaf>category"],
##			[catid2, "path>to>other>category"],
##		]
##
sub CDSFlatten {
	my ($CDS, $parent) = @_;

	if (not defined $parent) { $parent = 0; }
	my @result = ();	
	
	my $TREE = $CDS->{'_TREE'};
	my $INFO = $CDS->{'_INFO'};

	use Data::Dumper;

	foreach my $child (@{$TREE->{$parent}}) {
		#print STDERR "CHILD: $child\n";
		my $Iref = $INFO->{ $child };
		if ($Iref->{'isLeaf'}) {
			# use Data::Dumper; print Dumper($Iref);
			push @result, [ $child, $Iref->{'Path'}];
			}
		else {
			my $rs = CDSFlatten($CDS, $child);
			foreach my $rsx (@{$rs}) {
				push @result, $rsx;
				}
			}
		}

	return(\@result);	
	}



1;
