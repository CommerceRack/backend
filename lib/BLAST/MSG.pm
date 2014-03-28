package BLAST::MSG;

use strict;
use lib "/backend/lib";
use TLC;
use BLAST::DEFAULTS;
use Data::Dumper;

sub blaster { return($_[0]->{'*BLASTER'}); }
sub username { return($_[0]->blaster()->username()); }
sub prt { return($_[0]->blaster()->prt()); }
sub msgid {  return($_[0]->{'MSGID'}); }

sub bcc { return($_[0]->{'BCC'}); }
sub body { return($_[0]->{'BODY'}); }
sub subject { return($_[0]->{'SUBJECT'}); }
sub meta { return($_[0]->{'%META'}); }
sub format { return($_[0]->{'FORMAT'}); }
sub _is_empty { return( length($_[0]->{'BODY'}) == 0 ); }

sub new {
	my ($class, $BLASTER, $MSGID, $metaref) = @_;

	my $self = {};

	if (not defined $metaref) { $metaref = {}; }
	my ($BODY,$SUBJECT) = ();

	$self->{'*BLASTER'} = $BLASTER;
	$self->{'MSGID'} = $MSGID || $metaref->{'MSGID'} || "__HTML5__";
	$self->{'FORMAT'} = "HTML5x";
	bless $self, 'BLAST::MSG';

	$self->{'%META'} = $metaref;
	
	my @PARTS = split(/\./,$MSGID);
	print STDERR Dumper($MSGID,$metaref)."\n";

	if (defined $metaref->{'BODY'}) {
		$self->{'BODY'} = $metaref->{'BODY'};
		$self->{'SUBJECT'} = $metaref->{'SUBJECT'};
		}
	elsif (scalar(@PARTS)>0) {
		my ($udbh) = &DBINFO::db_user_connect($self->username());
		my ($MID) = &ZOOVY::resolve_mid($self->username());
		my ($PRT) = $self->prt();

		do {
			$MSGID = join('.',@PARTS);
	
			my $pstmt = "select BODY,SUBJECT,FORMAT,MSGBCC from SITE_EMAILS where MID=$MID and PRT=$PRT and MSGID=".$udbh->quote($MSGID);
			print $pstmt."\n";
			($self->{'BODY'},$self->{'SUBJECT'},$self->{'FORMAT'},$self->{'BCC'}) = $udbh->selectrow_array($pstmt);

			if (($self->{'SUBJECT'} eq '') && (defined $BLAST::DEFAULTS::MSGS{$MSGID})) {
				$self->{'BODY'} = $BLAST::DEFAULTS::MSGS{$MSGID}->{'MSGBODY'};
				$self->{'SUBJECT'} = $BLAST::DEFAULTS::MSGS{$MSGID}->{'MSGSUBJECT'};
				$self->{'FORMAT'} = $BLAST::DEFAULTS::MSGS{$MSGID}->{'MSGFORMAT'};
				$self->{'BCC'} = '';
				}	
			
			if ($self->{'SUBJECT'} eq '') { pop @PARTS; } else { $self->{'MSGID'} = $MSGID; }
			}
		while ( (scalar(@PARTS)>0) && ($self->{'BODY'} eq '') );


		&DBINFO::db_user_close();
		}	

	return($self);	
	}




1;