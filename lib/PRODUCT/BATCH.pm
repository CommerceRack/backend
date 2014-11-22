package PRODUCT::BATCH;

use strict;
use lib "/backend/lib";
require DBINFO;


##
## INVENTORY::resolve_sku
## PURPOSE: resolve sku from META data
## PARAMETERS: 
## - USERNAME
##	- type => META_SUPPLIERID or META_MFGID for example
## - id => value of the type
##
sub resolve_sku {
   my ($USERNAME, $type, $id, %options) = @_;

   my $MID = ZOOVY::resolve_mid($USERNAME);
	my ($lTB) = &ZOOVY::resolve_lookup_tb($USERNAME,$MID);
   my $udbh = &DBINFO::db_user_connect($USERNAME);

	my $SKU = undef;
	my $qtID = $udbh->quote($id);

	if ($type eq 'UPC') { 
	   my $pstmt = "select SKU from $lTB where UPC=$qtID and mid=$MID limit 1";
		($SKU) = $udbh->selectrow_array($pstmt);	
		}
	elsif (($type eq 'MFGID') || ($type eq 'MFGID')) {
	   my $pstmt = "select SKU from $lTB where MFGID=$qtID and mid=$MID limit 1";
		($SKU) = $udbh->selectrow_array($pstmt);	
		}
	elsif ($type eq 'SUPPLIER_SKU') {
		my ($qtSUPPLIER) = $udbh->quote($options{'SUPPLIER'});
	   my $pstmt = "select SKU from INVENTORY_DETAIL where SUPPLIER_ID=$qtSUPPLIER and SUPPLIER_SKU=$qtID and MID=$MID limit 1";
		($SKU) = $udbh->selectrow_array($pstmt);
		}
	else {
	##	warn "INVENTORY::sku_lookup called for unknown type[$type]\n";
		}
   DBINFO::db_user_close();

   return($SKU);
   }




