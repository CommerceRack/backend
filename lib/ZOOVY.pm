package ZOOVY;

#use bignum;  	# fixes issues with currency rounding

#use strict;
no warnings 'once'; # Keep perl from whining about variables used only once


#use encoding 'utf8';		## tells us to internally use utf8 for all encoding
use locale;  
use Fcntl ':flock';
use utf8 qw();
#use Net::RabbitMQ;
use Encode qw();
use strict;
use POSIX qw(strftime);
use Carp qw();
use Redis;
#use Math::Currency;

## ElasticSearch does
##		use JSON.pm
##		use URI::Escape 
## use ElasticSearch;
use Elasticsearch;

#use Cache::Memcached;
#use Any::Cache::Memcached;

BEGIN {
	eval 'require Cache::Memcached::libmemcached';
	$ZOOVY::MEMCACHESERVERS = undef;
	$ZOOVY::MEMCACHELIB = undef;
	if ($@) {
		# xs version not installed, use URI::Escape
		require Cache::Memcached;
		$ZOOVY::MEMCACHELIB = 'Cache::Memcached';
		}
	else {
		$ZOOVY::MEMCACHELIB = 'Cache::Memcached::libmemcached';
		}	
	%ZOOVY::EXISTING_MEMCACHE_PTR = ();
	}

use Carp qw();
use lib "/backend/lib";
require DBINFO;
require PRODUCT;
require ZTOOLKIT;
require POGS;
require PRODUCT;
require CFG;
use Storable;
# $Storable::interwork_56_64bit++;

$ZOOVY::UID = 99;
$ZOOVY::GID = 99;

# use CDB_File;
# use DB_File;
use CGI;
use utf8;
use YAML::Syck;
use Digest::MD5;
$YAML::Syck::ImplicitBinary++;
$YAML::Syck::ImplicitUnicode++;
$YAML::Syck::SingleQuote++;		# do not fucking enable this. it has issues with cr/lf 183535

$ZOOVY::RELEASE = 201401;
%ZOOVY::RELEASE_CACHE = (
	);


$ZOOVY::IS_COMMERCERACK = (-f "/etc/commercerack.ini")?1:0;
sub is_commercerack { return($ZOOVY::IS_COMMERCERACK); }

##
## NOTE: valid SKU /[A-Z0-9\-\_\#\:\/]/
##


##
## Revision history:
##
## Dec 17th 2000, removed category code into CATEGORY.pm
##

# I took the "my" off and added in "ZOOVY::" instead to specify namespace...
# it was breaking everywhere I was renferencing ZOOVY:: variables in render.cgi
# -AK 1/25/02

$ZOOVY::CACHE_LOCALMID = 1;
$ZOOVY::CACHE_LOCALCLUSTER = 1;

$ZOOVY::DEV_SHM = "/dev/shm";
if (! -d $ZOOVY::DEV_SHM) {
	$ZOOVY::DEV_SHM = "/tmp";
	}

$ZOOVY::LOCALTEMP  = "/tmp";
$ZOOVY::SHAREDTEMP = "/httpd/zoovy/tmp";

$ZOOVY::THEMESPATH = "/httpd/themes";
$ZOOVY::LOCALPATH  = "/httpd/local";

# cached copy of the data.
# experimental!
$ZOOVY::USERNAME = undef;					 # set when you call authenticate (the account name)
$ZOOVY::LUSER = undef;						 # set when you call authenticate (the login e.g. "brian")
$ZOOVY::FLAGS = undef;                  # set when you call authenticate (flags)
$ZOOVY::PRT = undef;

$ZOOVY::LOCKAPPID = undef;

$ZOOVY::TOUCHED_USER = undef;
$ZOOVY::TOUCHED_TS = undef;

$ZOOVY::USEDB = 1;

$ZOOVY::LAST_MID = undef;
$ZOOVY::LAST_MIDUSER = undef;
$ZOOVY::LAST_CLUSTER = undef;
$ZOOVY::LAST_CLUSTERUSER = undef;

##
## not sure where these constants are used anymore:
##
$IMGLIB::max_image_size = 2000; ## Maximum dimension of a scaled image in x or y
@IMGLIB::ext = qw(jpg jpeg png gif tif tiff bmp psd pdf ico pcx dib);
$IMGLIB::extensions = join '|', @IMGLIB::ext;
$IMGLIB::version = 1.3;




sub is_dev { return( (-f "/dev/shm/is_dev")?1:0 ); }

##
## for global initialization of certain variables/constants.
##
sub return_all_clusters {
        ## NOTE: some modules (ex: DBINFO) require access to all clusters to initialize, but of course we require
        ## ZOOVY from DBINFO and DBINFO from ZOOVY, so this function lets us work around that by making sure both
        ## sides are initialized properly before running.
			## REMEMBER: you must 
			## insert into ZUSERS (MID,USERNAME,CLUSTER,SUGARGUID) values (39,'bespin','bespin','bespin');
        $ZOOVY::CLUSTERS = ['crackle','endor','dagobah','hoth','bespin'];
        return($ZOOVY::CLUSTERS);
        }
$ZOOVY::CLUSTERS = &ZOOVY::return_all_clusters();


##
## this should always return a protocol-less hostname where /media/whatever works
##
sub resolve_media_host {
	my ($USERNAME) = @_;

	# return(sprintf("static.zoovy.com"));
	my ($CFG) = CFG->new();

	my $url = $CFG->get('global','cdn');
	if ($url) { return($url); }

	return(sprintf("static---$USERNAME.app-hosted.com"));
	}

##
## this should always return a protocol-less hostname where /media/whatever works
##
sub resolve_admin_host {
	my ($USERNAME) = @_;

	return(sprintf("admin---$USERNAME.app-hosted.com"));
	}

##
## returns /media/img/$USERNAME/??/image.??
##
sub image_path {
	my ($USERNAME, $imagename, %options) = @_;

	if ($imagename eq "") {
		return("/media/graphics/general/blank.gif");
		}

	my $width = $options{'W'};
	my $height = $options{'H'};
	my $bgcolor = $options{'B'};
	my $minimal = int($options{'minimal'});
	my $pixelscale = int($options{'pixelscale'});
	my $cache = int($options{'cache'});
	my $version = int($options{'V'});

	if (not defined $imagename) { $imagename = ''; }
	if (not defined $minimal) { $minimal = 0; }
	if (not defined $version) { $version = 0; }

	if (not defined $width) { $width  = ''; }
	if ($width eq '') { $width  = 0; }
	if (not defined $height) { $height  = ''; }
	if ($height eq '') { $height = 0; }
	if (not defined $bgcolor) { $bgcolor = ''; }
	$bgcolor = lc($bgcolor);
	$bgcolor =~ s/[^a-f0-9t]//g;
	if (length($bgcolor) != 6) { $bgcolor = ''; }
	if ($bgcolor eq 'tttttt') {
		## replace any extension with png
		($imagename) = split(/\./,$imagename);	# strip any extension
		$imagename = "$imagename.png";			# make sure we get a png.
		}
	elsif ($options{'ext'}) {
		if ($imagename =~ /^(.*)\.(gif|GIF|jpg|JPG|png|PNG)$/) { $imagename = $1; }
		$imagename = sprintf("$imagename.%s",$options{'ext'});
		}

	if (($width == 0) && ($height==0) && ($bgcolor eq '')) {
		## okay, so we really want the original here.
		}
	elsif ($minimal || ($width == 0) || ($height == 0)) {
		($width, $height) = &ZOOVY::image_minimal_size($USERNAME, $imagename, $width, $height, $cache);
		}

	## look in the last 5 characters for a file extension, otherwise add .jpg
	if (index(substr($imagename,-5),'.')<0) { $imagename .= '.jpg';  }

	if (not defined $width) { $width = 0; }
	if (not defined $height) { $height = 0; }

	my $url = "/media/img/$USERNAME";
	if ($height || $width) {
		$url .= '/W' . $width . '-H' . $height;
		if ($bgcolor ne '') { $url .= '-B' . $bgcolor; }
		if ($pixelscale) { $url .= '-P'; }
		if ($version) { $url .= "-V$version"; }
		}
	else {
		## we want the original.
		$url .= '/-';
		}

	$url .= '/' . $imagename;

	if ($options{'shibby'}) {
		## the shibby parameter tells us that we should relative pathing when on a 'public' or 'dev'
		## and leave it as a relative url / when we're not.
		my ($CFG) = CFG->new();
		if ($CFG->get('global','cdn')) {
			$url = sprintf("//%s%s",&ZOOVY::resolve_media_host($USERNAME),$url);
			}
		elsif (&ZOOVY::servername() =~ /^(public|dev)[\d]*$/) {
			$url = sprintf("//%s%s",&ZOOVY::resolve_media_host($USERNAME),$url);
			}		
		}

	return($url);
	}



###########################################################################
## imageurl
## handles imagelib/legacy conversion 
## parameters: USERNAME, variable, height, width, background, ssl
## 
sub mediahost_imageurl {
   my ($USERNAME, $var, $h, $w, $bg, $ssl, $ext, $v) = @_;

	if (not defined $v) { $v = 0; }

	# print STDERR "GT::imageurl received [".((defined $var)?$var:'undef')."]\n";
	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
	$v += int($gref->{'%tuning'}->{'images_v'});
	# use Data::Dumper; print Dumper($gref);

	# if we don't have an image, pass that along.
	if (!defined($var)) { return undef; }	
	if ($var eq '' || $var eq ' ') { return undef; } 
	if (substr($var,0,1) eq '/') { $var = substr($var,1); }	# remove leading /
	if (substr($var,-1) eq '_') { $var = substr($var,0,-1); } # remove trailing _

	my $proto = '';
	if (not defined $ssl) { }		## NOTE: this is probably the best case
	elsif (not $ssl) { $proto = 'http:'; }
	else { $proto = 'https:'; }

	if ($var !~ /^[Hh][Tt][Tt][Pp]/o) {
		# is from imagelibrary
		if (!defined($bg)) { $bg = "FFFFFF"; }
		$bg = lc($bg);	# MEDIA.pm formats these as lowercase (this way we don't have to symlink)

		my $MEDIAHOST = &ZOOVY::resolve_media_host($USERNAME);
		if ( (int($h)==0) && (int($w)==0) ) {
			my $dash = '-';
			if ($v>0) { $dash = sprintf("v%d",$v); }
			$var = "$proto//$MEDIAHOST/media/img/$USERNAME/$dash/$var";
			} 
		else {
			$var = "$proto//$MEDIAHOST/media/img/$USERNAME/W$w-H$h-B$bg".(($v)?"-v$v":"")."/$var";
			}

		## added check to see if extension was already on var, patti 2005-10-06
		if ( (defined $ext) && ($ext ne '') && ($var !~ /\.[a-zA-Z][a-zA-Z][a-zA-Z]$/)) {
			$var .= '.'.$ext;
			}
		}


	return($var);
}




%ZOOVY::PLATFORM = ();
sub platformify {
	my ($USERNAME) = @_;

	if ($USERNAME eq '') { 
		warn "called platformify with blank user\n";
		return(undef); 
		}

	if (defined $ZOOVY::PLATFORM{$USERNAME}) {
		## short circuit so we don't lookup file
		return($ZOOVY::PLATFORM{$USERNAME});
		}

	my $PATH = &ZOOVY::resolve_userpath($USERNAME);
	my $ref = undef;
	my $HOSTNAME = lc(&ZOOVY::servername());
	if (-f "$PATH/platform.yaml") {
		($ref) = YAML::Syck::LoadFile("$PATH/platform.yaml");
		}
	return($ZOOVY::PLATFORM{$USERNAME} = $ref);
	}


##
##	 returns the release the user is on so we know which database tables, syntax, etc. to use
##
sub myrelease {
	my ($USERNAME) = @_;

	if (defined $ZOOVY::RELEASE_CACHE{$USERNAME}) {
 		return($ZOOVY::RELEASE_CACHE{$USERNAME});
		}

	my $RELEASE = 0;
	# my ($USERPATH) = &ZOOVY::resolve_userpath($USERNAME);
	# if (&ZOOVY::servername() eq 'dev') { $USERPATH =~ s/endor/pop/; }
	# if (-f "$USERPATH/dbpasswd") { $RELEASE = 201339; }
	my ($pref) = &ZOOVY::platformify($USERNAME);
	$RELEASE = $pref->{'release'} || '201301';

	$ZOOVY::RELEASE_CACHE{$USERNAME} = $RELEASE;
	return( $ZOOVY::RELEASE_CACHE{$USERNAME} );	
	}
	


###############################################################################
## image_minimal_size
##
## Purpose: Does all the algebra for resizing an image
## Accepts: A username, an orignal image name, a requested width and a
##          requested height
## Returns: A new width and a new height
##
###############################################################################
sub image_minimal_size {
	my ($USERNAME, $imagename, $request_width, $request_height, $cache) = @_;

	if ($imagename eq '') { return(-1,-1); }
	my ($width,$height) = (-2,-2);

	if ($request_width > $IMGLIB::max_image_size) {
		$request_width = $IMGLIB::max_image_size;
		}
	if ($request_height > $IMGLIB::max_image_size) {
		$request_height = $IMGLIB::max_image_size;
		}

	##
	## SUPER CACHING LAYER  (stores answers on local disk, they expire every 24 hrs)
	##		every user has a file in $logdir/username.bin -- we pop that open (and even keep it persistent)
	##		inside it is simply a hashref of $imagename!width!height = width|height|timestamp
	##		if timestamp is older than 24 hrs. it will refresh the image	
	$USERNAME =~ s/\W//go;
	$USERNAME = lc($USERNAME);
	my ($redis) = &ZOOVY::getRedis($USERNAME,2);

	if (1) {
		my ($orig_width, $orig_height) = (-3,-3);

		my $info = undef;	
		if (defined $redis) {
			my ($YAML) = $redis->hget("IMAGE.$USERNAME","$imagename");
			if ($YAML) {
				$info = YAML::Syck::Load($YAML);
				}
			}

		if (not defined $info) {
			require MEDIA;
			($info) = &MEDIA::getinfo($USERNAME,$imagename);
			if ($info->{'err'}==12) {
				print STDERR "&MEDIA::getinfo($USERNAME,$imagename,DETAIL=>0,CACHE=>$cache,SKIP_DISK=>1); got err 12\n";
				}
			if (defined $redis) {
				my %store = ();
				foreach my $k ('FID','Format','MasterSize','W','H','TS') { $store{$k} = $info->{$k}; }
				$redis->hset("IMAGE.$USERNAME","$imagename",YAML::Syck::Dump(\%store));
				}
			}

		## use Data::Dumper; print STDERR Dumper($info);		
		if (defined $info) {
			($orig_width, $orig_height) = ($info->{'W'}, $info->{'H'});
			if (($info->{'err'}>0) || ($orig_width<=0) || ($orig_height<=0)) {
				($orig_width,$orig_height) = (-4,-4);
				}
			}			

		# print "$orig_width $orig_height  $request_width $request_height\n";
		if ($orig_width<0 || $orig_height<0) {
			## shit happened, no original width or height
			}
		elsif (($request_width == $orig_width) && ($request_height == $orig_height)) {
			$width  = $request_width;
			$height = $request_height;
			}
		elsif (($request_width == 0) && ($request_height==0)) {
			## both x and y are 0
			$width = $orig_width;
			$height = $orig_height;			
			}
	   elsif (($request_width == 0) || ($request_height==0)) {
			## either x or y are 0 (but not both)
         if (($request_height>0) && ($request_width==0)) {
            ## Doesn't work: $request_width = int ( $orig_height / $request_height * $orig_width );
            ## Doesn't work: $request_width = int ( $orig_height * $request_width / $orig_width );
				$request_width =  int ( $orig_width * $request_height / $orig_height );
            }
         elsif (($request_width>0) && ($request_height==0)) {
            ## Doesn't work: $request_height = int ( $orig_width / $request_width * $orig_height );
            ## Doesn't work: $request_height = int ( $orig_width * $request_height / $orig_height );
				$request_height = int ( $orig_height * $request_width / $orig_width );
            }

			$width = $request_width;
			$height = $request_height;
	      }
		else {
			# See how much each axis needs to be scaled by
			my $width_ratio  = ($request_width  / $orig_width);
			my $height_ratio = ($request_height / $orig_height);
			# If the scale values are equal (meaning its already proportional)
			if ($width_ratio <= $height_ratio) {
				## we have to scale more on  the width (i.e., it has a smaller
				## value), then use it to scale the image
				$width  = int($width_ratio * $orig_width);
				$height = int($width_ratio * $orig_height);
				}
			else {
				## we have to scale more on  the height (i.e., it has a smaller
				## value), then use it to scale the image
				$width  = int($height_ratio * $orig_width);
				$height = int($height_ratio * $orig_height);
				}
			}

		}

	return ($width, $height);
	}



##
## this loads /dev/shm/identity.bin which is created by /root/configs/dump-shm-files.pl 
##	the format for identity.bin is generated by /root/configs/lib/HOSTCONFIG.pm getHost(whoami());
##
#sub my_identity {
#	my $response = undef;
#	if (-f "/dev/shm/identity.bin") {
#		$response = retrieve("/dev/shm/identity.bin");
#		}
#	return($response);
#	}
#
sub return_all_ednsservers {
	return(['4.4.4.4']);
	}

sub return_all_idnsservers {
	return(['208.74.184.18','208.74.184.19']);
	}

##
## guaranteed to return a cached operating system type.
##
sub host_operating_system {
	if (not defined $ZOOVY::OS) {
		$ZOOVY::OS = `/bin/uname`;
		}
	if ($ZOOVY::OS =~ /^Linux/i) { return('LINUX'); }
	elsif ($ZOOVY::OS =~ /^SunOS/i) { return('SOLARIS'); }
	else { return('UNKNOWN'); }
	}

@ZOOVY::INVENTORY_CONDITIONS = (
	{ id=>'NEW', pretty=>'New' },
	{ id=>'OPEN', pretty=>'New - Open Box' },
	{ id=>'USED', pretty=>'Used' },
	{ id=>'RMFG', pretty=>'Remanufactured' },
	{ id=>'RFRB', pretty=>'Refurbished' },
	{ id=>'BROK', pretty=>'Broken/Damaged (see notes)' },
	{ id=>'CRAP', pretty=>'Scrap/not saleable' },
	);

