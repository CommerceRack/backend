#!/usr/bin/perl -w

## use thawedit to edit freeze/thaw

use strict;

use DBI;
use Fcntl;
use Data::Dumper;
use File::Copy;
use warnings;
use Storable;
use Storable qw(freeze thaw);
use Digest::MD5 qw(md5 md5_hex md5_base64);
use File::Temp;

use lib "/httpd/modules";
use DBINFO;

no warnings 'once';

my $ref = undef;
my %params = ();
foreach my $arg (@ARGV) {
   #if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
   my ($k,$v) = split(/=/,$arg);
   $params{$k} = $v;
   }


if (defined $params{'file'}) {
	## default to type file if just file= is specified.
	$params{'type'} = 'file';
	}
elsif (defined $params{'pid'}) {
	## default to type file if just file= is specified.
	$params{'type'} = 'pid';
	}
elsif (defined $params{'profile'}) {
	## default to type profile if just file= is specified.
	$params{'type'} = 'profile';
	}
elsif (defined $params{'luser'}) {
	## default to type "luser" if just luser is specified.
	$params{'type'} = 'luser';
	}

if (scalar(@ARGV)==0) {
	}
elsif (defined $params{'type'}) {
	## we're good here.
	}
elsif ($ARGV[0] eq 'o') {
	use lib "/httpd/modules";
	require ZOOVY;
	$params{'type'} = 'order';
	$params{'user'} = $ARGV[1];
	$params{'order'} = $ARGV[2];
	#my ($year, $month, $id) = split('-', $ARGV[2]);
	#$params{'type'} = 'file';
	#$params{'file'} = &ZOOVY::resolve_userpath($ARGV[1])."/ORDERS/$year-$month/$id.bin";	
	}
elsif ($ARGV[0] eq 'cart' || $ARGV[0] eq 'c') {
	$params{'type'} = 'cart';
	$params{'user'} = $ARGV[1];
	$params{'id'} = $ARGV[2];
	}
elsif ($ARGV[0] =~ /(.*?)\:(.*?)$/) {
	$params{'type'} = 'file';
	$params{'user'} = $ARGV[1];
	$params{'file'} = &ZOOVY::resolve_userpath($1).'/'.$2;
	}
elsif ($ARGV[0] eq 'n') {
	$params{'type'} = 'file';
	$params{'user'} = $ARGV[1];
	$params{'file'} = &ZOOVY::resolve_userpath($ARGV[1])."/navcats.bin";
	}
elsif ($ARGV[0] eq 'w') {
	$params{'type'} ='file';
	$params{'user'} = $ARGV[1];
	$params{'file'} = &ZOOVY::resolve_userpath($ARGV[1])."/webdb.bin";
	}
#elsif ($ARGV[0] eq 'm') {
#	$params{'type'} ='file';
#	$params{'user'} = $ARGV[1];
#	$params{'file'} = &ZOOVY::resolve_userpath($ARGV[1])."/merchant.bin";
#	}
elsif ($ARGV[0] eq 'd') {
	$params{'type'} ='domain';
	$params{'user'} = $ARGV[1];
	$params{'domain'} = $ARGV[2];
	}
elsif ($ARGV[0] eq 'p') {
	$params{'type'} = 'pid';
	$params{'user'} = $ARGV[1];
	$params{'pid'} = $ARGV[2];
	}
elsif ($ARGV[0] eq 'g') {
	$params{'type'} = 'global';
	$params{'user'} = $ARGV[1];
	}
elsif (-f $ARGV[0]) {
	$params{'type'} = 'file';
	$params{'user'} = $ARGV[1];
	$params{'file'} = $ARGV[0];
	}
else {
	die("Unknown option!");
	}


if ($params{'backup'}) {
	&DBINFO::use_backup();
	}

if ((scalar(keys %params)==0) || (not defined $params{'type'})) {
	print qq~
----------------------------------------
	binedit.pl usage:
----------------------------------------

	type=syndication user=username dst=DSTCODE
	type=profile user=username profile=profilename 
	type=file file=somepath/to/file.bin
	type=pid pid=PRODUCT user=username
	type=navcat user=username prt=#
	type=global user=username
	type=page user=username path=.category prt=# 
	type=page user=username path=pagename prt=# 
	type=supplier user=username code=code
	type=syn user=username code=GOO prt=# ns=profilename
	type=luser	user=username 
	type=order user=username order=2009-01-1234
	type=ordercreate user=username order=2009-01-1234
	type=sog user=username sog=A0
	type=domain user=username domain=domain

some old legacy syntax that still works:
	o user #orderid		-- loads an order
	c user cartid			-- loads a cart
	c user cartid 1			-- loads a cart
	n user 					-- loads the partition 0 navcats for a user
	p user productid		-- loads the product id
	d user domain			-- loads the domain
	user:path/file.bin	-- loads a file from a given users directory
	w user					-- loads a webdb for partition 0 for a user.
~;
	die();
	}
