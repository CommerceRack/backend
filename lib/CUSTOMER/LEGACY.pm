package CUSTOMER::LEGACY;

################################################################################
# sub set_likes_spam
# purpose: a quick an dirty way to set the likes spam flag
# paramters: merchant, email, 0 = off, 1 = on
# 
#sub set_likes_spam {
#	my ($USERNAME, $EMAIL, $STATUS, $IP) = @_;
#
#	# make sure status is a number.
#	$STATUS+=0;
#	
##	print STDERR "set_likes_spam USERNAME=$USERNAME EMAIL=$EMAIL STATUS=$STATUS\n";
#	
#	my $ipint = &CUSTOMER::smart_ip_int($IP, $ENV{'REMOTE_ADDR'});
#
#	my $odbh = &DBINFO::db_user_connect($USERNAME);
#	if (!defined($odbh)) { return(0); }
#
#	my $qtUSERNAME = $odbh->quote($USERNAME);
#	my $qtEMAIL = $odbh->quote($EMAIL);
#	my $qtSTATUS = $odbh->quote($STATUS);
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
#	
#	my $pstmt = "update $CUSTOMERTB set LIKES_SPAM=$STATUS, IP=$ipint, MODIFIED=now() where USERNAME=$qtUSERNAME and MID=$MID and EMAIL=$qtEMAIL";
##	print STDERR $pstmt."\n";
#	$odbh->do($pstmt);
#
#	&DBINFO::db_user_close();
#	return(1);
#	}


