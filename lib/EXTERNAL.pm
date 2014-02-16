package EXTERNAL;

use strict;

use lib '/backend/lib';
require DBINFO;
require PRODUCT;
require ZOOVY;
require INVENTORY2;

$EXTERNAL::DEBUG = 0;

%EXTERNAL::STAGE = (
	'A'=>'Email Sent - Nothing done.',
	'I'=>'Informed - Received email', 
	'V'=>'Visited Website - No purchase',
	'G'=>'Gift Certificate',
	'C'=>'Completed',
	'P'=>'Waiting for Marketplace',
	'H'=>'Hold - Waiting for Payment',
	'N'=>'Non Paying Bidder Filed',
	'W'=>'Non Pay Warning Sent',
	'X'=>'Expired/No Longer Available',
);

if (%EXTERNAL::STAGE) {} # Keep perl from whining

##
## pass in a reference to an incomplete item or at least:
##		MKT=>'ebay'	MKT_LISTINGID=>
##
sub linkto {
	my ($incref) = @_;

	# &ZOOVY::confess('',"DEPRECATED EXTERNAL::linkto",justkidding=>1);

	my $url = '#';
	if ($incref->{'MKT'} eq 'ebay') {
		$url = 'http://cgi.ebay.com/aw-cgi/eBayISAPI.dll?ViewItem&item='.$incref->{'MKT_LISTINGID'};
		}
	elsif ($incref->{'MKT'} eq 'overstock') {
		$url = 'http://auctions.overstock.com/cgi-bin/auctions.cgi?PAGE=PRODDET&PRODUCTID='.$incref->{'MKT_LISTINGID'};
		}
	return($url);
	}


##
##
## USERNAME=>'@CLUSTER'
##		MARKET=>''
##		MARKETS=>['','']
##
## LIMIT=>##
##	STAGES=>['A','P']
##
sub report {
	my ($USERNAME, %options) = @_;

	&ZOOVY::confess($USERNAME,"DEPRECATED EXTERNAL::report",justkidding=>1);

	my @result = ();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my $pstmt = '';
	$pstmt = "select ID, USERNAME, SKU, ZOOVY_ORDERID, MODIFIED_GMT, STAGE from EXTERNAL_ITEMS where ";
	
	if (substr($USERNAME,0,1) ne '@') {
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		$pstmt .= " MID=$MID /* $USERNAME */";
		}
	elsif ((defined $options{'MARKETS'}) && (ref($options{'MARKETS'}) eq 'ARRAY')) {
		$pstmt .= " MKT in (";
		foreach my $market (@{$options{'MARKETS'}}) {
			$pstmt .= $udbh->quote($market).',';
			}
		chop($pstmt); #remove trailing comma
		$pstmt .= ') ';
		}
	else {
		$pstmt .= " MKT=".$udbh->quote($options{'MARKET'});
		}

	if ((defined $options{'STAGES'}) && (ref($options{'STAGES'}) eq 'ARRAY')) {
		$pstmt .= " and STAGE in (";
		foreach my $stage (@{$options{'STAGES'}}) {
			$pstmt .= $udbh->quote($stage).',';
			}
		chop($pstmt);	 #remove trailing comma
		$pstmt .= ") ";
		}

	if (defined $options{'CREATED_BEFORE_GMT'}) {
		$pstmt .= " and CREATED_GMT<".int($options{'CREATED_BEFORE_GMT'});
		}

	if (defined $options{'LIMIT'}) {
		$pstmt .= " limit 0,".int($options{'LIMIT'});
		}

	# print $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		push @result, $hashref;
		}
	$sth->finish();
	
	&DBINFO::db_user_close();	
	return(\@result);
	}


##
## EXTERNAL::fetchext_by_market_id
## PARAMETERS: USERNAME, MKT, AUCTION, KEY (almost always ID)
## RETURNS: An Array containing references to hashes that contain the following KEYS:
##   CHANNEL, BUYER_EMAIL, SKU, MKT, ZOOVY_ORDERID, MODIFIED_GMT, EMAILSENT_GMT, STAGE
##
sub fetchext_by_market_id {
	my ($USERNAME, $AUCTION, $MKT, $KEY) = @_;

	&ZOOVY::confess($USERNAME,"DEPRECATED EXTERNAL::report",justkidding=>1);
	
	if (not defined $KEY)    { $KEY    = 'ID'; }
	if (not defined $MKT) { $MKT = ''; }

	my %hash = ();
	my $dbh = &DBINFO::db_user_connect($USERNAME);

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	$USERNAME = $dbh->quote($USERNAME);

	my ($pstmt,$sth,$rv);
	if ($MKT) {
		$pstmt = "select * from EXTERNAL_ITEMS where MID=$MID and MKT_LISTINGID=? and MKT=?";
		$sth = $dbh->prepare($pstmt);
		$rv = $sth->execute($AUCTION,$MKT);
		}
	else {
		$pstmt = "select * from EXTERNAL_ITEMS where MID=$MID and MKT_LISTINGID=?";
		$sth = $dbh->prepare($pstmt);
		$rv = $sth->execute($AUCTION);
		}
	
	if (defined($rv)) {
		while (my $hash_ref = $sth->fetchrow_hashref) {
			$hash{$hash_ref->{$KEY}} = $hash_ref;
			}
		}
	$sth->finish();
	&DBINFO::db_user_close();
	
	return(\%hash);
	}

