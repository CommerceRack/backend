package BATCHJOB::UTILITY::ELASTIC_REBUILD;

use strict;
use lib "/backend/lib";
use ELASTIC;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	my $USERNAME = $bj->username();
	my $MID = $bj->mid();
	my $PRT = $bj->prt();
	my $meta = $bj->meta();

	my ($rectotal) = 0;

	my $index = 'public';
	if ($bj->version() < 201346) {
		}
	else {
		$index = $meta->{'index'};
		}

	use Data::Dumper; print Dumper($meta,$bj,$index,$bj->version());

	$bj->title("Elastic $index Rebuild");
	$bj->progress(0,0,"Starting Search Catalog Generator","NOTE: Each records represents a group of 150 products.");

	if ($index eq 'private') {
		&ELASTIC::rebuild_private_index($USERNAME,'*bj'=>$bj,'NUKE'=>1);	
		&ZOOVY::log($USERNAME,'*BATCH',"ELASTIC.RESET","Reset elastic private",'INFO');
		$bj->progress($rectotal,$rectotal,"Finished Building Elastic Private");
		}
	elsif ($index eq 'public') {
		&ELASTIC::rebuild_product_index($USERNAME,'*bj'=>$bj,'NUKE'=>1);
		&ZOOVY::log($USERNAME,'*BATCH',"ELASTIC.RESET","Reset elastic public",'INFO');
		$bj->progress($rectotal,$rectotal,"Finished Building Elastic Public");
		}
	else {
		$bj->progress($rectotal,$rectotal,"ERROR - no index specified.");
		}


	return(undef);
	}

1;
