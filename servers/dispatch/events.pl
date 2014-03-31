#!/usr/bin/perl


use URI::Escape::XS;
use Proc::PID::File;
use strict;
use Fcntl ':flock';
use POSIX qw();
use App::Daemon qw();

# App::Daemon::daemonize();


use YAML::Syck;
$YAML::Syck::ImplicitBinary++;
$YAML::Syck::ImplicitUnicode++;
$YAML::Syck::SingleQuote++;      # do not fucking enable this. it has issues with cr/lf 183535

use lib "/httpd/modules";
use ZOOVY;
require PRODUCT;
use LISTING::MSGS;
use CART2;
use EXTERNAL;
use NAVCAT;
use Data::Dumper;
use strict;
use TODO;
use ELASTIC;
use PRODUCT;
use AMAZON3;
use SITE;
require INVENTORY2;
require BLAST;

## make sure we don't accidentally run two!
use Proc::PID::File;
die "Already running!" 
	if Proc::PID::File->running();

## we keep track of our current file -- if it changes later we'll exit
if (substr($0,0,1) eq '/') { $::SCRIPT_FILE = $0; } else { $::SCRIPT_FILE = "$ENV{'PWD'}/$0"; }
my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($::SCRIPT_FILE);
$::SCRIPT_CTIME = $ctime;


my %eFunctions = (
	'INV.GOTINSTOCK'=>\&e_INV_GOTINSTOCK,
	'INV.OUTOFSTOCK'=>\&e_INV_OUTOFSTOCK,
	'INV.CHANGED'=>\&e_INV_CHANGED,
	'ALERT.INV.RESTOCK'=>\&e_INV_RESTOCK,

	'ENQUIRY'=>\&e_ENQUIRY,
	'ENQUIRY.ORDER'=>\&e_ENQUIRY,
	'CUSTOMER.ORDER.CANCEL'=>\&e_ENQUIRY,

#	'NAVCAT.PATH.ADD'=>\&e_NAVCAT,
#	'NAVCAT.PATH.REMOVE'=>\&e_NAVCAT,

	'INV.NAVCAT.SHOW'=>\&e_NOTIFY,
	'INV.NAVCAT.HIDE'=>\&e_NOTIFY,
	'INV.NAVCAT.FAIL'=>\&e_NOTIFY,

#	'INV.NAVCAT.PATH.DELETED'=>\&e_NOTIFY,
#	'INV.NAVCAT.PATH.CHANGED'=>\&e_NOTIFY,
#	'INV.NAVCAT.PATH.CREATED'=>\&e_NOTIFY,

	'TICKET.CREATE'=>\&e_TICKET,
	'TICKET.CLOSE'=>\&e_TICKET,
	'TICKET.ASK'=>\&e_TICKET,
	'TICKET.UPDATE'=>\&e_TICKET,
	'PAYMENT.UPDATE'=>\&e_PAYMENT,
	'ORDER.CANCEL'=>\&e_ORDER,
	'ORDER.CREATE'=>\&e_ORDER,
	'ORDER.CREATED_DENIED_CANCEL'=>\&e_ORDER,
	'ORDER.PAID'=>\&e_ORDER,
	'ORDER.SHIP'=>\&e_ORDER,
	'ORDER.ARRIVE'=>\&e_ORDER,
	'ORDER.SAVE'=>\&e_ORDER,
	'ORDER.VERIFY'=>\&e_ORDER,

	## note 
	'ERROR.SYNDICATION'=>\&e_NOTIFY,	
	'ALERT.SYNDICATION'=>\&e_NOTIFY,
	'APIERR.SUPPLIER'=>\&e_NOTIFY,

	'PID.EBAY-CHANGE'=>\&e_PID,
	'PID.AMZ-CHANGE'=>\&e_PID,
	'PID.MKT-CHANGE'=>\&e_PID,
	'PID.PRICE-CHANGE'=>\&e_PID,
	'PID.COST-CHANGE'=>\&e_PID,
	'PID.CREATE'=>\&e_PID,
	'PID.GEOMETRY'=>\&e_PID,
	'PID.SAVED'=>\&e_PID,
	'PID.DELETE'=>\&e_PID,
	'PID.BROADCAST'=>\&e_BROADCAST,
	'SKU.CREATED'=>\&e_SKU,
	'SKU.REMOVED'=>\&e_SKU,
	'SYNDICATION.SUCCESS'=>\&e_SYNDICATION,
	'SYNDICATION.FAILURE'=>\&e_SYNDICATION,
	'CUSTOMER.SAVE'=>\&e_CUSTOMER,
	'CUSTOMER.NEW'=>\&e_CUSTOMER,

	'MKT.EBAY.START'=>\&e_MKT_EBAY,
	'MKT.EBAY.SOLD'=>\&e_MKT_EBAY,
	'MKT.EBAY.END' =>\&e_MKT_EBAY,
	);



