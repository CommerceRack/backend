package WEBAPI;


use Data::Dumper;

##
## PACKAGE: WEBAPI
##
## purpose:
##		collectively, a wrapper of functions for sync.cgi and legacy.cgi (which are actually the same application)
##		this will be a collection of all new format apis, in one, single, comprehensive location. 
##		note: I expect this module to grow *very* large, thats okay because eventually webapi will have it's own
##			cluster of servers - and the whole thing will be mod_perl, and it'll be great, and i'll be popular,
##			and people will like me, because i'm handsome, and smart, and .. err. 
##		
##

## these two values contain error codes 1024, 1025 (min/max compat level exceeded)
$WEBAPI::MAX_ALLOWED_COMPAT_LEVEL = 222;
$WEBAPI::MIN_ALLOWED_COMPAT_LEVEL = 201;

=pod

[[SECTION]Releases Notes]
<li> 2011/05/04: Added CUSTOMERPROCESS API call.
[[/SUBSECTION]]


[[/SECTION]]

[[SECTION]Compatibility Levels]
Current minimum compatibility level: 200 (released 11/15/10)
[[BREAK]]
[[STAFF]]
** when bumping compatibility level we should also change $WEBAPI::MAX_ALLOWED_COMPAT_LEVEL 
[[/STAFF]]

