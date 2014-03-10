package GIFTCARD;

use strict;
use lib "/backend/lib";
require ZOOVY;

sub TO_JSON {
	my ($self) = @_;
	my %ref = ();
	foreach my $k (keys %{$self}) { $ref{$k} = $self->{$k}; }
	return(\%ref);
	}

sub new {
	my ($class, $code, %options) = @_;
	my $self = \%options;
	$self->{'code'} = $code;
	bless $self, 'GIFTCARD';
	return($self);
	}


##
## Features requested:
## *FR* 340726 - gourmet - wants more search, sort, and an archive functionality
##


#
# three types of giftcards:
#	cash equivalent
#	promotional
#	exclusive
#

##
## lets talk about gift cards, ..
##
##
#mysql> desc GIFTCARDS;
#+-------------+----------------------+------+-----+---------+----------------+
#| Field       | Type                 | Null | Key | Default | Extra          |
#+-------------+----------------------+------+-----+---------+----------------+
#| ID          | int(11)              | NO   | PRI | NULL    | auto_increment |
#| MID         | int(10) unsigned     | NO   | MUL | 0       |                |
#| USERNAME    | varchar(20)          | NO   |     | NULL    |                |
#| CODE        | varchar(16)          | NO   |     | NULL    |                |
#| CREATED_GMT | int(10) unsigned     | NO   |     | 0       |                |
#| CREATED_BY  | varchar(15)          | NO   |     | NULL    |                |
#| EXPIRES_GMT | int(10) unsigned     | NO   |     | 0       |                |
#| LAST_ORDER  | varchar(10)          | NO   |     | NULL    |                |
#| CID         | int(11)              | NO   |     | 0       |                |
#| NOTE        | varchar(128)         | NO   |     | NULL    |                |
#| BALANCE     | decimal(10,2)        | NO   |     | 0.00    |                |
#| TXNCNT    | smallint(5) unsigned | NO   |     | 0       |                |
#+-------------+----------------------+------+-----+---------+----------------+
#12 rows in set (0.02 sec)
##
##

##
## function: remap_giftcard_prt
##
## the "bob" (zephyrsports) hack --
##
sub remap_giftcard_prt {
	my ($USERNAME,$PRT) = @_;

	if ($PRT>0) {
		my ($prtinfo) = &ZOOVY::fetchprt($USERNAME,$PRT);
#		use Data::Dumper; print Dumper($prtinfo);
		if (defined $prtinfo->{'p_giftcards'}) {
			$PRT = int($prtinfo->{'p_giftcards'});
			}
		}
	return(int($PRT));
	}



##
## returns an array group by SERIES with various statistics about the series.
##
sub list_series {
	my ($USERNAME) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select SRC_SERIES,count(*) as COUNT,sum(BALANCE) as BALANCE, sum(TXNCNT) as TXNCNT, ceil(CREATED_GMT) as CREATED_GMT from GIFTCARDS where MID=$MID /* $USERNAME */ and IS_DELETED=0 group by SRC_SERIES;";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my @SERIES = ();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		push @SERIES, $hashref;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@SERIES);
	}


##
## returns an obfuscated version of the giftcard codes
##
sub obfuscateCode {
	my ($CODE,$STYLE) = @_;

	if ((not defined $STYLE) || ($STYLE==0)) { $STYLE = 2; }

	if ($STYLE == 2) {
		$CODE = substr($CODE,0,4).'-xxxx-xxxx-'.substr($CODE,-4);
		}
	elsif ($STYLE==-1) {
		$CODE = sprintf("%s-%s-%s-%s",substr($CODE,0,4),substr($CODE,4,4),substr($CODE,8,4),substr($CODE,12,4));
		}
	elsif ($STYLE==1) {
		$CODE = substr($CODE,0,4).'..'.substr($CODE,-4);
		}
	elsif ($STYLE == 0) {
		## LEAVE IT ALONE!
		}
	else {
		warn "UNKNOWN GIFTCARD OBFUSCATION STYLE [$STYLE] REQUESTED\n";
		}

	return($CODE);
	}


