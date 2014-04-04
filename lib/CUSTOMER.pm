package CUSTOMER;

use lib "/backend/lib";
use DBI;
use Digest::SHA1;
use String::MkPasswd;


require DBINFO;
require ZTOOLKIT;
require ZOOVY;
require ZWEBSITE;
require CUSTOMER::ADDRESS;
require CUSTOMER::ORGANIZATION;
require BLAST;
use strict;

$CUSTOMER::DEBUG = 0;

##
## Okay, so we're going to create a customer object.
##
## the structure of a customer:
##	 everything is controlled through fetch_attrib -- which in turn initializes 
##		_STATE = 0 --> not loaded/no information saved.
##		_STATE = +1 --> initialized w/primary info
##		_STATE = +2 --> initialized w/billing info
##		_STATE = +4 --> initialized w/shipping info
##		_STATE = +8 --> initialized w/meta info
##		_STATE = +16 --> initialized w/wholesale info (WS->{} populated)
##		_STATE = +32 --> initialized w/notes
##
##		_DEFAULT_BILL => the position of the default billingo (-1 if unknown)
##		BILL = [ { billing info }, {'billing info2'} ]
##	
##		_DEFAULT_SHIP => the position of the default shipinfo (-1 if unknown)
##		SHIP = [ {}, {} ]
##
##		_CID = id # <-- we're going to start trying to use this more.
##		_EMAIL = email address/key (if known)
##		_USERNAME = the merchant who owns this customer.
##
##    @NOTES = [   
##			{ ID=>'##', LUSER=>'', CREATED_GMT=>, NOTE=>'' }  
##			{ ID=>'##', LUSER=>'', CREATED_GMT=>, NOTE=>'' }  
##			]
##				
##		META = { meta properties }
##		INFO.CID -- internal id for this customer (don't use this, use _CID instead)
##		INFO.MID -- merchant id for this customer (don't use this, use _MID instead)
##		INFO.PRT -- 
##		INFO.USERNAME -- owner of this customer (don't use this, use _USERNAME instead)
##		INFO.EMAIL -- email address of this customer (don't use this, use _EMAIL instead)
##		INFO.MODIFIED_GMT -- the last time this customer was modified
##		INFO.CREATED_GMT -- when the custome was created
##		INFO.PHONE
##		INFO.NEWSLETTER -- a bitwise value designating which newsletter the customer subscribes to.
##		INFO.HINT_NUM -- which hint # (see table in checkout)
##		INFO.HINT_ANSWER -- hint answer
##		*INFO.FULLNAME
##		INFO.FIRSTNAME INFO.LASTNAME
##	   HINT_ATTEMPTS tinyint(4) NOT NULL default '0',
##	   LASTLOGIN_GMT int(10) unsigned NOT NULL default '0',
## 	LASTORDER_GMT int(10) unsigned NOT NULL default '0',
##	   ORDER_COUNT smallint(5) unsigned NOT NULL default '0',
##		INFO.IP - ip address that created this account
##		INFO.ORIGIN - marketplace (see order.pm for mkt field info)
##		INFO.HAS_NOTES -- a counter for the number of notes a customer has (0 for none)
##		INFO.REWARD_BALANCE -- last computed reward balance
##		INFO.DEFAULT_SHIP_ADDRESS (deprecated)
##		INFO.DEFAULT_BILL_ADDRESS (deprecated)
##


sub TO_JSON {
	my ($self) = @_;
	
	my %clone = ();
	foreach my $k (keys %{$self}) {
		if (ref($self->{$k}) eq '') {
			$clone{$k} = $self->{$k};
			}
		else {
			$clone{$k} = Clone::clone($self->{$k});
			}
		}
 
	return(\%clone);
	}



##
## records what's changed.
##
sub sync_action {
	my ($self, $ACTION) = @_;
	if (not defined $self->{'@UPDATES'}) { $self->{'@UPDATES'} = []; }
	push @{$self->{'@UPDATES'}}, $ACTION;
	}

##
##
##
sub run_macro_cmds {
	my ($self, $CMDS, %params) = @_;

	my $errs = 0;
	my $LU = $params{'*LU'};

	my $lm = $params{'*LM'};
	if (not defined $lm) { $lm = LISTING::MSGS->new(); }

	my ($echo) = 0;
	my @RESULTS = ();
	my $CID = $self->cid();

	my $R = $params{'%R'} || {};
	$R->{'errors'} = 0;

	foreach my $CMDSET (@{$CMDS}) {
		my ($cmd,$pref) = @{$CMDSET};
		my $result = undef;
		$self->sync_action("MACRO/$cmd");

		if ($cmd eq 'PASSWORD-SET') {
			if (defined $LU) { $LU->log("MANAGE.CUSTOMER.PASSWORD-SET",sprintf("Password was reset for customer %d",$self->cid()),"INFO"); }
			$R->{$cmd}->{'password'} = $self->initpassword(set=>$pref->{'password'});
			}
		elsif ($cmd eq 'PASSWORD-RECOVER') {
			if (defined $LU) { $LU->log("MANAGE.CUSTOMER.PASSWORD-RECOVER",sprintf("Password recover for customer %d",$self->cid()),"INFO"); }
			$R->{$cmd}->{'password'} = $self->generate_recovery();
			}
		elsif ($cmd eq 'GIFTCARD-CREATE') {
			$pref->{'CID'} = $self->cid();
			&GIFTCARD::createCard( $self->username(), $self->prt(), $pref->{'BALANCE'}, %{$pref});
			}
		elsif ($cmd eq 'HINTRESET') {
			$self->set_attrib('INFO.HINT_ANSWER','');
			$self->set_attrib('INFO.HINT_NUM',0);
			}
		elsif ($cmd eq 'SETORIGIN') {
			$self->set_attrib('INFO.ORIGIN',int($pref->{'origin'}));
			}
		elsif ($cmd eq 'LINKORG') {
			$self->set_attrib('INFO.ORGID',int($pref->{'orgid'}));
			}
		elsif ($cmd eq 'LOCK') {
			$self->set_attrib('INFO.IS_LOCKED',1);
			}
		elsif ($cmd eq 'UNLOCK') {
			$self->set_attrib('INFO.IS_LOCKED',0);
			}
		elsif ($cmd eq 'ADDTODO') {
			require TODO;
			&TODO::easylog($self->username(),class=>"INFO",title=>$pref->{'title'},detail=>$pref->{'note'},priority=>2,link=>"cid:$CID");
			}
		elsif ($cmd eq 'ADDTICKET') {
			require CUSTOMER::TICKET;
			my ($CT) = CUSTOMER::TICKET->new($self->username(),0,
					new=>1,PRT=>$self->prt(),CID=>$self->cid(),
					SUBJECT=>$pref->{'title'},
					NOTE=>$pref->{'note'},
				);
			}
		elsif ($cmd eq 'SET') {
			my %update = ();

			$self->fetch_attrib('INFO');
			if ($pref->{'email'}) {
				if (not &ZTOOLKIT::validate_email($pref->{'email'})) {
					$lm->pooshmsg("ERROR|+Email address appears to be invalid, please double check");
					}
				elsif ($self->fetch_attrib('INFO.EMAIL') ne $pref->{'email'}) {
				   $self->set_attrib('INFO.EMAIL',$pref->{'email'});
					}
				}

			if (defined $pref->{'firstname'}) {
				if ($self->fetch_attrib('INFO.FIRSTNAME') ne $pref->{'firstname'}) {
				   $self->set_attrib('INFO.FIRSTNAME',$pref->{'firstname'});
					}
				}
			if (defined $pref->{'lastname'}) {
				if ($self->fetch_attrib('INFO.LASTNAME') ne $pref->{'lastname'}) {
				   $self->set_attrib('INFO.LASTNAME',$pref->{'lastname'});
					}
				}
			if (defined $pref->{'is_locked'}) {
				my $IS_LOCKED = (int($pref->{'is_locked'}))?1:0;
				if ($self->fetch_attrib('INFO.IS_LOCKED') != $IS_LOCKED) {
					$self->set_attrib('INFO.IS_LOCKED',$IS_LOCKED);
					}
				}

			## Handle Newsletter
			my $newsletter = $self->fetch_attrib('INFO.NEWSLETTER');
			foreach my $i (0..14) {
				if (not defined $pref->{'newsletter_'.($i+1)}) { 
					## no change
					}
				elsif ($pref->{'newsletter_'.($i+1)} == 0) {
					## disable
					$newsletter = $newsletter & ~(1<<$i);	## turn off bit
					}
				else {
					$newsletter |= (1<<$i); 
					}
				}	
			if ($self->fetch_attrib('INFO.NEWSLETTER') != $newsletter) {
				$self->set_attrib('INFO.NEWSLETTER',$newsletter); 
				}
			}
		elsif ($cmd eq 'ORGCREATE') {
			my ($ORG) = CUSTOMER::ORGANIZATION->create($self->username(),$self->prt(),$pref);
			$ORG->save('create'=>1);
			if ($ORG->orgid()>0) {
				$self->set_attrib('INFO.ORGID',$ORG->orgid());
				}
			}
		elsif (($cmd eq 'WSSET') || ($cmd eq 'ORGSET')) {
			my $changes = 0;
			my $wsinfo = $self->fetch_attrib('WS');
			## NOTE: popup saves this data directly
			# $wsinfo->{'LOGO'} = $pref->{'logoImg'};
			foreach my $k ('BILLING_CONTACT','SCHEDULE','ALLOW_PO','RESALE','LOGO','RESALE_PERMIT','CREDIT_LIMIT','CREDIT_BALANCE','CREDIT_TERMS','ACCOUNT_MANAGER','ACCOUNT_TYPE','ACCOUNT_REFID') {
				if (not defined $pref->{$k}) {
					}
				elsif ($k eq 'ALLOW_PO') { $wsinfo->set('ALLOW_PO', $pref->{'ALLOW_PO'}?1:0 ); }
				elsif ($k eq 'RESALE') { $wsinfo->set('RESALE', $pref->{'RESALE'}?1:0); }
				else {
					$wsinfo->set($k, sprintf("%s",$pref->{$k})); 
					}
				}
			}
		elsif (($cmd eq 'ADDRCREATE') || ($cmd eq 'ADDRUPDATE')) {

			my $TYPE = lc($pref->{'TYPE'});
			my %INFO = ();
			my $SHORTCUT = $pref->{'SHORTCUT'};
			if ($SHORTCUT eq '') { $SHORTCUT = $TYPE; } 	# a sane default

			$INFO{'firstname'} = $pref->{'firstname'};	
			$INFO{'lastname'} = $pref->{'lastname'};
			$INFO{'phone'} = $pref->{'phone'};
			$INFO{'company'} = $pref->{'company'};
			$INFO{'address1'} = $pref->{'address1'};
			$INFO{'address2'} = $pref->{'address2'};
			$INFO{'city'} = $pref->{'city'};
			$INFO{'region'} = $pref->{'region'};
			$INFO{'postal'} = $pref->{'postal'};
			$INFO{'countrycode'} = $pref->{'countrycode'};

			my $IS_DEFAULT = undef;
			if (defined $pref->{'DEFAULT'}) {
				$IS_DEFAULT = int($pref->{'IS_DEFAULT'});
				}

			if ($TYPE eq 'BILL') {
				$INFO{'email'} = $pref->{'email'};
				}
	
			if ((uc($TYPE) eq 'WS') || (uc($TYPE) eq 'ORG')) { 
				my ($WS) = $self->fetch_attrib('WS');
				$INFO{'BILLING_CONTACT'} = $pref->{'contact'};
				foreach my $k (keys %INFO) { $WS->set( $k, sprintf("%s",$pref->{$k}) ); }
				}
			else {
				my ($addr) = CUSTOMER::ADDRESS->new($self,$TYPE,\%INFO,'SHORTCUT'=>$SHORTCUT);
				$self->add_address($addr,'SHORTCUT'=>$SHORTCUT,'IS_DEFAULT'=>$IS_DEFAULT);
				}
			}
		elsif ($cmd eq 'ADDRDEFAULT') {
			## not implemented?			
			}
		elsif ($cmd eq 'ADDRREMOVE') {
			my $TYPE = uc($pref->{'TYPE'});	
			my $SHORTCUT = uc($pref->{'SHORTCUT'});
			$self->nuke_addr($TYPE,$SHORTCUT);
			}
		elsif (($cmd eq 'SENDEMAIL') || ($cmd eq 'BLAST-SEND')) {
			my ($MSGID) = $pref->{'MSGID'};
			my ($BLAST) = BLAST->new($self->username(),int($self->prt()),\%params);
			my ($rcpt) = $BLAST->recipient('CUSTOMER', $self, {'%CUSTOMER'=>$self->TO_JSON(),'%RUPDATES'=>$R});
			my ($msg) = $BLAST->msg($MSGID,$pref);
			$BLAST->send($rcpt,$msg);
			}
		elsif ($cmd eq 'ORDERLINK') {
			&CUSTOMER::save_order_for_customer($self->username(),$pref->{'OID'},$self->email());
			}
		elsif ($cmd eq 'NOTECREATE') {
			print STDERR "!!!!!!!!!!!!!!! $pref->{'TXT'}\n";
			my $LUSER = $LU->luser();
			if (not defined $LUSER) { $LUSER = '*MACRO'; }
			$self->save_note($LUSER,$pref->{'TXT'});
			}
		elsif ($cmd eq 'NOTEREMOVE') {
			$self->nuke_note( $pref->{'NOTEID'} );
			}
		elsif ($cmd eq 'WALLETCREATE') {
			my %params = ();
			$params{'CC'} = $pref->{'CC'};
			$params{'YY'} = $pref->{'YY'};
			$params{'MM'} = $pref->{'MM'};
			my ($ID,$ERROR) = $self->wallet_store(\%params);
			if ($ID == 0) {
				$lm->pooshmsg("ERROR|+Wallet $ERROR");
				}
			else {
				$lm->pooshmsg("SUCCESS|+Wallet $ID");
				}
			}
		elsif ($cmd eq 'WALLETDEFAULT') {
			$self->wallet_update(int($pref->{'SECUREID'}),'default'=>1);
			}
		elsif ($cmd eq 'WALLETREMOVE') {
			$self->wallet_nuke(int($pref->{'SECUREID'}));
			}
		elsif ($cmd eq 'REWARDUPDATE') {
			$self->update_reward_balance($pref->{'i'},$pref->{'reason'});
			}
		}	

	$self->save();

	if ($errs) {
		open F, ">>/tmp/customer-macro-debug.txt";
		print F  Dumper($self->username(),$self->cid(),\@{$CMDS});
		close F;
		}

	return($R);	
	}



