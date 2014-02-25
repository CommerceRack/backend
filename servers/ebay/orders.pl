#!/usr/bin/perl


use strict;
use lib "/httpd/modules";
use Data::Dumper;
use Date::Calc;
use Date::Parse;
use XML::Parser;
use XML::Parser::EasyTree;

use lib "/httpd/modules";
use EBAY2;
use TXLOG;
use CART2;
use STUFF2;
use ZTOOLKIT::XMLUTIL;
use XML::LibXML;
use LISTING::LOCK;
use LISTING::MSGS;
use XMLTOOLS;
use LUSER::FILES;
use SYNDICATION;

## L006 - changed to generic CART->guess_taxrate_using_voodoo
## L007 - improved country handling
## L008 - 20091006 - improved option handling.
## L009 - 20091006 - fixes count quantity.
## L010 - 20091006 - fixed country handling issue caused in L007
## L011 - 20091006 - adjusted firstname/lastname
## L012 - 20091006 - mkt fields were being blanked out from L008 issues.
## L013 - 20091006 - added token level locking.
## L014 - 20091009 - ebay item #'s aren't appearing in title.
## L015 - 20091009 - now properly creates orders for items with assemblies.
## L016 - 20091013 - not sure why mktid and mkt were commented out 
## L017 - 20091020 - better handling of assemblies /changed stuff->count(1+2) to stuff->count(1+2+8)
## L018 - 20100706 - seems like we ought to bump the version (made a lot of changes today)
## L019 - 20110218 - new payment method
## L020 - 20110223 - added some event based logging
## L021 - 20110722 - .SKU processing
## L022 - 20111020 - new option support
##		there was a gap to L022 and some new order format were created under that version
## L030 - 20120929 - new order format 
## L051 - 20121008 new queuing options
## L051 - 20121014 - fixed some tax handling issues (mostly in cart2)
$::LMS_APPVER = "L052";


#
# usage:
#	user=buckeyetoolsupply prt=0 redojob=5067877393
#
#
#



##
## user=
##
my %params = ();
foreach my $arg (@ARGV) {
	if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}




if ($params{'queue'}) {
	## TODO
	}

my @TODO = ();
my ($t) = time();

if (defined $params{'.queue'}) {
	#my $udbh = &DBINFO::db_user_connect("\@$params{'cluster'}");
	my $pstmt = "select USERNAME,PRT from EBAY_TOKENS where ERRORS<1000 order by LMS_SOLD_REQGMT";
	my $ROWS = &DBINFO::fetch_all_into_hashref($params{'cluster'},$pstmt);

	#my $sth = $udbh->prepare($pstmt);
	#$sth->execute();
	my $loop = 0;
	# while ( my ($USERNAME,$PRT) = $sth->fetchrow() ) {
	foreach my $row (@{$ROWS}) {
		my ($USERNAME,$PRT) = ($row->{'USERNAME'},$row->{'PRT'});
		# my $CMD = "/httpd/servers/ebay/orders.pl user=$USERNAME prt=$PRT queue=1";
		if ($params{'.queue'}) {
			$ENV{'SHELL'} = '/bin/bash';
			# open H, "|/usr/bin/at -q $queue now + $i minutes";
			my $CMD = "/usr/bin/at -q A now";
			if (&ZOOVY::host_operating_system() eq 'SOLARIS') {
				my $min = ($loop++%30).'min';
				$CMD = "/usr/bin/at -q e now+$min";
				}
			open H, "|$CMD";			
			print H "rm -f /tmp/EBAY-$USERNAME-$PRT.running-debug\n";
			# print H "/httpd/servers/ebay/orders.pl >> /tmp/EBAY-$USERNAME-$PRT.running-debug\n";
			print H "/httpd/servers/ebay/orders.pl user=$USERNAME prt=$PRT verb=create type=orders >> /tmp/EBAY-$USERNAME-$PRT.running-debug\n";
			print H "sleep 30;";
			print H "COUNTER=0; ";
			print H "while [ \$COUNTER -lt 25 ] ; do \n";
			print H "		/httpd/servers/ebay/orders.pl user=$USERNAME prt=$PRT verb=download type=orders >> /tmp/EBAY-$USERNAME-$PRT.running-debug\n";
			print H "		if [ \$? -eq 0 ] ; then \n";
			print H "			let COUNTER=COUNTER+60; \n";
			print H "  			/bin/rm -f /tmp/EBAY-$USERNAME-$PRT.running-debug\n";
			print H "			exit 1;\n";
			print H "		else \n";
			print H "			let COUNTER=COUNTER+1; \n";
			print H "			let PAUSE=COUNTER*5;\n";
			print H "			sleep \$PAUSE;\n";
			print H " 		fi;  \n";
			print H "		echo \$COUNTER;\n";
			print H "  done;	\n";
			print H "  echo \"command failed\";\n";
			print H "  /bin/mv /tmp/EBAY-$USERNAME-$PRT.running-debug /tmp/EBAY-$USERNAME-$PRT.crashed-debug\n";
			print H "  exit 1;\n";
			close H;
			}
		}
	&DBINFO::db_user_close();
	exit;
	}

if ($params{'user'}) {



	my ($USERNAME) = $params{'user'};
	my ($MID) = &ZOOVY::resolve_mid($params{'user'});
	my $PRT = int($params{'prt'});
	my $pstmt = "select * from EBAY_TOKENS where MID=$MID and PRT=$PRT";
	print $pstmt."\n";	
	
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $todoref = $sth->fetchrow_hashref() ) {
		my ($lm) = LISTING::MSGS->new( $todoref->{'USERNAME'}, stderr=>1, logfile=>'~/ebay-%YYYYMM%.log');

		my ($eb2) = EBAY2->new($todoref->{'USERNAME'},PRT=>$todoref->{'PRT'});
		if (not defined $eb2) {
			$lm->pooshmsg("ERROR|+No eBay token for PRT:$PRT");
			}

		$todoref->{'*EB2'} = $eb2;
		$todoref->{'*LM'} = $lm;
		if ($lm->can_proceed()) {
			push @TODO, $todoref;
			}
		}
	$sth->finish();
	&DBINFO::db_user_close();
	}

my $jobType = '';
my $TYPE = $params{'type'};
if ($TYPE eq 'listings') { $jobType = 'ActiveInventoryReport'; }
elsif ($TYPE eq 'orders') { $jobType = 'SoldReport';  }
else {
	die("UNKNOWN type=  (listings|orders)\n");
	}

my $VERB = $params{'verb'};
if ($VERB eq 'jobs') {}
elsif ($VERB eq 'download') {}
elsif ($VERB eq 'create') {}
elsif ($VERB eq 'deleterecurring') {}
else {
	die("UNKNOWN verb=  (jobs|download|create|deleterecurring)");
	}


