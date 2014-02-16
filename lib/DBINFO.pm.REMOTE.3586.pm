package DBINFO;

use DBI;
use strict;
use Data::Dumper;
#use SQLRelay::Connection;
#use SQLRelay::Cursor;

use lib "/backend/lib";
require ZOOVY;
require ZWEBSITE;

#$DBINFO::MYSQL_USER = "zoovy";
#$DBINFO::MYSQL_PASS = "zoovy";
#$DBINFO::MYSQL_DSN = "DBI:mysql:database=ZOOVY;host=192.168.2.32";
$DBINFO::MYSQL_USER = "commercerack";
$DBINFO::MYSQL_PASS = "commercerack";
$DBINFO::MYSQL_DSN = "DBI:mysql:database=commercerack;host=commercerack.cgrqpxqeaoos.us-west-2.rds.amazonaws.com";
$DBINFO::HANDLE_LOG = 1;


## BACKUP: 
## mysql> set password for 'dbuser'@'192.168.2.%' = password('io45uo23/3IIX'); flush privileges;
%DBINFO::CREDENTIALS = (
	## DBUSER, $DBPASS, $DSN, $DBNAME, $DBHOST
	'CRACKLE'=>	["zoovy","zoovy","DBI:mysql:database=ORDERS;host=192.168.2.35;net_read_timeout=60", "ORDERS", "192.168.2.35" ],
	'ENDOR'=>	["zoovy","zoovy","DBI:mysql:database=ORDERS;host=192.168.2.40;net_read_timeout=60", "ORDERS", "192.168.2.40" ],
	'DAGOBAH'=>	["zoovy","zoovy","DBI:mysql:host=192.168.2.37;net_read_timeout=60", "", "192.168.2.37" ],
	'HOTH'=>		["zoovy","zoovy","DBI:mysql:host=192.168.2.38;net_read_timeout=60", "", "192.168.2.38" ],
	'BESPIN'=>	['zoovy',"zoovy","DBI:mysql:host=192.168.2.39;net_read_timeout=60", "", "192.168.2.39" ],
	'CANCEL'=> [],
	);

$DBINFO::HAS_SOCKET = 0;
if (-S "/local/tmp/mysql.sock") {
	$DBINFO::HAS_SOCKET = "/local/tmp/mysql.sock";
	}		

$DBINFO::HANDLE_LOG = 0;
$DBINFO::DBH_PERSIST = undef;
$DBINFO::DBH_INSTANCE_COUNT = 0;

%DBINFO::USER_HANDLES = ();

$DBINFO::MAXAGE = 45;
$DBINFO::DEBUG = 0;
$DBINFO::LET_MOD_PERL_DO_ITS_THING++;

sub def  { foreach (0..$#_) { defined $_[$_] && return $_[$_]; } return ''; }

##
##
#/* a universal registry for guids, ex: faked upcs */
#create table GUID_REGISTRY (
#   MID integer unsigned default 0 not null,
#   CREATED_TS timestamp default 0 not null,
#   GUIDTYPE varchar(6) default '' not null, /* ex: AMZUPC */
#   GUID  varchar(45) default '' not null,
#   DATA varchar(32) default '' not null,
#   unique(MID,GUIDTYPE,GUID)
#);
##
sub guid_register {
	my ($USERNAME,$ORIGIN,$GUID,$VALUE) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) =&ZOOVY::resolve_mid($USERNAME);
	my ($pstmt) = &DBINFO::insert($udbh,'GUID_REGISTRY',{
		'MID'=>$MID,
		'*CREATED_TS'=>'now()',
		'GUIDTYPE'=>$ORIGIN,
		'GUID'=>$GUID,
		'DATA'=>$VALUE,
		},sql=>1);
	my ($rv) = $udbh->do($pstmt);
	my $SUCCESS = (defined $rv)?1:0;
	&DBINFO::db_user_close();

	return($SUCCESS);
	}

##
## ORIGIN: AMZUPC
##	GUID: sku?
##
sub guid_lookup {
	my ($USERNAME,$ORIGIN,$GUID) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) =&ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select DATA from GUID_REGISTRY where MID=$MID and GUIDTYPE=".$udbh->quote($ORIGIN)." and GUID=".$udbh->quote($GUID);
	my ($data) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();
	return($data);
	}

## NOTE: there is no guid_delete (don't delete them, they are eternal)

##
## next if (! my $LOCKID = &DBINFO::udbh($udbh,"USERNAME_DOBA"));
##
sub has_opportunistic_lock {
	my ($udbh,$USERNAME,@IDS) = @_;

	my $qtLOCK_ID = $udbh->quote(join(":",$USERNAME,@IDS));
	my $pstmt = "select get_lock($qtLOCK_ID,1)";
	print STDERR "$pstmt\n";
	my ($got_lock) = $udbh->selectrow_array($pstmt);
	return($got_lock);
	}

