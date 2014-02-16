package PLATFORM::NGINXGW;



%PLATFORM::NGINXGW::CMDS = (
	'host-create'=>&PLATFORM::NGINXGW::nginx_host_create,
	'host-remove'=>&PLATFORM::NGINXGW::nginx_host_remove,
	'server-reload'=>&PLATFORM::NGINXGW::nginx_server_reload,
	'remove-user'=>&PLATFORM::NGINXGW::nginx_remove_user,
	);

sub new {
	my ($CLASS) = @_;
	my ($self) = {};
	bless $self, $CLASS;
	return($self);
	}


sub register_cmds {
	my ($self,$CMDSREF) = @_;
	foreach my $cmd (keys %PLATFORM::DNSSERVER::CMDS) {		
		print ref($self)." registered $cmd\n";
		$CMDSREF->{ $cmd } = $PLATFORM::DNSSERVER::CMDS{$cmd};
		}
	return();
	}





__DATA__

#!/usr/bin/perl

#
# to view a certificate details:
# openssl x509 -text -in /usr/local/etc/geotrust.pem
# openssl x509 -text -in /usr/local/etc/certs/secure.wlanparts.com.pem
#
#
# rapid ssl intermediate certificates
# https://knowledge.rapidssl.com/support/ssl-certificate-support/index?page=content&actp=CROSSLINK&id=AR1549
#

use File::Slurp;
use strict;
use LWP::Simple;
use YAML;
use Data::Dumper;
use POSIX qw (strftime);


use lib "/backend/lib";
use lib "/root/configs/lib";
use HOSTCONFIG;
use PLATFORM;
my @CLUSTERS = ();

my ($PLATFORM) = PLATFORM->new();

