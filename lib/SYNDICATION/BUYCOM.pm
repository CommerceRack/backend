package SYNDICATION::BUYCOM;

use Text::CSV_XS;
use POSIX qw (strftime);
use JSON::XS;
use strict;
use Data::Dumper;
use Business::UPC;
use Net::FTP;
use lib "/backend/lib";
require PRODUCT;
require ZTOOLKIT;


##
## master list of buy.com store categories.
##
$SYNDICATION::BUYCOM::STORECODES = [
	{ id=>"666", title=>"Generic (does not require storecode)", headerset=>0,  },
	{ id=>"1000", title=>"Computers", headerset=>1,  },
	{ id=>"2000", title=>"Software", headerset=>1, },
	{ id=>"3000", title=>"Books", headerset=>1, },
	{ id=>"4000", title=>"DVD/Movies", headerset=>1, },
	{ id=>"5000", title=>"Games", headerset=>1, },
	{ id=>"6000", title=>"Music", headerset=>1, },
	{ id=>"7000", title=>"Electronics", headerset=>1, },
	{ id=>"14000", title=>"Bags (Non-Apparel)", headerset=>1, },
	{ id=>"16000", title=>"Toys", headerset=>0, }
	];



##
## converts a buy.com dbmap json into a flexedit.
##
#sub maptxt_to_flexedit {
#	my ($USERNAME,$MAPTXT,$prodref) = @_;
#
#	# use Data::Dumper; print STDERR Dumper($MAPTXT);
#
#	my $has_inv_options = undef;
#	if (defined $prodref) {
#		if (($prodref->{'zoovy:inv_enable'}&4)>0) {
#			$has_inv_options=1;	
#			}
#		else {
#			$has_inv_options=0;
#			}
#		}
#
#	my $ref  = JSON::XS::decode_json($MAPTXT);
#	# use Data::Dumper; print STDERR Dumper($ref);
#
#	foreach my $map (@{$ref}) {
#		## turn off 'sku'=>1 for this product if we don't have inventoriable options.
#		if (($map->{'sku'}==0) || (not defined $has_inv_options)) {
#			}
#		elsif ($map->{'sku'}>0) { 
#			## turn off sku=>1 when options aren't in use.
#			$map->{'sku'} = 0; 
#			}
#
#		## make sure everything has a pretty title.
#		if ($map->{'title'} eq '') { 
#			$map->{'title'} = $map->{'header'}; 
#			my $required = (substr($map->{'header'},0,1) eq '[')?'**REQUIRED**':'';
#			$map->{'title'} .= " ($map->{'id'}) $required";
#			}
#		# print STDERR Dumper($map);
#		}
#	
#	return($ref);
#	}
#

##
##
##
sub fetch_dbmap {
	my ($USERNAME,$MAPID) = @_;


	my ($map) = &SYNDICATION::BUYCOM::fetch_dbmaps($USERNAME,mapid=>$MAPID);
	return($map);
	}


##
## input parameters:
##		detail=>1 -- only returns MAPID
##		mapid=>'xyz' -- only returns data for MAPID xyz
##
sub fetch_dbmaps {
	my ($USERNAME, %options) = @_;

	my @maps = ();

	my $MAPID_EXISTING = {
			'STOREID'=>'666',
			'MAPID'=>'EXISTING',
			'MAPTXT'=>qq~[{"id":"buycom:sku","type":"textbox","sku":"1","default":"-"}]~,
			};


	if (($options{'mapid'} eq 'EXISTING') || (not defined $options{'mapid'})) {
		push @maps, $MAPID_EXISTING;
		}

	if ($options{'mapid'} eq 'EXISTING') {
		}
	else {
		my $udbh = &DBINFO::db_user_connect($USERNAME);
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		my $pstmt = "select * ";
		if ($options{'detail'}==1) { $pstmt = "select MAPID "; }
		$pstmt .= " from BUYCOM_DBMAPS where MID=$MID /* $USERNAME */ ";
		if (defined $options{'mapid'}) {
			$pstmt .= " and MAPID=".$udbh->quote($options{'mapid'});
			}
		$pstmt .= " order by MAPID";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $hashref = $sth->fetchrow_hashref() ) {
			next if ($hashref->{'MAPID'} eq 'EXISTING');
			push @maps, $hashref;
			}
		$sth->finish();
		&DBINFO::db_user_close();
		}
	
	if (scalar(@maps)==0) {
		push @maps, $MAPID_EXISTING;
		}
	
	return(@maps);
	}


## 
## feed formatter for buy.com (BUY code) - csv, tab-delimited
##


## we need to have an alias to username here, since we won't always have $self->so() initialized
## (for example if we we're being called from a product editor panel)
sub username { return($_[0]->{'_USERNAME'}); }
sub prt { return($_[0]->{'_PRT'}); }
sub tmpdir { return($_[0]->{'_TMPDIR'}); }


##
##
sub new {
	my ($class, $so) = @_;
	my ($self) = {};

	$self->{'_SO'} = $so;
	#$self->{'@NEEDS_TS'} = [];
	#$self->{'@NEEDS_TS_ERROR'} = [];

	## NOTE: buy.com works a little screwy, since we actually need to upload several files.
	##			so as we go, for each buycom:dbmap we encounter, we're going to load the dbmap,
	##			then create an entry in %FILES .. we'll keep the whole thing in memory, then dump
	##			it to the disk in the footer function.
	$self->{'%FILES'} = {};
	$self->{'%dbmaps'} = {};		## dynamically built list of dbmaprefs

	$self->{'_USERNAME'} = $so->username();
	$self->{'_PRT'} = $so->prt();

	my $TMPDIR = sprintf("/tmp/BUY-%s-%d",$so->username(),time());
	if (! -d $TMPDIR) { mkdir($TMPDIR); }
	$self->{'_TMPDIR'} = $TMPDIR;

	tie my %s, 'SYNDICATION', THIS=>$so;
	## we'll be using FTP not email
	#if(not $s{'.approved'}) {
	#	$CUSTOMER = $s{'.sellerid'};
	#	$s{'.url'} = "email:".$s{'.buy_person'};
	#	}

	$self->{'_csv'} = Text::CSV_XS->new({binary=>1, quote_char=>'', always_quote=>1, sep_char => "\t"}); # create a new object
	my $csv = $self->{'_csv'};

	bless $self, $class;
	}



