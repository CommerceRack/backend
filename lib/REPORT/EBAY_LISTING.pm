package REPORT::EBAY_LISTING;

use strict;

use lib "/backend/lib";
require ZTOOLKIT;
require DBINFO;
require EBAY2;

use Data::Dumper;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub r { return($_[0]->{'*PARENT'}); }

##
## REPORT: EBAYLISTING
##

sub init {
	my ($self) = @_;
	
	my $begins = 0;
	my $ends = 0;
	
	my $r = $self->r();
	my $meta = $r->meta();

	$meta->{'title'} = 'eBay Listing Report';
	$meta->{'subtitle'} = '';


	$r->{'@HEAD'} = [
		{ id=>0, 'name'=>'Id', type=>'NUM', hidden=>1, },
		{ id=>1, 'name'=>'eBay #', type=>'CHR', link=>'http://cgi.ebay.com/ws/eBayISAPI.dll?ViewItem&item=', target=>'_ebay', function=>'showDetail' },
		{ id=>2, 'name'=>'Type', type=>'CHR', },
		{ id=>3, 'name'=>'Product', type=>'CHR', },
		{ id=>4, 'name'=>'Title', type=>'CHR', },
		{ id=>5, 'name'=>'Launched', type=>'DAY' },
		{ id=>6, 'name'=>'Launch Hour', type=>'NUM', hidden=>1, },
		{ id=>7, 'name'=>'Items Sold', type=>'NUM' },
		{ id=>8, 'name'=>'Items ForSale', type=>'NUM' },
		{ id=>9, 'name'=>'Bid Price', type=>'NUM' },
		{ id=>10, 'name'=>'Bid Count', type=>'NUM' },
		{ id=>11, 'name'=>'Visitors', type=>'NUM', hidden=>1, },
		{ id=>12, hidden=>1, },
		{ id=>13, hidden=>1, }, 
		{ id=>14, hidden=>1, },

		{ id=>15, 'name'=>'Category Number', type=>'NUM', },
		{ id=>16, 'name'=>'Category Name', type=>'CHR', },
		{ id=>17, 'name'=>'Store Category Number', type=>'NUM', },
		{ id=>18, 'name'=>'Store Category', type=>'CHR', },
		{ id=>19, 'name'=>'Status', type=>'CHR', },

		{ id=>20, hidden=>1 },
		{ id=>21, hidden=>1 },
		{ id=>22, 'name'=>'Action', type=>'ACT', },
		{ id=>23, 'name'=>'Ends', type=>'YDT', },
		{ id=>24, 'name'=>'Is GTC', type=>'CHR', hidden=>1, },
		];

	$r->{'@BODY'} = [];

	return(0);
	}


##
## returns how many times the status appears for a particular type
## NOTE: status is col #19
##
sub count_status {
	my ($self,$line) = @_;

	my $lookup = $line->{'status'};
	my $count = 0;
	foreach my $row (@{$self->{'@BODY'}}) {
		if ($row->[19] eq $lookup) { $count++; }
		}
	return($count);
	}

##
## returns the @row for a specific claim
##
sub format_row {
	my ($USERNAME,$claim) = @_;

	return();
	}


