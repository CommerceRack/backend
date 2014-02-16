package ZWMS;

use strict;
use lib "/backend/lib"; 
require WAREHOUSE;
require ZTOOLKIT;


@ZWMS::CONDITIONS_DETAIL = (
	[ 'NEW', 'New with tags/unopened' ],
	[ 'OPEN', 'New other (packaging may be damaged, opened, but otherwise in-tact)' ],
	[ 'REFURB', 'Manufacturer Refurbished' ],
	[ 'SREFURB', 'Seller Reburbished' ],
	[ 'USED', 'Previously owned, may have cosmetic signs of wear but unit is fully operational' ],
	[ 'OTHER', 'Other' ],
	[ 'DAMAGED', 'item is damaged / not fully operational, requires repair' ],
	[ 'UNINSPECTED', 'Return Received but needs inspection/verification' ],
	);

@ZWMS::CONDITIONS = ('NEW','OPEN','REFURB','SREFURB','USED','OTHER','DAMAGED','UNINSPECTED');

sub xenc { return(&ZTOOLKIT::buildparams(@_)); }
sub xdec { if (scalar(@_)==0) { return({}); } else { return(&ZTOOLKIT::parseparams(@_)); } }

##
## also check location.
##

sub parse_update {
	my ($USERNAME,$lines,%options) = @_;

	##
	##	ADD:10\tSKU\tWAREHOUSE*ZONE*ROW-SHELF-BIN\tLU=user&key=value
	## DEC:10\tSKU\tWAREHOUSE*ZONE*ROW-SHELF-BIN
	##	SET:10\tSKU\tWAREHOUSE*ZONE*ROW-SHELF-BIN\tLU=user
	##
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	
	foreach my $line (@{$lines}) {
		next if ($line eq '');
		my ($VERB,$SKU,$location,$kvparams) = split(/[\^\s\t]/,$line,4);
		my $params = &ZWMS::xdec($kvparams);
		my ($GEO,$ZONE,$POS) = &ZWMS::locparse($location);
		my $CONDITION = 0;

		print STDERR "LINE: $line\nVERB[$VERB] SKU[$SKU] LOC[$location] KV[$kvparams]\n";

#mysql> desc WAREHOUSE_ZONE_LOCATION_INVENTORY;
#+-------------+------------------------------------------------------------------------------+------+-----+---------+-------+
#| Field       | Type                                                                         | Null | Key | Default | Extra |
#+-------------+------------------------------------------------------------------------------+------+-----+---------+-------+
#| MID         | int(10) unsigned                                                             | NO   | PRI | 0       |       |
#| GEO         | varchar(3)                                                                   | NO   | PRI | NULL    |       |
#| ZONE        | varchar(3)                                                                   | NO   | PRI | NULL    |       |
#| POS         | varchar(12)                                                                  | NO   | PRI | NULL    |       |
#| SKU         | varchar(35)                                                                  | NO   | PRI | NULL    |       |
#| QTY         | int(11)                                                                      | NO   | PRI | 0       |       |
#| COST_I      | int(10) unsigned                                                             | NO   |     | 0       |       |
#| COND        | enum('NEW','OPEN','REFURB','SREFURB','USED','OTHER','DAMAGED','UNINSPECTED') | NO   | PRI | NEW     |       |
#| NOTE        | varchar(25)                                                                  | NO   | PRI | NULL    |       |
#| CONTAINERID | varchar(8)                                                                   | NO   |     | NULL    |       |
#| ORIGIN      | varchar(16)                                                                  | NO   |     | NULL    |       |
#+-------------+------------------------------------------------------------------------------+------+-----+---------+-------+
#11 rows in set (0.01 sec)
		my %KEYS = ();
		$KEYS{'MID'} = $MID;

		my $exists = -1;
		if ($params->{'ID'}>0) {
			$exists = int($params->{'ID'});
			$KEYS{'ID'} =  int($params->{'ID'});
			$KEYS{'SKU'} = $SKU;
			}
		else {
			$KEYS{'GEO'} = $GEO;
			$KEYS{'ZONE'} = $ZONE;
			$KEYS{'POS'} = $POS;
			$KEYS{'SKU'} = $SKU;
			}

		## NOTE: for now we assume that the following fields (if available) will be used
		##			in the future  we might do more filtering/validation by warehouse type.
		## unique(MID,SKU,GEO,ZONE,POS,COND,CONTAINER,NOTE),
		if ($params->{'COND'}) { $KEYS{'COND'} = sprintf("%s",$params->{'COND'}); }
		if ($params->{'NOTE'}) { $KEYS{'NOTE'} = sprintf("%s",$params->{'NOTE'}); }
		if ($params->{'CONTAINER'}) { $KEYS{'CONTAINER'} = sprintf("%s",$params->{'CONTAINER'}); }
		
		if ($exists<0) {
			my $pstmt = "/* LOCATION ID LOOKUP */ select count(*),max(ID) from WAREHOUSE_ZONE_LOCATION_INVENTORY where ";
			foreach my $k (keys %KEYS) { $pstmt .= "$k=".$udbh->quote($KEYS{$k})." and "; }
			$pstmt = substr($pstmt,0,-5); # remove ' and ' from $pstmt
			my ($count,$ID) = $udbh->selectrow_array($pstmt);
			if ($count>0) {
				if ($count>1) {
					## bad situation, non-unique row - throw a warning!
					}
				$exists = $ID;
				%KEYS = ('MID'=>$MID,'ID'=>$ID);
				}
			else {
				$exists = 0;
				}
			}

		## SANITY: at this point we are guaranteed to have $exists be set to 0 (new row) or the ID in the database


		if ($VERB =~ /^(PUT)\:([\d]+)$/) {
			## PUT a new SKU to inventory (accepts origin, etc.), also updates
			## an insert (note: is this allowed?)
			my ($cmd,$QTY) = ($1,$2);
			my %vars = ('MID'=>$MID,'GEO'=>$GEO,'ZONE'=>$ZONE,'POS'=>$POS,'SKU'=>$SKU,'COND'=>$CONDITION);
			$vars{'*QTY'} = int($QTY);
			if ($params->{'COST'}) { $vars{'COST_I'} = sprintf("%d",$params->{'COST'}*100); }
			if ($params->{'COND'}) { $vars{'COND'} = sprintf("%s",$params->{'COND'}); }
			if ($params->{'NOTE'}) { $vars{'NOTE'} = sprintf("%s",$params->{'NOTE'}); }
			if ($params->{'CONTAINER'}) { $vars{'CONTAINER'} = sprintf("%s",$params->{'CONTAINER'}); }
			if ($params->{'ORIGIN'}) { $vars{'ORIGIN'} = sprintf("%s",$params->{'ORIGIN'}); }

			my ($pstmt) = &DBINFO::insert($udbh,'WAREHOUSE_ZONE_LOCATION_INVENTORY',\%vars,
				'sql'=>1,'update'=>(($exists>0)?0:1),keys=>\%KEYS);
			print STDERR "$pstmt\n";
			$udbh->do($pstmt);
			}
		elsif ($VERB =~ /^(INC|SET|DEC)\:([\d]+)$/) {
			my ($cmd,$QTY) = ($1,$2);

			if ($cmd eq 'DEC') { $cmd='INC'; $QTY = 0 - $QTY; }	# DEC:10 (decrement 10) is the same as ADD:-10

			my $QTYVAR = 0;
			if ($VERB eq 'SET') {
				$QTYVAR = int($QTY);
				}
			else {
				$QTYVAR = "QTY+$QTY";
				}
			
			if ($exists==0) {
				## throw warning, can't inc/dec a row that doesn't exist
				}
			else {
				my ($pstmt) = &DBINFO::insert($udbh,'WAREHOUSE_ZONE_LOCATION_INVENTORY',{'*QTY'=>$QTY},
					'sql'=>1,'update'=>2,keys=>\%KEYS);
				print STDERR "$pstmt\n";
				$udbh->do($pstmt);
				}
			}
		else {
			warn "UNKNOWN VERB:$VERB\n";
			}
		}	
	&DBINFO::db_user_close();

	return();
	}


