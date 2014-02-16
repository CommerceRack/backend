package SUPPLIER;

use lib "/backend/lib";
use Data::Dumper;
use strict;
use YAML::Syck;
require ZOOVY;
require CART2;

##
##
##
sub for_json {
	my ($self,$REF) = @_;

	if (not defined $REF) { $REF = {}; }

	## 
	foreach my $k (
		'CODE','FORMAT','MARKUP',
		'NAME','PHONE','EMAIL','PASSWORD','WEBSITE','ACCOUNT',
		'CREATED_GMT','LASTSAVE_GMT',
		'PREFERENCE',
		'PRODUCT_CONNECTOR',
		'SHIP_CONNECTOR',
		'INVENTORY_CONNECTOR',
		'ORDER_CONNECTOR',
		'TRACK_CONNECTOR',
		) {
		$REF->{"$k"} = $self->{$k};
		}	

	#my ($ref) = &ZOOVY::fetchmerchantns_ref($self->username(),$self->profile());
	#foreach my $k ('email','company_name','phone','address1','address2','city','countrycode','postal') {
	#	$REF->{'%COMPANY'}->{"$k"} = $ref->{"zoovy:$k"};
	#	}

	$REF->{'%OUR'} = {};
	$REF->{'%PRODUCT'} = {};
	$REF->{'%SHIP'} =  {};
	$REF->{'%ORDER'} = {};
	$REF->{'%INVENTORY'} = {};
	$REF->{'%TRACKING'} = {};

	foreach my $k (keys %{$self->{'%INIDATA'}}) {
		if ($k =~ /^\.order\.(.*?)$/) {
			$REF->{'%ORDER'}->{$1} = $self->{'%INIDATA'}->{$k};
			}
		elsif ($k =~ /^\.ship\.(.*?)$/) {
			$REF->{'%SHIP'}->{$1} = $self->{'%INIDATA'}->{$k};
			}
		elsif ($k =~ /^\.track\.(.*?)$/) {
			$REF->{'%TRACKING'}->{$1} = $self->{'%INIDATA'}->{$k};
			}
		elsif ($k =~ /^\.product\.(.*?)$/) {
			$REF->{'%PRODUCT'}->{$1} = $self->{'%INIDATA'}->{$k};
			}
		elsif ($k =~ /^\.inv\.(.*?)$/) {
			$REF->{'%INVENTORY'}->{$1} = $self->{'%INIDATA'}->{$k};
			}
		elsif ($k =~ /^\.our\.(.*?)$/) {
			$REF->{'%OUR'}->{$1} = $self->{'%INIDATA'}->{$k};
			}
		else {
			print STDERR "$k\n";
			}
		}

	return($REF);
	}


##
## 
##
sub run_macro_cmds {
	my ($self, $CMDS, %params) = @_;

	my $errs = 0;
	my $LU = $params{'*LU'};

	my $lm = $params{'*LM'};
	if (not defined $lm) { $lm = LISTING::MSGS->new(); }

	my ($echo) = 0;
	my @RESULTS = ();

	

	return($lm);
	}


#mysql> desc SUPPLIERS;
## see at bottom of code for conversion done 7/24/2008
#| ID                   | int(10) unsigned
#| | NO | PRI | NULL | auto_increment | MID | int(11) | NO | MUL | 0 | |
#| USERNAME | varchar(20) | NO | | NULL | | CODE | varchar(10) | NO | | NULL
#| | | PROFILE | varchar(30) | YES | | NULL | | MODE |
#| enum('JEDI','API','GENERIC','PARTNER','') | NO | | NULL | | FORMAT |
#| enum('DROPSHIP','FULFILL','STOCK','NONE','') | NO | | NULL | | MARKUP |
#| varchar(25) | NO | | NULL | | NAME | varchar(60) | NO | | NULL | | PHONE
#| | varchar(12) | NO | | NULL | | EMAIL | varchar(65) | NO | | NULL | |
#| WEBSITE | varchar(65) | NO | | NULL | | ACCOUNT | varchar(30) | YES | |
#| NULL | | INIDATA | text | NO | | NULL | | PARTNER |
#| enum('SHIPWIRE','QB','DOBA','ATLAST','FBA')


##
##
## this needs to return a CART2 object
##
##	ONLY called from SUPPLIER::API
## 
#sub assemble_v1_order {
#	my ($S,$SOIDREF,$ADDRREF,$ITEMSAR) = @_;
#	return($O);
#	}



sub inv_connector { my ($self) = @_; return($self->fetch_property('INVENTORY_CONNECTOR')); }
sub order_connector { my ($self) = @_; return($self->fetch_property('ORDER_CONNECTOR')); }
sub ship_connector { my ($self) = @_; return($self->fetch_property('SHIP_CONNECTOR')); }



##
## currently only built for ORDER CONFs
##
## note:
##		- couldn't find a current example, so not sure this is the correct way
##		- currently being used in spaparts API (on pub1)
sub from_xml {
	my ($USERNAME, $xml, $METHOD, $ACTION, $XCOMPAT) = @_;

	my $ERROR = '';

	print STDERR "SUPPLIER::from_xml\nUSERNAME: $USERNAME METHOD: $METHOD ACTION: $ACTION XCOMPAT: $XCOMPAT\nxml:\n$xml\n";

	## ORDER
	if ($METHOD eq 'ORDER') {
		## only ACTION is currently CONFIRMATION
		if ($ACTION eq 'CONFIRMATION') {
			if ($xml =~ /<ORDER(.*?)>(.*?)<\/ORDER>/s) {	
				my $ATTRIB = $1; 
				my $order_xml = $2; 

				## find ORDER NUMBER
				my $ordernum = '';
				if ($ATTRIB =~ / ID="(.*?)"/) { $ordernum = $1; }
				if ($ordernum eq '') { $ERROR = "Unknown Order Number"; }
				
				if ($ERROR eq '') {
					if ($order_xml =~ /<TRACKING>(.*?)<\/TRACKING>/s) {
						my $tracking_xml = $1;
						## find TRACKING INFO
						my $trackref = &ZTOOLKIT::xmlish_to_hashref($tracking_xml,'decoder'=>'latin1');
						if ($trackref->{'TRACKING_NUMBER'} eq '') { $ERROR = "Unknown Tracking Number"; }

						if ($ERROR eq '') {						
							my @errors = SUPPLIER::confirm_order($USERNAME,$ordernum,undef,undef,$trackref->{'SHIP_METHOD'},$trackref->{'TRACKING_NUMBER'},$trackref->{'CONF_PERSON'},undef,undef);
					
							$ERROR .= join(", ", @errors) 
							}
						}
					}	
				}
			}

		else { $ERROR = "Unknown Supplier Order ACTION: $ACTION"; }
		}

	else { $ERROR = "Unknown Supplier METHOD: $METHOD"; }


	return($ERROR,$xml);
	}
