package DOMAIN;

use strict;
use Storable;
use Data::Dumper;

use lib "/backend/lib";
require ZOOVY;
require ZTOOLKIT;
require DBINFO;
require PLATFORM;
require CFG;

#$DOMAINS::MYSQL_USER = "DOMAINS";
#$DOMAINS::MYSQL_PASS = "R3d1R";
#$DOMAINS::MYSQL_DSN = "DBI:mysql:database=DOMAINS;host=beast.zoovy.com";

##
## big changes:
##		no more primary domains instead an entry in the domains table for domain.zoovy.com redirects
##
##


$DOMAIN::VERSION = 201343;

##
## returns an array of HOSTINFO's (look at 'HOSTNAME' field for the id)
##
sub hosts {
	my ($self) = @_;
	my @HOSTS = ();
	foreach my $hostname (keys %{$self->{'%HOSTS'}}) {
		my $HOSTINFO = $self->{'%HOSTS'}->{$hostname};
		$HOSTINFO->{'HOSTNAME'} = $hostname;
		push @HOSTS, $HOSTINFO;
		}

	return(\@HOSTS);
	}

sub time_to_serial {
        my ($time) = @_;
        my @a=reverse((localtime($time))[2..5]); $a[0]+=1900; $a[1]++;  # the 2 is an offset
        return(sprintf("%04d%02d%02d%02d", @a));
        }


sub whatis_public_vip {
	my $VIP = undef;
	if (-f "/etc/commercerack.ini") { $VIP = CFG->new()->get("global","vip.public");	}
	return($VIP);
	}

sub whatis_private_vip {
	my $VIP = undef;
	if (-f "/etc/commercerack.ini") { $VIP = CFG->new()->get("global","vip.private"); }
	return($VIP);
	}








sub for_export {
	my ($self) = @_;

	my $CFG = CFG->new(); 

	my $out = {};
	foreach my $k (keys %{$self}) {
		if ($k eq '%YAML') {
			## ignore
			}
		elsif (ref($self->{$k}) eq '') {
			$out->{$k} = $self->{$k};
			}
		else {
			$out->{$k} = Storable::dclone($self->{$k});
			}
		}
	$out->{'CLUSTER'} = &ZOOVY::servername();

	my $VIP = CFG->new()->get("global","vip.public");	

	if ($VIP eq '') { die("VIP not configured"); }
	foreach my $HOST (keys %{$out->{'%HOSTS'}}) {	
		my $href = $out->{'%HOSTS'}->{$HOST};
		my $FQDOMAIN = lc(sprintf("%s.%s",$HOST,$out->{'DOMAIN'}));
		$href->{'IP4'} = $CFG->get("$FQDOMAIN","vip.public");
		if ($href->{'IP4'} eq '') { $href->{'IP4'} = DOMAIN::whatis_public_vip($self->username()); }

		## CHKOUT should already be set correctly here.
		}

	# /configs/dns-external/custom-records.txt
	my %custom;
	my ($CUSTOM_CONF) = &ZOOVY::resolve_userpath($self->username())."/custom-records.txt";
	## my $CUSTOM_CONF = "/root/configs/dns-external/custom-records.txt";
	if (-f $CUSTOM_CONF) {
		my @CUSTOM = ();
		$out->{'@CUSTOM'} = \@CUSTOM;
		open(F,$CUSTOM_CONF);
		while (<F>) {
			chop;
			## skip comments
			s/#.*//o;
			## replace multiple spaces with a single space
			s/[\s][\s]*/ /go;
			## strip leading space
			s/^ //o;
			## strip trailing space
			s/ $//o;
			next if /^$/;

         my ($domain, $host, $line) = split(/[\s\t]/,$_,3);
			next if ($domain ne $self->domainname());

			my %LINE = ();
         my @chunks = split(/[\s\t]+/,$line);
         $LINE{'host'} = $host;
			if ($chunks[0] =~ /^([\d]+)$/) { $LINE{'ttl'} = shift @chunks; }	## optional ttl may be specified "IN"
         if ($chunks[0] eq 'IN') { shift @chunks; }   ## throw away "IN" (it means "internet" oreally?)
         $LINE{'type'} = uc(shift @chunks);         ## should be "A" "TXT" "MX" "SRV" etc.
         if ($LINE{'type'} eq 'MX') { $LINE{'mx_priority'} = int(@chunks); }
         $LINE{'data'} = join(" ",@chunks);
			if ($LINE{'type'} eq 'TXT') { $LINE{'data'} =~ s/^"(.*?)"$/$1/gs;	}	# strip leading and trailing quotes
			push @CUSTOM, \%LINE;
			}
		close (F);
		}

   if ($self->domainname() =~ /\.zoovy\.com$/) {
		warn "[WARN] Forcing EMAIL type to FUSEMAIL for .zoovy.com\n";
		$out->{'%EMAIL'}->{'TYPE'} = 'NONE';
      }

	## Some other DNS specific stuff.
	## $out->{'@NS'} = [ 'ns.zoovy.com', 'ns2.zoovy.com', 'ns3.zoovy.com' ];
	$out->{'@NS'} = [ 'ns.zoovy.com', 'ns2.zoovy.com' ];
	$out->{'%SOA'}->{'NS'} = $out->{'@NS'}->[0];
	$out->{'%SOA'}->{'RNAME'} = 'dnsadmin.zoovy.com'; ## 'hostmaster.'.$out->{'SOA.NS'};
	$out->{'%SOA'}->{'SERIAL'} = &DOMAIN::time_to_serial($out->{'MODIFIED_GMT'});
	$out->{'TTL'} = 300;

	$out->{'V'} = $DOMAIN::VERSION;
	$out->{'DKIM_PUBKEY'} =~ s/[\-]+(.*?)[\-]+//g;
	$out->{'DKIM_PUBKEY'} =~ s/[\n\r]+//gs;

	return($out);
	}