##
##
##
foreach my $todoref (@TODO) {
	my $eb2 = $todoref->{'*EB2'};
	my $USERNAME = $eb2->username();

	if (not &ZOOVY::locklocal("ebay.$USERNAME","$$")) {
		warn "This application is already running .. cannot proceed.\n";
		next;
		}


	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $lm = $todoref->{'*LM'};
	my $MID = $eb2->mid();
	my $PRT = $eb2->prt();
	my $LF = LUSER::FILES->new($eb2->username(), 'app'=>'EBAY');


	##
	## CREATE JOB CODEs
	##
	if ($VERB eq 'create') {
		my ($jobid,$fileid);
 		my ($xUUID,$xresult) = $eb2->bdesapi('startDownloadJob',{'downloadJobType'=>$jobType},output=>'flat');
		if (not defined $xresult) {
			warn "did not queue a response\n";
			}
		elsif ($xresult->{'.ack'} eq 'Failure') {
			## possible failure reasons
			print "GOT FAILURE $xresult->{'.errorMessage.error.errorId'}\n";
			my $WAITING = 0;

			if ($xresult->{'.errorMessage.error.errorId'} == 7) {
				# '.errorMessage.error.message' => 'Maximum of one job per job-type in non-terminated state is allowed',
				## JobStatus are:
				## 	* Aborted (in/out) The Bulk Data Exchange has been aborted due to the abortJobRequset call.
				##		* Completed (in/out) Processing on the data file or the report has finished.
				##		* Created (in/out) The job ID and file reference ID have been created as a result of the createUploadJobRequest or the startDownloadJobRequest.
				##		* Failed (in/out) The Bulk Data Exchange job has not completed successfully, due to incorrect data format, request errors, or Bulk Data Exchange service errors.
				##		* InProcess (in/out) Processing on the data file or the report has begun.
				##		* Scheduled (in/out) The job has been internally scheduled for processing by the Bulk Data Exchange service.
				my ($xUUID,$xresult) = $eb2->bdesapi('getJobs',{	
					'jobType'=>$jobType,	## SoldReport or ActiveInventoryReport
					'jobStatus$A'=>'Scheduled',
					'jobStatus$B'=>'InProcess',
					#'jobStatus$C'=>'Aborted',
					#'jobStatus$D'=>'Failed',
					'jobStatus$E'=>'Created',
					},output=>'xml');
				# print Dumper($xresult); 	die();
	
				my @DELETEJOBS = ();
				if ($xresult->{'ack'}->[0] eq 'Success') {
					foreach my $jobprofile ( @{$xresult->{'jobProfile'}} ) {
						## so we don't die if the job was created less than an hour ago
						if ($jobprofile->{'jobStatus'}->[0] eq 'Completed') {
							}
						elsif ($jobprofile->{'jobStatus'}->[0]  eq 'Created') {
							if ($eb2->ebt2gmt($jobprofile->{'creationTime'}->[0]) > time()-86400) {
								$WAITING++;
								}
							else {
								push @DELETEJOBS, $jobprofile->{'jobId'}->[0];
								}
							}
						elsif ($jobprofile->{'jobStatus'}->[0] eq 'InProcess') {
							if ($eb2->ebt2gmt($jobprofile->{'startTime'}->[0]) > time()-7200) {
								$WAITING++;
								}
							else {
								push @DELETEJOBS, $jobprofile->{'jobId'}->[0];
								}
							}
						else {
							warn "Unknown jobStatus: $jobprofile->{'jobStatus'}->[0]\n";
							push @DELETEJOBS, $jobprofile->{'jobId'}->[0];
							## print Dumper($jobprofile);
							##die();
							}
						}
					}	
				if (scalar(@DELETEJOBS)>0) {
					foreach my $jobid (@DELETEJOBS) {
						print "ABORTING JOB: $jobid\n";
						my $result = $eb2->bdesapi('abortJob',{'jobId'=>$jobid},output=>'flat');
						print Dumper($result);
						}
					}
				}

			if ($WAITING==0) {
				$VERB = 'deleterecurring';
				}
			else {
				$lm->pooshmsg("SUMMARY-ORDERS|+Found $WAITING pending SoldReport(s)");
				}
			}
		elsif ($xresult->{'.ack'} eq 'Success') {
			#$VAR2 = {
			#	 '.jobId' => '5074278760',
			#	 '.timestamp' => '2012-10-04T08:42:58.394Z',
			#	 '.xmlns' => 'http://www.ebay.com/marketplace/services',
			#	 '.version' => '1.3.0',
			#	 '.ack' => 'Success'
			#  };
			my %vars = ( 'MID'=>$MID, 'USERNAME'=>$eb2->username(), 'PRT'=>$eb2->prt(), '*CREATED_TS'=>'now()' );
			$vars{'JOB_ID'} = $xresult->{'.jobId'};
			$vars{'JOB_TYPE'} = $jobType; # 'SoldReport';
			my $pstmt = &DBINFO::insert($udbh,'EBAY_JOBS',\%vars,verb=>'insert','sql'=>1);
			print $pstmt."\n";
			$udbh->do($pstmt);
			}
		else {
			print "GOT OTHER\n";
			print Dumper($xresult);
			}

		$VERB = 'jobs';
		}



	if ($params{'jobid'}) {
		}
	elsif (($VERB eq 'jobs') || ($VERB eq 'download')) {
		## GETJOBS makes sure we know about all the jobs that eBay has.
		my ($xUUID,$xresult) = $eb2->bdesapi('getJobs',{
			'jobType'=>"$jobType", # SoldReport or ActiveInventoryReport
			'creationTimeFrom'=>$eb2->ebdatetime(time()-(3600*10)),
			'creationTimeTo'=>$eb2->ebdatetime(time()),
			},output=>'xml');
	
		if ($xresult->{'ack'}->[0] eq 'Success') {
			foreach my $jobprofile ( @{$xresult->{'jobProfile'}} ) {
				# print Dumper($jobprofile);
				my $pstmt = "select count(*) from EBAY_JOBS where MID=$MID and PRT=$PRT and JOB_ID=".int($jobprofile->{'jobId'}->[0]);
				# print "$pstmt\n";
				my ($count) = $udbh->selectrow_array($pstmt);
	
				if ($count == 1) {
					}
				elsif ($jobprofile->{'jobStatus'}->[0] eq 'Completed') {
					## check db too see if we've gotten this before
					my %vars = ( 'MID'=>$MID, 'USERNAME'=>$eb2->username(), 'PRT'=>$eb2->prt(), );
					$vars{'*CREATED_TS'} = sprintf("from_unixtime(%d)",$eb2->ebt2gmt($jobprofile->{'creationTime'}->[0])); 
					$vars{'JOB_ID'} = $jobprofile->{'jobId'}->[0];
					if ($jobprofile->{'fileReferenceId'}->[0]>0) { $vars{'JOB_FILEID'} = $jobprofile->{'fileReferenceId'}->[0]; }
					$vars{'JOB_TYPE'} = $jobType; # 'SoldReport';
					my $pstmt = &DBINFO::insert($udbh,'EBAY_JOBS',\%vars,verb=>'insert','sql'=>1);
					print $pstmt."\n";
					$udbh->do($pstmt);
					}
				elsif ($jobprofile->{'jobStatus'}->[0] eq 'InProcess') {
					}
				elsif ($jobprofile->{'jobStatus'}->[0] eq 'Failed') {
					print Dumper($jobprofile);
					}
				elsif ($jobprofile->{'jobStatus'}->[0] eq 'Aborted') {
					print Dumper($jobprofile);
					}
				elsif ($jobprofile->{'jobStatus'}->[0] eq 'Scheduled') {
					print Dumper($jobprofile);
					}
				else {
					$lm->pooshmsg("ISE|+Unknown status $jobType job#$jobprofile->{'jobId'}->[0] $jobprofile->{'jobStatus'}->[0]");
					}
				}
			}
		else {
			&ZOOVY::confess($USERNAME,"EBAY FAILED");
			}
		}


	my $PENDING_JOB_COUNT = 0;
	my @JOBS = ();
	my $pstmt = "select ID,JOB_ID,JOB_TYPE,JOB_FILEID,CREATED_TS,DOWNLOADED_TS from EBAY_JOBS where MID=$MID and PRT=$PRT ";
	if ($params{'jobid'}>0) {
		$pstmt .= " and JOB_ID=".int($params{'jobid'}); 
		}
	elsif ($VERB eq 'jobs') {
		$pstmt .= " order by ID desc limit 0,250";
		}
	else {
		$pstmt .= " and DOWNLOADED_TS=0 order by CREATED_TS desc";
		}
	print "$pstmt\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my %I_HAS = ();
	while ( my ($ID,$JOBID,$JOBTYPE,$JOBFILEID,$CREATED_TS,$DOWNLOADED_TS) = $sth->fetchrow() ) {
		
		if ($JOBFILEID == 0) {
			my ($xUUID,$xresult) = $eb2->bdesapi('getJobStatus',{'jobId'=>$JOBID},output=>'flat');
			if ($xresult->{'.jobProfile.fileReferenceId'}>0) {
				$JOBFILEID = $xresult->{'.jobProfile.fileReferenceId'};		
				$pstmt = "update EBAY_JOBS set JOB_FILEID=".$udbh->quote($JOBFILEID)." where MID=$MID and ID=$ID";
				print "$pstmt /* CREATED_TS: $CREATED_TS */\n";
				$udbh->do($pstmt);
				}
				
                        if ($xresult->{'.jobProfile.jobStatus'} eq 'Failed') {
                           }
                        elsif ($JOBTYPE eq $jobType ) { 
                           $PENDING_JOB_COUNT++; 
                           }
			}

		if (($JOBFILEID>0) || ($VERB eq 'jobs')) {
			push @JOBS, [ $ID, $JOBID, $JOBTYPE, $JOBFILEID, $CREATED_TS, $DOWNLOADED_TS ];
			if (&ZTOOLKIT::mysql_to_unixtime($DOWNLOADED_TS)==0) {
				## on eBay - we only process one of each JOBTYPE
				if (defined $I_HAS{$JOBTYPE}) {
					$DOWNLOADED_TS = 1;
					$pstmt = "update EBAY_JOBS set DOWNLOADED_TS=1 where ID=$ID";
					print $pstmt."\n";
					$udbh->do($pstmt);
					pop @JOBS;
					}
				$I_HAS{$JOBTYPE} = $JOBID;
				}
			}


		}
	$sth->finish();
	
	if ($VERB eq 'jobs') {
		foreach my $jobref (@JOBS) {
			my ($ID,$JOBID,$JOBTYPE,$JOBFILEID,$CREATED_TS,$DOWNLOADED_TS) = @{$jobref};
			$JOBTYPE = sprintf("%25s",$JOBTYPE);
			print "$ID\t$JOBID\t$JOBTYPE\t$JOBFILEID\t$CREATED_TS\t$DOWNLOADED_TS\n";
			}
		next;
		}


	if ($VERB eq 'download') {
		my $SUCCESS = 0;
		my $qtAPP = $udbh->quote($::LMS_APPVER);		## just a handy way of reprocessing if we need to
		foreach my $waitref (@JOBS) {
			my ($DBID,$JOBID,$JOBTYPE,$JOBFILEID,$CREATED_TS) = @{$waitref};
			my $FILENAME = "EBAY-$USERNAME-$PRT-$JOBID-$JOBFILEID.xml";
	
			my ($ERROR,$xml) = $eb2->ftsdownload($JOBID,$JOBFILEID);
			if ($xml ne '') {
				open F, ">/tmp/$FILENAME";
				print F $xml;
				close F;
				$LF->add(file=>"/tmp/$FILENAME",type=>"SYNDICATION",overwrite=>1,'createdby'=>'eBay',expires_gmt=>time()+(86400*90));
				$lm->pooshmsg("INFO|+Stored $jobType Job#$JOBID as File:$FILENAME");

				if ($JOBTYPE eq 'SoldReport') {
					&processOrders($eb2,$JOBID,$CREATED_TS,$lm,$xml,\%params);
					}
				elsif ($JOBTYPE eq 'ActiveInventoryReport') {
					&processListings($eb2,$JOBID,$CREATED_TS,$lm,$xml,\%params);
					}
				else {
					&ZOOVY::confess($USERNAME,"EBAY UNKNOWN JOBTYPE: $JOBTYPE");
					}
			
				if ($lm->has_win()) {
					$pstmt = "update EBAY_JOBS set DOWNLOADED_APP=$qtAPP,DOWNLOADED_TS=now(),FILENAME=".$udbh->quote($FILENAME)." where MID=$MID and ID=$DBID";
					print "$pstmt\n";
					$udbh->do($pstmt);
					unlink("/tmp/$FILENAME");
					}
				else {
					&ZOOVY::confess($USERNAME,"EBAY NON-WIN ".Dumper($lm));
					}
				}
			else {
				$lm->pooshmsg("WARN|+FILE: $FILENAME was empty (it's fairly common for ths to happen)");
				}
			}

		if ($lm->has_win()) {
			$pstmt = "update EBAY_TOKENS set ERRORS=0,LMS_SOLD_REQGMT=".time()." where MID=$MID and PRT=$PRT";
			print "$pstmt\n";
			$udbh->do($pstmt);
			}
		}




	if ($VERB eq 'deleterecurring') {
		my ($xUUID,$xresult) = $eb2->bdesapi('getRecurringJobs',{},output=>'xml');
		if ($xresult->{'ack'}->[0] eq 'Success') {
			foreach my $jobprofile ( @{$xresult->{'recurringJobDetail'}} ) {
				my ($jobType,$deleteJob) = (undef,0);
				if ($jobprofile->{'jobStatus'}->[0] ne 'Active') {
					## ignore?
					}
				elsif ($jobprofile->{'downloadJobType'}->[0] eq 'SoldReport') {
					($jobType,$deleteJob) = ($jobprofile->{'downloadJobType'}->[0],$jobprofile->{'recurringJobId'}->[0]);
					}
				elsif ($jobprofile->{'downloadJobType'}->[0] eq 'ActiveInventoryReport') {
					($jobType,$deleteJob) = ($jobprofile->{'downloadJobType'}->[0],$jobprofile->{'recurringJobId'}->[0]);
					}

				if ($deleteJob) {
					my $result = $eb2->bdesapi('deleteRecurringJob',{'recurringJobId'=>$deleteJob},output=>'flat');
					}
				}
			## at this point all relevant recurring jobs should be deleted.
			}
		}


        my $EXIT = $PENDING_JOB_COUNT;
        # $EXIT = 0;
        print "EXIT:$EXIT\n"; 
	exit($EXIT);
	}



