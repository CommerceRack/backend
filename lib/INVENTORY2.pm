package INVENTORY2;

##
## Package: INVENTORY2 (the sequel)
## 

##
## each product has a field called inv_enable set
##		1 = enabled (should be turned on for everything now)
##		4 = has options
##		8 = forced on by system (DEBUG BIT)
##		16 = is api/virtual
##		32 = unlimited quantities
##		64 = unlimited due to schedule (temporary bit)
##		256 = parent (no inventory)
##		512 = child
##		1024 = this is part of a claim (this is a transient setting and should never be saved in the product)
##

## 
## globalref = inv_notify
##		1 = notify when item removed
##		2 = notify when item re-added
##		4 = notify when item re-add failed.
##		8 = reserved
##		16 = item quantity met reorder level
##		32 = item quantity below reorder level
##		64 = item hit safety level.
##
##		256 = notify when item revoked
##

# RESERVED = RESERVE+SAFETY
# ONSHELF = SIMPLE + WMS
# PROBLEMS = ERROR + OVERSOLD
# AVAILABLE = (ONSHELF + SUPPLIER - ERROR)
# DEFICIT = (OVERSOLD + BACKORDER + PREORDER)
# SALEABLE = (AVAILABLE - DEFICIT)
# UNRESERVED = SALEABLE - RESERVED;


use strict;
use Data::Dumper;
use Digest::MD5;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common;
use Data::GUID;

use lib '/backend/lib';
use DBI;
require PRODUCT;

require DBINFO;
require ZOOVY;
require ZWEBSITE;
require ZTOOLKIT;
require PRODUCT;
require ZWMS;
require LISTING::MSGS;
require TODO;
require BLAST;

sub appid {
	return( (rindex($::0,'/')>=0)?substr($::0,rindex($::0,'/')+1):$::0);
	}

sub username { return($_[0]->{'_USERNAME'}); }
sub mid { return(&ZOOVY::resolve_mid($_[0]->{'_USERNAME'})); }
sub pid { return($_[0]->{'%PIDS'}); }
sub luser { return($_[0]->{'_LUSER'}); }
sub needs_sync { my ($self) = @_; return(scalar(keys %{$self->{'%SYNC'}})); }


sub new {
	my ($class, $USERNAME, $LUSER) = @_;

	my $self = {};
	$self->{'_USERNAME'} = $USERNAME;
	$self->{'_LUSER'} = $LUSER;
	$self->{'%SYNC'} = {};			## SKU's and PIDS we need to sync.

	bless $self, 'INVENTORY2';
	return($self);
	}







##
## returns hashref
##		keyed by sku
##			value is:
##			PID,SKU,TS,AVAILABLE,ONSHELF,RESERVED,DIRTY
##
## INVENTORY2->new($self->username())->summary('SKU'=>$self->sku(),'SKU/VALUE'=>'AVAILABLE')
##
sub summary {
	my ($self, %options) = @_;

	my @ROWS = ();
	my $USERNAME = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);	
	my ($MID) = $self->mid();
	my ($L_TB) = &ZOOVY::resolve_lookup_tb($self->username(),$self->mid());
	my $pstmt = "/* INVENTORY2::summary */ select PID,SKU,unix_timestamp(TS) as TS,INV_AVAILABLE as AVAILABLE,QTY_ONSHELF as ONSHELF,QTY_MARKETS as MARKETS,DIRTY from $L_TB where MID=$MID /* $USERNAME */ ";
	my $WHERESTMT = '';


	##
	##
	##
	if (1) {
		my @HOWLS = ();	## what whererefs do!
		## single non-nested 'WHERE'=>[ 'SOMETHING', 'IS', 'SOMETHING' ]
		if ($options{'WHERE'}) { push @HOWLS, $options{'WHERE'}; }
		## multi nested where
		##		'@WHERE'=>[ [ 'SOMETHING','IS','SOMETHING'], ['SOMETHINGELSE','IS','SOMETHINGELSE' ] ];
		if ($options{'@WHERE'}) { foreach my $WHERE (@{$options{'@WHERE'}}) { push @HOWLS, $WHERE; } };

		my $REF = $options{'WHERE'};
		my %WHITELIST = (
			'AVAILABLE'=>'AVAILABLE',
			'ONSHELF'=>'ONSHELF',
			'TS'=>'TS',
			'MODIFIED_GMT'=>'unix_timestamp(TS)',
			'PID'=>'PID',
			);

		# print STDERR "HOWLS: ".Dumper(\@HOWLS);
		foreach my $WhereREF (@HOWLS) {
			if (substr($WhereREF->[2],0,1) eq '$') {
				$WhereREF->[2] = $options{substr($WhereREF->[2],1)};
				}

			if ($WhereREF->[1] eq 'GT') {
				$WHERESTMT .= " and ".$WHITELIST{$WhereREF->[0]}." > ".int($WhereREF->[2]);
				}
			elsif ($WhereREF->[1] eq 'LT') {
				$WHERESTMT .= " and ".$WHITELIST{$WhereREF->[0]}." < ".int($WhereREF->[2]);
				}
			elsif ($WhereREF->[1] eq 'EQ') {
				$WHERESTMT .= " and ".$WHITELIST{$WhereREF->[0]}." = ".$udbh->quote($WhereREF->[2]);
				}
			elsif ($WhereREF->[1] eq 'IN') {
				## param 2 *MUST* be an array
				$WHERESTMT .= " and ".$WHITELIST{$WhereREF->[0]}." in  ".&DBINFO::makeset($udbh,$WhereREF->[2]);
				}
			}
		}


	if ($options{'PID'}) {  $options{'@PIDS'} = [ $options{'PID'} ]; }
	if ($options{'SKU'}) {  $options{'@SKUS'} = [ $options{'SKU'} ]; }

	# print STDERR Dumper(\%options);

	if ($options{'@STIDS'}) {
		my @SKUS = ();
		foreach my $stid (@{$options{'@STIDS'}}) {
			my ($pid,$claim,$invopts,$noinvopts,$virtual) = PRODUCT::stid_to_pid($stid);
			push @SKUS, &PRODUCT::generate_stid(pid=>$pid,$invopts=>$invopts);
			}
		$WHERESTMT .= " and SKU in ".&DBINFO::makeset($udbh,\@SKUS);		
		}
	if ($options{'@SKUS'}) {
		$WHERESTMT .= " and SKU in ".&DBINFO::makeset($udbh,$options{'@SKUS'});
		}
	if ($options{'@PIDS'}) {
		if (scalar(@{$options{'@PIDS'}})==0) {
			warn "called INVENTORY2->summary with empty \@PIDS\n";
			$WHERESTMT = undef;
			}
		else {
			$WHERESTMT .= " and PID in ".&DBINFO::makeset($udbh,$options{'@PIDS'});
			}
		}

	if ((defined $options{'ALL'}) && ($options{'ALL'})) {
		}
	elsif ($WHERESTMT eq '') {
		Carp::cluck("INVENTORY SUMMARY HAS EMPTY WHERESTMT *AND* WE DID NOT RECEIVE AN 'ALL' PARAMETER. YOU GET NOTHING. GOOD DAY SIR.");
		$pstmt = undef;
		}

	##
	##
	##
	## print STDERR "/*RUN: ".Carp::cluck()."*/ $pstmt\n";
	my %SUMMARY = ();
	if ((defined $pstmt) && ($pstmt ne '')) {
		## print STDERR "$pstmt $WHERESTMT\n";
		# print STDERR Dumper(\%options);
		my ($sth) = $udbh->prepare("$pstmt $WHERESTMT");
		$sth->execute();
		while ( my $row = $sth->fetchrow_hashref() ) {
			$SUMMARY{ $row->{'SKU'} } = $row;
			}
		$sth->finish();
		}

	#print STDERR "SUMMARY IS: ".Dumper(\%SUMMARY);

	if (defined $options{'@SKUS'}) {
		foreach my $SKU (@{$options{'@SKUS'}}) {
			if (not defined $SUMMARY{$SKU}) {
				$SUMMARY{ $SKU } = { 'AVAILABLE'=>0, 'MARKETS' => 0, '_NOT_FOUND_IN_DB_'=>1 };
				}
			}
		}

	&DBINFO::db_user_close();

	if ($options{'ELASTIC_PAYLOADS'}) {
		## for now this lowercases all keys, eventually might hide keys from ELASTIC
		## basically returns the summary in a format that is suitable for an update into elastic sku record.
		my %ES_PAYLOADS = ();
		foreach my $SKU (keys %SUMMARY) {
			my %esdata = ();
			foreach my $k (keys %{$SUMMARY{$SKU}}) { 
				$esdata{lc($k)} = $SUMMARY{$SKU}->{$k}; 
				}
			$ES_PAYLOADS{$SKU} = \%esdata;
			}
		return(\%ES_PAYLOADS);
		}
	elsif ($options{'PIDS_ONLY'}) {
		foreach my $SKU (keys %SUMMARY) {
			my ($PID) = &PRODUCT::stid_to_pid($SKU);

			next if ($SKU eq $PID);
			if (defined $SUMMARY{$PID}) {
				## add all other SKU fields to the second.
				$SUMMARY{$PID}->{'AVAILABLE'} += ( $SUMMARY{$SKU}->{'AVAILABLE'}>0 )? $SUMMARY{$SKU}->{'AVAILABLE'} : 0;
				$SUMMARY{$PID}->{'SALEABLE'} += ( $SUMMARY{$SKU}->{'SALEABLE'}>0 )? $SUMMARY{$SKU}->{'SALEABLE'} : 0;
				$SUMMARY{$PID}->{'MARKETS'} += ( $SUMMARY{$SKU}->{'MARKETS'}>0 )? $SUMMARY{$SKU}->{'MARKETS'} : 0;
				delete $SUMMARY{$SKU};
				}
			else {
				## the first SKU becomes the * SKU (SALEABLE+RESERVD might be buggy)
				$SUMMARY{$PID} = $SUMMARY{$SKU}; 
				delete $SUMMARY{$SKU};
				$SUMMARY{$SKU}->{'SKU'} = '*';
				}
			}
		}
	elsif (my $SKU = $options{'SKU'}) {
		## returns a single sku record as a hashref
		if ($options{'SKU/VALUE'}) {
			## returns a scalar of the hashref that would have been returned.
			return($SUMMARY{$SKU}->{$options{'SKU/VALUE'}});
			}
		return($SUMMARY{$SKU});
		}


	

	return(\%SUMMARY);
	}


##
## returns data in the old format (but no location)
##
sub fetch_qty {
	my ($self, %options) = @_;

	my ($INVSUMMARY) = $self->summary(%options);
	my %ONHAND = ();
	my %RESERVE = ();
	foreach my $SKU (keys %{$INVSUMMARY}) {
		$ONHAND{ $SKU } = int($INVSUMMARY->{$SKU}->{'AVAILABLE'});
		$RESERVE{ $SKU } = int($INVSUMMARY->{$SKU}->{'RESERVE'});
		}


	return(\%ONHAND,\%RESERVE);
	}


##
## returns the onhand,reserve qty for a product (summarized from it's skus)
##
sub fetch_pidsummary_qtys {
	my ($self, %options) = @_;

	my ($onhandref,$reserveref) = $self->fetch_qty(%options);
	my ($onhandtotal,$reservetotal) = (0,0);
	foreach my $sku (keys %{$onhandref}) {
		$onhandtotal += ( $onhandref->{$sku}>0)?$onhandref->{$sku}:0;
		$reservetotal += ( $reserveref->{$sku}>0 )?$reserveref->{$sku}:0;
		}
	return($onhandtotal,$reservetotal);
	}



