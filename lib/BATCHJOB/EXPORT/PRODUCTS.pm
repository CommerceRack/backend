package BATCHJOB::EXPORT::PRODUCTS;

use strict;


##
##
##
sub generate {
	my ($bj) = @_;

	my ($USERNAME) = $bj->username();

	my $udbh =&DBINFO::db_user_connect($USERNAME);
	my ($SITE) = SITE->new($USERNAME,'PRT'=>$bj->prt());	# for buyme button

	my @records = ();

	my $reccount = 0;
	my $rectotal = 0;

	## addtocart=0&attribute_source=all&categories=0&convertutfx=0&createend=&createstart=&csv=&EXPORT=PRODUCT&fields=&imagelib=0&JOBID=0&NAVCAT%2b%24anothertest=0&NAVCAT%2b%24cool=0&NAVCAT%2b%24models=1&NAVCAT%2b%24rsslist2=0&NAVCAT%2b%24rsslist3=0&navcats=0&NAVCAT%2b%24thisisatest=0&pogs=&product_selectors=NAVCAT%3d%24models%0a&produrls=0&rend=&rstart=&SELECTALL=0&stripcrlf=0&variations=0

	my $PRT = $bj->prt();
	my $vars = $bj->vars();

	##
	## product_selectors
	my $ERROR = undef;

	my @HEAD = ();

	my @PRODUCTS = ();
	if (not defined $vars->{'product_selectors'}) {
		$ERROR = 'product_selectors not specified';
		}
	elsif (ref($vars->{'product_selectors'}) eq '') {
		require PRODUCT::BATCH;
		@PRODUCTS = &PRODUCT::BATCH::resolveProductSelector($USERNAME,$PRT,[ split(/[\n]+/,$vars->{'product_selectors'}) ]);
		}

#	print Dumper(\@PRODUCTS);
#	print Dumper($vars);


	# Fix up some keys
	my %FOUNDKEYS = ();			# contains a hash of keys we know we have.
	
	my @keyorder = ();

	$reccount = 0;
	$rectotal = scalar(@PRODUCTS);
	my $batchesref = &ZTOOLKIT::batchify(\@PRODUCTS,100);

	my $NC = undef;
	my $catref = {};
	my $DYNAMIC = 0;
	## DYNAMIC LEVEL1 = only on % special keys
	## DYNAMIC LEVEL2 = all product attribs

	if ($vars->{'headers'} eq '') {
		push @HEAD, { 'z'=>'%PRODUCTID', 'header'=>'%PRODUCTID' };
		$DYNAMIC |= 2;		
		}
	elsif (substr($vars->{'headers'},0,1) eq '@') {
		## cheap hack to detect advanced imports
		}
	else {
		## cheap hack to detect standard imports
		push @HEAD, { 'z'=>'%PRODUCTID', 'header'=>'%PRODUCTID' };
		}

	foreach my $line (split(/[\n\r]+/,$vars->{'headers'})) {
		if (substr($line,0,1) eq '@') {
			## advanced line - see syntax around line 9 in this file.
			## note: this allows commas on the line
			$line = substr($line,1);	# remove leading @
			my ($header,$attrib) = split(/\|/,$line,2);
			push @HEAD, { z=>"$attrib", header=>"$header" };
			}
		else {
			## standard line - header is by itself, or a simple transformation
			## we may need to split again by comma
			foreach my $attrib (split(/,/,$line)) {
				next if ($attrib eq '');
				$attrib =~ s/[\s]+//g;
				push @HEAD, { z=>"$attrib", header=>"$attrib" };
				}
			}
		}

	if ($vars->{'imagelib'}) { 
		## says transform all images into their url's
		foreach my $head (@HEAD) {
			if ($head->{'z'} =~ /zoovy:prod_thumb/) {
				$head->{'z'} = "%IMGURL=zoovy:prod_thumb";
				}
			elsif ($head->{'z'} =~ /zoovy:prod_image[\d]+/) {
				$head->{'z'} = sprintf("\%IMGURL=%s",$head->{'z'});
				}
			}
		}


	my %HAS_SPECIAL_HEADER = ();
	my @BODY = ();

	if ($vars->{'produrls'}) {
		## export product URLS
		push @HEAD, { z=>"%PRODUCTURL", header=>"%PRODUCTURL" };
		}
	if ($vars->{'addtocart'}) {
		## create add to cart code
		push @HEAD, { z=>"%ADDTOCART", header=>"%ADDTOCART" };
		}
	if ($vars->{'imagelib'}) {
		$DYNAMIC |= 1;
		push @HEAD, { z=>"%IMGURL=zoovy:prod_image1", header=>"%IMGURL=zoovy:prod_image1" };
		}

	if ($vars->{'categories'}) {
		require CATEGORY;
		my ($tmp) = &CATEGORY::fetchcategories($USERNAME);
		foreach my $cat (keys %{$tmp}) {
			foreach my $pid (split(/,/,$tmp->{$cat})) {
				next if ($pid eq '');
				$catref->{$pid} = $cat;
				}
			}
		# print Dumper($catref);
		push @HEAD, { z=>"%CATEGORY", header=>"%CATEGORY" };
		}

	if ($vars->{'navcats'}) {
		$DYNAMIC |= 1;
		$NC = NAVCAT->new($USERNAME,PRT=>$bj->prt() );
		push @HEAD, { z=>"%CATEGORY1%", header=>"%CATEGORY1%" };
		}

	if ($vars->{'pogs'} eq 'JSON') {
		push @HEAD, { z=>"%POGS=JSON", header=>"%POGS=JSON" };
		}
	elsif ($vars->{'pogs'} eq 'XML') {
		push @HEAD, { z=>"%POGS=XML", header=>"%POGS=XML" };
		}

	foreach my $head (@HEAD) {
		$HAS_SPECIAL_HEADER{ $head->{'z'} }++;
		}

	foreach my $batchref (@{$batchesref}) {
		my @PROCESS = ();
		my $prodsref = PRODUCT::group_into_hashref($USERNAME,$batchref);
		foreach my $P (values %{$prodsref}) {

			if ((not defined $vars->{'variations'}) || ($vars->{'variations'}==0)) {
				## NO VARIATIONS EXPANSION
				push @PROCESS, [ $P->pid(), $P ];			
				}
			elsif (not $P->has_variations('inv')) {
				push @PROCESS, [ $P->pid(), $P ];
				}
			elsif ($vars->{'variations'} == 1) {
				## variations with products
				push @PROCESS, [ $P->pid(), $P ];
				foreach my $skuset (@{$P->list_skus('verify'=>1)}) {
					push @PROCESS, [ $skuset->[0], $P ];
					}	
				}
			elsif ($vars->{'variations'} == 2) {
				foreach my $skuset (@{$P->list_skus('verify'=>1)}) {
					push @PROCESS, [ $skuset->[0], $P ];
					}	
				}

			}
		
		my $out = '';
		foreach my $set (@PROCESS) {
			my @ROW = ();
			
			my ($SKU,$P) = @{$set};
			print "SKU:$SKU\n";

			my %meta = ();
			$meta{'%SKU'} = $SKU;
			$meta{'%PRODUCTID'} = $P->pid();
			$meta{'%SAFESKU'} = &ZOOVY::to_safesku($SKU);

			if ($vars->{'produrls'}) {
				$meta{'%PRODUCTURL'} = $P->public_url();
				}
			if ($vars->{'addtocart'}) {
				$meta{'%ADDTOCART'} = $P->button_buyme($SITE);
				}
			if (defined $vars->{'categories'}) {
				$meta{'%CATEGORY'} = $catref->{$SKU};
				}
			if ((defined $vars->{'navcats'}) && (defined $NC)) {
				my $count = 1;	
				foreach my $path (@{$NC->paths_by_product($SKU,lists=>0)}) {
					$meta{'%CATEGORY'.($count++).'%'} = $path;
					}
				}
			foreach my $id ('%PRODUCTID',reverse sort keys %meta) {
				if (not defined $HAS_SPECIAL_HEADER{$id}) {
					push @HEAD, { z=>"$id", header=>"$id", id=>scalar(@HEAD) };
					$HAS_SPECIAL_HEADER{$id}++;
					}
				}			

			## 
			my %DYNAMIC_SKIP = ();
			foreach my $attrib (@HEAD) {
				## WEBDOC: 50365
				if (substr($attrib->{'z'},0,1) ne '%') {
					## non-macro defined in product (ex: zoovy:prod_name)
					push @ROW, sprintf("%s", $P->skufetch($SKU, $attrib->{'z'} ));
					}
				elsif ((substr($attrib->{'z'},0,1) eq '%') && ($meta{$attrib->{'z'}})) {
					## macro defined in meta (ex: %SKU)
					push @ROW, sprintf("%s", $meta{$attrib->{'z'}});
					}
				elsif ($attrib->{'z'} eq '') {
					## they want a blank line! wtf. okay.
					push @ROW, "";
					}
				elsif (defined $P->skufetch($SKU, $attrib->{'z'} )) {
					## the attribute exists implicitly. (how is this ever true? - not updating %SKUREF)
					push @ROW, $bj->skufetch( $SKU, $attrib->{'z'} );
					}
				elsif ($attrib->{'z'} =~ /^\%TEXT\=(.*?)$/) {
					## constant text
					push @ROW, $1;
					}
				elsif ($attrib->{'z'} =~ /^\%WIKISTRIP\=(.*?)$/) {
					## wiki stripping.
					push @ROW, &ZTOOLKIT::wikistrip($P->skufetch($SKU,$1));
					}
				elsif ($attrib->{'z'} =~ /^\%TF\=(.*?)\|(.*?)\|(.*?)$/) {
					## true false undefined
					## %TFU=true|false|undef
					
					}
				elsif ($attrib->{'z'} =~ /^\%TRY\=(.*?)$/) {
					## %TRY=x1:y1:,x2:y2 (best match)
					my $found = 0;
					foreach my $attrib (split(/,/,$1)) {
						next if ($found);
						if (defined $P->skufetch($SKU, $attrib)) {
							push @ROW, $P->skufetch($SKU, $attrib); $found++;
							}
						}
					if (not $found) { push @ROW, ""; }
					}
				elsif ($attrib->{'z'} =~ /^\%POGS\=(JSON|XML)$/) {
					my $format = $1;
					if (not $P->has_variations('any')) {
						push @ROW, "";
						}
					elsif ($format eq 'JSON') {
						push @ROW, POGS::to_json($P->pogs());
						}
					elsif ($format eq 'XML') {
						push @ROW, POGS::serialize($P->pogs());
						}
					}
				elsif ($attrib->{'z'} =~ /^\%IMGURL\=(.*?)$/) {
					## %IMGURL
					my $attrib = $1;
					if ($P->fetch($attrib)) {
						push @ROW, &ZOOVY::mediahost_imageurl($USERNAME,$P->skufetch($SKU,$attrib),undef,undef,undef,0,'jpg');							
						}
					else {
						push @ROW, "";
						}
					}
				else {
					push @ROW, "";
					}
				#elsif ($attrib->{'header'} =~ /^\%IMGURL\=(.*?)$/) {
				#	}
				# delete $prodref->{ $attrib->{'header'} };	## WHY WAS THIS LINE HERE?!
				$DYNAMIC_SKIP{ $attrib->{'header'} }++;
				}

			if ($DYNAMIC) {
				my $prodref = $P->prodref();
				foreach my $attrib (sort keys %{$prodref}) {
					next if ($DYNAMIC_SKIP{ $attrib });
					next if (substr($attrib,0,1) eq '_');
					next if (substr($attrib,0,1) eq '@');
					next if (substr($attrib,0,1) eq '%');
					## add new header
					my $ADD_TO_HEADER = 0;
					if ($DYNAMIC&2) { $ADD_TO_HEADER++; }
					elsif (($DYNAMIC) && (substr($attrib,0,1) eq '%')) { $ADD_TO_HEADER++; }

					next unless ($ADD_TO_HEADER);
					warn "Adding $attrib to header from $SKU";
					push @HEAD, { z=>"$attrib", header=>"$attrib", id=>scalar(@HEAD) };
					push @ROW, sprintf("%s", $prodref->{ $attrib });
					delete $prodref->{$attrib};
					}
				}

			#if (defined $vars->{'inventory'}) {
			#	($meta{'%INV_INSTOCK'}) = &INVENTORY::fetch_incremental($USERNAME,$prod);
			#	}

			if ($vars->{'stripcrlf'}) {
				## remove carriage return and line feed data.
				for (my $i = scalar(@ROW);$i>=0;--$i) {
					$ROW[$i] =~ s/[\n\r]/ /gso;
					}
				}

			if ($vars->{'convertutfx'}) {
				for (my $i = scalar(@ROW);$i>=0;--$i) {
					$ROW[$i] = &ZTOOLKIT::stripUnicode($ROW[$i]);
					}
				}

			$reccount++;
			push @BODY, \@ROW;
			}

		$bj->progress($reccount,$rectotal,"Loading Products (keys: ".(scalar(@HEAD)-1).") ");
		}

	$bj->progress($rectotal,$rectotal,"did $reccount/$rectotal records");

	##
	## the report module needs the word "name" instead of "header" (which makes more sense in the context above)
	##

	
	my $csv = Text::CSV_XS->new({ binary=>1 });
	$csv->eol("\r\n");
	my $TMPFILEPATH = sprintf("%s/job%d-%s-CSV+%s.csv",&ZOOVY::tmpfs(),$bj->id(),$bj->username(),$bj->guid());
	print "TMPFILE: $TMPFILEPATH\n";

	my @FILEHEAD = ();
	foreach my $headref (@HEAD) {	push @FILEHEAD, $headref->{'z'}; }

	my $fh = new IO::File(">$TMPFILEPATH");
	if (defined $fh) {
		$csv->print($fh, [ map { utf8::upgrade (my $x = $_); $x } @FILEHEAD ]);
		## report header # must match row #
		my $count = scalar(@HEAD)-1;
		foreach my $row (@BODY) {
			# print Dumper($row);
			if ($DYNAMIC) {
				if (not defined $row->[$count]) { $row->[$count] = ''; }
				}
			$csv->print($fh, [ map { utf8::upgrade (my $x = $_); $x } @{$row} ]);
			}
		$fh->close;
		}

	return($TMPFILEPATH);
	}

1;