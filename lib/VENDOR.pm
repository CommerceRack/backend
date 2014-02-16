package VENDOR;

use strict;

use lib "/backend/lib";
require VENDOR::ORDER;

=begin WSDL

   _ATTR _bar $negativeInteger _NEEDED a bar
   _ATTR _boerk $boolean a nillable _boerk

=cut


#/*
#   VENDORS: businesses we buy from
#   each vendor is assigned a 6 digit code that is used to create a unique inventory zone
#*/
# create table VENDORS (
#     ID integer unsigned auto_increment,
#     USERNAME varchar(20) default '' not null,
#     MID integer unsigned default 0 not null,
#     CREATED_TS timestamp  default 0 not null,
#     MODIFIED_TS timestamp  default 0 not null,
#     VENDOR_CODE varchar(6) default '' not null,
#     VENDOR_NAME varchar(41) default '' not null,
#     QB_REFERENCE_ID varchar(41) default '' not null,
#     ADDR1 varchar(41) default '' not null,
#     ADDR2 varchar(41) default '' not null,
#     CITY varchar(31) default '' not null,
#     STATE varchar(21) default '' not null,
#     POSTALCODE varchar(31) default '' not null,
#     PHONE varchar(21) default '' not null,
#     CONTACT varchar(41) default '' not null,
#     EMAIL varchar(100) default '' not null,
#     primary key(ID),
#     unique (MID,VENDOR_CODE)
#   );


sub username { return($_[0]->{'USERNAME'}); }
sub mid { return(int($_[0]->{'MID'})); }
sub id { return($_[0]->{'ID'}); }
sub code { return($_[0]->{'VENDOR_CODE'}); }

##
##
##
sub new {
	my ($class, $USERNAME, %options) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my $self = undef;
	if ($options{'DBREF'}) {
		$self = $options{'DBREF'};
		}
	elsif ($options{'CODE'}) {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select * from VENDORS where MID=$MID and VENDOR_CODE=".$udbh->quote($options{'CODE'});
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
			'VENDOR_NAME'=>'New Vendor',
			'VENDOR_CODE'=>$options{'NEW'},
			};
		}
	else {
		warn "VENDOR was not created due to unknown option!\n";
		}

	if ((defined $self) && (ref($self) eq 'HASH')) {
		bless $self, 'VENDOR';
		}

	return($self);
	}


sub create_order {
	my ($self, %options) = @_;
	my ($vo) = VENDOR::ORDER->new($self,%options);
	return($vo);
	}


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
		$db{$k} = $self->{$k};
		}
	my $is_update = 0;
	if ($self->{'ID'} == 0) { $is_update = 0; } else { $is_update = 2; }
	my $pstmt = &DBINFO::insert($udbh,'VENDORS',\%db,key=>['MID','VENDOR_CODE'],sql=>1,update=>$is_update);
	print STDERR $pstmt."\n";
	$udbh->do($pstmt);

	&DBINFO::db_user_close();
	}

##
## returns a valid 6 digit vendor code.
##
sub valid_vendor_code {
	my ($CODE) = @_;

	$CODE = uc($CODE);		# always uppercase
	$CODE =~ s/[^A-Z0-9]//gs;	# strip non-allowed characters
	if (length($CODE)>6) { $CODE = substr($CODE,0,-1); } # strip down to six characters
	while (length($CODE)<6) { $CODE .= '0'; }	# increase length to 6 digits by appending zeros
	return($CODE);
	}


sub exists {
	my ($USERNAME,$CODE) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select count(*) from VENDORS where MID=$MID /* $USERNAME */ and VENDOR_CODE=".$udbh->quote($CODE);
	my ($exists) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();
	return($exists);
	}


sub nuke {
	my ($self) = @_;

	my ($USERNAME) = $self->username();
	my ($MID) = $self->mid();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "delete from VENDORS where MID=$MID /* $USERNAME */ and VENDOR_CODE=".$udbh->quote($self->code());
	
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
	my $pstmt = "select * from VENDORS where MID=$MID /* $USERNAME */ ";

	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		push @RESULTS, VENDOR->new($USERNAME,'DBREF'=>$hashref);
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@RESULTS);
	}


1;