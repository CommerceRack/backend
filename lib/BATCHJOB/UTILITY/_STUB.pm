package BATCHJOB::UTILITY::_STUB;

use strict;
use lib "/backend/lib";

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	my $USERNAME = $bj->username();
	my $MID = $bj->mid();
	my $PRT = $bj->prt();

	$bj->progress(0,0,"Getting list of something.");

	my @RECORDS = ();
	my $reccount = 0;
	my $rectotal = scalar(@RECORDS);

	foreach my $prod (@RECORDS) {
		if ((++$reccount % 100)==1) {
			$bj->progress($reccount,$rectotal,"Did something");
			}
	   }
	$bj->progress($rectotal,$rectotal,"Finished doing something");

	return(undef);
	}

1;
