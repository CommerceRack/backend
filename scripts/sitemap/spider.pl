#!/usr/bin/perl

use strict;
use Data::Dumper;
use WWW::Mechanize::PhantomJS;
use XML::Writer;
use Selenium::Remote::Driver;
use threads;
use Digest::MD5;
use Time::HiRes;
use Try::Tiny; 

use lib "/httpd/modules";
use DBINFO;
use DOMAIN::QUERY;
use ZOOVY;

my $port = 8911;
$port = 8910;
$port = 8909;
$port = 8908;
if ($ARGV[0]) { $port = int($ARGV[0]); }

#my $driver = Selenium::Remote::Driver->new(port=>$port,auto_close=>0,log=>1);
my $mech = WWW::Mechanize::PhantomJS->new( 
	'port'=>$port,
	'log'=>1,
#	'launch_ghostdriver'=>'/root/.cpanm/latest-build/WWW-Mechanize-PhantomJS-0.03/lib/WWW/Mechanize/PhantomJS/ghostdriver/main.js',
	'launch_exec'=>'/usr/local/phantomjs/bin/phantomjs',
	'launch_arg'=>["--webdriver=$port",'--webdriver-logfile=/tmp/webdriver','--webdriver-loglevel=DEBUG','--debug=true', "--port=$port", "--load-images=0" ] ,
#	'driver'=>$driver,
#	'driver'=>Selenium::Remote::Driver->new(
#        'port' => $port,
#        auto_close => 0,
#     )

	);




$mech->add_header( 'X-WWW-Robot' => 1 );

my $USERNAME = 'cubworld';
my $HOSTDOMAIN = 'beta.sportsworldchicago.com';

my %STATS = ();

my $URL = "http://$HOSTDOMAIN/";
my $memd = &ZOOVY::getMemd($USERNAME);
my ($udbh) = &DBINFO::db_user_connect($USERNAME);
my ($r) = $mech->get($URL);
my @ERRORS = ();

my $continue = 100;
my $FAILURES_ALLOWED = 2;
my @ERRORS = ();

if (not $mech->success($URL)) {
	push @ERRORS, "Could not access $URL";
	}
else {
	sleep(1);
	print "TITLE: ".$mech->driver()->get_title()."\n";
  	print "URI: ".$mech->uri()."\n";

	for ($mech->js_errors()) { push @ERRORS, "Javascript: ". $_->{message}; }

	#print $mech->driver()->get_page_source();
	my ($version,$type) = $mech->eval_in_page(qq~_robots.hello("commercerack/1.0");~);
	$version = $version * 100;
	if ($version < 100 || $version > 200) {
		push @ERRORS,  sprintf("_robots.hello returned invalid version \"%s\"",$version);
		}
	}

my $waited = 0;
my $ready = 0;
while ( not $ready ) {
	($ready) = $mech->eval_in_page(qq~_robots.ready();~);
	if (not $ready) {
		print "NOT READY\n";
		sleep(2);
		if ($waited++>30) { print "DONE WAITING\n"; last; }
		}	
	}

# $mech->eval("var x = 1");
#my $pstmt = "delete from SEO_PAGES where MID=$MID and ESCAPED_FRAGMENT=".$udbh->quote($fragment);
# $udbh->do($pstmt);

##
## Phase 2: download urls
##

$FAILURES_ALLOWED = 10;
my @URIS = ();
my $count = 0;
my $continue = 100;
while ( $continue ) {
	my $responsecode = 0;
	my ($urii,$type) = $mech->eval_in_page(qq~_robots.pop(1000);~);

	if ($urii ne '') {
		foreach my $uri (split(/[\n\r]+/,$urii)) {
			print "URI:$uri\n";
			push @URIS, $uri;
			$count++;
			## if (($count % 1000)==0) { print "FOUND: $count uris\n"; }
			}
		#if ($count > 20000) { last; }
		}
	else {
		$continue = 0;
		}
	}

##
## Phase 3: take snapshots
##
print "DONE - have ".scalar(@URIS)." URLS\n";

$continue = 100;
$FAILURES_ALLOWED = 2;
my %SEEN_URLS = ();

