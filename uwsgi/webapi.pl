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
		$BODY .= ("<SyncURL>https://$HOSTDOMAIN/webapi/sync</SyncURL>");
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


##
## this thing should BLOW through /webapi/* requests.
##	/webapi
##		/sync.cgi
##
sub webapiResponseHandler {
	my ($r) = shift;

	if ($r->pnotes("HANDLER") ne 'WEBAPI') {
		return(Apache2::Const::DECLINED);
		}

	require WEBAPI;
	use lib "/httpd/modules";
	my $SITE = $r->pnotes("*SITE");
	if ($SITE->uri() =~ /\/webapi\/sync$/) {
		return(WEBAPI::handle_sync($r));
		}
	elsif ($SITE->uri() =~ /\/webapi\/banners$/) {
		return(WEBAPI::handle_banners($r));
		}
	elsif ($SITE->uri() =~ /\/webapi\/pogwizard$/) {
		return(WEBAPI::handle_pogwizard($r));
		}
	elsif ($SITE->uri() =~ /\/webapi\/check$/) {
		return(WEBAPI::handle_check($r));
		}
	elsif ($SITE->uri() =~ /\/webapi\/hello$/) {
		$r->content_type('text/xml');
		$r->print("<Response>\n");
		$r->print("<Server>".&ZOOVY::servername()."</Server>\n");
		$r->print("<Time>".(time())."</Time>\n");
		$r->print("<SyncURL>https://".$SITE->secure_domain()."/webapi/sync</SyncURL>");
		$r->print("</Response>\n");
		return(Apache2::Const::OK);
		}

	return(Apache2::Const::HTTP_NOT_FOUND);
	}