##
## creates a new customer
##
##  BILLREF should contain the following keys (uses ORDER keys)
##	 	bill_phone
##		bill_firstname
##		bill_middlename
##		bill_zip
##		bill_lastname
##		bill_address1
##	   bill_address2
##	   bill_email
##    bill_province
##    bill_country
## 
## HINTNUM should be pulled from fetch_password_hints
## HINTANS should be the answer trucated at 10 characters.
##
##	ORIGIN
##		0 = unknown
##		1 = website checkout
##
## LIKES_SPAM should be a number, 0 means no, 1 means yes.
## returns ($code, $message) possible values:
## 	0 success (password returned)
##		1 user exists	
##		2 no email specified. (nothing returned)
##
#sub new_customer {
#	my ($USERNAME, $EMAIL, $PASSWORD, $LIKESPAM, $HINTNUM, $HINTANS, $ORDERREF, $IP, $ORIGIN, $AOLSN) = @_;
#	if ($EMAIL eq "") { return (2,''); }
#
#	# intialize default return values
#	my $error = 0; 
#	my $errmsg = "";
#	# need the database handle to do the encoding properly!
#	my $odbh = &DBINFO::db_user_connect($USERNAME);
#
#	# since everything we are working with needs to be database friendly,
#	# lets just encode everything
#	my $qtUSERNAME = $odbh->quote($USERNAME);
#	my $qtEMAIL = $odbh->quote($EMAIL);
#	
#	if (not defined $AOLSN) { $AOLSN = ''; }
#	my $qtAOLSN = $odbh->quote($AOLSN);
#
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
#
#	$IP = $odbh->quote(&CUSTOMER::smart_ip_int($IP, $ORDERREF->{'ip_address'}, $ENV{'REMOTE_ADDR'}));
#
#	if (not defined $ORIGIN) { $ORIGIN = 0; }
#	$ORIGIN = $odbh->quote($ORIGIN);
#	
#	if ( (not defined($PASSWORD)) || ($PASSWORD eq '') ) { $PASSWORD = &ZTOOLKIT::make_password(); }
#	$PASSWORD = $odbh->quote($PASSWORD);
#
#	my $FULLNAME = '';
#	$HINTNUM = $odbh->quote($HINTNUM);
#	$HINTANS = $odbh->quote($HINTANS);
#
#	if (defined($ORDERREF->{'bill_fullname'})) {
#		$FULLNAME = $ORDERREF->{'bill_fullname'};
#		} 
#	else {
#		$FULLNAME = $ORDERREF->{'bill_firstname'}." ".$ORDERREF->{'bill_lastname'};
#		}
#	
#	if (!defined($FULLNAME)) { $FULLNAME = ''; }
#	# print STDERR "FULLNAME: $FULLNAME\n";
#	$FULLNAME = $odbh->quote($FULLNAME);
#
#	my $pstmt = "select count(*) from $CUSTOMERTB where EMAIL=$qtEMAIL and MID=$MID and USERNAME=$qtUSERNAME";
#	if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }
#	my $sth = $odbh->prepare($pstmt);
#	my $rv =  $sth->execute;
##	my ($count) = $sth->fetchrow();
#	$sth->finish;
#
#	if ($count>0) {
#		$error = 1;
#		$errmsg = "user $qtUSERNAME/$qtEMAIL already exists";
#		} 
#	else {     
#		$LIKESPAM += 0;#
#
#		my $parent = 0;
#		$pstmt = "insert into CUSTOMER_COUNTER (ID,USERNAME) values(0,$qtUSERNAME)";
#		$odbh->do($pstmt);
#
#		$pstmt = "select last_insert_id()";
#		$sth = $odbh->prepare($pstmt);
#		$sth->execute();
#		($parent) =	$sth->fetchrow();
#		$sth->finish();
#
#		$pstmt = "insert into $CUSTOMERTB (ID,MID,USERNAME,EMAIL,PASSWORD,FULLNAME,MODIFIED,DEFAULT_SHIP_ADDRESS,DEFAULT_BILL_ADDRESS,LIKES_SPAM,HINT_NUM,HINT_ANSWER,CREATED,IP,ORIGIN,AOLSN) values ($parent,$MID,$qtUSERNAME,$qtEMAIL,$PASSWORD,$FULLNAME,now(),'DEFAULT','DEFAULT',$LIKESPAM,$HINTNUM,$HINTANS,now(),$IP,$ORIGIN,$qtAOLSN)";
#		if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }
#		$rv = $odbh->do($pstmt);
#		
#		# grab all the bill_keys and save them to CUSTOMER_BILL
#		my %billhash = ();
#		my %shiphash = ();
#		my $k;
#		foreach $k (keys %{$ORDERREF}) {
#			if ($k =~ /^bill_/i) { $billhash{$k} = ${$ORDERREF}{$k}; }
#			if ($k =~ /^card/i) { $billhash{$k} = ${$ORDERREF}{$k}; }
#			if ($k =~ /^pay/i) { $billhash{$k} = ${$ORDERREF}{$k}; }
#			if ($k =~ /^ship_/i) { $shiphash{$k} = ${$ORDERREF}{$k}; }
#			}
#		# at this point, billhash is filled with billing info, and shiphash is filled with shipping info.
#		if ($parent) {
#			# now lets save the billhash
#			$billhash{'_IS_DEFAULT'}++;
#			$billhash{'_CODE'} = 'DEFAULT';
#			&CUSTOMER::store_addr($USERNAME,$parent,'BILL',\%billhash);
##			my $c = $odbh->quote(&CUSTOMER::freezehash(\%billhash));	
##			my $CUSTOMERBILLTB = &CUSTOMER::resolve_customer_bill_tb($USERNAME,$MID);
##			$pstmt = "insert into $CUSTOMERBILLTB (ID,USERNAME,MID,PARENT,CODE,INFO) values (0,$qtUSERNAME,$MID,$parent,'DEFAULT',$c)";
##			if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }
##			$odbh->do($pstmt);
#			
#			
#			$shiphash{'_IS_DEFAULT'}++;
#			$shiphash{'_CODE'} = 'DEFAULT';
#			delete $shiphash{'ship_email'};
#			&CUSTOMER::store_addr($USERNAME,$parent,'SHIP',\%shiphash);
##			$c = $odbh->quote(&CUSTOMER::freezehash(\%shiphash));
##			my $CUSTOMERSHIPTB = &CUSTOMER::resolve_customer_ship_tb($USERNAME,$MID);
##			$pstmt = "insert into $CUSTOMERSHIPTB (ID,USERNAME,MID,PARENT,CODE,INFO) values (0,$qtUSERNAME,$MID,$parent,'DEFAULT',$c)";
##			if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }
##			$odbh->do($pstmt);
#			}
#		else {
#			if ($CUSTOMER::DEBUG) { print STDERR "Could not obtain parent id!\n"; }
#			}
#		if ($CUSTOMER::DEBUG) { print STDERR "Customer $qtUSERNAME/$qtEMAIL error=[$error] errmsg=[$errmsg]\n"; }
#		}
#	&DBINFO::db_user_close();
#
#	return($error,$errmsg);  
#}
#


