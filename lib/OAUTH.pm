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
			'CUSTOMER'=>{'R'=>'+','C'=>'+','L'=>'+','S'=>'+'},
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
			'PRODUCT'=>{'R'=>'+','L'=>'+'},
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
		$MYACL{'_ROLES'}->{$role}++;
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
		return( undef );
		}

	my ($memd) = &ZOOVY::getMemd($USERNAME);
	if (my $ACL = $memd->get("SESSION+$AUTHTOKEN")) {
		#warn "got memache\n";
		return($ACL);
		}
	else {
		## doesn't exist in memcache, check the database (and add to MEMCACHE on success)
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		my $pstmt = "select LUSERNAME,ACL from OAUTH_SESSIONS where MID=$MID and AUTHTOKEN=".$udbh->quote($AUTHTOKEN);
		## print STDERR "/* $LUSERNAME */ $pstmt\n";
		my ($dbLUSER,$dbACL) = $udbh->selectrow_array($pstmt);
		&DBINFO::db_user_close();

		if (uc($dbLUSER) eq uc($LUSERNAME)) {
			#warn "set memcache\n";
			$memd->set("SESSION+$AUTHTOKEN",$dbACL);
			return($ACL);
			}
		else {
			#warn "failed db lookup\n";
			return(undef);
			}
		}

	## this line should NEVER be reached!
	return( undef );
	}


######################################################
##
##
##
sub destroy_authtoken {
	my ($USERNAME,$LUSERNAME,$AUTHTOKEN) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my ($memd) = &ZOOVY::getMemd($USERNAME);
	if (defined $memd) {
		$memd->delete("USER:$USERNAME.$LUSERNAME");
		$memd->delete("SESSION+$AUTHTOKEN");
		}

	my $pstmt = "delete from OAUTH_SESSIONS where MID=$MID /* $USERNAME */ and AUTHTOKEN=".$udbh->quote($AUTHTOKEN);
	print STDERR "$pstmt\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();

	return();
	}


#######################################################
##
## upgrades a session with security keys
##
sub create_authtoken {
	my ($USERNAME,$LUSERNAME,$CLIENTID,$DEVICEID, %options) = @_;

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
	## my $authtoken = &OAUTH::build_authtoken($USERNAME,$LUSERNAME,$CLIENTID,$DEVICEID);

	## create an authtoken
	my ($randomstr) = &OAUTH::randomstring(24);
	my $str = sprintf("%s-%s-%s-%s-%s",lc($USERNAME),lc($LUSERNAME),$CLIENTID,$DEVICEID,$randomstr);
	my $digest = Digest::SHA1::sha1_hex($str);
	my $authtoken = "1|$randomstr|$digest";

	my $memd = &ZOOVY::getMemd($USERNAME);
	$memd->set("SESSION+$authtoken",serialize_acl($ACL));

	if (defined $dbresult) {
		my $pstmt = &DBINFO::insert($udbh,'OAUTH_SESSIONS',{
			'USERNAME'=>$USERNAME,
			'LUSERNAME'=>$LUSERNAME,
			'MID'=>$MID,
			'DEVICEID'=>$DEVICEID,
			'CLIENTID'=>$CLIENTID,
			'IP_ADDRESS'=>$ENV{'REMOTE_ADDR'},
			'*CREATED_TS'=>'now()',
			'*EXPIRES_TS'=>'date_add(now(),interval 1 year)',
			'AUTHTOKEN'=>$authtoken,
			# 'CACHED_FLAGS'=>sprintf("%s",$dbresult->{'CACHED_FLAGS'}),
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