#
##
## Converts a decimal [base 10] number into it's alpha [base26] equivalent where A=1, Z=26, AA=27, AB=28
##
## (done)
sub base26 { 
	my ($i) = @_;
	my @ar = ('A'..'Z');
	my $out = '';
	while ($i > 0) {
		if ($i<27) { $out = $ar[$i-1].$out; $i = 0; }
		else { $out = $ar[($i-1) % 26].$out; $i = int(($i-1) / 26); }
		}
	return($out);
	}

## note: ship_method may be a full method or just the carrier
## (done)
sub confirm_order {
	my ($USERNAME, $srcorder, $supplierorderid, $conf_ordertotal, $ship_method, $ship_num, $conf_person, $conf_email, $supplier_orderitem, $cost) = @_;
	my @errors = ();	
	
	my $MID = ZOOVY::resolve_mid($USERNAME);
	require DBINFO;
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	
	## check for valid order number (ie Reference Number)
	if ($srcorder eq '') { push @errors, "Reference Number required."; }

	my $suppliercode = '';
	my $status = '';
	if (scalar(@errors) == 0) {
		## VALIDATION
		my $id = ''; 
		my $pstmt = "select ID, STATUS, VENDOR from VENDOR_ORDERS where OUR_ORDERID = ".$udbh->quote($srcorder).
			" and /* $USERNAME */ MID=".int($MID);
		print STDERR $pstmt."\n";
		($id,$status,$suppliercode) = $udbh->selectrow_array($pstmt);
	
		## check for valid order number (ie Reference Number)
		if ($id eq '') { push @errors, "Reference Number was not originally dispatched to this Supplier."; }
		
		print STDERR "$id,$status,$suppliercode\n";
		
		}
	
	my ($S) = SUPPLIER->new($USERNAME,$suppliercode);
	if ($suppliercode ne '' && (not defined $S || ref($S) ne 'SUPPLIER')) {
      push @errors, "Invalid Supplier user=$USERNAME supplier=$suppliercode";
      }
			
	## check for valid status
	## removing this check but not adding addl add_historys if tracking info is the same
	#if ($status eq 'CONFIRMED') { push @errors, "ERROR: This order has already been confirmed."; }

	## check if confirmation email if valid (currently optional)
	if ($conf_email ne '') {
		require ZTOOLKIT;
		my $valid = ZTOOLKIT::validate_email($conf_email);
		if ($valid == 0) { push @errors, "Invalid Email Address."; }
		}

	## UPDATE VENDOR_ORDERS
	if (scalar(@errors) == 0) {
		my $pstmt = "update VENDOR_ORDERS set status = 'CONFIRMED', conf_person=".$udbh->quote($conf_person).
						",conf_email=".$udbh->quote($conf_email).",conf_ordertotal=".$udbh->quote($conf_ordertotal).
						",conf_gmt=".time().",VENDOR_REFID=".$udbh->quote($supplierorderid).
						" where OUR_ORDERID = ".$udbh->quote($srcorder)." and MID = ".$udbh->quote($MID);
		print STDERR $pstmt."\n";
		print STDERR $udbh->do($pstmt);


		require CART2;
		my ($O2) = CART2->new_from_oid($USERNAME,$srcorder);

		if (defined $O2) {
			## if available, add tracking information to srcorder
			## note: there are 3 variables used to desc shipping;
			##		ship method [data.shp_method]: UPS Ground
			##		carrier [tracking.carrier]: UPS
			##		carrier code [data.shp_carrier]: UGND
			## ORDER::set_tracking currently uses the carrier and tracking number,
			##		this may be switched to carrier code in the near future
			if ($ship_method ne '' || $ship_num ne '') {
				print STDERR "update tracking in order\n";
				my $carrier = '';
				my $notes = 'Supplier update';

				## check if the Supplier has confirmed with a standard carrier
				require ZSHIP;
				if (defined $ZSHIP::SHIPCODES{$ship_method}) {
					$carrier = $ship_method;
					}
				## if not, they may have sent a long desc of method (ie "UPS GROUND COMMERCIAL")
				##		send the correct carrier and put the long desc in the tracking notes
				elsif ($ship_method =~ /UPS/i) { $carrier = 'UPS'; }
				elsif ($ship_method =~ /USPS/i) { $carrier = 'USPS'; }
				elsif ($ship_method =~ /FED/i) { $carrier = 'FEDX'; }
				elsif ($ship_method =~ /DHL/i) { $carrier = 'DHL'; }
				## if the method is not recognized, send OTHR for the carrier and add method to notes
				else { $carrier = 'OTHR'; }
				## add any non-standard method info to the notes
				if ($carrier ne $ship_method) { $notes = $ship_method;	}

				print STDERR "SET TRACKING: $carrier,$ship_num,$notes\n";
				my $repeat = $O2->set_tracking($carrier,$ship_num,$notes,$cost);
				print STDERR "REPEAT: $repeat\n";

				## only update as needed
				if ($status ne 'CONFIRMED') {
					## update VENDOR_ORDERS table
					print STDERR $pstmt."\n";
					print STDERR $udbh->do($pstmt);
					}
				
				## only add add_historys if this tracking info hasnt already been added
				if (not $repeat) {

					$O2->add_history("Order confirmed by Warehouse/Supplier: $conf_person (".$conf_email.")",etype=>16);
					$O2->add_history("Order tracking info added by Warehouse/Supplier ($carrier : $ship_num)",etype=>16+1);
				
					## check if Supplier is configured to show Supplier code 
					## and tracking info (ie add to item notes) on a per order item basis
					## supplier_orderitem is currently only sent from DOBA (ATLAST,FBA,SHIPWIRE are soon to follow)
					if ($S->fetch_property('ITEM_NOTES') == 1 && $supplier_orderitem ne '') {
						## get translation from supplier_id tp SKU
						my $item = $O2->stuff2()->item('stid'=>uc($supplier_orderitem));
						if (defined $item) {
							$item->{'notes'} .= " $carrier - $ship_num";
							}
						}
					}
				else {
					push @errors, "This order has already been confirmed.";
					}
					
				}
			else {
				$O2->add_history("Order confirmed by Warehouse/Supplier: $conf_person (".$conf_email.")",etype=>16);	
				}
			
			if ($supplierorderid ne '') {
				$O2->add_history("Dispatched SC Order $suppliercode .$supplierorderid");
				# print STDERR "Dispatched SC Order: $supplierorderid to $suppliercode\n";
				}
				
			print STDERR "Saving order: ".$O2->oid()."\n";
			$O2->order_save();
			}
		else { 
			print STDERR "Unable to write add_historys for order: $USERNAME $srcorder (possibly STOCK?)\n"; 
			}
		}
		

	&DBINFO::db_user_close();
	
	## return any errors
	return(@errors);
	}