<li> 221: 8/19/13		modified <PROFILES> response in webdb sync
<li> 220: 11/26/12	new order format (v220)
<li> 210: 9/17/12	 addition of uuid= in stuff
<li> 205: 1/5/12   ADDPRIVATE macro does an overrite, not an append. (backward compatibility release)
<li> 204: 12/29/11 fixes issues with payment processing (not explicitly declared in code, because they're "SAFE"/forward compat)
<li> 203: 10/24/11	has strict encoding rules for options, modifier must be encoded or there will be an error.
<li> 202: 10/24/11	(version 202 and lower adds backward support (via strip) for double quotes in stuff item options modifier=)
<li> 202: 5/6/11	 extends MSGID in emails node from 24 characters from 10
<li> 201: 2/16/11   adds MSGTYPE TICKET in emails node to WEBDBSYNC
<li> 200: 11/15/10  order generation version 5
<li> 117: 4/7/09  changes webdb sync in versioncheck
<li> 116: 5/21/08 re-enables image delete (for 116 and higher)
<li> 116: 4/10/08 note: 115 is was never apparently released due to bugs, skipping to 116 to be safe.
<li> 115: 2/23/08  [note: released to 114] changed format for stids (cheap hack: e.g.  abc/123*xyz:ffff  becomes 12
<li> 114: 12/26/07 new email changes (shuts down sendmail)
<li> 113: skipped for bad luck
<li> 112: 10/27/07 versions below have backward compatibility for company_logo in merchant sync
<li> 111: 10/09/07 convert ZOM and ZWM clients to ZID
<li> 110: 8/21/07 changes to events (ts was time)
<li> 109: 4/19/07 implements zoovy.virtual zoovy.prod_supplier zoovy.prod_supplierid removes supplier from skulist.
<li> 108: 3/13/07 changes xml output of stuff for orders
[[/SECTION]]

=cut

use Digest::MD5;
use Compress::Bzip2 qw();
use Compress::Zlib qw();
use MIME::Base64;

use IO::String;
use XML::SAX::Simple qw();
use XML::Simple qw();
use Data::Dumper;
use MIME::Base64;
use locale;
use utf8 qw();
use Encode qw();
 
use lib "/backend/lib";
require ZOOVY;
require PRODUCT;
# require STUFF;
require LUSER;
require ORDER::BATCH;
require ZTOOLKIT::XMLUTIL;
require SITE;
require CART2;
require DOMAIN;
use strict;

##
## called from /webapi/banners
##
sub handle_banners {
	my ($req,$HEADERSREF) = @_;

	require ADVERT;

	my @URLS = ADVERT::retrieve_urls('',15);
	my $jsarray = '';	foreach my $url (@URLS) { $jsarray .= "'$url',"; } chop($jsarray);
	my $BODY = '';

	$HEADERSREF->{'Content-Type'} = 'text/html';
	$BODY .= (qq~
<body width="320" height="240" scroll="no" bgcolor="FFFFFF" marginwidth="0" marginheight="0" topmargin="0" leftmargin="0" onLoad="progress();">
<center>
<iframe SRC="$URLS[0]" id="iFrameAd" NAME="iFrameAd" WIDTH=320 HEIGHT=240 ALIGN="MIDDLE" FRAMEBORDER=0 MARGINWIDTH=0 MARGINHEIGHT=0 SCROLLING="no"></iframe>
</center><SCRIPT>
<!--
var counter = 0;
var lastTime = 0;
function progress() {
	// called by the flash progress bar
	// never flips an add until 15 seconds or more have elapsed

	var d = new Date();
	var timeIs = d.getTime()/1000;

	if (lastTime + 5 < timeIs) {				
		lastTime = timeIs;	

		var URLS = new Array($jsarray);
		frames['iFrameAd'].location.href = URLS[counter];

		counter = counter + 1;
		if (counter>=URLS.length) { counter = 0; }
		}
	setTimeout('progress()',5000);
	}


if (window.resizeTo) { top.resizeTo(326,246); }
//-->
</SCRIPT></body>
~);
	return(200,$BODY);
	}


##
##
##
sub handle_check {
	my ($req,$HEADERSREF) = @_;

	use lib "/backend/lib";
	require DBINFO;
	#
	# parameters
	#	V=CLIENT-VERSION
	# 	TYPE=ORDER
	#	USERNAME=USERNAME
	#	OID=####-##-######
	#	DIGEST=base64digest
	#
	# RESPONSE FORMAT PLAINTEXT HTTP/200 = SUCCESS
	#	TS:########
	#	ERR:xyz
	#

	my $RESPONSE = '';
	my $form = $req->parameters();

	# leave the digest out for the testing
	my $V = $form->{'V'};
	my $TYPE = $form->{'TYPE'};
	my $USERNAME = $form->{'USERNAME'};

	if ($V eq '') {
		$RESPONSE = "ERR:V= is a required parameter";
		}
	elsif ($USERNAME eq '') {
		$RESPONSE = "ERR:USERNAME= is a required parameter";
		}
	elsif (($TYPE eq 'ORDER') && ($form->{'OID'} eq '')) {
		$RESPONSE = "ERR:OID is a required parameter for TYPE=ORDER";
		}
	elsif ($TYPE eq 'ORDER') {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $qtOID = $udbh->quote($form->{'OID'});
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		my $TB = &DBINFO::resolve_orders_tb($USERNAME,$MID);
		my $pstmt = "select MODIFIED_GMT from $TB where ORDERID=$qtOID and MID=$MID";
		my ($TS) = $udbh->selectrow_array($pstmt);
		if (not defined $TS) {
			$RESPONSE = "ERR:ORDER was not defined";
			}
		else {
			$RESPONSE = "TS:$TS";
			}	
		&DBINFO::db_user_close();
		}
	else {
		$RESPONSE = "ERR:Unknown TYPE=$TYPE";
		}

	$HEADERSREF->{'Content-Type'} = 'text/plain';
	return(200, $RESPONSE);
	}


##
##
##
sub show_msgs {
	my ($msgs) = @_;
	my $output = '';

	foreach my $msg (@{$msgs}) {
		my ($type,$msg) = split(/\|/,$msg,2);

		$type = uc($type);
		my $hint = '';
		if ($msg =~ /\n\n/s) { ($msg,$hint) = split(/\n\n/,$msg); }

		$msg = &ZOOVY::incode($msg);
		if ($hint ne '') { 
			$msg = "<div align=\"left\">$msg<div align=\"left\" class=\"hint\">".&ZOOVY::incode($hint)."</div></div>"; }
		if (($type eq 'SUCCESS') || ($type eq 'WIN') || ($type eq 'INFO')) { 
			$msg = "<div  style='width: 800px; align: center' class='success'>$msg</div>"; }
		elsif (($type eq 'WARN') || ($type eq 'WARNING') || ($type eq 'CAUTION')) { 
			$msg = "<div  style='width: 800px; align: center' class='warning'>$msg</div>"; }
		elsif (($type eq 'ERROR') || ($type eq 'ERR')) { 
			$msg = "<div  style='width: 800px; align: center' class='error'>$msg</div>"; }
		elsif ($type eq 'TODO') { $msg = "<div  style='width: 800px; align: center' class='todo'>$msg</div>"; }
		elsif ($type eq 'LEGACY') { $msg = "<div  style='width: 800px; align: center' class='warning legacy'>$msg</div>"; }
		elsif ($type eq 'ISE') { $msg = "<div  style='width: 800px; align: center' class='error ise'>$msg</div>"; }
		elsif ($type eq 'LINK') { 
			## LINK|/path/to/url|text
			my ($href,$txt) = split(/\|/,$msg,2);
			if ($txt eq '') { $hint = "Link $msg"; }
			$msg = "<div  style='width: 800px; align: center' class='todo'><a target=\"_blank\" href=\"$href\">$txt</a></div>"; 
			}
		else {
			$msg = "<div  style='width: 800px; align: center' class=\"unknown_class_$type\">$msg</div>";
			}
		$output .= $msg;
		}
	return($output);
	}



sub handle_pogwizard {
	my ($req,$HEADERSREF) = @_;

	use lib "/backend/lib";
	use ZOOVY;
	use CGI;
	use STUFF::CGI;
	use STUFF2;
	use POGS;
	use strict;
	use Data::Dumper;

	#
	# http://www.zoovy.com/webapi/merchant/pogwizard.cgi?USERNAME=jefatech&PRODUCT=GD58			(legacy)
	# http://www.zoovy.com/webapi/merchant/pogwizard.cgi?USERNAME=jefatech&PRODUCT=RV245RD		(rich)
	# http://www.zoovy.com/webapi/merchant/pogwizard.cgi?USERNAME=outpost&PRODUCT=W9732			(non-inv)
	# http://www.zoovy.com/webapi/merchant/pogwizard.cgi?USERNAME=1stproweddingalbums&PRODUCT=WBK101015PBSPKG			(excessive)
	#
	my $BODY = '';

	my $q = new CGI;
	my $USERNAME = $q->param('USERNAME');
	my $PRODUCT = $q->param('PRODUCT');
	if ((not defined $PRODUCT) || ($PRODUCT eq '')) { $PRODUCT = $q->param('product'); }
	
	my $CLIENT = $q->param('CLIENT');
	my $STID = $q->param('STID');
	my $COMPAT = int($q->param('COMPAT'));
	if ($COMPAT==0) { $COMPAT = 107; }
	print STDERR "USER:$USERNAME PRODUCT:$PRODUCT COMPAT: $COMPAT\n";
	
	my $VERB = $q->param('VERB');
	
	my ($P) = PRODUCT->new($USERNAME,$PRODUCT,'create'=>0);
	# my @pogs = &POGS::text_to_struct($USERNAME,$prodref->{'zoovy:pogs'},1);
	my $selectedref = {};
	
	my $lm = LISTING::MSGS->new($USERNAME);
	my ($stuff2) = STUFF2->new($USERNAME);
	
	if ($VERB eq 'SAVE') {
		require STUFF::CGI;
	
		## Build a hashref of key/value pairs!
		my %params = ();
		my %lcparams = ();
		foreach my $k ($q->param()) { 
			$params{$k} = $q->param($k); 
			$lcparams{lc($k)} = $params{$k};
			}
		
		#my $stuff = STUFF->new($USERNAME);
		#my @errors = ();
		#my @items = &STUFF::CGI::parse_products($USERNAME,\%lcparams,0,\@errors);
		#foreach my $item (@items) {
		#	$stuff->legacy_cram($item);
		#	}
	
		## note: we need to pass zero_qty_okay but it seems like legacy_parse already does that for us
		($stuff2,$lm) = &STUFF::CGI::legacy_parse($stuff2,\%lcparams,'*LM'=>$lm);
		if (not $lm->can_proceed()) {
			$VERB = 'TRYAGAIN';
			}
		}
	
	
	if ($VERB eq 'SAVE') {
	
	
		my ($xml,$errors) = $stuff2->as_xml($COMPAT);
	
		$HEADERSREF->{'Content-Type'} = 'text/html';
		$BODY .= (qq~
	<html>
	<font color="blue">Success!</font><br>
	<b>This window should close automatically in a moment.</b><br>
	<!--
	<POGWIZARD>$xml</POGWIZARD>
	-->~);
		$BODY .= (qq~</html>~);
		}
	
	
	if (($VERB eq '') || ($VERB eq 'TRYAGAIN')) { 
		$HEADERSREF->{'Content-Type'} = 'text/html';
	
		my $msgs = '';
		if ($VERB eq 'TRYAGAIN') {
			my @msgs = ();
			foreach my $msg (@{$lm->msgs()}) {
				my ($msgref,$status) = LISTING::MSGS::msg_to_disposition($msg);
				push @msgs, "$status|$msgref->{'+'}";
				}
			$msgs = &WEBAPI::show_msgs(\@msgs);
			}
	
	
		my $html = &POGS::struct_to_html($P,$selectedref,4);
	
		$BODY .= (qq~
	<head>
	<link rel="STYLESHEET" type="text/css" href="/biz/standard.css">
	</head>
	<body> 
		<form method=post action="/webapi/merchant/pogwizard.cgi">
		<input type="hidden" name="USERNAME" value="$USERNAME">
		<input type="hidden" name="product" value="$PRODUCT">
		<input type="hidden" name="CLIENT" value="$CLIENT">
		<input type="hidden" name="VERB" value="SAVE">
		<input type="hidden" name="COMPAT" value="$COMPAT">
		$msgs
		$html
		<input type="submit" value=" Submit ">
		</form>
	</body>
		~);
		}

	return(200,$BODY);
	}



sub handle_sync {
	my ($req,$HEADERSREF) = @_;

	## my $HEADERS_IN = $req->headers();

	my $MID = 0;
	my $USERNAME = '';						# the X-ZOOVY-USERNAME variable 
	my $LUSER = '';							# Login Username (e.g. the value after the *)
	my $SERVER = &ZOOVY::servername();		
	my $DATA = '';								# the actual DATA received from the post.
	my $LENGTH = -1;							# the X-LENGTH variable
	my $XREQUEST = '';						# the X-ZOOVY-REQUEST variable
	my $XTIME = -1;							# the X-TIME variable
	my $XAPI = '';								# the API name as it was passed X-ZOOVY-API
	my $ACTUALMD5 = ''; 						# the computed MD5 value
	my $XSECURITY = '';						# the X-ZOOVY-SECURITY variable
	my $API = ''; 								# the actual API (before the params)
	my @APIPARAMS = ();						# the parameters (delimited by /)
	my $EC = 0;									# Error Code 
	my $XCOMPRESS	= '';						# the type of compress specified by X-COMPRESS

	$::XCLIENTCODE = 'WTF';					# the code portion of the X-CLIENT variable (e.g. ZOM/ZWM)
	$::XCOMPAT = 0;							# the compatability mode
	$::XERRORS = 0;							# the X-ERRORS variable
	$ENV{"REMOTE_ADDR"} = $req->address();

	##
	## $::XCOMPAT = 100 -- initial release
	##	$::XCOMPAT = 101 -- 12/25/04 sync process for skulist changed formats slightly.
	## $::XCOMPAT = 102 -- 1/31/05 added VERSION 2 to ZSHIP::xml_out
	##	$::XCOMPAT = 103 -- 4/4/05 changes to customer sync [CRITICAL ERROR]
	##	$::XCOMPAT = 104 -- 4/25/05 changes to customer sync <CUSTOMERSYNC>
	##	$::XCOMPAT = 105 -- 5/28/05 adds required X-CLIENT code. (zwm)
	##	$::XCOMPAT = 106 -- 10/26/05 adds support for X-CLIENT:VERSION:SEAT (zwm)
	##	$::XCOMPAT = 107 -- 7/18/06 changes format for incompletesync. (zom)
	##	$::XCOMPAT = 108 -- 3/13/07 changes xml output of stuff for orders
	##	$::XCOMPAT = 109 -- 4/19/07 implements zoovy.virtual zoovy.prod_supplier zoovy.prod_supplierid removes supplier from skulist.
	##	$::XCOMPAT = 110 -- 8/21/07 changes to events (ts was time)
	## $::XCOMPAT = 111 -- 10/09/07 convert ZOM and ZWM clients to ZID 
	## $::XCOMPAT = 112 -- 10/27/07 versions below have backward compatibility for company_logo in merchant sync
	##	$::XCOMPAT = 113 -- skipped for bad luck
	##	$::XCOMPAT = 114 -- 12/26/07 new email changes (shuts down sendmail)
	##	$::XCOMPAT = 115 -- 2/23/08  [note: released to 114] changed format for stids (cheap hack: e.g.  abc/123*xyz:ffff  becomes 123*abc/xyz:ffff)
	##	$::XCOMPAT = 116 -- 4/10/08 note: 115 is was never apparently released due to bugs, skipping to 116 to be safe.
	##	$::XCOMPAT = 116 -- 5/21/08 re-enables image delete (for 116 and higher)
	##	$::XCOMPAT = 117 -- 4/7/09  changes webdb sync in versioncheck
	## $::XCOMPAT == **HEY** we're maintaining this document in WEBAPI.pm now (around line 37)
	##

	if ($EC==0) { if ($SERVER eq '') { $EC = 998; } }

	## Verify user exists!
	if ($EC==0) {
		$USERNAME = $req->header(lc('X-ZOOVY-USERNAME'));

		## separate the LUSER from the USERNAME
		if (index($USERNAME,'*')>=0) { ($USERNAME,$LUSER) = split(/\*/,$USERNAME); }

		$MID = &ZOOVY::resolve_mid($USERNAME);
		if ($USERNAME eq '') { $EC = 1000; }
		}

	## Read in Data and Check Length
	if ($EC == 0) {
		$LENGTH = int($req->header(lc('X-LENGTH')));
		if ($LENGTH < 0) { $EC = 1002; }

		$DATA = $req->content();

		#open F, ">/tmp/body";
		#print F $DATA."\n";		
		#use Data::Dumper; print F Dumper($req->headers());
		#close F;

		if (length($DATA)!=$LENGTH) {
			$EC = 2000;
			$WEBAPI::ERRORS{$EC} = "Oh My! Length of content ".length($DATA)." received does not match X-LENGTH ($LENGTH).";
			}
		}

	if (defined $req->header(lc('X-ZOOVY-API'))) { 
		$XAPI = $req->header(lc('X-ZOOVY-API'));
		} 
	else { $EC = 1003; }

	if ( ($EC==0) && ($XAPI eq '') ) { $EC = 2003; }
	($API,@APIPARAMS) = split(/\//,$XAPI);

	if ( ($EC==0) && ($API eq 'PAYPROCESS') ) { $EC = 3; }

	if ( ($EC==0) && (not defined $WEBAPI::APIS{$API}) ) { 
		$EC = 2004; $WEBAPI::ERRORS{$EC} = "Unknown/Invalid API [$API] called."; 
		}

	## check for X-ZOOVY-REQUEST and X-TIME
	if ($EC==0) {
		if (defined $req->header(lc('X-ZOOVY-REQUEST'))) { $XREQUEST = $req->header(lc('X-ZOOVY-REQUEST')); } else { $EC = 1004; }
		if (($EC==0) && ($XREQUEST eq '')) { $EC = 2001; }
		if (defined $req->header(lc('X-TIME'))) { $XTIME = $req->header(lc('X-TIME')); } else { $EC = 1005; }
		}


	if ($EC==0) {
		## check to make sure X-CLIENT is set.
		($::XCLIENTCODE) = $req->header(lc('X-CLIENT'));	# get the ZOM or ZWM out of the X-CLIENT variable

		my ($code,$version,$seat) = split(/\:/,$::XCLIENTCODE,2);
		if ($code eq '') { $EC = 2098; }
		elsif ($code =~ /^ZID\./) {}	## all series 8 desktop clients!
		elsif ($code eq 'ZID') {}		## ZOOVY INTEGRATED DESKTOP
		elsif ($code eq 'ZOM') {}		## ORDER MANAGER
		elsif ($code eq 'ZOME') {}	## ENTERPRISE CLIENT
		elsif ($code eq 'ZSM') {}		## SYNC MANAGER
		elsif ($code eq 'ZWM') {}		## WAREHOUSE MANAGER
		elsif ($code eq 'API') {}		## WAREHOUSE MANAGER
		else { $EC = 2099; }
		}

	## make sure we always set the compatibilitylevel otherwise we echo an old compat level zero warning.
	if (defined $req->header(lc('X-COMPAT'))) { $::XCOMPAT = int($req->header(lc('X-COMPAT'))); }

	if ($EC==0) {
		if ($::XCOMPAT<$WEBAPI::MIN_ALLOWED_COMPAT_LEVEL) { $EC = 1024; }
		elsif ($::XCOMPAT>$WEBAPI::MAX_ALLOWED_COMPAT_LEVEL) { $EC = 1025; } 
		if ($EC>0) {
			&ZOOVY::confess($USERNAME,"WEBAPI VERSION: $::XCOMPAT is no longer available MIN:$WEBAPI::MIN_ALLOWED_COMPAT_LEVEL MAX:$WEBAPI::MAX_ALLOWED_COMPAT_LEVEL");
			}
		}

	## verify security 
	if ($EC==0) {

		$XSECURITY = $req->header(lc('X-ZOOVY-SECURITY'));
		my $XPASS = undef;
		if ($XSECURITY eq '') { 
			$EC = 1001; 
			}

		my ($CODE,$VERSION,$SEAT) = split(/\:/,$::XCLIENTCODE,3);
		if ($::XCOMPAT>=111) {
			if (($CODE eq 'ZOM') || ($CODE eq 'ZWM')) { $CODE = 'ZID'; }
			}

		if ($EC==0) {
			## check to make sure we have a license (and appropriate seat count)	 
			my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
			my $FLAGS = ','.$gref->{'cached_flags'}.',';
		
			# my $FLAGS = ','.&ZWEBSITE::fetch_website_attrib($USERNAME,'cached_flags').',';
			$FLAGS =~ s/ZPM/ZWM/g;	# convert warehouse manager to product manager seats

			$EC = 556;

			if ($CODE =~ /^ZID\./) {
				## all series 8 desktop clients match the regex above!
				$SEAT = 1;
				}
			elsif ((($CODE eq 'ZOME') || ($CODE eq 'ZOM') || ($CODE eq 'ZWM') || ($CODE eq '')) && ($SEAT eq '')) { 
				$SEAT = 1; 
				}

			# print STDERR "SEAT[$SEAT] CODE[$CODE]\n";
			foreach my $flag (split(/,/,$FLAGS)) {
				my ($flag,$count) = split(/\*/,$flag);
				if (int($count)==0) { $count++; }
				# print STDERR "FLAG: [$flag] eq [$CODE] $SEAT>0 $SEAT<=$count\n";
				if (($flag eq $CODE) && ($SEAT>0) && ($SEAT<=$count)) {
					$EC = 0;	# whew, we're licensed to use this seat!
					}
				}
	
			## CHEAP HACK FOR SYNC MANAGER!
			if ($CODE eq 'ZSM') { $EC = 0; }
			if ($CODE eq 'ZOME') { $EC = 0; }
			if ($CODE eq 'ZID') { $EC = 0; $SEAT = ''; }
			if ($CODE eq 'API') { $EC = 0; $SEAT = ''; }
			if ($CODE =~ /ZID\./) { 
				$CODE = 'ZID'; 
				$EC = 0; $SEAT = ''; 
				} 	## version 8 of ZID series.
	
			if ($FLAGS !~ /,BASIC,/) {
				$EC = 555;		# insufficient access
				}
			if (($FLAGS =~ /,PKG=SHOPCART,/) && ($FLAGS !~ /,ZID,/)) {
				$EC = 555;
				}
			}

		if ($EC==0) {
			my $PASSWORD = ''; 
			my $MODE = 'PASSWORD';

			if ($XSECURITY =~ /^([A-Z]+)\:(.*?)$/) { $MODE = $1; $XSECURITY = $2; }

			# print STDERR "XSECURITY: [$XSECURITY]\n";

			if ($EC != 0) { 
				}
			elsif ($XSECURITY eq '') { 
				$EC = 2008; 
				}
			elsif ($MODE eq 'TOKEN') {
				## if we pass TOKEN:digest then we lookup token_zom or token_zwm
				if ((int($SEAT)==0) || (int($SEAT)==1)) { $SEAT = ''; }
				# print STDERR "Looking for Token: 'token_'.lc($CODE.$SEAT)\n";
				my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
				my $TOKEN = $gref->{'webapi_zid'} || $gref->{'%plugins'}->{'desktop.zoovy.com'}->{'~password'};

				my $IN = $USERNAME . (($LUSER ne '')?'*'.$LUSER:'') . $TOKEN . $XAPI . $XREQUEST . $XTIME . $DATA;
				my $ACTUALMD5 = Digest::MD5::md5_hex( $IN );
				if ($XSECURITY ne $ACTUALMD5) {
					$EC = 2009;
					}
				}
			elsif ($MODE eq 'PASSWORD') { 
				## this is for PASS:digest
				##if ($LUSER eq '') { $LUSER = 'admin'; }
				#my $zdbh = &DBINFO::db_user_connect($USERNAME);
				#my $pstmt = "select PASSHASH,PASSSALT,IS_ADMIN from LUSERS where MID=$MID and USERNAME=".$zdbh->quote($USERNAME)." and LUSER=".$zdbh->quote($LUSER);
				#&DBINFO::db_user_close();
				$LUSER = '';
				my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
				my $CFG = $gref->{'%plugins'}->{'desktop.zoovy.com'} || {};

				if (not $CFG->{'enable'}) {
					$EC = 2011;
					}
				elsif ($CFG->{'~password'} eq '') {
					$EC = 2006; 
					}
				else {
					$PASSWORD = $CFG->{'~password'};
					}

				if ($EC == 0) {
					my $IN = $USERNAME . (($LUSER ne '')?'*'.$LUSER:'') . $PASSWORD . $XAPI . $XREQUEST . $XTIME . $DATA;
					$ACTUALMD5 = Digest::MD5::md5_hex( $IN );
					if ($ACTUALMD5 ne $XSECURITY) {
						$EC = '2005';
						}
					}
				
				#elsif ($XPASS eq '') { 
				#	$EC = 2006; 
				#	}
				#open F, ">/tmp/x";
				#print F "X:$PASSHASH $PASSSALT -$XPASS- $XSECURITY\n";
				#close F;
				## ORDER MANAGER SENDS ENCRYPTED PASSWORDS OVER SSL! WTF
				#elsif (uc($PASSWORD) ne uc($XPASS)) { 
				#	$EC = '2006'; 
				#	}
				}
			else {
				$EC = 2007;
				}
			print STDERR "SERVER: CLIENT=$::XCLIENTCODE USER=$USERNAME\n";
			}
		}

	## Handle Compression
	if ($EC==0) {
		$::XERRORS = $req->header(lc('X-ERRORS'));
		$XCOMPRESS = $req->header(lc('X-COMPRESS'));
		my $xc = $XCOMPRESS;

		if ($DATA eq '') {
			# print STDERR "DATA IS BLANK [API=$API]\n";
			}
		elsif (substr($xc,0,7) eq 'BASE64:') {
			## Un-MIME encode if necessary
			$xc = substr($xc,7);	# Strip BASE64:
			$DATA = decode_base64($DATA);
			# print STDERR "DID DECODE\n";
			}

		if ($DATA eq '') {
			## no data, don't try to decompress!
			}
		elsif ($xc eq 'NONE') {
			## no compress!
			}
		elsif ($xc eq 'BZIP2') {
			my $TMP = $DATA;
			$DATA = Compress::Bzip2::decompress($TMP);
			if (not defined $DATA) { $EC = 997; }
			}
		elsif ($xc eq 'GZIP') {
			# $dest = Compress::Zlib::memGzip($buffer) ;
			$DATA = Compress::Zlib::memGunzip($DATA);
			if (not defined $DATA) { $EC = 996; }
			}
		elsif ($xc eq 'ZLIB') {
			$DATA = Compress::Zlib::uncompress($DATA);
			if (not defined $DATA) { $EC = 995; }
			}
		else {
			$EC = 1006;
			}
		}

	my $DEBUG = qq~<Debug>
		<x-request>$XREQUEST</x-request>
		<x-username>$USERNAME</x-username>
		<x-mid>$MID</x-mid>
		<x-api>$XAPI</x-api>
		<x-time>$XTIME</x-time>
		<x-security>$XSECURITY</x-security>
		<x-realsecurity>$ACTUALMD5</x-realsecurity>
	</Debug>~;
	$DEBUG = '';

	## NOT LEGACY
	# print STDERR "NOT LEGACY\n";
	$HEADERSREF->{'Content-Type'} = 'text/xml';
	my $BODY = '';
	$BODY .= ("<Response>\n");
	$BODY .= ("<Server>".&ZOOVY::servername()."</Server>\n");
	$BODY .= ("<StartTime>".(time())."</StartTime>\n");

	#if ($USERNAME eq 'bamtar') { $::XERRORS++; }
	#if ($USERNAME eq 'froggysfog') { $::XERRORS++; }

	if (-f "/dev/shm/sync.debug") {
		open F, ">>/tmp/sync.log";
		print F sprintf("%d\t%s\n",time(),$XAPI);
		close F;
		}

	if ($EC!=0) {
		$BODY .= ($DEBUG);
		$BODY .= ("<Errors>\n");
		if ($XREQUEST eq '') { $XREQUEST = -1; }
		$BODY .= ("<Error Id=\"$XREQUEST\" Code=\"$EC\">[ERR#$EC] $WEBAPI::ERRORS{$EC}</Error>\n");
		$BODY .= ("</Errors>\n");
		}
	elsif ($EC==0) {
		$BODY .= ($DEBUG);
		$BODY .= ("<Api>$API</Api>\n");
		
		my ($BatchID,$PickupTime,$xmlOut) = ();

		my ($GUID) = $req->header(lc('X-GUID'));

		if ($GUID ne '') {
			require BATCHJOB;
			my ($bj) = BATCHJOB->create($USERNAME,
				'PRT'=>0,
				'GUID'=>$GUID,
				'EXEC'=>'WEBAPI/API',
				'%VARS'=>{ XAPI=>$XAPI, XREQUEST=>$XREQUEST, DATA=>$DATA },
				'TITLE'=>"WEBAPI $API",
				);
			$bj->start();
			($BatchID) = $bj->id();
			}
		else {
			my ($udbh) = &DBINFO::db_user_connect($USERNAME);
			eval { 
				($PickupTime,$xmlOut) = $WEBAPI::APIS{$API}->($USERNAME,$XAPI,$XREQUEST,$DATA); 
				## note: since db_user_close returns 0 - it causes the eval to return zero.
				};

			if ($@) {
				$PickupTime = -2;
				$xmlOut = "WEBAPI $XAPI Failure\n$@\n";
				&ZOOVY::confess(
					$USERNAME,"$xmlOut\n===== XREQUEST: ======\n$XREQUEST\n\n===== DATA: =====\n$DATA\n\n\n",
					justkidding=>1
					);
				}
			&DBINFO::db_user_close();
			}

		if (($PickupTime==0) && ($BatchID>0)) {
			$BODY .= ("<Batch ID=\"$BatchID\" GUID=\"$GUID\"></Batch>\n");
			}
		elsif ($PickupTime<0) {
			$BODY .= ("<Errors><Error Id=\"$XREQUEST\" Code=\"$PickupTime\">$xmlOut</Error></Errors>\n");
			}
		else {
			$BODY .= (&WEBAPI::addRequest($XCOMPRESS,$XREQUEST,$PickupTime,$xmlOut));
			}

		if ($::XERRORS) {
			use Data::Dumper;
			open F, ">/tmp/XERRORS-$USERNAME-$XREQUEST-$XCOMPRESS.$::XERRORS";
			print F "XREQUEST: $XREQUEST\n";
			print F Dumper($USERNAME,$XAPI,$XREQUEST,$DATA);
			print F "\n\n\n\n-------------------------------------------------------------\nOUTPUT: ".Dumper($PickupTime,$xmlOut);
			close F;
			}
		}

	$BODY .= ("<Time>".(time())."</Time>\n");
	$BODY .= ("</Response>\n");

	return(200,$BODY);
	}


sub userlog {
	my ($USERNAME,$API,$MSG) = @_;
	return(LUSER::log( { LUSER=>'WEBAPI', USERNAME=>$USERNAME }, "WEBAPI.$API", $MSG, "API"));
	}


%WEBAPI::ERRORS = (
	'1' => 'Generic Error... shit happened!',
	'2' => 'WEBAPI Internal Application Failure',
	'3' => 'We regret to inform you that your requested action was denied because payment processing with Order Manager v10 is no longer compatible with the Zoovy servers.',
	'555' => 'Insufficient access flags, please contact Zoovy support',
	'556' => 'Seat not licensed',
	'989' => 'Internal MIME Base64 encoding error.',
	'990' => 'Internal MIME Base64 decoding error.',
	'995' => 'Internal Zlib decomrpession error. Could not decompress data.',
	'996' => 'Internal Gzip decompression error. Could not decompress data.',
	'997' => 'Internal Bzip2 decompression error. Could not decompress data.',
	'998' => 'Internal Error - cannot determine server name.',
	'999' => 'Internal Error - cannot connect to database!',
	'1000' => 'X-ZOOVY-USERNAME was not found in header.',
	'1001' => 'X-ZOOVY-SECURITY was not found in header.',
	'1002' => 'X-LENGTH was not found in header.',
	'1003' => 'X-ZOOVY-API was not found in header.',
	'1004' => 'X-ZOOVY-REQUEST was not found in header.',
	'1005' => 'X-TIME was not found in header.',
	'1006' => 'X-COMPRESS is missing or contains an invalid value, please pick one: NONE|BZIP2|GZIP.',
	'1024' => 'X-COMPAT Error Compatibility level too low, please upgrade to a newer version of your software.',
	'1025' => 'X-COMPAT Error Compatibility level passed exceeds maximum allowed value.',
	'2000' => 'Length of content does not match X-Length.',
	'2001' => 'X-ZOOVY-REQUEST appears to be blank.',
	'2002' => 'Deviation of X-TIME too large.',
	'2003' => 'Variable X-ZOOVY-API was received, but is blank.',
	'2004' => 'Invalid API called.',
	'2005' => 'Security Digests do not match - probably invalid password.',
	'2006' => 'Received legacy X-ZOOVY-PASSWORD variable, but it did not match password on file.',
	'2007' => 'Received unknown MODE: in XSECURITY try either PASSWORD or TOKEN',
	'2008' => 'X-SECURITY cannot be blank',
	'2009' => 'X-SECURITY is invalid.',
	'2010' => 'User attempting to authenticate does not have administrative access',
	'2011' => 'Admin sync is not enabled - please go to Setup | Integrations | Shipping | Zoovy Desktop and enable it.',
	'2012' => 'Admin sync password cannot be blank',
	'2098' => 'X-CLIENT is required at this compatibility level',
	'2099' => 'Unknown X-CLIENT value - please contact zoovy support',
);




%WEBAPI::APIS = (
	'BATCH' => \&WEBAPI::batch,
	'SUPPORT' => \&WEBAPI::support,
	'TEST' => \&WEBAPI::testSync,
	'PICKUP' => \&WEBAPI::Pickup,
	'ORDERSYNC' => \&WEBAPI::OrderSync,
	'ORDERLIST' => \&WEBAPI::OrderList,
	'CUSTOMERSYNC' => \&WEBAPI::CustomerSync,
	# 'PAYPROCESS' => \&WEBAPI::payProcess,
	'CUSTOMERPROCESS' => \&WEBAPI::customerProcess,
	'ORDERPROCESS' => \&WEBAPI::orderProcess,
	'CALCSHIP' => \&WEBAPI::calcShip,
	'ORDERBLOCK' => \&WEBAPI::orderBlock,
	'INCOMPLETESYNC' => \&WEBAPI::incompleteSync,
	'MERCHANTSYNC' => \&WEBAPI::merchantSync,
	'WEBDBSYNC' => \&WEBAPI::webdbSync,
	'INVENTORYSYNC' => \&WEBAPI::inventorySync,
	'SKULIST' => \&WEBAPI::skulistSync,
	'VERSIONCHECK' => \&WEBAPI::versioncheck,
	'PAYMENTMETHODS' => \&WEBAPI::paymentMethodsSync,
	'NAVCATSYNC' => \&WEBAPI::navcatSync,
	'LOOKUP' => \&WEBAPI::lookup,
	'PRODSYNC' => \&WEBAPI::prodSync,
	'IMAGESYNC' => \&WEBAPI::imageSync,
	'SENDMAIL' => \&WEBAPI::sendMail,
	'ADMINSYNC' => \&WEBAPI::adminSync,
	'REGISTER' => \&WEBAPI::registerSync,
	'TOXMLSYNC'	=> \&WEBAPI::toxmlSync,
	'LAUNCHGROUPSYNC' => \&WEBAPI::launchGroupSync,
	'SOGSYNC' => \&WEBAPI::sogSync,
	'GIFTCARDSYNC' => \&WEBAPI::giftCardSync,
	'WALLETSYNC' => \&WEBAPI::walletSync,
	'CSVIMPORT'	=> \&WEBAPI::csvImportSync,
	'RESOURCE' => \&WEBAPI::resourceSync,
	'SUPPLIERSYNC' => \&WEBAPI::supplierSync,	
	);


## goes through and replaces all the keys that have colons with dashes e.g.
##		zoovy:prod_name becomes zoovy-prod_name
sub hashref_colon_to_dashxml {
	my ($hashref) = @_;

	my $BUFFER = "";
	my $k2 = '';
	foreach my $k (keys %{$hashref}) {
		next if (index($k,':')<0);
		$k2 = lc($k);
		$k2 =~ s/\:/-/;
		$BUFFER .= "<$k2>".&ZOOVY::incode($hashref->{$k})."</$k2>\n";
		}
	return($BUFFER);
	}


##
## SUPPLIERSYNC
##	
#=pod
#
#[[SECTION]API: SUPPLIERSYNC]
#sends XML data from pub1 to Supply Chain
#ie Order Confirmations
#[[/SECTION]]
#
#=cut
#
sub supplierSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;
	
	require SUPPLIER;
	my ($API,$METHOD,$ACTION) = split(/\//,$XAPI,3);

	## SUPPLIER::from_xml deals with error handling
	my ($ERROR,$XML) = SUPPLIER::from_xml($USERNAME,$DATA,$METHOD,$ACTION,$::XCOMPAT);

	## embed error in XML as needed
	if ($ERROR ne '') { $XML .= "<Errors><Error>$ERROR</Error></Errors>"; }
	$XML = "<supplier$METHOD$ACTION>$XML</supplier$METHOD$ACTION>";

	return($ERROR,$XML);
	}


##
## Records the registration of a client.
##
sub registerSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	require ZTOOLKIT::SECUREKEY;
	my $securekey = &ZTOOLKIT::SECUREKEY::gen_key($USERNAME,'ZO');

	##
	## insert overly elaborate seat registration process here.
	##

	my $XML = qq~<SecureKey>$securekey</SecureKey>~;
	$XML = "<Registration>$XML</Registration>";
	
	return($XML);
	}


##
## RESOURCE/filename
##

=pod

[[SECTION]API: RESOURCE]
Purpose: Downloads internal resource files from Zoovy.  Files can be requested as either .xml, .json, or .yaml
[[BREAK]]
<li> shipcodes.ext: a list of all carrier codes, and associated properties.
<li> shipcountries.ext: a list of all shipping countries, if they are safe, etc.
<li> flexedit.ext: a list of all fields in the zoovy platform
<li> payment_status.ext: a complete list of all possible payment status codes, and their definitions.
<li> review_status.ext: a complete list of all possible review/fraud status codes, and their definitions.
<li> integrations.ext: a complete list of all integrations and their id's, dst codes, meta, attributes, etc.
<li> warehosues.ext: 
[[/SECTION]]

=cut
sub resourceSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	require XML::Simple;
	require JSON::XS;

	my $xs = new XML::Simple(ForceArray=>1,KeyAttr=>"");
	
	my $out = '';
	my ($API,$FILENAME) = split(/\//,$XAPI,3);

	my $ref = undef;
	my $EXT = undef;
	if ($FILENAME =~ /^shipcodes\.(.*?)$/) {
		$EXT = $1;
		$ref = \%ZSHIP::SHIPCODES;
		# $out = $xs->XMLout(\%ZSHIP::SHIPCODES);
		}
	elsif ($FILENAME =~ /^shipcountries\.(.*?)$/) { 
		$EXT = $1;
		$ref = Storable::retrieve("/httpd/static/country-highrisk.bin");
		if ($EXT eq 'xml') {
			$ref = { 'country'=>$ref };
			}
		}
	elsif ($FILENAME =~ /^flexedit\.(.*?)$/) { 
		$EXT = $1;
		require PRODUCT::FLEXEDIT;
		$ref = \%PRODUCT::FLEXEDIT::fields;
		}
	elsif ($FILENAME =~ /^payment_status\.(.*?)$/) { 
		$EXT = $1;
		require ZPAY;
		$ref = [];
		foreach my $ps (sort keys %ZPAY::PAYMENT_STATUS) {
			push @{$ref}, { 'ps'=>$ps, 'txt'=>$ZPAY::PAYMENT_STATUS{$ps} };
			}
		}
	elsif ($FILENAME =~ /^review_status\.(.*?)$/) { 
		$EXT = $1;
		require ZPAY;
		$ref = [];
		foreach my $rs (sort keys %ZPAY::REVIEW_STATUS) {
			push @{$ref}, { 'rs'=>$rs, 'txt'=>$ZPAY::REVIEW_STATUS{$rs} };
			}
		}
	elsif ($FILENAME eq /^integrations\.(.*?)$/) {
		$EXT = $1;
		$ref = \@ZOOVY::INTEGRATIONS;
		}
	elsif ($FILENAME eq /^warehouse.(.*?)$/) {
		$EXT = $1;
		
		}


	if ($EXT eq 'yaml') {
		$out = YAML::Syck::Dump($ref);
		}
	elsif ($EXT eq 'xml') { 
		$out = $xs->XMLout($ref);
		}
	elsif ($EXT eq 'json') { 
		$out = JSON::XS::encode_json($ref);
		}
	
	return(0,$out);
	}




##
## SUPPORT/TICKET/CREATE
##
sub support {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	require SUPPORT;
	my ($API,$METHOD,$ACTION) = split(/\//,$XAPI,3);

	my $XML = '';

	my ($globalref) = &ZWEBSITE::fetch_globalref($USERNAME);
	my $overrides = $globalref->{'%overrides'};
	if (not defined $overrides) { $overrides = {}; }

	
	## NOTE: usually $::XCLIENTCODE is something like: ZID.OM.SOHO:8.077
	##			it is output in the subject of the ticket following a "v" e.g. "vZID.OM.SOHO:8.077"
	my $zidkey = $::XCLIENTCODE;
	if ((defined $overrides) && (defined $overrides->{$zidkey})) {
		## HEY SYSOPS: 
		##		in merchant global.bin put in key %overrides and then specific overrides in a key/value format:
		##		'%overrides'=> { 'ZID.OM.SOHO:8.077'=>'tickets_allowed_allowed=0' }
		##		specify multiple parameters in uri encoded format e.g.:
		##		'%overrides'=> { 'ZID.OM.SOHO:8.077'=>'tickets_allowed_allowed=0&future_compatibility=is_fun', }
		
		my ($versionsettings) = &ZTOOLKIT::parseparams($overrides->{$zidkey});
		foreach my $k (keys %{$versionsettings}) {	
			## copy keys from version specific overrides
			$overrides->{$k} = $versionsettings->{$k};
			}
		}

	my $tickets_allowed = 1;
	if (defined $overrides->{'tickets_allowed'}) {
		## this key globally turns off webapi support tickets.
		$tickets_allowed = int($overrides->{'tickets_allowed'}); 	## allow by default.
		}

	if (not $tickets_allowed) {
		## no ticket functionality allowed.
		$XML = "<support ticket_id=\"0\"/>";
		}
	elsif ($METHOD eq 'TICKET') {
		if ($ACTION eq 'CREATE') {
			require PLUGIN::HELPDESK;
			my ($ticket, $error) = PLUGIN::HELPDESK::create_ticket($USERNAME,
				ORIGIN=>'ZID',
				DISPOSITION=>'LOW',
				TECH=>'@ZID',
				BODY=>$DATA,
				NOTIFY=>0,
				SUBJECT=>"WebAPI Ticket Dump v$::XCLIENTCODE",
				);
			$XML = "<support ticket_id=\"$ticket\" error=\"error\" />";
			}
		}

	if ($XML eq ''){
		$XML = "<support error=\"unknown XAPI=$XAPI\"/>";
		}

#	use Data::Dumper;
#	print STDERR Dumper($XML);

	return(0,$XML);
	}


#sub currentSupportPass {
#	my ($USERNAME) = @_;
#	
#	require Digest::MD5;
#	my $digest = Digest::MD5::md5_hex('fizzy' . $USERNAME . int(time() /86400));
#
#	return( substr($digest,3,9) );
#	}

##
## Sets up a sync token for the warehouse manager, sync manager, and order manager.
##

=pod

[[SECTION]API: ADMINSYNC]
Generates a new securekey for a given client. You must be given a client code by Zoovy to use this.
[[/SECTION]]

=cut

sub adminSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $XML = '';
	my $PickupTime = 0;

	my ($API,$LOGIN) = split(/\//,$XAPI,2);
	my $LUSER = '';
	if (index($LOGIN,'*')>=0) { (undef,$LUSER) = split(/\*/,lc($LOGIN)); }
	my ($CODE,$VERSION) = split(/\:/,$::XCLIENTCODE,3);


	## 
	## Generate a new Token - and save that in the webdb (assuming this isn't support syncing)
	##
	my $TOKEN = '';

	my $gref = &ZWEBSITE::fetch_globalref($USERNAME);

	## needed for version 7 compatibility
	my $cached_flags .= ',SOHONET,NETWORK,ZIDNET,ZWM,';
	my @ERRORS = ();

	if ($CODE =~ /^ZID[\.]?(.*?)/) {
		## Currently ZID is authorized for everything.
		$CODE = 'ZID';
		}
	else {
		push @ERRORS, "Unknown Client $CODE";
		}

	#my @characters = ('A' .. 'Z', 'a' .. 'z', 0 .. 9);
	#my $cs = scalar(@characters);
	#my $s = (time() % $$) ^ $$ ^ time(); srand($s);
	#for (1 .. 1024) { $TOKEN .= $characters[rand $cs]; }
	## for now we'll save to both webdb and gref
	#my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,0);
	#delete $webdbref->{'token_'.lc($CODE)};
	#&ZWEBSITE::save_website_dbref($USERNAME,$webdbref,0);

	if ($gref->{'webapi_zid'} || $gref->{'token_zid'}) {
		delete $gref->{'webapi_zid'};
		delete $gref->{'token_zid'};
		&ZWEBSITE::save_globalref($USERNAME,$gref);
		}
	$TOKEN = $gref->{'%plugins'}->{'desktop.zoovy.com'}->{'~password'};
	if ($TOKEN eq '') {
		push @ERRORS, "Integration/plugin desktop.zoovy.com ~password is not set";
		}
	elsif (not $gref->{'%plugins'}->{'desktop.zoovy.com'}->{'enable'}) {
		push @ERRORS, "Sorry, but integration/plugin desktop.zoovy.com is not currently enabled.";
		}

	if (@ERRORS>0) {
		foreach my $err (@ERRORS) {
			$XML .= "<Error>$err</Error>";
			}
		$XML = "<Errors>$XML</Errors>";
		}
	else {
		## NO ERRORS, OUTPUT XML
		my $USERXML = '';
		my $MID = &ZOOVY::resolve_mid($USERNAME);
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select * from LUSERS where MID=$MID /* $USERNAME */";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		my @ar = ();
		require Digest::MD5;
		while ( my $u = $sth->fetchrow_hashref() ) {
			next if ($u->{'PASSPIN'} eq '');	## don't send people with blank pin/passwords
			$u->{'MD5PASS'} = Digest::MD5::md5_hex( $u->{'PASSPIN'} . $TOKEN );
			delete $u->{'PASSSALT'};		## these should never be shared!
			delete $u->{'PASSHASH'};
			# delete $u->{'PASSWORD'};		## ORDER MANAGER REQUIRES THIS TO BE UNENCRYPTED (SO IT CAN INSERT INTO MYSQL)
			$u->{'PASSWORD'} = $u->{'PASSPIN'};
			delete $u->{'MERCHANT'};
			delete $u->{'MID'};
			$u->{'FLAG_ZOM'} = 0x1;	## 2= set package verification
			push @ar, $u;
			}
		&DBINFO::db_user_close();

		$USERXML = &ZTOOLKIT::arrayref_to_xmlish_list(\@ar,tag=>'User');

#		require ZTOOLKIT::SECUREKEY;
#		my $securekey = &ZTOOLKIT::SECUREKEY::gen_key($USERNAME,'ZO');

		my $PARTITIONS = '';
		
		my ($prtsref) = &ZWEBSITE::list_partitions($USERNAME);
		my $i = 0;
		my @PRTS = ();
		foreach my $prtref (@{$prtsref}) {
			my ($prtref) = &ZWEBSITE::prtinfo($USERNAME,$i);
			$prtref->{'id'} = $i;
			push @PRTS, $prtref;
			$i++;
			}
		$PARTITIONS = &ZTOOLKIT::arrayref_to_xmlish_list(\@PRTS,tag=>'prt');

		$XML = qq~
<Token>$TOKEN</Token>
<Partitions>$PARTITIONS</Partitions>
<Users>
$USERXML
</Users>~;
		}

	$XML = "<AdminSync><Username>$USERNAME</Username><Flags>$cached_flags</Flags>$XML</AdminSync>";

	return($PickupTime,$XML);
	}



################################################################################################################################
##
## sub: versioncheck
##

=pod
[[SECTION]API: VERSIONCHECK]
Checks your clients version and compatibility level against the API's current compatibility level.
[[BREAK]
RESPONSE can be either
<li> OKAY - proceed with normal
<li> FAIL - a reason for the failure
<li> WARN - a warning, but it is okay to proceed

[[SUBSECTION]Response]
[[HTML]]
<VersionCheck>
   <ConfigVersion>$ts</ConfigVersion>
   <Response>$RESPONSE</Response>
   <ResponseMsg>$RESPONSEMESG</ResponseMsg>
</VersionCheck>
[[/HTML]]
[[/SUBSECTION]]

[[/SECTION]]

=cut

sub versioncheck {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$CLIENT,$VERSION,$STATIONID,$SUBUSER,$LOCALIP,$OSVER,$FINGER) = split(/\//,$XAPI,8);
	my ($MAJOR,$MINOR) = split(/\./,$VERSION,2);
	if (not defined $OSVER) { $OSVER = '?'; }
	if (not defined $FINGER) { $FINGER = '?'; }
	
	$OSVER =~ s/^Microsoft//gs;

	##
	## RESPONSE can be either
	##		OKAY - proceed with normal
	##		FAIL - a reason for the failure
	##		WARN - a warning, but it is okay to proceed
	##
	my $RESPONSE = 'FAIL';
	my $RESPONSEMESG = 'Unknown client: '.$XAPI;


#	if (1) {
#		$RESPONSE = 'FAIL'; $RESPONSEMESG = 'We are currently performing system maintenance'; 
#		}
	if ($CLIENT =~ /^ZID[\.](.*?)?/) {
		## ZID.????
		## NOTE: after version 8 -- this is the only client.
		$RESPONSE = 'OKAY'; $RESPONSEMESG = 'Elvis lives!';
		if ($MAJOR==11) {
		#	if ($MINOR < 200) {
		#		$RESPONSE = 'WARN'; $RESPONSEMESG = 'This version will stop functioning on Feburary 15th 2013. You MUST upgrade before this date.';
		#		}
		#	elsif ($MINOR < 204) { 
		#		$RESPONSE = 'WARN'; $RESPONSEMESG = 'This version will stop functioning on Feburary 28th 2013. You MUST upgrade before this date.';
		#		}
			}
		elsif ($MAJOR<11) {
#			$RESPONSE = 'WARN'; $RESPONSEMESG = 'Zoovy has upgraded our payment infrastructure. Please upgrade to the latest version of this software. If you continue to use this software we do not recommend processing payments.';
			$RESPONSE = 'WARN'; $RESPONSEMESG = 'This version will stop functioning on January 31st, 2011. You MUST upgrade before this date.';
			}
		elsif ($MAJOR<=8) {
			$RESPONSE = 'FAIL'; $RESPONSEMESG = 'This version has expired. Please upgrade to the latest version of this software';
			}
		}
	elsif ($CLIENT eq 'FOO') {
		$RESPONSE = 'WARN'; $RESPONSEMESG = 'Run away!';
		}

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	$/ = undef; open F, "</proc/sys/kernel/hostname"; my $hostname = <F>; close F; $/ = "\n";
	$hostname =~ s/\W+//g;
	if (not defined $hostname) { $hostname = '?'; }
	&DBINFO::insert($udbh,'SYNC_LOG',{
		'USERNAME'=>$USERNAME,
		'MID'=>&ZOOVY::resolve_mid($USERNAME),
		'*CREATED'=>'now()',
		'CLIENT'=>"$CLIENT=$VERSION",
		'HOST'=>$hostname,
		'PUBLICIP'=>sprintf("%s",$ENV{'REMOTE_ADDR'}),
		'REMOTEIP'=>$LOCALIP,
		'SYNCTYPE'=>$SUBUSER,
		'OSVER'=>$OSVER,
		'FINGERPRINT'=>$FINGER,
		});
	&DBINFO::db_user_close();

	my ($ts) = &ZOOVY::touched($USERNAME);

	$XML = qq~<VersionCheck>
	<ConfigVersion>$ts</ConfigVersion>
	<Response>$RESPONSE</Response>
	<ResponseMsg>$RESPONSEMESG</ResponseMsg>
</VersionCheck>~;

	# print STDERR "RESPONSE: $PickupTime $XML\n";

	return($PickupTime,$XML);
	}



################################################################################################################################
##
##		DOWNLOAD
##		UPLOAD/XX-some_sog_name
##

=pod

[[SECTION]API: SOGSYNC]
[[SUBSECTION]METHOD: SOGSYNC/DOWNLOAD]
Returns a list of Store Option Groups (SOGs), see the SOG xml format for more specific information.
[[SUBSECTION]Response]
[[HTML]]
<SOGS>
<pog ...></pog>
</SOGS>
[[/HTML]]
[[/SUBSECTION]]

[[/SUBSECTION]]
[[/SECTION]]

=cut

sub sogSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;
	my $XML = '';
	my $PickupTime = 0;	

	my ($API,$FUNCTION,$PARAM1,$PARAM2) = split(/\//,$XAPI,4);

	require POGS;
	if ($FUNCTION eq 'DOWNLOAD') {
		my $listref = POGS::list_sogs($USERNAME);
		$XML = "<SOGS>";
		foreach my $sogid (sort keys %{$listref}) {
			my $sogref = &POGS::load_sogref($USERNAME,$sogid);
			$XML .= &POGS::to_xml($sogref);
			}
		$XML .= "</SOGS>";
		}
	

	return($PickupTime,$XML);
	}


############################################################################
## 
##	CSVIMPORT/PRODUCT
##

=pod

[[SECTION]API: CSVIMPORT]
[[SUBSECTION]METHOD: CSVIMPORT/FILETYPE]
This is a wrapper around the CSV file import available in the user interface.
Creates an import batch job. Filetype may be one of the following:
<li> JEDI
<li> PRODUCT
<li> INVENTORY
<li> CUSTOMER
<li> ORDER
<li> CATEGORY
<li> REVIEW
<li> REWRITES
<li> RULES
<li> LISTINGS

[[HINT]]
The file type may also be overridden in the header. See the CSV import documentation for current
descriptions of the file. 
[[/HINT]]

[[SUBSECTION]Response:]
[[HTML]]
<RESULTS>
<JOBID>jobid</JOBID>
</RESULTS>
[[/HTML]]
[[/SUBSECTION]]

[[/SUBSECTION]]

[[/SECTION]]

=cut

sub csvImportSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $PickupTime = 0;
	my ($API,$FILETYPE) = split(/\//,$XAPI,2);

	require LUSER;
	require ZCSV;
	my ($LU) = LUSER->new_app($USERNAME,'WEBAPI-csvImportSync');

	my ($JOBID,$ERROR) = &ZCSV::addFile('*LU'=>$LU,SRC=>"WEBAPI",TYPE=>$FILETYPE,BUFFER=>$DATA);
	
#	$IMPORT::SILENT = 1;
#
#	my $CSV;
#	my ($fieldref,$lineref,$optionsref) = &ZCSV::readHeaders($DATA,header=>1);	
#	if ($FILETYPE ne '') {
#		$optionsref->{'TYPE'} = $FILETYPE;
#		}
#
#	# &ZCSV::logImport($USERNAME,$LUSERNAME,$fieldref,$lineref,$optionsref);
#	my $linecount = -1;
#	if ($optionsref->{'TYPE'} eq 'PRODUCT') {
#		require ZCSV::PRODUCT;
#		($linecount) = &ZCSV::PRODUCT::parseproduct($LU,$fieldref,$lineref,$optionsref);	
#		}

	return($PickupTime,"<RESULTS><JOBID>$JOBID</JOBID><COUNT>$JOBID</COUNT></RESULTS>");
	}

################################################################################################################################
##
## sub: giftCardSync
##
##		
##

=pog

[[SECTION]API: GIFTCARDSYNC]

[[SUBSECTION]METHOD: GIFTCARDSYNC/LIST]
[[SUBSECTION]Response]
[[HTML]]
<GIFTCARDS TS="##">
<GIFTCARD ID="" CODE="" CREATED_GMT="" EXPIRES_GMT="" LAST_ORDER="" CID="" NOTE="" BALANCE="" TXNCOUNT="" MODIFIED_GMT="" CASHEQUIV="" COMBINABLE=""></GIFTCARD>
<GIFTCARD ID="" CODE="" CREATED_GMT="" EXPIRES_GMT="" LAST_ORDER="" CID="" NOTE="" BALANCE="" TXNCOUNT="" MODIFIED_GMT="" CASHEQUIV="" COMBINABLE=""></GIFTCARD>
</GIFTCARDS>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: GIFTCARDSYNC/CHANGED]
[[SUBSECTION]Response]
Same response format as LIST but only displays giftcards that have not been ACK'd
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: GIFTCARDSYNC/ACK]
Acknowledge receipt of giftcards. 
[[SUBSECTION]Request]
[[HTML]]
<GIFTCARDS>
<GIFTCARD ID="1" ACK="Y"/>
<GIFTCARD ID="2" ACK="Y"/>
</GIFTCARDS>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[/SECTION]]

=cut

sub giftCardSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $MID = &ZOOVY::resolve_mid($USERNAME);

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$FUNCTION,$PARAM1,$PARAM2) = split(/\//,$XAPI,4);
	require GIFTCARD;
	
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	if ($FUNCTION eq 'LIST') {
		my ($gcref) = &GIFTCARD::list($USERNAME,TS=>$PARAM1);
		$XML = &ZTOOLKIT::arrayref_to_xmlish_list($gcref,'tag'=>'GIFTCARD');
		$XML = "<GIFTCARDS TS=\"".(time()-1)."\">$XML</GIFTCARDS>";
		}
	elsif ($FUNCTION eq 'CHANGED') {
		my ($gcref) = &GIFTCARD::list($USERNAME,'CHANGED'=>int($PARAM1));
		$XML = &ZTOOLKIT::arrayref_to_xmlish_list($gcref,'tag'=>'GIFTCARD');
		$XML = "<GIFTCARDS TS=\"".(time()-1)."\">$XML</GIFTCARDS>";
		}
	elsif ($FUNCTION eq 'ACK') {
	#	$xml = qq~<GIFTCARDS>
	#	<GIFTCARD ID="1" ACK="Y"/>
	#	<GIFTCARD ID="2" ACK="Y"/>
	#	<GIFTCARD ID="3" ACK="Y"/>
	#	</GIFTCARDS>
	#	~;
		my @ACKS = ();
		my ($rs) = XML::Simple::XMLin($DATA,ForceArray=>1);
		foreach my $incref (@{$rs->{'GIFTCARD'}}) {
			# print STDERR Dumper($incref);
			if ($incref->{'ACK'} eq 'Y') {
				push @ACKS, $incref->{'ID'};
		      }
			else {
				warn "no acks for $incref->{'ID'}\n";
				}
			}
		my $ts = time();
		# print STDERR 'ACKS:'.Dumper(\@ACKS);
		if (scalar(@ACKS)>0) {
			my $pstmt = "update GIFTCARDS set SYNCED_GMT=$ts where MID=$MID /* $USERNAME */ and ID in ".&DBINFO::makeset($udbh,\@ACKS);
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			}	

		}
	elsif ($FUNCTION eq 'CREATE') {
		#my ($code) = &GIFTCARD::createCard($USERNAME,$BALANCE);
		#$XML = "<GIFTCARDS><GIFTCARD CODE=\"$code\"></GIFTCARD></GIFTCARDS>";	
		}
	&DBINFO::db_user_close();

	return($PickupTime,$XML)
	}


