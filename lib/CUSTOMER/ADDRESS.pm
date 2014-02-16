package CUSTOMER::ADDRESS;

use Data::Dumper;
use strict;


%CUSTOMER::ADDRESS::VALID_FIELDS = (
	## SHARED FIELDS
	'firstname'=>1,'middlename'=>1,'lastname'=>1,
	'company'=>1,
	'address1'=>1,'address2'=>1,
	'city'=>1,'region'=>1,'postal'=>1,'countrycode'=>1,
	'phone'=>1, 'email'=>1,
	);


sub has_changed { my ($self) = @_; return(int($self->{'_HAS_CHANGED'})); }
sub is_default { my ($self) = @_;  return($self->{'_IS_DEFAULT'}?1:0); }
sub set_changed { my ($self) = @_; return(++$self->{'_HAS_CHANGED'}); }

sub shortcut {	my ($self) = @_;	return($self->{'ID'});	}
## ->id use ->shortcut instead (more referencable/searchable)

##
## PAGE::JQUERY uses this method
##
$CUSTOMER::ADDRESS::JSON_EXPORT_FORMAT = 201313;	## at version 201314 it changes bill_firstname to bill
sub TO_JSON {
	my ($self) = @_;

	my %result = ();

	my $TYPE = $self->type();
	if ($CUSTOMER::ADDRESS::JSON_EXPORT_FORMAT < 201314) {
		## transport: bill_firstname, bill_lastname, etc.
		foreach my $k (keys %{$self->{'%ADDR'}}) {
			#next if (substr($k,0,1) eq '*');	 # skip *CUSTOMER, etc.
			#next if (lc($k) ne $k); # skip uppercase ID etc. (we'll copy those special values ex: ID, _IS_DEFAULT after this loop)
			$result{lc(sprintf("%s_%s",$TYPE,$k))} = $self->{'%ADDR'}->{$k};
			}
		}
	else {
		## transport: bill/firstname, bill/lastname, etc.
		my $TYPE = lc($self->type());
		# open F, ">>/tmp/addr"; print F Dumper($self); close F;
		foreach my $k (keys %CUSTOMER::ADDRESS::VALID_FIELDS) { 
			## populate all fields to blank
			$result{"$TYPE/$k"} = ''; 
			}	
		foreach my $k (keys %{$self->{'%ADDR'}}) {
			#next if (substr($k,0,1) eq '*');	 # skip *CUSTOMER, etc.
			#next if (lc($k) ne $k); # skip uppercase ID etc. (we'll copy those special values ex: ID, _IS_DEFAULT after this loop)
			# if ($k =~ /(bill|ship|ws)_(.*?)$/) { $result{"$1/$2"} = $self->{$k}; }
			$result{lc(sprintf("%s/%s",$TYPE,$k))} = $self->{'%ADDR'}->{$k};
			}
		}

	## special fields have an _ in front of them (they aren't data, they are identifiers to the data)
	$result{'_is_default'} = $self->is_default();
	$result{'_id'} = $self->shortcut();	# yeah, we're going to need 'id' aka shortcut
	return(\%result);
	}

##
sub TO_HASHREF {
	my ($self) = @_;

	my %result = ();
	my $TYPE = $self->type();
	if ($CUSTOMER::ADDRESS::JSON_EXPORT_FORMAT < 201314) {
		## transport: bill_firstname, bill_lastname, etc.
		foreach my $k (keys %{$self->{'%ADDR'}}) {
			#next if (substr($k,0,1) eq '*');	 # skip *CUSTOMER, etc.
			#next if (lc($k) ne $k); # skip uppercase ID etc. (we'll copy those special values ex: ID, _IS_DEFAULT after this loop)
			$result{lc(sprintf("%s_%s",$TYPE,$k))} = $self->{'%ADDR'}->{$k};
			}
		}
	else {
		## transport: bill/firstname, bill/lastname, etc.
		my $TYPE = lc($self->type());
		# open F, ">>/tmp/addr"; print F Dumper($self); close F;
		foreach my $k (keys %CUSTOMER::ADDRESS::VALID_FIELDS) { 
			## populate all fields to blank
			$result{"$TYPE/$k"} = ''; 
			}	
		foreach my $k (keys %{$self->{'%ADDR'}}) {
			#next if (substr($k,0,1) eq '*');	 # skip *CUSTOMER, etc.
			#next if (lc($k) ne $k); # skip uppercase ID etc. (we'll copy those special values ex: ID, _IS_DEFAULT after this loop)
			# if ($k =~ /(bill|ship|ws)_(.*?)$/) { $result{"$1/$2"} = $self->{$k}; }
			$result{lc(sprintf("%s/%s",$TYPE,$k))} = $self->{'%ADDR'}->{$k};
			}
		}
	return(\%result);
	}



