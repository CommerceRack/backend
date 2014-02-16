package CUSTOMER::ORGANIZATION;

use Data::Dumper;
use strict;

%CUSTOMER::ORGANIZATION::VALID_FIELDS = (
	## SHARED FIELDS
	'firstname'=>1,'middlename'=>1,'lastname'=>1,'company'=>1,
	'address1'=>1,'address2'=>1,
	'city'=>1,'region'=>1,'postal'=>1,'countrycode'=>1,
	'phone'=>1, 'email'=>1,
	## ORGANIZATION FIELDS
	'ALLOW_PO'=>2,
	'SCHEDULE'=>2,
	'RESALE'=>2,
	'RESALE_PERMIT'=>2,
	'CREDIT_LIMIT'=>2,
	'CREDIT_BALANCE'=>2,
	'CREDIT_TERMS'=>2,
	'ACCOUNT_MANAGER'=>2,
	'ACCOUNT_TYPE'=>2,
	'ACCOUNT_REFID'=>2,
	'JEDI_MID'=>2,
	'DOMAIN'=>2,
	'LOGO'=>2,
	'IS_LOCKED'=>2,
	'BILLING_PHONE'=>2,					##
	'BILLING_CONTACT'=>2,				## 
	);


sub has_changed { my ($self) = @_; return(int($self->{'_rw'})); }
sub set_changed { my ($self) = @_; return(++$self->{'_rw'}); }


##
## PAGE::JQUERY uses this method
##
sub TO_JSON {
	my ($self) = @_;

	my %result = ();
	if ($self->orgid()>0) {
		## transport: bill/firstname, bill/lastname, etc.
		foreach my $k (keys %CUSTOMER::ORGANIZATION::VALID_FIELDS) {
			$result{sprintf("%s",$k)} = $self->{$k};
			}
		}

	return(\%result);
	}


sub orgid { my ($self) = @_; return(int($self->{'ORGID'})); }
sub id { my ($self) = @_; return(int($self->{'ORGID'})); }

sub cid { my ($self) = @_; return(int($self->{'CID'})); }
sub mid { my ($self) = @_; return(int($self->{'MID'})); }
sub prt { my ($self) = @_; return(int($self->{'PRT'})); }
sub username { my ($self) = @_; return($self->{'USERNAME'}); }
sub schedule { my ($self) = @_; return($self->get('SCHEDULE')); }

sub type { my ($self) = @_; return('ORG'); }
sub customer { my ($self) = @_; return($self->{'*CUSTOMER'}); }


##
##
##
sub create {
	my ($class, $USERNAME, $PRT, $ref) = @_;
	my $self = {};

	foreach my $k (keys %{$ref}) {
		$self->{$k} = $ref->{$k};
		}
	$self->{'USERNAME'} = $USERNAME;
	$self->{'MID'} = &ZOOVY::resolve_mid($USERNAME);
	$self->{'PRT'} = $PRT;
	$self->{'ORGID'} = 0;

	bless $self, 'CUSTOMER::ORGANIZATION';
	return($self);
	}


sub nuke {
	my ($self) = @_;

	my ($MID) = $self->mid();
	my ($PRT) = $self->prt();
	my ($ORGID) = $self->orgid();

	my $udbh = &DBINFO::db_user_connect($self->username());
	my $pstmt = "delete from CUSTOMER_WHOLESALE where MID=$MID and PRT=$PRT and ID=$ORGID";
	print STDERR "$pstmt\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	return();
	}

##
##
##
sub new_from_orgid {
	my ($class, $USERNAME, $PRT, $ORGID) = @_;
	
	my $self = {};
	my $MID = int(&ZOOVY::resolve_mid($USERNAME)); 
	$PRT = int($PRT);
	$ORGID = int($ORGID);

	my $odbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select * from CUSTOMER_WHOLESALE where MID=$MID and PRT=$PRT and ID=$ORGID";
	my $sth = $odbh->prepare($pstmt);
	$sth->execute();
	if ($sth->rows()) { 
		($self) = $sth->fetchrow_hashref();
		$self->{'ORGID'} = $self->{'ID'}; 
		delete $self->{'ID'};
		}
	$sth->finish();
	&DBINFO::db_user_close();

	bless $self, 'CUSTOMER::ORGANIZATION';
	return($self);
	}


##
## 
##
#sub new_from_customer {
#	my ($class, $C, $ref) = @_;
#
#	if (ref($C) ne 'CUSTOMER') {
#		print STDERR Carp::cluck("need to pass a customer reference to CUSTOMER::ORGANIZATION->new()");
#		}
#
#	my $self = {};
#	if (not defined $ref) {
#		my $MID = int($C->mid()); 
#		my $CID = int($C->cid());	
#		my $odbh = &DBINFO::db_user_connect($C->username());
#		my $pstmt = "select * from CUSTOMER_WHOLESALE where MID=$MID and CID=$CID";
#		my $sth = $odbh->prepare($pstmt);
#		$sth->execute();
#		if ($sth->rows()) { 
#			($self) = $sth->fetchrow_hashref();
#			$self->{'CONTACT'} = $self->{'BILLING_CONTACT'};  delete $self->{'BILLING_CONTACT'};
#			}
#		$sth->finish();
#		&DBINFO::db_user_close();
#		}
#
#	$self->{'*CUSTOMER'} = $C;
#	bless $self, 'CUSTOMER::ORGANIZATION';
#
#	return($self);
#	}


