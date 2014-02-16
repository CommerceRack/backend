package REPORT;

use strict;
use Carp qw(cluck);

use Class::Runtime;
use YAML::Syck;
use lib "/backend/lib";
require ZOOVY;

use POSIX qw();
use Time::Local;
use Time::Zone;
use CGI;
use Date::Calc;
use Date::Parse;

##
## this will load "MAPS" which are effectively modules that populate it.
##	the structure of the data in a report is in GTOOLS::Report
##	
## lookup methods defined by report are:
##		username(), mid(), prt(), guid(), jobid()
##	
## worker methods (these basically call the equivalent function in MAP):
##		init(),
##
## *IF* this is being called from a batch job, then *BJ will be set following exit of method new()
##		otherwise it will be undef.


#sub AUTOLOAD {
#	my ($CLASS, $AUTOLOAD) = @_;
#	warn("REPORT::AUTOLOAD -- [Error: Missing Function] @_\n");
#	}

##
## for an example of a report object, look in GTOOLS/REPORT.pm
##
##




##
## returns a reference to the meta hash
##
sub username { return($_[0]->{'_USERNAME'}); }
sub mid { return($_[0]->{'_MID'}); }
sub guid { return($_[0]->{'_GUID'}); }
sub prt { return(int($_[0]->{'_PRT'})); }
sub jobid { my ($self) = @_; return(int($self->{'_BATCHJOB-ID'})); }

##
## this can safely be called, if *BJ isn't set, then it does nothing.
##
sub progress {
	my ($self, $records_done, $records_total, $msg) = @_;

	my ($bj) = $self->bj();
	$bj->progress(
		$records_done,
		$records_total,
		$msg,
		sprintf("%s",$self->meta()->{'notes'})
		);
	}

sub meta { 
	my ($self,$attrib) = @_; 
	return($self->{'%META'}); 
	}

## returns a reference to the report object
sub rm { my ($self) = @_; return($self->{'*RM'}); }
## returns a reference to the batch job object
sub bj { my ($self) = @_; return($self->{'*BJ'}); }
## returns a reference to the batch report object
sub br { my ($self) = @_; return($self->{'*BR'}); }


##
## this loads a report from disk ..
##
sub new_from_guid {
	my ($CLASS,$USERNAME,$GUID) = @_;
	
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select FILETYPE,FILENAME from PRIVATE_FILES where MID=$MID /* $USERNAME */ and GUID=".$udbh->quote($GUID);
	print STDERR $pstmt."\n";
	my ($filetype,$filename) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();

	## no file!?!
	if ($filename eq '') {
		return(sprintf("No file was found %s",$GUID));		
		}
	if ($filetype ne 'REPORT') {
		return(sprintf("GUID %s is not of type REPORT",$GUID));		
		}

	my ($R) = undef;
	if ($filename ne '') {
		my $path = &ZOOVY::resolve_userpath($USERNAME).'/PRIVATE/'.$filename;
		if (-f $path) {
			($R) = YAML::Syck::LoadFile($path);
			bless $R, 'REPORT';
			}
		else {
			warn "File: $path doesn't exist\n";
			}
		}

	return($R);
	}

##
## MAP is the REPORT::MAP -- 
##
## valid options:
##		file=> (leave PROVIDER blank)
##
sub new {
	my ($class, $USERNAME, $MAP, %protected) = @_;

	my $self = {};
	if (scalar(keys %protected)>0) {
		foreach my $k (keys %protected) {
			$self->{'_'.$k} = $protected{$k};
			}
		}

	my $ERROR = undef;

	$self->{'_USERNAME'} = $USERNAME;
	$self->{'_MID'} = &ZOOVY::resolve_mid($USERNAME);
	bless $self, 'REPORT';


	my $CLASS = undef;
	my $cl = undef;

	if (not $ERROR) {
		$MAP =~ s/[^A-Z0-9\_]+//g;
		$CLASS = 'REPORT::'.$MAP;

		$cl = Class::Runtime->new( class => $CLASS );
		if ( not $cl->load ) {
			warn "Error in loading class $CLASS\n";
			warn "\n\n", $@, "\n\n";
			$ERROR = $@;
			}
		}
		

	my $r = undef;
	## create the object. 
	## 	*ALWAYS* return an object.. if an object isn't returned it's assumed to be an invalid MAP
	if ($ERROR) {
		}
	elsif (not $cl->isLoaded()) {
		$ERROR = "Class $CLASS could not be loaded.";
		}
	elsif ($CLASS->can('new')) {
   	($r) = $CLASS->new();
		## copy all parameters into %meta 
		}
	else {
		$ERROR = "Could not call new on Class $CLASS";
		}


	if ($ERROR) {
		}
	elsif ((not defined $r) || (ref($r) ne $CLASS)) {
		$ERROR = "Unknown Report: $MAP";
		}
	else {
		$r->{'*PARENT'} = $self;
		$self->{'*RM'} = $r;
		}


	if ($ERROR) {
		## returns a scalar on failure.
		return($ERROR);
		}

	return($self);
	}

