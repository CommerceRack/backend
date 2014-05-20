package NAVCAT;


##
## Navcat object format;
##	$self = {
##		_USERNAME => username
##		_READONLY => 0|1 (has the contents been changed)
##		'.safe' 	 => [ 
##				'pretty(0)', 
##				'children(1)', 
##				'products(2)', 
##				'sort(3)', 
##				'metaref(4)'=>{ 'key1'=>'val1', 'key2'=>'val2' }, 
##				modified_gmt(5) 
##				];
##		inside metaref
##			CAT_THUMB
##			PRIORITY
##
##
##


#create table NAVCATS (
#   ID integer unsigned auto_increment,
#   USERNAME varchar(20) default '' not null,
#   MID integer unsigned default 0 not null,
#   SAFE VARCHAR(255) default '' not null,
#   PRODUCTS_YAML mediumtext default '' not null,
#   META_YAML text default '' not null, 
#   primary key(ID)
#);

use YAML::Syck;
use Storable; 
use strict;


require ZOOVY;
require ZTOOLKIT;

sub username { return($_[0]->{'_USERNAME'}); }
sub prt { return($_[0]->{'_PRT'}); }
sub rootpath { return($_[0]->{'_ROOT'}); }

sub encode_meta {	return(&ZTOOLKIT::makecontent($_[0],1,1,1)); }
sub decode_meta { return(&ZTOOLKIT::parseparams($_[0])); }


sub DESTROY {
	my ($this) = @_;

	if ((defined $this->{'_LOCK'}) && ($this->{'_LOCK'}>0)) {
		warn "NAVCAT release lock!";
		&ZOOVY::release_lock($this->username(),$this->{'_LOCK'});
		}

	if ((defined $this->{'_READONLY'}) && ($this->{'_READONLY'}>0)) {}
	else {
		$this->save();
		undef $this;
		}
	return(undef);
	}



##
## generates elastic payloads for a safe=> or pid=> (or the whole thing)
##
#  perl -e 'use lib "/httpd/modules"; use NAVCAT; my ($NC) = NAVCAT->new("sporks",0); use Data::Dumper; 
# print Dumper($NC->elastic_payloads());'
sub elastic_payloads {
	my ($self, %params) = @_;

	my @ES_PAYLOADS = ();
	my @paths = ();
	if (defined $params{'safe'}) {
		push @paths;
		}
	else {
		@paths = $self->paths();
		}

	foreach my $safe (@paths) {
		my %vars = ();
		my ($pretty,$children,$products,$sort,$metaref) = $self->get($safe);
		# $vars{'hidden'} = (substr($pretty,0,1) eq '!')?1:0;
		next if (substr($pretty,0,1) eq '!');
		$vars{'path'} = $safe;
		$vars{'prt'} = $self->prt();
		foreach my $pid (split(/,/,$products)) {
			next if ($pid eq '');
			next if ((defined $params{'pid'}) && ($params{'pid'} ne $pid));
			push @ES_PAYLOADS, { 'type'=>'navcat', 'id'=>sprintf("%d~%s~%s",$self->prt(),$pid,$safe), 'parent'=>$pid, 'doc'=>{ %vars, 'pid'=>$pid}  };
			}
		}
	
	return(\@ES_PAYLOADS);
	}


##
## perl -e 'use lib "/backend/lib"; use NAVCAT; my ($NC) = NAVCAT->new("brian",PRT=>0); print $NC->to_json(".");'
##
sub to_json {
	my ($self,$safe) = @_;

	my %vars = ();
	$vars{'safe'} = $safe;
	($vars{'pretty'},$vars{'children'},$vars{'products'},$vars{'sort'},$vars{'%meta'}) = $self->get($safe);

	require JSON::XS;
	my $json = JSON::XS::encode_json(\%vars);

	return($json);
	}


##
## returns either navcats.bin
##		or navcats-#.bin (if the partition is enabled to have unique navcats)
##
sub prtfilename {
	my ($USERNAME,$PRT) = @_;

	my $filename = 'navcats.bin';
	if ($PRT == 0) {
		## this is always default.. it can't be changed.
		}
	else {
		my ($prtinfo) = &ZOOVY::fetchprt($USERNAME,$PRT);
		if ($prtinfo->{'p_navcats'}>0) {
			$PRT = int($prtinfo->{'p_navcats'});
			$filename = 'navcats-'.int($PRT).'.bin'; 
			}
		}
	return($PRT,$filename);
	}