my @MSGS = ();
my @SSLCERTS = ();
require DBINFO;
foreach my $cluster (@{$PLATFORM->clusters()}) {

	my ($udbh) = &DBINFO::db_user_connect("\@$cluster");
	## we need to get the proper IP for each certificate
	my %DOMAIN_TO_IP = ();
	my $pstmt = "select IP_ADDR,DOMAIN from SSL_IPADDRESSES";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	
	while ( my ($IPADDR,$DOMAIN) = $sth->fetchrow() ) {
		$DOMAIN_TO_IP{lc($DOMAIN)} = $IPADDR;

		my $INT = $IPADDR; $INT =~ s/\.//gs;
		next if ($DOMAIN eq '');

		my $NETSTAT_OUTPUT = '';
		open IN, "/bin/netstat -e -Ilo:$INT|";
		while (<IN>) { $NETSTAT_OUTPUT .= $_; }
		close IN;

		if ($NETSTAT_OUTPUT !~ /inet addr\:/s) {
			## Interface not configure!
			print "ifconfig lo:$INT $IPADDR\n";
			system "/sbin/ifconfig lo:$INT $IPADDR netmask 255.255.255.255 up\n";
			
			$NETSTAT_OUTPUT = '';
			open IN, "/bin/netstat -e -Ilo:$INT|";
			while (<IN>) { $NETSTAT_OUTPUT .= $_; }
			close IN;
			}

		if ($NETSTAT_OUTPUT !~ /inet addr\:/s) {
			push @MSGS, "lo:$INT ip:$IPADDR is *STILL* not currently live.";
			}

		}
	$sth->finish();

	
	$pstmt = "select * from SSL_CERTIFICATES where ACTIVATED_TS>0 group by DOMAIN order by ACTIVATED_TS desc";
	$sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $cert = $sth->fetchrow_hashref() ) {

		$cert->{'CLUSTER'} = $cluster;
		$cert->{'IP_ADDR'} = $DOMAIN_TO_IP{lc($cert->{'DOMAIN'})};
		delete $DOMAIN_TO_IP{lc($cert->{'DOMAIN'})};		## we remove this from the list so we can add an http listener for anything else.

		next if ($cert->{'IP_ADDR'} eq '');

		my $date = strftime("%Y%m%d",localtime(time()));
		my $buffer = '';
		#	print Dumper($cert)."\n";
		$cert->{'DOMAIN'} = lc($cert->{'DOMAIN'});
  		next if ($cert->{'DOMAIN'} eq '');
  		#	print "$cert->{'IP_ADDR'}\n";
  		# next if ($cert->{'IP_ADDR'} !~ /^208\.74\.187\.([\d]+)$/);
  		my $LAST_IP_OCTET = $1;
	
	  	if (not defined $cert->{'PROVISIONED_GMT'}) {
			## date this ssl was provisioned (went live)
			$cert->{'PROVISIONED_GMT'} = &mysql_to_unixtime($cert->{'PROVISIONED_TS'});
			}
		if (not defined $cert->{'ACTIVATED_GMT'}) {
			## date this ssl was provisioned (went live)
			$cert->{'ACTIVATED_GMT'} = &mysql_to_unixtime($cert->{'ACTIVATED_TS'});
			}

	
		## LIVE IP WILL LOOK LIKE THIS:
		#lo:0      Link encap:Local Loopback
		#          inet addr:208.74.184.1  Mask:255.255.255.255
		#                    UP LOOPBACK RUNNING  MTU:16436  Metric:1
	
		mkdir("/var/local/certs");
		if (! -d "/var/local/certs") {
			die("can't create/use /var/local/certs");
			}
		chmod 0777, "/var/local/certs";
		my $file = sprintf("/var/local/certs/%s.pem",$cert->{'DOMAIN'});
		my $ERROR = undef;
	
		if ($cert->{'CERTTXT'} =~ /-----BEGIN PKCS #7 SIGNED DATA-----/) {
			## so the type PKCS #7 SIGNED DATA isn't understood by openssl, they see it as just a nested certificate
			## this apparently is as simple as replacing -----BEGIN PKCS #7 SIGNED DATA----- with -----BEGIN CERTIFICATE-----
			## and -----END PKCS #7 SIGNED DATA----- with -----END CERTIFICATE-----
			$cert->{'CERTTXT'} =~ s/PKCS #7 SIGNED DATA/CERTIFICATE/gs;
			print "CERT: $cert->{'DOMAIN'} appears to be p7b format, we'll convert to PEM\n";
			## NOTE: these files are /usr/local/etc/certs instead of /usr/local/nginx/certs
			my $P7BFILE = sprintf("/var/local/certs/%s.p7b",$cert->{'DOMAIN'});
			my $PEMFILE = sprintf("/var/local/certs/%s.cer",$cert->{'DOMAIN'});
			## write out the file we'll use for openssl
			open F, ">$P7BFILE"; 	print F $cert->{'CERTTXT'}; close F;
			# print "/usr/bin/openssl pkcs7 -print_certs -in $P7BFILE -out $PEMFILE\n";
			system("/usr/bin/openssl pkcs7 -print_certs -in $P7BFILE -out $PEMFILE");
			$cert->{'PKCS7TXT'} = $cert->{'CERTTXT'};
			$cert->{'CERTTXT'} = '';
			open F, "<$PEMFILE"; while(<F>) { $cert->{'CERTTXT'} .= $_; } close F;
			if ($cert->{'CERTTXT'} =~ /\-\-\-\-\-BEGIN CERTIFICATE\-\-\-\-\-/s) {
				unlink($P7BFILE);
				unlink($PEMFILE);
				}
			else {
				print Dumper($cert);
				die("Error converting $P7BFILE to $PEMFILE in PKCS #7 decode");
				}
			}
		
		if ($ERROR) {
			}
		elsif ($cert->{'CERTTXT'} !~ /-----BEGIN CERTIFICATE-----/) {
			print "CERT: $cert->{'CERTTXT'}\n";
			$ERROR = "$cert->{'DOMAIN'} CERTIFICATE MISSING ----BEGIN";
			}
		elsif ($cert->{'CERTTXT'} !~ /-----END CERTIFICATE-----/) {
			$ERROR = "$cert->{'DOMAIN'} CERTIFICATE MISSING ----END";
			}
		
		if ($ERROR) {
			}	
		elsif ($cert->{'KEYTXT'} !~ /-----END RSA PRIVATE KEY-----/) {
			$ERROR = "$cert->{'DOMAIN'} KEY MISSING ----END";
			}
		elsif ($cert->{'KEYTXT'} !~ /-----BEGIN RSA PRIVATE KEY-----/) {
			$ERROR = "$cert->{'DOMAIN'} KEY MISSING ----BEGIN";
			}

		 
		# print Dumper($cert);
		my $NGINX_CERT_FILE = sprintf("/var/local/certs/%s.pem",$cert->{'DOMAIN'});
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($NGINX_CERT_FILE);

		if ($ERROR) {
			die("$ERROR\n");
			}
		elsif (($size == 0) && ($ctime == 0)) {
			## same as saying ! -f $NGINX_CERT_FILE
			## no file, this is a new certificate
			print "NEWFILE: $NGINX_CERT_FILE\n";
			}
		elsif ($ctime > $cert->{'ACTIVATED_GMT'}) {
			## existing an .pem file already exists.
			}
		elsif ($ctime <= $cert->{'ACTIVATED_GMT'}) {
			## the file has been (RE)activated since it was written, so we'll back up the old one and then delete the existing one.
			print "KILLING: $NGINX_CERT_FILE\n";
			my $backupfile = sprintf("%s.%s",$NGINX_CERT_FILE,POSIX::strftime("%Y%m%d",localtime($mtime)));
			if (! -f $backupfile) {
				print "Made backup: $backupfile\n";
				system("/bin/cp -f $NGINX_CERT_FILE $backupfile");
				}
			unlink $NGINX_CERT_FILE;
			}
		else {
			## !?
			die("something went horribly wrong, this line should *never* be reached");
			}
		
		if (! -f $NGINX_CERT_FILE) {
			print "WRITING: $NGINX_CERT_FILE\n";
		 	open Fn, ">$NGINX_CERT_FILE";
	
			print Fn "# Key\n";
			print Fn $cert->{'KEYTXT'}."\n";
			print Fn "# Certificate\n";
			print Fn $cert->{'CERTTXT'}."\n";

			my ($txt) = '';
			($txt) = join("",File::Slurp::read_file("/root/configs/gw1/geotrust.pem"));
			# print Fn "$txt\n";
			print Fn "# Geotrust\n$txt\n";
			($txt) = join("",File::Slurp::read_file("/root/configs/gw1/20110225-rapidssl-primary-intermediate.txt"));
			# print Fn "$txt\n";
			print Fn "# RapidSSL Primary\n$txt\n";
			($txt) = join("",File::Slurp::read_file("/root/configs/gw1/20110225-rapidssl-secondary-intermediate.txt"));	
			# print Fn "$txt\n";
			# print Fn "# RapidSSL Secondary\n$txt\n\n";	
         print Fn "# Geotrust EV1\n$txt\n";
         ($txt) = join("",File::Slurp::read_file("/root/configs/gw1/20120901-geotrust-evssl.txt"));
         print Fn "\n";
			close Fn;	

			
			}
		$cert->{'PEMFILE'} = $NGINX_CERT_FILE;

		# push @{$NGINX_INCLUDES_REF}, [ $cert->{'USERNAME'}, $cert->{'IP_ADDR'},  $cert->{'DOMAIN'},  $NGINX_CERT_FILE,  lc($cert->{'CLUSTER'})  ];
		# NOTE: we really should bring up interfaces here.
		#system "/sbin/ifconfig lo:$int $1 netmask 255.255.255.255 up\n";

		push @SSLCERTS, $cert;
		}
	$sth->finish();	

	foreach my $domain (keys %DOMAIN_TO_IP) {
		next if ($domain eq '');
		push @SSLCERTS, { 'DOMAIN'=>$domain, 'IP_ADDR'=>$DOMAIN_TO_IP{$domain} };
		}

	&DBINFO::db_user_close();
	}


