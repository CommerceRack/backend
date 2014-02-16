package PAGE;


#use CDB_File;
use Carp;
use Data::Dumper;
use Storable;
use strict;
use YAML::Syck;

$YAML::Syck::ImplicitBinary++;
$YAML::Syck::ImplicitUnicode++;
$YAML::Syck::SingleQuote++;		# do not fucking enable this. it has issues with cr/lf 183535

use lib "/backend/lib";
require DBINFO;
require ZOOVY;
require ZTOOLKIT;

##
## a list of all well known page types that can have user defined content!
##
@PAGE::RESERVED = (
	'aboutus','contactus','privacy','return','cart','search','results','login','counter','gallery','adult','homepage'
	);

sub mid { return(&ZOOVY::resolve_mid($_[0]->{'_USERNAME'})); }
sub username { return($_[0]->{'_USERNAME'}); }
sub prt { return($_[0]->{'_PRT'}); }			## NOTE: this is resolved prt
sub domain { return($_[0]->{'_DOMAIN'}); }	## NOTE: this may be blank (for .path)
sub path { return($_[0]->{'_PATH'}); }

sub profile { 
	## there are no profile specific pieces of content for .category.pages
	if (substr($_[0]->{'_PATH'},0,1) eq '.') { return(''); }
	if ($_[0]->{'_NS'} eq '') { return(''); }
	return($_[0]->{'_NS'}); 
	}

##
## it makes more sense to access each page as a class.
## USERNAME (duh)
##	
##		if PAGE begins with a . it is assumed to a navcat.
##		if PAGE begins with a \w (alphanumeric) it is assumed to be a navcat
##		if PAGE begins with a * it is assumed to a special system page
##
##	 $options{'cache'}	 = our cache files must be newer than this to be used!
##
##
sub new {
	my ($class, $USERNAME, $PAGENAME, %options) = @_;

#	use Data::Dumper;	print STDERR "PRT: ".Dumper(\%options);
	if (not defined $USERNAME) { $USERNAME = ''; }
	if (not defined $PAGENAME) { $PAGENAME = ''; }
	my $NS = $options{'NS'};

	if (not defined $options{'cache'}) { $options{'cache'} = 0; }
	my ($DB_DOMAIN) = $options{'DOMAIN'};
	my ($DB_PRT) = $options{'PRT'};

	if ($PAGENAME eq '.') { $PAGENAME = 'homepage'; }
	if (substr($PAGENAME,0,1) eq '*') { 
		warn "Attempting to load old style page name: $PAGENAME\n";
		$PAGENAME = substr($PAGENAME,1); 
		}


	## print STDERR "PAGE NEW ".Dumper(\%options)."\n CALLED FROM".Carp::cluck()."\n";

	## BEGIN PARTITION FUNNY BUSINESS
	if (defined $options{'DATAREF'}) {
		## doesn't matter.
		}
	elsif (substr($PAGENAME,0,1) eq '.') {
		## PARTITIONS greater than zero can point at another partition to load/store data.
		##		BUT only on category pages.. not for profile specific content!
		$DB_DOMAIN = '';		## not used
		if ($DB_PRT>0) {
			my ($prtinfo) = &ZOOVY::fetchprt($USERNAME,$DB_PRT);
			if ($prtinfo->{'p_navcats'}>0) {	$DB_PRT = int($prtinfo->{'p_navcats'}); }
			}
		}
	else {
		## DOMAINS can only point at zero (they don't use partition, they are domain specific)
		$DB_PRT = 0;
		}
	## END PARTITION FUNNY BUSINESS

	my ($memd) = &ZOOVY::getMemd($USERNAME);
		
	my $self = undef;
	my $buf = '';
	my ($CREATED_GMT,$LASTMODIFIED_GMT) = (0,0,0);

	my $MEMKEY = lc("PAGE|$USERNAME~$DB_DOMAIN~$DB_PRT~$PAGENAME");
	if (defined $options{'DATAREF'}) {
		## do nothing!
		$self = $options{'DATAREF'};
		}
	elsif ($NS eq '_') {
		## this is the same "no profile"
		}
	elsif ( (my $YAML = $memd->get($MEMKEY)) ne '' ) {
		($self) = YAML::Syck::Load($YAML);
		}
	else {
		## NORMAL PAGE -- NOT REFERENCED BY ID!
		my $udbh = &DBINFO::db_user_connect($USERNAME);			
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		my $pstmt = "select CREATED_GMT,LASTMODIFIED_GMT,DATA from SITE_PAGES where MID=$MID and DOMAIN=".$udbh->quote($DB_DOMAIN)." and PRT=".int($DB_PRT)." /* README */ and SAFEPATH=".$udbh->quote($PAGENAME);
		## print STDERR "$pstmt\n";

		($CREATED_GMT,$LASTMODIFIED_GMT,$buf) = $udbh->selectrow_array($pstmt);
		if (substr($buf,0,3) eq '---') {
			## YAML
			($self) = YAML::Syck::Load($buf);
			$memd->set($MEMKEY,$buf);
			}
		elsif ($buf eq '') {
			$buf = "---\n";
			$memd->set($MEMKEY,$buf);
			}
		&DBINFO::db_user_close();	
		}

	## variables that always get set!
	$self->{'_PATH'} = $PAGENAME;
	$self->{'_USERNAME'} = $USERNAME;
	$self->{'_MODIFIED'} = 0;
	$self->{'_DOMAIN'} = $DB_DOMAIN;
	$self->{'_PRT'} = $DB_PRT;
	$self->{'_CREATED_GMT'} = $CREATED_GMT;
	$self->{'_LASTMODIFIED_GMT'} = $LASTMODIFIED_GMT;
	
	if (ref($self) ne 'PAGE') {
		bless $self, 'PAGE';
		}	

	return($self);
	}



