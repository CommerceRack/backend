package BATCHJOB::EXPORT::SEO;

use strict;

##
##
##
sub generate {
	my ($bj) = shift;


	my ($USERNAME) = $bj->username();
	my ($PRT) = $bj->prt();

	my ($DOMAIN) = $bj->domain();
	my ($D) = DOMAIN->new($bj->username(),$DOMAIN);

	my $SDOMAIN = "www.$DOMAIN";

	require PRODUCT::FLEXEDIT;
	my $CANONICAL_URL = undef;

	my $LM = $self->so()->msgs();
	
	if (not defined $so) {
		die("No syndication object");
		}
	my $prt = $so->prt();
	my ($DOMAIN,$ROOTCAT) = $so->syn_info();
	my $DOMAINNAME = $DOMAIN;
	
	my $base = "http://www.$DOMAIN";

	require DOMAIN::QUERY;
	my ($DNSINFO) = DOMAIN::QUERY::lookup($DOMAINNAME,'WWW');

	## my ($HOST) = DOMAIN->new($DOMAIN)->hostinfo('www');
	## my ($DNSINFO) = &DOMAIN::QUERY::lookup($DOMAIN);
	## my ($HOSTINFO) = ->new('WWW',$so->domain());
	my $IS_APP = 0;
	# if ($HOST->type() eq 'APP') { $IS_APP++; }
	#if ($DNSINFO->{'WWW_HOST_TYPE'} eq 'APP') {
	#	$IS_APP++;
	#	$LM->pooshmsg("+INFO|Detected APP hosting on $DOMAIN");
	#	}

   my $mainfile = &SYNDICATION::SITEMAP::sitemap_file($USERNAME,$DOMAINNAME);
   print "FILE: $mainfile\n";
	my $strategy = $so->get('.strategy');
	print "STRATEGY: $strategy\n";

	my @URLS = ();

	my ($NC) = $so->nc();
	if (not defined $NC) {
		$NC = NAVCAT->new($USERNAME, root=>$ROOTCAT, cache=>&ZOOVY::touched($USERNAME),PRT=>$prt);	
		}

   if (not $so->get('.enable')) {
      unlink $mainfile;
      # $so->addsummary("NOTE",NOTE=>"Removing static file - not enabled.");
		$LM->pooshmsg("STOP|+File generation not enabled (removing file)");
		}
	else {
		my $counter = 0xFFFFFFFF;

		
		if ($IS_APP) {
			$LM->pooshmsg("DEBUG|+Ignoring legacy pages due to APP hosting");
			}
		elsif ($ROOTCAT eq '.') {
			print STDERR "Doing pages\n";
			## homepage should be priority 1.00
			my %PAGES = &SITE::site_pages();
			foreach my $page (keys %PAGES) {
				next unless ($PAGES{$page} & 64);	# 
				next if ($counter-- <= 0);
				next if (($page eq 'category') || ($page eq 'product') || ($page eq 'homepage') || ($page eq 'login')); 
				push @URLS, [ "/$page.html", "0.25" ];
				}
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
					$LM->pooshmsg("WARN|Product '$pid' could not be loaded from category $path");
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
					my ($url) = $P->public_url('style'=>'vstore');
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
		}


	my $xml = '';
	if (scalar(@URLS)==0) {
		}
	elsif (scalar(@URLS)<50000) {
		## one big file, statically published.
		$xml .= qq~<?xml version="1.0" encoding="UTF-8"?>\n~;
		$xml .= "<!-- generated=".ZTOOLKIT::pretty_date(time(),1)." domain=$DOMAIN prt=$prt rootpath=$ROOTCAT base=$base is_static=1 -->\n";
		$xml .= qq~<urlset xmlns="http://www.google.com/schemas/sitemap/0.84">\n~;
		foreach my $url (@URLS) {
			$xml .= "<url><loc>$base$url->[0]</loc><priority>$url->[1]</priority></url>\n";
			}
		$xml .= q~</urlset>~;

		my $msg = "Generated 1 static file ".length($xml)." bytes";
      # $so->addsummary("NOTE",NOTE=>$msg);
		$self->so()->msgs()->pooshmsg("SUCCESS|+$msg");
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
		## SANITY: at this point @CHUNKS is an array of files we should write, we need to add xml headers and footer_productss

		my $gmtdatetime = &ZTOOLKIT::pretty_date(time(),6);
		my $totalchunkssize = 0;

		$xml .= qq~<?xml version="1.0" encoding="UTF-8"?>\n~;
		$xml .= "<!-- generated=".ZTOOLKIT::pretty_date(time(),1)." domain=$DOMAIN prt=$prt rootpath=$ROOTCAT base=$base is_static=1 -->\n";
		$xml .= qq~<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n~;
		$i = 0;
		foreach my $CHUNK (@CHUNKS) {
			$i++;
			$CHUNK = qq~<?xml version="1.0" encoding="UTF-8"?>\n~.
						"<!-- generated=".ZTOOLKIT::pretty_date(time(),1)." domain=$DOMAIN prt=$prt rootpath=$ROOTCAT base=$base is_static=1 -->\n".
						qq~<urlset xmlns="http://www.google.com/schemas/sitemap/0.84">\n~.
						$CHUNK.
						qq~</urlset>\n~;

			my $UUID = &SYNDICATION::SITEMAP::sitemap_safe_uuid("chunk-$i");
			my $url = "http://$DOMAIN/sitemap-$UUID.xml";
 			$xml .= qq~<sitemap><loc>$url</loc><lastmod>$gmtdatetime</lastmod></sitemap>\n~;

			my $file = &SYNDICATION::SITEMAP::sitemap_file($USERNAME,$DOMAINNAME,$UUID);
			print STDERR "Generating $file\n";
	      open F, ">$file";
			print F $CHUNK;
			close F;
			chown $ZOOVY::EUID,$ZOOVY::EGID, $file;
			
			$totalchunkssize += length($CHUNK);
			}

		$xml .= qq~</sitemapindex>\n~;

		my $msg = "Generated $i chunk files ($totalchunkssize bytes)";
     #  $so->addsummary("NOTE",NOTE=>$msg);
		$self->so()->msgs()->pooshmsg("SUCCESS|+$msg");				
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

	


	if ($r->uri() =~ /^\/category\/(.*?)$/o) {
		## START of /category handling
		my $ORIGINALPATH = my $CLEANEDPATH = $1;
		if ($CLEANEDPATH !~ /\/$/) { $CLEANEDPATH .= "/"; }
		$CLEANEDPATH =~ s/[\/]+/\//gs;
		$CLEANEDPATH = lc($CLEANEDPATH);
		$CANONICAL_URL = "/category/$CLEANEDPATH";

		my $SAFEPATH = $CLEANEDPATH;
		$SAFEPATH =~ s/\//\./gs;
		$SAFEPATH =~ s/[^a-zA-Z0-9\-\_\.]//gs;
		# $SAFEPATH =~ s/\.+/\./gos; # make multiple dots into a single (useful if we prepended an extra at the begining for some reason)
		if (substr($SAFEPATH,0,1) ne '.') { $SAFEPATH = ".$SAFEPATH"; }
		if (substr($SAFEPATH,-1) eq '.') { $SAFEPATH = substr($SAFEPATH,0,-1); }

		if ($CLEANEDPATH eq '/') {
			$REDIRECT = '/';
			}
		elsif ($CLEANEDPATH ne $ORIGINALPATH) {
			$REDIRECT = "/category/$CLEANEDPATH";
			# $body = "CLEAN:$CLEANEDPATH ne ORIG:$ORIGINALPATH";
			}
		else {
			my ($NC) = $SITE->get_navcats();
			my ($modified_gmt) = $NC->modified($SAFEPATH);
			if ($modified_gmt<=0) {
				$REDIRECT = "/";
				# $body = "MODIFIED: $modified_gmt SAFE:$SAFEPATH\n";
				}
			else {
				# $body = "SAFEPATH: $SAFEPATH\n";
				my ($pretty,$children,$products,$sort,$metaref,$modified_gmt) = $NC->get($SAFEPATH);
				$body .= "<h1>$pretty</h1>";

				$META{'title'} = $pretty;

				my ($bcorder,$bcnames) = $NC->breadcrumb($SAFEPATH);
				unshift @{$bcorder}, ".";
				$bcnames->{'.'} = 'Home';
				if (scalar(@{$bcorder})>0) {
					my @links = ();
					foreach my $bcsafe (@{$bcorder}) {
						push @links, sprintf("<span><a href=\"/category/%s\">%s</a></span>\n",substr($bcsafe,1),$bcnames->{$bcsafe});
						}
					$body .= join(" | ",@links);
					}

				$body .= "<ul class=\"subcategories\">";
				foreach my $childsafe (@{$NC->fetch_childnodes($SAFEPATH)}) {
					my ($childpretty,$childchildren,$childproducts,$childsort,$childmetaref,$childmodified_gmt) = $NC->get($childsafe);
					next if (substr($childpretty,0,1) eq '!');
					$body .= "<li> <a href=\"/category/$childsafe\"> $childpretty</a>";
					}
				$body .= "</ul>";

				my ($PG) = $SITE->pAGE($SAFEPATH);
				$body .= sprintf("<div id=\"description\" name=\"description\">%s</div>\n",$PG->get('desciption'));

				$META{'keywords'} = $PG->get('meta_keywords');
				$META{'description'} = $PG->get('meta_description');
				if ($PG->get('page_title') ne '') {
					$META{'title'} = $PG->get('page_title');
					}
			
				$body .= "<hr>";
	
				foreach my $PID (split(/,/,$products)) {
					next if ($PID eq '');
					my ($P) = PRODUCT->new($SITE->username(),$PID,'create'=>0);
					my $url = $P->public_url('style'=>'vstore');
					my $src = &ZOOVY::image_path($SITE->username(),$P->fetch('zoovy:prod_image1'),H=>75,W=>75);
					$body .= "<div class=\"product\" id=\"product:$PID\">
<a href=\"$url\">
<img style=\"align: left\" alt=\"".$P->fetch('zoovy:prod_name')."\" border=0 width=50 height=50 src=\"$src\">
<b>".$P->fetch('zoovy:prod_name')."</a></b><br>
".$P->fetch('zoovy:prod_desc')."
<i>\$".sprintf("%.2f",$P->fetch('zoovy:base_price'))."
</div>";
					}
				}
			}


		## END OF /category handler
		}
	elsif ($r->uri() =~ /^\/product\/(.*)$/) {
		my ($PIDPATH) = $1;

		my $PID = undef;
		# handle /product/pid/asdf
		if ($PIDPATH =~ /^(.*?)\/.*$/) {	$PID = $1; }
		# handle /product/pid
		if ((not defined $PID) && ($PIDPATH =~ /^([A-Z0-9\-\_]+)$/)) { $PID = $PIDPATH; }


		my ($P) = PRODUCT->new($SITE->username(),$PID,'create'=>0);

		if (defined $P) {
			my ($NC) = $SITE->get_navcats();
			$CANONICAL_URL = $P->public_url('style'=>'vstore');

			foreach my $safe (@{$NC->paths_by_product($PID)}) {
				my ($pretty,$children,$products,$sort,$metaref,$modified_gmt) = $NC->get($safe);
				next if (substr($pretty,0,1) eq '!');

				my ($bcorder,$bcnames) = $NC->breadcrumb($safe);
				if (not defined $bcorder) {
					$body .= "<!-- no breadcrumbs for $safe -->";
					}
				elsif (scalar(@{$bcorder})>0) {
					my @links = ();
					foreach my $bcsafe (@{$bcorder}) {
						push @links, sprintf("<span><a href=\"/category/%s/index.html\">%s</a></span>\n",substr($bcsafe,1),$bcnames->{$bcsafe});
						}
					$body .= "<li> ".join(" | ",@links);
					}
				}
			}

		## modified  1/7/13 
		## www.ekoreparts.com/product/VA-01/SIEMENS-SFA71U-24-Vac-NC-2-POSITION-VALVE-ACTUATOR.html
		## used privacy policy because it was the first div with content.
		## www.google.com/webmasters/tools/richsnippets

		if (not defined $P) {
			$RESPONSE_CODE = 404;
			}
		else {
			my $prodref = $P->prodref();
			$body .= "<div itemscope itemtype=\"http://schema.org/Product\">\n";
			$body .= "<h1 itemprop=\"name\" data-attribute=\"zoovy:prod_name\">$prodref->{'zoovy:prod_name'}</h1>\n";
			$body .= "<section itemprop=\"offers\" itemscope itemType=\"http://schema.org/Offer\"><span itemprop=\"price\">\$$prodref->{'zoovy:base_price'}</span></section>\n";
			$body .= "<div itemprop=\"manufacturer\" itemscope itemtype=\"http://schema.org/Organization\" data-attribute=\"zoovy:prod_mfg\">$prodref->{'zoovy:prod_mfg'}</div>\n";
  		   $body .= "<div itemprop=\"model\" data-attribute=\"zoovy:prod_mfgid\">$prodref->{'zoovy:prod_mfgid'}</div>\n";
			$body .= "<section itemprop=\"description\">\n\n";
			$body .= "	<div data-attribute=\"zoovy:prod_desc\">$prodref->{'zoovy:prod_desc'}</div><br />\n";
			$body .= "	<div data-attribute=\"zoovy:prod_detail\">$prodref->{'zoovy:prod_detail'}</div><br />\n";
  	  		$body .= "  <div data-attribute=\"zoovy:prod_features\">$prodref->{'zoovy:prod_features'}</div><br />\n";
			$body .= "</section>\n\n";
		
			if($prodref->{'youtube:videoid'})	{
				$body .= "<div itemprop=\"video\" itemscope itemtype=\"http://schema.org/VideoObject\">\n";
				$body .= "<h2 itemprop=\"name\">$prodref->{'youtube:video_title'}</h2>";
				$body .= "<meta itemprop=\"thumbnail\" content=\"http://i1.ytimg.com/vi/$prodref->{'youtube:videoid'}/default.jpg\" />";
				$body .= "<object width=\"560\" height=\"315\"><param name=\"movie\" value=\"http://www.youtube.com/v/$prodref->{'youtube:videoid'}?version=3&amp;hl=en_US\"></param>";
				$body .= "<param name=\"allowFullScreen\" value=\"true\"></param><param name=\"allowscriptaccess\" value=\"always\"></param>";
				$body .= "<embed src=\"http://www.youtube.com/v/$prodref->{'youtube:videoid'}?version=3&amp;hl=en_US\" type=\"application/x-shockwave-flash\" width=\"560\" height=\"315\" allowscriptaccess=\"always\" allowfullscreen=\"true\"></embed></object>";
				$body .= "<div itemprop=\"description\">$prodref->{'youtube:video_description'}</div>";
				$body .= "</div>"
				}
			$body .= "<h2>Images</h2>";
			foreach my $k ('zoovy:prod_image1','zoovy:prod_image2','zoovy:prod_image3','zoovy:prod_image4') {
				next if (substr($k,0,1) eq '%');
				next if ($prodref->{$k} eq '');			
				$body .= "<div data-attribute=\"$k\">$prodref->{$k}</div>\n";
				}
			$body .= "</div><!-- /product itemscope -->\n";
			## Need to get reviews in here. you get them in, I'll format. (jt note:  formatting here: http://schema.org/Product)

			$META{'title'} = $prodref->{'zoovy:prod_name'};
			$META{'keywords'} = $prodref->{'zoovy:prod_keywords'};
			$META{'description'} = $prodref->{'zoovy:prod_desc'};
			}

		}
	elsif ($r->uri() =~ /^\/customer\/(.*?)$/o) {
		$CANONICAL_URL = '/customer';
		$body .= "<h1>Customer Access</h1>";
		$body .= "<i>Please enable javascript to access our customer application.</i>";
		$META{'title'} = 'Customer Access';
		$META{'description'} = 'Customer login';
		}
	else {
		$CANONICAL_URL = '/';
		# $META{'title'} = 'Homepage';
		my ($PG) = $SITE->pAGE(".");
		if (defined $PG) {
			$META{'title'} = $PG->get('page_title');
			$META{'description'} = $PG->get('meta_description');
			$META{'keywords'} = $PG->get('meta_keywords');
			}

		my ($NC) = $SITE->get_navcats();
		my ($order,$names,$metaref,$SAFEPATH) = $NC->build_turbomenu($NC->rootpath(),undef,undef);

		foreach my $safe (@{$order}) {
			## below: substr($safe,1) removes leading . from $safe
			$body .= sprintf("<a href=\"#!category?navcat=%s&title=%s\">%s</a>\n",$safe,$names->{$safe},$names->{$safe});
			}		
		}

	if (defined $REDIRECT) {
		my $head = $r->headers_out();
		$head->add("Pragma"=>"no-cache");                     # HTTP 1.0 non-caching specification
		$head->add("Cache-Control"=>"no-cache, no-store");    # HTTP 1.1 non-caching specification
		$head->add("Expires"=>"0");                           # HTTP 1.0 way of saying "expire now"
		$head->add("Status"=>"301 Moved");
		# $head->add("Zoovy-Debug"=>caller(0));
		$head->add("Location"=>"$REDIRECT");
		## return(Apache2::Const::HTTP_MOVED_PERMANENTLY);
		}

	$META{'content-type'} = 'text/html; charset=UTF-8';
	my $PROJECT =  $r->headers_out()->get('X-Project');
	$META{'author'} = "SEO HTML5 Compatibility Layer r.$::BUILD p.$PROJECT server:".&ZOOVY::servername();

	$r->content_type('text/html');

	my $index_filename = $r->pnotes("FILE");
	if (-f $index_filename) {
		## the heavy lifting.
		open F, "<$index_filename"; $/ = undef; # </local/cache/sporks/2e5aaea5-abf3-11e1-95d8-8f2e378b/index.html"; $/ = undef;
		my $buf = <F>;
		close F; $/ = "\n";

		## insert noscript SEO compat layer into <body>
		my $seobody = '';
		$seobody .= sprintf("<!-- DEBUG GENERATED:%s SERVER:%s -->",&ZTOOLKIT::pretty_date(time(),3),&ZOOVY::servername());
		# if (not $ZOOVY::cgiv->{'_escaped_fragment_'}) {
		# if (not $cgi->param('_escaped_fragment_')) {
		if ($ENV{'QUERY_STRING'} !~ /\_escaped\_fragment\_\=/) {
			$seobody .= "<div class=\"displayNone seo\" id=\"seo-html5\"><!-- HTML5 SEO COMPATIBILITY -->\n$body\n<!-- /HTML5 SEO COMPATIBILITY --></div>\n";
			# $seobody = Dumper(\%ENV);
			}
		else {
			$seobody .= "<!-- HTML5 SEO COMPATIBILITY -->\n$body\n<!-- /HTML5 SEO COMPATIBILITY -->\n";
			}
		$buf =~ s/(\<[Bb][Oo][Dd][Yy].*?\>)/$1$seobody/sog;

		## insert meta SEO compat layer into <head>
		my $meta = '';

		$CANONICAL_URL = sprintf("http://%s%s",$SDOMAIN,$CANONICAL_URL);
		$meta .= qq~\n<link rel="canonical" href="$CANONICAL_URL#!v=1" />\n~;
		foreach my $k (keys %META) {
			$META{$k} = &ZTOOLKIT::htmlstrip($META{$k});
			$meta .= sprintf("<meta name=\"%s\" content=\"%s\" />\n",$k,&ZOOVY::incode($META{$k}));
			}
		$buf =~ s/(\<[Hh][Ee][Aa][Dd].*?\>)/$1$meta/s;

		$r->print($buf);	
		$r->print("\n\r\n\r\n\r");	
		}
	else {
		## CRITICAL ERROR
		$r->print(q~<!DOCTYPE HTML>~); #HTML5 has no doctype specified
		$r->print("<html><h1>No Index</h1></html>");
		}

	return($RESPONSE_CODE);
	}


1;