sub resolveProductSelector {
	my ($USERNAME,$PRT,$SELECTORS) = @_;

	my $NC = undef;
	my $MANAGECATS = undef;

	my %PRODUCTS = ();
	foreach my $line (@{$SELECTORS}) {
		#'navcat=.safe.name',
		#'pids=xyz1,xyz2',
		#'search=xyz',
		#'all',
		my ($VERB,$value) = split(/=/,$line,2);
		$VERB = uc($VERB);
		# print "LINE: $line\n";

		my @PIDS = ();
		if ($VERB eq 'NAVCAT') {
			if (not defined $NC) { ($NC) = NAVCAT->new($USERNAME,PRT=>$PRT); }
			use Data::Dumper; print Dumper($NC->get($value));
			my ($pretty,$x,$products) = $NC->get($value);
			@PIDS = split(/,/,$products);
			}
		elsif ($VERB eq 'CSV') {
			foreach my $pid (split(/,/,$value)) {		
				$pid =~ s/^[\s]+//;
				$pid =~ s/[\s]+$//;
				push @PIDS, $pid;
				}
			}
		elsif ($VERB eq 'CREATED') {
			my ($start,$end) = split(/\|/,$value);
			my $begints = &ZTOOLKIT::mysql_to_unixtime($start."000000");
			my $endts = &ZTOOLKIT::mysql_to_unixtime($end."000000");

			require PRODUCT::BATCH;
			my $pids = &PRODUCT::BATCH::report($USERNAME,CREATED_BEFORE=>$endts,CREATED_SINCE=>$begints);
			@PIDS = @{$pids};
			}
		elsif ($VERB eq 'RANGE') {
			my @list = &ZOOVY::fetchproduct_list_by_merchant($USERNAME);
			my ($start,$end) = split(/\|/,$value);
			$start = &ZTOOLKIT::alphatonumeric($start);
			$end = &ZTOOLKIT::alphatonumeric($end);
			if ($start gt $end) { my $t = $start; $start = $end; $end = $t; }
			foreach my $p (sort @list) {
				my $i = &ZTOOLKIT::alphatonumeric($p);
		      if (($start <= $i) && ($end >= $i)) {
					push @PIDS, $p;
		         }
		      }
			}
		elsif ($VERB eq 'MANAGECAT') {
			require CATEGORY;
			if (not defined $MANAGECATS) { $MANAGECATS = &CATEGORY::fetchcategories($USERNAME); }
			@PIDS = split(/,/,$MANAGECATS->{$value});
			}
		elsif ($VERB eq 'SEARCH') {
			require SEARCH;
			my ($pids,$prodsref,$logref) = SEARCH::search($USERNAME,'CATALOG'=>'COMMON','LOG'=>0,'KEYWORDS'=>$value);
			@PIDS = @{$pids};
			}
		elsif ($VERB eq 'PROFILE') {
		   my $ARREF = &PRODUCT::BATCH::list_by_attrib($USERNAME,'zoovy:profile',$value);
			@PIDS = @{$ARREF};
			}
		elsif ($VERB eq 'SUPPLIER') {
			#my $ARREF = &PRODUCT::BATCH::list_by_attrib($USERNAME,'zoovy:prod_supplier',$value);
			#@PIDS = @{$ARREF};
			require INVENTORY2;
			my ($INV2) = INVENTORY2->new($USERNAME);
			my ($DETAILREF) = $INV2->detail('BASETYPE'=>'SUPPLIER', 'WHERE'=>[ 'SUPPLIER_ID', 'EQ', $value ]);
			my %PIDS = ();
			foreach my $row (@{$DETAILREF}) { $PIDS{ $row->{'PID'} }++; }
			@PIDS = keys %PIDS;
			}
		elsif ($VERB eq 'MFG') {
			my $ARREF = &PRODUCT::BATCH::list_by_attrib($USERNAME,'zoovy:prod_mfg',$value);
			@PIDS = @{$ARREF};
			}
		elsif ($VERB eq 'TAG') {
			## NOT IMPLEMENTED
			}
		elsif ($VERB eq 'ALL') {
			@PIDS = &ZOOVY::fetchproduct_list_by_merchant($USERNAME);
			# @PIDS = keys %{ZOOVY::fetchproducts_by_nameref($USERNAME)};
			}
		elsif ($VERB =~ /AMAZON-(PRODUCT|INVENTORY|ALL)-ERROR/) {
			## NOTE: $MASK values come from $AMAZON3::BW 
			my $MASK = 0;
			if ($1 eq 'PRODUCT') { $MASK |= 1; }
			if ($1 eq 'INVENTORY') { $MASK |= 16; }
			if ($1 eq 'ALL') { $MASK |= 1+2+4+8+16+32; }
			my ($udbh) = &DBINFO::db_user_connect($USERNAME);
			my $pstmt = "select PID, SKU, AMZ_ERROR from SKU_LOOKUP where AMZ_FEEDS_ERROR=AMZ_FEEDS_ERROR|$MASK";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			my %PIDS = ();
			while ( my ($PID, $SKU,$AMZ_ERROR) = $sth->fetchrow() ) {
				$PIDS{$PID}++;
				}
			$sth->finish();
			@PIDS = sort keys %PIDS;
			}

		if (scalar(@PIDS)>0) {
			foreach my $PID (@PIDS) {
				$PRODUCTS{$PID}++;
				}
			}
		}

	return(keys %PRODUCTS);
	}



sub report {
	my ($USERNAME, %params) = @_;

	my @results = ();

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &ZOOVY::resolve_product_tb($USERNAME);

	my $pstmt = "select PRODUCT from $TB where MID=$MID /* $USERNAME */";
	if ($params{'CREATED_BEFORE'}) {
		$pstmt .= " and CREATED_GMT<=".int($params{'CREATED_BEFORE'});
		}
	if ($params{'CREATED_SINCE'}) {
		$pstmt .= " and CREATED_GMT>=".int($params{'CREATED_SINCE'});
		}
	if ($params{'SUPPLIER'}) {
		$pstmt .= " and SUPPLIER=".$udbh->quote($params{'SUPPLIER'});
		}

	foreach my $attrib (keys %params) {
		next if ($attrib !~ /^zoovy\:([a-z_]+)$/);
		next if (not defined $ZOOVY::PRODKEYS->{$attrib});
		$pstmt .= " and $ZOOVY::PRODKEYS->{$attrib}=".$udbh->quote($params{$attrib});
		}


	print STDERR $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($PID) = $sth->fetchrow() ) {
		push @results, $PID;
		}
	$sth->finish();

	&DBINFO::db_user_close();

	return(\@results);
	}



