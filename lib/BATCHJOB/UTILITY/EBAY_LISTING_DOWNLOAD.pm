package BATCHJOB::UTILITY::EBAY_LISTING_DOWNLOAD;


use strict;
use Data::Dumper;
use lib "/backend/lib";
require INVENTORY2;
require EBAY2;
use XML::LibXML;
use File::Slurp;
require SYNDICATION::EBAY;
require LUSER::FILES;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }


## this has it's own custom "finish" function that provides a link back to the product.
##
sub finish {
	my ($self, $bj) = @_;

	my $meta = $bj->meta();
	
	my $msg = qq~eBay Job done.<br>~;
	$bj->finish('SUCCESS',$msg);	

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
	my $lm = $bj->lm();



	my ($eb2) = EBAY2->new($USERNAME,PRT=>$PRT);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my $jobType = 'ActiveInventoryReport';

	## DUPLICATE CHECK?
	my $PENDING_JOB_COUNT = 0;
	my @JOBS = &SYNDICATION::EBAY::lms_get_jobs($eb2,$udbh,$jobType,$lm,'pending'=>1);

	foreach my $jobref (@JOBS) {
		my ($ID,$JOBID,$JOBTYPE,$JOBFILEID,$CREATED_TS,$DOWNLOADED_TS) = @{$jobref};		
		if (&ZTOOLKIT::mysql_to_unixtime($CREATED_TS)<time()-3600) {
			## to be considered PENDING it must be less than one hour old
			}
  		elsif ($DOWNLOADED_TS == 0) { 
 			$PENDING_JOB_COUNT++; 
			}
		}

		
	if ($PENDING_JOB_COUNT==0) {
		$lm->pooshmsg("START|+creating a new $jobType request");
		($lm) = &SYNDICATION::EBAY::lms_create_job($eb2,$udbh,$jobType,$lm);
		$lm->pooshmsg("STOP|+finished creating $jobType request");
		}

	my $DONE = 0;
	my $ATTEMPTS = 0;
	while ( not $DONE ) {
		print "Sleeping .. (ATTEMPTS: $ATTEMPTS)\n";

		sleep($ATTEMPTS * 10);

		my ($ID,$JOBID,$JOBTYPE,$JOBFILEID,$CREATED_TS,$DOWNLOADED_TS);
		my @JOBS = &SYNDICATION::EBAY::lms_get_jobs($eb2,$udbh,$jobType,$lm,'pending'=>1);
		if (scalar(@JOBS)==0) {
			$lm->pooshmsg("ISE|+No jobs requiring processing found.");
			}
		else {
			($ID,$JOBID,$JOBTYPE,$JOBFILEID,$CREATED_TS,$DOWNLOADED_TS) = @{$JOBS[0]};
  			if ($DOWNLOADED_TS == 0) { 
 				$PENDING_JOB_COUNT++; 
				}
			}

		print Dumper(\@JOBS);

		my $SUCCESS = 0;
		my $qtAPP = $udbh->quote($::LMS_APPVER);		## just a handy way of reprocessing if we need to
		foreach my $waitref (@JOBS) {
			$ATTEMPTS++;
			my ($DBID,$JOBID,$JOBTYPE,$JOBFILEID,$CREATED_TS) = @{$waitref};
			my $FILENAME = "EBAY-$USERNAME-$PRT-$JOBID-$JOBFILEID.xml";
			my ($TMPFILENAME) = sprintf("%s/%s",&ZOOVY::tmpfs(),$FILENAME);
				
			my $xml = undef;
			if (-s $TMPFILENAME) {
				$lm->pooshmsg("DEBUG|+Reading for existing TMPFILE:$TMPFILENAME");
				($xml) = join("",File::Slurp::read_file($TMPFILENAME));
				}
			else {
				(my $ERROR,$xml) = $eb2->ftsdownload($JOBID,$JOBFILEID);
				if ($ERROR) { 
					$lm->pooshmsg("ERROR|+$ERROR");
					}
				}


			if ($xml eq '') {	
				$lm->pooshmsg("WARN|+FILE: $FILENAME was empty (it's fairly common for ths to happen)");
				}
			else {
				my ($TMPFILENAME) = sprintf("%s/%s",&ZOOVY::tmpfs(),$FILENAME);
			
				open F, ">$TMPFILENAME";
				print F $xml;
				close F;

				my $LF = LUSER::FILES->new($eb2->username(), 'app'=>'EBAY');
				$LF->add(file=>"$TMPFILENAME",type=>"SYNDICATION",overwrite=>1,'createdby'=>'eBay',expires_gmt=>time()+(86400*90));
				$lm->pooshmsg("INFO|+Stored $jobType Job#$JOBID as File:$TMPFILENAME");

				if ($JOBTYPE eq 'ActiveInventoryReport') {
					&SYNDICATION::EBAY::processListings($eb2,$JOBID,$CREATED_TS,$lm,$xml,$bj->vars());
					}
			
				if ($lm->has_win()) {
					my $pstmt = "update EBAY_JOBS set DOWNLOADED_APP=$qtAPP,DOWNLOADED_TS=now(),FILENAME=".$udbh->quote($TMPFILENAME)." where MID=$MID and ID=$DBID";
					print "$pstmt\n";
					$udbh->do($pstmt);
					unlink("$TMPFILENAME");
					}
				else {
					$lm->pooshmsg("WARN|+got non -success response, saving crash file $TMPFILENAME");
					}
				$DONE++;
				}

			if ($ATTEMPTS>10) {
				$lm->pooshmsg("STOP|+Job $jobType was not processed after $ATTEMPTS");
				$DONE++;
				}

			}

		}

	if ($lm->has_win()) {
		my $pstmt = "update EBAY_TOKENS set ERRORS=0,LMS_SOLD_REQGMT=".time()." where MID=$MID and PRT=$PRT";
		print "$pstmt\n";
		$udbh->do($pstmt);
		}

	&DBINFO::db_user_close();
	$bj->progress(0,0,"Done");
	return(undef);
	}





1;