##
##
##
sub process_order {
	my ($INV2, $O2) = @_;

	print STDERR "START PROCESS_ORDER\n";
	my ($udbh) = &DBINFO::db_user_connect($INV2->username());
	my ($INVDETAIL) = $INV2->detail(
		'+'=>'ORDER',
		'@BASETYPES'=>['UNPAID','PICK','DONE','BACKORDER','PREORDER'],
		'WHERE'=>[ 'ORDERID', 'EQ', $O2->oid() ]
		);

	my %UUIDS = ();
	foreach my $row (@{$INVDETAIL}) {
		$UUIDS{$row->{'UUID'}} = $row;
		}

	my $USERNAME = $O2->username();
	my $MID = $O2->mid();
	## create order for each supplier.

	my $ORDER_CHANGED = 0;
	# $udbh->do("start transaction");

	my %ORDER_HAS_UUIDS = ();
	my %SUMMARIZE_PIDS = ();
	foreach my $item (@{$O2->stuff2()->items('show'=>'real')}) {
		next if ($item->{'qty'} <= 0);
		next if (substr($item->{'sku'}, 0, 1) eq '!');

		$SUMMARIZE_PIDS{ $item->{'product'} }++;
	
		if (not defined $item->{'uuid'}) { 
			$ORDER_CHANGED |= 1;
			$item->{'uuid'} = Data::GUID->new()->as_string(); 
			warn "UUID not set on item !! SHIT** making one! $item->{'uuid'}\n";
			}

		$ORDER_HAS_UUIDS{ $item->{'uuid'} }++;
		if (not defined $UUIDS{ $item->{'uuid'} }) {
			## So no item exists. we should add one. 
			$ORDER_CHANGED |= 1;
			my ($P) = PRODUCT->new($INV2->username(),$item->{'product'});
			
			if (not defined $P) {
				## tbd.?? maybe an error!?
				$INV2->orderinvcmd($O2,$item->{'uuid'},"ERROR/INIT",'ORDERID'=>$O2->oid(),"SKU"=>$item->{'sku'},"QTY"=>$item->{'qty'},"NOTE"=>"SKU does not exist");
				}
			elsif ($O2->is_paidinfull()) {
				## add it as paid item.
				if ($P->fetch('is:backorder')) {
					$INV2->orderinvcmd($O2,$item->{'uuid'},'BACKORDER/INIT','ORDERID'=>$O2->oid(),"SKU"=>$item->{'sku'},"QTY"=>$item->{'qty'});
					}
				elsif ($P->fetch('is:preorder')) {
					$INV2->orderinvcmd($O2,$item->{'uuid'},'PREORDER/INIT','ORDERID'=>$O2->oid(),"SKU"=>$item->{'sku'},"QTY"=>$item->{'qty'});				
					}
				else {
					$INV2->orderinvcmd($O2,$item->{'uuid'},"PICK/INIT",'ORDERID'=>$O2->oid(),"SKU"=>$item->{'sku'},"QTY"=>$item->{'qty'});
					}
				}
			else {
				## unpaid item.
				$INV2->orderinvcmd($O2,$item->{'uuid'},"UNPAID/INIT",'ORDERID'=>$O2->oid(),"SKU"=>$item->{'sku'},"QTY"=>$item->{'qty'});
				}
			}
		elsif ($UUIDS{ $item->{'uuid'} }->{'SKU'} ne $item->{'sku'}) {
			## verify the SKU's match
			$ORDER_CHANGED |= 2;
			$INV2->orderinvcmd($O2,$item->{'uuid'},'SET','SKU'=>$item->{'sku'});
			}
		elsif ($UUIDS{ $item->{'uuid'} }->{'QTY'} ne $item->{'qty'}) {
			## verify the QTY's match .. if not adjust
			$ORDER_CHANGED |= 4;
			$INV2->orderinvcmd($O2,$item->{'uuid'},'SET','QTY'=>$item->{'qty'});
			}
		elsif (($UUIDS{ $item->{'uuid'} }->{'BASETYPE'} eq 'UNPAID') && ($O2->is_paidinfull())) {
			## change from unpaid to pick
			$ORDER_CHANGED |= 8;
			$INV2->orderinvcmd($O2,$item->{'uuid'},"UNPAID/ITEM-PAID");
			}
		}

	## detect if we removed any items
	## print STDERR '%UUIDS: '.Dumper(\%UUIDS,\%ORDER_HAS_UUIDS)."\n";
	foreach my $UUID (keys %UUIDS) {
		next if (defined $ORDER_HAS_UUIDS{$UUID});
		$INV2->orderinvcmd($O2,$UUID,"SET","QTY"=>0,"NOTE"=>"Missing/removed from order");
		$ORDER_CHANGED |= 1024;
		}


	if ($ORDER_CHANGED) {
		## we ran one or more inventory cmds above. so we should refresh our list.
		%UUIDS = ();
		my ($INVDETAIL) = $INV2->detail(
			'+'=>'ORDER',
			'@BASETYPES'=>['UNPAID','PICK','DONE','BACKORDER','PREORDER'],
			'WHERE'=>[ 'ORDERID', 'EQ', $O2->oid() ]
			);
		foreach my $row (@{$INVDETAIL}) {
			$UUIDS{$row->{'UUID'}} = $row;
			}
		}



	# print STDERR 'UUIDS: '.Dumper(\%UUIDS)."\n";
	
	##
	## now we enter the ROUTING election .. we decided which route has the highest preference.
	##		** WE ONLY DO THIS FOR PICK_ROUTE=NEW **
	my @ROUTING = ();
	foreach my $LINEITEM (values %UUIDS) {

		next unless ($O2->is_paidinfull());		## NO ROUTING IS AVAILABLE TILL AN ORDER IS PAID!!


		print STDERR "TRY ROUTE: ".Dumper($LINEITEM)."\n";
		next unless ($LINEITEM->{'BASETYPE'} eq 'PICK');
		next unless ($LINEITEM->{'PICK_ROUTE'} eq 'NEW');
		
		my ($item) = $O2->stuff2()->item('uuid'=>$LINEITEM->{'UUID'});
		my $uuid = $LINEITEM->{'UUID'};
		print STDERR "ROUTING: $uuid\n";

		my $sku = $item->{'sku'};
		my $qty = $item->{'qty'};

		next if ($qty <= 0);
		next if (substr($sku, 0, 1) eq '!');

		## virtual/virtual_ship always prefers one supplier
		my %TRYROUTES = ();
		my ($ALLROUTES) = $INV2->detail('SKU'=>$sku,'+'=>'ROUTE','@BASETYPES'=>['SIMPLE','WMS','SUPPLIER']);
		foreach my $tryroute (@{$ALLROUTES}) {
			if ($tryroute->{'BASETYPE'} eq 'SIMPLE') {
				$TRYROUTES{"SIMPLE"} = $tryroute->{'PREFERENCE'} || 100;
				}
			elsif ($tryroute->{'BASETYPE'} eq 'WMS') {
				$TRYROUTES{sprintf("WMS:%s",$tryroute->{"WMS_GEO"})} = $tryroute->{'PREFERENCE'};
				}
			elsif ($tryroute->{'BASETYPE'} eq 'SUPPLIER') {
				$TRYROUTES{sprintf("SUPPLIER:%s",$tryroute->{"SUPPLIER_ID"})} = $tryroute->{'PREFERENCE'};
				}			
			}
		
		## simple preference
		if (defined $TRYROUTES{'SIMPLE'}) { $TRYROUTES{'SIMPLE'} |= 90; }

		my $virtual = undef;
		if (defined $item->{'virtual_ship'}) { $virtual = $item->{'virtual_ship'}; }
		if (defined $item->{'virtual'}) { $virtual = $item->{'virtual'}; }

		## 		
		if (($virtual eq 'GIFTCARD') || ($virtual eq 'SUPPLIER:GIFTCARD') || ($virtual eq 'PARTNER:GIFTCARD')) {
			## SUPPLIER:GIFTCARD is hardcoded and exists in every store!
			$TRYROUTES{"PARTNER:GIFTCARD"} |= 1000;
			}
		elsif ($virtual eq 'LOCAL') {
			foreach my $R (sort keys %TRYROUTES) {
				if ($R =~ /^WMS:/) { $TRYROUTES{$R} += 50; }
				}
			}
		elsif ($virtual ne '') {
			if (defined $TRYROUTES{$virtual}) { $TRYROUTES{$virtual} += 50; }
			}

		## add any special supplier preferences
		foreach my $R (sort keys %TRYROUTES) {
			if ($R =~ /^SUPPLIER:(.*?)$/) {
				my ($SUPPLIER) = $1;
				my ($S) = $O2->getSUPPLIER($SUPPLIER);
				if (not defined $S) {
					warn "ROUTE => SUPPLIER:$SUPPLIER is invalid (ignored)\n";
					}
				elsif (ref($S) ne 'SUPPLIER') {
					warn "ROUTE => SUPPLIER:$SUPPLIER is not a SUPPLIER object reference (ignored)\n";
					}
				else {
					$TRYROUTES{$R} += $S->fetch_property('INVENTORY_PREFERENCE');
					if ($S->fetch_property('FORMAT') eq 'STOCK') {
						##
						## okay so we only dispatch non STOCK items (e.g. DROPSHIP, or FULFILL)
						##		stock items are handled through inventory.pl
						##
						delete $TRYROUTES{$R};
						}
					}
				}
			else {
				}
			}
		
		## finally, we should select the best route
		my $MIN_ROUTE_DIFFERENCE = 0;			## minimum distance between routes for auto-routing
		my $MIN_ROUTE_PREFERENCE = 1;			## minimum number for a route to be considered for auto routing

		my $BEST = undef;
		my $NEXTBEST = undef;
		foreach my $R (sort keys %TRYROUTES) {
			next if ($TRYROUTES{$R} < $MIN_ROUTE_DIFFERENCE); ## we won't even consider this.
			
			if (not defined $BEST) {
				$NEXTBEST = $BEST; $BEST = $R; 
				}
			elsif ($TRYROUTES{$R} >= $BEST) {
				$NEXTBEST = $BEST; $BEST = $R;
				}
			}

		if (defined $NEXTBEST) {
			## check minimum distance between BEST routes
			if (($TRYROUTES{$NEXTBEST}+$MIN_ROUTE_DIFFERENCE) > $TRYROUTES{$BEST}) {
				$BEST = "TBD";
				}
			}

		if (not defined $BEST) {
			$BEST = "BACKORDER";
			}
		
		#if ($S->fetch_property('.api.dispatch_on_create')) {
		#	## always dispatch, any chance.
		#	}
		#if (($paymentcode eq '0') || ($paymentcode eq '4')) {
		#	## if it's paid (0xx) or review (4xx) [which is also paid] then we can safely dispatch on create
		#	}
		#else { 
		#	$RESULT = "SKIP|+received add_historyMsg:paid but order is: $paymentcode";
		#	}
		push @ROUTING, [ $LINEITEM, $BEST ];
		}

	print STDERR "PROCESS_ORDER ROUTES:".Dumper(\@ROUTING);
	

	##
	## at this point @ROUTING has been populated	
	##
	foreach my $ROUTESET (@ROUTING) {
		my ($LINEITEM, $ROUTE) = @{$ROUTESET};			
		my $UUID = $LINEITEM->{'UUID'};
		my ($item) = $O2->stuff2()->item('uuid'=>$LINEITEM->{'UUID'});
		$item->{'route'} = $ROUTE;		## hopefully this will stick!
		my @MSGS = ();

		print STDERR "ROUTING $UUID => $ROUTE\n";
		if ($ROUTE eq 'TBD') {
			$INV2->orderinvcmd($O2,$UUID,'PICK/ITEM-ROUTE','ROUTE'=>'TBD');
			}
		elsif ($ROUTE eq 'BACKORDER') {
			$INV2->orderinvcmd($O2,$UUID,'ITEM-ROUTE','BASETYPE'=>'BACKORDER','ROUTE'=>'TBD');
			}
		elsif ($ROUTE eq 'SIMPLE') {
			push @MSGS, "SUCCESS|+Routed to simple inventory";
			my (%MODIFIED_ROW) = ();
			$INV2->skuinvcmd($item->{'sku'},'SIMPLE/SUB','*MODIFIED_BY'=>$O2->oid(),'QTY'=>$item->{'qty'},'%ROW'=>\%MODIFIED_ROW);
			$INV2->orderinvcmd($O2,$UUID,'PICK/ITEM-DONE','QTY'=>$item->{'qty'},'PICK_ROUTE'=>'SIMPLE','NOTE'=>$MODIFIED_ROW{'NOTE'});
			}
		elsif ($ROUTE eq 'PARTNER:GIFTCARD') {
			##
			## okay so giftcards get created here
			##
			## qty is necessary because apparently, some people are dumb enough to buy qty 2+ of the same giftcard.
			my %OPTS = ();
			#$OPTS{'NOTE'} = 'Testing! ['.$item->{'stid'}.']';
			$OPTS{'NOTE'} = $item->{'%options'}->{'#C##'}->{'data'};
			$OPTS{'CREATED_BY'} = $O2->oid();
			$OPTS{'EXPIRES_GMT'} = '0';
			#$OPTS{'RECIPIENT_FULLNAME'} = 'Brian Tester';
			$OPTS{'RECIPIENT_FULLNAME'} = $item->{'%options'}->{'#A##'}->{'data'};
			#$OPTS{'RECIPIENT_EMAIL'} = 'test@zoovy.com';
			$OPTS{'RECIPIENT_EMAIL'} = $item->{'%options'}->{'#B##'}->{'data'};
			$OPTS{'RECIPIENT_EMAIL'} =~ s/[\s]+//g;

			## okay, now resolve the customer id.
			my $CID = 0;
			if (&ZTOOLKIT::validate_email($OPTS{'RECIPIENT_EMAIL'})) {
				my ($C) = CUSTOMER->new($O2->username(),
					CREATE=>2,
					INIT=>0x01,
					PRT=>$O2->prt(),
					EMAIL=>$OPTS{'RECIPIENT_EMAIL'},
					FULLNAME=>$OPTS{'RECIPIENT_FULLNAME'},
					);
				($CID) = $C->cid();
				$OPTS{'CID'} = $CID;
				}
	
			my $GCOBJ = undef;
			my $qty = $item->{'qty'};
			while ($qty > 0) {
				require GIFTCARD;
				my $issueamt = $item->{'cost'};
				if ($item->{'cost'} == 0) { $issueamt = $item->{'price'}; }
	
				$OPTS{'CARD_TYPE'} = 7;
				$OPTS{'SRC_GUID'} = sprintf("%s.%d.%s",$O2->oid(),$qty,$item->{'uuid'});
	
				my ($code) = GIFTCARD::createCard($USERNAME,$O2->prt(),$issueamt,%OPTS);
				$O2->add_history(sprintf("Created GIFTCARD#$qty $code for customer %s (%d)",$OPTS{'RECIPIENT_EMAIL'},$CID));
				$qty--;
				if ($qty == 0) {
					$GCOBJ = GIFTCARD->new( $code, %OPTS );
					}
				}

			if ($CID>0) {
				## where do they get sent to the recipient?
				require BLAST;
				my ($BLAST) = BLAST->new( $O2->username(), $O2->prt());
				my ($rcpt) = $BLAST->recipient('CUSTOMER',$CID,{'%GIFTCARD'=>$GCOBJ});
				my ($msg) = $BLAST->msg('AUTO','CUSTOMER.GIFTCARD.RECEIVED');
				$BLAST->send( $rcpt, $msg );
				}
			$INV2->orderinvcmd($O2,$UUID,'PICK/ITEM-DONE','PICK_ROUTE'=>'PARTNER','VENDOR'=>'GIFTCARD');
			}
		elsif ($ROUTE =~ /SUPPLIER:(.*?)$/) {
			## SUPPLIER (NOT A GIFTCARD)
			my ($SUPPLIERCODE) = $1;

			$INV2->orderinvcmd($O2,$UUID,'PICK/ITEM-ROUTE','ROUTE'=>'SUPPLIER',
				'VENDOR'=>$SUPPLIERCODE,
				'VENDOR_STATUS'=>'NEW',
				'VENDOR_DESCRIPTION'=>$item->{'description'},
				'COST'=>$item->{'cost'},
				'QTY'=>$item->{'qty'}
				);

			#my %hash = (
			#	MID=>$MID,
			#	USERNAME=>$USERNAME,
			#	UUID=>$item->{'uuid'},
			#	OUR_ORDERID=>$O2->oid(),
			#	STATUS=>'NEW',
			#	SKU=>$item->{'sku'},
			#	STID=>$item->{'stid'},
			#	QTY=>$item->{'qty'},
			#	COST=>$item->{'cost'},
			#	DESCRIPTION=>$item->{'description'},
			#	VENDOR=>$SUPPLIERCODE,
			#	'*CREATED_TS'=>'now()',
			#	'*MODIFIED_TS'=>'now()',
			#	);
			#my $pstmt = "select count(*) from INVENTORY_DETAIL where MID=$MID and OUR_ORDERID=".$udbh->quote($O2->oid())." and UUID=".$udbh->quote($item->{'uuid'});
			#my ($count) = $udbh->selectrow_array($pstmt);
			#if ($count == 0) {
			#	my $pstmt = &DBINFO::insert($udbh,'INVENTORY_DETAIL', \%hash, verb=>'insert',sql=>1);
			#	if ($udbh->do($pstmt)) {
			#		$O2->add_history("SC - Order Item [$item->{'sku'}] created for $SUPPLIERCODE");
			#		}
			#	else {
			#	$O2->add_history("SC - Order Item [$item->{'sku'}] created for $SUPPLIERCODE");
			#		}
			#	}
			#else {
			#	$O2->add_history("SC - Order Item $item->{'sku'} already in ITEM_DETAIL");
			#	}
			}
		elsif ($ROUTE =~ /WMS:(.*?)/) {
			my ($WMS_GEO) = $1;
			$INV2->orderinvcmd($O2,$UUID,'PICK/ITEM-ROUTE',
				'PICK_ROUTE'=>'WMS',
				'WMS_GEO'=>$WMS_GEO,
				'PICK_DONE_TS'=>0,
				);
			}
		else {
			$O2->add_history("SC - UNHANDLED RESPONSE stid:$item->{'stid'}");
			}
		}
	&DBINFO::db_user_close();

	## NORMALLY we'd fire summarization events here.. but since events don't actually run. we'll just do them ourselves
	foreach my $PID (sort keys %SUMMARIZE_PIDS) {
		my ($P) = PRODUCT->new($INV2->username(),$PID);
		if ((defined $P) && (ref($P) eq 'PRODUCT')) {
			print STDERR "SUMMARIZE PID: $PID\n";
			$INV2->summarize($P);
			}
		else {
			warn "COULD NOT SUMMARIZE PID: $PID\n";
			}
		}

	print STDERR "END PROCESS_ORDER\n";
	return(\%UUIDS);
	}