##
## can be BILL,SHIP,WS
##
sub type { my ($self) = @_; return($self->{'TYPE'}); }
sub customer { my ($self) = @_; return($self->{'*CUSTOMER'}); }

sub safekeys {
	my ($self) = @_;

	my @SAFE_KEYS = ();
	foreach my $k (keys %{$self}) {
		next if (substr($k,0,1) eq '*');	# ignore things like *CUSTOMER
		next if (lc($k) ne $k);	# only return lowercase keys (no ID=)
		push @SAFE_KEYS, $k;
		}
	return(\@SAFE_KEYS);
	}

##
## 
##
sub new {
	my ($class, $C, $TYPE, $ref, %options) = @_;

	if (ref($C) ne 'CUSTOMER') {
		print STDERR Carp::cluck("need to pass a customer reference to CUSTOMER::ADDRESS->new()");
		}

	if (ref($TYPE) ne '') {
		print STDERR Carp::cluck("need to pass a TYPE to CUSTOMER::ADDRESS->new()");
		}

	if (ref($ref) eq 'HASH') {
		## this is fine.
		}
	else {
		print Carp::cluck("need to pass a hashref as \$ref to CUSTOMER::ADDRESS->new()");
		}

	my $self = {};
	$self->{'%ADDR'} = $ref;			## ref should only have fields in CUSTOMER::ADDRESS::VALID_FIELDS
	$self->{'*CUSTOMER'} = $C;
	bless $self, 'CUSTOMER::ADDRESS';
	$self->{'TYPE'} = uc($TYPE);

	if ($self->{'TYPE'}) {
		## this is to correct an issue in order manager where it doesn't like a non-two-digit state
		## which happens from time to time.
		}

	if (defined $options{'IS_DEFAULT'}) {
		$self->{'_IS_DEFAULT'} = int($options{'IS_DEFAULT'});
		}

	if ($options{'SHORTCUT'}) {
		$self->{'ID'} = $options{'SHORTCUT'};
		}

	return($self);
	}


##
## implicitly trusts whatever it gets
##
sub from_hash {
	my ($self, $src) = @_;
	$self->{'%ADDR'} = $src;
	return($self);
	}


sub as_hash { my ($self) = @_; return($self->{'%ADDR'}); }

