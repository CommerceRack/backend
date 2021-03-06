#!/usr/bin/perl

#
# run this on a cluster, it will output a a file (typically /var/log/nagios/status-_self_
# which is then checked by /root/configs/nagios-plugins/check-cluster_apps/ssh_into_cluster_and_runthis.pl
#

use strict;
use lib "/httpd/modules";
use POSIX;
use ZOOVY;
use DBINFO;
use Data::Dumper;

## build a list of users for the cluster
my ($CFG) = CFG->new();
my (@USERS) = @{CFG->new()->users()};

my $TS = time();
foreach my $USERNAME (reverse @USERS) {
	my ($USERPATH) = &ZOOVY::resolve_userpath($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	next if ($MID<=0);

	my $MAX_DELETES = 25000;
	print "[$MID] USERPATH: $USERPATH\n";
	
	my ($udbh) = &DBINFO::db_user_connect("$USERNAME");
	opendir my $D, "$USERPATH/PRIVATE";
	while ( my $file = readdir($D) ) {
		next if (substr($file,0,1) eq '.');
		last if ($MAX_DELETES <= 0);
		
		my $fullpath = "$USERPATH/PRIVATE/$file";
				
		my $pstmt = "select count(*),unix_timestamp(EXPIRES),ID from PRIVATE_FILES where MID=$MID /* $USERNAME */ and FILENAME=".$udbh->quote($file);
		my ($count,$expires_gmt,$fileid) = $udbh->selectrow_array($pstmt);
		
		my $DELETE = 0;

		if (($count == 0) || ($expires_gmt == 0)) {
			## files that are not indexed in the DB have different retention periods
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($fullpath);
			if ($file =~ /\.yaml$/) {
				## reports
				if ($ctime < $^T-(180*86400)) { $DELETE++; }
				}
			elsif ($file =~ /\.out$/) {
				## marketplce output
				if ($ctime < $^T-(180*86400)) { $DELETE++; }
				}
			elsif ($file =~ /^SEARSOrder([\d]+)\.xml$/) {
				if ($ctime < $^T-(365*86400)) { $DELETE++; }
				}
			elsif ($file =~ /^SEARS.*?/) {
				if ($ctime < $^T-(180*86400)) { $DELETE++; }
				}
			elsif ($file =~ /^EBAY.*?\.xml$/) {
				if ($ctime < $^T-(45*86400)) { $DELETE++; }
				}
			elsif ($file =~ /^buycom/) {
				if ($ctime < $^T-(180*86400)) { $DELETE++; }
				}
			elsif ($file =~ /^BUY/) {
				if ($ctime < $^T-(180*86400)) { $DELETE++; }
				}
			elsif ($file =~ /^amz-([\d]+)\.xml$/) {
				if ($ctime < $^T-(45*86400)) { $DELETE++; }
				}
			elsif ($file =~ /^amz-.*?\.xml$/) {
				if ($ctime < $^T-(45*86400)) { $DELETE++; }
				}
			elsif ($file =~ /^CSV(.*?)csv$/) {
				if ($ctime < $^T-(180*86400)) { $DELETE++; }
				}
			elsif ($file =~ /^job_([\d]+)_/) {
				if ($ctime < $^T-(30*86400)) { $DELETE++; }
				}
			else {
				print "KEEP FILE: $file\n";
				}
			}
		elsif ($file =~ /SEARSOrder([\d]+)\.xml$/) {
			print STDERR "SEARS FILE:$file\n";
			}			
		elsif (($count == 1) && ($expires_gmt == 0)) {
			## leave it alone!
			print STDERR "COUNT==1 FILE:$file\n";
			}
		elsif ($expires_gmt<$TS) {
			## expired
			print STDERR "EXPIRES!\n";
			$DELETE++;
			}
	
		next if (not $DELETE);
			
		if ($DELETE) {
			print "UNLINK: $fullpath\n";
			my $pstmt = "delete from PRIVATE_FILES where ID=".int($fileid);
			print "$pstmt\n";
			$udbh->do($pstmt);
			if (-f $fullpath) { unlink("$fullpath"); }
			$MAX_DELETES--;
			}

		if (not defined $count) {
			## doesn't exist.
			}
	
		print "[$DELETE/$MAX_DELETES] $USERNAME: $file [$count] [$expires_gmt]\n";
		}
	closedir $D;	
	&DBINFO::db_user_close();
	}



