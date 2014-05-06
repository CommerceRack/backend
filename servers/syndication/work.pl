#!/usr/bin/perl

use strict;
use DBI;
use POSIX;
use lib "/httpd/modules";
use DBINFO;
use NAVCAT;
use NAVCAT::FEED;
use SITE;
use Net::FTP;
use Archive::Zip;
use ZSHIP;
use SYNDICATION;
use LISTING::MSGS;
use Data::Dumper;
use URI::Escape;



##
## parameters can be used in any order, and merely RESTRICT the select statement
##
##		user=username
##		dst=DST code (GOO,YST,C01) -- hint: look in /httpd/modules/SYNDICATION.pm around line 27
##		profile=profile
##		type=product|inventory
##		limit=1  (only run one record)
##
##		DEBUG=1  - force a run (even if it's not necessary)
##		DEBUG=2  - do not actually submit file.
##		tracepid = product(s) comma or pipe separated. debug this product id. (usually used with DEBUG +2)
##
## ./work.pl user=2bhip dst=GOO profile=DEFAULT DEBUG=1 TRACEPID=DR37-RL2002

my %MERCHANTS = ();
my $ts = time();

my %params = ();
foreach my $arg (@ARGV) {
	#if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}

# 29.15 28.15 23.90 28/243 14332
if (my $reason = &ZOOVY::is_not_happytime(avg=>12)) {
	my $str = ''; foreach my $k (sort keys %params) { $str .= " $k=$params{$k} "; }
	&ZOOVY::confess($params{'user'},"ABORT: syndication/work.pl $str","Sorry, can't run right now reason:$reason");
	die();
	}

my @USERS = (); 
if ($params{'user'} eq '') {
	die("user is a required parameter");
	}

if (not defined $params{'type'}) { 
	warn "type=products|inventory was not set, assuming you wanted products\n";
	$params{'type'} = 'products';
	}

## correct type=PRODUCTS to type=product
$params{'type'} = uc($params{'type'});
if ($params{'type'} eq 'PRODUCT') { $params{'type'} = 'PRODUCTS'; }

if (not defined $params{'dst'}) {
	die("dst= is a required parameter");
	}

my $udbh = &DBINFO::db_user_connect($params{'user'});

my $lockid = int($params{'lockid'});
if ($lockid==0) { $lockid = $$; }




# /httpd/servers/syndication/work.pl user=cubworld type=INVENTORY dst=SRS queued=1307992127 dbid=5360
my $pstmt = "update SYNDICATION set LOCK_ID=$lockid,LOCK_GMT=$ts where ".
				" USERNAME=".$udbh->quote($params{'user'}).
				" and DSTCODE=".$udbh->quote($params{'dst'});
if ($params{'dbid'}) { $pstmt .= " and ID=".int($params{'dbid'}); }
if ($params{'profile'}) { $pstmt .= " and PROFILE=".$udbh->quote($params{'profile'}); }
if ($params{'prt'}) { $pstmt .= " and DOMAIN=".$udbh->quote(sprintf("#%d",int($params{'prt'}))); }

## hmm.. 

if ($params{'pid'}) {
	## limit's to a specific product id (for debugging)
	}
print STDERR $pstmt."\n";
$udbh->do($pstmt);

##
## SANITY: at this point 
##

$pstmt = "select ID,USERNAME,DOMAIN,DSTCODE,IS_ACTIVE from SYNDICATION where LOCK_ID=$lockid and LOCK_GMT=$ts order by ID";
print STDERR $pstmt."\n";

my @SETS = ();
my $sth = $udbh->prepare($pstmt);
$sth->execute();
while ( my ($ID,$USERNAME,$DOMAIN,$DSTCODE,$IS_ACTIVE) = $sth->fetchrow() ) {
	if (not $IS_ACTIVE) {
		print "** IS_ACTIVE=0 -- skipping ID:$ID USERNAME:$USERNAME DOMAIN:$DOMAIN DSTCODE:$DSTCODE\n";
		}
	else {
		push @SETS, [ $ID,$USERNAME,$DOMAIN,$DSTCODE ];
		}
	}
$sth->finish();


foreach my $set (@SETS) {
	my ($ID,$USERNAME,$DOMAIN,$DSTCODE) = @{$set};

	print "ID: $ID\n";

	##
	## TODO: need to compare queued (if set to interval and to last_queued_gmt)
	##

	my $TYPE = $params{'type'};
	my $TMPLOGFILE = "/tmp/syndication-$USERNAME-$DOMAIN-$$-$DSTCODE-$TYPE.log";
	my ($lm) = LISTING::MSGS->new($USERNAME,logfile=>$TMPLOGFILE);

	if (not &ZOOVY::locklocal("$USERNAME-$DOMAIN-$DSTCODE-$ID","$$")) {
		$lm->pooshmsg("STOP|+Cannot obtain a lock!");
		}
	if (&ZOOVY::is_not_happytime()) {
		$lm->pooshmsg("STOP|+not a happy time.");
		}

	$USERNAME = lc($USERNAME);
	print ">>> USERNAME:$USERNAME DSTCODE:$DSTCODE DOMAIN:$DOMAIN TYPE:$TYPE (ID:$ID)\n";
	$lm->poosh("START","USERNAME:$USERNAME DSTCODE:$DSTCODE DOMAIN:$DOMAIN TYPE:$TYPE (ID:$ID)");

	my ($err) = undef;
	if (defined $err) {
		}
	elsif (not defined $SYNDICATION::PROVIDERS{$DSTCODE}) {
		$lm->poosh("FAIL-FATAL","Unknown Syndication Provider: $DSTCODE");
		## skip non-defined providers.
		}

	my ($so) = SYNDICATION->new($USERNAME,$DSTCODE,'*MSGS'=>$lm,'type'=>$params{'type'},'DEBUG'=>$params{'DEBUG'},'ID'=>$ID,'DOMAIN'=>$DOMAIN);
	if (not defined $so) {
		$lm->poosh("FAIL-FATAL","Syndication Provider $DSTCODE could not be loaded");
		}


	my ($gref) = undef;
	if ($lm->can_proceed()) {
		$gref = &ZWEBSITE::fetch_globalref($USERNAME);
		if ($so->{'MID'}==-1) { 
			$lm->poosh("STOP","No MID for USERNAME:$USERNAME");
			}
		elsif (not &ZOOVY::check_free_memory('is_safe')) {
			$lm->poosh("SKIP","Not enough free memory");
			}
		}


	## TODO: check interval
	my $DSTREF = $SYNDICATION::PROVIDERS{$DSTCODE};
	my $FEEDTYPE = $params{'type'};
	delete $params{'type'};
	if (not $lm->can_proceed()) {
		if (not defined $DSTREF) {
			$lm->poosh("STOP","DSTCODE:$DSTCODE was not found in SYNDICATION::PROVIDERS");
			}
		elsif (($FEEDTYPE eq 'PRODUCTS') && ($DSTREF->{'send_products'}<=0)) {
			$lm->poosh("STOP","DSTCODE:$DSTCODE does not send_products");
			}
		elsif (($FEEDTYPE eq 'INVENTORY') && ($DSTREF->{'send_inventory'}<=0)) {
			$lm->poosh("STOP","DSTCODE:$DSTCODE does not send_inventory");
			}
		}

	##
	##
	##
	if (not $lm->can_proceed()) {
		## ooh.. bad shit.
		}
	elsif ($FEEDTYPE eq 'PRODUCTS') {
		$so->runnow('type'=>'product',%params);
		}
	elsif ($FEEDTYPE eq 'PRICING') {
		$so->runnow('type'=>'pricing',%params);
		}
	elsif ($FEEDTYPE eq 'INVENTORY') {
		$so->runnow('type'=>'inventory',%params);
		}
	else {
		$lm->poosh("ISE","UNKNOWN FEEDTYPE: $FEEDTYPE");
		}

	##
	## EVENTUALLY: if NEEDS_INVENTORY, etc.
	##
	if ($params{'DEBUG'}&2) {
		$so->{'_CHANGES'}=0;
		}

	my ($result) = $lm->whatsup();

	my %DB_UPDATE = ( 'ID'=>$ID, 'MID'=>$so->mid() );
	my $VERB = $result->{'!'};
	if (($VERB eq 'ERROR') || ($VERB eq 'STOP') || ($VERB eq 'PAUSE')) {
		}

	if ($VERB eq 'ERROR') {
		## FAILURE OF SOME TYPE
		if ($lm->had('FAIL-FATAL')) {
			&ZOOVY::confess($USERNAME,"SYNDICATION $result->{'+'}\nNOTE: we've set IS_ACTIVE=0 due to this error, so you can ignore this ticket if you know why this happened.\nDBID:$ID\nDOMAIN:$DOMAIN\nDST:$DSTCODE\n\n\n".Dumper($lm),justkidding=>1);
			}
		$DB_UPDATE{'*CONSECUTIVE_FAILURES'} = 'CONSECUTIVE_FAILURES+1';
		if ($so->{'CONSECUTIVE_FAILURES'}>5) {
			$DB_UPDATE{'IS_SUSPENDED'} = 101;
			$lm->pooshmsg(sprintf("OFFLINE|+Syndication has been offlined due to %s consecutive errors",$so->{'CONSECUTIVE_FAILURES'}));
			}
		}
	elsif (my $stopref = $lm->had('STOP')) {
		## this is for cases where it wasn't an error/fatal, but at the same time, we don't want to try again for a while
		$DB_UPDATE{'LOCK_GMT'} = 0;
		$DB_UPDATE{'LASTSAVE_GMT'} = 0;
		$DB_UPDATE{'LOCK_ID'} = 0;
		$DB_UPDATE{'*CONSECUTIVE_FAILURES'} = 'CONSECUTIVE_FAILURES+1';
		if ($so->{'CONSECUTIVE_FAILURES'}>5) {
			$DB_UPDATE{'IS_SUSPENDED'} = 102;
			$lm->pooshmsg(sprintf("OFFLINE|+Syndication has been offlined due to excesssive stop commands (failures: %s)",$so->{'CONSECUTIVE_FAILURES'}));
			}
		else {
			$lm->pooshmsg(sprintf("NOTE|+encountered STOP, will retry"));
			}
		}
	else {
		## NON-FAILURE (SUCCESS) HANDLER
		## NOTE: this is also a 'PAUSE'
		$DB_UPDATE{'LOCK_GMT'} = 0;
		$DB_UPDATE{'LASTSAVE_GMT'} = 0;
		$DB_UPDATE{'LOCK_ID'} = 0;
		$DB_UPDATE{'*CONSECUTIVE_FAILURES'} = 'CONSECUTIVE_FAILURES+1';
		if ($FEEDTYPE ne '') {		
			$DB_UPDATE{"*${FEEDTYPE}_LASTRUN_GMT"} = "unix_timestamp(now())";
			}

		if (not $lm->has_win()) {
			## NOTE: a *PAUSE* will cause an error dump, which might not be what we want.
			my $FILE = "/tmp/syndication-error-$DSTCODE-$USERNAME-$DOMAIN";
			print "NOT A WIN !!! So dumping \$lm error log: $FILE\n";
			open F, ">$FILE";
			print F Dumper($lm);
			close F;
			}
		}

	#if (($so->{'INFORM_ZOOVY_MARKETING'}) && (not $lm->has_win())) {
	#	open MH, "|/usr/sbin/sendmail -t";
	#	print MH "To: marketing\@zoovy.com\n";
	#	print MH "From: marketing\@zoovy.com\n";
	#	print MH "Subject: Syndication failure: $lm
	#	close MH;
	#	}

	print STDERR Dumper(\%DB_UPDATE);
	my ($pstmt) = &DBINFO::insert($udbh,'SYNDICATION',\%DB_UPDATE,key=>['ID','MID'],update=>2,sql=>1);
	print STDERR "/* work.pl */ $pstmt\n";
	$udbh->do($pstmt);

	## append this syndication log file to the one in the users home directory
	my $yyyymm = POSIX::strftime("%Y%m",localtime(time()));
	my $USERPATH = &ZOOVY::resolve_userpath($USERNAME);
 	system("cat $TMPLOGFILE >> $USERPATH/syndication-$DSTCODE-$DOMAIN-$yyyymm.log");
	unlink($TMPLOGFILE);

	if ($so->is_debug()) {
		print Dumper($lm);
		}

	$params{'type'} = $FEEDTYPE;	# restore feedtype in passed parameters in case we're looping.
	}
$sth->finish();

&DBINFO::db_user_close();
print "DONE!\n";

# tell at/queue.pl that we exited without issue
exit 1;
