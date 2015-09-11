package LISTING::EVENT;

use strict;
use YAML::Syck;
use Data::Dumper;
use Carp;
use lib "/backend/lib";
use base 'LISTING::MSGS';
require PRODUCT;
require DBINFO;
require ZOOVY;
require INVENTORY2;

##
## UUID vs. LISTINGID: UUID is the unique row in the ZOOVY database or tracking database, it is used for operations
##		that cleanup, etc. whereas LISTINGID is the unique id in the remote system (ex; ebay)
##


##
## disposition message/error handling rationale (see LISTING::MSGS.pm)
##

##
## this formats the messages using current style sheet guidelines, suitable for end-user display
##
sub html_result {
	my ($self) = @_;
	
	my $c = '';
	if ($self->has_win()) {
		if ($self->verb() eq 'PREVIEW') {
			$c .= "<div class=\"success\">SUCCESS - no errors encountered</div>";
			}
		elsif (($self->target() =~ /^EBAY/) && ($self->listingid() > 0)) {
			$c .= sprintf("<div class=\"success\">SUCCESS verb:%s event:%d uuid:%d listingid:<a target=\"ebay\" href=\"http://cgi.ebay.com/ws/eBayISAPI.dll?ViewItem&item=%s\">%s</a></div>",$self->verb(),$self->id(),$self->uuid(),$self->listingid(),$self->listingid());
			}
		else {
			$c .= sprintf("<div class=\"success\">SUCCESS verb:%s event:%d uuid:%d listingid:%s</div>",$self->verb(),$self->id(),$self->uuid(),$self->listingid());
			}

		my $fees = '';
		foreach my $msg (@{$self->msgs()}) {
			my ($ref) = &LISTING::MSGS::msg_to_disposition($msg);

			my $msgid = (defined $ref->{'err'})?sprintf("<span class=\"hint\"> %s</span>",$ref->{'err'}):'';
			if (($ref->{'_'} eq 'WARN') && (defined $ref->{'html'})) {
				## some warnings e.g. those returned by eBay contain HTML in them.
				$c .= sprintf("<div class=\"warning\">WARNING %s $msgid</div>",$ref->{'html'});
				}			
			elsif ($ref->{'_'} eq 'WARN') {
				## we should encode other warnings e.g. <Item.Quantity> isn't set, so they display the <>
				$c .= sprintf("<div class=\"warning\">WARNING %s $msgid</div>",&ZOOVY::incode($ref->{'+'}));
				}			
			elsif ($ref->{'_'} eq 'HTML-FEES') {
				$fees .= sprintf("<div class=\"hint\">Fee Summary:<br>$ref->{'+'}</div>");
				}
			
			if ((defined $ref->{'hint'}) && ($ref->{'hint'} ne '')) {
				$c .= "<div class=\"hint\">HINT:$ref->{'hint'}</div>";
				}

			}
		$c .= $fees;

		}
	elsif ($self->has_failed()) {
		foreach my $msg (@{$self->msgs()}) {
			my ($ref) = &LISTING::MSGS::msg_to_disposition($msg);
			next unless (($ref->{'!'} eq 'ERROR') || ($ref->{'_'} eq 'WARN'));
			$c .= "<div class=\"error\">";

			$c .= $ref->{'_'};			
			if ($ref->{'src'}) { $c .= ".".$ref->{'src'}; }

			if ($ref->{'err'}) { $c .= ".".$ref->{'err'}; }
			elsif ($ref->{'code'}) { $c .= ".".$ref->{'code'}; }

			$c .= ": ";
			if ($ref->{'html'}) { $c .= $ref->{'html'}; }
			elsif ($ref->{'+'}) { $c .= &ZOOVY::incode($ref->{'+'}); }

			if ((defined $ref->{'hint'}) && ($ref->{'hint'} ne '')) {
				$c .= "<div class=\"hint\">HINT:$ref->{'hint'}</div>";
				}

			$c .= "</div>";
			}
		}
	else {
		$c = '<pre>INTERNAL ERROR - DID NOT FAIL, DID NOT SUCCEED'.&ZOOVY::incode(&Dumper($self)).'</pre>';
		}

	# $c .= "<div>".&ZOOVY::incode(Dumper($self))."</div>";
	return($c);
	}




##
## EVENT RESULT REGISTRY
##
%LISTING::EVENT::RESULTS = (
	'.0'=>{ txt=>'Success' },
	'TRANSPORT.2001'=>{ txt=>"Found stage RUNNING, recoverable (attempt 1/3)." },
	'TRANSPORT.2002'=>{ txt=>"Found stage RUNNING, recoverable (attempt 2/3)." },
	'TRANSPORT.2003'=>{ txt=>"Found stage RUNNING, recoverable (attempt 3/3)." },
	'TRANSPORT.3000'=>{ txt=>"Found stage RUNNING, not-recoverable (too many attempts)." },
	);



