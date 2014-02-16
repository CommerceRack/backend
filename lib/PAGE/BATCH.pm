package PAGE::BATCH;

##
## used by sitebuilder
##

use strict;

use YAML::Syck;
use Data::Dumper;
use lib "/backend/lib";
require DBINFO;
require ZOOVY;

##
## not even sure this is used anymore.
##
sub fetch_flows {
	my ($USERNAME, $PRT) = @_;

	my $ref = &PAGE::BATCH::fetch_pages($USERNAME,PRT=>$PRT);
	my %RESULT = ();
	foreach my $k (keys %{$ref}) {
		$RESULT{$k} = $ref->{$k}->{'fl'};
		}
	return(\%RESULT);
	}


##
## add a quick mode that doesn't actually change the page.
##
sub fetch_pages {
	my ($USERNAME,%options) = @_;

	my %RESULT = ();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select SAFEPATH,LASTMODIFIED_GMT ";
	if (not $options{'quick'}) { $pstmt .= ",DATA "; }
	$pstmt .= " from SITE_PAGES where MID=$MID /* $USERNAME */ and PRT=".int($options{'PRT'});

	print STDERR $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($safe,$lastmodified,$data) = $sth->fetchrow() ) {
		my $ref = {};
		if ($data ne '') {
			$ref = YAML::Syck::Load($data);
			}
		$ref->{'id'} = $safe;
		$ref->{'modified_gmt'} = $lastmodified;
		$RESULT{$safe} = $ref;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\%RESULT);
	}


1;