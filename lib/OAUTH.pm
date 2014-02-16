package OAUTH;

use strict;

use Data::Dumper;
use Digest::SHA1;
use Digest::MD5;
use YAML::Syck;
$YAML::Syck::ImplicitBinary++;
$YAML::Syck::ImplicitUnicode++;
$YAML::Syck::SingleQuote++;		# do not fucking enable this. it has issues with cr/lf 183535

use lib "/backend/lib";
require DBINFO;
require ZTOOLKIT;
require DOMAIN::TOOLS;
require TXLOG;

# developer.github.com/v3/oauth/
# tools.ietf.org/html/draft-ietf-oauth-v2-31#section-10.1


@OAUTH::CLIENTS = (
	{ 'clientid'=>'1pc' },
	{ 'clientid'=>'mvc', 'secret'=>'cheese', 'callback'=>'??',  },		## JT's typo fixed in 201342
	{ 'clientid'=>'zmvc', 'secret'=>'cheese', 'callback'=>'??',  },
	{ 'clientid'=>'droid-inv', 'secret'=>'cheese', 'callback'=>'??',  },
	{ 'clientid'=>'admin', 'secret'=>'cheese', 'callback'=>'??', 'domain'=>'.zoovy.com', 'challenges'=>'captcha|sms|voicepin|email' },
	{ 'clientid'=>'michael', 'secret'=>'cheese', 'callback'=>'??', 'domain'=>'.zoovy.com', 'challenges'=>'email' },
	{ 'clientid'=>'wms-client' },
	);


sub lookup_client {
	my ($clientid) = @_;
	
	my $this = undef;
	foreach my $client (@OAUTH::CLIENTS) {
		if ($client->{'clientid'} eq $clientid) { $this = $client; }
		}
	return($this);
	}


@OAUTH::OBJECTS = (
	'ORG',		# organization
	'CONFIG',	# partition configuration 

	'NAVCAT',
	'ORDER',		# RCULS
	'ORDER/PAYMENT',
	'ORDER/TRACKING',
	'ORDER/ITEMS',
	'INVENTORY',
	'PRODUCT',
	'IMAGE',
	'SYNDICATION',
	'DASHBOARD',
	'DOMAIN',
	'EBAY',
	'AMAZON',
	'GIFTCARD',
	'CUSTOMER',
	'CUSTOMER/PASSWORD',
	'CUSTOMER/WALLET',
	'SUPPLIER',
	'REVIEW',
	'PAGE',
	'MESSAGE',
	'TASK',
	'JOB',
	'HELP',
	'LEGACY',
	);

%OAUTH::ACL_PRETTY = (
	'R' => 'Review',
	'C' => 'Create',
	'U' => 'Update',
	'L' => 'List',
	'S' => 'Search',
	);