################################################################################################################################
##
## sub: walletSync
##
##		
##

=pod

[[SECTION]API: WALLETSYNC]

[[SUBSECTION]METHOD: WALLETSYNC/CHANGED]
[[SUBSECTION]Response]
[[HTML]]
<WALLETS>
<WALLET ID="" CID="" CREATED="" EXPIRES="" IS_DEFAULT="" DESCRIPTION="" ATTEMPTS="" FAILURES="" IS_DELETED=""></WALLET>
<WALLET ID="" CID="" CREATED="" EXPIRES="" IS_DEFAULT="" DESCRIPTION="" ATTEMPTS="" FAILURES="" IS_DELETED=""></WALLET>
<WALLET ID="" CID="" CREATED="" EXPIRES="" IS_DEFAULT="" DESCRIPTION="" ATTEMPTS="" FAILURES="" IS_DELETED=""></WALLET>
</WALLETS>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: WALLETSYNC/ACK]
[[SUBSECTION]Request]
[[HTML]]
<WALLETS>
<WALLET ID="" ACK="Y"/>
<WALLET ID="" ACK="Y"/>
<WALLET ID="" ACK="Y"/>
</WALLETS>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[/SECTION]]

=cut

sub walletSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $MID = &ZOOVY::resolve_mid($USERNAME);

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$FUNCTION,$PARAM1,$PARAM2) = split(/\//,$XAPI,4);
	require GIFTCARD;
	
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	#mysql> desc CUSTOMER_SECURE;
	#+-------------+---------------------+------+-----+---------+----------------+
	#| Field       | Type                | Null | Key | Default | Extra          |
	#+-------------+---------------------+------+-----+---------+----------------+
	#| ID          | int(10) unsigned    | NO   | PRI | NULL    | auto_increment |
	#| MID         | int(10) unsigned    | NO   | MUL | 0       |                |
	#| CID         | int(10) unsigned    | NO   |     | 0       |                |
	#| CREATED     | datetime            | YES  |     | NULL    |                |
	#| EXPIRES     | datetime            | YES  | MUL | NULL    |                |
	#| IS_DEFAULT  | tinyint(3) unsigned | NO   |     | 0       |                |
	#| DESCRIPTION | varchar(20)         | NO   |     | NULL    |                |
	#| SECURE      | tinytext            | NO   |     | NULL    |                |
	#| ATTEMPTS    | int(11)             | NO   |     | 0       |                |
	#| FAILURES    | int(11)             | NO   |     | 0       |                |
	#| SYNCED_GMT  | int(10) unsigned    | NO   |     | 0       |                |
	#| IS_DELETED  | tinyint(3) unsigned | NO   |     | 0       |                |
	#+-------------+---------------------+------+-----+---------+----------------+
	#12 rows in set (0.00 sec)
	if ($FUNCTION eq 'CHANGED') {
		my $LIMIT = int($PARAM1);
		my @wallets = ();
		my $pstmt = "select ID,CID,CREATED,EXPIRES,IS_DEFAULT,DESCRIPTION,ATTEMPTS,FAILURES,IS_DELETED from CUSTOMER_SECURE where MID=$MID /* $USERNAME */ and SYNCED_GMT=0 limit 0,$LIMIT";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $ref = $sth->fetchrow_hashref() ) {
			push @wallets, $ref;
			}
		$sth->finish();
		$XML = &ZTOOLKIT::arrayref_to_xmlish_list(\@wallets,'tag'=>'WALLET');
		$XML = "<WALLETS TS=\"".(time()-1)."\">$XML</WALLETS>";
		}
	elsif ($FUNCTION eq 'ACK') {
	#	$xml = qq~<WALLET>
	#	<GIFTCARD ID="1" ACK="Y"/>
	#	<GIFTCARD ID="2" ACK="Y"/>
	#	<GIFTCARD ID="3" ACK="Y"/>
	#	</WALLET>
	#	~;
		my @ACKS = ();
		my ($rs) = XML::Simple::XMLin($DATA,ForceArray=>1);
		foreach my $incref (@{$rs->{'WALLET'}}) {
			# print STDERR Dumper($incref);
			if ($incref->{'ACK'} eq 'Y') {
				push @ACKS, $incref->{'ID'};
		      }
			else {
				warn "no acks for $incref->{'ID'}\n";
				}
			}
		my $ts = time();
		# print STDERR 'ACKS:'.Dumper(\@ACKS);
		if (scalar(@ACKS)>0) {
			my $pstmt = "update CUSTOMER_SECURE set SYNCED_GMT=$ts where MID=$MID /* $USERNAME */ and ID in ".&DBINFO::makeset($udbh,\@ACKS);
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			}	
		}
	elsif ($FUNCTION eq 'CREATE') {
		#my ($code) = &GIFTCARD::createCard($USERNAME,$BALANCE);
		#$XML = "<GIFTCARDS><GIFTCARD CODE=\"$code\"></GIFTCARD></GIFTCARDS>";	
		}
	&DBINFO::db_user_close();

	return($PickupTime,$XML)
	}