##
##
##
sub update {
	my ($self,$LM) = @_;

	if (not defined $LM) {
		require LISTING::MSGS;
		($LM) = LISTING::MSGS->new($self->username(),stderr=>1);
		}

	my @CMDS = ();
	#push @CMDS, { '_uuid'=>"$USERNAME!nuke", '_cmd'=>'dns-user-delete' };
	my ($USERNAME) = $self->username();
	my $DOMAIN = $self->domainname();
	my ($MID) = $self->mid();

	my ($VIP) = DOMAIN::whatis_public_vip($USERNAME);
	if ($VIP eq '') { die("NO VIP SET\n"); }

	push @CMDS, { '_uuid'=>"$USERNAME\@static", '_cmd'=>'dns-wildcard-reserve', 'zone'=>'app-hosted.com', 'host'=>sprintf("static---%s",$USERNAME), 'ipv4'=>$VIP };

	my $D = $self;
	my @SERVERS = &PLATFORM::ns_servers();

	# push @CMDS, { '_uuid'=>"$USERNAME\@$DOMAIN", '_cmd'=>'dns-domain-delete', 'DOMAIN'=>$DOMAIN }; 
	push @CMDS, { '_uuid'=>"$USERNAME\@$DOMAIN", '_cmd'=>'dns-domain-update', 'DOMAIN'=>$DOMAIN, '%DOMAIN'=>$D->for_export() }; 

	foreach my $HOSTINFO (@{$D->hosts()}) {
		my $HOSTNAME = $HOSTINFO->{'HOSTNAME'};
		my ($wildHOST,$wildDOMAIN) = split(/\./,&ZWEBSITE::domain_to_checkout_domain("$HOSTNAME.$DOMAIN"),2);
		my %CMD = ( '_uuid'=>"$USERNAME\@$DOMAIN-$HOSTNAME", '_cmd'=>'dns-wildcard-reserve', 'DOMAIN'=>$DOMAIN, 'zone'=>$wildDOMAIN, 'host'=>$wildHOST, 'ipv4'=>$VIP ); 
		push @CMDS, \%CMD;
		}

	for my $CMD (@CMDS) {
		$CMD->{'MID'} = $MID;
		$CMD->{'USERNAME'} = $USERNAME;
		}

	#print STDERR Dumper(\@CMDS);

	$LM->pooshmsg(sprintf("INFO|+We have %d commands for %d servers",scalar(@CMDS),scalar(@SERVERS)));
	&PLATFORM::send_cmds($LM,\@CMDS,\@SERVERS);

	return($LM);
	}


##
##
##
%DOMAIN::REG_TYPES = (
	'OTHER' => 'Other Registrar',
	'ZOOVY' => 'Zoovy Registrar',
	'VSTORE' => 'Reserved Domain',
	'SUBDOMAIN' => 'Subdomain',
	'ERROR' => 'Invalid Registration State'
	);

##
##
##
%DOMAIN::REG_STATES = (
	'NEW' => 'Not Sent',
	'NEW-WAIT' => 'Waiting on Ack',
	'TRANSFER' => 'Not Sent',
	'TRANSFER-WAIT' => 'Waiting on Ack',
	'ACTIVE'=>'Live',
	);

%DOMAIN::EMAIL_TYPES = (
	''=>'Error/Not Configured',
	'MX'=>'External MX Server',
	'ZM'=>'Zoovy Mail 2.0',
	'NONE'=>'No Mail',
	'GOOGLE'=>'Google Apps',
	);


##
## makes a domain the primary responsible domain for a partition.
##
sub make_domain_primary {
	my ($self) = @_;

	my $PRT = $self->prt();
	
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my ($MID) = &ZOOVY::resolve_mid($self->username());

	my $pstmt = "update DOMAINS set IS_PRT_PRIMARY=0 where MID=$MID and PRT=$PRT";
	## print STDERR "$pstmt\n";
	$udbh->do($pstmt);

	$pstmt = "update DOMAINS set IS_PRT_PRIMARY=1 where MID=$MID and PRT=$PRT and DOMAIN=".$udbh->quote($self->domainname());
	## print STDERR "$pstmt\n";
	$udbh->do($pstmt);

	$self->{'IS_PRT_PRIMARY'} = 1;

	&DBINFO::db_user_close();
	}


##
##
##
sub gen_dkim_keys {
	my ($self,%options) = @_;

	require Crypt::OpenSSL::RSA;
	#Crypt::OpenSSL::Random::random_seed(time());
	#Crypt::OpenSSL::RSA->import_random_seed();
	my $rsa = Crypt::OpenSSL::RSA->generate_key(768);
	$rsa->use_no_padding();
	my $priv = $rsa->get_private_key_string();

	$self->{'DKIM_PRIVKEY'} = $rsa->get_private_key_string();
	## DKIM uses DER/x509 encoding not PKCS1 -- doh!
	## THIS WILL NOT WORK: $rsa->get_public_key_string();
	$self->{'DKIM_PUBKEY'} = $rsa->get_public_key_x509_string();

	if ((defined $options{'save'}) && ($options{'save'})) {
		## normally we don't load the DKIM parameters.
		$self->save();
		}
	}

##
## Just returns the domain name
##
sub domainname { my ($self) = @_; return($self->{'DOMAIN'}); }
sub prt { my ($self) = @_; return($self->{'PRT'}); }
sub reg_type { return($_[0]->{'REG_TYPE'}); }
sub dkim_privkey { return($_[0]->{'DKIM_PRIVKEY'}); }
sub dkim_pubkey { return($_[0]->{'DKIM_PUBKEY'}); }
sub username { return($_[0]->{'USERNAME'}); }
sub mid { return(&ZOOVY::resolve_mid($_[0]->username())); }
sub logo { return($_[0]->get('our/company_logo')); }

