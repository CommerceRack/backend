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

use lib "/backend/lib";
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



sub cache_get {
	my ($USERNAME,$CONFIG) = @_;

	my $ROOT = $CONFIG->{'$NFS_ROOT'};
	if ($CONFIG->{'cache'}) {
		$ROOT = $CONFIG->{'$CACHE_ROOT'};
		}

	}

sub cache_set {
	my ($USERNAME,$CONFIG,$BODY) = @_;
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

	my $RESULT = undef;
	my $APP = APPTIMIZER->new($req->uri());
	$APP->HEADERS($HEADERS);
	
	my $USERNAME = $APP->username();
	my $PROJECTID = $APP->projectid();

	if ((not defined $RESULT) && ($PROJECTID eq '')) {
		$RESULT = [ 'ERROR', '500', { body=>'<html><h1>PROJECTID not set.</h1></html>' } ];
		}

	##
	## SANITY: at this point %CONFIG is initialized.
	##	
	if (defined $RESULT) {
		}
	elsif ($APP->release() >= 201410) {
		$RESULT = $APP->rewrites();
		}

	## 
	if (defined $RESULT) {
		}
	elsif ($APP->file_exists( $APP->URI()->path() )) {
		$RESULT = [ 'SENDFILE', $APP->URI()->path() ];
		}
	elsif (($APP->release() < 201410) && ($RESULT = $APP->rewrites_pre_201410)) {
		}
	elsif (not defined $RESULT) {
		$RESULT = [ 'MISSING', '404' ];
		}



	##
	## SANITY: at this point $RESULT should be set!
	##

	#my $USE_CACHE = 1;
	#if (not $CONFIG{'cache'}) { $USE_CACHE = 0; }
	#if ($req->headers()->header('X-WWW-Robot')) {
	#	print STDERR "******************* WELCOME MR. ROBOTO **********************\n";
	#	$USE_CACHE = 0;
	#	}
	#if ($req->parameters()->get('seoRequest')) { 
	#	$USE_CACHE = 0; 
	#	$CONFIG{'html#compress'} = 0;
	#	}

	##
	##
	##	

	my $BODY = undef;

	if ($RESULT->[0] eq 'MISSING') {
		## try a separate rewrites of just 404 to see if we can get a different result, 
		## or will send a different http code
		}


	if ($RESULT->[0] eq 'SENDFILE') {
		print STDERR sprintf("SENDFILE - file:%s/%s\n",$APP->root(),$RESULT->[1]);
		# ($HTTP_RESPONSE,$HEADERS,$BODY) = @{Plack::App::File->new('root'=>$APP->root(), 'file'=>$RESULT->[1])->call($env)}; 
		($HTTP_RESPONSE,$HEADERS,$BODY) = @{Plack::App::File->new('file'=>sprintf("%s/%s",$APP->root(),$RESULT->[1]))->call($env)}; 
		## print STDERR "BODY:$BODY $HTTP_RESPONSE\n";
		if (ref($HEADERS) eq 'ARRAY') {
			## Plack::App::File returns a hash of headers, lets make it into an object
			$HEADERS = HTTP::Headers->new(@{$HEADERS});
			}
		}
	elsif ($RESULT->[0] eq 'SUCCESS') {
		## serve a file from { 'body'=>$BODY }
		$HTTP_RESPONSE = $RESULT->[1];
		if ((ref($RESULT->[2]) eq 'HASH') && ($RESULT->[2]->{'body'})) { $BODY = $RESULT->[2]->{'body'}; }
		}
	elsif ($RESULT->[0] eq 'REDIRECT') {
		$HTTP_RESPONSE = 301;
		if ((ref($RESULT->[2]) eq 'HASH') && ($RESULT->[2]->{'code'})) { $HTTP_RESPONSE = $RESULT->[2]->{'code'}; }
		$HEADERS->push_header('Location'=>$RESULT->[1]);
		}
	elsif ($RESULT->[0] eq 'MISSING') {
		$HTTP_RESPONSE = $RESULT->[1];
		# $HEADERS->push_header('Location'=>$RESULT->[1]);
		}
	elsif ($RESULT->[0] eq 'ERROR') {			
		## this is handled next.
		$HTTP_RESPONSE = $RESULT->[1];
		}
	else {
		## UNKNOWN!
		## ISE?
		$RESULT = [ 'ERROR', 500, { body=>sprintf("<h1>Unknown internal error -- unknown ACTION:$RESULT->[0] -- ".Dumper($RESULT)."</h1>") } ];
		}

	## SANITY: last ditch error handler!
	if ($RESULT->[0] eq 'ERROR') {
		$HTTP_RESPONSE = $RESULT->[1];
		if ((ref($RESULT->[2]) eq 'HASH') && (defined $RESULT->[2]->{'body'})) {
			$BODY = $RESULT->[2]->{'body'}
			}
		else {
			$BODY = sprintf("<h1>Unknown internal error -- ".Dumper($RESULT)."</h1>")
			}
		}

	if ($HTTP_RESPONSE == 200) {
		if ($HEADERS->header('Expires') eq '') {
			$HEADERS->push_header('Expires',POSIX::strftime("%a, %0d %b %Y %H:%M:%S GMT",gmtime(time()+(86400*30))));	# Last-Modified: Thu, 01 Dec 1994 16:00:00 GMT
			}
		if ($HEADERS->header('Cache-Control')) {
			$HEADERS->push_header('Cache-Control','max-age');
			}
		}

	## remove the line below at your own peril
	if (ref($BODY) eq '') {
	  	$HEADERS->push_header( 'Content-Length' => length($BODY) );
		}

   $HEADERS->push_header( 'X-Powered-By' => 'CommerceRack/v.'.$ZOOVY::RELEASE );
	$HEADERS->push_header( 'X-Prerender-Token' => 'BqtsGFeoHsdFyLad8VhS');

	my $res = Plack::Response->new($HTTP_RESPONSE,$HEADERS,$BODY);
	return($res->finalize);
	}



__DATA__
	