###################################################################################
##
##
sub work {
	my ($self) = @_;

	my ($r) = $self->r();
	my $meta = $r->meta();

	my $USERNAME = $r->username();
	my $MID = &ZOOVY::resolve_mid($r->username());
	my @IDS = ();

	my $edbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select ID,PRODUCT from EBAY_LISTINGS where MID=$MID /* $USERNAME */";

	if ($meta->{'.type'} eq '') {
		$meta->{'.type'} = $meta->{'type'};
		}

	if ($meta->{'.type'} eq 'SYNDICATION-LIVE') {
		## only show active SYNDICATION listings.
		$pstmt .= " and CHANNEL=-1 and (ENDS_GMT>".time()." or IS_GTC>0)";
		}
	elsif ($meta->{'.type'} eq 'SYNDICATION-ENDED') {
		## only show active SYNDICATION listings.
		$pstmt .= " and ENDS_GMT<".time()." and CHANNEL=-1";
		}
	elsif ($meta->{'.type'} eq 'ACTIVE-ALL') {
		## only show active SYNDICATION listings.
		$pstmt .= " and (ENDS_GMT<".time()." or IS_GTC=1)";
		}
	else {
		warn "unknown type: $meta->{'.type'}\n";
		die();
		}
	print STDERR $pstmt."\n";
#	die();
	
	$r->progress(1,3,"Getting Listings");

	my $sth = $edbh->prepare($pstmt);
	$sth->execute();
	while ( my ($id) = $sth->fetchrow() ) { push @IDS, $id; }
	$sth->finish();	
	
	if (scalar(@IDS)==0) {
		$r->progress(0,0,"No records matching report criteria");
		}
	

	my $jobs = &ZTOOLKIT::batchify(\@IDS,500);

	if (scalar(@IDS)>0) {
		$r->progress(1,3,"Getting Categories");
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select CatNum,Category from EBAYSTORE_CATEGORIES where MID=$MID /* $self->{'USERNAME'} */";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		my %STORECATS = ();
		while ( my ($catnum,$category) = $sth->fetchrow() ) { $STORECATS{$catnum} = $category; }
		$sth->finish();
		$STORECATS{-1} = 'Other'; 
		$self->{'%STORECATS'} = \%STORECATS;
		&DBINFO::db_user_close();
		$self->{'%CATMAP'} = {};
		}

	my $reccount = 0;
	my $rectotal = scalar(@{$jobs});
	
	my ($INV2) = INVENTORY2->new($USERNAME);
	my ($detail,$count) = $INV2->detail('+'=>'MARKET','WHERE'=>[ 'MARKET_DST', 'EQ', 'EBAY' ]);
	my %INVDETAIL_ROWS = ();		## hash keyed by EBAY_ID with value being detail row
	foreach my $row (@{$detail}) {
		$INVDETAIL_ROWS{ $row->{'MARKET_REFID'} } = $row;
		}
	
	## phase1: build the sql statement
	my $t = time();
	foreach my $listingids (@{$jobs}) {
		my $edbh = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = '';
		foreach my $id (@{$listingids}) { $pstmt .= $edbh->quote($id).','; }
		chop($pstmt);
		$pstmt = "select ID,PRODUCT,CLASS,EBAY_ID,LAUNCHED_GMT,ENDS_GMT,QUANTITY,ITEMS_SOLD,ENDS_GMT,BIDPRICE,BIDCOUNT,BUYITNOW,TITLE,CATEGORY,STORECAT,IS_GTC from EBAY_LISTINGS where MID=$MID and ID in ($pstmt)";
		print STDERR $pstmt."\n";

		my $sth = $edbh->prepare($pstmt);
		$sth->execute();
		while ( my $hashref = $sth->fetchrow_hashref() ) {
			my @ROW = ();

			my $EBAY_ID = $hashref->{'EBAY_ID'};
			$hashref->{'ITEMS_FORSALE'} = $INVDETAIL_ROWS{ $EBAY_ID }->{'QTY'};
			if (not defined $hashref->{'ITEMS_FORSALE'}) { $hashref->{'ITEMS_FORSALE'} = '?'; }

			my $STATUS = '';
			if ($hashref->{'IS_GTC'}) {
				if ($hashref->{'ITEMS_FORSALE'}==0) { $STATUS = 'SOLD_OUT'; }		# status of SOLD_OUT means that a STORE/FIXED GTC listing has ended 
				elsif (($hashref->{'ENDS_GMT'}>0) && ($hashref->{'ENDS_GMT'}<$t)) { $STATUS = 'GTC-ENDED'; }
				else { $STATUS = 'FOR_SALE'; }												# status of FOR_SALE means the item is listed on ebay waiting for buyers
				}
			elsif ($hashref->{'ENDS_GMT'}==0) {
				$STATUS = 'ERROR';				# status of ERROR means it did not launch!
				}
			elsif ($hashref->{'ENDS_GMT'}<$t) {
				if ($hashref->{'ITEMS_FORSALE'}==0) { $STATUS = 'SOLD_OUT'; }		# status of SOLD_OUT means that all available quantities sold out.
				elsif ($hashref->{'ITEMS_SOLD'}>0) { $STATUS = 'SOLD_SOME'; }		# status of SOLD_SOME means that some winners won, but not all.
				else { $STATUS = 'SOLD_NONE'; }												# status of SOLD_NONE means the item did not sell.
				}
			else {
				$STATUS = 'ACTIVE';																# status of ACTIVE means it's being sold right now.
				}


			my $ACTION = '';
#			if ($STATUS eq 'ACTIVE') {
#				$ACTION = "<input type=\"button\" value=\"Manage\" class=\"button2\" onClick=\"customAction('ACTIVE','$hashref->{'ID'}');\">";
#				}


			# { id=>0, 'name'=>'Id', type=>'NUM' },
			push @ROW, $hashref->{'ID'};

			# { id=>1, 'name'=>'eBay #', type=>'CHR', link=>'http://cgi.ebay.com/ws/eBayISAPI.dll?ViewItem&item=', target=>'_ebay', function=>'showDetail' },
			push @ROW, $hashref->{'EBAY_ID'};

			# { id=>2, 'name'=>'Type', type=>'CHR', },
			push @ROW, $hashref->{'CLASS'};
	
			# { id=>3, 'name'=>'Product', type=>'CHR', },
			push @ROW, $hashref->{'PRODUCT'};

			# { id=>4, 'name'=>'Title', type=>'CHR', },
			push @ROW, $hashref->{'TITLE'};

			# { id=>5, 'name'=>'Launched', type=>'DAY' },
			push @ROW, &REPORT::format_date($hashref->{'LAUNCHED_GMT'});
	
			# { id=>6, 'name'=>'Launch Hour', type=>'NUM', hidden=>1, },
			push @ROW, &REPORT::format_hour($hashref->{'LAUNCHED_GMT'});
	
			# { id=>7, 'name'=>'Items Sold', type=>'NUM' },
			push @ROW, $hashref->{'ITEMS_SOLD'};
	
			# { id=>8, 'name'=>'Items Remain', type=>'NUM' },
			push @ROW, $hashref->{'ITEMS_FORSALE'};
		
			# { id=>9, 'name'=>'Bid Price', type=>'NUM' },
			push @ROW, $hashref->{'BIDPRICE'};
	
			# { id=>10, 'name'=>'Bid Count', type=>'NUM' },
			push @ROW, $hashref->{'BIDCOUNT'};
	
			# { id=>11, 'name'=>'Visitors', type=>'NUM', },
			push @ROW, $hashref->{'CATEGORY'};

			push @ROW, ''; # { id=>12, },
			push @ROW, ''; # { id=>13, }, 
			push @ROW, ''; # { id=>14, },

			# { id=>15, 'name'=>'Category Number', type=>'NUM', },
			push @ROW, $hashref->{'CATEGORY'};
			$self->{'%CATMAP'}->{$hashref->{'CATEGORY'}}++;		# 
	
			# { id=>16, 'name'=>'Category Name', type=>'CHR', },
			push @ROW, '';		# note: we'll come back and the end when @JOBCOUNT==0 and map all these at once!
	
			# { id=>17, 'name'=>'Store Category Number', type=>'NUM', },
			push @ROW, $hashref->{'STORECAT'};
	
			# { id=>18, 'name'=>'Store Category', type=>'CHR', },
			my $storecat = $self->{'%STORECATS'}->{ $hashref->{'STORECAT'} };
			if (not defined $storecat) { $storecat = 'Unknown'; }
			push @ROW, $storecat;

			# { id=>19, 'name'=>'Status', type=>'CHR', },
			push @ROW, $STATUS;

			push @ROW, ''; # { id=>20, },
			push @ROW, ''; # { id=>21, },

			# { id=>22, 'name'=>'Action', type=>'CHR', },
			push @ROW, $ACTION;

			# { id=>23, 'name'=>'Ends', type=>'YTD', }
			push @ROW, $hashref->{'ENDS_GMT'};

			# { id=>24, 'name'=>'Is GTC', type=>'CHR', }
			push @ROW, $hashref->{'IS_GTC'};

			push @{$r->{'@BODY'}}, \@ROW;		
			}
		
		$r->progress(++$reccount,$rectotal,"Parsing Listing Batches");
		&DBINFO::db_user_close();
		}
	&DBINFO::db_user_close();

	$self->{'jobend'} = time()+1;
	}




1;

