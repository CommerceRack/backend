package BATCHJOB::SLOG;

use strict;
use lib "/backend/lib";
use ZOOVY;

sub username { return($_[0]->{'USERNAME'}); }
sub MEMD { 
	return($_[0]->{'*MEMD'}); 
	}
sub guid { return($_[0]->{'GUID'}); }

sub new {
	my ($CLASS,$USERNAME,$GUID) = @_;
	
	my $self = {};
	$self->{'USERNAME'} = $USERNAME;
	$self->{'GUID'} = $GUID;
	bless $self, 'BATCHJOB::SLOG';

	if (not defined $self->{'*MEMD'}) {
		$self->{'*MEMD'} = &ZOOVY::getMemd($USERNAME);
		if (not defined $self->{'*MEMD'}) {
			warn "MEMD not initialized..\n";
			$self = undef;
			}
		}

	return($self);
	}

##
## adds a message
##
sub restart { $_[0]->MEMD()->set($_[0]->guid(),0); }
sub add {
	my ($self, %options) = @_;

	my $i = $self->MEMD()->incr($self->guid(),1);
	if ($i == 0) { $self->restart(); }
	print STDERR "I:$i\n";
	$self->MEMD()->set(sprintf("%s.%s",$self->guid(),$i), \%options);
	return();
	}

##
## retrieves messages
##
sub get_messages_since {
	my ($self, $i_was) = @_;

	$i_was = int($i_was);
	if ($i_was>0) { $i_was++; } ## this way we don't return the same message twice

	my @MSGS = ();
	my $i_is = int($self->MEMD()->get( $self->guid() ));
	foreach my $i ($i_was .. $i_is) {
		my $ref = $self->MEMD()->get( sprintf("%s.%s",$self->guid(),$i) );
		if (not defined $ref) { $ref = {}; }
		$ref->{'#'} = $i;
		push @MSGS, $ref;
		}

	return(\@MSGS);
	}


1;