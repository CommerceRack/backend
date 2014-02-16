package WAREHOUSE;

use strict;
use Clone;

use lib "/backend/lib";
require WAREHOUSE::ZONE;



@WAREHOUSE::ZONE_TYPES = (
	{ 'type'=>'RECEIVING', 'title'=>'Receiving Zone', 'hint'=>'Useful for cross dock shipping', },
	{ 'type'=>'STANDARD', 'title'=>'Standard', 'hint'=>'Row/Shelf/Bin', },
	{ 'type'=>'UNSTRUCTURED', 'title'=>'Unstructured', 'hint'=>'Supports any location format', },
#	{ 'type'=>'ADHOC', 'title'=>'Adhoc', 'hint'=>'Dynamic Locations', },
#	{ 'type'=>'BULK', 'title'=>'Bulk', 'hint'=>'Bulk storage (Row/Shelf only)' },
#	{ 'type'=>'STASH', 'title'=>'Stash', 'hint'=>'For one of a kind items', },
#	{ 'type'=>'VAULT', 'title'=>'Vault', 'hint'=>'individual item serial # tracking with Checkin+Checkout', },
#	{ 'type'=>'RETAIL', 'title'=>'Retail', 'hint'=>'Retail Storefront', },
#	{ 'type'=>'UNSORTED', 'title'=>'Unsorted', 'hint'=>'No positions (one big mess)', },
	);



sub TO_JSON {
	my ($self) = @_;
	
	my %clone = ();
	foreach my $k (keys %{$self}) {
		if (ref($self->{$k}) eq '') {
			$clone{$k} = $self->{$k};
			}
		else {
			$clone{$k} = Clone::clone($self->{$k});
			}
		}
	$clone{'_OBJECT'} = 'GEO';
 
	return(\%clone);
	}


#mysql> desc WAREHOUSE_ZONE_LOCATIONS;
#+----------------+------------------+------+-----+---------------------+----------------+
#| Field          | Type             | Null | Key | Default             | Extra          |
#+----------------+------------------+------+-----+---------------------+----------------+
#| ID             | int(10) unsigned | NO   | PRI | NULL                | auto_increment |
#| USERNAME       | varchar(20)      | NO   |     | NULL                |                |
#| MID            | int(10) unsigned | NO   | MUL | 0                   |                |
#| GEO | varchar(3)       | NO   |     | NULL                |                |
#| ZONE_CODE      | varchar(3)       | NO   |     | NULL                |                |
#| CREATED_TS     | timestamp        | NO   |     | 0000-00-00 00:00:00 |                |
#| CREATED_BY     | varchar(10)      | NO   |     | NULL                |                |
#| COUNTED_TS     | timestamp        | NO   |     | 0000-00-00 00:00:00 |                |
#| COUNTED_BY     | varchar(10)      | NO   |     | NULL                |                |
#| CHANGE_COUNT   | int(11)          | NO   |     | 0                   |                |
#| CHANGE_TS      | timestamp        | NO   |     | 0000-00-00 00:00:00 |                |
#| ROW            | varchar(3)       | NO   |     | NULL                |                |
#| SHELF          | varchar(3)       | NO   |     | NULL                |                |
#| SLOT           | varchar(3)       | NO   |     | NULL                |                |
#| ACCURACY       | tinyint(4)       | NO   |     | 0                   |                |
#+----------------+------------------+------+-----+---------------------+----------------+
#15 rows in set (0.01 sec)



