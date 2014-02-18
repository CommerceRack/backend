#!/usr/bin/perl

use strict;

use YAML::Syck;
use AnyEvent;
use JavaScript::V8;
use threads ('yield',
	'stack_size' => 64*4096,
	'exit' => 'threads_only',
	'stringify');
use threads::shared;
use Data::Dumper;

use lib "/httpd/modules";
require ZOOVY;
require REPRICE;
require PRODUCT;


my $USERNAME = "andrewt";
my ($CLUSTER) = &ZOOVY::resolve_cluster($USERNAME);

sub sync_exit {
	print "Received exit\n";
	exit();
	}

## register signal handlers
$SIG{'HUP'} = \&sync_exit;
$SIG{'INT'} = \&sync_exit;


print "CLUSTER: $CLUSTER\n";
my $redis = &ZOOVY::getRedis($CLUSTER);
$redis->select(2);


## PHASE1:

## phase1: find any requests that are waiting (from the last time we ran)
%::UPDATES_PENDING = ();
foreach my $k ($redis->keys("UPDATES_PENDING.*")) {
	if ($k =~ /PENDING\.(.*?)$/) {
		$::UPDATES_PENDING{ $USERNAME }++;
		}
	}

$::MAX_THREADS = 2;
$::MAX_THREAD_RUNTIME = 60;

## phase2: enter a loop looking for new updates
my @THREADS = ();
while ( my ($QUEUE,$YAML) = $redis->brpop("INCOMING",2) ) {
	print "$QUEUE $YAML\n";


	my $msg = YAML::Syck::Load($YAML);
	my $VERB = $msg->{'VERB'};
	if (scalar(@THREADS)>$::MAX_THREADS) {
		$redis->rpush("INCOMING",$YAML);
		print sprintf("Wait .. too many threads %d of %d\n",scalar(@THREADS),$::MAX_THREADS);
		sleep(5);
		$VERB = undef;
		}

	my $ts = time();
	my @NEWTHREADS = ();
	foreach my $ref (@THREADS) {
		my ($t,$thr, $result) = @{$ref};

		my $ERROR = undef;
		if ($ERROR = $thr->error()) {
			}
		elsif ($t+$::MAX_THREAD_RUNTIME < $ts) {
			## this thread has run too long, kill it.
			$ERROR = "thread max runtime ($::MAX_THREAD_RUNTIME) exceeded.";
			$thr->kill('SIGUSR1');
			}
		elsif ($thr->is_running()) {
			## let it be.. let it be.
			print "RUNNING\n";
			push @NEWTHREADS, $ref;
			}
		elsif ($thr->is_joinable()) {
			my $RESULT = $thr->join();
			print "GOT RESULT\n";
			}
		else {
			## this line should never be reached?!? zombie thread!
			print "GOT A ZOMBI!\n";
			push @NEWTHREADS, $ref;
			}
		}
	@THREADS = @NEWTHREADS;

	if (not defined $VERB) {
		}
	elsif ($VERB eq 'ACTION1') {
		## send to thread1
		my $thr = threads->create('start_thread', $msg);
		push @THREADS, [ time(), $thr, undef ];
		# $thr->join();
		}
	else {
		
		}

	print "wait\n";
	}


# print Dumper(\%UPDATES_PENDING);

sub start_thread {
	my ($msg) = @_;
	print('Thread started: ', Dumper($msg), "\n");

	my ($P) = PRODUCT->new($msg->{'USERNAME'},$msg->{'PID'});
	my $rp = undef;
	my $ERROR = undef;
	if (not defined $P) {
		$ERROR = sprintf("product '%s' is invalid/could not be loaded from db",$msg->{'PID'});
		}
	else {
		($rp) = REPRICE->new($P);
		}

	print "EVAL\n";
	my $context = JavaScript::V8::Context->new();
	$context->bind_function(write => sub { print @_ });
	$content->bind_function(logMessage=> sub { });
	$content->bind_function(updateProductRecord=> sub { });
	$content->bind_function(makeUpdate=> sub { });
	$content->bind_function(saveNote=> sub { });
	## future:
	##		reachOutAndTouchSomeOne
	
	$context->eval(q~
		
	//	rp.rplog.as_string('Hello!!');
	// for (i = 1000; i > 0; i--) {
      for (i = 99; i > 0; i--) {
               write(i + " bottle(s) of beer on the wall, " + i + " bottle(s) of beer\n");
               write("Take 1 down, pass it around, ");
               if (i > 1) {
                   write((i - 1) + " bottle(s) of beer on the wall.");
               }
               else {
                   write("No more bottles of beer on the wall!");
               }
		
	//		rp.fire_event('spiffy instruction to reprice #'+i);
			}
		~);
	if ($@) {
		print Dumper($@);
		}
	return();
	}



__DATA__

my $thr = threads->create(FUNCTION, ARGS)




sub receiveBroadcast {
	my ($msg,$topic,$subscribed_topic) = @_;
	
	print Dumper($msg,$topic,$subscribed_topic);

	return();
	}

## Publish/Subscribe
#$redis->psubscribe("BROADCAST.*",\&receiveBroadcast);
my $timeout = 10;





__DATA__




