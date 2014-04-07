package CAMPAIGN;

use lib "/backend/lib";
require DBINFO;
use strict;
use File::Slurp;
use Data::Dumper;
use IO::String;
use Mail::DKIM::Signer;
use Crypt::OpenSSL::RSA;
use Mail::DKIM::PrivateKey;
use Data::GUID;

use lib "/backend/lib";
use strict;

use MIME::Entity;
use Net::AWS::SES;
require TEMPLATE::KISSTLC;



@CAMPAIGN::KEYS = (
	'RECIPIENTS',
	'SUBJECT','SEND_EMAIL','SEND_APPLEIOS','SEND_ANDROID','SEND_FACEBOOK',
	'SEND_TWITTER','SEND_SMS','QUEUE_MODE','EXPIRATION','COUPON','STARTTIME',
	'TEMPLATE_ORIGIN',
	);




#sub queue {
#	my ($self, $CIDS) = @_;
#	
##	&ZOOVY::getRedis($USERNAME,4);
##	foreach my $CID (@{$CIDS}) {
#
#	## EXPIREAT / TTL
#	## we will use lists 
#	## rpush, lpush
#	
#	}

##
##
##
sub recipients {
	my ($self, %options) = @_;
	my $RECIPIENTS = $options{'RECIPIENTS'} || $self->{'RECIPIENTS'};
	my @CIDS = ();
	require CUSTOMER::BATCH;
	if ($RECIPIENTS) {
		my @LINES = ();
		foreach my $line (split(/[\n\r]+/,$RECIPIENTS)) {
			push @LINES, $line;
			}
		@CIDS = CUSTOMER::BATCH::resolveCustomerSelector($self->username(),$self->prt(),\@LINES);
		}
	return(\@CIDS);
	}


sub send_email {
	my ($self,%params) = @_;

	my $CPG = $self;
	my $CID = $params{'CID'} || 0;
	my ($lm) = $params{'*LM'};

	my $ERRORSTO = '';
	my $REPLYTO = '';

	my $PRT = $self->prt();
	my ($webdb) = &ZWEBSITE::fetch_website_dbref($self->username(),$self->prt());

	my %EMAIL = ();
	if ((defined $webdb->{'%plugin.esp_awsses'}) && ($webdb->{'%plugin.esp_awsses'}->{'enable'})) {
		##
      ##                              'iam-username' => '20131126-200727',
      ##                              'enable' => '0',
      ##                              'ts' => '1385525408',
      ##                             'from_email_campaign' => '',
      ##                              'from_email_support' => '',
      ##                              '~smtp-password' => 'AoilvAuYpxeDUd60lS96x2yrvY5hf1zCKBK3ahAgBJxd',
      ##                              'luser' => 'support/kimh',
      ##                              'from_email_auto' => '',
      ##                              'smtp-username' => 'AKIAI5RZAP3S2BYEDCIA'
		##
		%EMAIL = %{$webdb->{'%plugin.esp_awsses'}};
		foreach my $k (keys %EMAIL) {
			if (substr($k,0,1) eq '~') {
				$EMAIL{substr($k,1)} = $EMAIL{$k}; 	## change ~smtp-password into smtp-password
				}
			}
		$EMAIL{'esp'} = 'awsses';
		}
	else {
		##
		%EMAIL = (
			'esp'=>'postfix',
			'from_email_campaign'=>''
			);
		}
	my $FROM = $EMAIL{'from_email_campaign'};
#		my $BOUNCE = undef;
#		my ($UNIQUEID) = 0;
#		my ($C) = CUSTOMER->new($USERNAME,'PRT'=>$self->prt(),'CID'=>$CID);
#		if (not defined $C) {
#			push @MSGS, "STOP|+CID: $CID does not exist";
#			}
#		elsif (($CID>0) || ($UNIQUEID>0)) {
#			my $b36CID = &ZTOOLKIT::base36($CID);
#			my $b36CPG = &ZTOOLKIT::base36($CREF->{'ID'});
#			my $b36CPNID = &ZTOOLKIT::base36($UNIQUEID);
#			$FROM = "vip-$b36CID\@newsletter.$CREF->{'SENDER'}";
#			$BOUNCE = "$b36CID+$b36CPG+$b36CPNID\@newsletter.$CREF->{'SENDER'}";
#			}
#		else {
#			$FROM = "campaign+$CREF->{'ID'}\@newsletter.$CREF->{'SENDER'}";
#			$BOUNCE = $FROM;
#			}

	# Build the message body.
	## perl -e 'use lib "/backend/lib"; use CAMPAIGN; my ($CPG) = CAMPAIGN->new("sporks",0,"TESTER5_20131126"); print $CPG->html();';

	my ($html) = $CPG->html(%params);
	my $TARGET = $params{'email'};

	my ($msg) = MIME::Entity->build(
		Type=>'text/html',
		'X-Mailer'=>"CommerceRack/3.0",
		'To'=>$TARGET,
		'From'=>$FROM,
		#'Errors-To'=>$FROM,
		#'Reply-To'=>$FROM,
		#'Return-Path'=>$FROM,
		'Subject'=>$CPG->property('SUBJECT'),
		'Data'=>$html
		);


#	my @HEADERS = ();
#	push @HEADERS, "Sender: <$FROM>";
#	if ($MSGREF->{'zoovy:fromvalid'}) {
#		push @HEADERS, "From: $COMPANY <$MSGREF->{'zoovy:from'}>";
#		}
#	else {
#		push @HEADERS, "From: $COMPANY <$FROM>"; 
#		}
#
#	push @HEADERS, "List-Unsubscribe: <mailto:$FROM?subject=Unsubscribe>";
#	push @HEADERS, "To: $RECIPIENT"; 
#	push @HEADERS, "Subject: $title";
#
#	foreach (split(/[\n]/,$altmsg->header_as_string())) {
#		s/[\r]+$//;
#		push @HEADERS, "$_";
#		}
#
#	## OMFG this is an important line:
#	push @HEADERS, "";  ## do not remove, needed to separate headers from body! or DKIM signing runs amuck!

#	foreach (split(/[\n]/,$altmsg->body_as_string())) {
#		s/[\r]+$//;
#		push @HEADERS, "$_";
#		}

#	my $sigtxt = '';
#	my @LINES = ();
#	if ((defined $CREF) && (ref($CREF->{'*D'}) eq 'DOMAIN') && ($CREF->{'*D'}->has_dkim())) {

#	## NOTE: DOMAIN KEYS IS OLD - DKIM IS NEW ** THEY ARE NOT THE SAME THING **
#	## okay we're going to dkim this message.
#	my $pk = $CREF->{'*PK'};
#	if (not defined $pk) {
#		my $rsa = Crypt::OpenSSL::RSA->new_private_key($CREF->{'*D'}->dkim_privkey());
#		$pk = Mail::DKIM::PrivateKey->load(Cork=>$rsa);
#		$CREF->{'*PK'} = $pk;
#		}
#
#	my $dkim = Mail::DKIM::Signer->new(
#		Algorithm => "rsa-sha1",
#		Method => "simple", 
#		# Method => "relaxed",
#		# Method => "nofws",
#		# Headers => "From:To:Subject",
#		Domain => "newsletter.".$CREF->{'*D'}->domainname(),
#		Selector => "s1",
#		Key=>$pk,
#      # KeyFile => "private.key",
#      );
#
#	foreach my $h (@HEADERS) {
#		$dkim->PRINT("$h\015\012");
#		}
#	#foreach (split(/[\n]+/,${$io->string_ref()})) {
#	#	s/[\r]+$//;
#	#	$dkim->PRINT("$_");
#	#	push @LINES, "$_\015\012";
#	#	}
#	# $dkim->PRINT(${$io->string_ref()});
#	$dkim->CLOSE();
#
#
#	my $signature = $dkim->signature();
#	unshift @HEADERS, $signature->as_string();
#
	if ($EMAIL{'esp'} eq 'awsses') {
		## print STDERR Dumper(\%EMAIL);

		my $ses = Net::AWS::SES->new(
			access_key => $EMAIL{'smtp-username'}, 
			secret_key => $EMAIL{'smtp-password'},
			);

		my $r = undef;
		eval { $r = $ses->send($msg); };

		if ( not defined $r ) {
			$lm->pooshmsg(sprintf("ISE|CID:$CID|+$TARGET ~~ %s",Dumper($r)));
			}
		elsif ( $r->is_success ) {
			$lm->pooshmsg(sprintf("SENT|CID:$CID|+$TARGET ~~ %s",$r->message_id));
			}
		else {
			$lm->pooshmsg(sprintf("FAIL|CID:$CID|+$TARGET ~~ %s",$r->error_message));

			## print Dumper($r);
			# die();
			}
		}
	else {
		die();
		#my $CMD = "/usr/sbin/sendmail";
		#if (&ZOOVY::host_operating_system() eq 'SOLARIS') {
		#$CMD = "/opt/csw/sbin/sendmail";
		#open MH, "|$CMD -t -f $FROM"; 
		#foreach my $h (@HEADERS) {
		#	print MH "$h\015\012";
		#	}
		#close(MH);
		}
                
	return();
	}