sub get {
	my ($self, $property) = @_;
	return($self->{$property});
	}

sub set {
	my ($self, $property, $value) = @_;
	## mark the WS as "rw" (if it's rw=0 then we won't save)
	$self->{ $property } = $value;
	$self->{'_rw'}++;
	return($self); 
	}


##
## formerly: save_ship_info save_bill_info
##
sub save {
	my ($self, %options) = @_;

	my %params = ();
	$params{'ID'} = $self->orgid();
	$params{'CID'} = $self->cid();
	if ($options{'create'}) {
		$params{'USERNAME'} = $self->username();
		delete $params{'CID'};
		## CREATED?
		}

	$params{'MID'} = $self->mid();
	$params{'PRT'} = $self->prt();
	$params{'firstname'} = sprintf("%s",$self->{'firstname'});
	$params{'lastname'} = sprintf("%s",$self->{'lastname'});
	$params{'company'} = sprintf("%s",$self->{'company'});
	$params{'address1'} = sprintf("%s",$self->{'address1'});
	$params{'address2'} = sprintf("%s",$self->{'address2'});
	$params{'city'} = sprintf("%s",$self->{'city'});
	$params{'region'} = sprintf("%s",$self->{'region'});
	$params{'postal'} = sprintf("%s",$self->{'postal'});
	$params{'phone'} = sprintf("%s",$self->{'phone'});
	$params{'countrycode'} = sprintf("%s",$self->{'countrycode'});
	$params{'LOGO'} = sprintf("%s",$self->{'LOGO'});
	$params{'ALLOW_PO'} = sprintf("%s",$self->{'ALLOW_PO'});
	$params{'RESALE'} = sprintf("%s",$self->{'RESALE'});
	$params{'CREDIT_LIMIT'} = sprintf("%s",$self->{'CREDIT_LIMIT'});
	$params{'CREDIT_BALANCE'} = sprintf("%s",$self->{'CREDIT_BALANCE'});
	$params{'CREDIT_TERMS'} = sprintf("%s",$self->{'CREDIT_TERMS'});
	$params{'ACCOUNT_MANAGER'} = sprintf("%s",$self->{'ACCOUNT_MANAGER'});
	$params{'ACCOUNT_TYPE'} = sprintf("%s",$self->{'ACCOUNT_TYPE'});
	$params{'ACCOUNT_REFID'} = sprintf("%s",$self->{'ACCOUNT_REFID'});
	$params{'RESALE_PERMIT'} = sprintf("%s",$self->{'RESALE_PERMIT'});
	$params{'BILLING_CONTACT'} = sprintf("%s",$self->{'BILLING_CONTACT'});
	$params{'BILLING_PHONE'} = sprintf("%s",$self->{'BILLING_PHONE'});
	$params{'EMAIL'} = sprintf("%s",$self->{'EMAIL'});
	$params{'DOMAIN'} = sprintf("%s",$self->{'DOMAIN'});
	$params{'SCHEDULE'} = sprintf("%s",$self->{'SCHEDULE'});
	$params{'IS_LOCKED'} = sprintf("%d",int($self->{'IS_LOCKED'}));

	my $VERB = ($options{'create'})?'insert':'update';

	my $odbh = &DBINFO::db_user_connect($self->username());
	my ($pstmt) = &DBINFO::insert($odbh,'CUSTOMER_WHOLESALE',\%params,'verb'=>$VERB,key=>['MID','PRT','ID'],debug=>1,sql=>1);
	print STDERR "$pstmt\n";
	$odbh->do($pstmt);

	if ($VERB eq 'insert') {
		$pstmt = "select last_insert_id()";
		$self->{'ORGID'} = $odbh->selectrow_array($pstmt);
		}

	&DBINFO::db_user_close();

	return(0);
	}


## 201318 and below need this.
sub as_legacy_wholesale_hashref {
	my ($self) = @_;
	my %out = ();

	$out{'CONTACT'} = $self->{'BILLING_CONTACT'};
	foreach my $k (
		'firstname','middlename','lastname','company','address1','address2','city','region','postal','countrycode',
		'phone','email',
		'ALLOW_PO','SCHEDULE','RESALE','RESALE_PERMIT',
		'CREDIT_LIMIT','CREDIT_BALANCE','CREDIT_TERMS','ACCOUNT_MANAGER','ACCOUNT_TYPE','ACCOUNT_REFID','JEDI_MID'
		) {
		$out{$k} = $self->get($k);
		}
	return(\%out);
	}


sub from_legacy_wholesale_hashref {
	##	not currently implemented.
	}




1;