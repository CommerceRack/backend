package ZTOOLKIT::ENCRYPT;

use Crypt::CBC;
use Storable qw(lock_store lock_retrieve);

use lib '/httpd/zoovy';
require ZOOVY;

require Exporter;
@ISA = qw(Exporter);

# Exported by default
@EXPORT = qw(
	string_encrypt string_decrypt new_cryptkey
	secret_keys secret_exists secret_set secret_get secret_delete
	secret_load secret_save secret_purge
	load_keyfile make_keyfile
);
# Allowable to be exported to foreign namespaces
@EXPORT_OK = ();
# These are the logical groupings of exported functions
%EXPORT_TAGS = (); 

my $DEBUG = 0;

########################################
# STRING ENCRYPT
# DESCRIPTION: Takes in a scalar and outputs an encrypted string
# ACCEPTS: Merchant ID, an unencrypted Value and optionally a string represending a 128-bit random
#          cryptographic key (defualts to using the merchant's already specified one)
# RETURNS: A stringified version of the encrypted results.
# NOTES: Undefs and blank strings as values are one in the same to this function
sub string_encrypt {
	my ($merchant_id,$value,$cryptkey) = @_;
	require MIME::Base64;
	$DEBUG && &msg("secret_encrypt called ($merchant_id,$value)");
	if (not defined $cryptkey) {
		$cryptkey = &load_keyfile($merchant_id);
		$DEBUG && &msg("secret_encrypt(): using default merchant cryptkey: $cryptkey");
	}
	else {
		$DEBUG && &msg("secret_encrypt(): using passed cryptkey: $cryptkey");
	}
	if (defined $value && $value ne '') {
		my $cipher = Crypt::CBC->new($cryptkey,'Twofish2');
		my $encrypted = $cipher->encrypt($value);
		$DEBUG && &msg("secret_encrypt(): encrypted value");
		my $encoded = &MIME::Base64::encode_base64($encrypted);
		$DEBUG && &msg("secret_encrypt(): encoded value");
		return $encoded;
	}
	else {
		$DEBUG && &msg("secret_encrypt(): value is blank, not encrypting/encoding");
		return '';
	}
	
}

########################################
# STRING DECRYPT
# DESCRIPTION: Takes in an ecrypted string and outputs a scalar
# ACCEPTS: Merchant ID, an encrypted Value and optionally a string represending a 128-bit random
#          cryptographic key (defualts to using the merchant's already specified one)
# RETURNS: The decrypted value
# NOTES: Undefs and blank strings as values are one in the same to this function
sub string_decrypt {
	my ($merchant_id,$value,$cryptkey) = @_;
	require MIME::Base64;
	$DEBUG && &msg("secret_decrypt called ($merchant_id,$value)");
	if (not defined $cryptkey) {
		$cryptkey = &load_keyfile($merchant_id);
		$DEBUG && &msg("secret_decrypt(): using default merchant cryptkey: $cryptkey");
	}
	else {
		$DEBUG && &msg("secret_decrypt(): using passed cryptkey: $cryptkey");
	}
	if (defined $value && $value ne '') {
		my $cipher = Crypt::CBC->new($cryptkey,'Twofish2');
		my $decoded = &MIME::Base64::decode_base64($value);
		$DEBUG && &msg("secret_decrypt(): decoded value");
		my $decrypted = $cipher->decrypt($decoded);
		$DEBUG && &msg("secret_decrypt(): decrypted value");
		return $decrypted;
	}
	else {
		$DEBUG && &msg("secret_decrypt(): value is blank, not decrypting/decoding");
		return '';
	}
	
}

########################################
# NEW CRYPTKEY
# DESCRIPTION: Makes a new key used for encryption and decryption
# ACCEPTS: Nothing
# RETURNS: A hex string representation of a random 128-bit cryptographic key
sub new_cryptkey {
	$DEBUG && &msg("new_cryptkey called");
	my $newkey = '';
	for (1..32) { $newkey .= (0..9,'A'..'F')[rand 16]; } 
	$DEBUG && &msg("new_cryptkey(): new key is $ZSECRET::cryptkeys{$merchant_id}");
	return $newkey;
}

