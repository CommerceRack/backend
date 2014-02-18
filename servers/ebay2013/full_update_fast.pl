#!/usr/bin/env perl

## Phase 1 - update ebay categories tree
## btw on ebay usa (site 0) all categories support specifics (site default setting and noone cat overrides that)
## Phase 2 - get recommended specifics names/values for all cats (500MB xml)
## everyhthing is stored into filesystem as bunch of .json files
## VERSION: 201336

## saveto=fs - .json chunks are saved to filesystem - resulting 11000+ .json files and 20000 directories, total 300MB+
## saveto=db - .json chunks are comressed and saved to sqlite3 db - result a single 40MB sqlite file - KISS!

## ./full_update_fast version=201334 saveto=fs
## ./full_update_fast version=201334 saveto=db

use strict;
use warnings;
use Data::Dumper;
use XML::Parser;
use XML::SimpleObject;
#use YAML::Syck;
use XML::Simple qw(:strict);
#use XML::SAX::Simple qw();
use JSON;
use lib '/httpd/modules';
use EBAY2;
use ZTOOLKIT;

$|=1;

my (%params, $SITE, $PATH_TO_STATIC, $PATH_TO_STATIC_FINAL, $edbh, $USERNAME, $EIAS, $eb2,%ebaySites) = ();
my ($getCategoriesFile,$specificsFile,$specificsDataFile);
$XML::Simple::PREFERRED_PARSER = 'XML::SAX::Expat';
my $json = JSON->new->allow_nonref;
$params{'version'} = '201336';
$params{'saveto'} = 'db';


set_ebay_sites_names();
init();
for my $i (0, 100) {
#for my $i (100) {
	
	$SITE = $i;
	$getCategoriesFile = "$PATH_TO_STATIC/xml/GetCategories-$SITE.xml";
	$specificsFile = "$PATH_TO_STATIC/xml/GetCategorySpecifics-$SITE.xml";
	$specificsDataFile = "$PATH_TO_STATIC/xml/GetCategorySpecifics-$SITE-Data.xml";
	
	phase1_build_cats();
	phase2_fetch_recommended_specifics_fast(); ## this is quick-n-dirty xml parsing
}
phase3_clean_up();
print "---- $0 - All done\n";
print "---- Change the files owner first\n";
print "\$ sudo chown -R nobody:nobody \"$PATH_TO_STATIC_FINAL\"\n\n";
print "Then add the following lines to appdist:\n";
print "#~ <time> - <name> - $params{'version'} eBay item specifics database release\n";
print "$PATH_TO_STATIC_FINAL/ebay.db -> \${ALL} install;\n";

##
## init db connection, PATH_TO_STATIC, eb2 ....
sub init {
	$params{'cluster'} = 'pop' ;
	foreach my $arg (@ARGV) {
		if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
		my ($k,$v) = split(/=/,$arg);
		$params{lc($k)} = $v;
		}
	
	print "---- eBay specifics, generating version $params{'version'}, let's start... ----\n";

	#$PATH_TO_STATIC = &EBAY2::resolve_resource_path($params{'version'},exists=>0);
	$PATH_TO_STATIC = "/httpd/static/ebay/$params{'version'}_inprogress"; ## this dir is renamed to $PATH_TO_STATIC_FINAL after update
	$PATH_TO_STATIC_FINAL = "/httpd/static/ebay/$params{'version'}";
	
	# you're trying to overwrite/modify existing db release - die
	if(-d $PATH_TO_STATIC_FINAL && !$params{'force'}) {
		die qq~Hey, $PATH_TO_STATIC_FINAL already exists!
If you want to generate a new db, pass 'version=YYYYWW'
If you want to modify the existing $params{'version'} release, pass 'force=yes'\n~;
		}

	`mkdir -p $PATH_TO_STATIC/xml` unless -d "$PATH_TO_STATIC/xml";
	
	`touch $PATH_TO_STATIC/ebay.db` unless -e "$PATH_TO_STATIC/ebay.db";
	#($edbh) = &EBAY2::db_resource_connect($params{'version'});
	$edbh = DBI->connect("dbi:SQLite:dbname=$PATH_TO_STATIC/ebay.db","","");

	#die("cluster is required") if not defined $params{'cluster'};
	#($USERNAME,$EIAS) = &EBAY2::valid_user_for_cluster($params{'cluster'});
	#die("no valid users found") if not defined $USERNAME;

	#($eb2) = EBAY2->new($USERNAME,'EIAS'=>$EIAS);
	#print 'USING CREDENTIALS: '.Dumper($USERNAME,$EIAS,$eb2);
	($eb2) = EBAY2->new('tarasi', PRT => 0);
	print 'USING CREDENTIALS: '.Dumper($eb2);
	#die 'ok';
	
	if($params{saveto} eq 'db') {
		print "\n===== USING PATH_TO_STATIC: $PATH_TO_STATIC\n";
		print "\n!!!!! Recommendations .json chunks are gzipped and saved to ebay.db\n";
		print "!!!!! If you want to save them as separate .json files\n";
		print "!!!!! pass 'saveto=fs' param to this script - NOT RECOMMENDED\n";
		print "!!!!! also see get_json_from_db.pl hook\n";
	}
}

