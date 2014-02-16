package REPORT::SEARCHLOG_SUMMARY;

use strict;

use Date::Calc;
use lib "/backend/lib";
require DBINFO;
require PRODUCT;
require ZOOVY;
require CART2;
require SITE;

##
## these methods should be included in the header of every report::module
##
sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub r { return($_[0]->{'*PARENT'}); }


###########################################################################
##
##
##
sub init {
	my ($self, %params) = @_;

	my $r = $self->r();
	my $meta = $r->meta();
	my $USERNAME = $r->username();
	my $MID = $r->mid();
	
	if ($meta->{'.userparamter'}) {
		}

	$meta->{'title'} = 'Search Log Summary';
	$meta->{'subtitle'} = '';

	$r->{'@HEAD'} = [
		{ id=>0, 'name'=>'Date', type=>'CHR', linksto=>'ORDER', target=>'_blank' },
		{ id=>1, 'name'=>'AND/OR', type=>'CHR', },
		{ id=>2, 'name'=>'Search Term', type=>'CHR', },
		{ id=>3, 'name'=>'Results', type=>'CHR', },
		{ id=>4, 'name'=>'IP Address', type=>'NUM', },
		{ id=>5, 'name'=>'Session', type=>'CHR', },
		{ id=>6, 'name'=>'Domain', type=>'CHR' },
		{ id=>7, 'name'=>'Partition', type=>'NUM' },
		];

	$r->{'@SUMMARY'} = [
		{ 'name'=>'Totals', type=>'TITLE' },
		{ 'name'=>'Total Searches', type=>'CNT', src=>0, },
		{ 'name'=>'Unique Sessions', type=>'UNIQUE', src=>5, },

		{ 'name'=>'Sales Conversion', type=>'TITLE' },
		{ 'name'=>'Data', type=>'LOAD', meta=>'.summary_orders', listdelim=>'|' },
		
		{ 'name'=>'Top 50 Most Popular Terms', type=>'TITLE' },
		{ 'name'=>'Terms', type=>'LOAD', meta=>'.summary_popular', listdelim=>'|' },

		{ 'name'=>'Top 50 No Results', type=>'TITLE' },
		{ 'name'=>'Terms', type=>'LOAD', meta=>'.summary_noresults', listdelim=>'|' },

		{ 'name'=>'Sale Terms', type=>'TITLE' },
		{ 'name'=>'Terms', type=>'LOAD', meta=>'.summary_salesterms', listdelim=>'|' },

		];

	$r->{'@BODY'} = [];
	return($self);
	}