##
##
@ZOOVY::RETURN_STAGES = (
	{ id=>"NEW", name=>"New Ticket", hint=>"A ticket which has not been addressed by a CSR", required=>1 },
	{ id=>"ACT", name=>"Active",  hint=>"The ticket is active, one or more CSR's has worked on the ticket, further action required.", required=>1 },
	{ id=>"ACK", name=>"Waiting", hint=>"A ticket which has been responded to by a CSR and is waiting on customer action.", required=>1 },
	{ id=>"XXX", name=>"Closed", hint=>"The issue has been closed, and cannot be reopened by customer.", required=>1 },
 
	{ id=>"EXQ",  name=>"Exchange Requested", }, 
	{ id=>"EXA",  name=>"Exchange Approved/Authorized",  }, 
	{ id=>"EXO",  name=>"Exchange Open (sent, in transit)", }, 
	{ id=>"EXR",  name=>"Exchange Open (wait received, waiting for send.)", }, 
	{ id=>"EMP",  name=>"Exchange Open (cross-ship, waiting for receive.)", },
	{ id=>"EINC", name=>"Exchange Item(s) not received", closed=>1 },
	{ id=>"EXX",  name=>"Exchange Closed", closed=>1 },

	{ id=>"IXQ",  name=>"Referred for Inspection", },

	{ id=>"RMR",  name=>"Return Requested", hint=>"Return requested, but no approval has been given." }, 
	{ id=>"RMA",  name=>"Return Approved/Authorized", hint=>"Return has been approved." }, 
	{ id=>"RMO",  name=>"Return Open (in transit)", hint=>"Return is in transit from customer." }, 
	{ id=>"RMR",  name=>"Return Received", hint=>"Return has been received at the dock." }, 
	{ id=>"RMI",  name=>"Return Inspected", hint=>"Return has been open, and contents have been verified." }, 
	{ id=>"RM1",  name=>"Return Full Authorized", hint=>"Return finished, full refund authorized.", closed=>1, }, 
	{ id=>"RM2",  name=>"Return Partial Authorized", hint=>"Return finished, partial refund authorized.", closed=>1, }, 
	{ id=>"RMC",  name=>"Return Full Complete", hint=>"Return finished, a complete refund was processed.", closed=>1, }, 
	{ id=>"RMP",  name=>"Return Partial Complete", hint=>"Return finished, a partial credit has been processed.", closed=>1, }, 
	{ id=>"RMD",  name=>"Return Denied", hint=>"Return has been denied.", closed=>1, }, 
	);




## converts a float to an int safely
## ex: perl -e 'print int(64.35*100);' == 6434  (notice the penny dropped)
## ex: perl -e 'print int(sprintf("%f",64.35*100));' == 6435
sub f2int { return(int(sprintf("%0f",$_[0]))); }



##
## check_free_memory can use any of the following parameters:
##		is_safe
##		need_percent_free
##
sub check_free_memory {
	my (%params) = @_;

	my $okay = 1;
	my %stats = ();
	open F, "</proc/meminfo";
	while (<F>) {
		if (/(.*?):[\s]+([\d]+) kB$/) {
			$stats{$1} = $2;
			}
		}
	close F;

	if ($params{'is_safe'}) {
		$params{'need_percent_free'}=5;	# need 5% free to be considered safe.
		}

	if ($params{'need_percent_free'}) {
		my $availpct = (($stats{'MemFree'} / $stats{'MemTotal'})*100);
		print "AVAIL: $availpct\n";
		$okay = ($availpct > $params{'need_percent_free'})?1:0;
		}
	else {
		$okay = -1;
		}
	
	use Data::Dumper;
	print Dumper(\%stats);

	return($okay);
	}


##
## a method for estimating the sizeof a variable
##
sub sizeof {
	my ($ref) = @_;
	my $yaml = YAML::Syck::Dump($ref);
	return(length($yaml));	
	}


##
## returns the application which is currently running (note: eventually this might have better handlers) currently
## /httpd /process.pl etc.
##
sub appname {
	my $app = $0;
	if ($app eq '/httpd/servers/amazon/orders.pl') {
		$app = 'amazon/orders.pl';
		}
	elsif (index($app,"/")>=0) {
		## remove slashes
		$app = substr($app,rindex($app,"/"));
		}
	return($app);
	}



##
## gets messages from a queue
##
sub msgsGet {
	my ($USERNAME, $queuename, $lowmsgid) = @_;
	if ($queuename eq '') { $queuename = '*'; }

	my ($redis) = &ZOOVY::getRedis($USERNAME,2);
	$USERNAME = lc($USERNAME);

	if (not defined $lowmsgid) { $lowmsgid = 0; }
	my ($line) = $redis->lrange("msg.queue.$USERNAME.$queuename",0,1);
	my ($highmsgid,$params) = split(/\?/,$line,2);

	my @MSGS = ();
	if ($highmsgid > $lowmsgid) {
		foreach my $line (reverse @{$redis->lrange("msg.queue.$USERNAME.$queuename",0,1000)}) {
			my ($msgid,$params) = split(/\?/,$line,2);
			if ($msgid > $lowmsgid) {
			 	# next if ($params->{'expires'}) 
				my $msgref = &ZTOOLKIT::parseparams($params);
				$msgref->{'id'} = $msgid;
				push @MSGS, $msgref;
				}
			}
		}

	return(\@MSGS);
	}


##
##
##
sub msgClear {
	my ($USERNAME, $queuename, $msgid, $origin) = @_;

	if ($queuename eq '') { $queuename = '*'; }
	my ($redis) = &ZOOVY::getRedis($USERNAME,2);
	$USERNAME = lc($USERNAME);

	my ($i) = $redis->get("msg.id.$USERNAME.$queuename");
	if ($msgid == -1) {
		## -1 is clear all, empty queue
		($i) = $redis->incr("msg.id.$USERNAME.$queuename");
		$redis->del("msg.queue.$USERNAME.$queuename");
		}
	elsif ($msgid == 0) {
		## clear a message based on the origin
		&ZOOVY::msgAppend($USERNAME,$queuename,{"verb"=>"remove","origin"=>$origin,"from-msg"=>0});
		}
	elsif ($msgid > 0) {
		## yes, i'm aware this is the wrong way to remove an item from a redis queue
		## but it should be fine. 99.9999% of the time
		my $llen = $redis->llen("msg.queue.$USERNAME.$queuename");
		while ($llen-- > 0) {
			my ($thismsgline) = $redis->lindex("msg.queue.$USERNAME.$queuename",$llen);
			my ($thismsgid,$thismsgparams) = split(/\?/,$thismsgline);
			if ($msgid == $thismsgid) {
				$redis->lrem("msg.queue.$USERNAME.$queuename",0,$thismsgline);	# remove's all occurrences of thismsgline from list.
				my ($params) = &ZTOOLKIT::parseparams($thismsgparams);
				if ($params->{'verb'} eq 'remove') {
					}
				elsif ($params->{'origin'} || $origin) {
					&ZOOVY::msgAppend($USERNAME,$queuename,{"verb"=>"remove","origin"=>($params->{'origin'} || $origin),"from-msg"=>$msgid});
					}
				}
			}
		}	

	return($i);
	}



##
## stores messages in a queue
##
sub msgAppend {
	my ($USERNAME, $queuename, $msgparams) = @_;

	if ($queuename eq '') { $queuename = '*'; }
	my ($redis) = &ZOOVY::getRedis($USERNAME,2);
	$USERNAME = lc($USERNAME);
	my ($i) = $redis->incr("msg.id.$USERNAME.$queuename");
	my $msg = "$i?".&ZTOOLKIT::buildparams($msgparams);
	$redis->lpush("msg.queue.$USERNAME.$queuename",$msg);
	$redis->ltrim("msg.queue.$USERNAME.$queuename",0,100);
	$redis->expire("msg.queue.$USERNAME.$queuename",86400);
	return($i);
	}



##
##
##
sub resolve_sku {
	my ($USERNAME,$itemcode,$TYPE) = @_;

	require PRODUCT::BATCH;
	require INVENTORY2;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($lTB) = &ZOOVY::resolve_lookup_tb($USERNAME,$MID);

	my $SKU = undef;
	if (length($SKU)>35) {
		## this cannot be a valid zoovy sku
		}
	elsif ($SKU !~ /:/) {
		## this might be a zoovy product id, in which case we use this:
		if (&ZOOVY::productidexists($USERNAME,$itemcode)) {
			$SKU = $itemcode;
			}
		}
	elsif ($SKU =~ /\:/) {
		## inventoriable options will always contain a : so we'll look them up this way.
		my ($PRODUCT,$CLAIM,$INVOPTS) = &PRODUCT::stid_to_pid($itemcode);
		my $pstmt = "select SKU from $lTB where MID=$MID and PID=".$udbh->quote($PRODUCT)." and INVOPTS=".$udbh->quote($INVOPTS);
		# print STDERR "$pstmt\n";
		($SKU) = $udbh->selectrow_array($pstmt);
		}

	## hmm.. we might have a UPC, ASIN, MFGID .. we'll use the functions below for now.
	if (not defined $SKU) {
		## UPC
		my $pstmt = "select SKU from $lTB where MID=$MID and UPC=".$udbh->quote($itemcode);
		# print STDERR "$pstmt\n";
		($SKU) = $udbh->selectrow_array($pstmt);
		}

	if (not defined $SKU) {
		## MFGID
		my $pstmt = "select SKU from $lTB where MID=$MID and MFGID=".$udbh->quote($itemcode);
		# print STDERR "$pstmt\n";
		($SKU) = $udbh->selectrow_array($pstmt);
		}
	
	if (not defined $SKU) {
		## SUPPLIERID
		my $pstmt = "select SKU from $lTB where MID=$MID and SUPPLIERID=".$udbh->quote($itemcode);
		# print STDERR "$pstmt\n";
		($SKU) = $udbh->selectrow_array($pstmt);
		}

	## OLD LEGACY PRODUCT ATTRIBUTES (PRE UPGRADE)
	#if ((not defined $SKU) && ($itemcode ne '')) {
	#	($SKU) = @{&PRODUCT::BATCH::list_by_attrib($USERNAME,'zoovy:prod_upc',$itemcode)};
	#	}	
	#if ((not defined $SKU) && ($itemcode ne '')) {
	#	($SKU) = @{&PRODUCT::BATCH::list_by_attrib($USERNAME,'zoovy:prod_mfgid',$itemcode)};
	#	}	
	#if ((not defined $SKU) && ($itemcode ne '')) {
	#	($SKU) = INVENTORY::resolve_sku($USERNAME,'META_UPC',$itemcode);
	#	}
	#if ((not defined $SKU) && ($itemcode ne '')) {
	#	($SKU) = INVENTORY::resolve_sku($USERNAME,'META_MFGID',$itemcode);
	#	}
	&DBINFO::db_user_close();

	return($SKU);
	}



##
## BITSTR LIBRARIES
##
sub mkt_to_bitsref {
	my ($mkt) = @_;

	my $i = 0;
	my @bits = ();
	while ($i<32) {
		if (($mkt & 1<<$i)>0) { push @bits, ($i+1); }
		$i++;
		}
	return(\@bits);
	}

##
## ZZZZZZ = 10000001101111110000111111111111 = 01234567890123456789012345678901 (32 bits)
##
## this is an array of bits which should be turned on, the length is arbitrary, each 32 bits determines the offset +6 so for example
##		values +1 => +32 are in position 0-5 
##		values +33 => +64 are in position 6-11
##		values +65 => +96 are in position 15-16
##
## perl -e 'use lib "/backend/lib"; use ZOOVY; print ZOOVY::bitstr(["1","33","65","96"]);'
##		000001000001ZIK0ZL
##
sub bitstr {
	my ($set) = @_;

	if (ref($set) eq 'ARRAY') {
		## this is what we expect!
		}	
	elsif (ref($set) eq 'HASH') {
		## sometimes we work with hashrefs, if we get a hashref then the keys are the bitstr id's
		my @ids = keys %{$set};
		$set = \@ids;
		}
	else {
		## this is an error!
		}

	my @vs = ();
	foreach my $s (@{$set}) {
		# print sprintf("S/32:%d\n",int(($s-1)/32));
		$vs[int(($s-1)/32)] |= (1<<((($s-1)%32)));		# we use a |= so that we can handle duplicate id's being passed in an array (yay, no more hashes!)
		}
	my $str = '';
	foreach (my $i = scalar(@vs)-1; $i>=0;$i--) {
		my $result = &ZTOOLKIT::base36($vs[$i]);
		$result = '0' x ( 6 - length( $result ) ) . $result;
		$str = $result.$str;
		}
	#use Data::Dumper;
	#print Dumper(\@vs,$str);
	return($str);
	}

##
## returns a SQL statement capable of taking a variable length bitstr and converting it (using mysql base 36 functions)
##		applying a mask and returning a true or false.
##
## perl -e 'use lib "/backend/lib"; use ZOOVY; print ZOOVY::bitstr_sql("\"000001000001000001ZIK0ZK\"",["1","33","65","96"]);'
##
sub bitstr_sql {
	my ($var,$set) = @_;

	my @vs = ();
	foreach my $s (@{$set}) {
		$vs[int($s/32)] |= (1<<(($s%32)-1));
		}

	my $str = '';
	foreach (my $i = scalar(@vs)-1; $i>=0;$i--) {
		#my $result = &ZTOOLKIT::base36($vs[$i]);
		#$result = '0' x ( 6 - length( $result ) ) . $result;
		next if ($vs[$i]==0);
		my $result = " ((conv(substring($var,$i*6+1,6),36,10)&$vs[$i])=$vs[$i]) ";
		$str = $result . (($str eq '')?'':' AND '). $str;
		}
	#use Data::Dumper;
	#print Dumper(\@vs,$str);
	return($str);
	}


##
## returns an arrayref of id's ex:
##		[ 1, 2, 6 ]
##
sub bitstr_bits {
	my ($bitstr) = @_;

	if ((length($bitstr)%6)!=0) {
		warn "invalid input (must be 6 digits)\n";
		}

	my @RESULT = ();	
	my $i = 0;
	while (length($bitstr)>0) {
		# print "bitstr: $bitstr\n";
		my $val = &ZTOOLKIT::unbase36( substr($bitstr,0,6) );
		$bitstr = substr($bitstr,6);

		if ($val > 0) {
			my $x = 0;
			while ($x<32) {
				# print "X: $x\n";
				if ($val & (1<<$x)) { 
					my $z = $x+($i*32)+1;
					push @RESULT, $z; 
					# print "z: $z val: $val x:$x i:$i\n"; 
					}
				$x++;
				}
			}
		$i++;
		}
	
	return(\@RESULT);
	}


#sub bitstr_dsts {
#	my ($bitstr) = @_;
#	my %DSTS = ();
#	foreach my $id (@{&ZOOVY::bitstr_bits($bitstr)}) {
#		$DSTS{$id}++;		
#		}
#	foreach my $ref (@ZOOVY::INTEGRATIONS) {
#		if ($ref->{'id'} == $ref) { $DSTS{$id}=$ref; }
#		}
#	return(
#	}





#my $safe = to_safesku("ABC-12-324-234-234-234:1344");
#print "SAFE : $safe\n";
#print from_safesku($safe);