my %params = ();
foreach my $arg (@ARGV) {
#	if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}

my $CLUSTER = lc($params{'cluster'});	# not actually cluster specific at this time.
my $UNLOCK = $params{'unlock'};		# unlock locked events after 3600 minutes
if (not defined $UNLOCK) { $UNLOCK++; }

if (defined $params{'user'}) {
	$CLUSTER = &ZOOVY::resolve_cluster($params{'user'});
	}

if ($CLUSTER eq '') {	
	die("Cluster is now required");
	}
print "CLUSTER: $CLUSTER\n";

my $ts = time(); 

my @USERS = ();
if ($params{'user'}) {
	push @USERS, $params{'user'};
	}

my $LOCK_ID = $$;
if ($params{'LOCK_ID'}) { $LOCK_ID = int($params{'LOCK_ID'}); }




sub run_timers {

	# my $limit = 1000; # int($params{'limit'});	# 4/3/2013
	my $limit = 2500;
	my $pstmt = "select ID,USERNAME,EVENT,YAML from USER_EVENT_TIMERS where PROCESSED_GMT=0 and DISPATCH_GMT<$ts order by ID limit $limit";
	print "$pstmt\n";
	my $ROWS = &DBINFO::fetch_all_into_hashref($params{'user'} || $CLUSTER,$pstmt);
	foreach my $row (@{$ROWS}) {
		my ($dbID,$USERNAME,$EVENT,$YAML) = ($row->{'ID'},$row->{'USERNAME'},$row->{'EVENT'},$row->{'YAML'});	

		next if (! -d &ZOOVY::resolve_userpath($row->{'USERNAME'}));

		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		print "DBID: $dbID $USERNAME $EVENT $YAML\n";
		next if (not &ZOOVY::locklocal("USER_EVENT_TIMERS",$USERNAME));
		my $YREF = {};
		my $ID = 0;
		if ($YAML ne '') {
			$YREF = YAML::Syck::Load($YAML);
			}
		if (scalar(keys %{$YREF})>0) {
			$YREF->{'#timer'} = $dbID;
			($ID) = &ZOOVY::add_event($USERNAME,$EVENT,%{$YREF});
			}
		$pstmt = "update USER_EVENT_TIMERS set PROCESSED_GMT=$ts,PROCESSED_ID=$ID where ID=$dbID /* $USERNAME $EVENT */";
		print STDERR $pstmt."\n";
		$udbh->do($pstmt);
		&DBINFO::db_user_close();
		}
	print "Done with timers!\n";
	return();
	}

## clear out records with too many attempts

my %LM_REF = ();



##
## writes cache to disk.
##
sub sync {
	print "!!!!!!!!!!!!!!!!!!!!!!\n";
	print "! SYNC\n";
	print "!!!!!!!!!!!!!!!!!!!!!!\n";
	my %SAVED = ();
	foreach my $ID (@{$::CACHE{'@'}}) {
		my ($TYPE) = split(/-/,$ID);	
		if (defined $SAVED{$ID}) {
			print "CACHED INTERCEPT - $ID!\n";
			}
		elsif ($TYPE eq 'NAVCAT') {
			print "SAVING[$TYPE]: $ID\n";
			$::CACHE{$ID}->[1]->save();
			delete $::CACHE{$ID};
			$SAVED{$ID}++;
			}
		else {
			warn "Could not save $ID (unknown type)\n";
			}
		}
	%::CACHE = ();	## RESET ALL CACHES
	return(0);
	}

sub sync_exit {
	&sync();
	print "Received exit\n";
	exit();
	}

## register signal handlers
$SIG{'HUP'} = \&sync_exit;
$SIG{'INT'} = \&sync_exit;

my ($redis) = &ZOOVY::getRedis($CLUSTER,1);
while (my ($YAML) = $redis->rpoplpush("EVENTS.PROCESSING","EVENTS")) {
	if (not defined $YAML) { 
		last; 
		}
	else {
		open F, ">>/tmp/events.log"; print F sprintf("%d|EVENTS.PROCESSING|%s\n",time(),$YAML); close F;
		}
	}

while (my ($YAML) = $redis->rpoplpush("EVENTS.RETRY","EVENTS")) {
	if (not defined $YAML) { 
		last; 
		}
	else {
		open F, ">>/tmp/events.log"; print F sprintf("%d|EVENTS.RETRY|%s\n",time(),$YAML); close F;
		}
	}

if (not $params{'limit'}) {
	&run_timers();
	}


%::CACHE = ();

my $LIMIT = $params{'limit'};
if ($LIMIT == 0) { $LIMIT = -1; }

my $loop = 0;
while ( my $YAML = $redis->brpoplpush("EVENTS","EVENTS.PROCESSING",1) ) {
	## DBUG:
	# print "YAML:$YAML\n"; sleep(1);
	
	$loop++;
	
	my $LINE = $YAML;
	$LINE =~ s/\\/\\\\/gs;
	$LINE =~ s/\n/\\n/gs;
	$LINE =~ s/\r/\\r/gs;

	open Fz, ">>/tmp/EVENTS.log";
	print Fz "$loop|".time()."|".$LINE."\n";
	close Fz;
	
	if ( (($loop % 100) == 0) || ($YAML eq '') ) {
		## every 250 loops we check to see if we are the most current version, if not - then we exit.
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($::SCRIPT_FILE);
		if ($::SCRIPT_CTIME != $ctime) {
			print "SCRIPT $::SCRIPT_FILE HAS NEW VERSION\n";
			&sync();
			last;
			}
		}

	if ($YAML eq '') { 
		## ONLY QUEUE DO THESE WHEN THE QUEUE IS EMPTY
		if (scalar(keys %::CACHE)>0) { &sync(); }
		## lowered loop % 100 to loop %10
		if (($loop % 10) == 0) { &run_timers(); }	## make sure we've processed any timers.
		print "."; sleep(3); 
		if (($loop % 10)==0) { print "\n"; }
		## if /tmp/events.reset exists, then restart the process
		if (-f "/tmp/events.reset") { unlink("/tmp/events.reset"); &sync(); last; }	## secret file to make us exit.
		}
	elsif ( (scalar(keys %::CACHE)>0) && (($loop % 1000) == 0) ) { 
		## always write to disk.
		&sync(); 
		}		


	next if ($YAML eq '');				## nothing to do!

	my $YREF = {};
	if ($YAML ne '') {
		$YREF = eval { YAML::Syck::Load($YAML); };
		}
	
	print "YAML:$YAML\n";

	my $USERNAME = $YREF->{'_USERNAME'};
	my $TS = $YREF->{'_TS'};
	if ((defined $TS) && ($TS < time()-(86400*10) )) {
		## no replay after 10 day
		warn "Deleting event because it's too old: $TS\n";
		$redis->lrem("EVENTS.PROCESSING",-1,$YAML);
		next;
		}

	next if (! -d &ZOOVY::resolve_userpath($USERNAME));

	my $PRT = $YREF->{'PRT'};
	my $EVENT = $YREF->{'_EVENT'};
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	last if (not $udbh);
	last if (not $udbh->ping());		## don't run if we have no database connection

	$USERNAME = uc($USERNAME);
	print "TRYING: $USERNAME\n";

	if (not defined $LM_REF{$USERNAME}) {
		my ($LM) = LISTING::MSGS->new($USERNAME,logfile=>"~/events-%YYYYMM%.log");
		$LM_REF{$USERNAME} = $LM;
		}

	$USERNAME = uc($USERNAME);
	print "ID: $USERNAME\[$PRT\] $EVENT\n";
	
	my $LM = $LM_REF{$USERNAME};
	$LM->logdate();		## advance the date for our logfile
	if (not defined $LM) {
		print STDERR Dumper(\%LM_REF);
		last;
		}

	if (not defined $YREF->{'PRT'}) { $YREF->{'PRT'} = $PRT; }
	if (not defined $YREF->{'#attempts'}) { $YREF->{'#attempts'} = 0; }
	if (not defined $YREF->{'#created_gmt'}) { $YREF->{'#created_gmt'} = $YREF->{'_TS'}; }

	$EVENT = uc($EVENT);
	my $error = undef;
	if (not defined $eFunctions{$EVENT}) {
		$error = "EVENT:$EVENT is undefined";
		}

	my $IGNORE = 0;
	if ((defined $YREF->{'ORDERID'}) && ($YREF->{'ORDERID'} =~ /^20(01|02|03|04|05|06|07|08|09|10|11)\-/)) {
		## ignore this
		warn "IGNORING!\n";
		$IGNORE++;
		}
	elsif (not defined $error) {	
		# print "TRY: $EVENT $USERNAME $PRT ".Dumper($YREF)."\n";
		if (not eval { ($error) = $eFunctions{$EVENT}->($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,\%::CACHE); }) {
			$error = $@;
			}
		}

	if ($IGNORE) {
		$redis->lpush("EVENTS.IGNORED",$YAML);
		warn "was ignored!\n";
		}
	elsif (defined $error) {
		##
		## bat shit happened.. so we save the #err and #ets (error timestamp)
		##
		print "ERR-$error (did not delete EVENT)\n";
		$YREF->{'#attempts'}++;
		$YREF->{'#err'} = $error;
		$YREF->{'#ets'} = time();
		my $REVISEDYAML = YAML::Syck::Dump($YREF);
		if ($YREF->{'#attempts'}<1) {
			$redis->lpush("EVENTS.RETRY",$REVISEDYAML);
			$LM->pooshmsg("RETRY|PRT:$PRT|E:$EVENT|+$error");
			}
		else {
			$LM->pooshmsg("FAIL|PRT:$PRT|E:$EVENT|+$error");
			open F, ">/tmp/EVENT-FAILED_$USERNAME.$EVENT.".time();
			print F $REVISEDYAML;
			close F;
			}
		}
	else {
		my $str = '';
		foreach my $k (sort keys %{$YREF}) { $str .= sprintf("%s=%s ",$k,substr($YREF->{$k},0,25));  }
		$LM->pooshmsg("SUCCESS|$str");
		}

	if ($YAML ne '') {
		$redis->lrem("EVENTS.PROCESSING",-1,$YAML);
		}

	open Fz, ">>/tmp/EVENT.log";
	print Fz "$loop||done!\n";
	close Fz;
	&DBINFO::db_user_close();
	}

## NOTE: THIS LINE SHOULD NEVER BE REACHED!
&sync();
&DBINFO::db_user_close();



##
##
##
sub load_cached_resource {
	my ($CACHEREF,$TYPE,$USERNAME,$ID) = @_;

	my $CACHEID = sprintf("$TYPE-$USERNAME-$ID");
	if (not defined $CACHEREF->{$CACHEID}) {
		if ($TYPE eq 'NAVCAT') {
			## USERNAME,PRT
			$CACHEREF->{$CACHEID} = [ 0, NAVCAT->new($USERNAME,'PRT'=>$ID) ];
			}
		elsif ($TYPE eq 'PRODUCT') {
			## USERNAME,PID
			$CACHEREF->{$CACHEID} = [ 0, PRODUCT->new($USERNAME,$ID,'create'=>0) ];
			}
		}

	if (defined $CACHEREF->{$CACHEID}) {
		$CACHEREF->{$CACHEID}->[0]++;		## increment the counter.
		return($CACHEREF->{$CACHEID}->[1]);
		}
	warn "Unknown resource type: $TYPE [$CACHEID]\n";
	return(undef);
	}


############################################################
##
## 
##
sub queue_save {
	my ($CACHEREF,$TYPE,$USERNAME,$PRT) = @_;

	my $ID = sprintf("$TYPE-$USERNAME-$PRT");
	print "QUEUED SAVE $ID\n";
	push @{$CACHEREF->{'@'}}, $ID;
	}



sub e_MKT_EBAY {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;

#	## CLEANUP
#		my $EBAY_ID = $incref->{'MKT_LISTINGID'};
#		my ($MID) = $self->mid();
#		$pstmt = "select * from EBAY_LISTINGS where EBAY_ID=".$udbh->quote($EBAY_ID)." and MID=$MID /* $USERNAME */";
#		print STDERR $pstmt."\n";
#		my $itemref = $udbh->selectrow_hashref($pstmt);
#		my $soldqty = undef;
#
#		if ($itemref->{'IS_ENDED'}==0) {
#			## first, check the winners table - if it exists keep moving!
#			my $pstmt = "select sum(QTY) from EBAY_WINNERS where EBAY_ID=".$udbh->quote($EBAY_ID)." and MID=$MID /* $USERNAME */";
#			print $pstmt."\n";
#			my ($soldqty) = $udbh->selectrow_array($pstmt);
#	
#			if ($itemref->{'ITEMS_SOLD'} != $soldqty) {
#				my $pstmt = "update EBAY_LISTINGS set ITEMS_SOLD=$soldqty where EBAY_ID=".$udbh->quote($EBAY_ID)." and MID=$MID /* $USERNAME */";
#				$udbh->do($pstmt);
#				$itemref->{'ITEMS_SOLD'} = $soldqty;	
#				}
#			}
#
#		if ($itemref->{'IS_SYNDICATED'}) {
#			}
#		elsif ($itemref->{'IS_GTC'}) {
#			}
#		else {
#			$self->INV2()->mktinvcmd( 'END', "EBAY", $EBAY_ID, $itemref->{'PRODUCT'}, 'QTY'=>0 );
#			}

	}



##
##
sub e_NOTIFY {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;

	## ERROR.SYNDICATION
	##	ALERT.SYNDICATION

	my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	my (@PIECES) = split(/\./,$EVENT,2);

	my $done = undef;
	do {
		my ($EVENTID) = join('.',@PIECES);
		print STDERR "EVENT:$EVENTID\n";
		
		my $ROWS = $webdb->{'%NOTIFICATIONS'}->{ $EVENTID };

		if (not defined $ROWS) {
			## force sane defaults.
			if ($EVENTID eq 'ENQUIRY') { $ROWS = [ 'verb=task'] };
			if ($EVENTID eq 'ERROR') { $ROWS = [ 'verb=task'] };
			if ($EVENTID eq 'ALERT') { $ROWS = [ 'verb=task'] };
			if ($EVENTID eq 'APIERR') { $ROWS = [ 'verb=task'] };
			if ($EVENTID eq 'CUSTOMER.ORDER.CANCEL') { $ROWS = [ 'verb=task'] };
			if ($EVENTID eq 'INV.NAVCAT.SHOW') { $ROWS = [ 'verb=task'] };
			if ($EVENTID eq 'INV.NAVCAT.HIDE') { $ROWS = [ 'verb=task'] };
			if ($EVENTID eq 'INV.NAVCAT.FAIL') { $ROWS = [ 'verb=task'] };
			}

		if ((defined $ROWS) && (ref($ROWS) eq 'ARRAY')) {
			$done++;
			foreach my $ROWSTR (@{$ROWS}) {
				print STDERR "e_NOTIFY[$EVENT] $ROWSTR\n";
				my ($row) = &ZTOOLKIT::parseparams($ROWSTR);
				my $VERB = lc($row->{'verb'});
				$row->{'event'} = $EVENT;
				
				if ($VERB eq 'noop') {
					## do nothing.. that was easy.
					}
				elsif ($VERB eq 'email') {
					my ($RECIPIENT) = $row->{'email'};
					print STDERR "RECIPIENT: $RECIPIENT\n";
					open MH, "|/usr/sbin/sendmail -t $RECIPIENT";
					print MH "To: $RECIPIENT\n";

					my $FROM = $row->{'from'} || $RECIPIENT;
					print MH "From: $RECIPIENT\n";
					print MH "X-Source-Event: $EVENT\n";
					my $TITLE = $YREF->{'title'} || $row->{'title'} || sprintf("EVENT $EVENT");
					$TITLE =~ s/[^A-Z0-9a-z\s\-\_\.\!]+//gs;

					my $BODY = $YREF->{'detail'} || $YREF->{'body'};
					print MH "Subject: $TITLE\n\n";
					foreach my $k (keys %{$YREF}) {
						next if (substr($k,0,1) eq '_');
						print MH sprintf("%s: %s\n",$k,$YREF->{$k});
						}
					print MH "$BODY\n\n";
					# print MH "https://admin.zoovy.com/support/index.cgi?USERNAME=$USERNAME&TICKET=$TICKETID\n\n";
					close MH;
					}
				elsif ($VERB eq 'crmticket') {
					my ($CID) = 0;
					my ($DOMAIN) = '';
		  			require CUSTOMER::TICKET;
					my ($CT) = CUSTOMER::TICKET->new($USERNAME,0,
						new=>1,PRT=>$PRT,CID=>$CID,DOMAIN=>$DOMAIN,
						SUBJECT=>$YREF->{'title'},
						NOTE=>$YREF->{'detail'},	
						%{$row}, %{$YREF}
						);
					}
				elsif ($VERB eq 'task') {			
					require TODO;
					TODO::easylog($USERNAME,%{$row},%{$YREF});
					}			
				elsif ($VERB eq 'awssqs') {
#					## url
#					require Amazon::SQS::Simple;
#					my $sqs = new Amazon::SQS::Simple($S->fetch_property('.order.aws_access_key'), $S->fetch_property('.order.aws_secret_key'));
#					my $q = $sqs->CreateQueue($S->fetch_property('.order.aws_sqs_channel'));
#					$q->SendMessage($body);
#					$olm->pooshmsg("SUCCESS|+Transmitted");
					}
				elsif ($VERB eq 'http') {
#					## url
#					my $agent = LWP::UserAgent->new( 'ssl_opts'=>{ 'verify_hostname' => 0 } );
#					$agent->timeout(15);
					}
				}
			}
		
		pop @PIECES;	## remove the extension
		if (scalar(@PIECES)==0) { $done = 0; }
		}
	while (not defined $done);	


	}


##
## ENQUIRY.ORDER.CANCEL
sub e_ENQUIRY {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;


	return(&e_NOTIFY(@_));

#         require TODO;
#         my ($t) = TODO->new($SITE->username(),writeonly=>1);
#         $t->add(class=>"MSG",link=>"order:$orderid",title=>$subject,detail=>$message);


#         &ZOOVY::add_event($SITE->username(),
#            "ENQUIRY.ORDER.CANCEL",
#            class=>"MSG",
#            order=>$orderid,
#            link=>"order:$orderid",
#            title=>$subject,
#            detail=>$message
#            );


	return(undef);
	}



sub e_SYNDICATION {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;

	if ($EVENT eq 'SYNDICATION.FAILURE') {
		my ($so) = SYNDICATION->new($USERNAME,$YREF->{'NS'},$YREF->{'DST'},type=>$YREF->{'FEED'});
		}

	return(undef);
	}



sub e_NAVCAT {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;

	return(&e_NOTIFY(@_));
#	if (defined $self->{$path}->[4]) {
#		if ((defined $self->{$path}->[4]->{'WS'}) && ($self->{$path}->[4]->{'WS'}>0)) {
#			## is a published category -- write out a dump file.
#			my $ts = time();
#			my $MERCHANT  = $self->{'_USERNAME'};
#			my $PRETTY = $self->{$path}->[0];
#			my $PRODUCTS = $self->{$path}->[2];
#			my $MID = &ZOOVY::resolve_mid($MERCHANT);
#			my $file = &ZOOVY::resolve_userpath($MERCHANT)."/IMAGES/".substr($path,1).".xml";
#			open F, ">$file";
#			print F qq~<\?xml version="1.0" encoding="utf-8"\?>~;
#			print F qq~<Navcat mid="$MID" merchant="$MERCHANT" ts="$ts" pretty="~.&ZTOOLKIT::encode("$MERCHANT $PRETTY").qq~" uuid="$MERCHANT$path">~;
#			foreach my $pid (split(/,/,$PRODUCTS)) {
#				print F qq~<product pid="$pid" ts="0"/>~;
#				}
#			print F qq~</Navcat>~;
#			close F;	
#			}
#		}
	
	return(undef);
	}



sub e_BROADCAST {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;

	

	}



#############################################################
##
## this is just a placeholder.. more to come.
##
sub e_SKU {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;
	return(undef);
	}

#############################################################
##
##
##
sub e_PID {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);	
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	
	print STDERR Dumper($YREF);
	
	my $PID = $YREF->{'PID'};
	if (not defined $PID) {
		die();
		}
	

	my $CREATED_GMT = $YREF->{'#created_gmt'};
	if (not $CREATED_GMT) { $CREATED_GMT = time(); }

	my @SQ_VERBS = ();

	my ($P) = &load_cached_resource($CACHEREF,'PRODUCT',$USERNAME,$PID);

	if ($EVENT eq 'PID.AMZ-CHANGE') {
		## one or more properties that impact amazon have changed.
		my $pstmt = "update LOW_PRIORITY SYNDICATION_PID_ERRORS set ARCHIVE_GMT=$CREATED_GMT where ARCHIVE_GMT=0 and MID=$MID /* $USERNAME */ and DSTCODE='AMZ' and PID=".$udbh->quote($PID);
		$udbh->do($pstmt);
		push @SQ_VERBS, [ $PID, 'AMZ', 'UPDATE' ]; 
		require AMAZON3;
		&AMAZON3::item_set_status({USERNAME=>$USERNAME,MID=>$MID},$PID,['+all.todo'],'USE_PIDS'=>1);
		}

	my %MKT_STATUS = ();
	if ($EVENT eq 'PID.MKT-CHANGE') {
		## use is/was variables to record changes
		require LISTING::EVENT;
		print STDERR "MKT-CHANGE - PID:$PID is:$YREF->{'is'}  was:$YREF->{'was'}\n";
		foreach my $is (@{&ZOOVY::bitstr_bits($YREF->{'is'})}) {
			$MKT_STATUS{$is} |= 2; 
			}
		foreach my $was (@{&ZOOVY::bitstr_bits($YREF->{'was'})}) {
			$MKT_STATUS{$was} |= 1;
			}
		foreach my $id (keys %MKT_STATUS) {
			my $INTREF = &ZOOVY::fetch_integration('id'=>$id);
			##
			## amz:ts on/off code
			##
			if ($INTREF->{'dst'} ne 'AMZ') {
				## NOT AMAZON - DON'T CARE
				}
			elsif ($MKT_STATUS{$id}==3) {
				## NO CHANGE
				}
			elsif (($MKT_STATUS{$id}==1) && ($INTREF->{'dst'} eq 'AMZ')) {
				## WAS ONLY: REMOVED AMAZON
			push @SQ_VERBS, [ $PID, 'AMZ', 'DELETE' ]; 
				&AMAZON3::item_set_status({USERNAME=>$USERNAME,MID=>$MID},$PID,['=this.delete_please'],'USE_PIDS'=>1);
				}
			elsif (($MKT_STATUS{$id}==2) && ($INTREF->{'dst'} eq 'AMZ')) {
				## IS ONLY: ADDED AMAZON
			push @SQ_VERBS, [ $PID, 'AMZ', 'CREATE' ]; 
				&AMAZON3::item_set_status({USERNAME=>$USERNAME,MID=>$MID},$PID,['=this.create_please'],'USE_PIDS'=>1);
				}
			}
		}

	if ($EVENT eq 'PID.CREATE') {
		if ($P->fetch('amz:ts')) { 
			&AMAZON3::item_set_status({USERNAME=>$USERNAME,MID=>$MID},$PID,['=this.create_please'],'USE_PIDS'=>1);
			}
		}

	if ($EVENT eq 'PID.GEOMETRY') {
		if ($P->fetch('amz:ts')) { 
			push @SQ_VERBS, [ $PID, 'AMZ', 'GEOMETRY' ]; 
			}
		}
	
	if ($EVENT eq 'PID.SAVED') {
		## reindex the product
		warn "elastic updated $PID\n";
		&ELASTIC::add_products($USERNAME,[$P]);
		}

	if ($EVENT eq 'PID.EBAY-CHANGE') {
		## clean up the error log.
		my $pstmt = "update LOW_PRIORITY SYNDICATION_PID_ERRORS set ARCHIVE_GMT=$CREATED_GMT where ARCHIVE_GMT=0 and MID=$MID /* $USERNAME */ and DSTCODE='EBF' and PID=".$udbh->quote($PID);
		$udbh->do($pstmt);
		push @SQ_VERBS, [ $PID, 'EBF', 'UPDATE' ];
		}
		
	if ($EVENT eq 'PID.MKT-CHANGE') {
		## use is/was variables to record changes
		require LISTING::EVENT;

		foreach my $id (keys %MKT_STATUS) {
			my $INTREF = &ZOOVY::fetch_integration('id'=>$id);

			if ($MKT_STATUS{$id}==3) {
				## NO CHANGE
				}
			elsif (($MKT_STATUS{$id}==1) && ($INTREF->{'dst'} eq 'EBF')) {
				## WAS ONLY: REMOVED EBAY FIXED PRICE (SYNDICATION)
				push @SQ_VERBS, [ $PID, 'EBF', 'REMOVE' ];
				}
			elsif (($MKT_STATUS{$id}==2) &&($INTREF->{'dst'} eq 'EBF')) {
				## IS ONLY: ADDED EBAY FIXED PRICE (SYNDICATION)
			push @SQ_VERBS, [ $PID, 'EBF', 'INSERT' ];
				}
			#elsif (($MKT_STATUS{$id}==2) && ($INTREF->{'dst'} eq 'EBA')) {
			#	## WAS ONLY: REMOVED EBAY AUCTION PRICE
			#	}
			#elsif (($MKT_STATUS{$id}==1) && ($INTREF->{'dst'} eq 'EBA')) {
			#	## IS ONLY: ADDED EBAY AUCTION PRICE
			#	}
			elsif (($MKT_STATUS{$id}==2) && ($INTREF->{'dst'} eq 'BUY')) {
				## WAS ONLY: REMOVE BUY.COM
				}
			elsif (($MKT_STATUS{$id}==1) && ($INTREF->{'dst'} eq 'BUY')) {
				## IS ONLY: ADDED BUY.COM 
				push @SQ_VERBS, [ $PID, 'BUY', 'REMOVE' ];
				}
			}
		}

	if ($EVENT eq 'PID.PRICE-CHANGE') {
		if ($P->fetch('ebay:ts')) { push @SQ_VERBS, [ $PID, 'EBF', 'UPDATE' ]; }
		if ($P->fetch('buy:ts')) { push @SQ_VERBS, [ $PID, 'BUY', 'UPDATE' ]; }
		if ($P->fetch('amz:ts')) { &AMAZON3::item_set_status({USERNAME=>$USERNAME,MID=>$MID},$PID,['+prices.todo']); }
		foreach my $intref (@ZOOVY::INTEGRATIONS) {
			next if (not defined $intref->{'attr'});
			## hmm.. eventaally maybe that will just dispatch directly from @ZOOVY::INTEGRATIONS!
			}
		}
		
	if ($EVENT eq 'PID.COST-CHANGE') {
		}
	
	# my @SKUS = ();
	if ($EVENT eq 'PID.DELETE') {
		## nuke from ELASTIC 
		require ELASTIC;
		my ($es) = &ZOOVY::getElasticSearch($USERNAME);
		$es->delete(
			'index'=>lc("$USERNAME.public"),
			'type'=>'product',
			'id'=>$PID,
			);
		$es->delete_by_query(
			'index'=>lc("$USERNAME.public"),
			'type'=>'sku',
			'queryb'=>{ 'pid'=>$PID },
			);
		}

	if (scalar(@SQ_VERBS)>0) {
		my %ALREADY_QUEUED_EVENTS = ();

		foreach my $vars (@SQ_VERBS) {
			my ($SKU,$DST,$VERB) = @{$vars};
			my $ALREADY_DID_EVENT = 0;
			my $EVENT_GUID = "$USERNAME.$SKU.$DST.$VERB";

			if (($DST eq 'EBF') && ($VERB eq 'UPDATE')) {
				## we try to handle eBay events in realtime, but (eventually) we'll queue if we get a failure
				require EBAY2;
				my ($error) = &EBAY2::sync_inventory($USERNAME,$SKU);
				if ($error) {
					$LM->pooshmsg("EBAY-API-ERROR|SKU:$SKU|+$error");
					}
				$ALREADY_DID_EVENT++;
				}
			
			if (($DST eq 'AMZ') && ($VERB eq 'SYNC')) {
				## this gets dumped into SYNDICATION_QUEUED_EVENTS
				}

			if (($DST eq 'AMZ') && ($VERB eq 'REMOVE')) {
				## this gets dumped into SYNDICATION_QUEUED_EVENTS
				}

			if ($ALREADY_DID_EVENT) {
				}
			elsif ($ALREADY_QUEUED_EVENTS{$EVENT_GUID}) {
				}
			else {
				if (not defined $SKU) { $SKU = $PID; }
				my $pstmt = &DBINFO::insert($udbh,'SYNDICATION_QUEUED_EVENTS',{
					'USERNAME'=>$USERNAME,
					'MID'=>$MID,
					'PRODUCT'=>$PID,
					'SKU'=>$SKU,
					'CREATED_GMT'=>$CREATED_GMT,
					'DST'=>$DST,
					'VERB'=>$VERB,
					# 'ORIGIN_EVENT'=>int($YREF->{'#id'}),
					'ORIGIN_EVENT'=>0,
					},sql=>1,insert=>1);
				print $pstmt."\n";
				$udbh->do($pstmt);
				$ALREADY_QUEUED_EVENTS{$EVENT_GUID}++;
				}
			}
		}

	&DBINFO::db_user_close();
	return(undef);
	}