##
##
##
sub app { return($_[0]->{'REQUEST_APP'}); }
sub batchid { return($_[0]->{'REQUEST_BATCHID'}); }


##
## this is a lookup table for verbs.
##
sub normalize_verb {
	my ($VERB) = @_;

	if ($VERB eq 'REMOVE-LISTING') { $VERB = 'END'; }
	if ($VERB eq 'REMOVE') { $VERB = 'END'; }
	if ($VERB eq 'END') { $VERB = 'END'; }
	if ($VERB eq 'REFRESH') { $VERB = 'UPDATE-LISTING'; }

	return($VERB);
	}


##
## takes several different (possible) target names
##		carps if an unknown target was sent in.
##
sub normalize_target {
	my ($TARGET) = @_;

	if ($TARGET eq 'EBAYA') { $TARGET = 'EBAY.AUCTION'; }
#	if ($TARGET eq 'EBAYS') { $TARGET = 'EBAY.STORE'; }
	if ($TARGET eq 'EBAYFP') { $TARGET = 'EBAY.FIXED'; }
	if ($TARGET eq 'EBAY.AUCTN') { $TARGET = 'EBAY.AUCTION'; }
	if ($TARGET eq 'EBAY.AUCTION') { $TARGET = 'EBAY.AUCTION'; }
	if ($TARGET eq 'EBAY.SYND') { $TARGET = 'EBAY.SYND'; }
	if ($TARGET eq 'EBAY.STORE') { $TARGET = 'EBAY.SYND'; }
	if ($TARGET eq 'EBAY.OTHER') { $TARGET = 'EBAY.SYND'; }	## total guess
	if ($TARGET eq 'EBAY.SYNDICATION') { $TARGET = 'EBAY.SYND'; }	## total guess
	if ($TARGET eq 'EBAY.LISTING') { $TARGET = 'EBAY.SYND'; }	## total guess

	$TARGET = uc($TARGET);
	if ($TARGET eq 'EBAY') {
		## generic target for updating ebay listings.
		}
	elsif ($TARGET eq 'EBAY.FIXED') {
		}
	elsif ($TARGET eq 'EBAY.SYND') {
		}
#	elsif ($TARGET eq 'EBAY.STORE') {
#		}
	elsif ($TARGET eq 'EBAY.AUCTION') {
		}
	else {
		$TARGET = undef;
		}

	return($TARGET);
	}



##
## status can be: 'PENDING','RUNNING','FAIL-SOFT','FAIL-FATAL','SUCCESS','SUCCESS-WARNING'
## src can be: 'PREFLIGHT','ZLAUNCH','TRANSPORT','MKT','MKT-LISTING','MKT-ACCOUNT'
## error codes - those should be listed in the RESULTS table above.
##	msg: is something specific to the error.
##
sub set_disposition {
	my ($self,$result,$src,$code,$msg) = @_;

	if ((not defined $src) && (not defined $code) && (not defined $msg)) {
		## src,code,msg must all be set, or NOT this is acceptable
		$src = undef;
		$code = 0;
		$msg = '';
		}
	elsif ((defined $src) && (defined $code) && (defined $msg)) {
		## all values are set.
		}
	elsif ((defined $src) || (defined $code) || (defined $msg)) {
		## error is self explanatory, but not fatal.
		warn "You must set seting src/code/msg at the same time - RESULT was not saved.";
		print Carp::confess();
		($src,$code,$msg) = (undef,0,'');
		}

	if ($src =~ /MKT/) {
		## marketplace error codes aren't defined in our little table.
		}
	elsif (not defined $LISTING::EVENT::RESULTS{sprintf("%s.%d",$src,$code)}) {
		warn "Requested update to non-registered SRC.CODE result.";
		}

	if ($result ne $self->{'RESULT'}) {
		$self->{'RESULT'} = $result;

		if (defined $src) {
			$self->{'RESULT_ERR_SRC'} = $src;
			$self->{'RESULT_ERR_CODE'} = $code;
			$self->{'RESULT_ERR_MSG'} = $msg;
			}
		else {
			$self->{'RESULT_ERR_SRC'} = undef;
			$self->{'RESULT_ERR_SRC'} = '0';
			$self->{'RESULT_ERR_MSG'} = '';
			}

		my $USERNAME = $self->username();
		my $MID = $self->mid();
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "update LISTING_EVENTS set RESULT=".$udbh->quote($self->{'RESULT'});
		if (defined $src) {
			$pstmt .= ",RESULT_ERR_SRC=".$udbh->quote($self->{'RESULT_ERR_SRC'}).
				",RESULT_ERR_CODE=".$udbh->quote($self->{'RESULT_ERR_CODE'}).
				",RESULT_ERR_MSG=".$udbh->quote($self->{'RESULT_ERR_MSG'});
			}
		$pstmt .= "where MID=$MID /* $USERNAME */ and ID=".int($self->id());
		$udbh->do($pstmt);
		&DBINFO::db_user_close();	
		}

	return();
	}


