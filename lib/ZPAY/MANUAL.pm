package ZPAY::MANUAL;


sub webdb { 
	my ($self,$attr) = @_;
	return($self->{'%webdb'}->{$attr}); 
	}

sub new {
   my ($class, $USERNAME, $webdbref) = @_;
   my $self = {};

	$self->{'%webdb'} = $webdbref;

   bless $self, 'ZPAY::MANUAL';
	return($self);
   }

sub is_emulate {
	my $emulate = $self->webdb('cc_emulate_gateway');
	if (not defined $emulate) { $emulate = 0; }
	return($emulate);
	}


sub authorize { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('AUTHORIZE',$O2,$payrec,$payment)); }
sub capture { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CAPTURE',$O2,$payrec,$payment)); }
sub charge { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CHARGE',$O2,$payrec,$payment)); }
sub void { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('VOID',$O2,$payrec,$payment)); }
sub credit { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CREDIT',$O2,$payrec,$payment)); } 

##
## with a manual gateway, we "pretend authorize" the card and set the card # in the note.
## then when the order is captured (set to paid) we destroy the note and mask the card.


sub unified {
	my ($self,$VERB,$O2,$payrec,$payment) = @_;

	my $amt = $payrec->{'amt'};
	if (defined $payment->{'amt'}) {
		$amt = $payment->{'amt'};
		}

	if (($VERB eq 'AUTHORIZE') || ($VERB eq 'CHARGE')) {
		$payrec->{'ps'} = 199;
		$payrec->{'note'} = sprintf("CC:%s YY:%s MM:%s",$payment->{'CC'},$payment->{'YY'},$payment->{'MM'});
		$payrec->{'amt'} = $amt;
		#my %acct = %{$payment};
		#$acct{'CM'} = &ZTOOLKIT::card
		#$payrec->{'acct'} = &ZPAY::packit($payment);
		}
	elsif ($VERB eq 'CAPTURE') {
		$payrec->{'ps'} = '005';
		$payrec->{'note'} = 'Card Info Destroyed Upon Capture';
		$payrec->{'amt'} = $amt;
		}
	elsif (($VERB eq 'CREDIT') || ($VERB eq 'VOID')) {
		my %chain = %{$payrec};
		$chain{'note'} = $payment->{'note'};
		if ($VERB eq 'CREDIT') {
			$chain{'ps'} = 302;
			}
		elsif ($VERB eq 'VOID') {
			$chain{'ps'} = 602;
			$payrec->{'voided'} = time();
			}
		$chain{'puuid'} = $payrec->{'uuid'};
		($payrec) = $O2->add_payment($payrec->{'tender'},$amt,%chain);
		}

	return($payrec);
	}

1;