##
## EXTERNAL::fetch_external_list
## PARAMETERS: USERNAME, STAGE (A,I,V,E,R,W,C,SEARCH)
## RETURNS: An Array containing references to hashes that contain the following KEYS:
##   CHANNEL, BUYER_EMAIL, SKU, MKT, ZOOVY_ORDERID, MODIFIED_GMT, EMAILSENT_GMT, STAGE
##
sub fetch_external_list
{
	my ($USERNAME, $SORTBY, $ORDERBY, $STAGE, $SEARCHTEXT, $PAGE) = @_;
	
	if (!defined($PAGE)) { $PAGE = ''; }
	else { $PAGE = $PAGE*100; $PAGE = "limit $PAGE,100"; }
	
	# Whitelist
	if (
		($SORTBY ne 'ID') &&
		($SORTBY ne 'MODIFIED_GMT') &&
		($SORTBY ne 'PRICE') && 
		($SORTBY ne 'MKT,MKT_LISTINGID') &&
		($SORTBY ne 'CHANNEL') &&
		($SORTBY ne 'SKU') &&
		($SORTBY ne 'BUYER_EMAIL') &&
		($SORTBY ne 'STAGE')
	)
	{
		$SORTBY = 'ID';
	}
	$SORTBY = 'order by '.$SORTBY;

	if ($ORDERBY eq 'D') { $SORTBY .= ' DESC'; }
	else { $SORTBY .= ' ASC'; }
	
	my $dbh = &DBINFO::db_user_connect($USERNAME);
	
	my $extra_sql = '';
	if    ($STAGE eq 'AIV')  { $extra_sql = "and STAGE in ('A','I','V')"; }
	elsif ($STAGE eq 'AIVW') { $extra_sql = "and STAGE in ('A','I','V','W')"; }
	elsif ($STAGE eq 'AIVWH') { $extra_sql = "and STAGE in ('A','I','V','W','H')"; }
	elsif ($STAGE eq 'HP')   { $extra_sql = "and STAGE in ('H','P')"; }
	elsif ($STAGE eq 'HPC')   { $extra_sql = "and STAGE in ('H','P','C')"; }
	elsif ($STAGE eq 'HPCN')   { $extra_sql = "and STAGE in ('H','P','C','N')"; }
	elsif ($STAGE eq 'SEARCH') { 
		my $qtTEXT = $dbh->quote('%'.$SEARCHTEXT.'%');
		$extra_sql = " and ( MKT_LISTINGID like $qtTEXT or BUYER_USERID like $qtTEXT or BUYER_EMAIL like $qtTEXT or SKU like $qtTEXT or ID like $qtTEXT )";
	}
	my @ar = ();
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	
	my $pstmt = "select ID, CHANNEL, BUYER_EMAIL, SKU, MKT, ZOOVY_ORDERID, MODIFIED_GMT, CREATED_GMT, EMAILSENT_GMT, STAGE, PRICE, PROD_NAME, BUYER_USERID, MKT_LISTINGID, MKT_TRANSACTIONID ";
	$pstmt .= " from EXTERNAL_ITEMS where MID=$MID $extra_sql $SORTBY $PAGE";
	$EXTERNAL::DEBUG && print STDERR $pstmt."\n";
	
	my $sth = $dbh->prepare($pstmt);
	my $rv = $sth->execute();
	if (defined($rv)) {
		while (my $hash_ref = $sth->fetchrow_hashref) {
			push @ar, $hash_ref;
			}
		}
	$sth->finish();

	&DBINFO::db_user_close();

	return(\@ar);
	}


##
## EXTERNAL::fetchexternal_full
## TAKES: USERNAME, ID
## RETURNS: a hash reference containing all the full record (keyed by field) from the EXTERNAL_ITEMS
##
sub fetchexternal_full {
	my ($USERNAME, $ID) = @_;
	
	my @ar = ();
	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $qtUSERNAME = $dbh->quote($USERNAME);
	$ID = $dbh->quote($ID);

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	
	my $hash_ref = {};
	my $pstmt = "select * from EXTERNAL_ITEMS where USERNAME=$qtUSERNAME and MID=$MID and ID=$ID";
	
	my $sth = $dbh->prepare($pstmt);
	my $rv = $sth->execute();
	if (defined($rv)) { $hash_ref = $sth->fetchrow_hashref; }
	else { $hash_ref = undef; }
	$sth->finish();

	&DBINFO::db_user_close();
	
	return($hash_ref);
	}