##
## eventually we might do some basic logic which verifies this is a valid stage, etc.
##	this should be used instead of calling "result" directly, especially during processing.
##
sub result { my ($self) = @_;	return($self->{'RESULT'}); }


##
## as long as the listing has the right quantity in itself, this will update the inventory
##
#sub update_reserve {
#	my ($self,$QTY,$EXPIRES_GMT) = @_;
#
#	if (defined $QTY) {
#		$self->{'QTY'} = $QTY;
#		}
#
#	my ($RESULT_ID) = &INVENTORY::set_other($self->username(),"EBAY",$self->sku(),$self->qty(),'expirests'=>$EXPIRES_GMT,'uuid'=>$self->listingid());
#	&INVENTORY::update_reserve($self->username(),$self->sku(),4);			
#	require INVENTORY2;
#	&INVENTORY2->new($self->username())->skuinvcmd($self->sku(),'UPDATE-RESERVE');
#
#	return($RESULT_ID);
#	}
#

##
##	after a launch, we record the UUID of the listing (usually it's ROW ID in the database) as the target UUID
##
sub set_target {
	my ($self,%vars) = @_;

	my $UUID = $vars{'UUID'};
	my $LISTINGID = $vars{'LISTINGID'};
	my %db = ();
	if (defined $vars{'UUID'}) { 
		$db{'TARGET_UUID'} = $vars{'UUID'}; 
		$self->{'TARGET_UUID'} = $vars{'UUID'};
		}
	if (defined $vars{'LISTINGID'}) { 
		$db{'TARGET_LISTINGID'} = $vars{'LISTINGID'}; 
		$self->{'TARGET_LISTINGID'} = $vars{'LISTINGID'};
		}
	$db{'ID'} = $self->id();

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my ($pstmt) = &DBINFO::insert($udbh,'LISTING_EVENTS',\%db,sql=>1,update=>2,key=>['ID']);
	print STDERR $pstmt."\n";
	my ($fail) = $udbh->do($pstmt);
	$self->{'TARGET_UUID'} = $UUID;
	&DBINFO::db_user_close();
	return($fail);
	}


