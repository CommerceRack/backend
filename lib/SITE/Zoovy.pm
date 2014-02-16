package SITE::Zoovy;

use strict;
use HTTP::Date;
use Apache2::URI;	# required for $r->parsed_uri 
use lib "/backend/lib";
require ZOOVY;

my $error_mode = 'fatal';
if (&ZOOVY::servername eq 'newdev') { $error_mode = 'output'; }

#my $ah = HTML::Mason::ApacheHandler->new( 
#	auto_send_headers=>1,
#	enable_autoflush=>1,
#	comp_root => '/httpd/htdocs',
#	data_dir  => '/local/mason/www.zoovy.com',
#	error_mode=>$error_mode,
#	);

##
## rewrite rules!
##
sub transHandler {
	my ($r) = shift;

	my $URI = $r->uri();
	my $HOST = $r->hostname();

	if ($HOST eq 'www.webdoc.zoovy.com') { 
		$HOST = 'webdoc.zoovy.com'; 
		}

#	print STDERR "HOST: $HOST\n";
	if ($HOST eq 'www.zoovy.com') {
		## no rewrite here
		#if ($URI =~ /\/webdoc\/[\d]+$/) {
		#	}	
		# print STDERR "HOST:$HOST URI:$URI\n";

		## make /index.html to just /
		if (lc(substr($URI,-11)) eq '/index.html') { $URI = substr($URI,0,-11); }

		## make /amazon/ to /amazon
		if (lc(substr($URI,-1) eq '/')) { $URI = substr($URI,0,-1); }

		# print STDERR "HTTP_ORIGIN: $ENV{'HTTP_ORIGIN'}\n";
		if ($r->method() eq 'OPTIONS')  {
			if ($r->headers_in()->get('Origin') ne 'null') {
				$r->headers_out->set('Access-Control-Allow-Credentials'=>'false'); 
				$r->headers_out->set('Access-Control-Allow-Origin'=>$r->headers_in()->get('Origin')); 
				}
			else {
				## Local client
				# $r->headers_out->set('Access-Control-Allow-Credentials'=>'true'); 
				$r->headers_out->set('Access-Control-Allow-Credentials'=>'false');
				# $r->headers_out->set('Access-Control-Allow-Origin'=>'*'); 
				$r->headers_out->set('Access-Control-Allow-Origin'=>'*'); 
				# $r->headers_out->set('Access-Control-Allow-Origin'=>''); 
				}
			$r->headers_out->set('Access-Control-Max-Age'=>'1000'); 
			$r->headers_out->set('Access-Control-Allow-Methods'=>'POST, GET, OPTIONS'); 
			$r->headers_out->set('Access-Control-Allow-Headers'=>'Content-Type, x-authtoken, x-version, x-clientid, x-deviceid, x-userid, x-domain, x-session'); 
			#$r->headers_out->set('Access-Control-Request-Method'=>'POST'); 
			#$r->headers_out->set('Access-Control-Request-Headers'=>'Content-Type, x-authtoken, x-version, x-clientid, x-deviceid, x-userid, x-domain'); 
			#$r->content_type('text/none');
			# $r->print("{}\n");
			# return(Apache2::Const::DONE);
			## return(Apache2::Const::HTTP_NO_CONTENT);
			return(204);
			}
		elsif ($URI eq '') {
			# $r->sendfile("/httpd/htdocs/index.html");
			return(Apache2::Const::DECLINED);
			}
		elsif ($URI =~ /\.(css|js|png|jpg|gif|ico|pdf)$/o) {
			return(Apache2::Const::DECLINED);
			}
		#elsif (defined $REWRITES{$URI}) {
		#	$r->content_type('text/html');
		#	$r->headers_out->add(Location => $REWRITES{$URI});		
		#	return(Apache2::Const::REDIRECT);
		#	}
		elsif ($URI =~ /^\/(webapi|biz|app|images|Animations)\//o) {
			## we don't want to cache under /biz
			return(Apache2::Const::DECLINED);			
			}
		elsif ($URI =~ /^\/webdoc\//o) {
			## we don't want to cache under /webdoc
			return(Apache2::Const::DECLINED);			
			}
		else {
			#my $SEC_REMAIN = 86400*365;
			#$r->headers_out->set('Expires' => HTTP::Date::time2str(time() + $SEC_REMAIN));
			#$r->headers_out->set('Cache-Control'=>"max-age=".$SEC_REMAIN);
			$r->content_type('text/html');
			$r->headers_out->add(Location => "/index.html#!$URI" );		
			return(Apache2::Const::REDIRECT);
			}
		}
#	elsif (($HOST eq 'gfxapi.zoovy.com') || ($HOST eq 'ebaycheckout.zoovy.com') || ($HOST eq 'ebayapi.zoovy.net')) { 
#		my $ARGS = $r->args();
#		if ($ARGS ne '') { $ARGS = '?'.$ARGS; }
#		$r->content_type('text/html');
#		$r->headers_out->add(Location => "http://www.zoovy.com/webapi/ebay/$URI$ARGS");		
#		return(Apache2::Const::REDIRECT);
#		}
#	elsif ($HOST eq 'track.zoovy.com') {
#		my $ARGS = $r->args();
#		if ($ARGS ne '') { $ARGS = '?'.$ARGS; }
#		$r->content_type('text/html');
#		$r->headers_out->add(Location => "http://www.zoovy.com/webapi/track/$URI$ARGS");		
#		return(Apache2::Const::REDIRECT);
#		}
#	elsif ($HOST eq 'support.zoovy.com') {
#		my $ARGS = $r->args();
#		if ($ARGS ne '') { $ARGS = '?'.$ARGS; }
#		$r->content_type('text/html');
#		$r->headers_out->add(Location => "http://www.zoovy.com/biz/support$URI$ARGS");		
#		return(Apache2::Const::REDIRECT);
#		}
	elsif ($HOST eq 'webdoc.zoovy.com') {
		if ($URI =~ /^\/sitemap$/) { $URI = '?VERB=SITEMAP'; }
		elsif ($URI =~ /^\/search/) { $URI = '?VERB=SEARCH'; }
		elsif ($URI =~ /^\/tag\/(.*?)$/) { $URI = '?VERB=SEARCH&keywords='.$1; }
		elsif ($URI =~ /^\/doc[\/-]([\d]+)/) { $URI = '?VERB=DOC&DOCID='.int($1); } 
		else {
			my $ARGS = $r->args();
      	if ($ARGS ne '') { $URI = "?$ARGS"; }
			}

		$r->content_type('text/html');
		$r->headers_out->add(Location => "http://www.zoovy.com/webdoc$URI");		
		return(Apache2::Const::REDIRECT);
		}

	## this runs subsequent handlers
	return(Apache2::Const::DECLINED);
	}



sub responseHandler {
	my ($r) = @_;


	return(Apache2::Const::DECLINED);	
	}


##
## 
#sub handler {
#	my ($r) = @_;
#
##	die();
#	## Still haven't figured out why this is absolutely necessary.
#	print "Content-type: text/html\n\n";
#
#	# return $ah->handle_request($r);
#	my $return = undef;
#	if ($r->uri() =~ /^\/biz/) {
#		## don't run mason code for /biz
#		return(Apache2::Const::DECLINED);
#		}
#	else {
#		$return = eval { $ah->handle_request($r) };
#		if ( my $err = $@ ) {
#			$r->pnotes( error => $err );
#			$r->filename( $r->document_root . '/includes/error/500.html');
#			return $ah->handle_request($r);
#		 	}
#		}
#	return($return);
#	}

1;
