package SITE::health;

use Data::Dumper;
use Apache2::Const;

#sub transHandler { my ($r) = @_; print STDERR "GOT HERE TRANS!\n"; return(Apache2::Const::OK); }
#sub storageHandler { my ($r) = @_; print STDERR "GOT HERE STORAGE!\n"; return(Apache2::Const::OK); 	}

sub slurp {
	my ($file) = @_;
	$/ = undef; open F, "<$file"; my ($BUF) = <F>; close F; $/ = "\n";
	chomp($BUF);
	return($BUF);
	}


##
## this response handler is always run before SITE::vstore::responseHandler
##
sub responseHandler {
	my ($r) = @_;

	if ($r->uri() ne '/__health__') {
		return(Apache2::Const::DECLINED);
		}

	## the old "simple" ping approach
	# my ($ICMP_DISABLED) = int(&slurp("/proc/sys/net/ipv4/icmp_echo_ignore_all")); 
	# my $STATE = (not $ICMP_DISABLED)?'HAPPY':'SAD');

	my $STATUS = undef;
	


	my @LINES = ();	
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("/dev/shm/kevorkian");
	if ($mtime < time()-300) { 
		## if the /dev/shm/kevorkian file is too old, we should force a status of UNHEALTHY
		push @LINES, "WARNING"; 
		push @LINES, ""; 
		push @LINES, "seems that /dev/shm/kevorkian last updated ".(time()-$mtime)." seconds ago!"; 
		push @LINES, ""; 
		}

	open F, "</dev/shm/kevorkian";
	while (<F>) { chomp($_); push @LINES, $_; }
	close F;
	my ($STATE) = shift(@LINES);

	my $NAGIOS_STATE = 3;
	#0	OK	UP
	# 1	WARNING	UP or DOWN/UNREACHABLE*
	# 2	CRITICAL	DOWN/UNREACHABLE
	# 3	UNKNOWN	DOWN/UNREACHABLE
	if ($STATE =~ /(HAPPY|OK)/) { 
		$NAGIOS_STATE = 0; 
		}
	elsif ($STATE eq 'WARNING') {
		$NAGIOS_STATE = 1;
		}
	else {
		$NAGIOS_STATE = 2;
		}
	
	$r->headers_out()->add("X-Nagios-Header"=>"$NAGIOS_STATE");
	$r->content_type('text/plain');
	$r->print(sprintf("%s\n", $STATE));
	$r->print(sprintf("Host: %s\n",&slurp("/proc/sys/kernel/hostname")));
	$r->print(sprintf("Load: %s\n",&slurp("/proc/loadavg")));

	foreach my $line (@LINES) {
		$line = lc($line);
		$r->print("$line\n");
		}	

	#if ($STATUS !~ /OK|WARNING/) {
	#	return(Apache2::Const::HTTP_MISSING);
	#	}

	$r->print("\n\n");

	return(Apache2::Const::DONE);
	# return(Apache2::Const::HTTP_DONE);
	}


1;