package TEMPLATE;

use strict;

use File::Copy::Recursive;
use File::Slurp qw();
use MIME::Base64 qw();
use lib "/backend/lib";
require JSONAPI;
require PROJECT;

$TEMPLATE::VERSION = $JSONAPI::VERSION;

#create table TEMPLATES (
#        MID integer unsigned default 0 not null,
#        USERNAME varchar(20) default '' not null,
#        PROJECTID varchar(36) default '' not null,
#        TEMPLATETYPE varchar(10) default '' not null,
#        SUBDIR varchar(45) default '' not null,
#        VERSION decimal(6,0) default 0 not null,
#        GUID varchar(36) default '' not null,
#        YAML mediumtext,
#        HTML mediumtext,
#   CREATED_TS timestamp,
#        MODIFIED_TS timestamp,
#        LOCK_ID integer unsigned default 0 not null,
#        primary key(MID,TEMPLATETYPE,SUBDIR),
#        index(MID,PROJECTID)
#        );
#


sub TO_JSON {
	my ($self) = @_;
	my %R = ();
	foreach my $k (keys %{$self}) { $R{$k} = $self->{$k}; }
	return(\%R);
	}




sub create {
	my ($USERNAME,$TYPE,$PROJECT,$NAME) = @_;

#create table TEMPLATES (
#   MID integer unsigned default 0 not null,
#   USERNAME varchar(20) default '' not null,
#   PROJECTID varchar(36) default '' not null,
#   TEMPLATETYPE varchar(10) default '' not null,
#   SUBDIR varchar(45) default '' not null,
#   VERSION decimal(6,0) default 0 not null,
#   GUID varchar(36) default '' not null,
#   JSON mediumtext,
#   HTML mediumtext,
#   CREATED_TS timestamp,
#   MODIFIED_TS timestamp,
#   LOCK_ID integer unsigned default 0 not null,
#   primary key(MID,TEMPLATETYPE,SUBDIR),
#   index(MID,PROJECTID)
#   );

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my %vars = ();
	$vars{'MID'} = &ZOOVY::resolve_mid($USERNAME);
	$vars{'USERNAME'} = $USERNAME;
	$vars{'PROJECTID'} = $PROJECT;
	$vars{'TEMPLATETYPE'} = $TYPE;
	$vars{'SUBDIR'} = $NAME;
	$vars{'VERSION'} = $TEMPLATE::VERSION;
	$vars{'*GUID'} = 'uuid()';
	$vars{'*CREATED_TS'} = 'now()';
	$vars{'*MODIFIED_TS'} = 'now()';
	my ($pstmt) = &DBINFO::insert($udbh,'TEMPLATES',\%vars,'verb'=>'insert','sql'=>1);
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	}

sub syslistpath {
	my ($TEMPLATETYPE) = @_;

	$TEMPLATETYPE = lc($TEMPLATETYPE);
	if ($TEMPLATETYPE eq 'campaign') { $TEMPLATETYPE = 'campaigns'; }
	if ($TEMPLATETYPE eq 'cpg') { $TEMPLATETYPE = 'campaigns'; }
	if ($TEMPLATETYPE eq 'site') { $TEMPLATETYPE = 'sites'; }
	
	my $ATTEMPTS = 0;
	my $SUBDIR = undef;
	do {
		$SUBDIR = sprintf("/httpd/static/templates/%s-%s.yaml",lc($TEMPLATETYPE), ($TEMPLATE::VERSION - $ATTEMPTS) );
		$ATTEMPTS++;
		} while ((! -f $SUBDIR) && ($ATTEMPTS < 100));

	return($SUBDIR);
	}

##
##
##
sub list {
	my ($USERNAME,$TYPE,%options) = @_;

	$TYPE = uc($TYPE);

	my @LIST = ();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select * from TEMPLATES where MID=$MID and TEMPLATETYPE=".$udbh->quote($TYPE);
	my ($sth) = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $ref = $sth->fetchrow_hashref() ) {
		push @LIST, $ref;

		my $DIR = '';
		if ($TYPE eq 'SITE') { $DIR = 'sites'; }
		if ($TYPE eq 'EBAY') { $DIR = 'ebay'; }
		if ($TYPE eq 'CPG') { $DIR = 'campaigns'; }
		my $dir = sprintf("%s/PROJECTS/%s/templates/%s/%s",&ZOOVY::resolve_userpath($USERNAME),$ref->{'PROJECTID'},$DIR,$ref->{'SUBDIR'});
		my $found = 0;
		do {
			my $filename = 'preview'.(($found>0)?"-$found":"").'.png';
			## print STDERR "THUMBS: $dir/$filename";
			if (-f "$dir/$filename") {
				my $bin = File::Slurp::read_file( "$dir/$filename", { binmode => ':raw' } ) ;
				push @{$ref->{'@PREVIEWS'}}, { 'filename'=>$filename, type=>"image/png", base64=>MIME::Base64::encode_base64($bin,'') };
				$found++;
				}
			else {
				$found = -1;	## not found.
				}
			} while ($found>0);
		}
	$sth->finish();
	&DBINFO::db_user_close();

	my ($SUBDIR) = &TEMPLATE::syslistpath($TYPE);
	print STDERR "SUBDIR: $SUBDIR\n";
	if (-f $SUBDIR) {
		my $LISTREF = YAML::Syck::LoadFile($SUBDIR);
		foreach my $ref (@{$LISTREF}) {
			push @LIST, $ref;
			}
		}

	return(\@LIST);
	}