##
##
##
sub host_set {
	my ($self,$hostname,%config) = @_;

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my %dbvars = ();
	$dbvars{'MID'} = $self->mid();
	$dbvars{'DOMAINNAME'} = $self->domainname();
	$dbvars{'HOSTNAME'} = sprintf("%s",uc($hostname));

	my $VERB = '';
	if (not defined $self->{'%HOSTS'}->{uc($hostname)}) {
		$VERB = 'insert';
		$self->{'%HOSTS'}->{uc($hostname)} = \%config;
		$dbvars{'CREATED_TS'} = time();
		}
	else {
		$VERB = 'update';
		foreach my $k (keys %{$self->{'%HOSTS'}->{uc($hostname)}}) {
			## copy any keys which don't exist
			next if (defined $config{$k});
			$config{$k} = $self->{'%HOSTS'}->{uc($hostname)}->{$k};
			}
		foreach my $k (keys %config) {
			$self->{'%HOSTS'}->{uc($hostname)}->{$k} = $config{$k};
			}
		}

	if (defined $config{'HOSTTYPE'}) { $dbvars{'HOSTTYPE'} = sprintf("%s",$config{'HOSTTYPE'}); };
	if (defined $config{'CHKOUT'}) { $dbvars{'CHKOUT'} = sprintf("%s",$config{'CHKOUT'});	}
	$dbvars{'CONFIG'} = &ZTOOLKIT::buildparams($self->{'%HOSTS'}->{uc($hostname)});
	
	my ($pstmt) = &DBINFO::insert($udbh,'DOMAIN_HOSTS',\%dbvars,'key'=>['MID','DOMAINNAME','HOSTNAME'],'verb'=>$VERB,'sql'=>1);
	## print STDERR "$pstmt\n";
	$udbh->do($pstmt);

	## things have changed.
	$self->flush_memcache();
	
	return($self);
	}

##
##
##
sub host_kill {
	my ($self,$hostname) = @_;

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my ($MID) = $self->mid();
	my ($qtDOMAINNAME) = $udbh->quote($self->domainname());

	delete $self->{'%HOSTS'}->{uc($hostname)};
	my $pstmt = "delete from DOMAIN_HOSTS where MID=$MID and DOMAINNAME=$qtDOMAINNAME and HOSTNAME=".$udbh->quote(uc($hostname));
	$udbh->do($pstmt);
	&DBINFO::db_user_close();

	# delete $self->{"$hostname\_CONFIG"};
	# $self->{"$hostname\_HOST_TYPE"} = 'NONE';

	## things have changed.
	$self->flush_memcache();

	return();
	}


sub has_dkim {
	## eventually this logic might be more sophisticated.
	my ($self) = @_;
	if ($self->reg_type() eq 'ZOOVY') { return 1; } else { return 0; }
	}

sub profile {
	my ($self) = @_;
	if ($self->{'PROFILE'} eq '') { $self->{'PROFILE'} = 'DEFAULT'; }
	return($self->{'PROFILE'});
	}

sub newsletter_enable { 
	if (defined $_[1]) { $_[0]->{'NEWSLETTER_ENABLE'} = int($_[1]); }
	return(int($_[0]->{'NEWSLETTER_ENABLE'})); 
	}
sub syndication_enable { 
	if (defined $_[1]) { $_[0]->{'SYNDICATION_ENABLE'} = int($_[1]); }
	return(int($_[0]->{'SYNDICATION_ENABLE'})); 	
	}


##
##
##
sub list {
	## returns an array of domain names
	##		%OPTIONS = 
	##			REG_TYPE=>['ZOOVY','NEW','TRANSFER']
	##			EMAIL_TYPE
	##			PROFILE
	##			PRT=>
	##		SKIP_VSTORE=>1
	my ($USERNAME,%options) = @_;

	my @domains = ();

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	if ($MID == -1) { warn("Crap, MID not found for [$USERNAME]"); return(); }
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	
	my ($package,$file,$line,$sub,$args) = caller(0);
	## print STDERR "DOMAINS: $package,$file,$line,$sub,$args\n";
	

	my $skip_vstore = 0;
	if ((defined $options{'PRT'}) && ($options{'PRT'}>0)) { $skip_vstore++; }
	if ((defined $options{'SKIP_VSTORE'}) && ($options{'SKIP_VSTORE'})) { $skip_vstore++; }

	my $qtUSERNAME = $udbh->quote($USERNAME);
	my $pstmt = '';
	if (defined $options{'PRTS'}) {
		$pstmt .= " and PRT in ".&DBINFO::makeset($udbh,$options{'PRTS'});
		}
	if (defined $options{'NEWSLETTER_ALLOWED'}) {
		$pstmt .= " and NEWSLETTER_ENABLE>0 ";
		}

	if (defined $options{'HAS_PROFILE'}) {
		## will be used later .. mostly for fetchprofiles emulation
		}

	if (defined $options{'PROFILE'}) {
		## note this must be the first check because it recycles $pstmt.
		if ($options{'PROFILE'} eq '') { $options{'PROFILE'} = 'DEFAULT'; }
		$pstmt .= " and PROFILE=".$udbh->quote($options{'PROFILE'});
		}
	if (defined $options{'REG_TYPE'}) {
		my $x = '';
		foreach my $type (@{$options{'REG_TYPE'}}) { $x .= $udbh->quote($type).','; }
		chop($x);
		$pstmt .= " and REG_TYPE in ($x)";
		}
	if (defined $options{'PRT'}) {
		$pstmt .= " and PRT=".int($options{'PRT'});
		}

	if (defined $options{'EMAIL_TYPE'}) {
		my $x = '';
		foreach my $type (@{$options{'EMAIL_TYPE'}}) { $x .= $udbh->quote($type).','; }
		chop($x);
		$pstmt .= " and EMAIL_TYPE in ($x)";
		}

	if (not defined $options{'DETAIL'}) { $options{'DETAIL'} = 0; }

	if ($options{'DETAIL'}==0) {
		## returns a simple array of domains scalars.
		$pstmt = "/* DOMAIN::TOOLS::domains */ select DOMAIN from DOMAINS where MID=$MID /* USERNAME=$qtUSERNAME detail=0 */ ".$pstmt;
		$pstmt .= " order by ID";

		## print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($d) = $sth->fetchrow() ) {
			push @domains, $d;
			}
		$sth->finish();
		}
	elsif ($options{'DETAIL'}==1) {
		## returns a complex array of hashrefs.
		## used by search debugger
		$pstmt = "/* DOMAIN::TOOLS::domains-2 */ select DOMAIN,PRT,PROFILE,IS_FAVORITE from DOMAINS where MID=$MID /* USERNAME=$qtUSERNAME detail=1  */ ".$pstmt;
		$pstmt .= " order by ID";

		## print STDERR $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $dref = $sth->fetchrow_hashref() ) {
			push @domains, $dref;
			}
		$sth->finish();
		}

	&DBINFO::db_user_close();
	return(@domains);
	}





