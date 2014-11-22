#!/usr/bin/perl

use strict;

use XML::SAX::Simple;
use IO::String;
use XML::LibXML;

use Data::Dumper;
use lib "/httpd/modules";
use DBINFO;
require PRODUCT;
use ZOOVY;
use LISTING::MSGS;
use SYNDICATION;
use AMAZON3;
use TXLOG;

my %params = ();
foreach my $arg (@ARGV) {
	if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}

##
## user=
##	cluster=
##	docs=1 (process documents)
##
##	xml=1 		show xml payloads sent to amazon
## contents=1	outputs the document contents
##	status=1		outputs the bw status updates that were done
## trace=1		outputs listing::msgs debug to stderr
##

my @USERS = ();
if ($params{'user'}) {
	push @USERS, $params{'user'};
	}


if (scalar(@USERS)>0) {
	print STDERR sprintf("USERS ALREADY INITIALIZED TO: %s\n",join(",",@USERS));
	}
else {
	die("you must pass user=");
	}
#elsif ($params{'docs'}) {
#	my $pstmt = "select USERNAME,DOCID,CREATED_GMT,DOCTYPE,ATTEMPTS from AMAZON_DOCS where RETRIEVED_GMT=0 and MID=$MID";
#	my $sth = $udbh->prepare($pstmt);
#	$sth->execute();
#	my %USERS = ();
#	while ( my ($USERNAME,$DOCID,$CREATED_GMT,$DOCTYPE,$ATTEMPTS) = $sth->fetchrow() ) {
#		$USERNAME = uc($USERNAME);
#	
#		my $PROCESS_PLEASE = 1;
#		## we don't actually need to retrieve these, so we can just mark them as retrieved
#		if ($DOCTYPE eq '_POST_ORDER_ACKNOWLEDGEMENT_DATA_') { $PROCESS_PLEASE = 0; }
#		if ($DOCTYPE eq '_POST_ORDER_FULFILLMENT_DATA_') { $PROCESS_PLEASE = 0; }
#
#		## after 5 attempts, we're done
#		if ($ATTEMPTS>5) { $PROCESS_PLEASE = 0; }		
#			
#		## after 15 days we just don't care, set the RETRIEVED_GMT to CREATED_GMT and we'll stop trying to process
#		if ($CREATED_GMT < $^T-(86400*15)) { $PROCESS_PLEASE = 0; }
#		
#		if (not $PROCESS_PLEASE) {
#			my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#			$pstmt = "update AMAZON_DOCS set RETRIEVED_GMT=CREATED_GMT where MID=$MID /* $USERNAME */ and DOCID=".int($DOCID);
#			print STDERR "$pstmt\n";
#			$udbh->do($pstmt);
#			}
#		else {
#			## increment that have documents to process!
#			$USERS{$USERNAME}++;
#			}
#		}
#	$sth->finish();
#	@USERS = keys %USERS;
#	}
#else {
#	## normal (non docs) run mode -- normally users are run individually from /httpd/servers/sync/queue.pl
#
#	my %NEED = ();
#
#	## lookup queue
#	my $pstmt = "select USERNAME,count(*) from SYNDICATION_QUEUED_EVENTS where DST='AMZ' and PROCESSED_GMT=0 and CREATED_GMT<unix_timestamp(now()) ";
#	$pstmt .= " and MID=".&ZOOVY::resolve_mid($params{'user'})." /* $params{'user'} */ ";
#	$pstmt .= " group by MID order by ID";
#	print "$pstmt\n";
#	my $sth = $udbh->prepare($pstmt);
#	$sth->execute();
#	while ( my ($USERNAME,$count) = $sth->fetchrow() ) {
#		print "USERNAME: $USERNAME has $count pending events\n";
#		$NEED{$USERNAME} = $count;
#		}
#	$sth->finish();
#
#	@USERS = keys %NEED;
#	}
print Dumper(@USERS);	


foreach my $USERNAME (@USERS) {
	## phase1: bump timestamps and clear events
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	## preprocess the queue, get a list of products to create, update, delete
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($lm) = LISTING::MSGS->new($USERNAME,logfile=>"~/amazon-%YYYYMM%.log",'stderr'=>($params{'trace'})?1:0);
	my @EVENTS = ();
	if ($params{'debug'}) {
		print STDERR "DEBUG VERB: $params{'verb'}\n";
		if ($params{'product'}) {
			if (not defined $params{'sku'}) { $params{'sku'} = $params{'product'}; }
			push @EVENTS, [ 0, $params{'product'}, $params{'sku'}, uc($params{'verb'}) ];
			}
		if ($params{'reset'}) {
			## get a list of products
			my ($TB) = &ZOOVY::resolve_product_tb($USERNAME,$MID);
			my $pstmt = "select PRODUCT,MKT_BITSTR from $TB where MID=$MID /* $USERNAME */ order by TS desc limit 0,1;";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my ($PRODUCT,$BITSTR) = $sth->fetchrow() ) {
				print "PID:$PRODUCT BT:$BITSTR\n";				
				}
			$sth->finish();
			}
		}


	if (scalar(@EVENTS)==0) {
		##
		## NOTE: eventually we'll skip this stage alltogther and just modify the bits directly in the user event dispatch (user.pl)
		## but for now, this is far easier to debug (and reprocess)
		##
		my ($userref) = &AMAZON3::fetch_userprt($USERNAME,undef);
		my $pstmt = "select ID,PRODUCT,SKU,VERB,CREATED_GMT from SYNDICATION_QUEUED_EVENTS where DST='AMZ' and PROCESSED_GMT=0 and MID=$MID /* $USERNAME */ and CREATED_GMT<unix_timestamp(now())";
		print $pstmt."\n";
		my ($sthx) = $udbh->prepare($pstmt);
		$sthx->execute();
		while ( my ($ID,$PID,$SKU,$VERB,$CREATED_GMT) = $sthx->fetchrow() ) {


			my $success = 0;
			if ($CREATED_GMT > $^T) {
				warn "IGNORING FUTURE EVENT ID:$ID PID:$PID SKU:$SKU VERB:$VERB\n";
				}
			elsif (($VERB eq 'DELETE') || ($VERB eq 'REMOVE')) {
				$lm->pooshmsg("EVENT|ID:$ID|SKU:$SKU|+$VERB");
				&AMAZON3::item_set_status($userref,$SKU,['=this.delete_please'],'TS'=>1);
				$success++;
				}
			elsif (($VERB eq 'SYNC') || ($VERB eq 'UPDATE')) {
				$lm->pooshmsg("EVENT|ID:$ID|SKU:$SKU|+$VERB");
				&AMAZON3::item_set_status($userref,$SKU,['=all.need'],'TS'=>1);
				$success++;
				}
			elsif (($VERB eq 'CREATE') || ($VERB eq 'GEOMETRY')) {
				$lm->pooshmsg("EVENT|ID:$ID|SKU:$SKU|+$VERB");
				&AMAZON3::item_set_status($userref,$SKU,['=this.create_please'],'TS'=>1);
				$success++;
				}
			else {
				$lm->pooshmsg("ISE|+unknown verb:$VERB EVENT:$ID,$PID,$SKU,$VERB");
				}

			if ($success) {
				$pstmt = "update SYNDICATION_QUEUED_EVENTS set PROCESSED_GMT=$^T where ID=$ID and MID=$MID /* $USERNAME */ ";
				print "$pstmt\n";
				$udbh->do($pstmt);
				}
			}
		$sthx->finish();
		}
	
	if (scalar(@EVENTS)==0) {
		## BIG SYNC (once per day)
		## next go through the SKU_LOOKUP_xxxx and see if the AMAZON_PRODUCTDB_GMT is different than the product timestamp
		}

	if ($params{'synconly'}) {
		die();
		}
	&DBINFO::db_user_close();
	}


##
## proecss inbound docs
##