##
## accepts $TYPE (can be undef) + src which is { 'bill_country'=> etc. } (will upgrade country, etc.)
##
sub from_legacy {
	my ($self, $src) = @_;

	my ($TYPE) = $self->type();
	my %INFO = ();
	foreach my $k (keys %CUSTOMER::ADDRESS::VALID_FIELDS) {
		if (defined $src->{ lc(sprintf("%s_%s",$TYPE,$k)) }) {
			$INFO{$k} = $src->{ lc(sprintf("%s_%s",$TYPE,$k)) };
			}
		}

	## CONVERT LEGACY FIELDS
	my $lcTYPE = lc($TYPE);
	if (($src->{lc($TYPE.'_state')} eq $src->{lc($TYPE.'_province')}) 
		&& ($src->{lc($TYPE.'_country')} ne '')) { 
		delete $src->{lc($TYPE.'_state')};
		}

	## convert old customers to new format
	if ((defined $src->{"$lcTYPE\_int_zip"}) && ($src->{"$lcTYPE\_int_zip"} ne '')) { $INFO{'postal'} = $src->{"$lcTYPE\_int_zip"}; delete $src->{"$lcTYPE\_int_zip"}; }
	if ((defined $src->{"$lcTYPE\_zip"}) && ($src->{"$lcTYPE\_zip"} ne '')) { $INFO{'postal'} = $src->{"$lcTYPE\_zip"}; delete $src->{"$lcTYPE\_zip"}; }
	if ((defined $src->{"$lcTYPE\_state"}) && ($src->{"$lcTYPE\_state"} ne '')) { $INFO{'region'} = $src->{"$lcTYPE\_state"}; delete $src->{"$lcTYPE\_state"}; }
	if ((defined $src->{"$lcTYPE\_province"}) && ($src->{"$lcTYPE\_province"} ne '')) { $INFO{'region'} = $src->{"$lcTYPE\_province"}; delete $src->{"$lcTYPE\_province"}; }
	if ((defined $src->{"$lcTYPE\_country"}) && ($src->{"$lcTYPE\_country"} ne '')) { 
		require ZSHIP;
		my $info = &ZSHIP::resolve_country("ZOOVY"=>$src->{"$lcTYPE\_country"});
		if (defined $info) {
			$INFO{'countrycode'} = $info->{'ISO'};
			delete $src->{"$lcTYPE\_country"};
			}
		}	
	if ((defined $src->{"$lcTYPE\_country"}) && ($src->{"$lcTYPE\_country"} eq '')) { 
		$INFO{'countrycode'} = "US";
		delete $src->{"$lcTYPE\_country"};
		}

	## now copy %INFO over fields in $self
	$self->{'%ADDR'} = \%INFO;

	return($self);	
	}


##
## accepts $TYPE (can be undef) + src which is { bill/postal, bill/countrycode=>, etc. }
##
sub from_prefix {
	my ($self, $TYPE, $src) = @_;

	if (defined $TYPE) {
		$self->{'TYPE'} = $TYPE;
		}
	else {
		$TYPE = $self->type();
		}
	
	my %INFO = ();
	foreach my $k (keys %CUSTOMER::ADDRESS::VALID_FIELDS) {
		if (defined $src->{ lc(sprintf("%s/%s",$TYPE,$k)) }) {
			$INFO{$k} = $src->{ lc(sprintf("%s/%s",$TYPE,$k)) };
			}
		}

	$self->{'%ADDR'} = \%INFO;
	return($self);
	}