##
##
sub test {
	my ($self, %params) = @_;

	my ($lm) = LISTING::MSGS->new($self->username());
	my ($redis) = &ZOOVY::getRedis($self->username(),2);
	my ($REDISKEY) = $self->campaignid();
	$redis->del($REDISKEY);
	$redis->lpush($REDISKEY,"START");
	my @CIDS = @{$self->recipients(%params)};
	if (scalar(@CIDS)==0) {
		$lm->pooshmsg("ERROR|+Sorry, no CID's could not be found.");
		}
	else {
		foreach my $CID (@CIDS) {
			if ($CID == 0) {
				$lm->pooshmsg("ERROR|+could not resolve customer CID (check to make sure customer account is valid on partition)");
				}
			else {
				## $lm->pooshmsg("INFO|+attempt CID:$CID");
				$redis->lpush($REDISKEY,"CID?CID=$CID");
				}
			}	
		}
	#if ($params{'email'}) {
	#	$redis->lpush($REDISKEY,"EMAIL?email=".$params{'email'});
	#	}

	$redis->lpush($REDISKEY,"FINISH");
	## $redis->expire($REDISKEY,60*1000);

	if ($lm->can_proceed()) {
		$self->__send__($REDISKEY, $lm);
		}

	return($lm);
	}




##
##
##
sub __send__ {
	my ($self, $REDISKEY, $lm) = @_;

	my $PRT = $self->prt();
	my ($redis) = &ZOOVY::getRedis($self->username(),2);
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $CPGID = $self->campaignid();

	print STDERR "CAMPAIGN: $CPGID\n";
	print STDERR "REDISKEY: $REDISKEY\n";

	if ($redis->llen($REDISKEY) == 0) {
		$lm->pooshmsg("FATAL|+Redis $REDISKEY is completely empty");
		}

	while ( my $LINE = $redis->rpop("$REDISKEY") ) {
		## $lm->pooshmsg("DEBUG|+$LINE");
		my ($VERB,$PARAMS) = split(/\?/,$LINE, 2);
		my %params = %{&ZTOOLKIT::parseparams($PARAMS)};
		$params{'*LM'} = $lm;

		if ($VERB eq 'CID') {
			my ($C) = CUSTOMER->new($self->username(),'PRT'=>$PRT,'CREATE'=>0,'CID'=>$params{'CID'});
			$params{'*CUSTOMER'} = $C;
			$VERB = 'EMAIL';
			$params{'email'} = $C->email();

			if (not &ZTOOLKIT::validate_email($params{'email'})) {
				## EMAIL did not validate.
				$VERB = 'NULL';
				$lm->pooshmsg("WARNING|+Found invalid email $params{'email'}");
				}
			}

		if ($VERB eq 'NULL') {
			## skip this line!
			}
		elsif ($VERB eq 'RESTART') {
			$lm->pooshmsg("WARNING|+Detected restart (or assist) by process $$");
			}
		elsif ($VERB eq 'BEEN-HERE-DONE-THAT') {
			$redis->lpush($REDISKEY,'BEEN-HERE-DONE-THAT');
			$lm->pooshmsg("STOP|+Campaign has already been sent completely.");
			last;
			}
		elsif ($VERB eq 'START') {
			## set the statistics.
			}
		elsif ($VERB eq 'FINISH') {
			## wrap it up.
			my $pstmt =	"update CAMPAIGNS set STATUS='DONE' where CAMPAIGNID=".$udbh->quote($CPGID);
			print "$pstmt\n";
			$udbh->do($pstmt);
			$redis->lpush($REDISKEY,'BEEN-HERE-DONE-THAT');
			$lm->pooshmsg("SUCCESS|+Finished sending campaign");
			last;
			}
		elsif ($VERB eq 'EMAIL') {
			## yay email!
			$self->send_email('*LM'=>$lm,%params);	
			}
		elsif ($VERB eq 'GCM') {
			## yay google cloud messaging
			}
		elsif ($VERB eq 'APNS') {
			## yay ios!
			}
		elsif ($VERB eq 'ADN') {
			## fuck you amazon device notifications.
			}
		else {
			$lm->pooshmsg("ISE|+Unknown cmd.");
			}
		}

	if ($lm->had('STOP')) {
		## for the love of god, don't try to run this again.
		$lm->pooshmsg("ERROR|+received stop command, probably a re-run");
		}
	elsif ($lm->has_failed()) {
		}
	elsif ($lm->has_win()) {
		}
	else {
		$lm->pooshmsg("FINISH|+Exit with no explicit win/fail, this may be normal.");
		}

	&DBINFO::db_user_close();
	print STDERR Dumper($lm);

	return($lm);
	}