##
##
##
sub init {
	my ($self, %options) = @_;

	## every report object can optionally define an "init" which can return errors
	##		*exactly* how this is done hasn't been determined yet .. but stuff like flag checking
	##		etc should be during init 
	my $ERROR = undef;

	my $rm = $self->rm();

	my $metaref = $self->bj()->meta();

	if (defined $ERROR) {
		}
	elsif ($metaref->{'PERIOD'}) {
		my $USERNAME = $self->username();
		my $begints = 0;
		my $endts = 0;

		#if ($metaref->{'PERIOD'} eq '') { 
		#	$metaref->{'PERIOD'} = $metaref->{'VERB'}; 
		#	$metaref->{'PERIOD'} =~ /^SALES-/;
		#	}
		#if ($metaref->{'PERIOD'} eq '') { $metaref->{'PERIOD'} = 'BYTIMESTAMP'; }

		if ($metaref->{'PERIOD'} eq '') {
			## NO PERIOD IS REQUIRED FOR SOME REPORTS
			}
		elsif ($metaref->{'PERIOD'} eq 'today') {
			$begints = str2time(Date::Calc::Date_to_Text(Date::Calc::Today));
			$endts = $begints + 86400;
			}
		elsif ($metaref->{'PERIOD'} eq 'yesterday') {
			$endts = str2time(Date::Calc::Date_to_Text(Date::Calc::Today));
			$begints = $endts - 86400;
			}
		elsif ($metaref->{'PERIOD'} eq 'thismonth') {
			$begints = &ZTOOLKIT::mysql_to_unixtime(POSIX::strftime("%Y-%m-01 00:00:00",localtime()));
			$endts = time();
			}
		elsif ($metaref->{'PERIOD'} eq '4week') {
			$begints = time()-(86400*28);
			$endts = time();
			}
		elsif ($metaref->{'PERIOD'} eq 'all') {
			$begints = 1;	  # make sure there's nothing nasty here!
			$endts = time();
			}
		elsif ($metaref->{'PERIOD'} eq 'BYINVOICE') {
			require CART2;
			if ($metaref->{'startinv'} ne '') {
				my ($O2) = CART2->new_from_oid($USERNAME,$metaref->{'startinv'});
				if (defined $O2) { $begints = $O2->in_get('our/order_ts'); } else { $ERROR = "beginnging order not valid"; }
				}
			if ($metaref->{'endinv'} ne '') {
				my ($O2) = CART2->new_from_oid($USERNAME,$metaref->{'endinv'});
				if (defined $O2) { $endts = $O2->in_get('our/order_ts'); } else { $ERROR = "ending order not valid"; }
				}
			else {
				$endts = time();
				}
			}
		elsif ($metaref->{'PERIOD'} eq 'BYMONTH') {
			my $month = $metaref->{'month'};
			my $year = $metaref->{'year'};
			$begints = &ZTOOLKIT::mysql_to_unixtime(sprintf("%d-%d-01 00:00:00",$year,$month));
			$endts = &ZTOOLKIT::mysql_to_unixtime(sprintf("%d-%d-%d 23:59:59",$year,$month,Date::Calc::Days_in_Month($year,$month)));
			}
		elsif (($metaref->{'PERIOD'} eq 'BYDATE') || ($metaref->{'PERIOD'} eq 'BYPERIOD')) {
			my $begins = $metaref->{'begins'};
			my $ends = $metaref->{'ends'};
			print STDERR "begins $begins ends $ends\n";
			if ($begins ne '' && $begins !~ /\d\d\/\d\d\/\d\d/) {
				$begints = 0;
				}
			elsif ($ends ne '' && $ends !~ /\d\d\/\d\d\/\d\d/) {
				$endts = 0;
				}
			else {
				$begints = str2time($begins);
				$endts = str2time($ends);
				}
			}
		elsif ($metaref->{'PERIOD'} eq 'BYTIMESTAMP') {
			$begints = $metaref->{'begints'};
			$endts = $metaref->{'endts'};
			}
		else {
			$ERROR = "Unknown sales-quick report PERIOD=$metaref->{'PERIOD'}";
			}
		if ($begints > $endts) { my $tmp = $begints; $begints = $endts; $endts = $begints; }	# swap backwards values!


		if ($ERROR) {
			}
		elsif (($endts == 0) || ($begints ==0)) {
			$ERROR = 'Error in date range, please try again!';
			}
		else {
			# my $URL = "/biz/reports/output.cgi?ACTION=NEW&REPORT=SALES&verb=period&start_gmt=$begints&end_gmt=$endts&include_deleted
			$metaref->{'start_gmt'} = $begints;
			$metaref->{'end_gmt'} = $endts;
			## NOTE: I think the version below (.start_gmt) is the *correct* version, but it seems we should set both for compat.
			$metaref->{'.start_gmt'} = $begints;
			$metaref->{'.end_gmt'} = $endts;
			if ($metaref->{'title'} eq '') {
				## set a default title for the job
				$self->bj()->{'TITLE'} = sprintf("REPORT %s start:%s end:%s",$metaref->{'REPORT'},&ZTOOLKIT::pretty_date($begints,1),&ZTOOLKIT::pretty_date($endts,1));
				}
			}

		foreach my $k (keys %{$metaref}) {
			$self->setMETA($k,$metaref->{$k});
			}
		}


	if ($ERROR) {
		## hmm.. something bad already happened.
		}
	elsif ((defined $rm) && ($rm->can('init'))) {
		$rm->init(%options);
		## we set the title after init so it shows properly while it's running.
		$self->bj()->title( $self->meta()->{'title'} );
		}
	else {
		$ERROR = "Unable to run INIT function in object";
		}

	if ($ERROR) {
		return($ERROR);		
		}
	
	return($self);
	}