##################################################################################
##
## this module is what does the actual work, all t
##
sub work {
	my ($self) = @_;

	my $r = $self->r();
	my $meta = $r->meta();
	my $USERNAME = $r->username();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	$r->progress(0,0,"Starting .. ");

	my $rectotal = 0;
	my $reccount = 0;

	my %TOP_RESULTS = ();
	my %NO_RESULTS = ();
	my %SESSIONS = ();

	my %SESSION_SUMMARY = ();
	my %SESSION_STUFF = ();
	my %IPLOOKUP = ();


	my $CATALOG = '';
	if ($meta->{'.file'} =~ /SEARCH\-([A-Z0-9]+)\.log/) { $CATALOG = $1; }

	my $PATH = &ZOOVY::resolve_userpath($USERNAME);
	open F, "<$PATH/IMAGES/".$meta->{'.file'};
	while (<F>) {
		$reccount++;
		my @ROW = split(/\t/,$_);

		#20090426 23:57:19   AND celtic harp     17  75.170.43.84        Sqj2evvtzDsV9VrIEtm5MnChy       musicbyandreas.com  0
		next if ($ROW[4] eq '?');
		## this next part is for the SEARCH results.
		my ($dt,$type,$term,$matches,$ip,$session,$domain,$prt) = @ROW;

		## ignore search engines, network scanners, etc.
		my ($whatis) = SITE::whatis($ip,undef);
		next if ($whatis ne '');
		next if ($ip eq '66.240.244.217');	## exclude zoovy
		# next if ($session eq '*');	# there are legit searches that use a *

		push @{$r->{'@BODY'}}, \@ROW;

		if (defined $SESSIONS{ $ROW[5].'.'.$ROW[2] }) {
			## we've already counted this session
			}
		elsif ($ROW[3] == 0) {
			$NO_RESULTS{ $ROW[2] }++;
			$SESSIONS{ $ROW[5].'.'.$ROW[2] }++;
			}
		elsif ($ROW[3] > 0) {
			$TOP_RESULTS{ $ROW[2] }++;
			$SESSIONS{ $ROW[5].'.'.$ROW[2] }++;
			}

		$IPLOOKUP{$ip} = $session; 
		if (not defined $SESSION_SUMMARY{ $session }) {
			$SESSION_SUMMARY{ $session } = {};
			$SESSION_SUMMARY{ $session }->{'@terms'} = [];		# an array of search terms
			}
		$SESSION_SUMMARY{ $session }->{'match_total'} += $matches;
		$SESSION_SUMMARY{ $session }->{'searches'}++;
		$SESSION_SUMMARY{ $session }->{'zero_searches'} += ($matches==0)?1:0;
		$SESSION_SUMMARY{ $session }->{'nozero_searches'} += ($matches>0)?1:0;
		push @{ $SESSION_SUMMARY{ $session }->{'@terms'} }, $term;
		}
	close F;
	
	my @NO_RESULTS = reverse &ZTOOLKIT::value_sort(\%NO_RESULTS,'numerically');
	my @TOP_RESULTS = reverse &ZTOOLKIT::value_sort(\%TOP_RESULTS,'numerically');

	@NO_RESULTS = splice(@NO_RESULTS, 0, 100);
	@TOP_RESULTS = splice(@TOP_RESULTS, 0, 100);

	$meta->{'.summary_popular'} = '';
	foreach my $term (@TOP_RESULTS) {
		my $count = $TOP_RESULTS{$term};
		$meta->{'.summary_popular'} .= "$term($count)|";
		}
	chomp($meta->{'.summary_popular'});

	$meta->{'.summary_noresults'} = '';
	foreach my $term (@NO_RESULTS) {
		my $count = $NO_RESULTS{$term};
		$meta->{'.summary_noresults'} .= "$term($count)|";
		}
	chomp($meta->{'.summary_noresults'});

	$rectotal = $reccount;
	$r->progress($rectotal,$rectotal,"did $reccount/$rectotal records");



	##
	##
	##

	my $YYYYMM = undef;
	if ($meta->{'.file'} =~ /\-([\d]+)\.csv$/) {
#		print "YYYYMM: $1 ($meta->{'.file'})\n"; die();
		$YYYYMM = $1;
		my ($YYYY) = substr($YYYYMM,0,4);
		my ($MM) = substr($YYYYMM,-2);

		$r->progress(0,0,"Downloading orders in the month: $YYYYMM");

		my $BEGINS = sprintf("%04d%02d%02d000000",$YYYY,$MM,1);		
		my $ENDS = sprintf("%04d%02d%02d000000",Date::Calc::Add_Delta_YM($YYYY,$MM,1,0,1));

		my $BEGINTS = &ZTOOLKIT::mysql_to_unixtime($BEGINS);
		my $ENDTS = &ZTOOLKIT::mysql_to_unixtime($ENDS);

		#print Dumper(\%SESSION);
		#die();

		my $odbh =&DBINFO::db_user_connect($USERNAME);
		my $ORDERTB = &DBINFO::resolve_orders_tb($USERNAME,$MID);
		my @orders = ();
		my $pstmt = "select ORDERID,POOL from $ORDERTB where MID=$MID and CREATED_GMT>=".int($BEGINTS)." and CREATED_GMT<".int($ENDTS);
		print STDERR $pstmt."\n";
		my $sth = $odbh->prepare($pstmt);
		$sth->execute();
		while ( my ($orderid,$status) = $sth->fetchrow() ) {
			push @orders, $orderid;
			}

		my @ORDERS = ();
		my $ORDER_COUNT = 0;		## how many orders came from a session which conducted a search.
		my $NOZERO_SALE = 0;		## got only 'results'
		my $ZERO_SALE = 0;		## got only 'no results'
		my $BOTH_SALE = 0;		## got both 'no results, and results'
		my $TOTAL_SALE = 0;		## total sales.

		my $reccount = 0;
		my $rectotal = scalar(@orders);
		foreach my $orderid (@orders) {
			# print STDERR "USERNAME=[$USERNAME] [$orderid]\n";
			my ($O2) = CART2->new_from_oid($USERNAME,$orderid);
			next if (not defined $O2);
			# next if (($O2->in_get('mkt') & 32)>0); 	# skip amazon

			if ((++$reccount % 5)==0) {
				$r->progress($reccount,$rectotal,"Checking orders for matching sessions");
				}

			next if (not defined $O2);

			# print Dumper($o);
			my $cartid = $O2->in_get('cart/cartid');
			if (not defined $SESSION_SUMMARY{$cartid}) {
				$cartid = $IPLOOKUP{$O2->in_get('cart/ip_address')};
				}
			next if ($cartid eq '');
			next if ($cartid eq '*');

			if (defined $SESSION_SUMMARY{$cartid}) {
				# this is probably where we should be tracking stuff for jamie.
				# push @{$SESSION_SUMMARY{$cartid}->{'@stuff'} }, $o->stuff();

				if (($SESSION_SUMMARY{$cartid}->{'nozero_searches'}>0) && ($SESSION_SUMMARY{$cartid}->{'zero_searches'}>0)) {
					$BOTH_SALE++;
					}
				elsif ($SESSION_SUMMARY{$cartid}->{'nozero_searches'}>0) {
					$NOZERO_SALE++;
					}
				elsif ($SESSION_SUMMARY{$cartid}->{'zero_searches'}>0) {
					$ZERO_SALE++;
					}
				$TOTAL_SALE++;
			
#				$NOZERO_SALE += ($SESSION_SUMMARY{$cartid}->{'nozero_searches'}>0)?1:0;
#				$ZERO_SALE += ($SESSION_SUMMARY{$cartid}->{'zero_searches'}>0)?1:0;
				$SESSION_SUMMARY{$cartid}->{'sale'}++;
				push @ORDERS, $orderid;
				push @{$SESSION_SUMMARY{$cartid}->{'@orders'}}, $orderid;
				push @{$SESSION_SUMMARY{$cartid}->{'@ipaddr'}}, $O2->in_get('cart/ip_address');
#				print Dumper($SESSION_SUMMARY{$cartid});
				foreach my $item ( @{$O2->stuff2()->items()} ) {
					my ($PID) = $item->{'product'};
					my $TITLE = $item->{'prod_name'};
					$SESSION_SUMMARY{$cartid}->{'%items'}->{$PID} = $TITLE;
					}
				}
			$ORDER_COUNT++;
			}

		my $ZERO_NOSALE = 0;		## got zero results, didn't make a sale
		my $NOZERO_NOSALE = 0;	## got no-zero results, didn't make a sale
		my $TOTAL_NOSALE = 0;	## got results, didn't make a sale
		my $BOTH_NOSALE = 0;
		foreach my $cartid (keys %SESSION_SUMMARY) {
			next if (defined $SESSION_SUMMARY{$cartid}->{'sale'});
			if (($SESSION_SUMMARY{$cartid}->{'nozero_searches'}>0) && 
				($SESSION_SUMMARY{$cartid}->{'zero_searches'}>0)) {	
				$BOTH_NOSALE++;
				}
			elsif ($SESSION_SUMMARY{$cartid}->{'nozero_searches'}>0) {
				$NOZERO_NOSALE++;
				}
			elsif ($SESSION_SUMMARY{$cartid}->{'zero_searches'}>0) {
				$ZERO_NOSALE++;
				}
			$TOTAL_NOSALE++;
			}
		## BOTH is the number of essions which appear in 
		#$BOTH_NOSALE = ($NOZERO_NOSALE+$ZERO_NOSALE) - $TOTAL_NOSALE;
		## NOZERO shouldn't include things that were in BOTH
		#$NOZERO_NOSALE -= $BOTH_NOSALE;
		#$ZERO_NOSALE -= $BOTH_NOSALE;
	
		my $ZERO_RATIO = ($ZERO_NOSALE)?sprintf("%.2f\%",($ZERO_SALE/$ZERO_NOSALE)*100):0;
		my $NOZERO_RATIO = ($NOZERO_NOSALE)?sprintf("%.2f\%",($NOZERO_SALE/$NOZERO_NOSALE)*100):0;
		my $BOTH_RATIO = ($BOTH_NOSALE)?sprintf("%.2f\%",($BOTH_SALE/$BOTH_NOSALE)*100):0;
		my $TOTAL_RATIO = ($TOTAL_NOSALE)?sprintf("%.2f\%",($TOTAL_SALE/$TOTAL_NOSALE)*100):0;
		
		# print Dumper(\@ORDERS);
		use Data::Dumper;
		$meta->{'.summary_orders'} = qq~
<table>
	<tr class="zoovysub1header">
		<td></td>
		<td>Zero Results Only</td>
		<td>Found Results Only</td>
		<td>Both Found/Zero Only</td>
		<td>Total</td>
	</tr>
	<tr>
		<td><b>SALE MADE</b></td>
		<td>$ZERO_SALE</td>
		<td>$NOZERO_SALE</td>
		<td>$BOTH_SALE</td>
		<td>$TOTAL_SALE</td>
	</tr>
	<tr>
		<td><b>SALE MISSED</b></td>
		<td>$ZERO_NOSALE</td>
		<td>$NOZERO_NOSALE</td>
		<td>$BOTH_NOSALE</td>
		<td>$TOTAL_NOSALE</td>
	</tr>
	<tr>
		<td><b>RATIO</b></td>
		<td>$ZERO_RATIO</td>
		<td>$NOZERO_RATIO</td>
		<td>$BOTH_RATIO</td>
		<td>$TOTAL_RATIO</td>
	</tr>
</table>
<div class="hint">
"SALE MADE" represents one or more orders was placed, "SALE MISSED" represents no sale was made in the reporting period.
"Zero Results Only" tracks the sessions where all searches resulted in zero matches.
"Found Results Only" tracks the sessions where all searches resulted in one or more possible matches.
"Both Found/Zero Only" tracks sessions where multiple searches were performed, and had both zero, and non-zero search results.

</div>
~;

		my $c = '';
		my $r = '';
		foreach my $cartid (keys %SESSION_SUMMARY) {
			next unless (defined $SESSION_SUMMARY{$cartid}->{'sale'});
			$r = ($r eq 'r0')?'r1':'r0';
			my $orderstxt = join(', ',@{$SESSION_SUMMARY{$cartid}->{'@orders'}});

			my $items = '';
			foreach my $PID (keys %{$SESSION_SUMMARY{$cartid}->{'%items'}}) { 
				$items .= "<li> $PID: ".$SESSION_SUMMARY{$cartid}->{'%items'}->{$PID}; 
				}

			my $terms = '';
			foreach my $term (@{$SESSION_SUMMARY{$cartid}->{'@terms'}}) {
				$terms .= "<li> $term<br>";
				my ($pidslist) = &SEARCH::search($USERNAME,KEYWORDS=>"$term",CATALOG=>"$CATALOG",LOG=>0);
				my $found = 0;
				foreach my $pid (@{$pidslist}) {
					if ($SESSION_SUMMARY{$cartid}->{'%items'}->{$pid}) {
						$found++;
						$terms .= "<i>$pid</i> ";
						}
					}
				if (not $found) {
					$terms .= "<font color='red'>No products from order matched.</font>";
					}
				}

			$c .= "<tr class='$r'><td valign=top>$orderstxt</td><td valign=top>$terms</td><td valign=top>$items</td></tr>";
			}
		$meta->{'.summary_salesterms'} = qq~<table>$c</table>~;

		#Dumper(
		#	'SEARCH_COUNT'=>scalar(keys %SESSION_SUMMARY),
		#	'ORDER_COUNT'=>$ORDER_COUNT,
		#	'NOZERO_SALE'=>$NOZERO_SALE,
		#	'ZERO_SALE'=>$ZERO_SALE,
		#	'NOZERO_NOSALE'=>$NOZERO_NOSALE,
		#	'ZERO_NOSALE'=>$ZERO_NOSALE,
		#	);

		&DBINFO::db_user_close();
		}




#	my $udbh =&DBINFO::db_user_connect($USERNAME);
#
#	my @records = ();
#
#	my $reccount = 1;
#	my $rectotal = scalar(@records);
#	$r->progress($reccount,$rectotal,"Loading records");
#
#	my $jobs = &ZTOOLKIT::batchify(\@records,100);
#
#	foreach my $records (@{$jobs}) {
#		foreach my $record (@{$records}) {
#			my @ROW = ();
#
#			push @{$r->{'@BODY'}}, @ROW;
#			$reccount++;
#			#if (($reccount % 100)==0) {
#			#	$r->progress($reccount,$rectotal,"processed record: $reccount");
#			#	}
#			}
#		$r->progress($reccount,$rectotal,"processed record: $reccount");
#		}
#	
#
#	$r->progress($rectotal,$rectotal,"did $reccount/$rectotal records");
#   &DBINFO::db_user_close();

	}




1;

