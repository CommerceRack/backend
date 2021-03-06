#!/usr/bin/perl


use strict;
use ElasticSearch;
use Clone;
use Data::Dumper;

use lib "/httpd/modules";
use ZOOVY;
use ZTOOLKIT;
use PRODUCT::FLEXEDIT;
use ELASTIC;
use ORDER::BATCH;

my $USERNAME = $ARGV[0];
if ($USERNAME eq '') {
	die();
	}

my @USERS = ();
push @USERS, $USERNAME;

my %options = ();
print Dumper(\@USERS);

foreach my $USERNAME (sort @USERS) {
	# next if (-f "did.$USERNAME");
	&ELASTIC::rebuild_private_index($USERNAME,'CREATED_GMT'=>&ZTOOLKIT::mysql_to_unixtime(20120101000000),'NUKE'=>1);
	open F, ">>/tmp/elastic.orders"; print F "$USERNAME\n"; close F;
	# open F, ">did.$USERNAME"; close F;
	# &ELASTIC::rebuild_product_index($USERNAME);
	}



__DATA__
