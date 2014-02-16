package LUSER::FILES;

use strict;
use lib "/backend/lib";
require ZOOVY;


##
## pass either:
##		LU=>$LU 
##		app=>"AMAZON"
##
sub new {
	my ($CLASS, $USERNAME, %options) = @_;

	my $self = {};
	$self->{'_USERNAME'} = $USERNAME;
	$self->{'_MID'} = &ZOOVY::resolve_mid($USERNAME);
	$self->{'_LUSER'} = '';

	if (defined $options{'app'}) {
		$self->{'_LUSER'} = uc('*'.$options{'app'});
		}
	elsif (defined $options{'LU'}) {
		my $LU = $options{'LU'};
		$self->{'_LUSER'} = $LU->luser();
		}

	bless $self, 'LUSER::FILES';
	return($self);
	}

##
## utility methods:
##
sub username { return($_[0]->{'_USERNAME'}); }
sub mid { return($_[0]->{'_MID'}); }
sub luser { return($_[0]->{'_LUSER'}); }


sub filepath { 
	my ($self,$FILENAME) = @_;  
	my $path = &ZOOVY::resolve_userpath($self->username()).'/PRIVATE';
	return(sprintf("%s/%s",$path,$FILENAME));
	}


##
## get some details about the file.
##
sub file_detail {
	my ($self,$FILENAME) = @_;

	my $path = &ZOOVY::resolve_userpath($self->username()).'/PRIVATE';

	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$path/$FILENAME");

	return($ctime,$size);
	}

##
## view the plain text of the file
##
sub file_contents {
	my ($self,$FILENAME) = @_;

	my $BUFFER = '';
	my $path = &ZOOVY::resolve_userpath($self->username()).'/PRIVATE';

	if ($FILENAME eq '') {
		$BUFFER = "No filename specified";
		}
	elsif ($FILENAME =~ /[^A-Za-z0-9\-\.]/) {
		$BUFFER = "Filename contains invalid characters.";
		}
	elsif (-f "$path/$FILENAME") {
		$BUFFER = "File PRIVATE/$FILENAME does not exist";
		}
	else {	
		require File::Slurp;
		$BUFFER = File::Slurp::read_file($path."/".$FILENAME);
		# open(FILE,$path."/".$FILENAME); $/ = ""; $BUFFER = <FILE>;  $/ = "\n"; close(FILE);
		}

	return($BUFFER);
	}



sub lookup {
	my ($self, %options) = @_;

	my $USERNAME = $self->username();
	my $MID = $self->mid();
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $pstmt = "select FILETYPE,FILENAME,GUID from PRIVATE_FILES where MID=$MID /* $USERNAME */ ";

	if ($options{'GUID'}) { $pstmt .= " and GUID=".$udbh->quote($options{'GUID'}); }
	elsif ($options{'FILENAME'}) { $pstmt .= " and FILENAME=".$udbh->quote($options{'FILENAME'}); }
	elsif ($options{'FILETYPE'}) { $pstmt .= " and FILETYPE=".$udbh->quote($options{'FILETYPE'}); }
	else { $pstmt = ''; }

	print STDERR $pstmt."\n";
	my ($FILETYPE,$FILENAME, $GUID) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();
	return($FILETYPE,$FILENAME,$GUID);
	}

##
##
##
sub lookup_by_guid {
	my ($self,$guid) = @_;
	my ($FILETYPE,$FILENAME) = $self->lookup(GUID=>$guid);
	return($FILETYPE,$FILENAME);
	}