##
## loads the appropriate target and dispatches to it.
##
sub dispatch {
	my ($self,$srcudbh,$P) = @_;

	my $udbh = $srcudbh;
	if (not defined $udbh) {
		$udbh = &DBINFO::db_user_connect($self->username());
		}

	my $MSGS = $self->msgs();

	my $VERB = $self->verb();
	if (defined $P) {
		}
	elsif ($VERB eq 'CLEANUP') {
		## prodref is not required for CLEANUP, otherwise they can't cleanup if they deleted the product.
		}
	elsif (not defined $P) {
		($P) = PRODUCT->new($self->username(),$self->sku());
		if (not defined $P) {
			push @{$MSGS}, sprintf("ERROR|src=PREFLIGHT|+SKU[%s] is not valid or could not be loaded from database",$self->sku());
			}
		}

#	if ($VERB eq 'CLEANUP') {
#		}
#	elsif (scalar(keys %{$prodref})<10) {
#		## simple sanity check
#		push @{$MSGS}, sprintf("ERROR|src=PREFLIGHT|+SKU[%s] is corrupted or deleted.",$self->sku());
#		}

	my $TARGET = $self->target();

	## we will whitelist verbs here .. eventually these should probably move out into the individual modules.
	if ($self->has_failed()) {
		## shit happened.
		}
	elsif (($VERB eq 'INSERT') && ($self->listingid()>0)) { if
		($self->{'ATTEMPTS'}>0) {
			push @{$MSGS}, "WARN|src=PREFLIGHT|code=201|+RETRY NOTICE: This is our ($self->{'ATTEMPTS'} attempt.";	
			}
		else {
			push @{$MSGS}, "ERROR|src=PREFLIGHT|code=230|+Sorry, but you may not specify a LISTINGID with VERB=INSERT";	
			}
		}
	elsif ($VERB eq 'END') {
		## this is okay, we can END with either a UUID or LISTINGID
		if (($self->listingid()>0) || ($self->uuid()>0)) {}
		else {
			push @{$MSGS}, "ERROR|src=PREFLIGHT|code=240|+Sorry, but you must specify either a UUID or LISTINGID to END an event";
			}
		}
	elsif (($VERB =~ /^(REMOVE-LISTING|UPDATE-LISTING)$/) && ($self->listingid()==0)) {
		push @{$MSGS}, "ERROR|src=PREFLIGHT|code=202|+Sorry, but you must specify a LISTINGID with VERB=$VERB";
		}
	elsif (($VERB =~ /^(REMOVE-SKU)$/) && ($self->sku() eq '')) {
		push @{$MSGS}, "ERROR|src=PREFLIGHT|code=210|+Sorry, but you must specify a LISTINGID with VERB=$VERB";
		}
	elsif ($VERB !~ /^(PREVIEW|INSERT|END|REMOVE-LISTING|REMOVE-SKU|UPDATE-LISTING)$/) {
		## note: END means detect REMOVE-LISTING and/or REMOVE-SKU automatically.
		push @{$MSGS}, "ERROR|src=PREFLIGHT|code=220|+Invalid VERB=$VERB";
		}

	if ($self->has_failed()) {
		## shit happened.
		}
	elsif (($TARGET eq 'EBAY') || ($TARGET eq 'EBAY.AUCTION') || ($TARGET eq 'EBAY.FIXED') || ($TARGET eq 'EBAY.SYND')) {
		if (($self->target() eq 'EBAY') && ($VERB eq 'INSERT')) {
			push @{$MSGS}, "ERROR|src=PREFLIGHT|code=200|+Target[EBAY] is not valid for insertions (only updates)";
			}
		else {
			require LISTING::EBAY;
			LISTING::EBAY::event_handler($udbh,$self,$P);
			}
		}
	#elsif ($TARGET eq 'OS.AUCTION') {
	#	require LISTING::OVERSTOCK;
	#	LISTING::OVERSTOCK::event_handler($udbh,$self,$prodref);
	#	}
	else {
		push @{$MSGS}, "ERROR|+Unknown Target";
		}

	print STDERR Dumper(\@{$MSGS})."\n";


	if (scalar(@{$MSGS})==0) {
		## shit happened.
		push @{$MSGS}, "ERROR|+No MSGS were returned for TARGET:$TARGET";
		}
	elsif ($self->has_failed()) {
		}
	elsif ($self->has_win()) {
		}
	else {
		push @{$MSGS}, "ERROR|+Could not ascertain win/fail status of event.";
		}

	##
	##

	##
	## we just make a quick log to ensure we're sane.
	##
	my $ts = time();
	open F, ">>/tmp/event.log";
	foreach my $msg (@{$MSGS}) {
		print F sprintf("%d\t%d\t%s\n",$self->id(),$ts,$msg);
		}
	close F;

	my %UPDATES = ();
	$UPDATES{'ID'} = $self->id();
	$UPDATES{'MID'} = $self->mid();
	$UPDATES{'PROCESSED_GMT'} = $ts;

	my $msgresult = $self->whatsup();
	print STDERR Dumper($msgresult);

	$UPDATES{'RESULT_ERR_CODE'} = int($msgresult->{'code'});
	$UPDATES{'RESULT_ERR_MSG'} = $msgresult->{'+'};
	if ((defined $msgresult->{'id'}) && ($msgresult->{'id'}>0)) {
		$UPDATES{'TARGET_LISTINGID'} = $msgresult->{'id'};
		}
	if ((defined $msgresult->{'uuid'}) && ($msgresult->{'uuid'}>0)) {
		$UPDATES{'TARGET_UUID'} = $msgresult->{'uuid'};
		}

	if ($msgresult->{'!'} eq 'SUCCESS') {
		## Yay we launched or at least we're planning on it.
		$UPDATES{'RESULT'} = "SUCCESS";
		$UPDATES{'RESULT_ERR_SRC'} = '';
		if ($UPDATES{'_'} eq 'SUCCESS-WARNING') { $UPDATES{'RESULT'}='SUCCESS-WARNING'; }
		elsif (($UPDATES{'RESULT_ERR_CODE'}>0) && ($UPDATES{'RESULT_ERR_MSG'} ne '')) { $UPDATES{'RESULT'}='SUCCESS-WARNING'; }
		}
	else {
		$UPDATES{'RESULT_ERR_SRC'} = (defined $msgresult->{'src'})?$msgresult->{'src'}:'TRANSPORT';
		if (not $UPDATES{'RESULT_ERR_SRC'} =~ m/^(PREFLIGHT|ZLAUNCH|TRANSPORT|MKT|MKT-LISTING|MKT-ACCOUNT)$/) {
			warn "Unknown RESULT_ERR_SRC:$UPDATES{'RESULT_ERR_SRC'}";
			$UPDATES{'RESULT_ERR_SRC'} = 'TRANSPORT';
			}
		## Bummer, something bad happened.
		$UPDATES{'RESULT'} = 'FAIL-SOFT';
		if ($UPDATES{'RESULT_ERR_SRC'} eq 'MKT-ACCOUNT') { $UPDATES{'RESULT'} = 'FAIL-FATAL'; }
		}

	if (($self->id() == 0) && ($self->verb() eq 'PREVIEW')) {
		## previews' don't generate actual events.
		}
	else {
		my ($pstmt) = "/* LISTING::EVENT->dispatch() */ ".&DBINFO::insert($udbh,'LISTING_EVENTS',\%UPDATES,update=>2,key=>['ID','MID'],sql=>1);
		print STDERR $pstmt."\n";
		if (not $udbh->do($pstmt)) {
			## something bad
			}
		}
	foreach my $k (keys %UPDATES) { $self->{$k} = $UPDATES{$k}; }

	if (not defined $srcudbh) {
		&DBINFO::db_user_close();
		}
	return();	
	}