##
## AUTHTYPE is "EMAIL", "PHONE", "OID+CARTID", "FACEBOOK", "OPENID", "TWITTER", "GOOGLE", "AIM", "YAHOO"
##
sub auth_lookup_cid {
	my ($USERNAME,$PRT,$AUTHTYPE,$KEY) = @_;

	}

sub auth_reserve_cid {
	my ($USERNAME,$PRT,$AUTHTYPE,$KEY) = @_;
	}

sub delete_cid_auth {
	my ($USERNAME,$PRT,$AUTHTYPE,$KEY) = @_;
	}


##
##
##
sub add_to_list {
	my ($self,$listid,$sku,%options) = @_;

	my $qty = 0;
	if (defined $options{'qty'}) { $qty = int($options{'qty'}); }

	my ($USERNAME) = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	
	my ($CID) = $self->cid();
	my ($MID) = $self->mid();

	my $pstmt = "select ID,QTY,NOTE,MODIFIED_TS,PRIORITY from CUSTOMER_LISTS where MID=$MID and CID=$CID and LISTID=".$udbh->quote($listid)." and SKU=".$udbh->quote($sku);
	print STDERR "$pstmt\n";
	my ($ID,$EXISTING_QTY) = $udbh->selectrow_array($pstmt);
	
	my $sql_update = 1;
	if ($ID>0) {
		## exists .. so what should we do.
		if (defined $options{'replace'}) {
			$pstmt = "delete from CUSTOMER_LISTS where MID=$MID and CID=$CID and LISTID=".$udbh->quote($listid)." and SKU=".$udbh->quote($sku);
			print $pstmt."\n";
			$udbh->do($pstmt);
			$sql_update = 0;
			$ID = 0;
			}
		}

	my %dbvars = (
		USERNAME=>$USERNAME,MID=>$MID,CID=>$CID,LISTID=>$listid,SKU=>$sku,
		MODIFIED_TS=>time()
		);
	if (defined $options{'priority'}) {
		$dbvars{'PRIORITY'} = int($options{'priority'});
		}
	if (defined $options{'note'}) {
		$dbvars{'NOTE'} = int($options{'note'});
		}

	if ($ID>0) {
		## update existing record.
		$dbvars{'ID'} = $ID;
		$dbvars{'*QTY'} = "(QTY+$qty)";
		my $pstmt = &DBINFO::insert($udbh,'CUSTOMER_LISTS',\%dbvars, 
			verb=>'update',sql=>1,
			key=>['MID','CID','LISTID','SKU','ID'],
			);
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		$ID = "0$ID";
		}
	else {
		## new record. set insert
		$dbvars{'QTY'} = $qty;
		my $pstmt = &DBINFO::insert($udbh,'CUSTOMER_LISTS',\%dbvars,update=>0,sql=>1);
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		($ID) = &DBINFO::last_insert_id($udbh);
		}

	&DBINFO::db_user_close();
	return($ID);
	}

##
##
##
sub get_all_lists {
	my ($self) = @_;
	my ($USERNAME) = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($CID) = $self->cid();
	my ($MID) = $self->mid();

	my @RESULTS = ();
	my $pstmt = "select LISTID,count(*) as ITEMS from CUSTOMER_LISTS where MID=$MID /* $USERNAME */ and CID=$CID group by LISTID";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($LISTID,$count) = $sth->fetchrow() ) {
		push @RESULTS, { id=>$LISTID, items=>$count };
		}
	$sth->finish();

	&DBINFO::db_user_close();
	return(\@RESULTS);
	}

##
##
##
sub get_list {
	my ($self,$listid) = @_;
	my ($USERNAME) = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($CID) = $self->cid();
	my ($MID) = $self->mid();

	my @RESULTS = ();
	my $pstmt = "select * from CUSTOMER_LISTS where MID=$MID /* $USERNAME */ and CID=$CID and LISTID=".$udbh->quote($listid);
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $listitemref = $sth->fetchrow_hashref() ) {
		delete $listitemref->{'ID'};
		push @RESULTS, $listitemref;
		}
	$sth->finish();

	&DBINFO::db_user_close();
	return(\@RESULTS);
	}


##
##
##
sub remove_from_list {
	my ($self,$listid,$sku) = @_;

	my ($USERNAME) = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($CID) = $self->cid();
	my ($MID) = $self->mid();

	my $pstmt = "delete from CUSTOMER_LISTS where MID=$MID /* $USERNAME */ and CID=$CID and LISTID=".$udbh->quote($listid)." and SKU=".$udbh->quote($sku);	
	$udbh->do($pstmt);

	&DBINFO::db_user_close();
	}



#sub sendmail {
#	my ($self,$msg,%OPTIONS) = @_;
#	require SITE;
#	my ($SITE) = SITE->new($self->username(),'PRT'=>$self->prt());
#	require SITE::EMAILS;
#	my ($se) = SITE::EMAILS->new($self->username(),'*SITE'=>$SITE,'CUSTOMER'=>$self,%OPTIONS);
#	return($se->sendmail('REWARDS'));
#	}


## NOTE: the only module which can access CUSTOMER_SECURE is ZPAY::
sub wallet_retrieve {
	my ($self,$ID) = @_;

	my ($USERNAME) = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	
	my ($CID) = $self->cid();
	my ($MID) = $self->mid();
	$ID = int($ID);
	my $pstmt = "select ID,SECURE,DESCRIPTION,date(CREATED),date(EXPIRES),ATTEMPTS,FAILURES,IS_DEFAULT from CUSTOMER_SECURE where MID=$MID and CID=$CID and ID=$ID";
	($ID,my $SECURE,my @INFO) = $udbh->selectrow_array($pstmt);

	print STDERR "MID:$MID CID:$CID ID:$ID SECURE:$SECURE\n";

	my $ref = undef;
	require ZTOOLKIT::SECUREKEY;
	my $UNSECURE = &ZTOOLKIT::SECUREKEY::decrypt($self->username(),$SECURE);	
	print STDERR "UNSECURE: $UNSECURE\n";

	if ($UNSECURE ne '') {
		$ref = &parseparams($UNSECURE);
		$ref->{'ID'} = $ID;	# probably not necessary (probably unwanted)
		$ref->{'WI'} = $ID;
		$ref->{'TD'} = $INFO[0];
		$ref->{'TC'} = $INFO[1];
		$ref->{'TE'} = $INFO[2];
		$ref->{'##'} = $INFO[3];
		$ref->{'#!'} = $INFO[4];
		$ref->{'#*'} = $INFO[5];
		}

	delete $ref->{'#$'};	# wallet should not contain a max amount to charge
	delete $ref->{'$#'};	# wallet should not contain a max amount to charge
	delete $ref->{'$$'};	# wallet should not contain a max amount to charge
	delete $ref->{'x'};	
	delete $ref->{'y'};	
	delete $ref->{'z'};	
	delete $ref->{'tender'};	
	delete $ref->{'auto'};	
	delete $ref->{'IP'};

	&DBINFO::db_user_close();
	return($ref);
	}


##
## returns a hashref of secure stored (without encryption)
##
sub wallet_list {
	my ($self) = @_;

	my ($USERNAME) = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	
	my ($CID) = $self->cid();
	my ($MID) = $self->mid();
	my $pstmt = "select ID,DESCRIPTION,date(CREATED) as CREATED,date(EXPIRES) as EXPIRES,ATTEMPTS,FAILURES,IS_DEFAULT from CUSTOMER_SECURE where MID=$MID and CID=$CID order by IS_DEFAULT desc,ID desc";
	my @RESULTS = ();
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $summaryref = $sth->fetchrow_hashref() ) {
		# $summaryref->{'CREATED'} =~
		my %wallet = ();
		$wallet{'TN'} = 'WALLET';
		$wallet{'WI'} = $summaryref->{'ID'};
		$wallet{'ID'} = sprintf("WALLET:%d",$summaryref->{'ID'});
		$wallet{'TD'} = $summaryref->{'DESCRIPTION'};
		$wallet{'TC'} = $summaryref->{'CREATED'};
		$wallet{'TE'} = $summaryref->{'EXPIRES'};
		$wallet{'##'} = $summaryref->{'ATTEMPTS'};
		$wallet{'#!'} = $summaryref->{'FAILURES'};
		$wallet{'#*'} = int($summaryref->{'IS_DEFAULT'});
		push @RESULTS, \%wallet;
		}
	$sth->finish();

	&DBINFO::db_user_close();
	return(\@RESULTS);
	}

##
## this is used to keep track of when a wallet is used (or attempted)
##
sub wallet_update {
	my ($self,$ID,%params) = @_;

	my ($USERNAME) = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($CID) = $self->cid();
	my ($MID) = $self->mid();
	$ID = int($ID);

	my %dbupdates = ();
	$dbupdates{'MID'} = $MID;
	$dbupdates{'CID'} = $CID;
	$dbupdates{'ID'} = $ID;
	if ($params{'default'}) {
		my $pstmt = "update CUSTOMER_SECURE set IS_DEFAULT=0 where MID=$MID and CID=$CID";
		$udbh->do($pstmt);
		$dbupdates{'IS_DEFAULT'}=1;
		}
	
	if ($params{'attempts'}) {
		$dbupdates{'*ATTEMPTS'} = 'ATTEMPTS+1';
		}
	if ($params{'failure'}) {
		$dbupdates{'*FAILURES'} = 'FAILURES+1';
		}

	my ($pstmt) = &DBINFO::insert($udbh,'CUSTOMER_SECURE',\%dbupdates,sql=>1,update=>2,key=>['CID','MID','ID']);
	# print $pstmt."\n";
	$udbh->do($pstmt);
	
	&DBINFO::db_user_close();
	}

