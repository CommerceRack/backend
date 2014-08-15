package PLUGIN::HELPDESK;

use strict;

use Data::GUID;
use lib "/backend/lib";
use JSON::XS;
use Crypt::OpenSSL::RSA;
use HTTP::Tiny;
use Data::Dumper;
use Digest::SHA1;

require CFG;
require JSONAPI;
require LISTING::MSGS;
require ZTOOLKIT::SECUREKEY;

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(ZMQ_REQ ZMQ_DONTWAIT ZMQ_RCVTIMEO ZMQ_SNDTIMEO ZMQ_NOBLOCK ZMQ_LINGER);



#
# TO TEST:
# perl -e 'use lib "/httpd/modules"; use JSONAPI; my ($JSAPI) = JSONAPI->new(); $JSAPI->{"USERNAME"}="sporks"; use PLUGIN::HELPDESK; use Data::Dumper; 
# print Dumper(PLUGIN::HELPDESK::execute($JSAPI,{"_cmd"=>"recentNews"}));'
#

##
##
##
sub send_cmds {
	my ($SERVER,$CMDS) = @_;

	## open F, ">/tmp/helpdesk"; print F Dumper($SERVER,$CMDS); close F;
	my %attributes = ();
	my $http = HTTP::Tiny->new( %attributes );

	my @RESPONSE = ();
	for my $CMD (@{$CMDS}) {

		print STDERR Dumper($CMD)."\n";
		my $RESULT = undef;

		my %options = ( 'content'=>JSON::XS::encode_json($CMD) );
		my $response = $http->request('POST', $SERVER, \%options);

		print Dumper($response)."\n";
		
		if (not $response->{'success'}) {
			&JSONAPI::set_error($RESULT = {},'apierr',7311,sprintf("Transmission Failure to %s",$SERVER));
			}
		else {
			my ($json) = $response->{'content'};
			eval { $RESULT  = JSON::XS::decode_json($json) };
			if ($@) { 
				$RESULT = JSONAPI::set_error($RESULT = {},'apierr',7312,sprintf('Invalid JSON in response'));
				$RESULT->{'_debug'} = $json;
				}			
			}
		push @RESPONSE, $RESULT;
		}

	return(\@RESPONSE);
	}




##
##
##
sub execute {
	my ($jsonapi,$v) = @_;

	my %CMD = ();
	foreach my $k (keys %{$v}) { $CMD{$k} = $v->{$k}; }
	$CMD{'_ts'} = time();		
	$CMD{'_user'} = $jsonapi->username();
	$CMD{'_prt'} = $jsonapi->prt();
	$CMD{'_domain'} = $jsonapi->domain();
	if (not defined $CMD{'_v'}) { $CMD{'_v'} = $jsonapi->apiversion(); }
	## NOTE: these is an issue with RSA encryption (it only supports keylength - padding) so we shouldn't add any unnecessary characters
	## $CMD{'_uuid'} = Data::GUID->new()->as_string();

	my ($PUBLIC_KEY) = ZTOOLKIT::SECUREKEY::rsa_key($CMD{'_user'},"commercerack.com.pub");
	if ($PUBLIC_KEY eq '') {
		$R = &JSONAPI::set_error({},'youerr',7301,'commercerack.com public helpdesk key not installed.');
		}
	else {
		my $rsa_pub = Crypt::OpenSSL::RSA->new_public_key($PUBLIC_KEY);
		$CMD{'_signature'} = MIME::Base64::encode($rsa_pub->encrypt(time()));

		my $R = undef;
		my @RESPONSES = @{&PLUGIN::HELPDESK::send_cmds( 'https://54.219.139.212/jsonapi/', [ \%CMD ])};
	
		if (scalar(@RESPONSES)==0) {
			$R = &JSONAPI::set_error({},'apierr','7300','No response from API');
			}
		else {
			$R = $RESPONSES[0];
			}
		}
	
	return($R);
	}



1;