sub list_roles {
	my ($USERNAME) = @_;

	## ACL 
	##		R - read/review
	##		C - create
	##		U - update
	##		L - list objects
	##		S - search  (tbd)

	my @ROLES = ();
	push @ROLES, {
		'id'=>'BOSS', 'title'=>'Owner/Operator', 'detail'=>'Reserved for admin user (can perform ownership transfer)',
		'%objects'=>{
			'ORG'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+' },
			'DASHBOARD'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+' },
			'REPORTS'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+' },
			},
		};
	push @ROLES, { 
		'id'=>'SUPER', 'title'=>'Supervisor', 'detail'=>'Access to all areas (except ownership transfer)',
		'%objects'=>{
			'ORDER'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+' },
			'INVENTORY'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+' },
			'PRODUCT'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+' },
			'DASHBOARD'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+' },
			'REPORTS'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+' },
			},
		};
	push @ROLES, { 
		'id'=>'WS1', 'title'=>'Warehouse Shipper', 'detail'=>'Picks, Ships, adds Tracking',
		'%objects'=>{
			'ORDER'=>{ 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+' },
			},
		};
	push @ROLES, { 
		'id'=>'WI1', 'title'=>'Warehouse Inventory', 'detail'=>'Inventory Updates',
		'%objects'=>{
			'INVENTORY'=>{'R'=>'+','U'=>'+','C'=>'+','L'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+','L'=>'+'},
			},
		};
	push @ROLES, { 
		'id'=>'WR1', 'title'=>'Warehouse Returns', 'detail'=>'Processes RMA/Tickets',
		'%objects'=>{
			'ORDER'=>{'R'=>'+','C'=>'+','L'=>'+'},
			'INVENTORY'=>{'R'=>'+','C'=>'+','L'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+','L'=>'+'},
			},
		};
	push @ROLES, { 
		'id'=>'CS1', 
		'title'=>'Customer Service: Trusted', 
		'detail'=>'Looks up orders, tickets, customers, processes payment, issues credits, changes order contents and pricing.',
		'%objects'=>{
			'ORDER'=>{'R'=>'+','C'=>'+','L'=>'+','S'=>'+'},
			'INVENTORY'=>{'R'=>'+','C'=>'+','L'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+','L'=>'+','S'=>'+'},
			},
		};
	push @ROLES, { 
		'id'=>'CC1', 
		'title'=>'Customer Service: Call Center', 
		'detail'=>'Looks up orders, tickets, customers, no payment processing/credits, notes and flagging only.',
		'%objects'=>{
			'ORDER'=>{'R'=>'+','C'=>'+','L'=>'+'},
			'INVENTORY'=>{'R'=>'+','C'=>'+','L'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+','L'=>'+'},
			},
		};
	push @ROLES, { 
		'id'=>'RL1', 
		'title'=>'Retail Lead', 
		'detail'=>'Operate point of sale, supervisor overrides on price',
		'%objects'=>{
			'ORDER'=>{'R'=>'+','C'=>'+','L'=>'+'},
			'INVENTORY'=>{'R'=>'+','C'=>'+','L'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+','L'=>'+'},
			},
		};
	push @ROLES, { 
		'id'=>'RO1', 'title'=>'Retail Operator', 'detail'=>'Operate point of sale',
		'%objects'=>{
			'ORDER'=>{'R'=>'+','C'=>'+','L'=>'+'},
			'INVENTORY'=>{'R'=>'+','L'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+','L'=>'+'},
			},
		};
	push @ROLES, { 
		'id'=>'TS1', 'title'=>'Vendor/Contractor (Read Only)',
		'detail'=>'Gives readonly order, inventory, and product access',
		'%objects'=>{
			'ORDER'=>{'R'=>'+','L'=>'+'},
			'INVENTORY'=>{'R'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+'},
			},
		};
	push @ROLES, { 
		'id'=>'AD1', 'title'=>'App/Web Developer', 'detail'=>'Access to hosting, dns, etc. but no product or orders',
		'%objects'=>{
			'ORDER'=>{'R'=>'+','L'=>'+'},
			'INVENTORY'=>{'R'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+'},
			},		
		};
	push @ROLES, { 
		'id'=>'XXX', 'title'=>'Catalog Manager', 'detail'=>'Access to create, update products, categories.',
		'%objects'=>{
			'ORDER'=>{'R'=>'+','C'=>'+','L'=>'+'},
			'INVENTORY'=>{'R'=>'+','C'=>'+','L'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+','L'=>'+'},
			},		
		};
	push @ROLES, { 
		'id'=>'XYZ', 'title'=>'Marketplace Manager', 'detail'=>'Access to manage syndication, marketplace settings.',
		'%objects'=>{
			'ORDER'=>{'R'=>'+','C'=>'+','L'=>'+'},
			'INVENTORY'=>{'R'=>'+','C'=>'+','L'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+','L'=>'+'},
			'SYNDICATION'=>{'R'=>'+','L'=>'+','C'=>'+'},
			},		
		};

	my %ALL_ROLES = ();
	foreach my $role (@ROLES) {
		$ALL_ROLES{$role->{'id'}} = $role;
		}

	## now load or override any custom roles here

	return(\%ALL_ROLES);
	}



sub serialize_acl { my ($ACL) = @_; return(YAML::Syck::Dump($ACL)); }
sub deserialize_acl { my ($YAML_ACL) = @_; return(YAML::Syck::Load($YAML_ACL)); }


sub build_myacl {
	my ($USERNAME,$MYROLES) = @_;

	my %MYACL = ();

	my $ALLROLES = &OAUTH::list_roles($USERNAME);	
	foreach my $role ( @{$MYROLES} ) {
		$MYACL{'_ROLES'}->{$role}++;
		if ($role eq 'BOSS') {
			foreach my $object (@OAUTH::OBJECTS) {
				$MYACL{ $object } = { 'R'=>'+', 'C'=>'+', 'U'=>'+', 'L'=>'+', 'S'=>'+' };
				}
			}
		#elsif (not defined $MYACL{$role}) {
		#	$MYACL{$role} = {};
		#	}

		foreach my $object (keys %{$ALLROLES->{$role}->{'%objects'}}) {
			if (not defined $MYACL{$object}) { $MYACL{$object} = {}; }
			foreach my $perm (keys %{$ALLROLES->{$role}->{'%objects'}->{$object}}) {
				$MYACL{$object}->{$perm} = $ALLROLES->{$role}->{'%objects'}->{$object}->{$perm};
				}
			}
		}

	return(\%MYACL);
	}





##
## this is necssary to change partitions (since we have to re-authorize)
##
sub randomstring {
	my ($len) = @_;
	require String::Urandom;
	my $obj = String::Urandom->new(LENGTH=>$len,CHARS=>[ qw / a b c d e f g h i j k l m n o p q r s t u v 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z / ] );
	return($obj->rand_string());
	}


sub crypto_session {
	my ($USERNAME,$LUSER,$DEVICEID) = @_;

	# sprintf("%s\n%s\n%s\n",$USERNAME,$LUSER,$DEVICEID);
	}


sub device_initialize {
	my ($USERNAME,$LUSER,$IP,$DEVICE_NOTE) = @_;

	my $DEVICEID = substr(&OAUTH::randomstring(32),0,32);
	my %params = ();
	$params{'MID'} = &ZOOVY::resolve_mid($USERNAME);
	$params{'USERNAME'} = $USERNAME;
	$params{'DEVICEID'} = $DEVICEID;
	$params{'*CREATED_TS'} = 'now()',
	$params{'*LASTUSED_TS'} = 'now()',
	$params{'LASTIP'} = sprintf("%s",$IP);
	$params{'DEVICE_NOTE'} = $DEVICE_NOTE;
	$params{'HISTORY'} = TXLOG->new()->add(time(),"init",'+'=>$IP)->serialize();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	&DBINFO::insert($udbh,'DEVICES',\%params,'verb'=>'insert');
	&DBINFO::db_user_close();

	return($DEVICEID);
	}


##
## 
##
sub build_authtoken {
	my ($USERNAME,$LUSERNAME,$CLIENTINFO,$DEVICEID) = @_;

	# print STDERR  'CLIENTINFO'.Dumper($CLIENTINFO)."\n";

	my ($randomstr) = &OAUTH::randomstring(24);
	my $str = sprintf("%s-%s-%s-%s-%s-%s",lc($USERNAME),lc($LUSERNAME),$CLIENTINFO->{'clientid'},$DEVICEID,$CLIENTINFO->{'secret'},$randomstr);
	# print STDERR "BUILD str:$str\n";
	my $digest = Digest::SHA1::sha1_hex($str);
	return("1|$randomstr|$digest");
	}


##
##
##
sub validate_authtoken {
	my ($USERNAME,$LUSERNAME,$CLIENTINFO,$DEVICEID,$AUTHTOKEN) = @_;

	my ($v,$randomstr,$trydigest) = split(/\|/,$AUTHTOKEN);
	my $str = sprintf("%s-%s-%s-%s-%s-%s",lc($USERNAME),lc($LUSERNAME),$CLIENTINFO->{'clientid'},$DEVICEID,$CLIENTINFO->{'secret'},$randomstr);
#	print STDERR "str:$str\n";
	my $validdigest = Digest::SHA1::sha1_hex($str);
#	print STDERR "validdigest:$validdigest\n";
	return( ($trydigest eq $validdigest)?1:0 );
	}




sub destroy_authtoken {
	my ($USERNAME,$LUSERNAME,$CLIENTINFO,$DEVICEID) = @_;
	
	my ($AUTHTOKEN) = $ENV{'HTTP_X_AUTHTOKEN'};

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	# my $pstmt = "delete from OAUTH_SESSIONS where MID=$MID /* $USERNAME */ and AUTHTOKEN=".$udbh->quote($AUTHTOKEN);
	# my $pstmt = "delete from OAUTH_SESSIONS where MID=$MID /* $USERNAME */ and AUTHTOKEN=".$udbh->quote($AUTHTOKEN);
	my $pstmt = "delete from OAUTH_SESSIONS where MID=$MID /* $USERNAME */ and LUSERNAME=".$udbh->quote($LUSERNAME)." and DEVICEID=".$udbh->quote($DEVICEID);
	print STDERR "$pstmt\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();

	my $memd = undef;
	($memd) = &ZOOVY::getMemd($USERNAME);
	if (defined $memd) {
		$memd->delete("USER:$USERNAME.$LUSERNAME");
		}

	return();
	}


#######################################################
##
## upgrades a session with security keys
##
sub create_authtoken {
	my ($USERNAME,$LUSERNAME,$CLIENTINFO,$DEVICEID, %options) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	$LUSERNAME = uc($LUSERNAME);
	my $ERROR = undef;
	my $dbresult = undef;

	my @MYROLES = ();
	if ($MID<=0) {
		$ERROR = "User: $USERNAME not found";
		}
	elsif ($options{'trusted'}==1) {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select USERNAME,DATA,MID,CACHED_FLAGS,RESELLER from ZUSERS where MID=".$MID." /* $USERNAME */";
		($dbresult) = $udbh->selectrow_hashref($pstmt);
		$dbresult->{'LUSER'} = $LUSERNAME;
		push @MYROLES, 'BOSS';
		&DBINFO::db_user_close();
		}
	elsif ($LUSERNAME eq 'ADMIN') {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select USERNAME,DATA,MID,CACHED_FLAGS,RESELLER from ZUSERS where MID=".$MID." /* $USERNAME */";
		($dbresult) = $udbh->selectrow_hashref($pstmt);
		$dbresult->{'LUSER'} = 'ADMIN';
		if ($dbresult->{'CACHED_FLAGS'} =~ /,ZM,/) { $dbresult->{'HAS_EMAIL'} = 'Y'; }
		push @MYROLES, 'BOSS';
		&DBINFO::db_user_close();
		}
	else {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select ZL.UID as UID, ZL.USERNAME as USERNAME, ZL.LUSER as LUSER, ZL.MID as MID, ZU.CACHED_FLAGS as CACHED_FLAGS, ";
		$pstmt .= " ZL.EXPIRES_GMT, ZL.ROLES as ROLES from ZUSER_LOGIN ZL, ZUSERS ZU where ZU.MID=ZL.MID and ZL.MID=".$MID." /* $USERNAME */ and ZL.LUSER=".$udbh->quote($LUSERNAME);
		($dbresult) = $udbh->selectrow_hashref($pstmt);
		$dbresult->{'LUSER'} = $LUSERNAME;
		&DBINFO::db_user_close();

		@MYROLES = split(/;/,$dbresult->{'ROLES'});

		if (not defined $dbresult) {
			}
		elsif ($dbresult->{'EXPIRES_GMT'} == 0) {
			## no expiration date
			}
		elsif ($dbresult->{'EXPIRES_GMT'} > 0) {
			$dbresult->{'EXPIRES_TS'} = &ZTOOLKIT::timestamp($dbresult->{'EXPIRES_GMT'});
			}
		}

	my ($ACL) = &OAUTH::build_myacl($USERNAME,\@MYROLES);
	my $authtoken = &OAUTH::build_authtoken($USERNAME,$LUSERNAME,$CLIENTINFO,$DEVICEID);

	if (defined $dbresult) {
		my $pstmt = &DBINFO::insert($udbh,'OAUTH_SESSIONS',{
			'USERNAME'=>$USERNAME,
			'LUSERNAME'=>$LUSERNAME,
			'MID'=>$MID,
			'DEVICEID'=>$DEVICEID,
			'CLIENTID'=>sprintf("%s",$CLIENTINFO->{'clientid'}),
			'IP_ADDRESS'=>$ENV{'REMOTE_ADDR'},
			'*CREATED_TS'=>'now()',
			'*EXPIRES_TS'=>'date_add(now(),interval 1 year)',
			'AUTHTOKEN'=>$authtoken,
			'CACHED_FLAGS'=>sprintf("%s",$dbresult->{'CACHED_FLAGS'}),
			'ACL'=>serialize_acl($ACL),
			},key=>['MID','AUTHTOKEN'],verb=>'insert',sql=>1);
		print STDERR "$pstmt\n";
		my ($rv) = $udbh->do($pstmt);

		if (not defined $rv) {
			warn "RESET SESSIONID/SECURITYID due to DB FAILURE\n";
			($authtoken) = (undef);
			}
		}

	&DBINFO::db_user_close();

	return($authtoken);
	}





##
## key structure - 
## 	keys are generated at login and stored in database + memcache
##		
sub verify_credentials {
	my ($USERNAME,$LUSER,$SECURITY,$HASHTYPE,$TRYHASHPASS) = @_;

	my $ERROR = undef;
	$HASHTYPE = uc($HASHTYPE);
	if (($HASHTYPE ne 'MD5') && ($HASHTYPE ne 'SHA1')) {
		$ERROR = "Unsupported hash type";
		}

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my $qtSECURITY = $udbh->quote("$SECURITY");

	my $REALHASHPASS = undef;
	if ($ERROR) {
		}
	elsif ($LUSER eq 'admin') {
		my $pstmt = "select $HASHTYPE(concat(password,$qtSECURITY)) from ZUSERS where MID=".$MID;
		print STDERR $pstmt."\n";
		($REALHASHPASS) = $udbh->selectrow_array($pstmt);
		}
	else {
		my $pstmt = "select $HASHTYPE(concat(password,$qtSECURITY)) from ZUSER_LOGIN where MID=".$MID." and LUSER=".$udbh->quote($LUSER);
		print STDERR $pstmt."\n";
		($REALHASHPASS) = $udbh->selectrow_array($pstmt);
		}

	if (defined $ERROR) {
		}
	elsif (uc($REALHASHPASS) eq uc($TRYHASHPASS)) {
		## compared hash passwords match! yay
		}
	else {
		$ERROR = "Password did not match."; # $HASHTYPE(concat(password,$qtTOKEN))";		
		}
	&DBINFO::db_user_close();
	return($ERROR);
	}




##
## accepts:
##		username
##		luser@username
##		luser@domain.com
##		domain.com
##		
sub resolve_userid {
	my ($userid) = @_;

	my ($luser,$username,$domain) = ('admin','','');
	if (index($userid,'@')>0) {
		($luser,$username) = split(/\@/,$userid);
		}
	elsif (index($userid,'*')>0) {
		($username,$luser) = split(/\*/,$userid);
		}
	else {
		$username = $userid;
		$luser = 'admin';
		}

	return($username,$luser);
	}







1;