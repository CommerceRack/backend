#!/usr/bin/perl

use strict;
use encoding 'utf8';		## tells us to internally use utf8 for all encoding
use locale qw();  
use utf8 qw();
use Encode qw();
use JSON::XS;

use URI::Escape::XS qw();
use HTTP::Date qw();
use Data::Dumper;
use POSIX;
use Image::Magick qw();
use Plack::Request;
use Plack::Response;
use MIME::Types qw();
use URI::Split;

use URI::Split;
use POSIX qw(locale_h);
use Storable;
use Data::Dumper;
use Cache::Memcached::libmemcached;

use lib "/httpd/modules";
require SITE;
require CART2;
require CUSTOMER;
require ZTOOLKIT;
require DBINFO;
require DOMAIN;
require PAGE;
require PAGE::HANDLER;
require DOMAIN::TOOLS;
require PRODUCT;

use lib "/httpd/modules";
require ZWEBSITE;
require ZOOVY;
require MEDIA;
require NAVBUTTON;
require SITE::health;
require File::Slurp;

## both necessary for RSS
require DOMAIN::TOOLS;
require DOMAIN::QUERY;
require WHOLESALE;
require JSONAPI;
require HTTP::Headers;
require TOXML;

## http://search.cpan.org/CPAN/authors/id/M/MI/MIYAGAWA/Plack-Middleware-ReverseProxy-0.15.tar.gz

my $app = sub {
	my $env = shift;

	my $HEADERS = HTTP::Headers->new;
	my $req = Plack::Request->new($env);

	my $BODY = undef;
	my $HTTP_RESPONSE = undef;

	$SITE::v       = {}; ## Implicitly lowercase keyed hash of passed GET/POST vars with scalar value (UNTAINTED)
	$SITE::v_mixed = {}; ## ACtual case keyed hash of passed GET/POST vars with scalar values			  (TAINTED)

	$HEADERS->push_header( 'X-Powered-By' => 'ZOOVY/v.'.&ZOOVY::servername() );
	
	if (defined $HTTP_RESPONSE) {
		## we're already done! (probably an error)
		}
	else {
		## NOTE: this code is mirrored in SITE::Vstore
		$HEADERS->push_header( "X-XSS-Protection" => 0 );
		$HEADERS->push_header( 'Access-Control-Allow-Origin' => '*' );
		$HEADERS->push_header( 'Access-Control-Allow-Methods' => 'POST, HEAD, GET, OPTIONS' );
		$HEADERS->push_header( 'Access-Control-Max-Age' => 0 );
		$HEADERS->push_header( 'Access-Control-Allow-Headers' => 'Content-Type, x-authtoken, x-version, x-clientid, x-deviceid, x-userid, x-domain' );
		$HEADERS->push_header( 'Vary' => 'Accept-Encoding' );

		## print STDERR "GOT OPTIONS REQUEST\n";
		## SHORT CIRCUIT
		my $h = $req->headers();
		foreach my $k (split(/,/,$h->header('access-control-allow-headers'))) {
			next if ($k eq 'content-type');
			next if ($k eq 'x-auth');
			next if ($k eq 'x-authtoken');
			}
		$HEADERS->push_header( 'Keep-Alive' => 'timeout=2, max=100' );
		$HEADERS->push_header( 'Connection' => 'Keep-Alive' );
		
		if ($req->method() eq 'OPTIONS') {
			$HTTP_RESPONSE = 200;
			$HEADERS->push_header( 'Allow' => 'GET,HEAD,OPTIONS,POST' );
			$HEADERS->push_header( 'Access-Control-Max-Age' => 1000 );
			$HEADERS->push_header( 'Content-Length' => 0 );
			$HEADERS->push_header( 'Content-type' => 'text/plain' );
			print STDERR Dumper($HEADERS);
			my $res = Plack::Response->new($HTTP_RESPONSE,$HEADERS,"");
			## short circuit!
			return($res->finalize);
			}
		}
		

	my $AGE = (86400*45);
	my $DNSINFO = undef;
	my $SITE = undef;
	$SITE::HANDLER = undef;
	$SITE::CART2 = undef;
	my $DESIGNATION = undef;
	my $URI = $req->uri();
	my ($HOSTDOMAIN) =  $URI->host();

	## COPY ENVIRONMENT VARIABLES (TO EMULATE OLD APACHE BEHAVIOR)
   delete $ENV{'HTTP_REFERER'};     ## WE *MUST* NUKE THIS OR ELSE IT CAN BLEED OVER (BECAUSE ITS NOT ALWAYS SET)
   delete $ENV{'REQUEST_URI'};
	delete $ENV{'HTTP_COOKIE'};

	my $psgienv = $req->env();
	foreach my $k (keys %{$psgienv}) { 
		if ($k eq uc($k)) { 
			$ENV{$k} = $env->{$k}; 
			}
		}
	$ENV{'SERVER_NAME'} = $ENV{'HTTP_HOST'};	## not sure why PSGI doesn't define SERVER_NAME

	if (defined $HTTP_RESPONSE) {
		}
	else {
		if ($HOSTDOMAIN =~ /^([a-z0-9\-]+)\.app-hosted\.com$/) {
			$HOSTDOMAIN = &ZWEBSITE::checkout_domain_to_domain($HOSTDOMAIN);
			}
		($DNSINFO) = &DOMAIN::QUERY::lookup($HOSTDOMAIN,'verify'=>1);
		}

	my $v = {};
	if (defined $HTTP_RESPONSE) {
		## we're already done! (probably an error)
		}
	else {
		## parse 
		if ((defined $req) && ($req->method() eq 'HEAD')) {};		## TODO: add support for HEAD
		setlocale("LC_CTYPE", "en_US");

		## This handles a POST
		my $params = $req->parameters();
		foreach my $k ($params->keys()) {
			#my ($x) = $params->get($k);		## this munges data with ; in it!
			my ($x) = $req->param($k);

			if (utf8::is_utf8($x) eq '') {
				## NOTE: this is specifically intended to correct situations where some clients post to us
				##			in ISO-8859-1 from a UTF8 form field.
				$x = Encode::decode("utf8",$x);
				utf8::decode($x);
				}

			# http://www.joelonsoftware.com/articles/Unicode.html
			# should probably check $ENV{'CONTENT_TYPE'} =~ /UTF-8/)
			if ($req->content_type() =~ /[Uu][Tt][Ff][-]?8/o) {
		 		$x = Encode::encode_utf8($x); ## added 6/21/12 -- not sure of all the impacts it will have!
				}
			$v->{$k} = $x;
			}
		
		if (scalar(keys %{$v})==0) {
			if ($req->raw_body()) {
				## might be a good type to check the content type, or at least structure!
				$v = JSON::XS::decode_json($req->raw_body());
				}
			}

		## VSTORE compat.
		foreach my $k (keys %{$v}) {
			$SITE::v->{lc(&SITE::untaint($k))}       = &SITE::untaint($v->{$k}); # removes unwanted xss attack vectors
			$SITE::v_mixed->{$k}     = $v->{$k};					  # avoid using this unless you need non-translated vars (e.g. pogs)
			}
		}


	
	if (not defined $HTTP_RESPONSE) {

		## we need to use a global handle because we don't know what cluster we' in (at the moment)
		## eventually PLATFORM can save us?!
		my $MEMD = &ZOOVY::getGlobalMemCache();
		my $TS = time();
		my $SCORE = 0;
		my $PATH_INFO = $req->path_info();
	
		## PHASE1: some initialization stuff
		my $IP = $req->address();
		if (defined $DESIGNATION) {
			}
		elsif ($PATH_INFO =~ /\.([Jj][Ss]|[Gg][Ii][Ff]|[Pp][Nn][Gg]|[Cc][Ss][Ss]|[Ii][Cc][Oo]|[Jj][Pp][Gg])$/) {
			## well known file type (always okay)
			# we don't record history on these types of static files.
			$DESIGNATION = [ '*PASS', 'allowed filetype' ];
			}
		elsif (not defined $IP) {
			}
		elsif ($ENV{'HTTP_USER_AGENT'} =~ /80legs/) {
			## yeah, fuck these guys .. watch this, i can ddos a site too
			$DESIGNATION = [ 'KILL', '80legs' ];
  	    	}
		elsif ($PATH_INFO =~ /^[\/]+(jquery|ajax|media)/) {
			$DESIGNATION = [ '*PASS', '' ];
			}
		elsif ($PATH_INFO =~ /\/(jquery|jsonsapi|ajax|media)\/$/) {
			## /s=www.toynk.com/jquery/
			$DESIGNATION = [ '*PASS', '' ];
			}
		elsif ($SITE::Vstore::DISABLE_BOT_DETECTION) {
			$DESIGNATION = [ 'SAFE' ];
			}
		elsif (($PATH_INFO eq '/robots.txt') || ($PATH_INFO eq '/sitemap.xml')) {
			## yipes, it's a robot!
			# we don't record history on these types of static files.
			$DESIGNATION = [ 'BOT', $PATH_INFO ];
			if (defined $MEMD) {
				$MEMD->set("IP:$IP","BOT",3600*3);
				}
			}
		else {
			## see if we've already judged this ip.
			my $LOOKUP = undef;
			if (defined $MEMD) {
				($LOOKUP) = $MEMD->get( "IP:$IP" );
				}

			if (defined $LOOKUP) {
				$DESIGNATION = [ $LOOKUP, "IP-LOOKUP: $IP" ];
				if (defined $MEMD) {
					## refresh the timeout
					$MEMD->set("IP:$IP",$LOOKUP,300);
					}
				}
	
			if (not defined $LOOKUP) {
				## nothing in memcache.. check our embedded list of offenders.
				my ($RESULT) = SITE::whatis($IP,$ENV{'HTTP_USER_AGENT'},$ENV{'SERVER_NAME'},$ENV{'REQUEST_URI'}); 
	
				if ($RESULT eq 'SAFE') { $RESULT = '*PASS'; }
				elsif ($RESULT eq 'DENY') { $RESULT = 'KILL'; }
				elsif ($RESULT eq 'BOT') { $RESULT = 'BOT'; }
				elsif ($RESULT eq 'SCAN') { $RESULT = 'SCAN'; }
				elsif ($RESULT eq 'SCAN-POSITIVE') { $RESULT = 'SCAN'; }
				elsif ($RESULT eq 'WATCH') { $RESULT = undef; $SCORE += 2; }
				elsif ($RESULT eq 'BOT-POSITIVE') { $RESULT = 'BOT'; }
				elsif ($RESULT eq '') { $RESULT = undef; }
				else {
					warn "UNKNOWN SITE::whatis value '$RESULT'\n"; 
					$RESULT = undef;
					} 

				if (defined $RESULT) {
					## make sure we don't have to read from the file again.
					$DESIGNATION = [ $RESULT, "SITE-WHATIS: $IP,$ENV{'HTTP_USER_AGENT'},$ENV{'SERVER_NAME'},$ENV{'REQUEST_URI'}" ];
					$MEMD->set("IP:$IP",$RESULT,3600);
					}
				}
	
			}

		if (defined $DESIGNATION) {
			}
		elsif ($SITE::Vstore::DISABLE_BOT_DETECTION) {
			}
		elsif (not defined $IP) {
			warn "NO IP SET, CANT DO BOT DETECTION\n";
			}
		elsif ($MEMD) {
			## lookup the IP history
			my $HISTORY = $MEMD->get( "$IP/HISTORY" );
			if (not defined $HISTORY) { $HISTORY = ''; }
			my $i20 = 0 + $SCORE;
			my $i60 = 0 + $SCORE*5;
			foreach my $line (split("\n",$HISTORY)) {
				my ($HTS,$HURI) = split(/\|/,$line);
				if ($HTS==0) { $HTS = $TS; } 	## 0 timestamps always count as current time 
				$i20 += ($HTS+20 >= $TS)?1:0;
				$i60 += ($HTS+60 >= $TS)?1:0;
				# print STDERR "==> HISTORY[".($HTS-$TS)."] $line\n";
				}
	
			if ($i20>60) {
				## raised from 40 to 60 on 2/22/12
				$DESIGNATION = [ "KILL", "I20:$i20" ];
				}
			elsif ($i20>30) {
				## raised from 10 to 12 on 11/29/12
				## raised from 12 to 15 on 12/5/12
				## raised from 15 to 20 on 12/8/12
				## raised from 20 to 30 on 2/22/12
				$DESIGNATION = [ "BOT", "I20:$i20" ];
				}
			elsif ($i60>80) {
				$DESIGNATION = [ "BOT", "I60:$i60" ];
				}
	
			($HISTORY) = sprintf("%s|%s\n%s",$TS,substr($PATH_INFO,0,35),substr($HISTORY,0,5000));	# always truncate history at 4k.
			if (not $MEMD->set( "$IP/HISTORY", $HISTORY, 86400 )) {
				print STDERR "COULD NOT STORE HISTORY\n";
				}
	
			if ($DESIGNATION) {
				my $STATS = "i20:$i20 i60:$i60 [$DESIGNATION->[0] $DESIGNATION->[1]]";
				print STDERR "IP:$IP $STATS\n";
				}
			}

		if ($DESIGNATION->[0] eq 'SCAN') {
			my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
			## security scans are allowed between before 7am and after 8pm
			if ($hour > 7 && $hour < 20) { $DESIGNATION->[0] = 'KILL'; }
			}

		if ($DESIGNATION->[0] eq 'KILL') {
			$HTTP_RESPONSE = 500;
			}
		if ($DESIGNATION eq 'BOT') { 
			open F, "</proc/loadavg"; my ($line) = <F>; close F;
			my ($AVG1) = split(/[\s\t]+/,$line);
			if ($AVG1>7) { 	
				$DESIGNATION = 'KILL'; 
				}
			}
		}

	
	if (defined $HTTP_RESPONSE) {
		}
	elsif (not defined $DNSINFO) {
		$SITE::HANDLER = [ 'ISE', { 'ERROR'=>"DNSINFO not set." } ];
		}
	else {

		($SITE) = SITE->new($DNSINFO->{'USERNAME'}, '%DNSINFO'=>$DNSINFO );

		$SITE->{'_is_site'} |= 0xFF; 	## this is ALWAYS *IS* SITE = true
		$SITE->{'+server'} =  $ENV{'SERVER_NAME'};
		$SITE->{'+server'} =  (defined $ENV{'SERVER_NAME'})?lc($ENV{'SERVER_NAME'}):'';
		## server_name is our first hint at what we're doing.
		##		www.domain.com -- etc.

		$SITE->{'+secure'} |= ($ENV{'SERVER_PORT'}==443) ? 1 : 0;	

		## BUT THE LINES BELOW SHOULD WORK GREAT!
		## NOTE: ENV not setup yet -- can't do $SITE->{'+secure'} |= ($ENV{'X-Forwarded-Proto'} eq 'https') ? 1 : 0;
		my $h = $req->headers();
		$SITE->{'+secure'} |= ($h->header('X-Forwarded-Proto') eq 'https') ? 1 : 0;
		$SITE->{'+secure'} |= ($h->header('X-SSL-Protocol') eq 'TLSv1') ? 1 : 0; 
		$SITE->{'+secure'} |= ($h->header('X-SSL-Cipher') ne '') ? 1 : 0;

		$ENV{'HTTPS'} = ($SITE->{'+secure'})?'on':'';			## FOR SITE::URL / IMAGE::URL **VERY IMPORTANT**

		$SITE->{'+uri/_'} = $SITE->{'+uri'} = $req->path_info();
		if ($SITE->{'+uri'} =~ /\/c[=\~](.*?)\//) {
			$SITE->{'+uri/cartid'} = $1;
			$SITE->{'+uri'} =~ s/\/c[=\~](.*?)\//\//;	# strip /s=1234234
			}

		if ($SITE->{'+uri'} =~ /\/s[=\~](.*?)\//) {
			# print STDERR "GRABBED SDOMAIN FROM URI: $SITE->{'+uri'}\n";
			## SDOMAIN: should be www.domain.com, app.domain, etc.
			## could also be __username.prt.profile__
			$SITE->{'+uri/sdomain'} = $1;
			$SITE->{'+uri'} =~ s/\/s[=\~](.*?)\//\//;	# strip /s=1234234
			if ($SITE->{'+uri'} =~ /s=(.*?)\//) {
				## deals with %SESSION% see ticket #2286735 -- sometimes the rewrite engine adds /s= and the customer
				## has specified /s= .. i realize what a bad idea this is, once toxml is removed we can strip this line.
				$SITE->{'+uri'} =~ s/s=(.*?)\///;
				}
			}

		## SANITY: at this point the following is true:
		##		+uri/_ 			=> the full (unmodified) uri
		##		+uri/sdomain	=> the sdomain found on the uri
		##		+uri/cartid		=> the cartid found on the uri


		my $LOGREF = undef;

		if ( $ENV{'SERVER_NAME'} =~ /^([a-z0-9\-]+)\.app-hosted\.com$/) {
			 $ENV{'SERVER_NAME'} = &ZWEBSITE::checkout_domain_to_domain( $ENV{'SERVER_NAME'});
			}
	
		if ($SITE->{'+uri'} =~ /\.html$/o) {
			}

		if (defined $DNSINFO) {	
			&SITE::insert_dnsinfo($SITE,$DNSINFO);
	
			$HEADERS->push_header('X-App',sprintf("host:%s.%s user:%s prt:%s profile:%s",$SITE->{'HOST'},$SITE->{'DOMAIN'},$SITE->{'_USERNAME'},$SITE->{'+prt'},$SITE->{'_NS'}));
			$SITE->{'*CART2'} = $SITE::CART2;	
			## *MSGS and *TXSPECL SHOULD BE SET SPECIFICALLY INSIDE OF legacyResponseHandler -- ** NOT HERE **
			#$SITE->{'*TXSPECL'} = $SITE::txspecl;
			}
		else {
			$HEADERS->push_header('X-App',sprintf("DNSINFO NOT DEFINED"));
			$SITE->{'+broked+'} = 'DNSINFO NOT DEFINED';
			}
		# $SITE->{'REMOTE_ADDR'} = $r->connection()->remote_ip();
		$SITE->uri($SITE->{'+uri'});	

		if (defined $SITE) {
			$SITE->client_is( $DESIGNATION->[0] );
			}
		else {
			print STDERR "*WARN NO SITE OBJECT == DESIGNATION: $DESIGNATION->[0]\n";
			}
		}


	my $LOGREF = undef;
	if (defined $LOGREF) { push @{$LOGREF}, "+URI: ".$SITE->uri(); }
	
	##
	## SANITY: at this point +sdomain_from_uri, and +cartid_from_uri and the +uri has them stripped. 
	##
	## SANITY: at this point +sdomain is the name of the domain we're on (or the rewritten equivalent)
	## SANITY: at this point $DNSINFO is set, or we're going to do return a 404/ise

	##
	## SANITY: at this point:
	##		$SREF{'+secure'} is set to true false
	##		$SREF{'+sdomain'} is set to the working domain (we'll pretend we're on)
	##

	## okay, so now we look in the url for a real sdomain, if we find one, we'll serve that.
	if (ref($SITE) ne 'SITE') {
		$SITE::HANDLER = [ 'ISE', { 'ERROR'=>"NON-SITE OBJECT AT TRANSHANDLER" } ];
		}
	elsif (($SITE->mid()>0) && ($SITE->username() ne '')) {
		$DNSINFO = $SITE->dnsinfo();
		########################################
		## CHECK FOR STORE CLOSURE
		if ((defined $SITE->globalref()->{'closed'}) && ($SITE->globalref()->{'closed'}>0)) {
			$BODY = "SITE IS CLOSED.";
			$HTTP_RESPONSE = 200;
			$SITE::HANDLER = [ 'DONE', {} ];
		   }
		$SITE::Vstore::DEBUG++;
		$SITE::Vstore::DEBUG && print STDERR "SITE->client_is()=\'".$SITE->client_is()."\' SITE->domain_host()->\'".$SITE->domain_host()."\'\n";
		}
	else {
		$SITE::HANDLER = [ 'ISE', { 'ERROR'=>"Could not find requested user." } ];
		}

	if (not defined $SITE::HANDLER) {
		print STDERR sprintf("HOST:%s TAIL:%s MECHANT:%s PRT:%d SDOMAIN:%s IP:%s DEN:%s\n",$SITE->domain_host(), $SITE->domain_only(),$SITE->username(),$SITE->prt(),$SITE->sdomain(),$SITE->ip_address,$DESIGNATION->[0]);
		}

	## 
	## AT THIS POINT $SITE IS guaranteed to be set, and iether _iz_broked or other properties (via DNSINFO) are set
	## 

	if (defined $HTTP_RESPONSE) {
		}
	elsif (defined $SITE::HANDLER) {
		}
	elsif (-f "/dev/shm/down.html") {
		## is_down, outage, offline
		$SITE::HANDLER = [ "FILE", { "FILE"=>"/dev/shm/down.html" } ];
		}
	elsif (-f sprintf("/dev/shm/%s.html",$DNSINFO->{'DOMAIN'})) {
		print STDERR "banned site [$DNSINFO->{'DOMAIN'}] refer: $ENV{'HTTP_REFERER'}\n";
		$SITE::HANDLER = [ "FILE", { "FILE"=>sprintf("/dev/shm/%s.html",$DNSINFO->{'DOMAIN'}) } ];
		}
	elsif (($SITE->client_is() =~ /^(BOT|SCAN)$/) && (defined $SITE->{'+uri/cartid'})) {
		## WHOA - BOTS SHOULD *NEVER* USE C= redirect them with a 301 -- but do the redirect before we strip the /s=
		## print STDERR "BOT STRIP /c= REDIRECT\n";
		$SITE::HANDLER = [ "REDIRECT", { "LOCATION"=>$SITE->uri() } ];
		}
	## apps shouldprovider their on robots.txt, sitemap, etc.
	elsif ($SITE->uri() =~ m/^\/(robots\.txt|sitemap\.xml|sitemap\-.*?\.xml|geotrust\.html|livesearchsiteauth\.xml)$/o) {
		my $SPECIAL = "$1";
		if (defined $LOGREF) { push @{$LOGREF}, sprintf("SPECIAL HANDLER triggered by URI:",$SITE->uri()); }
		$SITE::HANDLER = [ "SPECIAL", { 'SPECIAL'=>$SPECIAL } ];
		}
	else {
		my ($HOST) = $SITE->domain_host();
		if ($HOST eq '') { $HOST = 'www'; }

		my $HOSTTYPE = $DNSINFO->{'%HOSTS'}->{uc($HOST)}->{'HOSTTYPE'};
		my $CONFIG = &ZTOOLKIT::buildparams($DNSINFO->{'%HOSTS'}->{uc($HOST)});

		if (($HOSTTYPE eq 'VSTORE-APP') || ($HOSTTYPE eq 'SITEPTR') || ($HOSTTYPE eq 'SITE')) {
			$SITE::HANDLER = [ "VSTORE-APP", $CONFIG ];
			}
		else {
			$SITE::HANDLER = [ "VSTORE", $CONFIG ];
			}
		}

	##
	## SANITY: at this point $SITE::HANDLER should be set!
	##

	if (defined $HTTP_RESPONSE) {
		}
	elsif (not defined $SITE::HANDLER) {
		## we've already registered a different handler!
		if (defined $LOGREF) { push @{$LOGREF}, "unregistered handler"; }
		}
	elsif ($SITE::HANDLER->[0] eq 'VSTORE') {
		my $proto = ($SITE->_is_secure()) ? 'https' : 'http';

		my $URI = $req->path_info();
		$URI =~ s/[^\w\/\-\_\.]+/_/g; # stops http splitting.
		if ($URI =~ m/(\.gif|\.jpg|\.png)$/o) {
			$URI =~ s/[\/]+/\//ogs; 	# turn multiple //'s into just /
			$URI = "/media".$URI;
			}
		elsif ($URI =~ m/^\/(graphics|navbuttons)\//o) {
			$URI = "/media".$URI;
			}
		elsif ($DNSINFO->{'HOST'} eq 'NONE') {
			$URI = sprintf("%s://www.%s%s",$proto,$DNSINFO->{'DOMAIN'},$URI);
			}
		else {
			## don't do a redirect
			$URI = '';
			}
	
		if ($URI ne '') {
			## response header splitting.
			$URI =~ s/[\n\r]+//gs;
			$URI =~ s/%0[AD]//gs;
			$SITE::HANDLER = [ "REDIRECT", { 'LOCATION'=>$URI } ];
			}
	
		}

#	open F, ">>/tmp/domain.log";
#	use Data::Dumper; print F Dumper($DNSINFO->{'HOST'},$DNSINFO->{'DOMAIN'},$SITE::HANDLER->[0],$DNSINFO)."\n";
#	close F;

	
	## $SITE::HANDLER->[0] = 'VSTORE-APP';
	if (defined $HTTP_RESPONSE) {
		}
	elsif ((not defined $SITE) || (ref($SITE) ne 'SITE')) {
		## redirect to zoovy homepage?
		my $URL = "/404-page-missing/index.html?reason=no_site_object";
		&ZOOVY::confess("zoovy","LEGACY ISE: $ENV{'REMOTE_ADDR'} $@\n\n",justkidding=>1);
		$SITE::HANDLER = [ 'REDIRECT', { 'LOCATION'=>$URL } ];
		}
   elsif ($SITE::HANDLER->[0] eq 'VSTORE-APP') {
      eval {
			($BODY) = &seoHTML5CompatibilityResponseHandler($SITE,$req,$HEADERS);
			};
      }
	elsif ($SITE::HANDLER->[0] eq 'VSTORE') {
		## tells us that we're going to serve a static file (already set during mapToStorageHandler)
		eval { 
			($BODY) = &legacyResponseHandler($SITE,$req,$HEADERS); 
			};

		if (not defined $BODY) {
			my $ERRORMSG = $@;
			my $URL = undef;
			if ($ERRORMSG =~ /DBD driver has not implemented the AutoCommit attribute/) {
				## known issue, can't stop these.
				}
			#elsif ($ERRORMSG =~ /Apache2\:\:RequestIO\:\:read\:/) {
			#	## known issue, can't stop these.
			#	}
			else {
				$URL = $SITE->URLENGINE()->get('nonsecure_url')."/missing404?sender=ise&reason=$@";
				&ZOOVY::confess($SITE->username(),"LEGACY ISE: $ENV{'REMOTE_ADDR'} $@\n\n",justkidding=>1);
				$SITE::HANDLER = [ 'REDIRECT', { 'LOCATION'=>$URL } ];
				}
			}
		}

	## SPECIAL RESPONSE HANDLERS
	if (defined $HTTP_RESPONSE) {
		}
	elsif ($SITE::HANDLER->[0] ne 'SPECIAL') {
		}
	elsif ($SITE::HANDLER->[1]->{'SPECIAL'} eq 'parking') {

		$BODY = (qq~
<html>
<h1>$ENV{'SERVER_NAME'}</h1>
<hr>
<i>we apologize, but this website is no longer available.</i>
</html>
~);
		$BODY .= ("<!-- SERVER: ".&ZOOVY::servername()." -->\n");
		$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/html' } ];
		}
	elsif ($SITE::HANDLER->[1]->{'SPECIAL'} eq 'robots.txt') {
		my $txt = qq~User-agent: *
Robot-version: 2.0.0
Sitemap: /sitemap.xml
Disallow: /cgi-bin/*
Disallow: /claim/
Disallow: /checkout.cgis
Disallow: /search.cgis
Disallow: /cart.cgis
Disallow: /cancel_order.cgis
Disallow: /forgot.cgis
Disallow: /login.cgis
Disallow: /logout.cgis
Disallow: /password.cgis
Disallow: /remove.cgis
Disallow: /subscribe.cgis
Disallow: /feedback.cgis
Disallow: /about_zoovy.pl
Disallow: /about_zoovy.cgis
Disallow: /popup.pl
Disallow: /popup.cgis
Disallow: /s=*/*
Disallow: /customer/
Disallow: /customer/*
Disallow: /c=*/*

User-agent: msnbot
Crawl-delay: 1

User-agent: 008
Disallow: /

~;
## user-agent: AhrefsBot
## disallow: / 

	my $disallow_robots = 0;
	if (not defined $SITE) { $disallow_robots++; }
	elsif ($SITE->_is_secure()) { $disallow_robots++; }
	elsif ($SITE->sdomain() =~ /\.zoovy\.com/) { $disallow_robots++; }
		
	if ($disallow_robots) {
		## special robots.txt for .zoovy.com domains
		$txt = q~User-agent: *
Robot-version: 2.0.0
Disallow: /
~;
			}
		$BODY .= ($txt);
		$BODY .= ("\n\r\n\r\n\r"); 
		$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/plain' } ];
		}
	elsif ($SITE::HANDLER->[1]->{'SPECIAL'} =~ /^geotrust/) {
		# if ($assbackwards) { print "HTTP/1.0 200 Ok\nServer: Apache!\n"; }
		$BODY .= (qq~<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">
<html><body marginwidth="0" marginheight="0" topmargin="0" leftmargin="0">
<!-- webbot bot="HTMLMarkup" startspan -->
<!--[if IE]>
<script src="http://html5shiv.googlecode.com/svn/trunk/html5.js"></script>
<![endif]-->
<SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript" SRC="//smarticon.geotrust.com/si.js"></SCRIPT>
<!-- webbot bot="HTMLMarkup" endspan -->
</body></html>~);
		$BODY .= ("\n\r\n\r\n\r");
		$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/html' } ];
		}
	elsif ($SITE::HANDLER->[1]->{'SPECIAL'} eq 'livesearchsiteauth.xml') {
		# BINGTOOLS
		my $str = 'NOT-FOUND';
		## BING uses the same string in livesearchsiteauth.xml and the content= in the header
		if (not defined $SITE) { $str = "NO-SITE-OBJECT"; }
		elsif ($SITE->dnsinfo()->{'BING_SITEMAP'} =~ /content\="(.*?)"/) { $str = $1; }

		$BODY .= (qq~<?xml version="1.0" ?>
<users>
	<user>$str</user>
</users>
~);			
		$BODY .= ("\n\r\n\r\n\r");
		$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/html' } ];
		}
	elsif ($SITE::HANDLER->[1]->{'SPECIAL'} =~ /^sitemap(.*?)\.xml$/o) {
		########################################
		## generates a google sitemap
		# if ($assbackwards) { print "HTTP/1.0 200 Ok\nServer: Apache!\n"; }
		my $SENDER = $1;	# empty or -chunk-1
		if ($SENDER ne '') {
			$SENDER = substr($SENDER,1);	# remove - from -chunk-1
			}

		my $XML = '';
		$DNSINFO = $SITE->dnsinfo();
		my $SDOMAIN = $SITE->sdomain();

		require UTILITY::SITEMAP;
		my ($USERNAME) = $SITE->username();
		my $staticfile = &UTILITY::SITEMAP::sitemap_file($USERNAME, $DNSINFO->{'DOMAIN'}, $SENDER);

		if (-f $staticfile) {
			$SITE::HANDLER = [ 'FILE', { 'FILE'=>$staticfile, 'Content-Type'=>'text/html' } ];
			}
		else {
			$XML = qq~<!-- $SDOMAIN does not have a static sitemap file $staticfile -->
<urlset><url><loc>http://$SDOMAIN</loc><priority>1.0</priority></url></urlset>
~;
			$BODY .= ($XML);
			$BODY .= ("\n\r\n\r\n\r"); 
			$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/xml' } ];
			}
		}
	else {
		$BODY = "UNHANDLED SPECIAL: ".$SITE::HANDLER->[0]."\n";
		$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/plain' } ];
		}



	if (defined $HTTP_RESPONSE) {
		}
	elsif ($SITE::HANDLER->[0] eq 'FILE') {
		## our transHandler must decline to handle so Apache can pick it up and finish it!
		## just something so we don't get to declined
		## return(Apache2::Const::OK);		
		}

	if (defined $HTTP_RESPONSE) {
		}
	elsif ($SITE::HANDLER->[0] eq 'DONE') {
		}

	## print STDERR "SITE::HANDLER: ".Dumper($HTTP_RESPONSE,$SITE::HANDLER)."\n";

	if (defined $HTTP_RESPONSE) {
		}
	elsif ($SITE::HANDLER->[0] eq 'REDIRECT') {
		my $LOCATION = $SITE::HANDLER->[1]->{"LOCATION"};
      my $CODE = $SITE::HANDLER->[1]->{'CODE'} || 301;
		$HEADERS->push_header("Pragma"=>"no-cache");                     # HTTP 1.0 non-caching specification
		$HEADERS->push_header("Cache-Control"=>"no-cache, no-store");    # HTTP 1.1 non-caching specification
		$HEADERS->push_header("Expires"=>"0");                           # HTTP 1.0 way of saying "expire now"
		$HEADERS->push_header("Status"=>"$CODE Moved");
		# $HEADERS->push_header("Zoovy-Debug"=>caller(0));
		$HEADERS->push_header("Location"=>"$LOCATION");
		$HTTP_RESPONSE = $CODE;
		}
	elsif ($SITE::HANDLER->[0] eq 'DONE') {
		## already did this request! .. 
		if (defined $SITE::HANDLER->[1]->{'Content-Type'}) {
			$HEADERS->push_header('Content-Type'=>$SITE::HANDLER->[1]->{'Content-Type'});
			}
		$HTTP_RESPONSE = 200;
		}
	elsif ($SITE::HANDLER->[0] eq 'DENY') {
		## already did this request! .. 
		$HTTP_RESPONSE = 401;
		}
	elsif ($SITE::HANDLER->[0] eq 'MISSING') {
		## already did this request! .. 
		$HTTP_RESPONSE = 404;
		#		$r->status(Apache2::Const::HTTP_NOT_FOUND);
		#		$r->allowed(Apache2::Const::HTTP_NOT_FOUND);
		}

	if (not defined $HTTP_RESPONSE) {
		## CATCH ALL
		$HTTP_RESPONSE = 404;
		$BODY = '';
		}


	## the 'Content-Length' header below caused one of the most tramautic 24 hours in my life -- ask me about it.
	## change at your own peril. -BH 5/18/13
	$HEADERS->push_header( 'Content-Length' => length($BODY) );

	if (&ZOOVY::servername() eq 'dev') {
		warn "RESPONSE $HTTP_RESPONSE\nBODY:$BODY\n";
		}

	my $res = Plack::Response->new($HTTP_RESPONSE,$HEADERS,$BODY);
	return($res->finalize);
	};








