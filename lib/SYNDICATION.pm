package SYNDICATION;

use Carp;
use UNIVERSAL;
use YAML::Syck;
use Class::Runtime;
use URI::Escape::XS;
use strict;

use lib "/backend/lib";
use base 'LISTING::MSGS';
require PRODUCT;
require TXLOG;
require DBINFO;
require ZTOOLKIT;
require ZWEBSITE;
require ZOOVY;
require NAVCAT::FEED;
require TODO;
require WHOLESALE;
require INVENTORY2;
require INVENTORY2::UTIL;
require SITE;
require MEDIA;
require PRODUCT;
#require PRODUCT::STASHES;
require PRODUCT::BATCH;
require LISTING::MSGS;
##
use Data::Dumper;
use Archive::Zip;


# @SYNDICATION::ALLMSGS = ('PID','SETUP','SUMMARY','INFO','PAUSE','WARN','ISE','FATAL','SUCCESS','HINT','ERROR','GOOD','FAIL','STOP','DEBUG','SUSPEND');
@SYNDICATION::TXMSGS = (
	'SETUP',		## setup/config message
	'SUMMARY',	## SUMMARY-PRODUCT ex.
	'ISE',		##
	'SUCCESS',	## 
	'FATAL',		## a non recoverable error (due to a configuration)
	'ERROR',		## 
	'REDO',		##
	'STOP',		##	the feed cannot run (non-error, just nothing to do)
	'SUSPEND'	## an implicit non-fatal suspend request
	);

=pod

[[SECTION]]
In this example product "ABC" exists in two categories, with the following configuration(s):

Scenario 1: Normal operation
.i-am-a.really.long.category.name	<any valid category>
.i-am-a.short.category			<any valid category>

Syndication engine will elect to use .i-am-a.really.long.category.name because it is longer.

Scenario 2:
.i-am-a.really.long.category.name	IGNORED
.i-am-a.short.category			<any valid category>

Syndication engine will ignore .i-am-a.really.long.category.name, resulting in 
.i-am-a.short.category being selected as the best category for syndication.

Example uses of IGNORED: 
* Ignoring an entire taxonomy on the site such as "manufacturers"

Scenario 3: Using blocked categories
.i-am-a.really.long.category.name	<any valid category>
.i-am-a.short.category			BLOCKED

Syndication engine will select .i-am-a.really.long.category.name as the best match for
product ABC (because it is longer, and therefore ranks higher).  
However because product ABC also existed in the short category, it was added to the syndication
engines internal "block list", no matter which category is selected for ABC - product ABC will NOT
be sent because it appears in the short category (which is blocked).
[[/SECTION]]

[[STAFF]]
two new events:

SYNDICATION.SUCCESS
SYNDICATION.FAILURE

alter table SYNDICATION add INFORM_ZOOVY_MARKETING tinyint default 0 not null;

modify syndication generic so when support is in the interface they can check a box
which enables/disables that property, which should be a logged event 
(in the SYNDICATION LOG)

when a SYNDICATION.FAILURE is fired for a marketplace that has INFORM_ZOOVY_MARKETING
enabled then we can send an email to marketing@zoovy.com 

and if you or andrew want to be notified on specific destination codes then you can just
add specific "if" cases for that in user events (for now).

finally andrew or liz can build a panel which goes through $ZOOVY::CLUSTERs and
displays the IS_ACTIVE status (true or false) status for each syndication which has
INFORM_ZOOVY_MARKETING 


[[/STAFF]]

=cut




##
## IS_ACTIVE (bitwise)
##		1 = yes (required)
##		2 = test bit (only simulate, don't actually transfer)
##		4 = don't archive files
##		64 = don't submit products
##

##
## DSTCODES are:
##		AMZ - Amazon
##		BUY - buy.com
##		BSF - buysafe
##		EBS - EBAY Stores
##		GOO - Google Shopping / Froogle
##		BZR - Bizrate / Shopzilla
##

##
## add to webdoc:





##		[[MASON]]
##		% use SYNDICATION;
##		% print SYNDICATION::webdoc_panel("SHO"); 
##		[[/MASON]]
##
sub webdoc_panel {
	my ($dstcode) = @_;

	my $info = $SYNDICATION::PROVIDERS->{uc($dstcode)};
	
	return(Dumper($info));
	}


## returns the associated navcat object if available
sub nc { return($_[0]->{'*NC'}); }
sub is_active { return($_[0]->{'IS_ACTIVE'}); }
sub is_suspended { return($_[0]->{'IS_SUSPENDED'}); }


sub set_suspend {
	my ($self,$reasoncode,$reasonmsg) = @_;
	## reason code:
	##		1 = ise
	##		2 = stop
	$self->{'IS_SUSPENDED'} = $reasoncode;
	$self->msgs()->pooshmsg(sprintf("SUSPEND|+Reason:%s",$reasonmsg));
	}

sub get_tracking {
	my ($self) = @_;
	return(&SYNDICATION::get_userprtdst_tracking($self->username,$self->prt(),$self->dst()));
	}


