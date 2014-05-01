package PLUGIN::FREEDNS;

use strict;

use lib "/backend/lib";
use Digest::MD5;
require PLUGIN::HELPDESK;
require JSONAPI;


sub register {
	my ($USERNAME) = @_;

	my %v = ();
	$v{'_cmd'} = 'freedns-register';
	$v{'USERNAME'} = $USERNAME;
	$v{'MID'} = &ZOOVY::resolve_mid($USERNAME);

	# my ($PUBLIC_KEY) = ZTOOLKIT::SECUREKEY::rsa_key($CMD{'_user'},"commercerack.com.pub");
	$v{'PASSWORD'} = 'hello';

	my ($JSAPI) = JSONAPI->new();
	$JSAPI->{'USERNAME'} = $USERNAME;
	$JSAPI->{'PRT'} = 0;

	require PLUGIN::HELPDESK;
	my ($R) = PLUGIN::HELPDESK::execute($JSAPI,\%v);
	if (not &JSONAPI::hadError($R)) {
		&JSONAPI::append_msg_to_response($R,'success',0);		
		}
	return($R);
	}

1;