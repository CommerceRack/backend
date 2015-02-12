#!/usr/bin/perl

use strict;
use DBI;
use POSIX;
use List::Util 'shuffle';
use lib "/httpd/modules";
use DBINFO;
use NAVCAT;
use NAVCAT::FEED;
use SITE;
use Net::FTP;
use Archive::Zip;
use ZSHIP;
use SYNDICATION;
use LISTING::MSGS;
use Data::Dumper;
use URI::Escape;
use Getopt::Long;
use CFG;


if (my $reason = &ZOOVY::is_not_happytime(avg=>12)) {
	die("Sorry, can't run right now reason:$reason");
	}

##
## parameters can be used in any order, and merely RESTRICT the select statement
##
##		cluster=
##		user=username
##		dst=DST code (GOO,YST,C01) -- hint: look in /httpd/modules/SYNDICATION.pm around line 27
##		type=product|inventory|all
##


my %MERCHANTS = ();
my $ts = time();

my %params = ();
foreach my $arg (@ARGV) {
	#if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}

Getopt::Long::GetOptions(
	"user=s" => \$params{'user'},   
	"type=s" => \$params{'type'},   
	);


my @USERS = (); 
if (not defined $params{'user'}) {
	}
elsif (uc($params{'user'}) eq '_SELF_') {
	}
elsif ($params{'user'}) { 
	push @USERS, $params{'user'}; 
	}

if (scalar(@USERS)==0) {
	@USERS = @{CFG->new()->users()};
	}

print Dumper(\@USERS);

if (not &ZOOVY::locklocal(sprintf("queue.pl"))) {
	die("could not lock local");
	}

if (not defined $params{'type'}) { $params{'type'} = 'ALL'; }
$params{'type'} = uc($params{'type'});	

##
## STAGE1: figure out which SYNDICATION::PROVIDERS need what type of queuing.
##

my @DSTCODES = ();
foreach my $dstcode (keys %SYNDICATION::PROVIDERS) {
	next if ((defined $params{'dst'}) && ($dstcode ne $params{'dst'}));	## dst=ESS !??
	
	if (($params{'type'} ne 'ALL') && ($params{'type'} ne 'PRODUCTS')) {
		}
	elsif ($SYNDICATION::PROVIDERS{$dstcode}->{'send_products'}) {
		push @DSTCODES, [ $dstcode, 'PRODUCTS', $SYNDICATION::PROVIDERS{$dstcode}->{'send_products'} ];
		}

	if (($params{'type'} ne 'ALL') && ($params{'type'} ne 'IMAGES')) {
		}
	elsif ($SYNDICATION::PROVIDERS{$dstcode}->{'send_images'}) {
		push @DSTCODES, [ $dstcode, 'IMAGES', $SYNDICATION::PROVIDERS{$dstcode}->{'send_images'} ];
		}

	if (($params{'type'} ne 'ALL') && ($params{'type'} ne 'ORDERS')) {
		}
	elsif ($SYNDICATION::PROVIDERS{$dstcode}->{'grab_orders'}) {
		push @DSTCODES, [ $dstcode, 'ORDERS', $SYNDICATION::PROVIDERS{$dstcode}->{'grab_orders'} ];
		}

	if (($params{'type'} ne 'ALL') && ($params{'type'} ne 'ORDER_STATUS')) {
		}
	elsif ($SYNDICATION::PROVIDERS{$dstcode}->{'send_orderstatus'}) {
		push @DSTCODES, [ $dstcode, 'ORDERSTATUS', $SYNDICATION::PROVIDERS{$dstcode}->{'send_orderstatus'} ];
		}

	if (($params{'type'} ne 'ALL') && ($params{'type'} ne 'TRACKING')) {
		}
	elsif ($SYNDICATION::PROVIDERS{$dstcode}->{'send_tracking'}) {
		push @DSTCODES, [ $dstcode, 'TRACKING', $SYNDICATION::PROVIDERS{$dstcode}->{'send_tracking'} ];
		}

	if (($params{'type'} ne 'ALL') && ($params{'type'} ne 'INVENTORY')) {
		}
	elsif ($SYNDICATION::PROVIDERS{$dstcode}->{'send_inventory'}) {
		push @DSTCODES, [ $dstcode, 'INVENTORY', $SYNDICATION::PROVIDERS{$dstcode}->{'send_inventory'} ];
		}

	if (($params{'type'} ne 'ALL') && ($params{'type'} ne 'SHIPPING')) {
		}
	elsif ($SYNDICATION::PROVIDERS{$dstcode}->{'send_shipping'}) {
		push @DSTCODES, [ $dstcode, 'SHIPPING', $SYNDICATION::PROVIDERS{$dstcode}->{'send_shipping'} ];
		}

	if (($params{'type'} ne 'ALL') && ($params{'type'} ne 'ACCESSORIES')) {
		}
	elsif ($SYNDICATION::PROVIDERS{$dstcode}->{'send_accessories'}) {
		push @DSTCODES, [ $dstcode, 'ACCESSORIES', $SYNDICATION::PROVIDERS{$dstcode}->{'send_accessories'} ];
		}

	if (($params{'type'} ne 'ALL') && ($params{'type'} ne 'RELATIONS')) {
		}
	elsif ($SYNDICATION::PROVIDERS{$dstcode}->{'send_relations'}) {
		push @DSTCODES, [ $dstcode, 'RELATIONS', $SYNDICATION::PROVIDERS{$dstcode}->{'send_relations'} ];
		}

	if (($params{'type'} ne 'ALL') && ($params{'type'} ne 'PRICING')) {
		}
	elsif ($SYNDICATION::PROVIDERS{$dstcode}->{'send_pricing'}) {
		push @DSTCODES, [ $dstcode, 'PRICING', $SYNDICATION::PROVIDERS{$dstcode}->{'send_pricing'} ];
		}

	if (($params{'type'} ne 'ALL') && ($params{'type'} ne 'FEEDBACK')) {
		}
	elsif ($SYNDICATION::PROVIDERS{$dstcode}->{'send_feedback'}) {
		push @DSTCODES, [ $dstcode, 'FEEDBACK', $SYNDICATION::PROVIDERS{$dstcode}->{'send_feedback'} ];
		}
	}

##
## STAGE2: go through and see which specific user/records have a {TYPE}_NEXTQUEUE_GMT which is older than now
##				add those to @TO_QUEUE
##

my @TO_QUEUE = ();
foreach my $USERNAME (@USERS) {
	my $udbh = &DBINFO::db_user_connect("$USERNAME");

	foreach my $set (shuffle @DSTCODES) {
		print Dumper($USERNAME);
		my ($DSTCODE,$DSTTYPE,$INTERVAL) = @{$set};
		my $pstmt = "select USERNAME,DOMAIN,ID from SYNDICATION where IS_ACTIVE>0 and DSTCODE='$DSTCODE' and ${DSTTYPE}_NEXTQUEUE_GMT<unix_timestamp(now())";
		if ($params{'all'}) {
			$pstmt = "select USERNAME,DOMAIN,ID from SYNDICATION where IS_ACTIVE>0 and DSTCODE='$DSTCODE' ";
			}
		if ($params{'user'}) { $pstmt .= " and USERNAME=".$udbh->quote($params{'user'}); }
		print $pstmt."\n";

		my @ROWS = ();
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $rowref = $sth->fetchrow_hashref() ) {
			push @ROWS, $rowref;
			}
		$sth->finish();

		#my $sth = $udbh->prepare($pstmt);
		#$sth->execute();
		#while ( my ($USERNAME,$DOMAIN,$ID) = $sth->fetchrow() ) {
		foreach my $row (@ROWS) {
			my ($USERNAME,$DOMAIN,$ID) = ($row->{'USERNAME'},$row->{'DOMAIN'},$row->{'ID'});
			my $PRT = -1;
			if (substr($DOMAIN,0,1) eq '#') {
				## we have a PRT defined as "#0" in PROFILE field
				$PRT = int(substr($DOMAIN,1));
				## $PROFILE = &ZOOVY::prt_to_profile($USERNAME,$PRT);
				}
			else {
				## we have a profile defined in the profile field
				## $PRT = &ZOOVY::profile_to_prt($USERNAME,$PROFILE);
				my ($D) = DOMAIN->new($USERNAME,$DOMAIN);
				if (defined $D) { $PRT = $D->prt(); }
				}

			if ($PRT >= 0) {
				push @TO_QUEUE, [ $USERNAME, $DOMAIN, $PRT, $ID, $DSTTYPE, $DSTCODE, $INTERVAL ];
				}
			}
		}
	#$sth->finish();
	}
