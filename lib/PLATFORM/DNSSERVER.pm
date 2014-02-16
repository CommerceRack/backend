package PLATFORM::DNSSERVER;

use Data::Dumper;

%PLATFORM::DNSSERVER::CMDS = (
	'dns-domain-update'=>\&PLATFORM::DNSSERVER::dns_domain_update,	
	'dns-domain-delete'=>\&PLATFORM::DNSSERVER::dns_delete,
	'dns-wildcard-reserve'=>\&PLATFORM::DNSSERVER::dns_wildcard_reserve,
	'dns-user-delete'=>\&PLATFORM::DNSSERVER::dns_delete
	);


sub new {
	my ($CLASS) = @_;
	my ($self) = {};
	bless $self, $CLASS;
	return($self);
	}


sub register_cmds {
	my ($self,$CMDSREF) = @_;
	foreach my $cmd (keys %PLATFORM::DNSSERVER::CMDS) {		
		print ref($self)." registered $cmd\n";
		$CMDSREF->{ $cmd } = $PLATFORM::DNSSERVER::CMDS{$cmd};
		}
	return();
	}


################
#mysql> desc dns_records;
#+-------------+---------------------+------+-----+---------+----------------+
#| Field       | Type                | Null | Key | Default | Extra          |
#+-------------+---------------------+------+-----+---------+----------------+
#| id          | int(10) unsigned    | NO   | PRI | NULL    | auto_increment |
#| zone        | varchar(64)         | NO   | MUL |         |                |
#| host        | varchar(20)         | NO   |     |         |                |
#| type        | varchar(10)         | NO   |     |         |                |
#| data        | text                | NO   |     | NULL    |                |
#| ttl         | int(10) unsigned    | NO   |     | 0       |                |
#| mx_priority | tinyint(3) unsigned | NO   |     | 0       |                |
#| refresh     | int(10) unsigned    | NO   |     | 0       |                |
#| retry       | int(10) unsigned    | NO   |     | 0       |                |
#| expire      | int(10) unsigned    | NO   |     | 0       |                |
#| serial      | bigint(20)          | NO   |     | 0       |                |
#| resp_person | varchar(100)        | NO   |     |         |                |
#| primary_ns  | tinytext            | NO   |     | NULL    |                |
#| MID         | int(10) unsigned    | NO   |     | 0       |                |
#| USERNAME    | varchar(20)         | NO   |     |         |                |
#| CLUSTER     | varchar(10)         | NO   |     |         |                |
#+-------------+---------------------+------+-----+---------+----------------+
#16 rows in set (0.07 sec)


sub dnsdump {
	my ($CFG,$IN) = @_;
	my %OUT = ();
	return(\%OUT);
	}
	
sub dns_delete {
	my ($CFG,$IN) = @_;
	
	my $dbh = $CFG->{'*dbh'};
	my $pstmt = undef;

	if ($IN->{'USERNAME'} ne '') {	
		$pstmt = "delete from dns_records where USERNAME=".$dbh->quote($IN->{'USERNAME'});
		if ($IN->{'_cmd'} eq 'dns-domain-delete') { $pstmt .= " and DOMAIN=".$dbh->quote($IN->{'DOMAIN'}); }
		print $pstmt."\n";
		$dbh->do($pstmt);
		}
		
	if ($IN->{'MID'}>0) {
		$pstmt = "delete from dns_records where MID=".int($IN->{'MID'});
		if ($IN->{'_cmd'} eq 'dns-domain-delete') { $pstmt .= " and DOMAIN=".$dbh->quote($IN->{'DOMAIN'}); }
		print $pstmt."\n";
		$dbh->do($pstmt);
		}
	
	if ($IN->{'_cmd'} eq 'dns-domain-delete') {
		return({ 'err'=>0, msg=>sprintf("deleted domain %s",$IN->{'DOMAIN'}) });
		}
	else {
		return({ 'err'=>0, msg=>sprintf("deleted user %s",$IN->{'USERNAME'}) });
		}
	}


