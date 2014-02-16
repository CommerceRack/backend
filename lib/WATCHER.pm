package WATCHER;

#$REPRICE::DBH = undef;
#$REPRICE::MYSQL_USER = "zoovy";
#$REPRICE::MYSQL_PASS = "password";
#$REPRICE::MYSQL_DSN = "DBI:mysql:database=ZOOVY;host=zoovy.ciw0pzm1nqjr.us-east-1.rds.amazonaws.com";
# mysql -u zoovy -ppassword -h zoovy.ciw0pzm1nqjr.us-east-1.rds.amazonaws.com ZOOVY

#$REPRICE::MYSQL_USER = "zoovy";
#$REPRICE::MYSQL_PASS = "asdf";
#$REPRICE::MYSQL_DSN = "DBI:mysql:database=REPRICE;host=reprice1.ciw0pzm1nqjr.us-east-1.rds.amazonaws.com";
# reprice1.ciw0pzm1nqjr.us-east-1.rds.amazonaws.com


## https://images-na.ssl-images-amazon.com/images/G/01/mwsportal/doc/en_US/products/MWSProductsApiReference._V388666043_.pdf

use strict;
use YAML::Syck;

use lib "/backend/lib";
require ZOOVY;
require DBINFO;
require ZWEBSITE;

##
##
##
%REPRICE::SUSPENDED_REASONS = (
	1=>'No database record',
	);

$AMAZON::ACCESS_KEY = '13EMEBM9Q57T5V52Q382';
$AMAZON::SECRET_KEY = 'duww1YbaJfyIOU8pOYqyDM4Bpkml/+PNSOEKSSr/';

#sub add_sqs_event {
#	my ($USERNAME) = @_;
#
#	# Access Key: 13EMEBM9Q57T5V52Q382
#	# Secret Access Key: duww1YbaJfyIOU8pOYqyDM4Bpkml/+PNSOEKSSr/ 
#	# CreateQueue, ListQueues, DeleteQueue, SendMessage, ReceiveMessage, ChangeMessageVisibility, DeleteMessage, SetQueueAttributes, GetQueueAttributes, AddPermision, and RemovePermission
#	# arn:aws:sns:us-east-1:259948446197:asin_monitor
#	my $sqs = new Amazon::SQS::Simple($AMAZON::ACCESS_KEY, $AMAZON_SECRET_KEY);
#
#	# Create a new queue
#	my $q = $sqs->CreateQueue("ASIN_MONITOR");
#
#	# Send a message
#	$q->SendMessage(
#
#	# Retrieve a message
#   my $msg = $q->ReceiveMessage();
#	print $msg->MessageBody() # Hello world!
#
#	# Delete the message
#	$q->DeleteMessage($msg->ReceiptHandle());
#
#	# Delete the queue
#	$q->Delete();
#	}




##
##
##
sub get {
	my ($self,$URL) = @_;


	## selects a proxy, and create a user agent
	my $ua = LWP::UserAgent->new;
	$ua->agent("Zoovy-Scraper/0.1");
	$ua->proxy(["http", "https"], "http://75.101.135.209:8080");

	#my $URL = 'http://www.amazon.com/gp/offer-listing/0470097779/ref=dp_olp_new';
	#$URL = 'http://www.amazon.com/gp/offer-listing/B0025VK8K4/ref=dp_olp_new';
	#$URL = 'http://www.amazon.com/gp/offer-listing/B000FJ9DOK/ref=dp_olp_new';
	#$URL = 'http://www.amazon.com/gp/offer-listing/B002BAFLT2/ref=dp_olp_new';
	#$URL = "http://www.amazon.com/gp/offer-listing/$ASIN/ref=dp_olp_new";
	#my $ASIN = 'B003VRBP7Q'; # parent asin, apparently has no 
	#$ASIN = 'B001HBZCZ4';	 # child with no comeptitors
	#$ASIN = 'B001792H5O';
	#$ASIN = 'B001792E7A';
	#$URL = "http://www.amazon.com/gp/offer-listing/$ASIN/ref=dp_olp_new";

	my $ERROR = undef;


	print "URL: $URL\n";
	my $FILE = "$URL"; $FILE =~ s/\W/_/g;
	$FILE = "/tmp/$FILE.txt";

	# Create a user agent object

	my $buf = '';
	print "FILE: $FILE\n";

	if (! -f $FILE) {

		# Create a request
		my $req = HTTP::Request->new(POST => $URL);
		$req->content_type('application/x-www-form-urlencoded');
		$req->content('ie=UTF8&condition=new');

		# Pass request to the user agent and get a response back
		my $res = $ua->request($req);

		# Check the outcome of the response
		if ($res->is_success) {
			$buf = $res->content();	
			}
		else {
			print $res->status_line, "\n";
			}

		open F, ">$FILE";
		print F $buf;
		close F;
		}
	else {
		open F, "<$FILE"; $/= undef; $buf = <F>; $/ = "\n"; close F;
		}

	if (length($buf) == 0) {
		$ERROR = 'HTTP Error: Got zero by response';
		}

	print "CLEANUP: $FILE\n";
	unlink($FILE);

	return($ERROR,$buf);
	}