##
## securely stores some parameters
##
sub wallet_store {
	my ($self,$paymentsref,$EXPIRES_GMT) = @_;

	my ($USERNAME) = $self->username();

	require ZTOOLKIT::SECUREKEY;
	my $SECURE = &ZTOOLKIT::SECUREKEY::encrypt($self->username(),&buildparams($paymentsref));

	my $ID = 0;
	my $ERROR = undef;

	my $DESCRIPTION = '';

	if (defined $paymentsref->{'CC'}) {
		require ZPAY;
		if (($paymentsref->{'MM'} eq '') && ($paymentsref->{'YY'} eq '') && ($paymentsref->{'CC'} eq '')) { $ERROR = "No credit card data supplied to wallet"; }
		elsif (($paymentsref->{'MM'} eq '') && ($paymentsref->{'YY'} eq '')) { $ERROR = "No expiration supplied to wallet"; }
		elsif ($paymentsref->{'MM'} eq '') { $ERROR = 'Month field (MM) must contain data'; }
		elsif ($paymentsref->{'YY'} eq '') { $ERROR = 'Year field (YY) must contain data'; }
		elsif (int($paymentsref->{'MM'}) < 1) { $ERROR = 'Month field (MM) must contain a number between 1-12';  }
		elsif (int($paymentsref->{'MM'}) > 12) { $ERROR = 'Month field (MM) must contain a number between 1-12';  }
		elsif (not &ZPAY::cc_verify_length($paymentsref->{'CC'})) { $ERROR = 'Length of credit card is invalid'; }
 		elsif (not &ZPAY::cc_verify_expiration(sprintf("%02d",$paymentsref->{'MM'}), sprintf("%02d",$paymentsref->{'YY'}))) { $ERROR = 'Invalid expiration date on credit card'; }
		elsif (not &ZPAY::cc_verify_length($paymentsref->{'CC'})) { $ERROR = 'Length of credit card does not have enough digits.'; }
		elsif (not &ZPAY::cc_verify_checksum($paymentsref->{'CC'})) { $ERROR = 'Credit card checksum is invalid, please check the digits.'; }
		}
		
	if (defined $ERROR) {
		}
	elsif (defined $paymentsref->{'CC'}) {
		my $TYPE = '';
		if (substr($paymentsref->{'CC'},0,1) eq '4') { $TYPE = 'Visa'; }
		elsif (substr($paymentsref->{'CC'},0,1) eq '3') { $TYPE = 'AMEX'; }
		elsif (substr($paymentsref->{'CC'},0,1) eq '5') { $TYPE = 'MC'; }
		elsif (substr($paymentsref->{'CC'},0,1) eq '6') { $TYPE = 'Disc'; }
		else { $TYPE = '????'; }
		$DESCRIPTION = sprintf("%s-%s exp:%d/%d",$TYPE,substr($paymentsref->{'CC'},-4),
			$paymentsref->{'MM'},$paymentsref->{'YY'},
			);
		if ($EXPIRES_GMT==0) {
			## add 1 month to the credit card's expiration date
			require Date::Calc;
		
			my @EXPYYMMDD = (2000+int($paymentsref->{'YY'}),int($paymentsref->{'MM'}),1);
			# use Data::Dumper; print STDERR Dumper(\@EXPYYMMDD);
			$EXPIRES_GMT = Date::Calc::Mktime(
				Date::Calc::Add_Delta_YM(@EXPYYMMDD,0,1)
				,0,0,0);
			$EXPIRES_GMT -= 1;	# remove 1 second so it looks like we expire on the exact YY/MM at the last second.
			}
		}
	else {
		$DESCRIPTION = "Unknown ".join("|",keys %{$paymentsref});
		}

	if ($EXPIRES_GMT==0) { $EXPIRES_GMT = time()+(90*86400); }

	if (not defined $ERROR) {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my %params = ();
		$params{'MID'} = $self->mid();
		$params{'CID'} = $self->cid();
		$params{'*CREATED'} = 'now()';
		$params{'*EXPIRES'} = sprintf("from_unixtime(%d)",$EXPIRES_GMT);
		$params{'DESCRIPTION'} = $DESCRIPTION;
		$params{'SECURE'} = $SECURE;
		my $pstmt = &DBINFO::insert($udbh,'CUSTOMER_SECURE',\%params,sql=>1);
		$udbh->do($pstmt);
		($ID) = &DBINFO::last_insert_id($udbh);
		&DBINFO::db_user_close();
		}

	return($ID,$ERROR);
	}

##
## nukes a secure store
##
sub wallet_nuke {
	my ($self,$ID) = @_;
	my ($USERNAME) = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($CID) = $self->cid();
	my ($MID) = $self->mid();
	$ID = int($ID);
	my $pstmt = "delete from CUSTOMER_SECURE where MID=$MID and CID=$CID and ID=$ID";
	$udbh->do($pstmt);	
	&DBINFO::db_user_close();
	}



########################################################################
sub terms_add {
	my ($self) = @_;
	}

##
## creates a summarization record.
##
sub term_summarize {
	my ($self) = @_;

	my $CID = $self->cid();
	my $MID = $self->mid();
	my $USERNAME = $self->username();
	my $pstmt = "select * from CUSTOMER_PO_TRANSACTIONS where CID=$CID and MID=$MID /* $USERNAME */ and IS_OPEN>0";
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	&DBINFO::db_user_close();
	return();
	}




########################################
# PARSEPARAMS
# Description: Gets all of the params in a GET format URL
# Accepts: A list of he GET method params in URL format
# Returns: It returns a reference to a hash of all the parameters in
#          the URL.
sub parseparams {
	my ($string) = @_;

	my $params = {};
	if (not defined $string) { return $params; }

	foreach my $keyvalue (split /\&/, $string) {
		my ($key, $value) = split(/\=/, $keyvalue,2);
		if ((defined $value) && ($value ne '')) {
			$value =~ s/\+/ /g;
			$value =~ s/\%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
			$key =~ s/\+/ /g;
			$key =~ s/\%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
			$params->{$key} = $value;
			}
		else {
			delete $params->{$key};
			# $params->{$key} = '';
			}
		}
	return $params;
	}


##
## Converts a hashref to URI params (returns a string)
##    note: minimal defaults to 0
##    note: minimal of 1 means do not escape < > or / in data.
##
sub buildparams {
   my ($hashref,$minimal) = @_;

   if (not defined $minimal) { $minimal = 0; }
   my $string = '';

   foreach my $k (sort keys %{$hashref}) {
		next if (not defined $hashref->{$k});

      $string .= $k.'=';
      foreach my $ch (split(//,$hashref->{$k})) {
         if ($ch eq ' ') { $string .= '+'; }
         elsif (((ord($ch)>=48) && (ord($ch)<58)) || ((ord($ch)>64) &&  (ord($ch)<=127))) { $string .= $ch; }
         ## don't encode <(60) or >(62) /(47)
         elsif (((ord($ch)==60) || (ord($ch)==62) || (ord($ch)==47))) { $string .= $ch; }
         else { $string .= '%'.sprintf("%02x",ord($ch));  }
         }
      $string .= '&';
      }
   chop($string);
   return($string);
   }




##
## return's the schedule a customer is on, or blank if none.
##
sub is_wholesale {
	my ($self) = @_;
	my $result = '';
	if ($self->orgid()>0) {
		my $ORG = $self->org();
		$result = $ORG->schedule();
		}
	#if (my $schedule = $self->fetch_attrib('INFO.SCHEDULE')) {
	#	$result = $schedule;
	#	}
	return($result);
	}


##
## a simple function to determine if a customer is exempt from sales tax
##
sub is_tax_exempt {
	my ($self) = @_;
	my $exempt = 0;
	if ($self->is_wholesale()) {
		$exempt = ($self->fetch_attrib('WS.RESALE'))?1:0;
		}
	return($exempt);
	}


sub cid_to_prt {
	my ($USERNAME,$CID) = @_;

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);

	my $pstmt = "select PRT from $CUSTOMERTB where CID=$CID and MID=$MID /* $USERNAME */";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my ($PRT) = $sth->fetchrow();
	$sth->finish();
	&DBINFO::db_user_close();
	return($PRT);
	}


sub username { return($_[0]->{'_USERNAME'}); }
sub prt { my ($self) = @_; return($self->{'_PRT'}); }
sub mid { my ($self) = @_; return($self->{'_MID'}); }
sub cid { my ($self) = @_; return($self->{'_CID'});	}
sub email { my ($self) = @_; return($self->{'_EMAIL'}); }
sub orgid { my ($self) = @_; return(int($self->fetch_attrib('INFO.ORGID'))); }

##
## function: remap_customer_prt
##
## the "marion" (greatlookz) hack --
## allows customers to be remapped/loaded from partition 0 (or really any partition)
## regardless of which partition they actually exist
##
sub remap_customer_prt {
	my ($USERNAME,$PRT) = @_;

#	print STDERR "REMAP PRT: $PRT\n";
	if ($PRT>0) {
		my ($prtinfo) = &ZOOVY::fetchprt($USERNAME,$PRT);
#		print STDERR "PRT: $PRT ($prtinfo->{'p_customers'})\n";
		if (defined $prtinfo->{'p_customers'}) {
			$PRT = int($prtinfo->{'p_customers'});
			}
		}
	return(int($PRT));
	}


