package BATCHJOB::REPORT;

use strict;

use lib "/backend/lib";
use ZTOOLKIT;
use Data::Dumper;

use strict;
use Carp qw(cluck);

use Class::Runtime;
use YAML::Syck;
use lib "/backend/lib";
require ZOOVY;
require REPORT;

use POSIX qw();
use Time::Local;
use Time::Zone;
use CGI;
use Date::Calc;
use Date::Parse;


##
## references throughout this file:
##		$r = ZREPORT object
##		$bj = batch job BATCHJOB object.
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
##
##
sub new {
	my ($class,$bj,%options) = @_;

#	print "CLASS: $class\n";
#	print Dumper($batch);

	my $ERROR = undef;

	my $self = {};
	$self->{'*BJ'} = $bj;		## pointer to the batch job object
	
	my $vars = $bj->vars();
	my ($EXEC,$VERB) = $bj->execverb();

	my ($REPORT) = $VERB;
	if ((not defined $REPORT) || ($REPORT eq '')) { $REPORT =  $vars->{'REPORT'}; }
	print STDERR Dumper($vars);

	my ($EXEC,$VERB) = $bj->execverb();

   my $CLASS = undef;
   my $cl = undef;
   if (not $ERROR) {	
		$VERB =~ s/[^A-Z0-9\_]+//g;
		$CLASS = 'REPORT::'.$VERB;
		print "CLASS:$CLASS\n";

		$cl = Class::Runtime->new( class => $CLASS );
      if ( not $cl->load ) {
			warn "Error in loading class $CLASS\n";
         warn "\n\n", $@, "\n\n";
         $ERROR = $@;
         }

	   ## create the object.
  		##    *ALWAYS* return an object.. if an object isn't returned it's assumed to be an invalid MAP
   	if ($ERROR) {
     		}
	   elsif (not $cl->isLoaded()) {
   	   $ERROR = "Class $CLASS could not be loaded.";
	      }
	   elsif ($CLASS->can('new')) {
	      ## basically this is calling SYNDICATION::DOBA->new() for example
	      ($self->{'*RM'}) = $CLASS->new();
	      ## copy all parameters into %meta
	      }
	   else {
			$ERROR = "Could not call new on Class $CLASS";
   	   }
		}


	my ($r) = undef;
	if (not $ERROR) {
		$r = REPORT->new( $bj->username(), $REPORT, 'PRT'=>$bj->{'PRT'}, 'GUID'=>$bj->{'GUID'},	'BATCHJOB-ID'=>$bj->{'ID'} );
		}

	if ($ERROR) {
		}
	elsif (ref($r) eq '') {
		## we had an error if the object isn't set.
		$ERROR = $r;
		$r = undef;
		if ($ERROR eq '') { $ERROR = "BATCHJOB::REPORT got a non-set \$r when trying to create report"; }
		}
	elsif (ref($r) eq 'REPORT') {
		delete $vars->{'EXEC'};
		delete $vars->{'VERB'};
		$self->{'*R'} = $r;
		$r->{'*BJ'} = $bj;
		foreach my $k (keys %{$vars}) {
			next if (substr($k,0,1) eq '_');		## protected by the report object.
			$r->{'%META'}->{$k} = $vars->{$k};
			}
		bless $self, 'BATCHJOB::REPORT';
		}
	else {
		$ERROR = "BATCHJOB::REPORT got an unknown reference type (".ref($r).") when it expected report";
		$r = undef;
		}


	## every report object can optionally define an "init" which can return errors
	##		*exactly* how this is done hasn't been determined yet .. but stuff like flag checking
	##		etc should be during init 
	my $metaref = $self->bj()->meta();
	if (defined $ERROR) {
		}
	elsif ($metaref->{'PERIOD'}) {
		my $USERNAME = $self->username();
		my $begints = 0;
		my $endts = 0;

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
			next if (substr($k,0,1) eq '_');
			$r->{'%META'}->{$k} = $metaref->{$k};
			}
		}


	if ($ERROR) {
		## hmm.. something bad already happened.
		}
	elsif ((defined $r) && ($r->can('init'))) {
		$r->init(%options);
		## we set the title after init so it shows properly while it's running.
		$self->bj()->title( $r->meta()->{'title'} );
		}
	else {
		$ERROR = "Unable to run INIT function in object";
		}

	if ($ERROR) {
		return($ERROR);
		}

	# print Dumper({ERROR=>$ERROR,bj=>$bj,r=>$r,self=>$self});
	# die();
	return($self);
	}



##
##
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



##
##
##
sub run {
	my ($self,$bj) = @_;

	my ($r) = $self->{'*R'};
	my ($rm) = $self->rm();
	$rm->{'*PARENT'} = $r;		## legacy support

	my ($lm) = LISTING::MSGS->new($bj->username());

	my $ERROR = undef;
	if (not defined $r) {
		$lm->pooshmsg("ERROR|+BATCHJOB::REPORT::run did not have *R set");
		}
	elsif (not defined $rm) {
		$lm->pooshmsg("ERROR|+REPORT::run self->rm() was undef");
		}

	if (not $lm->can_proceed()) {
		## shit already happened.
		}
	elsif ((defined $rm) && ($rm->can('work'))) {
		$self->bj()->title( my $TITLE = $bj->meta()->{'title'} );
		$rm->work();
		if ($TITLE eq '') { $TITLE = sprintf("Report %s",join("/",$bj->execverb())); }

		if (($r->{'@HEAD'}) && ($r->{'@BODY'})) {
			$lm->pooshmsg(sprintf("SUCCESS|+%s (%d rows)",$TITLE,scalar(@{$r->{'@BODY'}})));
			$r->save();
			}
		else {
			$lm->pooshmsg("ERROR|+Report is missing HEAD or BODY!");
			}
		}	
	else {
		$lm->pooshmsg("ERROR|+REPORT->work() failed on can(work) check for \$rm");
		}

	## cleanup batch job.
	return($lm);
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






##
##
##

1;
