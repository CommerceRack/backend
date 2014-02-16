package BATCHJOB::SYNDICATION;

use strict;

use lib "/backend/lib";
use ZTOOLKIT;
use SYNDICATION;
use Data::Dumper;


##
## references throughout this file:
##		$u = UTILITY object
##		$sj = batch job BATCHJOB object.
##


##
##
##
sub new {
	my ($class,$bj) = @_;

#	print "CLASS: $class\n";
#	print Dumper($batch);

	my $ERROR = undef;

	my $self = {};


	$self->{'*BJ'} = $bj;		## pointer to the batch job object
	my $vars = $bj->vars();

	my $DST = $vars->{'DST'};
	$DST =~ s/[^A-Z0-9\_]+//g;

	#my $PROFILE = $vars->{'PROFILE'};
	#$PROFILE =~ s/[^\#A-Z0-9\_]+//g;
	
	my ($DOMAIN) = $bj->domain();
	my ($PRT) = $bj->prt();

	my ($s) = SYNDICATION->new($bj->username(),$DST,'DOMAIN'=>$DOMAIN,'PRT'=>$bj->prt(),'*BJ'=>$bj,'*LM'=>$bj->lm());
	$bj->title("Syndication of $DOMAIN/$PRT to $DST");

	if ($ERROR) {
		}
	elsif (not defined $s) {
		$ERROR = "Could not load SYNDICATION($DST)";
		}
	elsif (ref($s) ne 'SYNDICATION') {
		$ERROR = "BATCHJOB::SYNDICATION did not have \$s set as a SYNDICATION object";
		}

	if (not $ERROR) {
		$self->{'*SYNDICATION'} = $s;
		$s->{'*PARENT'} = $self;
		}

	if ($ERROR) {
		## returns a scalar on failure.
		warn "About to return error: $ERROR\n";
		return($ERROR);
		}
	else {
		bless $self, "BATCHJOB::SYNDICATION";
		}

	return($self);
	}




sub bj { return($_[0]->{'*BJ'}); }

##
##
##
sub run {
	my ($self,$bj) = @_;

	my $lm = $bj->lm();
	my ($s) = $self->{'*SYNDICATION'};

	my $FEEDTYPE = $bj->get('.FEEDTYPE');
	if ($FEEDTYPE eq '') { $FEEDTYPE = $bj->get('..FEEDTYPE'); }
	if (($FEEDTYPE eq '') && ($s->dst() eq 'PRV')) { $FEEDTYPE = 'PRODUCT'; }
	if ($FEEDTYPE eq '') { 
		$lm->pooshmsg("ISE|+Required Parameter: FEEDTYPE was not received!");
		}
	elsif (not defined $s) {
		$lm->pooshmsg("ISE|+BATCHJOB::SYNDICATION::run did not have *SYNDICATION set");
		}

	if ($lm->can_proceed()) {
		print "###BATCHJOB_SYNDICATION_RUNNING#####################################################\n";
		$bj->progress(0,0,"Starting Syndication Run");
		$s->runnow(type=>$FEEDTYPE,bj=>$bj,sj=>$self);
		}

	## cleanup batch job.
	if (my ($ref) = $lm->had('SUCCESS')) {
		my $MSG = "Syndication has Completed";
		if ($ref->{'+'}) { $MSG = $ref->{'+'}; }
		$bj->finish('END-SUCCESS',$MSG);
		}
	elsif (my ($ref) = $lm->had('ISE')) {
		my $MSG = "UNKNOWN ISE ENCOUNTERED";
		if ($ref->{'+'}) { $MSG = $ref->{'+'}; }
		warn "BATCHJOB::SYNDICATION::run returning with msg=$MSG";
		$bj->finish('END-ERRORS',"ISE: $MSG");
		}
	else {
		my $MSG = "UNKNOWN SYNDICATION ERROR ENCOUNTERED";
		if (my ($ref) = $lm->had('ERROR')) { $MSG = $ref->{'+'}; }
		warn "BATCHJOB::SYNDICATION::run returning ERROR with msg=$MSG";
		$bj->finish('END-ERRORS',"$MSG");
		}

	## let the next layer know it doesn't need to call finish, since we did!
	return('FINISHED');
	}


##
## this is called by SYNDICATION.pm 
##		as $sj->log()
##
sub log {
	my ($self, $txt) = @_;

	print STDERR "Txt: $txt\n";
	my $bj = $self->bj();
	$bj->slog($txt);

	my ($id) = $bj->id();
	open F, ">>/tmp/batch-$id.log";
	print F "$txt\n";
	close F;
	}

##
##
##

sub progress {
	my ($self, $records_done, $records_total, $msg) = @_;

	# print Dumper($self);
	print STDERR "$records_done/$records_total: $msg\n";
	my ($bj) = $self->{'*BJ'};
	if (defined $bj) {
		$bj->update(
			RECORDS_DONE=>$records_done,
			RECORDS_TOTAL=>$records_total,
			STATUS=>'RUNNING',
			STATUS_MSG=>$msg,
			NOTES=>'',
			);
		}
	}

sub username { return($_[0]->{'_USERNAME'}); }
sub prt { return($_[0]->{'_PRT'}); }
sub mid { return($_[0]->{'_MID'}); }
sub luser { return($_[0]->{'_LUSER'}); }



1;