sub username { return($_[0]->{'USERNAME'}); }
sub profile { return($_[0]->{'PROFILE'}); }
sub mid { return($_[0]->{'MID'}); }

sub id { return($_[0]->{'CODE'}); }
sub code { return($_[0]->{'CODE'}); }
## | MODE         | enum('JEDI','API','GENERIC','PARTNER','')      | YES  |     | NULL    |                |
# sub mode { return($_[0]->{'MODE'}); }
## | FORMAT       | enum('DROPSHIP','FULFILL','STOCK','NONE','')   | NO   |     | NULL    |                |
sub format { return($_[0]->{'FORMAT'}); }
sub partner { return($_[0]->{'PARTNER'}); }


## 
## input: MID
## output: code, name, mode, format
##
sub list_suppliers {
	my ($USERNAME) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select CODE,NAME,FORMAT from SUPPLIERS where MID=$MID";
	print STDERR $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my $count = 0;
	my ($hashref) = $sth->fetchall_hashref('CODE');
	$sth->finish();
	
	return($hashref);
	}
	

##
## serialize SUPPLIERS.INIDATA
## (done)
sub encodeini {
	my ($paramsref) = @_;

	my $txt = "\n";
	foreach my $k (sort keys %{$paramsref}) {
		next if (substr($k,0,1) eq '?');
		#next if ($k eq '');
		## take care of newlines, or they will save/display properly
		$paramsref->{$k} =~ s/\n/\\n/gm;
		$paramsref->{$k} =~ s/\r/\\r/gm;

		$txt .= "$k=$paramsref->{$k}\n";
		}
	return($txt);
	}

##
## deserialize SUPPLIERS.INIDATA
## (done)
sub decodeini {
	my ($initxt) = @_;

	my %result = ();
	my $prev_k = '';
	foreach my $line (split(/[\n]+/,$initxt)) {
		#my ($k,$v) = split(/=/,$line,2);
		#print "LINE: $line\n";
		my ($k,$v) = split(/=/,$line,2);
	
		## decode newlines
		$v =~ s/\\n/\n/gm;
		$v =~ s/\\r/\r/gm;

		$result{$k} = $v;
		# print STDERR "K: $k V: $v\n";
		## data has newlines (prepended by ='s)
		#if (($k eq '' || not defined $k)) { 
		#	$result{$prev_k} .= "\n".$v; 
		#	}
		#elsif ($v ne '') {
     	#	$result{$k} = $v;
		#	$prev_k = $k;
		#	}
		}


	# print Dumper(\%result);
	return(\%result);
	}


##
## update SUPPLIER_ORDERITEM table
## (done)
#sub update_orderitem {
#	my ($ID, $USERNAME, %options) = @_;
#
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#	
#	my $udbh = &DBINFO::db_user_connect($USERNAME);
#	foreach my $opt (keys %options) {
#		my $pstmt = "update VENDOR_ORDERITEMS set $opt=".$udbh->quote($options{$opt}).
#						" where ID=".$udbh->quote($ID)." and MID=".$udbh->quote($MID);
#		$udbh->do($pstmt);
#		}
#
#	DBINFO::db_zoovy_close();
#	}


##
## returns a hashref keyed by supplier orderid
##		value is: supplier pool | src orderid | createdgmt	
## moved from ORDER::SUPPLIER
##
## options
##		- STATUS => NON_CONF -> list non-confirmed orders
##
#sub list_orders {
#	my ($self, %options) = @_;
#
#	
#	return(\%H);
#	}

##
## returns a hashref keyed by supplier orderid
##		value is: supplier pool | src orderid | createdgmt	
##
## moved from ORDER::SUPPLIER
##
## options:
##		STATUS=>['NEW','ADDED']
##
#sub list_orderitems {
#	my ($self,%options) = @_;
#	my $USERNAME = $self->{'USERNAME'};
#
#	
#	return(\@ROWS);
#	}