elsif ($params{'type'} eq 'page') {
	## page username pagename #partition
	require PAGE;
	($ref) = PAGE->new($params{'user'},$params{'path'},PRT=>int($params{'prt'}));
	}
elsif ($params{'type'} eq 'supplier') {
	## supplier username code
	require SUPPLIER;
	($ref) = SUPPLIER->new($params{'user'},$params{'code'});
	}
elsif ($params{'type'} eq 'ebayprofile') {
	require EBAY2::PROFILE;
	($ref) = EBAY2::PROFILE::fetch($params{'user'},$params{'prt'},$params{'code'});
	}
elsif ($params{'type'} eq 'pid') {
	## supplier username code
	($ref) = PRODUCT->new($params{'user'},$params{'pid'});
	}
elsif ($params{'type'} eq 'syndication') {
	## supplier username code
	require SYNDICATION;
	($ref) = SYNDICATION->new($params{'user'},$params{'ns'},$params{'dst'},PRT=>$params{'prt'});
	}
elsif ($params{'type'} eq 'sog') {
	require POGS;
	($ref) = POGS::load_sogref($params{'user'},$params{'sog'});
	}
elsif ($params{'type'} eq 'navcat') {
	require NAVCAT;
	($ref) = NAVCAT->new($params{'user'},PRT=>$params{'prt'});
	}
elsif ($params{'type'} eq 'global') {
	require ZWEBSITE;
	($ref) = &ZWEBSITE::fetch_globalref($params{'user'});
	}
elsif ($params{'type'} eq 'profile') {
	$ref = &ZOOVY::fetchmerchantns_ref($params{'user'},$params{'profile'});
	}
elsif ($params{'type'} eq 'luser') {
	require LUSER;
	($ref) = LUSER->new($params{'user'},$params{'luser'});
	}
elsif ($params{'type'} eq 'domain') {
	require DOMAIN;
	($ref) = DOMAIN->new($params{'user'},$params{'domain'});
	}
elsif (($params{'type'} eq 'order') || ($params{'type'} eq 'ordercreate')) {
	require CART2;
	if ($params{'amz'} ne '') {
		require ORDER::BATCH;
		my $r = ORDER::BATCH::report($params{'user'},EREFID=>$params{'amz'});
		if (scalar(@{$r})==0) {
			die("Could not lookup amz=$params{'amz'}");
			}
		else {
			$params{'order'} = $r->[0]->{'ORDERID'};
			}
		}
	my $IS_NEW = 0;
	my $TMPOID = $params{'order'};
	if ($params{'type'} eq 'ordercreate') { $IS_NEW++; $TMPOID = ''; }
	($ref,my $err) = CART2->new_from_oid($params{'user'},$TMPOID,useoid=>$params{'order'},new=>$IS_NEW);
	}
elsif ($params{'type'} eq 'cart') {
	if ((not defined $params{'prt'}) && ($params{'user'} =~ /.([\d])+$/)) {
		## user.prt syntax
		($params{'user'},$params{'prt'}) = split(/\./,$params{'user'});
		}
	if (not defined $params{'prt'}) { 
		warn "prt not defined - using 0\n"; 
		}
	$params{'prt'} = int($params{'prt'});
	require CART2;
	$ref = CART2->new_persist($params{'user'},$params{'prt'},$params{'id'});
	}
elsif (not defined $params{'file'}) {
	print "\n    INCORRECT USAGE -- try \"binedit.pl\" with no parameters to see help.\n\n";
	exit;
	}




print STDERR "FILENAME: $params{'file'}\n";


my $editor = undef;
if (not defined $editor) {
	if (defined $ENV{'EDITOR'}) {
		$editor = $ENV{'EDITOR'};
		}
	else {
		$editor = 'joe';
		}
	}

if (defined $ref) {
	## not a real file.. it's an object!
	}
elsif (-f $params{'file'}) {
	$params{'file'} =~ m/(.*)/; # untaint so perl doesn't bitch when running in suid
	$params{'file'} = $1;
	}
else {
	die "DB file does not exist!\n";
	}

$ENV{'PATH'} = '/usr/local/sbin:/usr/sbin:/sbin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin';
$ENV{'BASH_ENV'} = '/root/.bashrc';

my $tmpfile = $params{'file'};
if (defined $ref) {
	warn "Dumping object to tmpfile!";
	$tmpfile = File::Temp::tmpnam();
	}
elsif ($< ne 0) { 
	warn "WARN: should be run as root!\n"; 
	$tmpfile = File::Temp::tmpnam();
	}