my $qtHOSTDOMAIN = $udbh->quote($HOSTDOMAIN);
while ( $continue && $FAILURES_ALLOWED && scalar(@URIS) ) {
	my ($STACKURI) = shift @URIS;

	my $GUID = Digest::MD5::md5_hex($STACKURI);

	if (not $memd->add("$GUID",1,180)) {
		print "GUID $GUID is in memcache already\n";
		next;
		}

	my $qtGUID = $udbh->quote($GUID);
	my $pstmt = "select count(*) from SEO_PAGES where DOMAIN=$qtHOSTDOMAIN and GUID=$qtGUID";
	my ($exists) = $udbh->selectrow_array($pstmt);
	if ($exists) {
		print "EXISTS: $exists\n";
		next;
		}



	print "EXECUTING NEXT $STACKURI\n";		
	my $responsecode = 0;
	$mech->driver->execute_script(qq~_robots.next(arguments[0]);~,$STACKURI);
	
	my $OKAY_TO_WAIT = 25;
	do {
		$STATS{'next'}++;
		if ($responsecode == 100) { 
			Time::HiRes::sleep(0.300); 
			$STATS{'response.100'}++; 
			}
		try {
			$responsecode = $mech->eval_in_page("_robots.status();");
			}
		catch {
			warn "_robots.status() failed $@";
			$responsecode = 100;
			};

		print "RESPONSECODE: $responsecode ($OKAY_TO_WAIT)\n";
		$OKAY_TO_WAIT--;
		}
	while ($responsecode == 100 && $OKAY_TO_WAIT); 


	if ($FAILURES_ALLOWED <= 0) {
		push @ERRORS, "too many failures.\n";
		}
	elsif (not $OKAY_TO_WAIT) {
		foreach ($mech->js_errors()) { push @ERRORS, "Javascript: $_->{message}\n"; }
		if ($FAILURES_ALLOWED-- > 0) { next; }	##
		push @ERRORS, "failures++; no more patience. maximum consecutive waits encountered.";
		}
	elsif ($responsecode == -1) {
		print "RECEIVED -1: ALL DONE!\n";
		last;
		}
	elsif ($responsecode == 200) {
		$STATS{'response.200'}++;
		print "SNAPSHOT!\n";
		print "URI: ".$mech->uri()."\n";
		print "TITLE: ".$mech->driver()->get_title()."\n";
		my $CANONICAL_URL = undef;
		foreach my $element (@{$mech->driver()->find_elements('link','tag_name')}) {
			## print "LINK: ".$element->get_attribute('rel')."\n";
			if ($element->get_attribute('rel') eq 'canonical') {
				## print "FOUND CANONICAL\n";
				$CANONICAL_URL = $element->get_attribute('href');
				}
			}
		print "CANONICAL: $CANONICAL_URL\n";
		if ($CANONICAL_URL eq '') { push @ERRORS, "failures++; No canonical url"; $FAILURES_ALLOWED--; next; }
		if ($SEEN_URLS{$CANONICAL_URL}) { push @ERRORS, "failures++; duplicate canonical: $CANONICAL_URL"; $FAILURES_ALLOWED--; next; }

		my $html = $mech->driver()->get_page_source();
		print "CONTENT-LENGTH: ".length($html)."\n";
		## print "HTML:$html\n";

		my $fragment = '';
		if ($CANONICAL_URL =~ /^.*?#!(.*)$/) {
			$fragment = $1;
			$fragment =~ s/\&/%26/gs;	## safety precaution.
			}
		my $score = 1;

		my $pstmt = "select count(*) from SEO_PAGES where DOMAIN=".$udbh->quote($HOSTDOMAIN)." and ESCAPED_FRAGMENT=".$udbh->quote($fragment);
		my ($count) = $udbh->do($pstmt);
		if ($count>0) {
			my $pstmt = "delete from SEO_PAGES where DOMAIN=".$udbh->quote($HOSTDOMAIN)." and ESCAPED_FRAGMENT=".$udbh->quote($fragment);
			print "$pstmt\n";
			$udbh->do($pstmt);
			$STATS{'found.existing'}++;
			}
		else {
			$STATS{'found.new'}++;
			}

		## escaped fragment is what google *should* send us
		## unescaped fragment is what we receive from google. (after it's decoded by webserver)
		my $unescfragment = URI::Escape::XS::uri_unescape($fragment);	
			
		my $pstmt = &DBINFO::insert($udbh,'SEO_PAGES',{
			'MID'=>&ZOOVY::resolve_mid($USERNAME),
			'*CREATED_TS'=>'now()',
			'GUID'=>$GUID,
			'DOMAIN'=>$HOSTDOMAIN,
			'UNESCAPED_FRAGMENT'=>$unescfragment,
			'ESCAPED_FRAGMENT'=>$fragment,
			'SITEMAP_SCORE'=>$score,
			'BODY'=>$html
			},'verb'=>'insert','sql'=>1);
		# print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		}
	elsif ($responsecode == 100) {
		print "CONTINUE!\n";
		}
	else {
		$STATS{"found.$responsecode"}++;
		print "OTHER: $responsecode\n";
		}

	print "------------------------------------------------------------------------------------------------\n";
	foreach my $k (keys %STATS) {
		print "$k: $STATS{$k} | ";
		}		
	print "\n";
	print "------------------------------------------------------------------------------------------------\n";

	}

&update_sitemap($USERNAME,$HOSTDOMAIN);
&DBINFO::db_user_close();



sub update_sitemap {
	my ($USERNAME,$HOSTDOMAIN) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	
	my $PROJECTID = DOMAIN::QUERY::lookup("$HOSTDOMAIN")->{"PROJECT"};
	my $PROJECTDIR = sprintf("%s/PROJECTS/%s",&ZOOVY::resolve_userpath($USERNAME),$PROJECTID);
	print "PROJECT: $PROJECTDIR\n";

	my $qtHOSTDOMAIN = $udbh->quote($HOSTDOMAIN);
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	my $pstmt = "select ESCAPED_FRAGMENT,SITEMAP_SCORE from SEO_PAGES where MID=$MID and DOMAIN=$qtHOSTDOMAIN order by SITEMAP_SCORE";
	print STDERR "$pstmt\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my @DATA = ();
	while ( my ($FRAGMENT, $SCORE) = $sth->fetchrow() ) {
		push @DATA, [ $FRAGMENT, $SCORE ];
		}
	$sth->finish();

	my $gmtdatetime = &ZTOOLKIT::pretty_date(time(),6);

	my $indexxml = '';
	my $inwriter = new XML::Writer(OUTPUT => \$indexxml, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');
	$inwriter->xmlDecl("UTF-8");	
	$inwriter->startTag("sitemapindex", "xmlns"=>"http://www.google.com/schemas/sitemap/0.84");
	$inwriter->comment(sprintf("Generated:%s",$gmtdatetime));

	my $batches = &ZTOOLKIT::batchify(\@DATA,2500);
	my $i = 0;
	foreach my $set (@{$batches}) {
		my $FILENAME = sprintf("sitemap-%s-%d.xml.gz",$HOSTDOMAIN,++$i);

		$inwriter->startTag("sitemap");
		$inwriter->dataElement("loc","http://$HOSTDOMAIN/$FILENAME");
		$inwriter->dataElement("lastmod",$gmtdatetime);
		$inwriter->endTag("sitemap");
	
		my $filexml = '';
		my $filewriter = new XML::Writer(OUTPUT => \$filexml, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');
		$filewriter->xmlDecl("UTF-8");	
		$filewriter->startTag("sitemapindex","xmlns"=>"http://www.sitemaps.org/schemas/sitemap/0.9");
		$filewriter->startTag("urlset","xmlns"=>"http://www.google.com/schemas/sitemap/0.84");
		foreach my $row (@{$set}) {
			$filewriter->startTag("url");
			$filewriter->dataElement("loc","http://$HOSTDOMAIN/#!$row->[0]");
			$filewriter->dataElement("priority",$row->[1]);
			$filewriter->endTag();
			}
		$filewriter->endTag();
		$filewriter->endTag("sitemapindex");
		$filewriter->end();

		## SANITY: at this point $xml is built
		my $z = IO::Compress::Gzip->new("$PROJECTDIR/$FILENAME") or die("gzip failed\n");
		$z->print($filexml);
		$z->close();
		}
	
	$inwriter->endTag("sitemapindex");
	$inwriter->end();

	my $out = new IO::File ">$PROJECTDIR/sitemap.xml";
	print $out $indexxml;
	$out->close();

	#$v->{'debug'} = 0;
	#if (not $v->{'debug'}) {
	#	$pstmt = "delete from SEO_PAGES where MID=$MID and DOMAIN=$qtHOSTDOMAIN and GUID!=$qtGUID";
	#	print STDERR $pstmt."\n";
	#	$udbh->do($pstmt);
	#	}

	&DBINFO::db_user_close();
	}


__DATA__

	## $mech->driver()->screenshot();
	

	

	#print $mech->get_page_source();
	}
else {
	print "FAIL!\n";
	}

__DATA__


use Data::Dumper;
print Dumper($r,$r->content())."\n";