##
## sets object internals ex: *LM
##
sub set {
	my ($self,%options) = @_;
	foreach my $k (keys %options) { $self->{$k} = $options{$k}; }
	}

sub msgs { return($_[0]->{'*LM'}); }

##
## perl -e 'use lib "/backend/lib"; use WATCHER; my ($w) = WATCHER->new("toynk","AMZ"); use Data::Dumper; print Dumper($w->get_skuref("ANDREW-AUT"));'
##
sub get_skuref {
	my ($self,$sku) = @_;

	die("get skuref not ported.");

#	my ($udbh) = &DBINFO::db_user_connect($self->username());
#	my $qtSKU = $udbh->quote($sku);
#	my $USERNAME = $self->username();
#	my $MID = $self->mid();
#	my $pstmt = "select * from AMAZON_PID_UPCS where MID=$MID /* $USERNAME */ and SKU=$qtSKU";
#	my ($skuref) = $udbh->selectrow_hashref($pstmt);
#	&DBINFO::db_user_close();
#	return($skuref);
	}


##
##
##
sub store_seller {
	my ($self,$sellerid,$sellername) = @_;

	my ($MID) = $self->mid();
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $pstmt = "select count(*) from WATCHER_SELLERIDS where MID=$MID and DST=".$udbh->quote($self->dst())." and SELLERID=".$udbh->quote($sellerid);
	my ($exists) = $udbh->selectrow_array($pstmt);
	if (not $exists) {
		$pstmt = &DBINFO::insert($udbh,'WATCHER_SELLERIDS',{
			'MID'=>$MID,
			'DST'=>$self->dst(),
			'SELLERID'=>$sellerid,
			'SELLERNAME'=>$sellername,
			},sql=>1,insert=>1);
		print "$pstmt\n";
		$udbh->do($pstmt);
		}
	&DBINFO::db_user_close();
	return();
	}

##
## record offers into the "WATCHER_HISTORY" table .. history
##
sub store_offers {
	my ($self,$SKU,$sellersref) = @_;

	## record the pricing history (this might be useful)
	my $TS = time();
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	foreach my $offer (@{$sellersref}) {
		next if ($offer->{'errors'});
		$self->store_seller($offer->{'sellerid'},$offer->{'seller'});
		my $pstmt = &DBINFO::insert($udbh,'WATCHER_HISTORY',{
			'MID'=>$self->mid(),'SKU'=>$SKU,'DST'=>$self->dst(),'*RECORDED_TS'=>$TS,
			'SELLERID'=>$offer->{'sellerid'},
			'PRICE_WAS'=>$offer->{'price'},
			'SHIP_WAS'=>$offer->{'shipping'},
			},sql=>1);
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		}
	&DBINFO::db_user_close();
	}