# Does the same as above but doesn't create the customer billing/shipping information and assumes they want spam
#sub new_subscriber {
#	my ($USERNAME, $EMAIL, $FULLNAME, $PASSWORD, $IP, $ORIGIN) = @_;
#	if ((not defined($PASSWORD)) || ($PASSWORD eq '')) {
#		$PASSWORD = &ZTOOLKIT::make_password();
#	}
#	if (($EMAIL eq '') || ($FULLNAME eq ''))  {
#		return (1,'Internal error: email and full name must be provided to CUSTOMER::new_subscriber');
#	}
#	# intialize default return values
#	my $error = 0; 
#	my $errmsg = '';
#	# need the database handle to do the encoding properly!
#	my $odbh = &DBINFO::db_user_connect($USERNAME);
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#
#	# since everything we are working with needs to be database friendly,
#	# lets just encode everything
#	my $qtUSERNAME = $odbh->quote($USERNAME);
#	my $qtEMAIL = $odbh->quote($EMAIL);
#	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
#
#	$IP = $odbh->quote(&CUSTOMER::smart_ip_int($IP, $ENV{'REMOTE_ADDR'}));
#
#	if (not defined $ORIGIN) { $ORIGIN = 0; }
#	$ORIGIN = $odbh->quote($ORIGIN);
#	
#	my $pstmt = "select count(*) from $CUSTOMERTB where EMAIL=$qtEMAIL and MID=$MID and USERNAME=$qtUSERNAME";
#	if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }
#	my $sth = $odbh->prepare($pstmt);
#	my $rv =  $sth->execute;
#	my ($count) = $sth->fetchrow();
#	$sth->finish;
#	if ($count>0) {
#		return(2,"User $EMAIL already exists");
#	} 
#	else {     
#		my $parent = 0;
#		$pstmt = "insert into CUSTOMER_COUNTER (ID,USERNAME) values(0,$qtUSERNAME)";
#		$odbh->do($pstmt);
#
#		$pstmt = "select last_insert_id()";
#		$sth = $odbh->prepare($pstmt);
#		$sth->execute();
#		($parent) =	$sth->fetchrow();
#		$sth->finish();
#
#		if ($CUSTOMER::DEBUG) { print STDERR "new_subscriber: Creating new user\n"; }
#		$PASSWORD = $odbh->quote($PASSWORD);
#		$FULLNAME = $odbh->quote($FULLNAME);
#		$pstmt = "insert into $CUSTOMERTB (ID,MID,USERNAME,EMAIL,PASSWORD,FULLNAME,MODIFIED,DEFAULT_SHIP_ADDRESS,".
#					"DEFAULT_BILL_ADDRESS,LIKES_SPAM,HINT_NUM,HINT_ANSWER,CREATED,IP,ORIGIN) ".
#					"values ($parent,$MID,$qtUSERNAME,$qtEMAIL,$PASSWORD,$FULLNAME,now(),NULL,NULL,1,NULL,NULL,now(),$IP,$ORIGIN)";
#		if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }
#		$rv = $odbh->do($pstmt);
#		if ($CUSTOMER::DEBUG) { print STDERR "new_subscriber: New user created\n"; }
#		unless (defined($rv)) {
#			return(3,"Could not create user $EMAIL for unknown reason");
#		}
#	}
#	&DBINFO::db_user_close();
#	return($error,$errmsg);  
#}

##
## you send: merchant and email address, reference to a hash we can fill with general info, and
## a reference to a hash for billing info, and a reference to a hash for shippping info.
##
## you get: 0 on success (but the hashes [or is it hashii?] are fuLL!)
##
#sub fetchcustomer
#{
#  my ($USERNAME, $EMAIL, $INFOREF) = @_;
#
#	if (ref($INFOREF) ne "HASH") { 
##		print STDERR "CUSTOMER::fetchcustomer not getting passed a reference to a hash!\n";
#		return 0;
#	}
#	my $odbh = &DBINFO::db_user_connect($USERNAME);
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#	my $qtUSERNAME = $odbh->quote($USERNAME);
#	my $qtEMAIL = $odbh->quote($EMAIL);
#	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
#
#
#	my $pstmt = "select ID, FULLNAME, PASSWORD, unix_timestamp(MODIFIED), DEFAULT_SHIP_ADDRESS, DEFAULT_BILL_ADDRESS, ";
#	$pstmt .= " LIKES_SPAM, HINT_NUM, HINT_ANSWER, unix_timestamp(CREATED), IP, ORIGIN from $CUSTOMERTB where MID=$MID and USERNAME=$qtUSERNAME and EMAIL=$qtEMAIL";
##   print STDERR $pstmt."\n";
#	
#	my $sth = $odbh->prepare($pstmt);
#	my $rv = $sth->execute();
#	my $result;
#	if (defined($rv) && $sth->rows>0) {
#		(
#			$INFOREF->{"ID"},
#			$INFOREF->{"FULLNAME"},
#			$INFOREF->{"PASSWORD"},
#			$INFOREF->{"MODIFIED"},
#			$INFOREF->{"DEFAULT_BILL"},
#			$INFOREF->{"DEFAULT_SHIP"},
#			$INFOREF->{"LIKESPAM"},
#			$INFOREF->{"HINTNUM"},
#			$INFOREF->{"HINTANS"},
#			$INFOREF->{'CREATED'},
#			$INFOREF->{'IP'},
#			$INFOREF->{'ORIGIN'}	
#		) = $sth->fetchrow();
#		$INFOREF->{'IP_ADDR'} = &CUSTOMER::int_to_ip($INFOREF->{'IP'});
#		# tip: dont' listen to rob zombie while coding. 
#		$result = 1;
#	}
#	else {
#		$result = 0;
#	}
#	$sth->finish;
#	&DBINFO::db_user_close();
#	return($result);
#}
#

