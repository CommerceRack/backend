package BLAST::RECIPIENT::EMAIL;

use strict;
use parent 'BLAST::RECIPIENT';
use Net::AWS::SES;
use HTML::TreeBuilder;
use CSS::Tiny;

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

##
##
##
sub send {
	my ($self, $msg) = @_;

	my $RECIPIENT = $self->email();
	my $BCC = $msg->bcc() || $self->bcc();
	my $BODY = $msg->body();

#	open F, ">/tmp/email";
#	print F $BODY;
#	close F;
	
	$BODY = &emailify_html($BODY);

	#my $FROM = $MSGREF->{'MSGFROM'};
	my $webdbref = $self->blaster()->webdb();
	my $FROM =  $webdbref->{'from_email'} || $webdbref->{'paypal_email'};

	my $SUBJECT = $msg->subject();
	$SUBJECT =~ s/<.*?>//gs;	# html stripping!


	open F, ">>/tmp/emails";
	print F Dumper($BODY);
	close F;

#	print STDERR "BODY: $BODY\n";

	my %EMAIL = ();
#	$webdbref->{'%plugin.esp_awsses'} = {};

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

		my %MSG = ();
		$MSG{'From'} = $FROM;
		$MSG{'To'} = $RECIPIENT;
		$MSG{'Subject'} = $SUBJECT;
		$MSG{'Body'} = $BODY;
		$MSG{'ReturnPath'} = $FROM;

		my $r = undef;
		eval { $r = $ses->send(%MSG); };

		use Data::Dumper; 
		print STDERR 'AWS OUTPUT; '.Dumper($r,$webdbref->{'%plugin.esp_awsses'})."\n";

		}
	else {
		##
		%EMAIL = (
			'esp'=>'postfix',
			'from_email_campaign'=>''
			);

		my $msg = MIME::Lite->new(
			'X-Mailer'=>sprintf("CommerceRack %s [%s]",$JSONAPI::VERSION,$msg->msgid()),
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
			);

		$msg->attr("content-type"			=> "text/html");
		$msg->attr("content-type.charset" => "US-ASCII");
	
		my $qtFROM = quotemeta($FROM);
		$msg->send("sendmail", "/usr/lib/sendmail -t -oi -B 8BITMIME -f $FROM");
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


#####

##
## ebay doesn't allow base urls, or meta tags so this rewrites the document.
##
## my $html = File::Slurp::read_file('index.html');
## print ebayify_html($html);
##
sub emailify_html {
	my ($HTML) = @_;

	my $tree = HTML::TreeBuilder->new(no_space_compacting=>1,ignore_unknown=>0,store_comments=>1); # empty tree
	$tree->parse_content("$HTML");
	my %META = ();

	my $el = $tree->elementify();
	&email_parseElement($el,\%META);
	$HTML = $el->as_HTML();

	$HTML =~ s/\<([\/]?[Mm][Ee][Tt][Aa].*?)\>/<!-- $1 -->/gs;   ## ebay doesn't allow metas
	$HTML =~ s/\<([\/]?[Bb][Aa][Ss][Ee].*?)\>/<!-- $1 -->/gs;   ## ebay doesn't allow base urls
	return($HTML);
	}


sub email_parseElement {
	my ($el, $METAREF) = @_;

	if ($el->tag() eq 'base') {
		$METAREF->{'base'} = $el->attr('href');
		}

	if ($el->tag() eq 'a') {
		## <a href="">
		if ($METAREF->{'base'}) {
			$el->attr('href',URI::URL->new($el->attr('href'),$METAREF->{'base'})->abs());
			}
		}
	elsif ($el->tag() eq 'img') {
		## <img src="">
		my $src = $el->attr('src');
 			
		if ($METAREF->{'base'} ne '') {
			$el->attr('src',URI::URL->new($el->attr('src'),$METAREF->{'base'})->abs());			
			}
		elsif (substr($src,0,2) eq '//') { 
			## gmail doesn't appreciate //www.domain.com urls
			$el->attr('src','https:'.$el->attr('src'));
			}
		}
	elsif ($el->tag() eq 'style') {
		my $sheet = $el->as_HTML();
		$sheet =~ s/\<[Ss][Tt][Yy][Ll][Ee].*?\>(.*)\<\/[Ss][Tt][Yy][Ll][Ee]\>/$1/s;
		$sheet =~ s/\<\!\-\-(.*)\-\-\>/$1/s;

		my $CSS = CSS::Tiny->new()->read_string($sheet) || {};
		foreach my $property (keys %{$CSS}) {
			foreach my $k (keys %{$CSS->{$property}}) {
				if ($CSS->{$property}->{$k} =~ /^[Uu][Rr][Ll]\((.*?)\)/) {
					my $url = $1;
					if ($METAREF->{'base'}) {
						my $absurl = URI::URL->new($url,$METAREF->{'base'})->abs();
						$CSS->{$property}->{$k} =~ s/^[Uu][Rr][Ll]\(.*?\)/url($absurl)/;
						}
					}
				}
			}

		open F, ">>/tmp/css";
		print F Dumper($CSS);
		close F;

		if ((not defined $CSS) || (ref($CSS) eq 'CSS::Tiny')) {
			$el->postinsert("<!-- // style is not valid, could not be interpreted by CSS::Tiny // -->");
			}
		else {
			$sheet = $CSS->html();
			my $sheetnode = HTML::Element->new('style','type'=>'text/css');
			$sheetnode->push_content("<!-- \n".$CSS->write_string()."\n -->");
			$el->replace_with($sheetnode);
			}
		}
	
	if (not $METAREF->{'base'}) {
		}
	elsif ($el->attr('style') ne '') {
		## parse the style tag
		# print $el->attr('style')."\n";
		my $sheet = sprintf("style { %s }",$el->attr('style'));
		my $CSS = CSS::Tiny->new()->read_string($sheet);
		foreach my $k (keys %{$CSS->{'style'}}) {
			if ($CSS->{'style'}->{$k} =~ /^[Uu][Rr][Ll]\((.*?)\)/) {
				if ($METAREF->{'base'}) {
					my $url = $1;
					my $absurl = URI::URL->new($url,$METAREF->{'base'})->abs();
					$CSS->{'style'}->{$k} =~ s/^[Uu][Rr][Ll]\(.*?\)/url($absurl)/;
					}
				}
			}
		$sheet = $CSS->write_string();
		$sheet =~ s/\n/ /gs;
		$sheet =~ s/\t/ /gs;
		$sheet =~ s/[\s]+/ /gs;
		$sheet =~ s/^.*?\{(.*)\}/$1/gs;
		$sheet =~ s/^[\s]+//gs;
		$sheet =~ s/[\s]+$//gs;
		$el->attr('style',$sheet);
		}

	foreach my $elx (@{$el->content_array_ref()}) {
		if (ref($elx) eq '') {
			}
		else {
			&email_parseElement($elx,$METAREF);
			}
		}

	}



1;