##
## perl -e 'use lib "/backend/lib"; use WATCHER; my ($w) = WATCHER->new("toynk","AMZ"); use Data::Dumper; print Dumper($w->verify($w->get_skuref("ANDREW-AUT")));'
##
sub verify {
	my ($self,$skuref) = @_;

	die("verify not ported");

	my $ERROR = undef;
	my ($USERNAME) = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $SKU = $skuref->{'SKU'};
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $qtSKU = $udbh->quote($SKU);

	if ($ERROR) {
		}
	elsif (not defined $SKU) {
		$ERROR = 'SKU not set in response';
		}

	## $lm will be undefined if we aren't in debug (or logging for some reason)
	my $lm = $self->msgs();


	##
	## SANITY: now load the strategy
	##
	my $STRATEGYREF = undef;
	if (defined $ERROR) {
		}
	elsif ($self->dst() eq 'BUY') {
		}
	elsif ($skuref->{'AMZRP_STRATEGY'} eq '') {
		$ERROR = "Strategy not set in SKUREF";
		}
	else {
		($STRATEGYREF) = $self->get_strategy($skuref->{'AMZRP_STRATEGY'});
		}


	##
	## SANITY: time for some competitive research.
	##
	my $SELLERSREF = ();
	if (defined $ERROR) {
		}
	elsif ($self->dst() eq 'AMZ') {
		require WATCHER::AMAZON;
		($ERROR,$SELLERSREF) = WATCHER::AMAZON::verify($self,$skuref->{'SKU'},$skuref->{'ASIN'});
		}
	elsif ($self->dst() eq 'BUY') {
		require WATCHER::BUYCOM;
		($ERROR,$SELLERSREF) = WATCHER::BUYCOM::verify($self,$skuref->{'SKU'},$skuref->{'BUYSKU'});
		die();
		}
	else {
		$ERROR = sprintf("Unable to download dst[%s]",$self->dist());
		}

	if (defined $ERROR) {
		}
	elsif (scalar(@{$SELLERSREF})==0) {
		$ERROR = "Did not find anybody (including us) selling item check SKU/UPC/ASIN";
		}
	else {
		#foreach my $element (@{$SELLERSREF}) {
		#	if ($lm) { $lm->pooshmsg("INFO|+SELLER: ".Dumper($element)); }
		#	}
		}


	##
	## SANITY: now lets analyze what we learned into actionable decisions.
	##
	my @ACTIONS = ();
	## okay, so no error, lets decide if the price changed.
	if (not $ERROR) {
		($ERROR,@ACTIONS) = $self->analyze($skuref,$STRATEGYREF,$SELLERSREF);
		if (defined $ERROR) {
			## shit happened.
			}
		elsif (scalar(@ACTIONS)==0) {
			$ERROR = "ISE - No actions returned from analyze";
			}	
		}

	my %dbupdates = ();
	$dbupdates{'*AMZRP_LAST_UPDATE_TS'} = time();
	if ($ERROR) {
		$dbupdates{'AMZRP_STATUS_MSG'} = $ERROR;
		$dbupdates{'AMZRP_HAS_ERROR'} = 1;
		}
	else {
		## perform actions!
		foreach my $a (@ACTIONS) {
			print STDERR "ACTION: $a\n";
			my @x = split(/\|/,$a);
			my $VERB = shift @x;
			my %params = ();
			foreach my $kv (@x) {
				my ($k,$v) = split(/:/,$kv,2);
				$params{$k} = $v;
				}
			if ($params{'DPRICE'}) {
				## convert DPRICE (DELIVERED price) back into PRICE by subtracting our current shipping amount.
				# $params{'PRICE'} = $params{'DPRICE'} - $ME->{'shipping'};
				}
			#my $pstmt = &DBINFO::insert($rdbh,'PRICING_EVENTS',{
			#	'MID'=>$MID,'SKU'=>$SKU,'CREATED_GMT'=>$TS,
			#	'VERB'=>$VERB,
			#	'PRICE_WAS'=>$dbrow->{'CURRENT_PRICE'},'PRICE_IS'=>$params{'PRICE'},
			#	# 'SHIP_WAS'=>$dbrow->{'CURRENT_SHIP'},'SHIP_IS'=>$params{'SHIP'},
			#	'NOTE'=>$params{'NOTE'},
			#	},sql=>1);
			#print "$pstmt\n";
			#$rdbh->do($pstmt);


			if ($params{'NOTE'} ne '') {
				$dbupdates{'AMZRP_STATUS_MSG'} = $params{'NOTE'};
				}

			if ($params{'LAST_SHIP'}) {
				$dbupdates{'AMZRP_LAST_SHIP_I'} = int($params{'LAST_SHIP'}*100);
				}
			if ($params{'LAST_PRICE'}) {
				$dbupdates{'AMZRP_LAST_PRICE_I'} = int($params{'LAST_PRICE'}*100);
				}

			if (defined $params{'SET_DPRICE'}) {
				## DPRICE (DELIVERED PRICE) is a macro, which is the same as setting SET_SHIP			
				my $SHIPPING = $dbupdates{'AMZRP_LAST_SHIP_I'}/100;
				## NOTE: we might use some more complex computations in the future for shipping..
				
				$params{'SET_SHIP'} = $SHIPPING;
				$params{'SET_PRICE'} = ($params{'SET_DPRICE'} - $SHIPPING);
				}
	
			if ($lm) {
				$lm->pooshmsg("INFO|+ACTION: ".Dumper($VERB,\%params));
				}

			if (defined $params{'SET_SHIP'}) {
				$dbupdates{'AMZRP_SET_SHIP_I'} = int($params{'SET_SHIP'}*100);
				}
			if (defined $params{'SET_PRICE'}) {
				$dbupdates{'AMZRP_SET_PRICE_I'} = int($params{'SET_PRICE'}*100);
				require WATCHER::AMAZON;
				my ($docid) = WATCHER::AMAZON::update_price($self,$SKU,$params{'SET_PRICE'});
				if (not defined $lm) {
					}
				elsif ($docid>0) {
					$lm->pooshmsg("SUCCESS|+Sent SKU[$SKU] PRICE[$params{'SET_PRICE'}] to Amazon as DOCID[$docid]");
					}
				else {
					$lm->pooshmsg("ERROR|+Could not update price on Amazon");
					}
				}
	
			if ($VERB ne 'NULL') {
				# $dbupdates{'NEEDS_PRICE_UPDATE'} = 1;
				}

			if ($VERB eq 'PAUSE') {
				# $dbupdates{'IS_SUSPENDED'} = 1;
				}
			}
		}


	if ($lm) {
		$lm->pooshmsg("WARN|+In debug mode, did not actually apply changes");
		}
	else {
		my $pstmt = &DBINFO::insert($udbh,'AMAZON_PID_UPCS',\%dbupdates,key=>{'MID'=>$MID,'SKU'=>$SKU},update=>2,sql=>1);
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);

		$self->store_offers($SKU,$SELLERSREF);

		my $now = POSIX::strftime("%Y%m%d%H%M%S",localtime(time()));
		my $logfile = sprintf("%s/reprice-%s.log",&ZOOVY::resolve_userpath($USERNAME),substr($now,0,6));
		print STDERR "LOGFILE: $logfile\n";
		open F, ">>$logfile";
		foreach my $action (@ACTIONS) {
			print F "$now\t$SKU\t$action\n";
			}
		close F;
		}

	&DBINFO::db_user_close();

	return($ERROR,$SELLERSREF);
	}