##
## 		NOTE: do *not* update screen name with this call - use AOLSN::associate call -- BUT only after you've verified 
##					that the email is valid (e.g. they are already authenticated)
##					Otherwise a person going through checkout the second time would be able to associate
##					an SN that they randomly created --- which would be *very* bad (easily hacked) - BH 9/14/04
##
## 		NOTE: you should *always* call this with at least 
##       	$USERNAME, $EMAIL so we can bump the modified timestamp.
##				all other parameters are optional, null values will not be set.
##
##			DEFAULT_BILL_CODE and DEFAULT_SHIP_CODE are the names of the default (eg: last used)
##			shipping and billing preferences.
## returns: undef on error
##
#sub update_customer {
#	my ($USERNAME, $EMAIL, $PASSWORD, $DEFAULT_BILL_CODE, $DEFAULT_SHIP_CODE, $LIKESPAM, $FULLNAME, $IP, $ORIGIN) = @_;
#
#	my $odbh = &DBINFO::db_user_connect($USERNAME);
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#
#	# do some simple address correction
#	$EMAIL =~ s/[^\w\+\-\.\@\!\_]+//g;
#
#	my $qtEMAIL = $odbh->quote($EMAIL);
#	my $qtUSERNAME = $odbh->quote($USERNAME);
#	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
#
#	if (defined $PASSWORD) { $PASSWORD = "PASSWORD=".$odbh->quote($PASSWORD).","; } else { $PASSWORD = '' }
#	if (defined $DEFAULT_SHIP_CODE) { $DEFAULT_SHIP_CODE = "DEFAULT_SHIP_ADDRESS=".$odbh->quote($DEFAULT_SHIP_CODE).","; } else { $DEFAULT_SHIP_CODE = '' }
#	if (defined $DEFAULT_BILL_CODE) { $DEFAULT_BILL_CODE = "DEFAULT_BILL_ADDRESS=".$odbh->quote($DEFAULT_BILL_CODE).","; } else { $DEFAULT_BILL_CODE = '' }
#   if (defined $FULLNAME) { $FULLNAME = "FULLNAME=".$odbh->quote($FULLNAME).","; } else { $FULLNAME = '' }
#	if (defined $LIKESPAM) { $LIKESPAM="LIKES_SPAM=".$odbh->quote($LIKESPAM).","; } else { $LIKESPAM = '' }
#	if (defined $IP) { $IP = "IP=".$odbh->quote(&CUSTOMER::smart_ip_int($IP)).","; } else { $IP = ''; }
#	if (defined $ORIGIN) { $ORIGIN = "ORIGIN=".$odbh->quote($ORIGIN).","; } else { $ORIGIN = ''; }
#
#	my $pstmt = "update $CUSTOMERTB set $PASSWORD $DEFAULT_SHIP_CODE $DEFAULT_BILL_CODE $FULLNAME $LIKESPAM $IP $ORIGIN MODIFIED=now() where USERNAME=$qtUSERNAME and MID=$MID and EMAIL=$qtEMAIL";
##	print STDERR $pstmt . "\n";
#
#	my $rv = $odbh->do($pstmt);
#
#	&DBINFO::db_user_close();
#   return($rv);	
#   }
#