##
##
##
## LEGACY VSTORE
##
##
## 
sub legacyResponseHandler {
	my ($SITE,$req,$HEADERS) = @_;

	### we need this because apache will reset REMOTE_ADDR

	@SITE::ERRORS = ();		# error messages that should be displayed.
	my ($START_TIMES_user,$START_TIMES_system) = times();
	$SITE::HANDLER = undef;

	## $SITE::DEBUG++;
	my $START_GMT = time(); 	## need to switch to Time::Hires

	#
	# ENV_VARIABLES:
	#	'merchant_id' => 'brian',
	#	'cart_id' => '6IH47L3rmU08rXsvBPKMYCqMC',
	#
	#	'REQUEST_URI' => '/claim/1234',
	#	'REQUEST_URI' => '/c=6IH47L3rmU08rXsvBPKMYCqMC/cart.cgis',
	#	'SCRIPT_URI' => 'http://brian.zoovy.com/c=6IH47L3rmU08rXsvBPKMYCqMC/cart.cgis',
	#	

	##
	## GLOBAL VARIABLES
	##
	## $SITE::DEBUG = 1;
	$SITE::CART2 = undef;
	$SITE::JSRUNTIME = undef;
	$SITE::JSCONTEXT = undef;
	$SITE::JSOUTPUT = undef;
	%SITE::OVERRIDES = ();			# hashref of specific overloads set by RENDER_OVERLOAD
	$SITE::pbench = undef;
	$SITE::HAVE_GLOBAL_DB_HANDLE = 0;
	$SITE::memd = undef;
	$SITE::REDIRECT_URL = undef;
	$SITE::SREF = $SITE;	## OLD GLOBAL VARIABLE

	my $BODY = '';
	if (ref($SITE::SREF) ne 'SITE') {
		die("r->pnotes *SITE must be a reference to a SITE object");
		}
	else {
		$SITE->sset('_FS','');			## the current flowstyle (references /httpd/static/flows.txt)
		$SITE->pageid( '' );		# this is used to track state throughout the application.
		}

	# my $cgi = new CGI;
	## Get info from both POST values as an arrayref (array for multi-select)
	setlocale("LC_CTYPE", "en_US");

	## This handles a POST
	#foreach my $k ($cgi->param()) {
	#	my ($x) = $cgi->param($k);

	#	if (utf8::is_utf8($x) eq '') {
	#		## NOTE: this is specifically intended to correct situations where some clients post to us
#	#		##			in ISO-8859-1 from a UTF8 form field.
	#		$x = Encode::decode("utf8",$x);
	#		utf8::decode($x);
	#		}

	#	$SITE::v->{lc(&SITE::untaint($k))}       = &SITE::untaint($x); # removes unwanted xss attack vectors
	#	$SITE::v_mixed->{$k}     = $x;					  # avoid using this unless you need non-translated vars (e.g. pogs)
	#	}

	## Get the info from cookies
	## $SITE::c = $req->cookies();
	$SITE::pbench = undef;

	##
	## NOTE: These intercepts MUST be done before we attempt to load the cart, since otherwise
	##			they will screw up the reads of our carts.
	##
	if (defined $SITE) {
		########################################
		## HTTP SERVER VARIABLES

		## BE CAREFUL: +server is ssl.zoovy.com, www.mydomain.com, www.subdomain.mydomain.com
		## VALID SERVERS: secure.domain.com, m.domain.com, i.domain.com, www.domain.com
		}


	if ($SITE->pageid() ne '') {
		}
	else {
		################################################################
		##  SANITY: at this point the following statements must be true:
		##		$SITE->username() is set
		##		$SITE->pageid() is blank (or set to error)
		##	
		$SITE::memd = &ZOOVY::getMemd($SITE->username());
		
		########################################
		## SANITY: at this point $SITE->username() is set and won't change
		$SITE::HAVE_GLOBAL_DB_HANDLE++;
		my ($udbh) = &DBINFO::db_user_connect($SITE->username());
		my ($dbnow) = $udbh->selectrow_array("select now()");
		if ($dbnow eq '') {
			print STDERR "$$ - DBHANDLE DID NOT RETURN NOW!\n";
			%DBINFO::USER_HANDLES = ();
			($udbh) = &DBINFO::db_user_connect($SITE->username());
			$udbh->do("set \@\@net_read_timeout=60");
			($dbnow) = $udbh->selectrow_array("select now()");
			if ($dbnow eq '') {
				print STDERR "$$ - DBHANDLE COULD NOT BE RECOVERED\n";
				}
			}
		
		########################################
		## LOAD MERCHANT/WEBSITE INFORMATION
		if ($SITE->servicepath()->[0] eq '') { $SITE->servicepath('homepage','.'); }

		## If we get nothing back looking up the website db, the user must not exist
		if ($SITE->pageid() ne '') {}
		elsif (scalar(keys(%{$SITE->webdbref()})) == 0) {
			if ( $SITE->prt() > 0 ) {
				$SITE->pageid( sprintf('?ERROR/Specified partition #%d has not been configured!', $SITE->prt()) );
				}
			else {
				$SITE::DEBUG && warn("404 (unable to load merchant db)");
			 	$SITE->pageid( '?REDIRECT/302|no webdb keys: '.$ENV{'REMOTE_ADDR'}.' '.$ENV{'SERVER_NAME'}.$ENV{'REQUEST_URI'} );
				$SITE::REDIRECT_URL = 'http://www.zoovy.com/?nowebdb-from-'.&ZOOVY::servername().'-'.$ENV{'SERVER_NAME'};
				}
			}

	

		if ($SITE->pageid() ne '') {}
		elsif ((defined $SITE->webdbref()->{'dev_enabled'}) && ($SITE->webdbref()->{'dev_enabled'}>0)) {
			my $webdbref = $SITE->webdbref();
			%SITE::OVERRIDES = ();

			if (defined $webdbref->{'dev.overrides'}) {
				%SITE::OVERRIDES = %{&ZTOOLKIT::parseparams($webdbref->{'dev.overrides'})};
				}
			## old legacy settings (does anybody even use these anymore?)
			if ($webdbref->{'dev_nocontinue'}) { $SITE::OVERRIDES{'dev.no_continue'} = 1; }
			if ($webdbref->{'dev_nosubcategories'}) { $SITE::OVERRIDES{'dev.no_subcategories'} = 1; }
			if ($webdbref->{'dev_no_home'}) { $SITE::OVERRIDES{'dev.no_home'} = 1; }
			if ($webdbref->{'dev_softcart'}) { $SITE::OVERRIDES{'dev.softcart'} = 1; }

			if ($webdbref->{'dev_softcart_referers'}) {
				$SITE::OVERRIDES{'dev.softcart_referers'} = $webdbref->{'dev_softcart_referers'}; 
				}
			## these are new format webapi keys.
	
			if (&ZTOOLKIT::def($webdbref->{'dev_killframes'})) { $SITE::OVERRIDES{'dev.killframes'} = 1; }
#			$SITE::OVERRIDES = (defined $webdbref->{'dev.ssl_only'})?$webdbref->{'dev.ssl_only'}:0;
#			$SITE::OVERRIDES = (defined $webdbref->{'dev.ssl_only'})?$webdbref->{'dev.ssl_only'}:0;
			## LOAD URL REWRITES
	
			# Fully-qualify non-secure URLS
			my $qtusername = quotemeta($SITE->username());

			if ((defined $webdbref->{'dev.rewrite_urls'}) && ($webdbref->{'dev.rewrite_urls'} ne '')) {
				my $urls = &ZTOOLKIT::parseparams($webdbref->{'dev.rewrite_urls'});
				foreach my $url (keys %{$urls}) {
					next if ($urls->{$url} eq '');
#					print STDERR "URL: $url\n";
					$SITE::OVERRIDES{"dev.$url"} = $urls->{$url};
					}
				}

			## END URL REWRITES
			}		
		}

	if ($SITE->pageid() ne '') {
		## we're not going to serve a ""normal"" page
		}
	else {
		## normal/standard page

		########################################
		# ALRIGHT, WE NEED A CART
		## The basic idea behind this is a new ID is assigned on every hit to the site
		## until the cart has been touched...  &CART::validate_cart fails if the cart
		## doesn't exist.  This way a search engine can come back on an indexed URL-encoded
		## cart ID and not have an old cart (by the time the search engine user get there
		## the cart has been long expired and they'll be assigned a new ID...  and this is
		## assuming that the cart had anything in it.  robots.txt forbids going to the cart
		## page to make any actual change).  Potential problem: things outside of cart
		## modifying the cart, like META or click-trails.
		$SITE::CART2 = undef;
		my $cart_id = undef;		# temporary cart_id variable (note: we now ignore $ENV{'cart_id'})
		## $SITE::DEBUG++;
		$SITE::DEBUG && warn("========== STARTING CART ELECTION ==================");
	
		## always check the cookie first.
		my $session = '';
		if ((not defined $req->cookies()->{ $SITE->our_cookie_id() }) || ($req->cookies()->{$SITE->our_cookie_id()} eq '')) {
			}
		elsif (substr($req->cookies()->{$SITE->our_cookie_id()},0,1) eq '*') {
			## *|t.1348081180|s.newdev
			print STDERR Carp::cluck("cookie ".$SITE->our_cookie_id()." == '*' is really bad, not setting session -- ".Dumper($req->cookies()));
			}
		else {
			$session = $req->cookies()->{$SITE->our_cookie_id()};
			}
		
		my %SESSION_DATA = ();
		if ($session ne '') {
			my (@SESSIONDATA) = split(/\|/,$session);
			$SESSION_DATA{'id'} = shift @SESSIONDATA;
			foreach my $txt (@SESSIONDATA) {
				## t= time issued
				## s= server issued
				if ($txt =~ /([ts]{1,1})\.(.*?)$/) { $SESSION_DATA{$1} = $2; }
				}

			if ($SESSION_DATA{'id'} eq '*') {
				print STDERR Carp::confess("SESSION_DATA{'id'} == '*' is really bad, deleting -- session was '$session'");
				delete $SESSION_DATA{'id'};
				}
			}


		## wha? no cart id in environment -- better check for myself.
		if ($ENV{'REQUEST_URI'} =~ m/\/c=(.*?)\//o) { 
			$cart_id = $1; 
			}
		elsif ($ENV{'HTTP_REFERER'} =~ m/\/c=(.*?)\//o) { 
			$cart_id = $1; 
			}

		## Used to tell if the connecting client is a spider or not
		if (($SITE->client_is() eq 'BOT') || ($SITE->client_is() eq 'SCAN')) {
			$SITE::DEBUG && warn('Connecting Host appears to be a bot! (temporary cart mode)');
			$SITE::CART2 = CART2->new_memory($SITE->username(),$SITE->prt());
			$SITE->cart2($SITE::CART2); ## LINK
			}

		$SITE::DEBUG && warn "Cookie/session sayz: $cart_id";

		## now.. 
		## if the referrer is a speciality domain, OR .zoovy.com - trust the session c= (yeah I know this duct tape)
		##		we do this incases where we are bouncing around domains and the session id is less attractive

		##
		if (defined $SITE::CART2) {
			}
		elsif (($cart_id ne '') && ($ENV{'HTTP_REFERER'} ne '')) {
			## okay, so lets try the referrer domain to see if we can trust it (if it's same user + same partition)
			my $TRUST_REFER = 0;
			my ($scheme, $referhost, $path, $query, $frag) = URI::Split::uri_split($ENV{'HTTP_REFERER'});
			my ($REFER_USER,$REFER_PRT) = &DOMAIN::TOOLS::domain_to_userprt($referhost);
			if (
				(uc($REFER_USER) eq uc($SITE->username())) &&
				($REFER_PRT == $SITE->prt()) 
				) { 
				$TRUST_REFER++; 
				}

			if ($TRUST_REFER) {			
				## Get the cart ID from the URL first if we're in the checkout (cross domain)
		      $SITE::CART2 = CART2->new_persist($SITE->username(),$SITE->prt(),$cart_id,'create'=>0);
  				if (not $SITE::CART2->exists()) { 
					$SITE::CART2 = undef; 
					$SITE::DEBUG && warn "!!!! oh crap cart->exists() failed on cart_id";
					}
				else {
					$SITE->cart2($SITE::CART2); ## LINK
					}
      		$SITE::DEBUG && warn('Getting CART_ID from URL due to referral by speciality site! (environment variable)');
				}
	      }
	
		##
		## first, if we're on a secure page - trust the session id 
		##		(since handoffs from customerdomain.com to ssl.zoovy.com are pretty common!)
		##
		if (defined $SITE::CART2) {
			}
		elsif (($SITE->_is_secure()) && ($cart_id ne '')) {
			## on secure pages -- cookies NEVER WIN!
			$SITE::CART2 = CART2->new_persist($SITE->username(),$SITE->prt(),$cart_id,'create'=>0);
			$SITE->cart2($SITE::CART2); ## LINK
			if (not $SITE::CART2->exists()) { $SITE::CART2 = undef; }
			$SITE::DEBUG && warn('Getting CART_ID from URL (environment variable)');
			}

		##
		## now, use session s=/c= if you got it.
		##
		if (defined $SITE::CART2) {
			## yay!
			}
		elsif ((defined $SESSION_DATA{'id'}) && ($SESSION_DATA{'id'} ne '')) {
			$SITE::DEBUG && warn "trying to use my session!";
			$SITE::CART2 = CART2->new_persist($SITE->username(),$SITE->prt(),$SESSION_DATA{'id'},'create'=>0);
			$SITE->cart2($SITE::CART2); ## LINK

			if (not defined $SITE::CART2) {
				$SITE::CART2 = undef
				}
			elsif (not $SITE::CART2->exists()) { 
				$SITE::CART2 = undef; 
				$SITE::DEBUG && warn "!!!! oh crap cart->exists() failed on SESSION_DATA";
				}
			}
		else { 
			delete $SESSION_DATA{'id'};	# make sure cart_cookie is undefined, we'll need this later.
			}

		##
		## if that doesn't work, check the session id. -- these are the least reliable because they might
		##	have come from a stupid search engine with the session id embedded in the link.
		##
		if (defined $SITE::CART2) {
			}
		elsif ((defined $cart_id) && ($cart_id ne '')) {
			## Get the cart ID from the URL first if we're in the checkout
			$SITE::CART2 = CART2->new_persist($SITE->username(),$SITE->prt(),$cart_id,'create'=>0);
			if ((not defined $SITE::CART2) || (not $SITE::CART2->exists())) { 
				$SITE::CART2 = undef; 	# this will give us a new cart.
				}
			elsif ($SITE->client_is() ne '') {
				## do not remap for bots/facebook/scans/etc.
				warn "Not remapping cart for facebook\n";
				}
			else {
				$SITE::CART2->reset_session($ENV{'REMOTE_ADDR'});
				}
			$SITE->cart2($SITE::CART2); ## LINK
			$SITE::DEBUG && warn('Getting CART_ID from URL (environment variable)');
			}

		##
		## Aiee! - create a new cart!
		##
		if (not defined $SITE::CART2) {
			## Get the cart ID by generating a new one!
			$SITE::DEBUG && warn('Generating new CART_ID');
			my ($CARTID) = CART2::generate_cart_id();
			$SITE::CART2 = CART2->new_persist($SITE->username(),$SITE->prt(),$CARTID,'ip'=>$SITE->ip_address(),'is_fresh'=>1,'create'=>1);
			$SITE->cart2($SITE::CART2); ## LINK
			}
		else {
			$SITE::DEBUG && warn(sprintf("=> ALRIGHT! my cart_id is: %s",$SITE::CART2->uuid()));
			$SITE::DEBUG && print STDERR Dumper($SITE::CART2);
			}

		##
		## at this point if we're logged in, we should tell the pages/urls to rewrite secure.
		if (defined $SITE::CART2->customer()) {
			$SITE::SREF->{'+secure'} |= 4;
			}
	
		$SITE::CART2->in_set('our/domain',$SITE->sdomain());
		## $SITE::CART2->in_set('our/profile',$SITE->profile());
		}
	
	###############################################################################
	##
	## SANITY: at this point the $SITE::CART2 is guaranteed to be defined!
	##				(even though it might not be saved just yet!)
	##

	if ($SITE->pageid() eq '') {


		## SITE SCHEDULES SHOULD NOT OVERRIDE CUSTOMER OR CAMPAIGN SCHEDULES
		## FORMAT IS: 
		my $schedulesrc = $SITE::CART2->in_get('our/schedule_src'); 
		if (not defined $schedulesrc) { $schedulesrc = ''; }

		if (($schedulesrc =~ /^CUSTOMER\:/) || ($schedulesrc =~ /^CAMPAIGN\:/)) {}
		elsif (not defined $SITE->nsref()) {
			push @SITE::ERRORS, sprintf('<div id=\"div_site_error\" class="zwarn">SITE REFERENCES INVALID PROFILE - SOME FEATURES MAY BE UNAVAILABLE</div>');
			}
		elsif ((defined $SITE->nsref()->{'zoovy:site_schedule'}) && ($SITE->nsref()->{'zoovy:site_schedule'} ne '')) {
			$SITE::CART2->in_set('our/schedule',$SITE->nsref()->{'zoovy:site_schedule'});
			$SITE::CART2->in_set('our/schedule_src',"SITE:".$SITE->sdomain());
			}
		else {
			}


		########################################
		## META INFORMATION
		##		meta=LAST1|PAST1|PAST2
		##		meta_src=LAST1/cpg=1/cpn=2
		my $meta = '';
		my $meta_src = undef;
		if    (defined $SITE::v->{'!meta'}) { $meta = $SITE::v->{'!meta'}; }
		elsif (defined $SITE::v->{'meta'})  { $meta = $SITE::v->{'meta'}; }
		$meta = uc($meta);

		########################################
		## EMAIL CAMPAIGNS
		my $cpg = ''; my $cpn = '';
		if (defined $SITE::v->{'cpg'}) { $cpg = $SITE::v->{'cpg'}; }
		if (defined $SITE::v->{'cpn'}) { $cpn = $SITE::v->{'cpn'}; }
		if (($cpg ne '') && ($cpn ne '')) {
	
			if (($SITE->pageid() eq 'remove') || ($SITE->pageid() eq 'unsubscribe')) {
				## remove requests don't count against our clicks!
				}
			elsif (($cpn==0) && (defined $SITE::v->{'cpc'})) {
				## RSS FEEDS also have a cpc (Coupon CODE)
				##		RSS feeds DO NOT put the user on a schedule.
				$meta_src = "$meta_src/cpc=$SITE::v->{'cpc'}";
				require CUSTOMER::RECIPIENT;
				&CUSTOMER::RECIPIENT::coupon_action($SITE->username(),'CLICKED',CPG=>$cpg);
				}
			else {
				## if we got a META passed then we'll use that, otherwise hopefully the meta which got
				## passed will contain enough information to determine who we should credit with the sale.
				$meta_src = "$meta/cpg=$cpg/cpn=$cpn";

				require CUSTOMER::RECIPIENT;
				&CUSTOMER::RECIPIENT::coupon_action($SITE->username(),'CLICKED',CPG=>$cpg,CPNID=>$cpn);
	
				## eventually we could automatically add a coupon code as well.
				## but i think it would be better to build a one time use coupon.
				## it seems that coupons would be more useful than schedules since they are easier to debug/create

				my ($coupon,$schedule) = &CUSTOMER::RECIPIENT::campaign_specials($SITE->username(),$cpg,$cpn);

				if ((defined $schedule) && ($schedule ne '')) {
					$SITE::CART2->in_set('our/schedule',$schedule);			
					$SITE::CART2->in_set('our/schedule_src',"CAMPAIGN:$cpg.$cpn");
					}
				if ((defined $coupon) && ($coupon ne '')) {
					## 
					my ($errs) = $SITE::CART2->add_coupon($coupon,\@SITE::ERRORS);
					}
				}
			}
		undef $cpg; 
		undef $cpn;

		if (defined $meta_src) {
			## meta_src records detail about the last meta added.
			$SITE::DEBUG && warn("Adding meta property to cart '$meta'");
			if (not defined $SITE::CART2) {
				&ZOOVY::confess($SITE->username(),"CREATED NEW CART --- WHY??",justkdding=>1);
				my ($CARTID) = CART2::generate_cart_id();
				$SITE::CART2 = CART2->new_persist($SITE->username(),$SITE->prt(),$CARTID,'is_fresh'=>1,'ip'=>$SITE->ip_address());    ## Meta URLs are always from off-site...  reset the cart
				$SITE->cart2($SITE::CART2); ## LINK
				}

			## meta_src is always destructive, it doesn't preserve past values.
			$SITE::CART2->in_set('cart/refer_src',$meta_src);
			}

		if ((defined $meta) && ($meta ne '')) {
			## merge meta's together (it's okay because meta_src will have the info we need)
			my $lastmeta = $SITE::CART2->in_get('cart/refer');
			if (($lastmeta eq '') || ($lastmeta eq $meta)) { 
				## same meta as last time, or new meta
				$lastmeta = $meta;
				}
			elsif (substr($lastmeta,0,length($meta)+1) eq "$meta|") {
				## so last meta hasn't changed, meaning we came in from the same link (again).. 
				## NOTE: perhaps we could track click fraud here for certain affiliates.
				## but for now we'll leave lastmeta alone.
				}
			else {
				## okay so we're going to maintain the chain: meta|last1|last2|last3
				$lastmeta =  $meta.(($lastmeta ne '')?"|$lastmeta":'');
				}
		
			$SITE::CART2->in_set('cart/refer', $lastmeta);
			## NOTE: $meta is preserved, it must be since JELLYFISH and EBATES will use it, but internally,
			}

		if ($meta eq 'NEWSLETTER') {
			## eventually we might want to have some extra validation logic here.
			}

		if ($meta eq 'RSS') {
			## again, eventually RSS feeds can have their own signing logic similar to veruta.

			#if ($SITE::v->{'_rssd'}) {
			#	require ZTOOLKIT::SECUREKEY;
			#	my ($securekey) = &ZTOOLKIT::SECUREKEY::gen_key($SITE->username(),'RS');
			#	my ($real_sig) = &ZTOOLKIT::SECUREKEY::gen_signature($securekey,$SITE::v->{'_rssd'});
			#	if ($real_sig ne $SITE::v->{'_rsig'}) {
			#		$SITE::v->{'_rssd'} = '';
			#		}
			#	}
			#if ($SITE::v->{'_rssd'}) {
			#	my ($version,$pid,$price,$expires,$campaign,$schedule) = split(/:/,$SITE::v->{'_rssd'});
			#	print STDERR "VERSION: $version PID: $pid PRICE: $price EXPIRES: $expires SCHEDULE: $schedule\n";
			#	my ($errs) = $SITE::CART2->add_coupon($campaign,[],{
			#		type=>'product',
			#		src=>'RSS',
			#		price=>$price,
			#		product=>$pid,
			#		addcart_gmt=>$expires,
			#		expires_gmt=>$expires+3600,
			#		schedule=>$schedule,
			#		});
			#	}
			}

	
		#if (($meta eq 'PRICEGRABBER') || ($meta eq 'BIZRATE') || ($meta eq 'DEALTIME') || ($meta eq 'MYSIMON') || ($meta eq 'NEXTAG')) {
		#	if ((not defined $webdbref->{lc($meta).'_schedule'}) || ($webdbref->{lc($meta).'_schedule'} eq '')) {
		#		## no schedule set for this marketplace
		#		}
		#	elsif ($SITE::CART2->in_get('our/schedule') ne '') {
		#		## schedule is already set for this user -- do not override.
		#		}
		#	else {
		#		## gee willikers batman, i guess we ought to give them the other pricing!
		#		$SITE::CART2->in_set('our/schedule',$webdbref->{lc($meta).'_schedule'});
		#		}
		#	}
	
		########################################
		## CART PROPERTY SETTING

		#print STDERR Dumper($SITE::v);
		
		## Looks for CGI params named cp_xxxx and sets the cart property cgi.xxxx accordingly
		## We name them differently so that we don't have accidental stepping on namespace of 
		## properties in the cart.
		## This was made specifically so we could check for the zip code being passed to any page
		## for the MINICART element in wrappers/flows
		##	if yer lookin for cp_shipmethod ya found it.
		foreach my $key (keys %{$SITE::v}) {
			if ($key =~ m/^[Cc][Pp]\_(.*)$/) {
				$SITE::v->{"cgi.$1"} = $SITE::v->{$key};
				delete $SITE::v->{$key};
				}
			}




		#$VAR1 = {
      #    'cgi.country' => 'United States',
      #    'qty-gkw43806' => '1',
      #    'promocode' => '',
      #    'cgi.zip' => '92010',
      #    'return' => 'http://www.gkworld.com/'
      #  };
		
		if ($SITE::v->{'cgi.shipmethod'} || $SITE::v->{'cgi.zip'} || $SITE::v->{'cgi.country'} || $SITE::v->{'cgi.countrycode'}) {
			my $saveprops = {};

			my @map = (
				['cgi.zip'=>'ship/postal'],
				# ['cgi.country'=>'ship/country'],
				['cgi.countrycode'=>'ship/countrycode'],
				);



			if ($SITE::v_mixed->{'cgi.zip'} ne '') {
				## old legacy code did NOT set country .. and defaulting to US is a BAD idea.. so we're going to add
				## some cleanup code here.
				if ($SITE::v_mixed->{'cgi.countrycode'} ne '') {
					# it's all good
					}
				elsif ($SITE::v_mixed->{'cgi.country'} ne '') {
					my $info = &ZSHIP::resolve_country(ZOOVY=>$SITE::v_mixed->{'cgi.country'});
					$SITE::v_mixed->{'cgi.countrycode'} = $info->{'ISO'};
					}
				else {
					$SITE::v_mixed->{'cgi.countrycode'} = 'US';
					}
				}
			elsif ($SITE::v_mixed->{'cgi.country'} ne '') {
				my $info = &ZSHIP::resolve_country(ZOOVY=>$SITE::v_mixed->{'cgi.country'});
				$SITE::v_mixed->{'cgi.countrycode'} = $info->{'ISO'};
				}

		
			foreach my $set (@map) {
				next if (not defined $SITE::v_mixed->{$set->[0]});
				next if ($SITE::v_mixed->{$set->[0]} eq '');
				## 
				$SITE::CART2->pu_set($set->[1],$SITE::v_mixed->{$set->[0]});
				if ($set->[0] eq 'cgi.zip') {
					$SITE::CART2->pu_set('ship/region',undef);
					}
				}

			print STDERR 'SHIP/TAX CODE: '.Dumper($SITE::v_mixed,$SITE::v,$SITE::CART2->{'%ship'});

			## cgi.shipmethod needs to be set for us to update shipping BEFORE the page
			#foreach my $k ('cgi.zip','cgi.state','cgi.country','cgi.countrycode') {
			#	next if (not defined $SITE::v_mixed->{$k});
			#	next if ($SITE::v_mixed->{$k} eq '');
			#	$saveprops->{$k} = $SITE::v_mixed->{$k};	# use UNSAFE/TAINTED VARIABLES HERE
			#	}

			#if (scalar(keys %{$saveprops})>0) {
			#	$SITE::CART2->save_properties($saveprops);
			#	## note: keep this or you won't be able to set the shipping on the cart!
			#	$SITE::CART2->shipping();
			#	}
			if ($SITE::v->{'cgi.shipmethod'}) {
				my ($newid) = $SITE::CART2->set_shipmethod($SITE::v->{'cgi.shipmethod'});
				#print STDERR "NEWID:$newid ".$SITE::CART2->in_get('want/shipping_id')."\n";
				}
			undef $saveprops;
			}
		}


	################################################################################
	##  SANITY: at this point the CART has all the state information saved.
	##				we can move forward with the actions and rendering the site.

	###########################################################
	## OKAY, SO NOW WE FIGURE OUT WHAT TYPE OF PAGE WE'VE GOT
	##		in the short run this is important so later on we can run the appropriate code blocks
	##
	@SITE::STARTUP = ();		# render elements which are run AFTER CONFIG element but before the header
	@SITE::PREBODY = ();		# render elements which are run BEFORE the BODY of a page.
	@SITE::ENDPAGE = ();		# render elements after the main body.

	%SITE::PAGES = &SITE::site_pages();
	#if ($SITE::CART2->customer()) {
	#	foreach my $k (keys %SITE::PAGES) {
	#		}
	#	}

	if (($SITE->pageid() eq '') || ($SITE->pageid() eq '?LASTRESORT')) {	
		# print STDERR "SECURE: $SITE::SREF->{'+secure'}\n";	
		# print STDERR 'DNSINFO: '.Dumper($SITE::DNSINFO);
		# print STDERR "R: ".$PATH_INFO."\n";

		######################################
		## Figure out which page we're on
		##		this mimics the old rewrite rules from apache.
		my $requri = $SITE->uri();
		if ($requri =~ /^\/product\/[A-Z0-9]+\/null$/) {
			$SITE->URLENGINE()->set(cookies=>0);
			warn "Null product request\n";
			$SITE->pageid( 'missing404?null_product_requested' );
			}

		if ($SITE->pageid() ne '') {
			}		
		elsif ($requri =~ /^\/product\/(.*)$/) {
			# print STDERR "Testing foo! [$1]\n";
			my $STID = CGI::unescape($1); 
			$STID =~ s/[<>\"\']/!/g; # block XSS attacks.
			## strip the /pagename_blah_blah_blah.html
			$STID =~ s/(\/[\w\-]+\.html)$//;
			# print STDERR "STID: $STID\n"; die();
			$SITE->setSTID($STID);

			#print STDERR sprintf("TRYING TO LOAD: user:%s pid:%s sku:%s $requri\n",$SITE->username(),$SITE->pid(),$SITE->sku());
			#die();

			my ($P) = $SITE->pRODUCT( $SITE->pid() );
			if ((defined $P) && (ref($P) eq 'PRODUCT')) {
				## woot! we're clear
				$SITE->pageid( 'product' );
				$SITE->sset('_FS','P'); 
				$SITE->servicepath( $SITE->pageid(), $SITE->pid() );
				$HEADERS->push_header('Last-Modified',$P->fetch('zoovy:prod_modified_gmt'));

				if (($SITE->pageid() eq 'product') && ($P->fetch('zoovy:redir_url') ne '')) {
					## redirect to a different URL
					my $url = $P->fetch('zoovy:redir_url');
					if ($url !~ /^http/i) { $url = $SITE->URLENGINE()->rewrite($url); }
					$SITE->pageid( "?REDIRECT/301|product redir[".$SITE->pid()."] to url[$url]" );
					## note: if url is /category/nature then it translates to ?? / 
					$SITE::REDIRECT_URL = $url;
					}

				## check the allowed list

				my $is_allowed = -1;
				if (($SITE->pageid() eq 'product') && ($P->fetch('web:prod_domains_allowed'))) {
					my $allowed_domains = &ZTOOLKIT::textlist_to_arrayref($P->fetch('web:prod_domains_allowed'));
					if (scalar(@{$allowed_domains})>0) { $is_allowed = 0; }	# failsafe: set to 0 to indicate failure, in case we don't match
					foreach my $domain (@{$allowed_domains}) {
						$domain = lc($domain);
						if ($domain eq $SITE->sdomain()) { $is_allowed++; }
						if ($domain eq $SITE->domain_only()) { $is_allowed++; }
						}
					}
	
				## check the banned list
				my $is_blocked = -1;
				if (($SITE->pageid() eq 'product') && ($P->fetch('web:prod_domains_blocked'))) {
					my $blocked_domains = &ZTOOLKIT::textlist_to_arrayref($P->fetch('web:prod_domains_blocked'));
					if (scalar(@{$blocked_domains})>0) { $is_blocked = 0; }	# failsafe: if non are blocked, then leave is_blocked at -1
					foreach my $domain (@{$blocked_domains}) {
						$domain = lc($domain);
						if ($domain eq $SITE->sdomain()) { $is_blocked++; }
						if ($domain eq $SITE->domain_only()) { $is_blocked++; }
						# if (sprintf("%s.%s",$SITE::SREF->{'HOST'},$SITE->domain_only()) eq $SITE::SREF->{'+sdomain'}) { $is_blocked++; }
						# print STDERR "DOMAIN:$domain $SITE::SREF->{'+sdomain'} $is_blocked\n";
						}
					}

				

				## make sure we're on the products appropriate domain
				if ($SITE->pageid() ne 'product') {}
				elsif ($is_allowed>0) {
					## 1 we never do web:prod_domain if this domain was allowed
					}		
				elsif ($is_allowed==0) {
					## was not allowed.
					$SITE->pageid( "?LASTRESORT/product ".$SITE->pid()." is not allowed for domain!" ); 
					}
				elsif ($is_blocked>0) {
					##	1 we never do web:prod_domain if this domain was blocked
					$SITE->pageid( "?LASTRESORT/product ".$SITE->pid()." is blocked for domain!" );
					}   
				elsif (
					(defined $P->fetch('web:prod_domain')) && 
					($P->fetch('web:prod_domain') ne '') &&
					($SITE->sdomain() ne $P->fetch('web:prod_domain'))
					) {
					## redirect to web:prod_domain
					$SITE::REDIRECT_URL = sprintf("http://%s/%s",$P->fetch('web:prod_domain'),$SITE->canonical_url());
					if (scalar(keys %{$SITE::v_mixed})>0) {
						$SITE::REDIRECT_URL = sprintf("%s?%s",$SITE::REDIRECT_URL,&ZTOOLKIT::buildparams($SITE::v_mixed));
						}
					$SITE->pageid( "?REDIRECT/301|product ".$SITE->pid()." is not on web:prod_domain!" );
					}
				else {
					}


				

				## do a 301 redirect to the canonical url
				if ($SITE->_is_secure()) {
					## no canoncial url redirects if we're on a secure url.
					}
				elsif (($SITE->pageid() eq 'product') && ($SITE->canonical_uri() ne $requri)) {
					$SITE::REDIRECT_URL = $SITE->canonical_url();
					if (scalar(keys %{$SITE::v_mixed})>0) {
						$SITE::REDIRECT_URL = sprintf("%s?%s",$SITE::REDIRECT_URL,&ZTOOLKIT::buildparams($SITE::v_mixed));
						}
					$SITE->pageid( "?REDIRECT/301|canonical url redirect[".$SITE->pid()."] was=[$requri] shouldbe=[".$SITE->canonical_uri()."]" );
					}
				## print STDERR "REDIRECT:$SITE::REDIRECT_URL\n";
				# print STDERR sprintf("DOMAINS ALLOWED %s %s allowed:$is_allowed(%s) blocked:$is_blocked(%s)\n",$SITE->pid(),$SITE->pageid(),$P->fetch('web:prod_domains_allowed'),$P->fetch('web:prod_domains_blocked'));

				}
			else {
				## OK then, it failed, strip everything past the first dash and try again
				## Somebody may have tried referring to a product with options (bad monkey)
				$SITE->pageid( "?LASTRESORT/product ".$SITE->pid()." does not exist!" );
			   }


			}
		elsif ($requri =~ /^[\/]+ajax\/(.*?)$/) {
			## detects AJAX requests and routes them to the AJAX handliner
			$SITE->pageid( "?AJAX/$requri" );
			}
		#elsif ($requri =~ /^\/newsletter\/([\d]+)\/([\d]+)/o) {
		#	# %40CAMPAIGN%3a1785
		#	$SITE->pageid( '@CAMPAIGN:'.int($1) );
		#	}
		elsif ($requri =~ /^\/customer([\/]?.*?)$/o) {
			# %40CAMPAIGN%3a1785
			$SITE->pageid( 'customer' ); # sprintf("customer:%s",$1);
			}
		elsif ($requri =~ /^\/category\/\.(.*)$/o) {
			## has a leading dot in the category, apparently bad for SEO - redirect!
			##	make sure we don't have bad redirects
			my $safe = ($1);  
			$safe =~ s/[\n\r]+//g;		## stop header splitting!
			if (substr($safe,-1) ne '/') { $safe .= "/"; }	# make sure we have a trailing slash.
			$SITE::REDIRECT_URL = $SITE->URLENGINE()->rewrite("/category/$safe".(($ENV{'QUERY_STRING'})?'?'.$ENV{'QUERY_STRING'}:''));
			$SITE->pageid( '?REDIRECT/301|Move leading dot in category' );
			}
		elsif ($requri =~ /^\/category\/(.*[^\/])$/o) {
			## category DOESN'T END in a / so we'll redirect to one that does. 
			##	make sure we don't have bad redirects
			my $safe = ($1);  
			$safe =~ s/[\n\r]+//g;		## stop header splitting!
			$SITE::REDIRECT_URL = $SITE->URLENGINE()->rewrite("/category/$safe/".(($ENV{'QUERY_STRING'})?'?'.$ENV{'QUERY_STRING'}:''));
			$SITE->pageid( "?REDIRECT/301|Using redirect to append / to category:$requri" );
			}
		elsif ($requri =~ /^\/category\/(.*?)\/$/o) {
			## 
			## Actual /category/* Handler.
			##
			my $cwpath = sprintf(".%s",$1);
			$cwpath =~ s/\.+/\./gos; # make multiple dots into a single (useful if we prepended an extra at the begining for some reason)
			#if ($SITE::SREF->{'_CWPATH'} =~ /^\.([a-zA-Z0-9\_\.]+)\/sitemap\.xml$/) {
			#	## note: this is used for /category/asdf/sitemap.xml
			#	##		the default sitemap is handled a little further down in the code .. just search for ?SITEMAP
			#	$SITE::SREF->{'_CWPATH'} = $1;
			#	$SITE->pageid( "?SITEMAP/$SITE::SREF->{'_CWPATH'}" );
			#	}
			$cwpath =~ s/[^a-zA-Z0-9\-\_\.]//gs;
			$cwpath = lc($cwpath);
			$SITE->pageid('category');
			$SITE->servicepath('category',$cwpath);
	
			## NOT NECESSARY - THIS PAGE SHOULD RETURN A 404.
			#if (($SITE::SREF->{'_CWPATH'} eq '.') || ($SITE::SREF->{'_CWPATH'} eq '')) { 
			#	# If its just . or '', send them to the home page, or speciality site root.
			#	$SITE->pageid( 'homepage' ); 
			#	if ($SITE::SREF->{'_ROOTCAT'} ne '.') {
			#		$SITE::SREF->{'_CWPATH'} = $SITE::SREF->{'_ROOTCAT'};
			#		}
			#	if ($SITE::OVERRIDES{'dev.homepage_url'} ne '') {
			#		$SITE::REDIRECT_URL = $SITE->URLENGINE()->get('homepage_url');
			#		$SITE->pageid( '?REDIRECT/301|Redirecting to actual homepage (went to /category/)' );
			#		}
			#	}

			my ($NC) = $SITE->get_navcats();
			my ($modified_gmt) = $NC->modified($cwpath);
			if ($modified_gmt<=0) {
				$SITE->pageid( '?LASTRESORT/Category not found.' );
				}

			if ($SITE->username() ne 'bamtar') {
				## we're testing this on bamtar to see what the effects are
				}
			elsif ($SITE->rootcat() eq '.') {
				## anything goes!
				}
			elsif ($SITE->rootcat() ne substr($SITE->servicepath()->[1],0,length($SITE->rootcat())) ) {
				## any category which isn't within our root.
				$SITE->pageid( "?LASTRESORT/CWPATH: ".$SITE->servicepath()->[1]." is not within ROOT:$SITE->rootcat()" );
				}


			#if ($SITE->pageid() eq 'category') {
			#	$SITE::SREF->{'+canonical_url'} = sprintf("http://%s/category/%s/",$SITE->cdomain(),substr($SITE::SREF->{'_CWPATH'},1));
			#	$r->set_last_modified($modified_gmt);				
			#	}
			}
		elsif ($requri =~ /^\/rss\/(.*?)$/o) {
			## RSS feeds (should end in either a .rss or .xml)
			$SITE->pageid( '?RSS/'.$1 );
			}
		elsif ($requri =~ /^\/search(\.cgis|)\/(.*?)$/o) {
			$SITE->pageid( 'results' );
			if (not defined $SITE::v->{'keywords'}) {
				foreach my $word (split(/\//,$2)) {
					$SITE::v->{'keywords'} .= $word.' ';
					}
				}
			}
		elsif ($requri =~ /^\/GOOGLE[a-f0-9]{16,16}\.html$/) {
			## special google files for sitemap e.g. /GOOGLEcf001ccad5658a34.html/
			$SITE->pageid( "?EMPTY/$requri" );
			}
		elsif (($requri eq '') || ($requri eq '/')) {
			$SITE->pageid( 'homepage' );
			# $SITE::SREF->{'+canonical_url'} = sprintf("http://%s/",$SITE->cdomain());
			}
		elsif ($requri =~ /^\/export\/(.*?)$/o) {
			$SITE->pageid( "?EXPORT/$1" );
			}
		else {
			## not a category or product. see if it's a known page type.
			$SITE->pageid( lc($requri) );

			if (index($SITE->pageid(),'/')>=0) { $SITE->pageid( substr($SITE->pageid(),rindex($SITE->pageid(),'/')+1) ); }	# just get filename	

			if (index($SITE->pageid(),'.cgi')>=0) { $SITE->pageid( substr($SITE->pageid(),0,index($SITE->pageid(),'.cgi')) ); }	# strip cgi+cgis
			elsif (index($SITE->pageid(),'.pl')>=0) { $SITE->pageid( substr($SITE->pageid(),0,index($SITE->pageid(),'.pl')) ); }	# strip pl
			elsif (index($SITE->pageid(),'.html')>=0) { $SITE->pageid( substr($SITE->pageid(),0,index($SITE->pageid(),'.html')) ); }	# strip html
	
			## STUPID STUPID STUPID rewrite rules
			if (($SITE->pageid() eq 'contact_us') || ($SITE->pageid() eq 'feedback')) { $SITE->pageid( 'contact' ); }
			elsif (($SITE->pageid() eq 'company_info') || ($SITE->pageid() eq 'companyinfo')) { $SITE->pageid( 'about_us' ); }	
			elsif ($SITE->pageid() eq 'product') {  
				$SITE->pageid( '?REDIRECT/302|broken /product' );
				$SITE::REDIRECT_URL = $SITE->URLENGINE->get('nonsecure_url');
				}
			elsif (not defined $SITE::PAGES{$SITE->pageid()}) {
				warn "Page Flow type of ".$SITE->pageid()." does not appear to be valid (requri:$requri)\n";
				$SITE->pageid( '' );
	
				## Okay so this isn't a known page type.
				## OK, there's no redirection set up for the current URL, try to look up the category using old URL translation
	
				my $path = $requri;
				# This strips and mangles the slashes that denote the REAL limiters in the path
				$path =~ s/\/\/+/\//g;    # swap multiple slashes for a single one
				$path =~ s/^\/+//;        # strip slashes off the beginning
				$path =~ s/\/+$//;        # strip slashes off the end
				                          # this will prepare an old name for the new navcat format
				$path =~ s/\./_/g;        # Strip dots to underscores so we can use dots as delimiters
				$path =~ s/\//./g;        # Change the old delimiter of slashes into dots.
				$path = '.' . &NAVCAT::safename($path);

				if ($SITE->pageid() eq '') {
					# See if the sub-category exists
					my ($NC) = $SITE->get_navcats();
					#unless (&NAVCAT::does_navcat_exist($SITE->username(),$SITE::SREF->{'_CWPATH'})) {
					if ($NC->exists($path)) {
						$SITE->pageid( '?REDIRECT/302|legacy /whatever to /category/whatever handler' );
						$SITE::REDIRECT_URL = "/category/".substr($path,1);
						}
					undef $NC;
					}
	
			#	if ($SITE->pageid() eq '') {
			#		my ($url) = &DOMAIN::TOOLS::resolve_redirect($SITE->username(),$requri);			
			#		if ($url ne '') {
			#			$SITE->pageid( "?REDIRECT/301|mapped path[$requri] to url[$url]" );
			#			## note: if url is /category/nature then it translates to ?? / 
			#			if ($url !~ /^http/i) { $url = $SITE->URLENGINE()->rewrite($url); }
			#			$SITE::REDIRECT_URL = $url;
			#			}
			#		else {
			#			print STDERR "Failed on lookup for [$requri]\n";
			#			}
			#		}
	
				if ($SITE->pageid() eq '') {
						# FRELL!  Send them away before they notice the category doesn't exist.
						$SITE->pageid( '?LASTRESORT/does ['.join("|",@{$SITE->servicepath()}).'] exist? guess not.' );
						}
	
				## check to see if we have any special redirects
				
	
				}
			}
	
		##
		## does the page we're going to require authentication
		##
		# print STDERR "FLOW::PG[$SITE->pageid()] $SITE::PAGES{$SITE->pageid()}\n";
		if ((defined $SITE::PAGES{$SITE->pageid()}) && (($SITE::PAGES{$SITE->pageid()}&2)==2)) {
			## this page requires security/ssl
			if (not $SITE->_is_secure()) {
				$SITE::REDIRECT_URL = $SITE->URLENGINE()->get('secure_url');

				if (substr($SITE::REDIRECT_URL,0,-1) ne '/') { $SITE::REDIRECT_URL .= "/"; } # require trailing slash for secure.domain.com/s=www.blah.com because rewrite rules look for /s=.*?/
				my %ARGS = ();
				my $params = $req->parameters();
				foreach my $k ($params->keys()) {
					my ($x) = $params->get($k);
					$ARGS{$k} = $x; 
					}
            if (scalar(keys %ARGS)>0) { $SITE::REDIRECT_URL .= '?'.&ZTOOLKIT::build_params(\%ARGS); }
				# if ($r->args() ne '') { $SITE::REDIRECT_URL .= '?'.$r->args(); }
				$SITE->pageid( "?REDIRECT/301|ssl security required - going to $SITE::REDIRECT_URL" );
#				open F, ">>/tmp/foo";
#				print F "REDIRECTURL[$SITE::REDIRECT_URL]\n";
#				close F;
				}
			}
		elsif ((defined $SITE::PAGES{$SITE->pageid()}) && (($SITE::PAGES{$SITE->pageid()}&1)==1)) {
			## this page requires a login.
			my $login  = &ZTOOLKIT::def($SITE::CART2->in_get('customer/login'));
			my $login_gmt = int(&ZTOOLKIT::def($SITE::CART2->in_get('customer/login_gmt')));
			print STDERR "LOGIN[$login] LOGIN_GMT[$login_gmt]\n";
	
			# warn "SITE::VSTORE login=$login login_gmt=$login_gmt\n";

	      if ($login eq '') {}    # they aren't logged in!
	      elsif ($login_gmt==0) { ## crap, some other program didn't setup login correctly! how about if we set it now
	         $SITE::CART2->in_set('customer/login_gmt',time());
	         }
	      elsif (($SITE->pageid() eq 'login') && ($SITE->_is_secure())) {}  ## trying to login!
	      elsif ($login_gmt<(time()-7200)) {  ## hmm.. the login has expired! doh.
	         $login = '';
	         $SITE::CART2->in_set('customer/login','');
	         $SITE::CART2->in_set('customer/login_gmt',0);
	         }
	      else {   ## lets get ready to rumble, bump the current login time since they accessed a secure page.
	         $SITE::CART2->in_set('customer/login_gmt',time());
	         }
	
			if ($login ne '') {}	## whoop, already logged in!
			elsif (($SITE->pageid() eq 'login') && ($SITE->_is_secure())) {}	## trying to login!
			else {
				## force login!
				print STDERR sprintf("SITE:PG:%s secure:%s\n",$SITE->pageid(),$SITE->_is_secure());
				$SITE::REDIRECT_URL = &ZTOOLKIT::makeurl($SITE->URLENGINE()->get('login_url'), \%SITE::v);
				$SITE->pageid( '?REDIRECT/302|required login' );
				}
			}
		}
	
	## on a head request, we don't output the whole document.
	if ((defined $req) && ($req->method() eq 'HEAD') && (($SITE::PAGES{$SITE->pageid()}&4)==4)) {
		## NOTE: eventually we'll need to handle these better.
	
		## The HEAD method is identical to GET except that the server MUST NOT return a message-body 
		## in the response. The metainformation contained in the HTTP headers in response to a HEAD 
		## request SHOULD be identical to the information sent in response to a GET request. This method 
		## can be used for obtaining metainformation about the entity implied by the request without 
		## transferring the entity-body itself. This method is often used for testing hypertext links for 
		## validity, accessibility, and recent modification.
		}
	

	## note: the 404 handler returns us here!
	ELECT_PAGE_CONTENT:

	#############################################################################
	## Now we need to figure out which page type and load the appropriate flow.

#	if (substr($SITE->pageid(),0,1) ne '?') {
#		$SITE->pageid( '?STATIC' );
#		}


	my $wrappertoxml = undef;
	if (substr($SITE->pageid(),0,1) ne '?') {


		##############################################
		##		BEGIN A/B MULTIVARSITE ELECTION
		##############################################
		my ($side) = $SITE::CART2->in_get('cart/multivarsite');
		if ($side eq '') { 
			## lets run an election
			$side = ($$%2)?'A':'B';
			$SITE::CART2->in_set('cart/multivarsite',$side);
			}
		elsif ($SITE::v->{'multivarsite'}) {
			## we implicitly got set to A or B side.
			$side = $SITE::v->{'multivarsite'};
			$SITE::CART2->in_set('cart/multivarsite',$side);
			}
		else {
			## we've got an a/b side.
			}
		
		##############################################
		##		BEGIN WRAPPER ELECTION
		##############################################
		my $docid = '';
		if ((defined $SITE::v->{'wrapper'}) && ($SITE::v->{'wrapper'} ne '')) {
			# We're previewing or some-such, so force the wrapper.
			$docid = $SITE::v->{'wrapper'};
			}
		elsif (not defined $SITE->nsref()) {
			push @SITE::ERRORS, sprintf('<div id=\"div_site_error\" class="zwarn">SITE REFERENCES INVALID PROFILE - SOME FEATURES MAY BE UNAVAILABLE</div>');
			}
		elsif (($SITE->nsref()->{'zoovy:popup_wrapper'} ne '') && (($SITE->pageid() eq 'gallery') || ($SITE->pageid() eq 'popup')) ) {
			$docid = $SITE->nsref()->{'zoovy:popup_wrapper'};
			}
		elsif (uc($SITE->domain_host()) eq 'M') {
			## mobile site.
			$docid = $SITE->nsref()->{'zoovy:mobile_wrapper'};
			if ($docid eq '') { $docid = 'm09_moby'; };
			}
		elsif (uc($SITE->domain_host()) eq 'APP') {
			if ($docid eq '') { $docid = 'm09_moby'; };
			}
		else {
			$docid = $SITE->nsref()->{'zoovy:site_wrapper'};
			}

		## at this point $docid must be set to something (even if it's default)
		## NOTE: we might eventually want to check and see if the wrapper really does exist.
		if ($docid ne '') {
			($wrappertoxml) = TOXML->new('WRAPPER',$docid,USERNAME=>$SITE->username(),FS=>$SITE->fs(),cache=>$SITE->cache_ts());
			}

		if (not defined $wrappertoxml) {
			($wrappertoxml) = TOXML->new('WRAPPER','wrapper_error',USERNAME=>$SITE->username(),FS=>$SITE->fs());
			}

		# print STDERR Dumper($docid,$SITE->username(),$SITE->fs());


		#######################################################
		## VARIABLE SETUP PHASE
		#######################################################
		$wrappertoxml->initConfig($SITE);	# this returns our SITE::CONFIG variable.
	
		# print STDERR "OVERRIDES: ".Dumper(\%SITE::OVERRIDES)."\n";
		if (not defined $wrappertoxml) {
			$SITE->pageid( "?ERROR/Sorry the specified wrapper $docid is invalid. Please try again later." );
			}
		elsif (ref($wrappertoxml) ne 'TOXML') {
			$SITE->pageid( "?ERROR/Sorry the specified wrapper $docid did not return a toxml document. Please try again later." );
			}
		elsif (defined $SITE->URLENGINE()) {
			my $docid = $wrappertoxml->{'_ID'};
			if ($wrappertoxml->can('docuri')) {
				$docid = $wrappertoxml->docuri();
				}

			$SITE->URLENGINE()->set(
				## NOTE: we don't implicitly set wrapper=> because we might be reviewing an email, or layout.
				# wrapper=>$wrappertoxml->docuri(),
				# wrapper=>"$wrappertoxml->{'_ID'}?V=$SITE::CONFIG->{'V'}&PROJECT=$SITE::CONFIG->{'PROJECT'}",
				toxml=>$wrappertoxml,
				# wrapper=>$docid,
				);
			}
	
		}


	if (substr($SITE->pageid(),0,1) ne '?') {
 

		my $GROUP = uc(substr($SITE->pageid(),0,1));
		if ($GROUP eq '_') { 
			## e.g. _googlecheckout eventually _paypal, etc.
			$SITE->pageid( substr($SITE->pageid(),1) );
			$GROUP = uc(substr($SITE->pageid(),0,1));	
			}

		if ($SITE->pageid() eq 'cust_address') {
			$SITE->title( "Customer Address" );
			$SITE->sset('_FS','!'); $SITE->layout( "empty" );
			push @SITE::STARTUP, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::HANDLER::cust_address_handler, };						
			}

		if ($GROUP eq 'A') {
				if ($SITE->pageid() eq 'amazon') {
					## amazon payments? -- not sure
					$SITE->title( 'Amazon Order Thank you' );
					$SITE->sset('_FS','!'); $SITE->layout( 'empty' );
					push @SITE::STARTUP, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::HANDLER::amazon_handler, };													
					}
				#elsif ($SITE->pageid() eq 'aolsale') {
				#	$SITE->title( 'AOL Classifieds Checkout' );
				#	$SITE->sset('_FS','!'); $SITE->layout( 'empty' );
				#	push @SITE::STARTUP, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::HANDLER::aolsale_handler, };								
				#	}
				if ($SITE->pageid() eq 'about_us') {
					my $company_name = $SITE->nsref()->{'zoovy:company_name'};
					if ((not defined $company_name) || ($company_name eq '')) { $company_name = &ZTOOLKIT::pretty($SITE->username()); }
					$SITE->title( &ZTOOLKIT::htmlstrip("About $company_name") );
					$SITE->sset('_FS','A'); 
					$SITE->pageid( 'aboutus' );
					}	
				elsif ($SITE->pageid() eq 'about_zoovy') {
					$SITE->title( &ZTOOLKIT::htmlstrip("Learn more about Zoovy.com") );
					$SITE->sset('_FS','A'); $SITE->pageid( 'about_zoovy' );
					push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', 'HTML'=>&PAGE::HANDLER::about_zoovy_handler({},undef,$SITE), };
					}
				elsif ($SITE->pageid() eq 'app') {
					if ($SITE::v->{'show'} eq 'turnto') {
						require PLUGIN::TURNTO;
						push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>&PLUGIN::TURNTO::iframe(), };
						}
					}
				else {
					$SITE->pageid( "?LASTRESORT/GROUP: $GROUP" );
					}
			}
		#elsif ($GROUP eq 'B' {
		#	}
		elsif ($GROUP eq 'C') {
				if ($SITE->pageid() eq 'checkout') {
					$SITE->sset('_FS','!'); 
			
					my $SENDER = defined($SITE::v->{'sender'}) ? uc($SITE::v->{'sender'}) : '';
					#if ($SENDER eq 'CHECKOUT-TEST') {
					#	## populate a test cart.
					#	$SITE::CART->fake();
					#	}

					my $checkout_layout = $SITE->webdbref()->{'checkout'};
					print STDERR "CHECKOUT:$checkout_layout\n"; 

					## if not set, default to legacy.
					if ($checkout_layout eq '') { $checkout_layout = 'passive'; }

					## one page checkout v1.
					# if ($checkout_layout eq 'op1') { $checkout_layout = 'checkout-20111031'; }	# standard

					# if ($checkout_layout eq 'op2') { $checkout_layout = 'checkout-20120226'; }  # passive
					# if ($checkout_layout eq 'op3') { $checkout_layout = 'checkout-20120227'; }	# nice|standard
					## if we're checking out with paypal then use legacy checkout (for versions prior to op4)

					## forced upgrades
					#if ($checkout_layout eq 'op1') { $checkout_layout = 'active'; }
					#if ($checkout_layout eq 'op2') { $checkout_layout = 'passive'; }
					#if ($checkout_layout eq 'op3') { $checkout_layout = 'active'; }			
					### released 5/9/12
					#if ($checkout_layout eq 'op4') { $checkout_layout = 'passive'; } 	# passive
					#if ($checkout_layout eq 'op5') { $checkout_layout = 'active'; } 	# active
					### released 12/4/12
					#if ($checkout_layout eq 'op6') { $checkout_layout = 'passive'; } 	# passive
					#if ($checkout_layout eq 'op7') { $checkout_layout = 'active'; } 	# active
					### released 01/11/13
					#if ($checkout_layout eq 'op8') { $checkout_layout = 'passive'; } 	# passive
					#if ($checkout_layout eq 'op9') { $checkout_layout = 'active'; } 	# active

					if ($checkout_layout eq 'legacy') { $checkout_layout = 'passive'; }

					if ($checkout_layout eq 'active') {  $checkout_layout = 'checkout-201403a'; }
					if ($checkout_layout eq 'passive') {  $checkout_layout = 'checkout-201403p'; }
					if ($checkout_layout eq 'required') {  $checkout_layout = 'checkout-201403r'; }

					if (! -d "/httpd/static/layouts/$checkout_layout") { $checkout_layout = 'checkout-201342p'; }

					## if they requested an override, use that.
					if ($SITE::v->{'fl'} ne '') { $checkout_layout = $SITE::v->{'fl'}; }

					print STDERR "CHECKOUT:$checkout_layout\n";
					#if ($checkout_layout eq 'legacy') {
					#	## legacy checkout.
					#	$SITE->layout( 'empty' );	
					#	require PAGE::checkout;
					#	push @SITE::STARTUP, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::checkout::handler, };
					#	}
					if ($checkout_layout =~ /^checkout\-/) {
						## one page checkout v1.
						$SITE->layout( $checkout_layout );
						}
					else {
						push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>qq~<p>UNKNOWN CHECKOUT SETTING: $checkout_layout</p>~ };
						}

					## NOTE: SITE::PG is important because it's used for output skips.
					$SITE->pageid( '*checkout' );
					}
				elsif ($SITE->pageid() eq 'contact') {
					$SITE->title( "Contact Us" );
					$SITE->sset('_FS','U'); $SITE->pageid( "*contactus" );
					push @SITE::STARTUP, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::HANDLER::contact_handler, };				
					}
				elsif ($SITE->pageid() eq 'customer') {
					$SITE->title( "Customer Admin" );
					$SITE->sset('_FS','!'); 
					$SITE->layout( "empty" );
					require PAGE::customer;
					push @SITE::STARTUP, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::customer::handler, };						
					}
				elsif ($SITE->pageid() eq 'confirm') {
					$SITE->title( "Supplier Order Confirmation" );
					$SITE->sset('_FS','!'); $SITE->layout( "empty" );
					push @SITE::STARTUP, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::HANDLER::confirm_handler, };
					}
				#elsif ($SITE->pageid() eq 'counter') {
				#	my $channel;
				#	if (defined $SITE::v->{'channel'}) { $channel = $SITE::v->{'channel'}; }
				#	elsif (defined $SITE::v->{'id'}) { $channel = $SITE::v->{'id'}; }
				#	else { $channel = 0; }
				#	$SITE->title( "Counter" ); $SITE->sset('_FS','D'); $SITE->pageid( 'counter' );
				#	# no handler since there is no special functionality on this page.
				#	}
				elsif ($SITE->pageid() eq 'category') {
					# See if the category exists, try to default the flow.
			
					my ($NC) = $SITE->get_navcats();
					my $CWPATH = $SITE->servicepath()->[1];
					my ($breadcrumb,$breadcrumbnames) = $NC->breadcrumb($CWPATH);
					$SITE->title( CGI::escapeHTML($breadcrumbnames->{$CWPATH}) ); # Default title if none is defined
					$SITE->sset('_FS','C'); 
					$SITE->pageid( $CWPATH );

					# print STDERR Dumper($SITE->pageid(),$CWPATH,$SITE->servicepath()); die();

					}
				elsif ($SITE->pageid() eq 'cart') {
					$SITE->sset('_FS','T');	$SITE->pageid( 'cart' );
					require PAGE::cart;
					push @SITE::STARTUP, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::cart::handler, };				
					}
				else {
					$SITE->pageid( "?LASTRESORT/GROUP: $GROUP" );
					}
				#elsif ($SITE->pageid() eq 'callcenter') {
				#	require PAGE::callcenter;
				#	push @SITE::STARTUP, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::callcenter::handler, };
				#	}
			}
		elsif ($GROUP eq 'D') {
			if ($SITE->pageid() eq 'debug') {
				#push @SITE::PREBODY, { 
				#	TYPE=>'EXEC', 
				#	FUNC=>sub {
				#		my ($iniref,$toxml,$SREF,$dref) = @_;	
				#		my $out = '<b>CART-DEBUGGER v1.0</b><hr>';
				#		$out .= "Cart-ID: ".$SITE::CART2->uuid()."<br>";
				#		$out .= "Cart-Meta: ".$SITE::CART2->fetch_property('meta')."<br>";
				#		$out .= "<hr>";
				#		$out .= "<b>Full Cart Dump:</b>\n";
				#		$out .= "<pre>".&ZOOVY::incode(Dumper($SITE::CART))."</pre><br>\n";
				#		return($out);
				#		}
				#	}
				}
			}
		elsif ($GROUP eq 'G') {
#				if ($SITE->pageid() eq 'googlecheckout') {
#					print STDERR "START GOOGLE\n";
#					$SITE::CART->set_checkout_status('GOOGLE');
#					require ZPAY::GOOGLE;
#					my ($success,$redirecturl) = &ZPAY::GOOGLE::getCheckoutURL(
#						$SITE::CART2,
#						$SITE,
#						'analyticsdata'=>$SITE::v->{'analyticsdata'}
#						);
#					print STDERR "DONE WITH GOOGLE CALL\n";
#
#					if ($success) {
#						## BOUNCE 'EM TO GOOGLE!
#						## NOTE: we need to have the [[GOOGLECHECKOUT]] so that we know not to rewrite the URL
#						## 		because it is an offsite link.
#						$SITE::REDIRECT_URL = $redirecturl;
#						$SITE->pageid( '?REDIRECT/301|[[GOOGLECHECKOUT]]' );
#						}
#					else {
#						## ERROR
#						$SITE->sset('_FS','!'); $SITE->layout( 'empty' );
#						my $OUTPUT = '';
#						$OUTPUT .= qq~<p><b>Google Checkout Error</b>:</p>~.$redirecturl;
#						push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT };
#						}
#					print "END GOOGLE\n";
#					}
			}
		elsif ($GROUP eq 'H') {
				if ($SITE->pageid() eq 'homepage') {	
					## NOTE: Eventually we really ought to make it so we don't have to do a redirect for speciality domain
					##			homepages (this code should never even be reached)
					$SITE->sset('_FS','H'); 	
					$SITE->pageid( "homepage" );
	
					if ($SITE::OVERRIDES{'dev.homepage_url'} ne '') {
						## overrides
						$SITE::REDIRECT_URL = $SITE->URLENGINE()->get('homepage_url');
						$SITE->pageid( '?REDIRECT/301|Redirecting to actual homepage (due to override)' );
						}
					elsif ($SITE->rootcat() ne '.') {
						$SITE->title( $SITE->sdomain()." Home" );
						#if ($SITE->profile() eq '') {
						#	## LEGACY HACK for PROFILES of ''
						#	$SITE->sset('_FS','C'); 
						#	$SITE->pageid( $SITE->rootcat() );
						#	}
						}
					else {
						$SITE->title( "Home" ); 
						}
					}

			}
		elsif ($GROUP eq 'M') {
				if ($SITE->pageid() eq 'missing404') {
					$SITE->title( '404 Page Not Found' );
					$SITE->sset('_FS','*'); 
					$SITE->pageid( '*missing404' );
					## ABSOLUTELY DO NOT REMOVE THE LINE BELOW!!!!! 
					## it's not obvious why it's here! see CART::save() to understand why this is here/what this does
					## hint: it's not named well, and it's TOTALLY not obvious. but please please please leave it alone.
					# $SITE::CART->{'cart_mode'} = 'TEMP';	
					# $SITE::CART->is_tmp(1);
					# so I moved down logic to NOT save a 404
					}
			}
		elsif ($GROUP eq 'O') {
			}
		elsif ($GROUP eq 'P') {
				if ($SITE->pageid() eq 'product') {
					$SITE->title( $SITE->pRODUCT()->fetch('zoovy:prod_name') );
					$SITE->layout( $SITE->pRODUCT()->fetch('zoovy:fl') );
					$SITE->pageid( 'product' );
					}
				elsif ($SITE->pageid() eq 'popup') {		
					$SITE->title( &ZTOOLKIT::htmlstrip('Popup') );
					$SITE->sset('_FS','B'); $SITE->layout( 'empty' );
					if (defined $SITE::v->{'pg'}) { $SITE->pageid( $SITE::v->{'pg'} ); }
					push @SITE::PREBODY, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::HANDLER::popup_handler, };
					}
				elsif ($SITE->pageid() eq 'paypal') {
					$SITE->title( 'Paypal Integration' );
					$SITE->sset('_FS','!'); $SITE->layout( 'empty' );
					push @SITE::STARTUP, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::HANDLER::paypal_handler, };						
					}
				elsif ($SITE->pageid() eq 'privacy') {
					$SITE->title( "Privacy Policy" ); $SITE->sset('_FS','Y'); $SITE->pageid( 'privacy' );
					# no handler since there is no special functionality on this page.
					}
				elsif ($SITE->pageid() eq 'powerreviews') {
					$SITE->title( "PowerReviews" ); 
					$SITE->sset('_FS','!');
					$SITE->layout( 'empty' );
					my $verb = $SITE::v->{'verb'};

					my $pwrmid = $SITE->nsref()->{'powerreviews:merchantid'};
					my $pwrgid = $SITE->nsref()->{'powerreviews:groupid'};
				
					if ($verb eq 'writereview') {
						
 
						push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>qq~<div class="pr_write_review"><script type="text/javascript">
var pr_style_sheet="http://cdn.powerreviews.com/aux/$pwrgid/$pwrmid/css/powerreviews_express.css";
</script><script type="text/javascript" src="http://cdn.powerreviews.com/repos/$pwrgid/pr/pwr/engine/js/appLaunch.js"></script></div>~, };
						}
					elsif ($verb eq 'resize') {
						push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>qq~<script type="text/javascript" src="http://cdn.powerreviews.com/repos/$pwrgid/pr/pwr/engine/js/resize.js"></script>~, };
						}
					else {
						push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>qq~powerreviews handler<hr>err: unknown uri parameter "verb"<br>must be writereview or resize<br>~, };
						}
					}
			
			}
		#elsif ($GROUP eq 'Q') {
		#	}
		elsif ($GROUP eq 'R') {
				if ($SITE->pageid() eq 'redir') {
					$SITE->pageid( '?REDIRECT/301|redir page' ); $SITE::REDIRECT_URL = $SITE::v->{'url'};
					}
				elsif (($SITE->pageid() eq 'return') || ($SITE->pageid() eq 'returns')) {
					$SITE->title( "Returns Policy" ); $SITE->sset('_FS','R'); $SITE->pageid( 'return' ); 
					# no handler since there is no special functionality on this page.
					}
				if ($SITE->pageid() eq 'results') {
					require SEARCH; # Not verified use strict yet
					my $search_url = $SITE->URLENGINE()->get('search_url');
					my $mode = uc($SITE::v->{'mode'});
					if ((not defined $mode) || ($mode eq '')) { $mode = 'AND'; }
					my $keywords = $SITE::v->{'keywords'};
					my $bounce = 1;
					
					# use Data::Dumper; print STDERR Dumper(\%SITE::OVERRIDES);
					if (defined $SITE::v->{'bounce'}) {
						## pass uri parameter bounce=0 to disable bounce.
						$bounce = int($SITE::v->{'bounce'});
						}
					elsif (defined $SITE::OVERRIDES{'dev.search_bounce'}) { 
						$bounce = $SITE::OVERRIDES{'dev.search_bounce'}; 
						}
	
					#use Data::Dumper;
					#print STDERR Dumper($SITE::v);

					if ($SITE::OVERRIDES{'dev.i_will_do_my_own_search_thank_you'}) {
						## 9/15/2010 - this is a cheap hack UNTIL we can fix search. jt and i both agree that it's broked
						##	now we've got a decent debugger, but we need to get rid of this legacy crap. this will turn it
						## off, we should not plan on supporting this beyond 10/10/10
						#warn "has - dev.i_will_do_my_own_search_thank_you\n";
						}
					elsif ($mode eq 'FINDER') {
						my ($resultref) = &SEARCH::finder($SITE, 
							$SITE::v, 
							ROOT=>$SITE->rootcat(),
							PRT=>$SITE->prt(),
							);
						if ((((not defined $resultref) || (scalar @{$resultref})==0)) && ($bounce)) {
							$SITE::REDIRECT_URL = "$search_url?error=noresults&".&ZTOOLKIT::buildparams($SITE::v);
							$SITE->pageid( '?REDIRECT/302|search not results2' ); 
							}
						else {
							$SITE->title( scalar(@{$resultref})." results found" );
							$SITE->sset('_FS','E');	$SITE->pageid( 'results' );
							$SITE::SREF->{'@results'} = $resultref;
							# undef $resultref;
							}
						}
					elsif ($bounce && ((not defined $keywords) || ($keywords eq ''))) {
						$SITE::REDIRECT_URL = "$search_url?error=nokeys";
						$SITE->pageid( '?REDIRECT/302|search no results' ); 
						}
					else {			
						my $catalog = $SITE::v->{'catalog'};
						if (not defined $catalog) { $catalog = ''; }
						my $debug = (defined $SITE::v->{'debug'})?int($SITE::v->{'debug'}):0;

						# print STDERR "SITE::vstore CATALOG: $catalog\n";

						my ($resultref) = &SEARCH::search($SITE,MODE=>$mode,KEYWORDS=>&ZOOVY::dcode($keywords),CATALOG=>$catalog,'debug'=>$debug,PRT=>$SITE->prt());
	
						if ($bounce && ((not defined $resultref) || (scalar(@{$resultref})==0))) {
							$SITE::REDIRECT_URL = "$search_url?error=noresults&".&ZTOOLKIT::buildparams($SITE::v);
							$SITE->pageid( '?REDIRECT/302|search not results2' ); 
							}
						else {
							if (not defined $resultref) { $resultref = []; }
							$SITE->title( scalar(@{$resultref})." results found for '$keywords'" );
							$SITE->sset('_FS','E'); 
							$SITE->pageid( 'results' );
							$SITE::SREF->{'@results'} = $resultref;
							# print STDERR 'RESULTS'. Dumper($resultref);
							undef $resultref;
							}
						}
					}
			}
		elsif ($GROUP eq 'S') {
				if ($SITE->pageid() eq 'search') {
					$SITE->sset('_FS','S'); $SITE->pageid( '*search' );
					push @SITE::STARTUP, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::HANDLER::search_handler, };		
					}
				#elsif ($SITE->pageid() eq 'shipquote') {
				#	$SITE->title( &ZTOOLKIT::htmlstrip("Shipping Quote") );
				#	$SITE->sset('_FS','N');
				#	$SITE->pageid( 'shipquote' );
				#	require PAGE::shipquote;
				#	push @SITE::STARTUP, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::shipquote::handler, };		
				#	}	
				elsif ($SITE->pageid() eq 'subscribe') {
					$SITE->title( "Mailing List Subscribe" );
					$SITE->sset('_FS','*'); 
					$SITE->pageid( '*subscribe' );
					# $SITE->layout( 'empty' );
					# push @SITE::PREBODY, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::HANDLER::subscribe_handler, };				
					}
			}
		elsif ($GROUP eq 'U') {		
			}
		#elsif ($GROUP eq 'V') {
		#	}
		elsif ($GROUP eq 'W') {
				#if ($SITE->pageid() eq 'wishlist') {
				#	$SITE->title( 'Wishlist Management' );
				#	}
				#push @SITE::STARTUP, { 'TYPE'=>'EXEC', FUNC=>\&PAGE::HANDLER::wishlist_handler, }
			}
		#elsif ($GROUP eq 'X') {
		#	}
		#elsif ($GROUP eq 'Y') {
		#	}
		#elsif ($GROUP eq 'Z') {
		#	}
		elsif ($GROUP eq '@') {
			my ($PG) = $SITE->pAGE($SITE->pageid());
			$SITE->layout( $PG->get('fl') );
			$SITE->title( $PG->get('subject') );
			undef $PG;
			}
	
		#if (($SITE::PAGES{$SITE->pageid()}&16)==16) {	
			## something is opening this an not closing it.
		#	&DBINFO::db_user_close();
		#	}
		}
	

	##
	## LAST CHANCE HANDLER
	##
	# print STDERR "BEFORE LAST: ".$SITE->pageid()."\n";
	if (substr($SITE->pageid(),0,11) eq '?LASTRESORT') {

		print STDERR "LASTRESORT1: ".$SITE->pageid()."\n";
		##
		## CHECK FOR REWRITES
		##
 		# my ($url) = &DOMAIN::TOOLS::resolve_redirect($SITE->username(),$SITE->rewritable_uri(),$ENV{'REQUEST_URI'});			
 		# my ($url) = &DOMAIN::TOOLS::resolve_redirect($SITE->username(),$SITE->uri(),$ENV{'REQUEST_URI'});		


		my ($USERNAME,$PATH,$REQURI) = ($SITE->username(),$SITE->uri(),$ENV{'REQUEST_URI'});
		my $url = '';
		if ($SITE->client_is() eq 'SCAN') {
			$SITE->pageid('?MISSING');
			}
		else {
			my $udbh = &DBINFO::db_user_connect($USERNAME);
			my ($MID) = &ZOOVY::resolve_mid($USERNAME);
			my $pstmt = "select TARGETURL from DOMAINS_URL_MAP where MID=$MID and PATH=".$udbh->quote($PATH);
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			($url) = $sth->fetchrow();
			$sth->finish();
			&DBINFO::db_user_close();
	
			if ($url ne '') {
				## note: if url is /category/nature then it translates to ?? / 
				if ($url !~ /^[Hh][Tt][Tt][Pp][Ss]?:/) { $url = $SITE->URLENGINE()->rewrite($url); }
				$SITE::REDIRECT_URL = $url;
	
				$SITE->pageid( "?REDIRECT/301|category mapped path[$ENV{'REQUEST_URI'}] to url[$url]" );
				}
			}
	
		##
		## 404 PAGE?
		##
		if (substr($SITE->pageid(),0,11) ne '?LASTRESORT') {
			## woot something earlier (probably URL redirect) handler took care of this.
			}
		elsif (int($SITE::SREF->{'+404_REDIRECT'})>10) {
			## TOO MANY 404 REDIRECTS
			$SITE->pageid( '?MISSING/Too many 404 redirects!' );
			}
		elsif ($url eq '') {
			$SITE::SREF->{'+404_REDIRECT'}++;	
			$SITE->pageid( '*missing404' );
			$SITE->sset('_FS','*');
			##
			## hey: THERE IS A BIG GOTO HERE.
			## 
			goto('ELECT_PAGE_CONTENT');
			##
			## open F, ">>/dev/shm/goto.log"; print F "$SITE::DEBUG_FILE\n"; close F;
			## never reached!
			die();
			}
		
		if (substr($SITE->pageid(),0,11) eq '?LASTRESORT') {
			$SITE->pageid( '?MISSING' );
			}
#		print STDERR "LASTRESORT: $SITE->pageid()\n";
		}