#sub queue {
#	my ($self,$skuref) = @_;
#
##	create table PRICE_PING_REQUESTS (
##  ID integer unsigned auto_increment,
##  USERNAME varchar(20) default '' not null,
##  REQUEST text default '' not null,
##  CREATED_TS timestamp default 0 not null,
##  FINISHED_TS timestamp default 0 not null,
##  LOCK_ID integer unsigned default 0 not null,
##  LOCK_GMT integer unsigned default 0 not null,
##  primary key(ID),
##  index(LOCK_ID,LOCK_GMT)
##);
#
#	my %request = ();
#	$request{'*watcher'} = $self;
#	$request{'%sku'} = $skuref;
#	$request{'%strategy'} = $self->get_strategy($skuref->{'AMZRP_STRATEGY'});
#
#	my $YAML = YAML::Syck::Dump(\%request);
#
#	my ($rdbh) = &WATCHER::db_ec2rds_connect($self->username());
#	my ($pstmt) = &DBINFO::insert($rdbh,'PRICE_PING_REQUESTS',{
#		'USERNAME'=>$self->username(),
#		'REQUEST'=>$YAML,
#		'*CREATED_TS'=>time(),
#		},sql=>1,update=>0);
#	print STDERR "$pstmt\n";
#	if (not defined $rdbh->do($pstmt)) {
#		print STDERR "ERROR: $pstmt\n";
#		}
#	
#	$pstmt = "select last_insert_id()";
#	my ($ID) = $rdbh->selectrow_array($pstmt);
#	print STDERR "ID: $ID\n";
#
#	&WATCHER::db_ec2rds_close();
#	return($ID);
#	}

