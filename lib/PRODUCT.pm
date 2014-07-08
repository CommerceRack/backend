package PRODUCT;


use strict;
use warnings;
use Digest::MD5;
use URI::Escape::XS qw();

no warnings 'once';
no warnings 'redefine';

$PRODUCT::POG_MAX_SKU = 256;		# the maximum number of skus we will build from pogs. 
$PRODUCT::POG_SAFE_BUILD = 2;		# the maximum number of POGS we will safely attempt to build

require POGS;
require ZOOVY;
require DBINFO;
require ZTOOLKIT;
##
## properties:
##		USERNAME,STID,PID,INV_OPTS,NON_OPTS,VIRTUAL
##		OPTIONSTR
##
##


## cheap function for removing 'Use of uninitialized value in sprintf'
sub str { return( (defined $_[0])?$_[0]:'' ); }

@PRODUCT::SPECIAL_CODES = (
	'CID',	# CUSTOMER ID
	'SKU',	# SKU
	'AMT',	# AMOUNT
	'MIN',	# MIN
	'MAX',	# MAX
	'QTY',	# QTY
	'EXP',	# EXPIRES
	);

@PRODUCT::RETURN_PROFILES = (
	'NONE'=>{ title=>'No Returns Allowed', 	cash_period=>0,	credit_period=>0,	exchange_period=>0, },
	'CE1Y'=>{ title=>'Store Credit or Exchange: 1 Year', cash_period=>0, credit_period=>365, exchange_period=>365, },
	'E1Y'=>{ title=>'Exchange Only: 1 Year',	cash_period=>0,	credit_period=>0,	exchange_period=>365, },
	'E90'=>{ title=>'Exchange Only: 90 Days',	cash_period=>0,	credit_period=>0,	exchange_period=>90, },
	'E60'=>{ title=>'Exchange Only: 60 Days',	cash_period=>0,	credit_period=>0,	exchange_period=>60, },
	'E30'=>{ title=>'Exchange Only: 30 Days',	cash_period=>0,	credit_period=>0,	exchange_period=>30, },
	'E14'=>{ title=>'Exchange Only: 14 Days',	cash_period=>0,	credit_period=>0,	exchange_period=>14, },
	'C90'=>{ title=>'Store Credit Only: 90 Days',	cash_period=>0,	credit_period=>90,	exchange_period=>0, },
	'C60'=>{ title=>'Store Credit Only: 60 Days',	cash_period=>0,	credit_period=>90,	exchange_period=>0, },
	'C30'=>{ title=>'Store Credit Only: 30 Days',	cash_period=>0,	credit_period=>90,	exchange_period=>0, },
	'C14'=>{ title=>'Store Credit Only: 14 Days',	cash_period=>0,	credit_period=>90,	exchange_period=>0, },
	'R90'=>{ title=>'Full Refund: 90 Days',	cash_period=>90,	credit_period=>0,	exchange_period=>0, },
	'R60'=>{ title=>'Full Refund: 60 Days',	cash_period=>60,	credit_period=>0,	exchange_period=>0, },
	'R30'=>{ title=>'Full Refund: 30 Days',	cash_period=>30,	credit_period=>0,	exchange_period=>0, },
	'R14'=>{ title=>'Full Refund: 14 Days',	cash_period=>14,	credit_period=>0,	exchange_period=>0, },
	'R14/E90'=>{ title=>'Full Refund: 14 Days, Store Credit 90 days', cash_period=>14, credit_period=>90, exchange_period=>0, },
	'R14/C90'=>{ title=>'Full Refund: 14 Days, Store Credit or Exchange 90 days', cash_period=>14, credit_period=>90, exchange_period=>90, },
	'R14/CE1Y'=>{ title=>'Full Refund: 14 Days, Store Credit or Exchange 1 Year', cash_period=>14, credit_period=>90, exchange_period=>90, },
	);


##
## the TO_JSON method is used by JSON::XS->new->utf8->allow_blessed(1)->convert_blessed(1)->encode($R);
##	(PAGE::JQUERY)
##
sub TO_JSON {
	my ($self) = @_;

	my %j = ();
	

	return(\%j);
	}

sub DESTROY {
	## called before we free
	my ($self) = @_;
	
	if (not defined $self->{'_tied'} || $self->{'_tied'}==0) {
		}
	else {
		$self->{'_tied'}--;
		}
	}

## you can tie one of these options.
##		you must pass USERNAME,PID
##		you can optionally pass REF
sub TIEHASH {
	my ($class, $USERNAME, $PID, %options) = @_;

	my $self = undef;
	if (ref($USERNAME) eq 'PRODUCT') { $self = $USERNAME; }	## we passed in a product reference instead of user (hmm.. retie?) 
	if (defined $options{'*OBJ'}) { $self = $options{'*OBJ'}; } ## better pass USERNAME,PID,*OBJ=>$PRODOBJ
	if (not defined $self) {
		## hmm, i guess we want a new object.
		$self = PRODUCT->new($USERNAME,$PID,%options);
		}
	$self->{'_tied'}++;

	return($self);
	}

sub FETCH { 
	my ($this,$key) = @_; 	
	return($this->fetch($key));
	}

sub EXISTS { 
	my ($this,$key) = @_; 
	return( (defined $this->fetch($key))?1:0 ); 
	}

sub DELETE { 
	my ($this,$key) = @_; 
	$this->store($key,undef);
	return(0);
	}

sub STORE { 
	my ($this,$key,$value) = @_; 
	$this->store($key,$value);
	return(0); 
	}

sub CLEAR { 
	my ($this) = @_; 
	#foreach my $k (keys %{$this}) {
	#	next if (substr($k,0,1) eq '_');
	#	delete $this->{$k};
	#	}
	return(0);
	}

sub FIRSTKEY {
	my ($this) = @_;
	## skip stuff like %SKU and @POGS in keys
	$this->{'@KEYS'} = [ grep(/^[a-z]/, keys %{$this->{'%data'}} ) ];
	my $x = pop @{$this->{'@KEYS'}};
	return($x);
	}

sub NEXTKEY {
	my ($this) = @_;
	return(pop @{$this->{'@KEYS'}});
	}






##
## is this a temporary (non-savable product)
##
sub is_tmp {
	if (defined $_[1]) { $_[0]->{'_tmp'}= $_[1]; }	# is_tmp(1) sets value to 1
	return(int($_[0]->{'_tmp'}));
	}


##
## just a quick alias to make code more readable
##
sub is_purchasable {
	my ($self) = @_;
	my $base_price = defined($self->fetch('zoovy:base_price')) ? $self->fetch('zoovy:base_price') : '';
	return ($base_price eq '')?0:1;
	}

## returns if we're a claim or not
sub is_claim {
	return( (defined $_[0]->{'CLAIM'})?int($_[0]->{'CLAIM'}):0 );
	}


##
## perl -e 'use lib "/backend/lib"; use PRODUCT; my($P) = PRODUCT->new("zephyrsports","PB-BT-OMEGABLK");  use Data::Dumper; print Dumper($P->elastic_index());'
##
sub elastic_index {
	my ($self, $FIELDSREF, $IMAGE_FIELDSREF, $NC) = @_;

	if (not defined $FIELDSREF || $IMAGE_FIELDSREF) {
		require PRODUCT::FLEXEDIT;
		($FIELDSREF,$IMAGE_FIELDSREF) = &PRODUCT::FLEXEDIT::elastic_fields($self->username());
		}

	my @ES_PAYLOADS = ();
	my ($PID) = $self->pid();

	my %STORE_SKUS = ();
	my $TODO = $self->list_skus('verify'=>1); # an array of [ [sku1,skuref1], [sku2,skuref2] ]
	## step1: 
	my ($INVSUMMARY) = INVENTORY2->new($self->username(),"*events")->summary( '@PIDS'=>[ $PID ], 'ELASTIC_PAYLOADS'=>1);

	foreach my $workset (@{$TODO}) {
		my ($sku,$dataref) = @{$workset};
		if (not defined $INVSUMMARY->{$sku}) { $INVSUMMARY->{$sku} = {}; }
		my %PAYLOAD = ( 'pid'=>$PID, 'sku'=>$sku, %{$INVSUMMARY->{$sku}} );		
		$STORE_SKUS{$sku} = \%PAYLOAD;
		$workset->[2] = $STORE_SKUS{$sku};
		}

	my %prodstore = ();
	## special fields
	$prodstore{'pid'} = $PID;

	## note: %prodstore becomes $storeref below
	unshift @{$TODO}, [ $PID, $self->prodref(), \%prodstore ];

	foreach my $ref (@{$FIELDSREF}) {
		next if ($ref->{'index'} eq '');

		foreach my $workset (@{$TODO}) {
			my ($pidsku,$dataref,$storeref) = @{$workset};

			next if (ref($dataref) ne 'HASH');
			my $value = $dataref->{ $ref->{'id'} };
			next if (not defined $value);		## this is key, because we don't want to index a price as zero

			## reference fields
			$storeref->{ $ref->{'index'} } = $value;

			## CURRENCY
			if ($ref->{'type'} eq 'currency') {
				## currency field - set to integer
				$storeref->{$ref->{'index'}} = int(sprintf("%0f",$storeref->{$ref->{'index'}}*100));
				if ($storeref->{$ref->{'index'}} > (1<<30))  { $storeref->{$ref->{'index'}} = 1<<30; }	## max value?
				}
			elsif ($storeref->{$ref->{'index'}} eq '') {
				## blank string fields (often) cause es to crash and do other wonky things, so we'll not use them.
			 	delete($storeref->{$ref->{'index'}});
				}
			elsif ($ref->{'type'} eq 'keywordlist') {
				## keyword list needs to go through an extra tokenization any cr/lf
				my @ITEMS = ();
				foreach my $item (split(/[\n\r]+/,$storeref->{$ref->{'index'}})) {
					next if ($item eq '');
					$item =~ s/^[\s]+//;	$item =~ s/[\s]+$//;
					push @ITEMS, $item;
					}
				$storeref->{$ref->{'index'}} = \@ITEMS;
				}
			elsif (($ref->{'type'} eq 'finder') || ($ref->{'type'} eq 'commalist')) {
				## finders should be split up into many pieces ex: PID1,PID2,PID3 ['PID1','PID2','PID3']
				## note about commalist -- there was no applicable use case for this when it was built, hopefully erich comes up with one.
				my @ITEMS = ();
				foreach my $item (split(/,/,$storeref->{$ref->{'index'}})) {
					next if ($item eq '');
					$item =~ s/^[\s]+//;	$item =~ s/[\s]+$//;
					push @ITEMS, $item;
					}
				$storeref->{$ref->{'index'}} = \@ITEMS;
				}
			else {
				## some other type
				}
			}
		}
	push @ES_PAYLOADS, {
		'type'=>'product',
		'id'=>"$PID",
		'source'=>\%prodstore	## was 'data' in elastic 0.xx
		};

	my @STORE_IMAGES;
	## $PRODUCT_PROPERTIES{'@skus'} = { 'type'=>'string', 'prodstore'=>'no', 'include_in_all'=>'no' };
	$prodstore{'skus'} = [];
	foreach my $set (@{ $self->list_skus() }) {
		my ($sku,$skuref) = @{$set};
		next if (ref($skuref) ne 'HASH');
		push @{$prodstore{'skus'}}, $sku;
		if ($skuref->{'zoovy:prod_image1'}) { push @STORE_IMAGES, $skuref->{'zoovy:prod_image1'}; }
		}
	if (scalar(@{$prodstore{'skus'}})==0) { delete $prodstore{'skus'}; }
		
	## $PRODUCT_PROPERTIES{'options'} = { 'type'=>'string', 'prodstore'=>'no', 'include_in_all'=>'no' };
	## options
	## $PRODUCT_PROPERTIES{'pogs'} = { 'type'=>'string', 'prodstore'=>'no', 'include_in_all'=>'no' };	
	## pogs
	$prodstore{'options'} = [];
	$prodstore{'pogs'} = [];
	my ($pogs2) = $self->fetch_pogs();
	foreach my $pog (@{$pogs2}) {
		push @{$prodstore{'pogs'}}, $pog->{'id'};
		push @{$prodstore{'options'}}, $pog->{'prompt'};
		if (defined $pog->{'@options'}) {
			foreach my $opt (@{$pog->{'@options'}}) {
				push @{$prodstore{'pogs'}}, sprintf("%s%s",$pog->{'id'},$opt->{'v'});
				push @{$prodstore{'options'}}, sprintf("%s %s",$pog->{'prompt'},$opt->{'prompt'});					
				}
			}
		}
	if (scalar(@{$prodstore{'pogs'}})==0) { delete $prodstore{'pogs'}; }
	if (scalar(@{$prodstore{'options'}})==0) { delete $prodstore{'options'}; }		

	## $PRODUCT_PROPERTIES{'@tags'} = { 'type'=>'string', 'prodstore'=>'no', 'include_in_all'=>'yes' };
	## @tags
	$prodstore{'tags'} = [];
	my $PROD_IS = $self->fetch('zoovy:prod_is');
	my @TAGS = ();
	foreach my $isref (@ZOOVY::PROD_IS) {
		# print "$PROD_IS $isref->{'bit'}\n";
		my $mask = 1 << $isref->{'bit'};
		if (($PROD_IS & $mask) > 0) {
			$self->store($isref->{'attr'},1);
			push @TAGS, $isref->{'tag'};
			}
		}

	## add more tags
	$prodstore{'tags'} = \@TAGS;
	if (scalar(@{$prodstore{'tags'}})==0) { delete $prodstore{'tags'}; }
		

	# $PRODUCT_PROPERTIES{'images'} = { 'type'=>'string', 'prodstore'=>'no', 'include_in_all'=>'yes' };
	## images
	foreach my $attrib (@{$IMAGE_FIELDSREF}) {
		my $value = $self->fetch($attrib);
		if (not defined $value) {
			}
		elsif ($value eq '') {
			}
		else {
			push @STORE_IMAGES, $value;
			}
		}
	## handle zoovy:prod_image1, ebay:prod_image1, amz:prod_image1 .. amz:prod_image24
	foreach my $mkt ('zoovy','amz','ebay') {
		foreach my $i (0..24) {
			my $attrib = sprintf("%s:prod_image%d",$mkt,$i);
			my $value = $self->fetch($attrib);
			if (not defined $value) {
				}
			elsif ($value eq '') {
				}
			else {
				push @STORE_IMAGES, $value;
				}				
			}
		}

	$prodstore{'images'} = \@STORE_IMAGES;
	if (scalar(@{$prodstore{'images'}})==0) { delete $prodstore{'images'}; }
	if (defined $prodstore{'images'}) {
		foreach my $img (@{$prodstore{'images'}}) {
			$img =~ s/\.(jpg|gif|png)$//gs;	# strip extensions (not important to the index)
			}
		}

	my @ASSEMBLY = ();
	my $asm = $self->fetch('pid:prod_asm');
	if (not defined $asm) { $asm = ''; }

	if ($self->has_variations('inv')) {
		## has variations so we need to index sku specific fields
		foreach my $skuset (@{$self->list_skus()}) {
			my ($sku,$skuref) = @{$skuset};
			if (my $asm = $skuref->{'sku:assembly'}) {
				$asm =~ s/[ ]+//gs;	# remove spaces
				foreach my $skuqty (split(/,/,$asm)) {
					my ($SKU,$QTY) = split(/\*/,$skuqty);
					push @ASSEMBLY, $SKU;
					}
				}
			}
		}
	elsif ( $asm ne '' ) {
		$asm =~ s/[ ]+//gs;	# remove spaces
		foreach my $skuqty (split(/,/,$asm)) {
			my ($SKU,$QTY) = split(/\*/,$skuqty);
			push @ASSEMBLY, $SKU;
			}
		}
	if (scalar(@ASSEMBLY)>0) {
		$prodstore{'assembly_pids'} = \@ASSEMBLY;
		}

	my $grp_children = $self->fetch('zoovy:grp_children');
	if (not defined $grp_children) { $grp_children = ''; }
	if ( $grp_children ne '' ) {		
		my @CHILDREN = ();
		foreach my $pid (split(/,/,$grp_children)) {
			$pid =~ s/[^A-Z0-9\-\_]+//gs;
			push @CHILDREN, $pid;
			}
		$prodstore{'child_pids'} = \@CHILDREN;
		}

	my @MARKETPLACES = ();
	foreach my $set (@ZOOVY::INTEGRATIONS) {
		next if ((not defined $set->{'attr'}) || ($set->{'attr'} eq ''));
		my $value = $self->fetch($set->{'attr'});
		if (not defined $value) {
			push @MARKETPLACES, "$set->{'dst'}_null";
			}
		elsif ($value) {
			push @MARKETPLACES, "$set->{'dst'}_on";
			}
		else {
			push @MARKETPLACES, "$set->{'dst'}_off";
			}
		}
	$prodstore{'marketplaces'} = \@MARKETPLACES;

	foreach my $sku (keys %STORE_SKUS) {
		next if (scalar(keys %{$STORE_SKUS{$sku}})<=2);	# don't index things which don't have sku specific fields
		push @ES_PAYLOADS, {
			'type'=>'sku',
			'id'=>"$sku",
			'parent'=>$PID,
			'source'=>$STORE_SKUS{$sku}	# was 'data'=> in elastic 0.xx
			};
		}

	return(\@ES_PAYLOADS);
	}






