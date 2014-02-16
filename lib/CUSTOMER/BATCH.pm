package CUSTOMER::BATCH;

use strict;
use lib "/backend/lib";
use strict;
require DBINFO;
require ZOOVY;
require CUSTOMER;




sub resolveCustomerSelector {
	my ($USERNAME,$PRT,$SELECTORS) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
	my %CUSTOMERS = ();
	foreach my $line (@{$SELECTORS}) {
		my ($VERB,$value) = split(/=/,$line,2);
		$VERB = uc($VERB);
		# print "LINE: $line\n";

		my @CIDS = ();
		if ($VERB eq 'CIDS') {
			foreach my $cid (split(/,/,$value)) {
				push @CIDS, int($cid);
				}
			}
		elsif ($VERB eq 'EMAILS') {
			foreach my $email (split(/,/,$value)) {
				push @CIDS, &CUSTOMER::resolve_customer_id($USERNAME,$PRT,$email);
				}
			}
		elsif (($VERB eq 'ACCOUNT_MANAGER') || ($VERB eq 'ACCOUNT_TYPE') || ($VERB eq 'SCHEDULE')) {
			my $pstmtx = "select CID from CUSTOMER_WHOLESALE where MID=$MID /* $USERNAME */ ";
			if ($VERB eq 'ACCOUNT_MANAGER') { $pstmtx .= " and ACCOUNT_MANAGER=".$udbh->quote($value); }
			if ($VERB eq 'ACCOUNT_TYPE') { $pstmtx .= " and ACCOUNT_TYPE=".$udbh->quote($value); }
			if ($VERB eq 'SCHEDULE') { $pstmtx .= " and SCHEDULE=".$udbh->quote($value); }
			print STDERR $pstmtx."\n";
			my $sth = $udbh->prepare($pstmtx);
			$sth->execute();
			while ( my ($CID) = $sth->fetchrow() ) { push @CIDS, $CID; }
			$sth->finish();
			}
		elsif (($VERB eq 'SUBLIST') || ($VERB eq 'ALL')) {
			## value of zero means *any* newsletter
			## value > 0 then set the correct bit e.g. 1-15
			my $BITMASK = ($value==0)?0xFFFF:(1 << ($value-1));
			if ($VERB eq 'ALL') { $BITMASK = 0; }

			my $pstmt = "select CID from $TB where  MID=$MID /* $USERNAME */ and PRT=$PRT";
			if ($BITMASK>0) { $pstmt .= " and (NEWSLETTER & $BITMASK)>0 "; }
			print $pstmt."\n";
  			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while (my ($CID) = $sth->fetchrow() ){
				push @CIDS, $CID;
				}
			$sth->finish();			
			}

		if (scalar(@CIDS)>0) {
			foreach my $CID (@CIDS) {
				$CUSTOMERS{$CID}++;
				}
			}
		}
	
	&DBINFO::db_user_close();

	return(keys %CUSTOMERS);
	}








###############################################################################
# Get all the orders for a customer
#
# returns: an array of order numbers
#
sub customer_orders {
	my ($USERNAME,$customer_id,$count) = @_;
	my ($order, @orders);
	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);

	my $qtUSERNAME = $odbh->quote($USERNAME);
	# $CUSTOMER::DEBUG = 1;

#	my ($customer_id) = &CUSTOMER::resolve_customer_id($USERNAME,0,$email);
	if ($customer_id<=0) { 
		warn "Customer [$customer_id] has no orders! M[$USERNAME] cid[$customer_id]\n";
		}
	else {	
		my $ORDERTB = &DBINFO::resolve_orders_tb($USERNAME,$MID);
		my $pstmt = "select ORDERID from $ORDERTB where /* USERNAME=$qtUSERNAME */ MID=$MID and CUSTOMER=$customer_id order by ID desc";
		if ((defined $count) && ($count>0)) { $pstmt .= " limit 0,".int($count); }
		if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }

		# print STDERR $pstmt."\n";
		my $sth = $odbh->prepare($pstmt);
		$sth->execute();
		# $sth->bind_col(1,\$order);
		while ( ($order) = $sth->fetchrow()) { push @orders, $order; }
		$sth->finish();
		}

	&DBINFO::db_user_close();

	return (@orders);
}

