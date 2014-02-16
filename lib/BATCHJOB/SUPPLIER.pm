package BATCHJOB::SUPPLIER;

use strict;

use lib "/backend/lib";
use ZTOOLKIT;
use Data::Dumper;
use SUPPLIER::JOBS;


##
## references throughout this file:
##		$u = UTILITY object
##		$bj = batch job BATCHJOB object.
##


sub S { return($_[0]->{'*S'}); }
sub task { return($_[0]->{'_task'}); }
sub code { return($_[0]->{'_code'}); }

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


	my ($MODULE,$CODE,$TASK) = $bj->execverb();
	$self->{'_code'} = $CODE;
	$self->{'_task'} = $TASK;
	
	
	my ($S) = undef;
	if ($CODE eq '') { 
		$ERROR = "Supplier must be passed to job SUPPLIER/CODE/TASK";
		}
	else { 
		($S) = SUPPLIER->new($bj->username(),$CODE);
		if (not defined $S) {
			$ERROR = "Supplier CODE:$CODE could not be found";
			}
		else {
			$self->{'*S'} = $S;
			}
		}
	
	if ($ERROR) {
		}
	elsif (not defined $SUPPLIER::JOBS::TASKS{$TASK}) {
		$ERROR = "SUPPLIER::JOBS does not defined TASK '$TASK'";
		}

	if ($ERROR) {
		## returns a scalar on failure.
		warn "About to return error: $ERROR\n";
		return($ERROR);
		}
	else {
		bless $self, "BATCHJOB::SUPPLIER";
		}

	return($self);
	}


##
##
##
sub run {
	my ($self,$bj) = @_;

	my ($S) = $self->{'*S'};
	my $ERROR = undef;
	my $lm = $bj->lm();


	if (not defined $S) {
		$lm->pooshmsg("ISE|+did not have *S (SUPPLIER) set in object");
		}
	else {
		my ($TASK) = $self->task();
		eval { 
			$SUPPLIER::JOBS::TASKS{$TASK}->($S,$lm); 
			};

		if ((defined $@) && ($@ ne '')) {
			$lm->pooshmsg("ISE|+eval got $@");
			}
		elsif ($lm->has_failed()) {
			}
		elsif ($lm->has_win()) {
			}
		else {
			$lm->pooshmsg("FINISH|+SUPPLIER::JOB::$TASK exited with no explicit win/fail, this may be normal.");
			}
			
		}

	print Dumper($lm,$S);

	## cleanup batch job.
	#if ($lm->had_error()) {
	#	my ($ref,$status) = $lm->whatsup();
	#	$bj->finish($status,"$status $ref->{'+'}");
	#	}
	#elsif ($lm->had_win()) {
	#	$bj->finish('SUCCESS',"");
	#	}
	#else {
	#	my ($ref,$status) = $lm->whatsup();
	#	}
	return($lm);
	}

##
##
##

sub progress {
	my ($self, $records_done, $records_total, $msg) = @_;

	print STDERR "$records_done/$records_total: $msg\n";
	my ($bj) = $self->bj();
	if (defined $bj) {
		$bj->update(
			RECORDS_DONE=>$records_done,
			RECORDS_TOTAL=>$records_total,
			STATUS=>'RUNNING',
			STATUS_MSG=>$msg,
			NOTES=>sprintf("%s",$self->meta()->{'notes'}),
			);
		}
	}

sub username { return($_[0]->{'_USERNAME'}); }
sub prt { return($_[0]->{'_PRT'}); }
sub mid { return($_[0]->{'_MID'}); }
sub luser { return($_[0]->{'_LUSER'}); }


##
##
##

sub batchify {
	my ($ARREF,$SEGSIZE) = @_;

	my @batches = ();
	my $arref = ();
	my $count = 0;
	foreach my $i (@{$ARREF}) {
		push @{$arref}, $i; 
		$count++;
		if ($count>=$SEGSIZE) {
			$count=0; 
			push @batches, $arref;
			$arref = ();
			}
		}
	if ($count>0) {
		push @batches, $arref;
		}
	return(\@batches);
	}





1;