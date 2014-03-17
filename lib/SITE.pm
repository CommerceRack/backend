package SITE;

use strict;

################################################################
## REQUIREMENTS

use encoding 'utf8';
use Data::Dumper;
use Storable;
use lib '/backend/lib';
require ZOOVY;
require ZTOOLKIT;
require ZWEBSITE;
require NAVCAT;
require SITE::URLS;
#require SITE::MSGS;
require PAGE;
require DOMAIN;
require DOMAIN::QUERY;
require DOMAIN::TOOLS;

## $SITE::DEBUG++;
$SITE::GLOBAL_MEMCACHE_ID = '.';



%SITE::VARS = (
	'_NS'=>'NS',		# profile in focus
	'DOMAIN'=>'DOMAIN',	# the domain we are editing (not sure if www.domain or not?)
	'+prt' =>'PRT',	# partition in focus (starts at 0)
	'_FS'	=> 'FS',	# page flow style (only valid on vstore)
	# '_FL' => 'FL',	# page flow id? or maybe type -- not sure
	'_DOCID'=>'DOCID',	## behavior unclear. not sure if this is the wrapper, or..
	'_SKU'=>'SKU',		## current SKU in focus
	'_PID'=>'PID',		## just the product id of the sku in focus
	'_is_preview'=>'_is_preview',	# are we just previewing.  iniref->{PREVIEW} = 1
	'_DIV'=>'DIV',
	'_PG'=>'PG',
	'_FORMAT'=>'FORMAT',
	'_PROJECTID'=>'PROJECTID',
	);


## +sdomain
## +cdomain?
#	if (defined $options{'DOMAIN'}) {
#		$SREF->{'+sdomain'} = $options{'DOMAIN'};
#		$SREF->{'+server'} = $options{'DOMAIN'};
#		require DOMAIN::TOOLS;
#		(undef, $SREF->{'+ssl_ipaddr'}) = 
#			&DOMAIN::TOOLS::fast_resolve_domain_to_user($SREF->{'+sdomain'});				
#
#		# print STDERR "IP ADDR: [".$SREF->{'+ssl_ipaddr'}."] [$SREF->{'+sdomain'}]\n";
#		}


##
##  this is the only allowed way to access ip address
##	 
sub ip_address { my ($r) = @_; return($ENV{'REMOTE_ADDR'}); }


##
## used by sitebuilder
##
sub siteserialize {
	my ($self) = @_;	
	my %clone = ();
	foreach my $k (keys %SITE::VARS) {
		next if (not defined $self->{$k});
		print STDERR "SERILIZE: $k = $self->{$k}\n";
		$clone{ $SITE::VARS{$k} } = $self->{$k};
		}
	my $str = &ZTOOLKIT::fast_serialize(\%clone);
	return($str);
	}

##
##
##
sub sitedeserialize {
	my ($USERNAME,$str) = @_;
	my $ref = &ZTOOLKIT::fast_deserialize($str);
	my $self = SITE->new($USERNAME,%{$ref});	
	return($self);
	}


sub our_cookie_id { return(lc(sprintf("%s-cart",$_[0]->username()))); }

##
## TIE HASH FUNCTIONS
##
##
#sub TIEHASH {
#	my ($class, $me, %options) = @_;
#	my $this = {};
#	$this->{'_tied'}++;
#	return($this);
#	}
#
#sub UNTIE {
#	my ($this) = @_;
#	$this->{'_tied'}--;
#	}
#
#sub FETCH { 
#	my ($this,$key) = @_; 	
#	my $val = undef;
#	return($val);
#	}
#
#sub EXISTS { 
#	my ($this,$key) = @_; 
#	return( return($this->FETCH($key)?1:0) ); 
#	}
#
#sub DELETE { 
#	my ($this,$key) = @_; 
#	die();
#	return(0);
#	}
#
#sub STORE { 
#	my ($this,$key,$value) = @_; 
#	die();
#	return(0); 
#	}
#
#sub CLEAR { 
#	my ($this) = @_; 
#	die();
#	return(0);
#	}

##
## accepts a stid, pid, etc. sets the focus to it.
##
sub setSTID {
	my ($self,$stid) = @_;

	$SITE::DEBUG && print STDERR  "setSTID->($stid) ".join("|",caller(0))."\n"; 

	$self->{'_PID'} = '';
	$self->{'_STID'} = '';
	$self->{'_SKU'} = '';
	delete $self->{'_CLAIM'};

	if ($stid ne '') {
		$stid = uc($stid);
		my ($PID,$CLAIM,$INVOPTS,$NONINV) = &PRODUCT::stid_to_pid($stid);
		$self->{'_STID'} = $stid;
		$self->{'_PID'} = $PID;
		$self->{'_SKU'} = $PID . (($INVOPTS ne '')?"$INVOPTS":"");
		if ($CLAIM>0) { $self->{'_CLAIM'} = $CLAIM; }
		}
	return($stid);
	}
sub claim { return($_[0]->{'_CLAIM'}); }
sub stid { return($_[0]->{'_STID'}); }
sub sku { return($_[0]->{'_SKU'}); }		## DOCID should be set whenever fs() eq '!'
sub pid { return($_[0]->{'_PID'}); }		## DOCID should be set whenever fs() eq '!'

## 
sub title {
	if (defined $_[1]) { $_[0]->{'+title'} = $_[1]; }
	return($_[0]->{'+title'});
	}

## note: continue_url willoften be 'origin' (return them from where they came)
sub continue_shopping_url {
	if (defined $_[1]) { $_[0]->{'+continue_url'} = $_[1]; }
	if (not defined $_[0]->{'+continue_shopping_url'}) { $_[0]->{'+continue_shopping_url'} = ''; }
	return($_[0]->{'+continue_shopping_url'});
	}

##
sub cache_ts { 
	if (not defined $_[0]->{'+cache'}) {
		$_[0]->{'+cache'} = &ZOOVY::touched($_[0]->username(),0);	
		if ($_[0]->client_is() =~ /^(BOT|SCAN|KILL)$/) { $_[0]->{'+cache'} = 666; }			## bots can't request no-cache
		elsif ($ENV{'HTTP_PRAGMA'} eq 'no-cache') {  $_[0]->{'+cache'} = (time()+86400); }
		}
	return($_[0]->{'+cache'}); 
	}



sub list_profile {
	my ($self,$id) = @_;
	if (defined $id) {
		}
	}

sub list_nsref {
	my ($self) = @_;
	}






sub pAGE {
	my ($self,$PATH) = @_;

	if (not defined $PATH) { $PATH = $self->pageid(); }
	if (not defined $self->{'%PAGES'}) { $self->{'%PAGES'} = {}; }

	my $P = undef;
	if (defined $self->{'%PAGES'}->{$PATH}) {	
		$P = $self->{'%PAGES'}->{$PATH};
		}
	elsif ($self->pid() ne '') {	
		my ($PROD) = PRODUCT->new($self->username(),$self->pid());
		my %PRODREF = %{$PROD->prodref()};
		($P) = $self->{'%PAGES'}->{$PATH} = PAGE->new($self->username(),$PATH,'DATAREF'=>\%PRODREF);
		}
	else {
		$P = $self->{'%PAGES'}->{$PATH} = PAGE->new($self->username(),$PATH,'DOMAIN'=>$self->domain_only(),'PRT'=>$self->prt());
		}
	$SITE::DEBUG && print STDERR  "PAGE->($PATH) ".join("|",caller(0))."\n"; 

	return($P);
	}


