package BATCHJOB::UTILITY::SITEMAP;

use Data::Dumper;
use lib "/backend/lib";

require SITE;
require NAVCAT;
require DOMAIN::QUERY;
use ZOOVY;
require PRODUCT;
use DBINFO;
use LISTING::MSGS;
use strict;



## the safe uuid for sitemaps can be passed in as "UUID" it's basically for translating safenames
## it's basically for translating safenames ex: .asdf.asdf.asdf to --ASDF--ASDF--ASDF 
##	which can then be called as www.domain.com/sitemap---ASDF--ASDF--ASDF and matched as
##	/sitemap-(.*?).xml then loaded as sitemap_file(username,profile,$1) 
## in other words: a safe uuid, passed as a uuid, will result in the same safe uuid
sub sitemap_safe_uuid {
	my ($UUID) = @_;
	$UUID = uc($UUID);
	$UUID =~ s/\./--/gs;
	$UUID =~ s/[^A-Z0-9\-]+//gs;
	return($UUID);
	}


##
## 
##
sub sitemap_file {
	my ($USERNAME,$DOMAINNAME,$UUID) = @_;
	
	# my $staticfile = &ZOOVY::resolve_userpath($USERNAME)."/IMAGES/sitemap_$NS.xml";
	my $staticfile = '';
	if ((not defined $UUID) || ($UUID eq '')) {
		## main file
		$staticfile = &ZOOVY::resolve_userpath($USERNAME)."/PRIVATE/$USERNAME-$DOMAINNAME-GSM.out";
		}
	else {
		$UUID = &BATCHJOB::UTILITY::SITEMAP::sitemap_safe_uuid($UUID);
		$staticfile = &ZOOVY::resolve_userpath($USERNAME)."/PRIVATE/$USERNAME-$DOMAINNAME-GSM-$UUID.out";
		}

	print STDERR "STATIC SITEMAP: $staticfile\n";
	
	return($staticfile);
	}


##
## 
##


sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	
	## WORK OUT ALL THE BASE CRAP
	my $USERNAME = $bj->username();
	my $lm = $bj->lm();
	my $PRT = $bj->prt();
	my ($DOMAINNAME,$ROOTCAT) = ($bj->domain(),'.');	## hardcoded to . for now
	my $HOST = 'www';
	my $base = sprintf("http://%s.%s",$HOST,$DOMAINNAME);

	my $NC = NAVCAT->new($USERNAME, root=>$ROOTCAT, cache=>&ZOOVY::touched($USERNAME),PRT=>$PRT);	

	## INSTANTIATE GLOBAL OBJECTS
	my $TMPDIR = sprintf("%s/sitemap.%s.%d",&ZOOVY::tmpfs(),"sitemap",$bj->id());
	mkdir $TMPDIR;
	chmod 0755, $TMPDIR;

	my $IS_APP = 0;
	my $mainfile = sprintf("%s/sitemap.xml",$TMPDIR);
	my @URLS = ();
	my $counter = 0xFFFFFFFF;

	## LINK SYNTAX v2.
	my %URLS = (
		'url.product'=>'#!/product/{PID}/{zoovy:prod_name}.html',
		'url.category'=>'#!/category/{safe}',
		'url.customer'=>'#!/customer/',
		'url.orderstatus'=>'#!/customer/orderstatus',
		'url.contact'=>'#!/contact_us.cgis',
		'url.policies'=>'#!/about_us.cgis',
		'url.privacy'=>'#!/privacy.cgis',
		);

	## PHASE1: load an custom urls from project/config.js
	if (1) {
		print STDERR "Doing custom pages\n";
		## homepage should be priority 1.00
		#my %PAGES = &SITE::site_pages();
		#foreach my $page (keys %PAGES) {
		#	next unless ($PAGES{$page} & 64);	# 
		#	next if ($counter-- <= 0);
		#	next if (($page eq 'category') || ($page eq 'product') || ($page eq 'homepage') || ($page eq 'login')); 
		#	push @URLS, [ "/$page.html", "0.25" ];
		#	}
		}

	print STDERR "Doing paths\n";
	my %ALREADY_DID_PRODUCTS = ();
	foreach my $path ($NC->paths($ROOTCAT)) {
		next if ($counter-- <= 0);
		next if ($path eq '.');	# avoid root category so we don't generate $base/category//

		my @inforef = $NC->get($path);
		next if (($path ne $ROOTCAT) && (substr($inforef[0],0,1) eq '!'));	# skip hidden categories
		next if (substr($path,0,1) eq '$');		# skip lists
		my $metaref = $inforef[4];

		## category priority is determined by the depth of the category 
		my $priority = "0.80";
		my $l = $path;
		$l =~ s/[^\.]//go;
		$l = length($l);
		if ((defined $metaref) && ($metaref->{'MAP'})) {
			$priority = sprintf("%.2f",$metaref->{'MAP'});
			}
		elsif ($l == 1) { $priority = "0.80"; }
		elsif ($l == 2) { $priority = "0.60"; }
		elsif ($l == 3) { $priority = "0.40"; }
		else { $priority = "0.20"; }
		push @URLS, [ '/category/'.substr($path,1).'/', $priority ];

		foreach my $pid (split(/\,/,$inforef[2])) {
			$pid = uc($pid);
			next if ($pid eq '');
			next if ($ALREADY_DID_PRODUCTS{$pid});

			$ALREADY_DID_PRODUCTS{$pid}++; 
			my $priority = "0.50";		
			my ($P) = PRODUCT->new($USERNAME,$pid,'create'=>0);
			if (not defined $P) {
				$lm->pooshmsg("WARN|Product '$pid' could not be loaded from category $path");
				$priority = undef;
				}
			elsif ($P->fetch('zoovy:prod_seo_priority')) { 
				## if prod_seo_priority is set - that ALWAYS wins. 
				$priority = sprintf("%.2f",$P->fetch('zoovy:prod_seo_priority'));
				}
			else {
				## auto-algorithm -- uses the product tags to determine the priority
				if ($P->fetch('is:discontinued')) { 
					$priority = "0.00"; 	
					}
				elsif (($P->fetch('is:preorder')) || ($P->fetch('is:fresh')) || ($P->fetch('is:newarrival'))) {
					$priority = "0.90"; 
					}
				elsif (($P->fetch('is:bestseller')) || ($P->fetch('is:sale'))) {
					$priority = "0.80";
					}
				else {
					$priority = "0.50"; 
					}
				## for each is:user1 .. is:user8 we add +0.05 
				foreach my $bit (1..8) {
					if ($P->fetch("is:user$bit")) { $priority += "0.05"; }
					}	

				## priority can never exceed 1.00
				if ($priority > 1) { $priority = "1.00"; }
		
				## and make sure it always has two decimal places.
				$priority = sprintf("%.2f",$priority);
				}

			if (defined $priority) {
				my ($url) = $P->public_url();
				if ($IS_APP) {
					## if we're using an app (seo compat) then we should use escaped fragments
					## https://developers.google.com/webmasters/ajax-crawling/docs/specification
					## https://developers.google.com/webmasters/ajax-crawling/docs/specification
					$url = sprintf("%s#!sitemap",$url);
					}
				push @URLS, [ $url, $priority ];
				}
				
			}
		}

	my $xml = '';
	if (scalar(@URLS)==0) {
		}
	elsif (scalar(@URLS)<50000) {
		## one big file, statically published.
		$xml .= qq~<?xml version="1.0" encoding="UTF-8"?>\n~;
		$xml .= "<!-- generated=".ZTOOLKIT::pretty_date(time(),1)." domain=$DOMAINNAME prt=$PRT rootpath=$ROOTCAT base=$base is_static=1 -->\n";
		$xml .= qq~<urlset xmlns="http://www.google.com/schemas/sitemap/0.84">\n~;
		foreach my $url (@URLS) {
			$xml .= "<url><loc>$base$url->[0]</loc><priority>$url->[1]</priority></url>\n";
			}
		$xml .= qq~</urlset>\n~;

		open F, ">".&BATCHJOB::UTILITY::SITEMAP::sitemap_file($USERNAME,$DOMAINNAME,undef);
		print F $xml;
		close F;

		my $msg = "Generated 1 static file ".length($xml)." bytes";
      # $so->addsummary("NOTE",NOTE=>$msg);
		$lm->pooshmsg("SUCCESS|+$msg");
		}
	else {
		##
		## we need to generate multiple files, in chunks, since we have more than 50,000
		##
		my @CHUNKS = ();
		my $i = 0;
		my $chunkxml = '';
		foreach my $url (@URLS) {
			$chunkxml .= "<url><loc>$base$url->[0]</loc><priority>$url->[1]</priority></url>\n";
			$i++;
			if ($i>=50000) {
				push @CHUNKS, $chunkxml;
				$i=0; $chunkxml = '';
				}
			}
		if (($chunkxml ne '') || ($i>0)) {
			push @CHUNKS, $chunkxml;
			}
		$chunkxml = '';
		## SANITY: at this point @CHUNKS is an array of files we should write, we need to add xml headers and footers

		my $gmtdatetime = &ZTOOLKIT::pretty_date(time(),6);
		my $totalchunkssize = 0;

		$xml .= qq~<?xml version="1.0" encoding="UTF-8"?>\n~;
		$xml .= "<!-- generated=".ZTOOLKIT::pretty_date(time(),1)." domain=$DOMAINNAME prt=$PRT rootpath=$ROOTCAT base=$base is_static=1 -->\n";
		$xml .= qq~<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n~;
		$i = 0;
		foreach my $CHUNK (@CHUNKS) {
			$i++;
			$CHUNK = qq~<?xml version="1.0" encoding="UTF-8"?>\n~.
				"<!-- generated=".ZTOOLKIT::pretty_date(time(),1)." domain=$DOMAINNAME prt=$PRT rootpath=$ROOTCAT base=$base is_static=1 -->\n".
				qq~<urlset xmlns="http://www.google.com/schemas/sitemap/0.84">\n~.
				$CHUNK.
				qq~</urlset>\n~;

			my $UUID = &BATCHJOB::UTILITY::SITEMAP::sitemap_safe_uuid("chunk-$i");
			my $url = "http://$DOMAINNAME/sitemap-$UUID.xml";
 			$xml .= qq~<sitemap><loc>$url</loc><lastmod>$gmtdatetime</lastmod></sitemap>\n~;

			my $file = &BATCHJOB::UTILITY::SITEMAP::sitemap_file($USERNAME,$DOMAINNAME,$UUID);
			print STDERR "Generating $file\n";
	      open F, ">$file";
			print F $CHUNK;
			close F;
			chown $ZOOVY::EUID,$ZOOVY::EGID, $file;
			
			$totalchunkssize += length($CHUNK);
			}

		$xml .= qq~</sitemapindex>\n~;

		open F, ">".&BATCHJOB::UTILITY::SITEMAP::sitemap_file($USERNAME,$DOMAINNAME,undef);
		print F $xml;
		close F;

		my $msg = "Generated $i chunk files ($totalchunkssize bytes)";
     #  $so->addsummary("NOTE",NOTE=>$msg);
		$lm->pooshmsg("SUCCESS|+$msg");				
		}

	# http://search.cpan.org/~jasonk/Search-Sitemap/
	# http://www.seroundtable.com/archives/013113.html
	# <searchengine_URL>/ping?sitemap=sitemap_url
	# Ask.com: http://submissions.ask.com/ping?sitemap=http%3A//www.domain.com/sitemap.xml 
	# Google: http://www.google.com/webmasters/sitemaps/ping?sitemap=http:%3A//www.domain.com/sitemap.xml 
	# Yahoo: http://search.yahooapis.com/SiteExplorerService/V1/updateNotification?appid=YahooDemo&url=http://www.domain.com/sitemap.xml
	# http://search.yahooapis.com/SiteExplorerService/V1/updateNotification?appid=YahooDemo&url=http%3A%2F%2Fwww.MySite.com%2Fsitemap.xml.gz
	# http://search.yahooapis.com/SiteExplorerService/V1/ping?sitemap=http%3A%2F%2Fwww.MySite.com%2Fsitemap.xml.gz
	# Bing: http://bing.com/ping?sitemap.xml=http://www.somedomain.com/sitemap.xml
	# http://webmaster.live.com/webmaster/ping.aspx?siteMap=http%3A%2F%2Fwww.MySite.com%2Fsitemap.xml.gz
	# http://api.moreover.com/ping?u=http%3A%2F%2Fwww.MySite.com%2Fsitemap.xml.gz


	$bj->progress(1,1,"Finished Building Sitemap");


   return();
	}


##
## logs an internal googlebase error.
##
sub log {
  my ($self,$pid,$err) = @_;

  if (not defined $self->{'@errs'}) {
    $self->{'@errs'} = [];
    }
  push @{$self->{'@errs'}}, $err;
  return();
  }


  


1;