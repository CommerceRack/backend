#!/usr/bin/perl

use strict;
use lib "/httpd/modules";
use CFG;
use DBINFO;
use Digest::MD5;


my %params = ();
foreach my $arg (@ARGV) {
#	if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}

if (defined $params{'version'}) {
	}
elsif (defined $params{'patch'}) {
	}
else {
	die("patchid= or version= must be supplied\n");
	}

my %PATCHES = ();
my $PATCHDIR = sprintf("/httpd/patches/%s",$params{'version'});

if ($params{'version'} eq 'init') {
	}
elsif (! -d $PATCHDIR) {
	die("$PATCHDIR does not exist");
	}

if ($params{'version'} eq 'init') {
	my $sql = '';
	while (<DATA>) { $sql .= $_; }
	$PATCHES{"init"} = $sql; 
	}
elsif ($params{'patchid'}) {
	$/ = undef;
	my $contents = File::Slurp::read_file(sprintf("$PATCHDIR/%s",$params{'patchid'}));
	my $patchid = sprintf("%s/%s",$params{'version'},$params{'patchid'});
	$/ = "\n";
	$PATCHES{ $patchid } =  $contents;	
	}
elsif (defined $params{'version'}) {
	opendir my $D, $PATCHDIR;
	while ( my $file = readdir($D) ) {
		next if (substr($file,0,1) eq '.');
		my $patchid = sprintf("%s/%s",$params{'version'},$file);

		$/ = undef;
		if ($file =~ /\.perl$/) {
			my $contents = File::Slurp::read_file("$PATCHDIR/$file");
			$PATCHES{ $patchid } =  $contents ;
			}
		elsif ($file =~ /\.sql$/) {
			my $contents = File::Slurp::read_file("$PATCHDIR/$file");
			$PATCHES{ $patchid } =  $contents ;
			}		
		elsif ($file =~ /\.sh$/) {
			my $contents = File::Slurp::read_file("$PATCHDIR/$file");
			$PATCHES{ $patchid } =  $contents ;
			}		
		else {
			warn "Ignored $PATCHDIR/$file\n";
			}
		$/ = "\n";
		}
	closedir $D;
	}
else {
	die("use version=");
	}

if (scalar(keys %PATCHES)==0) {
	warn "no patches found";
	}


my ($CFG) = CFG->new();
foreach my $USERNAME (@{$CFG->users()}) {

	if (defined $params{'user'}) {
		if ($params{'user'} ne lc($USERNAME)) {
			print "skipping user:$USERNAME\n";
			next;
			}
		}

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	
	foreach my $patchid (sort keys %PATCHES) {
		print "PATCH:$patchid\n";
		my $contents = $PATCHES{$patchid};
		
		my ($RESULT,$IS_CRASHED) = ();
		if ($patchid eq 'init') {
			$IS_CRASHED = 0;
			}
		else {
			my $pstmt = "select RESULT,IS_CRASHED from PATCH_HISTORY where PATCH_ID=".$udbh->quote($patchid);
			($RESULT,$IS_CRASHED) = $udbh->selectrow_array($pstmt);
			}

		if ($params{'verb'} eq 'retry') {
			}	
		elsif ($IS_CRASHED) {
			die("FOUND PREVIOUS CRASH $patchid -- cannot proceed
to retry: ./patch.pl verb=retry patch=$patchid
to finish: ./patch.pl verb=finish patch=$patchid
");
			}
		elsif (defined $RESULT) {
			warn "Already applied $patchid\n";
			next;
			}
		elsif ($contents eq '') {
			die "contents for patchid: $patchid are empty!\n";
			}
		elsif ($patchid eq 'init') {
			## initialize the PATCH_HISTORY database
			warn "initialized PATCH_HISTORY table\n";
			$udbh->do(" drop table if exists PATCH_HISTORY;  ");

			$udbh->do($contents);
			next;
			}

		my $DBID = 0;
		if (($params{'verb'} eq 'retry') || ($params{'verb'} eq 'force')) {
			my $pstmt = "delete from PATCH_HISTORY where PATCH_ID=".$udbh->quote($patchid);
			print $pstmt."\n";
			$udbh->do($pstmt);
			}

		my $pstmt = &DBINFO::insert($udbh,'PATCH_HISTORY',	{
			'PATCH_ID'=>$patchid,
			'PATCH_MD5'=>Digest::MD5::md5_hex($contents),
			'*APPLIED_TS'=>'now()',
			'RESULT'=>'STARTED',
			'IS_CRASHED'=>1,
			'LOG'=>''
			},verb=>'insert',sql=>1);
		print $pstmt."\n";
		$udbh->do($pstmt);
		$DBID = $udbh->selectrow_array("select last_insert_id()");
		if (($DBID <= 0) && ($params{'verb'} ne 'force')) {
			warn "DB Error: failed to create DBID for patch $patchid\n";
			die();
			}
		
		if ($patchid =~ /\.cpan$/) {
			use CPAN;
			foreach my $line (split(/[\n\r]+/,$contents)) {
				next if ($line eq '');
				CPAN::Shell->install($line);
				}
			}
		elsif ($patchid =~ /\.sql$/) {
			my @ROWS = ();
			my ($SQL) = '';
			my $startline = 0;
			my $this_line_num = 0;
			foreach my $line (split(/[\n\r]/,$contents)) {
				$this_line_num++;
				if ($SQL eq '') { $startline = $this_line_num; $SQL .= "/* line: $this_line_num */ "; }
				$SQL .= $line;
				chomp($line);
		
			 	if ($line eq "") { 
					push @ROWS, [$startline, $SQL]; $SQL = '';
					}
			   }
			if ($SQL ne '') {
				push @ROWS, [$startline, $SQL];
				}

			foreach my $rowset (@ROWS) {
				my ($linenum,$pstmt) = @{$rowset};
				print $pstmt."\n";
				$udbh->do($pstmt);
				}
			$pstmt = "update PATCH_HISTORY set IS_CRASHED=0,RESULT='FINISHED' where ID=$DBID";
			print "$pstmt\n";
			$udbh->do($pstmt);
			}
		elsif ($patchid =~ /\.perl$/) {
			eval "$contents";
			print $@."\n";
			if ($@) { die(); }

			$pstmt = "update PATCH_HISTORY set IS_CRASHED=0,RESULT='FINISHED' where ID=$DBID";
			print "$pstmt\n";
			$udbh->do($pstmt);
			}
		elsif ($patchid =~ /\.sh$/) {
			system("$PATCHDIR/$patchid");
			$pstmt = "update PATCH_HISTORY set IS_CRASHED=0,RESULT='FINISHED' where ID=$DBID";
			print "$pstmt\n";
			$udbh->do($pstmt);
			}
		else {
			die("unknown patch type: $patchid\n");
			}

		}


	&DBINFO::db_user_close();
	}


__DATA__


create table PATCH_HISTORY (
	ID integer unsigned auto_increment,
	PATCH_ID varchar(128) default '' not null,
	PATCH_MD5 varchar(32) default '' not null,
	APPLIED_TS timestamp default 0 not null,
	RESULT varchar(10) default '' not null,
	IS_CRASHED tinyint default 0 not null,
	LOG mediumtext default '' not null,
	primary key(ID),
	unique(PATCH_ID)
	) ENGINE=MyISAM;

