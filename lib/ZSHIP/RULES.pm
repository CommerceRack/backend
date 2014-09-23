package ZSHIP::RULES;

use Data::GUID;
use Data::Dumper;
use strict;

use lib "/backend/lib";
require ZOOVY;
require ZTOOLKIT;
require ZWEBSITE;
sub gstr { ZTOOLKIT::gstr(@_); }
sub def { ZTOOLKIT::def(@_); }


%ZSHIP::RULES::VALID_RULESETS = (
	## HMM.. this would be handy
	);


@ZSHIP::RULES::MATCH = (
	{ id=>'IGNORE', idx=>"0", txt=>"Ignore (for testing)", short=>"Disabled (will be skipped)", ship=>1, uber=>1, cpn=>1 },
	{ id=>'IS_TRUE', idx=>"1000", txt=>"Always True", short=>"Is True (Always run this rule)", ship=>1, uber=>0, },
	{ id=>'SOME_IN_FILTER', use_filter=>1, '@validation'=>[ 'filter'=>1 ], 
		idx=>"1", short=>"1+ [Any Match]", txt=>'ANY product in cart matches filter', ship=>1, cpn=>1, uber=>1, },
	## ALL_IN_FILTER is one of those rules which confuses the hell outta people, and makes the system inaccessible
	## to less sophisticated clients, for this reason it is NOT available in COUPONS because we try and keep coupons
	## easier to use (so the order of difficulty would go: simple promo, coupons, uber promo)
	{ id=>'ALL_IN_FILTER', '@validation'=>[ 'filter'=>1 ], 
		idx=>"2", short=>"*  [All Must Match]", txt=>'ALL products in cart match the filter', ship=>1, cpn=>0, uber=>1, 
		hint=>q~If this rule isn't working, you might have it confused with a "ALL_NOT_PRESENT" rule. 
		This method ("ALL_IN_FILTER") runs the action ONLY when the number of products which match the filter, is the same as the number of products in the cart.~,
		},
	{ id=>'ALL_NOT_PRESENT', '@validation'=>[ 'filter'=>1 ], 
		short=>"!* [All Don't Match]", txt=>'ALL products in cart do NOT match the filter', ship=>1, cpn=>0, uber=>1, 
		hint=>q~If this rule isn't working, you might have it confused with a "ALL_IN_FILTER" rule. 
		This method (the "ALL_NOT_PRESENT" runs the action when the number of products which match the filter, 
		is less than the total number of actual products (not promotions) in the cart.~,
		},
	{ id=>'TWO_IN_FILTER', '@validation'=>[ 'filter'=>1 ], 
		idx=>"3", short=>"2+ [Two or More Must Match]", ship=>1, uber=>0, },
	{ id=>'NOTHING_IN_FILTER', '@validation'=>[ 'filter'=>1 ], 
		idx=>"4", short=>"x [No Matches Found]", txt=>'NOTHING in cart matches the filter', ship=>1, cpn=>1, uber=>1, },
	{ id=>'CRAZY_FILTER', '@validation'=>[ 'filter'=>1 ], 
		idx=>"5", short=>"! [Filter Match]", txt=>'ONLY+ALL products in filter are present in cart (no wildcards allowed)', ship=>1, cpn=>0, uber=>1, },
	{ id=>'THREE_IN_FILTER', '@validation'=>[ 'filter'=>1 ], 
		idx=>"6", short=>"! [Three+ must Match]", ship=>1, uber=>0, },
	{ id=>'STATE_MATCH', idx=>"7", short=>"STATE matches filter criteria", txt=>"STATE matches", ship=>1, cpn=>1, uber=>1, },
	{ id=>'COUNTRY_MATCH', idx=>"8", short=>"Country Name matches filter criteria",  txt=>"Country Name matches", ship=>1, cpn=>1, uber=>1, },
	{ id=>'COUNTRYCODE_MATCH', idx=>"18", short=>"Country ISOX matches filter criteria", txt=>"Country ISOX matches", ship=>1, cpn=>1, uber=>1, },
	{ id=>'IPADDR_MATCH', idx=>"9", short=>"IP Address matches", ship=>1, uber=>0,  },
	{ id=>'IS_POBOX', idx=>"10", short=>"Address appears to be a PO Box", ship=>1, uber=>0, },
	{ id=>'HAS_DOM_ADDRESS', idx=>"20", short=>"Cart has Domestic Zip Code/Address specified", ship=>1, uber=>0, },

	## date/time functions SHOULD never appear in coupons because coupons have their own date features inheirent 
	## in the coupon object itself (with WAY better messaging to client about why a coupon wasn't available)
	{ id=>'DATE/LT', idx=>"60", short=>"Date is in past", txt=>'Date value is in the past (specify date value in match value: YYYYMMDDHHMNSS)', ship=>1, cpn=>0, uber=>1, },
	{ id=>'DATE/GT', idx=>"61", short=>"Date is in future", txt=>'Date value is in the future (specify date value in match value: YYYYMMDDHHMNSS)', ship=>1, cpn=>0, uber=>1, },
	{ id=>'DAY_OF_WEEK', idx=>"62", short=>"Day of Week (1=Mon, 3=Wed, 7=Sun)", ship=>1, uber=>0, },
	{ id=>'TIME_PAST', idx=>"63", short=>"Time is past HH:MM (always computed in PST)", ship=>1, uber=>0, },

	{ id=>'HAS_CLAIM', idx=>"70", txt=>"Incomplete Item in Cart", short=>"Incomplete Item present", ship=>1, cpn=>1, uber=>1, },
#	{ id=>'HAS_EBATES', txt=>'eBates Rebate Present', cpn=>1, uber=>1, },
	{ id=>'SUBSTRING_MATCH', idx=>"80", short=>"Substring in product title", ship=>1, uber=>0, },
	{ id=>'WEIGHT/GT', idx=>"100", txt=>"Weight greater than", ship=>1, uber=>0, },
	{ id=>'WEIGHT/LT', idx=>"101", txt=>"Weight less than", ship=>1, uber=>0, },

	{ id=>'SUBTOTAL/GT', idx=>"102", short=>"Subtotal before Promotions greater than",  txt=>'cart total price is GREATER than MATCH VALUE', ship=>1, cpn=>1, uber=>1, },
	{ id=>'SUBTOTAL/LT', idx=>"103", short=>"Subtotal before Promotions less than", txt=>'cart total price is LESS than MATCH VALUE', ship=>1, cpn=>1, uber=>1, },

	## shipping logic is COMPUTED AFTER PROMOTIONS so TRUE_SUBTOTAL and SHIPPING/GT|LT functions won't work in promotions (sorry the chicken came first)
	{ id=>'TRUE_SUBTOTAL/GT', idx=>"102", short=>"Subtotal including Promotions greater than",  txt=>'cart total price is GREATER than MATCH VALUE', ship=>1, cpn=>0, uber=>0, },
	{ id=>'TRUE_SUBTOTAL/LT', idx=>"103", short=>"Subtotal including Promotions less than", txt=>'cart total price is LESS than MATCH VALUE', ship=>1, cpn=>0, uber=>0, },
	{ id=>'SHIPPING/GT', idx=>"104", short=>"Shipping price greater than", ship=>1, uber=>0, cpn=>0 },
	{ id=>'SHIPPING/LT', idx=>"105", short=>"Shipping price less than", ship=>1, uber=>0, cpn=>0 },

	{ id=>'META/EXACT', idx=>"105", txt=>"Meta Exactly matches Match Value", ship=>1, uber=>1, cpn=>0 },
	{ id=>'META/FUZZY', idx=>"106", txt=>"Meta Fuzzy matches Filter", ship=>1, uber=>1, cpn=>0 },
	{ id=>'MULTIVARSITE/A', idx=>"107", txt=>"Visitor is on Site-A", ship=>1, uber=>1, },
	{ id=>'MULTIVARSITE/B', idx=>"108", txt=>"Visitor is on Site-B", ship=>1, uber=>1, },
	{ id=>'SCHEDULE_MATCH', txt=>"Wholesale Schedule Matches", ship=>1, cpn=>1, uber=>1, },
#	{ id=>'PROFILE/EQ', txt=>"Site Profile Matches", ship=>1, cpn=>1, uber=>1, },
#	{ id=>'DOMAIN/EQ', txt=>"Site Domain Matches", ship=>1, cpn=>1, uber=>1, },
	{ id=>'POGMATCH', use_filter=>1, txt=>'STID contains POG in filter criteria (examples: ":A0", ":A001", "/A001")', short=>'POG Matches', ship=>1, cpn=>1, uber=>1 },
	{ id=>'STIDMATCH/GT', use_filter=>1, txt=>'More than MATCH VALUE items are found in the filter', cpn=>1, uber=>1, },
	{ id=>'STIDMATCH/EQ', use_filter=>1, txt=>'Exactly MATCH VALUE items are found in the filter', cpn=>0, uber=>1, },
	{ id=>'STIDMATCH/LT', use_filter=>1, txt=>'Less than MATCH VALUE items match the filter', cpn=>1, uber=>1, },
	{ id=>'STIDTOTAL/GT', use_filter=>1, txt=>'sum of filter matching items is GREATER than MATCH VALUE', cpn=>1, uber=>1, },
	{ id=>'STIDTOTAL/LT', use_filter=>1, txt=>'sum of filter matching items is LESS than MATCH VALUE', cpn=>1, uber=>1, },
	{ id=>'FILTER_IS_SUBSTRING', txt=>'Filter appears as substring in ANY items description', cpn=>1, uber=>1, },
	{ id=>'TRUE', txt=>'Always True', use_filter=>0, cpn=>1, uber=>1, },
	{ id=>'COUPON/ANY', txt=>'Coupon(s) Present', use_filter=>0, cpn=>1, uber=>1, ship=>1 },
	{ id=>'SANDBOX/YES', txt=>"User is on Sandbox/Test Site", use_filter=>0, cpn=>1, uber=>1, ship=>1 },
	{ id=>'SANDBOX/NO', txt=>"User is on LIVE version", use_filter=>0, cpn=>1, uber=>1, ship=>1 },
	);


##
## Format the MATCH table for webdoc.
##
sub show_webdoc_matches {
	my $c = '';

	$c .= "<table>";
	foreach my $match (@ZSHIP::RULES::MATCH) {
		$c .= "<tr>";
		$c .= "<td valign=top>$match->{'id'}</td>";
		if ($match->{'txt'} eq '') { $match->{'txt'} = $match->{'short'}; }
		$c .= "<td valign=top>$match->{'txt'}</td>";
		if (not defined $match->{'ship'}) { $match->{'ship'} = 0; }
		$c .= "<td valign=top>SHIP:$match->{'ship'}</td>";
		if (not defined $match->{'cpn'}) { $match->{'cpn'} = 0; }
		$c .= "<td valign=top>COUPON:$match->{'cpn'}</td>";
		if (not defined $match->{'uber'}) { $match->{'uber'} = 0; }
		$c .= "<td valign=top>UBER:$match->{'uber'}</td>";
		$c .= "</tr>";
		}
	$c .= "</table>";

	return($c);
	}


#@ZSHIP::RULES::SHIP_MATCH = ();
#@ZSHIP::RULES::PROMO_MATCH = ();
#@ZSHIP::RULES::NEWSLETTER_MATCH = ();
#foreach my $r (@ZSHIP::RULES::MATCH) {
#	if (not defined $r->{'txt'}) { 
#		$r->{'txt'} = $r->{'short'}; 
#		}
#	if ($r->{'ship'}) { 
#		push @ZSHIP::RULES::SHIP_MATCH, $r; 
#		}
#	if ($r->{'uber'}) {
#		push @ZSHIP::RULES::PROMO_MATCH, $r;
#		}
#	if ($r->{'email'}) {
#		push @ZSHIP::RULES::NEWSLETTER_MATCH, $r;
#		}
#	}


@ZSHIP::RULES::EXEC = (
	{ id=>"STOP", idx=>"0", txt=>"Stop Processing", ship=>1 },
	{ id=>"FAIL", txt=>"Do not allow this client on subscriber list", },
	{ id=>"GOGO", txt=>"GoGo - Continue to Next Rule (if true, stop if not)", cpn=>1, uber=>1 },

	## SHIPPING SPECIFIC RULES
	{ id=>"SHIP/ADD-PERCENT-MATCH", idx=>"100", txt=>"Add [value] percent of matching items subtotal.", ship=>1 },
	{ id=>"SHIP/ADD-PERCENT-SUBTOTAL", idx=>"101", txt=>"Add [value] percent of the cart subtotal", ship=>1 },
	# { id=>"SHIP/BROKE", idx=>"102", txt=>"INVALID RULE 102", ship=>1 },
	{ id=>"SHIP/ADD-VALUE", idx=>"1", txt=>"Add [value] to Shipping Price", ship=>1 },
	{ id=>"SHIP/SET-VALUE", idx=>"2", txt=>"Set Shipping Price to [value]", ship=>1 },
	{ id=>"SHIP/DISABLE", idx=>"3", txt=>"Disallow Shipping Type", ship=>1 },
	{ id=>"SHIP/ADD-VALUE-MATCH-ITEM", idx=>"4", txt=>"Add [value] for each matching item", ship=>1 },
	{ id=>"SHIP/ADD-VALUE-MATCH-SKU", idx=>"5", txt=>"Add [value] for each matching sku", ship=>1 },
	{ id=>"SHIP/ADD-VALUE-COUNT-ITEM", idx=>"6", txt=>"Add [value] for every item in cart", ship=>1 },
	{ id=>"SHIP/ADD-VALUE-COUNT-ITEM-MINUS-ONE", idx=>"7", txt=>"Add [value] for each matching item, minus one", ship=>1 },	
	{ id=>"SHIP/STOP", idx=>"0", id=>'STOP', txt=>"Completely STOP Rule Processing", cpn=>1, uber=>1, },

	## COUPON/UBER ACTIONS
	{ id=>'MATCHADD*B3GO', txt=>'ADD to Discount (B3GO: Buy-Three-Get-One Matching Items)', cpn=>1, uber=>1, notes=>"use MATCHVALUE as a dollar or percentage per match. e.g. -%100 is buy one get one free, -%50 is buy one get one half off, -\$10 is buy two get \$10 off your purchase.",  },
	{ id=>'MATCHADD*B2GO', txt=>'ADD to Discount (B2GO: Buy-Two-Get-One Matching Items)', cpn=>1, uber=>1, },
	{ id=>'MATCHADD*BOGO', txt=>'ADD to Discount (BOGO: Buy-One-Get-One Matching Items)', cpn=>1, uber=>1, },
	{ id=>'MATCHADD*MINUS0', txt=>'ADD to Discount (SubTotal=Match Items) (% modify only)', cpn=>1, uber=>1, },
	{ id=>'MATCHADD*MINUS1', txt=>'ADD to Discount (SubTotal=Match Items - Single Most Expensive Match) (% modify only)', cpn=>1, uber=>1, },
	{ id=>'MATCHADD*MINUS2', txt=>'ADD to Discount (Subtotal=Match Items - Two Most Expensive Matches) (% modify only)', cpn=>1, , uber=>1,}, 
	{ id=>'MATCHADD*MINUS3', txt=>'ADD to Discount (SubTotal=Match Items - Three Most Expensive Matches) (% modify only)', cpn=>1, uber=>1, },
	{ id=>'MATCHADD*ONLY1', txt=>'ADD to Discount (SubTotal=Single Most Expensive Match Item)', cpn=>1, uber=>1, },
	{ id=>'REMOVE', txt=>"REMOVE the Discount code (uber promotions only)", cpn=>0, uber=>1, },
	{ id=>'DISABLE', txt=>"DISABLE (Remove coupon and stop processing)", cpn=>1, uber=>1, },
	{ id=>'SET', txt=>"SET Discount to modify value (\$ or %)", cpn=>1, uber=>1, },
	{ id=>'ADD*ONE', txt=>"ADD modify value to Discount Amount", cpn=>1, uber=>1, },
	## NOTE: ADD*MATCHITEMS repalced ADD*MATCHITEM (which did not work as it was described)
	{ id=>'ADD*MATCHITEMS', txt=>"ADD modify value to Discount Amount FOR EVERY MATCHING ITEM QTY", cpn=>1, uber=>1, },
	{ id=>'ADD*MATCHITEMS2', txt=>"ADD modify value to Discount Amount FOR EVERY MATCHING ITEM QTY/2", cpn=>1, uber=>1, },
	{ id=>'ADD*MATCHITEMS3', txt=>"ADD modify value to Discount Amount FOR EVERY MATCHING ITEM QTY/3", cpn=>1, uber=>1, },
	{ id=>'ADD*MATCHITEMS4', txt=>"ADD modify value to Discount Amount FOR EVERY MATCHING ITEM QTY/4", cpn=>1, uber=>1, },
	## NOTE: ADD*MATCHLINES repalced ADD*MATCHSKU (which did not work as it was described)
	{ id=>'ADD*MATCHLINES', txt=>"ADD modify value to Discount Amount FOR EACH MATCHING UNIQUE SKU/LINE, set quantity=1", cpn=>1, uber=>1, },
	## NOTE: ADD*ALLSKU should be called ADD*ALLLINES
	{ id=>'ADD*ALLSKU', txt=>"ADD modify value to Discount Amount FOR EVERY UNIQUE SKU/LINE REGARDLESS OF MATCH, set quantity=1", cpn=>1, uber=>1, },
	{ id=>'ADD*ALLITEMS', txt=>"ADD modify value to Discount Amount FOR EVERY ITEM QTY REGARDLESS OF MATCH, set quantity=1", cpn=>1, uber=>1, },
	{ id=>'ADD*EFFECTIVESUBTOTAL', txt=>"Apply modify value to effective subtotal (even if previous coupons have been applied)", cpn=>1, uber=>1, },
	## NOTE: SETQTY*MATCHSKU should be called SETQTY*MATCHLINES
	{ id=>'SETQTY*MATCHSKU', txt=>"SET Discount Quantity equal to EVERY MATCHING UNIQUE SKU/LINE", cpn=>0, uber=>1, },
	{ id=>'SETQTY*MATCHITEM', txt=>"SET Discount Quantity equal to EVERY MATCHING ITEM QTY", cpn=>0, uber=>1, },
	## NOTE: SETQTY*ALLSKU should be called SETQTY*ALLLINES
	{ id=>'SETQTY*ALLSKU', txt=>"SET Discount Quantity equal to EVERY UNIQUE SKU/LINE REGARDLESS OF MATCH", cpn=>0, uber=>1, },
	{ id=>'SETQTY*ALLITEMS', txt=>"SET Discount Quantity equal to EVERY ITEM QTY REGARDLESS OF MATCH", cpn=>0, uber=>1, },
	{ id=>'SETQTY*MATCHITEM2', txt=>"SET Discount Quantity equal to EVERY MATCHING ITEM / 2", cpn=>0, uber=>1, },
	## NOTE: ADD*MATCHITEM is broken/does not work, replaced with ADD*MATCHINGITEMS
	{ id=>'ADD*MATCHITEM', txt=>"*** PLEASE FIX - USING BACKWARD COMPATIBLE ADD*MATCHITEM RULE *** (DEPRECATED 2011/09/29)", cpn=>0, uber=>0, },
	## NOTE: ADD*MATCHITEM is broken/does not work, replaced with ADD*MATCHINGLINES
	{ id=>'ADD*MATCHSKU', txt=>"*** PLEASE FIX - USING BACKWARD COMPATIBLE ADD*MATCHSKU RULE *** (DEPRECATED 2011/09/29)", cpn=>0, uber=>0, },
	);



##
## Format the EXEC table for webdoc.
##
sub show_webdoc_exec {
	my $c = '';

	$c .= "<table>";
	foreach my $match (@ZSHIP::RULES::EXEC) {
		$c .= "<tr>";
		$c .= "<td valign=top>$match->{'id'}</td>";
		if ($match->{'txt'} eq '') { $match->{'txt'} = $match->{'short'}; }
		$c .= "<td valign=top>$match->{'txt'}</td>";
		if (not defined $match->{'ship'}) { $match->{'ship'} = 0; }
		$c .= "<td valign=top>SHIP:$match->{'ship'}</td>";
		if (not defined $match->{'cpn'}) { $match->{'cpn'} = 0; }
		$c .= "<td valign=top>COUPON:$match->{'cpn'}</td>";
		if (not defined $match->{'uber'}) { $match->{'uber'} = 0; }
		$c .= "<td valign=top>UBER:$match->{'uber'}</td>";
		$c .= "</tr>";
		}
	$c .= "</table>";

	return($c);
	}


#@ZSHIP::RULES::SHIP_EXEC = ();
#@ZSHIP::RULES::PROMO_EXEC = ();
#@ZSHIP::RULES::NEWSLETTER_EXEC = ();
#foreach my $r (@ZSHIP::RULES::EXEC) {
#	if ($r->{'ship'}) { 
#		push @ZSHIP::RULES::SHIP_EXEC, $r; 
#		}
#	if ($r->{'uber'}) {
#		push @ZSHIP::RULES::PROMO_EXEC, $r;
#		}
#	if ($r->{'email'}) {
#		push @ZSHIP::RULES::NEWSLETTER_EXEC, $r;
#		}
#	}




##
## converts all keys to lowercase
##
sub export_rules {
	my ($webdbref,$RULESETID) = @_;

	if (not defined $webdbref->{'%SHIPRULES'}) {
		$webdbref->{'%SHIPRULES'} = {};
		} 

	my $changes = 0;
	my $RULESETS = $webdbref->{'%SHIPRULES'};
	foreach my $ruleset (keys %{$RULESETS}) {
		foreach my $rule (@{$RULESETS->{$ruleset}}) {
			if (not defined $rule->{'GUID'}) { $rule->{'GUID'} = Data::GUID->new()->as_string(); $changes++; }
			}
		}

	if (not defined $RULESETS->{$RULESETID}) {
		$RULESETS->{$RULESETID} = [];
		}

	## NOW MAKE A COPY:
	my @OUTPUT = ();
	foreach my $rule (@{$RULESETS->{$RULESETID}}) {
		## step1: lowercase all keys
		my %new = ();
		foreach my $k (keys %{$rule}) { $new{ lc($k) } = $rule->{$k}; }
		push @OUTPUT, \%new;
		## step2: rename any stupidly named keys.
		}
	return(@OUTPUT);
	}



##
## searches through a ruleset looking for the position of a guid.
##
sub resolve_guid_index {
	my ($RULESETREF, $GUID) = @_;
	
	my $ID = -1;
	my $i = 0;
	foreach my $rule (@{$RULESETREF}) {
		if ($rule->{'guid'} eq $GUID) { $ID = $i; }
		if ($rule->{'GUID'} eq $GUID) { $ID = $i; }
		$i++;
		}
	return($ID);
	}




##
##
##
sub loadbin {
	my ($webdbref, $cache) = @_;
	if (not defined $webdbref->{'%SHIPRULES'}) {
		$webdbref->{'%SHIPRULES'} = {};
		} 
	return($webdbref->{'%SHIPRULES'});
	}



##
##
##
sub savebin {
	my ($webdbref, $ref) = @_;

	## partitions greater than zero don't use shiprules.bin
	$webdbref->{'%SHIPRULES'} = $ref;
	return(0);
	}



##
## ZSHIP::RULES::do_ship_rules
##   parameters: username, shipping method (SIMPLE_DOM), a reference to the cart hash, and the current shipping price
##   returns: new shipping price, or undef if the shipping method is disallowed
##
sub do_ship_rules {
	my ($CART2, $PKG, $METHOD, $CURRENTPRICE, $NOTE) = @_;

#	my $cache = $CART2->{'+cache'};
#	if (not defined $cache) { $cache = 0; }

	my ($PRT) = $CART2->prt();
	#if ($PRT>0) {
	#	## make sure we're focused on the correct partition
	#	$METHOD = $METHOD.'.'.$CART->prt();
	#	}

	my $LM = undef;
	if (ref($PKG) eq 'STUFF2::PACKAGE') {
		$LM = $PKG->lm();
		}
	elsif (ref($PKG) eq 'STUFF2') {
		$LM = $CART2->msgs();
		}
	else {
		warn "Created a new LISTING::MSGS-> object (this almost certainly isn't what you wanted)";
		$LM = LISTING::MSGS->new($CART2->username());
		}

	$CART2->is_debug() && $LM->pooshmsg("RULES|+$NOTE Rules starting -- Method: $METHOD  Price_before_rules: $CURRENTPRICE"); 

	my $USERNAME = $CART2->username();

	my $SCHEDULE = $CART2->in_get('our/schedule');
	if (not defined $SCHEDULE) { $SCHEDULE = ''; }
	## quick check to make sure rule processing is allowed by this schedule
	if ($SCHEDULE ne '') {
		require WHOLESALE;
		my $S = &WHOLESALE::load_schedule($USERNAME,$CART2->in_get('our/schedule'));
		if ($S->{'shiprule_mode'}==0) {
			$LM->pooshmsg("RULES|+RULES: shipping rules disabled by schedule $SCHEDULE"); 
			return($CURRENTPRICE);
			}
		}

	my ($k, $counter) = ();
	my @rules = &fetch_rules($CART2->webdbref(), "SHIP-$METHOD", $CART2->cache_ts());

	my $FINISH = 0;			# gets set to 1 if we stop rule processing
	my $rulemaxcount = scalar(@rules);
	$CART2->is_debug() && $LM->pooshmsg("RULES|+RULES: rulemaxcount=$rulemaxcount (this is the total # of rules to run)"); 
		

  	for ($counter=0; $counter < $rulemaxcount; $counter++) {
		my $rule = $rules[$counter];
		$rule->{'.line'} = $counter;

		$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ $rule->{'NAME'}");

      if ((defined $rule->{'SCHEDULE'}) && ($rule->{'SCHEDULE'} ne '')) {
         ## Schedule has a rule
			if ($SCHEDULE eq '') {
				## the schedule has a rule, but they don't, so ignore this.
				$rule->{'MATCH'} = 'IGNORE'; 
				$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ rule skipped (no schedule) - rule_schedule=[$rule->{'SCHEDULE'}] current_schedule=[$SCHEDULE]"); 
				}
         elsif (($rule->{'SCHEDULE'} eq $SCHEDULE) || ($rule->{'SCHEDULE'} eq '*')) {
				$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ rule proceed - rule_schedule=[$rule->{'SCHEDULE'}] current_schedule=[$SCHEDULE]"); 
				}
			else {
				$rule->{'MATCH'} = 'IGNORE'; 
				$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ rule skipped (schedule does not match) - rule_schedule=[$rule->{'SCHEDULE'}] current_schedule=[$SCHEDULE]"); 
				}
			}

		my $result = undef;
		if ($rule->{'MATCH'} eq 'IGNORE') {
			$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+IGNORE"); 
			next;
			}


		($result) = $CART2->rulematch($rule,'mode'=>'SHIP',CURRENTPRICE=>$CURRENTPRICE,'*LM'=>$LM);
		# my ($result->{'_skumatch'},) = ($result->{'_skumatch'},$result->{'_qtymatch'});

		# print STDERR Dumper($rule,$result);


		$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ Trying MATCH=$rule->{'MATCH'} HINT=[".$rule->{'NAME'}."]"); 
		if ($CART2->is_debug()) { 
			my $str = ''; foreach my $k (sort keys %{$rule}) { $str .= "$k=[".$rule->{$k}."] "; }
			$LM->pooshmsg("RULES[$counter]|+ ATTEMPTING RULE: $str");
			}

		$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ ** $rule->{'MATCH'} _skumatch=[$result->{'_skumatch'}] WILL-APPLY?[".(($result->{'_skumatch'})?'YES':'NO')."]"); 

		if ($result->{'_skumatch'}) {
			$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ Before applying rule shipping method CURRENTPRICE=$CURRENTPRICE"); 
			# if ($CART2->is_debug() & 128) { $LM->pooshmsg("RULES[$counter]|+ Performing Rule Action! (ACTION IS: $rule->{'ACTION'})"); }
			$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ Performing Rule Action! (EXEC IS: $rule->{'EXEC'})"); 

			# 0 means stop rule processing
			# if ($rule->{'ACTION'} == 0) { 
			if ($rule->{'EXEC'} eq 'STOP') {
				$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ halted all additional rule processing. "); 				
				$FINISH = 1; 
				} 

			# 1 means add value to shipping price
			# if ($FINISH == 0 && $rule->{'ACTION'} == 1) { 
			if (($FINISH == 0) && ($rule->{'EXEC'} eq 'SHIP/ADD-VALUE')) {
				$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ ACTION1 Current Price is: $CURRENTPRICE value is $rule->{'VALUE'}"); 
				my ($price, $pretty) = &ZOOVY::calc_modifier($CURRENTPRICE,$rule->{'VALUE'}); 
				$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ ACTION1 Calc modifier returned: ($price, $pretty)"); 
				$CURRENTPRICE = $price;
				}

			# 2 means set shipping to value
			#if (($FINISH == 0) && (int($rule->{'ACTION'}) == 2)) { 
			if (($FINISH == 0) && ($rule->{'EXEC'} eq 'SHIP/SET-VALUE')) {
				$CURRENTPRICE = $rule->{'VALUE'}; $CURRENTPRICE =~ s/[^0-9|^\.]+//g; 
				}

			# 3 means invalidate shipping method
			#if (($FINISH == 0) && (int($rule->{'ACTION'}) == 3)) { 
			if (($FINISH == 0) && ($rule->{'EXEC'} eq 'SHIP/DISABLE')) {
				$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ invalidated/disabled shipping method."); 				
				$FINISH=1; $CURRENTPRICE = undef; 
				}

			# 4 means add for each matching item.
			#if (($FINISH == 0) && (int($rule->{'ACTION'}) == 4)) { 
			if (($FINISH == 0) && ($rule->{'EXEC'} eq 'SHIP/ADD-VALUE-MATCH-ITEM')) {
				my ($price, $pretty) = &ZOOVY::calc_modifier($CURRENTPRICE,$rule->{'VALUE'},0); 
				$CURRENTPRICE += $price * $result->{'_qtymatch'}; 
				}

			# 5 means add value for each matching SKU
			#if (($FINISH == 0) && (int($rule->{'ACTION'}) == 5)) { 
			if (($FINISH == 0) && ($rule->{'EXEC'} eq 'SHIP/ADD-VALUE-MATCH-SKU')) {
				my ($price, $pretty) = &ZOOVY::calc_modifier($CURRENTPRICE,$rule->{'VALUE'},0); 
				$CURRENTPRICE += $price * $result->{'_skumatch'}; 
				}

			# 6 means add value for each item in cart.
			#if (($FINISH == 0) && ($rule->{'ACTION'} == 6))  { 
			if (($FINISH == 0) && ($rule->{'EXEC'} eq 'SHIP/ADD-VALUE-COUNT-ITEM')) {
				# my ($subtotal, $totalweight, $totaltax, $totaltaxable, $itemcount) = $STUFF2->totals(0,1);
				my $itemcount = $PKG->sum({'show'=>'real'})->{'items_count'};
				if (not defined $itemcount) { warn "SHIPRULE EXEC 'SHIP/ADD-VALUE-COUNT-ITEM' GOT UNDEF RESULT when requesting items_count\n"; }
			 	my ($price, $pretty) = &ZOOVY::calc_modifier($CURRENTPRICE,$rule->{'VALUE'},0); 
				$CURRENTPRICE += ($itemcount * $price);
				}

			# 7 means add for each matching item, minus 1
			#if ($FINISH == 0 && $rule->{'ACTION'} == 7) { 
			if (($FINISH == 0) && ($rule->{'EXEC'} eq 'SHIP/ADD-VALUE-COUNT-ITEM-MINUS-ONE')) {

				if (index('%',$rule->{'VALUE'}) >= 0) {
					$rule->{'VALUE'} =~ s/[^0123456789\%\+\.\-]//g;
					$LM->pooshmsg("RULES[$counter]|+ USE-%RULE _qtymatch=$result->{'_qtymatch'} VALUE=[".$rule->{'VALUE'}."]");
			 		my ($price, $pretty) = &ZOOVY::calc_modifier($CURRENTPRICE,$rule->{'VALUE'}); 
					$CURRENTPRICE += ( ($result->{'_qtymatch'}-1) * $price);
					}
				else {
					$rule->{'VALUE'} =~ s/[^0123456789\.\-]//g;
					$LM->pooshmsg("RULES[$counter]|+ USE-ELSE _qtymatch=$result->{'_qtymatch'} VALUE=[".$rule->{'VALUE'}."]");
					$CURRENTPRICE += (($result->{'_qtymatch'}-1) * $rule->{'VALUE'}); 
					}
				}

			# 100 - Add [value] percent of matching items subtotal.
			#if ($FINISH == 0 && $rule->{'ACTION'} == 100) {
			if (($FINISH == 0) && ($rule->{'EXEC'} eq 'SHIP/ADD-PERCENT-MATCH')) {
				# FILTERMATCH 10 is a special rule which returns total by sku and total by item
				# my ($totalsku, $totalitem) = &rulematch_cart($rule,10,$CART);				
				my ($totalsku,$totalitem) = (0,0);
				if ($result->{'matches'} > 0) { 
					($totalsku,$totalitem) = ($result->{'totalsku'}, $result->{'totalitem'}); 
					}
				$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ ACTION=100 totalsku=[$totalsku] totalitem=[$totalitem]"); 
			 	my ($price, $pretty) = &ZOOVY::calc_modifier($totalitem,$rule->{'VALUE'}); 
				$CURRENTPRICE += ($price-$totalitem);
				}
			
			# 101 - Add [value] percent of the cart subtotal
			#if ($FINISH == 0 && $rule->{'ACTION'} == 101) { 
			if (($FINISH == 0) && ($rule->{'EXEC'} eq 'SHIP/ADD-PERCENT-SUBTOTAL')) {
				# my ($subtotal, $totalweight, $totaltax, $totaltaxable, $itemcount) = $STUFF2->totals(0,1);
				my $subtotal = $PKG->sum({'show'=>'real'})->{'items_total'};
				if (not defined $subtotal) { warn "SHIPRULE EXEC 'SHIP/ADD-PERCENT-SUBTOTAL' GOT UNDEF RESULT when requesting items_total\n"; }

				$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ ACTION=101 subtotal=[$subtotal] value=[$rule->{'VALUE'}]");
			 	my ($price, $pretty) = &ZOOVY::calc_modifier($subtotal,$rule->{'VALUE'}); 
				$CURRENTPRICE += ($price-$subtotal);
				}

			

			$CART2->is_debug() && $LM->pooshmsg("RULES[$counter]|+ After applying rule: CURRENTPRICE=$CURRENTPRICE"); 
			} 

#		print Dumper($rule,$result->{'_skumatch'});
#		die();

		if ($FINISH) { $counter = $rulemaxcount; }
		}
	undef @rules;

	if ((not defined $CURRENTPRICE) || ($CURRENTPRICE eq '')) {
		$LM->pooshmsg("RULES[$counter]|+ Rules ending -- shipping price is undef/blank, method will be unavailable");
		}
	else {
		#if ($CURRENTPRICE < 0) {		
		#	$LM->pooshmsg("RULES[$counter]|+ Rules result was [$CURRENTPRICE] - negatives not allowed. setting to zero.");
		#	$CURRENTPRICE = 0;
		#	}
		$LM->pooshmsg("RULES[$counter]|+ Rules ending -- adjusted price is: [".((defined $CURRENTPRICE)?$CURRENTPRICE:'disable')."]"); 
		}

	

	return($CURRENTPRICE);
	}




sub filter_to_regex2 {	
	my ($FILTER) = @_;

	$FILTER = uc($FILTER);

	if (! defined $FILTER) { 
		#print STDERR "FILTER is undef!\n";
		$FILTER='';
		}

	# step0: purify filter
	$FILTER =~ s/[ ]+/,/g;	# change spaces to commas
	$FILTER =~ s/[\n\r]+/,/g;  # remove any hard returns or newlines, replace with comma
	$FILTER =~ s/[,]+/,/g;	# remove duplicate commas
	$FILTER =~ s/[,]+$//g;	# strip trailing commas
	$FILTER =~ s/^[,]+//g;	# strip leading commas
	

	## NOTE: this used to strip :'s but that was a bad idea (used in options)
	$FILTER =~ s/[\(\)]+//g;
	
	# step 1 expand filter
	$FILTER =~ s/\*/\.\*/g;
	$FILTER =~ s/\?/\.\?/g;
	my $regex = '';
	foreach my $chunk (split(/,/,$FILTER)) {
		if ($regex ne '') { $regex .= '|'; }
		$regex .= "(^$chunk\$)";
		}
	$regex = "($regex)";
	return($regex);
	}






sub filter_to_regex {	
	my ($FILTER) = @_;

	$FILTER = uc($FILTER);

	if (! defined $FILTER) { 
		#print STDERR "FILTER is undef!\n";
		$FILTER='';
		}

	# step0: purify filter
	$FILTER =~ s/[ ]+/,/g;	# change spaces to commas
	$FILTER =~ s/[\n\r]+/,/g;  # remove any hard returns or newlines, replace with comma
	$FILTER =~ s/[,]+/,/g;	# remove duplicate commas
	$FILTER =~ s/[,]+$//g;	# strip trailing commas
	$FILTER =~ s/^[,]+//g;	# strip leading commas
#	$FILTER =~ s/\+/\\+g/

	## NOTE: this used to strip :'s but that was a bad idea (used in options)
	$FILTER =~ s/[\(\)]+//g;
	
	# step 1 expand filter
	$FILTER =~ s/\*/\.\*/g;
	$FILTER =~ s/\?/\.\?/g;
	$FILTER =~ s/,/\|/g;		# change commas to pipes for the regex.
	return($FILTER);
}






#######################
##
## &ZSHIP::RULES::fetch_rules
##
## parameters: username, shipping type (in uppercase)
## valid shipping types: SIMPLE_DOM
## returns: an array of references to hashes 
##			hashes should have the following fields:
##			PROCESS {0=disable,1=any,2=all}
##			ACTION {0=stop,1=add,2=set,3=kill} add to price, set price, kill method
##			VALUE contains a price, with % or - to denote how it will be modified.
##			FILTER is a comma separated list of product id's. (note: spaces
##			NAME is a text field that describes the rule (note: spaces -> underscores)
######################
sub fetch_rules {
	my ($webdbref, $METHOD, $cache) = @_;

	my $rules = &loadbin($webdbref, $cache);

	my @ar = ();
	if (defined($rules) && defined($rules->{$METHOD}) && (ref($rules->{$METHOD}) eq 'ARRAY')) {
		## 5/28/2013 -- all rules MUST have a GUID
		@ar = @{$rules->{$METHOD}};
		}

	return(@ar);
	}



##
## empties a rule table
## 
sub empty_rules {
	my ($webdbref, $METHOD, $cache) = @_;
	my $rules = &loadbin($webdbref, $cache);
	my @ar = ();
	if (defined($rules) && defined($rules->{$METHOD}) && (ref($rules->{$METHOD}) eq 'ARRAY')) {
		delete $rules->{$METHOD};
		}
	return();
	}


#######################
##
## &ZSHIP::RULES::delete_rule
##
## parameters: username, shipping_type, id
## valid shipping types: SIMPLE_DOM
##    returns: 0 on success, 1 on failure.
######################
sub delete_rule {
	my ($webdbref, $METHOD, $ID) = @_;

#	print STDERR "Deleting $USERNAME $METHOD $ID\n";

	my $ref = &loadbin($webdbref);
#	print STDERR "before delete the count was ".scalar(@{$ref->{$METHOD}})."\n";
	if (defined $ref->{$METHOD})  {
		splice @{$ref->{$METHOD}}, $ID, 1;
		} 
	else {
		die "Cannot delete $METHOD which does not exist.\n";
		}
#	print STDERR "after delete the count was ".scalar(@{$ref->{$METHOD}})."\n";
	&savebin($webdbref,$ref);
	return(0);  
	}


##
## Swap Rule
##
##
sub swap_rule {
  my ($webdbref, $METHOD, $ID1, $ID2) = @_;

	my $ref = &loadbin($webdbref);
#	print STDERR "before delete the count was ".scalar(@{$ref->{$METHOD}})."\n";
	if (defined $ref->{$METHOD}) 
		{
		## Removed dereferencing style not supported by Perl 5.8 -AK 5/6/03
		my @tmp = @{$ref->{$METHOD}}; ## Make a copy of the array (so we don't get our references crossed)
		$ref->{$METHOD}[$ID1] = $tmp[$ID2];
		$ref->{$METHOD}[$ID2] = $tmp[$ID1];
		## WAS: 
		# my $tmp = @{$ref->{$METHOD}}->[$ID1];
		# @{$ref->{$METHOD}}->[$ID1] = @{$ref->{$METHOD}}->[$ID2];
		# @{$ref->{$METHOD}}->[$ID2] = $tmp;
		} 
	else {
		die "Cannot shift $ID1 and $ID2 on $METHOD which does not exist.\n";
		}
#	print STDERR "after delete the count was ".scalar(@{$ref->{$METHOD}})."\n";
	&savebin($webdbref,$ref);
	return(0);  
	}





#############################
##
## append_rule
##
#############################
sub append_rule {
	my ($webdbref, $METHOD, $hashref) = @_;

#	foreach $k (keys %{$hashref}) { print STDERR "HASH KEY: $k\n"; }

	# Sanity checking.
	$hashref->{'FILTER'} =~ s/ /,/g;
	$hashref->{'FILTER'} =~ s/[,]+/,/g;

	$hashref->{'CODE'} =~ s/[\W]+//gs;

	my $ref = &loadbin($webdbref);
	# verify that ref exists
	if (! defined $ref) {
		$ref = {};
#		print STDERR "Created \$ref\n";
		}

	# verify the METHOD we are using exists.
	if (! defined $ref->{$METHOD}) {
		$ref->{$METHOD} = ();
#		print STDERR "Initialized \$METHOD $METHOD\n";
		}

#	print STDERR "$METHOD is what we appended to SHIPRULES.bin\n";
	push @{$ref->{$METHOD}}, $hashref;
#	print STDERR "\$ref->\{$METHOD\} now has ".scalar(@{$ref->{$METHOD}})." elements.\n";

	&savebin($webdbref,$ref);

	return(0);
}


sub tax_boolean {
	my ($tax) = @_;
	if (not defined $tax) { $tax = 0; }
	elsif ($tax =~ m/^Y/i) { $tax = 1; }
	elsif ($tax =~ m/^N/i) { $tax = 0; }
	elsif ($tax ne '1') { $tax = 0; }
	return $tax;
	}



#############################
##
## update_rule
##
#############################
sub update_rule {
  my ($webdbref, $METHOD, $ID, $hashref) = @_;

  	# do a quicky data validity check!
  	$hashref->{'FILTER'} =~ s/[\n| ]//g;

	my $ref = &loadbin($webdbref);
	if (defined $ref->{$METHOD}) {
		## Removed dereferencing style not supported by Perl 5.8 -AK 5/6/03
		$ref->{$METHOD}[$ID] = $hashref; # Was: @{$ref->{$METHOD}}->[$ID] = $hashref;
		} 
	else {
		die "Cannot find ID $ID in METHOD $METHOD\n";
		}
	&savebin($webdbref, $ref);
	return(0);  
	}


1;
