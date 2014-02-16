#!/usr/bin/perl


use Data::Dumper;
use Storable;
use strict;
use lib "/httpd/modules";
use CFG;
use POSIX;
use strict;
use File::Slurp;
use lib "/httpd/modules";
use DBINFO;
use DOMAIN;
use CFG;


my ($CFG) = CFG->new();

$::PATH = "/usr/local/nginx/conf/vhosts";
my %params = ();
foreach my $arg (@ARGV) {
	#if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}


use CFG;
use ZOOVY;

## SET HOSTS
#my ($zdbh) = &DBINFO::db_zoovy_connect();
#my ($CFG) = CFG->new();
#my $SERVERNAME = $CFG->get('global','hostname');
#my $qtSERVERNAME = $zdbh->quote($SERVERNAME);
#foreach my $USERNAME (@{$CFG->users()}) {
#   ## print Dumper($CFG)."\n";
#   my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#   my $pstmt = "update ZUSERS set CLUSTER=$qtSERVERNAME where MID=$MID";
#   print STDERR "$pstmt\n";
#   $zdbh->do($pstmt);
#   }
#&DBINFO::db_zoovy_close();


##
## rebuild the dns cache
##
## THIS WILL REBUILD THE /dev/shm/domainhost-detail.bin file


##
## create a list of interfaces 
##
my %USERS = ();
my %INTERFACES = ();
open IN, "/bin/netstat -ien | grep \"inet addr:\"|";
while (<IN>) { 
	if (/addr:(.*?) /) { $INTERFACES{$1}++; }
	}
close IN;


##
##
##
foreach my $USERNAME (@{$CFG->users()}) {
	print "USER:$USERNAME\n";
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	##
	##
	##
	$USERNAME = lc($USERNAME);
	my $NGINX_CONFIG_FILE = "$::PATH/$USERNAME.conf";
	print "CONFIG_FILE: $NGINX_CONFIG_FILE\n";
	open F, ">$NGINX_CONFIG_FILE";
	print F "# created ".&ZTOOLKIT::pretty_date(time(),1)."\n\n";
	close F;

	use DOMAIN::QUERY;
	my (@DOMAINS) = @{DOMAIN::QUERY::rebuild_cache($USERNAME)};

	##
	## 
	##
	my @HOSTS = ();
	foreach my $DOMAIN (@DOMAINS) {
		my ($D) = DOMAIN->new($USERNAME,$DOMAIN);

		## refresh DNS
		$D->update();

		print "WRITING $NGINX_CONFIG_FILE\n";
		open F, ">>$NGINX_CONFIG_FILE";
		print F "\n# DOMAIN: $D->{'DOMAIN'}\n";
		close F;

		## STEP1: find hosts
		foreach my $HOST (keys %{$D->{'%HOSTS'}}) {
			my $HOSTREF = $D->{'%HOSTS'}->{$HOST};

			my ($HOSTDOMAIN) = lc(sprintf("%s.%s",$HOST, $D->{'DOMAIN'}));
			my $IPADDR = $CFG->get("$HOSTDOMAIN","vip.private");

			my @MSGS = ();
			my $INT = $IPADDR; $INT =~ s/\.//gs;

			next if ($HOSTDOMAIN eq '');
			next if ($INT eq '');
			print "INT:$IPADDR ($HOSTDOMAIN)\n";

			my $SSL_CRT_FILE = sprintf("%s/%s.crt",&ZOOVY::resolve_userpath($USERNAME),lc($HOSTDOMAIN));
			if (! -f $SSL_CRT_FILE) { die("Need $SSL_CRT_FILE"); }

			my $SSL_CERT = File::Slurp::read_file($SSL_CRT_FILE);
			my $SSL_KEY_FILE = sprintf("%s/%s.key",&ZOOVY::resolve_userpath($USERNAME),lc($HOSTDOMAIN));
			if (! -f $SSL_KEY_FILE) { die("Need $SSL_KEY_FILE"); }

			my $SSL_KEY = File::Slurp::read_file($SSL_KEY_FILE);
			my $NETSTAT_OUTPUT = '';
			open IN, "/bin/netstat -e -Ieth0:$INT|";
			while (<IN>) { $NETSTAT_OUTPUT .= $_; }
			close IN;

			if ($NETSTAT_OUTPUT !~ /inet addr\:/s) {
				## Interface not configure!
				print "ifconfig eth0:$INT $IPADDR\n";
				system "/sbin/ifconfig eth0:$INT $IPADDR netmask 255.255.255.255 up\n";
	
				$NETSTAT_OUTPUT = '';
				open IN, "/bin/netstat -e -Ieth0:$INT|";
				while (<IN>) { $NETSTAT_OUTPUT .= $_; }
				close IN;
				}

			if ($NETSTAT_OUTPUT !~ /inet addr\:/s) {
				push @MSGS, "lo:$INT ip:$IPADDR is *STILL* not currently live.";
				}

			## 
			## SANITY: at this point IP address should be provisioned.
			## 
			my $date = strftime("%Y%m%d",localtime(time()));
			## LIVE IP WILL LOOK LIKE THIS:
			#lo:0      Link encap:Local Loopback
			#          inet addr:208.74.184.1  Mask:255.255.255.255
			#                    UP LOOPBACK RUNNING  MTU:16436  Metric:1
			my $file = "$::PATH/$HOSTDOMAIN.pem";
			my $ERROR = undef;
	
			#if ($SSL_CERT =~ /-----BEGIN PKCS #7 SIGNED DATA-----/) {
			#	## so the type PKCS #7 SIGNED DATA isn't understood by openssl, they see it as just a nested certificate
			#	## this apparently is as simple as replacing -----BEGIN PKCS #7 SIGNED DATA----- with -----BEGIN CERTIFICATE-----
			#	## and -----END PKCS #7 SIGNED DATA----- with -----END CERTIFICATE-----
			#	$SSL_CERT =~ s/PKCS #7 SIGNED DATA/CERTIFICATE/gs;
			#	print "CERT: $HOSTDOMAIN appears to be p7b format, we'll convert to PEM\n";
			#	## NOTE: these files are /usr/local/etc/certs instead of /usr/local/nginx/certs
			#	my $P7BFILE = sprintf("/var/local/certs/%s.p7b",$HOSTDOMAIN);
			#	my $PEMFILE = sprintf("/var/local/certs/%s.cer",$HOSTDOMAIN);
			#	## write out the file we'll use for openssl
			#	open F, ">$P7BFILE"; 	print F $SSL_CERT; close F;
			#	# print "/usr/bin/openssl pkcs7 -print_certs -in $P7BFILE -out $PEMFILE\n";
			#	system("/usr/bin/openssl pkcs7 -print_certs -in $P7BFILE -out $PEMFILE");
			#	## $PKCS7TXT = $SSL_CERT;
			#	$SSL_CERT = '';
			#	open F, "<$PEMFILE"; while(<F>) { $SSL_CERT .= $_; } close F;
			#	if ($SSL_CERT =~ /\-\-\-\-\-BEGIN CERTIFICATE\-\-\-\-\-/s) {
			#		unlink($P7BFILE);
			#		unlink($PEMFILE);
			#		}
			#	else {
			#		die("Error converting $P7BFILE to $PEMFILE in PKCS #7 decode");
			#		}
			#	}

			if ($ERROR) {
				}
			elsif ($SSL_CERT eq '') {
				}
			elsif ($SSL_CERT !~ /-----BEGIN CERTIFICATE-----/) {
				print "CERT: $SSL_CERT\n";
				$ERROR = "$HOSTDOMAIN CERTIFICATE MISSING ----BEGIN";
				}
			elsif ($SSL_CERT !~ /-----END CERTIFICATE-----/) {
				$ERROR = "$HOSTDOMAIN CERTIFICATE MISSING ----END";
				}
	
			if ($ERROR) {
				}	
			elsif ($SSL_KEY eq '') {
				}
			elsif ($SSL_KEY !~ /-----END RSA PRIVATE KEY-----/) {
				$ERROR = "$HOSTDOMAIN KEY MISSING ----END";
				}
			elsif ($SSL_KEY !~ /-----BEGIN RSA PRIVATE KEY-----/) {
				$ERROR = "$HOSTDOMAIN KEY MISSING ----BEGIN";
				}
		 
			# print Dumper($cert);
			my $PEM_FILE = "$::PATH/$HOSTDOMAIN.pem";
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($PEM_FILE);
		
			if ($ERROR) {
				die("$ERROR\n");
				}

			if (($SSL_KEY eq '') || ($SSL_CERT eq '')) {
				}
			elsif (! -f $PEM_FILE) {
				print "WRITING: $PEM_FILE\n";
			 	open Fn, ">$PEM_FILE";
	
				print Fn "# Key\n";
				print Fn $SSL_KEY."\n";
				print Fn "# Certificate\n";
				print Fn $SSL_CERT."\n";
				my ($txt) = '';		
				($txt) = join("",File::Slurp::read_file("/httpd/platform/ssl/geotrust.pem"));
				print Fn "# Geotrust\n$txt\n";
				($txt) = join("",File::Slurp::read_file("/httpd/platform/ssl/20110225-rapidssl-primary-intermediate.txt"));
				print Fn "# RapidSSL Primary\n$txt\n";
				($txt) = join("",File::Slurp::read_file("/httpd/platform/ssl/20110225-rapidssl-secondary-intermediate.txt"));	
				print Fn "# Geotrust EV1\n$txt\n";
		      ($txt) = join("",File::Slurp::read_file("/httpd/platform/ssl/20120901-geotrust-evssl.txt"));
				print Fn "\n";
				close Fn;
				}
	
			print "Append $NGINX_CONFIG_FILE data:$IPADDR\n";
			open F, ">>$NGINX_CONFIG_FILE";
			print F qq~
#
# $HOSTDOMAIN ($USERNAME)
#
server {
	listen 9000 ssl spdy;	## admin
	listen 443 ssl spdy;
	listen 80;

	server_name	$HOSTDOMAIN;

	## BEGIN SSL
	## NOTE: nginx will make the IP below the *default* server for this ip address
	ssl_certificate		$PEM_FILE;
	ssl_certificate_key	$PEM_FILE;

	gzip on;
	gzip_disable "MSIE [1-6]\.(?!.*SV1)";
	gzip_min_length  1000;
	gzip_vary on;
	gzip_proxied any;
	gzip_types	text/javascript text/css text/xml application/x-javascript application/javascript;

	include "commercerack-locations.conf";

	## END SSL
	}
	~;

			close F;
			}
		}

	&DBINFO::db_user_close();
	}


print "DONE!\n";