################################################################
##
##
##
sub e_ORDER {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;

	$EVENT = uc($EVENT);
	my ($ORDERID) = $YREF->{'ORDERID'};
	print "ID:  $USERNAME\[$PRT\] $ORDERID/$EVENT\n";
	my $success = 1;
	# my ($o,$err) = ORDER->new($USERNAME,$ORDERID);
	my ($O2) = CART2->new_from_oid($USERNAME,$ORDERID);
	
	if ((not defined $O2) || (ref($O2) ne 'CART2')) {
		if ($YREF->{'#attempts'}>2) {
			return(undef);	# after two attempts, fuck it, delete the event.
			}
		return("COULD-NOT-LOAD-ORDER");	# error, try again.
		}
	
	## OLD LEGACY CODE FOR MKT to MKTS conversion
	my @SHIP_NOTIFY_DSTS = ();
	my %ORDER_DST = ();
	my ($mkts) = $O2->in_get('our/mkts');
	foreach my $bit (@{&ZOOVY::bitstr_bits($mkts)}) {
		foreach my $ref (@ZOOVY::INTEGRATIONS) {
			if ($ref->{'id'} == $bit) { 
				$ORDER_DST{$ref->{'dst'}}++;

				if ($ref->{'ship_notify'}) {
					push @SHIP_NOTIFY_DSTS, $ref->{'dst'};
					}
				}
			}
		}
	$ORDER_DST{'mkts'} = $mkts;
	print 'DST: '.Dumper(\%ORDER_DST);

	##
	## TODO: add some locking code here!
	##
	#	if ($EVENT eq 'inc-fix') {
	#		($success) = &flag_incomplete($o,$EVENT);
	#		}

	if ($O2->stuff2()->count('show'=>'real') == 0) {
		$O2->add_history("skipped event:$EVENT reason: No items in order (probably corrupt order)",etype=>2+8);
		warn "No stuff in order!\n";
		$success = 0;
		}
	elsif (scalar(@{ $O2->payments() })==0) {
		if ($EVENT eq 'ORDER.SHIP') {
			## no reason to discriminate		
			}
		else {
			$O2->add_history("skipped event:$EVENT reason: No Payments in order (probably corrupt order)",etype=>2+8);
			warn "No payments in order!\n";
			$success = 0;
			}
		}

	## ORDER.VERIFY


	
	if (not $success) {
		}
	elsif ($EVENT eq 'ORDER.CREATE') {
		($success) = &flag_incomplete($O2,$EVENT);

		if ($O2->in_get('customer/cid')>0) {
			## yay, already linked to a customer
			}
		elsif ($O2->in_get('bill/email') ne '') {
			## we have an email address, see if we should link these up
			
			#my ($C) = CUSTOMER->new($USERNAME,CID=>$CID);
			#my ($CART2) = CART2->new_from_oid($USERNAME,$ZOOVY::cgiv->{'link'});
			## &CUSTOMER::save_order_for_customer($USERNAME,$O2->oid(),$C->email());
			my ($CID) = &CUSTOMER::resolve_customer_id($O2->username(),$O2->prt(),$O2->in_get('bill/email'));
			if ($CID>0) {
				$O2->add_history(sprintf("Linking order to customer #%d",$CID),'luser'=>"*$EVENT");
				$O2->in_set('customer/cid',$CID);
				$O2->in_set('flow/flags', $O2->in_get('flow/flags') | (1<<2));
				my ($C) = CUSTOMER->new($O2->username(),'PRT'=>$O2->prt(),'CID'=>$CID,'INIT'=>0x1);
				if (defined $C) {
					$C->associate_order($O2);
					}
				}
			}

		# if ($O2->in_get('our/order_ts')<1293480000) {
		#if ($O2->in_get('our/order_ts')< 1351624351) {
		#	}
		$redis->select(1);
		my $REDIS_KPI_KEY = sprintf("CHECKPOINT.EVENT.KPI.%s.%s.%s",$O2->username(),$O2->oid(),$EVENT);
		print "REACHED CHECKPOINT $REDIS_KPI_KEY\n";
		if (not $success) {
			print "CHECKPOINT $REDIS_KPI_KEY = NO SUCCESS\n";
			}
		elsif ($O2->in_get('our/order_ts') < (time()-(86400*7)) ) {
			## no kpi after 7 days in the past.
			print "CHECKPOINT $REDIS_KPI_KEY = TOO OLD\n";
			}
		elsif ($redis->exists( $REDIS_KPI_KEY )>0) {
			## been here, tapped that.
			print "CHECKPOINT $REDIS_KPI_KEY = BEEN HERE\n";
			}
		else {
			## KPI
			require KPIBI;
			my ($KPI) = KPIBI->new($USERNAME,$O2->prt());
			my ($statdata) = $O2->order_kpistats();
			$KPI->stats_store($statdata);
			$redis->setex($REDIS_KPI_KEY,86400*7,time());
			print "CHECKPOINT $REDIS_KPI_KEY = DONE THAT\n";
			}


		if ($O2->in_get('our/order_ts') < (time() - 86400*7)) {
			## don't run create events on orders older than 7 days
			}
		elsif ($O2->has_supplychain_items()) {
			## process supply chain
			INVENTORY2->new($O2->username(),"*PROCESS")->process_order($O2);
			## $O2->process_order('create');
			}

		## DENIED orders
		if (not $success) {
			}
		elsif (ZPAY::payment_status_short_desc($O2->payment_status()) eq 'DENIED') {
			## create ORDER.CREATED_DENIED_CANCEL USER_EVENT_TIMER
			my $hours = 0;
			if ($USERNAME eq 'DESIGNED2BSWEET') {
				$hours = 1;
				}
			elsif ($USERNAME eq 'ZEPHYRSPORTS') {	
				$hours = 3;
				}
			if ($hours > 0) {
				## CANCEL order (if not corrected) in $hours
				## ORDER.CREATED_DENIED_CANCEL => want to make sure event has DENIED in name, 
				## so we check to see if order in still in DENIED status, before cancelling
				my ($udbh) = &DBINFO::db_user_connect($USERNAME);
				&ZOOVY::add_event($USERNAME,"ORDER.CREATED_DENIED_CANCEL",
					'DISPATCH_GMT'=>time()+($hours*3600),
					%{$YREF}
					);
				&DBINFO::db_user_close();
				$O2->add_history("Added event: ORDER.CREATED_DENIED_CANCEL to cancel order in $hours hour(s) (if still DENIED)");
				}
			}
		}

	## automatically cancel DENIED orders
	if (not $success) {
		}
	elsif ($EVENT eq 'ORDER.CREATED_DENIED_CANCEL') {
		## check if order is still DENIED
		if (ZPAY::payment_status_short_desc($O2->payment_status()) eq 'DENIED') {
			$O2->add_history("ORDER.CREATED_DENIED_CANCEL event called",etype=>1+2+4,);
			$O2->cancelOrder();
			$O2->run_macro("SETPOOL?pool=DELETED");
			}
		}	 



	if (not $success) {
		}	
	elsif ($EVENT eq 'ORDER.SHIP') {
		## check for ebay stuff and notify of shipment

		if ($ORDER_DST{'EBA'} || $ORDER_DST{'EBF'}) {
			## EBAY
			($success) = &notify_ebay($O2,$EVENT); 
			}

		foreach my $DST ('AMZ','BUY','BST','SRS','EGG','HSN','EBF','EBAY') {
			if (defined $ORDER_DST{$DST}) {
				my $KEY = uc(sprintf("EVENTS.ORDER.SHIP.$DST.%s", $O2->username() ));
				$redis->select(1);
				$redis->rpush($KEY,$O2->oid()); 	## rpush is better because the oldest goes on first
				$redis->expire($KEY,86400*30);
				}
			}
	
		if ($O2->in_get('is/origin_marketplace')==0) {
			## 'GTS': GOOGLE TRUSTED STORES
			my $KEY = uc(sprintf("EVENTS.ORDER.SHIP.GTS.%s", $O2->username() ));
			my ($redis) = &ZOOVY::getRedis($O2->username(),1);
			my $EXISTS = $redis->exists($KEY);
			$redis->lpush($KEY,$O2->oid()); 
			if (not $EXISTS) {
				## unlike marketplaces, where there is a REASONABLE assumption if we're continuing to receive orders down
				## THEN there is a good likihood we'll *eventually* be able to send the tracking back up, 
				## BUT with GTS there is no guarantee we will ever send this queue [is it even enabled], 
				## SO don't let it grow infinitely.
				## OKAY SO we set the expires to 30 days, but never reset it with each new order, if it isn't sent within 30
				## days of the FIRST order then the whole queue would be dumped and start over again.
				$redis->expire($KEY,86400*30);
				}
			else {
				## check the length of the queue (llen)+ttl and recommend they get on it!
				}
			}

		if ($ORDER_DST{'FBA'}) {
			## FBA ORDERS's - we don't need to notify amazon (because that's where we got 'em)
			}
		elsif (($ORDER_DST{'AMZ'}) || ($O2->in_get('mkt/amazon_orderid') ne '')) {
			## AMAZON
			($success) = &notify_amazon($O2,$EVENT);
			}

		## automatically set orders to COMPLETED
		if ($USERNAME eq 'DESIGNED2BSWEET') {
			$O2->run_macro("SETPOOL?pool=COMPLETED");
			}

		## added by patti - 2011-10-12
		## note: addition has been tested, just needs to be pushed to production...
		#if ($USERNAME eq 'amphidex') {
		#	## only set orders to COMPLETED that have 1 only item and have been SHIPPED
		#	## note: orders that have qty=2 for one item.. count=2, ie not moved to COMPLETED
		#	if ($O2->stuff2()->count(1) == 1) {
		#		$O2->add_history("ORDER.SHIP event called, moved single-item shipped order to COMPLETED");
		#		$o->run_macro("SETPOOL?pool=completed");
		#		}
		#	}

		## determine which carriers were used to ship order
		## 	we may use this info more in the future to determine how far in the 
		##		future we should send ORDER.ARRIVE emails
		my %carriers = (
			'UPS' => 0,
			'USPS'=> 0,
			'FDX' => 0,
			);
		foreach my $track (@{$O2->tracking()}) {
			## convert ship code to carrier: UPS,USPS,FDX
			my $carrier = ZSHIP::shipinfo($track->{'carrier'},'carrier');
			$carriers{$carrier}++;
			}
	
		## create ORDER.ARRIVE event
		### days in ORDER.SHIP depend on if international or domestic order (and possibly the carrier used)
		my %ARRIVED_OVERRIDES = (
			'CUBWORLD'=>14,
			'GKWORLD.int'=>35,		
			'GKWORLD.late'=>5,
			'CYPHERSTYLES.dom'=>10,
			'CYPHERSTYLES.int'=>30,		
			'DESIGNED2BSWEET.int'=>21,	## ticket 966532
			'DESIGNED2BSWEET.dom'=>14, 
			'BEAUTYSTORE.dom'=>10,
			'BEAUTYSTORE.int'=>21,		## ticket 1157660
			'TOTALFANSHOP.int'=>20,		## ticket 968081	
			'FROGPONDAQUATICS.dom'=>14, ## ticket 2035507 
			'FROGPONDAQUATICS.int'=>28, ## ticket 2035507
			);

		my $days = 0;
		if (defined $ARRIVED_OVERRIDES{$USERNAME}) {
			$days = ($ARRIVED_OVERRIDES{$USERNAME}>$days)?$ARRIVED_OVERRIDES{$USERNAME}:$days;
			}

		## sometimes we shouldn't send out an order arrived email (asking for feedback)
		##	when an order ships *really* late
		my $DAYS_TO_SHIP = int((time() - int($O2->in_get('our/order_ts')))/86400);

		if ((defined $ARRIVED_OVERRIDES{"$USERNAME.late"}) && ($ARRIVED_OVERRIDES{"$USERNAME.late"} < $DAYS_TO_SHIP)) {
			$days = -1;
			$O2->add_history(sprintf("ORDER.ARRIVED email was not queued because order took %d days to ship",$DAYS_TO_SHIP));
			}
		elsif (($O2->in_get('ship/countrycode') eq '') || (uc($O2->in_get('ship/countrycode')) eq 'US')) { 	
			## domestic, US
			$days = 7;
			if (defined $ARRIVED_OVERRIDES{"$USERNAME.dom"}) {
				$days = ($ARRIVED_OVERRIDES{"$USERNAME.dom"}>$days)?$ARRIVED_OVERRIDES{"$USERNAME.dom"}:$days;
				}
			}
		elsif ($O2->in_get('ship/countrycode') ne '') {	
			## all other international
			$days = 14;
			if (defined $ARRIVED_OVERRIDES{"$USERNAME.int"}) {
				$days = ($ARRIVED_OVERRIDES{"$USERNAME.int"}>$days)?$ARRIVED_OVERRIDES{"$USERNAME.int"}:$days;
				}
			if ($O2->in_get('ship/countrycode') eq 'AU' && $carriers{'USPS'} > 0) {
				## USPS to Australia takes weeks...
				## added for ticket 506458
				$days = 28;
				}
			}
		else {
			&ZOOVY::confess($O2->username(),"Unhandled shipping arrival time. Skipped ORDER.ARRIVE",justkidding=>1);
			$days = -1;
			}
		
		if ($days>0) {
			## queue an event $days days after today
			my ($udbh) = &DBINFO::db_user_connect($USERNAME);
			&ZOOVY::add_event($USERNAME,"ORDER.ARRIVE",
				'DISPATCH_GMT'=>time()+($days*86400),
				%{$YREF}
				);
			&DBINFO::db_user_close();	
			}
	

		## go through any marketplaces
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		if (scalar(@SHIP_NOTIFY_DSTS)) {
			my @SQL = ();
			my $ts = time();
			foreach my $trkref (@{$O2->tracking()}) {
				my $carrier = $trkref->{'carrier'};
				my $trackcode = $trkref->{'track'};
				my $shipped_gmt = int($trkref->{'created'});
				if ($shipped_gmt == 0) {
					$O2->add_history("received zero (invalid) 'created' (shipped) date for $carrier/$trackcode - setting to current time.",etype=>16+8);
					$shipped_gmt = time();
					}

				if ($shipped_gmt<($ts-86400*2)) {
					# &ZOOVY::confess($USERNAME,"Got unrealistic shipping date.\n\nSHIPPED:".&ZTOOLKIT::pretty_date($shipped_gmt)."\nNOW IS: "&ZTOOLKIT::pretty_date($ts)."\n".Dumper($o,$shipped_gmt,$trkref),justkidding=>1);
					my $msg = sprintf("mpo-late-ship-notify - shipping occurred: %s",&ZTOOLKIT::pretty_time_since($shipped_gmt,$ts));
					$O2->add_history($msg,etype=>8+16);
					}
				foreach my $dst (@SHIP_NOTIFY_DSTS) {
					my $pstmt = &DBINFO::insert($udbh,'USER_EVENTS_TRACKING',{
						'MID'=>$O2->mid(),
						'PRT'=>$O2->prt(),
						'DST'=>$dst,
						'OID'=>$O2->oid(),
						'CARRIER'=>$carrier,
						'TRACKING'=>$trackcode,
						'SHIPPED_GMT'=>$shipped_gmt,
						'DUE_GMT'=>$ts+86400
						},sql=>1);
					push @SQL, $pstmt;
					}
				}
			
			foreach my $pstmt (@SQL) {
				$udbh->do($pstmt);
				}
			}
		&DBINFO::db_user_close();

		## go through each payment and perform any notifications necessary.
		foreach my $payrec (@{$O2->payments()}) {
			if ($payrec->{'puuid'} ne '') {
				## this is a chained transaction and can be ignored.
				}
#			elsif ($payrec->{'tender'} eq 'GOOGLE') { 
#				require ZPAY::GOOGLE;
#				foreach my $trk (@{$O2->tracking()}) {
#					print Dumper($payrec,$trk);
#		         &ZPAY::GOOGLE::deliverOrder($O2, $payrec, $trk);
#					}
#				}
			}
		}


	if (not $success) {
		}
	elsif ($EVENT eq 'ORDER.PAID') {
		## check for ebay stuff and notify of payment

		## supply chain
		##
		## this is where we will create sub-orders for each supplier.
		##
		#my ($vcount,$vstuffref) = $O2->fetch_virtualstuff();
		#if ($vcount>0) {
		#	require SUPPLIER;
		#	&SUPPLIER::process_order($O2,'paid');
		#	}
		#$redis->select(1);
		#my $REDIS_PAID_KEY = sprintf("CHECKPOINT.EVENT.PAID.%s.%s.%s",$O2->username(),$O2->oid(),$EVENT);
		if ($O2->in_get('flow/paid_ts') < (time() - 86400*7)) {
			## don't run create events on orders older than 7 days
			}
		#elsif ($redis->exists($REDIS_PAID_KEY)) {
		#	}
		elsif ($O2->has_supplychain_items()) {
			INVENTORY2->new($O2->username(),"*PROCESS")->process_order($O2);
			## $O2->process_order('paid');
			# $redis->setex($REDIS_PAID_KEY,86400*7,time());
			}

		if ($ORDER_DST{'ESS'} || $ORDER_DST{'EBY'} || $ORDER_DST{'EBS'}) { ($success) = &notify_ebay($O2,$EVENT); }
		($success) += &flag_incomplete($O2,$EVENT);
		
		## REWARDS
		if ($ORDER_DST{'AMZ'} || $ORDER_DST{'FBA'}) {
			## no rewards points for amazon!
			}
		elsif (($success) && ($USERNAME eq 'cubworld') && ($O2->customerid()>0)) {
			## add reward points to customer, 1 point per 1 dollar spent (in subtotal)
			## points are rounded down, $33.95 => 33 pts
			my ($C) = CUSTOMER->new($USERNAME,'CREATE'=>0,'CID'=>$O2->customerid(),'INIT'=>0x1);
			$C->update_reward_balance( $O2->in_get('sum/items_total'), $O2->oid() );
			$O2->add_history("added ".int($O2->in_get('sum/items_total'))." reward points to customer");
			my $msgid = "CUSTOMER.REWARDS";

			## added 2011-11-02, ticket 474843... automatically create giftcard when balance exceeds "points_needed"
			## set by merchant
			## 300 points equal to $10 promotional giftcard, expires in 60 days
			my $issueamt = 10;
			my $expires_in_days = 60;
			my $card_type = 3; ## PROMO
			my $points_needed = 300;

			if ($C->{'INFO'}->{'REWARD_BALANCE'} >= $points_needed) {
				require GIFTCARD;
				my %OPTS = ();
				$OPTS{'CARDTYPE'} = $card_type;
				$OPTS{'EXPIRES_GMT'}= time()+(86400*$expires_in_days);
				$OPTS{'CID'} = $O2->customerid();

				GIFTCARD::createCard($USERNAME,$O2->prt(),$issueamt,%OPTS);
				$O2->add_history("added \$".$issueamt." giftcard, subtracted ".$points_needed." points from customer");
				$C->update_reward_balance("-".$points_needed,"\$".$issueamt." giftcard created");
				$msgid = "CUSTOMER.GIFTCARD.RECEIVED";
				}
				
			## send email to Customer notifying them of points added or GiftCard created	
			my ($BLAST) = BLAST->new($C->username,$C->prt());
			my ($rcpt) = $BLAST->recipient('CUSTOMER',$C);
			my ($msg) = $BLAST->msg($msgid);
			$BLAST->send($rcpt,$msg);
			#require SITE::EMAILS;
			#require SITE;
			#my ($SITE) = SITE->new($C->username,'PRT'=>$C->prt());
			#my ($SE) = SITE::EMAILS->new($C->username,'*SITE'=>$SITE); # 'PRT'=>$C->prt(),'GLOBALS'=>1);
			#$SE->sendmail($msgid,'CUSTOMER'=>$C);
			}

		## INFUSIONSOFT, added by patti 2011-02-24
		## - company consolidates order/contact info for "smart" email campaigning
		## commenting out until bug cause is found - 2011-04-08 11am
		if (($success) && ($USERNAME eq 'ledinsider') && ($O2->customerid()>0)) {
			require PLUGIN::INFUSIONSOFT;
			my $infusionsoft = PLUGIN::INFUSIONSOFT->new($USERNAME);
			
			if (defined $infusionsoft) {
				my ($ref) = eval { $infusionsoft->do_work($O2); };
				if (scalar(keys %{$ref})==0) { 
					print STDERR "INFUSIONSOFT SUCCESS!\n";
					}
      		else { print STDERR "INFUSIONSOFT ERROR\n";  }
				}
			}

		## Automatically populate insured value and signature requirements (based on order subtotal)
		if (($success) && $USERNAME eq 'zephyrsports') {
			my $order_subtotal = $O2->in_get('sum/items_total');

			## get either fedex or usps to set the right attribs below
			my $carrier = lc(ZSHIP::shipinfo($O2->in_get('our/shp_carrier'),'carrier'));
			#$carrier = ($carrier eq 'fdx'?'fedex':$carrier);
			if ($carrier eq 'ups' || $carrier eq 'usps') {
				## no need to change
				}
			else {
				## default to fedex
				$carrier = 'fedex';
				}
			
			my $signature = sprintf("our/%s_signature",$carrier);	 # our/fedex_signature
			my $insuredvalue = sprintf("our/%s_insuredvalue",$carrier); # our/fedex_insuredvalue

			## add "signature required" on orders over $250
			if ($order_subtotal <= 250) {
				$O2->in_set($signature,'NO_SIGNATURE_REQUIRED');
				}
			elsif ($order_subtotal > 250 && $order_subtotal <= 500) {
				$O2->in_set($signature,'INDIRECT');
				}
			## add "insured amount" on orders over $500
			elsif ($order_subtotal > 500) {
				$O2->in_set($signature,'DIRECT');
				$O2->in_set($insuredvalue,$order_subtotal);
				}
			}

		## COUPONS
		if ($ORDER_DST{'NEW'} || $ORDER_DST{'RSS'}) {
			## newsletters or rss
			my %options = ();
			## meta_src is NEWSLETTER/cpn=1/cpg=2 -- but is extensible.
			my $meta_src = $O2->in_get('cart/refer_src');
			foreach my $kv (split(/\//,$meta_src)) {
				my ($k,$v) = split(/=/,$kv);
				if (not defined $v) { $v = 1; }
				$options{uc($k)} = $v;
				}
						
			# print Dumper(\%options); 
			require CUSTOMER::RECIPIENT;
			if ((defined $options{'RSS'}) || (defined $options{'NEWSLETTER'})) {
				$O2->add_history(
							sprintf("updating meta_src:%s total:%.2f",$meta_src,$O2->in_get('sum/items_total')),
							etype=>32);
				$options{'SALES'} = $O2->in_get('sum/items_total');
				CUSTOMER::RECIPIENT::coupon_action($O2->username(),'PURCHASED',%options);
				}
			}
	
		print STDERR "SUCCESS: $success\n";
		}


	if (not $success) {
		}
	elsif ($EVENT eq 'ORDER.CANCEL') {
		## CANCEL ORDER
		$success++;
		if ($ORDER_DST{'BUY'}) {
			## BUY.COM
			}

		if ($ORDER_DST{'AMZ'}) {
			## AMAZON
			}

		if ($ORDER_DST{'HSN'}) {
			## HSN
			my $KEY = uc(sprintf("EVENTS.ORDER.CANCEL.HSN.%s", $O2->username() ));
			my ($redis) = &ZOOVY::getRedis($O2->username(),1);
			my $EXISTS = $redis->exists($KEY);
			$redis->lpush($KEY,$O2->oid()); 
			}

		if ($O2->in_get('is/origin_marketplace')==0) {
			## 'GTS': GOOGLE TRUSTED STORES
			my $KEY = uc(sprintf("EVENTS.ORDER.CANCEL.GTS.%s", $O2->username() ));
			my ($redis) = &ZOOVY::getRedis($O2->username(),1);
			my $EXISTS = $redis->exists($KEY);
			$redis->lpush($KEY,$O2->oid()); 
			}

		}

	if (not $success) {
		}
	elsif ($EVENT eq 'ORDER.ARRIVE') {
		## SEND FOLLOWUP EMAIL
		#require SITE::EMAILS;
		#my ($se) = SITE::EMAILS->new($USERNAME,'PRT'=>$o->prt(),'GLOBALS'=>1);
		## need to make emails PROFILE specific
		#my ($SREF) = SITE->new($USERNAME,'PROFILE'=>$O2->profile(),'PRT'=>$O2->prt());
		#my ($se) = SITE::EMAILS->new($USERNAME,'*SITE'=>$SREF,'GLOBALS'=>1);
		my $ORDER_ORIGIN = '';

		## attempt 2, getting correct marketplace dstcode from order
		if ($ORDER_ORIGIN ne '') {
			}
		elsif ($O2->in_get('our/mkts') ne '') {
			## mkts set for marketplace orders
			## no need to loop thru all (even though there should only be one for marketplace orders??)
			foreach my $id (@{&ZOOVY::bitstr_bits($O2->in_get('our/mkts'))}) {
				my $sref = &ZOOVY::fetch_integration('id'=>$id);
				# print Dumper($sref);
				$ORDER_ORIGIN = $sref->{'dst'};
				}
			}
		print Dumper($ORDER_ORIGIN);

		my $MSGID = undef;
		if ($ORDER_ORIGIN eq 'BUY') {
			## against Buy.com policy to send out emails to their customers
			}
		elsif ($ORDER_ORIGIN eq 'EGG') {
			## against NewEgg policy to send out emails to their customers (no email sent with order)
			}
		elsif ($ORDER_ORIGIN eq 'HSN') {
			## against HSN policy to send out emails to their customers (no email sent with order)
			}
		elsif ($ORDER_ORIGIN eq 'SRS') {
			## against Sears policy to send out emails to their customers (no email sent with order)
			}
		elsif ($ORDER_ORIGIN eq 'AMZ') {
			## Amazon will freak if we send any external links,
			##      dont let merchant make that mistake (or at least don't let them send the wrong message)
			$MSGID = 'ORDER.ARRIVED.AMZ';	
			}
		elsif ($O2->customerid() <= 0) {
			## no customer acct created?, don't send email... customer won't be able to add feedback
			## moved from the top of this group of if/elsif statement as a CID shouldn't be a requirement for markeplace orders 
			}
		elsif ($ORDER_ORIGIN ne '') {
			$MSGID = sprintf('ORDER.ARRIVED.%s',$ORDER_ORIGIN);
			}
		else {
			## add WEB for non-marketplace orders
			$MSGID = 'ORDER.ARRIVED.WEB';
			}

		##
		## SANITY: at this point if $MSGID is set we're sending an email
		##
		if ((not defined $MSGID) && ($ORDER_ORIGIN eq 'BUY')) {
			## this is a totally valid case, where Buy.com doesnt want us to send emails
			## no sense throwing a useless warning.
			}		
		elsif ((not defined $MSGID) && ($ORDER_ORIGIN eq 'AMZ')) {
			## this is a totally valid case, where they don't have a ORDER.ARRIVED.AMZ message
			## no sense throwing a useless warning.
			}		
		elsif (not defined $MSGID) {
			## none the ORDER.ARRIVED* emails are defined, don't send email
			warn "MSGID was not set, not sending ORDER.ARRIVED email\n";
			}
		else {
			my ($BLAST) = BLAST->new($USERNAME,$O2->prt());
			my ($rcpt) = $BLAST->recipient('CUSTOMER',$O2->customerid());
			my ($msg) = $BLAST->msg($MSGID);
			$BLAST->send($rcpt,$msg);
			# $se->sendmail($MSGID,'*SITE'=>$SREF,'*CART2'=>$O2,'CID'=>$O2->customerid());
			}
		# $se = undef;
		}

	
	
	
	
	
	if (uc($EVENT) eq 'ORDER.SAVE') {
		## we never create an ORDER.SAVE for a SAVE.
		$success = 1;
		}
	elsif ((defined $success) && ($success>0)) {
		print STDERR "SAVING!\n";
		$O2->add_history("finished event: $EVENT",etype=>4,luser=>"*$EVENT");
		$O2->order_save('from_event'=>"$EVENT");
		}
	elsif ((defined $success) && ($success==0)) {
		$O2->add_history("failed event: $EVENT (success:$success)",etype=>2+8);
		$O2->order_save('from_event'=>"$EVENT");
		warn("success=$success [$EVENT]");
		}
	else {
		warn("success undef");
		}

	# eval { $O2->elastic_index(); };

	##
	##
	##
	if (not $success) { return(1); }
	return(undef); 
	}


##
##
##
sub e_PAYMENT {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;

	require ZOOVY;
	require TODO;
	
	#&TODO::easylog($USERNAME,
	#	class=>'INFO',
	#	group=>'ORDER',
	#	title=>sprintf("order %s had payment updated",$YREF->{'ORDERID'}),
	#	detail=>sprintf("SRC: %s", $YREF->{'SRC'}),
	#	link=>sprintf("order:%s",$YREF->{'ORDERID'}),
	#	);
	
	return(&e_NOTIFY(@_));
	## always return - no error
	## return(undef);
	}



##
##
##
sub e_CUSTOMER {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;

	## no errors
	return(undef);
	}

##
## 
##
sub e_TICKET {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;

	my $ERROR = undef;

	my ($TID) = $YREF->{'TICKETID'};
	require CUSTOMER::TICKET;
	# require SITE::EMAILS;
	print "TID: $TID\n";
	my ($CT) = CUSTOMER::TICKET->new($USERNAME,"#$TID",'PRT'=>$PRT);
	my ($BLAST) = BLAST->new($USERNAME,$PRT);
		
	## STEP1: send an email
	#require SITE;
	#my ($SITE) = SITE->new($USERNAME,'PRT'=>$PRT);
	#my ($SE) = SITE::EMAILS->new($USERNAME,'*SITE'=>$SITE);	
	#my ($C,$CID) = undef;
	my ($rcpt) = undef;
	if (defined $CT) {
		my ($C) = $CT->link_customer();
		if ((defined $C) && (ref($C) eq 'CUSTOMER')) {
			($rcpt) = $BLAST->recipient('CUSTOMER',$C);
			}
		}	

	if (not defined $CT) {
		$ERROR = "Could not lookup ticket $TID";
		}
	elsif (not $rcpt) {
		}
	else {
		## EVENT: TICKET.CREATE, TICKET.CLOSE, TICKET.UPDATE, TICKET.REPLY
		my ($msg) = $BLAST->msg($EVENT,{'ORDER'=>$CT->link_order,'TICKET'=>$CT});
		$BLAST->send($rcpt,$msg);
		}
	#elsif ($EVENT eq 'TICKET.CREATE') {
	#	($ERROR) = $SE->sendmail('TICKET.CREATED','TO'=>$RECIPIENT,'PRT'=>$PRT,'*CT'=>$CT,'ORDER'=>$CT->link_order(),'CUSTOMER'=>$C);
	#	}
	#elsif ($EVENT eq 'TICKET.CLOSE') {
	#	($ERROR) = $SE->sendmail('TICKET.CLOSED','TO'=>$RECIPIENT,'PRT'=>$PRT,'*CT'=>$CT,'ORDER'=>$CT->link_order(),'CUSTOMER'=>$C);
	#	}
	#elsif ($EVENT eq 'TICKET.UPDATE') {
	#	($ERROR) = $SE->sendmail('TICKET.UPDATED','TO'=>$RECIPIENT,'PRT'=>$PRT,'*CT'=>$CT,'ORDER'=>$CT->link_order(),'CUSTOMER'=>$C);
	#	}
	#elsif ($EVENT eq 'TICKET.REPLY') {
	#	($ERROR) = $SE->sendmail('TICKET.REPLY','TO'=>$RECIPIENT,'PRT'=>$PRT,'*CT'=>$CT,'ORDER'=>$CT->link_order(),'CUSTOMER'=>$C);
	#	}
	#if ($ERROR == 0) { 
	#	$ERROR = undef; 
	#	}
	#else {
	#	$ERROR = sprintf("[%d] %s",$ERROR,$SITE::EMAIL::ERRORS{$ERROR});
	#	}
	

	return($ERROR);
	}



##
## THIS EVENT IS FIRED WHEN A CHANNEL REVOKE FOR A PRODUCT IS REQUESTED
##
sub e_INV_OUTOFSTOCK {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;

	## lets check stock right now
	my $SKU = $YREF->{'PID'};
	my $PID = $YREF->{'PID'};
	($PID) = &PRODUCT::stid_to_pid($PID); # 

	my ($INVSUMMARY) = INVENTORY2->new($USERNAME,"*EVENTS")->summary( '@PIDS'=>[ $YREF->{'PID'} ], 'PIDS_ONLY'=>1);
	my ($AVAILABLE) = $INVSUMMARY->{ $YREF->{'PID'} }->{'AVAILABLE'};
	if (not defined $AVAILABLE) { return(); }
	if ($AVAILABLE>0) { return(); }

	require LISTING::EVENT;
	require EBAY2;
	
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($qtPID) = $udbh->quote($SKU);
	my $pstmt = "/* INV_REVOKE EVENT */ select ID,EBAY_ID,PRT from EBAY_LISTINGS where PRODUCT=$qtPID and MID=$MID and EBAY_ID>0 and IS_ENDED=0";
	print "$pstmt\n";
	my ($sth) = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($UUID,$EBAY_ID,$PRT) = $sth->fetchrow() ) {
		print "INV_REVOKE EVENT REMOVED EBAY_ID: $EBAY_ID PRT:$PRT\n";
		my ($le) = LISTING::EVENT->new(
			'USERNAME'=>$USERNAME,'PRT'=>$PRT,
			'SKU'=>$SKU,
			'VERB'=>'END',
			'TARGET'=>'EBAY',
			'TARGET_LISTINGID'=>$EBAY_ID,
			'TARGET_UUID'=>$UUID,
			'REQUEST_APP'=>'INV-EV',
			);
		}
	$sth->finish();
	&DBINFO::db_user_close();

	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
	if ($gref->{'inv_rexceed_action'}>0) {
		## RESERVE INVENTORY exceeded (actual-inventory<0) 
		$LM->pooshmsg("INV.REMOVE|+REQUEST REMOVE SKU:$SKU QTY:$AVAILABLE");

		open F, ">>".&ZOOVY::resolve_userpath($USERNAME)."/inv-remove.log";
		print F time()."\t$USERNAME\t$PID\n";
		close F;
	
		#&logit($USERNAME,$PID,"Removing $PID from categories");
		my @PRTS = @{&ZWEBSITE::list_partitions($USERNAME,output=>'prtonly',has_navcats=>1)};
		foreach my $PRT (@PRTS) {
			my ($NC) = &load_cached_resource($CACHEREF,'NAVCAT',$USERNAME,$PRT);
			my ($catref) = $NC->paths_by_product($PID,'fast'=>1);
			if (scalar(@{$catref})>0) {
				print STDERR 'NAVCAT(S): '.Dumper($catref);	
				if ($NC->nuke_product($PID,memory=>1)) {
					&queue_save($CACHEREF,'NAVCAT',$USERNAME,$PRT);
					}
				}

			## if (not defined $gref->{'inv_notify'}) { $gref->{'inv_notify'} = 0; }

			if (not defined $catref) {
				warn "catref should *never* be undef\n";
				}
			elsif (scalar(@{$catref})==0) {
				## did not exist in any categories!
				}
			#elsif (not $gref->{'inv_notify'})  {		
			#	## no notifications
			#	}
			else {
				my ($P) = PRODUCT->new($USERNAME,$PID);
				my $prodname = (defined $P)?$P->fetch('zoovy:prod_name'):"Product '$PID' no longer exists";
				print "REMOVED/NOTIFYING $prodname\n";
				my $detail = '';
				foreach my $safe (@{$catref}) {
					my $pretty = $NC->pretty_path($safe);
					warn($USERNAME,$PID,"ACTION: Removed [$PID] $prodname from CATEGORY: $pretty ($safe) prt:$PRT");
					if ($safe eq '.') { $pretty = 'Homepage'; }

					&ZOOVY::add_notify($USERNAME,"INV.NAVCAT.HIDE",
						'PRT'=>$PRT,'SAFE'=>$safe, 'PID'=>$PID,SKU=>$SKU,is=>$AVAILABLE,
						'link'=>"product://$PID",
						'title'=>"[$PID] $prodname from CATEGORY: $pretty ($safe) prt:$PRT",
						);
					}
				}
			undef $NC;
			}
		}

	return(undef);
	}



