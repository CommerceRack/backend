package APPTIMIZER;

use lib "/httpd/modules";
use Redis;
use HTML::TreeBuilder;
use HTTP::Tiny;
use IO::Scalar;
use JavaScript::Minifier;
use MIME::Types;
use Data::Dumper;
use MIME::Base64;
use CSS::Minifier::XS;
use CSS::Inliner::Parser;
use URI::URL;
use URI;
use URI::QueryParam;
use HTTP::Headers;
use File::Slurp;

use strict;
require ZOOVY;

##
## checks to see if a file exists (and is servable)
##
sub file_exists {
	my ($self, $FILENAME) = @_;
	my $F = sprintf("%s%s",$self->root(),$FILENAME);
	return (-f $F)?1:0;
	}


sub HEADERS {
	my ($self, $HEADERS) = @_;
	if (defined $HEADERS) {
		$self->{'*HEADERS'} = $HEADERS;
		}
	elsif (not defined $self->{'*HEADERS'}) {
		$self->{'*HEADERS'} = HTTP::Headers->new();
		}
	return($self->{'*HEADERS'});
	}

sub CONFIG {
	my $self = shift;
	return($self->{'%CONFIG'});
	}

sub username { return($_[0]->{'$USERNAME'}); }
sub URI { return($_[0]->{'*URI'}); }
sub release { return($_[0]->CONFIG()->{'release'}); }
sub hostdomain { return($_[0]->{'$hostdomain'}); }
sub projectid { return($_[0]->{'$PROJECTID'}); }
sub root {
	my ($self,$new_root) = @_;
	if (defined $new_root) { $self->{'$ROOT'} = $new_root; }
	if (not defined $self->{'$ROOT'}) {
		$self->{'$ROOT'} = &ZOOVY::resolve_userpath($self->username()).'/PROJECTS/'.$self->projectid();
		}
	return($self->{'$ROOT'});
	}