##
## api call to create a supplier.
##
sub create {
	my ($USERNAME,$CODE,%options) = @_;

	my $ERROR = undef;

	if ($USERNAME eq '') { $ERROR = "USERNAME not set"; }

	$CODE = uc($CODE);
	if ($CODE =~ /^[^A-Z0-9]+$/) { $ERROR = "CODE must contain only A-Z0-0"; }
	if (not $options{'reserved_allowed'}) {
		if ($CODE eq 'GIFTCARD') { $ERROR = "GIFTCARD is a reserved supplier"; }
		if ($CODE eq 'LOYALTY') { $ERROR = "LOYALTY is a reserved supplier"; }
		if ($CODE eq 'REWARDS') { $ERROR = "REWARDS is a reserved supplier"; }
		}
	
	my ($MID) = -1;
	if (not defined $ERROR) {
		$MID = &ZOOVY::resolve_mid($USERNAME);
		if ($MID <= 0) { $ERROR = "Could not resolve MID for USERNAME"; }
		}
	
	if (not defined $ERROR) {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = &DBINFO::insert($udbh,'SUPPLIERS',{
			'MID'=>$MID,
			'USERNAME'=>$USERNAME,
			'CODE'=>sprintf("%s",$CODE),
#			'PROFILE'=>sprintf("%s",$options{'PROFILE'}),
#			'MODE'=>sprintf("%s",$options{'MODE'}),
#			'PARTNER'=>sprintf("%s",$options{'PARTNER'}),
#			'FORMAT'=>sprintf("%s",$options{'FORMAT'}),
			'MARKUP'=>sprintf("%s",$options{'MARKUP'}),
			'NAME'=>sprintf("%s",$options{'NAME'}),
			'PHONE'=>sprintf("%s",$options{'PHONE'}),
			'EMAIL'=>sprintf("%s",$options{'EMAIL'}),
#			'PASSWORD'=>sprintf("%s",sprintf("%s",$options{'PASSWORD'})),
			'WEBSITE'=>sprintf("%s",sprintf("%s",$options{'WEBSITE'})),
			'ACCOUNT'=>sprintf("%s",$options{'ACCOUNT'}),
			'CREATED_GMT'=>time(),
			'LASTSAVE_GMT'=>time(),
			'INIDATA'=>YAML::Syck::Dump({}),
			'PRODUCT_CONNECTOR'=>'NONE',
			'SHIP_CONNECTOR'=>'NONE',
			'INVENTORY_CONNECTOR'=>'NONE',
			'ORDER_CONNECTOR'=>'NONE',
			'TRACK_CONNECTOR'=>'NONE',
			}, key=>['MID','CODE'],update=>0,debug=>1,sql=>1);
		my $rv = $udbh->do($pstmt);
		if (not defined $rv) {
			$ERROR = "Could not insert SUPPLIER into database";
			}
		&DBINFO::db_user_close();
		}

	if (defined $ERROR) {
		## return no CODE when we have an error.
		$CODE = undef;
		}
	return($CODE,$ERROR);
	}


##
## Returns: undef on error
##		note if "CODE" begins with a # e.g. #1234 then it's assumed to be a supplier mid
##
## (done)
sub new {
	my ($class, $USERNAME, $CODE, %options) = @_;

	my $self = {};
	

	$USERNAME = uc($USERNAME);
	$CODE = uc($CODE);

	my $MID = int(&ZOOVY::resolve_mid($USERNAME));

	print STDERR "SC USERNAME[$USERNAME] SUPPLIER[$CODE]\n";
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my $pstmt = "select * from SUPPLIERS where MID=$MID ";
	if (substr($CODE,0,1) eq '#') {
		## lookup supplier by JEDI MID e.g. #1234
		$pstmt .= " and JEDI_MID=".int(substr($CODE,1));
		}
	#elsif (index($CODE,':')>0) { 		## note: remember index goes "haystack", "needle"
	#	## e.g. TYPE:CODE .. GENERIC:HAPPY1 
	#	## DEPRECATED - DONT USE THIS METHOD
	#	&ZOOVY::confess($USERNAME,"DONT CALL SUPPLIER NEW WITH A : in THE CODE",justkidding=>1);
	#	my ($type,$code) = split(/:/,$CODE);
	#	if (substr($code,0,9) eq 'GIFTCARD') {
	#		## Special handler to emulate a "GIFTCARD" supplier
	#		$self = { USERNAME=>$USERNAME, MID=>&ZOOVY::resolve_mid($USERNAME), MODE=>"GIFTCARD", FORMAT=>"GIFTCARD", '.api.dispatch_on_create'=>0 };
	#		}
	#	$pstmt .= " and CODE=".$udbh->quote($code);
	#	}
	elsif ($CODE eq 'GIFTCARD') {
		## Special handler to emulate a "GIFTCARD" supplier
		$self = { 
			USERNAME=>$USERNAME, MID=>&ZOOVY::resolve_mid($USERNAME), 'SHIP_CONNECTOR'=>'FREE', 'MODE'=>"GIFTCARD", 'FORMAT'=>"GIFTCARD", '.api.dispatch_on_create'=>0 
			};
		}
	else {
		## lookup supplier by code (default)
		$pstmt .= " and CODE=".$udbh->quote($CODE);
		}

	if (not defined $self->{'USERNAME'}) {
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		if ($sth->rows()>0) {
			($self) = $sth->fetchrow_hashref();
			}
		else{
			$self = undef;	
			}
		$sth->finish();
		}

	&DBINFO::db_user_close();

	if ((not defined $self) && (defined $options{'create'}) && ($options{'create'}>0)) {
		$self = {
			'USERNAME'=>$USERNAME,
			'CODE'=>$CODE,
			};
		}

	if (not defined $self) {
		}
	elsif (substr($self->{'INIDATA'},0,3) eq '---') {
		$self->{'%INIDATA'} = &YAML::Syck::Load($self->{'INIDATA'});
		}
	else {
		$self->{'%INIDATA'} = &decodeini($self->{'INIDATA'});
		}

	if (defined $self) {
		bless $self, 'SUPPLIER';	
		if (not defined $self->{'_CHANGES'}) { $self->{'_CHANGES'}=0; }
		}

	#	#if ($self->{'MID'} == int($self->{'%INIDATA'}->{'.jedi.mid'}) || $self->{'USERNAME'} eq $self->{'%INIDATA'}->{'.jedi.username'}) {
	#	if ($self->{'MID'} == int($self->{'JEDI_MID'}) || $self->{'USERNAME'} eq $self->{'%INIDATA'}->{'.jedi.username'}) {
	#		warn "SUPPLIER.pm returned undef for USERNAME=[$USERNAME] CODE=[$CODE] -- JEDI setup incorrectly\n";
	#		return(undef);
	#		}
	#	}
	#elsif ($sth->rows()<=0 && (defined $options{'NEW'})) {
	#	$self->{'CODE'} = $CODE;
	#	$self->{'USERNAME'} = $USERNAME;
	#	$self->{'MID'} = $MID;
#
#		## new supplier
#		$self->{'_CHANGES'}=0;	## we use _CHANGES to see if the INFO section changed.
#		}
#	else {
#		## Yeowza! the supplier doesn't exist? return an undef! -- error!
#	 	warn "Supplier.pm returned undef for USERNAME=[$USERNAME] CODE=[$CODE]\n";
#		$self = undef;
#		}


	return($self);
	}