##
## 
##
sub new {
	my ($CLASS, $USERNAME, %params) = @_;

	delete $ENV{'SITE_DESIGNATION'};
	## FUTURE: SKU

	$SITE::DEBUG && print STDERR  "new->".join("|",caller(0))."\n";
	if ($USERNAME eq '') {}	## this is unknown (and valid)

	my %this = ();
	$this{'_USERNAME'} = $this{'USERNAME'} = $USERNAME;

	my $self = \%this;
	bless $self, 'SITE';

	if ($params{'%DNSINFO'}) {
		my $DNSINFO = $params{'%DNSINFO'};
		$params{'PROJECTID'} = $DNSINFO->{'PROJECT'};
		$params{'HOST'} = $DNSINFO->{'HOST'};
		$params{'DOMAIN'} = $DNSINFO->{'DOMAIN'};
		$params{'PRT'} = $DNSINFO->{'PRT'};
		$self->{'%DNSINFO'} = $DNSINFO;
		$self->insert_dnsinfo($DNSINFO);
		}

	foreach my $k (keys %params) {
		if (not defined $params{$k}) {
			warn "SITE->new($USERNAME == is ignoring '$k' because it is blank/null ".join("|",caller(0))."\n";
			}
		elsif ($k eq '%DNSINFO') {
			## IGNORE
			}
		elsif ($k eq 'IS_SITE') {
			$self->sset('_is_site',$params{'IS_SITE'});
			}
		elsif (($k eq 'NS') || ($k eq 'PROFILE')) {
			warn "SITE->new() with PROFILE IS NO LONGER SUPPORTED!\n";
			$self->sset('_NS',$params{$k});
			}
		elsif ($k eq 'DOMAIN') {
			$self->sset('DOMAIN',$params{$k});
			$self->sset('_DOMAIN_ONLY',$params{$k});
			}
		elsif ($k eq 'PRT') {
			$self->sset('+prt',$params{$k});
			}
		elsif ($k eq 'FS') {
			$self->sset('_FS',$params{$k});
			}
		elsif ($k eq 'PROJECTID') {
			$self->sset('_PROJECTID',$params{$k});
			}
		elsif ($k eq 'PG') {
			$self->sset('_PG',$params{$k});
			}
		#elsif ($k eq 'FL') {
		#	$self->sset('_FL',$params{$k});
		#	}
		elsif ($k eq 'DOCID') {
			$self->sset('_DOCID',$params{$k});
			}
		elsif ($k eq 'DIV') {
			$self->sset('_DIV',$params{$k});
			}
		elsif ($k eq 'FORMAT') {
			$self->sset('_FORMAT',$params{$k});
			}
		elsif ($k eq 'SKU') {
			$self->setSTID($params{$k});
			}
		elsif ($k eq '*CART2') {
			$self->sset('*CART2',$params{$k});
			}
		elsif ($k eq 'PID') {
			warn Carp::cluck("It's much better to pass SKU than PID\n");
			$self->setSTID($params{$k});
			}
#		elsif ($k eq '_is_app') {
#			## _is_app will typically be set to the clientid .. when called from JSONAPI
#			$self->sset('_is_app',$params{$k});
#			}
		elsif ($k eq '_is_preview') {
			$self->sset('_is_preview',$params{$k});
			}
		elsif ($k eq '*P') {
			if (not defined $self->{'%PRODUCTS'}) { $self->{'%PRODUCTS'} = {}; }
			my $PID = $params{'*P'}->pid(); 
			$self->{'%PRODUCTS'}->{$PID} = $params{'*P'};
			}
		elsif ($k eq '%EBAYNSREF') {
			## this is a kludge to keep ebay wizards working it's functionaly the same as setting
			## $SITE->{%NSREF} = ebay profile data
			## I intentionally used a different parameter so it'd be easier to track/locate
			$self->{'%NSREF'} = $params{$k};
			}
		else {
			warn "UNKNOWN PARAMETER '$k'=>'$params{$k}' PASSED TO SITE->new\n";
			}
		}

	return($self);
	}


#sub prtinfo {
#		my $PRTINFO = undef;
#		if ($SITE->prt()==0) {
#			## DEFAULT PARTITION
#			$PRTINFO = { name=>"Default Partition", p_checkout=>0, p_messages=>0, p_customer=>0 };
#			}
#		else {
#			my $globalref = $SITE->globalref();
#			if ((defined $globalref) && (ref($globalref) eq 'HASH') && (ref($globalref->{'@partitions'}) eq 'ARRAY')) {
#				$PRTINFO = $globalref->{'@partitions'}->[$prt];
#				}
#
#			if (not defined $PRTINFO) {
#				$PRTINFO = { name=>sprintf("Err %d",$SITE->prt()),p_checkout=>$prt, p_messages=>$prt, p_customer=>$prt };
#				}
#			}
#	}



##
## loads a product 
##
sub pRODUCT {
	my ($self, $PID) = @_;

	$SITE::DEBUG && print STDERR  "PRODUCT->($PID) ".join("|",caller(0))."\n";
	if (not defined $PID) { $PID = $self->pid(); }
	if (not defined $self->{'%PRODUCTS'}) { $self->{'%PRODUCTS'} = {}; }

	my $P = $self->{'%PRODUCTS'}->{$PID};
	if (not defined $P) {
		$P = $self->{'%PRODUCTS'}->{$PID} = PRODUCT->new($self->username(),$PID);
		}

	if (defined $P) {
		$SITE::DEBUG && print STDERR  "GOT PRODUCT->($PID) \$".$P->fetch('zoovy:prod_name')."\n";
		}

	return($P);
	}


##
##
sub gref { return(SITE::globalref(@_)); }
sub globalref {
	my ($self) = @_;

	$SITE::DEBUG && print STDERR  "globalref->".join("|",caller(0))."\n";
	if (not defined $self->{'%GREF'}) {
		$self->{'%GREF'} = &ZWEBSITE::fetch_globalref($self->username());
		}
	return($self->{'%GREF'});
	}




sub wrapper { return( $_[0]->nsref()->{'zoovy:site_wrapper'} ); }
sub div { return($_[0]->sget('_DIV')); }

## FS guide
## * for claim page
## ! for special page?
## 'P' for product
## 'Y' 
## DOCID should be set whenever fs() eq '!'
sub fs { return($_[0]->sget('_FS')); }


##
##
##
# sub layout { return($_[0]->sget('_FL')); }
sub layout {
	my ($self,$layout) = @_;
	$SITE::DEBUG && print STDERR  "layout->".join("|",caller(0))."\n";
	if (defined $layout) { $self->{'_DOCID'} = $layout; }
	
	if (not defined $self->{'_DOCID'}) {
		## not sure why this line needs to be here
		$self->{'_DOCID'} = $self->pAGE()->get('fl');
		}

	return($self->{'_DOCID'});
	}

## most of the time docid() and layout() are the same thing (EXCEPT DURING SITES)
sub docid { return($_[0]->sget('_DOCID')); }		## DOCID should be set whenever fs() eq '!'
sub format { return($_[0]->sget('_FORMAT')); }	## ?? wonky, this is WRAPPER, LAYOUT, EMAIL, etc. (should really be stored in the toxml)

sub pageid { 
	if (defined $_[1]) { 
		$_[0]->{'_PG'} = $_[1]; 
		my $path = $_[0]->{'@CWPATHS'}->[0]->[1];
		unshift @{$_[0]->{'@CWPATHS'}}, [ $_[0]->{'_PG'}, $path, '(pageid)'.join("|", caller(0)) ];
		}
	return($_[0]->{'_PG'}); 
	}		

#sub push_pg {
#	my ($self, $pg, $fs, $uri, $params) = @_;
#	}

sub mid { return(&ZOOVY::resolve_mid($_[0]->{'_USERNAME'})); }
sub username { 
	if (not defined $_[0]->{'_USERNAME'}) { Carp::croak("SITE->USERNAME is not defined"); }
	return($_[0]->{'_USERNAME'}); 
	}
sub cluster { return(&ZOOVY::resolve_cluster($_[0]->{'_USERNAME'})); }

#sub appversion { 
#	if ($_[1]) { $_[0]->{'_APPVERSION'} = $_[1]; }
#	return($_[0]->{'APPVERSION'});
#	}

sub projectid { 
	if ($_[1]) { $_[0]->{'_PROJECTID'} = $_[1]; }
	return($_[0]->{'_PROJECTID'});
	}

##
## returns true when we're in the user interface in a preview/template mode which may cause some
##	squirrely rendering issues (where we want to show %MACRO% instead of doing substitution for example)
##
sub _is_preview { return( $_[0]->{'_is_preview'} ) };
#sub _is_app { return($_[0]->{'_is_app'}) };

##
## returns true if we're on a website *AND* we have a reasonable expectation of having a 
##	$SITE::CART2, etc.
##
sub _is_site { return( $_[0]->{'_is_site'} ) };
sub _is_newsletter { return( $_[0]->{'_is_newsletter'} ) };

##
## structure of DNSINFO
##
## NOT SURE WHAT 'cdomain' is 
sub linkable_domain { 
	my ($self) = @_; 

	my $DOMAIN = undef ;
	if ($self->domain_only()) {
		my $HOST = $self->domain_host();	
		if ($HOST eq 'NONE') { $HOST = 'www'; }
		$DOMAIN = lc(sprintf("%s.%s",$HOST,$self->domain_only()));
		}
	elsif ($DOMAIN = $self->{'DOMAIN'}) {
		}
	elsif ($DOMAIN = $self->sdomain()) {
		warn "SITE->URLENGINE is using SDOMAIN (this can be somewhat un-reliable)\n";
		}
	elsif ( (defined $self->prt()) && ($DOMAIN = &DOMAIN::TOOLS::domain_for_prt($self->username(),$self->prt())) ) {
		warn "SITE->URLENGINE is using &DOMAIN::TOOLS::domain_for_prt";
		$DOMAIN = "www.$DOMAIN";
		}
	else {
		$DOMAIN = sprintf("__#NO-DOMAIN-%s.%d#__",$self->username(),$self->prt());
		}

	return($DOMAIN);
	}

