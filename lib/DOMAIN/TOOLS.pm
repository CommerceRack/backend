package DOMAIN::TOOLS;

## mxmode 
##		1 = people who mx elsewhere
##		2 = zoovymail (fusemail)
##		3 = mail.zoovy.com  with lots of aliases

use DBI;
use strict;
use Storable;

use lib "/backend/lib";
require NAVCAT;
require ZWEBSITE;

# $DOMAIN::TOOLS::CACHE_FILE = "/dev/shm/domains.bin";

$DOMAIN::TOOLS::DISABLE_SSL = 0;
$DOMAIN::TOOLS::CACHE_FILE = "/dev/shm/domaintools-cache.bin";
%DOMAIN::TOOLS::PROFILE_CACHE = ();

##
## creates /dev/shm/domains.bin
##
sub rebuild_cache {
	my %CACHE = ();
	exit;
	}

#	require PLATFORM;
#	my ($PLATFORM) = PLATFORM->new();
#	foreach my $focusCLUSTER (@{$PLATFORM->clusters()}) {	
#
#		$focusCLUSTER = lc($focusCLUSTER);
#		print STDERR "CLUSTER: $focusCLUSTER\n";
#		my ($udbh) = &DBINFO::db_user_connect("\@$focusCLUSTER");
#		
#		my $pstmt = "select DOMAIN,USERNAME,PRT,PROFILE,
#			WWW_HOST_TYPE,WWW_CHKOUT_HOST,
#			APP_HOST_TYPE,APP_CHKOUT_HOST,
#			M_HOST_TYPE,M_CHKOUT_HOST 
#			from DOMAINS 
#			";
#		my $sth = $udbh->prepare($pstmt);
#		$sth->execute();
#		while ( my $ref = $sth->fetchrow_hashref() ) {
#			my $DOMAIN = lc($ref->{'DOMAIN'});
#			my ($userCLUSTER) = lc(&ZOOVY::resolve_cluster($ref->{'USERNAME'}));
#			next if ($focusCLUSTER ne $userCLUSTER);
#
#			foreach my $APPWWWM ('APP','WWW','M') {
#				if ($ref->{"$APPWWWM\_CHKOUT_HOST"} eq '') {
#					$ref->{"$APPWWWM\_CHKOUT_HOST"} = &ZWEBSITE::domain_to_checkout_domain("$APPWWWM.$DOMAIN");
#					}
#				}
#			
#			#########################################################################
#			## **ALERT**: if oyu change the format below you must also change it in domain_to_userprt
#			##					it uses fixed columns for speed.
#			$CACHE{lc($DOMAIN)} = $ref;
#			}
#		$sth->finish();
#		&DBINFO::db_user_close();
#		}
#
#	Storable::nstore \%CACHE, $DOMAIN::TOOLS::CACHE_FILE;
#	chmod 0666, $DOMAIN::TOOLS::CACHE_FILE;
#	chown 65534,65534, $DOMAIN::TOOLS::CACHE_FILE;
#
#	return(\%CACHE);
#	}
#