################################################################################################################################
##
## sub: paymentMethodsSync
##

=pod

[[SECTION]API: PAYMENTMETHODSSYNC]

[[SUBSECTION]METHOD: TOXMLSYNC/LIST]
[[SUBSECTION]Response]
Returns pnumonics based on the payment types available. 
[[HTML]]
SUPPORTED: CASH,CREDIT\n
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[CAUTION]]
this call may be deprecated, or change substantially in the future.
[[/CAUTION]]

[[/SECTION]]

=cut

sub paymentMethodsSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	require ZPAY;

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$FUNCTION,$TIMESTAMP) = split(/\//,$XAPI,3);

	my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,0);

	my ($cart,$country,$ordertotal) = ();
	my ($payref) = &ZPAY::payment_methods($USERNAME, cart=>$cart, country=>$country, ordertotal=>$ordertotal, webdb=>$webdbref);

	my @methods = ();
	foreach my $ref (@{$payref}) {
		push @methods, $ref->{'id'};
		}
	$XML = sprintf("SUPPORTED:%s\n",join(',',@methods));

	return($PickupTime,$XML);
	}







##
## SUB: doCompress
##	Purpose: what the hell do you think it's supposed to do?
##
sub doCompress {
	my ($XCOMPRESS,$xmlOut) = @_;

	if ($xmlOut eq '') {
		## no data, don't try to decompress!
		}
	elsif ($XCOMPRESS eq 'NONE') {
		## no compress!
		}
	elsif ($XCOMPRESS eq 'BZIP2') {
		$xmlOut = Compress::Bzip2::compress($xmlOut);
		}
	elsif ($XCOMPRESS eq 'GZIP') {
   	$xmlOut = Compress::Zlib::memGzip($xmlOut);
		}
	elsif ($XCOMPRESS eq 'ZLIB') {
		$xmlOut = Compress::Zlib::compress($xmlOut);
		}

	return($xmlOut);
	}

## 
## SUB: addRequest
##	Purpose: does encoding of data into CDATA.. at some point I suspect we might do more work here.
##		such as logging, qos, and/or other types of encoding (e.g. mime)
##
sub addRequest {
	my ($XCOMPRESS,$ID,$PickupTime,$xmlOut) = @_;
	
	if ($xmlOut eq '') {
		## no data, don't try to decompress!
		}
	elsif ($XCOMPRESS eq 'NONE') {
		## no compress!
		}
	elsif ($XCOMPRESS eq 'BASE64:NONE') {
		$XCOMPRESS = 'BASE64:NONE';
		# $xmlOut = encode_base64($xmlOut);
		$xmlOut = encode_base64(Encode::encode("UTF-8", $xmlOut));
		}
	elsif ($XCOMPRESS eq 'BZIP2' || $XCOMPRESS eq 'BASE64:BZIP2') {
		$XCOMPRESS = 'BASE64:BZIP2';
		$xmlOut = encode_base64(Compress::Bzip2::compress($xmlOut));
		}
	elsif ($XCOMPRESS eq 'GZIP'  || $XCOMPRESS eq 'BASE64:GZIP') {
		$XCOMPRESS = 'BASE64:GZIP';
      $xmlOut = encode_base64(Compress::Zlib::memGzip($xmlOut));
		}
	elsif ($XCOMPRESS eq 'ZLIB' || $XCOMPRESS eq 'BASE64:ZLIB') {
		$XCOMPRESS = 'BASE64:ZLIB';
		$xmlOut = encode_base64(Compress::Zlib::compress($xmlOut));
		}

	my $out = '';
	$out = "<Request Id=\"$ID\" COMPRESS=\"$XCOMPRESS\" PickupTime=\"$PickupTime\">";
	if ($PickupTime==0) { 
		$out .= "<![CDATA[$xmlOut]]>"; 
		}
	$out .= "</Request>\n";
	}



##
## sub: Pickup
## purpose: Handles a pickup request, or re-issues another pickup request.
##
sub Pickup {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my ($API,$FUNCTION) = split(/\//,$XAPI);

	my $PickupTime = time()+0;
	$DATA = "Here is a response for $ID!"; $PickupTime = 0;

	return($PickupTime,$DATA);
	}

################################################################################################################################
##
## sub: testSync
##	purpose: the quintessiential testing library.. creates simulated requests
##

=pod

[[SECTION]API: TESTSYNC]

[[SUBSECTION]METHOD: TESTSYNC/ECHO]
[[SUBSECTION]Response]
Returns as DATA exactly what the API received in DATA.
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: TESTSYNC/REVERSE]
[[SUBSECTION]Response]
Returns as DATA a reversed string of exactly what the API received in DATA.
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: TESTSYNC/ECHODELAY]
[[SUBSECTION]Response]
Returns a pickup job that will be picked up in 2 seconds.
[[/SUBSECTION]]
[[/SUBSECTION]]

[[/SECTION]]

=cut


sub testSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $XML = '';
	my ($API,$FUNCTION) = split(/\//,$XAPI);

	my $PickupTime = 0;
	my $PickupURL = '';

	if ($FUNCTION eq 'ECHO') { $XML = $DATA; }
	elsif ($FUNCTION eq 'REVERSE') { $XML = reverse($DATA); }
	elsif ($FUNCTION eq 'ECHODELAY') { 
		$PickupTime = time()+2;
		$XML = '';
		}

	return($PickupTime,$XML);	
	}


################################################################################################################################
##
## sub: orderBlock
## purpose: blocks a series of order ids.
##	methods:
##		ORDERBLOCK/[count]				- loads order, quotes shipping (if DATA includes order, then it is saved)
##

=pod

[[SECTION]API: ORDERBLOCK]

[[SUBSECTION]METHOD: ORDERBLOCK/count]
[[SUBSECTION]Response]
Returns (and reserves) a list of order #'s, CR/LF separated.
[[/SUBSECTION]]
[[/SUBSECTION]]

[[/SECTION]]

=cut


sub orderBlock {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$BLOCK) = split(/\//,$XAPI,3);

	$BLOCK = int($BLOCK);
	if (!$BLOCK) { $BLOCK = "10"; }
	# if ($BLOCK<0) { $BLOCK = 1; }

	my $NEXTID = CART2::next_id($USERNAME,$BLOCK);
	my ($YEAR,$MON,$THIS_ID) = split(/-/,$NEXTID,3);
	my $FIRST_ID = $THIS_ID;
	my $YEARMON = "$YEAR-$MON";
	$XML  = "";
	while ($BLOCK-->0)  { $XML .= "$YEARMON-".($THIS_ID-$BLOCK).","; }
   chop($XML);

	&WEBAPI::userlog($USERNAME,"WEBAPI.ORDERBLOCK","RESERVED $YEARMON range: $FIRST_ID - $THIS_ID");

	return($PickupTime,$XML);
	}




################################################################################################################################
##
## sub: calcShip
## purpose: customer data synchronization
##	methods:
##		CALCSHIP/ORDER/[order id]				- loads order, quotes shipping (if DATA includes order, then it is saved)
##		CALCSHIP/RATEONLY							- pass order in DATA and it will be rated.
##

=pod

[[SECTION]API: CALCSHIP]

[[SUBSECTION]METHOD: CALCSHIP/ORDER/orderid]
[[SUBSECTION]Response]
[[HTML]]
<CalcShipping>
<METHOD TAXABLE="" ID="" CARRIER="" VALUE=""></METHOD>
<METHOD TAXABLE="" ID="" CARRIER="" VALUE=""></METHOD>
<HND TAXABLE="" VALUE=""></HND>
<INS TAXABLE="" VALUE=""></INS>
<SPC TAXABLE="" VALUE=""></SPC>
</CalcShipping>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: CALCSHIP/ORDER/RATEONLY]
[[SUBSECTION]Request]
Pass full order XML in data (see ORDERSYNC for formatting)
[[/SUBSECTION]]
[[SUBSECTION]Response]
See CALCSHIP/ORDER/orderid
[[/SUBSECTION]]
[[/SUBSECTION]]


[[/SECTION]]


=cut

sub calcShip {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$FUNCTION,$OPTS) = split(/\//,$XAPI,3);
	
	my ($CART2) = ();
	if (($FUNCTION eq 'ORDER') && ($OPTS ne '*')) {
		$CART2 = CART2->new_from_oid($USERNAME,$OPTS);
		}
	elsif ($FUNCTION eq 'RATEONLY') {
		$CART2 = CART2->new_memory($USERNAME);
		}
	$CART2->make_readonly();

	my $error = '';
	if (not defined $CART2) { return(-1,"Order error"); }
	if ($DATA ne '') { 
		($error) = $CART2->from_xml($DATA,$::XCOMPAT,'calcShip');
		if (ref($CART2) ne 'CART2') { $error = "Order object was not blessed."; }

		if ($error ne '') { 
			return(-1,"Server Parsing error: $error."); 
			}
		elsif ($CART2->is_order()) { 
			# $CART2->add_history("Called order->save from WEBAPI::calcShip",undef,128);
			# $CART2->order_save(); 
			}
		}

	#require CART;
	#my $CART2 = CART2->new_from_order($o);
	## NOTE: if IS_EXTERNAL is set to 1 then it breaks order manager external shipping apis
	$CART2->shipmethods('force_update'=>1);
	# $CART2->shipping();

	my $V = 2; 
	$XML = &ZSHIP::xml_out($CART2,$V);
	$XML = "<CalcShipping>$XML</CalcShipping>";

	return($PickupTime,$XML);
	}




=pod

[[SECTION]API: CUSTOMERPROCESS]

[[SUBSECTION]METHOD: CUSTOMERPROCESS/XMLBATCH]
[[SUBSECTION]Response]
[[HTML]]
<MACROS>
<MACRO CID="1234">macro cmds</MACRO>
<MACRO CID="1235">macro cmds</MACRO>
<MACRO PRT="0" EMAIL="somebody@something.com">macro cmds</MACRO>
</MACROS>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: CUSTOMERPROCESS/MACRO/CID/cid#]
[[SUBSECTION]Request]
[[HTML]]
macro data
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]Using Customer Macros]
Customer Macros provide a developer with a way to make easy, incremental, non-destructive updates to customers.
The syntax for a macro payload uses a familiar dsn format cmd?key=value&key=value, along with the same
uri encoding rules, and one command per line (making the files very easy to read) -- here is an example:
"ADD-TAG?tag=CUSTOMTAG" (without the quotes). A complete list of available commands is below:

<ul>
<li> TAG-ADD?tag=TAG1
<li> TAG-DEL?tag=TAG1
<li> TAGS-RESET
<li> SETSHIPADDR?id=DEFAULT&ship_company=&ship_firstname=&ship_lastname=&ship_phone=&ship_address1=&ship_address2=&ship_city=&ship_country=&ship_email=&ship_state=&ship_province=&ship_zip=&ship_int_zip=
<li> SETBILLADDR?id=DEFAULT&bill_company=&bill_firstname=&bill_lastname=&bill_phone=&bill_address1=&bill_address2=&bill_city=&bill_country=&bill_email=&bill_state=&bill_province=&bill_zip=&bill_int_zip=
<li> ADD-NOTE?note=TAG&luser=luserid&ts=#timestamp
<li> OPT-OUT?note=reason given for opting out
<li> SAVE
<li> ECHO
</ul>

[[/SECTION]]

=cut

sub customerProcess {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $PickupTime = 0;
	my ($API,$FUNCTION,$TARGET) = split(/\//,$XAPI,4);

	print STDERR "XAPI: $XAPI\n";

	my $ERROR = undef;

	my $XML = '';
	my %CUSTOMERS = ();

	if ($FUNCTION eq 'XMLBATCH') {
		## <MACROS>
		## <MACRO CID="1234">data</MACRO> 
		## <MACRO EMAIL="joe@cool.com" PRT="0">data</MACRO> 
		##	</MACROS>
		require XML::SAX::Simple;
		require IO::String;
		# print STDERR "DATA: $DATA\n";

		# <![CDATA[content]]>
		my $io = IO::String->new($DATA);
		my $ref = eval { XML::SAX::Simple::XMLin($io,ForceArray=>1,ContentKey=>'_content'); };
		if ($@) { $ERROR = $@; }

		## 
		foreach my $m (@{$ref->{'MACRO'}}) {
			next unless ($m->{'_content'} =~ /CDATA/);
			open F, ">/tmp/macro-bad-payload.xml.".time();
			print F $DATA;
			close F;
			}

		
		foreach my $m (@{$ref->{'MACRO'}}) {
			if (defined $m->{'EMAIL'}) {
				$m->{'CID'} = &CUSTOMER::resolve_customer_id($USERNAME,$m->{'PRT'},$m->{'EMAIL'});
				}

			my $CID = $m->{'CID'};
			my $CMDS = &CART2::parse_macro_script($m->{'_content'});

			if (defined $ERROR) {
				## shit already happened.
				}
			elsif ($CID>0) {
				$ERROR = "At least one CID=\"\" or EMAIL=\"\" attribute was not specified on a macro";
				}
			elsif ($m->{'_content'} eq '') {
				$ERROR = "No commands received for customer $CID";
				}
			elsif (not defined $CUSTOMERS{$CID}) {
				## adding commands for new order (new command stack)
				$CUSTOMERS{$CID} = $CMDS;
				}
			else {
				## appending commands to existing order
				foreach my $cmd (@{$CMDS}) { push @{$CUSTOMERS{$CID}}, $cmd; }
				}
		
			}
		}
	elsif (($FUNCTION eq 'MACRO') && ($TARGET eq '')) {
		$ERROR = "Calls to CUSTOMERPROCESS/MACRO must have [orderid] specified.";
		}
	elsif (($FUNCTION eq 'MACRO') && ($TARGET =~ /CID\/([\d]+)$/)) {
		## FUNCTION:MACRO means individual single serving order.
		my ($CID) = $1;
		if ($DATA ne '') {
			my $CMDS = &CART2::parse_macro_script($DATA);
			$CUSTOMERS{$CID} = $CMDS;
			}
		}

	use Data::Dumper;
	if (&ZOOVY::servername() eq 'newdev') {
		open F, ">/home/becky/syncs/customermacros-$USERNAME.".time();
		print F Dumper(\%CUSTOMERS);
		close F;
		open F, ">/tmp/customermacros-$USERNAME.".time();
		print F Dumper(\%CUSTOMERS);
		close F;
		}

	if (not defined $ERROR) {

		foreach my $CID (sort keys %CUSTOMERS) {
			my ($C,$cerr) = undef;

			my ($CMDS) = $CUSTOMERS{$CID};

			if ($CMDS->[0]->[0] eq 'CREATE') {
				#($o,$oerr) = ORDER->new(
				#	$USERNAME,'',
				#	'new'=>1,
				#	'useoid'=>$ORDERID,
				#	'save'=>0,
				#	'mkts'=>'0001KW',
				#	'data'=>{
				#		'mkts'=>'0001KW',
				#		'mkt'=>2048
				#		}
				#	);
				}
			else {
				$C = CUSTOMER->new($USERNAME,CID=>$CID);
				}

			if ((not defined $C) || (ref($C) ne 'CUSTOMER')) {
				if ((not defined $cerr) || ($cerr eq '')) { $cerr = "Could not instantiate Customer OBJ:$CID (reason unknown)"; }
				$ERROR = $cerr;
				}
			else {
				# $C->add_history("called WEBAPI::orderProcess::MACRO",undef,128);
				$C->run_macro_cmds($CMDS);
				## if ($FUNCTION eq 'XMLBATCH') { $echo++; }	# XMLBATCH always ECHO's
				$C->save();
				#if ($is_new) { $o->dispatch('create'); }
				$XML .= $C->as_xml($::XCOMPAT);
				}

			}
		}

	if (defined $ERROR) {
		$PickupTime = -1; 
		$XML = "ORDERPROCESS.ERROR-$ERROR";
		}

	print STDERR "XML: $XML\n";
	return($PickupTime,$XML);	
	}



################################################################################################################################
##
## sub: CustomerSync
## purpose: customer data synchronization -- COMPATIBILITY 102 and BELOW
##	methods:
## 	CUSTOMERSYNC/SUMMARY/[timestamp]		- creates a list of customers which have changed in a specific time.
## 	CUSTOMERSYNC/DOWNLIST/[id1,id2,]		- downloads a list of customers (pass comma separated list - 50 max)
##		CUSTOMERSYNC/UPLOAD						- uploads customer (pass as data)
##		CUSTOMERSYNC/LOOKUPCID/[prt]/[email]
##		CUSTOMERSYNC/INCREMENTALS
##

=pod

[[SECTION]API: CUSTOMERSYNC]

[[SUBSECTION]METHOD: CUSTOMERSYNC/SUMMARY/timestamp]
creates a list of customers which have changed in a specific time
[[SUBSECTION]Request]
[[HTML]]
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: CUSTOMERSYNC/DOWNLIST/cid1,cid2,cid3]
50 max customers per request!
[[SUBSECTION]Request]
[[HTML]]
<CUSTOMERSYNC>