## 
##
sub tryinvlookup {
	my ($self, $lookup) = @_;

	my @SUGGESTIONS = ();
	my $USERNAME = $self->username();
	my $MID = $self->mid();
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	## first thing, see if it's a product
	my ($L_TB) = &ZOOVY::resolve_lookup_tb($self->username(),$self->mid());
	my $pstmt = "select SKU from $L_TB where MID=$MID /* $USERNAME */ and SKU=".$udbh->quote($lookup);
	my ($SKU) = $udbh->selectrow_array($pstmt);
	if (defined $SKU) {
		push @SUGGESTIONS, [ 'SKU', $SKU ];
		}
	
	if (&ZOOVY::productidexists($self->username(),$lookup)) {
		push @SUGGESTIONS, [ 'PID', $lookup ];
		}

	## next thing .. see if it's a sku
	## next, ask elastic for matching pids

	&DBINFO::db_user_close();
	return(\@SUGGESTIONS);
	}


##
##
##
sub detail {
	my ($self, %options) = @_;
	my ($rows,$count) = $self->pagedetail(%options);
	return($rows);
	}

sub pagedetail {
	my ($self, %options) = @_;
	my @ROWS = ();

	my $USERNAME = $self->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);	
	my ($MID) = $self->mid();
	my $pstmt = "select UUID,PID,SKU,BASETYPE,MODIFIED_TS, QTY, NOTE, COST_I ";
	if ($options{'+'} eq 'SIMPLE') {
		## nothing else.
		}
	elsif ($options{'+'} eq 'WMS') {
		$pstmt = "$pstmt,WMS_GEO,WMS_ZONE,WMS_POS";
		}
	elsif ($options{'+'} eq 'ORDER') {	
		$pstmt = "select * ";
		}
	elsif ($options{'+'} eq 'ROUTE') {	
		## the fields we need to do proper routing.
		$pstmt = "select UUID,SKU,BASETYPE,QTY,NOTE,COST_I,SUPPLIER_ID,WMS_GEO ";
		}
	elsif ($options{'+'} eq 'MARKET') {	
		## the fields we need to do proper routing.
		$pstmt = "select UUID,PID,SKU,QTY,NOTE,COST_I,MARKET_DST,MARKET_REFID ";
		}
	elsif ($options{'+'} eq 'ALL') {	
		$pstmt = "select * ";
		}
	$pstmt .= " from INVENTORY_DETAIL ";

	my $WHERESTMT = " where MID=$MID /* $USERNAME */ "; 
	if (&ZOOVY::servername() eq 'dev') {
		$WHERESTMT .= " /* DEV CLUCK: ".Carp::carp()." */ ";
		}


	##
	##  WHEREREF (a reference to a where statement - whitelisted)
	##	
	if (1) {
		my @HOWLS = ();	## what whererefs do!
		## single non-nested 'WHERE'=>[ 'SOMETHING', 'IS', 'SOMETHING' ]
		if ($options{'WHERE'}) { push @HOWLS, $options{'WHERE'}; }
		## multi nested where
		##		'@WHERE'=>[ [ 'SOMETHING','IS','SOMETHING'], ['SOMETHINGELSE','IS','SOMETHINGELSE' ] ];
		if ($options{'@WHERE'}) { foreach my $WHERE (@{$options{'@WHERE'}}) { push @HOWLS, $WHERE; } };

		my %WHITELIST = (
			'SUPPLIER_ID'=>'SUPPLIER_ID',
			'TS'=>'unix_timestamp(MODIFIED_TS)',
			'MODIFIED_TS'=>'MODIFIED_TS',
			'PID'=>'PID',
			'ORDERID'=>'OUR_ORDERID',
			'PICK_ROUTE'=>'PICK_ROUTE',
			'PICK_DONE_GMT'=>'unix_timestamp(PICK_DONE_TS)',
			'PICK_DONE_TS'=>'PICK_DONE_TS',
			'MARKET_DST'=>'MARKET_DST',
			);
	
		# print STDERR "HOWLS: ".Dumper(\@HOWLS);
		foreach my $WhereREF (@HOWLS) {
			if ($WhereREF->[1] eq 'GT') {
				$WHERESTMT .= " and ".$WHITELIST{$WhereREF->[0]}." > ".int($WhereREF->[2]);
				}
			elsif ($WhereREF->[1] eq 'LT') {
				$WHERESTMT .= " and ".$WHITELIST{$WhereREF->[0]}." < ".int($WhereREF->[2]);
				}
			elsif ($WhereREF->[1] eq 'EQ') {
				$WHERESTMT .= " and ".$WHITELIST{$WhereREF->[0]}." = ".$udbh->quote($WhereREF->[2]);
				}
			elsif ($WhereREF->[1] eq 'IN') {
				## param 2 *MUST* be an array
				$WHERESTMT .= " and ".$WHITELIST{$WhereREF->[0]}." in  ".&DBINFO::makeset($udbh,$WhereREF->[2]);
				}
			}
		}

	if ($options{'UUID'}) {  $options{'@UUIDS'} = [ $options{'UUID'} ]; }
	if ($options{'SKU'}) {  $options{'@SKUS'} = [ $options{'SKU'} ]; }

	if ($options{'@STIDS'}) {
		## a list of STIDS (we'll need to compute the stids, then set it in @SKUS
		my @SKUS = ();
		foreach my $stid (@{$options{'@STIDS'}}) {
			my ($pid,$claim,$invopts,$noinvopts,$virtual) = PRODUCT::stid_to_pid($stid);
			push @SKUS, &PRODUCT::generate_stid(pid=>$pid,$invopts=>$invopts);
			}
		$pstmt .= " and SKU in ".&DBINFO::makeset($udbh,\@SKUS);		
		}
	if ($options{'@SKUS'}) {
		$WHERESTMT .= " and SKU in ".&DBINFO::makeset($udbh,$options{'@SKUS'});
		}
	if ($options{'@PIDS'}) {
		$WHERESTMT .= " and PID in ".&DBINFO::makeset($udbh,$options{'@PIDS'});
		}
	if ($options{'@UUIDS'}) {
		$WHERESTMT .= " and UUID in ".&DBINFO::makeset($udbh,$options{'@UUIDS'});
		}

	if ($options{'@BASETYPES'}) { 
		$WHERESTMT .= " and BASETYPE in ".&DBINFO::makeset($udbh,$options{'@BASETYPES'});
		}
	elsif ($options{'BASETYPE'}) { 
		$WHERESTMT .= " and BASETYPE=".$udbh->quote($options{'BASETYPE'}); 
		}

	if ($options{'GEO'}) { $WHERESTMT .= " and WMS_GEO=".$udbh->quote($options{'GEO'}); }
	if ($options{'limit'}) { $WHERESTMT .= sprintf(" limit %d,%d",int($options{'page'}),int($options{'limit'})); }


	print STDERR "$pstmt $WHERESTMT\n";
	my $sth = $udbh->prepare("$pstmt $WHERESTMT");
	$sth->execute();
	while ( my $row = $sth->fetchrow_hashref() ) {
		$row->{'MODIFIED_GMT'} = &ZTOOLKIT::mysql_to_unixtime($row->{'MODIFIED_TS'}); 
		delete $row->{'MODIFIED_TS'};
		push @ROWS, $row;
		}
	$sth->finish();

	my ($count) = scalar(@ROWS);
	if ((defined $options{'limit'}) && ($options{'limit'} == $count)) {
		my $pstmt = "select count(*) from INVENTORY_DETAIL $WHERESTMT";
		($count) = $udbh->selectrow_array($pstmt);
		}

	&DBINFO::db_user_close();


	return(\@ROWS,$count);
	}