#
## THIS EVENT FIRES WHEN A PRODUCT COMES BACK INTO STOCK.
##
sub e_INV_GOTINSTOCK {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;
	
	## make sure we are focused on a product, not a STID.

	# print Dumper($YREF);

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $error = undef;

	my $STID = $YREF->{'PID'};
	if ($STID eq '') { $STID = $YREF->{'SKU'}; }

	my ($PID) = &PRODUCT::stid_to_pid($STID);
	my ($invref) = INVENTORY2->new($USERNAME,'*EVENTS')->fetch_qty('@PIDS'=>[$PID]);
	my $total = 0;
	foreach my $sku (keys %{$invref}) {
		# make sure negative qty's don't make total be less than zero.
		if ($invref->{$sku}>0) { $total += $invref->{$sku}; }
		}	

	my ($P) = PRODUCT->new($USERNAME,$PID,'create'=>0);
	if (not defined $P) { $error = "PRODUCT $PID not in database"; }

	if ($P->grp_type() eq 'PARENT') {
		## we add parents back whenever a child gets inventory (for bob)
		}
	elsif ($total<=0) {
		warn "Don't really have $STID ($invref->{$STID})\n";
		return(undef);
		}

	#my ($prodref) = &ZOOVY::fetchproduct_as_hashref($USERNAME,$PID);
	#if ($prodref->{'ebay:ts'}>0) {
	#	## when an item which has options comes back into stock, we need to fire off an update listing.
	#	}
	
	my ($gcref) = &ZWEBSITE::fetch_globalref($USERNAME);
	# if (not defined $gcref->{'inv_notify'}) { $gcref->{'inv_notify'} = 0; }
	## inventory is back in stock
	#mysql> desc NAVCAT_MEMORY;
	#+-------------+------------------+------+-----+---------+----------------+
	#| Field			 | Type						 | Null | Key | Default | Extra					|
	#+-------------+------------------+------+-----+---------+----------------+
	#| ID					| int(10) unsigned | NO	 | PRI | NULL		| auto_increment |
	#| USERNAME		| varchar(20)			| YES	|		 | NULL		|								|
	#| MID				 | int(10) unsigned | YES	|		 | 0			 |								|
	#| CREATED_GMT | int(10) unsigned | NO	 |		 | 0			 |								|
	#| PID				 | varchar(20)			| NO	 | MUL | NULL		|								|
	#| SAFENAME		| varchar(128)		 | NO	 |		 | NULL		|								|
	#+-------------+------------------+------+-----+---------+----------------+
	#6 rows in set (0.00 sec)		

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my @PRTS = ();
	my $pstmt = "select PRT from NAVCAT_MEMORY where MID=$MID /* $USERNAME */ and PID=".$udbh->quote($PID)." group by PRT";
	my $sth = $udbh->prepare($pstmt);	
	$sth->execute();
	while ( my ($PRT) = $sth->fetchrow() ) {
		print "PRT: $PRT\n";
		push @PRTS, $PRT;
		}
	$sth->finish();

	foreach my $PRT (@PRTS) {
		my $changes = 0;
		my $pstmt = "select SAFENAME from NAVCAT_MEMORY where MID=$MID /* $USERNAME */ and PID=".$udbh->quote($PID)." and PRT=".int($PRT);
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		my $NC = undef;
		if ($sth->rows()>0) { $NC = load_cached_resource($CACHEREF,'NAVCAT',$USERNAME,$PRT); }
		my $detail = '';
		my @PATHS = ();
		while ( my ($SAFE) = $sth->fetchrow() ) {
			push @PATHS, $SAFE;
			print "$USERNAME added $PID to $SAFE on prt#$PRT\n";
			if ($NC->exists($SAFE)) {
				## hurrah, category exists!
				$NC->set($SAFE,insert_product=>$PID); $changes++;
				$detail .= "Category: $SAFE\n";
				}
			else {
				warn "Category: $SAFE no longer exists!";
				&ZOOVY::add_notify($USERNAME,"INV.NAVCAT.FAIL",
					'PRT'=>$PRT,'SAFE'=>$SAFE, 'PID'=>$PID,
					'link'=>"product://$PID",
					'title'=>"$PID could not be readded to prt#$PRT (failed - see detail for category)",
					'detail'=>"Product $PID could not be re-added to category $SAFE because category no longer exists on prt#$PRT!"
					);
				$detail .= "Failed: $SAFE\n";
				}
			}
		$sth->finish();
		if ((defined $NC) && ($changes)) { 
			&queue_save($CACHEREF,'NAVCAT',$USERNAME,$PRT);
			# $NC->save(); 
			my $pstmt = "delete from NAVCAT_MEMORY where MID=$MID /* $USERNAME */ and PID=".$udbh->quote($PID)." and PRT=".int($PRT);
			$udbh->do($pstmt);
			}

		#if ($gcref->{'inv_notify'} & 2) { 
			&ZOOVY::add_notify($USERNAME,"INV.NAVCAT.SHOW",
				'PRT'=>$PRT,'SAFE'=>join("\n",@PATHS), 'PID'=>$PID,
				'link'=>"product://$PID",
				'title'=>"$PID added to category prt#$PRT",
				'detail'=>$detail,
				);
			&notify($USERNAME,$PID,"$PID back on website prt#$PRT",$detail);
		#	}

		}
	 
	## notify products 
	$pstmt = "select ID,CID,EMAIL,PROFILE,VARS from USER_EVENTS_FUTURE where PROCESSED_GMT=0 and MID=$MID /* $USERNAME */ and UUID=".$udbh->quote($PID);
	$sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($ID,$CID,$EMAIL,$PROFILE,$VARS) = $sth->fetchrow() ) {
		my $varsref = &ZTOOLKIT::parseparams($VARS);

		my ($METHOD) = $varsref->{'m'};
		if ($METHOD eq '') { $METHOD = $varsref->{'_METHOD'}; }
		
		print "CID: $CID EMAIL: $EMAIL METHOD: $METHOD\n";
		# print Dumper($varsref);
		
		if ($METHOD eq 'addNotify') {
			$pstmt = "update USER_EVENTS_FUTURE set PROCESSED_GMT=".time()." where MID=$MID and ID=".$ID;
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			my ($C) = CUSTOMER->new($USERNAME,CID=>$CID,INIT=>0xFF);
			
			## pinstock
			#require SITE;
			#my ($SITE) = SITE->new($USERNAME,NS=>$PROFILE,PRT=>$C->prt());
			#require SITE::EMAILS;
			#my ($se) = SITE::EMAILS->new($USERNAME,'*SITE'=>$SITE);
			#$se->send($varsref->{'msgid'},CUSTOMER=>$C,PRODUCT=>$varsref->{'pid'},TO=>$varsref->{'email'},VARS=>$varsref);
			#$se = undef;
			my ($BLAST) = BLAST->new($USERNAME,$C->prt());
			my ($rcpt) = $BLAST->recipient('CUSTOMER',$C);
			my ($msg) = $BLAST->msg($varsref->{'msgid'},{'%VARS'=>$varsref});
			$BLAST->send($rcpt,$msg);
			}
		## END ADDNOTIFY
		}
	$sth->finish();			
	&DBINFO::db_user_close();
	
	if (($error eq '') || ($error==0)) { 
		$error = undef; 
		}
	else {
		print STDERR "ERROR: $error\n";
		}
	return($error);
	}
	