#	print STDERR "MISSING: $SITE->pageid()\n";

	

	##
	## Determine if site should be private!
	##
	if (substr($SITE->pageid(),0,1) ne '?') {
		if (
			# ($SITE::OVERRIDES{'webdb.customer_management'} eq 'PRIVATE') &&
			($SITE->webdbref()->{'customer_management'} eq 'PRIVATE') &&
			($SITE->pageid() ne '*login') &&
			($SITE->pageid() ne '*forgot') &&
			($SITE->pageid() ne '*missing404') &&
			($SITE->pageid() ne 'closed') 
			) {

			if (($SITE->pageid() eq 'customer') && ($SITE->_is_secure())) {
				## we're trying to login!
				}	
			elsif ($SITE::CART2->customerid() <= 0) {
				## they aren't authenticated so we'd better make them login
				$SITE::REDIRECT_URL = &ZTOOLKIT::makeurl($SITE->URLENGINE()->get('login_url'), { 'url'=>sprintf("%s/",$SITE->URLENGINE()->get('secure_url')) });
				$SITE->pageid( "?REDIRECT/302|customer_management private - requires login! was: ".$SITE->pageid()." secure_url:".$SITE->URLENGINE()->get('secure_url')." REDIRECT: $SITE::REDIRECT_URL" );
				## NOTE: need trailing / for /s=domain.com to work later
				}
			}
		
		########################################
		## ZOOVY DEVELOPER
		
		## Always target the current window if we're not a zoovy developer user
		$SITE::target = '_self';
		
		## the cart page should always kill frames
		if ($SITE::OVERRIDES{'dev.killframes'}) { $SITE::target = '_top'; }
		}
	
	# $SITE->pageid( '?ERROR/somethign when horribly wrong' );
	
	#################################################################################
	## before this runs the following variables must be setup properly.	
	## 	
	##	$SITE::SREF->{'+secure'} 0|1 - are we in ssl mode
	##	$SITE::req_wrapper - the requested wrapper (if passed on command line)
	##	$SITE->username() - the user id
	## $SITE::userpath -	the path to the suers home data directory
	## %SITE::webdb - a reference to the webdb
	## $SITE::CART2 - a reference to the cart object
	##
	##	$SITE::rootcatset = 1 ??  (these can be set by developer?)
	##	$SITE::subcatset = 1 ??
	##
	##	$SITE::SREF->{'_FS'} - flow style (set by parent page)
	##	$SITE->layout( flow layout (which one are we using)
	##	$SITE->pageid() - which page are we on.
	##	
	# print STDERR "PAGEID: ".$SITE->pageid()."\n";
	if (substr($SITE->pageid(),0,1) ne '?') {


		## 
		#	'_SKU'=>	# set earlier
		#	'_PID'=> # set earlier
		#	'_NS'=> 
		#	'_USERNAME'=
		#	'_PG'
	
		if (defined $SITE::v->{'pg'}) { 
			$SITE->pageid( $SITE::v->{'pg'} ); 
			if ($SITE->pageid() eq '*taf') { $SITE->pageid( 'popup' ); }	## bug in old themes
			}
		# use Data::Dumper; print STDERR "OVERRIDES: ".Dumper(\%SITE::OVERRIDES);
		#if (defined $SITE::v->{'flow'}) { $SITE->layout( $SITE::v->{'flow'} ); }		
	
		my ($P) = $SITE->pAGE($SITE->pageid());

		# $SITE::PAGE = PAGE->new($SITE->username(),$SITE->pageid(),NS=>$SITE->profile(),cache=>$SITE->cache_ts(),PRT=>$SITE->prt());
	
		if (defined $SITE::v->{'fl'}) { $SITE->layout( $SITE::v->{'fl'} ); }		
		elsif (defined $SITE::v->{'forceflow'}) { $SITE->layout( $SITE::v->{'forceflow'} ); }	# gee standardization would be slick!
		elsif (defined $SITE::OVERRIDES{'flow.'.$SITE->pageid()}) { $SITE->layout( $SITE::OVERRIDES{'flow.'.$SITE->pageid()} ); }
		elsif (defined $SITE::OVERRIDES{'flow.'.lc($SITE->fs())}) { $SITE->layout( $SITE::OVERRIDES{'flow.'.lc($SITE->fs())} ); }
		elsif ((defined $SITE->layout()) && ($SITE->layout() ne '')) {
			# don't override something if we've already set it.
			}	
		elsif ($SITE->fs() eq '*') { 
			## NOTE: this must be before product () because the pid can still be in focus, but we may want to throw an error
			## 		if for example web:prod_domains_allowed is set, this is also really useful on claims!
			if ($SITE->pageid() eq '*subscribe') {
				$SITE->layout( 'subscribe-20080305' );
				}
			elsif ($SITE->pageid() eq '*login') {
				$SITE->layout( 'login-20080305' );
				}
			#elsif ($SITE->pageid() eq '*claim') {
			#	my $useflow = undef; # Default to using product flows for claims
			#	if (defined $SITE::OVERRIDES{'flow.claim'}) { $useflow = $SITE::OVERRIDES{'flow.claim'}; }
			#	else {
			#		($useflow) = &TOXML::RENDER::smart_load($SITE::SREF,'product:zoovy:claimfl');
			#		}
			#	if ((not defined $useflow) || ($useflow eq '')) { $useflow = 100; }
			#	$SITE->layout() = $useflow;
			#	}
			elsif ($SITE->pageid() eq '*missing404') {
				$SITE->layout( 'missing404-20090421' );
				}
			}
	   elsif ($SITE->pid() ne '') {
			my $P = $SITE->pRODUCT();
			if (defined $P) { $SITE->layout( $P->fetch('zoovy:fl') ); }

			if ($SITE->layout() ne '') {
				}
			elsif ((defined $SITE::OVERRIDES{'defaultflow.p'}) && ($SITE::OVERRIDES{'defaultflow.p'} ne '')) {
				$SITE->layout( $SITE::OVERRIDES{'defaultflow.p'} );
				}
			else {
				## default product layout (default to 100)
				$SITE->layout( '100' ); 
				}
			}
		else { 
			## if all else fails, use the FLOW from the page, then .. default to something sane.
			$SITE->layout( $SITE->pAGE()->get('FL') );

			print STDERR "DOCID:".$SITE->layout()." FS:".$SITE->fs()."\n";
			## NOTE: if SITE::SREF->{'_FS'} eq '*' then SITE::PG is probably something like *subscribe
			if ($SITE->layout() ne '') {
				}
			elsif (defined $SITE::OVERRIDES{'defaultflow.'.lc($SITE->fs())}) {
				## if an override called "defaultflow.c" for example is set, then we'll default to that.
				$SITE->layout( $SITE::OVERRIDES{'defaultflow.'.lc($SITE->fs())} );
				}
		   elsif ($SITE->fs() eq 'H') { $SITE->layout( 2 );    }
   		elsif ($SITE->fs() eq 'A') { $SITE->layout( 'about_leftpic' );   }
		   elsif ($SITE->fs() eq 'U') { $SITE->layout( 1500 ); }
		   elsif ($SITE->fs() eq 'S') { $SITE->layout( 5000 ); }
		   # elsif ($SITE->fs() eq 'E') { $SITE->layout( 5500 ); }
		   elsif ($SITE->fs() eq 'E') { $SITE->layout( 'e-20090617' ); }
		   elsif ($SITE->fs() eq 'Y') { $SITE->layout( 30 );   }
		   elsif ($SITE->fs() eq 'R') { $SITE->layout( 'r-20061003' ); }
		   elsif ($SITE->fs() eq 'C') { $SITE->layout( 1001 ); }
		   elsif ($SITE->fs() eq 'D') { $SITE->layout( 2000 ); }
		   elsif ($SITE->fs() eq 'T') { $SITE->layout( 3001 ); }
		   elsif ($SITE->fs() eq 'G') { $SITE->layout( 4000 ); }
		   elsif ($SITE->fs() eq 'L') { $SITE->layout( 6000 ); }
		   elsif ($SITE->fs() eq 'N') { $SITE->layout( 8000 ); }
		   elsif ($SITE->fs() eq 'X') { $SITE->layout( 0 );    } # I don't see this in use anywhere...?
		   elsif ($SITE->fs() eq 'Q') { $SITE->layout( 20000 ); }
		   elsif ($SITE->fs() eq 'I') { $SITE->layout( 'i_20050311' ); }
			elsif ($SITE->fs() eq '*') { $SITE->layout( 100 ); } 	# user subtype defaults to 100
			else {
				}
			}
	

		## NOTE: speciality handler has a different output format.
		# 14634 - sporks _NS=[DEFAULT] PG[customer] LAYOUT[empty] FS[!] PID[] 1285720839 cart[vCjoW8QO1yfz1eLajIRKzLWFk]

		print STDERR "\n".&ZTOOLKIT::pretty_date(time(),2)." - $$ - ".$SITE->username()." PG[".$SITE->pageid()."] LAYOUT[".$SITE->layout()."] FS[".$SITE->fs()."] PID[".$SITE->pid()."] ".time()." cart[".$SITE::CART2->uuid()."]\n";

		# use Data::Dumper;
		# print STDERR "POPUP SITE::PG: $SITE->pageid()\n".Dumper(@SITE::PREBODY);	
	
		## the STARTUP sequence runs after the CONFIG element.
		my %SUBS = ();		## subs is a key/value hash of variables we need to interpolate.
		&SITE::run(\%SUBS,\@SITE::STARTUP,$wrappertoxml,$SITE);	
		if (defined $SITE::pbench) { $SITE::pbench->stamp("finished startup commands for page."); }
	
	
		#######################################################
		## BEGIN HEADER OUTPUT
		#######################################################
	
		if (substr($SITE->pageid(),0,1) eq '?') {
			}
		elsif (not defined $req) {
			warn "no apache response object (probably command line)";
			}
		else {
			## RENDER PAGE
			$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/html; charset=utf8' } ];
			# $r->content_type("text/html; charset=utf8");		## note: i don't think this line is necessary site we run SITE::header later.

			my $cache_hours = 0;
			if (($SITE::PAGES{$SITE->pageid()} & 8)==8) { $cache_hours = 6; }
			if ($SITE::OVERRIDES{'IS_BOT'}) { $cache_hours = 72; }

			if ($SITE::SREF->{'+404_REDIRECT'}) {
				## THIS PAGE IS A 404 PAGE .. so it gets special headers!
				# $APACHERS = Apache2::Const::HTTP_NOT_FOUND;	
				$SITE::HANDLER = [ 'MISSING', {} ];
				}

			## Date is a required field when working with Expires and Cookies
			$HEADERS->push_header('Date'=>&CGI::expires('+0h')); # Looks kludgy but its how CGI.pm does it intenally :)

			if ($cache_hours == 0) {	## nocache
				$SITE::DEBUG && warn('Disabling browser caching');
				$HEADERS->push_header('Pragma'=>'no-cache');   ## HTTP 1.0 non-caching specification
				$HEADERS->push_header('Cache-Control'=>'no-cache, no-store');   ## HTTP 1.1 non-caching specification
				$HEADERS->push_header('Expires'=>'0');                         ## HTTP 1.0 way of saying "expire now"
				}
			else {
				$HEADERS->push_header('Cache-Control'=>'Private'); 
				$HEADERS->push_header('Expires'=>&CGI::expires('+' . $cache_hours . 'h'));    # Set the expiration time
				}


			&legacyCookies($SITE,$req,$HEADERS);
			}

		######################################################################################
		## SANITY: ALL HEADERS ARE FINISHED, AND WE CAN OUTPUT PAGE 
		##			  (unless we have an error, redirect, etc. then headers haven't been done)
		######################################################################################

		if (substr($SITE->pageid(),0,1) eq '?') {
			}
		else {
			## INSERT MAGIC HERE!

			## this *should* only compute shipping when the cart digest has changed
			# $SITE::CART2->shipping();
	
			my ($str) = &TOXML::RENDER::render_page({},$wrappertoxml,$SITE);
			if ((not defined $str) || ($str eq '')) {
				warn "OUTPUT STR WAS BLANK\n";
				}
			elsif (defined $req) {
				$BODY .= ($str);
				}
				
			my $DOCID = $wrappertoxml->{'_ID'};
			my $AB = $SITE::CART2->in_get('cart/multivarsite');

			my ($END_TIMES_user,$END_TIMES_system) = times();
			$END_TIMES_user -= $START_TIMES_user;
			$END_TIMES_system -= $START_TIMES_system;
			#if ($END_TIMES_user > 0.80) {
			#	my ($CLUSTER) = &ZOOVY::resolve_cluster($SITE->username());
			#	open Fz, ">>/dev/shm/slow.log";
			#	print Fz "$START_GMT\t$CLUSTER\t$END_TIMES_user\t$END_TIMES_system\t$SITE->username()\t$SITE->pageid()\t$ENV{'SERVER_ANME'}\t$ENV{'REQUEST_URI'}\n";
			#	close Fz;
			#	}

			my $CARTID = $SITE::CART2->uuid();
			if ((defined $SITE::CONFIG->{'footer'}) && ($SITE::CONFIG->{'footer'}==0)) {
				}
			else {
				if ($CARTID eq '*') {
					push @SITE::ENDPAGE, { 'TYPE'=>'OUTPUT', HTML=>qq~
<!-- 
******************************************************************************************
*****  This session is using a temporary cart id, cart contents will not be saved.   *****
******************************************************************************************
-->
~,						};
					}

				push @SITE::ENDPAGE, { 
'TYPE'=>'OUTPUT', HTML=>qq~<!--\n CART=[$CARTID] TS=[~.&ZTOOLKIT::pretty_date($START_GMT,2).qq~] IP=[~.$SITE->ip_address().qq~]
TOOK=[~.(time()-$START_GMT).qq~ sec.] CYCLES=[$END_TIMES_user/$END_TIMES_system] SERVER[~.&ZOOVY::servername().qq~.$$] 
USER[~.$SITE->username().qq~] build[$::BUILD]\nPAGE[~.$SITE->pageid().qq~] PRT[~.$SITE->prt().qq~] 
FS[~.$SITE->fs().qq~] LAYOUT[~.$SITE->layout().qq~] WRAPPER[$DOCID] PG[~.$SITE->pageid().qq~] HOST[~.$SITE->domain_host().qq~] 
DN:[~.$SITE->client_is().qq~] MVS[$AB]\n-->\n~ };
				}

			if (defined $req) {
				$BODY .= (&SITE::run(\%SUBS,\@SITE::ENDPAGE,$wrappertoxml,$SITE));
				}
			}
		undef %SUBS;
	
	

		## THIS IS THE ONLY PLACE WE SHOULD EVER CALL SAVE ON A PERSISTENT CART
		if ($SITE->pageid() eq 'missing404') {
			## don't save on 404 pages
			## NOTE: PLEASE LEAVE THIS ALONE.
			## this is used by the 404 handler (in particular, but perhaps elsewhere) to make sure we don't
			## save carts on 404 pages. this necessary because if for example a broken graphic tries to load under
			## the user domain e.g. http://www.userdomain.com//http:://idon'tknowtomakelinksproperlyorliketolinktononexistantjsfiles
			##	then (without this) it would/could cause a SAVE, 
			##	thus creates a race condition if the requesting page is saved after the 404
			## (which it normally would be since the 404 was requested instantly AFTER the page should it SHOULD be saved after normally)
			## this is an issue for example on an add to cart, where the race condition would atomically overwrite the
			## cart, thereby resetting the cart to BEFORE the add item, thus causing the customer to report "items dropping"
			## and other odd unexplained behaviors. There is no reason we ever need to save the fact we were on a 404 page.
			## at least no reason that is more important or mitigates the nasty effect of user stupidity described above.
			}
		else {
			##########################################
			## NOTE: all the "memory" functions need to be at the bottom *AFTER* the rendering phase.
			##

			if ($SITE->fs() eq 'C') {
				## remember which navcats we've visited.
				my @navcats = split(/,/, &ZTOOLKIT::def($SITE::CART2->pu_get('app/memory_navcat')));
				unshift @navcats, $SITE->pageid();
				$SITE::CART2->pu_set('app/memory_navcat', join(",",splice(@navcats,0,10)) ); 
				}
			elsif (($SITE->pageid() eq 'product') && ($SITE->pid() ne ''))  {
				my @products = split(/,/, &ZTOOLKIT::def($SITE::CART2->in_get('app/memory_visit')));
				unshift @products, $SITE->pid();
				$SITE::CART2->pu_set('app/memory_visit', join(",",splice(@products,0,25)) ); 
				}

			## this line saves carts, etc.
			$SITE::CART2->cart_save('persist_final'=>1);
			}

		}


	
	if (defined $SITE::HANDLER) {
		## okay, so I guess we shouldn't continue
		}
	elsif (substr($SITE->pageid(),0,1) eq '?') {
		## NOTE: we set non-renderable page flows to *TYPE/reason for tracing.
		(my $PAGEID,my $SENDER) = split(/\//s,$SITE->pageid(),2);
		$SITE->pageid($PAGEID);

	
		print STDERR $SITE->username()." SPECIALITY HANDLER: ".$SITE->pageid()." [$SENDER] [$ENV{'REQUEST_METHOD'}]\n";
		if ($SITE->pageid() eq '?ERROR') {
			# if ($assbackwards) { print "HTTP/1.0 501 Error\nServer: Apache!\n"; }
			$SITE::HANDLER = [ 'ISE', { 'Content-Type'=>'text/html' } ];
			$BODY .= ("<head><title>".$SITE->title()."</title></head><body>$SENDER</body>"); 
			}
		elsif ($SITE->pageid() eq '?AJAX') {
			require PAGE::AJAX;
			$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/plain' } ];
			$HEADERS->push_header('Expires'=>'-1');
			$BODY .= (PAGE::AJAX::handle($SITE,$SENDER));
			}
		elsif ($SITE->pageid() eq '?EXPORT') {
			require PAGE::DATAEXPORT;
			$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/plain' } ];
			# if ($assbackwards) { print "HTTP/1.0 200 Ok\nServer: Apache!\n"; }
			my ($FILE,$TYPE) = split(/\./,uc($SENDER));
			if ($TYPE eq 'CSV') { 
				$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/csv' } ];
				}
			elsif ($TYPE eq 'XML') { 
				$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/xml' } ];
				}
			else { 
				$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/html' } ];
				}
	
			## note: this does it's own printing to allow streaming.
			($BODY) = PAGE::DATAEXPORT::handle($SITE, $SENDER);
			}
		elsif ($SITE->pageid() eq '?MISSING') {
			########################################
			## 404 NOT FOUND
			# print "HTTP/1.0 404 OK\n";
			#if ($assbackwards) { $|++; print "HTTP/1.0 404 Not found\n\rServer: Apache!\n\r";  }
			$SITE::HANDLER = [ 'MISSING', {} ];
			}
		elsif ($SITE->pageid() eq '?EMPTY') {
			$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/html' } ];
			}
		elsif ($SITE->pageid() eq '?REDIRECT') {
			## hmm.. 302 is temporarily moved, 301 is permanently moved.
			## $sender could be 302|message, or 301|message

			my $code = 302; # default
			if (substr($SENDER,3,1) eq '|') { 
				$code = int(substr($SENDER,0,3)); 
				if (($code!=302) && ($code!=301)) { $code = 302; }
				$SENDER = substr($SENDER,4);	# strip the 301| or 302|
				}
	
			#if ($assbackwards) { 
	      #   my $txt = ($code==301)?'Moved Permanently':'Moved';
	      #   print "HTTP/1.0 $code $txt\nServer: Apache!\n";
	 		#	}
			#print STDERR "SENDER: $SENDER\n";
			#die();
			my $url = $SITE::REDIRECT_URL;

			if ((not defined $url) && (defined $SITE->URLENGINE())) {
				$url = $SITE->URLENGINE()->get('home_url');
				}


			if ((defined $SITE::OVERRIDES{'dev.disable_rewrite'}) && ($SITE::OVERRIDES{'dev.disable_rewrite'})) { 
				## implictly turns off any url rewriting.
				## especially important if we're going offsite.
				}
			elsif ($SENDER eq '[[GOOGLECHECKOUT]]') {
				## offsite link to google - do not redirect
				}		
			elsif ((defined $SITE->URLENGINE()) && (($SITE->URLENGINE()->state() & 4)==0)) {
				## include a cart if we need one.. eventually this will always be true.
				$url = $SITE->URLENGINE()->rewrite($url);
				}

			print STDERR "FINAL REDIRECT TO: $url [$SENDER] via $code\n";
			## THIS IS VERY BAD: it will cause a "this page has moved" message
			# $r->content_type("text/html");
			$HEADERS->push_header("Zoovy-Debug"=>"$SENDER");
			&legacyCookies($SITE,$req,$HEADERS);
			## response header splitting.
			$url =~ s/[\n\r]+//gs;
			$url =~ s/%0[AD]//gs;
			$SITE::HANDLER = [ 'REDIRECT', { 'LOCATION'=>$url, 'CODE'=>$code } ];
			}
		}
	

	if ($SITE::HAVE_GLOBAL_DB_HANDLE>0) {
		$SITE::HAVE_GLOBAL_DB_HANDLE = 0;
		&DBINFO::db_user_close(); 
		}

	
	
	###############################################################
	## CLEANUP
	##

#	## something is leaving db handles open
#	while (  $DBINFO::DBH_ORDER_INSTANCE_COUNT > 0) { &DBINFO::db_user_close(); }


	# &DBINFO::db_user_close($SITE->username());
	# unlink($SITE::DEBUG_FILE);
	
	$SITE::v               = {};
	$SITE::v_mixed         = {};
	$SITE::target          = '_self';
	$SITE::HAVE_GLOBAL_DB_HANDLE = undef;
	undef $SITE::REDIRECT_URL;
	
	undef @SITE::STARTUP;
	undef @SITE::PREBODY;
	undef @SITE::ENDPAGE;
	undef %SITE::PAGES;
	
	undef $SITE::v;
	undef $SITE::v_mixed;
	undef $SITE::CART2;
	
	undef %SITE::OVERRIDES;
	undef $SITE::JSRUNTIME;
	undef $SITE::JSCONTEXT;
	undef $SITE::JSOUTPUT;
	undef $SITE::SREF;
	
	undef $SITE::CONFIG;
	undef $wrappertoxml;
	
	return ($BODY);
	}
	


