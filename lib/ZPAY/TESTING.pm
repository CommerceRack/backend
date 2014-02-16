package ZPAY::TESTING;

use strict;

sub new { 
	my ($class) = @_;	
	my $self = {}; 
	bless $self, 'ZPAY::TESTING'; 

	return($self);
	}


use LWP::UserAgent;
use HTTP::Request;

use lib '/backend/lib';
require ZPAY;
require ZWEBSITE;
require ZTOOLKIT;
require ZSHIP;
use strict;

@ZPAY::TESTING::CARDS = (
	## card type, #, cvv, limit
	['American Express','378282246310005',1234,1000],
	['American Express','371449635398431',1234,0],
	['American Express Corporate','378734493671000',1000],
	#['Australian BankCard','5610591081018250'],
	#['Diners Club','30569309025904'],
	#['Diners Club','38520000023237'],
	['Discover','6011111111111117',123,1000],
	['Discover','6011000990139424',123,0],
	#['JCB','3530111333300000'],
	#['JCB','3566002020360505'],
	['MasterCard','5555555555554444',123,1000],
	['MasterCard','5105105105105100',123,0],
	['Visa','4111111111111111',123,1000],
	['Visa','4012888888881881',123,0],
	);


##
## returns a result e.g.
##		'OKAY'	
##
sub is_okay {
	my ($O2,$payrec,%params) = @_;

	#my $card_number = $o->get_attrib('card_number');
	#my $cvv = $o->get_attrib('card_cvvcid');

	my $card_number = $params{'cc_number'};
	my $cvv = $params{'cc_cvvcid'};

	my $found = undef;
	foreach my $line (@ZPAY::TESTING::CARDS) {
		if ($line->[1] ne $card_number) {
			}
		elsif ($line->[2] ne $cvv) {
			}
		else {
			$found = $line;
			}
		}

	my $result = 'ERR';
	if (not defined $found) {
		$result = 'OKAY';
		}
	else {
		$result = 'INVALID';
		}

	return($result,$found->[3]);
	}



########################################
sub authorize {
	my ($self, $O2, $payrec, %params) = @_;

	my $ps = '';
	my ($result,$limit) = &ZPAY::TESTING::is_okay($O2,$payrec,%params);
	
	if ($limit > $payrec->{'amt'}) { $ps = '130'; }	## Pending - TESTING GATEWAY ONLY
	else { $ps = '230'; }								## Denied - TESTING GATEWAY ONLY

	$payrec->{'ps'} = $ps;

	ZPAY::TESTING::log($self,$payrec,$O2,$ps,$result);
	return($payrec);
	} 



########################################
sub capture {
	my ($self, $O2, $payrec, %params) = @_;
	
	my $ps = '';
	my $result = '';

	if ($O2->payment_status() ne '130') {
		$ps = '230';
		$result = 'NOT-AUTHORIZED';
		}
	else {
		$ps = '030';		## Paid in Full - TESTING GATEWAY ONLY
		$result = 'CAPTURE-OKAY';
		}
	$payrec->{'ps'} = $ps;
	$payrec->{'note'} = $result;

	ZPAY::TESTING::log($self,$payrec,$O2,$ps,$result);
	return($payrec);
	} 


########################################
sub charge {
	my ($self, $O2, $payrec, %params) = @_;

	my $ps = '';
	my ($result,$limit) = &ZPAY::TESTING::is_okay($O2);
	if ($limit > $payrec->{'amt'}) {
		$ps = '230';
		$result = 'OVER-LIMIT';
		}
	else {
		$ps = '030';
		}
	$payrec->{'ps'} = $ps;
	$payrec->{'note'} = $result;

	ZPAY::TESTING::log($self,$payrec,$O2,$ps,$result);
	return($payrec);
	} 

########################################
sub void {
	my ($self, $O2, $payrec, %params) = @_;

	my $ps = '630';
	my $result = 'VOID-OKAY';

	$payrec->{'ps'} = $ps;
	$payrec->{'voided'} = time();
	$payrec->{'voidtxn'} = $result;
	
	ZPAY::TESTING::log($self,$payrec,$O2,$ps,$result);
	return($payrec);
	} 

########################################
sub credit {
	my ($self, $O2, $payrec, %params) = @_;

	my $ps = '330';
	my $result = 'CREDIT-OKAY';

	$payrec->{'ps'} = $ps;
	$payrec->{'result'} = $result;
		
	ZPAY::TESTING::log($self,$payrec,$O2,$ps,$result);
	return($payrec);
	} 

########################################
# log transaction to cluster specific transaction table
##
sub log {
	my ($self,$payment,$O2,$ps,$result) = @_;

	my $USERNAME = $O2->username();
	require DBINFO;
	my $udbh = DBINFO::db_user_connect($USERNAME);

	my ($pstmt) = &DBINFO::insert($udbh,'TXNTEST_LOG',{
		'USERNAME'=>$USERNAME,
		'ORDERID'=>$O2->oid(),
		'UID'=>sprintf("%s",$payment->{'uuid'}),
		'CREATED_GMT'=>time(),
		'GATEWAY'=>'TEST',		## should be grabbed from order
		'PS'=> $ps,	##payment status
		'RESULT' => $result,
		'TENDER'=> $payment->{'tender'},
		'AMT'=>$payment->{'amt'},
		},debug=>1+2);
	print STDERR $pstmt."\n";
	my $rows = $udbh->do($pstmt);

	DBINFO::db_user_close();
	return($rows);
	} 



1;

