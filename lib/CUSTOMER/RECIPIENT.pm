package CUSTOMER::RECIPIENT;

use lib "/backend/lib";
use strict;

require ZTOOLKIT;
require ZOOVY;
require DBINFO;

##
##	figures out which specials (schedules or coupons) a user is eligible for as a result of being participating
##		in a campaign. this could be by clicking an rss feed, or a newsletter, or taking some other desired action
##		that is as yet undetermined.
## pass: merchant + couponid
##	returns: schedule id (or undef/blank if not set)
##
sub campaign_specials {
	my ($USERNAME, $CPGID, $CPNID) = @_;

	my $MID = &ZOOVY::resolve_mid($USERNAME);

	my $SET_SCHEDULE_TO = undef;	# schedule this newsletter put us on, or blank/undef for none.
	my $SET_COUPON_TO = undef;		# which coupon this is tied to (if any) 

	my $PURCHASED = 0;		# how many purchases have been made 
	my $COUNTDOWN = 0;		# how many times a purchase can be made (this is called SCHEDULE_COUNTDOWN) in database
									# but it should be renamed because it could be COUPONS or SCHEDULES
									# since either can NOW be used by a campaign to provide a discount.
									
	my $CPG_TYPE = undef;	# EMAIL|

	if ($CPNID>0) {
		my $odbh = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select CPG,PURCHASED from CAMPAIGN_RECIPIENTS where MID=".$odbh->quote($MID)." and ID=".$odbh->quote($CPNID);
		my $sth = $odbh->prepare($pstmt);
		$sth->execute();
		($CPGID,$PURCHASED) = $sth->fetchrow();
		$sth->finish();
		&DBINFO::db_user_close();
		}

	if ($CPGID>0) {
		my $udbh = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select COUPON,CPG_TYPE from CAMPAIGNS where MID=".int($MID)." and ID=".int($CPGID);
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		($SET_COUPON_TO,$CPG_TYPE) = $sth->fetchrow();
		$sth->finish();
		&DBINFO::db_user_close();

		if (($CPG_TYPE eq 'EMAIL') && ($CPNID==0)) {
			$SET_COUPON_TO = ''; 
			}

		}

	if ($COUNTDOWN==0) {}
	elsif ( ($COUNTDOWN-$PURCHASED)<=0 ) {
		# they've purchased off this campaign too many times!
		$SET_COUPON_TO = '';
		$SET_SCHEDULE_TO = '';	
		}

	return($SET_COUPON_TO,$SET_SCHEDULE_TO);
	}

##
##
sub fetch_CPNID{
	my ($USERNAME,$CPG,$CID) = @_;
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my $dbh = &DBINFO::db_user_connect($USERNAME);
   my $pstmt = "select ID from CAMPAIGN_RECIPIENTS ".
					"where MID=$MID ".
               " and CID=".$dbh->quote($CID).
					" and CPG=".$dbh->quote($CPG);
   my $sth = $dbh->prepare($pstmt);
   $sth->execute();
   my ($CPNID) = $sth->fetchrow_array();
   $sth->finish();
   &DBINFO::db_user_close();

   return($CPNID);
	}
	

## USERNAME
## EMAIL is the recipient email
## 
## returns: ID from CUSTOMER table
sub fetch_CID{
	my ($USERNAME,$EMAIL, $PRT) = @_;

	# print STDERR "$USERNAME $EMAIL\n";
	my ($CID) = CUSTOMER::resolve_customer_id($USERNAME,$PRT,$EMAIL);

	return($CID);
	}

##
## resolves a customer id from a campaign + couponid
##
sub lookup_CID {
	my ($USERNAME, $CPG, $CPNID) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select CID from CAMPAIGN_RECIPIENTS where MID=$MID /* $USERNAME */ and CPG=".int($CPG)." and ID=".int($CPNID);
	my ($CID) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();

	return($CID);
	}

