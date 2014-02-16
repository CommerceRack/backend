package EBAY2::APIRESPONSE;

##
## this class is intended to provide common error handling and remdation for known issues.
##		a big piece of ebay is the fact that we need to make so damn many calls, and hopefully giving us
##		a simple way to handle errors will make it easier (and therefore more likely) to do better error
##		handling. - bh 9/25/09
##


##
##
##
sub new {
	my ($class) = @_;
	my $self = {
		'@ERRORS'=>[],		## array of hashrefs { type=>1|4|16 id=>errocde, msg=>short description, detail=>long description }
		'_XML'=>undef,		## the raw xml
		'_SXML'=>undef,	## the sxml
		'_HAS_DATA'=>0,	## will be true if we got data.
		};
	bless $self, $class;
	return($self);
	}



##
## severity - leave undef for all issues.
##		+1 = info
##		+4 = warnings
##		+16 = errors
##		+32 = account consistency errors
##
##	returns an array of errors matching.
##
sub errors {
	my ($self,$severitymask) = @_;
	my @RESPONSE = ();
	foreach my $err (@{$self->{'@ERRORS'}}) {
		if (($err->{'type'} & $severitymask)>0) { 
			push @RESPONSE, $err; 
			}
		}
	
	return(@RESPONSE);
	}

##
## the raw xml
sub xml { my ($self) = @_; return($self->{'_XML'}); }
## the parsed xml
sub sxml { my ($self) = @_; return($self->{'_SXML'}); }

##
## returns a 1 or 0 based on if it's recorded a critical error.
##
sub is_happy {
	my ($self) = @_;

	my $is_happy = 1;
	if ($self->{'_HAS_DATA'}==0) {
		## no data, that makes us sad.
		$is_happy = 0;
		}
	elsif (scalar(@{$self->{'@ERRORS'}})==0) {
		## woot.. we're all good. no errors!
		$is_happy = 1;
		}
	else {
		## search through errors, looking for serverity 16
		foreach my $err (@{$self->{'@ERRORS'}}) {
			if ($err->{'type'} == 16) { $is_happy = 0; }
			}
		}
	return($is_happy);
	}



1;