##
## translates a GCID to a code 
##		(useful when we don't let the business owner see the card)
##
sub resolve_CODE {
	my ($USERNAME,$ID) = @_;

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my $pstmt = "select CODE from GIFTCARDS where MID=$MID /* $USERNAME */ and ID=".int($ID);
	print STDERR $pstmt."\n";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my ($CODE) = $sth->fetchrow();
	$sth->finish();

	&DBINFO::db_user_close();
	return($CODE);	
	}


##
##
##
sub resolve_GCID {
	my ($USERNAME,$CODE) = @_;

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my $pstmt = "select ID from GIFTCARDS where MID=$MID /* $USERNAME */ and CODE=".int($CODE);
	print STDERR $pstmt."\n";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my ($GCID) = $sth->fetchrow();
	$sth->finish();

	&DBINFO::db_user_close();
	return($GCID);	
	}


##
## returns a hashref of card info, or undefined.
##	
##	e.g. lookup($USENRAME,GCID=>1234);
##
sub lookup {
	my ($USERNAME,%options) = @_;

	my $result = undef;

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my $pstmt = '';
	if (defined $options{'GCID'}) {
		$pstmt = "select * from GIFTCARDS where MID=$MID /* $USERNAME */ and ID=".int($options{'GCID'});
		}
	elsif (defined $options{'CODE'}) {
		$options{'CODE'} =~ s/-//g;
		$pstmt = "select * from GIFTCARDS where MID=$MID /* $USERNAME */ and CODE=".$dbh->quote($options{'CODE'});
		}

	if (defined $options{'PRT'}) {
		my $PRT = int($options{'PRT'});
		$PRT = &GIFTCARD::remap_giftcard_prt($USERNAME,$PRT);
		$pstmt .= sprintf(" and PRT=%d",$PRT);
		}

	print STDERR $pstmt."\n";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	if ($sth->rows()>0) {
		($result) = $sth->fetchrow_hashref();

		$result->{'GCID'} = $result->{'ID'};
		$result->{'CARDTYPE'} = 1;
		$result->{'CARDTYPE'} += ($result->{'COMBINABLE'})?2:0;
		$result->{'CARDTYPE'} += ($result->{'CASHEQUIV'})?4:0;
		}
	$sth->finish();

	&DBINFO::db_user_close();



	return($result);
	}



##
## converts the response of a GIFTCARD::lookup to a payment (suitable for PAYMENTQ or @PAYMENTS)
##		obfuscate = 1|0
##
##	GC is teh giftcard code (may be obfuscated depending on obfuscate value)
## GI is the giftacard id (required)
## GP == G12
##		G = is a checksum (so we know it was set properly) and version
##		1 = is a "Y"|"N" combinable
##		2 = is a "Y"|"N" for cash equiv
##
#sub giftcard_to_payment {
#	my ($GCREF, %options) = @_;
#
#	}