##
##
##
sub bill {
	my ($self,$ts) = @_;

#	if ($ts==0) { $ts = time(); }
#
#	my $dbh = &DBINFO::db_zoovy_connect();
#	my $USERNAME = $self->{'USERNAME'};
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#
##mysql> desc BS_TRANSACTIONS;
##+---------------+------------------------------------------------------------------------------------------------------------------------------------------+------+-----+---------------------+----------------+
##| Field         | Type                                                                                                                                     | Null | Key | Default             | Extra          |
##+---------------+------------------------------------------------------------------------------------------------------------------------------------------+------+-----+---------------------+----------------+
##| ID            | int(11)                                                                                                                                  |      | PRI | NULL                | auto_increment |
##| USERNAME      | varchar(20)                                                                                                                              |      |     | NULL                |                |
##| MID           | int(11)                                                                                                                                  |      | MUL | 0                   |                |
##| AMOUNT        | decimal(10,2)                                                                                                                            |      |     | 0.00                |                |
##| CREATED       | datetime                                                                                                                                 |      |     | 0000-00-00 00:00:00 |                |
##| ACTION        | enum('C','D','')                                                                                                                         |      |     | NULL                |                |
##| MESSAGE       | varchar(80)                                                                                                                              |      |     | NULL                |                |
##| BILLABLE      | enum('FEE_TBD','FVF_TBD','SETUP_WAIVED','SETUP_BILLED','CUSTOM_BILLED','FEE_WAIVED','FEE_BILLED','FVF_WAIVED','FVF_BILLED','AOL_BILLED') | YES  |     | NULL                |                |
##| BUNDLE        | varchar(6)                                                                                                                               |      |     | NULL                |                |
##| SETTLED       | int(11)                                                                                                                                  |      |     | 0                   |                |
##| SETTLEMENT    | int(11)                                                                                                                                  |      |     | 0                   |                |
##| LOCK_ID       | int(11)                                                                                                                                  |      |     | 0                   |                |
##| NO_COMMISSION | tinyint(4)                                                                                                                               |      |     | 0                   |                |
##+---------------+------------------------------------------------------------------------------------------------------------------------------------------+------+-----+-----------------
#	
#	&DBINFO::insert($dbh,'BS_TRANSACTIONS',{
#		USERNAME=>$USERNAME,
#		MID=>$MID,
#		AMOUNT=>7.00,
#		CREATED=>&ZTOOLKIT::mysql_from_unixtime($ts),
#		ACTION=>'D',
#		MESSAGE=>"1yr registration for ".$self->{'DOMAIN'},
#		BILLABLE=>'CUSTOM_BILLED',
#		BUNDLE=>'DNS',
#		NO_COMMISSION=>1,
#		},1);
#
#	$self->{'REG_TYPE'} = 'ZOOVY';
#	$self->{'REG_RENEWAL_GMT'} = &ZTOOLKIT::mysql_from_unixtime($ts)+(365*86400);
#	$self->save();	
#	&DBINFO::db_zoovy_close();	

	}



##
## 
##
sub rewrite {
	my ($URI) = @_;

	

	}


sub flush_memcache {
	my ($self,$memd) = @_;

	$memd = undef;
	my ($MID) = $self->mid();
	if ((defined $self) && ($MID>0)) {
		($memd) = &ZOOVY::getMemd($self->username());
		}
	if (defined $memd) {
		$memd->delete(&DOMAIN::memcache_key($self->domainname()));
		$memd->delete(sprintf("DOMAIN:%s",$self->domainname()));		## old ones!
		$memd->delete(sprintf("DOMAIN::%s",$self->domainname()));
		$memd->delete(sprintf("DOMAIN~%s",$self->domainname()));
		$memd->delete(sprintf("DOMAIN~~%s",$self->domainname()));
		}

	## this will update redis, and should trigger host type updates, etc.
	require DOMAIN::QUERY;
	&DOMAIN::QUERY::rebuild_cache($self->username());
	}

