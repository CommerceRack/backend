package LISTING::EBAY;

use IO::String;
use LWP::Simple;
use XML::SAX::Simple;
use YAML::Syck;
use strict;

use lib "/backend/lib";
require EBAY2::PROFILE;
require ZTOOLKIT;
require SITE;
require XMLTOOLS;


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
		die("no longer supported");
		#my $USERNAME = $options{'USERNAME'};
		#my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		#my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		#my $pstmt = "select * from LISTING_EVENTS where MID=$MID /* $USERNAME */ and ID=".int($options{'LEID'});
		#($self) = $udbh->selectrow_hashref($pstmt);
		#&DBINFO::db_user_close();
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
##
## IS_ENDED
##		1 = ended normally
##		55 = monitor.pl has determined it exists in the database, but not on ebay
##		56 = monitor.pl ended because inventory is too low 
##		66 = detected unsuccessfully aborted launch (ise, should never happen) - detected in syndication
##		77 = successfully cleaned up aborted during 'INSERT' event in LISTING::EBAY
##


##
## this is also by EBAY2::sync_options (called by EBAY2::sync_inventory)
##
sub add_options_to_request {
	my ($P,$api,$MSGSREF) = @_;

	my @LINES = ();
	my $pogcount = 0;
	
	my $picxml = '';
	## PICTURES:
	## http://developer.ebay.com/DevZone/XML/docs/Reference/eBay/AddFixedPriceItem.html#Request.Item.ItemCompatibilityList
	## 
	foreach my $pog (@{$P->fetch_pogs()}) {
		my $skip = 0;
		if ($pog->{'type'} eq 'attribute') {
	  		$skip++; push @{$MSGSREF}, "WARN|+Skipping option $pog->{'id'} because it's an attribute";
			}

		# always skip
		if ($pog->{'inv'} == 0) {
			$skip++; push @{$MSGSREF}, "WARN|+Skipping option $pog->{'id'} because it's non inventoriable";
			}
		next if ($skip);

		my $nvlxml = '';		## namevalue 

		$nvlxml .= '<NameValueList>';	
		my $varname = ($pog->{'ebay'})?$pog->{'ebay'}:$pog->{'prompt'};
		$nvlxml .= sprintf("<Name>%s</Name>",&ZOOVY::incode($varname));
	
		my @PAIRS = ();		
		my @IMAGES = ();
		foreach my $optx (@{$pog->{'@options'}}) {
			# my $mref = &POGS::parse_meta($optx->{'m'});
			push @PAIRS, { 'pogid'=>$pog->{'id'}, 'varname'=>$varname, 'optid'=>$optx->{'v'}, 'optprompt'=>$optx->{'prompt'}, 'optpricemod'=>$optx->{'p'} };
			$nvlxml .= sprintf("<Value>%s</Value>",&ZOOVY::incode($optx->{'prompt'}));
			if ($optx->{'img'} ne '') {
				push @IMAGES, [ $optx->{'prompt'}, $optx->{'img'} ];
				}
			}
		$nvlxml .= "</NameValueList>";

		if ($picxml ne '') {
			## we already have variations with images.
			}
		elsif (scalar(@IMAGES)>0) {
			$picxml .= '<VariationSpecificName>'.&ZOOVY::incode($varname).'</VariationSpecificName>';
			foreach my $imgset (@IMAGES) {
				my ($varvalue,$imgname) = @{$imgset};
				$picxml .= '<VariationSpecificPictureSet>';
					$picxml .= '<VariationSpecificValue>'.&ZOOVY::incode($varvalue).'</VariationSpecificValue>';
					$picxml .= '<PictureURL>'.&ZOOVY::mediahost_imageurl($P->username(),$imgname,0,0,'FFFFFF',0,'jpg').'</PictureURL>';
				$picxml .= "</VariationSpecificPictureSet>\n";
				}
			}
			
		if (scalar(@PAIRS)==0) {
			push @{$MSGSREF}, "WARNING|+Option group [$pog->{'id'}] $pog->{'prompt'} did not appear to have any options"; 
			}
		elsif (scalar(@LINES)==0) {
			## first option group
			foreach my $pref (@PAIRS) {
				push @LINES, [ $pref ];
				}
			}
		else {
			## second or more option groups
			my @NEWLINES = ();
			foreach my $lref (@LINES) {
				foreach my $pref (@PAIRS) {
						push @NEWLINES, [ @{$lref}, $pref ];
						}
					}
				@LINES = @NEWLINES;
				}
	
			$api->{"Item.Variations.VariationSpecificsSet.$pogcount*"} = $nvlxml;
			$pogcount++;
			}
	
	my ($INVSUMMARY) = INVENTORY2->new($P->username())->summary('@PIDS'=>[ $P->pid() ]);
	#my ($ONHANDREF,$RESREF) = &INVENTORY::fetch_incrementals($P->username(),[ $P->pid() ],undef);
	# <VariationSpecificPictureSet>
	#		<PictureURL></PictureURL>
	#		<VariationSpecificValue>Red</VariationSpecificValue>
	#		<VariationSpecificName>Color<VariationSpecificName>
	# </VariationSpecificPictureSet>
	#foreach my $imgset (@IMAGES) {
	#	## NOTE: in the future if we only have one option group, we also use the SKU images.
	#	my ($varname,$varvalue,$imgname) = @{$imgset};
	#	}
	if ($picxml ne '') {
		$api->{'Item.Variations.Pictures.picxml*'} = $picxml;
		}
	
	#print Dumper($api);
	#die();

	# push @{$MSGSREF}, "ERROR|Fuck you rich";
	my $vxml = '';
	use Data::Dumper; $vxml = "<!-- ".Dumper($INVSUMMARY)." -->";
	my $HAD_INVENTORY = 0;
	foreach my $ar (@LINES) {
	
		my %v = ();
		#my $totalprice = $P->fetch('ebay:fixed_price');
		#if ((not defined $totalprice) || ($totalprice == -1)) {
		#	$totalprice = 0; ## $P->fetch('zoovy:base_price');
		#	}

		my $i = 0;
		my $SKU = $P->pid();
		foreach my $ref (@{$ar}) {
			$SKU = sprintf("%s:%s%s",$SKU,$ref->{'pogid'},$ref->{'optid'});
			}

		my $totalprice = $P->skufetch($SKU,'sku:price');
		foreach my $ref (@{$ar}) {
			$v{"Variation.VariationSpecifics.NameValueList$i*"} = sprintf("<NameValueList><Name>%s</Name><Value>%s</Value></NameValueList>\n",&ZOOVY::incode($ref->{'varname'}),&ZOOVY::incode($ref->{'optprompt'}));
			$i++;
			#if ((defined $ref->{'optpricemod'}) && ($ref->{'optpricemod'} ne '')) {
			#	($totalprice) = &ZOOVY::calc_modifier($totalprice,$ref->{'optpricemod'},1);
			#	}
			}

		$v{'Variation.StartPrice*'} = &XMLTOOLS::currency('StartPrice',$totalprice,'USD');
		$v{'Variation.SKU'} = $SKU;

		if ($P->skufetch($SKU,'sku:upc')) {
			$v{'Variation.VariationProductListingDetails.UPC'} =  $P->skufetch($SKU,'sku:upc');
			}

		$v{'Variation.Quantity'} = int($INVSUMMARY->{$SKU}->{'AVAILABLE'});
		if ($v{'Variation.Quantity'} <= 0) {
			$v{'Variation.Quantity'} = 0;	# make sure -1 becomes zero.
			push @{$MSGSREF}, "WARNING|+SKU $SKU had zero inventory but was still transmitted to eBay";
			}
		else {
			push @{$MSGSREF}, sprintf("INFO|+SKU: $SKU AVAILABLE:%d PRICE:%.2f",$INVSUMMARY->{$SKU}->{'AVAILABLE'},$totalprice);
			$HAD_INVENTORY++;
			}
		$vxml .= XMLTOOLS::buildTree(undef,\%v,1)."\n";
		}
	$api->{'Item.Variations.*'} = $vxml;
	if ($HAD_INVENTORY==0) {
		push @{$MSGSREF}, "ERROR|+You need to have positive inventory for at least one of the SKU's in this product";
		}
	}



##
## returns the pretty name for a given category
##
sub resolve_category {
	my ($EBAYCAT) = @_;

	if ($EBAYCAT eq '') { return('Not Set'); }

	my %categories = ();
	$categories{''} = 'Not Set';
	my ($toxml) = TOXML->new('DEFINITION','ebay.auction');
	if (defined $toxml) {
		foreach my $opt (@{$toxml->getListOptByAttrib('EBAYCAT','V',$EBAYCAT)}) {
			$categories{$opt->{'V'}} = $opt->{'T'};
			}
		}
	undef $toxml;
	
	use Data::Dumper; print STDERR Dumper(\%categories);

	return($categories{$EBAYCAT});
	}



##
## TARGET is "AUCTION","FIXED","STORE"
##
sub ebay_fields {
	my ($listtype) = @_;

	if ($listtype =~ /^EBAY\.(.*)$/) { $listtype = $1; }	# change EBAY.AUCTN to AUCTN, EBAY.FIXED to just 'FIXED', etc.
	if ($listtype eq 'AUCTN') { $listtype = 'AUCTION'; }	# change AUCT to AUCTION
	
	my @FIELDS = (

	{properties=>1,id=>"ebay:secondchance",legacy=>"ebay:autosecond",ns=>'profile',hint=>"Enable Second Chance Offers"},
	# {properties=>1,id=>"ebay:listingtype",hint=>"AUCTION,FIXED,STORE"},
	{properties=>1,id=>"ebay:category",type=>'ebay/category',ns=>'product',loadfrom=>"navcat:ebay_category",hint=>"eBay.com Primary Category"},
	{properties=>1,id=>"ebay:category2",type=>'ebay/category',ns=>'product',hint=>"eBay Market Place Category Two"},
	{properties=>1,id=>"ebay:counter",type=>'chooser/counter',ns=>'profile',hint=>"eBay Visitor Counter"},
	{properties=>1,id=>"ebay:instant_paypal",type=>'boolean',ns=>'profile',legacy=>"ebay:instantpay",hint=>"Enable Paypal Instant Payment Upon eBay Checkout",ebay=>'Item\\AutoPay\\@BOOLEAN'},
	{properties=>1,id=>"ebay:prod_image1",type=>"image",loadfrom=>"zoovy:prod_image1",hint=>"First eBay Product Image"},
	{properties=>1,id=>"ebay:ship_irregular",type=>'checkbox',hint=>"Irregular Shipping Package"},
	{properties=>1,id=>"ebay:storecat",type=>'ebay/storecat',ns=>'product',loadrom=>"navcat:ebay_storecat",hint=>"eBay Store Category One"},
	{properties=>1,id=>"ebay:storecat2",type=>'ebay/storecat',ns=>'product',hint=>"eBay Store Category Two"},
	{properties=>1,id=>"ebay:title",type=>'textbox',loadfrom=>"zoovy:prod_name",hint=>"Default eBay Listing Title"},
	{properties=>1,id=>"ebay:subtitle",type=>'textbox',hint=>"eBay Subtitle"},
	{properties=>1,id=>"ebay:ship_originzip",type=>'textbox',ns=>'profile',hint=>"Shipping Origin (zip code) for the product"},
	{properties=>1,id=>"ebay:list_private",type=>'boolean'},
	{properties=>1,id=>"ebay:attributeset",type=>'ebay/attributes'},

	# {id=>"ebay:prod_condition",type=>'textbox',title=>'media condition (legacy)', hint=>'warning: only works in media categories use words: New or Used'},
	# {id=>"ebay:item_condition",type=>'hidden',title=>'attribute condition (legacy)',hint=>'a plain text description of the item used only for ebay (overrides zoovy:prod_condition), used with categories that have not been upgraded to ebays standardized conditionid'},
#	{id=>"ebay:financeoffer",type=>'boolean'},
	{properties=>1,id=>"ebay:productid",type=>'hidden'},
	{properties=>1,id=>"ebay:prod_image1_dim",type=>'textbox',hint=>'a string which specifies ebay image dimensions (otherwise original will be sent), format:##x##'},
	{properties=>1,id=>"ebay:motors_problems",type=>'textbox',hint=>"eBay Motors Known Problem Field"},
	{properties=>1,id=>"ebay:motors_terms",type=>'textbox',legacy=>"ebay:terms",ns=>"profile",hint=>"eBay Motors Terms and Conditions"},
	{properties=>1,id=>"ebay:location",type=>"textbox",ns=>"profile",hint=>"Location text describing where the item ships from"},
	{properties=>1,id=>"ebay:lotsize",type=>"textbox",ns=>"profile",hint=>"How many units are included in the listing"},
	{properties=>1,id=>"ebay:conditionid",type=>"select",title=>"eBay's unified site-wide condition id", hint=>"not all values are applicable for all categories, however ebay began transitioning all categories to this unified notation in July 2010",
		'options'=>[
			{ p=>"New/BrandNew/withBox", v=>"1000" },
			{ p=>"*New/Other/noBox", v=>"1500" },
			{ p=>"*New/withDefects", v=>"1750" },
			{ p=>"Refurbished/by Mfg", v=>"2000" },
			{ p=>"Refurbished/by Seller", v=>"2500" },
			{ p=>"Used/LikeNew/PreOwned", v=>"3000" },
			{ p=>"Very Good", v=>"4000" },
			{ p=>"Good", v=>"5000" },
			{ p=>"Acceptable", v=>"6000" },
			{ p=>"Not Working/For Parts", v=>"7000" },
			]},
	{properties=>1,id=>'ebay:motor_buyer_does_shipping',ns=>'profile',type=>'boolean'},
	{properties=>1,id=>'ebay:motor_limited_warranty',ns=>'profile',type=>'boolean'},

	{properties=>1,id=>'ebay:dispatchmaxtime',ns=>'profile',type=>'boolean',hint=>'maximum business-days before the item ships','ebay'=>'Item\\DispatchTimeMax'},
	{properties=>1,id=>'ebay:getitfast',ns=>'profile',type=>'boolean',hint=>'see ebay "get it fast" terms'},
	{properties=>1,id=>'ebay:now_and_new',ns=>'profile',type=>'boolean',hint=>'see ebay "now and new" terms'},
	{properties=>1,id=>'ebay:use_bestoffer',ns=>'profile',type=>'boolean',title=>'BestOffer Enabled',hint=>'should we allow best offers from buyers','ebay'=>'Item\\BuyerRequirementDetails\\BestOfferEnabled\\@BOOLEAN'},
	{properties=>1,id=>'ebay:minsellprice',ns=>'profile',type=>'currency',hint=>''},

	{properties=>1,id=>"ebay:autopay",type=>"boolean",ns=>"profile",'ebay'=>'Item\\AutoPay\\@BOOLEAN'},
	{properties=>1,id=>"ebay:buyreq_linkedpaypal",type=>"boolean",ns=>"profile"},
	{properties=>1,id=>"ebay:buyreq_maxitemcount",type=>"boolean",ns=>"profile"},
	{properties=>1,id=>"ebay:buyreq_minfeedback",type=>"boolean",ns=>"profile",'ebay'=>'Item\\BuyerRequirementDetails\\MaximumItemRequirements\\MinimumFeedbackScore'},
	{properties=>1,id=>"ebay:buyreq_maxupistrikes",type=>"boolean",ns=>"profile"},

	{properties=>1,id=>"ebay:pay_none",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_mocc",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_amex",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_seeitem",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_check",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_cod",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_visamc",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_paisapay",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_other",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_paypal",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_discover",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_cashonpickup",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_moneyxfer",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_moneyxfercheckout",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_otheronline",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_escrow",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_codprepay",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_postaltransfer",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_motor_loancheck",ns=>"profile"},
	{properties=>1,id=>"ebay:pay_motor_cash",ns=>"profile"},
	{properties=>1,id=>"ebay:zip",ns=>"profile"},

	{properties=>1,id=>"zoovy:paypalemail",ns=>"profile",hint=>"Paypal Email Address",'ebay'=>'Item\\PayPalEmailAddress'},
	{properties=>1,id=>"ebay:use_taxtable",ns=>"profile"},
	{properties=>1,id=>"ebay:ship_intlocations",ns=>"profile"},
	{properties=>1,id=>"ebay:return_acceptpolicy",ns=>"profile"},
	{properties=>1,id=>"ebay:return_refundpolicy",ns=>"profile"},
	{properties=>1,id=>"ebay:return_desc",ns=>"profile"},
	{properties=>1,id=>"ebay:refund_policy",ns=>"profile"},
	{properties=>1,id=>"ebay:return_withinpolicy",ns=>"profile"},
	{properties=>1,id=>"ebay:return_shipcostpolicy",ns=>"profile"},
	{properties=>1,id=>"ebay:salestaxpercent",ns=>"profile"},
	{properties=>1,id=>"ebay:salestaxstate",ns=>"profile"},
	{properties=>1,id=>"ebay:ship_tax",ns=>"profile"},
	{properties=>1, id=>"ebay:base_weight",type=>'weight',loadfrom=>"zoovy:base_weight",hint=>'eBay Specific Weight'},
	
	{properties=>1,id=>"ebay:sku",ns=>"product",type=>"text",title=>"eBay SKU",hint=>"SKU that will be sent to eBay and used on the inbound order/inventory. Use this if you have multiple products that act as separate ebay templates."},
	{properties=>1,id=>"ebay:launch_immediate",type=>"boolean",ns=>"product",hint=>"Ignore launch window and launch immediately"},
	{properties=>1,id=>"ebay:launch_window",type=>"boolean",ns=>"product",hint=>"Custom launch window"},
	
	{properties=>1,id=>"ebay:use_taxtable",type=>"boolean",ns=>"profile"},
	{properties=>1,id=>"ebay:salestaxpercent",type=>"number",ns=>"profile"},
	{properties=>1,id=>"ebay:ship_domservices",type=>"textarea",ns=>"profile", hint=>"contains a uri encoded string which specifies various ebay shipping options" },
	{properties=>1,id=>"ebay:ship_cost1",type=>"currency",loadfrom=>"zoovy:ship_cost1",ns=>"product",title=>"eBay Fixed Shipping Cost (first item)",title=>"Defaults to zoovy:ship_cost1. To simply markup the shipping for eBay use ebay:ship_markup instead." },
	{properties=>1,id=>"ebay:ship_cost2",type=>"currency",loadfrom=>"zoovy:ship_cost2",ns=>"product",title=>"eBay Fixed Shipping Cost (Additional Item)",hint=>"defaults to zoovy:ship_cost2 (additional fixed price item)"},
	{properties=>1,id=>"ebay:ship_markup",type=>"currency",loadfrom=>"zoovy:ship_markup",ns=>"profile",title=>"eBay Fixed Shipping Markup",hint=>"An additional amount in dollars that will be added to fixed price shipping cost for both first and second items. Particularly useful when ebay:ship_cost1, and ebay:ship_cost2 are left blank, so zoovy:ship_cost1, and zoovy:ship_cost2 are used. For eBay calculated shipping methods this field is ignored - however ebay:base_weight can be used to send an alternate (higher) weight for eBay thus accomplishing the same result."},
	{properties=>1,id=>"ebay:ship_intservices",type=>"textarea",ns=>"profile"},
	{properties=>1,id=>"ebay:ship_intlocations",type=>"textarea",ns=>"profile"},
	{properties=>1,id=>"ebay:ship_can_cost1",type=>"currency",title=>"eBay Fixed Shipping Cost to Canada", loadfrom=>"zoovy:ship_can_cost1",ns=>"product"},
	{properties=>1,id=>"ebay:ship_can_cost2",type=>"currency",title=>"eBay Fixed Shipping Cost (add. items) to Canada",loadfrom=>"zoovy:ship_can_cost2",ns=>"product"},
	{properties=>1,id=>"ebay:ship_int_cost1",type=>"currency",title=>"eBay Fixed Shipping Cost to International",loadfrom=>"zoovy:ship_int_cost1",ns=>"product"},
	{properties=>1,id=>"ebay:ship_int_cost2",type=>"currency",title=>"eBay Fixed Shipping Cost (add. items) to International",loadfrom=>"zoovy:ship_int_cost2",ns=>"product"},
	{properties=>1,id=>"ebay:ship_dominstype",type=>"text",title=>"eBay Domestic Insurance Setting",ns=>"profile"},
	{properties=>1,id=>"ebay:ship_dominsfee",type=>"currency",title=>"eBay Domestic Insurance Fee",ns=>"profile"},
	{properties=>1,id=>"ebay:ship_intinstype",type=>"text",title=>"eBay International Insurance Setting",ns=>"profile"},
	{properties=>1,id=>"ebay:ship_intinsfee",type=>"currency",title=>"eBay International Insurance Fee",ns=>"profile"},
	{properties=>1,id=>"ebay:ship_dompkghndcosts",type=>"currency",title=>"eBay Domestic Packaging and Handling Costs",ns=>"profile"},
	{properties=>1,id=>"ebay:ship_intpkghndcosts",type=>"currency",title=>"eBay International Packaging and Handling Costs",ns=>"profile"},

	{properties=>1,id=>"ebay:prod_length",title=>"eBay Packaged Shipping Length",loadfrom=>"zoovy:prod_length,ebay:pkg_length,zoovy:pkg_length,ebay:pkg_depth,zoovy:pkg_depth",type=>"number",ns=>"product"},
	{properties=>1,id=>"ebay:prod_height",title=>"eBay Packaged Shipping Height",loadfrom=>"zoovy:prod_height,ebay:pkg_height,zoovy:pkg_height",type=>"number",ns=>"product"},
	{properties=>1,id=>"ebay:prod_width",title=>"eBay Packaged Shipping Width",loadfrom=>"zoovy:prod_width,ebay:pkg_width,zoovy:pkg_width",type=>"number",ns=>"product"},
  	{properties=>1,id=>"ebay:ship_packagetype",title=>"eBay Package Type",hint=>"see eBay documentation for CalculatedShippingRate.ShippingPackage",ns=>"profile"},
	);

	if (($listtype eq 'FIXED') || ($listtype eq '')) {
		unshift @FIELDS, {properties=>1,id=>"ebay:fixed_duration",type=>'selectreset',ns=>'profile',hint=>"Default eBay Fixed Listing Duration",
				options=>[{v=>3,p=>'3 day'},{v=>5,p=>'5 day'},{v=>7,p=>'7 day'},{v=>10,p=>'10 day'},{v=>30,p=>'30 day'},{v=>-1,p=>'GTC'} ]};
		unshift @FIELDS, {properties=>1,id=>"ebay:fixed_qty",type=>'number',hint=>"eBay Fixed Quantity"};
		unshift @FIELDS, {properties=>1,id=>"ebay:fixed_price",type=>'currency',legacy=>"ebay:buyitnow,ebay:price",ns=>'product',hint=>"eBay Item Fixed Price"};
		}
	elsif (($listtype eq 'SYND') || ($listtype eq '')) {
		unshift @FIELDS, {properties=>1,id=>"ebay:fixed_price",type=>'currency',legacy=>"ebay:buyitnow,ebay:price",ns=>'product',hint=>"eBay Item Fixed Price"};
		}
	#if (($listtype eq 'STORE') || ($listtype eq '')) {
	#	unshift @FIELDS, {properties=>1,id=>"ebay:fixed_price",type=>'currency',legacy=>"ebay:buyitnow,ebay:price",ns=>'product',hint=>"eBay Item Store/Fixed Price"};
	#	}
	if (($listtype eq 'AUCTION') || ($listtype eq '')) {
		unshift @FIELDS, {properties=>1,ns=>'profile',properties=>1,id=>"ebay:duration",type=>'selectreset',ns=>'profile',hint=>"Default eBay Listing Duration",
				options=>[{v=>3,p=>'3 day'},{v=>5,p=>'5 day'},{v=>7,p=>'7 day'},{v=>10,p=>'10 day'}]};
		unshift @FIELDS, {properties=>1,id=>"ebay:qty",type=>'number',hint=>"eBay Auction Quantity"};
		unshift @FIELDS, {properties=>1,id=>"ebay:start_price",type=>"currency",required=>1,legacy=>"ebay:startprice",ns=>'product',hint=>"eBay Auction Start Price"};
		unshift @FIELDS, {properties=>1,id=>"ebay:reserve_price",type=>"currency",required=>0,legacy=>"ebay:reserve",ns=>'product',hint=>"eBay Auction Reserve Price"};
		unshift @FIELDS, {properties=>1,id=>"ebay:buyitnow_price",type=>'currency',legacy=>"ebay:buyitnow",ns=>'product',hint=>"eBay Auction Buy-It-Now Price"};
		}

	return(\@FIELDS);
	}