##
##
##
sub release_lock {
	my ($udbh,$USERNAME,@IDS) = @_;
	my $qtLOCK_ID = $udbh->quote(join(":",$USERNAME,@IDS));
	my $pstmt = "select release_lock($qtLOCK_ID)";
	my ($free_lock) = $udbh->selectrow_array($pstmt);
	return($free_lock);
	}


sub create_database {
	my ($CLUSTER,$USERNAME) = @_;
	$USERNAME = uc($USERNAME);

	my ($cdbh) = &DBINFO::db_user_connect($CLUSTER);
	if (defined $cdbh) {
		open F, "</backend/lib/schema.sql"; 
		$/ = undef;  my ($SQL) = <F>; $/ = "\n";
		close F;
		
		$cdbh->do("create database $USERNAME");	
		}

	&DBINFO::db_user_connect();
	}


##
## create table TASK_LOCKS (
#   CREATED datetime default 0 not null,
#   USERNAME varchar(20) default '' not null,
#   TASKID   varchar(32) default '' not null,
#   APPID    varchar(32) default '' not null,
#   unique(USERNAME,TASKID,APPID)
#) ENGINE = MEMORY;
#

sub our_appid {
	return(substr(sprintf("%d:%d:%s",$$,$^T,$0),0,64));
	}

##
## perl -e 'use lib "/backend/lib"; use DBINFO; print DBINFO::task_lock("brian","taskid","LOCK"); &DBINFO::task_lock("brian","taskid","UNLOCK");'
##
sub task_lock {
	my ($USERNAME,$taskid,$VERB,%options) = @_;

	$taskid = substr($taskid,0,32);
	my $appid = &DBINFO::our_appid();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my $LOCK_LIMIT = '';
	if (defined $options{'LOCK_LIMIT'}) {
		$LOCK_LIMIT = $options{'LOCK_LIMIT'};
		}
	else	{
		$LOCK_LIMIT = '3600';
		}

	if (($VERB eq 'UNLOCK') || ($VERB eq 'PICKLOCK')) {
		my $pstmt = "/* $VERB */ delete from TASK_LOCKS where USERNAME=".$udbh->quote($USERNAME)." and TASKID=".$udbh->quote($taskid);
		if ($VERB eq 'UNLOCK') {
			## this prevents us from accidentally releasing a lock that isn't ours
			$pstmt .= " and APPID=".$udbh->quote($appid);
			}
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		}

	my $result = 0;
	if (($VERB eq 'PICKLOCK') || ($VERB eq 'LOCK')) {
		my $pstmt = &DBINFO::insert($udbh,'TASK_LOCKS',{
			'USERNAME'=>$USERNAME,
			'*CREATED'=>'now()',
			'TASKID'=>$taskid,
			'APPID'=>$appid,
			},sql=>1,'verb'=>'insert');
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);

		$pstmt = "select unix_timestamp(now())-unix_timestamp(CREATED) as AGE,APPID from TASK_LOCKS where USERNAME=".$udbh->quote($USERNAME)." and TASKID=".$udbh->quote($taskid);
		print STDERR "$pstmt\n";
		my ($age,$ownerappid) = $udbh->selectrow_array($pstmt);
		if ($ownerappid ne $appid) {
			warn "already locked..\n";
			$result = 0;
			}

		if ($appid eq $ownerappid) {
			warn "LOCK SUCCESS appid:$appid owner:$ownerappid\n";
			$result = 1; 
			}
		elsif ( $age > $LOCK_LIMIT) {
			warn "forced release of lock! (too old! [$age])\n";	
			$pstmt = "/* EXPIRE */ delete from TASK_LOCKS where USERNAME=".$udbh->quote($USERNAME)." and TASKID=".$udbh->quote($taskid);
			print STDERR "$pstmt\n";
			$udbh->do($pstmt);
			$result = &DBINFO::task_lock($USERNAME,$taskid,$VERB,'LOCK_LIMIT'=>$LOCK_LIMIT);
			}
		else {
			warn "lock failed!\n";
			}

		}

	&DBINFO::db_user_close();
	return($result);
	}




