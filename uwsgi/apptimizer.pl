#!/usr/bin/perl

use strict;
use Plack::Request;
use Plack::Response;
use Plack::App::File;
use HTTP::Headers;
use Coro::AnyEvent;
use Data::Dumper;
use Redis;
use CSS::Minifier::XS;
use AnyEvent::HTTP;
use JavaScript::Minifier;
use AnyEvent::Redis;
use System::Command;
use POSIX qw (strftime);

use IO::Scalar;
use JavaScript::Minifier;
use CSS::Minifier::XS;
use HTML::TreeBuilder;
use MIME::Types;
use HTTP::Tiny;

use lib "/httpd/modules";
use DOMAIN::QUERY;
use ZOOVY;
use APPTIMIZER;

##
##
##
sub slurp {
	my ($file) = @_;
	$/ = undef; open F, "<$file"; my ($BUF) = <F>; close F; $/ = "\n";
	chomp($BUF);
	return($BUF);
	}



##
##

sub locate_file {
	my ($root,$env) = @_;

    my $path = $env->{PATH_INFO} || '';

    if ($path =~ /\0/) { return(undef); }
    my $docroot = $root || ".";

    my @path = split /[\\\/]/, $path;
    if (@path) {
        shift @path if $path[0] eq '';
    } else {
        @path = ('.');
    }

	if (grep $_ eq '..', @path) { return(undef); }

   my($file, @path_info);
	my $try = File::Spec::Unix->catfile($docroot, @path);
  	if (-f $try) { return $try; }
	return(undef);
	}