##
## there are a few ways to instantiate a customer object.
##
##		
##
sub new {
	my ($class, $USERNAME, %options) = @_;

	my $self = {};
	bless $self, 'CUSTOMER';

	if (not defined $options{'PRT'}) { $options{'PRT'} = 0; }

	my ($PRT) = int($options{'PRT'});
	$PRT = &CUSTOMER::remap_customer_prt($USERNAME,$PRT);

	if ((defined $options{'CREATE'}) && (int($options{'CREATE'})>0)) {
		## check to see if the customer already exists, then choose a behavior	
		## 	CREATE=>1 abort if exists		
		##		CREATE=>2 return customer, but don't update
		##		CREATE=>3 return customer, and update.
		$options{'CID'} = CUSTOMER::resolve_customer_id($USERNAME,$PRT,$options{'EMAIL'});
		if ($options{'CID'}) {
			if ($options{'CREATE'}==1) { 
				warn "Cannot create customer $options{'EMAIL'} because already assigned to CID $options{'CID'}";
				return(undef); 
				}
			elsif ($options{'CREATE'}==2) { $options{'CREATE'} = 0; }	# this will make sure downline we don't load
			elsif ($options{'CREATE'}==3) { $options{'INIT'} = 0xFF; }	# load all the customer settings so we can update
			}
		}

	$self->{'_PRT'} = $PRT;
	$self->{'_USERNAME'} = $USERNAME;
	$self->{'_MID'} = &ZOOVY::resolve_mid($USERNAME);

	if (defined $options{'CID'}) {
		$self->{'_CID'} = int($options{'CID'});
		$self->{'_EMAIL'} = &CUSTOMER::resolve_email($USERNAME,$PRT,int($options{'CID'}));
		}
	elsif (defined $options{'EMAIL'}) {
		$self->{'_CID'} = &CUSTOMER::resolve_customer_id($USERNAME,$PRT,$options{'EMAIL'});
		if (not defined $self->{'_CID'}) { $self->{'_CID'} = -1; }
		$self->{'_EMAIL'} = $options{'EMAIL'};
		}
	else {
		$self->{'_CID'} = -1;
		}

	$self->{'_STATE'} = 0;	
	if ($self->{'_CID'} <= 0) {
		## don't do lookups for data we don't have!
		}
	elsif (defined $options{'INIT'}) {
		##		_STATE = +1 --> initialized w/primary info
		if (($options{'INIT'}&1)==1) { $self->fetch_attrib('INFO.CID'); }	
		##		_STATE = +2 --> initialized w/billing info
		##		_STATE = +4 --> initialized w/shipping info
		##		_STATE = +8 --> initialized w/meta info
		if (($options{'INIT'}&14)>0) { $self->init_detail(); }
		if (($options{'INIT'}&8)==8) { $self->fetch_attrib('META'); }	
		##		_STATE = +16 --> initialized w/wholesale info (WS->{} populated)
		if (($options{'INIT'}&16)==16) { $self->fetch_attrib('WS'); }	
		##		_STATE = +32 --> initialized w/notes
		if (($options{'INIT'}&32)==32) { $self->fetch_notes(); }	
#		##		_STATE = +64 --> initialized w/tickets
#		if (($options{'INIT'}&64)==64) { $self->fetch_tickets(); }	

		##		_STATE = +128 --> initialized w/notifications
		if (($options{'INIT'}&128)==128) { $self->fetch_events(); }	
		}


	## pass CREATE to create a new account
	##		if we also pass DATA as a hashref of keys we can preset alot of stuff 
	##		(this can avoid two database saves, one to get a CID, one to update the info)
	if ( (defined $options{'CREATE'}) && (int($options{'CREATE'})>0) ) {
		$self->{'_CID'} = 0;
		$self->{'_STATE'} = 0xFF;
		
		if ((defined $options{'*CART2'}) && (ref($options{'*CART2'}) eq 'CART2')) {
			my ($O2) = $options{'*CART2'};
			my $webdb = $O2->webdb();
			$self->set_attrib('INFO.IP', $O2->in_get('cart/ip_address'));
			$self->{'INFO'}->{'FIRSTNAME'} = $O2->in_get('bill/firstname');
			$self->{'INFO'}->{'LASTNAME'} = $O2->in_get('bill/lastname');
			$self->{'INFO'}->{'PHONE'} = $O2->in_get('bill/phone');

			my $addr = {};

			my %billhash = ();
			$addr = $O2->get_address('bill');  
			foreach my $orderkey (keys %{$addr}) {
				my $addrkey = $orderkey;  $addrkey =~ s/\//_/; 
				$billhash{$addrkey} = $addr->{$orderkey};
				}

			my %shiphash = ();
			$addr = $O2->get_address('ship');  
			foreach my $orderkey (keys %{$addr}) {
				my $addrkey = $orderkey;  $addrkey =~ s/\//_/; 
				$shiphash{$addrkey} = $addr->{$orderkey};
				}

			#foreach my $k (keys %{$O2}) {
			#	# print STDERR "K: $k\n";
			#	if ($k =~ /^bill_/i) { $billhash{$k} = ${$oref}{$k}; }
			#	if ($k =~ /^ship_/i) { $shiphash{$k} = ${$oref}{$k}; }
			#	#if ($webdb->{"chkout_save_payment_disabled"}) {	}
			#	#elsif ($k =~ /^card/i) { $billhash{$k} = ${$oref}{$k}; }
			#	#elsif ($k =~ /^pay/i) { $billhash{$k} = ${$oref}{$k}; }
			#	}	

			$shiphash{'_IS_DEFAULT'}++;
			$billhash{'_HAS_CHANGED'}++;
			$shiphash{'ID'} = 'DEFAULT';
			delete $shiphash{'ship_email'};
			my ($shipaddr) = CUSTOMER::ADDRESS->new($self,'SHIP',\%shiphash);
			if (defined $shipaddr) {
				my ($SHORTCUT) = (defined $O2->in_get('ship/shortcut'))?$O2->in_get('ship/shortcut'):'DEFAULT';
				$self->add_address($shipaddr,'SHORTCUT'=>$SHORTCUT);
				}
			my ($billaddr) = CUSTOMER::ADDRESS->new($self,'BILL',\%billhash);
			if (defined $billaddr) {
				my ($SHORTCUT) = (defined $O2->in_get('bill/shortcut'))?$O2->in_get('bill/shortcut'):'DEFAULT';
				$self->add_address($billaddr,'SHORTCUT'=>$SHORTCUT);
				}

			}
		else {
			warn "Created customer without order! $options{'ORDER'}\n";
			}

		if ((defined $options{'DATA'}) && (ref($options{'DATA'}) eq 'HASH')) {
			foreach my $k (keys %{$options{'DATA'}}) {
				print STDERR "SET [$k] $options{'DATA'}->{$k}\n";
				$self->set_attrib($k,$options{'DATA'}->{$k});
				}
			}
	
		# use Data::Dumper; print STDERR Dumper($self,\%options);


   	## ORIGIN: 0 = unknown, 1 = website checkout, 99=signup form
		if (not defined $self->{'INFO'}->{'PRT'}) { $self->{'INFO'}->{'PRT'} = $PRT; }
		if (not defined $self->{'INFO'}->{'CREATED_GMT'}) { $self->{'INFO'}->{'CREATED_GMT'} = time(); }
		if (not defined $self->{'INFO'}->{'ORIGIN'}) { $self->{'INFO'}->{'ORIGIN'} = 0; }
		if (not defined $self->{'INFO'}->{'IP'}) { $self->{'INFO'}->{'IP'} = $ENV{'REMOTE_ADDR'}; }
		if (not defined $self->{'INFO'}->{'IS_AFFILIATE'}) { $self->{'INFO'}->{'IS_AFFILIATE'} = 0; }
		if (not defined $self->{'INFO'}->{'IS_LOCKED'}) { $self->{'INFO'}->{'IS_LOCKED'} = 0; }
		if (not defined $self->{'INFO'}->{'HINT_NUM'}) { 
			$self->{'INFO'}->{'HINT_NUM'} = 0; 
			$self->{'INFO'}->{'HINT_ANS'} = ''; 
			}

		$self->save();

		if ((defined $options{'*CART2'}) && (ref($options{'*CART2'}) eq 'CART')) {
			$self->associate_order($options{'CART2'}); 
			}
#		if ((defined $options{'ORDER'}) && (ref($options{'ORDER'}) eq 'ORDER')) {
#			$self->associate_order($options{'ORDER'}); 
#			}
		
		&ZOOVY::add_event($self->username(),'CUSTOMER.NEW','CID'=>$self->cid(),'EMAIL'=>$self->email());

		## END OF CREATE
		}

	return($self);	
	}


##
## returns an arrayref of all giftcards for a customer.
##
## OBFUSCATE=>1	returns them obfustcated
##
sub giftcards {
	my ($self, %options) = @_;

	my $ts = time();

	require GIFTCARD;
	my @CARDS = ();
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $pstmt = sprintf("select * from GIFTCARDS where MID=%s /* %s */ and CID=%d",&ZOOVY::resolve_mid($self->username()),$self->username(),$self->cid());
	my ($sth) = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $gcref = $sth->fetchrow_hashref() ) {
		next if ($gcref->{'BALANCE'}<=0);
		next if (($gcref->{'EXPIRES_GMT'}>0) && ($gcref->{'EXPIRES_GMT'}<$ts));

		push @CARDS, $gcref;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@CARDS);
	}



# Does the same as above but doesn't create the customer billing/shipping information and assumes they want spam
sub new_subscriber {
	my ($USERNAME, $PRT, $EMAIL, $FULLNAME, $IP, $ORIGIN, $NEWSLETTERS) = @_;

	($PRT) = &CUSTOMER::remap_customer_prt($USERNAME,$PRT);

	my $PASSWORD = undef;
	if ((not defined($PASSWORD)) || ($PASSWORD eq '')) {
		$PASSWORD = String::MkPasswd::mkpasswd(-length=>10,-minnum=>8,-minlower=>2,-minupper=>0,-minspecial=>0);
		}
	if (($EMAIL eq '') || ($FULLNAME eq ''))  {
		return (1,'Internal error: email and full name must be provided to CUSTOMER::new_subscriber');
		}
		
	if (not defined $NEWSLETTERS) {
		$NEWSLETTERS = 1;
		}

	my ($firstname,$lastname) = split(/ /,$FULLNAME,2);

	my ($C) = CUSTOMER->new($USERNAME,EMAIL=>$EMAIL,CREATE=>1,
		'PRT'=>$PRT,
		'DATA'=>{
			'INFO.IP'=>$IP,
			'INFO.ORIGIN'=>$ORIGIN,
			'INFO.FIRSTNAME'=>$firstname,
			'INFO.LASTNAME'=>$lastname,
			'INFO.NEWSLETTER'=>$NEWSLETTERS,
			}
		);

	if (not defined $C) {
		return(2,"User $EMAIL already exists");
		}
	else {
		return(0,'');
		}
	}



sub update_reward_balance {
	my ($self, $i, $reason) = @_;

	my $odbh = &DBINFO::db_user_connect($self->username());
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($self->username(),$self->mid());

	my $sql = undef;
	if (substr($i,0,1) eq '=') {
		$sql = sprintf("%d",substr($i,1));
		$self->{'INFO'}->{'REWARD_BALANCE'} = int(substr($i,1));
		}
	else {
		$sql = "IFNULL(REWARD_BALANCE,0)+".int($i);
		$self->{'INFO'}->{'REWARD_BALANCE'} += int($i);
		}
	my $pstmt = sprintf("update $CUSTOMERTB set REWARD_BALANCE=%s where MID=%d and PRT=%d and CID=%d /* rewards update */",$sql,$self->mid(),$self->{'_PRT'},$self->cid());
#	print STDERR $pstmt."\n";
	$odbh->do($pstmt);
	
	my ($path) = &ZOOVY::resolve_userpath($self->username());
	open F, ">>$path/rewards.log";
	print F &ZTOOLKIT::pretty_date(time(),2)."\t$self->{'_CID'}\t$i\t$reason\n";
	close F;

	&DBINFO::db_user_close();
	}



