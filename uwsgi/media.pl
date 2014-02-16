#!/usr/bin/perl

use strict;
use URI::Escape::XS qw();
use HTTP::Date qw();
use Data::Dumper;
use POSIX;
use Image::Magick qw();
use Plack::Request;
use Plack::Response;
use MIME::Types qw();

use lib "/httpd/modules";
require ZWEBSITE;
require ZOOVY;
require MEDIA;
require NAVBUTTON;
require SITE::health;

## both necessary for RSS
require DOMAIN::TOOLS;
require DOMAIN::QUERY;
require WHOLESALE;

## http://search.cpan.org/CPAN/authors/id/M/MI/MIYAGAWA/Plack-Middleware-ReverseProxy-0.15.tar.gz

my $app = sub {
	my $env = shift;

	my $req = Plack::Request->new($env);

	# my $path = $env->{'REQUEST_URI'};
	my $path = $req->path_info;
	my %HEADERS = ();

	$HEADERS{'X-Powered-By'} = 'ZOOVY/v.'.&ZOOVY::servername();
	my $AGE = (86400*45);
	my $VERB = undef;

	## SANITY: at this point we're not doing an API call, so lets set Cache-Control and Expires	
	if (not defined $VERB) {
		$HEADERS{'Expires'} = HTTP::Date::time2str( time() + $AGE );
		$HEADERS{'Cache-Control'} = "max-age=$AGE";
		}

	## BEGIN MEDIA DETECTION 
	my $IS_MEDIA_REQUEST = 0;
	if (defined $VERB) {
		}
	elsif ($path =~ /^\/media\//) {
		$path =~ s/^\/media\//\//o;
		$IS_MEDIA_REQUEST++;
		}
	elsif ($req->uri()->server_name() =~ /^static---/) {
		## this handles a few backwards compat situations.
		$IS_MEDIA_REQUEST++;
		}
	## END OF MEDIA DETECTION
	## Sanity: at this stage we know if we're handling a media request.

	if ((not defined $VERB) && ($IS_MEDIA_REQUEST)) {
		if (not defined $VERB) {
			# remove /v####	from leading part of path.
			$path =~ s/^\/v[\d]+\//\//o;
			}

		##
		## /graphics/something
		## 
		if (defined $VERB) {
			}
		elsif (substr($path,0,10) eq '/graphics/') {
			if ($path =~ /zmvc/) {
				$HEADERS{"X-XSS-Protection"} = "0";
				}

			my $dir = "/httpd/static".$path;
			if (substr($path,0,21) eq '/graphics/navbuttons/') {
				## navbuttons can be dynamically created
				$VERB = [ 'NAVBUTTON', $path ];
				}
			elsif (-f $dir) {
  	       ## but we need to get a handle .. if we can't get a handle, something bad happened.
				$VERB = [ 'FILE', $dir ];
			 	}
			}


		##
		## custom files 
		##
		if (defined $VERB) {
			}
		elsif (substr($path,0,10) eq '/merchant/') {
			my $baseimage = "";
			my $merchant = "";
	
			$path =~ s/[\/]+/\//go;	# changes //file.gif to /file.gif (seems a pretty a common mistake)
			$path =~ s/[\.]+/\./go;	# changes ../file.gif to ./file.gif (possible security issue)
		
			if ($path =~ /^\/merchant\/([A-Za-z0-9]+)\/(.+)$/) {
				## RegEx ran successfully! - note we must do $2 (ext) then $1 (baseimg), because we stomp baseimage
				($merchant,$baseimage) = ($1,$2);
				}

			if (substr($merchant,0,1) eq '-') {
				## if the first letter of the merchant name starts with - then it's a unique key.
				my $URI = $req->uri();
				my ($HOSTDOMAIN) =  $URI->host();
				# print STDERR "HOST:$HOSTDOMAIN URI:$URI\n";
				if ($HOSTDOMAIN =~ /^([a-z0-9\-]+)\.app-hosted\.com$/) {
					$HOSTDOMAIN = &ZWEBSITE::checkout_domain_to_domain($HOSTDOMAIN);
					}
				my ($DNSINFO) = &DOMAIN::QUERY::lookup($HOSTDOMAIN,'verify'=>1);
				$merchant = $DNSINFO->{'USERNAME'};				
				}

			$merchant = lc($merchant);
			my $file = &ZOOVY::resolve_userpath($merchant).'/IMAGES/'.$baseimage;

			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($file);	
			if ($ino>0) {
				$VERB = [ 'FILE', $file ];
			 	}
			else {
				$VERB = [ 'MISSING' ];
				}
			} ## end if strncmp /merchant
	
	
		if (defined $VERB) {
			}
		elsif (substr($path,0,6) eq '/auto/') {
			$VERB = [ 'AUTO', $path ];
			}

		##
		## dynamic images
		##
		if (defined $VERB) {
			}
		elsif (substr($path,0,5) eq '/img/') {
			my $merchant = undef;
			my $img_arg = undef;
			my $img_subdir = undef;
			my $base_image = undef;
			my $img_ext = undef;
			my $img_name = undef;

			$path = substr($path,5);	# strips off the /img

			## my $bgcolor = substr(time(),8,2).substr(time(),8,2).substr(time(),8,2);
			## $path =~ s/000000/$bgcolor/g;

			$merchant = lc(substr($path,0,index($path,'/')));
			if (substr($merchant,0,1) eq '-') {
				## auto-detect merchant id based on domain
				## if the first letter of the merchant name starts with - then it's a unique key.
				my $URI = $req->uri();
				my ($HOSTDOMAIN) =  $URI->host();
				# print STDERR "HOST:$HOSTDOMAIN URI:$URI\n";
				if ($HOSTDOMAIN =~ /^([a-z0-9\-]+)\.app-hosted\.com$/) {
					$HOSTDOMAIN = &ZWEBSITE::checkout_domain_to_domain($HOSTDOMAIN);
					}
				my ($DNSINFO) = &DOMAIN::QUERY::lookup($HOSTDOMAIN,'verify'=>1);
				$merchant = $DNSINFO->{'USERNAME'};		
				}
			$path = substr($path,index($path,'/')+1);

			if (&ZOOVY::resolve_cluster($merchant) eq '') {
				## 404 handler - merchant is not found.
				$VERB = [ 'MISSING' ];
				}


			$img_arg = substr($path,0,index($path,'/'));
			$path = substr($path,length($img_arg)+1);

			$base_image = $path;		

			(my $xref,$img_arg) = &MEDIA::parse_args($merchant,'',$img_arg);
	
			## SANITY: determine the collection
			if (defined $base_image) {
				my $pos = index($base_image,'/');
				if ($pos>=0) {
					## image has one or more slashes in it.
					$img_subdir = substr($base_image,0,rindex($base_image,'/'));
					$base_image = substr($base_image,rindex($base_image,'/')+1);
					}
				else {
					## legacy image format (e.g. asdf becomes A/asdf)
					$img_subdir = uc(substr($base_image,0,1));
					}			
				}
	
			## SANITY: determine extension (leave extension "" if null)
			if (defined $base_image) {
				if ($base_image =~ /^(.*)\.(.+)$/) {
  	      		# RegEx ran successfully! - note we must do $2 (ext) then $1 (baseimg), because we stomp base_image
					($base_image,$img_ext) = ($1,$2);
					}
				else {
					## hmm.. no extension! silly user, how about a jpg!?!
					$img_ext = 'jpg';
					}
				}
			$base_image = substr($base_image,0,$MEDIA::max_name_length);
			## NOTE: base_image will be have been rewritten if we found an extension!


			my $dir = $img_subdir.'/';
			## **********************************************************************************
			## SANITY - at this point, the following statements are true.
			##		base_image - is image name without extension, or blank if we don't have an image (error)
			##		img_ext 	 - is the extension, or blank if no extension was specified
			##		merchant  - is the poor sap who's data we're dealing with.
			##		img_arg	 - is the image arguments or - if we need the original image
			##		img_subdir 	 - is the directory off the merchants ~/IMAGES directory that we will find the image in
			##		dir	 - is the fully qualified path, including img_subdir (e.g. "/httpd/zoovy/merchants/b/brian/IMAGES/t/")
			##
			## **********************************************************************************


			if (($base_image eq '[logo]') || ($base_image eq '[/[logo]')) {
				## LEGACY!! DEPRECATED!! Handle special Logo URL (any image named [logo] loads the default profile logo!)
				##		which is then handled in the next code block
				$base_image = "[DEFAULT:LOGO]";
				}

			if ($base_image =~ /\[([\w]+)\:(LOGO)\]/o) {
				## Virtual redirect to logo for profile xxxx -- these are simply redirects to the actual images
				##		(which if they don't exist will be handled *exactly* like any other image
				my $profile = $1; 
				my ($collection) = &ZOOVY::fetchmerchantns_attrib($merchant,$profile,'zoovy:logo_website');
				if ($collection eq '') { $collection = 'imagenotfound'; }
				# print STDERR "Doing a redirect to /img/$merchant/$img_arg/$collection\n";

				$HEADERS{"Cache-Control"} = "no-cache, no-store";    # HTTP 1.1 non-caching specification
				$HEADERS{"Expires"} = "0";                           # HTTP 1.0 way of saying "expire now"
				$VERB = [ 'REDIRECT', "/img/$merchant/$img_arg/$collection" ];
				}

			## SANITY: at this point we're going to need to serve an image, no cheating and redirecting someplace else.		
			# print STDERR sprintf("base_image[%s]\nimg_ext[%s]\nimg_arg[%s]\nimg_subdir[%s]\ndir[%s]\n",$base_image,$img_ext,$img_arg,$img_subdir,$dir);

			if (defined $VERB) {
				}
			elsif ($img_ext eq '') {
				##
				## no extension - try the usual suspects .jpg and .gif
				##	if we find something we'll set img_ext to it.
				## -- note: in a pinch we could probably skip .png to reduce stat calls over nfs
				##
				if (length($img_arg)<=1) {
					## master image - no arguments
					$path = $dir.$base_image;
	  	       	}
		      else {
  		 	      ## rendered image - arguments included
					$path = $dir.$base_image.'-'.$img_arg;
		      	}

				if (-f $path.'.jpg') { $img_ext = 'jpg'; }
				elsif (-f $path.'.gif') { $img_ext = 'gif'; }
				elsif (-f $path.'.png') { $img_ext = 'png'; }
				# print STDERR "path[$path] base[$base_image] IMGEXT: $img_ext\n";
				}	

			##
			## SANITY: at this point we either have an extension, or we're handing this off to image.pl
			##
			if (defined $VERB) {
				}
			elsif ($img_ext ne "") {
			## we have an extension - note: first thing to do is reformat path
				my $file = undef;
				if (length($img_arg)<=1) { 
					## master image - no arguments (e.g. /-/)
					$file = $base_image.'.'.$img_ext; 
					}
				else {
					## rendered image - arguments included
					$file = $base_image.'-'.$img_arg.'.'.$img_ext;
					}
				## NOTE: it is VERY important that img_col be set to dir/filename-something.ext
				$path = $dir.$file;
				} 
    
			## performance tuning note: 
			## does the file exist (note: we're assuming the local operating system is caching the stat
			##		from the previous stat when we were looking up the extension (ASSUMING that we looked up the extension)
			##		so it doesn't hurt us here to call stat again. -BH
			if (not defined $VERB) {
				my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($path);
				if ($ENV{'HTTP_PRAGMA'} eq 'no-cache') { 
					## on a shift-refresh then it will force a reload
					unlink($path); $ino = 0; 
					}
				if ($size<512) { 
					$ino = 0; 
					unlink($path); 
					}
	
				if ($ino>0) {
					## file definitely exists!
					$VERB = [ 'FILE', $path ];
					$HEADERS{'IMG_EXT'} = $img_ext;
					}	
				else {
					if ($img_ext eq '') { $img_ext = 'jpg'; }	# if we don't have an extension by now, default to jpg.
					$HEADERS{'IMG_ARG'} = $img_arg;
					$HEADERS{'IMG_COL'} = $img_subdir.'/'.$base_image.(($img_ext eq '')?'':('.'.$img_ext));
					$HEADERS{'IMG_EXT'} = $img_ext;
					$HEADERS{'USERNAME'} = $merchant;
					$VERB = [ 'BUILD_IMAGE' ];
					}		
				}
			}	# END /img

		##
		## syntax:
		##		/rss/USERNAME/feedid.xml
		##
		if (defined $VERB) {
			}
		elsif (substr($path,0,5) eq '/rss/') {
			if ($path =~ /\/rss\/([a-z0-9]+)\/([A-Z0-9a-z]+)\.xml/) {
				my ($USERNAME,$CAMPAIGN) = ($1,$2);
				$VERB = [ 'RSS', "$USERNAME:$CAMPAIGN" ];
				}
			}

		##
		## syntax:
		##		/kount/$USERNAME/$LIVE/$KMERCHANT/s=$SDOMAIN/c=$CARTID/logo.(html|gif)
		if (defined $VERB) {
			}
		elsif (substr($path,0,7) eq '/kount/') {		
			if ($path =~ /\/kount\/([a-z0-9]+)\/([\d]{1,1})\/([\d]+)\/s\=([A-Z0-9a-z\.\-]+)\/c\=([A-Z0-9a-z]+)\/logo\.(gif|html|htm)/o) {
				my ($username,$live,$kmerchant,$sdomain,$cartid,$ext) = ($1,$2,$3,$4,$5,$6);
				$HEADERS{"Cache-Control"} = "no-cache, no-store";    # HTTP 1.1 non-caching specification
				$HEADERS{"Expires"} = "0";                           # HTTP 1.0 way of saying "expire now"
				my $url =  sprintf('https://%s.kaptcha.com/logo.%s?m=%s&s=%s',(($live)?'ssl':'tst'),$ext,$kmerchant,$cartid);
				$VERB = [ 'REDIRECT', $url ];
				}
			else {
				warn "MISSED ON: $path\n";
				}
			}

		## END /media
		}


	## CLEANUP - specialized handlers!
	if (defined $VERB) {
		}
	elsif ($path eq '/__health__') {
		## health checks should ignore the shenanigans below
		$VERB = [ 'HEALTH' ];
		}
	elsif (substr($path,0,16) eq '/crossdomain.xml') {
		$VERB = [ 'FILE', '/httpd/htdocs/crossdomain.xml' ];
		}
	elsif (substr($path,0,11) eq '/robots.txt') {
		## added a robots.txt for static.
		$VERB = [ 'FILE', '/httpd/static/robots.txt' ];
		}
	elsif (substr($path,0,14) eq '/geotrust.html') {
		$VERB = [ 'FILE', '/httpd/static/geotrust.html' ];
		}

	## attempt to lookup project/files

	if (not defined $VERB) {
		my $URI = $req->uri();
		my ($HOSTDOMAIN) =  $URI->host();
		# print STDERR "HOST:$HOSTDOMAIN URI:$URI\n";
		if ($HOSTDOMAIN =~ /^([a-z0-9\-]+)\.app-hosted\.com$/) {
			$HOSTDOMAIN = &ZWEBSITE::checkout_domain_to_domain($HOSTDOMAIN);
			}
		my ($DNSINFO) = &DOMAIN::QUERY::lookup($HOSTDOMAIN,'verify'=>1);
		## TODO - come back here.
		}
	

	if (not defined $VERB) {
		$VERB = [ 'MISSING' ];
		}

	##
	## END MAPPING PHASE, START PROCESSING PHASE
	##
	my $BODY = undef;
	my $HTTP_RESPONSE = undef;

	if ($VERB->[0] eq 'HEALTH') {
		## health check
		# return(SITE::health::responseHandler($r));
		my ($ICMP_DISABLED) = int(&SITE::health::slurp("/proc/sys/net/ipv4/icmp_echo_ignore_all")); 
		$HEADERS{'Content-type'} = 'text/plain';
		$BODY = sprintf("%s\n\n", (not $ICMP_DISABLED)?'HAPPY':'SAD');
		if (int($ICMP_DISABLED)>0) {
			$HTTP_RESPONSE = 404;
			}

		$BODY .= sprintf("Host: %s\n",&slurp("/proc/sys/kernel/hostname"));
		$BODY .= sprintf("Load: %s\n",&slurp("/proc/loadavg"));
		}
	elsif ($VERB->[0] eq 'FILE') {
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($VERB->[1]);

		$HEADERS{'Last-Modified'} = HTTP::Date::time2str($mtime);

		# TODO: reimplement $r->sendfile();
		$HTTP_RESPONSE = 200;
		$BODY = &SITE::health::slurp($VERB->[1]);

		## LET'S DO SOME FANCY MIME TYPE

		## NEED MORE?? MIME::Types::import_mime_types("/httpd/conf/mime.types");

		my ($mime_type, $encoding) = MIME::Types::by_suffix($VERB->[1]);
		if ($mime_type ne '') {
			$HEADERS{'Content-Type'} = "$mime_type";
			}

		if (($HEADERS{'Content-Type'} eq '') && ($HEADERS{'IMG_EXT'} ne '')) {
			## a lot of times our media library doesn't require images have an extension 
			$HEADERS{'Content-Type'} = MIME::Types::by_suffix(sprintf("filename.%s",$HEADERS{'IMG_EXT'}));
			}

		if ($HEADERS{'Content-Type'} eq '') {
			## final attempt.. look at the actual file. .. 
			}

		}
	elsif ($VERB->[0] eq 'AUTO') {

		my $path = $VERB->[1];

		# http://static.zoovy.com/auto/qr/hello.png
		# $r->uri() = "/auto/qr/hello.png";

		if ($path =~ /^\/auto\/qr([\d]*)\/(.*?)\.png$/) {
			## generates a QR code
			my $size = int($1);
			my $text = URI::Escape::XS::uri_unescape($2);
			if ($size==0) { $size = 1; }
			require GD::Barcode::QRcode;
			$HTTP_RESPONSE = '200';
			$HEADERS{'Content-Type'} = 'image/png';
			$BODY = GD::Barcode::QRcode->new($text,{ModuleSize=>$size})->plot->png;
			}
		elsif ($path =~ /^\/auto\/code39\/(.*?)\.png$/) {
			my $text = uc(URI::Escape::XS::uri_unescape($1));
			
			# allowed characters per http://en.wikipedia.org/wiki/Code_39
			$text =~ s/[^\-\.\$\/\+\%\sA-Z0-9]/ /gs;
			if (substr($text,0,1) eq '*') { $text = substr($text,1); } # remove leading * if it was passed
			if (substr($text,-1) eq '*') { $text = substr($text,0,-1); } # remove leading * if it was passed
			## code 3of9 requires leading and trailing *'s
			$text = "*$text*";

         require GD::Barcode::Code39;
         # print "Content-Type: image/png\n\n";
			$HTTP_RESPONSE = '200';
			$HEADERS{'Content-Type'} = 'image/png';
			$BODY = GD::Barcode::Code39->new("$text")->plot()->png();
			}
		elsif ($path =~ /^\/auto\/code128\/(.*?)\.png$/) {
			my $text = uc(URI::Escape::XS::uri_unescape($1));
			
			# allowed characters per http://en.wikipedia.org/wiki/Code_39
			$text =~ s/[^\-\.\$\/\+\%\sA-Z0-9]/ /gs;

         require Barcode::Code128;
         # print "Content-Type: image/png\n\n";
			$HTTP_RESPONSE = '200';
			$HEADERS{'Content-Type'} = 'image/png';
			$BODY = Barcode::Code128->new()->png("asdf");
			}
		elsif ($path =~ /^\/auto\/counter\/(.*?)\/([\d]+)\.gif$/) {
			## counters
			my ($SERIES,$COUNT) = ($1,$2);
			$HTTP_RESPONSE = '200';
			$HEADERS{'Content-Type'} = 'image/gif';
			&generate_counter_image($SERIES,$COUNT);
			}
		else {
			$HTTP_RESPONSE = '404';
			}

		}
	elsif ($VERB->[0] eq 'RSS') {
		## rss feed
		require PRODUCT::RSS;

		my ($USERNAME, $CAMPAIGN) = split(/:/,$VERB->[1]);
		my $udbh = &DBINFO::db_user_connect($USERNAME);
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);

		my $qtCODE = $udbh->quote($CAMPAIGN);
		my $pstmt = "select ID,CREATED_GMT,PROFILE,SCHEDULE,DATA from RSS_FEEDS where MID=$MID /* $USERNAME */ and CPG_TYPE='RSS' and CPG_CODE=$qtCODE";
		print STDERR "$pstmt\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		my ($CPGID,$CREATEDGMT,$PROFILE,$SCHEDULE,$DATA) = $sth->fetchrow();
		$sth->finish();

		if ($CREATEDGMT>0) {
			my ($ref) = &ZTOOLKIT::parseparams($DATA);		## seems like this might be problematic if we ever switch to YAML
			$ref->{'campaign'} = $CAMPAIGN;
			$ref->{'cpgid'} = $CPGID;
			$ref->{'createdgmt'} = $CREATEDGMT;
			$ref->{'profile'} = $PROFILE;
			$ref->{'schedule'} = $SCHEDULE;
			$ref->{'domain'} = $req->uri()->host();
			# print Dumper($ref);			

			my $PRT = 0;
			# my $PRT = $ref->{'domain'};
			#my ($DOMAIN) = &DOMAIN::TOOLS::syndication_domain($USERNAME,$PROFILE);
			#my ($PRT) = &ZOOVY::profile_to_prt($USERNAME,$PROFILE);

			my $LAST_MODIFIED_TS = &ZOOVY::touched($USERNAME);
			my ($NC) = NAVCAT->new($USERNAME,cache=>$LAST_MODIFIED_TS,PRT=>$PRT);
			my ($pretty,$children,$products) = $NC->get($ref->{'list'});
			my @PIDS = ();
			foreach my $pid (split(/,/,$products)) {
				next if ($pid eq '');
				push @PIDS, $pid;
				}
			# print Dumper(\@PIDS);

			my $max_products = $ref->{'max_products'};
			my $period = ($ref->{'cycle_interval'}*60);
	
			my $NOWTS = time();

			my $i = -1;
			my $SEC_REMAIN = 3600;
			$ref->{'sec_remain'} = $SEC_REMAIN;

			if (scalar(@PIDS)==0) {
				## No products for you!
				}
			elsif ($max_products==-1) { 
				## they want all products.. man that 
				$max_products = scalar(@PIDS); $i = 0; 
				}	
			else {
				## they want a splice of the products
				
				my $diff = $NOWTS-$CREATEDGMT;	## the current time that has elapsed since created.
				$i = int($diff/$period);		## how many interations we've done
				$SEC_REMAIN = ($period) - ($diff % $period); ##
				$ref->{'sec_remain'} = $SEC_REMAIN;
			
				$i = ($i % scalar(@PIDS)); 			## so now $i represents a position into the array.
				@PIDS = (@PIDS,@PIDS);						## now we'll double the size of the array so we don't overflow
			
				@PIDS = splice(@PIDS,$i,$max_products);
				}

			$HEADERS{'Last-Modified'} = HTTP::Date::time2str($NOWTS);
			$HEADERS{'Expires'} = HTTP::Date::time2str($NOWTS + $SEC_REMAIN);
			$HEADERS{'Cache-Control'} = "max-age=".$SEC_REMAIN;
			$HEADERS{'Content-Type'} = 'application/rss+xml';
			$HTTP_RESPONSE = 200;		
			$BODY = &PRODUCT::RSS::buildXML($USERNAME,\@PIDS,$ref);
			}

		&DBINFO::db_user_close();
		}
	elsif ($VERB->[0] eq 'BUILD_IMAGE') {
		## this is the old image.pl
		# Get the name of the file we're supposed to serve up
		
		# my ($image,$ext,$modtime) = SITE::Static::loadImage($r);

		my $USERNAME = $HEADERS{'USERNAME'};
		my $IMG_ARG = $HEADERS{'IMG_ARG'};
		my $IMG_COL = $HEADERS{'IMG_COL'};

		my ($filename, $image, $ext, $modtime);
		# Get the name of the file we're supposed to serve up
		($filename,$image,$ext,$modtime,my $result) = &MEDIA::serve_image($USERNAME,$IMG_COL,$IMG_ARG);
		# use Data::Dumper;	
		# print STDERR Dumper($result);
		
		# print STDERR "IMAGE.PL: $USERNAME $IMG_ARG $IMG_COL $ENV{'HTTP_REFERER'}\n";
		# print STDERR "IMAGE.PL[$USERNAME] img_arg=$IMG_ARG | img_col=$IMG_COL\n";
		if ((not defined $result) || ($result->{'err'}>0)) {
			## err=>1 means the source_file wasn't found, and so we're (more than likely) dealing with a blank image
			## all the other stuff means bad things happened.
			
			($filename,$image,$ext,$modtime) = &MEDIA::serve_image($USERNAME,'I/imagenotfound',$IMG_ARG);
			unless (defined($image) && length($image) && defined($ext) && ($ext ne '')) {
				$image = &MEDIA::blankout();
				$ext = 'gif';
				$modtime = 0;
				}
			}
			
		undef $filename;
		if (not defined $modtime) {
			$modtime =  time()-(86400*7);
			}		

		$HEADERS{'Content-Type'} = 'image/gif';	
		if (($ext eq 'jpg') || ($ext eq 'jpeg')) { $HEADERS{'Content-Type'} = 'image/jpeg'; }
		elsif ($ext eq 'png') { $HEADERS{'Content-Type'} = 'image/png'; }

		$HEADERS{'Last-Modified'} = HTTP::Date::time2str($modtime);
		my $AGE = (86400*45);
		$HTTP_RESPONSE = 200;
		$HEADERS{'Expires'} = HTTP::Date::time2str( time() + $AGE );
		$HEADERS{'Cache-Control'} = "max-age=$AGE";
		$BODY = $image;
		}
	elsif ($VERB->[0] eq 'NAVBUTTON') {
		# print STDERR "998 HANDLER FILENAME: ".$r->filename()."\n";
		$HTTP_RESPONSE = 200;
		$HEADERS{'Expires'} = HTTP::Date::time2str( time() + (86400*365) );
		$HEADERS{'Cache-Control'} = "max-age=86400";
		$BODY = &buildNavbutton($VERB->[1],\%HEADERS);
		}
	else {
		# print STDERR "FOUND[$found]\n";
		$VERB = [ 'MISSING' ];
		}

	if ($VERB->[0] eq 'MISSING') {
		$HTTP_RESPONSE = 404;
		$BODY = '';
		}

	my @HEADERS = ();
	foreach my $k (keys %HEADERS) {
		push @HEADERS, [ $k, $HEADERS{$k} ];
		}

	## print STDERR Dumper($HTTP_RESPONSE, \@HEADERS, [ $BODY ]);
	## return [ $HTTP_RESPONSE, \@HEADERS, [ $BODY ] ];
	
	## the 'Content-Length' header below caused one of the most tramautic 24 hours in my life -- ask me about it.
	## change at your own peril. -BH 5/18/13

	$HEADERS{'Content-Length'} = length($BODY);
	my $res = Plack::Response->new($HTTP_RESPONSE,\%HEADERS,$BODY);
	return($res->finalize);
	};