## converts a standard stid or safe sku to a marketplace syndicatable sku
sub to_safesku {
   my ($STID) = @_;

	#if ($STID =~ /Z\-/) {
	if ($STID =~ /^Z\-/) {
		## already encoded. (Z- skus are not allowed)
		}
	elsif ($STID =~ /[_\#:\/]+/) {
		## note: this will NOT encode
	   $STID =~ s/-/-Z/gs;  # remove dashes and underscores
		$STID =~ s/_/-X/gs;
	   $STID =~ s/\#/-A/gs;
		$STID =~ s/:/-B/gs;
		$STID =~ s/\//-C/gs;
		$STID = "Z-".$STID;
		}

   return($STID);
   }


## converts a safe SKU back to a regular sku.
sub from_safesku {
   my ($SAFE) = @_;

	if ($SAFE =~ /^Z-(.*?)$/) {
	   $SAFE =~ s/^Z\-//gs;    # strip leading Z-
 		$SAFE =~ s/\-C/\//gs;
 		$SAFE =~ s/\-B/\:/gs;
		$SAFE =~ s/\-A/\#/gs;
		$SAFE =~ s/\-X/_/gs;
		$SAFE =~ s/\-Z/-/gs;
		}

   return($SAFE);
   }







##
## converts floating point to money (safely)
## this should replace *ALL* sprintf("\$%.2f" in the system since those don't work reliably e.g.:
## 	perl -e 'print sprintf("%0.2f",1.006);'
## for now, assumes USD as currency, perhaps in the future this will change as I suspect
##
## this is a killer test:
## perl -e 'use lib "/backend/lib"; use ZOOVY; print ZOOVY::f2money("141.48");'
##
## perl -e 'print int(sprintf("%.2f",73.49)*100);'  # FAILS
## perl -e 'use lib "/backend/lib"; use ZOOVY; print ZOOVY::f2money("73.49");
##
## perl -e 'use lib "/backend/lib"; use ZOOVY; while (1) { my $x = int(rand()*10000)/100; 
##		if (sprintf("%.2f",$x) ne ZOOVY::f2money($x)) { die(print "X:$x sprintf:".sprintf("%.2f",$x)." f2:".ZOOVY::f2money($x)."\n") } else { print "X:$x\n" }; }'
##
## hard tests:
##	perl -e 'use lib "/backend/lib"; use ZOOVY; print ZOOVY::f2money(8.999);'
##
sub f2money {
	my ($float) = @_;

#	my $float = (Math::Currency::Money($float));
#	$float*=$float;
#	return($float);



#	$float = int($float * 1000);
#	my $sign = ($float<0)?'-':'';

#	print int($float/1000)."\n";
#	print POSIX::ceil(abs($float)/10)."\n";

	# print "FLOAT: $float\n";

	## 32.44
	## 8.99999 = 8.99
#	my $ceil = POSIX::ceil(abs($float));
#	return(sprintf("%s%d.%02d",$sign,int($ceil/1000),($ceil/10)%100));

## NOTE: this failed on 8.9999
   $float = int($float * 1000);
   my $sign = ($float<0)?'-':'';

	#print POSIX::ceil(abs($float)/10)."\n";
	$float = sprintf("%s%0.2f",$sign,$float/1000);

	## 8.99999 = 8.00
#   $float = sprintf("%s%d.%02d",
#      $sign,
#      int($float/1000),
#      substr(POSIX::ceil(abs($float)/10),-2));

	# perl -e 'use lib "/backend/lib"; use ZOOVY; my $i = 0; while ($i<100000) { my $x = $i/100; my $str = sprintf("%.2f",$x); $x += 0.001; $x -= 0.001; if ($str ne &ZOOVY::f2money($x)) { print sprintf("%s %s",$x,&ZOOVY::f2money($x)); die($i); } $i++; } '
   return("$float"); 
	}


sub is_not_happytime {
	my (%params) = @_;

	my $reason = undef;

	if (defined $params{'avg'}) {
		# 29.15 28.15 23.90 28/243 14332
		my $AVG1 = 0;
		if (&ZOOVY::host_operating_system() eq 'SOLARIS') {
			my $line = undef;
			open MH, "/usr/bin/uptime|";
			while(<MH>) { $line .= $_; }
			close MH;
			if ($line =~ /load average\: ([\d\.]+)/s) {
				($AVG1) = $1;
				}
			}
		else {
			open F, "</proc/loadavg"; my ($line) = <F>; close F;
			($AVG1) = split(/[\s\t]+/,$line);
			# print "AVG1:$AVG1\n";
			}

		if ($AVG1 >= $params{'avg'}) {
			$reason = sprintf("load:%f",$params{'avg'});
			}
		}
	return($reason);
	}

##
## prints k1=[value1] k2=[value2]
##
sub debugdump {
	my ($hashref,$keys) = @_;

	my $c = '';
	if (not defined $keys) {
		$keys = [ sort keys %{$hashref} ];
		}
	foreach my $k (@{$keys}) {
		if (ref($hashref->{$k}) eq '') {
			$c .= "$k=[$hashref->{$k}] ";
			}
		elsif (ref($hashref->{$k}) eq 'HASH') {
			$c .= "$k=={";
			foreach my $k2 (keys %{$hashref->{$k}}) {
				$c .= "$k2:$hashref->{$k}->{$k2} ";
				}
			chop($c);
			$c .= "} ";
			}
		else {
			$c .= "$k:".Dumper($hashref->{$k})." ";
			}
		}
	chomp($c);
	return($c);
	}




sub conflagerate {
	my ($SRC,$MSG,$THESHOLD) = @_;

	

	}



##
## a replacement for Carp::confess which also creates a ticket and/or optionally clucks instead.
##		(this could eventually be configurable on a per user basis possibly)
##
##	dupcheck
##
sub confess {
	my ($USERNAME,$MSG,%options) = @_;

	#$Carp::CarpLevel = 0;
	my $SKIP = 0;
 
	my ($SUBJECT) = split(/[\n]/,$MSG,2);
	$SUBJECT = "[fault:$0] $SUBJECT";

	my $LOG = undef;
	if ($options{'dupcheck'}) {
		($LOG) = $SUBJECT;
		$LOG =~ s/[^\w]+/_/g;
		$LOG = "/tmp/carp-$USERNAME-$LOG.log";
		}

	my ($TICKET) = 0;
	if ((defined $LOG) && (-f $LOG)) {
		## this is a duplicate
		open F, "<$LOG";
		my ($TICKET) = <F>;
		close F;

		## we should append to ticket here.
		}
	elsif ($SKIP) {
		}
	else {
		open F, ">>/tmp/confess.$USERNAME";
		print F Dumper({'USERNAME'=>$USERNAME,
            'MID'=>&ZOOVY::resolve_mid($USERNAME),
            '*CREATED'=>'now()',
            'SERVER'=>&ZOOVY::servername(),
            'REMOTE_IP'=>$ENV{'REMOTE_ADDR'},
            'SUBJECT'=>$SUBJECT,
            'BODY'=>sprintf("Server: %s\nProcess: $$\n\nFault:\n%s",&ZOOVY::servername(),Carp::longmess($MSG))
				});
		close F;
		}

	# $Carp::CarpLevel = 0;
	if (not $options{'justkidding'}) {
		## okay we really want to exit here.
		Carp::confess($MSG);
		}
	else {
		Carp::cluck($MSG);
		}

	return($TICKET);
	}



##
##
##
sub getElasticSearch {
	my ($USERNAME,%params) = @_;

	my ($platformref) = &ZOOVY::platformify($USERNAME);
	my ($CFG) = CFG->new();
	my ($elasticcfg) = $CFG->get('elasticsearch');

	my $HOST = undef;
	if (defined $params{'server'}) {
		$HOST = $params{'server'};
		}
	elsif (defined $elasticcfg) {
		$HOST = $elasticcfg->{'host'};
		}
	else {
		$HOST = '127.0.0.1'; # &ZOOVY::resolve_cluster($USERNAME);
		}
	
	my $es = Elasticsearch->new(	
		nodes		=> [ sprintf(lc('%s:9200'),$HOST) ],  # default '127.0.0.1:9200'
#	  transport	 => 'httplite',						# default 'http'
#		  max_requests => 10_000,					  # default 10_000
#		  trace_calls  => 'log_file',
#		no_refresh	=> 1
		);

	return($es);
	}



sub getGlobalMemCache {
	## alright, this is a slightly more complex endeavor than i'd like.. the goal is to establish our upstream
	## memcache servers based on the cluster.
	my @SERVERS = ();


   if ($ZOOVY::IS_COMMERCERACK) {
      return(&ZOOVY::getMemd());
      }

	#print STDERR "Global memcahe\n";
	#if (&ZOOVY::is_commercerack()) {
	#	my ($CFG) = CFG->new();
	#	my ($memcachecfg) = $CFG->get('memcached');
	#	if ($memcachecfg->{'host'}) {
	#		push @SERVERS, sprintf("%s:%s",$memcachecfg->{'host'},$memcachecfg->{'port'}|4000);
	#		}
	#	}
	#elsif (-f "/dev/shm/global-memache-hint.txt") {
	#	## use the global-memcache-hint.txt
	#	open Fm, "</dev/shm/global-memache-hint.txt";
	#	while (<Fm>) { push @SERVERS, $_; } 
	#	close Fm;
	#	}
	#else {
	#	## lets create a global memcache hint, first try and determine the cluster
	#	require PLATFORM;
	#	my $THISCLUSTER = PLATFORM->new()->thiscluster();
	#	my $y = $ZOOVY::MEMCACHESERVERS;
	#	if (not defined $y) {
	#		$y = $ZOOVY::MEMCACHESERVERS = YAML::Syck::LoadFile("/httpd/static/memcache.yaml");
	#		}
	#	if (defined $y->{$THISCLUSTER}) {
	#		@SERVERS = @{$y->{$THISCLUSTER}};
	#		}
	#	else {
	#		## use a safe global default
	#		warn "using a safe global default since we couldn't determine global memcache";
	#		@SERVERS =  ( '192.168.2.32:4000' );
	#		}
	#	open Fm, ">/dev/shm/global-memache-hint.txt";
	#	foreach my $line (@SERVERS) {	print Fm $line; } 
	#	close Fm;
	#	}

	#my $memd = undef;
	#if (not defined $memd) {
	#	$memd = $ZOOVY::EXISTING_MEMCACHE_PTR{ join("|",@SERVERS) };
	#	if (defined $memd) {
	#		# print STDERR "USED EXISTING!\n";
	#		}
	#	}

	#if (defined $memd) {
	#	}
	#elsif (scalar(@SERVERS)>0) {		
	#	# print STDERR "MEMCACHED: ".YAML::Syck::Dump($y->{$CLUSTER})."\n";
	#	# $memd = Cache::Memcached->new({
	#	$memd = $ZOOVY::EXISTING_MEMCACHE_PTR{ join("|",@SERVERS) } = $ZOOVY::MEMCACHELIB->new({
	#		servers => \@SERVERS,
	#		compress_threshold => 0,
	#		});
	#	}

	#my $MEMD = $ZOOVY::MEMCACHELIB->new({
	#	servers => \@SERVERS,
	#	# enable_compress=>0,
	#	# compress_threshold => 0,
	#	});
	#return($memd);
	}


##
## initializes the client access to a memcached
##
sub getMemd {
	my ($USERNAME) = @_;

	# return(undef);
	## print STDERR "Local memcahe -- ".join("|",caller(0))."\n";
	
	my $memd = undef;
	if (&ZOOVY::is_commercerack()) {
		my @SERVERS = ();
		my ($CFG) = CFG->new();
		my ($memcachecfg) = $CFG->get('memcached');
		if ($memcachecfg->{'host'}) {
			push @SERVERS, sprintf("%s:%s",$memcachecfg->{'host'},$memcachecfg->{'port'}|4000);
			}
      if ((defined $memcachecfg->{'@try'}) && (ref($memcachecfg->{'@try'}) eq 'ARRAY')) {
         foreach my $try (@{$memcachecfg->{'@try'}}) {
            push @SERVERS, $try;
            }
         }
		$memd = $ZOOVY::MEMCACHELIB->new({servers => \@SERVERS,compress_threshold=>0});
		}
	#elsif (($ZOOVY::MEMCACHELIB eq 'Cache::Memcached') && (-S '/data/redis/redis.sock')) {
	#	## this is probably a cluster, so we'll connect to localhost
	#	$memd = $ZOOVY::MEMCACHELIB->new({servers => '127.0.0.1:4000',enable_compress=>0,compress_threshold=>0});
	#	}
	#elsif (-f "/httpd/static/memcache.yaml") {
#
#		my $y = $ZOOVY::MEMCACHESERVERS;
#		if (not defined $y) {
#			$y = $ZOOVY::MEMCACHESERVERS = YAML::Syck::LoadFile("/httpd/static/memcache.yaml");
#			}
#
#		my $SERVERS = undef;
#		if ($USERNAME ne '') {
#			## a name user (figure out the cluster, use those servers)
#			my $CLUSTER = lc(&ZOOVY::resolve_cluster($USERNAME));
#			$SERVERS = $y->{$CLUSTER};
#			}
#		else {
#			## a global memcache object
#			my @LIST = ();
#			foreach my $CLUSTER (keys %{$y}) {
#				foreach my $s (@{$y->{$CLUSTER}}) {
#					push @LIST, $s;
#					}
#				}
#			$SERVERS = \@LIST;
#			}
#		# print STDERR Dumper($SERVERS);
#		# use Data::Dumper; print Dumper($SERVERS);
#		# if ($CLUSTER eq 'crackle') { return(undef); }
#		# use Data::Dumper; print Dumper($y->{$CLUSTER});
#
#		if (not defined $memd) {
#			$memd = $ZOOVY::EXISTING_MEMCACHE_PTR{ join("|",@{$SERVERS}) };
#			if (defined $memd) {
#				# print STDERR "USED EXISTING!\n";
#				}
#			}
#
#		if (defined $memd) {
#			}
#		elsif (defined $SERVERS) {		
#			# print STDERR "MEMCACHED: ".YAML::Syck::Dump($y->{$CLUSTER})."\n";
#			# $memd = Cache::Memcached->new({
#			$memd = $ZOOVY::EXISTING_MEMCACHE_PTR{ join("|",@{$SERVERS}) } = $ZOOVY::MEMCACHELIB->new({
#				servers => $SERVERS,
#				# enable_compress=>0,
#				compress_threshold => 0,
#				});
#			}
#		}
#	
#
	return($memd);
	}



##
## initializes the client access to a redis database
##
##	db0 = carts, public messages
##	db1 = events	
## db2 = batch jobs & messages, syndication
##
sub getRedis {
	my ($USERNAME,$DB) = @_;

	my $redis = undef;
	my $rediscfg = {};
	$rediscfg->{'socket'} = '/var/run/redis.sock';

	if ($rediscfg->{'socket'}) {
		$redis = Redis->new( sock=>$rediscfg->{'socket'}, encoding=>undef );
		}
	elsif ($rediscfg->{'host'}) {
		my $SERVER = sprintf("%s:%s",$redis->{'host'},$redis->{'port'}|6379);
		## print STDERR "REDIS SERVER: $SERVER\n";
		$redis = Redis->new( server=>$SERVER, reconnect=>15, encoding=>undef );
		}
	else {
		warn "Unknown [redis] settings in /etc/commercerack.ini\n";
		}

	if ((defined $DB) && (defined $redis)) {
		$redis->select($DB);
		}

	return($redis);
	}


######################################################
#@ZOOVY::SKU_ATTRIB_MAP = (
#	[ 'zoovy:supplier_id', 'SUPPLIERID' ],
#	[ 'zoovy:prod_mfgid', 'MFGID' ],
#	[ 'zoovy:prod_upc', 'UPC' ],
#	[ 'amz:asin', 'ASIN' ],
#	);



######################################################################################
##
##
##
sub resolve_lookup_tb {
	my ($USERNAME,$MID) = @_;

	if (&ZOOVY::myrelease($USERNAME)>201338) { return("SKU_LOOKUP"); }
	if (int($MID)==0) { ($MID) = &ZOOVY::resolve_mid($USERNAME); }

	my $TBMID = $MID;
	if ($MID%10000>0) { $TBMID = $MID -($MID % 10000); }		
	my $NEWTB = 'SKU_LOOKUP_'.$TBMID;	
	return($NEWTB);
	}



##
##
##
sub lookup_by_attrib {
	my ($USERNAME,$ATTRIB,$VALUE) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($TB) = &ZOOVY::resolve_lookup_tb($USERNAME);

	my @SKUS = ();
	my ($qtATTR) = $udbh->quote($ATTRIB);
	my ($qtVAL) = $udbh->quote($VALUE);
	my $pstmt = "select PRODUCT,OPTIONSTR from $TB where MID=$MID and ATTR=$qtATTR and VAL=$qtVAL";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($PRODUCT,$OPTIONSTR) = $sth->fetchrow() ) {
		my $SKU = $PRODUCT.(($OPTIONSTR)?":$OPTIONSTR":"");
		push @SKUS, $SKU;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@SKUS);
	}


########################################################


##
## creates a local lock in /var/run
##
sub locklocal {
	my ($LOCKID,$WHOAMI) = @_;
	$LOCKID =~ s/[^\w-]/_/gs;

	my $LOCK = "/var/run/$LOCKID";
	open(LOCK, ">>$LOCK") || die "Cannot open $LOCK: $!\n";
	unless (flock(LOCK,LOCK_EX|LOCK_NB)) {
		print STDERR "$0: Cannot open lock for pid=$$.\n";
      system("/usr/sbin/lsof $LOCK");
      exit 1;
      }
	}

sub memfs { return("/dev/shm"); }
sub tmpfs { return("/tmp"); }


##
##
##
sub lock_appid {
	my ($txt,$calldepth) = @_;

	if (defined $ZOOVY::LOCKAPPID) {
		return($ZOOVY::LOCKAPPID);
		}

	if ((not defined $txt) && ($calldepth == 0)) {
		$txt = ''; $calldepth = 1;
		}

	if ($calldepth == 0) { 
		## leave $txt alone!
		}
	else {
		my ($package,$file,$line,$sub,$args) = caller($calldepth);
		my $server = &ZOOVY::servername();
		$txt = "$txt|$$|$server|$package|$sub|$line";
		}
	$ZOOVY::LOCKAPPID = $txt;
	return($txt);
	}


##
## pass in $prodref (obtained from fetchproduct_as_hashref)
##		and SKU, returns metadata
##
#sub deserialize_skuref {
#	my ($prodref,$sku) = @_;
#	$sku = uc($sku);
#	if (not defined $prodref->{'%SKU'}) {
#		$prodref->{'%SKU'} = {};
#		}
#	if (not defined $prodref->{'%SKU'}->{$sku}) {
#		$prodref->{'%SKU'}->{$sku} = {};
#		}
#	return($prodref->{'%SKU'}->{$sku});
#	}

##
## pass in $prodref, $sku, and new dataref
##
sub serialize_skuref {
	my ($prodref,$sku,$dataref) = @_;

	$sku = uc($sku);
	$prodref->{'%SKU'}->{$sku} = $dataref;
	return();
	}

##
##
##
sub skuarray_via_prodref {
	my ($PID,$prodref) = @_;

	my @SKUS = ($PID);
	if (defined $prodref->{'%SKU'}) {
		@SKUS = keys %{$prodref->{'%SKU'}};
		}
	return(@SKUS);
	}




##
##
##
sub fetchprt {
	my ($USERNAME,$PRT) = @_;

	## for right now: this calls ZWEBSITE::prtinfo -- but eventually this is going to be used 
	## so universally it doens't really belong in zwebsite anymore (and i don't want that as a 
	## long term dependency) - BH 
	##		it will probably also have some type of caching layer.. it's a ready only
	##
	require ZWEBSITE;
	return(&ZWEBSITE::prtinfo($USERNAME,$PRT));
	}


##
## name is self explanatory.
##
sub prt_to_profile {
	my ($USERNAME,$PRT) = @_;
	my ($ref) = &ZOOVY::fetchprt($USERNAME,$PRT);
	return($ref->{'profile'});
	}

##
## returns the partition (PRT) for a given profile.
##
#sub profile_to_prt {
#	my ($USERNAME,$PROFILE) = @_;
#
#	if (($PROFILE eq '') || ($PROFILE eq 'DEFAULT')) {
#		return(0);
#		}
#
#	my ($ref) = &ZOOVY::fetchmerchantns_ref($USERNAME,$PROFILE);
#	return(int($ref->{'prt:id'}));
#	}


##
## writes an entry to the $userdir/access.log
##
sub log {
	my ($USERNAME,$LUSER,$AREA,$MSG,$TYPE) = @_;

	if ($LUSER ne '') {}
	elsif ($ENV{'REMOTE_ADDR'} ne '') { $LUSER = '@'.$ENV{'REMOTE_ADDR'}; }
	else { $LUSER = '*SYSTEM'; }

	require LUSER;
	return(LUSER::log({
		LUSER=>$LUSER,
		USERNAME=>$USERNAME,
		},$AREA,$MSG,$TYPE));
	}


##
## returns 1 for values of Y,1,T,ON
##	returns 0 for values of N,0,F
##
sub is_true {
	my ($VAL,$default) = @_;

	if (not defined $default) { $default = 0; }

	$VAL = uc($VAL); 
	if ($VAL eq '1') { return(1); }
	elsif ($VAL eq 'ON') { return(1); }

	## check for positive numbers
	if (int($VAL)>0) { return(1); }
	
	## now check for YES and TRUE
	$VAL = substr($VAL,0,1);
	if ($VAL eq 'Y') { return(1); }
	elsif ($VAL eq 'T') { return(1); }
	return($default);
	}




##
##
##
sub finish_event_txn {
	my ($USERNAME,$EVENT,$TXN) = @_;

	my ($redis) = &ZOOVY::getRedis($USERNAME,1);
	## NOTE: uses lpush to intentionally moves to the front of the line
	##			but it doesn't seem to work!
	my $result = $redis->eval(qq~
		redis.call('lpush','EVENTS',redis.call('hget','EVENTS.JOURNAL',KEYS[1]));  
		return(redis.call('hdel','EVENTS.JOURNAL',KEYS[1]));
		~,1,$TXN);
	return($result);
	}