##
##
##
sub mktinvcmd {
	my ($self, $CMD, $MKT, $MKTID, $SKU, %options) = @_;

	# print STDERR Dumper($SKU,\%options);

	if ($CMD !~ /^(FOLLOW|SOLD|END|NUKE)$/) {
		warn "mktinvcmd only supports FOLLOW|SOLD|END|NUKE\n";
		return(undef);
		}
	if ($MKTID eq '') { 
		warn "mktinvcmd requires MKTID";
		return(undef);
		}

	$options{'SKU'} = $SKU;
	my $UUID = $options{'UUID'} || "$MKT*$MKTID";
	$self->{'%SYNC'}->{ $SKU }++;
	return($self->invcmd($CMD,
		%options,
		'UUID'=>$UUID,'MARKET_DST'=>$MKT,'MARKET_REFID'=>$MKTID,'SKU'=>$SKU,'BASETYPE'=>'MARKET')
		);
	}

##
##
##
sub orderinvcmd {
	my ($self, $O2, $UUID, $CMD, %options) = @_;
	my ($ORDERID) = $O2->oid();
	my ($item) = $O2->stuff2()->item('uuid'=>$UUID);
	$self->{'%SYNC'}->{ $item->{'sku'} }++;
	my ($msgs) = $self->invcmd($CMD,%options,'UUID'=>$UUID,'OUR_ORDERID'=>$ORDERID);
	# print STDERR Dumper($msgs);
	if (scalar(@{$msgs})>0) {
		## write the msgs to the order
		foreach my $msg (@{$msgs}) {
			my ($ref) = LISTING::MSGS::msg_to_disposition($msg);
			if ($ref->{'_'} eq 'DEBUG') {
				}
			else {
				$O2->add_history( sprintf("%s %s %s",), 'luser'=>$self->luser() );
				}
			}
		}
	return($msgs);
	}

## make sure to pass PID=> or SKU=>
sub supplierinvcmd {
	my ($self, $S, $CMD, %options) = @_;
	## we should probably check for PID/SKU here
	return($self->invcmd($CMD,%options,'BASETYPE'=>'SUPPLIER','SUPPLIER_ID'=>$S->id()));	
	}

sub supplierskuinvcmd {
	my ($self, $S, $SKU, $CMD, %options) = @_;
	return($self->invcmd($CMD,%options,'BASETYPE'=>'SUPPLIER','SUPPLIER_ID'=>$S->id(),'SKU'=>$SKU));	
	}

sub uuidinvcmd {
	my ($self, $UUID, $CMD, %options) = @_;
	return($self->invcmd($CMD,%options,'UUID'=>$UUID));
	}

sub skuinvcmd {
	my ($self, $SKU, $CMD, %options) = @_;
	$self->{'%SYNC'}->{$SKU}++;
	return($self->invcmd($CMD,%options,'SKU'=>$SKU));
	}

sub pidinvcmd {
	my ($self, $PID, $CMD, %options) = @_;
	$self->{'%SYNC'}->{$PID}++;
	return($self->invcmd($CMD,%options,'PID'=>$PID));
	}


## 
#$VAR1 = {
#          'PID' => 'CEL-94175',
#          'MODIFIED_GMT' => 1380935193,
#          'BASETYPE' => 'DONE',
#          'NOTE' => 'A045',
#          'QTY' => '50',
#          'COST_I' => '0',
#          'UUID' => 'E992F5502D5811E38D0262553DE391E7',
#          'SKU' => 'CEL-94175'
#        };
#
sub uuid_detail {
	my ($self, $UUID) = @_;
	my ($row) = @{$self->detail(UUID=>$UUID)};
	return($row);
	}


