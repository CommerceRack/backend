package PROJECT;

$PROJECT::STATIC_PATH = "/httpd/static/apps";

use strict;
require DBINFO;

# perl -e 'use lib "/backend/lib"; use PROJECT; use Data::Dumper; print Dumper(PROJECT::list("brian"));'
sub list {
	my ($USERNAME) = @_;

	my @PROJECTS = ();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select * from PROJECTS where MID=$MID order by ID desc";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		push @PROJECTS, $hashref;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@PROJECTS);
	}


##
## deletes a project
##
sub delete {
	my ($self) = @_;

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $pstmt = sprintf("delete from PROJECTS where MID=%d and ID=%d",&ZOOVY::resolve_mid($self->username()),$self->id());
	$udbh->do($pstmt);
	system(sprintf("/bin/rm -Rf %s",$self->dir()));	
	&DBINFO::db_user_close();
	return();
	}


##
##
##
sub copyfrom {
	my ($self, $src) = @_;

	my $ERROR = undef;
	my @errors = ();
	my $guid = undef;

	print sprintf("DIR: %s\n",$self->dir());
	print sprintf("FROM: /httpd/static/apps/$src\n");
	if (-d "/httpd/static/apps/$src/") {
		require File::Copy::Recursive;
		File::Copy::Recursive::dircopy("/httpd/static/apps/$src",$self->dir()) or die $!;
		}
	else {
		$ERROR = "source directory does not exist";
		}

	return($ERROR);
	}

##
##
##
sub create {
	my ($class,$USERNAME,$title,%params) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my ($TYPE) = $params{'TYPE'};
	if (not defined $TYPE) { $TYPE = 'APP'; }	## not good!
	my %db = (
		MID=>$MID,
		USERNAME=>$USERNAME,
		TITLE=>$title,
		SECRET=>'secret',
		TYPE=>$TYPE
		);
	if ($params{'UUID'}) { $db{'UUID'} = $params{'UUID'}; } else { $db{'*UUID'} = 'uuid()'; }

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($pstmt) = &DBINFO::insert($udbh,'PROJECTS',\%db,sql=>1);
	$udbh->do($pstmt);
	my ($ID,$UUID) = $udbh->selectrow_array("select ID,UUID from PROJECTS where ID=last_insert_id()");
	&DBINFO::db_user_close();
	
	my $USERPATH = &ZOOVY::resolve_userpath($USERNAME);
	if (! -d "$USERPATH/PROJECTS") {
		mkdir("$USERPATH/PROJECTS");
		chmod(0777, "$USERPATH/PROJECTS");
		}
	if (! -d "$USERPATH/PROJECTS/$UUID") {
		mkdir("$USERPATH/PROJECTS/$UUID");
		chmod(0777, "$USERPATH/PROJECTS/$UUID");
		}
	my ($P) = PROJECT->new($USERNAME,'ID'=>$ID);

	return($P);
	}

sub username { return($_[0]->{'USERNAME'}); }
sub uuid { return($_[0]->{'UUID'}); }
sub id { return($_[0]->{'ID'}); }
sub dir {
	my ($self,$CREATE) = @_;
	my $USERPATH = &ZOOVY::resolve_userpath($self->username());
	my $UUID = $self->uuid();
	

	if ($CREATE) {	
		if (! -d "$USERPATH/PROJECTS") {
			mkdir("$USERPATH/PROJECTS");
			chmod(0777, "$USERPATH/PROJECTS");
			}
		if (! -d "$USERPATH/PROJECTS/$UUID") {
			mkdir("$USERPATH/PROJECTS/$UUID");
			chmod(0777, "$USERPATH/PROJECTS/$UUID");
			}
		}

	return("$USERPATH/PROJECTS/$UUID");
	}

##
##
##
sub projectdir {	
	my ($USERNAME,$UUID) = @_;
	my $USERPATH = &ZOOVY::resolve_userpath($USERNAME);
	my $DIR = sprintf("$USERPATH/PROJECTS/%s",$UUID);
	return($DIR);
	}


##
##
##
sub new {
	my ($CLASS,$USERNAME,%params) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $self = undef;
	if ($params{'ID'}) {
		my $pstmt = "select * from PROJECTS where MID=$MID and ID=".int($params{'ID'});
		$self = $udbh->selectrow_hashref($pstmt);
		}
	elsif ($params{'DOMAIN'}) {
		my $pstmt = "select * from PROJECTS where MID=$MID and UUID=".$udbh->quote($params{'DOMAIN'});
		$self = $udbh->selectrow_hashref($pstmt);
		#if (not defined $self) {
		#	$self = DOMAIN->create($USERNAME,"DOMAIN $options{'DOMAIN'}",'UUID'=>lc($params{'DOMAIN'}));
		#	}
		}
	elsif ($params{'UUID'}) {
		my $pstmt = "select * from PROJECTS where MID=$MID and UUID=".$udbh->quote($params{'UUID'});
		$self = $udbh->selectrow_hashref($pstmt);
		}

	if (defined $self) {
		bless $self, 'PROJECT';
		}

	&DBINFO::db_user_close();
	return($self);
	}


##
##
## perl -e 'use lib "/backend/lib"; use PROJECT; my ($P) = PROJECT->new("brian",ID=>1); use Data::Dumper; print Dumper($P->allFiles());'
sub allFiles {
	my ($self) = @_;

	my @FILES = ();
	my $PROJECTDIR = $self->dir(1);
	opendir my $D, "$PROJECTDIR";
	while (my $file = readdir($D)) {
		next if (substr($file,0,1) eq '.');
		if (-d "$PROJECTDIR/$file") {
			push @FILES, [ 'D', "/", $file ];
			&recurseDir($PROJECTDIR,"/$file",\@FILES);
			}
		else {
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$PROJECTDIR/$file"); 
			push @FILES, [ 'F', "/", $file, $size, $mtime ];
			}

		}
	closedir $D;
	return(\@FILES);
	}

## called by allFiles
sub recurseDir {
	my ($PROJECTDIR,$subdir,$filesref) = @_;
	opendir my $D, "$PROJECTDIR/$subdir";
	while (my $file = readdir($D)) {
		next if (substr($file,0,1) eq '.');
		if (-d "$PROJECTDIR/$file") {
			push @{$filesref}, [ 'D', "$subdir", $file ];
			&recurseDir($PROJECTDIR,"$subdir/$file",$filesref);
			}
		else {
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$PROJECTDIR/$subdir/$file"); 
			push @{$filesref}, [ 'F', "$subdir", $file, $size, $mtime ];
			}
		}
	closedir $D;
	
	}

1;