.. see customer xml record format below ..
</CUSTOMERSYNC>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: CUSTOMERSYNC/UPLOAD]
[[SUBSECTION]Request]
[[HTML]]

.. see customer xml record format below ..

[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: CUSTOMERSYNC/SUMMARY/timestamp]
[[SUBSECTION]Response]
[[HTML]]
<CUSTOMERS>
<CUSTOMER CID="" PRT="" EMAIL=""   TS=""/>
<CUSTOMER CID="" PRT="" EMAIL=""   TS=""/>
<CUSTOMER CID="" PRT="" EMAIL=""   TS=""/>
</CUSTOMERS>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: CUSTOMERSYNC/LOOKUPCID/prt/email]
[[SUBSECTION]Response]
[[HTML]]
<CUSTOMER PRT="" EMAIL="" CID=""/>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]




[[MODULE]CUSTOMER::XML]

[[/SECTION]]


=cut

sub CustomerSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$FUNCTION,$OPTS) = split(/\//,$XAPI,3);
	if ($API ne 'CUSTOMERSYNC') { return(-1,'incorrect function name!'); }

	my $odbh = &DBINFO::db_user_connect($USERNAME);

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $qtUSERNAME = $odbh->quote($USERNAME);		
	my ($CUSTOMERTB) = &CUSTOMER::resolve_customer_tb($USERNAME,$MID);

	if ($FUNCTION eq 'LOOKUPCID') {
		my ($PRT,$EMAIL) = split(/\//,$OPTS);
		my ($CID) = &CUSTOMER::resolve_customer_id($USERNAME,$PRT,$EMAIL);
		$XML = "<CUSTOMER PRT=\"$PRT\" EMAIL=\"$EMAIL\" CID=\"$CID\"/>";
		}
	elsif ($FUNCTION eq 'SUMMARY') {
		require ZWEBAPI;
		my $pstmt = "select CID, PRT, EMAIL, MODIFIED_GMT from $CUSTOMERTB where MID=$MID /* $qtUSERNAME */ ";
		if (int($OPTS)>0) { $pstmt .= " and MODIFIED_GMT>".int($OPTS); }
		print STDERR $pstmt."\n";

		$XML = "<CUSTOMERS>";
		my $sth = $odbh->prepare($pstmt);
		my $rv = $sth->execute();
		if (defined($rv)) {
			while ( my ($id, $prt, $email, $modified) = $sth->fetchrow() )  {
				$email = &ZWEBAPI::xml_incode($email);
				$XML .= "<CUSTOMER CID=\"$id\" PRT=\"$prt\" EMAIL=\"$email\"	TS=\"$modified\"/>\n";
				}
			}
		$XML .= "</CUSTOMERS>\n";
		# print STDERR $XML;
		}
	elsif ($FUNCTION eq 'DOWNLIST') {
		$XML = "";
		
		my @IDS = ();
		if ($FUNCTION eq 'DOWNLIST') { @IDS = split(/,/,$OPTS); }
		$XML = "<CUSTOMERSYNC>";
		foreach my $CID (@IDS) {
			my ($C) = CUSTOMER->new($USERNAME,CID=>$CID,INIT=>0xFF);
			next if (not defined $C);
			$XML .= $C->as_xml($::XCOMPAT)."\n";
			}
		$XML .= "\n</CUSTOMERSYNC>\n"; 
		}
	elsif ($FUNCTION eq 'UPLOAD') {
		require CUSTOMER::XML;
		$XML = &CUSTOMER::XML::import($USERNAME,$DATA,$::XCOMPAT);
		$XML = "<CustomerSync>$XML</CustomerSync>";
		}

	&DBINFO::db_user_close();
	
	return($PickupTime,$XML);	
	
	}



##
## sub: LOOKUP
##	 	LOOKUP/ORDER/key=value/key=value
##
##

=pod

[[SECTION]API: LOOKUP]

[[SUBSECTION]METHOD: LOOKUP/ORDER/key=value/key=value]

Returns a subset of orders matching one or more filter criteria. A list of filter's is below.

[[SUBSECTION]Request]
Possible key/values:
<li> POOL: RECENT|COMPLETED|etc.
<li> CUSTOMER: customer id #
<li> TS: modified since
<li> EBAY: ebay userid (searches external items)
<li> DETAIL: 1 - ORDERID,MODIFIED,
<li> DETAIL: 3 - all of 1-2 and POOL,CREATED_GMT
<li> DETAIL: 5 - all of 1-4 and CUSTOMER,ORDER_BILL_NAME,ORDER_BILL_EMAIL,ORDER_BILL_ZONE,ORDER_PAYMENT_STATUS,ORDER_PAYMENT_METHOD,ORDER_TOTAL,ORDER_SPECIAL,MKT,MKT_BITSTR
<li> DETAIL: 7 - all of 1-6 and SHIPPED_GMT, ORDER_SHIP_NAME, ORDER_SHIP_ZONE,
<li> DETAIL: 9 - all of 1-7 and REVIEW_STATUS, ITEMS, FLAGS
<li> EREFID
<li> BILL_FULLNAME: substring match on fullname
<li> BILL_EMAIL: substring match on email
<li> BILL_PHONE: full phone match
<li> DATA: substring match on attributes
<li> SHIP_FULLNAME: substring match on ship fullname
<li> CREATED_GMT: created since epoch ts
<li> CREATEDTILL_GMT: created before epoch ts
<li> PAID_GMT: paid since epoch ts
<li> PAIDTILL_GMT: paid before epoch ts
<li> PAYMENT_STATUS: matching payment status code ex: 001
<li> PAYMENT_METHOD: tender type pneumonic ex: CASH, MIXED
<li> PAYMENT_VERB: PAID|UNPAID|PENDING|DENIED|CANCELLED|REVIEW|PROCESSING|VOIDED|ERROR
<li> SHIPPED_GMT: shipping since
<li> SDOMAIN: purchased on sdomain (also ebay.com, and amazon.com work)
<li> NEEDS_SYNC: has the requires sync flag checked
<li> V: internal order version #
<li> MKT_BIT: a marketplace id ex: 1 for ebay, 6 for amazon (see INTEGRATIONS resource table)
<li> PRT: partition #
<li> LIMIT: maximum number of rows returned
<li> big=1 optimize for big results!
[[/SUBSECTION]]
[[SUBSECTION]Response]
[[HTML]]
<LOOKUP TYPE="ORDERS" KEYS="key=value/key=value">
<ORDER ORDERID="" MODIFIED="ts" ..exact results depend on DETAIL level requested.. />
</LOOKUP>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[/SECTION]]


=cut

sub lookup {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $XML = '';
	
	my ($API,$TYPE,@SETS) = split(/\//,$XAPI,4);
	if ($API ne 'LOOKUP') {
		return(-1,'incorrect function name!');
		}
	
	my %params = ();
	foreach my $set (@SETS) {
		my ($k,$v) = split(/=/,$set,2);
		$params{$k} = $v;
		}

	if ($TYPE eq 'ORDER') {
		require ORDER::BATCH;
		my ($result) = ORDER::BATCH::report($USERNAME,%params);
		$XML = &ZTOOLKIT::arrayref_to_xmlish_list($result,tag=>'ORDER');
		}

	$XML = "<LOOKUP TYPE=\"$TYPE\" KEYS=\"".join("/",@SETS)."\">$XML</LOOKUP>";
	

	return(0,$XML);
	}


#####################################################################################
##
## ORDERLIST/TIMESTAMPS/[ts]
##	ORDERLIST/CHANGED
##

=pod

[[SECTION]API: ORDERLIST]

[[SUBSECTION]METHOD: ORDERLIST/TIMESTAMPS/ts]
Returns a list of orders which have been modified since the ts timestamp.
[[SUBSECTION]Response]
[[HTML]]
<ORDERLIST>
<ORDER ID="" TS="" STATUS="" />
<ORDER ID="" TS="" STATUS="" />
<ORDER ID="" TS="" STATUS="" />
</ORDERLIST>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: ORDERLIST/CHANGED]
Returns a list of orders which have the "NEEDS_SYNC" flag turned on.
[[SUBSECTION]Response]
See ORDERLIST/TIMESTAMPS for response
[[/SUBSECTION]]
[[/SUBSECTION]]

[[/SECTION]]


=cut

sub OrderList {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$FUNCTION,$OPTS,$OPTS2) = split(/\//,$XAPI,4);
	## NOTE: this can also be called as ORDERSYNC or ORDERLIST
	#if ($API ne 'ORDERLIST') {
	#	return(-1,'incorrect function name!');
	#	}

	if ($OPTS2 == 0) {
		$FUNCTION = 'CHANGED';
		}

	if ($FUNCTION eq 'TIMESTAMPS') {
		$XML = "<ORDERLIST>"; 
		require ORDER::BATCH;
		my ($tsref,$statref,$ctimeref) = &ORDER::BATCH::list_orders($USERNAME,'',int($OPTS),int($OPTS2));
		foreach my $key (keys %{$tsref}) {
			$XML .= "<ORDER ID=\"$key\" TS=\"$tsref->{$key}\" STATUS=\"$statref->{$key}\" />\n";
			}
		$XML .= "</ORDERLIST>";
		}
	elsif ($FUNCTION eq 'CHANGED') {
		$XML = "<ORDERLIST>"; 
		my ($res) = &ORDER::BATCH::report($USERNAME, NEEDS_SYNC=>1, DETAIL=>3);	
		foreach my $ref (@{$res}) {
			$XML .= "<ORDER ID=\"$ref->{'ORDERID'}\" TS=\"$ref->{'MODIFIED_GMT'}\" STATUS=\"$ref->{'POOL'}\" />\n";
			}
		$XML .= "</ORDERLIST>";
		}
	else {
		warn "ORDERLIST Function: $FUNCTION unknown\n";
		}

	return($PickupTime,$XML);
	}


################################################################################################################################
##
## sub: fullOrderSync
## purpose: order synchronization
##	methods:
##		ORDERSYNC/UPLOAD (include orders in data)
##		ORDERSYNC/SINCE/[timestamp]
## 	ORDERSYNC/ORDERLIST/order1,order2,order3,order4 (max 50 orders)
##		ORDERSYNC/TIMESTAMPS/[timestamp]
##

=pod

[[SECTION]API: ORDERSYNC]

NOTE: syncing an order via ORDERSYNC will disable the NEEDS_SYNC flag on the order.

[[SUBSECTION]METHOD: ORDERSYNC/UPLOAD]
[[SUBSECTION]Request]
Pass full order XML in data, this will be a destructive overwrite of the order.
For this reason we recommend using ORDERPROCESS with incremental macros to make smaller changes to orders.
[[/SUBSECTION]]
[[SUBSECTION]Response]
[[HTML]]
<LENGTH>##</LENGTH>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: ORDERSYNC/SINCE/timestamp]
The order object format changes frequently and is maintained in a separate document. 
[[LINKDOC]50213]

[[SUBSECTION]Response]
[[HTML]]
<ORDERSYNC>
<ORDER ID="" USER="" V="5"></ORDER>
<ORDER ID="" USER="" V="5"></ORDER>
<ORDER ID="" USER="" V="5"></ORDER>
</ORDERSYNC>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: ORDERSYNC/ORDERLIST/order1,order2,order3,order4]

The order object format changes frequently and is maintained in a separate document. 
[[LINKDOC]50213]

[[SUBSECTION]Response]
[[HTML]]
<ORDERSYNC>
<ORDER ID="" USER="" V="5"></ORDER>
<ORDER ID="" USER="" V="5"></ORDER>
<ORDER ID="" USER="" V="5"></ORDER>
</ORDERSYNC>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: ORDERSYNC/TIMESTAMPS/ts]
[[CAUTION]]
This call has been deprecated, use ORDERLIST instead!
[[/CAUTION]]
[[/SUBSECTION]]


[[/SECTION]]


=cut

sub OrderSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$FUNCTION,$OPTS,$OPTS2) = split(/\//,$XAPI,4);
	if ($API ne 'ORDERSYNC') {
		return(-1,'incorrect function name!');
		}

	my @SYNCED = ();

	if ($FUNCTION eq 'TIMESTAMPS') {
		## DEPRECATED -- use ORDERLIST instead!
		return(&WEBAPI::OrderList(@_));
		}	
	elsif ($FUNCTION eq 'UPLOAD') {
		if ($DATA eq '') { return(-1,'Error: you must pass properly formatted orders in the data portion'); }
		$XML = "<LENGTH>" . length($DATA) . "</LENGTH>";
		while ($DATA =~ s/\<ORDER(.*?)\<\/ORDER\>//is) {
			my ($XML) = $1;
			my ($CART2) = CART2->new_memory($USERNAME);
			$CART2->from_xml('<ORDER'.$XML.'</ORDER>',$::XCOMPAT,'ORDERSYNC/UPLOAD');
			$CART2->order_save();
			push @SYNCED, $CART2;
			}
		}
	elsif ($FUNCTION eq 'SINCE') {
		if ($OPTS eq '') { return(-1,'Error: try FULLORDERSYNC/SINCE/[timestamp] (hint: you missed the timestamp)'); }
		require ORDER::BATCH;
		## print STDERR "SINCE/OPTS: $OPTS\n";

		## do a -5 second offset for toynk to see if it fixes paypal orders stuck in paid.
		## if ($USERNAME eq 'toynk') { $OPTS = $OPTS - 5; }

		my ($tsref, $statref, $createref) = &ORDER::BATCH::list_orders($USERNAME, '', int($OPTS));
	#	exit;
		$XML = '<ORDERSYNC>';
		foreach my $ID (keys %{$tsref}) {
			next if ($ID eq '');
			my ($CART2) = CART2->new_from_oid($USERNAME,$ID);
			if (defined $CART2) {
				$XML .= $CART2->as_xml($::XCOMPAT);
				push @SYNCED, $CART2;
				}
			#my ($o,$error) = ORDER->new($USERNAME,$ID);
			#if (defined $o) {
			#	$XML .= $o->as_xml($::XCOMPAT);
			#	push @SYNCED, $o;
			#	}
			}
		$XML .= "</ORDERSYNC>\n";	# need a trailing cr/lf for o/m
		}
	elsif ($FUNCTION eq 'ORDERLIST') {
		my @orders = split(/,/,$OPTS);
		if (scalar(@orders)<=0) { return(-1,'Function ORDERLIST requires you pass a comma separated list of ids.'); }
		$XML = '<ORDERSYNC>';
		foreach my $ID (@orders) {

			next if ($ID eq '');
			my ($CART2) = CART2->new_from_oid($USERNAME,$ID);
			if (defined $CART2) {
				$XML .= $CART2->as_xml($::XCOMPAT);
				push @SYNCED, $CART2;
				}
			}
		$XML .= '</ORDERSYNC>';
		}
	else {
		return(-1,'Valid functions are: UPLOAD,SINCE/[timestamp], or ORDERLIST');
		}

	if (scalar(@SYNCED)>0) {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		foreach my $CART2 (@SYNCED) {
			# print "SYNCING: ".$o->oid()."\n";
			$CART2->synced();
			}
		&DBINFO::db_user_close();
		}

	return($PickupTime,$XML);
	}




##################################################################################################
##
## sub: orderProcess
##
##	ORDERPROCESS/MACRO/[orderid]/[luser]
##		DATA is a macro script
##
##

=pod

[[SECTION]API: ORDERPROCESS]

[[SUBSECTION]METHOD: ORDERPROCESS/XMLBATCH]
Sends macros for multiple orders in one call.
[[SUBSECTION]Request]
[[HTML]]
<MACROS>
<MACRO ORDERID="2010-01-1234">macro cmds</MACRO>
<MACRO ORDERID="2011-01-1235">macro cmds</MACRO>
</MACROS>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: ORDERPROCESS/MACRO/orderid/luser]
[[SUBSECTION]Request]
[[HTML]]
macro data
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]Using Order Macros]
Order Macros provide a developer with a way to make easy, incremental, non-destructive updates to orders. 
The syntax for a macro payload uses a familiar dsn format cmd?key=value&key=value, along with the same
uri encoding rules, and one command per line (making the files very easy to read) -- here is an example:
"SETPOOL?pool=COMPLETED" (without the quotes). A complete list of available commands is below:

<ul>
<li> CREATE
<li> SETPOOL?pool=[pool]\n
<li> CAPTURE?amount=[amount]\n
<li> ADDTRACKING?carrier=[UPS|FDX]&track=[1234]\n
<li> EMAIL?msg=[msgname]\n
<li> ADDNOTE?note=[note]\n
<li> SET?key=value	 (for setting attributes)
<li> SPLITORDER
<li> MERGEORDER?oid=src orderid
<li> ADDPAYMENT?tender=CREDIT&amt=0.20&UUID=&ts=&note=&CC=&CY=&CI=&amt=
<li> ADDPROCESSPAYMENT?VERB=&same_params_as_addpayment<br>
	NOTE: unlike 'ADDPAYMENT' the 'ADDPROCESSPAYMENT' this will add then run the specified verb.
	Verbs are: 'INIT' the payment as if it had been entered by the customer at checkout,
	other verbs: AUTHORIZE|CAPTURE|CHARGE|VOID|REFUND
<li> PROCESSPAYMENT?VERB=verb&UUID=uuid&amt=<br>
	Possible verbs: AUTHORIZE|CAPTURE|CHARGE|VOID|REFUND
<li> SETSHIPADDR? ship_company=&ship_firstname=&ship_lastname=&ship_phone=&ship_address1=&ship_address2=&ship_city=&ship_country=&ship_email=&ship_state=&ship_province=&ship_zip=&ship_int_zip=
<li> SETBILLADDR?bill_company=&bill_firstname=&bill_lastname=&bill_phone=&bill_address1=&bill_address2=&bill_city=&bill_country=&bill_email=&bill_state=&bill_province=&bill_zip=&bill_int_zip=
<li> SETSHIPPING?shp_total=&shp_taxable=&shp_carrier=&hnd_total=&hnd_taxable=&ins_total=&ins_taxable=&spc_total=&spc_taxable=
<li> SETADDRS?any=attribute&anyother=attribute
<li> SETTAX?state_tax_rate=&local_tax_rate=
<li> SETSTUFFXML?xml=encodedstuffxml
<li> FLAGASPAID
<li> SAVE
<li> ECHO
</ul>

[[/SUBSECTION]]

[[/SECTION]]


=cut

