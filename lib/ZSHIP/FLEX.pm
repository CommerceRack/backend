package ZSHIP::FLEX;

use strict;
use lib "/backend/lib";
require ZOOVY;
require PRODUCT;
require ZWEBSITE;
require ZSHIP::RULES;



##
## REGION: US, CA, INT
##
##
sub calc {
	my ($CART2,$PKG,$REGION,$WEBDBREF,$SHIPMETHODSREF,$METAREF) = @_;

	## calculate the weight
	my ($sums) = $PKG->sum();
	my $WEIGHT = undef;
	if ($REGION eq 'US') {
		$WEIGHT = $PKG->get('legacy_usps_weight_194');
		}
	else {
		$WEIGHT = $PKG->get('legacy_usps_weight_166');
		}
	$CART2->is_debug() && $PKG->pooshmsg(sprintf("INFO|+PKG SUMS:%s",&ZOOVY::debugdump($sums)));

	if (int($WEIGHT) < $WEIGHT) { $WEIGHT = int($WEIGHT)+1; }		# strip decimals
	if ($WEIGHT <= 0) { $WEIGHT = 0; }

	my $methods = &ZWEBSITE::ship_methods($CART2->username(),prt=>$CART2->prt());
	if (not defined $methods) { $methods = []; }

	## now go through each method (so we do this 3 times, or once per region)
	foreach my $m (@{$methods}) {
		next if ($m->{'region'} ne $REGION);	## this allows us to do grouping!
		next unless ($m->{'active'});
		$CART2->is_debug() && $PKG->pooshmsg("INFO|+Flex Shipping Trying: name=[$m->{'name'}] type=[$m->{'handler'}] carrier=[$m->{'carrier'}] id=[$m->{'id'}]");

		#use Data::Dumper;
		#print STDERR Dumper($REGION,$m);

		my $price = undef;
		my $instructions = undef;
		
		#if ($m->{'handler'} eq 'FEDEX') {
		#	}
		#elsif ($m->{'handler'} eq 'USPS') {
		#	}
		#elsif ($m->{'handler'} eq 'FREIGHTCENTER') {
		#	}
		#elsif ($m->{'handler'} eq 'UPS') {
		#	}
		if ($m->{'handler'} eq 'FREE') {
			# my $hashref = &ZTOOLKIT::parseparams($m->{'data'});
			$CART2->is_debug() && $PKG->pooshmsg("TRACE|+FLEX/FREE total=".$m->{'total'});
			if ($PKG->value('items_total')>=$m->{'total'}) {
				$price = 0;
				$CART2->is_debug() && $PKG->pooshmsg("TRACE|+FLEX/FREE pkg qualifies");
				}
			}
		elsif ($m->{'handler'} eq 'FIXED') {
			my ($k1,$k2) = ();
			if ($REGION eq 'US') { ($k1,$k2) = ('zoovy:ship_cost1', 'zoovy:ship_cost2'); }
			if ($REGION eq 'CA') { ($k1,$k2) = ('zoovy:ship_can_cost1', 'zoovy:ship_can_cost2'); }
			if ($REGION eq 'INT') { ($k1,$k2) = ('zoovy:ship_int_cost1', 'zoovy:ship_int_cost2'); }
			$price = &ZSHIP::FLEX::calc_simplemultiprice($CART2, $PKG, $k1, $k2, $CART2->stuff2());
			}
		elsif ($m->{'handler'} eq 'WEIGHT') {
			my $hashref = &ZTOOLKIT::parseparams($m->{'data'});
			# print STDERR 'WEIGHT: '.Dumper($hashref);

			## make sure we convert any lbs to oz.
			$m->{'min_wt'} = &ZSHIP::smart_weight($m->{'min_wt'});

			$CART2->is_debug() && $PKG->pooshmsg("TRACE|+FLEX/WEIGHT ".&ZOOVY::debugdump($hashref));
			if ($WEIGHT < $m->{'min_wt'}) {
				$price = undef; 
				$CART2->is_debug() && $PKG->pooshmsg("TRACE|+FLEX/WEIGHT PKG:$WEIGHT < MIN_WT:$m->{'min_wt'} (disabling)");
				}
			else {
				my $matched = 0;
				my @MSGS = ();
				$CART2->is_debug() && $PKG->pooshmsg("TRACE|+FLEX/WEIGHT Package Weight: $WEIGHT (oz)");
				foreach my $oz (sort { $a <=> $b } keys %{$hashref}) {
					next if (defined $price);

					# print STDERR "OZ: $oz >= $WEIGHT\n";
					if ($oz >= $WEIGHT) { 
						($price) = $hashref->{$oz};
						$CART2->is_debug() && $PKG->pooshmsg("TRACE|+FLEX/WEIGHT $oz >= $WEIGHT (price set to $price)");
						}
					else {
						}
					}
				if (not defined $price) {
					$CART2->is_debug() && $PKG->pooshmsg("TRACE|+FLEX/WEIGHT price not set (disabling)");
					}
				}
			
			}
		elsif ($m->{'handler'} eq 'SIMPLE') {
			$price = &ZSHIP::FLEX::calc_simple($PKG->get('items_count'),$m->{'itemprice'},$m->{'addprice'});
			}
		elsif ($m->{'handler'} eq 'LOCAL') {
			my $hashref = &ZTOOLKIT::parseparams($m->{'data'});
			my $zip = $CART2->in_get('ship/postal');
			#if ($zip eq '') { $zip = $CART2->in_get('ship.zip'); }
			# if ($zip eq '') { $zip = $CART2->in_get('cgi.zip'); }
			my @zips = ();
			$m->{'@zips'} = \@zips;
			foreach my $set ( sort { $a <=> $b } keys %{$hashref} ) {
				next if (defined $price);	
				my ($start,$end) = split(/-/,$set,2);
				push @zips, [ $start, $end, $price ];
				if (($zip >= $start) && ($zip <= $end)) {
					$price = $hashref->{$set};
					}
				}
			}
		elsif ($m->{'handler'} eq 'LOCAL_CANADA') {
			my $hashref = &ZTOOLKIT::parseparams($m->{'data'});
			my $zip = $CART2->in_get('ship/postal');
			# if ($zip eq '') { $zip = $CART2->in_get('cgi.zip'); }
			$zip = uc($zip);
			$zip =~ s/[^A-Z0-9]+//g;
			study($zip);
			foreach my $zippattern ( sort keys %{$hashref} ) {
				if ($zip =~ /^$zippattern/) {
					($price,$instructions) = split(/\|/,$hashref->{$zippattern},2);
					}
				}
			}
		elsif ($m->{'handler'} eq 'PRICE') {
			my $hashref = &ZTOOLKIT::parseparams($m->{'data'});
			my $TOTAL = $PKG->value('items_total');

			use Data::Dumper; print STDERR Dumper($PKG->sum());			
			# $CART2->is_debug() && $PKG->pooshmsg("TRACE|+PRICE IS: ".Dumper($PKG));

			$CART2->is_debug() && $PKG->pooshmsg("TRACE|+PRICE IS: $TOTAL ");
			print STDERR "TOTAL IS: $TOTAL\n";

			if (($m->{'min_price'}>0) && ($TOTAL<$m->{'min_price'})) {
				## total doesn't meet min price!
				$price = undef;
				}
			else {
				foreach my $t (sort { $a <=> $b } keys %{$hashref}) {
					next if (defined $price);
					print STDERR "TOTAL: t[$t] >= TOTAL[$TOTAL]\n";
					if ($t >= $TOTAL) { 
						$CART2->is_debug() && $PKG->pooshmsg("TRACE|+PRICE MATCH $t>=$TOTAL WAS[$price] IS[$hashref->{$t}]  ");
						($price) = $hashref->{$t};
						}
					}
				}

			if (not defined $price) {
				## failure, no rate!
				}
			elsif (substr($price,0,1) eq '%') {
				## percentages
				$price = substr($price,1);
				$price = sprintf("%.2f", ($price / 100) * $PKG->get('items_total'));
				}
			elsif (substr($price,0,1) eq '=') {
				## ooh.. future: formula based price!
				}
			else {
				## fixed dollar amounts
				$price = $price;
				}
			## end of price based shipping!
			}
		else {
			$PKG->pooshmsg("INFO|+Unknown flex shipping handler: $m->{'handler'}");
			$price = undef;
			}
			

		if (not defined $price) {
			$CART2->is_debug() && $PKG->pooshmsg("RULES|+Rules were skipped because price was not set.");
			}
		elsif ($m->{'rules'}<=0) {
			$CART2->is_debug() && $PKG->pooshmsg("RULES|+Rules are disabled");
			}
		else {
			$CART2->is_debug() && $PKG->pooshmsg("RULES|+Starting Rules - price was:$price");
			$price = &ZSHIP::RULES::do_ship_rules($CART2, $PKG, $m->{'id'}, $price);
			if (not defined $price) {
				$CART2->is_debug() && $PKG->pooshmsg("RULES|+Finished Rules - price no longer set, method will be disabled.");
				}
			else {
				$CART2->is_debug() && $PKG->pooshmsg("RULES|+Finished Rules - price is now: $price");
				}
			}

		if (not defined $price) {
			## we will not be adding this to $METHODSREF
			$CART2->is_debug() && $PKG->pooshmsg("INFO|+CANNOT OFFER METHOD name=[$m->{'name'}] id=[$m->{'id'}]");
			}
		else {
			## 
			$CART2->is_debug() && $PKG->pooshmsg("INFO|+Flex Shipping Added: carrier=[$m->{'carrier'}] name=[$m->{'name'}] id=[$m->{'id'}] price=[$price]");
			$m->{'amount'} = $price;
			$m->{'pretty'} = $m->{'name'};
			push @{$SHIPMETHODSREF}, $m;
			}
		}

	#use Data::Dumper;
	#print STDERR Dumper($METHODSREF);

	return();
	}

