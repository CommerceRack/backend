package DOMAIN::QUERY;

use strict;

use Storable;
use Data::Dumper;
use Net::DNS;
use lib "/backend/lib";
require ZOOVY;
require ZWEBSITE;
require DOMAIN;



##  perl -e 'use lib "/backend/lib"; use DOMAIN::QUERY; use Data::Dumper; print Dumper(DOMAIN::QUERY::lookup("brian.zoovy.com"));'
##  perl -e 'use lib "/backend/lib"; use DOMAIN::QUERY; use Data::Dumper; my @LOG = (); print Dumper(DOMAIN::QUERY::lookup("brian.zoovy.com","\@LOG"=>\@LOG),\@LOG);'


## TO CLEAR KEYS: redis-cli KEYS "domain+*" | xargs redis-cli DEL
sub lookup_userref {
	my ($DOMAIN,$HOST) = @_;

	$DOMAIN = lc($DOMAIN);
	if ($DOMAIN eq '') { return(undef); }

	## print STDERR "lookup_userref DOMAIN:[$DOMAIN]\n";

	## okay first try and find the username in the global hint file, if we can't we'll default to the global list
	my ($redis) = &ZOOVY::getRedis();
	my @LOOKUPS = ();

	$DOMAIN = lc($DOMAIN);
	if ($HOST ne '') { 
		push @LOOKUPS, sprintf("%s.%s",lc($HOST)); 
		push @LOOKUPS, sprintf("%s",lc($DOMAIN));
		}
	elsif (not defined $HOST) {
		push @LOOKUPS, sprintf("%s",lc($DOMAIN));
		my @DOMAINPARTS = split(/\./,$DOMAIN);
		if (scalar(@DOMAINPARTS)>1) { shift @DOMAINPARTS; push @LOOKUPS, join(".",@DOMAINPARTS); }
		}
	else {
		push @LOOKUPS, sprintf("%s",lc($DOMAIN));
		}
	# print STDERR Dumper(\@LOOKUPS);
	
	my $RESULT = undef;
	foreach my $tryDOMAIN (@LOOKUPS) {
		next if (defined $RESULT); 
		my %RESULT = $redis->hgetall("domain+$DOMAIN");
		$RESULT = \%RESULT;
		}
	
	return($RESULT);
	}