##
## get and parse current ebay category tree
sub phase1_build_cats {
	print "\n------ Phase1 - build categories tree, SITE=$SITE (".$ebaySites{$SITE}[1].") ------ \n";
	
#	$edbh->do(qq~DROP TABLE if exists ebay_sites; ~);
	$edbh->do(qq~
	CREATE TABLE IF NOT EXISTS `ebay_sites` (
	  `id` int(10) NOT NULL DEFAULT '0' PRIMARY KEY,
		`abbr` varchar(10) NOT NULL DEFAULT '',
	  `name` varchar(30) NOT NULL DEFAULT ''
	);
	~);
	$edbh->do("INSERT INTO ebay_sites(id, abbr, name) VALUES (?,?,?)",{}, $SITE, $ebaySites{$SITE}[1],$ebaySites{$SITE}[1]) if $ebaySites{$SITE};
	
#	$edbh->do(qq~DROP TABLE if exists ebay_categories; ~);
	$edbh->do(qq~
	CREATE TABLE IF NOT EXISTS `ebay_categories` (
		`site` int(10) NOT NULL DEFAULT '0',
	  `id` int(10) NOT NULL DEFAULT '0',
	  `parent_id` int(10)  NOT NULL DEFAULT '0',
	  `level` tinyint(3)  NOT NULL DEFAULT '0',
	  `name` varchar(64) NOT NULL DEFAULT '',
	  `leaf` tinyint(3) NOT NULL DEFAULT '0',
	  `item_specifics_enabled` tinyint(3)  NOT NULL DEFAULT '0',
	  `variations_enabled` tinyint(3)  NOT NULL DEFAULT '0',
	  `catalog_enabled` tinyint(3) NOT NULL DEFAULT '0',
	  `product_search_page_available` tinyint(3) NOT NULL DEFAULT '0',
		PRIMARY KEY(site,id)
	);
	CREATE INDEX parent_id_idx ON ebay_categories (parent_id);
	~);

	my ($r, $xml);

	if(-e $getCategoriesFile or -e "$getCategoriesFile.gz") {
		print "$getCategoriesFile already exists - let's read it instead of making GetCategories call\n";
		-e "$getCategoriesFile.gz" ? open F, "gunzip -c $getCategoriesFile.gz |" : open F, "<$getCategoriesFile";
		#open(F,"<$getCategoriesFile");
		{	local $/; $xml = <F>; }
		close(F);
		}
	else {
		print "------ Phase1 - Making GetCategories api call, SITE=$SITE (".$ebaySites{$SITE}[1].") ...\n";
		($r) = $eb2->api('GetCategories',{
			'DetailLevel'=>'ReturnAll',
			'CategorySiteID'=>$SITE,
			'ViewAllNodes'=>'true',
			'LevelLimit'=>7,
			'#Site'=>$SITE,
			},xml=>1);
		$xml = $r->{'.XML'};
		open(F,">$getCategoriesFile");
		print F $xml;
		close F;
		}

	print "------ Phase1 - Parsing GetCategories response, SITE=$SITE (".$ebaySites{$SITE}[1].") ...\n";
	my $parser = new XML::Parser (ErrorContext => 2, Style => "Tree");
	my $xmlobj = new XML::SimpleObject ($parser->parse($xml));

	foreach my $element ($xmlobj->child('GetCategoriesResponse')->child('CategoryArray')->child('Category')) {
		my $id = $element->child('CategoryID')->value;
		my $parent_id = $element->child('CategoryParentID')->value;
		my $level = $element->child('CategoryLevel')->value;
		my $leaf = 0;
		if ($element->child('LeafCategory')) {
			$leaf = $element->child('LeafCategory')->value =~ /true/;
			}
		my $name = $element->child('CategoryName')->value;

		my $create_timestamp = $eb2->timestamp();
		$edbh->do("INSERT INTO ebay_categories(id, parent_id, level, leaf, name, item_specifics_enabled, site) VALUES (?,?,?,?,?,?,?)",{}, $id, $parent_id, $level, $leaf, $name, 1, $SITE);
		}
}

