package PLUGIN::KOUNT;


##
## update: 20100813 - all our accounts use the same cert. 
##			  20110812 - file was created with .pfx (but it was still .p12 format - no problem)
## 			the last one was stored up on the s drive in s:\users\partners\kount
##				scp it up, and then run this command:
##				/usr/bin/openssl pkcs12 -in $tmpfile -out $tmpfile2 -nodes -passin pass:$pass
##		
##


##
## how KOUNT works:
##
##	webdb
##		kount=>2 - live
##		kount_config => uri delimited .. referenced in object as .variable
##			.merchant
##	
##	pem-file is:
##		$userpath/kount-$PRT-RIS.pem
##		$userpath/kount-$PRT-API.pem
##


## ERROR CODES:
#[5:33:58 PM] Liz Marrone: 201 MISSING_VERS 
#301 BAD_VERS
#202 MISSING_MODE 302 BAD_MODE
#203 MISSING_MERC 303 BAD_MERC
#204 MISSING_SESS 304 BAD_SESS
#205 MISSING_TRAN 305 BAD_TRAN
#211 MISSING_CURR 311 BAD_CURR
#212 MISSING_TOTL 312 BAD_TOTL
#221 MISSING_EMAL 321 BAD_EMAL
#222 MISSING_ANID 322 BAD_ANID
#223 MISSING_SITE 323 BAD_SITE
#231 MISSING_PTYP 324 BAD_FRMT
#232 MISSING_CARD 331 BAD_PTYP
#233 MISSING_MICR 332 BAD_CARD
#234 MISSING_PYPL 333 BAD_MICR
#235 MISSING_PTOK 334 BAD_PYPL
#241 MISSING_IPAD 335 BAD_GOOG
#251 MISSING_MACK 336 BAD_BLML
#261 MISSING_POST 341 BAD_IPAD
#271 MISSING_PROD_TYPE 351 BAD_MACK
#272 MISSING_PROD_ITEM 362 BAD_CART
#273 MISSING_PROD_DESC 371 BAD_PROD_TYPE
#274 MISSING_PROD_QUANT 372 BAD_PROD_ITEM
#275 MISSING_PROD_PRICE 373 BAD_PROD_DESC
#404 UNNECESSARY_PTOK
#500.s Authentication Errors 300.s Invalid Data
#501 UNAUTH_REQ 374 BAD_PROD_QUANT
#502 UNAUTH_MERC 375 BAD_PROD_PRICE
#503 UNAUTH_IP 399 BAD_OPTN
#504 UNAUTH_PASS 400.s Other Data Related Errors
#600.s, 700.s System, Update Errors 
#401 EXTRA_DATA
#601 SYS_ERR 402 MISMATCH_PTYP
#701 NO_HDR 403 UNNECESSARY_ANID
#404 UNNECESSARY_PTOK
#374 BAD_PROD_QUANT
#375 BAD_PROD_PRICE
#399 BAD_OPTN
#301 BAD_VERS
#302 BAD_MODE
#303 BAD_MERC
#304 BAD_SESS
#305 BAD_TRAN
#311 BAD_CURR
#312 BAD_TOTL
#321 BAD_EMAL
#322 BAD_ANID
#323 BAD_SITE
#324 BAD_FRMT
#331 BAD_PTYP
#332 BAD_CARD
#333 BAD_MICR
#334 BAD_PYPL
#335 BAD_GOOG
#336 BAD_BLML
#341 BAD_IPAD
#351 BAD_MACK
#362 BAD_CART
#371 BAD_PROD_TYPE
#372 BAD_PROD_ITEM
#373 BAD_PROD_DESC
#

use LWP::UserAgent;
use lib "/backend/lib";
require ZOOVY;
require ZTOOLKIT;
require ZWEBSITE;
require ZSHIP;
require ZPAY;
use strict;


#$PLUGIN::KOUNT::PEM_FILE = '/backend/lib/PLUGIN/kount-20100813.pem';
#$PLUGIN::KOUNT::PASSWORD = 'sn0wball';
$PLUGIN::KOUNT::PEM_FILE = '/backend/lib/PLUGIN/kount-20120812.pem';
#$PLUGIN::KOUNT::PASSWORD = 'sn0wball2';