#################################################################################################
##
##
#mysql> desc WAREHOUSE_ZONES;
#+-----------------+-------------------------------------------------------------------------+------+-----+---------------------+----------------+
#| Field           | Type                                                                    | Null | Key | Default             | Extra          |
#+-----------------+-------------------------------------------------------------------------+------+-----+---------------------+----------------+
#| ID              | int(10) unsigned                                                        | NO   | PRI | NULL                | auto_increment |
#| USERNAME        | varchar(20)                                                             | NO   |     | NULL                |                |
#| MID             | int(10) unsigned                                                        | NO   | MUL | 0                   |                |
#| GEO  | varchar(3)                                                              | NO   |     | NULL                |                |
#| ZONE_PRIORITY   | tinyint(4)                                                              | NO   |     | 0                   |                |
#| ZONE       | varchar(3)                                                              | NO   |     | NULL                |                |
#| ZONE_TITLE      | varchar(100)                                                            | NO   |     | NULL                |                |
#| ZONE_TYPE       | enum('RECEIVING','UNSORTED','STANDARD','BULK','STASH','VAULT','RETAIL') | YES  |     | NULL                |                |
#| ZONE_PREFERENCE | tinyint(3) unsigned                                                     | NO   |     | 0                   |                |
#| CREATED_TS      | timestamp                                                               | NO   |     | 0000-00-00 00:00:00 |                |
#| CREATED_BY      | varchar(10)                                                             | NO   |     | NULL                |                |
#+-----------------+-------------------------------------------------------------------------+------+-----+---------------------+----------------+
#11 rows in set (0.02 sec)
sub add_zone {
	my ($self, $zone, $type, %options) = @_;

	my $ERROR = '';
	my $found = 0;
	foreach my $zonetyperef (@WAREHOUSE::ZONE_TYPES) {
		if ($zonetyperef->{'type'} eq $type) { $found++; }
		}
	if (not $found) {
		$ERROR = "Unknown Zone Type: $type";
		}

	if (not $ERROR) {
		my ($udbh) = &DBINFO::db_user_connect($self->username());

		my $pstmt = "select count(*) from WAREHOUSE_ZONES where MID=".int($self->mid()).
						" and GEO=".$udbh->quote($self->code()).
						" and ZONE=".$udbh->quote($zone);
		my ($exists) = $udbh->selectrow_array($pstmt);

		my $pstmt = &DBINFO::insert($udbh,'WAREHOUSE_ZONES',{
			'USERNAME'=>$self->username(),
			'MID'=>$self->mid(),
			'GEO'=>$self->geo(),
			'ZONE'=>$zone,
			'ZONE_TYPE'=>$type,
			'ZONE_TITLE'=>sprintf("%s",$options{'TITLE'}),
			'ZONE_PREFERENCE'=>sprintf("%d",$options{'PREFERENCE'}),
			},sql=>1,update=>($exists)?2:0,'key'=>['MID','GEO','ZONE']);
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		&DBINFO::db_user_close();
		}

	return($ERROR);
	}



##
## lists all available zones for a specific warehouse
##
sub list_zones {
	my ($self, %filter) = @_;

	my @RESULTS = ();

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $pstmt = "select * from WAREHOUSE_ZONES where MID=".int($self->mid())." and GEO=".$udbh->quote($self->code());
	if (defined $filter{'zone'}) { $pstmt .= " and ZONE=".$udbh->quote($filter{'zone'}); }
	print STDERR "$pstmt\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $rowref = $sth->fetchrow_hashref() ) {
		push @RESULTS, WAREHOUSE::ZONE->new($self,$rowref->{'ZONE'},'%DBREF'=>$rowref);
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@RESULTS);
	}


sub zone {
	my ($self, $zone) = @_;
	if ($self->{'%ZONES'}->{$zone}) { return($self->{'%ZONES'}->{$zone}); }
	return($self->{'%ZONES'}->{$zone} = WAREHOUSE::ZONE->new($self,$zone));
	}


##
## delete a zone.
## 
sub delete_zone {
	my ($self, $zone_code) = @_;

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $pstmt = "delete from WAREHOUSE_ZONES where MID=".int($self->mid())." and GEO=".$udbh->quote($self->code())." and ZONE=".$udbh->quote($zone_code);
	print STDERR $pstmt."\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();	
	}