sub DESTROY {
	if ($_[0]->{'_MODIFIED'}) { $_[0]->save(); }
	}

## returns the given flow for a specific page (used for clarity in code)
sub docid { return($_[0]->{'fl'} ); }

## returns a list of attributes in a given page
sub attribs { return(keys %{$_[0]}); }
## sets a property in a page e.g. $p->set(key,val)
##		bumps $self->{'_MODIFIED'} if it's changed.
sub set {
	my ($self, $key,$val) = @_;
	if ($self->{ lc($key) } ne $val) {
		# print STDERR "SETTING:  $self->{ lc($key) } [$key] = $val; \n";
		$self->{'_MODIFIED'}++;
		delete $self->{'_LASTMODIFIED_GMT'};
		$self->{ lc($key) } = $val;
		# THIS SEEMS LIKE A REALLY BAD IDEA.
		# $self->save();
		}
	}


## gets a property for a page e.g. $p->get(key)
sub get { 
	if (substr($_[1],0,1) eq '_') {
		## reserved value
		return($_[0]->{$_[1]});
		}
	else {
		## attribute 
		return($_[0]->{lc($_[1])});  
		}
	}


sub nuke {
	my ($self) = @_;

	my $USERNAME = $self->username();
	my $PRT = $self->prt();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "delete from SITE_PAGES where MID=$MID /* $USERNAME */ and PRT=".int($self->prt())." and DOMAIN=".$udbh->quote($self->domain())." and SAFEPATH=".$udbh->quote($self->path());
	print $pstmt."\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();
	}


