#!/usr/bin/perl

#  ./variations.pl --user campuscolors --verb list
#   ./variations.pl --user campuscolors --sog 00 --verb dump --xml
#   ./variations.pl --user campuscolors --sog A0 --verb dump --json
# ./variations.pl --user campuscolors --sog A0 --verb dump --json --file xyz.json
# ./variations.pl --user campuscolors --sog SZ --verb import --json --file xyz.json

use Getopt::Long;
my $USERNAME = '';
my $SOGID = '';
my $VERB = '';
my $IS_NEW = 0;
my $AS_XML = 0;
my $AS_JSON = 0;
my $FILE = '';
my $SHOW_LIST = 0;

GetOptions ("user=s" => \$USERNAME,
             "sog=s"   => \$SOGID,      # string
				 "verb=s"  => \$VERB,
				 "file=s"  => \$FILE,
              "xml"  => \$AS_XML,   # flag
              "json"  => \$AS_JSON   # flag
				) or die("Error in command line arguments\n");
                                       
use lib "/backend/lib";
use POGS;
use Data::Dumper;

if ($VERB eq '') { die("--verb dump|list|create|import is required"); }

if ($VERB eq 'list') {
	my $soglist = POGS::list_sogs($USERNAME);
	foreach my $sogid (keys %{$soglist}) {
		print "$sogid\t$soglist->{$sogid}\n";
		}
	exit 0;
	}

if ($SOGID eq '') { die("--sog is required"); }

if ($VERB eq 'create') {
	$ref = { 'sog'=>$SOGID, '@options'=>[] };
	exit 0;
	}
elsif ($VERB eq 'import') {
	my $data = '';
	if ($FILE) {
		open F, "<$FILE"; while (<F>) { $data .= $_; } close F;
		}
	else {
		while (<STDIN>) { $data .= $_; }
		}

	my $sogref = undef;
	# print "$data\n";
	if ($data eq '') { 
		die("could not read input"); 
		}
	elsif ($AS_JSON) {
		$sogref = POGS::from_json($data); 
		}
	elsif ($AS_XML) {
		$sogref = POGS::deserialize($data);
		}
	else {
		die("format not supported (try --xml or  --json)\n");
		}
	$sogref->[0]->{'id'} = $SOGID;
	POGS::store_sog($USERNAME,$sogref->[0]);
	# print Dumper($sogref);
	}
elsif ($VERB eq 'dump') {
	my $sogref = POGS::load_sogref($USERNAME,$SOGID);
	if (not defined $sogref) {
		die("sog $SOGID is not valid");
		}
	elsif ($AS_XML) {
		if ($FILE) { open F, ">$FILE"; print F POGS::to_xml($sogref); close F; } else {  print POGS::to_xml($sogref); }
		}
	elsif ($AS_JSON) {
		if ($FILE) { open F, ">$FILE"; print F POGS::to_json([$sogref]); close F; } else { print POGS::to_json([$sogref]); }
		}
	else {
		if ($FILE) { open F, ">$FILE"; print F Dumper($sogref); close F; } else { print Dumper($sogref); }
		}
	}

