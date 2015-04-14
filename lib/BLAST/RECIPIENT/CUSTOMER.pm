package BLAST::RECIPIENT::CUSTOMER;

use lib "/backend/lib";

use strict;
use parent 'BLAST::RECIPIENT';
require BLAST::RECIPIENT::EMAIL;

sub customer { return($_[0]->{'*CUSTOMER'}); }

sub new {
	my ($class, $BLASTER, $CUSTOMER, $METAREF) = @_;

	my $self = {};
	$self->{'%META'} = $METAREF || {};
	$self->{'*BLASTER'} = $BLASTER;
	$self->{'*CUSTOMER'} = $CUSTOMER;
	bless $self, 'BLAST::RECIPIENT::CUSTOMER';

	if (ref($CUSTOMER) eq 'CUSTOMER') {
		$self->{'*CUSTOMER'} = $CUSTOMER;
		}
	elsif ((ref($CUSTOMER) eq '') && (int($CUSTOMER)>0)) {
		$self->{'*CUSTOMER'} = CUSTOMER->new($self->username(),
				PRT=>$BLASTER->prt(),
				CID=>$CUSTOMER);
		}
	else {
		warn "CUSTOMER was not set, could not be identified\n";
		}

	return($self);
	}


sub send {
	my ($self, $msg) = @_;

	my ($C) = $self->customer();

	## make a copy of %CUSTOMER if we don't have one already
	my $METAREF = $self->{'%META'};
	if (not defined $METAREF->{'%CUSTOMER'}) {
		$METAREF->{'%CUSTOMER'} = $C;
		}

	## metaref %CUSTOMER should NOT be a customer object, it should be a JSON version of it.
	if ((defined $METAREF->{'%CUSTOMER'}) && (ref($METAREF->{'%CUSTOMER'}) eq 'CUSTOMER')) {
		$METAREF->{'%CUSTOMER'} = $METAREF->{'%CUSTOMER'}->TO_JSON();
		}

	## currently, we only send to customer via email.
	if (defined $C) {
		my ($method) = BLAST::RECIPIENT::EMAIL->new($self->blaster(),$C->email(), $self->meta());
		$method->send( $msg );
		}
	
	return( );
	}


1;