#!/usr/bin/perl


use strict;
use Clone;
use Data::Dumper;

use lib "/httpd/modules";
use ZOOVY;
use ZTOOLKIT;
use PRODUCT::FLEXEDIT;
use ELASTIC;

my $USERNAME = $ARGV[0];
if ($USERNAME eq '') {
	die();
	}

my @USERS = ();
push @USERS, $ARGV[0];

foreach my $USERNAME (@USERS) {
	print "USERNAME: $USERNAME\n";
	print Dumper(&ELASTIC::rebuild_product_index($USERNAME));
	}



__DATA__