##
## brought over from ZSHIP::SIMPLE
##
sub calc_simple {
	my ($count,$price1,$price2) = @_;

	my $price = 0;
	if ((not defined $price1) || ($price1 eq '')) { $price1 = 0; }
	$price1 =~ s/\$//; $price1 += 0; # Normalize 
	if ((not defined $price2) || ($price2 eq '')) { $price2 = 0; }
	$price2 =~ s/\$//; $price2 += 0; # Normalize 
	
	$price += $price1;
	if ($count > 1) {
		$price += ($price2 * ($count - 1));
		}
	
	return($price);
	}

##
## brought over from ZSHIP::SIMPLEMULTI
##
sub calc_simplemultiprice {
	my ($CART2,$PKG,$key1,$key2) = @_;

	my %pids = ();
	my %claims = ();

#	my ($package,$file,$line,$sub,$args) = caller(1);
#	print  STDERR "($package,$file,$line,$sub,$args)\n";
#
#	use Data::Dumper; print STDERR Dumper($STUFF);

	# format skus into pids.
	# build a hash of pid/qty
	foreach my $item (@{$PKG->items()}) {
	
		my $quantity = $item->{'qty'};

		my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($item->{'stid'});
		next if (substr($pid,0,1) eq '%');		# skip promotions

		if (not defined $pids{$pid}) { $pids{$pid} = 0; }
		$pids{$pid} += $quantity;

		if (($claim) || ($item->{'stid'} =~ /^0\*/)) { $claims{$pid} += $quantity; }
		}
	## sanity:
	# at this point %pids contains a list of product ids, and quantities
	# at this point %pidskumap is a hash keyed by sku, with pid in the value

	my @ar = keys %pids;

	my $prodsref = &ZOOVY::fetchproducts_into_hashref($CART2->username(),\@ar);

	# algorithm follows
	## I seem to have data that occasionally the fetchproducts_into_hashref doesn't return all products.
	## I have exercised the function, but have been unable to reproduce. 
	if (keys %{$prodsref} != scalar(@ar)) {
#		## uhoh .. we didn't find all the products
#		open F, ">>/tmp/debug.simplemulti";
#		print F "--------------------------------------------------------------\n";
#		print F time()." - $merchant\n";
#		print F Dumper($prodsref);
#		print F Dumper(\@ar);
#		print F Dumper($STUFF);
#		close F;
#		$prodsref = &ZOOVY::fetchproducts_into_hashref($CART2->username(),\@ar);		# just for shits, we'll try it again!
		}

	# step1 - figure out which product has the highest fixed cost
	my $highprice = undef;
	my $highpid = undef;
	foreach my $pid (@ar) {
		if (not defined $prodsref->{$pid}->{$key1}) { $prodsref->{$pid}->{$key1} = 0; }
		if ($prodsref->{$pid}->{$key1} eq '') { $prodsref->{$pid}->{$key1} = 0; }

		if (not defined $highprice) {
			$highprice = $prodsref->{$pid}->{$key1};
			$highpid = $pid;
			}
		elsif ($prodsref->{$pid}->{$key1} == $highprice) {
			if ($prodsref->{$pid}->{$key2} < $prodsref->{$highpid}->{$key2}) {
				$highpid = $pid;
				}
			}
		elsif ($prodsref->{$pid}->{$key1} > $highprice) {		
			$highprice = $prodsref->{$pid}->{$key1};
			$highpid = $pid;
			}
		}


	## if highpid isn't defined, then we didn't find a high price
	if (defined $highpid) {
		# step2 - set the fixed cost to the highest cost, and subtract that items qty
		$pids{$highpid} -= 1;

		# step3 - interate through the remaining products, adding their secondary costs.	
		foreach my $pid (keys %pids) {
			next if ($pids{$pid}<=0);

			if (not defined $prodsref->{$pid}->{$key2}) { $prodsref->{$pid}->{$key2} = 0; }
			elsif ($prodsref->{$pid}->{$key2} eq '') { $prodsref->{$pid}->{$key2} = 0; }

			$highprice += ($prodsref->{$pid}->{$key2} * $pids{$pid});
			}
		}

	##
	## if we had any claims, then we add the markup value for those.
	foreach my $pid (keys %claims) {
		next if (not defined $prodsref->{$pid}->{'zoovy:ship_markup'});
		next if ($prodsref->{$pid}->{'zoovy:ship_markup'} eq ''); 
		$highprice += ($prodsref->{$pid}->{'zoovy:ship_markup'} * $claims{$pid});
		}

	return(sprintf("%.2f",$highprice));
	}


1;

