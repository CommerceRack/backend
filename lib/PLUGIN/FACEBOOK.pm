package PLUGIN::FACEBOOK;

use strict;
use Facebook::Graph;

use lib "/backend/lib";


sub new {
	my ($class,$USERNAME,%options) = @_;

	my ($PRT) = int($options{'prt'});
	my $self = {};
	
	$self->{'USERNAME'} = $USERNAME;
	$self->{'PRT'} = $PRT;
	bless $self, 'PLUGIN::FACEBOOK';

	my ($cfg) = &PLUGIN::FACEBOOK::load_config($USERNAME);

	## 0 = disable, 1 = enable, 2 = test mode.
	if (defined $cfg) {
		$self->{'ENABLE'} = int($cfg->{'enable'});
		foreach my $k (keys %{$cfg}) {
			next if ($k eq 'enable');
			$self->{".$k"} = $cfg->{$k};
			}
		}
	
	return($self);
	}

## returns 0=no, 1=yes, 2=test
sub is_live { return($_[0]->{'ENABLE'}); }
sub merchant { return($_[0]->{'.merchant'}); }
sub username { return($_[0]->{'USERNAME'}); }


##
##
##
sub load_config {
	my ($USERNAME,$PRT) = @_;

	my $cfg = undef;
	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME,0);
	if (defined $gref->{'%facebook'}) {
		$cfg = $gref->{'%facebook'};		
		}

	return($cfg);
	}


##
##
##
sub save_config {
	my ($USERNAME,$cfg) = @_;

	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME,0);
	$gref->{'%facebook'} = $cfg;
	&ZWEBSITE::save_globalref($USERNAME,$gref);
	}


sub get_friends {
	my ($self) = @_;

	}

sub get_likes {
	my ($self) = @_;
	
	#$facebook->api_client->fql_query('SELECT user_id FROM like WHERE object_id="122706168308"');
	}





1;