##
## this is called by inventory.pl to add a sku to an "open" order for a stock supplier.
##
## (done)
#sub stock_ordersku {
#	my ($self,$SKU,$QTY) = @_;
#
#		
#	my ($udbh) = &DBINFO::db_user_connect($self->username());
#	#my $pstmt = "select ID from SUPPLIER_ORDERITEMS where SUPPLIEROID=0 and SRCMID=$self->{'MID'} /* $self->{'USERNAME'} */ ".
#	#				"and SUPPLIERCODE=".$udbh->quote($self=>{'CODE'})." and SRCSKU=".$udbh->quote($SKU);
#	my $pstmt = "select ID from VENDOR_ORDERITEMS where MID=$self->{'MID'} /* $self->{'USERNAME'} */ ".
#					"and VENDOR=".$udbh->quote($self=>{'CODE'})." and SKU=".$udbh->quote($SKU);
#	my $sth = $udbh->prepare($pstmt);
#	$sth->execute();
#	my ($ROWID) = $sth->fetchrow();
#	$sth->finish();
#
#	if (($ROWID == 0) || (not defined $ROWID)) {
#		my ($P) = PRODUCT->new( $self->username(), $SKU );
#		# my $skuref = &ZOOVY::fetchsku_as_hashref($self->{'USERNAME'},$SKU);
#
#		## get correct base_cost and prod_name for SKU
#		#require POGS;
#		# POGS::apply_options($self->{'USERNAME'}, $SKU, $skuref);
#		# $skuref->{'zoovy:prod_name'} =~ s/\n/ /g;
#
#		my $SUPPLIERSKU = $P->skufetch($SKU,'zoovy:prod_supplierid');
#		if ($SUPPLIERSKU eq '') { $SUPPLIERSKU = $P->skufetch($SKU,'zoovy:prod_mfgid'); }
#		if ($SUPPLIERSKU eq '') { $SUPPLIERSKU = $SKU; }
#
#		my $TITLE = $P->skufetch($SKU,'sku:title');
#		$TITLE =~ s/[\n]/ /gs;
#		
#		my ($pstmt) = &DBINFO::insert($udbh,'SUPPLIER_ORDERITEMS',{
#			MID=>$self->{'MID'}, 
#			USERNAME=>$self->{'USERNAME'},
#			ORDERID=>time(),
#			SKU=>$SKU,
#			STID=>$SKU,
#			QTY=>$QTY,
#			COST=> $P->fetch('zoovy:base_cost'),
#			DESCRIPTION=> $TITLE,
#			STATUS=>'NEW',
#			CREATED_GMT=>time(),
#			MODIFIED_GMT=>time(),
#			SUPPLIEROID=>0,
#			SUPPLIERCODE=> $self->{'CODE'},
#			SUPPLIERSKU=> $SUPPLIERSKU,
#			},'verb'=>'insert','sql'=>1);
#		$udbh->do($pstmt);
#		}
#	else {
#		$pstmt = "update SUPPLIER_ORDERITEMS set MODIFIED_GMT=".time().",QTY=".int($QTY).
#					" where QTY<$QTY and MID=$self->{'MID'} /* $self->{'USERNAME'} */ and ID=$ROWID";
##		print STDERR $pstmt."\n";
#		$udbh->do($pstmt);
#		}
#
#	
#	&DBINFO::db_user_close();
#
#	}


##
## returns a hash containing:
##		CODE, COMPANY_NAME, COMPANY_EMAIL, COMPANY_PHONE
## (being removed)
#sub fetch_info {
#	my ($self) = @_;
#	return($self->{'INFO'});
#	}

##
## save
##
## want to add CREATED_GMT, LASTSAVE_GMT
## (done)

sub save {
	my ($self,$force) = @_;	
	my @ERRORS = ();

	my ($udbh) = &DBINFO::db_user_connect($self->username());

	if ($force) { $self->{'_CHANGES'}++; }

	if ((not defined $self->{'_CHANGES'}) || ( $self->{'_CHANGES'} == 0)) {
		## no reason to save, nothing changed in the object.
		}
	elsif (scalar(@ERRORS)>0) {
		## errors occurred, don't save anything.
		}
	else {
		my $pstmt = &DBINFO::insert($udbh,'SUPPLIERS',{
			'MID'=>$self->{'MID'},
			'USERNAME'=>$self->{'USERNAME'},
			'CODE'=>$self->{'CODE'},
#			'PROFILE'=>$self->{'PROFILE'},
			'PREFERENCE'=>$self->{'PREFERENCE'},
			'MODE'=>$self->{'MODE'},
			'PARTNER'=>$self->{'PARTNER'},
			'FORMAT'=>$self->{'FORMAT'},
			'MARKUP'=>$self->{'MARKUP'},
			'NAME'=>$self->{'NAME'},
			'PHONE'=>$self->{'PHONE'},
			'EMAIL'=>$self->{'EMAIL'},
			'PASSWORD'=>sprintf("%s",$self->{'PASSWORD'}),
			'WEBSITE'=>sprintf("%s",$self->{'WEBSITE'}),
			'ACCOUNT'=>$self->{'ACCOUNT'},
			'CREATED_GMT'=>$self->{'CREATED_GMT'},
			'LASTSAVE_GMT'=>time(),
			'INIDATA'=>YAML::Syck::Dump($self->{'%INIDATA'}),
			'ITEM_NOTES'=>int($self->{'ITEM_NOTES'}),
			'PRODUCT_CONNECTOR'=>$self->{'PRODUCT_CONNECTOR'},
			'SHIP_CONNECTOR'=>$self->{'SHIP_CONNECTOR'},
			'INVENTORY_CONNECTOR'=>$self->{'INVENTORY_CONNECTOR'},
			'ORDER_CONNECTOR'=>$self->{'ORDER_CONNECTOR'},
			'TRACK_CONNECTOR'=>$self->{'TRACK_CONNECTOR'},
			}, key=>['MID','CODE'],'verb'=>'update','sql'=>1);
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		$self->{'_CHANGES'}=0;
		}


	&DBINFO::db_user_close();
	return(@ERRORS);
	}