##
## uses the 'SEQUENCES' table to create a unique identifier
##
sub next_in_sequence {
	my ($udbh,$USERNAME,$SEQID,$REASON) = @_;

	$REASON = substr($REASON,0,20);

	$SEQID = uc($SEQID);
	$SEQID =~ s/[^A-Z0-9\-]+//gs;
	$SEQID = substr($SEQID,0,10);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my $pstmt = "select count(*) from SEQUENCES where MID=$MID /* $USERNAME */ and SEQUENCE_ID=".$udbh->quote($SEQID);
	my ($exists) = $udbh->selectrow_array($pstmt);
	if (not $exists) {
		$pstmt = &DBINFO::insert($udbh,'SEQUENCES',{ 'MID'=>$MID, 'SEQUENCE_ID'=>$SEQID, 'COUNTER'=>0, 'LAST_UPDATE'=>0, 'LAST_REQUEST'=>'**INIT**'}, sql=>1);
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		}
	## at this point the counter exists, now bump it
	my $ts = time();
	$pstmt = &DBINFO::insert($udbh,'SEQUENCES',{
		'*COUNTER'=>'COUNTER+1',
		'LAST_UPDATE'=>$ts,
		'LAST_REQUEST'=>$REASON
		},update=>2,key=>{'MID'=>$MID,'SEQUENCE_ID'=>$SEQID},sql=>1);
	 print STDERR "$pstmt\n";
	$udbh->do($pstmt);

	## now make sure we're looking at *our* bump (otherwise we re-bump)
	$pstmt = "select COUNTER,LAST_REQUEST,LAST_UPDATE from SEQUENCES where MID=$MID /* $USERNAME */ and SEQUENCE_ID=".$udbh->quote($SEQID);
	 print STDERR "$pstmt\n";
	my ($counter,$lastreason,$lastts) = $udbh->selectrow_array($pstmt);
		
	if ($lastreason ne $REASON) {
		warn "next_in_sequence failure: lastreason: $lastreason thisreason: $REASON\n";
		}
	elsif ($lastts != $ts) {
		warn "next_in_sequence failure: lastts: $lastts thists: $ts\n";
		}
	else {
		return($counter);
		}
	## hmm.. try again!
	&next_in_sequence(@_);
	}




##
## executes query on each db that is reacable 
##	returns an array of hashrefs 
##
sub fetch_all_into_hashref {
	my ($cluster,$pstmt) = @_;

	my ($udbh) = &DBINFO::db_user_connect($cluster);
	my @RESULTS = ();

	if ( (lc($cluster) eq '_self_') || (uc($cluster) eq uc(&ZOOVY::resolve_cluster($cluster))) ) {
		## run on all users
		my $sth = $udbh->prepare("show databases;");
		$sth->execute();
		my @DBS = ();
		while ( my ($DB) = $sth->fetchrow() ) {
			next unless ($DB eq uc($DB));
			push @DBS, $DB;
			}
		$sth->finish();

		foreach my $DB (sort @DBS) {
			$udbh->do("use $DB;");
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my $ref = $sth->fetchrow_hashref() ) {
				$ref->{'_DB_'} = $DB;
				if (($DB eq 'ORDERS') || ($DB eq 'SNAP')) {
					## special rules for shared tables
					if ( $ref->{'USERNAME'} && (-f sprintf("%s/platform.yaml",&ZOOVY::resolve_userpath($ref->{'USERNAME'})) ) ) {
						## user has their own platform.yaml file .. which means we shouldn't use results form.
						}
					else {
						## user is in shared database, so use their results.
						push @RESULTS, $ref;
						}
					}
				else {
					push @RESULTS, $ref;
					}
				}
			$sth->finish();
			}
		}
	else {
		## single user
		my $sth = $udbh->prepare($pstmt);
		$sth->execute(); 
		while ( my $ref = $sth->fetchrow_hashref() ) {
			push @RESULTS, $ref; 
			}
		$sth->finish();
		}

	&DBINFO::db_user_close();
	return(\@RESULTS);
	}


