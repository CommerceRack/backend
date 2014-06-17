package ORDER::BATCH;

use strict;
require CART2;
require ZWEBSITE;
require ZTOOLKIT;


#------+----------------+
#| ID                   | int(11) unsigned                                                                   |      | PRI | NULL    | auto_increment |
#| MERCHANT             | varchar(20)                                                                        |      |     |         |                |
#| MID                  | int(11) unsigned                                                                   |      | MUL | 0       |                |
#| ORDERID              | varchar(20)                                                                        |      |     |         |                |
#| CREATED_GMT          | int(10) unsigned                                                                   |      |     | 0       |                |
#| MODIFIED_GMT         | int(10) unsigned                                                                   |      |     | 0       |                |
#| CUSTOMER             | int(11) unsigned                                                                   |      |     | 0       |                |
#| POOL                 | enum('RECENT','PENDING','APPROVED','COMPLETED','DELETED','ARCHIVE','BACKORDER','') |      |     |         |                |
#| ORDER_BILL_NAME      | varchar(30)                                                                        |      |     |         |                |
#| ORDER_BILL_EMAIL     | varchar(30)                                                                        |      |     |         |                |
#| ORDER_BILL_ZONE      | varchar(9)                                                                         |      |     |         |                |
#| ORDER_PAYMENT_STATUS | char(3)                                                                            |      |     |         |                |
#| ORDER_PAYMENT_METHOD | varchar(4)                                                                         |      |     |         |                |
#| ORDER_TOTAL          | decimal(10,2)                                                                      |      |     | 0.00    |                |
#| ORDER_SPECIAL        | varchar(40)                                                                        |      |     |         |                |
#| MKT                  | int(10) unsigned                                                                   | YES  |     | 0       |                |
#+

##
## orderset is an arrayref of order fields.
##	fieldsset is an array of fields e.g. ship_firstname, ship_lastname, ship_fullname
##
## returns:
##		an arrayref of orders (same order they were sent in)
##		each row is an array containing the keys which were passed into fieldsref
sub resolve_fields {
	my ($USERNAME,$orderset,$fieldsref) = @_;

	my @rows = ();
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my %dbfields = (
		'ship_fullname'=>'ORDER_BILL_NAME',
		'ship_state'=>'ORDER_BILL_ZONE',
		'created'=>'CREATED_GMT',
		'created_gmt'=>'CREATED_GMT',
		'pool'=>'POOL',
		'id'=>'ORDERID',
		'item_count'=>'ITEMS',
		'bill_zone'=>'ORDER_BILL_ZONE',
		'order_total'=>'ORDER_TOTAL',
		'payment_status'=>'ORDER_PAYMENT_STATUS',
		'payment_method'=>'ORDER_PAYMENT_METHOD',
		);
		

	## step1: can we get all the data from the db?
	my $dbokay = 1;
	foreach my $field (@{$fieldsref}) { 
		if (not defined $dbfields{$field}) { $dbokay=0; }
		# print STDERR "[$field] DBOKAY: $dbokay\n";
		}
#	$dbokay = 0;
#	die();

	## can we get everything from the database? If so, lets do that!
	if ($dbokay) {
		my $pstmt = '';

		my $odbh = &DBINFO::db_user_connect($USERNAME);
		foreach my $oid (@{$orderset}) { $pstmt .= $odbh->quote($oid).','; }
		chop($pstmt);

		$pstmt = "select * from ".&DBINFO::resolve_orders_tb($USERNAME,$MID)." where MID=$MID /* $USERNAME */ and ORDERID in ($pstmt)";
		my $sth = $odbh->prepare($pstmt);
		$sth->execute();
		while ( my $ref = $sth->fetchrow_hashref() ) {
			my @row = ();
			foreach my $field (@{$fieldsref}) { 
				push @row, $ref->{$dbfields{$field}};
				}
			push @rows, \@row;
			}
		$sth->finish();

		&DBINFO::db_user_close();
		}
	else {
		## looks like we need to go and open up each order file.
		foreach my $oid (@{$orderset}) {
			my ($O2) = CART2->new_from_oid($USERNAME,$oid);
			next if (not defined $O2);

			my $ref = $O2->get_legacy_order_attribs_as_hashref();
		
			if (not defined $ref->{'ship_firstname'}) { $ref->{'ship_firstname'} = ''}
			if (not defined $ref->{'ship_lastname'})  { $ref->{'ship_lastname'} = ''}
			my $customer_name = &ZOOVY::incode(ucfirst($ref->{'ship_firstname'}).' '.ucfirst($ref->{'ship_lastname'}));
			if ($customer_name eq ' ') { $customer_name = &ZOOVY::incode($ref->{'ship_fullname'}); }
			$ref->{'ship_fullname'} = $customer_name;
	
			if (not defined $ref->{'ship_state'}) { $ref->{'ship_state'} = ''; }
			$ref->{'ship_state'} = uc($ref->{'ship_state'});
	
			$ref->{'id'} = $oid;
			$ref->{'ship_zone'} = $ref->{'ship_city'}.', '.$ref->{'ship_state'};
			$ref->{'item_count'} = $ref->{'product_count'};
			$ref->{'payment_info'} = $ref->{'payment_method'}.': '.$ref->{'payment_status'};
			$ref->{'created_gmt'} = $ref->{'created'};
			
			my @row = ();
			# use Data::Dumper; push @row, Dumper($ref);
			foreach my $field (@{$fieldsref}) {
				push @row, $ref->{$field};
				}
			push @rows, \@row;
			$ref = undef;
			$O2 = undef;
			}
		}

	return(\@rows);
	}






