#!/usr/bin/perl

package BATCHJOB::UTILITY::GITPULL;

use strict;
use lib "/backend/lib";
use PROJECT;
use Data::Dumper;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }



sub work {
	my ($self, $bj) = @_;

	#my $payload = '{"pusher":{"name":"none"},"repository":{"name":"linktest","created_at":"2012-10-06T16:11:58-07:00","size":0,"has_wiki":true,"private":false,"watchers":0,"url":"https://github.com/brianhorakh/linktest","fork":false,"id":6107642,"pushed_at":"2012-10-06T16:11:58-07:00","open_issues":0,"has_downloads":true,"has_issues":true,"description":"linktest","stargazers":0,"forks":0,"owner":{"name":"brianhorakh","email":"brianh@zoovy.com"}},"forced":false,"after":"29ebef452b38b1bda426daa722381d57566dcd4e","head_commit":{"added":["README.md"],"modified":[],"timestamp":"2012-10-06T16:11:58-07:00","author":{"name":"brianhorakh","username":"brianhorakh","email":"brianh@zoovy.com"},"removed":[],"url":"https://github.com/brianhorakh/linktest/commit/29ebef452b38b1bda426daa722381d57566dcd4e","id":"29ebef452b38b1bda426daa722381d57566dcd4e","distinct":true,"message":"Initial commit","committer":{"name":"brianhorakh","username":"brianhorakh","email":"brianh@zoovy.com"}},"deleted":false,"ref":"refs/heads/master","commits":[],"before":"29ebef452b38b1bda426daa722381d57566dcd4e","compare":"https://github.com/brianhorakh/linktest/compare/29ebef452b38...29ebef452b38","created":false}';
	#my $payload = '{"pusher":{"name":"brianhorakh","email":"brianh@zoovy.com"},"repository":{"name":"linktest","created_at":"2012-10-06T16:11:58-07:00","size":128,"has_wiki":true,"private":false,"watchers":0,"url":"https://github.com/brianhorakh/linktest","fork":false,"id":6107642,"pushed_at":"2012-10-06T17:04:37-07:00","open_issues":0,"has_downloads":true,"has_issues":true,"description":"linktest","stargazers":0,"forks":0,"owner":{"name":"brianhorakh","email":"brianh@zoovy.com"}},"forced":false,"after":"f43ce1b5c2a42a6e2966d41079c8098ef9ac669e","head_commit":{"added":["index.html"],"modified":[],"timestamp":"2012-10-06T17:04:19-07:00","author":{"name":"Brian Horakh","username":"brianhorakh","email":"brianh@zoovy.com"},"removed":[],"url":"https://github.com/brianhorakh/linktest/commit/f43ce1b5c2a42a6e2966d41079c8098ef9ac669e","id":"f43ce1b5c2a42a6e2966d41079c8098ef9ac669e","distinct":true,"message":"commit1","committer":{"name":"Brian Horakh","username":"brianhorakh","email":"brianh@zoovy.com"}},"deleted":false,"ref":"refs/heads/master","commits":[{"added":["index.html"],"modified":[],"timestamp":"2012-10-06T17:04:19-07:00","author":{"name":"Brian Horakh","username":"brianhorakh","email":"brianh@zoovy.com"},"removed":[],"url":"https://github.com/brianhorakh/linktest/commit/f43ce1b5c2a42a6e2966d41079c8098ef9ac669e","id":"f43ce1b5c2a42a6e2966d41079c8098ef9ac669e","distinct":true,"message":"commit1","committer":{"name":"Brian Horakh","username":"brianhorakh","email":"brianh@zoovy.com"}}],"before":"29ebef452b38b1bda426daa722381d57566dcd4e","compare":"https://github.com/brianhorakh/linktest/compare/29ebef452b38...f43ce1b5c2a4","created":false}';
	use JSON::XS;
	
	my $ERROR = undef;
	my ($V,$USERNAME,$PROJECT,$KEY) = (); # ('erich','7C62B56A-101C-11E2-9284-F4273A9C');

	my ($USERNAME) = $bj->username();
	#if ($ENV{'REQUEST_URI'} =~ /\/webapi\/git\/webhook\.cgi\/v=([\d]+)\/u\=([a-zA-Z0-9\-]+)\/p=([a-zA-z0-9\-]+)\/k=([0-9A-Fa-f]+)$/) {
	#	($V,$USERNAME,$PROJECT,$KEY) = ($1,$2,$3,$4);
	#	}
	#else {
	#	$ERROR = 'INVALID WEBHOOK URL FORMAT';
	#	}
		
	my $PROJECTID = undef;
	my $vars = $bj->meta();
	
	if ($vars->{'domain'} ne '') { 
		my ($HOST,$DOMAIN) = split(/\./,$vars->{'domain'},2);
		my ($DREF) = DOMAIN->new($self->username(),$DOMAIN);
		$PROJECTID = $DREF->{'%HOSTS'}->{uc($HOST)}->{'PROJECT'};
		}
	elsif ($vars->{'PROJECT'}) {
		$PROJECTID = $vars->{'PROJECT'};
		}	
	else {
		$ERROR = "need domain or projectid parameters";
		}
		
	if ($ERROR ne '') {
		}
	elsif ($PROJECTID eq '') {
		$ERROR = "PROJECT could not be found or was not passed.";
		}
	#else {
	#	$ERROR = "PROJECT $PROJECTID directory does not exist";
	#	}

	my ($memd) = &ZOOVY::getMemd($USERNAME);
	if (defined $ERROR) {
		}

	print "USERNAME: $USERNAME PROJECTID: $PROJECTID\n";

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select ID,SECRET,GITHUB_REPO,GITHUB_BRANCH from PROJECTS where MID=$MID and UUID=".$udbh->quote($PROJECTID);
	print STDERR "$pstmt\n";
	my ($ID,$SECRET,$REPOURL,$BRANCH) = $udbh->selectrow_array($pstmt);
	if (not defined $ID) { 
		$ERROR = "COULD NOT FIND PROJECT "; 
		}
	&DBINFO::db_user_close();

	my $MEMCACHE_UPDATE_KEY = "$USERNAME.$PROJECTID.updating";
	## TODO: add -w file test
		
	## my $pstmt = "select DOMAIN from DOMAINS where MID=$MID and 
	my $ts = $memd->get($MEMCACHE_UPDATE_KEY);
	print "$MEMCACHE_UPDATE_KEY TS:$ts\n";
	if ($ts>0) {
		$ERROR = sprintf("ALREADY UPDATING FROM %s REQUEST. UNCLEARED LOCK. PLEASE WAIT.",&ZTOOLKIT::pretty_date($ts,1));
		}


	warn "ERROR:$ERROR\n";

	if (not $ERROR) {
		my $userpath = &ZOOVY::resolve_userpath($USERNAME);
		# print Dumper($ID,$SECRET);

		$memd->set($MEMCACHE_UPDATE_KEY,time(),30*60);
		if (-d "$userpath/PROJECTS/$PROJECTID") {
			my $GIT = "/usr/bin/git";
			if (! -f $GIT) { $GIT = "/usr/local/bin/git"; }
			
			if ($BRANCH eq '') { $BRANCH = 'master'; }
			print "PROJECT BRANCH IS: $BRANCH\n";

			my $TMPDIR = "$USERNAME.$PROJECTID.".time();
			
			## NOTE: github started blocking http on 9/3
			## if ($REPO =~ /http:/) { $REPO =~ s/https://gs; }
			
				
			#my $CMD = qq~
			#/bin/rm -Rf /tmp/$TMPDIR;
			#mkdir -p /tmp/$TMPDIR;
			#$GIT clone --branch $BRANCH -- $REPOURL /tmp/$TMPDIR
			### cloned to the local filesystem
			#/bin/mv /tmp/$TMPDIR $userpath/PROJECTS/$TMPDIR
			#/bin/mv $userpath/PROJECTS/$PROJECTID $userpath/PROJECTS/$PROJECTID.nuke
			#/bin/mv $userpath/PROJECTS/$TMPDIR $userpath/PROJECTS/$PROJECTID	
			#~;	
						
			# my $CMD = "cd $userpath/PROJECTS/$PROJECTID; $GIT --git-dir=$userpath/PROJECTS/$PROJECTID/.git pull";
			my $CMD = "
					cd $userpath/PROJECTS/$PROJECTID; 
					$GIT --git-dir=$userpath/PROJECTS/$PROJECTID/.git fetch --all; 
					$GIT --git-dir=$userpath/PROJECTS/$PROJECTID/.git reset --hard origin/$BRANCH;
					echo '';
					echo '--History----------------------------------------------------';
					echo '';
					$GIT --git-dir=$userpath/PROJECTS/$PROJECTID/.git log >> /tmp/git.log
					/bin/touch $userpath/PROJECTS/$PROJECTID >> /dev/null
					";
			open F, ">/tmp/git";
			print F $CMD;
			close F;
			print STDERR "$CMD\n";
			system("$CMD >> /dev/null");

			# sleep(60);

			if (defined $memd) {
				## no timestamp in memcache, so we load one, and we set 
				my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$userpath/PROJECTS/$PROJECTID");
				$memd->set("$USERNAME.$PROJECTID",$mtime);
				}
			}
	
		open F, ">/tmp/git.$USERNAME";
		print F Dumper($vars);
		close F;

				
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		$memd->delete($MEMCACHE_UPDATE_KEY);	## allow projects to update again
		$pstmt = "update PROJECTS set UPDATED_TS=now() where MID=$MID and UUID=".$udbh->quote($PROJECTID);
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		
		if (-f "$userpath/PROJECTS/$PROJECTID/config.json") {
			require JSON::Syck;
			my $config = JSON::Syck::LoadFile("$userpath/PROJECTS/$PROJECTID/config.json");
			## JSON::Syck::DumpFile($file, $data);
			}
		&DBINFO::db_user_close();
		}	


   if (not $ERROR) {
      $bj->progress(1,1,"Did git pull");
      }
   else {
      $bj->progress(0,0,"ERROR-$ERROR");
      }
	return($ERROR);
	}


