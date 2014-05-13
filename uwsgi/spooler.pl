#!/usr/bin/perl


use strict;

use Net::uwsgi;
use Data::Dumper;
use Fcntl ':flock';
use lib "/httpd/lib";
use JSONAPI;
use ZOOVY;

uwsgi::spooler(
	sub {
		my ($env) = @_;

		#my $file = $env->{'file'};
		## lock the file!

		#unless (flock($file,LOCK_EX|LOCK_NB)) {
		#	print STDERR "$0: Cannot open lock for pid=$$.\n";
		#	return(uwsgi::SPOOL_RETRY);
		#	}
		## print STDERR Dumper($env);

		my $v = JSON::XS::decode_json($env->{'body'});
		if (defined $v->{'*CART2'}) {
			delete $v->{'*CART2'};
			}

		my ($JSAPI) = JSONAPI->new();
		$JSAPI->spoolinit($env);

		my $USERNAME = $JSAPI->username();
		my ($redis) = &ZOOVY::getRedis($USERNAME);

		my $R = undef;
		eval {
			if ($v->{'_cmd'} eq 'cartOrderCreate') {
				$v->{'async'} = 0;
				($R) = $JSAPI->handle($v);
				}
			};
		
		if ($@) {
			($R) = &JSONAPI::set_error($R = {},'iseerr',500,"spooler err: $@");
			}
		elsif (not defined $R) {
			($R) = &JSONAPI::set_error($R = {},'iseerr',501,"spooler err ($R is undefined)");
			}

		my $DEBUG_FILE = "/dev/shm/spooler.debug";
		if (&JSONAPI::hadError($R)) {
			$DEBUG_FILE = sprintf("/dev/shm/spooler.err-%s-%s",$v->{'_cartid'},time());
			print STDERR 'ERROR: '.Dumper($v,$R)."\n";
			}
		open F, ">$DEBUG_FILE";		
		print F 'ENV: '.Dumper($env)."\n\n";
		print F "JSAPI: ".Dumper($JSAPI)."\n\n";
		print F "V: ".Dumper($v)."\n\n";
		print F "R: ".Dumper($R);
		close F;
	
		if (not &JSONAPI::hadError($R)) {
			return uwsgi::SPOOL_OK;		
			}

		return uwsgi::SPOOL_RETRY;
		}
	);
