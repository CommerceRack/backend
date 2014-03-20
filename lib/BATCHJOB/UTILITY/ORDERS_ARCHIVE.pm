package BATCHJOB::UTILITY::ORDERS_ARCHIVE;

use strict;
use lib "/backend/lib";
require ORDER::BATCH;


sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	my $USERNAME = $bj->username();
	my $MID = $bj->mid();
	my $PRT = $bj->prt();
	my $meta = $bj->meta();

	my $YEAR = $meta->{'.year'};

	&ZOOVY::log($USERNAME,'*BATCH',"ORDER.ARCHIVE","Order Archive Requested RANGE=$YEAR",'INFO');
	$bj->progress(0,0,"Starting Order Archival","REGRETFULLY THIS UTILITY IS NOT INTERACTIVE AND WILL NOT UPDATE STATUS UNTIL IT IS FINISHED.");

	require Date::Manip;
	my $TS = 0;

	if ($YEAR eq '2008') {
		$TS=&Date::Manip::Date_SecsSince1970GMT(1,1,2008,0,0,0);
		}
	elsif ($YEAR eq '2007') {
		$TS=&Date::Manip::Date_SecsSince1970GMT(1,1,2007,0,0,0);
		}
	elsif ($YEAR eq '2006') {
		$TS=&Date::Manip::Date_SecsSince1970GMT(1,1,2006,0,0,0);
		}
	elsif ($YEAR eq '2005') {
		$TS=&Date::Manip::Date_SecsSince1970GMT(1,1,2005,0,0,0);
		}
	elsif ($YEAR eq '2004') {
		$TS=&Date::Manip::Date_SecsSince1970GMT(1,1,2004,0,0,0);
		}		
	elsif ($YEAR eq '2003') {
		$TS=&Date::Manip::Date_SecsSince1970GMT(1,1,2003,0,0,0);
		}		
	elsif ($YEAR eq '2002') {
		$TS=&Date::Manip::Date_SecsSince1970GMT(1,1,2002,0,0,0);
		}
	elsif ($YEAR eq '2001') {
		$TS=&Date::Manip::Date_SecsSince1970GMT(1,1,2001,0,0,0);
		}
	elsif ($YEAR eq '*') {
		$TS=time();
		}
	else {	
		$TS = 0;
		}

	my @CHANGETHIS = ();
	my ($tsref,$statusref,$created) = &ORDER::BATCH::list_orders($USERNAME,'COMPLETED',0);
	foreach my $o (keys %{$created}) {		
		print STDERR "$created->{$o} <= $TS\n";
		if ($created->{$o}<=$TS) {
			push @CHANGETHIS, $o;
			}
		}
	
	&ORDER::BATCH::change_pool($USERNAME,'ARCHIVE',\@CHANGETHIS);
	$bj->progress(0,0,"Finished Order Archival",'');

	return(undef);
	}

1;