##
##
sub add_notify {
	my ($USERNAME,$EVENT,%params) = @_;
	$params{'notify'} = 1;
	return(&ZOOVY::add_event($USERNAME,$EVENT,%params));
	}

sub add_enquiry {
	my ($USERNAME,$EVENT,%params) = @_;
	$params{'notify'} = 1;
	return(&ZOOVY::add_event($USERNAME,$EVENT,%params));
	}

sub add_event {
	my ($USERNAME,$EVENT,%options) = @_;

	if ((not defined $USERNAME) || ($USERNAME eq '')) {
		print STDERR Carp::cluck("INVALID ADD EVENT $EVENT ".Dumper(\%options));
		}


	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my $ID = undef;
	## my $YAML = &ZOOVY::event_to_yaml($USERNAME,$EVENT,%options);

	## EVENT TO YAML
	my %YREF = ();
	if (defined $options{'OID'}) {  
		warn "please pass ORDERID instead of OID\n";
		$options{'ORDERID'} =  $options{'OID'}; 
		}
	elsif (defined  $options{'ORDER_ID'}) {  
		warn "please pass ORDERID instead of ORDER_ID\n";
		$options{'ORDERID'} =  $options{'ORDER_ID'}; 
		}

	my $PRIORITY = 255;
	if (defined $options{'PRIORITY'}) { 
		$PRIORITY = int($options{'PRIORITY'}); 
		}
	elsif ($EVENT =~ /^INV\./o) {
		$PRIORITY = 100;
		}

	if (not defined $options{'PRT'}) { $options{'PRT'} = 0; }
	if (not defined $options{'PID'}) { $options{'PID'} = ''; }
	if (not defined $options{'ORDERID'}) { $options{'ORDERID'} = ''; }

	if (defined $options{'PRT'}) {
		$options{'PRT'} = int($options{'PRT'});
		}
	if (($options{'PID'} eq '') && ($options{'SKU'} ne '')) {
		($options{'PID'}) = &PRODUCT::stid_to_pid($options{'SKU'});
		}

	## the following %options will be copied into YAML
	foreach my $id (
		'CARTID','CID','EMAIL','DST','FEED','NS','PRT','PID','SKU','PIDS','ORDERID','TICKETID','UUID',
		'SRC','SDOMAIN','EBAY','SAFE','IP','was','is','more','title','detail','from','body','link','orderid','notify'
		) {
		if ((defined $options{$id}) && ($options{$id} ne '')) { $YREF{$id} = $options{$id}; }
		}

	$YREF{'_USERNAME'} = $USERNAME;
	$YREF{'_EVENT'} = $EVENT;
	$YREF{'_TS'} = time();

	my $YAML = '';
	if (scalar(keys %YREF)>0) {
		$YAML = YAML::Syck::Dump(\%YREF);
		}
	## END OF EVENT_TO_YAML



	if ((defined $options{'DISPATCH_GMT'}) && ($options{'DISPATCH_GMT'} > time())) {
		##
		## queue a timer for future dispatch!
		##
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my %db_vars = (
			USERNAME=>$USERNAME, MID=>$MID,
			EVENT=>$EVENT,
			PRT=>$options{'PRT'},
			CREATED_GMT=>time(),
			YAML=>$YAML,
			);

		my $pstmt = '';
		## this goes into a timer queue
		if (defined $options{'UUID'}) {
			$db_vars{'UUID'} = $options{'UUID'};
			}
		elsif (defined $options{'ORDERID'}) {
			$db_vars{'UUID'} = $options{'ORDERID'};
			}
		elsif (defined $options{'CARTID'}) {
			$db_vars{'UUID'} = $options{'CARTID'};
			}
		$db_vars{'DISPATCH_GMT'} = $options{'DISPATCH_GMT'};
		$pstmt = &DBINFO::insert($udbh,'USER_EVENT_TIMERS',\%db_vars,sql=>1);
		$udbh->do($pstmt);

		($ID) = $udbh->selectrow_array("select last_insert_id()");
		if ((not defined $ID) || ($ID==0)) {
			open F, ">>/tmp/event-error.sql";
			print F sprintf("/* %s|%s */ %s;\n",$USERNAME,&ZTOOLKIT::pretty_date(time(),2),$pstmt);
			close F;
			}
	
		&DBINFO::db_user_close();
		}
	elsif (1) {

		my ($redis) = &ZOOVY::getRedis($USERNAME,1);
		if (not defined $redis) {
			## FAIL with RECOVERY FILE!
			open F, ">>/tmp/redis-failed.$USERNAME.$options{'PRT'}.$EVENT.".time().".yaml";
			print F $YAML;
			close F;
			$ID = -1;
			}
		elsif ($options{'_TXN'}) {
			($ID) = $redis->hset("EVENTS.JOURNAL",$options{'_TXN'},$YAML);
			}
		elsif ($options{'_PRIORITY_'}) {
			## do a right sided push (goes to the front of line)
			($ID) = $redis->rpush("EVENTS",$YAML);
			if ($ID == 0) { $ID = time(); }
			}
		else {
			($ID) = $redis->lpush("EVENTS",$YAML);
			if ($ID == 0) { $ID = time(); }
			}
		}
	return($ID);
	}





##
## generates the name of a publish file (if it exists)
##
sub pubfile {
	my ($USERNAME,$PRT,$FILE) = @_;

#	my ($package,$file,$line,$sub,$args) = caller(0);
#	print STDERR "USER[$USERNAME:$PRT] PUBFIL[$FILE] from ($package,$file,$line,$sub,$args)\n";

	if (not defined $PRT) { return(''); }
#
#	if ($FILE eq 'finished.txt') {}	## always returns the path to finished.txt if it exists
#
##	return('');
##	if ($USERNAME eq 'secondact') { return(''); }
#	# return('');
#
	$USERNAME = lc($USERNAME);
	my $file = '';
	if (not -d "/local/publish/$USERNAME-$PRT") {
		}
	elsif ($FILE eq '.') {
		## directory exists, we're cool, return a timestamp
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("/local/publish/$USERNAME-$PRT");
		return($ctime);
		}
	else {
		$file = "/local/publish/$USERNAME-$PRT/$FILE";
		return($file);
		}
	}


##
##
##
sub cachefile {
	my ($USERNAME,$FILE) = @_;

	$USERNAME = lc($USERNAME);

#	## certain external systems try to lookup usernames that don't exist.
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#	if ($MID<=0) { return('/dev/null'); }

	## NOTE: it's key that this directory be checked each time in case we nuke the directory while the program is running.
	if (! -d "/local/cache/$USERNAME") {
		mkdir "/local/cache/$USERNAME";
		chown $ZOOVY::EUID,$ZOOVY::EGID, "/local/cache/$USERNAME";
		chmod 0777, "/local/cache/$USERNAME";
		}
	return("/local/cache/$USERNAME/$FILE");	
	}


##
## this is used for cache coherency by the webservers. 
##		it creates/checked a file titled "touched" 
##		if you want to make it a "dirty" touch - it will return the current time.
##		anytime a file which relies upon caching is written, it should call this function
##		since the site caching module will check the directory ONCE to verify it has the
##		latest builds of all files.
## 
sub touched {
	my ($USERNAME,$DIRTY) = @_;

	$USERNAME = lc($USERNAME);

	## quick short circuit
	my $RESULT = undef;

	if ((not $RESULT) && (not $DIRTY)) {
		if ($ZOOVY::TOUCHED_USER eq $USERNAME) {
			$RESULT = $ZOOVY::TOUCHED_TS;
			}
		}

	## print STDERR "TOUCHED\n";
	my $memd = &ZOOVY::getMemd($USERNAME);
	if ((not $RESULT) && (not $DIRTY)) {
		if (defined $memd) {
			$RESULT = $memd->get("$USERNAME.ts");
			}
		}

	my $dir = &ZOOVY::resolve_userpath($USERNAME);
	if ($DIRTY) {	
		## utime below is the same as "touch" command in unix -- bumps mtime on directory
		utime undef,undef,$dir;
		(undef,undef,undef,undef,undef,undef,undef,undef,undef,my $mtime) = stat($dir);
		if (defined $memd) {
			# warn "set memd\n";
			$memd->set("$USERNAME.ts",$mtime);
			}
		$RESULT = $mtime;
		$ZOOVY::TOUCHED_USER = $USERNAME;
		$ZOOVY::TOUCHED_TS = $mtime;
		}

	if (not $RESULT) {	
		(undef,undef,undef,undef,undef,undef,undef,undef,undef,my $mtime) = stat($dir);
		$RESULT = $mtime;
		if (defined $memd) {
			$memd->set("$USERNAME.ts",$mtime);
			}
		$ZOOVY::TOUCHED_USER = $USERNAME;
		$ZOOVY::TOUCHED_TS = $mtime;
		}
	return($RESULT);
	}


sub nuke_product_cache {
	my ($USERNAME,$PRODUCT) = @_;
	$PRODUCT = uc($PRODUCT);

	my $path = &ZOOVY::resolve_userpath($USERNAME);
	require ZWEBSITE;
	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);

	my $nuke_product_cache = 1;
	if (defined $ZOOVY::GLOBAL_CACHE_FLUSH) {
		$nuke_product_cache = $ZOOVY::GLOBAL_CACHE_FLUSH;
		}
	elsif (defined $gref->{'%tuning'}) {
		## tuning parameters can alter behaviors here.
		if (defined $gref->{'%tuning'}->{'auto_product_cache'}) {
			$nuke_product_cache = int($gref->{'%tuning'}->{'auto_product_cache'});
			}
		}

	if ($nuke_product_cache) {
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$path/cache-products-list.bin");
		if ($ctime+60 > time()) {
			warn "Can't re-cache $nuke_product_cache more than once ever 60 seconds settng nuke_product_cache=0\n";
			$nuke_product_cache = 0;
			}
		}


	if ($nuke_product_cache) {
		unlink "$path/cache-products-list.bin";			# products by name
		}

	#if (defined $PRODUCT) {
	#	unlink "$path/PRODUCTS/$PRODUCT.bin";
	#	}
	#else {
	#	## no product specified, delete all product cache
	#	opendir my $D, "$path/PRODUCTS";
	#	while (my $file = readdir($D)) {
	#		next if (substr($file,0,1) eq '.');
	#		unlink "$path/PRODUCTS/$file";
	#		}
	#	closedir($D);
	#	}
	}


################################
##
## ZOOVY::servername
## parameters: nothing
## purpose: returns the server name we're running on (should run just as well from apache or cron)
## accpets: one optional parameter whether to disable the die on inability to determine server name
## returns: returns 'dev','app1','webapi','www1',www2'... or undef if we can't determine the server
## notes: made this function after writing a script/page specific one more than once, figured it
##        would be of use to more than just me
##
#####################################
sub servername {
	my ($disable_die) = @_;

	my $hostname = undef;
	if (defined $ZOOVY::SERVER) {
		return($ZOOVY::SERVER);
		}
	elsif (-f "/proc/sys/kernel/hostname") {
	   $/ = undef;
		open F, "</proc/sys/kernel/hostname";
		$hostname = <F>;
		close F;
		$/ = "\n";
		}
	else {
		$hostname = `/bin/hostname`;
		}

 
	if (index($hostname,'.')>=0) {
		## remove the .zoovy.com or whatever
		$hostname = substr($hostname,0,index($hostname,'.'));
		}

   $hostname =~ s/[^\w\-]+//go;
   $hostname = lc($hostname);
	
	## Bail out if we weren't able to determine the server name
	if ((not defined $hostname) && (not $disable_die)) {
#		print STDERR "ZOOVY::servername(): Unable to determine server name!  Please add into ZOOVY.pm\n";
		}
	$ZOOVY::SERVER = $hostname; ## Set the cache variable in case we're called again
	return $hostname;
}


##
## returns the appropriate product table for a particular user.
##
sub resolve_product_tb {
	my ($USERNAME,$MID) = @_;

	if (&ZOOVY::myrelease($USERNAME)>201338) { return("PRODUCTS"); }

	if (not defined $MID) { $MID = &ZOOVY::resolve_mid($USERNAME); }

	if ($MID == 53062) { return('PRODUCTS_REDFORD'); }
	if ($MID == 60001) { return('PRODUCTS_BAREFOOTTESS'); }

	if (defined $MID) {
		## if we pass an MID then use that to resolve the table.
		if ($MID%1000>0) { $MID = $MID -($MID % 1000); }		
		return('PRODUCTS_'.$MID);
		}
	
	}


##
## returns the numeric equivalent of a merchant_id
## note:
##		$options & 1 == ignore cache file
##		$optiosn & 2 == force lookup on negative number
##			
##	
sub resolve_mid {
	my ($USERNAME,$options) = @_;

	my ($MID,$CLUSTER) = (0,'');
	$USERNAME = uc($USERNAME);
	if ($USERNAME eq '') { return(0); }

	# we'll cache the last MID globally so we don't have to look it up twice.
	if ( (defined $ZOOVY::LAST_MID) && ($ZOOVY::LAST_MIDUSER eq $USERNAME)) {
		if ($ZOOVY::LAST_MID > 0) { return($ZOOVY::LAST_MID); }
		}

	$ZOOVY::LAST_MID = 0;
	$ZOOVY::LAST_MIDUSER = undef;
	if (($options&1)==1) { $ZOOVY::CACHE_LOCALMID = 0; }

	my ($platformref) = &ZOOVY::platformify($USERNAME);
	$MID = int($platformref->{'mid'});
	if ($MID>0) {
		$ZOOVY::LAST_MIDUSER = $USERNAME;
		$ZOOVY::LAST_MID = $MID;
		return($ZOOVY::LAST_MID);
		}

	return(0);
	}


##
## returns the numeric equivalent of a merchant_id
## note:
##		$options & 1 == ignore cache file
##		$optiosn & 2 == force lookup on negative number
##			
##	
sub resolve_cluster {
	my ($USERNAME,$options) = @_;

	my ($MID,$CLUSTER) = (0,'');
	$USERNAME = uc($USERNAME);

	my $IGNORE_CACHE = 0;
	if ((defined $options) && (($options & 2)==2)) { $IGNORE_CACHE = 1; }

	return('localhost');
	}



##
## note: this allows inventoriable product id's and returns a hashref keyed by them
##			as opposed to fetchproducts_into_hashref which only works with pids. -- this is slower.
##			so only use it if necessary.
##
sub fetchskus_into_hashref {
	my ($MERCHANT, $stidref, $pidsref) = @_;
	

	my %lookup = ();	# an array keyed by pid, with each sku that matches it in an array ref. 
							# e.g. $stidref = [ 'pid1'=>['pid1:ABCD','pid1:ABDD'], 'pid2'=>[...] ];
	foreach my $stid (@{$stidref}) {
		my $pid = $stid;
		## NOTE: this line below probably doesn't look right, but don't fucking change it.
		##			basically we need to push both the stid and the sku onto the lookup (assuming:
		##			they're not the same fucking thing) .. so we get both stid, and sku in the return.
		if (index($pid,'@')>0) { $pid = substr($pid,index($pid,'@')+1); }	# virtual stid handling.
		if (index($pid,':')>0) { $pid = substr($pid,0,index($pid,':')); }
		## SANITY: at this point $pid is just the product id.
		push @{$lookup{$pid}}, $stid;
		}

	my @NEED_PIDS = keys %lookup;
	if (not defined $pidsref) {
		}
	elsif (ref($pidsref) ne 'HASH') {
		warn "ignoring pidsref in ZOOVY::fetchsku_into_hashref\n";
		}
	else {
		## if we receive $pidsref, then we don't need to lookup those products (since we already hvae them)
		@NEED_PIDS = ();
		foreach my $pid (keys %lookup) {
			if (defined $pidsref->{$pid}) {
				## we already hvae it.
				}
			else {
				## very bad when this line is reached, things aren't working properly.
				push @NEED_PIDS, $pid;
				}
			}
		}
		
	if ((scalar(@NEED_PIDS)>0) && (ref($pidsref) eq 'HASH')) {
		print STDERR "ZOOVY::fetchskus_into_hashref missed on ".join("|",@NEED_PIDS)." eventhough pidsref was passed (something is amiss)\n";
		print STDERR "caller: ".Carp::cluck()."\n";
		print STDERR "PIDSREF: ".Dumper($stidref,\%lookup,keys %{$pidsref})."\n\n";
		}


		
	my $ref = {};
	if (scalar(@NEED_PIDS)>0) {
		$ref = &ZOOVY::fetchproducts_into_hashref($MERCHANT,\@NEED_PIDS);
		}
	if (defined $pidsref) {
		## merge in pidsref that was passed (which might be the same as fully populate $ref)
		foreach my $pid (keys %{$pidsref}) {
			$ref->{$pid} = $pidsref->{$pid};
			}
		}
	
	##
	## SANITY: at this point $ref has a list of products for all records in $stidref
	##

	foreach my $pid (keys %lookup) {
		my $keep = 0;
		foreach my $stid (@{$lookup{$pid}}) {
			if ($stid eq $pid) { 
				$keep++; 
				}
			else { 
				$ref->{$stid} = $ref->{$pid}; 
				}
			}
		if (not $keep) { delete $ref->{$pid}; }
		}

	return($ref);
	}