##
## saves changes to the database
##
sub save {
	my ($self, %params) = @_;

	my $odbh = &DBINFO::db_user_connect($self->username());
	if (($self->{'_STATE'} & 1)==1) {
		$self->{'_EMAIL'} =~ s/[^\w\+\-\.\@\!\_]+//g;
		my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($self->username(),$self->mid());

		if ($self->{'_CID'} == 0) {
			## okay, this means we haven't actually attempted to lookup the CID yet, so we'll treat it like a failure
			## and let the next block below which attempts to verify that the customer doesn't already exist do its thing.
			$self->{'_CID'} = -1;			
			}

		if (($self->{'_CID'} == -1) && (defined $self->{'_EMAIL'}) && ( $self->{'_EMAIL'} ne '') ) {
			## make sure the customer doesn't already exist!
			my ($MID) = $self->mid();
			my $pstmt = "select CID from $CUSTOMERTB where MID=$MID and PRT=".int($self->{'_PRT'})." and EMAIL=".$odbh->quote($self->{'_EMAIL'})." /* customer_save */";
			my $sth = $odbh->prepare($pstmt);
			$sth->execute();
			if ($sth->rows()>0) { ($self->{'_CID'}) = $sth->fetchrow(); }
			$sth->finish();
			}



		if ($self->{'_CID'} == -1) {
			## new customer -- add record, this update it.
			if (not defined $self->{'INFO'}->{'ORIGIN'}) { $self->{'INFO'}->{'ORIGIN'} = ''; }

			my $pstmt = &DBINFO::insert($odbh,$CUSTOMERTB,{
				CID=>0, MID=>$self->mid(), USERNAME=>$self->username(), EMAIL=>$self->{'_EMAIL'},
				ORIGIN=>$self->{'INFO'}->{'ORIGIN'}, 
				IP=>ip_to_int($self->{'INFO'}->{'IP'}), CREATED_GMT=>time(), MODIFIED_GMT=>time(),
				PRT=>int($self->{'_PRT'}),				
				},debug=>2,key=>['MID','PRT','EMAIL']);
			print STDERR "$pstmt\n";
			$odbh->do($pstmt);

			$pstmt = "select last_insert_id()";
			$self->{'_CID'} = $odbh->selectrow_array($pstmt);
			}
		
		## setup _DEFAULT_SHIP and _DEFAULT_BILL
		foreach my $TYPE ('SHIP','BILL') {
			if ((defined $self->{'_DEFAULT_'.$TYPE}) && ($self->{'_DEFAULT_'.$TYPE}>=0)) {
				## wow.. this is already setup correctly! does the position really exist?
				if (not defined $self->{$TYPE}->[$self->{'_DEFAULT_'.$TYPE}]) {
					$self->{'_DEFAULT_'.$TYPE} = -1; 	## position was set? but did not exist! reset to -1
					}
				}
			elsif ((defined $self->{$TYPE}) && (scalar(@{$self->{$TYPE}})>0)) {
			## default ship isn't setup! - but we have data so initialize to first array position!
				$self->{'_DEFAULT_'.$TYPE} = 0;
				}
			else {
				## failsafe -- damn!
				$self->{'_DEFAULT_'.$TYPE} = -1;
				}
			}

		if (defined $self->{'INFO'}->{'FULLNAME'}) {
			## for backward compatibility - if set, this wins!
			($self->{'INFO'}->{'FIRSTNAME'},$self->{'INFO'}->{'LASTNAME'}) = 	split(/[\s]+/,$self->{'INFO'}->{'FULLNAME'},2);
			}
	
		my %ref = ();
		$ref{'CID'} = $self->{'_CID'};
		$ref{'MID'} = $self->mid();
		$ref{'PRT'} = $self->{'_PRT'};

		if ($self->{'INFO'}->{'EMAIL'} ne $self->{'_EMAIL'}) {	
			## we've modified the email address in the customer object.
			$ref{'EMAIL'} = $self->{'INFO'}->{'EMAIL'};
			}

		$ref{'MODIFIED_GMT'} = time();
		$ref{'NEWSLETTER'} = $self->{'INFO'}->{'NEWSLETTER'};
		$ref{'FIRSTNAME'} = $self->{'INFO'}->{'FIRSTNAME'};
		$ref{'LASTNAME'} = $self->{'INFO'}->{'LASTNAME'};
		$ref{'IS_AFFILIATE'} = $self->{'INFO'}->{'IS_AFFILIATE'};
		$ref{'IS_LOCKED'} = $self->{'INFO'}->{'IS_LOCKED'};
		$ref{'ORGID'} = $self->{'INFO'}->{'ORGID'};

		if ($self->{'INFO'}->{'HAS_NOTES'}>0) { 
			$ref{'HAS_NOTES'} = int($self->{'INFO'}->{'HAS_NOTES'});
			} 		
		## $ref{'SCHEDULE'} = $self->{'INFO'}->{'SCHEDULE'};
		$ref{'LASTLOGIN_GMT'} = $self->{'INFO'}->{'LASTLOGIN_GMT'};
		$ref{'LASTORDER_GMT'} = $self->{'INFO'}->{'LASTORDER_GMT'};
		$ref{'ORDER_COUNT'} = $self->{'INFO'}->{'ORDER_COUNT'};

		if ($self->{'INFO'}->{'PHONE'} eq '') {
			if (defined $self->{'BILL'}->[0]) { 
				$self->{'INFO'}->{'PHONE'} = $self->{'BILL'}->[0]->{'bill_phone'};
				}
			}
		if (defined $self->{'INFO'}->{'PHONE'}) {
			$ref{'PHONE'} = $self->{'INFO'}->{'PHONE'};
			$ref{'PHONE'} =~ s/[^\d]+//gs; 	# strip non-numbers.
			}

		if (defined $self->{'INFO'}->{'HINT_ANSWER'}) {
			## this could probably use a bit more TLC
			$ref{'HINT_ANSWER'} = $self->{'INFO'}->{'HINT_ANSWER'};
			$ref{'HINT_NUM'} = $self->{'INFO'}->{'HINT_NUM'};
			}		

		$ref{'HINT_ATTEMPTS'} = $self->{'INFO'}->{'HINT_ATTEMPTS'};

		if ($params{'%INFO'}) {
			## usually used for updating password type fields (that aren't stored in customer record)
			foreach my $k (keys %{$params{'%INFO'}}) {
				$ref{$k} = $params{'%INFO'}->{$k};
				}
			}

		## clear out null keys (in case we just created this customer)
		foreach my $k (keys %ref) {
			next if ($k eq 'CID');
			if (not defined $ref{$k}) { delete $ref{$k}; }
			}
		my $pstmt = &DBINFO::insert($odbh,$CUSTOMERTB,\%ref,key=>['CID','MID','PRT'],verb=>'update',sql=>1);
		print STDERR "[insert] ".$pstmt."\n";
		
		# print STDERR $pstmt."\n";
		my $rv = $odbh->do($pstmt);

		if ($ref{'CID'}==0) {
			## we inserted a new customer, so lets lookup the cid and set _CID
			($self->{'_CID'}) = &DBINFO::last_insert_id($odbh);
			}
		}

	if (($self->{'_STATE'} & 14)>0) {
		print STDERR "SAVING ADDRESSES\n";

		foreach my $addr (@{$self->fetch_addresses('BILL')}) {
			next unless ($addr->has_changed());
			$addr->store();
			}
		foreach my $addr (@{$self->fetch_addresses('SHIP')}) {
			next unless ($addr->has_changed());
			$addr->store();
			}
		&CUSTOMER::store_addr($self->username(),$self->cid(),'META',$self->{'META'});
		}
	else {
		warn "did not store address\n";
		}

	if (($self->{'_STATE'} & 16) == 16) {
		if ((defined $self->{'WS'}) && (ref($self->{'WS'}) eq 'CUSTOMER::ORGANIZATION')) {
			$self->{'WS'}->save();
			}
		}
		
	&ZOOVY::add_event($self->username(),'CUSTOMER.SAVE','CID'=>$self->cid(),'EMAIL'=>$self->email());

	&DBINFO::db_user_close();
	return($self->cid());
	}


##
sub as_xml { require CUSTOMER::XML; return(&CUSTOMER::XML::as_xml(@_)); }
sub from_xml { require CUSTOMER::XML; return(&CUSTOMER::XML::from_xml(@_)); }


##
## formerly: save_ship_info save_bill_info, replaced by addr->store() but still performs
##		save for META (keeping it generic just in case we need something lese besides META in the future)
##		also performs BILL,SHIP save as part of a fast CHECKOUT::finalize
##
sub store_addr {
   my ($USERNAME,$CID,$TYPE,$INFOREF) = @_;

   if (int($CID)<=0) {
      warn "Invalid CID[$CID] passed to store_addr for $USERNAME/$TYPE";
      return();
      }

   if (not defined $INFOREF) { return(undef); }
   if (scalar(keys %{$INFOREF})==0) { return(undef); }

   my $MID = &ZOOVY::resolve_mid($USERNAME);
   my $IS_DEFAULT = 0;
   if ($INFOREF->{'_IS_DEFAULT'}) { $IS_DEFAULT++; }
   delete $INFOREF->{'_IS_DEFAULT'};

   my $CODE = $INFOREF->{'ID'};
   delete $INFOREF->{'ID'};
   if ($CODE eq '') { $CODE = $TYPE; }

   my ($addrtb) = &CUSTOMER::resolve_customer_addr_tb($USERNAME,$MID);
   my $odbh = &DBINFO::db_user_connect($USERNAME);
   &DBINFO::insert($odbh,$addrtb,{
      INFO=>&CUSTOMER::buildparams($INFOREF),
      MID=>$MID,
      PARENT=>$CID,
      USERNAME=>$USERNAME,
      TYPE=>$TYPE,
      CODE=>$CODE,
      IS_DEFAULT=>$IS_DEFAULT,
      },key=>['PARENT','MID','TYPE','CODE'],debug=>1);
   &DBINFO::db_user_close();

   $INFOREF->{'ID'} = $CODE;

   return(0);
   }



##
## save a note, updates $self->{'@NOTES'} and INFO.HAS_NOTES correctly.
##	returns the new note id. 
##
sub save_note {
	my ($self, $LUSER, $NOTE, $TS) = @_;

	if ((not defined $TS) || ($TS==0)) {
		$TS = time();
		}

	if (not defined $self->{'@NOTES'}) { 
		$self->fetch_notes(); 
		}

	my $dbh = &DBINFO::db_user_connect($self->username());
	my $pstmt = &DBINFO::insert($dbh,'CUSTOMER_NOTES',{
		MID=>int($self->mid()),
		CID=>int($self->cid()),
		MERCHANT=>$self->username(),
		LUSER=>$LUSER,
		CREATED_GMT=>$TS,
		NOTE=>$NOTE
		},debug=>2);
	# print STDERR "$pstmt\n";
	$dbh->do($pstmt);
	
	$pstmt = "select last_insert_id();";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my ($ID) = $sth->fetchrow();
	$sth->finish();

	if ($ID>0) {
		if (not defined $self->{'@NOTES'}) { $self->{'@NOTES'} = []; }
		push @{$self->{'@NOTES'}}, { ID=>$ID, LUSER=>$LUSER, CREATED_GMT=>time(), NOTE=>$NOTE };
		my $cnt = scalar(@{$self->{'@NOTES'}});
		$self->set_attrib('INFO.HAS_NOTES', $cnt);
		# print STDERR "CNT: $cnt\n";
		if ($cnt<3) {
			## if the cnt field is zero or one and we're in this function then we should update it
			## because some of the UI components use HAS_NOTES to hint if they should show them at all.
			$self->save();
			}
		}

	&DBINFO::db_user_close();
	return($ID);
	}



###############################################################################
# Get all the orders for a customer
#
# returns: an array of order numbers
#
sub fetch_orders {
	my ($self) = @_;

	my $odbh = &DBINFO::db_user_connect($self->username());
	my $USERNAME = $self->username();
	my ($MID) = &ZOOVY::resolve_mid($self->username());
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($self->username(),$MID);

	my $CID = $self->cid();

	my @orders = ();
	if ($CID<=0) { 
		warn "Customer [$CID] has no orders! M[$USERNAME]\n";
		}
	else {	
		my $ORDERTB = &DBINFO::resolve_orders_tb($USERNAME,$MID);
		my $pstmt = "select ORDERID,ORDER_TOTAL,CREATED_GMT,ORDER_SHIP_ZONE,ORDER_PAYMENT_METHOD,ORDER_PAYMENT_STATUS,ITEMS,SHIPPED_GMT from $ORDERTB where MID=$MID and CUSTOMER=$CID order by ID desc limit 0,50";
		my $sth = $odbh->prepare($pstmt);
		$sth->execute();
		while ( my $ref = $sth->fetchrow_hashref()) { 
			push @orders, $ref;
			}
		$sth->finish();
		}

	&DBINFO::db_user_close();

	return (\@orders);
	}

##
## loads the notes from the customer database (part the CRM package)
##
sub fetch_notes {	
	my ($self) = @_;

	if (defined $self->{'@NOTES'}) {
		return($self->{'@NOTES'});
		}

	my $counter = 0;
	$self->{'@NOTES'} = [];

	my $dbh = &DBINFO::db_user_connect($self->username());
	my $pstmt = "select ID,LUSER,CREATED_GMT,NOTE from CUSTOMER_NOTES where MID=".int($self->mid()).' and CID='.int($self->cid()).' order by ID desc';
	print STDERR $pstmt."\n";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		$counter++;
		push @{$self->{'@NOTES'}}, $hashref;
		}
	$sth->finish();
	$self->set_attrib('INFO.HAS_NOTES',$counter);
	&DBINFO::db_user_close();

	return($self->{'@NOTES'});
	}




##
## loads the notes from the customer database (part the CRM package)
##
sub fetch_events {	
	my ($self) = @_;

	if (defined $self->{'@EVENTS'}) {
		return($self->{'@EVENTS'});
		}


	my $counter = 0;
	$self->{'@EVENTS'} = [];

	my $udbh = &DBINFO::db_user_connect($self->username());
	my $pstmt = "select * from USER_EVENTS_FUTURE where MID=".int($self->mid()).' and CID='.int($self->cid()).' order by ID desc';
	print STDERR $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my $expires_gmt = $^T-(86400*365);	# the oldest event we'll show.
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		next if ($hashref->{'CREATED_GMT'}<$expires_gmt);

		$counter++;
		if ($hashref->{'TYPE'} eq 'INVENTORY') {
			if ($hashref->{'PROCESSED_GMT'}==0) {
				$hashref->{'*PRETTY'} = "will be automatically notified when item $hashref->{'UUID'} is back in stock.";
				}
			else {
				$hashref->{'*PRETTY'} = "was automatically notified on ".&ZTOOLKIT::pretty_date($hashref->{'PROCESSED_GMT'})." that item $hashref->{'UUID'} is back in stock.";
				}
			}

		push @{$self->{'@EVENTS'}}, $hashref;
		}
	$sth->finish();
	$self->set_attrib('INFO.HAS_EVENTS',$counter);
	&DBINFO::db_user_close();

	return($self->{'@EVENTS'});
	}



##
## removes/hides a customer note
##
sub nuke_note {
	my ($self, $NID) = @_;

	$NID = int($NID);
	my $dbh = &DBINFO::db_user_connect($self->username());
	my $pstmt = "delete from CUSTOMER_NOTES where MID=".int($self->mid()).' and CID='.int($self->cid()).' and ID='.int($NID);
	$dbh->do($pstmt);
	&DBINFO::db_user_close();	
	
	return(0);	
	}


##
## removes an address from the database and in memory @SHIP or @BILL customer object
## delete_address
sub nuke_addr {
	my ($self,$TYPE,$SHORTCUT) = @_;

	my $USERNAME = $self->username();
	my $CID = $self->cid();

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my $qtTYPE = $odbh->quote($TYPE);
	my $qtCODE = $odbh->quote($SHORTCUT);
	my ($ADDRTB) = &CUSTOMER::resolve_customer_addr_tb($USERNAME,$MID);
	my $pstmt = "delete from $ADDRTB where PARENT=".int($CID)." and MID=$MID /* $USERNAME */ and TYPE=$qtTYPE and CODE=$qtCODE";
	print STDERR "$pstmt\n";
	$odbh->do($pstmt);

	my $addr_array_ref = $self->{uc("\@$TYPE")};	# @BILL @SHIP
	if (defined $addr_array_ref) {
		my @NEW_ADDR_ARRAY = ();
		foreach my $addr (@{$addr_array_ref}) {
			if ($addr->shortcut() eq $SHORTCUT) { 
				## delete from @BILL or @SHIP
				}
			else {
				push @NEW_ADDR_ARRAY, $addr;
				}
			}
		$self->{uc("\@$TYPE")} = \@NEW_ADDR_ARRAY;
		}


	&DBINFO::db_user_close();	
	return();
	}