##
## a listing event is basically an object wrapper around the LISTING_EVENTS table 
##	note: we're gonna assume you did your checking and your asking for a valid LISTING_EVENT
##	if you don't get back a ref($VAR1)eq'LISTING::EVENT', 
##	then we're gonna return undef and the REASON is because your input parameters were CRAP 
##	so mayzbe you wanna fix that shit - yo.
##
sub new {
	my ($class,%options) = @_;

	## there are basically three ways to instantiate this object -- one is to pass a hashref
	##		called "DBREF"=>{}  -- which is a select from the LISTING_EVENTS table
	## the second is to pass 
	##		USERNAME=>,LEID=>Listing Event ID
	##	the third.. we haven't figured out yet. it's a secret.

	my $self = {};

	if (defined $options{'@MSGS'}) {
		$self->{'@MSGS'} = $options{'@MSGS'};
		}

	if (defined $options{'DBREF'}) {
		$self = $options{'DBREF'};
		}
	elsif ((defined $options{'USERNAME'}) && (defined $options{'LEID'})) {
		my $USERNAME = $options{'USERNAME'};
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select * from LISTING_EVENTS where MID=$MID /* $USERNAME */ and ID=".int($options{'LEID'});
		($self) = $udbh->selectrow_hashref($pstmt);
		&DBINFO::db_user_close();
		}
	elsif ((defined $options{'USERNAME'}) && (defined $options{'PRT'}) && ($options{'VERB'} eq 'PREVIEW')) {
		$self->{'USERNAME'} = $options{'USERNAME'};
		$self->{'LUSER'} = (defined $options{'LUSER'})?$options{'LUSER'}:'?';
		$self->{'MID'} = &ZOOVY::resolve_mid($options{'USERNAME'});
		$self->{'PRT'} = $options{'PRT'};
		$self->{'PROFILE'} = $options{'PROFILE'};
		$self->{'SKU'} = $options{'SKU'};
		$self->{'PRODUCT'} = $options{'PRODUCT'}; 
		## interchange SKU and PRODUCT 
		if ((not defined $self->{'PRODUCT'}) && (defined $self->{'SKU'})) { ($self->{'PRODUCT'}) = &PRODUCT::stid_to_pid($self->{'SKU'}); }
		if ((not defined $self->{'SKU'}) && (defined $self->{'PRODUCT'})) { $self->{'SKU'} = $self->{'PRODUCT'}; }

		$self->{'VERB'} = $options{'VERB'};
		$self->{'TARGET'} = $options{'TARGET'};
		$self->{'%DATA'} = $options{'%DATA'};
		}
		
	elsif (
		((defined $options{'USERNAME'}) && (defined $options{'PRT'}) && ($options{'VERB'} eq 'INSERT')) ||
		## insert doesn't require UUID - since it's a new record.
		((defined $options{'USERNAME'}) && (defined $options{'PRT'}) && ($options{'TARGET_UUID'})) 
		## this handles all other event types which *MUST* have a UUID
		) {
		if (not defined $options{'SKU'}) {
			}
		else {
			($options{'PRODUCT'}) = &PRODUCT::stid_to_pid($options{'SKU'});
			}

		if (not defined $options{'QTY'}) {
			}

		$self->{'USERNAME'} = $options{'USERNAME'};
		$self->{'LUSER'} = ($options{'LUSER'})?$options{'LUSER'}:'',
		$self->{'MID'} = &ZOOVY::resolve_mid($options{'USERNAME'});
		$self->{'PRT'} = $options{'PRT'};
		if (defined $options{'PROFILE'}) {
			$self->{'%DATA'}->{'zoovy:profile'} = $options{'PROFILE'};
			}
		$self->{'PRODUCT'} = $options{'PRODUCT'};
		$self->{'SKU'} = $options{'SKU'};
		$self->{'VERB'} = $options{'VERB'};
		if ($self->{'VERB'} eq '') {
			## we should probably whitelist verbs here!?
			warn "VERB was not set, this probably won't go well";
			}

		if (defined $options{'TARGET'}) {
			$options{'TARGET'} = &LISTING::EVENT::normalize_target($options{'TARGET'});
			}
		$self->{'TARGET'} = $options{'TARGET'};
		if (not defined $self->{'TARGET'}) {
			warn "INVALID (undef) TARGET\n";
			}

		if (defined $options{'TARGET_UUID'}) {
			$self->{'TARGET_UUID'} = $options{'TARGET_UUID'};		
			}
		if (defined $options{'TARGET_LISTINGID'}) {
			$self->{'TARGET_LISTINGID'} = $options{'TARGET_LISTINGID'};		
			}

		$self->{'QTY'} = int($options{'QTY'});
		if ((defined $options{'%DATA'}) && (ref($options{'%DATA'}) eq 'HASH') && (scalar(keys %{$options{'%DATA'}})>0)) {
			$self->{'REQUEST_DATA'} = YAML::Syck::Dump($options{'%DATA'});
			}
		$self->{'CREATED_GMT'} = time();
		if ((defined $options{'CREATED_GMT'}) && ($options{'CREATED_GMT'} > $self->{'CREATED_GMT'})) {
			$self->{'CREATED_GMT'} = $options{'CREATED_GMT'};
			}
		$self->{'LAUNCH_GMT'} = time();
		if ((defined $options{'LAUNCH_GMT'}) && ($options{'LAUNCH_GMT'} > $self->{'LAUNCH_GMT'})) {
			$self->{'LAUNCH_GMT'} = $options{'LAUNCH_GMT'};
			}

		if ($self->{'LAUNCH_GMT'}<$self->{'CREATED_GMT'}) {
			## hmm.. we've been created ahead of the LAUNCH_GMT .. that doesn't make sense, so we'll fix that up.
			$self->{'LAUNCH_GMT'} = $self->{'CREATED_GMT'};
			}

		$self->{'REQUEST_APP'} = $options{'REQUEST_APP'};
		if (not defined $self->{'REQUEST_APP'}) {
			warn "REQUEST_APP is undef\n";
			}
		$self->{'REQUEST_APP_UUID'} = $options{'REQUEST_APP_UUID'};
		if (not defined $self->{'REQUEST_APP'}) {
			warn "REQUEST_APP_UUID is undef\n";
			}
		
		if (defined $options{'REQUEST_BATCHID'}) {
			$self->{'REQUEST_BATCHID'} = $options{'REQUEST_BATCHID'};
			}

		if ($options{'LOCK'}) {
			$self->{'RESULT'} = 'RUNNING';
			$self->{'LOCK_GMT'} = $^T;
			$self->{'LOCK_ID'} = $self->{'MID'};
			$self->{'RESULT_ERR_SRC'} = 'PREFLIGHT';
			$self->{'RESULT_ERR_CODE'} = 999;
			$self->{'RESULT_ERR_MSG'} = "Locked by Insert";
			}
		else {
			$self->{'RESULT'} = 'PENDING';
			$self->{'LOCK_GMT'} = 0;
			$self->{'LOCK_ID'} = 0;
			}

		my ($udbh) = &DBINFO::db_user_connect($self->{'USERNAME'});

		my $MSGS = $self->{'@MSGS'};
		delete $self->{'@MSGS'};
		my ($pstmt) = &DBINFO::insert($udbh,'LISTING_EVENTS',$self,'verb'=>'insert','sql'=>1);
		if (defined $MSGS) { $self->{'@MSGS'} = $MSGS; }
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		$self->{'ID'} = &DBINFO::last_insert_id($udbh);
		&DBINFO::db_user_close();
		if ($self->{'ID'}==0) {
			$self->{'RESULT_ERR_CODE'} = '998';
			$self->{'RESULT_ERR_MSG'} = "Could not insert into db";
			}
		else {
			$self->{'RESULT_ERR_CODE'} = 0;
			}
		}
	else {
		Carp::croak("called LISTING::EVENT->new without proper parameters USERNAME=$options{'USERNAME'} PRT=$options{'PRT'} VERB=$options{'VERB'} TARGET_UUID=$options{'TARGET_UUID'}");
		}

	if (defined $self) {

		if ((defined $self->{'REQUEST_DATA'}) && ($self->{'REQUEST_DATA'} ne '')) {
			$self->{'%DATA'} = YAML::Syck::Load($self->{'REQUEST_DATA'});
			}

		if (defined $options{'@MSGS'}) {
			$self->{'@MSGS'} = $options{'@MSGS'};
			}

		bless $self, 'LISTING::EVENT';
		
		if ($self->{'RESULT_ERR_CODE'}>0) {
			$self->pooshmsg(sprintf("ERROR|err=%s|src=%s|+%s",$self->{'RESULT_ERR_CODE'},$self->{'RESULT_ERR_SRC'},$self->{'RESULT_ERR_MSG'}));
			}
		return($self);
		}
	}