############################################################
##
##
##
sub ftp_connect {
	my ($so, $tlm) = @_;

	tie my %s, 'SYNDICATION', THIS=>$so;

	my @RELAYS = ();
	push @RELAYS, "ftpgw.zoovy.net:2370";

	my $ftp = undef; 
	if (not $tlm->can_proceed()) {
		}
	elsif (scalar(@RELAYS)) {
		## use ftp relay/proxy
		my ($HOST,$PORT) = split(":",$RELAYS[0]);
		if (not defined $PORT) { $PORT = 21; }
		$ftp = Net::FTP->new($HOST, Port=>$PORT, Debug => 1);
		if (not defined $ftp) { $tlm->pooshmsg("ISE|+FTP Error - Could not connect to relay $HOST:$PORT"); }
		if ($tlm->can_proceed()) {
			my $rc = $ftp->login(qq~"$s{'.ftp_user'}"\@trade.marketplace.buy.com~,$s{'.ftp_pass'});
			if (not $rc) { 
				$tlm->pooshmsg(sprintf("ERROR|+FTP Error - Could not login or temporarily banned '%s' '%s'",$s{'.ftp_user'},$s{'.ftp_pass'})); 
				}
			}
		}
	else {
		## direct connect
		$ftp = Net::FTP->new("trade.marketplace.buy.com", Debug => 1);
		if (not defined $ftp) { $tlm->pooshmsg("ISE|+FTP Error - Could not connect to trade.marketplace.buy.com"); }
		if ($tlm->can_proceed()) {
			my $rc = $ftp->login($s{'.ftp_user'},$s{'.ftp_pass'});
			if (not $rc) { 
				$tlm->pooshmsg(sprintf("ERROR|+FTP Error - Could not login or temporarily banned '%s' '%s'",$s{'.ftp_user'},$s{'.ftp_pass'})); 
				}
			}
		}


	if ($tlm->can_proceed()) {
		$ftp->binary();
		}

	return($ftp);
	}



##
## returns a syndication object
sub so { return($_[0]->{'_SO'}); }


sub upload {
	my ($self, $file, $tlm) = @_;

	my ($so) = $self->so();
	my $USERNAME = $so->username();
#	my $PROFILE = $so->profile();
	my $DSTCODE = $so->dstcode();
	tie my %s, 'SYNDICATION', THIS=>$so;

	my $sj = $so->{'%options'}->{'sj'};

	if (not $tlm->can_proceed()) {
		}
	elsif ($s{'.ftp_user'} eq '') {
		$tlm->pooshmsg("ERROR|FTP username was not specified.");
		}

	#$s{'.url'} = 'ftp://'.$s{'.ftp_user'}.':'.$s{'.ftp_pass'}.'@trade.marketplace.buy.com:2370/NewSku/Products.txt';
	#if ($so->{'%options'}->{'type'} eq 'inventory') {
	#	$s{'.url'} = 'ftp://'.$s{'.ftp_user'}.':'.$s{'.ftp_pass'}.'@trade.marketplace.buy.com:2370/Inventory/Inventory.txt';
	#	}

	my $ftp = undef;
	if ($tlm->can_proceed()) {
		$ftp = SYNDICATION::BUYCOM::ftp_connect($so,$tlm);
		}


	if (not defined $tlm->can_proceed()) {
		## shit already happened.
		}
	elsif ($so->type() eq 'products') {
		opendir my $D, $self->{'_TMPDIR'};
		my $files = 0;
		while ( my $file = readdir($D) ) {
			next if (substr($file,0,1) eq '.');
			print "UPLOADING FILE: $file\n";
			if (defined $sj) { $sj->progress(0,0,"Transferring Products");  }
			my $localfile = sprintf("%s/%s",$self->{'_TMPDIR'},$file);
			$ftp->put($localfile,"/NewSku/$file") or $tlm->pooshmsg("ERROR|+FTP Error - unable to transfer products file $localfile");
			$files++;
			}
		closedir $D;
		if ($tlm->can_proceed()) {
			$tlm->pooshmsg("SUCCESS|+Transferred $files product files");
			}
		}
	elsif ($so->type() eq 'inventory') {
		my $remotefile = strftime("/Inventory/inventory_%Y%m%d_%H%M%S.txt",localtime());
		print "$so->{'_FILENAME'},$remotefile\n";

		$ftp->put($so->{'_FILENAME'},$remotefile) or $tlm->pooshmsg(sprintf("ERROR|+FTP Error %s - unable to transfer inventory file $so->{'_FILENAME'}",$ftp->message()));
		
		if ($tlm->can_proceed()) {
			$tlm->pooshmsg("SUCCESS|+Inventory File Transferred");
			}
		}
	else {
		$tlm->pooshmsg("ISE|+Unknown upload type: ".$so->type());
		}
	# cleanup:
	# rmtree($self->{'_IMAGESDIR'});

	# die();
	return($tlm);
	}


##
## this is used to implicitly delete inventory.
##
sub INVENTORY_DELETE {
	my ($self,$SKU,$was_processed) = @_;

	my ($so) = $self->so();
	$so->pooshmsg("INFO|+$SKU is deleted/blocked, sending 99999.99 as price");

	my $txt = "\t$SKU\t3\t1\t99999.99\t99999.99\t0\t0\t\t0\t0\t\t$SKU\r\n";
	return($txt);
	}