##
##
##
my $app = sub {
	my $env = shift;

	## determine host type, etc.
	my $HEADERS = HTTP::Headers->new;
	my $req = Plack::Request->new($env);
	my $path = $req->path_info;
	my $HTTP_RESPONSE = undef;
   $HEADERS->push_header( 'X-Powered-By' => 'CommerceRack/v.'.$ZOOVY::RELEASE );

	my $BODY = undef;
	# connect to redis
   #my $redis = AnyEvent::Redis->new(
	#	host => 'unix/', port=>"/var/run/redis.sock"
   #  	encoding => 'utf8',
   #   on_error => sub { warn @_; $error = 1; $w->send; },
   #   on_cleanup => sub { warn "Connection closed: @_"; $error = 1; $w->send; },
   #   );


	## V = 201401
	## RAW => serves files, no special handling
	##	REWRITES => 1/0
	##	COMPRESS = CSS,HTML,JS
	## ESCFRAGS = 
	## SITEMAP = /sitemap.xml 
	## ROBOTS = 
	##


	my $URI = $req->uri();
	my $HOSTDOMAIN = lc($URI->host());
	
	my $HOSTINFO = undef;
	if (defined $HTTP_RESPONSE) {
		}
	else {
		## setup domain.com to redirect to www.domain.com
		my ($redis) = Redis->new( server=>"127.0.0.1:6379", sock=>"/var/run/redis.sock", encoding=>undef );

		my @TRYDOMAINS = ();
		push @TRYDOMAINS, $HOSTDOMAIN;
		if ($HOSTDOMAIN =~ /^.*?\.(.*?)$/) { push @TRYDOMAINS, $HOSTDOMAIN; }	## recurse up one level if necessary
	
		foreach my $DOMAIN (@TRYDOMAINS) {
			my $USERNAME = $redis->hget("domain+$DOMAIN","USERNAME");
			next unless $USERNAME;
			$HOSTINFO = {
	    		'USERNAME'=>$USERNAME,
	      	'PRT'=>$redis->hget(lc("domain+$DOMAIN"),"PRT"),
   	   	'HOSTTYPE'=>$redis->hget(lc("domain+$DOMAIN"),"HOSTTYPE"),
				'PROJECT'=>$redis->hget(lc("domain+$DOMAIN"),'PROJECT')
				};
			}

		## AT THIS POINT $HOSTINFO IS SET, OR WE ERROR OUT
		if (not defined $HOSTINFO) {
			$HTTP_RESPONSE = 410;	# GONE
			$BODY = "$HOSTDOMAIN is not valid.";
			}
		}

	my $USERNAME = $HOSTINFO->{'USERNAME'};
	my $PROJECTID = $HOSTINFO->{'PROJECT'};
	my $FILENAME = $req->path_info();
	if ($FILENAME eq '/') { 
		$FILENAME = $env->{'PATH_INFO'} = '/index.html'; 
		}

	if ($PROJECTID eq '') {
		$BODY = '<html><h1>PROJECTID not set.</h1></html>';
		$HTTP_RESPONSE = 500;
		}

	my $NFSROOT = &ZOOVY::resolve_userpath($USERNAME).'/PROJECTS/'.$PROJECTID;
	my $CACHEROOT = "/local/cache/$USERNAME";
	my $LOCALROOT = "/local/cache/$USERNAME/$HOSTDOMAIN";
	my $LOCALFILE = sprintf("%s%s",$LOCALROOT,$FILENAME);

	## step1. make sure LOCALROOT EXISTS
	my ($memd) = &ZOOVY::getMemd($USERNAME);

	my %CONFIG = ();
	## platform/www.domain.com.json

	if (-f "$CACHEROOT/$HOSTDOMAIN.json") {
		my ($json) = slurp("$LOCALROOT/platform/$HOSTDOMAIN.json");
		if ($json eq '') {
			$CONFIG{'error'} = 'cache file empty';
			}
		else {
			my $ref = JSON::XS->new->ascii->pretty->allow_nonref->relaxed(1)->decode($json);
			%CONFIG = %{$ref};
			}
		}
	else {
		## make a copy of the host.domain.com.json
		if (! -d "$CACHEROOT") { mkdir $LOCALROOT; chown $ZOOVY::EUID,$ZOOVY::EGID; chmod 0777, $LOCALROOT; }
		my ($json) = slurp("$NFSROOT/platform/$HOSTDOMAIN.json");
		if ($json eq '') { $json = JSON::XS->new()->encode( { "_error"=>"platform/$HOSTDOMAIN.json missing" } ); }
		my $ref = {};
		eval { $ref = JSON::XS->new->ascii->pretty->allow_nonref->relaxed(1)->decode($json); };
		if ($@) {
			$CONFIG{'_error'} = sprintf("platform/$HOSTDOMAIN.json: $@"); 
			}
		else {
			%CONFIG = %{$ref};
			}
		$CONFIG{'_projectid'} = $PROJECTID;
		$CONFIG{'_username'} = $USERNAME;

		open F, ">$CACHEROOT/$HOSTDOMAIN.json";
		print F JSON::XS->new()->ascii->pretty->encode( \%CONFIG );
		close F;
		}

	$CONFIG{'cache'} = $CONFIG{'cache'} || 1;
	$CONFIG{'release'} = $CONFIG{'release'} || $ZOOVY::RELEASE;
	$CONFIG{'copyright'} = $CONFIG{'copyright'} || "Do not copy without permission."; 

	$CONFIG{'json#compress'} = $CONFIG{'json#compress'} || 1;
	$CONFIG{'js#compress'} = $CONFIG{'js#compress'} || 1;
	$CONFIG{'css#compress'} = $CONFIG{'css#compress'} || 1;

	$CONFIG{'html#compress'} = $CONFIG{'html#compress'} || 1;
	$CONFIG{'html#fonts#embed'} = $CONFIG{'html#fonts#embed'} || 1;
	$CONFIG{'html#css#embed'} = $CONFIG{'html#css#embed'} || 1;
	$CONFIG{'html#image#embed'} = $CONFIG{'html#image#embed'} || 1;

	$CONFIG{'image#compress'} = $CONFIG{'image#compress'} || 1;

	$CONFIG{'file#robots'} = $CONFIG{'file#robots'} || '/robots.txt';
	$CONFIG{'file#rewrites'} = $CONFIG{'file#rewrites'} || '/platform/rewrites.txt';
	$CONFIG{'redirect#https'} = $CONFIG{'redirect#https'} || 0;
	$CONFIG{'redirect#root'} = $CONFIG{'redirect#root'} || '/index.html';
	$CONFIG{'redirect#missing'} = $CONFIG{'redirect#missing'} || '/index.html#!missing';
	$CONFIG{'sitemap#syntax'} = $CONFIG{'sitemap#syntax'} || $ZOOVY::RELEASE;
	$CONFIG{'seo#fragments'} = $CONFIG{'seo#fragments'} || 1;
	$CONFIG{'seo#index'} = 'seo.html';

#	$CONFIG{'html#compress'} = 0;
#	$CONFIG{'js#compress'} = 0;
#	$CONFIG{'css#compress'} = 0;

	##
	## SANITY: at this point %CONFIG is initialized.
	##
	
	## did we receive an escape fragment? _escaped_fragment_
	my $ESCAPED_FRAGMENTS = undef;
	if ( $CONFIG{'seo#fragments'} && (defined $req->parameters()->get('_escaped_fragment_')) ) {
		## $ESCAPED_FRAGMENTS = &ZTOOLKIT::parseparams($req->parameters()->get('_escaped_fragment_'));
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select unix_timestamp(CREATED_TS),BODY from SEO_PAGES where MID=$MID and DOMAIN=".$udbh->quote($HOSTDOMAIN)." and ESCAPED_FRAGMENT=".$udbh->quote($req->parameters()->get('_escaped_fragment_'));
		print STDERR "$pstmt\n";
		(my $TS,$BODY) = $udbh->selectrow_array($pstmt);
		## open F, ">/tmp/escape"; print F "$pstmt\n"; print F Dumper($ESCAPED_FRAGMENTS,$BODY); close F;
		$HEADERS->push_header('Age',time()-$TS);
		$HEADERS->push_header('Last-Modified',POSIX::strftime("%a, %0d %b %Y %H:%M:%S GMT",gmtime($TS)));	# Last-Modified: Thu, 01 Dec 1994 16:00:00 GMT
		$HEADERS->push_header('Expires',POSIX::strftime("%a, %0d %b %Y %H:%M:%S GMT",gmtime(time()+3600)));	# Last-Modified: Thu, 01 Dec 1994 16:00:00 GMT

		if ($BODY ne '') { 
			$BODY .= "\n<!-- _escaped_fragment_ created: ".&ZTOOLKIT::pretty_date($TS,1)." -->\n";
			$HTTP_RESPONSE = 200;
			}
		else {
			$HTTP_RESPONSE = 404;
			
			$BODY = sprintf("<html>\nInvalid escaped fragment: %s\n",$req->parameters()->get('_escaped_fragment_'));
			my $pstmt = "select ESCAPED_FRAGMENT from SEO_PAGES where MID=$MID and DOMAIN=".$udbh->quote($HOSTDOMAIN)." limit 0,250";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			$BODY .= "<ul>";
			while ( my ($FRAGMENT) = $sth->fetchrow() ) {
				$BODY .= "<li> <a href=\"/?_escaped_fragment_=$FRAGMENT\">$FRAGMENT</a>\n";
				}
			$BODY .= "</ul></html>";
			$sth->finish();
			}
		&DBINFO::db_user_close();
		$HEADERS->push_header('Content-Length',length($BODY));
		$HEADERS->push_header('Content-Type','text/html');
		}
	

	

	## SHORT CIRCUIT
	#if ($HTTP_RESPONSE) {
	#	}
	#elsif ($path eq '/') { 
 	#	$HTTP_RESPONSE = 301;
	#	$HEADERS->push_header('Location'=>$CONFIG{'redirect#root'});
	#	}

	my $USE_CACHE = 1;
	if (not $CONFIG{'cache'}) { $USE_CACHE = 0; }
	if ($req->parameters()->get('seoRequest')) { 
		$USE_CACHE = 0; 
		$CONFIG{'html#compress'} = 0;
		}

	if (defined $HTTP_RESPONSE) {
		## already handled .. probably by _escaped_fragment_
		}
	elsif (($USE_CACHE) && (defined $memd)) {
		my $PROJECT_TS = $memd->get("$USERNAME.$PROJECTID");
		$HEADERS->push_header('Last-Modified',POSIX::strftime("%a, %0d %b %Y %H:%M:%S GMT",gmtime($PROJECT_TS)));	# Last-Modified: Thu, 01 Dec 1994 16:00:00 GMT
		#print STDERR "MEMCACHE - PROJECT_TS: $PROJECT_TS\n";

		if (not defined $PROJECT_TS) {
			## no timestamp in memcache, so we load one, and we set 
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$NFSROOT");
			$PROJECT_TS = $mtime;
			$memd->set("$USERNAME.$PROJECTID",$PROJECT_TS);
			#print STDERR "NFSROOT MTIME: $mtime\n";
			}

		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$LOCALROOT");
		#print STDERR "LOCAL MTIME: $mtime\n";

		if ($ino == 0) {
			## local cache does not exist, so create it.
			if (! -d "/local/cache/$USERNAME") {
				mkdir "/local/cache/$USERNAME";
				chown $ZOOVY::EUID,$ZOOVY::EGID, "/local/cache/$USERNAME";
				chmod 0777, "/local/cache/$USERNAME";
				}
			mkdir "/local/cache/$USERNAME/$HOSTDOMAIN";
			chown $ZOOVY::EUID,$ZOOVY::EGID, "/local/cache/$USERNAME/$HOSTDOMAIN";
			chmod 0777, "/local/cache/$USERNAME/$HOSTDOMAIN";	
			$USE_CACHE = 0;
			}
		elsif ($mtime < $PROJECT_TS) {
			## flush cache by moving, then nuking directory.
			warn "FLUSH CACHE FOR $LOCALROOT\n";
			system("/bin/mv $LOCALROOT $LOCALROOT.$$; /bin/rm -Rf $LOCALROOT.$$");
			system("/local/cache/$USERNAME/$HOSTDOMAIN.json");
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
	my $USE_ROOT = undef;		
	if (defined $HTTP_RESPONSE) {
		}
	elsif (not $CONFIG{'cache'}) {
		## don't locally cache
		$USE_ROOT = $NFSROOT;
		}
	elsif (not $USE_CACHE) {
		## print STDERR "not USE_CACHE\n";
		$USE_ROOT = $NFSROOT;
		}
	elsif (-f "$LOCALFILE") {
		## BEST CASE, LOCAL FILE AND IT EXISTS
		warn "LOCAL FILE (BEST CASE): $LOCALFILE\n";
		$USE_ROOT = $LOCALROOT;
		## open F, "<$LOCALFILE"; $/ = undef; $BODY = <F>; $/ = "\n"; close F;
		}
	elsif (-f "$LOCALFILE.missing") {
		## MISSING CASE, LOCAL DIR EXISTS, with FILE MISSING (point at local file)
		$HTTP_RESPONSE = 404;
		$BODY = '';
		}
	else {
		## WORST CASE: LET'S GET IT FROM THE SERVER
		## print STDERR "COPY '$NFSROOT/$FILENAME' to '$LOCALROOT/$FILENAME'\n";

		## STEP1: create local dirs to hold it.
		my @PARTS = split(/\//,$FILENAME);
		if (scalar(@PARTS)>2) {
			shift @PARTS; # strip leading /
			pop @PARTS; # discard filename
			my $TMPDIR = "$LOCALROOT";
			foreach my $part (@PARTS) {
				my $PATH = "$TMPDIR/$part";
				## print STDERR "PATH:$PATH\n";
				$TMPDIR = "$TMPDIR/$part";	## note: don't put this after the dir is created
				next if (-d "$PATH");
				mkdir "$PATH";
				chmod 0777, "$PATH";
				}
			}

		$CONFIG{'_ROOT'} = $NFSROOT;

		my $BODY = undef;
		if (-f "$NFSROOT/$FILENAME") {
			open Fin, "<$NFSROOT/$FILENAME"; $/ = undef;
			($BODY) = <Fin>;
			close Fin; $/ = "\n";
			}

		if ((not defined $BODY) || ($BODY eq '')) {
			}
		elsif (($CONFIG{'js#compress'}) && ($FILENAME =~ /\.js$/)) {
			if ($FILENAME =~ /-min\.js$/) {
				## already minified.
				}
			else {
				my $COPY = '';
				my $SH = new IO::Scalar \$COPY;
				JavaScript::Minifier::minify(input => $BODY, outfile => $SH, copyright=>$CONFIG{'copyright'});
				$BODY = $COPY;
				}
			}
		elsif (($CONFIG{'json#compress'}) && ($FILENAME =~ /\.json$/)) {
			if ($FILENAME =~ /-min\.js$/) {
				## already minified.
				}
			else {
			#	my $COPY = '';
			#	my $SH = new IO::Scalar \$COPY;
			#	JavaScript::Minifier::minify(input => $BODY, outfile => $SH, copyright=>$CONFIG{'copyright'});
			#	$BODY = $COPY;
				}
			}
		elsif (($CONFIG{'html#compress'}) && ($FILENAME =~ /\.html$/)) {
			## NOT AVAILABLE YET
			my ($BASEDIR) = "$NFSROOT";
			my $tree = HTML::TreeBuilder->new(no_space_compacting=>0,ignore_unknown=>0,store_declarations=>1,store_comments=>0); # empty tree
			$tree->parse_content($BODY);

		   my $el = $tree->elementify();
			&APPTIMIZER::optimizeHTML($BASEDIR,$el,\%CONFIG);
			$BODY = "<!DOCTYPE html>\n".$el->as_HTML();
			}
		elsif (($CONFIG{'css#compress'}) && ($FILENAME =~ /\.css$/)) {
			## open F, ">/tmp/compress"; print F $BODY; close F;
			
         eval { $BODY = CSS::Minifier::XS::minify($BODY); };
			if ($@) {
				$BODY = "/* 
CSS::Minifier::XS error: $@
please use http://jigsaw.w3.org/css-validator/validator to correct, or disable css minification. 
*/\n".$BODY;
				}
			}
		else {
			}


		## 
		if (not defined $BODY) {

			## SHIT!: FILE DOES NOT EXIST
			$HTTP_RESPONSE = 404;
			open F, ">$LOCALFILE.missing";
			print F "$NFSROOT/$FILENAME not found\n";
			close F;
			}
		else {
			## JUST COPY
			open F, ">$LOCALFILE";
			print F $BODY;
			close F;	
			$USE_ROOT = $LOCALROOT;
			}

		if (($CONFIG{'image#compress'}) && ($FILENAME =~ /\.(png|gif|jpg)$/)) {
			my $cmd = System::Command->new( '/usr/local/bin/mogrify', '-strip', "$LOCALFILE" );
			$BODY = slurp("$LOCALFILE");
			}

		}

	$HEADERS->push_header('Expires',POSIX::strftime("%a, %0d %b %Y %H:%M:%S GMT",gmtime(time()+(86400*30))));	# Last-Modified: Thu, 01 Dec 1994 16:00:00 GMT
	## print STDERR "HELL! $HTTP_RESPONSE $LOCALFILE\n";

	## step2. make sure we're looking at a recent copy
	my $MEMD = undef;
	if ((defined $HTTP_RESPONSE) && ($HTTP_RESPONSE == 404)) {
		## check for rewrite rules.
		my $REWRITES_FILE = $CONFIG{'file#rewrites'} || "/platform/rewrites.txt";	## this was act
		$REWRITES_FILE =~ s/[.]+/./gs;	# no .. are allowed
		$REWRITES_FILE =~ s/[\/]+/\//gs;	# no // are allowed

		if (! -f "$REWRITES_FILE") {
			open F, "<$NFSROOT/$REWRITES_FILE";
			my $line = 0;
			my $GOTO = undef;
			my %GOTO_modifiers = ();

			while (<F>) {
				last if ($GOTO);
				$line++;

				# print "LINE: $_\n";
				$_ =~ s/[\n\r]+//gs;
				my ($verb,$ifmatch,$thengoto,$modifiers) = split(/[\t]/,$_);
				print STDERR "LINE:$line [$verb] [$ifmatch] [$thengoto] [$modifiers]\n";

				if ($_ eq '') {
					## ignore blank lines!
					}
				elsif (substr($_,0,1) eq '#') {
					## ignore comments!
					}
				elsif ($verb =~ /^(\~|\=)(uri|url|path|query|queryparam)$/) {
					my ($style,$part) = ($1,$2);
					my $src = undef;
					if ($part eq 'uri') { $src = $URI->as_string(); }
					if ($part eq 'url') { $src = $URI->path_query(); }
					if ($part eq 'path') { $src = $URI->path(); }
					if ($part eq 'query') { $src = $URI->query(); }


					#print STDERR "STYLE:$style SRC:$src  IFMATCH:$ifmatch\n";
					if (substr($thengoto,0,1) eq '=') {
						## 410 
						}
					elsif ($style eq '=') {
						if ($src eq $ifmatch) { $GOTO = $thengoto; }
						}
					elsif ($style eq '~') {
						#print STDERR "IFMATCH:$ifmatch THEN:$thengoto SRC[$src]\n";
						$ifmatch =~ s/"/\\"/g;			# protection from embedded code
						if ($src =~ m/$ifmatch/) {
							#print STDERR "GOMATCH: 1[$1] 2[$2] 3[$3]\n";

							$thengoto =~ s/"/\\"/g;		# embedded code protection
							$thengoto = '"'.$thengoto.'"';
							$src =~ s/$ifmatch/$thengoto/ee;
							$GOTO = $src;
							#print STDERR "GOTO: $GOTO\n";
							}
						}

					if ((defined $GOTO) && ($modifiers ne '')) {
						foreach my $token (split(/,/,$modifiers)) {
							$token =~ s/^[\s]+//gs; $token =~ s/[\s]+$//gs; # strip leading/trailing whitespace
							my ($k,$v) = split(/=/,$modifiers,2);
							$GOTO_modifiers{$k} = $v;
							}

						if (defined $GOTO_modifiers{'set'}) {
							## this is a rewrite, it lets us do something like this:
					
							if ($GOTO_modifiers{'set'} eq 'path') { $URI->path($GOTO); $GOTO = undef; }
							}

						}

					}
				else {
					$GOTO = "/index.html?error=invalid_rewrite_prefix_$verb\_line_$line";
					}
				}
			close F;
				
			if (not defined $GOTO) {
				}
			elsif ($GOTO_modifiers{'http'}==410) {
				$HTTP_RESPONSE = 410;
				}
			elsif ($GOTO_modifiers{'http'}==404) {
				$HTTP_RESPONSE = 404;
				}
			elsif ($GOTO_modifiers{'http'}==302) {
				$HTTP_RESPONSE = 302;
				$HEADERS->push_header('Location'=>$GOTO);
				}
			else {
				$HTTP_RESPONSE = 301;
				$HEADERS->push_header('Location'=>$GOTO);
				}

			}
		}


	if (defined $HTTP_RESPONSE) {
		}
	elsif ($USE_ROOT) {
		($HTTP_RESPONSE,$HEADERS,$BODY) = @{Plack::App::File->new('root'=>$USE_ROOT)->call($env)};
		if (ref($HEADERS) eq 'ARRAY') {
			## Plack::App::File returns a hash of headers, lets make it into an object
			$HEADERS = HTTP::Headers->new(@{$HEADERS});
			}
		}
	else {
		## UNKNOWN!
		## ISE?
		$HTTP_RESPONSE = 500;
    	## change at your own peril. -BH 5/18/13
    	$HEADERS->push_header( 'Content-Length' => length($BODY) );
		}

	if ($HTTP_RESPONSE == 200) {
		if ($HEADERS->header('Expires') eq '') {
			$HEADERS->push_header('Expires',POSIX::strftime("%a, %0d %b %Y %H:%M:%S GMT",gmtime(time()+(86400*30))));	# Last-Modified: Thu, 01 Dec 1994 16:00:00 GMT
			}
		if ($HEADERS->header('Cache-Control')) {
			$HEADERS->push_header('Cache-Control','max-age');
			}
		}


	my $res = Plack::Response->new($HTTP_RESPONSE,$HEADERS,$BODY);
	return($res->finalize);
	}



__DATA__
	
