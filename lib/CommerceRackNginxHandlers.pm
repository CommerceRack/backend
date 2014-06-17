package CommerceRackNginxHandlers;

use strict;
use nginx;
use Redis;
use CSS::Minifier::XS;
use POSIX qw (strftime);


## http://bloke.org/linux/minify-css-fly-nginx/
sub css_handler {
	my $r = shift;
	my $cache_dir="/tmp";
	my $cache_file=$r->uri;
	$cache_file=~s!/!_!g;
	$cache_file=join("/", $cache_dir, $cache_file);
	my $uri=$r->uri;
	my $filename=$r->filename;

   local $/=undef;

   return DECLINED unless -f $filename;

   open(INFILE, $filename) or die "Error reading file: $!";
   my $css = <INFILE>;
   close(INFILE);

   open(OUTFILE, '>' . $cache_file) or die "Error writing file: $!";
   print OUTFILE CSS::Minifier::XS::minify($css);
   close(OUTFILE);

   $r->send_http_header('text/css');
   $r->sendfile($cache_file);
   return OK;
	}

sub var_datettime { return(strftime("%Y%m%d%H%M%S",localtime(time())));  };
sub var_username { my $r = shift; return( uc( redis_hget( sprintf("domain+%s",lc($r->header_in("Host"))), "USERNAME" ) || "unknown" )); };
sub var_hosttype { my $r = shift; return( uc(redis_hget( sprintf("domain+%s",lc($r->header_in("Host"))), "HOSTTYPE" ) || "unknown" )); };
sub var_targetpath { 
	my $r = shift; 
	my $TARGETPATH = redis_hget( sprintf("domain+%s",lc($r->header_in("Host"))), "TARGETPATH" ) || "";
	
	return( $TARGETPATH ); 
	};

sub health_handler {
	my $r = shift;
	my $STATUS = undef;
	my @LINES = ();	
	#my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("/dev/shm/kevorkian");
	#if ($mtime < time()-300) { 
	#	## if the /dev/shm/kevorkian file is too old, we should force a status of UNHEALTHY
	#	push @LINES, "WARNING"; 
	#	push @LINES, ""; 
	#	push @LINES, "seems that /dev/shm/kevorkian last updated ".(time()-$mtime)." seconds ago!"; 
	#	push @LINES, ""; 
	#	}
	#open F, "</dev/shm/kevorkian";
	#while (<F>) { chomp($_); push @LINES, $_; }
	#close F;
	#my ($STATE) = shift(@LINES);
	my ($STATE) = ('OK');

	my $NAGIOS_STATE = 3;	
	# 0	OK	UP
	# 1	WARNING	UP or DOWN/UNREACHABLE*
	# 2	CRITICAL	DOWN/UNREACHABLE
	# 3	UNKNOWN	DOWN/UNREACHABLE
	if ($STATE =~ /(HAPPY|OK)/) { 
		$NAGIOS_STATE = 0; 
		}
	elsif ($STATE eq "WARNING") {
		$NAGIOS_STATE = 1;
		}
	else {
		$NAGIOS_STATE = 2;
		}

	$r->header_out("X-Nagios-Header"=>"$NAGIOS_STATE");
	$r->send_http_header("text/plain");
	$r->print(sprintf("%s\n", $STATE));
	$r->print(sprintf("Host: %s\n",&slurp("/proc/sys/kernel/hostname")));
	$r->print(sprintf("Load: %s\n",&slurp("/proc/loadavg")));
	foreach my $line (@LINES) {
		$line = lc($line);
		$r->print("$line\n");
		}	
	$r->print("\n\n");
	return OK;
	}


##
##
##
sub slurp {
	my ($file) = @_;
	$/ = undef; open F, "<$file"; my ($BUF) = <F>; close F; $/ = "\n";
	chomp($BUF);
	return($BUF);
	}

sub redis_hget {
	my ($REDIS_HKEY,$REDIS_HKEY_VAR) = @_;
	my ($redis) = Redis->new( server=>"127.0.0.1:6379", sock=>"/var/run/redis.sock", encoding=>undef );
	return $redis->hget($REDIS_HKEY,$REDIS_HKEY_VAR);
	}

1;