###########################################
## ZORDER::list_orders
## parameters: MERCHANT_ID, STATE, TIMESTAMP (optional), FLAGS
## note: STATUS can be either "RECENT", "PENDING", "COMPLETED", "CANCELED", "" (returns everything)
## returns: a hash, keyed by DATE-ORDER_ID the value is a timestamp of the
##          the last time the order was last modified.
##				hashref keyed by orderid containing the created date (unixtime) as the value
##	FLAGS: bitwise operator, telling it what we want returned
##		1 = return CREATED hashref
##
##	possible options:
##			POOL=>RECENT,COMPLETED, etc.
##			TS=>timestamp from
##			MKT => a report by market (use bitwise value)
##			EREFID=>
##			LIMIT=>max record sreturns
##			CUSTOMER=> the cid of a particular customer.
##			DETAIL=>	1 - minimal (orderid + modified) 
##						3 - all of 1 + created, pool
##						5 - full detail
##						0xFF - just return objects
##			PRT=>0,1 (0 by default)
##
##############################################
sub report {
	my ($USERNAME,%options) = @_;

	if (!defined($USERNAME) || $USERNAME eq "") { return(undef); }
	my $MID = &ZOOVY::resolve_mid($USERNAME);


#+----------------------+------------------------------------------------------------------------------------+------+-----+---------+----------------+
#| Field                | Type                                                                               | Null | Key | Default | Extra          |
#+----------------------+------------------------------------------------------------------------------------+------+-----+---------+----------------+
#| ID                   | int(11) unsigned                                                                   | NO   | PRI | NULL    | auto_increment |
#| MERCHANT             | varchar(20)                                                                        | NO   |     | NULL    |                |
#| MID                  | int(11) unsigned                                                                   | NO   | MUL | 0       |                |
#| ORDERID              | varchar(20)                                                                        | NO   |     | NULL    |                |
#| CREATED_GMT          | int(10) unsigned                                                                   | NO   |     | 0       |                |
#| MODIFIED_GMT         | int(10) unsigned                                                                   | NO   |     | 0       |                |
#| CUSTOMER             | int(11) unsigned                                                                   | NO   |     | 0       |                |
#| POOL                 | enum('RECENT','PENDING','APPROVED','COMPLETED','DELETED','ARCHIVE','BACKORDER','') | NO   |     | NULL    |                |
#| ORDER_BILL_NAME      | varchar(30)                                                                        | NO   |     | NULL    |                |
#| ORDER_BILL_EMAIL     | varchar(30)                                                                        | NO   |     | NULL    |                |
#| ORDER_BILL_ZONE      | varchar(9)                                                                         | NO   |     | NULL    |                |
#| ORDER_PAYMENT_STATUS | char(3)                                                                            | NO   |     | NULL    |                |
#| ORDER_PAYMENT_METHOD | varchar(4)                                                                         | NO   |     | NULL    |                |
#| ORDER_TOTAL          | decimal(10,2)                                                                      | NO   |     | 0.00    |                |
#| ORDER_SPECIAL        | varchar(40)                                                                        | NO   |     | NULL    |                |
#| MKT                  | int(10) unsigned                                                                   | YES  |     | 0       |                |
#+----------------------+------------------------------------------------------------------------------------+------+-----+---------+----------------+

	$options{'DETAIL'} = int($options{'DETAIL'});
	  
	## NEW ORDER FORMAT
	#####################################
	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my $qtUSERNAME = $odbh->quote($USERNAME);


	if ($options{'EBAY'}) {
		## goes into the incomplete item table
		my $qtEBAYID = $odbh->quote($options{'EBAY'});
		my @OIDS = ();
		my $pstmt = "select ZOOVY_ORDERID from EXTERNAL_ITEMS where MID=$MID /* $USERNAME */  and MKT='ebay' and MKT_LISTINGID=$qtEBAYID";
		my $sth = $odbh->prepare($pstmt);
		$sth->execute();
		while ( my ($OID) = $sth->fetchrow() ) {
			push @OIDS, $OID;
			}
		$sth->finish();
		$options{'@OIDS'} = \@OIDS;
		}


	my $ORDERTB = &DBINFO::resolve_orders_tb($USERNAME,$MID);
	my %FIELDS = ();
	$FIELDS{'ORDERID'}++;
	$FIELDS{'MODIFIED_GMT'}++;

   if ($options{'@FIELDS'}) {
		## please use @FIELDS sparingly (try using detail level instead), and comment any place in the u/i that uses it here.
		## this is primarily for tom's reports on admin
      foreach my $k (@{$options{'@FIELDS'}}) { $FIELDS{$k}++; }
      }

	if ($options{'DETAIL'}>=3) { 
		$FIELDS{'POOL'}++;
		$FIELDS{'CREATED_GMT'}++;
		}
	if ($options{'DETAIL'}>=5) {
		$FIELDS{'CUSTOMER'}++;
		$FIELDS{'ORDER_BILL_NAME'}++;
		$FIELDS{'ORDER_BILL_EMAIL'}++;
		$FIELDS{'ORDER_BILL_ZONE'}++;
		$FIELDS{'ORDER_PAYMENT_STATUS'}++;
		$FIELDS{'ORDER_PAYMENT_METHOD'}++;
		$FIELDS{'ORDER_TOTAL'}++;
		$FIELDS{'ORDER_SPECIAL'}++;
		$FIELDS{'MKT'}++;
		$FIELDS{'MKT_BITSTR'}++;
		}
	if ($options{'DETAIL'}>=7) {
		$FIELDS{'PRT'}++;
		$FIELDS{'SHIPPED_GMT'}++;
		$FIELDS{'CUSTOMER'}++;
		$FIELDS{'ORDER_SHIP_NAME'}++;
		$FIELDS{'ORDER_SHIP_ZONE'}++;
		$FIELDS{'ORDER_BILL_NAME'}++;
		$FIELDS{'ORDER_BILL_EMAIL'}++;
		$FIELDS{'ORDER_BILL_ZONE'}++;
		$FIELDS{'ORDER_PAYMENT_STATUS'}++;
		$FIELDS{'ORDER_PAYMENT_METHOD'}++;
		$FIELDS{'ORDER_TOTAL'}++;
		$FIELDS{'ORDER_SPECIAL'}++;
		$FIELDS{'MKT'}++;
		$FIELDS{'MKT_BITSTR'}++;
		}
	if ($options{'DETAIL'}>=9) { 
		$FIELDS{'PRT'}++;
		$FIELDS{'SHIPPED_GMT'}++;
		$FIELDS{'CUSTOMER'}++;
		$FIELDS{'ORDER_SHIP_NAME'}++;
		$FIELDS{'ORDER_SHIP_ZONE'}++;
		$FIELDS{'ORDER_BILL_NAME'}++;
		$FIELDS{'ORDER_BILL_EMAIL'}++;
		$FIELDS{'ORDER_BILL_ZONE'}++;
		$FIELDS{'ORDER_PAYMENT_STATUS'}++;
		$FIELDS{'ORDER_PAYMENT_METHOD'}++;
		$FIELDS{'ORDER_TOTAL'}++;
		$FIELDS{'ORDER_SPECIAL'}++;
		$FIELDS{'MKT'}++;
		$FIELDS{'MKT_BITSTR'}++;
		$FIELDS{'REVIEW_STATUS'}++;
		$FIELDS{'ITEMS'}++;
		$FIELDS{'FLAGS'}++;
		$FIELDS{'SDOMAIN'}++;
		}

	if ($options{'DETAIL'}>=11) { 
		$FIELDS{'ORDER_EREFID'}++;
		}

	my $pstmt = '';
	my @USE_INDEX = ();
	if ((defined $options{'EREFID'}) && ($options{'EREFID'} ne '')) { 
		push @USE_INDEX, 'IN_EREFID';
		$pstmt .= " and ORDER_EREFID=".$odbh->quote(uc($options{'EREFID'})); 
		}
	if ((defined $options{'POOL'}) && ($options{'POOL'} ne '')) { 
		push @USE_INDEX, 'MID_2';
		$pstmt .= " and POOL=".$odbh->quote(uc($options{'POOL'})).' '; 
		}
	if ((defined $options{'CUSTOMER'}) && ($options{'CUSTOMER'}>0)) { 
		push @USE_INDEX, 'MID_3';
		$pstmt .= " and CUSTOMER=".int($options{'CUSTOMER'}).' '; 
		}
	# if (defined $options{'BILL_FULLNAME'}) { $pstmt .= " and ORDER_BILL_NAME like ".$odbh->quote("%$options{'BILL_FULLNAME'}%").' '; }
	if (defined $options{'BILL_FULLNAME'}) { $pstmt .= " /* WANTED TO USE BILL_FULLNAME LIKE */ "; }
	if (defined $options{'BILL_EMAIL'}) { $pstmt .= " and ORDER_BILL_EMAIL=".$odbh->quote("$options{'BILL_EMAIL'}").' '; }
	if (defined $options{'BILL_PHONE'}) { $pstmt .= " and ORDER_BILL_PHONE=".$odbh->quote("$options{'BILL_PHONE'}").' '; }
	# if (defined $options{'DATA'}) { $pstmt .= " and YAML like ".$odbh->quote("%$options{'DATA'}%").' '; }
	if (defined $options{'DATA'}) { $pstmt .= " /* WANTED TO USE DATA LIKE */ "; }

	# if (defined $options{'SHIP_FULLNAME'}) { $pstmt .= " and ORDER_SHIP_NAME like ".$odbh->quote("%$options{'SHIP_FULLNAME'}%").' '; }
	if (defined $options{'SHIP_FULLNAME'}) { $pstmt .= " /* WANTED TO USE BILL_FULLNAME LIKE */ "; }
	# if ((defined $KEY) && ($KEY ne '')) { $pstmt .= " and $KEY=".$odbh->quote($VALUE); }
	if ((defined $options{'TS'}) && ($options{'TS'}>0)) { 
		push @USE_INDEX, 'IN_MODIFIED';
		$pstmt .= " and MODIFIED_GMT>=".$odbh->quote(int($options{'TS'})); 
		}
	if ((defined $options{'CREATED_GMT'}) && ($options{'CREATED_GMT'}>0)) { $pstmt .= " and CREATED_GMT>=".$odbh->quote(int($options{'CREATED_GMT'})); }
	if ((defined $options{'CREATEDTILL_GMT'}) && ($options{'CREATEDTILL_GMT'}>0)) { $pstmt .= " and CREATED_GMT<".$odbh->quote(int($options{'CREATEDTILL_GMT'})); }
	if ((defined $options{'PAID_GMT'}) && ($options{'PAID_GMT'}>0)) { 
		push @USE_INDEX, 'MID_5';
		$pstmt .= " and PAID_GMT>=".$odbh->quote(int($options{'PAID_GMT'})); 
		}
	if ((defined $options{'PAIDTILL_GMT'}) && ($options{'PAIDTILL_GMT'}>0)) { $pstmt .= " and PAID_GMT<".$odbh->quote(int($options{'PAIDTILL_GMT'})); }
	if ((defined $options{'PAYMENT_STATUS'}) && ($options{'PAYMENT_STATUS'} ne '')) { $pstmt .= " and ORDER_PAYMENT_STATUS=".$odbh->quote($options{'PAYMENT_STATUS'}); }
	# if ((defined $options{'PAYMENT_STATUS_IS_PAID'}) && ($options{'PAYMENT_STATUS_IS_PAID'} ne '')) { $pstmt .= " and ORDER_PAYMENT_STATUS like '0%'"; }
	if ((defined $options{'PAYMENT_METHOD'}) && ($options{'PAYMENT_METHOD'} ne '')) { $pstmt .= " and ORDER_PAYMENT_METHOD=".$odbh->quote(substr($options{'PAYMENT_METHOD'},0,4)); }
	if ((defined $options{'SHIPPED_GMT'}) && ($options{'SHIPPED_GMT'}>0)) { $pstmt .= " and SHIPPED_GMT>=".$odbh->quote(int($options{'SHIPPED_GMT'})); }
	if ((defined $options{'SHIPPED_TILL'}) && ($options{'SHIPPED_TILL'}>0)) { $pstmt .= " and SHIPPED_GMT<=".$odbh->quote(int($options{'SHIPPED_TILL'})); }
	if (defined $options{'SDOMAIN'}) { $pstmt .= " and SDOMAIN=".$odbh->quote($options{'SDOMAIN'}); }
	if (defined $options{'ORDERID'}) { $pstmt .= " and ORDERID=".$odbh->quote($options{'ORDERID'}); }

	if ((defined $options{'PAYMENT_VERB'}) && ($options{'PAYMENT_VERB'} ne '')) {
		$pstmt .= " /* PAYMENT_VERB */ ";
		if ($options{'PAYMENT_VERB'} eq 'PAID') { $pstmt .= " and ORDER_PAYMENT_STATUS like '0%' "; }
		if ($options{'PAYMENT_VERB'} eq 'PENDING') { $pstmt .= " and ORDER_PAYMENT_STATUS like '1%' "; }
		if ($options{'PAYMENT_VERB'} eq 'DENIED') { $pstmt .= " and ORDER_PAYMENT_STATUS like '2%' "; }
		if ($options{'PAYMENT_VERB'} eq 'CANCELLED') { $pstmt .= " and ORDER_PAYMENT_STATUS like '3%' "; }
		if ($options{'PAYMENT_VERB'} eq 'REVIEW') { $pstmt .= " and ORDER_PAYMENT_STATUS like '4%' "; }
		if ($options{'PAYMENT_VERB'} eq 'PROCESSING') { $pstmt .= " and ORDER_PAYMENT_STATUS like '5%' "; }
		if ($options{'PAYMENT_VERB'} eq 'VOIDED') { $pstmt .= " and ORDER_PAYMENT_STATUS like '6%' "; }
		if ($options{'PAYMENT_VERB'} eq 'ERROR') { $pstmt .= " and ORDER_PAYMENT_STATUS like '9%' "; }
		if ($options{'PAYEMNT_VERB'} eq 'UNPAID') { $pstmt .= " and ORDER_PAYMENT_STATUS not like '0%' "; }
		}

	if (defined $options{'NEEDS_SYNC'}) { 
		push @USE_INDEX, 'IN_SYNCED';
		$pstmt .= " /* NEEDS_SYNC */ and SYNCED_GMT<=0 and SYNCED_GMT>=0 "; 
		}
	if (defined $options{'V'}) { $pstmt .= sprintf(" and V=%d ",$options{'V'}); }
	if (defined $options{'V<'}) { $pstmt .= sprintf(" and V<%d ",$options{'V<'}); }

	#if ((defined $options{'MKT'}) && ($options{'MKT'}>0)) {
	#	$pstmt .= sprintf(" and (MKT & %d)>0 ",$options{'MKT'});
	#	}
	if ((defined $options{'MKT'}) && ($options{'MKT'} ne '')) {
		## a faster way to resolve marketplace order lookups.
		## we got passed something like MKT=>'AMZ', we'll conver that to MKT_BIT
		$options{'MKT'} = uc($options{'MKT'});
		my ($result) = &ZOOVY::fetch_integration('dst'=>$options{'MKT'});
		if (not defined $result) { 
			$pstmt .= " and 1=0 /* MKT: $options{'MKT'} invalid */ "; 
			}
		else {
			$options{'MKT_BIT'} = $result->{'id'};
			}
		}

	if ((defined $options{'MKT_BIT'}) && ($options{'MKT_BIT'}>0)) {
		$pstmt .= " and ".&ZOOVY::bitstr_sql("MKT_BITSTR",[$options{'MKT_BIT'}]);
		}
	if ((defined $options{'@OIDS'}) && (ref($options{'@OIDS'}) eq 'ARRAY')) {
		## a specific set of orders.
		$pstmt .= " and ORDERID in ".&DBINFO::makeset($odbh,$options{'@OIDS'});
		}

	if ((defined $options{'WEB_SCOPE'}) && ($options{'WEB_SCOPE'}>0)) {
		my ($ts) = time()-(86400*365);
		$pstmt .= " and /* WEB_SCOPE */ CREATED_GMT>$ts ";
		}
	else {
		$pstmt .= sprintf(" /* %s !%s.%d */ ",join(";",&ZTOOLKIT::def(caller(0))),$0,$$);
		}

	## added 2008-06-04 - patti
	if ((defined $options{'PRT'}) && $options{'PRT'} >= 0) {	$pstmt .= " and PRT=".int($options{'PRT'}).' '; }

	# if ((defined $options{'LIMIT'}) && ($options{'LIMIT'} > 0)) { $pstmt .= " order by MODIFIED_GMT desc limit 0,".int($options{'LIMIT'}); }
	if ((defined $options{'LIMIT'}) && ($options{'LIMIT'} > 0)) { 
		if ((defined $options{'WEB_SCOPE'}) && ($options{'WEB_SCOPE'}>0)) {
			$pstmt .= " order by CREATED_GMT desc limit 0,".int($options{'LIMIT'}); 
			}
		else {
			$pstmt .= " order by ID desc limit 0,".int($options{'LIMIT'}); 
			}
		}
	

	## now build the actual pstmt
	$pstmt = "select ".
				(($options{'big'})?" SQL_BIG_RESULT SQL_BUFFER_RESULT ":'').
				join(',',keys %FIELDS).
				" from $ORDERTB ".
				## COMMENT OUT THE LINE BELOW IF ORDER STUFF ISN'T WORKING:
				#((scalar(@USE_INDEX)==0)?'':sprintf(" use index (%s)",join(',',@USE_INDEX))).
				" where MID=$MID /* MERCHANT=$qtUSERNAME */ ".
				$pstmt;

	print STDERR $pstmt."\n";

	my $sth = $odbh->prepare($pstmt);
	$sth->execute();
	my @x = ();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		push @x, $hashref;
		}   
	$sth->finish();
	&DBINFO::db_user_close();

	return(\@x);
	}