##
## just a simple exists yes/no function
## (done)
sub exists {
	my ($USERNAME,$CODE) = @_;
	my ($S) = SUPPLIER->new($USERNAME,$CODE);
	if (defined $S) { return(1); } else { return(0); }
	}



##
##
## calculate price given MARKUP
##	 (done)
sub calculate_price {
	my ($prodref, $S) = @_;	

	my $formula = uc($S->{'MARKUP'});
	my $price = '';

	require Math::Symbolic;
	my $tree = Math::Symbolic->parse_from_string($formula);         
	if (defined $tree) {
		$tree->implement('COST'=> sprintf("%.2f",$prodref->{'zoovy:base_cost'}) );
		$tree->implement('BASE'=> sprintf("%.2f",$prodref->{'zoovy:base_price'}) );
		$tree->implement('SHIP'=> sprintf("%.2f",$prodref->{'zoovy:ship_cost1'}) );
		$tree->implement('MSRP'=> sprintf("%.2f",$prodref->{'zoovy:prod_msrp'}) );

		my ($sub) = Math::Symbolic::Compiler->compile_to_sub($tree);
		$price = sprintf("%.2f",$sub->());
		}
		
	return($price);
	}

##
## disassociate products
## inputs:
##		MID
##		CODE - supplier code
##		SKUs - array ref of SKUs
##

## don't forget SUPPLIER value in the PRODUCTS/INVENTORY table
## (done)
#sub disassociate_products {
#	my ($USERNAME, $CODE, $skuref) = @_;
#	my $pdbh = &DBINFO::db_user_connect($USERNAME);
#
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#	my $TB = &ZOOVY::resolve_product_tb($USERNAME);
#	
#	# my $hashref = ZOOVY::fetchskus_into_hashref($USERNAME,$skuref);
#	my $Prodsref = &PRODUCT::group_into_hashref($USERNAME,$skuref);
#
#	foreach my $P (values %{$Prodsref}) {
#		## delete vars, saveproduct_from_hashref
#		$P->store('zoovy:prod_supplierid',undef);
#		$P->store('zoovy:prod_supplier',undef);
#		$P->store('zoovy:virtual',undef);
#		$P->save();
#
#		## update SUPPLIER and Management CATEGORY in PRODUCT table
#		## only "delete" the CATEGORY if its the SUPPLIER code
#		my $pstmt = "update $TB set SUPPLIER='',CATEGORY=replace(CATEGORY,'/".$CODE."','') where MID=$MID and PRODUCT=".$pdbh->quote($P->pid());
#		$pdbh->do($pstmt);
#		}
#
#	&DBINFO::db_user_close();
#	}	
#


## 
## input:
## 	USERNAME
##		SUPPLIER (merchant defined supplier code)
##
## returns:
##		hash of products to supplier_id
##	
## note: 
## 	if supplier_id is not defined, it's set to the PRODUCT
## (done)
#sub fetch_supplier_products {
#	my ($self) = @_;
#	my $USERNAME = $self->username();
#	my $SUPPLIER = $self->id();
#
#	my $udbh = &DBINFO::db_user_connect($USERNAME);
#
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#	my $PRODTB = &ZOOVY::resolve_product_tb($USERNAME);
#
#	my $pstmt = "select PRODUCT,SUPPLIER_ID,OPTIONS from $PRODTB where MID=$MID /* $USERNAME */ and SUPPLIER=".$udbh->quote($SUPPLIER);
#	print STDERR $pstmt."\n";
#
#	my $sth   = $udbh->prepare($pstmt);
#	$sth->execute();
#	my %sup_to_prod = ();
#	my %prod_to_sup = ();
#	my %NEED_OPTIONS = ();
#
#	## PHASE1: get a list of matching sku's
#	while ( my ($PID,$SUPPLIER_ID,$OPTIONS) = $sth->fetchrow() ) { 
#		if ($SUPPLIER_ID eq '') { $SUPPLIER_ID = $PID; }
#	
#		$sup_to_prod{$SUPPLIER_ID} = $PID; 
#		$prod_to_sup{$PID} = $SUPPLIER_ID;
#
#		## populate %prods with SKUs as necessary
#		if (($OPTIONS & 4)==4) {
#			my ($P) = PRODUCT->new($USERNAME,$PID);
#			foreach my $set (@{$P->list_skus()}) {
#				my $SKU = $set->[0];
#				my $SKU_SUPPLIERID = $P->skufetch($SKU,'zoovy:prod_supplierid');
#				if ($SKU_SUPPLIERID eq '') { $SKU_SUPPLIERID = $SKU; }
#				$sup_to_prod{$SKU_SUPPLIERID} = $SKU;
#				$prod_to_sup{$SKU} = $SKU_SUPPLIERID;
#				}
#
#			$NEED_OPTIONS{$PID}++;
#			}
#		}
#	$sth->finish();
#	&DBINFO::db_user_close();
#	
#	return(\%sup_to_prod,\%prod_to_sup);
#	}
#