##
## 
##
sub generate_counter_image {
	my ($SERIES,$COUNTER) = @_;

	##
	## SANITY: from here on out $COUNTER has the number we ought to generate.
	##
	$SERIES = lc($SERIES);

	my $facount = sprintf("%04d", $COUNTER);

	##this is the first two digits of the count, used to find the directory that the correct immage is in.
	my $twodigimg = substr($facount,0,2);
	my $output = '';


	my %CHAR = ();
	my $PATH = "/httpd/static/counters/";
	my $CACHEDIR = "/local/cache/_counters";

	my $CACHEFILE = "$CACHEDIR/$COUNTER--$SERIES.gif";

	if ( -f $CACHEFILE ) { 
		# /httpd/counters/katt014/00/katt0141.gif 	# image #1
		open F, "<$CACHEFILE"; $/ = undef;
		$output = <F>;
		close F;
		$/ = "\n";
		}
	else {
		my $digit_dir =  "/httpd/static/counters/$SERIES/original";
		my $flyprog = "/httpd/static/counters/fly -q";
		my $fly_temp ="/tmp/fly_temp.txt".$$.time();

	   ### IMAGE SETTINGS ###

		########################################################################################
		##find image height and width
	
		#		my $filename="/httpd/counters/" . $COUNTER . "/original/0.gif";
		#
		#		my $im = Image::Magick->new();
		#		$im->Read($filename);
		#
		#		my $width = $im->Get('width');	
		#		my $height= $im->Get('height');
		#
		#		print STDERR "width and height are $width:$height\n";
		my $width = -1; my $height = -1;
		open F, "</httpd/static/counters/$SERIES/info.txt"; $/ = undef; my $buf = <F>; close F; $/ = "\n";
		foreach my $kv (split(/\&/s,$buf)) {
			my ($k,$v) = split(/=/,$kv);
			if ($k eq 'w') { $width = $v; }
			if ($k eq 'h') { $height = $v; }
			}

		my $tp = "1";
		my $il = "1";

		# Done 
		##############################################################################
		######### create the series directory

		#BAM -- total length -- Determines the total length of the final graphic
		my $glength = 4;

		# Determine Length of Counter Number
		my $length;
	  	my $num = $length = length($COUNTER);

		# Set Individual Counter Numbers Into Associative Array
		my $tmpcount = $COUNTER;
		while ($num>0) {
			$CHAR{$num} = chop($tmpcount);
			$num--;
			}

		# BH Figure out which directory we ought to be in.
		# BH Right justify directory name

		my $dir = sprintf("%s/%d",$COUNTER,int($COUNTER /100));

		# Determine the Height and Width of the Image
		my $img_width = ($width * $glength); 
		my $img_height = ($height);
		my $insert_width = 0;
		my $insert_height = 0;
	
		# Open the In-File for Commands
		open(FLY,">$fly_temp") || die "Can't Open In File For FLY Commands: $!\n";

		# Create New Counter Image
		print FLY "new\n";
		print FLY "size $img_width,$img_height\n";

		## BAM -- this should make zeros in front of the number.
		my $gh =  $glength - $length;
		while ($gh > 0) {
				print FLY "copy $insert_width,$insert_height,-1,-1,-1,-1,$digit_dir/0.gif\n";
				$insert_width = ($insert_width + $width); 
				$gh--;
				}

		# Copy Individual Counter Images Commands to In-File
		my $j = 1;
		while ($j <= $length) {
				print FLY "copy $insert_width,$insert_height,-1,-1,-1,-1,$digit_dir/$CHAR{$j}\.gif\n";
				$insert_width = ($insert_width + $width); 
				$j++;
			}
	
		# If they want a color transparent, make it transparent
		if ($tp ne "X" && $tp =~ /.*,.*,.*/) {
			print FLY "transparent $tp\n";
			}
	
		# If they want the image interlaced, make it interlaced
		if ($il == 1) {
			print FLY "interlace\n";
			}

		# Close FLY
		close(FLY);

		$output = `$flyprog -i $fly_temp`;

		if (($COUNTER < 100) && ($output ne '')) {
			mkdir($CACHEDIR); chmod 0777, $CACHEDIR;
			open F, ">$CACHEFILE";
			print $output;
			close F;
			}
		}

	if ($output eq '') { 
		warn "no output - loading blank image\n";
		open F, "</httpd/htdocs/images/blank.gif"; $output = <F>; close F; 
		}

	return($output);
	}