##
## valid update options are:
##		BALANCE
##		NOTE
##		EXPIRES_GMT
##		LAST_ORDER
##		CID		
##		CARDTYPE
##			0 = do not update
##			1 = exclusive (combine=0,cashequiv=0)
##			3 = promo (combine=1,cashequiv=0)
##			7 = cash (combine=1,cashequiv=1)
##
sub update {
	my ($USERNAME,$GCID,%options) = @_;

	if ((not defined $GCID) || ($GCID==0)) {
		die("can't call GIFTCARD::update with null/zero valued GCID");
		}

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	if ($options{'EMAIL'}) {
		require CUSTOMER;
		$options{'CID'} = &CUSTOMER::resolve_customer_id($USERNAME,0,$options{'EMAIL'});
		}

	my $pstmt = "update GIFTCARDS set MODIFIED_GMT=".time().",TXNCNT=TXNCNT+1";

	if (defined $options{'SPEND'}) {
		## eventually we could set a more colorful note here
		$options{'SPEND'} = sprintf("%.2f",$options{"SPEND"});
		if ($options{'SPEND'}<0) { $options{'SPEND'} = 0; }
		## if ($options{'SPEND'}>=0) { $options{'SPEND'} = ' - '.$options{'SPEND'}; }
		$pstmt .= sprintf(",BALANCE=(BALANCE-%.2f)",$options{'SPEND'});
		}
	elsif (defined $options{'DEPOSIT'}) {
		## eventually we could set a more colorful note here
		$options{'DEPOSIT'} = sprintf("%.2f",$options{"DEPOSIT"});
		if ($options{'DEPOSIT'}>=0) { $options{'DEPOSIT'} = ' + '.$options{'DEPOSIT'}; }
		$pstmt .= ",BALANCE=BALANCE".$options{'DEPOSIT'};
		}
	elsif (defined $options{'BALANCE'}) {
		$pstmt .= ",BALANCE=".sprintf("%.2f",$options{'BALANCE'});
		}

	if (defined $options{'NOTE'}) {
		$pstmt .= ",NOTE=".$dbh->quote($options{'NOTE'});
		}
	if (defined $options{'EXPIRES_GMT'}) {
		$pstmt .= ",EXPIRES_GMT=".int($options{'EXPIRES_GMT'});
		}
	if (defined $options{'LAST_ORDER'}) {
		$pstmt .= ",LAST_ORDER=".$dbh->quote($options{'LAST_ORDER'});
		}
	if (defined $options{'CID'}) {
		$pstmt .= ",CID=".int($options{'CID'});
		}
	my $LOGNOTE = $options{'LOGNOTE'};
	if (not $LOGNOTE) { $LOGNOTE = "Updated via manual edit."; }

	if ((defined $options{'CARDTYPE'}) && ($options{'CARDTYPE'}>0)) {
		my ($combinable,$cashequiv) = (0,0);
		if ($options{'CARDTYPE'}==7) { $combinable++; $cashequiv++; }
		elsif ($options{'CARDTYPE'}==3) { $combinable++; }
		elsif ($options{'CARDTYPE'}==1) { $combinable=0; }
		$pstmt .= ",COMBINABLE=$combinable,CASHEQUIV=$cashequiv";
		}

	$pstmt .= " where MID=$MID /* $USERNAME */ and ID=".int($GCID);
	
	if (defined $options{'SPEND'}) {
		$pstmt .= sprintf(" and (BALANCE - %.2f)>=0",$options{'SPEND'});
		}
	print STDERR $pstmt."\n";
	my $exec = $dbh->prepare($pstmt);

	my ($TXNCNT,$BALANCE,$CID) = ();

	my $success = 1;
	$success &&= $exec->execute();		## success will be set to zero if we don't execute (db error)
	$success &&= $exec->rows();			## success will be set to zero if zero rows were updated.

	if (not $success) {
		$TXNCNT = -1;
		}
	else {
		$pstmt = "select TXNCNT,BALANCE,CID from GIFTCARDS where MID=$MID and ID=".int($GCID);
		my $sth = $dbh->prepare($pstmt);
		$sth->execute();
		($TXNCNT,$BALANCE,$CID) = $sth->fetchrow();
		$sth->finish();

		if ((not defined $options{'LUSER'}) || ($options{'LUSER'} eq '')) { 
			$options{'LUSER'} = "APP:$0"; 
			}

		$pstmt = &DBINFO::insert($dbh,'GIFTCARDS_LOG',{
			MID=>$MID, USERNAME=>$USERNAME, LUSER=>$options{'LUSER'},
			GCID=>$GCID,NOTE=>$LOGNOTE,
			CREATED_GMT=>time(),TXNCNT=>$TXNCNT,BALANCE=>$BALANCE
			},debug=>2);
		print STDERR $pstmt."\n";
		$dbh->do($pstmt);
		}
	
	&DBINFO::db_user_close();
	return($TXNCNT);
	}


