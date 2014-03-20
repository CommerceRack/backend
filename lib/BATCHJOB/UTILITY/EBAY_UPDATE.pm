package BATCHJOB::UTILITY::EBAY_UPDATE;

use strict;
use Data::Dumper;
use lib "/backend/lib";
require INVENTORY2;
require EBAY2;
require LISTING::EVENT;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }


##
## this has it's own custom "finish" function that provides a link back to the product.
##
sub finish {
	my ($self, $bj) = @_;

	my $meta = $bj->meta();
	$bj->finish('SUCCESS',qq~eBay Job done.~);

	return();
	}

##
##
##
sub work {
	my ($self, $bj) = @_;


	my $USERNAME = $bj->username();
	my $LUSERNAME = $bj->lusername();
	my $MID = $bj->mid();
	my $PRT = $bj->prt();
	my $meta = $bj->meta();


	my ($eb) = EBAY2->new($USERNAME,PRT=>$PRT);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my $FUNCTION = $meta->{'.function'};
	if ($FUNCTION eq '') { $FUNCTION = $meta->{'function'}; } 

	## SOME PREFLIGHT STUFF.
	if (0) {
		$meta->{'.all'}++;
		$meta->{'.live'}++;
		}
#	elsif ($FUNCTION eq 'enable-ebay-checkout') {
#		## 1. set token style		
#		$bj->progress(0,0,"Setting CHKOUT_STYLE on TOKENS");
#		my $pstmt = "update EBAY_TOKENS set CHKOUT_STYLE='EBAY' where MID=$MID /* $USERNAME */ and PRT=$PRT";
#		print STDERR $pstmt."\n";
#		$udbh->do($pstmt);
#
#		## 2. create exception flag
#		$bj->progress(0,0,"Adding tech support flag to account.");
#		require ZACCOUNT;
#		&ZACCOUNT::create_exception_flags($USERNAME,sprintf("EC-%d",$PRT),45);
#		$meta->{'.all'}++;
#		$meta->{'.live'}++;
#		}
	elsif ($FUNCTION eq 'end-all') {
		$meta->{'.all'}++;
		$FUNCTION = 'end';
		}
	elsif ($FUNCTION eq 'refresh') {
		## this will implicitly set .all, .live, .profile, etc.
		$meta->{'.live'}++;
		}
	elsif ($FUNCTION eq 'end') {
		$meta->{'.live'}++;
		}
	elsif ($FUNCTION ne '') {
		die("Unknown FUNCTION: $FUNCTION");
		}


   my @listings = ();
	my %FOUND = ();

	## GET LISTINGS from DATABASE
	if (1) {
	 	my $pstmt = "select ID,EBAY_ID,TITLE,PRODUCT,ENDS_GMT,CLASS from EBAY_LISTINGS where MID=$MID /* $USERNAME */ ";
		$pstmt .= " and EBAY_ID>0 and IS_ENDED=0 ";

		my @PIDS = ();
		if ($meta->{'.all'} ne '') {
			## this does *EVERYTHING*
			$pstmt .= " and PRT=$PRT ";
			}
		elsif ($meta->{'.listing'} ne '') {
			my $set = &DBINFO::makeset($udbh,[split(/,/,$meta->{'.listing'})]);
			$pstmt .= " and EBAY_ID in ($set)";
			}
		elsif ($meta->{'.product'} ne '') {
			#my ($items) = &INVENTORY::list_other('EBAY',$USERNAME,$meta->{'.product'},0);
			#foreach my $item (@{$items}) {
			#	## returns: LISTINGID,PRODUCT,SKU,QTY,EXPIRES_GMT,CREATED, etc.
			#	if ($item->{'LISTINGID'} eq '') {
			#		## old syndication format (no listing id) probalby safe to remove
			#		&INVENTORY::set_other($USERNAME,'EBAY',$item->{'SKU'},0,'uuid'=>$item->{'LISTINGID'});
			#		}
			#	else {
			#		push @listings, { 
			#			Msg=>"Inventory reserved item: $item->{'LISTINGID'} qty: $item->{'QTY'}",
			#			EBAY_ID=>$item->{'LISTINGID'},
			#			ENDS_GMT=>$item->{'EXPIRES_GMT'},
			#			};
			#		$FOUND{$item->{'LISTINGID'}}++;
			#		}
			#	}
			push @PIDS, $meta->{'.product'};
			}
		elsif ($meta->{'.profile'} || $meta->{'profile'}) {
		   my $ARREF = &PRODUCT::BATCH::list_by_attrib($USERNAME,'zoovy:profile',$meta->{'.profile'} || $meta->{'profile'});
			@PIDS = @{$ARREF};
			}
		elsif ($meta->{'.selectors'} ne '') {
			@PIDS = &PRODUCT::BATCH::resolveProductSelector($USERNAME,$bj->prt(),$meta->{'.selectors'});
			}

		if (scalar(@PIDS)>0) {
			$pstmt .= ' and PRODUCT in '.DBINFO::makeset($udbh,\@PIDS);
			}
	
		#if ($meta->{'.live'}>0) {
		#	## hmm.. this might be a good idea someday.
		#	# $pstmt .= " and (ENDS_GMT>".time()." or (ENDS_GMT=0 and IS_GTC>0)) ";
		#	}

		# $pstmt .= "  and PRODUCT=5806001613; ";
		# $pstmt .= " and EBAY_ID='250686967293'";

		if ((scalar(@listings)==0) && ($pstmt ne '')) {
			print $pstmt."\n";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my $listref = $sth->fetchrow_hashref() ) {
				next if (defined $FOUND{$listref->{'EBAY_ID'}});
				push @listings, $listref;
		  	   }
			$sth->finish();
			}
		}

	## SANITY:
	## at this poing @listings contains a hashref of listings, where at least
	##		ID=>, EBAY_ID, TITLE, ENDS_GMT are set.	


	my $rectotal = scalar(@listings);
	my $reccount = 0;
	$bj->progress(0,0,"Found ".scalar(@listings)." live listings to update");

	foreach my $listing (@listings) {
		next if ($listing->{'EBAY_ID'} eq '');

		my $TARGET = sprintf("EBAY.%s",$listing->{'CLASS'});
		($TARGET) = LISTING::EVENT::normalize_target($TARGET);
	
		my $VERB = '';
		if ((not defined $listing->{'EBAY_ID'}) || ($listing->{'EBAY_ID'} == 0)) {
			$bj->slog("Zoovy did not find eBay item to revise.");
			}
		elsif ($FUNCTION eq 'refresh') {
			$VERB = 'UPDATE-LISTING';
			}
		elsif ($FUNCTION eq 'end') {
			$VERB = 'END';
			}
		else {
			die("Unknown function: '$FUNCTION'");
			}

		my ($le) = undef;	
		if ($VERB eq '') {
			}
		elsif (not defined $TARGET) {
			$bj->slog("ERROR:Could not ascertain target");
			}
		else {
			($le) = LISTING::EVENT->new(
				USERNAME=>$USERNAME,LUSER=>$LUSERNAME,
				REQUEST_APP=>'EBBJ',
				REQUEST_APP_UUID=>undef,
				REQUEST_BATCHID=>$bj->id(),
				SKU=>$listing->{'PRODUCT'},
				TARGET=>$TARGET,
				TARGET_UUID=>$listing->{'ID'},
				TARGET_LISTINGID=>$listing->{'EBAY_ID'},
				PRT=>$PRT,VERB=>$VERB,LOCK=>1
				);	
			}

		my $P = undef;
		if (ref($le) eq 'LISTING::EVENT') {
			($P) = PRODUCT->new($USERNAME,$listing->{'PRODUCT'});
			}

		if (not defined $P) {
			$bj->slog("INTERNAL-ERROR[$listing->{'PRODUCT'}] was not able to load from database");
			}		
		elsif (ref($P) ne 'PRODUCT') {
			$bj->slog("INTERNAL-ERROR[$listing->{'PRODUCT'}] object was not valid.");
			}		
		elsif (ref($le) eq 'LISTING::EVENT') {
			$le->dispatch($udbh,$P);
			if ($le->has_win()) {
				$bj->slog("$VERB $listing->{'EBAY_ID'} $listing->{'TITLE'}");
				}
			else {
				my $ref = $le->whatsup();
				$bj->slog(sprintf("%s[%d]: %s",$ref->{'_'},$listing->{'EBAY_ID'},$ref->{'+'}));
				}
			}
		else {
			$bj->slog("INTERNAL-ERROR[$listing->{'PRODUCT'}] - was not able to create/process a listing event");
			}

		if ((++$reccount % 3)==0) {
			$bj->progress($reccount,$rectotal,"Did $FUNCTION on listing: $listing->{'EBAY_ID'} ");
			}
		}
	
	&DBINFO::db_user_close();

	$bj->progress(0,0,"Done");

#	my @RECORDS = ();
#	my $reccount = 0;
#	my $rectotal = scalar(@RECORDS);
#
#	foreach my $prod (@RECORDS) {
#		if ((++$reccount % 100)==1) {
#			$bj->progress($reccount,$rectotal,"Did something");
#			}
#	   }
#	$bj->progress($rectotal,$rectotal,"Finished doing something");

	return(undef);
	}

1;