##
##
##
sub claim {
	my ($self,$CLAIM) = @_;

	if ((defined $CLAIM) && ($CLAIM>0)) {
		$self->{'CLAIM'} = int($CLAIM);	## incomplete reference 
#		if ((defined $self->{'CLAIM'}) && ($self->{'CLAIM'}>0)) {
#			$self->{'%data'}->{'zoovy:inv_enable'} |= 1024; 	# it's a claiM!
#			}

		require EXTERNAL;
		my $incref = &EXTERNAL::fetchexternal_full($self->username(),$CLAIM);
		delete $incref->{'CHANNEL'};
		delete $incref->{'ID'};
		delete $incref->{'DATA'};
		delete $incref->{'USERNAME'};
		delete $incref->{'MID'};

		$self->{'%INCOMPLETE'} = $incref;
		}

	if (not defined $self->{'CLAIM'}) { return(undef); }
	return(int($self->{'CLAIM'}));
	}

##
## returns an array of arrayrefs of properties which a claim sets inside stuff
##		[
##			[ 'claim', #### ],
##			[ 'mkt' , 'ebay' ],
##		]
sub claim_item_properties {
	my ($self) = @_;

	my @properties = ();
	# $self->{'%data'}->{'zoovy:marketid'} = $incref->{'MKT_LISTINGID'};
	push @properties, [ 'claim',  $self->{'CLAIM'} ];
	# $self->{'%data'}->{'zoovy:marketuser'} = $incref->{'BUYER_USERID'};
	push @properties, [ 'mktuser',  $self->{'%INCOMPLETE'}->{'BUYER_USERID'} ];
	# if ($incref->{'MKT_TRANSACTIONID'}>0) { 
	#	$self->{'zoovy:marketid'} .= '-'.$incref->{'MKT_TRANSACTIONID'}; 
	#	}
	if ($self->{'%INCOMPLETE'}->{'MKT_TRANSACTIONID'}==0) { 
		push @properties, [ 'mktid',  $self->{'%INCOMPLETE'}->{'MKT_LISTINGID'} ];
		}
	else {
		push @properties, [ 'mktid', $self->{'%INCOMPLETE'}->{'MKT_LISTINGID'}.'-'.$self->{'%INCOMPLETE'}->{'MKT_TRANSACTIONID'} ];
		}
	#$self->{'%data'}->{'zoovy:marketurl'} = &EXTERNAL::linkto($incref);
	#if ($incref->{'MKT'} eq 'ebay') {
	#	$self->{'%data'}->{'zoovy:marketurl'} = 'http://cgi.ebay.com/aw-cgi/eBayISAPI.dll?ViewItem&item='.$incref->{'MKT_LISTINGID'};
	#	}
	if ($self->{'%INCOMPLETE'}->{'MKT'} eq 'ebay') {
		push @properties, [ 'mkturl',  'http://cgi.ebay.com/aw-cgi/eBayISAPI.dll?ViewItem&item='.$self->{'%INCOMPLETE'}->{'MKT_LISTINGID'} ];
		}
	#$self->{'%data'}->{'zoovy:market'} = $incref->{'MKT'};
	push @properties, [ 'mkt',  $self->{'%INCOMPLETE'}->{'MKT'} ];
	#$self->{'%data'}->{'zoovy:quantity'} = $incref->{'QTY'};
	push @properties, [ 'claim_qty',  $self->{'%INCOMPLETE'}->{'QTY'} ];
	#$self->{'%data'}->{'zoovy:base_price'} = $incref->{'PRICE'};
	push @properties, [ 'claim_price',  $self->{'%INCOMPLETE'}->{'PRICE'} ];
	#if ($incref->{'PROD_NAME'} ne '') {
	#	$self->{'%data'}->{'zoovy:prod_name'} = $incref->{'PROD_NAME'};
	#	}
	if ($self->{'%INCOMPLETE'}->{'PROD_NAME'} ne '') {
		push @properties, [ 'prod_name',  $self->{'%INCOMPLETE'}->{'PROD_NAME'} ];
		}
	return(\@properties);
	}


##
## creates a new product class
##
## new->($USERNAME,$PID,%options)
##		'%prodref'=>$prodref
##
## code to replace OLD product ref
##
sub new {
	my ($class, $USERNAME, $PID, %options) = @_;
	# print STDERR Carp::cluck("PRODUCT $USERNAME $PID\n");

	my $self = {};
	bless $self, 'PRODUCT';

	$self->{'*LU'} = $options{'*LU'};	# alternatively pass $LUSRE object as USERNAME
	if (ref($USERNAME) eq 'LUSER') { 
		$self->{'*LU'} = $USERNAME; 
		$USERNAME = $self->lu()->username();
		}

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	if ($MID<=0) { return undef; }

	$self->{'_tied'} = 0;
	$self->{'USERNAME'} = $USERNAME;
	if (defined $options{'SCHEDULE'}) {
		$self->{'SCHEDULE'} = $options{'SCHEDULE'};
		}
	#$self->{'STID'} = $STID;
	#($self->{'PID'},$self->{'CLAIM'},$self->{'INV_OPTS'},$self->{'NON_OPTS'},$self->{'VIRTUAL'}) = &stid_to_pid($STID);

	if (index($PID,':')>=0) { 
		warn "REQUEST PRODUCT-> $USERNAME SKU:$PID (should have no :) ".join("|",caller(1))."\n";
		($PID) = &PRODUCT::stid_to_pid($PID);
		}
	$self->{'PID'} = $PID;

	## note: even if it's a claim, we still load the product (to get stuff like taxable, etc.)
	if (defined $options{'%prodref'}) {
		# $self->{'_ORIGIN'} = 'REFERENCE %prodref - '.join("|",caller(1));
		$self->{'%data'} = $options{'%prodref'};
		}
	else {
		my $ID = undef;
		my $DATA = undef;
		my $PROD_IS = undef;
		my $CREATED_GMT = undef;
		my $MODIFIED_GMT = undef;

		## memcaching layer.
		# my ($memd) = &ZOOVY::getMemd($USERNAME);
		my $memd = undef;
		if ((not defined $DATA) && (defined $memd)) {
			($DATA) = $memd->get(uc("$USERNAME:pid-$PID"));
			}
	
		if (not defined $DATA) {
			my $pdbh 	 = &DBINFO::db_user_connect($USERNAME);
			my $TB = &ZOOVY::resolve_product_tb($USERNAME);
			my $pstmt = "select ID,DATA,PROD_IS,CREATED_GMT,TS from $TB where MID=".$pdbh->quote($MID)." and PRODUCT=".$pdbh->quote($PID);
			# print STDERR $pstmt."\n";
			if (($MID>0) && ($TB ne '')) {
				#print STDERR $pstmt."\n";
				($ID,$DATA,$PROD_IS,$CREATED_GMT,$MODIFIED_GMT) = $pdbh->selectrow_array($pstmt);
				}

			if ((not defined $DATA) || ($DATA eq '')) {
				$DATA = undef;
				}
			elsif (length($DATA)>1000000) { 
				# this will stop people from doing stupid HTML tricks,
				# or at least stop those stupid tricks from taking down our
				# our system .. so max product length is 1mb
				$DATA = "---\nzoovy:prod_name: Product Corrupt - exceeds 1mb\n";
				}
			elsif (substr($DATA,0,3) ne "---") {
				## non YAML backward compat. mode
				if (utf8::is_utf8($DATA) eq '') {
					$DATA = Encode::decode("utf8",$DATA);
					utf8::decode($DATA);
					}
				my $ref = &ZOOVY::attrib_handler_ref($DATA);
				$DATA = YAML::Syck::Dump($ref);
				}

			&DBINFO::db_user_close();
			}

		#$ZOOVY::GLOBAL_PRODUCTUSER = $USERNAME;
		#$ZOOVY::GLOBAL_PRODUCTID = $PID;
		#$ZOOVY::GLOBAL_PRODUCTDATA = $DATA;
		#$ZOOVY::GLOBAL_PRODUCTTS = undef;

		my $prodref = undef;
		if (defined $DATA) {
			$prodref = YAML::Syck::Load($DATA);
			my $PROD_IS = int($prodref->{'zoovy:prod_is'});
			my @TAGS = ();
			foreach my $isref (@ZOOVY::PROD_IS) {
				# print "$PROD_IS $isref->{'bit'}\n";
				if (($PROD_IS & (1 << int($isref->{'bit'}))) > 0) {
					$prodref->{ $isref->{'attr'} } = 1;
					push @TAGS, $isref->{'tag'};
					}
				}

			if (not defined $ID) {}		
			elsif ($ID>0) {
				$prodref->{'db:id'} = $ID;
				$prodref->{'zoovy:prod_is_tags'} = join(',',@TAGS);
				$prodref->{'zoovy:prod_created_gmt'} = $CREATED_GMT;
				$prodref->{'zoovy:prod_modified_gmt'} = $MODIFIED_GMT;
				}
			# use Data::Dumper; print Dumper($prodref,\@TAGS); die();

			# &ZOOVY::apply_magic_to_productref($USERNAME,$prodref);
			## as of 2012/7/03 - all products are prod_rev=3
			$prodref->{'zoovy:prod_rev'} = 3;
			}

		#if (defined $prodref->{'froogle:ts'}) {
		#	if (not defined $prodref->{'gbase:ts'}) { $prodref->{'gbase:ts'} = $prodref->{'froogle:ts'}; }
		#	delete $prodref->{'froogle:ts'};
		#	}
		#return($prodref);
		$self->{'%data'} = $prodref;
		}

	if (defined $self->{'%data'}) {
		if (defined $self->{'%data'}->{'zoovy:html'}) {
			delete  $self->{'%data'}->{'zoovy:html'};
			}
		}

	if ((defined $options{'CLAIM'}) && ($options{'CLAIM'}>0)) {
		$self->claim( $options{'CLAIM'} );
		}

	if (defined $options{'readonly'}) {
		## turns on enhancements that prevent computing values for saving etc. this is a contract, you will NOT
		## be able to call save if readonly is turned on.
		$self->{'_readonly'}++;
		}

	if (defined $options{'tmp'}) {
		if ((not defined $self->{'PID'}) || ($self->{'PID'} eq '')) { $self->{'PID'} = '*TMP'; }
		$self->{'_tmp'}++;
		}

	if (defined $self->{'%data'}) {
		## yay, it already exists.

		if (defined $self->{'%data'}->{'zoovy:prod_asm'}) {
			## upgrade 'zoovy:prod_asm' to sku:assembly pid:assembly
			if ($self->has_variations('inv')) {
				foreach my $skuset (@{$self->list_skus()}) {
					my ($sku,$skuref) = @{$skuset};
					$skuref->{"sku:assembly"} = $self->{'%data'}->{'zoovy:prod_asm'};
					}
				}
			else {
				$self->{'%data'}->{"pid:assembly"} = $self->{'%data'}->{'zoovy:prod_asm'};
				}
			delete $self->{'%data'}->{'zoovy:prod_asm'};
			}

		if (defined $self->{'%data'}->{'%SKU'}) {
			## this specifically fixes a case where sku:price is blank (for cubworld)
			foreach my $sku (keys %{$self->{'%data'}->{'%SKU'}}) {
				if ((defined $self->{'%data'}->{'%SKU'}->{$sku}->{'sku:price'}) && ($self->{'%data'}->{'%SKU'}->{$sku}->{'sku:price'} eq '')) {
					delete $self->{'%data'}->{'%SKU'}->{$sku}->{'sku:price'};
					}
				}
			}

		}
	elsif ($options{'create'}) {
		## we're creating a new product
		if (not defined $self->{'@UPDATES'}) {
			$self->{'@UPDATES'} = [];
			}
		push @{$self->{'@UPDATES'}}, [ '', 'CREATED' ];
		}
	else {
		## does not exist, return undef!
		$self = undef; 
		}

	return($self);
	}



