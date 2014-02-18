#!/usr/bin/perl

use lib "/httpd/modules";
use strict;

my %params = ();
foreach my $arg (@ARGV) {
	#if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}

my $CLUSTER = undef;
if ($params{'cluster'} ne '') {
	$CLUSTER = $params{'cluster'};
	}
else {
	die("cluster= is required");
	}

if ($params{'verb'} eq 'init') {
	}
elsif ($params{'verb'} eq 'send') {
	}
else {
	die("verb=init|send is required");
	}


require CUSTOMER::NEWSLETTER;
require CUSTOMER;
require DBINFO;
require ZOOVY;
require DOMAIN::TOOLS;
require DOMAIN;
require SITE::MSGS;
use Data::Dumper;




my $udbh = &DBINFO::db_user_connect("\@$CLUSTER");
print STDERR "\n\nProcessing Newsletters: ".`date`."\n";

## phase1: process the campaigns table in ZOOVY and populate the CAMPAIGN_RECIPIENTS table in the ORDER DB

if ($params{'verb'} ne 'init') {
	}
elsif (not &DBINFO::has_opportunistic_lock($udbh,"newsletters")) {
	die("sorry, cannot lock");
	}
else {
	print STDERR "Populate CAMPAIGN_RECIPIENTS table\n";
	if (not defined $udbh) { die("Could not connect to database!"); }
	# print STDERR $pstmt."\n";

	my @CAMPAIGNS = ();		## an arrayref of campaigns
	my $pstmt = "select * from CAMPAIGNS where STATUS in ('APPROVED','QUEUED') ";
		if ($params{'user'}) { $pstmt .= " and MID=".int(&ZOOVY::resolve_mid($params{'user'})); }
		$pstmt .= " order by ID,STARTS_GMT";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $CREF = $sth->fetchrow_hashref() ) {
		my $NID = -1;
		if ($CREF->{'RECIPIENT'} eq 'OT_All') { $NID=0; }
		elsif ($CREF->{'RECIPIENT'} =~ /^OT_([\d]+)$/) { $NID = int($1); }	# handle OT_###
		else { $NID = -1; }	## implicitly set ID to -1 for DO NOT SEND.

		if (($NID >= 0) && ($NID <= 16)) {
			## ID's 0 - 16 are safe to send.!
			my $BIT = 0;
			if ($NID==0) {
				## this will enable newsletters 1-32
				## NOTE: when order manager is publishing lists, we *might* need to change this.
				$BIT = 0xFFFF; 
				}
			else {
				## if ID>0 then set the correct bit e.g. 1-15 
				$BIT = 1 << ($NID-1);
				}
			$CREF->{'BITMASK'} = $BIT;
			}

		if ($CREF->{'STARTS_GMT'} > time()) {
			## not time to send this campaign yet.
			print "SKIPPING[$CREF->{'ID'}] $CREF->{'USERNAME'} -- does not start until: ".&ZTOOLKIT::pretty_date($CREF->{'STARTS_GMT'},1)."\n";
			}
		else {
			## lets send it.
			print "STARTING[$CREF->{'ID'}]: $CREF->{'USERNAME'} --  ".&ZTOOLKIT::pretty_date($CREF->{'STARTS_GMT'},1)."\n";
			push @CAMPAIGNS, $CREF;
			}
		}
	$sth->finish();

	##
	## SANITY: at this point @CAMPAIGNS is an arrayref of CAMPAIGN hashes
	##				with BITMASK setup.
	##

	foreach my $CREF (@CAMPAIGNS) {
		## NOTE: $CREF->{RECIPIENT} is one of the following:
		##			OT_All <== all newsletters (just pass ID=0)
		##			OT_1	<== newsletter #1

		my $USERNAME = $CREF->{'USERNAME'};		
		my $MID = &ZOOVY::resolve_mid($USERNAME);
		my $CREATED_GMT = $CREF->{'STARTS_GMT'};
		if ($CREATED_GMT==0) { $CREATED_GMT = time(); }
		my $count = 0;
		next if ($MID==0);
		next if (($CREF->{'STATUS'} ne 'APPROVED') && ($CREF->{'STATUS'} ne 'QUEUED'));

		my $PRT = int($CREF->{'PRT'});
		($PRT) = &CUSTOMER::remap_customer_prt($USERNAME,$PRT);

	 	## fetch subscribers
	 	require CUSTOMER;
	 	my $odbh = &DBINFO::db_user_connect($USERNAME);
		my $TB = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
		$count = 0;
		my $BITMASK = $CREF->{'BITMASK'};
	
		my $did_insert = 0;
		my $pstmt = "select CID, EMAIL from $TB where (NEWSLETTER & $BITMASK)>0 and MID=$MID /* $USERNAME */ and PRT=$PRT ";
		print $pstmt."\n";
  		my $sth = $odbh->prepare($pstmt);
		$sth->execute();
		while(my ($CID, $EMAIL) = $sth->fetchrow() ){
			## validate email before putting into CAMPAIGN_RECIPIENTS	
			## returns 1 if correct
			if (not &ZTOOLKIT::validate_email($EMAIL)) {	
				}
			else {			
				## insert data into CAMPAIGN_RECIPIENTS
				my ($pstmt) = "select count(*) from CAMPAIGN_RECIPIENTS where MID=$MID and CID=$CID and CPG=".int($CREF->{'ID'});
				my ($count) = $udbh->selectrow_array($pstmt);

				if ($count>0) {
					$did_insert++;
					}
				else {
					## not in db, insert it 
					my ($pstmt) = &DBINFO::insert($odbh,'CAMPAIGN_RECIPIENTS',{
						MID=>$MID,CID=>$CID,CPG=>$CREF->{'ID'},CREATED_GMT=>$CREATED_GMT,
						},sql=>1);
					# print STDERR $pstmt."\n";
					my $rv = $odbh->do($pstmt); 
					if (defined $rv) { $did_insert++; }
					}
				}
			}
		$sth->finish();
		&DBINFO::db_user_close();

		my ($pstmt) = "select count(*) as TOTAL,sum(IF(SENT_GMT>0,1,0)) as SENT from CAMPAIGN_RECIPIENTS where  CPG=".$udbh->quote($CREF->{'ID'})." and MID=$MID /* $USERNAME */";
		my ($TOTAL,$SENT) = $odbh->selectrow_array($pstmt);

		print STDERR "FINAL[$CREF->{'ID'}] -- did_insert:$did_insert total:$TOTAL sent:$SENT\n";

		my %vars = (
			'STAT_SENT'=>$SENT,
			'STAT_QUEUED'=>$TOTAL, 
			'QUEUED_GMT'=>time(),
			'STATUS' => 'QUEUED'
			);

		if ($SENT >= $TOTAL) { 
			$vars{'STATUS'} = 'FINISHED'; 
			$vars{'FINISHED_GMT'} = time(); 
			}
		my $pstmt = &DBINFO::insert($odbh,'CAMPAIGNS',\%vars,key=>{'ID'=>$CREF->{'ID'}},sql=>1,update=>1);
		print $pstmt."\n";
		$odbh->do($pstmt);
		}

	print STDERR "DONE Populating CAMPAIGN_RECIPIENTS\n";
	}





