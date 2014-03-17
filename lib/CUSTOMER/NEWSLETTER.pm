package CUSTOMER::NEWSLETTER;

use IO::String;
use Mail::DKIM::Signer;
use Crypt::OpenSSL::RSA;
use Mail::DKIM::PrivateKey;
use Data::GUID;

use lib "/backend/lib";
use strict;

use MIME::Entity;
require ZOOVY;
require DBINFO;
require ZWEBSITE;
require ZTOOLKIT;
use Data::Dumper;


##
## removes characters that are non-email safe, including html.
##
sub htmlStrip {
	my ($body) = @_;
	$body =~ s/&nbsp;/ /gs;
	$body =~ s/<a.*?href=\"(.*?)\">(.*?)<\/a>/$2 $1/gs;	# convert links!
	$body =~ s/\<style.*?\<\/style\>//igs;
	$body =~ s/\<script.*?\<\/script\>//igs;
	$body =~ s/\<br\>/\n\r/gs;
	$body =~ s/\<li\>/\[\*\] /gs;
	$body =~ s/<\/tr>/\n\r/igs;
	$body =~ s/<\/td>/\t/igs;
	$body =~ s/\<.*?\>//gs;
	$body =~ s/[\t]+//g; 

	$body =~ s/[\r]+//gs;	# remove lf's 
	$body =~ s/\n[\n]+/\r/gs;	# remove 2+ \n's with a \r

	my $new = '';
	foreach my $line (split(/[\n]+/,$body)) {
		$line =~ s/[ ]+/ /gs;	# strip unnecessary whitespace
		$line =~ s/^[ ]+//g; 	# strip leading whitespace
		$line =~ s/[ ]+$//g;	# strip trailing whitespace
		if ($line ne '') { 
			$new .= $line."\n";
			}
		$line =~ s/[\r]+/\n/gs;
		}
	$body = $new;
		# $body =~ s/[\n\r]+/\n\r/gs;
	return($body);
}


###############################################################################
## AUTOEMAIL::interpolate
## parameters: the message and subject you want to send, 
##					plus a reference to a hash of variables to be interoplated
##	returns: a interpolated messages
##
sub interpolate {
	my ($textref, $hashref) = @_;

	my ($key,$val) = ('','');  
	foreach $key (keys %{$hashref})
		{
		$val = $hashref->{$key};
		if (not defined $val) { $val = ''; }
		${$textref} =~ s/$key/$val/gis;
		}

	return($textref);
}