############################################################################
##
## opens a database connection to the proper database for a user.
##
sub db_user_connect {
	my ($USERNAME) = @_;

	# print STDERR Dumper(caller(0))."\n";

	$USERNAME = uc($USERNAME);
	my $CLUSTER = undef;

	## _self_ is not a valid username, but it's handy to do this type of lookup.

	if (($USERNAME eq '_SELF_') || (substr($USERNAME,0,1) eq '@')) {
		if ($USERNAME eq '_SELF_') { $USERNAME = uc(&ZOOVY::servername()); }
		if (substr($USERNAME,0,1) eq '@') {	$USERNAME = uc(substr($USERNAME,1)); }
		if ((defined $DBINFO::CREDENTIALS{$USERNAME}) && ($DBINFO::HAS_SOCKET)) {
			## this handles _self_ and @cluster
			my $dbdsn = "DBI:mysql:mysql_socket=/local/tmp/mysql.sock";
			$DBINFO::CREDENTIALS{$USERNAME} = [ 'root','',$dbdsn ];
			}
		}

	if (not $DBINFO::CREDENTIALS{$USERNAME}) {
		my ($dbuser,$dbpass,$dbdsn,$dbname,$dbhost) = &ZOOVY::resolve_user_db($USERNAME);
		if ($DBINFO::HAS_SOCKET) {
			$dbdsn = "DBI:mysql:database=$dbname;mysql_socket=/local/tmp/mysql.sock";
			}
		if ($dbuser && $dbpass && $dbname) {
			$DBINFO::CREDENTIALS{$USERNAME} = [ $dbuser,$dbpass,$dbdsn,$dbname,$dbhost ];
			}
		if ($DBINFO::HAS_SOCKET) {
			my $dbdsn = "DBI:mysql:database=$dbname;mysql_socket=/local/tmp/mysql.sock";
			$DBINFO::CREDENTIALS{$USERNAME}->[2] = $dbdsn;
			}
		}

	if (not $DBINFO::CREDENTIALS{$USERNAME}) {
		($CLUSTER) = uc(&ZOOVY::resolve_cluster($USERNAME));
		$DBINFO::CREDENTIALS{$USERNAME} = $DBINFO::CREDENTIALS{$CLUSTER};
		my ($dbuser,$dbpass,$dbdsn,$dbname,$dbhost) = @{$DBINFO::CREDENTIALS{$USERNAME}};
		if ($DBINFO::HAS_SOCKET) {
			my $dbdsn = "DBI:mysql:database=$dbname;mysql_socket=/local/tmp/mysql.sock";
			$DBINFO::CREDENTIALS{$USERNAME}->[2] = $dbdsn;
			}
		}

	#print STDERR join("|",$USERNAME,$CLUSTER)."\n";
	#print STDERR join("|",@{$DBINFO::CREDENTIALS{$USERNAME}})."\n";
	my $HANDLEREF = [undef,0,'UNKNOWN',0,'-::-'];		# [0]=$dbh, [1]=instance count, [2] cluster, [3]=ts created, [4]=module::sub opening.

	if (not $DBINFO::CREDENTIALS{$USERNAME}) {
		warn "NO DB CREDENTIALS FOR $USERNAME\n";
		}
	elsif ($DBINFO::HAS_SOCKET) {
		## don't worry about the CLUSTER
		}
	elsif ($DBINFO::LET_MOD_PERL_DO_ITS_THING && $ENV{'MOD_PERL'}) {
		## under mod perl we let apache do the heavy lifting.
		}
	elsif (not defined $DBINFO::USER_HANDLES{"$USERNAME"}->[0]) {
		## create a new USER_HANDLES object
		$DBINFO::USER_HANDLES{$USERNAME} = $HANDLEREF;
		}
	elsif ($DBINFO::USER_HANDLES{"$USERNAME"}->[1] == 0) {
		## cached counts should NEVER be at zero, this is a cause to reset the whole thing!		
		$DBINFO::USER_HANDLES{$USERNAME} = $HANDLEREF;
		}
	elsif (defined $DBINFO::USER_HANDLES{"$USERNAME"}) {
		## hurray, we have that instance already!
		$HANDLEREF = $DBINFO::USER_HANDLES{"$USERNAME"};
		if ($DBINFO::HANDLE_LOG) {
			## NOTE: we should *NEVER* have a cached at zero.
			my ($package,$file,$line,$sub,$args) = caller(0);
			open F, ">>/tmp/db.log";
			print F "[$$] $HANDLEREF->[2] $HANDLEREF->[3] $HANDLEREF->[4].$HANDLEREF->[1] CACHED $package,$file,$line,$sub,$args\n";
			close F;
			}
		## VERY IMPORTANT SINCE WE USE THIS TO DETERMINE THE COUNT BEFORE WE NEED TO CLOSE.
		$HANDLEREF->[1]++;
		}
	else {
		## reset, a fresh db handle!
		$DBINFO::USER_HANDLES{$USERNAME} = $HANDLEREF;
		}

	

	## Is Database Down - Retry.
	my $i = 0;
	while (($HANDLEREF->[1]<=0) && ($i < 5)) {
		#my ($package,$file,$line,$sub,$args) = caller(0);
		if ($i>0) { sleep(); }
		my $failed = 0;

		## NOTE: apache/mod_perl will run this line multiple times... it's fine.. under mod_perl and DBI::Cache
		## it's more efficient

		## print "($dbdsn,$dbuser,$dbpass)\n";
		## print STDERR join("|",@{$DBINFO::CREDENTIALS{$USERNAME}})."\n";
		my ($dbuser,$dbpass,$dbdsn) = @{$DBINFO::CREDENTIALS{$USERNAME}};

		$HANDLEREF->[0] = DBI->connect_cached($dbdsn,$dbuser,$dbpass) || eval { $failed++; warn "failed to connect to database $@"; };
		$HANDLEREF->[0]->{'mysql_auto_reconnect'} = 1;
		if (not $failed) {
			## increment the counter so we know we got a connection!
			$HANDLEREF->[1]++;
			$HANDLEREF->[2]=$CLUSTER;
			$HANDLEREF->[3]=time();	# record the time we created the handle.

			my ($package,$file,$line,$sub,$args) = caller(1);
			$HANDLEREF->[4]=sprintf('%s::%s',&DBINFO::def($package),&DBINFO::def($sub));
			if ($DBINFO::HANDLE_LOG) {
				my ($package,$file,$line,$sub,$args) = caller(0);
				open F, ">>/tmp/db.log";
				print F "[$$] $HANDLEREF->[2] $HANDLEREF->[3] $HANDLEREF->[4].$HANDLEREF->[1] OPENED $package,$file,$line,$sub,$args\n";
				close F;
				}
			}
		elsif ($i>0) {
			if ($DBINFO::HANDLE_LOG) {
				my ($package,$file,$line,$sub,$args) = caller(0);
				open F, ">>/tmp/db.log";
				print F "[$$] $HANDLEREF->[2] $HANDLEREF->[3] $HANDLEREF->[4].$HANDLEREF->[1] FAILED $package,$file,$line,$sub,$args\n";
				close F;
				}
			open F, "|/usr/sbin/sendmail -t";
			print F "To: brianh\@zoovy.com\n";
			print F "From: nfs1\@zoovy.com\n";
			print F "Subject: Unable to connect to db $ENV{'SERVER_ADDR'} attempt:$i\n\n";
			print F "User: $USERNAME\n";
			print F "Host: ".`hostname`;
			print F "Time was: ".time()."\n";
			print F "DSN: $dbdsn\n";
			close F;
			}
		$i++;
		}

	if ($HANDLEREF->[1] > 0) {
		## YAY, SUCCESS, SO WE KEEP THE HANDLE ON THE STACK SO WE CAN POP IT LATER.
		push @{$DBINFO::USER_HANDLES{'@HANDLES'}}, $HANDLEREF;
		if ($DBINFO::HANDLE_LOG) {	
			my ($package,$file,$line,$sub,$args) = caller(0);
			open F, ">>/tmp/db.log";
			print F "[$$] $HANDLEREF->[2] $HANDLEREF->[3] $HANDLEREF->[4].$HANDLEREF->[1] SUCCESS $package,$file,$line,$sub,$args\n";
			close F;
			}
		return($HANDLEREF->[0]);
		}
	else {
		if ($DBINFO::HANDLE_LOG) {	
			my ($package,$file,$line,$sub,$args) = caller(0);
			open F, ">>/tmp/db.log";
			print F "[$$] $HANDLEREF->[2] $HANDLEREF->[3] $HANDLEREF->[4].$HANDLEREF->[1] FAILED $package,$file,$line,$sub,$args\n";
			close F;
			}
		if (($i>3) && ($HANDLEREF->[1]<=0))  {
			print "Content-type: text/plain\n\nError: Temporarily unable to reach database.  Please try your request again in a few minutes.\n\n";	
			die("Could not connect to Database");
			}
		return(undef);
		}
	## never reached
	return(undef);
	}

