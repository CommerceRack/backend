package BLAST::RECIPIENT::CUSTOMER;

use strict;
use parent 'BLAST::RECIPIENT';
require BLAST::RECIPIENT::EMAIL;

sub new {
	my ($class, $BLASTER, $CUSTOMER, $METAREF) = @_;

	my $self = {};
	$self->{'%META'} = $METAREF || {};
	$self->{'*BLASTER'} = $BLASTER;
	bless $self, 'BLAST::RECIPIENT::CUSTOMER';

	if (defined $METAREF->{'%CUSTOMER'}) {
		}
	elsif (ref($CUSTOMER) eq 'CUSTOMER') {
		$self->{'%CUSTOMER'} = $CUSTOMER;
		}
	elsif ((ref($CUSTOMER) eq '') && (int($CUSTOMER)>0)) {
		$self->{'%CUSTOMER'} = CUSTOMER->new($self->username(),
				PRT=>$BLASTER->prt(),
				CID=>$CUSTOMER);
		}

	return($self);
	}


sub send {
	my ($self, $msg) = @_;

	my ($C) = $self->{'%CUSTOMER'};

	## currently, we only send to customer via email.
	my ($method) = BLAST::RECIPIENT::EMAIL->new($self->blaster(),$C->email(), $self->meta());
	$method->send( $msg );
	
	return( );
	}


1;