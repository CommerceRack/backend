package VENDOR::ORDER;

require Data::GUID;
use lib "/backend/lib";


##
## we cache the vendor object within $self->{'*V'}
##
sub vendor {
	if (defined $_[0]->{'*V'}) {
		}
	else {
		$_[0]->{'*V'} = VENDOR->new($USERNAME,'CODE'=>$self->vcode());
		}
	return($_[0]->{'*V'});
	}

sub guid { return($_[0]->{'GUID'}); }
sub vcode { return($_[0]->{'VENDOR_CODE'}); }

#/* 
#	orders that Zoovy has created with a vendor 
#	for receiving orders should be able to be looked up (on the wireless scanner by either:
#		scan vendor_reference	 (note: result may not be unique)
#		scan our_reference		 (note: result mya not be unique)
#		search open orders (closed_gmt=0) 
#*/
#create table VENDOR_ORDERS (
#    ID integer unsigned auto_increment,
#    USERNAME varchar(20) default '' not null,
#    MID integer unsigned default 0 not null,
#    VENDOR_CODE varchar(6) default '' not null,		   
#    VENDOR_REFERENCE varchar(20) default '' not null,	 /* note: increased from 10, seemed too short */
#    OUR_REFERENCE varchar(20) default '' not null,		 /* an internal po # or something we reference */
#    CREATED_TS timestamp  default 0 not null,
#    CREATED_BY varchar(10) default '' not null,
#    APPROVED_TS timestamp  default 0 not null,			/* for now, anybody can approve po's, eventually user control */
#    APPROVED_BY varchar(10) default '' not null,
#    TRANSMISSION_TS timestamp  default 0 not null,		/* po's will not be transmitted until approved */
#    TRANSMISSION_RESULT tinytext default '' not null,
#    GUID varchar(32),										   /* used for jedi, and other edi/security protocols */
#    CLOSED_TS timestamp  default 0 not null,
#    ORDER_TOTAL decimal(10,2) default 0 not null,  /* select sum vendor */
#    primary key(ID),
#    unique (MID,VENDOR_CODE,GUID)
#	 );
#
sub new {
	my ($class, $v, %options) = @_;

	my ($USERNAME) = $v->username();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my $self = undef;
	if ($options{'DBREF'}) {
		$self = $options{'DBREF'};
		}
	elsif ($options{'VREFID'}) {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select * from VENDOR_ORDERS where MID=$MID and VENDOR_REFERENCE=".$udbh->quote($options{'VREFID'});
		($self) = $udbh->selectrow_hashref($pstmt);
		&DBINFO::db_user_close();
		}
	elsif ($options{'REFID'}) {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select * from VENDOR_ORDERS where MID=$MID and OUR_REFERENCE=".$udbh->quote($options{'REFID'});
		($self) = $udbh->selectrow_hashref($pstmt);
		&DBINFO::db_user_close();
		}
	elsif ($options{'GUID'}) {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select * from VENDOR_ORDERS where MID=$MID and GUID=".$udbh->quote($options{'GUID'});
		($self) = $udbh->selectrow_hashref($pstmt);
		&DBINFO::db_user_close();
		}
	elsif ($options{'NEW'}) {
		my ($GUID) = Data::GUID->new()->as_string();
		$self = {
			'ID'=>0,
			'USERNAME'=>$USERNAME,
			'MID'=>&ZOOVY::resolve_mid($USERNAME),
			'VENDOR_CODE'=>$v->code(),
			'VENDOR_REFERENCE'=>$options{'VREFID'},
			'CREATED_TS'=>&ZTOOLKIT::mysql_from_unixtime(time()),
			'APPROVED_TS'=>0,
			'APPROVED_BY'=>'',
			'GUID'=>$GUID,
			'ORDER_TOTAL'=>0,
			'@ITEMS'=>[],
			};
		}
	else {
		warn "VENDOR was not created due to unknown option!\n";
		}

	if ((defined $self) && (ref($self) eq 'HASH')) {
		bless $self, 'VENDOR::ORDER';
		}

	return($self);
	}