foreach my $USERNAME (@USERS) {
	next if (int($params{'docs'})==0);

	print "USERNAME:$USERNAME\n";
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($userref) = &AMAZON3::fetch_userprt($USERNAME,undef);
	my ($MID) = $userref->{'MID'};

	my ($lm) = LISTING::MSGS->new($USERNAME,logfile=>"~/amazon-%YYYYMM%.log",'stderr'=>($params{'trace'})?1:0);
	if (not &DBINFO::task_lock($USERNAME,"amazon-docs",(($params{'unlock'})?"PICKLOCK":"LOCK"))) {
		$lm->pooshmsg("STOP|+Could not obtain lock");
		}

	next if (not $lm->can_proceed());

	my @RDOCS = ();
	## 	0: docid
	##		1: doctype ex: _POST_PRODUCT_DATA_, _POST_PRODUCT_IMAGE_DATA_
	##		2: zoovy bitwise (bw) doctype (products, images, relations)
	##		3: _DONE_ or _ERRORS_

	my ($path) = &ZOOVY::resolve_userpath($userref->{'USERNAME'});

	my $pstmt = "select DOCTYPE,DOCID,ATTEMPTS,CREATED_GMT from AMAZON_DOCS where CREATED_GMT<".(time()-15)." ";
	if ($params{'docid'}==0) {
		$pstmt .= " and RETRIEVED_GMT=0 ";
		}
	else {
		$pstmt .= " and DOCID=".int($params{'docid'});
		}
	$pstmt .= " and MID=$userref->{'MID'} and PRT=$userref->{'PRT'} ";
	$pstmt .= " order by attempts,created_gmt";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	$lm->pooshmsg(sprintf("INFO|waiting for %d docs",$sth->rows()));

	my $DOCUMENTS_TO_PROCESS = int($params{'docs'});
	while ( my ($doctype,$docid,$attempts,$created_gmt) = $sth->fetchrow() ) {
		next if ($DOCUMENTS_TO_PROCESS <= 0);
		my $BWDOCTYPE = '';
		if ($doctype eq '_POST_PRODUCT_DATA_') { $BWDOCTYPE = 'products'; }
		elsif ($doctype eq '_POST_PRODUCT_IMAGE_DATA_') { $BWDOCTYPE = 'images';  }
		elsif ($doctype eq '_POST_PRODUCT_RELATIONSHIP_DATA_') { $BWDOCTYPE = 'relations'; }
		elsif ($doctype eq '_POST_PRODUCT_PRICING_DATA_') { $BWDOCTYPE = 'pricing'; }
		elsif ($doctype eq '_POST_INVENTORY_AVAILABILITY_DATA_') { $BWDOCTYPE = 'inventory'; }
		elsif ($doctype eq '_POST_PRODUCT_SHIPPING_DATA_') { $BWDOCTYPE = 'shipping'; }
		elsif ($doctype eq '_POST_ORDER_ACKNOWLEDGEMENT_DATA_') { $BWDOCTYPE = ''; }	 ## we don't currently process this.
		elsif ($doctype eq '_POST_ORDER_FULFILLMENT_DATA_') { $BWDOCTYPE = ''; }		 ## we don't currently process this.
		else {
			$lm->pooshmsg("DEBUG|+sync is ignoring unknown docid:$docid doctype:$doctype");
			}

		next if ($BWDOCTYPE eq '');  # non supported document type
		$DOCUMENTS_TO_PROCESS--; ## process a limited number of documents to avoid 503 errors

		my ($rdocid,$status) = &AMAZON3::getDocumentPS($userref,$docid);
		my $ADDED = 0;
		if ($status eq '_FAILED_DUE_TO_FATAL_ERRORS_') {
			## the bad case
			$lm->pooshmsg("INFO|DOCID:$docid|+Found errors, sending for processing.");
			$ADDED++;
			push @RDOCS, [ $docid, $doctype, $BWDOCTYPE, '_ERRORS_' ];
			}
		elsif ($status eq '_IN_PROGRESS_') {
			$lm->pooshmsg("WARN|DOCID:$docid|+Document still in progress (attempts: $attempts created: ".&ZTOOLKIT::pretty_date($created_gmt,1).")");
			}
		elsif ($status eq '_SUBMITTED_') {
			$lm->pooshmsg("INFO|DOCID:$docid|+Document submitted (attempts: $attempts created: ".&ZTOOLKIT::pretty_date($created_gmt,1).")");
			}
		elsif ($rdocid == 0) {
			$lm->pooshmsg("WARN|DOCID:$docid|+Document not available (yet) -- $status");
			}
		elsif ($status eq '_DONE_') { 
			# the good case.
			$lm->pooshmsg("INFO|DOCID:$docid|+clean response, sending for processing.");
			$ADDED++;
			push @RDOCS, [ $docid, $doctype, $BWDOCTYPE, '_DONE_' ];
			}
		elsif ($status eq '_CANCELLED_') {
			## amazon cancelled the feed - usually at the request of the merchant
			## we should be looking to use AMAZON_DOCUMENT_CONTENTS in the future to update the products
			$lm->pooshmsg("WARN|DOCID:$docid|+Document cancelled by Amazon so we won't have anything to process");
			}
		elsif ($status =~ /^503/) {
			## a 503 error is caused by requesting too many docs at the same time.
			$lm->pooshmsg("WARN|DOCID:$docid|+throttled");
			}
		elsif ($status =~ /^400 Bad Request/) {
			## a 400 error is a bad request (ivnalid password?)
			$lm->pooshmsg("ERROR|DOCID:$docid|+got 400 error (invalid user/pass?)");
			}
		else {
			&ZOOVY::confess($userref->{'USERNAME'},"Unknown/unhandled value returned to getDocumentPS\nrdocid=$rdocid\nstatus=$status\n");
			}

		if ($ADDED) {
			## document was added @RDOCS (received documents) - nothing else to do.
			}
		elsif (($created_gmt > 0) && ($created_gmt > $^T-3600)) {
			print "created_gmt: $created_gmt and timecheck: $^T-3600\n";
			## give amazon 1 hour to process documents before we start incrementing attempts
			$lm->pooshmsg("WARN|DOCID:$docid|+Not enough time has elapsed to increment attempts");
			}
		elsif ($attempts>5) {
			## "Too many attempts on Document $docid";
			$pstmt = "update AMAZON_DOCS set RETRIEVED_GMT=1,RESPONSE_BODY='',ATTEMPTS=ATTEMPTS+1 where MID=$userref->{'MID'} and PRT=$userref->{'PRT'} and DOCID=".int($docid);
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			$lm->pooshmsg("WARN|DOCID:$docid|+Too many attempts ($attempts)");
			}
		else {
			## increment the attempt counter since it wasn't added
			$lm->pooshmsg("WARN|DOCID:$docid|+incrementing attempts ($attempts)");
			if (not defined $status) { $status = ''; }
			$pstmt = "update AMAZON_DOCS set RESPONSE_BODY=".$udbh->quote($status).",ATTEMPTS=ATTEMPTS+1 where MID=$userref->{'MID'} and PRT=$userref->{'PRT'} and DOCID=".int($docid);
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			}
		}
	$sth->finish();


	my $TS = time();
	foreach my $rdoc (@RDOCS) {
		my ($docid,$doctype,$feed_type,$status) = @{$rdoc};

		my ($ERROR,$xml) = &AMAZON3::getDocument($userref,$docid,$doctype);

		my ($src_file) = sprintf("%s/PRIVATE/amz-%s-%s-request.xml",ZOOVY::resolve_userpath($userref->{'USERNAME'}),$userref->{'USERNAME'},$docid);
		print STDERR "SRC_FILE: $src_file\n";
		my ($dst_file) = sprintf("%s/PRIVATE/amz-%s-%s-response.xml",ZOOVY::resolve_userpath($userref->{'USERNAME'}),$userref->{'USERNAME'},$docid);
		print STDERR "DST_FILE: $dst_file\n";

		##
		## now go into the database and get the list of msgs for a document.
		##
		my @DOC_CONTENTS = ();
		if ($ERROR eq '') {
			my $pstmt = "select MSGID,FEED,SKU from AMAZON_DOCUMENT_CONTENTS where MID=$MID /* $USERNAME */ and DOCID=".int($docid);
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my ($msgid,$feed,$sku) = $sth->fetchrow() ) {
				print "MSGID:$msgid FEED:$feed SKU:$sku\n";
				push @DOC_CONTENTS, [ $msgid, $feed, $sku ];
				}
			$sth->finish();
			}

		##
		## GET THE XML FROM THE MULTIPART DOCUMENT.
		##
		my @RESULTS = ();
		my $UNKNOWN_ERRORS = 0;
		my @XMLMESSAGES = ();
		my $parser = XML::LibXML->new();

		my @messages = ();
		if ($ERROR) {
			}
		else {
			## we're good
			# print "Why yes please, that would be wonderful!!\n";
			my $tree = $parser->parse_string($xml);
			my $root = $tree->getDocumentElement;
			@messages = $root->getElementsByTagName('Message');
			}


		my @issues = ();
		foreach my $detail (@messages) {
			my $msgxml = $detail->toString();
			my ($sh) = IO::String->new(\$msgxml);
			my ($msg) = XML::SAX::Simple::XMLin($sh,ForceArray=>1);

			#	$VAR2 = {
			#		 '.MessageID' => '1',
			#		 '.ProcessingReport.ProcessingSummary.MessagesProcessed' => '1',
			#		 '.ProcessingReport.ProcessingSummary.MessagesWithWarning' => '0',
			#		 '.ProcessingReport.ProcessingSummary.MessagesSuccessful' => '1',
			#		 '.ProcessingReport.DocumentTransactionID' => '2705136282',
			#		 '.ProcessingReport.ProcessingSummary.MessagesWithError' => '0',
			#		 '.ProcessingReport.StatusCode' => 'Complete'
			#	  };
			## AMAZON RETURNS TWO ProcessingSummary nodes, the first is Warnings, the Second is Errors.
	
			if (defined $msg->{'ProcessingReport'}[1]) {
				ZOOVY::confess($userref->{'USERNAME'},"Alas.. I don't know how to handle documents with multiple ProcessingReport nodes");
				}
			my $flat = &ZTOOLKIT::XMLUTIL::SXMLflatten($msg);
			my ($flat_warn) = &ZTOOLKIT::XMLUTIL::SXMLflatten($msg->{'ProcessingReport'}[0]{'ProcessingSummary'}->[0]);
			my ($flat_err) = &ZTOOLKIT::XMLUTIL::SXMLflatten($msg->{'ProcessingReport'}[0]{'ProcessingSummary'}->[1]);
			my $thisdocid = $flat->{'.ProcessingReport.DocumentTransactionID'};
			if ($thisdocid != $docid) {
				$ERROR = "FAIL|Response document[$thisdocid] does not match requested[$docid]";							
				}
			elsif ($flat_err->{'.MessagesProcessed'} == $flat_err->{'.MessagesSuccessful'}) {
				## woot, all good.
				}
			else {
				$UNKNOWN_ERRORS = $flat_err->{'.MessagesWithError'};
				}

			##
			## a response document might have one or more ProcessingReports which indicate which specific SKU's had issues.
			##
			if (defined $msg->{'ProcessingReport'}[0]{'Result'}) {		
				foreach my $r (@{$msg->{'ProcessingReport'}[0]{'Result'}}) {
					my $resultref = &ZTOOLKIT::XMLUTIL::SXMLflatten($r);
					$resultref->{'docid'} = $docid;
					$resultref->{'doctype'} = $doctype;
					push @issues, $resultref;
					}	
				}
			}


		##
		## go through the errors/warnings in @issues and match (link) them to the @DOC_CONTENTS in array position #3
		##
		foreach my $issue (@issues) {
			print "REPORT(s) docid=$docid doctype=$doctype\n".Dumper($issue)."\n";
			if ($issue->{'.MessageID'}>0) {
				## track down the message in doc_contents, set the error.
				foreach my $msg (@DOC_CONTENTS) {
					next if (defined $msg->[3]);
					if ($msg->[0] == $issue->{'.MessageID'}) {
						$msg->[3] = $issue;
						}
					}
				}
			elsif (($issue->{'.MessageID'}==0) && ($issue->{'.ResultMessageCode'} == 90000)) {
				## a warning that can be ignored.
				}
			elsif ($issue->{'.MessageID'}==0) {
				## unknown message id apply to all messages
				## we should whitelist these.
#				die(); # is this line ever actually reached? (on anything other than a formatting error)
				foreach my $msg (@DOC_CONTENTS) {
					next if (defined $msg->[3]);
					$msg->[3] = $issue;
					}
				}				
			}

		print 'DOC_CONTENTS: '.Dumper(\@DOC_CONTENTS);

		if (scalar(@DOC_CONTENTS)==0) {
			# $ERROR = "Unknown document contents";
			warn "We don't know what was in this document (attempt rebuild?)\n";
			}

		## now process out the errors.
		foreach my $content (@DOC_CONTENTS) {
			my ($msgid,$feed,$SKU,$errorref) = @{$content};

			if ((defined $errorref) && ($errorref->{'.ResultCode'} ne 'Warning')) {
				## THIS IS AN ERROR NOT A WARNING 
				## this is NOT a permanent solution:
				## a warning from amazon means the product was processed but was not perfect (eg. it was missing attributes that are suggested but not required).
				## as it stands every warning amazon is returning appears to be invalid which is confusing the merchants.
				## amazon stated that as warnings can be ignored the issue will not be passed to the developers.
				## for now we are treating a warning as a success but Brian wants to revist the issue and come up with a better way of dealing with warnings  
				my $SEVERITY = 'ERROR';
				my $UNIQUE = $feed;
				if ($UNIQUE eq 'init') { $UNIQUE = 'products'; }	## init is the same as product.
				$lm->pooshmsg("$SEVERITY|SKU:$SKU|#:$errorref->{'.ResultMessageCode'}|+$errorref->{'.ResultDescription'}");
				my $txline = &TXLOG::addline($TS,$UNIQUE,'_'=>$SEVERITY,'#'=>$errorref->{'.ResultMessageCode'},'+'=>$errorref->{'.ResultDescription'});
				&AMAZON3::item_set_status($userref,$SKU,["+$feed.fail"],'+ERROR'=>$txline,'TS'=>1);
				}
#			if (defined $errorref) {
#				my $SEVERITY = ($errorref->{'.ResultCode'} eq 'Warning')?'WARNING':'ERROR';
#				my $UNIQUE = $feed;
#				if ($UNIQUE eq 'init') { $UNIQUE = 'products'; }	## init is the same as product.
#				$lm->pooshmsg("$SEVERITY|SKU:$SKU|#:$errorref->{'.ResultMessageCode'}|+$errorref->{'.ResultDescription'}");
#				my $txline = &TXLOG::addline($TS,$UNIQUE,'_'=>$SEVERITY,'#'=>$errorref->{'.ResultMessageCode'},'+'=>$errorref->{'.ResultDescription'});
#				&AMAZON3::item_set_status($userref,$SKU,["+$feed.fail"],'+ERROR'=>$txline,'TS'=>1);
#				}
			elsif ($feed eq 'init') {
				## special handling for init feeds
				&AMAZON3::item_set_status($userref,$SKU,["=this.create_done"],'TS'=>1);
				}			
			elsif ((not defined $errorref) || ($errorref->{'.ResultCode'} eq 'Warning')) {
				## success (win! WIN!)
				&AMAZON3::item_set_status($userref,$SKU,["+$feed.win"],'TS'=>1);
				}
#			elsif (not defined $errorref) {
#				## success (win! WIN!)
#				&AMAZON3::item_set_status($userref,$SKU,["+$feed.win"],'TS'=>1);
#				}
			else {
				die("should never be reached");
				}
			}

		
		if ($ERROR eq '') {
			my $TS = time();
			my $pstmt = '';
			my @SQL = ();
			push @SQL, 'start transaction';
			push @SQL, "update AMAZON_DOCUMENT_CONTENTS set ACK_GMT=$TS where MID=$userref->{'MID'} /* $userref->{'USERNAME'} */ and DOCID=$docid ";
			push @SQL, "update AMAZON_DOCS set RETRIEVED_GMT=$TS where MID=$userref->{'MID'} /* $userref->{'USERNAME'} */ and DOCID=$docid ";
			push @SQL, 'commit';			
			foreach my $pstmt (@SQL) {
				print "$pstmt;\n";
				$udbh->do($pstmt);
				}
			}

		$DOCUMENTS_TO_PROCESS--;
		}



	&DBINFO::task_lock($USERNAME,"amazon-docs","UNLOCK");	
	&DBINFO::db_user_close();
	}