## some utility functions
sub id { return($_[0]->{'ID'}); }
sub username { return(lc($_[0]->{'USERNAME'})); }
sub luser { return($_[0]->{'LUSER'}); }
sub listingid { return($_[0]->{'TARGET_LISTINGID'}); }
sub uuid { return($_[0]->{'TARGET_UUID'}); }
sub mid { return($_[0]->{'MID'}); }
sub pid { return($_[0]->{'PRODUCT'}); }
sub sku { return($_[0]->{'SKU'}); }
sub prt { return($_[0]->{'PRT'}); }
sub qty { return($_[0]->{'QTY'}); }
sub verb { return($_[0]->{'VERB'}); }
sub target { return(LISTING::EVENT::normalize_target($_[0]->{'TARGET'})); }
## NOTE: dataref routine ALWAYS returns a empty hashref if %DATA is not populated.
sub dataref {
	if (ref($_[0]->{'%DATA'}) ne 'HASH') { $_[0]->{'%DATA'} = {}; }
	return($_[0]->{'%DATA'});
	} 
sub set_dataref {
	my ($self,$ref) = @_;
	$self->{'%DATA'} = $ref;
	$self->{'REQUEST_DATA'} = YAML::Syck::Dump($ref);

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $pstmt = "update LISTING_EVENTS set REQUEST_DATA=".$udbh->quote($self->{'REQUEST_DATA'})." where MID=".int($self->mid())." /* ".$self->username()." */ and ID=".int($self->id());
	print STDERR $pstmt."\n";
	if (not $udbh->do($pstmt)) {
		$self->poosh("ISE","DB ERROR - Could not update LISTING_EVENTS REQUEST_DATA");
		}
	&DBINFO::db_user_close();
	}