##
##
##
sub dns_wildcard_reserve {
	my ($CFG,$IN) = @_;

	my $OUT = undef;
	my $dbh = $CFG->{'*dbh'};
	my $pstmt = undef;
	
	if (not defined $IN->{'DOMAIN'}) { $IN->{'DOMAIN'} = ''; }
	$dbh->do("start transaction");
	
	my $HOSTDOMAIN = sprintf("%s.%s",$IN->{'host'},$IN->{'zone'});
	
	$pstmt = "delete from dns_records where DOMAIN=".$dbh->quote($IN->{'DOMAIN'})." and MID=".int($IN->{'MID'})." and host='\@' and zone=".$dbh->quote($HOSTDOMAIN);
	print $pstmt."\n";
	$dbh->do($pstmt);

	## Add an SOA record.
	$pstmt = &DBINFO_insert($dbh,'dns_records',{
		'zone'=>$HOSTDOMAIN,
		'host'=>'@',
		'ttl'=>3600,
		'serial'=>time(),refresh=>28800, retry=>3600, expire=>6048000, minimum=>3600,
		'resp_person'=>sprintf("%s.",$CFG->{'WILDCARD_RNAME'}), 'data'=>sprintf("%s.",$CFG->{'WILDCARD_SOA'}),
		'type'=>'SOA',
		'MID'=>$IN->{'MID'},
		'USERNAME'=>sprintf("%s",$IN->{'USERNAME'}),
		'CLUSTER'=>sprintf("%s",$IN->{'CLUSTER'}),
		'DOMAIN'=>sprintf("%s",$IN->{'DOMAIN'}),
		},sql=>1,verb=>'insert');
	print $pstmt."\n";
	$dbh->do($pstmt);
		
	## now add an "A" record.
	$pstmt = &DBINFO_insert($dbh,'dns_records',{
		'zone'=>$HOSTDOMAIN,
		'host'=>'@',
		'ttl'=>3600,
		'type'=>'A',
		'data'=>$IN->{'ipv4'},
		'MID'=>$IN->{'MID'},
		'USERNAME'=>sprintf("%s",$IN->{'USERNAME'}),
		'CLUSTER'=>sprintf("%s",$IN->{'CLUSTER'}),
		'DOMAIN'=>sprintf("%s",$IN->{'DOMAIN'}),
		},sql=>1,verb=>'insert');
	print $pstmt."\n";
	$dbh->do($pstmt);
	$dbh->do("commit");

	return({ 'err'=>0, msg=>sprintf("domain %s.%s is %s",$IN->{'host'},$IN->{'zone'},$IN->{'ipv4'})});
	}