##
## note: this is called externally (not from object) via panel_validate
##
sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;
	my $RESULT = undef;

	my $USERNAME = undef;
	if (defined $self) {
		$USERNAME = lc($self->username());
		}
	else {
		$USERNAME = $P->username();
		}

	my $so = undef;	## this means we're running from PRODUCT::PANELS
	if (defined $self) { $so = $self->so(); }

	my $EXISTING_SKU = 0;
	if ((not $RESULT) && (not $EXISTING_SKU) && ($P->fetch('zoovy:base_price') eq '')) {
		$RESULT = "VALIDATION|ATTRIB=zoovy:base_price|+Product does not have a base price set.";
		}

	my $UPC = undef;
	if ($SKU =~ /:/) {
		$UPC = $P->skufetch($SKU,'zoovy:prod_upc');
		}
	else {
		$UPC = $P->fetch('zoovy:prod_upc');
		}

	if ($UPC =~ /[\s]+/) {	
		$RESULT = "VALIDATION|ATTRIB=zoovy:prod_upc|+upc may not contain spaces";
		}
	## the errors above don't *care* if it's an existing sku (we always gotta have a price)

	if ((not $RESULT) && ($P->fetch('buycom:dbmap') eq 'EXISTING')) { $EXISTING_SKU++; }

	if ($RESULT) {
		}
	elsif (not defined $so) {
		## this probably means we're running validate from PRODUCT::PANELS (ugh)
		}
	elsif ( ($so->dstcode() eq 'BUY') && ($P->fetch('buycom:ts')<1) ) {
		$RESULT = "VALIDATION|buycom:ts|+buycom:ts is not enabled .. cannot syndicate";
		}
	elsif ( ($so->dstcode() eq 'BST') && ($P->fetch('bestbuy:ts')<1) ) {
		$RESULT = "VALIDATION|bestbuy:ts|+bestbuy:ts is not enabled .. cannot syndicate";
		}

	my $DBMAP = $P->fetch('buycom:dbmap');
	if ((not $RESULT) && ($P->fetch('buycom:dbmap') eq '')) {
		$DBMAP = 'EXISTING';
		## WARN: "{buycom:dbmap}buycom:dbmap is not set .. cannot syndicate";
		# $P->fetch('buycom:dbmap') = 'EXISTING';
		# $RESULT = "{buycom:dbmap}buycom:dbmap is not set .. cannot syndicate";
		}


	if ($RESULT) {
		}
	elsif ($P->skufetch($SKU,'buycom:sku') ne '') {
		}
	elsif ($P->skufetch($SKU,'zoovy:prod_isbn') ne '') {
		}
	elsif ($UPC ne '') {
		}

	## restrictive verification
	## in order to be included in NewSKU a product will need to be buycom:ts == 1
	## and buycom:category will need to be set to something "non-blank"
	#if (not $P->fetch('buycom:category'))	{
	#	$RESULT = "buycom:category is required for syndication.";
	#	}
	## this is not universally true.. i'm certain.
	#if ($P->fetch('zoovy:prod_upc') !~ /^\d{12}$|^\d{14}$/) {
	#	$RESULT = "Product UPC is required for syndication. Must be valid 12 or 14 digits number.";
	#	}
	if ((not $RESULT) && (not $EXISTING_SKU) && ($UPC ne '')) {
		my $bupc = Business::UPC->new($UPC);
		if (not defined $bupc) { $RESULT = sprintf("VALIDATION|ATTRIB=zoovy:prod_upc|+Product UPC '%s' is not well formed.",$UPC); }
		elsif (not $bupc->is_valid()) { $RESULT = sprintf("VALIDATION|ATTRIB=zoovy:prod_upc|+Product UPC '%s' is not valid.",$UPC); }
		}

	if ((not defined $self) || (not defined $self->so())) {
		## ?!?
		}
	elsif ($self->so()->{'%options'}->{'type'} eq 'INVENTORY') {
		## INVENTORY SPECIFIC VALIDATION
		$EXISTING_SKU++;
		}
	else {
		## PRODUCT SPECIFIC VALIDATION
		my $DBMAP = uc($P->fetch('buycom:dbmap')); 
		if ((not $RESULT) && (not $EXISTING_SKU)  && ($DBMAP =~ /[^A-Z0-9]/)) {
			$RESULT = sprintf("VALIDATION|ATTRIB=buycom:dbmap|+Product DBMap '%s' contains invalid characters.",$DBMAP);
			}

		if ((not $RESULT) && (not $EXISTING_SKU)  && (not $P->fetch('zoovy:prod_image1')))	{
			$RESULT = "VALIDATION|ATTRIB=zoovy:prod_image1|+Product Main Image (zoovy:prod_image1) must be set for syndication.";
			}
	
		## use buycom:prod_mfg and buycom:prod_mfgid
		if (defined $P->fetch('buycom:prod_mfg')) { $P->fetch('zoovy:prod_mfg') = $P->fetch('buycom:prod_mfg'); }
		if (defined $P->fetch('buycom:prod_mfgid')) { $P->fetch('zoovy:prod_mfgid') = $P->fetch('buycom:prod_mfgid'); }
		
		if ((not $RESULT) && (not $EXISTING_SKU)  && (not $P->fetch('zoovy:prod_mfg')))	{
			$RESULT = "VALIDATION|ATTRIB=zoovy:prod_mfg|+Product Manufacturer (zoovy:prod_mfg) must be set for syndication.";
			}
		if ((not $RESULT) && (not $EXISTING_SKU)  && (not $P->fetch('zoovy:prod_mfgid')))	{
			$RESULT = "VALIDATION|ATTRIB=zoovy:prod_mfgid|+Product ManufacturerID (zoovy:prod_mfgid) must be set for syndication.";
			}
		if ((not $RESULT) && (not $EXISTING_SKU)  && ($P->fetch('zoovy:prod_desc') eq '')) {
			$RESULT = "VALIDATION|ATTRIB=zoovy:prod_desc|+Product description is required for syndication.";
			}

		}

	## validate against the dbmap
	my $dbmapid = uc($P->fetch('buycom:dbmap'));

	$dbmapid =~ s/[^A-Z0-9]+//gs;
	my $dbmap = undef;
	if ((not defined $RESULT) && (not $EXISTING_SKU)  && ($dbmapid eq '')) {
		$RESULT = "VALIDATION|ATTRIB=buycom:dbmap|+attribute buycom:dbmap not set";
		}

	my $mapref = undef;
	if (defined $RESULT) {
		## shit apparently happened.
		}
	elsif ($EXISTING_SKU) {
		## SKU already exists, it won't need to be sent (inventory only)
		}
	elsif (defined $self->{'%dbmaps'}->{$dbmapid}) {
		## hurrah.. we already loaded this dbmap
		$mapref = $self->{'%dbmaps'}->{$dbmapid};
		}
	else {
		## lookup dbmap add to $self->{'%dbmaps'}
		$mapref = &SYNDICATION::BUYCOM::fetch_dbmap($USERNAME,uc($P->fetch('buycom:dbmap')));

		if (not defined $mapref) {
			$RESULT = "VALIDATION|ATTRIB=buycom:dbmap|+attribute buycom:dbmap references map $dbmapid which does not exist.";
			}
		else {
			$mapref->{'@headers'} = JSON::XS::decode_json($mapref->{'MAPTXT'});
			foreach my $storeref (@{$SYNDICATION::BUYCOM::STORECODES}) {
				if ($storeref->{'id'} == $mapref->{'STOREID'}) {
					$mapref->{'store_title'} = $storeref->{'title'};
					$mapref->{'store_headerset'} = $storeref->{'headerset'};
					}
				}
			$mapref->{'file'} = sprintf("%s/NEWSKU-%d-%d-%s-%s.txt",$self->{'_TMPDIR'},$mapref->{'CATID'},$mapref->{'STOREID'},$dbmapid, POSIX::strftime("%Y%m%d%H%M%S",localtime()));
			$self->{'%dbmaps'}->{$dbmapid} = $mapref;

			foreach my $map (@{$mapref->{'@headers'}}) {
				if ($map->{'header'} =~ /^\[(.*?)\]$/) {
					## headers in brackets are: [Required]
					$map->{'is_required'}++;
					}
				if (ref($map->{'options'}) eq 'ARRAY') {
					foreach my $optref (@{$map->{'options'}}) {
						## apparently *some* customers (toynk for example) can't figure out that these 
						## are case-sensitive, so we must create an uppercase version call vUC pronounced
						## "vugh-ked" or the "vugh-ked UP" value.
						$optref->{'vUC'} = uc($optref->{'v'});
						}
					}
				## we should do some more high level dbmap validating here.
				}
			}
		}

	if (defined $RESULT) {
		## shit already happened.
		}
	elsif ($EXISTING_SKU) {
		## this already exists on buy.com
		}
	elsif ($mapref->{'CATID'} == 0) {
		## A DBMAP with CATID zero means that we should look into the product for buycom:categoryid
		if (int($P->fetch('buycom:categoryid'))<=0) {
			$RESULT = "VALIDATION|ATTRIB=buycom:categoryid|+A DBMAP ".Dumper($mapref)." using CategoryID=0 requires buycom:categoryid to be set as product attribute (is \"$P->fetch('buycom:categoryid')\").";
			}
		}


	if (defined $RESULT) {
		}
	elsif ($EXISTING_SKU) {
		## this already exists on buy.com
		}
	elsif (not defined $mapref) {
		$RESULT = "VALIDATION|ATTRIB=buycom:dbmap|+Internal error: DBMap $dbmapid could not be initialized.";
		}
	elsif (1) {
		## no longer offering dbmap validation (deprecated due to deserialize_skuref)
		}