##
## accepts: username, and array ref of product id's.
## we can potentially optimize the hell outta this! by going to a multi-select
## Returns $ref which is a datastructure like:
## $ref = { 'foo1'=>{'zoovy:prod_name'=>'data'} };
## becareful, this takes a cart in a lot of places with a claim*sku and it needs to return claim*sku (actually i'm not 100% sure this happens -BH)
##
sub fetchproducts_into_hashref {
	my ($USERNAME, $productarref) = @_;
	$USERNAME = uc($USERNAME);


#	my $cluck = Carp::cluck("fetchskus_into_hashref");
#	if ($cluck !~ /CACHE/s) {
#		print STDER "CLUCK: $cluck\n";
#		}
	my $ref = undef;

	my $MID = &resolve_mid($USERNAME);
	if ($MID==-1) { return({}); }

	my $pdbh 	 = &DBINFO::db_user_connect($USERNAME);

#	my $path = &ZOOVY::resolve_userpath($USERNAME);
#	if (! -d "$path/PRODUCTS") {
#		print STDERR "Making $path/PRODUCTS\n";
#		mkdir "$path/PRODUCTS", 0777;
#		}

	my $memd = undef;

	my $t = time();

	my $mcref = {};
	my @mckeys = ();
	if (defined $memd) {
		foreach my $PID (@{$productarref}) { push @mckeys, uc("$USERNAME:pid-$PID"); }
		$mcref = $memd->get_multi(@mckeys);
		# print YAML::Syck::Dump($mcref);
		}

	## step 0, separate the products into blocks of 20
	my $count = 0;
	my $prodar = ();
	my @blocks = ();
	foreach my $product_id (@{$productarref}) {
		$product_id = uc($product_id);

		my $prodinfo = undef;
		if (defined $mcref->{ uc("$USERNAME:pid-$product_id") }) {	
			## woot found in memcache.
			## print STDERR "!!!!!!!!!!!! $USERNAME FOUND $product_id in multi-get memcache!\n";
			$ref->{$product_id} = $mcref->{ "$USERNAME:pid-$product_id" };
    		}

		if (not defined $prodinfo) {
			if ($count++>10) {
				push @blocks, $prodar;
				$prodar = ();
				$count = 0;
				}
			push @{$prodar}, $product_id;
			}
		}
	push @blocks, $prodar;

	##
	## step 1: build the sql statement and do the query for each block
	##
	foreach my $prodar (@blocks) {
		my $pstmt = '';
		foreach my $product_id (@{$prodar}) {
			$product_id =~ s/[^\w\-\*\@]+//og;
	
			## if the product is a virtual product
			if (index($product_id,'@')>=0) {
				## @ = zoovy@
				## alldropship@ = pull from marketplace default url
				## username@ = pull from remote url

				## strip the @
				if (substr($product_id,0,1) eq '@') { $product_id = substr($product_id,1); }
				}

			## if the product has an external item
			if (index($product_id,'*')>=0) {
				$product_id = substr($product_id,index($product_id,'*')+1);
				}
			$pstmt .= $pdbh->quote($product_id).',';
			}
		chop($pstmt);
		next if ($pstmt eq '');

		my $TB = &resolve_product_tb($USERNAME);
	
		##
		## step 2: run the sql statement, and process the results in $ref
		##
		$pstmt = "select PRODUCT,DATA,CREATED_GMT,TS,PROD_IS,CATEGORY from $TB where MID=$MID and PRODUCT in ($pstmt)";
		my $sth = $pdbh->prepare($pstmt);
		my $rv  = $sth->execute();
		if (not defined $rv) { 
			# print STDERR "ERROR: $pstmt\n";  # sometimes the database times out?
			$sth = $pdbh->prepare($pstmt);
			$rv = $sth->execute();
			}

		while ( my ($product_id,$DATA,$CREATED_GMT,$MODIFIED_GMT,$PROD_IS,$FOLDER) = $sth->fetchrow() ) {


			if (substr($DATA,0,3) eq '---') {
				## detects YAML (way faster than xmlish)
			# 	print "product: $product_id\n";
				$ref->{$product_id} = YAML::Syck::Load($DATA);
				}
			else {
				## does the old xmlish route
				if (utf8::is_utf8($DATA) eq '') {
					$DATA = Encode::decode("utf8",$DATA);
					utf8::decode($DATA);
					}
				my $p = &attrib_handler_ref($DATA);
				$ref->{$product_id} = $p;
				}

			## handle PROD_IS code.
			my @TAGS = ();
			foreach my $isref (@ZOOVY::PROD_IS) {
				# print "$PROD_IS $isref->{'bit'}\n";
				if (($PROD_IS & (1 << $isref->{'bit'})) > 0) {
					
					$ref->{$product_id}->{ $isref->{'attr'} } = 1;
					push @TAGS, $isref->{'tag'};
					}
				}
			$ref->{$product_id}->{'zoovy:prod_is'} = $PROD_IS;
			$ref->{$product_id}->{'zoovy:prod_is_tags'} = join(',',@TAGS);
			$ref->{$product_id}->{'zoovy:prod_created_gmt'} = $CREATED_GMT;
			## 11/18/11 - gkworld was informed 
			$ref->{$product_id}->{'zoovy:prod_modified_gmt'} = $MODIFIED_GMT;
			$ref->{$product_id}->{'zoovy:prod_folder'} = $FOLDER;

			# &ZOOVY::apply_magic_to_productref($USERNAME,$ref->{$product_id});
			$ref->{$product_id}->{'zoovy:prod_rev'} = 3;

			## if it's not in memcache, then multi-get from database.
			if (defined $memd) {
				$memd->set(uc("$USERNAME:pid-$product_id"), $ref->{$product_id} );
				}

			}

		$sth->finish();
		}

	##
	## step 3: verify we didn't miss any products, if we did - then try and find them
	foreach my $product_id (@{$productarref}) {
		next if (defined $ref->{$product_id});

	## commented out 2010/10/02 - if causes products to be deleted from Amazon by returning a dummy product with no amz:ts
	## attribute. the statement does this when it thinks the products no longer exist in the zoovy account. the problem is 
	##	that the code also thinks the products have been deleted when there is a database error and no products are returned. 
	## add a dummy to the list
	#	if (not defined $ref->{$product_id}) {
	#		$ref->{$product_id} = {'zoovy:prod_name' => $product_id, 'zoovy:prod_desc' => 'Product no longer available' };
	#		}

		}


	&DBINFO::db_user_close();
	return($ref);
}



## NOTE: this is also mirrored in PRODUCT.pm
$ZOOVY::PRODKEYS = {
	'zoovy:prod_id'=>'PRODUCT',
	'zoovy:prod_name'=>'PRODUCT_NAME',
	'zoovy:prod_supplier'=>'SUPPLIER',
	'zoovy:prod_supplierid'=>'SUPPLIER_ID',
	'zoovy:prod_salesrank'=>'SALESRANK',
	'zoovy:prod_mfg'=>'MFG',
	'zoovy:prod_mfgid'=>'MFG_ID',
	'zoovy:prod_upc'=>'UPC',
	'zoovy:base_cost'=>'BASE_COST',
	'zoovy:base_price'=>'BASE_PRICE',
	'zoovy:profile'=>'PROFILE',
	'zoovy:prod_is'=>'PROD_IS',
	};

##
## these are stored in the zoovy:prod_is value and expanded/contracted when product is loaded/saved.
##		the value is the bitwise position for a true value.
@ZOOVY::PROD_IS = (
	## system defined.
	{ attr=>'is:fresh', 		'bit'=>0, tag=>'IS_FRESH', panel=>'general', },
	{ attr=>'is:needreview','bit'=>1, tag=>'IS_NEEDREVIEW', panel=>'general' },
	{ attr=>'is:haserrors',	'bit'=>2, tag=>'IS_HASERRORS', panel=>'general' },
	{ attr=>'is:configable','bit'=>3, tag=>'IS_CONFIGABLE', panel=>'flexedit' },
	{ attr=>'is:colorful',	'bit'=>4, tag=>'IS_COLORFUL', panel=>'flexedit' },
	{ attr=>'is:sizeable',	'bit'=>5, tag=>'IS_SIZEABLE', panel=>'flexedit' },
	{ attr=>'is:download',	'bit'=>6, tag=>'IS_DOWNLOAD', panel=>'flexedit' },
	# is:freight ??

	## merchandising tags
	## NOTE: thee xsell panel doesn't automatically update based on 'panel'
	{ attr=>'is:openbox', 	'bit'=>7, tag=>'IS_OPENBOX', panel=>'xsell', },	
	{ attr=>'is:preorder',	'bit'=>8, tag=>'IS_PREORDER', panel=>'xsell', },
	{ attr=>'is:discontinued',	'bit'=>9, tag=>'IS_DISCONTINUED', panel=>'xsell', },
	{ attr=>'is:specialorder',	'bit'=>10, tag=>'IS_SPECIALORDER', panel=>'xsell', },
	{ attr=>'is:bestseller',	'bit'=>11, tag=>'IS_BESTSELLER', panel=>'xsell', },
	{ attr=>'is:sale',		'bit'=>12, tag=>'IS_SALE', panel=>'xsell', },
	{ attr=>'is:shipfree', 	'bit'=>13, tag=>'IS_SHIPFREE', panel=>'xsell', },
	{ attr=>'is:newarrival',	'bit'=>14, tag=>'IS_NEWARRIVAL', panel=>'xsell', },	
	{ attr=>'is:clearance',	'bit'=>15, tag=>'IS_CLEARANCE', panel=>'xsell', },
	{ attr=>'is:refurb', 	'bit'=>16, tag=>'IS_REFURB', panel=>'xsell', },

	## user defined.
	{ attr=>'is:user1', 'bit'=>17, tag=>'IS_USER1', panel=>'flexedit' },
	{ attr=>'is:user2', 'bit'=>18, tag=>'IS_USER2', panel=>'flexedit' },
	{ attr=>'is:user3', 'bit'=>19, tag=>'IS_USER3', panel=>'flexedit' },
	{ attr=>'is:user4', 'bit'=>20, tag=>'IS_USER4', panel=>'flexedit' },
	{ attr=>'is:user5', 'bit'=>21, tag=>'IS_USER5', panel=>'flexedit' },
	{ attr=>'is:user6', 'bit'=>22, tag=>'IS_USER6', panel=>'flexedit' },
	{ attr=>'is:user7', 'bit'=>23, tag=>'IS_USER7', panel=>'flexedit' },
	{ attr=>'is:user8', 'bit'=>24, tag=>'IS_USER8', panel=>'flexedit' },

	## bit 25+ are "can" tags (shared with SKU)
	{ attr=>'can:backorder', 'bit'=>25, 'tag'=>'IS_BACKORDER', panel=>'xsell', },
	{ attr=>'can:offer', 'bit'=>26, 'tag'=>'CAN_OFFER' },
	{ attr=>'can:preorder', 'bit'=>27, 'tag'=>'CAN_PREORDER' },
	{ attr=>'can:return', 'bit'=>28, 'tag'=>'CAN_RETURN' },
	{ attr=>'can:exchange', 'bit'=>29, 'tag'=>'CAN_EXCHANGE' }
	);

@ZOOVY::SKU_CAN = (
	{ attr=>'can:backorder', 'bit'=>25, 'tag'=>'CAN_BACKORDER' },
	{ attr=>'can:offer', 'bit'=>26, 'tag'=>'CAN_OFFER' },
	{ attr=>'can:preorder', 'bit'=>27, 'tag'=>'CAN_PREORDER' },
	{ attr=>'can:return', 'bit'=>28, 'tag'=>'CAN_RETURN' },
	{ attr=>'can:exchange', 'bit'=>29, 'tag'=>'CAN_EXCHANGE' }
	);


##
## ZOOVY INTEGRATIONS TABLE
##	this table contains the official values/constants for marketplaces for all eternity.
## if you edit this table, please maintain order/formatting. 
##	
##	id	: the official "bitstr" position for the marketplace
##	title: the official name
##	dst : is a reference to syndication dst, and if category mapping is performed then that is the key in the navcat meta.
##	attr: that is the attribute that will be used to store the on/off value
##	true:	if 1 then the value will default to on.
##	mask: the order mask (currently orders still use a MKT value)
## meta:	the meta value that should be checked in the order/cart to determine if the order is associated
## sdomain:	the matching sdomain value that should be checked in the order/cart to determine if the order is associated
##	is_web: if true, then sales from this subdomain will be tracked as 'website sales'
##
@ZOOVY::INTEGRATION_GRPS = (
	[ 'WEB', 'Website Sources' ],
	[ 'USR', 'Merchant Generated' ],	
	[ 'CPC',	'Cost-Per-Click' ],
	[ 'DDS', 'Daily Deals Site' ],
	[ 'SOC', 'Social' ],
	[ 'MKT',	'Marketplace Sales' ],
	[ 'AFF',	'Affiliate Sales' ],
	[ 'RMK', 'Remarketing Sales' ],
	[ 'UGH', 'Return/Exchanges - Non Sale' ],
	);

