package BATCHJOB::UTILITY;

use strict;

use lib "/backend/lib";
use ZTOOLKIT;
use Data::Dumper;


##
## references throughout this file:
##		$u = UTILITY object
##		$bj = batch job BATCHJOB object.
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

	my ($MODULE,$MAPP) = $bj->execverb();

	## PRE 201234
	if (not defined $MAPP) { $MAPP = $vars->{'APP'}; }
	if (not defined $MAPP) { $MAPP = uc($vars->{'.function'}); }

	$MAPP =~ s/[^A-Z0-9\_]+//g;
	my $CLASS = "BATCHJOB::UTILITY::$MAPP";
	my $cl = undef;

	if (not $ERROR) {
		$cl = Class::Runtime->new( class => $CLASS );
		if ( not $cl->load ) {
			warn "Error in loading class $CLASS\n";
			warn "\n\n", $@, "\n\n";
			$ERROR = $@;
			}
		}
		
	my $u = undef;
	## create the object. 
	## 	*ALWAYS* return an object.. if an object isn't returned it's assumed to be an invalid MAP
	if ($ERROR) {
		}
	elsif (not $cl->isLoaded()) {
		$ERROR = "Utility Class $CLASS could not be loaded.";
		}
	elsif ($CLASS->can('new')) {
		## basically this is calling SYNDICATION::DOBA->new() for example
   	($u) = $CLASS->new();
		## copy all parameters into %meta 
		}
	else {
		$ERROR = "Could not call new on Utility Class $CLASS";
		}

	if ($ERROR) {
		}
	elsif ((not defined $u) || (ref($u) ne $CLASS)) {
		$ERROR = "Unknown Utility: $MAPP";
		}
	else {
		$u->{'*PARENT'} = $self;
		$self->{'*UM'} = $u;
		}

	if ($ERROR) {
		}
	elsif (not $CLASS->can('work')) {
		$ERROR = "Class $CLASS cannot call work";
		}

	if ($ERROR) {
		## returns a scalar on failure.
		warn "About to return error: $ERROR\n";
		return($ERROR);
		}
	else {
		bless $self, "BATCHJOB::UTILITY";
		}

	return($self);
	}


##
##
##
sub run {
	my ($self,$bj) = @_;

	my ($um) = $self->{'*UM'};
	my $ERROR = undef;
	if (not defined $um) {
		$ERROR = "1|BATCHJOB::UTILITY::run did not have *UM set";
		}
	else {
		print "###BATCHJOB_UTILITY_RUNNING#####################################################\n";
		eval { ($ERROR) = $um->work($bj) };

		if ((defined $@) && ($@ ne '')) {
			$ERROR = "3|ISE $@";
			}
		elsif (defined $ERROR) {
			$ERROR = "2|$ERROR";
			}
		else {
			$ERROR = "0|Success";
			}
		print "###### ERROR:$ERROR\n";
		}

	## hmm.. might be a good idea to do some more error handling here.
	## $BATCHJOB::UTILITY::VERBS{$r->{'TYPE'}}->($bj,$r);

	## cleanup batch job.
	my ($errcode,$msg) = split(/\|/,$ERROR,2);
	if ($errcode>0) {
		warn "BATCHJOB::UTILITY::run returning with err=$errcode ($msg)";
		$bj->finish('ERROR',"Utility error: $msg");
		}
	elsif ($um->can('finish')) {
		$um->finish($bj);
		}
	else {
		warn "BATCHJOB::UTILITY::run returning SUCCESS";
		$bj->finish('SUCCESS',"Utility has Completed");
		}
	return($errcode,$msg);
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




##
##
##

1;