###
###
###
#sub queue_ack {
#	my ($self,$ref) = @_;
#
#	my $YAML = YAML::Syck::Dump($ref);
##	use Data::Dumper; print Dumper(\%request);
##	die();
#
#	my ($rdbh) = &WATCHER::db_ec2rds_connect($self->username());
#	my ($pstmt) = &DBINFO::insert($rdbh,'PRICE_PING_RESPONSES',{
#		'USERNAME'=>$self->username(),
#		'RESPONSE'=>$YAML,
#		'*CREATED_TS'=>time(),
#		},sql=>1,update=>0);
#	if (not defined $rdbh->do($pstmt)) {
#		print STDERR "ERROR: $pstmt\n";
#		}
#	
#	$pstmt = "select last_insert_id()";
#	my ($ID) = $rdbh->do($pstmt);
#
#	&WATCHER::db_ec2rds_close();
#	return($ID);
#	}


##
##
##
sub analyze {
	my ($self, $skuref, $strategyref, $sellersref) = @_;


	my $SKU = $skuref->{'SKU'};
	my $ASIN = $skuref->{'ASIN'};


	my @ACTIONS = ();
	use Data::Dumper;
	##
	## SANITY: at this point @ELEMENTS is populated, and we should initialize our strategy
	##

	my $ERROR = undef;
	my $lm = $self->msgs();

	my $ME = undef;
	my $LOWEST = undef;
	my @RANKED = ();
	if (not defined $ERROR) {
		## phase3: see how many errors we got, identify our listing, figure out some pricing info.
		my $had_errors = 0;
		foreach my $e (@{$sellersref}) {
			if ((defined $e->{'errors'}) && ($e->{'errors'}>0)) { $had_errors++; }

			if (
				($strategyref->{'%'}->{'sellerid'} eq uc($e->{'sellerid'})) || 
				($strategyref->{'%'}->{'seller'} eq uc($e->{'seller'})) 
				){ 
				## YAY! - this is us, so we can ignore it.
				$e->{'skip'} = 'self';
				$ME = $e;
				if ($lm) { $lm->pooshmsg("HINT|+OUR OFFER: ".Dumper($e)); }
				}
			elsif ($strategyref->{'%ignore'}->{ uc($e->{'sellerid'}) }) {
				## HMM.. this seller is on our ignore list.
				$e->{'skip'} = 'ignored';
				if ($lm) { $lm->pooshmsg("WARN|+IGNORING OFFER: ".Dumper($e)); }
				}
			elsif ($strategyref->{'%bully'}->{ uc($e->{'sellerid'}) }) {
				## HMM.. this seller is on our ignore list.
				$e->{'bully'}++;
				if ($lm) { $lm->pooshmsg("WARN|+PREPARING TO BULLY OFFER: ".Dumper($e)); }
				}
			else {
				if ($lm) { $lm->pooshmsg("INFO|+FOUND OFFER: ".Dumper($e)); }
				}

			if ($e->{'skip'}) {}
			elsif ($e->{'errors'}) {}
			elsif (not defined $LOWEST) {
				## first seller is always the lowest!
				$LOWEST = $e;
				push @RANKED, $e;
				}
			elsif ((defined $LOWEST) && ($LOWEST->{'delivered_price'} > $e->{'delivered_price'})) {
				## this seller is lower than the lowest
				$LOWEST = $e;
				unshift @RANKED, $e;
				}
			}

		if ($had_errors == scalar(@{$sellersref})) {
			$ERROR = sprintf("All(%d) pricing elements encountered errors",scalar(@{$sellersref}));
			}
		elsif ($had_errors>1) {
			$ERROR = sprintf("Too many errors(%d) encountered in parsing sellers(%d)",$had_errors,scalar(@{$sellersref}));
			}
		elsif (not defined $ME) {
			$ERROR = sprintf("Could not find item from seller %s (out of stock?)",$strategyref->{'%'}->{'seller'},$strategyref->{'%'}->{'sellerid'});
			}
		}


	##
	## note:
	##		SET_PRICE is what we determined the price should be set to.
	##

	if (defined $ME) {
		push @ACTIONS, "NULL|LAST_SHIP:".sprintf("%.2f",$ME->{'shipping'});
		push @ACTIONS, "NULL|LAST_PRICE:".sprintf("%.2f",$ME->{'price'});
		if ($lm) { $lm->pooshmsg(sprintf("INFO|+Recording our LAST_SHIP[%.2f] LAST_PRICE[%.2f]",$ME->{'shipping'},$ME->{'price'})); }
		# the minimum shipping is whatever we currently charge.
		}
	else {
		if ($lm) { $lm->pooshmsg("WARN|+We did not find our listing, so a lot of stuff isn't going to work."); }
		}

	my $MIN_DELIVERED_PRICE = sprintf("%.2f",($skuref->{'AMZRP_MIN_PRICE_I'} + $skuref->{'AMZRP_MIN_SHIP_I'})/100);
	my $MAX_DELIVERED_PRICE = sprintf("%.2f",$skuref->{'AMZRP_MAX_PRICE_I'}/100);

	if (defined $ERROR) {
		push @ACTIONS, "PAUSE|ASIN:$ASIN|SKU:$SKU|NOTE:Pausing - $ERROR";
		if ($lm) { $lm->pooshmsg("WARN|+Issuing PAUSE command due to error: $ERROR"); }
		}
	elsif (not defined $LOWEST) {
		## hmm.. nobody else selling this?
		push @ACTIONS, "NULL|ASIN:$ASIN|SKU:$SKU|SET_PRICE:$MAX_DELIVERED_PRICE|NOTE:No competition, moving price up!";
		if ($lm) { $lm->pooshmsg("HINT|+Moving price up due to lack of competition."); }
		}
	elsif ($ME->{'delivered_price'} < $LOWEST->{'delivered_price'}) {
		## we're the lowest price, should we reprice up?
		if ($lm) { $lm->pooshmsg("GOOD|+It seems our delivered price is less than the next lowest price."); }
		if ($ME->{'delivered_price'} == $LOWEST->{'delivered_price'}-0.01) {
			## yay, we're exactly where we should be!
			if ($lm) { $lm->pooshmsg("GOOD|+Our price is perfecto!"); }
			push @ACTIONS, "NULL|NOTE:Perfecto|ASIN:$ASIN|SKU:$SKU|SET_DPRICE:".sprintf("%.2f",$LOWEST->{'delivered_price'}-0.01);
			}
		elsif ($ME->{'delivered_price'} < $LOWEST->{'delivered_price'}-0.01) {
			## we should move our price up a bit!
			if ($lm) { $lm->pooshmsg("GOOD|+It appears we could raise our price a bit."); }
			push @ACTIONS, "SET|NOTE:Moving up|ASIN:$ASIN|SKU:$SKU|SET_DPRICE:".sprintf("%.2f",$LOWEST->{'delivered_price'}-0.01);
			}
		}
	elsif ($ME->{'delivered_price'} == $LOWEST->{'delivered_price'}) {
		## sanity: we can only match the lowest price!
		if ($lm) { $lm->pooshmsg("INFO|+we need to match the lowest price."); }
		push @ACTIONS, "SET|NOTE:matching lowest price|ASIN:$ASIN|SKU:$SKU|SET_DPRICE:".sprintf("%.2f",$LOWEST->{'delivered_price'});
		}
	elsif ($MIN_DELIVERED_PRICE > $LOWEST->{'delivered_price'}) {
		## sanity: we can't reprice that low! omg.
		if ($lm) { $lm->pooshmsg("WARN|+we CANNOT match the lowest price."); }
		push @ACTIONS, "SET|NOTE:cannot match|ASIN:$ASIN|SKU:$SKU|SET_DPRICE:".sprintf("%.2f",$MIN_DELIVERED_PRICE);
		}
	else {
		## sanity: we're not the lowest price
		if ($lm) { $lm->pooshmsg("HINT|+we're going to try and match the lowest price."); }
		push @ACTIONS, "SET|NOTE:Moving down|ASIN:$ASIN|SKU:$SKU|SET_DPRICE:".sprintf("%.2f",$LOWEST->{'delivered_price'}-0.01);
		}

	return($ERROR,@ACTIONS);
	}