sub processed_gmt { return($_[0]->{'PROCESSED_GMT'}); }


##
## the term /disposition/ is shorthand for 3 (or sometimes 4) different values
##		RESULT + RESULT_ERR_SRC + RESULT_ERR_CODE + optional message.
##
sub disposition { 
	return(
	$_[0]->{'RESULT'},
	$_[0]->{'RESULT_ERR_SRC'},
	$_[0]->{'RESULT_ERR_CODE'},
	$_[0]->{'RESULT_ERR_MSG'}); 
	}

#sub resolve_qty { 
#	my ($self) = @_;
#
#	if ($self->{'QTY'} eq 'ALL') {
#		return( INVENTORY2->new($self->username())->summary('SKU'=>$self->sku(),'SKU/VALUE'=>'AVAILABLE') ); 
#		#my ($ONHANDREF) = &INVENTORY::fetch_incrementals($self->username(),[$self->sku()]);
#		#return($ONHANDREF->{$self->sku()});		
#		}
#	elsif ($self->{'QTY'} eq 'USEPRODUCT') {
#		die("USEPRODUCT not working (yet)");
#		}
#	elsif ($self->{'QTY'} =~ /^[-]?[\d]+$/) {
#		return(int($self->{'QTY'}));
#		}
#	return(-1);
#	}


##
## listing event QTY fields are special. 
##
sub validate_qty {
	my ($qty) = @_;

	if ($qty =~ /^[\-]?[\d]+/) {
		return(1);
		}
	elsif ($qty eq 'ALL') {
		return(1);
		}
	elsif ($qty eq 'USEPRODUCT') {
		return(1);
		}

	return(0); # failed
	}

