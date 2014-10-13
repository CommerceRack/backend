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


my $ts = time();

my %params = ();
foreach my $arg (@ARGV) {
	#if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}

my @USERS = (); 
if ($params{'user'} ne '') {
	$params{'cluster'} = &ZOOVY::resolve_cluster($params{'user'});
	}

if ($params{'cluster'} eq '') {
	die("cluster= is required!");
	}

if (not &ZOOVY::locklocal(sprintf("queue.pl"))) {
	die("could not lock local");
	}

my @USERS = ();
if ($params{'user'}) { push @USERS, $params{'user'}; }
if (scalar(@USERS)==0) {
	@USERS = @{CFG->new()->users()};
	}

if (not defined $params{'type'}) { $params{'type'} = 'ALL'; }
$params{'type'} = uc($params{'type'});	

##
## STAGE1: figure out which SYNDICATION::PROVIDERS need what type of queuing.
##
my $ts = time();
my @JOBS = ();
foreach my $USERNAME (@USERS) {
	
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select * from SYNDICATION where IS_ACTIVE>0";

	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $row = $sth->fetchrow_hashref() ) {
		my $DSTCODE = $row->{'DSTCODE'};
		my $ID = $row->{'ID'};
		my $DOMAIN = $row->{'DOMAIN'};

		next if ((defined $params{'dst'}) && (uc($params{'dst'}) ne $DSTCODE));
		next if ((defined $params{'dstcode'}) && (uc($params{'dstcode'}) ne $DSTCODE));

		print "ID:$row->{'ID'} $row->{'DSTCODE'} $row->{'DOMAIN'}\n";

		my $PROVIDER = $SYNDICATION::PROVIDERS{$DSTCODE};
		if (not defined $PROVIDER) {
			warn "SYNDICATION::PROVIDERS{$DSTCODE} not found\n";
			next;
			}

		## PRT LOOKUP
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
		## /PRT LOOKUP

		foreach my $TYPE ('PRODUCTS','IMAGES','ORDERS','ORDERSTATUS','TRACKING','INVENTORY','SHIPPING','ACCESSORIES','RELATIONS','PRICING','FEEDBACK') {
			next if ((defined $params{'type'}) && ($params{'type'} ne 'ALL') && (uc($params{'type'}) ne $TYPE));

			my $INTERVAL = '';
			if ($TYPE eq 'ORDERS') {
				$INTERVAL = $PROVIDER->{'grab_orders'};
				}
			else {
				$INTERVAL = $PROVIDER->{sprintf('send_%s',lc($TYPE))};
				}

			my $NEXTQUEUE_GMT = $row->{sprintf("%s_NEXTQUEUE_GMT",$TYPE)};

			my $QUEUE_JOB = 0;
			if (not $INTERVAL) {
				## there is send_products, send_images, etc. on the syndication provider
				}
			elsif ($NEXTQUEUE_GMT > $ts) {
				print sprintf("$TYPE not ready to re-queue (needs %d seconds)\n", $NEXTQUEUE_GMT-$ts);

				if ((defined $params{'type'}) && (uc($params{'type'}) eq $TYPE)) {
					warn "type:$TYPE has overridden these settings\n";
					$QUEUE_JOB++;
					}
				}
			else {
				$QUEUE_JOB++;
				}

			if ($QUEUE_JOB) {
				push @JOBS, [ $USERNAME, $DOMAIN, $PRT, $ID, $TYPE, $DSTCODE, $INTERVAL  ];
				}
			
			}
		}
	$sth->finish();
	&DBINFO::db_user_close();
	}

##
## STAGE2: go through and see which specific user/records have a {TYPE}_NEXTQUEUE_GMT which is older than now
##				add those to @TO_QUEUE
##
print Dumper(\@JOBS)."\n";

#print Dumper(\@TO_QUEUE);


##
## STAGE3: go through and send commands to at - which will run them in order, not the order itself is shuffled (random)
##
my $TS = time();
my $i = 0;
foreach my $workloadset (shuffle @JOBS) {
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
		my @CMDS = ();
		push @CMDS, "rm -f /tmp/syndication-$USERNAME-$DSTCODE-$DBID-$DSTTYPE.running-debug\n";
		push @CMDS, $CMD."\n";
		push @CMDS, "if \[ \"\$?\" -eq 0 \]; then\n";
		push @CMDS, "  echo \"command failed\";\n";
		push @CMDS, "  /bin/mv /tmp/syndication-$USERNAME-$DSTCODE-$DBID-$DSTTYPE.running-debug /tmp/syndication-$USERNAME-$DSTCODE-$DBID-$DSTTYPE.crashed-debug\n";
		push @CMDS, "  exit 1;\n";
		push @CMDS, "else\n";
		push @CMDS, "  /bin/rm -f /tmp/syndication-$USERNAME-$DSTCODE-$DBID-$DSTTYPE.running-debug\n";
		push @CMDS, "  exit 0;\n";
		push @CMDS, "fi\n";
		print join("\n",@CMDS);

		open H, "|/usr/bin/at -q $queue now";
		foreach my $cmd (@CMDS) { print H $cmd; }
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