## returns a hash keyed by email address, with comma separated
## record id, modified timestamp (unix format) in the value.
#sub list_since
#{
#  my ($USERNAME,$SINCE) = @_;
#
#	my $odbh = &DBINFO::db_user_connect($USERNAME);
#	my %hash = ();
#		
#	my $qtUSERNAME = $odbh->quote($USERNAME);
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
#
#
#	my $pstmt = "select ID, EMAIL, unix_timestamp(MODIFIED), FULLNAME from $CUSTOMERTB where USERNAME=$qtUSERNAME and MID=$MID ";
#	if (defined $SINCE) {
#		$pstmt .= " and MODIFIED>".&ZTOOLKIT::mysql_from_unixtime($SINCE+0);
#		}
#	if ($CUSTOMER::DEBUG) { print STDERR "list_since: ".$pstmt."\n"; }
#	my $sth = $odbh->prepare($pstmt);
#	my $rv = $sth->execute();
#	my $fullname; my $id; my $email; my $modified;
#	if (defined($rv)) {
#		while ( ($id, $email, $modified, $fullname) = $sth->fetchrow() ) { $hash{$email} = "$id,$modified,$fullname"; }
#		}
#	&DBINFO::db_user_close();
#	return (%hash);
#}
#

## returns a hash keyed by email address, with comma separated
## record id, modified timestamp (unix format), fullname in the value.
sub list_customers {
  my ($USERNAME,$PRT,%options) = @_;

	## default to old list_customers flat format.
	$PRT = int($PRT);
	($PRT) = &CUSTOMER::remap_customer_prt($USERNAME,$PRT);
	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my %hash = ();
		
	my $qtUSERNAME = $odbh->quote($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
	
	my $pstmt = "select CID, EMAIL, MODIFIED_GMT, FIRSTNAME, LASTNAME, CREATED_GMT ";
	if ((defined $options{'IS_AFFILIATE'}) || (defined $options{'AFFILIATE_ID'})) {
		$pstmt .= ",IS_AFFILIATE ";
		}
	$pstmt .= "  from $CUSTOMERTB where PRT=$PRT and MID=$MID /* USERNAME=$qtUSERNAME */";
	if ((defined $options{'CREATED_GMT'}) && ($options{'CREATED_GMT'}>0)) { $pstmt .= " and CREATED_GMT>=".$odbh->quote(int($options{'CREATED_GMT'})); }
	if ((defined $options{'CREATEDTILL_GMT'}) && ($options{'CREATEDTILL_GMT'}>0)) { $pstmt .= " and CREATED_GMT<".$odbh->quote(int($options{'CREATEDTILL_GMT'})); }
	if ((defined $options{'NEWSLETTERMASK'}) && ($options{'NEWSLETTERMASK'}>0)) { my $BITMASK = int($options{'NEWSLETTERMASK'}); $pstmt .= " and (NEWSLETTER & $BITMASK)>0 "; }
	if (defined $options{'SCHEDULE'}) { $pstmt .= " and SCHEDULE=".$odbh->quote($options{'SCHEDULE'}); }

	if (defined $options{'IS_AFFILIATE'}) {
		## show all affiliates.
		$pstmt .= " and IS_AFFILIATE>0";
		}
	elsif (defined $options{'AFFILIATE_ID'}) {
		## only show affiliates matching a specific program.
		$pstmt .= " and IS_AFFILIATE=".int($options{'AFFILIATE_ID'});
		}
	if ($CUSTOMER::DEBUG) { print STDERR "list_customers: ".$pstmt."\n"; }

	print STDERR $pstmt."\n";

	my $sth = $odbh->prepare($pstmt);
	my $rv = $sth->execute();
	
	if (not defined($rv)) {
		}
	elsif (defined $options{'HASHKEY'}) {
		## HASHKEY could be CID, EMAIL, or any other unique property.
		my $key = $options{'HASHKEY'};
		while ( my $ref = $sth->fetchrow_hashref() ) {
			$hash{$ref->{ $key }} = $ref;
			}
		}
	else {
		## default to non-hashref
		while ( my ($id, $email, $modified, $firstname, $lastname, $created ) = $sth->fetchrow() )  { 
			$hash{$email} = "$id,$modified,$firstname,$lastname,$created"; }
			}
	$sth->finish();
	&DBINFO::db_user_close();
	return (%hash);
	}


## returns a hash keyed by customer id, with comma separated
## email, modified timestamp (unix format), fullname in the value.
sub list_customers_by_id {
  my ($USERNAME) = @_;

	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my %hash = ();
		
	my $qtUSERNAME = $odbh->quote($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);


	my $pstmt = "select CID, EMAIL, MODIFIED_GMT, FIRSTNAME, LASTNAME from $CUSTOMERTB where MID=$MID /* $qtUSERNAME */";
	if ($CUSTOMER::DEBUG) { print STDERR "list_customers_by_id: ".$pstmt."\n"; }
	my $sth = $odbh->prepare($pstmt);
	my $rv = $sth->execute();
	if (defined($rv))
		{
		my ($id,$email,$modified,$firstname,$lastname) = ();
		while ( ($id, $email, $modified, $firstname,$lastname ) = $sth->fetchrow() ) 
			{ $hash{$id} = "$email,$modified,$firstname $lastname"; }
		}
	&DBINFO::db_user_close();
	return (%hash);
}



## returns a hash keyed by email address, with comma separated
## record id, modified timestamp (unix format) in the value.
sub list_recent_customers {
  my ($USERNAME,$START,$COUNT) = @_;

	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my %hash = ();
		
	my $qtUSERNAME = $odbh->quote($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);

	my $pstmt = "select CID, EMAIL, MODIFIED_GMT, FIRSTNAME, LASTNAME from $CUSTOMERTB where MID=$MID /* $qtUSERNAME */ order by CREATED_GMT desc limit $START,$COUNT";
	if ($CUSTOMER::DEBUG) { print STDERR "list_recent_customers: ".$pstmt."\n"; }
	my $sth = $odbh->prepare($pstmt);
	my $rv = $sth->execute();
	my ($id,$email,$modified,$firstname,$lastname) = ();
	if (defined($rv)) {
		while ( ($id, $email, $modified, $firstname, $lastname) = $sth->fetchrow() ) 
			{ $hash{$email} = "$id,$modified,$firstname $lastname"; }
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return (%hash);
}


##
##
## SCOPE can be:
##		NAME
##		CID
##		
##
## returns:
##		an array of hashrefs
##
##
sub find_customers {
	my ($USERNAME, $searchfor, $scope, $elapseddays) = @_; 

	my @result = ();
	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my $qtUSERNAME = $odbh->quote($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	$scope = uc($scope);
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
	my ($ADDRTB) = &CUSTOMER::resolve_customer_addr_tb($USERNAME,$MID);

	if ($scope eq "FULL") {
		die();
		}


	my $qtLIKE = $odbh->quote($searchfor.'%');
	my $qtFULLTEXT = $odbh->quote('%'.$searchfor.'%');
	if ($searchfor =~ /\*/) {
		$searchfor =~ s/\*/\%/g;
		$qtFULLTEXT = $qtLIKE = $odbh->quote($searchfor);
		}
	my $qtEXACT = $odbh->quote($searchfor);
	
	my $pstmt = '';

	if ($scope eq 'GIFTCARD') {
		if ($searchfor =~ /\@/) { $scope = 'EMAIL'; }
		}

	if ($scope eq 'GIFTCARD') {
		require GIFTCARD;
		my $result = GIFTCARD::lookup($USERNAME,'CODE'=>$searchfor);
		if (defined $result) {
			$scope = 'CID'; $searchfor = $result->{'CID'};
			}
		}

	if (($scope eq 'ORDER') || ($scope eq 'ORDERID')) {
		use Data::Dumper;
		print STDERR Dumper($searchfor);

		require CART2;
		my ($O2) = CART2->new_from_oid($USERNAME,$searchfor);
		if (defined $O2) {
			($searchfor) = $O2->customerid();
			if (int($searchfor)==0) {
				print STDERR sprintf("LEGACY LOOKUP: %d %s\n",int($O2->prt()), $O2->in_get('bill/email'));
				($searchfor) =  &CUSTOMER::resolve_customer_id($USERNAME,$O2->prt(), $O2->in_get('bill/email'));
				print STDERR "searchfor: $searchfor\n";
				}
			if (int($searchfor)>0) {
				$scope = 'CID'; 
				}
			}
		}

	if ($searchfor eq '') {
		## Blank search = no results.
		}
	elsif (($scope eq "NAME") || ($scope eq 'LASTNAME')) {
		$pstmt = " and (FIRSTNAME like $qtLIKE or LASTNAME like $qtLIKE)";
		}
	elsif ($scope eq "CID") {
		$pstmt = " and CID=".int($searchfor);
		}
	elsif ($scope eq "EMAIL") {
		$pstmt = "and email like $qtLIKE";
		}
#	elsif ($scope eq "EBAY") {
#		$pstmt = "and EBAYUSER like $qtLIKE";
#		}
#	elsif (($scope eq 'WS') || ($scope eq 'SCHEDULE')) {
#		$pstmt = "and SCHEDULE=".$odbh->quote($searchfor);
#		}
	elsif ($scope eq "PHONE") {
		my $qtPHONE = $searchfor;
		$qtPHONE =~ s/[^\d]+//gs;
		$qtPHONE = $odbh->quote($qtPHONE);
		$pstmt = " and PHONE=$qtPHONE";
		}
	elsif (($scope eq 'ACCOUNT_MANAGER') || ($scope eq 'ACCOUNT_TYPE') || ($scope eq 'SCHEDULE') || ($scope eq 'WS')) {
		my $pstmtx = "select CID from CUSTOMER_WHOLESALE where MID=$MID /* $qtUSERNAME */ ";
		if ($scope eq 'ACCOUNT_MANAGER') { $pstmtx .= " and ACCOUNT_MANAGER=$qtEXACT"; }
		if ($scope eq 'ACCOUNT_TYPE') { $pstmtx .= " and ACCOUNT_TYPE=$qtEXACT"; }
		if ($scope eq 'SCHEDULE' || $scope eq 'WS') { $pstmtx .= " and SCHEDULE=$qtEXACT"; }
		print STDERR $pstmtx."\n";
		my $sth = $odbh->prepare($pstmtx);
		$sth->execute();
		while ( my ($CID) = $sth->fetchrow() ) {
			$pstmt .= "$CID,";
			}
		chop($pstmt);
		$pstmt = " and CID in ($pstmt)";
		$sth->finish();		
		}
	elsif ($scope eq 'NOTES') {
		my $pstmtx = "select CID from CUSTOMER_NOTES where MID=$MID /* $qtUSERNAME */ and NOTE like $qtFULLTEXT";
		print STDERR $pstmtx."\n";
		my $sth = $odbh->prepare($pstmtx);
		$sth->execute();
		while ( my ($CID) = $sth->fetchrow() ) {
			$pstmt .= "$CID,";
			}
		chop($pstmt);
		$pstmt = " and CID in ($pstmt)";
		$sth->finish();
		}

	if ($pstmt ne '') {
		my $pstmt = "select CID, EMAIL, PHONE, MODIFIED_GMT, FIRSTNAME, LASTNAME, PRT from $CUSTOMERTB where MID=$MID /* $qtUSERNAME */ $pstmt";
		print STDERR $pstmt."\n";
		my $sth = $odbh->prepare($pstmt);
		my $rv = $sth->execute();
		while ( my $hashref = $sth->fetchrow_hashref() ) { 
			push @result, $hashref;
			}
		$sth->finish();
		}

	&DBINFO::db_user_close();
	return(\@result);
	}



1;