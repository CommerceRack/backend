package PLUGIN::GITHUB;

use lib "/backend/lib";
use ZTOOLKIT;

use LWP::Simple;

sub authorize {
	my %params = ();

	$params{'client_id'} = $PLUGIN::GITHUB::ClientID;
	$params{'redirect_uri'} = 'http://webapi.zoovy.com/webapi/github.cgi';
	$params{'state'} = 'mystate';

	my $url = sprintf("https://github.com/login/oauth/authorize?%s",&ZTOOLKIT::buildparams(\%params));
	print LWP::Simple::get($url);
	print "URL: $url\n";
	}

1;

__DATA__

callback:
https://www.anycommerce.com/webapi/oauth/github.cgi