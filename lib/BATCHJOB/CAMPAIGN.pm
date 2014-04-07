package BATCHJOB::CAMPAIGN;

use strict;

use lib "/backend/lib";
use ZTOOLKIT;
use Data::Dumper;
require CAMPAIGN;
require CUSTOMER;
require TEMPLATE::KISSTLC;
use Net::AWS::SES;

##
## references throughout this file:
##		$bj = batch job BATCHJOB object.
##


sub BJ { return($_[0]->{'*BJ'}); }
sub CPG { return($_[0]->{'*CPG'}); }

sub redisqueuekey { my ($self) = @_; return( sprintf("campaign.%s",$self->CPG()->campaignid()) ); }

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

	my ($USERNAME) = $bj->username();
	my ($MODULE,$CPGID) = $bj->execverb();
	my $CPG = $self->{'*CPG'} = CAMPAIGN->new($USERNAME,$bj->prt(),$CPGID);
	if (not $self->{'*CPG'}) {
		$ERROR = "*CPG is corrupt";
		}

	if ($ERROR) {
		## returns a scalar on failure.
		warn "About to return error: $ERROR\n";
		return($ERROR);
		}
	else {
		bless $self, "BATCHJOB::CAMPAIGN";
		}

	my $lm = $bj->lm();
	$lm->console(1);

	my ($redis) = &ZOOVY::getRedis($USERNAME,2);
	my $REDISKEY = $self->redisqueuekey();
	my $TMPREDISKEY = sprintf("$REDISKEY.%d",$$);

	## $redis->del($REDISKEY);
	##  
	if ($ERROR) {
		## shit happened.
		}
	elsif ($redis->exists($REDISKEY)) {
		$lm->pooshmsg("RESTART|+Found $REDISKEY queue, no need to initialize");
		}
	elsif (not $ERROR) {
		## step1: create a redis queue
		$redis->lpush($TMPREDISKEY,"START");
		$redis->expire($TMPREDISKEY,60*60);

		## step2: insert all the messages
		## $redis->lpush($TMPREDISKEY,"EMAIL?CID=7633597&email=kimh\@zoovy.com");
		foreach my $CID (@{$CPG->recipients()}) {
			$redis->lpush($TMPREDISKEY,"CID?CID=$CID");
			}

		## step3: push a finish
		$redis->lpush($TMPREDISKEY,"FINISH");

		## step4: renamenx will only succeed if the queue doesn't already exist!
		$redis->renamenx($TMPREDISKEY,$REDISKEY);
		$redis->expire($REDISKEY,86400*30);
		## SANITY: at this point $REDISKEY will be set.
		}


	return($self);
	}







##
##
##
sub run {
	my ($self,$bj) = @_;

	my $ERROR = undef;
	my $lm = $bj->lm();
	my ($CPG) = $self->CPG();
	my $REDISKEY = $self->redisqueuekey();
	$CPG->__send__($REDISKEY,$lm);
	print Dumper($CPG);

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

sub username { return($_[0]->BJ()->username()); }
sub prt { return($_[0]->BJ()->prt()); }
sub mid { return( $_[0]->BJ()->mid()); } 
sub luser { return($_[0]->BJ()->lusername()); }


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