##
## this is the magic function
##
#sub summary {
#	my ($DOMAIN) = @_;
#
#	$DOMAIN = lc($DOMAIN);
#	if ($DOMAIN =~ /^(secure|www|m|i|app)\.(.*?)$/) { $DOMAIN = $2; }
#
#	my $result = undef;
#
#	if (-f $DOMAIN::TOOLS::CACHE_FILE) {
#		my $ref = retrieve $DOMAIN::TOOLS::CACHE_FILE;		
#		if (defined $ref->{$DOMAIN}) {
#			$result = $ref->{$DOMAIN};
#			$result->{'SRC'} = $DOMAIN::TOOLS::CACHE_FILE;
#			}
#		}
#
#	if (not defined $result) {
#		warn "DOMAIN:$DOMAIN was not found, resorting to dns lookup\n";
#		my %result = ();
#
#		require Net::DNS;
#		my $response = ();
#		## my $res   = Net::DNS::Resolver->new(nameservers => ['208.74.184.18','208.74.184.19']);
#		my $res = Net::DNS::Resolver->new();
#
#		my $query = $res->query(sprintf('config.%s',$DOMAIN),'TXT');
#		if ($query) {
#			$result{'SRC'} = 'DNS';
#			foreach my $rr (grep { $_->type eq 'TXT' } $query->answer) {
#				$result{'TXT'} .= sprintf("%s\n",$rr->txtdata);
#				foreach my $kvpair (split(/[;\s]+/,$rr->txtdata)) {
#					print STDERR "KV:$kvpair\n";
#					my ($k,$v) = split(/=/,$kvpair,2);
#					$result{uc($k)} = $v;
#					}
#  	       }
#			if ((not defined $result{'USERNAME'}) && (defined $result{'USER'})) { 
#				$result{'USERNAME'} = $result{'USER'}; 
#				}
#			if ((not defined $result{'PROFILE'}) && (defined $result{'USERNAME'}) && (defined $result{'PRT'})) {
#				$result{'PROFILE'} = &ZOOVY::prt_to_profile($result{'USERNAME'},$result{'PRT'});
#				}
#			chomp($response->{'TXT'}); # remove trailing cr/lf
#			}
#		else {
#			warn "query failed: ", $res->errorstring, "\n";
#			$result{'err'} = $res->errorstring();				
#			}
#
#		$result = \%result;
#		}
#	
#	return($result);
#	}



##
## resolves a domain to a user/partition pair
##
sub domain_to_userprt {
	my ($DOMAIN) = @_;

	if ($DOMAIN =~ /\.app-hosted\.com$/) {
		$DOMAIN = &ZWEBSITE::checkout_domain_to_domain($DOMAIN);
		}

	my $MEMCACHEKEY = uc($DOMAIN);
	my ($USERNAME,$PRT,$PROFILE,$SSLDOMAIN) = ();
	my $MEMD = &ZOOVY::getGlobalMemCache();
	my $summary = undef;
	if (defined $MEMD) {
		my $yaml = $MEMD->get($MEMCACHEKEY);
		if (defined $yaml) { 
			$summary = YAML::Syck::Load($yaml);
			}
		}

	if (not defined $summary) {
		## $summary = &DOMAIN::TOOLS::summary($DOMAIN);
		require DOMAIN::QUERY;
		($summary) = DOMAIN::QUERY::lookup_userref($DOMAIN,'www');

		if (not defined $MEMD) {
			}
		else {
			$MEMD->set($MEMCACHEKEY,YAML::Syck::Dump($summary));
			}
		}

	return(
		$summary->{'USERNAME'},
		$summary->{'PRT'}
		);

	return($USERNAME,$PRT);
	}

%DOMAIN::TOOLS::CACHE_DOMAINPRT_LOOKUP = ();

##
## returns the syndication domain for a particular partition
##
sub domain_for_prt {
	my ($USERNAME,$PRT,%options) = @_;

	my $KEY = "$USERNAME:$PRT";
	if (defined $DOMAIN::TOOLS::CACHE_DOMAINPRT_LOOKUP{ $KEY }) {
		return( $DOMAIN::TOOLS::CACHE_DOMAINPRT_LOOKUP{$KEY} );
		}

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	$PRT = int($PRT);
	my $pstmt = "select DOMAIN from DOMAINS where IS_PRT_PRIMARY=1 and PRT=$PRT and MID=$MID order by ID";
	my ($DOMAIN) = $udbh->selectrow_array($pstmt);

	if (($DOMAIN eq '') && ($options{'guess'})) {
		$pstmt = "select DOMAIN from DOMAINS where PRT=$PRT and MID=$MID order by ID";
		($DOMAIN) = $udbh->selectrow_array($pstmt);
		warn "GUESSED DOMAIN: $DOMAIN for $USERNAME/$PRT\n";
		}

	&DBINFO::db_user_close();
	$DOMAIN::TOOLS::CACHE_DOMAINPRT_LOOKUP{ $KEY } = $DOMAIN;

	return($DOMAIN);
	}



