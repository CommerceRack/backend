#!/usr/bin/perl

#
# how this works:
# EBAY::SYNDICATION.pm puts entries into LISTING_EVENTS table
# this processes those, listing events was an attempt to make a generic interface to marketplace listings
# but in reality ebay has moved away from this and we'll probably be able to remove it and make it work more like amazon
# where upload products with sku's in one feed, and inventory in another.
#


use strict;
use Data::Dumper;
use XML::SAX::Simple;
use IO::String;
use lib "/httpd/modules";
use DBINFO;
use LISTING::EVENT;
use LISTING::EBAY;
use ZSHIP;
use CFG;

# /httpd/servers/ebay/process.pl user=andreasinc uuid=1425014 reset=1
use Getopt::Long;

my %params = ();
foreach my $arg (@ARGV) {
	if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{lc($k)} = $v;
	}

my $verbose = undef;
Getopt::Long::GetOptions (
	"user=s" => \$params{'user'},    
	"uuid=s"   => \$params{'uuid'},  
	"product=s"   => \$params{'product'},  
	"verbose"  => \$verbose)   # flag
	or die("Error in command line arguments\n");



my @USERS = ();
my ($CFG) = CFG->new();
if ($params{'user'}) {
	push @USERS, $params{'user'};
	$params{'saas'} = 0;	## disable saas mode (single user mode)
	}
else {
	my $CFG = CFG->new();
	@USERS = @{$CFG->users()};
	$params{'saas'} = int($CFG->get('system','saas'));
	}



foreach my $user (@USERS) {
	&process($user,%params);
	}


