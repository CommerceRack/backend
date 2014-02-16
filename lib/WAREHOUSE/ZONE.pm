package WAREHOUSE::ZONE;

use Data::GUID qw();
use Data::Dumper qw(Dumper);
use strict;

## some aliases to make stuff easy to get to.
sub W { return($_[0]->{'*W'}); }
sub username { return($_[0]->W()->username()); }
sub mid { return($_[0]->W()->mid()); }
sub geo { return($_[0]->W()->geo()); }
sub zone { return($_[0]->{'ZONE'}); }
sub zonetype { return($_[0]->{'ZONE_TYPE'}); }



sub TO_JSON {
	my ($self) = @_;

	my %clone = ();
	foreach my $k (keys %{$self}) {
		if (ref($self->{$k}) eq '') {
			$clone{$k} = $self->{$k};
			}
		elsif (substr($k,0,1) eq '*') {
			## skip object references (ex: *W)
			}
		elsif ($k eq '%YAML') {
			foreach my $k2 (keys %{$self->{'%YAML'}}) {
				## eg: @POSITIONS should be moved up one level.
				$clone{$k2} = $self->{'%YAML'}->{$k2};
				}
			}
		else {
			$clone{$k} = Clone::clone($self->{$k});
			}
		$clone{'_OBJECT'} = 'ZONE';
		}

	print STDERR 'WAREHOUSE_ZONE: '.Dumper(\%clone);

	return(\%clone);	
	}


###########################################################
##
## get zone for a specific warehouse
##
sub new {
	my ($class, $WAREHOUSE, $zone, %options) = @_;

	my @RESULTS = ();

	my $self = undef;

	if (defined $options{'%DBREF'}) {
		$self = $options{'%DBREF'};
		}
	else {
		my ($udbh) = &DBINFO::db_user_connect($WAREHOUSE->username());
		my $pstmt = "select * from WAREHOUSE_ZONES where MID=".int($WAREHOUSE->mid())." and GEO=".$udbh->quote($WAREHOUSE->geo());
		$pstmt .= " and ZONE=".$udbh->quote($zone); 
		($self) = $udbh->selectrow_hashref($pstmt);
		&DBINFO::db_user_close();
		}

	if ($self->{'YAML'} ne '') {
		$self->{'%YAML'} = YAML::Syck::Load($self->{'YAML'});
		}
	else {
		$self->{'%YAML'} = {};
		}
	delete $self->{'YAML'};

	$self->{'*W'} = $WAREHOUSE;
	bless $self, 'WAREHOUSE::ZONE';

	return($self);
	}


sub add_positions_row {
	my ($self, %vars) = @_;

	if (not defined $self->{'%YAML'}->{'@POSITIONS'}) {
		$self->{'%YAML'}->{'@POSITIONS'} = [];
		}

	my $ref = Storable::dclone(\%vars);
	foreach my $k (keys %{$ref}) {
		if ($k ne lc($k)) { delete $ref->{$k}; }	## only lowercase keys are allowed here.
		}

	if (not $ref->{'uuid'}) { $ref->{'uuid'} = Data::GUID->new()->as_string(); }
	$self->delete_positions_row($ref->{'uuid'});	## remove the duplicate row.
	push @{$self->{'%YAML'}->{'@POSITIONS'}}, $ref;

	return($self);
	}

sub delete_positions_row {
	my ($self, $uuid) = @_;

	if (not defined $self->{'%YAML'}->{'@POSITIONS'}) {
		$self->{'%YAML'}->{'@POSITIONS'} = [];
		}

	my @POSITIONS = ();
	foreach my $row (@{$self->{'%YAML'}->{'@POSITIONS'}}) {
		next if ($row->{'uuid'} eq $uuid);
		push @POSITIONS, $row;
		}
	$self->{'%YAML'}->{'@POSITIONS'} = \@POSITIONS;

	return($self);
	}


sub save {
	my ($self) = @_;

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $YAML = YAML::Syck::Dump($self->{'%YAML'});
	my %dbvars = (
		'MID'=>$self->mid(),
		'GEO'=>$self->geo(),
		'ZONE'=>$self->zone(),
		'ZONE_TITLE'=>$self->{'ZONE_TITLE'},
		'ZONE_PREFERENCE'=>$self->{'ZONE_PREFERENCE'},
		'*CREATED_TS'=>'now()',
		'YAML'=>$YAML,
		);
	my ($pstmt) = &DBINFO::insert($udbh,'WAREHOUSE_ZONES',\%dbvars,key=>['MID','GEO','ZONE'],'verb'=>'update','sql'=>1);
	print STDERR "$pstmt\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	return($self);
	}



1;

__DATA__

############################################################
##
##
##
sub add_location_row {
	my ($self,%options) = @_;

	my ($zone) = $self->zone();
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my @DBKEYS = ('MID','GEO','ZONE');

	my %dbvars = ();
	$dbvars{'USERNAME'} = $self->username();
	$dbvars{'MID'} = $self->mid();
	$dbvars{'GEO'} = $self->geo();
	$dbvars{'ZONE'} = $zone;
	
	$dbvars{'CREATED_BY'} = sprintf("%s",$options{'luser'});
	$dbvars{'*CREATED_TS'} = 'now()';

	if (defined $options{'ROW'}) {
		$dbvars{'ROW'} = $options{'ROW'};
		push @DBKEYS, 'ROW';
		}
	if (defined $options{'SHELF'}) {
		$dbvars{'SHELF'} = $options{'SHELF'};
		push @DBKEYS, 'SHELF';
		}
	if (defined $options{'SLOT'}) {
		$dbvars{'SLOT'} = $options{'SLOT'};
		push @DBKEYS, 'SLOT';
		}

	my $pstmt = &DBINFO::insert($udbh,'WAREHOUSE_ZONE_POSITIONS',\%dbvars,sql=>1,key=>\@DBKEYS);
	print STDERR "$pstmt\n";
	$udbh->do($pstmt);
	
	&DBINFO::db_user_close();
	return();
	}



##########################################################
##
##
##
sub list_locations {
	my ($self,$zone,%options) = @_;

	my ($udbh) = &DBINFO::db_user_connect($self->username());

	my $pstmt = "select * from WAREHOUSE_ZONE_POSITIONS where MID=".int($self->mid())." and GEO=".$udbh->quote($self->code())." and ZONE=".$udbh->quote($zone)." order by ROW,SHELF,SLOT";
	my @POSITIONS = ();
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		push @POSITIONS, $hashref;
		}
	$sth->finish();	
	&DBINFO::db_user_close();
	return(\@POSITIONS);
	}


##
##
##
sub delete_location {
	my ($self,$zone,%options) = @_;

	my ($udbh) = &DBINFO::db_user_connect($self->username());

	my $pstmt = "delete from WAREHOUSE_ZONE_POSITIONS ".
					" where MID=".int($self->mid()).
					" and GEO=".$udbh->quote($self->code()).
					" and ZONE=".$udbh->quote($zone);
	if (defined $options{'ROW'}) {
		$pstmt .= " and ROW=".$udbh->quote($options{'ROW'});
		}
	if (defined $options{'SHELF'}) {
		$pstmt .= " and SHELF=".$udbh->quote($options{'SHELF'});
		}
	if (defined $options{'SLOT'}) {
		$pstmt .= " and SLOT=".$udbh->quote($options{'SLOT'});
		}

	&DBINFO::db_user_close();
	return();
	}





1;