##
## close the persistent handle
##
sub db_user_close {

	my ($HANDLEREF) = [undef,-1,0,''];
	if (scalar(@{$DBINFO::USER_HANDLES{'@HANDLES'}})>0) {
		$HANDLEREF = pop( @{$DBINFO::USER_HANDLES{'@HANDLES'}} );
		}
	else {
		warn "tried to pop empty stack, resetting all handles!";
		%DBINFO::USER_HANDLES = ();
		}

	
	if ($DBINFO::HANDLE_LOG) {	
		my ($package,$file,$line,$sub,$args) = caller(0);
		open F, ">>/tmp/db.log";
		print F "[$$] $HANDLEREF->[2] $HANDLEREF->[3] $HANDLEREF->[4].$HANDLEREF->[1] POPPED  $package,$file,$line,$sub,$args\n";
		close F;
		}

	if ($HANDLEREF->[1]>0) {
		$HANDLEREF->[1]--;
		if ($HANDLEREF->[1]<=0) {
			my ($package,$file,$line,$sub,$args) = caller(1);
			if ((not defined $package) || (not defined $sub)) {
				warn "database handle caller(1) is undef\n";
				}
			elsif ((not defined $HANDLEREF->[4]) || ($HANDLEREF->[4] ne sprintf('%s::%s',&DBINFO::def($package),&DBINFO::def($sub)))) {
				warn "database handle opened from: $HANDLEREF->[4] but closed from: $package::$sub\n";
				if ($DBINFO::HANDLE_LOG) {	
					open F, ">>/tmp/db.log";
					print F "[$$] $HANDLEREF->[2] $HANDLEREF->[3] $HANDLEREF->[4].$HANDLEREF->[1] MISMATCH $HANDLEREF->[4]\n";
					close F;
					}
				}
			}
		}

	if (not defined $HANDLEREF->[0]) {
		warn "corrupt handleref\n";
		if ($DBINFO::HANDLE_LOG) {	
			open F, ">>/tmp/db.log";
			print F "[$$] $HANDLEREF->[2] $HANDLEREF->[3] $HANDLEREF->[4].$HANDLEREF->[1] DETECT_CORRUPT_HANDLE $HANDLEREF->[4]\n";
			close F;
			}
		}
	elsif ($DBINFO::LET_MOD_PERL_DO_ITS_THING && $ENV{'MOD_PERL'}) {
		$HANDLEREF->[0]->disconnect();
		if ($DBINFO::HANDLE_LOG) {	
			open F, ">>/tmp/db.log";
			print F "[$$] $HANDLEREF->[2] $HANDLEREF->[3] $HANDLEREF->[4].$HANDLEREF->[1] MOD_PERL_DISCONNECT $HANDLEREF->[4]\n";
			close F;
			}
		}
	elsif ($HANDLEREF->[1]<=0) {
		## eventually we should add a UNIVERSAL::can here to test if disconnect will fail.
		# print STDERR "DISCONNECT\n";

		my $CLUSTER = $HANDLEREF->[3];
		if ($DBINFO::HANDLE_LOG) {	
			open F, ">>/tmp/db.log";
			print F "[$$] $HANDLEREF->[2] $HANDLEREF->[3] $HANDLEREF->[4].$HANDLEREF->[1] CLEANUP $HANDLEREF->[4]\n";
			close F;
			}

		$HANDLEREF->[0]->disconnect();
		## always delete closed database handles
		delete $DBINFO::USER_HANDLES{$CLUSTER};
		}
	elsif ($HANDLEREF->[1]>0) {
		## we still have modules using this cached handle.
		}
	else {
		warn "database error - undef[0] in HANDLEREF";
		}

	return(0);
	}



