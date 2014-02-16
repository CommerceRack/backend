package SITE::AnyCommerce;

use strict;
use HTTP::Date qw();
use Apache2::URI;	# required for $r->parsed_uri 
use lib "/backend/lib";
require ZOOVY;


my $error_mode = 'fatal';
if (&ZOOVY::servername eq 'newdev') { $error_mode = 'output'; }

#my $ah = HTML::Mason::ApacheHandler->new( 
#	auto_send_headers=>1,
#	enable_autoflush=>1,
#	comp_root => '/httpd/any-htdocs',
#	data_dir  => '/local/mason/www.anycommerce.com',
#	error_mode=>$error_mode,
#	);

##
## rewrite rules!
##
sub transHandler {
	my ($r) = shift;

	my $URI = $r->uri();
	my $HOST = $r->hostname();

	# print STDERR "HTTP_ORIGIN: $ENV{'HTTP_ORIGIN'}\n";
	my %REWRITES = ();
	if (lc(substr($URI,-1) eq '/')) { $URI = substr($URI,0,-1); }
	if (lc(substr($URI,-11)) eq '/index.html') { $URI = substr($URI,0,-11); }


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
#	elsif ($r->get_server_port()!=443) {
	elsif (($r->headers_in()->get('X-SSL-Session-Id') eq '') && ($r->get_server_port()!=443)) {
		## not secure - make them secure!
		$r->content_type('text/html');
		$r->headers_out->add(Location => sprintf("https://www.anycommerce.com%s",$r->uri()));		
		return(Apache2::Const::REDIRECT);		
		}
	elsif ($r->hostname() eq 'anycommerce.com') {
		## no www. redirect
		$r->content_type('text/html');
		$r->headers_out->add(Location => sprintf("https://www.anycommerce.com%s",$r->uri()));		
		return(Apache2::Const::REDIRECT);		
		}
	elsif ($URI eq '/signup') {
		$r->headers_out->add(Location => "https://www.anycommerce.com/app/latest/admin.html?show=acreate");		
		return(Apache2::Const::REDIRECT);				
		}
	elsif ($URI eq '') {
		# $r->sendfile("/httpd/htdocs/index.html");
		return(Apache2::Const::DECLINED);
		}
	elsif ($URI =~ /\.(css|js|png|jpg|gif|ico|pdf)$/o) {
		return(Apache2::Const::DECLINED);
		}
	elsif (defined $REWRITES{$URI}) {
		$r->content_type('text/html');
		$r->headers_out->add(Location => $REWRITES{$URI});		
		return(Apache2::Const::REDIRECT);
		}
	elsif ($URI =~ /^\/(webapi|biz|app|Animations)\//o) {
		## we don't want to cache under /biz
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
	#elsif ($r->hostname() eq 'www.anycommerce.com') {
	#	## we don't actually serve this, but this is where the site would be. -- we might intercept this later 
	#	return(Apache2::Const::DECLINED);
	#	}

	#if ($r->uri() =~ '/signup') {
	#	$r->headers_out->add(Location => "https://www.anycommerce.com/app/latest/admin.html?show=acreate");		
	#	return(Apache2::Const::REDIRECT);				
	#	}

	## this runs subsequent handlers
	return(Apache2::Const::DECLINED);
	}

##
## 
#sub handler {
#	my ($r) = @_;
#
#	## Still haven't figured out why this is absolutely necessary.
##	print "Content-type: text/html\n\n";
#
##	# return $ah->handle_request($r);
##	my $return = eval { $ah->handle_request($r) };
##	if ( my $err = $@ ) {
##		$r->pnotes( error => $err );
##		$r->filename( $r->document_root . '/includes/error/500.html');
##		return $ah->handle_request($r);
##	 	}
##	return($return);
#	}


sub responseHandler {
	my ($r) = @_;


	return(Apache2::Const::DECLINED);	
	}


1;
