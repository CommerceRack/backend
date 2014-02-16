package EBAY2::STORE;

use lib "/backend/lib";
use ZTOOLKIT;


sub rebuild_categories {
	my ($USERNAME,$EIAS) = @_;

	my ($edbh) = &DBINFO::db_user_connect($USERNAME);

	use Storable;
	require XML::Parser;
	require XML::Parser::EasyTree;

	my $qtEIAS = $edbh->quote($EIAS);

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "delete from EBAYSTORE_CATEGORIES where MID=$MID /* $USERNAME */";
	if ($EIAS ne '') {
		$pstmt .= " and EIAS=".$qtEIAS;
		}

	print STDERR $pstmt."\n";
	$edbh->do($pstmt);

	my ($count) = 0;

	$pstmt = "select ID,EBAY_USERNAME,EBAY_EIAS from EBAY_TOKENS where MID=$MID /* $USERNAME */";
	if ($EIAS ne '') {
		$pstmt .= " and EBAY_EIAS=".$qtEIAS;
		}
	my $sth = $edbh->prepare($pstmt);
	$sth->execute();
	while ( my ($ID,$EBAYUSER,$EIAS) = $sth->fetchrow() ) {
		print STDERR "EBAYUSER: $EBAYUSER\n";
	   my %info = ();
		$info{'CategoryStructureOnly'} = 'true';
		$info{'LevelLimit'} = 3;
		my ($eb2) = EBAY2->new($USERNAME,'EIAS'=>$EIAS);
		my ($r) = $eb2->api('GetStore',\%info,xml=>3);

		open F, ">/tmp/categories.ebay";
		use Data::Dumper; print F Dumper($r);
		close F;

		##
		##
		##
	   my $catsref = $r->{'.'}->{'Store'}->[0]->{'CustomCategories'}->[0]->{'CustomCategory'};
		my @OUTPUT = ();
		&EBAY2::STORE::herdStoreCats('',$catsref,\@OUTPUT);
		#print Dumper(\@OUTPUT);

		foreach my $o (@OUTPUT) {
			my ($cat,$name) = @{$o};
			$name = &ZTOOLKIT::stripUnicode($name);
			$count++;
			# open F, ">>/tmp/ebay.cats"; print F "[$count] $cat|$name\n"; close F;
			my ($pstmt) = &DBINFO::insert($edbh,'EBAYSTORE_CATEGORIES', {
				USERNAME=>$USERNAME,MID=>$MID,EIAS=>$EIAS,EBAYUSER=>$EBAYUSER,CatNum=>$cat,Category=>$name
				},debug=>1,sql=>1);
			$edbh->do($pstmt);
			}


		## NOTE: we should add a note to the syndication object.
		}
	$sth->finish();

	&DBINFO::db_user_close();

	return($count);
	}

##
## pass in an empty array (OUTPUTREF) - this calls itself recursively and populates the OUTPUTREF
##
sub herdStoreCats {
	my ($PATH,$catsref,$OUTPUTREF) = @_;

	my %cats = ();
   foreach my $ci0 (@{$catsref}) {
		my $CATEGORYID = $ci0->{'CategoryID'}->[0];
		if ($CATEGORYID<100) { $CATEGORYID--; }	# shift down by 1 so Category 1=1 (instead of 2 which is how eBay does it)

		push @{$OUTPUTREF}, [ $CATEGORYID, (($PATH ne '')?"$PATH / ":''). $ci0->{'Name'}->[0] ];
		if (defined $ci0->{'ChildCategory'}) {
			herdStoreCats( $ci0->{'Name'}->[0], $ci0->{'ChildCategory'}, $OUTPUTREF );
			}
		}

	return(\@OUTPUTREF);
	}




1;