##
## takes an address ref, and saves it to a position
##		used in online customer editor.
##		used in CUSTOMER::XML::from_xml
##	TYPE is: BILL, SHIP
##
sub add_address {
	my ($self, $addr, %options) = @_;

	if ($options{'SHORTCUT'}) { $addr->{'ID'} = uc($options{'SHORTCUT'}); }
	$addr->{'_HAS_CHANGED'}++;

	if (($self->{'STATE'} & 14)==0) {	
		$self->init_detail();
		}

	my $TYPE = $addr->type();
	my $existsref = $self->{uc("\@$TYPE")}; # @BILL, @SHIP
	my @NEW_ADDR_ARRAY = ();
	my $found = 0;
	foreach my $exist (@{$existsref}) {
		if ($exist->shortcut() eq $addr->shortcut()) {
			$found++;
			push @NEW_ADDR_ARRAY, $addr;
			}
		else {
			push @NEW_ADDR_ARRAY, $exist;
			}
		}
	if (not $found) { push @NEW_ADDR_ARRAY, $addr; }
	$self->{uc("\@$TYPE")} = \@NEW_ADDR_ARRAY;

	return($addr);
	}


##
## initializes a customer password and returns it
##
## 	options: 
##			reset=>1 (this is the default behavior)
##			set=>password
##
sub initpassword {
	my ($self,%options) = @_;

	my ($PASSWORD) = String::MkPasswd::mkpasswd(-length=>8,-minnum=>2,-minlower=>2,-minupper=>0,-minspecial=>0);
	if (defined $options{'set'}) {
		## this will force the password to be whatever the value of set is
		$PASSWORD = $options{'set'};
		warn "Setting password to $PASSWORD\n";
		}

	my $SALT = String::MkPasswd::mkpasswd(-length=>6,-minnum=>2,-minlower=>1,-minupper=>1,-minspecial=>1,-distribute=>1);		
	my %INFO = ();
	$INFO{'PASSWORD'} = $PASSWORD;	# INFO.PASSWORD
	$INFO{'PASSSALT'} = $SALT;			# INFO.PASSSALT
	$INFO{'PASSHASH'} = Digest::SHA1::sha1_base64( sprintf("%s%s",$PASSWORD,$SALT) ).'=';	# INFO.PASSHASH

	#$self->set_attrib('INFO.PASSWORD',$PASSWORD);
	#$self->set_attrib('INFO.PASSSALT', $SALT);
	#$self->set_attrib('INFO.PASSHASH', Digest::SHA1::sha1_base64( sprintf("%s%s",$PASSWORD,$SALT) ).'=');
	$self->save('%INFO'=>\%INFO);

	return($PASSWORD);
	}


sub set_attrib {
	my ($self,$property,$value) = @_;

	my $ROUTE = substr($property,0,1);
		## _ = internal property (e.g. _CID, _EMAIL, _MID, _USERNAME)
		##	I => info (_STATE & 1) 
		##	B => billing (_STATE & 2)
		## S => shipping (_STATE & 4)
		##	M => meta (_STATE & 8)
		## W => wholesale (_STATE & 16)
		##
	if ($ROUTE eq '_') {
		return($self->{$property});
		}
	elsif ($ROUTE eq 'I') {				## INFO
		if (length($property) == 4) { 
			$self->{'INFO'} = $value; #  sets the entire hash (DANGEROUS!)
			}	
		else { 
			if ($property eq 'INFO.FULLNAME') {
				my ($firstname,$lastname) = split(/ /,$value,2);
				if ($lastname =~ /^[A-Z][\.]? (.*?)$/) { $lastname = $1; }	## discard middle initial
				$self->set_attrib('INFO.FIRSTNAME',$firstname);
				$self->set_attrib('INFO.LASTNAME',$lastname);
				}
			else {
				$self->{'INFO'}->{substr($property,5)} = $value;  #  sets a specific property		
				}
			} 
		}	
	elsif ($ROUTE eq 'M') {				## META
		if (length($property) == 4) { 
			$self->{'META'} = $value; #  sets the entire hash (DANGEROUS!)
			}	
		else { 
			$self->{'META'}->{substr($property,5)} = $value;  #  sets a specific property		
			} 
		}	
	elsif ($ROUTE eq 'W') {				## WS
		if (length($property) == 2) { 
			$self->{'WS'} = $value; #  sets the entire hash (DANGEROUS!)
			}	
		else { 
			my $property = substr($property,3);
			## the line below lets us start using WS.address1 instead of WS.ws_address1
			if ((lc($property) eq $property) && ($property =~ /^ws_/)) { $property = substr($property,3); }
			$self->{'WS'}->set( $property, $value );
			} 
		}	
	}

## get is an alias for fetch_attrib
sub get { return(&CUSTOMER::fetch_attrib(@_)); }
sub set { return(&CUSTOMER::set_attrib(@_)); }


##
## customer detail (also called customer address [but it hold meta too!]
##
sub init_detail {
	my ($self) = @_;

	## This is now a universal handler for all types META, BILL, SHIP

	if (($self->{'STATE'} & 14)>0) {
		## Already initialized!
		}
	else {
		$self->{'_DEFAULT_BILL'} = -1;
		$self->{'_STATE'} = $self->{'_STATE'} | 14;
		$self->{'@BILL'} = [];
		$self->{'@SHIP'} = [];
		$self->{'%META'} = {};
		$self->{'%BILL_DEFAULT'} = undef;
		$self->{'%SHIP_DEFAULT'} = undef;
		}

	if (($self->{'STATE'} & 14)>0) {
		## Already initialized!
		}
	elsif ($self->cid() == -1) {
		## cannot initialize (because we don't know the customer id)
		$self->{'STATE'} |= 14;
		}
	else {
		my $odbh = &DBINFO::db_user_connect($self->username());
		my ($addrtb) = &CUSTOMER::resolve_customer_addr_tb($self->username(),$self->mid());
		my ($MID) = int($self->mid());
		my ($CID) = int($self->cid());
		my $pstmt = "select TYPE,CODE,INFO,IS_DEFAULT from $addrtb where MID=$MID /* $self->username() */ and PARENT=$CID";
		my $sth = $odbh->prepare($pstmt);
		$sth->execute();

		while ( my ($TYPE,$CODE,$INFO,$IS_DEFAULT) = $sth->fetchrow() ) {
			## deserialize all the address fields.
			if ($TYPE eq 'META') {
				$self->{'%META'} = &CUSTOMER::parseparams($INFO);
				}
			elsif ($TYPE eq 'BILL') {
				my ($inforef) = &CUSTOMER::parseparams($INFO);

				my ($addr) = CUSTOMER::ADDRESS->new($self,'BILL',{},'SHORTCUT'=>$CODE,'IS_DEFAULT'=>$IS_DEFAULT);				
				if ($inforef->{'countrycode'}) { 
					$addr->from_hash($inforef); 
					}
				else { 
					$addr->from_legacy($inforef); 
					}

				push @{$self->{'@BILL'}}, $addr;
				if ($IS_DEFAULT) { $self->{'_BILL_DEFAULT'} = scalar(@{$self->{'@BILL'}})-1; }
				}
			elsif ($TYPE eq 'SHIP') {
				my ($inforef) = &CUSTOMER::parseparams($INFO);
				$inforef->{'TYPE'} = $TYPE;
				my ($addr) = CUSTOMER::ADDRESS->new($self,'SHIP',{},'SHORTCUT'=>$CODE,'IS_DEFAULT'=>$IS_DEFAULT);
				if ($inforef->{'countrycode'}) { 
					$addr->from_hash($inforef); 
					}
				else { 
					$addr->from_legacy($inforef); 
					}
				push @{$self->{'@SHIP'}}, $addr;
				if ($IS_DEFAULT) { $self->{'_SHIP_DEFAULT'} = scalar(@{$self->{'@SHIP'}})-1; }
				}
			else {
				warn "UNKNOWN CUSTOMER NESTED RECORD TYPE: $TYPE\n";
				}
			}
		
		if (not defined $self->{'_BILL_DEFAULT'}) {
			## no _BILL_DEFAULT, see if we have one
			if (scalar(@{$self->{'@BILL'}})>0) { $self->{'_BILL_DEFAULT'} = $self->{'@BILL'}->[0]; }
			}

		if (not defined $self->{'_SHIP_DEFAULT'}) {
			## no _BILL_DEFAULT, see if we have one
			if (scalar(@{$self->{'@SHIP'}})>0) { $self->{'_SHIP_DEFAULT'} = $self->{'@SHIP'}->[0]; }
			}

		## remind us that we've already been here (2+4+8)
		$self->{'STATE'} |= 14;

		# print STDERR Dumper($self->{'@BILL'},$self->{'@SHIP'});
		&DBINFO::db_user_close();
		# warn "FINISHED init_default()\n";
		}


	return();
	}

sub bill_addrs {
	my ($self) = @_;
	$self->init_detail();
	if (not defined $self->{'@BILL'}) { $self->{'@BILL'} = []; }
	return($self->{'@BILL'});
	}

sub ship_addrs {
	my ($self) = @_;
	$self->init_detail();
	if (not defined $self->{'@SHIP'}) { $self->{'@SHIP'} = []; }
	return($self->{'@SHIP'});
	}


##
## a in-direct (forward compatible) way to access @SHIP and @BILL and WS addresses
##
sub fetch_addresses {
	my ($self,$TYPE) = @_;

	$TYPE = uc($TYPE);
	$self->init_detail();
	## NOTE: $ID [in future] could be #0 to access specific location
	##			if $ID is blank, then we'll assume we're talking about default.
	if ($TYPE eq 'BILL') {
		return($self->{'@BILL'});
		}
	elsif ($TYPE eq 'SHIP') {
		return($self->{'@SHIP'});		
		}
	else {
		warn "CUSTOMER::fetch_addresses UNKNOWN ADDRESS TYPE: $TYPE - returning []\n";
		return([]);
		}

	warn "CUSTOMER::fetch_addresses THIS LINE SHOULD NEVER BE REACHED\n";
	return([]);
	}


##
## returns the organiztion for the current customer
##
sub org {
	my ($self, %options) = @_;

	if (not $self->{'*ORG'}) {
		if ($self->orgid()>0) {
			$self->{'*ORG'} = CUSTOMER::ORGANIZATION->new_from_orgid($self->username(),$self->prt(),$self->orgid());
			}
		}
	return($self->{'*ORG'});
	}


##
## the best way to access 
##
sub fetch_address {
	my ($self,$TYPE,$SHORTCUT) = @_;

	$TYPE = uc($TYPE);

	my $thisaddr = undef;
	if (($TYPE ne 'BILL') && ($TYPE ne 'SHIP')) {
		warn "TYPE must be set\n";
		}
	elsif ($SHORTCUT eq '') {
		warn "SHORTCUT '' will always return blank address ref. (for non WS types)\n";
		$thisaddr = CUSTOMER::ADDRESS->new($self,$TYPE,{});
		}
	
	if (not defined $thisaddr) {
		foreach my $addr (@{$self->fetch_addresses($TYPE)}) {
			next if (defined $thisaddr);
			if ($addr->shortcut() eq $SHORTCUT) {
				$thisaddr = $addr;
				}
			}
		}

	return($thisaddr);
	}

##
##
##
sub fetch_preferred_address {
	my ($self,$TYPE) = @_;

	my $bestaddr = undef;
	my $addrs = $self->fetch_addresses($TYPE); 
	if ((defined $addrs) && (scalar(@{$addrs}>0))) {
		## first, find the first default address
		foreach my $tryaddr (@{$addrs}) {
			next if (defined $bestaddr);
			if ($tryaddr->is_default()) { $bestaddr = $tryaddr; }
			}
		## okay, if bestaddr is not set, then we should just use the first addr (none are default)
		if (not defined $bestaddr) {
			$bestaddr = $addrs->[0];
			}
		}
	return($bestaddr);
	}


