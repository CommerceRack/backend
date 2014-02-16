package CUSTOMER::TICKET;



use strict;
use lib "/backend/lib";
require DBINFO;
require ZOOVY;

#mysql> desc TICKETS;
#+-------------+----------------------------------+------+-----+---------+----------------+
#| Field       | Type                             | Null | Key | Default | Extra          |
#+-------------+----------------------------------+------+-----+---------+----------------+
#| ID          | int(11) unsigned                 | NO   | PRI | NULL    | auto_increment |
#| TKTCODE     | varchar(6)                       | NO   |     | NULL    |                |
#| MID         | int(10) unsigned                 | NO   |     | 0       |                |
#| USERNAME    | varchar(20)                      | NO   |     | NULL    |                |
#| PROFILE     | varchar(10)                      | NO   |     | NULL    |                |
#| CID         | int(10) unsigned                 | NO   |     | 0       |                |
#| SUBJECT     | varchar(60)                      | NO   |     | NULL    |                |
#| ORDERID     | varchar(12)                      | NO   |     | NULL    |                |
#| STATUS      | enum('NEW','ACTIVE','CLOSED','WAIT',,'') | NO   |     | NULL    |                |
# | CLASS            | enum('PRESALE','POSTSALE','RETURN','EXCHANGE','') | YES  |     | NULL    |                |
#| CREATED_GMT | int(10) unsigned                 | NO   |     | 0       |                |
#| UPDATED_GMT | int(10) unsigned                 | NO   |     | 0       |                |
#| CLOSED_GMT  | int(10) unsigned                 | NO   |     | 0       |                |
#| UPDATES     | tinyint(3) unsigned              | NO   |     | 0       |                |
#+-------------+----------------------------------+------+-----+---------+----------------+
#13 rows in set (0.02 sec)





##
## Standardized Fields in Ticket


#mysql> alter table TICKETS add STAGE varchar(3) default 'NEW' after STATUS;
#Query OK, 469 rows affected (0.06 sec)
#Records: 469  Duplicates: 0  Warnings: 0
#
#mysql> alter table TICKETS add REFUND_AMOUNT decimal(10,2) default 0 not null;
#Query OK, 469 rows affected (0.03 sec)
#Records: 469  Duplicates: 0  Warnings: 0
#
#mysql> alter table TICKETS add LAST_ACCESS_GMT integer unsigned default 0 not null;
#Query OK, 469 rows affected (0.04 sec)
#Records: 469  Duplicates: 0  Warnings: 0
#
#mysql> alter table TICKETS add LAST_ACCESS_USER varchar(10) default '' not null;
#Query OK, 469 rows affected (0.03 sec)
#Records: 469  Duplicates: 0  Warnings: 0


##
##
##
sub add_event {
	my ($self, $event, %options) = @_;
	## note: $event will NEVER be TICKET.CREATE because we can't call a method on a non-blessed object	
	## so if you modify this, be sure to modify the corresponding code in CUSTOMER::TICKET::new as well!
	&ZOOVY::add_event($self->username(),$event,'PRT'=>$self->prt(),'TICKETID'=>$self->tid());
	return();
	}


sub issueRMA {
	my ($self) = @_;

	}



##
## this is a wrapper around ctconfig - handy since we can change/add default values on the fly (based on the 'v')
##
sub deserialize_ctconfig {
	my ($USERNAME,$PRT,$webdbref) = @_;
	
	my $CTCONFIG = {};
	if (not defined $webdbref) {
		$webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
		}

	if ($webdbref->{'crmtickets'} eq '') {
		## disabled/not enabled
		$CTCONFIG->{'v'} = 0;
		}
	else {
		$CTCONFIG = &ZTOOLKIT::parseparams($webdbref->{'crmtickets'});
		}
	return($CTCONFIG);
	}


##
## returns the order id (if any associated with a ticket)
##
sub oid {
	my ($self) = @_;
	my ($oid) = $self->{'ORDERID'};
	return($oid);
	}