##
##
##
sub process {
	my ($USERNAME,%options) = @_;

	my $ts = time();

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	## UNLOCK CODE:
	if (1) {
		my $pstmt = "select USERNAME,ATTEMPTS,ID,PRODUCT,LOCK_ID,LOCK_GMT from LISTING_EVENTS where 1=1 ";
		if (defined $options{'uuid'}) { 
			$pstmt .= " and ID=".int($options{'uuid'}); 
			}
		else {
			## NOTE: the +3600 is a safety mechanism to stop error 77's from happening where a shit ton of listings
			##			has been created (and will be executed by a batch, but hasn't finished yet)
			$pstmt .= " and LOCK_GMT>unix_timestamp($ts-(86400*10)) and LOCK_GMT< ($ts-((1800*ATTEMPTS)+3600)) and PROCESSED_GMT=0";
			}
		print $pstmt."\n";
		my ($sth) = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($USERNAME,$ATTEMPTS,$ID,$PID,$LOCKID,$LOCKGMT) = $sth->fetchrow() ) {
			&ZOOVY::confess($USERNAME,"EBAY LISTINGEVENT PID:$PID ID:$ID was unlocked ($ATTEMPTS)\nLOCKID:$LOCKID\nLOCKGMT:$LOCKGMT\n",justkidding=>1);
			$pstmt = "update LISTING_EVENTS set ATTEMPTS=ATTEMPTS+1,LOCK_GMT=0,LOCK_ID=0 where PROCESSED_GMT=0 and ID=$ID";
			print STDERR "$pstmt\n";
			$udbh->do($pstmt);
			}
		$sth->finish();
		}

	## LOCK CODE:
	if (1) {
		my $pstmt = "update LISTING_EVENTS set LOCK_GMT=$ts,LOCK_ID=$$,RESULT='RUNNING' where  LAUNCH_GMT<=$ts and LOCK_GMT=0 and LOCK_ID=0";
		if (not $options{'reset'}) { $pstmt .= " and PROCESSED_GMT=0 "; }

		if ($options{'uuid'}) {
			$pstmt .= " and ID=".int($params{'uuid'});
			}
		elsif ($options{'user'}) {
			$pstmt .= " and MID=".&ZOOVY::resolve_mid($options{'user'});
			if (defined $options{'product'}) {
				$pstmt .= " and PRODUCT=".$udbh->quote($options{'product'});
				}
			}

		$pstmt .= " order by ATTEMPTS,ID ";
		if (not defined $options{'limit'}) { $options{'limit'} = 10 ; }
		$pstmt .= " limit ".int($options{'limit'});
		print $pstmt."\n";
		$udbh->do($pstmt);
		}

	##
	## SANITY: at this point all the recovers we need are locked, flagged as "RUNNING" but nothing has been done.
	## 

	my $pstmt = "select * from LISTING_EVENTS where LOCK_GMT=$ts and LOCK_ID=$$";
	print $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $evref = $sth->fetchrow_hashref() ) {

		my $le = undef;
		print Dumper($evref);

		if (defined $options{'uuid'}) {
			## can't fail when we request a specific uuid
			$evref->{'RESULT_ERR_CODE'} = 0;
			$evref->{'RESULT_ERR_MSG'} = undef;
			}
		elsif ($evref->{'RESULT'} =~ /FAIL/) {
			## wow, this is already a fail.
			$pstmt = "update LISTING_EVENTS set PROCESSED_GMT=$ts where ID=".$evref->{'ID'};
			print $pstmt."\n";
			$udbh->do($pstmt);
			$evref = undef;
			}
		elsif ($evref->{'ATTEMPTS'}>3) {
			## fail the transaction, and undef it so we don't try again.
			open F, ">/tmp/ebay-too-many-attempts.$evref->{'ID'}";
			print F Dumper($evref);
			close F;
			$pstmt = "update LISTING_EVENTS set PROCESSED_GMT=$ts,RESULT='FAIL-SOFT',RESULT_ERR_SRC='TRANSPORT',RESULT_ERR_CODE=3000,RESULT_ERR_MSG='Too many attempts' where ID=".$evref->{'ID'};
			print $pstmt."\n";
			$udbh->do($pstmt);
			$evref = undef;
			warn "!!!!!!!!! DO MANY ATTEMPTS\n";
			}
		next if (not defined $evref);

		require LISTING::EVENT;
		($le) = LISTING::EVENT->new(DBREF=>$evref);
		if ((not defined $le) || (ref($le) ne 'LISTING::EVENT')) {
			## fail the transaction, and undef it so we don't try again.
			$pstmt = "update LISTING_EVENTS set PROCESSED_GMT=$ts,RESULT='FAIL-SOFT',RESULT_ERR_SRC='PREFLIGHT',RESULT_ERR_CODE=3000,RESULT_ERR_MSG='Invalid database record' where ID=".$evref->{'ID'};
			print $pstmt."\n";
			$udbh->do($pstmt);
			$le = undef;
			}
		$evref = undef;	# we don't need $evref anymore (use $le instead)
		next if (not defined $le);

		## SANITY: at this point, we've got a valid $le (LISTING::EVENT) which we're probably gonna try and dispatch.
		my $USERNAME = $le->username();
		if ($evref->{'ATTEMPTS'}>0) {
			## this has been attempted, so we should set the error status regardless, since it's probably gonna crash again.
			$le->set_disposition('RUNNING','TRANSPORT',2000+$le->{'ATTEMPTS'},sprintf("Originally processed: %s",&ZTOOLKIT::pretty_date($le->processed_gmt())));
			}
		$le->{'ATTEMPTS'}++;
	
		if ($le->result() eq 'PENDING') {
			die("this line should never be reached");
			}
		elsif ($le->result() eq 'RUNNING') {
			print "### BEGIN DISPATCH ###\n";
			$le->dispatch($udbh,undef);
			print "### END DISPATCH ###\n";
			}
		elsif ($le->result() =~ /(FAIL-SOFT|FAIL-FATAL)/) {
			die();
			}
		elsif ($le->result() =~ /(SUCCESS|SUCCESS-WARNING)/) {
			die();
			}
		else {
			&ZOOVY::confess($USERNAME,"Unknown event result [".$le->result()."]\n\n".Dumper($le),justkidding=>1);
			}

		print Dumper($le->msgs());
		print sprintf("FINISHED user=%s uuid=%s result=%s\n",$le->username(),$le->id(),$le->result());
		print "---------------------------------------------------------\n";

		# if ($le->... running? / pending)
		# print "RESULT: $RESULT\n";
		}
	$sth->finish();
	&DBINFO::db_user_close();
	}





