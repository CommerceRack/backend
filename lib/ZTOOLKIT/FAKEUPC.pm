package ZTOOLKIT::FAKEUPC;

use strict;
use Business::UPC;
use lib "/backend/lib";
require DBINFO;
require ZOOVY;

sub fmake_upc {
	my ($USERNAME,$SKU) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $udbh = &DBINFO::db_user_connect($USERNAME);

	my ($fake) = &DBINFO::guid_lookup($USERNAME,"AMZUPC",$SKU);
	if ($fake eq '') { $fake = undef; }	# probably not necessary.

	if (not defined $fake) {
		## okay we're going to generate a fake upc
		my ($inc) = &DBINFO::next_in_sequence($udbh,$USERNAME,"AMZUPC",$SKU);
		if ($inc < 99999) {
			## note: the 8 prefix is used at first, and the zero suffix will be replaced by a valid checksum.
			$fake = sprintf("8%05d%05d0",$MID,$inc);
			}
		elsif ($inc < 199999) {
			## note: the 9 prefix is used next.
			$fake = sprintf("9%05d%05d0",$MID,$inc % 100000);
			}
		elsif ($USERNAME eq 'stateofnine') {
			# 8001xxxxxxxxxX is state of nine.
			$fake = sprintf("8001%07d0",$inc);
			}
		elsif ($USERNAME eq 'cubworld') {
			# 8001xxxxxxxxxX is state of nine.
			$fake = sprintf("8002%07d0",$inc);
			}
		else {
			warn "$USERNAME: Could not create fake UPC sequence: $inc (max: 199999)\n";
			}
	
		if (defined $fake) {
			print STDERR "FAKE: $fake\n";
			my $upc = new Business::UPC($fake);
	
			# print STDERR "VALID?: ".$upc->is_valid."\n";
			$upc->fix_check_digit;
			$fake = $upc->as_upc;
			}

		if ((defined $fake) && ($SKU ne '')) {
			&DBINFO::guid_register($USERNAME,"AMZUPC",$SKU,$fake);
			}
		}

	&DBINFO::db_user_close();

	return($fake);
	}

1;