##
##
##
sub cdSet {
	my ($self,$property,$value) = @_;

	$property = lc($property);
	if (not defined $self->{'%CLASSDATA'}) { $self->{'%CLASSDATA'} = {}; }

	if (not defined $value) {
		delete $self->{'%CLASSDATA'}->{$property};
		}
	else {
		$self->{'%CLASSDATA'}->{$property} = $value;
		}

	use Data::Dumper;
	print STDERR Dumper($self);

	return();	
	}

##
##
##
sub cdGet {
	my ($self, $property) = @_;
	$property = lc($property);
	if (not defined $self->{'%CLASSDATA'}) { $self->{'%CLASSDATA'} = {}; }
	return($self->{'%CLASSDATA'}->{$property});
	}


##
##
## STATE can be:
##		CLOSE (closes ticket + sends email)
##		UPDATE (sets ticket to ACTIVE, but does not send a message)
##		ASK   (sends an email, waits for response)
##		''	(leaves ticket in current state)
##
sub changeState {
	my ($self, $state, %options) = @_;

	my $odbh = &DBINFO::db_user_connect($self->username());

	if (defined $options{'escalate'}) {
		$self->{'ESCALATED'} = int($options{'escalate'});
		}

	if (defined $options{'class'}) {
		$self->{'CLASS'} = $options{'class'};
		}

	if (not defined $self->{'%CLASSDATA'}) { $self->{'%CLASSDATA'} = {}; }
	my $qtCLASSDATA = $odbh->quote(&encodeini($self->{'%CLASSDATA'}));

	my $pstmt = "update TICKETS set UPDATED_GMT=".time().",CLASSDATA=".$qtCLASSDATA.",CLASS=".$odbh->quote($self->{'CLASS'}).",ESCALATED=".int($self->{'ESCALATED'}); 
	if (($state eq 'CLOSE') || ($state eq 'CLOSED')) { 
		$self->{'STATUS'} = 'CLOSED';
		$self->{'CLOSED_GMT'} = time();
		## send notification email?
		}
	elsif (($state eq 'UPDATE') || ($state eq 'ACTIVE')) {
		$self->{'STATUS'} = 'ACTIVE';
		}
	elsif (($state eq 'ASK') || ($state eq 'WAIT')) {
		$self->{'STATUS'} = 'WAIT';
		}
	else {
		warn "Unknown Status $state";
		die();
		}

	$pstmt .= ",STATUS=".$odbh->quote($self->{'STATUS'});
	$pstmt .= " where MID=".int($self->{'MID'})." /* $self->{'USERNAME'} */ and ID=".int($self->{'ID'});

	print STDERR $pstmt."\n";
	$odbh->do($pstmt);

	&DBINFO::db_user_close();
	return($self);
	}



sub setLock {
	my ($self,$LUSER) = @_;

	if ($LUSER eq '') { $LUSER = 'UNKNOWN'; }
	
	$self->{'LAST_ACCESS_GMT'} = time();
	$self->{'LAST_ACCESS_LUSER'} = $LUSER;

	my ($odbh) = &DBINFO::db_user_connect($self->username());
	my $pstmt = "update TICKETS set LAST_ACCESS_GMT=".$self->{'LAST_ACCESS_GMT'}.",LAST_ACCESS_USER=".$odbh->quote($LUSER)." where MID=".$self->mid()." and ID=".$self->tid();
	print STDERR $pstmt."\n";
	$odbh->do($pstmt);
	&DBINFO::db_user_close();
	return();
	}


sub getLock {
	my ($self) = @_;

	return($self->{'LAST_ACCESS_GMT'},$self->{'LAST_ACCESS_USER'});

#	my ($odbh) = &DBINFO::db_user_connect($USERNAME);
#	my $pstmt = "select LAST_ACCESS_GMT,LAST_ACCESS_USER from TICKETS where MID=".$self->mid()." and ID=".$self->tid();
#	my $sth = $odbh->prepare($pstmt);
#	$sth->execute();
#	my ($ts,$user) = $sth->fetchrow();
#	$sth->finish();
#	&DBINFO::db_user_close();	
#	return($ts,$user);
	}


