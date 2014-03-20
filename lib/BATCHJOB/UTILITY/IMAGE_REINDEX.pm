package BATCHJOB::UTILITY::IMAGE_REINDEX;

use strict;
use lib "/backend/lib";
use MEDIA;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	my $USERNAME = $bj->username();
	my $MID = $bj->mid();
	my $PRT = $bj->prt();

	$bj->progress(0,0,"Running image reindex.");

#	use LUSER;
#	LUSER::log($bj->luser(),"SUPPORT.IMAGE_REINDEX","Rebuild image index script");
	require MEDIA;

	&MEDIA::reindex($USERNAME,'',0);

	$bj->progress(1,1,"Finished image library rebuild.");

	return(undef);
	}

1;