sub new {
	my ($class,$USERNAME,$TYPE,$PROJECTID,$SUBDIR) = @_;

	my $self = {};
	$self->{'USERNAME'} = $USERNAME;
	$self->{'TEMPLATETYPE'} = uc($TYPE);
	$self->{'PROJECTID'} = $PROJECTID;
	$self->{'SUBDIR'} = $SUBDIR;

	bless $self, 'TEMPLATE';
	return($self);
	}

sub templatetype { return($_[0]->{'TEMPLATETYPE'}); }
sub projectid { return($_[0]->{'PROJECTID'}); }
sub username { return($_[0]->{'USERNAME'}); }
sub subdir { return($_[0]->{'SUBDIR'}); }

sub exists { 
	my ($self) = @_; return( (-d $self->dir())?1:0 ); 
	}


##
##
##
sub install {
	my ($self,$DESTID,%head) = @_;


	my $templatedir = $self->dir();
	my ($success) = 0;

	my $userpath = '';
	if (! -d $templatedir) {
		}
	elsif ($self->templatetype() eq 'EBAY') {
		$DESTID = uc($DESTID);
		$DESTID =~ s/[^A-Z0-9]//gs;
		$userpath = &ZOOVY::resolve_userpath($self->username()).'/IMAGES/_ebay';
		}
	elsif (($self->templatetype() eq 'CAMPAIGN') || ($self->templatetype() eq 'CPG')) {
		$DESTID = uc($DESTID);
		$DESTID =~ s/[^A-Z0-9\-\_]//gs;
		$userpath = &ZOOVY::resolve_userpath($self->username()).'/IMAGES/_campaigns';
		}
	elsif ($self->templatetype() eq 'SITE') {
		$DESTID = lc($DESTID);
		$DESTID =~ s/[^a-z0-9\-\.]//gs;
		$userpath = &ZOOVY::resolve_userpath($self->username()).'/PROJECTS';
		}
	else {
		warn "UNKNOWN $self->templatetype() =".$self->templatetype()."\n";
		$DESTID = uc($DESTID);
		}

	if ($userpath ne '') {
		## make the copy of all files
		if (! -d $userpath) { mkdir($userpath); chmod 0777, $userpath; }
		$userpath .= "/".$DESTID;
		if (! -d $userpath) { mkdir($userpath); chmod 0777, $userpath; }
		#my $CMD = "cd $templatedir; /bin/tar -c * | /bin/tar --directory=$userpath -x";
		#print STDERR "$CMD\n";
		#system($CMD);
		print STDERR "COPY: $templatedir/* => $userpath\n";
		$File::Copy::Recursive::CPRFComp = 1;
		my ($num_of_files_and_dirs,$num_of_dirs,$depth_traversed) = File::Copy::Recursive::dircopy( "$templatedir/*", $userpath );

		if ($self->templatetype() eq 'SITE') {
			##
			
			}
		elsif ((-f "$userpath/index.html") && (scalar(keys %head)>0)) {
			## CAMPAIGN/EBAY	- 	add baseURL to index.html
			my $head = '';
			$head .= "<HEAD>\n";
			$head .= qq~<meta name="generator" content="CommerceRack http://www.commercerack.com/ " />\n~;
			foreach my $k (keys %head) {
				$head .= qq~<meta name="$k" content="$head{$k}" />\n~;
				}
			if (defined $head{'base'}) {
				$head .= qq~<base href="$head{'base'}" />\n~;
				}
			$head .= "</HEAD>\n";
			File::Slurp::prepend_file("$userpath/index.html", $head);
			}

		$success++;
		}

	if ($self->templatetype() eq 'SITE') {
		## this will make us flush the cache
		my $USERNAME = $self->username();
		my ($MEMD) = &ZOOVY::getMemd($USERNAME);
		use Data::Dumper; print STDERR 'DESTID: '.Dumper("$USERNAME.$DESTID");
		$MEMD->delete("$USERNAME.$DESTID");
		}
	
	return($success);
	}

##
##
##
sub dir {
	my ($self) = @_;

	my ($USERNAME) = $self->username();
	my ($PROJECTID) = $self->projectid();
	my ($SUBDIR) = $self->subdir();
	my ($TYPE) = uc($self->templatetype());

	my $TYPEPATH = $TYPE;
	if ($TYPE eq 'CAMPAIGN') { $TYPEPATH = 'campaigns'; }
	if ($TYPE eq 'CPG') { $TYPEPATH = 'campaigns'; }
	if ($TYPE eq 'EBAY') { $TYPEPATH = 'ebay'; }
	if ($TYPE eq 'SITE') { $TYPEPATH = 'sites'; }
	$SUBDIR =~ s/[^a-z0-9A-Z\-\_]+//gs;	## filter non-allowed characters

	my $templatedir = '';
	if ($PROJECTID eq '$SYSTEM') {
		$templatedir = sprintf("/httpd/static/templates/%s/%s",$TYPEPATH,$SUBDIR);
		}
	elsif ($PROJECTID eq 'LEGACY') {
		$templatedir = sprintf("%s/PROJECTS/LEGACY/%s/%s",&ZOOVY::resolve_userpath($USERNAME),$TYPEPATH,$SUBDIR);
		}
	elsif ($PROJECTID eq 'TEMPLATES') {
		$templatedir = sprintf("%s/PROJECTS/TEMPLATES/%s/%s",&ZOOVY::resolve_userpath($USERNAME),$TYPEPATH,$SUBDIR);
		}
	else {
		my ($P) = PROJECT->new($USERNAME,'UUID'=>$PROJECTID);
		$templatedir = sprintf("%s/%s/%s",$P->dir(),$TYPEPATH,$SUBDIR);
		}

	return($templatedir);
	}








1;