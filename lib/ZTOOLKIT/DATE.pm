package ZTOOLKIT::DATE;

use strict;
require Date::Calc;


# these two should always sync up:
#  perl -e 'use Date::Calc; print Date::Calc::Mktime(Date::Calc::Today_and_Now())."\n"; print time()."\n";'

sub relative_gmt {
	my ($txt) = @_;

	## recognizes the following formats
	my $ts = 0;
	$txt = lc($txt);
	
	# perl -e 'use lib "/backend/lib"; use ZTOOLKIT::DATE; use ZTOOLKIT; print &ZTOOLKIT::pretty_date(&ZTOOLKIT::DATE::relative_gmt("today"),1);'
	# perl -e 'use lib "/backend/lib"; use ZTOOLKIT::DATE; use ZTOOLKIT; print ZTOOLKIT::DATE::relative_gmt("yesterday"),1);'
	if (($txt eq 'today') || ($txt eq 'yesterday') || ($txt eq 'tomorrow')) {
		my ($year,$mon,$day) = Date::Calc::Today_and_Now();
		$ts = Date::Calc::Mktime($year,$mon,$day,0,0,0);
		if ($txt eq 'yesterday') { $ts -= 86400; }
		if ($txt eq 'tomorrow') { $ts += 86400; }
		}
	# perl -e 'use lib "/backend/lib"; use ZTOOLKIT::DATE; use ZTOOLKIT; print &ZTOOLKIT::pretty_date(&ZTOOLKIT::DATE::relative_gmt("this.week"),1);'
	elsif ($txt eq 'this.week') {		
		my ($year,$mon,$day) = Date::Calc::Today();
		(my $week,$year) = Date::Calc::Week_of_Year($year,$mon,$day);
		($year,$mon,$day) = Date::Calc::Monday_of_Week($week,$year);
		$ts = Date::Calc::Mktime($year,$mon,$day,0,0,0)
		}
	# perl -e 'use lib "/backend/lib"; use ZTOOLKIT::DATE; use ZTOOLKIT; print &ZTOOLKIT::pretty_date(&ZTOOLKIT::DATE::relative_gmt("this.month"),1);'
	elsif ($txt eq 'this.month') {
		my ($year,$mon,$day) = Date::Calc::Today_and_Now();
		$ts = Date::Calc::Mktime($year,$mon,1,0,0,0);
		}

	return($ts);	
	}


1;