##
## THIS EVENT FIRES WHEN A SKU'S INVENTORY CHANGES.
##
sub e_INV_CHANGED {
	my ($EVENT,$USERNAME,$PRT,$YREF,$LM,$redis,$CACHEREF) = @_;
	
	## make sure we are focused on a product, not a STID.

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $error = undef;
	my $warn = undef;

	my $SKU = $YREF->{'SKU'};
	my ($PID) = &PRODUCT::stid_to_pid($SKU);
	my ($invref) = INVENTORY2->new($USERNAME)->fetch_qty('@PIDS'=>[$PID]);
	my $total = 0;
	foreach my $sku (keys %{$invref}) {
		# make sure negative qty's don't make total be less than zero.
		if ($invref->{$sku}>0) { $total += $invref->{$sku}; }
		}	

	my ($gcref) = &ZWEBSITE::fetch_globalref($USERNAME);
	# if (not defined $gcref->{'inv_notify'}) { $gcref->{'inv_notify'} = 0; }

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($P) = PRODUCT->new($USERNAME,$PID,'create'=>0);
	if (not defined $P) { $error = "PRODUCT $PID not in database"; }

	if ($error) {
		}
	elsif ($P->fetch('ebay:ts')>0) {
		## has ebay syndication enabled for the product, lets get a list of fixed price syndicated listings, and update the inventory
		print "EBAY:TS ".$P->fetch('ebay:ts')."\n";
		require EBAY2;
		my ($ebayerr) = EBAY2::sync_inventory($USERNAME,$SKU,$YREF->{'is'},$YREF->{'#attempts'});
		$YREF->{'ebay'} = $ebayerr;
		}
	else {
		$YREF->{'ebay'} = 0;
		}

	if ($error) {
		}
	elsif ($P->fetch('amz:ts')>0) {
		## inform amazon the products inventory has changed.
		require AMAZON3;
		&AMAZON3::item_set_status({USERNAME=>$USERNAME,MID=>$MID},$SKU,['+inventory.todo']);
		if ($YREF->{'is'}<=3) {
			&AMAZON3::sync_inventory($USERNAME,$SKU,$YREF->{'is'},$YREF->{'#attempts'});
			}
		$YREF->{'amz'}++;
		}
	else {
		$YREF->{'amz'} = 0;
		}

	## updates grp parent with "consolidated/correct" inv (from $PID sibs)
	## change only occurs when: grp_parent defined, grp_type eq CHILD
	## otherwise, nothing happens
	## added 2011-12-15, custom project ticket 479297

	if ($error) {
		}
	else {
		my ($INV2) = INVENTORY2->new($USERNAME,'*EVENTS');
		$INV2->summarize($P);
		}

	#if ($error) {
	#	}
	#elsif ($P->fetch('zoovy:grp_type') ne 'CHILD') {
	#	## we are only VERIFYING GRP CHILDREN!!
	#	return undef;
	#	}
	#elsif ($P->fetch('zoovy:grp_parent') eq '') {
	#	## can't really update parent inv without parent sku...
	#	return undef;
	#	}
	#else {
	#	## find all sibs and calculate "consolidated/correct" parent inv
	#	my $parent_sku = $P->fetch('zoovy:grp_parent');
	#	my $parentP = PRODUCT->new($USERNAME,$parent_sku,'create'=>0);
	#	if (not defined $parentP) {
	#		$error = "parent:$parent_sku does not exist";
	#		}
	#	else {
	#		my @sibs = $parentP->grp_children();
	#		# split(/,/,$parent_prodref->{'zoovy:grp_children'});
	#		## calulate total sibling qty
	#		my $parent_qty = 0;
	#		## my ($onhandref) = INVENTORY::fetch_incrementals($USERNAME,\@sibs);		## group parent/child handling.
	#		my ($onhandref) = $INV2->fetch_qty('@PIDS'=>\@sibs);
	#		foreach my $sku (keys %{$onhandref}) {
	#			$parent_qty += $onhandref->{$sku};
	#			}
	#		print STDERR "inv_verify: Updating $parent_sku inv: ".int($parent_qty)."\n";
	#		&INVENTORY::add_incremental($USERNAME,$parent_sku,'U',int($parent_qty));
	#		}
	#	}

	&DBINFO::db_user_close();
	
	print STDERR "ERR: $error\n";

	if (($error eq '') || ($error == 0)) { $error = undef; }
	return($error);
	}
	