##
##
##
##
sub getTickets {
	my ($USERNAME,%options) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my @TICKETS = ();
	my ($odbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select TKTCODE,SUBJECT,CREATED_GMT,UPDATED_GMT,STATUS,CLASS,ESCALATED from TICKETS where MID=".int($MID);
	if ((defined $options{'CID'}) && ($options{'CID'}>0)) { $pstmt .= " and CID=".int($options{'CID'}); }
	if ($options{'STATUS'} eq 'NEW') { $pstmt .= " and STATUS in ('NEW')"; }
	if ($options{'STATUS'} eq 'OPEN') { $pstmt .= " and STATUS in ('NEW','ACTIVE')"; }
	if ($options{'STATUS'} eq 'WAIT') { $pstmt .= " and STATUS in ('WAIT')"; }
	## STATUS == ALL is equivalent to all status'es (except maybe archived??)
	if ((defined $options{'TID'}) && ($options{'TID'}>0)) { $pstmt .= " and ID=".int($options{'TID'}); }

	if (defined $options{'SORT'}) {
		my ($SORT,$DIR) = split(/-/,$options{'SORT'});
		print STDERR "DIR: $DIR\n";
		$DIR = int($DIR); 	# 0 = asc, 1=desc
		my $key = 'ID';
		if ($options{'SORT'} eq 'STATUS') { $key = 'STATUS'; }
		if ($options{'SORT'} eq 'CLASS') { $key = 'CLASS'; }
		if ($options{'SORT'} eq 'CREATED') { $key = 'CREATED_GMT'; }
		$pstmt .= " order by $key ".(($DIR==0)?'asc':'desc');
		}
	
	print STDERR $pstmt."\n";
	my $sth = $odbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		push @TICKETS, $hashref;
		}
	
	&DBINFO::db_user_close();
	return(\@TICKETS);
	}



##
## returns a hashref of:
##		email, phone, orderid
##
sub buildInfo {
	my ($self) = @_;

	my %result = ();
	my ($email,$phone) = ('','');
	my $USERNAME = $self->{'USERNAME'};

	$result{'TKT_open'} = 0;
	$result{'TKT_total'} = 0;
	$result{'TKT_wait'} = 0;

	my $odbh = &DBINFO::db_user_connect($USERNAME);

	$result{'orderid'} = $self->link_orderid();

	if ($result{'orderid'} ne '') {
		my ($O2) = CART2->new_from_oid($USERNAME,$result{'orderid'});
		if (defined $O2) {
			$result{'email'} = $O2->in_get('bill/email');
			$result{'phone'} = $O2->in_get('bill/phone');
			}
		}

	if (not defined $result{'email'}) { $result{'email'} = ''; }
	if (not defined $result{'phone'}) { $result{'phone'} = ''; }

	if ($self->{'CID'}<=0) {}
	else {
		## Always lookup the customer if we can, so we can get relevant order details.
		my ($C) = CUSTOMER->new($USERNAME,INIT=>1,CID=>$self->{'CID'},PRT=>$self->{'PRT'});
		if ((defined $C) && ($C->cid()>0)) {
			$result{'cid'} = $C->cid();
			$result{'fullname'} = $C->get('INFO.FULLNAME');
			$result{'email'} = $C->get('INFO.EMAIL');
			my ($phone) = $C->get('INFO.PHONE');
			
			$result{'phone'} = sprintf("%s-%s-%s",substr($phone,0,3),substr($phone,3,3),substr($phone,6,4));
			$result{'customer_since'} = &ZTOOLKIT::pretty_date($C->get('INFO.CREATED_GMT'),-1);
			$result{'order_count'} = $C->get('INFO.ORDER_COUNT');
			# $result{'schedule'} = $C->get('INFO.SCHEDULE');
			$result{'orgid'} = $C->orgid();
			}

		
		## lets get the ticket counts!
		if ($result{'cid'}>0) {
			my $pstmt = "select STATUS from TICKETS where MID=".int($self->{'MID'})." /* $self->{'USERNAME'} */ and CID=".int($self->{'CID'});
			my $sth = $odbh->prepare($pstmt);
			$sth->execute();
			while ( my ($status) = $sth->fetchrow() ) {
				$result{'TKT_total'}++;
				if ($status eq 'CLOSED') {}
				elsif ($status eq 'WAIT') { $result{'TKT_wait'}++; }
				else { $result{'TKT_open'}++; }
				}
			$sth->finish();
			}

		}

	&DBINFO::db_user_close();
	return(\%result);
	}

