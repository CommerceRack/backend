package CFG;


use strict;
use Data::Dumper;
use File::Slurp;
use YAML::Syck;
use JSON::XS;
use Storable;

$::CFGFILE = "/etc/commercerack.ini";
$::CACHEFILE = "/dev/shm/commercerack.json";
$::CFG = undef; 
##
##
##
sub new {
	my ($CLASS, %options) = @_;
	
	if (defined $::CFG) { return($::CFG); }
	
	if (! -f $::CFGFILE) {
		die("missing $::CFGFILE file");
		}

	my $self = undef;
	my $coder = JSON::XS->new->ascii->pretty->allow_nonref->convert_blessed;

	my $fh = undef;
	if (-f $::CACHEFILE) {
		open( $fh, "<", $::CACHEFILE ) || die "Can't open $fh: $!";
		my $json = join("",<$fh>);
		close $fh;
		eval { $self = $coder->decode($json); };
		if (defined $self) {
			bless $self, 'CFG';
			}
		}

	if ($options{'recompile'}) {
		## now if we're recompiling then toss the result.
		$self = undef;
		}		

	if (not defined $self) {
		print STDERR "INIT CFG\n";
		$self = {};
		$self->{'$HOSTNAME$'} = `/bin/hostname`; $self->{'$HOSTNAME$'} =~ s/[\n\r]*//gs;
		bless $self, 'CFG';
		$self->read_ini($::CFGFILE,'');

		open $fh, ">", $::CACHEFILE || die "can't open $fh for write";
		print $fh $coder->encode($self);
		close $fh;
		}


	$::CFG = $self;

	return($self);
	}


##
##
##
sub TO_JSON {
	my ($self) = @_;
	my %result = ();
	foreach my $k (keys %{$self}) {
		if (ref($self->{$k}) eq '') {
			$result{$k} = $self->{$k};
			}
		else {
			$result{$k} = Storable::dclone($self->{$k});
			}
		}
	return(\%result);
	}


##
## same as calling new->get()
##
##	intended for shell scripts:
## perl -e 'use lib "/backend/lib"; use CFG; CFG->print("apache","\@roles");
##
sub print {
	my ($CLASS, $node,$key) = @_;

	my $result = undef;
	my $self = $CLASS->new();

	if ($node =~ /^type\:(.*?)$/) {
		$result = $self->matches('type',$1);
		}

	if (not defined $result) {
		$result = $self->get($node,$key);
		}

	if (ref($result) eq '') { print "$result\n" }
	elsif (ref($result) eq 'ARRAY') { print join(" ",@{$result})."\n"; }
	else { die("invalid return"); }

	return($self);
	}


sub get {
	my ($self,$node,$key) = @_;

	if ($node eq '$HOSTNAME$') {	
	  $node = $self->{'$HOSTNAME$'};
	  }

	if (not defined $key) {	
		if (not defined $self->{$node}) { 
			if (substr($node,0,1) eq '@') { return([]); }
			return(undef);
			}
		return($self->{$node}); 
		}
	if (defined $self->{$node}) {
		return($self->{$node}->{$key});
		}
	}


sub users { return( $_[0]->matches('type','user') ); }
sub user { return($_[0]->get(uc($_[0]))); }

sub matches {
	my ($self, $key, $value) = @_;

	my @MATCHES = ();	
	foreach my $k (keys %{$self}) {
		next if (substr($k,0,1) eq '_');
		next if (substr($k,0,1) eq '@');
		next if (substr($k,0,1) eq '$');
		if ($self->{$k}->{$key} eq $value) {
			push @MATCHES, $k;
			}
		}
	return(\@MATCHES);
	}



##
## reads in commercerack.ini
##
sub read_ini {
	my ($self, $filename, $SECTION) = @_;

	my $CFG = $self;
	if (not defined $CFG->{'@TYPES'}) { $CFG->{'@TYPES'} = []; }

	my $line = 0;
	open F, $filename;
	my @lines = File::Slurp::read_file($filename);
	close F;

	foreach (@lines) {
		$line++;
		## ignore comments and blank lines
		next if (substr($_,0,1) eq '#');	
		$_ =~ s/[\n\r]+//gs;
      # print "$_\n";
		
		if ($_ =~ /^\[(.*?)\:(.*?)\]$/) {
			## [type:name] 
			my ($TYPE,$ALIAS) = ($1,$2);
			$CFG->{$ALIAS}->{'type'} = $TYPE; 
			$SECTION = $ALIAS;
			next;
			}
		elsif ($_ =~ /^\[(.*?)\]$/) {
			## [type] 
			my ($TYPE) = $1;
			$CFG->{$TYPE}->{'type'} = $TYPE;
			$SECTION = $TYPE;
			next;
			}
		elsif ($_ =~ /^!/) {
			## any link which starts with a ! is a directive and we should process it.
			}
		#elsif ($_ eq '') {
		#	## a single blank link resets the section.
		#	$SECTION = '';
		#	next;
		#	}
			
		next if ($_ eq '');
		 
		my ($k,$v) = split(/\:[\s\t]*/,$_,2);
		
		## detect type of $v
		if (substr($k,0,1) eq '@') {
			## multivalue	key: val1, val2, val3
			my @VALS = ();
			foreach my $v1 (split(/,/,$v)) {
				$v1 =~ s/^[\s]+//gs;	# strip leading/trailing spaces
				$v1 =~ s/[\s]+$//gs;
				next if ($v1 eq '');
				push @VALS, $v1;
				}	
			$v = \@VALS;
			}
		elsif (substr($k,-1) eq '<') {
			## read value from a file, ex: pem_file<:  (strips < from key)
			if (! -f $v) {
				warn "$filename\[$line\] $k could not read \'$v\'";
				$v = undef;
				}
			else {
				$k = substr($k,0,-1);
				$v = File::Slurp::read_file($v); 
				}
			}
		elsif (substr($k,0,1) eq '!') {
			if (not defined $v) { $v = ''; }
			}
		else {
			## a regular $v
			}
			
		if (not defined $v) {
			## ignore!
			}
		elsif (substr($k,0,1) eq '!') {
			## clean directive ex: !include
			## print "K: $k\n";
			if ($k eq '!include') {
				my (@FILES) = glob $v;
				foreach my $file (@FILES) {
					if (! -f $file) {
						print STDERR "$filename\[$line\] !include $file failed.\n";
						}
					else {
						$self->read_ini($file,$SECTION);
						}
					}
				}
			elsif ($k eq '!users') {
				my (@FILES) = glob "$v";
				foreach my $file (@FILES) {
					if ($file =~ /\/platform\.yaml$/) {
						my $USER = YAML::Syck::LoadFile($file);
                  my ($username) = $USER->{'username'};
                  $USER->{'type'} = 'user';
                  $CFG->{uc("$username")} = $USER;
						}
					else {
						warn "$filename\[$line\] !usersdir globbed invalid file $file\n";
						}
					}
				}
			#elsif ($k eq '!domain_discover') {
			#	foreach my $USERNAME (@{$self->matches('type','user')}) {
			#		my $ref = $self->get($USERNAME);
			#		
			#		print Dumper($ref);
			#		}
			#	}
			else {
				warn "Unknown directive in $k line $line\n";
				}
			}
		else {
			## just save the value
			$CFG->{$SECTION}->{$k} = $v;
			}
		}
	return($CFG);	
	}


1;