sub last_insert_id {
	my ($dbh) = @_;

	my $pstmt = "select last_insert_id()";
	my ($ID) = $dbh->selectrow_array($pstmt);
	return($ID);
	}


##
## takes an arrayref, turns it into
##		('1','2','3')
##
sub makeset {
	my ($dbh, $arref) = @_;

	my $set = '';
	foreach my $x (@{$arref}) {
		$set .= $dbh->quote($x).',';
		}
	if ($set ne '') {
		chop($set);
		$set = "($set)";
		}
	return($set);
	}

##
## does a simple insert statement to a table, from a hash
##		parameters: a dbh reference, TABLE NAME, hashref (key=>value)
##		options:
##			key=>causes us to do a select count(*) and then switch to update mode
##					see notes in the code for specific behaviors for scalar, arrayref, hashref
##			debug=>(bitise) 
##				1 - output to stderr
##				2 - do not apply statements.
##			update=>0|1|2 (default is 1) 
##				0 = force an insert 
##				2 = force an update
##			sql=>1
##				returns an sql statement, turns off STDERR print
##	returns:
##		pstmt or undef if error (if it was applied to database)
##	
sub insert {
	my ($dbh,$TABLE,$kvpairs,%options) = @_;

	if (defined $options{'sql'}) {
		$options{'debug'} |= 2;
		$options{'debug'} = $options{'debug'} & (0xFF-1);
		}

	if (not defined $options{'debug'}) { $options{'debug'}=0; }
	if (not defined $dbh) { $options{'debug'} = $options{'debug'} | 2; }

	if ($options{'debug'}&1) {
		# use Data::Dumper;
		# print STDERR Dumper($TABLE,$kvpairs,%options);
		}

	my $mode = 0;	# insert, 1=update, -1 skip action, 0 = figure it out, 2 = force insert
	if (defined $options{'verb'}) {
		$mode = -1;
		if ($options{'verb'} eq 'auto') { $mode = 0; }
		if ($options{'verb'} eq 'update') { $mode = 1; }
		if ($options{'verb'} eq 'insert') { $mode = 2; }
		if ($mode == -1) {
			warn "DBINFO::insert unknown verb=$options{'verb'} (should be auto|update|insert)\n";
			}
		}
	elsif ((defined $options{'update'}) && ($options{'update'}==2)) {
		## pass in update=>2 to force us to generate an update statement
		##		(do this when we're sure the record already exists)
		$mode = 1;
		}


	if (($mode == 0) && (defined $options{'key'})) {
		my $pstmt = '';

		if ( (ref($options{'key'}) eq 'SCALAR') || (ref($options{'key'}) eq '') ) {
			## simple: key=scalarkey  (value looked up in $kvpairs)
			$pstmt = "select count(*) from $TABLE where ".$options{'key'}.'='.$dbh->quote($kvpairs->{$options{'key'}});
			}
		elsif (ref($options{'key'}) eq 'ARRAY') {
			## more complex: key=[kvkey1,kvkey2,kvkey3] (values looked up in $kvpairs)
			foreach my $k (@{$options{'key'}}) {
				if ($pstmt ne '') { $pstmt .= " and "; }
				$pstmt .= $k.'='.$dbh->quote($kvpairs->{$k});
				}
			$pstmt = "select count(*) from $TABLE where $pstmt";
			}
		elsif (ref($options{'key'}) eq 'HASH') {
			## ultra complex: key={ key1=>value1, key2=>value2 }
			foreach my $k (keys %{$options{'key'}}) {
				if ($pstmt ne '') { $pstmt .= " and "; }
				$pstmt .= $k.'='.$dbh->quote($options{'key'}->{$k});
				}
			$pstmt = "select count(*) from $TABLE where $pstmt";
			}

		my $sth = $dbh->prepare($pstmt);
		$sth->execute();
		my ($exists) = $sth->fetchrow();
		$sth->finish();
		if ($exists>0) { 
			$mode = 1; # update
			} 
		else { 
			$mode = 2; # insert
			}

		if ((defined $options{'update'}) && ($options{'update'}==0) && ($mode==1)) {
			## if we are told not to do updates, and we're supposed to do an update then don't do anything.
			$mode = -1;
			}
		}

	if ($mode == 0) { $mode = 2; }	
	# convert any "auto" to automatic insert (since our function name is DBINFO::insert)

	my $pstmt = '';
	if ($mode==2) {
		## insert statement
		my $tmp = '';
		if (defined $options{'on_insert'}) {
			## on_insert is a hash of key values which are ONLY transmittined on insert e.g. CREATED_GMT
			foreach my $k (keys %{$options{'on_insert'}}) {
				$kvpairs->{$k} = $options{'on_insert'}->{$k};
				}
			}
		foreach my $k (sort keys %{$kvpairs}) {
			if ($pstmt) { $tmp .= ','; $pstmt .= ','; }
			if (substr($k,0,1) eq '*') { ## RAW
				$pstmt .= substr($k,1);
				$tmp .= $kvpairs->{$k};				
				}
			else {
				$pstmt .= $k;
				$tmp .= $dbh->quote($kvpairs->{$k});
				}
			}
		$pstmt = 'insert '.($options{'delayed'}?'DELAYED':'').' into '.$TABLE.' ('.$pstmt.') values ('.$tmp.')';
		}
	elsif (($mode==1) && (defined $options{'key'})) {
		## update statement
		foreach my $k (keys %{$kvpairs}) {
			if (substr($k,0,1) eq '*') { ## RAW
				$pstmt .= (($pstmt)?',':'').substr($k,1).'='.$kvpairs->{$k};
				}
			else {
				$pstmt .= (($pstmt)?',':'').$k.'='.$dbh->quote($kvpairs->{$k});
				}
			}

		if (ref($options{'key'}) eq 'SCALAR') {
			$pstmt = 'update '.($options{'delayed'}?'DELAYED':'')." $TABLE set ".$pstmt." where  ".$options{'key'}.'='.$dbh->quote($kvpairs->{$options{'key'}});
			}
		elsif (ref($options{'key'}) eq 'ARRAY') {
			## more complex: key=[kvkey1,kvkey2,kvkey3] (values looked up in $kvpairs)
			$pstmt = 'update '.($options{'delayed'}?'DELAYED':'')." $TABLE set $pstmt where ";
			my $count = 0;
			foreach my $k (@{$options{'key'}}) {
				if ($count++) { $pstmt .= " and "; }
				$pstmt .= $k.'='.$dbh->quote($kvpairs->{$k});
				}
			}
		elsif (ref($options{'key'}) eq 'HASH') {
			## ultra complex: key={ key1=>value1, key2=>value2 }
			$pstmt = 'update '.($options{'delayed'}?'DELAYED':'')." $TABLE set $pstmt where ";
			my $count = 0;
			foreach my $k (keys %{$options{'key'}}) {
				if ($count++) { $pstmt .= " and "; }
				$pstmt .= $k.'='.$dbh->quote($options{'key'}->{$k});
				}
			}

		}
	else {
		warn "DBINFO::insert NO KEY SPECIFIED BUT \$mode==$mode";
		}
	
	if ($options{'debug'}&1) {
		print STDERR "PSTMT: ".$pstmt."\n";
		}

	if (not $options{'debug'}&2) { 
		my $rv = $dbh->do($pstmt); 
		if (not $rv) {
			my ($package,$file,$line,$sub,$args) = caller(0);
			print STDERR "CALLER[0]: $package,$file,$line,$sub,$args\n";
			}
		}
	
	return($pstmt);
	}