##
## a merge requires three things:
##
#sub merge {
#	my ($self,$FIELDSMAP,$prodref,$nsref) = @_;
#
#	my @LOG = ();
#
#	my %data = ();
#	foreach my $ref (@{$FIELDSMAP}) {
#		my $attrib = $ref->{'id'};
#		my $val = undef;
#
#		if ((not defined $val) && (defined $self->{'%DATA'}->{$attrib})) {
#			## EVENT data always wins (if it's set)
#			$val = $self->{'%DATA'}->{$attrib};
#			push @LOG, "DEBUG|+$attrib loaded from event";
#			if ((defined $val) && (defined $ref->{'properties'}) && ($ref->{'properties'}&1) && ($val eq '')) { 
#				push @LOG, "DEBUG|+EVENT $attrib was reset to undef because it was blank";
#				$val = undef; 
#				}
#			}
#
#		if ((not defined $val) && (defined $prodref->{$attrib})) {
#			## Then PRODUCT data
#			$val = $prodref->{$attrib};
#			push @LOG, "DEBUG|+$attrib loaded from product";
#			if ((defined $val) && (defined $ref->{'properties'}) && ($ref->{'properties'}&1) && ($val eq '')) { 
#				push @LOG, "DEBUG|+PRODUCT $attrib was reset to undef because it was blank";
#				$val = undef; 
#				}
#			}
#
#		if ((not defined $val) && ($ref->{'ns'} eq 'profile') && (defined $nsref->{$attrib})) {
#			## Then PROFILE data
#			$val = $nsref->{$attrib};
#			push @LOG, "DEBUG|+$attrib loaded from profile";
#			if ((defined $val) && (defined $ref->{'properties'}) && ($ref->{'properties'}&1) && ($val eq '')) { 
#				push @LOG, "DEBUG|+PROFILE $attrib was reset to undef because it was blank";
#				$val = undef; 
#				}
#			}
#
#		
#		if ((not defined $val) && ($ref->{'loadfrom'})) {
#			foreach my $lattrib (split(/,/,$ref->{'loadfrom'})) {
#				if (defined $prodref->{$lattrib}) {
#					## note: at some point we might need to run a transformation routine, which could be an 
#					##			anonymous sub embedded in @EBAY_FIELDS
#					$val = $prodref->{$lattrib};
#					push @LOG, "DEBUG|+$attrib loaded from product $lattrib";
#					}
#				elsif ($ref->{'ns'} eq 'product') {
#					## if an attribute is in product namespace, NEVER attempt to load from profile.
#					}
#				elsif (defined $nsref->{$lattrib}) {
#					## note: at some point we might need to run a transformation routine, which could be an 
#					##			anonymous sub embedded in @EBAY_FIELDS
#					$val = $nsref->{$lattrib};
#					push @LOG, "DEBUG|+$attrib loaded from profile $lattrib";
#					}
#				}			
#			}
#
#		if ((not defined $val) && ($ref->{'legacy'})) {
#			## load from legacy
#			foreach my $lattrib (split(/,/,$ref->{'legacy'})) {
#				if (defined $val) {
#					## we already have a value, no need to look for another.
#					}
#				elsif (defined $prodref->{$lattrib}) {
#					## note: at some point we might need to run a transformation routine, which could be an 
#					##			anonymous sub embedded in @EBAY_FIELDS
#					$val = $prodref->{$lattrib};
#					push @LOG, "DEBUG|+$attrib loaded from legacy product $lattrib";
#					}
#				elsif ($ref->{'ns'} eq 'product') {
#					## if an attribute is in product namespace, NEVER attempt to load from profile.
#					}
#				elsif (defined $nsref->{$lattrib}) {
#					## note: at some point we might need to run a transformation routine, which could be an 
#					##			anonymous sub embedded in @EBAY_FIELDS
#					$val = $nsref->{$lattrib};
#					push @LOG, "DEBUG|+$attrib loaded from legacy profile $lattrib";
#					}
#				}
#			}
#
#		if (defined $val) {
#			## good shit.
#			$data{$attrib} = $val;
#			}
#		elsif ($ref->{'required'} && ($ref->{'ns'} eq 'product')) {
#			## throw an error!
#			push @LOG, "ERROR|+Could not find required product attribute $attrib ($ref->{'hint'})";
#			}
#		elsif ($ref->{'required'} && ($ref->{'ns'} eq 'profile')) {
#			## throw an error!
#			push @LOG, "ERROR|+Could not find required profile $attrib ($ref->{'hint'})";
#			}
#		elsif ($ref->{'required'}) {
#			## throw an error!
#			push @LOG, "ERROR|+Could not find required $attrib ($ref->{'hint'})";
#			}
#		elsif (not $ref->{'required'}) {
#			## i guess we can ignore this.
#			push @LOG, "DEBUG|+$attrib was not found, but was not required and can safely be ignored.";
#			}
#		else {
#			## never reached.
#			push @LOG, "ERROR|+Something horrible happened in LISTING::EVENT->merge";
#			}
#		}
#
#	return(\%data,\@LOG);
#	}
#

1;