########################################################################
##
##
##
sub invcmd {
	my ($self,$CMD,%options) = @_;
	my ($udbh) = &DBINFO::db_user_connect($self->username());	

	my $MSGS = $options{'@MSGS'};
	if ($options{'*LM'}) { $MSGS = $options{'*LM'}->msgs(); }
	if (not defined $MSGS) { $MSGS = []; }

	my $TS =  $options{'ts'} || time();
	my $WHERESTMT = " MID=".int($self->mid())." ";

	if (defined $options{'GEO'}) { $options{'WMS_GEO'} = $options{'GEO'}; }
	if (defined $options{'ZONE'}) { $options{'WMS_ZONE'} = $options{'ZONE'}; }
	if ($options{'LOC'}) {
		my ($GEO,$ZONE,$POS) = &ZWMS::locparse($options{'LOC'});
		if (defined $GEO) { $options{'WMS_GEO'} = $GEO; }
		if (defined $ZONE) { $options{'WMS_ZONE'} = $ZONE; }
		if (defined $POS) { $options{'WMS_POS'} = $POS; }
		}

	if ($options{'PID'}) { $WHERESTMT .= " and PID=".$udbh->quote($options{'PID'}); }
	if ($options{'SKU'} && ($options{'SKU'} ne '')) { $WHERESTMT .= " and SKU=".$udbh->quote($options{'SKU'}); }
	if ($options{'MARKET_DST'}) {
		$WHERESTMT .= " and MARKET_DST=".$udbh->quote($options{'MARKET_DST'}); 
		if ($options{'MARKET_REFID'}) {
			$WHERESTMT .= " and MARKET_REFID=".$udbh->quote($options{'MARKET_REFID'}); 
			}
		}
	if ((not defined $options{'PID'}) && (not defined $options{'SKU'}) && (not defined $options{'UUID'}) && (not defined $options{'MARKET_DST'})) {
		die("INVENTORY::invcmd says SKU or UUID is required");
		}

	if ($CMD =~ /(.*?)\/(.*?)$/) {
		## for CMD that specifies a BASETYPE ex: PICK/INIT .. this makes it easier to run a command only only a specific BASETYPE
		($options{'BASETYPE'},$CMD) = ($1,$2);
		}

	if ($options{'BASETYPE'}) { $WHERESTMT .= " and BASETYPE=".$udbh->quote($options{'BASETYPE'}); }
	if ($options{'CREATED_BEFORE_TS'}) { $WHERESTMT .= " and CREATED_TS<".$udbh->quote($options{'CREATED_BEFORE_TS'}); }

	if ((defined $options{'SKU'}) && ($options{'SKU'} ne '')) {
		if ($options{'BASETYPE'} eq 'SIMPLE') {
			$options{'UUID'} = $options{'SKU'};
			}
		if (($options{'BASETYPE'} eq 'SUPPLIER') && ($options{'SUPPLIER_ID'} ne '')) {
			$options{'UUID'} = sprintf("%s*%s",$options{'SKU'},$options{'SUPPLIER_ID'} || $options{'SUPPLIER'});
			}
		}

	if ($options{'UUID'}) { $WHERESTMT .= " and UUID=".$udbh->quote($options{'UUID'}); }

	if ( $options{'WMS_GEO'}  && $options{'WMS_ZONE'} ) {
		$WHERESTMT .= " and WMS_GEO=".$udbh->quote($options{'WMS_GEO'})." and WMS_ZONE=".$udbh->quote($options{'WMS_ZONE'});
		if ($options{'WMS_POS'}) { 
			$WHERESTMT .= " and WMS_POS=".$udbh->quote($options{'WMS_POS'}); 
			}
		}

	# print STDERR 'LOC: '.Dumper(\%options,$WHERESTMT);

	my ($qtLUSER) = $udbh->quote(sprintf("%s",$options{'LUSER'})); 

	my ($PID) = $options{'PID'};
	if ((not defined $PID) && (defined $options{'SKU'})) { ($PID) = &PRODUCT::stid_to_pid($options{'SKU'}); }

	my %dbvars = (
		'MID'=>$self->mid(),
		'MODIFIED_BY'=>sprintf("%s", $options{'*MODIFIED_BY'} || $options{'luser'} || $self->luser()),
		'*MODIFIED_TS'=>&ZTOOLKIT::mysql_from_unixtime($TS), 
		'*MODIFIED_QTY_WAS'=>'QTY',
		);

	if ((defined $options{'UUID'}) && ($options{'UUID'} ne '')) { $dbvars{'UUID'} = $options{'UUID'}; }
	if ((defined $options{'SKU'}) && ($options{'SKU'} ne '')) { $dbvars{'SKU'} = $options{'SKU'}; }
	if ((defined $options{'PID'}) && ($options{'PID'} ne '')) { $dbvars{'PID'} = $options{'PID'}; }
	elsif ((not defined $dbvars{'PID'}) && (defined $PID) && ($PID ne '')) { $dbvars{'PID'} = $PID; }


	if ((defined $options{'NOTE'}) && ($options{'NOTE'} ne '')) { $dbvars{'NOTE'} = $options{'NOTE'}; }
	if ((defined $options{'COST'}) && ($options{'COST'} ne '')) { $dbvars{'COST_I'} = sprintf("%d",int($options{'COST'}*100)); }
	if ((defined $options{'CONTAINER'}) && ($options{'CONTAINER'} ne '')) { $dbvars{'CONTAINER'} = $options{'CONTAINER'}; }
	if (defined $options{'PREFERENCE'}) { $dbvars{'PREFERENCE'} = int($options{'PREFERENCE'}); }

	if (defined $options{'ORDERID'}) { $dbvars{'OUR_ORDERID'} = $options{'ORDERID'}; }
	elsif (defined $options{'OUR_ORDERID'}) { $dbvars{'OUR_ORDERID'} = $options{'OUR_ORDERID'}; }

	## MARKETPLACE FIELDS
	if (defined $options{'ENDS_GMT'}) { $dbvars{'*MARKET_ENDS_TS'} = sprintf("from_unixtime(%d)",$options{'ENDS_GMT'}); }
	if (defined $options{'SALE_GMT'}) { $dbvars{'*MARKET_SALE_TS'} = sprintf("from_unixtime(%d)",$options{'SALE_GMT'}); }

	## WMS FIELDS
	if (defined $options{'WMS_GEO'}) { $dbvars{'WMS_GEO'} = $options{'WMS_GEO'}; }
	if (defined $options{'WMS_GEO'}) { $dbvars{'WMS_GEO'} = $options{'WMS_GEO'}; }

	## SUPPLIER/VENDOR FIELDS
	if ((defined $options{'SUPPLIER_ID'}) && ($options{'SUPPLIER_ID'} ne '')) { 
		$dbvars{'SUPPLIER_ID'} = $dbvars{'VENDOR'} = $options{'SUPPLIER_ID'}; 
		}
	elsif ((defined $options{'VENDOR'}) && ($options{'VENDOR'} ne '')) { 
		$dbvars{'VENDOR'} = $dbvars{'SUPPLIER_ID'} = $options{'VENDOR'};
		}
	if (defined $options{'SUPPLIER_SKU'}) { $dbvars{'SUPPLIER_SKU'} = $options{'SUPPLIER_SKU'}; }
	if (defined $options{'VENDOR'}) {
		if (defined $options{'VENDOR_STATUS'}) { $dbvars{'VENDOR_STATUS'} = $options{'VENDOR_STATUS'}; }
		if (defined $options{'VENDOR_ORDER_DBID'}) { $dbvars{'VENDOR_ORDER_DBID'} = $options{'VENDOR_ORDER_DBID'}; }
		if (defined $options{'VENDOR_SKU'}) { $dbvars{'VENDOR_SKU'} = $options{'VENDOR_SKU'}; }
		if (defined $options{'VENDOR_DESCRIPTION'}) { $dbvars{'DESCRIPTION'} = $options{'VENDOR_DESCRIPTION'}; }
		}

	## print STDERR Carp::cluck("$CMD");
	push @{$MSGS}, "DEBUG|+CMD:$CMD";

	

	##
	## START GENERAL DETAIL COMMANDS
	##
	if ($CMD eq 'INIT') {
		if (not defined $dbvars{'UUID'}) {
			## INIT is the only function that will auto-create a signed UUID
			$dbvars{'UUID'} = Digest::MD5::md5_hex($options{'BASETYPE'}.$options{'SKU'}.$options{'SUPPLIER_ID'}.$options{'ORDERID'});
			}

		$dbvars{'*CREATED_TS'} = 'now()';
		$dbvars{'QTY'} = int($options{'QTY'});
		$dbvars{'BASETYPE'} = $options{'BASETYPE'};
		if ($dbvars{'BASETYPE'} =~ /^(UNPAID|BACKORDER|PREORDER|PICK)$/o) {
			## these are all types of order records which means we should probably pick a safe PICK_ROUTE
			$dbvars{'PICK_ROUTE'} = $options{'PICK_ROUTE'};
			if (not defined $dbvars{'PICK_ROUTE'}) { $dbvars{'PICK_ROUTE'} = 'NEW'; }
			}

		delete $dbvars{'*MODIFIED_QTY_WAS'};
		my ($pstmt) = &DBINFO::insert($udbh,'INVENTORY_DETAIL',\%dbvars,'verb'=>'insert','sql'=>1);
		print STDERR "$pstmt\n";
		my ($rv) = $udbh->do($pstmt);
		if (not defined $rv) {
			push @{$MSGS}, "ERROR|+INIT Failed";
			}
		}
	elsif ($CMD eq 'NUKE') {
		my $pstmt = "delete from INVENTORY_DETAIL where $WHERESTMT";
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		push @{$MSGS}, "SUCCESS|+Detail deleted";
		}
	elsif ($CMD eq 'UNDO') {
		my $pstmt = "update INVENTORY_DETAIL set MID=0,NOTE=UUID,UUID=NULL where $WHERESTMT";
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		}
	elsif (($CMD eq 'ANNOTATE') || ($CMD eq 'PREFERENCE')) {
		my $pstmt = "select ID,UUID from INVENTORY_DETAIL where $WHERESTMT";
		my ($ID,$DBUUID) = $udbh->selectrow_array($pstmt);
		if ($ID>0) {
			my ($pstmt) = &DBINFO::insert($udbh,'INVENTORY_DETAIL',\%dbvars,'verb'=>'update','sql'=>1,key=>{MID=>$self->mid(),ID=>$ID,UUID=>$DBUUID});
			print STDERR "$pstmt\n";
			$udbh->do($pstmt);
			}
		}	
	##
	## START GENERAL/WMS CONTROL COMMANDS
	##
	elsif (($CMD eq 'ADD') || ($CMD eq 'SUB') || ($CMD eq 'SET') || ($CMD eq 'INC')) {
		my ($QTY) = int($options{'QTY'});

		$dbvars{'*VERIFY_INC'} = 'VERIFY_INC+1';
		my $pstmt = "select ID,UUID,NOTE from INVENTORY_DETAIL where $WHERESTMT";
		print STDERR "$pstmt\n";
		my ($ID,$DBUUID,$NOTE) = $udbh->selectrow_array($pstmt);
		
		if (defined $options{'%ROW'}) { 
			$options{'%ROW'}->{'ID'} = $ID;
			$options{'%ROW'}->{'UUID'} = $DBUUID;
			$options{'%ROW'}->{'NOTE'} = $NOTE;
			}

		if ($CMD eq 'SET') { $dbvars{'QTY'} = $QTY; }
		if ($CMD eq 'ADD') { $dbvars{'*QTY'} = sprintf("QTY+%d",$QTY); }
		if ($CMD eq 'INC') { $dbvars{'*QTY'} = sprintf("QTY+%d",$QTY); }
		if ($CMD eq 'SUB') { $dbvars{'*QTY'} = sprintf("QTY-%d",$QTY); }

		if ($ID == -1) {
			## error!
			push @{$MSGS}, "CMD:$CMD got response -1";
			}
		elsif ($ID>0) {
			## udpate, we're good.
			if (defined $options{'BASETYPE'}) { $dbvars{'BASETYPE'} = $options{'BASETYPE'}; }	## did we want t change basetype?
			my $pstmt = &DBINFO::insert($udbh,'INVENTORY_DETAIL',\%dbvars,'verb'=>'update','sql'=>1,'key'=>{MID=>$self->mid(),ID=>$ID});
			print STDERR "$pstmt\n";
			my ($rv) = $udbh->do($pstmt);
	      if (defined $rv) {
				# push @{$MSGS}, "DEBUG|+$pstmt";
				push @{$MSGS}, "SUCCESS|+$CMD $QTY";
				}
			}
		else {
			## create
			if (defined $DBUUID) { $dbvars{'UUID'} = $DBUUID; }
			if (not defined $dbvars{'UUID'}) { 
				warn "INVENTORY2->set|add|sub Generating UUID (HINT: it's better if you make your own)\n";
				$dbvars{'UUID'} = substr(Data::GUID->new()->as_string(),0,36); 
				}
			if ($options{'GEO'}) { $dbvars{'WMS_GEO'} = $options{'GEO'}; }
			if ($options{'ZONE'}) { $dbvars{'WMS_ZONE'} = $options{'ZONE'}; }
			if ($options{'POS'}) { $dbvars{'WMS_POS'} = $options{'POS'}; }
			$dbvars{'BASETYPE'} = $options{'BASETYPE'};
			if ((not defined $dbvars{'BASETYPE'}) || ($dbvars{'BASETYPE'} eq '')) { $dbvars{'BASETYPE'} = 'ERROR'; }
			if (not defined $dbvars{'PREFERENCE'}) {
				$dbvars{'PREFERENCE'} = int($options{'PREFERENCE'});
				}

			my $pstmt = &DBINFO::insert($udbh,'INVENTORY_DETAIL',\%dbvars,'verb'=>'insert','sql'=>1);
			print STDERR "$pstmt\n";
			$udbh->do($pstmt);
			push @{$MSGS}, "DEBUG|+$pstmt";
			push @{$MSGS}, "SUCCESS|+Yay!";
			}

		}
	##
	## START MARKETPLACE 
	##
	elsif (($CMD eq 'SOLD') || ($CMD eq 'END') || ($CMD eq 'FOLLOW')) {

		my %mktdbvars = %dbvars;
		my ($QTY) = int($options{'QTY'});
		$mktdbvars{'BASETYPE'} = 'MARKET';
		$mktdbvars{'NOTE'} = sprintf("%s",$options{'NOTE'});
	
		$mktdbvars{'MARKET_DST'} = $options{'MARKET_DST'} || $options{'MARKET'};
		$mktdbvars{'MARKET_REFID'} = $options{'MARKET_REFID'};
		$mktdbvars{'*MODIFIED_TS'} = 'now()';
		my $VERB = 'update';

		my $SKU = $options{'SKU'};
		if (not defined $SKU) {
			warn "SKU not passed to MKTINVCMD:$CMD -- this will be much slower (need to lookup)\n";
			my $pstmt = "select SKU from INVENTORY_DETAIL where $WHERESTMT";
			print $pstmt."\n";
			($SKU) = $udbh->selectrow_array($pstmt);
			}

		my $UUID = $options{'UUID'};
		if ($CMD eq 'FOLLOW') {
			my $pstmt = "select QTY from INVENTORY_DETAIL where $WHERESTMT";
			my ($DB_QTY) = $udbh->selectrow_array($pstmt);
			$VERB = (defined $DB_QTY)?'update':'insert';
			if ($QTY == $DB_QTY) { $VERB = 'skip'; }

			$mktdbvars{'UUID'} = $UUID;
			$mktdbvars{'QTY'} = $QTY;
			$mktdbvars{'MARKET_ENDS_TS'} = time();
			if (defined $options{'NOTE'}) { $mktdbvars{'NOTE'} = $options{'NOTE'}; }
			}
		if ($CMD eq 'SOLD') { 
			$mktdbvars{'*QTY'} = sprintf("QTY-%d",$QTY); 
			$mktdbvars{'*MARKET_SOLD_TS'} = sprintf("MARKET_SOLD_TS+%d",$QTY);
			$mktdbvars{'*MARKET_SALE_TS'} = 'now()';
			}
		if ($CMD eq 'END') {
			$mktdbvars{'QTY'} = 0;
			$mktdbvars{'MARKET_ENDS_TS'} = time();
			}

		if ($VERB eq 'update') {
			delete $mktdbvars{'MARKET_DST'};
			delete $mktdbvars{'MARKET_REFID'};
			delete $mktdbvars{'BASETYPE'};
			delete $mktdbvars{'UUID'};
			delete $mktdbvars{'MID'};
			}

		if ($VERB ne 'skip') {
			my $pstmt = &DBINFO::insert($udbh,'INVENTORY_DETAIL',\%mktdbvars,'verb'=>$VERB,'sql'=>1,'key'=>{MID=>$self->mid(),SKU=>$SKU,UUID=>$UUID});
			print STDERR "$pstmt\n";
			$udbh->do($pstmt);
			push @{$MSGS}, "SUCCESS|+Yay!";
			}
		else {
			push @{$MSGS}, "SUCCESS-SKIP|+no update necessary";
			}

		}
	elsif ($CMD eq 'MOVE') {
		push @{$MSGS}, "ISE|+Move is not currently supported";		
		}
	##
	## START ORDER
	##
	elsif ($CMD =~ /^ITEM-(CANCEL|DONE|PAID|ROUTE|RESET)$/) {
		## we're done processing this record (done is a status meaning the inventory record is only for record keeping)
		if (not $dbvars{'OUR_ORDERID'}) {
			warn "OUR_ORDER IS REQUIRED FOR ITEM-xxx commands\n";
			}

		if ($CMD eq 'ITEM-CANCEL') {
			my ($INVROW) = @{$self->detail("UUID"=>$options{'UUID'})};
			if ($INVROW->{'BASETYPE'} eq 'DONE') {
				$dbvars{'BASETYPE'} = 'RETURN';
				}
			else {
				$dbvars{'BASETYPE'} = 'CANCEL';
				}
			}
		elsif ($CMD eq 'ITEM-DONE') {
			$dbvars{'BASETYPE'} = 'DONE';
			$dbvars{'PICK_DONE_TS'} = &ZTOOLKIT::mysql_from_unixtime(time());
			}
		elsif ($CMD eq 'ITEM-RESET') {
			$dbvars{'BASETYPE'} = 'PICK';
			$dbvars{'PICK_ROUTE'} = 'TBD';
			}
		elsif ($CMD eq 'ITEM-PAID') {
			$dbvars{'BASETYPE'} = 'PICK';
			$dbvars{'PICK_ROUTE'} = 'NEW';
			}
		elsif ($CMD eq 'ITEM-SPLIT') {
			
			}
		elsif (($CMD eq 'ITEM-ROUTE') && ($options{'ROUTE'} eq 'SIMPLE')) {
			## NOT SURE IF THIS IS STILL USED!
			my $pstmt = "select ID,SKU,QTY from INVENTORY_DETAIL where MID=".int($self->mid())." and UUID=".$udbh->quote($dbvars{'UUID'})." and OUR_ORDERID=".$udbh->quote($dbvars{'OUR_ORDERID'});
			my ($ID,$SKU,$QTY) = $udbh->selectrow_array($pstmt);
			if (($QTY>0) && ($ID>0)) {
				$self->skuinvcmd($SKU,'SIMPLE/SUB','QTY'=>$QTY);
				$dbvars{'BASETYPE'} = 'DONE';
				}
			}
		elsif (($CMD eq 'ITEM-ROUTE') && ($options{'ROUTE'} eq 'BACKORDER')) {
			$dbvars{'BASETYPE'} = 'BACKORDER';
			$dbvars{'PICK_ROUTE'} = '';
			}
		elsif (($CMD eq 'ITEM-ROUTE') && ($options{'ROUTE'} eq 'PREORDER')) {
			$dbvars{'BASETYPE'} = 'PREORDER';
			$dbvars{'PICK_ROUTE'} = '';
			}
		elsif ($CMD eq 'ITEM-ROUTE') {
			$dbvars{'BASETYPE'} = 'PICK';
			$dbvars{'PICK_ROUTE'} = $options{'ROUTE'};
			if (not defined $dbvars{'PICK_ROUTE'}) { $dbvars{'PICK_ROUTE'} = $options{'PICK_ROUTE'}; }
			if (not defined $dbvars{'PICK_ROUTE'}) { $dbvars{'PICK_ROUTE'} = ''; }
			}

		my $pstmt = &DBINFO::insert($udbh,'INVENTORY_DETAIL',\%dbvars,'verb'=>'update','sql'=>1,'key'=>{'MID'=>$self->mid(),'UUID'=>$dbvars{'UUID'},'OUR_ORDERID'=>$dbvars{'OUR_ORDERID'}});
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		}
	#elsif ($CMD eq 'PROCESSED') {
	#	my $pstmt = &DBINFO::insert($udbh,'INVENTORY_DETAIL',\%dbvars,'verb'=>'update','sql'=>1,'key'=>{'MID'=>$self->mid(),'ORDERID'=>$dbvars{'OUR_ORDERID'}});
	#	print STDERR "$pstmt\n";
	#	$udbh->do($pstmt);
	#	}
	##
	## START PRODUCT/PID
	##
	elsif ($CMD eq 'RENAME') {	
		my ($qtNEWPID) = $udbh->quote($options{'NEW_PID'});
		my $pstmt = "select * from INVENTORY_DETAIL where $WHERESTMT";
		my ($sth) = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $row = $sth->fetchrow() ) {
			my ($pid,$claim,$invopts,$noinvopts,$virtual) = PRODUCT::stid_to_pid($row->{'SKU'});
			my ($newSKU) = &PRODUCT::generate_stid(pid=>$options{'NEW_PID'},claim=>$claim,$invopts=>$invopts,noinvopts=>$noinvopts,virtual=>$virtual);
			my ($qtNEWSKU) = $udbh->quote($newSKU);
			$pstmt = "update INVENTORY_DETAIL set PID=$qtNEWPID,SKU=$qtNEWSKU where $WHERESTMT and ID=".int($row->{'ID'});
			print STDERR "$pstmt\n";
			$udbh->do($pstmt);
			}
		$sth->finish();
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		}
	##
	## END PRODUCT BASED COMMANDS
	##
	else {
		push @{$MSGS}, "ERROR|+Unknown CMD:$CMD";
		}

	if (($options{'PID'} eq '') && ($options{'SKU'} ne '')) {
		($options{'PID'}) = PRODUCT::stid_to_pid($options{'SKU'});
		}
	elsif (($options{'SKU'} eq '') && ($options{'PID'} ne '')) {
		($options{'SKU'}) = '*';
		}

	my %logvars = ();
	$logvars{'MID'} = $self->mid();
	$logvars{'SKU'} = sprintf("%s",$options{'SKU'});
	$logvars{'PID'} = sprintf("%s",$options{'PID'});
	$logvars{'QTY'} = sprintf("%s",$options{'QTY'});
	$logvars{'UUID'} = sprintf("%s",$options{'UUID'});
	$logvars{'LUSER'} = sprintf("%s",$options{'LUSER'});
	$logvars{'PARAMS'} = &ZTOOLKIT::buildparams(\%options,1);
	$logvars{'CMD'} = $CMD;
	$logvars{'*TS'} = 'now()';

	my ($pstmt) = &DBINFO::insert($udbh,'INVENTORY_LOG',\%logvars,'verb'=>'insert','sql'=>1);
	print STDERR "$pstmt\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();

	return($MSGS);
	}


