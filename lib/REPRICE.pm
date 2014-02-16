package REPRICE;

use strict;

$REPRICE::SYSTEM_AGENTS = [
	{ 'id'=>'_VOYUER', 'title'=>'Watches prices, no interaction/updates.' },
	{ 'id'=>'_CAPTNEMO', 'title'=>'Keeps driving the price lower and lower till everbody is underwater.', },
	{ 'id'=>'_ROCKY', 'title'=>'Gets knocked down, comes back swinging. Attempts to match price for price.', },
	];


sub username {	return($_[0]->{'USERNAME'}); }
sub mid { return(&ZOOVY::resolve_mid($_[0]->{'USERNAME'})); }


##
##
sub fire_event {
	my ($self, $str) = @_;
	## &ZOOVY::add_event($self->username(),"REPRICE",%options);
	my ($redis) =&ZOOVY::getRedis($self->username());
	$redis->select(2);
	$redis->rpush("BROADCAST",$str);
	# print "STR: $str\n";
	return();
	}


## list of skus handled by this reprice object.
sub skus {
	my ($self) = @_;
	return(sort keys %{ $self->{'%SKUS'} });
	}

##
##
##
sub new {
	my ($CLASS, $P) = @_;

	my $self = {};
	$self->{'USERNAME'} = $P->username();
	$self->{'*P'} = $P;
	$self->{'%CHANGES'} = ();

	my %SKUS = ();
	my ($udbh) = &DBINFO::db_user_connect($P->username());
	my ($LTB) = &ZOOVY::resolve_lookup_tb($P->username(),&ZOOVY::resolve_mid($P->username()));
	my ($MID) = &ZOOVY::resolve_mid($P->username());
	my $pstmt = "select 
		SKU,PRICE,
		RP_IS as STATUS,
		RP_STRATEGY as STRATEGY,
		RP_NEXTPOLL_TS,
		RP_LASTPOLL_TS,
		RP_CONFIG,
		RP_MINPRICE_I,RP_MINSHIP_I,
		RP_DATA
/*		AMZRP_SET_PRICE_I,AMZRP_SET_SHIP_I,AMZRP_META,AMZRP_CHANGED_TS,
		BUYRP_SET_PRICE_I,BUYRP_SET_SHIP_I,BUYRP_META,BUYRP_CHANGED_TS,
		EBAYRP_SET_PRICE_I,EBAYRP_SET_SHIP_I,EBAYRP_META,EBAYRP_CHANGED_TS,		
		GOORP_SET_PRICE_I,GOORP_SET_SHIP_I,GOORP_META,GOORP_CHANGED_TS,
		USR1RP_SET_PRICE_I,USR1RP_SET_SHIP_I,USR1RP_META,USR1RP_CHANGED_TS
*/
		from $LTB where MID=$MID and PID=".$udbh->quote($P->pid());
	print STDERR "$pstmt\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $ref = $sth->fetchrow_hashref() ) {
		$SKUS{ $ref->{'SKU'} } = $ref;
		$ref->{'MINPRICE'} = &ZOOVY::f2money($ref->{'RP_MINPRICE_I'}/100);
		$ref->{'MINSHIP'} = &ZOOVY::f2money($ref->{'RP_MINSHIP_I'}/100);
		$ref->{'AMZPRICE'} = &ZOOVY::f2money($ref->{'AMZRP_SET_PRICE_I'}/100);
		$ref->{'AMZSHIP'} = &ZOOVY::f2money($ref->{'AMZRP_SET_PRICE_I'}/100);
		}
	$sth->finish();
	&DBINFO::db_user_close();
	$self->{'%SKUS'} = \%SKUS;
	$self->{'%CHANGES'} = {};

	bless $self, 'REPRICE';	
	return($self);
	}



sub get {
	my ($self,$key) = @_;
	## KEY/SKU:##12
	my ($SKU,$ATTR) = split(/\./,$key,2);
	return($self->{'%SKUS'}->{$SKU}->{$ATTR});
	}

sub set {
	my ($self,$key,$val) = @_;

	my ($SKU,$ATTR) = split(/\./,$key,2);
	print STDERR "$SKU->\{$ATTR\} = $val\n";

	my $CHANGES = $self->{'%CHANGES'}->{$SKU};
	if (not defined $CHANGES) {
		## initialize array
		$CHANGES = $self->{'%CHANGES'}->{$SKU} = {};
		}

	my $LOG = $self->{'@LOG'};
	if (not defined $LOG) {
		$LOG = $self->{'@LOG'} = [];
		}

	if (not defined $key) {
		## trying to delete/unset something 
		if (defined $self->{'%SKUS'}->{$ATTR}) {
			$CHANGES->{$ATTR} = undef;
			push @{$LOG}, [ $SKU, $ATTR, undef ];
			delete $self->{'%SKUS'}->{$SKU};
			}
		}
	elsif ($self->{'%SKUS'}->{$ATTR} eq $val) {
		## no changes!
		}
	else {
		# push @{$CHANGES}, [ $ATTR, $val, $self->{'%SKUS'}->{$ATTR} ];
		$CHANGES->{$ATTR} = $val;
		push @{$LOG}, [ $SKU, $ATTR, $val ];
		$self->{'%SKUS'}->{$SKU}->{$ATTR} = $val;
		}
	}