sub dnsinfo_is_init { return(int($_[0]->{'_DNSINFO_INIT'})); }
sub dnsinfo { 
	my ($self, $DOMAIN) = @_; 
	$SITE::DEBUG && print STDERR  "dnsinfo->".join("|",caller(0))."\n";

	my $DNSINFO = undef;
	if (defined $self->{'%DNSINFO'}) {
		$DNSINFO = $self->{'%DNSINFO'};
		}

	if (not defined $DNSINFO) {
		if (not defined $DOMAIN) { $DOMAIN = $self->cdomain(); }
		$DNSINFO = $self->{'%DNSINFO'} = &DOMAIN::QUERY::lookup($DOMAIN); 
		}

	return($DNSINFO); 
	}

sub sdomain {  
	my ($self) = @_; 
	return(lc($self->{'+sdomain'}));  
	}
sub domain_host { my ($self) = @_; return($self->{'_DOMAIN_HOST'}); };
sub domain_only { my ($self) = @_; return($self->{'_DOMAIN_ONLY'}); };
sub cdomain { my ($self) = @_;  return(sprintf("%s.%s",$self->{'_DOMAIN_HOST'}, $self->{'_DOMAIN_ONLY'})); }
sub Domain {
	my ($self,%options) = @_;

	if (not defined $self->{'*DOMAIN'}) { 
		## print STDERR Carp::cluck();
		my $DOMAINNAME = $self->domain_only();
		my $USERNAME = $self->username();

		if ($DOMAINNAME eq '') {
			my $PRT = $self->prt();
			require DOMAIN::TOOLS;
			($DOMAINNAME) = &DOMAIN::TOOLS::domain_for_prt($USERNAME,$PRT,'guess'=>1);
			}

		print STDERR "Domain --> USER:$USERNAME DOMAIN:$DOMAINNAME\n";
		my ($D) = DOMAIN->new( $USERNAME, $DOMAINNAME );
		if ((not defined $D) && ($options{'guess'})) {
			## this is mostly for the old legacy broke ass email system that sets _DOMAIN_ONLY to www.domain.com
			my @PARTS = split(/\./,$DOMAINNAME);
			shift @PARTS;
			my $BROKE_ASS_DOMAINNAME = join(".",@PARTS);
			print STDERR "Domain() USING BROKE_ASS_DOMAIN: $BROKE_ASS_DOMAINNAME [[ FIX THIS ]]\n";
			($D) = DOMAIN->new( $USERNAME, $BROKE_ASS_DOMAINNAME );
			}

		$self->{'*DOMAIN'} = $D;
		}

	return( $self->{'*DOMAIN'} ); 
	}

##
##
##
sub secure_domain { 
	my ($self) = @_; 
	return($self->{'_DOMAIN_SECURE'}); 
	}

sub canonical_uri {
	my ($self) = @_;

	my ($pagetype,$path) = @{$self->servicepath()};
	my $CANONICAL_URI = '';

	# $SITE::DEBUG++;
	$SITE::DEBUG && print STDERR "CANONICAL URL SERVICEPATH '$pagetype' PATH '$path'\n";
	$SITE::DEBUG && print STDERR 'CWPATHS: '.Dumper($self->{'@CWPATHS'});

	if ($pagetype eq 'product') {
		if ($self->pRODUCT()) { 
			$CANONICAL_URI = $self->pRODUCT()->public_url(); 
			}
		else {
			$CANONICAL_URI = "/?#INVALID_PRODUCT";
			}
		}
	elsif ($path eq '.') {
		$CANONICAL_URI = '/';
		}
	elsif (($pagetype eq 'category') || (substr($path,0,1) eq '.')) {
		## it's really hard to recognize a category because pagetype gets (incorrectly) set to .safe.name
		## not worth fixing.
		$CANONICAL_URI = sprintf("/category/%s",substr($path,1));
		}
	elsif ($pagetype eq 'results') {
		#my $params = &ZTOOLKIT::buildparams({KEYWORDS=>$SITE::v->{'keywords'},CATALOG=>$SITE::v->{'catalog'}});
		}
	return($CANONICAL_URI);
	}

sub canonical_url { 
	my ($self) = @_;
	my $CANONICAL_URL = sprintf("http://%s%s",$self->cdomain(),$self->canonical_uri());

	# print STDERR "CANONICAL: $CANONICAL_URL\n";
	# $r->set_last_modified($modified_gmt);				
	return($CANONICAL_URL);
	}


## SITE::SREF->{'_ROOTCAT'}
sub rootcat {
	my ($self) = @_;
	if (defined $self->{'_ROOTCAT'}) {
		}
	elsif (not defined $self->nsref()) {
		$self->{'_ROOTCAT'} = '#PROFILE_NOT_CONFIGURED_INVALID_CONFIGURATION';
		}
	elsif (defined $self->nsref()->{'zoovy:site_rootcat'}) {
		$self->{'_ROOTCAT'} = $self->nsref()->{'zoovy:site_rootcat'};
		$self->{'_ROOTCAT'} =~ s/[\.]+/\./gs; 			# sanitize
		$self->{'_ROOTCAT'} =~ s/[^a-z0-9\.\_\-]+//gs;	# sanitize (this will eventually be part of a filename)
		if ($self->{'_ROOTCAT'} eq '') { $self->{'_ROOTCAT'} = '.'; }
		}
	else {
		$self->{'_ROOTCAT'} = '.';
		}
	$SITE::DEBUG && print STDERR "SITE->rootcat (response is '$self->{'_ROOTCAT'}')\n";
	return($self->{'_ROOTCAT'});
	}

##
## current working path? not sure..
## 	_CWPATH
##		SITE::PG
sub servicepath {
	my ($self, $page, $path) = @_;
	if (not defined $self->{'@CWPATHS'}) { $self->{'@CWPATHS'} = [ [$self->rootcat(),'homepage','init'] ]; }
	if ((defined $path) || ($page)) {
		unshift @{$self->{'@CWPATHS'}}, [ $page, $path, join("|",caller(0)) ];
		}

	return($self->{'@CWPATHS'}->[0]);
	}


sub server_name {
	my ($self) = @_;
	if (not defined $self->{'+server'}) { return(lc($ENV{'SERVER_NAME'})); }
	return($self->{'+server'});
	}


##
## populates DNSINFO for a SITE object 
##		used by both init_newsletters and init_from_apache and JSONAPI::configJS
## 
sub insert_dnsinfo {
	my ($self, $DNSINFO) = @_;

	$self->{'_DNSINFO_INIT'}++;
	$self->{'_DOMAIN_HOST'} = $DNSINFO->{'HOST'};
	$self->{'_DOMAIN_ONLY'} = $DNSINFO->{'DOMAIN'};
	$self->{'_USERNAME'} = $DNSINFO->{'USERNAME'};

	my $HOST = $DNSINFO->{'HOST'};
	if ($HOST eq 'SECURE') { $HOST = 'WWW';  }	## cheap hack for backward compat.

	#my $APPWWWM_CHKOUT_HOST = uc(sprintf("%s_CHKOUT_HOST",$HOST));
	if (defined $DNSINFO->{'%HOSTS'}->{$HOST}) {
		$self->{'_DOMAIN_SECURE'} = lc($DNSINFO->{'%HOSTS'}->{$HOST}->{'CHKOUT'});
		}
	## $self->{'_DOMAIN_SECURE'} = $DNSINFO->{ $APPWWWM_CHKOUT_HOST };
	if ($SITE::URLS::DISABLE_SSL_CERTS) { $self->{'_DOMAIN_SECURE'} = ''; }
	if ($self->{'_DOMAIN_SECURE'} eq '') {
		$self->{'_DOMAIN_SECURE'} = &ZWEBSITE::domain_to_checkout_domain(sprintf("%s.%s",$DNSINFO->{'HOST'},$DNSINFO->{'DOMAIN'}));
		}

	if (not defined $self->{'+sdomain'}) {
		$self->{'+sdomain'} = lc(sprintf("%s.%s",$DNSINFO->{'HOST'},$DNSINFO->{'DOMAIN'}));
		}

	$self->{'+prt'} = $DNSINFO->{'PRT'};
	$self->{'_NS'} = $DNSINFO->{'PROFILE'};
	$self->{'_MID'} = &ZOOVY::resolve_mid($DNSINFO->{'USERNAME'});

	return($self);
	}