##
##
##
sub rebuild_cache {
	my ($USERNAME) = @_;

	my $ROWS = [];
	my ($redis) = &ZOOVY::getRedis($USERNAME);

	my @DOMAINS = ();
	my ($CFG) = CFG->new();

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select DOMAIN,USERNAME,PRT from DOMAINS where MID=$MID";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $ref = $sth->fetchrow_hashref() ) {
		push @{$ROWS}, $ref;
		}
	$sth->finish();

	##########################################################
	## setup hosting for static---$USERNAME.app-hosted.com
	my $MEDIA_HOST = &ZOOVY::resolve_media_host($USERNAME);
	$redis->hset(lc("domain+$MEDIA_HOST"),"USERNAME",$USERNAME);
	$redis->hset(lc("domain+$MEDIA_HOST"),"PRT",0);
	$redis->hset(lc("domain+$MEDIA_HOST"),"HOSTTYPE","MEDIA");

	##########################################################
	## setup hosting for admin---$USERNAME.app-hosted.com
	my $ADMIN_HOST = &ZOOVY::resolve_admin_host($USERNAME);
	$redis->hset(lc("domain+$ADMIN_HOST"),"USERNAME",$USERNAME);
	$redis->hset(lc("domain+$ADMIN_HOST"),"PRT",0);
	$redis->hset(lc("domain+$ADMIN_HOST"),"HOSTTYPE","ADMIN");

	my %CACHE = (); 
	foreach my $REF (@{$ROWS}) {
		my ($DOMAIN,$USERNAME,$PRT) = ($REF->{'DOMAIN'},$REF->{'USERNAME'},$REF->{'PRT'});
		$DOMAIN = lc($DOMAIN);
		## print STDERR "DOMAIN:$DOMAIN\n";
		push @DOMAINS, $DOMAIN;
	
		my $userpath = &ZOOVY::resolve_userpath($USERNAME);

		my %REF = ();
		$REF{'DOMAIN'} = $DOMAIN;			
		$REF{'USERNAME'} = $USERNAME;
		$REF{'PRT'} = $PRT;
		$REF{'MID'} = my $MID = &ZOOVY::resolve_mid($USERNAME);

		$REF{'vip.public'} = $CFG->get('global','vip.public');
		$REF{'vip.private'} = $CFG->get('global','vip.private');

		#########################################################
		## setup domain.com to redirect to www.domain.com
		$redis->hset(lc("domain+$DOMAIN"),"USERNAME",$USERNAME);
		$redis->hset(lc("domain+$DOMAIN"),"PRT",$PRT);
		$redis->hset(lc("domain+$DOMAIN"),"HOSTTYPE","REDIR");
		$redis->hset(lc("domain+$DOMAIN"),"TARGETPATH","http://www.$DOMAIN");
		$redis->hset(lc("domain+$DOMAIN"),"DOMAIN",$DOMAIN);
			
		#+------------+-----------------------------------------------------------+------+-----+-------------------+-----------------------------+
		#| Field      | Type                                                      | Null | Key | Default           | Extra                       |
		#+------------+-----------------------------------------------------------+------+-----+-------------------+-----------------------------+
		#| CREATED_TS | timestamp                                                 | NO   |     | CURRENT_TIMESTAMP | on update CURRENT_TIMESTAMP |
		#| MID        | int(10) unsigned                                          | NO   | PRI | 0                 |                             |
		#| DOMAINNAME | varchar(50)                                               | NO   | PRI |                   |                             |
		#| HOSTNAME   | varchar(10)                                               | NO   | PRI |                   |                             |
		#| HOSTTYPE   | enum('APP','SITE','SITEPTR','VSTORE','REDIR','CUSTOM','') | YES  |     | NULL              |                             |
		#| CONFIG     | tinytext                                                  | YES  |     | NULL              |                             |
		#| CHKOUT     | varchar(65)                                               | NO   |     |                   |                             |
		#+------------+-----------------------------------------------------------+------+-----+-------------------+-----------------------------+
		my $pstmt = "select HOSTNAME,HOSTTYPE,CONFIG from DOMAIN_HOSTS where MID=$MID and DOMAINNAME=".$udbh->quote($DOMAIN);
		my $sthx = $udbh->prepare($pstmt);
		$sthx->execute();
		$REF{'%HOSTS'} = {};
		while ( my ($HOSTNAME,$HOSTTYPE,$CONFIG) = $sthx->fetchrow() ) {
			## print "HOSTNAME:$HOSTNAME.$DOMAIN\n";
			$HOSTNAME = uc($HOSTNAME);
			## REDIR=, URI=
			my %HOST = %{&ZTOOLKIT::parseparams($CONFIG)};
			$HOST{'DOMAIN'} = $DOMAIN;
			if ($HOSTTYPE eq '') { $HOSTTYPE = 'VSTORE'; }
			if (($HOSTTYPE eq 'SITE') || ($HOSTTYPE eq 'SITEPTR')) { $HOSTTYPE = 'VSTORE-APP'; }
			$HOST{'HOSTNAME'} = $HOSTNAME;
			$HOST{'HOSTTYPE'} = $HOSTTYPE;
			$HOST{'CANONICAL'} = sprintf("www.%s",$DOMAIN);
			#if (-f "$userpath/$HOSTNAME.$DOMAIN.pem") {
			#	$HOST{'ssl_pem'} = "$userpath/$HOSTNAME.$DOMAIN.key";
			#	}
			my $CRT_FILE = sprintf("$userpath/%s.%s.crt",lc($HOSTNAME),lc($DOMAIN));
			my $CHKOUT = undef;
			if (-s $CRT_FILE) {
				$CHKOUT = sprintf("%s.%s",lc($HOSTNAME),lc($DOMAIN));
				$HOST{'ssl_pem'} = "$userpath/$HOSTNAME.$DOMAIN.crt";
				}

			$HOST{'vip.private'} = $CFG->get(sprintf("%s.%s",$HOSTNAME,$DOMAIN),"vip.private") || $REF{'vip.private'};
			$HOST{'vip.public'} = $CFG->get(sprintf("%s.%s",$HOSTNAME,$DOMAIN),"vip.public") || $REF{'vip.public'};
		
			

			## print "HOSTTYPE: $HOSTTYPE\n";
			if ($HOSTTYPE !~ /^(APP|VSTORE-APP|VSTORE)/) {
				## no need for a CHKOUT 
				}
			elsif ($CHKOUT ne '') {
				## CHKOUT is set, use it.
				$HOST{'CANONICAL'} = sprintf("www.%s",$DOMAIN);
				$HOST{'CHKOUT'} = $CHKOUT;
				}
			else {
				## we're probably using an alias wildcard domain (ex: www-domain-com.ssl-wildcard.com)
				$HOST{'CANONICAL'} = sprintf("www.%s",$DOMAIN);
				$HOST{'CHKOUT'} = &ZWEBSITE::domain_to_checkout_domain(sprintf("%s.%s",lc($HOSTNAME),$DOMAIN)); 
				}


			$REF{'%HOSTS'}->{uc($HOSTNAME)} = \%HOST;
			}
		$sthx->finish();

		if (not defined $REF{'%HOSTS'}->{'ADMIN'}) {
			$REF{'%HOSTS'}->{'ADMIN'} = {
				'HOSTNAME'=>'ADMIN',
				'HOSTTYPE'=>'REDIR',
				'REDIR'=>sprintf("https://%s:9000",&ZWEBSITE::domain_to_checkout_domain(sprintf("www.%s",lc($DOMAIN)) ))
				};
			}

		foreach my $HOST (values %{$REF{'%HOSTS'}}) {
			my $HOSTNAME = $HOST->{'HOSTNAME'};
			my $HOSTTYPE = $HOST->{'HOSTTYPE'};
			if (($HOSTTYPE eq 'SITE') || ($HOSTTYPE eq 'SITEPTR')) { $HOSTTYPE = 'VSTORE-APP'; }

			my %HKEY = ();

			foreach my $k (keys %{$HOST}) { $HKEY{uc($k)} = $HOST->{$k}; }
			$HKEY{"USERNAME"} = $USERNAME;	
			$HKEY{"PRT"} = $PRT;
			if ($HOSTTYPE eq 'APPTIMIZER') {
				$HKEY{'PROJECT'} = $HOST->{'PROJECT'};
				}
			elsif ($HOSTTYPE eq 'VSTORE-APP') {
				$HKEY{"HOSTTYPE"} = "VSTORE-APP";
				my $PROJECTDIR = sprintf("%s/PROJECTS/%s",&ZOOVY::resolve_userpath($USERNAME),$HOST->{'PROJECT'});
				$HKEY{"TARGETPATH"} = $PROJECTDIR;
				}
			elsif ($HOSTTYPE eq 'REDIR') {
				$HKEY{"HOSTTYPE"} = uc($HOSTTYPE);
				$HKEY{"TARGETPATH"} = $HOST->{'REDIR'} || "/#!REDIR_NOT_SET";
				}
			else {
				$HKEY{"HOSTTYPE"} = uc($HOSTTYPE);
				$HKEY{"TARGETPATH"} = "";
				}

			## print STDERR "HOST:$HOSTNAME.$DOMAIN\n";
			my $HOSTDOMAIN = lc(sprintf("%s.%s",$HOSTNAME,$DOMAIN));
			foreach my $key (sort keys %HKEY) {		
				next if (substr($key,0,1) eq '_');
				$redis->hset(lc("domain+$HOSTDOMAIN"),$key,$HKEY{$key});
				}

			my $CHKOUT = &ZWEBSITE::domain_to_checkout_domain($HOSTDOMAIN);
			## REGISTER WILDCARD DOPPLEGANGER HOST FOR CHECKOUT
			print STDERR "HOST:$CHKOUT\n";
			$HKEY{'IS_CANONICAL'} = 0;		## this is not the canonical (root)
			$HKEY{'vip.private'} = $CFG->get("$CHKOUT","vip.private") || $REF{'vip.private'};
			$HKEY{'vip.public'} = $CFG->get("$CHKOUT","vip.public") || $REF{'vip.public'};
			foreach my $key (sort keys %HKEY) {
				next if (substr($key,0,1) eq '_');
				$redis->hset(lc("domain+$CHKOUT"),$key,$HKEY{$key});
				}

			}
		}

	&DBINFO::db_user_close();
	return(\@DOMAINS);
	}



