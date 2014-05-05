#!/usr/bin/perl

use strict;
use lib "/httpd/modules";
use Plack::Request;
use Plack::Response;
use HTTP::Headers;
use WEBAPI;
use DOMAIN::QUERY;

my $app = sub {
	my $env = shift;

	my $HEADERS = HTTP::Headers->new;
	my $req = Plack::Request->new($env);
	my $path = $req->path_info;

	my %HEADERS = ();

	require CFG;
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
		require DOMAIN::QUERY;
		my $URI = $req->uri();
		my ($HOSTDOMAIN) =  $URI->host();
		my ($DNSINFO) = DOMAIN::QUERY::lookup($HOSTDOMAIN,'') || undef;
		my $USERNAME = '';

		my $CHKOUT = undef;
		if (defined $DNSINFO) {
			$USERNAME = $DNSINFO->{'USERNAME'};
			$CHKOUT = $DNSINFO->{'CHKOUT'};
			## usually we won't have CHKOUT set as root level, so we'll go to WWW host to find chkout.
			if ($CHKOUT eq '') { $CHKOUT = $DNSINFO->{'%HOSTS'}->{'WWW'}->{'CHKOUT'}; }
			if ($CHKOUT eq '') { $CHKOUT = $DNSINFO->{'%HOSTS'}->{'APP'}->{'CHKOUT'}; }
			}

		$HEADERS{'Content-Type'} = 'text/xml';
		$BODY .= ("<Response>\n");
		$BODY .= ("<Server>".&ZOOVY::servername()."</Server>\n");
		$BODY .= ("<Username>$USERNAME</Username>\n");
		$BODY .= ("<Time>".(time())."</Time>\n");
		
		my ($CFG) = CFG->new();
		## Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; WOW64; Trident/7.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C)
		if ($CFG->get('zid','insecure')>0) {
			## some versions of IE don't like connecting via SSL/TLS
			$BODY .= ("<SyncURL>http://$HOSTDOMAIN/webapi/sync</SyncURL>");
			}
		elsif ($CHKOUT) {
			$BODY .= ("<SyncURL>https://$CHKOUT/webapi/sync</SyncURL>");
			}
		else {
			$BODY .= ("<SyncURL>https://$HOSTDOMAIN/webapi/sync</SyncURL>");
			}
		$BODY .= ("</Response>\n");
		$HTTP_RESPONSE = 200;
		## open F, ">/tmp/webapi-hello"; use Data::Dumper; print F Dumper($req,$BODY); close F;
		}
	else {
		$HTTP_RESPONSE = 404;
		}

	my @HEADERS = ();
	foreach my $k (keys %HEADERS) {
		push @HEADERS, [ $k, $HEADERS{$k} ];
		}


	$HEADERS{'Content-Length'} = length($BODY);
	my $res = Plack::Response->new($HTTP_RESPONSE,\%HEADERS,$BODY);
	return($res->finalize);	
	}

__DATA__