##
## generates a unique code for use with a giftcard.
##
sub createCode {
	my ($USERNAME,$PRT,$attempt) = @_;

	
	my $FORMAT = '';
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $xattempt = 0;

	my $TICKET_COUNT = -1;
	$PRT = int($PRT);

	while (($TICKET_COUNT<0) && ($FORMAT ne 'ALPHA')) {
		my $pstmt = "update CRM_SETUP set TICKET_COUNT=TICKET_COUNT+1,TICKET_LOCK_PID=$$ where MID=$MID /* $USERNAME */ and PRT=$PRT";
		print STDERR $pstmt."\n";
		$udbh->do($pstmt);

		$pstmt = "select TICKET_SEQ,TICKET_COUNT from CRM_SETUP where MID=$MID /* $USERNAME */ and PRT=$PRT and TICKET_LOCK_PID=$$";
		print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		($FORMAT,$TICKET_COUNT) = $sth->fetchrow();
		$sth->finish();
		
		$xattempt++;
		if ($xattempt>4) {
			## well.. we better make sure we got something in CRM_SETUP
			&DBINFO::insert($udbh,'CRM_SETUP',{
				TICKET_COUNT=>123,
				USERNAME=>$USERNAME,
				MID=>$MID,
				PRT=>$PRT,
				},debug=>1);
			}
		if ($xattempt>5) {
			$TICKET_COUNT = time();
			warn "Failed to get a TICKET_COUNT for $USERNAME [$xattempt]";
			$FORMAT = 'ALPHA';
			}
		}
	if ($FORMAT eq '') { $FORMAT = 'ALPHA'; }
	&DBINFO::db_user_close();

	my $str = '';
	if ($FORMAT eq 'ALPHA') {
		require Data::UUID;
		my $ug    = new Data::UUID;
	  	my $uuid1 = $ug->create();
		my $str = reverse(time()%100).reverse($$%100).uc($ug->to_string($uuid1));
		$str =~ s/-//gs;
		$str =~ s/L/1/gs;
		$str =~ s/I/1/gs;
		$str =~ s/S/5/gs;
		$str =~ s/O/0/gs;
		$str = substr($str,0,6);
	
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
		}
	elsif ($FORMAT eq 'SEQ5') {
		$TICKET_COUNT = $TICKET_COUNT % 100000;
		$str = sprintf("%05d",$TICKET_COUNT);
		}
	elsif ($FORMAT eq 'DATEYYMM4') {
		$TICKET_COUNT = $TICKET_COUNT % 10000;

		require POSIX;		
		$str = sprintf("%04d@%04d",POSIX::strftime("%y%m",localtime()),$TICKET_COUNT);
		}

	## DUPLICATE CHECK!
	if (1) {
		my ($odbh) = &DBINFO::db_user_connect($USERNAME);
		my $qtTKTCODE = $odbh->quote($str);
		my $pstmt = "select count(*) from TICKETS where TKTCODE=$qtTKTCODE and MID=$MID /* $USERNAME */";
		my $sth = $odbh->prepare($pstmt);
		$sth->execute();
		my ($count) = $sth->fetchrow();
		$sth->finish();
		&DBINFO::db_user_close();
		if ($count>0) {
			## aieee.. duplicate check!
			warn("TICKET $str appears to be duplicate for $USERNAME [$xattempt]");
			$str = createCode($USERNAME,$PRT,++$attempt);
			}
		}

	return($str);
	}


##
## returns the TKTCODE for the current ticket.
##
sub username { return($_[0]->{'USERNAME'}); }
sub tid { my ($self) = @_; return(int($self->{'ID'})); }
sub mid { my ($self) = @_; return(int($self->{'MID'})); }
sub tktcode { my ($self) = @_; return($self->{'TKTCODE'}); }
sub link_cid { my ($self) = @_; return($self->{'CID'}); }
sub link_orderid { my ($self) = @_; return($self->{'ORDERID'}); }
sub prt { my ($self) = @_; return(int($self->{'PRT'})); }



sub get { my ($self,$id) = @_; return($self->{$id}); }