##
## lastmodified returns most recent timestamp
##
sub lastmodified {
	my ($USERNAME) = @_;

	my $pdbh = &DBINFO::db_user_connect($USERNAME);

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &ZOOVY::resolve_product_tb($USERNAME);

	my $pstmt = "select TS from $TB where MID=$MID /* $USERNAME */ order by TS desc limit 0,1;";
	print STDERR $pstmt."\n";
	my ($count) = $pdbh->selectrow_array($pstmt);

	&DBINFO::db_user_close();
	return($count);
	}

##
## options
## navcat=>
##		all products in a specific navcat
##	schedule=>
##		products that are using schedule xyz
##
## returns number of products updated
##
sub updatetss {
	my ($USERNAME, %options) = @_;

	my $pdbh = &DBINFO::db_user_connect($USERNAME);

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &ZOOVY::resolve_product_tb($USERNAME);

	my $pstmt = "update $TB set TS=".time()." where MID=$MID /* $USERNAME */";
	print STDERR $pstmt."\n";
	my ($count) = $pdbh->do($pstmt);

	&DBINFO::db_user_close();
	return($count);
	} 


##
## A collection of functions designed to assist in handling/sorting through batches of products.
##

sub list_by_mkt {
	my ($USERNAME,$ATTRIB,$VALUE) = @_;

	$ATTRIB = $ZOOVY::PRODKEYS->{$ATTRIB};
	if (!$USERNAME) { return (undef); }
	if (!$ATTRIB) { return(undef); }

	my $pdbh = &DBINFO::db_user_connect($USERNAME);

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &ZOOVY::resolve_product_tb($USERNAME);

	my $pstmt = "select PRODUCT from $TB where MID=$MID /* $USERNAME */ and $ATTRIB=".$pdbh->quote($VALUE);
	print STDERR $pstmt."\n";
	my $sth   = $pdbh->prepare($pstmt);
	$sth->execute();
	my @AR = ();
	while ( my ($PID) = $sth->fetchrow() ) { push @AR, $PID; }
	$sth->finish();
	&DBINFO::db_user_close();
	
	return(\@AR);
	}

##
## returns an arrayref of PIDs that have a specific attribute e.g. zoovy:supplier=ABC
##
sub list_by_attrib {
	my ($USERNAME,$ATTRIB,$VALUE) = @_;

	print STDERR "$USERNAME,$ATTRIB,$VALUE\n";
	## resolve attribute
	
	$ATTRIB = $ZOOVY::PRODKEYS->{$ATTRIB};
	# print STDERR "ATTRIB: $ATTRIB\n";

	## NOTE: this can be replaced by PRODUCT::BATCH::report now

	if (!$USERNAME) { return (undef); }
	if (!$ATTRIB) { return(undef); }

	my $pdbh = &DBINFO::db_user_connect($USERNAME);

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &ZOOVY::resolve_product_tb($USERNAME);

	my $pstmt = "select PRODUCT from $TB where MID=$MID and $ATTRIB=".$pdbh->quote($VALUE);
	print STDERR $pstmt."\n";
	my $sth   = $pdbh->prepare($pstmt);
	$sth->execute();
	my @AR = ();
	while ( my ($PID) = $sth->fetchrow() ) { push @AR, $PID; }
	$sth->finish();
	&DBINFO::db_user_close();
	
	return(\@AR);
	}


