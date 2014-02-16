#!/usr/bin/perl
use POSIX ();
use Net::Ping;
use Fcntl ':flock';

# use strict;


if (not &locklocal("kevmorkian","")) { 
	die "there can only be one!\n"; 
	}

#use lib "/root/configs/lib";
#use HOSTCONFIG;
use lib "/httpd/modules";
use PLATFORM;
use CFG;

my ($CFG) = CFG->new();

#ipcs -s | grep nobody | perl -e 'while (<STDIN>) { @a=split(/\s+/); print `ipcrm sem $a[1]`}' 
#http://www.goldfisch.at/knowledge/224
#my ($P) = PLATFORM->new();
#my $host = HOSTCONFIG::getHost(&HOSTCONFIG::whoami());
#my $host = $P->getHost();

my $hostname = `hostname`; chomp($hostname);

my %params = ();
foreach my $arg (@ARGV) {
	if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}

my $SLEEP=5;
my $NICE=-10;
my $AVG=3;
my $LOADAVG = 0;
my $LOADMAX = 25;

my $SWAPMAX = 300000;
my $SWAPTOTAL = int(`/usr/bin/free -o | /bin/grep "Swap" | /bin/cut -b 11-20`);
if ($SWAPTOTAL > 0) {
   ## CALIBRATE SWAPMAX TO 15% of AVAILABLE SWAP
   ## 20130401 - raised swapmax from 0.25 to 0.35%
   ## 20130426 - raised swapmax from 0.35 to 0.45%
   ## 20130427 - raised swapmax from 0.45 to 0.40%
   $SWAPMAX = int($SWAPTOTAL * 0.50);
   print "SWAPMAX CALIBRATED TO: $SWAPMAX\n";
   }

my $DAMPEN = 3;
my $LOG = "/var/log/kevorkian";
my $HELPER = "/var/run/kevorkian";
$::ISSUES_FILE = "/dev/shm/kevorkian";

my $DEBUG = $params{'debug'} || 0;

# Make swap less sticky
# http://kerneltrap.org/node/3000
# the higher the vm.swappiness value, the more the system will swap.
# vm.swappiness takes a value between 0 and 100 to change the balance between 
# swapping applications and freeing cache. At 100, the kernel will always prefer to 
# find inactive pages and swap them out; 
# open(SWAP, ">/proc/sys/vm/swappiness"); print SWAP "20\n"; close(SWAP);

sub daemon () {
	my $p;
	die "fork: $!" if (!defined($p = fork()));
	print STDERR "P:$p\n";
	exit(0) unless ($p == 0);
	chdir("/");
	open(STDIN, "/dev/null") or die "/dev/null: $!";
	open(STDOUT, ">/dev/null") or die "/dev/null: $!";
	for (my $fd = 3; $fd < POSIX::sysconf(POSIX::_SC_OPEN_MAX); ++$fd) {
		POSIX::close($fd);
		}
	POSIX::setsid() or die "setsid: $!";
	POSIX::nice($NICE);
	print STDERR "P2:$p\n";
	die "fork: $!" if (!defined($p = fork()));
	exit(0) if ($p != 0);
	print STDERR "P3:$p\n";
	open(STDERR, ">&STDOUT") or die "dup: $!";
	return();
	}

sub log {
	my ($msg) = @_;
	my @time = localtime(); $time[4]++;
	my $time = sprintf("%02d%02d-%02d:%02d:%02d", reverse(@time[0..4]));
	
	if ($DEBUG) {
		print STDERR "$time: $msg\n";
		} 
	else {
		open(L, ">>$LOG");
		print L "$time: $msg\n";
		close(L);
		}
	}

##
## creates a local lock in /var/run
##
sub locklocal {
	my ($LOCKID,$WHOAMI) = @_;
	$LOCKID =~ s/[^\w-]/_/gs;

	my $LOCK = "/var/run/$LOCKID";
	open(LOCK, ">>$LOCK") || die "Cannot open $LOCK: $!\n";
	unless (flock(LOCK,LOCK_EX|LOCK_NB)) {
		print STDERR "$0: Cannot open lock for pid=$$.\n";
      system("/usr/sbin/lsof $LOCK");
      exit 1;
      }
	}


die "You must be root to run this\n" unless $< eq '0';
die "\$AVG ($AVG) must be greater than 1\n" unless $AVG > 1;

## this doesn't work.. not sure why (i think because we daemonize)

#&daemon;

my $healthy = 1;
my $dampen = 0;

if (substr($0,0,1) eq '/') { $::SCRIPT_FILE = $0; } else { $::SCRIPT_FILE = "$ENV{'PWD'}/$0"; }
my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($::SCRIPT_FILE);
$::SCRIPT_CTIME = $ctime;