##
##
##
sub seoHTML5CompatibilityResponseHandler {
	my ($SITE,$req,$HEADERS) = @_;
	
	my $DNSINFO = $SITE->dnsinfo();
	my $HOSTDOMAIN = sprintf("%s.%s",$DNSINFO->{'HOST'},$DNSINFO->{'DOMAIN'});
	print STDERR "SEOCOMPAT\n";

	$SITE::HANDLER = undef;

	require PRODUCT::FLEXEDIT;
	my $CANONICAL_URL = undef;
	my $PROJECTID =  $DNSINFO->{'%HOSTS'}->{ $DNSINFO->{'HOST'} }->{'PROJECT'};
	my $PATH_INFO = $req->path_info();

	my $USERNAME = lc($SITE->username());
	my $PARAMSREF = &ZTOOLKIT::parseparams($1);
	$SITE->projectid($PROJECTID);

	## static html site.
	my $filename = $req->path_info();
	# $filename =~ s/\/app\//\//s;
	my $nfsdir = &ZOOVY::resolve_userpath($USERNAME).'/PROJECTS/'.$PROJECTID;
	$HEADERS->push_header('X-Project'=>$PROJECTID);

	#if ($req->path_info() eq '/') {
	#	$SITE::HANDLER = [ 'REDIRECT', { 'Location'=>'/index.html' } ];
	#	return();
	#	}
	if (($SITE->uri() =~ m/^\/(product|category|customer)\/(.*?)$/o) || ($SITE->uri() eq '/')) {
		## SEO Compatibility always maps to index.html
		$filename = "/index.html";
		}
	## file doesn't exist on nfs, maybe it's index.html or index.htm
	elsif ($filename eq '/') { $filename = '/index.html'; }
	elsif (substr($filename,0,1) ne '/') { $filename = "/$filename"; }	# make sure filename has a leading slash (not sure if this is necessary)
	else {
		## strip leading /s=www.domain.com/	
		$filename =~ s/\/s\=[a-z0-9\.\-]+\//\//;
		## strip trailing /c=www.domain.com
		$filename =~ s/\/c\=[a-z0-9A-Z]+\//\//;
		$filename =~ s/[\.]+/./gs;	## don't let them descend dirs.
		$filename =~ s/[\/]+/\//gs;	## don't let them reset to root. descend dirs.
		}
	
	## SANITY: at this point $filename is done being rewritten

	my $NETWORKFILE = sprintf("%s/%s",$nfsdir,$filename);
	my $LOCALCACHEDIR = "/local/cache/$USERNAME/$PROJECTID";
	my $LOCALFILE = sprintf("/local/cache/$USERNAME/%s%s",$PROJECTID,$filename);

	print STDERR "FILE:$filename\n";

	my $USE_CACHE = 1;	
	my ($memd) = &ZOOVY::getMemd($USERNAME);
	if (defined $memd) {
		my $PROJECT_TS = $memd->get("$USERNAME.$PROJECTID");
		if (not defined $PROJECT_TS) {
			## no timestamp in memcache, so we load one, and we set 
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$nfsdir");
			$PROJECT_TS = $mtime;
			$memd->set("$USERNAME.$PROJECTID",$PROJECT_TS);
			}

		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$LOCALCACHEDIR");
		if ($ino == 0) {
			## local cache does not exist, so create it.
			if (! -d "/local/cache/$USERNAME") {
				mkdir "/local/cache/$USERNAME";
				chown $ZOOVY::EUID,$ZOOVY::EGID, "/local/cache/$USERNAME";
				chmod 0777, "/local/cache/$USERNAME";
				}
			mkdir "/local/cache/$USERNAME/$PROJECTID";
			chown $ZOOVY::EUID,$ZOOVY::EGID, "/local/cache/$USERNAME/$PROJECTID";
			chmod 0777, "/local/cache/$USERNAME/$PROJECTID";	
			$USE_CACHE = 0;
			}
		elsif ($mtime < $PROJECT_TS) {
			## flush cache by moving, then nuking directory.
			warn "FLUSH CACHE FOR $LOCALCACHEDIR\n";
			system("/bin/mv $LOCALCACHEDIR $LOCALCACHEDIR.$$; /bin/rm -Rf $LOCALCACHEDIR.$$");
			$USE_CACHE = 0;
			}
		else {
			## local cache can be used, yay!
			$USE_CACHE++;
			}
		}

	##
	##
	##		
	my $BODY = '';
	if (not $USE_CACHE) {
		print STDERR "not USE_CACHE\n";
		open F, "<$nfsdir/$filename"; $/ = undef; $BODY = <F>; $/ = "\n"; close F;
		}
	elsif (-f "$LOCALFILE") {
		## BEST CASE, LOCAL FILE AND IT EXISTS
		warn "LOCAL FILE (BEST CASE): $LOCALFILE\n";
		open F, "<$LOCALFILE"; $/ = undef; $BODY = <F>; $/ = "\n"; close F;
		}
	elsif (-f "$LOCALFILE.missing") {
		## MISSING CASE, LOCAL DIR EXISTS, with FILE MISSING (point at local file)
		warn "MISSING: $LOCALFILE\n";
		$BODY = '';
		}
	else {
		## WORST CASE: LET'S GET IT FROM THE SERVER
		print STDERR "COPY '$nfsdir/$filename' to '$LOCALFILE'\n";

		## STEP1: create local dirs to hold it.
		my @PARTS = split(/\//,$filename);
		if (scalar(@PARTS)>2) {
			shift @PARTS; # strip leading /
			pop @PARTS; # discard filename
			my $TMPDIR = "$LOCALCACHEDIR";
			foreach my $part (@PARTS) {
				my $PATH = "$TMPDIR/$part";
				## print STDERR "PATH:$PATH\n";
				$TMPDIR = "$TMPDIR/$part";	## note: don't put this after the dir is created
				next if (-d "$PATH");
				mkdir "$PATH";
				chmod 0777, "$PATH";
				}
			}

		my $BODY = undef;
		if (-f "$nfsdir/$filename") {
			open Fin, "<$nfsdir/$filename"; $/ = undef;
			($BODY) = <Fin>;
			close Fin; $/ = "\n";
			}
		## 
		if (not defined $BODY) {
		## SHIT!: FILE DOES NOT EXIST
			open F, ">$LOCALFILE.missing";
			print F "$nfsdir/$filename not found\n";
			close F;
			}
		else {
			## JUST COPY
			open F, ">$LOCALFILE";
			print F $BODY;
			close F;
			}
		}


	##
	my %META = ();
	my $MEMCACHE_META_KEY = '';
	if ($filename eq '/index.html') {
		$MEMCACHE_META_KEY = sprintf("%s+%s+%s",$USERNAME,$HOSTDOMAIN,$PATH_INFO);
		my $json = $memd->get("$MEMCACHE_META_KEY");
		if ($json ne '') {
			warn "USED MEMCACHE FOR PATHINFO\n";
			%META = %{JSON::XS::decode_json($json)};
			}
		}

	if ($filename ne '/index.html') {
		## we are serving a non-index.html file, we are done here.
		if ($BODY eq '') {
			## CRITICAL ERROR
			$BODY .= (q~<!DOCTYPE HTML>~); #HTML5 has no doctype specified
			$BODY .= ("<html><h1>Missing file $filename</h1></html>");
			$SITE::HANDLER->[0] = 'MISSING';
			}
		}	
	elsif (scalar(keys %META)>0) {
		## we already computed the meta for this path_info
		warn "Already had META (probably cached!)\n";
		print STDERR Dumper(\%META);
		}
	elsif ($PATH_INFO =~ /^\/category\/(.*?)$/o) {
		## START of /category handling
		my $ORIGINALPATH = my $CLEANEDPATH = $1;
		if ($CLEANEDPATH !~ /\/$/) { $CLEANEDPATH .= "/"; }
		$CLEANEDPATH =~ s/[\/]+/\//gs;
		$CLEANEDPATH = lc($CLEANEDPATH);
		$CANONICAL_URL = "/category/$CLEANEDPATH";

		my $SAFEPATH = $CLEANEDPATH;
		$SAFEPATH =~ s/\//\./gs;
		$SAFEPATH =~ s/[^a-zA-Z0-9\-\_\.]//gs;
		# $SAFEPATH =~ s/\.+/\./gos; # make multiple dots into a single (useful if we prepended an extra at the begining for some reason)
		if (substr($SAFEPATH,0,1) ne '.') { $SAFEPATH = ".$SAFEPATH"; }
		if (substr($SAFEPATH,-1) eq '.') { $SAFEPATH = substr($SAFEPATH,0,-1); }

		if ($CLEANEDPATH eq '/') {
			$SITE::HANDLER = [ 'REDIRECT', { 'LOCATION'=>'/' } ];
			}
		elsif ($CLEANEDPATH ne $ORIGINALPATH) {
			$SITE::HANDLER = [ 'REDIRECT', { 'LOCATION'=>"/category/$CLEANEDPATH" } ];
			# $META{'_BODY'} = "CLEAN:$CLEANEDPATH ne ORIG:$ORIGINALPATH";
			}
		else {
			my ($NC) = $SITE->get_navcats();
			my ($modified_gmt) = $NC->modified($SAFEPATH);
			if ($modified_gmt<=0) {
				$SITE::HANDLER = [ 'REDIRECT', { 'LOCATION'=>'/' } ];
				# $META{'_BODY'} = "MODIFIED: $modified_gmt SAFE:$SAFEPATH\n";
				}
			else {
				# $META{'_BODY'} = "SAFEPATH: $SAFEPATH\n";
				my ($pretty,$children,$products,$sort,$metaref,$modified_gmt) = $NC->get($SAFEPATH);
				$META{'_BODY'} .= "<h1>$pretty</h1>";

				$META{'title'} = $pretty;

				my ($bcorder,$bcnames) = $NC->breadcrumb($SAFEPATH);
				unshift @{$bcorder}, ".";
				$bcnames->{'.'} = 'Home';
				if (scalar(@{$bcorder})>0) {
					my @links = ();
					foreach my $bcsafe (@{$bcorder}) {
						push @links, sprintf("<span><a href=\"/category/%s\">%s</a></span>\n",substr($bcsafe,1),$bcnames->{$bcsafe});
						}
					$META{'_BODY'} .= join(" | ",@links);
					}

				$META{'_BODY'} .= "<ul class=\"subcategories\">";
				foreach my $childsafe (@{$NC->fetch_childnodes($SAFEPATH)}) {
					my ($childpretty,$childchildren,$childproducts,$childsort,$childmetaref,$childmodified_gmt) = $NC->get($childsafe);
					next if (substr($childpretty,0,1) eq '!');
					$META{'_BODY'} .= "<li> <a href=\"/category/$childsafe\"> $childpretty</a>";
					}
				$META{'_BODY'} .= "</ul>";

				my ($PG) = $SITE->pAGE($SAFEPATH);
				$META{'_BODY'} .= sprintf("<div id=\"description\" name=\"description\">%s</div>\n",$PG->get('desciption'));

				$META{'keywords'} = $PG->get('meta_keywords');
				$META{'description'} = $PG->get('meta_description');
				if ($PG->get('page_title') ne '') {
					$META{'title'} = $PG->get('page_title');
					}
			
				$META{'_BODY'} .= "<hr>";
	
				foreach my $PID (split(/,/,$products)) {
					next if ($PID eq '');
					my ($P) = PRODUCT->new($SITE->username(),$PID,'create'=>0);
					my $url = $P->public_url('style'=>'vstore');
					my $src = &ZOOVY::image_path($SITE->username(),$P->fetch('zoovy:prod_image1'),H=>75,W=>75);
					$META{'_BODY'} .= "<div class=\"product\" id=\"product:$PID\">
<a href=\"$url\">
<img style=\"align: left\" alt=\"".$P->fetch('zoovy:prod_name')."\" border=0 width=50 height=50 src=\"$src\">
<b>".$P->fetch('zoovy:prod_name')."</a></b><br>
".$P->fetch('zoovy:prod_desc')."
<i>\$".sprintf("%.2f",$P->fetch('zoovy:base_price'))."
</div>";
					}
				}
			}


		## END OF /category handler
		}
	elsif ($PATH_INFO =~ /^\/product\/(.*)$/) {
		my ($PIDPATH) = $1;

		my $PID = undef;
		# handle /product/pid/asdf
		if ($PIDPATH =~ /^(.*?)\/.*$/) {	$PID = $1; }
		# handle /product/pid
		if ((not defined $PID) && ($PIDPATH =~ /^([A-Z0-9\-\_]+)$/)) { $PID = $PIDPATH; }


		my ($P) = PRODUCT->new($SITE->username(),$PID,'create'=>0);

		if (defined $P) {
			my ($NC) = $SITE->get_navcats();
			$CANONICAL_URL = $P->public_url('style'=>'vstore');

			foreach my $safe (@{$NC->paths_by_product($PID)}) {
				my ($pretty,$children,$products,$sort,$metaref,$modified_gmt) = $NC->get($safe);
				next if (substr($pretty,0,1) eq '!');

				my ($bcorder,$bcnames) = $NC->breadcrumb($safe);
				if (not defined $bcorder) {
					$META{'_BODY'} .= "<!-- no breadcrumbs for $safe -->";
					}
				elsif (scalar(@{$bcorder})>0) {
					my @links = ();
					foreach my $bcsafe (@{$bcorder}) {
						push @links, sprintf("<span><a href=\"/category/%s/index.html\">%s</a></span>\n",substr($bcsafe,1),$bcnames->{$bcsafe});
						}
					$META{'_BODY'} .= "<li> ".join(" | ",@links);
					}
				}
			}

		## modified  1/7/13 
		## www.ekoreparts.com/product/VA-01/SIEMENS-SFA71U-24-Vac-NC-2-POSITION-VALVE-ACTUATOR.html
		## used privacy policy because it was the first div with content.
		## www.google.com/webmasters/tools/richsnippets

		if (not defined $P) {
			$SITE::HANDLER = [ 'MISSING', {} ];
			}
		else {
			my $prodref = $P->prodref();
			$META{'_BODY'} .= "<div itemscope itemtype=\"http://schema.org/Product\">\n";
			$META{'_BODY'} .= "<h1 itemprop=\"name\" data-attribute=\"zoovy:prod_name\">$prodref->{'zoovy:prod_name'}</h1>\n";
			$META{'_BODY'} .= "<section itemprop=\"offers\" itemscope itemType=\"http://schema.org/Offer\"><span itemprop=\"price\">\$$prodref->{'zoovy:base_price'}</span></section>\n";
			$META{'_BODY'} .= "<div itemprop=\"manufacturer\" itemscope itemtype=\"http://schema.org/Organization\" data-attribute=\"zoovy:prod_mfg\">$prodref->{'zoovy:prod_mfg'}</div>\n";
  		   $META{'_BODY'} .= "<div itemprop=\"model\" data-attribute=\"zoovy:prod_mfgid\">$prodref->{'zoovy:prod_mfgid'}</div>\n";
			$META{'_BODY'} .= "<section itemprop=\"description\">\n\n";
			$META{'_BODY'} .= "	<div data-attribute=\"zoovy:prod_desc\">$prodref->{'zoovy:prod_desc'}</div><br />\n";
			$META{'_BODY'} .= "	<div data-attribute=\"zoovy:prod_detail\">$prodref->{'zoovy:prod_detail'}</div><br />\n";
  	  		$META{'_BODY'} .= "  <div data-attribute=\"zoovy:prod_features\">$prodref->{'zoovy:prod_features'}</div><br />\n";
			$META{'_BODY'} .= "</section>\n\n";
		
			if($prodref->{'youtube:videoid'})	{
				$META{'_BODY'} .= "<div itemprop=\"video\" itemscope itemtype=\"http://schema.org/VideoObject\">\n";
				$META{'_BODY'} .= "<h2 itemprop=\"name\">$prodref->{'youtube:video_title'}</h2>";
				$META{'_BODY'} .= "<meta itemprop=\"thumbnail\" content=\"http://i1.ytimg.com/vi/$prodref->{'youtube:videoid'}/default.jpg\" />";
				$META{'_BODY'} .= "<object width=\"560\" height=\"315\"><param name=\"movie\" value=\"http://www.youtube.com/v/$prodref->{'youtube:videoid'}?version=3&amp;hl=en_US\"></param>";
				$META{'_BODY'} .= "<param name=\"allowFullScreen\" value=\"true\"></param><param name=\"allowscriptaccess\" value=\"always\"></param>";
				$META{'_BODY'} .= "<embed src=\"http://www.youtube.com/v/$prodref->{'youtube:videoid'}?version=3&amp;hl=en_US\" type=\"application/x-shockwave-flash\" width=\"560\" height=\"315\" allowscriptaccess=\"always\" allowfullscreen=\"true\"></embed></object>";
				$META{'_BODY'} .= "<div itemprop=\"description\">$prodref->{'youtube:video_description'}</div>";
				$META{'_BODY'} .= "</div>"
				}
			$META{'_BODY'} .= "<h2>Images</h2>";
			foreach my $k ('zoovy:prod_image1','zoovy:prod_image2','zoovy:prod_image3','zoovy:prod_image4') {
				next if (substr($k,0,1) eq '%');
				next if ($prodref->{$k} eq '');			
				$META{'_BODY'} .= "<div data-attribute=\"$k\">$prodref->{$k}</div>\n";
				}
			$META{'_BODY'} .= "</div><!-- /product itemscope -->\n";
			## Need to get reviews in here. you get them in, I'll format. (jt note:  formatting here: http://schema.org/Product)

			$META{'title'} = $prodref->{'zoovy:prod_name'};
			$META{'keywords'} = $prodref->{'zoovy:prod_keywords'};
			$META{'description'} = $prodref->{'zoovy:prod_desc'};
			}

		}
	elsif ($PATH_INFO =~ /^\/customer\/(.*?)$/o) {
		$CANONICAL_URL = '/customer';
		$META{'_BODY'} .= "<h1>Customer Access</h1>";
		$META{'_BODY'} .= "<i>Please enable javascript to access our customer application.</i>";
		$META{'title'} = 'Customer Access';
		$META{'description'} = 'Customer login';
		}
	else {
		$CANONICAL_URL = '/';
		# $META{'title'} = 'Homepage';
		my ($PG) = $SITE->pAGE(".");
		if (defined $PG) {
			$META{'title'} = $PG->get('page_title');
			$META{'description'} = $PG->get('meta_description');
			$META{'keywords'} = $PG->get('meta_keywords');
			}

		my ($NC) = $SITE->get_navcats();
		my ($order,$names,$metaref,$SAFEPATH) = $NC->build_turbomenu($NC->rootpath(),undef,undef);

		foreach my $safe (@{$order}) {
			## below: substr($safe,1) removes leading . from $safe
			$META{'_BODY'} .= sprintf("<a href=\"#!category?navcat=%s&title=%s\">%s</a>\n",$safe,$names->{$safe},$names->{$safe});
			}		
		}


	if ((defined $SITE::HANDLER) && (ref($SITE::HANDLER) eq 'ARRAY') && ($SITE::HANDLER->[0] eq 'MISSING')) {
		## 
		}
	elsif ($filename ne '/index.html') {
		## NON-index.html FILE
		## Detect Mime Type
		if ($filename =~ /\.gif$/) {
			$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'image/gif' } ];			
			}
		elsif ($filename =~ /\.jpg$/) {
			$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'image/jpg' } ];			
			}
		elsif ($filename =~ /\.png$/) {
			$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'image/png' } ];			
			}
		elsif ($filename =~ /\.json$/) {
			$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'application/json' } ];			
			}
		elsif ($filename =~ /\.js$/) {
			$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'application/javascript' } ];			
			}
		elsif ($filename =~ /\.html$/) {
			$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/html' } ];			
			}
		else {
			require MIME::Types;
			my ($mime_type, $encoding) = MIME::Types::by_suffix($filename);
			$mime_type = $mime_type || "file/unknown; filename=$filename"; 
			$SITE::HANDLER = [ 'DONE', { 'Content-Type'=> $mime_type } ];
			}
		}
	else {
		$META{'_PATH'} = $PATH_INFO;
		$memd->set( $MEMCACHE_META_KEY, JSON::XS::encode_json(\%META) );
		$META{'content-type'} = 'text/html; charset=UTF-8';
		$META{'author'} = "SEO HTML5 Compatibility Layer r.$::BUILD p.$PROJECTID server:".&ZOOVY::servername();
		
		$SITE::HANDLER = [ 'DONE', { 'Content-Type'=>'text/html' } ];
	
		my $seobody = '';
		$seobody .= sprintf("<!-- DEBUG GENERATED:%s SERVER:%s -->",&ZTOOLKIT::pretty_date(time(),3),&ZOOVY::servername());
		if ($ENV{'QUERY_STRING'} !~ /\_escaped\_fragment\_\=/) {
			$seobody .= "<div class=\"displayNone seo\" id=\"seo-html5\"><!-- HTML5 SEO COMPATIBILITY -->\n$META{'_BODY'}\n<!-- /HTML5 SEO COMPATIBILITY --></div>\n";
			}
		else {
			$seobody .= "<!-- HTML5 SEO COMPATIBILITY -->\n$META{'_BODY'}\n<!-- /HTML5 SEO COMPATIBILITY -->\n";
			}
		$BODY =~ s/(\<[Bb][Oo][Dd][Yy].*?\>)/$1$seobody/sog;

		## insert meta SEO compat layer into <head>
		my $meta = '';
		$CANONICAL_URL = sprintf("http://%s%s",$HOSTDOMAIN,$CANONICAL_URL);
		$meta .= qq~\n<link rel="canonical" href="$CANONICAL_URL#!v=1" />\n~;
		foreach my $k (keys %META) {
			next if (substr($k,0,1) eq '_');
			$META{$k} = &ZTOOLKIT::htmlstrip($META{$k});
			$meta .= sprintf("<meta name=\"%s\" content=\"%s\" />\n",$k,&ZOOVY::incode($META{$k}));
			}
		$BODY =~ s/(\<[Hh][Ee][Aa][Dd].*?\>)/$1$meta/s;
		}

	return($BODY);
	}