###########################################################
# FETCH EXTERNAL AS HASH
# 
#sub fetch_as_hashref {
#	my ($USERNAME, $ID, $product, $extref) = @_;
#	# fetch a full external record if not provided
#
#	## DAMMIT --- CHEAP HACK!
#	$extref = undef;
#
#
#	# Provide a bunch of safe defaults
#	my $prodref = {
#		"zoovy:prod_name" => "Untitled Product [Code 901]", # Code 901? I dunno, I just made it up.
#		"zoovy:base_price" => "Unpriced",
#		"zoovy:base_weight" => 0,
#		"zoovy:quantity" => 1,
#		"zoovy:taxable" => "Y",
#		};
#
#
#	if (not defined $extref) { 
#		$extref = &fetchexternal_full($USERNAME,$ID);
#		}
#
#	# load product values (such as taxable) since they may not appear in the external item
#	if ($extref->{'SKU'} ne '') {
#		($prodref) = &ZOOVY::fetchsku_as_hashref($USERNAME,$extref->{'SKU'},$prodref);
#		}
#
#	$prodref->{'zoovy:marketid'} = $extref->{'MKT_LISTINGID'};
#	$prodref->{'zoovy:marketuser'} = $extref->{'BUYER_USERID'};
#	if ($extref->{'MKT_TRANSACTIONID'}>0) { $prodref->{'zoovy:marketid'} .= '-'.$extref->{'MKT_TRANSACTIONID'}; }
#	$prodref->{'zoovy:marketurl'} = &EXTERNAL::linkto($extref);
#	$prodref->{'zoovy:market'} = $extref->{'MKT'};
#	$prodref->{'zoovy:quantity'} = $extref->{'QTY'};
#	$prodref->{'zoovy:base_price'} = $extref->{'PRICE'};
#	if ($extref->{'PROD_NAME'} ne '') {
#		$prodref->{'zoovy:prod_name'} = $extref->{'PROD_NAME'};
#		}
#
#
#	if ($extref->{'MKT'} eq 'ebay') {
#		$prodref->{'zoovy:virtual_ship'} = "EBAY:".$extref->{'MKT_LISTINGID'};
#		}
#
#	if (&ZOOVY::prodref_has_variations($prodref)) {
#		## okay so we've got some pogs.. so we'll convert any which have been selected into hidden.
#		require POGS;
#		# my @pogs = POGS::text_to_struct($USERNAME,$prodref->{'zoovy:pogs'},1,0);
#		my @pogs2 = @{&ZOOVY::fetch_pogs($USERNAME,$prodref)};
#
#		my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($extref->{'SKU'});
#		my %SELECTED = ();
#		if (not defined $noinvopts) { $noinvopts = ''; }
#		if (not defined $invopts) { $invopts = ''; }
#
#		foreach my $set (split(/[\/:]/,$noinvopts.':'.$invopts)) {
#			next if ($set eq '');
#			$SELECTED{ substr($set,0,2) } = substr($set,2,2); 
#			}
#
#		## SANITY: %SELECTED is now a hash where key is the pog id, value is the selected option.
#		foreach my $pog (@pogs2) {
#			if (defined $SELECTED{$pog->{'id'}}) {
#				$pog->{'type'} = 'select';
#				$pog->{'default'} = $SELECTED{$pog->{'id'}};
##				$pog->{'options'} = [
##					{ v=>$SELECTED{$pog->{'id'}} },
##					];
#				my @options = ();
#				foreach my $opt (@{$pog->{'@options'}}) {
#					if ($opt->{'v'} eq $SELECTED{$pog->{'id'}}) {
#						delete $opt->{'p'};
#						#	my $metaref = &POGS::parse_meta($opt->{'m'});
#						#	delete $metaref->{'p'};
#						#	$opt->{'m'} = &POGS::encode_meta($metaref);
#						push @options, $opt;
#						}
#					}
#				$pog->{'@options'} = \@options;
#				}
#			}
#		$prodref->{'@POGS'} = \@pogs2;
#		$prodref->{'zoovy:pogs'} = &POGS::struct_to_text(&POGS::downgrade_struct(\@pogs2));
#		}
#
#	# Strip out any newlines! WHY? -bh
#	foreach my $key (keys %{$prodref}) {
#		$prodref->{$key} =~ s/\n//g;
#		}
#	return $prodref;
#	}