##
## Parameters: $USERNAME (just in case we need it)
##					$RECIPIENT (destination email address)
##					$MSGREF is a reference to a message hash (probably from load_message or safefetch_message)
##					$SUBREF is a set of data, either populated by the caller or by build_defaults_for_test
##	OPTIONS:
##
##		2 - message is implicitly HTML -- default OFF
##		4 - don't validate source email address
##		8 - don't cobrand message.
##		16 - don't do aol checks.
##		32 - add newsletter header
##
##		result:
##			result, \@warnings
##			result = 1 (sent), 0 (sent w/warnings), -1 (not sent due to errors)
##
sub sendmail {
	my ($USERNAME, $PROFILE, $RECIPIENT, $MSGREF, $SUBREF, $CREF) = @_;

	my $result = 0;
	my @WARNINGS = ();

	if ($MSGREF =~ /^[\s]+$/) { $result = -1; push @WARNINGS, "Message is blank or contains nothing but whitespace"; }
	elsif ($RECIPIENT eq '') { $result = -1; push @WARNINGS, "Recipient is not set"; }
	elsif (not &ZTOOLKIT::validate_email($RECIPIENT)) { 
		$result = -1; 
		push @WARNINGS, "Recipient email [$RECIPIENT] does not appear to be valid."; 
		}

	my $COMPANY = $MSGREF->{'zoovy:company'};
	if ($COMPANY eq '') { $result = -1; push @WARNINGS, "Company name was not set or found."; }
	my $REPLYTO = $MSGREF->{'zoovy:replyto'};
	if ($REPLYTO eq '') { $result = -1; push @WARNINGS, "Reply-to address could not be resolved."; }
	
	$SUBREF->{'%USERNAME%'} = $USERNAME;

	my $body = $MSGREF->{'zoovy:body'};
	my $title = $MSGREF->{'zoovy:title'};
	$title =~ s/[\n\r]+//gs;
	if ($title eq '') { push @WARNINGS, "Message has a blank title"; }
	
	&interpolate(\$body,$SUBREF);	
	&interpolate(\$title,$SUBREF);	

	my $FROM = $MSGREF->{'zoovy:from'};
	## multiple addresses can be specified email1@isp1.com,email2@isp2.com

	#if (index($FROM,',')>=10) { $FROM = substr($FROM,0,index($FROM,',')); }
	#if ($FROM =~ /<(.*?\@.*?)>/) { $FROM = $1; }	# Noah Webster <noah@dictionary.com>
	#$FROM =~ s/[^A-Za-z0-9\.@\-\_]//gs;
	
	if ($result == -1) { 
		}
	elsif ($FROM eq '') { 
		$result = -1; push @WARNINGS,"From address is blank"; 
		}
	elsif (not &ZTOOLKIT::validate_email($FROM)) { 
		$result = -1; push @WARNINGS, "From email address [$FROM] does not appear to be valid."; 
		}

	my $ERRORSTO = $MSGREF->{'zoovy:bounce'};		# where do we send errors to!
	if ($ERRORSTO eq '') { $ERRORSTO = $FROM; }
	

	my $html = '';
	if ($result == -1) {
		## we already encountered a fatal error
		}
	else {
		## this is an HTML message, we should create a plaintext version
		$html = $body;
		$body = &CUSTOMER::NEWSLETTER::htmlStrip($html);
		# $html =~ s/\>\</\>\n\</gs;
		}
		
		
#        $RECIPIENT = 'brian@zoovy.com';
#        $RECIPIENT = 'zoovyliz@yahoo.com';
#        $RECIPIENT = 'liz.marrone@gmail.com';

#	$FROM = 'brian@zoovy.com'; $ERRORSTO = $FROM; $REPLYTO = $FROM;
#	$RECIPIENT = 'dkim-test@altn.com';

	## add the body and /html tags back in!
	if ($result == 0) {
		if ($html =~ /<\/body>/i) { $html =~ s/<\/body>//ig; $html .= "</body>"; }
		if ($html =~ /<\/html>/i) { $html =~ s/<\/html>//ig; $html .= "</html>"; }

		my $TYPE = 'multipart/alternative';
		my $IS_MSN = 0;
		if ($RECIPIENT =~ /\@msn\.com/) { $IS_MSN = 1; $TYPE = 'multipart/mixed'; }


		# Build the message body.
		my $altmsg = MIME::Entity->build(
			Type=>'multipart/alternative',
			'X-Mailer'=>"Zoovy-Automail/2.0 [$USERNAME]",
			'Errors-To'=>$ERRORSTO,
			'Reply-To'=>$REPLYTO,
			'Return-Path'=>$ERRORSTO,
			);

		## @#$%^& stupid MSN lusers can't receive mixed/alternative format
		# $body = 'howdy liz';
		
		if (not $IS_MSN) { 
			$altmsg->attach( Type => 'text/plain',Disposition => 'inline', Data => $body, ); 
			}

		$altmsg->attach(
			Type => 'text/html',
			Disposition => 'inline',
			Data => $html, );
	
	
		my @HEADERS = ();
		push @HEADERS, "Sender: <$FROM>";
		if ($MSGREF->{'zoovy:fromvalid'}) {
			push @HEADERS, "From: $COMPANY <$MSGREF->{'zoovy:from'}>";
			}
		else {
			push @HEADERS, "From: $COMPANY <$FROM>"; 
			}
		# Return-Path: <v-cdammaf_fgfpelnc_ighfmel_ighfmel_a-1@bounce.t.plasticjungle.com>
		# push @HEADERS, "List-Unsubscribe: <mailto:v-cdammaf_fgfpelnc_ighfmel_ighfmel_a-1@bounce.t.plasticjungle.com?subject=Unsubscribe>";
		# push @HEADERS, "List-Unsubscribe, <mailto:list-request@host.com?subject=unsubscribe>, <http://www.host.com/list.cgi?cmd=unsub&lst=list>";
		
		push @HEADERS, "List-Unsubscribe: <mailto:$FROM?subject=Unsubscribe>";
		push @HEADERS, "To: $RECIPIENT"; 
#		$MSGREF->{'zoovy:title'} =~ s/\n//g;
		push @HEADERS, "Subject: $title";
                # print Dumper($CREF);

		foreach (split(/[\n]/,$altmsg->header_as_string())) {
			s/[\r]+$//;
			push @HEADERS, "$_";
			}

		## OMFG this is an important line:
		push @HEADERS, "";  ## do not remove, needed to separate headers from body! or DKIM signing runs amuck!


		foreach (split(/[\n]/,$altmsg->body_as_string())) {
			s/[\r]+$//;
			push @HEADERS, "$_";
			}

		#push @HEADERS, "";
		#push @HEADERS, "Hello Lizzzzz!...";

		my $sigtxt = '';
		my @LINES = ();
		if ((defined $CREF) && (ref($CREF->{'*D'}) eq 'DOMAIN') && ($CREF->{'*D'}->has_dkim())) {

			## NOTE: DOMAIN KEYS IS OLD - DKIM IS NEW ** THEY ARE NOT THE SAME THING **
			## okay we're going to dkim this message.
			my $pk = $CREF->{'*PK'};
			if (not defined $pk) {
				my $rsa = Crypt::OpenSSL::RSA->new_private_key($CREF->{'*D'}->dkim_privkey());
				$pk = Mail::DKIM::PrivateKey->load(Cork=>$rsa);
				$CREF->{'*PK'} = $pk;
				}

			my $dkim = Mail::DKIM::Signer->new(
				Algorithm => "rsa-sha1",
				Method => "simple", 
				# Method => "relaxed",
				# Method => "nofws",
				# Headers => "From:To:Subject",
				Domain => "newsletter.".$CREF->{'*D'}->domainname(),
				Selector => "s1",
                                Key=>$pk,
                                # KeyFile => "private.key",
                                );


			foreach my $h (@HEADERS) {
				$dkim->PRINT("$h\015\012");
				}
			#foreach (split(/[\n]+/,${$io->string_ref()})) {
			#	s/[\r]+$//;
			#	$dkim->PRINT("$_");
			#	push @LINES, "$_\015\012";
			#	}
                        # $dkim->PRINT(${$io->string_ref()});
			$dkim->CLOSE();

#                        print Dumper($dkim->headers()); die();
			my $signature = $dkim->signature();
#			$signature->headerlist("Sender:From:To:Subject");
#			$signature->headerlist("to:from:subject");
#			print STDERR Dumper($signature,\@HEADERS);
#                       die(Dumper($dkim->message_sender(),$dkim->message_originator(),$dkim->signature()));
                      
			unshift @HEADERS, $signature->as_string();
#			unshift @LINES, $signature->as_string()."\015\012";
			}

#		push @LINES, $sigtxt;
#		push @HEADERS, "";
#		push @HEADERS, "Hello Liz";
#		foreach (split(/[\n]/,$altmsg->body_as_string())) {
#			s/[\r]$//;
#			push @HEADERS, "$_";
#			}

#		print STDERR Dumper(\@HEADERS);

#		if ((defined $MSGREF->{'zoovy:cc'}) && ($MSGREF->{'zoovy:cc'} ne '')) {
#			print MH "Cc: ".$MSGREF->{'zoovy:cc'}."\n";
#			}
#		elsif ((defined $MSGREF->{'zoovy:carbon'}) && ($MSGREF->{'zoovy:carbon'} ne '')) { 
#			print MH "Cc: ".$MSGREF->{'zoovy:from'}."\n"; 
#			}
#		if (defined $MSGREF->{'zoovy:bcc'}) {
#			print MH "Bcc: ".$MSGREF->{'zoovy:bcc'}."\n";
#			}

		#	print MH "Bcc: adam\@zoovy.com\n";
	
                
                my $CMD = "/usr/sbin/sendmail";
                if (&ZOOVY::host_operating_system() eq 'SOLARIS') {
                        $CMD = "/opt/csw/sbin/sendmail";
                        }
                
		open MH, "|$CMD -t -f $FROM"; 
#		print MH $sigtxt;
		foreach my $h (@HEADERS) {
			print MH "$h\015\012";
			# join('',@HEADERs); # ${$io->string_ref()};
			}
		# foreach my $h (@HEADERS) { print MH $h; }
		close(MH);

#		open F, ">/tmp/foo";
#		print F $sigtxt;
#		foreach my $h (@HEADERS) {
#			print F "$h\015\012"; # join('',@); # ${$io->string_ref()};
#			}
#		close F;
		
		if (scalar(@WARNINGS)==0) { $result = 1; }
		}

	return($result,\@WARNINGS);
}





##
## returns: 
## 	array, each position (0..15) is the newsletter #
##		which corresponds to it's bit position in the customer record.
##		the value is a hashref which consists of the corresponding row from the database.
##		$key->{'SUBSCRIBE'} pulled from LIKES_SPAM value in CUSTOMER_TB
##			1 subscribed 
##			0 not subscribed
## 		-1 if not available
##
## sample dump of @RESULTS
## $VAR1 = undef;
## $VAR2 = {
##          'ID' => 1,
##          'NAME' => 'one',
##          'USERNAME' => 'patti',
##          'SUBSCRIBE' => 1,
##          'EXEC_SUMMARY' => '',
##          'MID' => 2,
##          'MODE' => 2,
##        };
## $VAR3 = {
##          'ID' => 2,
##          'NAME' => 'two',
##          'USERNAME' => 'patti',
##          'SUBSCRIBE' => '0',
##          'EXEC_SUMMARY' => 'test',
##          'MID' => 2,
##          'MODE' => 2,
##			 };
##
sub available_newsletters {
	my ($USERNAME, $PRT, $EMAIL) = @_;
   my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my (@NAME) = ();

   my $dbh = &DBINFO::db_user_connect($USERNAME);
   my $TB = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);

   my $pstmt = "select NEWSLETTER from $TB where EMAIL=".$dbh->quote($EMAIL)." and MID=$MID /* $USERNAME */ and PRT=".int($PRT);
   my $sth = $dbh->prepare($pstmt);
   $sth->execute();
	my ($LS) = $sth->fetchrow_array(); 
	$sth->finish();
   &DBINFO::db_user_close();

	my (@RESULTS) = CUSTOMER::NEWSLETTER::fetch_newsletter_detail($USERNAME,$PRT);
	foreach my $key (@RESULTS) {
      next if (not defined $key);

		if ($key->{'NAME'} eq '') {
			if ($key->{'ID'} == 1) { $key->{'NAME'} = 'Store Newsletter'; }
			else { $key->{'NAME'} = 'Newsletter #'.$key->{'ID'}; }
			}

		## if MODE is Exclusive/private
		## otherwise check against LIKES_SPAM
		if ($LS & (1 << ($key->{'ID'}-1) ) ){ $key->{'SUBSCRIBE'} = 1; }
		## NOTE: This line is *broke* it ignore LIKESPAM (not sure why it was even here) BH 12/18/07
		## elsif ($key->{'MODE'} == 0){ $key->{'SUBSCRIBE'} = -1; }
		else{ $key->{'SUBSCRIBE'} = 0; }
		}

	return(\@RESULTS);
	}


##
##
## takes the HTML output from a newsletter, and the campaign id.
##	
## and does the following:
##		if unique id is zero, then this also adds the "Approve" link.
##		adds the cpg= tags
##		adds the unsubscribe
##		adds the webbug to track how many times the email was opened.
##
sub rewrite_links {
	my ($html, $uri) = @_;

	## HTML section of email
	## add cpg to all links
	
#	my $SDOMAIN = quotemeta($CREF->{'SENDER'});
#	$SDOMAIN = ".*?$SDOMAIN.*?";
	my $SDOMAIN = "\\?";

	## catch all links with params (need to add &)
	$html =~ s/href\s*=\s*"([^"\s>]+)($SDOMAIN)([^"\s>]+)"/href="$1$2$3\&$uri"/gis;
	## and those with anchors
	$html =~ s/href\s*=\s*\"([^\"$SDOMAIN\s>]+)(\#.*)\"/href="$1\?$uri$2"/gis;
	## and those without (need to add ?)
	$html =~ s/href\s*=\s*\"([^\"$SDOMAIN\s>]+)\"/href="$1\?$uri"/gis;

	return($html);
	}



##
## NOTE: CEID is the unique identifier for this particular email.
##
sub build_footer {
	my ($CREF,$nsref) = @_;

	if (not defined $nsref) {
		die("NSREF is required");
		}
	
	$CREF->{'COMPANY'} = $nsref->{'zoovy:company_name'};
	$CREF->{'COMPANY'} =~ s/[^\w]+/ /g;		## remove bad characters that will confuse mailers.
	$CREF->{'REPLY-TO'} = $nsref->{'zoovy:support_email'};
	if ($CREF->{'REPLY-TO'} eq '') { $CREF->{'REPLY-TO'} = $nsref->{'zoovy:email'}; }
	## we should some fancy shmancy domain stuff here.

   if (not defined $nsref->{'zoovy:address1'}) {
      $nsref->{'zoovy:address1'} = $nsref->{'zoovy:address'};
      }
	my $addr = $nsref->{'zoovy:address1'}."<br>\n";
	
	if ($nsref->{'zoovy:address2'} ne '') { $addr .= $nsref->{'zoovy:address2'}."<br>\n"; }
	$addr .= $nsref->{'zoovy:city'}.', '.$nsref->{'zoovy:state'}.' '.$nsref->{'zoovy:zip'}."<br>\n";

	my $USERNAME = $CREF->{'USERNAME'};

my  $html = qq~
<center>
<br>
<table cellpadding="4" cellspacing="0" style="border:1px solid #CCCCCC; background-color:#FFFFFF; font-family:Arial, Helvetica, sans-serif; font-size: 8pt;">
<tr>
	<td valign="top" rowspan="2" style="border-right:1px solid #cccccc;">$nsref->{'zoovy:company_name'}<br>$nsref->{'zoovy:support_phone'}<br>
	$addr</td>
	<td colspan="2">
	This email was sent to %EMAIL% on behalf of $nsref->{'zoovy:company_name'}.<br>
	To stop future mailings please <a style="font-family:Arial, Helvetica, sans-serif; font-size: 8pt;" href="http://www.$CREF->{'SENDER'}/customer/newsletter/unsubscribe?username=%EMAIL%&meta=NEWSLETTER&cpg=%CAMPAIGN%&cpn=%CPNID%">Unsubscribe</a>.<br>
	Your privacy is important, please <a style="font-family:Arial, Helvetica, sans-serif; font-size: 8pt;" href="http://www.$CREF->{'SENDER'}/privacy.cgis">read our privacy policy</a>.
	</td>
</tr>
<tr style="background-color:#f0f0f0;">
	<td valign="top">This email was sent by <a style="font-family:Arial, Helvetica, sans-serif; font-size: 8pt;" href="http://www.zoovy.com/track.cgi?M=$USERNAME">Zoovy.com</a> on behalf of $nsref->{'zoovy:company_name'}.</td>
	<td valign="top"><a style="font-family:Arial, Helvetica, sans-serif; font-size: 8pt;" href="http://www.zoovy.com/track.cgi?M=$USERNAME">
	<img src="https://static.zoovy.com/img/proshop/W90-H30-BF0F0F0/zoovy/logos/zoovy.gif" alt="" border="0">
	</a>
	</td>
</tr></table>
<img height="1" width="1" src="http://webapi.zoovy.com/webapi/webbug.cgi/CPG=%CAMPAIGN%/CPN=%CPNID%/$USERNAME.gif">
</center>
	~;

	return($html);
	}


## 
## pass:
##		campaign ref (from fetch_campaign)
##		email address to send to.
##		UniqueID (0 if this is a test email) -- otherwise the unique message id.
##		customer full name	
##
## return:
##		result
##			 1 - success
##			 0 - success w/warnings
##			-1 - unsuccessful w/errors
## 	warnings/errors specific to send
##
sub send_newsletter {
	my ($CREF,$EMAIL,$CID,$UNIQUEID,$FULLNAME) = @_;

	my $SUBJECT = $CREF->{'SUBJECT'};
	my $PROFILE = $CREF->{'PROFILE'};
	if (not defined $PROFILE) { $PROFILE = 'DEFAULT'; }
	my $TS = time();
	my $MID = $CREF->{'MID'};
	my $USERNAME = $CREF->{'USERNAME'};
	my $PG = "\@CAMPAIGN:".$CREF->{'ID'};

	## this is the code that should do the individual "From" address .. for now 
	## it's hardcoded as newsletter@domain.com
	my $SENDER = '';
	my $BOUNCE = '';
	if (($CID>0) || ($UNIQUEID>0)) {
		my $b36CID = &ZTOOLKIT::base36($CID);
		my $b36CPG = &ZTOOLKIT::base36($CREF->{'ID'});
		my $b36CPNID = &ZTOOLKIT::base36($UNIQUEID);
		$SENDER = "vip-$b36CID\@newsletter.$CREF->{'SENDER'}";
		$BOUNCE = "$b36CID+$b36CPG+$b36CPNID\@newsletter.$CREF->{'SENDER'}";
		}
	else {
		$SENDER = "campaign+$CREF->{'ID'}\@newsletter.$CREF->{'SENDER'}";
		$BOUNCE = $SENDER;
		}

	## set up values for email
	my $msgref = {};
	$msgref->{'zoovy:from'} = $SENDER;
	$msgref->{'zoovy:bounce'} = $BOUNCE;
	$msgref->{'zoovy:title'} = $SUBJECT;
	$msgref->{'zoovy:body'} = $CREF->{'_BODY'};

	$msgref->{'zoovy:company'} = $CREF->{'COMPANY'};
	$msgref->{'zoovy:replyto'} = $CREF->{'REPLY-TO'};

	## in the future: these are the ONLY variables which will be unique per message.	
	my $subref = {};
	$subref->{'%EMAIL%'} = $EMAIL;
   $subref->{'%SUBJECT%'} = $SUBJECT;
   $subref->{'%CAMPAIGN%'} = $PG;
   $subref->{'%CAMPAIGNID%'} = $CREF->{'ID'};
   $subref->{'%USERNAME%'} = $USERNAME;
	$subref->{'%CPNID%'} = $UNIQUEID;
	$subref->{'%CPG_CODE%'} = $CREF->{'CPG_CODE'};
	$subref->{'%CPG_NAME%'} = $CREF->{'NAME'};
	$subref->{'%TRACKING%'} = sprintf("meta=NEWSLETTER&CPN=%d&CPG=%d",$UNIQUEID,$CREF->{'ID'});

	$subref->{'%FULLNAME%'} = $FULLNAME;
	$subref->{'%FIRSTNAME%'} = substr($FULLNAME,0,index($FULLNAME,' '));
	# $subref->{'%VARS%'} = 

	## attempt to send mail	
	my ($result, $warnings) = &CUSTOMER::NEWSLETTER::sendmail(
		$USERNAME,$PROFILE,$EMAIL,$msgref,$subref,$CREF
		);

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	if (($result>0) && ($UNIQUEID>0)) {
		## Remember: campaign 0 is a TEST EMAIL
		my $pstmt = "update CAMPAIGNS set STAT_SENT=STAT_SENT+1 where MID=$MID /* $USERNAME */ and ID=".int($CREF->{'ID'});
		$udbh->do($pstmt);
		}
	## UNIQUEID=0 is test email sent for approval
	## UNIQUEID=-1 is email sent for testing bad/good email addresses for actual campaign send
	##		so for this case, don't update CAMPAIGNS
	elsif(($result>0) && ($UNIQUEID==0)) {
	## update DB with TESTED timestamp
		## get TIMESTAMP for this send, update DB
		my $pstmt = "update CAMPAIGNS ".
						"set TESTED=$TS ".
						"where MID=$MID /* $USERNAME */ ".
						"and ID=".int($CREF->{'ID'});
		$udbh->do($pstmt);
		}
	&DBINFO::db_user_close();
	print STDERR "TESTED updated: $TS\n";

	return($result,$warnings);
	}

## fetches most recent FINISHED newsletter
## http://proshop.zoovy.com/newsletter/3523/0 -- 
## http://proshop.zoovy.com/newsletter/recent
##
sub fetch_recent {
	my ($USERNAME) = @_;

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select id from CAMPAIGNS ".
					"where status = 'FINISHED' ".
					"and merchant = ".$dbh->quote($USERNAME).
					" order by id desc limit 1";

	my $sth = $dbh->prepare($pstmt);	
	$sth->execute();
	my ($id) = $sth->fetchrow();
	$sth->finish();
	&DBINFO::db_user_close();

	return($id);
	}




##
## So .. this returns an array, each position (0..15) is the newsletter #
##		which corresponds to it's bit position in the customer record.
##		the value is a hashref which consists of the corresponding row from the database.
##	NOTE: newsletters which are undefined will be returned as undefined (since perl pads out arrays)
##
sub fetch_newsletter_detail {
	my ($USERNAME, $PRT, $mode) = @_;

	$PRT = int($PRT);

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my %LIST = ();

	my @RESULTS = ();
	foreach (0..15) { $RESULTS[$_] = { ID=>$_, NAME=>"", MODE=>-1 }; }
	my $pstmt = "select * from NEWSLETTERS where MID=$MID /* $USERNAME */ and PRT=$PRT and ID < 16";

	## only show specific mode lists
	## default = 1
	## targeted = 2
	## exclusive = 0
	if ($mode ne '') { $pstmt .= " and mode = ".$udbh->quote($mode); }
	print STDERR $pstmt."\n";
	
	print STDERR "[CUSTOMER::NEWSLETTER::fetch_newsletter_detail] $pstmt\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		$RESULTS[$hashref->{'ID'}] = $hashref;
		}
	$sth->finish();
	&DBINFO::db_user_close();

	if ($RESULTS[1]->{'MODE'} == -1) {
		## Hmm.. this will always initialize the default store newsletter to 1
		$RESULTS[1]->{'ID'} = 1;
		$RESULTS[1]->{'MODE'} = 1;  ## mode: 1 is default
		$RESULTS[1]->{'NAME'} = "Store Newsletter";
		} 

	return(@RESULTS);
	}