## NOTE: be sure to update order.pm line 439
@ZOOVY::INTEGRATIONS = (
	{ id=>0,		title=>'Website Sale',			dst=>'WEB',												grp=>'WEB',	},
	{ id=>1,		title=>'eBay Auction',			dst=>'EBA', true=>1, 			grp=>'MKT',	mask=>(1<<0)	},
	{ id=>2,		title=>'eBay Fixed Price',		dst=>'EBF', attr=>'ebay:ts', true=>1,	grp=>'MKT',	mask=>(1<<1)	},
	{ id=>3,		title=>'Sears.com',				dst=>'SRS', attr=>'sears:ts', true=>0, 		grp=>'MKT',	mask=>(1<<2), sdomain=>'sears.com', ship_notify=>1	},
	{ id=>4,		title=>'',				dst=>'', true=>0, 								grp=>'',	mask=>0 			}, # AVAILABLE
	{ id=>5,		title=>'Amazon FBA',				dst=>'FBA', attr=>'', true=>0, 					grp=>'USR',	mask=>(1<<4)	},
	{ id=>6,		title=>'Amazon',					dst=>'AMZ', attr=>'amz:ts', true=>0, 			grp=>'MKT',	mask=>(1<<5),	sdomain=>'amazon.com', ship_notify=>1	},
	{ id=>7,		title=>'GoogleBase',				dst=>'GOO', attr=>'gbase:ts', true=>1, 		grp=>'WEB',	mask=>(1<<6),	meta=>'GBASE'		},
	{ id=>7,		title=>'GoogleBase/Froogle',	dst=>'FRG', attr=>'', true=>1, 					grp=>'WEB',	mask=>(1<<6),	meta=>'FROOGLE'		},
	{ id=>8,		title=>'PriceGrabber',			dst=>'PGR', attr=>'pricegrabber:ts', true=>1,grp=>'CPC',	mask=>(1<<7), 	meta=>'PRICEGRAB'	},
	{ id=>8,		title=>'PriceGrabber',			dst=>'', attr=>'', true=>1,						grp=>'CPC',	mask=>(1<<7), 	meta=>'PRICEGRABBER'	},
	{ id=>9,		title=>'ShopZilla',				dst=>'BZR', attr=>'bizrate:ts', true=>1,		grp=>'CPC',	mask=>(1<<8), 	meta=>'BIZRATE'		},
	{ id=>10,	title=>'Shopping.com',			dst=>'SHO', attr=>'shopping:ts', true=>1,		grp=>'CPC',	mask=>(1<<9), 	meta=>'SHOPPING'	},
	{ id=>10,	title=>'Shopping.com',			dst=>'', attr=>'',									grp=>'CPC',	mask=>(1<<9), 	meta=>'DEALTIME'	},
	{ id=>11,	title=>'Overstock Auctions',	dst=>'OAS', attr=>'overstock:ts', true=>0,	grp=>'MKT',	mask=>(1<<10)	},
	{ id=>11,	title=>'Overstock Auctions',	dst=>'OVR', attr=>'', true=>0,					grp=>'MKT',	mask=>(1<<10)	},
	{ id=>12,	title=>'Desktop Client',		dst=>'ZOM',												grp=>'USR',	mask=>(1<<11)	},
	{ id=>13,	title=>'Return/Exchange',		dst=>'UGH', true=>1,									grp=>'UGH', mask=>(1<<12),	 },
	{ id=>14,	title=>'Newsletter Campaign',	dst=>'NEW',												grp=>'WEB',	mask=>(1<<13), meta=>'NEWSLETTER'},
	{ id=>15,	title=>'BuySafe Bonded',		dst=>'BYS',												grp=>'WEB',},	# USED FOR ORDERS ONLY.
#	{ id=>16,	title=>'Bing Shopping',			dst=>'BIN', attr=>'bing:ts', true=>1,			grp=>'CPC',	mask=>(1<<15), meta=>'BINGCB'		},
	{ id=>16,	title=>'Bing Shopping',			dst=>'BIN', attr=>'bing:ts', 						grp=>'CPC',	mask=>(1<<15), meta=>'BING'		},
#	{ id=>16,	title=>'Bing Shopping',			dst=>'', attr=>'', 									grp=>'CPC',	mask=>(1<<15), meta=>'JLYFISH'	},
#	{ id=>16,	title=>'Bing Shopping',			dst=>'', attr=>'', 									grp=>'CPC',	mask=>(1<<15), meta=>'JELLYFISH'	},
#	{ id=>17,	title=>'eBates.com',				dst=>'EBS', attr=>'ebates:ts', true=>0,		grp=>'CPC',	mask=>(1<<16), meta=>'EBATES'		},
	{ id=>18,	title=>'Buy.com',					dst=>'BUY', attr=>'buycom:ts', true=>0,		grp=>'MKT', 	mask=>(1<<17),	sdomain=>'buy.com'	},
#	{ id=>19,	title=>'Veruta',					dst=>'VRT', attr=>'veruta:ts', true=>1,		grp=>'RMK',	mask=>(1<<18), meta=>'VERUTA'		},
	{ id=>19,	title=>'BestBuy',					dst=>'BST', attr=>'bestbuy:ts', true=>1,		grp=>'MKT',	mask=>(1<<18), meta=>'BESTBUY', sdomain=>'bestbuy.com'		},
	{ id=>20,	title=>'Fetchback',				dst=>'FET',	attr=>'', true=>0, 					grp=>'RMK',	mask=>(1<<19), meta=>'FETCHBACK'	},
	{ id=>21,	title=>'Wishpot',					dst=>'WSH', attr=>'wishpot:ts', true=>1,		grp=>'WEB',	mask=>(1<<20), meta=>'WISHPOT'	},
	{ id=>22,	title=>'Wishpot FB Plugin',	dst=>'WFB',	attr=>'', true=>0, 					grp=>'RMK',	mask=>(1<<21), meta=>'WPFACEBOOK'},
	{ id=>23,	title=>'RSS Feed',				dst=>'RSS',	attr=>'', true=>0, 					grp=>'WEB',	mask=>(1<<22),	meta=>'RSS'			},
	{ id=>24,	title=>'NexTag',					dst=>'NXT', attr=>'nextag:ts', true=>1, 		grp=>'CPC',	mask=>(1<<23),	meta=>'NEXTAG'		},
	{ id=>25,	title=>'Amazon Product Ads/CBA',	dst=>'APA', attr=>'amzpa:ts', true=>0, 		grp=>'CPC',	mask=>(1<<24),	meta=>'AMZPA'		},
	{ id=>26,	title=>'HSN.com',					dst=>'HSN', attr=>'hsn:ts', true=>1, 			grp=>'MKT',	mask=>(1<<25), sdomain=>'hsn.com', ship_notify=>1	},
	{ id=>27,	title=>'Smarter.com',			dst=>'SMT', attr=>'smarter:ts', true=>0, 		grp=>'CPC',	mask=>(1<<26), meta=>'SMARTER'	},
	{ id=>28,	title=>'Become.com',				dst=>'BCM', attr=>'become:ts', true=>0, 		grp=>'CPC',	mask=>(1<<27),	meta=>'BECOME'		},
	{ id=>29,	title=>'Pronto',					dst=>'PTO', attr=>'pronto:ts', true=>0, 		grp=>'CPC',	mask=>(1<<28),	meta=>'PRONTO'	},
	{ id=>30,	title=>'TheFind',					dst=>'FND', attr=>'thefind:ts', true=>0, 		grp=>'CPC',	mask=>(1<<29), meta=>'THEFIND'	},
	{ id=>31,	title=>'Doba Supplier',			dst=>'DOB', attr=>'doba:ts', true=>0, 			grp=>'MKT',	mask=>(1<<30),	},
	## bit 32 reserved - otherwise 0xFFFF-1 will exceed the 6 char MKTSTR

	{ id=>33,	title=>'Commission Junction',	dst=>'CJ',	attr=>'cj:ts', true=>1, 			grp=>'AFF',	mask=>0},
	{ id=>34,	title=>'DijiPop.com',			dst=>'DIJ', attr=>'dijipop:ts', true=>0, 		grp=>'AFF',	mask=>0,			meta=>'DIJIPOP'	},
	{ id=>35,	title=>'LinkShare.com',			dst=>'LNK', attr=>'linkshare:ts', true=>0, 	grp=>'AFF',	mask=>0,			meta=>'LINKSHARE' },
	{ id=>36,	title=>'Imshopping.com',		dst=>'IMS', attr=>'imshopping:ts', true=>0, 	grp=>'CPC',	mask=>0,	 		meta=>'IMSHOPPING'},
#	{ id=>37,	title=>'MySimon',					dst=>'MYS', attr=>'mysimon:ts', true=>0, 		mask=>0,	 		},
	{ id=>38,	title=>'IOffer',					dst=>'IOF', attr=>'ioffer:ts', true=>0, 		grp=>'MKT',	mask=>0,			},
	{ id=>39,	title=>'Share-A-Sale',			dst=>'SAS', attr=>'sas:ts', true=>0, 			grp=>'AFF',	mask=>0,	 		meta=>'SAS'			},
	{ id=>40,	title=>'PowerReviews',			dst=>'PRV', attr=>'', 				 				grp=>'WEB',	mask=>0,	 		},
#	{ id=>41,	title=>'Google Site Map',		dst=>'GSM', attr=>'',  								grp=>'WEB',	mask=>0,			},
	{ id=>42,	title=>'Shop.com',				dst=>'SDT', attr=>'',  								grp=>'CPC',	mask=>0,			},
	{ id=>43,	title=>'NewEgg.com',				dst=>'EGG', attr=>'newegg:ts', true=>0,		grp=>'MKT',	mask=>(1<<43),			sdomain=>'newegg.com', ship_notify=>1, }, ## added by patti 2010-12-30 
#	{ id=>44,	title=>'BuySafe Shopping',		dst=>'BSS', attr=>'buysafe:ts', true=>1,		grp=>'WEB',	meta=>'BUYSAFE'	},
#	{ id=>44,	title=>'BuySafe Shopping',		dst=>'BSF',												grp=>'WEB',	},
	{ id=>45,	title=>'Point of Sale',			dst=>'POS', attr=>'', true=>0,					grp=>'USR',	mask=>0,			}, 
	{ id=>46,	title=>'Amazon Repricing',		dst=>'ARP', attr=>'arp:ts', true=>1,			mask=>0,			}, 
	{ id=>47,	title=>'Google Adwords',		dst=>'GAW', attr=>'', grp=>'CPC', 	true=>1,		mask=>0,			}, 
	{ id=>48,	title=>'Turn To',					dst=>'TRN', attr=>'', true=>1,					grp=>'WEB',	mask=>0,			}, 
	{ id=>49,	title=>'',							dst=>'', attr=>'', true=>1,						mask=>0,			}, # AVAILABLE
	{ id=>50,	title=>'',							dst=>'', attr=>'', true=>1,						mask=>0,			}, # AVAILABLE
	{ id=>51,	title=>'User Custom Application 1',	dst=>'US1', attr=>'us1:ts', true=>1,	grp=>'USR', mask=>0,			}, 
	{ id=>52,	title=>'User Custom Application 2',	dst=>'US2', attr=>'us2:ts', true=>1,	grp=>'USR', mask=>0,			}, 
	{ id=>53,	title=>'User Custom Application 3',	dst=>'US3', attr=>'us3:ts', true=>1,	grp=>'USR', mask=>0,			}, 
	{ id=>54,	title=>'User Custom Application 4',	dst=>'US4', attr=>'us4:ts', true=>1,	grp=>'USR', mask=>0,			}, 
	{ id=>55,	title=>'User Custom Application 5',	dst=>'US5', attr=>'us5:ts', true=>1,	grp=>'USR', mask=>0,			}, 
	{ id=>56,	title=>'User Custom Application 6',	dst=>'US6', attr=>'us6:ts', true=>1,	grp=>'USR', mask=>0,			}, 
	{ id=>57,	title=>'Facebook',	dst=>'FBK', attr=>'', true=>1,	grp=>'SOC', mask=>0,			}, 
	{ id=>58,	title=>'Google Plus',	dst=>'GPL', attr=>'', true=>1,	grp=>'SOC', mask=>0,			}, 
	{ id=>59,	title=>'Social (Other)',	dst=>'SOC', attr=>'', true=>1,	grp=>'SOC', mask=>0,			}, 
	{ id=>60,	title=>'GroupOn',	dst=>'GRP', attr=>'', true=>1,	grp=>'DDS', mask=>0,			}, 
	{ id=>61,	title=>'LivingSocial',	dst=>'LVS', attr=>'', true=>1,	grp=>'DDS', mask=>0,			}, 
	{ id=>62,	title=>'Daily Deal Site (Other)',	dst=>'DDS', attr=>'', true=>1,	grp=>'DDS', mask=>0,			}, 
	{ id=>63,	title=>'JEDI/API Order',		dst=>'API',	attr=>'',	grp=>'USR',	mask=>(1<<63),	},
	## bit 64 reserved - otherwise 0xFFFF-1 will exceed the 6 char MKTSTR

	{ id=>65, 	title=>'Amazon Merchant Canada (CA)', dst=>'AUK', attr=>'auk:ts', true=>1, grp=>'MKT', mask=>0 },
	{ id=>66, 	title=>'Amazon Merchant China (CN)', dst=>'ACN', attr=>'acn:ts', true=>1, grp=>'MKT', mask=>0 },
	{ id=>67, 	title=>'Amazon Merchant Germany (DE)', dst=>'ADE', attr=>'ade:ts', true=>1, grp=>'MKT', mask=>0 },
	{ id=>68, 	title=>'Amazon Merchant France (FR)', dst=>'AFR', attr=>'afr:ts', true=>1, grp=>'MKT', mask=>0 },
	{ id=>69, 	title=>'Amazon Merchant Italy (IT)', dst=>'AIT', attr=>'ait:ts', true=>1, grp=>'MKT', mask=>0 },
	{ id=>70, 	title=>'Amazon Merchant Japan (JP)', dst=>'AJP', attr=>'ajp:ts', true=>1, grp=>'MKT', mask=>0 },
	{ id=>71, 	title=>'Amazon Merchant United Kingom (UK)', dst=>'AUK', attr=>'auk:ts', true=>1, grp=>'MKT', mask=>0 },

# EBAY SITE CODES:
#US (0) United States
#CA (2) Canada
#UK (3) United Kingdom
#AU (15) Australia
#AT (16) Austria
#BEFR (23) Belgium (French)
#FR (71) France
#DE (77) Germany
#Motors (100) US eBay Motors
#IT (101) Italy
#BENL (123) Belgium (Dutch)
#NL (146) Netherlands
#ES (186) Spain
#CH (193) Switzerland
#HK (201) Hong Kong
#IN (203) India
#IE (205) Ireland
#MY (207) Malaysia
#CAFR (210) Canada (French)
#PH (211) Philippines
#PL (212) Poland
#SG (216) Singapore

	

	## Groupon, LivingSocial
#	{ id=>49,	title=>'User App1',				dst=>'US1', attr=>'user1:ts', true=>1,			mask=>0,			}, 
#	{ id=>50,	title=>'eBay Auction',			dst=>'EPW', attr=>'epw:ts', true=>0,			grp=>'MKT',	mask=>0,			}, 
#	{ id=>50,	title=>'eBay Fixed',				dst=>'EPW', attr=>'epw:ts', true=>0,			grp=>'MKT',	mask=>0,			}, 
#	{ id=>50,	title=>'eBay Powerlister/Fixed',		dst=>'EPW', attr=>'epw:ts', true=>0,			grp=>'MKT',	mask=>0,			}, 
#	{ id=>50,	title=>'eBay Powerlister/Auction',		dst=>'EPW', attr=>'epw:ts', true=>0,			grp=>'MKT',	mask=>0,			}, 
	##
	## NOTE: id's up to 64 require 12 bytes
	##			id's up to 96 require 16 bytes 
	##			
	);


##
## returns an integration record, you can search by 'dst'=> or 'id'=>
##
sub fetch_integration {
	my (%options) = @_;

	my ($key,$value) = ('','');
	if ($options{'dst'}) { $key = 'dst'; $value = $options{'dst'}; }
	elsif ($options{'id'}) { $key = 'id'; $value = $options{'id'}; }

	my $result = undef;
	foreach my $intref (@ZOOVY::INTEGRATIONS) {
		next if (defined $result);
		if ($intref->{$key} eq $value) { $result = $intref; }
		}
	
	return($result);
	}

#########################
##
## this is used to create the META_MKT value in the INVENTORY table, and also the MKT value in the product table.
##		shit: this list *NEEDS* to be kept in sync with SYNDICATION.pm and ORDER.pm
##
## 8442851 = 100000001101001111100011
## 
#%ZOOVY::MKT_BITVAL = (
#	'ebay:ts'=>[(1<<0),1,'eBay'],
#	'ebaystores:ts'=>[(1<<1),1,'eBay Stores'],
#	'sears:ts'=>[(1<<2),0,'Sears.com'],
##	'amz:ts'=>[(1<<4),0,'Amazon FBA'],	
#	'amz:ts'=>[(1<<5),0,'Amazon'],
#	'gbase:ts'=>[(1<<6),1,'GoogleBase'],
#	'pricegrabber:ts'=>[(1<<7),1,'PriceGrabber'],
#	'bizrate:ts'=>[(1<<8),1,'ShopZilla',],
#	'shopping:ts'=>[(1<<9),1,'Shopping.com'],
#	'overstock:ts'=>[(1<<10),0,'Overstock Auctions'],
#	'yshop:ts'=>[(1<<12),1,'Yahoo Shopping'],
#	'buysafe:ts'=>[(1<<14),1,'BuySafe Shopping'],
#	'bing:ts'=>[(1<<15),1,'Bing Shopping'],  
#	'buycom:ts'=>[(1<<17),0,'Buy.com'],
#	'nextag:ts'=>[(1<<23),1,'NexTag'],		
#	'amzpa:ts'=>[(1<<24),1,'Amazon Product Ads'],
#	'hsn:ts'=>[(1<<25),1,'HSN.com'],
#	'smarter:ts'=>[(1<<27),0,'Smarter.com'],
#	'become:ts'=>[(1<<27),0,'Become.com'],
#	'pronto:ts'=>[(1<<28),0,'Pronto'],
#	'thefind:ts'=>[(1<<29),0,'TheFind'],
#	'doba:ts'=>[(1<<30),0,'Doba Supplier'],
#	);


##
## returns a hashref of products and timestamps which are allowed for a particular marketplace
##		pass USERNAME,ebaystores:ts for example
## 
## %options
##		V=0 - version 1 - returns a hashref keyed by sku, value is timestamp
##		V=1 - version 2 - returns a hashref keyed by sku, value is an arrayref [ ts, options ]
sub syndication_pids_ts {
	my ($USERNAME,$attrib,%options) = @_;

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &resolve_product_tb($USERNAME);

	## --mysql directives--
	## SQL_BIG_RESULT:  can be used with GROUP BY or DISTINCT to tell the optimizer that the result set has many rows. In this case, MySQL directly uses disk-based temporary tables if needed, and prefers sorting to using a temporary table with a key on the GROUP BY elements. 
	## SQL_BUFFER_RESULT: forces the result to be put into a temporary table. This helps MySQL free the table locks early and helps in cases where it takes a long time to send the result set to the client. This option can be used only for top-level SELECT  statements, not for subqueries or following UNION. 
	my $pstmt = "select SQL_BIG_RESULT SQL_BUFFER_RESULT PRODUCT,TS,OPTIONS from $TB where MID=$MID /* $USERNAME */";
	if (defined $attrib) {
		# $pstmt .= " and (MKT & $bitmask)>0 ";
		my @IDS = ();
		foreach my $intref (@ZOOVY::INTEGRATIONS) {
			if ($intref->{'attr'} eq $attrib) { push @IDS, $intref->{'id'}; }
			}
		if (scalar(@IDS)>0) {
			$pstmt .= " and /* $attrib */ ".&ZOOVY::bitstr_sql("MKT_BITSTR",\@IDS);
			}
		}  
	if (defined $options{'pogs'}) {
		$pstmt .= " and (OPTIONS&4)=".(($options{'pogs'})?4:0);
		}
	if (defined $options{'since'}) {
		$pstmt .= " and TS>=".int($options{'since'});
		}
	if (defined $options{'parent'}) { 
		$pstmt .= " and (OPTIONS&256)=".(($options{'parent'})?256:0);
		}
	if (defined $options{'child'}) { 
		$pstmt .= " and (OPTIONS&512)=".(($options{'child'})?512:0);
		}
	if (defined $options{'folder'}) {
		if (substr($options{'folder'},0,1) ne '/') { $options{'folder'} = "/$options{'folder'}"; }
		$pstmt .= " and CATEGORY=".$udbh->quote($options{'folder'});
		}
#	print $pstmt."\n";

	my $V = int($options{'V'});
	
	my $result = {};
	print STDERR $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	my ($rv) = $sth->execute();
	if (not defined $rv) {
		$result = undef;
		&ZOOVY::confess($USERNAME,"syndication_pid_ts return zero results",justkidding=>1);
		}

	if (defined $result) {
		while ( my ($PID,$TS,$OPTIONS) = $sth->fetchrow() ) {
			if ($V == 0) {
				## version 0: ts scalar
				$result->{$PID} = $TS;
				}
			elsif ($V==1) {
				## Version 1: array of ts, option
				$result->{$PID} = [ $TS, $OPTIONS ];
				}
			else {
				ZOOVY::confess($USERNAME,"Unknown version $V requested");
				}
			}
		$sth->finish();
		}
	&DBINFO::db_user_close();

	return($result);
	}



#@ZOOVY::SKU_MKTRP_IS = (
#	[ '$KEY:is_enabled', 'ENABLED', 1<<0 ],
#	[ '$KEY:is_unleashed', 'UNLEASHED', 1<<1 ],
#	[ '$KEY:is_paused', 'PAUSED', 1<<2 ],
#  [ '$KEY:is_waiting_for_update', 'NEEDS_UPDATE', (1<<15) ],
#  [ '$KEY:is_unhappy', 'UNHAPPY', 1<<3  ],
#  [ '$KEY:is_angry', 'ANGRY', 1<<4 ],
#  [ '$KEY:is_winning', 'WINNING' ],
#  [ '$KEY:is_losing', 'LOSING' ],
#	);

##
## note: this takes either a skuref, or prodref (honey badger doesn't give a shit)
##		and creates the right value for a set('ENABLED','UNLEASHED','PAUSED','UNHAPPY','ANGRY','WINNING','LOSING')
##		
#sub skulookup_compile_IS_value {
#	my ($ref,$key) = @_;
#	my $i = 0;
#	
#	## USER CONTROLLED PORTION (never updated by RP app)
#	if ($ref->{"$key:is_enabled"}) { $i |= (1<<0); }
#	if ($ref->{"$key:is_unleashed"}) { $i |= (1<<1); }
#	if ($ref->{"$key:is_paused"}) { $i |= (1<<2); }
#
### NOTE: these values are ONLY set by the repricing app
##	if ($ref->{"$key:is_unhappy"}) { $i |= (1<<3); }
##	if ($ref->{"$key:is_angry"}) { $i |= (1<<4); }
##	if ($ref->{"$key:is_winning"}) { $i |= (1<<5); }
##	if ($ref->{"$key:is_losing"}) { $i |= (1<<6); }
#	$ref->{"$key:is"} = $i;
#
#	return($i);
#	}



##
## inserts an item at the end of a list of items, only if the item doesn't appear 
##	ex1.:	csv=abc,def,ghi 	value=xyz	would produce: abc,def,ghi,xyz
##		perl -e 'use lib "/backend/lib"; use ZOOVY; print ZOOVY::csv_insert("abc,def,ghi","xyz");'
##	ex2.: csv=abc,def,ghi	value=abc	would product: abc,def,ghi
##
## preserves sorted order of array.
##
sub csv_insert {
	my ($csv,$value) = @_;

	my $found = 0;
	foreach my $item (split(/,/,$csv)) {
		next if (($item eq '') || ($found));
		if ($value eq $item) { $found++; }
		}
	if (not $found) {
		if ($csv eq '') { $csv = $value; } else { $csv .= ','.$value; }
		}
	return($csv);
	}


###########################
##
## ZOOVY::build_prodinfo_refs
##
## parameters: USERNAME
## returns: a reference to a hash which contains all the timestamps for all products
##
sub build_prodinfo_refs {
	my ($USERNAME) = @_;

	my %tshash  = ();
	my %cathash = ();

	my $MID = &resolve_mid($USERNAME);
	my $TB = &resolve_product_tb($USERNAME);

	my $udbh 	 = &DBINFO::db_user_connect($USERNAME);

	my $pstmt = "select SQL_BIG_RESULT SQL_BUFFER_RESULT PRODUCT,TS,CATEGORY from $TB where MID=" . $udbh->quote($MID);
	# my $pstmt = "select PRODUCT,TS,CATEGORY from $TB where MID=" . $udbh->quote($MID);
	my $sth   = $udbh->prepare($pstmt);
	my $rv    = $sth->execute();
	while (my ($prod, $ts, $cat) = $sth->fetchrow()) {
		$tshash{$prod}  = $ts;
		$cathash{$prod} = $cat;
		}
	&DBINFO::db_user_close();
	return (\%tshash, \%cathash);
	} ## end sub build_prodinfo_refs


###########################
## ZOOVY::resolve_userpath
## parameters: a USERNAME
## returns: a directory to the ROOT of a users directory
##
sub resolve_userpath {
	my ($USERNAME,$NOASYNC,$CLUSTER) = @_;

	$USERNAME = lc($USERNAME);
	
	if ($USERNAME eq '') {
		warn "called resolve_userpath on blank username\n";
		return("/tmp");
		}

	return("/users/$USERNAME");
	}