##
## EXTERNAL::update_stage
## parameters: USERNAME (portal or merchant), EXTERNAL_ID, NE_STAGE (optional), $ZOOVY_ORDERID (optional)
## returns: undef on failure, postive on success
sub update_stage {
	my ($USERNAME, $ID, $STAGE, $STATUS, $ZOOVY_ORDERID) = @_;
	
	my $dbh = &DBINFO::db_user_connect($USERNAME);

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	
	# Failsafe: don't update the stage to Visited if we've already got an order number.
	if ($STAGE eq 'V' || $STAGE eq 'I' || $STAGE eq 'T' || $STAGE eq 'W') {
		my $pstmt = "select STAGE,ZOOVY_ORDERID from EXTERNAL_ITEMS where ID=".$dbh->quote($ID);
		my $sth = $dbh->prepare($pstmt);
		$sth->execute();
		my ($nowstage,$orderid) = $sth->fetchrow();
		$sth->finish();

		my $bail = 0;
		if ($sth->rows()<=0) { $bail = 1; }
		elsif ($STAGE eq 'W' && $nowstage eq 'C') { $bail = 1; }		# never move something from COMPLETED to warned.
		elsif ($STAGE eq 'W') {}												# anything else can go to warned.
		elsif ($orderid ne '') { $bail = 1; }
		elsif ($STAGE eq 'I' && $nowstage eq 'V') { $bail = 1; }
		elsif ($nowstage eq 'V' && $STAGE eq 'V') { $bail = 1; }		# save some database load!
		elsif ($nowstage eq 'I' && $STAGE eq 'I') { $bail = 1; }		# this seems obvious doesn't it?
		
		# make sure we don't ever move something from C/P/H back to I/V (merchant' can't do this as it's not supported - only to A [which a customer can't do.])
		elsif (($nowstage eq 'C' || $nowstage eq 'P' || $nowstage eq 'H') && ($STAGE eq 'I')) { $bail = 1; }
		elsif (($nowstage eq 'C' || $nowstage eq 'P' || $nowstage eq 'H') && ($STAGE eq 'V')) { $bail = 1; }

		if ($bail) {
			&DBINFO::db_user_close();
			return(0);
			}
		} 
	
	if ( (defined($ZOOVY_ORDERID)) && ($ZOOVY_ORDERID ne '') ) { $ZOOVY_ORDERID = ", ZOOVY_ORDERID=".$dbh->quote($ZOOVY_ORDERID); } else { $ZOOVY_ORDERID=''; }

	my $pstmt = "select USERNAME,MKT,SKU from EXTERNAL_ITEMS where ID=".$dbh->quote($ID)." limit 0,1";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my ($dbUSERNAME,$dbMKT,$dbSKU) = $sth->fetchrow();
	$sth->finish();

	$USERNAME = lc($USERNAME);
	$dbUSERNAME = lc($dbUSERNAME);
	$dbMKT = lc($dbMKT);
	my $changed = 0;
	if ($dbUSERNAME eq $USERNAME || $dbMKT eq $USERNAME) {
		$ID = $dbh->quote($ID);
		$STAGE = $dbh->quote($STAGE);
		$USERNAME = $dbh->quote($USERNAME);
		my $pstmt = "update EXTERNAL_ITEMS set MODIFIED_GMT=".time().",STAGE=$STAGE $ZOOVY_ORDERID where ID=$ID";
		$EXTERNAL::DEBUG && print STDERR $pstmt."\n";
		$changed = $dbh->do($pstmt);	

		if ($changed>0) {
			## require INVENTORY2;
			## INVENTORY2->new($dbUSERNAME)->skuinvcmd($dbSKU,'UPDATE-RESERVE');
			# &INVENTORY::update_reserve($dbUSERNAME,$dbSKU,2);
			}
		}

	&DBINFO::db_user_close();
	return($changed);

}

################################# EVERYTHING BELOW THIS LINE IS DEPRECATED ############################################

# There are plenty of things below this line which are still needed and not replicated by anything above this line. :)  -AK





##
## EXTERNAL::nuke_external_item
## PURPOSE: duh.
## 
sub nuke_external_item {
	my ($USERNAME, $ID) = @_;
	
	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	$USERNAME = $dbh->quote($USERNAME);
	$ID = int($ID);
	my $pstmt = "delete from EXTERNAL_ITEMS where ID=$ID and MID=$MID /* USERNAME=$USERNAME */";
	my $rv = $dbh->do($pstmt);

	&DBINFO::db_user_close();

	return($rv);
	}







##
## EXTERNAL::saveexternal_full
## PURPOSE: to save changes/updates to a external item
## TAKES: a reference to a full populated hash (like the one retreived from fetchexternal_full)
## RETURNS: the ID of the record (0 on failure)
sub save {
	my ($USERNAME,$CLAIM,$ref) = @_;

	my $dbh = &DBINFO::db_user_connect($USERNAME);

	$CLAIM = int($CLAIM);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	
	my $pstmt = "update EXTERNAL_ITEMS set ";
	foreach my $k (keys %{$ref}) {
		next if ($k eq 'ID');
		next if ($k eq 'USERNAME');
		next if ($k eq 'MID');
		$pstmt .= "$k=".$dbh->quote($ref->{$k}).",";
		}
	$pstmt .= "MODIFIED_GMT=".time()." ";

	$pstmt .= " where ID=$CLAIM and MID=$MID /* $USERNAME */";
#	print STDERR $pstmt."\n";
	my ($success) = $dbh->do($pstmt);
	&DBINFO::db_user_close();

	return($success);	
	}





