package ORDER::SUPPLIER;

#use lib "/backend/lib";
#use DBINFO;
#use ZOOVY;

#create table SUPPLIER_ORDERS (
#   ID integer default 0 not null auto_increment,
#   MERCHANT varchar(20) default '' not null,
#   MID integer default 0 not null,
#
#   SUPPLIER varchar(6) default '' not null, 
#
#   SRC_ORDERID varchar(12) default '' not null,
#   ORDERID varchar(13) default '' not null,
#   
#   CREATED_GMT integer default 0 not null, 
#   DISPATCHED_GMT integer default 0 not null,
#
#   STATUS enum('','PENDING','PLACED','CONFIRMED') default '' not null,
#
#   unique(MID,SUPPLIER,ORDERID),
#   index(MID,SRC_ORDERID),
#   PRIMARY KEY(ID)
#);

##
## returns a hashref keyed by supplier orderid
##		value is: supplier pool | src orderid | createdgmt	
##
#sub list_orders {
#	my ($USERNAME,$SUPPLIER_CODE,$STATUS) = @_;
#
#	my %H = ();
#
#	my $dbh = &DBINFO::db_zoovy_connect();
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#
#	$pstmt = "select * from SUPPLIER_ORDERS where SRCMID=$MID ";
#	
#	if ($SUPPLIER_CODE ne '') {
#		$pstmt .= " and SUPPLIERCODE=".$dbh->quote($SUPPLIER_CODE);
#		}
#	if ($STATUS ne '') {
#		if ($STATUS eq 'NON_CONF') {
#			$pstmt .= " and CONF_GMT = '' ";
#			}
#		}
#		
#		
#	$pstmt .= " order by SRCORDER desc limit 300";
#
#
#	print STDERR $pstmt."\n";
#	
#	$sth = $dbh->prepare($pstmt);
#	$sth->execute();
#	
#	## make srcorder the key to sort on
#	while ( my $orderref = $sth->fetchrow_hashref() ) {
#		$H{$orderref->{'SRCORDER'}.$orderref->{'SUPPLIERCODE'}} = $orderref;
#		}
#	$sth->finish();	
#	&DBINFO::db_zoovy_close();
#	
#	return(\%H);
#	}
#
##
## returns a hashref keyed by supplier orderid
##		value is: supplier pool | src orderid | createdgmt	
##
## moved to SUPPLIER.pm
#sub list_orderitems {
#	my ($USERNAME,$SUPPLIER_CODE) = @_;
#
#	my %H = ();
#
#	my $dbh = &DBINFO::db_zoovy_connect();
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#	#require SUPPLIER::JEDI;
#	#my $SUPPLIER_USERNAME = &SUPPLIER::JEDI::resolve_jedi_username($USERNAME,$SUPPLIER_CODE);
#
#	$pstmt = "select SRCSKU,QTY,STATUS,SRCORDER,CREATED_GMT,SUPPLIEROID,ID from SUPPLIER_ORDERITEMS where SRCMID=$MID ".
#		" and SUPPLIERCODE=".$dbh->quote($SUPPLIER_CODE)." order by SRCORDER";
#
#	#print STDERR "supplier code: $SUPPLIER_CODE ".$pstmt."\n";
#	$sth = $dbh->prepare($pstmt);
#	$sth->execute();
#	while ( my ($sku,$qty,$stat,$srcoid,$cts,$soid,$id) = $sth->fetchrow() ) {
#		#print STDERR $srcoid."|".$sku."|".$qty."|". $stat."|".$srcoid."|".$cts."\n";
#		$H{$srcoid.$id} = $sku."|".$qty."|". $stat."|".$srcoid."|".$cts."|".$soid."|".$id;
#		}
#	$sth->finish();	
#	&DBINFO::db_zoovy_close();
#	
#	return(\%H);
#	}
#
#
#
#

1;
