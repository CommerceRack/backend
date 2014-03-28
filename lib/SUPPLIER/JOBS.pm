package SUPPLIER::JOBS;

use strict;

use lib "/backend/lib";
use Date::Calc qw (Day_of_Week Today Date_to_Days Localtime);
use DBINFO;
use TXLOG;
use strict;
use ORDER;
use ZOOVY;
use CUSTOMER;
use WHOLESALE;
use SUPPLIER;
use ZTOOLKIT;
use LISTING::MSGS;
use ZSHIP;
use TXLOG;
use URI::Split;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP::UserAgent;
use LWP::Simple;
use IO::Scalar;
use JSON::XS;
use XML::LibXSLT;
use XML::LibXML;
use Data::Dumper;


%SUPPLIER::JOBS::TASKS = (
	'TRACKING'=> \&SUPPLIER::JOBS::TRACKING,
	'INVENTORY'=> \&SUPPLIER::JOBS::INVENTORY,
	'PROCESS'=> \&SUPPLIER::JOBS::PROCESS,
	);



sub TRACKING {
	my ($S,$lm,%params) = @_;

	my ($USERNAME) = $S->username();
	my ($MID) = $S->mid();
	my ($CODE) = $S->code();

	if (not &ZOOVY::locklocal("supplychain.$USERNAME.$CODE")) {
		$lm->pooshmsg("STOP|+Cannot obtain lock");
		}


	return();
	}



################################################
##
##
##
sub INVENTORY {
	my ($S,$lm,%params) = @_;

	my ($USERNAME) = $S->username();
	my ($MID) = $S->mid();
	my ($CODE) = $S->code();

	if (not &ZOOVY::locklocal("supplychain.$USERNAME.$CODE")) {
		$lm->pooshmsg("STOP|+Cannot obtain lock");
		}

	##
	## INVENTORY
	##
	my $INVENTORY_CONNECTOR = $S->fetch_property('INVENTORY_CONNECTOR');
	if (($INVENTORY_CONNECTOR eq 'NONE') || ($INVENTORY_CONNECTOR eq '')) {
		## NOTHING TO DO HERE
		$lm->pooshmsg("INFO|+NO INVENTORY");
		$S->save_property('INVENTORY_NEXT_TS',0);
		}
#	elsif ($S->fetch_property('inv.updateauto')==0) {
#		## no auto-updates, nothing to do here.
#		$lm->pooshmsg("INFO|+INV AUTOUPDATE DISABLED");
#		}
	elsif ($INVENTORY_CONNECTOR eq 'GENERIC') {
		require SUPPLIER::GENERIC;
		my $ts = time();
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select unix_timestamp(INVENTORY_NEXT_TS) from SUPPLIERS where MID=$MID and CODE=".$udbh->quote($S->id());
		my ($nextts) = $udbh->selectrow_array($pstmt);
		if ($nextts > $ts) {
			print "NOT TIME FOR INVENTORY\n";
			}
		else {
			my ($JOBID,$lm) = SUPPLIER::GENERIC::update_inventory($S);
			my ($tx) = TXLOG->new();
			$lm->append_txlog($tx,'inv','ts'=>$ts);
			my $txlog  = $udbh->quote($tx->serialize());
			$pstmt = "update SUPPLIERS set INVENTORY_NEXT_TS=date_add(now(),interval 12 hour),INVENTORY_LOG=concat($txlog,INVENTORY_LOG) where MID=$MID and CODE=".$udbh->quote($S->id());
			print "$pstmt\n";
			$udbh->do($pstmt);
			}
		&DBINFO::db_user_close();
		}
	elsif ($INVENTORY_CONNECTOR eq 'FBA') {
		require SUPPLIER::FBA;
		SUPPLIER::FBA::inventory($S);
		}
	#elsif ($INVENTORY_MODE eq 'PARTNER' && $PARTNER eq 'ATLAST') {
	#	require SUPPLIER::ATLAST;
	#	($count,$error) = SUPPLIER::ATLAST::update_inventory($S);	
	#	}
	#elsif ($INVENTORY_MODE eq 'PARTNER' && $PARTNER eq 'DOBA') {
	#	require SUPPLIER::DOBA;
	#	my ($S) = SUPPLIER->new($USERNAME, $VENDOR);
	#
	#		my $params = SUPPLIER::decodeini($INIDATA);
	#		my $retailer_id = $params->{'.partner.retailer_id'};
	#		if ($retailer_id eq '') {
	#			$error = "bad supplier user=$USERNAME supplier=$VENDOR mode=$INVENTORY_MODE no retailer_id\n";
	#			}
	#
	#		if ($error eq '') {
	#			my $pstmt = "select id,xml from DOBA_CALLBACKS where retailer_id = ".$udbh->quote($retailer_id)." and callback_type = 'inventory_update' and processed_gmt = 0";
	#			my $sth = $udbh->prepare($pstmt);
	#			$sth->execute();
	#	
	#			while (my ($id,$xml) = $sth->fetchrow()) {
	#				print $xml."\n";
	#				print Dumper($S);
	#
	#				($count,$error) = SUPPLIER::DOBA::update_inventory($S,{xml=>$xml});	
	#
	#				DBINFO::insert( $udbh, 'DOBA_CALLBACKS', {
	#				USERNAME => $USERNAME,
	#				PROCESSED_GMT => time(),
	#				ERROR => $error,
	#				COUNT => $count,
	#				ID => $id
	#				},	key=>['ID'] );
	#			
	#				}
	#		
	#				$sth->finish();
	#			}
	#		}
	#elsif ($S->fetch_property('.inv.url') ne '') {
	## only update inv if merchant has configured the "Automate Nightly Update"
	#elsif ($S->fetch_property('.inv.url') ne '' && $S->fetch_property('.inv.updateauto')) {
	#		require SUPPLIER::GENERIC;
	#		($count,$error) = SUPPLIER::GENERIC::update_inventory($S);	
	#	}
	else {
		$lm->pooshmsg(sprintf("ISE|+unknown inventory connector '%s'",$INVENTORY_CONNECTOR));
		}	

	return();	
	}









