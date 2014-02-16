package LOCK;


##
## copied from app6:/httpd/servers/inventory/LOCK.pm
## 
## changed to our format, added strict

use strict;

my $LOCKPATH = "/tmp";
my $VERBOSE = 1;
my $MAXAGE = 30 * 60;	# 30 minutes



##
## This will return a non-zero if the lock succeeeds
##
sub grab_lock {
	my ($lockid,$ttl) = @_;

	if (not defined $ttl) { $ttl = $MAXAGE; }

	my $file = $LOCKPATH."/".$lockid.".lock";	
	if (-f $file) { 
		$VERBOSE && print STDERR "Lock file $file existed!!!\n";

		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
		$VERBOSE && print STDERR "TIME: ".time()." ctime: $ctime TIME-ctime: ".(time()-$ctime)." ttl: $ttl\n";

		if (time()-$ctime > $ttl) {
			$VERBOSE && print STDERR "Expiring dirty lock file.. ($$)\n";
			} 
		else {
			return 0; 
			}
		}

	## write to lock file
	open F, ">$file";
	print F $$;
	close F;

	my $RESULT = 0;

	$/ = undef;
	open F, "<$file";
	$RESULT = <F>;
	close F;
	$/ = "\n";
	if ($RESULT != $$) { $RESULT = 0; }

	# double check, this will handle the 
	# 1=open,2=open,1=write,2=write,1=read,2=read,1=close,2=close which *could* happen
	# in theory, this should be run 1+n, where is the maximum number of threads
	if (!&verify_lock($lockid)) { $RESULT = 0; }

	return($RESULT);
	}

##
## release lock will return 0 if the lock could be released.
## 
sub release_lock {
	my ($lockid) = @_;

	$VERBOSE && print STDERR "DEBUG STATEMENT - release lock id is currently [$lockid]\n";

	my $file = $LOCKPATH."/".$lockid.".lock";
	if (!-f $file) { 
		print STDERR "release_lock: Lock file $file did not exist!!!\n";
		return 1; 
		}

	$/ = undef;
	open F, "<$file";
	my $RESULT = <F>;
	close F;
	$/ = "\n";
	if ($RESULT == $$) { unlink($file); } 
	else { print STDERR "Cannot remove $file because we are not the owner! [$RESULT] != [$$]\n"; }

	print STDERR "Released lock for $lockid\n";
	return(0);	
	}

##
## verify that the current process still holds the lock
##
sub verify_lock {
	my ($lockid) = @_;

	my $file = $LOCKPATH."/".$lockid.".lock";
	if (!-f $file) { 
		print STDERR "verify_lock Lock file $file did not exist!!!\n";
		return 0; 
		}

	my $RESULT = 0;
	$/ = undef;
	open F, "<$file";
	$RESULT = <F>;
	close F;
	$/ = "\n";
	if ($RESULT != $$) { 
		print STDERR "CRITICAL!!!! verify_lock on $file failed we are not the owner!\n";
		$RESULT = 0;
		} 
	
	print "verify lock returned: pid is $RESULT\n";
	return($RESULT);
	}


1;