##
## SANITY: at this point all the bits should be set, and we just need to select them.
##

if ($params{'sync'}) { $params{'docs'} = 0; } ## implicitly turn on sync after docs (used by queue.pl)


foreach my $USERNAME (@USERS) {
	next if (int($params{'docs'})>0);

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($lm) = LISTING::MSGS->new($USERNAME,logfile=>"~/amazon-%YYYYMM%.log",'stderr'=>($params{'trace'})?1:0);
	if (not &DBINFO::task_lock($USERNAME,"amazon-sync",(($params{'unlock'})?"PICKLOCK":"LOCK"),'LOCK_LIMIT'=>14400)) {
		$lm->pooshmsg("STOP|+Could not obtain lock");
		}
	next if (not $lm->can_proceed());

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($userref) = &AMAZON3::fetch_userprt($USERNAME,undef);
	my ($so) = SYNDICATION->new($USERNAME,'AMZ','PRT'=>$userref->{'PRT'});
	my ($thesref) = &AMAZON3::fetch_thesaurus_detail($userref);
	# my ($ncprettyref,$ncprodref,$ncref) = &NAVCAT::FEED::matching_navcats($USERNAME,'AMAZON_THE');

	$userref->{'*SO'} = $so;
	$userref->{'*lm'} = $lm;

	my @PRODUCTS_XML = ();
	my @PRODUCT_INIT_CONTENTS = ();
	my @PRODUCT_UPDATE_CONTENTS = ();
	my @PRODUCT_DELETE_CONTENTS = ();

	my @RELATIONS_XML = ();
	my @RELATIONS_CONTENTS = ();

	my @IMAGES_XML = ();
	my @IMAGES_CONTENTS = ();
		
	my @PRICES_XML = ();
	my @PRICES_CONTENTS = ();

	my @INVENTORY_XML = ();
	my @INVENTORY_CONTENTS = ();

	my @SHIPPING_XML = ();
	my @SHIPPING_CONTENTS = ();

	## NOTE: the AMAZON3::relationships should tell us who our dependents are - so we don't need code like this:
	my %CACHED_PRODUCTS = ();

	## limit 
	my $i = 80000;
	my ($sTB) = &ZOOVY::resolve_lookup_tb($USERNAME,$MID);
	my $pstmt = "select ID,PID,SKU,AMZ_PRODUCTDB_GMT,AMZ_FEEDS_DONE,AMZ_FEEDS_TODO,AMZ_FEEDS_ERROR 
			from $sTB where MID=$MID /* $USERNAME */ and AMZ_FEEDS_TODO>0 ";
	if ($params{'product'}) {	$pstmt .= " and PID=".$udbh->quote($params{'product'});	}
	# if ($params{'debug'}) {  limit 0,10"; }
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my %PROCESS = ();
	my %TRACKPIDS = ();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		
		if ($params{'feed'}) {
			if (not defined $AMAZON3::BW{ $params{'feed'} }) {
				die("Sorry but AMAZON3::BW{$params{'feed'}} is not defined - try again");
				}
			else {
				$lm->pooshmsg("APPLY TODO MASK: $params{'feed'}");
				$hashref->{'AMZ_FEEDS_TODO'} = ($hashref->{'AMZ_FEEDS_TODO'}&$AMAZON3::BW{ $params{'feed'} });
				}
			}

		if (($hashref->{'AMZ_FEEDS_ERROR'} & $AMAZON3::BW{'init'})>0) {
			## if the product has an init error, it needs to be re-queued or cleared before it will be resent
			$lm->pooshmsg("WARN|+SKU $hashref->{'SKU'} was not sent due to init error");
			$hashref->{'AMZ_FEEDS_TODO'} = 0;
			## TODO: implement a reaper here to cleanup old products stuck in this state.	
			}

		print STDERR "TODO:$hashref->{'AMZ_FEEDS_TODO'}\n";
		next if ($hashref->{'AMZ_FEEDS_TODO'} == 0);
		$hashref->{'ORIGIN'} = sprintf('AMZ_FEEDS_TODO[%d]',$hashref->{'AMZ_FEEDS_TODO'});

		$i--;
		# print Dumper($hashref);
		# print Dumper($hashref->{'PID'});
		if ($i > 0) {
			warn "Adding PID: $hashref->{'PID'} (SKU:$hashref->{'SKU'})\n";
			$TRACKPIDS{ $hashref->{'PID'} }++;
			$PROCESS{ $hashref->{'SKU'} } = $hashref;
			}
		elsif ($TRACKPIDS{ $hashref->{'PID'} }) {
			warn "Allowing SKU: $hashref->{'SKU'}\n";
			$PROCESS{ $hashref->{'SKU'} } = $hashref;
			}
		else {
			# warn "Ignoring: SKU:$hashref->{'SKU'}\n";
			}
		}
	$sth->finish();

	##
	##
	## PHASE1: PROCESS ALL SKUS, POPULATE: 
	##			@......_XML (ex: @PRODUCT_XML) 
	##			@......_CONTENTS (ex: @PRODUCT_INIT_CONTENTS, or @RELATIONS_XML)
	##	
	##
	$i = 0;
	my %PIDOBJECTS = ();
	
	my @PROCESS_SKUS = sort keys %PROCESS;
	my %CAN_WE_SHORTCIRCUIT_VARIATIONS = ();
	foreach my $SKU (@PROCESS_SKUS) {

		my $PID = $PROCESS{$SKU}->{'PID'};

		print "... PROCESSING SKU:$SKU PID:$PID SC=[$CAN_WE_SHORTCIRCUIT_VARIATIONS{$PID}]\n";
		next if ($CAN_WE_SHORTCIRCUIT_VARIATIONS{$PID});
		
		
		my $ID = $PROCESS{$SKU}->{'ID'};
		my $TODO = $PROCESS{$SKU}->{'AMZ_FEEDS_TODO'};
		my $DONE = $PROCESS{$SKU}->{'AMZ_FEEDS_DONE'};
		my $plm = $PROCESS{ $SKU }->{'*lm'} = LISTING::MSGS->new($USERNAME,'stderr'=>($params{'trace'})?1:0);

		my ($P) = $PIDOBJECTS{$PID};
		if (not defined $P) {
			($P) = $PIDOBJECTS{$PID} = PRODUCT->new($USERNAME,$PID);
			}
		if (not defined $P) {
			$plm->pooshmsg(sprintf("ISE|+PID:%s|+PRODUCT not in database",$PID));
			}
		elsif (($SKU =~ /\:/) && (not $P->skuref($SKU)) ) {
			$plm->pooshmsg(sprintf("ISE|+SKU:%s|+SKU '%s' is not valid option for Product '%s'",$SKU,$SKU,$PID));
			## NOTE: we should PROBABLY convert this to a delete, or at least an error
			}
		elsif (($SKU =~ /\:/) && ($P->grp_type() eq 'PARENT')) {
			$plm->pooshmsg(sprintf("ISE|+SKU:%s|+Product '%s' classified as GROUP CHILD, but SKU is '%s'",$SKU,$PID,$SKU));
			## NOTE: we should PROBABLY convert this to a delete, or at least an error
			}

		my $RELATIONS = [];
		my $ME = undef;

		if (not $plm->can_proceed()) {
			## wow.. bad shit already happened.
			}
		elsif (($TODO & $AMAZON3::BW{'deleted'})>0) {
			$ME = 'DELETED'; 
			$PROCESS{$SKU}->{'*P'} = $P;
			$PROCESS{$SKU}->{'ORIGIN'} = 'DELETED';
			}
		elsif ($P->fetch('amz:ts')==0) {
			## NOTE: CHILDREN **MIGHT** NEED TO IGNORE THE amz:ts setting, it's not important.
			$plm->pooshmsg(sprintf("ISE|PID:%s|+NOT ALLOWED TO SEND DUE TO amz:ts=%d",$P->pid(),$P->fetch('amz:ts')));
			$PROCESS{$SKU}->{'*P'} = $P;
			$PROCESS{$SKU}->{'ORIGIN'} = 'TS:0';
			# $PROCESS{$SKU}->{'ERROR'} = sprintf("NOT ALLOWED TO SEND DUE TO amz:ts=%d",$P->fetch('amz:ts'));
			}
		elsif (not defined $P) {
			$plm->pooshmsg("ISE|+PRODUCT OBJECT NOT VALID");
			$PROCESS{$SKU}->{'ORIGIN'} = 'NO_PROD_OBJ';
			# $PROCESS{$SKU}->{'ERROR'} = "PRODUCT OBJECT NOT VALID";
			}
		else {
			$PROCESS{$SKU}->{'*P'} = $P;
			$PROCESS{$SKU}->{'ORIGIN'} = 'STD-ADD';
			($RELATIONS) = &AMAZON3::relationships($P);
			$ME = (shift @{$RELATIONS})->[0];	## the first element is our descriptor
			}

		if ($params{'trace'}) {
			print "processing (from db) ID:$ID SKU:$SKU PID:$PID (*P PID IS: ".$P->pid().") TODO:$TODO DONE:$DONE ME:$ME\n";
			}
		##
		## phase1: figure out which set of SKU's we're dealing with
		##		
		my @PROCESS_ALSO = ();
		if (not $plm->can_proceed()) {
			## bad shit already happened.
			}
		elsif ($ME eq 'DELETED') {
			## a special case for a product where we're going to process a delete.
			}
		elsif ($ME eq 'INVALID-GROUPING') {
			$plm->pooshmsg("ERROR|SKU:$SKU|+Has invalid grouping child/parent relationships and is corrupt.");
			}
		elsif ($ME eq 'INVALID-OPTIONS') {
			$plm->pooshmsg("ERROR|SKU:$SKU|+Has invalid inventoriable option configuration.");
			}
		elsif ($ME eq 'BASE') {
			}
		elsif ($ME eq 'CHILD') {
			my $PARENT = '';
			foreach my $REL (@{$RELATIONS}) {
				if ($REL->[0] eq 'PARENT') { $PARENT = $REL->[1]; }
				}
			$CAN_WE_SHORTCIRCUIT_VARIATIONS{$PARENT}++;	## HUGE SPEED INCREASE for products which have a lot of variations
		
			if ($PARENT eq '') {
				$plm->pooshmsg("SKIP|SKU:$SKU|+CHILD has INVALID PARENT (was not processed)");
				}
			elsif ($PROCESS{$PARENT}) {
				## we're also already processing the parent, so this is fine.
				}
			else {
				## we can't INIT a child that doesn't have a parent being sent up.
				my $pstmt = "select AMZ_FEEDS_DONE from  $sTB where MID=$MID /* $USERNAME */ and SKU=".$udbh->quote($PARENT);
				my ($PARENT_DONE) = $udbh->selectrow_array($pstmt);
				if (($PARENT_DONE & 3)>0) {
					## the parent product record has been sent and therefore we can safely proceed with the child.
					## NOTE: eventually we might want to check TODO/WAIT for 3 on the parent -- and if they aren't set
					## 		then RESET the parent to make sure it gets sent so the child doesn't block forever and ever.
					##			honestly - this should *NEVER* happen so I'm not going to write code for it, but in case it
					##			it does happen, AND it -should- happen (meaning it's not a bug someplace else) then this would
					##			be an easy way to solve the following:  parent_done(-3) & todo(3+)
					}
				else {
					$plm->pooshmsg("SKIP|TODO:$TODO|PARENT_DONE:$PARENT_DONE|SKU:$SKU|+Cannot INIT CHILD directly please remove/re-add the PARENT (was not processed)");
					}
				}
			}
		elsif ($ME eq 'XFAMILY') {
			foreach my $REL (@{$RELATIONS}) {
				if ($REL->[0] eq 'XPRODUCT') {
					## with XFAMILY we send grandparents->variation (parent->child->variation) so this is ignored intentionally.
					my ($PID) = &PRODUCT::stid_to_pid($REL->[1]);
					my $xP = $CACHED_PRODUCTS{$PID};

					my $RESULTSTR = undef;
					if (not defined $xP) { 
						$xP = $CACHED_PRODUCTS{$PID} = PRODUCT->new($USERNAME,$REL->[1]); 
						}
					if (not defined $xP) {
						$RESULTSTR = sprintf("ERROR|SKU:$SKU|+XFAMILY RELATION %s could not be loaded from database",$REL->[1]);
						}
					elsif ($xP->fetch('amz:ts')==0) {
						$RESULTSTR = sprintf("ERROR|SKU:$SKU|+XFAMILY RELATION %s NOT ALLOWED TO SEND DUE TO amz:ts=%d",$REL->[1],$P->fetch('amz:ts'));
						}

					if ($RESULTSTR) {
						$plm->pooshmsg($RESULTSTR);
						# $PROCESS{$SKU}->{'ERROR'} = $RESULTSTR;
						}
					else {
						push @PROCESS_ALSO, [ $PID, $xP ];
						}
					}
				elsif ($REL->[0] eq 'XSKU') {
					}
				}
			}
		elsif ($ME eq 'CONTAINER') {
			foreach my $REL (@{$RELATIONS}) {
			# print "ME:$ME $REL->[0] $REL->[1]\n";

				if ($REL->[0] eq 'VARIATION') {  ## variations
					if (defined $PROCESS{$REL->[1]}) {
						}
					else {
						push @PROCESS_ALSO, [ $REL->[1], $P ];
						}
					}
				elsif ( ($REL->[0] eq 'CHILD') && (($REL->[1] eq $SKU) || ($REL->[1] eq '')) ) {
					## catch a product that has itself listed in zoovy:grp_children
					$plm->pooshmsg("ERROR|SKU:$SKU|INVALID DATA - $SKU is GROUP CONTAINER that references itself as a CHILD");
					}
				elsif ($REL->[0] eq 'CHILD') {
					my ($PROCESS_PID) = &PRODUCT::stid_to_pid( $REL->[1] );
					if ($PROCESS_PID eq $P->pid()) {
						## we're processing the same product record (ex: variation) .. so there is no need to load again
						## NOTE: not sure that this line is ever actually reached.
						push @PROCESS_ALSO, [ $REL->[1], $P ]; die(); 	# can safely remove the die,but not sure if the line is ran.
						}
					else {
						push @PROCESS_ALSO, [ $REL->[1], undef ];
						}
					}
				elsif ($REL->[0] eq 'ORPHAN') {
					push @PROCESS_ALSO, [ $REL->[1], $P ];
					}
				elsif ($REL->[0] eq 'PRODUCT') {
					## HUGE SPEED INCREASE for products which have a lot of variations
					## WHY WE SHORTCIRCUIT: 
					##	 -- there is no point checking the variation peers for a variation
					##		ex: creating a new product with lot of inv. options causes each inv. opt to sync, and to compute it's
					##		own peers/parent/children.
					##		  when we *KNOW* we're already processing the parent (since it will always bring its children)
					##		  that just makes some items like swimsuits (beachmart SU2BLT65) might have like 486 options
					##		if each variation checks each other variation thats 486*486 or 236,196 which is a lot of wasted
					##	 	cycles .. once we know a parent of a variation is being processed we can skip this.. 
					##		now i probably didn't think of some edge case where avoiding all this needeless processing is
					##		going to break something, but we cannot allow the situation above to continue, it ran app8 out
					##		of diskspace, caused me (brian) a lot of heartburn on oct 25th, 2012. so don't remove this even
					##		if you think it's a good idea without coming up with a plan to handle the situation above.
					if ($ME eq 'CONTAINER') {
						$CAN_WE_SHORTCIRCUIT_VARIATIONS{$PID}++;	
						}
					# warn "Already got $REL->[1] (in PROCESS)\n";
					}
				}
			}
		else {
			# $PROCESS{$SKU}->{'ERROR'} = "ISE|PID:$PID|SKU:$SKU|+Unknown relationship perspective:$ME (was not processed)";
			$plm->pooshmsg("ISE|SKU:$SKU|+Unknown relationship perspective:$ME (was not processed)");
			}

		#if ($PROCESS{$SKU}->{'ERROR'}) {
		#	warn($PROCESS{$SKU}->{'ERROR'});
		#	}

		##
		## phase1.2: amend the process queue with skus that we're related to.
		##
		if (($TODO & $AMAZON3::BW{'init'})>0) {
			## so if we're waiting on init (and we're going to hold for init) then we should also also turn on 
			## ***ONLY*** 'init' todo for other products in @PROCESS_ALSO because they might NOT be waiting for init
			## ex: AMZ_FEEDS_DONE&1  then they're going to transmit each time the app is run.
			## this is totally safe since everything inevitably ends up waiting on init anyway.
			$TODO = ($TODO & $AMAZON3::BW{'init'}|$AMAZON3::BW{'products'});
			}

		foreach my $set (@PROCESS_ALSO) {
			## set[0] = sku to process
			## set[1] = *P for sku
			my ($processSKU,$processP) = @{$set};
			if ($processSKU eq '') {
				## we don't process blank SKU's (wtf) .. this line should *NEVER* be reached it indicates a product
				## probably references itself in a new and exciting way.
				print Dumper($SKU,$ME,\@PROCESS_ALSO,$plm);
				die();
				}

			my ($processPID) = &PRODUCT::stid_to_pid($processSKU);
			if (not defined $processP) {
				$processP = PRODUCT->new($USERNAME,$processSKU);
				}

			if (defined $PROCESS{$processSKU}) {
				## already in PROCESS				
				$PROCESS{$processSKU}->{'AMZ_FEEDS_TODO'} |= $TODO; # make sure we have the same TODO tasks as our parent (plus any of our own)
				print "skip processing (already queued) SKU=$processSKU TODO:$PROCESS{$processSKU}->{'AMZ_FEEDS_TODO'} (focus=$SKU)\n";
				}
			elsif (defined $PROCESS{$processPID}) {
				## same product, but different sku 
				print "skip processing (already queued) PID=$processPID (focus=$SKU)\n";
				my %copy = %{$PROCESS{$SKU}};
				$copy{'SKU'}=$processSKU;
				$copy{'*P'} = $processP;
				$copy{'*lm'} = LISTING::MSGS->new($USERNAME,'stderr'=>($params{'trace'})?1:0);
				$copy{'PID'}=$copy{'*P'}->pid();
				$copy{'RELATED'} = $SKU;
				$copy{'ORIGIN'} = "defined PROCESS{$processPID}";
				$copy{'ID'} = 0;
				$copy{'AMZ_FEEDS_TODO'} |= $TODO; # make sure we have the same TODO tasks as our parent (plus any of our own)
				print "processing (existing-relation) PID:$processPID TODO:$copy{'AMZ_FEEDS_TODO'} DONE:$copy{'AMZ_FEEDS_DONE'} ME:$ME (focus=$SKU)\n";
				$PROCESS{$processSKU} = \%copy;	 # copy previous hash
				}
			else {
				## this is PROBABLY a group child (that's what is SUPPOSED to trigger this code)
				my %new = ();
				$new{'SKU'} = $processSKU;
				$new{'*P'} = $processP;

				if ((not defined $processP) || (ref($processP) ne 'PRODUCT')) {
					print Dumper($processSKU,$processP);
					die();
					}

				$new{'*lm'} = LISTING::MSGS->new($USERNAME,'stderr'=>($params{'trace'})?1:0);
				$new{'PID'}= $new{'*P'}->pid();
				$new{'RELATED'} = $SKU;
				$new{'ORIGIN'} = "undefined PROCESS{$processPID}";
				$new{'ID'} = 0;
				my $pstmt = "select ID,AMZ_FEEDS_TODO,AMZ_FEEDS_DONE,AMZ_FEEDS_ERROR from  $sTB where MID=$MID /* $USERNAME */ and SKU=".$udbh->quote($processSKU);
				my ($dbref) = $udbh->selectrow_hashref($pstmt);
				if (not defined $dbref) {
					$plm->pooshmsg("ISE|+Could not load process_also SKU=$processSKU from database");
					}	
				else {
					## got data from database, copy into %new 
					foreach my $k (keys %{$dbref}) { $new{$k} = $dbref->{$k}; }
					}
				$new{'AMZ_FEEDS_TODO'} |= $TODO; # make sure we have the same TODO tasks as our parent (plus any of our own)
				print "processing (new-relation) PID:$processPID TODO:$new{'AMZ_FEEDS_TODO'} DONE:$new{'AMZ_FEEDS_DONE'} ME:$ME (focus=$SKU)\n";
				$PROCESS{$processSKU} = \%new;	 # new hash

				## NOTE: not sure if this is the right place to check and see if we can actually send this product.. 
				##			and if we can't, not sure what to do next .. probably error out the parent and flag it to not send.
				}

			}
		}

	##
	## SANITY: at this point EVERY SINGLE SKU that will be processed is in %PROCESS -- NO EXCEPTIONS!
	##

	#foreach my $SKU (sort keys %PROCESS) {
	#	print sprintf("%35s\tTODO:%d\n",$SKU,$PROCESS{$SKU}->{'AMZ_FEEDS_TODO'});
	#	}

	##
	## SANITY: at this point if there is a high level (non-feed specific) error in the product we've flagged it
	##				in the $plm object, any other errors that occur below this line MUST be associated with a specific feed.
	##




	my @SKU_POST_PROCESS_UPDATES = ();
	foreach my $SKU (sort keys %PROCESS) {
		print Dumper($SKU);

		my $P = $PROCESS{$SKU}->{'*P'};
		if (defined $P) {
			## happy times
			}
		else {
			## hmm.. we don't have *P for the variation, check the parent, or it might a grouped item.
         ## so this code applies for TWO reasons!
         ##              1. it has options (hence the old $SKU =~ /:/ check)
         ##              2. it's a parent and we were loaded from our child.
         ##              the #2. reason is why bob @ zephyr's syndication didn't work for over a year
         ##              so don't fucking add any *if* variation code without consulting that use case.
			my ($PID) = PRODUCT::stid_to_pid($SKU);
			if ((not defined $P) && (defined $PROCESS{$PID})) {
				$P = $PROCESS{$PID}->{'*P'};
				}
			if ((not defined $P) && (defined $PIDOBJECTS{$PID})) {
				$P = $PIDOBJECTS{$PID};
				}
			if ((not defined $P) && (not defined $PIDOBJECTS{$PID})) {
				$P = $PIDOBJECTS{$PID} = PRODUCT->new($USERNAME,$PID,'create'=>0);
				}
			}

		my $plm = $PROCESS{$SKU}->{'*lm'};
		# will not be set for all but 1 of group

		my $CANNOT_PROCESS = 0;
#		next if ((defined $params{'product'}) && ($P->pid() ne $params{'product'}));
		
		if (not defined $plm) {
			($plm) = LISTING::MSGS->new($USERNAME,'stderr'=>($params{'trace'})?1:0);			
			$plm->pooshmsg("WARN|SKU:$SKU|+Had to create new *msgs in PROCESS loop");
			}

		## do some validation validation
		if (not $plm->can_proceed()) {
			}
		elsif (not defined $P) {
			## 9/12/12 - not sure why but sometimes RELATED/ORIGIN in PROCESS{$SKU}-> is not set.
			$plm->pooshmsg(sprintf("ISE|RELATED:%s|ORIGIN:%s|+SKU:$SKU did not have a PRODUCT object",$PROCESS{$SKU}->{'RELATED'},$PROCESS{$SKU}->{'ORIGIN'})); 
			}

		if ($plm->can_proceed()) {
			## good to go, otherwise .. 
			}
		elsif ( my ($thiserr) = $plm->had(['ISE','PAUSE','END','HALT','STOP','WAIT','ERROR'])) {
			# $so->suspend_sku($SKU,0,$thiserr->{'+'});
			if ($plm->had(['ISE'])) {
				## on an ISE set BLOCKED ERROR bit high and all other feeds (TODO) off, so this won't be sent this again.
				my ($TX) = TXLOG->new(); 
				$plm->append_txlog($TX,'blocked');
				&AMAZON3::item_set_status($userref,$SKU,['=this.fatal_error'],'TS'=>1,'+ERROR'=>$TX->serialize());
				}
			$PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} = 0;
			}
		else {
			## this line should never be reached.
			$plm->pooshmg("ISE|+unhandled high level error in sync.pl (tlsnbr)");
			my ($thiserr) = $plm->had(['ISE']);
			$PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} = 0;
			}
		$lm->merge($plm,'_log'=>1,'_refid'=>$SKU);


		if ( ($PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} & $AMAZON3::BW{'deleted'}) > 0) { 
			## delete
			my ($xplm) = LISTING::MSGS->new($USERNAME,'stderr'=>($params{'trace'})?1:0);
			my $MSGID = 0;
			my $xml = '';
			require XML::Writer;
			my $writer = new XML::Writer(OUTPUT => \$xml, UNSAFE=>1);
			$writer->startTag("Message");
			$writer->dataElement("MessageID",$MSGID = scalar(@PRODUCTS_XML)+1);
			$writer->dataElement("OperationType","Delete");
			$writer->startTag("Product");
			$writer->dataElement("SKU",$SKU);
			$writer->endTag("Product");
			$writer->endTag("Message");
			$writer->raw("\n");
			$writer->end();

			#my $deletexml = XML::Smart->new();
			#$deletexml = $deletexml->{'Message'};
			#$deletexml->{'MessageID'}->content($MSGID = scalar(@PRODUCTS_XML)+1);
			#$deletexml->{'OperationType'}->content('Delete');
			#$deletexml->{'Product'}{'SKU'}->content($SKU);
			#$deletexml =~ s/^<\?(.*)\?>$//mg;
			# my $xml = $deletexml->data(nometagen=>1,noheader=>1);
			push @PRODUCTS_XML, $xml;
			push @PRODUCT_DELETE_CONTENTS, [ $MSGID, $SKU ];
			$xplm->pooshmsg("SUCCESS|+Did DELETE ($MSGID)");
			my ($TX) = TXLOG->new(); 
			$xplm->append_txlog($TX,'delete');
			push @SKU_POST_PROCESS_UPDATES, [ $SKU, '=this.delete_sent', $TX->serialize() ];

			if ( ($PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} & ($AMAZON3::BW{'init'} | $AMAZON3::BW{'products'} | $AMAZON3::BW{'inventory'})) > 0) {
				## WTF: THIS CODE IS HERE SO WHEN DELETE IS TURNED ON, AND SO ARE OTHER FEEDS (EX:INIT) - 
				## *** THIS SHOULD NEVER HAPPEN *** BUT APPARENTLY IT DOES -- SO WE LOG THE ERROR, AND THEN "FIX" THE PRODUCT
				## NOT SURE HOW *EXACTLY* THIS HAPPENS (IT IS AN INVALID STATE), BUT IF WE DON'T DO THIS WE END UP STOP+DIE
				## WHEN WE GO TO DO PRODUCTS LATER ON (SINCE AMZ:TS will be ZERO AND THAT IS A STOP+DIE CONDITION)
				$lm->pooshmsg("WARN|SKU:$SKU|+Delete found identity crisis AMZ_FEEDS_TODO:$PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} - turning off other feeds.");
				$PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} = $AMAZON3::BW{'deleted'};
				}

			$lm->merge($xplm,'_log'=>1,'_refid'=>"delete~$SKU");
			}	

		##
		## PRODUCT RECORD (init, update, delete)
		##

		if ($params{'force'}) { $PROCESS{$SKU}->{'AMZ_FEEDS_DONE'} |= $AMAZON3::BW{'init'}; }
		print 'FEEDS_TODO: '.Dumper($PROCESS{$SKU}->{'AMZ_FEEDS_TODO'});		

		if (($PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} & ($AMAZON3::BW{'init'}|$AMAZON3::BW{'products'})) > 0) { 
			## INIT+PRODUCTS
			my $CONTAINSREF = undef;
			if (($PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} & $AMAZON3::BW{'init'})==0) {
				$plm->pooshmsg("DEBUG|SKU:$SKU|+storing content in update todo=$PROCESS{$SKU}->{'AMZ_FEEDS_TODO'}");
				$CONTAINSREF = \@PRODUCT_UPDATE_CONTENTS;
				}
			else {
				$plm->pooshmsg("DEBUG|SKU:$SKU|+storing content in init");
				$CONTAINSREF = \@PRODUCT_INIT_CONTENTS;
				}
			(my $xplm,my $prodxml) = &AMAZON3::create_skuxml($userref,$SKU,$P,'@xml'=>\@PRODUCTS_XML,'%THESAURUSREF'=>$thesref,
				'@CONTENTS'=>$CONTAINSREF,
				);

			my $VERB = '';
			if ( $xplm->had(['ISE','ERROR']) ) {
				$VERB = '+products.fail';
				if ($PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} & $AMAZON3::BW{'init'}) {
					$VERB = '+init.fail';
					}
				if ($xplm->had('ISE')) {
					&ZOOVY::confess($userref->{'USERNAME'},"PRODUCT ".$P->pid()." SKU $SKU ISE\n".Dumper($xplm),justkidding=>1);
					}
				}
			elsif ($xplm->had('STOP')) {
				## the product was not sent, it won't be sent, so let's flag it accordingly.
				$VERB = '=this.will_not_be_sent';
				}
			elsif ($xplm->had('SKIP')) {
				## the product was not sent, it won't be sent, so let's flag it accordingly.
				$VERB = '=init.stop'; 
				}
			elsif ($xplm->had('SUCCESS')) {
				## success
				## we will always send a +products.sent, but if this was an init then we'll also send a +this.create
				if ( ($PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} & $AMAZON3::BW{'init'}) == $AMAZON3::BW{'init'}) {
					## note: init should ONLY be triggered by this.create_please 
					$VERB = '=this.create_sent';
					}
				else {
					$VERB = '+products.sent';
					}
				}
			#elsif ($xplm->had('STOP')) {
			#	## success, but well.. can't really say.
			#	print Dumper($xplm->as_string());
			#	open F, ">/tmp/stop";
			#	print F Dumper($xplm);
			#	close F;
			#	die("$SKU why did we get here?");
			#	}
			else {
				$xplm->pooshmsg("ISE|+Totally unhandled/unexpected case on product feed");
				$VERB = '=init.fail';
				}			
			
			
			my ($TX) = TXLOG->new(); $xplm->append_txlog($TX,'products');
			push @SKU_POST_PROCESS_UPDATES, [ $SKU, $VERB, $TX->serialize() ];
			$lm->merge($xplm,'_log'=>1,'_refid'=>"products~$SKU");
			}


		##
		## IMAGES
		##
		if (($PROCESS{$SKU}->{'AMZ_FEEDS_DONE'} & $AMAZON3::BW{'init'})==0) {
			## NEED TO INIT BEFORE WE CAN PROCESS IMAGES
			$plm->pooshmsg("PAUSE|SKU:$SKU|Images not processed (wait on init)");
			}
		elsif (($PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} & $AMAZON3::BW{'images'})>0) {
			## IMAGES
			(my $xplm, my $imgxml) = &AMAZON3::create_imgxml($userref,$SKU,$P,'@xml'=>\@IMAGES_XML,'@CONTENTS'=>\@IMAGES_CONTENTS);

			my $VERB = '';
			if ($xplm->had(['SUCCESS'])) { $VERB = '+images.sent'; }
			elsif ($xplm->had(['STOP','SKIP'])) { $VERB = '+images.stop'; }
			else { 
				$VERB = '+images.fail'; 
				print sprintf("SKU[$SKU] IMAGES.FAILED CAUSE:\n%s\n",$xplm->as_string());
				}

			my ($TX) = TXLOG->new(); $xplm->append_txlog($TX,'images');
			if ($VERB eq '+images.fail') {	print "SKU[$SKU] IMAGES_FAILED CAUSE:\n".$xplm->as_string(); }
			push @SKU_POST_PROCESS_UPDATES, [ $SKU, $VERB, $TX->serialize() ];
			$lm->merge($xplm,'_log'=>1,'_refid'=>"images~$SKU");
			# print Dumper({'SKU'=>$SKU,'*LM'=>$xplm});	
			}


		##
		## PRICES
		##
		if (($PROCESS{$SKU}->{'AMZ_FEEDS_DONE'} & $AMAZON3::BW{'init'})==0) {
			## NEED TO INIT BEFORE WE CAN PROCESS PRICES
			$plm->pooshmsg("PAUSE|SKU:$SKU|Prices not processed (wait on init)");
			}
		elsif (($PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} & $AMAZON3::BW{'prices'})>0) {
			## PRICES
			(my $xplm, my $pricexml) = &AMAZON3::create_pricexml($userref,$SKU,$P,'@xml'=>\@PRICES_XML,'@CONTENTS'=>\@PRICES_CONTENTS);

			my $VERB = '';
			if ($xplm->had(['SUCCESS'])) { $VERB = '+prices.sent'; }
			elsif ($xplm->had(['STOP','SKIP'])) { $VERB = '+prices.stop'; }
			else { 
				$VERB = '+prices.fail'; 
				print sprintf("SKU[$SKU] PRICES.FAILED CAUSE:\n%s\n",$xplm->as_string());
				}

			my ($TX) = TXLOG->new(); $xplm->append_txlog($TX,'prices');
			push @SKU_POST_PROCESS_UPDATES, [ $SKU, $VERB, $TX->serialize() ];
			$lm->merge($xplm,'_log'=>1,'_refid'=>"prices~$SKU");
			}


		##
		## INVENTORY
		##
		if (($PROCESS{$SKU}->{'AMZ_FEEDS_DONE'} & $AMAZON3::BW{'init'})==0) {
			## NEED TO INIT BEFORE WE CAN PROCESS INVENTORY
			$plm->pooshmsg("PAUSE|SKU:$SKU|Inventory not processed (wait on init)");
			}
		elsif (($PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} & $AMAZON3::BW{'inventory'})>0) {
			## PRICES
			my ($xplm) = LISTING::MSGS->new($USERNAME,'stderr'=>($params{'trace'})?1:0);
			($xplm, my $invxml) = &AMAZON3::create_inventoryxml($userref,$SKU,$P,'*LM'=>$xplm,'@xml'=>\@INVENTORY_XML,'@CONTENTS'=>\@INVENTORY_CONTENTS);
			my $VERB = ($xplm->had(['STOP','SUCCESS']))?'+inventory.sent':'+inventory.fail';
			if ($VERB eq '+inventory.fail') {	print "SKU[$SKU] INVENTORY_FAILED CAUSE:\n".$xplm->as_string(); }
			my ($TX) = TXLOG->new(); $xplm->append_txlog($TX,'inventory');
			push @SKU_POST_PROCESS_UPDATES, [ $SKU, $VERB, $TX->serialize() ];
			$lm->merge($xplm,'_log'=>1,'_refid'=>"inventory~$SKU");
			}



		##
		## RELATIONS
		##
		if (($PROCESS{$SKU}->{'AMZ_FEEDS_DONE'} & $AMAZON3::BW{'init'})==0) {
			## NEED TO INIT BEFORE WE CAN PROCESS RELATIONSHIPS
			$plm->pooshmsg("PAUSE|SKU:$SKU|Relationships not processed (wait on init)");
			}
		elsif (($PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} & $AMAZON3::BW{'relations'})>0) {
			(my $xplm, my $relxml) = &AMAZON3::create_relationxml($userref,$SKU,$P,'@xml'=>\@RELATIONS_XML,'@CONTENTS'=>\@RELATIONS_CONTENTS);

			my $VERB = '';
			if ($xplm->had(['SUCCESS'])) { $VERB = '+relations.sent'; }
			elsif ($xplm->had(['STOP','SKIP'])) { $VERB = '+relations.stop'; }
			else { 
				$VERB = '+relations.fail'; 
				print sprintf("SKU[$SKU] RELATIONS.FAILED CAUSE:\n%s\n",$xplm->as_string());
				}

			my ($TX) = TXLOG->new(); $xplm->append_txlog($TX,'relations');
			push @SKU_POST_PROCESS_UPDATES, [ $SKU, $VERB, $TX->serialize() ];
			$lm->merge($xplm,'_log'=>1,'_refid'=>"relations~$SKU");
			}

		##
		## SHIPPING
		##
		if (($PROCESS{$SKU}->{'AMZ_FEEDS_DONE'} & $AMAZON3::BW{'init'})==0) {
			## NEED TO INIT BEFORE WE CAN PROCESS SHIPPING
			$plm->pooshmsg("PAUSE|SKU:$SKU|Shipping not processed (wait on init)");
			}
		elsif (($PROCESS{$SKU}->{'AMZ_FEEDS_TODO'} & $AMAZON3::BW{'shipping'})>0) {
			(my $xplm, my $relxml) = &AMAZON3::create_shippingxml($userref,$SKU,$P,'@xml'=>\@SHIPPING_XML,'@CONTENTS'=>\@SHIPPING_CONTENTS);

			my $VERB = '';
			if ($xplm->had(['SUCCESS'])) { $VERB = '+shipping.sent'; }
			elsif ($xplm->had(['STOP','SKIP'])) { $VERB = '+shipping.stop'; }
			else { 
				$VERB = '+shipping.fail'; 
				print sprintf("SKU[$SKU] SHIPPING.FAILED CAUSE:\n%s\n",$xplm->as_string());
				}

			# print Dumper({'SKU'=>$SKU,'*LM'=>$xplm});	
			my ($TX) = TXLOG->new(); $xplm->append_txlog($TX,'shipping');
			push @SKU_POST_PROCESS_UPDATES, [ $SKU, $VERB, $TX->serialize() ];
			$lm->merge($xplm,'_log'=>1,'_refid'=>"shipping~$SKU");
			}	

		}


	


	##
	##
	## PHASE2: TRANSMIT XML
	##			@......_XML (ex: @PRODUCT_XML) 
	##			@......_CONTENTS (ex: @PRODUCT_INIT_CONTENTS, or @RELATIONS_XML)
	##	
	##

	# print Dumper(\@SKU_POST_PROCESS_UPDATES); 

	## TRANSMISSION LOG (NOT PRODUCT SPECIFIC)
	my ($tlm) = LISTING::MSGS->new($USERNAME,'stderr'=>($params{'trace'})?1:0);

	if (scalar(@PRODUCTS_XML)>0) {
		if ($params{'xml'}) { print 'PRODUCTS_XML: '.Dumper(\@PRODUCTS_XML); }

		## send products
		## push all skus that have passed validation into processing
		# print Dumper(\@PRODUCTS_XML);
		my ($DOCID,$ERROR) = AMAZON3::push_xml($userref,join("",@PRODUCTS_XML),'Product',$tlm);
		if ($DOCID>0) {
			if ($params{'contents'}) {
				print 'PRODUCT_UPDATE_CONTENTS: '.Dumper(\@PRODUCT_UPDATE_CONTENTS)."\n";
				print 'PRODUCT_INIT_CONTENTS: '.Dumper(\@PRODUCT_INIT_CONTENTS)."\n";
				print 'PRODUCT_DELETE_CONTENTS: '.Dumper(\@PRODUCT_DELETE_CONTENTS)."\n";
				}
			&AMAZON3::record_contents($udbh,$userref->{'USERNAME'},$DOCID,'init',\@PRODUCT_INIT_CONTENTS);
			&AMAZON3::record_contents($udbh,$userref->{'USERNAME'},$DOCID,'products',\@PRODUCT_UPDATE_CONTENTS);
			&AMAZON3::record_contents($udbh,$userref->{'USERNAME'},$DOCID,'deleted',\@PRODUCT_DELETE_CONTENTS);
			$tlm->pooshmsg("SUCCESS|DOCID:$DOCID|Transmitted product+init+delete feed");
			}
		else {
			$tlm->pooshmsg($ERROR);
			}
		}

	if (not $tlm->can_proceed()) {
		}
	elsif (scalar(@IMAGES_XML)>0) {
		if ($params{'xml'}) { print 'IMAGES_XML: '.Dumper(\@IMAGES_XML); }
		my ($DOCID,$ERROR) = AMAZON3::push_xml($userref,join("",@IMAGES_XML),'ProductImage',$tlm);
		if ($DOCID>0) {
			if ($params{'contents'}) { print 'IMAGES_CONTENTS: '.Dumper(\@IMAGES_CONTENTS)."\n"; }
			&AMAZON3::record_contents($udbh,$userref->{'USERNAME'},$DOCID,'images',\@IMAGES_CONTENTS);
			$tlm->pooshmsg("SUCCESS|DOCID:$DOCID|Transmitted images feed");
			}
		else {
			$tlm->pooshmsg($ERROR);
			}
		}

	if (not $tlm->can_proceed()) {
		}
	elsif (scalar(@PRICES_XML)>0) {
		if ($params{'xml'}) { print 'PRICES_XML: '.Dumper(\@PRICES_XML); }
		my ($DOCID,$ERROR) = AMAZON3::push_xml($userref,join("",@PRICES_XML),'Price',$tlm);
		if ($DOCID>0) {
			if ($params{'contents'}) { print 'PRICES_CONTENTS: '.Dumper(\@PRICES_CONTENTS)."\n"; }
			&AMAZON3::record_contents($udbh,$userref->{'USERNAME'},$DOCID,'prices',\@PRICES_CONTENTS);
			$tlm->pooshmsg("SUCCESS|DOCID:$DOCID|Transmitted  prices feed");
			}
		else {
			$tlm->pooshmsg($ERROR);
			}
		}

	if (not $tlm->can_proceed()) {
		}
	elsif (scalar(@INVENTORY_XML)>0) {
		if ($params{'xml'}) { print 'INVENTORY_XML: '.Dumper(\@INVENTORY_XML); }
		my ($DOCID,$ERROR) = AMAZON3::push_xml($userref,join("",@INVENTORY_XML),'Inventory',$tlm);
		if ($DOCID>0) {
			if ($params{'contents'}) { print 'INVENTORY_CONTENTS: '.Dumper(\@INVENTORY_CONTENTS)."\n"; }
			&AMAZON3::record_contents($udbh,$userref->{'USERNAME'},$DOCID,'inventory',\@INVENTORY_CONTENTS);
			$tlm->pooshmsg("SUCCESS|DOCID:$DOCID|Transmitted inventory feed");
			}
		else {
			$tlm->pooshmsg($ERROR);
			}
		}

	if (not $tlm->can_proceed()) {
		}
	elsif (scalar(@RELATIONS_XML)>0) {
		if ($params{'xml'}) { print 'RELATIONS_XML: '.Dumper(\@RELATIONS_XML); }
		print Dumper(\@RELATIONS_XML);
		my ($DOCID,$ERROR) = AMAZON3::push_xml($userref,join("",@RELATIONS_XML),'Relationship',$tlm);
		if ($DOCID>0) {
			if ($params{'contents'}) { print 'RELATIONS_CONTENTS: '.Dumper(\@RELATIONS_CONTENTS)."\n"; }
			&AMAZON3::record_contents($udbh,$userref->{'USERNAME'},$DOCID,'relations',\@RELATIONS_CONTENTS);
			$tlm->pooshmsg("SUCCESS|DOCID:$DOCID|Transmitted relations feed");
			}
		else {
			$tlm->pooshmsg($ERROR);
			}
		}

	if (not $tlm->can_proceed()) {
		}
	elsif (scalar(@SHIPPING_XML)>0) {
		if ($params{'xml'}) { print 'SHIPPING_XML: '.Dumper(\@SHIPPING_XML); }
		print Dumper(\@SHIPPING_XML);
		my ($DOCID,$ERROR) = AMAZON3::push_xml($userref,join("",@SHIPPING_XML),'Override',$tlm);
		if ($DOCID>0) {
			if ($params{'contents'}) { print 'SHIPPING_CONTENTS: '.Dumper(\@SHIPPING_CONTENTS)."\n"; }
			&AMAZON3::record_contents($udbh,$userref->{'USERNAME'},$DOCID,'shipping',\@SHIPPING_CONTENTS);
			$tlm->pooshmsg("SUCCESS|DOCID:$DOCID|Transmitted shipping feed");
			}
		else {
			$tlm->pooshmsg($ERROR);
			}
		}

	if (scalar(@{$tlm->msgs()})==0) {
		$tlm->pooshmsg("STOP|No documents transmitted");
		}

	if ($params{'status'}) {
		print Dumper(\@SKU_POST_PROCESS_UPDATES);
		}

	## finally, flag all the various documents as processed
	my $HAD_TRANSMISSION_ERRORS = ($tlm->can_proceed())?0:1;
	foreach my $line (@SKU_POST_PROCESS_UPDATES) {	
		my ($SKU,$VERB,$TXLOG) = @{$line};
		if (($HAD_TRANSMISSION_ERRORS) && ($VERB =~ /\.(delete_sent|sent)$/)) { 
			## if we had transmission errors, then don't process VERB's with .sent at the end.
			if ($params{'status'}) { print "*SKIPPED* SKU: $line->[0] $line->[1]\n"; }
			}
		else {
			## transmission errors don't affect us flagging problems as problems in the txlog
			if ($params{'status'}) { print "FLAGGED SKU: $line->[0] $line->[1]\n"; }
			&AMAZON3::item_set_status($userref, $line->[0], [ $line->[1] ], '+ERROR'=>$line->[2], 'TS'=>1 );
			}
		}
	$lm->merge($tlm);

	&DBINFO::task_lock($USERNAME,"amazon-sync","UNLOCK");
	&DBINFO::db_user_close();
	}





## need to send '1' to queue.pl to be considered a success
exit(1);

__DATA__

