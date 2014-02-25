package SEARCH;

use strict;

#use Search::QueryParser;
#use Lingua::EN::Infinitive;
#use Lingua::EN::Inflect::Number qw( to_PL ); # Or anything you want from Lingua::EN::Inflect


# use Text::Metaphone;
# use CDB_File;
use Storable;

use lib '/backend/lib';
require ZOOVY;
require PRODUCT;
require DBINFO;
require ZTOOLKIT;
require NAVCAT;
require ZWEBSITE;
require ELASTIC;
require PRODUCT::FLEXEDIT;

$SEARCH::DEBUG = 0;

&init();
$ENV{'PATH'} .= ':/usr/local/bin';		## the cdbmake program is in /usr/local/bin

$SEARCH::ELASTIC_RESULTS = 500;

# $SEARCH::CACHE_INFINITIVE = undef;

sub init {};



##
## takes a model number, or sku and "explodes it" to generate keywords.
##		this will make a field appear more like a substring field.
##
sub explode {
	my ($modelsku) = @_;

	# if ($modelsku ne 'SMP_MTX_BL_VL_COND') { return(); }
	# print sprintf("START: $modelsku %d\n",length($modelsku));

	#if ($modelsku eq 'SMP_MTX_BL_VL_COND') { return(); }
	#if ($modelsku eq 'MTX_VM_CTRL_DRY_MIST') { return(); }
	# if (length($modelsku)<18) { return(); } 

	$modelsku = lc($modelsku);
	my $model = $modelsku;

	my @words = ();

	if ($modelsku eq '') { 
		## short circuit blank fields.
		return(''); 
		}

	## phase1: handle most common model numbers.
	push @words, $model;
	if (index('_',$model)>=0) {
		$model =~ s/_/ /go;			## replace underscore with spaces
		push @words, $model;
		}
	if (index(' ',$model)>=0) {
		$model =~ s/[\s]+/-/go;		## replace spaces with dashes
		push @words, $model;
		}
	if (index('-',$model)>=0) {
		$model =~ s/-//go;		## replace dashes with nothing.
		push @words, $model;
		}

	## phase2: different logic to pickup some window lickers.
	##	 and this time replace all non-alphanumeric with dashes
	$model = lc($modelsku);
	$model =~ s/[^a-z0-9]/-/go;  ## this time replace all non-alphanumeric with dashes
	push @words, $model;
	if (index('-',$model)>=0) {
		$model =~ s/-/ /go;			## now replace dashes with space (handles model: PR5 57L 70E-6S1)
		push @words, $model;
		}
	push @words, "\n";

	## phase3: now lets do some phrase spinning PR5 57L 70E-6S1
	## 	as: 57L-70E-6S1
	## 	as: 70E-6S1
	$model = lc($modelsku);
	$model =~ s/[^a-z0-9]+/ /go;
	my @chunks = split(/[\s]+/,$model);
	my $i = scalar(@chunks);
	while ($i-->1) {
		pop @chunks; 
		push @words, join('-',@chunks);
		push @words, join('_',@chunks);
		}
	push @words, "\n";

	# print "DONE $modelsku is: $txt\n"; return($txt);

	##		then as: PR5-57L-70E
	##		then as: PR5-57L
	@chunks = split(/[\s]+/,$model);
	$i = scalar(@chunks);
	while ($i-->1) {
			shift @chunks;
			push @words, join('-',@chunks);
			push @words, join('_',@chunks);
			}
	## phase4: lets loose some characters -- so 2010397 becomes
	##		as: 201039
	##		as: 20103
	##		as: 2010
	push @words, "\n";
	$model = lc($modelsku);
	$model =~ s/[^a-z0-9]+//go;
	if ($model ne $modelsku) {
		## so the original has spaces and stuff.
		push @words, $model;
		}

	push @words, "\n";
	@chunks = split(//,$model);
	$i = scalar(@chunks);
	while ($i-->3) {
		pop @chunks; 
		push @words, join('',@chunks);
		}
	##		now as: 010397
	##		now as: 10397
	##		now as: 0397
	if (1) {
		push @words, "\n";
		@chunks = split(//,$model);
		$i = scalar(@chunks);
		while ($i-->3) {
			shift @chunks;
			push @words, join('',@chunks);
			}
		}

	my $txt = join(' ',@words);

	# print "DONE $modelsku is: $txt\n";

	return($txt);
	}


##############################################################################
##
## build_catalog
## returns: 0 on success
##				negative value on fail (e.g. catalog doesn't exist)
##
##	 NOTE: 
##		FORMAT can be 'FULLTEXT' or 'FINDER'
##
#sub build_catalog {
#	my ($USERNAME, $CATALOG, $RESET, $bj) = @_;
#
#	my ($CATREF) = &SEARCH::fetch_catalog($USERNAME,$CATALOG);
#	if ((defined $bj) && (ref($bj) eq 'BATCHJOB')) {
#		$CATREF->{'JOBID'} = $bj->id();
#		}
#
#	require POGS;
#	my $BATCHSIZE = 150;
#	my $STORESIZE = 50;
#
#	my $success = 0;
#	## okay, so at this point we know..	
#	## the catalog name, the attributes, the lasttime it was indexed (if we care??) and what time we started
#	## now lets open the database
#
#	my $STARTTS = time();
#	my $pstmt = '';
#
#	my $tmpfile = "/tmp/SEARCH-$USERNAME-$CATALOG.cdb";
#	my $savefile = &ZOOVY::resolve_userpath($USERNAME)."/SEARCH-$CATALOG.cdb";
#
#	use CDB_File;
#	use CDB_File::Generator;
#	use PRODUCT;
#	my $gen = new CDB_File::Generator($savefile,$tmpfile);
#
#	my $TS = 0;
#	if ($RESET) {
#		## Clean out catalog to start from scratch
#		## Select all of the products
#		}
#	else {
#		$TS = &ZTOOLKIT::mysql_to_unixtime($CATREF->{'LASTINDEX'});
#		## BEGIN Load old values into this CDB File!
#		my %CAT = ();
#		my $cdb = tie %CAT, 'CDB_File', $savefile;
#		foreach my $key (keys %CAT) {
#		   my $resultref = $cdb->multi_get($key);
#		   next if (not defined $resultref);      # oh shit!
#		   next if (scalar @{$resultref}==0);     # key not found
#
#			foreach my $pairset (@{$resultref}) {
#				$gen->add($key,$pairset);
#				}
#			}
#		untie $cdb;
#		## END Load old values
#		}
#
#	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
#
#	## implicitly reset the product_cache before we rebuild a search index (it's just better that way)
#	$ZOOVY::GLOBAL_CACHE_FLUSH = 1;
#	&ZOOVY::nuke_product_cache($USERNAME);
#	my @PRODUCTS = &ZOOVY::fetchproduct_list_by_merchant($USERNAME,$TS);
#	# my @PRODUCTS = ('ICN-10017-C');
#	#foreach my $pid (@PRODUCTS) {
#	#	next unless ($pid eq 'ICN-10017-C');
#	#	die();
#	#	}
#	# exit;
#	
#	# @PRODUCTS = ( 'RFR-BD-42BF' );
#	my $batches = &PRODUCT::batchify(\@PRODUCTS,150);
#	@PRODUCTS = undef;
#
#	my %KILLWORDS = ();
#	my $remain = scalar(@{$batches});
#	my $keys = 0;				# this is a count of keys which will be merged into actualkeys
#	my $actualkeys = 0;		# this is a count of unique keys which will be stored into the file.
#
#
#
#	## each batch is an array ref of product ids.
#	my %keymerge = ();			## key=word value=5*prod,3*prod2,7*prod3
#	my %BIGWORDS = ();			## keeps track of words that appear a lot in each segment key=word value=count
#	my $STORECOUNT = 0;
#	my $batchcount = 0;
#	my $pidcount = 0;
#	foreach my $batch (@{$batches}) {
##		print STDERR "REMAIN: $remain\n";
#		if (defined $bj) {
#			$batchcount++;					
#			$bj->progress($batchcount,scalar(@{$batches}),"Processing $CATALOG - processed $pidcount products");
#			}
#
#		my $ref = &ZOOVY::fetchproducts_into_hashref($USERNAME,$batch);
#		foreach my $prod (@{$batch}) {
#			$ref->{$prod}->{'id'} = uc($prod);
#			$pidcount++;
##			next if ($prod ne 'KTO-KOTOS-B5');
##			print "PROD: $prod\n";
#
#			## Build a string that we're going to search for keywords through
#			my $index_text = '';
#			my $key_matches = undef;
#			if ($CATREF->{'FORMAT'} eq 'FINDER') {
#				## FINDER POG INDEXING
#				$key_matches = &POGS::text_to_finder($USERNAME,$prod,$ref->{$prod});
#				}
#			else {
#				## FULLTEXT INDEXING!
#				foreach my $attrib (split(/[,\n\r]+/, $CATREF->{'ATTRIBS'})) { 
#					next if ($attrib eq '');
#					$attrib =~ s/^[\s]+//g;
#					$attrib =~ s/[\s]+$//g;
#
#					# print STDERR "ATTRIB: $attrib [$ref->{$prod}->{$attrib}]\n";
#					if (($attrib eq 'id') || ($attrib eq 'zoovy:prod_mfgid')) {
#						$index_text .= ' '.$ref->{$prod}->{$attrib}.' '.&SEARCH::explode($ref->{$prod}->{$attrib});
#						}
#					elsif ($attrib eq 'zoovy:pogs') {
#						## Handle options
#						my ($pogs2) = &ZOOVY::fetch_pogs($USERNAME, $ref->{$prod});
#						my $txt = '';
#						foreach my $pog (@{$pogs2}) {
#							$txt .= "$pog->{'id'}: $pog->{'prompt'}\n";
#							if ($pog->{'@options'}) {
#								foreach my $opt (@{$pog->{'@options'}}) {
#									$txt .= "$opt->{'id'}$opt->{'val'}: $opt->{'prompt'}\n";
#									}
#								}
#							}
#						$index_text .= $txt;
#						# $index_text .= &POGS::text_to_html($USERNAME, $ref->{$prod}->{'zoovy:pogs'}, undef, 8+2, $prod);
#						}
#					else {
#						$index_text .= ' '.$ref->{$prod}->{$attrib}; 
#						}
#					}
#
#				# print "INDEX: $index_text\n";
#
#				## Search for keywords in the string we just assembled.  $key_matches is a hashref
#				## keyed by a keyword with a value of the number of hits for the keyword
#				($key_matches) = SEARCH::find_keywords($index_text,$CATREF);
#				# print "KEY MATCHES: ".Dumper($key_matches)."\n";
#				}
#
#			foreach my $keyword (keys %{$key_matches}) {
#				# print "KEY: $keyword\n";
#				$keys++;
#				my $str = $key_matches->{$keyword}.'*'.uc($prod);
#				if (defined $keymerge{$keyword}) { 
#					$keymerge{$keyword} .= ','.$str; 
#					if (not defined $BIGWORDS{$keyword}) { $BIGWORDS{$keyword} = 1; }
#					$BIGWORDS{$keyword}++; 		# this contains a count of words that occur freqently in a batch.
#					} 
#				else { 
#					$keymerge{$keyword} = $str; 
#					}
#				}
#			}
#		
#		if (($STORECOUNT++>=$STORESIZE) || ($remain<=1)) {
#			## dump all the words into the segment	
##			print STDERR "adding keys to cdb\n";
#			foreach my $word (keys %keymerge) {
#				$gen->add($word, $keymerge{$word});
#				$actualkeys++;
#				}
#		
#			##
#			## now, if we have any words which appeared more than 1/3rd of the products, then it's probably not a relevant word
#			##		to be searching on, and we kill it. .. eventually this could be tuned a bit more I suppose.
#			##		
#			foreach my $word (keys %BIGWORDS) {
#				next if (defined $KILLWORDS{$word}); # killwords is built from bigwords .. it's designed to keep the index smaller.
#				next unless (($BATCHSIZE*($STORESIZE/2)) / $BIGWORDS{$word}<10);
#				$KILLWORDS{$word}++;
##				print STDERR "ADDING \"$word\" to KILLWORDS\n";
#				}
#
#			%keymerge = ();
#			%BIGWORDS = ();
#			$STORECOUNT = 0;
#			}
#	
##		print STDERR "storecount=[$STORECOUNT] KEY COUNT: $keys (actual: $actualkeys)\n";
#		$remain--;
#		}
#
#	delete $CATREF->{'@TRACELOG'};	## this can get REALLY BIG during a create.
#	$gen->add('..DEBUG..',Dumper($CATREF));
#	$gen->finish();
#
#	chmod(0666,$savefile);
#	chown(65534,65534,$savefile);
#
##	print STDERR "SAVEFILE: $savefile\n";
#
#	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($savefile);
#	if (not defined $mtime) {
##		print STDERR "No savefile.. returning error.";
#		$success = -3;
#		}
#	elsif ( ($mtime>=$STARTTS) ||
#		(($STORECOUNT>0) && ($keys==0) && ($actualkeys==0)) ) {	
#		$success = 0;	# 
#		}
#	elsif (($STORECOUNT==0) && ($keys==0) && ($actualkeys==0)) {
#		print STDERR "Hmmm.. nothing to store, no keys, no nothing.\n";
#		$success = -2;
#		}
#	else {
#		print STDERR "Failure to update LASTINDEX\n";
#		$success = -1;
#		}
#
#	## somewhere a connection is left open, can't find it for the life of me
#	## okay, we're ALWAYS going to reset DIRTY -- but we'll only touch LASTINDEX when 
#	##		we actually had a success.
#	my $udbh = &DBINFO::db_user_connect($USERNAME);	
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#	my $qtCATALOG = $udbh->quote($CATALOG);
#	$pstmt = "update SEARCH_CATALOGS set DIRTY=".int($success).",LASTINDEX=from_unixtime($STARTTS-1) ";
#	$pstmt .= " where MID=$MID /* $USERNAME */ and CATALOG=$qtCATALOG";
#	$SEARCH::DEBUG && &msg($pstmt);
#	print STDERR $pstmt."\n";
#	$udbh->do($pstmt);
#	&SEARCH::rebuild_cache($USERNAME);
#	&DBINFO::db_user_close();	
#
#
#	&DBINFO::db_user_close();
#	return $success;
#	}



sub add_catalog  {
	my ($USERNAME,$CATALOG,$ATTRIBS,%params) = @_;

	$CATALOG =~ s/[\W_]+//g; 
	$CATALOG = uc($CATALOG);

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = &DBINFO::insert($udbh,'SEARCH_CATALOGS',{	
		ID=>0,
		MID=>&ZOOVY::resolve_mid($USERNAME),
		MERCHANT=>$USERNAME,
		CATALOG=>$CATALOG,
		ATTRIBS=>$ATTRIBS,
		DIRTY=>1,
		'*CREATED'=>'now()',
		# FORMAT=>$FORMAT,
		# DICTIONARY_DAYS=>$DICTIONARY_DAYS,
		},debug=>2);		
	#$SEARCH::DEBUG && &msg($pstmt);
	$udbh->do($pstmt);
	&SEARCH::rebuild_cache($USERNAME);
	&DBINFO::db_user_close();


	return(1);
	}



##
##
##
#sub catalog_filepath {
#	my ($USERNAME,$CATALOG) = @_;
#
#	my $file = &ZOOVY::resolve_userpath($USERNAME)."/SEARCH-$CATALOG.cdb";
#	return($file);
#	}


sub del_catalog {
	my ($USERNAME,$CATALOG,$LUSER,$REASON) = @_;
	
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "delete from SEARCH_CATALOGS where MERCHANT=? and CATALOG=?";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute($USERNAME,$CATALOG);
	$sth->finish();
	&SEARCH::rebuild_cache($USERNAME);
	&DBINFO::db_user_close();
	
	$CATALOG =~ s/[\W_]+//g; 
	my $savefile = &ZOOVY::resolve_userpath($USERNAME)."/SEARCH-$CATALOG.cdb";
	unlink($CATALOG);

	&ZOOVY::log($USERNAME,$LUSER,"SEARCH.CATALOG.REMOVED","CATALOG:$CATALOG REMOVED:$REASON","INFO");

	return(0);
	}

##
##
##
sub rebuild_cache {
	my ($USERNAME) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select * from SEARCH_CATALOGS where MID=$MID /* $USERNAME */";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my %ref = ();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		$ref{ $hashref->{'CATALOG'} } = $hashref;
		}
	$sth->finish();

#	my $userpath = &ZOOVY::resolve_userpath($USERNAME);
#	if (! -d $userpath) {
#		warn "could not access $userpath\n";
#		}
#	else {
#		my $indexfile = $userpath.'/catalog-index.bin';
#		my $tmp = "$indexfile.$$";
#		Storable::nstore \%ref, $tmp;
#		chmod(0666,$tmp);
#		chown(65534,65534,$tmp);
#		rename($tmp,$indexfile);
#		&ZOOVY::touched($USERNAME,1);
#		}

	my ($mem) = &ZOOVY::getMemd($USERNAME);
	$mem->set("$USERNAME:catalogs",\%ref);
	&DBINFO::db_user_close();

	return(\%ref);
	}

##
## options is 
##
sub list_catalogs	{
	my ($USERNAME,%options) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my %catalogs = ();

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select * from SEARCH_CATALOGS where MID=$MID /* $USERNAME */";
	$SEARCH::DEBUG && &msg($pstmt);
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	use Data::Dumper;
	my $hashref = undef;
	while ( $hashref = $sth->fetchrow_hashref() ) {
		$catalogs{$hashref->{'ID'}} = $hashref;
		}
	$sth->finish();
	&DBINFO::db_user_close();

	if (not defined $catalogs{'SUBSTRING'}) {
		$catalogs{'SUBSTRING'} = { CATALOG=>'SUBSTRING', ID=>'SUBSTRING' };
		}
	if (not defined $catalogs{'COMMON'}) {
		$catalogs{'COMMON'} = { CATALOG=>'COMMON', ID=>'COMMON' };
		}
	## NOTE: ID is a number for user-created catalogs

	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
	if (defined $gref->{'%tuning'}) {
		## tuning parameters can alter behaviors here.
		if (defined $gref->{'%tuning'}->{'disable_substring'}) {
			delete $catalogs{'SUBSTRING'};
			}
		}

	return(\%catalogs);
	}


##
## attempts to do a local lookup.
##
sub fast_fetch_catalog {
	my ($USERNAME,$CATALOGID,$PRT,$cache) = @_;

	my $fetch = 0;

#	if ($cache < 0) {
#		## we can short circuit this all with a publisher file
#		my $result = undef;
#		my $published_file = &ZOOVY::pubfile($USERNAME,$PRT,"catalogs.yaml");
#		if (-f $published_file) {
#			my $REF = YAML::Syck::LoadFile($published_file);
#			$result = $REF->{$CATALOGID};
#			}
#		return($result);
#		}

#	my $cachets = &ZOOVY::touched($USERNAME);
#	my $localfile = &ZOOVY::cachefile($USERNAME,'catalog-index.bin');
#	my $indexfile = &ZOOVY::resolve_userpath($USERNAME).'/catalog-index.bin';
#	my $resultref = undef;
#
#	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($localfile);
#	if ($mtime > $cachets) {
#		$indexfile = $localfile;
#		}
#	elsif (-f $indexfile) {
#		warn "fast_fetch_catalog is loading new catalog cache file from server $localfile";
#		system("/bin/cp $indexfile $localfile");
#		chmod(0666,$localfile);
#		chown(65534,65534,$localfile);
#		## we don't actually use it, until next lookup
#		}
#	else {
#		## wow.. no index file on server, build one (and we'll continue to use it on the server)
#		warn "fast_fetch_catalog is rebuilding catalog index.";

	my $xref = undef;
	my ($memd) = &ZOOVY::getMemd($USERNAME);
	if ($memd) {
		$xref = $memd->get("$USERNAME:catalogs");
		if (scalar($xref) && ($xref eq '')) { 
			$xref = undef; 
			}
		else {
			## print STDERR "USED CACHE!\n";
			}
		}

	if (not defined $xref) {
		$xref = &SEARCH::rebuild_cache($USERNAME);
		# $resultref = &SEARCH::fetch_catalog($USERNAME,$CATALOGID);
		}

		
#	if (not defined $resultref) {
#		my $xref = undef;
#		eval { $xref = Storable::retrieve($indexfile); };
#		if ($@) {
#			&ZOOVY::confess($USERNAME,"catalog file $indexfile doesn't exist!",justkidding=>1);
#			}
#		else {
	my $resultref = $xref->{$CATALOGID};
#			}
#		}
	
	return($resultref);
	}


##
##
##
sub fetch_catalog	{
	my ($USERNAME,$CATALOGID) = @_;

	$CATALOGID =~ s/[\W_]+//g; 

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $qtCATALOG = $udbh->quote($CATALOGID);
	my $pstmt = "select * from SEARCH_CATALOGS where MID=$MID /* $USERNAME */ and CATALOG=$qtCATALOG";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my $resultref = undef;
	if ($sth->rows()) {
		$resultref = $sth->fetchrow_hashref();
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return($resultref);
	}

##
## pass text, it returns a keyword hash count.
##		options: detail=>1 (return hashref + dictionary)
##		
##
#sub find_keywords {
#	my ($text,$optionsref) = @_;
#
##	$optionsref->{'@TRACELOG'} = [];
#	
#	if (defined $optionsref->{'@TRACELOG'}) {
#		push @{$optionsref->{'@TRACELOG'}}, "---------------------------[ STAGE1: STRUCTURE INPUT ]";
#		}
#	my $detail = ($optionsref->{'detail'})?1:0;
##	if (not defined $SEARCH::CACHE_INFINITIVE) {
##		## since we call this function repeatedly and this object is expensive to instantiate -- we'll just create it globally.
##		$SEARCH::CACHE_INFINITIVE = Lingua::EN::Infinitive -> new();
##		}
#
#	my $counthash = {}; # Hashref, indexed by word, with a value of the number of times the word was found.
#
##	$SEARCH::DEBUG && &msg("find_keywords was sent : $text");
#	
#
#	if ($optionsref->{'FORMAT'} eq 'FINDER') {
#		## finders should *NEVER* lowercase their keywords.
#		}
#	else {
#		if (defined $optionsref->{'@TRACELOG'}) {
#			push @{$optionsref->{'@TRACELOG'}}, "BEFORE STRUCTURE: $text";
#			}
#		## we use study here because 99% of the time we're not actually going to make changes. (play the odds)
#		$text = ' '.lc($text).' ';	 # note: we need spaces on either side to reg'ex's don't go wild.
#		# print STDERR Dumper($optionsref);
#
#		if ($optionsref->{'REPLACEMENTS'} ne '') {
#			require Text::CSV_XS;
#			require IO::Scalar;
#			my ($csv) = Text::CSV_XS->new();
#			my $io = new IO::Scalar \$optionsref->{'REPLACEMENTS'};
#
#			foreach my $line ($io->getlines()) {
#				my $status = $csv->parse($line);         # parse a CSV string into fields
#				my @row = $csv->fields();            # get the parsed fields
#				if ($row[0] eq 'S') {
#					## substring replace
#					$row[1] = quotemeta($row[1]);
#					$row[2] = quotemeta($row[2]);
#					$text =~ s/$row[1]/$row[2]/gs;
#					}
#				}
#			}
#	
#		# $text =~ s/m\&m/hi-christy-and-jamie/igs;
#
#		if ($text =~ /\<[Ss[Cc][Rr][Ii][Pp][Tt].*?\>.*?\<\/[Ss][Cc][Rr][Ii][Pp][Tt]\>/o) {
#			$text =~ s/\<script.*?\>.*?\<\/script\>//gis; # remove javascript
#			}
#
#		if ($text =~ /\<\!\-\-(.*?)\-\-\>/o) {
#			$text =~ s/\<\!\-\-(.*?)\-\-\>/ $1 /gs;       # but preserve comments
#			}
#
#		if ($text =~ /\<.*?\>/) {
#			$text =~ s/\<.*?\>//gs;                       # remove remaining html
#			}
#
#		if ($text =~ /([a-z])\'([a-z])/o) { 
#			$text =~ s/([a-z])\'([a-z])/$1$2/gs;          # Changes "Anthony's" to "Anthonys".  Should leave regular single quotes around phrases alone
#			}
#
#		if ($text =~ /([a-z]+)\-([a-z]+)/o) {
#			## note: if a model contains a number e.g. 42-BF
#			$text =~ s/([a-z]+)\-([a-z]+)/$1 $2/gs;     # Changes "stupid-assed" to "stupid assed".  Dashed words are handled differently than dashed numbers
#			}
#	
#		## apparently ?= behaves badly when it's at the end of a string e.g. 
#		##		' 42-bf' won't match wheres ' 42-bf ' will .. stupid.
#		#if ($text =~ /(\w+)\-(\w+)/s) {
#		#	$text =~ s/(\w+)\-(\w+)/$1_$2/gs;           # Changes any remaining non-text dashed items to underscores 1234-ABCD becomes 1234_ABCD
#		#	}
#
#		# print STDERR "TEXT: [$text]\n";
#		$text =~ s/[^\w_-]/ /gs;                          # Uppercase any non-word/model caharacters, also removes control characters. Only a-z0-9_ and space should remain at this point
#		if (defined $optionsref->{'@TRACELOG'}) {
#			push @{$optionsref->{'@TRACELOG'}}, "AFTER STRUCTURE: $text";
#			}
#		}
#
#	
#
#	if (defined $optionsref->{'@TRACELOG'}) {
#		push @{$optionsref->{'@TRACELOG'}}, "---------------------------[ STAGE2: REWRITES ]";
#		}
#	
#	if ((defined $optionsref->{'REWRITES'}) && ($optionsref->{'REWRITES'} ne '')) {
#		## apply rewrite rules.
#		$text = " $text ";
#		my $i = 0; 
#		my $changed = 0;
#		$optionsref->{'REWRITES'} = lc($optionsref->{'REWRITES'});
#		foreach my $line (split(/[\n\r]+/s,$optionsref->{'REWRITES'})) {
#			# push @{$optionsref->{'@TRACELOG'}}, "LinE: $line\n";
#			$i++;
#			my ($k,$vs) = split(/\:/,$line,2);
#			# push @{$optionsref->{'@TRACELOG'}}, "K[$k] vs[$vs]\n";
#			foreach my $s (split(/,/,$vs)) {
#				$s =~ s/^[\s]+//go;	# strip leading space
#				$s =~ s/^[\s]$//go;	# strip leading space
#				my $op = 0;  ## op == 0 (rewrite equivalence)
#				## check for leading + and if found then op==1 (expand)
#				if (substr($s,0,1) eq '+') { $op=1; $s = substr($s,1); }
#				if (($op>0) && ($optionsref->{'from_search'})) { 
#					## this is necessary when we're actually doing a search because we want translation e.g.
#					## we don't want to search for EGGSHELL *AND* WHITE .. 
#					$op = 0; 
#					}
#				# push @{$optionsref->{'@TRACELOG'}}, "op[$op] s[$s] txt[$text] match:[".(index($text," $s "))."]\n";
#
##				next unless (index($text," $s ")>=0);
#				$s = quotemeta($s);
#				$k = quotemeta($k);
#				if ($op==0) {
#					## rewrite $s to $k (equivalence)
#					$text =~ s/ $s / $k /gs; 
#					}
#				elsif ($op==1) {
#					## add $s to wherever $k appears
#					$text =~ s/ $s / $s $k /gs;  
#					}
#				$changed++;
#				# if (defined $optionsref->{'@TRACELOG'}) { push @{$optionsref->{'@TRACELOG'}}, "MATCHED REWRITE($i,$s): $line\n"; }
#				}
#			## 
#			}
#		if (($changed) && (defined $optionsref->{'@TRACELOG'})) { 
#			push @{$optionsref->{'@TRACELOG'}}, "FINISHED REWRITE made $changed changes.\nText: $text";
#			}
#		}
#
#
#	if (defined $optionsref->{'@TRACELOG'}) {
#		push @{$optionsref->{'@TRACELOG'}}, "---------------------------[ STAGE3: PROCESS KILLWORDS ]";
#		}
#	if ((defined $optionsref->{'KILLWORDS'}) && ($optionsref->{'KILLWORDS'} ne '')) {
#		$text = " $text ";
#		my $i = 0;
#		my ($changed) = 0;
#		$optionsref->{'KILLWORDS'} = lc($optionsref->{'KILLWORDS'});
#		foreach my $term (split(/[\n\r\,]+/s,$optionsref->{'KILLWORDS'})) {
#			if (index($text,$term)>=0) {
#				$term = quotemeta($term);
#				$text =~ s/ $term / /g;
#				$changed++;
#				if (defined $optionsref->{'@TRACELOG'}) { push @{$optionsref->{'@TRACELOG'}}, "FOUND KILLWORD: $term\n"; }
#				}
#			}		
#		if (($changed) && (defined $optionsref->{'@TRACELOG'})) { 
#			push @{$optionsref->{'@TRACELOG'}}, "FINISHED KILLWORDS made $changed changes.\n";
#			}
#		}
#
#	if (defined $optionsref->{'@TRACELOG'}) {
#		push @{$optionsref->{'@TRACELOG'}}, "---------------------------[ STAGE4: PROCESS TRANSFORMATIONS ]";
#		}
#
#	# print "TEXT: $text\n";
#
#	my %dictionary = ();
#	foreach my $word (split(/[ ]+/, $text)) {
#		next if ($word eq '');
#
#		
#
#		if ($word =~ /\d/) {
#			## keep all numbers!
#			$counthash->{$word}++;
#			}
#		elsif (length($word)<3) {
#			# Skip any text word less than 3 characters
#			if (defined $optionsref->{'@TRACELOG'}) {
#				push @{$optionsref->{'@TRACELOG'}}, "DISCARD word '$word\' is too short.\n";
#				}
#			}
#		#elsif ($word =~ /^[^aeiou]+$/) {
#		#	$counthash->{$word}++;
#		#	}
#		elsif ($word =~ /([^aeiou]{3,3})/) {
#			## no vowels - wtf? this will make inflections or metaphone cheese badly.
#			## no vowels - for more than three simultaneous characters
#			push @{$optionsref->{'@TRACELOG'}}, "TRANSFORM/INFLECTIONS is NOT AVAILABLE for word:$word (3+ simulatenous consonants:$1)";
#			$counthash->{$word}++;
#			}
#		else {
#			my $oword = $word;
#			# print "WORD: $oword\n";
#
#			if (not $optionsref->{'USE_INFLECTIONS'}) {
#				## INFLECTIONS DISABLED
#				push @{$optionsref->{'@TRACELOG'}}, "TRANSFORM/INFLECTIONS is DISABLED";
#				}
#			else {
##				$word = Lingua::EN::Inflect::Number::to_PL($word);
##				if (defined $optionsref->{'@TRACELOG'}) {
##					push @{$optionsref->{'@TRACELOG'}}, "TRANSFORM/INFLECTION word '$oword' is now '$word'\n";
##					}
#				}
#
#			if (not $optionsref->{'USE_WORDSTEMS'}) {
#				## WORDSTEM DISABLED
#				}
#			elsif (length($word)>=7) {
#				## for words which have a length >=7 we grab the split infinitive e.g. assholes becomes "asshole" and "sexuality" becomes "sexual"
##				my ($word1, $word2, $suffix, $rule) = $SEARCH::CACHE_INFINITIVE->stem($word);
##				if ($word1 ne '') { $word = $word1; }
##				if (defined $optionsref->{'@TRACELOG'}) {
##					push @{$optionsref->{'@TRACELOG'}}, "TRANSFORM/WORDSTEM word '$oword' is now '$word'\n";
##					}
#
#				}
#			else {
#				if (defined $optionsref->{'@TRACELOG'}) {
#					push @{$optionsref->{'@TRACELOG'}}, "TRANSFORM/WORDSTEM not done because word '$word' length is less than 7\n";
#					}
#				}
#
#			if (not $optionsref->{'USE_SOUNDEX'}) {
#				## SOUNDEX DISABLED
#				}
#			#elsif ($word eq 'mtxslbldnex') {
#			#	## this word makes text/metaphone crash
#			#	}
#			elsif (length($word)>=5) { 
#				# print "WORD: $word\n";
##				$word = Metaphone($word); 
##				if (defined $optionsref->{'@TRACELOG'}) {
##					push @{$optionsref->{'@TRACELOG'}}, "TRANSFORM/METAPHONE word '$oword' is now '$word'\n";
##					}
#				}
#			else {
#				if (defined $optionsref->{'@TRACELOG'}) {
#					push @{$optionsref->{'@TRACELOG'}}, "TRANSFORM/METAPHONE not done because word '$word' length less than 5\n";
#					}				
#				}
#
#			if (not defined $counthash->{$word}) { $counthash->{$word} = 0; }
#			$counthash->{$word}++;
#			if (($detail&1) && 
#				(defined $dictionary{$word}) && 
#				($dictionary{$word} !~ /$oword\,/)) {
#					$dictionary{$word} .= $oword.',';
#				}
#			}
#		}
#
#	# use Data::Dumper;
#	# print STDERR Dumper($counthash);
#	if (defined $optionsref->{'@TRACELOG'}) {
#		push @{$optionsref->{'@TRACELOG'}}, "---------------------------[ STAGE5: LOOKUP RESULTS ]";
#		}
#	if ($detail&1) { 
#		return($counthash,\%dictionary); 
#		}
#
##	print STDERR 'TRACELOG: '.Dumper($optionsref->{'@TRACELOG'});
#
#	return ($counthash);
#	}
#


##
## note: sets is an arrayref of sets
##
#sub OLD_finder {
#	my ($USERNAME, $cgiparams, %options) = @_;
#
#	my @SOGS = ();
#	my @invcheck = ();
#	# $cgiparams->{'_inventory'}++;
#	my @inventory = ();
#	my $TRACELOG = $options{'@TRACELOG'};
#	
#	## okay, this is where we decide which params are valid FINDERS
#	foreach my $k (keys %{$cgiparams}) {
#		if (substr($k,0,1) eq '_') {
#			## _inventory
#			## _navcat
#			if (defined $TRACELOG) {
#				push @{$TRACELOG}, "setting option $k=$cgiparams->{$k}";
#				}
#			$options{$k} = $cgiparams->{$k};
#			}
#		elsif ((substr($k,0,1) eq ':') && ((length($k)==5) || (length($k)==7))) {
#			## its' the key (which is either 4 or 6 digits long)
#			## e.g. :ZZ00 or :ZZ0000 (the six digit finders are for automotive)
#			push @SOGS, uc(substr($k,1));
#			}
#		elsif (substr($cgiparams->{$k},0,1) eq ':') {
#			## it's in the value, better check for separators inside the value e.g. :0001:0002:0003
#			foreach my $kk (split(/:/,$cgiparams->{$k})) {
#				next if ($kk eq '');
#				next if (length($kk)==2);	## yipes! a two digit value is an "ANY" so we'll skip that.
#				push @SOGS, $kk;
#				}
#			}
#		else {
#			## skip incorrectly formatted keys.
#			}
#		}
#
#	if (defined $TRACELOG) {
#		push @{$TRACELOG}, "Looking for SOGS: ".Dumper(@SOGS);
#		}
#
#	##
#	## SANITY: at this poing @SOGS is populated with each word we're going to lookup.
#	##
#	my %WORDRESULTS = ();	# a hash keyed by SET where VALUE is product id that was found.
#	my %PIDS = ();
#
##	my $cdb = undef;
##	my $file = &ZOOVY::resolve_userpath($USERNAME)."/SEARCH-FINDER.cdb";
##	my %CAT;
##	if (-f $file) { $cdb = tie %CAT, 'CDB_File', $file; }
##	if (defined $cdb) {
##		foreach my $key (@SOGS) {
##			my $resultref = $cdb->multi_get($key);
##
##			if (defined $TRACELOG) {
##				push @{$TRACELOG}, "SOG($key) returned: ".Dumper($resultref);
##				}
##	
##			next if (not defined $resultref);		# oh shit!
##			next if (scalar @{$resultref}==0);		# key not found
##
##			my %thisSet = ();			# this tracks words found in this set if we are in "AND" mode
##			foreach my $pairset (@{$resultref}) {
##				foreach my $prodmatch (split(/,/,$pairset)) {
##					my ($match,$prod) = split(/\*/, $prodmatch, 2); # Product, number of matches of keyword for product
##					next if ($prod eq ''); # Skip blanks
##					next if (($match eq '') || (int($match) eq 0)); # We should never see this, but just in case
##					$WORDRESULTS{$key}->{$prod} = $match;
##					$PIDS{$prod}++;
##					}
##				}
##			}
##		}
##	undef $cdb;
##	undef %CAT;
#
#	
#	if (defined $TRACELOG) {
#		push @{$TRACELOG}, "MATCHING PIDS: ".Dumper([keys %PIDS]);
#		}
#
#	##
#	## we SHOULD be able to just count up how many of the PIDS have a count which is equal to scalar(@SOGS)
#	##
#	my $need = scalar(@SOGS);
#	my @pids = ();
#	my %pids = ();
#	foreach my $pid (keys %PIDS) {
#		next if ($PIDS{$pid}<$need);
##		print STDERR "KEY: $key\n";	
#		push @pids, uc($pid);
#		}
#
#	##
#	## _navcat=>1
#	##
#	if (not defined $options{'_navcat'}) {
#		$options{'_navcat'} = 0;
#		}
#
#	if (int($options{'_navcat'})==1) {
#		my @newpids = ();
#		if (not defined $options{'PRT'}) {
#			$options{'PRT'} = 0;
#			if (defined $TRACELOG) {
#				push @{$TRACELOG}, "Defaulting to partition 0";
#				}
#			}
#
#		my $okaytoshowref = undef;
#		my ($NC) = NAVCAT->new($USERNAME,PRT=>$options{'PRT'},cache=>1);
#		my ($ROOT) = '.';
#		if (defined $options{'ROOT'}) { 
#			$ROOT = $options{'ROOT'}; 
#			}
#		elsif (defined $SITE::SREF->{'_ROOTCAT'}) {
#			$ROOT = $SITE::SREF->{'_ROOTCAT'};
#			}
#	
#		if (defined $TRACELOG) { push @{$TRACELOG}, "Using ROOT: $ROOT"; }
#			
#		$okaytoshowref = $NC->okay_to_show($USERNAME,undef,$ROOT);
#		undef $NC;
#
#		my $count = scalar(@pids);
#		foreach my $pid (@pids) {
#			if (not defined $okaytoshowref->{$pid}) {
#				if (defined $TRACELOG) {
#					push @{$TRACELOG}, "Removed product $pid from result set because it was not within category=$ROOT prt=$options{'PRT'}";
#					}
#				}
#			else {
#				push @newpids, $pid;
#				}
#			}
#		@pids = @newpids;
#		}
#
#	##
#	## Okay .. lets check inventory for each inventoriable SOG to make sure it's available.
#	##
#	# $cgiparams->{'_inventory'}++;
#	my @INVSOGS = ();
#	if ($cgiparams->{'_inventory'}>0) {
#		foreach my $SOG_ID_VAL (@SOGS) {
#			my ($sogref) = &POGS::load_sogref($USERNAME,$SOG_ID_VAL);
#			if ($sogref->{'inv'}>0) { push @INVSOGS, ":$SOG_ID_VAL"; }
#			#my @sogs = POGS::text_to_struct($USERNAME,POGS::load_sog($USERNAME,substr($SOG_ID_VAL,0,2),undef,1),0,1);
#			#if ($sogs[0]->{'inv'}>0) { push @INVSOGS, ":$SOG_ID_VAL"; }
#			}
#		}
#	## SANITY: at this point @INVSOGS is an array of inventoriable :+sogid+sogval
#	# print STDERR Dumper(\@INVSOGS);
#
#	if (scalar(@INVSOGS)>0) {
#		my ($ref) = INVENTORY::fetch_incrementals($USERNAME,\@pids,1);
#		%PIDS = ();
#		foreach my $sku (keys %{$ref}) {
#			my $skip = 0;
#			if ($ref->{$sku}<=0) { $skip++; }
#			foreach my $optionid (@INVSOGS) {
#				if ($sku !~ /$optionid/) { $skip++; }
#				}
#			next if ($skip);
#			my ($pid) = &PRODUCT::stid_to_pid($sku);
#			$PIDS{$pid}++;
#			}
#		@pids = keys %PIDS;
#		}
#		
#	undef %PIDS;
#	undef %WORDRESULTS;
#	undef @SOGS;
#
#	return(\@pids);
#	}




##
## note: sets is an arrayref of sets
##
sub finder {
	my ($SITE, $cgiparams, %options) = @_;

	my $USERNAME = $SITE->username();

	my @SOGS = ();
	my @invcheck = ();
	# $cgiparams->{'_inventory'}++;
	my @inventory = ();
	my $TRACELOG = $options{'@TRACELOG'};
	
	## okay, this is where we decide which params are valid FINDERS
	foreach my $k (keys %{$cgiparams}) {
		if (substr($k,0,1) eq '_') {
			## _inventory
			## _navcat
			if (defined $TRACELOG) {
				push @{$TRACELOG}, "setting option $k=$cgiparams->{$k}";
				}
			$options{$k} = $cgiparams->{$k};
			}
		elsif ((substr($k,0,1) eq ':') && ((length($k)==5) || (length($k)==7))) {
			## its' the key (which is either 4 or 6 digits long)
			## e.g. :ZZ00 or :ZZ0000 (the six digit finders are for automotive)
			push @SOGS, uc(substr($k,1));
			}
		elsif (substr($cgiparams->{$k},0,1) eq ':') {
			## it's in the value, better check for separators inside the value e.g. :0001:0002:0003
			foreach my $kk (split(/:/,$cgiparams->{$k})) {
				next if ($kk eq '');
				next if (length($kk)==2);	## yipes! a two digit value is an "ANY" so we'll skip that.
				push @SOGS, $kk;
				}
			}
		else {
			## skip incorrectly formatted keys.
			}
		}

	if (defined $TRACELOG) {
		push @{$TRACELOG}, "Looking for SOGS: ".Dumper(@SOGS);
		}

	##
	## SANITY: at this poing @SOGS is populated with each word we're going to lookup.
	##
	my %WORDRESULTS = ();	# a hash keyed by SET where VALUE is product id that was found.
	my %PIDS = ();

#	if (0) {
##		print STDERR Dumper(\@SOGS);
#		my $cdb = undef;
#		my $file = &ZOOVY::resolve_userpath($USERNAME)."/SEARCH-FINDER.cdb";
#		my %CAT;
#		if (-f $file) { $cdb = tie %CAT, 'CDB_File', $file; }
#		if (defined $cdb) {
#			foreach my $key (@SOGS) {
#				my $resultref = $cdb->multi_get($key);
#	
#				if (defined $TRACELOG) {
#					push @{$TRACELOG}, "SOG($key) returned: ".Dumper($resultref);
#					}
#		
#				next if (not defined $resultref);		# oh shit!
#				next if (scalar @{$resultref}==0);		# key not found
#	
#				my %thisSet = ();			# this tracks words found in this set if we are in "AND" mode
#				foreach my $pairset (@{$resultref}) {
#					foreach my $prodmatch (split(/,/,$pairset)) {
#						my ($match,$prod) = split(/\*/, $prodmatch, 2); # Product, number of matches of keyword for product
#						next if ($prod eq ''); # Skip blanks
#						next if (($match eq '') || (int($match) eq 0)); # We should never see this, but just in case
#						$WORDRESULTS{$key}->{$prod} = $match;
#						$PIDS{$prod}++;
#						}
#					}
#				}
#			}
#		undef $cdb;
#		}
	if (1) {
		if (defined $TRACELOG) {
			push @{$TRACELOG}, "Using Elastic Search: ".join(",",@SOGS);
			}

		my ($es) = &ZOOVY::getElasticSearch($USERNAME);
	   my $results = undef;
		print STDERR "DOING ELASTIC B\n";
		eval { 
			$results = $es->search( 
				'index'=>"$USERNAME.public", 
				'body'=>{
					filter=> { 
						"terms" => { "pogs"=>\@SOGS, "execution"=>"and" } 
						}
					,size=>$SEARCH::ELASTIC_RESULTS 
					}
				);
				};
		if (not defined $results) {
			push @{$TRACELOG}, "SEARCH ERROR: $@";
			}
		elsif ($results->{'hits'}->{'total'}>0) {
			foreach my $hit (@{$results->{'hits'}->{'hits'}}) {
				if ($hit->{'_type'} eq 'product') {
					$PIDS{$hit->{'_id'}} = $hit->{'_score'}*1000;
					}
				}
			}
		print STDERR "DONE ELASTIC B\n";
		}
	
	if (defined $TRACELOG) {
		push @{$TRACELOG}, "MATCHING PIDS: ".Dumper([keys %PIDS]);
		}

	##
	## we SHOULD be able to just count up how many of the PIDS have a count which is equal to scalar(@SOGS)
	##
	my $need = scalar(@SOGS);
	my @pids = ();
	my %pids = ();
	foreach my $pid (keys %PIDS) {
		next if ($PIDS{$pid}<$need);
#		print STDERR "KEY: $key\n";	
		push @pids, uc($pid);
		}


	##
	## _navcat=>1
	##
	if (not defined $options{'_navcat'}) {
		$options{'_navcat'} = 0;
		}

	if (int($options{'_navcat'})==1) {
		my @newpids = ();
		if (not defined $options{'PRT'}) {
			$options{'PRT'} = 0;
			if (defined $TRACELOG) {
				push @{$TRACELOG}, "Defaulting to partition 0";
				}
			}

		my $okaytoshowref = undef;
		my ($NC) = NAVCAT->new($USERNAME,PRT=>$options{'PRT'},cache=>1);
		my ($ROOT) = '.';
		if (defined $options{'ROOT'}) { 
			$ROOT = $options{'ROOT'}; 
			}
		elsif (defined $SITE->rootcat()) {
			$ROOT = $SITE->rootcat();
			}
	
		if (defined $TRACELOG) { push @{$TRACELOG}, "Using ROOT: $ROOT"; }
			
		$okaytoshowref = $NC->okay_to_show($USERNAME,undef,$ROOT);
		undef $NC;

		my $count = scalar(@pids);
		foreach my $pid (@pids) {
			if (not defined $okaytoshowref->{$pid}) {
				if (defined $TRACELOG) {
					push @{$TRACELOG}, "Removed product $pid from result set because it was not within category=$ROOT prt=$options{'PRT'}";
					}
				}
			else {
				push @newpids, $pid;
				}
			}
		@pids = @newpids;
		}

	##
	## Okay .. lets check inventory for each inventoriable SOG to make sure it's available.
	##
	# $cgiparams->{'_inventory'}++;
	my @INVSOGS = ();
	if ($cgiparams->{'_inventory'}>0) {
		foreach my $SOG_ID_VAL (@SOGS) {
			my ($sogref) = &POGS::load_sogref($USERNAME,$SOG_ID_VAL);
			if ($sogref->{'inv'}>0) { push @INVSOGS, ":$SOG_ID_VAL"; }
			#my @sogs = POGS::text_to_struct($USERNAME,POGS::load_sog($USERNAME,substr($SOG_ID_VAL,0,2),undef,1),0,1);
			#if ($sogs[0]->{'inv'}>0) { push @INVSOGS, ":$SOG_ID_VAL"; }
			}
		}
	## SANITY: at this point @INVSOGS is an array of inventoriable :+sogid+sogval
	# print STDERR Dumper(\@INVSOGS);

	if (scalar(@INVSOGS)>0) {
		my ($INVSUMMARY) = INVENTORY2->new($USERNAME)->summary('@PIDS'=>\@pids);
		%PIDS = ();
		foreach my $sku (keys %{$INVSUMMARY}) {
			my $skip = 0;
			if ($INVSUMMARY->{$sku}->{'AVAILABLE'}<=0) { $skip++; }
			foreach my $optionid (@INVSOGS) {
				if ($sku !~ /$optionid/) { $skip++; }
				}
			next if ($skip);
			my ($pid) = &PRODUCT::stid_to_pid($sku);
			$PIDS{$pid}++;
			}
		@pids = keys %PIDS;
		}
		
	undef %PIDS;
	undef %WORDRESULTS;
	undef @SOGS;

	return(\@pids);
	}









##
##
##
#sub keyCount {
#	my ($USERNAME,$catalog,$key) = @_;
#
#	
#	
#	}


##
## returns:
##		resultref = an arrayref of pids.
##		productsref = a hashref of all product results keyed by pid, data in hashref 
##			NOTE: productsref is NOT always populated! only on virtual results and other cases 
##		mode
##			SUBSTRING
##			STRUCTURED
##			FINDER
##		options:
##			debug - disables 'safe to show' behavior.
##			speed - disables 'safe to show' and does not record (used for dictionary building)
##				1 = do NOT run 'safe to show'
##				2 = do NOT record 
##				4 = make local copy of cdb
###			8 = use cached bin-file of search catalog
##
sub search {
	my ($SITE, %options) = @_;

	my $USERNAME = undef;
	if (ref($SITE) eq 'SITE') {
		$USERNAME = $SITE->username();
		}
	else {
		$USERNAME = $SITE;
		$SITE = undef;
		}
		

	# open F, ">>/tmp/search.log";	print F "MERCHANT:$USERNAME ".Dumper(\%options)."\n";	close F;

	## $options{'PRT'} is passed in some locations.
	my $mode = $options{'MODE'};
	my $keywords = $options{'KEYWORDS'};
	$keywords =~ s/[\s]+$//gs; # strip trailing space
	$keywords =~ s/^[\s]+//gs;	# strip leading space
	my $catalog = $options{'CATALOG'};
	my $LOG = $options{'LOG'};
	if (not defined $LOG) { $LOG = 1; }

	my $SREF = $options{'*SREF'};
	my $cache = 0;
	if (defined $SREF) { $cache = $SREF->{'+cache'}; }

	# print STDERR "SEARCH[$cache]: \n".Carp::cluck()."\n\n";

	my $PRT = int($options{'PRT'});
	
#	my ($webdbref) = $options{'%webdb'};
#	if (not defined $webdbref) {
#		$webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT,$cache);
#		}


#	print STDERR "Doing SEARCH $USERNAME, $mode, $keywords, $catalog\n";
	my @TRACELOG = ();
	$options{'@TRACELOG'} = \@TRACELOG;
	my $DEBUG = (defined $options{'debug'})?int($options{'debug'}):0;		# default to debug=0
	my $SPEED = (defined $options{'speed'})?int($options{'speed'}):0;		# default to speed=0

	require NAVCAT;
	if (not defined $mode) { $mode = ''; }

	## EXACT/SRC:elementid/LOG:0
	## AND/SRC:elementid/LOG:1
	if (index($mode,"/")>=0) {
		## mode has slashes in it.. so it has extra parameters .. always starts with AND|OR|EXACT
		my @kvs = split(/\//,$mode);
		$mode = shift @kvs;
		foreach my $kv (@kvs) {
			my ($k,$v) = split(/:/,$kv,2);
			if ($k eq 'LOG') { 
				$LOG = int($v);
				}
			elsif ($k eq 'SRC') {
				## don't actually do anything different here, but we record SRC 
				## so the reports can generate a separate report.
				}
			}
		}

	if (not defined $catalog) { $catalog = ''; }
	elsif ($catalog =~ /[^A-Z0-9]/) { $keywords = undef; }	# bail if we asked for an invalid catalog

	# if ($USERNAME eq 'beachmart') { $SPEED = 0xFF; }
	
	my $prodsref = undef;
	return(undef,undef,['No keywords passed']) unless (defined($keywords) && $keywords);

#	if ($catalog eq '') { 
#		# $catalog = &ZWEBSITE::fetch_website_attrib($USERNAME,'search_primary');
#		$catalog = $webdbref->{'search_primary'};
#		if ($DEBUG) { push @TRACELOG, "catalog not set, using primary [$catalog]"; }
#		}


	if ((not defined $catalog) || ($catalog eq '')) { 
		push @TRACELOG, "Catalog was not set, attempting to use PRIMARY";
		$catalog = 'PRIMARY'; 
		}

	my ($CATREF) = &SEARCH::fast_fetch_catalog($USERNAME,$catalog,$PRT,$cache);

	## NOTE: do not remove catalogs from the list below, it will break things that are unobivious and difficult to test later.	
	##			specifically YOU MUST leave catalog set to FINDER if MODE=STRUCTURED (yes i know how much I'd like to kill this)
	if (substr($keywords,0,-1) eq '-') {
	 	push @TRACELOG, "KEYWORDS ends with invalid character '-' cannot continue";
		$catalog = 'NULL';
		}
	elsif (defined $CATREF) {
		## woot, it exists, use it.
		}
	elsif ($catalog eq 'SUBSTRING') {
		## always exists, it's k, i promise.
		push @TRACELOG, "CATALOG: using SUBSTRING";
		}
	elsif ($catalog eq 'FINDER') {
		## this too, always exists.. it's k, go for it.
		push @TRACELOG, "CATALOG: using FINDER";
		}
	elsif ($catalog eq 'COMMON') {
		## woot.. we're good, they asked for common!
		push @TRACELOG, "CATALOG: using COMMON";
		}
	elsif (not defined $CATREF) {
		push @TRACELOG, "CATALOG: $catalog does not exist, using COMMON";
		$catalog = 'COMMON';	# guaranteed to exist.
		}

	$CATREF->{'DEBUG'} = $DEBUG;
	if ($DEBUG) { $CATREF->{'@TRACELOG'} = \@TRACELOG; }
	if (not defined $options{'ISOLATION_LEVEL'}) {
		$options{'ISOLATION_LEVEL'} = $CATREF->{'ISOLATION_LEVEL'};
		}

	$mode = uc($mode);
	if (($mode eq '') && ($CATREF->{'USE_EXACT'}>0)) { $mode = 'EXACT'; }
	elsif ($mode eq 'STRUCTURED') {}
	elsif (($mode ne 'AND') && ($mode ne 'OR') && ($mode ne 'EXACT')) { $mode = 'AND'; }
	$CATREF->{'MODE'} = $mode;
	$CATREF->{'USERNAME'} = $USERNAME;

	my $pidsfound = {};
	push @TRACELOG, "Using a catalog $catalog (MODE:$mode) for matches $keywords";

#$VAR1 = {
#          'ID' => '3597',
#          'MERCHANT' => 'toynk',
#          'ATTRIBS' => 'toynk:prod_theme',
#          'USE_EXACT' => '1',
#          'DIRTY' => '0',
#          'USE_INFLECTIONS' => '1',
#          'USE_SOUNDEX' => '1',
#          'CREATED' => '2010-05-20 07:30:26',
#          'KILLWORDS' => '',
#          'MID' => '52277',
#          'FORMAT' => 'FULLTEXT',
#          'USE_WORDSTEMS' => '1',
#          'REPLACEMENTS' => '',
#          'DICTIONARY_DAYS' => '0',
#          'USE_ALLWORDS' => '0',
#          'REWRITES' => '',
#          'CATALOG' => 'THEME',
#          'LASTINDEX' => '2012-03-12 15:12:07',
#          'ISOLATION_LEVEL' => '5'
#        };


	my %opts = ();
	my ($es) = &ZOOVY::getElasticSearch($USERNAME);
#	my $qp = $es->query_parser( \%opts );
#	my $filtered_query_string = $qp->filter($keywords,
#		'fields'=>1,
#		'allow_fuzzy'=>$CATREF->{'USE_SOUNDEX'},
#		'allow_slop'=>$CATREF->{'USE_INFLECTIONS'},
#		);
#    escape_reserved => 0
#    fields          => 0
#    boost           => 1
#    allow_bool      => 1
#    allow_boost     => 1
#    allow_fuzzy     => 1
#    allow_slop      => 1
#    allow_ranges    => 0
#    wildcard_prefix => 1

	if ($mode eq 'EXACT') { $mode = 'AND'; }
	if ($mode eq 'STRUCTURED') {}
	elsif ($mode eq 'AND') {}
	elsif ($mode eq 'OR') {}
	else { $mode = 'OR'; }
		

	#$keywords =~ s/\+//gs;
	# $keywords =~ s/\"//gs;
	my @FIELDS = ();
	if ($catalog eq 'SUBSTRING') {
		push @TRACELOG, "Catalog SUBSTRING has fixed field list of: pid,sku,prod_name";
		push @FIELDS, 'pid';
		push @FIELDS, 'skus';
		push @FIELDS, 'prod_name';
		}
	elsif ($catalog eq 'FINDER') {
		push @TRACELOG, "Catalog FINDER has fixed field list of: pogs";
		push @FIELDS, "pogs";
		}
	elsif ($catalog eq 'COMMON') {
		push @TRACELOG, "Catalog COMMON is using elastic search _all fields";
		## no fields specified.
		push @FIELDS, '_all';
		}
	else {
		my %INDEXED = ();
		my ($fields) = &PRODUCT::FLEXEDIT::elastic_fields($USERNAME);
		foreach my $set (@{$fields}) {
			$INDEXED{$set->{'id'}} = $set;
			}

		print STDERR "ATTRIB: $CATREF->{'attribs'} [catalog:$catalog]\n";
		foreach my $attrib (split(/[\r\n,\s]+/,$CATREF->{'ATTRIBS'})) {
			next if ($attrib eq '');
			# print STDERR "ATTRIB: [$attrib]\n";
			if ($attrib eq 'id') {
				push @FIELDS, 'pid'; 
				push @FIELDS, 'skus';
				}
			elsif ($attrib eq 'tags') {
				push @FIELDS, 'tags';
				}
			elsif ($attrib eq 'options') {
				push @FIELDS, 'options';
				}
			elsif ($attrib eq 'pogs') {
				push @FIELDS, 'pogs';
				}
			elsif ($attrib eq 'zoovy:grp_children') {
				push @FIELDS, 'parent';
				}
			elsif ($attrib =~ /^is\:/) {
				push @FIELDS, 'tags';
				}
			elsif ($attrib eq 'zoovy:prod_is_tags') {
				push @FIELDS, 'tags';
				}
			elsif ($attrib eq 'zoovy:pogs') {
				push @FIELDS, 'pogs';
				push @FIELDS, 'options';
				}
			elsif ($attrib eq 'zoovy:prod_salesrank') {
				## this is a numeric field, you don't want to search this with a catalog!
				push @TRACELOG, "Ignoring zoovy:prod_salesrank because it's a numeric field and will cause ise's when used with CATALOG";
				}
			elsif ($attrib eq 'zoovy:base_price') {
				## this is a numeric field, you don't want to search this with a catalog!
				push @TRACELOG, "Ignoring zoovy:base_price because it's a numeric field and will cause ise's when used with CATALOG";
				}
			elsif ($INDEXED{$attrib}) {
				push @FIELDS, $INDEXED{$attrib}->{'index'};
				}
			else {
				push @TRACELOG, "ERROR: Could not determine index for attribute[$attrib] so it will be ignored.\n";
				open F, ">>/tmp/elastic-fail";
				print F sprintf("$USERNAME\t$catalog\t$attrib\t%s\n",&ZTOOLKIT::buildparams(\%options));
				close F;
				}
			}
		}
		

	# print Dumper(\@FIELDS);		

	#$keywords =~ s/[\+\(\k)\"]+//gs;
	#print STDERR Dumper($keywords);
	
	##  perl -e 'use lib "/backend/lib"; use SEARCH; use Data::Dumper; print Dumper(SEARCH::fetch_catalog("toynk","THEME"));'

	if (($mode eq 'NULL') || ($catalog eq 'NULL')) {
		}
	elsif (($mode eq 'STRUCTURED') && ($catalog eq 'FINDER')) {
		$keywords =~ s/^[\s]+//gs;
		$keywords =~ s/[\s]+$//gs;
		push @TRACELOG, "Using STRUCTURED syntax keywords=$keywords";
		print STDERR "STRUCTURED SEARCH: $USERNAME $catalog $keywords\n";
		($pidsfound) = &SEARCH::search_structured($USERNAME,$es,$keywords,\@TRACELOG,$DEBUG);

		if (scalar(keys %{$pidsfound})==0) {
			push @TRACELOG, "WARNING: We received zero matching responses from search_structured.";
			}
		}
	else {
		my %params = ();

		$keywords =~ s/\///gs;		# strip /'s .. they shouldn't be used here!

		if ($catalog eq 'SUBSTRING') {
			## NOTE: before altering this code read about the WILDCARD COMPROMISE (later in code)
			## allows wildcards (adds *keyword* if doesn't exist)
			push @TRACELOG, "Using special SUBSTRING catalog wildcard behavior";
			$keywords =~ s/[^\w\s\-\_\*\?]+/ /gs;
			if ($keywords !~ /[\*\?]+/) { $keywords = "*$keywords*"; }
			}
		elsif ($catalog eq 'PRIMARY') {
			## NOTE: before altering this code read about the WILDCARD COMPROMISE (later in code))
			push @TRACELOG, "Using special PRIMARY catalog wildcard behavior";
			$keywords =~ s/[^\w\s\-\_\*\?]+/ /gs;
			}
		else {
			## doesn't allow wildcards
			$keywords =~ s/[^\w\s\-\_]+/ /gs;
			}

		if ($options{'debug'}) { $params{'explain'} = 'true'; }

		$params{'type'} = 'product';
		$params{'query'} = { 			
			# query_string=>{ analyze_wildcard=>'true', fields=>\@FIELDS, query => $keywords, "default_operator"=>$mode } 
			query_string=>{ fields=>\@FIELDS, query => $keywords, "default_operator"=>$mode } 
			# 'wildcard'=>{ "pid" => $keywords }
			};
		$params{'size'} = $SEARCH::ELASTIC_RESULTS;
		if (($catalog eq 'SUBSTRING') || ($catalog eq 'PRIMARY')) {
			##
			## 5/22/12 - the WILDCARD COMPROMISE (by brian and fred)
			## PRIMARY catalog will allow/detect wildcards
			## SUBSTRING will allow/detect and auto-append (if not present)
			##
			if ((index($keywords,'*')>=0) || (index($keywords,'?')>=0)) {
				## enable wildcards if we see a ? or *
				$params{'query'}->{'query_string'}->{'analyze_wildcard'} = 'true';
				$params{'size'} = int($params{'size'}/2);
				}
			if ((substr($keywords,0,1) eq '*') || (substr($keywords,0,1) eq '?')) {
				## enable leading wildcards if the first character is a * or ?
				$params{'query'}->{'query_string'}->{'allow_leading_wildcard'} = 'true';
				$params{'size'} = int($params{'size'}/2);
				}
			}

		if ($params{'query'}->{'query_string'}->{'query'} =~ /^(.*?)[-]+$/) {
			## query's may not end in -- and a stupid security scanner likes to test for that.
			push @TRACELOG, "ERROR: Query $params{'query'} is invalid (removing trailing -'s)";
			$params{'query'} = $1;
			}

		print STDERR "DOING ELASTIC A\n";
	   my $results = undef;
		eval {
		 	$results = $es->search( 
				'index'=>"$USERNAME.public", 
				'body'=>\%params 
				);
			};
		#open F, ">>/tmp/elastic";
		#print F Dumper($USERNAME,\%params);
		#close F;

		print STDERR "DONE ELASTIC A\n";

		if ($DEBUG) {	
			require JSON::XS;
	      my $coder = JSON::XS->new->ascii->pretty->allow_nonref;

			push @TRACELOG, "ElasticRequest (JSON): <pre>".&ZOOVY::incode($coder->encode(\%params))."</pre>";
			push @TRACELOG, "ElasticResponse (JSON): <pre>".&ZOOVY::incode($coder->encode($results))."</pre>";
			}

		my %PIDS = ();
		if (not defined $results) {
			push @TRACELOG, "Query: ".&ZTOOLKIT::buildparams(\%params);
			push @TRACELOG, "ElasticSearch Error: $@";
			}
		elsif ($results->{'hits'}->{'total'}>0) {
			foreach my $hit (@{$results->{'hits'}->{'hits'}}) {
				if ($hit->{'_type'} eq 'product') {
					$PIDS{$hit->{'_id'}} = $hit->{'_score'}*1000;
					}
				}
			}
		$pidsfound = \%PIDS;
		# print STDERR Dumper(\%params,$pidsfound);	
		}



#		else {
#			push @TRACELOG, "Using NON-STRUCTURED syntax";
#			($pidsfound,$prodsref) = &search_unstructured($USERNAME,$cdb,$keywords,$CATREF,\@TRACELOG);
#			if ((not defined $pidsfound) || (scalar(keys %{$pidsfound})==0)) {
#				push @TRACELOG, "Unfortunately -- no results were returned from search_unstructured";
#				}
#			# print Dumper($pidsfound);
#			} 
#		$cdb = undef;
#		untie %CAT;

		# We'll replace this with something that secondarily sorts on the number of matches found.

	## now make sure these items are safe to show.

#	use Data::Dumper;
#	print Dumper($pidsfound);

	my ($iso) = $options{'ISOLATION_LEVEL'};

	if (($SPEED&1)==0) {
		my $okaytoshowref = undef;

		my ($NC) = $options{'*NC'};
		if (not defined $NC) { $NC = NAVCAT->new($USERNAME,PRT=>$options{'PRT'},cache=>1); }
		my ($ROOT) = '.';
		if (defined $options{'ROOT'}) { 
			$ROOT = $options{'ROOT'}; 
			}
		elsif (defined $SITE) {
			$ROOT = $SITE->rootcat();
			}

		if (not defined $iso) { 
			push @TRACELOG, "DEFAULTING ISOLATION LEVEL TO 10";
			$iso = 10; 
			}

		if ($iso==0) {
			push @TRACELOG, "ISOLATION_LEVEL=0 (None) - so okaytoshow is the same as pidsfound.";
			$okaytoshowref = $pidsfound;
			}
		else {
			push @TRACELOG, "ISOLATION_LEVEL=$iso";
			$okaytoshowref = $NC->okay_to_show($USERNAME,undef,$ROOT,$iso);
			# push @TRACELOG, "PIDSFOUND: ".Dumper($pidsfound);
			}

		

		if ((defined $options{'TRACEPID'}) && ($options{'TRACEPID'} ne '')) {
			push @TRACELOG, "======== TRACING PRODUCT: $options{'TRACEPID'} ==========<br>\n(this is done regardless if matches are found)<br>\n==============================================";

			require JSON::Syck;
			my $getresults = eval { $es->get( 
				'index'=>"$USERNAME.public", 
				'type'=>'product',
				'id'=>$options{'TRACEPID'}
				) };
			if (not defined $getresults) {
				push @TRACELOG, "***ERROR**** ElasticResponse(GET/JSON) either DOWN or PRODUCTID is invalid: ".JSON::Syck::Dump($getresults);
				}
			else {
				push @TRACELOG, "ElasticResponse(GET/JSON): ".JSON::Syck::Dump($getresults);
				}
			

			# my ($ref) = &ZOOVY::fetchproduct_as_hashref($USERNAME,$options{'TRACEPID'});
			# push @TRACELOG, Dumper($ref);
			#require Date::Parse;
			#my ($catts) = Date::Parse::str2time($CATREF->{'CREATED'}); 
			#push @TRACELOG, "Catalog Time: ".&ZTOOLKIT::pretty_date($catts,1)." Product Created: ".&ZTOOLKIT::pretty_date($ref->{'zoovy:prod_created_gmt'},1);
			#if ($ref->{'zoovy:prod_created_gmt'}>$catts) {
			#	push @TRACELOG, "**WARNING**: Catalog has not been re-indexed SINCE this product was created. (I am nearly certain you won't be able to find this product!)\n";
			#	}
			#elsif ($ref->{'zoovy:prod_modified_gmt'}>$catts) {
			#	push @TRACELOG, "**WARNING**: It appears this product has been modified/saved since the last re-index of this catalog. You should reindex this catalog before spending any serious time troubleshooting.\n";
			#	}


			if (not defined $okaytoshowref->{$options{'TRACEPID'}}) {
				push @TRACELOG, "Product $options{'TRACEPID'} was not in a okay_to_show, this won't appear publically. Lets find out why:";
				}
			else {
				push @TRACELOG, "Product $options{'TRACEPID'} said okay_to_show. Lets find out why:";
				}

			my $paths = $NC->paths_by_product($options{'TRACEPID'});
			if (scalar(@{$paths})==0) {
				push @TRACELOG, "Product $options{'TRACEPID'} found not be located in any categories.";
				}
			else {
				my $pos = length($ROOT);
				if ($pos==1) { $pos = 0; }	# this makes the real root at like a sub root (see logic below)
				push @TRACELOG, "ROOT IS: $ROOT (offset=$pos)";
				foreach my $safe (@{$paths}) {
					my ($pretty,$children,$products,$sort,$metaref) = $NC->get($safe);
					if (substr($safe,0,1) eq '$') {
						push @TRACELOG, "Found $options{'TRACEPID'} in $safe ($pretty), but it's a LIST and therefore doesn't count.";
						}
					elsif (substr($pretty,0,1) eq '!') { 
						push @TRACELOG, "Found $options{'TRACEPID'} in $safe ($pretty), but it's a HIDDEN CATEGORY and therefore doesn't count.";
						}
					else {
						push @TRACELOG, "Found $options{'TRACEPID'} in $safe ($pretty), which is a visible category.";
						my @ar = split(/\./,substr($safe,$pos));		# so if we're in root .a then we'll get split .b.c 
						# push @TRACELOG, "DEBUG: ".join("|",@ar);
						my $myroot = (($pos)?$ROOT.'.':'.').$ar[1];
						my ($pretty,$children,$products,$sort,$metaref) = $NC->get($myroot);
						if (substr($pretty,0,1) eq '!') {
							push @TRACELOG, ".... Root $myroot of $safe is hidden, so we can't use it.";
							}
						else {
							push @TRACELOG, ".... Root $myroot of $safe is visible.";
							}

						pop @ar;
						my $myparent = (($pos)?$ROOT.'.':'.').join('.',@ar);		# clearly we're in b.c.d.e and we've already checked b, what about d?
						$myparent = substr($myparent,1);		## implicitly strip leading dot. (??)
						($pretty,$children,$products,$sort,$metaref) = $NC->get($myparent);
						if (substr($pretty,0,1) eq '!') {
							push @TRACELOG, ".... Regrettably the parent $myparent of $safe is hidden ($pretty) so we can't use it.";
							}
						else {
							push @TRACELOG, ".... Parent $myparent of $safe is not hidden ($pretty)";
							}
						}
					}
				}
			}
		undef $NC;

		foreach my $pid (keys %{$pidsfound}) {
			if (not defined $okaytoshowref->{$pid}) {
				delete $pidsfound->{$pid};
				if ($DEBUG) {
					push @TRACELOG, "Unfortunately product $pid was removed from result set because it was not within visible category=$ROOT prt=$options{'PRT'}";
					}
				}				
			else {
				if ($DEBUG) {
					push @TRACELOG, "Looks like product $pid would have been displayed (assuming everything else is on the up and up).\n";
					}
				}
			}

		push @TRACELOG, "Found: ".scalar(keys %{$pidsfound})." products which are visible + eligible matches.\n";
		}

	## sort items into a decent order.
	## 7/17/12 - changed search to use a relevancy return order (reversed value_sort)
	my @out = reverse &ZTOOLKIT::value_sort($pidsfound,'numerically'); 

	if (not $LOG) {
		}
	elsif (($SPEED&2)==0) {
		my $count = scalar(@out);
		my $path = &ZOOVY::resolve_userpath($USERNAME);

		my @t = localtime();
		my $YEARMON = &ZTOOLKIT::zeropad(4,($t[5] + 1900)) . &ZTOOLKIT::zeropad(2,($t[4] + 1));

#		open F, ">>$path/IMAGES/SEARCH-$catalog-$YEARMON.csv";
#		my $now = &ZTOOLKIT::pretty_date(time(),2);
#		my ($session,$domain,$prt) = ('?','?','?');
#		if ((defined $SITE::CART2) && (ref($SITE::CART2) eq 'CART2') && ($SITE::CART2->username() eq $USERNAME)) {
#			$session = ((ref($SITE::CART2) eq 'CART2')?$SITE::CART2->cartid():'');
#			$prt = $SITE::CART2->prt();
#			$domain = $SITE::CART2->in_get('our/sdomain');
#			}
#
#		print F "$now\t$mode\t$keywords\t$count\t$ENV{'REMOTE_ADDR'}\t$session\t$domain\t$prt\n";
#		close F;
		}

	$prodsref = undef;
	#if ($DEBUG) {
	#	print STDERR Dumper(\@out,$prodsref,\@TRACELOG);
	#	}

	return (\@out,$prodsref,\@TRACELOG);
	}












##
##	%options
## .. @TRACELOG
##	.. TRACEPID
##
sub substring_search {
	my ($USERNAME,$keywords,%options) = @_;

	my $DEBUG = 0;
	my %matchesfound = ();

	my @keys = split(/\s+/, $keywords);
	my %pidsfound = ();
	foreach my $key (@keys) {
		foreach my $prod (&ZOOVY::findproducts_by_keyword($USERNAME,$key)) {
			next if ($prod eq '');
			if (not defined $pidsfound{$prod}) { $pidsfound{$prod} = 0; }
			$pidsfound{$prod}++;
			}
		%matchesfound = %pidsfound; # We have no way to know how many matches here, so its equal

		if (defined $options{'TRACEPID'}) {
			if ($pidsfound{$options{'TRACEPID'}}) {
				push @{$options{'@TRACELOG'}}, "PID $options{'TRACEPID'} was found in findproducts_by_keyword";
				}
			else {
				push @{$options{'@TRACELOG'}}, "PID $options{'TRACEPID'} was found in findproducts_by_keyword"; 
				}
			}
		}

	####################### hope products can't be indexed more than once!	
	my $mode = 'AND';
	if ($mode eq 'AND') {
		foreach my $prod (keys %pidsfound) {
			# "AND" search, so we make sure to match all keywords
			# print STDERR "$pidsfound{$prod} != ".scalar(@keys)."\n";
			if ($pidsfound{$prod} < scalar(@keys)) {
				delete $pidsfound{$prod};
				}
			}
		}
	# We'll replace this with something that secondarily sorts on the number of matches found.
	#if (not $SPEED) { 
	my @out = &ZTOOLKIT::value_sort(\%pidsfound,'numerically'); 
	#	}
	#else { 
	#	@out = keys %pidsfound; 
	#	}

	####################### 
	return(\@out);
	}


sub msg {
	my $head = 'SEARCH: ';
	while ($_ = shift(@_)) {
		if (ref) { require Data::Dumper; $_ = Data::Dumper->Dump([$_],[shift(@_)]); }
#		print STDERR $head, join("\n$head",split(/\n/,$_)), "\n";
	}
}



#sub search_unstructured {
#	my ($USERNAME,$cdb,$keywords,$CATREF,$TLOG) = @_;
#
#	my ($DEBUG) = int($CATREF->{'DEBUG'});
#	my ($mode) = $CATREF->{'MODE'};
#
#	$CATREF->{'from_search'} = 1;
#	$CATREF->{'@TRACELOG'} = $TLOG;
#	my ($keyhash) = &find_keywords($keywords,$CATREF); # Why not use the same function?  :)
#	if (not $DEBUG) {
#		## do nothing!
#		}
#	elsif (scalar(keys %{$keyhash})>0) {
#		my $str = "determined keywords(count): ";
#		foreach my $k (keys %{$keyhash}) { $str .= " $k($keyhash->{$k}) "; }
#		push @{$TLOG}, $str;
#		}
#	else {
#		push @{$TLOG}, "WARNING: no keywords found.\nThe most likely cause is the words specified did not meet the criteria to be considered a 'word'";
#		}
#
#	my %matchesfound = (); # Key of product, value of number of times any key was found (single key increments by the number of times that key matched)
#	my %pidsfound = (); # Key of product, value of the number of keys that product matched (single key can only inclement by one)
#	my @keys = (); # All of the keys the user searched for
#	@keys = keys(%{$keyhash});
#
#	# $CATREF->{'USE_ALLWORDS'}++;
#
#	my @STACK = ();
#	foreach my $key (@keys) {
#		my $resultref = $cdb->multi_get($key);
#		
#		if ((not defined $resultref) || (scalar @{$resultref}==0)) {	
#			# oh shit! no results!
#			push @{$TLOG}, "WARNING: cdb->multi_get($key) found no matches.";
#			if ($CATREF->{'USE_ALLWORDS'}) {
#				push @{$TLOG}, "USE_ALLWORDS is enabled, so this search will return zero results due to term[$key]";
#				push @STACK, {};								
#				}
#			}
#		else {
#			my %thisSet = ();			# this tracks words found in this set if we are in "AND" mode
#			SEARCH::cdb_prod_matches($resultref,\%thisSet,\%pidsfound);
#			if ($DEBUG) {
#				push @{$TLOG}, "WARNING: cdb->multi_get for TERM=$key returned ".join(", ",keys %thisSet);
#				#&ZTOOLKIT::buildparams(\%thisSet,1);
#				}
#			push @STACK, \%thisSet;
#			}
#
#		}
#
#	# print Dumper(\@STACK);
#	if (scalar(@STACK)==1) {
#		## only have one stack, so AND/OR logic doesn't ally.
#		push @{$TLOG}, "WARNING: Single word search string, ignoring and/or/exact logic";
#		%pidsfound = %{$STACK[0]};
#		}
#	elsif (($mode eq 'AND') || ($mode eq 'EXACT')) {
#		## AND/EXACT logic.
#		push @{$TLOG}, "WARNING: Using MODE=$mode";
#		my $pidset = pop @STACK;
#
#		%pidsfound = ();
#		foreach my $pid (keys %{$pidset}) {
#			my $missed = 0;
#			foreach my $s (@STACK) {
#				if (not defined $s->{$pid}) { $missed++; }
#				# print "$pid SCALAR: ".scalar(keys %{$s})." [$missed]\n";
#				}
#			if (not $missed) {
#				$pidsfound{$pid}++;
#				}
#			# print "PID: $pid $missed\n";
#			}
#		}
#	else {
#		## "OR" logic
#		push @{$TLOG}, "WARNING: Using MODE=$mode";
#		foreach my $s (@STACK) {
#			foreach my $pid (keys %{$s}) {
#				$pidsfound{$pid} += $s->{$pid};
#				}
#			}
#		}
#		
#
#	my $prodsref = {};
##	if (0 && ($mode eq 'EXACT')) {
##		print STDERR "EXACT KEYWORDS: $keywords\n";
##		$keywords = lc($keywords);
##		my @ATTRIBS = split(/,/,lc($CATREF->{'ATTRIBS'}));
##		my @prods = keys %pidsfound;
##		$prodsref = &ZOOVY::fetchproducts_into_hashref($USERNAME,\@prods);
##		%pidsfound = ();
##		foreach my $prod (keys %{$prodsref}) {
##			my $found = 0;
##			if ($prod eq $keywords) { $found++; }
##			foreach my $attrib (@ATTRIBS) {
##				if (index(lc($prodsref->{$prod}->{$attrib}),$keywords)>=0) { $found++; }
##				}
##			if ($found) { $pidsfound{$prod} = $found; }
##			else { delete $prodsref->{$prod}; }						
##			}
##		}
#
#
#	# print Dumper({'TLOG'=>$TLOG});
#
#	return(\%pidsfound,$prodsref);
#	}








##
## resultRef is a return from a cdb->multi_get
##	thisSet is a reference to a hash which will contain a list of products
##	pidsfound is a reference to a hash keyed by search term
##
sub cdb_prod_matches {
	my ($resultref,$thisSet,$pidsfound,$matchesfound) = @_;

	foreach my $pairset (@{$resultref}) {
		## a pairset might have one or more products in it e.g. 5*prod1,7*prod2,1*prod3
		foreach my $prodmatch (split(/,/,$pairset)) {
			my ($match,$prod) = split(/\*/, $prodmatch, 2); # Product, number of matches of keyword for product
			next if ($prod eq ''); # Skip blanks
			next if (($match eq '') || (int($match) eq 0)); # We should never see this, but just in case

			next if (defined $thisSet->{$prod});		# hmm.. product must have been re-indexed!
			$thisSet->{$prod} = 1;

			if (not defined $pidsfound->{$prod}) { $pidsfound->{$prod} = 0; }
			$pidsfound->{$prod}++;
			if (not defined $matchesfound->{$prod}) { $matchesfound->{$prod} = 0; }
			$matchesfound->{$prod} += $match;
			}
		}

	return();
	}



##########################################
##
##
##
# perl -e 'use lib "/backend/lib"; use SEARCH; use Data::Dumper; my ($pids) = SEARCH::search_elastic("gkworld","'T00290\\:AF00'",\@TRACE); print Dumper(\@TRACE,$pids);'
sub search_elastic {
	my ($USERNAME,$keywords,$tracelogref, %options) = @_;

	my ($es) = &ZOOVY::getElasticSearch("$USERNAME");
	my $qp = $es->query_parser( %options );

	if (not defined $options{'fields'}) { $options{'fields'} = 1; }
	if (not defined $options{'size'}) { $options{'_size'} = $SEARCH::ELASTIC_RESULTS; }

	my $filtered_query_string = $qp->filter($keywords,%options);

	push @{$tracelogref}, 'FILTERED QUERY STRING: '.Dumper($filtered_query_string);

	print STDERR "DOING ELASTIC C\n";
   my $results = $es->search( 'index'=>"$USERNAME.public", 'body'=>{ query=> { query_string=>{ query => $keywords } }, size=>$options{'_size'} } );
	print STDERR "DONE ELASTIC C\n";

	# print Dumper($results->{'hits'});	
	my @PIDS = ();
	if ($results->{'hits'}->{'total'}>0) {
		foreach my $hit (@{$results->{'hits'}->{'hits'}}) {
			# print Dumper($hit);
			if ($hit->{'_type'} eq 'product') {
				push @PIDS, $hit->{'_id'};
				}
			}
		}

	return(\@PIDS);
	}


##########################################
##
##
##
sub search_structured {
	my ($USERNAME,$es,$keywords,$tracelogref,$DEBUG) = @_;

	require ElasticSearch::QueryParser;
	my %opts = ();
	my $qp = $es->query_parser(%opts);
	# my $filtered_query_string = $qp->filter(qq~+"A501" +("A301" "A300")~, %opts);
	my $filtered_query_string = $qp->filter($keywords, %opts);

	$filtered_query_string =~ s/\"//gs;
	push @{$tracelogref}, "Filtered-query-string is: $filtered_query_string\n";

	my %params = ();
	# $params{'index'} = "$USERNAME.public";
	$params{'query'} = {
						query_string=>{ fields=>['pogs'], query => $filtered_query_string }
                  };
	$params{'size'} = $SEARCH::ELASTIC_RESULTS;
	print STDERR "DOING ELASTIC D\n";
   my $results = $es->search( 'index'=>"$USERNAME.public", 'body'=>\%params );
	print STDERR "DONE ELASTIC D\n";
	
	if ($DEBUG) {
		require JSON::XS;
      my $coder = JSON::XS->new->ascii->pretty->allow_nonref;
		push @{$tracelogref}, "ElasticRequest (JSON): <pre>".&ZOOVY::incode($coder->encode(\%params))."</pre>";
		push @{$tracelogref}, "ElasticResponse (JSON): <pre>".&ZOOVY::incode($coder->encode($results))."</pre>";
		}

	my %PIDS;
	if ($results->{'hits'}->{'total'}>0) {
		foreach my $hit (@{$results->{'hits'}->{'hits'}}) {
			if ($hit->{'_type'} eq 'product') {
				$PIDS{$hit->{'_id'}} = $hit->{'_score'}*1000;
				}
			}
		}
	return(\%PIDS);

#	## OLD Search::QueryParser code
#
#	my $qp = new Search::QueryParser;
#	my $query = $qp->parse($keywords) or die "Error in query : " . $qp->err;
#
#	# my ($keyhash) = &find_keywords($keywords,$CATREF); # Why not use the same function?  :)
#	&recurseQuery($query);
#	# print Dumper($query);
#
#	push @{$tracelogref}, 'STRUCTURED QUERY DUMP: '.Dumper($query);
#
#	my ($prodsref) = do_search_structured($query,$es,$USERNAME);	
#
#	print STDERR "PRODSREF: ".Dumper($prodsref);
#
#	my %result = ();
#	foreach my $pid (@{$prodsref}) {
#		$result{$pid}++;
#		}
#
#	return(\%result);
	}


#sub recurseQuery {
#	my ($query) = @_;
#
#	foreach my $verb (keys %{$query}) {
#		foreach my $set (@{$query->{$verb}}) {
#			if ($set->{'op'} ne '()') {
#				my ($wordset) = &find_keywords($set->{'value'},{});
#				# print Dumper($wordset);
#				$set->{'zkeyword'} = join(" ",keys %{$wordset});
#				}         
#			else {
#				recurseQuery($set->{'value'});
#				}
#			#print Dumper($set);
#			}
#		}
#	}

##########################################
##
##
##
sub do_search_structured {
	my ($query,$es,$USERNAME) = @_;


	my $pexclude = undef;	## this is an array ref of PRODUCTS to be *EXCLUDED* (or undef if none)
	my $prequire = undef;	## this is an array ref of PRODUCTS which *MUST* *BE* *INCLUDED* (or undef if none)
	my $presult = undef;		## this is the array which contains the products 
									## note: the prequire will be applied against this set as a logical "and" at the end.

	foreach my $verb (keys %{$query}) {
		## verbs are returned by the query parser, currently we understand: '+' '-' and ''[or] and ':'[word]

		foreach my $set (@{$query->{$verb}}) {
			## A set is a keyword, or a subquery. these chunks of data are created by the queryparser.
			## {'value' => 'doh', 'op' => ':', 'field' => '' }

			# print Dumper($set);
			my $pidsref = undef;				## this the current "set" of products we're working with.
													## this will be and'ed or or'ed or nor'ed against another set within the same verb.
			if ($set->{'op'} eq '()') {
				## we've got a subquery, so we run that .. and return it as if we'd just magically found a keyword
				##	that returned the exact same result as the subquery did.
				$pidsref = do_search_structured($set->{'value'},$es,$USERNAME);
				# print Dumper({"GOT FROM NEST"=>$pidsref});				
				}
			else {
				## we're just going to search for a keyword and return a set of products.
				my $word = $set->{'zkeyword'};
	#			my $word = $set->{'value'};
	# 			print "WORD: $word\n";
	#			my $resultref = $cdb->multi_get($word);
	#			if (not defined $resultref) {}
	#			elsif (@{$resultref}==0) {}
	#			else {
	#				### 
	#				my %thisSet = ();
	#				&SEARCH::cdb_prod_matches($resultref,\%thisSet);
	#				$pidsref = [ keys %thisSet ];
	#				}
		$word = sprintf("%s",uc($word));
		print STDERR "ELASTIC WORD: $word\n";
		print STDERR "DOING ELASTIC E\n";
	   my $results = $es->search( 
			'index'=>"$USERNAME.public", 
			'body'=>{
				filter=> { "terms" => { "pogs"=>[ $word ] } }, 
				size=>$SEARCH::ELASTIC_RESULTS 
				}
				);		## this was MUCH BIGGER
				my @PIDS = ();
				if ($results->{'hits'}->{'total'}>0) {
					foreach my $hit (@{$results->{'hits'}->{'hits'}}) {
						if ($hit->{'_type'} eq 'product') {
							push @PIDS, $hit->{'_id'};
							}
						}
					}
				$pidsref = [ @PIDS ];

				#print STDERR "GOT FROM WORD [$word]: ".Dumper(
				#	# {'index'=>"$USERNAME.public",filter=> { "terms" => { "pogs"=>["A301"] } }, size=>1000},
				#	# $USERNAME,
				#	# $pidsref
				#	)."\n";
				}

			if (not defined $pidsref) { $pidsref = []; }

			if ($verb eq '+') {
				## MUSTHAVE/MUST-INCLUDE
				
				if (not defined $prequire) {
					## we don't know what we prequire yet, so we initialize prequire to the first set of products.
					$prequire = $pidsref;
					}
				else {
					## we have a set of prequires, so we'll run a redux and keep the set which matches both.
					my @reducedset = ();
					foreach my $outer (@{$pidsref}) {
						foreach my $inner (@{$prequire}) {
							if ($inner eq $outer) { push @reducedset, $inner; }
							}
						}
					# print Dumper( {'PREQUIRE REDUCED SET: '=>\@reducedset, 'pidsref'=>$pidsref, 'prequire'=>$prequire });
					$prequire = \@reducedset;
					}

				}
			elsif ($verb eq '-') {
				## EXCLUDE
				if (not defined $pexclude) {
					## we don't know what we pexclude yet, so we initialize pexclude to the first set of products.
					$pexclude = $pidsref;
					}
				else {
					## we have a set of pexcludes, so we'll run a redux and keep the set which matches both.
					$pexclude = [ @{$pexclude},@{$pidsref} ];
					}
				}
			elsif ($verb eq '') {
				## OR
				if (not defined $presult) {
					$presult = $pidsref;
					}
				else {
					$presult = [ @{$presult},@{$pidsref} ];
					}
				}

			}

		print STDERR "DONE ELASTIC E\n";
		## at the end of this loop a specific "verb" has been run, meaning either
		##	presult, prequire, or pexclude is fully built (based on the verb)

#		print Dumper($verb,$set,$xref->{$word});
		}
	
	##
	## at this point: presult, prequire and pexclude are all built into flat sets of matching products.
	##		now we'll just go through and toss out anything explicitly excluded, and make sure if we have 
	##		a list of implicit includes then we keep those, otherwise we can just use presult.
	##

	# print Dumper({prequire=>$prequire});

	my %whitelist = ();	## whitelist to return
	my %blacklist = ();
	if (defined $prequire) {
		foreach my $pid (@{$prequire}) { $whitelist{$pid}++; }
		}
	if (defined $pexclude) {
		foreach my $pid (@{$pexclude}) { $blacklist{$pid}++; }
		}

	#print Dumper({presult=>$presult,prequire=>$prequire,pexclude=>$pexclude})."\n\n";
	if ((not defined $presult) && (defined $prequire)) {
		## there were no "OR" requests .. so we'll just use the "AND", so anything in our whitelist,
		##		is actually our result list. e.g. "foo AND faa" returns the subset of both foo and faa, even though
		##		presult was never set because there was no "or" verb.
		$presult = $prequire;
		$prequire = undef;
		}

	my %could = ();
	if (defined $presult) {
		foreach my $pid (@{$presult}) { 
			next if ((defined $pexclude) && ($blacklist{$pid}));
			next if ((defined $prequire) && (not defined $whitelist{$pid}));
			$could{$pid}++; 
			}
		}

	my @result = keys %could;
	# print Dumper({RESULT=>\%could,GOOD=>\%whitelist,BAD=>\%blacklist,RESULT=>\@result});


	return(\@result);
	}



1;