##
##
##
sub PROCESS {
	my ($S,$lm,%params) = @_;

	my ($udbh) = &DBINFO::db_user_connect($S->username());

	my ($VENDOR) = $S->code();

	print "vendor: ".Dumper($VENDOR);

	my $qtVENDOR = $udbh->quote($VENDOR);
	my ($USERNAME) = $S->username();
	my ($MID) = $S->mid();

	my ($CODE) = $S->code();

	if (not &ZOOVY::locklocal("supplychain.$USERNAME.$CODE")) {
		$lm->pooshmsg("STOP|+Cannot obtain lock");
		}

	## UNLOCK
	my $pstmt = "update VENDOR_ORDERS set LOCK_GMT=0,LOCK_PID=0 where MID=$MID and VENDOR=$qtVENDOR and LOCK_GMT<".(time()-60)." and LOCK_PID>0";
	print STDERR $pstmt."\n";
	$udbh->do($pstmt);

	## download inventory
	## process confirmations


	##
	## process any new items
	##		NOTE: at some point we *really* ought to rewrite this so it's  SUPPLIER_ORDERID, SRC_ORDERID (or some type of SRC/DSN string) 
	##				and PO # .. currently OUROID is really the "PO Number"
	##
	my $t = time();
	my $ORDER_CONNECTOR = $S->fetch_property('ORDER_CONNECTOR');
	my @NEW_ORDERS = ();
   my $pstmt = "select * from INVENTORY_DETAIL where VENDOR_STATUS='NEW' and MID=$MID and VENDOR=$qtVENDOR";
	my $sthx = $udbh->prepare($pstmt);
	$sthx->execute();
	while ( my $VOITEMREF = $sthx->fetchrow_hashref() ) {
		## PHASE1: first, figure out what type of supplier we're working with and that tells us what we ought to do with the ORDER ITEMS
		##			  if we're going to process ORDERITEMS then we lookup the SUPPLIER OUR_ORDERID (or create one) then  push onto @NEW_ORDERS

		
		my $PONUMBER = undef;
		
		if ($VOITEMREF->{'VENDOR_ORDER_DBID'}>0) {
			## we already have this item on a PO.
			$lm->pooshmsg("INFO|+Item $VOITEMREF->{'SKU'} is on SUPPLIERPO ID#: $VOITEMREF->{'VENDOR_ORDER_DBID'}");
			}
		elsif ($S->fetch_property('FORMAT') eq 'NONE') {
			$pstmt = "update INVENTORY_DETAIL set VENDOR_STATUS='FINISHED' where VENDOR_STATUS='NEW' and MID=$MID and VENDOR=$qtVENDOR and ID=$VOITEMREF->{'ID'} /* REASON: FORMAT=NONE */";
			print STDERR "SUPPLIER FORMAT: NONE (ie no dispatch)\n".$pstmt."\n";
			$udbh->do($pstmt);
			}
		elsif ($S->fetch_property('FORMAT') =~ 'STOCK') {
			## make sure we have an open stock order created, if not create it
			## do we have an existing OPEN order?? if so, lets use that!
			my $i = 0;		
			while ( not defined $PONUMBER ) {
				my $pstmt = "select OUR_ORDERID from VENDOR_ORDERS where MID=$MID and STATUS='OPEN' and VENDOR=$qtVENDOR order by ID desc";
				print STDERR "$pstmt\n";
				($PONUMBER) = $udbh->selectrow_array($pstmt);
			
				if (defined $PONUMBER) {
					$lm->pooshmsg("WARN|+Found an open PO #$PONUMBER (so we'll add to this)");
					}
				else {
					my $TRY_PONUMBER = sprintf("%8s-%6s-%s",&ZTOOLKIT::pretty_date(time(),-2),$S->id(),&ZTOOLKIT::AZsequence($i++));
					## note: stock orders #'s are unique across all suppliers, but also contain supplier code to make them 
					## eventually it might make more sense to pull this from a global sequence
					my $pstmt = "select ID from VENDOR_ORDERS where MID=$MID and OUR_ORDERID=".$udbh->quote($TRY_PONUMBER)." and VENDOR=$qtVENDOR order by ID desc";
					print STDERR $pstmt."\n";
					my ($ID) = $udbh->selectrow_array($pstmt);
					if (not defined $ID) {
						## we found a TRY that doesn't exist, so lets try and create it.
						my $pstmt = &DBINFO::insert($udbh,'VENDOR_ORDERS',{
							'USERNAME'=>$USERNAME,
							'MID'=>$MID,
							'VENDOR'=>$VENDOR,
							'OUR_VENDOR_PO'=>$TRY_PONUMBER,
							'*CREATED_TS'=>'now()',
							'STATUS'=>'OPEN',
							'FORMAT'=>'STOCK',
							},'verb'=>'insert','sql'=>1);
						print STDERR "$pstmt\n";
						$udbh->do($pstmt);
						}
					}
				if ($i > 1000) {
					## something really bad happened here -- this is endlessly looping.
					die();
					}
				}
			}	
		elsif ($S->fetch_property('FORMAT') =~ /^(FULFILL|DROPSHIP|FBA)$/) {
			## see if we have an order for this specific order created, if not - create it.
			## for fulfillment orders the supplier orderid is always the internal order # plus an A or B.
			## for now PO numbers will always be the same as the OUR_ORDERID which created the item.
			my $qtORDERID = $udbh->quote($VOITEMREF->{'OUR_ORDERID'});
			my $pstmt = "select STATUS,OUR_VENDOR_PO from VENDOR_ORDERS where MID=$MID and VENDOR=$qtVENDOR and OUR_ORDERID=$qtORDERID order by ID desc";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my ($STATUS,$THIS_PONUMBER) = $sth->fetchrow() ) {
				if ($STATUS ne 'OPEN') {
					## can't use supplier order $VENDOR_ORDER_DBID because it's not open.
					$lm->pooshmsg("ISE|+OrderID(PO) $PONUMBER is $STATUS (should be OPEN)");
					}
				else {
					$PONUMBER = $THIS_PONUMBER;
					}
				}
			$sth->finish();

			if (not defined $PONUMBER) {
				my $pstmt = &DBINFO::insert($udbh,'VENDOR_ORDERS',{
					'USERNAME'=>$USERNAME,
					'MID'=>$MID,
					'VENDOR'=>$VENDOR,
					'OUR_VENDOR_PO'=>$VOITEMREF->{'OUR_ORDERID'},
					'OUR_ORDERID'=>$VOITEMREF->{'OUR_ORDERID'},
					'*CREATED_TS'=>'now()',
					'STATUS'=>'OPEN',
					'FORMAT'=>$S->fetch_property('FORMAT'),
					},'verb'=>'insert','sql'=>1);
				print STDERR "$pstmt\n";
				$udbh->do($pstmt);		

				$pstmt = "select OUR_VENDOR_PO from VENDOR_ORDERS where MID=$MID and VENDOR=$qtVENDOR and OUR_VENDOR_PO=$qtORDERID";
				($PONUMBER) = $udbh->selectrow_array($pstmt);
				}

			if (not defined $PONUMBER) {
				$lm->pooshmsg("ISE|+Could not allocate ORDERID:$qtORDERID");
				}			
			}
		else {
			$lm->pooshmsg(sprintf("ISE|+Unknown supplier FORMAT:%s",$S->fetch_property('FORMAT')));
			}

		if (defined $PONUMBER) {
			push @NEW_ORDERS, [ $PONUMBER, $VOITEMREF ];
			}
		else {
			## this is *FINE* if we're FORMAT=NONE otherwise this is very very very bad.
			}
		}
	$sthx->finish();
	if ($params{'limit'}>0) {
		$lm->pooshmsg(sprintf("DEBUG|+Have %d orders for NEW, reducing to %d for debug",scalar(@NEW_ORDERS),int($params{'limit'})));
		@NEW_ORDERS = splice(@NEW_ORDERS,0,int($params{'limit'}));
		}

	foreach my $resultset (@NEW_ORDERS) {
		my ($PONUMBER, $rowref) = @{$resultset};
		## old MODE=CREATE
		## create orders for new items, or add items to existing OPEN order (if in STOCK mode)
		##
		
		## check_stock_limits set to yes for STOCK orders
		## my $orderref = SUPPLIER::create_order($USERNAME,$S->id(),$FORMAT);	

		## get a distinct SRCORDER		
		my $pstmt = "select ID from VENDOR_ORDERS where MID=$MID and VENDOR=$qtVENDOR and OUR_VENDOR_PO=".$udbh->quote($PONUMBER);
		print STDERR "$pstmt\n";
		my ($SUPPLIERPOID) = $udbh->selectrow_array($pstmt);

		if (defined $SUPPLIERPOID) {
			## make sure to include ID= or we'll set *way* too many orders
			my $pstmt = "update INVENTORY_DETAIL set VENDOR_ORDER_DBID=$SUPPLIERPOID,VENDOR_STATUS='ADDED' where ID=$rowref->{'ID'} and MID=$MID and VENDOR_STATUS='NEW' and VENDOR=$qtVENDOR";
			print STDERR "$pstmt\n";
			$udbh->do($pstmt);;	
			}
		}


	############################################################################################################
	##
	## automatically close orders IF POSSIBLE ..
	##	if we can't close the order, set WAIT_GMT to the next time we ought to check the order.
	##
	my $this_day = Date_to_Days(Today());
	## changed from ('OPEN') to ('OPEN','HOLD')
	$pstmt = "select * from VENDOR_ORDERS where STATUS='OPEN' and MID=$MID and VENDOR=$qtVENDOR";
	print "$pstmt\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my @ORDERS_OPEN = ();
	while ( my $openref = $sth->fetchrow_hashref() ) {
		push @ORDERS_OPEN, $openref;
		}
	$sth->finish();
	$lm->pooshmsg(sprintf("INFO|+Found %d open orders",scalar(@ORDERS_OPEN)));
	if ($params{'limit'}) {
		$lm->pooshmsg(sprintf("DEBUG|+Have %d orders for NEW, reducing to %d for debug",scalar(@ORDERS_OPEN),int($params{'limit'})));
		@ORDERS_OPEN = splice(@ORDERS_OPEN,0,int($params{'limit'}));
		}

	##
	foreach my $openref (@ORDERS_OPEN) {
		my ($SUPPLIERPOID) = ($openref->{'ID'});
	
		## what is the criteria for an order can be closed??
		## 	all the holddowns are true.
		print STDERR "/* PROCESSING OPEN ORDER PO ID: $SUPPLIERPOID CREATED: $openref->{'CREATED_TS'} */\n";

		my $STATUS = 'HOLD';		# the default is to require the merchant to CLOSE orders
		if (not defined $S) {
			$STATUS = 'CORRUPT';	# this isn't necessary
			}		
		elsif ($S->fetch_property('FORMAT') =~ /^(STOCK|FULFILL|DROPSHIP)$/) {
			## STOCK|FULFILL|DROPSHIP can auto
			if (int($S->fetch_property('.order.auto_approve'))>0) {
				$STATUS = 'CLOSED'; 
				}
			}		
		else {
			## hold everything else (NONE?) .. not sure what reaches this line.
			$STATUS = 'HOLD'; 
			}

		my $pstmt = "update VENDOR_ORDERS set STATUS=".$udbh->quote($STATUS)." where MID=$MID and STATUS='OPEN' and ID=".int($SUPPLIERPOID);
		print STDERR $pstmt."\n";
		$udbh->do($pstmt);
		}

	##
	## FORMAT + TRANSFER A SUPPLIER ORDER
	##
	$pstmt = "update VENDOR_ORDERS set LOCK_GMT=".time().",LOCK_PID=$$ where LOCK_PID=0 and DISPATCHED_TS=0 and STATUS='CLOSED' and MID=$MID and VENDOR=$qtVENDOR limit 40";
	print STDERR $pstmt."\n";
	$udbh->do($pstmt);

	$pstmt = "select * from VENDOR_ORDERS where LOCK_PID=$$ and STATUS='CLOSED' and DISPATCHED_TS=0 and MID=$MID and VENDOR=$qtVENDOR";
	if (($params{'verb'} eq 'debug') && ($params{'orderid'} ne '')) {
		$pstmt = "select * from VENDOR_ORDERS where OUR_ORDERID=".$udbh->quote($params{'orderid'})." and MID=$MID and VENDOR=$qtVENDOR";
		}
	print STDERR $pstmt."\n";
	$sth = $udbh->prepare($pstmt);
	$sth->execute();
	my @CLOSED_ORDERS = ();
	while ( my $SOIDREF	 = $sth->fetchrow_hashref() ) {
		push @CLOSED_ORDERS, $SOIDREF;
		}
	$sth->finish();
	$lm->pooshmsg(sprintf("INFO|+We have %d orders to close",scalar(@CLOSED_ORDERS)));

	my $PROFILE = $S->fetch_property('PROFILE');
	my $FORMAT = $S->fetch_property('FORMAT'); ## FORMAT (aka ORDER_FORMAT) DROPSHIP','FULFILL','STOCK',

	my %merchantinfo = ();
	if (scalar(@CLOSED_ORDERS)>0) {
		##	%addrinfo contains all the address info that will be used in the order, we compute this here since no matter
		##			which method the order gets dispatched, the address info is the same.
		#my $our_email = &ZOOVY::fetchmerchantns_attrib($USERNAME,$PROFILE,'zoovy:support_email');
		#if ($our_email eq '') { &ZOOVY::fetchmerchantns_attrib($USERNAME,$PROFILE,'zoovy:email'); }
		# require LUSER;
		#my ($LUADMIN) = LUSER->new($USERNAME,'ADMIN'); 
		# my $firstname = &ZOOVY::fetchmerchantns_attrib($USERNAME,$PROFILE,'zoovy:firstname');
		#if ($firstname eq '') { $firstname = $LUADMIN->get("zoovy:firstname"); }
		
		# my $lastname = &ZOOVY::fetchmerchantns_attrib($USERNAME,$PROFILE,'zoovy:lastname');
		# if ($lastname eq '') { $lastname = $LUADMIN->get("zoovy:lastname"); }

		# my ($nsref) = &ZOOVY::fetchmerchantns_ref($USERNAME,$PROFILE);
		#%merchantinfo = (
		#	'our/country'=>$nsref->{'zoovy:country'},
		#	'our/state'=>$nsref->{'zoovy:state'},
		#	'our/firstname'=>$firstname,
		#	'our/lastname'=>$lastname,
		#	'our/company'=>$nsref->{'zoovy:company_name'},
		#	'our/phone'=>$nsref->{'zoovy:support_phone'},
		#	'our/email'=>$our_email,
		#	'our/address1'=>$nsref->{'zoovy:address1'},
		#	'our/address2'=>$nsref->{'zoovy:address2'},
		#	'our/city'=>$nsref->{'zoovy:city'},
		#	'our/zip'=>$nsref->{'zoovy:zip'},
		#	);
		#my ($info) = &ZSHIP::resolve_country(ZOOVY=>$nsref->{'zoovy:country'});
		#$merchantinfo{'our/countrycode'} = $info->{'ISO'};

		foreach my $K ('.our.email','.our.firstname','.our.lastname','.our.phone',
							'.our.company','.our.address1','.our.address2',
							'.our.city','.our.region','.our.postal','.our.countrycode') {
				if ($K =~ /^\.our\.($1)$/) {
					$merchantinfo{"our/$1"} = $S->fetch_property($K);
					}
				}
		$merchantinfo{"our/country"} = $merchantinfo{"our/countrycode"};
		$merchantinfo{"our/state"} = $merchantinfo{"our/region"};
		$merchantinfo{"our/zip"} = $merchantinfo{"our/postal"};
		}

	foreach my $VOREF (@CLOSED_ORDERS) {
		my ($olm) = LISTING::MSGS->new($USERNAME,'stderr'=>1);


		my $OID = $VOREF->{'ID'};		## the database id (this could DEFINITELY be named better)
		my $TRANSMIT_OID = $VOREF->{'OUR_ORDERID'};
		if ((not defined $TRANSMIT_OID) || ($TRANSMIT_OID eq '')) { $TRANSMIT_OID = $VOREF->{'OUR_VENDOR_PO'}; }		## fall back to database id (stock orders, stuff like that)
		if ((not defined $TRANSMIT_OID) || ($TRANSMIT_OID eq '')) { $TRANSMIT_OID = $VOREF->{'ID'}; }		## fall back to database id (stock orders, stuff like that)

		if ($VOREF->{'LOCK_PID'} != $$) {
			if ($params{'unlock'}==1) {
				$olm->pooshmsg("WARN|+$TRANSMIT_OID is locked. but i\'ll ignore it.");
				}
			else {
				$olm->pooshmsg("STOP|+$TRANSMIT_OID is locked. cannot continue (set unlock=1)");
				}
			}
		if ($VOREF->{'STATUS'} ne 'CLOSED') {
			if ($params{'retry'}==1) {
				$olm->pooshmsg("WARN|+$TRANSMIT_OID is not closed, but retry=1 was set so we'll go ahead anyway.");
				}
			else {
				$olm->pooshmsg("STOP|+$TRANSMIT_OID is not closed. (set retry=1)");
				}
			}

		next if (not $olm->can_proceed());

		my ($SO2) = CART2->new_memory($USERNAME);
		$SO2->in_set('flow/supplier_orderid',$TRANSMIT_OID);
		$SO2->in_set('our/order_ts', &ZTOOLKIT::mysql_to_unixtime($VOREF->{'CREATED_TS'}));


		$olm->pooshmsg("INFO|+$VENDOR Closing $VOREF->{'OUR_ORDERID'} => $TRANSMIT_OID");		## our store order #
		
		##
		## SANITY: 
		##		$S is my supplier object.
		##		@ITEMS is an array of hashrefs containing key/values from VENDOR_ORDERITEMS
		##			NOTE: SUPPLIERSKU has been resolved (or set to the same as SKU)
		##		$VOREF contains the key/values from SUPPLIER_ORDERS
		##	now we need to figure out where it's shipping, and the supplier part #'s and then
		##	 dispatch the actual orders.		
		##
		
		$pstmt = "select * from INVENTORY_DETAIL where MID=$MID and VENDOR=$qtVENDOR and VENDOR_ORDER_DBID=$OID";
		print STDERR $pstmt."\n";
		my $sthx = $udbh->prepare($pstmt);
		$sthx->execute();
		my $i = 0;
		my @DBITEMS = ();
		while ( my $itemref = $sthx->fetchrow_hashref() ) {
			push @DBITEMS , $itemref;
			$i++;
			my ($PID) = &PRODUCT::stid_to_pid($itemref->{'SKU'});
			my ($P) = PRODUCT->new($VOREF->{'USERNAME'}, $PID);
			if (not defined $P) {
				$olm->pooshmsg("WARN|SKU '$itemref->{'SKU'}' is invalid and/or could not be loaded from database");
				}

			my $SKU = $itemref->{'SKU'};
			if ($itemref->{'VENDOR_SKU'} eq '') {
				## Figure out the VENDOR_SKU if we've got one!
				# my $skuref = &ZOOVY::fetchsku_as_hashref($VOREF->{'USERNAME'}, $itemref->{'SKU'});
				my $VENDOR_SKU = ''; 

				if (not defined $P) {
					$olm->pooshmsg("WARN|+SKU:$SKU could not be found in local product database");
					}
				elsif ($P->pid() ne $itemref->{'SKU'}) {
					if ($VENDOR_SKU eq '') { $VENDOR_SKU = $P->skufetch($SKU,'zoovy:prod_supplierid'); }
					if ($VENDOR_SKU eq '') { $VENDOR_SKU = $P->skufetch($SKU,'zoovy:prod_mfgid'); }
					}
				else {
					if ($VENDOR_SKU eq '') { $VENDOR_SKU = $P->fetch('zoovy:prod_supplierid'); }
					if ($VENDOR_SKU eq '') { $VENDOR_SKU = $P->fetch('zoovy:prod_mfgid'); }
					}
				
				if ($VENDOR_SKU eq '') { $VENDOR_SKU = $itemref->{'SKU'}; }	# default to the same SKU we're using.
				
				print STDERR "VENDOR_SKU: $VENDOR_SKU\n";
				$pstmt = "update INVENTORY_DETAIL set VENDOR_SKU=".$udbh->quote($VENDOR_SKU)." where VENDOR=$qtVENDOR and ID=".$itemref->{'ID'}." limit 1";
				print STDERR $pstmt."\n";
				$udbh->do($pstmt);
				$itemref->{'VENDOR_SKU'} = $VENDOR_SKU;
				}

			# 2610235*234-15 => 234-15
			$itemref->{'VENDOR_SKU'} =~ s/.*\*//; 	# strip the claim?? (hmm..)
			if ($itemref->{'DESCRIPTION'} eq '') { $itemref->{'DESCRIPTION'} = "No description available"; }

			my $CRAM = 'BASIC';
			if (not defined $P) {
				## sometimes jackasses at amazon give us products we don't have, we should pass those through 
				## (but hwtf they got into supply chain i will NEVER fuckin know)
				$CRAM = 'BASIC';
				}
			elsif (($ORDER_CONNECTOR eq 'API') && ($S->fetch_property('.order.export_format') eq 'XML#200')) {
				$CRAM = 'FULL';
				}

			if ($CRAM eq 'FULL') {
				## certain people, like designed2bsweet/db2s rely upon receiving full attributes to their
				##	fulfillment supplier (wtf- seriously?) alright fine. 
				# $SO2->stuff2()->cram($P->pid(), $itemref->{'QTY'});
            my @suggestions = @{$P->suggest_variations('stid'=>$SKU,'guess'=>1)};
            foreach my $suggestion (@suggestions) {
               if ($suggestion->[4] eq 'guess') {
                  $olm->pooshmsg("WARN|+SKU '$SKU' variation '$suggestion->[0]' was set to guess '$suggestion->[1]' because it was unknown");
                  }
               }
            my $variations = STUFF2::variation_suggestions_to_selections(\@suggestions);
            (my $item,$olm) = $SO2->stuff2()->cram( $P->pid(), $itemref->{'QTY'}, $variations, force_qty=>$itemref->{'QTY'}, force_price=>$itemref->{'COST'}, '*LM'=>$olm ); 
				$item->{'suppliersku'} = $itemref->{'VENDOR_SKU'};
				# $item->{'orderid'} = $itemref->{'ORDERID'};
				}
			elsif ($CRAM eq 'BASIC') {
				$SO2->stuff2()->basic_cram( 
					$itemref->{'VENDOR_SKU'}, 
					$itemref->{'QTY'}, 
					$itemref->{'COST'}, 
					$itemref->{'DESCRIPTION'},
					'our_orderid'=>$itemref->{'OUR_ORDERID'},		# our oid#
					'stid'=>$itemref->{'STID'},				# 
					'uuid'=>$itemref->{'UUID'},
					'VENDOR_ORDER_DBID'=>$itemref->{'VENDOR_ORDER_DBID'}
					);
				}
			else {
				$olm->pooshmsg("ISE|+Unsupported CRAM type '$CRAM'");
				}
			
			}
		$sthx->finish();


		$olm->pooshmsg(sprintf("INFO|+Processing %d items in order %s",$SO2->in_get('sum/items_count'), $TRANSMIT_OID));

		if ($SO2->in_get('sum/items_count')==0) {
			## hmm.. shit happened, lets unlock the order so we can try again. 
			$olm->pooshmsg(sprintf("ERROR|+no items found, skipping order %s",$TRANSMIT_OID));
			}
	

		my $O2_ORIGIN = undef;			# ORIGIN ORDER (if appropriate)
		if (not $olm->can_proceed()) {
			}
		elsif ($FORMAT eq 'STOCK') {
			$olm->pooshmsg("INFO|+STOCK order - no need to load srcorder");
			}
		else {
			($O2_ORIGIN) = CART2->new_from_oid($USERNAME,$VOREF->{'OUR_ORDERID'});
			if (ref($O2_ORIGIN) ne 'CART2') {
				$olm->pooshmsg("ISE|OID:$VOREF->{'OUR_ORDERID'}|+non order object returned, no error given."); 
				}
			}

	
		if (not $olm->can_proceed()) {	
			## bad shit happened, flag the order as corrupt.
			$olm->pooshmsg("CORRUPT|+Flagging order $TRANSMIT_OID as CORRUPT");
			my $pstmt = "update VENDOR_ORDERS VO, INVENTORY_DETAIL as VOI set VO.status='CORRUPT',VOI.VENDOR_status='CORRUPT' ".
							"where VO.ID=$VOREF->{'ID'} and VOI.VENDOR_ORDER_DBID=$VOREF->{'ID'} ".
							" and VO.MID=$MID and VOI.MID=$MID and VO.MID=VOI.MID /* $USERNAME $VOREF->{'OUR_ORDERID'} */";
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			}
		elsif ($FORMAT eq 'STOCK') {
			## STOCK orders don't check source order to see if it's cancelled.
			}
		elsif (($O2_ORIGIN->pool() eq 'CANCELLED') || ($O2_ORIGIN->pool() eq 'DELETED')) {
			## so currently, this should ONLY be run on DROPSHIP or FULFILLMENT orders -- frankly, this is the
			## wrong place to do this, but for now, we need to preserve this functionality.
			$olm->pooshmsg(sprintf("STOP|+Encountered CANCELLED source order %s",$O2_ORIGIN->oid()));
			if (($FORMAT eq 'DROPSHIP') || ($FORMAT eq 'FULFILL')) {
				my $pstmt = "update VENDOR_ORDERS VO, INVENTORY_DETAIL as VOI set VO.VENDOR_status='CANCELLED',VOI.VENDOR_status='CANCELLED' ".
							"where VO.ID=$VOREF->{'ID'} and VOI.VENDOR_ORDER_DBID=$VOREF->{'ID'} ".
							" and VO.MID=$MID and VOI.MID=$MID and VO.MID=VOI.MID /* $USERNAME $VOREF->{'OUR_ORDERID'} */";
				print STDERR "$pstmt\n";
				$udbh->do($pstmt);
				}
			}


		## addrfields can be prefixed with either bill_ or ship_
		#my @addrfields = ('state','province','countrycode','int_zip',
		#						'fullname','firstname','lastname','address1',
		#						'address2','company','phone','city','zip', 'email');
		if (not $olm->can_proceed()) {
			## shit happened
			}
 		elsif (($FORMAT eq 'DROPSHIP') || ($FORMAT eq 'FULFILL')) {
			## in a dropship order we setup the billing as "US" and the shipping as the customer
			## we figure out the customers shipping address by opening $VOREF->{'OUR_ORDERID'}
			$olm->pooshmsg("INFO|+Formatting $FORMAT changes to $VOREF->{'OUR_ORDERID'}");


			foreach my $field (@CART2::VALID_ADDRESS) {
				$SO2->in_set( "ship/$field", $O2_ORIGIN->in_get("ship/$field") );
				}
			my @COPY_FIELDS = ();
			if ($FORMAT eq 'FULFILL') {
				## addrinfo{bill...} is blank unless we're doing fulfillment
				@COPY_FIELDS = (
					'sum/tax_total','sum/items_total','our/tax_rate','sum/tax_rate_state','sum/shp_taxable','sum/tax_rate_zone',
					'sum/shp_method','sum/shp_total','sum/shp_taxable','sum/shp_carrier',
					'sum/ins_method','sum/ins_total','is/ins_taxable',
					'sum/hnd_method','sum/hnd_total','is/hnd_taxable',
					'sum/spc_method','sum/spc_total','is/spc_taxable',
					'sum/bnd_method','sum/bnd_total','is/bnd_taxable',
					'our/sdomain','flow/payment_method','flow/payment_status', 'flow/paid_ts', 'flow/private_notes',
					'want/po_number', 'want/is_giftorder', 'want/erefid', 'want/order_notes'
					);
				}
			if ($FORMAT eq 'DROPSHIP') {
				if ($SO2->in_get('ship/phone') eq '') { $SO2->in_set( 'ship/phone', $O2_ORIGIN->in_get('bill/phone')); }
				if ($SO2->in_get('ship/email') eq '') { $SO2->in_set( 'ship/email', $O2_ORIGIN->in_get('bill/email')); }
				@COPY_FIELDS = (
					'sum/shp_method','sum/shp_carrier','want/order_notes','flow/paid_ts','flow/private_notes',
					);
 				}

			foreach my $field (@COPY_FIELDS) {
				$SO2->in_set( $field, $O2_ORIGIN->in_get($field));
				}
			## moved to non-error state below
			## ie only add event if order has actually dispatched
			#$srcorder->event("Supply chain dispatched to SUPPLIER[$VOREF->{'SUPPLIERCODE'}:$ORDER_CONNECTOR:$FORMAT]",undef,16,'*dispatch');
			#$srcorder->save();
			}
		elsif ($FORMAT eq 'STOCK') {
			## in an inventory order we always ship to ourselves.
			foreach my $field (@CART2::VALID_ADDRESS) {
				$SO2->in_set( "ship/$field", $merchantinfo{"our/$field"} );
				$SO2->in_set( "bill/$field", $merchantinfo{"our/$field"} );
				}
			}
		elsif ($FORMAT eq 'FBA') {
			# nothing to do here - all processing for FBA order is done in SUPPLIER::FBA.pm
			}
		else {
			$olm->pooshmsg("ISE|+UNKNOWN FORMAT '$FORMAT'");
			}
	
		##
		## 
		##

		my $O2_TRANSMIT = undef;
		if (not $olm->can_proceed()) {
			}
		elsif ($S->fetch_property('.api.dispatch_full_order')) {
			## just load the original order and send that 
			# ($O2) = CART2->new_from_oid($USERNAME, $VOREF->{'OUR_ORDERID'}); # ORDER->new($USERNAME, $VOREF->{'OUR_ORDERID'});
			$olm->pooshmsg("INFO|+Getting ready to transmit full order to supplier");
			$O2_TRANSMIT = $O2_ORIGIN;
			}
		else {
			$olm->pooshmsg("INFO|+Getting ready to transmit supplier order");
			$O2_TRANSMIT = $SO2;
			}

		if (defined $O2_TRANSMIT) {
			$O2_TRANSMIT->make_readonly();
			}
		# 	$O2_ORIGIN->make_readonly();		

		if (not $olm->can_proceed()) {
			}
		elsif ($params{'nosend'}>0) {
			$olm->pooshmsg("STOP|+found nosend=1 so did not actually send this order");
			print Dumper($O2_TRANSMIT);
			if ($ORDER_CONNECTOR eq 'API') {
				#if (($S->fetch_property('.api.version') > 100) && ($S->fetch_property('.api.version') < 300)) {
				#	print $O2_TRANSMIT->as_xml( $S->fetch_property('.api.version') );		
				#	}
				}
			}
		elsif (ref($O2_TRANSMIT) ne 'CART2') {
			## die intentionall - this line is never reached.
			&ZOOVY::confess($USERNAME,"internal error in supply chain .. corrupt order!?".Dumper($O2_TRANSMIT));
			}
		elsif ($ORDER_CONNECTOR eq 'FBA') {
			require SUPPLIER::FBA;
			SUPPLIER::FBA::transmit($S,$O2_TRANSMIT);
			}
		elsif ($ORDER_CONNECTOR eq 'FAX') {
			&ZOOVY::confess($USERNAME,"FAX CONNECTOR NO LONGER SUPPORTED".Dumper($O2_TRANSMIT));
			## SEND VIA EFAX
			#if ($ORDER_CONNECTOR eq 'FAX') {
			#	$FROM = 'efax@zoovy.com'; 
			#	$RECIPIENT = $S->fetch_property('.order.fax');
			#	$RECIPIENT =~ s/[^\d]+//gs;
			#	$RECIPIENT =~ s/^[01]+//gs;	# strip leading 01
			#	$RECIPIENT = '1'.$RECIPIENT.'@efaxsend.com';
		
			#	my $zdbh = &DBINFO::db_zoovy_connect();
			#	&DBINFO::insert($zdbh,"BS_TRANSACTIONS", {
			#		USERNAME=>$USERNAME,
			#		MID=>$MID,
			#		AMOUNT=>0.10,
			#		CREATED=>&ZTOOLKIT::mysql_from_unixtime(time()),
			#		BILLGROUP=>'OTHER',
			#		MESSAGE=>"Fax to supplier for order ". $SO2->in_get('flow/supplier_orderid'),
			#		BILLCLASS=>"BILL",
			#		BUNDLE=>"FAX",
			#		NO_COMMISSION=>1, }, debug=>1);
			#	&DBINFO::db_zoovy_close();		
			#	$disposition = 'attachment';
			#	}
			#	if ($ORDER_CONNECTOR eq 'FAX') {
			#		## remove cover page
			#		$bodypart->{'BODY'} = "{nocoverpage}{showbodytext}\n".$bodypart->{'BODY'};
			#		}
			#	if ($ORDER_CONNECTOR eq 'FAX') {
			#		$msg->send("sendmail", "/usr/sbin/sendmail -r efax\@zoovy.com -t");
			#		}
			}
		elsif ($ORDER_CONNECTOR eq 'EMAIL') {
			require SUPPLIER::GENERIC;

			#my ($error) = SUPPLIER::GENERIC::dispatch_order($S,$O2_TRANSMIT);
			#if ($error eq '0') { $error = undef; }
			## what do we do now?
			my $disposition = 'inline';
			my $RECIPIENT = $S->fetch_property('.order.email_recipient');
			if ($RECIPIENT eq '') {
				$olm->pooshmsg("ERROR|+Recipient Email not found for Supplier: ".$S->fetch_property('CODE'). " unable to send order");
				}
			my $FROM = $S->fetch_property('.order.email_src');
			# my $PROFILE = $S->fetch_property('PROFILE');
			my ($BCC) = $S->fetch_property('.order.email_bcc');
			## only added for testing
			#if ($BCC eq '') { $BCC = "patti\@zoovy.com"; }
			#else { $BCC .= ",patti\@zoovy.com"; }

			## get source email from the DEFAULT PROFILE
			#my $FROM = ZOOVY::fetchmerchantns_attrib($S->username(),$S->profile(),"zoovy:support_email");
			## return error if Source Email not found
			#if ($FROM eq '') { 
			#	$olm->pooshmsg("ERROR|+Source Email not found for Supplier: ".$S->fetch_property('CODE'). " unable to send order");
			#	}

	
			## find appropriate domain for this Profile
			#use DOMAIN::TOOLS;
			#my $domain = &DOMAIN::TOOLS::syndication_domain($S->username(),$S->profile());	

			## build SUBS vars
			## '%REFNUM%', '%DATE%', '%PAYINFO%', '%WEBSITE%'
			my %SUBS = (
				'%REFNUM%'=> $SO2->in_get('flow/supplier_orderid'),
				'%ORDERID%'=> $SO2->in_get('flow/supplier_orderid'),
				'%DATE%'=>	&ZTOOLKIT::pretty_date( $SO2->in_get('our/order_ts') ),		
				'%PAYINFO%'=> '', # waiting for patti!',
				# '%WEBSITE%'=>'http://'.$domain,
				'%SHIPMETHOD%'=>($SO2->in_get('sum/shp_method') eq '')?'Standard':$SO2->in_get('sum/shp_method'),
				);

			my $FORMAT = $S->fetch_property('.order.email_body_format');
			if ($FORMAT !~ /^(XML|HTML|TXT)$/) { 
				$olm->pooshmsg(sprintf("ERROR|+Unsupported .order.email_body_format '%s'",$FORMAT));
				}

			## build SUBS vars
			## '%HTMLBILLADDR','%HTMLSHIPADDR', '%TXTBILLADDR', '%TXTSHIPADDR', '%XMLBILLADDR', '%XMLSHIPADDR'
			## ship and bill address info for each type (txt, html, xml)
			foreach my $type ('ship','bill') {
				my $addr = '';

				## NAME
				if (not $SO2->in_get(sprintf("%s/%s",$type,'firstname'))) { }
				elsif ($FORMAT eq 'TXT') {	$addr .=$SO2->in_get(sprintf("%s/%s",$type,'firstname'))." ".$SO2->in_get(sprintf("%s/%s",$type,'lastname'))."\n"; }
				elsif ($FORMAT eq 'HTML') { $addr .= $SO2->in_get(sprintf("%s/%s",$type,'firstname'))." ".$SO2->in_get(sprintf("%s/%s",$type,'lastname'))."<br>";  }
				elsif ($FORMAT eq 'XML') {	$addr .= '<firstname>'.$SO2->in_get(sprintf("%s/%s",$type,'firstname')).'</firstname><lastname>'.$SO2->in_get(sprintf("%s/%s",$type,'lastname')).'</lastname>'; }

				## COMPANY
				if (not $SO2->in_get(sprintf("%s/%s",$type,'company'))) { }
				elsif ($FORMAT eq 'TXT') { 	$addr .=$SO2->in_get(sprintf("%s/%s",$type,'company'))."\n"; }
				elsif ($FORMAT eq 'HTML') {	$addr .= $SO2->in_get(sprintf("%s/%s",$type,'company'))."<br>";  }
				elsif ($FORMAT eq 'XML') {		$addr .= '<company>'.$SO2->in_get(sprintf("%s/%s",$type,'company')).'</company>'; }
		
				## ADDRESS
				if ($SO2->in_get(sprintf("%s/%s",$type,'address1')) eq '') {}
				elsif ($FORMAT eq 'TXT') { $addr .=$SO2->in_get(sprintf("%s/%s",$type,'address1'))."\n".(($SO2->in_get(sprintf("%s/%s",$type,'address2')) ne '')?$SO2->in_get(sprintf("%s/%s",$type,'address2'))."\n":''); }
				elsif ($FORMAT eq 'HTML') { $addr .= $SO2->in_get(sprintf("%s/%s",$type,'address1'))."<br>".(($SO2->in_get(sprintf("%s/%s",$type,'address2')) ne '')?$SO2->in_get(sprintf("%s/%s",$type,'address2')).'<br>':'');  }
				elsif ($FORMAT eq 'XML') {	$addr .= '<addr1>'.$SO2->in_get(sprintf("%s/%s",$type,'address1'))."</addr1>".(($SO2->in_get(sprintf("%s/%s",$type,'address2')) ne '')?'<addr2>'.$SO2->in_get(sprintf("%s/%s",$type,'address2')).'</addr2>':''); }

				## CITY, STATE, PROVINCE, COUNTRY, ZIP
				if (($SO2->in_get(sprintf("%s/%s",$type,'city')) eq '') && ($SO2->in_get(sprintf("%s/%s",$type,'region')) eq '')) {
					## no city/region
					}
				elsif (defined $SO2->in_get(sprintf("%s/%s",$type,'postal')) && $SO2->in_get(sprintf("%s/%s",$type,'postal')) ne '') {
					if 	($FORMAT eq 'HTML')	{ $addr .= $SO2->in_get(sprintf("%s/%s",$type,'city')).', '.$SO2->in_get(sprintf("%s/%s",$type,'region')).', '.$SO2->in_get(sprintf("%s/%s",$type,'postal'))." ".$SO2->in_get(sprintf("%s/%s",$type,'countrycode'))."<br>\n"; }		
					elsif ($FORMAT eq 'TXT') 	{ $addr .=$SO2->in_get(sprintf("%s/%s",$type,'city')).', '.$SO2->in_get(sprintf("%s/%s",$type,'region')).', '.$SO2->in_get(sprintf("%s/%s",$type,'postal'))." ".$SO2->in_get(sprintf("%s/%s",$type,'countrycode'))."\n";  }
					elsif ($FORMAT eq 'XML') 	{ $addr .= '<city>'.$SO2->in_get(sprintf("%s/%s",$type,'city')).'</city><region>'.$SO2->in_get(sprintf("%s/%s",$type,'region')).'</region><postal>'.$SO2->in_get(sprintf("%s/%s",$type,'postal'))." ".$SO2->in_get(sprintf("%s/%s",$type,'countrycode'))."</postal>"; }
					}
				else {
					if 	($FORMAT eq 'HTML')	{ $addr .= $SO2->in_get(sprintf("%s/%s",$type,'city')).', '.$SO2->in_get(sprintf("%s/%s",$type,'region')).'. '.$SO2->in_get(sprintf("%s/%s",$type,'postal'))."<br>\n"; }
					elsif ($FORMAT eq 'TXT') 	{ $addr .=$SO2->in_get(sprintf("%s/%s",$type,'city')).', '.$SO2->in_get(sprintf("%s/%s",$type,'region')).'. '.$SO2->in_get(sprintf("%s/%s",$type,'postal'))."\n"; }
					elsif ($FORMAT eq 'XML') 	{ $addr .= '<city>'.$SO2->in_get(sprintf("%s/%s",$type,'city')).'</city><region>'.$SO2->in_get(sprintf("%s/%s",$type,'region')).'</region><postal>'.$SO2->in_get(sprintf("%s/%s",$type,'postal'))."</postal>\n"; }
					}
			
				## PHONE
				if 	($FORMAT eq 'HTML')	{ $addr .= ($SO2->in_get(sprintf("%s/%s",$type,'phone')) ne '')?"Phone: ".$SO2->in_get(sprintf("%s/%s",$type,'phone'))."<br>":''; }
				elsif ($FORMAT eq 'TXT')   { $addr .=($SO2->in_get(sprintf("%s/%s",$type,'phone')) ne '')?"Phone: ".$SO2->in_get(sprintf("%s/%s",$type,'phone'))."\n":''; }
				elsif ($FORMAT eq 'XML')   { $addr .= ($SO2->in_get(sprintf("%s/%s",$type,'phone')) ne '')?"<phone>".$SO2->in_get(sprintf("%s/%s",$type,'phone'))."</phone>":''; }
		
				## assign contact to variables below
				## '%BILLADDR','%SHIPADDR%',
				$SUBS{uc('%'.$type.'ADDR%')} = $addr;
				}
		
			## build SUBS vars
			## '%HTMLCONTENTS%', '%XMLCONTENTS%', '%TXTCONTENTS%'
		
			## this setting can be toggled in the UI
			##		some merchants do not want the cost shown to their Supplier
			my ($show_cost) = int($S->fetch_property('.order.field_cost'));
			## this setting was added for ibuystores and is currently can only be changed on the backend
			##		do not show items where the qty is zero, this would happen if the merchant edit the order
			my ($dont_show_zero_qtys) = int($S->fetch_property('.order.dont_show_zero_qtys'));
		
			my $items = '';

			if ($FORMAT eq 'TXT') {			
				$items = sprintf("%s \t%4s \t%s\t%s",'SKU','QTY','DESC','COST','EXT');
				}
			elsif ($FORMAT eq 'HTML') {
				$items .= "<table cellpadding='2' cellspacing='1' width='100%' bgcolor='#CCCCCC'>\n";
				$items .= "<tr>\n";
				$items .= "<td bgcolor='#FFFFFF'><b>SKU</b></td>\n";
				$items .= "<td width=60 bgcolor='#ffffff' align='center'><b>QTY</b></td>\n";
				$items .= "<td bgcolor='#ffffff'><b>DESCRIPTION</b></td>\n";
				$items .= "<td bgcolor='#ffffff'><b>COST</b></td>\n";
				$items .= "<td bgcolor='#ffffff'><b>EXTENDED</b></td>\n";
				$items .= "</tr>\n";
				}
			 
			my $total_items = 0;
			foreach my $item (@{$SO2->stuff2()->items()}) {
				my $sku = $item->{'sku'};
				my $qty = $item->{'qty'};
				my $desc = $item->{'prod_name'};
				
				if ($dont_show_zero_qtys && int($qty) == 0) {
					## go to the next item
					print STDERR "dont_show_zero_qtys -- SKU: $sku QTY: $qty\n";
					}
				else {
					$total_items++;
					## get the SKU product name if its an ebay item
					#if ($desc =~ /ebay:/) {
					#	my $new_desc = &ZOOVY::fetchproduct_attrib($USERNAME,$sku,'zoovy:prod_name');
					#	if ($new_desc ne '') { $desc = $new_desc; }
					#	}
	
					## so basically: basic items are 'price' (for cost) and non basic items (complete orders) are price
					## 	ugh that's ungly.
					my $cost = $item->{'price'};
					my $extended = sprintf("%.2f",($cost*$qty));
		
					if (not $show_cost) { 
						$cost = '-'; 
						$extended = '-'; 
						}

					if ($FORMAT eq 'TXT') {
						$items .= "\n".sprintf("%s \t%4d \t%s\t%2.f\t%2.f\n",$sku,$qty,$desc,$cost,$extended);
						}
					elsif ($FORMAT eq 'HTML') {
						$items .= "<tr>\n";
						$items .= "<td bgcolor='#ffffff'>$sku</td>\n";
						$items .= "<td bgcolor='#ffffff' align='center'>$qty</td>\n";
						$items .= "<td bgcolor='#ffffff'>$desc</td>\n";
						$items .= "<td bgcolor='#ffffff' align='center'>$cost</td>\n";
						$items .= "<td bgcolor='#ffffff' align='center'>$extended</td>\n";
						$items .= "</tr>\n";
						}
					elsif ($FORMAT eq 'XML') {
						$items .= "<sku>$sku</sku>\n";
						$items .= "<qty>$qty</qty>\n";
						$items .= "<desc>$desc</desc>\n";
						if ($show_cost) { $items .= "<cost>$cost</cost>\n"; }
						}
			
					}
				}
			if ($FORMAT eq 'HTML') {
				$items .= "</table>";
				}
			$SUBS{'%CONTENTS%'} = $items;
		
			## this error may occur if 'dont_show_zero_qtys' is set, and no items are in the order
			if ($total_items == 0) {
				$olm->pooshmsg("ERROR|+Order: ".$SO2->in_get('flow/supplier_orderid')." will not be dispatched to Supplier, no items found.");
				}

			if (not $olm->can_proceed()) {
				}
			elsif ($SO2->in_get('want/order_notes') eq '') {
				$SUBS{'%ORDER_NOTES'} = ''; 	
				}
			elsif ($S->fetch_property('.order.email_body_format') eq 'XML') {
				$SUBS{'%ORDER_NOTES%'} = "<additional_notes>".$SO2->in_get('want/order_notes')."</additional_notes>";
				}
			elsif ($S->fetch_property('.order.email_body_format') eq 'HTML') {
				$SUBS{'%ORDER_NOTES%'} = "<p><p><b>Additional Notes:</b><br>".$SO2->in_get('want/order_notes');
				}
			elsif ($S->fetch_property('.order.email_body_format') eq 'TXT') {
				$SUBS{'%ORDER_NOTES%'} = "\n\nAdditional Notes:\n".$SO2->in_get('want/order_notes')."\n";
				}

			my $BODY = $S->fetch_property('.order.email_body_content');
			$BODY = &ZTOOLKIT::interpolate(\%SUBS,$BODY);	
			if ($BODY eq '') {
				$BODY = "Message body is blank, please see attachement";
				}

			my $SUBJECT  = $S->fetch_property('.order.email_subject');
			$SUBJECT = &ZTOOLKIT::interpolate(\%SUBS,$SUBJECT);
			$SUBJECT =~ s/[\n\r]+/ /gs;

			if (my $hadref = $olm->had(['ERROR','ISE'])) {
				#require TODO;
				#my ($t) = TODO->new($USERNAME,writeonly=>1);
				#if (defined $t) {
				#	$t->add(class=>"ERROR",title=>"Supply Chain/".$S->id()." error: $hadref->{'+'}");
				#	}
				&ZOOVY::add_notify($USERNAME,'ERROR.SUPPLIER',supplier=>$S->id(),title=>"Supply Chain/".$S->id()." error: $hadref->{'+'}");
				}	
			elsif (not $olm->can_proceed()) {
				## stop/skip etc.?
				}
			else {
				$olm->pooshmsg( "INFO|+Sending $FORMAT email from $FROM to $RECIPIENT");	
				my $mime = lc('text/'.$FORMAT);
				if ($mime eq 'text/txt') { $mime = 'text/plain'; }	
				if ($mime eq 'text/text') { $mime = 'text/plain'; }	
		
				### Create a new multipart message
				use MIME::Lite;
				my $msg = MIME::Lite->new(
					'X-Mailer'=>"Zoovy-SupplyChain/2.0 [$USERNAME:".($S->id())."]",
					From=>$FROM,
					'Reply-To'=>$FROM,
			  	   To=>$RECIPIENT,
					Bcc=>$BCC,
					Type=>$mime,
					Subject=>$SUBJECT,
					Data=>$BODY,
					Disposition=>'inline',
			  	   );

				my $CMD = "/usr/sbin/sendmail -t";
				if (&ZOOVY::host_operating_system()) {
					if (-f "/usr/sbin/sendmail") {}
					elsif (-f "/opt/csw/sbin/sendmail") { $CMD = "/opt/csw/sbin/sendmail -t"; }
					else { die "No sendmail!"; }
					}
				$msg->send("sendmail", "$CMD");
			   ### Format as a string:
				# print $msg->as_string;
				$olm->pooshmsg("SUCCESS|+$ORDER_CONNECTOR Email sent (BODY was ".length($BODY)." bytes)"); 
				}
			}
		elsif (($ORDER_CONNECTOR eq 'API') || ($ORDER_CONNECTOR eq 'FTP') || ($ORDER_CONNECTOR eq 'AMZSQS')) {
			print STDERR "Dispatching order to API\n";

			## populate order contents
			my $body = '';

			if ($S->fetch_property('.order.export_format') eq '') {
				$body = "ERROR:export_format not set";
				}
			elsif ($S->fetch_property('.order.export_format') eq 'XCBL#4') {
				require ORDER::XCBL;
				$body = ORDER::XCBL::as_xcbl($O2_TRANSMIT);
				}
			elsif ($S->fetch_property('.order.export_format') eq 'CSV3D#0') {
				require ORDER::CSV;		
				$body = ORDER::CSV::as_csv($O2_TRANSMIT);
				}
			elsif ($S->fetch_property('.order.export_format') eq 'XML#200') {
				$body = $O2_TRANSMIT->as_xml( 200 );		
				}
			elsif ($S->fetch_property('.order.export_format') =~ /^XML\#([\d]+)$/) {
				$body = $O2_TRANSMIT->as_xml( $1 );		
				}
			elsif ($S->fetch_property('.order.export_format') =~ /^JSON\#([\d]+)$/) {
				$body = JSON::XS::encode_json($O2_TRANSMIT->jsonify( $1 ));		
				}
			elsif ($S->fetch_property('.order.export_format') =~ /^XSLT\#([\d]+)$/) {
				my $xml = $O2_TRANSMIT->as_xml( $1 );	
				my $parser = XML::LibXML->new();
				my $xslt = XML::LibXSLT->new();
				my $source = $parser->parse_string($xml);
#				my $style_doc = $parser->parse_file($S->fetch_property('.order.xslt'));
				my $style_doc = $parser->load_xml( string => $S->fetch_property('.order.xslt'));
				my $stylesheet = $xslt->parse_stylesheet($style_doc);
				my $results = $stylesheet->transform($source);
				$body = $stylesheet->output_string($results);
				}
			else {		
				$body = sprintf("ERROR: ORDER_CONNECTOR API UNSUPPORTED .api.version = %d",$S->fetch_property('.api.version'));
				&ZOOVY::confess($USERNAME,"$body"); 
				}

			print Dumper($S,$O2_TRANSMIT);
			print "BODY: $body\n";

			## parse the API scheme, and substitute any %orderid% in the path
			my $URL = '';
			if ($ORDER_CONNECTOR eq 'FTP') {
				$URL = $S->fetch_property('.order.ftp_url');
				}
			elsif ($ORDER_CONNECTOR eq 'API') {
				# ($URL) = $S->fetch_property('.api.orderurl');	## NOT REFERENCED
				($URL) = $S->fetch_property('.order.api_url');
				}
			elsif ($ORDER_CONNECTOR eq 'AMZSQS') {
				$URL = sprintf("sqs://%s:%s\@%s",$S->fetch_property('.order.aws_access_key'),$S->fetch_property('.order.aws_secret_key'),$S->fetch_property('.order.aws_sqs_channel'));
				}
			$URL =~ s/%orderid%/$TRANSMIT_OID/ig;		
			my ($scheme, $auth, $path, $query, $frag) = URI::Split::uri_split($URL);
			## this substition lets us do things like 'ftp://wlanparts:rt5k33np@96.31.234.16/file-%orderid%.xml'
			$scheme = uc($scheme);

			## send order information
			## if ($S->fetch_property('.api.orderurl') =~ /^http[s]?\:(.*?)$/i) {
			if (not $olm->can_proceed()) {
				## shit happened.
				}
			elsif ($body eq '') {
				$olm->pooshmsg("ERROR|+cowardly refusing to transmit a blank body");
				}
			elsif ($scheme eq '') {
				$olm->pooshmsg("ERROR|+order api url has no scheme  - nothing to do here.");
				}
			elsif ($scheme eq 'SQS') {
				require Amazon::SQS::Simple;
				my $sqs = new Amazon::SQS::Simple($S->fetch_property('.order.aws_access_key'), $S->fetch_property('.order.aws_secret_key'));
				my $q = $sqs->CreateQueue($S->fetch_property('.order.aws_sqs_channel'));
				$q->SendMessage($body);
				$olm->pooshmsg("SUCCESS|+Transmitted");
				}
			elsif (($scheme eq 'HTTP') || ($scheme eq 'HTTPS')) {
				# (my $ERROR, my $status) = &SUPPLIER::API::post($S->fetch_property('.api.orderurl'), \%vars);
				my $agent = LWP::UserAgent->new( 'ssl_opts'=>{ 'verify_hostname' => 0 } );
				$agent->timeout(15);

				## NOTE: this proxy is dead. not sure if one is still needed for dev. (doubt it)
				# $agent->proxy(['http', 'ftp'], 'http://63.108.93.10:8080/');
				
				my %vars = ();
				if ($USERNAME eq 'cubworld' && $VENDOR eq 'VLFSG1') {
					%vars = ( 'Username'=>$USERNAME, 'Method'=>'Order', 'OrderID'=>$TRANSMIT_OID, 'Request'=>$body );
					}
				else {
					%vars = ( 'Username'=>$USERNAME, 'Method'=>'Order', 'OrderID'=>$TRANSMIT_OID, 'Contents'=>$body );
					}
				my ($result) = $agent->request( POST $URL, \%vars  );

				my ($h) = HTTP::Headers->new();
				#$h->push_header( 'Username'=>$USERNAME );
				#$h->push_header( 'Method'=>'Order' );
				#$h->push_header( 'OrderID'=>$TRANSMIT_OID );

				## ANDREW:
				## my $r = HTTP::Request->new( 'POST',  $URL, $h, $body);
				## my ($result) = $agent->request($r);

				# my $result = $agent->request(POST $URL, 'Username'=>$USERNAME, 'Method'=>'Order', 'OrderID'=>$TRANSMIT_OID, 'Contents'=>$body );
				

				print STDERR Dumper($result);
		
				## non 200 OK results
				if ($result->code() eq '200') {
					$olm->pooshmsg("SUCCESS|+HTTP RESPONSE 200");
					}			
				elsif ($result->content() =~ /<ERROR>(.*?)<\/ERROR>/) {
					## Shipping API's will return an error like this:
					my ($msg) = $1;
					$olm->pooshmsg(sprintf("ERROR|+HTTP %d RESPONSE ERROR '%s'",$result->code(),$msg));
					}
				else {
					$olm->pooshmsg(sprintf("ERROR|+HTTP %d ERROR",$result->code()));
					}

				}
			# elsif ($S->fetch_property('.api.orderurl') =~ /ftp\:\/\/(.*?):(.*?)/\@(.*?)\/(.*)$) {
			elsif ($scheme eq 'FTP') {
				## ex: ftp://wlanparts:rt5k33np@96.31.234.16/file-%orderid%.xml
				#(my $ERROR, my $status) = &SUPPLIER::API::post($S->fetch_property('.api.orderurl'), \%vars);
				#$olm->pooshmsg("INFO|POST RESPONSE:$ERROR");
				#print STDERR "Dispatching API Order: \n".Dumper({'$S'=>$S,'$VOREF'=>$VOREF,'$status'=>$status, '$ERROR'=>$ERROR});				
				my $error = undef;
				my ($user,$pass,$host) = split(/[:\@]/,$auth);
				require Net::FTP;
				my $ftp = Net::FTP->new("$host", Debug => 1);
					if ((not $error) && (defined $ftp)) {
					print STDERR "USER[$user] PASS[$pass] HOST[$host]\n";
					$ftp->login($user,$pass) or $error = "FTP error! could not login";
					}
				if ((defined $ftp) && (not $error)) {
					$ftp->ascii();
					require IO::Scalar;
					my $SH = IO::Scalar->new(\$body);
					print STDERR "PATH[$path]\n";
					$ftp->put($SH,"$path") or $error = "FTP error! could not upload file";
					$ftp->quit();
					}

				if (defined $error) {
					$olm->pooshmsg("ERROR|+FTP ERROR '$error'");
					}
				else {
					$olm->pooshmsg("SUCCESS|+FILE SENT");
					}
				}
			elsif ($scheme eq 'MAILTO') {
			#elsif ($S->fetch_property('.api.orderurl') =~ /^mailto\:(.*?)$/i) {
				my ($email) = $path;
			
				## set ERROR for blank email
				if ($email eq '') {
					$olm->pooshmsg("ERROR|+Order email was not found: ".$email);
					}
				elsif (not ZTOOLKIT::validate_email_strict($email)) {
					$olm->pooshmsg("ERROR|+Invalid Order email: ".$email);
					}

				## send email
				if ($olm->can_proceed()) {
					my $FROM = $merchantinfo{'our/email'};
					open MH, "|/usr/sbin/sendmail -t";
					print MH "To: $email\n";
					print MH "From: $FROM\n";
					print MH "Subject: Order $TRANSMIT_OID\n\n";
					print MH $body;
					close MH;		
					$olm->pooshmsg("SUCCESS|+Email sent");
					}
				}
			else {
				&ZOOVY::confess($USERNAME,sprintf("UNSUPPORTED API ORDERURL FORMAT '%s'",$S->fetch_property('.order.api_url')),justkidding=>1); 
				}
			}
		#elsif ($ORDER_CONNECTOR eq 'JEDI') {
		#	require SUPPLIER::JEDI;
		#	my ($srcorder) = ORDER->new($USERNAME,$VOREF->{'OUR_ORDERID'});
		#	($oid, $error) = SUPPLIER::JEDI::dispatch_order($S,$VOREF,\%addrinfo,\@ITEMS,$srcorder);
		#	print STDERR "JEDI dispatch OUR_ORDERID: $oid ERROR: $error\n";
		#	if ($error eq '') {
		#		$srcorder->set_attrib('sc_orderinfo',$S->fetch_property('.jedi.username')." ".$oid);												
		#		$srcorder->save();
		#		print STDERR "Dispatched JEDI Order: $oid to ".$S->fetch_property('.jedi.username')."\n";
		#		} 
		#	}
		## elsif ($ORDER_CONNECTOR eq 'PARTNER') {
		##		my $PARTNER = $S->fetch_property('PARTNER')
		##		if ($PARTNER eq 'ATLAST') {
		#elsif ($ORDER_CONNECTOR eq 'PARTNER') {
		#  my $PARTNER = $S->fetch_property('PARTNER');
		#  if ($PARTNER eq 'ATLAST') {
		#		print STDERR "Dispatching order to ATLAST\n";
		#		require SUPPLIER::ATLAST;
		#		($oid, $error) = SUPPLIER::ATLAST::dispatch_order($S,$VOREF,\%addrinfo,\@ITEMS);
		#		}
		#  elsif ($PARTNER eq 'SHIPWIRE') {
		#		print STDERR "Dispatching order to SHIPWIRE\n";
		#		require SUPPLIER::SHIPWIRE;
		#		($oid, $error) = SUPPLIER::SHIPWIRE::dispatch_order($S,$VOREF,\%addrinfo,\@ITEMS);
		#		}
		#  elsif ($PARTNER eq 'DOBA') {
		#		print STDERR "Dispatching order to DOBA\n";
		#		require SUPPLIER::DOBA;
		#		($oid, $error) = SUPPLIER::DOBA::dispatch_order($S,$VOREF,\%addrinfo,\@ITEMS);
		#		}
		#  }
		else {
			$olm->pooshmsg("ISE|+UNKNOWN ORDER_CONNECTOR '$ORDER_CONNECTOR'".Dumper($olm),'justkidding'=>1);
			}

	
		## update VENDOR_ORDERS
		my $event = '';
		# if ($error eq '' || $error eq '0') {
		if (my $successref = $olm->had(['SUCCESS'])) {

			## NOTE: we *may* not want to set OUR_VENDOR_REFID == technically this should always be the OUR_VENDOR_PO
			my $pstmt = "update VENDOR_ORDERS set VENDOR_REFID=".$udbh->quote($TRANSMIT_OID).
						",LOCK_PID=0,LOCK_GMT=0,DISPATCHED_COUNT=DISPATCHED_COUNT+1,DISPATCHED_TS=now() where ID=".$udbh->quote($VOREF->{'ID'});	
			print STDERR $pstmt."\n";
			print STDERR $udbh->do($pstmt);

			## step4: create order in the store AND compute all the totals
			## do this step even if a WARNING exists
			my @SQL = ();

			my $total_cost = $O2_TRANSMIT->in_get('sum/order_total');

			push @SQL, "start transaction";
			$pstmt = "update VENDOR_ORDERS set DISPATCHED_TS=now(),STATUS='PLACED',TOTAL_COST=$total_cost,TXLOG=concat(".$udbh->quote(TXLOG->new()->lmsgs($olm,"transmit")->serialize()).",TXLOG)";
			$pstmt .= " where MID=$MID /* $USERNAME */ and ID=".$VOREF->{'ID'};
			push @SQL, $pstmt;
	
			foreach my $item (@DBITEMS) {
				my $pstmt = "update INVENTORY_DETAIL set VENDOR_STATUS='ONORDER',MODIFIED_TS=now() where ID=".$udbh->quote($item->{'ID'});
				push @SQL, $pstmt;
				}
			push @SQL, "commit";
			foreach my $pstmt (@SQL) {
				print STDERR $pstmt."\n";
				$udbh->do($pstmt);
				}	
			$event = "Supply chain dispatched to SUPPLIER[$VOREF->{'SUPPLIERCODE'}:$ORDER_CONNECTOR:$FORMAT]";
			}		
		elsif (my $iseref = $olm->had(['ISE'])) {
			&ZOOVY::confess($USERNAME,"SUPPLY CHAIN ISE $iseref->{'+'}\n".Dumper($olm),justkidding=>1);
			$olm->pooshmsg("INFO|+Setting ID=$VOREF->{'ID'} to ERROR");
			my $pstmt = "update VENDOR_ORDERS set STATUS='ERROR',TXLOG=concat(".$udbh->quote(TXLOG->new()->lmsgs($olm,"transmit")->serialize()).",TXLOG) where ID=".$udbh->quote($VOREF->{'ID'});
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			}
		else {
			## 
			## RETRY try redispatching the order 5 times before returning an ERROR
			## 
			my $pstmt = "select ATTEMPTS from VENDOR_ORDERS where ID = ".$udbh->quote($VOREF->{'ID'});
			my ($ATTEMPTS) = $udbh->selectrow_array($pstmt);

			my %DBUPDATES = ();
			$DBUPDATES{'*ATTEMPTS'} = 'ATTEMPTS+1';
			if ($ATTEMPTS >= 5) {
				$olm->pooshmsg("ERROR|+ATTEMPTS: $ATTEMPTS (will not retry)");
				$DBUPDATES{'STATUS'} = 'ERROR';
				}
			else {
				## increment ATTEMPTS and wait 30min before trying again
				$olm->pooshmsg("WARN|+ATTEMPTS: $ATTEMPTS (will retry)");
				}
			$DBUPDATES{'*TXLOG'} = sprintf("TXLOG=concat(%s,TXLOG)",$udbh->quote(TXLOG->new()->lmsgs($olm,"transmit")->serialize()));
			my $pstmt = &DBINFO::insert($udbh,'VENDOR_ORDERS',\%DBUPDATES,sql=>1,verb=>'update',key=>{'ID'=>$VOREF->{'ID'},'MID'=>$VOREF->{'MID'},'VENDOR'=>$VOREF->{'VENDOR'}});
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			}
	
		if ($event ne '') {
			## save event to ticket (either order dispatched or there was an error)	
			my ($O2) = CART2->new_from_oid($USERNAME,$VOREF->{'OUR_ORDERID'});
			if (defined $O2) {
				$O2->add_history($event,etype=>16,luser=>'*supply');
				$O2->order_save();
				}
			}
		$lm->merge($olm);
		}

	&DBINFO::db_user_close();

	return();
	}

1;