##
#mysql> desc WAREHOUSES;
#+--------------------------+------------------+------+-----+---------------------+----------------+
#| Field                    | Type             | Null | Key | Default             | Extra          |
#+--------------------------+------------------+------+-----+---------------------+----------------+
#| ID                       | int(10) unsigned | NO   | PRI | NULL                | auto_increment |
#| USERNAME                 | varchar(20)      | NO   |     | NULL                |                |
#| MID                      | int(10) unsigned | NO   | MUL | 0                   |                |
#| GEO           | varchar(3)       | NO   |     | NULL                |                |
#| WAREHOUSE_TITLE          | varchar(100)     | NO   |     | NULL                |                |
#| WAREHOUSE_ZIP            | varchar(12)      | NO   |     | NULL                |                |
#| WAREHOUSE_CITY           | varchar(30)      | NO   |     | NULL                |                |
#| WAREHOUSE_STATE          | varchar(2)       | NO   |     | NULL                |                |
#| CREATED_TS               | timestamp        | NO   |     | 0000-00-00 00:00:00 |                |
#| SHIPPING_LATENCY_IN_DAYS | tinyint(4)       | NO   |     | 0                   |                |
#| SHIPPING_CUTOFF_HOUR_PST | tinyint(4)       | NO   |     | 0                   |                |
#+--------------------------+------------------+------+-----+---------------------+----------------+
#11 rows in set (0.01 sec)
#
#	each warehouse may have multiple zones, or only one zone. 
#	each zone denotes a set of rules and behaviors within the warehouse 
#	and is intended to specify a physical geographic area inside the warehouse like a state within a country
#	each zone has it's own rules and regulations and behaviors (and in many cases database tables)
#		the zone concept allows us to (in the future) continue to expand functionality by adding new zone types
#		and the possibility of having multiple levels of functionality that can be charged at a premium.
#
#	this is a brief description of the type of zones
#	*RECEIVING : a special zone that has the ability to "cross dock" items
#					 when a shipment is marked as received the inventory is available inside the receiving zone
#					 until it is transferred to another zone. 
#	*UNSORTED  : a zone where no item locations are tracked, only quantities, usually used for unsorted
#				    locations such as returns/openbox/etc. 
#   *STANDARD  : a standard warehouse zone, brakes down into row, shelf, bin
#					 inventory has assigned locations in the warehouse along with a minimum and maximum number
#					 for that location. Standard zones support (and track) cycle counts.
#	*BACKORDER : items which were oversold, that are currently waiting (note: this should be represented as negative quantities)
#   --- FUTURE ---
#	*PREORDER  : items which were pre-sold, that are currently waiting for inventory to be received (note: negative quantity) - will probably use JIT shipping.
#	*BULK		  : a storage spot for cases of items, items are picked from here when the quantity in an order
#				    exceeds the quantity of a case. BULK zones are also used to fill standard zones. 
#   *STASH	  : items can be put into any availabe location, and when an item is added to a pick list it is marked
#					 as picked. each item in a stash zone stores it's location, and is unique. 
#	*VAULT	  : similar to a stash zone, except a vault zone has minimum quantities (overall) that it wants to
#					 maintain, but also tracks serial numbers and generates a specialized pick ticket that requires 
#					 a scanner.
#	*RETAIL	  : a retail zone is used for a retail storefront, inventory counts in a retail zone might be off
#					 and it's preference (in terms of picking) is much lower. 
#	 --- WAY FUTURE ---
#	*SPOOL	  : an area that tracks inventory by linear dimensions allowing for fractional inventory ex:
#					 3 inches, or 5.5 ft. or 7 yards.
#
#	Pick lists will be generated for each warehouse, and then we will try and find items within the same zone
#	based on the zone's priority.  
#
#	inside of a zone there might be rows, shelves, bins, cubbies
#	there might be pallets inside a bulk zone
#	there might be 


sub username { return($_[0]->{'USERNAME'}); }
sub mid { return(int($_[0]->{'MID'})); }
sub id { return($_[0]->{'ID'}); }
sub code { return($_[0]->{'GEO'}); }
sub geo { return($_[0]->{'GEO'}); }

