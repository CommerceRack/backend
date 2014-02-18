#!/usr/bin/perl

##
## Purpose: this program goes through SUPPLIER_ORDERS, locks records and causes dispatches to occur
##

use strict;

use Data::Dumper;
use lib "/httpd/modules";
use Date::Calc qw (Day_of_Week Today Date_to_Days Localtime);
use DBINFO;
use TXLOG;
use strict;
use ORDER;
use ZOOVY;
use CUSTOMER;
use WHOLESALE;
use SUPPLIER;
use ZTOOLKIT;
use LISTING::MSGS;
use ZSHIP;
use TXLOG;
use URI::Split;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP::UserAgent;
use LWP::Simple;
use IO::Scalar;
use JSON::XS;
use XML::LibXSLT;
use XML::LibXML;
use SUPPLIER::JOBS;


##
## option parameters:
##		user
##		supplier
##		mode=unlock|create|close|dispatch|all
##
my %params = ();
foreach my $arg (@ARGV) {
	if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}

my $USERCLUSTER = '';
if ($params{'cluster'}) {
	$USERCLUSTER = $params{'cluster'};
	}
elsif ($params{'user'} ne '') { 
	$USERCLUSTER = &ZOOVY::resolve_cluster($params{'user'});
	}
else {
	die("requires user= or cluster="); 
	}
if ($params{'verb'} eq '') {
	print "verb is required .. try one of the following:\n";
	print "verb=list  show all suppliers\n";
	print "verb=run	run\n";
	print "	process=1 	inventory=1		tracking=1\n";

#	print "verb=debug orderid=xxxx-xx-xxxx supplier=xyz reset=1 unlock=1 nosend=1\n";
#	print "verb=inventory	download inventory\n";
	exit;
	}


my $udbh = &DBINFO::db_user_connect($USERCLUSTER);
my $pstmt = "select ID,USERNAME,CODE from SUPPLIERS where 1=1 ";
if ($params{'user'}) { $pstmt .= " and MID=".&ZOOVY::resolve_mid($params{'user'}); }
if ($params{'supplier'}) { $pstmt .= " and CODE=".$udbh->quote($params{'supplier'}); }

if ($params{'verb'} eq 'todo') {
	$pstmt = "select S.ID as ID,S.USERNAME as USERNAME,S.CODE as CODE from SUPPLIERS S where 1=1 ";
	if ($params{'user'}) { $pstmt .= " and S.MID=".&ZOOVY::resolve_mid($params{'user'}); }
	if ($params{'supplier'}) { $pstmt .= " and S.CODE=".$udbh->quote($params{'supplier'}); }
	$pstmt .= " group by S.MID,S.CODE";
	}


my @SUPPLIERS_TODO = ();
my $ROWS = &DBINFO::fetch_all_into_hashref($USERCLUSTER,$pstmt);
foreach my $hashref ( @{$ROWS} ) {
	my ($ID,$USERNAME,$CODE) = ($hashref->{'ID'}, $hashref->{'USERNAME'}, $hashref->{'CODE'});

	next unless (&ZOOVY::locklocal("supplychain.$USERNAME.$CODE"));
	my $skip = 0;
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $qtVENDOR = $udbh->quote($CODE);
	my $pstmt = "select count(*) from INVENTORY_DETAIL VOI where VOI.BASETYPE='PICK' and VOI.MID=$MID and VOI.VENDOR=$qtVENDOR and VOI.VENDOR_STATUS in ('NEW')";
	my ($exists) = $udbh->selectrow_array($pstmt);
	if (($exists) || ($params{'process'})) {
		push @SUPPLIERS_TODO, [ $ID, $USERNAME, $CODE, 'PROCESS' ] ;
		}

	$pstmt = "select unix_timestamp(INVENTORY_LAST_TS),unix_timestamp(TRACK_LAST_TS) from SUPPLIERS where MID=$MID and ID=$qtVENDOR";
	my ($last_inventory_gmt,$last_tracking_gmt) = $udbh->selectrow_array($pstmt);
	
	if ((($last_inventory_gmt + (86400/4)) < time() ) || ($params{'inventory'})) {
		push @SUPPLIERS_TODO, [ $ID, $USERNAME, $CODE, 'INVENTORY' ];
		}

	if ((($last_tracking_gmt + (86400/4)) < time() ) || ($params{'tracking'})) {
		push @SUPPLIERS_TODO, [ $ID, $USERNAME, $CODE, 'TRACKING' ];
		}

	&DBINFO::db_user_close();
	}
&DBINFO::db_user_close();


if ($params{'verb'} eq 'list') {
	print Dumper(\@SUPPLIERS_TODO);
	die();
	}

if (scalar(@SUPPLIERS_TODO)==0) {
	warn "SUPPLIERS_TODO is zero - no suppliers will be processed\n";
	}

##
##
##
foreach my $set (@SUPPLIERS_TODO) {
	my ($ID,$USERNAME,$VENDOR,$TASK) = @{$set};

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	print "ID:$ID\tUSER:$USERNAME\tCODE:$VENDOR\tTASK:$TASK\n";
	my ($lm) = LISTING::MSGS->new($USERNAME,logfile=>"~/supplier-$VENDOR-%YYYYMM%.log",'stderr'=>($params{'trace'})?1:0);
	$lm->pooshmsg("START|+starting $TASK");

	my ($S) = SUPPLIER->new($USERNAME,$VENDOR);
	next if (not defined $S);	## should probably throw an error

	my $qtVENDOR = $udbh->quote($VENDOR);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	if ($lm->had('ISE')) {
		&ZOOVY::confess($USERNAME,"SUPPLIER $VENDOR had ISE".Dumper($lm),justkidding=>1);
		}
	elsif ($TASK eq 'PROCESS') {
		&SUPPLIER::JOBS::PROCESS($S,$lm,%params);
		}
	elsif ($TASK eq 'INVENTORY') {
		&SUPPLIER::JOBS::INVENTORY($S,$lm,%params);
		my $pstmt = "update SUPPLIERS set INVENTORY_LAST_TS=now() where MID=$MID and ID=".$udbh->quote($S->code());
		$udbh->do($pstmt);	
		}
	elsif ($TASK eq 'TRACKING') {
		&SUPPLIER::JOBS::TRACKING($S,$lm,%params);
		my $pstmt = "update SUPPLIERS set TRACK_LAST_TS=now() where MID=$MID and ID=".$udbh->quote($S->code());
		$udbh->do($pstmt);	
		}

	$lm->pooshmsg("START|+finished $TASK");

	print Dumper($lm);	
	## end of foreach lopo
	&DBINFO::db_user_close();
	}



exit 1;