##
##
##
#sub notify {
#	my ($USERNAME,$PID,$TITLE,$DETAIL,$CACHEREF) = @_;
#	
#	#my ($t) = TODO->new($USERNAME,writeonly=>1);
#	## my ($PID,$TITLE,$DETAIL) = split(/\|/,$msg);
#	#$t->add( 
#	#	title=>$TITLE,
#	#	detail=>$DETAIL,
#	#	class=>'INFO',
#	#	link=>"PRODUCT:$PID",
#	#	);
#
#	return(undef);
#	}


##
##
##
sub flag_incomplete {
	my ($O2,$EVENT) = @_;

	my ($stuff2) = $O2->stuff2();	
	my $USERNAME = $O2->username();
	my $order_id = $O2->oid();
	my $status = $O2->payment_status();
	my $changed = 0;
	
	foreach my $item (@{$stuff2->items()}) {
		my $stid = $item->{'stid'};			
		my $claim = $item->{'claim'};

		if (int($claim)>0) {}
		elsif ($stid =~ m/^([\d]+)\*/) { $claim = $1; }	## legacy
		next if ($claim eq '');

		require EXTERNAL;
		&EXTERNAL::save($USERNAME,$claim,{ 'ZOOVY_ORDERID' => $order_id, });
		my $inc = &EXTERNAL::fetchexternal_full($USERNAME, $claim);
		if ($inc->{'ZOOVY_ORDERID'} ne $order_id) {
			$O2->add_history("Internal Coherency Issue: order id is not set to $order_id after ORDERsaveexternal_full",etype=>8,luser=>"*$EVENT");
			}

		## Don't change the stage of an external item if it was already flagged in the past
		if (not defined $inc->{'STAGE'}) { $inc->{'STAGE'} = ''; }
		next unless ($inc->{'STAGE'} =~ m/^[AIVHWT]+$/); 

		## feedback is usually only left for 000-series statuses
		## auto_feedback means leave feedback regardless of payment status
		my $stage = 'C';
		if (substr($status,0,1) eq '0') {
			$stage = 'P'; 
			}
		else {
			$stage = 'H';
			}
		
		print "ORDER: $order_id claim $claim to STATUS=[$stage]\n";
		my ($success) = &EXTERNAL::update_stage($USERNAME, $claim, $stage, undef, $order_id);
		$O2->add_history("Flagged incomplete item $claim to STATUS=[$stage] $success",etype=>32,luser=>"*$EVENT");
		$changed++;
		}

	return(1);
	}	


