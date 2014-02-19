#!/usr/bin/perl


use strict;

use UNIVERSAL;
use Class::Runtime;
use lib "/httpd/modules";
use BATCHJOB;
use BATCHJOB::REPORT;
use Data::Dumper;

my %params = ();
foreach my $arg (@ARGV) {
	#if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}

if (($params{'cluster'} eq '') && ($params{'user'} ne '')) {
	$params{'cluster'} = &ZOOVY::resolve_cluster($params{'user'});
	}

if ($params{'verb'} eq '') {
	print "need verb=queue|run|kill|status\n";
	}


if ($params{'verb'} eq 'status') {
	my ($udbh) = &DBINFO::db_user_connect(sprintf("%s",$params{'user'} || $params{'cluster'}));
	my ($redis) = &ZOOVY::getRedis($params{'cluster'},2);
	my $pstmt = "select ID,USERNAME from BATCH_JOBS where STATUS in ('RUNNING');";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($JOBID,$USERNAME) = $sth->fetchrow() ) {
		print "/httpd/modules/batch.pl user=$USERNAME jobid=$JOBID verb=run\n";
		}
	$sth->finish();
	&DBINFO::db_user_close();
	}

if ($params{'verb'} eq 'list') {
	my ($udbh) = &DBINFO::db_user_connect(sprintf("%s",$params{'user'} || $params{'cluster'}));
	my ($redis) = &ZOOVY::getRedis($params{'cluster'},2);
	my ($MID) = &ZOOVY::resolve_mid($params{'user'});
	my $pstmt = "select ID,USERNAME,STATUS from BATCH_JOBS where CREATED_TS>date_sub(now(),interval 5 day) and MID=$MID";
	print "$pstmt\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($JOBID,$USERNAME,$STATUS) = $sth->fetchrow() ) {		
		print "$JOBID\t$USERNAME\t$STATUS\n";
		}
	$sth->finish();
	&DBINFO::db_user_close();
	}