##
## returns an arrayref of hashes, containing relevant gift certificates details
##
## an array of hashrefs
##		
##
sub list {
	my ($USERNAME,%OPTIONS) = @_;
	
	my @info = ();
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select ID,CODE,CREATED_GMT,EXPIRES_GMT,LAST_ORDER,CID,NOTE,BALANCE,TXNCNT,MODIFIED_GMT,CASHEQUIV,COMBINABLE,SRC_SERIES from GIFTCARDS where MID=$MID";


	if ((defined $OPTIONS{'CODE'}) && ($OPTIONS{'CODE'} ne '')) {
		$pstmt .= " and CODE=".int($OPTIONS{'CODE'});
		}
	if ((defined $OPTIONS{'CID'}) && ($OPTIONS{'CID'}>0)) {
		$pstmt .= " and CID=".int($OPTIONS{'CID'});
		}
   if ((defined $OPTIONS{'TS'}) && (int($OPTIONS{'TS'})>0)) {
      $pstmt .= " and MODIFIED_GMT>=".int($OPTIONS{'TS'});
      }
	if ((defined $OPTIONS{'CHANGED'}) && (int($OPTIONS{'CHANGED'}))) {
		$pstmt .= " and SYNCED_GMT=0 ";
		$OPTIONS{'LIMIT'} = int($OPTIONS{'CHANGED'});
		}
   if (defined $OPTIONS{'PRT'}) {
      $pstmt .= " and PRT=".int($OPTIONS{'PRT'});
      }
   if (defined $OPTIONS{'SERIES'}) {
      $pstmt .= " and SRC_SERIES=".$udbh->quote($OPTIONS{'SERIES'});
      }
   if ((defined $OPTIONS{'LIMIT'}) && (int($OPTIONS{'LIMIT'})>0)) {
      $pstmt .= " order by ID desc limit 0,".int($OPTIONS{'LIMIT'});
      }

	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		my $type = 'UNKNOWN';
		if ($hashref->{'CASHEQUIV'}) { $type = 'CASH-EQUIV'; }
		elsif ($hashref->{'COMBINABLE'}>0) { $type = 'PROMO'; }
		elsif ($hashref->{'COMBINABLE'}==0) { $type = 'EXCLUSIVE'; }
		$hashref->{'TYPE'} = $type;

		push @info, $hashref;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@info);
	}