##
## notify amazon order processor that we have tracking information.
##
sub notify_amazon {
	my ($O2,$EVENT) = @_;

	$EVENT = uc($EVENT);
	my ($success) = 1;

	my $pstmt = undef;
	if ($EVENT eq 'ORDER.CREATE') {
		## no need to notify on a create because it will be put into AMAZON_ORDERS on it's own!
		}

	if ($EVENT eq 'ORDER.SHIP') {
#alter table AMAZON_ORDERS add NEWORDER_ACK_PROCESSED_GMT integer unsigned default 0 not null,
#  add NEWORDER_ACK_DOCID bigint unsigned default 0 not null,
#  add FULFILLMENT_ACK_REQUESTED_GMT integer unsigned default 0 not null,
#  add FULFILLMENT_ACK_PROCESSED_GMT integer unsigned  default 0 not null,
#  add FULFILLMENT_ACK_DOCID bigint unsigned  default 0 not null,
#  add index(NEWORDER_ACK_PROCESSED_GMT),
#  add index(FULFILLMENT_ACK_PROCESSED_GMT,FULFILLMENT_ACK_REQUESTED_GMT);
		$success = 0;
		my $udbh = &DBINFO::db_user_connect($O2->username());
		my ($MID) = &ZOOVY::resolve_mid($O2->username());
		## HAS_TRACKING of 1 means "need to send tracking"
		## HAS_TRACKING of 2 means "sent tracking"
		my ($PRT) = $O2->prt();
		my $pstmt = "update AMAZON_ORDERS set FULFILLMENT_ACK_REQUESTED_GMT=unix_timestamp(now()),HAS_TRACKING=1 where MID=$MID and PRT=$PRT and OUR_ORDERID=".$udbh->quote($O2->oid());
		print STDERR "$pstmt\n";
		if ($udbh->do($pstmt)) { $success++; }
		$O2->add_history("requested tracking for this order be updated in the next amazon upload (success:$success)",etype=>2+32);
		&DBINFO::db_user_close();
		}

	return($success);
	}