#print Dumper(\@TO_QUEUE);


##
## STAGE3: go through and send commands to at - which will run them in order, not the order itself is shuffled (random)
##
my $TS = time();
my $i = 0;
foreach my $workloadset (shuffle @TO_QUEUE) {
	print Dumper($workloadset);

	my ($USERNAME,$DOMAIN,$PRT,$DBID,$DSTTYPE,$DSTCODE,$INTERVAL) = @{$workloadset};
	# next if ($DSTCODE eq 'AMZ');

	my $CMD = "/bin/nice -n 10 /httpd/servers/syndication/work.pl user=$USERNAME type=$DSTTYPE dst=$DSTCODE queued=$TS dbid=$DBID";

	## OVERRIDES FOR INDIVIDUAL SPECIALIZED MARKETPLACES
	if (($DSTCODE eq 'SRS') && ($DSTTYPE eq 'TRACKING')) {
		$CMD = "/httpd/servers/sears/orders.pl user=$USERNAME type=tracking prt=$PRT";
		}
	elsif (($DSTCODE eq 'SRS') && ($DSTTYPE eq 'ORDERS')) {
		$CMD = "/httpd/servers/sears/orders.pl user=$USERNAME type=orders prt=$PRT";
		}
	elsif (($DSTCODE eq 'EGG') && ($DSTTYPE eq 'TRACKING')) {
		$CMD = "/httpd/servers/newegg/orders.pl user=$USERNAME type=tracking prt=$PRT";
		}
	elsif (($DSTCODE eq 'EGG') && ($DSTTYPE eq 'ORDERS')) {
		$CMD = "/httpd/servers/newegg/orders.pl user=$USERNAME type=orders prt=$PRT";
		}
	elsif (($DSTCODE eq 'BUY') && ($DSTTYPE eq 'TRACKING')) {
		$CMD = "/httpd/servers/buycom/buyorders.pl user=$USERNAME verb=tracking prt=$PRT dst=$DSTCODE";
		}
	elsif (($DSTCODE eq 'BUY') && ($DSTTYPE eq 'ORDERS')) {
		$CMD = "/httpd/servers/buycom/buyorders.pl user=$USERNAME verb=orders prt=$PRT dst=$DSTCODE";
		}
	elsif (($DSTCODE eq 'BST') && ($DSTTYPE eq 'TRACKING')) {
		$CMD = "/httpd/servers/buycom/buyorders.pl user=$USERNAME verb=tracking prt=$PRT dst=$DSTCODE";
		}
	elsif (($DSTCODE eq 'BST') && ($DSTTYPE eq 'ORDERS')) {
		$CMD = "/httpd/servers/buycom/buyorders.pl user=$USERNAME verb=orders prt=$PRT dst=$DSTCODE";
		}
	elsif (($DSTCODE eq 'EBF') && ($DSTTYPE eq 'ORDERS')) {
		## IT's bad to have two of these running .. so leave the one on app7 for now
#		$CMD = qq~
#		/httpd/servers/ebay/orders.pl user=$USERNAME prt=$PRT dst=EBF type=orders verb=create ; 
#		sleep 90 ; 
#		/httpd/servers/ebay/orders.pl user=$USERNAME prt=$PRT dst=EBF type=orders verb=download ; 
#		~;
#		$CMD = qq~
#		/httpd/servers/ebay/orders.pl user=$USERNAME prt=$PRT verb=create type=orders ;  
#		sleep 30;
#		COUNTER=0; 
#		while [ \$COUNTER -lt 25 ] ; do 
#			/httpd/servers/ebay/orders.pl user=$USERNAME prt=$PRT verb=download type=orders ; 
#			if [ \$? -eq 0 ] ; then 
#				let COUNTER=COUNTER+25; 
#				exit 1;
#			else 
#				let COUNTER=COUNTER+1; 
#				let PAUSE=COUNTER*5;
#				sleep \$PAUSE;
#			fi;  
#			echo \$COUNTER;
#		done;	
#		exit 0;
#		~;
		}
#	elsif (($DSTCODE eq 'HSN') && ($DSTTYPE eq 'TRACKING')) {
#		$CMD = "/httpd/servers/hsn/orders.pl user=$USERNAME type=tracking prt=$PRT";
#		}
#	elsif (($DSTCODE eq 'HSN') && ($DSTTYPE eq 'ORDERS')) {
#		$CMD = "/httpd/servers/hsn/orders.pl user=$USERNAME type=orders prt=$PRT";
#		}
	elsif (($DSTCODE eq 'AMZ') && ($DSTTYPE eq 'INVENTORY')) {
		$CMD = "/httpd/servers/amazon/sync.pl user=$USERNAME docs=20 sync=1";
		}
	elsif (($DSTCODE eq 'AMZ') && ($DSTTYPE eq 'TRACKING')) {
		$CMD = "/httpd/servers/amazon/orders.pl user=$USERNAME prt=$PRT dbid=$DBID verb=track ";
		}
	elsif (($DSTCODE eq 'AMZ') && ($DSTTYPE eq 'ORDERS')) {
		$CMD = "/httpd/servers/amazon/orders.pl user=$USERNAME prt=$PRT dbid=$DBID verb=orders ";
		}
	elsif (($DSTCODE eq 'GOO') && ($DSTTYPE eq 'ORDERSTATUS')) {
		$CMD = "/httpd/servers/googletrustedstores/orders.pl type=orderstatus user=$USERNAME dbid=$DBID prt=$PRT";
		}
	elsif (($DSTCODE eq 'GOO') && ($DSTTYPE eq 'TRACKING')) {
		$CMD = "/httpd/servers/googletrustedstores/orders.pl type=tracking user=$USERNAME dbid=$DBID prt=$PRT";
		}
	$CMD .= " 1>> /tmp/syndication-$USERNAME-$DSTCODE-$DBID-$DSTTYPE.running-debug 2>&1";;

	print "$CMD\n";

	if ($params{'run'}) {
		my $queue = 'D';
		if ($DSTCODE eq 'GOO') { $queue = 'E'; }
		if ($USERNAME eq 'stateofnine') { $queue = 'Z'; }
		if ($DSTTYPE eq 'ORDERS') { $queue = 'B'; }	## order updates should be higher priority than everything else
		if ($DSTTYPE eq 'TRACKING') { $queue = 'D'; }	## tracking updates should have a higher priority than products
		if ($DSTTYPE eq 'INVENTORY') { $queue = 'A'; }	## inventory updates should have a higher priority than products
		## E = EBAY ORDERS

		$ENV{'SHELL'} = "/bin/bash";
		if (&ZOOVY::host_operating_system() eq 'SOLARIS') {
			$ENV{'SHELL'} = '/usr/bin/bash';
			$queue = lc($queue);
			}
		
		# open H, "|/usr/bin/at -q $queue now + $i minutes";
		open H, "|/usr/bin/at -q $queue now";
		print H "rm -f /tmp/syndication-$USERNAME-$DSTCODE-$DBID-$DSTTYPE.running-debug\n";
		print H $CMD."\n";
		print H "if \[ \"\$?\" -eq 0 \]; then\n";
		print H "  echo \"command failed\";\n";
		print H "  /bin/mv /tmp/syndication-$USERNAME-$DSTCODE-$DBID-$DSTTYPE.running-debug /tmp/syndication-$USERNAME-$DSTCODE-$DBID-$DSTTYPE.crashed-debug\n";
		print H "  exit 1;\n";
		print H "else\n";
		print H "  /bin/rm -f /tmp/syndication-$USERNAME-$DSTCODE-$DBID-$DSTTYPE.running-debug\n";
		print H "  exit 0;\n";
		print H "fi\n";
		close H;

		my ($udbh) = &DBINFO::db_user_connect($USERNAME);	
		my $qtUSERNAME = $udbh->quote($USERNAME);
		my $qtDSTCODE = $udbh->quote($DSTCODE);
		my $pstmt = "update SYNDICATION set ${DSTTYPE}_LASTQUEUE_GMT=unix_timestamp(now()),${DSTTYPE}_NEXTQUEUE_GMT=$TS+$INTERVAL where USERNAME=$qtUSERNAME and DSTCODE=$qtDSTCODE and ID=".int($DBID);
		print $pstmt."\n";
		$udbh->do($pstmt);
		&DBINFO::db_user_close();

		my ($lm) = LISTING::MSGS->new("$USERNAME",logfile=>"~/syndication-$DSTCODE-%YYYYMM%.log");
		$lm->pooshmsg("INFO|Queued $DSTTYPE - next queue: ".&ZTOOLKIT::pretty_date($TS+($i*60)+$INTERVAL,2));
		}

	$i++;
	}