if ($params{'verb'} eq 'send') {
	my $PID = $$;
	my $TS = time();

	##
	## phase2: go through the CAMPAIGN_RECIPIENTS table and send the messages
	##

	print STDERR "Send Messages\n";

	## Unlock records which have been locked for a long time.
	if (1) {
		my $pstmt = "update CAMPAIGN_RECIPIENTS set LOCKED_GMT=0,LOCKED_PID=0 where LOCKED_PID>0 and LOCKED_GMT<".(time()-7200);
		if ($params{'user'}) { $pstmt .= " and MID=".int(&ZOOVY::resolve_mid($params{'user'})); }
		if ($params{'limit'}) { $pstmt .= " limit ".int($params{'limit'}); }
		print STDERR $pstmt."\n";
		$udbh->do($pstmt);
		}

	## Clean up records which have been sent.
	if (1) {
		my $pstmt = "/* cleanup campaigns */ delete from CAMPAIGN_RECIPIENTS where LOCKED_GMT<".(time()-(86400*30))." and LOCKED_GMT>0";
		if ($params{'user'}) { $pstmt .= " and MID=".int(&ZOOVY::resolve_mid($params{'user'})); }
		print STDERR $pstmt."\n";
		$udbh->do($pstmt);
		}

	if (1) {
		## Lock new records
		my $pstmt = "update CAMPAIGN_RECIPIENTS set LOCKED_GMT=$TS,LOCKED_PID=$PID where LOCKED_GMT=0 and LOCKED_PID=0 ";
		
		if (defined $params{'user'}) { $pstmt .= " and MID=".int(&ZOOVY::resolve_mid($params{'user'}))." /* $params{'user'} */"; }
		$pstmt .= "order by ID limit 5000";
		print STDERR $pstmt."\n";
		$udbh->do($pstmt);
		}

	my $ctr = 0;
	my %CAMPAIGNS = ();

	my $pstmt = "select * from CAMPAIGN_RECIPIENTS where LOCKED_GMT=$TS and LOCKED_PID=$PID ORDER BY ID";
	print STDERR $pstmt."\n";

	my $sth = $udbh->prepare($pstmt);
	$sth->execute();

	my $PREV_CPG = '';
	while ( my $ceref = $sth->fetchrow_hashref() ) {
		my $body = '';
	
		my $CREF = $CAMPAIGNS{$ceref->{'CPG'}};
		if (not defined $CREF) {
			## CACHING TO "REMEMBER" CAMPAIGNS
			my $USERNAME = &ZOOVY::resolve_merchant_from_mid($ceref->{'MID'});
		
			print STDERR "MID[$ceref->{'MID'}] CPG[$ceref->{'CPG'}]\n";
		#	my $PROFILE = &ZOOVY::prt_to_profile($USERNAME,$CREF->{'PROFILE'});
#			print STDERR Dumper($ceref);
			my $CREF = &CUSTOMER::NEWSLETTER::fetch_campaign($USERNAME,$ceref->{'CPG'});
			print Dumper($CREF);
			$CREF = &CUSTOMER::NEWSLETTER::generate($USERNAME,$CREF);

		#	$CREF->{'USERNAME'} = $USERNAME;
		#	$CREF->{'NAME'} =~ s/[^\w]+/ /g;	# strip out non-alpha numeric chars from NAME so it's URL friendly.
		#	$CREF->{'NAME'} =~ s/^[\s]+//g;  # strip out leading whitespace
		#	$CREF->{'NAME'} =~ s/[\s]+$//g;	# strip out trailing whitespace
		#	my $nsref = &ZOOVY::fetchmerchantns_ref($CREF->{'USERNAME'},$PROFILE);
			
			$CREF->{'_FOOTER'} = &CUSTOMER::NEWSLETTER::build_footer($CREF,$CREF->{'*SITE'}->nsref());
			$CREF->{'_CACHETS'} = &ZOOVY::touched($USERNAME);
			$CREF->{'USERNAME'} = $USERNAME;
		#	require PAGE;
		#	$CREF->{'_PG'} = "\@CAMPAIGN:".$CREF->{'ID'};
		# 	$CREF->{'*SITE'} = 
		#	require TOXML;
		#	$CREF->{'*T'} = TOXML->new('LAYOUT',$FL,USERNAME=>$USERNAME,MID=>$CREF->{'MID'});								  

		#	$CREF->{'_DOMAIN'} = &DOMAIN::TOOLS::syndication_domain($CREF->{'USERNAME'},$CREF->{'PROFILE'});
		#	$CREF->{'*D'} = DOMAIN->new($CREF->{'USERNAME'},$CREF->{'_DOMAIN'});
		#	if (not defined $CREF->{'*D'}) {
		#		warn "DOMAIN: $CREF->{'_DOMAIN'} could not be resolved";
		#		}
		#	elsif (not $CREF->{'*D'}->has_dkim()) {
		#		warn "DOMAIN: $CREF->{'_DOMAIN'} does not have DKIM support"; 
		#		delete $CREF->{'*D'}; 
		#		}
		#
			$CAMPAIGNS{$ceref->{'CPG'}} = $CREF;
			}

		$CREF = $CAMPAIGNS{$ceref->{'CPG'}};

#		print 'ceref    :'.Dumper($ceref);
#		print 'campaigns:'.Dumper($CREF);
		my $USERNAME = $CREF->{'USERNAME'};

		my ($c) = CUSTOMER->new($USERNAME,'CID'=>$ceref->{'CID'},'INIT'=>1,'PRT'=>$CREF->{'PRT'});
		print 'customer :'.Dumper($c);
		
		my $EMAIL = $c->fetch_attrib('INFO.EMAIL');
		print "EMAIL: $EMAIL\n";
		## changed 20090126, FULLNAME no longer exists in the CUSTOMER object
		#my $FULLNAME = $c->fetch_attrib('INFO.FULLNAME');
		my $FULLNAME = $c->fetch_attrib('INFO.FIRSTNAME')." ".$c->fetch_attrib('INFO.LASTNAME');
		my $MID = $ceref->{'MID'};

		## we always create a fresh _BODY since it will get interpolated/trashed.
		my $URI = "meta=NEWSLETTER&CPG=%CAMPAIGN%&CPN=%CPNID%";
		$CREF->{'_BODY'} = &CUSTOMER::NEWSLETTER::rewrite_links($CREF->{'OUTPUT_HTML'},$URI)."\n".$CREF->{'_FOOTER'};
		
		## only get the footer once
		my ($result,$warnings) = 
			&CUSTOMER::NEWSLETTER::send_newsletter($CREF,$EMAIL,$ceref->{'CID'},$ceref->{'ID'},$FULLNAME);

		print STDERR "Done sending: $result ".Dumper($warnings)."\n";
	
		## mail to good email to get a copy of the email
		## mail to bad email to confirm bounces are working correctly
		if($ctr == 0){
			#my $bad_email = "bad_email\@zoovy.com"; 
			#my $good_email = "news\@pattimccreary.com";
			#&CUSTOMER::NEWSLETTER::send_newsletter($CREF,$body,$footer,$bad_email,-1);
			#&CUSTOMER::NEWSLETTER::send_newsletter($CREF,$body,$footer,$good_email,-1);
			}
		$ctr++;


		## NOTE: you should always update CAMPAIGN_RECIPIENTS so we don't continue to retry to send the message
		##			don't put this inside of an "if" statement:
		## added update to SENT_GMT 12/05/05
		$pstmt = "update CAMPAIGN_RECIPIENTS set LOCKED_PID=0, SENT_GMT=".time()." where ID=".$ceref->{'ID'};
		print STDERR $pstmt."\n";

		my $udbh = &DBINFO::db_user_connect($USERNAME);
		$udbh->do($pstmt);
		&DBINFO::db_user_close();
		}
	$sth->finish();



	print STDERR "DONE with Sending Messages\n".`date`;
	}

&DBINFO::db_user_close();


