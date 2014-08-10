package BATCHJOB::IMPORT::PRODUCT;

use strict;
use lib "/backend/lib";
require CUSTOMER;
require PRODUCT;
require POGS;
require NAVCAT;
require PRODUCT::FLEXEDIT;
require PRODUCT::BATCH;
require PRODUCT;
require INVENTORY2;

sub parseproduct {
	my ($bj,$fieldsref,$lineref,$optionsref,$errs) = @_;


	if (not defined $errs) { $errs = []; }

	my $FATAL_ERROR = undef;
	my ($USERNAME,$LUSERNAME,$PRT) = ($bj->username(),$bj->lusername(),$bj->prt());
	if (defined $optionsref->{'PRT'}) {
		if (lc($LUSERNAME) eq 'admin') { 
			$bj->slog("Changing PRT to $optionsref->{'PRT'} for ADMIN user");
			$PRT = $optionsref->{'PRT'};
			}
		elsif ($LUSERNAME eq 'SUPPORT') { 
			$bj->slog("Changing PRT to $optionsref->{'PRT'} for ZOOVY SUPPORT");
			$PRT = $optionsref->{'PRT'};
			}
		else {
			$FATAL_ERROR = "Cannot change to PRT=$optionsref->{'PRT'} (requires support or admin user) - aborting";
			}
		}



	#if ((defined $optionsref->{'PRT'}) && ($LU->is_admin())) {
	#	$PRT = int($optionsref->{'PRT'});
	#	$bj->slog("<font color='red'>PARTITION OVERRIDE: $optionsref->{'PRT'}</font>");
	#	}

	my $MID = ZOOVY::resolve_mid($USERNAME);
	# my $NC = undef;
	my @NCS = ();
	my $linecount = 0;
	my @SORT_CATS = ();		# list of categories we need to resort.
	my $DELETED = 0;
	my %prodlist = ();
	if ($optionsref->{'REMOVEREST'}) {
		%prodlist = &ZOOVY::fetchproducts_by_name($USERNAME);
		}

	if (defined $optionsref->{'DELIMITER'}) {
		## note: we need to escape this so it doesn't get trashed by the regex
		$optionsref->{'DELIMITER'} = quotemeta($optionsref->{'DELIMITER'});
		}
	
	my %OVERRIDES = ();
	## we don't actually use OVERRIDES anymore .. but leave it in for posterity.
	##		set a field such as zoovy:virtual=123 and will be set implicitly on import.

	#my $SUPPLIER = undef;
	#if (defined $optionsref->{'SUPPLIER'}) {
	#	require SUPPLIER;	
	#	$SUPPLIER = SUPPLIER->new($USERNAME,$optionsref->{'SUPPLIER'});		
	#	}

	my %ALLOWED_COLUMNS = ();
	if ($optionsref->{'COLUMNS_ALLOWED'}) {
		## only actually import the attributes in columns only
		foreach my $k (split(/,/,$optionsref->{'COLUMNS_ALLOWED'})) {
			next if ($k eq '');
			$ALLOWED_COLUMNS{$k}++;
			}
		}

	my $i = 0;
	foreach my $header (@{$fieldsref}) {
		if ($header eq '%ATTRIBVALUE') { 
			$optionsref->{'%ATTRIBVALUE'} = $i; 
			}
		elsif (substr($header,0,1) eq '%') {
			# special headers aren't validated
			if ($header =~ /^\%POGLOOKUP=(.*?)$/) {
				my $pogid = $1;
				if (length($pogid)==2) {
					## we don't need to resolve this pog id.
					}
				else {
					my ($results) = &POGS::list_sogs($USERNAME,name=>$pogid);
					if (scalar(keys %{$results})==1) {
						($pogid) = keys %{$results};
						}
					else {
						$FATAL_ERROR = "COULD NOT LOOKUP HEADER[$i]: $header\n";
						}
					}
				$fieldsref->[$i] = "%POGLOOKUP=$pogid";
				}
			}	
		elsif (substr($header,0,1) eq '!') {}	# IGNORED HEADERS
		elsif ($header =~ /^[\s]*\<(sku|base)\>/) { $fieldsref->[$i] = $header; } # FORCED HEADERS <base>zoovy:tag_doesnt_exist
		elsif (($header eq '') && ($optionsref->{'IGNORE_BLANK_FIELDS'})) {}	# ignore blank headers
		elsif (not &PRODUCT::FLEXEDIT::is_valid($header,$USERNAME)) {
			$FATAL_ERROR = "HEADER_ATTRIBUTE IN COLUMN:[$i] VALUE:[$header] is not valid";
			print "$FATAL_ERROR\n";
			die();
			}
		$i++;
		}


	my $SCHEDULE = '';
	my $JEDI_MERCHANT = ''; 
	my $JEDI_MID = '';
#	if (defined $optionsref->{'JEDI'}) {
#		require SUPPLIER;
#		# require SUPPLIER::JEDI;
#		$SUPPLIER = SUPPLIER->new($USERNAME,$optionsref->{'JEDI'});

#		if (not defined $SUPPLIER) { 
#			$bj->slog("<font color='red'>ENCOUNTERED ERROR:</font> Supplier code: $optionsref->{'JEDI'} is not valid");
#			exit;
#			}
#		$JEDI_MERCHANT = $SUPPLIER->fetch_property('JEDI_USERNAME');
#		$JEDI_MID = $SUPPLIER->fetch_property('JEDI_MID');
#		print STDERR "[JEDI Import] Found Supplier for $optionsref->{'JEDI'}\n";
#		## JEDI_CUSTOMER is the resellers login to the Jedi Store
#		if (defined $SUPPLIER->fetch_property('JEDI_CUSTOMER')) {
#			require WHOLESALE;
#			my $schref = &WHOLESALE::load_schedule_for_login($SUPPLIER->fetch_property('JEDI_USERNAME'),$SUPPLIER->fetch_property('JEDI_CUSTOMER'));
#			$SCHEDULE = $schref->{'SID'};
#	
#			print STDERR "[JEDI Import] Found Schedule: $SCHEDULE\n";
#			}
#		}

	if (defined $FATAL_ERROR) {
		$bj->slog($FATAL_ERROR);		
		$lineref = [];
		push @{$errs}, "FAIL|+$FATAL_ERROR";
		}

	my $rows_count = scalar(@{$lineref});
	my $rows_done = 0;

	my $WIKI_PARSER = undef;
	my %UPDATES = ();
	my @SPECIAL_USER_CUSTOM_FIELDS = @{&PRODUCT::FLEXEDIT::userfields($USERNAME,undef)};

	foreach my $line (@{$lineref}) {
		my $INVENTORY = undef;
		my $LOCATION = undef;
		my $MIN_QTY = undef;
		my $PRODUCTID = undef;
		my $OPTIONSTR = undef;
		my $SKU = undef;
		my @MACROS = ();

		my @CATEGORIES = ();
		my $HOMEPAGE = undef;
		my %prodhash = ();
		my %orderhash = ();
		my $ORDERID = undef;
		my $MANAGEMENT_CAT = undef;
		my $DELETE = undef;
		my $SKIP = undef;
		$linecount++;

		if ($optionsref->{'JEDI'}) {
			$MANAGEMENT_CAT = $optionsref->{'SUPPLIER'};
			}

		my @DATA = @{$line};

		## PREFLIGHT - locate $SKU, $PRODUCTID, $OPTIONSTR
		my $pos = 0;
		foreach my $destfield (@{$fieldsref}) {	
			my $VALUE = $DATA[$pos++];

			if (($optionsref->{'IGNORE_BLANK_FIELDS'}) && ($DATA[$pos] eq '')) {
				$VALUE = undef;
				}
			if (($optionsref->{'COLUMNS_ALLOWED'}) && (not defined $ALLOWED_COLUMNS{$destfield})) {
				## COLUMNS_ALLOWED is used for JEDI imports which might have 50 columns, and we only want to keep 3 or 4.
				$VALUE = undef;
				}


			if (not defined $VALUE) {
				## ignore this.
				$DATA[$pos-1] = undef;
				}
			elsif (($destfield eq '%PRODUCTID') || ($destfield eq '%PRODUCT')) {
				$PRODUCTID = $VALUE;
				}
			elsif ($destfield eq '%SKU') {
				$SKU = $VALUE;
				}

			if (defined $SKU) {
				## these next ones don't apply since SKU was implicitly set already
				}
			elsif ($destfield eq '%UPC') {
				($SKU) = &PRODUCT::BATCH::resolve_sku($USERNAME,'UPC',$VALUE);
				}
			elsif ($destfield eq '%ASIN') {
				($SKU) = &PRODUCT::BATCH::resolve_sku($USERNAME,'ASIN',$VALUE);
				}
			elsif (($destfield eq '%MFGID') || ($destfield eq 'MFGID')) {
				($SKU) = &PRODUCT::BATCH::resolve_sku($USERNAME,'MFGID',$VALUE);
				}
			elsif (($destfield eq '%SUPPLIERID') || ($destfield eq 'SUPPLIERID')) {
				($SKU) = &PRODUCT::BATCH::resolve_sku($USERNAME,'SUPPLIERID',$VALUE);
				}

			if (substr($destfield,0,8) eq '%WIKIFY=') {
				require HTML::WikiConverter; 
				require HTML::WikiConverter::Creole;
				$WIKI_PARSER = new HTML::WikiConverter(
					dialect => 'Creole',
					# dialect => 'WikkaWiki',
					# dialect => 'MediaWiki',
					# dialect => 'TikiWiki',
					#wiki_uri => [
					#	"http://static.zoovy.com/img/$USERNAME/",
				   #   # sub { pop->query_param('title') } # requires URI::QueryParam
  	  				#	]
					);
				}
			}

		if ((not defined $SKU) && (defined $PRODUCTID)) { $SKU = $PRODUCTID; }
		if ((not defined $PRODUCTID) && (defined $SKU)) {
			($PRODUCTID,my $claim,$OPTIONSTR) = &PRODUCT::stid_to_pid($SKU);
			if ($OPTIONSTR eq '') { $OPTIONSTR = undef; }
			}	

		## SANITY: at this point $PRODUCTID and $SKU are both set, or we aren't going to importing.
	
		if (scalar(@DATA)==0) {
			$bj->slog("<font color='red'>ERROR WITH LINE (could not be imported):<br></font>$line");
			}
#		$bj->slog("<pre>".Dumper(\@DATA)."</pre>");
		# always skip line zero

		$pos = 0; # $pos keeps track of which field in the @DATA array we are on.
		foreach my $destfield (@{$fieldsref}) {	
			my $VALUE = $DATA[$pos++];

			if (not defined $VALUE) {
				}
			elsif ($destfield =~ /^[\s]*<(sku|base)\>[\s]*(.*?)[\s]*$/o) {
				## <sku>owner:attrib
				##	<base>owner:attrib
				if (defined $optionsref->{'CRLF'}) {
					## replace the character in CRLF (ex: ||) with cr/lf
					$VALUE =~ s/$optionsref->{'CRLF'}/\r\n/gs;
					}
				push @{$UPDATES{$PRODUCTID}}, [ $SKU, "$destfield", $VALUE ];
				}
			elsif (substr($destfield,0,1) eq '%') {
				## strip leading and trailing spaces in data.
				$VALUE =~ s/^[\s]+//gs;
				$VALUE =~ s/[\s]+$//gs;

				# %INVENTORY will load into inventory
				# %LOCATION will set the inventory location
				# %MIN_QTY will set the minimum stock level, ie REORDER_QTY (used in STOCK Supply Chain)
				# %HOMEPAGE will place on homepage
				# %IMGURL=attrib will copy an image url into imagelibrary and associate it with the defined attribute
				# %PRODUCTID will create/update a product id.
				# %DELETE will remove the column if a Y is in the value.

				# check for categoryies, 
				# %CATEGORY will create a category (if necessary) and place the product on it
				if ($destfield eq '%CATEGORY') { $destfield = '%FOLDER'; }

				if ($destfield eq '%PRODUCTID') {
					}
				elsif ($destfield eq '%TEMPLATE') {
					push @{$UPDATES{$PRODUCTID}}, [ $SKU, 'USE-TEMPLATE', $VALUE ];
					}
				elsif ($destfield eq '%INVENTORY') {
					push @{$UPDATES{$PRODUCTID}}, [ $SKU, 'SET-INVENTORY', $VALUE ];
					}
				elsif ($destfield eq '%LOCATION') { 
					push @{$UPDATES{$PRODUCTID}}, [ $SKU, 'SET-LOCATION', $VALUE ];
					}
				elsif ($destfield eq '%MIN_QTY') { 
					push @{$UPDATES{$PRODUCTID}}, [ $SKU, 'SET-MIN_QTY', $VALUE ];
					}
#				elsif ($dstfield eq '%EVENT') {
#					push @{$UPDATES{$PRODUCTID}}, [ $SKU, 'EVENT', $VALUE, { } ];
#					}
				elsif ($destfield eq '%HOMEPAGE') { 
					push @{$UPDATES{$PRODUCTID}}, [ $SKU, 'WARN', "%HOMEPAGE is no longer supported" ];
					}
				elsif ($destfield eq '%DELETE') { 
					if (uc($VALUE) eq 'Y') { $VALUE = 1+2+4+8+16+32+64+128; }
					## NOTE this is NOT an elsif, because the line above sets $VALUE
					if (int($VALUE) > 0) { $DELETE = $VALUE; }
					if ($DELETE > 0) {
						push @{$UPDATES{$PRODUCTID}}, [ $SKU, 'DELETE', $VALUE ];
						}
					}
				elsif ($destfield =~ /^\%POGLOOKUP=(.*?)$/) {
					## NOTE: POGLOOKUP should have already been translated earlier.
					push @{$UPDATES{$PRODUCTID}}, [ $SKU, 'SET-POG', $VALUE, { 'pogid'=>$1, 'pogvalue'=>$VALUE  } ];
					}
				elsif ($destfield =~ /^\%POGS\=(XML|JSON)$/o) {
					my ($format) = ($1);
					## FORMAT is XML|JSON
					push @{$UPDATES{$PRODUCTID}}, [ $SKU, "SET-POGS-FROM-$format", $VALUE ];
					}
				elsif (substr($destfield,0,7) eq '%FOLDER') {
					$MANAGEMENT_CAT = substr($VALUE,0,50); 		## max length of a management cat is 50 chars
					if (substr($MANAGEMENT_CAT,0,1) ne '/') {
						$MANAGEMENT_CAT =~ s/[^A-Za-z0-9]/_/g;
						$MANAGEMENT_CAT = "/$MANAGEMENT_CAT";
						#$bj->slog("<font color='red'>Improperly formatted category, must start with a / and contain only alphanumeric characters. [1]</font>");
						#$MANAGEMENT_CAT = '';
						}
					if ($MANAGEMENT_CAT =~ /[^\w\/ ]+/) {
						$bj->slog("<font color='red'>Improperly formatted category, must start with a / and contain ONLY alphanumeric characters. [2]</font>");
						$MANAGEMENT_CAT = '';
						}
					push @{$UPDATES{$PRODUCTID}}, [ $SKU, 'SET-FOLDER', $VALUE ];
					}
				elsif (substr($destfield,0,9) eq '%CATEGORY') {
					my $safepath = $VALUE;
					my $CATEGORY = $VALUE;
					if (not defined $optionsref->{'RAWCATEGORIES'}) { 
						$safepath =~ s/ /_/g; 
						$safepath =~ s/[\W]+//g;
						## adition into subcategories - tricky - will consult brian				
						#$safepath =~ s/[^\w.]+//g; ## added by BAM

						# my $safepath = &NAVCAT::whatis_safename('.'.$CATEGORY);
						$safepath =~ s/\&//g;
						$safepath = NAVCAT::safename('.'.$safepath);
						## sub cat modification ## $safepath = &NAVCAT::whatis_safename($CATEGORY);
						} 

					push @{$UPDATES{$PRODUCTID}}, [ $SKU, "ADD-CATEGORY", $VALUE, { safe=>$safepath, pretty=>$CATEGORY } ];
					}
				elsif ($destfield eq '%ATTRIB') {
					if (&PRODUCT::FLEXEDIT::is_valid($destfield,$USERNAME)) {
						push @{$UPDATES{$PRODUCTID}}, [ $SKU, $VALUE, $optionsref->{'%ATTRIBVALUE'} ];
						}
					else {
						$bj->slog("<font color='red'>Invalid %ATTRIB attribute: $VALUE</font>");
						}
					}
				elsif (substr($destfield,0,8) eq '%IMGURL=') {
					if ($VALUE eq '') {
						## skip blank/not set image.
						}
					else {
						$bj->slog("Remote image copying - $VALUE");
						my ($code,$name) = &ZCSV::remote_image_copy($USERNAME,$VALUE,$optionsref);
						if ($code == 0) { 
							$bj->slog("Storing: $destfield = $name");
							push @{$UPDATES{$PRODUCTID}}, [ $SKU, substr($destfield,8), $name ];
							}
						else {
							$bj->slog("Error[$code]: $destfield = $name");
							}
						}
					} # end of IMGURL
				elsif (substr($destfield,0,8) eq '%WIKIFY=') {
					if ($VALUE eq '') {
						## skip blank/not set image.
						}
					else {
						$bj->slog("Converting to WIKI");
						my $wiki = $WIKI_PARSER->html2wiki($VALUE);
						push @{$UPDATES{$PRODUCTID}}, [ $SKU, substr($destfield,8), $wiki ];
						}
					} # end of IMGURL
				}
			elsif (substr($destfield,0,1) eq '!') {
				## ignore columns that start with a !
				}
			#elsif (substr($destfield,0,1) eq '@') {
			#	## run a macro over the data
			#	## macros are coded in the header 
			#	##	#@format(text) { text.replace("\n"
			#	}
			else {
				$destfield =~ s/[\s]+//g;		# strip spaces out of field names. (stupid user)
				if (defined $optionsref->{'CRLF'}) {
					## replace the character in CRLF (ex: ||) with cr/lf
					$VALUE =~ s/$optionsref->{'CRLF'}/\r\n/gs;
					}
				if (my $flexref = $PRODUCT::FLEXEDIT::fields{$destfield}) {
					push @{$UPDATES{$PRODUCTID}}, [ $SKU, $destfield, $VALUE ];
					}
				elsif (&PRODUCT::FLEXEDIT::is_valid($destfield,$USERNAME)) {
					## note - PRODUCT::FLEXEDIT::is_valid handles user:xx and zoovy:schedule_xx fields.
					push @{$UPDATES{$PRODUCTID}}, [ $SKU, $destfield, $VALUE ];
					}
				else {
					$bj->slog("<font color='red'>Invalid %ATTRIB attribute: $VALUE</font>");				
					}
				}
			}
		## end of foreach $line
		}


	##
	## SANITY: at this point %UPDATES is fully populated, if you wanted to make more, you should have done it earlier.
	##

	my %DELETED_PRODUCTS = ();
	my ($INV2) = INVENTORY2->new($USERNAME,$LUSERNAME);

	foreach my $PRODUCTID (sort keys %UPDATES) {
		my $SKIP = 0;
		if ($optionsref->{'NEW_ONLY'}) {
			## only add products 
			if (&ZOOVY::productidexists($USERNAME,$PRODUCTID)) { $SKIP++; }
			}

#		else {
#			$PRODUCTID = &ZOOVY::builduniqueproductid($USERNAME,$prodhash{'zoovy:prod_name'}); 
#			$bj->slog("Creating Unique Product ID $PRODUCTID");
#			}

		if (defined($PRODUCTID) && $PRODUCTID ne '') { 
			$PRODUCTID =~ s/[^\w\-]+//g;			
			$bj->slog("Product ID is: $PRODUCTID");
			}

		next if ($SKIP);

		# my ($prodref) = &ZOOVY::fetchproduct_as_hashref($USERNAME,$PRODUCTID);
	
		my ($P) = PRODUCT->new($USERNAME,$PRODUCTID,'create'=>1);
		my $prodref = $P->prodref();

		if ((defined $optionsref->{'DESTRUCTIVE'}) && ($optionsref->{'DESTRUCTIVE'})) {
			foreach my $k (keys %{$prodref}) {
				## note: this should remove %SKU detail as well.
				delete $prodref->{$k}; 
				}
			}

#		## NONDESTRUCTIVE
#		if (not defined $optionsref->{'NONDESTRUCTIVE'}) {
#			$prodref = {}; 	# clean start!
#			die();
#			}
#			my $ref = &ZOOVY::fetchproduct_as_hashref($USERNAME,$PRODUCTID);
##			my %tmphash = %prodhash;
##			%prodhash = &ZOOVY::attrib_handler(&ZOOVY::fetchproduct_data($USERNAME,$PRODUCTID));
#			foreach my $k (keys %{$ref}) { 
#				next if (defined $prodhash{$k});	## we've updated this key
#				$prodhash{$k} = $ref->{$k}; 		## this key wasn't imported, so copy it.
#				}
#			}


		## at this point we've got the product loaded.
		foreach my $set (@{$UPDATES{$PRODUCTID}}) {
			my ($SKU,$COMMAND,$VALUE,$METAREF) = @{$set};

			if ($COMMAND eq 'DELETE') {
				my $DELETE = int($VALUE);
				if ( ($DELETE & 16) == 16) {
					## eventually this list should be replaced by a flexedit list of images.
					require MEDIA;
					if ((defined $prodref->{'zoovy:prod_thumb'}) && ($prodref->{'zoovy:prod_thumb'} ne '')) {
						print STDERR "NUKING: $USERNAME,$prodref->{'zoovy:prod_thumb'}\n";
						&ZOOVY::log($USERNAME,$LUSERNAME,"IMPORT.PRODUCT","INFO","Nuking product thumb $prodref->{'zoovy:prod_thumb'} for PID $PRODUCTID");
						&MEDIA::nuke($USERNAME,$prodref->{'zoovy:prod_thumb'});
						$bj->slog("Nuking image: ".$prodref->{'zoovy:prod_thumb'});
						}
					my $img = 0;
					for ($img=0; $img<9999; $img++) {
						next if ($prodref->{'zoovy:prod_image'.$img} eq '');
						print STDERR "NUKING: $USERNAME,".$prodref->{'zoovy:prod_image'.$img}."\n";
						&ZOOVY::log($USERNAME,$LUSERNAME,"IMPORT.PRODUCT","INFO","Nuking product thumb $prodref->{'zoovy:prod_thumb'} for PID $PRODUCTID");
						&MEDIA::nuke($USERNAME,$prodref->{'zoovy:prod_image'.$img});
						$bj->slog("Nuking image: ".$prodref->{'zoovy:prod_image'.$img});
						}
					$bj->slog("Removing $PRODUCTID images");
					}

			
				if ( ($DELETE & 1) == 1) {
					&ZOOVY::deleteproduct($USERNAME,$PRODUCTID,nuke_cache=>0,nuke_navcats=>0);
					$bj->slog("Removing $PRODUCTID from database and website");
					require NAVCAT;
					foreach my $prttxt (@{ZWEBSITE::list_partitions($USERNAME)}) {
						my ($prt) = split(/:/,$prttxt);
						if (not defined $NCS[$PRT]) { $NCS[$PRT] = NAVCAT->new($USERNAME,PRT=>$PRT); }
						my $NC = $NCS[$prt];

						if ((defined $NC) && (ref($NC) eq 'NAVCAT')) {
							$NC->nuke_product($PRODUCTID);
							}
						}
					$DELETED_PRODUCTS{$PRODUCTID} |= 1;
					}
				elsif ( ($DELETE & 2) == 2) {
					## NOTE: this is not necessary if we did 1, because that nuked everything.
					$DELETED_PRODUCTS{$PRODUCTID} |= 2;
					if (not defined $NCS[$PRT]) { $NCS[$PRT] = NAVCAT->new($USERNAME,PRT=>$PRT); }
					my $NC = $NCS[$PRT];
					$NC->nuke_product($PRODUCTID); 
					undef $NC;
					$bj->slog("Removing $PRODUCTID from navigation categories");
					}
	
   	      if ( ($DELETE & 1) == 1) {
					## if we nuked the product it nuked the inventory
					}
				elsif ( ($DELETE & 4) == 4) {		
					$INV2->pidinvcmd($PRODUCTID,'NUKE');
					$bj->slog("Removing $PRODUCTID from Inventory");
					}
				## End of DELETE code
				}
			elsif ($COMMAND eq 'USE-TEMPLATE') {
				$bj->slog("Loading template $VALUE for $PRODUCTID");
				my ($Pt) = PRODUCT->new($USERNAME,$VALUE);
				foreach my $k (keys %{$Pt->prodref()}) {
					$prodref->{$k} = $Pt->fetch($k);
					}
				}
			elsif ($COMMAND eq 'SET-INVENTORY') {
				# print STDERR "Saving Inventory for $PRODUCTID (".int($INVENTORY).")";
				$bj->slog("Saving SIMPLE Inventory for $SKU (".int($VALUE).")");
				$INV2->skuinvcmd($SKU,"SET",'BASETYPE'=>'SIMPLE',QTY=>$VALUE);
				## &INVENTORY::add_incremental($USERNAME,$SKU,'U',int($VALUE)); 
				}
			elsif ($COMMAND eq 'SET-LOCATION') {
				## &INVENTORY::set_location($USERNAME,$SKU,$VALUE);
				$INV2->skuinvcmd($SKU,'ANNOTATE','BASETYPE'=>'SIMPLE','NOTE'=>$VALUE);
				}
			elsif ($COMMAND eq 'SET-MIN_QTY') {
				$bj->slog("Saving Minimum Qty for $PRODUCTID (".int($VALUE).")");
				$P->skustore("sku:inv_reorder",$VALUE);
				## &INVENTORY::set_meta($USERNAME,$PRODUCTID,'REORDER_QTY'=>$VALUE);
				}
			elsif ($COMMAND eq 'SET-FOLDER') {
				$prodref->{'zoovy:prod_folder'} = $VALUE;
				}
			elsif ($COMMAND eq 'SET-POGS-FROM-JSON') {
				$prodref->{'@POGS'} = POGS::from_json($VALUE);
				}
			elsif ($COMMAND eq 'SET-POGS-FROM-XML') {
				$prodref->{'@POGS'} = POGS::deserialize($VALUE);
				}
			elsif ($COMMAND eq 'ADD-CATEGORY') {
				my $safe = $METAREF->{'safe'};
				my $pretty = $METAREF->{'pretty'};

				if (not defined $NCS[$PRT]) { $NCS[$PRT] = NAVCAT->new($USERNAME,PRT=>$PRT); }
				my $NC = $NCS[$PRT];
				if ($NC->exists($safe)) {
					$NC->set($safe,insert_product=>$PRODUCTID);
					}
				else {
					$NC->set($safe,pretty=>$pretty,insert_product=>$PRODUCTID);
					}
				$SORT_CATS[$PRT]->{$safe}++;
				#if (defined $optionsref->{'PRODNAVCAT'}) {
				#	}
				#elsif (not defined $MANAGEMENT_CAT) {
				#	$MANAGEMENT_CAT = '/'. substr($CATEGORY,0,35);
				#	}
				}
			elsif ($COMMAND eq 'SET-POG') {
				my ($pogid, $pogvalue) = ($METAREF->{'pogid'}, $METAREF->{'pogvalue'});
				my ($pogs2) = $P->fetch_pogs();
				my $selectedpog = undef;
				my $sogref = undef;
				foreach my $pog (@{$pogs2}) {
					if ($pog->{'id'} eq $pogid) { $selectedpog = $pog; }
					}
				if (not defined $selectedpog) {
					($sogref) = &POGS::load_sogref($USERNAME,$pogid);
					my %copy = %{$sogref};						
					if ($sogref->{'global'}>0) { 
						}
					elsif (ref($copy{'@options'}) eq 'ARRAY') {
						$copy{'@options'} = [];
						}	# don't copy in options
					push @{$pogs2}, \%copy;
					$selectedpog = \%copy;
					}
				# print Dumper($sogref);

				## SANITY: at this point selectedpog is set, so lets add an option.
				foreach my $opt (@{$sogref->{'@options'}}) {
					my $match = 0;
					print Dumper($opt,$pogvalue);
					if ($opt->{'v'} eq $pogvalue) { $match++; }
					if ($opt->{'prompt'} eq $pogvalue) { $match++; }
					if (uc($opt->{'prompt'}) eq uc($pogvalue)) { $match++; }
					next if (not $match);
					push @{$selectedpog->{'@options'}}, $opt;
					}
				# print Dumper(\%prodhash,$pogs2);	
				# die();
				}
			elsif ($COMMAND =~ /^[\s]*\<(sku)\>[\s]*(.*?)[\s]*$/o) {
				## <sku>owner:attrib
				my ($ATTRIB) = ($2);
				$P->skustore($SKU,$ATTRIB,$VALUE);
				}
			elsif ($COMMAND =~ /^[\s]*\<(base)\>[\s]*(.*?)[\s]*$/o) {
				## <base>owner:attrib
				my ($ATTRIB) = ($2);
				$P->store($ATTRIB,$VALUE);
				}
			elsif (&PRODUCT::FLEXEDIT::is_valid($COMMAND,$USERNAME)) {
				## NOTE: $COMMAND is the attribute and it could be a user: field, or a zoovy:xx field
				##			if we got here, we're adding it!
				my $flexref = $PRODUCT::FLEXEDIT::fields{$COMMAND};
				if (not defined $flexref) {
					foreach my $tryref (@SPECIAL_USER_CUSTOM_FIELDS) {
						if ($tryref->{'id'} eq $COMMAND) { $flexref = $tryref; }
						}
					}
				if (not defined $flexref) {
					$flexref = { 'id'=>$COMMAND, 'type'=>'text' };
					}

				if ($flexref->{'type'} eq 'currency') {
					$VALUE =~ s/,//gs;
					}
				## calculate SUPPLIER price base on cost given MARKUP
				#if (not defined $SUPPLIER) {
				#	}
				#elsif ( ($COMMAND eq 'zoovy:base_cost') && (int($VALUE*100) > 0) ) {
				#	## this will probably need to change when we update base_cost
				#	if ($SUPPLIER->fetch_property('MARKUP') ne '') {
				#		my ($calc_price) = SUPPLIER::calculate_price($prodref,$SUPPLIER);
				#		$VALUE = ($calc_price);
				#		}
				#	}

				if (($SKU ne $PRODUCTID) && ($flexref->{'sku'})) {
					$P->skustore($SKU,$COMMAND,$VALUE);
					# print STDERR "SKU:$SKU $VALUE\n";
					# $prodref->{'%SKU'}->{$SKU}->{$COMMAND} = $VALUE;
					}
				else {
					$prodref->{$COMMAND} = $VALUE;
					}
				}
			else {
				die("UNKNOWN COMMAND[$COMMAND] This line should never be reached!");
				}

			}

		$bj->progress($rows_done++,$rows_count,"Product: $PRODUCTID");

		## e.g. force zoovy:prod_supplier 
		if (scalar(keys %OVERRIDES)) {
			foreach my $k (keys %OVERRIDES) { $prodref->{$k} = $OVERRIDES{$k}; }
			}

		if (($DELETED_PRODUCTS{$PRODUCTID} & 1)==1) {
			## if a product has been deleted, then we don't save it!
			}
		elsif (&ZCSV::validsku($PRODUCTID)) {
			use Data::Dumper;				
			$P->save();
			}

		# if we have inventory, lets write that too
		}



	if (scalar(keys %DELETED_PRODUCTS)>0) {
		# &NAVCAT::clean_navcats($USERNAME);
		&ZOOVY::nuke_product_cache($USERNAME);
		}


	## Resort any categories which may have changed.
	if (scalar(@NCS)>0) {
		foreach my $NC (@NCS) {
			next if (not defined $NC);
			my $PRT = $NC->prt();
			my @PATHS = keys %{$SORT_CATS[$PRT]};
			if ($optionsref->{'RESORT_NAVCATS'}) {
				$bj->slog("Resorting all navigation categories - this may take some time!");
				@PATHS = $NC->paths();
				}
			foreach my $safe (@PATHS) {
				$NC->sort($safe);
				}
			$NC->save();
			}
		}


	return($linecount);
	}