#	else {
#		## lets validate the DBMAP
#		foreach my $map (@{$mapref->{'@headers'}}) {
#			my $zoovyattr = $map->{'id'};
#			my %SKUDATA = ();		## a hash keyed by SKU or PID with the $zoovyattr as value
#			if ($pid =~ /:/) {
#				## liar, this is a SKU not a PID -- we're probably being called from SYNDICATION::
#				## *AND* that means that $prodref is already merged with $mref
#				$SKUDATA{$pid} = $P->fetch($zoovyattr);
#				}
#			elsif ($map->{'sku'}) {
#				## okay so if we get here, we're on a sku specific field, being called as a product .. probably from
#				## panel_validate (we could probably verify this with caller() later on if i weren't so lazy)
#				foreach my $SKU (&ZOOVY::skuarray_via_prodref($pid,$prodref)) {
#					my $mref = &ZOOVY::deserialize_skuref($prodref,$SKU);
#					$SKUDATA{$SKU} = $mref->{$zoovyattr};
#					}
#				}
#			else {
#				## don't really care who called us, lets just validate this biatch.
#				$SKUDATA{$pid} = $P->fetch($zoovyattr);
#				}
#			# $RESULT = "|".Dumper(\%SKUDATA,$P->fetch('zoovy:prod_id'));
#
#			## now we run through each SKU (or it might just be the PID) and check to see if we have a valid value.				
#			foreach my $SKU (keys %SKUDATA) {
#				next if ($RESULT ne '');
#				my $result = $SKUDATA{$SKU}; # $P->fetch($zoovyattr);
#				if (not defined $result) { $result = $map->{'default'}; }
#				if ($map->{'is_required'}) {
#					## we have a required field.. lets build a list of allowed values
#					## note: this assumes we're dealing with a select list/enumeration.
#					my %valid = ();
#					if ($map->{'type'} eq 'select') {
#						if (not defined $map->{'options'}) {
#							$RESULT = "{$zoovyattr}DBMap $dbmapid header $map->{'header'} (type=select) has no valid options configured. ";
#							}
#						else {
#							foreach my $kv (@{$map->{'options'}}) { 
#								$valid{ $kv->{'vUC'} } = $kv->{'v'};
#								}
#							if (not defined $valid{ uc($result) }) {
#								$RESULT = "{$zoovyattr}DBMap $dbmapid says Invalid value \"$result\" for $map->{'header'} attrib[$zoovyattr] valid: ".join(",",sort values %valid);
#								}
#							}
#						}
#					elsif ($result eq '') {
#						## we can't validate against options, but we can check to make sure it's not blank.
#						$RESULT = "{$zoovyattr}DBMap $dbmapid says header $map->{'header'} may not be blank for '$SKU'";
#						}
#					}	# end is_required
#				}	# end foreach $SKU
#			}
#		}

	$plm->pooshmsg($RESULT);

	return();
	}


#######################################################################################################
##
## *** NEW PRODUCT FEED ***
##
#######################################################################################################


sub dbmap_product_header {
	
	}


##
## returns a tab-delimited header for product feed
sub header_products {
	my ($self) = @_;

	## persistent copy of all dbmaps for a user 
	## (this sucks but it's faster than getting them individually)
	# $self->{'%dbmaps'} = &BUYCOM::SYNDICATION::fetch_dbmaps($USERNAME);
	
	return("");
	}