sub client_is {
	if ($_[1]) { 
		$_[0]->{'+client_is'} = $ENV{'CLIENTIS'} = $ENV{'SITE_DESIGNATION'} = $_[1]; 
		print STDERR "SITE_DESIGNATION: $ENV{'SITE_DESIGNATION'}\n";
		}	
	return($_[0]->{'+client_is'});
	}



##
sub init_from_uwsgi {
	my ($CLASS, $req) = @_;
	}



## all _is_ return 1/0
sub _is_trusted_ip { return($_[0]->{'+is_trusted_ip'}); }	## only for nginx, this is considered secure
sub _is_secure {  return($_[0]->{'+secure'}); }  				## 'is this session considered secure'

## tells if the site object is non-usable (corrupt)
##	value should be in msgref format   ISE|+reason
sub _iz_broked { 
	if (defined $_[1]) { warn $_[0]->{'+broked+'} = $_[1]; }

	print STDERR "BROKED: $_[0]->{'+broked+'}\n";
	return($_[0]->{'+broked+'}); 
	}					


sub prt { 
	my ($self) = @_;

	if (defined $self->{'+prt'}) {
		}
	elsif (defined $self->{'DOMAIN'}) {
		my ($D) = $self->Domain();
		$self->{'+prt'} = $D->prt();
		}
	#elsif (defined $self->{'_NS'}) {
	#	$self->{'+prt'} = &ZOOVY::profile_to_prt($self->username(),$self->profile());		
	#	}

	return($self->sget('+prt')); 
	}



sub uri { 
	return($_[0]->sget('+uri')); 
	}	## the parsed uri (ex: /s=, /c= removed 

sub msgs {
	my ($self) = @_;

	# warn "MSGS: ".join("|",caller(0))."\n";	
	if (defined $self->{'*MSGS'}) {
		}
	else {
		require SITE::MSGS;
		$self->{'*MSGS'} = SITE::MSGS->new($self->username(), '*SITE'=>$self, '*CART2'=>$self->cart2());
		}
	return($self->{'*MSGS'});
	}


sub txspecl {
	my ($self) = @_;
	
	# print STDERR  "txspecl->".join("|",caller(0))."\n";
	if (defined $self->{'*TXSPECL'}) {
		}
	else {
		## DO NOT PASS *MSGS to TXSPECL (it gets it's messages from us)
		## print STDERR Carp::cluck("path to here")."\n";
		$self->{'*TXSPECL'} = TOXML::SPECL3->new($self->username(),$self);
		}
	return($self->{'*TXSPECL'});
	}

## returns a reference to the current cart, creates a memory cart if one doesn't exist
##	or if $create==0 then returns undef
sub cart2 {
	my ($self, $cart2, $create) = @_;
	
	$SITE::DEBUG && print STDERR  "cart2->".join("|",caller(0))."\n";
	if (defined $cart2) { 
		$cart2->set_site($self);
		return($self->{'*CART2'} = $cart2);
		}
	elsif (defined $self->{'*CART2'}) {
		return($self->{'*CART2'});
		}
	elsif ((defined $create) && ($create == 0)) {
		# Carp::cluck("cart2 called -- but no *CART2 populated for SITE object");
		return(undef);
		}
	else { 
		$self->{'*CART2'} = CART2->new_memory($self->username());
		$self->{'*CART2'}->set_site($self);
		return($self->{'*CART2'});
		}	

	die("never reached"); # never reached.
	# return($self->{'*CART2'});
	}

sub nsref { 
	my ($self,%options) = @_;
	$SITE::DEBUG && print STDERR  "nsref->".join("|",caller(0))."\n";
	if (defined $self->{'%NSREF'}) { 
		}
	#elsif ($self->profile()) {
	#	## $self->{'%NSREF'} = &ZOOVY::fetchmerchantns_ref($self->username(),$self->profile());
	#	}
	#else {
	#	warn Carp::cluck("%NSREF not populated in SITE");
	#	}
	else {
		my ($D) = $self->Domain('guess'=>1);
		if (defined $D) {	$self->{'%NSREF'} = $D->as_legacy_nsref(); } 
		}
	return($self->{'%NSREF'});
	}

sub webdb {
	my ($self) = @_;
	$SITE::DEBUG && print STDERR  "webdb->".join("|",caller(0))."\n";
	if (defined $self->{'%webdbref'}) {
		}
	elsif (defined $self->prt()) {
		$self->{'%webdbref'} = &ZWEBSITE::fetch_website_dbref($self->username(),$self->prt(),$self->cache_ts());
		}
	else {
		warn Carp::cluck("%webdbref not populated in SITE (prt not set)");
		}
	return($self->{'%webdbref'});
	}

sub webdbref { my ($self) = shift @_; $self->webdb(@_); }


sub URLENGINE {
	my ($self) = @_;


	# $SITE::DEBUG && print STDERR  "URLENGINE->".join("|",caller(0))."\n";
	if (defined $self->{'*URLS'}) {
		}
	else {
		# my $has_cookies = undef;
		#if (defined $SITE::c) { $has_cookies = ((defined $SITE::c->{$self->our_cookie_id()})?1:0) };

		$self->{'*URLS'} = SITE::URLS->new(
			$self->username(),
			'prt'=>$self->prt(),
			'*SITE'=>$self,
			'secure'=>$self->_is_secure(),
			'cookies'=>1, 
			);
		}
	return($self->{'*URLS'});
	}


sub sset { my ($self, $key, $value) = @_; $self->{$key} = $value; }
sub sget { my ($self, $key) = @_; return($self->{$key}); }




##
## PAGES is a list of valid page handlers,
##    the value is a bitwise, which means the following:
##       1 = requires authentication
##       2 = requires ssl.
##			4 = do NOT do HEAD requests.
##			8 = allow caching.
##		  16 = open db connection to products
##		  32 = open db connection to zoovy.
##		  64 = include in sitemap	
##		  128 = rewrite all urls to cookies.
##		  256 = uses a popup wrapper (if available)
##
##	pages we've cached: category, homepage, about_zoovy, product, privacy, search, popup
##
sub site_pages {
	my %PAGES = (
		'app'=>8+16, 'amazon'=>16, 'debug'=>0,
		'category'=>4+16,	'homepage'=>4+16,
		#'cancel_order'=>1,	'add_to_site'=>1,	'login'=>2+64,
		#'order_status'=>1+2+128,	'fastorder'=>1,	
		#'customer_main'=>1,
		'about_zoovy'=>4+64,		'checkout'=>2,
		'confirm'=>0,
		# 'rewards'=>0,		'mail_config'=>1, 'cust_address'=>1,		
		'product'=>4,		'cart'=>16,			'privacy'=>0,	
		'about_us'=>0+64,			'claim'=>16,		
		#'update_payment'=>1+2+128,
		# 'claim_multi'=>16,	'counter'=>0,		
		#'mail_form'=>0,
		#'unsubscribe'=>0,		'remove'=>0,		
		'results'=>16,
		'subscribe'=>0,
		#'no_cookies'=>0,	
		'disabled'=>0,
		'closed'=>0,
		'redir'=>0,	'paypal'=>16,
		'_googlecheckout'=>0, '_support'=>1+2+4,
		#'forgot'=>0,			
		'return'=>4+64,		'returns'=>0+64,
		'privacy'=>4,		'search'=>4+16,	
		# 'logout'=>0,
		'contact'=>0+64,		
		#'password'=>1+2, 	
		'popup'=>16+256,
		#'wishlist'=>1,			'rma'=>0,		'review'=>0,		'rewards'=>1+2,
		'_powerreviews'=>8,	'missing404'=>0,
		# 'callcenter'=>2,
		);
	return (%PAGES);
	}





