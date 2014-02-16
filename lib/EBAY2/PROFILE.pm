package EBAY2::PROFILE;

use strict;
use YAML::Syck;
use lib "/backend/lib";
require DBINFO;


##
##
##
sub nuke {
	my ($USERNAME,$PRT,$CODE) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	($PRT) = int($PRT);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "delete from EBAY_PROFILES where MID=$MID /* $USERNAME */ and PRT=$PRT and CODE=".$udbh->quote($CODE);
	print STDERR "$pstmt\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	}

sub fetch {
	my ($USERNAME,$PRT,$CODE) = @_;

	my $REF = undef;
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	($PRT) = int($PRT);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select DATA from EBAY_PROFILES where MID=$MID /* $USERNAME */ and PRT=$PRT and CODE=".$udbh->quote($CODE);
	my ($DATA) = $udbh->selectrow_array($pstmt);
	if ($DATA ne '') {
		$REF = YAML::Syck::Load($DATA);
		}
	&DBINFO::db_user_close();
	return($REF);
	}



sub lookup_prt {
	my ($USERNAME,$CODE) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select PRT from EBAY_PROFILES where MID=$MID /* $USERNAME */ and CODE=".$udbh->quote($CODE);
	my ($PRT) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();
	return($PRT);
	}

##
## legacy function, lighly used.
##
sub fetch_without_prt {
	my ($USERNAME,$CODE) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($PRT) = &EBAY2::PROFILE::lookup_prt($USERNAME,$CODE);
	my ($REF) = &EBAY2::PROFILE::fetch($USERNAME,$PRT,$CODE);
	&DBINFO::db_user_close();
	return($REF);
	}


sub store {
	my ($USERNAME,$PRT,$CODE,$REF) = @_;

	my	$DATA = YAML::Syck::Dump($REF);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	($PRT) = int($PRT);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select count(*) from EBAY_PROFILES where MID=$MID /* $USERNAME */ and PRT=$PRT and CODE=".$udbh->quote($CODE);
	my ($exists) = $udbh->selectrow_array($pstmt);
	my %vars = ();
	$vars{'*MODIFIED_TS'} = 'now()';
	$vars{'CODE'} = $CODE;
	$vars{'PRT'} = $PRT;
	$vars{'MID'} = $MID;
	$vars{'DATA'} = $DATA;
	$vars{'V'} = int($REF->{'#v'});
	if ($exists==0) {
		$vars{'USERNAME'} = $USERNAME;
		$vars{'*CREATED_TS'} = 'now()';
		}
	($pstmt) = "/* EXISTS:$exists */ ".&DBINFO::insert($udbh,'EBAY_PROFILES',\%vars,update=>($exists==0)?0:2,key=>['MID','CODE','PRT'],sql=>1);
	print STDERR "$pstmt\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	return($REF);	
	}


sub list {
	my ($USERNAME,$PRT) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select CODE,CREATED_TS,MODIFIED_TS,V from EBAY_PROFILES where MID=$MID ";
	if (defined $PRT) { $pstmt .= " and PRT=".int($PRT); }
	my @RESULTS = ();
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $ref = $sth->fetchrow_hashref() ) {
		push @RESULTS, $ref;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@RESULTS);
	}


sub baseurl {
	my ($USERNAME,$DOMAIN,$CODE) = @_;
	return("http://$DOMAIN/media/merchant/$USERNAME/_ebay/$CODE/");
	}

##
##
##
sub profiledir {
	my ($USERNAME,$CODE) = @_;
	($CODE) = uc($CODE);
	$CODE =~ s/[^A-Z0-9]+//gs;	# strip non-allowed characters
	my ($userpath) = &ZOOVY::resolve_userpath($USERNAME)."/IMAGES/_ebay/$CODE";
	return($userpath);
	}
