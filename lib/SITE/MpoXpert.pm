package SITE::MpoXpert;

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
#	comp_root => '/httpd/mpoxpert-htdocs',
#	data_dir  => '/local/mason/www.mpoxpert.com',
#	error_mode=>$error_mode,
#	);

##
## rewrite rules!
##
sub transHandler {
	my ($r) = shift;

	my $URI = $r->uri();
	my $HOST = $r->hostname();

	## this runs subsequent handlers
	return(Apache2::Const::DECLINED);
	}



##
## 
sub handler {
	my ($r) = @_;

	## Still haven't figured out why this is absolutely necessary.
	#print "Content-type: text/html\n\n";
	# return $ah->handle_request($r);
	#my $return = eval { $ah->handle_request($r) };
	#if ( my $err = $@ ) {
	#	$r->pnotes( error => $err );
	#	$r->filename( $r->document_root . '/includes/error/500.html');
	#	return $ah->handle_request($r);
	# 	}
	return(Apache2::Const::DECLINED);
	}


1;