#######################################################
##
##	see /httpd/static/banned.pl for more info about how this works.
##
$SITE::BANNEDMAP = undef;
sub whatis {
	my ($IP,$USERAGENT,$SERVERNAME,$URI) = @_;

	$USERAGENT = lc($USERAGENT);

	if (defined $SITE::BANNEDMAP) {
		## never cache banned maps longer than 60 seconds
		if (time()-$SITE::BANNEDMAP->{'_age'} > 120) {
			$SITE::BANNEDMAP = undef;
			}
		}

	if (not defined $SITE::BANNEDMAP) {
		print STDERR "LOADED BANNED MAP PID:$$ IP:$IP\n";
		$SITE::BANNEDMAP = Storable::retrieve "/httpd/static/banned.bin";
		$SITE::BANNEDMAP->{'_age'} = time();
		}
	my $map = $SITE::BANNEDMAP;

	my $DONE = 0;
	my ($TYPE,$reason) = (undef,undef); 

	## first match by IP
	my ($oct1,$oct2,$oct3,$oct4) = split(/\./,$IP);
	# print "oc1:$oct1,oc2:$oct2,oc3:$oct3,oc4:$oct4\n";

	if (defined $TYPE) {
		}
	elsif (defined $map->{'%IP'}->{$oct1}) {
		if (not defined $map->{'%IP'}->{$oct1}->{$oct2}->{$oct3}) {
			}
		elsif (defined $map->{'%IP'}->{$oct1}->{$oct2}->{$oct3}->{$oct4}) {
			($TYPE,$reason) = ($map->{'%IP'}->{$oct1}->{$oct2}->{$oct3}->{$oct4},"IP:$oct1.$oct2.$oct3.$oct4");	
			}
		elsif (defined $map->{'%IP'}->{$oct1}->{$oct2}->{$oct3}->{'*'}) {
			($TYPE,$reason) = ($map->{'%IP'}->{$oct1}->{$oct2}->{$oct3}->{'*'},"IP:$oct1.$oct2.$oct3.*");
			}

		if (not defined $TYPE) { $TYPE = ''; }

		if ($TYPE eq '') {}
		elsif ($TYPE ne 'WATCH') {}
		else { $DONE |= 1; }
		}
	
	if ((not $DONE) && ($USERAGENT ne '')) {
		## positive robot detector
		## ***** REMEMBER: USERAGENT IS LOWERCASED EARLIER ******
		# Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)
		# Mozilla/5.0 (compatible; FatBot 2.0; http://www.thefind.com/crawler)	
		# Mozilla/5.0 (compatible; YandexBot/3.0; +http://yandex.com/bots)
		# Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)
		# Mozilla/5.0 (compatible; Baiduspider/2.0; +http://www.baidu.com/search/spider.html)
		if ($USERAGENT =~ m/\s+(googlebot|fatbot|yandexbot|facebookexternalhit|bingbot|baiduspider)/o) { ($TYPE,$reason) = ('BOT-POSITIVE',"positive match ($1)"); }
		# Mozilla/5.0 (compatible; MSIE 7.0; MSIE 6.0; ScanAlert; +http://www.scanalert.com/bot.jsp) Firefox/2.0.0.3
		# FreeWebMonitoring SiteChecker/0.2 (+http://www.freewebmonitoring.com/bot.html)
		elsif ($USERAGENT =~ m/(scanalert|freewebmonitoring)/o) { ($TYPE,$reason) = ('SCAN-POSITIVE',"positive match ($1)"); }
		# Sogou web spider/4.0(+http://www.sogou.com/docs/help/webmasters.htm#07)
		# Mozilla/5.0 (compatible; Ezooms/1.0; ezooms.bot@gmail.com)
		# DealOzBot/7.2 (+http://www.dealoz.com/bot.pl)
		# TwengaBot-2.0 (http://www.twenga.com/bot.html)	
		# ShopWiki/1.0 ( +http://www.shopwiki.com/wiki/Help:Bot)
		# AdsBot-Google (+http://www.google.com/adsbot.html)
		# rogerbot/1.0 (http://www.seomoz.org, rogerbot-crawler@seomoz.org)
		# msnbot/2.0b (+http://search.msn.com/msnbot.htm) www.allcosmeticswholesale.com  /category/acw.300lips.lipgloss/
		# Mozilla/5.0 (compatible; MJ12bot/v1.4.3; http://www.majestic12.co.uk/bot.php?+) 
		# AddThis.com robot tech.support@clearspring.com
		# ia_archiver (+http://www.alexa.com/site/help/webmasters; crawler@alexa.com)
		# intelium_bot
		# Mozilla/5.0 (compatible; Exabot/3.0; +http://www.exabot.com/go/robot)
		elsif ($USERAGENT =~ m/(sogou web spider|ezooms|dealozbot|twengabot|shopwiki|adsbot-google|rogerbot|msnbot|mj12bot|addthis\.com|ia_archiver|intelium_bot|exabot)/o) { ($TYPE,$reason) = ('BOT-POSITIVE',"+positive match ($1)"); }
		## generic robot detector
		elsif ($USERAGENT =~ m/(\w+|\b|\_|\.)+bot\b/o) { ($TYPE,$reason) = ('BOT',"REGEX:+bot $1"); }
		elsif ($USERAGENT =~ m/robo\w+/o) { ($TYPE,$reason) = ('BOT',"REFEX:+robo $1"); }
		## no logging for BOT-POSITIVE

		if ($TYPE eq '') {}
		elsif ($TYPE ne 'WATCH') {}
		else { $DONE |= 2; }
		}

	if ((not $DONE) && ($USERAGENT ne '')) { 
		## specific robot whitelist
		foreach my $needleref (@{$map->{'@UA'}}) {
			next if (not $DONE);
			if (index($USERAGENT, $needleref->[0]) != -1) { 
				($TYPE,$reason) = ($needleref->[1],"UA:$USERAGENT"); 
				$DONE |= 4;
				}
			}
		}

	if ($TYPE eq '') {
		## this is a normal host (not known) so we should log it's velocity
		#if ($URI =~ /robots\.txt/) {
		#	my $WHEN = &ZTOOLKIT::pretty_date(time(),-2);
		#	open F, ">>/dev/shm/banned-more.txt";
		#	print F "BOT-TEST|IP:$IP|WHEN:$WHEN|SERVER:$SERVERNAME|REASON:robots.txt\n";
		#	print F "BOT-TEST|UA:$USERAGENT|WHEN:$WHEN|SERVER:$SERVERNAME|REASON:robots.txt\n";
		#	close F;
		#	}
		}

	## set an environment variable called "REMOTE_IS" that we can lookup	
	#$ENV{'SITE_DESIGNATION'} = $TYPE;
	#$ENV{'SITE_DESIGNATION_REASON'} = $reason;

	if ($TYPE eq '__DATA__') { $TYPE = undef; }

	return($TYPE);
	}




# URL Names
# secure			 - Internal use...  points to root of merchant dir on ssl.zoovy.com
# nonsecure		 - Internal use...  points to root of non-ssl merchant.zoovy.com site
# publish			- Internal use...
# edit				- Internal use...
# preview			- Internal use...
# home				- For "Home" link (this can be the user's home page)
# homepage		  -  Alias for home
# homecategory	 - For links to the "Home" category (this is for links specifically to the category home, such as categories associated with a product)
# DEPRECATED (REMOVED): shop				- For "Continue Shopping" links
# continue		  -  Continue shopping link
# privacy			- For "Privacy Policy"
# returns			- For "Returns Policy"
# wrapper			- For wrapper graphics for the currently selected
# graphics		  - For common graphics (mainly used for pointing at blank.gif)
# navbutton		 - Root for Zoovy navigation buttons
# userbutton		- Root for user-created navigation buttons
# about			  - Company information page
# aboutus			-  Alias for about
# search			 - Search page
# logout			 - Where the user goes after a logout
# logout_function - Where the user goes to logout
# news				- Only available on some layouts.  Defaults to the about URL
# contact			- Form where the user can leave 
# feedback		  -  Alias for contact
# forgot			 - Forgotten password page
# cart				- Shopping cart page
# customer_main	- customer page
# adult			  - Adult verification page
# claim			  - Claim URL
# mail_form		 - Mail Form
# remove			 - Remove from mailing list
# results			- Search results
# subscribe		 - Subscribe to mailing list
# order_status	 - Order status
# cancel_order	 - Cancel order
# update_payment  - Update Payment
# login			  - Login
# checkout		  - Checkout
# no_cookies		- Shows a cookies not found error
# disabled		  - Shows a feature disabled error
# gallery			- Shows a channel gallery page
# kill_cookies	 - Should kill all browser cookies
# redir			  - Will redirect to a page



#sub canonize_domain {
#	my ($DOMAIN) = @_;
#
#	$DOMAIN =~ s/^(www|m|i|secure)\.(.*?)$/$2/gs;
#	return(lc("www.$DOMAIN"));
#	}



sub log_email {
	my ($USERNAME,$IPADDRESS) = @_;

	my $t = time();

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select sum(COUNT) from EMAIL_ABUSERS where MID=$MID /* $USERNAME */ and LASTATTEMPT_GMT>$t-86400 and IPADDRESS=".$udbh->quote($IPADDRESS);
	my ($count) = $udbh->selectrow_array($pstmt);
	if ((not defined $count) || ($count==0)) {
		## insert		
		&DBINFO::insert($udbh,'EMAIL_ABUSERS',{
			USERNAME=>$USERNAME, MID=>$MID,
			IPADDRESS=>$IPADDRESS,
			COUNT=>1,LASTATTEMPT_GMT=>time(),
			});
		}
	else {
		## update
		$pstmt = "update LOW_PRIORITY EMAIL_ABUSERS set LASTATTEMPT_GMT=$t,COUNT=COUNT+1 where MID=$MID /* $USERNAME */ and IPADDRESS=".$udbh->quote($IPADDRESS);
		$udbh->do($pstmt);
		}

	&DBINFO::db_user_close();
	return(++$count);
	}


