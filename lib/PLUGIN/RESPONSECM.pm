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
	bless $self, 'PLUGIN::RESPONSECM';

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

	my $BODY = '';
	my $VARS = $self->vars();
	my $HTTP_RESPONSE = 200;
	my $ERROR = undef;

	my $VERB = $VARS->{'verb'};
	if ($VARS->{'password'} ne 'fortran1') {
		## we should find a better place to store this password, but this should work for testing.
		$ERROR = "Incorrect password";
		}
	elsif ($VERB eq 'GetOrders') {
		## change parameters here as needed to exclude certain classes of orders.
		my ($orders) = &ORDER::BATCH::report($USERNAME,'NEEDS_SYNC'=>1, LIMIT=>10, DETAIL=>1);
		foreach my $oidref (@{$orders}) {
			my ($O) = CART2->new_from_oid($USERNAME,$oidref->{'ORDERID'});
#			$BODY .= $O->as_xml(201411);
			use ORDER::XCBL; 
			$BODY .= ORDER::XCBL::as_xcbl($O);
			}
		$BODY = "<GetOrdersResponse>\n$BODY\n</GetOrdersResponse>";
		}
	elsif ($VERB eq 'VerifyOrder') {
		my $OID = $VARS->{'order'};
		if (not $OID) {
			$ERROR = "VerifyOrder requires order= parameter";
			}
		elsif (my ($O2) = CART2->new_from_oid($USERNAME,$OID)) {
			$O2->synced();
			## add any code which might move the order, etc.
			$BODY = "<VerifyOrderResponse order=\"$OID\" success=\"true\" />";
			}
		else {
			$ERROR = "order=$OID not found";
			}
		}
	else {
		$ERROR = "Unknown Request: $path verb:$VERB";
		}


	if ($ERROR) {
		$HTTP_RESPONSE = 404;
		$BODY = "<Error><Msg>$ERROR</Msg></Error>";
		}

	return($HTTP_RESPONSE,$HEADERS,$BODY);
	}
1;