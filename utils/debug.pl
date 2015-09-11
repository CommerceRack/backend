#!/usr/bin/perl

use Getopt::Long;
use lib "/backend/lib";
use ZOOVY;
use CART2;

my %cmdline = ();
Getopt::Long::GetOptions(
	"cart=s"=>\$cmdline{"cart"},
	"user=s"=>\$cmdline{"user"},
	"debug-shipping"=>\$cmdline{"debug-shipping"}
	);


if (not defined $cmdline{'prt'}) { $cmdline{'prt'} = 0; }
if (defined $cmdline{'user'}) { $cmdline{'mid'} = &ZOOVY::resolve_mid($cmdline{'user'}); }

use Data::Dumper;
print Dumper(\%cmdline);

if ($cmdline{'cart'}) {
	$cmdline{'*CART2'} = CART2->new_persist($cmdline{'user'},$cmdline{'prt'},$cmdline{'cart'});	
	}


if ($cmdline{'debug-shipping'}) {
	my ($CART2) = $cmdline{'*CART2'};
	my ($methods) = $CART2->shipmethods();
	print Dumper($methods)."\n";

	die();
	}