##
## this will DYNAMICALLY load properties as they are needed from the different tables.
## the _STATE value is initialized	
##
## NOTE: all properties have a leading character that tells us where we're going.
##	 e.g. BILL is "B", SHIP is "S", META is "M"
##
## if we're dealing with an array like SHIP or BILL, then pos * returns a ref to all arrays
##	or it's the number of the array
##
## 	e.g. fetch_attrib('BILL.COMPANY',0);	# would return the company name for the first shipping address
## 	e.g. fetch_attrib('BILL.*',0);			# would return the address ref
##
sub fetch_attrib {
	my ($self, $property, $pos) = @_;

	# print STDERR "fetch_attrib [$property]\n";

	my $ROUTE = substr($property,0,1);
		## _ = internal property (e.g. _CID, _EMAIL, _MID, _USERNAME)
		##	I => info (_STATE & 1) 
		##	B => billing (_STATE & 2)
		## S => shipping (_STATE & 4)
		##	M => meta (_STATE & 8)
		## W => wholesale (_STATE & 16)
		##
	if ($ROUTE eq '_') {
		return($self->{$property});
		}
	elsif ($self->{'_CID'}<=0) {
		## no data, don't do lookup
		}
	elsif ($ROUTE eq 'I') {				## INFO
		if (($self->{'_STATE'} & 1)==0) {			
			$self->{'_STATE'} = $self->{'_STATE'} | 1;
			if ($self->cid()==-1) {
				}
			else {
				my $odbh = &DBINFO::db_user_connect($self->username());
				my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($self->username(),$self->mid());
				my $qtEMAIL = $odbh->quote($self->{'_EMAIL'});
				my $MID = int($self->mid());
				my $pstmt = "select * from $CUSTOMERTB where MID=$MID and PRT=".int($self->{'_PRT'})." and EMAIL=$qtEMAIL /* fetch_attrib:I */";
				print STDERR $pstmt."\n";
				my $sth = $odbh->prepare($pstmt);
				my $rv = $sth->execute();
				my $ref = $sth->fetchrow_hashref();
				$sth->finish();
				&DBINFO::db_user_close();
				if (defined $ref) {
					delete $ref->{'PASSWORD'};
					#$ref->{'MODIFIED_GMT'} = &ZTOOLKIT::mysql_to_unixtime($ref->{'MODIFIED'});
					#$ref->{'CREATED_GMT'} = &ZTOOLKIT::mysql_to_unixtime($ref->{'CREATED'});
					#$ref->{'NEWSLETTER'} = $ref->{'LIKES_SPAM'}; delete $ref->{'LIKES_SPAM'};
					$ref->{'IP'} = int_to_ip($ref->{'IP'});
					$self->{'INFO'} = $ref;
					}
				}
			}
		if (length($property) == 4) { return ($self->{'INFO'}); }	#  returns the entire hash
		return($self->{'INFO'}->{substr($property,5)});				#  returns a specific property		
		}
	elsif ($ROUTE eq 'M') {
		my ($xTYPE,$xATTRIB) = split(/\./,$property);		## property is BILL.* or BILL.PROPERTY
		$self->init_detail();		## this can be called as often as necessary.
		if (length($property) == 4) { return ($self->{'META'}); }	#  returns the entire hash
		return($self->{'META'}->{substr($property,5)});				#  returns a specific property				
		}
	elsif (($ROUTE eq 'B') || ($ROUTE eq 'S')) { 
		my ($xTYPE,$xATTRIB) = split(/\./,$property);		## property is BILL.* or BILL.PROPERTY
		$self->init_detail();
		Carp::cluck("Don't load [$property] C->fetch_attrib('BILL') or C->fetch_attrib('SHIP') .. it's deprecated and will be removed.!\n");

		if ($property eq 'BILL') {
			return($self->{'@BILL'});
			}
		elsif ($property eq 'SHIP') {
			return($self->{'@SHIP'});
			}
		## here's how this works:
		##		BILL|SHIP undef => returns the full array ref
		##		BILL|SHIP -1 => returns the default entry
		##		BILL|SHIP 0-n => returns the specific entry
		##	(NOTE: we can't target specific attributes, because you always deal with addresses holistically)
		##	meaning if the state changes, so does the zip!
		warn "POS[$pos] it appears we're actually trying to get a property of the default address. EVEN WORSE!\n";
		my $ADDRESS = undef;
		if ($xTYPE eq 'BILL') {
			$ADDRESS = $self->{'%BILL_DEFAULT'};
			if ($pos>=0) { $ADDRESS = $self->{'@BILL'}->[$pos]; }
			}
		elsif ($xTYPE eq 'SHIP') {
			$ADDRESS = $self->{'%SHIP_DEFAULT'};
			if ($pos>=0) { $ADDRESS = $self->{'@SHIP'}->[$pos]; }
			}
		
		if (not defined $ADDRESS) {
			$ADDRESS = {};
			warn "EVEN WORSE, the address is undefined, this definitely isn't what you wanted to do!\n";
			}
		return($ADDRESS);
		}
	elsif ($ROUTE eq 'W') {
		## WS - wholesale properties!
		if (($self->{'_STATE'} & 16)==0) { 
			$self->{'*ORG'} = CUSTOMER::ORGANIZATION->new_from_orgid($self->username(),$self->prt(),$self->orgid()); 
			$self->{'_STATE'} |= 16;
			}
		# use Data::Dumper; print STDERR "ROUTEW: ".Dumper($self->{'WS'});
		if (length($property) == 2) { return ($self->{'ORG'}); }	#  returns the entire hash
		return( $self->{'*ORG'}->get($property,3) );				#  returns a specific property
		}
	elsif ($ROUTE eq 'O') {
		## ORG - properties
		if (($self->{'_STATE'} & 16)==0) { 
			$self->{'*ORG'} = CUSTOMER::ORGANIZATION->new_from_orgid($self->username(),$self->prt(),$self->orgid()); 
			$self->{'_STATE'} |= 16;
			}
		# use Data::Dumper; print STDERR "ROUTEW: ".Dumper($self->{'WS'});
		if (length($property) == 2) { return ($self->{'ORG'}); }	#  returns the entire hash
		return( $self->{'*ORG'}->get($property,3) );				#  returns a specific property
		}
	} 

##
## Valid ORIGIN codes for customer records:
## 0 - Unknown or merchant-entered
## 1 - Customer completed checkout
## 2 - Customer signed up for mailing list
##
#sub resolve_customer_tb_old {
#	my ($USERNAME,$MID) = @_;
#
#  	my $ch = uc(substr($USERNAME,0,1));
#	
#	if (ord('A') <= ord($ch) &&
#		 ord('Z') >= ord($ch)) {
#		return('CUSTOMERS_'.$ch);
#		}
#	if (ord('0') <= ord($ch) &&
#		ord('9') >= ord($ch)) {
#		return('CUSTOMERS_0');
#		}
#	return('');
#	}


sub resolve_customer_tb {
	my ($USERNAME,$MID) = @_;

	if (&ZOOVY::myrelease($USERNAME)>201338) { return("CUSTOMERS"); }

	if (not defined $MID) { ($MID) = &ZOOVY::resolve_mid($USERNAME); }

	if ($MID<=0) { 
		my ($package,$file,$line,$sub,$args) = caller(1);
		print STDERR "MID[$MID] USERNAME[$USERNAME] caller($package,$file,$line,$sub,$args)\n";
		return('CUSTOMER_NULL'); 
		}

   if (not defined $MID) { $MID = &ZOOVY::resolve_mid($USERNAME); }
   if ($MID%10000>0) { $MID = $MID -($MID % 10000); }
   return(sprintf("CUSTOMER_%d",$MID));
	}


##
## 
##
sub resolve_customer_addr_tb {
	my ($USERNAME,$MID) = @_;

	if (&ZOOVY::myrelease($USERNAME)>201338) { return("CUSTOMER_ADDRS"); }
	if (not defined $MID) { $MID = &ZOOVY::resolve_mid($USERNAME); }
	if ($MID%10000>0) { $MID = $MID -($MID % 10000); }		
	return(sprintf("CUSTOMER_ADDR_%d",$MID));
	}

##
##
##




##
## An easier way to check and see if a customer exists (eventually this should simply be
##		replaced by a direct call to resolve_customer_id .. but figured this was easier)
##
sub customer_exists { 
	my ($USERNAME,$EMAIL,$PRT) = @_;
	if (not defined $PRT) { $PRT = 0; }
	return(&CUSTOMER::resolve_customer_id($USERNAME,$PRT,$EMAIL));
	}

################################################################################
# returns a record ID (used for all subsequent functions) or 
# 0 if user does not exist
# -1 if the authentication fails.
# -2 if a database error occurs
# -3 locked account
sub authenticate {
	my ($USERNAME, $PRT, $EMAIL, $PASSWORD) = @_;

	$PRT = int($PRT);
	($PRT) = &CUSTOMER::remap_customer_prt($USERNAME,$PRT);

	if ($EMAIL eq "") { return(0); }
	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my ($qtEMAIL) = $odbh->quote($EMAIL);

	my ($redis) = &ZOOVY::getRedis($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);

	my $pstmt = "select CID,IS_LOCKED,PASSHASH,PASSSALT from $CUSTOMERTB where MID=$MID /* $USERNAME */ and PRT=$PRT and EMAIL=$qtEMAIL";
	my ($CID,$IS_LOCKED,$dbPASSHASH,$dbPASSSALT) = $odbh->selectrow_array($pstmt);
	print STDERR "AUTH FOR USERNAME: CID=$CID M=$USERNAME P=$PRT E=$EMAIL PW=$PASSWORD\n";

	my $tryHASH = Digest::SHA1::sha1_base64( sprintf("%s%s",$PASSWORD,$dbPASSSALT)).'=';	# Base64
	if ($CID == 0) {
		}
	elsif ($PASSWORD eq '') {
		$CID = 0;
		}
	elsif ($tryHASH eq $dbPASSHASH) {
		## SUCCESS! (db password matches)
		}
	elsif ($redis->llen("PasswordRecover:$CID")>0) {
		## check for a recovery
		my $SUCCESS = 0;
		## never try the 10 most recent passwords (this avoids somebody spamming recoveries to improve their odds)
		foreach my $recovery ($redis->lrange("PasswordRecover:$CID",0,10)) {
			my ($correctSALT,$correctHASH) = split(/\|\|/,$recovery);
			if ($correctHASH eq Digest::SHA1::sha1_hex( $PASSWORD.$correctSALT )) {
				$SUCCESS++;
				}
			}
		if (not $SUCCESS) { $CID = 0; }
		}
	else {
		## no recovery passwords, no valid password
		$CID = 0;
		}

	if ($IS_LOCKED) { $CID = 0; }	# yeah i know we should have better error handling, no time to rewrite.
	&DBINFO::db_user_close();
	return($CID);
	}

##
## generates a one time recovery password that is good for three hours
##  
##  perl -e 'use lib "/httpd/modules"; use CUSTOMER; my ($C) = CUSTOMER->new("sporks","PRT"=>0,EMAIL=>"jt\@zoovy.com"); print $C->generate_recovery();'
##
sub generate_recovery {
	my ($self) = @_;

	my $CID = $self->cid();
	my ($redis) = &ZOOVY::getRedis($self->username());

	my $PASSWORD =  String::MkPasswd::mkpasswd(-length=>8,-minnum=>2,-minlower=>1,-minupper=>1,-minspecial=>0,-distribute=>1);
	my $SALT = String::MkPasswd::mkpasswd(-length=>4,-minnum=>2,-minlower=>1,-minupper=>1,-minspecial=>0,-distribute=>1);

	$redis->lpush("PasswordRecover:$CID","$SALT||".Digest::SHA1::sha1_hex($PASSWORD.$SALT));
	$redis->expire("PasswordRecover:$CID",60*60*3);	# 1 hour

	return($PASSWORD);	
	}