##
##
##
sub new {
	my ($CLASS, $URI) = @_;

	my $self = {};
	bless $self, $CLASS;

	$self->{'*URI'} = $URI;
	my $RESULT = undef;
	my $hostdomain = $self->{'$hostdomain'} = $URI->host();

	if ($URI->path() eq '/') { $URI->path( '/index.html' ); }

	## setup domain.com to redirect to www.domain.com
	my ($redis) = Redis->new( server=>"127.0.0.1:6379", sock=>"/var/run/redis.sock", encoding=>undef );
	my @TRYDOMAINS = ();
	push @TRYDOMAINS, $hostdomain;
	if ($hostdomain =~ /^.*?\.(.*?)$/) { push @TRYDOMAINS, $hostdomain; }	## recurse up one level if necessary
	
	my $USERNAME = undef;
	foreach my $DOMAIN (@TRYDOMAINS) {
		$USERNAME = $redis->hget("domain+$DOMAIN","USERNAME");
		next unless $USERNAME;
		$self->{'$hostdomain'} = $DOMAIN;
		$self->{'$USERNAME'} = $USERNAME;
		$self->{'$PROJECTID'} = $redis->hget(lc("domain+$DOMAIN"),'PROJECT');
		$self->{'$HOSTTYPE'} = $redis->hget(lc("domain+$DOMAIN"),'HOSTTYPE');
		last;
		#$self->{'$PRT'} = $redis->hget(lc("domain+$DOMAIN"),'HOSTTYPE')
		}
	
	if (not $self->{'$USERNAME'}) {
		return([ 'ERROR', sprintf("Could not resolve DOMAINs: %s to a valid account",join(",",@TRYDOMAINS)) ]);
		}

	if ((not $self->{'$HOSTTYPE'}) || ($self->{'$HOSTTYPE'} ne 'APPTIMIZER')) {
		return([ 'ERROR', sprintf("DOMAIN %s is type %s (not APPTIMIZER)",$self->{'$DOMAIN'},$self->{'$HOSTTYPE'}) ]);
		}
	

			
	## NOW LOAD THE CONFIG.
	my %CONFIG = ();
	$self->{'%CONFIG'} = \%CONFIG;
	my ($memd) = &ZOOVY::getMemd($self->username());
	my $hostdomain_JSON = $memd->get("$hostdomain.json");
	if (defined $hostdomain_JSON) {
		my $ref = {};
		eval { $ref = JSON::XS->new->ascii->pretty->allow_nonref->relaxed(1)->decode($hostdomain_JSON); };
		foreach my $key (%{$ref}) {
			$CONFIG{$key} = $ref->{$key};
			}
		}
	else {
		## make a copy of the host.domain.com.json
		my $NFSROOT = $self->root();

		my $json = undef;
		if (! -f "$NFSROOT/platform/$hostdomain.json" ) {
			$json = JSON::XS->new()->encode( { "_error"=>"platform/$hostdomain.json missing" } ); 
			}
		else {
			$json = File::Slurp::read_file("$NFSROOT/platform/$hostdomain.json");
			}

		if ($json eq '') { 
			$json = JSON::XS->new()->encode( { "_error"=>"platform/$hostdomain.json exists, but is empty" } ); 
			}
		
		my $ref = {};
		eval { $ref = JSON::XS->new->ascii->pretty->allow_nonref->relaxed(1)->decode($json); };
		if ($@) {
			$CONFIG{'_error'} = sprintf("platform/$hostdomain.json: $@"); 
			}
		else {
			%CONFIG = %{$ref};
			}
		$CONFIG{'_projectid'} = $self->projectid();
		$CONFIG{'_username'} = $self->username();

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
		if ($CONFIG{'release'}>=201410) {
			$CONFIG{'file#rewrites'} = $CONFIG{'file#rewrites'} || '/platform/rewrites.json';
			}
		else {
			$CONFIG{'file#rewrites'} = $CONFIG{'file#rewrites'} || '/platform/rewrites.txt';
			}
		$CONFIG{'redirect#https'} = $CONFIG{'redirect#https'} || 0;
		$CONFIG{'redirect#root'} = $CONFIG{'redirect#root'} || '/index.html';
		$CONFIG{'redirect#missing'} = $CONFIG{'redirect#missing'} || '/index.html#!missing';
		$CONFIG{'sitemap#syntax'} = $CONFIG{'sitemap#syntax'} || $ZOOVY::RELEASE;
		$CONFIG{'seo#fragments'} = $CONFIG{'seo#fragments'} || 1;
		$CONFIG{'seo#index'} = 'seo.html';
	
		$CONFIG{'seo#frag_lookup'} = $CONFIG{'seo#frag_lookup'} || 1;
		$CONFIG{'seo#frag_notfound_http'} = $CONFIG{'seo#frag_notfound'} || 404;
		$memd->set("$hostdomain.json", JSON::XS::encode_json(\%CONFIG));
		}

#	$CONFIG{'seo#fragments'} = 0;	## IMPLICITLY TURN THIS OFF
#	$CONFIG{'html#compress'} = 0;
#	$CONFIG{'js#compress'} = 0;
#	$CONFIG{'css#compress'} = 0;

#	my $CACHEROOT = "/local/cache/$USERNAME";
#	my $LOCALROOT = "/local/cache/$USERNAME/$hostdomain";
#	my $LOCALFILE = sprintf("%s%s",$LOCALROOT,$FILENAME);
#	$CONFIG{'$CACHE_ROOT'} = $CACHEROOT;
#	$CONFIG{'$NFS_ROOT'} = $NFSROOT;
#	$CONFIG{'$FILENAME'} = $FILENAME;

	return($self);
	}


