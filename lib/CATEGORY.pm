package CATEGORY;

require ZOOVY;
require DBINFO;
use strict;

sub products_by_category {
	my ($USERNAME,$CATEGORY) = @_;

	my @AR = ();
	my $pdbh 	 = &DBINFO::db_user_connect($USERNAME);

	my $TB = &ZOOVY::resolve_product_tb($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	my $pstmt = "select PRODUCT from $TB where MID=$MID and CATEGORY=".$pdbh->quote($CATEGORY);
	my $sth = $pdbh->prepare($pstmt);
	$sth->execute();
	while ( my ($product) = $sth->fetchrow() ) { 
		push @AR, $product;
		}
	&DBINFO::db_user_close();

	return(\@AR);
	}

##
##
##
sub listcategories {
	my ($USERNAME) = @_;

	my @AR = ();

	my $pdbh 	 = &DBINFO::db_user_connect($USERNAME);

	my $TB = &ZOOVY::resolve_product_tb($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	my $pstmt = "select CATEGORY from $TB where MID=$MID group by CATEGORY";
#	print STDERR $pstmt."\n";
	my $sth = $pdbh->prepare($pstmt);
	$sth->execute();
	while ( my ($category) = $sth->fetchrow() ) { 
		push @AR, $category;
		}
	&DBINFO::db_user_close();

	return(\@AR);
	}

#################################
##
## fetchcategories
## parameters: $username
## purpose: returns a hashref array containing categories
##          with fully qualified path names. 
##
## note: rewritten on Jun 7th, code stolen from fetchproducts_by_category
##
#############################################
sub fetchcategories
{
	my ($USERNAME) = @_;

	my %AR = ();

	my $pdbh 	 = &DBINFO::db_user_connect($USERNAME);

	my $TB = &ZOOVY::resolve_product_tb($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	my $pstmt = "select PRODUCT,CATEGORY from $TB where MID=$MID";
#	print STDERR $pstmt."\n";
	my $sth = $pdbh->prepare($pstmt);
	$sth->execute();
	while ( my ($product,$category) = $sth->fetchrow() ) { $AR{$category} .= $product.','; }

	&DBINFO::db_user_close();

	return(\%AR);
}


1;
