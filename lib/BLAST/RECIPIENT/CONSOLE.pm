package BLAST::RECIPIENT::CONSOLE;

use strict;
use parent 'BLAST::RECIPIENT';

require MIME::Lite;

sub email { return(@_[0]->{'CONSOLE'}); }

sub new {
	my ($class, $BLASTER, $CONSOLE, $METAREF) = @_;

	my $self = {};
	$self->{'%META'} = $METAREF || {};
	$self->{'*BLASTER'} = $BLASTER;
	bless $self, 'BLAST::RECIPIENT::CONSOLE';
	return($self);
	}

sub send {
	my ($self, $msg) = @_;

	my $RECIPIENT = $self->email();
	my $BCC = $self->bcc();
	my $BODY = $msg->body();

	print "SUBJECT: ".$msg->subject()."\n";
	print $msg->body()."\n";

	return(1);
	}

1;