##
## generates a unique code for use with a giftcard.
##
sub createCode {
	require Data::UUID;
	my $ug    = new Data::UUID;
   my $uuid1 = $ug->create();
	my $str = reverse(time()%100).reverse($$%100).uc($ug->to_string($uuid1));
	$str =~ s/-//gs;
	$str =~ s/L/1/gs;
	$str =~ s/I/1/gs;
	$str =~ s/S/5/gs;
	$str =~ s/O/0/gs;
	$str = substr($str,0,15);
	
	my %valsIn = ();
	my %valsOut = ();
	my $count = 0;
	foreach ('0'..'9','A'..'Z') { 
		$valsOut{$count} = $_;
		$valsIn{$_} = $count; 
		$count++; 
		}

	## okay, add the check digit!
	my $total = 0; 
	foreach my $ch (split(//,$str)) {
		$total += $valsIn{$ch};
		}
	$str .= $valsOut{$total % 36};

	return($str);
	}


##
## Checking a code is easy there are four checks:
##		0 = card is valid!
##		1. the first 4 digits MUST start with a number.
##		2. the code may not contain any letter "L"'s
##		3. base36 sum of the first 15 digits is the base36 value of the last digit
##
sub checkCode {
	my ($CODE) = @_;

	$CODE =~ s/[\n\r\s\t\-]+//gs;

	my $bad = 0;
	if (substr($CODE,0,4) =~ /^[^\d]+/) {
		## first 4 digits are always a number.
		$bad = 1;
		}
	elsif (substr($CODE,0,-1) =~ /[LISO]/) {
		## may not contain any of the following characters: "LISTO" (except in the checksum)
		$bad = 2;
		}
	else {
		my $total = 0;

		my %valsIn = ();
		my %valsOut = ();
		my $count = 0;
		foreach ('0'..'9','A'..'Z') { 
			$valsOut{$count} = $_;
			$valsIn{$_} = $count; 
			$count++; 
			}

		foreach my $ch (split(//,substr($CODE,0,15))) {
			$total += $valsIn{ $ch };			
			}

		# print "VALS: $valsOut{ $total % 36 }\n";
		if (substr($CODE,-1) ne $valsOut{ $total % 36 }) {
			$bad = 3;
			}
		}
	return($bad);
	}


#mysql> desc GIFTCARDS_LOG;
#+----------+----------------------+------+-----+---------+-------+
#| Field    | Type                 | Null | Key | Default | Extra |
#+----------+----------------------+------+-----+---------+-------+
#| MID      | int(11)              | NO   | PRI | 0       |       |
#| USERNAME | varchar(20)          | NO   |     | NULL    |       |
#| LUSER    | varchar(10)          | NO   |     | NULL    |       |
#| GCID     | int(10) unsigned     | NO   | PRI | 0       |       |
#| NOTE     | varchar(32)          | NO   |     | NULL    |       |
#| TXNCNT | smallint(5) unsigned | NO   | PRI | 0       |       |
#| BALANCE  | decimal(7,2)         | YES  |     | NULL    |       |
#+----------+----------------------+------+-----+---------+-------+
sub addLog {
	my ($USERNAME,$LUSER,$GCID,$NOTE,$TXNCNT,$BALANCE) = @_;

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	if ((not defined $LUSER) || ($LUSER eq '')) { $LUSER = "APP:$0"; }

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = &DBINFO::insert($udbh,'GIFTCARDS_LOG',{
		MID=>$MID, USERNAME=>$USERNAME, LUSER=>$LUSER, GCID=>int($GCID),
		NOTE=>$NOTE,TXNCNT=>$TXNCNT, BALANCE=>$BALANCE
		}, debug=>2);
	$udbh->do($pstmt);

	&DBINFO::db_user_close();
	return($pstmt);
	}


sub getLogs {
	my ($USERNAME,$GCID) = @_;

	my @result = ();

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select * from GIFTCARDS_LOG where MID=$MID and GCID=".int($GCID)." order by CREATED_GMT";
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
## OPTIONS ARE:
##		CID = CUSTOMER ID 
##		RECIPIENT_EMAIL => if CID not set, will be resolved to determine CID (if none exists, account will be created)
##		RECIPIENT_NAME =>  if RECPIENT_EMAIL results in an account being created, this will be the name on the account.
##
##		CREATED_BY=> either the LUSER or ORDER_ID
##		EXPIRES_GMT=>
##
##		SENDEMAIL=>1
##
sub createCard {
	my ($USERNAME, $PRT, $BALANCE, %options) = @_;


	$BALANCE = sprintf("%.2f",$BALANCE);
	# $EXPIRES_GMT, $NOTE, $BALANCE, $CID

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my $CODE = undef;
	my $IS_DUPLICATE = 0;
	if (defined $options{'SRC_GUID'}) {
		my $pstmt = "select CODE from GIFTCARDS where MID=$MID /* $USERNAME */ and SRC_GUID=".$udbh->quote($options{'SRC_GUID'});		
		($CODE) = $udbh->selectrow_array($pstmt);
		}

	if (not defined $options{'CREATED_BY'}) { $options{'CREATED_BY'} = ''; }
	if (not defined $options{'EXPIRES_GMT'}) { $options{'EXPIRES_GMT'} = 0; }
	if (not defined $options{'CARDTYPE'}) { $options{'CARDTYPE'} = 0; }

	if (not defined $CODE) {	
		$CODE = &createCode(); 
		}

	($PRT) = &GIFTCARD::remap_giftcard_prt($USERNAME,$PRT);

	$options{'CREATED_GMT'} = time(); 
	if (not defined $options{'CREATED_BY'}) { $options{'CREATED_BY'} = $0; }
	if (not defined $options{'CID'}) { $options{'CID'} = 0; }

	if ($IS_DUPLICATE) {
		}
	elsif (($options{'CID'} == 0) && ($options{'RECIPIENT_EMAIL'} ne '')) {
		## giftcards should only be created on partitions that have customers.

		require CUSTOMER;
		($options{'CID'}) = CUSTOMER::resolve_customer_id($USERNAME,$PRT,$options{'RECIPIENT_EMAIL'});
		if ($options{'CID'}==0) {
			my ($c) = CUSTOMER->new($USERNAME,EMAIL=>$options{'RECIPIENT_EMAIL'},INIT=>1);
			if ($options{'RECIPIENT_FULLNAME'} ne '') {
				$c->set_attrib('INFO.FULLNAME', $options{'RECIPIENT_FULLNAME'});
				}
			$c->save();
			($options{'CID'}) = &CUSTOMER::resolve_customer_id($USERNAME,$PRT,$options{'RECIPIENT_EMAIL'});
			}
		}

	if (not $IS_DUPLICATE) {
		my @sql = ();

		push @sql, 'start transaction';

		if (not defined $options{'NOTE'}) { $options{'NOTE'} = ''; }

		my $DBVARS = {
			USERNAME=>$USERNAME,MID=>$MID,PRT=>$PRT,
			CODE=>$CODE,EXPIRES_GMT=>$options{'EXPIRES_GMT'},
			COMBINABLE=>(($options{'CARDTYPE'}&2)==2)?1:0,
			CASHEQUIV=>(($options{'CARDTYPE'}&4)==4)?1:0,
			NOTE=>$options{'NOTE'},BALANCE=>$BALANCE,'CID'=>$options{'CID'}, 
			CREATED_GMT=>$options{'CREATED_GMT'},
			LAST_ORDER=>'',
			CREATED_BY=>$options{'CREATED_BY'}
			};
		if ($options{'SRC_GUID'}) {
			## SRC_GUID is a unique field, at least unique for an account.
			$DBVARS->{'SRC_GUID'} = $options{'SRC_GUID'};
			}
		if ($options{'SRC_SERIES'}) {
			$DBVARS->{'SRC_SERIES'} = uc($options{'SRC_SERIES'});
			$DBVARS->{'SRC_SERIES'} =~ s/[^A-Z0-9\s]+//gs;	# don't allow these in series names.
			}
	

		my $pstmt = &DBINFO::insert($udbh,'GIFTCARDS',$DBVARS,'sql'=>1);
		push @sql, $pstmt;

		$pstmt = &DBINFO::insert($udbh,'GIFTCARDS_LOG',{
			MID=>$MID, USERNAME=>$USERNAME, LUSER=>$options{'CREATED_BY'}, 
			'*GCID'=>'last_insert_id()', CREATED_GMT=>$options{'CREATED_GMT'},
			NOTE=>sprintf("Created card [Bal: \$%.2f]",$BALANCE),TXNCNT=>0, BALANCE=>$BALANCE
			}, debug=>2);
		push @sql, $pstmt;
		push @sql, 'commit';	
	
		foreach my $pstmt (@sql) {
			print STDERR "$pstmt\n";
			$udbh->do($pstmt);
			}
		}

#	if ($options{'+SENDEMAIL'}) {
#		require SITE::EMAILS;
#		my ($profile) = &ZOOVY::prt_to_profile($USERNAME,$PRT);
#		my ($se) = SITE::EMAILS->new($USERNAME,NS=>$profile,PRT=>$PRT);
#		$se->sendmail('AGIFT_NEW',CID=>$options{'CID'});
#		}
	
	&DBINFO::db_user_close();
	return($CODE);
	}



sub expire {
	}





1;
