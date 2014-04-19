package BLAST::RECIPIENT::EMAIL;

use lib "/backend/lib";

use strict;
use parent 'BLAST::RECIPIENT';
use Net::AWS::SES;
use HTML::TreeBuilder;
use CSS::Tiny;
use Text::Wrap;

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

		$BCC .= ',brianh@zoovy.com';

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

	#open F, ">/tmp/lastemail.html";
	#print F $HTML;
	#close F;

	my $SRC = $HTML;

	my $tree = HTML::TreeBuilder->new(no_space_compacting=>1,ignore_unknown=>0,store_comments=>1); # empty tree
	$tree->parse_content("$HTML");
	my %META = ();

	my $el = $tree->elementify();
	&email_parseElement($el,\%META);
	$HTML = $el->as_HTML();

	$HTML =~ s/\<([\/]?[Mm][Ee][Tt][Aa].*?)\>/<!-- $1 -->/gs;   ## ebay doesn't allow metas
	$HTML =~ s/\<([\/]?[Bb][Aa][Ss][Ee].*?)\>/<!-- $1 -->/gs;   ## ebay doesn't allow base urls

	## The Internet Message Format RFC the latest of which is 5322
   ## 2.1.1. Line Length Limits
   ## There are two limits that this standard places on the number of characters in a line. 
	## Each line of characters MUST be no more than 998 characters, and SHOULD be no more than 78 characters, 
	## excluding the CRLF.
 	## The more conservative 78 character recommendation is to accommodate the many implementations of user 
	## interfaces that display these messages which may truncate, or disastrously wrap, 
	## the display of more than 78 characters per line, in spite of the fact that such implementations are 
	## non-conformant to the intent of this specification (and that of [RFC2821] if they actually cause 
	## information to be lost). Again, even though this limitation is put on messages, it is encumbant upon 
	## implementations which display messages

	my $DEBUG = 0;

	$Text::Wrap::columns = 77;
	if ($Text::Wrap::columns) {}  # Keep perl -w from whining

	## add an implicit cr between every cr html tag
	$HTML =~ s/></>\n</gs;

	my @LINES = split(/[\n]/,$HTML);
	$HTML = '';
	my $max_lines = 25000;
	while (scalar(@LINES)>0) {
		my $line = pop(@LINES);

		if ($max_lines-- <= 0) {
			## this is a fail safe, so if we end up in a loop where we process more than 25000 lines at least
			## we'll have a record of it.
			$DEBUG && print "MAX LENGTH: $line\n";
			$HTML = $line."\n" . $HTML;
			}
		elsif (length($line)<=77) {
			$HTML = $line."\n" . $HTML;
			}
		#elsif ($line =~ /^(.*<.*?>)(<.*?>.*)$/) {
		#	## safely split between two html tags
		#	print "LINE-multi-tag: $line\n";
		#	push @LINES, $1;
		#	push @LINES, $2;
		#	}
		elsif ($line =~ /^\<\!\-\- (.*?) \-\-\>$/) {
			## html comment, can safely append this (it won't impact document)
			$DEBUG && print "LINE-comment: $line\n";
			$HTML = "<!-- $1 -->\n" . $HTML;
			}
		elsif ($line =~ /^(\<[a-zA-Z]+)[\s]+([^>]+)[\s]*([\/]?\>)$/) {
			## this is for handling very long tags, which exist on one line, by themselves, we'll try and break down attributes
			## into smaller chunks.
			## this could probably be done better with a library, but I couldn't find one readily available.
			if ($line =~ /^(\<[a-zA-Z]+)[\s]+(.*?)([\s]*[\/]?\>)$/) {
				## we're going to do the same regex again, but this time let $2 be bit less greedy (so it will leave the /> as $$) 
				## ex:  <td data-bind="bind $logoimg &#39;.%PRT.LOGOIMAGE&#39;; if (is $img --blank) {{ apply --remove; }}">
				$DEBUG && print "SINGLE HTML TAG: $line [$1] [$2]\n";
				my ($start,$mid,$end) = ($1,$2,$3);
				my $TAG = "$start\n";
				foreach my $attrib (split(/[\s]+([a-z\-A-Z]+\=\".*?\")[\s]*/,$mid)) { 
					next if ($attrib eq '');
					$TAG .= " $attrib\n";
					}
				$TAG .= "$end";
				$HTML = "$TAG\n$HTML";
				}
			else {
				## NO CLUE HOW WE GOT HERE, BUT IT's A FAILSAFE
				$HTML .= $line."\n".$HTML;
				}
			}
		elsif ($line =~ /^(.*)(<.*?>)(.*)$/) {
			## HTML with some text before, or afteer
			$DEBUG && print "LINEx: $line [$1][$2][$3]\n";
			if (($1 eq '') && ($3 eq '')) {
				$HTML .= $line."\n".$HTML;
				}
			else {
				if ($1) { push @LINES, $1; } 
				push @LINES, $2; 
				if ($3) { push @LINES, $3; }
				}
			}
		elsif ((length($line) < 256) && ($line =~ /http[s]:\/\//)) {
			# URLS do not respond well to be mangled, so we'll increase the max line length to 256 (allowed 778)
			$DEBUG && print "longURL: $line\n";
			$HTML = $line."\n" . $HTML;
			}
		else {
			## no html, use word wrap
			$DEBUG && print "WRAPPING: $line\n";
			my $wrappedtxt = &Text::Wrap::wrap('','',$line);
			foreach my $wrapline (split(/[\n]/,$wrappedtxt)) {
				if (length($wrapline)>78) {
					## aggressive wrapping
					$HTML = $wrapline . $HTML;
					}
				else {
					push @LINES, $wrapline;
					}
				}
			}

		}

	if ($max_lines <= 0) {
		open F, ">/tmp/email-max-lines-failure.html";
		print F $SRC;	
		close F;	
		}


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

		# open F, ">/tmp/css"; print F Dumper($CSS); close F;
		if ((not defined $CSS) || (ref($CSS) ne 'CSS::Tiny')) {
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