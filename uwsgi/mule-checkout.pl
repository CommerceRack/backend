#!/usr/bin/perl

use strict;
use Data::Dumper;
use JSON::XS;

use lib "/httpd/modules";
use DBINFO;
use ZOOVY;

## http://search.cpan.org/CPAN/authors/id/M/MI/MIYAGAWA/Plack-Middleware-ReverseProxy-0.15.tar.gz

my $checkout_process = sub {
	my ($redis) = &ZOOVY::getRedis(undef,0);
	};

my $checkout_init = sub {
	my $json = shift;

	sleep(3);
	my $results = JSON::XS::decode_json($json);	
	my %results = %{$results};
	
	return(JSON::XS::encode_json(\%results));
	};

uwsgi::register_signal(17, '', $checkout_process);
uwsgi::register_rpc('checkout/init',$checkout);
uwsgi::register_rpc('checkout/check',$checkout);