##
## returns an arrayref of PIDs that have a specific attribute e.g. zoovy:supplier=ABC
##
sub count_by_attrib {
	my ($USERNAME,$ATTRIB,$VALUE) = @_;

	print STDERR "$USERNAME,$ATTRIB,$VALUE\n";
	## resolve attribute
	
	$ATTRIB = $ZOOVY::PRODKEYS->{$ATTRIB};
	# print STDERR "ATTRIB: $ATTRIB\n";

	if (!$USERNAME) { return(0); }
	if (!$ATTRIB) { return(0); }

	my $pdbh = &DBINFO::db_user_connect($USERNAME);

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &ZOOVY::resolve_product_tb($USERNAME);

	my $pstmt = "select count(*) from $TB where MID=$MID and $ATTRIB=".$pdbh->quote($VALUE);
	print STDERR $pstmt."\n";
	my $sth   = $pdbh->prepare($pstmt);
	$sth->execute();
	my ($count) = $sth->fetchrow();
	$sth->finish();
	&DBINFO::db_user_close();
	
	return($count);
	}



##
## returns a hashref of possible values for a given pid (nothing in key)
##
sub group_by_attrib {
	my ($USERNAME,$ATTRIB) = @_;

	$ATTRIB = $ZOOVY::PRODKEYS->{$ATTRIB};
	if (!$USERNAME) { return (); }
	if (!$ATTRIB) { return(); }


	my $pdbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &ZOOVY::resolve_product_tb($USERNAME);

	my $pstmt = "select $ATTRIB from $TB where MID=$MID group by $ATTRIB";
	my $result = $pdbh->selectcol_arrayref($pstmt);
	&DBINFO::db_user_close();

	return($result);
	}


sub sort_by_attrib {
	my ($USERNAME,$ATTRIB,$productsar) = @_;

	$ATTRIB = $ZOOVY::PRODKEYS->{$ATTRIB}; 
	if (!$USERNAME) { return (undef); }
	if (!$ATTRIB) { return(undef); }

	my @result = ();
	if (scalar(@{$productsar})==0) {
		return(@result);
		}

	my $pdbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &ZOOVY::resolve_product_tb($USERNAME);
	
	my $pstmt = '';
	foreach my $pid (@{$productsar}) { $pstmt .= $pdbh->quote($pid).',';	} 
	chop $pstmt;	# remove the trailing ,
	$pstmt = "select PRODUCT from $TB where MID=$MID and PRODUCT in ($pstmt) order by $ATTRIB";
	# print STDERR $pstmt."\n";
	my $sth = $pdbh->prepare($pstmt);
	$sth->execute();
	while ( my ($pid) = $sth->fetchrow() ) {
		push @result, $pid;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	
	return(@result);
	}

##
## returns products order by a specific attribute e.g. CREATED_GMT
##		note: eventually it'd be handy to pass in a "set" of products (e.g. array of pids) and be able to sort by it.
##
sub order_by_attrib {
	my ($USERNAME,$ATTRIB,$LIMIT,$ORDER) = @_;
	

	if (defined $ZOOVY::PRODKEYS->{$ATTRIB}) { $ATTRIB = $ZOOVY::PRODKEYS->{$ATTRIB}; }
	if (!$USERNAME) { return (undef); }
	if (!$ATTRIB) { return(undef); }

	my $pdbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &ZOOVY::resolve_product_tb($USERNAME);

	my $pstmt = "select PRODUCT from $TB where MID=$MID order by $ATTRIB ";
	if ($ORDER eq 'desc') { $pstmt .= ' desc'; }
	if ($LIMIT>0) { $pstmt .= " limit 0,".int($LIMIT); }

	print STDERR "!!!" .$pstmt."\n\n\n";

	my $result = $pdbh->selectcol_arrayref($pstmt);
	&DBINFO::db_user_close();
	return($result);
	}

##
##
##
sub fetchcategories {
	my ($USERNAME,$pidarray) = @_;

	my $pdbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &ZOOVY::resolve_product_tb($USERNAME);

	my $pstmt = "select PRODUCT,CATEGORY from $TB where MID=$MID ";
	if (not defined $pidarray) {
		## 
		}
	elsif (ref($pidarray) eq 'ARRAY') {
		$pstmt .= " and PRODUCT in ".&DBINFO::makeset($pdbh,$pidarray);
		}
	my $sth = $pdbh->prepare($pstmt);
	$sth->execute();

	my %PIDS = ();
	while ( my ($pid,$category) = $sth->fetchrow() ) {
		$PIDS{$pid} = $category;
		}
	$sth->finish();

	&DBINFO::db_user_close();
	return(\%PIDS);
	}


1;