##
## a handy shortcut to create a watcher by watcher reference.
##
#sub new_by_ref {
#	my ($class,$self) = @_;
#	bless $self, 'WATCHER';
#	if ($self->dst() eq 'AMZ') {
#		require WATCHER::AMAZON;
#		}
#	return($self);
#	}
#

sub username {
	return($_[0]->{'USERNAME'});
	}


sub new {
	my ($class,$USERNAME,$DST,%options) = @_;

	my $self = {};
	$self->{'USERNAME'} = $USERNAME;
	$self->{'MID'} = &ZOOVY::resolve_mid($USERNAME);
	$self->{'DST'} = uc($DST);

	## is library running on zoovy, or ec2 
	## $self->{'IS_REMOTE'} = ($options{'ec2'})?1:0;

	if ($DST eq 'AMZ') {
		require WATCHER::AMAZON;
		bless $self, 'WATCHER';
		}
	elsif ($DST eq 'BUY') {
		require WATCHER::BUYCOM;
		bless $self, 'WATCHER';
		}
#	elsif ($DST eq 'NXT') {
#		require WATCHER::NEXTAG;
#		bless $self, 'WATCHER';
#		}	
#	elsif ($DST eq 'EBY') {
#		require WATCHER::EBAY;
#		bless $self, 'WATCHER';
#		}
	else {
		}

	return($self);
	}


