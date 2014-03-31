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
use POSIX qw (strftime);

use IO::Scalar;
use JavaScript::Minifier;
use CSS::Minifier::XS;
use HTML::TreeBuilder;

use lib "/httpd/modules";
use DOMAIN::QUERY;
use ZOOVY;

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
	my $LOCALROOT = "/local/cache/$USERNAME/$HOSTDOMAIN";
	my $LOCALFILE = sprintf("%s%s",$LOCALROOT,$FILENAME);

	## step1. make sure LOCALROOT EXISTS
	my ($memd) = &ZOOVY::getMemd($USERNAME);

	my %CONFIG = ();
	## platform/www.domain.com.json

	$CONFIG{'cache'} = $CONFIG{'cache'} || 1;
	$CONFIG{'release'} = $CONFIG{'release'} || $ZOOVY::RELEASE;
	$CONFIG{'copyright'} = $CONFIG{'copyright'} || "Do not copy without permission."; 
	$CONFIG{'js.compress'} = $CONFIG{'js.compress'} || 1;
	$CONFIG{'css.compress'} = $CONFIG{'css.compress'} || 1;

	$CONFIG{'html.compress'} = $CONFIG{'html.compress'} || 1;
	$CONFIG{'html.fonts.embed'} = $CONFIG{'html.fonts.embed'} || 1;
	$CONFIG{'html.css.embed'} = $CONFIG{'html.css.embed'} || 1;
	$CONFIG{'html.image.embed'} = $CONFIG{'html.image.embed'} || 1;

	$CONFIG{'file.robots'} = $CONFIG{'file.robots'} || '/robots.txt';
	$CONFIG{'file.rewrites'} = $CONFIG{'file.rewrites'} || '/rewrites.json';
	$CONFIG{'redirect.https'} = $CONFIG{'redirect.https'} || 1;
	$CONFIG{'redirect.root'} = $CONFIG{'redirect.root'} || '/index.html';
	$CONFIG{'redirect.missing'} = $CONFIG{'redirect.missing'} || '/index.html#!missing';
	$CONFIG{'sitemap.syntax'} = $CONFIG{'sitemap.syntax'} || $ZOOVY::RELEASE;
	$CONFIG{'seo.fragments'} = $CONFIG{'seo.fragments'} || 1;
	$CONFIG{'seo.index'} = 'seo.html';

#	$CONFIG{'html.compress'} = 0;
#	$CONFIG{'js.compress'} = 0;
#	$CONFIG{'css.compress'} = 0;

	##
	## SANITY: at this point %CONFIG is initialized.
	##
	
	## did we receive an escape fragment? _escaped_fragment_
	my $ESCAPED_FRAGMENTS = undef;
	if ( $CONFIG{'seo.fragments'} && (defined $req->parameters()->get('_escaped_fragment_')) ) {
		## $ESCAPED_FRAGMENTS = &ZTOOLKIT::parseparams($req->parameters()->get('_escaped_fragment_'));
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select BODY from SEO_PAGES where MID=$MID and DOMAIN=".$udbh->quote($HOSTDOMAIN)." and ESCAPED_FRAGMENT=".$udbh->quote($req->parameters()->get('_escaped_fragment_'));
		print STDERR "$pstmt\n";
		($BODY) = $udbh->selectrow_array($pstmt);
		## open F, ">/tmp/escape"; print F "$pstmt\n"; print F Dumper($ESCAPED_FRAGMENTS,$BODY); close F;
		if ($BODY eq '') { 
			$HTTP_RESPONSE = 200;
			}
		else {
			$HTTP_RESPONSE = 404;
			}
		&DBINFO::db_user_close();
		}
	
	

	## SHORT CIRCUIT
	#if ($HTTP_RESPONSE) {
	#	}
	#elsif ($path eq '/') { 
 	#	$HTTP_RESPONSE = 301;
	#	$HEADERS->push_header('Location'=>$CONFIG{'redirect.root'});
	#	}

	my $USE_CACHE = 1;
	if (not $CONFIG{'cache'}) { $USE_CACHE = 0; }

	if (($USE_CACHE) && (defined $memd)) {
		my $PROJECT_TS = $memd->get("$USERNAME.$PROJECTID");
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
		elsif (($CONFIG{'js.compress'}) && ($FILENAME =~ /\.js$/)) {
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
		elsif (($CONFIG{'html.compress'}) && ($FILENAME =~ /\.html$/)) {
			## NOT AVAILABLE YET
	#		my $tree = HTML::TreeBuilder->new(no_space_compacting=>0,ignore_unknown=>1,store_comments=>0); # empty tree
	#		$tree->parse_content($BODY);
#
#		   my $el = $tree->elementify();
#			optimizeHTML($el,\%CONFIG);
				
			}
		elsif (($CONFIG{'css.compress'}) && ($FILENAME =~ /\.css$/)) {
			## open F, ">/tmp/compress"; print F $BODY; close F;
         eval { $BODY = CSS::Minifier::XS::minify($BODY); };
			if ($@) {
				$BODY = "/* 
CSS::Minifier::XS error: $@
please use http://jigsaw.w3.org/css-validator/validator to correct, or disable css minification. 
*/\n".$BODY;
				}
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
		}

	## print STDERR "HELL! $HTTP_RESPONSE $LOCALFILE\n";

	## step2. make sure we're looking at a recent copy
	my $MEMD = undef;
	if ((defined $HTTP_RESPONSE) && ($HTTP_RESPONSE == 404)) {
		## check for rewrite rules.
		if (-f "$NFSROOT/platform/rewrites.txt") {
			open F, "<$NFSROOT/platform/rewrites.txt";
			my $line = 0;
			my $goto = undef;
			while (<F>) {
				last if ($goto);
				$line++;

				# print "LINE: $_\n";
				$_ =~ s/[\n\r]+//gs;
				my ($verb,$ifmatch,$thengoto) = split(/[\t]/,$_);
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


					# print "STYLE:$style SRC:$src  IFMATCH:$ifmatch\n";
					if ($style eq '=') {
						if ($src eq $ifmatch) { $goto = $thengoto; }
						}
					elsif ($style eq '~') {
						# print "IFMATCH:$ifmatch THEN:$thengoto\n";
						$ifmatch =~ s/"/\\"/g;			# protection from embedded code
						if ($src =~ m/^$ifmatch$/) {
							# print "GOMATCH: 1\n";

							$thengoto =~ s/"/\\"/g;		# embedded code protection
							$thengoto = '"'.$thengoto.'"';
							$src =~ s/^$ifmatch$/$thengoto/ee;
							$goto = $src;
							# print "GOTO: $goto\n";
							}
						}
					}
				else {
					$goto = "/index.html?error=invalid_rewrite_prefix_$verb\_line_$line";
					}
				}
			close F;
				
			if (defined $goto) {
				$HTTP_RESPONSE = 301;
				$HEADERS->push_header('Location'=>$goto);
				}

			}
		}


	if (defined $HTTP_RESPONSE) {
		}
	elsif ($USE_ROOT) {
		($HTTP_RESPONSE,$HEADERS,$BODY) = @{Plack::App::File->new('root'=>$USE_ROOT)->call($env)};
		}
	else {
		## UNKNOWN!
		## ISE?
		$HTTP_RESPONSE = 500;
    	## change at your own peril. -BH 5/18/13
    	$HEADERS->push_header( 'Content-Length' => length($BODY) );
		}
	  
	my $res = Plack::Response->new($HTTP_RESPONSE,$HEADERS,$BODY);
	return($res->finalize);
	}



__DATA__
	