##
##
##
sub notify_ebay {
	my ($O2,$EVENT) = @_;

	print "NOTIFY!\n"; 
	my $USERNAME = $O2->username();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	
	my $changed = 0;
	my $udbh = &DBINFO::db_user_connect($USERNAME);

	foreach my $item (@{$O2->stuff2()->items()}) {
		my $stid = $item->{'stid'};
		print "STID: $stid\n";
		print "STID MKT: $item->{'mkt'}\n";
		next unless ($item->{'mkt'} =~ /^(EBAY|EBF|EBA)$/);
		# print Dumper($item);

		my $CLAIM = $item->{'claim'};
		if ((not defined $item->{'claim'}) || ($item->{'claim'}==0)) {
			## dammit, order manager discards this attribute
			(my $pid,$CLAIM) = &PRODUCT::stid_to_pid($stid);
			}
		print "STID CLAIM: $CLAIM\n";
		next if ($CLAIM==0);
		
		my $pstmt = "select EBAY_ID,SITE_ID,TRANSACTION,EIAS,EBAY_USER from EBAY_WINNERS where MID=$MID /* $USERNAME */ and CLAIM=".int($CLAIM);
		print $pstmt."\n";
		my $sthx = $udbh->prepare($pstmt);
		$sthx->execute();
		my ($EBAY_ID,$SITE_ID,$TRANSACTION,$EIAS,$EBAY_USER) = $sthx->fetchrow();
		$sthx->finish();
		
		print "EBAY: $EBAY_ID,$TRANSACTION,$EIAS\n";
		require EBAY2;

		my $status = undef;
		my ($eb2) = EBAY2->new($USERNAME,EIAS=>"$EIAS");
		if ((not defined $status) && (not defined $eb2)) {
			$status = "ERR:no_ebay_token_matched";
			}

		## calling CompleteSale with <Paid>true</Paid> and <Shipped>true</Shipped>
		## so item will display correctly on 'My eBay' (in 'Paid and Shipped' pool)
		# print "Calling CompleteSale, item:$EBAY_ID, transaction:$TRANSACTION\n";
		
		my $shipped = ($O2->in_get('flow/shipped_ts')>0)?1:0;
		if (not $shipped) {
			 if (scalar(@{$O2->tracking()})>0) { $shipped++; }
			 }

		my $r = undef;
		my %hash = ();
		my $pkgs = 0;
		if (not defined $status) {
			$hash{'#Site'} = $SITE_ID;
			$hash{'ItemID'} = $EBAY_ID;
			$hash{'TransactionID'} = $TRANSACTION;
			$hash{'Paid'} = ($O2->in_get('flow/paid_ts')>0)?'true':'false';
			$hash{'Shipped'} = ($shipped)?'true':'false';

			# developer.ebay.com/devzone/xml/docs/Reference/eBay/CompleteSale.html
			# global shipping program: www.ecommercebytes.com/cab/abn/y12/m08/i23/s02
			foreach my $trk (@{$O2->tracking()}) {
				$pkgs++;
				my $ebaycode = $trk->{'carrier'};
				if (my $ref = &ZSHIP::shipinfo($trk->{'carrier'})) {
					if ($ref->{'ebay'}) {
						$ebaycode = $ref->{'carrier'};
						}
					elsif ($ref->{'carrier'}) {
						$ebaycode = $ref->{'carrier'};
						}
					}
				$hash{'Shipment.ShippedTime'} = $eb2->ebtime($trk->{'created_ts'});
				$hash{"Shipment.ShipmentTrackingDetails#$pkgs.ShipmentTrackingNumber"} = $trk->{'track'};
## ShippingCarrierUsed:
## 	Required if ShipmentTrackingNumber is supplied. Name of the shipping carrier used to ship the item. 
##   Although this value can be any value, since it is not checked by eBay, commonly used shipping carriers 
## 	can be found by calling GeteBayDetails and examining the returned ShippingCarrierCodeTypes.
## 	For those using UPS Mail Innovations, supply the value UPS-MI for UPS Mail Innnovations. 
## 	Buyers will subsequently be sent to the UPS Mail Innovations website for tracking.
##		For those using FedEx SmartPost in a CompleteSale callsupply the value FedEx. 
## 	Buyers will subsequently be sent to the appropriate web site for tracking status. 
##	(The buyer is sent to the UPS Mail Innovations website if UPS-MI is specified, 
## or to the FedEx website if FedEx is specified.) Returned only if set. Returned for Half.com as well.
				$hash{"Shipment.ShipmentTrackingDetails#$pkgs.ShippingCarrierUsed"} = $ebaycode;
				}


			print Dumper(\%hash);
			($r) = $eb2->api('CompleteSale',\%hash,'xml'=>3,debug=>0);
			}

		if (defined $status) {
			}
		elsif ($r->{'.'}->{'Ack'}->[0] eq 'Success') { 
			$status = $r->{'.'}->{'Ack'}->[0];
			}		
		elsif ((defined $r->{'.ERRORS'}) && (defined $r->{'.ERRORS'}->[0])) { 
			$status = "ERR:".$r->{'.ERRORS'}->[0]->{'ShortMessage'}; 
			}
		else {
			$status = "ERR:status unrecognized";
			}
		# print Dumper(\%hash);
		# print Dumper($r);
		print "CompleteSale ack: $status\n";
		$O2->add_history("notified ebay $EBAY_ID; paid=$hash{'Paid'} ship=$hash{'Shipped'} pkgs=$pkgs ($status)",etype=>32,luser=>"*$EVENT");

		## revise the checkout status:
		# http://developer.ebay.com/DevZone/XML/docs/Reference/eBay/ReviseCheckoutStatus.html
		#if (($USERNAME eq 'toynk') && (1)) {
		#	$hash{'#Site'} = $SITE_ID;
		#	$hash{'BuyerID'} = $EBAY_USER;
		#	$hash{'AmountPaid*'} = &XMLTOOLS::currency('AmountPaid',0,'USD');
		#	$hash{'CheckoutStatus'} = 'Complete';
		#	$hash{'ItemID'} =
		#	$hash{'TransactionID'} = 
		#	$hash{'ShippingService'} = 
		#	# $hash{'ShippingInsuranceCost*'} = 
		#	}
#		$pkgs = 0;
		if ($pkgs) {	
			my $ORDERID = URI::Escape::XS::uri_escape($O2->oid());
			my $CARTID = URI::Escape::XS::uri_escape($O2->in_get('cart/cartid'));
	
			my ($BLAST) = BLAST->new($USERNAME,$O2->prt());
			my ($rcpt) = $BLAST->recipient('EBAY',$eb2, {'%call'=>{ '#Site'=>$SITE_ID,'ItemID'=>$EBAY_ID,'MemberMessage.QuestionType'=>'Shipping','MemberMessage.RecipientID'=>$EBAY_USER}});
			my ($msg) = $BLAST->msg('ORDER.SHIPPED.EBAY',{'%ORDER'=>$O2->TO_JSON()});
			$BLAST->send($rcpt,$msg);
			$O2->add_history("Notified client of shipment via myEBay",etype=>32,luser=>"*$EVENT");

			#my $SREF = SITE->new($USERNAME,'PRT'=>$O2->prt());
			#require SITE::EMAILS;
			#my ($se) = SITE::EMAILS->new($USERNAME,'*SITE'=>$SREF,'GLOBALS'=>1);
			#my ($ERR, $result) = $se->createMsg('ORDER.SHIPPED.EBAY','*CART2'=>$O2,'*SITE'=>$SREF,'LAYOUT'=>0);
			#($hash{'MemberMessage.Subject'},$hash{'MemberMessage.Body'}) = ($result->{'SUBJECT'},$result->{'BODY'});	
			}
		
		## next lets leave feedback.		
		$changed++;
		}

	&DBINFO::db_user_close();
	return($changed);
	}


#	elsif ($SITE::merchant_id eq 'ibc') {
#		## I don't even have a name for this feature yet.
#		require LWP::UserAgent;
#		my ($xml) = $o->as_xml(118);
#		my %vars = ( 'Method'=>'Order', 'Contents'=>$xml );
#		my $agent = new LWP::UserAgent;
#		$agent->timeout(15);
#		my ($r) = $agent->post('http://www.razormouth.com/receive.cgi',\%vars);
#		if ($r->is_success()) {
#			$o->run_macro( $r->content() );
#			}
#		else {
#			$o->add_history("could not access api: ".$r->status_line());
#			}
##		## reimport the order into SITE::CART
#		$CART->in_set('data.remote_id',$o->get_attrib('remote_id'));
#		$CART->in_set('data.remote_user',$o->get_attrib('remote_user'));
#		$CART->in_set('data.remote_pass',$o->get_attrib('remote_pass'));
#		$CART->in_set('data.remote_url',$o->get_attrib('remote_url'));
#		$CART->in_set('chkout.payment_status',$o->get_attrib('payment_status'));
#		}