## NOT USED ANY MORE - Brian asked to re-write using XML::Simple
## fetch recommended specifics key/value pairs for all cats - 500MB xml
sub phase2_fetch_recommended_specifics_fast {
	print "\n------ Phase2 - fetch and parse recommended specifics, SITE=$SITE (".$ebaySites{$SITE}[1].") ------\n";
	
	#$edbh->do("DROP TABLE IF EXISTS ebay_specifics;");
	$edbh->do(qq~
	CREATE TABLE IF NOT EXISTS ebay_specifics (
		site int(10) NOT NULL DEFAULT 0,
		cid integer NOT NULL DEFAULT 0,
		json BLOB,
		PRIMARY KEY(site,cid)
	);
	~);

	## this call only returns taskReferenceId + fileReferenceId
	## and we pass them to EBAY2::ftsdownload
	my ($xml, $r) = (undef,undef);
	if(-e $specificsFile or -e "$specificsFile.gz") {
		print "------ Phase2 - $specificsFile file exists\nReading it instead of making ebay api call\n";
		-e "$specificsFile.gz" ? open F, "gunzip -c $specificsFile.gz |" : open F, "<$specificsFile";
		{ local $/; $xml = <F>;}
		close F;
		} 
	else {
		print "------ Phase2 - making GetCategorySpecifics api call, SITE=$SITE (".$ebaySites{$SITE}[1].")\n";
		$r = $eb2->api('GetCategorySpecifics',{
			'CategorySpecificsFileInfo' => 'true',
			'#Site'=>$SITE,
			},xml=>1);
		$xml = $r->{'.XML'};
		print "Saving $specificsFile\n";
		open(F,">$specificsFile");
		print F $xml;
		close F;
		}

	my ($taskReferenceId, $fileReferenceId);
	unless($xml =~ /RequestError/) {
		$taskReferenceId = $1 if $xml =~ /<taskReferenceId>(.*?)<\/taskReferenceId>/si;
		$fileReferenceId = $1 if $xml =~ /<fileReferenceId>(.*?)<\/fileReferenceId>/si;
		}

	## fetch zip file with all specifics - slow 30 minutes call + unzipping 500MB xml file
	if(-e $specificsDataFile or -e "$specificsDataFile.gz") {
		print "------ Phase2 - File already exists: $specificsDataFile\n";
		print "------ Phase2 - Let's use it instead of making 30-minutes long ebay fts api call\n";
		}
	else {
		print "------ Phase2 - Downloading recommended specifics zip from fts - takes about 30 minutes, SITE=$SITE (".$ebaySites{$SITE}[1].")\n";
		print "------ Phase2 - taskReferenceId - $taskReferenceId, fileReferenceId - $fileReferenceId, SITE=$SITE (".$ebaySites{$SITE}[1].")\n";
		my ($err, $specifics) = $eb2->ftsdownload($taskReferenceId,$fileReferenceId);
		print "------ Phase2 - Saving and parsing $specificsDataFile\n";
		open(F,">$specificsDataFile");
		print F $specifics;
		close F;
		}

	## parse 500MB $specificsDataFile xml - by reading small chunks of "Recommendations" data like this:
	## <Recommendations>
	##   <CategoryID>1217</CategoryID>
	##   <NameRecommendation>
	##     <Name>Color</Name>
	##     <ValidationRules>
	##       <MaxValues>1</MaxValues>
	##       <SelectionMode>FreeText</SelectionMode>
	##     </ValidationRules>
	##     <ValueRecommendation>
	##       <Value>Beige</Value>
	##       <ValidationRules/>
	##     </ValueRecommendation>
	##   </NameRecommendation>
	##    ...
	## </Recommendations>
	## -------------------------------------
	## <Recommendations>
	##   <CategoryID>22608</CategoryID>
	##    .......
	## </Recommendations>
	## -------------------------------------


	my ($chunkStarted, $chunkXml, $chunkCount) = (0,'',0);
	-e "$specificsDataFile.gz" ? open F, "gunzip -c $specificsDataFile.gz |" : open F, "<$specificsDataFile";
	#print `ls -la $specificsDataFile`;
	#open(F,"<$specificsDataFile") or die("cannot open file $specificsDataFile");
	while(my $line = <F>) {
		#die("Processed $chunkCount chunks, dying") if $chunkCount > 0;
		if(!$chunkStarted) {
			## looking for a start chunk tag - <Recommendations>
			next unless $line =~ /<Recommendations>/;
			$chunkStarted = 1;
			$chunkXml = $line;
			}
		else {
			## storing xml into $chunkXml and looking for a stop tag - </Recommendations>
			if($line !~ /<\/Recommendations>/) {
				$chunkXml .= $line;
				}
			else {
				$chunkXml .= $line;
				$chunkStarted = 0;
				## $chunkXml contains <Recommendations>...</Recommendations> structure now
				## let's parse/store it (to db, to json file, to xml file, ....)
				#print "-----------\n$chunkXml\n-----------\n\n";
				my $cid = $1 if $chunkXml =~ /<CategoryID>(.*?)<\/CategoryID>/si;
				#$edbh->do('INSERT INTO specifics(cid,xml) VALUES (?,?)',{},$cid,$chunkXml);
				
				my $xmlSimple = XML::Simple->new(NSExpand => 0, ForceArray => 0, KeyAttr => [], Cache => [ 'memshare' ], KeepRoot => 0);
				my $tree = $xmlSimple->XMLin($chunkXml);
				
				#print Dumper($tree);
				## create a file like PATH_TO_STATIC/$SITE/n/n/n/n/cat_id.json
				if($tree->{NameRecommendation}) {
					$chunkCount++;
					print "------ Phase2 - Processed recommended specifics for $chunkCount categories, SITE=$SITE (".$ebaySites{$SITE}[1].")\n" if !($chunkCount % 200);
					#$tree->{NameRecommendation} =~ s/[^\0-\x80]//g; ## strip wide characters
					
					## force array
					if(ref($tree->{NameRecommendation}) ne 'ARRAY') {
						$tree->{NameRecommendation} = [$tree->{NameRecommendation}];
						#print "--- catID: $cid - just one recommendation here, lets do ForceArray\n";
					}
					
					## remove empty nodes
					fixValidationRules($_) foreach (@{$tree->{NameRecommendation}});
					
					my $chunkJson = $json->pretty->utf8->encode( $tree->{NameRecommendation} ); # pretty-printing;
					
					if($params{saveto} eq 'fs') {
						my $jsonPath = join '/', split //,$cid;
						`mkdir -p $PATH_TO_STATIC/$SITE/$jsonPath`;
						open F1, ">$PATH_TO_STATIC/$SITE/$jsonPath/$cid.json";
						print F1 $chunkJson;
						close F1;
						}
					else {
						$edbh->do('INSERT INTO ebay_specifics(site,cid,json) VALUES (?,?,?)',{},$SITE,$cid,Compress::Zlib::memGzip($chunkJson));
						}
					}
				
				}
			}
		}
	print "------ Phase2 - Processed $chunkCount categories, SITE=$SITE (".$ebaySites{$SITE}[1].")\n";

	close F;

}