##
## produces a csv data line for the product
## SEE 'sub header' for every data field description
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my ($pid) = PRODUCT::stid_to_pid($SKU);
	my $product_set_id = '';
	if ($P->pid() ne $SKU) { 
		## product-set-id's are for grouping
		$product_set_id = uc($SKU); 
		## BUY.com says alphanmeric, but fuck'em  we're gonna assume they support dashes and underscores
		##	that would just be stupid if they didn't since it wouldn't save any space in the database.
		## if we use the line below - then it potentially causes collisions e.g. SHIRT123 and SHIRT-123 are the same.
		# $product_set_id =~ s/[^A-Z0-9]+//g;
		}

	if ($P->skufetch($SKU,'zoovy:prod_upc') =~ /\s+/) {
		$plm->pooshmsg("ERROR|+spaces are not allowed in the zoovy:prod_upc field");
		}

	if ($P->fetch('buycom:ts') < 1) {
		## premature exit due to buycom:ts not being set.
		$plm->pooshmsg("STOP|+buycom:ts is not set to allow syndication");
		}

	if ($P->fetch('buycom:dbmap') eq 'EXISTING') {
		## special "EXISTING" dbmap is for products which are already on buy.com
		$plm->pooshmsg(sprintf("STOP|+dbmap indicates '%s' is EXISTING",$SKU));
		}

	if (not $plm->can_proceed()) {
		return("");
		}

	my $ERROR = undef;
	my $dbmapid = uc($P->fetch('buycom:dbmap'));
	$dbmapid =~ s/[^A-Z0-9]+//gs;
	my $dbmap = undef;
	if ((not defined $ERROR) && ($dbmapid eq '')) {
		$ERROR = "VALIDATION|ATTRIB=buycom:dbmap|+attribute buycom:dbmap not set";
		}

	my $mapref = undef;
	if (defined $self->{'%dbmaps'}->{$dbmapid}) {
		## hurrah.. we already loaded this dbmap
		$mapref = $self->{'%dbmaps'}->{$dbmapid};
		}
	else {
		$ERROR = "ISE|ATTRIB=buycom:dbmap|+%dbmaps->{$dbmapid} was not initialized .. caller should run validate() to initialize it first.";
		}
	
	## 
	## SANITY: at this point $mapref better fucking be set or shit is gonna break.
	##	
	my ($csv) = $self->{'_csv'};
	my $CSVFILE = $mapref->{'file'};	
	my $HEADER_COLUMNS = 0;

	if ($ERROR) {
		}
	elsif ($CSVFILE eq '') {
		$ERROR = "ERROR|+Could not create CSV file";
		}
	elsif (! -f $mapref->{'file'}) {
		## Create a new CSV FIle w/header.
		warn "Creating $CSVFILE\n";
		my @columns = ();
		# Buy.com store identifier, e.g. computers, books, electronics etc.
		## see $SYNDICATION::BUYCOM::STORECODES 
		push @columns, "seller-id";			 # reqiured NEW! Integer identifying the seller creating the product. Example: 15582389
		push @columns, "gtin";						# required GTIN compatible product identifier (i.e. UPC or EAN). 12 or 14 digits
		push @columns, "isbn";						# reqired for all Books - 10 or 13 digits
		push @columns, "mfg-name";				# required
		push @columns, "mfg-part-number"; # required
		push @columns, "asin";						# NEW! The Amazon Standard Identification Number (ASIN)
		push @columns, "seller-sku";			# required NEW! An arbitrary, seller specified, alpha-numeric string 
		push @columns, "title";					 # required
		push @columns, "description";		 # required
		push @columns, "main-image";			# url
		push @columns, "additional-images"; # url
		push @columns, "weight";					# required, in pounds, decimal
	
		# Carriage Returns, ther special symbols are not accep	
		# Examples: TV-quality video with audio~Bonus Disc Included
		push @columns, "features";
	
		push @columns, "listing-price";	 # required, decimal
		push @columns, "msrp";
	
		if ($mapref->{'store_headerset'} == 0) {
			push @columns, "category-id";		 # required, integer from buy.com taxonomy, one cat per product
			# NEW! Search keywords that will help customers locate your product. 
			# Use the pipe character (|
			# Example: waterproof|down|parka|anorak
			push @columns, "keywords";
			push @columns, "product-set-id";	# Alpha-numeric string uniquely identifying the Product Set to which the current product belongs.

			## add variable headers
			foreach my $map (@{$mapref->{'@headers'}}) {
				next if ($map->{'id'} eq 'buycom:categoryid');
				my $header = $map->{'header'};
				if ($header =~ /^\[(.*?)\]$/) { $header = $1; }
				push @columns, $header; 
				}
			}
		elsif ($mapref->{'store_headerset'} == 1) {
			## Everything but toys(2) and generic(0)
			push @columns, "keywords";
			push @columns, "product-set-id";	# Alpha-numeric string uniquely identifying the Product Set to which the current product belongs.
			push @columns, "store-code";			
			push @columns, "category-id";		 # required, integer from buy.com taxonomy, one cat per product
			}
		elsif ($mapref->{'store_headerset'} == 2) {
			## TOYS apparently doens't use store-code
			push @columns, "keywords";
			push @columns, "product-set-id";	# Alpha-numeric string uniquely identifying the Product Set to which the current product belongs.
			push @columns, "category-id";		 # required, integer from buy.com taxonomy, one cat per product
			}
		else {
			die("this line should never be reached (invalid headerset)");
			}

		## some random blank columns as suggested by dereck @ buy.com
		if ($mapref->{'store_headerset'} != 2) {
			push @columns, "";		
			push @columns, "";		
			push @columns, "";		
			push @columns, "";		
			push @columns, "";		
			push @columns, "";		
			push @columns, "";		
			push @columns, "";		
			push @columns, "";		
			push @columns, "";
			}
		## some categories aso support attribute1, attribute2, ..., attributeN fields
		## can added directly into the header line

		# use Data::Dumper; print Dumper($mapref);

	
		#my $status = $csv->combine(@columns);		# combine columns into a string
		#my $line = $csv->string();							 # get the combined string
		my $line = join("\t",@columns);

		open F, ">>$CSVFILE";
		print F $line."\r\n";
		close F;
		## END OF INITIALIZED PRoDUCT FILE W/HEADER
		}
	

	## 
	## SANITY: at this point the $CSVFILE has been created, with the appropriate header
	##
	my @columns = ();
	push @columns, $self->so()->get('.sellerid'); # seller-id REQUIRED

	push @columns, $P->skufetch($SKU,'zoovy:prod_upc') ? $P->skufetch($SKU,'zoovy:prod_upc') : '';
	push @columns, $P->skufetch($SKU,'zoovy:prod_isbn');	 # isbn REQUIRED for Books
	push @columns, $P->skufetch($SKU,'zoovy:prod_mfg') ? $P->fetch('zoovy:prod_mfg') : '';	 # mfg-name REQUIRED
	
	if (($self->username() eq 'cubworld') && ($P->fetch('zoovy:prod_mfgid') eq '')) {
		$P->fetch('zoovy:prod_mfgid') = $SKU;
		}
	push @columns, $P->skufetch($SKU,'zoovy:prod_mfgid') ? $P->skufetch($SKU,'zoovy:prod_mfgid') : ''; # mfg-part-number REQUIRED
	push @columns, $P->skufetch($SKU,'amz:asin');				 # asin
	push @columns, $SKU;			# seller-sku REQUIRED			

	if ((defined $P->fetch('zoovy:sku_name')) && ($P->fetch('zoovy:sku_name') ne '')) {								 
		push @columns, $P->fetch('zoovy:sku_name');	# title REQUIRED
		}
	else {
		push @columns, $P->fetch('zoovy:prod_name');	# title REQUIRED
		}
	
	my $DESCRIPTION = $P->fetch('zoovy:prod_desc');
	if ($DESCRIPTION =~ /\<([Bb][Rr]|[Dd][Ii][Vv])\>/) {
		## has a br tag, or div tag, so it's probably html
		$DESCRIPTION = &ZTOOLKIT::htmlstrip($DESCRIPTION);
		}
	else {
		## no html, we'll strip wiki just to be safe.
		$DESCRIPTION = &ZTOOLKIT::wikistrip($DESCRIPTION);
		}		
	$DESCRIPTION =~ s/[\n\r]+/ /g;	## no hard returns in file.
	push @columns, $DESCRIPTION;	# description REQUIRED
	
	# main-image, additional-images
	push @columns, &ZOOVY::mediahost_imageurl($P->username(),$P->thumbnail($SKU),0,0,'FFFFFF',0,'jpg');
	if ($P->fetch('zoovy:prod_image2') ne '') {
		push @columns, &ZOOVY::mediahost_imageurl($P->username(),$P->fetch("zoovy:prod_image2"),0,0,'FFFFFF',0,'jpg');
		}
	else {
		push @columns, "";
		}
	
	## convert ounces into lbs
	my $WEIGHT = $P->fetch('zoovy:base_weight');
	if($WEIGHT !~ /#/) {
		$WEIGHT =~ s/[^\d\.]//g;
		$WEIGHT = sprintf("%.2f", $WEIGHT/16);
		} 
	else {
		$WEIGHT =~ s/[^\d\.]//g;
		}
	push @columns, $WEIGHT; # weight in lbs REQUIRED
	
	my $features = '';
	if ($P->fetch('zoovy:prod_features') ne '') {
		## zoovy's prod features is a bulleted list, separated by hard returns, 
		## but buy.com wants pipe separated.
		foreach my $line (split(/[\n\r]+/,$P->fetch('zoovy:prod_features'))) {
			$line =~ s/^[\s]*\*[\s]*//;	# remove leading bullets.
			$features .= (($features)?"|":"")."|".$line;
			}
		}
	push @columns, $features;								 # features separated by ~ or maybe a |

	if ($SKU =~ /\:/) {
		push @columns, $OVERRIDES->{'zoovy:base_price'};
		}
	else {
		push @columns, $P->fetch('zoovy:base_price'); # price REQUIRED
		}
	
	push @columns, $P->fetch('zoovy:prod_msrp');	# msrp

	my $CATID = $P->fetch('buycom:categoryid');
	if ($mapref->{'CATID'} == 0) {
		## if the dbmap says it's CATEGORYID 0 then we use the buycom:categoryid in the product
		# the product attribute buycom:categoryid holds the category id, but this field is ONLY USED for dbmaps
		# which use CATID zero.
		}
	else {
		## if the dbmap has a categoryid set, then we'll *always* use that.
		## even *if* the user has set a buycom:categoryid in the product - we overwrite it with the dbmap.
		$CATID = $mapref->{'CATID'};
		}

	if ($mapref->{'store_headerset'} == 0) {
		# 1000=Computers 2000=Software 3000=Books 4000=DVD/Movies 5000=Games 6000=Music 7000=Electronics 14000=Bags 16000=Toys
		push @columns, $CATID; 		 	# category-id REQUIRED 
		push @columns, "";													# keywords separated by |
		push @columns, $product_set_id;													# product-set-id

		## add variable data (based on $mapref/dbmap)	
		foreach my $map (@{$mapref->{'@headers'}}) {
			next if ($map->{'id'} eq 'buycom:categoryid');
			my $result = $P->fetch( $map->{'id'} );
			if (not defined $result) { $result = $map->{'default'}; }
			## see the issue is that some users (toynk) don't actually bother to adhere to case sensitivivity
			## for option values .. this code will attempt to prove the statement "you can't fix stupid" is incorrect.
			if ($map->{'type'} eq 'select') {
				my %mvUC = ();	# mother of all vuckers. 
				foreach my $optref (@{$map->{'options'}}) {
					## create the v upper case or "vucked up" value.
					$mvUC{uc($optref->{'v'})} = $optref->{'v'}; 
					}
				$result = $mvUC{uc($result)};
				}
			push @columns, sprintf("%s",$result);
			}
		}
	elsif ($mapref->{'store_headerset'} == 1) {
		push @columns, "";														 # keywords separated by |
		push @columns, $product_set_id;														 # product-set-id
		push @columns, $mapref->{'STOREID'};	 # store-code - REQUIRED
		push @columns, $P->fetch('buycom:categoryid');		 # category-id REQUIRED
		}
	elsif ($mapref->{'store_headerset'} == 2) {
		push @columns, "";														 # keywords separated by |
		push @columns, $product_set_id;														 # product-set-id
		push @columns, $P->fetch('buycom:categoryid');		 # category-id REQUIRED
		}
	else {
		die("this line should never be reached - invalid headerset");
		}


	
	
	my $i = scalar(@columns);
	while ($i-->0) {
		$columns[$i] = &ZTOOLKIT::stripUnicode($columns[$i]);
		$columns[$i] =~ s/[\n\r\t]+//g;	# no tabs allowed in file!
		$columns[$i] =~ s/^[\s]+//g;
		$columns[$i] =~ s/[\s]+$//g;
		}
	
	#my $status = $csv->combine(@columns);		# combine columns into a string
	#my $line = $csv->string();							 # get the combined string
	my $line = join("\t",@columns);

	open F, ">>$CSVFILE";
	print F $line."\r\n";
	close F;

	print "WROTE: $CSVFILE\n";

	## now we create a response file that tells which sku was in which file.
	my $response = "$SKU\t$CSVFILE";

	return("$response");
	}