##
## Get an attribute from %INIDATA
##		attrib sets a value in the object itself e.g. _IS_ACTIVE 
##		.attrib sets a value in the data portion of the object
## (grabbed from SYNDICATION.pm)
sub fetch_property {
	my ($self,$attrib) = @_;

	if (substr($attrib,0,1) ne '.') { return($self->{$attrib});	}
	else { return($self->{'%INIDATA'}->{$attrib}); }
	}

sub get { return(&SUPPLIER::fetch_property(@_)); }
sub set { return(&SUPPLIER::save_property(@_)); }


##
## returns an arrayref of products for this supplier.
##
sub products {
	my ($self) = @_;

	require PRODUCT::BATCH;
	my $arref = &PRODUCT::BATCH::list_by_attrib($self->username(),'zoovy:prod_supplier',$self->id());
	return($arref);
	}

##
## Sets an attribute in %INIDATA
##		pass .attrib to set marketplace specific settings.
##
## (grabbed from SYNDICATION.pm)
sub save_property {
	my ($self,$attrib,$val) = @_;

	print STDERR "SUPPLIER SETTING [$attrib]=$val\n";
	if (substr($attrib,0,1) ne '.') {
		## non INI data
		if ($self->{$attrib} ne $val) {
			$self->{$attrib} = "$val";
			$self->{'_CHANGES'}++;
			}
		}
	else {
		## INI data should always have a leading period
		## hmm... this seems to be the bad line.
		# $attrib = lc(substr($attrib,1));
		if (defined $val) {
			if ($self->{'%INIDATA'}->{$attrib} ne $val) {			
				$self->{'%INIDATA'}->{$attrib} = "$val";
				$self->{'_CHANGES'}++;
				}
			}
		else {
			delete $self->{'%INIDATA'}->{$attrib};
			$self->{'_CHANGES'}++;
			}
		}
	
	}

## remove SUPPLIER
## 
## %options
## 	products => 
## 		0 - remove all products
## 		1 - disassociate Supplier's products (convert to normal)
##			2 - do nothing with products
##
sub nuke {
	my ($USERNAME, $CODE, %options) = @_;
	my $MID = ZOOVY::resolve_mid($USERNAME);

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "delete from SUPPLIERS where MID=$MID and CODE=".$udbh->quote($CODE);
	$udbh->do($pstmt);

	require PRODUCT::BATCH;
	my $arref = &PRODUCT::BATCH::list_by_attrib($USERNAME,'zoovy:prod_supplier',$CODE);

	if ($options{'products'} == 0) {
		## remove products with supplier.
		foreach my $pid (@{$arref}) {
			&ZOOVY::deleteproduct($USERNAME,$pid);
			}
		}
	elsif ($options{'products'} == 1) {
		## convert to normal products.
		foreach my $pid (@{$arref}) {
			my ($P) = PRODUCT->new($USERNAME,$pid,'create'=>0);
			$P->store('zoovy:virtual',undef);
			$P->store('zoovy:prod_supplier',undef);
			$P->store('zoovy:prod_supplierid',undef);
			## $P->store('zoovy:inv_enable', $P->fetch('zoovy:inv_enable') & ~16);
			$P->save();
			## seems like we need to remove META vars
			}
		}
	elsif ($options{'products'} == 2) {
		## Blah.. leave everything alone!
		}

	return(1);
	}



####### conversion done ~2008/07/24

###### JEDI
#| ACCT_PAYMENT_TYPE    | varchar(15)                                                                     | YES  |     | NULL    |                |
## jedi.payment_type

#| ACCT_CC_NUMBER       | varchar(20)                                                                     | YES  |     | NULL    |                |
## jedi.cc.number

#| ACCT_CC_EXP_DATE     | varchar(7)                                                                      | YES  |     | NULL    |                |
## jedi.cc.exp_date

#| ACCT_CC_CODE         | char(3)                                                                         | YES  |     | NULL    |                |
## jedi.cc.code

#| ACCT_PAYPAL_EMAIL    | varchar(50)                                                                     | YES  |     | NULL    |                |
## jedi.paypal.email

#| JEDI_MID             | int(11)                                                                         | NO   |     | 0       |                |
## jedi.mid

#| JEDI_USERNAME        | varchar(20)                                                                     | NO   |     | NULL    |                |
## jedi.username

#| JEDI_CUSTOMER        | varchar(65)                                                                     | NO   |     | NULL    |                |
## jedi.customer


###### SHIPPING
#| GEN_SHIPMETHODS      | int(11)                                                                         | NO   |     | 0       |                |
## ship.methods

#| GEN_SHIPORIGZIP      | varchar(5)                                                                      | NO   |     | NULL    |                |
## ship.origzip

#| GEN_SHIPORIGSTATE    | char(2)                                                                         | NO   |     | NULL    |                |
## ship.origstate

#| GEN_SHIPPROVIDER     | enum('','FEDEX','UPS')                                                          | NO   |     | NULL    |                |
## ship.provider

#| GEN_SHIPACCOUNT      | varchar(15)                                                                     | NO   |     | NULL    |                |
## ship.account

#| GEN_SHIPMETER        | varchar(100)                                                                    | YES  |     | NULL    |                |
## ship.meter

#| GEN_SHIPMETERCREATED | int(10) unsigned                                                                | NO   |     | 0       |                |
## ship.meter_createdgmt

#| GEN_SHIPOPTIONS      | int(11)                                                                         | NO   |     | 0       |                |
## ship.options

#| GEN_HNDPERORDER      | decimal(8,2)                                                                    | NO   |     | 0.00    |                |
## ship.hnd.perorder

#| GEN_HNDPERITEM       | decimal(8,2)                                                                    | NO   |     | 0.00    |                |
## ship.hnd.peritem

#| GEN_HNDPERUNIITEM    | decimal(8,2)                                                                    | NO   |     | 0.00    |                |
## ship.hnd.perunititem