print "Editor is set to '$editor'\n";

print "Opening BIN $params{'file'} file in read-only mode\n";

my $dump = undef;
if (defined $ref) {
	print "Dumping object to file\n";
	$dump = Dumper($ref);
	}
else {
	print "Dumping input to file\n";
	my $xref = retrieve $params{'file'};
	#print Dumper(\%TEMP_AR)."\n\n";
	$dump = Dumper($xref);

	print "Copying original DB file to backup $params{'file'}.bak\n";
	copy($params{'file'},"$params{'file'}.bak");
	}

print "Saving the dumped DB file to $tmpfile.dmp\n";
open DUMP, ">$tmpfile.dmp" or die "Could not open dumped DB file $tmpfile.dmp for writing\n";
print DUMP $dump;
close DUMP;

my $before_digest = Digest::MD5::md5_hex($dump);

print "Opening in editor of choice (if its not the editor you want, specify it as the second arg on the command line)\n";
print "Do not save the file if you do not wish the DB file to be overwritten with changes (the unmodified original version will be saved back)\n";
if ($> != $<) { $editor = "/usr/bin/joe"; }
system($editor,"$tmpfile.dmp");


print "Loading the newly edited version of the dumped DB file $tmpfile.dmp\n";
$/ = undef; # Set the input separator to nothing so we can load the whole file in at once.
open DUMP, "$tmpfile.dmp" or die "Could not open edited dumped DB file $tmpfile.dmp for reading\n";
my $dump_edit = <DUMP>; # This should load up %TEMP_AR
close DUMP;

my $after_digest = Digest::MD5::md5_hex($dump_edit);
print "Before Digest: $before_digest\n";
print "After Digest: $after_digest\n";

if ($before_digest eq $after_digest) {
	die("Digests appear to be the same, no reason to save");
	exit;
	}

if (($< eq 0) || ($> eq 0)) {
	my $VAR1 = undef;
	print "Evaluating the newly edited version of the dumped DB file\n";
	$dump_edit =~ /^(.*)$/s;
	$dump_edit = $1; # untaint 
	unless (eval $dump_edit) { 
		die "Edited dumped DB file failed perl evaluation!\n\n Error: $@\n"; 
		}
	#no warnings;
	if (not defined $VAR1) {
		die("\$VAR1 was not initialized.. file was not saved!");
		}

	if (not defined $ref) {
		print "Saving the new version of the DB file\n";
		chown('nobody.nobody',$params{'file'});
		chmod(0666,$params{'file'});
		Storable::nstore $VAR1, $params{'file'};
		## just make sure we don't have a copy floating around in memcache
		my ($memd) = &ZOOVY::getMemd($params{'user'});
		$memd->flush_all();
		}
	elsif ($params{'type'} eq 'profile') {
		&ZOOVY::savemerchantns_ref($params{'user'},$params{'profile'},$VAR1);
		}
	elsif ($params{'type'} eq 'luser') {
		print "saving LUSER\n";
		bless $VAR1, ref($ref); 
		$VAR1->{'changed'}++;
		$VAR1->save();
		}
	elsif ($params{'type'} eq 'cart') {
		print "saving CART";
		bless $VAR1, ref($ref);
		$VAR1->cart_save('force'=>1);
		}
	elsif ($params{'type'} eq 'syndication') {
		print "saving SYNDICATION\n";
		bless $VAR1, ref($ref); 
		$VAR1->{'_CHANGES'}++;
		$VAR1->save();
		}
	elsif ($params{'type'} eq 'order') {
		bless $VAR1, ref($ref);
		$VAR1->order_save();
		}
	elsif ($params{'type'} eq 'domain') {
		bless $VAR1, ref($ref);
		$VAR1->save();
		}
	elsif ($params{'type'} eq 'global') {
		bless $VAR1, ref($ref);
		&ZWEBSITE::save_globalref($params{'user'},$VAR1);
		}
	elsif (($params{'type'} eq 'navcat') || ($params{'type'} eq 'page') || 
		($params{'type'} eq 'supplier') || ($params{'type'} eq 'syndication')) {
		print "blessing VAR1..\n";
		bless $VAR1, ref($ref); 
		$VAR1->{'_MODIFIED'}++;
		print "Saving!\n";
		$VAR1->save();
		}
	elsif ($params{'type'} eq 'pid') {
		print "Saving $params{'user'} $params{'pid'}\n";
		bless $VAR1, ref($ref);
		$VAR1->{'@UPDATES'} = [ 'manual-edit' ];
		$VAR1->save();
		# &ZOOVY::saveproduct_from_hashref($params{'user'},$params{'pid'},$VAR1);
		}
	}
else {
	print "Not root, won't save uid=$< euid=$>\n";
	}
