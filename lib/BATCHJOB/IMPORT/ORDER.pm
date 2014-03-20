package BATCHJOB::IMPORT::ORDER;

##
## 
## originally built to import FBA orders
##	 (should now be flexible enough to handle other types of order imports)
##
## example header [FBA]:
##
## #GROUP_BY=erefid				## if order has multiple items (ie multiple rows in csv file)
##                         	   ## use the erefid to group items together
##	#STATUS=COMPLETED          ## order has already been shipped
##	#DECREMENT_INV=N           ## inv is decremented from Amazon Fulfillment Center
##	#ORDER_EMAIL=N      			## don't send email to customer
##	#PAYMENT_METHOD=AMAZON     ## means checkout happened on Amazon.com
##	#PAYMENT_STATUS=010        ## 010=PAID via AMAZON.com
##	#DST=FBA                   ## FBA => destination code for Fulfillment By Amazon
##	#SEP_CHAR=\t					## how the import file is separated ( , \t )
##
##

use strict;
use Data::Dumper;
use lib "/backend/lib";
require CART2;
use ZCSV;
use STUFF2;
use LISTING::MSGS;


sub parseorder {
	my ($bj,$fieldsref,$lineref,$optionsref,$errors) = @_;

	my ($USERNAME,$LUSERNAME,$PRT) = ($bj->username(),$bj->lusername(),$bj->prt());

	## all these GLOBAL vars can be set in the header
	my $GLOBAL_CREATE_DATE = '';
	my $GLOBAL_YYYY_MON = '';
	
	# STATUS => RECENT,PENDING,APPROVED,COMPLETED,DELETED,ARCHIVE,BACKORDER
	## defaults to RECENT
	my $GLOBAL_STATUS = $optionsref->{'STATUS'}; 
	# PAYMENT STATUS => 000=PAID,010=PAID via AMAZON.com,050=PAID via PAYPAL,100=PENDING,200=DENIED,300=CANCELLED
	## defaults to PENDING
	my $GLOBAL_PAYMENT_STATUS = $optionsref->{'PAYMENT_STATUS'};
	# PAYMENT_METHOD => AMAZON,CREDIT,PAYPAL,CASH,OTHER
	## defaults to blank
	my $GLOBAL_PAYMENT_METHOD = $optionsref->{'PAYMENT_METHOD'};
	# DST - syndication dstcode
	my $GLOBAL_DST = $optionsref->{'DST'};
	# ORDER_CREATE_EMAIL 
	## SDOMAIN
	my $GLOBAL_SDOMAIN = $optionsref->{'SDOMAIN'};

	## when a sku doesn't exist should we error, or create basic files
	$optionsref->{'CREATE_BASIC_ITEMS'} = &ZOOVY::is_true($optionsref->{'CREATE_BASIC_ITEMS'});

	# SEPARATOR
	## defaults to comma [,]
	my $SEP_CHAR = ($optionsref->{'SEP_CHAR'} ne '')?$optionsref->{'SEP_CHAR'}:',';
	
	## stores the GROUP_BY value and the orderid associated with it
	## example: patti@zoovy.com 		=> 2011-01-44444, for GROUP_BY %EMAIL
	##				201-0002992-8342897	=> 2011-01-44443, for GROUP_BY %EREFID
	# my $GLOBAL_GROUP_BY = lc($optionsref->{'GROUP_BY'});


	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $lm = LISTING::MSGS->new($USERNAME);
	$lm->set_batchjob($bj);

	if ($optionsref->{'GROUP_BY'} eq '') {
		$lm->pooshmsg("ERROR|+header GROUP_BY is a required for ORDER imports");
		}

	my $ctr = 0;


	my %ORDERS = ();
	## 	%ORDERS is: 
	##	 'groupby1'=>{  '%DATA'=>{}, '@CSVITEMS'=>[ { %SKU=>'' } ] },
	##	 'groupby2'=>{  '%DATA'=>{}, '@CSVITEMS'=>[ { %SKU=>'' } ] }
	##	

	##
	## PHASE0: preflight, identify grouping column
	##
	$bj->slog("Phase 0: identify grouping column");	
	my $GROUPBY_COLUMN = -1;
	if ($lm->can_proceed()) {
		## figure out grouping column
		my $pos = 0;
		foreach my $destfield (@{$fieldsref}) {	
			## create temp hash to hold order contents
			if ($GROUPBY_COLUMN>=0) {
				}
			elsif ($destfield eq $optionsref->{'GROUP_BY'}) {
				$GROUPBY_COLUMN = $pos;
				}
			elsif (($optionsref->{'GROUP_BY'} eq '%EREFID') && ($destfield eq 'erefid')) {
				## backward compatible hack since EREFID can be set at both product and order level
				$GROUPBY_COLUMN = $pos;
				}
			elsif (($optionsref->{'GROUP_BY'} eq 'erefid') && ($destfield eq '%EREFID')) {
				## backward compatible hack since EREFID can be set at both product and order level
				$GROUPBY_COLUMN = $pos;
				}
			$pos++;
			}
		if ($GROUPBY_COLUMN == -1) {
			$lm->pooshmsg("ERROR|+Could not locate GROUPBY '$optionsref->{'GROUP_BY'}' column");
			}
		else {
			$lm->pooshmsg("INFO|+Found grouping column $GROUPBY_COLUMN '$optionsref->{'GROUP_BY'}'");
			}
		}


	##
	##  PHASE1: go thru each CSV line, populate %ORDERS
	##
	$bj->slog("Phase 1: process lines and organize data into hierarchy");	
	my $linecount = 0;
	foreach my $line ( @{$lineref} ) {

		my %order = ();

		my $ERROR = '';	## ERROR's are per line

		my @DATA = &ZCSV::parse_csv($line,{SEP_CHAR=>$SEP_CHAR});
		next if ($DATA[0] =~ /^\#/);		## skip header lines

		$linecount++;
		next if (($DATA[0] eq '') && (scalar(@DATA)==1) && ($optionsref->{'SKIP_BLANK_LINES'} eq 'Y'));

		my $GROUPBY = $DATA[$GROUPBY_COLUMN];
		my $THIS_ORDER = undef;
		my $IS_FIRST_LINE_OF_GROUP = 0;
		if ($GROUPBY eq '') {
			$lm->pooshmsg("ERROR|+line[$linecount] - GROUPBY column (#$GROUPBY_COLUMN) is blank");
			}
		elsif (not defined $ORDERS{$GROUPBY}) {
			## new order/groupby
			$IS_FIRST_LINE_OF_GROUP++;
			$lm->pooshmsg("INFO|+line[$linecount] - NEW GROUP '$GROUPBY'");
			$THIS_ORDER = $ORDERS{$GROUPBY} = {};
			$THIS_ORDER->{'%CSV'} = {};
			$THIS_ORDER->{'@CSVITEMS'} = [];
			$THIS_ORDER->{'*LM'} = LISTING::MSGS->new($USERNAME);
			$THIS_ORDER->{'*LM'}->set_batchjob($bj);
			}
		else {
			## existing group
			$lm->pooshmsg("INFO|+line[$linecount] - ADD TO GROUP '$GROUPBY'");
			$THIS_ORDER = $ORDERS{$GROUPBY};
			}

		next if (not $THIS_ORDER);	## if this is true, we don't have an order, we'll probably error out.

		my %THIS_ITEM = ();
		$THIS_ITEM{'_'} = "Line[$linecount]";
		
		## PHASE0: go through and detect the order, see if it exists.
		##
		## go thru columns, populate order hash
		##
		my $pos = 0; # $pos keeps track of which field in the @DATA array we are on.
		foreach my $destfield (@{$fieldsref}) {					
			if ($destfield eq '') {
				## blank destfield (ignore)
				}
			elsif ($DATA[$pos] eq '') {
				## blank data field, ignore
				} 
			elsif (substr($destfield,0,1) eq '!') {
				## ignore columns that start with a !
				}
			elsif (substr($destfield,0,1) eq '%') {
				# % fields
				# %EREFID will create an order with for a given DST using %EREFID as the erefid
				# %ORDERID will allocate an order-id in the format YYYY-MM-#####
				# %SKU will create a placeorder for a particular sku in an order contents hash
				# %DESCRIPTION
				# %QTY 
				# %WEIGHT
				# %PRICE
				# %PROMO
				# %GIFT_WRAP_PRICE
				# %GIFT_WRAP_TAX
				# %SHIPPING
				# %SHIPPING METHOD
				# %SHIPPING CARRIER
				# %TRACKING NUMBER
				if ($destfield eq '%EREFID') {
					$THIS_ORDER->{'%CSV'}->{'erefid'} = $DATA[$pos];
					}
				elsif ($destfield eq '%EMAIL') { 
					$THIS_ORDER->{'%CSV'}->{'bill_email'} = $DATA[$pos]; 
					}
				elsif ($destfield eq '%FULLNAME') { 
					$THIS_ORDER->{'%CSV'}->{'bill_fullname'} = $DATA[$pos]; 
					$THIS_ORDER->{'%CSV'}->{'ship_fullname'} = $DATA[$pos]; 
					}
				$THIS_ITEM{$destfield} = $DATA[$pos];
				}	
			elsif (not defined $THIS_ORDER->{'%CSV'}->{$destfield}) {
				# example: bill_fullname,bill_email,bill_phone,bill_address1,bill_address2,bill_city,bill_state,bill_zip,bill_country,bill_phone
				## new value (best case scenario)
				$THIS_ORDER->{'%CSV'}->{$destfield} = $DATA[$pos];
				}
			elsif ($THIS_ORDER->{'%CSV'}->{$destfield} eq $DATA[$pos]) {
				## it's the same (ignore it)
				}
			else {
				$THIS_ORDER->{'%CSV'}->{$destfield} = $DATA[$pos];
				$THIS_ORDER->{'*LM'}->pooshmsg("WARN|+GROUP '$GROUPBY' FIELD $destfield differs between lines was '$THIS_ORDER->{'%CSV'}->{$destfield}' - now '$DATA[$pos]'");
				}
			$pos++;  # move to the next field that we should parse
			}	
		## columns are processed.

		if (scalar(keys %THIS_ITEM)>0) {
			push @{$THIS_ORDER->{'@CSVITEMS'}}, \%THIS_ITEM;
			}
		else {
			$lm->pooshmsg("WARN|+GROUP '$GROUPBY' LINE[$linecount] had no item level data [possible corruption?]");
			}

		}



	##
	##	 PHASE2: 
	##
	$bj->slog("Phase 2: validate hierarchy");	
	if (not $lm->can_proceed()) {
		$bj->slog("Phase2 was skipped due to earlier errors");
		}
	else {

#		my %CONTENTS = ();
#		my $SHIPPING = 0;
#		my $SHIPPING_PROMO = undef;
#		my $TRACKING_NUMBER = undef;
#		my $SKU = undef; 
#		my $DESCRIPTION = undef; 
#		my $ORDERID = undef; 
#		my $QTY =undef; 
#		my $WEIGHT =undef; 
#		my $PRICE = undef; 
#		my $PROMO = undef;
#		my $GIFT_WRAP_PRICE = undef;
#		my $TAX = undef;								## need to add support for TAX
#		my $CREATE_DATE = $GLOBAL_CREATE_DATE;
#		my $POST_DATE = undef;
#		my $YYYY_MON = $GLOBAL_YYYY_MON;
#			

		foreach my $GROUPBY (sort keys %ORDERS) {
			my $THIS_ORDER = $ORDERS{$GROUPBY};
			my $HISTORY = $THIS_ORDER->{'@HISTORY'} = [];
			my $stuff2 = $THIS_ORDER->{'*STUFF2'} = STUFF2->new($USERNAME);
			my $DATA = $THIS_ORDER->{'%DATA'} = {};
			my $olm = $THIS_ORDER->{'*LM'};

			my $SHIPPING = 0;
			foreach my $csvitem (@{$THIS_ORDER->{'@CSVITEMS'}}) {
				my $SKU = $csvitem->{'%SKU'};
				push @{$HISTORY}, "PROCESSING $SKU";
				my $P = undef;
				if ($SKU eq '') {
					$olm->pooshmsg("ERROR|+$csvitem->{'_'} item had no SKU");
					}
				elsif ($csvitem->{'%QTY'} == 0) {
					$olm->pooshmsg("ERROR|+$csvitem->{'_'} item had no QTY");
					}				
				else {
					my ($PID) = PRODUCT::stid_to_pid($SKU);
					$P = PRODUCT->new($USERNAME, $PID, 'create'=>0);
					if (defined $P) { 
						}
					elsif ($optionsref->{'CREATE_BASIC_ITEMS'}) {
						$olm->pooshmsg("WARN|+$csvitem->{'_'} reference SKU $SKU does not exist");
						}
					else {
						$olm->pooshmsg("ERROR|+$csvitem->{'_'} reference SKU $SKU does not exist"); 
						}
					}

				if (defined $csvitem->{'%SHIPPING_PROMO'}) {
					## WTF is this?
					$csvitem->{'%SHIPPING_PROMO'} =~ s/[^0-9^\.]+//gs;
					$SHIPPING += $csvitem->{'%SHIPPING_PROMO'};
					}
				if (defined $csvitem->{'%SHIPPING'}) {
					## WTF is this?					
					$csvitem->{'%SHIPPING'} =~ s/[^0-9^\.\-]+//gs;
					$SHIPPING += $csvitem->{'%SHIPPING'};
					}
#				if ($csvitem->{'%PROMO'}) { $THIS_ITEM{'PROMO'} = $DATA[$pos]; }
#				if ($csvitem->{'%GIFT_WRAP_PRICE'}) { $THIS_ITEM{'GIFT_WRAP_PRICE'} = $DATA[$pos]; }	

				if ($csvitem->{'%EREFID'}) {
					my $found_oid = CART2::lookup($USERNAME,'EREFID'=>$csvitem->{'%EREFID'});
					if ($found_oid ne '') {
						$THIS_ORDER->{'ORDERID'} = $found_oid;
						$olm->pooshmsg("WARN|+EREFID '$csvitem->{'%EREFID'}' already used '$found_oid' (running verify instead of create)");
						## order exists, and it was created before this import
						}
					$DATA->{'want/erefid'} = $csvitem->{'%EREFID'};	
					}

				my $PRICE = undef;
				if ($csvitem->{'%PRICE'}) {
					$csvitem->{'%PRICE'} =~ s/[^0-9\.]//g;
					$PRICE = ((defined $PRICE)?$PRICE:0)+ $csvitem->{'%PRICE'};
					}
				if ($csvitem->{'%PROMO'}) {
					## if a PROMO is given, apply it before dividing out the qty
					$csvitem->{'%PROMO'} =~  s/[^0-9\.]//g;
					$PRICE = ((defined $PRICE)?$PRICE:0)+ $csvitem->{'%PROMO'};
					}
				if ($csvitem->{'%GIFT_WRAP_PRICE'}) {
					## if there is a GIFT_WRAP_PRICE, apply it before dividing out the qty
					$csvitem->{'%GIFT_WRAP_PRICE'} =~ s/[^0-9\.]//g;
					$PRICE = ((defined $PRICE)?$PRICE:0)+ $csvitem->{'%GIFT_WRAP_PRICE'};
					}

				### took this out, don't think this is actually used this way
				### ie PRICE is price per item vs extended price
				## PRICE => total price, need to divide by qty to get price per item
				#$PRICE = $PRICE/$QTY;

				#$DESCRIPTION =~ s/\<(.*?)\>//gs;	## 
				if ($csvitem->{'%DESCRIPTION'}) {
					$csvitem->{'%DESCRIPTION'} = ZTOOLKIT::htmlstrip($csvitem->{'%DESCRIPTION'}); 
					$csvitem->{'%DESCRIPTION'} =~ s/[\n\r]+//g;
					}

				
				##
				## ADD ITEM
				## 
				if (not defined $P) {
					if ($optionsref->{'CREATE_BASIC_ITEMS'}) {
						## add a basic item
						$stuff2->basic_cram($SKU,int($csvitem->{'%QTY'}),$csvitem->{'%PRICE'},$csvitem->{'%DESCRIPTION'});
						}
					elsif ($SKU eq '') {
						}
					else {
						$olm->pooshmsg("ERROR|SKU '$SKU' does not exist and CREATE_BASIC_ITEMS not allowed");
						}
					}
				else {
					## a real item
					my %params = ();
					if ($GLOBAL_DST) { 
						## product level stores AMZ vs the bitwise value
						$params{'mkt'} = $GLOBAL_DST; 
						}
					if ($csvitem->{'%WEIGHT'}) { 
						## may need to convert at some point in the future						
						$params{'force_weight'} = int($csvitem->{'%WEIGHT'}); 
						}

					my $ilm = $params{'*LM'} = LISTING::MSGS->new($USERNAME);
					if ($csvitem->{'%PRICE'}) { $params{'force_price'} = $csvitem->{'%PRICE'}; }
					my $recommended_variations = $P->suggest_variations('guess'=>1,'stid'=>$SKU);
					my ($variations) = STUFF2::variation_suggestions_to_selections($recommended_variations);
					my ($item) = $stuff2->cram( $SKU, int($csvitem->{'%QTY'}), $variations, %params);
					
					## note: it may take warnings if an option is invalid, but arrgh.. this is has to work for now.
					## ex: THISISMYSKU:A0100	(typo on newegg) -- $item gets returned with ERROR message saying
					##			option dropped, since A0100 isn't valid at all.
					if ($ilm->can_proceed()) {
						$olm->merge($ilm);
						if (defined $csvitem->{'%DESCRIPTION'}) {
							$item->{'prod_name'} = $csvitem->{'%DESCRIPTION'};
							$item->{'description'} = $csvitem->{'%DESCRIPTION'};
							}
						}
					elsif ($optionsref->{'CREATE_BASIC_ITEMS'}) {
						$olm->merge($ilm,'%mapstatus'=>{ 'ERROR'=>'ITEM-ERROR','POGERROR'=>'ITEM-ERROR' });
						$stuff2->basic_cram(
							$SKU,int($csvitem->{'%QTY'}),$csvitem->{'%PRICE'},$csvitem->{'%DESCRIPTION'},
								'notes'=>"Invalid SKU"
								);
						}
					else {
						$olm->pooshmsg("ERROR|+SKU '$SKU' had error being added, and CREATE_BASIC_ITEMS is not allowed.");
						}

					#if ($SKU eq 'RSI-4333_1-B2:AI100') {
					#	die(Dumper($lm,$item,$ilm));
					#	}
					}






				## note some other fields like %SHIPPING_METHOD, %SHIPPING_CARRIER will be processed later
				foreach my $csvitem (@{$THIS_ORDER->{'@CSVITEMS'}}) {
					if ($csvitem->{'%SHIPPING_METHOD'}) { 
						$DATA->{'sum/shp_method'} = $csvitem->{'%SHIPPING_METHOD'};
						}
					if ($csvitem->{'%SHIPPING_CARRIER'}) {
						my $ship_carrier = $csvitem->{'%SHIPPING_CARRIER'};
						if ($ship_carrier =~ /^F/) { 
							$ship_carrier = 'FEDX';
							} 		## FEDEX
						elsif ($ship_carrier =~ /^U/) { } 	## UPS, USPS
						else { $ship_carrier = 'OTHR'; }
						$DATA->{'sum/shp_carrier'} = $ship_carrier; 
						}

					if ($csvitem->{'%CREATE_DATE'}) {
						my $CREATE_DATE = $csvitem->{'%CREATE_DATE'}; 
						## put date in the correct format YYYY-MM-DD
						$CREATE_DATE = &find_yyyymmdd($CREATE_DATE);
						if ($CREATE_DATE ne '') {
							$CREATE_DATE = ZTOOLKIT::mysql_to_unixtime($CREATE_DATE);
							$DATA->{'our/order_ts'} = $CREATE_DATE; 
							push @{$HISTORY}, "Order originally created on $CREATE_DATE";
							}
						}

	
					if ($csvitem->{'%POST_DATE'}) {
						my $POST_DATE = $csvitem->{'%POST_DATE'};
						$POST_DATE = &find_yyyymmdd($POST_DATE);
						if ($POST_DATE eq '') {
							$olm->pooshmsg("WARN|+%POST_DATE '$csvitem->{'%POST_DATE'}' could not be interpreted");
							}
						elsif ($POST_DATE eq $DATA->{'mkt/post_date'}) {
							## it's the same we can ignore it.
							}
						else {
						 	$DATA->{'mkt/post_date'} = $POST_DATE;
							push @{$HISTORY}, "Order originally posted on $POST_DATE";
							$olm->pooshmsg("INFO|+FOUND POST_DATE: $csvitem->{'%POST_DATE'} $POST_DATE");
							}
						}
	
					}	
					
				}


			## get first and last name from fullname
			if ( (!defined $THIS_ORDER->{'%CSV'}->{'bill_firstname'}) && (defined $THIS_ORDER->{'%CSV'}->{'bill_fullname'})) {
				($THIS_ORDER->{'%CSV'}->{'bill_firstname'},$THIS_ORDER->{'%CSV'}->{'bill_lastname'}) = split(' ',$THIS_ORDER->{'%CSV'}->{'bill_fullname'},2);
				}
			if ( (!defined $THIS_ORDER->{'%CSV'}->{'ship_firstname'}) && (defined $THIS_ORDER->{'%CSV'}->{'ship_fullname'})) {
				($THIS_ORDER->{'%CSV'}->{'ship_firstname'},$THIS_ORDER->{'%CSV'}->{'ship_lastname'}) = split(' ',$THIS_ORDER->{'%CSV'}->{'ship_fullname'},2);
				}
			## get address info from full_address
			if (!defined($THIS_ORDER->{'%CSV'}->{'bill_address1'}) && defined $THIS_ORDER->{'%CSV'}->{'bill_fulladdress'}) {
				## 426 Sunny Hill Drive
				## Elkhorn, WI 53121
				if ($THIS_ORDER->{'%CSV'}->{'bill_fulladdress'} =~ m/(.*)(\r?\n)(\w+),\s*(\w+)\s*(.*)/m) {
					$THIS_ORDER->{'%CSV'}->{'bill_address1'} = $1;
			
					$THIS_ORDER->{'%CSV'}->{'bill_city'} = $3;
					$THIS_ORDER->{'%CSV'}->{'bill_state'} = $4;
					$THIS_ORDER->{'%CSV'}->{'bill_zip'} = $5;
					delete $THIS_ORDER->{'%CSV'}->{'bill_fulladdress'};
					}
				}

			## populate any undefined ship_ fields
			# it seemed easier to safely copy data this way.
			foreach my $k (keys %{$THIS_ORDER->{'%CSV'}}) {
				if (substr($k,0,5) eq 'bill_') {
					$k = substr($k,5);
					if (!defined($THIS_ORDER->{'%CSV'}->{'ship_'.$k})) {
						$THIS_ORDER->{'%CSV'}->{'ship_'.$k} = $THIS_ORDER->{'%CSV'}->{'bill_'.$k};
						}
					}
				}
			## populate any undefined ship_ fields
			# it seemed easier to safely copy data this way.
			foreach my $k (keys %{$THIS_ORDER->{'%CSV'}}) {
				if (substr($k,0,5) eq 'bill_') {
					$k = substr($k,5);
					if (!defined($THIS_ORDER->{'%CSV'}->{'ship_'.$k})) {
						$THIS_ORDER->{'%CSV'}->{'ship_'.$k} = $THIS_ORDER->{'%CSV'}->{'bill_'.$k};
						}
					}
				}
			## populate any undefined bill_ fields
			# it seemed easier to safely copy data this way.
			foreach my $k (keys %{$THIS_ORDER->{'%CSV'}}) {
				if (substr($k,0,5) eq 'ship_') {
					$k = substr($k,5);
					if (!defined($THIS_ORDER->{'%CSV'}->{'bill_'.$k})) {
						$THIS_ORDER->{'%CSV'}->{'bill_'.$k} = $THIS_ORDER->{'%CSV'}->{'ship_'.$k};
						}
					}
				}
	
			foreach my $k (keys %{$THIS_ORDER->{'%CSV'}}) {
				next if (substr($k,0,1) eq '%');
				next if ($k =~ /[\s]+/);	# ignore columns with spaces
				next if ($k ne lc($k));		# ignore mixed case columns
				## TODO: we really ought to have a valid list of order fields

				if ($k =~ /^(ship|bill)[\/\_]?country$/) {
					# ship/country and bill/country are passed to us by newegg, and possibly others .. so we'll make sure
					# we don't put 'United States' or 'USA' or something stupid like that in there.
					my ($type) = ($1);	 # bill/countrycode ship/countrycode
					my ($ISO) = &ZSHIP::fetch_country_shipcodes($THIS_ORDER->{'%CSV'}->{$k}); # note ISO is return in parameter [0]
					$DATA->{"$type/countrycode"} = $ISO;
					}
				elsif (defined $CART2::VALID_FIELDS{$k}) {
					## valid cart2 supported field.
					$DATA->{$k} = $THIS_ORDER->{'%CSV'}->{$k};
					}
				elsif (my $order2key = CART2::legacy_resolve_order_property($k)) {
					$bj->slog("COMPATIBILITY - upgrading key '$k' to '$order2key' (supported until Jan 1st, 2014)");
					if ($order2key eq '*bill_country') {
						$DATA->{"bill/countrycode"} = &ZSHIP::resolve_country('ZOOVY'=>$THIS_ORDER->{'%CSV'}->{$k})->{'ISO'};
						}
					elsif ($order2key eq '*ship_country') {
						$DATA->{"ship/countrycode"} = &ZSHIP::resolve_country('ZOOVY'=>$THIS_ORDER->{'%CSV'}->{$k})->{'ISO'};
						}
					elsif ($order2key eq 'bill_fullname') {
						($DATA->{"bill/firstname"},$DATA->{"bill/lastname"}) = split(/ /,$THIS_ORDER->{'%CSV'}->{$k},2);
						}
					elsif ($order2key eq 'ship_fullname') {
						($DATA->{"ship/firstname"},$DATA->{"ship/lastname"}) = split(/ /,$THIS_ORDER->{'%CSV'}->{$k},2);
						}
					else {
						$DATA->{$order2key} = $THIS_ORDER->{'%CSV'}->{$k};
						}
					}
				}

			## Step 2.5 - fix newegg lameness
			if ($DATA->{'ship/company'} eq 'None') { $DATA->{'ship/company'} = ''; }
			if ($DATA->{'ship/address1'} eq $DATA->{'ship/address2'}) { $DATA->{'ship/address2'} = ''; }

			if ($optionsref->{'COPY_SHIP_TO_BILL'} eq 'Y') {
				foreach my $addrfield (@CART2::VALID_ADDRESS) {
					$DATA->{"bill/$addrfield"} = $DATA->{"ship/$addrfield"};
					}
				}
	
			#print Dumper($optionsref);
			#die();

			## cleanup country codes
			if (($DATA->{'bill/countrycode'} eq '') && ($DATA->{'ship/countrycode'} eq '')) {
				$DATA->{'ship/countrycode'} = $DATA->{'bill/countrycode'} = 'US';
				}
			if ($DATA->{'ship/countrycode'} eq '') { $DATA->{'ship/countrycode'} = $DATA->{'bill/countrycode'}; }
			if ($DATA->{'bill/countrycode'} eq '') { $DATA->{'bill/countrycode'} = $DATA->{'ship/countrycode'}; }
			

			$DATA->{'sum/shp_total'} = $SHIPPING;
			$DATA->{'our/order_ts'} = $bj->created_gmt();
		
			## other GLOBAL vars
			if (defined $GLOBAL_PAYMENT_STATUS) {
				$DATA->{'flow/payment_status'} = $GLOBAL_PAYMENT_STATUS;
				}
			if ($GLOBAL_PAYMENT_METHOD) {
				$DATA->{'flow/payment_method'} = $GLOBAL_PAYMENT_METHOD;
				}
			if (defined $GLOBAL_DST) {
				$DATA->{'want/order_notes'} = $GLOBAL_DST." Order # ".$DATA->{'want/erefid'};
				}
			if (defined $GLOBAL_SDOMAIN) {
				$DATA->{'our/domain'} = $GLOBAL_SDOMAIN;	
				}

			my $item_count = scalar($stuff2->stids());
			if ($item_count == 0) {
				$olm->pooshmsg("ERROR|+No items in order groupby '$GROUPBY'");
				
				print Dumper($THIS_ORDER);

				die();
				}

			if ($olm->has_failed()) {
				$lm->pooshmsg("ERROR|+Found critical error in hierarchy validation");
				}

			## END FOREACH $GROUPBY
			}



		## END IF can_proceed()
		}

	if ($lm->can_proceed()) {
		$bj->slog("Phase 2: **PASSED**");
		}
	else {
		print Dumper($lm); die();
		}

	##
	##	 PHASE3: 
	##
	$bj->slog("Phase 3: create orders");	
	if (not $lm->can_proceed()) {
		$bj->slog("Phase3 was skipped due to earlier fatal errors (dumping)");
		}
	else {

		## add shipping
		## suppress order emails
		foreach my $GROUPBY (sort keys %ORDERS) {
			my $THIS_ORDER = $ORDERS{$GROUPBY};
			my $HISTORY = $THIS_ORDER->{'@HISTORY'};
			my $stuff2 = $THIS_ORDER->{'*STUFF2'};
			my $DATA = $THIS_ORDER->{'%DATA'};
			my $olm = $THIS_ORDER->{'*LM'};

			if ($optionsref->{'ORDER_EMAIL'} ne 'Y') {
  				#$order{'email_suppress'} = 0xFF;
				$DATA->{'want/email_update'} = 1;
				}

			## update POOL if need be (ie if its set to something besides RECENT)
			if ($GLOBAL_STATUS eq 'PENDING' || $GLOBAL_STATUS eq 'APPROVED' || $GLOBAL_STATUS eq 'COMPLETED' 
			 || $GLOBAL_STATUS eq 'DELETED' || $GLOBAL_STATUS eq 'ARCHIVE' || $GLOBAL_STATUS eq 'BACKORDER') {
				$bj->slog("Step 5 - add STATUS [$GLOBAL_STATUS]");	
				$DATA->{'flow/pool'} = $GLOBAL_STATUS;
				}

			# print Dumper($THIS_ORDER); die();

			my $O2 = undef;
			if (not defined $THIS_ORDER->{'ORDERID'}) {
				$O2 = CART2->new_memory($USERNAME,$bj->prt());
				# $O2 = CART2->new_memory($USERNAME,data=>$orderdata, events=>$HISTORY, stuff=>$stuff2->as_legacy_stuff());
				$O2->set_stuff2_please($stuff2);
				foreach my $k (sort keys %{$DATA}) { $O2->pr_set($k,$DATA->{$k}); }

				foreach my $msg (@{$HISTORY}) { 
					$O2->add_history($msg);  
					}
				$O2->in_set('our/orderid',CART2::next_id($USERNAME,1));
				$THIS_ORDER->{'ORDERID'} = $O2->oid();
				}
			else {
				#$lm->pooshmsg("WARN|+Recovering $THIS_ORDER->{'ORDERID'}");
				#$o = ORDER->new($USERNAME,$THIS_ORDER->{'ORDERID'},create=>0);
				## figure out exactly what to do here.
				## IDEA: allow auto-fix while in recent w/no shipping created in last 7 days

				$O2 = CART2->new_from_oid($USERNAME,$THIS_ORDER->{'ORDERID'});
				$O2->stuff2()->empty();
				$O2->set_stuff2_please($stuff2);
				foreach my $k (sort keys %{$DATA}) { $O2->pr_set($k,$DATA->{$k}); }
			
				$O2->{'@HISTORY'} = [];
				$O2->add_history("re-created order");
				foreach my $msg (@{$HISTORY}) { $O2->add_history($msg);  }

				$O2->{'@PAYMENTS'} = [];
				}
			

			$O2->in_set('our/jobid',$bj->id());
			if (defined $optionsref->{'FILENAME'}) {
				$O2->in_set('mkt/docid',$optionsref->{'FILENAME'});
				}

			## Step 8 - add tracking info
			foreach my $csvitem (@{$THIS_ORDER->{'@CSVITEMS'}}) {
				if ($O2->in_get('sum/shp_carrier') eq '') {
					}
				elsif ($csvitem->{'%TRACKING'} eq '') {
					}
				else {
					my $TRACKING_NUMBER = $csvitem->{'%TRACKING_NUMBER'};
					$O2->set_tracking($O2->in_get('sum/shp_carrier'),$TRACKING_NUMBER);
					}
				}
			
			if ($O2->in_get('bill/email') ne '') {
				require CUSTOMER;
				$CUSTOMER::DEBUG = 1;	
		  	 	my ($C) = CUSTOMER->new($USERNAME,CREATE=>2,'*CART2'=>$O2,EMAIL=>$O2->in_get('bill/email'));
				$olm->pooshmsg("INFO|+$THIS_ORDER->{'ORDERID'} Added customer CID: ".$C->cid());
				}

			## create payment info to send to finalize 
			my @PAYMENTS = ();
			if (($O2->in_get('want/erefid') ne '') && ($O2->in_get('mkt/post_date')>0 || $O2->in_get('flow/paid_ts')>0)) {
				$olm->pooshmsg("INFO|+$THIS_ORDER->{'ORDERID'} Add payment $GLOBAL_PAYMENT_METHOD, $GLOBAL_PAYMENT_STATUS, ".$O2->in_get('sum/order_total'));
				$O2->add_payment( 
					$GLOBAL_PAYMENT_METHOD, 
					$O2->in_get('sum/order_total'), 
					'ps'=>$GLOBAL_PAYMENT_STATUS, 
					'txn'=>$O2->in_get('want/erefid'),
					'app'=>sprintf('CSV #%d',$bj->id()),
					);
				#push @PAYMENTS, [ $GLOBAL_PAYMENT_METHOD, $O2->in_get('sum/order_total'), 
				#	{ ps=>$GLOBAL_PAYMENT_STATUS, txn=>$O2->in_get('want/erefid') } ];
				}

			## DECREMENT Inventory if #DECREMENT_INV is set to "Y"
			## default is "N"
			my $skip_inventory = 0;
			if (defined $optionsref->{'DECREMENT_INV'}) {
				$skip_inventory = ($optionsref->{'DECREMENT_INV'} eq 'Y')?0:1;
				}
			if (not $skip_inventory) {
				## this order is already in the database so don't decrement inventory again
				if ($O2->order_dbid()>0) { $skip_inventory |= 2; }
				}

			## SUPPRESS EMAILS if #ORDER_EMAIL is set to "N"
			if (defined $optionsref->{'ORDER_EMAIL'}) {
				my $email_suppress = ($optionsref->{'ORDER_EMAIL'} eq 'N')?1:0;
				$O2->pr_set('is/email_suppress',$email_suppress);
				}

			## copy all relevant messages into the history before we finalize
			foreach my $msg (@{$olm->msgs()}) {
				my ($ref) = LISTING::MSGS::msg_to_disposition($msg);
				next if ($ref->{'_'} eq 'INFO');
				$O2->add_history(sprintf("FINALIZE %s[%s] ",$ref->{'_'},$ref->{'+'}));
				}
		
			($olm) = $O2->finalize_order(
				'*LM'=>$olm,
				'skip_inventory'=>$skip_inventory,
				'skip_oid_creation'=>1,
				);

			## NO O2 changes can be made here O2 will be readonly.

			## finalize order
			# (my $orderid, my $payment_success, $o, my $finalize_ERROR) = &CHECKOUT::finalize($O2);
  	    	#	undef, 										## finalize used to only accept CART, 
			#	o					=> $o,					## 	now accepts undef with $o (order object)
			#	skip_inventory => $skip_inventory,	## some orders shouldnt decrement inv, ie FBA
	  	   # 	'@payments'		=> \@PAYMENTS,,
			#	email_suppress	=> $email_suppress,
			#	);

			## report any finalize errors
			if ($olm->has_win()) {
				$olm->pooshmsg("SUCCESS|+".$O2->oid()." was finalized OKAY")
				}
			else {
				$olm->pooshmsg("ERROR|+ORDER:$THIS_ORDER->{'ORDERID'} had finalize errors / non-win");
				} 			
			$lm->merge($olm);
			}
		}


	if (not $lm->has_win()) {
		foreach my $msg (@{$lm->msgs()}) {
			my ($ref) = LISTING::MSGS::msg_to_disposition($msg);
			if ($ref->{'_'} eq 'ERROR') {
				push @{$errors}, $ref->{'+'};
				}
			}
		}

	&DBINFO::db_user_close();
	} # END SUB



## 
## find the year, month, day for a date field
## - used because merchant (or marketplace) may use different date formats
## 10/17/11 12:21
sub find_yyyymmdd {
	my ($date) = @_;

	my $return_date = '';
	my $yyyy = '';
	my $mm = '';
	my $dd = '';
	if ($date =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {
		$yyyy = $1;
		$mm = $2;
		$dd = $3;
		}
	elsif ($date =~ /^(\d\d)-(\d\d)-(\d\d\d\d)/) {
		$yyyy = $3;
		$mm = $1;
		$dd = $2;
		}
	elsif ($date =~ /^(\d\d)\/(\d\d)\/(\d\d\d\d)/) {
		$yyyy = $3;
		$mm = $1;
		$dd = $2;
		}
	elsif ($date =~ /^(\d\d)\/(\d\d)\/(\d\d) /) {
      $yyyy = "20".$3;
      $mm = $1;
      $dd = $2;
      }

	$return_date = "$yyyy-$mm-$dd";
	
	return($return_date);
	}

1;