##
## called just before the first db_zoovy_connect in  SITE.pm...
## since we know SITE.pm is expressly for the startup of pages, it
## makes sense that we can do cleanup there. -AK
##
sub init {
	my ($keepcount) = @_;
	if (not defined $keepcount) { $keepcount = 0; }
	}

## 
## create the persistent handle
##
sub db_zoovy_connect {
	my $HOSTNAME = $ENV{'HOSTNAME'};

	if ((defined $DBINFO::DBH_PERSIST) && (ref($DBINFO::DBH_PERSIST) ne 'DBI::db')) {
		## uh-oh, we can't ping the database
		$DBINFO::DBH_INSTANCE_COUNT = 0;
		print STDERR "FAILED DB PRODUCT PING - RESETTING INSTANCE COUNT!\n";
		}

	if (($DBINFO::DBH_INSTANCE_COUNT>0) && (not $DBINFO::DBH_PERSIST->ping())) {
		$DBINFO::DBH_INSTANCE_COUNT = 0;
		print STDERR "FAILED DB PRODUCT PING2 - RESETTING INSTANCE COUNT!\n";
		}

	if ( (not defined $DBINFO::DBH_PERSIST) || ($DBINFO::DBH_INSTANCE_COUNT==0)) {
		$DBINFO::DEBUG && print STDERR "db_zoovy_open\n";
		$DBINFO::DBH_PERSIST = DBI->connect($DBINFO::MYSQL_DSN,$DBINFO::MYSQL_USER,$DBINFO::MYSQL_PASS); 	
		$DBINFO::DBH_PERSIST->{mysql_auto_reconnect} = 1;

		## Is Database Down - Retry.
		#if (!defined($DBINFO::DBH_PERSIST)) {
		my $i = 0;
		while ( (++$i < 4) && (defined($DBI::err)) ) {
			warn $DBI::errstr;
			sleep($i);
			$DBINFO::DBH_PERSIST = DBI->connect($DBINFO::MYSQL_DSN,$DBINFO::MYSQL_USER,$DBINFO::MYSQL_PASS); 	
			$DBINFO::DBH_PERSIST->do("set time_zone='PDT'");
			}

		## Okay, it's *really* down
		if (defined($DBI::err)) {
			warn "DB FAIL! $DBINFO::MYSQL_DSN,$DBINFO::MYSQL_USER,$DBINFO::MYSQL_PASS\n";
			print "Content-type: text/plain\n\nError: Temporarily unable to reach database.  Please try your request again in a few minutes.\n\n";	
			open F, "|/usr/sbin/sendmail -t";
			#print F "To: brian\@zoovy.com\n";
			print F "To: brian\@zoovy.com\n";
			print F "From: nfs1\@zoovy.com\n";
			print F "Subject: Unable to connect to database on $ENV{'SERVER_ADDR'}\n\n";
			print F "Time was: ".time()."\n";
			print F "DSN: ".$DBINFO::MYSQL_DSN."\n";
			print F "DBI_Error: $DBI::errstr\n";
			close F;
			die("Could not connect to Database");
			}
		else {
			# warn "DB RECOVER!\n";
			}
	
		$DBINFO::DBH_INSTANCE_COUNT = 0;
		} 
	$DBINFO::DBH_INSTANCE_COUNT++;

	# print STDERR "db_zoovy_connect: $DBH_INSTANCE_COUNT\n";
	return($DBINFO::DBH_PERSIST);
	}