##
## TIE HASH FUNCTIONS
##
sub DESTROY {
	my ($self) = @_;

	if ($self->{'_tied'}==0) {
		}
	else {
		$self->{'_tied'}--;
		}
	}

## you can tie one of these options.
##
##	tie %xc, 'CART2', CART2=>$cart2, 'ACCESS'=>'IN' -- internal (in_get/in_set)
##	tie %xc, 'CART2', CART2=>$cart2, 'ACCESS'=>'PR' -- private[admin] (pr_get/pr_set)
##	tie %xc, 'CART2', CART2=>$cart2, 'ACCESS'=>'PU' -- public (pu_get/pu_set)
##
## 	NOTE: access is required (or public is assumed)
##
sub TIEHASH {
	my ($class, $var) = @_;

	my $this;
	if (ref($var) eq 'PRODUCT') {
		$this = $class->new($var);
		}
	elsif (ref($var) eq 'REPRICE') {
		$this = $var;
		}

	$this->{'_tied'}++;
	return($this);
	}

sub UNTIE {
	my ($this) = @_;
	$this->{'_tied'}--;
	}

sub FETCH { 
	my ($this,$key) = @_; 	
	my $val = $this->get($key);
	return($val);
	}

sub EXISTS { 
	my ($this,$key) = @_; 
	return( (defined $this->in_get($key))?1:0 ); 
	}

sub DELETE { 
	my ($this,$key) = @_; 
	$this->set($key,undef);
	return(0);
	}

sub STORE { 
	my ($this,$key,$value) = @_; 
	$this->set($key,$value);
	return(0); 
	}

sub CLEAR { 
	my ($this) = @_; 
	return(0);
	}

## method(s) not supported
sub FIRSTKEY {  my ($this) = @_; return(undef); }
sub NEXTKEY { return(undef); }



##
##
##
sub strategies {
	my ($self) = @_;

	my @AGENTS = ();
	foreach my $agent (@{$REPRICE::SYSTEM_AGENTS}) {
		push @AGENTS, $agent;
		}
	return(\@AGENTS);
	}



##
## rparray is an array of hashref, with SKU parameter
##
sub save {
	my ($self) = @_;

	if (scalar(keys %{$self->{'%CHANGES'}})>0) {
		my ($udbh) = &DBINFO::db_user_connect($self->username());
		my ($LTB) = &ZOOVY::resolve_lookup_tb($self->username(),$self->mid());
		my ($MID) = int($self->mid());

		foreach my $SKU (sort keys %{$self->{'%CHANGES'}}) {
			my $ref = $self->{'%CHANGES'}->{$SKU};
			my %cols = ();
			## direct update columns
			foreach my $col (
				'RP_IS','RP_NEXTPOLL_TS','RP_LASTPOLL_TS','RP_CONFIG',
				'AMZRP_SET_PRICE_I','AMZRP_SET_SHIP_I',
				'BUYRP_SET_PRICE_I','BUYRP_SET_SHIP_I',
				'EBAYRP_SET_PRICE_I','EBAYRP_SET_SHIP_I',
				'GOORP_SET_PRICE_I','GOORP_SET_SHIP_I',
				'USR1_SET_PRICE_I','USR1_SET_SHIP_I') {
				if (defined $ref->{$col}) { $cols{$col} = $ref->{$col}; }
				}
			if (defined $ref->{'STRATEGY'}) { $cols{'RP_STRATEGY'} = $ref->{'STRATEGY'}; }
			if (defined $ref->{'STATUS'}) { $cols{'RP_IS'} = $ref->{'STATUS'}; }
			if (defined $ref->{'MINPRICE'}) { $cols{'RP_MINPRICE_I'} = sprintf("%d",$ref->{'MINPRICE'}*100); }
			if (defined $ref->{'MINSHIP'}) { $cols{'RP_MINSHIP_I'} = sprintf("%d",$ref->{'MINSHIP'}*100); }

			## special columns (increment, etc.)
			if (scalar(keys %cols)>0) {
				my $pstmt = &DBINFO::insert($udbh,$LTB,\%cols,'verb'=>'update',sql=>1,'key'=>{'MID'=>$MID,'SKU'=>$SKU});
				print STDERR "$pstmt\n";
				$udbh->do($pstmt);
				}	
			else {
				warn "(REPRICE) NOTHING TO UPDATE FOR $SKU\n";
				}	
			}

		&DBINFO::db_user_close();
		}

	return();
	}



1;