1;

__DATA__


#{"pusher":{"name":"none"},"repository":{"name":"linktest","created_at":"2012-10-06T16:11:58-07:00","size":0,"has_wiki":true,"private":false,"watchers":0,"url":"https://github.com/brianhorakh/linktest","fork":false,"id":6107642,"pushed_at":"2012-10-06T16:11:58-07:00","open_issues":0,"has_downloads":true,"has_issues":true,"description":"linktest","stargazers":0,"forks":0,"owner":{"name":"brianhorakh","email":"brianh@zoovy.com"}},"forced":false,"after":"29ebef452b38b1bda426daa722381d57566dcd4e","head_commit":{"added":["README.md"],"modified":[],"timestamp":"2012-10-06T16:11:58-07:00","author":{"name":"brianhorakh","username":"brianhorakh","email":"brianh@zoovy.com"},"removed":[],"url":"https://github.com/brianhorakh/linktest/commit/29ebef452b38b1bda426daa722381d57566dcd4e","id":"29ebef452b38b1bda426daa722381d57566dcd4e","distinct":true,"message":"Initial commit","committer":{"name":"brianhorakh","username":"brianhorakh","email":"brianh@zoovy.com"}},"deleted":false,"ref":"refs/heads/master","commits":[],"before":"29ebef452b38b1bda426daa722381d57566dcd4e","compare":"https://github.com/brianhorakh/linktest/compare/29ebef452b38...29ebef452b38","created":false}