sub mid { return($_[0]->{'MID'}); }
sub dst { return($_[0]->{'DST'}); }
sub is_remote { return($_[0]->{'IS_REMOTE'}); }

##
## returns a strategyid for a particular guid
##
sub resolve_guid_to_strategy {
	my ($self,$GUID) = @_;

	my ($USERNAME) = $self->username();

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my ($MID) = $self->mid();
	my $pstmt = "select ID from STRATEGY_ID where MID=$MID /* $USERNAME */ and GUID=".$udbh->quote($GUID);
	my ($ID) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();
	return(int($ID));
	}

##
##
sub add_strategy {
	my ($self,$STRATID,$configref,$MSGSREF) = @_;

	my $err = undef;
	if (length($STRATID)<3) { 
		$err = 'ERROR|+Strategy ID must be 3 characters';
		}

	if ($STRATID eq 'SUSPENDED') {
		$err = 'ERROR|+SUSPENDED is a reserved word';
		}

	$configref->{'lower_amount'} = sprintf("%.2f",$ZOOVY::cgiv->{'lower_amount'});
	if ($configref->{'lower_amount'}<=0) { 
		if (defined $MSGSREF) { push @{$MSGSREF}, "WARN|Lower Amount was zero, raising to 0.01"; }
		$configref->{'lower_amount'} = 0.01; 
		}

	print STDERR "ERR: $err\n";
	if (not defined $err) {
		my $yaml = YAML::Syck::Dump($configref);
		my ($udbh) = &DBINFO::db_user_connect($self->username());
		my ($pstmt) = &DBINFO::insert($udbh,'REPRICE_STRATEGIES',{
			'USERNAME'=>$self->username(),
			'MID'=>$self->mid(),
			'DST'=>$self->dst(),
			'STRATEGY_ID'=>$STRATID,
			'*MODIFIED_TS'=>'now()',
			'YAML'=>$yaml,
			},
			on_insert=>{ '*CREATED_TS'=>'now()' },
			key=>['MID','STRATEGY_ID'],sql=>1);
		$udbh->do($pstmt);
		&DBINFO::db_user_close();

		print STDERR "$pstmt\n";
		}

	return($err);	
	}

##
##
sub nuke_strategy {
	my ($self,$STRATID) = @_;

	my ($MID) = $self->mid();
	my ($USERNAME) = $self->username();

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "delete from REPRICE_STRATEGIES where MID=$MID /* $USERNAME */ and STRATEGY_ID=".$udbh->quote($STRATID);
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	}

##
##
sub get_strategy {
	my ($self,$STRATID) = @_;

	my $USERNAME = $self->username();
	my $MID = $self->mid();

	my $udbh = &DBINFO::db_user_connect($USERNAME);

	my $pstmt = "select * from REPRICE_STRATEGIES where MID=$MID /* $USERNAME */ and STRATEGY_ID=".$udbh->quote($STRATID);
	print STDERR $pstmt."\n";
	my ($ref) = undef;
	if ($ref = $udbh->selectrow_hashref($pstmt)) {
		$ref->{'%'} = Load($ref->{'YAML'});
		delete $ref->{'YAML'};
		
		if (not $self->is_remote()) {
			## always reload the seller and sellerid from global variable
			my ($gref) = ZWEBSITE::fetch_globalref($self->username());
			$ref->{'%'}->{'seller'} = $gref->{'amz_merchantname'};
			$ref->{'%'}->{'sellerid'} = $gref->{'amz_sellerid'};
			}

		$ref->{'%bully'} = {};	
		foreach my $line (split(/[\n\r]+/,$ref->{'%'}->{'bully_sellers'})) {
			next if (substr($line,0,1) eq '#');
			$line =~ s/[\s]+$//gs; # remove trailing whitespace
			$line = uc($line);
			$ref->{'%bully'}->{$line}++;
			}

		$ref->{'%ignore'} = {};
		foreach my $line (split(/[\n\r]+/,$ref->{'%'}->{'ignore_sellers'})) {
			next if (substr($line,0,1) eq '#');
			$line =~ s/[\s]+$//gs; # remove trailing whitespace
			$line = uc($line);
			$ref->{'%ignore'}->{$line}++;
			}

		#if ($strategyref->{'%'}->{'seller'} eq '') {
		#	$ref->{'err'} = "Seller not specified in strategy: $dbrow->{'STRATEGY_ID'}";
		#	}

		}
	else {
		$ref->{'err'} = "STRATEGY[$STRATID] is invalid";
		}

	&DBINFO::db_user_close();
	return($ref);
	}

