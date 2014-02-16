package ZPAY::POINTS;


sub new { 
	my ($class,$USERNAME,$WEBDB) = @_;	
	my $self = {};
	$self->{'USERNAME'} = $USERNAME; 
	$self->{'%webdb'} = $WEBDB;
	bless $self, 'ZPAY::GIFTCARD'; 
	return($self);
	}

sub prt { return($_[0]->{'%webdb'}->{'+prt'}); }
sub username { return($_[0]->{'USERNAME'}); }

use lib '/backend/lib';
require ZPAY;
require ZWEBSITE;
require ZTOOLKIT;
require GIFTCARD;
require ZSHIP;
use strict;

sub authorize { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('AUTHORIZE',$O2,$payrec,$payment)); }
sub capture { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CAPTURE',$O2,$payrec,$payment)); }
sub charge { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CHARGE',$O2,$payrec,$payment)); }
sub void { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('VOID',$O2,$payrec,$payment)); }
sub credit { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('REFUND',$O2,$payrec,$payment)); } 

##
##  this is the primary "magic" routine for giftcards
##
sub unified {
	my ($self, $VERB, $O2, $payrec, $payment) = @_;

	my $RESULT = undef;

	## CHARGE and AUTHORIZE are the same thing since giftcards don't support anything else.
	if ($VERB eq 'AUTHORIZE') { $VERB = 'CHARGE'; }

	if ((not defined $O2) || (ref($O2) ne 'CART2')) { 
		$RESULT = "999|Order was not defined"; 
		}
	elsif ($payrec->{'tender'} ne 'POINTS') {
		$RESULT = "900|tender:$payrec->{'tender'} unknown";
		}
	elsif ($VERB eq 'CAPTURE') {
		$RESULT = "252|GIFTCARD does not support $VERB";
		}
	elsif ($payrec->{'amt'}<=0) {
		$RESULT = "901|amt is a required field and must be greater than zero.";
		}
	elsif ((not defined $payment->{'GC'}) && (not defined $payment->{'GI'})) {
		$RESULT = "998|Payment variables not supplied - either GC or GI is required!";
		}


	my $USERNAME = $O2->username();
	my $PRT = $O2->prt();
	my $RS = undef;

	my $AMT = $payment->{'amt'};
	if (not defined $AMT) { $AMT = $payrec->{'amt'}; }

	## refresh the card's with current data (in case somebody already purchased)

	my ($gcref) = undef;
	if (not defined $RESULT) {
		$gcref = &GIFTCARD::lookup($O2->username(),PRT=>$O2->prt(),
			CODE=>sprintf("%s",$payment->{'GC'}),GCID=>$payment->{'GI'}
			);
		if (not defined $gcref) {
			$RESULT = sprintf("970|Giftcard CODE:%s GCID:%s could not be loaded from database",$payment->{'GC'},$payment->{'GI'});
			}
		}

	my $GCID = 0;
	if (defined $gcref) {
		$GCID = $gcref->{'GCID'};
		if (($VERB eq 'CHARGE') && ($gcref->{'BALANCE'}<$AMT)) {
			## card is greater balance due.
			$RESULT = sprintf("270|Giftcard Balance:\$%0.2f  Charge Amount:\$%0.2f",$gcref->{'BALANCE'},$AMT);
			}
		}

	if (defined $RESULT) {
		}
	elsif ($VERB eq 'VOID') {
		$RESULT = "970|Giftcard VOIDS are not supported at this time";
		}
	elsif (($VERB eq 'CHARGE') || ($VERB eq 'REFUND') || ($VERB eq 'VOID')) {

		my ($SPENDorDEPOSIT) = '';
		if ($VERB eq 'CHARGE') { $SPENDorDEPOSIT = 'SPEND'; }
		if ($VERB eq 'REFUND') { $SPENDorDEPOSIT = 'DEPOSIT'; }

		my $DEBUG = "Purchase ".$O2->oid()." for \$".sprintf("%.2f",$AMT);
		print STDERR "******* CARD INFO: cardspend=$AMT cardbalance=$gcref->{'BALANCE'}\n";

		my $LUSERNAME = '';
		if (defined $payrec->{'luser'}) { $LUSERNAME = $payrec->{'luser'}; }

		## should CID=>$CID be set here?
		my ($txn) = &GIFTCARD::update($O2->username(),$GCID,
			$SPENDorDEPOSIT=>$AMT,
			LAST_ORDER=>$O2->oid(),
			LUSER=>$LUSERNAME,
			LOGNOTE=>$DEBUG
			);

		if (not defined $txn) {
			$RESULT = "970|Giftcard update returned undefined txn";
			}
		else {
			my $card_balance_remain = 0;
			if ($SPENDorDEPOSIT eq 'SPEND') {
				$card_balance_remain = sprintf("%0.2f",($gcref->{'BALANCE'}-$AMT));
				$RESULT = "070|$DEBUG";
				}
			elsif ($SPENDorDEPOSIT eq 'DEPOSIT') {
				$card_balance_remain = sprintf("%0.2f",($gcref->{'BALANCE'}+$AMT));
				$RESULT = "370|$DEBUG";
				}

			my $NOTE = sprintf("Points %s [#%d]",&GIFTCARD::obfuscateCode($gcref->{'CODE'},0),$GCID);
			$payrec->{'txn'} = "$gcref->{'CODE'}.$txn";
			$payrec->{'note'} = $NOTE;
			$payrec->{'acct'} = &ZPAY::packit(
				{'GI'=>$GCID,'GC'=>$gcref->{'CODE'}
				});
			$O2->add_history("Giftcard ".&GIFTCARD::obfuscateCode($gcref->{'CODE'},0)." points_debit:$AMT points_balance_remain:$card_balance_remain");
			}
		}
	
	if ($RESULT eq '') { 
		## this line should NEVER be reached!
		$RESULT = "999|Internal error - RESULT was blank"; 
		}

	if (defined $RESULT) {

		my ($PS,$DEBUG) = split(/\|/,$RESULT,2);

		my $chain = 0;
		if (($VERB eq 'AUTHORIZE') || ($VERB eq 'CHARGE')) { $chain = 0; }
		elsif ($VERB eq 'REFUND') { $chain++; }
		elsif (substr($PS,0,1) eq '2') { $chain++; }
		elsif (substr($PS,0,1) eq '3') { $chain++; }
		elsif (substr($PS,0,1) eq '6') { $chain++; $payrec->{'voided'} = time(); }
		elsif (substr($PS,0,1) eq '9') { $chain++; }

		if ($chain) {
			my %chain = %{$payrec};
			delete $chain{'debug'};
			delete $chain{'note'};
			$chain{'puuid'} = $chain{'uuid'};
			$chain{'uuid'} = $O2->next_payment_uuid();
			$payrec = $O2->add_payment($payrec->{'tender'},$AMT,%chain);
			}

		$payrec->{'ts'} = time();	
		$payrec->{'ps'} = $PS;
		$payrec->{'note'} = $payment->{'note'};
		$payrec->{'debug'} = $DEBUG;

		if ($chain) {
			delete $payrec->{'acct'};
			}
		}
	
	$O2->paymentlog("GIFTCARD RESULT: $RESULT");

	return($payrec);
	}



1;