##
##
##
sub buildNavbutton {
	my ($URI, $HEADERSREF) = @_;

	my $DEBUG = 0;	
	my $uriinfo = '';
	my $header = 1;

	$DEBUG = 1;

	# use Data::Dumper; print Dumper(\%ENV);

	## URI should only have 
	## /graphics/navbuttons/l2_raspberry_off_w135_h18/home.gif

	##
	## BH: don't ask me to explain what this does - i pulled it from the apache rewrite rules.
	##
	## remove the /media (if it's present, and it's *definitely* optional)

	print STDERR "URI[$URI]\n";

	$URI =~ s/^\/media\//\//o;
	print STDERR "URI[$URI]\n";

	## remove the /graphics/navbuttons
	$URI = substr($URI,21); 	
	## remove the .gif
	$URI = substr($URI,0,-4);	

	$DEBUG && print STDERR "xx NAVBUTTON: \$URI is '$URI'\n";

	## THIS LINE BREAKS SHIT:  (like uri encoded spaces, and junk like that)
	# $URI =~ s/[^\w\/]//gis; # Get rid of anything other than alphanum and underscore

	##
	##
	##
	## apparently these two are the same thing:
	##		http://static.zoovy.com/graphics/navbuttons/toynk_w57_h27/Costumes.gif
	##		http://static.zoovy.com/graphics/navbuttons/toynk_w57_h27__Costumes.gif
	##
	unless (defined($URI) && ($URI ne '') && ($URI =~ m/^([a-z0-9\_]+)(__|\/)(.*)$/)) {
		$HEADERSREF->{'Content-Type'} = 'image/gif';
		return(pack("H84", "4749463839610100010080FF00C0C0C000000021F90401000000002C000000000100010000010132003B"));
		}

	## NOTE: $type is MAY still contain height and width (we'll strip it in a second)
	my $type	  = defined($1) ? $1 : '';
	my $width	 = '';
	my $height   = '';
	## NOTE: $2 is either __ or /
	my $message  = defined($3) ? $3 : '' ;

	if ((index($type,"_h")>=0) || (index($type,"_w")>=0)) {
		## Handle embedded height _h#### and width _w###
		if ($type =~ /^(.*?)(_w[\d]+)?(_h[\d]+)?$/) {
			$type = $1;
			$width = defined($2) ? $2 : ''; 
			$height = defined($3) ? $3 : ''; 
			}
		if ($height ne '') { $height = substr($height,2); } # strip leading _h from width
		if ($width ne '') { $width = substr($width,2); } 	# strip leading _w from width
		}
	
	$DEBUG = 0;
	if ($DEBUG) {
		print STDERR "NAVBUTTON: \$type initialized to '$type'\n";
		print STDERR "NAVBUTTON: \$width initialized to '$width'\n";
		print STDERR "NAVBUTTON: \$height initialized to '$height'\n";
		print STDERR "NAVBUTTON: \$message initialized to '$message'\n";
		}


	$message =~ s/\_\_/ /g; # Swap two underscores for a space
	# Swap all underscores followed by two hex with the ascii Equivalent of the hex.
	# Like %20 syntax in GET's except with an underscore instead of %
	$message =~ s/\_([0-9A-Fa-f][0-9A-Fa-f])/chr(hex($1))/eg;
	$message =~ s/\_/ /gs;
	$message =~ s/\s+/ /gs;

	if ($message eq '') { $message = ' '; }

	$type = substr($type,0,30); # Maximum length of a button type [NAME] is 30 characters

	##############################################################################
	# Read in the parameters for the button

	my $button_info = &NAVBUTTON::button_info(
		'',
		$type,
		$width,
		$height,
		[$message],
		);

	my ($cfg,$widths,$heights,$lines) = @{$button_info->[0]};

	##############################################################################
	# Dump what we have so far

	if ($DEBUG) {
		print STDERR "NAVBUTTON: URI: '$URI'\n";
		print STDERR "NAVBUTTON: type : '$type'\n";
		print STDERR "NAVBUTTON: message : '$message'\n";
		foreach (sort keys %{$cfg}) { print STDERR "NAVBUTTON: cfg $_ : '$cfg->{$_}' \n"; }
		}

	##############################################################################
	# Create the image

	# $lines->[0] .= $cfg->{'width'} . 'x' . $cfg->{'height'};

	my $image = Image::Magick->new('size' => $cfg->{'width'} . 'x' . $cfg->{'height'});
	$image->Read('xc:' . $cfg->{'bgcolor'});

	########################################
	# Load the background

	my $bg_file = '';
	if ($cfg->{'bgimage'} ne '') {
		$bg_file = $cfg->{'dir'}."/".$cfg->{'bgimage'};
		# print STDERR $bg_file."\n";
		}


	if ($bg_file) {
		my $bg_temp = Image::Magick->new();
		if (my $error = $bg_temp->Read("$bg_file")) {
			# Threw an error
			print "Unable to open file $bg_file because $error\n";
		}
		else {
			if ($cfg->{'stretch'}) {
				if (my $error = $bg_temp->Sample('width' => $cfg->{'width'}, 'height' => $cfg->{'height'})) {
					print "Unable to open file $bg_file for resampling because $error\n";
				}
				else {
					$image = $bg_temp;
				}
			}
			else {
				if ($cfg->{'random'}) {
					my $bg_width = $bg_temp->Get('width');
					my $bg_height = $bg_temp->Get('height');
					if (($bg_width >= $cfg->{'width'}) && ($bg_height >= $cfg->{'height'})) {
						# We use the message as the seed so we always produce the same
						# background for the same message
						srand (unpack "%32L*", $message); 
						my $x = int(rand($bg_width-$cfg->{'width'}+1));
						my $y = int(rand($bg_height-$cfg->{'height'}+1));
						$bg_temp->Crop(
							'width' =>  $cfg->{'width'},
							'height' => $cfg->{'height'},
							'x' => $x,
							'y' => $y,
						);
					}
				}
				if (my $error = $image->Texture('texture' => $bg_temp)) {
					print "Unable to open file $bg_file for texturing because $error\n";
					$image->Read('xc:' . $cfg->{'bgcolor'});
				}
			}
		}
	}

	## height: total height of the button
	## padding_top: upper margin
	## padding_bottom: lower martin
	## border_y: the size of the border on the y axis's.
	## usable_height: is the amount of room left for text
	my $usable_height = ($cfg->{'height'} - $cfg->{'padding_top'} -	$cfg->{'padding_bottom'} -	($cfg->{'border_y'} * 2));
	## if we don't have enough USABLE HEIGHT then start the text at the very top regardless of where it should be.
	if ($cfg->{'text_height'} > $usable_height) { 
		# $lines->[0] .= "($cfg->{'height'} - $cfg->{'padding_top'} -   $cfg->{'padding_bottom'} - ($cfg->{'border_y'} * 2));"; 
		$cfg->{'align_y'} = 'top'; 
		}
		
	
	########################################
	# Add the text
	my $count = 0;
	my $y_offset = $cfg->{'offset_y'};		## 
	my @PRETEXT = ();
	my @TEXT = ();
	foreach my $line (@{$lines}) {
	
		my $line_height = $heights->[$count];
		my $line_width = $widths->[$count];
	
		# Get the X-axis offset
		my $x_offset = $cfg->{'offset_x'};
		if ($cfg->{'align_x'} eq 'center') {
			$x_offset += int(($cfg->{'width'} / 2) - ($line_width / 2) + 0.5);
			}
		elsif ($cfg->{'align_x'} eq 'right') {
			$x_offset += ($cfg->{'width'} - $line_width - $cfg->{'border_x'} - $cfg->{'padding_right'});
			}
		if (($cfg->{'align_x'} eq 'left') || ($x_offset < 0)) {
			$x_offset += ($cfg->{'border_x'} + $cfg->{'padding_left'});
			}
		
		# Set the Y-axis offset
		my $line_y_offset = $cfg->{'f_ascender'} + $y_offset;
		# $line .= $cfg->{'align_y'}.' - '.$cfg->{'get_height'};
		if (($cfg->{'align_y'} eq 'top') ||	$cfg->{'get_height'}) {
			$line_y_offset += ($cfg->{'border_y'} + $cfg->{'padding_top'});
			}
		elsif ($cfg->{'align_y'} eq 'center') {
			## don't round (this usually shifts us down one more than we intended)
			# $line_y_offset += int(($cfg->{'height'} / 2) - ($cfg->{'text_height'} / 2) + 0.5);
			$line_y_offset += int(($cfg->{'height'} / 2) - ($cfg->{'text_height'} / 2));
			}
		elsif ($cfg->{'align_y'} eq 'bottom') {
			$line_y_offset += ($cfg->{'height'} - $cfg->{'text_height'} - $cfg->{'border_y'} - $cfg->{'padding_bottom'});
			}
		$y_offset += $line_height;

		if ($cfg->{'highlight'}) {
			push @PRETEXT, {
				'text' => "$line ",
				'font' => '@'.$cfg->{'font'},
				'pointsize' => $cfg->{'font_size'},
				'x' => ($x_offset - $cfg->{'highlight_offset_x'}),
				'y' => ($line_y_offset - $cfg->{'highlight_offset_y'}),
				'fill' => $cfg->{'highlight_color'},
				'antialias'=>'true',
				};
			}

		if ($cfg->{'shadow'}) {
			## a shadow is located at x_offset+shadow_offset_x
			push @PRETEXT, {
				'text' => "$line ",
				'font' => '@'.$cfg->{'font'},
				'pointsize' => $cfg->{'font_size'}+0,
				'x' => ($x_offset + $cfg->{'shadow_offset_x'}),
				'y' => ($line_y_offset + $cfg->{'shadow_offset_y'}),
				'fill' => $cfg->{'shadow_color'},
				'antialias'=>'true',
				};
			}


		push @TEXT, {
			'text' => "$line ", # Added the space because of some really weird encoding issues with anythign that ended with a %
			'font' => '@'.$cfg->{'font'},
			'pointsize' => $cfg->{'font_size'},
			'x' => $x_offset+0,
			'y' => $line_y_offset+0,
			'fill' => $cfg->{'text_color'},
			'antialias'=>'true',
#			'strokewidth'=>'1',
#			'strokecolor'=>'#FF0000',

#			'weight'=>10,
## doesn't seem to work:
#			'stretch'=>'Condensed'
			};
			
		$count++;
		}

	if (scalar(@PRETEXT)>0) {
		## this will apply any highlights and shadows
		foreach my $cmd (@PRETEXT) { $image->Annotate(%{$cmd}); }

		if (not $cfg->{'blur'}) { $cfg->{'blur'} = 1; }	## implicitly enable blur
		if ($cfg->{'blur'}) {
			$image->Blur( 'sigma' => $cfg->{'blur'} );
			}
		}	

	########################################
	# Add any borders
	if ($cfg->{'border_type'} eq 'bevel') {
		$image->Raise('raise' => 'True', 'width' => $cfg->{'border_x'}, 'height' => $cfg->{'border_y'});
		}
	elsif ($cfg->{'border_type'} eq 'plain') {
		$image->Shave(width=>$cfg->{'border_x'},height=>$cfg->{'border_y'});
		$image->Border(
			'color' => $cfg->{'border_color'},
			'width' => $cfg->{'border_x'},
			'height' => $cfg->{'border_y'},
			# 'compose' => 'Atop',
			);
		}

	
	## This actually adds the text to the image:
	#use Data::Dumper; print STDERR Dumper(\@TEXT);
	foreach my $cmd (@TEXT) { $image->Annotate(%{$cmd}); }


	####################################################
	# Create the image
	
	# $image->Set(Size=>$cfg->{'width'} . 'x' . $cfg->{'height'});
	$image->Set('magick'=>'gif');
	my $BODY = $image->ImageToBlob();
	
	##############################################################################
	# Output the header and graphic

	$HEADERSREF->{'Content-Type'} = 'image/gif';
	my $mtime = time()-(86400*7);
	$HEADERSREF->{'Last-Modified'} = HTTP::Date::time2str($mtime);
	# $image->Write('gif:-');
	# $r->print($gif);
	
	undef $URI;
	undef $header;
	undef $message;
	undef $type;
	undef $width;
	undef $height;
	undef $cfg;
	undef $widths;
	undef $heights;
	undef $lines;
	undef $image;
	undef $bg_file;
	undef $count;
	undef $y_offset;
	undef $button_info;

	return($BODY);
	}








__DATA__


use CGI::PSGI;

my $app = sub {
    my $env = shift;
    my $q = CGI::PSGI->new($env);
    return [ 
        $q->psgi_header('text/plain'),
        [ "Hello ", $q->param('name') ],
    ];
};