##
## returns: associated customer object (if any)
## the assumption is that this *might* be cached someday
##
sub link_customer {
	my ($self) = @_;

	require CUSTOMER;
	my $CID = $self->link_cid();
	my $C = undef;
	if ($CID>0) {
		($C) = CUSTOMER->new($self->username(),'PRT'=>$self->prt(),'CREATE'=>0,'INIT'=>0xFF,'CID'=>$self->link_cid());
		}
	return($C);
	}

##
## returns: order object associated (if any)
## the assumption is that this *might* be cached someday
##
sub link_order {
	my ($self) = @_;

	require CART2;
	my $OID = $self->link_orderid();
	my ($O2) = undef;
	if ($OID ne '') {
		($O2) = CART2->new_from_oid($self->username(),$OID,'new'=>0);
		}
	return($O2);
	}



sub create {
	my ($class, $USERNAME, %options) = @_;

	my ($self) = CUSTOMER::TICKET->new($USERNAME,0,%options);
	

	return($self);
	}


##
##
##
##
sub new {
	my ($class, $USERNAME, $TID, %options) = @_;

	my $self = undef;
	my ($odbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($PRT) = int($options{'PRT'});

	if (substr($TID,0,1) eq '#') {
		## TICKETID
		}
	elsif (substr($TID,0,1) eq '+') {
		## TKTCODE
		}
	elsif ($TID == 0) {	## this is problematic i think (we should have implicit new=> parameter)
		## Create a new ticket.

		my $self = {};
		my ($CODE) = &CUSTOMER::TICKET::createCode($USERNAME,$options{'PRT'});
	
		if (not defined $options{'PRT'}) {
			warn "called new but did not pass PRT";
			}
		if (not defined $options{'ORDERID'}) { $options{'ORDERID'} = ''; }
		if (not defined $options{'CREATED_GMT'}) { $options{'CREATED_GMT'} = time(); }
		# if (not defined $options{'PROFILE'}) { $options{'PROFILE'} = ''; }		
		if (not defined $options{'DOMAIN'}) { $options{'DOMAIN'} = ''; }
		if (not defined $options{'CID'}) { $options{'CID'} = 0; }
		if (not defined $options{'SUBJECT'}) { $options{'SUBJECT'} = 'Subject Not Specified'; }
		if (not defined $options{'NOTE'}) { $options{'NOTE'} = ''; }
		if (not defined $options{'CLASS'}) { $options{'CLASS'} = ''; }
		if ($CODE eq '') { $CODE = time()%100000; }

		&DBINFO::insert($odbh,'TICKETS',{
			TKTCODE=>$CODE,
			MID=>$MID,
			USERNAME=>$USERNAME,
			# PROFILE=>$options{'PROFILE'},
			DOMAIN=>$options{'DOMAIN'},
			PRT=>$options{'PRT'},
			CREATED_GMT=>int($options{'CREATED_GMT'}),
			STATUS=>'NEW',
			CLASS=>$options{'CLASS'},
			ORDERID=>$options{'ORDERID'},
			CID=>$options{'CID'},
			UPDATES=>0,
			SUBJECT=>$options{'SUBJECT'},
			NOTE=>$options{'NOTE'},
			LAST_ACCESS_GMT=>0,
			LAST_ACCESS_USER=>'',
			},debug=>1);
		
		my $pstmt = "select last_insert_id()";
		my $sth = $odbh->prepare($pstmt);
		$sth->execute();
		($TID) = $sth->fetchrow();
		$sth->finish();
		if ($TID>0) { 
			## can't call $self->add_event because it hasn't been blessed yet.
			&ZOOVY::add_event($USERNAME,'TICKET.CREATE','PRT'=>$PRT,'TICKETID'=>$TID);
			$TID = '#'.$TID; 
			}


		}


	if (substr($TID,0,1) eq '+') {
		## +CODE
		$TID = substr($TID,1);
		my $pstmt = "select * from TICKETS where TKTCODE=".($odbh->quote($TID))." and MID=$MID /* $USERNAME */ and PRT=$PRT";
		print STDERR "$pstmt\n";
		if ($options{'CID'}) { $pstmt .= " and CID=".int($options{'CID'}); }
		my $sth = $odbh->prepare($pstmt);
		$sth->execute();
		$self = $sth->fetchrow_hashref();
		$sth->finish();
		}
	elsif (substr($TID,0,1) eq '#') {
		## Lookup existing ticket by ID #1234
		$TID = substr($TID,1);
		my $pstmt = "select * from TICKETS where ID=".int($TID)." and MID=$MID /* $USERNAME */";
		if ($options{'CID'}) { $pstmt .= " and CID=".int($options{'CID'}); }
		my $sth = $odbh->prepare($pstmt);
		$sth->execute();
		$self = $sth->fetchrow_hashref();
		$sth->finish();
		}

	if (defined $self) {
		bless $self, 'CUSTOMER::TICKET';
		}

	if ($self->{'CLASSDATA'} ne '') {
		## %CLASSDATA is a hashref of key value pairs!
		$self->{'%CLASSDATA'} = &decodeini($self->{'CLASSDATA'});
		}


	&DBINFO::db_user_close();
	return($self);
	}





##
## NOTE: 
##		leave $AUTHOR blank to represent customer.
##
sub addMsg {
	my ($self, $AUTHOR, $NOTE, $PRIVATE) = @_;

	if (not defined $AUTHOR) { $AUTHOR = ''; }
	if (not defined $NOTE) { $NOTE =  ''; }

	$NOTE =~ s/\<.*?\>//gs;	# strip HTML

	my $odbh = &DBINFO::db_user_connect($self->username());
	&DBINFO::insert($odbh,'TICKET_UPDATES',{
		PARENT=>$self->{'ID'},
		MID=>$self->{'MID'},
		AUTHOR=>$AUTHOR,
		CREATED_GMT=>time(),
		NOTE=>$NOTE,
		PRIVATE=>int($PRIVATE),
		},debug=>1);

	my $pstmt = "update TICKETS set UPDATED_GMT=".time().",UPDATES=UPDATES+1 where ID=".$self->{'ID'};
	$odbh->do($pstmt);

	&DBINFO::db_user_close();
	}




#mysql> desc TICKET_UPDATES;
#+-------------+------------------+------+-----+---------+----------------+
#| Field       | Type             | Null | Key | Default | Extra          |
#+-------------+------------------+------+-----+---------+----------------+
#| ID          | int(11) unsigned | NO   | PRI | NULL    | auto_increment |
#| PARENT      | int(10) unsigned | NO   |     | 0       |                |
#| MID         | int(10) unsigned | NO   | MUL | 0       |                |
#| AUTHOR      | varchar(20)      | NO   |     | NULL    |                |
#| CREATED_GMT | int(10) unsigned | NO   |     | 0       |                |
#| NOTE        | varchar(2048)    | NO   |     | NULL    |                |
#| PRIVATE     | tinyint(4)       | NO   |     | 0       |                |
#+-------------+------------------+------+-----+---------+----------------+
#7 rows in set (0.03 sec)

##
## returns an arrayref of TICKET_UPDATES for this ticket.
##
sub getMsgs {
	my ($self, %options) = @_;

	$self->{'@msgs'} = [];
	my $odbh = &DBINFO::db_user_connect($self->username());
	my $pstmt = "select * from TICKET_UPDATES where MID=".int($self->{'MID'})." and PARENT=".int($self->{'ID'})." order by ID";
	my $sth = $odbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		push @{$self->{'@msgs'}}, $hashref;
		}
	$sth->finish();

	&DBINFO::db_user_close();
	return($self->{'@msgs'});
	}


sub encodeini {
	my ($paramsref) = @_;

	my $txt = "\n";
	foreach my $k (sort keys %{$paramsref}) {
		next if (substr($k,0,1) eq '?');
		$paramsref->{$k} =~ s/[\n\r]+//gs;
		$txt .= "$k=$paramsref->{$k}\n";
		}
	return($txt);
	}

sub decodeini {
	my ($initxt) = @_;

	my %result = ();
	foreach my $line (split(/\n/,$initxt)) {		
		my ($k,$v) = split(/=/,$line,2);
		$result{$k} = $v;
		}
	# use Data::Dumper; 
	# print STDERR "DECODE INI: ".Dumper(\%result);
	return(\%result);
	}




1;