##
##
##
sub rewrites {
	my ($self) = @_;

	my $CONFIG = $self->CONFIG();
	my $NFSROOT = $self->root();

	## version 201410 and higher uses rewrites.json
	my $REWRITES_FILE = $CONFIG->{'file#rewrites'};
	$REWRITES_FILE =~ s/[.]+/./gs;	# no .. are allowed in the path
	$REWRITES_FILE =~ s/[\/]+/\//gs;	# no // are allowed in the path

	my $URI = $self->URI();

        print STDERR "$NFSROOT/$REWRITES_FILE\n";
	my $buf = '';
	open F, "<$NFSROOT/$REWRITES_FILE";
	while(<F>) {
	   $_ =~ s/^\/\//##/gs; ## replace leading // with ## (json::xs supports ## comments)
	   $buf .= $_;
	   }
	close F;
	# print STDERR "FILE: $NFSROOT/$REWRITES_FILE\n";

	my $RESULT = undef;

	my $ref = [];
	my $JS = JSON::XS->new->ascii->pretty->allow_nonref()->relaxed(1);
	eval { $ref = $JS->decode($buf); };
	if ($@) {
		$RESULT = [ 'ERROR', sprintf("file#rewrites: %s is corrupt. $@", $REWRITES_FILE) ];
	   print STDERR "$NFSROOT/$REWRITES_FILE ERROR:$@\n";
	   }


	## pre-process rewrite rows.
	my $statement = 0;
	foreach my $row (@{$ref}) {
		$row->{'.row'} = ++$statement;
		foreach my $k (keys %{$row}) { 
			if ($k =~ /^then/) { $row->{'.then.val'} = $row->{$k}; $row->{'.then.key'} = $k; }
			if ($k =~ /^else/) { $row->{'.else.val'} = $row->{$k}; $row->{'.else.key'} = $k };
			}
		}

	# print STDERR "REF: ".Dumper($ref)."\n";

	foreach my $row (@{$ref}) {
		last if ($RESULT);

		##	my ($verb,$ifmatch,$thengoto,$modifiers) = split(/[\t]/,$_);
		my $src = undef;
		if ($row->{'type'} eq 'uri') { $src = $URI->as_string(); }
		if ($row->{'type'} eq 'url') { $src = $URI->path_query(); }
		if ($row->{'type'} eq 'path') { $src = $URI->path(); }
		if ($row->{'type'} eq 'path#rewrite') { $src = $URI->path(); }
		if ($row->{'type'} eq 'query') { $src = $URI->query(); }

		##print STDERR "row#$row->{'.row'} type:$row->{'type'} src:$src\n";

		my $DID_IT_MATCH = 0;
		my $style = '~';
		if ($style eq '~') {
			#print STDERR "IFMATCH:$ifmatch THEN:$then SRC[$src]\n";
			my $ifmatch = $row->{'if'};
			$ifmatch =~ s/"/\\"/g;			# protection from embedded code
			##print STDERR "IFMATCH: $ifmatch\n";
			if ($src =~ m/$ifmatch/) {
				$DID_IT_MATCH++;
				## print STDERR "GOT-MATCH: 1[$1] 2[$2] 3[$3]\n";
				my $then = $row->{'.then.val'};
				$then =~ s/"/\\"/g;		# embedded code protection
				my $rethen = '"'.$then.'"';
				$src =~ s/$ifmatch/$rethen/ee;
				##	The issue is that with a single /e, the RHS is understood to be code whose eval'd result is used for the replacement.
				## What is that RHS? It's $1. If you evaluated $1, you find that contains the string $var. It does not contain the contents of said variable, just $ followed by a v followed by an a followed by an r.
				## Therefore you must evaluate it twice, once to turn $1 into $var, then again to turn the previous result of $var into the string "testing". You do that by having the double ee modifier on the s operator.
				## You can check this pretty easily by running it with one /e versus with two of them. Here's a demo a both, plus a third way that uses symbolic dereferencing which, because it references the package symbol table, works on package variables only.
				$row->{'.then.goto'} = $src;
				}
			}

		if ($DID_IT_MATCH) {
			print STDERR "POST-MATCH#$row->{'.row'} then[$row->{'.then.val'}] thenkey[$row->{'.then.key'}] type[$row->{'type'}] src[$src] GOTO:[$row->{'.then.goto'}] apptimize[$row->{'apptimize'}]\n";
			}
		else {
			print STDERR "FAIL_MATCH#$row->{'.row'} src[$src]==$row->{'if'}\n";
			}

		if (not $DID_IT_MATCH) {
			}
		elsif ($row->{'.then.key'} eq 'then#rewrite') {
			print STDERR "!!!!! REWRITE type:$row->{'type'} src:$src (goto:$row->{'.then.goto'})\n";
			if ($row->{'type'} eq 'path') {
				## rewrite the path, unset $GOTO
				$URI->path($row->{'.then.goto'});
				}
			}
		elsif ($row->{'.then.key'} eq 'then#sendfile') {
			## TODO: need to test to see if a file actually exists.
			if ($self->file_exists( $row->{'.then.goto'} )) {
				$RESULT = [ 'SENDFILE', $row->{'.then.goto'} ];
				}
			else {
				print STDERR "MISSED ON FILE: $row->{'.then.goto'}\n";
				$RESULT = undef;
				}

			#print STDERR "APPTIMZIE: $row->{'apptimize'}\n";
			if ($row->{'apptimize'}) {
				## takes a result and rewrites it.
				$self->apptimize_result_before_sendfile($RESULT);
				}

			}
		elsif ($row->{'.then.key'} eq 'then#redirect') {
			$RESULT = [ 'REDIRECT', $row->{'.then.goto'} ];
			## leave GOTO alone
			#if ((defined $GOTO) && ($modifiers ne '')) {
			#	foreach my $token (split(/,/,$modifiers)) {
			#		$token =~ s/^[\s]+//gs; $token =~ s/[\s]+$//gs; # strip leading/trailing whitespace
			#		my ($k,$v) = split(/=/,$modifiers,2);
			#		$GOTO_modifiers{$k} = $v;
			#		}
			#print STDERR "REDIRECT: $GOTO\n";
			#my %GOTO_modifiers = ();
			#if (not defined $GOTO) {
			#	}
			#elsif ($GOTO_modifiers{'http'}==410) {
			#	$HTTP_RESPONSE = 410;
			#	}
			#elsif ($GOTO_modifiers{'http'}==404) {
			#	$HTTP_RESPONSE = 404;
			#	}
			#elsif ($GOTO_modifiers{'http'}==302) {
			#	$HTTP_RESPONSE = 302;
			#	$HEADERS->push_header('Location'=>$GOTO);
			#	}
			#else {
			#	$HTTP_RESPONSE = 301;
			#	$HEADERS->push_header('Location'=>$GOTO);
			#	}
			}
			## end foreach $row
		}
	## end if release>201410
	return($RESULT);
	}