##
## close the persistent handle
##
sub db_zoovy_close {

#	my ($package,$file,$line,$sub,$args) = caller(1);
#	print STDERR "CLOSE [$DBINFO::DBH_INSTANCE_COUNT] $package,$file,$line,$sub,$args\n";

	if (defined($DBINFO::DBH_PERSIST)) {
		$DBINFO::DBH_INSTANCE_COUNT--;
		if ($DBINFO::DBH_INSTANCE_COUNT<=0) {
			$DBINFO::DEBUG && print STDERR "db_zoovy_close ".Dumper(caller(1))."\n";
			$DBINFO::DBH_PERSIST->disconnect();
			$DBINFO::DBH_PERSIST = undef;
			}
		}
	return(0);
	}


#############################################################################################


sub resolve_orders_tb {
	my ($USERNAME,$MID,$force) = @_;

	if (&ZOOVY::myrelease($USERNAME)>201338) { return("ORDERS"); }

	if ($MID==0) {
		require ZOOVY;
		($MID) = &ZOOVY::resolve_mid($USERNAME);
		}

	my $TBMID = $MID;
	if ($MID%10000>0) { $TBMID = $MID -($MID % 10000); }		
	my $NEWTB = 'ORDERS_'.$TBMID;

	my ($CLUSTER) = lc(&ZOOVY::resolve_cluster($USERNAME));
#	if ($CLUSTER eq 'crackle') {
#		return("ORDERS");
#		}
	

	return($NEWTB);	
	}


sub cleanup {
	foreach my $cluster (keys %DBINFO::USER_HANDLES) {
		if (defined $DBINFO::USER_HANDLES{$cluster}->[0]) {
			print STDERR "UHOH $cluster has $DBINFO::USER_HANDLES{$cluster}->[1] open handles\n";
			}
		}
	}

1;