##
## options: 
##		root=> specifies an alternate site root (e.g. .abc) .. only categories below that point are visible.
##		cache=> 
##			-1 - use publisher (prt=0)
##			0 - no caching, 
##			1 - use'em if you got 'em.
##			2 - don't use cache AND rebuild file.
##
##		PRT=>$prt
##
##
sub new {
	my ($class, $USERNAME, %options) = @_;
	
	my $self = undef;
	my $fqfilename = '';

	my $userdir = &ZOOVY::resolve_userpath($USERNAME);
	my ($PRT,$filename) = &NAVCAT::prtfilename($USERNAME,int($options{'PRT'}));

	my $LOCK_ID = undef;
#	print STDERR "NAVCATCACHE: $options{'cache'}\n";
#	if ($options{'lock'}) {
#		## we're might be updating so we're going to need to get a lock, and release a lock.
#		my $attempts = 30;	## max attempts to get a lock.
#		$LOCK_ID = 0;
#		while (($LOCK_ID==0) && ($attempts-->0)) {
#			($LOCK_ID) = &ZOOVY::lock($USERNAME,$PRT,'NAVCAT','',&ZOOVY::lock_appid("NAVCAT",1));
#			if ($LOCK_ID==0) {
#				warn "Could not obtain lock for NAVCAT .. attempt: $attempts";
#				sleep(1);
#				}
#			}
#
#		if ($LOCK_ID==0) {
#			warn "Unable to obtain NAVCAT lock!";
#			}
#		## note: currently we'll still read on a LOCK fail.
#		}

	if (not defined $options{'cache'}) { $options{'cache'} = 0; }
	#if ($options{'cache'}<0) {
	#	## SITE PUBLISHER
	#	my $PRT = abs($options{'cache'})-1;
	#	$self = YAML::Syck::LoadFile(&ZOOVY::pubfile($USERNAME,$PRT,"navcats-$PRT.yaml"));
	#	}

	if (defined $self) {
		## yay, short circuit!
		}
	elsif ($options{'cache'}>0) {
		# print STDERR "CACHE: $options{'cache'}\n";
		## this tells us that it's okay to make+use local copies of data
		## LEGACY CACHING METHOD

		$fqfilename = &ZOOVY::cachefile($USERNAME,$filename);
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($fqfilename);
		if (($options{'cache'}==1) && ($dev>0)) {
			## cache==1 means ALWAYS cache (regardless of age) generally used in search
			## but we set cache to zero since we definitely don't want to write what we just read.
			$options{'cache'} = 0;
			}
		elsif (($options{'cache'}==666) && ($dev>0)) {
			## cache==666 means *BOT* ALWAYS cache (regardless of age) generally used in search
			## but we set cache to zero since we definitely don't want to write what we just read.
			$options{'cache'} = 0;
			}
		elsif (($options{'cache'}>1) && ($options{'cache'} < $mtime)) {
			## hurray, we can use a cached copy without fear of reprisal! (since we have the most current one)
			}
		else {
			## crap, no cache file exists, or it's expired, we'll create a new one!
			$fqfilename = $userdir.'/'.$filename;
			$options{'cache'} = 1;
			}
		}
	else {
		my ($package,$file,$line,$sub,$args) = caller(1);
   	print STDERR "NAVCAT OPEN [$USERNAME-$PRT] $package,$file,$line,$sub,$args (CACHE:$options{'cache'}) ".&ZTOOLKIT::buildparams(\%options)."\n";
		
		$fqfilename = $userdir.'/'.$filename;
		}

	# print STDERR "NAVCAT FILE: $fqfilename\n";

	if (defined $self) {
		## hmm.. probably already got this from site publisher.
		}
	elsif (-f $fqfilename) {
		$self = eval { retrieve $fqfilename; };

		if (not defined $options{'attempt'}) { $options{'attempt'} = 0; }
		if ($options{'attempt'}>5) {
#			print STDERR "NAVCAT: Could not load NAVCAT file for $USERNAME";
			die("Unable to open file: $fqfilename");
			}		
		elsif (not defined $self) {
			$options{'attempt'}++;
			## after 3 attempts, stop using the cached version.
			if ($options{'attempt'}>4) { $options{'cache'} = 0; }
			## cache will often be a timestamp, but we only respect "1"
			if ($options{'cache'}>0) { $options{'cache'}=1; }
#			print STDERR "NAVCAT: RETRY ATTEMPT [$options{'attempt'}]\n";
			select(undef,undef,undef,0.25);
			$self = NAVCAT->new($USERNAME,%options);
			}
		}

	if (not defined $self) {
		$self->{'.'} = [ 'Homepage' ];
		$options{'cache'} = 0;
		}


	$self->{'_USERNAME'} = $USERNAME;
	$self->{'_ROOT'} = '.';				## only categories from below this point are visible (in things like paths)
	$self->{'_PRT'} = $PRT;
		
	if (not defined $LOCK_ID) {
		delete $self->{'_LOCK'};
		}
	else {
		$self->{'_LOCK'} = $LOCK_ID;
		}

	if (defined $options{'root'}) { $self->{'_ROOT'} = $options{'root'}; }

	delete $self->{'*READONLY'};
	delete $self->{'*KEYS'};
	bless $self, 'NAVCAT';	

	$self->{'_READONLY'} = 1;			## by default this is readonly (this will get set to zero when a value is changed/modified)

	if ($options{'cache'}==1) {
		## REBUILD THE FILE!
		$fqfilename = &ZOOVY::cachefile($USERNAME,$filename);
		Storable::nstore $self, $fqfilename;
		chmod 0666, $fqfilename;
		if ($< != $ZOOVY::EUID) { 
			chown $ZOOVY::EUID,$ZOOVY::EGID, $fqfilename; 
			}
		}

	return($self);
	}



##
## moves a safename across the tree
##
sub remap {
	my ($self,$src,$dest) = @_;
		
	print STDERR "REMAP SRC: $src DEST: $dest\n";
	$self->{$dest} = $self->{$src};
	delete $self->{$src};
	my ($PGOLD) = PAGE->new($self->username(),$src,PRT=>$self->prt());
	my ($PGNEW) = PAGE->new($self->username(),$dest,PRT=>$self->prt());
	foreach my $k ($PGOLD->attribs()) {
		$PGNEW->set($k,$PGOLD->get($k));
		}
	$PGNEW->save();
	$PGOLD->nuke();
	}