##
##
##
sub save {
	my ($self) = @_;

	my ($USERNAME) = $self->username();

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my %db = ();
	foreach my $k (keys %{$self}) {
		next if (substr($k,0,1) eq '_');	# hidden scalars
		next if (substr($k,0,1) eq '*');	# cached objects
		$db{$k} = $self->{$k};
		}
	my $is_update = 0;
	if ($self->{'ID'} == 0) { $is_update = 0; } else { $is_update = 2; }
	my $pstmt = &DBINFO::insert($udbh,'VENDOR_ORDERS',\%db,key=>['MID','VENDOR_CODE'],sql=>1,update=>$is_update);
	print STDERR $pstmt."\n";
	$udbh->do($pstmt);

	&DBINFO::db_user_close();
	}


sub log {
	my ($self) = @_;
	}

#/*
#	LINE_SKU will have special types for:
#	%SHIPPING
#	%WHATEVER
#	
#	NOTE: VENDOR_SKU is not unique, meaning one order can have the same SKU multiple items with different
#	expected dates.  The user interface should provide a "common sense" flow 
#*/
#create table VENDOR_ORDERITEMS (
#    ID integer unsigned auto_increment,
#    USERNAME varchar(20) default '' not null,
#    MID integer unsigned default 0 not null,
#    VENDOR_CODE varchar(6) default '' not null,
#    VENDOR_ORDER_ID integer unsigned default 0 not null,
#    VENDOR_SKU varchar(65) default '' not null,
#    OUR_SKU varchar(45) default '' not null,
#    OUR_NOTE varchar(128) default '' not null,
# 	 ITEM_ADDED_TS timestamp default 0 not null,
#    ITEM_ADDED_BY varchar(10) default '' not null,
#    ITEM_QTY_ORDERED integer unsigned default 0 not null,	/* this is the number we requested from vendor */
#    ITEM_QTY_RESERVED integer unsigned default 0 not null,  /* the number of units already spoken for */
#    ITEM_QTY_RECEIVED integer unsigned default 0 not null,	/* this is the number we received so far (also see VENDOR_ORDERITEMS_RECEIVED) */
#    ITEM_QTY_RETURNED integer unsigned default 0 not null,	/* this is reserved to track future returns */
#    ITEM_QTY_EXPECTED integer unsigned default 0 not null,	/* this is the number we expect to receive on ITEM_EXPECTED_GMT */
#    ITEM_EXPECTED_TS timestamp  default 0 not null, 
#	 ITEM_COST_I2 integer default 0 not null,	
#    TAGS_PRINTED integer default 0 not null,
#	 /* FUTURE: has orders waiting? */
#    primary key(ID),
#    unique(MID,VENDOR_CODE,VENDOR_ORDER_ID,VENDOR_SKU),
#);

##
##
##
sub add_item {
	my ($self, $SKU, $QUANTITY, $PRICE) = @_;

	my $ITEMSREF = $self->{'@ITEMS'};
	return;
	}


sub items { return($_[0]->{'@ITEMS'}); }


#
#
#/*
#	a log of items we've received, just like an event log in orders, it'd be NICE if this could match up to
#   VENDOR_ORDERITEMS.ITEM_QTY_RECEIVED .. but i'm not necessarily expecting that since we could be receiving
#   multiple items
#*/
#create table VENDOR_ORDERITEMS_RECEIVED (
#    ID integer unsigned auto_increment,
#    USERNAME varchar(20) default '' not null,
#    MID integer unsigned default 0 not null,
#    VENDOR_CODE varchar(6) default '' not null,
#    VENDOR_ORDER_ID integer unsigned default 0 not null,
#    OUR_SKU varchar(45) default '' not null,
#	 RECEIVED_GMT integer default 0 not null,
#    RECEIVED_QTY integer default 0 not null,
#	 RECEIVED_BY varchar(10) default '' not null,	/* which employee did this */
#	 TF_LABELS_PRINTED tinyint default 0 not null, 
#    primary key(ID)
#    index(MID)
#);
#


#
#
#
#/* 
#	An event log of things that have happened to a vendor.
#*/ 
#create table VENDOR_LOG (
#    ID integer unsigned auto_increment,
#    MID integer unsigned default 0 not null,
#    CREATED_TS timestamp  default 0 not null,
#    VENDOR_CODE varchar(6) default '' not null,
#    VENDOR_ORDER_ID integer unsigned default 0 not null,
#    VENDOR_SKU varchar(65) default '' not null,
#    NOTE	varchar(128) default '' not null,
#    primary key(ID)
#);



1;