## EMAIL is the recipient email
##	CPG is the full coupon string e.g. @CAMPAIGN:52
##	CPNID is the id column in the CAMPAIGN_RECIPIENTS table,this is sufficient for a soft auth to allow
##		simple soft tasks such as add/remove newsletter preferences which do not require a hard auth (login)
##
## return: 0/1 (0 for failure, 1 for success)
##
sub softauth_user {
	my ($USERNAME, $PRT, $EMAIL, $CPG, $CPNID) = @_;
	my $RESULT = 0;	
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
   $CPG =~ s/\@CAMPAIGN\://;
   $CPG =~ s/[^\d]+//g;
	print STDERR "SAU CPG: $CPG\n";
   my $udbh = &DBINFO::db_user_connect($USERNAME);
	my ($CID) = CUSTOMER::resolve_customer_id($USERNAME,$PRT,$EMAIL);
	 	
  	my $pstmt = "select count(1) from CAMPAIGN_RECIPIENTS ".
               "where CPG=".$udbh->quote($CPG).
    	         " and ID=".$udbh->quote($CPNID).
               " and MID=$MID ".
               " and CID=$CID";
	print STDERR $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
   $sth->execute();
   my ($COUNT) = $sth->fetchrow_array();
   $sth->finish();

   &DBINFO::db_user_close();

	## to prevent duplicates, should we return $RESULT=0 if more than 
	## one row is returned?
	if($COUNT > 0){ $RESULT = 1; }
	
	return($RESULT);
	}