##
## NOTE: $USERNAME can also be blank, then %filters should be the 
##
sub list_strategies {
	my ($self,%filters) = @_;

	my @RESULT = ();
	my ($USERNAME) = $self->username();
	my ($MID) = $self->mid();

	my $udbh = &DBINFO::db_user_connect($self->username());

	my $pstmt = "select * from REPRICE_STRATEGIES where MID=".$self->mid();
	$pstmt .= " order by STRATEGY_ID";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $ref = $sth->fetchrow_hashref() ) {
		$ref->{'%'} = Load($ref->{'YAML'});
		delete $ref->{'YAML'};
		push @RESULT, $ref;
		}	
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@RESULT);
	}

##
##
##

##
##
#sub add_product {
#	my ($USERNAME,$SKU,$ASIN,$STRATID,$varref) = @_;
#	my $rdbh = &WATCHER::db_ec2rds_connect($USERNAME);;
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#	my ($pstmt) = &DBINFO::insert($rdbh,'REPRICE_STRATEGIES',{
#		'USERNAME'=>$USERNAME,'MID'=>$MID,
#		'SKU'=>$SKU,
#		'ASIN'=>$ASIN,
#		'STRATEGY_ID'=>$STRATID,
#		'MODIFIED_GMT'=>time(),
#		'VAR_MIN_PRICE'=>sprintf("%0.2f",$varref->{'min_price'}),
#		'VAR_MIN_SHIP'=>sprintf("%0.2f",$varref->{'min_ship'}),
#		},
#		on_insert=>{ 'CREATED_GMT'=>time() },
#		key=>['MID','SKU'],sql=>1);
#	$rdbh->do($pstmt);
#	&WATCHER::db_ec2rds_close();
#	return();	
#	}

##
##
#sub nuke_product {
#	my ($USERNAME,$SKU) = @_;
#
#	my $rdbh = &WATCHER::db_ec2rds_connect($USERNAME);;
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#	my $pstmt = "delete from AMAZON_PID_UPCS where MID=$MID /* $USERNAME */ and SKU=".$rdbh->quote($SKU);
#	$rdbh->do($pstmt);
#	&WATCHER::db_ec2rds_close();
#	}

##
##
#sub get_product {
#	my ($USERNAME,$SKU) = @_;
#
#	my $rdbh = &WATCHER::db_ec2rds_connect($USERNAME);;
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#	my $pstmt = "select * from AMAZON_PID_UPCS where MID=$MID /* $USERNAME */ and SKU=".$rdbh->quote($SKU);
#	my ($ref) = $rdbh->selectrow_hashref($pstmt);
#	&WATCHER::db_ec2rds_close();
#	return($ref);
#	}

##
##
#sub list_products {
#	my ($USERNAME,%filters) = @_;
#
#	my @RESULT = ();
#	my $rdbh = &WATCHER::db_ec2rds_connect($USERNAME);;
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#	my $pstmt = "select * from AMAZON_PID_UPCS where MID=$MID /* $USERNAME */";
#	my $sth = $rdbh->prepare($pstmt);
#	$sth->execute();
#	while ( my $ref = $sth->fetchrow_hashref() ) {
#		push @RESULT, $ref;
#		}	
#	$sth->finish();
#	&WATCHER::db_ec2rds_close();
#	return(\@RESULT);
#	}










1;