##
##
##
sub dns_domain_update {
	my ($CFG,$IN) = @_;

	my ($ref) = $IN->{'%DOMAIN'};
	my $OUT = undef;
	
	my $USERNAME = $ref->{'USERNAME'};
	my $domain = $ref->{'DOMAIN'}	;

	open F, ">/tmp/$domain.dump";
	print F Dumper($ref);
	close F;
	
	$domain = lc($domain);
	$domain =~ s/[^a-z0-9\.\-]+//g;
	next unless $domain;

	my $whynot = undef;	
	my $dotdomain = ".$domain";
	foreach my $verbotenregex (@BADNAMES) {
		if ($dotdomain =~ /$verbotenregex/) { $whynot = $verbotenregex; }
		}

	## NOTE: the VIP is always what the IP should be for a valid www or m_ based on the cluster, it might be overwritten later by (for example) an ssl, etc.
	if ($domain eq 'paypal.zoovy.com') { 
		die("this should have been blocked [earlier] - check your filters"); 
		}

	# Read old db
	my @FILE = ();
	my @SQL = ();

	# Generate new db
	## we need to have sslgmt in the header so when it updates, we'll bump the live date on the domain.
	push(@FILE, "; $ref->{'DOMAIN'} user=$ref->{'USERNAME'} cluster=$ref->{'CLUSTER'}");
	push(@FILE, "\$TTL	$ref->{'TTL'};");
	push(@FILE, "\$ORIGIN $ref->{'DOMAIN'}.");

	## SQL ttl, zone will be added at the end of loop to all records.
	my $SOA_NS = $ref->{'%SOA'}->{'NS'};
	my $SOA_RNAME = $ref->{'%SOA'}->{'RNAME'};
	my $SERIAL = $ref->{'%SOA'}->{'SERIAL'};

	push(@FILE, "\@ IN SOA $SOA_NS. $SOA_RNAME. ( $SERIAL 28800 3600 6048000 3600 )");
	push @SQL, { type=>'SOA', serial=>$SERIAL, data=>"$SOA_NS.", resp_person=>"$SOA_RNAME.", refresh=>28800, retry=>3600, expire=>6048000, minimum=>3600 };
	foreach my $NS_SERVER (@{$ref->{'@NS'}}) {
		push(@FILE, "\@	IN	NS	$NS_SERVER.");
		push @SQL, { type=>'NS', host=>'@', data=>"$NS_SERVER." };
		}

	my @HOSTNAMES = keys %{$ref->{'%HOSTS'}};	
	if (defined $ref->{'%HOSTS'}->{'WWW'}) {
		unshift @HOSTNAMES, '@';		## this is domain.com .. it will be mapped to www.
		}
	
	foreach my $HOSTNAME (@HOSTNAMES) {
		## www, m, app, secure.
		
		my $HOSTINFO = $ref->{'%HOSTS'}->{$HOSTNAME};
		if ($HOSTNAME eq '@') { $HOSTINFO = $ref->{'%HOSTS'}->{'WWW'}; }
		
		if (not defined $HOSTINFO->{'HOSTTYPE'}) {
			warn "UNKNOWN TYPE IN HOSTINFO FOR:$HOSTNAME --" . Dumper($HOSTINFO);
			$HOSTINFO->{'HOSTTYPE'} = 'UNKNOWN';
			}
		elsif ($HOSTINFO->{'HOSTTYPE'} eq 'CUSTOM') { 
			## this will be overridden by a custom record. don't do anything
			}

		if (defined $HOSTINFO->{'HOSTTYPE'}) {
			push @FILE, "; $HOSTNAME: $HOSTINFO->{'HOSTTYPE'}";
			push(@FILE, "$HOSTNAME IN	A	$HOSTINFO->{'IP4'}");
			my %HOST = ( host=>lc("$HOSTNAME"), type=>'A', data=>$HOSTINFO->{'IP4'} );
			$HOST{'HOSTTYPE'} = $HOSTINFO->{'HOSTTYPE'};
			if (
				(defined $HOSTINFO->{'SSL_CERT'}) && ($HOSTINFO->{'SSL_CERT'} ne '') &&
				(defined $HOSTINFO->{'SSL_KEY'})  && ($HOSTINFO->{'SSL_KEY'} ne '')
				) {
				## this would be a good place 
				$HOST{'SSL_CERT'} = $HOSTINFO->{'SSL_CERT'};
				$HOST{'SSL_KEY'}  = $HOSTINFO->{'SSL_KEY'};
				};
			push @SQL, \%HOST;
			if (not defined $HOSTINFO->{'IP4'}) {
				$OUT = { err=>2000, errmsg=>"No IP4 address for HOSTNAME:$HOSTINFO->{'HOSTNAME'}" };
				}
			}
		}
		

	##
	## BEGIN: EMAIL
	##
	my @MXSERVERS = ();
	push @FILE, "; EMAIL_TYPE: $ref->{'%EMAIL'}->{'TYPE'}";
	if ($ref->{'%EMAIL'}->{'TYPE'} eq 'NONE') {
		}
	elsif ($ref->{'%EMAIL'}->{'TYPE'} eq 'GOOGLE') {
		# ip4:66.240.244.192/27 include:_spf.google.com ~all
		push @FILE, "; GOOGLE APPS:";
		push @FILE, "mail IN CNAME ghs.google.com.";
		push @SQL, { 'host'=>'mail', 'type'=>'cname', 'data'=>'ghs.google.com.' };
		push @FILE, "calendar IN CNAME ghs.google.com.";
		push @SQL, { 'host'=>'calendar', 'type'=>'cname', 'data'=>'ghs.google.com.' };
		push @FILE, "docs IN CNAME ghs.google.com.";
		push @SQL, { 'host'=>'docs', 'type'=>'cname', 'data'=>'ghs.google.com.' };
		push @FILE, "\@\tIN\tTXT \"v=spf1 include:_spf.google.com include:_spf.zoovymail.com ~all\"";
		push @SQL, { host=>'@', type=>'txt', data=>qq|v=spf1 include:_spf.google.com include:_spf.zoovymail.com ~all| };
		push @MXSERVERS, 'ASPMX.L.GOOGLE.COM';
		push @MXSERVERS, 'ALT1.ASPMX.L.GOOGLE.COM';
		push @MXSERVERS, 'ALT2.ASPMX.L.GOOGLE.COM';
		push @MXSERVERS, 'ASPMX2.GOOGLEMAIL.COM';
		push @MXSERVERS, 'ASPMX3.GOOGLEMAIL.COM';
		push @MXSERVERS, 'ASPMX4.GOOGLEMAIL.COM';
		push @MXSERVERS, 'ASPMX5.GOOGLEMAIL.COM';
		}
	elsif ($ref->{'%EMAIL'}->{'TYPE'} eq 'FUSEMAIL') {
		push @FILE, "\@\tIN\tTXT \"v=spf1 include:fusemail.net include:mailanyone.net include:_spf.zoovymail.com ~all\"";
		push @SQL, { 'type'=>'txt', data=>qq|v=spf1 include:fusemail.net include:mailanyone.net include:_spf.zoovymail.com ~all| };
		push @MXSERVERS, 'mx.mailanyone.net';
		push @MXSERVERS, 'mx2.mailanyone.net';
		push @MXSERVERS, 'mx3.mailanyone.net';
		## 4/4/11 - webmail3.mailanyone.net goes to version 3 of the webmail interface, apparently
		#@				www.mailanyone.net still points at version 2 (yay!) which is deprecated /no longer supported.
		push @FILE, 'webmail IN CNAME webmail3.mailanyone.net.';
		push @SQL, { host=>'webmail', type=>'CNAME', data=>'webmail3.mailanyone.net.' };
		push @FILE, 'smtp IN CNAME smtp.mailanyone.net.';
		push @SQL, { host=>'smtp', type=>'CNAME', data=>'smtp.mailanyone.net.' };
		push @FILE, 'imap IN CNAME imap.mailanyone.net.';
		push @SQL, { host=>'imap', type=>'CNAME', data=>'imap.mailanyone.net.' };
		push @FILE, 'pop IN CNAME pop.mailanyone.net.';
		push @SQL, { host=>'pop', type=>'CNAME', data=>'pop.mailanyone.net.' };
		push @FILE, 'ftp IN CNAME ftp.mailanyone.net.'; 
		push @SQL, { host=>'ftp', type=>'CNAME', data=>'ftp.mailanyone.net.' };
		}
	elsif ($ref->{'%EMAIL'}->{'TYPE'} eq 'MX') {
		foreach my $MXPOS ('MX1','MX2','MX3') {
		
			my $MXSERVER = $ref->{'%EMAIL'}->{$MXPOS};
			if ((not defined $MXSERVER) || ($MXSERVER eq '')) {
				if ($MXPOS eq 'MX1') {
					push @FILE, "; [WARN] No $MXPOS server specified";
					}
				next;
				}
			$MXSERVER=lc($MXSERVER);
			$MXSERVER =~ s/\.$//g;	# strip trailing periods (we'll re-add them later)
			
			if ($MXSERVER =~ /^[0-9\.]+$/) { 
				# No IP addresses
				push @FILE, "; [WARN] $MXPOS ($MXSERVER) cannot be an ip address.";
				$MXSERVER = undef;
				} 
			else {
				my ($mxname,$mxaliases,$mxaddrtype,$mxlength,@addrs) = gethostbyname($MXSERVER);
				if ($mxname eq '' || $#addrs < 0) { 
					# No answer = invalid
					push @FILE, "; [WARN] $MXPOS ($MXSERVER) is lame (not functional).";
					$MXSERVER = undef;
					}  
				}
					
			if (defined $MXSERVER) {
				push @MXSERVERS, $MXSERVER;
				}
			else {
				push @FILE, "; [WARN] Invalid $MXPOS  for $domain";
				}
			}
		
		if ($MXSERVERS[0] =~ /secureserver\.net/) {
			push @FILE, 'webmail IN CNAME email.secureserver.net.';
			push @SQL, { host=>'webmail', type=>'CNAME', data=>'email.secureserver.net.' };
			push @FILE, 'mail IN CNAME pop.secureserver.net.';
			push @SQL, { host=>'mail', type=>'CNAME', data=>'pop.secureserver.net.' };
			push @FILE, 'pop IN CNAME pop.secureserver.net.';
			push @SQL, { host=>'pop', type=>'CNAME', data=>'pop.secureserver.net.' };
			push @FILE, 'imap IN CNAME imap.secureserver.net.';
			push @SQL, { host=>'imap', type=>'CNAME', data=>'imap.secureserver.net.' };
			push @FILE, 'email IN CNAME email.secureserver.net.';
			push @SQL, { host=>'email', type=>'CNAME', data=>'email.secureserver.net.' };
			} 
		elsif ($MXSERVERS[0] =~ /mxmail\.register\.com/) {
			push(@FILE, 'mail IN CNAME webmail.register.com.');
			push @SQL, { 'host'=>'mail', type=>'CNAME', data=>'webmail.register.com.' };
			} 
		#elsif ($MXSERVERS[0] =~ /^[\d]+\.[\d]+\.[\d]+\.[\d]+/) {
		#	push @FILE, "mail IN CNAME $MXSERVERS[0].";
		#	push @SQL, { 'host'=>'mail', type=>'CNAME', data=>$MXSERVERS[0] };
		#	$MXSERVERS[0] = "mail.$domain";
		#	}
		}
	else {
		# $ref->{'%EMAIL'}->{'TYPE'} is not defined correctly
		push @FILE, "; [WARN] Invalid EMAIL_TYPE:$ref->{'%EMAIL'}->{'TYPE'}";
		# @MXSERVERS = ('10 undef.zoovy.com');
		}

	if (@MXSERVERS) {
		my $mx_priority = 0;
		for my $mx (@MXSERVERS) {
			## $mx =~ s/\.$//g;	# strip trailing dots at the end of mx server name.
			push @FILE, "\@ IN MX $mx_priority $mx.";
			push @SQL, { 'host'=>'@', 'type'=>'mx', 'mx_priority'=>($mx_priority+=10), data=>"$mx." };
			}
		}

	if (ref($ref->{'@CUSTOM'}) eq 'ARRAY') {
		push @FILE, sprintf('; (%d) CUSTOM RECORDS: ',scalar(@{$ref->{'@CUSTOM'}}));
		foreach my $row (@{$ref->{'@CUSTOM'}}) {
			push @FILE, sprintf("%s\t%s\t%s",$row->{'host'},$row->{'type'},$row->{'data'});
			if ($row->{'type'} eq 'MX') {
				($row->{'mx_priority'},$row->{'data'}) = split(/[\s\t]+/,$row->{'data'});
				}
			push @SQL, $row;
			}
		}

	##
	## END OF EMAIL
	## 
	#if (defined $custom{$domain}) {
	#	push @FILE, "; BEGIN Custom appends from $CUSTOM_CONF";
	#	foreach my $customline (@{$custom{$domain}}) {
	#		push @FILE, $customline;
	#		}
	#	push @FILE, "; END Custom";
	#	}


	## check to see if we have an alt "www" vip assigned in custom.conf
	if ($ref->{'DKIM_PUBKEY'} =~ /[\n\r]+/) {
		push @FILE, "; [WARN] DKIM records should NOT have hard returns in them at this point. (removing DKIM)";
		$ref->{'DKIM_PUBKEY'} = '';
		}
	
	if ($ref->{'%EMAIL'}->{'TYPE'} eq 'NONE') {
		if ($ref->{'DKIM_PUBKEY'} eq '') {
			push @FILE, "; [WARN] DKIM was ignored because EMAIL_TYPE is NONE";
			}
		}
	elsif ($ref->{'DKIM_PUBKEY'} ne '') {
		## _domainkeys.domain.com
		push @FILE, qq~\$ORIGIN s1._domainkey.${domain}.~;
		if ($ref->{'DKIM_PUBKEY'} ne '') {
			push @FILE, qq~\@\tIN\tTXT \"k=rsa; p=$ref->{'DKIM_PUBKEY'}\"~;
			}
		# push @SQL, { host=>"s1", zone=>"_domainkey.$domain", type=>'txt', data=>"k=rsa; p=$ref->{'DKIM_PUBKEY'}" };
		push @SQL, { host=>"s1._domainkey", type=>'txt', data=>"k=rsa; p=$ref->{'DKIM_PUBKEY'}" };
		}
	
	#if ($ref->{'NEWSLETTER_ENABLE'}) {
	#	## newsletter.domain.com
	#	push @FILE, qq~\$ORIGIN newsletter.${domain}.~;
	#	push @FILE, qq~\@\tIN\tTXT \"v=spf1 ip4:66.240.244.192/27 ip4:208.74.184.0/24 -all\"~;
	#	push @FILE, qq~\@\tIN\tMX 5 mail.zoovy.com.~;
	#	## _domainkeys.newsletter.domain.com
	#	if ($ref->{'DKIM_PUBKEY'} ne '') {
	#		push @FILE, qq~\$ORIGIN s1._domainkey.newsletter.${domain}.~;
	#		push @FILE, qq~\@\tIN\tTXT \"k=rsa; p=$ref->{'DKIM_PUBKEY'}\"~;
	#		}
	#	}

	#if (1) {
	#	## CONFIG RECORD
	push @FILE, qq~\$ORIGIN config.${domain}.~;
	push @FILE, qq~\@\tIN\tTXT \"app=zoovy user=$USERNAME cluster=$ref->{'CLUSTER'} prt=$ref->{'PRT'} v=$ref->{'MODIFIED_GMT'}\"~;
	push @SQL, { host=>'config', type=>'txt', data=>"app=zoovy user=$USERNAME cluster=$ref->{'CLUSTER'} prt=$ref->{'PRT'} v=$ref->{'MODIFIED_GMT'}" };
	#	}

	foreach my $sql (@SQL) {
		if (not defined $sql->{'zone'}) { $sql->{'zone'} = $domain; }
		if (not defined $sql->{'ttl'}) { $sql->{'ttl'} = $ref->{'TTL'}; }
		if (not defined $sql->{'host'}) { 
			warn "NO HOST -- type:$sql->{'type'} data:$sql->{'data'}\n";
			$sql->{'host'} = '@'; 
			}
		$sql->{'MID'} = int($ref->{'MID'});	
		$sql->{'USERNAME'} = sprintf("%s",$ref->{'USERNAME'});
		$sql->{'CLUSTER'} = sprintf("%s",$ref->{'CLUSTER'});
		}


	## 
	if (not defined $OUT) {
		## got an error, don't do anything!
		open F, ">/tmp/$domain.db";
		for (@FILE) { print F "$_\n"; }

		print F "\n; SQL:\n";
		foreach my $line (split(/\n/,Dumper(\@SQL))) {
			print F "; $line\n";
			}
		close F;
		$OUT = { 'err'=>0, 'msg'=>"wrote /tmp/$domain.db" };
		}
		
	if ($OUT->{'err'} == 0) {
		my $dbh = $CFG->{'*dbh'};
		$dbh->do("start transaction");
		my $pstmt = "delete from dns_records where MID=".int($ref->{'MID'})." and zone=".$dbh->quote($domain);
		$dbh->do($pstmt);
		foreach my $sql (@SQL) { 
			my ($pstmt) = &DBINFO_insert($dbh,'dns_records',$sql,verb=>'insert',sql=>1);
			print $pstmt."\n";
			$dbh->do($pstmt);
			}
		#my $pstmt = "delete from dns_records where MID=".int($ref->{'MID'})." and zone=".$dbh->quote($domain)." and serial!=".int($SERIAL);
		#$dbh->do($pstmt);
		$dbh->do("commit");
		}
			
	

	
	return($OUT);
	}