##
## returns an arrayref of orderid's that have changed since a date
##		this is used by buysafe
##
sub paid_since {
	my ($USERNAME,$TS) = @_;	

	my ($result) = ORDER::BATCH::report($USERNAME, PAID_GMT=>$TS,DETAIL=>1);
	my @ORDERS = ();
	foreach my $oref (@{$result}) {
		push @ORDERS, $oref->{'ORDERID'};
		}
	return(\@ORDERS);
	}



##
## Lists all the orders which have changed since a specific time.
##
sub list_orders {
	my ($USERNAME, $POOL, $TIMESTAMP_GMT, $LIMIT, $KEY, $VALUE) = @_;

	# quick fix.
	if ($POOL eq 'CANCELED') { $POOL = 'DELETED'; }
	elsif ($POOL eq 'CANCELLED') { $POOL = 'DELETED'; }
	
	# prepare variables
	my %ts = ();			# a hash keyed by order id with timestamps as value
	my %status = ();		# a hash keyed by order id with status as value
	my %created = (); 	# a hash keyed by order id with created (in db format) as the value

	my %options = (POOL=>$POOL, TS=>$TIMESTAMP_GMT,  LIMIT=>$LIMIT, DETAIL=>9);
	$options{'CREATED_GMT'} = ($TIMESTAMP_GMT-(86400*180));
	if ((defined $KEY) && ($KEY ne '')) {
		$options{$KEY} = $VALUE;
		}
	my $res = &ORDER::BATCH::report($USERNAME, %options);
	# use Data::Dumper; print STDERR Dumper($res);
	foreach my $x (@{$res}) {
		$ts{$x->{'ORDERID'}} = $x->{'MODIFIED_GMT'};
		$status{$x->{'ORDERID'}} = $x->{'POOL'};
		$created{$x->{'ORDERID'}} = $x->{'CREATED_GMT'};
		}

	return(\%ts,\%status,\%created,$res);
	}




