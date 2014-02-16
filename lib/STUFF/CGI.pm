package STUFF::CGI;

use strict;

use lib "/backend/lib";
require LISTING::MSGS;
require EXTERNAL;
require STUFF2;
require PRODUCT;
require ZTOOLKIT;

sub pint { ZTOOLKIT::pint(@_); }
sub def { ZTOOLKIT::def(@_); }
sub gstr { ZTOOLKIT::gstr(@_); }




##
##	accepts: 
##		MERCHANT 	- the username of the person in question
##		CGIV 			- a hashref of CGI key/value pairs (implicitly lower case UNTAINTED)
##		CGIV_MIXED 	- a hashref of CGI key/value pairs (mixed case TAINTED)
##		SOFTCART 	- 0/1 (allows key values to be overridden on post/get)
##		ERRORSREF 	- an array ref to which error messages will be appended (optional)
##						  e.g. product could not be found - or softcart params not allowed.
##
## returns: an array of "items" which can be stuffed
##
## 	looks for product_id or product_id: or product:


sub legacy_parse {
	my ($s2,$cgiv, %params) = @_;

	my $lm = $params{'*LM'};
	if (not defined $lm) { $lm = LISTING::MSGS->new($s2->username()); }
	my $DEBUG = 0;

	my @items = (); 
	my %PROCESSED = ();

	my $softcart = int($params{'softcart'});
	if (not $softcart) {
		## no softcart functionality will be implemented.
		}
	elsif ($cgiv->{'_trustedparams'}) {
		my %trustedparams = ();
		## do md5 check here, recompile a list of trusted params
		my $webdbref = &ZWEBSITE::fetch_website_dbref($s2->username(),0);
		my ($shared_secret) = $webdbref->{'softcart_secret'};

		my @VALUES_TO_BE_DIGESTED = ();
		foreach my $tryparam (split(/;/,$cgiv->{'_trustedparams'})) {
			if ($tryparam eq 'secret') {
				push @VALUES_TO_BE_DIGESTED, $shared_secret;
				}
			else {
				push @VALUES_TO_BE_DIGESTED, sprintf("%s",$cgiv->{$tryparam});
				$trustedparams{$tryparam} = $cgiv->{$tryparam};
				}
			}

		## SANITY: at this point @VALUES_TO_BE_DIGESTED is fully built
		$softcart = 0;
		if (defined $cgiv->{'_md5b64'}) {
			require Digest::MD5;
			my ($md5_base64_digest) = Digest::MD5::md5_base64(join(";",@VALUES_TO_BE_DIGESTED));
			if ($md5_base64_digest eq $cgiv->{'_md5b64'}) {
				## yay! trust the parameters - this softcart is good. (re-enable the softcart)
				$cgiv = \%trustedparams;
				$softcart++;
				}
			else {
				$lm->pooshmsg("ERROR|+_md5b64 digest did not match");
				}
			}
		else {
			$lm->pooshmsg("ERROR|+_trustedparams must be used with _md5b64 parameter, softcart functionality disabled");
			}
		}
	else {
		## okay we need to decide if we have a shared secret (if we do, then softcart will require it)
		my $webdbref = &ZWEBSITE::fetch_website_dbref($s2->username(),0);
		my ($shared_secret) = $webdbref->{'softcart_secret'};
		if ($shared_secret ne '') {
			## since we have a shared secret, but no _trustedparams we must disable softcart!
			$softcart = 0;
			}
		}


	if ($softcart) {
		# &ZOOVY::confess($s2->username(),"LEGACY USING SOFTCART",justkidding=>1);
		}

	##
	## SANITY: at this point $softcart is set to 1/0 based on the _trustedparams and $cgiv only contains
	##			  parameters we're ACTUALLY going to use.
	##


	foreach my $param (keys %{$cgiv}) {

		my $stid = '';
		my $quantity = undef;
		my $suffix = '';
		if ((lc($param) eq 'product_id') || (lc($param) eq 'product')) {
			## passes:
			##			product=pid/sku/stid
			##			quantity=###
			$stid = lc(def($cgiv->{$param}));
			$quantity = defined($cgiv->{'quantity'}) ? $cgiv->{'quantity'} : 1 ;
			}
		elsif (lc(substr($param,0,11)) eq 'product_id:') {
			## passes:
			##			product_id:stid=anything
			##			quantity:stid=###
			##
			## stid could be a product, a sku, or a fully qualified stid e.g.:
			##			PID:AABB:CCDD
			$stid = lc(substr($param,11));
			$suffix = ':'.$stid;
			$quantity = defined($cgiv->{"quantity:$stid"}) ? $cgiv->{"quantity:$stid"} : 1 ;
			}
		elsif (lc(substr($param,0,8)) eq 'product:') {
			##	passes:			
			##			product:stid=anything
			##			quantity:stid=###
			$stid = lc(substr($param,8));
			$suffix = ':'.$stid;
			$quantity = defined($cgiv->{"quantity:$stid"}) ? $cgiv->{"quantity:$stid"} : 1 ;
			}

		next if ($stid eq '');

		# $DEBUG++;
		# $DEBUG = ($stid eq 'reeb3')?1:0;

		if (not defined $quantity) { $quantity = 1; }
		$quantity = int($quantity);

		next unless gstr($stid);
		next if ($PROCESSED{$stid});			# loopback detection since mixed case vars appear twice it prevents
		$PROCESSED{$stid}++;										# us from adding the same product twice.

		$DEBUG && print STDERR ("Quantity is $quantity\n");
		$DEBUG && print STDERR ("Found product to add: $stid\n");

		print STDERR "product: $stid QUANTITY: [$quantity]\n";

		## If we already have a dash in the product id, don't try to add the pogs
		#my $item = {};
		#my $prodref = &EXTERNAL::get_item($MERCHANT, $product_id, 1);
		#if ((defined $prodref) && (scalar(keys %{$prodref})==0)) { $prodref= undef; }

		#if ((not defined $prodref) && (not $softcart)) {
		#	## no product record and not softcart, this is the end of line for us!
		#	push @{$errorsref}, "Product $product_id is no longer available for purchase.";
		#	$product_id = '';
		#	}
		#else {
		#	delete $prodref->{'zoovy:prod_desc'};

		#	foreach (qw(base_weight prod_name inv_mode base_price qty_price taxable)) {
		#		$item->{$_} = $prodref->{"zoovy:$_"};
		#		}
		#	}

#		use Data::Dumper; 
#		$DEBUG && print STDERR (Dumper($cgiv));
#		next if ($product_id eq '');

		$stid =~ s/^[\s]*(.*?)[\s]*$/$1/gso;
		$stid = uc($stid);
		$stid =~ s/[^A-Z0-9\_\-\:\/\*\#]+/_/gs;

		my %options = ();	## hash keyed by groupID, value is optionID |OR| text value
								##  optionID's are always two digits
								##  at this point there is no way to reliably distinguish between a textbox and optionID
								##  thank you Anthony!
		my $variations = undef;

		my ($PID,$CLAIM,$INV_OPS,$NON_OPS,$VIRTUAL) = &PRODUCT::stid_to_pid($stid);
		my ($P) = PRODUCT->new($s2->username(), $PID);

		if (not defined $P) {
			}
		elsif ($P->has_variations('any')) {
			##
			## STAGE1: first parse any options which were passed as part of the $product_id
			##			  e.g. $PID:1234/ABCD/QFGD  becomes 12=>34,AB=>CD,QF=>GD
			my $prodopts = $stid;
			$prodopts =~ s/\//:/;	# replaces / with a colon e.g. ABC/#Z23 becomes ABC:#Z23 (we don't care if inv/noninv)
			if (index($prodopts,':')>0) {
				$prodopts = substr($prodopts,index($prodopts,':'));	# ABC:#Z23 becomes just #Z23
				foreach my $set (split(/:/,$prodopts)) {
					next unless (length($set)==4);	# valid option sets are always 4 digits
					$options{ uc(substr($set,0,2)) } = uc(substr($set,2,2)); 
					}
				}



			##
			## STAGE2: look for passed values
			## 
			foreach my $pog_param (keys %{$cgiv}) {
				## iterate through URI parameters - looking for pog_[SUFFIX]_prompt pog_[SUFFIX]_cb 
				## SUFFIX is probably something like :pid or some such nonsense.
				next unless $pog_param =~ m/^pog_(.*?)(_prompt|_cb)?\Q$suffix\E$/;
				my ($pogid,$pogtype) = ($1,$2);

				next if (length($pogid)!=2);
				if (not defined $pogtype) { $pogtype = ''; }

				if ($pogtype eq '_prompt') {
					## text?
					$options{ uc($pogid) } = $pog_param;
					}
				if ($pogtype eq '_cb') {
					## CHECKBOX: Set the default of NO for a checkbox
					if (not defined $options{uc($pogid)}) {
						$options{uc($pogid)} = 'NO';
						}
					}
				else {
					## select, or other "fixed" type of option
					## also apparently some types of textareas.
					$options{uc($pogid)} = $cgiv->{$pog_param};
					}
				}


			$variations = \%options;
			## NOTE: there are cases - where we've only got "attribs" on a product, in which case
			##	we've got data in $item->{'pogs'} but we didn't get ANY options passed to us.
			## someday we'll probably need to deal with that condition here.
			}


		if ($quantity == 0) {
			## ignore situations where quantity is zero.
			}
		elsif (defined $P) {
			my ($iilm) = LISTING::MSGS->new($s2->username());
			my %cramparams = ();
				$cramparams{'claim'} = $CLAIM;
				$cramparams{'*P'} = $P;
				$cramparams{'*LM'} = $iilm;
				$cramparams{'zero_qty_okay'} = 1;

				if (($params{'is_admin'}) && (defined $cgiv->{'price'.$suffix}))  {
					$cramparams{'force_price'} = &SITE::untaint(def($cgiv->{'price'.$suffix}));
					}

			(my $item,$iilm) = $s2->cram( $PID, $quantity, $variations, %cramparams);
			$lm->merge($iilm,'%remap'=>{'ERROR'=>'CRAM-ERROR'});
			## use Data::Dumper; print STDERR Dumper($item,$iilm);

			#foreach my $msg (@{$ilm->msgs()}) {
			#	my ($msgref,$status) = &LISTING::MSGS::msg_to_disposition($msg);
			#	if ($status eq 'ERROR') { push @{$errorsref}, $msgref->{'+'}; }
			#	elsif ($status eq 'WARN') { push @{$errorsref}, $msgref->{'+'}; }
			#	}
			}
		elsif ($softcart) {

			my $price = &SITE::untaint(def($cgiv->{'price'.$suffix}));
			my $description = &SITE::untaint(def($cgiv->{'desc'.$suffix}));			
			my %softitem = ();
			$softitem{'taxable'}     = &SITE::untaint(def($cgiv->{'taxable'.$suffix}));
		   if (uc($softitem{'taxable'}) eq 'NO') { $softitem{'taxable'} = 0; }
			elsif (uc($softitem{'taxable'}) eq 'N') { $softitem{'taxable'} = 0; }

			$softitem{'base_weight'} = &SITE::untaint(def($cgiv->{'weight'.$suffix}));

			## added for stateofnine softcart integration - patti - 20111011, ticket 468088
			$softitem{'%attribs'} = {};
			$softitem{'%attribs'}->{'zoovy:prod_supplierid'}     = &SITE::untaint(def($cgiv->{'prod_supplierid'.$suffix}));
			$softitem{'%attribs'}->{'zoovy:prod_supplier'} = &SITE::untaint(def($cgiv->{'prod_supplier'.$suffix}));
			$softitem{'%attribs'}->{'zoovy:virtual'} = &SITE::untaint(def($cgiv->{'virtual'.$suffix}));
			
			$softitem{'is_softcart'} = 1;

			if (def($cgiv->{'notes'.$suffix})) {
				$softitem{'notes'}        = &SITE::untaint(def($cgiv->{'notes'.$suffix}));
				$softitem{'notes_prompt'} = &SITE::untaint(def($cgiv->{'notes_prompt'.$suffix}));
				}

			my ($item) = $s2->basic_cram( $stid, $quantity, $price, $description, %params);
			$lm->pooshmsg("SUCCESS|+Added $stid quantity $quantity to cart");
			}
		else {
			$lm->pooshmsg("STOP|+Product $stid is no longer available for purchase / does not exist.");
			}

		}

	return($s2,$lm);
	}

1;