##
## set a file to expire
##
sub expire {
	my ($self, $id) = @_;

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $MID = $self->mid();
	my $USERNAME = $self->username();
	## always make sure we've got a current expiration date.
	my $pstmt = "update PRIVATE_FILES set EXPIRES=now() where EXPIRES=0 and MID=$MID /* $USERNAME */ and ID=".int($id);
	print STDERR $pstmt."\n";
	$udbh->do($pstmt);
	## add two days to the expiration.
	$pstmt = "update PRIVATE_FILES set EXPIRES=date_add(EXPIRES, interval 2 day) where MID=$MID /* $USERNAME */ and ID=".int($id);
	print STDERR $pstmt."\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	}

##
## make a file non-expiring.
##
sub preserve {
	my ($self, $id) = @_;

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $MID = $self->mid();
	my $USERNAME = $self->username();
	## always make sure we've got a current expiration date.
	my $pstmt = "update PRIVATE_FILES set EXPIRES=0 where MID=$MID /* $USERNAME */ and ID=".int($id);
	print STDERR $pstmt."\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	}

##
## file=>path_to_file (will copy the file)
## expires_gmt=>
##	type=>DEBUG|TICKET|REPORT|SYNDICATION|OTHER
##	unlink=>1 (will remove the file after copying it)
##	unique=>1	  -- will force the name to be unique
##	overwrite=>1  -- will overwrite (remove) an existing file with the same name.
##	createdby=>		-- leave blank for current user, otherwise *APP for system applications (e.g. *AMAZON)
##
## note: while not recommended, it is possible.
##
sub add {
	my ($self, %param) = @_;

	my $expires = 0;

	my $USERNAME = $self->username();
	my $MID = $self->mid();


	if ($param{'EXPIRES_GMT'}) {
		$expires = &ZTOOLKIT::mysql_from_unixtime($param{'EXPIRES_GMT'});
		}

	if (not defined $param{'meta'}) {
		$param{'meta'} = {};
		}

	my $title = $param{'title'};
	if (not defined $title) { $title = $param{'filename'}; }
	if (not defined $title) { $title = $param{'file'}; }

	my $type = $param{'type'};
	if ((not defined $type) || ($type eq '')) { $type = 'OTHER'; }

	my $buf = undef;
	my $filename = undef;
	if ((defined $param{'file'}) && (-f $param{'file'})) {
		## load a file from disk.
		($filename) = $param{'file'};
		if ($filename =~ /.*\/(.*?)$/) { $filename = $1; }
		$filename =~ s/[^\w\.\-]+/_/g;

		open F, "<$param{'file'}"; $/ = undef;
		($buf) = <F>;
		close F; $/ = "\n";
	
		if ($param{'unlink'}) {
			unlink $param{'file'};
			}
		}
	elsif ($param{'buf'}) {
		$buf = $param{'buf'};
		}
	elsif ($param{'empty'}) {
		$buf = '';
		}
	else {
		warn "No file input!\n";
		}

	if (defined $param{'filename'}) {
		$filename = $param{'filename'};
		}
	elsif (($filename eq '') && ($param{'title'} ne '')) {
		## NOTE: $filename MUST be unique or overwrite must be turned on.
		$filename = $param{'title'};
		$filename =~ s/[^\w\.\-]/_/g;
		}
	

#	if ((defined $buf) && ($options{'unique'})) {
#		## file must be unique
#		}
#
	my $reference = $param{'reference'};
	if (not defined $reference) { $reference = 0; }
	my $guid = $param{'guid'};

	if ((defined $guid) && (defined $buf) && ($param{'overwrite'})) {
		## file should overwrite previous file. 
		#my $pstmt = "select ID from PRIVATE_FILES where MID=$MID /* $USERNAME */ and GUID=".$udbh->quote($guid)." and FILETYPE=".$udbh->quote($type);
		#&DBINFO::db_zoovy_close();

		my ($udbh) = &DBINFO::db_user_connect($self->username());
		my $pstmt = "delete from PRIVATE_FILES where MID=$MID and GUID=".$udbh->quote($guid);
		$udbh->do($pstmt);

		$pstmt = "delete from PRIVATE_FILES where MID=$MID and FILENAME=".$udbh->quote($filename);
		$udbh->do($pstmt);
		&DBINFO::db_user_close();
		}

	if (($guid eq '0') || (not defined $guid)) {
		require Data::UUID;
		my $ug = new Data::UUID;
		$guid = $ug->create_str();	
		}

	if (defined $buf) {
		## write the file.
		my $path = &ZOOVY::resolve_userpath($self->username()).'/PRIVATE';
		if (! -d $path) {
			mkdir($path);
			chmod(0777,$path);
			chown $ZOOVY::EUID,$ZOOVY::EGID, $path;
			}
		if (-f "$path/$filename") {
			## hmm.. the file already exists.
			}

		if ($param{'*lm'}) {
			$param{'*lm'}->pooshmsg("DEBUG|+wrote $path/$filename");
			}
		else {
			print STDERR "WROTE: $path/$filename\n";
			}
		open F, ">$path/$filename";
		print F $buf;
		close F;
		}

	
	if (defined $buf) {
		my ($udbh) = &DBINFO::db_user_connect($self->username());

		## make sure we truncate the guid to the max allowed 36 characters.
		$guid = substr($guid,0,36);

		## UUID/GUID
		my ($pstmt) = &DBINFO::insert($udbh,'PRIVATE_FILES',{
			'USERNAME'=>$self->username(),
			'MID'=>$self->mid(),
			'CREATEDBY'=>$self->luser(),
			'CREATED'=>&ZTOOLKIT::mysql_from_unixtime(time()),
			'EXPIRES'=>$expires,
			'TITLE'=>$title,
			'FILETYPE'=>$type,
			'FILENAME'=>$filename,
			'GUID'=>$guid,
			'REFERENCE'=>$reference,
			'META'=>&ZTOOLKIT::buildparams($param{'meta'}),
			},key=>['MID','GUID'],debug=>2);
		print STDERR $pstmt."\n";
		$udbh->do($pstmt);

		## the concept below is NOT a good idea because on an existing $guid we don't know, then last_insert_id isn't
		##	set, so while this MIGHT seem like a good idea for new files, it's a shitty shitty idea for old existing
		## files because it trashes $guid
		#$pstmt = "select GUID from PRIVATE_FILES where MID=".$self->mid()." and ID=last_insert_id()";
		#my ($newguid) = $udbh->selectrow_array($pstmt);
		#if ($newguid ne '') { $guid = $newguid; }	

		&DBINFO::db_user_close();
		}
	
	return($guid);
	}


##
## a list of private files.. with some amended data.
##
sub list {
	my ($self, %filters) = @_;

	my @results = ();
	my ($udbh) = &DBINFO::db_user_connect($self->username());
	
	my $path = &ZOOVY::resolve_userpath($self->username()).'/PRIVATE';

	my $pstmt = "select * from PRIVATE_FILES where MID=".$self->mid()." /* ".$self->username()." */";
	if (defined $filters{'type'}) {
		$pstmt .= " and FILETYPE=".$udbh->quote($filters{'type'});
		}
	if (defined $filters{'guid'}) {
		$pstmt .= " and GUID=".$udbh->quote($filters{'guid'});
		}
	if ((not defined $filters{'active'}) || ($filters{'active'})) {
		## active defaults to yes.
		$pstmt .= " and (ISNULL(EXPIRES) or EXPIRES>now() or EXPIRES=0) ";
		}
	if (defined $filters{'keyword'}) {
		my $qtWORD = $udbh->quote($filters{'keyword'});
		$pstmt .= " and TITLE like concat('%',$qtWORD,'%') ";
		}
	if (defined $filters{'limit'}) {
		$pstmt .= sprintf(" order by ID desc limit 0,%d",int($filters{'limit'}));
		}

	print STDERR $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		$hashref->{'CREATED_GMT'} = &ZTOOLKIT::mysql_to_unixtime($hashref->{'CREATED'});

		if ($filters{'limit'}) {
			## if we don't limit the scope, we don't get file sizes.
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$path/$hashref->{'FILENAME'}");
			$hashref->{'SIZE'} = $size;
			}

		$hashref->{'%META'} = &ZTOOLKIT::parseparams($hashref->{'META'});
		push @results, $hashref;
		}
	$sth->finish();

	&DBINFO::db_user_close();
	return(\@results);
	}

##
## FILE=>filename
##
sub nuke {
	my ($self, %options) = @_;

	use Data::Dumper; 
	print STDERR Dumper(\%options);

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $ID = int($options{'ID'});
	my $FILE = $options{'FILE'};

	my $pstmt = "select FILENAME,ID from PRIVATE_FILES where MID=".$self->mid()." /* ".$self->username()." */ ";
	if ($ID>0) {
		$pstmt .= " and ID=".int($ID);
		}
	elsif (($ID == 0) && (defined $FILE)) {
		$pstmt .= " and FILENAME=".$udbh->quote($FILE);
		}
	print STDERR $pstmt."\n";
	($FILE,$ID) = $udbh->selectrow_array($pstmt);

	if (($ID>0) && ($FILE ne '')) {
	
		my $path = &ZOOVY::resolve_userpath($self->username()).'/PRIVATE/'.$FILE;
		unlink($path);

		$pstmt = "delete from PRIVATE_FILES where MID=".$self->mid()." /* ".$self->username()." */ and ID=".int($ID);
		print STDERR $pstmt."\n";
		$udbh->do($pstmt);
		}

	&DBINFO::db_user_close();
	}




1;
