#!/usr/bin/perl

use POSIX;
use strict;

use lib "/httpd/modules";
use CFG;
use ZOOVY;


my ($CFG) = CFG->new();
my (@USERS) = @{CFG->new()->users()};

# 
# perl -e 'foreach $letter ("a".."z","0".."9") { opendir $D1, "/data/users/$letter"; while (my $user = readdir($D1)) { next if (substr($user,0,1) eq "."); next if (! -d "/data/users/$letter/$user"); print "$letter/$user"; system("/bin/du -sk /data/users/$letter/$user > /data/users/$letter/$user/diskspace.txt"); } closedir $D1; }'
#

foreach my $USERNAME (@USERS) {
	my ($USERPATH) = &ZOOVY::resolve_userpath($USERNAME);
	next if (! -d "$USERPATH");
	next if (! -d "$USERPATH/.zfs");

	print "$USERPATH/diskspace.txt\n";
	unlink("$USERPATH/diskspace.txt");
	# look for log files
	&cleanup_logs($USERNAME,"$USERPATH");
		
	print "DISK: $USERPATH\n";
	my $DU = undef;
	if ((not defined $DU) && (-f '/usr/bin/du')) { $DU = '/usr/bin/du'; }
	if ((not defined $DU) && (-f '/bin/du')) { $DU = '/bin/du'; }
	system("$DU -sk $USERPATH > $USERPATH/diskspace.txt");
	}


sub cleanup_logs {
	my ($user,$dir) = @_;

	my $now = POSIX::strftime("%Y%m",localtime(time()));
	my $nowabs = &abs_date($now);

	opendir my $Duser, "$dir";
	while (my $file = readdir($Duser) ) {
		next if (substr($file,0,1) eq '.');

		if ($file =~ /(.*?)\-$now\.log$/) {
			## current log file - leave it alone
			}
		elsif ($file eq 'access.log') {
			## rename access.log to access-201000.log
			print "RENAMING $dir/$file\n";
			system("/bin/mv $dir/access.log $dir/access-201000.log");
			}
		elsif ($file =~ /^(.*?)\-[\d]{6,6}\.log$/) {
			## compress old log files
			print "COMPRESSING LOG: $dir/$file [$now]\n";
			system("/bin/gzip -9 $dir/$file");
			}
		elsif ($file =~ /^access\-/) {
			## never archive access logs! support needs these.
			}
		## LONG TERM: GLACIER?
		#elsif ($file =~ /^(.*?)\-([\d]{6,6})\.log\.gz$/) {
		#	if ((abs_date($1)+3) < $nowabs) {
		#		## move to log directory with username
		#		print "ARCHIVING $dir/$file to /data/logs/$user~$file\n";
		#		system("/bin/mv $dir/$file /data/logs/$user~$file");
		#		}
		#	else {
		#		## preserve less than 3 months
		#		}
		#	}
		elsif ($file =~ /^(.*?)\.cdb$/) {
			print "REMOVING: $dir/$file\n";
			unlink("$dir/$file");
			}
		elsif ($file =~ /^shiprules\.bin$/) {
			print "REMOVING: $dir/$file\n";
			unlink("$dir/$file");
			}
		else {
			print "SYSTEM: $dir/$file\n";
			}
			
		}
	closedir $Duser;
	}

##
## returns the number of months that have elapsed since 2000
##
sub abs_date {
	my ($yyyymm) = @_;

	my $x = int(substr($yyyymm,0,4));
	$x = $x - 2000;
	$x *= 12;
	$x += int(substr($yyyymm,4,2));
	return($x);
	}