##
## Links an order to a customer, bumps modified on customer,
##		also increments: ORDER_COUNT, LASTORDER_GMT
##
sub associate_order {
	my ($self,$CART2) = @_;

	my $CID = $self->cid();
	if ($CID<=0) {
		warn "Sorry, CUSTOMER->cid must return a positive number before attempting to associate_order";
		return();
		}

	if (ref($CART2) ne 'CART2') {
		warn "Sorry, but you must pass an ORDER object to CUSTOMER->associate_order";
		return();
		}
	my $ORDERID = $CART2->oid();

	my $odbh = &DBINFO::db_user_connect($self->username());
	my $USERNAME = $self->username();
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);

	# escape the whole mess since we'll be working with a database
	my $qtORDERID = $odbh->quote($ORDERID);
 	my $ORDERTB = &DBINFO::resolve_orders_tb($USERNAME,$MID);


	## NEW DATABASE FORMAT
	my $pstmt = "update $ORDERTB set CUSTOMER=$CID where MID=$MID /* $USERNAME */ and ORDERID=$qtORDERID";
	print STDERR $pstmt."\n";
	my $rv = $odbh->do($pstmt);

	# since an order as updated/added/whatever update the modified timestamp
	if ($rv>0) {
		## $^T is getting the current day w/o the correct time
		## ie 2009-03-25 00:00:03 instead of 2009-03-25 14:24:55
		## causing modified times to be less than created times
		#$pstmt = "update $CUSTOMERTB set MODIFIED_GMT=$^T ";
		#$pstmt .= ",LASTORDER_GMT=$^T,ORDER_COUNT=ORDER_COUNT+1 ";
		$pstmt = "update $CUSTOMERTB set MODIFIED_GMT=".time();
		$pstmt .= ",LASTORDER_GMT=".time().",ORDER_COUNT=ORDER_COUNT+1 ";
		$pstmt .= " where MID=$MID /* $USERNAME */ and CID=$CID";
		print STDERR $pstmt."\n";
		$odbh->do($pstmt);
	
		## update our last in memory version.
		$self->{'LASTORDER_GMT'} = time();
		$self->{'ORDER_COUNT'} = $self->{'ORDER_COUNT'}+1;

		$CART2->in_set('customer/cid',$CID);
		}
	&DBINFO::db_user_close();

	}


##
## Purpose: associate an ORDER_ID with a particular CUSTOMER by email address.
##				Note: i do this by email because i figure its safer.
##				Note: the order should already exist (duh, since your passing the variable)
##  			NOTE: consequently you should only call this once a customer has been created - else it won't work.
## returns: CUSTOMER record id (non-zero) on success, 0 on failure.
##
sub save_order_for_customer {
	my ($USERNAME, $ORDERID, $CUSTEMAIL) = @_;

	if ( (not defined $CUSTEMAIL) || ($CUSTEMAIL eq '') ) { return(0); }
	$CUSTEMAIL =~ s/[^\w\+\-\.\@\!\_]+//g;

	my $odbh = &DBINFO::db_user_connect($USERNAME);

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);

	# escape the whole mess since we'll be working with a database
	my $qtUSERNAME = $odbh->quote($USERNAME);
	$CUSTEMAIL = $odbh->quote($CUSTEMAIL);
	$ORDERID = $odbh->quote($ORDERID);
 	my $ORDERTB = &DBINFO::resolve_orders_tb($USERNAME,$MID);

	my $pstmt = "select CID from $CUSTOMERTB where MID=$MID /* $qtUSERNAME */ and EMAIL=$CUSTEMAIL";
	if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }
	my $sth = $odbh->prepare($pstmt);
	my $rv = $sth->execute;
	my $CUSTID = 0;
	if ($sth->rows>0) {
		($CUSTID) = $sth->fetchrow();

		## NEW DATABASE FORMAT
		$pstmt = "update $ORDERTB set CUSTOMER=$CUSTID where MID=$MID /* $qtUSERNAME */ and ORDERID=$ORDERID";
		if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }
		$rv = $odbh->do($pstmt);

		# since an order as updated/added/whatever update the modified timestamp
		## $^T is getting the current day w/o the correct time
		## ie 2009-03-25 00:00:03 instead of 2009-03-25 14:24:55
		## causing modified times to be less than created times
		#$pstmt = "update $CUSTOMERTB set MODIFIED_GMT=$^T ".
		$pstmt = "update $CUSTOMERTB set MODIFIED_GMT=".time().
					" where MID=$MID /* $qtUSERNAME */ and CID=$CUSTID";
		if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }
		$odbh->do($pstmt);
		}
	$sth->finish;
	&DBINFO::db_user_close();

   return($CUSTID);
}

##
## returns a list of password hints
##
sub fetch_password_hints
{
	my %hash = ();
#	$hash{1} = "Name of the person you'd most like to see be horribly mutilated";
#	$hash{2} = "Name of the person who abused you the most as a child";
#	$hash{3} = "The name and phone number of the best fuck you've ever had";
#	$hash{4} = "The name and phone number of the second best fuck you've ever had";
#	$hash{5} = "Number of times you'd been arrested before you turned 18";
#	$hash{6} = "Number of times you've been abducted by aliens";
#	$hash{7} = "Number of times you've tried crack.";
#	$hash{8} = "The name and phone number of the easiest lay you ever had.";
	$hash{'1'} = "What is your mothers maiden name?";
	$hash{'2'} = "What was the name of your favorite childhood pet?";
	$hash{'3'} = "What was the city you were born in?";
	$hash{'4'} = "What was the last name of your best friend growing up?";
	$hash{'5'} = "What is the last city you lived in?";
	return(%hash); 
}



sub delete_customer {
	my ($USERNAME,$CID) = @_;

	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my %hash = ();

	my ($rv) = (undef);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	if ($CID =~ /\@/) {
		## crap.. silly user passed us an email address inside of a CID
		($CID) = &CUSTOMER::resolve_customer_id($USERNAME,0,$CID);
		}
	
	if ($CID>0) {
		print STDERR "Customer ID: $CID";

		my $pstmt = '';

		my $ORDERTB = &DBINFO::resolve_orders_tb($USERNAME,$MID);
		$pstmt = "update $ORDERTB set CUSTOMER=0 where MID=$MID and CUSTOMER=$CID";
		if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }
		$odbh->do($pstmt);

		my ($addrtb) = &CUSTOMER::resolve_customer_addr_tb($USERNAME,$MID);
		$pstmt = "delete from $addrtb where PARENT=$CID and MID=$MID /* $USERNAME */";
		if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }
		$odbh->do($pstmt);
		
		my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
		$pstmt = "delete from $CUSTOMERTB where CID=$CID";
		if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }
		$odbh->do($pstmt);

		$pstmt = "delete from CUSTOMER_SECURE where MID=$MID and CID=$CID /* $USERNAME */";
		$odbh->do($pstmt);
		}

	&DBINFO::db_user_close();
	return($rv);
	}


# RESOLVE CUSTOMER ID
# Author: BALDO, BE-YATCH.
# Finds the customer_id for a email address
# Accepts: USERNAME and email address
# Returns: The customer_id of the email address provided
sub searchfor_cid {
	my ($USERNAME,$PRT,$TYPE,$FIELD) = @_;

	($PRT) = &CUSTOMER::remap_customer_prt($USERNAME,$PRT);

	$FIELD =~ s/^[\s]+//gs;	# strip leading spaces
	$FIELD =~ s/[\s]+$//gs; # strip trailing spaces
	$TYPE = uc($TYPE);

	$PRT = int($PRT);	
	my $odbh = &DBINFO::db_user_connect($USERNAME);

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);


	my $pstmt = "select CID from $CUSTOMERTB where MID=$MID /* $USERNAME */ and PRT=$PRT ";
	if ($TYPE eq 'PHONE') {
		$FIELD =~ s/[^\d]+//gs;
		$FIELD = $odbh->quote($FIELD);
		$pstmt .= " and PHONE=$FIELD";
		}
	elsif ($TYPE eq 'EMAIL') {
		$FIELD = $odbh->quote($FIELD);
		$pstmt .= " and EMAIL=$FIELD";
		}
	else {
		warn "CUSTOMER::searchfor_cid had invalid TYPE[$TYPE]";
		$pstmt = '';
		}
	if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }

	my $sth = $odbh->prepare($pstmt);
	$sth->execute();
	my $customer_id = '';
	if ($sth->rows>0) {
		$customer_id = $sth->fetchrow_array();
		} else {
		$customer_id = undef;
		}
	$sth->finish();
	&DBINFO::db_user_close();

	return $customer_id;
	}




sub resolve_customer_info {
	my ($USERNAME,$PRT,$email) = @_;

	## early exit.
	if ((not defined $email) || ($email eq '')) { return(0); }

	$PRT = int($PRT);	
	($PRT) = &CUSTOMER::remap_customer_prt($USERNAME,$PRT);

	my $udbh = &DBINFO::db_user_connect($USERNAME);

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
	$email = $udbh->quote($email);

	my $pstmt = "select CID,CREATED_GMT from $CUSTOMERTB where MID=$MID /* $USERNAME */ and PRT=$PRT and EMAIL=$email /* resolve_customer_id */";
	print STDERR $pstmt."\n";
	if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }
	my ($customer_id,$created_gmt) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();

	return($customer_id,$created_gmt);
	}

# RESOLVE CUSTOMER ID
# Author: BALDO, BE-YATCH.
# Finds the customer_id for a email address
# Accepts: USERNAME and email address
# Returns: The customer_id of the email address provided
sub resolve_customer_id {
	my ($USERNAME,$PRT,$email) = @_;
	my ($customer_id) = &CUSTOMER::resolve_customer_info($USERNAME,$PRT,$email);
	return($customer_id);
	}



# RESOLVE EMAIL
# Author: BALDO, BE-YACH.
# Finds the email address for a customer_id
# Accepts: USERNAME and customer_id
# Returns: The email address of the customer_id provided
sub resolve_email {
	my ($USERNAME,$PRT,$customer_id) = @_;
	
	if ($customer_id == 0) { return undef; }

	$PRT = int($PRT);
	($PRT) = &CUSTOMER::remap_customer_prt($USERNAME,$PRT);

	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	$customer_id = $odbh->quote(int($customer_id));
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);

	my $pstmt = "select EMAIL from $CUSTOMERTB where MID=$MID /* $USERNAME */ and CID=$customer_id and PRT=$PRT";
	if ($CUSTOMER::DEBUG) { print STDERR $pstmt."\n"; }

	my $sth = $odbh->prepare($pstmt);
	$sth->execute();
	my ($email) = $sth->fetchrow_array();
	$sth->finish();

	&DBINFO::db_user_close();
	return $email;
	}


# CHANGE EMAIL
# Swaps out one email address for another
sub change_email {
	my ($self,$email) = @_;
	
	my $udbh = &DBINFO::db_user_connect($self->username());

	my $MID = &ZOOVY::resolve_mid($self->username());
	my $CID = int($self->cid());
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($self->username(),$MID);
	my $qtEMAIL = $udbh->quote($email);

	my ($cid) = &CUSTOMER::resolve_customer_id($self->username(),$self->prt(),$email);
	if ($cid == 0) {
		## are we overwriting a user, or does this user already exist?
		my $pstmt = "update $CUSTOMERTB set EMAIL=$qtEMAIL where MID=$MID /* $self->{'_USERNAME'} */ and CID=$CID";
		# print STDERR $pstmt."\n";
		$udbh->do($pstmt);
	
		$self->{'_EMAIL'} = $email;
		$self->set_attrib('INFO.EMAIL',$email);
		$cid = $self->cid();
		}

	&DBINFO::db_user_close();
	return $cid;
	}


## Goes down a list of potential IP addresses and returns the first one that's defined and looks valid
## Always returns an int, whether passed a dot-notation or plain integer
sub smart_ip_int {
	foreach my $addr (@_) {
		next unless ((defined $addr) && ($addr ne ''));
		if ($addr =~ m/^\d+$/) { return $addr; }
		return ip_to_int($addr);
		}
	return 0;
	}

## Turns a dotted quad (1.2.3.4) into an integer.  returns 0 on failure
sub ip_to_int {
	my $ip = shift;
	return 0 unless defined($ip);
	my @n = split(/\./, $ip);
	foreach (0..3) {
		unless (
			defined($n[$_]) &&
			($n[$_] =~ m/^\d+$/) &&
			($n[$_] < 256)) {
			return 0;
			}
		}
	return unpack('N', pack('C4', @n));
	}

## Turns an integer into a dotted quad (1.2.3.4).  returns 0.0.0.0 on failure
sub int_to_ip {
	my $num = shift;
	return '0.0.0.0' unless defined($num);
	return '0.0.0.0' unless $num =~ m/^\d+$/;
	return '0.0.0.0' unless $num < 4294967296;
	return join('.', unpack('C4', pack('N4', $num) ) );
	}

1;
