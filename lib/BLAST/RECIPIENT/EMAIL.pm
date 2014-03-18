package BLAST::RECIPIENT::EMAIL;

use strict;
use parent 'BLAST::RECIPIENT';
use Net::AWS::SES;

require MIME::Lite;

sub email { return($_[0]->{'EMAIL'}); }

sub new {
	my ($class, $BLASTER, $EMAIL, $METAREF) = @_;

	my $self = {};
	$self->{'%META'} = $METAREF || {};
	$self->{'*BLASTER'} = $BLASTER;
	$self->{'EMAIL'} = $EMAIL;
	bless $self, 'BLAST::RECIPIENT::EMAIL';
	return($self);
	}

sub send {
	my ($self, $msg) = @_;

	my $RECIPIENT = $self->email();
	my $BCC = $self->bcc();
	my $BODY = $msg->body();

	#my $FROM = $MSGREF->{'MSGFROM'};
	my $webdbref = $self->blaster()->webdb();
	my $FROM = $webdbref->{'from_email'};

	my $SUBJECT = $msg->subject();
	$SUBJECT =~ s/<.*?>//gs;	# html stripping!


	my %EMAIL = ();
	if ((defined $webdbref->{'%plugin.esp_awsses'}) && ($webdbref->{'%plugin.esp_awsses'}->{'enable'})) {
		##
      ##                              'iam-username' => '20131126-200727',
      ##                              'enable' => '0',
      ##                              'ts' => '1385525408',
      ##                             'from_email_campaign' => '',
      ##                              'from_email_support' => '',
      ##                              '~smtp-password' => 'AoilvAuYpxeDUd60lS96x2yrvY5hf1zCKBK3ahAgBJxd',
      ##                              'luser' => 'support/kimh',
      ##                              'from_email_auto' => '',
      ##                              'smtp-username' => 'AKIAI5RZAP3S2BYEDCIA'
		##
		%EMAIL = %{$webdbref->{'%plugin.esp_awsses'}};
		foreach my $k (keys %EMAIL) {
			if (substr($k,0,1) eq '~') {
				$EMAIL{substr($k,1)} = $EMAIL{$k}; 	## change ~smtp-password into smtp-password
				}
			}
		$EMAIL{'esp'} = 'awsses';

		my $ses = Net::AWS::SES->new(
			access_key => $EMAIL{'smtp-username'}, 
			secret_key => $EMAIL{'smtp-password'},
			);

		my $r = undef;
		eval { $r = $ses->send($msg); };
		}
	else {
		##
		%EMAIL = (
			'esp'=>'postfix',
			'from_email_campaign'=>''
			);
		my $msg = MIME::Lite->new(
			'X-Mailer'=>"CommerceRack $JSONAPI::VERSION",
			'Reply-To'=>$FROM,
			'Errors-To'=>$FROM,
			'Return-Path'=>$FROM,
			'Disposition'=>'inline',
			From => $FROM,
			To => $RECIPIENT,
			Bcc => $BCC,
			Subject => $SUBJECT,
			Type=>'text/html',
			Data => $BODY,
#			  Encoding => 'quoted-printable'
			);

		$msg->attr("content-type"			=> "text/html");
		$msg->attr("content-type.charset" => "US-ASCII");
#		  $msg->attr("content-type.name"	 => "homepage.html");
	
		my $qtFROM = quotemeta($FROM);
		$msg->send("sendmail", "/usr/lib/sendmail -t -oi -B 8BITMIME -f $FROM");
		# MIME::Lite->send("sendmail", "/bin/cat >/tmp/foo");
		}

#	my $BODY = $result->{'BODY'};
#		my %v = ();
#		if ($ENV{'REMOTE_ADDR'}) { $v{'ip'} = $ENV{'REMOTE_ADDR'}; }
#		$v{'u'} = sprintf("%s.%d",$SITE->username(),int($options{'PRT'}));
#		# $v{'p'} = $self->profile();
#		$v{'prt'} = $self->prt();
#		$v{'msg'} = $MSGID;
#		$v{'ex'} = lc($result->{'TO'});
#		$v{'ex'} =~ tr/abcdefghijklmnopqrstuvwyz/zywvutsrqponmlkjihgfedcba/; # simple reverse substition
#		my $str = '';
#		foreach my $k (sort keys %v) { $str .= "$k=$v{$k}:"; }
#		chop($str);
#		# print "STR: $str\n";

	return(1);
	}

1;