#sub list_customer_claims {
#	my ($USERNAME,$PRT,%options) = @_;
#
#	my @ar = ();
#	my $dbh = &DBINFO::db_user_connect($USERNAME);
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#
#	$EMAIL =~ s/[ ]+//gs;		# stupid ebay!
#	$EMAIL = $dbh->quote($EMAIL);
#
#	my $pstmt = "select ID, STAGE, MKT, MKT_LISTINGID, SKU, ZOOVY_ORDERID from EXTERNAL_ITEMS where MID=$MID and PRT=$PRT  and BUYER_EMAIL=$EMAIL";	
#	print STDERR $pstmt."\n";
#	my $sth = $dbh->prepare($pstmt);
#	my $rv = $sth->execute();
#	if (($sth->rows()==0) && (defined $BUYERUSER)) {
#		## if we don't get any matches by email then use the username.
#		## note: we do this as separate queries because it's faster to use two different lookups because of mysql indexing.
#		$sth->finish();
#		$pstmt = "select ID, STAGE, MKT, MKT_LISTINGID, SKU, ZOOVY_ORDERID from EXTERNAL_ITEMS where MID=$MID and BUYER_USERID=".$dbh->quote($BUYERUSER);
#		print $pstmt."\n";
#		$sth = $dbh->prepare($pstmt);
#		$sth->execute();
#		}
#	
#	if (defined($rv)) {
#		while (my $row = $sth->fetchrow_hashref()) {
#
#			if (
#				(not $new_only) ||
#				($row->{'STAGE'} eq 'A') ||
#				($row->{'STAGE'} eq 'I') ||
#				($row->{'STAGE'} eq 'V') ||
#				(($row->{'STAGE'} eq 'W') && ($row->{'ZOOVY_ORDERID'} eq '')) ||
#				($row->{'STAGE'} eq 'T')) 	{
#				$data->{$row->{'ID'}} = &EXTERNAL::fetch_as_hashref($USERNAME,$row->{'ID'},$row->{'SKU'},$row);
#
#				foreach my $k (keys %{$row}) {
#					$data->{$row->{'ID'}}->{$k} = $row->{$k};
#					}
#				}
#			}
#		}
#	else {
#		$data = {};
#		}
#	
#	$sth->finish();
#
#	&DBINFO::db_user_close();
#	}


###########################################################
# FETCH BUYER_EMAIL EXTERNALS
# Accepts: Merchant id and a customer email address
# Returns: A hash of hashes of external items waiting for checkout (each root level hash entry is
# keyed on external id, and has a value of a hash portion of the item)
#sub fetch_customer {
#	my ($USERNAME,$EMAIL,$new_only,$BUYERUSER) = @_;
#	if (not defined $new_only) { $new_only = 0; } #whether or not we only want waiting new items only, or all items
#	
#	my $data = {};
#	return($data);	
#	}