##
## options:
##		cache => allow cached lookups (usually okay)
##		dns => use dns for lookup (usually okay)
##		verify => verify the results in the database 
##
sub lookup {
	my ($DOMAIN,%options) = @_;

	my ($USERREF) = &DOMAIN::QUERY::lookup_userref($DOMAIN,$options{'HOST'});
	## print STDERR "USERREF ".Dumper($USERREF);

	if (not defined $USERREF) {
		warn "&DOMAIN::QUERY::lookup_userref failed on host=[$options{'HOST'}.domain=$DOMAIN]\n";
		return(undef);
		}
	else {
		## let's figure out if we're looking up a domain, or a host
		my $HOST = $options{'HOST'} || $USERREF->{'HOSTNAME'} || 'WWW'; 	
		my ($D) = DOMAIN->new($USERREF->{'USERNAME'}, $USERREF->{'DOMAIN'});
		$D->{'HOST'} = $HOST;
		$D->{'PROJECT'} = $D->{'%HOSTS'}->{ uc($HOST) }->{'PROJECT'};
		return($D);
		}
	}

1;

__DATA__


##
## options:
##		cache => allow cached lookups (usually okay)
##		dns => use dns for lookup (usually okay)
##		verify => verify the results in the database 
##
sub lookupOLD {
	my ($DOMAIN,%options) = @_;

	$DOMAIN = lc($DOMAIN);
	my @DOMAINPARTS = split(/\./,$DOMAIN);
	my $DOMAIN_HOST = $DOMAINPARTS[0];
	my $DOMAIN_WITHOUT_HOST = join(".",splice(@DOMAINPARTS,1));

	my $RESULT = undef;

	my $LOG = undef;
	if ($options{'@LOG'}) { $LOG = $options{'@LOG'}; }

	if (defined $RESULT) {
		## already got an answer!
		}
	elsif ((defined $options{'cache'}) && ($options{'cache'}==0)) {
		## no caching!
		if (defined $LOG) { push @{$LOG}, "cache disabled"; }
		}
	elsif (-f $DOMAIN::QUERY::CACHE_FILE) {
		## try just domain.com if this works then we return:
		
		my $ref = undef;
		if (defined $DOMAIN::QUERY::CACHE_REF) { 
			## use in memory cache
			$ref = $DOMAIN::QUERY::CACHE_REF;
			if ($DOMAIN::QUERY::CACHE_TS < time()-600) {
				$ref = undef;
				}
			}
		
		if (not defined $ref) {
			$ref = $DOMAIN::QUERY::CACHE_REF = retrieve $DOMAIN::QUERY::CACHE_FILE;
			$DOMAIN::QUERY::CACHE_TS = time();
			}

		if (defined $ref->{$DOMAIN_WITHOUT_HOST}) {
			if (defined $LOG) { push @{$LOG}, "HIT CACHE $DOMAIN_WITHOUT_HOST (HOST=$DOMAIN_HOST)"; }
			$RESULT = $ref->{$DOMAIN_WITHOUT_HOST};
			if (defined $RESULT) { $RESULT->{'HOST'} = $DOMAIN_HOST; }
			}
		else {
			if (defined $LOG) { push @{$LOG}, "MISS CACHE $DOMAIN_WITHOUT_HOST"; }
			}

		if (defined $RESULT) {
			if (defined $LOG) { push @{$LOG}, "SKIP CACHE PLAIN DOMAIN LOOKUP (ALREADY GOT A HIT)"; }			
			}
		elsif (defined $ref->{$DOMAIN}) {
			if (defined $LOG) { push @{$LOG}, "HIT CACHE $DOMAIN (HOST=NONE)"; }
			$RESULT = $ref->{$DOMAIN};
			if (defined $RESULT) { $RESULT->{'HOST'} = 'NONE'; }
			}
		else {
			if (defined $LOG) { push @{$LOG}, "MISS CACHE $DOMAIN"; }
			}
		}
	else {
		warn "NO DOMAIN::QUERY::CACHE_FILE\n";
		}

	if (defined $RESULT) {
		## already got an answer!
		}
	elsif ((defined $options{'dns'}) && ($options{'dns'}==0)) {
		## no caching!
		if (defined $LOG) { push @{$LOG}, "SKIP - DNS lookups disabled"; }
		}
	elsif ($DOMAIN_WITHOUT_HOST eq '') {
		warn "attempted to do a domain lookup without a host\n";
		}
	else {
		}

	if (defined $RESULT) {
		}
	elsif ((defined $options{'dns'}) && ($options{'dns'} == 0)) {
		## dns lookups are not wanted, so no need to try www.
		}
	elsif ((defined $options{'retrywww'}) && ($options{'retrywww'}==0)) {
		}
	elsif ($DOMAIN_HOST eq 'www') {
		## this already was a www.
		}
	else {
		## RETRY WWW
		if (defined $LOG) { push @{$LOG}, "RETRY DNS www.$DOMAIN"; }
		$RESULT = &DOMAIN::QUERY::lookup("www.$DOMAIN",'cache'=>0,'retrywww'=>0);
		}


	if (defined $RESULT) {
		}
	elsif ((defined $options{'dns'}) && ($options{'dns'}==0)) {
		## we don't have a RESULT because DNS was disabled, let's fix that.
		if (not defined $options{'USERNAME'}) {
			if (defined $LOG) { push @{$LOG}, "INTERNAL API ERROR - MUST PASS USERNAME WHEN DNS IS DISABLED"; }
			}
		else {
			$RESULT = { 'DOMAIN'=>$DOMAIN, 'USERNAME'=>$options{'USERNAME'}, 'SRC'=>'GUESS_WITHOUT_DNS' };		
			}
		}


	if ( (not defined $options{'verify'}) || (int($options{'verify'})==0)) {
		if (defined $LOG) { push @{$LOG}, "SKIP VERIFY - NOT NECESSARY"; }
		}
	elsif (not defined $RESULT) {
		if (defined $LOG) { push @{$LOG}, "SKIP VERIFY - NO DATA"; }
		}
	elsif ($RESULT->{'USERNAME'} eq '') {
		## this prevents GET http://vstore/__health__ from doing a db/lookup and fail
		}
	elsif ($options{'verify'}>0) {

		## NOTE: eventually we should implement a memcache here.
		my ($memd) = &ZOOVY::getMemd($RESULT->{'USERNAME'});
		my $ref = undef;

		# $memd->delete(sprintf("DOMAIN:%s",$RESULT->{'DOMAIN'}));

		if ((defined $options{'cache'}) && ($options{'cache'}==0)) {
			## no caching!
			}
		elsif (defined $memd) {			
			$ref = $memd->get(sprintf("DOMAIN:%s",$RESULT->{'DOMAIN'}));
			if (defined $ref) {
				## verify we got a valid result
				if (ref($ref) ne 'HASH') { $ref = undef; }
				}

			if (defined $ref) {
				if (defined $LOG) { push @{$LOG}, "HIT DOMAIN DETAIL IN MEMCACHE"; }
				}
			else {
				if (defined $LOG) { push @{$LOG}, "MISS DOMAIN DETAIL IN MEMCACHE"; }
				}
			}

		if (not defined $ref) {		
			my ($MID) = &ZOOVY::resolve_mid($RESULT->{'USERNAME'});
			my ($udbh) = &DBINFO::db_user_connect($RESULT->{'USERNAME'});
			my $pstmt = sprintf("/* X */ select * from DOMAINS where MID=%d /* %s */ and DOMAIN=%s",$MID,$udbh->quote($RESULT->{'USERNAME'}),$udbh->quote($RESULT->{'DOMAIN'}));
			print STDERR "$pstmt\n";

			if (defined $LOG) { push @{$LOG}, "SQL: $pstmt"; }
			$ref = $udbh->selectrow_hashref($pstmt);
			&DBINFO::db_user_close();

			if (not defined $memd) {
				}
			elsif ((not defined $options{'cache'}) || ($options{'cache'}==0)) {
				}
			else {
				## cache VERIFY in memcache
				if (defined $LOG) { push @{$LOG}, "UPDATE MEMCACHE"; }
				$memd->set(sprintf("DOMAIN:%s",$RESULT->{'DOMAIN'}),$ref);
				}			
			}

		if (not defined $ref) {
			if (defined $LOG) { push @{$LOG}, "FAIL ON VERIFY - NO RECORD FOR DOMAIN: $RESULT->{'DOMAIN'}"; }
			}
		else {
			# if (defined $LOG) { push @{$LOG}, "BEGIN VERIFY"; }
			foreach my $k (sort keys %{$ref}) {
				if (not defined $RESULT->{$k}) {
					## new value
					# if (defined $LOG) { push @{$LOG}, sprintf("- %s is[%s]",$k,$ref->{$k}); }
					$RESULT->{$k} = $ref->{$k};
					}
				elsif ($RESULT->{$k} eq $ref->{$k}) {
					## values are the same
					}
				else {
					## values are different
					if (defined $LOG) { push @{$LOG}, sprintf("- %s was[%s] is[%s]",$k,$RESULT->{$k},$ref->{$k}); }
					$RESULT->{$k} = $ref->{$k};
					}
				}
			# if (defined $LOG) { push @{$LOG}, "END VERIFY"; }
			}
		}


	return($RESULT);
	}



1;