my $loop = 0;
while (1) {
	##
	## Everyone starts healthy until we can find out how they're sick.
	##
	my @ISSUES = ();
	$healthy = 1;

	#### see if we have a new version
	if ( ($loop++ % 10) == 0) {
		## every 250 loops we check to see if we are the most current version, if not - then we exit.
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($::SCRIPT_FILE);
		if ($::SCRIPT_CTIME != $ctime) {
			print "SCRIPT $::SCRIPT_FILE HAS NEW VERSION\n";
			last;
			}
		}
	

	#### Test load
	if ($healthy) {
		open(F, "/proc/loadavg");
		$_ = <F>;
		close(F);
		/^(\S+) (\S)+ (\S)+ ([0-9]+)\//o;
      my ($AVG1,$AVG2,$AVG3,$RUNNING_PROCS) = ($1,$2,$3,$4);
      $LOADAVG = sprintf("%0.1f", ($AVG1+$AVG2)/2);
		if ($LOADAVG > $LOADMAX) {
			push @ISSUES, "Load average $LOADAVG > $LOADMAX ($AVG cycles @ $SLEEP sec)";
			$healthy = 0;
			}
		}

	if (0) {
		}
	elsif ($healthy) {
      ## we use a rand below so that all the servers don't drop out of rotation at the same time
		my @FILES = (
			# { file=>'/dev/shm/domainhost-detail.bin', maxage=> 4000+ ((rand()*$$)%4000) },
			);
		
		foreach my $fref (@FILES) {
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($fref->{'file'});
			my $age = time()-$mtime;
			if ((defined $fref->{'maxage'}) && ($fref->{'maxage'}>0) && ($fref->{'maxage'}<$age)) {
				push @ISSUES, "$fref->{'file'} is $age seconds old but maxage is:$fref->{'maxage'}";
				$healthy = 0;
				}
			}
		
		}

	#### Test swap (if not already)
	if ($healthy) {
		open(F, "/proc/meminfo");
		$total=$free=-1;
		while (<F>) {
			next unless /^Swap(Total|Free):\s+([0-9]+)/o;
			$total=$2 if $1 eq 'Total';
			$free=$2 if $1 eq 'Free';
			}
		close(F);
		$swap=$total-$free;
		if ($swap > $SWAPMAX) {
			push @ISSUES, "Swap usage $swap > $SWAPMAX";
			$healthy = 0;
			}
		}

	#### Test async input status
	if ($healthy) {
		if (-f $HELPER) {
			open(F, $HELPER);
			while (<F>) {
				chop;
				push @ISSUES, "Helper says: $_";
				$healthy = 0;
				}
			close(F);
			}
		}

	### Make sure we can read/write to the local filesystems
	$tmp = "kevorkian.$$." . time();
	foreach $fs ("/dev/shm","/tmp","/local/tmp") {
		if (open(F, ">$fs/$tmp")) {
			$NLINES=500;
			for $i (1..$NLINES) { print F "$i: $tmp\n"; }
			close(F);
			unless(open (F, "$fs/$tmp")) {
				push @ISSUES, "Cannot open/read $fs/$tmp: $!";
				$healthy = 0;
				}
			$i=0;
			while (<F>) { $i++ if /: $tmp$/; }
			close(F);
			if ($i < $NLINES) {
				push @ISSUES, "Did not read full file $fs/$tmp ($i/$NLINES)";
				$healthy = 0;
				}
		} else {
			push @ISSUES, "Cannot write to $fs/$tmp: $!";
			$healthy = 0;
			}
		unlink("$fs/$tmp");
		}

	#### Make sure httpd is running
	if ($healthy) {
  		my @PIDFILES = (
			#[ 'uwsgi-jsonapi', '/var/run/uwsgi-jsonapi.pid' ],
			#[ 'uwsgi-static', '/var/run/uwsgi-static.pid' ],
			#[ 'mysql', "/var/lib/mysql/$hostname.pid" ],
			[ 'memcache', '/var/run/memcached/memcached.pid' ],
			[ 'redis', '/var/run/redis.pid' ],
			# [ 'apache', '/local/httpd/logs/httpd.pid' ], 
			#[ 'elasticsearch', '/usr/local/elasticsearch/bin/service/elasticsearch.pid' ],
			);

		foreach my $line (@PIDFILES) {
			my ($APP,$PIDFILE) = @{$line};

			my $IF_FIXABLE = 0;
			my $pid = 0;
			if (-f $PIDFILE) {
				## print "$PIDFILE\n";
				open(F, "$PIDFILE"); $pid = <F>; close(F); chop $pid;
				}

			if (not $pid) {
				push @ISSUES, "$APP file $PIDFILE does not exist";	 $IF_FIXABLE++; 
				$healthy = 0;				
				}
			elsif (-f "/proc/$pid/cmdline") {
				## this file contains which program it is
				}
			else {
				push @ISSUES, "$APP pid $pid in $PIDFILE not in /proc/$pid!"; $IF_FIXABLE++;
				}

			if (($IF_FIXABLE) && ($APP eq 'mysql')) {
				push @ISSUES, "RESTART mysql\n";
				system("/etc/init.d/mysql start");
				}

			#if (($IF_FIXABLE) && ($APP eq 'apache')) {
			#	## http://www.goldfisch.at/knowledge/224
			#	&log("flushed shared memory");
			#	system(q~/usr/bin/ipcs -s | /bin/grep nobody | /usr/bin/perl -e 'while (<STDIN>) { @a=split(/\s+/); print `/usr/bin/ipcrm sem $a[1]`}'~); 
			#	system("/httpd/bin/apachectl start");
			#	}

			if (($IF_FIXABLE) && ($APP eq 'memcache')) {
				system("/etc/init.d/memcached start");
				}

			if (($IF_FIXABLE) && ($APP eq 'elasticsearch')) {
				system("cd /usr/local/elasticsearch/bin/service; ./elasticsearch start");
				}

			}
		}

	if ($healthy) {
		my @NAGIOS = (
			[ 'check_disk', '/usr/lib64/nagios/plugins/check_disk -l -c 10%' ],
			[ 'check_load', '/usr/lib64/nagios/plugins/check_load -w 10,9,8 -c 20,15,10' ],
			[ 'check_mysql_query', '/usr/lib64/nagios/plugins/check_mysql_query -q "show processlist";' ],
			);
		foreach my $row (@NAGIOS) {
			my ($check,$cmd) = @{$row};
			my $output = '';
			open MH, '-|', "$cmd"; while(<MH>) { $output .= $_; } close MH; chomp($output);
			## my $output = qx{/usr/local/libexec/nagios/check_users2 -w 100 -c 500};
			## my $status = $? > 0 ? $? >> 8 : 3;
			my @TOKENS = split(/[\-\:]+/, $output); 
			## print "NAGIOS: $output\n";
			if ($TOKENS[0] =~ /OK/) { } 	## woot!
			elsif ($TOKENS[0] =~ /CRITICAL/) { push @ISSUES, $output; $healthy = 0; };
			}
		}

	#if (-f "/dev/shm/restart-server.txt") {
	#	## create this file, put a "reason" message in it, and then push it! 
	#	## server will randomly wait up to Length(msg) seconds before restarting to hopefully avoid
	#	## all servers going offline at the same time - thus = more detailed reasons = better!
	#	open F, "</dev/shm/restart-server.txt"; $/ = undef; my ($reason) = <F>;	close F; $/ = "\n";
	#	if ($reason eq '') { $reason = "reason not specified"; }
	#	my $wait = int(rand(length($reason)+1 * $$));
   #   if ($wait > 60) { $wait = $wait % 60; }	## never wait more than 60 seconds
   #   
   #   ## immediately take it out of rotation
	#	$reason = "restart-server/$reason/wait($wait)";
   #   		
	#	## make sure we remove the file in case something goes horribly wrong!
	#	unlink("/dev/shm/restart-server.txt");
	#	if (! -f "/dev/shm/restart-server.txt") {
	#		sleep($wait);
   #		open(F, ">/proc/sys/net/ipv4/icmp_echo_ignore_all");
   #   	print F "$wait";
	#   	close(F);
   #      sleep(5);
	#		$healthy = 0;
	#		}
	#	}

#	## check port 80 to see that it's responding.
#	if ($host->{'ip'} ne '') {
#		$p = Net::Ping->new("tcp", 2);
#		# Try connecting to the www port instead of the echo port
#		$p->{'port_num'} = getservbyname("http", "tcp");
#		if (not $p->ping($host->{'ip'})) { $healthy = 0; }
#		undef($p);
#		}


	&log("healthy=$healthy load=$LOADAVG/$LOADMAX swap=$swap/$SWAPMAX dampen=$dampen");

	#### Enable or disable server based on result
	## status can be one of three settings
	##		 'active' - services are running
	##		 'wait' = waiting to go active (check)
	##		 'dead' = stopped
	## $dampen is the number of seconds.
	##
	if ($healthy) {
		open(F, ">/proc/sys/net/ipv4/icmp_echo_ignore_all"); print F "0";	close(F);
		open F, ">$::ISSUES_FILE"; print F "OK;\n\n"; close F;
		}
	else {
		open(F, ">/proc/sys/net/ipv4/icmp_echo_ignore_all"); print F "1";	close(F);
		open F, ">$::ISSUES_FILE";
		print F "CRITICAL;\n\n";
		foreach my $issue (@ISSUES) {
			&log("ISSUE: $issue");
			print F "$issue\n";
			}
		close F;
		&log("Set ICMP ignore");
		sleep($SLEEP*$DAMPEN);
		}

	sleep $SLEEP;
	}