## only for versions < 201410
sub rewrites_pre_201410 {
	my ($self) = @_;

	my $RESULT = undef;

	## version 201409 and lower use rewrites.txt
	## check for rewrite rules.
	my $CONFIG = $self->CONFIG();
	my $REWRITES_FILE = $CONFIG->{'file#rewrites'} || "/platform/rewrites.txt";	## this was act
	## $REWRITES_FILE = '/platform/rewrites.txt';
	## print STDERR "REWRITES_FILE: $REWRITES_FILE\n";
	$REWRITES_FILE =~ s/[.]+/./gs;	# no .. are allowed
	$REWRITES_FILE =~ s/[\/]+/\//gs;	# no // are allowed
	my $NFSROOT = $self->root();

	my $URI = $self->URI();
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
			elsif ($verb =~ /^(\~|\=)(uri|url|path|query|queryparam|path#rewrite)$/) {
				my ($style,$part) = ($1,$2);
				my $src = undef;
				if ($part eq 'uri') { $src = $URI->as_string(); }
				if ($part eq 'url') { $src = $URI->path_query(); }
				if ($part eq 'path') { $src = $URI->path(); }
				if ($part eq 'path#rewrite') { $src = $URI->path(); }
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

				if ($verb eq 'path#rewrite') {
					## rewrite the path, unset $GOTO
					$URI->path($GOTO); $GOTO = undef;
					}

				if ((defined $GOTO) && ($modifiers ne '')) {
					foreach my $token (split(/,/,$modifiers)) {
						$token =~ s/^[\s]+//gs; $token =~ s/[\s]+$//gs; # strip leading/trailing whitespace
						my ($k,$v) = split(/=/,$modifiers,2);
						$GOTO_modifiers{$k} = $v;
						}

					#if (defined $GOTO_modifiers{'set'}) {
					#	## this is a rewrite, it lets us do something like this:
					#	if ($GOTO_modifiers{'set'} eq 'path') { $URI->path($GOTO); $GOTO = undef; }
					#	}
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
			$RESULT = [ 'MISSING', 410 ];
			#$HTTP_RESPONSE = 410;
			}
		elsif ($GOTO_modifiers{'http'}==404) {
			$RESULT = [ 'MISSING', 404 ]; 
			# $HTTP_RESPONSE = 404;
			}
		elsif ($GOTO_modifiers{'http'}==302) {
			$RESULT = [ 'REDIRECT', $GOTO, { 'code'=>302 } ];
			# $HTTP_RESPONSE = 302;
			# $HEADERS->push_header('Location'=>$GOTO);
			}
		else {
			$RESULT = [ 'REDIRECT', $GOTO, { 'code'=>301 } ];
			#$HTTP_RESPONSE = 301;
			#$HEADERS->push_header('Location'=>$GOTO);
			}

		}
	}


sub escaped_fragments {
	my ($self) = @_;

	my $CONFIG = $self->CONFIG();
	my $URI = $self->URI();
	my $USERNAME = $self->username();
	my $hostdomain = $self->hostdomain();

	## did we receive an escape fragment? _escaped_fragment_
	my $ESCAPED_FRAGMENTS = undef;
	my $RESULT = undef;
	if ( $CONFIG->{'seo#fragments'} && (defined $URI->query_param('_escaped_fragment_')) ) {
		## $ESCAPED_FRAGMENTS = &ZTOOLKIT::parseparams($req->parameters()->get('_escaped_fragment_'));
		my $BODY = undef;
		my $HEADERS = $self->HEADERS();

		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $FRAGMENT = $URI->query_param('_escaped_fragment_');
		use URI::Escape;
		## $FRAGMENT = URI::Escape::uri_escape($FRAGMENT); 
		my $pstmt = "select unix_timestamp(CREATED_TS),BODY from SEO_PAGES where MID=$MID and DOMAIN=".$udbh->quote($hostdomain)." and UNESCAPED_FRAGMENT=".$udbh->quote($FRAGMENT);
		print STDERR "$pstmt\n";
		(my $TS,$BODY) = $udbh->selectrow_array($pstmt);
		## open F, ">/tmp/escape"; print F "$pstmt\n"; print F Dumper($ESCAPED_FRAGMENTS,$BODY); close F;
		$HEADERS->push_header('Age',time()-$TS);
		$HEADERS->push_header('Last-Modified',POSIX::strftime("%a, %0d %b %Y %H:%M:%S GMT",gmtime($TS)));	# Last-Modified: Thu, 01 Dec 1994 16:00:00 GMT
		$HEADERS->push_header('Expires',POSIX::strftime("%a, %0d %b %Y %H:%M:%S GMT",gmtime(time()+3600)));	# Last-Modified: Thu, 01 Dec 1994 16:00:00 GMT

		my $HTTP_RESPONSE = 0;
		my $TRY_URIKEY = '';
		my $TRY_URIVAL = '';
		if ($BODY ne '') { 
			$BODY .= "\n<!-- _escaped_fragment_ created: ".&ZTOOLKIT::pretty_date($TS,1)." -->\n";
			$HTTP_RESPONSE = 200;
			}

		if (($HTTP_RESPONSE==0) && ($CONFIG->{'seo#frag_lookup'})) {
			if ($FRAGMENT =~ /product\/(.*?)\//) {
				$TRY_URIKEY = 'product'; $TRY_URIVAL = $1;
				}
			elsif ($FRAGMENT =~ /product\/([A-Z0-9\-\_]+)$/) {
				$TRY_URIKEY = 'product'; $TRY_URIVAL = $1;
				}
			elsif ($FRAGMENT =~ /category\/(.*?)\//) {
				$TRY_URIKEY = 'category'; $TRY_URIVAL = $1;
				}

			if (($HTTP_RESPONSE == 0) && ($TRY_URIKEY)) {
				$pstmt = "select UNESCAPED_URL from SEO_PAGES_FRAGMENTS where MID=$MID and DOMAIN=".$udbh->quote($hostdomain)." and URIKEY=".$udbh->quote($TRY_URIKEY)." and URIVAL=".$udbh->quote($TRY_URIVAL);
				print STDERR "$pstmt\n";
				my ($REDIRECT) = $udbh->selectrow_array($pstmt);
				if ($REDIRECT) {
					$HTTP_RESPONSE = 301;
					my $GOTO = sprintf("http://$hostdomain#!$REDIRECT");
					$HEADERS->push_header('Location'=>$GOTO);
					}
				}
			}


		if ($HTTP_RESPONSE == 0) {
			$HTTP_RESPONSE = $CONFIG->{'seo#frag_missing'} || 410;
			
			open F, ">>/tmp/missed_fragments";
			print F "$FRAGMENT\n";
			close F;

			$BODY = "<html>Unknown fragment</html>\n";
			#$BODY = sprintf("<html>\nInvalid escaped fragment: %s\n",$FRAGMENT);
			#my $pstmt = "select UNESCAPED_FRAGMENT from SEO_PAGES where MID=$MID and DOMAIN=".$udbh->quote($hostdomain)." limit 0,250";
			#my $sth = $udbh->prepare($pstmt);
			#$sth->execute();
			#$BODY .= "<ul>";
			#while ( my ($UNESCFRAGMENT) = $sth->fetchrow() ) {
			#	my ($URIUNESCFRAG) = URI::Escape::uri_escape($UNESCFRAGMENT);
			#	$BODY .= "<li> <a href=\"/index.html#!$URIUNESCFRAG\">$UNESCFRAGMENT</a>\n";
			#	}
			#$BODY .= "</ul></html>";
			#$sth->finish();
			}
		&DBINFO::db_user_close();
		$HEADERS->push_header('Content-Length',length($BODY));
		$HEADERS->push_header('Content-Type','text/html');

		if ($HTTP_RESPONSE > 0) {
			$RESULT = [ 'SUCCESS', $HTTP_RESPONSE, { body=>$BODY } ];
			}
		}
	return($RESULT);
	}

##
##
##
sub cache_file {
	my ($self,$FILENAME) = @_;

	}



##
##
##
sub apptimize_result_before_sendfile {
	my ($self, $RESULT) = @_;

	return($RESULT);		## uncomment to completely disable apptimizer

	## use alternate expires time.
	my $HEADERS = $self->HEADERS();
	$HEADERS->push_header('Expires',POSIX::strftime("%a, %0d %b %Y %H:%M:%S GMT",gmtime(time()+(86400*30))));	# Last-Modified: Thu, 01 Dec 1994 16:00:00 GMT

	if (ref($RESULT->[2]) ne 'HASH') { $RESULT->[2] = {}; }

	my $CONFIG = $self->CONFIG();
	my $NFSROOT = $self->root();

	my $FILENAME = $RESULT->[1];
	if ($FILENAME eq '') { 
		## not sure why this happens.. but we definitly don't want to try and apptimize it
		return($RESULT);
		}

	my $ORIGIN_FILE = sprintf("%s%s",$self->root(),$FILENAME);
	my $BODY = undef;

	my $CACHEROOT = sprintf("/local/cache/%s/%s",$self->username(),$self->hostdomain());
	my $CACHEFILE = sprintf("%s%s",$CACHEROOT,$FILENAME);
	print STDERR "CACHEFILE :$CACHEFILE\n";
	print STDERR "ORIGINFILE:$ORIGIN_FILE\n";
	if (-f $CACHEFILE) {
		## yay, cached copy exists, use that!
		print STDERR "SHORT CIRCUIT\n";
		$RESULT->[2]->{'root'} = $CACHEROOT;		
		$self->root($CACHEROOT);
		return($RESULT);
		}
	else {
		print STDERR "MISSED: $CACHEFILE\n";
		}

	## step1. read in origin file
	if (-f $ORIGIN_FILE) {
		open Fin, "<$ORIGIN_FILE"; $/ = undef;
		($BODY) = <Fin>;
		close Fin; $/ = "\n";
		}

	## step2. make a cached copy asap
	if (! -d "$CACHEROOT") { mkdir $CACHEROOT; chown $ZOOVY::EUID,$ZOOVY::EGID, $CACHEROOT; chmod 0777, $CACHEROOT; }

	## STEP1: create local dirs to hold it.
	my @PATH_PARTS = split(/\//,$FILENAME);
	pop @PATH_PARTS; 	## discard filename
	shift @PATH_PARTS; # strip leading /


	if (! -d "$CACHEROOT%s",join("/",@PATH_PARTS)) {
		mkdir "$CACHEROOT";
		chmod 0777, $CACHEROOT;

		my $TMPDIR = "$CACHEROOT";
		foreach my $part (@PATH_PARTS) {
			my $PATH = "$TMPDIR/$part";
			$TMPDIR = "$TMPDIR/$part";	## note: don't put this after the dir is created
			## print STDERR "PATH:$PATH\n";
			next if (-d "$PATH");
			mkdir "$PATH";
			chmod 0777, "$PATH";
			}
		}

	## now make a copy in the cache_path
	if (! -f $CACHEFILE) {
		open F, ">$CACHEFILE";
		print F $BODY;
		close F;
		chmod 0667, "$CACHEFILE";
		}
	
	if (1) {
		## only caching!
		$RESULT->[2]->{'root'} = $CACHEROOT;		
		$self->root($CACHEROOT);
		return($RESULT);
		}

	
	if ((not defined $BODY) || ($BODY eq '')) {
		$BODY = undef;
		}
	elsif (($CONFIG->{'js#compress'}) && ($FILENAME =~ /\.js$/)) {
		if ($FILENAME =~ /-min\.js$/) {
			## already minified.
			}
		else {
			my $COPY = '';
			my $SH = new IO::Scalar \$COPY;
			JavaScript::Minifier::minify(input => $BODY, outfile => $SH, copyright=>$CONFIG->{'copyright'});
			$BODY = $COPY;
			}
		}
	elsif (($CONFIG->{'json#compress'}) && ($FILENAME =~ /\.json$/)) {
		if ($FILENAME =~ /-min\.js$/) {
			## already minified.
			}
		else {
		#	my $COPY = '';
		#	my $SH = new IO::Scalar \$COPY;
		#	JavaScript::Minifier::minify(input => $BODY, outfile => $SH, copyright=>$CONFIG->{'copyright'});
		#	$BODY = $COPY;
			}
		}
	elsif (($CONFIG->{'html#compress'}) && ($FILENAME =~ /\.html$/)) {
		## NOT AVAILABLE YET
		my ($BASEDIR) = "$NFSROOT";
		my $tree = HTML::TreeBuilder->new(no_space_compacting=>0,ignore_unknown=>0,store_declarations=>1,store_comments=>0); # empty tree
		$tree->parse_content($BODY);

	   my $el = $tree->elementify();
		$self->optimizeHTML($el);

		$BODY = "<!DOCTYPE html>\n".$el->as_HTML();
		}
	elsif (($CONFIG->{'css#compress'}) && ($FILENAME =~ /\.css$/)) {
		## open F, ">/tmp/compress"; print F $BODY; close F;
			
		eval { $BODY = CSS::Minifier::XS::minify($BODY); };
		if ($@) {
			$BODY = "/* 
CSS::Minifier::XS error: $@
please use http://jigsaw.w3.org/css-validator/validator to correct, or disable css minification. 
*/\n".$BODY;
			}
		}
	elsif (($CONFIG->{'image#compress'}) && ($FILENAME =~ /\.(png|gif|jpg)$/)) {
		my $cmd = System::Command->new( '/usr/local/bin/mogrify', '-strip', "$CACHEFILE" );
		$BODY = slurp("$CACHEFILE");
		}
	else {
		$BODY = undef;
		}

	if (defined $BODY) {
		open F, ">$CACHEFILE";
		print F $BODY;
		close F;
		chmod 0677, "$CACHEFILE";
		}	
	
	return($RESULT);
	}



##
##
##
sub optimizeHTML {
	my ($self, $el) = @_;

	if (my $cmds = $el->attr('data-apptimize')) {
		$cmds =~ s/^[\s]+//gs;
		$cmds =~ s/[\s]+$//gs;

		my $NFSROOT = $self->root();
		my $BODY = undef;
		my %CMDS = ();
		foreach my $cmd (split(/[\s]*;[\s]*/,$cmds)) {
			$CMDS{$cmd}++;
			}

		my $src = $el->attr('src');
		if ($el->tag() eq 'link') { $src = $el->attr('href'); }	## <link rel="stylesheet" type="text/css" href="app-quickstart.css"

		if (($CMDS{'embed'} || $CMDS{'download'}) && ($src =~ /^http[s]?:/)) {
			print STDERR "Downloading $src\n";
			my $response = HTTP::Tiny->new->get($src);
			if ($response->{'success'}) {
				$BODY = $response->{'content'};
				}
			$el->attr('data-debug',sprintf("[remote] tag:%s type:%s",$el->tag(), $el->attr('type')));
			}

		if (($CMDS{'embed'}) && (not defined $BODY) && ($src)) {
			if (($src ne '') && (-f "$NFSROOT/$src"))  {
				open F, "<$NFSROOT/$src"; while(<F>) { $BODY .= $_; } close F;
				}
			$el->attr('data-debug',sprintf("[local] tag:%s type:%s",$el->tag(), $el->attr('type')));
			}
	
		if ($BODY && ($el->tag() eq 'img')) {
			my $src = $el->attr('src');
			$el->attr('data-embedded',"$src");
			my ($mime_type, $encoding) = MIME::Types::by_suffix($src);
			$el->attr('src',sprintf("data:%s;%s,%s",$mime_type, $encoding, MIME::Base64::encode_base64($BODY,'') ) );
			}

		if ($BODY && ($el->tag() eq 'script') && ($el->attr('type') eq 'text/javascript')) {
			## <script>
			if ($src =~ /[\.-]min\.js$/) {
				}
			else {
				print STDERR "Minifiy JS ($src)\n";
				my $COPY = '';
				my $SH = new IO::Scalar \$COPY;
				JavaScript::Minifier::minify(input => $BODY, outfile => $SH, copyright=>$self->CONFIG()->{'copyright'});
				$BODY = $COPY;
				}

			$el->push_content($BODY);	
			$el->attr('src',undef);
			$el->attr('data-embedded',"$src");					
			}

		
		if ($BODY && ($el->tag() eq 'link') && ($el->attr('type') eq 'text/css')) {
			## 
			my $css = CSS::Inliner::Parser->new(); $css->read( {css=>$BODY} );
			foreach my $rule (@{$css->get_rules()}) {
				 foreach my $k (keys %{$rule->{'declarations'}}) {
					if ($rule->{'declarations'}->{$k} =~ /^[Uu][Rr][Ll]\((.*?)\)/) {
						## print STDERR "K:$k\n";
						my $url = $1;
						$url =~ s/^'(.*)'$/$1/gs;	## strip outer ' 
						$url =~ s/^"(.*)"$/$1/gs;	## strip outer ' 
						my $absurl = URI::URL->new($url,$src)->abs();
						print STDERR "--> absurl: $absurl\n";
						if (-f "$NFSROOT/$absurl") {
							my ($DATA) = ''; 
							open F, "<$NFSROOT/$absurl"; while(<F>) { $DATA .= $_; } close F;
							my ($mime_type, $encoding) = MIME::Types::by_suffix($absurl);
							$absurl = sprintf("data:%s;base64,%s",$mime_type,MIME::Base64::encode_base64($DATA,''));
							}
						$rule->{'declarations'}->{$k} =~ s/^[Uu][Rr][Ll]\(.*?\)/url($absurl)/;
						}
					}
				## this will output uncompressed html with embedded url's
				$BODY = $css->write();
				}

#			# open F, ">/tmp/css"; print F Dumper($CSS); close F;
#			if ((not defined $CSS) || (ref($CSS) ne 'CSS::Tiny')) {
#				$el->postinsert("<!-- // style is not valid, could not be interpreted by CSS::Tiny // -->");
#				}
#			else {
#				$sheet = $CSS->html();
#				my $sheetnode = HTML::Element->new('style','type'=>'text/css');
#				$sheetnode->push_content("<!-- \n".$CSS->write_string()."\n -->");
#				$el->replace_with($sheetnode);
#				}
#			}
				

			print STDERR "Minifiy CSS ($src)\n";
			eval { $BODY = CSS::Minifier::XS::minify($BODY); };
			if ($@) {
					$BODY = "/* 
CSS::Minifier::XS error: $@
please use http://jigsaw.w3.org/css-validator/validator to correct, or disable css minification. 
*/\n".$BODY;
				}

			$el->tag('style');
			$el->attr('href',undef);
			$el->push_content($BODY);
			$el->attr('data-embedded',"$src");
			}

		# $el->attr('data-apptimize',undef);
		}

	if (defined $el) {
	   foreach my $elx (@{$el->content_array_ref()}) {
			if (ref($elx) eq '') {
				## just content!
				}
			else {
				$self->optimizeHTML($elx);
	         }
			}
		}
	
	return($el);
	}








1;

__DATA__







__DATA__

##
###
sub debug {
	my ($PATH, $FILE) = @_;

	my %CONFIG = ();

	open F, "<$PATH/$FILE";
	while (<F>) { $BODY .= $_; }
	close F;

	my $tree = HTML::TreeBuilder->new(no_space_compacting=>0,ignore_unknown=>0,store_declarations=>1,store_comments=>0); # empty tree
	$tree->parse_content($BODY);
	my $el = $tree->elementify();
	&APPTIMIZER::optimizeHTML($PATH,$el,\%CONFIG);
	$BODY = $el->as_HTML();
	return($BODY);
	}


1;