##			NOTE: if you pass a newsletter of zero, you'll get back a hashref 
##					keyed by ID e.g. 1..16 with the count as the value.
sub fetch_newsletter_sub_counts {
	my ($USERNAME,$PRT) = @_;

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my %result = ();
	if ($MID>0) {
		require CUSTOMER;
		my $dbh = &DBINFO::db_user_connect($USERNAME);
		my $TB = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);
		my $pstmt = "select NEWSLETTER from $TB where NEWSLETTER>0 and MID=$MID /* $USERNAME */ and PRT=$PRT";
		my $sth = $dbh->prepare($pstmt);
		$sth->execute();
		while ( my ($spam) = $sth->fetchrow() ) {
			my $count = 0;
			while ($spam > 0) {
				$count++;
				$result{$count} += ($spam&1);
				$spam = $spam >> 1;
				}
			}
		$sth->finish();
		&DBINFO::db_user_close();
		}
	
	# foreach my $e (1..16) { $result{$e} = $e; }
	return(\%result);
	}

##
## input: MID and newsletter ID
##			NOTE: id is the newsletter id, NOT the campaign.
##				this also assumes the newsletters start at #1 not #0
## returns: number of subscribers for given newsletter (subscription list)
##
sub fetch_newsletter_sub_count{
	my ($USERNAME, $ID) = @_;
	my $COUNT = -1;

	my $BIT = 1 << ($ID-1);
	
	## fetch subscriber count, not sure if DB connection needed

	return($COUNT);
	}	




