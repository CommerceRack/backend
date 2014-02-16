package ACCOUNT;

use strict;

use YAML::Syck;
use Data::Dumper;
use lib "/backend/lib";
require ZOOVY;
require ZTOOLKIT;

# note there is a spiffy compatibility mode for merchant profile stuff

#
# perl -e 'use lib "/backend/lib"; use ACCOUNT; my ($a) = ACCOUNT->new("brian","brianh"); tie my %ac, 'ACCOUNT', $a; use Data::Dumper;  $ac{"zoovy:email"} = "brian"; $ac{"zoovy:email"} = "brianh"; print Dumper(\%ac,$a);'
# perl -e 'use lib "/backend/lib"; use ACCOUNT; my ($a) = ACCOUNT->new("brian","brian"); use Data::Dumper;  $a->set("bill.fullname","brian"); $a->set("bill.fullname","brianh"); print Dumper($a->get("bill.fullname"));'
#

##
## only compatbile with TIE approach
##
%ACCOUNT::LEGACY_PROFILE_COMPAT = (
	'zoovy:email'=>'bill.email',
	'zoovy:firstname'=>'bill.firstname',
	'zoovy:company_name','org.company',
	'zoovy:firstname','org.firstname',
	'zoovy:lastname'=>'org.lastname',
   'zoovy:email'=>'org.email',
	'zoovy:phone'=>'org.phone',
	'zoovy:address1'=>'org.address1',
	'zoovy:address2'=>'org.address2',
	'zoovy:city'=>'org.city',
	'zoovy:state'=>'org.region',
	'zoovy:zip'=>'org.postal',
	'zoovy:support_email'=>'tech.email',
	'zoovy:support_phone'=>'tech.phone',
	);

%ACCOUNT::VALID_FIELDS = (
	'bill.email'=>'',
	'bill.firstname'=>'',
	'bill.lastname'=>'',
	'bill.phone'=>'',
	'bill.mobile'=>'',
	'bill.newsletter'=>'',

	'tech.email'=>'',
	'tech.firstname'=>'',
	'tech.lastname'=>'',
	'tech.phone'=>'',
	'tech.mobile'=>'',
	'tech.newsletter'=>'',

	'org.company'=>'',
	'org.email'=>'',
	'org.firstname'=>'',
	'org.lastname'=>'',
	'org.phone'=>'',
	'org.mobile'=>'',

	'org.city'=>'',
	'org.region'=>'',
	'org.postal'=>'',
	'org.country'=>'',
	'org.address1'=>'',
	'org.address2'=>'',
	'org.newsletter'=>'',

	'org.type'=>'',
	'org.ein'=>'',

	'info.employees'=>'',
	'info.founded'=>'',
	'info.sales'=>'',
	);

sub DESTROY {
	my ($self) = @_;

	if ($self->{'_tied'}==0) {
		}
	else {
		$self->{'_tied'}--;
		}
	}

##
## you can tie one of these options.
##
sub TIEHASH {
	my ($class, $ACCOUNT) = @_;
	my $self = $ACCOUNT;
	if ((not defined $self) || (ref($self) ne 'ACCOUNT')) {
		die("must pass valie ACCOUNT object to tie");
		}
	$self->{'_tied'}++;
	return($self);
	}

sub FETCH { 
	my ($this,$key) = @_; 	
	if (defined $ACCOUNT::LEGACY_PROFILE_COMPAT{$key}) { $key = $ACCOUNT::LEGACY_PROFILE_COMPAT{$key}; }
	return($this->get($key));
	}

sub EXISTS { 
	my ($this,$key) = @_; 
	if (defined $ACCOUNT::LEGACY_PROFILE_COMPAT{$key}) { $key = $ACCOUNT::LEGACY_PROFILE_COMPAT{$key}; }
	return( (defined $this->get($key))?1:0 ); 
	}

sub DELETE { 
	my ($this,$key) = @_; 
	if (defined $ACCOUNT::LEGACY_PROFILE_COMPAT{$key}) { $key = $ACCOUNT::LEGACY_PROFILE_COMPAT{$key}; }
	$this->set($key,undef);
	return(0);
	}

sub STORE { 
	my ($this,$key,$value) = @_; 

	if (defined $ACCOUNT::LEGACY_PROFILE_COMPAT{$key}) { $key = $ACCOUNT::LEGACY_PROFILE_COMPAT{$key}; }

	$this->set($key,$value);	

	return(0); 
	}

sub CLEAR { 
	my ($this) = @_; 
	
	#foreach my $k (keys %{$this}) {
	#	next if (substr($k,0,1) eq '_');
	#	delete $this->{$k};
	#	}
	return(0);
	}

