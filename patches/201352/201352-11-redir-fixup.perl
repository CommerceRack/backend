#!/usr/bin/perl

use lib "/httpd/modules";
use ZOOVY;
use Data::Dumper;
use ZTOOLKIT;

if (not defined $USERNAME) { 
  print "No USERNAME\n";
  die(); 
  }

my $USERPATH = &ZOOVY::resolve_userpath($USERNAME);
my ($udbh) = &DBINFO::db_user_connect($USERNAME);

   my $pstmt = "select DOMAINNAME,HOSTNAME,CONFIG from DOMAIN_HOSTS where HOSTTYPE='REDIR'";
   my $sth = $udbh->prepare($pstmt);
   $sth->execute();
   while ( my ($DOMAINNAME,$HOSTNAME,$CONFIG) = $sth->fetchrow() ) {
      my $ref = &ZTOOLKIT::parseparams($CONFIG);
		my $changed = 0;
		if (substr($ref->{'REDIR'},0,1) eq '/') {
			## leave britney alone!
			}
		elsif ($ref->{'REDIR'} =~ /^http[s]?\:/i) {
			## seriously.
			}
		else {
			$ref->{'REDIR'} = sprintf('http://%s',$ref->{'REDIR'});
			$changed++;
			}

		if ($changed) {
			my $qtCONFIG = $udbh->quote(&ZTOOLKIT::buildparams($ref));
			my $qtHOSTNAME = $udbh->quote($HOSTNAME);
			my $qtDOMAINNAME = $udbh->quote($DOMAINNAME);
			$pstmt = "update DOMAIN_HOSTS set CONFIG=$qtCONFIG where DOMAINNAME=$qtDOMAINNAME and HOSTNAME=$qtHOSTNAME";
			print $pstmt."\n";
			$udbh->do($pstmt);
			}
		}
   $sth->finish();
	
	&DBINFO::db_user_close();