##
##
##
sub save {
	my ($self) = @_;

	my $USERNAME = $self->username();
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	$self->{'MODIFIED_GMT'} = time();
	
	if ($self->{'REG_TYPE'} eq 'VSTORE') {
		## this is username.zoovy.com - settings to webdb as well for backward compatibility		
		}

	my %data = ();
	foreach my $k (keys %{$self}) {
		next if (substr($k,0,1) eq '_');
		next if (substr($k,0,1) eq '#');	## #V
		next if ($k eq 'MXMODE_TXT');
		next if ($k eq 'STATUS_TXT');

		next if (substr($k,0,1) eq '%');	## skip %HOSTS %YAML
		next if ($k =~ /_CONFIG$/);
		next if ($k =~ /_CHKOUT_HOST$/);
		next if ($k =~ /_HOST_TYPE$/);

		$data{$k} = $self->{$k};
		}


	## save all the hosts
	my $userpath = &ZOOVY::resolve_userpath($USERNAME);
	if (defined $self->{'%HOSTS'}) {
		foreach my $HOST (keys %{$self->{'%HOSTS'}}) {
			$HOST = uc($HOST);
			if ($self->{'%HOSTS'}->{$HOST}) {
				delete $self->{'%HOSTS'}->{$HOST}->{'IP4'};
				delete $self->{'%HOSTS'}->{$HOST}->{'SSL_EXPIRES'};
				}
			}

		foreach my $h (values %{$self->{'%HOSTS'}}) {
			next if ($h->{'HOSTTYPE'} eq 'ADMIN');

			## if we have an SSL certificate, then set our CHKOUT
			$h->{'CHKOUT'} = '';
			if (-f sprintf("%s/%s.%s.crt",$userpath,$self->domainname())) {
				$h->{'CHKOUT'} = lc(sprintf("%s.%s",$h->{'HOSTNAME'},$self->domainname()));
				}

			$self->host_set($h->{'HOSTNAME'},%{$h});
			}
		}

	$data{'YAML'} = YAML::Syck::Dump($self->{'%YAML'});
	$data{'EMAIL_CONFIG'} = &ZTOOLKIT::buildparams($self->{'%EMAIL'});
	$data{'EMAIL_TYPE'} = $self->{'%EMAIL'}->{'TYPE'};

	my ($pstmt) = &DBINFO::insert($udbh,'DOMAINS',\%data,key=>['MID','DOMAIN','ID'],debug=>1,sql=>1);
	## print STDERR "$pstmt\n";
	$udbh->do($pstmt);

	## delete record from memcache
	$self->flush_memcache();
	my ($memd) = &ZOOVY::getMemd($USERNAME);
	if (defined $memd) {
   	$memd->set(&DOMAIN::memcache_key($self->domainname()),YAML::Syck::Dump($self));
      }
	&DBINFO::db_user_close();	
	}


## memcache_key("domain.com")
sub memcache_key { return(sprintf("DOMAIN~~%s~%d",lc($_[0]),$DOMAIN::VERSION)); }

##
##
##
sub create {
	my ($class, $USERNAME, $DOMAIN, %options) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	## NEW_DOMAIN what the hell is this? a new domain?
	my $self = {};
	$self->{'ID'} = 0;
	$self->{'DOMAIN'} = $DOMAIN;
	$self->{'USERNAME'} = $USERNAME;
	$self->{'MID'} = $MID;

	$self->{'CREATED_GMT'} = time();
	$self->{'REG_RENEWAL_GMT'} = time()+(86400*350);

	if (defined $options{'PROFILE'}) { 
		$self->{'PROFILE'} = $options{'PROFILE'};
		}
	if (defined $options{'PRT'}) { 
		$self->{'PRT'} = $options{'PRT'};
		}

	if (not defined $options{'REG_TYPE'}) {
		$self->{'REG_TYPE'} = 'OTHER';
		}
	elsif ($options{'REG_TYPE'} eq 'VSTORE') {
		$self->{'REG_TYPE'} = $options{'REG_TYPE'};
		$self->{'STATUS_TXT'} = 'Reserved Domain';
		}
	elsif ($options{'REG_TYPE'} eq 'NEW') { 
		$self->{'REG_TYPE'} = $options{'REG_TYPE'};
		$self->{'STATUS_TXT'} = 'Waiting for Registration';  
		}
	elsif ($options{'REG_TYPE'} eq 'TRANSFER') { 
		$self->{'REG_TYPE'} = $options{'REG_TYPE'};
		$self->{'STATUS_TXT'} = 'Waiting for Transfer';  
		}
	elsif ($options{'REG_TYPE'} eq 'ERROR') {
		$self->{'REG_TYPE'} = $options{'REG_TYPE'};
		}
	elsif ($options{'REG_TYPE'} eq 'WAIT') {
		$self->{'REG_TYPE'} = $options{'REG_TYPE'};
		$self->{'STATUS_TXT'} = 'Waiting for Registration/Transfer';
		}
	elsif ($options{'REG_TYPE'} eq 'OTHER') {
		$self->{'REG_TYPE'} = '';
		$self->{'STATUS_TXT'} = '';
		}
	else {
		$self->{'REG_TYPE'} = '';
		}

	if (not defined $options{'EMAIL_TYPE'}) {
		$self->{'EMAIL_TYPE'} = 'NONE';
		}
	else {
		$self->{'EMAIL_TYPE'} = $options{'EMAIL_TYPE'};
		}

	if (defined $options{'REG_STATE'}) {
		$self->{'REG_STATE'} = $options{'REG_STATE'};
		}

	$self->{'%HOSTS'} = {};

	bless $self, $class;
	$self->save();
	$self->dlog('','INIT',"Domain $DOMAIN initialized");

	return($self);
	}


sub as_legacy_nsref {
	my ($self) = @_;

	my %ref = ();
	foreach my $k (keys %{$self->{'%YAML'}}) {
		next if (substr($k,0,1) ne '%');
		next if (ref($self->{'%YAML'}->{$k}) ne 'HASH');
		if ($k eq '%our') {
			foreach my $kk (keys %{$self->{'%YAML'}->{"%our"}}) {
				$ref{ sprintf("zoovy:%s",$kk) } = $self->{'%YAML'}->{"%our"}->{$kk};
				}
			}
		else {
			foreach my $kk (keys %{ $self->{'%YAML'}->{$k} }){
				$ref{ sprintf("%s:%s",substr($k,1),$kk) } = $self->{'%YAML'}->{$k}->{$kk};
				}
			}
		}
	return(\%ref);
	}

sub from_legacy_nsref {
	my ($self, $nsref) = @_;
	$self->{'%YAML'} = DOMAIN::nsref_to_domainyaml($self->username(),$nsref);
	return($self);
	}

##
##
##
sub nsref_to_domainyaml {
	my ($USERNAME,$nsref) = @_;

	my %ref = ();
	foreach my $k (keys %{$nsref}) {
		next if (lc($k) ne $k);
		next if ($k eq 'zoovy:profile');
		next if ($nsref->{$k} eq '');
		if ($k =~ /(.*?)\:(.*?)$/) {
			my ($owner,$attrib) = ($1,$2);
			if ($k eq '') {
				}
			elsif ($owner eq 'aol') {
				}
			elsif ($owner eq 'veruta') {
				}
			elsif ($owner eq 'zoovy') {
				## zoovy:site_rootcat is deprecated, but still in use for vstore.
				$ref{"%our"}->{$attrib} = $nsref->{$k};
				}
			else {
				$ref{"%$owner"}->{$attrib} = $nsref->{$k};
				}
			}
		}

	return(\%ref);
	}



