#!/usr/bin/perl


use strict;
use ElasticSearch;
use Clone;
use Data::Dumper;

use lib "/httpd/modules";
use ZOOVY;
use ZACCOUNT;
use ZTOOLKIT;
use PRODUCT::FLEXEDIT;
use ELASTIC;

my $USERNAME = $ARGV[0];
if ($USERNAME eq '') {
	die();
	}

my @USERS = ();
push @USERS, $ARGV[0];
#my $CLUSTER = &ZOOVY::resolve_cluster($USERNAME);
#if (uc($CLUSTER) eq uc($USERNAME)) {
#	@USERS = @{&ZACCOUNT::list_users('CLUSTER'=>$CLUSTER,"LIVE"=>1)};
#	}
#else {
#	push @USERS, $USERNAME;
#	}
#
foreach my $USERNAME (@USERS) {
	print "USERNAME: $USERNAME\n";
	print Dumper(&ELASTIC::rebuild_product_index($USERNAME));
	}



__DATA__