sub pid { return(uc($_[0]->{'PID'})); }
sub username { return(uc($_[0]->{'USERNAME'})); }
sub lu { return($_[0]->{'*LU'}); }
sub modified_gmt { return($_[0]->{'%data'}->{'zoovy:prod_modified_gmt'}); }
sub grp_type { return($_[0]->{'%data'}->{'zoovy:grp_type'}); }
sub grp_parent { return($_[0]->{'%data'}->{'zoovy:grp_parent'}); }
## returns an array of grp_children pids
sub grp_children {  return(split(/,/,$_[0]->{'%data'}->{'zoovy:grp_children'})); }
sub folder {  
	my ($self,$folder) = @_;
	if (defined $folder) { 
		if (substr($folder,0,1) ne '/') { $folder = "/$folder"; }
		$folder = substr($folder,0,100); 	## truncate length to 100
		$folder =~ s/[\s]+/_/gs;	# multiple spaces become _
		$self->{'%data'}->{'zoovy:prod_folder'} = $folder; 
		}
	return($self->{'%data'}->{'zoovy:prod_folder'}); 
	}

## returns the best matching thumbnail for the product/sku
sub thumbnail { 
	my ($self,$sku) = @_;

	my $img = undef;
	if ((defined $sku) && ($sku ne $self->pid())) {
		if (not defined $img) { $img = $self->{'%data'}->{'%SKU'}->{$sku}->{'zoovy:prod_image0'}; }
		if ((defined $img) && ($img eq '')) { $img = undef; }
		if (not defined $img) { $img = $self->{'%data'}->{'%SKU'}->{$sku}->{'zoovy:prod_thumb'}; }
		if ((defined $img) && ($img eq '')) { $img = undef; }
		if (not defined $img) { $img = $self->{'%data'}->{'%SKU'}->{$sku}->{'zoovy:prod_image1'}; }
		if ((defined $img) && ($img eq '')) { $img = undef; }
		}
	if (not defined $img) { $img = $self->{'%data'}->{'zoovy:prod_image0'}; }
	if ((defined $img) && ($img eq '')) { $img = undef; }
	if (not defined $img) { $img = $self->{'%data'}->{'zoovy:prod_thumb'}; }
	if ((defined $img) && ($img eq '')) { $img = undef; }
	if (not defined $img) { $img = $self->{'%data'}->{'zoovy:prod_image1'}; }
	if ((defined $img) && ($img eq '')) { $img = undef; }
	return($img);
	}

sub dataref { 
	## returns a direct read dataref to %data (don't use this)
	return($_[0]->{'%data'}); 
	}

sub prodref {
	my ($self) = @_;
	tie my %x, 'PRODUCT', $self;
	return(\%x);
	}