########################################
# SECRET KEYS
# DESCRIPTION: "keys" seems ambiguous here, so I just want to clarify that I mean keys in the sense of
#               perl hash keys (like the "keys" function), not referring to encryption keys
# ACCEPTS: Merchant ID
# RETURNS: An array of keys in the merchant's secret stash
sub secret_keys {
	my ($merchant_id) = @_;
	$DEBUG && &msg("secret_keys called ($merchant_id)");
	my ($hash,$dhash) = &secret_load($merchant_id);
	return (keys %{$hash});
}

########################################
# SECRET EXISTS
# DESCRIPTION: Does a key exist?
# ACCEPTS: Merchant ID and a Key
# RETURNS: True or false depending on whether the key exists in the merchant's stash
sub secret_exists {
	my ($merchant_id,$key) = @_;
	$DEBUG && &msg("secret_keys called ($merchant_id,$key)");
	my ($hash,$dhash) = &secret_load($merchant_id);
	return ((exists $hash->{$key} && $hash->{$key} ne '') ? 1 : 0 );
}

########################################
# SECRET SET
# DESCRIPTION: Set an entry in the a merchant's secret stash
# ACCEPTS: Merchant ID, a Key, and a Value
# RETURNS: The result of the assignment
# NOTES: Undefs and blank strings as values are one in the same to this function
sub secret_set {
	my ($merchant_id,$key,$value) = @_;
	$DEBUG && &msg("secret_set called ($merchant_id,$key,$value)");
	my ($hash,$dhash) = &secret_load($merchant_id);
	$dhash->{$key} = $value;
	if (defined $value && $value ne '') {
		$DEBUG && &msg("secret_set(): non-blank value, encrypting");
		my $cipher = Crypt::CBC->new(&load_keyfile($merchant_id),'Twofish2');
		my $encrypted = $cipher->encrypt($value);
		return ($hash->{$key} = $encrypted);
	}
	else {
		$DEBUG && &msg("secret_set(): blank value, not encrypting");
		return ($hash->{$key} = '');
	}
}

########################################
# SECRET GET
# DESCRIPTION: Get an entry in the stash (be aware that this decrypts every time its called)
# ACCEPTS: Merchant ID and a Key
# RETURNS: The value of the Key requested
# NOTES: Undefs and blank strings as values are one in the same to this function
sub secret_get {
	my ($merchant_id,$key) = @_;
	$DEBUG && &msg("secret_get called ($merchant_id,$key)");
	my ($hash,$dhash) = &secret_load($merchant_id);
	if (defined $dhash->{$key}) {
		$DEBUG && &msg("secret_get(): using already decrypted value from cache");
		return ($dhash->{$key});
	}
	if (defined $hash->{$key} && $hash->{$key} ne '') {
		$DEBUG && &msg("secret_get(): non-blank value, decrypting");
		my $cipher = Crypt::CBC->new(&load_keyfile($merchant_id),'Twofish2');
		my $decrypted = $cipher->decrypt($hash->{$key});
		$dhash->{$key} = $decrypted;
		return ($decrypted);
	}
	else {
		$DEBUG && &msg("secret_get(): blank value, not decrypting");
		$dhash->{$key} = '';
		return '';
	}
}

########################################
# SECRET DELETE
# DESCRIPTION: Remove a key from a merchant's secret stash
# ACCEPTS: Merchant ID, and a Key
# RETURNS: The results of the delete function
sub secret_delete {
	my ($merchant_id,$key) = @_;
	$DEBUG && &msg("secret_delete called ($merchant_id,$key)");
	my ($hash,$dhash) = &secret_load($merchant_id);
	delete $dhash->{$key};
	return (delete $hash->{$key});
}

########################################
# SECRET LOAD
# DESCRIPTION: Loads the secret stash (from RAM, or from disk if it hasn't been loaded already)
# ACCEPTS: Merchant ID
# RETURNS: A reference to the hash loaded from the storable on disk
sub secret_load {
	my ($merchant_id) = @_;
	#my $DEBUG = 0;
	$DEBUG && &msg("secret_load called ($merchant_id)");
	if (defined $ZSECRET::hashes{$merchant_id}) {
		$DEBUG && &msg("secret_load(): using already cached secret stash");
		return ($ZSECRET::hashes{$merchant_id},$ZSECRET::dhashes{$merchant_id});
	}
	$DEBUG && &msg("secret_load(): loading merchant secret stash");
	my $filename = &ZOOVY::resolve_userpath($merchant_id).'/secret.stor';
	if (-e $filename) { $ZSECRET::hashes{$merchant_id} = lock_retrieve($filename); }
	else { $ZSECRET::hashes{$merchant_id} = {}; } # Empty hashref 
	$ZSECRET::dhashes{$merchant_id} = {}; # Decrypted versions cache, Empty hashref until changes are made
	return ($ZSECRET::hashes{$merchant_id},$ZSECRET::dhashes{$merchant_id});
}

