package OAUTH;

use strict;

use Data::Dumper;
use Digest::SHA1;
use Digest::MD5;
use YAML::Syck;
$YAML::Syck::ImplicitBinary++;
$YAML::Syck::ImplicitUnicode++;
$YAML::Syck::SingleQuote++;		# do not fucking enable this. it has issues with cr/lf 183535

use lib "/httpd/modules";
require DBINFO;
require ZTOOLKIT;
require DOMAIN::TOOLS;
require TXLOG;

# developer.github.com/v3/oauth/
# tools.ietf.org/html/draft-ietf-oauth-v2-31#section-10.1


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
	'FAQ',

	'SYNDICATION',
	'PROJECT',
	'BLAST', 'RSS', 'REPORT', 'WMS',

	'PLATFORM',
	'TICKET','CAMPAIGN',
	'DASHBOARD',
	'DOMAIN',
	'EBAY',
	'AMAZON',
	'GIFTCARD',
	'CUSTOMER',
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
	'C' => 'Create',
	'U' => 'Update',
	'L' => 'List',
	'S' => 'Search',
	'R' => 'Review',		## in 201403 this will become "R" = "Remove"
	'D' => 'Delete',		## in 201403 this will become "D" = "Detail"
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
			'DOMAIN'=>{ 'L'=>'+' },
			'ORG'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'DASHBOARD'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'REPORTS'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			},
		};

	push @ROLES, {
		'id'=>'TECHSUPPORT', 'title'=>'Technical Support', 'detail'=>'Access to almost everything',
		'%objects'=>{
			'DOMAIN'=>{ 'L'=>'+' },
			'ORDER'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'INVENTORY'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'PRODUCT'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'DASHBOARD'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'REPORTS'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'ORG'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },		
			'CONFIG'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'NAVCAT'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'ORDER'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },	
			'ORDER/PAYMENT'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'ORDER/TRACKING'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'ORDER/ITEMS'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'INVENTORY'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'PRODUCT'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'IMAGE'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'FAQ'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'SYNDICATION'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'PROJECT'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'BLAST'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' }, 
			'RSS'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' }, 
			'REPORT'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' }, 
			'WMS'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'PLATFORM'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'TICKET'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'CAMPAIGN'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'DASHBOARD'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'DOMAIN'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'EBAY'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'AMAZON'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'GIFTCARD'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'CUSTOMER'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'CUSTOMER/WALLET'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'SUPPLIER'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'REVIEW'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'PAGE'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'MESSAGE'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'TASK'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'JOB'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'HELP'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'LEGACY'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' }
			}
		};

	push @ROLES, { 
		'id'=>'SUPER', 'title'=>'Supervisor', 'detail'=>'Access to all areas (except ownership transfer)',
		'%objects'=>{
			'DOMAIN'=>{ 'L'=>'+' },
			'ORDER'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'INVENTORY'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'PRODUCT'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'DASHBOARD'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			'REPORTS'=>{ 'C'=>'+', 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+', 'D'=>'+' },
			},
		};
	push @ROLES, { 
		'id'=>'WS1', 'title'=>'Warehouse Shipper', 'detail'=>'Picks, Ships, adds Tracking',
		'%objects'=>{
			'DOMAIN'=>{ 'L'=>'+' },
			'ORDER'=>{ 'U'=>'+', 'R'=>'+', 'L'=>'+', 'S'=>'+' },
			},
		};
	push @ROLES, { 
		'id'=>'WI1', 'title'=>'Warehouse Inventory', 'detail'=>'Inventory Updates',
		'%objects'=>{
			'DOMAIN'=>{ 'L'=>'+' },
			'INVENTORY'=>{'R'=>'+','U'=>'+','C'=>'+','L'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+','L'=>'+'},
			},
		};
	push @ROLES, { 
		'id'=>'WR1', 'title'=>'Warehouse Returns', 'detail'=>'Processes RMA/Tickets',
		'%objects'=>{
			'DOMAIN'=>{ 'L'=>'+' },
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
			'CUSTOMER'=>{'R'=>'+','C'=>'+','L'=>'+','S'=>'+','U'=>'+'},
			'DOMAIN'=>{'L'=>'+' },
			'ORDER/PAYMENT'=>{'U'=>'+'},
			'ORDER'=>{'R'=>'+','U'=>'+','C'=>'+','L'=>'+','S'=>'+'},
			'INVENTORY'=>{'R'=>'+','C'=>'+','L'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+','L'=>'+','S'=>'+'},
			},
		};
	push @ROLES, { 
		'id'=>'CC1', 
		'title'=>'Customer Service: Call Center', 
		'detail'=>'Looks up orders, tickets, customers, no payment processing/credits, notes and flagging only.',
		'%objects'=>{
			'DOMAIN'=>{ 'L'=>'+' },
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
			'DOMAIN'=>{ 'L'=>'+' },
			'ORDER'=>{'R'=>'+','C'=>'+','L'=>'+'},
			'INVENTORY'=>{'R'=>'+','C'=>'+','L'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+','L'=>'+'},
			},
		};
	push @ROLES, { 
		'id'=>'RO1', 'title'=>'Retail Operator', 'detail'=>'Operate point of sale',
		'%objects'=>{
			'DOMAIN'=>{ 'L'=>'+' },
			'ORDER'=>{'R'=>'+','C'=>'+','L'=>'+'},
			'INVENTORY'=>{'R'=>'+','L'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+','L'=>'+'},
			},
		};
	push @ROLES, { 
		'id'=>'TS1', 'title'=>'Vendor/Contractor (Read Only)',
		'detail'=>'Gives readonly order, inventory, and product access',
		'%objects'=>{
			'DOMAIN'=>{ 'L'=>'+' },
			'ORDER'=>{'R'=>'+','L'=>'+'},
			'INVENTORY'=>{'R'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+'},
			},
		};
	push @ROLES, { 
		'id'=>'AD1', 'title'=>'App/Web Developer', 'detail'=>'Access to hosting, dns, etc. but no product or orders',
		'%objects'=>{
			'DOMAIN'=>{ 'L'=>'+' },
			'ORDER'=>{'R'=>'+','L'=>'+'},
			'INVENTORY'=>{'R'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+'},
			},		
		};
	push @ROLES, { 
		'id'=>'XXX', 'title'=>'Catalog Manager', 'detail'=>'Access to create, update products, categories.',
		'%objects'=>{
			'DOMAIN'=>{ 'L'=>'+' },
			'ORDER'=>{'R'=>'+','C'=>'+','L'=>'+'},
			'INVENTORY'=>{'R'=>'+','C'=>'+','L'=>'+','S'=>'+'},
			'PRODUCT'=>{'R'=>'+','L'=>'+','U'=>'+','C'=>'+'},
			'IMAGE'=>{'R'=>'+','C'=>'+','U'=>'+','L'=>'+','S'=>'+'},
			'JOB'=>{'R'=>'+','C'=>'+','U'=>'+','L'=>'+','S'=>'+'},
			},		
		};
	push @ROLES, { 
		'id'=>'XYZ', 'title'=>'Marketplace Manager', 'detail'=>'Access to manage syndication, marketplace settings.',
		'%objects'=>{
			'DOMAIN'=>{ 'L'=>'+' },
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

##
##
##
sub build_myacl {
	my ($USERNAME,$MYROLES) = @_;

	my %MYACL = ();
	my $ALLROLES = &OAUTH::list_roles($USERNAME);	
	foreach my $role ( @{$MYROLES} ) {
		$MYACL{'%ROLES'}->{$role}++;
		if (($role eq 'BOSS') || ($role eq 'SUPER')) {
			foreach my $object (@OAUTH::OBJECTS) {
				$MYACL{ $object } = { 'R'=>'+', 'C'=>'+', 'U'=>'+', 'L'=>'+', 'S'=>'+',, 'D'=>'+' };
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
sub validate_authtoken {
	my ($USERNAME,$LUSERNAME,$CLIENTID,$DEVICEID,$AUTHTOKEN) = @_;

	## FOR JT TO DIAGNOSE ERROR 10 (invalid login)
	# return(undef);

	my ($v,$randomstr,$trydigest) = split(/\|/,$AUTHTOKEN);
	my $str = sprintf("%s-%s-%s-%s-%s",lc($USERNAME),lc($LUSERNAME),$CLIENTID,$DEVICEID,$randomstr);
	my $validdigest = Digest::SHA1::sha1_hex($str);
	if ($trydigest ne $validdigest) {
		## okay so the digest checks out
		print STDERR "VALID_DIGEST ne TRYDIGEST\n";
		return( undef );
		}

	my $SESSIONKEY = "SESSION+$USERNAME+$randomstr";
	print STDERR "validate_authtoken attempting $SESSIONKEY\n";
	my $redis = &ZOOVY::getRedis($USERNAME,1);
	my ($SESSIONJS) = $redis->get($SESSIONKEY);
	if ($SESSIONJS ne '') {
		## yay memcache got it!, refresh the session key
		$redis->expire($SESSIONKEY,86400);
		my $OBJ = JSON::XS::decode_json($SESSIONJS);	
		return($OBJ->{'%ACL'});
		}

	return(undef);
	}


######################################################
##
##
##
sub destroy_authtoken {
	my ($USERNAME,$LUSERNAME,$AUTHTOKEN) = @_;

	my $redis = &ZOOVY::getRedis($USERNAME,1);
	my $SESSIONKEY = "SESSION+$USERNAME+$AUTHTOKEN";
	$redis->del($SESSIONKEY);

	return();
	}


#######################################################
##
## upgrades a session with security keys
##
sub create_authtoken {
	my ($USERNAME,$LUSERNAME,$CLIENTID,$DEVICEID, %options) = @_;

	my ($randomstr) = &OAUTH::randomstring(24);
	my ($redis) = &ZOOVY::getRedis($USERNAME,1);
	my $SESSIONKEY = "SESSION+$USERNAME+$randomstr";

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
		#my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		#my $pstmt = "select USERNAME,DATA,MID,CACHED_FLAGS,RESELLER from ZUSERS where MID=".$MID." /* $USERNAME */";
		#($dbresult) = $udbh->selectrow_hashref($pstmt);
		$dbresult->{'USERNAME'} = $USERNAME;
		$dbresult->{'MID'} = &ZOOVY::resolve_mid($USERNAME);
		$dbresult->{'LUSER'} = $LUSERNAME;
		push @MYROLES, 'BOSS';
		# &DBINFO::db_user_close();
		}
	elsif ($options{'@MYROLES'}) {
		## used for support, etc.
		@MYROLES = @{$options{'@MYROLES'}};
		}
	else {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select UID, USERNAME, LUSER, MID, EXPIRES_GMT, ROLES from LUSERS where MID=".$MID." /* $USERNAME */ and LUSER=".$udbh->quote($LUSERNAME);
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

	## create an authtoken
	my $str = sprintf("%s-%s-%s-%s-%s",lc($USERNAME),lc($LUSERNAME),$CLIENTID,$DEVICEID,$randomstr);
	my $digest = Digest::SHA1::sha1_hex($str);
	my $authtoken = "1|$randomstr|$digest";

	my ($redis) = &ZOOVY::getRedis($USERNAME,1);
	$redis->set($SESSIONKEY,JSON::XS::encode_json({
		USERNAME=>$USERNAME,
		LUSERNAME=>$LUSERNAME,
		DEVICEID=>$DEVICEID,
		CLIENTID=>$CLIENTID,
		IP_ADDRESS=>$ENV{'REMOTE_ADDR'},
		CREATED_GMT=>time(),
		AUTHTOKEN=>$authtoken,
		MID=>$MID,
		'%ACL'=>$ACL
		}));
	$redis->expire($SESSIONKEY,86400);

	print STDERR "SESSIONKEY: $SESSIONKEY\n";

	return($authtoken);
	}






##
## accepts:
##		username
##		luser@username
##		luser@domain.com
##		domain.com
##		
#sub resolve_userid {
#	my ($userid) = @_;
#
#	my ($luser,$username,$domain) = ('admin','','');
#	if (index($userid,'@')>0) {
#		($luser,$username) = split(/\@/,$userid);
#		}
#	elsif (index($userid,'*')>0) {
#		($username,$luser) = split(/\*/,$userid);
#		}
#	else {
#		$username = $userid;
#		$luser = 'admin';
#		}
#
#	return($username,$luser);
#	}







1;
