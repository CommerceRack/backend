package PLUGIN::RESPONSECM;

use utf8 qw();
use Encode qw();
use HTML::Entities qw();

use strict;
use Data::Dumper;
use XML::Writer;
use Date::Parse;
use Date::Format;
use Plack::Builder;
use lib "/backend/lib";
require ORDER::BATCH;
require CART2;
require STUFF2;

sub username { return($_[0]->dnsinfo()->{'USERNAME'}); }
sub prt { return($_[0]->dnsinfo()->{'USERNAME'}); }

sub vars { return($_[0]->{'%VARS'} || {}); }
sub dnsinfo { return($_[0]->{'%DNSINFO'} || {}); }

##
##
##
sub new {
	my ($class, $DNSINFO, $VARSREF) = @_;

	my ($self) = {
		'%DNSINFO'=>$DNSINFO,
		'%VARS'=>$VARSREF,
		};
	bless $self, 'PLUGIN::SHIPSTATION';

	return($self);
	}

##
##
##
sub jsonapi {
	my ($self, $path, $req, $HEADERS, $env) = @_;

	my $VARS = $self->vars();
	my $HTTP_RESPONSE = 200;

	my ($USERNAME) = $self->username();

	my ($SHIPUSER,$SHIPPASS) = ();



	return($HTTP_RESPONSE,$HEADERS,$BODY);
	}
1;