##
## for now locparse uses tight formatting rules
##		WAREHOUSE*ZONE*ROW-SHELF-BIN 
##
sub locparse {
	my ($loc) = @_;
	my ($WH,$ZONE,$POS) = ();
	if ($loc =~ /^([A-Z0-9]{3,3})[\.\*\:]{1,1}([A-Z0-9]+)[\.\*\:]{1,1}(.*?)$/) {
		($WH,$ZONE,$POS) = ($1,$2,$3);
		}
	elsif ($loc =~ /^([A-Z0-9]+)[\.\*\:]{1,1}(.*?)$/) {
		($ZONE,$POS) = ($1,$2);
		}
	elsif ($loc =~ /^(.*?)$/) {
		($POS) = ($1);
		}
	return($WH,$ZONE,$POS);
	}

##
## note: always use this function, no matter how simple it may be to copy.
##			because this will get more complex in the future.
##			
sub locify {
	my ($WAREHOUSE,$ZONE,$POSITION) = @_;
	return("$WAREHOUSE\*$ZONE\:$POSITION");
	}

##
##
##
sub is_valid_location {
	my ($USERNAME,$LOC,%options) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($GEO,$ZONE,$POS) = &ZWMS::locparse(uc($LOC));

	my $INVALID_REASON = undef;
	my $is_valid = 0;

	## step1: verify warehouse
	my ($W) = WAREHOUSE->new($USERNAME,'GEO'=>$GEO);
	my ($zoneref) = $W->get_zone($ZONE);

	if (not defined $W) {
		$INVALID_REASON = "WAREHOUSE:$GEO was not found";
		}
	elsif ($zoneref->{'ZONE_TYPE'} eq 'RECEIVING') {
		#*RECEIVING : a special zone that has the ability to "cross dock" items
		#			 when a shipment is marked as received the inventory is available inside the receiving zone
		#			 until it is transferred to another zone. 
		if ($POS eq 'DOCK') { 
			$is_valid++; 
			}
		else {
			$INVALID_REASON = "ZONE TYPE:RECEIVING only supports POSITIONS:DOCK"; 
			}
		}
	elsif ($zoneref->{'ZONE_TYPE'} eq 'UNSORTED') {
		#*UNSORTED  : a zone where no item locations are tracked, only quantities, usually used for unsorted
		#		    locations such as returns/openbox/etc. 
		if ($POS eq '') { $is_valid++; }
		else {
			$INVALID_REASON = "ZONE TYPE:UNSORTED does not allow POSITIONS"; 
			}
		}
	elsif (($zoneref->{'ZONE_TYPE'} eq 'STANDARD') || ($zoneref->{'ZONE_TYPE'} eq 'BULK')) {
 	 	# *STANDARD  : a standard warehouse zone, brakes down into row, shelf, bin
		#			 inventory has assigned locations in the warehouse along with a minimum and maximum number
		#			 for that location. Standard zones support (and track) cycle counts.
		my ($ROW,$SHELF,$SLOT) = split(/\-/,$POS);
		my $pstmt = "select count(*) from WAREHOUSE_ZONE_LOCATIONS where MID=$MID ".
						"and GEO=".$udbh->quote($GEO).
						" and ZONE=".$udbh->quote($ZONE).
						" and ROW=".$udbh->quote($ROW).
						" and SHELF=".$udbh->quote($SHELF).
						" and SLOT=".$udbh->quote($SLOT);
		# $options{'*LM'}->pooshmsg("INFO|+$pstmt");
		($is_valid) = $udbh->selectrow_array($pstmt);
		if (not $is_valid) {
			$INVALID_REASON = "ZONE TYPE:$zoneref->{'ZONE_TYPE'} ZONE:$ZONE does not have ROW:$ROW SHELF:$SHELF SLOT:$SLOT defined";
			}
		}
	else {
		$INVALID_REASON = "UNKNOWN ZONE_TYPE: $zoneref->{'ZONE_TYPE'}";		
		}
	#elsif ($zoneref->{'ZONE_TYPE'} eq 'BACKORDER') {
	#	# *BACKORDER : items which were oversold, that are currently waiting (note: this should be represented as negative quantities)
	#	}
   #--- FUTURE ---
	#*PREORDER  : items which were pre-sold, that are currently waiting for inventory to be received (note: negative quantity) - will probably use JIT shipping.
	#*BULK		  : a storage spot for cases of items, items are picked from here when the quantity in an order
	#			    exceeds the quantity of a case. BULK zones are also used to fill standard zones. 
   #*STASH	  : items can be put into any availabe location, and when an item is added to a pick list it is marked
	#				 as picked. each item in a stash zone stores it's location, and is unique. 
	#*VAULT	  : similar to a stash zone, except a vault zone has minimum quantities (overall) that it wants to
	#				 maintain, but also tracks serial numbers and generates a specialized pick ticket that requires 
	#				 a scanner.
	#*RETAIL	  : a retail zone is used for a retail storefront, inventory counts in a retail zone might be off
	#				 and it's preference (in terms of picking) is much lower. 
	# --- WAY FUTURE ---
	#*SPOOL	  : an area that tracks inventory by linear dimensions allowing for fractional inventory ex:
	#				 3 inches, or 5.5 ft. or 7 yards.
	#	}
	#elsif ($zoneref->{'ZONE_TYPE'} eq 'BULK') 
	if ((not $is_valid) && ($options{'*LM'})) {
		$options{'*LM'}->pooshmsg("ERROR|+$LOC invalid - $INVALID_REASON");
		}

	&DBINFO::db_user_close();
	return($is_valid);
	}



1;
