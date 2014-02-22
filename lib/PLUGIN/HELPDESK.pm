package PLUGIN::HELPDESK;

use strict;

use Data::GUID;
use lib "/backend/lib";
use JSON::XS;
use Crypt::OpenSSL::RSA;
use Data::Dumper;
use Digest::SHA1;

require CFG;
require JSONAPI;
require LISTING::MSGS;
require ZTOOLKIT::SECUREKEY;

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(ZMQ_REQ ZMQ_DONTWAIT ZMQ_RCVTIMEO ZMQ_SNDTIMEO ZMQ_NOBLOCK ZMQ_LINGER);



sub test {
	my $VAR1 = 'tcp://admin.zoovy.com:5555';
	my %CMD = (
            'disposition' => 'open',
            '_security' => 'SECRET_GOES_HERE',
            '_cartid' => undef,
            '_prt' => '0',
            '_cmd' => 'adminTicketList',
            '_domain' => 'domain.com',
            '_is_pipelined' => 1,
            '_v' => 201401,
            '_admin' => undef,
            '_tag' => undef,
            'limit' => '50',
            '_user' => 'sporks'
          );

	my ($PUBLIC_KEY) = ZTOOLKIT::SECUREKEY::rsa_key($CMD{'_user'},"commercerack.com.pub");
	my $rsa = Crypt::OpenSSL::RSA->new_public_key($PUBLIC_KEY);
	my %ECMD = ();
	my $json = JSON::XS::encode_json(\%CMD);
	$ECMD{'_user'} = $CMD{'_user'};
	$ECMD{'_cmd'} = 'encrypted-json-payload';
	$ECMD{'_payload'} = MIME::Base64::encode_base64($rsa->encrypt($json));

	print Dumper(send_cmds($VAR1,[ \%ECMD ]));
	}


##
##
##
sub send_cmds {
	my ($SERVER,$CMDS) = @_;

	## open F, ">/tmp/helpdesk"; print F Dumper($SERVER,$CMDS); close F;

	my $context = ZMQ::LibZMQ3::zmq_init();
	if (! $context) { die "zmq_init() failed with $!"; }

	# $LM->pooshmsg("INFO|+Connecting to server: $SERVER");
	## print STDERR "CONNECT\n";
	my $socket = ZMQ::LibZMQ3::zmq_socket($context, ZMQ_REQ);

	ZMQ::LibZMQ3::zmq_connect($socket, $SERVER);
	ZMQ::LibZMQ3::zmq_setsockopt($socket, ZMQ_RCVTIMEO, 2500);
	ZMQ::LibZMQ3::zmq_setsockopt($socket, ZMQ_SNDTIMEO, 2500);
	ZMQ::LibZMQ3::zmq_setsockopt($socket, ZMQ_LINGER, 1000);
	## print STDERR "TEST2\n";

	my @RESPONSE = ();
	for my $CMD (@{$CMDS}) {
		print STDERR Dumper($CMD)."\n";
		my $RESULT = undef;
		my $msgstatus = ZMQ::LibZMQ3::zmq_sendmsg($socket, JSON::XS::encode_json($CMD));
		my $reply = ZMQ::LibZMQ3::zmq_recvmsg($socket);	## DON'T USE ZMQ_DONTWAIT
		
		if (not $reply) {
			&JSONAPI::set_error($RESULT = {},'apierr',7311,sprintf("Transmission Failure to %s",$SERVER));
			}
		else {
			my ($json) = ZMQ::LibZMQ3::zmq_msg_data($reply);
			eval { $RESULT  = JSON::XS::decode_json($json) };
			if ($@) { 
				$RESULT = JSONAPI::set_error($RESULT = {},'apierr',7312,sprintf('Invalid JSON in response'));
				$RESULT->{'_debug'} = $json;
				}			
			}
		push @RESPONSE, $RESULT;
		}

	ZMQ::LibZMQ3::zmq_close($socket);
	ZMQ::LibZMQ3::zmq_term($context);
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
	my $rsa = Crypt::OpenSSL::RSA->new_public_key($PUBLIC_KEY);
	my %ECMD = ();
	my $json = JSON::XS::encode_json(\%CMD);
	$ECMD{'_user'} = $CMD{'_user'};
	$ECMD{'_cmd'} = 'encrypted-json-payload';
	$ECMD{'_payload'} = MIME::Base64::encode_base64($rsa->encrypt($json));

	my $R = undef;
	my @RESPONSES = @{&PLUGIN::HELPDESK::send_cmds( 'tcp://admin.zoovy.com:5555', [ \%ECMD ])};

	if (scalar(@RESPONSES)==0) {
		$R = &JSONAPI::set_error({},'apierr','7300','No response from API');
		}
	else {
		$R = $RESPONSES[0];
		}
	
	return($R);
	}



1;