##
## returns the public_url for a product
##
sub public_url {
	my ($self, %options) = @_;

	if (not defined $options{'style'}) { $options{'style'} = 'vstore'; }
	
	if ($options{'style'} eq 'app') {
		my $origin = $options{'origin'} || 'unknown';
		my $market = $options{'mkt'} || 'xxx';
		my $pid = $self->pid();
		return("?origin=$origin&product=$pid&marketplace=$market");
		}
	elsif ($options{'style'} eq 'vstore') {
		my $uri_name = $self->fetch('zoovy:prod_name');
		if ((defined $self->fetch('zoovy:prod_seo_title')) && ($self->fetch('zoovy:prod_seo_title') ne '')) {
			$uri_name = $self->fetch('zoovy:prod_seo_title');
			}
		if (not defined $uri_name) { 
			$uri_name = $self->pid();
			}
		else {
			$uri_name =~ s/[\"!\&]+//gs;
			$uri_name =~ s/^[\s]+//gos;
			$uri_name =~ s/[\s]+$//gos;
			$uri_name =~ s/[\s]+/\-/gos;
			$uri_name =~ s/[\n\r]+//gos;
			$uri_name =~ s/[^\w\-]+//gos;
			$uri_name = URI::Escape::XS::uri_escape($uri_name); 
			$uri_name = "$uri_name.html";
			}

		my $url = '';
		if ($options{'internal'}) {
			## legacy toxml rendering compatibility with SITE::URLS->product_url 
			## internal links are appended to url/session/product/ so we don't add the /product (whereas domain requires /)
			$url = sprintf('/%s/%s',$self->pid(),$uri_name);
			}
		else {
			$url = sprintf('/product/%s/%s',$self->pid(),$uri_name);
			}
		if (defined $options{'mkt'}) {
			$url = sprintf("%s?meta=%s",$url,$options{'mkt'});
			}
		return($url);
		}


	}


##
## you pass:
##		price=>1.00
##	you get:
##
##	options
##		expires		
##
sub signme {
	my ($self,$attribs,%options) = @_;	

	## we use zoovy:digest as the shared key

	my $d = '';
	foreach my $k (sort keys %options) {
		$d .= " $k:$options{$k}";
		}

	my $c = $self->fetch('zoovy:digest').$d;
	foreach my $k (sort keys %{$attribs}) {
		$c .= " $k:$attribs->{$k}";
		}
	
	$d = sprintf("%s1:%s",(($d)?"$d ":""),Digest::MD5::md5_base64($c));
	return($d);
	}

##
## HOW THIS STUFF WORKS:
## perl -e 'use Data::Dumper; use lib "/backend/lib"; use PRODUCT; my ($P) = PRODUCT->new("indianselections","CTRDD_BLACK"); my %options = ("e"=>86400); my $attribs = {"zoovy:schedule"=>"DOTD"};  my $d = $P->signme($attribs,%options); print Dumper($P->is_signature_valid($d,$attribs));'
##
sub is_signature_valid {
	my ($self,$signature,$attribs) = @_;

	my %options = ();
	my ($digestformat,$digestvalue) = (undef,undef);
	foreach my $kv (split(/ /,$signature)) {
		next if ($kv eq '');
		my ($k,$v) = split(/:/,$kv,2);
		if ($k eq '1') {
			($digestformat,$digestvalue) = (1,$v);
			}
		else {
			$options{$k} = $v;
			}
		}

	my $c = $self->fetch('zoovy:digest');
   foreach my $k (sort keys %options) {
      $c .= " $k:$options{$k}";
      }
	foreach my $k (sort keys %{$attribs}) {
		$c .= " $k:$attribs->{$k}";
		}


	my $d = undef;
	if ($digestformat==1) {
		my $d = Digest::MD5::md5_base64($c);
		if ($d eq $digestvalue) { 
			return(\%options); 
			}
		%options = ( '-'=>"Digests don't match $d eq $digestvalue" );
		}
	else {
		%options = ( '-'=>"Unsupported digestformat '$digestformat'" );
		}

	return(\%options);
	}




## generates html for a buyme button
##		prt=>
##		domain=> (if known, will be resolved from prt)
##		profile=> (if known, will be resolved from prt)
sub button_buyme {
	my ($self,$SITE,%options) = @_;


	if (ref($SITE) ne 'SITE') { die("button_buyme requires SITE parameter"); }
	if (not defined $options{'link'}) { $options{'link'} = 0; }

	my $html = '';

	my ($USERNAME) = $self->username();
	my ($PID) = $self->pid();

	my %SPECIAL = ();
	my $SPECIAL = '';
	foreach my $code (@PRODUCT::SPECIAL_CODES) {
		if ((defined $options{$code}) && ($options{$code} ne '')) {
			$SPECIAL{$code} = $options{$code};
			}
		}
	if (scalar(keys %SPECIAL)>0) {
		$SPECIAL{'+++'} = 'CHEESE';
		$SPECIAL{'SKU'} = $PID;
		foreach my $k (sort keys %SPECIAL) { $SPECIAL .= "~$k$SPECIAL{$k}"; }
		$SPECIAL = sprintf("%s\@MD5%s",$SPECIAL,Digest::MD5::md5_hex($SPECIAL));
		$SPECIAL = substr($SPECIAL,1);	# strip leading ~
		$SPECIAL = substr($SPECIAL,index($SPECIAL,'~')); 	# strip up to the next ~
		}

	# print STDERR "PROFILE: $profile\n";	
	my $imgtag = undef;
	my $image = $options{'image'};
	if ($image ne '') {
		$imgtag = "<input type=\"image\" src=\"$image\" border=\"0\" alt=\"Add to Cart\">";
		}

	#else {
	#	#my $wrapper = $SITE->nsref()->{'zoovy:site_wrapper'};
	#	#require TOXML;
	#	#my ($t) = TOXML->new('WRAPPER',$wrapper,USERNAME=>$USERNAME);
	#	#if (defined $t) {
	#	#	my ($cfg) = $t->initConfig($SITE);
	#	#	($imgtag) = TOXML::RENDER::RENDER_SITEBUTTON({button=>'add_to_cart',name=>"add_$PID"},$t,$SITE);
	#	#	}
	#	}
	
	my $domain = $options{'DOMAIN'};
	if ($domain eq '') { $domain = $SITE->cdomain(); }
	if ($domain eq '') { $domain = $SITE->linkable_domain(); }

	my $nonsecure_root = "http://$domain";
	my $prod_name = $self->fetch('zoovy:prod_name');

	# Get the pogs associated with the product
	
	if ($options{'link'}) {
	 	if ($self->has_variations('any')) {
			## link to product, since we have options
			$html .= qq~<a href="$nonsecure_root/product/$PID">~;
			}
		else {
			## link to cart, since w have NO options
			$html .= qq~<a href="$nonsecure_root/cart.cgis?product_id:$PID=1&add=yes">~;
			}

		if ($imgtag eq '') { 
			$html .= "Add To Cart";
			}
		elsif ($imgtag =~ /^<input/) { 
			$imgtag =~ s/^<input/<img/s;
			$html .= "$imgtag\n"; 
			}
		else { 
			$html .= "$nonsecure_root/product/$PID";
			}
		$html .= "</a>";
		}
	else {
		## 
		## NEW FORMAT OPTIONS
		##
		$html .= "<form target=\"_blank\" action=\"$nonsecure_root/cart.cgis\" method=\"get\">\n";
		$html .= "<!-- CREATED BY ZOOVY BUY ME BUTTON GENERATOR ".&ZTOOLKIT::pretty_date(time(),1)." -->\n";
  		$html .= "<input type=\"hidden\" name=\"product_id:$PID\" value=\"1\">\n";
		$html .= "<input type=\"hidden\" name=\"add\" value=\"yes\">\n";
		if ($self->has_variations('any')) {
			my ($pogs2) = $self->pogs();
			$html .= &POGS::struct_to_html($self,undef,0+2)."\n";
			}
		elsif ($SPECIAL ne '') {
			$html .= "<input type=\"hidden\" name=\"special\" value=\"$SPECIAL\">\n";
			}
		#if ($PRODREF->{'zoovy:pogs'}) {
		#	my @pogs = &POGS::text_to_struct($USERNAME,$PRODREF->{'zoovy:pogs'},1);
		#	$html .= &POGS::struct_to_html($USERNAME,\@pogs,undef,0+2,$PID)."\n";
		#	}
		if ($imgtag) { 
			$html .= "$imgtag\n"; 
			}
		else { 
			$html .= "<input type=\"submit\" value=\"Add to Cart\">\n"; 
			}
		$html .= "</form>";
		}

	return($html);
	}



##
## 
##
sub group_into_hashref {
	my ($USERNAME,$pidsarray) = @_;

	my %ref = ();
	$USERNAME = uc($USERNAME);

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	if ($MID==-1) { return({}); }

	my $pdbh 	 = &DBINFO::db_user_connect($USERNAME);

	# my $memd = &ZOOVY::getMemd($USERNAME);
	my $memd = undef;

	my $t = time();

	my $mcref = {};
	my @mckeys = ();
	if (defined $memd) {
		foreach my $PID (@{$pidsarray}) { 
			push @mckeys, uc("$USERNAME:pid-$PID"); 
			}
		$mcref = $memd->get_multi(@mckeys);
		}

	## step 0, separate the products into blocks of 20
	my $count = 0;
	my $prodar = ();
	my @blocks = ();
	foreach my $PID (@{$pidsarray}) {
		$PID = uc($PID);

		my $prodinfo = undef;
		if (defined $mcref->{ uc("$USERNAME:pid-$PID") }) {	
			## woot found in memcache.
			print STDERR "!!!!!!!!!!!! $USERNAME FOUND $PID in multi-get memcache!\n";
			$ref{$PID} = PRODUCT->new($USERNAME,$PID,'%prodref'=>$mcref->{ "$USERNAME:pid-$PID" });
    		}

		if (not defined $prodinfo) {
			if ($count++>10) {
				push @blocks, $prodar;
				$prodar = ();
				$count = 0;
				}
			push @{$prodar}, $PID;
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

		my $TB = &ZOOVY::resolve_product_tb($USERNAME);
	
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

		while ( my ($PID,$DATA,$CREATED_GMT,$MODIFIED_GMT,$PROD_IS,$FOLDER) = $sth->fetchrow() ) {

			my $dataref = undef;
			if (substr($DATA,0,3) eq '---') {
				## detects YAML (way faster than xmlish)
				$dataref = YAML::Syck::Load($DATA);
				}

			## handle PROD_IS code.
			my @TAGS = ();
			foreach my $isref (@ZOOVY::PROD_IS) {
				# print "$PROD_IS $isref->{'bit'}\n";
				if (($PROD_IS & (1 << int($isref->{'bit'}))) > 0) {
					$dataref->{ $isref->{'attr'} } = 1;
					push @TAGS, $isref->{'tag'};
					}
				}
			$dataref->{'zoovy:prod_is'} = $PROD_IS;
			$dataref->{'zoovy:prod_is_tags'} = join(',',@TAGS);
			$dataref->{'zoovy:prod_created_gmt'} = $CREATED_GMT;
			## 11/18/11 - gkworld was informed 
			$dataref->{'zoovy:prod_modified_gmt'} = $MODIFIED_GMT;
			$dataref->{'zoovy:prod_folder'} = $FOLDER;

			$ref{$PID} = PRODUCT->new($USERNAME,$PID,'%prodref'=>$dataref);


			## if it's not in memcache, then multi-get from database.
			if (defined $memd) {
				$memd->set(uc("$USERNAME:pid-$PID"), $dataref->{$PID} );
				}

			}

		$sth->finish();
		}


	&DBINFO::db_user_close();
	return(\%ref);
	}

##
## helpful compatibility layer function 
##		type: inv, noinv, pinv, asm
##	
## pinv: product inventoriable (not allowed for syndication)
##
sub has_variations {
	my ($self,$type) = @_;

	if (not defined $type) { $type = ''; }
	my $pogsref = $self->{'%data'}->{'@POGS'};
	my $invcount = 0;

	my $has = 0;
	if (not defined $pogsref) {
		$has = undef;
		}
	elsif (ref($pogsref) ne 'ARRAY') {
		## invalid options
		$has = undef;
		}
	elsif (scalar(@{$pogsref})==0) {
		$has = undef;
		}
	elsif (($type eq '') || ($type eq 'any')) {
		$has = scalar(@{$pogsref});
		}
	elsif (($type eq 'noinv') || ($type eq 'inv') || ($type eq 'asm') || ($type eq 'pinv')) {
		$has = 0;
		foreach my $pog2 (@{$pogsref}) {

			if ($type eq 'inv') {
				if ($pog2->{'inv'}>0) { $has++; $invcount++; }
				}
			elsif ($type eq 'noinv') {
				if ($pog2->{'inv'}==0) { $has++; }
				}
			elsif ($type eq 'asm') {
				## how many assembly options do we have 
				## why: certain things ie. syndication don't work with asm --
				## so we need to be able to identify those and filter them.
				if (not defined $pog2->{'@options'}) {
					## this is fine, no @options
					}
				elsif (scalar($pog2->{'@options'})==0) {
					## this is corrupt, who knows.
					}
				else {
					if (not defined $pog2->{'asm'}) {}
					elsif ($pog2->{'asm'} ne '') { $has++; }
					foreach my $opt (@{$pog2->{'@options'}}) {
						if (not defined $opt->{'asm'}) {}
						elsif ($opt->{'asm'} ne '') { $has++; }
						}
					}
				} 
			elsif ($type eq 'pinv') {
				## pinv: product specific (non-sog) inventoriable pogs
				if (($pog2->{'inv'}) && (substr($pog2->{'id'},0,1) eq '#')) {
					$has++;  $invcount++;
					}
				}
			}	# end of foreach loop

		if ($invcount>3) {
			warn "corrupt product (more than 3 inv options)\n";
			$has = -1;
			}
		}
	else {
		## this line should never be reached.
		Carp::cluck("Unknown prodref_has_variations type[$type] passed\n");
		$has = -1;
		}

	return($has);
	}



##
## get/set the schedule associated that will be used for calculations on this product
##
sub schedule {
	if (defined $_[1]) {
		$_[0]->{'SCHEDULE'} = $_[1];
		}
	return($_[0]->{'SCHEDULE'});
	}

##
## takes in a prod_ref, and modifies the base_price based on the username/schedule  it is passed.
##	called from:
##		/backend/lib/FLOW/RENDER.pm
##		/backend/lib/STUFF.pm
##		/httpd/site/product.pl
##
sub wholesale_tweak_product {
	my ($self,$SCHEDULE) = @_;

	## BEGIN WHOLESALE PRICING
	my %results = ();
	my $prodref = $self->prodref();

	if ($SCHEDULE eq '') {
		## there is no schedule set, so we'll use public qty price
		$results{'zoovy:qty_price'} = $prodref->{'zoovy:qty_price'};
		}
 	elsif (defined $prodref->{'zoovy:qtyprice_'.lc($SCHEDULE)}) {
		## load a custom qtyprice for a given schedule.
		$results{'zoovy:qty_price'} = $prodref->{'zoovy:qtyprice_'.lc($SCHEDULE)};
		}
	elsif ($SCHEDULE =~ /^[QM]P/) {
		## the quantity price schedules will default to the public quantity pricing. 
		}
	elsif ($SCHEDULE ne '') {
		## the non-qp schedules ignore quantity pricing.
		delete $results{'zoovy:qty_price'};
		}
	
	if (defined $prodref->{'zoovy:qtymin_'.lc($SCHEDULE)}) {
		## override the minimum quantities
		$results{lc($self->username()).':minqty'} = $prodref->{'zoovy:qtymin_'.lc($SCHEDULE)}; 	## backward compat
		$results{'schedule:minqty'} = $prodref->{'zoovy:qtymin_'.lc($SCHEDULE)};		## forward compat
		}
	if (defined $prodref->{'zoovy:qtyinc_'.lc($SCHEDULE)}) {
		## override the increment quantities
		$results{lc($self->username()).':incqty'} = $prodref->{'zoovy:qtyinc_'.lc($SCHEDULE)}; ## backward compat
		$results{'schedule:incqty'} = $prodref->{'zoovy:qtyinc_'.lc($SCHEDULE)}; ## forward compat
		}

  my $formula = '';
  if ((not defined $prodref->{'zoovy:base_price'}) || ($prodref->{'zoovy:base_price'} eq '')) {
    }
  elsif ((defined $SCHEDULE) && ($SCHEDULE ne '')) {
		
		$formula = $prodref->{'zoovy:schedule_'.lc($SCHEDULE)};		# load formula from product

		require WHOLESALE;
		my ($S) = WHOLESALE::load_schedule($self->username(),$SCHEDULE);

		if ((not defined $formula) || ($formula eq '')) { 
			## use the default formula if we didn't have one in the product.
			if ((defined $S->{'discount_default'}) && ($S->{'discount_default'}>0)) { $formula = $S->{'discount_amount'}; }
			}

		if ((defined $S->{'currency'}) && ($S->{'currency'} ne '')) {
			require ZTOOLKIT::CURRENCY;
			$formula = '';
			$results{'zoovy:schedule_currency'} = $S->{'currency'};
			$results{'zoovy:schedule_price'} = $prodref->{'zoovy:schedule_'.lc($SCHEDULE)};

			$results{'zoovy:base_currency'} = 'USD';
			$results{'zoovy:base_price'} = &ZTOOLKIT::CURRENCY::convert($results{'zoovy:schedule_price'},
				$results{'zoovy:schedule_currency'},
				$results{'zoovy:base_currency'});
			
			}

		## DEPRECATED 8/20/11
		#if (int($S->{'inventory_ignore'})==1) {
		#	## turn on unlimited inventory, and flag this as a "temporary unlimited"
		#	$prodref->{'zoovy:inv_enable'} |= 32 + 64;
		#	};
			
		if ((not defined $formula) || ($formula eq '')) {
			## Don't do shit!
			$results{'zoovy:base_price'} = $prodref->{'zoovy:base_price'};
			}
		elsif ($formula =~ /^[\d\.]+$/) {
		  ## here's a shortcut we can take if it's guaranteed to be a decimal number
		  $results{'zoovy:schedule'} = $SCHEDULE;
		  $results{'zoovy:orig_price'} = $results{'zoovy:base_price'};
		  $results{'zoovy:base_price'} = $formula;
		  }
		elsif ($formula ne '') {	
			require Math::Symbolic;
			$results{'zoovy:base_price'} = $prodref->{'zoovy:base_price'};
			$results{'zoovy:base_cost'} = $prodref->{'zoovy:base_cost'};
		   $results{'zoovy:orig_price'} = $prodref->{'zoovy:base_price'};
			if ((not defined $prodref->{'zoovy:base_cost'}) || ($prodref->{'zoovy:base_cost'} eq '')) { 
            $results{'zoovy:base_cost'} = $prodref->{'zoovy:base_price'}; 
            }
			$results{'zoovy:prod_msrp'} = $prodref->{'zoovy:prod_msrp'};
			if ((not defined $prodref->{'zoovy:prod_msrp'}) || ($prodref->{'zoovy:prod_msrp'} eq '')) { 
			   $results{'zoovy:prod_msrp'} = $prodref->{'zoovy:base_price'}; 
            }
			$results{'zoovy:ship_cost1'} = $prodref->{'zoovy:ship_cost1'};
			if ((not defined $prodref->{'zoovy:ship_cost1'}) || ($prodref->{'zoovy:ship_cost1'} eq '')) {
            $results{'zoovy:ship_cost1'} = 0; 
            }

			$results{'formula'} = $formula;
			my $tree = Math::Symbolic->parse_from_string($formula);         
			if (defined $tree) {
				$tree->implement('COST'=> sprintf("%.2f",$results{'zoovy:base_cost'}) );
				$tree->implement('BASE'=> sprintf("%.2f",$results{'zoovy:base_price'}) );
				$tree->implement('SHIP'=> sprintf("%.2f",$results{'zoovy:ship_cost1'}) );
				$tree->implement('MSRP'=> sprintf("%.2f",$results{'zoovy:prod_msrp'}) );

				my ($sub) = Math::Symbolic::Compiler->compile_to_sub($tree);
				$formula = sprintf("%.2f",$sub->());
				# use Data::Dumper; print STDERR Dumper($tree,$formula);

				$results{'zoovy:schedule'} = $SCHEDULE;
			   $results{'zoovy:base_price'} = $formula;
				}
			}
		}

	## END WHOLESALE PRICING
	return(\%results);
	}




##
##
##
#sub sku {
#	my ($self,$sku) = @_;
#	return($self->{'%SKU'}->{$sku});
#	}

##
## same as ZOOVY::fetch_pogs()
## 	this returns the raw pogs object with no sogs loaded, it's safe for modification and re-saving.
##
sub pogs {
	my ($self) = @_;
	if (not defined $self->{'%data'}) { return undef; } 	# this will usually cause an ise if not handled.

	## but not having @POGS is totally fine especially for products without options, so for those we return []
	if (not defined $self->{'%data'}->{'@POGS'}) { return( [] ); }
	return($self->{'%data'}->{'@POGS'});
	}

## for now this is an alias to ZOOVY::fetch_pogs
## 	unlike ->pogs it will return a blank array when there are no pogs.
## 	this will also resolve global sogs (so we should use this for most non-management functions)
sub fetch_pogs {
	my ($self) = @_; 
	my $pogs2 = $self->pogs();
	if (not defined $pogs2) { $pogs2 = []; }

	foreach my $pog2 (@{$pogs2}) {
		if ($pog2->{'global'}) {
			my ($sogref) = &POGS::load_sogref($self->username(),$pog2->{'id'});
			$pog2->{'@options'}  = $sogref->{'@options'};			
			}
		}

	return($pogs2);
	}


##
## this is use to figure out a default set of options given a product.
##		if a STID is passed, then we'll try and figure it out from that.
##
## 'stid'=>$STID
##	'guess'=>1  (use the first option if no default option is specified)
## 'invalid'=>1  when enabled, if the stid contains an option that it is not available/does not exist - don't error, instead create an 'invalid' option
##	
## returns:
##		[
##			[ 'A0', '00', 'select', '1' ],
##			[ 'A1', '##', 'text', 0 ],
##			[ 0#pogid,1#value,2#type,3#inv,4#reason ]
##		]
##
## if $params{'guess'} is true, then 4#reason can be 'guess' this is *very* dangerous and should be logged.
##		someplace that we had to guess becuase of a fubar data
##
sub suggest_variations {
	my ($self,%params) = @_;

	my @suggestions = ();		#
	if (not $self->has_variations()) {
		## intentional short circuit
		return(\@suggestions);
		}

	my %preset = ();
	## addition so options is defined for both inv and non-inv STIDs
	if ($params{'stid'}) {
		my ($pid,$claim,$invopts,$noinvopts,$virtual) = PRODUCT::stid_to_pid($params{'stid'});
		if (not defined $noinvopts) { $noinvopts = ""; }
		if (not defined $invopts) { $invopts = ""; }
		foreach my $pairs (split(/[:\/]/,"$invopts:$noinvopts")) {
			next if ($pairs eq '');
			$preset{ substr($pairs,0,2) } = substr($pairs,2,2);
			}
		}

	foreach my $pog (@{$self->fetch_pogs()}) {
		next if ($pog->{'type'} eq 'attrib');
		next if ($pog->{'type'} eq 'attribs');

		if ($pog->{'type'} =~ /^(cb|select|imgselect|radio)$/) {
			## some validation code
			if (not defined $pog->{'@options'}) { $pog->{'@options'} = []; }
			}

		my ($v,$reason) = ('','');
		if (not defined $pog->{'@options'}) {
			## no options, it's probably a text field. (we could probably do a bit more validation here)
			$v = '##';  $reason = 'text';
			}
		elsif (defined $preset{ $pog->{'id'} }) {
			## %options already initialized - leave it alone.
			$v = $preset{ $pog->{'id'} };  
			$reason = 'preset';
			if ($pog->{'inv'} == 0) {
				## no need to verify, it's not inventoriable
				}
			elsif (not defined $pog->{'@options'}) {
				# no options, probably not a select list	
				}
			elsif ($pog->{'optional'}) {
				## it's optional, so we can just trust the preset
				}
			else {
				## it's required, so we better verify it
				my $opt = undef;
				foreach my $option (@{$pog->{'@options'}}) {
					if ($option->{'v'} eq $v) { $opt = $option; }
					}
				if (defined $opt) {
					## yay, we found an option!
					}
				else {
					$reason = 'invalid';
					}
				}
			}
		else {
			## has options, then it's basically a select
			my $opt = undef;  

			## use the selected value if one is available.
			if ((defined $pog->{'selected'}) && ($pog->{'selected'} ne '')) { 
				foreach my $option (@{$pog->{'@options'}}) {
					if ($option->{'v'} eq $pog->{'selected'}) { $opt = $option; }
					}
				}
	
			## default to the first element in the list.
			if (defined $opt) { 
				$v = $opt->{'v'}; $reason = 'default';
				}
			elsif (($pog->{'inv'} == 0) && ($pog->{'optional'})) {
				$v = '';	$reason = 'optional'; 
				}
			elsif ($params{'guess'}) {
				$v = $pog->{'@options'}->[0]->{'v'};  $reason = 'guess';
				}
			else {
				$v = "**"; $reason = 'error';		# inv, error - pass params 'guess'=>1
				}

			}

		push @suggestions, [ $pog->{'id'}, $v, $pog->{'type'}, $pog->{'inv'}, $reason ];
		}

	return(\@suggestions);
	}





## don't save things to this and expect it to work.
sub skuref {
	my ($self, $sku) = @_;
	
	if (defined $self->{'%data'}->{'%SKU'}->{'.'}) {
		## this shouldn't exist, it was a bug - it should have been removed. but this will clear it.
		delete $self->{'%data'}->{'%SKU'}->{'.'};
		}

	if (not defined $self->{'%data'}->{'%SKU'}->{$sku}) {
		if (lc($self->username()) ne 'stateofnine') {
			warn "$sku has no skuref ".Carp::cluck($self->username());
			}
		}

	return( $self->{'%data'}->{'%SKU'}->{$sku} );
	}


##
## this returns a hash of SKU's, with pointers to individual properties.
##	'verify'
## 
sub skus {
	my ($self, %options) = @_;


	if (not defined $self->{'%data'}->{'%SKU'}) {
		return({$self->pid()=>{}});
		}
	elsif (int($options{'verify'})==0) {
		## default
		return($self->{'%data'}->{'%SKU'});
		}
	elsif (int($options{'verify'})==1) {
		foreach my $set (@{$self->list_skus(%options)}) {
			if (not defined $self->{'%data'}->{'%SKU'}->{ $set->[0] }) {
				## %SKU key didn't exist, just reference source hash
				$self->{'%data'}->{'%SKU'}->{ $set->[0] } = $set->[1];
				}
			else {
				## copy keys over existing keys
				foreach my $k ( keys %{$set->[1]}) {
					$self->{'%data'}->{'%SKU'}->{ $set->[0] }->{$k} = $set->[1]->{$k};
					}
				}
			}
		return($self->{'%data'}->{'%SKU'});
		}
	}
 

##
## returns empty array if no skus's!
## returns an arrayref of
##		[ sku1, skuref1 ],
##		[ sku2, skuref2 ]
##
sub list_skus {
	my ($self, %options) = @_;

	my @SKUS = ();

	if (not defined $options{'verify'}) { $options{'verify'} = 0; }
	my $verify = int($options{'verify'});
	
	if (not $verify) {
		## this is the fastest method, it assumes the product record is already correct.
		if (defined $self->{'%data'}->{'%SKU'}->{'.'}) {
			## can probably be removed in 2015 -- was a hack that got removed.
			delete $self->{'%data'}->{'%SKU'}->{'.'};
			}

		foreach my $sku (sort keys %{$self->{'%data'}->{'%SKU'}}) {
			next if ($sku eq ':');
			next if ($sku eq '');
			push @SKUS, [ $sku, $self->{'%data'}->{'%SKU'}->{$sku} ];
			}
		}
	else {
		## this interates through the options to create the SKU records
		use Data::Dumper;
		my %ar = ();
		$ar{$self->pid()} = [];
	
		my $pogsref = $self->pogs();
		if (not defined $pogsref) { 
			## this prevents an ISE, but .. well maybe it shouldn't. really the module that called this should have done
			## more with the product, maybe calling a validate or something.
			warn "P->pogs() returned undef (ISE?) for pid:".$self->pid()." -- i'll prented there are no pogs, but you should check into this\n";
			$pogsref = [];
			}

		my $invcount = 0;
		foreach my $pog (@{$pogsref}) {
		#	print Dumper($pog);
			next if ($pog->{'type'} eq 'attribs');
			next if (int($pog->{'inv'}&1)==0);		# inv can be +2 with assembles
			$invcount++;
			next if ($invcount>3);

			my %new = ();
			foreach my $option (@{$pog->{'@options'}}) {
				foreach my $sku (keys %ar) {
					## nasty line, produces:
					##	 if brief ($OPT&2)	PRODUCT:IDVV:IDVV => 'IDprompt: VVprompt / IDprompt: VVprompt'
					##  if not brief			PRODUCT:IDVV:IDVV => 'VVprompt / VVprompt'
					my $buildsku = sprintf("%s:%s%s",$sku,$pog->{'id'},$option->{'v'});
					$new{ $buildsku } = [];
					foreach my $set (@{$ar{$sku}}) { 
						push @{$new{$buildsku}}, $set;
						}
					push @{ $new{$buildsku} }, [ $pog->{'prompt'}, $option->{'prompt'} ];
					}
				}
			%ar = %new;
			}

		## 10,000 options should be more than anybody needs! (note -it's not using "keys" below)
		if (scalar(keys %ar)>20000) {
			%ar = ();
			}

		foreach my $sku (sort keys %ar) {
			my $ref = $self->{'%data'}->{'%SKU'}->{$sku};
			if (not defined $ref) {
				$ref = $self->{'%data'}->{'%SKU'}->{$sku} = {};
				}

			my $mini = '';
			my $maxi = '';
			foreach my $set (@{$ar{$sku}}) {
				$mini .= sprintf("%s%s",(($mini eq '')?'':" / "), $set->[1]);
				$maxi .= sprintf("%s%s: %s",(($maxi eq '')?'':" / "), $set->[0],$set->[1]);
				}
			$ref->{'zoovy:sku_pogdesc'} = $mini;
			$ref->{'zoovy:sku_pogdetail'} = $maxi;
			
			push @SKUS, [ $sku, $ref ];
			}

		}

	return(\@SKUS);
	}





##
##	sub FETCH
## 
## pass no parameters and this returns an arrayref of attributes
## pass in attribute and this returns the value
##
sub fetch {
	my ($self,$attrib) = @_;

	if (not defined $attrib) {
		my @AR = keys %{$self->{'%data'}};
		for (my $x = scalar(@AR); $x>0; --$x) { $AR[$x] =~ s/\:/\./g; }
		return(\@AR);
		}

	$attrib = lc($attrib);
	if (index($attrib,'.')>=0) { $attrib =~ s/\./\:/; }
	return($self->{'%data'}->{$attrib});
	}

##
## sets a value at the product level
##
sub store {
	my ($self,$attrib,$value) = @_;

	if (not defined $self->{'@UPDATES'}) {
		$self->{'@UPDATES'} = [];
		}

	my $changed = 0;
	if (not defined $value) {
		## deleting a key
		if (defined $self->{'%data'}->{$attrib}) {
			$changed++;
			delete $self->{'%data'}->{$attrib};
			push @{$self->{'@UPDATES'}}, [ '', 'DELETE', $attrib ]; 
			}
		}
	## if we get here, we're setting a key
	elsif (not defined $self->{'%data'}->{$attrib}) {
		$changed++;
		$self->{'%data'}->{$attrib} = $value;
		push @{$self->{'@UPDATES'}}, [ '', 'INIT', $attrib ]; 
		}
	elsif ($self->{'%data'}->{$attrib} eq $value) {
		## no change!
		}
	else {
		$changed++;
		push @{$self->{'@UPDATES'}}, [ '', 'CHANGED', $attrib, $self->{'%data'}->{$attrib}, $value ];
		$self->{'%data'}->{$attrib} = $value;
		}

	## note: at this point @UPDATES has been set if necessary.
	return($changed);
	}


##
## goes through seo:xxx fields and returns a hashref of keys and values.
##
sub seo_tags {
	my ($self) = @_;

	my %SEO_TAGS = ();
	my $dataref = $self->{'%data'};
	foreach my $k (keys %{$dataref}) {
		if ($k =~ /^seo\:(.*?)$/) { 
			$SEO_TAGS{$k} = $dataref->{$k};
			}
		## later maybe we can add user:seo_xyz
		}	
	return(\%SEO_TAGS);
	}


##
##
##
sub store_pogs {
	my ($self,$pogsref) = @_;

	my $LU = $self->lu();
	my $USERNAME = $self->username();

	my $dataref = $self->{'%data'};


	## make sure everything is upgraded (even if internal versions are mismatched)
	my @POGS2 = ();
	foreach my $pog (@{$pogsref}) {
		if (not defined $pog->{'v'}) { $pog->{'v'} = 1; } # implicitly set version 1
		if ($pog->{'v'} == 1) {
			## upgrade this pogs
			($pog) = @{&POGS::upgrade_struct([$pog])};
			}
		push @POGS2, $pog;
		}

	$dataref->{'@POGS'} = \@POGS2;
	if (not defined $self->{'@UPDATES'}) {
		$self->{'@UPDATES'} = [];
		}

	my $PID = $self->pid();
	push @{$self->{'@UPDATES'}}, [ $PID, 'CHANGED', '@POGS' ];
	## we should probably cleanup inventory records here.
	if (defined $LU) {
		$LU->log("PRODEDIT.OPTIONS.SAVE","PID:$PID options updated","INFO");
		}
	else {
		&ZOOVY::log($USERNAME,undef,"PRODEDIT.OPTIONS.SAVE","PID:$PID options updated","INFO");
		}
	return();
	}




sub inv_qty {
	my ($self, $sku, $property) = @_;
	
	$sku = uc($sku);
	if (not defined $self->{'%INVSUMMARY'}) {
		my ($INV2) = INVENTORY2->new($self->username());
		$self->{'%INVSUMMARY'} = $INV2->summary('PID'=>$self->pid());

		## print STDERR "SUMMARY: ".Dumper($self->{'%INVSUMMARY'})."\n";

		my %SUMMARY = ( );
		foreach my $SKU (keys %{$self->{'%INVSUMMARY'}}) {
			$SUMMARY{'AVAILABLE'} += $self->{'%INVSUMMARY'}->{$SKU}->{'AVAILABLE'};
			$SUMMARY{'MARKETS'} = 0;
			}
		$self->{'%INVSUMMARY'}->{'*'} = \%SUMMARY;
		}

	if (not defined $self->{'%INVSUMMARY'}->{$sku}->{$property}) {
		warn "MISSING INVSUMMARY PROPERTY $property on sku:$sku\n";
		}

	return($self->{'%INVSUMMARY'}->{$sku}->{$property});
	}



##
## note: does the same thing apply_options used to do.
##
sub skufetch {
	my ($self, $sku, $attrib) = @_;

	if (index($sku,':')<0) {
		## hmm.. we're working with a product (as a sku) so that's a bit wonky. we'll call store instead
		if ($attrib =~ /^sku\:(price|weight|title|variation_detail)$/o) { 
			if ($attrib eq 'sku:price') { $attrib = 'zoovy:base_price'; }
			elsif ($attrib eq 'sku:weight') { $attrib = 'zoovy:base_weight'; }
			elsif ($attrib eq 'sku:title') { $attrib = 'zoovy:prod_name'; }
			elsif ($attrib eq 'sku:variation_detail') { $attrib = ''; }	 ## zoovy:pogs_desc
			}
		return($self->fetch($attrib));
		}
	elsif ($attrib =~ /^(oldsku\:price|oldsku\:weight|oldsku\:title|sku\:variation_detail)$/) {
		## oldsku:price oldsku:weight sku:prod_name sku:detail

		require ZSHIP;
		my $weight = &ZSHIP::smart_weight($self->fetch('zoovy:base_weight'));
		my $price = sprintf("%.2f",$self->fetch('zoovy:base_price'));
		my ($pid,$claim,$invopts,$noinvopts,$virtual) = PRODUCT::stid_to_pid($sku);
		my @sogidval = split(/:/,$invopts);
		my @variation_details = ();

		if ($self->schedule()) {
			## if we have a schedule set for the product, use that for the base price
			my $results = $self->wholesale_tweak_product($self->schedule());
			$price = $results->{'zoovy:base_price'};
			}

		foreach my $kv (@sogidval) {
			my $id = substr($kv,0,2); 
			my $val = substr($kv,2,4);
			# print STDERR  "OPT: $kv - id: $id val: $val\n";
			my $found = 0;
			foreach my $pog (@{$self->fetch_pogs()}) {
				next if ($pog->{'id'} ne $id);
				next if ($pog->{'type'} eq 'attribs');	## type "attribs" is used in FINDERS and has no properties.
				next if ($pog->{'type'} eq 'assembly');	## type "attribs" is used in FINDERS and has no properties.

				foreach my $opt (@{$pog->{'@options'}}) {
					next if ($opt->{'v'} ne $val);
					$found++;
					# if (($pog->{'inv'} & 2) && ($opt->{'asm'} ne '')) { &tweak_asm_option($pog,$opt); }
					next if ($opt->{'skip'});	## wtf is a "skip" option?

					if ((defined $opt->{'p'}) && ($opt->{'p'} ne '')) {
						## if merchant didn't use a '+', '-' or '=' default to '='
						if(substr($opt->{'p'},0,1) ne '+' && substr($opt->{'p'},0,1) ne '-') {
							$opt->{'p'} = "=".$opt->{'p'};
							}
						my ($diff) = &ZOOVY::calc_modifier($price,$opt->{'p'},1);
						$price = $diff; 
						}
					if ((defined $opt->{'w'}) && ($opt->{'w'} ne '')) { 
						## note: this will NOT work with % or -
						my ($diff) = &ZOOVY::calc_modifier(
							$weight,
							&ZSHIP::smart_weight($opt->{'w'},1),1);
						$weight = $diff;
						}
	
					push @variation_details, $pog->{'prompt'}.': '.$opt->{'prompt'};
					#$result{'zoovy:prod_name'} .= "\n".$pog->{'prompt'}.': '.$opt->{'prompt'};
					#$result{'zoovy:pogs_desc'} .= "\n".$pog->{'prompt'}.': '.$opt->{'prompt'};
					}
				}
			}

		if ($attrib eq 'oldsku:price') { return($price); }
		elsif ($attrib eq 'oldsku:weight') { return($weight); }
		elsif ($attrib eq 'oldsku:title') { 
			return( sprintf("%s %s",$self->fetch('zoovy:prod_name'),join(" ",@variation_details))  ); 
			}
		## variation_detail (previously pogs_desc) can be used by marketplaces (SYNDICATION's) to display option specific data
		## appended to their own product title. e.g. gbase:prod_name
		elsif ($attrib eq 'sku:variation_detail') { return(join("\n",@variation_details)); }
		else { return(undef); }
		}
	elsif (not defined $self->{'%data'}->{'%SKU'}->{$sku}) {
		warn "sku:$sku does not exist";
		return(undef);
		}
	else {
		## try and get the value from the sku itself
		## NOTE: eventually we might want to change skufetch so it looks at flexedit and goes to product record when
		## 		appropriate
		my $result = $self->{'%data'}->{'%SKU'}->{$sku}->{$attrib};

		## NOTE: don't remove this, shit will break, make sure all products have been upgraded to sku:price, etc. first
		if ((defined $result) && ($attrib eq 'sku:title') && ($result eq '')) {
			## auto-gnenerate sku:title
			$result = $self->fetch('oldsku:title');
			}
		elsif (defined $result) {}
		elsif ($attrib =~ /sku:(price|weight|title)/) { $result = $self->{'%data'}->{'%SKU'}->{$sku}->{$attrib} = $self->skufetch($sku,"old$attrib"); }
	
		# print "$sku $attrib=$result\n";
		return($result);
		}	
	}


##
sub pricetags {
	my ($self, $sku) = @_;
	my %TAGS = ();
	my $skuref = $self->{'%data'}->{'%SKU'}->{$sku};
	foreach my $k (keys %{$skuref}) {
		if ($k =~ /^sku\:pricetags.(.*?)$/) {
			$TAGS{$1} = $skuref->{$k};
			}
		}
	return(\%TAGS);
	}



##
## 
##
sub skustore {
	my ($self, $sku, $attrib, $value) = @_;

#	my ($baseattrib,$subtag) = undef;	
#	if (index($attrib,'.')>0) { ($baseattrib,$subtag) = split(/\./,$subtag); }

	my $changed = 0;
	if (index($sku,':')<0) {
		## hmm.. we're working with a product (as a sku) so that's a bit wonky. we'll call store instead
		$changed = $self->store($attrib,$value);
		}
	elsif (not defined $self->{'%data'}->{'%SKU'}->{$sku}) {
		warn "SKU:$sku does not exist. ignoring update\n";
		$changed = undef;
		}
	elsif (not defined $value) {
		delete $self->{'%data'}->{'%SKU'}->{$sku}->{$value};
		if (defined $self->{'%data'}->{'%SKU'}->{$sku}->{$value}) {
			push @{$self->{'@UPDATES'}}, [ $sku, 'DELETE', $attrib ];
			$changed++;
			}
		}
	elsif (not defined $self->{'%data'}->{'%SKU'}->{$sku}->{$attrib}) {
		$self->{'%data'}->{'%SKU'}->{$sku}->{$attrib} = $value;
		push @{$self->{'@UPDATES'}}, [ '', 'INIT', $attrib ]; 
		}
	elsif ($self->{'%data'}->{'%SKU'}->{$sku}->{$attrib} eq $value) {
		## no change!
		}
	else {
		push @{$self->{'@UPDATES'}}, [ '', 'CHANGED', $attrib, $self->{'%data'}->{'%SKU'}->{$sku}->{$attrib}, $value ];
		$self->{'%data'}->{'%SKU'}->{$sku}->{$attrib} = $value;
		}
	return($changed);
	}



## returns a count for the # of changes (useful in status messages ex: saving # changes)
sub _changes {
	my ($self) = @_; 
   if (not defined $self->{'@UPDATES'}) { return(0); }
   return( scalar(@{$self->{'@UPDATES'}}) );
	}


## makes a product so it will force a save (useful when we've internally updated product structure/indexing)
sub _dirty {
	my ($self) = @_;
   if (not defined $self->{'@UPDATES'}) { $self->{'@UPDATES'} = []; }
	push @{$self->{'@UPDATES'}}, [ '', 'DIRTY', '' ];
	return();
	}

##
##
##
sub save {
	my ($self) = @_;


	## print STDERR Dumper($self);
	if (not defined $self->{'@UPDATES'}) {
		## no updates! woot.
		return();
		}
	elsif ( scalar(@{$self->{'@UPDATES'}})==0) {
		## no updates.
		return();
		}
	elsif ($self->{'_tmp'}) {
		return();
		}

	my $USERNAME = $self->username();
	my $PREF = $self->{'%data'};

	## if zoovy:prod_folder is set, use that as the category
	my @EVENTS = ();
	my $CATEGORY = '';
	if (defined $PREF->{'zoovy:prod_folder'}) {
		$CATEGORY = $PREF->{'zoovy:prod_folder'};
		}

	## future - delete zoovy:redir_url (legacy api2 flag not used)

	my $PID = uc($self->pid());
	if (!$USERNAME) { return (1); }

	if (index($PID,':')>=0) {
		## if we are requesting data for an option - just return the product.
		$PID = substr($PID,0,index($PID,':'));
		}

	$PID =~ s/[^\w\-]+/_/go;		# strips invalid characters

	if ($PID eq '') { return(2); }
	
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $qtUSERNAME = $udbh->quote($USERNAME);
	my $qtPRODUCT  = $udbh->quote($PID);

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &ZOOVY::resolve_product_tb($USERNAME);

	my $pstmt = "select ID,MKT_BITSTR,BASE_PRICE,BASE_COST,OPTIONS from $TB where MID=$MID and PRODUCT=$qtPRODUCT";
	my ($exists,$old_mkt_bitstr,$old_base_price,$old_base_cost,$old_options) = $udbh->selectrow_array($pstmt);

	my ($pogs2) = undef;
	if ($self->{'%data'}->{'@POGS'}) {
		($pogs2) = $self->{'%data'}->{'@POGS'};
		my $invcount = 0;
		foreach my $pog (@{$pogs2}) {
			if (($pog->{'inv'}&1)==1) {
				$invcount++;
				if ($invcount>3) { $pog->{'inv'} = 0; }		## you cannot have more than 3 inventoriable options
				}
			}
		}

	my $OPTIONS = 1;
	## 16 is open
	## 32 is open
	if ($self->has_variations('inv')) { 
		$OPTIONS |= 4; 
		foreach my $skuset (@{$self->list_skus()}) {
			my ($sku,$skuref) = @{$skuset};
			if (my $asm = $skuref->{'sku:assembly'}) { $OPTIONS |= 8; }
			}
		}
	if ($self->fetch('pid:prod_asm')) { $OPTIONS |= 64; }
	## 256 = is_parent
	## 512 = is_child
	if ($self->fetch('seo:noindex')) { $OPTIONS |= 1024; }		## no index

	if ((defined $PREF->{'zoovy:grp_siblings'}) && ($PREF->{'zoovy:grp_siblings'} ne '')) {
		## these field is an automated lookup.. might be cached someday, don't let the user save it.
		delete $PREF->{'zoovy:grp_siblings'};
		}

	## figure out if we can do "group autodetection"
	if ((defined $PREF->{'zoovy:grp_children'}) && ($PREF->{'zoovy:grp_children'} ne '') && ($PREF->{'zoovy:grp_type'} ne 'PARENT')) {
		$PREF->{'zoovy:grp_type'} = 'AUTO';
		## log that we turned on auto-group resolution
		}
	elsif ((defined $PREF->{'zoovy:grp_parent'}) && ($PREF->{'zoovy:grp_parent'} ne '') && ($PREF->{'zoovy:grp_type'} ne 'CHILD')) {
		$PREF->{'zoovy:grp_type'} = 'AUTO';
		## log that we turned on auto-group resolution
		}
	elsif ((defined $PREF->{'zoovy:grp_type'}) && ($PREF->{'zoovy:grp_type'} eq 'PARENT') && ($PREF->{'zoovy:grp_children'} eq '')) {
		## we have no children, this cannot be considered a PARENT
		delete $PREF->{'zoovy:grp_type'};
		}
	elsif (($PREF->{'zoovy:grp_type'}) && ($PREF->{'zoovy:grp_type'} eq 'CHILD') && ($PREF->{'zoovy:grp_parent'} eq '')) {
		## we have no parent, this cannot be considered a CHILD
		delete $PREF->{'zoovy:grp_type'};
		}

	if (not defined $PREF->{'zoovy:grp_type'}) { $PREF->{'zoovy:grp_type'} = 'AUTO'; }

	if ($PREF->{'zoovy:grp_type'} ne 'AUTO') {
		## no auto-detection -- this product already knows if it's a product or a parent.
		if ($PREF->{'zoovy:grp_type'} eq 'PARENT') { $OPTIONS |= 256; }
		elsif ($PREF->{'zoovy:grp_type'} eq 'CHILD') { $OPTIONS |= 512; }
		else { delete $PREF->{'zoovy:grp_type'}; }
		}
	elsif ((defined $PREF->{'zoovy:grp_children'}) && ($PREF->{'zoovy:grp_children'} ne '')) {
		## THIS IS A PARENT
		$OPTIONS |= 256;	## designates this product is a parent
		$PREF->{'zoovy:grp_type'} = 'PARENT';
		}
	elsif ((defined $PREF->{'zoovy:grp_parent'}) && ($PREF->{'zoovy:grp_parent'} ne '')) {
		## THIS IS A CHILD -- then 
		$OPTIONS |= 512;	## designates this product is a child
		$PREF->{'zoovy:grp_type'} = 'CHILD';
		}
	else {
		## yeah, we don't need this attribute because we're not a child or parent.
		delete $PREF->{'zoovy:grp_type'};
		}


	if (defined $pogs2) {
		## this might have attributes, inventoriable or non-inventoriable options - lets find out!
		require POGS;
		# print STDERR "POGS: $PREF->{'zoovy:pogs'}\n";

		my %MERGE = ();					# key is SKU  value is bitwise 1:pre-existing 2:valid now
		my %SKU_LOOKUP = ();				# key is SKU, value is ref to data

		my @PRE_EXISTING_SKUS = ();
		if (not defined $PREF->{'%SKU'}) {
			## hmm.. i assume we do this so we don't have a blank hashref and we test for zero someplace.
			## $PREF->{'%SKU'} = { '.'=>{} };
			$PREF->{'%SKU'} = {};
			}

		## map pre-existing
		foreach my $SKU (keys %{$PREF->{'%SKU'}}) { 
			$MERGE{$SKU} |= 1; 
			}

		## map currently valid sku's
		foreach my $set (@{$self->list_skus('verify'=>1)}) {
			my ($SKU,$SKUREF) = @{$set};
			$MERGE{ $SKU } |= 2;
			$SKU_LOOKUP{ $SKU } = $SKUREF;
			}

		## now settle up the different values.
		foreach my $SKU (keys %MERGE) {
			if ($MERGE{$SKU} == 3) {
				## pre-existing, and currently allowed, leave it all alone.
				}
			elsif ($MERGE{$SKU} == 2) {
				## new sku (just created)
				$PREF->{'%SKU'}->{$SKU} = $SKU_LOOKUP{ $SKU };
				push @EVENTS, "SKU.CREATED?SKU=$SKU";
				}
			elsif (($MERGE{$SKU} == 1) && ($SKU eq '.')) {
				## legacy issue - just delete it.
				delete $PREF->{'%SKU'}->{$SKU};
				}
			elsif ($MERGE{$SKU} == 1) {
				## pre-existing, but not current (remove it)
				delete $PREF->{'%SKU'}->{$SKU};
				push @EVENTS, "SKU.REMOVED?SKU=$SKU";
				}
			else {
				warn "UNKNOWN SKU MERGE CONDITION -- this line is never reached!\n";
				}
			}
		}

	##
	## SANITY: BEGIN create SKU_LOOKUP_x records
	##
	my ($L_TB) = &ZOOVY::resolve_lookup_tb($USERNAME);
	my %EXISTING_SKU_LOOKUPS = ();
	if (1) {
		my ($sth) = $udbh->prepare("select ID,INVOPTS,COST,PRICE from $L_TB where MID=$MID and PID=".$udbh->quote($PID));
		$sth->execute();
		while ( my ($ID,$INVOPTS, $COST,$PRICE) = $sth->fetchrow() ) {
			$EXISTING_SKU_LOOKUPS{":$INVOPTS"} = [ $ID, $COST, $PRICE ];
			}
		$sth->finish();
		}
	
	my $HAS_INV_OPTIONS = 0;
	foreach my $SKU (sort keys %{$PREF->{'%SKU'}}) {
		next if ($SKU eq '.');	# we add a '.' to %SKU earlier if there were no %SKU (not sure why)
		next if ($SKU eq ':');	# hmm.. this should never be reached.
		my ($sPID,$CLAIM,$INVOPTS) = &PRODUCT::stid_to_pid($SKU);
		## my $SKU = sprintf("%s%s",$PID,($INVOPTS?":$INVOPTS":""));

		if ((not defined $INVOPTS) || ($INVOPTS eq '')) {
			## sku corruption
			delete $PREF->{'%SKU'}->{$SKU};
			next;
			}
		elsif ($PID ne $sPID) {
			## sometimes the PID in %SKU isn't the same as %PID (corruption)
			delete $PREF->{'%SKU'}->{$SKU};
			next;
			}
		elsif ($INVOPTS ne '') { 
			$HAS_INV_OPTIONS++; 
			}


		my $exists = (defined $EXISTING_SKU_LOOKUPS{":$INVOPTS"})?1:0;
		## SKU_LOOKUP does not exist in DB.

		my %vars = (
			'MID'=>$MID,
			'PID'=>$PID,
			'INVOPTS'=>sprintf("%s",$INVOPTS),
			'SKU'=>$SKU,
			'IS_CONTAINER'=>0,
			'TITLE'=>sprintf("%s",&PRODUCT::str($PREF->{'%SKU'}->{$SKU}->{'zoovy:sku_pogdesc'})),
			'COST'=>sprintf("%0.2f",  
				$PREF->{'%SKU'}->{$SKU}->{'sku:cost'} ||  0
				),
			'PRICE'=>sprintf("%0.2f",  
				$PREF->{'%SKU'}->{$SKU}->{'sku:price'} || 0
				),
			'UPC'=>sprintf("%s",
				&PRODUCT::str($PREF->{'%SKU'}->{$SKU}->{'sku:upc'} || "")
				),
			'MFGID'=>sprintf("%s",
				&PRODUCT::str( $PREF->{'%SKU'}->{$SKU}->{'sku:mfgid'} || "") 
				),
			'AMZ_ASIN'=>sprintf("%s",
				&PRODUCT::str(  $PREF->{'%SKU'}->{$SKU}->{'sku:amz_asin'} || "" ) 
				),
			'SUPPLIERID'=>sprintf("%s",&PRODUCT::str(  $PREF->{'%SKU'}->{$SKU}->{'zoovy:prod_supplierid'} || "") ),
			'ASSEMBLY'=>sprintf("%s",&PRODUCT::str($PREF->{'%SKU'}->{$SKU}->{'sku:assembly'}) || ""),
			'INV_REORDER'=>sprintf("%s",&PRODUCT::str($PREF->{'%SKU'}->{$SKU}->{'sku:inv_reorder'}) || 0),
			);
		($pstmt) = "/* $INVOPTS */ ".&DBINFO::insert($udbh,$L_TB,\%vars,sql=>1,verb=>($exists)?'update':'insert',key=>['MID','PID','INVOPTS']);
		# print STDERR "$pstmt\n";
		# print STDERR "sql[$exists:$L_TB]: $pstmt ".Dumper(\%vars)."\n";
		$udbh->do($pstmt);

		my $old_price = $EXISTING_SKU_LOOKUPS{":$INVOPTS"}->[1];
		if ($old_price != ($PREF->{'%SKU'}->{$SKU}->{'sku:price'} || 0)) {
			push @EVENTS, sprintf('SKU.PRICE-CHANGE?SKU=%s&was=%s&is=%s',$SKU,$old_price,$PREF->{'%SKU'}->{$SKU}->{'sku:price'});
			}

		my $old_cost = $EXISTING_SKU_LOOKUPS{":$INVOPTS"}->[1];
		if ($old_cost != ($PREF->{'%SKU'}->{$SKU}->{'sku:cost'} || 0)) {
			push @EVENTS, sprintf('SKU.COST-CHANGE?SKU=%s&was=%s&is=%s',$SKU,$old_cost,$PREF->{'%SKU'}->{$SKU}->{'sku:cost'});
			}

		delete $EXISTING_SKU_LOOKUPS{":$INVOPTS"};


		}


	## product record only, no inventoriable options.
	if (1) {
		## we will ALWAYS have a base record
		my ($exists) = (defined $EXISTING_SKU_LOOKUPS{":"})?1:0;
		if (not defined $PREF->{'pid:assembly'}) { $PREF->{'pid:assembly'} = ''; }
		if (not defined $PREF->{'amz:asin'}) { $PREF->{'amz:asin'} = ''; }
		if (not defined $PREF->{'zoovy:prod_mfgid'}) { $PREF->{'zoovy:prod_mfgid'} = ''; }
		if (not defined $PREF->{'zoovy:prod_upc'}) { $PREF->{'zoovy:prod_upc'} = ''; }

		my %vars = (
			'MID'=>$MID,'PID'=>$PID,'INVOPTS'=>'','SKU'=>$PID,
			'IS_CONTAINER'=>($HAS_INV_OPTIONS)?1:0,
			'TITLE'=>sprintf("%s",$PREF->{'zoovy:prod_name'} || ""),
			'COST'=>sprintf("%0.2f",$PREF->{'zoovy:base_cost'} || 0),
			'PRICE'=>sprintf("%0.2f",$PREF->{'zoovy:base_price'} || 0),
			'UPC'=>sprintf("%s",$PREF->{'zoovy:prod_upc'} || 0),
			'MFGID'=>sprintf("%s",$PREF->{'zoovy:prod_mfgid'} || ""),
			'AMZ_ASIN'=>sprintf("%s",$PREF->{'amz:asin'} || ""),
			'SUPPLIERID'=>sprintf("%s",$PREF->{'zoovy:prod_supplierid'} || ""),
			'ASSEMBLY'=>sprintf("%s",$PREF->{'pid:assembly'} || ""),
			);

		my ($pstmt) = "/* BS:$exists */ ".&DBINFO::insert($udbh,$L_TB,\%vars,sql=>1,'verb'=>(($exists)?'update':'insert'),key=>['MID','PID','INVOPTS'],sql=>1);
		if ($pstmt eq '') { &ZOOVY::confess($self->username(), "BOGUS PRODUCT ".Dumper($udbh,$L_TB,\%vars,$exists)); }
		$udbh->do($pstmt);
		delete $EXISTING_SKU_LOOKUPS{":"};
		}

	if (scalar(keys %EXISTING_SKU_LOOKUPS)>0) {
		## Invalid SKU's we should remove
		foreach my $PIDINVOPTS (keys %EXISTING_SKU_LOOKUPS) {
			my ($DBID) = $EXISTING_SKU_LOOKUPS{$PIDINVOPTS}->[0]; 
			my $pstmt = "delete from $L_TB where MID=$MID and PID=".$udbh->quote($PID)." and ID=".int($DBID)." /* $PID$PIDINVOPTS */";
			# print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			}
		}

	##
	## SANITY: END create SKU_LOOKUP_x records
	##

	my $digest = undef;
	$digest = Digest::MD5::md5_base64(sprintf("%s:%s:%s:%s",
		$PID || "",
		$PREF->{'zoovy:grp_type'} || "",
		$PREF->{'zoovy:grp_parent'} || "",
		$PREF->{'zoovy:grp_children'} || ""
		));
	if ($digest eq $PREF->{'zoovy:digest'}) { 
		## digests match .. don't need to fix my children!
		$digest = undef;
		}
	else {
		## we'll update the family digest to what it should be *when we're done*
		## so that it saves this time, and next time we're here dont' need to do an update.
		$PREF->{'zoovy:digest'} = $digest;
		}
	
	## handle PROD_IS flags
	my $PROD_IS = 0;
	foreach my $isref (@ZOOVY::PROD_IS) {
		if ($PREF->{$isref->{'attr'}}) { $PROD_IS |= (1 << $isref->{'bit'}); }
		## we do not need to store the PROD_IS attributes, since they will be rebuilt based on the PROD_IS value.
		delete $PREF->{$isref->{'attr'}};
		}
	if (not $exists) { $PROD_IS |= 1; } 	# set to "Fresh"
	$PREF->{'zoovy:prod_is'} = $PROD_IS;
	delete $PREF->{'zoovy:prod_is_tags'}; 	## delete these, since they will be auto-computed.

	if ($PREF->{'zoovy:profile'} eq '') { $PREF->{'zoovy:profile'} = 'DEFAULT'; }

	## AMAZON defaults to "do not syndicate"
	if (not defined $PREF->{'amz:ts'}) { $PREF->{'amz:ts'} = 0; }
	$PREF->{'amz:ts'} = int($PREF->{'amz:ts'});

	my ($ebay_str,$amz_str,$zoovy_str);
	foreach my $k (sort keys %{$PREF}) {
		next if ($k =~ /:digest/);	# skip digest fields
		my ($owner,$attrib) = split(/\:/,$k,2);
		# $PREF->{$k} = &ZTOOLKIT::stripUnicode($PREF->{$k});  -- this will fix the md5 crashing.
		if ($k =~ /^(zoovy)\:(prod_name|prod_desc|prod_detail|prod_image|base_price)$/o) {
			$zoovy_str .= sprintf("%s=%s&",$k,$PREF->{$k}||"");
			}
		elsif ($k =~ /^(ebay|ebaystores)\:/o) {
			$ebay_str .= sprintf("%s=%s&",$k,$PREF->{$k}||"");
			}
		elsif ($k =~ /^amz\:/) {
			$amz_str .= sprintf("%s=%s&",$k,$PREF->{$k}||"");
			}
		}

	my $ebay_digest = Digest::MD5::md5_base64(Encode::encode_utf8($ebay_str.$zoovy_str));
	my $amz_digest = Digest::MD5::md5_base64(Encode::encode_utf8($amz_str.$zoovy_str));
	if (($PREF->{'ebay:ts'}) && ($PREF->{'ebay:digest'} ne $ebay_digest)) {
		push @EVENTS, 'PID.EBAY-CHANGE';
		$PREF->{'ebay:digest'} = $ebay_digest;
		}
	if (($PREF->{'amz:ts'}) && ($PREF->{'amz:digest'} ne $amz_digest)) {
		push @EVENTS, 'PID.AMZ-CHANGE';
		$PREF->{'amz:digest'} = $amz_digest;
		}
	undef $ebay_str;
	undef $amz_str;
	undef $zoovy_str;
	undef $ebay_digest;
	undef $amz_digest;


	my %BITIDS = ();
	foreach my $intref (@ZOOVY::INTEGRATIONS) {
		if ( not defined $intref->{'mask'} ) {
			}
		elsif ((not defined $intref->{'attr'}) || ($intref->{'attr'} eq '')) {
			## integration has no attribute
			if ($intref->{'true'}) {
				## default on
				$BITIDS{ $intref->{'id'} }++;
				}
			}
		elsif (not defined $PREF->{ $intref->{'attr'} }) {
			## attribute not set, or attribute not enabled on product , so let's default
			if ($intref->{'true'}) {
				## default on
				$BITIDS{ $intref->{'id'} }++;
				$PREF->{ $intref->{'attr'} } = 1;
				}
			}
		elsif ( (not defined $PREF->{ $intref->{'attr'} }) || ( $PREF->{ $intref->{'attr'} } eq '') ) {
			## stops warning  'Argument "" isn't numeric in int'
			}
		elsif (int($PREF->{ $intref->{'attr'} })>0) {
			## implicitly turned on
			$BITIDS{ $intref->{'id'} }++;
			}
		else {
			## implicitly turned off
			}
		}
	my @bitvals = keys %BITIDS;
	my $MKT_BITSTR = &ZOOVY::bitstr(\%BITIDS);

	my $DATA = YAML::Syck::Dump($PREF);

	if (length($DATA)>1000000) { 
		$DATA = "---\nzoovy:prod_name: Corrupt product - exceeds 1mb limit\n";
		}

	my %DBVARS = ();
	$DBVARS{'OPTIONS'} = $OPTIONS;
	$DBVARS{'MKT_BITSTR'} = $MKT_BITSTR;
	$DBVARS{'TS'} = time();
	$DBVARS{'DATA'} = $DATA;
	foreach my $k (keys %{$ZOOVY::PRODKEYS}) {
		# print STDERR "K: $k\n";
		next if (not defined $PREF->{$k});
		next if ($k eq 'zoovy:prod_id');
		$DBVARS{$ZOOVY::PRODKEYS->{$k}} = $PREF->{$k};
		}	
	if (defined $DBVARS{'BASE_COST'}) { $DBVARS{'BASE_COST'} = 0; }

	if ($exists) {
		## EXISTING PRODUCT
		if (defined $CATEGORY) { $DBVARS{'CATEGORY'} = $CATEGORY; }
		$pstmt = &DBINFO::insert($udbh,$TB,\%DBVARS,update=>2,sql=>1,key=>{'MID'=>$MID,'PRODUCT'=>$PID},sql=>1);
		if ($old_mkt_bitstr ne $DBVARS{'MKT_BITSTR'}) {
			push @EVENTS, sprintf('PID.MKT-CHANGE?was=%s&is=%s',$old_mkt_bitstr,$DBVARS{'MKT_BITSTR'});
			}
		if ($old_base_price != ($PREF->{'zoovy:base_price'} || 0)) {
			push @EVENTS, sprintf('PID.PRICE-CHANGE?was=%s&is=%s',$old_base_price,$PREF->{'zoovy:base_price'});
			}
		if ($old_base_cost != ($PREF->{'zoovy:base_cost'} || 0)) {
			push @EVENTS, sprintf('PID.COST-CHANGE?was=%s&is=%s',$old_base_cost,$PREF->{'zoovy:base_cost'});
			}
		}
	else {
		## NEW PRODUCT
		if (!defined($CATEGORY)) { $CATEGORY = ''; }
		$DBVARS{'CATEGORY'} = $CATEGORY;
		$DBVARS{'CREATED_GMT'} = $DBVARS{'TS'};
		$DBVARS{'MERCHANT'} = $USERNAME;
		$DBVARS{'MID'} = $MID;
		$DBVARS{'PRODUCT'} = $PID;
		$pstmt = &DBINFO::insert($udbh,$TB,\%DBVARS,update=>0,sql=>1);
		push @EVENTS, 'PID.CREATE';
		}

	# print STDERR $pstmt."\n";
	my ($rv) = $udbh->do($pstmt);
	if (not defined $rv) {
		## attempt reconnect/retry
		sleep(1);
		($rv) = $udbh->do($pstmt);
		}

	if (not defined $rv) {
		open F, ">>/tmp/fail-pstmt.log";
		print F "$pstmt;\n";
		close F;
		}


#	## THESE LINES MUST BE RUN AFTER THE DATABASE UPDATE
#	$pstmt = "delete from PRODUCT_RELATIONS where MID=$MID /* $USERNAME */ and PID=".$dbh->quote($PID);
#	print STDERR $pstmt."\n";
#	$dbh->do($pstmt);


#create table PRODUCT_RELATIONS (
#  MID integer unsigned default 0 not null,
#  PID varchar(20) default '' not null,
#  CHILD_PID varchar(20) default '' not null,
#  RELATION varchar(16) default '' not null,   
#  QTY smallint unsigned default 0 not null,
#  IS_ACTIVE tinyint unsigned default 0 not null,
#  LIST_POS tinyint unsigned default 0 not null,
#  CREATED_GMT integer unsigned default 0 not null,
#  unique(MID,PID,RELATION,CHILD_PID),
#  index(MID,CHILD_PID,RELATION)
#);
#	my @SQL = ();
#	$pstmt = "delete from PRODUCT_RELATIONS";
#	if ($PREF->{'zoovy:prod_related'} ne '') {
#		foreach my $pid (split(/,/,$PREF->{'zoovy:prod_related'})) {
#			push @SQL, &DBINFO::insert($dbh,'PRODUCT_RELATIONS',{
#				MID=>$MID,PID=>$PID,
#				CHILD_PID=>$pid, RELATION=>'RELATED', CREATED_GMT=>time(),
#				},update=>0,debug=>2);
#			}
#		}

	if (defined $digest) {
		## for now .. we're doing chuck-e-cheese rules:
		##		a child may specify it's parent, and that relationship will be updated.
		##		however it doesn't matter what a parent says, the child needs to agree.
		
		if ($PREF->{'zoovy:grp_type'} eq 'PARENT') {
		## if we decided to let parents update their children, it'd probably look something like this:
		#	foreach my $childpid (split(/\,/,$PREF->{'zoovy:grp_children'})) {
		#		my ($childpref) = &ZOOVY::fetchproduct_as_hashref($USERNAME,$childpid);
		#		next if ($childpref->{'zoovy:grp_parent'} eq $PID);
		#		## we should probably do some type of logging here.
		#		$childpref->{'zoovy:grp_parent'} = $PID;
		#		delete $childpref->{'zoovy:grp_children'};
		#		&ZOOVY::saveproduct_from_hashref($USERNAME,$childpid,$childpref);
		#		}
			}
		elsif ($PREF->{'zoovy:grp_type'} eq 'CHILD') {
			my $PARENTPID = $PREF->{'zoovy:grp_parent'};
			
			# my ($parentpref) = &ZOOVY::fetchproduct_as_hashref($USERNAME,$PARENTPID);
			# my %siblings = map { $_ => $_ } split(/,/,$parentpref->{'zoovy:grp_children'});

			my ($parentP) = PRODUCT->new($USERNAME,$PARENTPID);
			my %siblings = map { $_ => $_ } $parentP->grp_children();
			if (not defined $siblings{$PID}) {
				## we need to adopt a parent, and let them know we're a child.
				## we should probably do some type of logging here.
				$parentP->store('zoovy:grp_children', &ZOOVY::csv_insert($parentP->fetch('zoovy:grp_children'),$PID) );
				## remind our parent that shouldn't behave as a child.
				$parentP->store('zoovy:grp_parent',undef);
				## can't do this because PREF is already saved at this point.
				## $PREF->{'zoovy:grp_siblings'} = $parentpref->{'zoovy:grp_children'};
				$parentP->save();
				}
			}

		if ($exists) {
			## we only perform geometry events when an item already exists!
			push @EVENTS, 'PID.GEOMETRY';
			}
		}




	## restore is:* values.
	## handle PROD_IS code.
	$PROD_IS = $PREF->{'zoovy:prod_is'};
	my @TAGS = ();
	foreach my $isref (@ZOOVY::PROD_IS) {
		# print "$PROD_IS $isref->{'bit'}\n";
		if (($PROD_IS & (1 << int($isref->{'bit'}))) > 0) {
			$PREF->{ $isref->{'attr'} } = 1;
			push @TAGS, $isref->{'tag'};
			}
		}
	$PREF->{'zoovy:prod_is_tags'} = join(',',@TAGS);

	# my ($memd) = &ZOOVY::getMemd($USERNAME);
	my $memd = undef; 
	if (defined $memd) {
		$memd->set(uc("$USERNAME:pid-$PID"), $PREF );
		}

#
# create table PRODUCT_RELATIONSHIPS (
#   MID integer unsigned default 0 not null, 
#   PID varchar(20) default '' not null,  
#   FIELD varchar(16) default '' not null,   /* 'zoovy:prod_asm' */
#   CHILD varchar(20) default '' not null,
#   QTY smallint unsigned default 0 not null, 
#   CREATED_GMT integer unsigned default 0 not null, 
#   unique(MID,PID,FIELD,CHILD),
#   index(MID,CHILD,FIELD)
# );
#

	$ZOOVY::GLOBAL_PRODUCTUSER = $USERNAME;
	$ZOOVY::GLOBAL_PRODUCTID = $PID;
	$ZOOVY::GLOBAL_PRODUCTDATA = $DATA;
	$ZOOVY::GLOBAL_PRODUCTTS = undef;

	&ZOOVY::nuke_product_cache($USERNAME,$PID);

	push @EVENTS, "PID.SAVED";
	foreach my $event (@EVENTS) {
		# print STDERR "EVENT: $event\n";
		my $params = {};
		if (index($event,'?')>0) {
			## event?param1=value1&param2=value2
			$params = &ZTOOLKIT::parseparams(substr($event,index($event,'?')+1));
			$event = substr($event,0,index($event,'?'));	
			}
		$params->{'PID'} = $PID;
		$params->{'SRC'} = 'ZOOVY::PRODUCT-SAVE';
		&ZOOVY::add_event($USERNAME,$event,%{$params});
		}

	&DBINFO::db_user_close();
	}





## sub VALIDATE
##
## pass in product object
##  validate attributes
##	 - inventory has been configured (for all skus)
##  -- includes setting inv_enable as necessary
##  -- and adding incrementals
##	 - related products (still exist) --- needs to be added
##  - nuke old (invalid) inventory entries ?? --- needs to be added 
##
## currently only called from Power Option Tool
##
#sub validate {
#	my ($self) = @_;
#	my $ERRORS = '';
#	my $results = '';
#	my $USERNAME = $self->{'USERNAME'};
#
#
##	if ($item->{'%attribs'}->{'zoovy:virtual'} =~ /[\s]/) { $lm->pooshmsg("ERROR|+Preflight: STID[$stid] has space in zoovy:virtual field"); }
##	if ($item->{'%attribs'}->{'zoovy:virtual'} ne $item->{'virtual'}) { $lm->pooshmsg("ERROR|+Preflight: STID[$stid] has non-matching zoovy:virtual and item.virtual (internal error!?)"); }
#
#	## check assembly components to make sure all qty are positive integers
#
### INTEGRATE LATER: POGS::validate_invsku
##	my $pogs2 = &ZOOVY::fetch_pogs($USERNAME,$prodref);
##
##	my $result = 0;		# this is consider success! (we'll flip it later)
##
##	## 
##	## step1: build a hashref keyed by option code e.g. #Z=>00,#Y=>AA .. you get the idea.
##	my %opts = ();
##	foreach my $kv (split(/\:/,$INVSKU)) {
##		next if ($kv eq '');
##		my $k = substr($kv,0,2);
##		my $v = substr($kv,2,2);
##		$opts{$k} = $v;
##		}
##	
##	## now go through each pog, one by one.
##	foreach my $pog (@{$pogs2}) {
##		my $id = (defined $pog->{'id'})?$pog->{'id'}:'';
##		if ($id !~ m/^[\$\#A-Z0-9][A-Z0-9]$/) { $result = 1; }		# wow. corrupt pog in product!
##
##		next if (not $pog->{'inv'}); 											# skip non inventoriable options!
##		next if ($result > 0);													# if we've already got an error, then bail!
##
##		if (defined $opts{$pog->{'id'}}) {									# check to see if this inv opt was passed to func. (if not thats an error)
##			$result = 2;															# assume we won't find shit.
##			foreach my $opt (@{$pog->{'@options'}}) {						# hunt through each pog, look for a success!
##				next if ($opt->{'v'} ne $opts{$pog->{'id'}});		
##				$result = 0;														# yippie-- now wash, rinse, repeat.
##				}	
##			}
##		else {
##			$result = 3; # option does not exist.							# shit, this wasn't passed in $INV_SKU
##			}
##		delete $opts{$pog->{'id'}};											
##		}
#	
###	print STDERR "RESULT: $result\n";
##	use Data::Dumper; print STDERR Dumper(\%opts);
##	if (scalar keys %opts) { $result = 4; }								# we had left over options!
#	
##	print STDERR "RESULT: $result\n";
#	
#	## configure inventory as necessary
#	if ($ERRORS eq '') {
#		require INVENTORY;
#
#		## check all SKUs
#		# if ($self->fetch('zoovy:pogs') ne '') {
#
#	
#
#
#		if ($self->has_variations('inv')) {
#			my $skusref = $self->list_skus('verify'=>1);
#
#
#			## TODO: make sure each selectable option has one or more valid choices
#			##			size - with no sizes specified.
#
#			my @skus = ();
#			foreach my $set (@{$skusref}) { push @skus, $set->[0]; }
#
#			# use Data::Dumper; print STDERR Dumper(\@skus);
#
#			my ($instockref,$reserveref,$locref,$reorderref, $onorderref) = &INVENTORY::fetch_incrementals($USERNAME,\@skus,undef,8+16+32+64+128);
#			foreach my $SKU (@skus) {
#				print STDERR "checking SKU: $SKU $instockref->{$SKU}\n";
#				## not configured
#				if (!($self->fetch('zoovy:inv_enable') & 32) && not defined $instockref->{$SKU}) { 
#					INVENTORY::add_incremental($USERNAME,$SKU,'U',0); 
#					$results .= "Added incremental (0) for $SKU\n";
#					}
#				## unlimited
#				elsif ($self->fetch('zoovy:inv_enable') & 32 && $instockref->{$SKU} != 9999) {
#					INVENTORY::add_incremental($USERNAME,$SKU,'U',9999); 
#               $results .= "Added incremental (9999) for $SKU\n";
#					}
#				
#				}
#
#			## alter inv_enable as necessary
#			## ie if its not & 5, inventory incrmentals are not finalized
#			if ($results ne '') {
#				my $inv_enable = int($self->fetch('zoovy:inv_enable'));
#				if ($inv_enable & 4) {
#					$results .= "no change to inv_enable needed: $inv_enable\n"; 
#					}
#				else {
#					$inv_enable += 4;
#					$self->store('zoovy:inv_enable',$inv_enable);
#					$results .= "Added 4 (for inv pogs) to inv_enable for $self->{'PID'}\n";
#					}
#				}
#			}
#
#		## just check the PID - not used yet
#		else {
#			print STDERR "checking PID inventory\n";	
#			require INVENTORY;
#			if ($self->fetch('zoovy:inv_enable') & 32) {
#				my @pids = ($self->{'PID'});
#				my ($instockref,$reserveref,$locref,$reorderref, $onorderref) = &INVENTORY::fetch_incrementals($USERNAME,\@pids,undef,8+16+32+64+128);
#				my $quantity = $instockref->{$self->{'PID'}} - $reserveref->{$self->{'PID'}};
#
#				## normally this update takes place in the inventory script
#				## this update would just make it available to the merchant before finalization
#				if ($quantity != 9999) {
#					INVENTORY::add_incremental($USERNAME,$self->{'PID'},'U',9999);
#					$results .= "Added incremental (9999) for $self->{'PID'}\n"; 
#					}
#				}
#			}
#		}		
#
#	return($results, $ERRORS);
#	}
#



###
### returns @ERRORS (or empty array if success)
###
#sub validate_assembly_chain {
#	my ($self,$sku,$chain) = @_;
#
#	## check assembly chain
#	my @ERRORS = ();
#	my $pos = 0;
#	if (not defined $chain) { $chain = ''; }
#	foreach my $skuqty (split(/\,/,$chain)) {
#		$pos++;
#		$skuqty =~ s/[\s]+//g;
#		next if ($skuqty eq '');
#		my ($invsku,$qty) = split(/\*/,$skuqty,2);
#		if ($qty eq '') { $qty = 1; }
#		$qty = int($qty); 
#		my ($chainpid,$claim,$invopts,$noinvopts,$virtual) = PRODUCT::stid_to_pid($invsku);
#		
#		## no options -- easy
#		my $pidxref = {};
#		if (not &ZOOVY::productidexists($self->username(),$chainpid)) {
#			push @ERRORS, "position[$pos] product[$chainpid] does not exist";
#			}
#		}
#	return(@ERRORS);
#	}
#

## 
## sub PROPERTY
##	
##	pass: variable in the $self object you want to access e.g. PID, USERNAME, STID, etc. (see function NEW for a list)
##
sub property { my ($self) = @_; return($self->{$_[1]});  }

################################### NON OBJECT FUNCTIONS ##########################################


##
## builds a stid from various pieces
##
sub generate_stid {
	my (%options) = @_;

	my $STID = $options{'pid'};

	if ((defined $options{'invopts'}) && ($options{'invopts'} ne '')) { 
		$STID = sprintf("$STID:%s",$options{'invopts'}); 
		}
	
	if ((defined $options{'noinvopts'}) && ($options{'noinvopts'} ne '')) { 
		$STID = sprintf("$STID/%s",$options{'noinvopts'}); 
		}	

	if ((defined $options{'claim'}) && ($options{'claim'} ne '')) {
		$STID = sprintf("%d*$STID",$options{'claim'}); 
		}	
	if ((defined $options{'virtual'}) && ($options{'virtual'} ne '')) { 
		$STID = sprintf("%s@%s",$options{'virtual'},$STID); 
		}	

	return($STID);
	}



## 
## busts apart a pid into it's respective properties.
##		i.e. VIRTUAL@CLAIM*PID:INVOPTS/NONINVOPTIONS
##		e.g. ALLDROPSHIP@1234*PRODUCTID:#Z01/1
##
sub stid_to_pid {
	my ($stid) = @_;

	## STID max length is 128 characters. 
	## anything after 128 will be truncated/dropped. 

	my $x = -1;
	my $virtual = undef;
	my $claim = undef;
	my $noinvopts = undef;
	my $invopts = undef;

	## NEC-SIN2-G/3518765*NEC-SIN2-B4:#Z00

	$x = index($stid,'@');		## VIRTUAL/ASSEMBLY MASTER appear before the @ 
	if ($x>=0) { $virtual = substr($stid,0,$x); $stid = substr($stid,$x+1); }

	$x = index($stid,'/'); 		## NON INVENTORIABLE OPTIONS appear after the /
	if ($x>=0) { $noinvopts = substr($stid,$x+1); $stid = substr($stid,0,$x); }

	## NOTE: remember that non-invopts sometimes have * in them so we have to parse claims last!
	$x = index($stid,'*'); 		## UNIQUE CLAIM # for eBay transactions
	if ($x>=0) { $claim = substr($stid,0,$x); $stid = substr($stid,$x+1); }

	$x = index($stid,':'); 		## delimiter for inventoriable options.  option codes are always two digit
										## lead by a colon (:) e.g. :ZZ01  denotes option group ZZ selection 01. 
	if ($x>=0) { $invopts = substr($stid,$x+1); $stid = substr($stid,0,$x); }

	## Product max length is 20 characters.
	##	Inventoriable option x 3 (5 characters each) adds +15
	## Maximum SKU (Stock Keeping Unit) length is therefore 35 characters (SKU = PID + INVENTORIABLE_OPTIONS)

	my $pid = $stid;
	
	return($pid,$claim,$invopts,$noinvopts,$virtual);
	return(&PRODUCT::stid_to_pid($stid));
	}



##
## moved to ZTOOLKIT 5/16/09
sub batchify {
	return(&ZTOOLKIT::batchify(@_));
	}


################################################
##
##	 
##
sub fetchproduct_ts {
	my ($USERNAME, $PRODUCT) = @_;

	if (($ZOOVY::GLOBAL_PRODUCTUSER eq $USERNAME) && ($ZOOVY::GLOBAL_PRODUCTID eq $PRODUCT) && (defined $ZOOVY::GLOBAL_PRODUCTTS)) {
		return($ZOOVY::GLOBAL_PRODUCTTS);
		}

	my $pdbh 	 = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &ZOOVY::resolve_product_tb($USERNAME);

	my $pstmt = "select TS,DATA from $TB where MID=".$pdbh->quote($MID)." and PRODUCT=" . $pdbh->quote($PRODUCT);
	#print STDERR $pstmt."\n";
	my $sth = $pdbh->prepare($pstmt);
	my $rv  = $sth->execute();
	my ($TS,$DATA) = $sth->fetchrow();
	$sth->finish();
	&DBINFO::db_user_close();

	$ZOOVY::GLOBAL_PRODUCTUSER = $USERNAME;
	$ZOOVY::GLOBAL_PRODUCTID = $PRODUCT;
	$ZOOVY::GLOBAL_PRODUCTDATA = $DATA;
	$ZOOVY::GLOBAL_PRODUCTTS = $TS;
	
	return($ZOOVY::GLOBAL_PRODUCTTS);
	}


###########################
##
## ZOOVY::build_prodinfo_ts
##
## parameters: USERNAME
## returns: a reference to a hash which contains all the timestamps for all products
##
sub build_prodinfo_ts {
	my ($USERNAME) = @_;

	my %ts = ();

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $TB = &ZOOVY::resolve_product_tb($USERNAME);

	my $pdbh 	 = &DBINFO::db_user_connect($USERNAME);

	## speeds up reads
	#my $pstmt = 'set read_buffer_size= 2093056;';
	#$pdbh->do($pstmt);

	my $pstmt = "select PRODUCT,TS from $TB where MID=$MID";
	# ($tsref) = $pdbh->selectall_hashref($pstmt, 'PRODUCT');
	my $sth = $pdbh->prepare($pstmt);
	$sth->execute();
	while ( my ($k,$v) = $sth->fetchrow() ) { $ts{$k}=$v; }
	$sth->finish();
	
	&DBINFO::db_user_close();
	return (\%ts);
	} ## end sub build_prodinfo_refs



1;