############################################
##
## INVENTORY::cart_verify
## PARAMETERS: username, invref (hashref keyed by SKU, with quantity as value), webdb ref (optional)
## RETURNS: an undef if it was successful, or a hashref of sku/value for updated quantities (if necessary)
## 
sub verify_cart2 {
	my ($self, $CART2, %options) = @_;

	my $USERNAME = $self->username();
	my $GREF = $options{'%GREF'};
	if (not defined $GREF) { 
		# $GREF = &ZWEBSITE::fetch_website_dbref($USERNAME);
		$GREF = &ZWEBSITE::fetch_globalref($USERNAME);
		}

	if ((not defined $GREF->{'inv_mode'}) || ($GREF->{'inv_mode'} == 0)) { 
		warn "$USERNAME inv_mode not configured";
		return undef; 
		}


	## inventory police means reduce # in cart to match qty available (or not reserved)
	#my $police = defined($GREF->{'inv_police'}) ? $GREF->{'inv_police'} : 0;
	#if ($police < 1) { 
	#	# warn "$USERNAME inv_police not enabled or not set.";
	#	return undef; 
	#	}

	my %result = ();

	my $STUFF2 = $CART2->stuff2();
	my %UUID_SKU_LOOKUP = ();
	my @SKUS = ();
	foreach my $item (@{$STUFF2->items('show'=>'real')}) {
#		my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($stid);
#		print STDERR "UUID=$stid pid=$pid,claim=$claim,invopts=$invopts,noinvopts=$noinvopts,virtual=$virtual\n";
		# my $invsku = $pid.(($invopts ne '')?":$invopts":'');		## invsku is the sku as it would appear in inventory
		$UUID_SKU_LOOKUP{$item->{'stid'}} = $item->{'sku'};
		push @SKUS, $item->{'sku'};
		}
	
	my ($qtyref,$reserveref,$locref) = $self->fetch_qty('@SKUS'=>\@SKUS);

	my %TOTALQTY = ();	# this is a hash of skus
	foreach my $item (@{$STUFF2->items('show'=>'real')}) {
		# next if ($stid =~ m/(\*|\%)/); 
		# my ($item) = $STUFF2->item($stid);
		next if ((defined $item->{'claim'}) && ($item->{'claim'}>0));
		next if ($item->{'force_qty'}>0);

		my $qty = $qtyref->{$item->{'sku'}};
		my $reserve = $reserveref->{$item->{'sku'}};
		next if (not defined $qty);

		my $available = $qty;
		#if ($police==1) { $available = $qty; }
		#elsif ($police==2) { $available = $qty-$reserve; }

		## so $available tracks the quantity of this sku.
		if (defined $TOTALQTY{$item->{'sku'}}) { 
			## so we've already removed some of these, this is case the same item with different options is in the cart.
			## this is the "personalized trophy" scenario..
			$available -= $TOTALQTY{$item->{'sku'}}; 
			}
		else { 
			## nope, never seen this item before, so far this is the only one in the cart we know about.
			$TOTALQTY{$item->{'sku'}} = 0; 
			}	 
		
		## so here is where we decide that an item is out of stock
		if ($available < $item->{'qty'}) { 
			## this time it's out of stock!
			$result{$item->{'stid'}} = $available; 
			## oh shit, what if it's an assembly, we need to let the parent know.
			if (($item->{'asm_qty'}==0) || ($available==0)){
				## avoid division by zero issues!
				## well fuck, we already have zero.
				if ((defined $item->{'asm_master'}) && ($item->{'asm_master'} ne '')) {
					$result{$item->{'asm_master'}} = 0;
					}
				}
			elsif ($item->{'asm_qty'}>$available) {
				## okay shit, we don't have enough.. so set the master to zero quantity, get it the fuck out of the cart.
				$result{$item->{'asm_master'}} = 0;
				}
			else {
				## well.. we don't have enough of the master to satisfy this component request, 
				## but maybe we have enough for one or two..  the int() here is on purpose, because 
				##	we need to make sure we never get any decimals.. if you need 3, and we only have 2.5 .. you get 2.
				$result{$item->{'asm_master'}} = int($available/$item->{'asm_qty'});
				}
			}
		# we keep the total quantity of inventoriable skus (so they can't overpurchase)
		$TOTALQTY{$item->{'sku'}} += (defined $result{$item->{'stid'}})?$result{$item->{'stid'}}:$item->{'qty'};

		if (defined $result{$item->{'stid'}}) {
			## if $result{$item->{'stid'}} is set it means that the inventory # is adjusted
			## ooh, there is a bad situations where if zoovy:inv_enable is set to 0 then we shouldn't be paying attention to inventory
			## but the inventory record still exists. - this code is intended to fix that.

			## new options
			#my ($P) = $STUFF2->getPRODUCT($item->{'product'});
			#my $inv_enable = (defined $P)?$P->fetch('zoovy:inv_enable'):0;
         #if (($inv_enable & 16)==16) {
         #   ## virtual product -- yeah, we should never let them overbuy virtual items (pisses suppliers off)
         #   }
			#elsif (($inv_enable & 32)==32) {
			#	delete $result{$item->{'stid'}};		# unlimited quantities are always purchasable!
			#	}
			#elsif ((not defined $inv_enable) || ($inv_enable == 0)) {
			##	&INVENTORY::nuke_record($USERNAME,$item->{'product'},$item->{'sku'});
			#	delete $result{$item->{'stid'}};
			#	}
			
			}

		}

	if ( scalar(keys %result) > 0 ) { return (\%result); }
	return(undef);	
	}


##
## call this before a $INV2 object goes out of scope tosync all inventory values.
##
sub synctag { my ($self, $PID) = @_; $self->{'%SYNC'}->{$PID}++; }
sub sync {
	my ($self) = @_;
	
	my %PIDS = ();
	foreach my $SKU (keys %{$self->{'%SYNC'}}) {
		my ($PID) = PRODUCT::stid_to_pid($SKU);
		if (not defined $PIDS{$PID}) {
			($PIDS{$PID}) = PRODUCT->new($self->username(),$PID);
			}
		}

	foreach my $P (values %PIDS) {
		next unless (ref($P) eq 'PRODUCT');
		$self->summarize($P);
		}
	}