## wow.. saves to either a database, or a file (based on the _PATH property)
sub save {
	my ($self) = @_;

	if (($self->{'_MODIFIED'}>0) || ($self->{'_MIGRATE'})) {
		delete $self->{'_MODIFIED'};

		#mysql> desc SITE_PAGES;
		#+------------------+---------------------+------+-----+---------+-------+
		#| Field            | Type                | Null | Key | Default | Extra |
		#+------------------+---------------------+------+-----+---------+-------+
		#| ID               | int(10) unsigned    | NO   |     | 0       |       |
		#| USERNAME         | varchar(20)         | NO   |     | NULL    |       |
		#| MID              | int(10) unsigned    | NO   | MUL | 0       |       |
		#| PRT              | tinyint(3) unsigned | NO   |     | 0       |       |
		#| PROFILE          | varchar(10)         | NO   |     | NULL    |       |
		#| SAFEPATH         | varchar(128)        | NO   |     | NULL    |       |
		#| DATA             | mediumtext          | NO   |     | NULL    |       |
		#| CREATED_GMT      | int(10) unsigned    | NO   |     | 0       |       |
		#| LASTMODIFIED_GMT | int(10) unsigned    | NO   |     | 0       |       |
		#+------------------+---------------------+------+-----+---------+-------+
		#9 rows in set (0.01 sec)

		my %data = ();
		foreach my $k (keys %{$self}) {
			next if (substr($k,0,1) eq '_');
			$data{$k} = $self->{$k};
			$data{$k} =~ s/\r\n/\n/gs;	## NOTE: YAML HATES \r's and fucks them up. 
												## converts %0d%0a to %0d%0a%0a (VERY BAD)
			}

		my ($lmt) = time();
		if (not defined $self->{'_CREATED_GMT'}) {
			$self->{'_CREATED_GMT'} = 0;
			}
		if (defined $self->{'_LASTMODIFIED_GMT'}) {
			$lmt = $self->{'_LASTMODIFIED_GMT'};
			}

		# my $DATA = '?'.&ZTOOLKIT::buildparams(\%data,1);
		my $DATA = YAML::Syck::Dump(\%data);
		my $NS = $self->profile();

		my $udbh = &DBINFO::db_user_connect($self->username());			
		my ($pstmt) = &DBINFO::insert($udbh,'SITE_PAGES',{
			MID=>$self->mid(),
			USERNAME=>$self->username(),
			PRT=>$self->prt(),
			SAFEPATH=>$self->path(),
			DOMAIN=>$self->domain(),
			PROFILE=>$self->profile(),
			DATA=>$DATA,
			LASTMODIFIED_GMT=>$lmt,
			},
			key=>
				['MID','SAFEPATH','PRT','DOMAIN'],
			on_insert=>{
				USERNAME=>$self->username(),
				CREATED_GMT=>$self->{'_CREATED_GMT'},
				},
			debug=>1+2,
			);
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		&DBINFO::db_user_close();

		## flush memcache
		my $MEMKEY = lc(sprintf("PAGE|%s~%s~%s~%s",$self->username(),$self->domain(),$self->prt(),$self->path()));
		my ($memd) = &ZOOVY::getMemd($self->username());
		$memd->delete($MEMKEY);

		$self->{'_MODIFIED'} = 0;
		}
	return();
	}


##
## returns an arrayref of hashrefs
##		safe=> modified=>
sub page_info {
	my ($USERNAME,$PROFILE,$PAGES) = @_;

	my @ar = ();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my @NSPAGES = ();
	if (($PROFILE eq '') || ($PROFILE eq 'DEFAULT')) {
		## default profile doesn't have prefix e.g. PROFILE/pagename
		@NSPAGES = @{$PAGES};
		}
	else {
		foreach my $k (@{$PAGES}) {
			if (substr($k,0,1) eq '.') {
				## navcat doesn't have profile prepended
				push @NSPAGES, "$k";
				}
			elsif (substr($k,0,1) eq '$') {
				## list doesn't have profile prepended
				push @NSPAGES, "$k";
				}
			else {
				push @NSPAGES, "$PROFILE/$k";
				}
			}
		}
	my $pstmt = "select SAFEPATH,LASTMODIFIED_GMT from SITE_PAGES where MID=$MID and SAFEPATH in ".&DBINFO::makeset($udbh,$PAGES);
	# print $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($path,$modified) = $sth->fetchrow() ) {
		# strip PROFILE/pagename
		if ($path =~ /^$PROFILE\/(.*?)$/) { $path = $1; }
		push @ar, { safe=>$path, modified=>$modified };
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@ar);
	}



#### LEGACY FUNCTIONS
####

sub init {};	
#sub page_name_sanity { return(&PAGE::resolve_filename(@_)); }
#sub page_attribs { my ($p) = PAGE->new($_[0],$_[1]); my @attribs = $p->attribs(); undef $p; return(@attribs); }
#sub savepage_attrib { my ($USERNAME,$PAGE,$ATTRIB,$VAL) = @_; my ($p) = PAGE->new($USERNAME,$PAGE); $p->set($ATTRIB,$VAL); $p->save(); undef $p; }

1;