##
##
## NOTE: STOP messages should be handled as YOUERR
##			everything else is FILEERR
##
#sub __send__ {
#	my ($self,%options) = @_;
#	
#	## 1. build a list of recipients
#
#	my $redis = ZOOVY::getRedis($self->username(),0);
#
#	my $USERNAME = $self->username();
#	my $ERRORSTO = '';
#	my $REPLYTO = '';
#	my $TITLE = $self->{'SUBJECT'};
#	my $CREF = {};
#
#	## 2. decide if we're going to send, or simply insert events
#	my $FROM_DOMAIN = &DOMAIN::TOOLS::domain_for_prt($self->username(),$self->prt());
#	my ($D) = DOMAIN->new($self->username(),$FROM_DOMAIN);
#	my $COMPANY = $D->get('our/company_name');
#
#	my @RESULTS = ();
#
#	my @CIDS = $self->recipients();
#
#	foreach my $CID (@CIDS) {
#		my $TS = undef;
#		my ($CAMPAIGNID) = $self->campaignid();
#		my ($FROM) = ('');
#
#		my @MSGS = ();
#		my ($LM) = LISTING::MSGS->new($USERNAME,'@MSGS'=>\@MSGS);
#
#		my $KEY = '';
#
#
#	
#		## 3. log that it was sent.
#		my ($html) = '';
#		if ($LM->can_proceed()) {
#			require TEMPLATE::KISSTLC;
#			($html) = TEMPLATE::KISSTLC::render($self->username(),'CPG',$self->campaignid(),'KEY'=>$KEY,'CID'=>$CID,'*CUSTOMER'=>$C,'PRT'=>$self->prt(),'@MSGS'=>\@MSGS);
#			}
#	
#		if ($LM->can_proceed()) {
#			my $TYPE = 'multipart/alternative';
#			my $RECIPIENT = $C->email();
#
#			# Build the message body.
#			my $altmsg = MIME::Entity->build(
#				Type=>'multipart/alternative',
#				'X-Mailer'=>"CommerceRack/$TEMPLATE::VERSION [$USERNAME]",
#				'Errors-To'=>$ERRORSTO,
#				'Reply-To'=>$REPLYTO,
#				'Return-Path'=>$ERRORSTO,
#				);
#	
#			$altmsg->attach(
#				Type => 'text/html',
#				Disposition => 'inline',
#				Data => $html
#				);
#			
#			my @HEADERS = ();
#			push @HEADERS, "Sender: <$FROM>";
#			push @HEADERS, "From: $COMPANY <$FROM>"; 
#			# Return-Path: <v-cdammaf_fgfpelnc_ighfmel_ighfmel_a-1@bounce.t.plasticjungle.com>
#			# push @HEADERS, "List-Unsubscribe: <mailto:v-cdammaf_fgfpelnc_ighfmel_ighfmel_a-1@bounce.t.plasticjungle.com?subject=Unsubscribe>";
#			# push @HEADERS, "List-Unsubscribe, <mailto:list-request@host.com?subject=unsubscribe>, <http://www.host.com/list.cgi?cmd=unsub&lst=list>";
#			
#			push @HEADERS, "List-Unsubscribe: <mailto:$FROM?subject=Unsubscribe>";
#			push @HEADERS, "To: $RECIPIENT"; 
#			push @HEADERS, "Subject: $TITLE";
#
#			foreach (split(/[\n]/,$altmsg->header_as_string())) {
#				s/[\r]+$//;
#				push @HEADERS, "$_";
#				}
#
#			## OMFG this is an important line:
#			push @HEADERS, "";  ## do not remove, needed to separate headers from body! or DKIM signing runs amuck!
#	
#			foreach (split(/[\n]/,$altmsg->body_as_string())) {
#				s/[\r]+$//;
#				push @HEADERS, "$_";
#				}
#	
#			my $sigtxt = '';
#			my @LINES = ();
#			if (1) {
#				}
#			elsif ((ref($CREF->{'*D'}) eq 'DOMAIN') && ($CREF->{'*D'}->has_dkim())) {
#	
#				## NOTE: DOMAIN KEYS IS OLD - DKIM IS NEW ** THEY ARE NOT THE SAME THING **
#				## okay we're going to dkim this message.
#				my $pk = $CREF->{'*PK'};
#				if (not defined $pk) {
#					my $rsa = Crypt::OpenSSL::RSA->new_private_key($CREF->{'*D'}->dkim_privkey());
#					$pk = Mail::DKIM::PrivateKey->load(Cork=>$rsa);
#					$CREF->{'*PK'} = $pk;
#					}
#
#				my $dkim = Mail::DKIM::Signer->new(
#					Algorithm => "rsa-sha1",
#					Method => "simple", 
#					# Method => "relaxed",
#					# Method => "nofws",
#					# Headers => "From:To:Subject",
#					Domain => "newsletter.".$CREF->{'*D'}->domainname(),
#					Selector => "s1",
#					Key=>$pk,
#					# KeyFile => "private.key",
#					);
#
#				foreach my $h (@HEADERS) {
#					$dkim->PRINT("$h\015\012");
#					}
#				#foreach (split(/[\n]+/,${$io->string_ref()})) {
#				#	s/[\r]+$//;
#				#	$dkim->PRINT("$_");
#				#	push @LINES, "$_\015\012";
#				#	}
#                        # $dkim->PRINT(${$io->string_ref()});
#				$dkim->CLOSE();
#				my $signature = $dkim->signature();
#	#			$signature->headerlist("Sender:From:To:Subject");
#	#			$signature->headerlist("to:from:subject");
#	#			print STDERR Dumper($signature,\@HEADERS);
#	#                       die(Dumper($dkim->message_sender(),$dkim->message_originator(),$dkim->signature()));
#                      
#				unshift @HEADERS, $signature->as_string();
#	#			unshift @LINES, $signature->as_string()."\015\012";
#				}
#
#	#		if ((defined $MSGREF->{'zoovy:cc'}) && ($MSGREF->{'zoovy:cc'} ne '')) {
#	#			print MH "Cc: ".$MSGREF->{'zoovy:cc'}."\n";
#	#			}
#	#		elsif ((defined $MSGREF->{'zoovy:carbon'}) && ($MSGREF->{'zoovy:carbon'} ne '')) { 
#	#			print MH "Cc: ".$MSGREF->{'zoovy:from'}."\n"; 
#	#			}
#	#		if (defined $MSGREF->{'zoovy:bcc'}) {
#	#			print MH "Bcc: ".$MSGREF->{'zoovy:bcc'}."\n";
#	#			}
#
#			#	print MH "Bcc: adam\@zoovy.com\n";
#			my $CMD = "/usr/sbin/sendmail";
#			if (&ZOOVY::host_operating_system() eq 'SOLARIS') {
#				$CMD = "/opt/csw/sbin/sendmail";
#				}
#                
#			## 4. send it.
#			open MH, "|$CMD -t -f $FROM"; 
#	#		print MH $sigtxt;
#			foreach my $h (@HEADERS) {
#				print MH "$h\015\012";
#				# join('',@HEADERs); # ${$io->string_ref()};
#				}
#			# foreach my $h (@HEADERS) { print MH $h; }
#			close(MH);
#			push @MSGS, "SUCCESS|+Email sent";
#			}
#		
#		my $RESULT = $LM->whatsup();
#		$RESULT->{'CID'} = $CID;
#		$RESULT->{'TS'} = $TS;
#		$RESULT->{'@MSGS'} = \@MSGS;
#		push @RESULTS, $RESULT;
#		}
#
#	$redis = undef;
#	return(\@RESULTS);
#	}
#