sub orderProcess {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $PickupTime = 0;
	my ($API,$FUNCTION,$ORDERID) = split(/\//,$XAPI,4);

	## print STDERR "XAPI: $XAPI\n";

	my $ERROR = undef;

	my $XML = '';
	my %ORDERS = ();

	if ($FUNCTION eq 'XMLBATCH') {
		## <MACROS>
		## <MACRO ORDERID="2010-01-1234">data</MACRO> 
		## <MACRO ORDERID="2011-01-1235">data</MACRO> 
		##	</MACROS>
		require XML::SAX::Simple;
		require IO::String;
		# print STDERR "DATA: $DATA\n";

		# <![CDATA[content]]>
#		open F, ">/tmp/orderprocess.datapayload.$USERNAME";
#		print F $DATA;
#		close F;

		my $io = IO::String->new($DATA);
		my $ref = eval { XML::SAX::Simple::XMLin($io,ForceArray=>1,ContentKey=>'_content'); };
		if ($@) { 
			$ERROR = $@; 
			}
		#elsif ($USERNAME eq 'beltiscool') {
		#	}
		else {
			unlink("/tmp/orderprocess.datapayload.$USERNAME");
			}
		


		## 
		foreach my $m (@{$ref->{'MACRO'}}) {
			next unless ($m->{'_content'} =~ /CDATA/);
			open F, ">/tmp/macro-bad-payload.xml.".time();
			print F $DATA;
			close F;
			}

		
		foreach my $m (@{$ref->{'MACRO'}}) {
			my $ORDERID = $m->{'ORDERID'};
			my $CMDS = &CART2::parse_macro_script($m->{'_content'});

			#open F, ">/dev/shm/macro-$ORDERID";
			#print F $m->{'_content'};
			#close F;

			if (defined $ERROR) {
				## shit already happened.
				}
			elsif ($ORDERID eq '') {
				$ERROR = "At least one ORDERID=\"\" attribute was not specified on a macro";
				}
			elsif ($m->{'_content'} eq '') {
				$ERROR = "No commands received for order $ORDERID";
				}
			elsif (not defined $ORDERS{$ORDERID}) {
				## adding commands for new order (new command stack)
				$ORDERS{$ORDERID} = $CMDS;
				}
			else {
				## appending commands to existing order
				foreach my $cmd (@{$CMDS}) { push @{$ORDERS{$ORDERID}}, $cmd; }
				}
		
			}
		}
	elsif (($FUNCTION eq 'MACRO') && ($ORDERID eq '')) {
		$ERROR = "Calls to ORDERPROCESS/MACRO must have [orderid] specified.";
		}
	elsif ($FUNCTION eq 'MACRO') {
		## FUNCTION:MACRO means individual single serving order.
		if ($DATA ne '') {
			my $CMDS = &CART2::parse_macro_script($DATA);
			$ORDERS{$ORDERID} = $CMDS;
			}
		}

	#if (&ZOOVY::servername() eq 'newdev') {
	#	open F, ">/home/becky/syncs/ordermacros-$USERNAME.".time();
	#	print F Dumper(\%ORDERS);
	#	close F;
	#	open F, ">/tmp/ordermacros-$USERNAME.".time();
	#	print F Dumper(\%ORDERS);
	#	close F;
	#	}

	if (not defined $ERROR) {


		foreach $ORDERID (sort keys %ORDERS) {
			# my ($o,$oerr,$is_new) = undef;
			my ($CART2,$is_new) = undef;

			my ($CMDS) = $ORDERS{$ORDERID};

			if ($CMDS->[0]->[0] eq 'CREATE') {
				$CART2 = CART2->new_memory($USERNAME);
				$CART2->__SET__('our/mkts','0001KW');
				$CART2->__SET__('our/orderid',$ORDERID);
				# ($o,$oerr) = ORDER->create($USERNAME,'new'=>1,'useoid'=>$ORDERID,'save'=>0,'mkts'=>'0001KW');
				}
			else {
				# ($o,$oerr) = ORDER->new($USERNAME,$ORDERID,new=>0);
				$CART2 = CART2->new_from_oid($USERNAME,$ORDERID);
				}

			#if ((not defined $CART2) || (ref($CART2) ne 'CART2')) {
			#	$CART2 = CART2->new_memory($USERNAME,0);
			#	$CART2->add_history("CART2 order object could not be loaded, created an in memory object",'etype'=>8);
			#	}

			if ((not defined $CART2) || (ref($CART2) ne 'CART2')) {
				# if ((not defined $oerr) || ($oerr eq '')) { $oerr = "Could not instantiate Order OBJ:$ORDERID (reason unknown)"; }
				$XML .= "<ERROR ORDERID=\"$ORDERID\" MSG=\"Invalid CART2 object - reason unknown, very corrupt\"></ERROR>";
				}
			else {
				$CART2->add_history("called WEBAPI::orderProcess::MACRO",etype=>128);

				if ($::XCOMPAT<205) {
					foreach my $CMDSET (@{$CMDS}) {
						if ($CMDSET->[0] eq 'ADDPRIVATE') {
							$CMDSET->[0] = 'SETATTRS';
							$CMDSET->[1]->{'private_notes'} = $CMDSET->[1]->{'note'};
							delete $CMDSET->[1]->{'note'};
							}
						}
					}

				my ($echo) = $CART2->run_macro_cmds($CMDS);
				if ($FUNCTION eq 'XMLBATCH') { $echo++; }	# XMLBATCH always ECHO's
	
				$CART2->order_save();
				if ($is_new) { $CART2->action('create'); }
				if ($echo) { $XML .= $CART2->as_xml($::XCOMPAT); }
				}

			}
		}

	#if (defined $ERROR) {
	#	$PickupTime = -1; 
	#	$XML = "ORDERPROCESS.ERROR-$ERROR";
	#	}
	# print STDERR "XML: $XML\n";

	return($PickupTime,$XML);	
	}




##############################
## 
## sub: hashit
##
## PURPOSE: converts strings from the format <merchant.tag>data</tag> to 
##          a usable hash
##
## returns: HASH reference with key=merchant.tag and value=data
## note: I think this is used by customer - but not sure what for? -bh
##
###############################
sub hashit {
    my ($BUFFER, $HASH) = @_;
	# If we weren't passes a reference to a hash, make a new one
	if (not defined ($HASH)) { $HASH = {}; }
	if ((not defined ($BUFFER)) || ($BUFFER eq '')) { return undef; }

    # first match all the merchant:tag combinations (note this will NOT
    # match </merchant:attrib>
    $BUFFER .= "\n";
    study($BUFFER);

    # split on the end tags.
    my @ar = split(/(.*?)<\/([\w]+)\>(.*?)/s,$BUFFER);
    
	foreach my $KEY (@ar)
		{
		if ($KEY ne "")
			{
			# find the data which matches the KEY
			if ($KEY =~ /.*?([\w]+).*?/is)
				{
				$KEY = $1;
#				print STDERR "KEY IS: [$KEY]\n";
				if ($BUFFER =~ /\<$KEY\>(.*?)\<\/$KEY\>/si)
					{ 
#					print "Adding: $KEY\n";
					$HASH->{lc($KEY)} = &ZOOVY::dcode($1); 
					} else {
					print STDERR "Unbalanced key: $KEY\n";
					}
				} # end of if internal key match
			} # end of if $KEY ne ""
		} # end of foreach $KEY

    return($HASH);
}

################################################################################################################################
##
## sub: merchantSync
## purpose: sends down merchant namespace
##	methods:
##		MERCHANTSYNC/ZML
##		MERCHANTSYNC/XML
##
#=pod
#
#[[SECTION]API: MERCHANTSYNC]
#
#[[CAUTION]]
#This call will be removed in the future, use WEBDBSYNC instead!
#[[/CAUTION]]
#
#[[SUBSECTION]METHOD: MERCHANTSYNC/XML]
#[[SUBSECTION]Response]
#[[HTML]]
#<MerchantSync><tag></tag></MerchantSync>
#[[/HTML]]
#[[/SUBSECTION]]
#[[/SUBSECTION]]
#
#
#[[/SECTION]]
#
#
#=cut
#
sub merchantSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$FUNCTION,$TIMESTAMP) = split(/\//,$XAPI,3);
	$TIMESTAMP = int($TIMESTAMP);

	#my ($nsref) = &ZOOVY::fetchmerchantns_ref($USERNAME,"DEFAULT"); 

	if ($FUNCTION eq 'XML') {
		#my %NS = ();
		#foreach my $k (keys %{$nsref}) {
		#	my ($owner,$attr) = split(/:/,$k);
		#	next if (substr($owner,0,1) eq '_');
		#	$NS{$owner}->{$attr} = $nsref->{$k};
		#	}
		#foreach my $k (keys %NS) {
		#	next if ($k eq 'email');
		#	$XML .= "<$k>\n";
		#	foreach my $x (keys %{$NS{$k}}) {
		#		next if ($x eq '');
		#		$XML .= "<$x>".&ZOOVY::incode($NS{$k}->{$x})."</$x>\n";
		#		}
		#	$XML .= "</$k>\n";
		#	}
		$XML = "<MerchantSync>$XML</MerchantSync>";
		}
	elsif ($FUNCTION eq 'ZML') {
		## doesn't do anything - used to add a "<contents>..</contents>" to the data
		}
	else {
		$PickupTime = -1;
		$XML = "Function must be ZML or XML";	
		}	
	return($PickupTime,$XML);
	}





################################################################################################################################
##
## sub: webdbSync
## purpose: sends down merchant namespace
##	methods:
##		WEBDBSYNC
##		WEBDBSYNC/UPLOAD
##


=pod

[[SECTION]API: WEBDBSYNC]

The webdb holds information specific to a partition, most accounts will only have one partition.

[[SUBSECTION]METHOD: WEBDBSYNC/UPLOAD]
[[SUBSECTION]Request]
[[HTML]]
<RESOURCE>
<PROFILES>
   <email ns="" id=""><![CDATA[...]]></email>
   <email ns="" id=""/></email>   <-- delete
</PROFILES>
</RESOURCE>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: WEBDBSYNC]
[[SUBSECTION]Response]
[[HTML]]
<WEBSITE>
<GLOBAL>
<zid_qbautoadd>
<zid_searchlength></zid_searchlength>
<zid_shipcarriers></zid_shipcarriers>
<zid_qbmsgdisplay></zid_qbmsgdisplay>
<zid_alternative_company_name></zid_alternative_company_name>
<bcsc_exportdir></bcsc_exportdir>
<bcsc_ts></bcsc_ts>
<bcsc_filter></bcsc_filter>
</GLOBAL>
<PROFILES>
<profile ns=""><![CDATA[key1=value1&key2=value2]]></profile>
</PROFILES>
<PARTITIONS>
<WEBDB ID="" PRETTY="" PROFILE="">
<prt_customers></prt_customers>
<prt_navcats></prt_navcats>
.. many other configuration fields ..
</WEBDB>
</PARTITIONS>
<schedule>.. schedule data ..</schedule>
<SCHEDULES>
</SCHEDULES>
<NEWSLETTERS>
<!-- removed 6/22/2011 -->
<newsletter>.. newsletter data..</newsletter>
</NEWSLETTERS>
<SUPPLIERS>
<supplier>
<ID></ID>
<MID></MID>
<USERNAME></USERNAME>
<CODE></CODE>
<PROFILE></PROFILE>
<MODE></MODE>
<FORMAT></FORMAT>
<MARKUP></MARKUP>
<NAME></NAME>
<PHONE></PHONE>
<EMAIL></EMAIL>
<WEBSITE></WEBSITE>
<ACCOUNT></ACCOUNT>
<JEDI_MID></JEDI_MID>
<PARTNER></PARTNER>
<CREATED_GMT></CREATED_GMT>
<LASTSAVE_GMT></LASTSAVE_GMT>
<INIDATA></INIDATA>
<ITEM_NOTES></ITEM_NOTES>
</supplier>
</SUPPLIERS>
</WEBSITE>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[/SECTION]]


=cut

sub webdbSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$FUNCTION,$TIMESTAMP) = split(/\//,$XAPI,3);
	$TIMESTAMP = int($TIMESTAMP);
	

	if ($FUNCTION eq 'UPLOAD') {
		use XML::Parser;
		use XML::Parser::EasyTree;

#		open F, ">/tmp/xml";
#		print F $DATA;
#		close F;
		## <WEBSITE>
		## <PROFILES>
		## 	<email ns=\"\" id=\"\"><![CDATA[...]]></email>
		## 	<email ns=\"\" id=\"\"/></email>   <-- delete
		## </PROFILES>
		##	</WEBSITE>
		$XML::Parser::Easytree::Noempty=1;
		my $p=new XML::Parser(Style=>'EasyTree');
 
		my $tree=$p->parse($DATA);
		$tree = $tree->[0]->{'content'};
		foreach my $node (@{$tree}) {
			next if ($node->{'type'} eq 't');
	
#			use Data::Dumper; print STDERR Dumper($node);

			if ($node->{'name'} eq 'email') {
				# print STDERR Dumper($node);
				my $NS = $node->{'attrib'}->{'ns'};
				my $MSGID = $node->{'attrib'}->{'id'};
				# my $PRT = &ZOOVY::profile_to_prt($USERNAME,$NS);
				my ($PRT) = 0;
				if ($node->{'attrib'}->{'prt'}) {
					$PRT = int($PRT);
					}
			
				require SITE;
				my $SITE = SITE->new( $USERNAME, 'NS'=>$NS, 'PRT'=>$PRT );
				my $params = &ZTOOLKIT::parseparams($node->{'content'}->[0]->{'content'});
				#my ($se) = SITE::EMAILS->new($USERNAME,'*SITE'=>$SITE);
				#my ($success) = $se->save($MSGID,%{$params});
				#$XML .= "<email id=\"$MSGID\" ns=\"$NS\" status=\"success\" errmsg=\"\"/>\n";
				}
			}

		}
	elsif ($FUNCTION eq '') {

		require ZWEBSITE;
		my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
		my ($cached_flags) = ','.$gref->{'cached_flags'}.',';
		#if ($::XCOMPAT<=117) {
		#	$XML .= "<GLOBAL>";
		#	my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,0);
		#	## specific list of override fields.
		#	foreach my $k ('zid_qbautoadd','zid_searchlength','zid_shipcarriers','zid_qbmsgdisplay',
		#		'zid_alternative_company_name','bcsc_exportdir','bcsc_ts','bcsc_filter'
		#		) {
		#		$XML .= "<$k>".&ZOOVY::incode($webdbref->{$k})."</$k>";
		#		}
		#	$XML .= "</GLOBAL>";
		#	}


		if ($::XCOMPAT >= 221) {
			$XML .= "<EMAILS>";
			#require SITE;
			#foreach my $PRT (&ZWEBSITE::prts()) {
			#	my ($SREF) = SITE->new($USERNAME,'PRT'=>$PRT);
			#	require SITE::EMAILS;
			#	my $se = SITE::EMAILS->new($USERNAME,"*SITE"=>$SREF);
			#	foreach my $msgref (@{$se->available()}) {
			#		$XML .= "<email prt=\"$PRT\" id=\"$msgref->{'MSGID'}\"><![CDATA[".&ZTOOLKIT::buildparams($msgref)."]]></email>\n";
			#		}
			#	}
			$XML .= "</EMAILS>";
			}
		else {
			## VERSION 220 and lower uses PROFILE COMPATIBILITY
			$XML .= "<PROFILES>\n";
			my @domains = DOMAIN::list($USERNAME,'HAS_PROFILE'=>1,'DETAIL'=>0);
			my %PRTS = ();
			foreach my $DOMAINNAME (@domains) {
				my ($D) = DOMAIN->new($USERNAME,$DOMAINNAME);
				my ($nsref) = $D->as_legacy_nsref();
	
				next if (defined $PRTS{$D->prt()});
				$PRTS{$D->prt()}++;

				my $PROFILE_COMPATIBILITY = sprintf("#PRT-%d",$D->prt());
				$XML .= "<profile ns=\"$PROFILE_COMPATIBILITY\"><![CDATA[".&ZTOOLKIT::buildparams($nsref)."]]></profile>\n";

				#require SITE;
				#my ($SREF) = SITE->new($USERNAME,'*D'=>$D,'DOMAIN'=>$D->domainname(),'PRT'=>$D->prt());
				#require SITE::EMAILS;
				#my $se = SITE::EMAILS->new($USERNAME,"*SITE"=>$SREF);
				#foreach my $msgref (@{$se->available()}) {
				#	next if (($::XCOMPAT<202) && (length($msgref->{'MSGID'})>10));
				#	next if (($msgref->{'MSGTYPE'} eq 'TICKET') && ($::XCOMPAT < 201));
				#	$XML .= "<email ns=\"$PROFILE_COMPATIBILITY\" id=\"$msgref->{'MSGID'}\"><![CDATA[".&ZTOOLKIT::buildparams($msgref)."]]></email>\n";
				#	}
				}

			$XML .= "</PROFILES>\n";
			}

		#if ($::XCOMPAT<=116) {
		#	## webdb *USED* to be in its own top level set of keys.
		#	my $nsref = &ZOOVY::fetchmerchantns_ref($USERNAME,'DEFAULT');
		#	my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,0);
		#	delete $webdbref->{'dev_sidebar_html'}; # this fucks stuff up.
		#	$webdbref->{'company_logo'} = $nsref->{'zoovy:logo_invoice'};
		#	$webdbref->{'company_name'} = $nsref->{'zoovy:company_name'};
		#	$webdbref->{'company_address1'} = $nsref->{'zoovy:address1'};
		#	$webdbref->{'company_address2'} = $nsref->{'zoovy:address2'};
		#	$webdbref->{'city'} = $nsref->{'zoovy:city'};
		#	$webdbref->{'state'} = $nsref->{'zoovy:state'};
		#	$webdbref->{'country'} = $nsref->{'zoovy:country'};
		#	$webdbref->{'zip'} = $nsref->{'zoovy:zip'};
		#	$webdbref->{'support_email'} = $nsref->{'zoovy:support_email'};
		#	$webdbref->{'support_phone'} = $nsref->{'zoovy:support_phone'};
		#	# nsref->{'zoovy:logo_invoice_xy
		#	foreach my $key (keys %{$webdbref}) {
		#		next if (index($key,'@')>=0);
		#		next if (substr($key,0,1) eq '%');
		#		next if ($key eq '');
		#		next if ($key =~ /^\+/);	## skip +prt field in webdb
		#		$XML .= "<$key>".&ZOOVY::incode($webdbref->{$key})."</$key>\n";
		#		}
		#	}
		#else {

			## XCOMPAT 117+ adds partition support
			$XML .= "<PARTITIONS>\n";
			my @prts = @{&ZWEBSITE::list_partitions($USERNAME)};
			foreach my $prtstr (@prts) {
				my ($prt,$pretty) = split(/\:[\s]*/,$prtstr);
				my $prtinfo = &ZWEBSITE::prtinfo($USERNAME,$prt);

				$XML .= "<WEBDB ID=\"$prt\" PRETTY=\"$pretty\" PROFILE=\"$prtinfo->{'profile'}\">\n";

				$XML .= "<prt_customers>".int($prtinfo->{'p_customers'})."</prt_customers>\n";
				$XML .= "<prt_navcats>".int($prtinfo->{'p_navcats'})."</prt_navcats>\n";

				my $webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,$prt);
				delete $webdbref->{'dev_sidebar_html'}; # this fucks stuff up.

				## required fields:
				## primary_shipper	UPS|FEDEX

				## UPS API:
				##	upsapi_shipper_number	
				##	upsapi_license
				##	upsapi_userid
				## upsapi_password
				
				my $UPS_CONFIG = &ZTOOLKIT::parseparams($webdbref->{'upsapi_config'});
				$webdbref->{'upsapi_shipper_number'} = $UPS_CONFIG->{'.shipper_number'};
				$webdbref->{'upsapi_license'} = $UPS_CONFIG->{'.license'};
				$webdbref->{'upsapi_password'} = $UPS_CONFIG->{'.password'};
				$webdbref->{'upsapi_userid'} = $UPS_CONFIG->{'.userid'};				

				## FEDEX CTS
				## fedexapi_account
				##	fedexapi_meter

				## FEDEX WEBSERVICES
				## fedexapi_hubid
				## fedexapi_userid
				## fedexapi_password
            ## fedexapi_account
            ## fedexapi_meter				

				foreach my $key (keys %{$webdbref}) {	
					next if (index($key,'@')>=0);
					next if (substr($key,0,1) eq '%');
					next if ($key eq '');
					next if ($key =~ /^\+/);	## skip +prt field in webdb
					$XML .= "<$key>".&ZOOVY::incode($webdbref->{$key})."</$key>\n";
					}
				$XML .= "</WEBDB>\n";
				} 
			$XML .= "</PARTITIONS>\n";
		#	}
	
		#if ($cached_flags =~ /,WS,/) {
		   require WHOLESALE;
			my $schedulesref = &WHOLESALE::list_schedules($USERNAME);
			if (scalar(@{$schedulesref})>0) {
				$XML .= "<SCHEDULES>\n";
				foreach my $s (@{$schedulesref}) {
					my $info = &WHOLESALE::load_schedule($USERNAME,$s);
		       	$XML .= &ZTOOLKIT::arrayref_to_xmlish_list([$info],encoder=>'latin1',tag=>'schedule');
		         }
  		 	   $XML .= "</SCHEDULES>\n";
		      }
		#	}

		#if ($cached_flags =~ /,SC,/) {
			## they have supply chain
			require DBINFO;
			my $MID = &ZOOVY::resolve_mid($USERNAME);
			
			$XML .= "<SUPPLIERS>\n";
			my $zdbh = &DBINFO::db_user_connect($USERNAME);
			my $pstmt = "select * from SUPPLIERS where MID=".$zdbh->quote($MID);
			my $sth = $zdbh->prepare($pstmt);
			$sth->execute();
			while ( my $hashref = $sth->fetchrow_hashref() ) {
				delete $hashref->{'MID'};
				delete $hashref->{'USERNAME'};
				delete $hashref->{'ID'};
				next if ($hashref->{'CODE'} eq 'FBA');

				if ($hashref->{'FORMAT'} eq 'FBA') { $hashref->{'FORMAT'} = ''; }
			 	$XML .= &ZTOOLKIT::arrayref_to_xmlish_list([$hashref],encoder=>'latin1',tag=>'supplier');
				}
			$sth->finish();
			$XML .= "</SUPPLIERS>\n";
			&DBINFO::db_user_close();
			# $XML .= &suppliersXML($USERNAME);
		#	}

		$XML = "<WEBSITE>".$XML."</WEBSITE>";
#		open F, ">/tmp/webdb";
#		use Data::Dumper; print F Dumper($XML);
#		close F;
		}
	
	return($PickupTime,$XML);
	}


