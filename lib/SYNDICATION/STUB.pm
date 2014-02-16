package SYNDICATION::OVERSTOCK;

use lib "/backend/lib";
require SITE; 
use strict;



sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;

	## we don't need to do anything since nextag will load our private file we generate
	$so->set('null');

	bless $self, 'SYNDICATION::OVERSTOCK';  
	return($self);
	}


##
##
##
sub header_products {
	my ($self) = @_;
	return("");
	}

sub so { return($_[0]->{'_SO'}); }
  

##
##
##
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my $USERNAME = $self->so()->{'USERNAME'};

	return();
	}

##
##
##  
sub footer_products {
  my ($self) = @_;
  return("");
  }



1;