###########################################################
##
## eBay Auction/FixedPrice Handler
##
sub event_handler {
	my ($udbh,$le,$P,%options) = @_;

	if (not defined $udbh) {
		die("UDBH must be passed");
		}

	if (ref($P) ne 'PRODUCT') {
		&ZOOVY::confess($le->username(),"event failed due to invalid PRODUCT reference");
		}

	## make a copy of orig_prodref which we can trash with overrides, etc.
	my $prodref = {};
	my $orig_prodref = $P->prodref();
	foreach my $k (keys %{$orig_prodref}) {
		$prodref->{$k} = $orig_prodref->{$k};
		}

	my $INV2 = INVENTORY2->new($le->username(),$le->luser());
	my %FINALMSG = ();

	require EBAY2;
	my ($eb2) = undef;
	my $MSGS = $le->msgs();

	if (not $le->has_failed()) {
		($eb2) = EBAY2->new($le->username(),'PRT'=>$le->prt());
		if (not defined $eb2) { 
			push @{$MSGS}, sprintf("ERROR|src=ZLAUNCH|code=200|+Could not load eBay Token for partition[%d]",$le->prt());
			}
		if ($eb2->{'ERRORS'}>1000) {
			push @{$MSGS}, "ERROR|src=ZLAUNCH|code=201|+eBay Token has errors=$eb2->{'ERRORS'}>1000 - please correct errors and reset token.";
			}
		}	

	if ((defined $eb2) && (ref($eb2) eq 'EBAY2')) {
		}
	else {
		push @{$MSGS}, "ERROR|ZLAUNCH|code=10|+No eBay Token/Object available";
		}

	my $VERB = $le->verb();
	if ($VERB eq 'REFRESH') { $VERB = 'UPDATE-LISTING'; }
	my $TARGET = $le->target();


	if (($TARGET eq 'EBAY.FIXED') && ($le->{'REQUEST_APP'} eq 'SYND')) {
		$TARGET = 'EBAY.SYND'; 
		}
	if ($VERB eq 'UPDATE-LISTING') {
		## see if we're doing a syndicated listing (change to EBAY.SYND so we use those rules)
		my $MID = $le->mid();
		my $USERNAME = $le->username();
		my $pstmt = "select CHANNEL,IS_SYNDICATED,IS_GTC from EBAY_LISTINGS where MID=$MID /* $USERNAME */ and EBAY_ID=".$udbh->quote($le->listingid());
		my ($CHANNEL,$IS_SYNDICATED,$IS_GTC) = $udbh->selectrow_array($pstmt);
		if (($CHANNEL == -1) || ($IS_SYNDICATED) || ($IS_GTC)) {
			## NOTE: GTC listings should be treated as syndicated listings, because you can't revise duration anyway. ticket #746995
			if ($IS_GTC) {
				push @{$MSGS}, "INFO|+DETECTED GTC LISTING - USING SYNDICATION LOGIC";
				}
			$TARGET = 'EBAY.SYND';
			}
		}


	if ($le->has_failed()) {
		## shit already happened.
		}
	elsif (($VERB eq 'INSERT') || ($VERB eq 'UPDATE-LISTING') || ($VERB eq 'PREVIEW')) {

		# print STDERR "PROFILE: $prodref->{'zoovy:profile'}\n"; die();
		
		my $CLASS = '?';
		if ($TARGET eq 'EBAY.AUCTN') { $CLASS = 'AUCTION'; }		# legacy
		if ($TARGET eq 'EBAY.AUCTION') { $CLASS = 'AUCTION'; }
		# elsif ($TARGET eq 'EBAY.STORE') { $CLASS = 'STORE'; }
		elsif ($TARGET eq 'EBAY.FIXED') { $CLASS = 'FIXED'; }
		elsif ($TARGET eq 'EBAY.SYND') { $CLASS = 'FIXED'; }
		elsif ($TARGET eq 'EBAY.STORE') { $CLASS = 'FIXED'; }		# legacy
		else { 
			push @{$MSGS}, "FAIL-FATAL|src=PREFLIGHT|+Unknown Target:$TARGET"; 
			}

		## lets discuss how we're merging data.
		## $ebref is all the data we need to launch an ebay listing.
		my $EBAY_FIELDS = &ebay_fields($TARGET);
		my $ebnsref = undef;
		my $PROFILE = undef;

		if ($le->can_proceed()) {
			$PROFILE = $prodref->{'ebay:profile'};
			if ($PROFILE eq '') { $PROFILE = $prodref->{'zoovy:profile'}; }

			if ($options{'%profile'}) {
				## used during an ebay test
				$ebnsref = $options{'%profile'};
				}
			elsif ($PROFILE eq '') {
				push @{$MSGS}, "ERROR|src=LAUNCH|+zoovy:profile was not set and is a required field.";
				}
			else {
				$ebnsref = &EBAY2::PROFILE::fetch($le->username(),$le->prt(),$PROFILE);
				if (not defined $ebnsref) {
					push @{$MSGS}, "ERROR|+Profile '$PROFILE' is invalid/could not be loaded.";
					}
				}
			}

		if ($le->has_failed()) {
			}
		elsif ($TARGET eq 'EBAY.SYND') {
			##
			## Special Store Syndication Logic
			##
			#if ($cfg_autopilot) {
			#	push @{$MSGS}, "SYNDICATION|src=LAUNCH|+Syndication autopilot is engaged";
			#	}
			#else {
			#	push @{$MSGS}, "SYNDICATION|src=LAUNCH|+Syndication autopilot is NOT engaged";
			#	}
			# my ($cfg_gallery) = $so->get('.cfg_gallery');
			# my ($cfg_duplicates) = $so->get('.duplicates');
			#$so = undef;

			##
			## 
			## 

			my $edataref = $le->dataref();
			$edataref->{'ebay:fixed_duration'} = -1;	# GTC ONLY for SYNDICATION

			if (($prodref->{'ebay:fixed_price'} == -1) && ($P->has_variations('inv')>0)) {
				$prodref->{'ebay:fixed_price'} = $prodref->{'zoovy:base_price'};
				push @{$MSGS}, "INFO|src=LAUNCH|+Syndication w/variations changed ebay:fixed_price (-1) to zoovy:base_price[$prodref->{'zoovy:base_price'}]";					
				}
			elsif ($prodref->{'ebay:fixed_price'} == -1) {
				$prodref->{'ebay:fixed_price'} = $prodref->{'zoovy:base_price'};
				push @{$MSGS}, "INFO|src=LAUNCH|+Syndication changed ebay:fixed_price (-1) to zoovy:base_price";
				}
			if ($prodref->{'ebay:title'} eq '') {
				$prodref->{'ebay:title'} = substr($prodref->{'zoovy:prod_name'},0,80);
				push @{$MSGS}, "INFO|src=LAUNCH|+Syndication used zoovy:prod_name as ebay:title";
				}

			my ($NC) = undef;
			if (($prodref->{'ebay:storecat'} ne '') && ($prodref->{'ebay:category'} ne '')) {
				## best case: ebay:storecat and ebay:category are both set in product!
				}
			elsif ((defined $edataref->{'navcat:ebay_storecat'}) || (defined $edataref->{'navcat:ebay_category'})) {
				## well, at least the syndication object gave us good hinting!
				}
			else {
				## i guess we're running a preview or something, so we'll do our own lookup
				push @{$MSGS}, "INFO|src=LAUNCH|+eBay Store Category or eBay category hints are empty, so we'll try a navcat lookup (this should only occur on preview/test)";
				require NAVCAT;
				my ($NC) = NAVCAT->new($le->username(),PRT=>$le->prt());
				my ($safe,$metaref) = $NC->meta_for_product($le->pid());
				if ($safe eq '') {
					push @{$MSGS}, "WARN|src=LAUNCH|+Syndication did not find this product in any website categories.";
					}
				$edataref->{'navcat:safe'} = $safe;
				$edataref->{'navcat:ebay_category'} = $metaref->{'EBAY_CAT'};
				$edataref->{'navcat:ebay_storecategory'} = $metaref->{'EBAY_STORECAT'};
				}

			if ($prodref->{'ebay:storecat'} ne '') {  
				}
			elsif ($edataref->{'navcat:safe'} eq '') {
				## we already threw an error earlier.
				}
			elsif ($edataref->{'navcat:ebay_storecategory'} ne '') {
				push @{$MSGS}, "DEBUG|src=LAUNCH|+Syndication said ebay:storecat default category set by navcat: ".$edataref->{'navcat:safe'};
				$prodref->{'ebay:storecat'} =  $edataref->{'navcat:ebay_storecategory'}; 
				}
			else {
				push @{$MSGS}, "WARN|src=LAUNCH|+Syndication said EBAYSTORE_CAT default category was not set for navcat: ".$edataref->{'navcat:safe'};
				}

			if ($prodref->{'ebay:category'} ne '') {  
				}
			elsif ($edataref->{'navcat:ebay_category'} ne '') {
				push @{$MSGS}, "DEBUG|src=LAUNCH|+Syndication said ebay:category default category set by navcat: ".$edataref->{'navcat:safe'};
				$prodref->{'ebay:category'} =  $edataref->{'navcat:ebay_category'}; 
				}
			else {
				push @{$MSGS}, "WARN|src=LAUNCH|+Syndication said EBAYSTORE_CAT default category was not set for navcat: ".$edataref->{'navcat:safe'};
				}
			
			if ($prodref->{'zoovy:profile'} ne '') {
				}
			elsif ($prodref->{'ebay:profile'} ne '') {
				}
			#elsif (($cfg_autopilot) && ($edataref->{'default:profile'} eq '')) {
			#	push @{$MSGS}, "DEBUG|src=LAUNCH|+Syndication autopilot used default:profile from event $edataref->{'default:profile'}";
			#	$prodref->{'zoovy:profile'} = $edataref->{'default:profile'};
			#	}
			else {
				push @{$MSGS}, "WARN|src=LAUNCH|+Syndication failed because autopilot was not engaged and profile was not set.";
				}

			if (defined $prodref->{'ebay:fixed_price'}) {
				push @{$MSGS}, "DEBUG|src=LAUNCH|+Syndication fixed price: ".$prodref->{'ebay:fixed_price'};
				}
			elsif ($ebnsref->{'AUTO_PRICE'}) {
				push @{$MSGS}, "DEBUG|src=LAUNCH|+Syndication AUTO_PRICE set ebay:fixed_price to zoovy:base_price";
				$prodref->{'ebay:fixed_price'} = $prodref->{'zoovy:base_price'};
				}
			else {
				push @{$MSGS}, "WARN|src=LAUNCH|+Syndication failed because profile auto_price=disabled and ebay fixed price was not set.";
				}
			}
		

		my ($ebref) = ();
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());

		if ($le->has_failed()) {
			}
		else {
			push @{$MSGS}, "INFO|+Profile version: $ebnsref->{'#v'}";
			$ebref = $prodref;
			## copy zoovy: fields into ebay:
			foreach my $k (keys %{$ebref}) {
				if ($k =~ /^zoovy\:(.*?)$/) {
					next if (defined $ebref->{"ebay:$1"});
					$ebref->{"ebay:$1"} = $ebref->{$k};
					}
				}
			}
	
		if ($ebref->{'ebay:storecat'} eq '') { $ebref->{'ebay:storecat'} = 0; }		
		if (not defined $ebref->{'ebay:prod_image1'}) { $ebref->{'ebay:prod_image1'} = ''; }
		if ($ebref->{'ebay:prod_image1'} =~ /[\s\t]+/) {
			push @{$MSGS}, "ERROR|src=LAUNCH|+ebay:prod_image1 contains invalid (space or tab) characters in the filename";
			}

		#if ($ebref->{'ebay:ship_originzip'} eq '') {
	   #  push @{$MSGS}, "WARN|src=ZLAUNCH|+eBay shipping origin zip not set, defaulting to company zip"; 
      #  $ebref->{'ebay:ship_originzip'} = $ebnsref->{'zoovy:zip'};
      #  }

		my $dbref = undef;
		my $UUID = -1;

		## lets do a quick duplicate check
		if ($le->has_failed()) {
			}
		elsif ($VERB eq 'INSERT') {
			my $MID = $le->mid();
			my $USERNAME = $le->username();
			my $pstmt = "select * from EBAY_LISTINGS where MID=$MID /* $USERNAME */ and DISPATCHID=".$le->id();
			($dbref) = $udbh->selectrow_hashref($pstmt);
			if (not defined $dbref) {
				## listing does not exist in database, we'll insert it.
				}
			elsif ($dbref->{'LISTINGID'}==0) {
				## hmm.. bad launch, but we'll use the same uuid so it's up to eBay to figure out if it's a dup.
				push @{$MSGS}, "WARN|+Detected unlaunched listing TB:EBAY_LISTINGS DBID:$dbref->{'ID'}";
				$UUID = $dbref->{'ID'};
				}
			else {
				warn "DISPATCHID already exists in database as LISTINGID=$dbref->{'LISTINGID'}, changing to UPDATE-LISTING";
				$VERB = 'UPDATE-LISTING';
				$UUID = $dbref->{'ID'};
				}
			}

		## do one more inventory check just to be sure.
		my $SKU = $le->sku();
		my ($instock, $reserved) = $INV2->fetch_pidsummary_qtys('@PIDS'=>[$SKU],'%PIDS'=>{$P->pid()=>$P});
		if ($le->has_failed()) {
			$VERB = 'FAIL';
			}
		elsif ($VERB eq 'INSERT') {

			if (not defined $instock) {
				push @{$MSGS}, "WARN|+Could not find inventory for $SKU in database";
				}
			elsif ($instock <= 0) {
				if ($prodref->{'zoovy:prod_asm'} ne '') {
					push @{$MSGS}, "FAIL-SOFT|+Inventory not available sku:$SKU (on-shelf: $instock), possibly due to assemblies.";
					}
				else {
					push @{$MSGS}, "FAIL-SOFT|+Inventory not available sku:$SKU on-shelf:$instock reserved:$reserved";
					}
				$VERB = 'FAIL';
				}	
			else {
				push @{$MSGS}, "INFO|+Inventory for $SKU on-shelf:$instock reserved:$reserved";
				}
			}




		if (($VERB eq 'INSERT') && (defined $dbref) && ($dbref->{'LISTINGID'}==0)) {
			## we've got a listing in the database already, but no listing id, so it probably crashed in the middle or
			## something. either way we don't need it in the database AGAIN so we'll skip the next bit and maybe add
			## some intelligence here about how many times we've retried or whatever.
			}
		elsif (($VERB eq 'INSERT') && (not defined $dbref)) {
			#mysql> desc MONITOR_QUEUE_CRACKLE;
			#+-----------------------+--------------------------------------------------------------------+------+-----+---------+----------------+
			#| Field                 | Type                                                               | Null | Key | Default | Extra          |
			#+-----------------------+--------------------------------------------------------------------+------+-----+---------+----------------+
			#| ID                    | int(11)                                                            | NO   | PRI | NULL    | auto_increment |
			$dbref->{'ID'} = 0;
			#| MERCHANT              | varchar(20)                                                        | NO   |     | NULL    |                |
			$dbref->{'MERCHANT'} = $le->username();
			#| MID                   | int(11)                                                            | NO   | MUL | 0       |                |
			$dbref->{'MID'} = $le->mid();
			#| PRT                   | tinyint(3) unsigned                                                | NO   |     | 0       |                |
			$dbref->{'PRT'} = $le->prt();
			#| PROFILE               | varchar(10)                                                        | NO   |     | NULL    |                |
			$dbref->{'PROFILE'} = $PROFILE;
			if (not defined $dbref->{'PROFILE'}) { $dbref->{'PROFILE'} = ''; }
			#| PROFILE_VERSION       | tinyint(4)                                                         | NO   |     | 0       |                |
			$dbref->{'PROFILE_VERSION'} = 10;
			#| PRODUCT               | varchar(45)                                                        | NO   |     | NULL    |                |
			$dbref->{'PRODUCT'} = $le->sku();
			#| CHANNEL               | bigint(20)                                                         | NO   | MUL | 0       |                |
			$dbref->{'CHANNEL'} = 0;
			#| EBAY_ID               | bigint(20)                                                         | YES  | UNI | NULL    |                |
			$dbref->{'EBAY_ID'} = undef;
			#| CREATED_GMT           | int(11)                                                            | NO   |     | 0       |                |
			$dbref->{'CREATED_GMT'} = time();
			#| LASTSAVE_GMT          | int(11)                                                            | NO   |     | 0       |                |
			$dbref->{'LASTSAVE_GMT'} = time();
			#| LAUNCHED_GMT          | int(11)                                                            | NO   | MUL | 0       |                |
			$dbref->{'LAUNCHED_GMT'} = time();
			#| LAST_PROCESSED_GMT    | int(11)                                                            | NO   |     | 0       |                |
			$dbref->{'LAST_PROCESSED_GMT'} = 0;
			#| LAST_TRANSACTIONS_GMT | int(11)                                                            | NO   |     | 0       |                |
			$dbref->{'LAST_TRANSACTIONS_GMT'} = 0;
			#| ENDS_GMT              | int(11)                                                            | NO   |     | 0       |                |
			$dbref->{'ENDS_GMT'} = 0;
			#| EXPIRES_GMT           | int(11)                                                            | NO   |     | 0       |                |
			$dbref->{'EXPIRES_GMT'} = 0;
			#| QUANTITY              | int(11)                                                            | NO   |     | 0       |                |
			## if the quantity is: -1 it means load from product (ebay:qty)
			## if the quantity is: -2 it means all available inventory
			## if the quantity is: -3 it means all available inventory minus 1
			$dbref->{'QUANTITY'} = $instock;
			#if ($le->username() eq 'kcint') {
			#	$dbref->{'QUANTITY'} = 1;
			#	}
			if (($le->username() eq 'toynk') && ($dbref->{'QUANTITY'}==-1)) { 
				$dbref->{'QUANTITY'} = ($instock - $reserved);
				}
			if ($dbref->{'QUANTITY'}<=0) {
				# print Dumper($le);
				push @{$MSGS}, "ERROR|+Detected zero quantity listing, will not continue with INSERT"; 
				}

			#| ITEMS_SOLD            | int(11)                                                            | NO   |     | 0       |                |
			$dbref->{'ITEMS_SOLD'} = 0;
			#| ITEMS_REMAIN          | int(11)                                                            | NO   |     | 0       |                |
			$dbref->{'ORIG_EBAYID'} = 0;
			#| DEST_USER             | varchar(60)                                                        | NO   |     | NULL    |                |
			$dbref->{'DEST_USER'} = '';
			#| TRIGGER_PRICE         | decimal(10,2)                                                      | NO   |     | 0.00    |                |
			$dbref->{'TRIGGER_PRICE'} = 0; 
			#| RECYCLED_ID           | bigint(20)                                                         | NO   |     | 0       |                |
			$dbref->{'RECYCLED_ID'} = 0;
			#| BIDPRICE              | decimal(10,2)                                                      | NO   |     | 0.00    |                |
			$dbref->{'BIDPRICE'} = 0;
			#| BIDCOUNT              | tinyint(3) unsigned                                                | NO   |     | 0       |                |
			$dbref->{'BIDCOUNT'} = 0;
			#| BUYITNOW              | decimal(10,2)                                                      | NO   |     | 0.00    |                |
			$dbref->{'BUYITNOW'} = 0;
			#| TITLE                 | varchar(55)                                                        | NO   |     | NULL    |                |
			$dbref->{'TITLE'} = sprintf("%s",$ebref->{'ebay:title'});
			#| CATEGORY              | int(11)                                                            | NO   |     | 0       |                |
			$dbref->{'CATEGORY'} = int($ebref->{'ebay:category'});
			#| STORECAT              | int(10) unsigned                                                   | NO   |     | 0       |                |
			$dbref->{'STORECAT'} = int($ebref->{'ebay:storecat'});
			#| CLASS                 | enum('AUCTION','DUTCH','FIXED','MOTOR','STORE','PERSONAL','OTHER') | YES  |     | OTHER   |                |
			$dbref->{'CLASS'} = $CLASS;
			#| VISITORS              | int(11)                                                            | NO   |     | 0       |                |
			$dbref->{'VISITORS'} = 0;
			#| IS_GTC                | tinyint(4)                                                         | NO   |     | 0       |                |
			$dbref->{'IS_GTC'} = 0;
			#| IS_RELIST             | tinyint(4)                                                         | NO   |     | 0       |                |
			$dbref->{'IS_RELIST'} = 0;
			#| IS_RECYCLABLE         | tinyint(4)                                                         | NO   |     | 0       |                |
			$dbref->{'IS_RECYCLABLE'} = 0;
			#| IS_SYNDICATED         | tinyint(4)                                                         | NO   |     | 0       |                |
			$dbref->{'IS_SYNDICATED'} = 0;
			if ($TARGET eq 'EBAY.SYND') {
				$dbref->{'IS_SYNDICATED'} = 1;		## NOTE: this will NOT be set on PREVIEW so don't use this.
				$dbref->{'CHANNEL'} = -1;
				}
			#elsif (($TARGET eq 'EBAY.FIXED') && ($le->{'REQUEST_APP'} eq 'SYND')) {
			#	$dbref->{'IS_SYNDICATED'} = 1;
			#	$dbref->{'CHANNEL'} = -1;
			#	}

			#| IS_MOTORS             | tinyint(4)                                                         | NO   |     | 0       |                |
			$dbref->{'IS_MOTORS'} = 0;
			#| IS_RESERVE            | decimal(10,2)                                                      | NO   |     | 0.00    |                |
			$dbref->{'IS_RESERVE'} = 0;
			#| IS_SCOK               | decimal(8,2)                                                       | NO   |     | 0.00    |                |
			$dbref->{'IS_SCOK'} = 0;
			#| RESULT                | varchar(60)                                                        | NO   |     | NULL    |                |
			$dbref->{'RESULT'} = '';
			#| RELISTS               | tinyint(4)                                                         | NO   |     | 0       |                |
			$dbref->{'RELISTS'} = 0;
			#| THUMB                 | varchar(60)                                                        | NO   |     | NULL    |                |
			$dbref->{'THUMB'} = $ebref->{'ebay:prod_image1'};
			#| LOCK_GMT              | int(10) unsigned                                                   | NO   |     | 0       |                |
			$dbref->{'LOCK_GMT'} = 0;
			#| LOCK_PID              | int(10) unsigned                                                   | NO   | MUL | 0       |                |
			$dbref->{'LOCK_PID'} = 0;
			#| GALLERY_UPDATES       | int(11)                                                            | NO   |     | 0       |                |
			$dbref->{'GALLERY_UPDATES'} = 0;
			#| DISPATCHID            | int(11)                                                            | YES  | UNI | NULL    |                |
			## very important ensures uniqueness.
			$dbref->{'DISPATCHID'} = $le->id();	
			#| PRODTS                | int(11)                                                            | NO   |     | 0       |                |
			$dbref->{'PRODTS'} = $prodref->{'zoovy:prod_modified_gmt'};
			if (not defined $dbref->{'PRODTS'}) { $dbref->{'PRODTS'} = 0; }
			#| IS_SANDBOX            | tinyint(4)                                                         | NO   |     | 0       |                |
			$dbref->{'IS_SANDBOX'} = 0;
			#+-----------------------+--------------------------------------------------------------------+------+-----+---------+----------------+

			my ($pstmt) = &DBINFO::insert($udbh,'EBAY_LISTINGS',$dbref,insert=>1,sql=>1);
			print STDERR $pstmt."\n";
			if ($le->has_failed()) {
				}
			elsif ($udbh->do($pstmt)) {
				($UUID) = $udbh->selectrow_array("select last_insert_id()");
				}
			else {

##				started to develop some recovery code, but this wasn't actually the problem, but still might be useful in the future.
##				totally untested!
##
##				my $pstmt = sprintf("select ID from EBAY_LISTINGS where MID=%d and DISPATCHID=%d",$le->mid(),$le->id());
##				($UUID) = $udbh->selectrow_array($pstmt);
##				print "UUID: $UUID $pstmt\n";
##				die();
##				if ($UUID>0) {
##					push @{$MSGS}, "WARN|+It appears this dispatchid was previously inserted into the ebay database table.";
##					}
##				else {
					push @{$MSGS}, "ERROR|src=ISE|+Internal Error - could not determine last inserted database id";
##					}
				}

			if ($le->has_failed()) {
				}
			elsif ($UUID == -1) {
				push @{$MSGS}, "ERROR|src=ISE|retry=1|+Internal Error - Could not insert record into database";
				}
			else {
				if (not $le->set_target('UUID'=>$UUID)) {
					push @{$MSGS}, "ERROR|src=ISE|retry=1|+Internal Error - Could not update UUID in Listing events";
					}
				}

			}
		elsif ($VERB eq 'PREVIEW') {
			## no database stuff on a preview
			}
		elsif ($VERB eq 'UPDATE-LISTING') {
			## hmm.. not sure what to do here.
			my $MID = $le->mid();
			my $USERNAME = $le->username();
			my $pstmt = "select * from EBAY_LISTINGS where MID=$MID /* $USERNAME */ and EBAY_ID=".$udbh->quote($le->listingid());
			# print $pstmt."\n";
			($dbref) = $udbh->selectrow_hashref($pstmt);
	
			# print Dumper($dbref);
			$UUID = $dbref->{'ID'};

			# push @{$MSGS}, "WARN|+DEBUG TARGET:$TARGET SYNDICATED:$dbref->{'IS_SYNDICATED'} CHANNEL:$dbref->{'CHANNEL'}";
			if (($dbref->{'IS_SYNDICATED'}>0) || ($dbref->{'CHANNEL'} == -1)) {
				$TARGET = 'EBAY.SYND';
				}

			}
		elsif ($VERB eq 'FAIL') {
			## this causes a bunch of logic to be skipped
			}
		else {
			push @{$MSGS}, "ERROR|Unknown interior verb $VERB";
			}

		if ($UUID>0) {
			$FINALMSG{'uuid'} = $UUID;
			}
	
		## NOTE: at this point UUID *really* needs to be defined.

		if (($VERB eq 'PREVIEW') || ($VERB eq 'INSERT')) {} # both allowed to have $UUID of zero
		elsif (($VERB eq 'FAIL') || ($le->has_failed())) {
			}
		elsif (not defined $dbref) {
			## critical internal error
			push @{$MSGS}, "ERROR|src=ISE|+DBREF could not be loaded";
			}

		if ($UUID<=0) { $UUID = 0; }

		## NOTE: UUID is *NOT* the same as ebay UUID
		$UUID = int($UUID); 

		my $CATEGORY_FEATURES = {};
		my $CATEGORY_DETAIL_FILE = sprintf("/httpd/static/ebay/category-features/category-%d.yaml",int($ebref->{'ebay:category'}));
		if ($le->has_failed()) {
			}
		elsif (! -f $CATEGORY_DETAIL_FILE) {
			push @{$MSGS}, sprintf("WARN|+Category %d could not load category-features, this may cause other errors.",int($ebref->{'ebay:category'}));
			}
		else {
			$CATEGORY_FEATURES = YAML::Syck::LoadFile($CATEGORY_DETAIL_FILE);
			}

		my $RECYCLEID = undef;	# we'll figure you out later.



		## powerlister special settings.
		if (($VERB eq 'FAIL') || ($le->has_failed())) {
			}

		if (int($ebref->{'ebay:category'}) == 0) {
			$ebref->{'ebay:category'} = $dbref->{'CATEGORY'};
		   }
		if (($ebref->{'ebay:storecat'}) == 0) {
			$ebref->{'ebay:storecat'} = $dbref->{'STORECAT'};
		   }
		if (($ebref->{'ebay:qty'}) == 0) {
	  		$ebref->{'ebay:qty'} = $dbref->{'QUANTITY'};
	   	}

	
		my $html = undef;
		if ($le->has_failed()) {
			}
		elsif ($ebnsref->{'#v'} >= 201324) {
			## new style launch template
			print STDERR "PROFILE: $PROFILE\n";
			require TEMPLATE::KISSTLC;
			($html) = TEMPLATE::KISSTLC::render($le->username(),'EBAY',$PROFILE,'SKU'=>$le->sku(),'@MSGS'=>$MSGS,'*PRODUCT'=>$P);

			#$html =~ s/\<([\/]?[Mm][Ee][Tt][Aa].*?)\>/<!-- $1 -->/gs;	## ebay doesn't allow metas
			#$html =~ s/\<([\/]?[Bb][Aa][Ss][Ee].*?)\>/<!-- $1 -->/gs;	## ebay doesn't allow base urls

			$html = TEMPLATE::KISSTLC::ebayify_html($html);
			$html .= sprintf(qq~<!-- USERNAME:%s | PRODUCT:%s | EBAY_PROFILE:%s | DATE:%s | LISTING-EVENT:%d -->~,
				$le->username(),$le->sku(),$PROFILE,&ZTOOLKIT::pretty_date(time(),1),$le->id(),
				);
			

			## $html = 'spiffy new listing template goes here';
			}
		elsif ($ebnsref->{'ebay:template'} eq '') {
			$le->pooshmsg("ERROR|src=ZLAUNCH|+No ebay:template value specified in pre 201324 profile ($PROFILE)" );
			}

		## hmm.. unicode sequence stripping !?!
		if ($le->{'ATTEMPTS'}>0) {
			push @{$MSGS}, "INFO|+This is RETRY attempt ($le->{'ATTEMPTS'}) - so we'll engage unicode stripping!";
			$html = &ZTOOLKIT::stripUnicode($html);
			}
		# $html =~ s/return/r e t u r n/gi;

		if ($html =~ /<[Ii][Ff][Rr][Aa][Mm][Ee] /) {
			push @{$MSGS}, "ERROR|+Resulting HTML contains iFrame html tag -- which is NOT allowed by eBay.";
			}

		##
		## SANITY: at this point $html is built.
		##
	
		## Handle Catalog pieces
		my %xml = ();
		my $currency = 'USD';
		if ($ebref->{'ebay:category'} =~ /([\d]+)\.([\d]+)/) { 
			## handle ebay motors .100 categories.
			$xml{'#Site'} = $2; $ebref->{'ebay:category'} = $1;
			if ($xml{'#Site'}==100) { $dbref->{'IS_MOTORS'}=100; }
			if ($xml{'#Site'}==15) { $currency = 'AUD'; }
			}


		if ($le->has_failed()) {
			}
		elsif ($ebnsref->{'#v'} >= 201324) {
			foreach my $k (keys %{$ebnsref}) {
				if ($k =~ /Item\\(.*?)$/) {
					my $path = $k;  
					my $type = '';
					if ($k =~ /^(.*?)\\@(BOOLEAN|CURRENCY|ARRAY)$/) {
						$path = $1; $type = $2;
						}
					$path =~ s/\\/\./gs;

					if ($k =~ /Item\\ShippingDetails\\/) {
						## handled special.
						## Item\ShippingDetails\CalculatedShippingRate\OriginatingPostalCode
						## ==> BAD Item\ShippingDetails\InternationalShippingServiceOption\ShipToLocation\@ARRAY
						## Item\ShippingDetails\InsuranceDetails\InsuranceOption
						## Item\ShippingDetails\InsuranceDetails\InsuranceFee@CURRENCY
						## Item\ShippingDetails\InternationalInsuranceDetails\InsuranceOption
						## Item\ShippingDetails\InternationalInsuranceDetails\InsuranceFee@CURRENCY
						}
					elsif ($type eq 'BOOLEAN') {
						## ebay defines boolean as 'true' 'false'
						$xml{"$path"} = &XMLTOOLS::boolean($ebnsref->{$k});
						}
					elsif (($type eq 'CURRENCY') && ($path =~ /\.(.*?)$/)) {
						## return("<$attrib currencyID=\"USD\">".sprintf("%.2f",$var)."</$attrib>");
						$xml{"$path*"} = &XMLTOOLS::currency($1,0,$ebnsref->{$k});
						}
					elsif (($type eq 'ARRAY') && (ref($ebnsref->{$k}) ne 'ARRAY')) {
						warn "IGNORED $k because it was not an array -- ".Dumper($ebnsref->{$k})."\n";
						}
					elsif ($type eq 'ARRAY') {
						#$xml{"Item.PaymentMethods\$x"} = "Paypal";
						#$xml{"Item.PaymentMethods\$y"} = "Paypal";
						foreach my $val ( @{$ebnsref->{$k}} ) {
							## "Item.PaymentMethods\$Paypal
							if ($val eq '') {
								warn "skipped: $path\$$val (blank)\n";
								}
							else {
								warn "did $path\$$val = $val\n";
								$xml{sprintf('%s$%s',$path,$val)} = $val;
								}
							}
						}
					else {
						## copy this field verbatim
						if ($ebnsref->{$k} eq '') {
							warn "Skipped: $k because it was blank!\n";
							}
						else {
							## warn "xxxx[$type] $path = $ebnsref->{$k}\n";
							$xml{$path} = $ebnsref->{$k};
							}
						}
					}
				}
			}


		## when choosing eBay category, we show UPC/ISBN/EAN field in DVDs, Books, CDs cats
		## if was selected - pass to eBay	
		#12025	 	Search found too many matches with product identifier <026359294129>, type <UPC>        
		#if ($ebref->{'ebay:prod_upc'} eq '026359294129') {
	   #   }
		#elsif ($ebref->{'ebay:ext_pid_type'} and $ebref->{'ebay:ext_pid_value'}) {
		#	$xml{'Item.ExternalProductID.Value'} = $ebref->{'ebay:ext_pid_value'};
		#	$xml{'Item.ExternalProductID.Type'} = $ebref->{'ebay:ext_pid_type'};
		#	}

   	if ($ebref->{'ebay:prod_upc'} eq '026359294129') {
	      }
		elsif ($ebref->{'ebay:catalog'} eq 'BOOK' || $ebref->{'ebay:catalog'} eq 'DVD' || 
			$ebref->{'ebay:catalog'} eq 'VHS' || $ebref->{'ebay:catalog'} eq 'GAME' || $ebref->{'ebay:catalog'} eq 'CD') {

			## removed profane works
			$ebref->{'ebay:title'} =~ s/ fuck / F**K /igs;
			$ebref->{'ebay:title'} =~ s/ fucking / F***ing /igs;
			$ebref->{'ebay:title'} =~ s/ shit / S**T /igs;
	
			my $new = '';

			if ($ebref->{'ebay:catalog'} eq 'BOOK' && $ebref->{'ebay:prod_isbn'} ne '') {
				$xml{'Item.ExternalProductID.Value'} = $ebref->{'ebay:prod_isbn'};
				$xml{'Item.ExternalProductID.Type'} = 'ISBN';
				$ebref->{'ebay:category'} = 378;
				$new = 'Brand New';
				}
			elsif ($ebref->{'ebay:catalog'} eq 'VHS' && $ebref->{'ebay:prod_upc'} ne '') {
				$xml{'Item.ExternalProductID.Value'} = $ebref->{'ebay:prod_upc'};
				$xml{'Item.ExternalProductID.Type'} = 'UPC';
				$new = 'Brand New';
				}
			elsif ($ebref->{'ebay:catalog'} eq 'DVD' && $ebref->{'ebay:prod_upc'} ne '') {
				$xml{'Item.ExternalProductID.Value'} = $ebref->{'ebay:prod_upc'};
				$xml{'Item.ExternalProductID.Type'} = 'UPC';
				$ebref->{'ebay:category'} = 617;
				$new = 'Brand New';
				}
			else {
				$new = 'Brand New';
				}
			}	
		elsif ($ebref->{'ebay:do_preset'}) {

			if ($ebref->{'ebay:productid'} eq '') {
				require EBAYATTRIBS;
				my %datahash = ($ebref->{'ebay:prod_upc'}=>'');
		#		print STDERR "EBAYATTRIBS::resolve_productids: ".Dumper($le->username(),$ebref->{'ebay:catalog'},\%datahash,'',$ebref->{'ebay:password'});
				my ($titleref,$metaref) = &EBAYATTRIBS::resolve_productids($le->username(),$ebref->{'ebay:catalog'},\%datahash,'',$ebref->{'ebay:password'});
				$ebref->{'ebay:productid'} = $datahash{ $ebref->{'ebay:prod_upc'} };
			
				if ($titleref->{$ebref->{'ebay:prod_upc'}} eq '') {
					push @{$MSGS}, "WARN|+Preset for catalog [$ebref->{'ebay:catalog'}] KEY [$ebref->{'ebay:prod_upc'}] missing or not available";
					}
				elsif ($ebref->{'ebay:title'} eq '') {
					$ebref->{'ebay:title'} = substr($titleref->{$ebref->{'ebay:prod_upc'}},0,80);
					if (length($ebref->{'ebay:title'})<35) { $ebref->{'ebay:title'} .= uc($ebref->{'ebay:catalog'}).'!'; }
					}

				## Preset Category Rules
				if ($ebref->{'ebay:category'} eq '') {
					$ebref->{'ebay:catalog'} = uc($ebref->{'ebay:catalog'});
					if ($ebref->{'ebay:catalog'} eq 'DVD') { $ebref->{'ebay:category'} = 617; }
					if ($ebref->{'ebay:catalog'} eq 'BOOK') { 
						if ($ebref->{'ebay:category'} eq '') {
							$ebref->{'ebay:category'} = 378; 	## non-fiction books
							}
						}
					if ($ebref->{'ebay:catalog'} eq 'CD') { $ebref->{'ebay:category'} = 307; }
					if ($ebref->{'ebay:catalog'} eq 'VHS') { $ebref->{'ebay:category'} = 309; }
					}
	
				if ($ebref->{'ebay:attributeset'} eq '') {
					$ebref->{'ebay:attributeset'} = $ebref->{'ebay:preset_attrib'};
					}
			
				if ($metaref->{$ebref->{'ebay:prod_upc'}}->{'image'} ne '') {
					if ($ebref->{'ebay:prod_thumb'} eq '') { $ebref->{'ebay:prod_thumb'} = $metaref->{$ebref->{'ebay:prod_upc'}}->{'image'}; }
					if ($ebref->{'ebay:prod_image1'} eq '') { $ebref->{'ebay:prod_image1'} = $metaref->{$ebref->{'ebay:prod_upc'}}->{'image'}; }
					}
				}
			# print STDERR "PRESET PRODUCTID: $ebref->{'ebay:productid'} [$ebref->{'ebay:title'}] $ebref->{'ebay:prod_image1'} $ebref->{'ebay:prod_thumb'}\n";
			}
	
		if ($ebref->{'ebay:attributeset'} eq '') {
			$ebref->{'ebay:attributeset'} = $ebref->{'ebay:preset_attrib'};
			}

		my $galleryenable = 0;
		my $galleryurl;
	
		if ($ebref->{'ebay:use_gallery'} eq '_') { $ebref->{'ebay:use_gallery'} = '0'; }
		if ($ebref->{'ebay:use_gallery'} eq 'ON') { $ebref->{'ebay:use_gallery'} = 11; }

		if (($ebref->{'ebay:use_gallery'}>0) && ($ebref->{'ebay:prod_thumb'} eq '')) {
			## wants gallery, but has no image.
			$ebref->{'ebay:prod_thumb'} = $ebref->{'ebay:prod_image1'};
			}

		if (($ebref->{'ebay:use_gallery'}>0) && ($ebref->{'ebay:prod_thumb'} ne '')) {
			## was 96,96
			$galleryurl = &ZOOVY::mediahost_imageurl($le->username(),$ebref->{'ebay:prod_thumb'},0,0,'FFFFFF',0,'jpg');
			$galleryenable = 1;
			## bitwise: 1=auction, 2=fixed, 8=store
			if ($dbref->{'CLASS'} eq 'STORE') { $galleryenable = (int($ebref->{'ebay:use_gallery'}) & 8)?8:0; }
			elsif ($dbref->{'CLASS'} eq 'FIXED') { $galleryenable = (int($ebref->{'ebay:use_gallery'}) & 2)?2:0; }
			else { $galleryenable = (int($ebref->{'ebay:use_gallery'}) & 1)?1:0; }
			} 
		else {
			## NOTE: this must be blank, because if we send eBay *ANYTHING* related to the gallery they enable it.
			$galleryurl = '';
			$galleryenable = 0;
			if ($::DEBUG) { warn "($ebref->{'ebay:use_gallery'}>0) && ($ebref->{'ebay:prod_thumb'} ne '')"; }
			# die();
			}

		if ($ebref->{'ebay:feature_border'}) { $xml{'Item.feature_border*'} = "<ListingEnhancement>Border</ListingEnhancement>"; }
		if ($ebref->{'ebay:feature_bold'}) { $xml{'Item.feature_boldtitle*'} = "<ListingEnhancement>BoldTitle</ListingEnhancement>"; }
		if ($ebref->{'ebay:feature_featured'}) { $xml{'Item.feature_featured*'} = "<ListingEnhancement>Featured</ListingEnhancement>"; }
		if ($ebref->{'ebay:feature_highlight'}) { $xml{'Item.feature_highlight*'} = "<ListingEnhancement>Highlight</ListingEnhancement>"; }
		if ($ebref->{'ebay:feature_homepagefeatured'}) { $xml{'Item.feature_homepagefeatured*'} = "<ListingEnhancement>HomePageFeatured</ListingEnhancement>"; }
		if ($ebref->{'ebay:feature_propack'}) { $xml{'Item.feature_propack*'} = "<ListingEnhancement>ProPackBundle</ListingEnhancement>"; }
		if ($ebref->{'ebay:feature_valuepack'}) { $xml{'Item.feature_valuepack*'} = "<ListingEnhancement>ValuePackBundle</ListingEnhancement>"; }
		if ($ebref->{'ebay:feature_propackplus'}) { $xml{'Item.feature_propackplus*'} = "<ListingEnhancement>ProPackPlusBundle</ListingEnhancement>"; }
	
		## other Type: Half, PersonalOffer
		if ($dbref->{'IS_SYNDICATED'}>0) {  
			$dbref->{'CLASS'} = 'STORE'; 
			}	## hmm... (somehow this is set to FIXED)



		if ((defined $dbref->{'EBAY_ID'}) && ($dbref->{'EBAY_ID'}>0)) {
			$xml{'Item.ItemID'} = $dbref->{'EBAY_ID'};
			}
		elsif (($VERB eq 'REFRESH') || ($VERB eq 'UPDATE-LISTING')) {
			push @{$MSGS}, "ERROR|+EBAY_ID was not set on REFRESH";
			}
		elsif ((defined $RECYCLEID) && ($RECYCLEID>0)) {
			$xml{'#Verb'} = 'RelistItem';
			$xml{'Item.ItemID'} = $RECYCLEID;
			if (not defined $xml{'Item.BuyItNowPrice*'}) { $xml{'Item.BuyItNowPrice*'} = &XMLTOOLS::currency('BuyItNowPrice',0,$currency);	}
			if (not defined $xml{'Item.ReservePrice*'}) { $xml{'Item.ReservePrice*'} = &XMLTOOLS::currency('ReservePrice',0,$currency); }
			print STDERR "Running RelistItem! [$RECYCLEID]\n";

                ## OKAY SO WE'LL FLAG IT AS RECYCLED NOW (BUT IT REALLY HASN'T BEEN YET)
	      $dbref->{'RECYCLED_ID'} = $RECYCLEID;
			my $pstmt = "update RECYCLE_BIN set RECYCLED_GMT=$^T,RELISTED_EBAY_ID=0,ATTEMPTS=ATTEMPTS+1 where EBAY_ID=".$udbh->quote($RECYCLEID)." and MID=$dbref->{'MID'} /* $dbref->{'MERCHANT'} */ limit 1";
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			}

		$xml{'Item.Description'} = $html;

		## verboten words.
		my @VERBOTEN_TERMS = ('google checkout', 'money order');
		foreach my $shallnotbespoken (@VERBOTEN_TERMS) {
			if ($html =~ /$shallnotbespoken/is) {
				push @{$MSGS}, "ERROR|+You cannot have the word \"$shallnotbespoken\" in your listing - it is not allowed.";
				}
			}

	
		if ($VERB eq 'PREVIEW') {
			}	
		elsif ($UUID>0) {
			## we already have an eBay item (probably a ReviseItem call)
			my $MID = $le->mid();
			$xml{'Item.UUID'} = sprintf("%08d%024d",$MID,$UUID);
			}
		else {
			## updating an existing listing.
			}

		$xml{'Item.ThirdPartyCheckout'} = 'false';
		$xml{'Item.ApplicationData'} = $dbref->{'ID'};
		$xml{'Item.CategoryBasedAttributesPrefill'} = 'true';
		$xml{'Item.CategoryMappingAllowed'} = 'true';
		# $xml{'Item.HitCounter'} = '';
		$xml{'Item.Currency'} = $currency;

		$xml{'Item.Country'} = 'US';
		if ($le->username() eq 'pricematters') {
			push @{$MSGS}, sprintf("WARN|+changed origin country to canada for user pricematters");
			$xml{'Item.Country'} = 'CA'; 
			}


		$xml{'Item.ConditionID'} = 0;
		if ($eb2->global_shortcut('default_new')) {
			## default to "new" if that is the global preference
			$xml{'Item.ConditionID'} = '1000';
			}
	
		if ($ebref->{'ebay:conditionid'} ne '') {
			$xml{'Item.ConditionID'} = int($ebref->{'ebay:conditionid'});
			if ($ebref->{'ebay:conditionid'}==0) {
				push @{$MSGS}, sprintf("ERROR|+Detected invalid ebay:conditionid field \"%s\"",$ebref->{'ebay:conditionid'});
				}
			}
		elsif ($prodref->{'zoovy:prod_condition'} eq '') {
			## not set - it's "new"
			}
		elsif ($prodref->{'zoovy:prod_condition'} =~ /used/i) {
			# default to used if the word used appears
			push @{$MSGS}, "INFO|+Detected 'used' prod_condition, setting ConditionID to used";
			$xml{'Item.ConditionID'} = 3000;
			}
		elsif ($prodref->{'zoovy:prod_condition'} =~ /refurb/i) {
			# default to used if the word used appears
			push @{$MSGS}, "INFO|+Detected 'refurb' prod_condition, setting ConditionID to Refurbished";
			$xml{'Item.ConditionID'} = 2000;
			}

		if ($xml{'Item.ConditionID'} == 0) {
			push @{$MSGS}, "ERROR|code=9000|src=MKT-ACCOUNT|hint=You can default all items to NEW by changing the preference in Setup/eBay/Global Preferences|+The condition (new,used,etc.) of this product could NOT be ascertained from any field. Condition must be specified to launch a product.";
			}

		## Profile Fields
		# $xml{'Item.ApplyShippingDiscount'} = &XMLTOOLS::boolean($ebref->{'ebay:applyshippingdiscount'});	

		if ($ebref->{'ebay:lotsize'} ne '') { 
			$xml{'Item.LotSize'} = $ebref->{'ebay:lotsize'};
			}


		if (not $le->has_failed()) {
			if (int($ebref->{'ebay:dispatchmaxtime'})>0) {
				$xml{'Item.DispatchTimeMax'} = int($ebref->{'ebay:dispatchmaxtime'});
				if ($xml{'Item.DispatchTimeMax'}==0) {
					push @{$MSGS}, 'WARN|+ebay:dispatchmaxtime was set to zero (invalid) and was increased to 1 day';
					$xml{'Item.DispatchTimeMax'} = 1;
					}
				}
	
			if (defined $ebref->{'ebay:getitfast'}) {
				$xml{'Item.GetItFast'} = &XMLTOOLS::boolean($ebref->{'ebay:getitfast'});	
				}
	
			if (defined $ebref->{'ebay:now_and_new'}) {
				$xml{'Item.NowAndNew'} = &XMLTOOLS::boolean($ebref->{'ebay:now_and_new'});
				}
			}


		## second chance offers
		# if ((defined $ebref->{'ebay:autosecond'}) && ($ebref->{'ebay:autosecond'} eq '1')) {
		if ($ebref->{'ebay:minsellprice'}>0) {
			$dbref->{'IS_SCOK'} = sprintf("%.2f",$ebref->{'ebay:minsellprice'});
			}

		## instantpay instant_pay autopay
		if (($CLASS eq 'STORE') || ($CLASS eq 'FIXED')) {
			## STORE/FIXED PRICE can always have autopay
			}
		elsif (&ZOOVY::is_true($xml{'Item.AutoPay'},0)) {
			## autopay not compatible with non-fixedprice or non-buy it now.
			if ($ebref->{'ebay:buyitnow_price'} == 0) {
				push @{$MSGS}, "WARN|+Disable auto-payment because this is not a STORE or FIXED price item and does not have BUY IT NOW";
				$ebref->{'Item.AutoPay'} = &XMLTOOLS::boolean(0);
				}
			}


		if (not $le->has_failed()) {
			my ($imgh, $imgw) = (0,0);
			if (($ebref->{'ebay:prod_image1_dim'} ne '') && ($ebref->{'ebay:prod_image1_dim'} =~ /^([\d]+)x([\d]+)$/)) {
				($imgw,$imgh) = ($1,$2);
				}

			if (defined($ebref->{'ebay:prod_image1'})) { $ebref->{'ebay:prod_image1'} = &ZOOVY::mediahost_imageurl($le->username(),$ebref->{'ebay:prod_image1'},$imgh,$imgw,'FFFFFF',0,'jpg',1); }
			if ($ebref->{'ebay:prod_image1'} eq '') { $ebref->{'ebay:prod_image1'} = 'http://static.zoovy.com/graphics/general/blank.gif'; }
			$ebref->{'ebay:prod_image1'} =~ s/\.jpg\.jpg$/\.jpg/g;		# fix image lib screw up
	
			## Item Specific Fields
			$xml{'Item.PictureDetails.Picture'} = 'VendorHostedPicture';
			$xml{'Item.PictureDetails.PictureURL'} = $ebref->{'ebay:prod_image1'};

			$xml{'Item.Title'} = substr($ebref->{'ebay:title'},0,80);
			if ($xml{'Item.Title'} eq '') {
				push @{$MSGS}, "ERROR|+eBay Title is not set, will not continue with launch.";
				}

			if ($ebref->{'ebay:subtitle'} ne '') {
				$xml{'Item.SubTitle'} = substr($ebref->{'ebay:subtitle'},0,80);
				}
			elsif ($RECYCLEID>0) {
				$xml{'Item.Subtitle*'} = '<Subtitle action="remove"/>';
				}
			}

		##
		## item_condition is set in the profile as a Default if zoovy:prod_condition is NOT set.	
		##		note: eventually we may need to map more complex types e.g. "damaged" to "used"
		##				for now we'll assume ebay does that.
		#if ($ebref->{'ebay:prod_condition'} ne '') {}	# use prod_condition!
		#elsif ($ebref->{'ebay:item_condition'} eq 'New') { $ebref->{'ebay:prod_condition'} = 'New'; }
		#elsif ($ebref->{'ebay:item_condition'} eq 'Used') { $ebref->{'ebay:prod_condition'} = 'Used'; }
		#if ($ebref->{'ebay:prod_condition'} ne '') {
		### NOTE: This is apparently only valid for MEDIA categories (fuckers)
		#	$xml{'Item.LookupAttributeArray.LookupAttribute.Name'} = 'Condition';
		#	$xml{'Item.LookupAttributeArray.LookupAttribute.Value'} = $ebref->{'ebay:prod_condition'};
		#	}
	
		my $HAS_INV_OPTIONS = 0;
		if ($P->has_variations('inv')) { $HAS_INV_OPTIONS++; }
	
		if (($HAS_INV_OPTIONS) && ($TARGET ne 'EBAY.SYND')) {
			push @{$MSGS}, "ERROR|+Inventoriable Options/eBay Variations are ONLY compatible with syndication.";
			}

	
		if ($HAS_INV_OPTIONS) {
			## POGS SUPPORT: & 16 means has inv. options
			## options have a *VERY* different structure, and the code which generates them is in a module because
			## it is shared with the EBAY2::sync_inventory  (because a reviseitem is necessary when changing inventory
			## in order to add/remove items)
			&LISTING::EBAY::add_options_to_request($P,\%xml,$MSGS);
			$FINALMSG{'qty'} = 9999;
			$FINALMSG{'has_options'}++;
			$FINALMSG{'reserve_qty'} = 0;
			}
		else {
			## single non-variation item
			if ($TARGET eq 'EBAY.AUCTION') {
				## we need to remove this, they don't allow the dutch auction anymore .. since 2009
				$xml{'Item.Quantity'} = $ebref->{'ebay:qty'};
				}
			elsif ((defined $ebref->{'ebay:fixed_qty'}) && (int($ebref->{'ebay:fixed_qty'})==0)) {
				## no, this is not valid. 
				push @{$MSGS}, "ERROR|+Fixed Quantity was not set or zero, cannot launch.";
				}
			elsif (($TARGET eq 'EBAY.SYND') || ($TARGET eq 'EBAY.FIXED')) {
				$xml{'Item.Quantity'} = -1;
				}

			if ($xml{'Item.Quantity'} == -1) {
				my ($AVAILABLE) = $INV2->summary('@PIDS'=>[ $le->pid() ], 'COMBINE_PIDS'=>1)->{ $le->pid() }->{'AVAILABLE'};
				$xml{'Item.Quantity'} = $AVAILABLE; # ($instock-$reserve);

				if ((defined $ebref->{'ebay:fixed_qty'}) && (int($ebref->{'ebay:fixed_qty'})>0)) {
					if ($ebref->{'ebay:fixed_qty'}<$AVAILABLE) {
						push @{$MSGS}, sprintf("INFO|+Available [%d] was reduced to Fixed Quantity [%d].",$AVAILABLE,$ebref->{'ebay:fixed_qty'});
						$xml{'Item.Quantity'} = $ebref->{'ebay:fixed_qty'};
						}
					}


				if ($xml{'Item.Quantity'}<=0) {
					push @{$MSGS}, "ERROR|+Insufficient Store Inventory: $xml{'Item.Quantity'}";
					}
				}

			#if ($le->username() eq 'kcint') {
			#	## kcint is a pain in the ass, that's why.
			#	push @{$MSGS}, "WARN|+KCINT Inventory forced to 1 (ask fred or brian why if you dont know)";
			#	$xml{'Item.Quantity'} = 1;
			#	}

			$FINALMSG{'qty'} = $xml{'Item.Quantity'};
			$FINALMSG{'reserve_qty'} = $xml{'Item.Quantity'};
			if ($TARGET eq 'EBAY.SYND') {
				$FINALMSG{'reserve_qty'} = 0;
				}
			}
	
		$xml{'Item.PrivateListing'} = ($ebref->{'ebay:list_private'})?'true':'false';
		$xml{'Item.PrivateNotes'} = "SKU:".$le->sku();  
		      
		if (int($ebref->{'ebay:storecat'})>=0) {
			#   0=Not an eBay Store item
			#   1=Other
			#    2=Category 1
			#    3=Category 2
			#    ...
			#    19=Category 18
			#    20=Category 19
			#if ($ebref->{'ebay:storecat'}<100) { $ebref->{'ebay:storecat'}++; }	## NOTE: we treat "0" as other, so category 1 can be 1 (duh!)
			$xml{'Item.Storefront.StoreCategoryID'} = $ebref->{'ebay:storecat'};
			if ($xml{'Item.Storefront.StoreCategoryID'}<=100) { $xml{'Item.Storefront.StoreCategoryID'}++; } 
			}
	
		if (int($ebref->{'ebay:storecat2'})>0) {
			## second eBay store category
			#if ($ebref->{'ebay:storecat2'}<100) { $ebref->{'ebay:storecat2'}++; }	## NOTE: we treat "0" as other, so category 1 can be 1 (duh!)
			$xml{'Item.Storefront.StoreCategory2ID'} = $ebref->{'ebay:storecat2'};
			if ($xml{'Item.Storefront.StoreCategory2ID'}<=100) { $xml{'Item.Storefront.StoreCategory2ID'}++; } 
			}
	

		## 
		## This will merge zoovy attributes in eBay custom properties - a very cool feature.
		##
		if ($le->has_failed()) {
			}
		else {

			my %NameValueList;
			## SANITY: at this point NameValueList is a hashref of custom attributes we loaded, or we will create our own.
			my %MAPS = (
				'Manufacturer'=>'zoovy:prod_mfg',
				'Manufacturer Part Number'=>'zoovy:prod_mfgid',
				'Brand'=>'zoovy:prod_brand',
				'Condition'=>'zoovy:prod_condition',
				'Width'=>'zoovy:prod_width',
				'Height'=>'zoovy:prod_height',
				'Length'=>'zoovy:prod_length',
				'UPC'=>'zoovy:prod_upc',
				'EAN'=>'zoovy:prod_ean',
				'ISBN'=>'zoovy:prod_isbn',
				'Color'=>'zoovy:prod_color',
				'Size'=>'zoovy:prod_size',
				'ESRB Rating'=>'zoovy:prod_esrb_rating',
				'MPAA Rating'=>'zoovy:prod_mpa_rating',
				'Author'=>'zoovy:prod_author',
				'MSRP'=>'zoovy:prod_msrp',
				);
			foreach my $k (keys %MAPS) {
				if ((defined $prodref->{ $MAPS{$k} }) && ($prodref->{$MAPS{$k}} ne '')) {
					$NameValueList{$k} = $prodref->{ $MAPS{$k} };
					}
				}

			## extract any wikibullets from the contents
			my $contents = $prodref->{'zoovy:prod_features'}."\n".$prodref->{'zoovy:prod_desc'}."\n".$prodref->{'zoovy:prod_detail'};
			foreach my $bulletset (@{&ZTOOLKIT::extractWikiBullets($contents)}) {
				print STDERR Dumper($bulletset)."\n";
				if (length($bulletset->[0])>40) {
					push @{$MSGS}, "WARN|+Item Specific Tag \"$bulletset->[0]\" is too long (max 40) and was discarded.";
					}
				elsif (length($bulletset->[1])>50) {
					push @{$MSGS}, "WARN|+Item Specific Value for Tag \"$bulletset->[0]\" is too long (max 50) and was discarded.";
					}
				elsif (not defined $NameValueList{ $bulletset->[0] }) {
					$NameValueList{ $bulletset->[0] } = $bulletset->[1];
					}
				}

			if ($prodref->{'ebay:itemspecifics'} ne '') {
				## new field from 201324 and beyond..
				foreach my $line (split(/[\n\r]+/,$prodref->{'ebay:itemspecifics'})) {
					next if ($line eq '');
					my ($key,$value) = split(/:[\s]*/,$line,2);
					$NameValueList{ $key } = $value;
					}
				}


			## open F, ">/tmp/namevalue"; print F Dumper(\%NameValueList); close F;

			## this is a little wonky, but it's how we need to format it for ebay
			## NOTE: not sure if ebay uses ItemSpecifics anymore.
			my $i = 0;
			foreach my $k (keys %NameValueList) {
				## push @{$is}, { 'Name'=>[ &ZTOOLKIT::stripUnicode($k) ], 'Value'=>[ &ZTOOLKIT::stripUnicode($NameValueList{$k}) ] };
				$xml{"Item.ItemSpecifics.NameValueList#$i.Name"} = $k;
				#$xml{"Item.ItemSpecifics.NameValueList#$i.Value"} = $NameValueList{$k};

				## handle multi-select fields - like "Value1||Value2||Value3"
				## we need to make separate <value>Value1</value> ... nodes - so let's split
				my @values = split /\|\|/,$NameValueList{$k};
				@values = splice(@values,0,30); ## eBay allows 30 values max for multilesect
				my $j = 0;
				foreach my $specval (@values) {
					$xml{"Item.ItemSpecifics.NameValueList#$i.Value\$$j"} = $specval;
					$j++;
					}
				$i++;


				if ($k eq 'EAN') {
					## ProductID, ProductReferenceID, ISBN, UPC, EAN, BrandMPN, and/or TicketListingDetails
					## UPC must always be sent. When EAN is sent UPC must be sent as 'Does Not Apply' 
					$xml{"Item.ProductListingDetails.EAN"} = $values[0];
					$xml{"Item.ProductListingDetails.UPC"} = 'Does Not Apply';
					}
				elsif ($k eq 'UPC') {
					if (length($values[0])==13) {
						$xml{"Item.ProductListingDetails.EAN"} = $values[0];
						$xml{"Item.ProductListingDetails.UPC"} = 'Does Not Apply';
						}
					else {
						$xml{"Item.ProductListingDetails.UPC"} = $values[0];
						}
					}

				}



			}


	
		# push @{$MSGS}, "TRACE|+TARGET IS:$TARGET";
		if (($VERB eq 'FAIL') || ($le->has_failed())) {
			}	
		elsif ($TARGET eq 'EBAY.AUCTION') {
			if ($VERB eq 'INSERT') { $xml{'#Verb'} = 'AddItem'; }
			if ($VERB eq 'UPDATE-LISTING') { $xml{'#Verb'} = 'ReviseItem'; }
			if ($VERB eq 'PREVIEW') { $xml{'#Verb'} = 'VerifyAddItem'; }
			if (($xml{'#Verb'} eq 'AddItem') && ($xml{'Item.ItemID'}>0)) { 
				$xml{'#Verb'} = 'ReviseItem';
				push @{$MSGS}, "WARN|+Appears to be a duplicate INSERT request for $xml{'Item.ItemID'}, changing to ReviseItem";
				}
			if (($xml{'#Verb'} eq 'ReviseItem') && ($xml{'Item.ItemID'}>0)) {
				## we don't need a UUID on ReviseItem because the listing already exists.
				delete $xml{'Item.UUID'}; 
				}
	
			if ($xml{'#Verb'} ne 'ReviseItem') {
				## you cannot revise a listing type.
				$xml{'Item.ListingType'} = 'Chinese';
				}
			
			if ($ebref->{'ebay:qty'}>1) { 
				# dutch auction is type 2
				$xml{'Item.ListingType'} = 'Dutch'; 
				delete $xml{'Item.ReservePrice*'};
				}

			if ($ebref->{'ebay:start_price'} == 0) {
				push @{$MSGS}, "ERROR|+Starting price is zero dollars - which is not valid for auctions.";
				}

			if (int($ebref->{'ebay:duration'})>0) {
				$xml{'Item.ListingDuration'} = 'Days_'.$ebref->{'ebay:duration'};
				}
		
	
			if ($HAS_INV_OPTIONS) {
				## Inventoriable options are not compatible with auctions
				push @{$MSGS}, "ERROR|+Products with inventoriable options (variations) are not compatible with eBay";
				}
			else {
			  	$xml{'Item.StartPrice*'} = &XMLTOOLS::currency('StartPrice',$ebref->{'ebay:start_price'},$currency);
				}
	
	
			$ebref->{'ebay:reserve_price'} += 0;
		  	$xml{'Item.ReservePrice*'} = &XMLTOOLS::currency('ReservePrice',$ebref->{'ebay:reserve_price'},$currency);
	
	      if ($ebref->{'ebay:buyitnow_price'}==-1) {
				push @{$MSGS}, "DEBUG|+ebay:buyitnow_price was set to -1, so we will use zoovy:base_price";
				$ebref->{'ebay:buyitnow_price'} = $prodref->{'zoovy:base_price'};
				}
			if ($ebref->{'ebay:buyitnow_price'}>0) {
				$xml{'Item.BuyItNowPrice*'} = &XMLTOOLS::currency('BuyItNowPrice',$ebref->{'ebay:buyitnow_price'},$currency);
				}
	
			}
		elsif ($TARGET eq 'EBAY.FIXED') {
			## NOTE: -1 is GTC
			if (not defined $ebref->{'ebay:fixed_qty'}) {
				$ebref->{'ebay:fixed_qty'}=1;
				push @{$MSGS}, "WARN|+Fixed Quantity was not set, defaulting to qty 1";
				}

			my $duration = '';
			if ($VERB eq 'INSERT') { $xml{'#Verb'} = 'AddFixedPriceItem'; }
			if ($VERB eq 'UPDATE-LISTING') { $xml{'#Verb'} = 'ReviseFixedPriceItem'; }
			if ($VERB eq 'PREVIEW') { $xml{'#Verb'} = 'VerifyAddFixedPriceItem'; }
			
			if (($xml{'#Verb'} eq 'AddFixedPriceItem') && ($xml{'Item.ItemID'}>0)) { 
				$xml{'#Verb'} = 'ReviseFixedPriceItem';
				push @{$MSGS}, "WARN|+Appears to be a duplicate INSERT request for $xml{'Item.ItemID'}, changing to ReviseFixedPriceItem";
				}
			if (($xml{'#Verb'} eq 'ReviseFixedPriceItem') && ($xml{'Item.ItemID'}>0)) {
				## we don't need a UUID on ReviseFixedPriceItem because the listing already exists.
				delete $xml{'Item.UUID'}; 
				}
			my @VALID_DURATIONS = ();
	
			@VALID_DURATIONS = ('ebay:fixed_duration',[-1,'30','10','7','5','3','1']);
			$duration = $ebref->{'ebay:fixed_duration'};
			if ($duration eq 'GTC') { $duration = -1; }

			my ($previous_listingid,$previous_ooid) = $eb2->sku_has_gtc($le->sku());
			if (not $previous_listingid) {
				## yeehoo, no previous listing!
				}
			elsif ($VERB eq 'UPDATE-LISTING') {
				## we're updating an existing listing.
				}
			elsif ($previous_listingid > 0) {
				push @{$MSGS}, sprintf("ERROR|+SKU %s already has a existing GTC listing: %s (this listing will likely violate eBay rules)",$le->sku(),$previous_listingid);
				}
	
			my $matches = 0;
			foreach my $matchval (@{$VALID_DURATIONS[1]}) {
				if ($duration == $matchval) { $matches++; }
				}

			if (not $matches) {
				if ($duration eq '') {
					push @{$MSGS}, sprintf("ERROR|+Sorry, but the duration field %s is empty",$VALID_DURATIONS[0]);
					}
				else {
					push @{$MSGS}, sprintf("ERROR|+Sorry, but the duration field %s did not have a valid value \"%s\" (valid: %s)",$VALID_DURATIONS[0],$duration,join(",",@{$VALID_DURATIONS[1]}));
					}
				}		
			elsif ($duration == -1) {
				## GTC is treated as value. Doh!
				$xml{'Item.ListingDuration'} = 'GTC';
				$FINALMSG{'duration'} = -1;
				}
			elsif ($duration<=30) { 
				$xml{'Item.ListingDuration'} = sprintf('Days_%d',$duration);
				$FINALMSG{'duration'} = $duration;
				}
			else {
				push @{$MSGS}, sprintf("ERROR|+Sorry, but the duration field %s is invalid \"%s\"",$duration);
				}
	
			#if (($TARGET eq 'EBAY.STORE') && ($xml{'#Verb'} eq 'ReviseFixedPriceItem')) {
			#	## 10026: Duration cannot be revised on store items.
			#	push @{$MSGS}, sprintf("WARN|+Duration cannot be updated on store listings (leaving as is)");
			#	delete $xml{'Item.ListingDuration'};
			#	$FINALMSG{'duration-as-is'}++;
			#	}

				
	
			# push @{$MSGS}, "WARN|FRED starting price is [$ebref->{'ebay:fixed_price'}]";
			if ($P->has_variations('inv')>0) {
	          push @{$MSGS}, "DEBUG|+Inventoriable Variations detected, ignoring ebay:fixed_price";
				}
	      elsif ($ebref->{'ebay:fixed_price'}==-1) {
				push @{$MSGS}, "DEBUG|+ebay:fixed_price was set to -1, so we will use zoovy:base_price";
				$ebref->{'ebay:fixed_price'} = $prodref->{'zoovy:base_price'};
				}
			elsif ($ebref->{'ebay:fixed_price'} eq '') {
	          push @{$MSGS}, "ERROR|+The fixed price (ebay:fixed_price) is blank/empty";
				}
	      elsif (int($ebref->{'ebay:fixed_price'})==0) {
				if ($ebref->{'ebay:fixed_price'} =~ /[^\d\.]+/) {
					push @{$MSGS}, "WARN|+Non-numeric content from ebay:fixed_price '$ebref->{'ebay:fixed_price'}'";
					}

				if (int($ebref->{'ebay:fixed_price'})==0) {
					push @{$MSGS}, "ERROR|+The fixed price (ebay:fixed_price=$ebref->{'ebay:fixed_price'}) is zero dollars.";
					}
				}

	
			$xml{'Item.StartPrice*'} = &XMLTOOLS::currency('StartPrice',$ebref->{'ebay:fixed_price'},$currency);
	
			delete $xml{'Item.ReservePrice*'};
	    	delete $xml{'Item.BuyItNowPrice*'};
			}
		elsif ($TARGET eq 'EBAY.SYND') {
			my $duration = '';
			if ($VERB eq 'INSERT') { $xml{'#Verb'} = 'AddFixedPriceItem'; }
			if ($VERB eq 'UPDATE-LISTING') { $xml{'#Verb'} = 'ReviseFixedPriceItem'; }
			if ($VERB eq 'PREVIEW') { $xml{'#Verb'} = 'VerifyAddFixedPriceItem'; }
						
			if (($xml{'#Verb'} eq 'AddFixedPriceItem') && ($xml{'Item.ItemID'}>0)) { 
				$xml{'#Verb'} = 'ReviseFixedPriceItem';
				push @{$MSGS}, "WARN|+Appears to be a duplicate INSERT request for $xml{'Item.ItemID'}, changing to ReviseFixedPriceItem";
				}
			if (($xml{'#Verb'} eq 'ReviseFixedPriceItem') && ($xml{'Item.ItemID'}>0)) {
				## we don't need a UUID on ReviseFixedPriceItem because the listing already exists.
				delete $xml{'Item.UUID'}; 
				}

			my ($previous_listingid,$previous_ooid) = (undef,undef);
			if ($xml{'#Verb'} ne 'ReviseFixedPriceItem') {
				## before we even attempt to go to ebay, lets check our own house first.
				($previous_listingid,$previous_ooid) = $eb2->sku_has_gtc($le->sku());
				}

			if (not $previous_listingid) {
				## yeehoo, no previous listing!
				}
			elsif ($previous_ooid == $UUID) {
				## we're looking at ourslves, so we don't need to throw an error.
				}
			elsif ($VERB eq 'UPDATE-LISTING') {
				## we're updating an existing listing.
				}
			elsif ($previous_listingid > 0) {
				push @{$MSGS}, sprintf("ERROR|+SKU %s already has a existing fixed price listing: %s (syndication will not violate eBay rules)",$le->sku(),$previous_listingid);
				}
			$xml{'Item.ListingDuration'} = 'GTC';
			$FINALMSG{'duration'} = -1;
	
			# push @{$MSGS}, "WARN|FRED starting price is [$ebref->{'ebay:fixed_price'}]";
			if ($P->has_variations('inv')>0) {
	          push @{$MSGS}, "DEBUG|+Inventoriable Variations detected, ignoring ebay:fixed_price";
				}
	      elsif ($ebref->{'ebay:fixed_price'}==-1) {
				push @{$MSGS}, "DEBUG|+ebay:fixed_price was set to -1, so we will use zoovy:base_price";
				$ebref->{'ebay:fixed_price'} = $prodref->{'zoovy:base_price'};
				}
			elsif ($ebref->{'ebay:fixed_price'} eq '') {
	          push @{$MSGS}, "ERROR|+The fixed price (ebay:fixed_price) is blank/empty";
				}
	      elsif (int($ebref->{'ebay:fixed_price'})==0) {
				if ($ebref->{'ebay:fixed_price'} =~ /[^\d\.]+/) {
					push @{$MSGS}, "WARN|+Non-numeric content from ebay:fixed_price '$ebref->{'ebay:fixed_price'}'";
					}

				if (int($ebref->{'ebay:fixed_price'})==0) {
					push @{$MSGS}, "ERROR|+The fixed price (ebay:fixed_price=$ebref->{'ebay:fixed_price'}) is zero dollars.";
					}
				}
	
			if (not $HAS_INV_OPTIONS) {
				## StartPrice should not be set when we are using Variations
				$xml{'Item.StartPrice*'} = &XMLTOOLS::currency('StartPrice',$ebref->{'ebay:fixed_price'},$currency);
				}
	
			delete $xml{'Item.ReservePrice*'};
	    	delete $xml{'Item.BuyItNowPrice*'};

			# print Dumper(\%info); die("TARGET:$TARGET VERB:$VERB");
			}
		else {
			push @{$MSGS}, "ERROR|src=ISE|+Unknown Target \"$TARGET\" (this is most likely an internal zoovy error)";
			}
	
		if (($VERB eq 'FAIL') || ($le->has_failed())) {
			}	
		else {		
			$xml{'Item.PictureDetails.GalleryType'} = ($galleryenable>0)?'Gallery':'None';
			if ($ebref->{'ebay:featured'} eq '') { $ebref->{'ebay:featured'} = '0'; }
			if (&ZOOVY::is_true($ebref->{'ebay:featured'})) { 
				$xml{'Item.PictureDetails.GalleryType'} = 'Featured';
				}
		   elsif (&ZOOVY::is_true($ebref->{'ebay:feature_galleryfirst'})) {
		      $xml{'Item.PictureDetails.GalleryType'} = 'Featured';
		      }
			$xml{'Item.PictureDetails.GalleryURL'} = $galleryurl;
			## eBay doesn't accept blank gifs into the gallery
			if ($xml{'Item.PictureDetails.GalleryURL'} =~ /images\/blank\.gif$/) { $xml{'Item.PictureDetails.GalleryURL'} = ''; }
			if ($xml{'Item.PictureDetails.GalleryURL'} eq '') { 
				$xml{'Item.PictureDetails.GalleryType'} = 'None';
				delete $xml{'Item.PictureDetails.GalleryURL'}; 
				if ($RECYCLEID>0) { $xml{'Item.PictureDetails.GalleryType'} = 'None'; }
				}
			# only on US site
	
			$xml{'Item.PrimaryCategory.CategoryID'} = int($ebref->{'ebay:category'});
			if ($ebref->{'ebay:category'} eq '') {
				push @{$MSGS}, "ERROR|+Primary Category not set";
				}
			if (int($ebref->{'ebay:category2'})>0) {
				$xml{'Item.SecondaryCategory.CategoryID'} = int($ebref->{'ebay:category2'});
				}
			$xml{'Item.SKU'} = $le->sku();
			if ($ebref->{'ebay:sku'} ne '') {
				push @{$MSGS}, "WARN|+Alternate SKU was specified in product.";
				$xml{'Item.SKU'} = $ebref->{'ebay:sku'};		
				}
			$xml{'Item.InventoryTrackingMethod'} = 'SKU';
		
			#if ($ebref->{'ebay:skypeid'} ne '') {
			#	$xml{'Item.SkypeEnabled'} = 'true';
			#	$xml{'Item.SkypeID'} = $ebref->{'ebay:skypeid'};
			#	$xml{'Item.SkypeOption'} = $ebref->{'ebay:skypeoption'};
			#	}
			}		
	
	
		## new eBay Pre-Filled Item Specifics
		if ($ebref->{'ebay:productid'} =~ /[<>]+/) { $ebref->{'ebay:productid'} = ''; } # fix corrupt product id's
		if ($ebref->{'ebay:productid'} ne '') {
			## see if eBay has a stock photo
			my $pstmt = "select count(*) from PROD_NO_PICTURES where EBAYPROD=".$udbh->quote($ebref->{'ebay:productid'});
			my ($missingpic) = $udbh->selectrow_array($pstmt);
			
			my $includestock = 'false';
			if (not $missingpic) { $includestock = 'true'; } 
	
			#$hash{'**ProductInfo'} = qq~
	  		#	<ProductInfo id="$ebref->{'ebay:productid'}">
			#		<IncludeStockPhotoURL>$includestock</IncludeStockPhotoURL>
			#		<IncludePrefilledItemInformation>1</IncludePrefilledItemInformation>
			#		<UseStockPhotoURLAsGallery>$includestock</UseStockPhotoURLAsGallery>
			#	</ProductInfo>
			#	~;
			$xml{'Item.ProductListingDetails.ProductID'} = $ebref->{'ebay:productid'};
			$xml{'Item.ProductListingDetails.IncludeprefilledItemInformation'} = 1;
			$xml{'Item.ProductListingDetails.IncludeStockPhotoURL'} = $includestock;
			$xml{'Item.ProductListingDetails.UseStockPhotoURLAsGallery'} = $includestock;
			}
		
	
		##
		## SHIPPING!
		##
		if ($le->has_failed()) {
			}
		else {
			## ADMIN-APP SHIPPING
			my $shipxml = '';
			my %topref = ();
			my %ref = ();
			my %btmref = ();

			my $currency = 'USD';

			my $NEED_CALCULATED_SHIPPING = 0;
			my $HAS_FIXED_PRICE = 0;
			my $HAS_FREIGHT = 0;
			my ($majorWeight,$minorWeight) = &EBAY2::smart_weight_in_lboz($ebref->{'ebay:base_weight'});
		
			## DOMESTIC SHIPPING OPTIONS
			if (1) {
				my $i = 1;
				my $used_product_rates = 0;
		
				foreach my $svc (@{$ebnsref->{'@ship_domservices'}}) {
					if (ref($svc) eq '') { $svc =  &ZTOOLKIT::parseparams($svc); }
					my %x = ();
		         my %y = ();
					$y{'ShippingServiceOptions.ShippingServicePriority'} = $i;
					++$i;
		
					$y{'ShippingServiceOptions.ShippingService'} = $svc->{'service'};
		
					if ($svc->{'cost'}==-1) { 
						push @{$MSGS}, "DEBUG|+=== Used ebay:ship_cost1 + ebay:ship_markup formula because addcost was -1";
						$svc->{'cost'} = sprintf("%.2f",$ebref->{'ebay:ship_cost1'}+$ebref->{'ebay:ship_markup'}); 
						if ($used_product_rates++>0) {
							push @{$MSGS}, "WARN|+=== Multiple domestic shipping methods have price of -1 for fixed shipping and subsequently will display the same rates.";
							}
						}
					else {
						push @{$MSGS}, "DEBUG|+=== Used shipping method cost of $svc->{'cost'}";
						}
		
					if ($svc->{'addcost'}==-1) { 
						push @{$MSGS}, "DEBUG|+=== Used ebay:ship_cost2 + ebay:ship_markup formula because addcost was -1";
						$svc->{'addcost'} = sprintf("%.2f",$ebref->{'ebay:ship_cost2'}+$ebref->{'ebay:ship_markup'}); 
						}	
					else {
						push @{$MSGS}, "DEBUG|+=== Used shipping method addcost of $svc->{'addcost'}";
						}

					$y{'ShippingServiceOptions.FreeShipping'} = &XMLTOOLS::boolean($svc->{'free'});
					if ($svc->{'free'}>0) {	$svc->{'cost'} = 0; $svc->{'addcost'} = 0; }
					# $x{'ShippingServiceOptions.FreeShipping'} = &XMLTOOLS::boolean($svc->{'free'});
			
					if ($svc->{'service'} eq 'Freight') { $HAS_FREIGHT |= 1;	}
					if ($svc->{'service'} eq 'FreightFlat') { $HAS_FREIGHT |= 1;	}
					if ($svc->{'service'} eq 'FreightShipping') { $HAS_FREIGHT |= 1;	}
		
					if ($svc->{'free'}>0) {
						## free shipping si something special! (not fixed price or calculated)
						}
					elsif (($svc->{'cost'} ne '') && ($svc->{'cost'}>=0)) { 
						$HAS_FIXED_PRICE |= 1;
						$y{'ShippingServiceOptions.SSAC*'} = &XMLTOOLS::currency('ShippingServiceAdditionalCost',$svc->{'addcost'},$currency);
						# $x{'ShippingServiceOptions.SSAC*'} = &XMLTOOLS::currency('ShippingServiceAdditionalCost',$svc->{'addcost'},$currency);
						$y{'ShippingServiceOptions.SSC*'} = &XMLTOOLS::currency('ShippingServiceCost',$svc->{'cost'},$currency);
						#$x{'ShippingServiceOptions.SSC*'} = &XMLTOOLS::currency('ShippingServiceCost',$svc->{'cost'},$currency);
						if ($svc->{'farcost'}>0) {
							$y{'ShippingServiceOptions.S*'} = &XMLTOOLS::currency('ShippingSurcharge',$svc->{'farcost'},$currency);
							# $x{'ShippingServiceOptions.S*'} = &XMLTOOLS::currency('ShippingSurcharge',$svc->{'farcost'},$currency);

							if ($svc->{'service'} !~ /^(UPS|FedEx)/) {
								push @{$MSGS}, "ERROR|+eBay rules stipulate that AK/HI shipping surcharge is only available for fixed cost UPS/FedEx methods (remove $svc->{'service'})";
								}

							}
						# delete $y{'ShippingServiceOptions.S*'};
						}
					else {
						$NEED_CALCULATED_SHIPPING |= 1;
						}
					$btmref{'ShippingServiceOptions*'} .= &XMLTOOLS::buildTree(undef,\%y,1);
					}
				}
		
			## INTERNATIONAL SHIPPING OPTIONS
			if (1) {
				# my @lines = split(/[\n\r]+/,$ebref->{'ebay:ship_intservices'});
				my $i = 1;
				foreach my $svc (@{$ebnsref->{'@ship_intservices'}}) {
					if (ref($svc) eq '') { $svc =  &ZTOOLKIT::parseparams($svc); }
		
					my $skip = 0;
					if (($svc->{'service'} eq 'USPSFirstClassMailInternational') && ($majorWeight>4)) {				
						## USPS First Class should be dropped.
		            push @{$MSGS}, "WARN|+USPS First Class International Mail has a maximum weight of 4lbs. and was dropped.";
						$skip++;
						}
					next if ($skip);
		
					my %x = ();
					$x{'InternationalShippingServiceOption.ShippingServicePriority'} = $i;
					$x{'InternationalShippingServiceOption.ShippingService'} = $svc->{'service'};
		         ++$i;
		         
					

					my @locs = ();
					if ($svc->{'shipto'} ne '') {
						## custom shipto specified for the shipping method.
						@locs = split(/[,\s]+/,$svc->{'shipto'});
						}
					elsif ($svc->{'service'} eq 'UPSStandardToCanada') {
						## force canada on whenever it's UPSStandardToCanada
						@locs = ('CA');
						}
					elsif (ref($ebnsref->{'Item\ShipToLocations\@ARRAY'}) eq 'ARRAY') {
						## use default ebay:ship_intlocations
						@locs = @{$ebnsref->{'Item\ShipToLocations\@ARRAY'}}; 
						}
					else {
						@locs = ();
						}

		         if (scalar(@locs)==0) {
		            push @{$MSGS}, "ERROR|+internationl shipping is specified, but no locations are.";
		            }
		           
					## 'Item\ShippingDetails\InternationalShippingServiceOption\ShipToLocation\@ARRAY'
					foreach my $loc (@locs) {
						# $x{'InternationalShippingServiceOption.ShipToLocation-'.$loc.'*'} = '<ShipToLocation>'.$loc.'</ShipToLocation>';
						$x{'InternationalShippingServiceOption.ShipToLocation$'.$loc} = $loc; 
						}
		
					# print Dumper($svc,\@locs);
		
					if ((scalar(@locs)==1) && ($locs[0] eq 'CA')) {
						## if we only have canada then use canada fixed price shipping rates!
						if ($svc->{'cost'}==-1) { $svc->{'cost'} = sprintf("%.2f",$ebref->{'ebay:ship_can_cost1'}+$ebref->{'ebay:ship_markup'}); }
						if ($svc->{'addcost'}==-1) { $svc->{'addcost'} = sprintf("%.2f",$ebref->{'ebay:ship_can_cost2'}+$ebref->{'ebay:ship_markup'}); }					
						}
					else {
						## use international fixed price rates!
						if ($svc->{'cost'}==-1) { $svc->{'cost'} = sprintf("%.2f",$ebref->{'ebay:ship_int_cost1'}+$ebref->{'ebay:ship_markup'}); }
						if ($svc->{'addcost'}==-1) { $svc->{'addcost'} = sprintf("%.2f",$ebref->{'ebay:ship_int_cost2'}+$ebref->{'ebay:ship_markup'}); }	
						}
		
					$x{'InternationalShippingServiceOption.FreeShipping'} = &XMLTOOLS::boolean($svc->{'free'});
					if ($svc->{'free'}>0) {	$svc->{'cost'} = 0; $svc->{'addcost'} = 0; }

					if ($svc->{'free'}>0) {
						## free shipping si something special! (not fixed price or calculated)
						}
					elsif (($svc->{'cost'} ne '') && ($svc->{'cost'}>=0)) {
						$HAS_FIXED_PRICE |= 2;
						$x{'InternationalShippingServiceOption.SSAC*'} = &XMLTOOLS::currency('ShippingServiceAdditionalCost',$svc->{'addcost'},$currency);
						$x{'InternationalShippingServiceOption.SSC*'} = &XMLTOOLS::currency('ShippingServiceCost',$svc->{'cost'},$currency);
						if ($svc->{'farcost'}>0) {
							$x{'InternationalShippingServiceOption.S*'} = &XMLTOOLS::currency('ShippingSurcharge',$svc->{'farcost'},$currency);
							}
						}
					else {
						$NEED_CALCULATED_SHIPPING |= 2;
						}
							
					$btmref{'InternationalPromotionalShippingDiscount'} = &XMLTOOLS::boolean(0);
					$btmref{'InternationalShippingServiceOptions_'.$i.'*'} = &XMLTOOLS::buildTree(undef,\%x,1);
					}
				}
		
			if (not $ebnsref->{'Item\ShippingDetails\InsuranceDetails.InsuranceOption'}) { 
				push @{$MSGS}, "WARN|+Set InsuranceDetails.InsuranceOption to 'NotOffered'";
				$ebnsref->{'Item\ShippingDetails\InsuranceDetails\InsuranceOption'} = 'NotOffered'; 
				}
			$ref{'InsuranceDetails.InsuranceOption'} = $ebnsref->{'Item\ShippingDetails\InsuranceDetails\InsuranceOption'};
			if ($ebnsref->{'Item\ShippingDetails\InsuranceDetails\InsuranceOption'} eq 'NotOffered') {
				}
			elsif ($ebnsref->{'Item\ShippingDetails\InsuranceDetails\InsuranceFee@CURRENCY'}>0) {
				if (($HAS_FIXED_PRICE & 1) && (($NEED_CALCULATED_SHIPPING&1)==0)) {
					$ref{'InsuranceDetails.InsuranceFee*'} = &XMLTOOLS::currency('InsuranceFee',$ebnsref->{'Item\ShippingDetails\InsuranceDetails\InsuranceFee@CURRENCY'},$currency);
					}
				else {
					push @{$MSGS}, "WARN|+Domestic Insurance fee ignored. Insurance fees only apply to Flat rate shipping, listing will use carrier insurance rates.";
					}
				}
		
			if (not $ebnsref->{'Item\ShippingDetails\InternationalInsuranceDetails\InsuranceOption'}) { 
				push @{$MSGS}, "WARN|+Set InternationalInsuranceDetails.InsuranceOption to 'NotOffered'";
				$ebnsref->{'Item\ShippingDetails\InternationalInsuranceDetails\InsuranceOption'} = 'NotOffered'; 
				}
			$ref{'InternationalInsuranceDetails.InsuranceOption'} = $ebnsref->{'Item\ShippingDetails\InternationalInsuranceDetails\InsuranceOption'};
			if ($ebnsref->{'Item\ShippingDetails\InternationalInsuranceDetails\InsuranceOption'} eq '') {
				push @{$MSGS}, "ERROR|+International Shipping and insurance settings have not been configured on this product.";
				}
			elsif ($ebnsref->{'Item\ShippingDetails\InternationalInsuranceDetails\InsuranceOption'} eq 'NotOffered') {}
			elsif ($ebnsref->{'Item\ShippingDetails\InternationalInsuranceDetails\InsuranceFee@CURRENCY'}>0) {
				if (($HAS_FIXED_PRICE & 2) && (($NEED_CALCULATED_SHIPPING&2)==0)) {
					$ref{'InternationalInsuranceDetails.InsuranceFee*'} = &XMLTOOLS::currency('InsuranceFee',$ebnsref->{'Item\ShippingDetails\InternationalInsuranceDetails\InsuranceFee@CURRENCY'},$currency);
					}
				else {
					push @{$MSGS}, "WARN|+International Insurance fee ignored. Insurance fees only apply to Flat rate shipping, listing will use carrier insurance rates.";
					}
				}
		
			if (($HAS_FIXED_PRICE&1) && ($NEED_CALCULATED_SHIPPING&1)) {
				push @{$MSGS}, "ERROR|+Unfortunately eBay does not support mixed flat rate and calculated rate domestic shipping methods. (HFP=$HAS_FIXED_PRICE NCS=$NEED_CALCULATED_SHIPPING)";
				}
		
			if (($HAS_FIXED_PRICE&2) && ($NEED_CALCULATED_SHIPPING&2)) {
				push @{$MSGS}, "ERROR|+Unfortunately eBay does not support mixed flat rate and calculated rate international shipping methods. (HFP=$HAS_FIXED_PRICE NCS=$NEED_CALCULATED_SHIPPING)";
				}
		
			if ($HAS_FREIGHT>0) {
				$btmref{'ShippingType'} = 'Freight'; 
				## DispatchTimeMax must be set to zero for freight shipments!
				## or eBay throws (completely incorrect) error:
				## #21806 Invalid Domestic Handling Time.: 0 business day(s) is not a valid Domestic Handling Time on site 0.
				## isn't it ironic, that it MUST be set to zero -- even though the error says zero isn't valid.
				$xml{'Item.DispatchTimeMax'} = 0;
				}
			elsif (($HAS_FIXED_PRICE==1) && ($NEED_CALCULATED_SHIPPING==2)) {
				## we have fixed domestic, and calculated international
				$btmref{'ShippingType'} = 'FlatDomesticCalculatedInternational';
				}
			elsif (($HAS_FIXED_PRICE==2) && ($NEED_CALCULATED_SHIPPING==1)) {
				## we have calculated domestic, and fixed international
				$btmref{'ShippingType'} = 'CalculatedDomesticFlatInternational';
				# push @{$MSGS}, "BH|+blah";
				}
			elsif (($HAS_FIXED_PRICE&3) && ($NEED_CALCULATED_SHIPPING==0)) {
				$btmref{'ShippingType'} = 'Flat';
				}
			elsif (($HAS_FIXED_PRICE==0) && ($NEED_CALCULATED_SHIPPING&3)) {
				$btmref{'ShippingType'} = 'Calculated';
				}
			else {
			   warn "((HFP=$HAS_FIXED_PRICE) && (NCS=$NEED_CALCULATED_SHIPPING))\n";
				push @{$MSGS}, "WARN|+Cannot configure set ShippingType properly (HFP=$HAS_FIXED_PRICE NCS=$NEED_CALCULATED_SHIPPING)";
				}
			
		
			# $NEED_CALCULATED_SHIPPING = 0;	
			if ($NEED_CALCULATED_SHIPPING) {
				if (not defined $ebnsref->{'Item\ShippingDetails\CalculatedShippingRate\OriginatingPostalCode'}) {
					$ebnsref->{'Item\ShippingDetails\CalculatedShippingRate\OriginatingPostalCode'} = $ebnsref->{'origin_zip'};
					}
				if ($ebnsref->{'Item\ShippingDetails\CalculatedShippingRate\OriginatingPostalCode'} eq '') {
					push @{$MSGS}, "ERROR|+Origin Postal Code is blank, but is required for calculated shipping";
					}


				$topref{'CalculatedShippingRate.OriginatingPostalCode'} = $ebnsref->{'Item\ShippingDetails\CalculatedShippingRate\OriginatingPostalCode'};	
				if ($NEED_CALCULATED_SHIPPING&1) {
					$topref{'CalculatedShippingRate.PHC*'} = &XMLTOOLS::currency('PackagingHandlingCosts',$ebref->{'ebay:ship_dompkghndcosts'},$currency);
					}
				if ($NEED_CALCULATED_SHIPPING&2) {
					$topref{'CalculatedShippingRate.IPHC*'} = &XMLTOOLS::currency('InternationalPackagingHandlingCosts',$ebref->{'ebay:ship_intpkghndcosts'},$currency);
					}
				$topref{'CalculatedShippingRate.MeasurementUnit'} = 'English';
				
				#if ($ebref->{'ebay:pkg_height'}) { $topref{'CalculatedShippingRate.PackageLength'} = $ebref->{'ebay:pkg_height'}; }
				# if ($ebref->{'ebay:prod_height'}) { $topref{'CalculatedShippingRate.PackageLength'} = $ebref->{'ebay:prod_height'}; }
				#elsif ($ebref->{'ebay:pkg_length'}) { $topref{'CalculatedShippingRate.PackageLength'} = $ebref->{'ebay:pkg_length'}; }
				if ($ebref->{'ebay:prod_length'}) { $topref{'CalculatedShippingRate.PackageLength'} = $ebref->{'ebay:prod_length'}; }
		
				#if ($ebref->{'ebay:pkg_width'}) { $topref{'CalculatedShippingRate.PackageWidth'} = $ebref->{'ebay:pkg_width'}; }
				if ($ebref->{'ebay:prod_width'}) { $topref{'CalculatedShippingRate.PackageWidth'} = $ebref->{'ebay:prod_width'}; }
		
				#if ($ebref->{'ebay:pkg_depth'}) { $topref{'CalculatedShippingRate.PackageDepth'} = $ebref->{'ebay:pkg_depth'}; }
				if ($ebref->{'ebay:prod_height'}) { $topref{'CalculatedShippingRate.PackageDepth'} = $ebref->{'ebay:prod_height'}; }
		
				if ($ebref->{'ebay:ship_packagetype'} eq 'None') {}
				elsif ($ebref->{'ebay:ship_packagetype'} ne '') {
					$topref{'CalculatedShippingRate.ShippingIrregular'} = &XMLTOOLS::boolean($ebref->{'ebay:ship_irregular'});	
					$topref{'CalculatedShippingRate.ShippingPackage'} = $ebref->{'ebay:ship_packagetype'};
					}
		
				$topref{'CalculatedShippingRate.WeightMajor*'} = sprintf("<WeightMajor unit=\"lbs\">%d</WeightMajor>",$majorWeight);
				$topref{'CalculatedShippingRate.WeightMinor*'} = sprintf("<WeightMinor unit=\"lbs\">%d</WeightMinor>",$minorWeight);
				}
			else {
				## there is no calculated shipping
				if ($ebref->{'ebay:ship_dompkghndcosts'}>0) {
					push @{$MSGS}, "WARN|+eBay does not allow handling charges to be applied to flat rate shipping. Handling fee will be ignored.";
					}
				}
		
		#      <ShippingServiceOptions> ShippingServiceOptionsType 
		#        <FreeShipping> boolean </FreeShipping>
		#        <ShippingService> token </ShippingService>
		#        <ShippingServiceAdditionalCost currencyID="CurrencyCodeType"> AmountType (double) </ShippingServiceAdditionalCost>
		#        <ShippingServiceCost currencyID="CurrencyCodeType"> AmountType (double) </ShippingServiceCost>
		#        <ShippingServicePriority> int </ShippingServicePriority>
		#        <ShippingSurcharge currencyID="CurrencyCodeType"> AmountType (double) </ShippingSurcharge>
		#      </ShippingServiceOptions>
		 #    <InternationalPromotionalShippingDiscount> boolean </InternationalPromotionalShippingDiscount>
		 #     <InternationalShippingDiscountProfileID> string </InternationalShippingDiscountProfileID>
		 #     <InternationalShippingServiceOption> InternationalShippingServiceOptionsType 
		 #       <ShippingService> token </ShippingService>
		 #       <ShippingServiceAdditionalCost currencyID="CurrencyCodeType"> AmountType (double) </ShippingServiceAdditionalCost>
		 #       <ShippingServiceCost currencyID="CurrencyCodeType"> AmountType (double) </ShippingServiceCost>
		 #       <ShippingServicePriority> int </ShippingServicePriority>
		 #       <ShipToLocation> string </ShipToLocation>
		 #       <!-- ... more ShipToLocation nodes here ... -->
		 #     </InternationalShippingServiceOption>
		#     <PaymentInstructions> string </PaymentInstructions>
		#      <PromotionalShippingDiscount> boolean </PromotionalShippingDiscount>
		#      <SalesTax> SalesTaxType 
		#        <SalesTaxPercent> float </SalesTaxPercent>
		#        <SalesTaxState> string </SalesTaxState>
		#        <ShippingIncludedInTax> boolean </ShippingIncludedInTax>
		#      </SalesTax>
		#      <ShippingDiscountProfileID> string </ShippingDiscountProfileID>
		#      <ShippingServiceOptions> ShippingServiceOptionsType 
		#        <FreeShipping> boolean </FreeShipping>
		#        <ShippingService> token </ShippingService>
		#        <ShippingServiceAdditionalCost currencyID="CurrencyCodeType"> AmountType (double) </ShippingServiceAdditionalCost>
		#        <ShippingServiceCost currencyID="CurrencyCodeType"> AmountType (double) </ShippingServiceCost>
		#        <ShippingServicePriority> int </ShippingServicePriority>
		#        <ShippingSurcharge currencyID="CurrencyCodeType"> AmountType (double) </ShippingSurcharge>
		#      </ShippingServiceOptions>
		#      <!-- ... more ShippingServiceOptions nodes here ... -->
		#      <ShippingType> ShippingTypeCodeType </ShippingType>
		

			if (not defined $xml{'Item.UseTaxTable'}) {
				$xml{'Item.UseTaxTable'} = &XMLTOOLS::boolean(1);
				}

			if (not &ZOOVY::is_true($xml{'Item.UseTaxTable'})) {
				$btmref{'SalesTax.SalesTaxPercent'} = sprintf("%.3f",$ebnsref->{'Item\\ShippingDetails\\SalesTax\\SalesTaxPercent'});
				$btmref{'SalesTax.SalesTaxState'} = $ebnsref->{'Item\\ShippingDetails\\SalesTax\\SalesTaxState'}; 
				$btmref{'SalesTax.ShippingIncludedInTax'} = &XMLTOOLS::boolean( $ebnsref->{'Item\\ShippingDetails\\SalesTax\\ShippingIncludedInTax\\@BOOLEAN'} );
				}
			
		  	$shipxml = XMLTOOLS::buildTree(undef,\%topref,1);
		  	$shipxml .= XMLTOOLS::buildTree(undef,\%ref,1);
		  	$shipxml .= XMLTOOLS::buildTree(undef,\%btmref,1);
			$shipxml =~ s/></>\n</g;
			untie %ref;
			
			$xml{'Item.ShippingDetails.x*'} = $shipxml;
			$xml{'Item.CheckoutDetailsSpecified'} = &XMLTOOLS::boolean(1);

		
			#if ($ebref->{'ebay:ship_intlocations'} ne '') {
			#	my $mylocs = &ZTOOLKIT::parseparams($ebref->{'ebay:ship_intlocations'},1);
			#	my @locs = ();
			#	if ($mylocs->{'Worldwide'}) {
			#		@locs = ('WorldWide');
			#		$mylocs = {};
			#		}
			#	push @locs, keys %{$mylocs};
			#	## wow the documentation is fucking stupid, it's ShipToLocation not ShipToLocation(s)
			#	foreach my $loc (@locs) {
			#		$xml{'Item.ShipToLocations-'.$loc.'*'} = "<ShipToLocations>$loc</ShipToLocations>";
			#		}
			#	}

			}

		print Dumper(%xml);
		my $file = sprintf("/tmp/dump.%s",$le->username());
		open F, sprintf(">$file");
		print F Dumper($MSGS,$le->username(),\%xml,$ebref,$ebnsref);
		close F;
		chmod 0666, "$file";
	
#		if ($le->username() eq 'castlebouncehouse') {
#			# push @{$MSGS}, "ERR|Rich you suck";
#			}

		my ($r,$rx) = ();
		if (not $le->has_failed()) {
			my ($r) =  $eb2->api($xml{'#Verb'},\%xml,preservekeys=>['Item'],xml=>1);
		# print STDERR Dumper($r,$errs);
			my ($io) = IO::String->new($r->{'.XML'});
			$rx = XML::SAX::Simple::XMLin($io,ForceArray=>1);
			&ZTOOLKIT::XMLUTIL::stripNamespace($rx);
			}
	
		## PHASE1: process the ebay response into our own FINALMSG response, this will make it easier for us to access the data in a "friendly" format	
	
		if ($rx->{'Message'}->[0]) {
			push @{$MSGS}, "WARN|html=$rx->{'Message'}->[0]";
			}
	
		my @ERRORS = ();
		if (not defined $rx) {
			## something horrible happened.
			push @{$MSGS}, "WARN|+We did not even attempt to send this listing to eBay because of data validation errors (there may be more wrong once those errors are corrected)";
			}
		elsif ($rx->{'Errors'}) {
			foreach my $eberr (@{$rx->{'Errors'}}) {
				my $zerr = {
					'_'=>'ERROR',
					'src'=>'MKT',
					'code'=>$eberr->{'ErrorCode'}->[0],
					'err'=>sprintf("eBay.%d",$eberr->{'ErrorCode'}->[0]), 
					'+'=>$eberr->{'LongMessage'}->[0],
					'severity'=>uc($eberr->{'Severity'}->[0]),	## WARNING|ERROR
					#'debug'=>Dumper($eberr),
					};

				## change brackets from <Item.Quantity> to [Item.Quantity]
				$zerr->{'+'} =~ tr/<>/[]/;
	
				if ($zerr->{'err'} eq 'eBay.488') {
					## The specified UUID has already been used; ListedByRequestAppId=1, item ID=7236587050.	
					## NOTE: this will break if eBay every adds another response parameter
					my $xref = &ZTOOLKIT::XMLUTIL::SXMLflatten($eberr);
					$FINALMSG{'id'} = $xref->{'ErrorParameters.Value'};
					if (($FINALMSG{'id'} == 0) && ($xref->{'.LongMessage'} =~ /ID=([\d]+)\./)) {
						## PlanB: get the ebay id from the ID= in the long message.
						## ex: The specified UUID has already been used; ListedByRequestAppId=1, item ID=310230450165.
						$FINALMSG{'id'} = int($1);
						}
					$le->set_target('LISTINGID',$FINALMSG{'id'});
					$r->{'Ack'}->[0] = 'UnFailure';
					$zerr = undef;
					}
				elsif ($zerr->{'err'} eq 'eBay.5116') {
					## Warning: Attribute 15965 dropped. Attribute either has an invalid attribute id or the value(s) for the attribute are invalid.
					$zerr = undef;
					}
				elsif ($zerr->{'err'} eq 'eBay.11012') {
					## paypal warning - ignore this. 
					## PayPal added as a payment method because you have set your preference to 'offer PayPal on all listings' (known as Automatic Logo Insertion at PayPal)
					$zerr = undef;
					}
				elsif ($zerr->{'err'} eq 'eBay.5119') {
					## A warning that the preset productid has changed. -- can safely be ignored.
					$zerr = undef;
					}
				elsif ($zerr->{'err'} eq 'eBay.12302') {
					## Checkout Redirect is incompatible with Live Auctions, Ad format, Merchant Tool, Motors, and Immediate payment. Your item has been listed, but Checkout Redirect was disabled.
					$zerr = undef;
					}
				elsif ($zerr->{'err'} eq 'eBay.20402') {
					# The Legacy XML format used in this request is being phased out. All applications should migrate to the Unified Schema to avoid loss of service. For more information please see http://developer.ebay.com/migration/.
					$zerr = undef; 
					}	
				elsif ($zerr->{'err'} eq 'eBay.12302') {
					# Checkout Redirect is incompatible with Live Auctions, Ad format, Merchant Tool, Motors, and Immediate payment. Your item has been listed, but Checkout Redirect was disabled.
					$zerr = undef; 
					}
				elsif ($zerr->{'err'} eq 'eBay.17408') {
					# The following input fields have been ignored: UseStockPhotoURLAsGallery, because Gallery/GalleryFeature is not selected
					$zerr = undef;
					}			
				elsif ($zerr->{'err'} eq 'eBay.488') {
					# The specified UUID has already been used; ListedByRequestAppId=0, item ID=250281888336
					$zerr = undef;
					}
				elsif ($zerr->{'err'} eq 'eBay.21917020') {
					# cannot change to requested quanttiy. Original txn quantity = {0} eBay.21917020
					# per DTS 7/30/2010 - this can be ignored and is caused by passing condition id to a category that doesn't support it.
					$zerr = undef;
					}
				elsif ($zerr->{'err'} eq 'eBay.5') {
					my $file = 'debug.'.time();
					$zerr->{'hint'} = "This is an internal XML error - which means that eBay could not accept the content of this listing, please contact Zoovy technical support. [DEBUG FILE: $file]";
					}
				elsif ($zerr->{'err'} eq 'eBay.21673') {
					$zerr->{'hint'} .= "Try using the product power tool to remove the field ebay:productid, and/or zoovy:productid if it is set.";
					}
				elsif ($zerr->{'err'} eq 'eBay.17524') {
					$zerr->{'hint'} = "This is probably because you have shipping locations set to NONE - try US instead.";
					}
				elsif ($zerr->{'err'} eq 'eBay.930') {
					# No XML <RequestPassword> or <RequestToken> was found in XML Request.
					$zerr->{'hint'} = "Chances are all you need to do is refresh your eBay Authorization Token and/or map your eBay account to the profile you're trying to use.<br>";
					}
				elsif ($zerr->{'err'} eq 'eBay.17511') {
					$zerr->{'hint'} = "This error usually means that you've chosen a method such as UPS Ground for International shipping when that method may only be used domestically.<br>";
					}
				elsif ($zerr->{'err'} eq 'eBay.13020') {
					$zerr->{'hint'} = "<br>To fix this: please re-select the category. If the error persists notify Zoovy support.";
					}
				elsif ($zerr->{'err'} eq 'eBay.5112') {
					## Attribute Set Id "1740" does not match category you have entered for this request.
					$zerr->{'hint'} = "<br>To fix this: please re-select the category. If the error persists notify Zoovy support.";
					}
				elsif ($zerr->{'err'} eq 'eBay.5113') {
					## Invalid child attribute value. (1453:15965)
					$zerr->{'hint'} = "<br><font color='red'>eBay has updated the attributes for this category and now requires additional information in order to list. You can fix this error by returning to the previous page and re-selecting the category and then re-selecting the attributes.";
					}
				elsif ($zerr->{'err'} eq 'eBay.17412') {
					$zerr->{'hint'} = "eBay is whining it doesn't have a stock photo. Reload this page, we won't ask them next time.<br>";
					}
				elsif ($zerr->{'err'} eq 'eBay.12515') {
					# Missing the primary shipping service option.. Please check API documentation.
					$zerr->{'hint'} = "Check the shipping setup in your eBay profile. You probably didn't specify any shipping methods for the profile you are trying to use.<br>This error also occurs when you have specified both Fixed/Flat/Free rate shipping and Calculated Shipping (which is okay as long as the Flat rate Shipping has a lower Service Priority than the Calculated Rate)<br>";
					}
				elsif ($zerr->{'err'} eq 'eBay.10008') {
					$zerr->{'hint'} = "Check your eBay profile. Minimum feedback can only be negative values: -1,-2,-3 (ebay won't let this be a positive number since they assume all buyers start as 'good/trusted')";
					}
				elsif ($zerr->{'err'} eq 'eBay.219214') {
					$zerr->{'hint'} = "eBay doesn't say which shipping service had the error, but you can correct it by going to your eBay profile, check the error messages at the top of the screen - it may provide additional info.";
					}
				elsif ($zerr->{'err'} eq 'eBay.21916271') {
					# When specifying SKU for InventoryTrackingMethod, the SKU must be unique within your active and scheduled listings
					# my ($existing_item) = $eb2->GetItem(0,$le->sku());
					# $zerr->{'hint'} = "Hi Mike ".Dumper($existing_item);
					}
				elsif ($zerr->{'err'} eq 'eBay.307') {
					$zerr->{'hint'} = "This error can be caused when attempting to use buy it now with a dutch (multi-quantity) listing. <br>There are three possible solutions: use a fixed price listing, reduce the quantity to 1, or remove the buy it now.<br>";
					}
				elsif ($zerr->{'err'} eq 'eBay.36') {	
			      if ($eberr->{'ErrorParameters'}->[0]->{'Value'}->[0] eq 'SYI.BIZ.9023') { 
						$zerr->{'hint'} = "Try disabling Skype or changing the skype settings.<br>";
						}
					}
				elsif ($zerr->{'err'} eq 'eBay.314') {
					# Only store owners may create store listings.
					$zerr->{'src'} = 'MKT-ACCOUNT';
					}
				elsif ($zerr->{'err'} eq 'eBay.219021') {
					my ($majorWeight,$minorWeight) = &EBAY2::smart_weight_in_lboz($ebref->{'ebay:base_weight'});
					$zerr->{'hint'} = sprintf('Weight transmitted %d lbs. %d oz (ebay:base_weight=%s)',$majorWeight,$minorWeight,$ebref->{'ebay:base_weight'});
					}
				elsif ($zerr->{'err'} eq 'eBay.37') {
					# Input data for tag <Item.Storefront.StoreCategoryID> is invalid or missing. Please check API documentation.
					$zerr->{'hint'} = "The most common cause of this issue is when an eBay store category is removed on eBay.com, but the product (or category in syndication) is still mapped to it and/or your eBay store categories on Zoovy have not been refreshed.";
					}
				elsif ($zerr->{'err'} eq 'eBay.38') {
					## Your application encountered an error. This request is missing required value in input tag <InternationalShippingServiceOption>.<ShipToLocation>.
					$zerr->{'hint'} = "Try specifying one more /Permitted International Shipping Destinations/ if you want to ship internationally";
					}
				elsif ($zerr->{'err'} eq 'eBay.12519') {
					## Shipping service Other (see description)(14) is not available.
					$zerr->{'hint'} = "You probably need to specify fixed shipping prices to utilize this shipping method.";
					}
				elsif ($zerr->{'err'} eq 'eBay.219214') {
					$zerr->{'hint'} = "eBay is aware that the US Postal service has no handling fee to AK/HI, so they won't let you charge one. (Use UPS Shipping)";
					}
	
				if (not defined $zerr) {
					}
				elsif ($eberr->{'SeverityCode'}->[0] eq 'Warning') {		
					$zerr->{'_'} = 'WARN';
					push @{$MSGS}, &LISTING::MSGS::hashref_to_msg('WARN',$zerr);
					}
				elsif (defined $zerr) {
					## note: class "EBAY-ERR" can be ignored if the application shows ERRORS, otherwise it will show EBAY-ERR
					$zerr->{'_'} = 'ERROR';
					push @{$MSGS}, &LISTING::MSGS::hashref_to_msg('ERROR',$zerr);
					}
				}
			}
	
		###
		#my $USERNAME = $eb2->username();
		#my ($r) =  &EBAY::API::doRequest($USERNAME,$PROFILE,'VerifyAddItem',$hashref,preservekeys=>['Item'],noflatten=>['Fees'],xml=>1);
	
	
		### Check for an Item
		#if ($rx->{'Ack'}->[0] eq 'UnFailure') {
		#	## not a success, but not a failure, probably attempted to relist a dupe UUID
		#	#if ($FINALMSG{'id'}<=0) {		
		#	#	$FINALMSG{'id'} = $FINALMSG{'DuplicateItemId'};
		#	#	}
		#	}
	
		if (($rx->{'Ack'}->[0] eq 'Success') || ($rx->{'Ack'}->[0] eq 'Warning') || ($rx->{'Ack'}->[0] eq 'UnFailure')) {
			$FINALMSG{'id'} = $rx->{'ItemID'}->[0];
			if (($rx->{'ItemID'}->[0] == 0) && ($rx->{'DuplicateItemID'}->[0]>0)) {
				$FINALMSG{'id'} = $rx->{'DuplicateItemID'}->[0]
				}
			$le->set_target('LISTINGID',$FINALMSG{'id'});
	
			$FINALMSG{'expires'} = $eb2->ebt2gmt($rx->{'EndTime'}->[0]);
			if ($VERB eq 'PREVIEW') {
				## previews don't have an end time.
				}
			elsif ($rx->{'EndTime'}->[0] eq '') {
				push @{$MSGS}, "WARN|+Required API response 'EndTime' was not set";
				}
			elsif ($FINALMSG{'expires'} == 0) {
				push @{$MSGS}, "WARN|+FINALMSG{expires} was zero because $rx->{'EndTime'}->[0]";
				}

			if ($VERB eq 'PREVIEW') {
				## previews don't have an expires time!
				}
			elsif ($FINALMSG{'expires'}==0) {		
				my $str = "API-RESPONSE|+".Dumper($rx);
				&ZOOVY::confess($eb2->username(),$str,justkidding=>1);
				$str =~ s/[\n\r]+//gs;
			  	push @{$MSGS}, $str;
				}
			if ($FINALMSG{'duration'} == -1) {
				$FINALMSG{'expires'} = -1;
				}
			}	
	
		## recover from a duplicate item id
	
		## CHECK STATUS OF AUCTION_NUM (0 = FAILURE)
		if ((defined $FINALMSG{'id'}) && ($FINALMSG{'id'}>0)) {
			}
		elsif ($FINALMSG{'ERRORCODE'} == 196) {
			## Your item was not relisted. Possible reasons: the item does not exist, the item has not ended, or you were not the seller of the item.
			$FINALMSG{'retry'} = 1;
			}
		elsif ($FINALMSG{'ERRORCODE'} == 163) {
			## Inactive application or developer. - yeah right!
			$FINALMSG{'retry'} = 1;
			}
		elsif ($FINALMSG{'ERRORCODE'} == 2) {
			## Unsupported Verb! (4/1/04)
			$FINALMSG{'retry'} = 1;
			}
		elsif ($FINALMSG{'ERRORCODE'} == 17) {
			## gee, couldn't relist.
			$FINALMSG{'retry'}=1;
			}
		elsif ($FINALMSG{'ERRORCODE'} == 10007) {
			## Internal error to the application.
			### NOTE: this is returned when eBay is DOWN - so we retry 12/26/03
			$FINALMSG{'retry'}=1;
			}
		elsif ($FINALMSG{'ERRORCODE'} == 97 && $RECYCLEID) {
			## contradicotry shipping
			$FINALMSG{'retry'}=1;
			}
		elsif ($FINALMSG{'ERRORCODE'} == 190 && $RECYCLEID) {
			## ebay bug! 
			$FINALMSG{'retry'}=1;
			}
		elsif ($FINALMSG{'ERRORCODE'} == 115 && $RECYCLEID) {
			## relisted price must be higher
			$FINALMSG{'retry'}=1;
			}
		elsif ($FINALMSG{'ERRORCODE'} == 195 && $RECYCLEID) {
			## ebay bug! The Buy It Now price must be greater than or equal to the minimum bid price. 
			$FINALMSG{'retry'}=1;
			}
		elsif ($FINALMSG{'ERROR'} =~ /502 Proxy Error/) {
			## TREAT THIS AS A CRITICAL FAILURE SO WE BACK OFF
			$FINALMSG{'retry'}=1;
			}
		#elsif ($META{'ERRORCODE'} == 17412) {
		#	## SeriousError #17412 - cannot find muse stock photos ?? who the @#$% cares? 	
		#	$META{'retry'}=1;
		#	my $dbh = &EBAY::API::db_ebay_connect();
		#	my $qtTITLE = $dbh->quote($ebayvars->{'Item.Title'});
		#	my $qtEBAYPROD = $dbh->quote($zoovyvars->{'ebay:productid'});
		#	my $pstmt = "insert into PROD_NO_PICTURES (TITLE,EBAYPROD,CREATED) values ($qtTITLE,$qtEBAYPROD,now())";
		#	# print STDERR "Stupid eBay doesn't have a picture, we've got to retry!\n$pstmt\n";
		#	$dbh->do($pstmt);
		#	&EBAY::API::db_ebay_close();
		#	}
	
	
		my $USERNAME = $eb2->username();
		open F, ">/tmp/preview.$USERNAME";
		use Data::Dumper; 
		print F Dumper({r=>$r,rx=>$rx,final=>\%FINALMSG,msgs=>$MSGS});
		close F;
	
	
		if (defined $rx->{'Fees'}->[0]) {
			foreach my $fee (@{ $rx->{'Fees'}->[0]->{'Fee'} }) {
				next if ($fee->{'Fee'}->[0]->{'content'}==0);
				next if ($fee->{'Name'}->[0] eq 'ListingFee');
				push @{$MSGS}, "INFO-FEE|name:$fee->{'Name'}->[0]|amt:$fee->{'Fee'}->[0]->{'content'}|+Fee ".$fee->{'Name'}->[0]." = ".sprintf("%0.2f",$fee->{'Fee'}->[0]->{'content'});
				}				
			}	
	
	
		my %vars = ();
		$vars{'ID'} = $UUID;
		$vars{'MID'} = &ZOOVY::resolve_mid($USERNAME);
		$vars{'QUANTITY'} = $FINALMSG{'qty'};
		## reset ITEMS_SOLD to zero so we don't mistaken set inventory too low.
		$vars{'ITEMS_SOLD'} = 0;

		$vars{'TITLE'} = $xml{'Item.Title'};		# Powerlisters require title be updated.
	
		if ($FINALMSG{'duration-as-is'}) {
			## leave as is.
			$vars{'ENDS_GMT'} = $dbref->{'ENDS_GMT'};
			$vars{'IS_GTC'} = $dbref->{'IS_GTC'};
			push @{$MSGS}, sprintf("INFO|ENDS_GMT:$vars{'ENDS_GMT'}|IS_GTC:$vars{'IS_GTC'}|+Duration was not updated (leaving as is ENDS_GMT)");
			}
		elsif ($FINALMSG{'duration'} == -1) { 
			$vars{'ENDS_GMT'} = 0; 
			$vars{'IS_GTC'} = 1; 
			$FINALMSG{'expires'} = -1;
			}
		else {
			$vars{'IS_GTC'} = 0;
			$vars{'ENDS_GMT'} = $FINALMSG{'expires'};
			}
	
		if ($le->has_failed()) {
			}
		elsif ($VERB eq 'PREVIEW') {
			$FINALMSG{'+'} = "Preview was successful";
			push @{$MSGS}, &LISTING::MSGS::hashref_to_msg("SUCCESS",\%FINALMSG);
			}
		elsif (($VERB eq 'INSERT') && ($FINALMSG{'id'}>0)) {
			## INSERT SUCCESS
			$vars{'EBAY_ID'} = $FINALMSG{'id'};

			$vars{'ITEMS_REMAIN'} = -1; # $FINALMSG{'qty'};
			$vars{'QUANTITY'} = $FINALMSG{'qty'};
			$vars{'ITEMS_SOLD'} = 0;	# reset items sold, since we're getting a new qty.
			#$vars{'QUANTITY'} = $rxo->
			#$self->{'TITLE'} = $hashref->{'Item.Title'}; 
			## hmm.. we should PROBABLY be updating, not inserting for the first time here.
			my ($pstmt) = &DBINFO::insert($udbh,'EBAY_LISTINGS',\%vars,update=>1,key=>['MID','ID'],sql=>1);

			$INV2->mktinvcmd("FOLLOW","EBAY",$FINALMSG{'id'},$SKU,'QTY'=>$FINALMSG{'qty'},'ENDS_GMT'=>$vars{'ENDS_GMT'});

			print STDERR $pstmt."\n";
			if (not $udbh->do($pstmt)) {
				$FINALMSG{'+'} = "Could not update eBay database: ".$udbh->errstr();
				push @{$MSGS}, &LISTING::MSGS::hashref_to_msg("ERROR",\%FINALMSG);
				}
			else {
				push @{$MSGS}, &LISTING::MSGS::hashref_to_msg("SUCCESS",\%FINALMSG);		
				}

			}
		elsif ($VERB eq 'INSERT') {
			push @{$MSGS}, "ERROR|+Internal Error - Blank result inside LISTING::EBAY verb=INSERT"; 
			}
		elsif ($VERB eq 'UPDATE-LISTING') {
			if ($FINALMSG{'id'} > 0) {
				$FINALMSG{'+'} = "Updated $FINALMSG{'id'}";
				push @{$MSGS}, &LISTING::MSGS::hashref_to_msg("SUCCESS",\%FINALMSG);
				my ($pstmt) = &DBINFO::insert($udbh,'EBAY_LISTINGS',\%vars,update=>1,key=>['MID','ID'],sql=>1);
				$udbh->do($pstmt);

				$INV2->mktinvcmd( "FOLLOW", "EBAY",$FINALMSG{'id'}, $le->sku(), 'QTY'=>$FINALMSG{'qty'} );
				}
			else {
				push @{$MSGS}, "ERROR|+Failed to update (reason unknown)";
				}
			}
		else {
			push @{$MSGS}, "ERROR|+Internal error - Blank result not allowed on LISTING::EBAY verb=$VERB";
			}

	
		if ($le->has_failed()) {
			}
		elsif ($FINALMSG{'duration'}==-1) {
			my $PRODUCT = $le->sku();
			my $pstmt = "select EBAY_ID from EBAY_LISTINGS where MID=".$eb2->mid()." and PRT=".$eb2->prt()." and PRODUCT=".$udbh->quote($PRODUCT)." and IS_GTC>0 and IS_ENDED=0";
			my ($sth) = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my ($existing_EBAY_ID) = $sth->fetchrow() ) {
				if ($existing_EBAY_ID == 0) {
					## ignore, this was never created, in fact it might even be our UUID
					}
				elsif ($existing_EBAY_ID == $FINALMSG{'id'}) {
					## this is us, which is fine, we already know about ourselves!
					}
				else {
					## shit, this appears to be a duplicate gtc listings for the same product, take it down (how did that happen)
					## there can only be one, so we'll issue a kill command.
					&ZOOVY::add_event($eb2->username(),'EBAY.KILL','PRT'=>$eb2->prt(),'EBAY'=>$existing_EBAY_ID);
					}
				}
			$sth->finish();
		
			my %VARS = ();
			$VARS{'MID'} = $eb2->mid();
			$VARS{'EBAY_ID'} = $FINALMSG{'id'};
			$VARS{'PRT'} = $eb2->prt();
			$VARS{'PRODUCT'} = $PRODUCT;

			$VARS{'IS_GTC'} = 1;
			$VARS{'IS_ENDED'} = 0;
			$VARS{'ENDS_GMT'} = 0;

			($pstmt) = &DBINFO::insert($udbh,'EBAY_LISTINGS',\%VARS,update=>2,sql=>1,key=>['MID','PRT','PRODUCT','EBAY_ID']);
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			# $eb2->gtc_update($le->sku(),$FINALMSG{'id'});
			}

		if (($VERB eq 'INSERT') && ($le->has_failed()) && ($FINALMSG{'id'}==0) && ($vars{'ID'}>0)) {
			## cleanup the listing (mark it as ended since it didn't actually launch)
			my $pstmt = sprintf("update EBAY_LISTINGS set IS_ENDED=if(IS_ENDED=0,77,IS_ENDED) where MID=%d and ID=%d",$vars{'MID'},$vars{'ID'});
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			push @{$MSGS}, "DEBUG|+Did database cleanup UUID:$vars{'ID'} to IS_ENDED=77";

			use Data::Dumper;
			open F, ">/tmp/ebay.failure.77";
			print F Dumper(\%vars,$pstmt,$le,\%FINALMSG);
			close F;
			}
		
		push @{$MSGS}, sprintf("DEBUG|+TARGET:$TARGET VERB:$VERB LE:%d",$le->has_failed());
		if (($TARGET eq 'EBAY.SYND') && ($VERB eq 'INSERT') && ($le->has_failed())) {
			my $msgresult = $le->whatsup();
			require SYNDICATION;
			my ($so) = SYNDICATION->new($USERNAME,'EBF','PRT'=>$le->prt(),'type'=>'products');
			$so->suspend_sku($le->sku(),int($msgresult->{'id'}),$msgresult->{'+'},
				'BATCHID'=>$le->batchid(),
				'LISTING_EVENT_ID'=>$le->id()
				);
			}

		if (($FINALMSG{'duration'} == -1) && ($FINALMSG{'id'}>0)) {
			#mysql> desc EBAY_GTC_LISTINGS;
			#+-------------+------------------+------+-----+---------+-------+
			#| Field       | Type             | Null | Key | Default | Extra |
			#+-------------+------------------+------+-----+---------+-------+
			#| USERNAME    | varchar(20)      | NO   |     | 0       |       |
			#| MID         | int(10) unsigned | NO   | PRI | 0       |       |
			#| PRT         | tinyint(4)       | NO   | PRI | 0       |       |
			#| PRODUCT     | varchar(20)      | NO   |     | NULL    |       |
			#| SKU         | varchar(35)      | NO   | PRI | NULL    |       |
			#| EBAY_ID     | bigint(20)       | NO   | MUL | 0       |       |
			#| CREATED_GMT | int(10) unsigned | NO   |     | 0       |       |
			#| INVSYNC_GMT | int(10) unsigned | NO   |     | 0       |       |
			#| PIDSYNC_GMT | int(10) unsigned | NO   |     | 0       |       |
			#| ENDED_GMT   | int(10) unsigned | NO   | PRI | 0       |       |
			#+-------------+------------------+------+-----+---------+-------+
			# 10 rows in set (0.00 sec)			
			}
		
		}
	elsif (($VERB eq 'REMOVE-LISTING') || ($VERB eq 'REMOVE-SKU') || ($VERB eq 'END')) {
		##
		## REMOVE-LISTING / REMOVE-SKU
		##
		my @REMOVE_THIS = ();
		my $MID = $le->mid();
		my $USERNAME = $le->username();
		if (($VERB eq 'END') && ($le->listingid()>0)) {
			push @REMOVE_THIS, sprintf("%s|%s",$le->sku(),$le->listingid());
			}
		elsif ($VERB eq 'REMOVE-LISTING') {
			push @REMOVE_THIS, sprintf("%s|%s",$le->sku(),$le->listingid());
			}
		elsif ($VERB eq 'REMOVE-SKU') {
			my $pstmt = "select PRODUCT,EBAY_ID from EBAY_LISTINGS where MID=$MID /* $USERNAME */ and PRODUCT=".$udbh->quote($le->sku());
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my ($SKU,$EBAY_ID) = $sth->fetchrow() ) {
				push @REMOVE_THIS, "$SKU|$EBAY_ID";
				}
			$sth->finish();
			}
		
		# push @{$MSGS}, "WARN|+".Dumper($le);

		foreach my $SET (@REMOVE_THIS) {
			my ($SKU,$EBAY_ID) = split(/\|/,$SET);
			my $result = $eb2->api('EndItem',{ ItemID=>$EBAY_ID, EndingReason=>'NotAvailable' },xml=>3);
			print STDERR Dumper($result);
			
			my $is_happy = 0;
			if ($result->{'.'}->{'Ack'}->[0] eq 'Success') {
				## yay!
				$is_happy++;
				}
			elsif (($result->{'.'}->{'Ack'}->[0] eq 'Failure') && ($result->{'.'}->{'Errors'}->[0]->{'ErrorCode'}->[0] == 1047)) {
				## it's still okay / The auction has already been closed.
				$is_happy++;
				}
			elsif (($result->{'.'}->{'Ack'}->[0] eq 'Failure') && ($result->{'.'}->{'Errors'}->[0]->{'ErrorCode'}->[0] == 17)) {
				## This item cannot be accessed because the listing has been deleted, is a Half.com listing, or you are not the seller.
				$is_happy++;
				}
			else {
				push @{$MSGS}, "ERROR|src=ZLAUNCH|code=301|+ebay[".$result->{'.'}->{'Errors'}->[0]->{'ErrorCode'}->[0]."] ".$result->{'.'}->{'Errors'}->[0]->{'LongMessage'}->[0];
				}

			if ($is_happy) {

				my $IS_ENDED = 1;
				if ($le->app() eq 'EBMO') { $IS_ENDED = 56; }	# ebay monitor

				my $pstmt = "update EBAY_LISTINGS set IS_ENDED=if(IS_ENDED>0,IS_ENDED,$IS_ENDED) where MID=$MID /* $USERNAME */ and EBAY_ID=$EBAY_ID limit 1";
				if ($::DEBUG) { print STDERR $pstmt."\n"; }
				$udbh->do($pstmt);

				$INV2->mktinvcmd('END',"EBAY",$FINALMSG{'id'},$le->sku(),'QTY'=>0,'ENDS_GMT'=>time()-1);
				}
			}

		if (not $le->has_failed()) {
			push @{$MSGS}, "SUCCESS|+Removed listing(s)";
			}
		}
	elsif ($VERB eq 'ARCHIVE') {
		my $listingid = $le->listingid();
		my $USERNAME = $le->username();
		my $MID = $le->mid();
		my $pstmt = "update EBAY_LISTINGS set EXPIRES_GMT=$^T where MID=$MID /* $USERNAME */ and ID=$listingid";
		$udbh->do($pstmt);
		# $LU->log("PRODEDIT.EBAY2","Archived OOID=$VERBPARAMS->{'OOID'} LISTINGID=$VERBPARAMS->{'LISTINGID'}","SAVE");
		push @{$MSGS}, "SUCCESS|+Did Archive on listingid:$listingid";
		}
	elsif ($VERB eq 'UPDATE-LISTING') {
		die();
		}
	else {
		push @{$MSGS}, "ERROR|src=ZLAUNCH|code=100|+Unsupported VERB=$VERB";
		}


	foreach my $msg (@{$MSGS}) {
		$msg = &ZTOOLKIT::stripUnicode($msg);
		}

		
	return();
	}


#############################################################################










1;