##
##
## returns 0 or negative number on error.
## 
##
sub create {
	my ($USERNAME, $PRT, $SKU, $dataref, %params) = @_;

	my $CLAIM = 0;	## as soon as this is not zero, we're done. (for the most part)
	
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	my %ref = ();
	$ref{'USERNAME'} = $USERNAME;
	$ref{'MID'} = $MID;
	$ref{'PRT'} = $PRT;
	$ref{'SKU'} = $SKU;
	$ref{'SKU'} =~ s/[^\w\-\:\#]+//igs;		# remove non-product valid characters

	if (defined $dataref->{'MKT_SHORTID'}) {
		## MKT_SHORTID is a shortcut, for MKT_LISTINGID-MKT_TRANSACTIONID
		($dataref->{'MKT_LISTINGID'},$dataref->{'MKT_TRANSACTIONID'}) = split(/-/,$dataref->{'MKT_SHORTID'}); 		
		}

	if (not defined $dataref->{'REF'}) {
		## ref is a unique identifier for this transaction, if it's not set, we'll use the MKT_TRANSACTIONID
		if (defined $dataref->{'MKT_TRANSACTIONID'}) {
			$dataref->{'REF'} = $dataref->{'MKT_TRANSACTIONID'};	
			}
		}

	if (defined $dataref->{'PROD_NAME'}) {
		$dataref->{'PROD_NAME'} =~ s/[\n\r]+//igs;
		$dataref->{'PROD_NAME'} =~ s/[^\w\s[:punct:]]+//gs;
		}

	if (not defined $dataref->{'STAGE'}) {
		$dataref->{'STAGE'} = 'A';
		}
	if (not defined $params{'AUTOEMAIL'}) { 
		$params{'AUTOEMAIL'} = 0;
		if ($dataref->{'MKT'} ne 'EBAY') {
			## eBay users should never receive email.
			$params{'AUTOEMAIL'} = 1; 
			}
		}

	foreach my $col (
			'BUYER_EMAIL','BUYER_USERID','BUYER_EIAS',
			'PROD_NAME','PRICE','QTY',
			'MKT','MKT_LISTINGID','MKT_TRANSACTIONID','MKT_ORDERID',
			'STAGE','ZOOVY_ORDERID','REF') {
		next if (not defined $dataref->{$col});
		$ref{$col} = $dataref->{$col};
		}


	if (not defined $ref{'MKT_LISTINGID'}) {
		if ((defined $ref{'MKT'}) && (substr($ref{'MKT'},0,2) eq 'US')) {
			## USR1, USR2, USR3, USR4, USR5, etc. do not require MKT_LISTINGID
			if (not defined $ref{'MKT_LISTINGID'}) { $ref{'MKT_LISTINGID'} = time(); }
			}
		if (not defined $ref{'MKT'}) {
			$ref{'MKT'} = '';
			$ref{'MKT_LISTINGID'} = time();
			}
		}

	##
	## some simple checking to make sure this item looks good.
	##
	if ($CLAIM!=0) {
		}
	elsif ((not defined $ref{'QTY'}) || ($ref{'QTY'}==0)) {
		warn "QTY ($ref{'QTY'}) is a required field";
		$CLAIM = -1;
		}
	elsif ((not defined $ref{'PRICE'}) || ($ref{'PRICE'}<0)) {
		warn "PRICE ($ref{'PRICE'}) is a required field";
		$CLAIM = -2;
		}
	elsif (not defined $ref{'MKT_LISTINGID'}) {
		warn "MKT_LISTINGID is a required field";
		$CLAIM = -3;
		}
	elsif (not defined $ref{'BUYER_EMAIL'}) {
		warn "BUYER_EMAIL is a required field";
		$CLAIM = -4;
		}

	## DUPLICATE CHECK
	if ($CLAIM<0) {
		## bad error already happened.
		}
	elsif (($ref{'MKT_LISTINGID'} ne '') && ($ref{'MKT_LISTINGID'} ne '0')) {
		my $pstmt = "select ID from EXTERNAL_ITEMS where MID=$MID ";
		$pstmt .= " and MKT_LISTINGID=".$udbh->quote($ref{'MKT_LISTINGID'});
		$pstmt .= " and MKT_TRANSACTIONID=".$udbh->quote($ref{'MKT_TRANSACTIONID'});
		## HMM.. not sure if I should try do this or not:
		if ($ref{'BUYER_EIAS'}) {
			## NOTE: EIAS is not set right now, so the line below will fail!
			# $pstmt .= " and BUYER_EIAS=".$udbh->quote( $dataref->{'BUYER_EIAS'} );
			}
		if ($ref{'REF'}) { 
			$pstmt .= " and REF=".$udbh->quote($ref{'REF'}); 
			}

		($CLAIM) = $udbh->selectrow_array($pstmt);
		$CLAIM = int($CLAIM);
		}

	$ref{'CREATED_GMT'} = time();
	$ref{'MODIFIED_GMT'} = $ref{'CREATED_GMT'};
	$ref{'MUSTPURCHASEBY_GMT'} = 0;
	if ($dataref->{'MUSTPURCHASEBY_GMT'}) {
		## this field is fucked up, because it's output as "MUSTPURCHASEBY" but it's created as MUSTPURCHASEBY_GMT
		$ref{'MUSTPURCHASEBY_GMT'} = sprintf("%d",$dataref->{'MUSTPURCHASEBY_GMT'});
		}

	if (int($params{'AUTOEMAIL'}) > 0) {
		## if we're going to send an email, might as well set that as well.
		$ref{'EMAILSENT_GMT'} = $ref{'CREATED_GMT'};
		}
	
	if ($CLAIM==0) {
		my ($pstmt) = &DBINFO::insert($udbh,'EXTERNAL_ITEMS',\%ref,debug=>1+2);
		# print STDERR $pstmt."\n";
		$udbh->do($pstmt);

      $pstmt = "select last_insert_id();";
      ($CLAIM) = $udbh->selectrow_array($pstmt);

		if ($CLAIM==0) {
			warn "Could not create claim!";
			$CLAIM = -100;
			}
		}


#mysql> desc EXTERNAL_ITEMS;
#+-------------------+------------------------------------------------------+------+-----+---------+----------------+
#| Field             | Type                                                 | Null | Key | Default | Extra          |
#+-------------------+------------------------------------------------------+------+-----+---------+----------------+
#| ID                | int(11)                                              | NO   | PRI | NULL    | auto_increment |
#| USERNAME          | varchar(20)                                          | NO   |     | NULL    |                |
#| MID               | int(10) unsigned                                     | NO   | MUL | 0       |                |
#| PRT               | tinyint(3) unsigned                                  | NO   |     | 0       |                |
#| CHANNEL           | int(11)                                              | NO   |     | 0       |                |
#| BUYER_EMAIL       | varchar(65)                                          | NO   |     | NULL    |                |
#| BUYER_USERID      | varchar(30)                                          | NO   |     | NULL    |                |
#| BUYER_EIAS        | varchar(64)                                          | NO   |     | NULL    |                |
#| SKU           | varchar(35)                                          | NO   |     | NULL    |                |
#| PROD_NAME         | varchar(200)                                         | NO   |     | NULL    |                |
#| PRICE             | decimal(10,2)                                        | NO   |     | 0.00    |                |
#| QTY               | smallint(5) unsigned                                 | NO   |     | 0       |                |
#| MKT               | enum('ebay','overstock','')                          | NO   | MUL | NULL    |                |
#| MKT_LISTINGID     | bigint(20) unsigned                                  | NO   |     | 0       |                |
#| MKT_TRANSACTIONID | bigint(20) unsigned                                  | NO   |     | 0       |                |
#| MKT_ORDERID       | bigint(20)                                           | NO   |     | 0       |                |
#| ZOOVY_ORDERID     | varchar(16)                                          | NO   |     | NULL    |                |
#| CREATED_GMT       | int(10) unsigned                                     | NO   |     | 0       |                |
#| MODIFIED_GMT      | int(10) unsigned                                     | NO   |     | 0       |                |
#| EMAILSENT_GMT     | int(10) unsigned                                     | NO   |     | 0       |                |
#| PAID_GMT          | int(10) unsigned                                     | NO   |     | 0       |                |
#| SHIPPED_GMT       | int(10) unsigned                                     | NO   |     | 0       |                |
#| FEEDBACK_GMT      | int(10) unsigned                                     | NO   |     | 0       |                |
#| STAGE             | enum('A','I','V','T','E','H','P','C','','G','W','N') | NO   |     | NULL    |                |
#| REF               | bigint(20) unsigned                                  | NO   |     | 0       |                |
#+-------------------+------------------------------------------------------+------+-----+---------+----------------+
#27 rows in set (0.02 sec)
#	## now do another dupe check!
#	my $ISDUP = 0;
#	if (($ref{'MKT_LISTINGID'} ne '') && ($ref{'MKT_LISTINGID'} ne '0')) {
#		my $qtmarketid = $udbh->quote($ref{'MKT_LISTINGID'});
#		$pstmt = "select ID from EXTERNAL_ITEMS where MID=$MID and BUYER_EMAIL=".$udbh->quote($dataref->{'BUYER_EMAIL'})." and MKT_LISTINGID=".$qtmarketid;
#		elsif (index($dataref->{'zoovy:marketid'},'-')>0) { $pstmt .= " and REF=".$udbh->quote($REF); } ## 6/24/05
#		$pstmt .= " order by ID";
##		print STDERR $pstmt."\n";
#		my $sth = $udbh->prepare($pstmt);
#		$sth->execute();
#		$ISDUP = 0;
#		if ($sth->rows()>1) {
#			my ($OTHERCLAIM) = $sth->fetchrow();
#			## first claim one always wins! (this is to prevent a situation where they both delete eachother in a leapfrog race condition)
#			if ($OTHERCLAIM == $RETURN_ID) {
#				## we are winner!
#				$ISDUP = 0;
#				}
#			else {
#				## we are the loser! commit suicide
#				$pstmt = "delete from EXTERNAL_ITEMS where ID=".$udbh->quote($RETURN_ID)." limit 1";
##				print STDERR $pstmt."\n";
#				$udbh->do($pstmt);
#				$RETURN_ID = $OTHERCLAIM;
#				$ISDUP = 1;
#				}
#			}
#		$sth->finish();
#		}
#

	if ($CLAIM>0) {
#		if ($ref{'CHANNEL'}>0) {
#			require CHANNEL;
#			my $cdbh = &CHANNEL::db_channel_connect();
#			my ($CHANNELTB) = &CHANNEL::resolve_merchant_tb($ref{'USERNAME'},$MID);
#			my $pstmt = "update $CHANNELTB set QTY_SOLD=QTY_SOLD+".int($ref{'QTY'})." where ID=".int($ref{'CHANNEL'})." limit 1";
##			print STDERR $pstmt."\n";
#			$cdbh->do($pstmt);
#			&CHANNEL::db_channel_close();
#			}

#		if (int($params{'AUTOEMAIL'}) > 0) {
#			require SITE;
#			require SITE::EMAILS;
#			my ($SITE) = SITE->new($USERNAME,'PRT'=>$PRT);
#			my ($se) = SITE::EMAILS->new($USERNAME,'*SITE'=>$SITE);
#			my $MSGID = (defined $params{'EMAIL_MSGID'})?$params{'EMAIL_MSGID'}:'ECREATE';
#			$se->sendmail($MSGID,CLAIM=>$CLAIM);
#			$se = undef;
#			}

		## if we have inventory enabled for this product, then update the reserved count
		## INVENTORY2->new($USERNAME)->skuinvcmd($SKU,'UPDATE-RESERVE');
		# &INVENTORY::update_reserve($USERNAME,$SKU,2);
		} 

	&DBINFO::db_user_close();	
	return($CLAIM);
	}


##
## EXTERNAL::createexternal_full
## TAKES: a reference to a full populated hash (like the one retreived from fetchexternal_full)
## RETURNS: ID of the record (undef on failure)
sub createexternal_full {
	warn "do not call createexternal_full";
	die();
	}


###########################################################
# FETCH BUYER_EMAIL CLAIMS
# Accepts: Merchant id and a customer email address
# Returns: A hash of hashes of external items waiting for checkout (each root level hash entry is
# keyed on external id
sub fetch_customer_claims {
	my ($USERNAME,$EMAIL,$new_only,$BUYERUSER) = @_;
	if (not defined $new_only) { $new_only = 0; } 
	
	my @stids = ();
	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	$EMAIL =~ s/[ ]+//gs;		# stupid ebay!

	my $pstmt = '';
	my $sth = undef;

	$pstmt = "select SKU, ID, STAGE from EXTERNAL_ITEMS where MID=$MID and BUYER_EMAIL=".$dbh->quote($EMAIL);;	
	$sth = $dbh->prepare($pstmt);
	my $rv = $sth->execute();

	if (($sth->rows()==0) && (defined $BUYERUSER)) {
		## if we don't get any matches by email then use the username.
		## note: we do this as separate queries because it's faster to use two different lookups because of mysql indexing.
		$sth->finish();
		$pstmt = "select SKU, ID, STAGE from EXTERNAL_ITEMS where MID=$MID and BUYER_USERID=".$dbh->quote($BUYERUSER);
		$sth = $dbh->prepare($pstmt);
		$sth->execute();
		}
	
	while (my $row = $sth->fetchrow_hashref()) {

			next if ( ($new_only) &&
				(($row->{'STAGE'} eq 'C') ||
				($row->{'STAGE'} eq 'H') ||		## hmm.. don't let the customer re-purchase 'H'(hold) items
				($row->{'STAGE'} eq 'P') ||
				(($row->{'STAGE'} eq 'W') && ($row->{'ZOOVY_ORDERID'} ne '')) ) );
			push @stids, $row->{'ID'}.'*'.$row->{'SKU'};
			}
	
	$sth->finish();

	&DBINFO::db_user_close();
	return(\@stids);
	}




###########################################################
# FIND_CLAIMS
# Accepts: Merchant id and a customer email address
# Returns: an array of the number of items waiting to be checked out.
sub find_claims {
	my ($USERNAME,$EMAIL) = @_;
	
	my $dbh = &DBINFO::db_user_connect($USERNAME);

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	$EMAIL = $dbh->quote($EMAIL);
	
	my @RESULT = ();

	my $count = 0;
	my $pstmt = "select ID from EXTERNAL_ITEMS where MID=$MID and BUYER_EMAIL=$EMAIL and STAGE in ('A','I','V','T','W')";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	while ( my ($CLAIM) = $sth->fetchrow() ) {
		push @RESULT, $CLAIM;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(@RESULT);
	
}

###########################################################
# EXTERNAL COUNT
# Accepts: Merchant id and a customer email address
# Returns: The number of external items waiting for that customer to process
sub external_count {
	my ($USERNAME,$EMAIL) = @_;
	return(scalar(&EXTERNAL::find_claims($USERNAME,$EMAIL)));
	}



###########################################################
# GET ITEM
# Accepts: Merchant id and product id and new only
#		(whether we should return any external item, or only new ones that haven't been purchased)
# Returns: A reference to a hash with the attributes of either an external item or product,
#		depending on the product code (if there's a star in it, its an external item)
#		undef if an external item cannot be retrieved. 
#
#sub get_item {
#	my ($merchant_id, $sku, $new_only) = @_;
#	# $EXTERNAL::DEBUG && print STDERR "EXTERNAL::get_item $merchant_id, $sku, $new_only\n";
#
#	# new only causes this function to only return items which can be purchased, otherwise it returns
#	# an undef. (was zero, but that seems stupid)
#	if (not defined $new_only) { $new_only = 0; }
#
#	# 0*SKUS emulates an external item, in that it allows the cart to think it got an external item
#	# but in reality, it's just a product.
#	if ($sku =~ /^0\*/) { $sku = substr($sku,2); }
#
#	if ($sku eq '') { return(undef); }
#
#	## do we have a claim?
#	if (index($sku,'*') != -1) {
#		my $external_id;
#		($external_id,undef) = split(/\*/,$sku);
#
#		if ($new_only) {
#			## what does New Only do? It seems that it returns
#			my $extref = &EXTERNAL::fetchexternal_full($merchant_id,$external_id);
#			if (
#				($extref->{'STAGE'} eq 'A') ||
#				($extref->{'STAGE'} eq 'I') ||
#				($extref->{'STAGE'} eq 'V') ||
#				($extref->{'STAGE'} eq 'W') ||
#				($extref->{'STAGE'} eq 'T')) {
#				return &EXTERNAL::fetch_as_hashref($merchant_id, $external_id, $extref->{'SKU'}, $extref);
#				}
#			return undef;
#			}
#		else {
#			# print STDERR "$merchant_id $external_id\n";
#			return &EXTERNAL::fetch_as_hashref($merchant_id, $external_id);
#			}
#		}
#
#	## failsafe
#	# print STDERR "CALLING &ZOOVY::fetchsku_as_hashref($merchant_id, $sku);\n";	
#	my $prod = &ZOOVY::fetchsku_as_hashref($merchant_id, $sku);
#	return $prod;
#	}

1;