##
## outputs an xml list of suppliers
##
#=pod
#
#[[SECTION]API: SUPPLIERSYNC]
#
#[[SUBSECTION]METHOD: SUPPLIERSYNC/DOWNLOAD]
#[[SUBSECTION]Response]
#[[HTML]]
#[[/HTML]]
#[[/SUBSECTION]]
#[[/SUBSECTION]]
#
#[[CAUTION]]
#NOTE: these data structures and api calls are likely to change in the future!
#[[/CAUTION]]
#
#[[/SECTION]]
#=cut
#sub suppliersXML {
#	my ($USERNAME) = @_;
#	return($XML);
#	}

################################################################################################################################
##
## sub: inventorySync
## purpose: inventory stuff.
##	methods:
##		INVENTORYSYNC/DOWNLOAD/[timestamp]
##		INVENTORYSYNC/UPLOAD
##		INVENTORYSYNC/UPLOADONLY
##

=pod

[[SECTION]API: INVENTORYSYNC]

[[SUBSECTION]METHOD: INVENTORYSYNC/UPLOADONLY]
[[SUBSECTION]Request]
<li> orderid, luser (logged in user) are optional and will be recorded in the logs.
<li> +1/-1 are incremental updates
<li> =1 is an absolute update.
[[HTML]]
<SKU REF="sku" ORDERID="" LOC="" LUSER="">+1</SKU>
<SKU REF="sku" ORDERID="" LOC="" LUSER="">=1</SKU>
<SKU REF="sku" ORDERID="" LOC="" LUSER="">-1</SKU>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]



[[SUBSECTION]METHOD: INVENTORYSYNC/DOWNLOAD/timestamp]
Returns all inventory records which have changed since the passed timestamp, use 0 for full inventory dumps.
[[SUBSECTION]Response]
[[HTML]]
<INVENTORY TS="">
<SKU ID="" QTY="" RESERVE="" LOC="" ONORDER="" REORDER="">meta properties</SKU>
<SKU ID="" QTY="" RESERVE="" LOC="" ONORDER="" REORDER="">meta properties</SKU>
<SKU ID="" QTY="" RESERVE="" LOC="" ONORDER="" REORDER="">meta properties</SKU>
</INVENTORY>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: INVENTORYSYNC/UPLOAD/timestamp]
This method is an "UPLOADONLY" combined with a "DOWNLOAD".  The upload format is same format as upload only, 
but also returns the inventory that has changed since timestamp (in the same format as DOWNLOAD).
[[/SUBSECTION]]

[[/SECTION]]


=cut

sub inventorySync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$FUNCTION,$TIMESTAMP) = split(/\//,$XAPI,3);
	$TIMESTAMP = int($TIMESTAMP);

	if ($FUNCTION eq 'UPLOADONLY') {
		## note: a blank timestamp will return no values!
		$TIMESTAMP = -1; 
		}

	# open F, ">/tmp/test"; print F "API: $API,$FUNCTION,$TIMESTAMP\nDATA: ".$DATA."\n"; close F;

	require INVENTORY2;
	my ($INV2) = INVENTORY2->new($USERNAME,"*WEBAPI");
	if ((defined $DATA) && ($DATA ne '')) {
		$DATA =~ s/^.*?(\<SKU)/$1/gs;		# strip off INVENTORY tags
		$DATA =~ s/[\n\r]+//g;		# strip out newlines

		foreach my $line (split(/<\/SKU>/s,$DATA)) {
			print STDERR "INPUT LINE: $line\n";
			next unless (substr($line,0,4) eq '<SKU');


			my $ref = '';
			my $qty = '';		
			my $loc = '';
			my $oid = '';
			my $luser = '';
			if ($line =~ /REF=\"(.*?)\"/) { $ref = $1; }
			if ($line =~ /ORDERID=\"(.*?)\"/) { $oid = $1; }
			if ($line =~ /LOC=\"(.*?)\"/) { $loc = $1; }
			if ($line =~ /LUSER=\"(.*?)\"/) { $luser = $1; }
			if ($line =~ /\>(.*?)$/) { $qty = $1; }

			print STDERR "INPUT PARSED QTY=[$qty] REF=[$ref] LOC=[$loc]\n";

			if ((index($qty,'-')>-1) || (index($qty,'+')>-1)) {
				# print STDERR "Found Inventory Plus/Minus [$ref]=[$qty] loc:$loc\n";
				$qty =~ s/[^0-9\+\-]//g;	# strip anything funny
				#&INVENTORY::add_incremental($USERNAME,$ref,'I',$qty,ORDERID=>$oid,LUSER=>$luser);
				#&INVENTORY::set_location($USERNAME,$ref,$loc);
				my ($CMD) = ($qty>=0)?'ADD':'SUB';
				if ($CMD eq 'SUB') { $qty = 0 - $qty; }
				$INV2->skuinvcmd($ref,$CMD,'BASETYPE'=>'SIMPLE','QTY'=>$qty,'NOTE'=>$loc,'luser'=>$luser);
				#if (not defined $TIMESTAMP) {
				#	# LEGACY
				#	my ($actual,$reserve,$loc) = &INVENTORY::fetch_incremental($USERNAME,$ref);
				#	$XML .= "<SKU LOC=\"$loc\" REF=\"$ref\">".$actual."</SKU>";
				#	}
				}
			elsif (index($qty,'=')>-1) {
				# print STDERR "Found Absolute Inventory [$ref]=[$qty]\n";
				$qty = substr($qty,1);
				$INV2->skuinvcmd($ref,'SET','BASETYPE'=>'SIMPLE','QTY'=>$qty,'NOTE'=>$loc,'luser'=>$luser);
				#&INVENTORY::add_incremental($USERNAME,$ref,'U',$qty,ORDERID=>$oid,LUSER=>$luser);
				#&INVENTORY::set_location($USERNAME,$ref,$loc);
				#if (not defined $TIMESTAMP) {
				#	my ($actual, $reserve, $loc) = &INVENTORY::fetch_incremental($USERNAME,$ref);
				#	$XML .= "<SKU LOC=\"$loc\" REF=\"$ref\">$actual</SKU>";
				#	}
				}		
			}
		}

	if ((defined $TIMESTAMP) && ($TIMESTAMP>-1)) {
		#my ($arref,$ts) = &INVENTORY::get_since_timestamps($USERNAME,$TIMESTAMP);
		#$XML = "<INVENTORY TS=\"$ts\">\n";
		#my ($invref,$reserveref,$locref,$onorderref,$reorderref) = &INVENTORY::fetch_incrementals($USERNAME,$arref,undef,1 + 8+16+32+64+128);	
		#foreach my $sku (keys %{$invref}) {
		#	my $meta = '';
		#	#if ($metaref->{$sku} ne '') {
		#	#	my $ref = &ZTOOLKIT::parseparams($metaref->{$sku});
		#	#	$meta = &WEBAPI::hashref_colon_to_dashxml($ref);
		#	#	}
		#	$XML .= "<SKU ID=\"$sku\" QTY=\"$invref->{$sku}\" RESERVE=\"$reserveref->{$sku}\" LOC=\"$locref->{$sku}\" ONORDER=\"$onorderref->{$sku}\" REORDER=\"$reorderref->{$sku}\">".$meta."</SKU>\n";
		#	}	
		#$XML .= '</INVENTORY>';
		my ($TS) = 0;
		# foreach my $row (values %{$INV2->summary('WHERE'=>['TS','GT',$TIMESTAMP]) }) {
		my $INVDETAIL = $INV2->detail('BASETYPE'=>'SIMPLE','WHERE'=>['TS','GT',$TIMESTAMP]);
		foreach my $row ( @{$INVDETAIL} ) {
			$XML .= "<SKU ID=\"$row->{'SKU'}\" QTY=\"$row->{'QTY'}\" RESERVE=\"0\" LOC=\"$row->{'NOTE'}\" ONORDER=\"0\" REORDER=\"0\"></SKU>\n";
			if ($row->{'MODIFIED_GMT'} > $TS) { $TS = $row->{'MODIFIED_GMT'}; }
			}	
		$XML = "<INVENTORY TS=\"$TS\">\n$XML\n</INVENTORY>";
		}
	elsif ($TIMESTAMP == -1) {
		$XML .= '<INVENTORY><!-- empty due to UPLOADONLY request --></INVENTORY>';
		}

	# open F, ">>/tmp/inventory"; print F "<!-- $XAPI\nTIMESTAMP: $TIMESTAMP -->\n"; print F $XML; close F;

	return($PickupTime,$XML);
	}


################################################################################################################################
##
## sub: skulistSync
## purpose: sends down a list of sku's ..
##	methods:
##

=pod

[[SECTION]API: SKULIST]

The methods below return an expanded list of SKU's (stock keeping units) with some details. 
Any product options will have been expanded. 

[[SUBSECTION]METHOD: SKULIST/LISTALL]
[[SUBSECTION]Response]
[[HTML]]
<PRODLIST>
<P ID="pid1"/>
<P ID="pid2"/>
<P ID="pid3"/>
<P ID="pid4"/>
</PRODLIST>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: SKULIST/DOWNLOAD/pid1,pid2,pid3]
[[SUBSECTION]Response]
[[HTML]]
<ZOOVY>
<product name=\"$prod\">
<attribs>
	<zoovy.catalog></zoovy.catalog>
	<zoovy.mfg></zoovy.mfg>
	<zoovy.consigner></zoovy.consigner>
	<zoovy.virtual></zoovy.virtual>
	<zoovy.supplier></zoovy.supplier>
</attribs>
<name></name>
<weight></weight>
<price></price>
<taxable></taxable>
</product>
</ZOOVY>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[/SECTION]]


=cut

sub skulistSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$FUNCTION,$PARAMS) = split(/\//,$XAPI,3);

	require ZWEBAPI;

	if ($FUNCTION eq 'DOWNLOAD') {
		my %attribs = ('zoovy:catalog'=>'zoovy.catalog','zoovy:mfg'=>'zoovy.mfg','zoovy:consigner'=>'zoovy.consigner','zoovy:virtual'=>'zoovy.virtual','zoovy:inv_reorder'=>'zoovy.inv_reorder');
		my @prods = split(/,/,$PARAMS);		# params is a comma separated list of products
		
		$XML = "<ZOOVY>\n";
		my $Prodsref = &PRODUCT::group_into_hashref($USERNAME,\@prods);
		foreach my $P (values %{$Prodsref}) {

			$XML .= sprintf("<product name=\"%s\">\n",$P->pid());
			$XML .= "<web>1</web>\n";

			foreach my $k (keys %attribs) {
				next if (not defined $P->fetch($k));
				$XML .= "<$attribs{$k}>".&ZWEBAPI::xml_incode($P->fetch($k))."</$attribs{$k}>\n";
				}
		
			if ($P->fetch('zoovy:virtual') ne '') { 
				$XML .= "<zoovy.virtual>".$P->fetch('zoovy:virtual')."</zoovy.virtual>\n"; 
				$XML .= "<zoovy.virtual_ship>".$P->fetch('zoovy:virtual_ship')."</zoovy.virtual_ship>\n"; 
				$XML .= "<zoovy.prod_supplier>".$P->fetch('zoovy:prod_supplier')."</zoovy.prod_supplier>\n"; 
				$XML .= "<zoovy.prod_supplierid>".$P->fetch('zoovy:prod_supplierid')."</zoovy.prod_supplierid>\n"; 
				}
		
			## my ($name,$price,$weight) = &ZSKU::calc_sku_info($USERNAME,$prod,$prodsref->{$prod});
	  		## always prepend an @ for virtual products

			if ($P->has_variations('any')) { $XML .= "<haspogs>1</haspogs>"; }

			$XML .= "<name>".&ZWEBAPI::xml_incode($P->fetch('zoovy:prod_name'))."</name>\n";
			$XML .= "<weight>".$P->fetch('zoovy:base_weight')."</weight>\n";
			$XML .= "<price>".$P->fetch('zoovy:base_price')."</price>\n";

			$XML .= "<taxable>".$P->fetch('zoovy:taxable')."</taxable>\n";
 			$XML .= "</product>\n";
			}
		$XML .= "</ZOOVY>";
		}
	elsif ($FUNCTION eq 'LISTALL') {
		if (not defined $PARAMS) { $PARAMS = undef; }
		$XML = '<PRODLIST>';
		foreach my $p (&ZOOVY::fetchproduct_list_by_merchant($USERNAME,$PARAMS)) {
			$p = uc($p);
			$XML .= "<P ID=\"$p\"/>\n";
			}
		$XML .= '</PRODLIST>';
		}

	return($PickupTime,$XML);
	}



################################################################################################################################
##
## sub: navcatSync
## purpose: synchronization of navcats
##	methods:
##		NAVCATSYNC/DOWNLOAD/PRT=0
##		NAVCATSYNC/INCREMENTAL/PRT=0
##		NAVCATSYNC/FULLUPLOAD/PRT=0
##


=pod

[[SECTION]API: NAVCATSYNC]

[[SUBSECTION]METHOD: NAVCATSYNC/DOWNLOAD/PRT=prt]
[[SUBSECTION]Response]
[[HTML]]
<NAVCATINFO PRT="prt">
<NAVCAT NAME="" PRETTY="" TS="0">
<CONTENTS>$PRODUCTS</CONTENTS>
<SORTBY>$SORTBY</SORTBY>
<META><DST>VAL</DST></META>
</NAVCAT>
<NAVCAT NAME="" PRETTY="" TS="0">
<CONTENTS>$PRODUCTS</CONTENTS>
<SORTBY>$SORTBY</SORTBY>
<META><DST>VAL</DST></META>
</NAVCAT>
</NAVCATINFO>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: NAVCATSYNC/INCREMENTAL/PRT=prt]
[[SUBSECTION]Request]
[[HTML]]
<NAVCAT>
<EVENT TYPE="ADD" CAT="safe">pid1,pid2,pid3</EVENT>
<EVENT TYPE="DEL" CAT="safe">pid1</EVENT>
<EVENT TYPE="NUKEPRODUCT">pid1,pid2,pid3</EVENT>
<EVENT TYPE="REMOVE" CAT="safe"></EVENT>
<EVENT TYPE="RENAME" CAT="safe" PRETTY=""></EVENT>
<EVENT TYPE="CREATE" CAT="safe" PRETTY=""></EVENT>
<EVENT TYPE="NUKE" CAT="safe"></EVENT>
</NAVCAT>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: NAVCATSYNC/FULLUPLOAD/PRT=prt]
Desctructive (non-incremental) updates to navigation category tree.
[[SUBSECTION]Request]
[[HTML]]
<NAVCATINFO>
<NAVCAT NAME="" PRETTY="" TS="0">
<CONTENTS>$PRODUCTS</CONTENTS>
<SORTBY>$SORTBY</SORTBY>
<META><DST>VAL</DST></META>
</NAVCAT>
<NAVCAT NAME="" PRETTY="" TS="0">
<CONTENTS>$PRODUCTS</CONTENTS>
<SORTBY>$SORTBY</SORTBY>
<META><DST>VAL</DST></META>
</NAVCAT>
</NAVCATINFO>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[/SECTION]]


=cut