##
##
sub footer_products {
	my ($self) = @_;

	## eventually this could be moved into a success/finalization/cleanup module -- if there ever is one.
	my $USERNAME = $self->so()->username();

	#foreach my $pid (@{$self->{'@NEEDS_TS'}}) {
	#	my $prod = &ZOOVY::fetchproduct_as_hashref($USERNAME,$pid);
	#	$prod->{'buycom:ts'} = $^T;
	#	&ZOOVY::saveproduct_from_hashref($USERNAME,$pid,$prod);
	#	}

	#foreach my $pid (@{$self->{'@NEEDS_TS_ERROR'}}) {
	#	my $prod = &ZOOVY::fetchproduct_as_hashref($USERNAME,$pid);
	#	$prod->{'buycom:ts'} = 0;
	#	&ZOOVY::saveproduct_from_hashref($USERNAME,$pid,$prod);
	#	}

	## let merchant know if they are offering free shipping

	return("");
	}



#######################################################################################################
##
## *** INVENTORY FEED ***
##
#######################################################################################################


##
## returns a tab-delimited header for inventory feed
sub header_inventory {
	my ($self) = @_;

	##
	## note: if you add headers here, you need to add them to the INVENTORY_DELETE function as well.
	##
	
	$self->{'_csv'} = Text::CSV_XS->new({binary=>1, sep_char => "\t"}); # create a new object
	my $csv = $self->{'_csv'};



	my @columns = ();
	#push @columns, "listing-id";
	push @columns, "ListingId";
	#push @columns, "product-id";					# required
	push @columns, "ProductId";
	#push @columns, "product-id-type";		 # required 0 = Buy.com SKU; 1 = ISBN; 2 = UPC; 3=Seller SKU
	push @columns, "ProductIdType";
	#push @columns, "item-condition";			# required 1=Brand New, 2=Used-Like New, 3=Used-Very Good, 4=Used-Good, 5=Used-Acceptable 10=Refurbished
	push @columns, "ItemCondition";
	#push @columns, "price";							 # required
	push @columns, "Price";
	push @columns, "MAP";
	push @columns, "MAPType";							# added 8/26/12
	#push @columns, "quantity";						# required
	push @columns, "Quantity";
	#push @columns, "expedited-shipping";	# required 0 or 1
	push @columns, "OfferExpeditedShipping";
	#push @columns, "item-note";
	push @columns, "Description";
	# push @columns, "reference-id";				# required - SKU
	# push @columns, "ReferenceId";				# removed 9/21/09
	push @columns, "ShippingRateStandard";
	push @columns, "ShippingRateExpedited";
	push @columns, "ShippingLeadTime";
	push @columns, "OfferTwoDayShipping";		# added 8/26/12
	push @columns, "ShippingRateTwoDay";		# added 8/26/12
	push @columns, "OfferOneDayShipping";		# added 8/26/12
	push @columns, "ShippingRateOneDay";		# added 8/26/12
#	push @columns, "OfferSameDayShipping";		# added 8/26/12  # removed by buy.com on 8/29/12
#	push @columns, "ShippingRateSameDay";		# added 8/26/12  # removed by buy.com on 8/29/12
	push @columns, "OfferLocalDeliveryShippingRates"; # added 8/26/12
	push @columns, "ReferenceId";

	my $status = $csv->combine(@columns);		# combine columns into a string

	my $line = "##Type=Inventory;Version=5.0\r\n";
	$line .= $csv->string()."\r\n";							 # get the combined string

	return($line);
	}