##
## removes bad characters from text
##
sub declaw {
	my ($val) = @_;
	$val =~ s/<[Jj][Aa][Vv][Aa].*?>.*?<\/[Jj][Aa][Vv][Aa].*?>//gso;
	$val =~ s/<[Ss][Cc][Rr][Ii][Pp][Tt].*?<\/[Ss][Cc][Rr][Ii][Pp][Tt]>//gso;
	## strip out advanced wikitext (%softbreak%, %hardbreak%)
	$val =~ s/%\w+%//gs;

	$val =~ s/<.*?>//gs;
	$val =~ s/[\t]+/ /g;
	$val =~ s/[^\"\w\.\:\:\!\@\#\$\%\^\&\*\(\)]+/ /g;
	$val =~ s/[\n\r]+//gs;		
	$val =~ s/^[\s]+//gs;
	$val =~ s/[\s]+$//gs;

	return($val);
	}

##
## options:
##
sub public_product_link {
	my ($self, $P, %options) = @_;

	## create links
	## product link
	my $style = $self->get('.linkstyle') || 'vstore';

	#my %vars = (
	#	'origin'=>'cpc',
	#	'mkt'=>$self->dstcode(),
	#	'meta'=>$meta
	#	);

	my $link = sprintf("http://www.%s%s",$self->domain(),$P->public_url('origin'=>'cpc','mkt'=>$self->dstcode(),'style'=>$style));

	## product link with meta data
	my $analytics_data = '';
	
	#if (not defined $self->provider()->{'analytics_utm_source'}) {
	#	}
	#elsif ($self->nsref()->{'analytics:syndication'} eq 'GOOGLE') {
	#	## CUSTOMER IS USING GOOGLE ANALYTICS SO WE'LL USE THEIR TRACKING STYLE.

	#	my $utm_campaign_var = $SYNDICATION::PROVIDERS{$self->dstcode()}->{'analytics_utm_campaign_var'};
	#	if (not defined $P->fetch($utm_campaign_var)) {
	#		## no campaign variable set in product level, so we'll use product id for campaign.
	#		$utm_campaign_var = $P->pid();
	#		}

	#	$analytics_data = sprintf("utm_source=%s&utm_medium=CPC&utm_content=%s&utm_campaign=%s",
	#		$SYNDICATION::PROVIDERS{$self->dstcode()}->{'analytics_utm_source'},
	#		$P->fetch( $SYNDICATION::PROVIDERS{$self->dstcode()}->{'analytics_utm_content_var'} ),
	#		$utm_campaign_var
	#		);
	#	}

	#if (defined $SYNDICATION::PROVIDERS{$self->dstcode()}->{'linkmeta'}) {
	#	my $meta = $SYNDICATION::PROVIDERS{$self->dstcode()}->{'linkmeta'};
	#	$link .= "?meta=$meta";
	#	if ($P->fetch('zoovy:analytics_data') ne '') {
	#		$link .= '&'.$P->fetch('zoovy:analytics_data');
	#		}
	#	}

	return($link);
	}


##
## this returns an array of tracking #'s in an array format
##		[ #DBID, ORDERID#, CARRIERCODE, TRACKING#, SHIPPED_GMT ]
##	note: don't call this direct, use get_tracking instead
##
sub get_userprtdst_tracking {
	my ($USERNAME,$PRT,$DST) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	($PRT) = int($PRT);

	my @RESULTS = ();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($qtDST) = $udbh->quote($DST);
	my $pstmt = "select ID,OID,CARRIER,TRACKING,SHIPPED_GMT from USER_EVENTS_TRACKING where MID=$MID /* $USERNAME */ and PRT=$PRT and DST=$qtDST and ACK_GMT=0";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();

	my %GOTIT = ();
	while ( my ($ID,$OID,$CARRIER,$TRACKING,$SHIPPED_GMT) = $sth->fetchrow() ) {
		# print "ID:$ID OID:$OID\n";
		push @RESULTS, [ $ID, $OID, $CARRIER, $TRACKING, $SHIPPED_GMT, $DST ];
		}
	$sth->finish();

	## backup whatever we've got in REDIS
	my ($redis) = &ZOOVY::getRedis($USERNAME,1);
	my $REDISQUEUE = uc(sprintf("EVENTS.ORDER.SHIP.%s.%s",$DST,$USERNAME));
	my ($length) = $redis->llen($REDISQUEUE);
	if ($length > 0) {
		my @ORDERLIST = $redis->lrange($REDISQUEUE,0,100);
		foreach my $OID (@ORDERLIST) {
			my ($O2) = CART2->new_from_oid($USERNAME,$OID);
			foreach my $trk (@{$O2->tracking()}) {
				push @RESULTS, [ 0, $OID, $trk->{'carrier'}, $trk->{'track'}, $trk->{'created'}, $DST ];
				}
			}
		}
	

	&DBINFO::db_user_close();
	return(\@RESULTS);
	}


sub ack_tracking {
	my ($self, $TRACKREF) = @_;
	return(&SYNDICATION::ack_userprt_tracking($self->username(),$self->prt(),$TRACKREF));
	}


##
## acknowledge tracking #'s that have been sent to a marketplace (uses output from get_tracking)
##
sub ack_userprt_tracking {
	my ($USERNAME,$PRT,$RESULTREF) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	($PRT) = int($PRT);

	my $success = 0;
	my $TS = time();
	my @RESULTS = ();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($redis) = &ZOOVY::getRedis($USERNAME,1);
	foreach my $set (@{$RESULTREF}) {
		my ($ID,$OID,$CARRIER,$TRACK,$CREATED,$DST) = @{$set};	## we only care about position zero which is the ID # in the database
		$ID = int($ID);
		if ($ID==0) {
			my $REDISQUEUE = uc(sprintf("EVENTS.ORDER.SHIP.%s.%s",$DST,$USERNAME));
			$redis->lrem($REDISQUEUE,0,$OID);
			}
		else {
			my $pstmt = "update USER_EVENTS_TRACKING set ACK_GMT=$TS where MID=$MID and PRT=$PRT and ID=$ID limit 1";
			$udbh->do($pstmt);
			$success++;
			}
		}
	&DBINFO::db_user_close();
	return($success);
	}


##
## takes: array of skus's that need to have their logs cleanedup.
##
sub cleanup_syndication_pid_errors {
	my ($USERNAME,$PRT,$DST,$SKUS,%options) = @_;
	## note current table is NOT PRT specific, but we will probably need to make it that way eventually.

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $udbh = &DBINFO::db_user_connect($USERNAME);

	my %PIDS = ();
	foreach my $SKU (@{$SKUS}) {
		my ($PID) = &PRODUCT::stid_to_pid($SKU);
		if (not defined $PIDS{$PID}) { $PIDS{$PID} = []; }
		push @{$PIDS{$PID}}, $SKU;
		}
	my @PIDS = keys %PIDS;

	foreach my $PIDBATCH (@{&ZTOOLKIT::batchify(\@PIDS,100)}) {
		#my $pstmt = "/* cleanup_sku_log */ update SYNDICATION_PID_ERRORS set ARCHIVE_GMT=".time().
		#	" where MID=$MID /* $USERNAME */ ".
		#	sprintf(" and DSTCODE=%s ",$udbh->quote($DST)).
		#	" and PID in ".&DBINFO::makeset($udbh,$PIDBATCH);
		my $pstmt = "/* cleanup_sku_log */ delete from SYNDICATION_PID_ERRORS ";
			" where MID=$MID /* $USERNAME */ ".
			sprintf(" and DSTCODE=%s ",$udbh->quote($DST)).
			" and PID in ".&DBINFO::makeset($udbh,$PIDBATCH);
		if ($options{'SKU_ONLY'}==1) {
			my @ONLYSKUS = ();
			foreach my $pid (@{$PIDBATCH}) {
				foreach my $sku (@{$PIDS{$pid}}) {
					push @ONLYSKUS, $sku;
					}
				}
			$pstmt .= " and SKU in ".&DBINFO::makeset($udbh,\@ONLYSKUS);
			}
		print STDERR $pstmt."\n";
		$udbh->do($pstmt);
		}

	&DBINFO::db_user_close();
	}



##
## logs a SKU into SYNDICATION_PID_ERRORS, if the config element for the SKU has 'suspend_products' set >0 then
##	an additional suspension check will be performed until the SKU's properties are updated. 
##
sub suspend_sku {
	my ($self,$SKU,$ERRCODE,$ERRMSG,%options) = @_;

	my ($PID) = &PRODUCT::stid_to_pid($SKU);
	my $CREATED_GMT = $options{'CREATED_GMT'};
	if (not $CREATED_GMT) { $CREATED_GMT = time(); }
	my $DST = '';

	my $DOCID = int(sprintf("%d",$options{'DOCID'}));
	my $BATCHID = sprintf("%s",$options{'BATCHID'});
	my $LISTING_EVENT_ID = int($options{'LISTING_EVENT_ID'});

	my $FEED = 0;
	if ($self->type() eq 'init') { $FEED = 1; }
	elsif ($self->type() eq 'products') { $FEED = 1; }
	elsif ($self->type() eq 'prices') { $FEED = 2; }
	elsif ($self->type() eq 'images') { $FEED = 4; }
	elsif ($self->type() eq 'inventory') { $FEED = 8; }
	elsif ($self->type() eq 'relations') { $FEED = 16; }
	elsif ($self->type() eq 'shipping') { $FEED = 64; }
	elsif ($self->type() eq 'docs') { $FEED = 128; }
	elsif ($self->type() eq 'parentage') { $FEED = 1<<14; }
	elsif ($self->type() eq 'deleted') { $FEED = 1<<15; }

	my ($udbh) = &DBINFO::db_user_connect($self->username());

	my $pstmt = "select ID,ERRCODE,ERRMSG from SYNDICATION_PID_ERRORS where ".
		" MID=".$self->mid()." /* ".$self->username()." */ and ".
		" SKU=".$udbh->quote($SKU)." and ".
		" DSTCODE=".$udbh->quote($self->dstcode())." and ".
		" FEED=".int($FEED);
	my ($dbID,$dbERRCODE,$dbERRMSG,$dbDOCID) = $udbh->selectrow_array($pstmt);
		
	my $handled = 0;
	if ($ERRCODE ne $dbERRCODE) {}
	elsif ($ERRMSG eq $dbERRMSG) {}
	elsif (($DOCID > 0) && ($dbDOCID = $DOCID)) { $handled++; }  ## same docid, same errcode, same errmsg
	else {
		## same, so we bump OCCURRED_TS, ERRCOUNT, DOCID
		#my $pstmt = &DBINFO::insert($udbh,'SYNDICATION_PID_ERRORS',{
		#	'*OCCURRED_TS'=>'now()',
		#	'*ERRCOUNT'=>'ERRCOUNT+1',
		#	'*DOCID'=>$DOCID, 	# integer
		#	},'verb'=>'update','key'=>{'MID'=>$self->mid(),'ID'=>$dbID});
		# print STDERR "$pstmt\n";
		# $udbh->do($pstmt);
		$handled++;
		}

	if (not $handled) {
		## we need to delete old records (maybe)
		if ($dbID>0) {
			$pstmt = "delete from SYNDICATION_PID_ERRORS where MID=".$self->mid()." and ID=".int($dbID);
			# print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			}

		## and add a new record.
	   my ($pstmt) = &DBINFO::insert($udbh,'SYNDICATION_PID_ERRORS',{
			'*OCCURRED_TS'=>'now()',
   	   MID=>$self->mid(),
   	   DSTCODE=>$self->dstcode(),
			PID=>$PID,
			SKU=>$SKU,
			FEED=>$FEED,
			ERRCODE=>$ERRCODE,
			ERRMSG=>$ERRMSG,
			BATCHID=>$BATCHID,
			LISTING_EVENT_ID=>$LISTING_EVENT_ID,
			DOCID=>$DOCID,
			},sql=>1,'verb'=>'insert');
		# print STDERR $pstmt."\n";
	   $udbh->do($pstmt);
		}
   &DBINFO::db_user_close();
   return();
	}



##
## looks up the current provider in the $SYNDICATION::PROVIDERS table
##
sub provider {
	my ($self) = @_;

	my $provider = $SYNDICATION::PROVIDERS{$self->dst()};
	if (not defined $provider) { 
		$provider = {};
		$provider->{'title'} = sprintf("Unknown DST:%s",$self->dst());
		}
	return($provider);
	}

##
## this is going to eventually replace SYNDICATION::DSTCODES .. but I use it to keep
##	track of which ones i've started or finished moving over to app6:/httpd/servers/customfeed/batch.pl
##
##	module is the name of the /httpd/modules/SYNDICATION/module.pm file. 
##
%SYNDICATION::PROVIDERS = (
	## this is a custom syndication (for orangeonions)
	## assigned a dst because other merchant may use in the future
	'TRN'=>{
		# send_products=>86400,
		title=>'TurnTo',
		module=>'TURNTO',
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		expandPOGs=>1,
		validationLogPlease=>1,
		source=>'PRODUCTS-ALL',
		store=>'DOMAIN',
		},
	'SRS'=>{
		# send_products=>0,
		send_pricing=>3600,
		send_inventory=>3600,
		send_tracking=>3600*3,
		grab_orders=>3600*3,
		title=>'Sears',
		module=>'SEARS',
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		expandPOGs=>1,
		validationLogPlease=>1,
		# link=>'/biz/syndication/sears/?VERB=EDIT&PROFILE=%PROFILE%',
		source=>'PRODUCTS-ALL',
		store=>'PRT',
		},
	'EGG'=>{
		send_products=>0,
		send_inventory=>3600,
		send_tracking=>3600*3,
		#send_inventory=>0,
		#send_tracking=>0,
		grab_orders=>3600,
		#grab_orders=>0,
		title=>'NewEgg',
		module=>'NEWEGG',
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		expandPOGs=>1,
		validationLogPlease=>1,
		# link=>'/biz/syndication/newegg/?VERB=EDIT&PROFILE=%PROFILE%',
		source=>'PRODUCTS-ALL',
		store=>'PRT',
		},
	'BCM'=>{
		send_products=>86400,
		title=>'Become.com',
		module=>'BECOME',
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		expandPOGs=>2,
		source=>'WEBSITE-ALL',
		validationLogPlease=>1,
      analytics_utm_source=>'BECOME',
      analytics_utm_content_var=>'become:content',
      analytics_utm_campaign_var=>'become:campaign',		
		category_webdoc=>51553,
		store=>'DOMAIN',
		},
	'SMT'=>{
		send_products=>86400,
		title=>'Smarter.com',
		module=>'SMARTER',
		validationLogPlease=>1,
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		source=>'PRODUCTS-ALL',
      analytics_utm_source=>'SMARTER',
      analytics_utm_content_var=>'smarter:content',
      analytics_utm_campaign_var=>'smarter:campaign',		
		category_webdoc=>51558,
		store=>'DOMAIN',
		expandPOGs=>2,
		},
	'DIJ'=>{
		send_products=>86400,
		title=>'DijiPop.com',
		module=>'DIJIPOP',
		validationLogPlease=>1,
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		source=>'PRODUCTS-ALL',
		category_webdoc=>0,
		expandPOGs=>2,
		store=>'DOMAIN',
		},
	'LNK'=>{
		send_products=>86400,
		title=>'LinkShare.com',
		module=>'LINKSHARE',
		validationLogPlease=>1,
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		source=>'PRODUCTS-ALL',
      analytics_utm_source=>'LINKSHARE',
      analytics_utm_content_var=>'linkshare:content',
      analytics_utm_campaign_var=>'linkshare:campaign',		
		category_webdoc=>0,
		store=>'DOMAIN',
		expandPOGs=>2,
		},
	'FND'=>{
		send_products=>86400,
		validationLogPlease=>1,
		title=>'TheFind.com',
		module=>'THEFIND',
		validationLogPlease=>1,
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		source=>'WEBSITE-ALL',
      analytics_utm_source=>'THEFIND',
      analytics_utm_content_var=>'thefind:content',
      analytics_utm_campaign_var=>'thefind:campaign',		
		category_webdoc=>51516,
		store=>'DOMAIN',
		expandPOGs=>2,
		},
	'PTO'=>{
		send_products=>86400,
		title=>'Pronto.com',
		module=>'PRONTO',
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		source=>'WEBSITE-ALL',
		validationLogPlease=>1,
      analytics_utm_source=>'PRONTO',
      analytics_utm_content_var=>'pronto:content',
      analytics_utm_campaign_var=>'pronto:campaign',
		category_webdoc=>51520,
		store=>'DOMAIN',
		expandPOGs=>2,
		},
	'IMS'=>{
		send_products=>86400,
		title=>'Imshopping.com',
		module=>'IMSHOPPING',
		source=>'WEBSITE-ALL',
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
      analytics_utm_source=>'IMSHOPPING',
      analytics_utm_content_var=>'imshopping:content',
      analytics_utm_campaign_var=>'imshopping:campaign',
		store=>'DOMAIN',
		expandPOGs=>2,
		},
	'WSH'=>{
		send_products=>86400,
		title=>'Wishpot.com',
		module=>'WISHPOT',
		source=>'WEBSITE-ALL',
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		analytics_utm_source=>'WISHPOT',
		analytics_utm_content_var=>'wishpot:content',
		analytics_utm_campaign_var=>'wishpot:campaign',		
		category_webdoc=>51584,
		validationLogPlease=>1,
		store=>'DOMAIN',
		expandPOGs=>2,
		},
	'SHO'=>{
		send_products=>86400,
		title=>'Shopping.com',
		module=>'SHOPPINGCOM',
		# allowed=>'shopping:allowed',
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		expandPOGs=>2,
		source=>'WEBSITE-ALL',
		analytics_utm_source=>'SHOPCOM',
		analytics_utm_content_var=>'shopping:content',
		analytics_utm_campaign_var=>'shopping:campaign',
		category_webdoc=>51524,
		store=>'DOMAIN',
		},
	'CJ'=>{
		send_products=>86400,
		title=>'Commission Junction',
		module=>'CJUNCTION',
		# allowed=>'cj:allowed',
		syndicationOPTIONs=>1+4,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		expandPOGs=>2,
		source=>'WEBSITE-ALL',
		validationLogPlease=>1,
		store=>'DOMAIN',
		},
	'EBF'=>{
		send_products=>86400,
		send_inventory=>3600,
		suspend_products=>1,
		grab_orders=>3600,
		title=>'eBay Fixed Price',
		module=>'EBAY',
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		source=>'PRODUCTS-MAPPED',
		'expandPOGs'=>3,		## thanks syndication, we got this.
		store=>'PRT',
		},
	'BIN'=>{
		send_products=>86400,
		title=>'BING/Microsoft Cashback',
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		# allowed=>'bing:allowed',
		module=>'BING',
		analytics_utm_source=>'BINGCB',
		analytics_utm_content_var=>'bing:content',
		analytics_utm_campaign_var=>'bing:campaign',
		expandPOGs=>2,
		validationLogPlease=>1,
		category_webdoc=>51526,
		source=>'WEBSITE-ALL',
		store=>'DOMAIN',
		},
 	'GOO'=>{
		send_products=>86400,
		send_tracking=>86400,
		send_orderstatus=>86400,
 		title=>'Google Shopping',
      syndicationOPTIONs=>1,	
		'navcat_hidden'=>0,
		'navcat_lists'=>1,
		'send_parents'=>0,
 		module=>'GOOGLEBASE',
		expandPOGs=>1,
		validationLogPlease=>1,
		analytics_utm_source=>'gbase',
		analytics_utm_content_var=>'gbase:content',
		analytics_utm_campaign_var=>'gbase:campaign',
		category_webdoc=>51521,
		source=>'PRODUCTS-MAPPED',
		store=>'DOMAIN',
 		},
	## MAP
	'GSM'=>{
		send_products=>86400,
		title=>'Site Map',
		module=>'SITEMAP',
		headerOnly=>1,
		source=>'WEBSITE-ALL',
		# link=>'/biz/syndication/sitemap/?VERB=EDIT&PROFILE=%PROFILE%',
		store=>'DOMAIN',
		expandPOGs=>2,
		},
   'PRV'=>{
		send_products=>86400,
      title=>'PowerReviews',
      module=>'POWERREV',
		navcats=>1,
		store=>'DOMAIN',
		expandPOGs=>2,
      },
	'BZR'=>{
		send_products=>86400,
		title=>'BizRate',
		module=>'BIZRATE',
      syndicationOPTIONs=>1,	
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		analytics_utm_source=>'BIZRATE',
		analytics_utm_content_var=>'bizrate:content',
		analytics_utm_campaign_var=>'bizrate:campaign',
		category_webdoc=>51578,
		expandPOGs=>2,
		# link=>'/biz/syndication/bizrate/?VERB=EDIT&PROFILE=%PROFILE%',
		store=>'DOMAIN',
		},
	'PGR'=>{
		send_products=>86400,
		title=>'PriceGrabber',
		module=>'PRICEGRAB',
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		analytics_utm_source=>'PRICEGRAB',
		analytics_utm_content_var=>'pricegrabber:content',
		analytics_utm_campaign_var=>'pricegrabber:campaign',
		category_webdoc=>51523,
		# link=>'/biz/syndication/pricegrabber/?VERB=EDIT&PROFILE=%PROFILE%',
		source=>'WEBSITE-ALL',
		store=>'DOMAIN',
		expandPOGs=>1,
		},
	'BST'=>{
		send_products=>86400,
		send_inventory=>3600,
		send_tracking=>3600*3,
		grab_orders=>3600,
      title=>'BestBuy Marketplace',
      module=>'BUYCOM',		## NOTE: BST and BUY both use same MODULE
		expandPOGs=>1,
		validationLogPlease=>1,
		# link=>'/biz/syndication/bestbuy/?VERB=EDIT&PROFILE=%PROFILE%',
		source=>'PRODUCTS-ALL',
		store=>'PRT',
		},
   'BUY'=>{
		send_products=>86400,
		send_inventory=>3600,
		send_tracking=>3600*3,
		grab_orders=>3600,
      title=>'BUY.com',		
      module=>'BUYCOM',		## NOTE: BST and BUY both use same MODULE
		expandPOGs=>1,
		validationLogPlease=>1,
		# link=>'/biz/syndication/buycom/?VERB=EDIT&PROFILE=%PROFILE%',
		source=>'PRODUCTS-ALL',
		store=>'PRT',
      },
	'SAS'=>{
		send_products=>86400,
		title=>'Share-A-Sale',
		module=>'SHAREASALE',
		syndicationOPTIONs=>1,		## 
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		analytics_utm_source=>'SAS',
		analytics_utm_content_var=>'sas:content',
		analytics_utm_campaign_var=>'sas:campaign',
		# link=>'/biz/shareasale/doba/?VERB=EDIT&PROFILE=%PROFILE%',
		category_webdoc=>51597,
		source=>'WEBSITE-ALL',
		store=>'DOMAIN',
		expandPOGs=>1,
		},
	'AMZ'=>{
		grab_orders=>3600,
		send_tracking=>3600,
		send_inventory=>60*20,
		title=>'Amazon Seller Central',
		module=>'AMAZON',
		source=>'',
		store=>'PRT',
		},
	'APA'=>{
		send_products=>86400,
		title=>'Amazon Product Ads',
		module=>'AMAZONPA',
		source=>'WEBSITE-ALL',
      analytics_utm_source=>'AMAZONPA',
      analytics_utm_content_var=>'amzpa:content',
      analytics_utm_campaign_var=>'amzpa:campaign',
		validationLogPlease=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>1,
		'send_parents'=>1,
		# link=>'/biz/syndication/amazonpa/?VERB=EDIT&PROFILE=%PROFILE%',
		source=>'WEBSITE-ALL',
		expandPOGs=>0,
		store=>'DOMAIN',
		},
	'EBY'=>{
		title=>'eBay',
		compatible=>0,
		store=>'PRT',
		},
	'NXT'=>{
		send_products=>86400,
		title=>'NexTag',
		compatible=>1,
		module=>'NEXTAG',
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		expandPOGs=>2,
		analytics_utm_content_var=>'nextag:content',
		analytics_utm_campaign_var=>'nextag:campaign',		
		link=>'/biz/syndication/nextag/?VERB=EDIT&PROFILE=%PROFILE%',
		source=>'WEBSITE-ALL',
		category_webdoc=>51579,		
		navcats=>1,
		store=>'DOMAIN',
		},
   'HSN'=>{
		send_products=>86400,
		send_inventory=>3600,
		send_tracking=>3600*3,
		grab_orders=>3600,
		title=>'HSN.com',
		module=>'HSN',
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		expandPOGs=>1,
		validationLogPlease=>1,
		link=>'/biz/syndication/hsn/?VERB=EDIT&PROFILE=%PROFILE%',
		source=>'PRODUCTS-ALL',
		store=>'DOMAIN',
      },
	## this is a custom syndication (for toynk)
	## - it was built as a copy of the Googlebase feed
	## - it is being sent to Channel Advisor for Google Product Ads
	'TY1'=>{
		send_products=>43200,
		title=>'Custom Toynk 1',
		module=>'TOYNK001',
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		expandPOGs=>1,
		validationLogPlease=>1,
		source=>'PRODUCTS-ALL',
		store=>'DOMAIN',
		},
	## this is a custom syndication (for orangeonions)
	## tab-delimited basic data
	#'OR1'=>{
	#	send_products=>86400,
	#	title=>'Custom OrangeOnions 1',
	#	module=>'ORANGEONIONS001',
	#	syndicationOPTIONs=>1,
	#	'navcat_hidden'=>0,
	#	'navcat_lists'=>0,
	#	'send_parents'=>0,
	#	validationLogPlease=>1,
	#	source=>'WEBSITE-ALL',
	#	store=>'DOMAIN',
	#	},
	## this is a custom syndication (for zephyrsports)
	## - it was built as a copy of the Googlebase feed
	## - it is being sent to NAME HERE for Google Product Ads
	'ZE1'=>{
		send_products=>86400,
		title=>'Custom Zephyrsports 1',
		module=>'ZEPHYRSPORTS001',
		syndicationOPTIONs=>1,
		'navcat_hidden'=>0,
		'navcat_lists'=>0,
		'send_parents'=>0,
		expandPOGs=>1,
		validationLogPlease=>1,
		source=>'WEBSITE-ALL',
		store=>'DOMAIN',
		}

   );


%SYNDICATION::DSTCODES = ();
foreach my $intref (@ZOOVY::INTEGRATIONS) {
	if ($intref->{'dst'} eq '') {
		}
	elsif (not defined $SYNDICATION::PROVIDERS{ $intref->{'dst'} }) {
		## no corresponding entry in %SYNDICATION::PROVIDERS
		}
	else {
		my $dstcode = $intref->{'dst'};
		$SYNDICATION::PROVIDERS{$dstcode}->{'attrib'} = $intref->{'attr'}; 
		if (not defined $SYNDICATION::PROVIDERS{$dstcode}->{'linkmeta'}) {
			$SYNDICATION::PROVIDERS{$dstcode}->{'linkmeta'} = $intref->{'meta'}; 
			}
		
		$SYNDICATION::DSTCODES{$dstcode} = $SYNDICATION::PROVIDERS{$dstcode}->{'title'};
		}
	}



##
## a standard validation library for handling most types of standard validation with inheritence issues.
##$SYNDICATION::GOOGLEBASE::ATTRIBUTES = [
##   [ 'gbase:prod_name', 'zoovy:prod_name', { 'required'=>1, 'maxlength'=>70, 'nb'=>1 } ],
##   ];
##
sub validate {
	my ($ATTRIBUTES,$prodref) = @_;

	my $ERROR = undef;
	foreach my $row (@{$ATTRIBUTES}) {
		my ($attrib,$loadfrom,$validation) = @{$row};
		## inherit $attrib from $loadfrom
		if (not defined $prodref->{$attrib}) { 
			$prodref->{$attrib} = $prodref->{$loadfrom}; $attrib = $loadfrom; 
			}
		if (not defined $validation) {
			## undef is a totally valid state for validation.
			}
		elsif (ref($validation) eq 'HASH') {
			foreach my $k (keys %{$validation}) {
				next if (defined $ERROR);
				if (($k eq 'required') && (not defined $prodref->{$attrib})) { 
					$ERROR = "{$attrib}Required field $attrib not set"; 
					}
				elsif (($k eq 'maxlength') && (length($prodref->{$attrib})>$validation->{$k})) {
					$ERROR = "{$attrib}Field $attrib exceeds maximum length of $validation->{$k}";
					}
				elsif (($k eq 'nb') && ($prodref->{$attrib} eq '')) {
					$ERROR = "{$attrib}Field $attrib cannot be blank.";
					}
				}
			}
		else {
			Carp::confess::confess("invalid validation type");
			}
		}
	return($ERROR);
	}



sub isBatchJob {
	my ($self) = @_;

	if (not defined $self->{'*PARENT'}) {
		return(0);	# nope, not a batch job
		}
	elsif (ref($self->{'*PARENT'}) eq 'BATCHJOB::SYNDICATION') {
		return(1);
		}
	else {
		return(0);
		}
	return(0);
	}





##
## erefid is the external/marketplace reference id
##		this is intended to lookup an see if an order has already been created - in order for this to work
##		the order must have been associated with the proper mkt field.
##
## perl -e 'use lib "/httpd/modules"; use SYNDICATION; my ($so) = SYNDICATION->new("toynk","","BUY",PRT=>0); 
# use Data::Dumper; print Dumper($so); print Dumper($so->resolve_erefid("58347056"));'
## 
sub resolve_erefid {
	my ($self, $EREFID) = @_;

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my ($USERNAME) = $self->username();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($TB) = &DBINFO::resolve_orders_tb($self->username());
	my $dstinfo = $SYNDICATION::PROVIDERS{$self->dstcode()};
	if (not defined $dstinfo) {
		Carp::confess("Could not resolve ".$self->dstcode()." in SYNDICATION::PROVIDERS");
		}
	if (not defined $dstinfo->{'attrib'}) {
		Carp::confess($self->dstcode()." does not appear to have it's own special attrib");
		}

	my $pstmt = undef;
	foreach my $intref (@ZOOVY::INTEGRATIONS) {
		if ($intref->{'dst'} ne $self->dstcode()) {
			## this is not the dst you are looking for
			}
		elsif ($intref->{'mask'}==0) {
			## sorry, but we don't set the MKT for this marketplace!
			}
		else {
			# $pstmt = "select * from $TB where MID=$MID /* $USERNAME */ and (MKT_BITSTR&$intref->{'mask'})>0 and ORDER_EREFID=".$udbh->quote($EREFID);
			my $SQL = &ZOOVY::bitstr_sql('MKT_BITSTR',[$intref->{'id'}]);
			$pstmt = "select * from $TB where MID=$MID /* $USERNAME */ and $SQL and ORDER_EREFID=".$udbh->quote($EREFID);
			print Dumper($SQL);
			}
		}

	#my $bwinfo = $ZOOVY::MKT_BITVAL{ $dstinfo->{'attrib'} };
	#if (not defined $bwinfo) {
	#	Carp::confess($self->dstcode()." attrib $dstinfo->{'attrib'} does not appear in ZOOVY::MKT_BITVAL");
	#	}
	# my $pstmt = "select * from $TB where MID=$MID /* $USERNAME */ and (MKT&$bwinfo->[0])>0 and ORDER_EREFID=".$udbh->quote($EREFID);

	## 12/8/10 NOTE: the line below would not work because $bwinfo->[0] which is a reference to $ZOOVY::MKT_BITVAL
	##			in array ref position zero would have the masked value (ex: 1<<17) and so we'd be using a mask of 1<<(1<<17) 
	#my $pstmt = "select * from $TB where MID=$MID /* $USERNAME */ and (MKT&(1<<$bwinfo->[0])>0) and ORDER_EREFID=".$udbh->quote($EREFID);
	my $hashref = undef;
	if (defined $pstmt) {
		print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		($hashref) = $sth->fetchrow_hashref();
		$sth->finish();
		}
	&DBINFO::db_user_close();

	# print 'RESULT: '.Dumper($hashref);

	return($hashref);
	}



##
## increments the ERRCOUNT without saving the object.
##
sub inc_err {
	my ($self) = @_;
	my ($dbh) = &DBINFO::db_user_connect($self->username());
	my ($USERNAME) = $self->username();
	my $pstmt = "update SYNDICATION set ERRCOUNT=ERRCOUNT+1 where /* $USERNAME */ ID=".$self->dbid();
	print STDERR $pstmt."\n";
	$dbh->do($pstmt);
	&DBINFO::db_user_close();
	}


##
## To TIE a syndication object you must pass USERNAME=> PROFILE=> and DSTCODE=>
##		or simply pass THIS=>object
##
sub TIEHASH {
	my ($class, %options) = @_;

	if (defined $options{'THIS'}) { return ($options{'THIS'}); }
	if (not defined $options{'USERNAME'}) { return(undef); }
	if (not defined $options{'PROFILE'}) { die(); return(undef); }
	if (not defined $options{'DSTCODE'}) { return(undef); }
	my ($self) = SYNDICATION->new($options{'USERNAME'},$options{'DSTCODE'},%options);
	if (not defined $self->{'_CHANGES'}) { $self->{'_CHANGES'}=0; }
	return($self);
	}

sub FETCH { my ($this,$key) = @_; return($this->get($key)); }
sub STORE { my ($this,$key,$value) = @_; return($this->set($key,$value)); }
sub DELETE { my ($this,$key) = @_; return($this->set($key,undef)); }
# sub FIRSTKEY { my ($this) = @_; }
# sub NEXTKEY { my ($this) = @_; }

sub DESTROY {
	my ($this,$key) = @_;
	if ($this->{'_CHANGES'}==0) {}
	else {
		$this->save();
		undef $this;
		}
	return(undef);
	}



sub pid_attrib {
	my ($self) = @_;

	my ($USERNAME) = $self->username();
	my ($DSTCODE) = $self->dstcode();

	my $p = $SYNDICATION::PROVIDERS{$DSTCODE};
	if (not defined $p) { $p = {}; }
	my $attrib = $p->{'attrib'};
	return($attrib);
	}

##
## returns a hashref of product id's and timestamps which are allowed to syndicate to a marketplace.
##
sub pids_ts {
	my ($self, %options) = @_;

	my ($USERNAME) = $self->username();
	my $attrib = $self->pid_attrib();
	my $result = undef;
	if (defined $attrib) {
		$result = &ZOOVY::syndication_pids_ts($USERNAME,$attrib, %options);
		}

	return($result);
	}



## some constant functions.
sub dbid { return($_[0]->{'ID'}); }
sub username { return($_[0]->{'USERNAME'}); }
sub mid { return(&ZOOVY::resolve_mid($_[0]->username())); }
sub bj { my ($self) = @_; return($self->{'*PARENT'}); }
sub dstcode { return($_[0]->{'DSTCODE'}); }
sub dst { return($_[0]->{'DSTCODE'}); }
sub domain { my ($self) = @_; return($self->{'DOMAIN'}); }
sub prt { 
	my ($self) = @_;

	if (substr($self->domain(),0,1) eq '#') {
		return(int(substr($self->domain(),1)));
		}
	else {
		my ($D) = $self->DOMAIN();
		return($D->prt());
		}

	return($self->{'PRT'}); 
	}
sub guid { return($_[0]->{'PRIVATE_FILE_GUID'}); }
sub userdata { my ($self) = @_; return($self->{'%DATA'}); }
sub msgs { return($_[0]->{'*MSGS'}); }




sub transfer_email {
	my ($self,$URL,$FILESARRAY) = @_;

	my ($lm) = $self->msgs();

	my ($ERROR) = ();
	if ($URL =~ /^email:(.*?)$/) {
		my ($EMAIL) = ($1);
		require MIME::Lite;
		my $subj = "Syndication Feed ".$self->dst();
		my $msg = MIME::Lite->new(
				From => "billing\@zoovy.com",
				To=> $EMAIL,
				Subject=>$subj,
				Type=>"multipart/mixed"
				);

		foreach my $f (@{$FILESARRAY}) {
			if (ref($f) eq '') {
				## scalar
			   ### Add parts (each "attach" has same arguments as "new"):
			   $msg->attach(
					# Type=>'text/csv',
					# Data=>$out,
					Path=>"$f",		# filename in the email
					Filename=>"$f",
					Disposition=>"attachment",
			      );
				}
			elsif (ref($f) eq 'HASH') {
				## hashref w/ in+out keys
				# print STDERR "HASHREF IN+OUT PUT FILE=$f UPFILE=$UPFILE\n";
			   ### Add parts (each "attach" has same arguments as "new"):
			   $msg->attach(
					# Type=>'text/csv',
					# Data=>$out,
					Path=>$f->{'in'},		# filename in the email
					Filename=>$f->{'out'},
					Disposition=>"attachment",
			      );
				}
			else {
				$ERROR = "Unknown data type passed in FILESARRAY got:".ref($f);
				}
			}

   	$msg->send();
		$lm->pooshmsg("SUCCESS|+Emailed to $EMAIL");
		}
	else {
		$ERROR = "Unhandled URL format: $URL";
		}
	return($ERROR)
	}


##
## FILES is an array which can contain either scalars or hashrefs
##	scalar: [$FILENAME]	(the input file -- only compatible with single file transfers)
##	hashref: [{'in'=>$FILENAME,'out'=>$UPLOADFILENAME}]
sub transfer_ftp {
	my ($self,$URL,$FILESARRAY,$tlm) = @_;

	## note: transfer_ftp is called directly by other scripts e.x. newegg/orders.pl
	if (not defined $tlm) { $tlm = LISTING::MSGS->new($self->username()); }

	## FTP TYPE added to indicate ftp SSL as necessary 
	my ($FTP_TYPE,$USER,$PASS,$HOST,$PORT,$UPFILE);
	$tlm->pooshmsg("INFO|+URL:$URL");
	if ($URL =~ /^(sftp|ftp|ftps)\:\/\/(.*?):(.*?)\@(.*?)\/(.*?)$/) {
		($FTP_TYPE,$USER,$PASS,$HOST,$UPFILE) = ($1,$2,$3,$4,$5);
	
		if ($UPFILE =~ /^\//) {
			## this already starts at the root / so that's fine (hmm. url must be ftp://host.com// how bizarre!
			}
		## NOTE: if we want to start relative from the root then we should to a ftp://host.com//path/to/file.csv 
		##			many ftp servers get PISSED if we start at /path/to/file
		##			ex: hsn, pgr -- both want us to PUT path/to/file.csv
		##	SO DO NOT EVER REIMPLMENT THIS CODE BELOW **IT WILL NOT WORK**
		#elsif (index($UPFILE,'/')<0) {
		#	## no directory path, so we shouldn't add a / .. store in local file directory
		#	}
		#else {
		#	## we have a directory path, so we should start at the root, append a / if we don't have one.
		#	$UPFILE = "/$UPFILE";
		#	}

		$UPFILE = URI::Escape::XS::uri_unescape($UPFILE);
		$tlm->pooshmsg("INFO|+UPFILE:$UPFILE");
		}
	elsif ($URL eq '') {
		($USER) = $self->get('.ftp_user');
		($PASS) = $self->get('.ftp_pass');
		($HOST) = $self->get('.ftp_server');		
		}
	else {
		$tlm->pooshmsg("ERROR|+could not determine user credentials for transfer_ftp");
		}

	$USER = URI::Escape::XS::uri_unescape($USER);
	$PASS = URI::Escape::XS::uri_unescape($PASS);
	$HOST = URI::Escape::XS::uri_unescape($HOST);

	$PORT = 21;
	if ($HOST =~ /^(.*?):([\d]+)$/) {
		## found an alternate FTP port number, necessary for:
		## - buy.com which uses an active ftp proxy
		## - hsn which uses SSL ftp, 990
		$PORT = int($2);
		$HOST = $1;
		}
		
	$tlm->pooshmsg("DEBUG|+FTP USER=$USER PASS=$PASS HOST=$HOST UPFILE=$UPFILE");
	my $ftp = ();
	my $rc = '';
	if ($tlm->can_proceed()) {
		## HSN uses SSL ftp
		if ($FTP_TYPE eq 'ftps' ) {
			use Net::FTPSSL;
			$ftp = Net::FTPSSL->new($HOST, Port=>$PORT, useSSL => 1, Debug => 1, Encryption => IMP_CRYPT);
			}
		## normal ftp transfer
		elsif ($FTP_TYPE eq 'sftp') {
			require Net::SFTP;
			$ftp = Net::SFTP->new("$HOST", user=>$USER, password=>$PASS, debug=>1 );
			}
		else {
			require Net::FTP;
			$ftp = Net::FTP->new("$HOST", Port=>$PORT, Debug => 1);
			}
		print STDERR "FTPSERV:[$HOST] FUSER: $USER FPASS: $PASS\n";
		if (not defined $ftp) { $tlm->pooshmsg("ISE|+Unknown FTP server $HOST"); }
		}

	if ($FTP_TYPE eq 'sftp') {
		## sftp does not have a separate login
		}
	elsif ($tlm->can_proceed()) {
		$rc = $ftp->login($USER,$PASS);	
		print STDERR "RC: $rc\n";
		if ($rc!=1) { $tlm->pooshmsg('ERROR|+FTP User/Pass invalid.'); }
		}

	if ($tlm->can_proceed()) {
		## BAD: commission junction does not accept pasv ftp connections.
		# $ftp->pasv();
		
		foreach my $f (@{$FILESARRAY}) {
			if ($FTP_TYPE ne 'sftp') { $ftp->binary(); }

			if (ref($f) eq '') {
				## scalar
				$tlm->pooshmsg("INFO|+SCALAR PUT FILE=$f UPFILE=$UPFILE");
				if ($UPFILE eq '') {
					$tlm->pooshmsg("ISE|+FTP UPFILE filename is blank (this should never happen)");
					}
				elsif ($ftp->put($f,$UPFILE)) {
					$tlm->pooshmsg("INFO-FTP|+FTP PUT $UPFILE");
					}
				else {
					$tlm->pooshmsg("ISE|+FTP PUT FAILED ON FILE=$UPFILE");
					}
				}
			elsif (ref($f) eq 'HASH') {
				## hashref w/ in+out keys
				print STDERR "HASHREF IN+OUT PUT F->in=$f->{'in'} F->out=$f->{'out'}\n";
				if ($ftp->put($f->{'in'},$f->{'out'})) {
					$tlm->pooshmsg("INFO-FTP|+FTP PUT FILE=$f->{'out'}");
					}
				else {
					$tlm->pooshmsg("ISE|+FTP PUT FAILED ON FILE=$f->{'out'}");
					}
				}
			else {
				$tlm->pooshmsg("ISE|+Unknown data type passed in FILESARRAY got:".ref($f));
				}
			}
		}

	if ($tlm->can_proceed()) {
		if ($FTP_TYPE ne 'sftp') { $ftp->quit; }
		$tlm->pooshmsg("SUCCESS|+Transferred files via $FTP_TYPE"); 
		}

	return($tlm);
	}


##
## $NS can be a profile, OR #0 #1, #2 to reference partition.
##		  -- most syndications (in the future) will be *per* partition, not per profile/specialty site.
##
## valid options;
##
sub new {
	my ($class, $USERNAME, $DST, %options) = @_;

	## initialize some sane defaults..
	if (not defined $options{'AUTOCREATE'}) { $options{'AUTOCREATE'}++; }

	my $info = $SYNDICATION::PROVIDERS{$DST};
	my $storetype = $info->{'store'};
	if (($storetype ne 'DOMAIN') && ($storetype ne 'PRT')) {
		warn "SYNDICATION::PROVIDERS store not set for $DST.\n";
		}
	
	if (not defined $USERNAME) {
		warn "requested SYNDICATION object without passing USER[$USERNAME]\n";
		return(undef);
		}
	if (not defined $DST) {
		warn "requested SYNDICATION object without passing DST[$DST]\n";
		return(undef);
		}
	if (not defined $options{'type'}) {
		Carp::cluck("recommends 'type' option parameter\n");
		}

	# if ($NS eq '') { $NS = 'DEFAULT'; }

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select * from SYNDICATION where DSTCODE=".$dbh->quote($DST)." and MID=$MID /* $USERNAME */ ";
	if ($options{'ID'}) {
		$pstmt .= " and ID=".int($options{'ID'});
		}
	elsif ($storetype eq 'PRT') {
		if (not defined $options{'PRT'}) {
			my ($D) = DOMAIN->new($USERNAME,$options{'DOMAIN'});
			$options{'PRT'} = $D->prt();
			warn "SYNDICATION had to resolve PRT($options{'PRT'}) from DOMAIN($options{'DOMAIN'})\n";
			}
		$pstmt .= " and DOMAIN=".$dbh->quote(sprintf("#%d",$options{'PRT'}));
		}
	else {
		$pstmt .= " and DOMAIN=".$dbh->quote(sprintf("%s",$options{'DOMAIN'}));
		}

	# print STDERR "$pstmt\n";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my $self = {};
	if ($sth->rows()>0) {
		($self) = $sth->fetchrow_hashref();
		}
	elsif (not $options{'AUTOCREATE'}) {
		## don't autocreate - 
		$self = undef;
		}
	else {
		$self->{'DSTCODE'} = $DST;
		$self->{'USERNAME'} = $USERNAME;
		
		$self->{'PRT'} = $options{'PRT'};
		$self->{'DOMAIN'} = $options{'DOMAIN'};

		$self->{'MID'} = $MID;
		$self->{'IS_ACTIVE'} = 0;
		$self->{'IS_SUSPENDED'} = 0;
		$self->{'CREATED_GMT'} = time();
		$self->{'LASTSAVE_GMT'} = -1;
		$self->{'ERRCOUNT'} = 0;
		}
	$sth->finish();
	&DBINFO::db_user_close();

	if ($self->{'DOMAIN'} =~ /^#([\d]+)$/) {
		$options{'PRT'} = $self->{'PRT'} = int($1);
		}

	if ($storetype eq 'PRT') {
		$self->{'DOMAIN'} = sprintf('#%d',$options{'PRT'});
		}


	if (defined $options{'*MSGS'}) {
		$self->{'*MSGS'} = $options{'*MSGS'};
		}
	else {
		my %MSGS_OPTIONS = ();
		if ($options{'DEBUG'}) { $MSGS_OPTIONS{'stderr'}++; }
		$self->{'*MSGS'} = LISTING::MSGS->new($USERNAME,%MSGS_OPTIONS);
		}

	if (defined $self) {
		if (defined $options{'*BJ'}) {
			$self->{'*PARENT'} = $options{'*BJ'};
			}

		if (not defined $self->{'_CHANGES'}) { $self->{'_CHANGES'}=0; }
		if (substr($self->{'DATA'},0,3) eq '---') {
			$self->{'%DATA'} = YAML::Syck::Load($self->{'DATA'});
			}
		elsif ($self->{'DATA'} eq '') {
			## not initialized!
			}
		else {
			## legacy format:
			die();
			# $self->{'%DATA'} = &SYNDICATION::decodeini($self->{'DATA'});
			}
		bless $self, 'SYNDICATION';
		}
	## enable is a t/f value that loads from IS_ACTIVE
	$self->{'%DATA'}->{'enable'} = $self->{'IS_ACTIVE'};

	if (defined $options{'type'}) {
		$self->{'TYPE'} = $options{'type'};
		}
	elsif (defined $options{'TYPE'}) {
		$self->{'TYPE'} = $options{'TYPE'};
		}
	else {
		## no type!?!
		}

	## turns on/off debugging
	if (defined $options{'DEBUG'}) { 
		$self->{'DEBUG'} = $options{'DEBUG'}; 
		}

	return($self);
	}





##
## Get an attribute from %DATA
##		attrib sets a value in the object itself e.g. _IS_ACTIVE 
##		.attrib sets a value in the data portion of the object
##
sub get {
	my ($self,$attrib) = @_;

	if (substr($attrib,0,1) ne '.') {
		return($self->{$attrib});
		}
	else {
		$attrib = lc(substr($attrib,1));
		return($self->{'%DATA'}->{$attrib});
		}

	return(undef);	
	}

##
## Sets an attribute in %DATA
##		pass .attrib to set marketplace specific settings.
##
sub set {
	my ($self,$attrib,$val) = @_;

	print STDERR "SYNDICATION SETTING [$attrib]=$val\n";
	if (substr($attrib,0,1) ne '.') {
		print STDERR "$attrib [$self->{$attrib}] ne [$val]\n";

		if ($self->{$attrib} ne $val) {
			$self->{$attrib} = $val;
			$self->{'_CHANGES'}++;
			}
		}
	else {
		$attrib = lc(substr($attrib,1));
		if (defined $val) {
			if ($self->{'%DATA'}->{$attrib} ne $val) {			
				$self->{'%DATA'}->{$attrib} = $val;
				$self->{'_CHANGES'}++;
				}
			}
		else {
			delete $self->{'%DATA'}->{$attrib};
			$self->{'_CHANGES'}++;
			}
		}
	
	}



sub filename {
	my ($self,$type) = @_;
	$type = '' unless $type; ## can add '-inventory' suffix to the filename

	my $url = $self->get('.url');
	my ($datafile) = $url;
	if (index($datafile,'/')>=0) {
		$datafile = substr($datafile,rindex($datafile,'/')+1);
		}
	if ($url eq 'null') {
		$datafile = 'data.txt';
		}
	if ($datafile eq '') {
		$datafile = "data.txt";
		}
	$datafile =~ s/[\/\\]+/_/g;
#	$datafile = sprintf("%s-%s-%s-%s",$self->profile(),$self->dstcode(),$type,$datafile);
	return($datafile);
	}





##
## this should be called by the syndication engine to determine:
##		the root category,
##		the primary domain
##		a reference to the merchant (profile) namespace
##
sub syn_info {
	my ($self) = @_;
	return($self->domain(),$self->rootcat());
	}


##
##
##
sub rootcat {
	my ($self) = @_;
	my ($D) = $self->DOMAIN();
	if (not defined $D) { return('.'); }
	return($D->get('our.rootcat') || '.');
	}

##
##
##
sub DOMAIN {
	my ($self) = @_;	
	if (defined $self->{'*DOMAIN'}) { return($self->{'*DOMAIN'}); }
	return($self->{'*DOMAIN'} = DOMAIN->new($self->username(),$self->{'DOMAIN'}));
	}


##
## deletes a syndication entry
##
sub nuke {
	my ($self, $ID) = @_;

	# print Dumper($self);
	if (not defined $ID) { $ID = $self->{'ID'}; }
	my $dbh = &DBINFO::db_user_connect($self->username());
	my $pstmt = "delete from SYNDICATION where ID=$ID /* $self->{'USERNAME'} */ limit 1";
	print STDERR $pstmt."\n";
	$dbh->do($pstmt);
	&DBINFO::db_user_close();
	return();
	}




##
## scope: 
##		1 limit by dstcode
##		2 limit by profile
## 
## returns an array of hashrefs
##
#sub files {
#	my ($self, $scope) = @_;
#
#	my $dbh = &DBINFO::db_user_connect($self->username());
#	my ($MID) = $self->{'MID'};
#	my @RESULTS = ();
#
#	my $pstmt = "select FILENAME,TITLE,CREATED_GMT from SYNDICATION_FILES where MID=$MID /* $self->{'USERNAME'} */ ";
#	if ($scope & 1) { $pstmt .= " and DSTCODE=".$dbh->quote($self->{'DSTCODE'})." "; }
##	if ($scope & 2) { $pstmt .= " and PROFILE=".$dbh->quote($self->{'PROFILE'})." "; }
#	if ($scope & 2) { $pstmt .= " and DOMAIN=".$dbh->quote($self->{'DOMAIN'})." "; }
#	$pstmt .= " and EXPIRES_GMT<$^T order by ID desc";
#	my $sth = $dbh->prepare($pstmt);
#	$sth->execute();
#	while ( my $hashref = $sth->fetchrow_hashref() ) {
#		push @RESULTS, $hashref;
#		}
#	$sth->finish();
#	&DBINFO::db_user_close();
#	return(\@RESULTS);
#	}


## sub tx
sub appendtxlog {
	my ($self,$group,$msg) = @_;
	
	my ($line) = TXLOG::addline(time(),$group,'+'=>$msg);
	my $USERNAME = $self->username();
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $qtTXLINE = $udbh->quote($line);
	
	my $pstmt = "update SYNDICATION set TXLOG=concat($qtTXLINE,TXLOG) where DSTCODE=".$udbh->quote($self->dstcode())." and MID=$MID /* $USERNAME */ and ID=".int($self->dbid());
	print STDERR "/* addtxlog */ $pstmt\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	return();
	}



##########################################
##
## silent = pass 1 for silent mode 
##
sub save {
	my ($self,$silent) = @_;

	if (not defined $silent) { $silent = 0; }

	my $dbh = &DBINFO::db_user_connect($self->username());

	if ((not defined $self->{'_CHANGES'}) || ( $self->{'_CHANGES'} == 0)) {
		## no reason to save, nothing changed in the object.
		warn "no reason to save, no changes made";
		}
	else {
		if (not $silent) {
			## don't do a silent save
			# $self->addsummary('INFO',NOTE=>sprintf('Updated settings (IS_ACTIVE=%d)',$self->{'IS_ACTIVE'}));
			$self->msgs()->pooshmsg("SETUP|+Settings updated");
			}

		if (not defined $self->{'NEEDS_PRODUCTS'}) { $self->{'NEEDS_PRODUCTS'} = 0; }
		if (not defined $self->{'NEEDS_IMAGES'}) { $self->{'NEEDS_IMAGES'} = 0; }
		if (not defined $self->{'NEEDS_INVENTORY'}) { $self->{'NEEDS_INVENTORY'} = 0; }
		if (not defined $self->{'NEEDS_ORDERS'}) { $self->{'NEEDS_ORDERS'} = 0; }
		if (not defined $self->{'NEEDS_TRACKING'}) { $self->{'NEEDS_TRACKING'} = 0; }

		if (not defined $self->{'PRODUCTS_LASTRUN_GMT'}) { $self->{'PRODUCTS_LASTRUN_GMT'} = 0; }
		if (not defined $self->{'INVENTORY_LASTRUN_GMT'}) { $self->{'INVENTORY_LASTRUN_GMT'} = 0; }
		if (not defined $self->{'ORDERS_LASTRUN_GMT'}) { $self->{'ORDERS_LASTRUN_GMT'} = 0; }
		if (not defined $self->{'TRACKING_LASTRUN_GMT'}) { $self->{'TRACKING_LASTRUN_GMT'} = 0; }

		$self->{'INFORM_ZOOVY_MARKETING'} = int($self->{'INFORM_ZOOVY_MARKETING'});

		my ($pstmt) = &DBINFO::insert($dbh,'SYNDICATION',{
			'MID'=>$self->{'MID'},
			'DSTCODE'=>$self->{'DSTCODE'},
			'USERNAME'=>$self->{'USERNAME'},
		 	'DOMAIN'=>$self->{'DOMAIN'},
#			'PRT'=>$self->{'PRT'},
#			'PROFILE'=>$self->{'PROFILE'},
			'CREATED_GMT'=>$self->{'CREATED_GMT'},
			'LASTSAVE_GMT'=>time(),
			'IS_ACTIVE'=>$self->{'IS_ACTIVE'},
			'IS_SUSPENDED'=>$self->{'IS_SUSPENDED'},
			'ERRCOUNT'=>$self->{'ERRCOUNT'},
			'INFORM_ZOOVY_MARKETING'=>$self->{'INFORM_ZOOVY_MARKETING'},
			'DATA'=>YAML::Syck::Dump($self->{'%DATA'}),
			'PRODUCTS_COUNT'=>int($self->{'PRODUCTS_COUNT'}),
			'PRODUCTS_LASTRUN_GMT'=>$self->{'PRODUCTS_LASTRUN_GMT'},
			'INVENTORY_LASTRUN_GMT'=>$self->{'INVENTORY_LASTRUN_GMT'},
			'ORDERS_LASTRUN_GMT'=>$self->{'ORDERS_LASTRUN_GMT'},
			'TRACKING_LASTRUN_GMT'=>$self->{'TRACKING_LASTRUN_GMT'},
			}, 
			'key'=>['MID','DSTCODE','DOMAIN'],
			'verb'=>($self->dbid()?'update':'insert'),
			'sql'=>1
			);
		print STDERR "$pstmt\n";
		$dbh->do($pstmt);
		$self->{'_CHANGES'}=0;
		}

	&DBINFO::db_user_close();
	return();
	}



##
## returns 'products' or 'inventory' or 'pricing'
##
sub type {	
	my ($self) = @_; 
	$self->{'TYPE'} = lc($self->{'TYPE'});
	if ($self->{'TYPE'} eq 'product') { return('products'); }
	return($self->{'TYPE'}); 
	}

## if we're debugging, this returns the product id (or undef if we're not in debug)
## returns undef for "not debugging"
## returns '' for debug general
## retuns pid for blank
sub is_debug { 
	my ($self,$PID) = @_;
	
	if ($self->{'DEBUG'}) {
		## debug is enabled, not PID specific call, so we return TRUE for everything.
		return(1);
		}
	elsif (not defined $PID) {
		## general debugging level
		## debug not turned on, always off
		return(undef);
		}
	elsif ($self->{'_TRACEPID'} eq '') {
		## we're not tracing a specific pid, so any pid will work!
		return(0);
		}
	elsif ($PID eq $self->{'_TRACEPID'}) {
		## we requested a pid *AND* it matches! yay!
		return( $self->{'_TRACEPID'} );
		}
	elsif (($PID =~ /\:/o) && (substr($PID,0,length($self->{'_TRACEPID'})).":" eq "$self->{'_TRACEPID'}:")) {
		## we requested a pid *AND* it matches! yay!
		return( $self->{'_TRACEPID'} );
		}
	else {
		## we requested debug on a pid that is NOT the PID we're looking for
		return(0);
		}

	return('');
	};


##
## this is a wrapper around runnow
##		.. but enables debugging in children .. also they behave differently.
##
sub runDebug {
	my ($self, %options) = @_;

	$options{'DEBUG'} = 3;	## never sends a file, but runs full diagnostics.
	$options{'TRACEPID'} =~ s/^[\s]+//gs;	# strip leading whitespace.
	$options{'TRACEPID'} =~ s/[\s]+$//gs;	# strip trailing whitespace.
	$self->{'_TRACEPID'} = $options{'TRACEPID'};
	$self->{'DEBUG'} = $options{'DEBUG'};	# turns on debug mode

	if (defined $options{'type'}) {
		## products or inventory
		$self->{'TYPE'} = $options{'type'};
		}

	my ($lm) = $self->msgs();	
	if ($options{'TRACEPID'} ne '') {
		$lm->pooshmsg("INFO|+Starting diagnostics for TracePID[$options{'TRACEPID'}] at ".&ZTOOLKIT::pretty_date(time(),1));
		}
	else {
		$lm->pooshmsg("INFO|+Starting diagnostics for all products at ".&ZTOOLKIT::pretty_date(time(),1));
		}

	$lm->pooshmsg("BEGIN|+User: ".$self->username()." / Domain: ".$self->domain()." / Partition: ".$self->prt());
	$self->runnow(%options);
	$lm->pooshmsg("END|+Finished diagnostics for product $options{'TRACEPID'}");	

	return($lm);	
	}




#############################################################################
##
## Actually builds the file, used by custom feeds, powerreviews, buy.com, buysafe, etc.
##	
##	this is what runnow should have been. :-P
##
##  And I don't like the idea to have single runnow2 for all types of feeds - 
##  products, inventory, ... and all destinations here - too unobvious
## 
## NOTE: $sj is a reference to a syndication job.
##
sub runnow {
	my ($self, %options) = @_;

	my $x = 0;
	
	## always reset message to blank (hopefully it will get set while we run)	
	my $lm = $self->msgs();
	
	my $sj = $options{'sj'};	## reference to a syndication job (for logging/output)
	$self->{'TYPE'} = lc($self->type());
	if (defined $options{'type'}) {
		$self->{'TYPE'} = $options{'type'};
		}
	$self->{'%options'} = \%options;

	if ($self->type() eq '') {
		$self->{'TYPE'} = 'products';
		warn("type not specified .. assuming 'products'");
		}
	elsif ($self->type() !~ /^(products|inventory|pricing|images)$/) {
		$lm->pooshmsg(sprintf("ISE+|SYNDICATION->run found non-supported feed type: %s",$self->type()));
		}

	my $DSTCODE = $self->dstcode();
	my $PRT = $self->prt();
	my ($DOMAIN) = $self->domain();
	my ($ROOTCAT) = $self->rootcat();

	my ($USERNAME) = $self->username();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	##################################################################
	## Step 0: figure out which data mapping we're going to use and load it.		
	##
	my ($MODULE) = $self->get('.map');
	my $attrib = undef;

	#my $syndicationOPTIONs = 0;	##  need set to skip hidden(1), DO NOT skip LISTS (4)
	#										## lists are available on the UI
	#										## 8 = submit parents (even if they don't have inventory)

	my %CONFIG = ();
	## attrib			the attribute to filter on ex: market:ts
	## expandPOGs 		eventually this will be a generic syndication property.
	## 		this tells us to expand inventoriable option groups into their SKU's
	## 		for syndication.
	## 		0 = no
	## 		1 = expand into unique options
	## 		2 = do not expand, but merge inventory
	##		
	%CONFIG = %{$SYNDICATION::PROVIDERS{$DSTCODE}};

	## a hashref keyed by pid or sku, value is an arrayref of hashrefs 
	##		each hashref containing: pid, or sku (or both) + msg + hint (optional), attrib, attrvalue
	##		note if 'PID' is *WARNING then it won't actually block the product, but 'sku' or 'pid' must be passed in reference then.


	if (not $lm->can_proceed()) {
		}
	elsif ($self->type() eq '') {
		$lm->pooshmsg("ISE|+feed type() must be set");
		}
	elsif ( ($CONFIG{'store'} eq 'DOMAIN') && ((not defined $DOMAIN) || ($DOMAIN eq '')) ) {
		$lm->pooshmsg("ERROR|+profile '%s' has no domain associated (a valid domain is required)");
		}
	

	if (not $lm->can_proceed()) {
		}
	elsif ($self->get('.map') ne '') {
		$CONFIG{'module'} = $self->('.map');
		}
	else {
		## MODULE BEHAVIORS: 
		## 	eventually each module will define these behaviors themselves.
		## 	(or will more likely set them based on user preferences)

		if (defined $sj) {
			$lm->set_batchjob($sj->bj());
			$sj->bj()->title("Syndication ".$SYNDICATION::PROVIDERS{$DSTCODE}->{'title'}." for $DOMAIN");
			$lm->pooshmsg(sprintf("INFO|type=%s|+Starting $DOMAIN to $SYNDICATION::PROVIDERS{$DSTCODE}->{'title'}",$self->type()));
			}

		}


	if (defined $self->get('.feed_options')) {
		## some providers, such as google actually let us set feed_options
		$CONFIG{'navcat_hidden'} = ((($self->get('.feed_options')&1)==0)?1:0);
		$CONFIG{'navcat_lists'} = ((($self->get('.feed_options')&4)==0)?1:0);
		## $CONFIG{'syndicationOPTIONs'} = $self->get('.feed_options');
		}

	## check again, since MAP may have been set now.
	if (not $lm->can_proceed()) {
		}
	elsif ($CONFIG{'module'} eq '') {
		$lm->pooshmsg("ISE|+Unknown MAP: $CONFIG{'module'} DST: $DSTCODE");
		}

	## SYNDICATION::REPLACEYOURCELL001
	## SYNDICATION::SLI001
	## SYNDICATION::GEN001
	## SYNDICATION::RAW001
	## STNDICATION::BAMTAR001
	## SYNDICATION::POWERREV
	## SYNDICATION::DOBA
	## SYNDICATION::BUYCOM
	## SYNDICATION::BUYSAFE
	## SYNDICATION::YAHOOSHOP
	my $CLASS = undef;
	my $cl = undef;
	if ($lm->can_proceed()) {
		$CONFIG{'module'} =~ s/[^A-Z0-9]+//g;
		$CLASS = 'SYNDICATION::'.$CONFIG{'module'};

		$cl = Class::Runtime->new( class => $CLASS );
		if ( not $cl->load ) {
			warn "Error in loading class $CLASS\n";
			warn "\n\n", $@, "\n\n";
			$lm->pooshmsg("ISE|+Error loading $CLASS $@");

			# if (defined $sj) { $sj->progress(0,0,"SYNDICATION->load($CLASS) got $ERROR"); }
			}
		}

	my $sm = undef;
	if (not $lm->can_proceed()) {
		## shit happened.
		}
	elsif (($cl->isLoaded) && ($CLASS->can('new'))) {
		## basically this is calling SYNDICATION::DOBA->new() for example
   	$sm = $CLASS->new($self);
		if (ref($sm) ne $CLASS) { $lm->pooshmsg("ISE|+Class $CLASS did not instantiate properly"); }
		if ((not defined $sm) || (ref($sm) ne $CLASS)) {
			$lm->pooshmsg("ISE|+ERROR UNKNOWN MAP[$CONFIG{'module'}]");
			}
		}
	else {
		$lm->pooshmsg("ISE|+Cannot call method 'new' on module $CLASS");
		}


	if (not $lm->can_proceed()) {
		## shit already happened.
		}
	elsif (UNIVERSAL::can($sm, 'preflight')) {
		$sm->preflight($lm);
		}
	
	## we use a next here for now .. not good.
	if (not $lm->can_proceed()) {
		}
	elsif (not defined $sm) {
		## just a failsafe 
		$lm->pooshmsg("ISE|+syndication module CLASS=$CLASS not defined");
		}

	my $TRACEPID = undef;
	if (($lm->can_proceed()) && ($options{'TRACEPID'})) {
		## $TRACEPID is the PID of an item which we're testing (as part of a debug) to figure out what's going wrong.
		$TRACEPID = uc($options{'TRACEPID'});
		$lm->pooshmsg("WARN|debugpid=$TRACEPID|+Tracing $TRACEPID - we're going to focus on that product. 
That means several of the counts such as \"before validation\", \"after validation\" will reflect only 
the trace product(s).  But it's all good, so you got nothing to worry about.");
		}

	########################################################################
	## step 1: create a list of products, and navcats	
	##

	my $duplicates = int($self->get('.duplicates'));			
	# my ($ebaycatref,$storecatref,$ncpretty,$ncprodref) = ();
	my ($maxcount) = $self->get('.maxlistings');
	
	my $SKU_TOTAL = 0;
	my $SKU_VALIDATED = 0;
	my $SKU_TRANSMITTED = 0;

	my $source = $self->get('.source');
	if ($source eq '') { $source = $SYNDICATION::PROVIDERS{$DSTCODE}->{'source'}; }
	if ($source eq '') { $source = 'PRODUCTS-MAPPED'; }

	$source = $SYNDICATION::PROVIDERS{$DSTCODE}->{'source'};
	if (defined $sj) { 
		$sj->progress(0,0,"Loading from product source:$source"); 
		$lm->pooshmsg("INFO|+Product source $source");
		}

	if ($TRACEPID ne '') {
		$lm->pooshmsg("INFO|+Product source $source");
		}

	## NOTE: we need to load $NC now becasue we use it later for paths_by_product
	my %BLOCKED_PRODUCTS = ();
	my ($NC) = NAVCAT->new($USERNAME,root=>$ROOTCAT,PRT=>$PRT);
	$self->{'*NC'} = $NC;
	my %LAUNCH_PIDS = ();

	if ($self->type() eq 'inventory') {
		$lm->pooshmsg("INFO|+inventory feed uses source:PRODUCTS-MAPPED");
		$source = 'PRODUCTS-MAPPED';
		}
	elsif ($self->type() eq 'pricing') {
		$lm->pooshmsg("INFO|+pricing feed uses source:PRODUCTS-MAPPED");
		$source = 'PRODUCTS-MAPPED';
		}

	if ( not $lm->can_proceed()) {
		## shit happened.
		}
	elsif ($source eq 'PRODUCTS-MAPPED') {
		if ($self->is_debug()) {
			my ($prod_count) = &ZOOVY::products_count($USERNAME);
			$lm->pooshmsg("INFO|+Found $prod_count product records account wide.");
			}
		my $enabled = &ZOOVY::syndication_pids_ts($USERNAME,$CONFIG{'attrib'},%options);
		if ($self->is_debug()) {
			$lm->pooshmsg("INFO|+You have ".(scalar keys %{$enabled})." products (account wide) allowed based on $CONFIG{'attrib'} setting.");
			if ($TRACEPID eq '') {
				## overall debug mode.
				}
			elsif (not defined $enabled->{$TRACEPID}) {
				$lm->pooshmsg("PAUSE|+Could not locate PID:$TRACEPID -- was not allowed by $CONFIG{'attrib'} field.");
				}
			else {
				$lm->pooshmsg("INFO|+$TRACEPID -- was allowed by $CONFIG{'attrib'} field.");
				$enabled = { $TRACEPID => 1 };
				}
			}

		## historically this was only enabled if there was a navcatMETA
		# my $navcat_mapref = $NC->syndication_map();
		my %NCMAP = ();
		foreach my $safe ($NC->paths()) {
			my ($pretty,$children,$products) = $NC->get($safe);
			my $bc = &NAVCAT::FEED::path_breadcrumb($NC,$safe);
			foreach my $pid (split(/,/,$products)) {
				next if ($pid eq '');
				if (not defined $NCMAP{$pid}) {
					$NCMAP{$pid} = { 'navcat:safe'=>$safe,  'navcat:bc'=>$bc };
					}
				elsif ( length($NCMAP{$pid}->{'navcat:safe'}) < length($safe) ) {
					$NCMAP{$pid} = { 'navcat:safe'=>$safe,  'navcat:bc'=>$bc };
					}
				}
			}
		
		foreach my $pid (keys %{$enabled}) {
			if (defined $NCMAP{$pid}) {
				$LAUNCH_PIDS{$pid} = $NCMAP{$pid};
				}
			else {
				$LAUNCH_PIDS{$pid} = {};
				}

			if (($TRACEPID eq '') || (not $self->is_debug($pid))) {
				}
			elsif ($LAUNCH_PIDS{$pid}->{'navcat:safe'} eq '') {
				$lm->pooshmsg(sprintf("HINT|+PID: $pid - is not in a category (no properties will be inherited)",$LAUNCH_PIDS{$pid}->{'navcat:safe'}));
				}
		else {
				$lm->pooshmsg(sprintf("HINT|+PID: $pid - Category %s was selected to inherit properties from.",$LAUNCH_PIDS{$pid}->{'navcat:safe'}));
				}
			}
		}
	elsif ($source eq 'PRODUCTS-ALL') {
		## ALL PRODUCTS
		my ($tsref) = &PRODUCT::build_prodinfo_ts($USERNAME);
		$SKU_TOTAL = scalar(scalar keys %{$tsref});
		$lm->pooshmsg("INFO|+Found $SKU_TOTAL unique products (source: PRODUCTS-ALL)");
		foreach my $pid (keys %{$tsref}) {
			next if ($pid eq '');
			$LAUNCH_PIDS{$pid} = {};
			}
		if (defined $TRACEPID) {
			if (not defined $LAUNCH_PIDS{ $TRACEPID }) {
				$lm->pooshmsg("PAUSE|+Could not find product $TRACEPID in source=PRODUCTS-ALL");
				}
			}
		}
	elsif ($source eq 'WEBSITE-ALL') {
		## load from website, with matching META

		if (not defined $ROOTCAT) { $ROOTCAT = '.'; }
		#my %ncpretty = ();			# key=safe, val=breadcrumb of pretty
		#my %ncprodref = ();			# key=product id, val=which safe name it belongs to

		my @paths = sort $NC->paths($ROOTCAT);
		if (scalar(@paths)==0) {
			$lm->pooshmsg("STOP|+There appear to be no categories for root=$ROOTCAT");
			}
		elsif ($self->is_debug()) {
			$lm->pooshmsg("INFO|+Found ".(scalar @paths)." total categories on this partition");
			if ($TRACEPID eq '') {
				my %PIDS = ();
				foreach my $safe (@paths) {
					my ($pretty,$children,$products) = $NC->get($safe);
					foreach my $pid (split(/,/,uc($products))) { $PIDS{$pid}++; }
					}
				$lm->pooshmsg("INFO|+Found ".(scalar keys %PIDS)." total products mapped to categories on this partition");
				}

			$lm->pooshmsg("INFO|+Option .. Shall we Include hidden categories? -- ".(($CONFIG{'navcat_hidden'})?'Yes':'No'));
			$lm->pooshmsg("INFO|+Option .. Shall we Include Lists? -- ".(($CONFIG{'navcat_lists'})?'Yes':'No'));				
			$lm->pooshmsg("INFO|+Option .. Shall we send parents without Inventory? -- ".(($CONFIG{'send_parents'})?'Yes':'No'));				
			$lm->pooshmsg("INFO|+Option .. Shall we Skip Pages? -- Yes");
			if (scalar(@paths)==0) {
				$lm->pooshmsg("WARN|+Found no categories, something went horribly wrong.");
				}
			elsif (defined $TRACEPID) {
				@paths = sort @{$NC->paths_by_product($TRACEPID)};
				$lm->pooshmsg("INFO|+Product \"$TRACEPID\" is in ".(scalar @paths)." website categories on this partition");
				if (scalar(@paths)==0) {
					$lm->pooshmsg("WARN|+Product $TRACEPID is not in any website categories, this will probably be a bumpy ride.");
					}
				}
			}

	   foreach my $safe (@paths) {
			my ($pretty, $child, $products, $sortstyle,$metaref) = $NC->get($safe);

			my $skip = 0;
			if (substr($pretty,0,1) eq '!') {
				# skip hidden categories.
				$skip = 1;
				if ((defined $CONFIG{'navcat_hidden'}) && ($CONFIG{'navcat_hidden'})) { $skip = 0; }
				}
			elsif (substr($safe,0,1) eq '$') {
				# skip lists.
				$skip =2;
				if ((defined $CONFIG{'navcat_lists'}) && ($CONFIG{'navcat_lists'})) { $skip = 0; }
				}
			elsif (substr($safe,0,1) eq '*') {
				## skip pages.
				$skip =3;
				}

			next if  ($skip);

			my $bc = &NAVCAT::FEED::path_breadcrumb($NC,$safe);
			foreach my $prod (split(/,/,$products)) {
				next if ($prod eq '');
				my $copy = 0;
				if (not defined $LAUNCH_PIDS{$prod}) { 
					$LAUNCH_PIDS{$prod} = {}; 
					}

            if ($self->type() eq 'inventory') {
               ## inventory doesn't require a full data feed.
               }
            elsif ($self->type() eq 'pricing') {
               ## pricing doesn't require a full data feed.
               }
            elsif (($CONFIG{'module'} eq 'POWERREV') || ($CONFIG{'module'} eq 'BUYSAFE') ||
              	($CONFIG{'module'} eq 'NEXTAG')) {
					## NOTE: we can't do this in the module since it's inherited by children
               my ($safe) = @{$NC->paths_by_product($prod)};
               $LAUNCH_PIDS{$prod}->{'navcat:prod_category'} = $NC->pretty_path($safe,delimiter=>' > ');
               }

				if (length($LAUNCH_PIDS{$prod}->{'navcat:safe'}) < length($safe)) {
					## legnth of existign is less than current
					$LAUNCH_PIDS{$prod}->{'navcat:safe'} = $safe;
					$LAUNCH_PIDS{$prod}->{'navcat:bc'} = $bc;
					}
				}
			}
					
		## Not sure how clients do this.
		if (defined $LAUNCH_PIDS{""}) {
			$lm->pooshmsgs("WARN|+Found null product of '' in LAUNCH_PIDS - removing");
			delete $LAUNCH_PIDS{""};
			}
		##
		## SANITY: at this point LAUNCH_PIDS is *as big* as it's gonna get.
		##				as we go, we'll deflate it a bit by deleting items we shouldn't launch. 
		##


		if (defined $TRACEPID) {
			if (not defined $LAUNCH_PIDS{ $TRACEPID }) {
				## product $TRACEPID wouldn't be launched.
				my @paths = @{$NC->paths_by_product($TRACEPID)};
				if (scalar(@paths)==0) {
					$lm->pooshmsg("PAUSE|+Could not locate $TRACEPID in any website categories.");
					}
				else {
					$lm->pooshmsg("PAUSE|+Could not locate $TRACEPID in qualified navcats .. found in: ".join("\n",@paths));
					}			
				}
			}
		elsif ($self->is_debug()) {
			$lm->pooshmsg("INFO|+After processing website categories we have: ".scalar(keys %LAUNCH_PIDS)." products.");
			}
	
		if (scalar(keys %LAUNCH_PIDS)==0) {
			# $ERROR = "There are no products mapped for syndication";
			if ($source eq 'WEBSITE-ALL') {
				}
			else {
				$lm->pooshmsg("STOP|No products (source:$source)");
				}
			}

		}
	else {
		$lm->pooshmsg("FATAL|+UNKNOWN product source \"$source\"");
		}


	$SKU_TOTAL = scalar(keys %LAUNCH_PIDS);
	# print Dumper(\%LAUNCH_PIDS);

	##
	## check blocked products
	##
	if ( ($lm->can_proceed()) && scalar(keys %BLOCKED_PRODUCTS)) {
		if (defined $BLOCKED_PRODUCTS{$TRACEPID}) {
			$lm->pooshmsg("WARN|+Trace product $TRACEPID blocked: $BLOCKED_PRODUCTS{$TRACEPID}");
			}
		$lm->pooshmsg(sprintf("INFO|+There are %d products residing in blocked categories.",scalar(keys %BLOCKED_PRODUCTS)));
		my $i = 0;
		foreach my $pid (keys %BLOCKED_PRODUCTS) {
			if (defined $LAUNCH_PIDS{$pid}) {
				delete $LAUNCH_PIDS{$pid};
				$i++;
				}
			}
		## regardless if this is zero or more, we should show it:
		$lm->pooshmsg(sprintf("INFO|+Removed %d products due to blocked categories.",$i));
		}

	##
	##  check inventory
	##
	if ($self->type() eq 'inventory') {
		$lm->pooshmsg("INFO|+skip inventory check for type:inventory (because we'll want to send any zeros)");
		}
	elsif ($self->type() eq 'pricing') {
		$lm->pooshmsg("INFO|+skip inventory check for type:pricing (because we'll want to send any zeros)");
		}
	elsif ( ($lm->can_proceed()) && (($CONFIG{'syndicationOPTIONs'} & 2)==2) ) {
		my %IGNORE_INVENTORY = ();
		if (($CONFIG{'syndicationOPTIONs'} & 8)==8) {
			my $result = &ZOOVY::syndication_pids_ts($USERNAME,undef,'parent'=>1);
			foreach my $pid (keys %{$result}) {
				$IGNORE_INVENTORY{$pid}++;
				}
			if ($self->is_debug()) {
				$lm->pooshmsg("INFO|+Found ".(scalar(keys %IGNORE_INVENTORY))." parent products where we will ignore inventory");
				if ($TRACEPID) {
					if ($IGNORE_INVENTORY{$TRACEPID}) {
						$lm->pooshmsg("WARN|+Trace product $TRACEPID IS one of the ignored products.");
						}
					else {
						$lm->pooshmsg("INFO|+Trace product $TRACEPID was NOT found in the list of ignored products (so it better have inventory).");
						}
					}
				}
			}


		my @PIDS = keys %LAUNCH_PIDS;
		if ((defined $TRACEPID) && ($TRACEPID ne '')) {
			if (not defined $LAUNCH_PIDS{ $TRACEPID }) {
				## product $TRACEPID wouldn't be launched.
				$lm->pooshmsg("PAUSE|+Could not locate $TRACEPID in LAUNCH_PIDS.");
				}
			}

		## my ($skuinvref) = &INVENTORY::fetch_incrementals($USERNAME,\@PIDS,undef,1+8);
		my ($PIDINVSUMMARY) = INVENTORY2->new( $USERNAME )->summary( '@PIDS'=>\@PIDS, PIDS_ONLY=>1 );
		$lm->pooshmsg("INFO|+Inventory returned ".(scalar(keys %{$PIDINVSUMMARY}))." records, based on ".(scalar(@PIDS))." product records");

		foreach my $pid (@PIDS) {
			if ($IGNORE_INVENTORY{$pid}) {
				}
			elsif ($PIDINVSUMMARY->{$pid}->{'AVAILABLE'} <= 0) {
				if ($TRACEPID eq $pid) {  $lm->pooshmsg(sprintf("WARN|+No inventory for $pid (quantity: %d)",$PIDINVSUMMARY->{$pid}->{'AVAILABLE'})); }
				delete $LAUNCH_PIDS{$pid};
				}
			}

		if ((defined $TRACEPID) && ($TRACEPID ne '')) {
			if (not defined $PIDINVSUMMARY->{ $TRACEPID }) {
				## product $TRACEPID wouldn't be launched.
				$lm->pooshmsg("PAUSE|+Could not locate inventory for $TRACEPID in inventory summary.");
				}
			}
		$lm->pooshmsg("INFO|+After processing inventory we have: ".scalar(keys %LAUNCH_PIDS)." products.");
		}


	########################################################################
	## step 1b: go through and figure out which products are actually allowed to syndicate
	##
	if (not $lm->can_proceed()) {
		}
	elsif ($source eq 'PRODUCTS-MAPPED') {
		## we can skip this step since we already are working with a list of enabled products.
		}
	elsif ((defined $CONFIG{'attrib'}) && ($CONFIG{'attrib'} ne '')) {
		$lm->pooshmsg("INFO|+Products before to $CONFIG{'attrib'} verification: ".scalar(keys %LAUNCH_PIDS));

		if (defined $sj) { 
			$sj->progress(0,0,"Finding products with $CONFIG{'attrib'} allowed"); 
			}
		my $enabled = &ZOOVY::syndication_pids_ts($USERNAME,$CONFIG{'attrib'},%options);		
		if ($TRACEPID) {
			$lm->pooshmsg("INFO|+You have ".(scalar keys %{$enabled})." products (account wide) allowed based on $CONFIG{'attrib'} setting.");
			if (not defined $enabled->{$TRACEPID}) {
				$lm->pooshmsg("PAUSE|+Could not locate $TRACEPID -- was blocked by $CONFIG{'attrib'} field.");
				}
			else {
				$lm->pooshmsg("INFO|+$TRACEPID -- was allowed by $CONFIG{'attrib'} field.");
				$enabled = { $TRACEPID => 1 };
				}
			}

		## go through and delete $LAUNCH_PIDS which aren't allowed to launch.
		foreach my $pid (keys %LAUNCH_PIDS) {
			if (not defined $enabled->{$pid}) {
				delete $LAUNCH_PIDS{$pid};
				}
			}

		$lm->pooshmsg("INFO|+After processing ($CONFIG{'attrib'}) allowed products we have: ".scalar(keys %LAUNCH_PIDS)." products. (TRACE:$TRACEPID)");
		if ((defined $TRACEPID) && ($TRACEPID ne '')) {
			if ($LAUNCH_PIDS{$TRACEPID}) {
				$lm->pooshmsg("INFO|+TracePID[$TRACEPID] is still eligible for syndication.");
				}
			else {
				$lm->pooshmsg("PAUSE|+Since processing ($CONFIG{'attrib'}) the TracePID[$TRACEPID] is no longer eligible.");
				}
			}
		}
	elsif (not defined $CONFIG{'attrib'}) {
		$lm->pooshmsg("DEBUG|+No attrib:ts (filter) set for this destination, which is a little strange. (you won't be able to fix this).");
		}



	$SKU_VALIDATED = scalar(keys %LAUNCH_PIDS);
	if (($lm->can_proceed()) && (scalar (keys %LAUNCH_PIDS)==0)) {
		$lm->pooshmsg("STOP|+No eligible products after phase 1 validation.");
		}


	if ($CONFIG{'suspend_products'}) {
		## suspended products are any product which has a non-archived log entry for this dst code in SYNDICATION_PID_ERRORS
		my @LAUNCHABLE_PIDS = keys %LAUNCH_PIDS;
		$lm->pooshmsg("INFO|+Before suspended_products check we have: ".scalar(@LAUNCHABLE_PIDS)." products.");
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $qtDST = $udbh->quote($self->dstcode());
		foreach my $blockref (@{&ZTOOLKIT::batchify(\@LAUNCHABLE_PIDS,100)}) {
			my $pstmt = "select ID,PID from SYNDICATION_PID_ERRORS where MID=$MID /* $USERNAME */ and DSTCODE=$qtDST and ARCHIVE_GMT=0 and PID in ".&DBINFO::makeset($udbh,$blockref);
			print STDERR $pstmt."\n";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my ($ID,$PID) = $sth->fetchrow() ) {
				## if we have an entry in SYNDICATION_PID_ERRORS that is the only thing we need to suspend the product
				if ($self->is_debug($PID)) {
					my $pstmt = "select OCCURRED_TS,SKU,FEED,ERRCODE,ERRMSG,BATCHID from SYNDICATION_PID_ERRORS where ID=$ID";
					my ($OCCURRED_TS,$SKU,$FEED,$ERRCODE,$ERRMSG,$BATCHID) = $udbh->selectrow_array($pstmt);
					$lm->pooshmsg("DEBUG|+SKU:$SKU was suspended on $OCCURRED_TS errcode:$ERRCODE errmsg:$ERRMSG refid:$BATCHID");
					}
				delete $LAUNCH_PIDS{$PID};
				}
			$sth->finish();			
			}
		&DBINFO::db_user_close();
		$lm->pooshmsg("INFO|+After suspended_products check we have: ".scalar(keys %LAUNCH_PIDS)." products.");		
		}


	#if (UNIVERSAL::can($sm,'filterLaunch')) {
	#	$lm->pooshmsg("INFO|+Before processing filterLaunch we have: ".scalar(keys %LAUNCH_PIDS)." products.");
	#	$sm->filterLaunch(\%LAUNCH_PIDS);
	#	$lm->pooshmsg("INFO|+After processing filterLaunch we have: ".scalar(keys %LAUNCH_PIDS)." products.");
	#	if (scalar(keys %LAUNCH_PIDS)==0) {
	#		$lm->pooshmsg("PAUSE|+Seems no products require syndication at the moment");
	#		}
	#	}


 	## step 1c: debugging, just does one product
 	##
 	# $ncprodref = { 'MHP0005' => '' };

	########################################################################
	## step 2: segment these into batches of 25 products for easy processing
	my @batches = ();
	my @new = ();
	my $thisref = \@new;
	my %done = ();
	if ($lm->can_proceed()) {
		if (defined $sj) { 
			$sj->progress(0,0,"Creating product batches"); 
			}
		foreach my $prod (sort keys %LAUNCH_PIDS) {		
			next if (defined $done{$prod});
			push @{$thisref}, $prod;
			if (scalar(@{$thisref})==50) { 
				my @new = ();
				push @batches, $thisref;
				$thisref = \@new;
				}
			$done{$prod}++;
			}
		if (scalar(@{$thisref})>0) { push @batches, $thisref; }
		}


	## run through a validation just to see what would happen.
	$lm->pooshmsg("DEBUG|+Seems we have ".scalar(keys %LAUNCH_PIDS)." products before validation.");

	## quick sanity check:
	if ($lm->can_proceed()) {
		if (scalar(@batches)==0) {
			$lm->pooshmsg("STOP|+No syndication eligible products found");
			}
		}

	if ($CONFIG{'headerOnly'}) {
		$lm->pooshmsg("DEBUG|+headerOnly option turned on (we don't actually send products)");
		@batches = ();
		}

	if ($self->get('.schedule') ne '') {
		$lm->pooshmsg(sprintf("INFO|+using pricing schedule %s",$self->get('.schedule')));
		}

	########################################################################
	## step 3: parse through the products

	my $FILENAME = undef;
	if ($self->type() eq 'products') {
		$FILENAME = "/local/tmp/$USERNAME-$DOMAIN-$DSTCODE.out";
		}
	elsif ($self->type() eq 'inventory') { 
		$FILENAME = "/local/tmp/$USERNAME-$DOMAIN-$DSTCODE-INVENTORY.out"
		}
	elsif ($self->type() eq 'pricing') { 
		$FILENAME = "/local/tmp/$USERNAME-$DOMAIN-$DSTCODE-PRICING.out"
		}
	else {
		die("DIE DUE TO INVALID TYPE:".$self->type());
		$lm->pooshmsg(sprintf("ISE|+UNKNOWN OUTPUT FILE TYPE: %s",$self->type()));
		}

	## reference to _FILENAME is used by both DOBA/BUYCOM which have their own transfer methods -- DO NOT CHANGE
	if (defined $FILENAME) {
		$self->{'_FILENAME'} = $FILENAME;
		}


	my %PROCESSED_SKUS = ();
	if ($lm->can_proceed()) {
		open Fzz, ">$FILENAME";
		if (defined $sj) { 
			$sj->progress(0,0,"Creating file header"); 
			}
		my $reccount = 0;
		my $rectotal = scalar(@batches);

		if ($self->type() eq 'products') {
			print Fzz $sm->header_products();
			}
		elsif ($self->type() eq 'inventory') {
			print Fzz $sm->header_inventory();
			}
		elsif ($self->type() eq 'pricing') {
			print Fzz $sm->header_pricing();
			}
		else {
			$lm->pooshmsg(sprintf("ISE|+HEADER UNKNOWN FILE TYPE: %s",$self->type()));
			}

		my $expandPOGs = $CONFIG{'expandPOGs'};
		if (($self->type() eq 'inventory') && (defined $CONFIG{'inv.expandPOGs'})) {
			## inventory feed (ex: ebay) requires a different expandPOGs behavior than the product record.
			$lm->pooshmsg("INFO|+Feed type inventory has special expandPOGS behavior:$CONFIG{'inv.expandPOGs'}");
			$expandPOGs = $CONFIG{'inv.expandPOGs'};
			}

		my $udbh = &DBINFO::db_user_connect($USERNAME);
		foreach my $batchref (@batches) {
			## get product data
			$reccount++;
			if (defined $sj) { 
				$sj->progress($reccount,$rectotal,"Loading Products/Inventory Batch"); 
				}

			## PROCESSING is a hashref keyed by $SKU it MAY be modified during the run (ex: expandOptions etc.)
			##		the value is [ $SKU[0], $P[1], $plm[2], { ..metadata[3].. instock=>#, reserve=>#, } ]
			my %PROCESSING = ();
			if (1) {
				my ($Prodsref) = &PRODUCT::group_into_hashref($USERNAME,$batchref);
				foreach my $P (values %{$Prodsref}) {
					my %OVERRIDES = %{$LAUNCH_PIDS{$P->pid()}};
					my $plm = LISTING::MSGS->new($USERNAME,'stderr'=>($options{'trace'})?1:0,'pid'=>$P->pid());
					$PROCESSING{ $P->pid() } = [ 
						$P->pid(),
						$P, 
						$plm,  
						\%OVERRIDES,
						];
					}
				}
			## SANITY: okay lets start PROCESSING


		 	########################################################################
			## NOTE: at some point we could bypass inventory checks for anything which *DIDNT*
			##			have inventory, or had inventory unlimited
 			##
 			## PHASE1: preprocess, handle product options
 			##

			my $ALLOWEDATTRIB = $SYNDICATION::PROVIDERS{$DSTCODE}->{'attrib'};

 			foreach my $set (values %PROCESSING) {
				my ($PID,$P,$plm,$OVERRIDES) = @{$set};
				if ($PID eq '') { 
					$plm->pooshmsg("ISE|PID:$PID|+Blank PID?");
					}

				## check and make sure product is allowed 
				if (not $plm->can_proceed()) {
					}
				elsif (not defined $ALLOWEDATTRIB) {
					}
				elsif (not defined $P->fetch($ALLOWEDATTRIB)) {
					}
				elsif ($P->fetch($ALLOWEDATTRIB) <= 0) {
					## it's defined, and forbidden
					$plm->pooshmsg(sprintf("STOP|PID:$PID|+explicitly blocked because %s=%s",$ALLOWEDATTRIB,$P->fetch($ALLOWEDATTRIB)));
					}

				if (not $plm->can_proceed()) {
					}
				elsif (($self->type() eq 'inventory') && (UNIVERSAL::can($sm, 'inventory_validate'))) {
					## inventory has it's own validation. (not fully implemented)
					}
				elsif ($self->type() eq 'inventory') {
					## no validation on inventory
					}
				elsif ($self->type() eq 'pricing') {
					## no validation on pricing
					}
				elsif (UNIVERSAL::can($sm, 'validate')) {
					## if the syndication module can validate() the product, then let it.

					my ($err) = $sm->validate($PID,$P,$plm,$OVERRIDES);
					if ((defined $err) && ($err ne '')) {
						if ($err =~ /^(STOP|VALIDATION|WARN)\|/) {
							$plm->pooshmsg($err);
							}
						else {
							$plm->pooshmsg("STOP|PID:$PID|src=VALIDATION|+$err");
							}
						}
					elsif ($self->is_debug($P->pid())) {
						$plm->pooshmsg("INFO|PID:$PID|+passed validation with no errors");
						}
					}

				if (not $plm->can_proceed()) {
					}
#				elsif ($so->dstcode() eq 'EBF') {
#					## we shouldn't send children for ebay (ebay's whole grouping/variation construct is wonky)
#					}
				elsif ($P->grp_type() eq 'PARENT') {
					## add group children (this has been put 'here' so grp children options can be expanded in expandPOGs)
					## group parents, only syndicate the children
					my @childpids = $P->grp_children();

					my ($Childrenref) = &PRODUCT::group_into_hashref($USERNAME,\@childpids);
					if ($self->is_debug()) {
						$plm->pooshmsg("DEBUG|PID:$PID|+Group Children".Dumper(\@childpids));
						}

					foreach my $childpid (@childpids) {
						## loop thru children
						next if ($PROCESSING{$childpid});		## childsku already exists.

						$plm->pooshmsg(sprintf("INFO|PID:$PID|+%s admitted to feed (CHILD of %s)",$childpid,$P->pid()));
						my $cplm = LISTING::MSGS->new($USERNAME,'stderr'=>($options{'trace'})?1:0,'pid'=>$P->pid());

						my %CHILDOVERRIDES = %{$OVERRIDES};		## always start with the parents overrides for the child

						$CHILDOVERRIDES{ 'parent:keywords' } = $P->fetch('zoovy:keywords');
						if ($CONFIG{'module'} eq 'CJ') {
							$CHILDOVERRIDES{'cj:category'} = $P->fetch('cj:category');
							}

						if (not defined $Childrenref->{$childpid}) {
							$plm->pooshmsg(sprintf("ERROR|PID:$PID|+SKU %s references invalid child SKU %s",$P->pid(),$childpid));
							}
						else {
							$PROCESSING{ $childpid } = [ $childpid, $Childrenref->{$childpid}, $cplm, \%CHILDOVERRIDES ];
							}
						}

					$plm->pooshmsg(sprintf("INFO|PID:$PID|+%s dropped from feed (reason: PARENT)",$P->pid()));
					delete $PROCESSING{ $P->pid() };	# remove the parent, we are sending the children instead
					}					
				}


			##
			## INVENTORY
			## 
			my %TMP_SKUSREF = ();
			foreach my $set (values %PROCESSING) {
				my ($SKU,$P) = @{$set};
				$TMP_SKUSREF{ $P->pid() } = $P;
				}

			my ($invref, $reserveref) = INVENTORY2->new($USERNAME)->fetch_qty('@SKUS'=>$batchref,'%PIDS'=>\%TMP_SKUSREF);
			
			foreach my $set (values %PROCESSING) {
				my ($PID,$P,$plm,$OVERRIDES) = @{$set};

				next if (not $plm->can_proceed());
	
				if ($TRACEPID ne $PID) {
					## no need to log to syndication what the inventory was.
					}	
				elsif ($P->has_variations('inv')) {
					$plm->pooshmsg("INFO|+This product has inventory options, so we'll check inventory later.");
					}
				elsif (not defined $invref->{$PID}) { 
					$plm->pooshmsg("WARN|PID:$PID|+has no inventory record returned (will be out of stock)");
					# $plm->pooshmsg("DEBUG|+".Dumper($invref));
					}
				else {
					$plm->pooshmsg("INFO|PID:$PID|+has $invref->{$PID} in stock.");
					}


 				##
 				## NOTE: eventually this option handling code could be a bit more generic/applicapble to 
 				##			more than just googlebase.				
				my $HAS_INV_POGS = 0;
				if (not $plm->can_proceed()) {
					if ($self->is_debug($PID)) {
						$lm->pooshmsg("INFO|PID:$PID|+skipped pog expansion due to validation issues.");
						}
					}
				elsif (not $P->has_variations('inv')) {
					if ($self->is_debug($PID)) {
						$lm->pooshmsg("INFO|PID:$PID|+does not appear to have inventoriable options");
						}
					$OVERRIDES->{'zoovy:qty_instock'} = $invref->{$PID};

					## wholesale schedules are only applied to items without inv variations.
					if ($self->get('.schedule') ne '') {
						my $result = $P->wholesale_tweak_product( $self->get('.schedule') );
						## for now, copy the wholesale schedule pricing into OVERRIDES
						foreach my $k (keys %{$result}) {
							$OVERRIDES->{$k} = $result->{$k};
							if ($self->is_debug($PID)) {
								$lm->pooshmsg(sprintf("INFO|PID:$PID|+schedule %s set %s=%s",$self->get('.schedule'),$k,$result->{$k}));
								}
							}
						}
					}
				elsif ($expandPOGs==3) {
					## ebay and others (which do their own pog magic) -- so don't do anything here.
					if ($self->is_debug($PID)) {
						$lm->pooshmsg("HINT|+This syndication module has it's own specialized option handling.");
						}
					}
				elsif ($expandPOGs==2) {
					## expandPOGS == 2
					## this will set the quantity for a single item to the combined total of all options.
					## eventually this should probably be a feed in the syndication options itself.
					my $INSTOCK_QTY = 0;
					my $RESERVE_QTY = 0;
					my @skus = ();
					foreach my $set (@{$P->list_skus('verify'=>1)}) {
						my ($sku,$skuref) = @{$set};
						push @skus, $sku;
						$INSTOCK_QTY += $invref->{$sku};
						$RESERVE_QTY += $reserveref->{$sku};
						}
					
					$invref->{$PID} = $INSTOCK_QTY;
					$reserveref->{$PID} = $RESERVE_QTY;
					$OVERRIDES->{'zoovy:qty_instock'} = $invref->{$PID};
					# if (int($P->fetch('zoovy:inv_enable')) & 32) { $OVERRIDES->{'zoovy:qty_instock'} = 9999; }
					# $OVERRIDES->{'zoovy:qty_reserved'} = $reserveref->{$PID};
					$lm->pooshmsg("DEBUG|PID:$PID|+Final qty_instock: $INSTOCK_QTY qty_reserve: $RESERVE_QTY");
					}
				elsif ($expandPOGs==1) {
					##  break out inventoriable option groups
					# my $resultref = &POGS::build_sku_list($pid,\@pogs2,1+2);
					# my @skus = keys %{$resultref};
					my @skus = ();
					foreach my $set (@{$P->list_skus()}) {
						my ($sku,$skuref) = @{$set};
						push @skus, $sku;
						}
					my ($ONHANDREF,$RESREF) = INVENTORY2->new($USERNAME)->fetch_qty('@SKUS'=>\@skus);
 	
					if ($self->is_debug()) {
						$lm->pooshmsg("DEBUG|+".Dumper($ONHANDREF));
						}

					## clone each optsku and add to file.
					foreach my $set (@{$P->list_skus('verify'=>1)}) {
						my ($optsku,$skuref) = @{$set};
						my %SKU_OVERRIDES = %{$OVERRIDES};
						$SKU_OVERRIDES{'zoovy:prod_name'} = $P->fetch('zoovy:prod_name');
						$SKU_OVERRIDES{'zoovy:base_price'} = $P->skufetch($optsku,'sku:price');
						$SKU_OVERRIDES{'zoovy:base_weight'} = $P->skufetch($optsku,'sku:weight');
						$SKU_OVERRIDES{'zoovy:sku_name'} = $P->skufetch($optsku,'sku:title');
						$SKU_OVERRIDES{'zoovy:pogs_desc'} = $P->skufetch($optsku,'sku:variations_detail');

						## load sku specific settings and put them into the product.
						$SKU_OVERRIDES{'zoovy:prod_name'} =~ s/\n/ | /g; 	# replace CR/LF's in product name with |
						$SKU_OVERRIDES{'zoovy:sku_name'} =~ s/\n/ | /g; 	# replace CR/LF's in product name with |
						$PROCESSING{ $optsku } = [ $optsku, $P, $plm, \%SKU_OVERRIDES ];
						$SKU_OVERRIDES{'zoovy:qty_instock'} = $ONHANDREF->{$optsku};
						}
					
					## if we need to validate a sku, do that here:
					if (UNIVERSAL::can($sm, 'validatesku')) {
						foreach my $set (@{$P->list_skus()}) {
							my ($sku,$skuref) = @{$set};
							## if the syndication module can validate() the product, then let it.
							my ($err) = $sm->validatesku($sku,$P,$plm,$OVERRIDES);
							if ($err ne '') {
								$plm->pooshmsg("ERROR|SKU:$sku|+$err");
								}
							}
						}
					delete $PROCESSING{$PID};	# we are only sending each sku, so don't keep $pid in $prodsref
 					}
				elsif ($expandPOGs==0) {
					## we don't need to expand pogs for some mkts
					}
				else {
					$lm->pooshmsg("ISE|+expandPOGs[$expandPOGs] was not set properly in SYNDICATION module.");
					}	
				}

 			## 
 			## PHASE2: generate file
 			##
			if ($lm->can_proceed()) {
				if (scalar(keys %PROCESSING)==0) {
					# note: since we're doing this in batches, we can't actually throw an error.
					# $ERROR = "No eligible products after phase 2 transformation.";
					$lm->pooshmsg("WARN|+No products in this batch of products eligible for processing");
					}
				}
			elsif (defined $sj) { 
				$sj->progress($reccount,$rectotal,"Appending Products to Output"); 
				}

			$x++;

			foreach my $set (values %PROCESSING) {
				my ($SKU,$P,$plm,$OVERRIDES) = @{$set};

				if ($CONFIG{'module'} eq 'RAW001') {
					my $i = 0;
					foreach my $path (@{$NC->paths_by_product($P->pid())}) {
						$i++;
						$OVERRIDES->{"zoovy:navcat$i"} = $path;
						}
					}

				if ($self->provider()->{'store'} eq 'DOMAIN') {
					## don't generate a link unless we expected a valid domain name
					$OVERRIDES->{'zoovy:link2'} = $self->public_product_link($P);
					}

				my ($line) = undef;
				my ($RESULT) = undef;
				# my ($P) = PRODUCT->new($USERNAME,$prod,'%prodref'=>$prodsref->{$prod});
				if ($self->type() eq 'inventory') {
					($line,$RESULT) = $sm->inventory($SKU,$P,$plm,$OVERRIDES);
					}
				elsif ($self->type() eq 'pricing') {
					($line,$RESULT) = $sm->pricing($SKU,$P,$plm,$OVERRIDES);
					}
				elsif ($self->type() eq 'products') {
					($line,$RESULT) = $sm->product($SKU,$P,$plm,$OVERRIDES);	
					if ((not defined $line) && (not defined $RESULT)) {
						if ($DSTCODE eq 'EBF') {
							$RESULT = "OKAY|+No errors"; $line = 'OKAY';
							}
						}
					}
				else {
					$plm->pooshmsg(sprintf("ISE|SKU:$SKU|feed has unknown type: %s",$self->type()));
					}

				if (not defined $RESULT) {
					## no error, no warning.
					}

				if (not $self->is_debug($P->pid())) {
					# $lm->pooshmsg("BLAH|+Debug is not enabled");
					}
				elsif ($RESULT ne '') {
					## already output our response, no need to do anything with the line.
					#$lm->pooshmsg(sprintf("PRODUCT-FAILURE|pid=%s|+Did not add %s to due to error: %s .",$prod,$prod,$RESULT));
					}
				elsif ($line ne '') {
					$plm->pooshmsg("SUCCESS|SKU:$SKU|+Output: ".&ZOOVY::incode($line));
					}
				elsif ($self->is_debug($P->pid())) {
					$plm->pooshmsg(sprintf("ERROR|SKU:$SKU|+Did not add %s to %s output due to blank response.",$SKU,,$self->type()));
					}

				if ($self->is_debug()) {
					## DEBUG=2 blocks actual updates 
					if ($line eq '') {
						$plm->pooshmsg(sprintf("ERROR|+Experienced internal %s output error",$self->type()));;
						}
					else {
						$PROCESSED_SKUS{ $P->pid() } += 1;
						}
					}
				elsif ($line ne '') { 
					$SKU_TRANSMITTED++;
					print Fzz $line;
					$PROCESSED_SKUS{ $P->pid() } += 1; 	## record we processed this so we can ignore in STASH file.
					}
				else {
					$PROCESSED_SKUS{ $P->pid() } = 0;		## sku generated a blank line, but was processed.
					}

				## VERY VERY VERY LAST THING - MERGE $plm into $lm
				$lm->merge($plm,'sku'=>$SKU,'prefix'=>'PID');
				## $lm->merge($plm,'sku'=>$SKU,'%mapstatus'=>{ 'SUCCESS'=>'PID-SUCCESS', 'ERROR'=>'PID-ERROR', 'STOP'=>'PID-STOP' });
				## we MUST flush plm so it clears out the queue because it might be referenced by multiple sku's
				## and therefore would get merged multiple times.
				$plm->flush();
				}

			}


		if ($self->is_debug()) {
			## display reasons we failed.
			$lm->pooshmsg("INFO|+Seems after validation we have ".(scalar(keys %PROCESSED_SKUS))." products.");

			### whynot is a summ
			#my %ISSUE_SUMMARY = ();
			#foreach my $sku (keys %VALIDATION_ISSUES) {
			#	foreach my $issueref (@{$VALIDATION_ISSUES{$sku}}) {
			#		$ISSUE_SUMMARY{$issueref->{'msg'}}++;
			#		}
			#	}

			if ($TRACEPID) {
				if ($PROCESSED_SKUS{$TRACEPID}) {
					$lm->pooshmsg("GOOD|+$TRACEPID *WAS* processed and would be included in feed.");
					}
				elsif (not $PROCESSED_SKUS{$TRACEPID}) {
					$lm->pooshmsg("FAIL|$TRACEPID *WAS NOT* processed and would be included in feed.");
					}
				}
			}


		############################################################################
		##
		## SANITY: we need to check for products which were *NOT* in the respective feed type.
		##			  some of these might be disallowed even.., but for example on inventory feeds we need
		##			  to update whatever we've sent (even if we're setting that to "it's been deleted") ..
		##			  because silly clients will delete/remove products without taking down from the marketplace.
		##			  $PROCESSED_SKUS{ $SKU } => undef|0|1    where 0 = ignored, 1 = processed. and undef is unknown.
		##	
		&DBINFO::db_user_close();

		if ($self->type() eq 'inventory') {
			$lm->pooshmsg("INFO|+adding inventory footer.");
			print Fzz $sm->footer_inventory();
			}
		elsif ($self->type() eq 'pricing') {
			$lm->pooshmsg("INFO|+adding pricing footer.");
			print Fzz $sm->footer_pricing();
			}
		elsif ($self->type() eq 'products') {
			$lm->pooshmsg("INFO|+adding products footer.");
			print Fzz $sm->footer_products();
			}
		else {
			$lm->pooshmsg(sprintf("ISE|+FOOTER UNKNOWN FILE TYPE: %s",$self->type()));
			}

		close Fzz;
		}

	## agreed to use .ftp_user, .ftp_pass, .doba_user, .doba_pass and hardcode ftp_host for DOBA
	my ($UPFILE) = ('');


	if ($self->get('.url') eq '' and not UNIVERSAL::can($sm, 'upload')) {
		$lm->pooshmsg("FATAL|+URL not set. Please check your configuration\n");
		$SKU_TRANSMITTED = 0;
		}	
	my $URL = $self->get('.url');

	if ((defined $sj) && (not $lm->can_proceed())) { 
		$sj->progress(0,0,"Transferring file"); 
		}
	
	my $tlm = LISTING::MSGS->new($USERNAME,'stderr'=>($options{'trace'})?1:0);
	if (not $lm->can_proceed()) {
		## shit already happened.		
		print STDERR Dumper($lm);
		$tlm->pooshmsg("STOP|+Prior errors stopping any transfer attempt");
		}
	elsif ($self->is_debug()) {
		$tlm->pooshmsg("SUCCESS|+Debug mode - no file was transferred.");
		}
	elsif (UNIVERSAL::can $sm, 'upload') {
		## anytime we've got a proprietary "upload" method in the object, we'll use that.
		($tlm) = $sm->upload($FILENAME,$tlm);
		## NOTE: these will set their own errors and/or success - best practices:
		##
		##		ISE on if there is a data/handling error it should set 
		##		ERROR on user/pass failure or other type of api 'preventable' issue
		##		STOP on a pause event .. (non error) ex: testing
		##
		}
	elsif ($URL =~ /^site:\/\/(.*?)$/) {
		## SITE (copy to public files directory with a specific filename)
		my ($storefile) = $1;
		$storefile =~ s/[\/\\]+/_/g;

		$storefile = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES/'.$storefile;
		system("/bin/cp $FILENAME $storefile");
		chown $ZOOVY::EUID,$ZOOVY::EGID,"$storefile";
		chmod 0666, "$storefile";
		$tlm->pooshmsg("SUCCESS|+Stored file $storefile");
		}
	elsif ($URL =~ /^email:(.*?)$/) {
		my ($ERROR) = $self->transfer_email($URL,[{in=>$FILENAME,out=>$FILENAME}]);
		if ($ERROR eq '') {
			$tlm->pooshmsg("SUCCESS|+Emailed to $FILENAME");
			}
		else {
			$tlm->pooshmsg("FATAL|+Email transport error - $ERROR");
			$SKU_TRANSMITTED=0;
			}
		}
	elsif ($URL eq 'null') {
		## do nothing.
		$tlm->pooshmsg("SUCCESS|Null upload method (nothing to do)");
		}
	elsif ($URL =~ /^(sftp|ftp)\:\/\//) {
		## FTP (set's $lm to ERROR|ISE based on what went wrong)
		($tlm) = $self->transfer_ftp($URL,[$FILENAME],$tlm);
		if ($tlm->has_win()) {
			}
		else {
			$SKU_TRANSMITTED=0;
			$tlm->pooshmsg("FATAL|+SKU TRANSMITTED=0 because we did not have a WIN response from FTP");
			}
		}
	else {
		$tlm->pooshmsg(sprintf("ISE|+Could not understand URL provided. [%s]",$URL));
		$SKU_TRANSMITTED=0;
		}

	## merge the transfer messages into the primary listing::msgs option
	if ($tlm->has_win()) {
		$lm->merge($tlm);
		}	
	elsif ($tlm->had(['FATAL'])) {
		$lm->merge($tlm);
		}
	elsif ($tlm->had(['ISE'])) {
		$lm->merge($tlm);
		}
	else {
		$lm->merge($tlm);
		$lm->pooshmsg("ISE|+Got non-win response from transfer");
		}

	if (defined $sj) { $sj->progress(0,0,"Saving local backup");  }

	## write file to the PRIVATE FILES dir/table 
	my $guid = undef;
	require LUSER::FILES;
	my ($lf) = LUSER::FILES->new($USERNAME);
	if ($DSTCODE eq 'DOB') {
		## DOBA saves it's own product feed.
		}
	elsif ($self->is_debug()) {
		$lm->pooshmsg("WARN|+Did not write file since DEBUG=1");
		}
	elsif ((not defined $FILENAME) || ($FILENAME eq '')) {
		$lm->pooshmsg("ISE|+\$FILENAME was not set, cannot write file.");
		}
	elsif (defined $lf) {
		my $GUID = substr(sprintf("%s-%s-%s-%s",&ZTOOLKIT::pretty_date($^T,3),$self->dstcode(),$self->type()),0,31);
		my %params = (
       	file=>$FILENAME,
         title=>"Syndication Feed $CONFIG{'module'} for $DOMAIN",
         type=>$self->dstcode(),
         overwrite=>1,
			guid=>$GUID,
         meta=>{'DSTCODE'=>$self->dstcode(),'TYPE'=>$self->type()},
			);
		#if (length($self->{'PRIVATE_FILE_GUID'})>5) {
		#	## this is total duct tape 10/22/10
		#	$params{'guid'} = $self->{'PRIVATE_FILE_GUID'};
		#	}

		($guid) = $lf->add(%params);
		## if an insert just occured, a GUID is returned 
		## otherwise, the PRIVATE_FILE_GUID should already be set
		if (defined $guid) { 
			$self->{'PRIVATE_FILE_GUID'} = $guid; 
			}
		}


	########################################################################
	## step 4: copy file to users directory
	
	my %dbupdates = ();
	if ($options{'DEBUG'}&2) {
		warn "Got a good old fashion DEBUG=2 .. no error, no status, no nothing.";
		## no status updates, etc.
		}
	elsif ($lm->has_win()) {
		warn "*********************************** Had Win!\n";
		## was this a first time publication - if so add a TODO acknowledgement.
		$dbupdates{'CONSECUTIVE_FAILURES'} = 0;	## yay, we got a win so we reset the failure counter
		if (($self->type() eq 'products') && ($self->get('PRODUCTS_LASTRUN_GMT')==0)) {
			&ZOOVY::add_notify(
				$USERNAME,"ERROR.SYNDICATION",
				dst=>$DSTCODE,
				feedtype=>$self->type(),
				title=>"Product Syndication Feed $DSTCODE Submission",
				detail=>"Feed $DSTCODE ".$self->type()." has been completed."
				);
			}
		elsif (($self->type() eq 'inventory') && ($self->get('INVENTORY_LASTRUN_GMT')==0)) {
			&ZOOVY::add_notify(
				$USERNAME,"ALERT.SYNDICATION",
				dst=>$DSTCODE,
				feedtype=>$self->type(),
				title=>"Inventory Feed $DSTCODE Submission",
				detail=>"Feed has been completed."
				);
			}
		elsif (($self->type() eq 'pricing') && ($self->get('PRICING_LASTRUN_GMT')==0)) {
			&ZOOVY::add_notify(
				$USERNAME,"ALERT.SYNDICATION",
				dst=>$DSTCODE,
				feedtype=>$self->type(),
				title=>"Pricing Feed $DSTCODE Submission",
				detail=>"Feed has been completed."
				);
			}

		$dbupdates{'ERRCOUNT'} = 0;
		if ($self->type() eq 'products') {
			$dbupdates{'PRODUCTS_COUNT'} = (scalar keys %PROCESSED_SKUS);
			my $errs = 0; foreach my $v (values %PROCESSED_SKUS) { if ($v == 0) { $errs++; } };
			$dbupdates{'PRODUCTS_ERRORS'} = $errs;
			$dbupdates{'PRODUCTS_LASTRUN_GMT'} = time();
			$lm->pooshmsg(sprintf("SUMMARY-PRODUCTS|+records:%s sku:%s validated:%d transmitted:%d",$dbupdates{'PRODUCTS_COUNT'},$SKU_TOTAL,$SKU_VALIDATED,$SKU_TRANSMITTED));
			}
		elsif ($self->type() eq 'inventory') {
			$dbupdates{'INVENTORY_COUNT'} = (scalar keys %PROCESSED_SKUS);
			$dbupdates{'INVENTORY_LASTRUN_GMT'} = time();
			$lm->pooshmsg(sprintf("SUMMARY-INVENTORY|+records:%s sku:%s validated:%d transmitted:%d",$dbupdates{'INVENTORY_COUNT'},$SKU_TOTAL,$SKU_VALIDATED,$SKU_TRANSMITTED));
			}
		elsif ($self->type() eq 'pricing') {
			$dbupdates{'PRICING_COUNT'} = (scalar keys %PROCESSED_SKUS);
			$dbupdates{'PRICING_LASTRUN_GMT'} = time();
			$lm->pooshmsg(sprintf("SUMMARY-PRICING|+records:%s sku:%s validated:%d transmitted:%d",$dbupdates{'PRICING_COUNT'},$SKU_TOTAL,$SKU_VALIDATED,$SKU_TRANSMITTED));
			}
		else {
			ZOOVY::confess($USERNAME,sprintf("Syndication error (unknown type:%s)",$self->type()),justkidding=>1);
			$lm->pooshmsg(sprintf("ISE|+Unknown syndication type:%s",$self->type()));
			}
		}
	elsif (my $iseref = $lm->had('ISE')) {
		#warn "*********************************** Had ISE!\n";
		#require TODO;
		#&ZOOVY::confess($USERNAME,"SYNDICATION $DSTCODE ISE: $iseref->{'+'}\n".Dumper($lm),justkidding=>1);
		#my ($t) = TODO->new($USERNAME,writeonly=>1);
		#if (defined $t) {
		#	$t->add(
		#		title=>"Syndication Internal-Error: $DSTCODE",
		#		link=>"syndication:$DSTCODE",
		#		class=>"ERROR",
		#		detail=>sprintf("%s",$iseref->{'+'}),
		#		);
		#	}
		#$self->addsummary("NOTE",NOTE=>"ISE: $iseref->{'+'}");
		$dbupdates{'IS_SUSPENDED'} = 1;
		$dbupdates{'*CONSECUTIVE_FAILURES'} = "CONSECUTIVE_FAILURES+1";
		$lm->pooshmsg(sprintf("SUMMARY-%s|+ISE %s:%s",$self->type(),$iseref->{'_'},$iseref->{'+'}));
		}
	elsif (my $stopref = $lm->had('STOP')) {
		## not sure why we'd get here.
		## NOTE: work.pl will disable syndication if 'STOP' is returned		
		#warn "*********************************** Had STOP!\n";
		#$self->addsummary("NOTE",NOTE=>"Received STOP instruction: $stopref->{'+'}");
		$dbupdates{'IS_SUSPENDED'} = 2;
		$lm->pooshmsg(sprintf("SUMMARY-%s|+STOP %s:%s",$self->type(),$stopref->{'_'},$stopref->{'+'}));
		}
	elsif (my $pauseref = $lm->had('PAUSE')) {
		## stop and pause are similar, but work.pl won't suspend syndication on a pause.
		##	pause will eventually advance all polling counters
		# $self->addsummary("NOTE",NOTE=>"Received PAUSE instruction: $pauseref->{'+'}");
		$lm->pooshmsg(sprintf("SUMMARY-%s|+PAUSED %s:%s",$self->type(),$pauseref->{'_'},$pauseref->{'+'}));
		}
	else {
		# print Dumper($self);
		my $whatsup = $lm->whatsup();
#		my $PROFILE = $self->profile();
		my $DOMAIN = $self->domain();
		my $PRT = $self->prt();
		my $DSTTITLE = $SYNDICATION::PROVIDERS{$DSTCODE}->{'title'};
		$lm->pooshmsg(sprintf("SUMMARY-%s|+UNKNOWN %s:%s",$self->type(),$whatsup->{'_'},$whatsup->{'+'}));

		## always treat this as an ISE since we should NEVER get here.
		open F, sprintf(">%s/syndication-dump-$DSTCODE-$USERNAME-$PRT-$DOMAIN",&ZOOVY::tmpfs());
		print F Dumper($lm);
		close F;
		}

	## copy dbupdates into current object.
	foreach my $k (keys %dbupdates) { $self->{$k} = $dbupdates{$k}; }
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	$dbupdates{'MID'} = $self->mid();
	$dbupdates{'ID'} = $self->dbid();
	$dbupdates{'LOCK_ID'} = 0;
	$dbupdates{'LOCK_GMT'} = 0;
	my $qtTXLOG = $udbh->quote($lm->status_as_txlog('@'=>\@SYNDICATION::TXMSGS)->serialize());
	$dbupdates{'*TXLOG'} = sprintf("concat(%s,TXLOG)",$qtTXLOG);
	
	my ($pstmt) = &DBINFO::insert($udbh,'SYNDICATION',\%dbupdates,key=>['MID','ID'],sql=>1,verb=>'update');
	print STDERR "/* REAL UPDATE */ $pstmt\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();

	if ($self->is_debug() && 0) {
		warn "No validation log because DEBUG=1\n";
		}

	if (UNIVERSAL::can($sm, 'finish')) {
		$sm->finish($lm);	
		};

	if (defined $sj) { 
		$sj->progress(0,0,"Finished Syndication"); 
		}

	# print Dumper($self); die();
	}




#sub runnow_inventory {
#	my ($self) = @_;
#	return($self->runnow2(undef,'inventory'));
#	}


1;