##
##	CPG is the full coupon string e.g. @CAMPAIGN:52
##	CPNID is the id column in the CAMPAIGN_RECIPIENTS table
## ACTION described the action of the customers:
##
##	  columns set to 1/0
##		UNSUBSCRIBED - customer has unsubscribed
##
##   column set to incremental (ie PURCHASED+1)
##		OPENED - opened the email
##		CLICKED - clicked on a link (are we tracking exact links?)
##		PURCHASED - customer has made a purchase
##		BOUNCED - customer email has bounced
##
##		OPENED_GMT - first time customer opened email
##	  	CLICKED_GMT - first time customer clicked on a link
##	  	PURCHASED_GMT - last time customer purchased from email 
##
## SALES is the total sales if customer has made a purchase
##		(ie TOTAL_SALES+1)
##		
##
## returns: 0/1 (0 for failure, 1 for success)
##
sub coupon_action {
	my ($USERNAME, $ACTION, %options) = @_;

	my $CPG = $options{'CPG'};
	## NOTE: something things (like newsletters, still pass @CAMPAIGN:)
	$CPG =~ s/^\@CAMPAIGN://;		## legacy!
	$CPG = int($CPG);

	#$VAR1 = {
   #       'CPNID' => 45539453,
   #       'CPG' => '@CAMPAIGN:11874'
   #     };


	use Data::Dumper;
	print STDERR Dumper(\%options);

	## we now use CPN instead of CPNID
	if (defined $options{'CPN'}) { $options{'CPNID'} =  $options{'CPN'}; delete $options{'CPN'}; }

	my $CPNID = int($options{'CPNID'});
	my $SALES = int($options{'SALES'});

	print STDERR "CPG: $CPG CPNID: $CPNID\n";
	if (defined $options{'RSS'}) { $CPNID = 0; }

	my $SUCCESS = 0;
	my $TOTAL_SALES = '';
	my $GMT = '';

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);	
	my $udbh = &DBINFO::db_user_connect($USERNAME);

	if ((defined $options{'CPC'}) && ($options{'CPC'} ne '') && ($CPNID==0)) {
		## lets lookup CPG # in the database .. CPC (CP-CODE is used in RSS)
		my $pstmt = "select * from CAMPAIGNS where MID=$MID /* $USERNAME */ and CPG_TYPE='RSS' and CPG_CODE=".$udbh->quote($options{'CPC'});
		($CPG) = $udbh->selectrow_array($pstmt);
		}

	if ($CPG == 0) {
		warn "Unknown campaign CPC=$options{'CPC'}/ could not resolve for $USERNAME";
		$ACTION = '';
		}


	# only proceed if valid ACTION 

	if ($ACTION eq "UNSUBSCRIBED" ||
		$ACTION eq "OPENED" ||
		$ACTION eq "BOUNCED" ||
		$ACTION eq "CLICKED" ){
	
		if (($ACTION eq "OPENED") || ($ACTION eq "CLICKED")) {	
			$GMT = ", $ACTION"."_GMT=".time();
			}
	
		## CAMPAIGN_RECIPIENTS needs to be updated with latest ACTION
		## GMT's set for CLICKED & OPENED ACTIONs
		my $COUNT = 0;
		if ($CPNID>0) {
			my $pstmt = "update CAMPAIGN_RECIPIENTS set $ACTION=$ACTION+1".$GMT.
						" where MID=$MID /* $USERNAME */ ".
						" and CPG=".$udbh->quote($CPG)." and ID=".$udbh->quote($CPNID);
			print STDERR $pstmt."\n";
			my ($rv) = $udbh->do($pstmt);
	
			## find out how many times this customer has performed this action
			$pstmt = "select $ACTION from CAMPAIGN_RECIPIENTS ".
							"where MID=$MID /* $USERNAME */ ".
  		  	 				 " and CPG=".$udbh->quote($CPG).
  							 " and ID=".$udbh->quote($CPNID);
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			($COUNT) = $sth->fetchrow();
			$sth->finish();
			}

		## only update CAMPAIGNS with ACTION once	per customer
		if (($CPNID==0) || ($COUNT == 1)) {
			## CAMPAIGNS needs to be updated with latest ACTION
			## NOTE: CPNID==0 always updates action since it's non-serialized.
			my $pstmt = "update CAMPAIGNS set STAT_$ACTION=STAT_$ACTION+1";
			## views is the non-unique number of OPENS
			if ($ACTION eq 'OPENED') { $pstmt .= ",STAT_VIEWED=STAT_VIEWED+1"; }
			$pstmt .= " where MID=$MID /* $USERNAME */ and ID=".$udbh->quote($CPG);
			print STDERR $pstmt."\n";
			my ($rv) = $udbh->do($pstmt);
			## confirm both update were made
			if($rv == 2){ $SUCCESS = 1; }	
			}
		else{ 
			## no update to CAMPAIGNS needed, customer already performed ACTION
			$SUCCESS = 1; 
			if ($ACTION eq 'OPENED') {
				## track "VIEWS" aka non-unique OPENED actions.
				my $pstmt = "update CAMPAIGNS set STAT_VIEWED=STAT_VIEWED+1 where MID=$MID /* $USERNAME */ and ID=".$udbh->quote($CPG);
				my ($rv) = $udbh->do($pstmt);
				if ($rv == 2){ $SUCCESS = 1; }					
				}
			}
		}


	# update total sales if PURCHASED
	if($ACTION eq "PURCHASED"){
		## CAMPAIGN_RECIPIENTS needs to be updated with latest ACTION
		my $rv = 0;
		if ($CPNID>0) {
			my $pstmt = "update CAMPAIGN_RECIPIENTS set $ACTION=$ACTION+1, ".$ACTION."_GMT=".time().", TOTAL_SALES=TOTAL_SALES+".int($SALES).
							" where MID=$MID /* $USERNAME */ ".
							" and CPG=".$udbh->quote($CPG)." and ID=".$udbh->quote($CPNID);
			print STDERR $pstmt."\n";
			$rv = $udbh->do($pstmt);
			}

		## CAMPAIGNS needs to be updated with latest ACTION
		## CAMPAIGNS is currently storing incremental for PURCHASES (whether it's from the same customer or not)
		my $pstmt = "update CAMPAIGNS set STAT_$ACTION=STAT_$ACTION+1, STAT_TOTAL_SALES=STAT_TOTAL_SALES+".int($SALES).
					" where MID=$MID /* $USERNAME */ and ID=".$udbh->quote($CPG);
		print STDERR $pstmt."\n";
		$rv = $udbh->do($pstmt);
		if ($rv>0) { 
			$SUCCESS = 1; 
			}
		}

	&DBINFO::db_user_close();

	return($SUCCESS);
	}


1;