##
## formerly: save_ship_info save_bill_info
##
sub store {
	my ($self) = @_;

	my ($C) = $self->customer();
	
#	my %INFO = ();
#	foreach my $k (keys %{$self}) {
#		next if (substr($k,0,1) eq '*'); # *CUSTOMER
#		next if (lc($k) ne $k); # IS_DEFAULT (we only save/store lowercase keys)
#		$INFO{$k} = $self->{$k};
#		}
#
#	if (defined $INFO{'countrycode'}) {
#		## already in correct format
#		}
#	else {
#		my $TYPE = lc($self->type());
#		if ((defined $INFO{"$TYPE\_int_zip"}) && ($INFO{"$TYPE\_int_zip"} ne '')) { $INFO{"$TYPE\_postal"} = $INFO{"$TYPE\_int_zip"}; delete $INFO{"$TYPE\_int_zip"}; }
#		if ((defined $INFO{"$TYPE\_zip"}) && ($INFO{"$TYPE\_zip"} ne '')) { $INFO{"$TYPE\_postal"} = $INFO{"$TYPE\_zip"}; delete $INFO{"$TYPE\_zip"}; }
#		if ((defined $INFO{"$TYPE\_state"}) && ($INFO{"$TYPE\_state"} ne '')) { $INFO{"$TYPE\_region"} = $INFO{"$TYPE\_state"}; delete $INFO{"$TYPE\_state"}; }
#		if ((defined $INFO{"$TYPE\_province"}) && ($INFO{"$TYPE\_province"} ne '')) { $INFO{"$TYPE\_region"} = $INFO{"$TYPE\_province"}; delete $INFO{"$TYPE\_province"}; }
#		if ((defined $INFO{"$TYPE\_country"}) && ($INFO{"$TYPE\_country"} ne '')) { 
#			require ZSHIP;
#			my $info = &ZSHIP::resolve_country("ZOOVY"=>$INFO{"$TYPE\_country"});
#			if (defined $info) {
#				$INFO{"$TYPE\_countrycode"} = $info->{'ISO'};
#				delete $INFO{"$TYPE\_country"};
#				}
#			}
#		if ((defined $INFO{"$TYPE\_country"}) && ($INFO{"$TYPE\_country"} eq '')) { 
#			$INFO{"$TYPE\_countrycode"} = "US";
#			delete $INFO{"$TYPE\_country"};
#			}
#
#		## since 201314 we don't use the bill_field or ship_field (now simply 'field') syntax
#		%COPY = ();
#		foreach my $k (keys %CUSTOMER::ADDRESS::VALID_FIELDS) {
#			$COPY{ $k } = $INFO{"$TYPE\_$k"};
#			}
#		%INFO = %COPY;
#		}
		
	my ($CID) = $C->cid();
	my ($USERNAME) = $C->username();
	my ($MID) = $C->mid();
	my ($IS_DEFAULT) = $self->is_default();

	my $SHORTCUT = $self->shortcut();
	if ($SHORTCUT eq '') { $SHORTCUT = uc($self->type()); }
	$SHORTCUT =~ s/[^A-Z0-9]+//gs;

	my ($addrtb) = &CUSTOMER::resolve_customer_addr_tb($USERNAME,$MID);
	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my ($pstmt) = &DBINFO::insert($odbh,$addrtb,{
		INFO=>&CUSTOMER::buildparams($self->{'%ADDR'}),
		MID=>$MID,	
		PARENT=>$CID,
		USERNAME=>$USERNAME,
		TYPE=>$self->type(),
		CODE=>$SHORTCUT,
		IS_DEFAULT=>$IS_DEFAULT,
		},key=>['PARENT','MID','TYPE','CODE'],debug=>1,sql=>1);
	print STDERR "$pstmt\n";
	$odbh->do($pstmt);
	&DBINFO::db_user_close();

	## hmm.. @BILL and @SHIP haven't been updated .. 

	return(0);
	}


sub as_html {
	my ($self) = @_;

	my $c = '';
	my $type = lc($self->type());
	my $ADDR = $self->{'%ADDR'};

	if ($ADDR->{'company'}) { $c .= $ADDR->{'company'}."<br>"; }

	if ($ADDR->{'firstname'} ne '') {
		$c .= $ADDR->{'firstname'}.' '.$ADDR->{'lastname'}."<br>";
		}

	if ($ADDR->{'address1'} ne '') {
		$c .= $ADDR->{'address1'}."<br>".(($ADDR->{'address2'} ne '')?$ADDR->{'address2'}.'<br>':'');
		} 

	#if (($ADDR->{'city'} eq '') && ($ADDR->{'state'} eq '')) {
	#	## no city/state
	#	}
	#else {
	$c .= $ADDR->{'city'}.', '.$ADDR->{'region'}.'. '.$ADDR->{'postal'}." ".$ADDR->{'countrycode'}."<br>\n";	
	#	}
	#elsif (defined $ADDR->{'int_zip'}) {
	#	$c .= $ADDR->{'city'}.', '.$ADDR->{'province'}.', '.$ADDR->{'int_zip'}." ".$ADDR->{'country'}."<br>\n"; 
	#	}
	#else {
	#	$c .= $ADDR->{'city'}.', '.$ADDR->{'state'}.'. '.$ADDR->{'zip'}."<br>\n";
	#	}
	
	$c .= ($ADDR->{'phone'} ne '')?"Phone: ".$ADDR->{'phone'}."<br>":'';
	if ($c eq '') { $c .= "<i>Not Set</i><br>\n"; }
				
	if (($type eq 'ws') && ($ADDR->{'BILLING_CONTACT'} ne '')) {
		$c .= "<br><u>PURCHASING CONTACT:</u><br>$ADDR->{'BILLING_CONTACT'}<br>$ADDR->{'BILLING_PHONE'}<br>";
		}

	return($c);
	}



1;