##
## $mode = 0 default, save + sort
##			  1 = quick save, ignores sort requests.
##
sub save {
	my ($self, $mode) = @_;

	if (not defined $self) {};


	my $USERNAME = $self->{'_USERNAME'};
	if (not defined $USERNAME) { return(); }

	my $t = &ZOOVY::servername().'-'.time().'-'.$$.'-'.rand();

	if (defined $self->{'_SORT'}) {
		foreach my $safe (keys %{$self->{'_SORT'}}) {
			next if (not defined $self->{$safe});
			$self->{$safe}->[2] = $self->sort($safe);
			}
		delete $self->{'_SORT'};
		}

	if (defined $self->{'_REVERSE'}) {
		## reverse lookup
		delete $self->{'_REVERSE'};
		}

	delete $self->{'_USERNAME'};	
	my ($PRT,$filename) = &NAVCAT::prtfilename($USERNAME,$self->{'_PRT'});

	my $fqfilename = &ZOOVY::resolve_userpath($USERNAME,1).'/'.$filename;

	Storable::nstore $self, $fqfilename.'-'.$t;
	chmod(0666,$fqfilename.'-'.$t);

	my ($OLDdev,$OLDino,$OLDmode,$OLDnlink,$OLDuid,$OLDgid,$OLDrdev,$OLDsize,$OLDatime,$OLDmtime,$OLDctime,$OLDblksize,$OLDblocks) = stat($fqfilename);
	## cleanup our old backup.
   unlink($fqfilename.'.old');
	## okay so now we have TWO copies of the file .. filename and filename.old 
	link($fqfilename,$fqfilename.'.old');
	## get rid of the original.
	rename($fqfilename.'-'.$t,$fqfilename);

   my ($dev,$ino,$smode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($fqfilename);
	if ($OLDctime+30<$ctime) {
		# we will NOT replicate more than once every 30 seconds.
		&ZOOVY::touched($USERNAME,1);
		}
	else {
		
		}

	$self->{'_USERNAME'} = $USERNAME;
	$self->{'_READONLY'} = 1;		# okay, so we're all synced until we make changes

	my $APP = $ENV{'REQUEST_URI'};
	if ($APP eq '') { $APP = $0; }

	&ZOOVY::log($USERNAME,"*SYSTEM","NAVCAT.SAVE",
		sprintf("server:%s app:%s",&ZOOVY::servername(1),$APP),
		"SAVE");

	return($self);
	}



##
## hmm.. for now, this returns 
##
sub get {
	my ($self, $path) = @_;

	if (substr($path,0,1) eq '.') {
		## safe names.
		}
	elsif ((substr($path,0,1) eq '$') && (defined $self->{$path})) {
		## lists that exist.
		}
	elsif (not defined $self->{$path}) { 
		my $pidscsv = '';
		## check to see if we've got a virtual category.
		if ($path =~ /\$prodlist\:(.*?)\.([a-z0-9\_]+)$/) {
			## $prodlist:pid1.prod_accessory
			my ($pid,$attrib) = ($1,$2);
			&ZOOVY::confess($self->username(),"LEGACY ATTEMPT TO ACCESS VIRTUAL PRODLIST zoovy:$attrib",'justkidding'=>1);
			my ($P) = PRODUCT->new($self->username(),$pid,'create'=>0)->fetch("zoovy:$attrib");
			#($pidscsv) = &ZOOVY::fetchproduct_attrib($self->username(),$pid,"zoovy:$attrib");			
			}
		#elsif ($path =~ /\$page:(.*?)\.([a-z0-9\_]+)$) {
		#	my ($pg) = PAGE->new($USERNAME,$SITE::PG,NS=>$NS,PRT=>$SREF->{'+prt'}); 
		#	($pidcsv) = $pg->get($tag);
		#	}
		elsif ($path =~ /\$tagged:prod_is\.(.*)$/o) {
			## looksup tagged products returns them in semi-sorted order.	
			my ($tag) = uc($1);
			my $PROD_IS_FILTER = 0;
			foreach my $isa (@ZOOVY::PROD_IS) {
				next unless ($isa->{'tag'} eq $tag);
				$PROD_IS_FILTER |= (1<<$isa->{'bit'}); 
				}
			my ($productsref) = &ZOOVY::fetchproducts_by_nameref($self->username(),prod_is=>$PROD_IS_FILTER);
			$pidscsv = join(',',keys %{$productsref});
			}
		## short circuit
		return($path, '', $pidscsv, '', {});
		}

	
	if (not defined $self->{$path}) {
		## path itself is invalid - return undef, this is necessary otherwise setting $self->{$path}->[4] = {} 
		## will create a bogus/invalid category.
		return(undef);
		}
	elsif ((ref($self->{$path}->[4]) ne 'HASH')) {
		$self->{$path}->[4] = {};	# make sure pos 4 is always a ref
		}

	return(@{$self->{$path}});
	}



##
## parameters: safename, product(optional)
##		($self,$path,$pid) = @_;
##	OR ($_[0],$_[1],$_[2])
sub exists { 
	## by default we return a 1 or 0 if a category exists
	if (defined $_[2]) {
		if (defined $_[0]->{$_[1]}) {	# category exists.
			return (index(','.$_[0]->{ $_[1] }->[2].',', ','.$_[2].',')>=0)?1:0;
			}
		}
	elsif ($_[1] eq '.') {
		return(1);
		}
	else {
		## just verifies the existance of a category
		return( (defined $_[0]->{$_[1]})?1:0 ); 
		}
	}


##
## returns -1 for does not exist, 0 for modified unknown otheriwse an mtime
sub modified {
	if (not defined $_[0]->{$_[1]}) {	# category does not exist
		return(0);
		}
	else {
		my $ts = $_[0]->{$_[1]}->[5];
		if (not defined $ts) { $ts = time(); }
		return($ts);
		}
	}

##
## returns the depth of a given category 
##		NOTE: eventually this might support base domain
##		returns -1 for a list
##		
sub depth {
	my ($self,$safe) = @_;

	if (substr($safe,0,1) eq '$') { return(-1); }
	elsif ($safe eq '.') { return(0); }
	else {
		$safe =~ s/[^\.]+//gs; 	# remove all non-periods
		return(length($safe)-1);
		}	
	}


## 
## prints out a breadcrumb e.g. / asdf / foo / asdf for a given safename 
##
sub pretty_path {
	my ($self, $safe, %options) = @_;
	
	my $delimiter = $options{'delimiter'};
	if (not defined $delimiter) { $delimiter = ' / '; }
	my $subpath = '';
	my $prettyname = '';
	foreach my $path (split(/\./,$safe)) {
		next if (!defined($path));
		next if ($path eq '');
		next if ($path eq '.');
		$subpath .= '.'.$path;
		# print STDERR "Subpath: subpath=[$subpath] path=[$path]\n";
		my ($pretty) = $self->get($subpath);
		$prettyname .= (($prettyname ne '')?$delimiter:'').$pretty;
		}
	return($prettyname);
	}


##
## sets a navcat by safename
## parameters: safename, key=>value
##		keys are: 
##			pretty - pretty name 
##			products	- comma separated list of values.
##			sort - sort direction
##			metaref - meta hashref (overrides meta)
##				metastr - a meta encoded string (gets converted to metaref)
##			
##
sub set {
	my ($self, $path, %options) = @_;

	$self->{'_READONLY'} = 0;	
	if (not defined $self->{$path}) {
		$self->{$path} = [];		# create a new entry.
		}

	$path =~ s/[\r\n]+//gs;		## strip invalid characters from path

	if (defined $self->{$path}) {
		}	# path already exists, assume it is valid.
#	elsif ((substr($path,0,1) eq '$') && ($path =~ /:/)) {
#		## special uri path
#
#			# print STDERR "saving: [$USERNAME][$pid][$attrib] new=[$prodnew]\n";
#			&ZOOVY::saveproduct_attrib($USERNAME,$pid,$attrib,$prodnew);
#
#		}
	elsif (length($path)>1) {
		## this does some path formatting/validation.
		$path = lc($path);
		$path =~ s/[^a-z0-9\-\_\.\$]+/_/gs;     # strips invalid characters in path.
		$path =~ s/\.[\.]+/\./gs;           # changes ..... to just .
		while (substr($path,-1) eq '.') { $path = substr($path,0,-1); }  # strip unlimited trailing dots off path.

		if (substr($path,0,1) eq '.') {
			}
		elsif (substr($path,0,1) ne '$') {
			$path =~ s/\./_/gs;		# changes . to _ for lists.
			}
		else { $path = '.' . $path; }
		&ZOOVY::add_event($self->username(),'NAVCAT.CREATED',PRT=>$self->prt(),SAFE=>$path);
      }

	if (defined $options{'metastr'}) {
		## metastr does a full override of metaref
		$options{'metaref'} = &NAVCAT::decode_meta($options{'metastr'});
		}

	if ((defined $options{'metaref'}) && (ref($options{'metaref'}) ne 'HASH')) {
		$options{'metaref'} = {};
		}

	if (defined $options{'products'}) {
		if (substr($options{'products'},0,1) eq ',') { $options{'products'} = substr($options{'products'},1); }
		if (substr($options{'products'},-1) eq ',') { $options{'products'} = substr($options{'products'},0,-1); }
		$self->{'_SORT'}->{$path}++;
		}

	$self->{$path} = [ 
		((not defined $options{'pretty'})?$self->{$path}->[0]:$options{'pretty'}),
		((not defined $options{'children'})?$self->{$path}->[1]:$options{'children'}),
		((not defined $options{'products'})?$self->{$path}->[2]:$options{'products'}),
		((not defined $options{'sort'})?$self->{$path}->[3]:$options{'sort'}),
		((not defined $options{'metaref'})?$self->{$path}->[4]:$options{'metaref'}),
		((not defined $options{'modified_gmt'})?time():$options{'modified_gmt'})
		];

	if (not defined $self->{'_SORT'}) { $self->{'_SORT'} = {}; }

	## note: add_product is actually insert_product
	if ((defined $options{'insert_product'}) && (defined $options{'position'})) {
		## note: position specific

		my $insertpos = int($options{'position'});
		my $ADDME = $options{'insert_product'};

		my $orig = $self->{$path}->[2];

		my @PIDS = ();
		my $i = 0;
		my $added = 0;
		foreach my $this (split(/,/,$self->{$path}->[2])) {
			if ($i == $insertpos) {
				push @PIDS, $ADDME; $i++; $added++;
				}

			if ($this eq $ADDME) {
				## don't re-add the current product
				}
			else {
				push @PIDS, $this;
				$i++;
				}
			}

		if (not $added) {
			## it wasn't added, so we should add it to the end.
			push @PIDS, $ADDME;
			}

		$self->{$path}->[2] = join(',',@PIDS);

#		use Data::Dumper;
#		print STDERR Dumper({insert=>$insertpos,ADDME=>$ADDME,orig=>$orig,result=>$self->{$path}->[2]} );
		}
	elsif (defined $options{'insert_product'}) {
		## used by webapi: adds a single product.
		$options{'insert_product'} = uc($options{'insert_product'});

		if (index(uc(','.$self->{$path}->[2].',') , uc(','.$options{'insert_product'}.','))>=0) {} 	# already exists
		else { $self->{$path}->[2] .= ','.$options{'insert_product'}; }
		
		$self->{'_SORT'}->{$path}++;
		}
	elsif (defined $options{'products'}) { 
		$self->{'_SORT'}->{$path}++;
		}

	if (defined $options{'delete_product'}) {
		## used by webapi: deletes a single product.
		$options{'delete_product'} = uc($options{'delete_product'});
		if (index(uc(','.$self->{$path}->[2].',') , uc(','.$options{'delete_product'}.','))>=0) {
			my $str = '';
			foreach my $pid (split(',',$self->{$path}->[2])) { 
				$pid = uc($pid);
				next if ($pid eq '');
				## skip over the one we're trying to delete
				next if ($pid eq $options{'delete_product'});
				# print STDERR "PID: $pid eq $options{'delete_product'}\n";
				$str .= $pid.',';
				}	
			if (length($str)>0) { chop($str); }
			$self->{$path}->[2] = $str;
			} 	
		}

	if (defined $self->{$path}->[4]) {
		if ((defined $self->{$path}->[4]->{'WS'}) && ($self->{$path}->[4]->{'WS'}>0)) {
			&ZOOVY::add_event($self->username(),'NAVCAT.CHANGED',PRT=>$self->prt(),SAFE=>$path);
			}
		}

	if (not defined $self->{$path}->[3]) {
		$self->{$path}->[3] = '';		## make sure that the sort column isn't null (it will stop inserts)
		}

#	&logTHIS( $self->{'_USERNAME'}, 'SET', $path,
#      pretty=>$self->{$path}->[0],
#      products=>$self->{$path}->[2],
#      sort=>$self->{$path}->[3],
#      meta=>&ZTOOLKIT::buildparams($self->{$path}->[4])
#		);

	return($self->{$path});
	}



#sub logTHIS {
#	my ($USERNAME,$VERB,$path,%options) = @_;
#
#	##
#	## VERBs are:
#	##		SET, NUKE
#	##
#
#	my %cmd = ();
#	$cmd{'USERNAME'} = $USERNAME;
#	$cmd{'MID'} = &ZOOVY::resolve_mid($USERNAME);
#	$cmd{'VERB'} = $VERB;
#	$cmd{'CREATED_GMT'} = $^T;
#	$cmd{'path'} = $path;
#
#	if (defined $options{'pretty'}) { 
#		$cmd{'pretty'} = $options{'pretty'};
#		}	
#	if (defined $options{'products'}) { 
#		$cmd{'products'} = $options{'products'};
#		}	
#	if (defined $options{'sort'}) { 
#		$cmd{'sort'} = $options{'sort'};
#		}	
#	if (defined $options{'meta'}) { 
#		$cmd{'meta'} = $options{'meta'};
#		}	
#
#	my ($dbh) = &DBINFO::db_zoovy_connect();
#	&DBINFO::insert($dbh,'NAVCAT_UPDATES',\%cmd,debug=>1);
#	&DBINFO::db_zoovy_close();
#
####	NOTE: FILES DON'T WORK!
##	my $userdir = &ZOOVY::resolve_userpath($USERNAME);
##	open F, ">>$userdir/navcat.log";
##	print F &ZTOOLKIT::buildparams(\%cmd)."\n";
##	close F;
##	chmod 0777, "$userdir/navcat.log";
##	chown $ZOOVY::EUID,$ZOOVY::EGID, "$userdir/navcat.log";	
#	}
#


##
## a list of all available categories + lists
##		note: if _ROOT is set then only categories above that path are visible.
##		
## parameters:
##		rootpath (optional - if undef, uses $self->{'_ROOT'})
## returns:
##		an ARRAY (not a ref)
##
## known issues:
##		if you pass $rootpath which is outside the current _ROOT it still returns categories.
##
sub paths {
	my ($self, $rootpath) = @_; 

	my @keys = ();
	if (not defined $rootpath) { $rootpath  = $self->{'_ROOT'}; }		# default to the current _ROOT path
	my $rootpathlen = length($rootpath);	# how long the root path is (should be 1)

	foreach my $p (keys %{$self}) {
		next if (substr($p,0,1) eq '_');	# internal keys shouldn't be nuked

		if ($rootpathlen>1) {
			## check to make sure we're looking at an available subcategory of the current category
			if (length($p) < $rootpathlen) { $p = undef; }		# a quicker check, since if $p is shorter, we can't show it!
			elsif (substr($p,0,$rootpathlen) ne $rootpath) { $p = undef; } 
			}
	
		next if (not defined $p);
		push @keys, $p;
		}	

	return(@keys);
	}


##
## validate the path (that all parents exist)
##
sub validate_path {
	my ($self, $path) = @_;

	my @pieces = split(/\./,$path);
	my $okay = 1;
	while (scalar(@pieces)>1) {
		my $safe = join(".",@pieces);
		print "SAFE: $safe\n";
		if (not $self->{$safe}) {
			$okay = 0;		## category does not exist;
			last;
			}
		pop @pieces; 
		} 

 	return($okay);
	}


##
## 
## %options
##	 	memory=>1
##
sub nuke_product {
	my ($self, $PID, %options) = @_;

	my $USERNAME = $self->{'_USERNAME'};
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	if (not defined $self) { return -1; }
	if ((not defined $PID) || ($PID eq '')) { return -1; }

	my $pdbh = undef;
	if ($options{'memory'}>0) {
		$pdbh = &DBINFO::db_user_connect($USERNAME);
		}

	my $count = 0;
	foreach my $safe (@{$self->paths_by_product($PID,lists=>1)}) {
		$self->set($safe,delete_product=>$PID);
		$count++;
		if ($options{'memory'}>0) {
			my $pstmt = &DBINFO::insert($pdbh,'NAVCAT_MEMORY',{
				USERNAME=>$USERNAME,MID=>$MID,
				CREATED_GMT=>$^T,
				PRT=>$self->prt(),
				PID=>$PID,
				SAFENAME=>$safe,
				},debug=>1+2);
			$pdbh->do($pstmt);
			}
		}
	
	if ($options{'memory'}>0) {
		&DBINFO::db_user_close();
		}

	return($count);
	}



##
## meta key would usually be $CONFIG{'navcatMETA'} which would be something like 'EGG' (the dst code of the marketplace)
##
#sub syndication_map {
#	my ($self, %options) = @_;
#
#	require NAVCAT::FEED;
#
#	my %PRODUCTS = ();
#	foreach my $safe ($self->paths()) {
#		my $bc = &NAVCAT::FEED::path_breadcrumb($self,$safe);
#
#		foreach my $pid (split(/,/,$self->{$safe}->[2])) {
#			next if ($pid eq '');
#			if (not defined $PRODUCTS{$pid}) {
#				$PRODUCTS{$pid} = [ $safe, $bc ];
#				}
#			elsif ( length($PRODUCTS{$pid}->[0]) < $safe ) {
#				$PRODUCTS{$pid} = [ $safe, $bc ];
#				}
#			}
#		}
#
#	return(\%PRODUCTS);
#	}


###
## returns a list of safe paths where the meta is set to val
##
sub paths_by_meta {
	my ($self,$meta,$val) = @_;

	my @RESULT = ();
	foreach my $safe ($self->paths()) {
		if ($self->{$safe}->[4]->{$meta} eq $val) { push @RESULT, $safe; }
		}
	return(@RESULT);
	}


###
## returns an arrayref of product categories (safenames)
##	
##	OPTIONS is a bitwise value
##		1 = only show categories (skip lists)
##
sub paths_by_product {
	my ($self, $PID, %options) = @_;

	my $lists = 1;
	my $root = undef;
	if ($options{'root'}) { $root = $options{'root'}; }
	if (defined $options{'lists'}) { $lists = int($options{'lists'}); }

	if ((not defined $PID) || ($PID eq '')) { return(undef); }

	if ((defined $options{'fast'}) && ($options{'fast'}>0)) {
		## fast reverse lookup -- create a one time REVERSE LOOKUP map (that can be used again and again)
		my $REF = $self->{'_REVERSE'};
		if (not defined $REF) {
			$REF = $self->{'_REVERSE'} = {}; 
			foreach my $safe ($self->paths()) {
				my ($pretty,$children,$products) = $self->get($safe);
				foreach my $PID (split(/,/,$products)) {
					next if ($PID eq '');
					if (not defined $REF->{uc($PID)}) { $REF->{uc($PID)} = []; }
					push @{$REF->{uc($PID)}}, $safe;
					}				
				}		
			}
		if (not defined $REF->{uc($PID)}) { $REF->{uc($PID)} = []; }
		return($REF->{uc($PID)});
		}
	else {
		## standard old fashioned interative lookup
		my @paths = ();
		my $needle = uc(",$PID,");
		foreach my $safe ($self->paths()) {
			next if (($root) && ($safe !~ /^$root/));
			next if ((not $lists) && (substr($safe,0,1) ne '.'));
	
			my ($pretty,$children,$products) = $self->get($safe);
			next if ((not defined $products) || ($products eq ''));	
	
			if (index(uc(','.$products.','), $needle)>=0) {
				push @paths, $safe;
				}
			}
		return(\@paths);
		}
	}


##
## goes through the election process and selects the category which would be used for syndication
##
sub meta_for_product {
	my ($self,$PID) = @_;

	my @paths = sort @{$self->paths_by_product($PID)};
	
	my $bestSafe = undef;
	my $metaref = {};

	if (scalar(@paths)>0) {
		$bestSafe = shift @paths;
		foreach my $safe (@paths) {
			if (length($bestSafe)<$safe) {
				## use the best one.
				$bestSafe = $safe;
				}
			}
		(my $pretty,my $children,my $products,my $sort,$metaref) = $self->get($bestSafe);
		}
	return($bestSafe,$metaref);
	}


##
## deletes a navcat by safename, or if undef is passed then removes all categories.
##
sub nuke {	
	my ($self, $path) = @_;
	
	if (not defined $path) { 
		foreach my $path ($self->paths()) {
			$self->nuke($path);
			}	
		return();
		}
	## no need to keep going if it doesn't already exist!
	elsif (not defined $self->{$path}) { 
		return(); 
		}
	else {
		&ZOOVY::add_event($self->username(),'NAVCAT.DELETED',
			'PRT'=>$self->prt(),
			'SAFE'=>$path,
			'PIDS'=>$self->{$path}->[2],
			);
		$self->{'_READONLY'} = 0;
		delete $self->{'_KEYS'};
		if (defined $self->{$path}) {
			delete $self->{$path};
			}
	
#		&logTHIS( $self->{'_USERNAME'}, 'NUKE', $path );
		}

	}

##
## resorts a specific navcat
##		
##
sub sort {
	my ($self, $path, $sortby) = @_;

	my @products = split (/\,/, $self->{$path}->[2]);
	my $USERNAME = $self->{'_USERNAME'};
	if (not defined $sortby) { 
		$sortby = $self->{$path}->[3]; 
		}
	
	if (($sortby eq '') || ($sortby eq 'NONE')) { 
		return($self->{$path}->[2]); 
		}

#	print STDERR "SORTBY: $sortby\n"; 
#	use Data::Dumper; 

	## Redefine the products array properly sorted by the specified criteria

	if (($sortby eq 'NAME') || ($sortby eq 'NAME_DESC')) {
		my $names = {};
		my $prod = &ZOOVY::fetchproducts_into_hashref($USERNAME, \@products);
		foreach my $pid (@products) {
			$names->{$pid} = $prod->{$pid}->{'zoovy:prod_name'};
			}
		@products = &ZTOOLKIT::value_sort($names, 'alphabetically');
		# print STDERR "SORTED: ".Dumper(\@products,$names);
		}
	elsif (($sortby eq 'PRICE') || ($sortby eq 'PRICE_DESC')) {
		my $prices = {};
		my $prod   = &ZOOVY::fetchproducts_into_hashref($USERNAME, \@products);
		foreach my $pid (@products) {
			$prices->{$pid} = $prod->{$pid}->{'zoovy:base_price'};
			}
		@products = &ZTOOLKIT::value_sort($prices, 'numerically');
		}
	elsif (($sortby eq 'SKU') || ($sortby eq 'SKU_DESC')) {
		@products = sort @products;
		}
#	else{
#		die();
#		}
	if ($sortby =~ m/_DESC$/) { 
		@products = reverse @products; 
		}
	my $productstr = join(",",@products);
	
	return($productstr);
	}


##
## 
## returns a hashref of products which are safe to show on the web 
## (also returns a count of how many times each product appears)
##
##		$PRODUCT is optional - it returns only the data for a particular product.	
##		$ROOTPATH is optional as well, it is used to only return if a product is safe within a subtree.
##
## ISOLATION: 	0	- none: don't isolate, show all products in database that match.
##					5	- standard: show products on the current site, even in hidden categories
##					10 - max: crazy logic (see below)
##
sub okay_to_show {
	my ($self, $MERCHANT,$PRODUCT,$ROOTPATH,$ISOLATION) = @_;

	if (not defined $ISOLATION) { $ISOLATION = 10; }

	if ($ISOLATION==0) {
		warn("Do not call okay_to_show at isolation level 0 (it's not necessary)");
		return(undef);
		}

	my %prods = ();
	my $p;
	my ($pretty, $child, $products, $sortstyle);
	my $skip = 0;

	if (not defined $ROOTPATH) { $ROOTPATH = ''; }
	if (substr($ROOTPATH,0,1) ne '.') { $ROOTPATH = '.'.$ROOTPATH; }	# make sure we have the leading .
	my $pos = length($ROOTPATH); 		# $pos is the starting position of the ROOTPATH in the safename.
	if ($pos==1) { $pos = 0; }	# this makes the real root at like a sub root (see logic below)


	# print STDERR "ROOTPATCH : $ROOTPATH\n";
	foreach my $safe ($self->paths()) {
		next if (not defined $safe);				# how the fuck would this happen?

		next if (($pos) && (substr($safe,0,$pos) ne $ROOTPATH));		# skip any directories which aren't the ROOTPATH or a child of ROOTPATH.
	
		$skip = 0;
		($pretty, $child, $products) = $self->get($safe);

		if ($ISOLATION<=5) {}	## isolation level 5 doesn't concern itself with labels like hidden, etc.
		elsif ($ROOTPATH eq $safe) {}	#  this safename IS OUR ROOT category, so its implicitly included.
		elsif (substr($pretty, 0, 1) eq '!') { $skip++; }   # apparently we're hidden, stop now.
		# elsif ($ISOLATION<=7) {}	## isolation level 7 respects hidden 
		else {  # we're looking at a valid subcategory, and we're NOT on the root category.
			my @ar = split(/\./,substr($safe,$pos));		# so if we're in root .a then we'll get split .b.c 
			## remember: $ar[0] is a blank since we split on .b.c or just .

			# SANITY: $ar[0] is a root level category level category we're in (NOTE: this would be $ar[1] but we dropped the leading /./)
			my $myroot = (($pos)?$ROOTPATH.'.':'.').$ar[1];
			my ($pretty) = $self->get($myroot);
			if (not defined $pretty) {}
			elsif (substr($pretty,0,1) eq '!') { $skip++; } # if root subcategory we're in is hidden, stop now.
			elsif (scalar(@ar)<=2) {}	# hmm.. this is just b.c and we already checked b above! (no sense checking again)
			else {
				pop @ar;	# remove the last category
				my $myparent = (($pos)?$ROOTPATH.'.':'.').join('.',@ar);		# clearly we're in b.c.d.e and we've already checked b, what about d?
				my ($pretty) = $self->get($myparent);
				if (not defined $pretty) {}
				elsif (substr($pretty,0,1) eq '!') { $skip++; }	# if our immediate parent is hidden stop now.
				## NOTE: for obvious reasons (can you imagine what the code would look like) we're only looking in the 
				##			root subcategory, and our immediate parent. To use an ethnic example: 
				##			my parents were scottish, i'm scottish. 
				##			if i trace back to my earliest known ancestor (beside the monkey,.. err.. root category)
				##			then i can also say "i'm scottish" .. but if anybody along the way just happend to be scottish
				##			i'm not scottish. in this case if I was scottish, i'd also be hidden.
				}
			}
		next if ($skip);

		if (defined $PRODUCT) {
			## speed - we have a product filter.
			foreach my $safe (split (/,/, $products)) {
				next if ($safe eq '');
				next if ((defined $PRODUCT) && ($PRODUCT ne $safe));
				$safe = uc($safe);
#				print STDERR "SAFE: $safe\n";
				if (not defined $prods{$safe}) { $prods{$safe} = 0; }
				$prods{$safe}++;
				}
			}
		else {
			foreach my $safe (split (/,/, $products)) { 
				next if ($safe eq ''); 
				$prods{uc($safe)}++; 
				}
			}
		}
	return (\%prods);
	} 
## end sub safe_to_show


##############################################################################
##
## path_breadcrumb
##
## Purpose: Gets information needed to make a breadcrumb path for a category
## Accepts: A navcat path ".some.path.foo"
## Returns: An array ref (paths, in order), and hash ref (pretty names keyed
##          by path) of breadcrumbs to a specific path
##
sub breadcrumb {
	my ($self,$PATH, $STRIP_HIDDEN) = @_;

	my @pathparts = split (/\./, $PATH);
	shift @pathparts;    # There's nothing before the first dot

	## Old behavior is to strip hidden category markers (exclamation points) by default
	if (not defined $STRIP_HIDDEN) { $STRIP_HIDDEN = 1; }
	
	my $pathtmp = '';
	my $order   = ();
	my $names   = {};

	foreach my $pathpart (@pathparts) {
		$pathtmp = $pathtmp . '.' . $pathpart;
		my ($pretty) = $self->get($pathtmp);
		next if (not defined $pretty);

		if ($STRIP_HIDDEN>0) { 
			if (($STRIP_HIDDEN==2) && (substr($pretty,0,1) eq '!')) { 
				$pretty = ''; 
				}
			$pretty =~ s/^\!//gs; 			
			}
		next if ($pretty eq '');
		

		$names->{$pathtmp} = $pretty;
		push (@{$order}, $pathtmp);
		}

	return $order, $names;
	} 
## end sub path_breadcrumb


##############################################################################
##
## whatis_safename
##
## Purpose: Makes a safe name from a pretty name
## Accepts: A string, and whether the string should be interpreted as our old
##          format for encoding paths
## Returns: A navcat-path safe version of the string
##
sub safename {
	my ($PATH,%options) = @_;
	$PATH = lc($PATH);

	if (substr($PATH, 0, 1) eq '$') {
		## this is a list e.g. $asdf
		$PATH = substr($PATH,1);
		$PATH =~ s/[^a-z0-9\-]/_/g;
		$PATH = "\$$PATH";
		}
	elsif (substr($PATH, 0, 1) ne '*') {
		# take anything which isn't a a-z 0-9 or . to an underscore (for safety)	
		$PATH =~ s/[^a-z0-9\.\-\_]/\_/g;
		if (defined $options{'new'}) { $PATH =~ s/\.//gs; }
		}

	if ((defined $options{'new'}) && (substr($PATH,0,1) eq '_')) {
		# strip leading _ in case the customer did something silly like !blah
		$PATH = substr($PATH,1);
		}

	return $PATH;
	} ## end sub whatis_safename


##
## returns the parent of a particular category
##
sub parentOf {
	my ($self,$safe) = @_;

	if ($safe eq '.') { return('.'); }
	elsif (substr($safe,0,1) eq '$') { return('.'); }
	elsif (substr($safe,0,1) eq '0') { return('.'); }
	elsif (rindex($safe,'.')<=0) { return('.'); }
	else {
		$safe = substr($safe,0,rindex($safe,'.'));
		}
	return($safe);
	}


##
## returns only leaf nodes
## 	leaf categories are the right most categories, any category which has sub categories is a branch (non-leaf) category
##
sub fetch_leafnodes {
	my ($self, $ROOTPATH) = @_;

	# Default to the root category (just a dot)
	if ((not defined $ROOTPATH) || ($ROOTPATH eq '') || ($ROOTPATH eq '.')) { $ROOTPATH = $self->rootpath; }
	# Special categories have no subcategories so return nothing

	if (substr($ROOTPATH, 0, 1) eq '*') { return ([], {}); }
	if ($ROOTPATH ne '.') { $ROOTPATH .= '.'; }    # Add a dot to the end of any non-root path for easy matching later

	## step1: fetch children into $results
	my %results = ();
	my $len = length($ROOTPATH);
	foreach my $path ($self->paths()){
		next if ($path eq $ROOTPATH);						# always skip the current ROOT
		next if (substr($path,0,$len) ne $ROOTPATH);	# make sure this path matches the root
		$results{$path}++;
		}
	
	## step2: remove all but leaf categories, by deleting inward.
	foreach my $path (keys %results) {
		my @nodes = split(/\./,$path);
		# use Data::Dumper; print Dumper($path,@nodes); die();
		while (scalar(@nodes)) {
			pop @nodes;	# iteratively remove the .3 from .1.2.3
			# print "DELETING: ".join('.',@nodes)."\n";
			delete $results{ join('.',@nodes) };
			}
		}

	## step3: all that should be left are leaf nodes.	
	my @leafs = sort keys %results;
	return(\@leafs);
	}

##############################################################################
##
## fetch_childnodes (previously fetch_children)
##
## Purpose: Finds all the child paths of a navcat
## Accepts: A username and a navcat path
## Returns: Returns an arrayref of the subcategory paths in sorted order
##
sub fetch_childnodes {
	my ($self, $ROOTPATH) = @_;

	# Default to the root category (just a dot)
	if ((not defined $ROOTPATH) || ($ROOTPATH eq '') || ($ROOTPATH eq '.')) { $ROOTPATH = $self->rootpath; }
	# Special categories have no subcategories so return nothing

	if (substr($ROOTPATH, 0, 1) eq '*') { return ([], {}); }
	if ($ROOTPATH ne '.') { $ROOTPATH .= '.'; }    # Add a dot to the end of any non-root path for easy matching later
	
	my $results = {};
	my $len = length($ROOTPATH);
	foreach my $path ($self->paths()){
		next if ($path eq $ROOTPATH);						# always skip the current ROOT
		next if (substr($path,0,$len) ne $ROOTPATH);	# make sure this path matches the root
		next if (index(substr($path,$len+1),'.')>=0); # make sure there are no other dots . (since we only want children)
		$results->{$path}++;
		}

	return [sort keys %{$results}];
} ## end sub fetch_children

##############################################################################
##
## fetch_children_names
##
## Purpose: Finds all the child paths of a navcat
## Accepts: A username and a navcat path
## Returns: Returns an arrayref of the subcategory paths in sorted order, and
##          and a hashref keyed on path with a value of the pretty name.
##	         Skips any invisible categories.  
##
sub build_turbomenu {
	my ($self, $SAFEPATH, $INIREF, $CATLIST) = @_;

	my $order = [];    # Arrayref of sort order
	my $names = {};    # Hashref keyed on path, values of the path's pretty name
	my $metaref = {};

	my ($catsort_ar, $catinfo_hash) = ();

	if (defined $SAFEPATH) {
		($catsort_ar) = $self->fetch_childnodes($SAFEPATH);
		}
	elsif (defined $CATLIST) {
		$catsort_ar = $CATLIST;
		}
	return unless (defined($catsort_ar));

	my ($pretty,$meta);
	my $DEPTH = 0;
	if (defined $INIREF) {
		## iniref indicates we are probably being called from a FLOW element
		$DEPTH = $INIREF->{'DEPTH'};
		if (not defined $DEPTH) { $DEPTH = 0; }
		if (not defined $INIREF->{'DELIMITER'}) { $INIREF->{'DELIMITER'} = ' / '; }	# note, we don't check this later, so we've got to set it here!
		}

	foreach my $thiscat (@{$catsort_ar}) {
		my ($pretty,undef,undef,undef,$metaref) = $self->get($thiscat);
		my $skip = 0;

		if ((not defined $pretty) || ($pretty eq '')) { $skip++; }
		elsif (substr($pretty, 0, 1) eq '!') { $skip++; }

		if ((not defined $metaref) || (ref($metaref) ne 'HASH')) { $metaref = {}; }
	
		if ((not $skip) && ($DEPTH>0)) {
			## changes pretty from "Category C" to "Category A / Category B / Category C"
			my $i = $DEPTH;	# how many nodes should we move towards the root (e.g. cat a -> cat b -> cat c) c =0,b=1,a=2
			my $chopcat = $thiscat;
			while (( $i-- > 0 ) && (not $skip)) {
				$chopcat = substr($chopcat,0,rindex($chopcat,'.'));
				next if ($chopcat eq '.' || $chopcat eq '');
				my ($thispretty, undef, undef, undef, $meta , undef) = $self->get($chopcat);
				if (substr($thispretty,0,1) eq '!') { $skip++; }
				$pretty = $thispretty.$INIREF->{'DELIMITER'}.$pretty;
				}
			}
		
		if (not $skip) {
			push @{$order}, $thiscat;
			$names->{$thiscat} = $pretty;
			$metaref->{$thiscat} = $meta;
			}
		}

	return $order, $names, $metaref, $SAFEPATH;
	} ## end build_turbomenu


1;
