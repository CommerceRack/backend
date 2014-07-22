#!/usr/bin/perl


use URI::Escape::XS qw();
use HTTP::Date qw();
use Data::Dumper;
use POSIX;
use Image::Magick qw();
use Plack::Request;
use Plack::Response;
use MIME::Types qw();
use Coro::AnyEvent;
use AnyEvent::Redis;

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

## http://search.cpan.org/CPAN/authors/id/M/MI/MIYAGAWA/Plack-Middleware-ReverseProxy-0.15.tar.gz

my $app = sub {
	my $env = shift;


	my $HEADERS = HTTP::Headers->new;
	my $req = Plack::Request->new($env);
	my $path = $req->path_info;

	print STDERR "REQUEST METHOD: ".$req->method()."\n";

	## strip leading /s=www.domain.com/	
	$path =~ s/\/s\=[a-z0-9\.\-]+\//\//;
	## strip trailing /c=www.domain.com
	$path =~ s/\/c\=[a-z0-9A-Z]+\//\//;

	my $BODY = undef;
	my $HTTP_RESPONSE = undef;

	$HEADERS->push_header( 'X-Powered-By' => 'ZOOVY/v.'.&ZOOVY::servername() );
	## print STDERR "METHOD: ".$req->method()." -- $path\n";

	
	if (defined $HTTP_RESPONSE) {
		## we're already done! (probably an error)
		}
	elsif ($path =~ /^\/jsonapi\/upload/) {
		## we handle options *very* differntly for jsonapi/upload requests so we'll do that later.
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
		# print STDERR 'H: '.Dumper($h);
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
			# print STDERR Dumper($HEADERS);
			my $res = Plack::Response->new($HTTP_RESPONSE,$HEADERS,$BODY);
			## short circuit!
			return($res->finalize);
			}
		}


	##
	##
	##		
	my $AGE = (86400*45);
	my $DNSINFO = undef;
	my $URI = $req->uri();
	my ($HOSTDOMAIN) =  $URI->host();
	## print STDERR "HOSTDOMAIN:$HOSTDOMAIN\n";
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
	elsif (not defined $HTTP_RESPONSE) {
		## parse 
		if ((defined $req) && ($req->method() eq 'HEAD')) {};		## TODO: add support for HEAD
		setlocale("LC_CTYPE", "en_US");

		## This handles a POST
		my $params = $req->parameters();
		foreach my $k ($params->keys()) {
			my ($x) = $params->get($k);

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
				$v = JSON::XS::decode_json($req->raw_body());
				}
			}
		}


   if (defined $HTTP_RESPONSE) {
      ## we're already done! (probably an error)
      }
	elsif ($path =~ /^\/jsonapi\/call\/([a-zA-Z]+)\.json/) {
		## future jsonapi/call/appResource?filename=elastic_public.json
		
		}
   elsif ($path =~ /^\/jsonapi\/plugin\/([a-z0-9]+)\.(xml|json|txt)$/) {
      ## we handle options *very* differntly for jsonapi/upload requests so we'll do that later.
		my $module = uc($1);
		my $output = $2;

		if ($module eq 'SHIPWORKS') {
			require PLUGIN::SHIPWORKS;		
			my ($plugin) = PLUGIN::SHIPWORKS->new($DNSINFO,$v);
			($HTTP_RESPONSE, $HEADERS, $BODY) = $plugin->jsonapi($path,$req,$HEADERS);
			}
		elsif ($module eq 'SHIPSTATION') {
			require PLUGIN::SHIPSTATION;		
			my ($plugin) = PLUGIN::SHIPSTATION->new($DNSINFO,$v);
			($HTTP_RESPONSE, $HEADERS, $BODY) = $plugin->jsonapi($path,$req,$HEADERS,$env);
			# using OO interface
			}
		##
		## ADD YOUR OWN CUSTOM MODULE/EXPORT HERE
		##
		else {
			$HTTP_RESPONSE = 500;
			$BODY = qq~Unknown plugin: $module~;
			}

		if ($HTTP_RESPONSE == 200) {
			$HEADERS->push_header( 'Content-type' => "text/$output" );
			}

      }
  	


	## AT THIS POINT $v is populated
	my $JSAPI = undef;
	
	if (defined $HTTP_RESPONSE) {
		## we're already done! (probably an error)
		}
	## NOTE: be careful with the path as it may contain shit like /s=/
	## /jquery/config.js /jsonapi/config.js
	elsif ($path =~ /^\/jsonapi\/v\-201[45][\d][\d]+\/(.*?)$/o) {
		## jsonapi/v-201405/api.api.api
		$path = '/jsonapi/';
		}
	elsif ($path =~ /^\/(jquery|jsonapi)\/config\.js$/) {
		$JSAPI = JSONAPI->new('__config.js__');

      print STDERR 'DNSINFO: '.Dumper($DNSINFO)."\n";

		my ($SITE) = SITE->new($DNSINFO->{'USERNAME'},'%DNSINFO'=>$DNSINFO);
		$JSAPI->psgiinit($req,$v,'*SITE'=>$SITE);

		
		if (not defined $SITE) {
			print STDERR 'INVALID SITE: '.Dumper($ENV);
			$HTTP_RESPONSE = 404;
			}
		elsif (ref($SITE) ne 'SITE') {
			$HTTP_RESPONSE = 404;
			}
		else {
			print STDERR "Sending bootstrap file!\n";
			$HEADERS->push_header( 'Content-Type' => 'text/javascript' );
	
			my ($memd) = &ZOOVY::getMemd($SITE->username());
			delete $DNSINFO->{'DKIM_PRIVKEY'};
			my $zGlobals = $JSAPI->configJS('*SITE'=>$SITE);

        my $DEBUG = ''; # .= "/* ".Dumper($SITE)." */ ";

			if ((not defined $BODY) || ($BODY eq '')) {
			   $BODY .= $DEBUG;
				$BODY .= "// config file - this should whitelist this url for future requests.\n";
				$BODY .= "// uwsgi generated: ".&ZTOOLKIT::pretty_date(time(),1)." on host ".&ZOOVY::servername()."\n";
				$BODY .= "\n";

				$BODY .= 'var zGlobals = '.JSON::XS->new()->pretty(1)->encode($zGlobals).";\n";
				$BODY .= "// server: ".&ZOOVY::servername()."\n";
				$BODY .= "\n//eof\n";
	
				if (defined $memd) {
					$memd->set(sprintf("%s.%s.%s",$SITE->username(),$DNSINFO->{'DOMAIN'},"config-js"),$BODY);
					}
				}
			$HTTP_RESPONSE = 200;
			}
		}
	elsif ($path =~ /jsonapi\/upload/) {
		## FILE UPLOAD
		print STDERR "LEGACY FILE UPLOAD CODE STARTED\n";
		print STDERR 'HEADERS ;'.Dumper($req->headers());

		require PLUGIN::FILEUPLOAD;
		require DOMAIN::TOOLS;
		our ($USERNAME,$DOMAIN);

		print STDERR 'PARAMS: '.Dumper(\$v);

		$HEADERS->push_header('Pragma'=>'no-cache');
		$HEADERS->push_header('Cache-Control'=>'no-store, no-cache, must-revalidate');
		$HEADERS->push_header('Content-Disposition'=>'inline; filename="files.json"');
		## Prevent Internet Explorer from MIME-sniffing the content-type:
		$HEADERS->push_header('X-Content-Type-Options'=>'nosniff');
		## access control headers
		print STDERR sprintf("ORIGIN IS: %s\n",$req->headers()->header('origin'));
		$HEADERS->push_header('Access-Control-Allow-Origin'=>'*');
		#if ($req->headers()->header('origin') eq 'null') {
		#	$HEADERS->push_header('Access-Control-Allow-Origin'=>'*');
		#	}
		#else {
		#	$HEADERS->push_header('Access-Control-Allow-Origin'=>''.$PFU->options('access_control_allow_origin'));
		#	}
		$HEADERS->push_header('Access-Control-Allow-Credentials'=>'false');
		$HEADERS->push_header('Access-Control-Allow-Methods'=>'OPTIONS, POST, GET, PUT');
		$HEADERS->push_header('Access-Control-Allow-Headers'=>'Content-Type, Content-Range, Content-Disposition, Content-Description');
		$HEADERS->push_header('Vary'=>'Accept');
	

		if ($req->method() eq 'OPTIONS') {
			$HTTP_RESPONSE = 200;
			}	
		elsif (defined $v->{'USERNAME'}) {	
			($USERNAME) = $v->{'USERNAME'}; 
			}
		elsif ($DOMAIN ne '') {
		   ($USERNAME) = &DOMAIN::TOOLS::domain_to_userprt($v->{'DOMAIN'});
		   if ($USERNAME eq '') { $USERNAME = undef; }
			}
		elsif (defined $v->{'DOMAIN'}) {
			if (ref($v->{'DOMAIN'}) eq 'ARRAY') {
				$v->{'DOMAIN'} = $v->{'DOMAIN'}->[0];
				}
			($USERNAME) = &DOMAIN::TOOLS::domain_to_userprt($v->{'DOMAIN'});
			if ($USERNAME eq '') { $USERNAME = undef; }
			}

		if ($HTTP_RESPONSE) {
			}
		elsif ($req->method() eq 'OPTIONS') {
			}	
		elsif (not defined $USERNAME) {
			$HEADERS->push_header( 'Content-Type' => 'text/error' );
			$BODY = "cannot upload file - no USERNAME or DOMAIN passed.";
			$HTTP_RESPONSE = 401; 
			}
		else {
			my ($PFU) = PLUGIN::FILEUPLOAD->new($USERNAME);
			if ($req->method() =~ /^(OPTIONS|HEAD|GET)$/) {
				my $options = $PFU->options();
				foreach my $k (keys %{$options}) { $HEADERS->push_header( $k => $options->{$k} ); }
				}
				
			my @FILES = ();
			$PFU->{'@FILES'} = \@FILES;
			
			foreach my $upload ( $req->uploads->get_all('files[]') ) {
				# my ($finfo) = values %{$fh};	## this is specific to CGI::Lite	
	 	      #$upload->size;
            #$upload->path;
            #$upload->content_type;
            #$upload->basename;
				if (! -f $upload->path()) {
					push @FILES, { error=>"FILE ".$upload->path()." DOES NOT EXIST" };
					}
				elsif ($upload->size() == 0) {
					push @FILES, { error=>"FILE IS ZERO BYTES" };
					}
				elsif (($upload->content_type eq 'application/zip') && ($v->{'unzip'})) {
					require Archive::Zip;
					my $zip = Archive::Zip->new();
					$zip->read( $upload->path() );
					# $zip->readFromFileHandle($finfo->fh);		## it'd be nice if Plack just returned an *FH
					my @names = $zip->memberNames();
					foreach my $m (@names) {
						# next unless (($m =~ /.txt$/i) || ($m =~ /.csv/i));
						my $BUFFER = $zip->contents($m);
						my $fileguid = Data::GUID->new()->as_string();
						push @FILES, {
							'zip'=>1,
							'name'=>$m,
							'filename'=>$m,
							'size'=>length($BUFFER),
							'fileguid'=>$fileguid,
							};
						$PFU->store_file($fileguid,$BUFFER);
						}
					}
				else {
					## $finfo is a CGI::Lite::Request::Upload->new;
					my $fileguid = Data::GUID->new()->as_string();
					my $filename = $upload->basename();
					$filename = lc($filename);
					$filename =~ s/[\s]+/_/gs;
					push @FILES, { 
						'zip'=>0,
						'name'=>sprintf($upload->basename),
						'filename'=>sprintf($upload->basename), 
						'size'=>$upload->size, 
						'enctype'=>$upload->content_type,
						'fileguid'=>$fileguid
						};

					## my ($contents) = File::Slurp::slurp( $upload->path(), binmode => ':raw' );
					my $contents = undef;
					my $tmpfilepath = $upload->path();
					## NOTE: had massive issues reading in files, File::Slurp didn't work, IO::File didn't work,
					##			but this did .. how bizarre!
					open F, "<$tmpfilepath"; while (<F>) { $contents .= $_; }; close F;

					# my $fh = new IO::File $upload->path(), "r";		
					# if (defined $fh) { $contents .= <$fh>;  undef $fh; }      # automatically closes the file
					# system("/bin/cp $tmpfile /tmp/file.tmp");
					# print STDERR  sprintf("SIZE: %d",$upload->size()."\n");
					# open F, ">/tmp/file.out"; print F $contents; close F;
					$PFU->store_file($fileguid,$contents);
					unlink($upload->path());
					}
				}

			my $ACCEPT = $req->headers()->header('accept');
			if (&PLUGIN::FILEUPLOAD::isset($ACCEPT) && (index($ACCEPT, 'application/json') >= 0)) {
				$HEADERS->push_header('Content-type'=>'application/json');
				} 
			else {
				$HEADERS->push_header('Content-type'=>'text/plain');
				}	

			if ($req->method() =~ /^(OPTIONS|HEAD|GET)$/) {
				$HTTP_RESPONSE = 200;
				}
			elsif ($req->method() =~ /^(POST)$/) {
				if (scalar(@{$PFU->FILES()})>0) {
					my $ug = new Data::UUID;		
					my $send_finfo = undef;
					my @FILES = ();
					foreach my $finfo (@{$PFU->FILES()}) { push @FILES, $finfo;	}
					$BODY = JSON::XS->new->utf8->allow_blessed(1)->convert_blessed(1)->encode(\@FILES);
					}
				$HTTP_RESPONSE = 200;
				}
			else {
				$HTTP_RESPONSE = 405;
				$BODY = "Method not allowed";
				}
			}
		}

	##
	##
	##

	## everything else is assumed to be an API request
	my $R = undef;
	if (not defined $HTTP_RESPONSE) {
		$JSAPI = JSONAPI->new(); 
		$R = $JSAPI->psgiinit($req,$v);		## R will be set to an error.

		if ($v->{'_callback'}) {
			## jsonp request so parameters passed on get in funky format:
			#			 {
			#				'@cmds' => [],
			#				'@cmds[0][_uuid]' => '1116',
			#				'@cmds[0][status]' => 'requesting',
			#				'_zjsid' => 'EUNNyP9KuE1DX1xitmC94VFHc',
			#				'_cmd' => 'pipeline',
			#				'_uuid' => '1117',
			#				'_callback' => 'bob',
			#				'@cmds[0][_v]' => 'zmvc:201216.20120410143100;browser:mozilla-11.0;OS:WI;',
			#				'@cmds[0][_tag][callback]' => 'translateTemplate',
			#				'_' => '1335282924213',
			#				'@cmds[0][_cmd]' => 'appProfileInfo',
			#				'@cmds[0][profile]' => 'DEFAULT',
			#				'@cmds[0][attempts]' => '0',
			#				'callback' => 'bob',
			#				'@cmds[0][_tag][datapointer]' => 'appProfileInfo|DEFAULT',
			#				'@cmds[0][_tag][parentID]' => 'newID'
			#			 },
			if ($v->{'_json'}) {
				my $jsonpvars = JSON::XS::decode_json($v->{'_json'});
				$v->{'%v'} = $jsonpvars;
				foreach my $k (keys %{$jsonpvars}) {
					$v->{$k} = $jsonpvars->{$k};
					}
				}
			}
    			
		## API REQUEST
		$HEADERS->push_header( 'Expires' => -1 );

		if (not defined $R) {
			($R,my $cmdlines) = $JSAPI->handle($v);
			}

		if ($JSAPI->username() eq 'sporks') {
			use Data::Dumper; open F, ">>/tmp/sporks"; print F Dumper(time(),$v,$R); close F;
			}
				
		my $utf8_encoded_json_text = JSON::XS->new->utf8->allow_blessed(1)->convert_blessed(1)->encode($R);
		## print STDERR "UF8 ENCODED TXT: $utf8_encoded_json_text\n";
		if ($v->{'_callback'}) {
			## jsonp response
			$HEADERS->push_header( 'Content-Type' => 'application/javascript' );
			$BODY = sprintf("%s(%s);\n\r",$v->{'_callback'},$utf8_encoded_json_text);
			open F, ">/dev/shm/jsonp.js";	print F $BODY; 	close F;
			}
		else {
			## json response
			$HEADERS->push_header( 'Content-Type' => 'text/json' );
			$BODY = $utf8_encoded_json_text;
			}
		$HTTP_RESPONSE = 200;
		#if (&ZOOVY::servername() eq 'dev') {
		#	print STDERR 'V: '.Dumper({'RESPONSE'=>$HTTP_RESPONSE,'$R'=>$R});
		#	}
		}

	if (not defined $HTTP_RESPONSE) {
		$HTTP_RESPONSE = 404;
		$BODY = '';
		}
	
	## the 'Content-Length' header below caused one of the most tramautic 24 hours in my life -- ask me about it.
	## change at your own peril. -BH 5/18/13
	if (ref($HEADERS) eq 'HTTP::Headers') {
		$HEADERS->push_header( 'Content-Length' => length($BODY) );
		}

	if (&ZOOVY::servername() eq 'dev') {
		warn "RESPONSE $HTTP_RESPONSE\nBODY:$BODY\n";
		}


	my $res = Plack::Response->new($HTTP_RESPONSE,$HEADERS,$BODY);
	return($res->finalize);
	};