#sub change_password {
#	my ($USERNAME, $EMAIL, $PASSWORD) = @_;
#
#	if ((not defined($PASSWORD)) && (not $PASSWORD)) { return; }
#	
#	my $odbh = &DBINFO::db_user_connect($USERNAME);
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#	$EMAIL =~ s/[^\w\+\-\.\@\!\_]+//g;
#	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
#
#
#	my $qtEMAIL = $odbh->quote($EMAIL);
#	my $qtUSERNAME = $odbh->quote($USERNAME);
#	$PASSWORD = $odbh->quote($PASSWORD);
#
#	my $pstmt = "update $CUSTOMERTB set PASSWORD=$PASSWORD, MODIFIED=now() where USERNAME=$qtUSERNAME and MID=$MID and EMAIL=$qtEMAIL";
#	my $rv = $odbh->do($pstmt);
#
#	&DBINFO::db_user_close();
#   return($rv);	
#}

################################################################################
# returns a record ID if the customer exists
# 0 if user does not exist
sub customer_exists {
	my ($USERNAME, $EMAIL) = @_;

	if ( (not defined $USERNAME) || ($USERNAME eq '') ) { return(undef); }
	if ( (not defined $EMAIL) || ($EMAIL eq '') ) { return(undef); }

	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my $result = 0;

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);

	my $qtUSERNAME = $odbh->quote($USERNAME);
	my $qtEMAIL = $odbh->quote($EMAIL);

	my $pstmt = "select ID from $CUSTOMERTB where MID=$MID and USERNAME=$qtUSERNAME and EMAIL=$qtEMAIL";
	my $sth = $odbh->prepare($pstmt);
	my $rv =  $sth->execute;

	if (defined($rv)) {
		if ($sth->rows > 0) {
			$result = $sth->fetchrow(); # Return the customer_id
			}
		}

	$sth->finish;
	&DBINFO::db_user_close();

	return $result;
	}

################################################################################
# returns a record ID (used for all subsequent functions) or 
# 0 if user does not exist
# -1 if the authentication fails.
# -2 if a database error occurs
#sub authenticate_customer {
#	my ($USERNAME, $EMAIL, $PASSWORD) = @_;
#
#	if ($EMAIL eq "") { return(0); }
#	my $odbh = &DBINFO::db_user_connect($USERNAME);
#	my $result = 0;
#
#	my $qtUSERNAME = $odbh->quote($USERNAME);
#	my $qtEMAIL = $odbh->quote($EMAIL);
#
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
#
#	my $pstmt = "select ID, PASSWORD from $CUSTOMERTB where USERNAME=$qtUSERNAME and MID=$MID and EMAIL=$qtEMAIL";
##   print STDERR $pstmt."\n";
#	my $sth = $odbh->prepare($pstmt);
#	my $rv =  $sth->execute;
#
#	if (defined($rv))
#		{
#		if ($sth->rows>0)
#			{
#			my ($recid,$realpass) = $sth->fetchrow();
#			if (uc($realpass) eq uc($PASSWORD))
#				{
#				$result = $recid; # success!
#				} else {
#				$result = -1;   # authentication failure
#				}
#			} else {
#			# 0 rows returned means the user does not exist.
#			$result = 0;
#			}
#		} else {
#		$result = -2;
#		}
#	$sth->finish;
#
#	&DBINFO::db_user_close();
#  return($result);
#}


#sub get_password_by_hint {
#	my ($USERNAME, $EMAIL, $ANSWER) = @_;
#
#	my (%customer);
#	&CUSTOMER::fetchcustomer($USERNAME,$EMAIL,\%customer) || return 0;
#
#	if (&ZTOOLKIT::wordstrip(uc($ANSWER)) eq &ZTOOLKIT::wordstrip(uc($customer{'HINTANS'}))) {
#		my $odbh = &DBINFO::db_user_connect($USERNAME);
#		my $qtUSERNAME = $odbh->quote($USERNAME);
#		my $qtEMAIL = $odbh->quote($EMAIL);
#		my $MID = &ZOOVY::resolve_mid($USERNAME);
#		my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
#
#		my $pstmt = "select PASSWORD from $CUSTOMERTB where MID=$MID and USERNAME=$qtUSERNAME and EMAIL=$qtEMAIL";
#		my $sth = $odbh->prepare($pstmt);
#		my $rv =  $sth->execute;
#		my $PASSWORD;
#		if (defined($rv)) { $PASSWORD = $sth->fetchrow(); } 
#		else { $PASSWORD = 'ERROR'; }
#		$sth->finish;
#		&DBINFO::db_user_close();
#		return $PASSWORD;
#		}
#	else {
#		return 0;
#		}
#	}


1;