#  /**
#   * Hash a credit card number.
#   *
#   * Preserves first six characters of the input so that hashed cards can be
#   * categorized by Bank Identification Number (BIN).
#   *
#   * @param string $plainText String to be hashed
#   * @return Hashed String
#   */
require Digest::SHA1;
require MIME::Base64;





sub has_kount { return(&ZPAY::has_kount(@_)); }

sub generate_khash {
	my ($plainText) = @_;
	$plainText =~ s/[^\d]+//gs;	# remove non-numeric digits
	my $firstSix = substr($plainText,0,6);
	
	# my $key = '4077th hawkeye trapper radar section-8';
	my $key = "=gTLu9Wa0NWZzBichRWYyBiclBHchJHdgUWelt2dhhGIoR3N3ADN";
	$key = MIME::Base64::decode_base64(join("",reverse(split(//,$key))));

	## this is faster: but i'd remove this line if I was going to distribute publically in an SDK
	# my $key = MIME::Base64::encode_base64("4077th hawkeye trapper radar section-8");
   my @a = (
		'0','1','2','3','4','5','6','7','8','9',
		'A','B','C','D','E','F','G','H','I','J',
		'K','L','M','N','O','P','Q','R','S','T',
		'U','V','W','X','Y','Z'
		);
	my $digitsPlease = 14;	# how many digits we want from the credit card

	require Digest::SHA1;
	my $hexdigest = Digest::SHA1::sha1_hex(sprintf("%s.%s",$plainText,$key));
	my $mash = '';
	my $limit = 2 * $digitsPlease;
    $limit = 2 * 14;
	## NOTICE how the function below skips two digits (BIN) 
    for (my $i = 0; $i < $limit; $i += 2) {
		$mash .= $a[ hex( substr($hexdigest, $i, 7) ) % 36 ];
	  	}
	
  	# // a total length of 20! .. 6 + 14 
	return sprintf("%6s%14s",$firstSix,$mash);
	}


##
##
##  perl -e 'use lib "/backend/lib"; use PLUGIN::KOUNT; print PLUGIN::KOUNT::exercise_khash();'
sub exercise_khash {
	my @VALID = ();
	push @VALID, [ 'Visa', '4444444444444448', '444444COSU39DC8BIUK7' ];
	push @VALID, [ 'Visa', '4444444411111111', '444444GGBXSUIX06M8J4' ];
	push @VALID, [ 'MC', 	'5555555555555557', '555555DATDY1C7OWLPR6' ];
	push @VALID, [ 'MC',	'5555555533333333', '555555O0FB4EA71HKIAA' ];
	push @VALID, [ 'Disc', '6011701170117011', '601170WW3OJSTR7GAPOP' ];
	push @VALID, [ 'Disc', '6011621162116211', '601162D5Q2YQJRLO7H2N' ];
	push @VALID, [ 'Disc', '6011608860886088', '601160B6AHPYY74MXZEL' ];
	push @VALID, [ 'Disc', '6011333333333333', '6011334F1JBNP56TRQ9U' ];
	push @VALID, [ 'Amex', '370370370370370', '3703700YAU2YYW1CTFS6' ];
	push @VALID, [ 'Amex', '377777777777770', '377777K6IP496NGO9VML' ];
	push @VALID, [ 'Amex', '343434343434343', '343434RZAMV0XUA8V7LH' ];
	push @VALID, [ 'Amex', '341111111111111', '341111QRL5JM7AU1ZCKC' ];
	push @VALID, [ 'Amex', '341341341341341', '341341ZH0X5CTMYTX66H' ];
	push @VALID, [ 'None', '8888888888888888', '8888884WKE0TTD27BU9H' ];

	require Data::Dumper;
	foreach my $set (@VALID) {
		# print Data::Dumper::Dumper($set);
		my $khash = &generate_khash($set->[1]);
		if ($khash eq $set->[2]) {
			## happy day
			print sprintf("PASSED %5s: %14s %20s\n",$set->[0],$set->[1],$khash);
			}
		else {
			print sprintf("FAILED %5s: %14s expected %20s got: \n",$set->[0],$set->[1],$set->[2],$khash);
			}
		}
	}


## { "id":"1234", "secret":"xyz", "enable":"xyz" } 
sub load_config {
	my ($USERNAME,$PRT) = @_;

	#if (defined $gref->{'%kount'}) {
	#	$cfg = $gref->{'%kount'};		
	#	}
	#if (not defined $cfg) {
	#	my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,0);
	#	if ($webdb->{'kount'}) {
	#		$cfg = &ZTOOLKIT::parseparams($webdb->{'kount_config'});
	#		$cfg->{'enable'} = 1;
	#		}
	#	}

	my $ref = undef;
	my ($userpath) = &ZOOVY::resolve_userpath($USERNAME);
	if ( -f "$userpath/kount-$PRT.json" ) {
		my $json = File::Slurp::read_file("$userpath/kount-$PRT.json");
		$ref = JSON::XS::decode_json($json);
		} 
	return($ref);
	}

##
##
##
sub save_config {
	my ($USERNAME,$PRT,$cfg) = @_;

	my ($userpath) = &ZOOVY::resolve_userpath($USERNAME);
	open F, ">$userpath/kount-$PRT.json";
	print F JSON::XS::encode_json($cfg);
	close F;

	chmod 0666, "$userpath/kount-$PRT.json";
	chown $ZOOVY::EUID,$ZOOVY::EGID, "$userpath/kount-$PRT.json";

	return($cfg);
	}




##
## takes a username, prt and returns the corresponding kountid
sub resolve_kountid {
	my ($USERNAME,$PRT) = @_;
	my $kountcfg = &KOUNT::load_config($USERNAME,$PRT);
	return($kountcfg->{'id'});
	}


##
## takes a database id (or zero for none) and the xml for a notification.
##
#sub process_notification {
#	my ($DBID,$XML) = @_;
#	}


##
## returns the password for the user.
##
sub password {
	my ($self) = @_;

	my $kountcfg = &KOUNT::load_config($self->username(),$self->prt());
	return($kountcfg->{'secret'});
	}



##
## takes a ris response from kount ex: 
# AUTO=D&BRND=VISA&GEOX=JP&KAPT=Y&MERC=200090&MODE=Q&NETW=N&ORDR=2010%2d09%2d2640&REAS=SCOR&REGN=JP_17&SCOR=20&SESS=hSxKMI0mOVxKcTSrXktq0Wkm8&TRAN=69HX012LMZN1&VELO=0&VERS=0320&VMAX=0
## converts it to a valid Zoovy Review status
##	look in ZPAY::review_status
sub RIStoZoovyReviewStatus {
	my ($risref) = @_;

	my $rs = 'XXX';
	if ($risref->{'AUTO'} eq 'D') {
		## DECLINE
		$rs = 'DIS';
		if ($risref->{'REAS'} eq 'SCOR') { $rs = 'DSC'; }
		}
	elsif ($risref->{'AUTO'} eq 'R') {
		## REVIEW
		$rs = 'RIS';
		}
	elsif ($risref->{'AUTO'} eq 'E') {
		## ESCALATED
		$rs = 'EIS';
		}
	elsif ($risref->{'AUTO'} eq 'A') {
		## APPROVED
		$rs = 'AOK';
		}
	else {
		warn "RIStoZoovyReviewStatus result $rs from RIS:".&ZTOOLKIT::buildparams($risref);
		}
	return($rs);
	}


sub kaptcha {
	my ($self,$cartid,$sdomain) = @_;

	my $username = $self->username();
	my $merchant = $self->merchant();
	my $live = int($self->is_live());

	## http://static.zoovy.com/kount/brian/1/200000/s=test.com/c=cartid/logo.gif
	my $html = '';
	if ($cartid eq '*') {
		$html .= "<i>Kount error: temporary cart id is not valid.</i>";
		}
	elsif ($sdomain eq '') {
		$html .= "<i>Kount error: sdomain is blank to function kaptcha</i>";
		}
	else { 
		$html = qq~<iframe width=88 height=31 frameborder=0 scrolling=no 
src="/media/kount/$username/$live/$merchant/s=$sdomain/c=$cartid/logo.htm">
<img width=88 height=31 src="/media/kount/$username/$live/$merchant/s=$sdomain/c=$cartid/kount/logo.gif">
</iframe>
~;
		}
	return($html);
	}


##
## returns a kaptcha.
##
#sub kaptcha {
#	my ($self,$cartid,$sdomain) = @_;
#	# https://tst.kaptcha.com/logo.gif?m=101600&s=1234567890
#	
#	my $merchant = $self->merchant();	
#
#	my $html = '';
#	my $live = $self->is_live();
#	
#	my $url = "https://tst.kaptcha.com/logo.gif?live=$live&m=$merchant&s=$cartid";
#	$html = qq~<img src="$url" width=81 height=31>~;
#
#	return($html);
#	}



##
## pass: 
##		$USERNAME, prt=>$PRT, webdb=>$prt
##
## perl -e 'use lib "/backend/lib"; use PLUGIN::KOUNT; my ($pk) = PLUGIN::KOUNT->new("gssstore"); print $pk->merchant()."\n";'
sub new {
	my ($class,$USERNAME,%options) = @_;

	my ($PRT) = int($options{'prt'});
	my $self = {};
	
	$self->{'USERNAME'} = $USERNAME;
	$self->{'PRT'} = $PRT;
	bless $self, 'PLUGIN::KOUNT';

	#my $webdbref = $options{'webdb'};
	#my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	my ($cfg) = &PLUGIN::KOUNT::load_config($USERNAME);

	## 0 = disable, 1 = enable, 2 = test mode.
	if (defined $cfg) {
		$self->{'ENABLE'} = int($cfg->{'enable'});
		# my $pref = &ZTOOLKIT::parseparams($webdb->{'kount_config'});
		foreach my $k (keys %{$cfg}) {
			next if ($k eq 'enable');
			$self->{".$k"} = $cfg->{$k};
			}
		}
	
	return($self);
	}

## returns 0=no, 1=yes, 2=test
sub is_live { return($_[0]->{'ENABLE'}); }
sub merchant { return($_[0]->{'.merchant'}); }
sub username { return($_[0]->{'USERNAME'}); }


##
## there are two types of files - "ris" and "api"
##		however we can also look for "ristest" and "apitest" based on the result of is_live()
##
sub pem_file {
	my ($self,$TYPE) = @_;

	return($PLUGIN::KOUNT::PEM_FILE);

#	my ($PRT) = int($self->{'PRT'});
#	my ($path) = &ZOOVY::resolve_userpath($self->{'USERNAME'});
#	$TYPE = lc($TYPE);
#
#	if ($self->is_live()==2) {
#		## ristest or apitest
#		$TYPE .= 'test';
#		}
#
#	my $file = "$path/kount-$PRT-$TYPE.pem";
#	return($file);
	}

##
##
##
sub gen_cert {
	#  openssl pkcs12 -in perl.p12 -out perl.pem nodes
	# http://www.mail-archive.com/libwww@perl.org/msg04397.html
	}

##
## pass in ORDER
##
sub doRISRequest {
	my ($self, $CART2) = @_;

	my ($MID) = &ZOOVY::resolve_mid($self->{'USERNAME'});

	$ENV{'HTTPS_DEBUG'} = 1;
	$ENV{'HTTPS_VERSION'} = '3';

	# client certificate support
#	$ENV{HTTPS_CERT_FILE} = '/backend/lib/PLUGIN/perl.pem';
#	$ENV{HTTPS_KEY_FILE}  = '/backend/lib/PLUGIN/perl.pem';
#	$ENV{HTTPS_PKCS12_FILE}     = '/backend/lib/PLUGIN/perl.p12';
#	$ENV{HTTPS_PKCS12_PASSWORD} = 'asdf';
	my ($pemfile) = $self->pem_file('RIS');
	$ENV{HTTPS_CERT_FILE} = $pemfile;
	$ENV{HTTPS_KEY_FILE} = $pemfile;

	my $ua = LWP::UserAgent->new();
	$ua->timeout(10);
	# $ua->env_proxy;

	my %form = ();
	## HEADER FIELDS
	# $form{'VERS'} = '0320'; 6/13/11
	$form{'VERS'} = '0420';
	## Q = Inquiry Record
	## P = Phone record
	## U = Update Record
	## X = Update Record (w/response)
	## E = Error
	$form{'MODE'} = 'Q';
	## -- use MODE 'U' for updating from the payment gateway
	## 	not payment or avs - use Q for new payment.
	
	# FRMT N/A Specify the format of the RIS response (not case sensitive):
	#. FRMT = XML
	#. FRMT = JSON
	#. FRMT = YAML


	$form{'MERC'} = $self->merchant();
	# SESS Y 32 Session ID - must be unique over 30-day span and can contain any combination of letters, 
	#	numbers or underscores from 1 to 32 characters
	$form{'SESS'} = $CART2->cartid();
	# SITE Y 08 The Website ID for either the default website or merchant created website. 
	# The Website ID for the site to be used must be entered exactly as it appears in the Website ID
	# column on the DMC/Websites page of the AWC.
	$form{'SITE'} = 'default'; # $o->prt();
	if ($self->{'.multisite'} eq 'prt') {
		$form{'SITE'} = sprintf("prt%d",$CART2->prt());
		}
	elsif ($self->{'.multisite'} eq 'sdomain') {
		my ($sdomain) = $CART2->in_get('our/domain');		# $o->get_attrib('sdomain');
		if ($sdomain =~ /^(.*?)\./) { $sdomain = $1; }
		$sdomain = substr($sdomain,0,8); 
		$form{'SITE'} = $sdomain;
		}


	$form{'ORDR'} = $CART2->oid();

	## Payment Amounts
	# CURR Y 03 Currency, USD/EUR/CAD/AUD/JPY/HKD/NZD
	$form{'CURR'} = 'USD';

	# TOTL Y 12 Total auth amount in pennies of CURR, 0-9999999
	# $form{'TOTL'} = sprintf("%d",$o->get_attrib('order_total')*100);
	$form{'TOTL'} = sprintf("%d",$CART2->in_get('sum/order_total')*100);
	my $stuff2 = $CART2->stuff2();
	my $i = 0;
	foreach my $item (@{$stuff2->items()}) {
		my $stid = $item->{'stid'};
		$form{'CASH'} += sprintf("%d",$item->{'cost'}*100);

		next if (substr($stid,0,1) eq '%');	# skip promotions
		next if ($item->{'is_promo'});

		# PROD_TYPE[ ] Y 1-255 High level description of the item, such as TV or laptop, input as a string.
		$form{sprintf("PROD_TYPE[%d]",$i)} = uc($item->{'%attribs'}->{'zoovy:catalog'});
		if ($form{sprintf("PROD_TYPE[%d]",$i)} eq '') {
			$form{sprintf("PROD_TYPE[%d]",$i)} = 'GENERIC';
			}
		# PROD_ITEM[ ] Y 1-255 Typically the SKU number for the item, input as a string.
		$form{sprintf("PROD_ITEM[%d]",$i)} = $stid;
		# PROD_DESC[ ] Y 0-255 Specific description of the item, such as 42 inch plasma, input as a string.
		$form{sprintf("PROD_DESC[%d]",$i)} = $item->{'prod_name'};
		# PROD_QUANT[ ] Y Long The quantity of the item being purchased, input as an integer.
		$form{sprintf("PROD_QUANT[%d]",$i)} = $item->{'qty'};
		# PROD_PRICE[ ] Y Long The price per unit in pennies, input as an integer.
		$form{sprintf("PROD_PRICE[%d]",$i)} = sprintf("%d",$item->{'base_price'}*100);

		$i++;
		}

	# UDF[NUMBER]=value N 1-255 Can contain numbers, negative signs, and decimal points.
	# UDF[ALPHA-NUMERIC]=value N 1-255 Can contain letters, numbers, or both.
	# UDF[DATE]=value N Max 20
	# Formatted as yyyy-mm-dd or yyyy-mm-dd hh:mi:ss. hh is a 24-hour format.
	# UDF[AMOUNT]=value N 1-255 Can contain integers only. No decimal points, signs, or symbols.

	# For the other examples, PROMO_CODE and AD_SOURCE labels are Alpha-Numeric data types, LAST_PURCHASE
	# is one of the two accepted Date formats, and PRICE is an Amount data type. The Amount type cannot
	# contain decimal points or special symbols like the dollar sign, so all prices must be expressed in whole
	# numbers.
	# Errors: If you pass in a label that doesn.t exist or associate the wrong data type with a label, a 399
	# BAD_OPTN error code will be returned.
	
	## Customer Entered Order Information
	if ($form{'MODE'} eq 'P') {
		$form{'ANID'} = $CART2->in_get('bill/phone');
		}
	else {
		$form{'EMAL'} = $CART2->in_get('bill/email');
		}

	# NAME 64 Customer or company name	
	$form{'NAME'} = sprintf("%s %s",$CART2->in_get('bill/firstname'),$CART2->in_get('bill/lastname'));
	if ($form{'NAME'} =~ /^[\s]*$/) {
		$form{'NAME'} = $CART2->in_get('bill/company');
		}

	# DOB 10 Date of birth formatted YYYY-MM-DD
	# GENDER 1 M or F

	# BPREMISE 256 Bill-to premises address (UK)
	# 	For 192.com: It is recommended that you pass in Address Line 1 with premise and street information if you are
	# 	using the 192.com service to make the results in the response more accurate.
	# SPREMISE 256 Ship-to premises address (UK)
	# BSTREET 256 Bill-to street (UK)
	# SSTREET 256 Ship-to street (UK)

	#if ($o->get_attrib('customer_id')>0) {
	#	my ($CID) = $o->get_attrib('customer_id');
	#	# UNIQ 32 Customer-unique ID or cookie set by merchant aka Customer ID
	#	$form{'UNIQ'} = $CID;
	#	my ($C) = CUSTOMER->new($o->username(),'PRT'=>$o->prt(),'CID'=>$CID,'INIT'=>0x1);
	#	if ($C->get('INFO.CREATED_GMT')>0) {
	#		# EPOC 10 Epoch when UNIQ value was set
	#		$form{'EPOC'} = $C->get('INFO.CREATED_GMT'); 
	#		}
	#	}
	if ($CART2->in_get('customer/cid')) {
		my ($CID) = $CART2->in_get('customer/cid');
		# UNIQ 32 Customer-unique ID or cookie set by merchant aka Customer ID
		$form{'UNIQ'} = $CID;
		my ($C) = CUSTOMER->new($CART2->username(),'PRT'=>$CART2->prt(),'CID'=>$CID,'INIT'=>0x1);
		if ($C->get('INFO.CREATED_GMT')>0) {
			# EPOC 10 Epoch when UNIQ value was set
			$form{'EPOC'} = $C->get('INFO.CREATED_GMT'); 
			}
		}
	# DRIV 32 US driver.s license number

	# UAGT 1024 Customer User-Agent HTTP header

	$form{'S2NM'} = sprintf("%s %s",$CART2->in_get('ship/firstname'),$CART2->in_get('ship/lastname'));
	# $form{"S2EM"} 



	foreach my $x ('B','S') {
		## B2A1 S2A1  bill_address1, ship_address1
		my ($addr) = ($x eq 'B')?'bill':'ship';
		if (defined $CART2->in_get("$addr/address1")) {
			$form{$x.'2A1'} = $CART2->in_get("$addr/address1");	
			}
		## B2A2 S2A2
		if (defined $CART2->in_get("$addr/address2")) {
			$form{$x.'2A2'} = $CART2->in_get("$addr/address2");	
			}
		
		## B2CI S2CI
		$form{$x.'2CI'} = $CART2->in_get("$addr/city");	
		## B2ST S2ST
		$form{$x.'2ST'} = $CART2->in_get("$addr/region");	
		## B2PC S2PC
		$form{$x.'2PC'} = $CART2->in_get("$addr/postal");	
		if ($form{$x.'2PC'} eq '') {
			$form{$x.'2PC'} = $CART2->in_get("$addr/postal");	
			}
		## B2CC S2CC
		## country code (ISO-3166-1 Alpha 2)
		$form{$x.'2CC'} = $CART2->in_get("$addr/countrycode");
		if (length($form{$x.'2CC'})==2) {
			## already got it from countrycode in order.
			}
		elsif ($CART2->in_get("$addr/countrycode") eq '') {
			$form{$x.'2CC'} = 'US';
			}
		#else {
		#	$form{$x.'2CC'} = &ZSHIP::fetch_country_shipcodes($CART2->in_get("$addr/country'));
		#	}
		## B2PN S2PN
		$form{$x.'2PN'} = $CART2->in_get("$addr/phone");
		}

	my $paytype = undef; 	# $o->get_attrib('payment_method');
	my $payrec = undef;
	my $acctref = undef;

	if (scalar(@{$CART2->payments()})==1) {
		($payrec) = @{$CART2->payments()};
		$paytype = $payrec->{'tender'};
		}
	else {
		$CART2->add_history("Could not accurately determine payment type (due to none or mixed types)",luser=>"*KOUNT");
		}

#. If PTYP=PYPL PayPal PayerID field
#. If PTYP=CARD MOD 10 validated card
#number (no test cards)
#. If PTYP=MICR MICR line from check
#. If PTYP=GOOG Google Checkout account
#ID
#. If PTYP=BLML Bill Me Later account number
#. If PTYP=GDMP Green Dot MoneyPak submitted
#with KHASH

	if ($payrec->{'acct'} ne '') {
		$acctref = &ZPAY::unpackit($payrec->{'acct'});
		}

	if ($paytype eq 'CREDIT') {
		# PENC Y only if hashing a credit card number
		# 20 PENC = KHASH: Allows merchants to use a Kount
		# proprietary hash to pre-hash a credit card number before passing it to Kount.

		if ($acctref->{'KH'}) {
			# $form{'PTOK'} = $acctref->{'KH'};
				$form{'PTYP'} = 'CARD';
			$form{'PENC'} = 'KHASH';
			$form{'PTOK'} = $acctref->{'KH'};
			}
		elsif ($acctref->{'CC'}) {
			$form{'PTYP'} = 'CARD';
			$form{'PTOK'} = $acctref->{'CC'};
			}
		elsif ($acctref->{'CM'}) {
			$form{'PTYP'} = 'NONE';
			# $form{'PTOK'} = $acctref->{'CM'};
			}
		# $form{'PTOK'} = '4111111111111111';
		}
	elsif (($paytype eq 'PAYPALEC') || ($paytype eq 'PAYPAL')) {
		$form{'PTYP'} = 'PYPL';
		$form{'PTOK'} = $acctref->{'PI'}; # $payrec->{'auth'}; # $o->get_attrib('cc_bill_transaction');
		if ((not defined $acctref->{'PI'}) || ($acctref->{'PI'} eq '')) {
			$CART2->add_history("Kount Error: Paypal PayerID was not found",etype=>2+8,'luser'=>'*KOUNT');
			}
		}
	elsif ($paytype eq 'ECHECK') {
		##
		$form{'PTYP'} = 'CHEK';
		my $acctref = &ZPAY::unpackit($payrec->{'acct'});
		$form{'PTOK'} = sprintf("%s%s",$acctref->{'ER'},$acctref->{'EA'}); 
		# $o->get_attrib('echeck_aba_number').$o->get_attrib('echeck_acct_number');
		## DRIV 32 US driver.s license number
		}
	elsif ($paytype eq 'GOOGLE') {
		## GOOGLE
		$form{'PTYP'} = 'GOOG';
		$form{'PTOK'} = $acctref->{'GA'};	 # Google Checkout Account ID
		if ((not defined $acctref->{'GA'}) || ($acctref->{'GA'} eq '')) {
			$CART2->add_history("Kount Error: Google Checkout Account ID was not found",etype=>2+8,luser=>'*KOUNT');
			}
		}
	elsif ($paytype eq 'AMZSPAY') {
		## AMAZON
		$form{'PTYP'} = 'NONE';
		}
	else {
		## other?
		$form{'PTYP'} = 'NONE';
		}



	if ( $CART2->in_get('flow/kount') ne '') {
		## supported payment gateways and stuff will set kount specific fields in order (e.g. AVS)
		## AVSZ 01 Bankcard AVS ZIP CODE reply:
		## M = Match
		## N = No match
		## X = Unavailable or unsupported
		## AVST 01 Bankcard AVS STREET ADDRESS reply:
		## M = Match
		## N = No match
		## X = Unavailable or unsupported
		## CVVR 01 Bankcard CVV/CVC/CVV2 reply:
		## M = Match
		## N = No match
		## X = Unavailable or unsupported
		foreach my $kv (split(/\|/,$CART2->in_get('flow/kount'))) {
			my ($k,$v) = split(/\=/,$kv,2);
			$form{$k} = $v;
			}
		}

	## SD - same day, ND - next day, 2D - 2day, ST - standard
	$form{'SHTP'} = 'ST';	# standard
	if ( (my $carrier = $CART2->in_get("sum/shp_carrier")) ne '') {
		require ZSHIP;
		if (my $shipinfo = &ZSHIP::shipinfo($carrier)) {

			if (not $shipinfo->{'expedited'}) {
				}
			elsif ($shipinfo->{'is_fastest'}) {
				$form{'SHTP'} = 'SD'; 
				}
			elsif ($shipinfo->{'is_nextday'}) {
				$form{'SHTP'} = 'ND'; 
				}
			else {
				$form{'SHTP'} = '2D';
				}
			}
		}

	if ($CART2->in_get("cart/ip_address") ne '') {
		## orders created on desktop don't have an IPAD
		$form{'IPAD'} = $CART2->in_get("cart/ip_address");
		}

	# AUTH: A = Approved by issuer D = Declined by issuer
	# MACK: Merchant has acknowledged receipt of order and customer expects order will ship: Y/N
	my ($paystatus) = $CART2->in_get("flow/payment_status");
	if ((substr($paystatus,0,1) eq '0') || (substr($paystatus,0,1) eq '1')) {
		$form{'AUTH'} = 'A';
		}
	else {
		$form{'AUTH'} = 'D';
		}

	my ($reviewstatus) = $CART2->in_get("flow/review_status");
	if (substr($reviewstatus,0,1) eq 'A') {
		## approved
		$form{'MACK'} = 'Y';
		}
	elsif (substr($reviewstatus,0,1) eq 'R') {
		$form{'MACK'} = 'Y';
		}
	elsif (substr($reviewstatus,0,1) eq 'E') {
		$form{'MACK'} = 'N';
		}
	elsif (substr($reviewstatus,0,1) eq 'D') {
		$form{'MACK'} = 'N';
		}
	else {
		$form{'MACK'} = 'N';
		}



	my $udbh = &DBINFO::db_user_connect($self->{'USERNAME'});
	my $pstmt = &DBINFO::insert($udbh,'BS_CALLS_LOG',{
		'USERNAME'=>$self->{'USERNAME'},
		'MID'=>$MID,
		'*CREATED'=>'now()',
		'SESSION'=>time(),
		'PARTNER'=>'KT',
		},debug=>1+2);
	# print STDERR $pstmt."\n";
	&DBINFO::db_user_close();

	my %RESULT = ();
	foreach my $k (keys %form) { if (not defined $form{$k}) { delete $form{$k}; } }

	my $URL = 'https://risk.kount.net';
	if ($self->is_live()==2) {
		$URL = 'https://risk.test.kount.net';
		## test mode stores test parameters.
		$CART2->add_history("Kount Sent: ".&ZTOOLKIT::buildparams(\%form),etype=>128,luser=>"*KOUNT");
		}
	my $response = $ua->post($URL,\%form);
	if ($response->is_success) {
		# print STDERR $response->content;  # or whatever
		foreach my $line (split(/[\n\r]+/,$response->content())) {
			my ($k,$v) = split(/=/,$line,2);
			$RESULT{$k} = $v;
			}
		}
	else {
		$RESULT{'ERRO'} = 1;	## defines a zoovy error.
		$RESULT{'ERR'} = $response->status_line();
		}

	if ($self->is_live()==2) {
		## test mode outputs test parameters.
		use Data::Dumper;
		print STDERR Dumper(\%RESULT);
		}
	
	open F, ">>/dev/shm/kount.txt";
	print F Dumper($self->{'USERNAME'},$CART2->oid(),\%form,\%RESULT);
	close F;


	return(\%RESULT);
	}




1;

