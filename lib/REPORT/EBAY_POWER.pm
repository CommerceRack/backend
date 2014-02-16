package REPORT::EBAY_POWER;

use strict;

use lib "/backend/lib";
require DBINFO;
require ZTOOLKIT;

use lib "/httpd/ebayapi/modules";

use Data::Dumper;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub r { return($_[0]->{'*PARENT'}); }

##
## REPORT: EBAYLISTING
##	PARAMS: 
##		period
##			start_gmt
##			end_gmt
##

sub init {
	my ($self) = @_;
	
	my $begins = 0;
	my $ends = 0;

	my $r = $self->r();

	my $meta = $r->meta();
	$meta->{'title'} = 'Sales Report';

	$meta->{'title'} = 'eBay PowerLister Report';
	$meta->{'subtitle'} = '';

	$r->{'@HEAD'} = [
		{ id=>0, 'name'=>'Channel #', type=>'NUM', link=>'http://www.zoovy.com/biz/manage/channels/edit.cgi?EXIT=POPUP&ID=', target=>'_channel' },
		{ id=>1, 'name'=>'Product', type=>'CHR', cell=>'nowrap=1' },
		{ id=>2, 'name'=>'Title', type=>'CHR', cell=>'nowrap=1'},
		{ id=>3, hidden=>1, },
		{ id=>4, 'name'=>'Created', type=>'YDT', cell=>'nowrap=1' },
		{ id=>5, 'name'=>'Expires', type=>'YDT', cell=>'nowrap=1' },
		{ id=>6, hidden=>1, },
		{ id=>7, hidden=>1, },
		
		{ id=>8, 'name'=>'Sell Qty', type=>'NUM' },
		{ id=>9, 'name'=>'Qty Sold', type=>'NUM', },
		{ id=>10, 'name'=>'Inv Avail', type=>'NUM', },
		{ id=>11, name=>'Last Sale', type=>'YDT', cell=>'nowrap=1' },
		{ id=>12, hidden=>1, },

		{ id=>13, 'name'=>'List Todo', type=>'NUM' },
		{ id=>14, 'name'=>'List Done', type=>'NUM' },
		{ id=>15, hidden=>1, },
		{ id=>16, hidden=>1, },
		{ id=>17, hidden=>1, },

		{ id=>18, 'name'=>'Start Hour', type=>'NUM', },
		{ id=>19, 'name'=>'End Hour', type=>'NUM', },
		{ id=>20, 'name'=>'Allowed Days', type=>'CHR', },
		{ id=>21, 'name'=>'Concurrent', type=>'NUM' },
		{ id=>22, 'name'=>'Notes', type=>'CHR', cell=>'nowrap=1'},
		{ id=>23, 'name'=>'Errors', type=>'NUM', },		
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

	my $r = $self->r();
	my $lookup = $line->{'status'};
	my $count = 0;
	foreach my $row (@{$r->{'@BODY'}}) {
		if ($row->[19] eq $lookup) { $count++; }
		}
	return($count);
	}

$REPORT::FUNCTIONS{'count_status'} = \&count_status;
$REPORT::FUNCTIONS{'showDetail'} = \&showDetail;

##
## this function checks to make sure that the detail for a specific dispute is displayed at runtime.
##
sub showDetail {
	my ($R,$ROWREF) = @_;

	#my $disputeref = &DISPUTES::fetch_dispute($R->{'USERNAME'},$ROWREF->[2]);
	#if ($disputeref->{'DETAIL'}) {
	#	$ROWREF->[11] = $disputeref->{'DETAIL'};
	#	}

	#if ($ROWREF->[9] eq 'Open') {
	#	## don't let them sit on the refresh button (only can be used once per hour)
	#	if ($disputeref->{'VERIFIED_GMT'}>(time()-3600)) { $ROWREF->[10] = ''; }
	#	}

	}


################################################################
##
## a customAction can be created to allow reports to actually modify the dataset.
##
sub customAction {
	my ($self,$ACTION,$KEY,$params,$cgi) = @_;

	my ($listing,$error) = LISTING->new('EBAY',$self->{'USERNAME'},ooid=>$KEY);
	if ($error ne '') {
		require qq~
		<b>Internal error - could not load listing!</b><br>
		ERROR: [$error]
		~;
		}
	elsif ($ACTION eq 'ENDITEM') {
		return('STILL UNDER DEVELOPMENT: EndItem Not implemented Yet! (use channel manager instead)');
		}
	elsif ($ACTION eq 'ACTIVE') {
		my $out = qq~<b>Manage an Active Listing</b><Br><br><table>~;

		$out .= "<tr><td>eBay Id:</td><td>$listing->{'EBAY_ID'}</td></tr>";
		$out .= "<tr><td>Product:</td><td>$listing->{'PRODUCT'} - $listing->{'TITLE'}</td></tr>";
		$out .= "<tr><td>Type:</td><td>$listing->{'CLASS'}</td></tr>";
		if ($listing->{'TYPE'} eq 'PERSONAL') {
			$out .= "<tr><td>Destination User:</td><td>$listing->{'DEST_USER'} (this is a second chance offer)</td></tr>";
			}
		if ($listing->{'CHANNEL'}>0) {
			$out .= "<tr><td>Created by:</td><td>Channel $listing->{'CHANNEL'}</td></tr>";
			}
		elsif ($listing->{'CHANNEL'}==-1) {
			$out .= "<tr><td>Created by:</td><td>Syndication</td></tr>";
			}

		$out .= "<tr><td>Quantity:</td><td>$listing->{'QUANTITY'} ($listing->{'ITEMS_SOLD'} sold, $listing->{'ITEMS_REMAIN'} remaining)</td></tr>";
		$out .= "</table><br><table>";
		$out .= "<tr><td>Category:</td><td>$listing->{'CATEGORY'}</td></tr>";
		$out .= "<tr><td>Bid Price:</td><td>$listing->{'BIDPRICE'}</td></tr>";
		$out .= "<tr><td>Bid Count:</td><td>$listing->{'BIDCOUNT'}</td></tr>";
		$out .= "<tr><td>Auto Second Chance:</td><td>".(($listing->{'IS_SCOK'}>0)?sprintf("\$%.2f",$listing->{'IS_SCOK'}):'No')."</td></tr>";
		$out .= "<tr><td>&nbsp;</td></tr>";
		if ($listing->{'IS_POWERLISTER'}>0) {
			$out .= "<tr><td>Powerlister:</td><td>$listing->{'IS_POWERLISTER'}</td></tr>";
			$out .= "<tr><td>Trigger Price:</td><td>$listing->{'TRIGGER_PRICE'}</td></tr>";
			}

		##
		## ENDS_GMT,       IS_RESERVE, THUMB, PRODTS, 'CREATED_GMT' => '1106956989', 'BUYITNOW' => '0.00', 'TITLE' => 'New Extended Battery for Samsung A400 Cell Phone',
		##

		return qq~$out</table>
		<input type="button" class="button2" onClick="customAction('ENDITEM',$KEY);" value=" End Item ">
		<input type="button" class="button2" onClick="customAction('QUIT');" value=" Quit ">
		<br>
		<br>
		~;
		}
	elsif ($ACTION eq 'QUIT') {
		return();
		}
	else {
		return('Custom ACTION: '.$ACTION.' KEY='.$KEY);
		}

	return('');
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


	my $r = $self->r();
	my $MID = &ZOOVY::resolve_mid($r->username());
	my $USERNAME = $r->username();

	my @IDS = ();

	$r->progress(0,0,"Downloading summary of all powerlisters");

	my $edbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select CHANNEL,PRODUCT from EBAY_POWER_QUEUE where MERCHANT=".$edbh->quote($USERNAME);
	print STDERR $pstmt."\n";
	my $sth = $edbh->prepare($pstmt);
	$sth->execute();
	while ( my ($id,$p) = $sth->fetchrow() ) { push @IDS, "$id,$p"; }
	$sth->finish();	

	my $jobs = &ZTOOLKIT::batchify(\@IDS,100);
	my $reccount = 0;
	my $rectotal = scalar(@IDS);
	
	foreach my $batch (@{$jobs}) {
		my $edbh = &DBINFO::db_user_connect($USERNAME);

		## phase1: build the sql statement
		my @PRODS = ();
		my $pstmt = '';
		foreach my $idprod (@{$batch}) { 
			my ($id,$prod) = split(/,/,$idprod);
			push @PRODS, $prod;
			$pstmt .= $edbh->quote($id).','; 
			}
		chop($pstmt);
		my ($PIDINVSUMMARY) = INVENTORY2->new($USERNAME)->summary('@PIDS'=>\@PRODS,'PIDS_ONLY'=>1);
		#	my ($invref,$reserveref,$locref) = &INVENTORY::fetch_qty($USERNAME,\@PRODS);

		$pstmt = "select * from EBAY_POWER_QUEUE where MERCHANT=".$edbh->quote($USERNAME)." and CHANNEL in ($pstmt)";
		print STDERR $pstmt."\n";
		my $sth = $edbh->prepare($pstmt);
		$sth->execute();
		while ( my $hashref = $sth->fetchrow_hashref() ) {
			my @ROW = ();
			$reccount++;

			## { id=>0, 'name'=>'Channel #', type=>'NUM', hidden=>1, },
			$ROW[0] = $hashref->{'CHANNEL'};

			## { id=>1, 'name'=>'Product', type=>'CHR', cell=>'nowrap=1' },
			$ROW[1] = $hashref->{'PRODUCT'};

			## { id=>2, 'name'=>'Title', type=>'CHR', cell=>'nowrap=1'},
			$ROW[2] = $hashref->{'TITLE'};

			##	{ id=>3, hidden=>1, }
			## { id=>4, 'name'=>'Created', type=>'YDT', cell=>'nowrap=1' },
			$ROW[4] = &ZTOOLKIT::mysql_to_unixtime($hashref->{'CREATED_TS'});

			##	{ id=>5, 'name'=>'Expires', type=>'YDT', cell=>'nowrap=1' },
			print "EXPIRES: $hashref->{'EXPIRES_TS'}\n";
			$ROW[5] = &ZTOOLKIT::mysql_to_unixtime($hashref->{'EXPIRES_TS'});

			##	{ id=>6, hidden=>1, }
			##	{ id=>7, hidden=>1, }
		
			##	{ id=>8, 'name'=>'Qty Reserved', type=>'NUM' },
			$ROW[8] = $hashref->{'QUANTITY_RESERVED'};

			##	{ id=>9, 'name'=>'Qty Sold', type=>'NUM', },
			$ROW[9] = $hashref->{'QUANTITY_SOLD'};

			##	{ id=>10, 'name'=>'Inv Remain', type=>'NUM', },
			$ROW[10] = $PIDINVSUMMARY->{$hashref->{'PRODUCT'}}->{'AVAILABLE'};

			## { id=>11, name=>'Last Sale', type=>'YDT', },
			$ROW[11] = ZTOOLKIT::mysql_to_unixtime($hashref->{'LAST_SALE_TS'});
			##	{ id=>12, hidden=>1, }
	
			##	{ id=>13, 'name'=>'List Allowed', type=>'NUM' },
			$ROW[13] = $hashref->{'LISTINGS_ALLOWED'};

			##	{ id=>14, 'name'=>'List Performed', type=>'NUM' },
			$ROW[14] = $hashref->{'LISTINGS_LAUNCHED'};

			##	{ id=>16, hidden=>1, }
			##	{ id=>17, hidden=>1, }

			##	{ id=>18, 'name'=>'Start Hour', type=>'NUM', },
			$ROW[18] = $hashref->{'START_HOUR'};

			##	{ id=>19, 'name'=>'End Hour', type=>'NUM', },
			$ROW[19] = $hashref->{'END_HOUR'};

			##	{ id=>20, 'name'=>'Allowed Days', type=>'CHR', },
			my $days = '';
			if ($hashref->{'LAUNCH_DOW'} == 0) { $days = 'All'; }
			else {
				if (($hashref->{'LAUNCH_DOW'} & 1)==1) { $days .= 'Mon,'; }
				if (($hashref->{'LAUNCH_DOW'} & 2)==2) { $days .= 'Tue,'; }
				if (($hashref->{'LAUNCH_DOW'} & 4)==4) { $days .= 'Wed,'; }
				if (($hashref->{'LAUNCH_DOW'} & 8)==8) { $days .= 'Thu,'; }
				if (($hashref->{'LAUNCH_DOW'} & 16)==16) { $days .= 'Fri,'; }
				if (($hashref->{'LAUNCH_DOW'} & 32)==32) { $days .= 'Sat,'; }
				if (($hashref->{'LAUNCH_DOW'} & 64)==64) { $days .= 'Sun,'; }
				chop($days);
				}
			$ROW[20] = $days;


			##	{ id=>21, 'name'=>'Concurrent', type=>'NUM' },
			$ROW[21] = $hashref->{'CONCURRENT_LISTINGS'};

			##	{ id=>22, 'name'=>'Notes', type=>'CHR', },
			my $notes = '';
			if ($hashref->{'CONCURRENT_LISTING_MAX'} > $hashref->{'CONCURRENT_LISTINGS'}) {
				$notes .= "Max Concurrent: $hashref->{'CONCURRENT_LISTING_MAX'},";
				}
			if ($hashref->{'TRIGGER_PRICE'}>0) { $notes .= "Trigger Price: $hashref->{'TRIGGER_PRICE'},"; }
			if ($hashref->{'FILL_BIN_ASAP'}>0) { $notes .= "Fill Immediate,"; }
			$ROW[22] = $notes;
			
			##	{ id=>23, 'name'=>'Errors', type=>'NUM', },
			$ROW[23] = $hashref->{'ERRORS'};

			push @{$r->{'@BODY'}}, \@ROW;		
			}
		$r->progress($reccount,$rectotal,"Downloading Powerlister Data");
	
		&DBINFO::db_user_close();
		}
	&DBINFO::db_user_close();

	return();
	}




1;