##
## generates a cache id that uniquely identifies an element, suitable for memcache.
##
sub cache_id {
	my ($self,$el) = @_;
	## NOTE: CACHEID code is duplciated in the following locations:
	##		/backend/lib/SITE/Vstore.pm ~line 2382
	##		/backend/lib/TOXML/RENDER.pm ~line 705
	##		/backend/lib/TOXML/SPECL.pm ~line 1010
	##		533 = 512 + 16 + 4 + 1
	## bit 1 is id of element.
	my $cache_id = sprintf("%s|%s.%s",$el->{'ID'},$self->username(),$self->prt());
	## bit 2 is timestamp of site.
	if ($el->{'CACHEABLE'}&2) { $cache_id .= "|".$self->cache_ts(); }
	## bit 4 is page of the site.
	if ($el->{'CACHEABLE'}&4) { $cache_id .= sprintf("|%s/%s",$self->pageid(),$self->pid()); }
	## bit 8 is the cache zone.
	if ($el->{'CACHEABLE'}&8) { $cache_id .= "|($el->{'CACHEZONE'}"; }
	## bit 16 is the site domain
	if ($el->{'CACHEABLE'}&16) { $cache_id .= "|".$self->sdomain(); }
	# print STDERR "SDOMAIN: ".$self->sdomain()."\n";
	#open F, ">>/tmp/sdomain.debug"; print F Dumper($self); close F;

	## bit 256 - uri params (query string)
	if ($el->{'CACHEABLE'}&256) { $cache_id .= "|".$ENV{'QUERY_STRING'}; }
	## bit 512 - date time
	if ($el->{'CACHEABLE'}&512) { $cache_id .= "|".&ZTOOLKIT::pretty_date(time()); } # refresh once per day

	## bit 1024 - allow caching on secure pages
	if ($self->_is_secure()) {
		if ($el->{'CACHEABLE'}&1024) {} # yep, we're cool.
		else { return(undef); }			  # NO CACHING ON SECURE PAGES!
		}

	$cache_id =~ s/[\s]+/_/g;
	$cache_id .= $SITE::GLOBAL_MEMCACHE_ID;

	return($cache_id);
	}


