#!/usr/bin/perl

use strict;
use lib "/httpd/modules";
use Plack::Request;
use Plack::Response;
use HTTP::Headers;
use WEBAPI;

my $app = sub {
	my $env = shift;

	my $HEADERS = HTTP::Headers->new;
	my $req = Plack::Request->new($env);
	my $path = $req->path_info;

	my %HEADERS = ();

	require WEBAPI;
	my ($HTTP_RESPONSE,$BODY) = ();

	if ($path =~ /\/webapi\/sync$/) {
		($HTTP_RESPONSE,$BODY) = WEBAPI::handle_sync($req,\%HEADERS);
		}
	elsif ($path =~ /\/webapi\/banners$/) {
		($HTTP_RESPONSE,$BODY) = WEBAPI::handle_banners($req,\%HEADERS);
		}
	elsif ($path =~ /\/webapi\/pogwizard$/) {
		($HTTP_RESPONSE,$BODY) = WEBAPI::handle_pogwizard($req,\%HEADERS);
		}
	elsif ($path =~ /\/webapi\/check$/) {
		($HTTP_RESPONSE,$BODY) = WEBAPI::handle_check($req,\%HEADERS);
		}
	elsif ($path =~ /\/webapi\/hello$/) {
		my $URI = $req->uri();
		my ($HOSTDOMAIN) =  $URI->host();

		$HEADERS{'Content-Type'} = 'text/xml';
		$BODY .= ("<Response>\n");
		$BODY .= ("<Server>".&ZOOVY::servername()."</Server>\n");
		$BODY .= ("<Time>".(time())."</Time>\n");
		
		my ($CFG) = CFG->new();
		if ($CFG->get('zid.insecure')) {
			## some versions of IE don't like connecting via SSL/TLS
			$BODY .= ("<SyncURL>http://$HOSTDOMAIN/webapi/sync</SyncURL>");
			}
		else {
			$BODY .= ("<SyncURL>https://$HOSTDOMAIN/webapi/sync</SyncURL>");
			}
		$BODY .= ("</Response>\n");
		$HTTP_RESPONSE = 200;
		}

	my @HEADERS = ();
	foreach my $k (keys %HEADERS) {
		push @HEADERS, [ $k, $HEADERS{$k} ];
		}

	## print STDERR "BODY: $BODY\n";

	$HEADERS{'Content-Length'} = length($BODY);
	my $res = Plack::Response->new($HTTP_RESPONSE,\%HEADERS,$BODY);
	return($res->finalize);	
	}

__DATA__