########################################
# SECRET SAVE
# DESCRIPTION: Writes a merchant's secret stash that is in RAM to disk.
# ACCEPTS: Merchant ID
# RETURNS: The results of the store operation
sub secret_save {
	my ($merchant_id) = @_;
	$DEBUG && &msg("secret_save called ($merchant_id)");
	my ($hash,$dhash) = &secret_load($merchant_id); # Just a precautionary measure if we haven't loaded the stash yet
	lock_store($hash,&ZOOVY::resolve_userpath($merchant_id).'/secret.stor');
	$DEBUG && &msg("secret_save(): file saved");
}

########################################
# SECRET PURGE
# DESCRIPTION: Removes all merchant stashes and keyfiles from RAM
#              (use this each time if you're looping over a BUNCH of merchants or something,
#              so you don't run out of RAM).  You WILL lose informtion if you don't flush
#              via secret_save()
# ACCEPTS: Merchant ID
# RETURNS: Nothing
sub secret_purge {
	my ($merchant_id) = @_;
	$DEBUG && &msg("secret_nuke called ($merchant_id)");
	%ZSECRET::hashes = undef;
	%ZSECRET::dhashes = undef;
	%ZSECRET::cryptkeys = undef;
	return;
}

########################################
# LOAD KEYFILE
# DESCRIPTION: This loads a keyfile for a merchant.  If a keyfile doesn't exist, it makes a new one.
# ACCEPTS: A Merchant ID
# RETURNS: The key for that merchant
sub load_keyfile {
	my ($merchant_id) = @_;
	#my $DEBUG = 0;
	$DEBUG && &msg("load_keyfile called ($merchant_id)");
	if (not defined $ZSECRET::cryptkeys{$merchant_id}) {
		$DEBUG && &msg("load_keyfile(): attempting to load keyfile");
		if (open (CRYPTKEY, &ZOOVY::resolve_userpath($merchant_id).'/secret.key')) {
			$ZSECRET::cryptkeys{$merchant_id} = <CRYPTKEY>;
			close CRYPTKEY;
			$ZSECRET::cryptkeys{$merchant_id} =~ s/[^A-F0-9]//gs;
			$DEBUG && &msg("load_keyfile(): loaded keyfile");
		}
		else {
			$DEBUG && &msg("load_keyfile(): unable to load, returning a new keyfile");
			return &make_keyfile($merchant_id);
		}
	}
	else {
		$DEBUG && &msg("load_keyfile(): using cached keyfile");
	}
	$DEBUG && &msg("load_keyfile(): returning $ZSECRET::cryptkeys{$merchant_id}");
	return $ZSECRET::cryptkeys{$merchant_id};
}

########################################
# MAKE KEYFILE
# DESCRIPTION: This makes a new keyfile for a merchant.  If it can't make one for some reason, it dies
# ACCEPTS: A Merchant ID
# RETURNS: The new key for that merchant
sub make_keyfile {
	my ($merchant_id) = @_;
	$DEBUG && &msg("make_keyfile called ($merchant_id)");
	my	$newkey = new_cryptkey(); 
	if (open (CRYPTKEY, '>'.&ZOOVY::resolve_userpath($merchant_id).'/secret.key')) {
		print CRYPTKEY $newkey;
		$ZSECRET::cryptkeys{$merchant_id} = $newkey;
		return $newkey;
	}
	else {
		die 'Unable to create merhcant keyfile';
	}
}

########################################
# MSG
# Description: Prints an error message to STDERR (the apache log file)
# Accepts: An error message as a string, or a reference to a variable (if a reference,
#          the name of the variable must be the next item in the list, in the format
#          that Data::Dumper wants it in).  For example:
#          &msg("This house is ON FIRE!!!");
#          &msg(\$foo=>'*foo');
#          &msg(\%foo=>'*foo');
# Returns: Nothing

sub msg {
	my $head = 'ZSECRET: ';
	while ($_ = shift(@_)) {
		if (ref) { require Data::Dumper; $_ = Data::Dumper->Dump([$_],[shift(@_)]); }
#		print STDERR $head, join("\n$head",split(/\n/,$_)), "\n";
	}
}

1;