sub navcatSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	require ZWEBAPI;

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$FUNCTION,$PARAMS) = split(/\//,$XAPI,3);
	my $PRT = 0;
	if ($PARAMS ne '') {
		my ($paramsref) = &ZTOOLKIT::parseparams($PARAMS);
		if ($paramsref->{'PRT'}) { $PRT = int($paramsref->{'PRT'}); }
		}

	require NAVCAT;
	require ZTOOLKIT;
	my $NC = NAVCAT->new($USERNAME,PRT=>$PRT);


	if ($FUNCTION eq 'DOWNLOAD') {
		$XML .= "<NAVCATINFO PRT=\"$PRT\">\n";
		foreach my $safe ($NC->paths()) {
			next if ($safe eq '');
			next if (substr($safe,0,1) eq '@');	 # skip @CAMPAIGN navcats

			my ($PRETTY, $CHILDREN, $PRODUCTS, $SORTBY, $METAREF) = $NC->get($safe);
			$PRETTY = &ZWEBAPI::xml_incode($PRETTY);
			$SORTBY = &ZWEBAPI::xml_incode($SORTBY);
			$PRODUCTS = &ZWEBAPI::xml_incode($PRODUCTS);
			$safe = &ZWEBAPI::xml_incode($safe);
			$XML .= "<NAVCAT NAME=\"$safe\" PRETTY=\"$PRETTY\" TS=\"0\">\n";
			$XML .= "<CHILDREN>$CHILDREN</CHILDREN>\n";
			$XML .= "<CONTENTS>$PRODUCTS</CONTENTS>\n";
			$XML .= "<SORTBY>$SORTBY</SORTBY>\n";
			if (defined $METAREF) {
				$XML .= "<META>".&ZWEBAPI::xml_incode(&ZTOOLKIT::buildparams($METAREF))."</META>\n";
				}
			$XML .= "</NAVCAT>\n";
			}
		$XML .= "</NAVCATINFO>\n";
		} 


	if ($FUNCTION eq 'INCREMENTAL') {
		if ($DATA =~ /\<NAVCAT\>(.*?)\<\/NAVCAT\>/s) {
			$DATA = $1;
			}

		my %SORTCATS = ();
		foreach my $event (split('</EVENT>',$1)) {
			$event =~ s/[\n\r]+//g;
			my $TYPE = '';
			if ($event =~ /TYPE\=\"(.*?)\"/s) { $TYPE = $1; }

			if ($TYPE eq 'ADD') {
				print STDERR "EVENT: $event\n";
				if ($event =~ /CAT=\"(.*?)\".*?\>(.*?)$/s) {
					my $ITEMS = $2; my $SAFE = &ZOOVY::dcode($1);
					# Fix a bug in product sync 3.04
					$ITEMS =~ s/ /_/g;
					print STDERR "CAT=[$SAFE] ITEMS=[$ITEMS]\n";
					foreach my $item (split(',',$ITEMS)) { 
						print STDERR "NAVCAT ADD USERNAME=[$USERNAME] PATH=[$SAFE] ITEM=[$item]\n";
						$NC->set($SAFE,insert_product=>$item);
						}
					$SORTCATS{$SAFE}++;
					}
				}
			elsif ($TYPE eq 'DEL') {
				my $NUKEEMPTY = 0;
				if ($event =~ /NUKEEMPTY=\"(.*?)\"/) { $NUKEEMPTY = int($1); }
				if ($event =~ /CAT=\"(.*?)\".*?\>(.*?)$/) {
					my $ITEMS = $2; my $SAFE = &ZOOVY::dcode($1);
					foreach my $item (split(',',$ITEMS)) { 
						print STDERR "NAVCAT DEL USERNAME=[$USERNAME] PATH=[$SAFE] ITEM=[$item]\n";
						$NC->set($SAFE,delete_product=>$item);
						}
					$SORTCATS{$SAFE}++;
					}
				}
			elsif ($TYPE eq 'NUKEPRODUCT') {
				if ($event =~ />(.*?)$/) {
					my $ITEMS = $1; 
					foreach my $item (split(',',$ITEMS)) { 
						$NC->nuke_product($item);
						}
					}
				}
			elsif ($TYPE eq 'REMOVE') {
				if ($event =~ /CAT=\"(.*?)\"/s) {
					my $SAFE = &ZOOVY::dcode($1);
					$NC->nuke($SAFE);
					}
				}
			elsif ($TYPE eq 'RENAME') {
				if ($event =~ /CAT=\"(.*?)\"/s) {
					my $SAFE = $1;
					if ($event =~ /PRETTY=\"(.*?)\"/s) {
						$NC->set($SAFE,pretty=>&ZOOVY::dcode($1));
						}
					$SORTCATS{$SAFE}++;
					}
				}
			elsif ($TYPE eq 'CREATE') {
				if ($event =~ /CAT=\"(.*?)\"/s) {
					my $SAFE = &ZOOVY::dcode($1);
					if ($event =~ /PRETTY=\"(.*?)\"/s) {
						my $PRETTY = &ZOOVY::dcode($1);
						$NC->set( $SAFE, pretty=>$PRETTY );
						}
					$SORTCATS{$SAFE}++;
					}
				}
			elsif ($TYPE eq 'NUKE') {
				print STDERR "Running Nuke!\n";
				$NC->nuke();
				%SORTCATS = ();
				}
			}
		
		foreach my $SAFE (keys %SORTCATS) {
			print STDERR "navcatsync SORTING: [$USERNAME] [$SAFE]\n";
			$NC->sort($SAFE);
			}
		}

	######################################################################
	if ($FUNCTION eq 'FULLUPLOAD') {
		## uploads a directory tree in the same format as "DOWNLOAD"
		$NC->nuke();		# clear out the tree

		require XML::Parser;
		require XML::Parser::EasyTree;
		my $parser = new XML::Parser(Style=>'EasyTree');
		my $tree = $parser->parse($DATA);
		## pop the root node (hopefully it's a NAVCATINFO)
		$tree = $tree->[0]->{'content'};
		foreach my $cat (@{$tree}) {
			next if ($cat->{'type'} ne 'e');
			my $SAFE = $cat->{'attrib'}->{'NAME'};
			my $PRETTY = $cat->{'attrib'}->{'PRETTY'};
			my %props = ();
			$props{'TS'} = $cat->{'attrib'}->{'TS'};
			foreach my $prop (@{$cat->{'content'}}) {
				next if ($prop->{'type'} ne 'e');
				$props{ $prop->{'name'} } = $prop->{'content'}->[0]->{'content'};
				}
			$NC->set( $SAFE, pretty=>$PRETTY, children=>$props{'CHILDREN'}, 
					products=>$props{'CONTENTS'}, 
					sortby=>$props{'SORTBY'},
					metastr=>$props{'META'} );
			}

		}
	
	$NC->save();
	return($PickupTime,$XML);
	}


################################################################################################################################
##
## sub: prodSync
## purpose: synchronize product data
##	methods:
##		PRODSYNC/TIMESTAMPS/[timestamp]		- returns a list of products skus which have changed since a timestamp along 
##														- with the timestamp of the product but NOT the product contents
##		PRODSYNC/DOWNLOADLIST/[prod1,prod2]	- downloads a comma separted list of sku's (note: sku list can also be passed in data)
##		PRODSYNC/DOWNLOADSINCE/[timestamp]	- returns a list of all products which have changed since a specific time (in one big result)
##		PRODSYNC/UPLOAD							- uploads one or more products.
##


=pod

[[SECTION]API: PRODSYNC]

[[SUBSECTION]METHOD: PRODSYNC/TIMESTAMPS/timestamp]
returns a list of products skus which have changed since a timestamp along
with the timestamp of the product but NOT the product contents

[[SUBSECTION]Response]
[[HTML]]
<PRODUCT NAME="pid1" TS="###"/>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: PRODSYNC/DOWNLOADLIST/pid1,pid2,pid3]
[[SUBSECTION]Response]
[[HTML]]
<PRODUCT NAME="pid1" TS="" CAT="">
<zoovy-prod_name></zoovy-prod_name>
..full data..
</PRODUCT>
<PRODUCT NAME="pid2" TS="" CAT="">
<zoovy-prod_name></zoovy-prod_name>
..full data..
</PRODUCT>
<PRODUCT NAME="pid3" TS="" CAT="">
<zoovy-prod_name></zoovy-prod_name>
..full data..
</PRODUCT>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: PRODSYNC/DOWNLOADSINCE/timestamp]
[[SUBSECTION]Response]
See DOWNLOADLIST reponse format.
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: PRODSYNC/UPLOAD]
[[SUBSECTION]Request]
[[HTML]]
<PRODUCT NAME="" CAT="">
<zoovy:prod_name></zoovy:prod_name>
..full data..
</PRODUCT>
[[/HTML]]
[[/SUBSECTION]]
[[SUBSECTION]Response]
[[HTML]]
Length: ###
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]


[[/SECTION]]


=cut


sub prodSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	print STDERR "$USERNAME,$XAPI,$ID,$DATA\n";

	require NAVCAT;

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$FUNCTION,$PARAMS) = split(/\//,$XAPI,3);
	&DBINFO::db_user_connect($USERNAME);

	if ($FUNCTION eq 'TIMESTAMPS') {
		my ($tsref,$catref) = &ZOOVY::build_prodinfo_refs($USERNAME);
		my $out = '';
		my $prod;
		foreach $prod (keys %{$tsref}) { 
			next if ($prod eq '');
			$XML .= "<PRODUCT NAME=\"$prod\" TS=\"$tsref->{$prod}\"/>\n"; 
			}
		}
	elsif ($FUNCTION eq 'DOWNLOADLIST' || $FUNCTION eq 'DOWNLOADSINCE') {
		my @AR = ();
		my ($tsref,$catref) = &ZOOVY::build_prodinfo_refs($USERNAME);
		if ($FUNCTION eq 'DOWNLOADLIST') {
			my $LIST = $PARAMS; 
			if ($LIST eq '') { $LIST = $DATA; }
			@AR = split(',',$LIST);
			}
		elsif ($FUNCTION eq 'DOWNLOADSINCE') {
			my $TS = $PARAMS;
			if (!defined($TS)) { $TS = 0; }
			foreach my $prod (keys %{$tsref}) {
				if (($tsref->{$prod}>$TS) && ($prod ne '')) { push @AR, $prod; }
				}
			}

		my $prod;
		my $ref = &ZOOVY::fetchproducts_into_hashref($USERNAME,\@AR);
		foreach $prod (@AR) {
			if ((not defined $prod) || ($prod eq '')) { print STDERR "Skipping blank/undef prod\n"; next; } ## Added to prevent not defined message -AK 06/19/03
			my $ts  = defined($tsref->{$prod})  ? $tsref->{$prod}  : '' ; ## Added to prevent not defined message -AK 06/19/03
			my $cat = defined($catref->{$prod}) ? $catref->{$prod} : '' ; ## Added to prevent not defined message -AK 06/19/03
			$XML .= "<PRODUCT NAME=\"$prod\" TS=\"$ts\" CAT=\"$cat\">";
			$XML .= &WEBAPI::hashref_colon_to_dashxml($ref->{$prod});
			$XML .= "</PRODUCT>";
			}
		}
	elsif ($FUNCTION eq 'UPLOAD') {
		#my @prods = split('</PRODUCT>',$DATA);

		&ZOOVY::confess($USERNAME,"ran removed/deprecated code\n$DATA",justkidding=>1);

		#my ($prodbuf,$PRODID);
		#foreach my $prodbuf (@prods) {
		#	# split the buffer into three parts.
		#	if ($prodbuf =~ /<PRODUCT.*?NAME="(.*?)"(.*?)>(.*?)$/s) {	


		#		# $1 is the product id. $2 is the trailer (TS="" CAT="") and CONTENTS is everything between the two product tags
		#		my $PRODID = $1;
		#		next if ($PRODID eq '');
		#		my $TRAILER = $2;
		#		my $CONTENTS = $3;

		#		my $cat = undef;
		#		if ($TRAILER =~ /CAT="(.*?)"/) { $cat = $1; }

		#		if (substr($PRODID,0,1) eq '!') {
		#			# delete the product
		#			$PRODID = substr($PRODID,1);		# strip the leading !
		#			&ZOOVY::deleteproduct($USERNAME,$PRODID);
		#			}
		#		else { 
		#			my $ref = &ZOOVY::attrib_handler_ref($CONTENTS);
		#			if ($cat ne '') { $ref->{'zoovy:prod_folder'} = $cat; $cat = undef; } 
		#			&ZOOVY::saveproduct_from_hashref($USERNAME,$PRODID,$ref,$cat)
		#			}
		#		}
		#	}
		#$prodbuf = undef;
		#$PRODID = undef;
		#$XML = "Length: ".length($DATA)."\n\n";
		$XML = "Length: 0\n\n";
		# renable sync, and then flush the buffer
		}
	

	&DBINFO::db_user_close();
	return($PickupTime,$XML);
	}


################################################################################################################################
##
## sub: sendMail
## purpose: sendMail
##	methods:
##		SENDMAIL/
##		<MSG FROM="" TO="" CC="" BCC="" SUBJECT="" BODY="HTML">
##		&lt;HTML&gt;this is the html message&lt;HTML;&gt;
##		</MSG>
##	
##		<MSG OID="" CID="" TO="EMAIL" MSGID="OCREATE"></MSG>
##

=pod

[[SECTION]API: SENDMAIL]

[[SUBSECTION]METHOD: SENDMAIL]
[[SUBSECTION]Request Format 1: Custom HTML message]
[[HTML]]
<MSG CC="" BCC="" NS="" MSGFORMAT="" SUBJECT="" FROM="" ID="" TO="" OID="" CID="" CLAIM="" BODY="HTML"><[CDATA[..]]></MSG>
<MSG CC="" BCC="" NS="" MSGFORMAT="" SUBJECT="" FROM="" ID="" TO="" OID="" CID="" CLAIM="" BODY="HTML"><[CDATA[..]]></MSG>
<MSG CC="" BCC="" NS="" MSGFORMAT="" SUBJECT="" FROM="" ID="" TO="" OID="" CID="" CLAIM="" BODY="HTML"><[CDATA[..]]></MSG>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[/SECTION]]

=cut

sub sendMail {
	my ($USERNAME, $XAPI, $ID, $DATA) = @_;
	
	require XML::Parser;
	require XML::Parser::EasyTree;
	# print STDERR "DATA: $DATA\n";

	my $PickupTime = 0;
	my $parser = new XML::Parser(Style=>'EasyTree');
	my $tree = $parser->parse("<msgs>$DATA</msgs>");
	
	my $SENT = 0;
	my $WARNINGS = 0;
	my $ERRORS = 0;

	$tree = $tree->[0]->{'content'};
	my $XML = '';
	foreach my $msgNode (@{$tree}) {
		next if ($msgNode->{'type'} ne 'e');
		next if ($msgNode->{'name'} ne 'MSG');
#
#		## <MSG CC="" BCC="" NS="" MSGFORMAT="" SUBJECT="" FROM="" ID="" TO="" OID="" CID="" CLAIM=""><[CDATA[..]]></MSG>
#		## <MSG CC="" BCC="" NS="" MSGFORMAT="" SUBJECT="" FROM="" ID="" TO="" OID="" CID="" CLAIM=""><[CDATA[..]]></MSG>
#
		# print STDERR Dumper($msgNode);
		my $body = $msgNode->{'content'}->[0]->{'content'};
		my $ref = $msgNode->{'attrib'};
		if ($body ne '') {
			## override the body!
			$ref->{'MSGBODY'} = $body;
			}

		if (not defined $ref->{'PRT'}) {
			$ref->{'PRT'} = 0;
			}

		if (($ref->{'MSGID'} eq 'ORDER.SHIPPED') || ($ref->{'MSGID'} eq 'BLANK')) {
			my ($O2) = CART2->new_from_oid($USERNAME,$ref->{'OID'});
			require BLAST;
			my ($BLAST) = BLAST->new($USERNAME,$ref->{'PRT'});
			my ($rcpt) = $BLAST->recipient('EMAIL',$ref->{'TO'});
			my ($msg) = $BLAST->msg($ref->{'MSGID'},{'%ORDER'=>$O2});
			$BLAST->send($rcpt,$msg);
			}

		$XML .= qq~<MSG UUID="$ref->{'UUID'}" ERR="0" ERRMSG="ignored messages" />\n~;
		}

	open F, ">>/tmp/emails";
	use Data::Dumper; print F Dumper($tree,$XML);
	close F;

	return(0,$XML);
	}



################################################################################################################################
##
## sub: imageSync
## purpose: synchronize images
##	methods:
##		IMAGESYNC/DELETE/[collection]			- deletes an image collection
##		IMAGESYNC/UPLOAD/[collection]/[filetype] - creates an image collection (be sure to pass the binary data in the data area)
##		IMAGESYNC/FOLDERDETAIL/path|to|folder
##		IMAGESYNC/FOLDERCREATE/path|to|folder
##		IMAGESYNC/FOLDERDELETE/path|to|folder
##


=pod

[[SECTION]API: IMAGESYNC]

[[SUBSECTION]METHOD: IMAGESYNC/DELETE/collection]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: IMAGESYNC/UPLOAD/collection/filetype]
collection is the full path to the image ex: folder1/imagename
[[SUBSECTION]Request]
Base64 encoded binary image, filetype is optional and will be detected.
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: IMAGESYNC/FOLDERCREATE/path|to|folder]
it is possible to call create's in any order, subpaths will be created.
[[SUBSECTION]Response]
[[HTML]]
<Category FID="1234" Name=""/>
<Category FID="-1" Error=""/>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: IMAGESYNC/FOLDERDETAIL/path|to|folder]
[[SUBSECTION]Request]
[[HTML]]
<Folder ImageCount="5" TS="123" Name="Path1" FID="1" ParentFID="0" ParentName="|"/>
<Folder ImageCount="2" TS="456" Name="Path1b" FID="2" ParentFID="1" ParentName="|Path1"/>
<Folder ImageCount="1" TS="567" Name="Path1bI" FID="3" ParentFID="2" ParentName="|Path1|Pathb"/>
<Folder ImageCount="0" TS="789" Name="Path2" FID="4" ParentFID="0" ParentName="|"/>
[[/HTML]]
[[/SUBSECTION]]
[[/SUBSECTION]]

[[SUBSECTION]METHOD: IMAGESYNC/FOLDERDELETE/path|to|folder]
[[/SUBSECTION]]

[[/SECTION]]


=cut


sub imageSync {
	my ($USERNAME,$XAPI,$ID,$DATA) = @_;

	require MEDIA;

	my $XML = '';
	my $PickupTime = 0;
	my ($API,$FUNCTION,@PARAMS) = split(/\//,$XAPI);

	my $STATUS = 0;

	print STDERR "FUNCTION: $API $FUNCTION  [$XAPI]\n";

#  IMAGESYNC/FOLDERDETAIL/DIR1|DIR2
#	-- returns the list of images for a given folder. 
#        <Image Name="abc" TS="1234" Format="jpg" />
#        <Image Name="abc2" TS="1234" Format="jpg" />
#        <Image Name="abc3" TS="1234" Format="jpg" />
#        <Image Name="abc4" TS="1234" Format="jpg" />
#        <Image Name="abc5" TS="1234" Format="jpg" />
#	if ($FUNCTION eq 'FOLDERDETAIL') {
#		my $response = &MEDIA::folderdetail($USERNAME,&MEDIA::from_webapi($PARAMS[0]));
#		foreach my $f (keys %{$response}) {
#			$XML .= "<Image Name=\"$f\" TS=\"$response->{$f}\" />\n";
#			}
#		}

#  IMAGESYNC/FOLDERCREATE/DIR1|DIR2
#	- note you can call these in any order, subpaths will be created.
#	- response:
#	<Category FID="1234" Name=""/>
#	or:
#	<Category FID="-1" Error=""/>
#	elsif ($FUNCTION eq 'FOLDERCREATE') {
#		my $PWD = &MEDIA::mkfolder($USERNAME,&MEDIA::from_webapi($PARAMS[0]));
#		if ($PWD eq '') {
#			$XML = "<Category FID=\"-1\" Error=\"Could not create category $PARAMS[0]\"/>\n";
#			}
#		else {
#			my $FID = &MEDIA::resolve_fid($USERNAME,$PWD);
#			$XML = "<Category FID=\"$FID\" Name=\"".&MEDIA::from_webapi($PWD)."\"/>\n";
#			}
#		}
#
##  IMAGESYNC/FOLDERDELETE/DIR1|DIR2
##	- request the deletion of a category (do not implement this right now)
#	elsif ($FUNCTION eq 'FOLDERDELETE') {
#		&WEBAPI::userlog($USERNAME,"IMAGESYNC.FOLDERDELETE","Deleted $PARAMS[0]");
#		&MEDIA::rmfolder($USERNAME,&MEDIA::from_webapi($PARAMS[0]));
#		}

#  IMAGE/FOLDERLIST
#  	- returns a list of image categories and timestamps for each category
#	<Folder ImageCount="5" TS="123" Name="Path1" FID="1" ParentFID="0" ParentName="|"/>
#	<Folder ImageCount="2" TS="456" Name="Path1b" FID="2" ParentFID="1" ParentName="|Path1"/>
#	<Folder ImageCount="1" TS="567" Name="Path1bI" FID="3" ParentFID="2" ParentName="|Path1|Pathb"/>
#	<Folder ImageCount="0" TS="789" Name="Path2" FID="4" ParentFID="0" ParentName="|"/>
#	elsif ($FUNCTION eq 'FOLDERLIST') {
#		foreach my $fref (@{&MEDIA::folderlist($USERNAME)}) {
#			my $line = '';
#			$fref->{'FName'} = &MEDIA::to_webapi($fref->{'FName'});
#			$fref->{'ParentName'} = &MEDIA::to_webapi($fref->{'ParentName'});
#			foreach my $k (keys %{$fref}) {		
#				$line .= " $k=\"".&ZTOOLKIT::encode($fref->{$k})."\"";
#				}
#			$XML .= "<Folder $line/>\n";
#			}
#		}

#  IMAGE/UPLOAD/DIR1|DIR2/NAME.FORMAT
#	Contents should be 
#	elsif ($FUNCTION eq 'UPLOAD') {
#		my $PWD = &MEDIA::from_webapi($PARAMS[0]);
#		my $filename = $PARAMS[1];
#
#		if ((defined($DATA)) && ($DATA ne '')) {		
#			my $ext = 'PNG'; ## default
#
#			# see if we can get an extension from filename, otherwise assume it's a PNG
#			if (index($filename,'.')>=0) { $ext = substr($filename,rindex($filename,'.')+1); } else { $ext = 'PNG'; }
#
#			print STDERR "Assuming Filename is [$filename]\n";
#			if (index($filename,'.')>=0) {
#				# has file extension
#				$ext = substr($filename,rindex($filename,'.')+1);
#				$filename = substr($filename,0,rindex($filename,'.'));
#				print STDERR "overwriting defaults with best guess [$ext] [$filename]\n";
#				} 
#			else {
#				# no extension?? Hmm..
#				}
#
#			if ($filename) {
#				# Quick sanity
#				# print STDERR "storing $USERNAME - $PWD/$filename.$ext\n";
#				$DATA = decode_base64($DATA);		
#				&MEDIA::store($USERNAME,"$PWD/$filename.$ext",$DATA);
#				}
#			} else {
#				# print STDERR "No data\n";
#			}
#		
#		}
#
##
###  IMAGE/DELETE/DIR1|DIR2/NAME.FORMAT
##
#	elsif ($FUNCTION eq 'DELETE') {
##		my $PWD = &MEDIA::from_webapi($PARAMS[0]);
##		my $filename = lc($PARAMS[1]);		# note: must be lowercased since extension .JPG doesn't work when passed to nuke*
##		&MEDIA::nuke($USERNAME,"$PWD/$filename");
##		&WEBAPI::userlog($USERNAME,"IMAGESYNC.NUKEIMG","Deleted $PWD/$filename");
#		}
#	else {
		$XML = "<Error UNKNOWN_FUNCTION_$FUNCTION/>";
#		}

	return($PickupTime,$XML);
	}



1;