sub phase3_clean_up {
	print "------ Phase3 - Copying README and get_json_from_db.pl -> $PATH_TO_STATIC\n";
	use File::Basename;
	my $dirname = dirname(__FILE__);
	`cp $dirname/post-update/* $PATH_TO_STATIC/`;
 
	my $XMLDIR = $PATH_TO_STATIC."/xml";
	print "------ Phase3 - Gzipping eBay xml responses inside $XMLDIR\n";
	if(opendir(DIR, $XMLDIR)) {
		while (my $file = readdir(DIR)) {
			# We only want files
			next unless (-f "$XMLDIR/$file");
 
			# Use a regular expression to find files ending in .xml
			next unless ($file =~ /\.xml$/);
			
			unless(-e "$XMLDIR/$file.gz") {
				print "   --- gzipping $XMLDIR/$file\n";
				`gzip "$XMLDIR/$file"`;
				}
			}
		closedir(DIR);
		}

#	print "------ Phase3 - Gzipping $specificsDataFile (if not gzipped already)\n";
#	`gzip $specificsDataFile` unless -e "$specificsDataFile.gz";
#	print "------ Phase3 - gzippping eBay xml responses\n";
#	`gzip $getCategoriesFile` unless -e "$getCategoriesFile.gz";
#	`gzip $specificsFile` unless -e "$specificsFile.gz";
	
	print "------ Phase3 - clean up - setting chmod 777 on dirs and 666 on files inside $PATH_TO_STATIC\n";
	`find "$PATH_TO_STATIC" -type d -exec chmod 777 {} \\;`;
	`find "$PATH_TO_STATIC" -type f -exec chmod 666 {} \\;`;
	`chmod 777 $PATH_TO_STATIC/get_json_from_db.pl`;
	print "------ Phase3 - moving $PATH_TO_STATIC -> $PATH_TO_STATIC_FINAL\n";
	`mv "$PATH_TO_STATIC" "$PATH_TO_STATIC_FINAL"`;
	`chown -R nobody:nobody "$PATH_TO_STATIC_FINAL"`;
}