##
##
##
sub set {
	my ($self,$attrib,$value) = @_;

	if ($attrib eq uc($attrib)) {
	## 	print STDERR "SETTING: $attrib = $value\n";
		if ($self->{$attrib} ne $value) {
			$self->{'_CHANGES'}++;
			$self->{$attrib} = $value;
			}
		}
	elsif ($attrib eq lc($attrib)) {
		my ($owner,$node) = split(/\//,$attrib,2);
		#if (($node eq '') && ($attrib =~ /:/)) {
		#	## legacy zoovy:whatever attrib
		#	($owner,$node) = split(/:/,$attrib,2);
		#	if ($owner eq 'zoovy') { $owner = 'our'; }
		#	}
		if ( $self->{'%YAML'}->{"%$owner"}->{$node} ne $value ) {
			$self->{'_CHANGES'}++;
			$self->{'%YAML'}->{"%$owner"}->{$node} = $value;
			}
		}
	return($self->{'_CHANGES'});	
	}


##
##
## 
sub get {
	my ($self,$attrib) = @_;

	if ($attrib eq uc($attrib)) {
		return($self->{$attrib});
		}
	elsif ($attrib eq lc($attrib)) {
		my ($owner,$node) = split(/\//,$attrib,2);
		#if (($node eq '') && ($attrib =~ /:/)) {
		#	## legacy zoovy:whatever attrib
		#	($owner,$node) = split(/:/,$attrib,2);
		#	if ($owner eq 'zoovy') { $owner = 'our'; }
		#	}
		return( $self->{'%YAML'}->{"%$owner"}->{$node} );
		}
	}



##
## supported options:
##		register=>1
##		transfer=>1
##		SITE=>1 (tells us that we should load site defaults)
##
sub new {
	my ($class, $USERNAME, $DOMAIN, %options) = @_;

	my $self = undef;

	## NOTE: it's safe to assume $USERNAME is always known

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	#$DOMAIN = lc($DOMAIN);
	#if (substr($DOMAIN,0,2) eq 'm.') { $DOMAIN = substr($DOMAIN,2); } # strip leading m.
	#if (substr($DOMAIN,0,4) eq 'www.') { $DOMAIN = substr($DOMAIN,4); } # strip leading www.
	#if (substr($DOMAIN,0,4) eq 'app.') { $DOMAIN = substr($DOMAIN,4); } # strip leading www.
	#if (substr($DOMAIN,0,7) eq 'secure.') { $DOMAIN = substr($DOMAIN,7); } # strip leading secure.

	my $memd = undef;
	if ((defined $options{'cache'}) && ($options{'cache'}==0)) {
		## don't use memcache
		}
	elsif ((not defined $self) && ($MID>0)) {
		($memd) = &ZOOVY::getMemd($USERNAME);
		if (defined $memd) {
			my $yaml = $memd->get(&DOMAIN::memcache_key($DOMAIN));
			if ($yaml ne '') {
				my $BAD_CACHE = 0;
				$self = YAML::Syck::Load($yaml);
				## print STDERR 'CACHE!! '.Dumper($self)."\n";
				if (not defined $self->{'%YAML'}) { $BAD_CACHE |= 1; }
				else {
					foreach my $k (keys %{$self->{'%YAML'}}) { if (ref($self->{'%YAML'}->{$k}) ne 'HASH') { $BAD_CACHE |= 2; } }
					}
				if ($BAD_CACHE) { print STDERR "DOMAIN HAD NO (OR BAD) CACHE!! $BAD_CACHE\n"; $self = undef; }
				}
			}
		if (not defined $self->{'%HOSTS'}) {
			$self = undef;
			}
		}
	

	my $userpath = &ZOOVY::resolve_userpath($USERNAME);
	if ((not defined $self) && ($MID>0)) {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my $qtUSERNAME = $udbh->quote($USERNAME);
		my $pstmt = "SELECT * FROM DOMAINS WHERE MID=$MID /* $qtUSERNAME */ and DOMAIN=".$udbh->quote($DOMAIN);
		($self) = $udbh->selectrow_hashref($pstmt);

		if (not defined $self) {
			}
		elsif ($self->{'YAML'} ne '') {
			## warn "TOOK YAML ROUTE $DOMAIN\n";
			$self->{'%YAML'} = YAML::Syck::Load($self->{'YAML'}); 
			delete $self->{'YAML'};
			if (ref($self->{'%YAML'}->{'%our'}) eq '') {
				warn "CORRUPT DOMAIN!!! (no %our) -- failing back to merchant namespace\n";
				my $nsref = &ZOOVY::LEGACYfetchmerchantns_ref($USERNAME,$self->{'PROFILE'});
				$self->{'%YAML'} = &DOMAIN::nsref_to_domainyaml($USERNAME,$nsref);
				$self->{'%YAML'}->{'%prt'}->{'id'} = $self->{'PRT'};
				}
			$self->{'%YAML'}->{'%prt'}->{'id'} = $self->{'PRT'};
			}

		if (defined $self) {
			$self->{'%EMAIL'} = &ZTOOLKIT::parseparams($self->{'EMAIL_CONFIG'});
			$self->{'%EMAIL'}->{'TYPE'} = $self->{'EMAIL_TYPE'};

			my $pstmt = "select HOSTNAME,HOSTTYPE,CHKOUT,CONFIG from DOMAIN_HOSTS where MID=$MID /* $qtUSERNAME */ and DOMAINNAME=".$udbh->quote($DOMAIN);
			my $sth = $udbh->prepare($pstmt);
			$sth->execute();
			while ( my ($HOSTNAME,$HOSTTYPE,$CHKOUT,$CONFIG) = $sth->fetchrow() ) {
				if (($HOSTTYPE eq 'SITE') || ($HOSTTYPE eq 'SITEPTR')) { $HOSTTYPE = 'VSTORE-APP'; }

				$self->{'%HOSTS'}->{$HOSTNAME} = &ZTOOLKIT::parseparams($CONFIG);
				$self->{'%HOSTS'}->{$HOSTNAME}->{'HOSTNAME'} = $HOSTNAME;
				$self->{'%HOSTS'}->{$HOSTNAME}->{'HOSTTYPE'} = $HOSTTYPE;

				my $CRT_FILE = sprintf("$userpath/%s.%s.crt",lc($HOSTNAME),lc($DOMAIN));
				my $CHKOUT = undef;
				if (-s $CRT_FILE) {
					$CHKOUT = sprintf("%s.%s",lc($HOSTNAME),lc($DOMAIN));
					}
				
				if ($CHKOUT eq '') { $CHKOUT = &ZWEBSITE::domain_to_checkout_domain(sprintf("%s.%s",lc($HOSTNAME),$DOMAIN)); }
				$self->{'%HOSTS'}->{$HOSTNAME}->{'CHKOUT'} = $CHKOUT;
				}
			$sth->finish();
			}

		if (defined $self) {
			$self->{'%HOSTS'}->{'ADMIN'} = {
				'HOSTNAME'=>'ADMIN',
				'HOSTTYPE'=>'ADMIN'
				};

			}
	
		if (defined $self) {
			$self->{'#V'} = $DOMAIN::VERSION;	

  	    	if (defined $memd) {
  	     		$memd->set(&DOMAIN::memcache_key($DOMAIN),YAML::Syck::Dump($self));
  				}	
			}

		&DBINFO::db_user_close();
		}

	if (not defined $self) {
		return(undef);
		}
	else {
		## YAY!
		bless $self, 'DOMAIN';
		return($self);
		}
	}


##
## removes a domain and all it's references from the database.
##
sub nuke {
	my ($self,%options) = @_;

	if ((not defined $options{'*LU'}) || (ref($options{'*LU'}) ne 'LUSER')) {
		die("Can't nuke domains without *LU being passed for logging.");
		}
	else {
		$options{'*LU'}->log("DOMAIN.NUKE","deleted domain: ".lc($self->{'DOMAIN'}),'INFO');
		$options{'LUSER'} = $options{'*LU'}->luser();
		}

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $MID = &ZOOVY::resolve_mid($self->username());
	my $qtDOMAIN = $udbh->quote(lc($self->{'DOMAIN'}));

	$self->dlog('WARN','Deleted Domain',LUSER=>$options{'LUSER'});

	my @sql = ();
	push @sql, "start transaction";
	push @sql, "delete from DOMAINS_EMAIL_ALIAS where MID=$MID /* $self->{'USERNAME'} */ and DOMAIN=$qtDOMAIN";
	push @sql, "delete from DOMAINS_URL_MAP where MID=$MID /* $self->{'USERNAME'} */ and DOMAIN=$qtDOMAIN";
	push @sql, "delete from DOMAIN_HOSTS where MID=$MID /* $self->{'USERNAME'} */ and DOMAIN=$qtDOMAIN";
	push @sql, "delete from DOMAINS where MID=$MID /* $self->{'USERNAME'} */ and DOMAIN=$qtDOMAIN";
	## IS_DELETED_GMT ??
	push @sql, "commit";

	foreach my $pstmt (@sql) {
		$udbh->do($pstmt);
		}
	
	&DBINFO::db_user_close();
	return(1);
	}

#CREATE TABLE OMAINS_EMAIL_ALIAS (
#  	D int(11) NOT NULL auto_increment,
#  SERNAME varchar(20) NOT NULL default '',
#  ID int(10) unsigned NOT NULL default '0',
#  OMAIN varchar(64) NOT NULL default '',
#  ALIAS varchar(50) default '' not null,
#  ARGET_EMAIL varchar(129) NOT NULL default '',
#  UTORESPONDER tinyint(4) NOT NULL default '0',
#  UTORESPONDER_MSG mediumtext NOT NULL,
#  	S_NEWSLETTER tinyint(4) NOT NULL default '0',
#  PRIMARY KEY  (	D),
#  unique key(MID,DOMAIN,ALIAS)
#);

##
## options can be:
##		AUTORESPONDER_MSG=>'text'
##		NEWSLETTER=>1|0
#sub add_alias {
#	my ($self,$ALIAS,$TARGET,%options) = @_;
#
#	if (not defined $options{'AUTORESPONDER_MSG'}) { $options{'AUTORESPONDER_MSG'} = ''; }
#	my $AUTORESPONDER = ($options{'AUTORESPONDER_MSG'} ne '')?1:0;
#	my $NEWSLETTER = int($options{'NEWSLETTER'});
#	if ($NEWSLETTER) { $TARGET = 'admin@'.$self->{'USERNAME'}.'.zoovy.com'; }
#
#	if (index($ALIAS,'@')>=0) { 
#		# strip anything after the @
#		$ALIAS =~ s/^(.*?)\@.*$/$1/s;
#		}
#	$ALIAS =~ s/[^\w]+/_/gs;
#
#	my ($udbh) = &DBINFO::db_user_connect($self->username());
#	&DBINFO::insert($udbh,'DOMAINS_EMAIL_ALIAS',{
#		USERNAME=>$self->{'USERNAME'},
#		MID=>$self->{'MID'},
#		DOMAIN=>$self->{'DOMAIN'},
#		ALIAS=>$ALIAS,TARGET_EMAIL=>$TARGET,
#		IS_NEWSLETTER=>$NEWSLETTER,
#		AUTORESPONDER=>$AUTORESPONDER, AUTORESPONDER_MSG=>$options{'AUTORESPONDER_MSG'}
#		},debug=>1,key=>['MID','DOMAIN','ALIAS']);
#	&DBINFO::db_user_close();
#	}

##
## deletes an alias e.g. brian@
##
#sub del_alias {
#	my ($self, $ALIAS) = @_;
#
#	my $MID = $self->{'MID'};
#	my ($udbh) = &DBINFO::db_user_connect($self->username());
#	my $pstmt = "delete from DOMAINS_EMAIL_ALIAS where MID=$MID /* $self->{'USERNAME'} */ and DOMAIN=".$udbh->quote($self->{'DOMAIN'})." and ALIAS=".$udbh->quote($ALIAS);
##	print STDERR $pstmt."\n";
#	$udbh->do($pstmt);
#	&DBINFO::db_user_close();
#	}

##
## provides a list of aliases.
##
#sub aliases {
#	my ($self) = @_;
#
#	my $udbh = &DBINFO::db_user_connect($self->username());
#	my @result = ();
#
#	my $MID = $self->{'MID'};
#	my $pstmt = "select ALIAS,TARGET_EMAIL,AUTORESPONDER,AUTORESPONDER_MSG,IS_NEWSLETTER from DOMAINS_EMAIL_ALIAS where MID=$MID and DOMAIN=".$udbh->quote($self->{'DOMAIN'});
#	my $sthx = $udbh->prepare($pstmt);
#	$sthx->execute();
#	if ($sthx->rows()) {
#		while ( my $emailinfo = $sthx->fetchrow_hashref() ) {
#			push @result, $emailinfo;
#			}
#		}
#	$sthx->finish();
#	&DBINFO::db_user_close();
#
#	return(\@result);
#	}

##
#CREATE TABLE OMAINS_URL_MAP (
#  	D int(11) NOT NULL auto_increment,
#  SERNAME varchar(20) NOT NULL default '',
#  MID integer default 0 not null, 
#  OMAIN varchar(50) NOT NULL default '',
#  ATH varchar(100) NOT NULL default '',
#  ARGETURL varchar(200) NOT NULL default '',
#  REATED datetime default '0000-00-00 00:00:00',
#  PRIMARY KEY  (	D),
#  UNIQUE KEY ATH (ID,OMAIN,ATH)
#) ENGINE=MyISAM;
##
## options can be:
##		AUTORESPONDER_MSG=>'text'
##		NEWSLETTER=>1|0
sub add_map {
	my ($self,$PATH,$TARGETURL,%options) = @_;

	if (substr($PATH,0,1) ne '/') { $PATH = '/'.$PATH; }
	if ($TARGETURL =~ /^[Hh][Tt][Tt][Pp][s]?:\/\//) {
		## we're redirecting to a site, rather than a URL of the same target.
		}
	elsif (substr($TARGETURL,0,1) ne '/') { 
		$TARGETURL = '/'.$TARGETURL; 
		}

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	&DBINFO::insert($udbh,'DOMAINS_URL_MAP',{
		USERNAME=>$self->{'USERNAME'},
		MID=>$self->{'MID'},
		DOMAIN=>$self->{'DOMAIN'},
		PATH=>$PATH,
		TARGETURL=>$TARGETURL,
		},debug=>1,key=>['MID','DOMAIN','PATH']);
	&DBINFO::db_user_close();
	}

##
## deletes an maps e.g. brian@
##
sub del_map {
	my ($self, $PATH) = @_;

	my $MID = $self->{'MID'};
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $pstmt = "delete from DOMAINS_URL_MAP where MID=$MID /* $self->{'USERNAME'} */ and DOMAIN=".$udbh->quote($self->{'DOMAIN'})." and PATH=".$udbh->quote($PATH);
#	print STDERR $pstmt."\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	}

##
## provides a list of mapses.
##
sub maps {
	my ($self) = @_;

	my $udbh = &DBINFO::db_user_connect($self->username());
	my @result = ();

	my $MID = $self->{'MID'};
	my $pstmt = "select PATH,TARGETURL,CREATED from DOMAINS_URL_MAP where MID=$MID and DOMAIN=".$udbh->quote($self->{'DOMAIN'});
	my $sthx = $udbh->prepare($pstmt);
	$sthx->execute();
	if ($sthx->rows()) {
		while ( my $emailinfo = $sthx->fetchrow_hashref() ) {
			push @result, $emailinfo;
			}
		}
	$sthx->finish();
	&DBINFO::db_user_close();

	return(\@result);
	}


##
## I have no idea what these class variables mean.
##		class bitwise values seem to be:
##			2 = info (displayable to user)
##			1 = error
sub dlog {
	my ($self,$class,$txt,%options) = @_;

	if (not defined $txt) { $txt = ''; }

	my $udbh = &DBINFO::db_user_connect($self->username());
#mysql> desc DOMAINS_LOG;
#+-------------+---------------------+------+-----+---------+----------------+
#| Field       | Type                | Null | Key | Default | Extra          |
#+-------------+---------------------+------+-----+---------+----------------+
#| ID          | int(11)             |      | PRI | NULL    | auto_increment |
#| MID         | int(11)             |      | MUL | 0       |                |
#| DOMAIN      | varchar(50)         |      |     | NULL    |                |
#| CREATED_GMT | int(11)             |      |     | 0       |                |
#| CLASS       | tinyint(3) unsigned |      |     | 0       |                |
#| TXT         | varchar(50)         |      |     | NULL    |                |
#+-------------+---------------------+------+-----+---------+----------------+
#6 rows in set (0.00 sec)
	my ($pstmt) = &DBINFO::insert($udbh,'DOMAIN_LOGS',{
		MID=>$self->mid(),
		DOMAIN=>$self->domainname(),
		HOST=>sprintf("%s",$options{'HOST'}),
		LUSER=>sprintf("%s",$options{'LUSER'}),
		'*CREATED_TS'=>'now()',
		MSGTYPE=>$class,
		MSG=>$txt,
		},verb=>'insert',sql=>1);
	## print STDERR "$pstmt\n";
	$udbh->do($pstmt);

	&DBINFO::db_user_close();
	}




1;