##
## takes an arrayref, turns it into
##		('1','2','3')
##
sub DBINFO_makeset {
	my ($dbh, $arref) = @_;

	my $set = '';
	foreach my $x (@{$arref}) {
		$set .= $dbh->quote($x).',';
		}
	if ($set ne '') {
		chop($set);
		$set = "($set)";
		}
	return($set);
	}

##
## does a simple insert statement to a table, from a hash
##		parameters: a dbh reference, TABLE NAME, hashref (key=>value)
##		options:
##			key=>causes us to do a select count(*) and then switch to update mode
##					see notes in the code for specific behaviors for scalar, arrayref, hashref
##			debug=>(bitise) 
##				1 - output to stderr
##				2 - do not apply statements.
##			update=>0|1|2 (default is 1) 
##				0 = force an insert 
##				2 = force an update
##			sql=>1
##				returns an sql statement, turns off STDERR print
##	returns:
##		pstmt or undef if error (if it was applied to database)
##	
sub DBINFO_insert {
	my ($dbh,$TABLE,$kvpairs,%options) = @_;

	if (defined $options{'sql'}) {
		$options{'debug'} |= 2;
		$options{'debug'} = $options{'debug'} & (0xFF-1);
		}

	if (not defined $options{'debug'}) { $options{'debug'}=0; }
	if (not defined $dbh) { $options{'debug'} = $options{'debug'} | 2; }

	if ($options{'debug'}&1) {
		# use Data::Dumper;
		# print STDERR Dumper($TABLE,$kvpairs,%options);
		}

	my $mode = 0;	# insert, 1=update, -1 skip action, 0 = figure it out, 2 = force insert
	if (defined $options{'verb'}) {
		$mode = -1;
		if ($options{'verb'} eq 'auto') { $mode = 0; }
		if ($options{'verb'} eq 'update') { $mode = 1; }
		if ($options{'verb'} eq 'insert') { $mode = 2; }
		if ($mode == -1) {
			warn "DBINFO::insert unknown verb=$options{'verb'} (should be auto|update|insert)\n";
			}
		}
	elsif ((defined $options{'update'}) && ($options{'update'}==2)) {
		## pass in update=>2 to force us to generate an update statement
		##		(do this when we're sure the record already exists)
		$mode = 1;
		}


	if (($mode == 0) && (defined $options{'key'})) {
		my $pstmt = '';

		if ( (ref($options{'key'}) eq 'SCALAR') || (ref($options{'key'}) eq '') ) {
			## simple: key=scalarkey  (value looked up in $kvpairs)
			$pstmt = "select count(*) from $TABLE where ".$options{'key'}.'='.$dbh->quote($kvpairs->{$options{'key'}});
			}
		elsif (ref($options{'key'}) eq 'ARRAY') {
			## more complex: key=[kvkey1,kvkey2,kvkey3] (values looked up in $kvpairs)
			foreach my $k (@{$options{'key'}}) {
				if ($pstmt ne '') { $pstmt .= " and "; }
				$pstmt .= $k.'='.$dbh->quote($kvpairs->{$k});
				}
			$pstmt = "select count(*) from $TABLE where $pstmt";
			}
		elsif (ref($options{'key'}) eq 'HASH') {
			## ultra complex: key={ key1=>value1, key2=>value2 }
			foreach my $k (keys %{$options{'key'}}) {
				if ($pstmt ne '') { $pstmt .= " and "; }
				$pstmt .= $k.'='.$dbh->quote($options{'key'}->{$k});
				}
			$pstmt = "select count(*) from $TABLE where $pstmt";
			}

		my $sth = $dbh->prepare($pstmt);
		$sth->execute();
		my ($exists) = $sth->fetchrow();
		$sth->finish();
		if ($exists>0) { 
			$mode = 1; # update
			} 
		else { 
			$mode = 2; # insert
			}

		if ((defined $options{'update'}) && ($options{'update'}==0) && ($mode==1)) {
			## if we are told not to do updates, and we're supposed to do an update then don't do anything.
			$mode = -1;
			}
		}

	if ($mode == 0) { $mode = 2; }	
	# convert any "auto" to automatic insert (since our function name is DBINFO::insert)

	my $pstmt = '';
	if ($mode==2) {
		## insert statement
		my $tmp = '';
		if (defined $options{'on_insert'}) {
			## on_insert is a hash of key values which are ONLY transmittined on insert e.g. CREATED_GMT
			foreach my $k (keys %{$options{'on_insert'}}) {
				$kvpairs->{$k} = $options{'on_insert'}->{$k};
				}
			}
		foreach my $k (keys %{$kvpairs}) {
			if ($pstmt) { $tmp .= ','; $pstmt .= ','; }
			if (substr($k,0,1) eq '*') { ## RAW
				$pstmt .= substr($k,1);
				$tmp .= $kvpairs->{$k};				
				}
			else {
				$pstmt .= $k;
				$tmp .= $dbh->quote($kvpairs->{$k});
				}
			}
		$pstmt = 'insert '.($options{'delayed'}?'DELAYED':'').' into '.$TABLE.' ('.$pstmt.') values ('.$tmp.')';
		}
	elsif (($mode==1) && (defined $options{'key'})) {
		## update statement
		foreach my $k (keys %{$kvpairs}) {
			if (substr($k,0,1) eq '*') { ## RAW
				$pstmt .= (($pstmt)?',':'').substr($k,1).'='.$kvpairs->{$k};
				}
			else {
				$pstmt .= (($pstmt)?',':'').$k.'='.$dbh->quote($kvpairs->{$k});
				}
			}

		if (ref($options{'key'}) eq 'SCALAR') {
			$pstmt = 'update '.($options{'delayed'}?'DELAYED':'')." $TABLE set ".$pstmt." where  ".$options{'key'}.'='.$dbh->quote($kvpairs->{$options{'key'}});
			}
		elsif (ref($options{'key'}) eq 'ARRAY') {
			## more complex: key=[kvkey1,kvkey2,kvkey3] (values looked up in $kvpairs)
			$pstmt = 'update '.($options{'delayed'}?'DELAYED':'')." $TABLE set $pstmt where ";
			my $count = 0;
			foreach my $k (@{$options{'key'}}) {
				if ($count++) { $pstmt .= " and "; }
				$pstmt .= $k.'='.$dbh->quote($kvpairs->{$k});
				}
			}
		elsif (ref($options{'key'}) eq 'HASH') {
			## ultra complex: key={ key1=>value1, key2=>value2 }
			$pstmt = 'update '.($options{'delayed'}?'DELAYED':'')." $TABLE set $pstmt where ";
			my $count = 0;
			foreach my $k (keys %{$options{'key'}}) {
				if ($count++) { $pstmt .= " and "; }
				$pstmt .= $k.'='.$dbh->quote($options{'key'}->{$k});
				}
			}

		}
	else {
		warn "DBINFO::insert NO KEY SPECIFIED BUT \$mode==$mode";
		}
	
	if ($options{'debug'}&1) {
		print STDERR "PSTMT: ".$pstmt."\n";
		}

	if (not $options{'debug'}&2) { 
		my $rv = $dbh->do($pstmt); 
		if (not $rv) {
			my ($package,$file,$line,$sub,$args) = caller(0);
			print STDERR "CALLER[0]: $package,$file,$line,$sub,$args\n";
			}
		}
	
	return($pstmt);
	}





1;