##
## this is a very obtuse way to get information about a domain..
##
#sub getinfo {
#	my ($USERNAME,$DOMAIN) = @_;
#
#	my ($PROFILE) = ();
#	my %data = ();
#
#	my $udbh = &DBINFO::db_user_connect($USERNAME);
#	my $pstmt = "/* GETINFO */ select PROFILE from DOMAINS where DOMAIN=".$udbh->quote($DOMAIN);
#	my $sth = $udbh->prepare($pstmt);
#	$sth->execute();
#	($PROFILE) = $sth->fetchrow();
#	$sth->finish();
#	&DBINFO::db_user_close();
#
#	my ($nsref) = &ZOOVY::fetchmerchantns_ref($USERNAME,$PROFILE);
#	$data{'profile'} = $PROFILE;
#	$data{'rootcat'} = $nsref->{'zoovy:site_rootcat'};
#	$data{'schedule'} = $nsref->{'zoovy:site_schedule'};
#	## $data{'prt'} = int($nsref->{'zoovy:site_partition'});
#	$data{'prt'} = $nsref->{'prt:id'};
#	
#	return(\%data);
#	}




##
## returns an array of errors about why a domain is invalid.
##
sub valid_domain {
	my ($DOMAIN) = @_;

	$DOMAIN = lc($DOMAIN);
	my @ERRORS = ();

	my $x = $DOMAIN;
	my %EXTS = ( 'com'=>1,'net'=>1,'org'=>1,'us'=>1,'biz'=>1,'info'=>1, 'mobi'=>1, 'tv'=>1 );
        
	## if customer wants to link international domain, hosted on outside nameserver
	## with setup > domain hosting > add domains > Link
	## validate against full list of EXTS.
	#if ($ZOOVY::cgiv->{'VERB'} and $ZOOVY::cgiv->{'VERB'} eq 'LINK-SAVE') {
	#  %EXTS = ( 'aero'=>1,'biz'=>1,'cat'=>1,'com'=>1,'coop'=>1,'edu'=>1,'gov'=>1,'info'=>1,'int'=>1,
	#	'jobs'=>1,'mil'=>1,'mobi'=>1,'museum'=>1,'name'=>1,'net'=>1,'org'=>1,'travel'=>1,
	#	'ac'=>1,'ad'=>1,'ae'=>1,'af'=>1,'ag'=>1,'ai'=>1,'al'=>1,'am'=>1,'an'=>1,'ao'=>1,
	#	'aq'=>1,'ar'=>1,'as'=>1,'at'=>1,'au'=>1,'aw'=>1,'az'=>1,'ba'=>1,'bb'=>1,'bd'=>1,
	#	'be'=>1,'bf'=>1,'bg'=>1,'bh'=>1,'bi'=>1,'bj'=>1,'bm'=>1,'bn'=>1,'bo'=>1,'br'=>1,
	#	'bs'=>1,'bt'=>1,'bv'=>1,'bw'=>1,'by'=>1,'bz'=>1,'ca'=>1,'cc'=>1,'cd'=>1,'cf'=>1,
	#	'cg'=>1,'ch'=>1,'ci'=>1,'ck'=>1,'cl'=>1,'cm'=>1,'cn'=>1,'co'=>1,'cr'=>1,'cs'=>1,
	#	'cu'=>1,'cv'=>1,'cx'=>1,'cy'=>1,'cz'=>1,'de'=>1,'dj'=>1,'dk'=>1,'dm'=>1,'do'=>1,
	#	'dz'=>1,'ec'=>1,'ee'=>1,'eg'=>1,'eh'=>1,'er'=>1,'es'=>1,'et'=>1,'eu'=>1,'fi'=>1,
	#	'fj'=>1,'fk'=>1,'fm'=>1,'fo'=>1,'fr'=>1,'ga'=>1,'gb'=>1,'gd'=>1,'ge'=>1,'gf'=>1,
	#	'gg'=>1,'gh'=>1,'gi'=>1,'gl'=>1,'gm'=>1,'gn'=>1,'gp'=>1,'gq'=>1,'gr'=>1,'gs'=>1,
	#	'gt'=>1,'gu'=>1,'gw'=>1,'gy'=>1,'hk'=>1,'hm'=>1,'hn'=>1,'hr'=>1,'ht'=>1,'hu'=>1,
	#	'id'=>1,'ie'=>1,'il'=>1,'im'=>1,'in'=>1,'io'=>1,'iq'=>1,'ir'=>1,'is'=>1,'it'=>1,
	#	'je'=>1,'jm'=>1,'jo'=>1,'jp'=>1,'ke'=>1,'kg'=>1,'kh'=>1,'ki'=>1,'km'=>1,'kn'=>1,
	#	'kp'=>1,'kr'=>1,'kw'=>1,'ky'=>1,'kz'=>1,'la'=>1,'lb'=>1,'lc'=>1,'li'=>1,'lk'=>1,
	#	'lr'=>1,'ls'=>1,'lt'=>1,'lu'=>1,'lv'=>1,'ly'=>1,'ma'=>1,'mc'=>1,'md'=>1,'me'=>1,
	#	'mg'=>1,'mh'=>1,'mk'=>1,'ml'=>1,'mm'=>1,'mn'=>1,'mo'=>1,'mp'=>1,'mq'=>1,'mr'=>1,
	#	'ms'=>1,'mt'=>1,'mu'=>1,'mv'=>1,'mw'=>1,'mx'=>1,'my'=>1,'mz'=>1,'na'=>1,'nc'=>1,
	#	'ne'=>1,'nf'=>1,'ng'=>1,'ni'=>1,'nl'=>1,'no'=>1,'np'=>1,'nr'=>1,'nu'=>1,'nz'=>1,
	#	'om'=>1,'pa'=>1,'pe'=>1,'pf'=>1,'pg'=>1,'ph'=>1,'pk'=>1,'pl'=>1,'pm'=>1,'pn'=>1,
	#	'pr'=>1,'ps'=>1,'pt'=>1,'pw'=>1,'py'=>1,'qa'=>1,'re'=>1,'ro'=>1,'rs'=>1,'ru'=>1,
	#	'rw'=>1,'sa'=>1,'sb'=>1,'sc'=>1,'sd'=>1,'se'=>1,'sg'=>1,'sh'=>1,'si'=>1,'sj'=>1,
	#	'sk'=>1,'sl'=>1,'sm'=>1,'sn'=>1,'so'=>1,'sr'=>1,'st'=>1,'su'=>1,'sv'=>1,'sy'=>1,
	#	'sz'=>1,'tc'=>1,'td'=>1,'tf'=>1,'tg'=>1,'th'=>1,'tj'=>1,'tk'=>1,'tl'=>1,'tm'=>1,
	#	'tn'=>1,'to'=>1,'tp'=>1,'tr'=>1,'tt'=>1,'tv'=>1,'tw'=>1,'tz'=>1,'ua'=>1,'ug'=>1,
	#	'uk'=>1,'um'=>1,'us'=>1,'uy'=>1,'uz'=>1,'va'=>1,'vc'=>1,'ve'=>1,'vg'=>1,'vi'=>1,
	#	'vn'=>1,'vu'=>1,'wf'=>1,'ws'=>1,'ye'=>1,'yt'=>1,'yu'=>1,'za'=>1,'zm'=>1,'zr'=>1,
	#	'zw'=>1 
	#  );
	#}


	my @parts = split(/\./, $DOMAIN);
	my $ext = pop(@parts);
	if (not defined $EXTS{$ext}) { push @ERRORS, "Domain does not have a valid extension [$ext]"; }

	if (substr($DOMAIN,0,1) eq '.') {
		push @ERRORS, "Domains may not have a leading period in their name";
		}

	$x =~ s/^[a-z0-9\-\.]+//gs;
	if (length($x)>0) {
		push @ERRORS, "Domain contains invalid characters [$x]";
		}
	$x = $DOMAIN;
	$x =~ s/[^\.]+//gs;
	## changed to >2, sub domains are allowed
	if (length($x)>2) {
		push @ERRORS, "Domain contains too many periods (try domain.com)";
		}
	elsif (length($x)==0) {
		push @ERRORS, "Domain missing suffix (e.g. domain.com)";
		}

	return(@ERRORS);
	}



##
## returns an array of domain names
##		%OPTIONS = 
##			REG_TYPE=>['ZOOVY','NEW','TRANSFER']
##			EMAIL_TYPE
##			PROFILE
##			PRT=>
##		SKIP_VSTORE=>1
sub domains {
	my ($USERNAME,%options) = @_;

	require DOMAIN;
	return(DOMAIN::list($USERNAME,%options));
	}








1;