## -------- helper methods ------------

## delete empty ValidationRules nodes to save some space
sub fixValidationRules {
	my $node = shift;
	fixRelationship($node->{ValidationRules});
	if ($node->{ValueRecommendation} and length $node->{ValueRecommendation}) {
		$node->{ValueRecommendation} = [$node->{ValueRecommendation}] if(ref($node->{ValueRecommendation}) ne 'ARRAY');
		
		foreach my $valRec (@{$node->{ValueRecommendation}}) {
		
			if(length %{$valRec->{ValidationRules}} < 2) {
				# empty ValidationRules
				delete $valRec->{ValidationRules};
				} 
			else {
				fixRelationship($valRec->{ValidationRules});
				}
			}
		}
	}
	
	
## remove duplicates from ValidationRules->Relationship node
sub fixRelationship {
	my $validationRules = shift;
	## remove duplicates from Relationship, they look like these:
	##"ValidationRules" : {
  ##             "Relationship" : [
  ##                {
  ##                   "ParentValue" : "Regular",
  ##                   "ParentName" : "Size Type"
  ##                },
  ##                {
  ##                   "ParentValue" : "Regular",
  ##                   "ParentName" : "Size Type"
  ##                },
  ##                {
  ##                   "ParentValue" : "Regular",
  ##                   "ParentName" : "Size Type"
  ##                }
  ##             ]
  ##          },
	if($validationRules->{Relationship} and ref($validationRules->{Relationship}) eq 'ARRAY') {
		my @relArr;
		my %duplicates;
		foreach my $rel (@{$validationRules->{Relationship}}) {
			if($rel->{ParentName} and $rel->{ParentValue}) {
				if(!$duplicates{$rel->{ParentName}.$rel->{ParentValue}}) {
					$duplicates{$rel->{ParentName}.$rel->{ParentValue}} = 1;
					push @relArr,$rel;
					}
				}
				elsif ($rel->{ParentName}) {
					if(!$duplicates{$rel->{ParentName}}) {
						$duplicates{$rel->{ParentName}} = 1;
						push @relArr,$rel;
						}
					}
			} 
		$validationRules->{Relationship} = \@relArr;
		#print Dumper($valRec->{ValidationRules}{Relationship});
		}
	}


## set eBay sites and IDs
sub set_ebay_sites_names {
	%ebaySites = (
		0 => ['US','United States'],
		2 => ['CA','Canada'],
		3 => ['UK','United Kingdom'],
		15 => ['AU','Australia'],
		16 => ['AT','Austria'],
		23 => ['BEFR','Belgium (French)'],
		71 => ['FR','France'],
		77 => ['DE','Germany'],
		100 => ['Motors','US eBay Motors'],
		101 => ['IT','Italy'],
		123 => ['BENL','Belgium (Dutch)'],
		146 => ['NL','Netherlands'],
		186 => ['ES','Spain'],
		193 => ['CH','Switzerland'],
		201 => ['HK','Hong Kong'],
		203 => ['IN','India'],
		205 => ['IE','Ireland'],
		207 => ['MY','Malaysia'],
		210 => ['CAFR','Canada (French)'],
		211 => ['PH','Philippines'],
		212 => ['PL','Poland'],
		216 => ['SG','Singapore'],
		);
	}
	