if ($params{'verb'} eq 'kill') {

	my ($udbh) = &DBINFO::db_user_connect(sprintf("%s",$params{'user'} || $params{'cluster'}));
	my ($MID) = &ZOOVY::resolve_mid($params{'user'});
	my ($ID) = int($params{'jobid'});
	my $pstmt = "update BATCH_JOBS set STATUS='END-CRASHED',STATUS_MSG='Killed by Admin' where ID=$ID and MID=$MID";
	print "$pstmt\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	}

if ($params{'verb'} eq 'queue') {
	my $tmpdir = "/tmp";
	if (-d "/local/tmp") { $tmpdir = "/local/tmp"; }

	my ($redis) = &ZOOVY::getRedis($params{'cluster'},2);
	my $pstmt = "select * from BATCH_JOBS where STATUS in ('NEW','HOLD','QUEUED') ";
	if ($params{'user'}) { $pstmt .= " and MID=".&ZOOVY::resolve_mid($params{'user'}); }
	if ($params{'limit'}) { $pstmt .= sprintf(" limit 0,%d",int($params{'limit'})); }
	$pstmt .= " order by ID";
	my $ROWS = &DBINFO::fetch_all_into_hashref($params{'cluster'},$pstmt);

	foreach my $ref (@{$ROWS}) {
		my ($ID) = $ref->{'ID'};
		my ($USERNAME) = $ref->{'USERNAME'};
		
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my ($MID) = $ref->{'MID'};
		my ($EXEC) = $ref->{'BATCH_EXEC'};

		if ($ref->{'STATUS'} eq 'QUEUED') {
			## see if we need to recover from a 'HUNG' state
			if (&ZTOOLKIT::mysql_to_unixtime($ref->{'QUEUED_TS'})<time()-(3600*24)) {
				## after 10 hours a job will queue again
				$ref->{'STATUS'} = 'NEW';
				}
			}

		## LOOK -- RUNNING, ABORTED, QUEUED -- if we have those we can't run anything else.
		$pstmt = "select ID from BATCH_JOBS where MID=$MID /* $USERNAME */ and STATUS in ('RUNNING','ABORTED','QUEUED') order by ID";
		my ($HAS_RUNNING) = $udbh->selectrow_array($pstmt);
		$HAS_RUNNING = int($HAS_RUNNING);

		if ($ref->{'STATUS'} eq 'HOLD') {
			if ($HAS_RUNNING == 0) {
				$ref->{'STATUS'} = 'NEW'; 
				}
			}
		elsif ($HAS_RUNNING>0) {
			$pstmt = "update BATCH_JOBS set STATUS='HOLD',STATUS_MSG='Holding for $HAS_RUNNING' where ID=$ID and MID=$MID";
			print "$pstmt\n";
			$udbh->do($pstmt);
			}

		if ($ref->{'STATUS'} eq 'NEW') {
			## NEW jobs go into a queue
			my $CMD = "/httpd/modules/batch.pl user=$USERNAME verb=run exec=$EXEC jobid=$ID ";
			if (-f '/usr/bin/nice') {
				## making it nice!
				$CMD = "/usr/bin/nice -n 10 $CMD";
				}
			if (-f '/bin/bash') { $ENV{'SHELL'} = '/bin/bash'; } else {  $ENV{'SHELL'} = '/usr/bin/bash'; }

			if ($params{'limit'}) {
				print "!!!!!!!! YOU NEED TO RUN:\n";
				print "$CMD\n"; 
				sleep(10);
				}
			else {
				print "USERNAME $USERNAME has $HAS_RUNNING running/queued jobs\n";
				open H, "|/usr/bin/at -q a now";
		 		print H qq~

/bin/rm -f $tmpdir/job-$ID.txt;
$CMD 1>> $tmpdir/job-$ID.txt 2>&1
if [ "\$?" -eq 0 ]; then
	## 0 = crashed
	/bin/mv $tmpdir/job-$ID.txt $tmpdir/job-$ID.crashed
	/httpd/modules/batch.pl verb=crash user=$USERNAME jobid=$ID
else
	## 1 = success
	/bin/rm -f $tmpdir/job-$ID.txt
fi;
~;
				close H;		
				print "$CMD\n";
				}

			$pstmt = "update BATCH_JOBS set STATUS='QUEUED',QUEUED_TS=now(),STATUS_MSG='Job has been queued.' where ID=$ID and MID=$MID";
			print $pstmt."\n";
			$udbh->do($pstmt);
			}
		&DBINFO::db_user_close();
		}
	}



if ($params{'verb'} eq 'run') {
	## /httpd/modules/batch.pl user=fkaufmann verb=run exec= jobid=400000
	my ($ID) = $params{'jobid'};
	if ($ID==0) { $ID = $params{'id'}; }	
	my ($USERNAME) = $params{'user'};

	print "USERNAME:$USERNAME JOBID:$ID\n";

	my ($BJ) = BATCHJOB->new($USERNAME,$ID);
	#if ($0 =~ /checkjob/) {
	### if we run as checkjob.pl then check the STATUS
	#if ($BJ->{'STATUS'} eq 'QUEUED') {
	#	my ($RUNNING_JOB) = $BJ->queue_locked();
	#	if ($RUNNING_JOB>0) {
	#		$BJ->update('STATUS'=>'ABORT','STATUS_MSG'=>"Aborted due to time-out, running job: $RUNNING_JOB");
	#		die();
	#		}
	#	}
	## if we got here, we're going to run this biatch.
	#}
	$BJ->update('STATUS'=>'RUNNING','STATUS_MSG'=>'...');

	my ($MODULE,$VERB) = $BJ->execverb();
	$MODULE = uc($MODULE);
	$MODULE =~ s/[^A-Z0-9]+//g;
	my $CLASS = 'BATCHJOB::'.$MODULE;

	my ($EXEC,$VERB) = $BJ->execverb();

	my $ERROR = undef;
	my $cl = Class::Runtime->new( class => $CLASS );
	if ( not $cl->load ) {
		warn "Error in loading class $CLASS\n";
		warn "\n\n", $@, "\n\n";	
		$ERROR = $@;	
		## need to eventually add some cleanup code here.
		die();
		}

	my ($status,$statusMsg);
	if (defined $ERROR) {
		($status,$statusMsg) = ('ERROR',$ERROR);
		}
	elsif (($cl->isLoaded) && ($CLASS->can('new'))) {
		## basically this is calling SYNDICATION::DOBA->new() for example
  		my ($bjj) = $CLASS->new($BJ);

		if (ref($bjj) ne $CLASS) {
			## some type of error occurred.
			print "The class for $bjj was not set.\n";
			($status,$statusMsg) = ('ERROR',$bjj);
			$BJ->finish($status,$statusMsg);
			}
		else {
			print "############ ABOUT TO RUN ##########\n";
			$status = undef;
			eval { ($status,$statusMsg) = $bjj->run($BJ); };
			if (not defined $status) { 
				$statusMsg = "status is unknown, setting to ERROR $@";
				$status = 'ERROR'; 
				}
			elsif (ref($status) eq 'LISTING::MSGS') {
				my $LM = $status;
				(my $ref,$status) = $LM->whatsup();
				($status,$statusMsg) = ($ref->{'_'},$ref->{'+'});
				}
			elsif ((ref($status) eq '') && ($status eq 'FINISHED')) {
				## this uses the new LM response format .. so we can skip this.
				$status = 'FINISHED';
				}

			print "############ FINISHED RUN ($status) ##########\n";
			## we don't call finish here because the job will call.
			}
		}
	else {
		($status,$statusMsg) = ('ERROR',"Cannot call method: new on class: $CLASS");
		}

	if ($status ne 'FINISHED') {
		## the previous layer returns "FINISHED" when it calls finish on it's own.
		print "Finish: status=$status statusMsg=$statusMsg\n";
		$BJ->finish($status,$statusMsg);	
		}

	if ($status eq 'ERROR') {
		## failure
		exit 0;
		}
	else {
		## success
		exit 1;
		}
	}


__DATA__

