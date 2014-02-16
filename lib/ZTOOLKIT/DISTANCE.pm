package ZTOOLKIT::DISTANCE;

#
# a complete library intended to the pursuit of finding out how far away things are.
#

use strict;
use CDB_File;
use GIS::Distance;
use lib "/backend/lib";
require ZSHIP;



sub zip_to_zip {
	my ($zip1,$zip2) = @_;

	my ($xy1,$xy2) = ();

	if ($zip2 eq '00000') {
		$xy2 = "0|0";	# shortcut
		}

	if ($zip1 eq '00000') {
		$xy1 = "0|0";	# shortcut
		}

	if ((defined $xy1) && (defined $xy2)) {
		## no need to tie, we've already got what we came for!
		}
   elsif (tie my %zips, 'CDB_File', '/httpd/static/zip-xy.cdb') {

		if (not defined $xy1) {
			$xy1 = $zips{$zip1};
			}

		if (not defined $xy1) {
			my $state = uc(&ZSHIP::zip_state($zip1));
			if (defined $state) { $xy1 = $zips{"$state"}; }
			}


		if (not defined $xy2) {
			$xy2 = $zips{$zip2};
			}

		if (not defined $xy2) {
			my $state = uc(&ZSHIP::zip_state($zip2));
			if (defined $state) { $xy2 = $zips{"$state"}; }
			}

		## hmm. if $xy1, or $xy2 aren't set, then it's going to be ROUGH
      untie %zips;
      }

	if (not defined $xy1) {
		warn "ZTOOLKIT::DISTANCE::zip_to_zip->zip1: $zip1 is not valid in census data, going to state lookup\n";
		$xy1 = "0.1|0.1";	# north pole?
		}
	if (not defined $xy2) {
		warn "ZTOOLKIT::DISTANCE::zip_to_zip->zip1: $zip2 is not valid in census data, going to state lookup\n";
		$xy2 = "0.1|0.1";	# north pole? 
		}

	my ($lat1,$lon1) = split(/\|/,$xy1);
	my ($lat2,$lon2) = split(/\|/,$xy2);

	#print STDERR "$zip1 XY1: $xy1\n";
	#print STDERR "$zip2 XY2: $xy2\n";

	my $gis = GIS::Distance->new();

	# $gis->formula('Haversine');  # Optional, default is Haversine.
	my $distance = $gis->distance( $lat1,$lon1 => $lat2,$lon2 );
	my $meters = $distance->km();
	return($meters);
	}


1;