##
##
##
sub summarize {
	my ($self, $P, %options) = @_;


	my $SuMMarIzeD = $options{'%SuMMarIzeD'} || {};
	$SuMMarIzeD->{$P->pid()}++;

	my $USERNAME = $self->username();
	my ($L_TB) = &ZOOVY::resolve_lookup_tb($self->username(),$self->mid());
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = $self->mid();
	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
	my ($lm) = LISTING::MSGS->new($USERNAME);
	my ($t) = TODO->new($USERNAME,writeonly=>1);

	my %PIDS = ();
	my %SKUS = ();
	my %CONTAINERS = ();
	my %CONSTANTS = ();

	my @SQL = ();
	my @EVENTS = ();


	## ASSEMBLY HANDLING
	if (not defined $P) {
		print STDERR Carp::cluck("well $P isn't defined, this won't go well.\n");
		return();
		die();
		}


	my $PIDASM = $P->fetch('pid:assembly') || $P->fetch('zoovy:prod_asm');
	$PIDASM = uc($PIDASM);
	foreach my $row (@{$P->list_skus('verify'=>1)}) {
		my @ASSEMBLY = ();
		$SKUS{ $row->[0] } = { '%QTY'=>{} };
		# print STDERR Dumper($row)."\n";
		my $SKUASM = $P->skufetch($row->[0],'sku:assembly');
		$SKUASM = uc($SKUASM);
		foreach my $skuqty (split(/[\n,]/,sprintf("%s\n%s",$PIDASM,$SKUASM))) {
			$skuqty =~ s/[\s]+//gs;
			next if ($skuqty eq '');
			my ($SKU,$QTY) = split(/\*/,$skuqty);
			if (not defined $QTY) { $QTY = 1; }
			$SKUS{ $row->[0] }->{'%ASM'}->{$SKU} += $QTY;
			}
		}



	## INVENTORY DETAIL HANDLING
	my ($PID) = $P->pid();
	my $pstmt = "select SKU,BASETYPE,QTY,COST_I,MARKET_DST,WMS_GEO,GRPASM_REF from INVENTORY_DETAIL where MID=".$udbh->quote($MID)." and PID=".$udbh->quote($PID);
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($SKU,$BASETYPE,$QTY,$COSTI,$MARKET,$WMS_GEO,$GRPASM_REF) = $sth->fetchrow() ) {
		next if (not defined $SKUS{$SKU});		## skip records which .. aren't,umm. real.

		next if ($BASETYPE eq 'DONE');
		if ($QTY < 0) {
			if ($BASETYPE ne 'SIMPLE') { $QTY = 0; }	## non SIMPLE cannot decrement inventory.
			}

		if ($BASETYPE eq 'CONSTANT') {
			$SKUS{$SKU}->{'CONSTANT'} = $QTY;
			$CONSTANTS{$SKU} = $QTY;
			}
		if ($BASETYPE eq '_ASM_') {
			## i'm part of an assembly!
			push @{$CONTAINERS{ $GRPASM_REF }}, $SKU;
		#	open F, ">>/tmp/$USERNAME.pid"; print F "!! $GRPASM_REF\n";  close F;
			}

		$SKUS{$SKU}->{'%QTY'}->{$BASETYPE} += $QTY;
		if ($BASETYPE eq 'SIMPLE') { 
			$SKUS{$SKU}->{'%QTY'}->{'AVAILABLE'} += $QTY;
			}
		if ($SKU ne $PID) {
			## must have variations, better update the root product record
			$SKUS{$PID}->{'%QTY'}->{$BASETYPE} += ($QTY>0)?$QTY:0;
			}

		# print Dumper( $SKU=>$SKUS{$SKU} ); 
			
		## 'SIMPLE','WMS','SUPPLIER','PICK','OVERSOLD','BACKORDER','SAFETY','ERROR','PREORDER','ONORDER','MARKET'
		}
	$sth->finish();
	## / INVENTORY_DETAIL


	## LOAD PREVIOUS INVENTORY SUMMARY (so we can see what changed)
	if (1) {
		my @SKUS = keys %SKUS;
		my $pstmt = "select SKU,QTY_ONSHELF,INV_AVAILABLE,QTY_MARKETS from $L_TB where MID=$MID and SKU in ".&DBINFO::makeset($udbh,\@SKUS);
		print STDERR "$pstmt\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($DBSKU,$ONSHELF,$AVAILABLE,$MARKETS) = $sth->fetchrow() ) {
			$DBSKU =~ s/[\s]+//gs;		## remove spaces from SKU's (how the hell do these get here?)
			$SKUS{$DBSKU}->{'%WAS'} = { 'ONSHELF'=>$ONSHELF,'AVAILABLE'=>$AVAILABLE,'MARKETS'=>$MARKETS };
			}
		$sth->finish();
		}
	## /END PREVIOUS SUMMARY

	#if (($TYPE eq 'P') && (not defined $P)) {
	#	my ($t) = TODO->new($USERNAME,writeonly=>1);
	#	$t->add(class=>"WARN",link=>"product:$PID",title=>"Product $PID is designated as parent (but does not exist)");
	#	$lm->pooshmsg("ERROR|+PID:$PID was designated as a parent but does not have a product record");
	#	}

	## if we are looking at a parent which has variations, it'd be nice to update it.
	#if ($P->has_variations('inv')>0) {
	#	$SKUS{ $PID } = {}
	#	my %dbvars = ();
	#	my ($pstmt) = &DBINFO::insert($udbh,$L_TB,\%dbvars,key=>['MID','SKU'],sql=>1,'verb'=>'update');
	#	push @SQL, $pstmt;
	#	}

	foreach my $SKU (sort keys %SKUS) {
		my $SKUREF = $SKUS{$SKU};
		my %dbvars = ();
		$dbvars{'MID'} = $MID;
		$dbvars{'SKU'} = $SKU;
		$dbvars{'*TS'} = 'now()';

		# print STDERR "GROUP_TYPE: ".$P->grp_type()."\n";
		if ($P->grp_type() eq 'PARENT') {
			## type 'PARENT' should be the sum of all children
			my @GRP_CHILDREN = $P->grp_children();
			my $CHILD_SUMMARIES = $self->summary('@SKUS'=>\@GRP_CHILDREN);

			my $AVAILABLE = 0;
			foreach my $child (keys %{$CHILD_SUMMARIES}) {
				## make sure we don't add quantities < 0	(otherwise a -9999 might eliminate a lot of valid products)
				$AVAILABLE += ($CHILD_SUMMARIES->{$child}->{'AVAILABLE'}>0)?$CHILD_SUMMARIES->{$child}->{'AVAILABLE'}:0;
				}
			$dbvars{'QTY_ONSHELF'} = 0;
			$dbvars{'INV_AVAILABLE'} = $AVAILABLE;
			$dbvars{'QTY_MARKETS'} = 0;
			$dbvars{'GRP_PARENT'} = '*PARENT'; 
			}
		elsif (($P->grp_type() eq 'CHILD') || ($P->grp_type() eq '')) {
			## if we're updating a child, make sure we also process the parent.
			$dbvars{'GRP_PARENT'} = '';
			if ($P->grp_type() eq 'CHILD') {
				push @{$CONTAINERS{ $P->grp_parent() }}, $SKU;
				$dbvars{'GRP_PARENT'} = $P->grp_parent();
				}
			$dbvars{'QTY_ONSHELF'} = int($SKUREF->{'%QTY'}->{'SIMPLE'}) + int($SKUREF->{'%QTY'}->{'WMS'}) + int($SKUREF->{'%QTY'}->{'RETURN'});
			$dbvars{'INV_AVAILABLE'} = 0 	
				+ $dbvars{'QTY_ONSHELF'} 
				+ int($SKUREF->{'%QTY'}->{'SUPPLIER'}) 
				- int($SKUREF->{'%QTY'}->{'ERROR'})
				- int($SKUREF->{'%QTY'}->{'UNPAID'})
				;
				
			$dbvars{'QTY_MARKETS'} = int($SKUREF->{'%QTY'}->{'MARKET'});
			}


		if ($SKUREF->{'CONSTANT'}) {
			## constant inventory causes us to always have xx AVAILABLE
			$dbvars{'INV_AVAILABLE'} = $SKUREF->{'CONSTANT'};
			}
		elsif ($SKUS{ $SKU }->{'%ASM'}) {
			## do we have assemblies
			my @ASM_SKUS = (keys %{$SKUS{ $SKU }->{'%ASM'}});
			my $ASMSKU_SUMMARIES = $self->summary('@SKUS'=>\@ASM_SKUS);

			foreach my $ASMSKU (@ASM_SKUS) {
				my $MAXUNITQTY = -1;
				my $ASMQTY = $SKUS{ $SKU }->{'%ASM'}->{ $ASMSKU };
				my $REALQTY = int($ASMSKU_SUMMARIES->{$ASMSKU}->{'AVAILABLE'});
				if ($ASMQTY <= 0) {}
				elsif ($REALQTY <= 0) { $MAXUNITQTY = 0; }
				else { $MAXUNITQTY = int($REALQTY / $ASMQTY); }
					
				print "$ASMSKU WE_WANT:$ASMQTY (per item)  REALLY_HAVE:$REALQTY (total)\n";
				$ASMSKU_SUMMARIES->{$ASMSKU}->{'ASM_MAX_UNITS'} = $MAXUNITQTY;
				if ($MAXUNITQTY < $dbvars{'INV_AVAILABLE'}) { $dbvars{'INV_AVAILABLE'} = $MAXUNITQTY; }
				}
			}
		elsif (0) {
			## are we a group product
			}
			

		##
		my $pstmt = "select count(*) from $L_TB where MID=? and SKU=?";
		my ($exists) = $udbh->selectrow_array($pstmt, {},$dbvars{'MID'},$dbvars{'SKU'});
		my $VERB = ($exists)?'update':'insert';


		my ($pstmt) = &DBINFO::insert($udbh,$L_TB,\%dbvars,key=>['MID','SKU'],sql=>1,'verb'=>$VERB);
		push @SQL, $pstmt;

		$SKUREF->{'%QTY'}->{'AVAILABLE'} = $dbvars{'INV_AVAILABLE'};
		$SKUREF->{'%QTY'}->{'ONSHELF'} = $dbvars{'QTY_ONSHELF'};
		$SKUREF->{'%QTY'}->{'MARKET'} = $dbvars{'QTY_MARKETS'};

		## CREATE/CHILDREN RECORDS
		if ($P->grp_type() eq 'PARENT') {
			#foreach my $childPID ($P->grp_children()) {
			#	my ($childavailableqty) = &INVENTORY::load_record($USERNAME,$childPID);
			#	$availableqty += $childavailableqty;
			#	}
			}
		##


		##
		## REGISTER ASSMEBLY RECORDS IN INVENTORY_DETAIL
		##		(so we receive notifications)
		##
		if ($SKUREF->{'%ASM'}) {
			## load asm records from INVENTORY_DETAIL
			my @ASM_SKUS = (keys %{$SKUS{ $SKU }->{'%ASM'}});
			my $pstmt = "select ID,SKU,QTY from INVENTORY_DETAIL where MID=$MID and BASETYPE='_ASM_' and SKU in ".&DBINFO::makeset($udbh,\@ASM_SKUS)." and GRPASM_REF=".$udbh->quote($SKU);
			print STDERR "$pstmt\n";
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			my %ASMCHANGES = ();
			while ( my ($ID,$ASMSKU,$ASMQTY) = $sth->fetchrow() ) {
				# print STDERR "$ID|$ASMSKU|$ASMQTY\n";
				if (defined $ASMCHANGES{$ASMSKU}) {
					push @SQL, "/* dup _ASM_ record */ delete from INVENTORY_DETAIL where MID=$MID and ID=$ID";
					}
				elsif ($SKUREF->{'%ASM'}->{$ASMSKU} == $ASMQTY) {
					## leave britney alone!
					$ASMCHANGES{$ASMSKU} = 'ASIS';
					}	
				elsif (not defined $SKUREF->{'%ASM'}) {
					$ASMCHANGES{$ASMSKU} = 'DELETE'; 
					}
				else {
					$ASMCHANGES{$ASMSKU} = 'UPDATE';
					}
				}
			$sth->finish();
			## find missing records for us. 
			foreach my $ASMSKU (keys %{$SKUREF->{'%ASM'}}) {
				if (not defined $ASMCHANGES{$ASMSKU}) {
					$ASMCHANGES{$ASMSKU} = 'CREATE'; 
					}
				}

			foreach my $ASMSKU (sort keys %ASMCHANGES) {
				next if ($ASMCHANGES{$ASMSKU} eq 'ASIS');
				my $ASMQTY = int($SKUREF->{'%ASM'}->{$ASMSKU});
				if ($ASMCHANGES{$ASMSKU} eq 'DELETE') {
					push @SQL, "delete from INVENTORY_DETAIL  where MID=$MID and BASETYPE='_ASM_' and SKU=".$udbh->quote($ASMSKU)." and GRPASM_REF=".$udbh->quote($SKU);
					}
				elsif ($ASMCHANGES{$ASMSKU} eq 'UPDATE') {
					push @SQL, "update INVENTORY_DETAIL set QTY=$ASMQTY,MODIFIED_TS=now() where MID=$MID and BASETYPE='_ASM_' and SKU=".$udbh->quote($ASMSKU)." and GRPASM_REF=".$udbh->quote($SKU);
					}
				else {
					## insert a new record.
					my ($PID) = &PRODUCT::stid_to_pid($ASMSKU);
					push @SQL, &DBINFO::insert($udbh,'INVENTORY_DETAIL',{
						'UUID'=>Data::GUID->new()->as_string(),
						'MID'=>$MID,
						'PID'=>$PID,
						'SKU'=>$ASMSKU,
						'QTY'=>$ASMQTY,
						'BASETYPE'=>'_ASM_',
						'GRPASM_REF'=>$SKU,
						'*MODIFIED_TS'=>'now()'
						},'verb'=>'insert',sql=>1);
					}
				}
			}
		## END OF ASSEMBLY PROPERTY



		## EVENT PROCESSING

		if (not defined $SKUREF->{'%QTY'}->{'AVAILABLE'}) {
			## not defined, this is an error
			}
		elsif (($SKUREF->{'%WAS'}->{'AVAILABLE'} <= 0 ) && ( $SKUREF->{'%QTY'}->{'AVAILABLE'} > 0 )) {
			push @EVENTS, [ 'INV.GOTINSTOCK', { 'SKU'=>$SKU,'was'=>$SKUREF->{'%WAS'}->{'AVAILABLE'},'is'=>$SKUREF->{'%QTY'}->{'AVAILABLE'} } ];	
			}
		elsif (($options{'force_events'}) && ($SKUREF->{'%QTY'}->{'AVAILABLE'} > 0 )) {
			push @EVENTS, [ 'INV.GOTINSTOCK', { 'forced'=>1, 'SKU'=>$SKU,'was'=>$SKUREF->{'%WAS'}->{'AVAILABLE'},'is'=>$SKUREF->{'%QTY'}->{'AVAILABLE'} } ];				
			}
		elsif (($SKUREF->{'%WAS'}->{'AVAILABLE'} > 0 ) && ( $SKUREF->{'%QTY'}->{'AVAILABLE'} <= 0 )) {
			push @EVENTS, [ 'INV.OUTOFSTOCK', { 'SKU'=>$SKU,'was'=>$SKUREF->{'%WAS'}->{'AVAILABLE'},'is'=>$SKUREF->{'%QTY'}->{'AVAILABLE'} } ];	
			}
		elsif (($options{'force_events'}) && ($SKUREF->{'%QTY'}->{'AVAILABLE'} <= 0 )) {
			push @EVENTS, [ 'INV.OUTOFSTOCK', { 'forced'=>1, 'SKU'=>$SKU,'was'=>$SKUREF->{'%WAS'}->{'AVAILABLE'},'is'=>$SKUREF->{'%QTY'}->{'AVAILABLE'} } ];				
			}

		if (not defined $SKUREF->{'%QTY'}->{'AVAILABLE'}) {
			# SKU no longer valid.
			}
		elsif ( $SKUREF->{'%WAS'}->{'AVAILABLE'} != $SKUREF->{'%QTY'}->{'AVAILABLE'} ) {
			push @EVENTS, [ 'INV.CHANGED', { 'SKU'=>$SKU,'was'=>$SKUREF->{'%WAS'}->{'AVAILABLE'},'is'=>$SKUREF->{'%QTY'}->{'AVAILABLE'} } ];
			}
		elsif ($options{'force_events'}) {
			## force the events
			push @EVENTS, [ 'INV.CHANGED', { 'forced'=>1, 'SKU'=>$SKU,'was'=>$SKUREF->{'%WAS'}->{'AVAILABLE'},'is'=>$SKUREF->{'%QTY'}->{'AVAILABLE'} } ];
			}


		if ( $P->skufetch($SKU,'sku:inv_reorder')==0) {
			}
		elsif (not defined $SKUREF->{'%QTY'}->{'ONHAND'}) {
			}
		elsif ( $P->skufetch($SKU,'sku:inv_reorder') < $SKUREF->{'%QTY'}->{'ONHAND'}) {
			my $WAS = $SKUREF->{'%WAS'}->{'ONHAND'};
			my $ONHAND = $SKUREF->{'%QTY'}->{'ONHAND'};
			my $ONORDER = 0;
			my $REORDER = $P->skufetch($SKU,'sku:inv_reorder');

			#if (($gref->{'inv_notify'} & (16+32))==0) {
			#	# don't notify if we've reached minimums
			#	}	
			#elsif ( (($gref->{'inv_notify'} & 16)==16) && ($ONHAND<($REORDER+$ONORDER)) ) {
			#	## re-order level exceeded
			#	$t->add(class=>"INFO",link=>"product:$PID",title=>"Inventory $SKU Re-order qty was exceeded (available: $ONHAND onorder: $ONORDER)",description=>"reorder: $REORDER, onorder: $ONORDER, NOW: $ONHAND, WAS: $WAS");
			#	$lm->pooshmsg("TODO|pid=$PID|+EXCEEDED REORDER-QTY (16)");
			#	}
 			#elsif ( (($gref->{'inv_notify'} & 32)==32) && ($ONHAND<=($REORDER+$ONORDER)) ) {
			#	$t->add(class=>"INFO",link=>"product:$PID",title=>"Inventory $SKU Re-order qty has been met (available: $ONHAND onorder: $ONORDER)",description=>"reorder: $REORDER, onorder: $ONORDER, NOW: $ONHAND, WAS: $WAS");
			#	$lm->pooshmsg("TODO|pid=$PID|+EXCEEDED REORDER-QTY (32)");
			#	}
			push @EVENTS, [ 'INV.CHANGED', {'SKU'=>$SKU,'was'=>$SKUREF->{'%WAS'}->{'AVAILABLE'},'is'=>$SKUREF->{'%QTY'}->{'AVAILABLE'}} ];
			}

		print STDERR 'SKUREF: '.Dumper($SKUREF);
		## /EVENT PROCESSING

		## COMBINE ALL THE SKUS INTO A PRODUCT RECORD.
		if (not defined $PIDS{ $PID }) {	
			$PIDS{$PID}->{'%QTY'}->{'AVAILABLE'} += $SKUREF->{'AVAILABLE'};
			$PIDS{$PID}->{'%QTY'}->{'ONHAND'} += $SKUREF->{'ONHAND'};
			$PIDS{$PID}->{'%QTY'}->{'MARKETS'} += $SKUREF->{'MARKETS'};
			}


		## /COMBINE
		}


	## PID PROCESSING
	foreach my $PID (keys %PIDS) {		
		my $ONHAND = $PIDS{$PID}->{'ONHAND'};
		my $remove_reason = '';
		if (not defined $PIDS{$PID}->{'AVAILABLE'}) {
			## this line should never be reached.
			}
		elsif ( $PIDS{$PID}->{'AVAILABLE'} > 0 ) {
			## it's available, don't remove it.
			}
		elsif ($gref->{'inv_outofstock_action'}>0) {
			# is actual <= 0
			if (($remove_reason eq '') && ( ($gref->{'inv_outofstock_action'} & 1) == 1)) { $remove_reason = 'Out of Stock'; }
			}

		#if ($remove_reason ne '') {
		#	my ($PID) = $P->pid();
		#	&ZOOVY::add_event($USERNAME,'INV.REMOVE',PID=>$PID);
		#	$lm->pooshmsg("INV.REMOVE|pid=$PID|+REQUEST REMOVE WEBSITE RS=$remove_reason ONHAND=$ONHAND");
		#	}
		}
	## END PID PROCESSING

	## process 
	if (scalar(keys %CONTAINERS)==0) {
		## too few
		}	
	elsif (scalar(keys %CONTAINERS)>25) {
		## make a constant record to maintain performance
		foreach my $k (keys %CONTAINERS) {
			## we should probably create CONSTANT records for .. or .. who knows.
			}
		warn "Too many containers, cannot update";
		}
	else {
		foreach my $ParentPID (sort keys %CONTAINERS) {
			my ($Parent) = PRODUCT->new($self->username(),$ParentPID,'create'=>0);

			if ($ParentPID eq $PID) {
				#$t->add(class=>"WARN",link=>"product:$PID",title=>"Product $PID claims to be it's own parent (summarization was halted)");
				#$lm->pooshmsg("ERROR|+PID:$PID designates itself as a parent (summarization halted)");
				}
			elsif ((not defined $Parent) || (ref($Parent) ne 'PRODUCT')) {
				## yeah, this doesn't exist!
				}
			elsif ($SuMMarIzeD->{$Parent->pid()}) {
				## we've done this someplace else.
				}
			else {
				print STDERR sprintf("SUMMARIZING CONTAINER[%s] from %s\n",$ParentPID,$P->pid());
			# 	open F, ">>/tmp/$USERNAME.pid"; print F "** ".$Parent->pid()."\n"; close F;
				$SuMMarIzeD->{$Parent->pid()}++;
				$self->summarize($Parent,'%SuMMarIzeD'=>$SuMMarIzeD);
				}
			}
		}

	###
	### Actually process the updates
	###
	my $REALLY_PROCESS = 1;
	if ($REALLY_PROCESS) {
		$udbh = &DBINFO::db_user_connect($USERNAME);
		push @SQL, 'commit';
		foreach $pstmt (@SQL) {
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			}
		&DBINFO::db_user_close();

		foreach my $EVENTREF( @EVENTS ) {
			print STDERR "EVENT: $EVENTREF->[0] ".Dumper($EVENTREF->[1])."\n";
			&ZOOVY::add_event($USERNAME,$EVENTREF->[0],%{$EVENTREF->[1]});
			}
		}

	&DBINFO::db_user_close();
	return();
	}



##
## INVENTORY::checkout_cart
## PURPOSE: add the inventory in the cart to the incremental log, so it will (eventually) be marked
##		from inventory.
## 	also used from Edit Order to update/change inventory quantities.
## PARAMETERS: USERNAME and a reference to a cart hash
## RETURNS: 0 on success, 1 on failure.
##
sub checkout_cart2 {
	my ($self, $CART2, $APPID) = @_;

	my $STUFF2 = $CART2->stuff2();
	my $ORDERID = $CART2->oid();

	if (not defined $APPID) { $APPID = &appid(); }
	if (not defined $ORDERID) { $ORDERID = ''; }

	my ($USERNAME) = $self->username();
	my $pdbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my ($INV2) = INVENTORY2->new($USERNAME,"*$APPID");
	my ($MSGS) = $INV2->process_order($CART2);
	&DBINFO::db_user_close();

	my $error = undef;
	return ($error);
	} ## end sub checkout_cart







1;




__DATA__

1;