##
## pass a username and campaign id (e.g. the ID column in the CAMPAIGNS table)
##	returns:
##		hashref of all fields in CAMPAIGN table
##		OR undef on failure.
##
sub exists {
	my ($USERNAME,$CAMPAIGN_ID) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $CREF = undef;

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select count(*) from CAMPAIGNS ".
					"where MID=$MID /* $USERNAME */ ".
					"and CAMPAIGNID=".$udbh->quote($CAMPAIGN_ID);
	my ($count) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();
	return($count);
	}



##
##
##
sub new {
	my ($CLASS,$USERNAME,$PRT,$CAMPAIGNID,%options) = @_;

	$PRT = int($PRT);

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select * from CAMPAIGNS where MID=$MID and PRT=$PRT and CAMPAIGNID=".$udbh->quote($CAMPAIGNID);
	my ($self) = $udbh->selectrow_hashref($pstmt);
	if (not defined $self) { $self = {}; }

	$self->{'USERNAME'} = $USERNAME;
	$self->{'PRT'} = $PRT;
	$self->{'CAMPAIGNID'} = $CAMPAIGNID;
	&DBINFO::db_user_close();

	bless $self, 'CAMPAIGN';
	return($self);
	}


sub username { return($_[0]->{'USERNAME'}); }
sub prt { return($_[0]->{'PRT'}); }
sub campaignid { return($_[0]->{'CAMPAIGNID'}); }

## any db colum (or emulation if we change)
sub property { return($_[0]->{ $_[1] }); }

sub campaigndir {
	my ($USERNAME,$CAMPAIGNID) = @_;

	if (ref($USERNAME) eq 'CAMPAIGN') {
		my $self = $USERNAME;
		return(&CAMPAIGN::campaigndir($self->username,$self->campaignid()));
		}

	($CAMPAIGNID) = uc($CAMPAIGNID);
	$CAMPAIGNID =~ s/[^A-Z0-9\_\-]+//gs;	# strip non-allowed characters
	my ($userpath) = &ZOOVY::resolve_userpath($USERNAME)."/IMAGES/_campaigns/$CAMPAIGNID";
	return($userpath);
	}

sub baseurl {
	my ($USERNAME,$DOMAIN,$CODE) = @_;
	return("http://$DOMAIN/media/merchant/$USERNAME/_campaigns/$CODE/");
	}



sub set { 
	my ($self,$k,$v) = @_; 
	$self->{$k} = $v; 
	}

##
##
sub nuke {
	my ($self) = @_;

	my ($USERNAME) = $self->username();
	my ($PRT) = $self->prt();

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($CAMPAIGNID) = $self->campaignid();
	my $pstmt = "delete from CAMPAIGNS where MID=$MID and PRT=$PRT and CAMPAIGNID=".$udbh->quote($CAMPAIGNID);
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	return();
	}