##
## this is intended to strip/remove many of the dangerous characters from a user input string
##
sub untaint {
	my ($str) = @_;

	$str = &ZOOVY::incode($str);
	# McAfee recommended best practices to untaint/remove xss opportunities.
	#Remove < input and replace with &lt;
	#Remove > input and replace with &gt;
	#Remove ' input and replace with &apos;
	#Remove " input and replace with &#x22;
	#Remove ) input and replace with &#x29;
	#Remove ( input and replace with &#x28;
	if ($str =~ /[<>'"()]+/o) {
		$str =~ s/\&/\&amp;/gso;
		$str =~ s/\</\&lt;/gso;
		$str =~ s/\>/\&gt;/gso;
		$str =~ s/\'/&apos;/gso;
		$str =~ s/\"/&quot;/gso;
		## NOTE: we don't want to start screwing with () because they aren't escape characters.
		## and they *ARE* used in search strings. acceptable risk.
		}

	return($str);
	}


##
## adds a layer of caching on top of navcats
##
sub get_navcats {
	my ($SREF) = @_;

	my ($NC) = undef;
	if (defined $SREF->{'*NC'}) {
		$NC = $SREF->{'*NC'};
		}
	else {
		my $CACHE_TS = $SREF->cache_ts();
		print STDERR "CACHE: $CACHE_TS (".$SREF->username().")\n";
		($NC) = NAVCAT->new($SREF->username(),'cache'=>$CACHE_TS,'PRT'=>$SREF->prt());
		$SREF->{'*NC'} = $NC;
		}

	return($NC);
	}


sub init_jsruntime {
	my (%options) = @_;

	if (defined $SITE::JSRUNTIME) { 
		$SITE::JSOUTPUT = '';
		return($SITE::JSCONTEXT); 
		}
	require JavaScript;
#	require Data::JavaScript::LiteObject;

	$SITE::JSOUTPUT = '';
	$SITE::JSRUNTIME = JavaScript::Runtime->new(128000);
	$SITE::JSCONTEXT = $SITE::JSRUNTIME->create_context();
	my $context = $SITE::JSCONTEXT;
	$context->bind_function( name => 'write', func => sub { $SITE::JSOUTPUT .= $_[0]; } );
	
	return($context);
	}


##
## <ELEMENT TYPE="OUTPUT" OUTPUTSKIP="128" OUTPUTIF="
##		$zoovy:product:var_1;
##		">
##
## <ELEMENT TYPE="SCRIPT"><HTML><[CDATA[
##		has_freeship = ($product:zoovy:ship_cost1 == 0);
##		has_cheapship = ($product:zoovy:ship_cost1 < 1.00);
##		has_discship = ($product:zoovy:ship_cost1 > $product:zoovy:ship_cost2);
##		c = $product:zoovy:base_cost - $product:zoovy:prod_msrp;
##		write("c is: "+c);
##	]]></HTML></ELEMENT>
##
##	<ELEMENT TYPE="OUTPUT" OUTPUTIF="
##	a = 10;
##	b = 20;
##	c = a * b;
##	c;
## "></ELEMENT>
##
## <ELEMENT OUTPUTIF="has_discship;">Buy more than 1 to save on shipping!</ELEMENT>
##
#sub output_if {
#	my ($EVAL) = @_;
#
#	&ZOOVY::confess($SITE::merchant_id,"calling legacy output_if function\n$EVAL",justkidding=>1);
#	return(1);

#	my ($context) = &SITE::init_jsruntime();
#	my $rval = $context->eval($EVAL);
#
#	use Digest::MD5;
#	my $hex = Digest::MD5::md5_hex($EVAL);
#	open F, ">>/tmp/js";
#	print F "output_if\t$SITE::merchant_id\t$hex\t$EVAL\t$rval\n";
#	close F;
#
#	# print STDERR "RVAL: $rval\n";
#	# $rval = ($rval)?1:0;
#
#	## this should return a "true" to output, a "false" to not output.
#	return($rval);
#	}



##
## takes:
##		subsref a list of parameters to be subtituted
##		elref - an array of elements which need to be rendered.
##
sub run {
	my ($subsref,$elref,$toxml,$SREF) = @_;

	## toxml is NOT required for SITE::run because it's how some modules (poorly) detect recursion 
	# if (not defined $toxml) { print STDERR Carp::confess("toxml parameter is now required for SITE::run"); }
	if (ref($SREF) ne 'SITE') { warn Carp::cluck("SREF object is not a valid SITE object"); }
	if (not defined $SREF) { print STDERR Carp::confess("SREF parameter is now required for SITE::run"); }

	require TOXML::RENDER;
	# print STDERR Dumper($elref);

	my $OUTPUT = '';
	my $TYPE = '';
	foreach my $el (@{$elref}) {
		$TYPE = $el->{'TYPE'};
		next if ($TYPE eq '');

		if (defined($TOXML::RENDER::render_element{$TYPE})) {
			my $tagout = undef;

			# print STDERR YAML::Syck::Dump($el)."\n";

			#if ((defined $SITE::memd) && ($el->{'CACHEABLE'})) {
			#	print STDERR "!!!! loading from body memcache\n";
			#	($tagout) = $SITE::memd->get("$el->{'ID'}|$SITE::merchant_id|$SITE::PG");
			#	}

			if (not defined $tagout) {
				# print STDERR "trying $SITE::memd $SITE::merchant_id $el->{'ID'} $el->{'CACHEABLE'}\n";
				$tagout = $TOXML::RENDER::render_element{$TYPE}->($el,$toxml,$SREF);
				#if ((defined $SITE::memd) && ($el->{'CACHEABLE'})) {
				#	print STDERR "!!!! storing $el->{'ID'}|$SITE::merchant_id|BODY|$SITE::PG\n";
				#	$SITE::memd->set("$el->{'ID'}|$SITE::merchant_id|BODY|$SITE::PG",$tagout);
				#	}
				}

			if (defined $el->{'SUB'}) {
				## this is going to be used for substitution, so don't append the content.
				## just add it to SUBS for future use.
				$subsref->{'%'.$el->{'SUB'}.'%'} = $tagout;
				}
			else {
				## we *probably* need to do the interoplation.
				if (index($tagout,'%')>=0) {
					## short circuit: interpolation *MIGHT* be necessary, since there are %'s
					foreach my $k (keys %{$subsref}) {
						next unless (index($tagout,$k)>=0);
						$tagout =~ s/$k/$subsref->{$k}/gs;
						}
					}
				$OUTPUT .= $tagout;
				}
			undef $tagout;
			}
		else {
			$OUTPUT .= "<font color='red'>Element $TYPE not found</font><br>";
			}
		}

	return($OUTPUT);
	}


########################################
# HTTP HEADER


########################################
## BAD BOT

sub bad_bot {
	# print "Content-Type: text/html; charset=ISO-8859-1\n\n";
	print "Content-Type: text/html; charset=UTF-8\n\n";
	print "<html><head><title>Bad Robot</title></head><body>\n";
	print "<p>Searching / Spidering denied.  Web robots should pay attention to /robots.txt </p>\n";
	print "</body></html>\n";
	&expire();
	}

########################################
## HTTP COOKIES


sub generate_js_cookies_script { my ($self) = @_;  return($self->{'__JSCOOKIES__'});  }




########################################
## LOGIN HANDLING

## Returns the login if the user is logged in, or a blank string if they aren't
## remember: there are some un-authenticated functions (such as view order status)
sub request_login {
	return (&ZTOOLKIT::def($SITE::CART2->in_get('customer/login')));
	}



sub login_trackers {
	my ($self,$CART2) = @_;

	my $nsref = $self->nsref();
	my $OUTPUT = '';
	if ($nsref->{'plugin:loginjs'} ne '') {
		$OUTPUT .= "<!-- PLUGIN_LOGINJS -->\n".$nsref->{'plugin:loginjs'}."\n<!-- /PLUGIN_LOGINJS -->\n"; 
		}
	if ($nsref->{'fetchback:loginjs'} ne '') {
		$OUTPUT .= "<!-- FETCHBACK_LOGINJS -->\n".$nsref->{'fetchback:loginjs'}."\n<!-- /FETCHBACK_LOGINJS -->\n"; 
		}
	
	return($OUTPUT);
	}


##
## this outputs all the javascript which should be set on the final page.
##
sub conversion_trackers {
	my ($self, $CART2) = @_;
	
	my ($out) = $self->conversion_trackers_as_array($CART2);
	my $OUTPUT = "<!-- BEGIN TRACKERS -->\n";
	foreach my $element (@{$out}) {
		$OUTPUT .= $element->[1];
		}
	$OUTPUT .= "<!-- /END TRACKERS -->";

	return($OUTPUT);
	}

##
##
sub conversion_trackers_as_array {
	my ($self,$CART2) = @_;

	my @OUT = ();
	my $EXISTING_CART2 = undef;
	if (defined $CART2) {
		## temporarily swap out the global cart for this conversion trackers 
		$EXISTING_CART2 = $self->cart2(undef,0);
		$self->cart2($CART2);
		}

	#open F, ">/tmp/foo";
	#print F Dumper($EXISTING_CART2,$CART2);
	#close F;

	my $order_id = $CART2->in_get('our/orderid');

	my $nsref = $self->nsref();
	my $msgs = $self->msgs();

	# $OUTPUT .= "\n<!-- TRACKERS -->\n";

	if ($nsref->{'omniture:enable'}>0) {
		my $OUTPUT .= "\n<!-- begin omniture -->".$msgs->show($nsref->{'omniture:checkoutjs'})."<!-- end omniture -->";
		push @OUT, [ 'omniture', $OUTPUT ]; 
		}

	if ($nsref->{'analytics:roi'} ne 'GOOGLE') {
		## NOT GOOGLE ROI 
		}
	elsif ($nsref->{'analytics:headjs'} =~ /pagetracker/is) {
		$nsref->{'analytics:roi'} = 'GOOGLE-NONASYNC';
		}
	else {
		## NOTE: if you're changing this, you should also check ZPAY/GOOGLE.pm for the google checkout button that passes the coookie.
		$nsref->{'analytics:roi'} = 'GOOGLE-ASYNC';
		}


	my $SDOMAIN = $self->sdomain();
	if ($nsref->{'analytics:roi'} eq 'GOOGLE-ASYNC') {
#<script type="text/javascript">
#  var _gaq = _gaq || [];
#  _gaq.push(['_setAccount', 'UA-885015-3']);
#  _gaq.push(['_trackPageview']);
#  (function() {
#    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
#    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
#    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
#  })();
#</script>
		## http://code.google.com/apis/analytics/docs/tracking/gaTrackingEcommerce.html
		my $order_total = $CART2->in_get('sum/order_total');
		my $tax_total = $CART2->in_get('sum/tax_total');
		my $shipprice = $CART2->in_get('sum/shp_total');
		my $city = $CART2->in_get('bill/city');
		my $state = $CART2->in_get('bill/region');
		my $country = $CART2->in_get('bill/countrycode');

		my $ts = time();

		my $OUTPUT .= qq~
<!-- begin: google async analytics ecommerce -->
<script type="text/javascript">
_gaq.push(['_addTrans',
"$order_id", // order ID - required
"$SDOMAIN", // affiliation or store name
"$order_total", // total - required
"$tax_total", // tax
"$shipprice", // shipping
"$city", // city
"$state", // state or province
"$country" // country
]);
~;

			my ($stuff) = $CART2->stuff2();
			foreach my $item (@{$stuff->items()}) {
				my $prodname = &ZOOVY::incode($item->{'prod_name'});
					$OUTPUT .= qq~
_gaq.push(['_addItem',
"$order_id", // order ID - required
"$item->{'sku'}", // SKU/code
"$prodname", // product name
"", // category or variation
"$item->{'price'}", // unit price - required
"$item->{'qty'}" // quantity - required
]);
~;
					};
		$OUTPUT .= qq~
_gaq.push(['_trackTrans']); //submits transaction to the Analytics servers
</script>
<!-- end: google analytics ecommerce -->
~;
		
		push @OUT, [ 'google-analytics-async', $OUTPUT ];
		}


	if ($nsref->{'analytics:roi'} eq 'GOOGLE-NONASYNC') {
		## NON-ASYNC ROI CODE
		## GOOGLE ANALYTICS CODE
		#UTM:T|34535|Main Store|111108.06|8467.06|10.00|San Diego|CA|USA
		#UTM:I|34535|XF-1024|Urchin T-Shirt|Shirts|11399.00|9
		#UTM:I|34535|CU-3424|Urchin Drink Holder|Accessories|20.00|2
		#UTM:T|[order-id]|[affiliation]|[total]|[tax]| [shipping]|[city]|[state]|[country] 
		#UTM:I|[order-id]|[sku/code]|[productname]|[category]|[price]|[quantity] 
		my $order_total = $CART2->in_get('sum/order_total');
		my $tax_total = $CART2->in_get('sum/tax_total');
		my $shipprice = $CART2->in_get('sum/shp_total');
		my $city = $CART2->in_get('bill/city');
		my $state = $CART2->in_get('bill/region');
		my $country = $CART2->in_get('bill/countrycode');

		my $ts = time();

		my $OUTPUT .=  qq~
<!-- begin: google non-async analytics ecommerce -->
<script type="text/javascript">
pageTracker._addTrans(
"$order_id", // order ID - required
"$SDOMAIN", // affiliation or store name
"$order_total", // total - required
"$tax_total", // tax
"$shipprice", // shipping
"$city", // city
"$state", // state or province
"$country" // country
);
~;
			my ($stuff) = $CART2->stuff2();
			foreach my $item (@{$stuff->items()}) {
				my $prodname = &ZOOVY::incode($item->{'prod_name'});
					$OUTPUT .= qq~
pageTracker._addItem(
"$order_id", // order ID - required
"$item->{'sku'}", // SKU/code
"$prodname", // product name
"", // category or variation
"$item->{'price'}", // unit price - required
"$item->{'qty'}" // quantity - required
);
~;
					};
			$OUTPUT .= qq~
var JSEpochIs = new Date();
JSEpochIs = parseInt(JSEpochIs.valueOf() / 1000);
if (JSEpochIs < $ts+86400) {
	// if the customer saves the page, don't let them re-run the analytics code.
	pageTracker._trackTrans();
	}
</script>
<!-- end: google analytics ecommerce -->
~;

		push @OUT, [ 'google-analytics-legacy', $OUTPUT ]; 
		}



	if ($nsref->{'googlets:chkout_code'} ne '') {
		my $OUTPUT .=  "\n<!-- begin googlets -->".$msgs->show($nsref->{'googlets:chkout_code'})."<!-- end googlets -->";
		push @OUT, [ 'google-trustedstores', $OUTPUT ]; 
		}
	
	my $META = $CART2->in_get('cart/refer');
	if (not defined $META) { $META = ''; }

	if (($nsref->{'msnad:filter'}) && ($META !~ /MSN/i) ) {
		my $OUTPUT .=  "\n<!-- SKIPPED MSNAD DUE TO OUTPUT FILTER: $META -->";
		push @OUT, [ 'msnad', $OUTPUT ];
		}
	elsif ($nsref->{'msnad:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin msnad -->".$msgs->show($nsref->{'msnad:chkoutjs'})."<!-- end msnad -->";
		push @OUT, [ 'msnad', $OUTPUT ];
		}

	if (($nsref->{'shopcom:filter'}) && ($META !~ /DEALTIME/i)) {
		my $OUTPUT .=  "\n<!-- SKIPPED SHOPCOM DUE TO OUTPUT FILTER: $META -->";
		push @OUT, [ 'shopping.com', $OUTPUT ];
		}
	elsif ($nsref->{'shopcom:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin shopping.com -->".$msgs->show($nsref->{'shopcom:chkoutjs'})."<!-- end shopping.com -->";
		push @OUT, [ 'shopping.com', $OUTPUT ];
		}

	if ($nsref->{'googleaw:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin googleaw -->".$msgs->show($nsref->{'googleaw:chkoutjs'})."<!-- end googleaw -->";
		push @OUT, [ 'google-adwords', $OUTPUT ];
		}

	#if (($nsref->{'yahooshop:filter'}) && ($META !~ /YAHOO/i)) {
	#	my $OUTPUT .=  "<!-- SKIPPED YAHOO DUE TO OUTPUT FILTER: $META -->";
	#	}
	#elsif ($nsref->{'yahooshop:chkoutjs'} ne '') {
	#	my $OUTPUT .=  "\n<!-- begin yahooshop -->".$msgs->show($nsref->{'yahooshop:chkoutjs'})."<!-- end yahooshop -->";
	#	}

	if (($nsref->{'nextag:filter'}) && ($META !~ /NEXTAG/i)) {
		my $OUTPUT .=  "\n<!-- SKIPPED NEXTAG DUE TO OUTPUT FILTER: $META -->";
		push @OUT, [ 'nextag', $OUTPUT ];
		}
	elsif ($nsref->{'nextag:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin nextag -->".$msgs->show($nsref->{'nextag:chkoutjs'})."<!-- end nextag -->";
		push @OUT, [ 'nextag', $OUTPUT ];
		}

	if (($nsref->{'pgrabber:filter'}) && ($META !~ /PRICEGRAB/i)) {
		my $OUTPUT .=  "\n<!-- SKIPPED PRICEGRABBER DUE TO OUTPUT FILTER: $META -->";
		push @OUT, [ 'pricegrabber', $OUTPUT ];
		}
	elsif ($nsref->{'pgrabber:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin pgrabber -->".$msgs->show($nsref->{'pgrabber:chkoutjs'})."<!-- end pgrabber -->";
		push @OUT, [ 'pricegrabber', $OUTPUT ];
		}

	 if (($nsref->{'cj:filter'}) && ($META !~ /CJ/i)) {
		my $OUTPUT .=  "\n<!-- SKIPPED CJ DUE TO OUTPUT FILTER: $META -->";
		push @OUT, [ 'commission-junction', $OUTPUT ];
		}
	 elsif (($nsref->{'cj:filter'}) && ($META =~ /EBATES/i)) {
		my $OUTPUT .=  "\n<!-- SKIPPED CJ DUE TO EBATES FILTER: $META -->";
		push @OUT, [ 'commission-junction', $OUTPUT ];
		}
	elsif ($nsref->{'cj:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin cj -->".$msgs->show($nsref->{'cj:chkoutjs'})."<!-- end cj -->";
		push @OUT, [ 'commision-junction', $OUTPUT ];
		}

	 if (($nsref->{'omnistar:filter'}) && ($META !~ /OMNISTAR/i)) {
		my $OUTPUT .=  "\n<!-- SKIPPED OMNISTAR DUE TO OUTPUT FILTER: $META -->";
		push @OUT, [ 'omnistar', $OUTPUT ];
		}
	 elsif (($nsref->{'omnistar:filter'}) && ($META =~ /EBATES/i)) {
		my $OUTPUT .=  "\n<!-- SKIPPED OMNISTAR DUE TO EBATES FILTER: $META -->";
		push @OUT, [ 'omnistar', $OUTPUT ];
		}
	elsif ($nsref->{'omnistar:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin omnistar -->".$msgs->show($nsref->{'omnistar:chkoutjs'})."<!-- end omnistar -->";
		push @OUT, [ 'omnistar', $OUTPUT ];
		}


	if ($nsref->{'kowabunga:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin kowabunga -->".$msgs->show($nsref->{'kowabunga:chkoutjs'})."<!-- end kowabunga -->";
		push @OUT, [ 'kowabunga', $OUTPUT ];
		}

	if (($nsref->{'bizrate:filter'}) && ($META !~ /BIZRATE/i)) {
		my $OUTPUT .=  "\n<!-- SKIPPED BIZRATE DUE TO OUTPUT FILTER: $META -->";
		push @OUT, [ 'bizrate/shopzilla', $OUTPUT ];
		}
	elsif ($nsref->{'bizrate:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin bizrate -->".$msgs->show($nsref->{'bizrate:chkoutjs'})."<!-- end bizrate -->";
		push @OUT, [ 'bizrate/shopzilla', $OUTPUT ];
		}

	if (($nsref->{'pronto:filter'}) && ($META !~ /PRONTO/i)) {
		my $OUTPUT .=  "\n<!-- SKIPPED BIZRATE DUE TO OUTPUT FILTER: $META -->";
		push @OUT, [ 'pronto', $OUTPUT ];
		}
	elsif ($nsref->{'pronto:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin pronto -->".$msgs->show($nsref->{'pronto:chkoutjs'})."<!-- end pronto -->";
		push @OUT, [ 'pronto', $OUTPUT ];
		}

	#if ($nsref->{'razormo:chkoutjs'} ne '') {
	#	my $OUTPUT .=  "\n<!-- begin razormo -->".$msgs->show($nsref->{'razormo:chkoutjs'})."<!-- end razormo -->";
	#	push @OUT, [ '', $OUTPUT ];
	#	}

	if ($nsref->{'sas:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin share-a-sale -->".$msgs->show($nsref->{'sas:chkoutjs'})."<!-- end share-a-sale -->";
		push @OUT, [ 'shareasale', $OUTPUT ];
		}

	if ($nsref->{'linkshare:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin linkshare -->".$msgs->show($nsref->{'linkshare:chkoutjs'})."<!-- end linkshare -->";
		push @OUT, [ 'linkshare', $OUTPUT ];
		}

	if ($nsref->{'become:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin become -->".$msgs->show($nsref->{'become:chkoutjs'})."<!-- end become -->";
		push @OUT, [ 'become', $OUTPUT ];
		}

	if ($nsref->{'upsellit:chkoutjs'} ne '') {
		my $OUTPUT .=  "<!-- begin upsellit_chkoutjs -->".$msgs->show($nsref->{'upsellit:chkoutjs'})."<!-- end upsellit_chkoutjs -->";
		push @OUT, [ 'upsellit', $OUTPUT ];
		}

	if ($nsref->{'fetchback:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin fetchback -->".$msgs->show($nsref->{'fetchback:chkoutjs'})."<!-- end fetchback -->";
		push @OUT, [ 'fetchback', $OUTPUT ];
		}

	# plugin:checkoutjs
	if ($nsref->{'plugin:chkoutjs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin other plugin -->\n".$msgs->show($nsref->{'plugin:chkoutjs'})."\n<!-- end other plugin -->";
		push @OUT, [ 'generic/checkout-plugin', $OUTPUT ];
		}

	if ($nsref->{'plugin:invoicejs'} ne '') {
		my $OUTPUT .=  "\n<!-- begin invoice plugin(s) -->\n".$msgs->show($nsref->{'plugin:invoicejs'})."\n<!-- end invoice plugin(s) -->";
		push @OUT, [ 'generic/invoice-plugin', $OUTPUT ];
		}

#	if ($SITE::merchant_id eq 'gkworld') {
#		open F, ">>/tmp/gkworld"; print F $OUTPUT."\n"; close F;
#		}
#	if ($SITE::merchant_id eq 'gssstore') {
#		open F, ">>/tmp/gssstore"; print F $OUTPUT."\n"; close F;
#		}

	if (defined $EXISTING_CART2) {
		## temporarily swap out the global cart for this conversion trackers 
		$self->cart2($EXISTING_CART2);
		}

#	open F, ">/tmp/conversion";
#	print F $OUTPUT;
#	close F;

	return(\@OUT);
	}





1;