##
## fetch recommended specifics key/value pairs for all cats - 500MB xml
sub phase2_fetch_recommended_specifics {
	print "\n------ Phase2 - fetch and parse recommended specifics, SITE=$SITE ------\n";

	## this call only returns taskReferenceId + fileReferenceId
	## and we pass them to EBAY2::ftsdownload
	my ($specificsFile, $xml, $r) = ("$PATH_TO_STATIC/GetCategorySpecifics-$SITE.xml",undef,undef);
	if(-e $specificsFile) {
		print "------ Phase2 - $specificsFile file exists\nReading it instead of making ebay api call\n";
		open F, "<$specificsFile";
		{ local $/; $xml = <F>;}
		close F;
		} 
	else {
		print "------ Phase2 - making GetCategorySpecifics api call, SITE=$SITE\n";
		$r = $eb2->api('GetCategorySpecifics',{
			'CategorySpecificsFileInfo' => 'true',
			'#Site'=>$SITE,
			},xml=>1);
		$xml = $r->{'.XML'};
		print "Saving $specificsFile\n";
		open(F,">$specificsFile");
		print F $xml;
		close F;
		}

	my ($taskReferenceId, $fileReferenceId);
	unless($xml =~ /RequestError/) {
		$taskReferenceId = $1 if $xml =~ /<taskReferenceId>(.*?)<\/taskReferenceId>/si;
		$fileReferenceId = $1 if $xml =~ /<fileReferenceId>(.*?)<\/fileReferenceId>/si;
		}

	## fetch zip file with all specifics - slow 30 minutes call + unzipping 500MB xml file
	my $specificsDataFile = "$PATH_TO_STATIC/GetCategorySpecifics-$SITE-Data.xml";

	if(-e $specificsDataFile) {
		print "------ Phase2 - File already exists: $specificsDataFile\n";
		print "------ Phase2 - Let's use it instead of making 30-minutes long ebay fts api call\n";
		}
	else {
		print "------ Phase2 - Downloading recommended specifics zip from fts - takes about 30 minutes (dev node has super-slow inet connection), SITE=$SITE\n";
		print "------ Phase2 - taskReferenceId - $taskReferenceId, fileReferenceId - $fileReferenceId\n";
		my ($err, $specifics) = $eb2->ftsdownload($taskReferenceId,$fileReferenceId);
		print "------ Phase2 - Saving $specificsDataFile\n";
		open(F,">$specificsDataFile");
		print F $specifics;
		close F;
		}

	print "------ Phase2 - parsing 500MB xml using XML::Simple + XML::SAX::Expat ....\n";
	my $xmlSimple = XML::Simple->new(NSExpand => 0, ForceArray => 0, KeyAttr => [], Cache => [ 'memshare' ], KeepRoot => 0);
	my $tree = $xmlSimple->XMLin($specificsDataFile);
	
	my $chunkCount = 0;
	foreach my $rec (@{$tree->{Recommendations}}) {
		if($rec->{NameRecommendation}) {
			$rec->{NameRecommendation} =~ s/[^\0-\x80]//g; ## strip wide characters
			$chunkCount++;
			print "------ Phase2 - Processed recommended specifics for $chunkCount categories\n" if !($chunkCount % 250);
		
			## create a file like PATH_TO_STATIC/$SITE/n/n/n/n/cat_id.json
			my $jsonPath = join '/', split //,$rec->{CategoryID};
			`mkdir -p $PATH_TO_STATIC/$SITE/$jsonPath`;
			open F, ">$PATH_TO_STATIC/$SITE/$jsonPath/$rec->{CategoryID}.json";
			print F $json->pretty->encode( $rec->{NameRecommendation} ); # pretty-printing;
			close F;
			#my $pretty_printed = $json->pretty->encode( $rec ); # pretty-printing
			#print $pretty_printed;
			#print "-------\n";
			}
		}
	
	print "------ Phase2 - Processed $chunkCount categories (500+MB total)\n";

	#print "------ Phase2 - Gzipping 500MB $specificsDataFile (if not gzipped already)\n";
	#`gzip $specificsDataFile` unless -e "$specificsDataFile.gz";
}
