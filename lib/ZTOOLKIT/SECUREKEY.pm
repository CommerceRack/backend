package ZTOOLKIT::SECUREKEY;

use Digest::SHA1;
use strict;

use Digest::HMAC_SHA1;
use Crypt::Twofish;
use MIME::Base64;

use lib "/backend/lib";
require DBINFO;




##
## pass in a securekey, generates a digest.
##
sub gen_signature {
	my ($securekey,$data) = @_;
	my $digest = Digest::HMAC_SHA1::hmac_sha1_hex($data, $securekey);
	return($digest);
	}


##
## this will encode using a unique key for the user (based on mid, and internal securekey)
##
sub encrypt {
	my ($USERNAME,$plaintext, $KEYID) = @_;

	if (not defined $KEYID) { $KEYID = 'ZV'; }

	my ($key) = &ZTOOLKIT::SECUREKEY::gen_key($USERNAME,$KEYID);	
	if ($key eq '') { $key = substr($USERNAME,0,6); }

	use Crypt::CBC;
	my $cipher = Crypt::CBC->new(-key=>$key,-cipher => 'Twofish');
	my ($secret) = $cipher->encrypt($plaintext);
	my $b64secret = MIME::Base64::encode_base64($secret,'');
	return($b64secret);	
	}


##
##
##
sub decrypt {
	my ($USERNAME,$b64secret,$KEYID) = @_;

	if ($b64secret eq '') {
		warn "ZTOOLKIT/SECUREKEY.pm received blank b64secret value!\n";
		return(undef);
		}

	if ($KEYID eq '') { $KEYID = 'ZV'; }

	##
	## NOTE: IF we remid a user then the "gen_key" will return a different value
	##

	my ($key) = &ZTOOLKIT::SECUREKEY::gen_key($USERNAME,$KEYID);
	if ($key eq '') { $key = substr($USERNAME,0,6); }

	use Crypt::CBC;
	my $cipher = Crypt::CBC->new(-key=>$key,-cipher => 'Twofish');
	my $secret = MIME::Base64::decode_base64($b64secret);
	my ($plain) = $cipher->decrypt($secret);
	return($plain);	
	}


##
## Yeehaw! converts a decimal number to a base 36. e.g. 0-Z
##
sub to_b36 {
	my ($dec) = @_;
	my @CHARS = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z');
	my $RESULT = '';
	my $BASE = 36;
	while ($dec > 0) {
		$RESULT = $CHARS[ $dec % $BASE ].$RESULT;
		$dec -= ($dec % $BASE); 
		$dec /= $BASE;
		}
	return($RESULT);
	}



## 
## Secure Key Format: 
##		first pair: 01-ZZ = partner id (00 is reserved for extension)
##						note: ZZ = ZOOVY
##		second pair: hex value of the unixtime the account was created modded into base 36. (00-ZZ)
##		third pair: checksum -- here is the formula:
##				the MID of the user + the sum of the ordinal value of all digits
##				modded by 36^2 power and converted into base 36.
##
$ZTOOLKIT::SECUREKEY::KEY_IN = undef;			## cache key in
$ZTOOLKIT::SECUREKEY::KEY_OUT = undef;			## cache key out



sub rsa_key {
	my ($USERNAME,$FILEID) = @_;

	my $KEY = undef;
	my ($path) = &ZOOVY::resolve_userpath($USERNAME);
	if ($FILEID !~ /^([a-z0-9\-\.]+)\.pub$/) {
		print STDERR "FILEID INVALID:$FILEID\n";
		}
	elsif (-f "$path/keys/$FILEID") {
		$/ = undef; open F, "<$path/keys/$FILEID"; ($KEY) = <F>; close F; $/ = "\n";
		}
	else {
		print STDERR "NO FILE: $path/keys/$FILEID\n";
		}
	return($KEY);
	}

sub gen_key {
	my ($USERNAME,$PARTNERID,%options) = @_;

	## normally partnerid would only be two digits but this lets us just pass in the key!
	$PARTNERID = substr($PARTNERID,0,2);

	if ($ZTOOLKIT::SECUREKEY::KEY_IN eq "$USERNAME:$PARTNERID") {
		## short circuit: if we already looked up this key, then return it.
		return($ZTOOLKIT::SECUREKEY::KEY_OUT);
		}

	my $KEY = undef;
	my ($path) = &ZOOVY::resolve_userpath($USERNAME);

	if (-f "$path/$PARTNERID.key") {
		open F, "<$path/$PARTNERID.key"; ($KEY) = <F>; close F;
		$KEY =~ s/[\n\r]+//gs;	# strip trailing cr/lfs'
		}

	if (not defined $KEY) {
		srand( time() ^ ($$ + ($$ << 15)) * (rand()+1) );
		$KEY = Digest::SHA1::sha1_base64( Crypt::CBC->random_bytes( 256 ) );
		#if ($MID>0) {
		#	$KEY = sprintf("%2s%2s",$PARTNERID,&to_b36($CREATEDGMT % (36*36)));
		#	$KEY =~ s/[\s]/0/g;
		#	my $CHECKSUM = $MID;
		#	foreach my $ch (split(//,$KEY)) { $CHECKSUM += ord($ch); }
		#	$KEY .= &to_b36($CHECKSUM % (36*36));
		#	}
		open F, ">$path/$PARTNERID.key";
		print F "$KEY\n";
		close F;
		warn "MISSING KEY $PARTNERID:$USERNAME\n";
		}
	
	## remember the user:partner so we can short circuit later.
	$ZTOOLKIT::SECUREKEY::KEY_IN = "$USERNAME:$PARTNERID";
	$ZTOOLKIT::SECUREKEY::KEY_OUT = $KEY;

	return($KEY);
	}

$ZTOOLKIT::SECUREKEY::WALLETKEY_IN = undef;			## cache bigkey in
$ZTOOLKIT::SECUREKEY::WALLETKEY_OUT = undef;			## cache bigkey out



1;