#####
##
## parameters:
##		username
##		destination pool
##		reference to array containing order ids
##
sub change_pool {
	my ($USERNAME, $POOL, $orderref, $LUSERNAME) = @_;
	
	my $odbh = &DBINFO::db_user_connect($USERNAME);		# we open a persistent connection for speed!
	foreach my $order (@{$orderref}) {
		$order =~ s/[\s]+//gs;
		next if ($order eq '');
		my $app = $0; if (rindex($app,'/')) { $app = substr($app,rindex($app,'/')+1); }

		my ($O2) = CART2->new_from_oid($USERNAME,$order);
		$O2->in_set('flow/pool',$POOL);
		$O2->add_history("Order moved to status $POOL on web via $app",etype=>1+4,'luser'=>$LUSERNAME);
		$O2->order_save();
		}

	&DBINFO::db_user_close();
	}



#####
## returns an array of order-ids based on created_date
sub orderlist_by_month {
	my ($USERNAME, $MON, $YEAR) = @_;

	my $odbh = &DBINFO::db_user_connect($USERNAME);

	my @ar = ();
	$MON =~ s/\D//gis; # Strip non-digits
	$MON = $MON + 0; # Force numeric context (strips leading zeroes)
	$YEAR =~ s/\D//gis; # Strip non-digits
	$YEAR = $YEAR + 0; # Force numeric context (strips leading zeroes)
	my $qtUSERNAME = $odbh->quote($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	my $ORDERTB = &DBINFO::resolve_orders_tb($USERNAME,$MID);
	my $pstmt = "select ORDERID from $ORDERTB where MERCHANT=$qtUSERNAME and MID=$MID and MONTH(from_unixtime(CREATED_GMT))=$MON and YEAR(from_unixtime(CREATED_GMT))=$YEAR";
	# print STDERR "\$pstmt = '$pstmt'\n";
	my $sth= $odbh->prepare($pstmt);
	my $rv = $sth->execute();
	my ($id);
	if (defined($rv)) {
		while ( ($id) = $sth->fetchrow() ) {
			push @ar, $id;
			}
		} 
	$sth->finish();

	&DBINFO::db_user_close();
	
	return(@ar);
	}

1;