## perl -e 'use Data::Dumper; use lib "/backend/lib"; use CUSTOMER::NEWSLETTER; my ($CREF) = &CUSTOMER::NEWSLETTER::fetch_campaign("brian",12314); print Dumper(CUSTOMER::NEWSLETTER::generate("brian",$CREF));'

##
## generate/parbake is phase1, it renders the newsletter content and get's it ready for interplation phase
##
#sub generate {
#	my ($USERNAME,$CREF) = @_;
#
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#
#	my $out = '';
#	my $DOMAIN = undef;
#	my $DNSINFO = undef;
#
#	require SITE;
#
#	my $SITE = undef;
#	if (not defined $CREF) {
#		$out = 'ERROR: NO CREF PASSED IN';
#		}
#	else {
#		die();
#		#$CREF->{'*SITE'} = $SITE = SITE->init_from_newsletter($USERNAME,$CREF);	
#		#if ($SITE->_iz_broked()) { $out = $SITE->_iz_broked(); }
#		}
#
#	require TOXML;
#	if ($out ne '') {
#		}
#	else {
#		my $t = TOXML->new('LAYOUT',$SITE->layout(),USERNAME=>$SITE->username(),MID=>$SITE->mid());
#		if (not defined $t) {
#			$out = 'Invalid TOXML file';
#			}
#		else {
#			($out) = $t->render('*SITE'=>$SITE);
#			}
#		}
#
#	if (1) {
#	   my $guid = Data::GUID->new;
#
#      require SITE::EMAILS;
#		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
#		$CREF->{'OUTPUT_HTML'} = $out;
#		$CREF->{'OUTPUT_TXT'} = &SITE::EMAILS::htmlStrip($out);
#		$CREF->{'PREVIEW_GUID'} = $guid->as_string();
#
#		my ($pstmt) = &DBINFO::insert($udbh,'CAMPAIGNS',{
#			MID=>$MID,ID=>$CREF->{'ID'},
#			OUTPUT_HTML=>$CREF->{'OUTPUT_HTML'},
#			OUTPUT_TXT=>$CREF->{'OUTPUT_TXT'},
#			PREVIEW_GUID=>$CREF->{'PREVIEW_GUID'},
#			},key=>['MID','ID'],sql=>1,update=>2);
#		print STDERR "$pstmt\n";
#		$udbh->do($pstmt);
#
#		&DBINFO::db_user_close();
#		}
#
#	return($CREF);	
#	}
#


1;