##
##
sub save {
	my ($self) = @_;

	my ($USERNAME) = $self->username();
	my ($PRT) = $self->prt();
	my ($CAMPAIGNID) = $self->campaignid();

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select count(*) from CAMPAIGNS where MID=$MID and PRT=$PRT and CAMPAIGNID=".$udbh->quote($CAMPAIGNID);
	my ($EXISTS) = $udbh->selectrow_array($pstmt);

	my %vars = ();
	$vars{'USERNAME'} = $self->username();
	$vars{'MID'} = &ZOOVY::resolve_mid($self->username()); 
	$vars{'PRT'} = $self->prt();
	$vars{'CAMPAIGNID'} = $self->campaignid();

	foreach my $k (@CAMPAIGN::KEYS) {
		if (defined $self->{$k}) {
			$vars{$k} = $self->{$k};
			}
		}

	$pstmt = &DBINFO::insert($udbh,'CAMPAIGNS',\%vars,verb=>($EXISTS?'update':'insert'),sql=>1,key=>['MID','PRT','CAMPAIGNID']);
	print STDERR "$pstmt\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	}

##
##
sub TO_JSON {
	my ($self) = @_;
	my %R = ();
	foreach my $k (keys %{$self}) { $R{$k} = $self->{$k}; }
	return(\%R);
	}

##
##
sub list {
	my ($USERNAME,%options) = @_;

	my $R = [];

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select * from CAMPAIGNS where MID=$MID";
	if ($options{'PRT'}) { $pstmt .= " and PRT=".int($options{'PRT'}); }
	print STDERR "$pstmt\n";

	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $row = $sth->fetchrow_hashref() ) {
		push @{$R}, $row;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return($R);
	}


##
##
##
sub html {
	my ($self, %params) = @_;

	## my $file = sprintf("%s/index.html",$self->campaigndir());
	## my $html = File::Slurp::read_file($file);

	use TEMPLATE::KISSTLC;
	my ($html) = TEMPLATE::KISSTLC::render($self->username(),'CPG',$self->campaignid(),%params);

	return($html);
	}


1;

__DATA__

#!/usr/bin/perl

use lib "/backend/lib";
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



package CUSTOMER::NEWSLETTER;

require ZOOVY;
require DBINFO;
require ZWEBSITE;
require ZTOOLKIT;
use Data::Dumper;



##
## removes characters that are non-email safe, including html.
##
sub htmlStrip {
	my ($body) = @_;
	$body =~ s/&nbsp;/ /gs;
	$body =~ s/<a.*?href=\"(.*?)\">(.*?)<\/a>/$2 $1/gs;	# convert links!
	$body =~ s/\<style.*?\<\/style\>//igs;
	$body =~ s/\<script.*?\<\/script\>//igs;
	$body =~ s/\<br\>/\n\r/gs;
	$body =~ s/\<li\>/\[\*\] /gs;
	$body =~ s/<\/tr>/\n\r/igs;
	$body =~ s/<\/td>/\t/igs;
	$body =~ s/\<.*?\>//gs;
	$body =~ s/[\t]+//g; 

	$body =~ s/[\r]+//gs;	# remove lf's 
	$body =~ s/\n[\n]+/\r/gs;	# remove 2+ \n's with a \r

	my $new = '';
	foreach my $line (split(/[\n]+/,$body)) {
		$line =~ s/[ ]+/ /gs;	# strip unnecessary whitespace
		$line =~ s/^[ ]+//g; 	# strip leading whitespace
		$line =~ s/[ ]+$//g;	# strip trailing whitespace
		if ($line ne '') { 
			$new .= $line."\n";
			}
		$line =~ s/[\r]+/\n/gs;
		}
	$body = $new;
		# $body =~ s/[\n\r]+/\n\r/gs;
	return($body);
}


###############################################################################
## AUTOEMAIL::interpolate
## parameters: the message and subject you want to send, 
##					plus a reference to a hash of variables to be interoplated
##	returns: a interpolated messages
##
sub interpolate {
	my ($textref, $hashref) = @_;

	my ($key,$val) = ('','');  
	foreach $key (keys %{$hashref})
		{
		$val = $hashref->{$key};
		if (not defined $val) { $val = ''; }
		${$textref} =~ s/$key/$val/gis;
		}

	return($textref);
}



##
## Parameters: $USERNAME (just in case we need it)
##					$RECIPIENT (destination email address)
##					$MSGREF is a reference to a message hash (probably from load_message or safefetch_message)
##					$SUBREF is a set of data, either populated by the caller or by build_defaults_for_test
##	OPTIONS:
##
##		2 - message is implicitly HTML -- default OFF
##		4 - don't validate source email address
##		8 - don't cobrand message.
##		16 - don't do aol checks.
##		32 - add newsletter header
##
##		result:
##			result, \@warnings
##			result = 1 (sent), 0 (sent w/warnings), -1 (not sent due to errors)
##
sub sendmail {
	my ($USERNAME, $PROFILE, $RECIPIENT, $MSGREF, $SUBREF, $CREF) = @_;

	my $result = 0;
	my @WARNINGS = ();

	if ($MSGREF =~ /^[\s]+$/) { $result = -1; push @WARNINGS, "Message is blank or contains nothing but whitespace"; }
	elsif ($RECIPIENT eq '') { $result = -1; push @WARNINGS, "Recipient is not set"; }
	elsif (not &ZTOOLKIT::validate_email($RECIPIENT)) { 
		$result = -1; 
		push @WARNINGS, "Recipient email [$RECIPIENT] does not appear to be valid."; 
		}

	my $COMPANY = $MSGREF->{'zoovy:company'};
	if ($COMPANY eq '') { $result = -1; push @WARNINGS, "Company name was not set or found."; }
	my $REPLYTO = $MSGREF->{'zoovy:replyto'};
	if ($REPLYTO eq '') { $result = -1; push @WARNINGS, "Reply-to address could not be resolved."; }
	
	$SUBREF->{'%USERNAME%'} = $USERNAME;

	my $body = $MSGREF->{'zoovy:body'};
	my $title = $MSGREF->{'zoovy:title'};
	$title =~ s/[\n\r]+//gs;
	if ($title eq '') { push @WARNINGS, "Message has a blank title"; }
	
	&interpolate(\$body,$SUBREF);	
	&interpolate(\$title,$SUBREF);	

	my $FROM = $MSGREF->{'zoovy:from'};
	## multiple addresses can be specified email1@isp1.com,email2@isp2.com

	#if (index($FROM,',')>=10) { $FROM = substr($FROM,0,index($FROM,',')); }
	#if ($FROM =~ /<(.*?\@.*?)>/) { $FROM = $1; }	# Noah Webster <noah@dictionary.com>
	#$FROM =~ s/[^A-Za-z0-9\.@\-\_]//gs;
	
	if ($result == -1) { 
		}
	elsif ($FROM eq '') { 
		$result = -1; push @WARNINGS,"From address is blank"; 
		}
	elsif (not &ZTOOLKIT::validate_email($FROM)) { 
		$result = -1; push @WARNINGS, "From email address [$FROM] does not appear to be valid."; 
		}

	my $ERRORSTO = $MSGREF->{'zoovy:bounce'};		# where do we send errors to!
	if ($ERRORSTO eq '') { $ERRORSTO = $FROM; }
	

	my $html = '';
	if ($result == -1) {
		## we already encountered a fatal error
		}
	else {
		## this is an HTML message, we should create a plaintext version
		$html = $body;
		$body = &CUSTOMER::NEWSLETTER::htmlStrip($html);
		# $html =~ s/\>\</\>\n\</gs;
		}
		
		
#        $RECIPIENT = 'brian@zoovy.com';
#        $RECIPIENT = 'zoovyliz@yahoo.com';
#        $RECIPIENT = 'liz.marrone@gmail.com';

#	$FROM = 'brian@zoovy.com'; $ERRORSTO = $FROM; $REPLYTO = $FROM;
#	$RECIPIENT = 'dkim-test@altn.com';

	## add the body and /html tags back in!
	if ($result == 0) {
		if ($html =~ /<\/body>/i) { $html =~ s/<\/body>//ig; $html .= "</body>"; }
		if ($html =~ /<\/html>/i) { $html =~ s/<\/html>//ig; $html .= "</html>"; }


	return($result,\@WARNINGS);
}





##
## returns: 
## 	array, each position (0..15) is the newsletter #
##		which corresponds to it's bit position in the customer record.
##		the value is a hashref which consists of the corresponding row from the database.
##		$key->{'SUBSCRIBE'} pulled from LIKES_SPAM value in CUSTOMER_TB
##			1 subscribed 
##			0 not subscribed
## 		-1 if not available
##
## sample dump of @RESULTS
## $VAR1 = undef;
## $VAR2 = {
##          'ID' => 1,
##          'NAME' => 'one',
##          'USERNAME' => 'patti',
##          'SUBSCRIBE' => 1,
##          'EXEC_SUMMARY' => '',
##          'MID' => 2,
##          'MODE' => 2,
##        };
## $VAR3 = {
##          'ID' => 2,
##          'NAME' => 'two',
##          'USERNAME' => 'patti',
##          'SUBSCRIBE' => '0',
##          'EXEC_SUMMARY' => 'test',
##          'MID' => 2,
##          'MODE' => 2,
##			 };
##
sub available_newsletters {
	my ($USERNAME, $PRT, $EMAIL) = @_;
   my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my (@NAME) = ();

   my $dbh = &DBINFO::db_user_connect($USERNAME);
   my $TB = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);

   my $pstmt = "select NEWSLETTER from $TB where EMAIL=".$dbh->quote($EMAIL)." and MID=$MID /* $USERNAME */ and PRT=".int($PRT);
   my $sth = $dbh->prepare($pstmt);
   $sth->execute();
	my ($LS) = $sth->fetchrow_array(); 
	$sth->finish();
   &DBINFO::db_user_close();

	my (@RESULTS) = CUSTOMER::NEWSLETTER::fetch_newsletter_detail($USERNAME,$PRT);
	foreach my $key (@RESULTS) {
      next if (not defined $key);

		if ($key->{'NAME'} eq '') {
			if ($key->{'ID'} == 1) { $key->{'NAME'} = 'Store Newsletter'; }
			else { $key->{'NAME'} = 'Newsletter #'.$key->{'ID'}; }
			}

		## if MODE is Exclusive/private
		## otherwise check against LIKES_SPAM
		if ($LS & (1 << ($key->{'ID'}-1) ) ){ $key->{'SUBSCRIBE'} = 1; }
		## NOTE: This line is *broke* it ignore LIKESPAM (not sure why it was even here) BH 12/18/07
		## elsif ($key->{'MODE'} == 0){ $key->{'SUBSCRIBE'} = -1; }
		else{ $key->{'SUBSCRIBE'} = 0; }
		}

	return(\@RESULTS);
	}

##
## pass a username and campaign id (e.g. the ID column in the CAMPAIGNS table)
##	returns:
##		hashref of all fields in CAMPAIGN table
##		OR undef on failure.
##
sub fetch_campaign {
	my ($USERNAME,$CAMPAIGN_ID) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $CREF = undef;

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select * from CAMPAIGNS ".
					"where MID=$MID /* $USERNAME */ ".
					"and ID=".int($CAMPAIGN_ID);
	my $sth = $udbh->prepare($pstmt);
   $sth->execute();
	if ($sth->rows()) { $CREF = $sth->fetchrow_hashref(); }
	$sth->finish();
	&DBINFO::db_user_close();

	return($CREF);
	}

##
##
## takes the HTML output from a newsletter, and the campaign id.
##	
## and does the following:
##		if unique id is zero, then this also adds the "Approve" link.
##		adds the cpg= tags
##		adds the unsubscribe
##		adds the webbug to track how many times the email was opened.
##
sub rewrite_links {
	my ($html, $uri) = @_;

	## HTML section of email
	## add cpg to all links
	
#	my $SDOMAIN = quotemeta($CREF->{'SENDER'});
#	$SDOMAIN = ".*?$SDOMAIN.*?";
	my $SDOMAIN = "\\?";

	## catch all links with params (need to add &)
	$html =~ s/href\s*=\s*"([^"\s>]+)($SDOMAIN)([^"\s>]+)"/href="$1$2$3\&$uri"/gis;
	## and those with anchors
	$html =~ s/href\s*=\s*\"([^\"$SDOMAIN\s>]+)(\#.*)\"/href="$1\?$uri$2"/gis;
	## and those without (need to add ?)
	$html =~ s/href\s*=\s*\"([^\"$SDOMAIN\s>]+)\"/href="$1\?$uri"/gis;

	return($html);
	}



##
## NOTE: CEID is the unique identifier for this particular email.
##
sub build_footer {
	my ($CREF,$nsref) = @_;

	if (not defined $nsref) {
		die("NSREF is required");
		}
	
	$CREF->{'COMPANY'} = $nsref->{'zoovy:company_name'};
	$CREF->{'COMPANY'} =~ s/[^\w]+/ /g;		## remove bad characters that will confuse mailers.
	$CREF->{'REPLY-TO'} = $nsref->{'zoovy:support_email'};
	if ($CREF->{'REPLY-TO'} eq '') { $CREF->{'REPLY-TO'} = $nsref->{'zoovy:email'}; }
	## we should some fancy shmancy domain stuff here.

   if (not defined $nsref->{'zoovy:address1'}) {
      $nsref->{'zoovy:address1'} = $nsref->{'zoovy:address'};
      }
	my $addr = $nsref->{'zoovy:address1'}."<br>\n";
	
	if ($nsref->{'zoovy:address2'} ne '') { $addr .= $nsref->{'zoovy:address2'}."<br>\n"; }
	$addr .= $nsref->{'zoovy:city'}.', '.$nsref->{'zoovy:state'}.' '.$nsref->{'zoovy:zip'}."<br>\n";

	my $USERNAME = $CREF->{'USERNAME'};

my  $html = qq~
<center>
<br>
<table cellpadding="4" cellspacing="0" style="border:1px solid #CCCCCC; background-color:#FFFFFF; font-family:Arial, Helvetica, sans-serif; font-size: 8pt;">
<tr>
	<td valign="top" rowspan="2" style="border-right:1px solid #cccccc;">$nsref->{'zoovy:company_name'}<br>$nsref->{'zoovy:support_phone'}<br>
	$addr</td>
	<td colspan="2">
	This email was sent to %EMAIL% on behalf of $nsref->{'zoovy:company_name'}.<br>
	To stop future mailings please <a style="font-family:Arial, Helvetica, sans-serif; font-size: 8pt;" href="http://www.$CREF->{'SENDER'}/customer/newsletter/unsubscribe?username=%EMAIL%&meta=NEWSLETTER&cpg=%CAMPAIGN%&cpn=%CPNID%">Unsubscribe</a>.<br>
	Your privacy is important, please <a style="font-family:Arial, Helvetica, sans-serif; font-size: 8pt;" href="http://www.$CREF->{'SENDER'}/privacy.cgis">read our privacy policy</a>.
	</td>
</tr>
<tr style="background-color:#f0f0f0;">
	<td valign="top">This email was sent by <a style="font-family:Arial, Helvetica, sans-serif; font-size: 8pt;" href="http://www.zoovy.com/track.cgi?M=$USERNAME">Zoovy.com</a> on behalf of $nsref->{'zoovy:company_name'}.</td>
	<td valign="top"><a style="font-family:Arial, Helvetica, sans-serif; font-size: 8pt;" href="http://www.zoovy.com/track.cgi?M=$USERNAME">
	<img src="https://static.zoovy.com/img/proshop/W90-H30-BF0F0F0/zoovy/logos/zoovy.gif" alt="" border="0">
	</a>
	</td>
</tr></table>
<img height="1" width="1" src="http://webapi.zoovy.com/webapi/webbug.cgi/CPG=%CAMPAIGN%/CPN=%CPNID%/$USERNAME.gif">
</center>
	~;

	return($html);
	}


## 
## pass:
##		campaign ref (from fetch_campaign)
##		email address to send to.
##		UniqueID (0 if this is a test email) -- otherwise the unique message id.
##		customer full name	
##
## return:
##		result
##			 1 - success
##			 0 - success w/warnings
##			-1 - unsuccessful w/errors
## 	warnings/errors specific to send
##
sub send_newsletter {
	my ($CREF,$EMAIL,$CID,$UNIQUEID,$FULLNAME) = @_;

	my $SUBJECT = $CREF->{'SUBJECT'};
	my $PROFILE = $CREF->{'PROFILE'};
	if (not defined $PROFILE) { $PROFILE = 'DEFAULT'; }
	my $TS = time();
	my $MID = $CREF->{'MID'};
	my $USERNAME = $CREF->{'USERNAME'};
	my $PG = "\@CAMPAIGN:".$CREF->{'ID'};

	## this is the code that should do the individual "From" address .. for now 
	## it's hardcoded as newsletter@domain.com
	my $SENDER = '';
	my $BOUNCE = '';
	if (($CID>0) || ($UNIQUEID>0)) {
		my $b36CID = &ZTOOLKIT::base36($CID);
		my $b36CPG = &ZTOOLKIT::base36($CREF->{'ID'});
		my $b36CPNID = &ZTOOLKIT::base36($UNIQUEID);
		$SENDER = "vip-$b36CID\@newsletter.$CREF->{'SENDER'}";
		$BOUNCE = "$b36CID+$b36CPG+$b36CPNID\@newsletter.$CREF->{'SENDER'}";
		}
	else {
		$SENDER = "campaign+$CREF->{'ID'}\@newsletter.$CREF->{'SENDER'}";
		$BOUNCE = $SENDER;
		}

	## set up values for email
	my $msgref = {};
	$msgref->{'zoovy:from'} = $SENDER;
	$msgref->{'zoovy:bounce'} = $BOUNCE;
	$msgref->{'zoovy:title'} = $SUBJECT;
	$msgref->{'zoovy:body'} = $CREF->{'_BODY'};

	$msgref->{'zoovy:company'} = $CREF->{'COMPANY'};
	$msgref->{'zoovy:replyto'} = $CREF->{'REPLY-TO'};

	## in the future: these are the ONLY variables which will be unique per message.	
	my $subref = {};
	$subref->{'%EMAIL%'} = $EMAIL;
   $subref->{'%SUBJECT%'} = $SUBJECT;
   $subref->{'%CAMPAIGN%'} = $PG;
   $subref->{'%CAMPAIGNID%'} = $CREF->{'ID'};
   $subref->{'%USERNAME%'} = $USERNAME;
	$subref->{'%CPNID%'} = $UNIQUEID;
	$subref->{'%CPG_CODE%'} = $CREF->{'CPG_CODE'};
	$subref->{'%CPG_NAME%'} = $CREF->{'NAME'};
	$subref->{'%TRACKING%'} = sprintf("meta=NEWSLETTER&CPN=%d&CPG=%d",$UNIQUEID,$CREF->{'ID'});

	$subref->{'%FULLNAME%'} = $FULLNAME;
	$subref->{'%FIRSTNAME%'} = substr($FULLNAME,0,index($FULLNAME,' '));
	# $subref->{'%VARS%'} = 

	## attempt to send mail	
	my ($result, $warnings) = &CUSTOMER::NEWSLETTER::sendmail(
		$USERNAME,$PROFILE,$EMAIL,$msgref,$subref,$CREF
		);

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	if (($result>0) && ($UNIQUEID>0)) {
		## Remember: campaign 0 is a TEST EMAIL
		my $pstmt = "update CAMPAIGNS set STAT_SENT=STAT_SENT+1 where MID=$MID /* $USERNAME */ and ID=".int($CREF->{'ID'});
		$udbh->do($pstmt);
		}
	## UNIQUEID=0 is test email sent for approval
	## UNIQUEID=-1 is email sent for testing bad/good email addresses for actual campaign send
	##		so for this case, don't update CAMPAIGNS
	elsif(($result>0) && ($UNIQUEID==0)) {
	## update DB with TESTED timestamp
		## get TIMESTAMP for this send, update DB
		my $pstmt = "update CAMPAIGNS ".
						"set TESTED=$TS ".
						"where MID=$MID /* $USERNAME */ ".
						"and ID=".int($CREF->{'ID'});
		$udbh->do($pstmt);
		}
	&DBINFO::db_user_close();
	print STDERR "TESTED updated: $TS\n";

	return($result,$warnings);
	}

## fetches most recent FINISHED newsletter
## http://proshop.zoovy.com/newsletter/3523/0 -- 
## http://proshop.zoovy.com/newsletter/recent
##
sub fetch_recent {
	my ($USERNAME) = @_;

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select id from CAMPAIGNS ".
					"where status = 'FINISHED' ".
					"and merchant = ".$dbh->quote($USERNAME).
					" order by id desc limit 1";

	my $sth = $dbh->prepare($pstmt);	
	$sth->execute();
	my ($id) = $sth->fetchrow();
	$sth->finish();
	&DBINFO::db_user_close();

	return($id);
	}




##
## So .. this returns an array, each position (0..15) is the newsletter #
##		which corresponds to it's bit position in the customer record.
##		the value is a hashref which consists of the corresponding row from the database.
##	NOTE: newsletters which are undefined will be returned as undefined (since perl pads out arrays)
##
sub fetch_newsletter_detail {
	my ($USERNAME, $PRT, $mode) = @_;

	$PRT = int($PRT);

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my %LIST = ();

	my @RESULTS = ();
	foreach (0..15) { $RESULTS[$_] = { ID=>$_, NAME=>"", MODE=>-1 }; }
	my $pstmt = "select * from NEWSLETTERS where MID=$MID /* $USERNAME */ and PRT=$PRT and ID < 16";

	## only show specific mode lists
	## default = 1
	## targeted = 2
	## exclusive = 0
	if ($mode ne '') { $pstmt .= " and mode = ".$udbh->quote($mode); }
	print STDERR $pstmt."\n";
	
	print STDERR "[CUSTOMER::NEWSLETTER::fetch_newsletter_detail] $pstmt\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		$RESULTS[$hashref->{'ID'}] = $hashref;
		}
	$sth->finish();
	&DBINFO::db_user_close();

	if ($RESULTS[1]->{'MODE'} == -1) {
		## Hmm.. this will always initialize the default store newsletter to 1
		$RESULTS[1]->{'ID'} = 1;
		$RESULTS[1]->{'MODE'} = 1;  ## mode: 1 is default
		$RESULTS[1]->{'NAME'} = "Store Newsletter";
		} 

	return(@RESULTS);
	}


##			NOTE: if you pass a newsletter of zero, you'll get back a hashref 
##					keyed by ID e.g. 1..16 with the count as the value.
sub fetch_newsletter_sub_counts {
	my ($USERNAME,$PRT) = @_;

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my %result = ();
	if ($MID>0) {
		require CUSTOMER;
		my $dbh = &DBINFO::db_user_connect($USERNAME);
		my $TB = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
		my $pstmt = "select NEWSLETTER from $TB where NEWSLETTER>0 and MID=$MID /* $USERNAME */ and PRT=$PRT";
		my $sth = $dbh->prepare($pstmt);
		$sth->execute();
		while ( my ($spam) = $sth->fetchrow() ) {
			my $count = 0;
			while ($spam > 0) {
				$count++;
				$result{$count} += ($spam&1);
				$spam = $spam >> 1;
				}
			}
		$sth->finish();
		&DBINFO::db_user_close();
		}
	
	# foreach my $e (1..16) { $result{$e} = $e; }
	return(\%result);
	}

##
## input: MID and newsletter ID
##			NOTE: id is the newsletter id, NOT the campaign.
##				this also assumes the newsletters start at #1 not #0
## returns: number of subscribers for given newsletter (subscription list)
##
sub fetch_newsletter_sub_count{
	my ($USERNAME, $ID) = @_;
	my $COUNT = -1;

	my $BIT = 1 << ($ID-1);
	
	## fetch subscriber count, not sure if DB connection needed

	return($COUNT);
	}	


1;