#########################################################################################################
##
##
##
##
##
##
##
sub processListings {
	my ($eb2,$EBAY_JOBID,$CREATED_TS,$lm,$xml,$paramsref) = @_;

	my ($USERNAME) = $eb2->username();
	my ($udbh) = &DBINFO::db_user_connect($eb2->username());
	my ($MID) = $eb2->mid();
	my $PRT= $eb2->prt();

	## ANYTHING WHICH HAS CHANGED OR BEEN MODIFIED SINCE THE JOB WAS CREATED IS OFF LIMITS
	my $IGNORE_AFTER_GMT = &ZTOOLKIT::mysql_to_unixtime($CREATED_TS);

	my $NOW_TS = time();
	my @SKUDETAIL = ();
	my $parser = XML::LibXML->new();
	my $tree = $parser->parse_string($xml);
	my $root = $tree->getDocumentElement;
	my @details = $root->getElementsByTagName('SKUDetails');
	foreach my $detail (@details) {
		my $xml = $detail->toString();
		my ($skux) = XML::Simple::XMLin($xml,ForceArray=>1);
		my $skuref = &ZTOOLKIT::XMLUTIL::SXMLflatten($skux);
		if ($skuref->{'.SKU'} ne '') {
			push @SKUDETAIL, $skuref;
			}
		else {
			$lm->pooshmsg("WARN|+Listing $skuref->{'.ItemID'} (on eBay) has no SKU");
			}
		}

	my $GOT_DATA = ($xml ne '')?1:0;



	my %ACTIVE_LISTINGS = ();
	my @RESULTS = ();

	if ($GOT_DATA) {
		## SANITY: get a list of all active listings in our database
		# [0] = items remain
		# [1] = created date
		# [2] = quantity
		# [3] = sku
		# [4] = db uuid

		## KEY = ebayid
		##	VALUE = array 0=ITEMS REMAIN, 1=created_gmt, 2=confirmed, exists on ebay 3=SKU, 4=dbid
		my $pstmt = "select EBAY_ID,ITEMS_REMAIN,CREATED_GMT,PRODUCT,ID from EBAY_LISTINGS where MID=$MID and PRT=$PRT and IS_ENDED=0 and EBAY_ID>0";
		print $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($EBAY_ID,$ITEMS_REMAIN,$CREATED_GMT,$SKU,$DBID) = $sth->fetchrow() ) {
			## the 0 in column 2 is "exists on ebay"

			if ($EBAY_ID == 0) {
				$lm->pooshmsg("WARN|+SKU:$SKU DBID:$DBID HAS NO EBAY_ID");
				}
			elsif ($CREATED_GMT > $IGNORE_AFTER_GMT) {
				$lm->pooshmsg("WARN|+SKU:$SKU DBID:$DBID WAS CREATED($CREATED_GMT) AFTER($IGNORE_AFTER_GMT)");
				}
			else {
				$ACTIVE_LISTINGS{$EBAY_ID} = [ $ITEMS_REMAIN, $CREATED_GMT, 0, $SKU, $DBID ];
				}
			}
		$sth->finish();

		my %END_ME = %ACTIVE_LISTINGS;
		foreach my $SKUREF (@SKUDETAIL) {
			my $EBAYID = $SKUREF->{'.ItemID'};
			delete $END_ME{$EBAYID};
			}

		foreach my $key (keys %END_ME) {
			print "KEY: $key IS_ENDED=0 but isn't on eBay\n";
			$pstmt = "update EBAY_LISTINGS set IS_ENDED=1 where EBAY_ID=$key\n"; 
			print "$pstmt\n";
			$udbh->do($pstmt);
			delete $ACTIVE_LISTINGS{$key};
			}
		}

	if ($GOT_DATA) {
		foreach my $SKUREF (@SKUDETAIL) {
			#$VAR1 = {
			#	 '.Quantity' => '4',
			#	 '.SKU' => 'DS_GREASE',
			#	 '.Price.content' => '29.99',
			#	 '.ItemID' => '280594712305',
			#	 '.Price.currencyID' => 'USD'
			#  };
			
			my $EBAYID = $SKUREF->{'.ItemID'};

			if (not defined $ACTIVE_LISTINGS{$EBAYID}) {
				## Listing on eBay that we don't have in the database
				warn "SKU: $SKUREF->{'.SKU'} EBAYID: $EBAYID exists on eBay, but not in database\n";
				my $pstmt = "select count(*) from EBAY_LISTINGS where MID=$MID and PRT=$PRT and EBAY_ID=".int($EBAYID);
				my ($count) = $udbh->selectrow_array($pstmt);
				print "$pstmt $count\n";

				if ($SKUREF->{'.SKU'} eq '') {
					warn "EBAYID: $EBAYID has no SKU\n";
					}
				elsif ($count==0) {
					warn "Importing listing $EBAYID [$count]\n";
					my ($pstmt) = &DBINFO::insert($udbh,'EBAY_LISTINGS',{
						'MERCHANT'=>$USERNAME,
						'MID'=>$MID,
						'PRT'=>$PRT,
						'CHANNEL'=>-10,
						'IS_GTC'=>1,
						'PRODUCT'=>$SKUREF->{'.SKU'},	
						'ITEMS_SOLD'=>0,
						'QUANTITY'=>$SKUREF->{'.Quantity'},
						'ITEMS_REMAIN'=>$SKUREF->{'.Quantity'},
						'EBAY_ID'=>$EBAYID,
						'BIDPRICE'=>$SKUREF->{'.Price.content'},
						'RESULT'=>'Imported',
						},sql=>1);
					print $pstmt."\n";
					$udbh->do($pstmt);
					my ($UUID) = &DBINFO::last_insert_id($udbh);
					$ACTIVE_LISTINGS{$EBAYID} = [ $SKUREF->{'.Quantity'}, 0, 1, $SKUREF->{'.SKU'}, $UUID ];
					}
				elsif ($count>0) {
					warn "Resurrecting $EBAYID\n";
					$pstmt = "update EBAY_LISTINGS set IS_ENDED=0,EXPIRES_GMT=0,IS_GTC=1,ENDS_GMT=0,RESULT='Resurrected' where MID=$MID and PRT=$PRT and EBAY_ID=".$udbh->quote($EBAYID);
					print $pstmt."\n";
					$udbh->do($pstmt);
					$ACTIVE_LISTINGS{$EBAYID} = [ $SKUREF->{'.Quantity'}, 0, 1, $SKUREF->{'.SKU'} ];
					}
					
				}
			elsif ($ACTIVE_LISTINGS{$EBAYID}->[0] != $SKUREF->{'.Quantity'}) {
				warn "EBAYID: $EBAYID has different quantities ebay=[$SKUREF->{'.Quantity'}] zoovy=[$ACTIVE_LISTINGS{$EBAYID}->[0]]\n";
				}
				
			if ($SKUREF->{'.SKU'} ne $ACTIVE_LISTINGS{$EBAYID}->[3]) {
				print "$EBAYID is $SKUREF->{'.SKU'} should be $ACTIVE_LISTINGS{$EBAYID}->[3]\n";
				my ($LISTINGID) = $udbh->selectrow_array("select DISPATCHID from EBAY_LISTINGS where EBAY_ID=$EBAYID");
				print "update LISTING_EVENTS set SKU='$SKUREF->{'.SKU'}',PRODUCT='$SKUREF->{'.SKU'}' where ID=$LISTINGID\n";
				print "update EBAY_LISTINGS set PRODUCT='$SKUREF->{'.SKU'}' where EBAY_ID=$EBAYID\n";
				}
			$ACTIVE_LISTINGS{$EBAYID}->[2]++;
			}
		}


	$GOT_DATA = 0;
	$lm->pooshmsg("SUCCESS|+Finished listing sync");

	if ($GOT_DATA) {
		## END LISTINGS (NOT READY FOR PRIME-TIME)
		foreach my $EBAYID (keys %ACTIVE_LISTINGS) {
			next if ($EBAYID eq '');
			my $SKU = $ACTIVE_LISTINGS{$EBAYID}->[3];


			#my ($inv) = INVENTORY::fetch_incremental($USERNAME,$SKU);
			#if ((defined $params{'inv'}) && ($params{'inv'}==0)) { $inv = 9999; } 
			my ($AVAILABLE) = INVENTORY2->new($USERNAME,"*EBAY")->summary('SKU'=>$SKU,'SKU/VALUE'=>'AVAILABLE');

			#if (($USERNAME eq 'kcint') && ($inv < 9999)) {
			#	warn "SKU: $SKU has <9999 inventory, so we're going to pull it down\n";
			#	my ($prodref) = &ZOOVY::fetchproduct_as_hashref($USERNAME,$SKU);
			#	$prodref->{'ebay:ts'} = 0;
			#	&ZOOVY::saveproduct_from_hashref($USERNAME,$SKU,$prodref);
			#	}

			if (not $ACTIVE_LISTINGS{$EBAYID}->[4]) {
				warn "EBAYID: $EBAYID .. hmmm, can't remove what we don't have! (EBAYID not in \$ACTIVE_LISTINGS)\n";
				}
			elsif ((defined $AVAILABLE) && ($AVAILABLE <= 0)) {
				warn "SKU: $SKU has $AVAILABLE inventory (removing) EBAYID:$EBAYID UUID:$ACTIVE_LISTINGS{$EBAYID}->[4] ";
				$lm->pooshmsg("INFO|+Created END event for EBAYID: $EBAYID (inv:$AVAILABLE)");
				require LISTING::EVENT;
				my ($le) = LISTING::EVENT->new(
					'USERNAME'=>$USERNAME,
					'PRT'=>$PRT,
					'SKU'=>$SKU,
					'VERB'=>'END',
					'TARGET'=>'EBAY',
					'TARGET_LISTINGID'=>$EBAYID,
					'TARGET_UUID'=>$ACTIVE_LISTINGS{$EBAYID}->[4], # dbid is our UUID
					'REQUEST_APP'=>'EBMONITOR',
					);
				$le->dispatch();	
				}
			elsif ($ACTIVE_LISTINGS{$EBAYID}->[1]>$NOW_TS-86400) {
				warn "SKU: $SKU EBAYID: $EBAYID was created in the last 86400 seconds, so we can't end it. (ebay file might not be up to date)\n";
				}
			elsif ($ACTIVE_LISTINGS{$EBAYID}->[2]==0) {
				## this is the infamous error=55
				warn "EBAYID: $EBAYID exists in database, but not on eBay\n";
				my $pstmt = "update EBAY_LISTINGS set IS_ENDED=if(IS_ENDED>0,IS_ENDED,55) where MID=$MID and PRT=$PRT and EBAY_ID=".$udbh->quote($EBAYID);
				print $pstmt."\n";
				$udbh->do($pstmt);
				$lm->pooshmsg("INFO|+Setting EBAYID:$EBAYID to IS_ENDED=55 [not in file]");
				}
			}
	
		my %ACTIVE_PRODUCTS = ();
		foreach my $EBAYID (sort keys %ACTIVE_LISTINGS) {
			my $SKU = $ACTIVE_LISTINGS{$EBAYID}->[3];
			next if ($SKU eq '');

			if (defined $ACTIVE_PRODUCTS{ $SKU }) {
				## duplicates
				print "SKU: $SKU is duplicated in eBayID: $ACTIVE_PRODUCTS{$SKU} - but also: $EBAYID\n";
				print Dumper($ACTIVE_LISTINGS{$EBAYID},$ACTIVE_LISTINGS{$ACTIVE_PRODUCTS{$SKU}});
				require LISTING::EVENT;
				my ($le) = LISTING::EVENT->new(
					'USERNAME'=>$USERNAME,
					'PRT'=>$PRT,
					'SKU'=>$SKU,
					'VERB'=>'END',
					'TARGET'=>'EBAY',
					'TARGET_LISTINGID'=>$EBAYID,
					'TARGET_UUID'=>$ACTIVE_LISTINGS{$EBAYID}->[4], # dbid is our UUID
					'REQUEST_APP'=>'EBMONITOR',
					);
				$le->dispatch();
				}
			else {
				$ACTIVE_PRODUCTS{ $SKU } = $EBAYID;
				}
			}

		## SANITY: now update any in our database that ebay still has as active
		}

	&DBINFO::db_user_close();
	return();
	}