my %CACHE_ZONES = ();
foreach my $cert (@SSLCERTS) {
	my ($USERNAME) = $cert->{'USERNAME'};
	next if ($USERNAME eq '');
	next if $CACHE_ZONES{$USERNAME};
	
	mkdir "/disk1/proxy-$USERNAME";
	chmod 0777, "/disk1/proxy-$USERNAME";

	mkdir "/disk1/proxy-$USERNAME/tmp";
	chmod 0777, "/disk1/proxy-$USERNAME/tmp";

	$CACHE_ZONES{$USERNAME}++;
	}

my @MSGS = ();
print "writing /usr/local/nginx/conf/vstore-ssl.conf\n";
open F, ">/usr/local/nginx/conf/vstore-ssl.conf";

foreach my $USERNAME (keys %CACHE_ZONES) {
	print F qq~proxy_cache_path  /disk1/proxy-$USERNAME/ levels=1 keys_zone=$USERNAME:128m max_size=1024m inactive=1200m;\n~;
	}

foreach my $cert (@SSLCERTS) {
	# next unless ($cert->{'PROVISIONED_GMT'}==2);

	my ($USERNAME) = $cert->{'USERNAME'};
	my ($IP) = $cert->{'IP_ADDR'};
	my ($DOMAIN) = $cert->{'DOMAIN'};
	my ($PEM_FILE) = $cert->{'PEMFILE'};
	my ($CLUSTER) = $cert->{'CLUSTER'};

	next if ($USERNAME eq '');
	
	print F qq~
#
# $DOMAIN ($USERNAME.$CLUSTER)
#

	server {
		listen		$IP:80;			## we should eventually do these deferred
		server_name	$DOMAIN;
~;

	if ($cert->{'CERTTXT'} ne '') {
		print F qq~
		
		## BEGIN SSL
		listen			 $IP:443 ssl deferred;
		ssl_certificate		$PEM_FILE;
		ssl_certificate_key	$PEM_FILE;

		proxy_set_header X-SSL-Cipher \$ssl_cipher;
		proxy_set_header X-SSL-Protocol  \$ssl_protocol;
		proxy_set_header X-SSL-Session-Id   \$ssl_session_id;
		## END SSL
~;
		}

	print F qq~
		access_log		logs/$DOMAIN-access.log main;
		error_log		 logs/$DOMAIN-error.log;

		gzip on;
		gzip_disable "MSIE [1-6]\.(?!.*SV1)";
		gzip_vary on;

		keepalive_timeout	 75;

		### Set headers ####
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;		
		### Most PHP, Python, Rails, Java App can use this header ###
		proxy_set_header X-Forwarded-Proto \$scheme;

		location =	/__HEALTH__ {
			check_status;
			access_log   off;
			}

		location = /geotrust.html {
			proxy_pass	http://upstream-vstore;
			}

		location / {
 			### By default we don't want to redirect it ####
			proxy_redirect	 off;
			### force timeouts if one of backend is died ##
			proxy_next_upstream     error timeout invalid_header http_500 http_504;
			## 09/22/11 - proxy_connect_timeout   2;	  - think this is cause of 500, 504 issues on backend.
			proxy_connect_timeout   5;
			# default: proxy_read_timeout 60s; # apparently 60s is default, never tested
			proxy_ignore_client_abort on;	# 09/22/11
			proxy_temp_path 	/dev/shm;	# 09/22/11

			proxy_pass	http://upstream-vstore;
			gzip_types	text/javascript text/css text/xml;
			gzip_proxied	any;
		 	}

		location ^\~ /webapi/ {
			sendfile off;
			client_body_buffer_size  16K;
			client_max_body_size 16m;			## anysize is cool for file uploads (can be set to 0)
			proxy_pass   http://upstream-vstore;
			gzip_types	application/xml text/xml;
			gzip_proxied	any;
			}


		location ^\~ /media/ {
			## all other media files can be served from here:
			alias /httpd/static/;
			sendfile on;
			gzip off;
	
			location	\~	^/media/(img|merchant)/.*\$ {
				proxy_temp_path /disk1/proxy-$USERNAME/tmp;
		  		proxy_cache $USERNAME;
				proxy_cache_use_stale	updating timeout invalid_header error;
 				proxy_cache_valid  200 302  24h;
				proxy_cache_valid  301 404  10m;
				add_header X-NginxCache-Status \$upstream_cache_status;
				proxy_pass   http://upstream-static;
				gzip_types	application/x-javascript text/javascript text/css;
				gzip_proxied	any;
				}

		   location \~ ^/media/graphics/navbuttons/.*\$ {
  				root  /local/navbuttons;
		      error_page  404 = \@make_vstore_navbutton;
				gzip off;
  	   		}
			}

		location ^\~ /jquery/ {
			sendfile off;
			client_max_body_size 1m;			## anysize is cool for file uploads (can be set to 0)
			proxy_pass   http://upstream-vstore;
	
			gzip on;
			gzip_disable "MSIE [1-6]\.(?!.*SV1)";
			gzip_vary on;
			gzip_types	text/javascript text/css text/xml text/json application/json;
			gzip_proxied	any;
			}
		}
	~;



	}
