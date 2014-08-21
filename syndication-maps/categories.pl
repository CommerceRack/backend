#!/usr/bin/perl

use strict;

# 51520
use lib "/httpd/modules";
require WEBDOC;
use Data::Dumper;
use Storable;
use SYNDICATION;
use SYNDICATION::CATEGORIES;

my %params = ();
foreach my $arg (@ARGV) {
	if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}

my @DSTS = ();
if (defined $params{'dst'}) {
	if ($SYNDICATION::PROVIDERS{$params{'dst'}}->{'category_webdoc'}) {
		push @DSTS, $params{'dst'};
		}
	else {
		die("dst=$params{'dst'} does not have category_webdoc attribute set in syndication definition");
		}
	}
if (defined $params{'all'}) {
	foreach my $id (keys %SYNDICATION::PROVIDERS) {
		my $sp = $SYNDICATION::PROVIDERS{$id};
		next if (not defined $sp->{'category_webdoc'});
		print "Adding $id (webdoc #$sp->{'category_webdoc'})\n";
		push @DSTS, $id;
		}
	}

if (scalar(@DSTS)==0) {
	die("Need to specify at least one dst= parameter, or specify all=1");
	}


foreach my $DST (@DSTS) {

	my $sp = $SYNDICATION::PROVIDERS{$DST};
	my $DOCID = $sp->{'category_webdoc'};

	my ($doc) = WEBDOC->new($DOCID);
	my $txt = '';
	if ($doc->body() =~ /\[\[CATEGORIES\]\](.*?)\[\[\/CATEGORIES\]\]/s) {
		$txt = $1;
		}
	else {
		die("No [[CATEGORIES]] found in DOC:$DOCID");
		}

	if ($txt eq '') {
		die("nothing found inside [[CATEGORIES]] tag");
		}

	my @rows = ();
	my $count = 0;
	foreach my $line (split(/[\n\r]+/,$txt)) {
		$count++;
		next if ($line eq '');
		next if (substr($line,0,1) eq '#');
		next if ($line =~ /^[\s]+$/);

		## tags or pipes are valid delimeters
		my ($catid,@cols) = split(/[\>\t\|]/,$line);
		foreach (@cols) {
			s/^[\s]+//g; 	# strip leading whitespace
			s/[\s]+$//g; 	# strip trailing whitespace
			}
		$catid =~ s/[^\-\d\.]+//g;	# strip non numeric (and decimal) from catid

		if (int($catid)==0) {
			warn("failed on line[$count]: $line\n");
			}
	
		push @rows, [ $catid, join(" / ",@cols) ];
		}

	my $CDSREF = &SYNDICATION::CATEGORIES::CDSBuildTree($DST,\@rows);
	my $FILE1 = &SYNDICATION::CATEGORIES::CDSSave($DST,$CDSREF);

	my $FILE2 = sprintf("$SYNDICATION::CATEGORIES::PATH/%s/list.bin",uc($DST));
	Storable::nstore \@rows, $FILE2;

	print "Please push:\n$FILE1 -> \${HOSTS} install;\n$FILE2 -> \${HOSTS} install;\n";
	}