##
##
##
sub run {
	my ($self) = @_;
	##
	## this is the actual worker routine.
	##
	my $ERROR = undef;

	# use Data::Dumper; print Dumper($self);

	## note: $r here isn't a report, it's a pointer to the REPORT::MAP
	my $rm = $self->rm();
	if (not defined $rm) {
		$ERROR = "REPORT::run self->rm() was undef";
		}


	if (defined $ERROR) {
		## shit already happened.
		}
	elsif ((defined $rm) && ($rm->can('work'))) {
		$rm->work();
		$self->save();
		$self->bj()->title( $self->meta()->{'title'} );
		}	
	else {
		$ERROR = 'REPORT::run failed on can(work) check for $rm';
		}

	# use Data::Dumper; print Dumper($r,$CLASS); die();
	return($ERROR);
	}







##
## meta properties are stored in the REPORT object, and referenced by REPORT::MAP
##
sub setMETA {
	my ($self,%vars) = @_;

#	my ($r) = $self->r();
#	if (not defined $r) {
#		my ($package,$file,$line,$sub,$args) = caller(1);
#		Carp::cluck("attempted to call setMETA with no *R set");
#		}
#	else {
#		## loads variables into %META
		foreach my $k (keys %vars) {
			next if (substr($k,0,1) eq '_');		## protected by the report object.
			$self->{'%META'}->{$k} = $vars{$k};
			}
#		}

	}

##
## serializes the data in R
##
sub save {
	my ($self) = @_;

	## backup and delete coderefs
	my %coderefs = ();
	foreach my $k (keys %{$self}) {
		if (substr($k,0,1) eq '*') {
			$coderefs{$k} = $self->{$k};
			delete $self->{$k};	## remove the link to the parent (us)
			}
		}

	my $filename = "/tmp/".$self->{'username'}.'~'.$self->jobid().'~'.$self->guid().'.yaml';
	open F, ">$filename";
	print F YAML::Syck::Dump($self);
	close F;

	require LUSER::FILES;
	my ($lf) = LUSER::FILES->new($self->username());

	my $guid = undef;
	if (defined $lf) {
		($guid) = $lf->add(
			file=>$filename,
			title=>$self->meta()->{'title'},
			type=>'REPORT',
			overwrite=>1,
			guid=>$self->guid(),
			meta=>$self->meta(),
			unlink=>1
			);
		}
		
	## restore coderefs
	foreach my $k (keys %coderefs) {	
		$self->{$k} = $coderefs{$k};
		}
	
	if (not defined $guid) {
		warn "LUSER::FILES return undef on method add";
		}
	elsif ($guid eq $self->guid()) {
		return($guid);
		}
	else {
		return(undef);
		}
	}



###################################################################################
##
## 	UTILITY FUNCTIONS (which are commonly used) 
##
sub yyyy_mm_dd_time {
	my ($timestamp) = @_;
	
	my (undef,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($timestamp);
	
	my $TZ = 'PST';
	if ($isdst) { $TZ = 'PDT'; }

	my $c = sprintf("%4d-%02d-%02d",$year+1900,$mon+1,$mday);
   $c .= " $hour:";
	if ($min<10) { $c .= '0'; }
	$c .= $min;
	$c .= ' '.$TZ;

	return($c);
	}

##
## returns the hour for a gmT time.
##
sub format_hour {
	my ($GMT) = @_;

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($GMT);
	return($hour);
	}

##
## returns a report formatted date
##
sub format_date {
	my ($GMT) = @_;

	## eventually we might want to do some more tuning here.
	return(&ZTOOLKIT::pretty_date($GMT));
	}



1;