##############
##
# ZOOVY::fetchproducts_by_name
#
# parameters: USERNAME
# returns: a hash of products keyed by code, with name = value
# note: needs a performance bump!
##
##############
sub fetchproducts_by_name { return(%{&fetchproducts_by_nameref(@_)}); }
sub fetchproducts_by_nameref {
	my ($USERNAME, %options) = @_;
	my %hash = ();

	my $use_cache = 1;
	if ((defined $options{'prod_is'}) && ($options{'prod_is'}>0)) { $use_cache = 0; }
	if ((defined $options{'mkt'}) && ($options{'mkt'}>0)) { $use_cache = 0; }

#	require ZWEBSITE;
#	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
#	if (defined $gref->{'%tuning'}) {
#		if (defined $gref->{'%tuning'}->{'auto_product_cache'}) {
#			if (int($gref->{'%tuning'}->{'auto_product_cache'})==0) {
#				$use_cache = 2;
#				}
#			}		
#		}	

#	if ($USERNAME eq 'redford') { 
#		return({});
#		}
	
	my $path = &ZOOVY::resolve_userpath($USERNAME);
	if (($use_cache) && (-f "$path/cache-products-list.bin")) {
		my $ref = eval { retrieve "$path/cache-products-list.bin"; };
		if (scalar(keys %{$ref})==0) { $ref = undef; }
		if (defined $ref) { return($ref); }
		else { &nuke_product_cache($USERNAME); }
		}


	#if ($USERNAME eq 'redford') {
	#	## not allowed
	#	}
	if ($use_cache<2) {
		my $MID = &resolve_mid($USERNAME);

		my $udbh 	 = &DBINFO::db_user_connect($USERNAME);
		my $TB = &resolve_product_tb($USERNAME);

		# my $pstmt = "select SQL_BIG_RESULT SQL_BUFFER_RESULT PRODUCT,PRODUCT_NAME from $TB where MID=$MID";
		my $pstmt = "/* NAMEREF */ select PRODUCT,PRODUCT_NAME from $TB where MID=$MID";
		if ((defined $options{'prod_is'}) && ($options{'prod_is'}>0)) {
			my $prod_is = int($options{'prod_is'});
			$pstmt .= " and ((PROD_IS & $prod_is)=$prod_is) ";
			}
		if ((defined $options{'mkt'}) && ($options{'mkt'}>0)) {
			my $mkt = int($options{'mkt'});
			$pstmt .= " and ((MKT & $mkt)=$mkt) ";
			}

		print STDERR $pstmt."\n";
		my $sth   = $udbh->prepare($pstmt);
		$sth->execute();
		while (my ($product, $productname) = $sth->fetchrow()) { 
			if (utf8::is_utf8($productname) eq '') {
				$productname = Encode::decode("utf8",$productname);
				utf8::decode($productname);
				}		
			$hash{uc($product)} = $productname; 
			}
		$sth->finish();
		&DBINFO::db_user_close();

		if ($use_cache>0) {
			my $success = eval { Storable::nstore \%hash, "$path/cache-products-list.bin"; };
			unless ($success) { &nuke_product_cache($USERNAME); }
			}
		}

	return (\%hash);
	} ## end sub fetchproducts_by_name



#########
#
# ZOOVY::incode_by_ref
# parameters: reference to a buffer that needs to be encoded
# returns: 0
#
#############
sub incode_by_ref {
	my ($BUFREF) = @_;

	${$BUFREF} = &incode(${$BUFREF});
	return (0);
	}

##########
#
# ZOOVY::dcode_by_ref
#
# parameters: reference to a buffer that needs to be decoded.
# returns: 0
#
###########
sub dcode_by_ref {
	my ($BUFREF) = @_;

	${$BUFREF} = &dcode(${$BUFREF});
	return (0);
	}
	
