#!/usr/bin/perl

use lib "/httpd/modules";
use Data::Dumper;

if (not defined $USERNAME) { 
  print "No USERNAME\n";
  die(); 
  }

my $USERPATH = &ZOOVY::resolve_userpath($USERNAME);
my ($udbh) = &DBINFO::db_user_connect($USERNAME);

   my $pstmt = "select DOMAIN,KEYTXT,CERTTXT from SSL_CERTIFICATES where ACTIVATED_TS>0";
   my $sth = $udbh->prepare($pstmt);
   $sth->execute();
   while ( my ($HOSTDOMAIN,$SSL_KEY,$SSL_CERT) = $sth->fetchrow() ) {
      print "$HOSTDOMAIN\n";
			
		open F, ">$USERPATH/$HOSTDOMAIN.key";
		print F $SSL_KEY;
		close F;

		open F, ">$USERPATH/$HOSTDOMAIN.crt";
		print F $SSL_CERT;
		close F;
		}
   $sth->finish();
	
	&DBINFO::db_user_close();

