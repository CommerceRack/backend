package PAGE::cart;


# use URI::Split qw ();
use Digest::MD5 qw();
use Data::Dumper;
use Data::GUID;
use Encode qw();
use strict; # Modules verified!

require CART2;
require ZTOOLKIT;
require STUFF::CGI;
require LISTING::MSGS;	
sub pint { ZTOOLKIT::pint(@_); }
sub def { ZTOOLKIT::def(@_); }
sub gstr { ZTOOLKIT::gstr(@_); }


sub warn { my $msg = @_; print STDERR $msg."\n"; }

##
##
##
sub handler {
	my ($iniref,undef,$SITE) = @_;
		
	my $DEBUG = 1;
	
	my $v = $SITE::v;
	my $changed = 0;
	
	$SITE->URLENGINE()->set('sessions'=>1);
	my ($lm) = $SITE::CART2->msgs();
	
	# RESET CART (This one is used by developer users to make sure what they're sending over 
	#			is the only thing in the cart)
	if ((defined $v->{'reset'}) || (defined $v->{'empty.x'}) || (defined $v->{'empty'})) {
		$SITE::DEBUG && &warn("Resetting cart");
		$SITE::CART2->empty();
		}
	
	## Set the softcart and allow_negative variables (only good if the user is a developer)
	my $softcart = int($SITE::OVERRIDES{'dev.softcart'});

	if ($softcart) {
		$DEBUG && &warn('Processing dev flag settings');
		## If we have the softcart enabled, then we have to check for valid referers
		## Reset softcart to zero (the referer is guilty until proven innocent)
		$softcart = 0;
		## Loop over all of the allowed referers and see if the current referer passes muster
		## Links from their zoovy site are OK, in addition to any others specified in dev_softcart_referers
		my $USERNAME = lc($SITE->username());
		foreach (
			split(/[\n\r]+/, def($SITE::OVERRIDES{'dev.softcart_referers'})),
			#"http://$USERNAME.zoovy.com",
			#"http://www.$USERNAME.zoovy.com",
			#"https://ssl.zoovy.com/$USERNAME",
			#"https://ssl.zoovy.com/s=$USERNAME",
			#"https://www.zoovy.com/"
			) {
			# s/^[\s]+//g; s/[\s]+$//g; ## Strip leading and trailing space
			next if ($_ eq ''); ## Skip blank rows
			## Do we have the word 'any' in the list?  If then all referers are OK
			if (lc($_) eq 'any') { $softcart = 1; last; }
			## Does the referer match the beginning of the match string?
			if ($ENV{'HTTP_REFERER'} =~ m/^\Q$_\E/i) { $softcart = 1; last; }
			}
		$DEBUG && &warn("Soft cart is $softcart");
		}
	

	# UPDATE QUANTITIES FROM FIELDS
	# this is where the quantity is updated if you press "UPDATE QUANTITIES" in the cart
	my $update = {}; # Hash of all of the updates to the cart
	foreach my $param (keys %{$v}) {
		# loop through each CGI param search for qty-
		next unless($param =~ m/^qty-(.*)$/);
		my ($stid) = $1;
		my ($update_qty) = int($v->{$param});
		if ($update_qty < 0) {$update_qty = 0;} 
		if (defined($update_qty)) { 
			$update->{$1} = $update_qty; 
			$SITE::CART2->stuff2()->update_item_quantity('stid'=>uc($stid),$update_qty,'*LM'=>$lm);
			}
		}
		
	# Perform the update to the cart if we found quantities to update
	#if (scalar keys %{$update}) {
	#	$DEBUG && &warn("Updating product quantities");
	#	$SITE::CART2->stuff2()->update_quantities($update);
	#	}
	

	
	##
	## NOTE: a considerable amount of code was migrated from this section
	##			to STUFF::CGI::parse_products 
	##			so it could be shared with the pogwizard. (and eventually configurator)
	##
	# my ($s2) = STUFF2->new($SITE->username());

	my ($s2) = STUFF2->new($SITE->username());  ## we need to handle these items separately (for now) since we can't 
	$s2->link_cart2($SITE::CART2);
													 ## easily isolate/group them in the stuff2 object [[yet]] 
	($s2,$lm) = &STUFF::CGI::legacy_parse($s2,$SITE::v,'softcart'=>$softcart,'*LM'=>$lm);

	if (defined $SITE::v->{'errmsg'}) {
		## this is used by other applications to pass errmsgs to the cart.
		$lm->pooshmsg("ERROR|+$SITE::v->{'errmsg'}");
		}

	if ($SITE->client_is() eq 'BOT') {
		$lm->pooshmsg("ERROR|+Your IP address (".$SITE->ip_address().") has been flagged as a ROBOT - you will not be able to make purchases."); 
		}
	elsif ($SITE->client_is() eq 'SCAN') {
		$lm->pooshmsg("ERROR|+Your IP address (".$SITE->ip_address().") has been flagged as SCANNER - you will not be able to make purchases."); 
		}

	##
	## A check to see if we're re-adding the same items to the cart!
	if (scalar($s2->count())>0) {
		my $str = '';
		if ($ENV{'REQUEST_METHOD'} eq 'GET') { 
			## Handle GET
			$str = $ENV{'QUERY_STRING'}; 
			}
		else {
			## Handle POST
			foreach my $k (sort keys %{$SITE::v}) {
				$str .= "$k=".$SITE::v->{$k}."|";
				}
			}
		$str = Digest::MD5::md5_base64(&Encode::encode_utf8($str));
		if ($ENV{'SERVER_ADDR'} eq '192.168.99.12') { $str = ''; }

		my ($lad) = $SITE::CART2->in_get('app/last_add_digest');
		if ((defined $lad) && ($lad eq $str) && ($str ne '')) {
			## this is a duplicate!
			$s2 = undef;
			$lm->pooshmsg("STOP|+Encountered identical add to cart request, please add a different item, or update the item quantities manually.");
			}
		else {
			$SITE::CART2->in_set('app/last_add_digest',$str);
			}
		}
	## End duplicate add check
	##

	#my $success = 0;
	#foreach my $msg (@{$lm->msgs()}) {
	#	my ($msgref,$status) = LISTING::MSGS::msg_to_disposition($msg);
	#	if ($status eq 'ERROR') { push @errors, $msgref->{'+'}; }
	#	if ($status eq 'WARN') { push @errors, $msgref->{'+'}; }
	#	if ($status eq 'STOP') { push @errors, $msgref->{'+'}; }
	#	}

	my @MEMORY_CART = ();

	if ((not defined $s2) || (ref($s2) ne 'STUFF2')) {
		$lm->pooshmsg("WARN|+s2 is Invalid STUFF2 object -- cannot add to cart");
		}
	else {
		foreach my $item (@{ $s2->items() }) {
			## WTF -- why is this here?

			if ((defined $item->{'asm_master'}) && ($item->{'asm_master'} ne '')) {
				## force price to zero for assembly items so they can be added
				## otherwise items with price of '' can't be added.
				$item->{'base_price'} = 0;
				}

			if ($item->{'qty'}<=0) { 
				# if we dont' do this then certain items which have no price will throw errrs.
				# when sent from a multi-item prodlist.
				# die();
				}
			elsif ((defined $item->{'base_price'}) && ($item->{'base_price'} eq '')) {
				## if we have a price, and it's not set, then it's not purchasable.
				$lm->pooshmsg("ISE|+SKU: $item->{'sku'} base_price on item is not set, cannot add to cart.");
				# die();
				}
			else {
				#my $schedule = $SITE::CART2->schedule();
				#my $expires = 0;
				#if ((not defined $schedule) || ($schedule eq '')) {
				#	## no global wholesale schedule... so:
				#	my ($pid) = $item->{'pid'};
				#	if ($pid eq '') { $pid = $item->{'product'}; } 	## thank anthony for not having good naming conventions!
				#	if (not defined $pid) { $pid = $item->{'sku'}; }
				#	if (not defined $pid) { $pid = $item->{'stid'}; }
				#	if (($pid) && ( my $cpn = $self->coupons(product=>$pid) )) {
				#		$schedule = $cpn->[0]->{'schedule'};
				#		$expires = $cpn->[0]->{'expires_gmt'};
				#		}
				#	$self->debug('CART','INFO',"Adding $pid | schedule=$schedule expires=$expires");
				#	#use Data::Dumper; $self->debug('CART','DUMP',Dumper($item));
				#	}


				my ($existingitem) = $SITE::CART2->stuff2()->item('stid'=>$item->{'stid'});
				if (defined $existingitem) {
					## item doesn't exist, add it## item exists, update quantity
					my %STIDS_IN_CART = ();
					foreach my $item (@{$SITE::CART2->stuff2()->items()}) {
						$STIDS_IN_CART{ $item->{'stid'} }++;
						}

					if ($existingitem->{'%options'}) {
						foreach my $pogidval (keys %{$existingitem->{'%options'}}) {
							## look for any option ZZ##
							if (substr($pogidval,2,2) eq '##') {
								$lm->pooshmsg("DEBUG|+Item '$existingitem->{'stid'}' was left in cart because pogset '$pogidval' requires it be unique");
								$existingitem = undef;
								}
							}
						}
					
					if (not defined $existingitem) {
						## now set a unique uuid and stid value
						$item->{'uuid'} = Data::GUID->new()->as_string();
						my $STID = substr($item->{'stid'},0,-5);	# strip /##00
						foreach my $i (0..99) {
							next if (defined $STIDS_IN_CART{sprintf("$STID/##%2d",$i)});
							$item->{'stid'} = sprintf("$STID/##%2d",$i);
							last; 
							}
						}
					}
	
				if (defined $existingitem) {
					## item exists, update quantity
					$SITE::CART2->stuff2()->drop('uuid'=>$existingitem->{'uuid'});
					$existingitem = undef;
					}
	
				## item does not exist, add it.
				$lm->pooshmsg("INFO|+Added item '$item->{'stid'}' quantity $item->{'qty'}");
				$SITE::CART2->stuff2()->fast_copy_cram($item);
	
				## remember which products we've added to the cart.
				push @MEMORY_CART, $item->{'product'};
				}
			}
		}

	## add any PIDS we just handled to memory_cart
	my @pids = split(/,/ &ZTOOLKIT::def($SITE::CART2->pu_get('app/memory_cart')));
	foreach my $pid (@pids) { push @MEMORY_CART, $pid; }

	if (scalar(@MEMORY_CART)==0) {
		}
	else {
		# print STDERR 'MEMORY_CART: '.Data::Dumper::Dumper(\@MEMORY_CART)."\n";
		## note: this tracks a successful "addEvent" of one or more items.
		my $event_count = int($SITE::CART2->pu_get('app/add_event_count'))+scalar(@MEMORY_CART);
		$SITE::CART2->pu_set('app/add_event_count', $event_count );
		$SITE::CART2->pu_set('app/memory_cart', join(",",splice(@MEMORY_CART,0,10)) ); 
		}
	
	# DELETE ITEM
	if (defined($v->{'delete_item'})) {
		$DEBUG && &warn("Deleting item ".$v->{'delete_item'});
		$SITE::CART2->in_set('app/last_add_digest',undef);
		# $SITE::CART2->recalc();
		$SITE::CART2->stuff2()->drop('stid'=>$v->{'delete_item'});
		}
	
	
	# $lm->pooshmsg("DEBUG|+STARTING PROMO CODE");
	if (defined $v->{'promocode'}) {
		## eventually we'll need code here to determine which one it is.

		## NOTE: the input length is *intentionally* 10 characters so merchants can use "shared" coupon codes with
		##			other foreign systems, but after 10 characters, they are just being fucking stupid and
		##			we should smack them in the head!
		if (length($v->{'promocode'})<=10) {
			## a promo code of less than 6 digits is a coupon!
			$v->{'couponcode'} = substr($v->{'promocode'},0,8);
			}

		my $x = $v->{'promocode'};
		$x =~ s/[\-\t\n\r\s]+//gs;	## users might put in dashes, but we kill 'em.

		if (length($x)==16) {
			require GIFTCARD;
			if (GIFTCARD::checkCode($x)==0) {
				$v->{'giftcardcode'} = $x;
				}
			}
		}

	if (defined $v->{'couponcode'}) {
		my @errors = ();
		$SITE::CART2->add_coupon($v->{'couponcode'},\@errors,undef,'SITE');
		foreach my $err (@errors) { $lm->pooshmsg("ERROR|+$err"); }
		}

	if (defined $v->{'giftcardcode'}) {
		## first thing we need to do is figure out
		$lm->pooshmsg("INFO|+Looks like we might have a giftcard");
		my @errors = ();
		$SITE::CART2->add_giftcard($v->{'giftcardcode'},\@errors);
		foreach my $err (@errors) { 
			$lm->pooshmsg("ERROR|+$err"); 
			}
		}

#	if (defined $v->{'giftcardcode'}) {
#		$SITE::CART->add_giftcard($v->{'giftcard'},\@errors);
#		}

	# UPDATE QUANTITIES FROM INVENTORY AVAILABILITY

	if (not $softcart) {
		##
		## upper level wrapper around cart which verifies inventory
		##
		##	note: %options
		##		pretty=>1|0  -- if true, uses SITE::msgs to output pretty warnings
		##							 if false, output SKU|qtyavail
		##			
		## called from PAGE::cart (maybe others?)
		##
		my $gref = &ZWEBSITE::fetch_globalref($SITE::CART2->username());

		## inventory is disabled by schedule

		## okay we're really going to be checking inventory, so lets default some settings.

		my %before = ();	
		foreach my $item (@{$SITE::CART2->stuff2()->items('real')}) {
			next if ($item->{'is_basic'}>0); 	## basic (softcart?) items don't get inventory checks
			next if ($item->{'force_qty'}>0);	## force_qty means it's all good.
			$before{$item->{'stid'}} = $item->{'qty'};
			}

		my @warnings = ();

		## if we ignore inventory, the we can 
		my ($update) = INVENTORY2->new($SITE::CART2->username())->verify_cart2($SITE::CART2,'%GREF'=>$gref);

		if (defined($update) && (scalar keys %{$update})) {
			foreach my $sku (keys %{$update}) {	
				# push @warnings, "SKU: $sku";

				my $warning = $sku.'|'.$update->{$sku};
				# Message: "Changed quantity of $sku from $before{$sku} to $update->{$sku} $reason";
				## Message: "Item $sku not added to cart $reason : out of stock message"; 
				$warning = $SITE->msgs()->get('inv_cart_add_warning',{ 
					'%%SKU%%'=>$sku, '%%REQUESTQTY%%'=>$before{$sku}, '%%ACTUALQTY%%'=>$update->{$sku},}
					);
				push @warnings, $warning;

				my $item = $SITE::CART2->stuff2()->item('stid'=>$sku);
				$SITE::CART2->stuff2()->update_item_quantity( 'stid'=>$sku, $update->{$sku}, '*LM'=>$lm);
				}

			# $SITE::CART2->stuff2()->update_quantities($update);
			foreach my $msg (@{$lm->msgs()}) {
				my ($ref) = LISTING::MSGS::msg_to_disposition($msg);
				next if ($ref->{'_'} eq 'INFO');
				next if ($ref->{'_'} eq 'DEBUG');	# might want to just show this for zoovy
				push @warnings, "$ref->{'_'} : $ref->{'+'}";
				}		
			}
	
		my $warnings = \@warnings;
		## my ($warnings) = $SITE::CART2->check_inventory('*SITE'=>$SITE,pretty=>1);	
		if (int($SITE::CART2->__GET__('is/inventory_exempt'))) { 
			# we use internal __GET__ to avoid a sync.
			}	
		elsif ((defined $warnings) && (scalar(@{$warnings})>0)) {
			foreach my $msg (@{$warnings}) { $lm->pooshmsg("WARN|+$msg"); }
			}
		}

	## BUYSAFE CRAP (is this really necessary?)
	if (defined $SITE::v->{'ship.bnd_purchased'}) {
		$SITE::CART2->in_set('want/bnd_purchased',int($SITE::v->{'ship.bnd_purchased'}));
		# $SITE::CART2->recalc();
		}
	
	# CHECKOUT
	my $count = $SITE::CART2->count('show'=>'real');		# 1 = don't count meta items
	
	if (
		$count &&
		($lm->can_proceed()) &&
		((defined $v->{'checkout.x'}) || (defined $v->{'checkout'}))
		) {
		# Check cart_count above too, so they don't get an ugly cookies error
		# for getting to checkout with nothing in the cart.
		## NOTE: checkout=1 is also passed from the claim page (e.g. AOL express checkout)
		$SITE->pageid( '?REDIRECT/301|cart - checkout redirect' );
		$SITE::REDIRECT_URL = $SITE->URLENGINE()->get('checkout_url');

		if ($SITE::v->{'sender'}) {
			$SITE::REDIRECT_URL .= '?SENDER='.$SITE::v->{'sender'}.'&STAGE='.$SITE::v->{'stage'};
			}
		return();
		}
	
	# GET THE RETURN URL
	my $continue_url = $SITE->continue_shopping_url($v->{'return'});
	if ($SITE->continue_shopping_url() eq 'origin') {
		$continue_url = $SITE->URLENGINE()->rewrite($ENV{'HTTP_REFERER'});
		}

	if ($continue_url eq '') {
		}
	elsif ($v->{'return'} =~ /\/\/(.*)[\/]?/) {
		## make sure, if we're redirecting to a host, that it's a valid host.
		my $DOMAIN = lc($1);
		if (index($DOMAIN,'/')>0) { $DOMAIN = substr($DOMAIN,0,index($DOMAIN,'/')); }
		if ($DOMAIN =~ /^(www|secure)\.(.*?)$/) { $DOMAIN = $2; }

		#if ($DOMAIN eq "$SITE::merchant_id.zoovy.com") {
		#	## username.zoovy.com is always valid 
		#	$owner = $SITE::merchant_id;
		#	}
		#elsif ($DOMAIN eq "https://ssl.zoovy.com/$SITE::merchant") {
		#	## ssl.zoovy.com is always valid 
		#	$owner = $SITE::merchant_id;
		#	}

		# if (not defined $owner) {
		## otherwise it needs to be one of our domains
		my ($owner) = &DOMAIN::TOOLS::domain_to_userprt($DOMAIN);
		$owner = lc($owner);
		#	}

		if ($SITE->username() ne $owner) {
			$continue_url = $SITE->URLENGINE()->get('continue_url').'?reason=redirect_not_allowed';
			# &ZOOVY::confess($SITE::merchant_id,"oh-no returning to: $continue_url\nDOMAIN: $DOMAIN\nOWNER: $owner\n",justkidding=>1);
			}
		}
	else {
		## this line should NEVER be reached
		$continue_url = $SITE->URLENGINE()->get('continue_url').'?reason=redirect_invalid';
		# &ZOOVY::confess($SITE::merchant_id,"Aiieeee on: $continue_url\n",justkidding=>1);
		}

#	# whitelist the URI
#	my ($scheme, $auth, $path, $query, $frag) = URI::Split::uri_split($continue_url);
#	if ($auth =~ /.\zoovy\.com$/) {
#		}
#	else {		
#		my ($u,$p) = &DOMAIN::TOOLS::domain_to_userprt($auth);
#		if ($u eq '') { 
#			print STDERR ("Attempt to redirect to: $auth was discarded due to lack of whitelist\n"); 
#			$continue_url = '';
#			}
#		}
	
	if ((not defined $continue_url) || ($continue_url eq '')) {
		$continue_url = $SITE->URLENGINE()->get('continue_url');
		}
	
	print STDERR "CONTINUE: $continue_url\n";

	# CONTINUE SHOPPING
	if ((defined $v->{'continue.x'}) || (defined $v->{'continue'})) {
		$SITE->pageid( '?REDIRECT/requires login' );
		$SITE::REDIRECT_URL = $continue_url;
		return();
		}

	if    ($count == 0) { $SITE->title( "You have nothing in your shopping cart" ); }
	elsif ($count == 1) { $SITE->title( "You have 1 item in your shopping cart" ); }
	else                { $SITE->title( "You have $count items in your shopping cart" ); }
	
	$SITE->continue_shopping_url($continue_url);                 ## Where to go when they click "Continue Shopping"
	
	##############################################################################
	## Output Page
	
	my $OUTPUT = '';
	my $TH = $SITE::CONFIG->{'%THEME'};

	foreach my $msg (@{$lm->msgs()}) {
		my ($ref,$status) = LISTING::MSGS::msg_to_disposition($msg);

		my $msg = $ref->{'+'};
		$msg =~ s/^[\+]+//gs;
		$msg =~ s/<!--//gs;
		$msg =~ s/-->//gs;
		$OUTPUT .= qq~<!-- $ref->{'_'} $msg -->\n~;
		if ($ref->{'_'} =~ /^(INFO|ISE|WARN|ERROR)$/) {
			$OUTPUT .= qq~<div class="zwarn z$ref->{'_'}">$msg</div>~;
			}
		}


	push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>$OUTPUT };
	return();
	}

1;	
	
	