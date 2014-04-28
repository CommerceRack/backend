package BLAST;

use strict;
use Data::Dumper;
use Storable;
use Scalar::Util;
use Data::Structure::Util;


#require BLAST::MSG::LEGACY;
require ZWEBSITE;
#require BLAST::MSG::KISS2;
require BLAST::RECIPIENT::CUSTOMER;
require BLAST::RECIPIENT::EMAIL;
require BLAST::RECIPIENT::CONSOLE;
#require BLAST::RECIPIENT::APNS;
#require BLAST::RECIPIENT::GCM;
#require BLAST::RECIPIENT::ADM;
#require BLAST::RECIPIENT::SMS;
require BLAST::MSG;
require BLAST::DEFAULTS;

##
## steps to send a message:
##		my ($b) = BLAST->new($USERNAME,$PRT);
##		my ($rcpt) = $b->recipient( 'EMAIL', 'brian@zoovy.com' );
##
my $test = q~ 
perl -e 'use Data::Dumper; use lib "/backend/lib"; use BLAST; 
my ($b) = BLAST->new("sporks",0); 
my ($rcpt) = $b->recipient( "EMAIL", "brian\@zoovy.com" ); print Dumper($rcpt); 
my ($msg) = $b->msg("HTML5","subject","body",{"x"=>"y"}); print Dumper($msg);
$b->send($rcpt,$msg);
'
~;


##
## these will get interpolated
##
sub macros {
	my ($self) = @_;

	if (not defined $self->{'%MACROS'}) {
		$self->{'%MACROS'} = Storable::dclone \%BLAST::DEFAULTS::MACROS;
		my ($udbh) = &DBINFO::db_user_connect($self->username());
		my ($MID) = $self->mid();
		my $pstmt = "select MACROID,BODY from BLAST_MACROS where MID=$MID";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($MACROID, $BODY) = $sth->fetchrow() ) {
			$self->{'%MACROS'}->{$MACROID} = $BODY;
			}
		$sth->finish();
		&DBINFO::db_user_close();
		}
	return($self->{'%MACROS'});
	}

##
## 
##
sub new {
	my ($class,$USERNAME,$PRT,%meta) = @_;

	my $self = {};
	$self->{'USERNAME'} = $USERNAME;
	$self->{'PRT'} = $PRT;

	$self->{'%META'} = \%meta;
	bless $self, 'BLAST';


	my ($webdb) = &ZWEBSITE::fetch_website_dbref($self->username(),$self->prt());
	if ($webdb->{'%BLAST'}) { $self->{'%META'}->{'%PRT'} = $webdb->{'%BLAST'}; }
	if (not defined $self->{'%META'}->{'%PRT'}) { $self->{'%META'}->{'%PRT'} = {}; }
	if (not defined $self->{'%META'}->{'%PRT'}->{'EMAIL'}) { 
		$self->{'%META'}->{'%PRT'}->{'EMAIL'} = $webdb->{'from_email'}; 
		}

	$self->{'%META'}->{'%ENV'} = \%ENV;	## ex: %ENV.REMOTE_ADDR 
	
	return($self);
	}

sub username { return($_[0]->{'USERNAME'}); }
sub mid { return(&ZOOVY::resolve_mid($_[0]->{'USERNAME'})); }
sub prt { return($_[0]->{'PRT'}); }
sub webdb { return(&ZWEBSITE::fetch_website_dbref($_[0]->username(),$_[0]->prt())); }
sub meta { return($_[0]->{'%META'} || {}); }

sub send {
	my ($self, $recipient, $msg) = @_;

	## MAKE A COPY OF ALL FIELDS
	my $sendmsg = $msg;


	if ($msg->format() ne 'XXX') {
		my %data = ();
		foreach my $k (keys %{$msg->meta()}) { $data{$k} = $msg->meta()->{$k}; }
		foreach my $k (keys %{$recipient->meta()}) { $data{$k} = $recipient->meta()->{$k}; }
		foreach my $k (keys %{$self->meta()}) { $data{$k} = $self->meta()->{$k}; }

		

		## now attempt to serialize any blessed objects
		foreach my $k (keys %data) {
			if ((substr($k,0,1) eq '%') && (ref($data{$k}) ne 'HASH')) {
				## we have a %KEY which is not actually a hash
				if ( Scalar::Util::blessed($data{$k}) && $data{$k}->can('TO_JSON') ) {
					## run the TO_JSON function (which will return a unblessed, cloned copy)
					$data{$k} = $data{$k}->TO_JSON();
					} 
				$data{$k} = Data::Structure::Util::unbless($data{$k});
				}
			}


		## already, now create a new sendmsg that's a clone of the original msg
		$sendmsg = Storable::dclone($msg);
		bless $sendmsg, 'BLAST::MSG';

		#open F, ">/dev/shm/tlc";
		#print F Dumper({
		#	'BODY'=>$sendmsg->body(),
		#	'SUBJECT'=>$sendmsg->subject(),
		#	'DATA'=>\%data});
		#close F;

		my $tlc = TLC->new('username'=>$self->username());
		($sendmsg->{'BODY'}) = $tlc->render_html($sendmsg->body(), \%data);
		($sendmsg->{'SUBJECT'}) = $tlc->render_html($sendmsg->subject(), \%data);
		}

	## print Dumper($sendmsg->{'SUBJECT'}); die();
	$recipient->send($sendmsg);		
	return();	
	}

##
## creates a recipient object
##
sub recipient {
	my ($self, $TYPE, $REF, $METAREF) = @_;

	if ($TYPE eq 'CART') {
		## type "CART" isn't actually a valid destination (at this point) so we'll try and find the best route.
		my ($CART2) = $REF;
		
		if ($CART2->customerid()>0) {			
			($TYPE) = 'CUSTOMER';
			$REF = $CART2->customer();
			}
		elsif ($CART2->in_get('bill/email') ne '') {
			($TYPE) = 'EMAIL';
			$REF = $CART2->in_get('bill/email');
			}
		else {
			($TYPE) = 'CONSOLE';
			$REF = '';
			}
		}

#	open F, ">/tmp/msgclass";
#	print F Dumper($TYPE,$REF,$METAREF);
#
	my $class = "BLAST::RECIPIENT::$TYPE";
	my ($recipient) = $class->new($self, $REF, $METAREF);
	
#	print F "----------------------\n";
#	print F Dumper($recipient);
#	close F;

	return($recipient);
	}

##
##	HTML5, subject, body, {} 
## LEGACY, MSGID, {}
##	KISS2, MSGID, {}
##
sub msg {
	my ($self, $MSGID, @params) = @_;
	my ($msg) = BLAST::MSG->new($self,$MSGID,@params);

	if ($msg->format() =~ /^(HTML|TEXT|XML)$/) {
		$msg->{'BODY'} = &ZTOOLKIT::interpolate( $self->macros(), $msg->{'BODY'} );
		# use Data::Dumper; print Dumper(\%BLAST::MSG::LEGACY::TLC); die();
		$msg->{'SUBJECT'} = &ZTOOLKIT::interpolate( $self->macros(), $msg->{'SUBJECT'} );
		$msg->{'FORMAT'} = 'HTML5';
		}


	return($msg);
	}


1;