sub finish {
	my ($self,$lm) = @_;

	my $TMPDIR = $self->tmpdir();
	if (-d $TMPDIR) {
		$lm->pooshmsg("INFO|+removed temporary files");
		system("/bin/rm -Rf $TMPDIR");
		}
	}


##
## produces a csv data line for the inventory
## SEE 'sub invHeader' for every data field description
sub inventory {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	my $ERROR = undef;

	## we need to resolve dbmaps here so we know what category we're working with.
	##	since electronics has some special rules.
	my $dbmapid = uc($P->fetch('buycom:dbmap'));
	$dbmapid =~ s/[^A-Z0-9]+//gs;
	my $dbmap = undef;
	if ((not defined $ERROR) && ($dbmapid eq '')) {
		$ERROR = "attribute buycom:dbmap not set";
		}

	my $mapref = undef;
	if ($dbmapid eq 'EXISTING') {
		## we never error out when we have an existing sku!
		}
	elsif (defined $self->{'%dbmaps'}->{$dbmapid}) {
		## hurrah.. we already loaded this dbmap
		$mapref = $self->{'%dbmaps'}->{$dbmapid};
		}
	else {
		$self->{'%dbmaps'}->{$dbmapid} = &SYNDICATION::BUYCOM::fetch_dbmap($self->username(),uc($dbmapid));
		# $ERROR = "%dbmaps->{$dbmapid} was not initialized .. you need to run validate() to initialize it first.";
		}

	if ($P->fetch('buycom:sku') eq '-') {
		## just kidding, we don't actually want to send this item!
		$ERROR = "buycom:sku is '-' which will not submit";
		}

	## restrictive verification
	if ((not defined $ERROR) && ($P->fetch('buycom:ts') < 1)) {
		$ERROR = "buycom:ts was $P->fetch('buycom:ts') (do not syndicate)";
		}
	elsif (sprintf("%.2f",$P->fetch('zoovy:base_price')) eq '0.00') {
		$ERROR = "zoovy:base_price must be set";
		}
	

	#if (defined $ERROR) {
	#	}
	#elsif ($P->fetch('buycom:dbmap') eq 'EXISTING') {
	#	## Existing SKU's don't need to have buycom:sku or buycom:category set (they will need a upc or isbn)
	#	}
	#elsif (($P->fetch('buycom:sku') eq '') && ($P->fetch('buycom:category') eq '')) {
	#	## No buycom SKU and no category - SKIP
	#	$ERROR = "buycom:sku and buycom:category not set (cannot be syndicated)";
	#	}
	
	## not yet listed - SKIP
	#if ($P->fetch('buycom:ts') < 1) {
	#	$error = "buycom:ts was $P->fetch('buycom:ts') (has not been syndicated yet)";
	#	}

	my $line = '';
	if (defined $ERROR) {
		$plm->pooshmsg("ERROR|+$ERROR");
		}
	else {
		my $csv = $self->{'_csv'};

		my @columns = ();
		# The listing-id is a number assigned by Buy.com to uploaded listings. The listing-id is created after you have successfully listed your items. Please leave blank if you are listing items for the first time. Normally, the only time you need to use the listing-id is if you want to change the .reference-id. of the item.
		# Example: 4782351
		# NOTE: This number will be referenced in your seller pages for listings.
		# push @columns, "";	# listing-id - DONT USE! TESTED - GOT AN ERROR!!!
		push @columns, $P->skufetch($SKU,'buycom:listingid');	# listing-id - DONT USE! TESTED - GOT AN ERROR!!!

		#Product-id is a unique identifier that is used to find the product you wish to list on the Marketplace. The product-id types which can be used:
		# (1) ISBN must be 13 digits in length.
		# (2) UPC must be 12 or 14 digits in length
		# (0) Buy.com SKUs have variable lengths
		# (3) Seller SKU have variable lengths
		#Examples: 30764650 or 0066620996
		#Note: ISBN will be used for Books and UPC will be used for electronics, hardware and software. The Buy.com SKU is universal accross categories

		#if ($pid eq 'DW0280') {
		#	die("SKU:$P->fetch('buycom:sku')\n".Dumper($prodref));
		#	}

		if ($P->skufetch($SKU,'buycom:sku') ne '') {
			push @columns, $P->fetch('buycom:sku');
			push @columns, '0';
			}
		elsif ($P->skufetch($SKU,'zoovy:prod_isbn') ne '') {
			push @columns, $P->skufetch($SKU,'zoovy:prod_isbn');
			push @columns, 1;
			}
		elsif ($P->skufetch($SKU,'zoovy:prod_upc') ne '') {
			push @columns, $P->skufetch($SKU,'zoovy:prod_upc');
			push @columns, 2;
			}
		else {
			push @columns, $SKU;
			push @columns, 3;
			}

		# item-condition - REQUIRED
		# 1=Brand New, 2=Used-Like New, 3=Used-Very Good, 4=Used-Good, 5=Used-Acceptable 10=Refurbished
		# Please enter the numerical index corresponding to the condition of the item:
		# 1 = Brand New, 2 = Used-Like New, 3 = Used-Very Good, 4 = Used-Good, 5 = Used-Acceptable, 10 = Refurbished
		my $condition = 1; ## assume it's new
		if (($mapref->{'CATID'} == 1000) || ($mapref->{'CATID'} = 7000)) {
			## 9/21/09 computers and electronics have their own special rules.
			## can only be 1 = brand new, and 10 = refurbished
			if ($P->fetch('zoovy:prod_condition') eq '') {
				$condition = 1;	## assume it's new
				}
			elsif ($P->fetch('zoovy:prod_condition') =~ /New/i) {
				$condition = 1; 	# it's new!
				}
			else {
				$condition = 10; 	# this is probably used.
				}
			}
		elsif($P->fetch('zoovy:prod_condition') =~ /Refurbished/i) {
			$condition = 10; # Refurbished
			} 
		elsif($P->fetch('zoovy:prod_condition') =~ /Used/i) {
			$condition = 4; # Used-Good
			} 
		else {
			$condition = 1; # New
			}
		push @columns, $condition;

		# Enter the unit price for this product. Price should be greater than 0.00.
		# Do NOT enter the currency symbols (e.g. $) or use commas in the price.
		# Do not specify more than 2 decimal points.
		# Example: 4.99	
		#push @columns, sprintf("%.2f",$P->skufetch($SKU,'zoovy:base_price'));	# price REQUIRED
		if ($OVERRIDES->{'zoovy:base_price'}) {
			push @columns, $OVERRIDES->{'zoovy:base_price'};
			}
		else {
			push @columns, $P->fetch('zoovy:base_price'); # price REQUIRED
			}
#		if ($SKU =~ /\:/) {
#			push @columns, $OVERRIDES->{'zoovy:base_price'};
#			}
#		else {
#			push @columns, $P->fetch('zoovy:base_price'); # price REQUIRED
#			}

		my ($mapprice) = sprintf("%.2f",$P->fetch('zoovy:prod_mapprice'));
		if ($mapprice>0) {
			## map should only be specified IF we need to comply with map rules 
			push @columns, sprintf("%.2f",$mapprice);
			## 0=none, 1=click for price, 2=cart for price, 3=checkout for price
			push @columns, 1;				
			}
		else {
			push @columns, '';		## never include a value of zero
			push @columns, 0;
			}
		# print STDERR sprintf("BASE_PRICE: %.2f\n",$P->fetch('zoovy:base_price'));


		if ($OVERRIDES->{'zoovy:qty_instock'}<0) { 
			$OVERRIDES->{'zoovy:qty_instock'} = 0; 
			}
		if ($OVERRIDES->{'zoovy:qty_instock'}>9998) {
			# inventory for buy.com should never exceed 9998 
			$OVERRIDES->{'zoovy:qty_instock'} = 9998; 
			}
		push @columns, $OVERRIDES->{'zoovy:qty_instock'} ? $OVERRIDES->{'zoovy:qty_instock'} : 0; # quantity REQUIRED
	
		## SHIPPING
		## 	- shipping attributes are to be pushed as follows: OfferExpeditedShipping, Notes, ShipCost, ShipExpCost, ShippingLeadTime
		## 	- because the order slightly strange, wait until all shipping variables have been set before pushing   

		## Expedited Shipping
		##
		##	OfferExpeditedShipping if a required attribute
		##		- Sellers shipment must arrive in 4 business days if they offer this option.
      ##		- 1 = Offering Expedited Shipping
      ##		- 0 = Not Offering Expedited shipping
      ##		- Example: 1
		##		- Must be set to 1 to use expedited shipping even if marketplace values (configured on buy.com) are to be used
		##
		## Expedited shipping value is not required to be populated as merchant may choose to use marketplace values. 
		##		- look at buycom:shipexp_cost1 first
		## 	- if -100 	=> do NOT offer
		## 	- if -1 	=> use marketplace
		## 	- if 0  	=> free (increment $ship_free_ctr)
		## 	- if > 0 	=> use that 
		##		- if '' 	=> look at zoovy:ship_expcost1
		### keep in mind... zoovy:ship_expcost1 undef sends 0 => free
		my $enable_expship = 0;
		my $ship_expcost = $P->fetch('buycom:shipexp_cost1');
		if (not defined $ship_expcost) { $ship_expcost = $P->fetch('zoovy:ship_expcost1'); }
		if ($ship_expcost == -100) {
			# don't offer expedited shipping
			$ship_expcost = '';
         $enable_expship = 0; # don't offer expedited shipping
			}
		elsif ($ship_expcost == -1) {
			# use marketplace expedited shipping
			$ship_expcost = '';
			$enable_expship = 1; 	# offer expedited shipping
			}
		elsif ((defined $ship_expcost) && ($ship_expcost >= 0)) {
			# send actual value so no need to re-define
			$enable_expship = 1; 	# offer expedited shipping
			}
		else {
			# attribute is either not set or is invalid. leave $enable_expship as 0
			}

		# Note?
		# These notes will appear in your Marketplace listing. Up to 250 characters of free form text describing the condition of the item.
		# Do not put any product details or marketing information here.
		# Examples: Manufacturer reconditioned. New in box
		
		my $ship_itemnote = "";															# item-note

		# push @columns, $pid;														# reference-id REQUIRED
		#	The flat rate shipping fee you want to charge for Standard shipping, which will override the Buy.com default shipping rates. If you don.t specify a value, the shipping rates from the Buy.com default shipping table will be used.
		# Rate must be >= 0.
		# Use 0 for Free Shipping.
		# Do not enter currency symbols or commas. Do not specify more than 2 decimal points.
		# Example: 5.95
		## look at buycom:ship_cost1 first
		## if -1 	=> use marketplace
		## if 0  	=> free (increment $ship_free_ctr) $self->increment("ship_free");
		## if > 0 	=> use that 
		##	if '' 	=> look at zoovy:ship_cost1
		### keep in mind... zoovy:ship_cost1 undef sends 0 => free
		my $ship_cost = $P->fetch('buycom:ship_cost1');
		if ($ship_cost == -1) {
			# use marketplace shipping
			$ship_cost = '';
			}
		elsif ($ship_cost >= 0) {
			# send actual value so no need to re-define
			}
		else {
			#attribute is either not defined or has an invalid value so use 'zoovy:ship_cost1'
			$ship_cost = $P->fetch('zoovy:ship_cost1');
			}
#		if ($ship_cost == 0){
#			# free shipping has been set on this product
#			$self->{'_ship_free_CTR'}++;	# counting how many products have free shipping to notify merchant under buy.com history tab
#			}
	
		# ShippingLeadTime
		# only works with the home & ourdoor, sports, toys and baby, doesn't work with other categories
		# note 9/21/09 - if we actually include this for non-allowed categories it throws an error.
		my $ship_leadtime = '';
		if (defined $P->fetch('buycom:prod_shipleadtime')) {
			$ship_leadtime = $P->fetch('buycom:prod_shipleadtime');
			}
		else {
			## nothing to do. $ship_leadtime already set to ''.
			}
	
		push @columns, $enable_expship;
		push @columns, $ship_itemnote; 
		push @columns, $ship_cost;
		push @columns, $ship_expcost;
		push @columns, $ship_leadtime;

		## we don't have support for these fields yet
		push @columns, 0; 	#"OfferTwoDayShipping"
		push @columns, '';	#"ShippingRateTwoDay"
		push @columns, 0;		#"OfferOneDayShipping"
		push @columns, '';	#"ShippingRateOneDay"
#		push @columns, 0;		#"OfferSameDayShipping" # removed by buy.com on 8/29/12
#		push @columns, '';	#"ShippingRateSameDay" # removed by buy.com on 8/29/12
		push @columns, 0;		#OfferLocalDeliveryShipping Rates


		# ReferenceId
		# A unique product id assigned to the product by you. The SKU field is a unique alphanumeric identifier for each product - e.g., your internal ID code/SKU. Maximum of 30 characters.
		# Once you associate a ReferenceId to a listing (and Buy.com SKU) you should not change this association. The only time you would have different ReferenceId.s for the same Buy.com SKU is when you are listing different ItemCondition listings for that Buy.com SKU.
		# You can change the ReferenceId association by including the ListingId of the item that has the ReferenceId you would like to change. If the new ReferenceId is not in use then the association will be changed to use the new ReferenceId.
		# Example: 01-02993AV0-QA-1
		push @columns, $SKU;
 	
		my $i = scalar(@columns);
		while ($i-->0) {
			$columns[$i] = &ZTOOLKIT::stripUnicode($columns[$i]);
			}
		
		my $status = $csv->combine(@columns);		# combine columns into a string
		$line = $csv->string()."\r\n";							 # get the combined string
		}

	return($line);	
	}



##
##
sub footer_inventory {
	my ($self) = @_;
	return("");
	}



1;