##
##
##

sub legacyCookies {
	my ($SITE,$req,$HEADERS) = @_;
	# This function is used both by redir and header
	# We load up the @SITE::cookies array as we start processing the page, and then we output them here
	# The reason for this is so that
	#	a) we can render the same cookies as javascript too
	#		(the JS version of the cookies is stored in $SITE::js_cookies and is called by &FLOW::render_head)
	#	b) we are not comitted to output until the very last stage (we can wipe out some cookies if we need)
	#	c) cookie troubleshooting can be consolidated
	# The cart cookie is always present.

	if ((not defined $SITE::CART2) || (ref($SITE::CART2) ne 'CART2')) { 
		return(); 
		}

	my @cookies = ();

	my $session = $SITE::CART2->cartid()."|t.".time()."|s.".&ZOOVY::servername();
	push @cookies, {'name' => $SITE->our_cookie_id(), 'value' => $session, 'hours' => 72, 'httponly'=>1, };

	my $js_cookies = '';
	$js_cookies = qq~<script type="text/javaScript">\n~;
	$js_cookies .= qq~<!--\n~;
	$js_cookies .= qq~today = new Date();\n~;
	foreach my $cookie (@cookies) {
		my $domain = (defined $ENV{'SERVER_NAME'})?lc($ENV{'SERVER_NAME'}):'';;
		$domain =~ s/.*(\.[a-z0-9\-]+\.[a-z][a-z][a-z]+)\.?$/$1/s; ## www.domainname.com -> .domainname.com / www.domainname.info -> .domainname.info
		$domain =~ s/.*(\.[a-z0-9\-]+\.[a-z0-9\-]+\.[a-z][a-z])\.?$/$1/s; ## www.domainname.co.uk -> .domainname.co.uk
		my %defaults = (
			'name'	 => 'name',
			'value'	=> 'value',
			'domain'  => $domain,
			'hours'	=> 1,
			'path'	 => '/',
			'secure'  => 0,
			'destroy' => 0,
			);
		my %set_cookie = ();
		my %params	  = %defaults;
		# Note: hours and destroy are missing from this list since they don't directly translate into params for cgi->cookie
		foreach my $key (qw(name value domain path secure)) {
			$set_cookie{"-$key"} = $defaults{$key};
			next unless (defined $cookie->{$key});
			$set_cookie{"-$key"} = $cookie->{$key};
			$params{$key} = $cookie->{$key};
			}

		#if ($cookie->{'destroy'}) {
		#	$set_cookie{'-value'}	= '';
		#	$set_cookie{'-expires'} = '-350d';
		#	$js_cookies .= qq~expires = new Date(0);\n~;
		#	}
		#else {
		$set_cookie{'-expires'} = "+$cookie->{'hours'}h";
		my $ticks = $cookie->{'hours'} * 3600000;
		$js_cookies .= qq~expires = new Date(today.getTime() + $ticks);\n~;
		#	}
		my $esc_name  = &CGI::escape($params{'name'});
		my $esc_value = &CGI::escape($params{'value'});
		my $secure	 = $params{'secure'} ? "; secure" : '';
		my $httponly	 = $params{'httponly'} ? "; httponly" : '';
		$js_cookies .= qq~document.cookie = "$esc_name=$esc_value; expires=" + expires.toGMTString() + "; domain=$params{'domain'}; path=$params{'path'}$secure$httponly";\n~;

		$HEADERS->push_header('Set-cookie'=>  CGI::cookie(%set_cookie));

		} ## end foreach my $cookie (@SITE::cookies...
	$js_cookies .= qq~//-->\n~;
	$js_cookies .= qq~</script>\n~;
	$SITE->{'__JSCOOKIES__'} = $js_cookies;
	return();
	}












__DATA__