__DATA__
				
						my $STORE_IN_OPTION = 0;

						if ((defined $OPTIONSTR) && ($STORE_IN_OPTION)) {
							$prodhash{"%SKU"}->{"$PRODUCTID:$OPTIONSTR"}->{$VALUE} = $DATA[ $optionsref->{'%ATTRIBVALUE'} ];
							}
						else {
							$prodhash{$VALUE} = $DATA[ $optionsref->{'%ATTRIBVALUE'} ];
							}
					else {
						$bj->slog("<font color='red'>ERROR: %ATTRIBVALUE was found!</font>");				
						}					


				my $CAN_STORE_VALUE_IN_OPTION = 0;
				if (my $flexref = $PRODUCT::FLEXEDIT::fields{$destfield}) {
					## validate known types
					}


				else {
					$prodhash{$destfield} = $VALUE;
					}


			}




					if ($VALUE eq '') {
						}
					elsif ($format eq 'JSON') {

					else {
						$bj->slog("<font color='red'>Invalid %POGS= field should be JSON|XML</font>");
						}


		## now lets do some sanity
		# create product id
		if ($SKIP) {
			$bj->slog("Skipping $PRODUCTID");
			}
		elsif ($DELETE) {
			# make sure we don't build a sku then delete it.
			$bj->slog("<font color='red'>ERROR: Found %DELETE but %PRODUCTID was blank or missing.</font>");
			} 
		# now make sure we don't stomp additional fields

		delete $prodlist{$PRODUCTID};

#		$bj->slog(Dumper(\@CATEGORIES));
#		$bj->slog("level1 [$DELETE]");

		if ($SKIP) {
			$bj->slog("Skipping product: $PRODUCTID\n");
			}
		elsif ($DELETE) {
			## All this code is for deleting a product (specifically $PRODUCTID)
			next if ($PRODUCTID eq '');
		
		
			}
		else {
			## All this code is for creating a product
			if (not defined $NCS[$PRT]) { $NCS[$PRT] = NAVCAT->new($USERNAME,PRT=>$PRT); }
			my $NC = $NCS[$PRT];
			foreach my $CATEGORY (@CATEGORIES) {
				next unless $CATEGORY;

				$bj->slog("<b>Adding $PRODUCTID to Category [$CATEGORY]</b>");
	
				elsif ($optionsref->{'ONLY_IF_NAVCAT_EXISTS'}) {
					my $safepath = $CATEGORY;
					}
				else {
					my $safepath = $CATEGORY;
					$NC->set($safepath,insert_product=>$PRODUCTID);
					}


			if ($MANAGEMENT_CAT ne '') {
				$bj->slog("Adding $PRODUCTID to Management Category [$MANAGEMENT_CAT]");
				}

			if ( (not defined $prodhash{'zoovy:taxable'}) || ($prodhash{'zoovy:taxable'} eq '') && (not $DELETE)) {
				$prodhash{'zoovy:taxable'} = '1';
				}


			## DESTRUCTIVE
			else {
				$bj->slog("DESTRUCTIVE OVERWRITE! $USERNAME $PRODUCTID");
				}

 			# print Dumper(\@MACROS);

			foreach my $macro (@MACROS) {
				if ($macro->[0] eq 'SET-POG') {
					} 
				else {
					$bj->slog("UNKNOWN INTERNAL MACRO: $macro->[0]");
					}
				}

			# die();

	
			$bj->slog("Checking for valid SKU");
	
				if ($HOMEPAGE) { 
					$bj->slog("Adding $PRODUCTID to Homepage");
					if (not defined $NCS[$PRT]) { $NCS[$PRT] = NAVCAT->new($USERNAME,PRT=>$PRT); }
					my $NC = $NCS[$PRT];
					$NC->set('.',insert_product=>$PRODUCTID);
					}
				$bj->slog("Saving Product ID $PRODUCTID (".$prodhash{'zoovy:prod_name'}.")");
				}
			else {
				$bj->slog("$PRODUCTID is not a valid product id, not saving!");
				}

			}

	} # end of while loop




	


}




1;