sub FIRSTKEY {
	my ($this) = @_;

	my @THEKEYS = ();
	foreach my $k (sort keys %{$this}) {
		next if (substr($k,0,1) eq '_');
			next if (substr($k,0,1) eq '@');
		if (ref($this->{$k}) eq '') {
			push @THEKEYS, "$k";
			}
		elsif (ref($this->{$k}) eq 'HASH') {
			foreach my $k2 (sort keys %{$this->{$k}}) {
				push @THEKEYS, "$k.$k2";
				}
			}
		}

	print Dumper(\@THEKEYS);

	$this->{'@'} = \@THEKEYS;
	return(pop @THEKEYS);
	}

#
#
#
sub NEXTKEY {
	my ($this) = @_;
	return(pop @{$this->{'@'}});
	}

#
#
#
sub TO_JSON {
	my ($self) = @_;

	my %R = ();
	foreach my $k (keys %{$self}) {
		$R{$k} = $self->{$k};
		}

	return(\%R);
	};


##
##
##
sub new {
	my ($class, $USERNAME, $LUSER, %params) = @_;

	my $self = undef;
	my ($path) = &ZOOVY::resolve_userpath($USERNAME);
	if (! -f "$path/contact.yaml") {
		$self = {};
		$self->{'_USERNAME'} = $USERNAME;
		$self->{'_MID'} = &ZOOVY::resolve_mid($USERNAME);
		$self->{'_CREATED'} = &ZTOOLKIT::pretty_date(time(),3);
		$self->{'@log'} = [];
		}
	else {
		$self = YAML::Syck::LoadFile("$path/contact.yaml");
		}
	$self->{'_LUSER'} = $LUSER;
	bless $self, 'ACCOUNT';
	return($self);
	}

##
##
##
sub username { return($_[0]->{'_USERNAME'}); }
sub mid { return(int($_[0]->{'_MID'})); }
sub luser { return($_[0]->{'_LUSER'}); }
##
##
sub flags { 
	my ($self) = @_;
	if (not defined $self->{'CACHED_FLAGS'}) {
		my ($globalref) = &ZWEBSITE::fetch_globalref($self->username());
		$self->{'CACHED_FLAGS'} = $globalref->{'cached_flags'};
		}	
	return($self->{'CACHED_FLAGS'}); 
	}

sub is_bpp { 
	my ($self) = @_;
	if ($self->flags() =~ /,BPP,/) { return(1); }
	return(0); 
	}

sub get {
	my ($self, $attr) = @_;

	my $ref = $self;
	my @parts = split(/\./,$attr);
	my $piece = pop @parts;
	foreach my $part (@parts) { $ref = $ref->{$part}; }	# descend tree
	return($ref->{$piece});
	}

##
##
sub set {
	my ($self, $attr, $value) = @_;

	my $ref = $self;
	my @parts = split(/\./,$attr);
	my $piece = pop @parts;
	foreach my $part (@parts) { 
		# descend tree
		if (not defined $ref->{$part}) { $ref->{$part} = {}; }
		$ref = $ref->{$part}; 
		}	

	if (not defined $value) {
		## a delete
		if (not defined $ref->{$piece}) {
			## it's okay, nothing to delete
			}
		else {
			$self->log("[d]\t$piece\t$ref->{$piece}");
			}
		}
	elsif (not defined $ref->{$piece}) {
		## initialized value
		$ref->{$piece} = $value;
		}
	elsif ($ref->{$piece} eq $value) {
		## value is the same
		}
	else {
		$self->log("[u]\t$attr\t$ref->{$piece}");
		$ref->{$piece} = $value;
		}
	return();
	}


##
##
sub log {
	my ($self,$msg) = @_;
	
	if (not defined $self->{'@log'}) {
		$self->{'@log'} = [];
		}
	push @{$self->{'@log'}}, ZTOOLKIT::pretty_date(time(),3)."\t".$self->luser()."\t$msg";
	}

##
##
sub save {
	my ($self) = @_;

	# $file can be an IO object, or a filename
	my $THEKEYS = $self->{'@'};
	if (defined $THEKEYS) {
		delete $self->{'@'};
		}

	my ($path) = &ZOOVY::resolve_userpath($self->username());
	if (! -d $path) {
		warn "PATH: $path does not exist\n";
		}
	else {
		YAML::Syck::DumpFile("$path/contact.yaml",$self);
		chmod 0666, "$path/contact.yaml";
		}

	if (defined $THEKEYS) {
		$self->{'@'} = $THEKEYS;
		}
	}

##
##
##


1;