################################################################################################################
##
##
##
##
sub processOrders {
	my ($eb2,$EBAY_JOBID,$CREATED_TS,$lm,$xml,$paramsref) = @_;

	my ($USERNAME) = $eb2->username();
	my ($MID) = $eb2->mid();


	my @XMLORDERS = ();
	my @ORDERACKS = ();

	# print "Why yes please, that would be wonderful!!\n";
	my $parser = XML::LibXML->new();
	my $tree = $parser->parse_string($xml);
	my $root = $tree->getDocumentElement;
	my @details = $root->getElementsByTagName('OrderDetails');
	foreach my $detail (@details) {
		push @XMLORDERS, $detail->toString();
		}


	if (not &ZOOVY::locklocal("ebay.$USERNAME","$$")) {
		$lm->pooshmsg("STOP|+Could not obtain opportunistic lock");
		@XMLORDERS = ();
		}
	

	#if (not &DBINFO::task_lock($USERNAME,"ebay-orders",(($params{'unlock'})?"PICKLOCK":"LOCK"))) {
	#	$lm->pooshmsg("STOP|+Could not obtain opportunistic lock");
	#	@XMLORDERS = ();
	#	}

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	foreach my $xml (@XMLORDERS) {
		my ($olm) = LISTING::MSGS->new($USERNAME,'stderr'=>1);

		my @CLAIMS = ();
		my $RESULT = ''; 	## WARN|GOOD|FAIL

		my ($ord) = XML::Simple::XMLin($xml,ForceArray=>1);
		my $ebordref = &ZTOOLKIT::XMLUTIL::SXMLflatten($ord);

	
		my $EBAY_ORDERID = $ebordref->{'.OrderID'};

		# next if ((defined $paramsref->{'ebayid'}) && ($ebordref->{'.OrderItemDetails.OrderLineItem.ItemID'} ne $paramsref->{'ebayid'}));
		next if ((defined $paramsref->{'ebayid'}) && ($xml !~ /$paramsref->{'ebayid'}/));
		next if ((defined $paramsref->{'ebayoid'}) && ($EBAY_ORDERID ne $paramsref->{'ebayoid'}));
		# print "FOUND: $ebordref->{'.OrderItemDetails.OrderLineItem.ItemID'}\n";

		##
		## NOTE: I really need to rewrite this to use erefid instead of a separate table (this predates erefid)
		##			

		## WAIT: do not ack (this will close eventually)
		## SKIP: this order is not somethin we will process
		## STOP: we've already done this, (this will be acked)
		
		my $EBAY_PAID_GMT = 0;
		if (defined $ebordref->{'.PaymentClearedTime'}) {
			$EBAY_PAID_GMT = $eb2->ebt2gmt($ebordref->{'.PaymentClearedTime'});
			}

		my $SHIPPED_GMT = 0;
		my $pstmt = "select OUR_ORDERID from EBAY_ORDERS where MID=$MID /* $USERNAME */ and EBAY_ORDERID=".$udbh->quote($EBAY_ORDERID);
		my ($OUR_ORDERID) = $udbh->selectrow_array($pstmt);

		my $O2 = undef;
		if ($EBAY_PAID_GMT==0) {
			$olm->pooshmsg(sprintf("WAIT|+eBay #:$EBAY_ORDERID -- we will not process non-paid orders"));
			}
		elsif ($eb2->get('IGNORE_ORDERS_BEFORE_GMT') > $EBAY_PAID_GMT) {
			## this is to help new users, so we can set a time when order processing started.
			$olm->pooshmsg(sprintf("SKIP|+IGNORE_ORDERS_BEFORE_GMT:%d PAID_GMT:%d\n",$eb2->get('IGNORE_ORDERS_BEFORE_GMT'),$EBAY_PAID_GMT));
			}
		elsif ($OUR_ORDERID) {
			if (not $paramsref->{'fix_corrupt'}) {
				$olm->pooshmsg("STOP|+We already have eBay Order#:$EBAY_ORDERID => Our #:$OUR_ORDERID");
				}
			else {
				($O2) = CART2->new_from_oid($USERNAME,$OUR_ORDERID);
				if ((not defined $O2) && ($paramsref->{'fix_corrupt'})) {
					$olm->pooshmsg("WARN|+running 'fix_corrupt' code on ORDER:$EBAY_ORDERID");
					$pstmt = "delete from EBAY_ORDERS where MID=$MID /* $USERNAME */ and EBAY_ORDERID=".$udbh->quote($EBAY_ORDERID);
					print $pstmt."\n";
					$udbh->do($pstmt);
					$O2 = CART2->new_memory($USERNAME);
					}
				}
			}
		else {
			($O2) = CART2->new_memory($USERNAME,$eb2->prt());			
			}

		## SANITY: at this point $O2 is set, or $olm is set to error


		if (not $olm->can_proceed()) {
			}
		elsif ((not defined $O2) || (ref($O2) ne 'CART2')) {
			$olm->pooshmsg(sprintf("ISE|+COULD NOT INSTANTIATE O2 OBJECT - CANNOT PROCEED ORDER: %s EBAY:%s",$EBAY_ORDERID,$OUR_ORDERID));
			}
		elsif ($paramsref->{'fix_corrupt'}) {
			## special debug parameter
			}
		elsif ($O2->order_dbid()>0) {
			## CHECK FOR DUPLICATE ORDERS WE'VE ALREADY GOT
			## if they are shipped and paid we can ack them.
			$olm->pooshmsg(sprintf("WAIT|+ORDER: %s is already in db as %s",$EBAY_ORDERID,$OUR_ORDERID));

			if (($O2->in_get('flow/shipped_ts')>0) && ($O2->in_get('flow/paid_ts')>0)) {
				}
			if ($O2->in_get('flow/paid_ts')>0) {
				$olm->pooshmsg("STOP|+ORDER:$OUR_ORDERID is already existing+paid");
				}
			}

		if (not $olm->can_proceed()) {
			## nothing to do here.
			}
		else {
			## unprocessed order
			$O2->in_set('flow/paid_ts',$eb2->ebt2gmt($ebordref->{'.PaymentClearedTime'}));
			# '.OrderID' => '190336372311-367621280009',
			$O2->in_set('mkt/erefid', $EBAY_ORDERID);
			if ($EBAY_ORDERID eq '') {
				$lm->pooshmsg("SKIP|+EBAY ORDERID IS NOT SET (WTF)?");
				}
			}


		my $UNPAID_ITEMS = undef;
		if ($olm->can_proceed()) {
			my $ITEM_TOTALS = 0;

			# '.PaymentClearedTime' => '2009-10-05T01:32:10.000Z',
			$UNPAID_ITEMS = 0;

			##
			## Iterate through the items, and create claims, and add to cart (if appropriate)
			##
			my $ORDER_ITEM_LINES = 0;		## the number of line items in the order (for verification later)

			## PHASE1: pre-chew the items a bit.
			foreach my $item (@{$ord->{'OrderItemDetails'}->[0]->{'OrderLineItem'}}) {	
				#print Dumper($item);
				$ORDER_ITEM_LINES++;
				my $ilm = LISTING::MSGS->new($USERNAME,'stderr'=>1);
				my $ebitemref = &ZTOOLKIT::XMLUTIL::SXMLflatten($item);
	
				my $SKU = $ebitemref->{'.SKU'};
				if (defined $ebitemref->{'.Variation.SKU'}) {
					## .SKU is what we use for inventory, so we overwrite that with .Variation.SKU if it's avialable.
					$SKU = $ebitemref->{'.Variation.SKU'};
					}
				
				my $EBAYID = $ebitemref->{'.ItemID'};
	
				## we compute $ITEM_TOTALS for sales tax later (if we need it)
				## strip commas from sale price.
				$ebitemref->{'.SalePrice.content'} =~ s/[^\d\.]+//gs; 
				$ebitemref->{'.SalePrice.content'} = sprintf("%.2f",$ebitemref->{'.SalePrice.content'});
				$ITEM_TOTALS += $ebitemref->{'.SalePrice.content'};

				if ((defined $ebitemref->{'.PaymentClearedTime'}) && ($ebitemref->{'.PaymentClearedTime'} ne '')) {
					my $THIS_PAID_GMT = $eb2->ebt2gmt($ebitemref->{'.PaymentClearedTime'});
					if ($THIS_PAID_GMT>$O2->in_get('flow/paid_ts')) { $O2->in_set('flow/paid_ts',$THIS_PAID_GMT); }
					}
				elsif ($O2->in_get('flow/paid_ts')>0) {
					## this was already paid at the order level (not the item level)
					}
				else {
					$ilm->pooshmsg("WAIT|+EBAYID:$EBAYID is not paid $ebitemref->{'.PaymentClearedTime'}");
					$UNPAID_ITEMS++;
					}

				$pstmt = "select ID,CHANNEL,TITLE from EBAY_LISTINGS where MID=$MID and EBAY_ID=".int($EBAYID);
				print STDERR "$pstmt\n";
				my ($UUID,$CHANNEL,$TITLE) = $udbh->selectrow_array($pstmt);

				## DO NOT PULL SKU FROM DATABASE SINCE IT WILL BE *PRODUCT* not SKU
				##	AND WILL FUCK UP OPTIONS

				if (not $ilm->can_proceed()) {
					}
				elsif ($UUID==0) {
					## hmm.. okay so we don't have it in our database, but that could mean it was a second chance offer
					my ($getitemresult) = $eb2->GetItem($ebitemref->{'.ItemID'});
					if (int($getitemresult->{'.Item.ListingDetails.SecondChanceOriginalItemID'})>0) {
						$ebitemref->{'_IS_SECONDCHANCE_FOR_ITEM'} = int($getitemresult->{'.Item.ListingDetails.SecondChanceOriginalItemID'});
						$pstmt = "/* SECOND CHANCE */ select ID,CHANNEL,TITLE from EBAY_LISTINGS where MID=$MID and EBAY_ID=".int($getitemresult->{'.Item.ListingDetails.SecondChanceOriginalItemID'});
						print STDERR $pstmt."\n";
						($UUID,$CHANNEL,$TITLE) = $udbh->selectrow_array($pstmt);
						$lm->pooshmsg(sprintf("INFO|+eBay item %s is a second chance of item:%s uuid:%d",
							$ebitemref->{'.ItemID'},$ebitemref->{'_IS_SECONDCHANCE_FOR_ITEM'},$UUID));
						}
					else {
						$lm->pooshmsg(sprintf("INFO|+eBay item %s is NOT a second chance offer.",$ebitemref->{'.ItemID'}));
						}
	
					if (($TITLE eq '') && ($getitemresult->{'.Item.Title'} ne '')) {
						$TITLE = $getitemresult->{'.Item.Title'};
						}
					}

				if (not defined $UUID) {
					($UUID,$CHANNEL,$TITLE) = (0,0,,"EBAY ITEM $EBAYID NOT IN DATABASE");
					}

				my ($P) = undef;
				if (not $ilm->can_proceed()) {
					}
				elsif ($UUID>0) {
					## best case scenario, we'll use .SKU from eBay, and title+channel from zoovy db.
					$ebitemref->{'_TITLE'} = $TITLE;
					$ebitemref->{'_UUID'} = $UUID;
					$ebitemref->{'_CHANNEL'} = $CHANNEL;
					}
				elsif (($SKU ne '') && (&ZOOVY::productidexists($USERNAME,$SKU))) {
					## workable scenario, not our listing (or we don't know about it) but at least we can figure out title.
					# ($P) = PRODUCT->new($USERNAME,$ebitemref->{'.SKU'});
					($P) = PRODUCT->new($USERNAME,$SKU);
					# my ($prodref) = &ZOOVY::fetchsku_as_hashref($USERNAME,$ebitemref->{'.SKU'});
					if (not defined $ebitemref->{'_TITLE'}) {
						$ebitemref->{'_TITLE'} = $P->skufetch($SKU,'zoovy:prod_name'); # $prodref->{'zoovy:prod_name'};
						}
					$ebitemref->{'_UUID'} = 0;
					}
				elsif ($eb2->{'DO_IMPORT_LISTINGS'}>0) {
					## SANITY: the next few lines ensure that _TITLE and .SKU are set to something!
					if (not defined $ebitemref->{'_TITLE'}) {
						$ebitemref->{'_TITLE'} = sprintf("Unknown eBay Item: %s",$ebitemref->{'.ItemID'});
						}
					if ($ebitemref->{'.SKU'} eq '') { 
						$SKU = "EBAY-".$ebitemref->{'.ItemID'}; 
						}
					}
				else {
					## nope, we really can't auto-create orders, and we have no zoovy items.
					$ilm->pooshmsg(sprintf("SKIP|+eBay order %s CANNOT CREATE ORDER BECAUSE ZOOVY_ITEM_COUNT==0 and DO_IMPORT_LISTINGS==0",$EBAY_ORDERID));
					}

				my $CLAIM = 0;
				my ($LISTINGID,$TXNID) = split(/-/,$ebitemref->{'.OrderLineItemID'});

				if (not $ilm->can_proceed()) {
					}
				elsif ($SKU) {
					($CLAIM) = $eb2->createClaim({
						'CHANNEL'=>$CHANNEL,
						'BUYER_EMAIL'=>$ebordref->{'.BuyerEmail'},
						'BUYER_USERID'=>$ebordref->{'.BuyerUserID'},
						'BUYER_EIAS'=>'*'.$ebordref->{'.BuyerUserID'},
						'SKU'=>$SKU,
						'PRICE'=>$ebitemref->{'.SalePrice.content'},
						'QTY'=>$ebitemref->{'.QuantitySold'},	
						'PROD_NAME'=>$ebitemref->{'_TITLE'},
			  		 	'MKT_LISTINGID'=>$ebitemref->{'.ItemID'}, 
						'MKT_TRANSACTIONID'=>$TXNID,
						'SITE'=>$ebitemref->{'.ListingSiteID'},
						});
					}
				else {
					$ilm->pooshmsg("WARN|+LISTING:$LISTINGID REFERENCED BLANK SKU (CANNOT CREATE A CLAIM#)");
					## sku was not found or not set, we'll throw a warning later.
					}
			
				## now lets see if an order has already been created.
				my $ACK = 0;	## send ack for this order.
				my $claimref = undef;
				if ($CLAIM>0) {
					$claimref = &EXTERNAL::fetchexternal_full($USERNAME,$CLAIM); 
					if (not defined $claimref) {
						$ilm->pooshmsg("ERROR|+Could not load CLAIM:$CLAIM from database");
						}
					}
			
				
				if (not $ilm->can_proceed()) {
					}
				elsif (not defined $claimref) {
					$ilm->pooshmsg("ERROR|+No claimref");
					}
				elsif ($paramsref->{'fix_corrupt'}) {
					}
				elsif ($claimref->{'ZOOVY_ORDERID'} ne '') {
					$ilm->pooshmsg("WARN|+CLAIM #$CLAIM references ORDER:$claimref->{'ZOOVY_ORDERID'}");
					my ($O2) = CART2->new_from_oid($USERNAME,$claimref->{'ZOOVY_ORDERID'},'new'=>0);
					if (not defined $O2) { 
						$ilm->pooshmsg("WARN|+It appears order ORDER:$claimref->{'ZOOVY_ORDERID'} isn't real - we'll pretend we didn't see that");
						$claimref->{'ZOOVY_ORDERID'} = '';
						}
					$ilm->pooshmsg("SKIP|+Skipped order creation, $CLAIM already linked to order $claimref->{'ZOOVY_ORDERID'}");

					#if ($claimref->{'ZOOVY_ORDERID'} eq '') {
					#	}
					#else {
					#	## hmm.. in hte future some SKIP logic here might be good to just drop this item from the order.
					#	## not sure if it's necessary (ever happens) so i won't code it now.
					#	$ilm->pooshmsg("SKIP|+CLAIM:$CLAIM is already part of order $claimref->{'ZOOVY_ORDERID'}");
					# 	}
					}
				elsif (($claimref->{'STAGE'} eq 'H') && ($O2->in_get('flow/paid_ts')>0)) {
					## ebay item is now flagged as paid. (change the line above to enter)
					my ($O2) = CART2->new($USERNAME,$claimref->{'ZOOVY_ORDERID'},'new'=>0);
					if (not $O2->is_paidinfull()) {
						$O2->add_history("Detected Order is actually PAID");
						# $O2->set_payment_status('060','ebay/monitor-recover',[]);  ## NO LONGER SUPPORTED
						# $O2->save();
						}
					}
				elsif ($claimref->{'STAGE'} eq 'C') {
					$ilm->pooshmsg("STOP|+the item $CLAIM is already completed (but without an order).");
					}
				elsif ((not defined $SKU) || ($SKU eq '')) {
					$ilm->pooshmsg("WARN|+ITEM $LISTINGID HAS BLANK SKU - CREATING AS BASIC ITEM");
					$O2->stuff2()->basic_cram(
						"EBAY-$LISTINGID",
						$ebitemref->{'.QuantitySold'},
						$ebitemref->{'.SalePrice.content'},
						"Misc EBAY Item (No SKU Provided)",
						);						
					}
				else {
					my $MKTID = sprintf("%s-%s",$LISTINGID,$TXNID);
					my $MKT = 'EBF';
					if ($TXNID == 0) { $MKT = 'EBA'; }	# auction listings don't have transaction id's!
	
					my ($P) = PRODUCT->new($USERNAME,$SKU,'create'=>1,'CLAIM'=>$CLAIM);
					my ($pid,$cx,$invopts,$noinvopts,$virtual) = PRODUCT::stid_to_pid($SKU);
					my $recommended_variations = $P->suggest_variations('guess'=>1,'stid'=>$SKU);
					foreach my $variation (@{$recommended_variations}) {
						if ($variation->[4] eq 'guess') {
							$ilm->pooshmsg("WARN|+SKU:$SKU had to guess for variation $variation->[0]$variation->[1]");
							}
						}
					my $selected_variations = STUFF2::variation_suggestions_to_selections($recommended_variations);
					(my $item, $ilm) = $O2->stuff2()->cram( $pid, $ebitemref->{'.QuantitySold'}, $selected_variations, 
						'*LM'=>$ilm, '*P'=>$P,
						'force_price'=>$ebitemref->{'.SalePrice.content'},
						'force_qty'=>$ebitemref->{'.QuantitySold'},
						'claim'=>int($CLAIM),
						);
					$item->{'mkt'} = $MKT;
					$item->{'mktid'} = $MKTID;
					}


				#if ($ilm->can_proceed()) {
				#	push @ORDERACKS, { OrderID=>$EBAY_ORDERID,OrderLineItemID=>$ebitemref->{'.OrderLineItemID'},Paid=>$O2->in_get('flow/paid_ts') };
				#	}
				$olm->merge($ilm);
				}
			}

		if (not $olm->can_proceed()) {
			}
		elsif ((defined $UNPAID_ITEMS) && ($UNPAID_ITEMS>0)) {
			$olm->pooshmsg(sprintf("STOP|+eBay order %s FOUND UNPAID ITEMS IN ORDER!",$EBAY_ORDERID));
			}
		elsif ($O2->in_get('flow/paid_ts')==0) {
			$olm->pooshmsg(sprintf("STOP|+eBay order %s MISSING PAYMENT FLAG",$EBAY_ORDERID));
			}
		else {
			$olm->pooshmsg("INFO|+passed preflight checks");
			}

		## okay there is an annoying case where the person can pay for items individually, and the order isn't
		## ever flagged as paid. so on a multi-item order, even if we decided that it isn't paid, we should still
		## check each item, for payment.
					
		if (not $olm->can_proceed()) {
			}
		elsif ($O2->in_get('flow/paid_ts')==0) {
			## this is a failsafe, just in case.. this line should never be reached.
			$olm->pooshmsg(sprintf("ISE|+eBay order %s is unpaid",$EBAY_ORDERID));
			}
		elsif ($O2->stuff2()->count('show'=>'real')==0) {
			## this is a failsafe, just in case.. this line should never be reached.
			## 10/20/2009 - kits were were not working - changed from 1+2 to 1+2+8 e.g. toynk 250511435648
			$lm->pooshmsg(sprintf("ISE|+eBay order %s skipped due to no items in cart",$EBAY_ORDERID));
			}
		else {
			## we should create an order
			my @EVENTS = ();

			## ebay sometimes likes to put commas in large numbers.
			$ebordref->{'.OrderTotalCost.content'} =~ s/[^\d\.]+//g;
			$ebordref->{'.OrderTotalCost.content'} = sprintf("%.2f",$ebordref->{'.OrderTotalCost.content'});
				
			my $PAYMENT_TXN = undef;
			my $CREATED_GMT = 0;
			my $EBAY_USER = undef;

			$O2->in_set('our/domain', 'ebay.com');
			# '.TaxAmount.currencyID' => 'USD',
			# '.OrderTotalCost.content' => '30.90',
			$O2->in_set('mkt/order_total', $ebordref->{'.OrderTotalCost.content'});
			$O2->in_set('sum/order_total', $ebordref->{'.OrderTotalCost.content'});

			# '.CheckoutSiteID' => '100',
			$O2->in_set('mkt/siteid', $ebordref->{'.CheckoutSiteID'});

			# '.OrderItemDetails.OrderLineItem.BuyerPaymentTransactionNumber> '1EX64160UV2011615');
			$PAYMENT_TXN = $ebordref->{'.OrderItemDetails.OrderLineItem.BuyerPaymentTransactionNumber'};
			$O2->in_set('mkt/payment_txn',$PAYMENT_TXN);

			#$O2->in_set(('ship.selected_method', $ebordref->{'.ShippingService'});
			# '.OrderCreationTime' => '2009-10-05T01:31:12.000Z',
			$CREATED_GMT = $eb2->ebt2gmt($ebordref->{'.OrderCreationTime'});
			$O2->in_set('mkt/post_date',$CREATED_GMT);


			# '.BuyerPhone' => '201 915 0180',
			$O2->in_set('bill/phone', $ebordref->{'.BuyerPhone'});
			$O2->in_set('bill/firstname', $ebordref->{'.BuyerFirstName'});
			$O2->in_set('bill/lastname', $ebordref->{'.BuyerLastName'});

			# '.BuyerEmail' => 'chrisautousa@wataru.com',
			$O2->in_set('bill/email', $ebordref->{'.BuyerEmail'});

			# '.ShipCountryName' => 'US',
			## stupid eBay:
			if ($ebordref->{'.ShipCountryName'} eq 'APO/FPO') { 
				push @EVENTS, "Seems .ShipCountryName is APO/FPO - so we'll change that to US";
				$ebordref->{'.ShipCountryName'} = 'US'; 
				}
			elsif ($ebordref->{'.ShipCountryName'} eq '') { 
				push @EVENTS, "Seems .ShipCountryName is BLANK - so we'll change that to US";
				$ebordref->{'.ShipCountryName'} = 'US'; 
				}
			elsif ($ebordref->{'.ShipCountryName'} eq 'UK') { 
				push @EVENTS, "Seems .ShipCountryName is 'UK' - so we'll change that to GB";
				$ebordref->{'.ShipCountryName'} = 'GB'; 
				}

			# $O2->in_set('ship/country', &ZSHIP::fetch_country_shipname($ebordref->{'.ShipCountryName'});			);
			$O2->in_set('ship/countrycode', $ebordref->{'.ShipCountryName'});

			if (($ebordref->{'.ShipPostalCode'} eq '') || ($ebordref->{'.ShipStateOrProvince'} eq '')) {
				## sanity marker. -- this would be a GREAT place to create a debug log.
				$olm->pooshmsg("WARNING|+Seems no zip and/or state came from eBay (perhaps an offline [customer pickup] payment method?)");
				}


			# '.ShipCityName' => 'Jersey City',
			$O2->in_set('ship/city', $ebordref->{'.ShipCityName'});
			if ($ebordref->{'.ShipCountryName'} eq 'US') {
				# '.ShipPostalCode' => '07302',
				$O2->in_set('ship/postal', $ebordref->{'.ShipPostalCode'});
				# '.ShipStateOrProvince' => 'NJ',
				$O2->in_set('ship/region', $ebordref->{'.ShipStateOrProvince'});
				}
			else {
				# '.ShipPostalCode' => '07302',
				$O2->in_set('ship/postal', $ebordref->{'.ShipPostalCode'});
				# '.ShipStateOrProvince' => 'NJ',
				$O2->in_set('ship/region', $ebordref->{'.ShipStateOrProvince'});
				}


			# '.ShipRecipientName' => 'Wataru Kanematsu',
			if (index($ebordref->{'.ShipRecipientName'}," ")>0) {
				my ($firstname, $lastname) = split(/[\s]+/,$ebordref->{'.ShipRecipientName'},2);
				$O2->in_set('ship/firstname', $firstname);
				$O2->in_set('ship/lastname', $lastname);
				}
			else {
				$O2->in_set('ship/company', $ebordref->{'.ShipRecipientName'});
				}
			# '.InsuranceCost.currencyID' => 'USD',
			# $O2->in_set(('data.', $ebordref->{'.InsuranceCost.currencyID'});
			# '.ShipStreet1' => '102 Columbus Drive',
			$O2->in_set('ship/address1', $ebordref->{'.ShipStreet1'});
			# '.ShipStreet2' => 'Unit 1004',
			$O2->in_set('ship/address2', $ebordref->{'.ShipStreet2'});


			# '.BuyerUserID' => 'chrisautousa',
			$O2->in_set('mkt/docid',$EBAY_JOBID);
			$O2->in_set('mkt/siteid',$ebordref->{'.ListingSiteID'});
			$EBAY_USER = $ebordref->{'.BuyerUserID'};
			$O2->in_set('mkt/buyerid',$ebordref->{'.BuyerUserID'});
			$O2->in_set('is/origin_marketplace',1);			

			# '.ShippingCost.content' => '5.00',
			# WRONG: $O2->in_set('data.shp_total', $ebordref->{'.ShippingCost.content'});
			## NEED A WAY TO MATCH THE EBAY SHIPPING TO A CARRIER CODE
			$O2->set_mkt_shipping( $ebordref->{'.ShippingService'}, $ebordref->{'.ShippingCost.content'} );

			#$O2->in_set('ship.selected_price', $ebordref->{'.ShippingCost.content'});
			# '.ShippingService' => 'US Postal Service Priority Mail',

			# '.OrderTotalCost.currencyID' => 'USD',
			# $O2->in_set('data.order_total', $ebordref->{'.OrderTotalCost.currencyID'});
			## free shipping adds insurance to order (not sure if this right logic)
			# '.InsuranceCost.content' => '0.00',
			if ($ebordref->{'.InsuranceCost.content'} > 0) {
				# $O2->in_set('ship.ins_total', $ebordref->{'.InsuranceCost.content'});	

				my $insurance_paid = $O2->in_get('mkt/shp_total');
				$insurance_paid -= $ebordref->{'.ShippingCost.content'};
				$insurance_paid -= $ebordref->{'.TaxAmount.content'};

				if ($insurance_paid <= 0) {
					push @EVENTS, "It appears the customer didn't actually purchase optional shipping insurance. (removing it)";
					$O2->surchargeQ('add','ins',0,'Insurance',0,2);
					}
				else {
					$O2->surchargeQ('add','ins',$ebordref->{'.InsuranceCost.content'},'Insurance',0,2);
					}
				}

			# '.OrderItemDetails.OrderLineItem.TaxAmount.currencyID' => 'USD',
			# $O2->in_set(('data.', $ebordref->{'.OrderItemDetails.OrderLineItem.TaxAmount.currencyID'});
			# '.TaxAmount.content' => '0.00',
			# $O2->in_set('data.tax_total', $ebordref->{'.TaxAmount.content'});
			my ($IGNORE_ORDER_TOTALS_DONT_MATCH) = 0;
			if ($ebordref->{'.TaxAmount.content'} > 0) {
				$O2->surchargeQ('add','tax',$ebordref->{'.TaxAmount.content'},'Tax',0,2);
				}



			#elsif (0) {
			#	## IS THIS NECESSARY?
			#	## reverse out the tax rate(s)	
			#	($IGNORE_ORDER_TOTALS_DONT_MATCH) = $O2->guess_taxrate_using_voodoo($ebordref->{'.TaxAmount.content'},src=>'eBay');
			#	}
			#if ($IGNORE_ORDER_TOTALS_DONT_MATCH++) {
			#	push @EVENTS, "OTDM! eBay thinks tax[$ebordref->{'.TaxAmount.content'}]+shipping[$ebordref->{'.ShippingCost.content'}]+itemstotal[$ITEM_TOTALS] = ordertotal[$ebordref->{'.OrderTotalCost.content'}]";
			#	}

			my $PAYMENT_STATUS = undef;
			my $PAYMENT_AMOUNT = $ebordref->{'.PaymentOrRefundAmount.content'};
			if (not defined $PAYMENT_AMOUNT) {
				push @EVENTS, "No PaymentOrRefundAmount specified by eBay, we'll use the OrderTotalCost instead";
				$PAYMENT_AMOUNT = $ebordref->{'.OrderTotalCost.content'};
				}

			if ($O2->in_get('flow/paid_ts')==0) {
				## we won't ACK PAID_GMT orders.
				$PAYMENT_STATUS = '160';
				push @EVENTS, "eBay told us the item isn't paid for yet.";
				}
			elsif (sprintf("%.2f",$O2->in_get('sum/order_total')) == sprintf("%.2f",$PAYMENT_AMOUNT)) {
				## woot, ebay matches our total.
				push @EVENTS, "ebay=$ebordref->{'.OrderTotalCost.content'} total matches zoovy=".$O2->in_get('sum/order_total');
				$PAYMENT_STATUS = '060';
				}
			elsif ($IGNORE_ORDER_TOTALS_DONT_MATCH) {
				push @EVENTS, "we are ignoring non-matching order totals! zoovy=".$O2->in_get('sum/order_total')." vs ebay=$ebordref->{'.OrderTotalCost.content'}";
				$PAYMENT_STATUS = '460';
				}
			elsif (sprintf("%.2f",$O2->in_get('sum/order_total')) != sprintf("%.2f",$PAYMENT_AMOUNT)) {

				if (sprintf("%.2f",$O2->in_get('sum/order_total')) > sprintf("%.2f",$PAYMENT_AMOUNT)) {
					push @EVENTS, "Order was underpaid.  zoovy=".$O2->in_get('sum/order_total')." ebay=$PAYMENT_AMOUNT";
					$PAYMENT_STATUS = '160';
					}
				else {
					$PAYMENT_STATUS = '460';
					push @EVENTS, "Order is OVERPAID. total: zoovy=".$O2->in_get('sum/order_total')." vs ebay=$PAYMENT_AMOUNT";
					}
				}
			else {
				ZOOVY::confess($USERNAME,"Order creation fault - this line should never be reached");
			#	$PAYMENT_STATUS = '060';
			#	push @EVENTS, "received update from ebay txn=$PAYMENT_TXN";
				}

			$pstmt = "select OUR_ORDERID from EBAY_ORDERS where MID=".$eb2->mid()." and EBAY_ORDERID=".$udbh->quote($EBAY_ORDERID);
			print $pstmt."\n";
			my ($OUR_ORDERID) = $udbh->selectrow_array($pstmt);

			if ($OUR_ORDERID ne '') {
				}
			elsif ($EBAY_ORDERID eq '') {
				}
			elsif ($olm->can_proceed()) {
				my $ts = time();

				$params{'*LM'} = $olm;
				# $cart2{'mkt/siteid'} eq 'cba')
				$O2->in_set('want/create_customer',0);
				$params{'skip_ocreate'} = 1;

				$O2->add_history(sprintf("eBay Large Merchant Services API %d - Z.LMSAPP %s Ps=$$",$eb2->ebay_compat_level(),$::LMS_APPVER));
				foreach my $estr (@EVENTS) {
					# $lm->pooshmsg(sprintf("EVENT|ebayoid=%s|%s",$EBAY_ORDERID,$msg));
					$O2->add_history($estr,ts=>$ts,etype=>2,luser=>'*EBAY');
					}

				## report any finalize errors, add payments before we save.
				if ($ebordref->{'.PaymentOrRefundAmount.content'} > 0) {
					## we found a payment on this order so we'll just apply that and hope everything lines up.
					$olm->pooshmsg(sprintf("SUCCESS|+eBay:%s Zoovy:%s was finalized SUCCESSFULLY, adding payment of $PAYMENT_AMOUNT",$EBAY_ORDERID,$O2->oid()));
					$O2->add_payment('EBAY',$PAYMENT_AMOUNT,'ps'=>$PAYMENT_STATUS,'txn'=>$PAYMENT_TXN );
					}
				else {
					## there was no payment amount, but it's paid, so we'll apply the order_total as the payment amount 
					$olm->pooshmsg(sprintf("SUCCESS|+eBay:%s Zoovy:%s was finalized SUCCESSFULLY (using Order Total)",$EBAY_ORDERID,$O2->oid()));
					$O2->add_payment('EBAY',$O2->in_get('mkt/order_total'),'ps'=>$PAYMENT_STATUS,'txn'=>$PAYMENT_TXN );
					}

				my ($pstmt) = &DBINFO::insert($udbh,'EBAY_ORDERS',{
					'*CREATED'=>'now()',
					'USERNAME'=>$eb2->username(),
					'MID'=>$eb2->mid(),
					'EBAY_EIAS'=>$eb2->ebay_eias(),				
					'EBAY_JOBID'=>$EBAY_JOBID,
					'EBAY_ORDERID'=>$EBAY_ORDERID,
					'EBAY_STATUS'=>'Active',
					'PAY_METHOD'=>'EBAY',
					'PAY_REFID'=>$PAYMENT_TXN,
					'APPVER'=>$::LMS_APPVER,
					},'verb'=>'insert','sql'=>1);
				$udbh->do($pstmt);

				#if ($ebordref->{'.TaxAmount.content'} > 0) {
				#  open F, ">/tmp/ebay-tax-$USERNAME";
				#  print F Dumper($ebordref);
  				#  print F Dumper($O2);
				#  close F;
  				#  die();
  				#  }

				($olm) = $O2->finalize_order(%params);

				if ($O2->oid()) {
					}
				else {
					$olm->pooshmsg("SKIP|+Order creation was skipped due to previous errors");
					}
				}
			## REMEMBER: if the order is success - then ACK it!
			}

		#if ($ebordref->{'.TaxAmount.content'}>0) {
		#	die();
		#	}

		if ($olm->had(['ISE','ERROR','WAIT','SKIP'])) {
			## we don't ACKNOWLEDGE these
			print Dumper($olm);
			}
		elsif ($olm->had(['STOP','SUCCESS'])) {
			foreach my $item (@{$ord->{'OrderItemDetails'}->[0]->{'OrderLineItem'}}) {	
				my $itemref = &ZTOOLKIT::XMLUTIL::SXMLflatten($item);
				push @ORDERACKS, { OrderID=>$EBAY_ORDERID,OrderLineItemID=>$itemref->{'.OrderLineItemID'} };
				}			
			}
		else {
			$olm->pooshmsg("ISE|+UNKNOWN ACK/UNACK STATUS -- NOT ISE,ERROR,WAIT,SKIP *or* STOP,SUCCESS");
			print Dumper($olm);
			die();
			}

		if (defined $paramsref->{'ebayoid'}) { die(); }
		$lm->merge($olm,'%mapstatus'=>{'STOP'=>'ORDER-STOP','SKIP'=>'ORDER-SKIP','WAIT'=>'ORDER-WAIT','SUCCESS'=>'ORDER-SUCCESS'});
		}

	## now summary size all the messages
	my $ORDER_AVOIDED = 0;
	my $ORDER_SUCCESS = 0;
	my $MSG_ERRORS = 0;
	my $MSG_WARNINGS = 0;
	
	foreach my $msg (@{$lm->msgs()}) {
		my ($ref) = &LISTING::MSGS::msg_to_disposition($msg);
		if (($ref->{'_'} eq 'WARN') || ($ref->{'_'} eq 'WARNING')) { $MSG_WARNINGS++; }
		if (($ref->{'_'} eq 'ERROR') || ($ref->{'_'} eq 'ISE')) { $MSG_ERRORS++; }
		if (($ref->{'_'} eq 'ORDER-STOP') || ($ref->{'_'} eq 'ORDER-SKIP') || ($ref->{'_'} eq 'ORDER-WAIT')) { $ORDER_AVOIDED++; }
		if ($ref->{'_'} eq 'ORDER-SUCCESS') { $ORDER_SUCCESS++; }
		}
	$lm->pooshmsg(sprintf("SUMMARY-ORDERS|+New-Orders:%d Pending-Orders:%d Warn-Msgs:%d Error-Msgs:%d",$ORDER_SUCCESS,$ORDER_AVOIDED,$MSG_WARNINGS,$MSG_ERRORS));

	if (my $iseref = $lm->had(['ISE'])) {
		## if we got an ise don't ack anything!
		&ZOOVY::confess($USERNAME,"EBAY ISE $iseref->{'+'}\n".Dumper($lm),justkidding=>0);
		$lm->pooshmsg(sprintf("SUMMARY-ORDERACK|+Order Ack skipped due to internal-error (ISE) in ORDER feed."));
		}
	elsif (scalar(@ORDERACKS)>0) {
		## we do a getJobs -- because we can only do one orderAck
		my ($xUUID,$xresult) = $eb2->bdesapi('getJobs',{'jobType'=>'OrderAck','jobStatus'=>'Created'},output=>'flat');
		# print Dumper($xresult)."\n";

		my ($UUID,$RESULT) = $eb2->ftsupload('OrderAck',\@ORDERACKS);
		# print Dumper($UUID,$RESULT);

		if ($RESULT->{'.ack'} eq 'Success') {
			$lm->pooshmsg(sprintf("SUMMARY-ORDERACK|+Acknowledged %d orders",scalar(@ORDERACKS)));
			$lm->pooshmsg("SUCCESS|+Complete");
			}
		else {
			## NOTE: it's normal to get failures here because we often send multiple ack jobs at the same time 
			##			and ebay would prefer if we sent it is as one big job.
			my $debugfile = "/tmp/ebay/orderack-$USERNAME.xml";
			open F, ">$debugfile"; 	print F Dumper($xresult);	close F;	
			$lm->pooshmsg(sprintf("SUMMARY-ORDERACK|+Did not get success on OrderAck .ack=$RESULT->{'.ack'} [debug:$debugfile]"));
			}
		}
	else {
		$lm->pooshmsg("SUMMARY-ORDERACK|+No orders to Acknowledge");
		$lm->pooshmsg("SUCCESS|+Nothing to do");
		}

	if (not $lm->can_proceed()) {
		# shit happened.
		}
	elsif ($lm->has_win()) {
		}
	else {
		# warn "Seems odd that we finished with no orders, but I'm setting setting YAY_WE_FINISHED to 1";
		$lm->pooshmsg("SUCCESS|+Done processing orders and acks.");
		}

	my $PRT = $eb2->prt();
	my $TXLOG = TXLOG->new();
	my $qtTXLOG = $udbh->quote($lm->status_as_txlog('@'=>\@SYNDICATION::TXMSGS)->serialize());
	my $pstmt = "update SYNDICATION set TXLOG=concat($qtTXLOG,TXLOG) where MID=$MID /* $USERNAME */ and DSTCODE='EBF'";
	print STDERR "$pstmt\n";
	$udbh->do($pstmt);

	# &DBINFO::task_lock($USERNAME,"ebay-orders","UNLOCK");
	&DBINFO::db_user_close();

	return();
	}



