##
##
##
sub new {
	my ($class, $USERNAME, %options) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	if ((defined $options{'CODE'}) && (not defined $options{'GEO'})) {
		warn "WAREHOUSE::new using CODE reference (don't do this)\n";
		$options{'GEO'} = $options{'CODE'};
		delete $options{'CODE'};
		}

	my $self = undef;
	if ($options{'DBREF'}) {
		$self = $options{'DBREF'};
		}
	elsif ($options{'GEO'}) {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select * from WAREHOUSES where MID=$MID and GEO=".$udbh->quote($options{'GEO'});
		($self) = $udbh->selectrow_hashref($pstmt);
		&DBINFO::db_user_close();
		}
	elsif ($options{'NEW'}) {
		$self = {
			'ID'=>0,
			'USERNAME'=>$USERNAME,
			'MID'=>&ZOOVY::resolve_mid($USERNAME),
			'CREATED_TS'=>&ZTOOLKIT::mysql_from_unixtime(time()),
			'MODIFIED_TS'=>0,
			'WAREHOUSE_TITLE'=>'New Warehouse',
			'GEO'=>$options{'NEW'},
			};
		}
	else {
		warn "WAREHOUSE was not created due to unknown option!\n";
		}

	if ((defined $self) && (ref($self) eq 'HASH')) {
		bless $self, 'WAREHOUSE';
		}

	return($self);
	}


#sub create_order {
#	my ($self, %options) = @_;
#	my ($vo) = WAREHOUSE::ORDER->new($self,%options);
#	return($vo);
#	}


sub get {
	my ($self,$property) = @_;
	return($self->{$property});
	}

sub set {
	my ($self,$property,$value) = @_;	
	$self->{$property} = $value;
	return($value);
	}


sub save {
	my ($self) = @_;

	my ($USERNAME) = $self->username();

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my %db = ();
	foreach my $k (keys %{$self}) {
		next if (substr($k,0,1) eq '_');	# hidden scalars
		next if (substr($k,0,1) eq '*');	# cached objects
		next if (substr($k,0,1) eq '@');	# arrays objects
		$db{$k} = $self->{$k};
		}

	my $is_update = 0;
	if ($self->{'ID'} == 0) { $is_update = 0; } else { $is_update = 2; }
	my $pstmt = &DBINFO::insert($udbh,'WAREHOUSES',\%db,key=>['MID','GEO'],sql=>1,update=>$is_update);
	print STDERR $pstmt."\n";
	$udbh->do($pstmt);

	&DBINFO::db_user_close();
	}

##
## returns a valid 6 digit vendor code.
##
sub valid_warehouse_code {
	my ($CODE) = @_;

	$CODE = uc($CODE);		# always uppercase
	$CODE =~ s/[^A-Z0-9]//gs;	# strip non-allowed characters
	if (length($CODE)>3) { $CODE = substr($CODE,0,-1); } # strip down to six characters
	while (length($CODE)<3) { $CODE .= '0'; }	# increase length to 6 digits by appending zeros
	return($CODE);
	}


sub exists {
	my ($USERNAME,$CODE) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select count(*) from WAREHOUSES where MID=$MID /* $USERNAME */ and GEO=".$udbh->quote($CODE);
	my ($exists) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();
	return($exists);
	}


sub nuke {
	my ($self) = @_;

	my ($USERNAME) = $self->username();
	my ($MID) = $self->mid();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "delete from WAREHOUSES where MID=$MID /* $USERNAME */ and GEO=".$udbh->quote($self->code());
	
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	
	}


##
##
##
sub lookup {
	my ($USERNAME,%filter) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my @RESULTS = ();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select * from WAREHOUSES where MID=$MID /* $USERNAME */ ";

	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		push @RESULTS, WAREHOUSE->new($USERNAME,'DBREF'=>$hashref);
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@RESULTS);
	}


1;