close F;


print qq~
----- Next Steps: ----

# check the file:
/etc/init.d/nginx configtest

# now run -- this will startpound in the background.
/etc/init.d/nginx restart

# then check for errors:
tail -f /usr/local/nginx/logs/*.log

# you should see a request (eventually) ..

~; 

foreach my $msg (@MSGS) {
	print "$msg\n";
	}

##
##
# TODO:
# 
#	hitback zoovy on new domains
#	verify dns has been updated.
#

########################################
## MYSQL_TO_UNIXTIME
## Description: takes a mysql datetime (2001-08-13 21:47:15) and returns unixtime
## Accepts: mysql datetime
## returns: Unixtime
sub mysql_to_unixtime
{
        my ($datetime) = @_;

        if ((!defined($datetime)) || ($datetime eq '')) { return (''); }

        my ($y,$m,$d,$h,$mn,$s) = ();
        if (length($datetime)==14) {
                ## e.g. 20070315010000
                $y = substr($datetime,0,4);
                $m = int( substr($datetime,4,2) );
                $d = int( substr($datetime,6,2) );
                $h = int( substr($datetime,8,2) );
                $mn = int(substr($datetime,10,2) );
                $s = int( substr($datetime,12,2) );
                }
        else {
                ($y,$m,$d,$h,$mn,$s) = split(/[ \:\-]/,$datetime);
                }
        if ($y == 0) { return(0); }

        require Time::Local;
        $y -= 1900; $m--;

        if ($y>125) { $y = 125; $m = 1; $d = 1; $h = 0; $mn = 0; $s = 0; }
        return(Time::Local::timelocal($s,$mn,$h,$d,$m,$y));

#       print "$y $m $d $h $mn $s\n";
#       $y -= 1900; $y--; $m--; $d--;      # all mktime values start at zero.
        require POSIX;
        return(POSIX::mktime($s, $mn, $h, $d, $m, $y,undef,undef,0));

        require Date::Manip;
        return(&Date::Manip::Date_SecsSince1970GMT($m,$d,$y,$h,$mn,$s));
}