#########
#
# ZOOVY::incode
# parameters: a buffer that needs to be encoded
# returns: $BUFFER
#
#############
sub incode {
	my ($BUFFER) = @_;

	# we should consider doing a double encode check here.

	if (not defined($BUFFER)) { 
		## GIGO
		}
	elsif ($BUFFER =~ /[\&\>\<\"]/o) {
		## a lot of strings don't need encoding, so we use the regex above because overall it's faster
		$BUFFER =~ s/\&/\&amp\;/ogs;
		$BUFFER =~ s/\>/\&gt\;/ogs;
		$BUFFER =~ s/\</\&lt\;/ogs;
		$BUFFER =~ s/\"/\&quot\;/ogs;
		}

	return ($BUFFER);
	}

#########
#
# ZOOVY::encode_ref
# note: unlike it's retarded cousin incode and incode_by_ref this one will support double encoding
# parameters: a buffer that needs to be encoded
# returns: $BUFFER
#
#############
sub encode_ref {
	my ($BUFFERREF) = @_;

	# we should consider doing a double encode check here.

	if (not defined($BUFFERREF)) { return undef; }    # GIGO
	if (length(${$BUFFERREF}) <= 0) { return ($BUFFERREF); }

	${$BUFFERREF} =~ s/\&/\&amp\;/ogs;
	${$BUFFERREF} =~ s/\>/\&gt\;/ogs;
	${$BUFFERREF} =~ s/\</\&lt\;/ogs;
	${$BUFFERREF} =~ s/\"/\&quot\;/ogs;

	return ($BUFFERREF);
	}

##########
#
# ZOOVY::dcode
#
# parameters: a buffer that needs to be decoded.
# returns: $BUFFER
#
###########
sub dcode
{
	my ($BUFFER) = @_;

	if (!defined($BUFFER)) { return undef; }
	$BUFFER =~ s/\&gt\;/\>/ogs;
	$BUFFER =~ s/\&lt\;/\</ogs;
	$BUFFER =~ s/\&quot\;/\"/ogs;
	$BUFFER =~ s/\&amp\;/\&/ogs;
	# $BUFFER =~ s/\&#47;/\//g;

	return ($BUFFER);
}

#######
#
# ZOOVY::calc_modifier
# PURPOSE: computes a modified price
#
# PARAMETERS: price, modifier, [1 = return total+modified, 0=return modified]
#
# defaults to addition as the modifier
# defaults to dollars as the modifier
#
######
sub calc_modifier {
	my ($price, $modifier, $add) = @_;

	# Add determines whether we return the price with the difference already worked in
	# or just the difference in cost.  In other words $add means automatically add on the
	# adjustment to the price when this function returns.  This function didnt have this
	# behavior until now, so I left the default as adding automatically.
	if (not defined $add) { $add = 1; }
	if ((not defined $price)    || ($price    eq '')) { $price    = 0; }    # Keep perl form whining, added by AK 1/9/02
	if ((not defined $modifier) || ($modifier eq '')) { $modifier = 0; }    # Keep perl form whining, added by AK 1/9/02

	$price =~ s/[^0-9\.\-]+//ogs;    # strip everything except 0-9 and .
	if ($modifier !~ m/[0-9]/o) { $modifier = "+0.00"; }    # If its still non-numeric (i.e., doesn't have ANY numbers), make it zero
	$price = sprintf("%.2f", $price);                # Make it look like a real money number :)


	if (!defined $modifier) { $modifier = '+0.00'; }
	#print STDERR "MODIFIER: $modifier\n";

	my ($format, $operation);
	if (index($modifier, '%') >= 0) { $format = '%'; }
	else { $format = '$'; }

	if (index($modifier, '-') >= 0) { $operation = '-'; }
	elsif (substr($modifier,0,1) eq '=') { $format = '='; }
	else { $operation = '+'; }

	$modifier =~ s/[^0-9\.\-]//ogs;                     # strip everything except 0-9 and .
	if ($modifier !~ m/[0-9]/o) { $modifier = 0; }    # If its still non-numeric (i.e., doesn't have ANY numbers), make it zero

	my $difference = 0;
	if ($format eq "%") {
		if ($operation eq "-") { $difference -= ($price * ( (0-$modifier) / 100)); }
		elsif ($operation eq "+") { $difference += ($price * ($modifier / 100)); }
		}
	elsif ($format eq '$') {
		# modifier will be a negative number
		$difference += $modifier; 
		}
	elsif ($format eq '=') {
		$difference = $modifier;
		$price = 0;
		}
	# Make sure what we're outputting good lookin' stuff
	$difference = sprintf("%.2f", $difference);
	my $pretty = sprintf("%.2f", $modifier);

	if ($add) { return ($price + $difference), $pretty; }
	else { return $difference, $pretty; }

} ## end sub calc_modifier

##############################################
##
## calc_producthash_totals
##
## parameters: reference to a product hash, tax_rate (optional)
## note: the product hash is expected to resemble:
##   KEY = SKU
##   VALUE = comma separated string in the following format: price,quantity,weight,tax
##               
## note2: tax should be either a Y|y or an N|n, it is case insensitive for your pleasure.
## note3: if you send anything in the value after tax it will be handled and ignored
##        this means you can send the hash directly from ZORDER::fetchorder_contents_as_hash
##        and CART->shipping()
##
## returns: (sub total, total weight, total tax, item count)
##
## note4: if no tax rate was passed, then no tax will be returned ("")
## note5: in case you didn't know, subtotal is the sum of all extended prices, before tax and shipping.
##
###############################################
sub calc_producthash_totals
{
	my ($hashref, $taxrate, $skipdiscounts) = @_;

#	my ($package, $filename, $line) = caller;
#	print STDERR "ZOOVY::calc_producthash_totals($hashref, $taxrate, $skipdiscounts) called from $package, $filename, $line\n";

	if (not defined $skipdiscounts) { $skipdiscounts = 0; }
	# if the taxrate is bogus, set it to zero...  did this 'cause of dividing by uninitialized value errors in the apache error log
	if ((not defined $taxrate) || ($taxrate eq '') || ($taxrate !~ m/[0-9]*\.?[0-9]*/)) { $taxrate = 0; }
	my $subtotal     = 0;
	my $totalweight  = 0;
	my $totaltax     = 0;
	my $totaltaxable = 0;
	my $itemcount    = 0;
	foreach my $key (keys %{$hashref})
	{
		# if you don't know what this does, then perhaps you shouldn't be editing it eh?
		# remember that several other modules, including ZSHIPRULES interact with the cart format.
		# added BH 9/3
		next if ($skipdiscounts && (substr($key, 0, 1) eq '%'));
		my ($price, $quantity, $weight, $tax) = split (',', ${$hashref}{$key}, 5);
		# There was much complaining happening regarding undefined/non-numeric values
		# in the error logs so I defaulted these to equivalents
		if ((not defined $price)    || ($price eq ''))     { $price = 0; }
		if ((not defined $quantity) || ($quantity eq ''))  { $quantity = 0; }
		if ((not defined $weight)   || ($weight eq ''))    { $weight = 0; }
		if ((not defined $tax)      || ($tax eq ''))       { $tax = 'Y'; }
		
		if (index($weight, '#') > 0)
		{
			my ($lbs, $oz) = split ('#', $weight);
			$lbs =~ s/[^0-9]//og;
			$oz  =~ s/[^0-9]//og;
			if ($lbs eq '') { $lbs = 0; }
			if ($oz  eq '') { $oz  = 0; }
			$weight = ($lbs * 16) + $oz;
		}

		my $extended = ($price * $quantity);
		$subtotal += sprintf("%.2f", $extended);
		# If tax starts with a Y
		#	print STDERR "TAXIS: $tax EXTENDED: $extended\n";
		if (substr(uc($tax), 0, 1) eq 'Y') { $totaltaxable += sprintf("%.2f", $extended); }
		$totalweight += ($quantity * $weight);
		# handle hidden items and discounts
		if ((substr($key, 0, 1) ne "!") && (substr($key, 0, 1) ne '%')) { $itemcount += $quantity; }
	} ## end foreach my $key (keys %{$hashref...
	$totaltax = sprintf("%.2f", ($taxrate / 100) * $totaltaxable);
	return ($subtotal, $totalweight, $totaltax, $totaltaxable, $itemcount);
} ## end sub calc_producthash_totals

sub sslify
{
	my ($STRING) = @_;

	$STRING =~ s/^http:/https:/oi;

	return ($STRING);
}


sub products_count {
	my ($USERNAME) = @_;

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &resolve_mid($USERNAME);
	my $TB = &resolve_product_tb($USERNAME);

	my $pstmt = "select count(*) from $TB where MID=".$udbh->quote($MID);
	print STDERR $pstmt."\n";
	my ($count) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();
	return($count);
	}

##########################################
##
## builduniqueproductid
##
##
##########################################
sub builduniqueproductid
{
	my ($USERNAME, $PID) = @_;
	my $ATTEMPT = 1;
	my $NEW_ID = $PID;
	$NEW_ID =~ s/[^\w\-]+//igso;
	$NEW_ID = uc(substr($NEW_ID, 0, 4));

	my $attempt = 0;
	&DBINFO::db_user_connect($USERNAME);
	my $EXISTS = 1;
	while ($EXISTS) {
		my $PRODUCT_ID = $NEW_ID . (++$attempt);
		if (&productidexists($USERNAME, $PRODUCT_ID)) { $EXISTS = 1; }
		else { $EXISTS = 0; }
		}
	&DBINFO::db_user_close();

	return ($NEW_ID . $attempt);
} ## end sub builduniqueproductid

##
## returns: 0 no , 1 yes
## added cache support 11/17/03
##
sub productidexists {
	my ($USERNAME, $PRODUCT_ID, %options) = @_;

	my $RESULT = undef;
	$PRODUCT_ID = uc($PRODUCT_ID);

	#my $INV_SKU = undef;
	#if (index($PRODUCT_ID,':')>0) {
	#	$INV_SKU = substr($PRODUCT_ID,index($PRODUCT_ID,':'));
	#	$PRODUCT_ID = substr($PRODUCT_ID,0,index($PRODUCT_ID,':'));
	#	}


	require ZWEBSITE;
	my $use_cache = 1;
	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
	if (defined $gref->{'%tuning'}) {
		if (defined $gref->{'%tuning'}->{'auto_product_cache'}) {
			$use_cache = int($gref->{'%tuning'}->{'auto_product_cache'});
			}
		}


	if ($use_cache) {
		my $path = &ZOOVY::resolve_userpath($USERNAME);
		# print STDERR "$path/cache-products-list.bin\n";
		if (-f "$path/cache-products-list.bin") {
			my $ref = eval { retrieve "$path/cache-products-list.bin"; };
			if (scalar(keys %{$ref})==0) { $ref = undef; }
			if (defined $ref) { 
				if (defined $ref->{$PRODUCT_ID}) {	$RESULT = 1; } else { $RESULT = 0; }
				}
			else { 
				&nuke_product_cache($USERNAME); 
				}
			}
		}

	if (not defined $RESULT) {
		my $udbh 	 = &DBINFO::db_user_connect($USERNAME);
		my $MID = &resolve_mid($USERNAME);
		my $TB = &resolve_product_tb($USERNAME);

		my $pstmt = "select count(*) from $TB where MID=".$udbh->quote($MID)." and PRODUCT=".$udbh->quote($PRODUCT_ID);
		print STDERR "$pstmt\n";
		my $sth   = $udbh->prepare($pstmt);
		$sth->execute();
		($RESULT) = $sth->fetchrow();
		$sth->finish();
		&DBINFO::db_user_close();
		}

	#if ($RESULT==0) {
	#	## the product itself doesn't exist 
	#	}
	#elsif (defined $INV_SKU) {
	#	## this means we have an inventoriable product option to check on as well.
	#	my ($prodref) = &ZOOVY::fetchproduct_as_hashref($USERNAME,$PRODUCT_ID);
	#	if (not &POGS::validate_invsku($USERNAME,$prodref,$INV_SKU)) { $RESULT = 0; }
#
#
#		#require POGS;
#		#my ($txt) = &ZOOVY::fetchproduct_attrib($USERNAME,$PRODUCT_ID,'zoovy:pogs');
#		## print STDERR "TXT: $txt\n";
#		#if (not POGS::validate_invsku($USERNAME,$PRODUCT_ID,$txt,$INV_SKU)) { $RESULT = 0; }
#		}

	return ($RESULT);
} ## end sub productidexists

##########################################
## 
## ZOOVY::saveproduct_attrib
## parameters: $MERCHANT_NAME, $PID, $ATTRIBUTE, $VALUE
##
## note: doesn't actually save yet.
##       needs a saveproduct_data
##############################################
#sub saveproduct_attrib {
#	my ($MERCHANT, $PRODUCT, $ATTRIBUTE, $VALUE) = @_;
#
#	if (!defined($PRODUCT) || !defined($MERCHANT)) {
#		#print STDERR "ERROR: saveproduct_attrib called MERCHANT=[$MERCHANT] PRODUCT=[$PRODUCT] ATTRIB=[$ATTRIBUTE]\n";
#		return (1);
#		}
#
# 	$PRODUCT = uc($PRODUCT);
#	my $Pref = &ZOOVY::fetchproduct_as_hashref($MERCHANT,$PRODUCT);
#   if (not defined $VALUE) {
#      delete $Pref->{$ATTRIBUTE};
#      }
#   else {
#      $Pref->{$ATTRIBUTE} = $VALUE;
#      }
#	&ZOOVY::saveproduct_from_hashref($MERCHANT,$PRODUCT,$Pref);
#
#	return (0);
#	} ## end sub saveproduct_attrib

############################################
##
## ZOOVY::fetchproduct_attrib
##
## parameters: $MERCHANT_NAME, $PID, $ATTRIBUTE
##
## note: if product is not found it returns at undef
## returns: value
## AS OF 4/21/01: this returns undef instead of '' on failure. '' means '' was the value.
## AS OF 4/21/01: this is now CASE SENSITIVE
## AS OF 4/22/01: now tries to be case insensitive, and is backward compatible (on failure)
##
##
###############################################
#sub fetchproduct_attrib {
#	my ($MERCHANT, $PRODUCT, $ATTRIBUTE) = @_;
#
#	# Sanity!
#	if (!defined($PRODUCT)) { return undef; }
#
#	# Sanity check.
#	$PRODUCT =~ s/ /_/igo;
#	$ATTRIBUTE = lc($ATTRIBUTE);
#
#	my $PREF = &fetchproduct_as_hashref($MERCHANT, $PRODUCT);
#	# use Data::Dumper; print STDERR Dumper($PREF);
#	return($PREF->{$ATTRIBUTE});
#	} 



sub attrib_handler_ref {
   my ($BUFFER,$HASHREF) = @_;
   require ZTOOLKIT;
   if (not defined $HASHREF) {
      $HASHREF = {};
      }
   return(&ZTOOLKIT::xmlish_to_hashref($BUFFER, 'lowercase'=>'1', 'tag_match'=>qr/\w+:\w+/, 'use_hashref'=>$HASHREF));
   }



##
##
## does a keyword search for the PROD_NAMe field! (uses the cache_products_by_name file)
##
sub findproducts_by_keyword
{
	my ($USERNAME, $KEYWORD) = @_;
	my @retar = ();

	$KEYWORD = uc($KEYWORD);

	# if ($USERNAME eq 'amphidex') { return(); }

	my $cached = 0;
	my $path = &ZOOVY::resolve_userpath($USERNAME);
	if (-f "$path/cache-products-list.bin") {
		my $ref = eval { retrieve "$path/cache-products-list.bin"; };
		if (scalar(keys %{$ref})==0) { $ref = undef; }
		if (defined $ref)	{
			$cached++;
			my $searchstr = '';
			foreach my $product (keys %{$ref}) {
				my $searchstr = uc($ref->{$product}.' '.$product);
				if (index($searchstr, $KEYWORD) >= 0) {
					push @retar, $product;
					}
				}
			}
		else {
			&nuke_product_cache($USERNAME);
			}
		}

#	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
#	if (($cached) && (defined $gref->{'%tuning'})) {
#		## tuning parameters can alter behaviors here.
#		if ((defined $gref->{'%tuning'}->{'auto_product_cache'}) && (int($gref->{'%tuning'}->{'auto_product_cache'})>0)) {
#			$cached = 1;
#			}
#		}
	

	if (not $cached) {
		my $udbh 	 = &DBINFO::db_user_connect($USERNAME);
		my $MID = &resolve_mid($USERNAME);
		my $TB = &resolve_product_tb($USERNAME);

		my $pstmt = "/* KEYWORD */ select SQL_BUFFER_RESULT PRODUCT,PRODUCT_NAME from $TB where MID=$MID";
		my $sth   = $udbh->prepare($pstmt);
		$sth->execute();
		my $ref = {};
		while (my ($product, $productname) = $sth->fetchrow()) {
			## NOTE: this will only search the first 80 characters since that's all we keep in the database.
			if (utf8::is_utf8($productname) eq '') {
				$productname = Encode::decode("utf8",$productname);
				utf8::decode($productname);
				}
			$product         = uc($product);
			$ref->{$product} = $productname;
			$productname    = uc($productname);
			if ((index($product, $KEYWORD) >= 0) || (index($productname, $KEYWORD) >= 0)) {
				push @retar, $product;
				}
			}
		$sth->finish();
		my $success = eval { Storable::nstore $ref, "$path/cache-products-list.bin"; };
		unless ($success) { 
			&nuke_product_cache($USERNAME); 
			}
		&DBINFO::db_user_close();
		}

	return (@retar);
} ## end sub findproducts_by_keyword


##
## Blah!
##
#sub savemerchantns_attrib {
#	my ($USERNAME,$NS,$attrib,$value) = @_;
#	$attrib = lc($attrib);
#	
#	my $ref = &ZOOVY::fetchmerchantns_ref($USERNAME,$NS);
#	## only save if the value is different
#	if ($ref->{$attrib} ne $value) {
#		$ref->{$attrib} = $value;
#		&ZOOVY::savemerchantns_ref($USERNAME,$NS,$ref);
#		}
#	}
#

#sub fetchmerchantns_attrib {
#	my ($USERNAME,$NS,$attrib,$default) = @_;
#
#	if (not defined $default) { $default = undef; }
#
#	if ((not defined $attrib) || ($attrib eq '')) { return($default); }
#
#	$attrib = lc($attrib);
#	my $ref = &ZOOVY::fetchmerchantns_ref($USERNAME,$NS);
#
#	if (not defined $ref->{$attrib}) { return($default); }
#	return($ref->{$attrib});	
#	}
#


#sub savemerchantns_ref {
#	my ($USERNAME,$NS,$ref) = @_;
#
#	delete $ref->{'_NS'};
#
#	$NS = uc($NS);
#	$NS =~ s/[^A-Z0-9]+//gso;
#	$NS = substr($NS,0,10); 
#	my $file = "merchant.bin";			
#	if (($NS eq '') || ($NS eq 'DEFAULT')) {}
#	else { $file = "merchant-".$NS.".bin"; }
#
#	my $path = &ZOOVY::resolve_userpath($USERNAME);
#	if (defined($ref) && defined($path)) {
#		# my $success = eval { Storable::lock_nstore($ref,"$path/$file"); };
#
#		my $success = eval { Storable::nstore($ref,"$path/$file"); };
#		if (not $success) {
#			require Data::Dumper;
#			&ZOOVY::confess($USERNAME,"profile $NS could not be saved.\npath:$path/$file\n".Data::Dumper::Dumper($ref),justkidding=>1);
#			}
#		elsif ($success) {
#			my $memd = &ZOOVY::getMemd($USERNAME);
#			if ((defined $ref) && (defined $memd)) {
#				$memd->set("$USERNAME.$file",$ref);
#				}
#			}
#		}
#	chown($ZOOVY::EUID,$ZOOVY::EGID,"$path/$file");
#	chmod(0666,"$path/$file");
#	&ZOOVY::touched($USERNAME,1);
#	}
#

sub merchant_cache_file {
	my ($USERNAME,$NS) = @_;
	$NS = uc($NS);
	return(&ZOOVY::cachefile($USERNAME,"merchant-$NS.bin"));
	}



sub LEGACYfetchmerchantns_ref {
	my ($USERNAME,$NS,$cache) = @_;

	if (not defined $cache) { $cache = 0; }

	$NS = uc($NS);
	$NS =~ s/[^A-Z0-9]+//gso;
	$NS = substr($NS,0,10); 
	if ($NS eq '') { $NS = 'DEFAULT'; }

	my $ref = undef;
	#if ($cache<0) {
	#	my $PRT = abs($cache)-1;
	#	my $cachefile = &ZOOVY::pubfile($USERNAME,$PRT,"profile-$NS.yaml");
	#	if ($cachefile ne '') {
	#		$ref = YAML::Syck::LoadFile("$cachefile",$ref);
	#		return($ref);			
	#		}
	#	}

	my $file = "merchant.bin";			
	if ($NS eq 'DEFAULT') {}
	else { $file = "merchant-".$NS.".bin"; }


	my $path = &ZOOVY::resolve_userpath($USERNAME);
	if (not defined $path) { return undef; }

	my $binfile = "$path/$file";
	if (-f $binfile) {
		# $ref = eval { Storable::lock_retrieve($binfile) };
		$ref = eval { Storable::retrieve($binfile) };
		if (not defined $ref) {
			sleep(1);
			$ref = eval { Storable::retrieve($binfile) };
			}
		if (not defined $ref) {
			sleep(3);
			$ref = eval { Storable::retrieve($binfile) };
			}
		if (not defined $ref) {
			my $shall_i_nuke = (($cache>0) && ($binfile =~ /\/local/))?1:0;
			&ZOOVY::confess($USERNAME,"profile $NS corrupt, reset.\ncache:$cache\nbinfile:$binfile\nshall_i_nuke:$shall_i_nuke\n",justkidding=>1);
			if ($shall_i_nuke) { unlink($binfile); }
			}
		$ref->{'zoovy:profile'} = uc($NS);
		## these fields should *NEVER* be set in the profile (but somehow routinely are)
		delete $ref->{'ebaystores:price'};
		delete $ref->{'ebay:price'};
		delete $ref->{'zoovy:base_price'};
		delete $ref->{'ebaystores:quantity'};
		delete $ref->{'ebay:password'};
		delete $ref->{'ebay:category2'};
		delete $ref->{'ebaystores:category'};
		delete $ref->{'ebay:reserve'};
		delete $ref->{'ebay:buyitnow'};
		delete $ref->{'ebaystores:duration'};
		delete $ref->{'ebay:fixedprice'};
		delete $ref->{'ebay:quantity'};
		delete $ref->{'ebay:reclaim_fees'};
		delete $ref->{'ebay:category'};
		delete $ref->{'ebaymotor:username'};

		$ref->{'_NS'} = $NS;
#		if ((defined $ref) && (defined $memd)) {
#			$memd->set("$USERNAME.$file",$ref);
#			}
		}
#
#	## 
#	## logo:invoice
#	## logo:website
#	##	logo:market
#	## logo:email
#	## logo:mobile
#	##
#
#	if (($cache==1) && (defined $ref)) {
#		my $cbinfile = &ZOOVY::merchant_cache_file($USERNAME,$NS);
#		Storable::nstore $ref, $cbinfile;
#		}
#
	return($ref);
	}
#

##
## accepts a username - returns an arrayref of profiles. 
##
##	options
##		FILTER=>DOMAIN_AVAILABLE
##
##
sub LEGACYfetchprofiles {
	my ($USERNAME, %options) = @_;
	my @AR = ('DEFAULT');

	my $path = &ZOOVY::resolve_userpath($USERNAME);
	if (not defined $path) { return undef; }
	opendir(my $D,$path);
	while ( my $file = readdir($D) ) {
		next if (substr($file,0,1) eq '.');
		if ($file =~ /^merchant-([A-Z0-9]+)\.bin$/o) {
			push @AR, $1;
			}
		}
	closedir($D);

#	if (defined $options{'FILTER'}) {
#		my @NEW = ();
#		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#		my $udbh = &DBINFO::db_user_connect($USERNAME);
#
#		if ($options{'FILTER'} eq 'NO_DOMAIN_MAPPED') {
#			my $pstmt = "select PROFILE,WWW_HOST_TYPE,APP_HOST_TYPE,M_HOST_TYPE from DOMAINS where MID=$MID";
#			my $sth = $udbh->prepare($pstmt);
#			$sth->execute();
#			my %h = ();
#			while ( my ($PROFILE,$WWW,$APP,$M) = $sth->fetchrow() ) { 
#				my ($IS_USE) = 0;
#				if (($WWW eq 'APP') || ($WWW eq 'VSTORE')) { $IS_USE |= 1; }
#				if (($APP eq 'APP') || ($APP eq 'VSTORE')) { $IS_USE |= 2; }
#				if (($M eq 'APP') || ($M eq 'VSTORE')) { $IS_USE |= 4; }
#				$h{$PROFILE} = $IS_USE;
#				}
#			$sth->finish();
#			foreach my $PROFILE (@AR) {
#				next if (defined $h{$PROFILE});
#				push @NEW, $PROFILE;
#				}	
#			}
#		else {
#			## this line should never be reached.
#			warn "Called fetchprofiles with unknown FILTER=>$options{'FILTER'}."
#			}
#		&DBINFO::db_user_close();
#		@AR = @NEW;
#		}
#
#	if (defined $options{'PRT'}) {
#		my $PRT = int($options{'PRT'});
#		my @NEW = ();
#		foreach my $profile (@AR) {
#			my ($ref) = &ZOOVY::fetchmerchantns_ref($USERNAME,$profile);
#			next if (int($ref->{'prt:id'}) != $PRT);
#			push @NEW, $profile;
#			}
#		@AR = @NEW;
#		}
#
#
	return(\@AR);
	}


#sub savemerchant_ref { 
#	my ($USERNAME,$ref) = @_; 
#
#	my ($package,$file,$line,$sub,$args) = caller(1);
##	warn "saving ref: $0 $$ ".time()." $sub\n";
#	return(&savemerchantns_ref($USERNAME,'',$ref)); 
#	}
#
#sub savemerchant_attrib { 
#	my ($USERNAME,$attrib,$value) = @_; 
#
#	my ($package,$file,$line,$sub,$args) = caller(1);
##	warn "saving attrib: $0 $$ ".time()." $sub\n";
#	return(savemerchantns_attrib($USERNAME,'',$attrib,$value)); 
#	}
#sub fetchmerchant_attrib { 
#	my ($USERNAME,$attrib,$default) = @_; 
#	my ($package,$file,$line,$sub,$args) = caller(1);
##	warn "loading attrib: $0 $$ ".time()." $sub\n";
#	return(&fetchmerchantns_attrib($USERNAME,'',$attrib,$default)); 
#	}

#sub fetchmerchant_ref { 
#	my ($USERNAME) = @_; 
#	my ($package,$file,$line,$sub,$args) = caller(1);
#	# warn "loading ref: $0 $$ ".time()." $sub\n";
#	return(&fetchmerchantns_ref($USERNAME,'')); 
#	}

#sub commitmerchant {
#	my ($USERNAME,$data) = @_;
#
##	print STDERR "ZOOVY::commitmerchant is deprecated, being called by $0\n";
#	my $ref = &ZOOVY::attrib_handler_ref($data);
#	&ZOOVY::savemerchantns_ref($USERNAME,'',$ref);
#	}

#sub fetchmerchant {
#	my ($USERNAME) = @_;
#	return(attrib_to_str_ref(&ZOOVY::fetchmerchantns_ref($USERNAME,'')));
#	}


#################################
##
## ZOOVY::deleteproduct
##
## description: deletes a product from the PRODUCTS.ZOOVY file.
## 
## parameters: MERCHANT_ID, PRODUCT_NAME
##
## returns:
##     0 on success
##     1 on failure
##
########################################
sub deleteproduct {
	my ($USERNAME, $PID, %options) = @_;

	my $NC = undef;
	if (defined $options{'navcat'}) {
		$NC = $options{'navcat'};
		}
	if (not defined $options{'nuke_cache'}) {
		$options{'nuke_cache'} = 1;
		}
	if (not defined $options{'nuke_navcats'}) {
		$options{'nuke_navcats'} = 1;
		}

	my $result = 0;
	my $udbh 	 = &DBINFO::db_user_connect($USERNAME);

	my $MID = &resolve_mid($USERNAME);
	my $TB = &resolve_product_tb($USERNAME);

	my $qtPRODUCT  = $udbh->quote($PID);
	my $qtUSERNAME = $udbh->quote($USERNAME);

	my $pstmt = "select ID,MKT_BITSTR from $TB where PRODUCT=$qtPRODUCT and MID=$MID";
	my ($EXISTS,$old_mkt_bitstr) = $udbh->selectrow_array($pstmt);

	my @EVENTS = ();
	if ($EXISTS) {
		if ($old_mkt_bitstr eq '') {
			push @EVENTS, sprintf('PID.MKT-CHANGE?was=%s&is=0',$old_mkt_bitstr);
			}


		my $pstmt = "delete from $TB where PRODUCT=$qtPRODUCT and MID=$MID";
		# print STDERR $pstmt . "\n";
		my $rv = $udbh->do($pstmt);
		if (defined($rv)) { $result = 0; }
		else { $result = 1; }

		my ($LTB) = &ZOOVY::resolve_lookup_tb($USERNAME,$MID);
		$pstmt = "delete from $LTB where MID=$MID and PID=".$udbh->quote($PID);
		$udbh->do($pstmt);

		push @EVENTS, 'PID.DELETE';

		## notify amazon marketplace immediately (don't wait for events)
		## NOTE: this is a really bad idea since it spreads amazon code all over the fuck. lets just let events handle it.
		#my ($enabled_mktbits) = &ZOOVY::bitstr_bits($old_mkt_bitstr);
		#foreach my $dstid (@{$enabled_mktbits}) {
		#	my $intref = &ZOOVY::fetch_integration('id'=>$dstid);
		#	if ($intref->{'dst'} eq 'AMZ') {
		#		## special amazon specific behaviors
		#		}
		#	}
		}

	


	require ZWEBSITE;
	INVENTORY2->new($USERNAME,"*DELETE")->pidinvcmd($PID,'NUKE');
	## &INVENTORY::nuke_record($USERNAME,$PID);

	if ($options{'nuke_navcats'}) {
		require NAVCAT;
		foreach my $prttxt (@{ZWEBSITE::list_partitions($USERNAME)}) {
			my ($prt) = split(/:/,$prttxt);
			if (not defined $NC) { $NC = NAVCAT->new($USERNAME,$prt); }
			if ((defined $NC) && (ref($NC) eq 'NAVCAT')) {
				if ($NC->nuke_product($PID)) { $NC->save(); }
				undef $NC;
				}
			}
		}

	if ($options{'nuke_cache'}) {
		&nuke_product_cache($USERNAME,$PID);
		}

	if (scalar(@EVENTS)>0) {
		foreach my $event (@EVENTS) {
			# print STDERR "EVENT: $event\n";
			my $params = {};
			if (index($event,'?')>0) {
				## event?param1=value1&param2=value2
				$params = &ZTOOLKIT::parseparams(substr($event,index($event,'?')+1));
				$event = substr($event,0,index($event,'?'));	
				}
			$params->{'PID'} = $PID;
			$params->{'SRC'} = 'ZOOVY::DELETEPRODUCT';
			&ZOOVY::add_event($USERNAME,$event,%{$params});
			}
		}

#	require ELASTIC;
#	my ($es) = &ZOOVY::getElasticSearch($USERNAME);
#	$es->delete(
#		'index'=>lc("$USERNAME.public"),
#		'type'=>'product',
#		'id'=>$PID,
#		);
#	$es->delete_by_query(
#		'index'=>lc("$USERNAME.public"),
#		'type'=>'sku',
#		'queryb'=>{ 'pid'=>$PID },
#		);

	&DBINFO::db_user_close();
	return ($result);
} ## end sub deleteproduct

###########################################
##
## ZWEBSITE::fetchproduct_list_by_merchant
##
## returns: an array of products
###########################################
sub fetchproduct_list_by_merchant {
	my ($USERNAME,$TS) = @_;

	my @ar = ();

	## we can use a cache file if the TS is zero or undefined
	if ((not defined $TS) || ($TS == 0)) {
		my $path = &ZOOVY::resolve_userpath($USERNAME);
		if (-f "$path/cache-products-list.bin")
		{
			my $ref = eval { retrieve "$path/cache-products-list.bin"; };
			if (scalar(keys %{$ref})==0) { $ref = undef; }
			if (defined $ref) { return(keys %{$ref}); }
			else { &nuke_product_cache($USERNAME); }
		}
	}


	my $udbh 	 = &DBINFO::db_user_connect($USERNAME);

	my $MID = &resolve_mid($USERNAME);
	my $TB = &resolve_product_tb($USERNAME);

	my $pstmt = "select PRODUCT from $TB where MID=$MID";
	if (defined $TS) { $pstmt .= " and TS>=".$udbh->quote($TS); }
	my $sth   = $udbh->prepare($pstmt);
	$sth->execute();
	my $product;
	while (($product) = $sth->fetchrow()) { push @ar, $product; }
	$sth->finish();
	&DBINFO::db_user_close();

	return (@ar);
} ## end sub fetchproduct_list_by_merchant



1;