####### INVENTORY UPDATES
#| GEN_INVUPDATE_GMT    | int(11)                                                                         | NO   |     | 0       |                |
## inv.update_gmt => when the inv update has occured

#| GEN_INVUPDATE_ROWS   | int(11)                                                                         | NO   |     | 0       |                |
## inv.update_rows => how many rows have been updated

#| GEN_INVERRORS        | varchar(200)                                                                    | YES  |     | NULL    |                |
## inv.update_errors

#| GEN_INVAUTO          | enum('0','1')                                                                   | YES  |     | 0       |                |
## inv.updateauto => automatically update inv nightly

#| GEN_INVTYPE          | enum('','CSV','TAB','OTHER')                                                    | YES  |     | NULL    |                |
## inv.type

#| GEN_INVTYPE_OTHER    | varchar(15)                                                                     | YES  |     | NULL    |                |
## inv.type_other

#| GEN_INVSKU           | int(2)                                                                          | YES  |     | NULL    |                |
## inv.pos.sku => position of SKU in import file
 
#| GEN_INVSTOCK         | int(2)                                                                          | YES  |     | NULL    |                |
## inv.pos.instock => position of in-stock qty (NUMBER) in import file

#| GEN_INVSHIP          | int(2)                                                                          | YES  |     | NULL    |                |
## inv.pos.ship => shipping cost

#| GEN_INVAVAIL         | int(2)                                                                          | YES  |     | NULL    |                |
## inv.pos.avail => in-stock qty available (YES or NO)

#| GEN_INVCOST          | int(2)                                                                          | YES  |     | NULL    |                |
## inv.pos.cost

#| GEN_INVURL           | varchar(200)                                                                    | YES  |     | NULL    |                |
## inv.url

####### ORDERS -> will be moved to TOXML soon
#| GEN_ORDERTYPE        | int(1)                                                                          | NO   |     | 0       |                |
## order.type

#| GEN_ORDERSUBJECT     | varchar(100)                                                                    | YES  |     | NULL    |                |
## order.subject

#| GEN_ORDERBODY        | text                                                                            | YES  |     | NULL    |                |
## order.body

#| GEN_ORDERNOTES       | int(1)                                                                          | YES  |     | 0       |                |
## order.notes

#| GEN_ORDEREMAIL       | varchar(50)                                                                     | YES  |     | NULL    |                |
## order.email

#| GEN_ORDERBCC         | varchar(50)                                                                     | YES  |     | NULL    |                |
## order.bcc

#| GEN_ORDERFAX         | varchar(20)                                                                     | YES  |     | NULL    |                |
## order.fax

#| GEN_ORDERATTACH      | int(1)                                                                          | NO   |     | 1       |                |
## order.attach

#| GEN_ORDEREMAIL_SRC   | varchar(50)                                                                     | YES  |     | NULL    |                |
## order.email_src

#| GEN_ORDERCONF        | int(1)                                                                          | NO   |     | 0       |                |
## order.conf => order confirmation required

######## STOCK
#| LIMIT_DAYS           | tinyint(4)                                                                      | NO   |     | 0       |                |
## stock.limit_days

#| LIMIT_TIME           | varchar(5)                                                                      | YES  |     | NULL    |                |
## stock.limit_time

#| LIMIT_AMOUNT         | decimal(10,2)                                                                   | NO   |     | 0.00    |                |
## stock.limit_amount

#| LIMIT_COMBODAYS      | tinyint(4)                                                                      | NO   |     | 0       |                |
## stock.limit_combodays

#| LIMIT_COMBOAMOUNT    | decimal(10,2)                                                                   | NO   |     | 0.00    |                |
## stock.limit_comboamount

#| LIMIT_CLOSENOW       | tinyint(4)                                                                      | NO   |     | 0       |                |
## stock.limit_closenow

####### API
#| DISPATCH_ON_CREATE   | tinyint(3) unsigned                                                             | NO   |     | 0       |                |
## api.dispatch_on_create

#| DISPATCH_FULL_ORDER  | tinyint(4)                                                                      | NO   |     | 0       |                |
## api.dispatch_full_order

#| API_INVURL           | varchar(128)                                                                    | NO   |     | NULL    |                |
## api.invurl

#| API_INVHDR           | text                                                                            | YES  |     | NULL    |                |
## api.invhdr

#| API_SHIPURL          | varchar(128)                                                                    | NO   |     | NULL    |                |
## api.shipurl

#| API_ORDERURL         | varchar(128)                                                                    | NO   |     | NULL    |                |
## api.orderurl

#| API_VERSION          | tinyint(3) unsigned                                                             | NO   |     | 1       |                |
## api.version

#| API_DEBUG            | tinyint(4)                                                                      | NO   |     | 0       |                |
## api.debug

######## PARTNER
#| PARTNER_USERNAME     | varchar(25)                                                                     | NO   |     | NULL    |                |
## partner.username

#| PARTNER_PASSWORD     | varchar(10)                                                                     | NO   |     | NULL    |                |
## partner.password


#### not used
#| ACCT_FULLNAME        | varchar(50)                                                                     | YES  |     | NULL    |                |
#| ACCT_COMPANY         | varchar(60)                                                                     | YES  |     | NULL    |                |
#| ACCT_ADDRESS         | varchar(60)                                                                     | YES  |     | NULL    |                |
#| ACCT_CITY            | varchar(50)                                                                     | YES  |     | NULL    |                |
#| ACCT_STATE           | char(2)                                                                         | YES  |     | NULL    |                |
#| ACCT_ZIP             | varchar(10)                                                                     | YES  |     | NULL    |                |
#| ACCT_PHONE           | varchar(15)                                                                     | YES  |     | NULL    |                |
#| ACCT_EMAIL           | varchar(30)                                                                     | YES  |     | NULL    |                |
#| GEN_EMAIL_MSGID      | varchar(10)                                                                     | NO   |     | NULL    |                |
#### not used






	
1;
