package ZSHIP::HANDLING;

use strict;


##
## area is: 'dom','can','int'
##
sub calc_flat {
	my ($area,$prefix,$CART2,$WEBDBREF) = @_;
	my $TOTAL = 0;

	my $key1 = $prefix.'_'.$area.'_item1';		# i.e. hand_dom_item1 - the first item price
	my $key2 = $prefix.'_'.$area.'_item2';		# i.e. hand_int_item2 - each additional item price

	my $count = $CART2->stuff2()->count('show'=>'real');
	if ($count>0) { 
		$TOTAL += sprintf("%.2f",$WEBDBREF->{$key1}); 
		$count--;
		$TOTAL += sprintf("%.2f",$WEBDBREF->{$key2} * $count);
		}
	return($TOTAL); 
	}

##
## area is: 'dom','can','int'
##
sub calc_product {
	my ($area,$attrib,$CART2,$WEBDBREF) = @_;
	my $TOTAL = 0;

	foreach my $item (@{$CART2->stuff2()->items()}) {
		my $fee = $item->{'%attribs'}->{$attrib};
		next if ((not defined $fee) || ($fee eq ''));
		$TOTAL += sprintf("%.2f",$fee);
		}

	return($TOTAL);
	}

##
## area is: 'dom','can','int'
##
sub calc_weight {
	my ($area,$prefix,$CART2,$WEBDBREF) = @_;
	my $TOTAL = 0;

	my $result = $CART2->stuff2()->sum({'show'=>'real'});
	# my $weight = $CART2->in_get('sum/pkg_weight');
	my $weight = $result->{'pkg_weight_194'};
	if ($area eq 'dom') {
		$weight = $result->{'pkg_weight_194'};
		# $CART2->in_get('sum/pkg_weight_194');
		}
	else {
		$weight = $result->{'pkg_weight_166'};
		# $CART2->in_get('sum/pkg_weight_166');
		}
	my $ref = &ZTOOLKIT::parseparams($WEBDBREF->{$prefix.'_weight_'.$area});

	my $matched = 0;
	foreach my $oz (sort { $a <=> $b; } keys %{$ref}) {
		if (($matched==0) && ($oz>=$weight)) { $matched = 1; }

		next unless ($matched==1);
		## when matched is 1, we found the next "oz" value that 
		$TOTAL = sprintf("%.2f",$ref->{$oz});
		$matched=2;
		}	

	return($TOTAL);
	}


##
## area is: 'dom','can','int'
##
sub calc_price {
	my ($area,$prefix,$CART2,$WEBDBREF) = @_;
	my $TOTAL = 0;

	# my $price = $CART2->in_get('sum/order_total');
	my $result = $CART2->stuff2()->sum({'show'=>'real'});
	my $price = $result->{'items_total'};
	my $ref = &ZTOOLKIT::parseparams($WEBDBREF->{$prefix.'_price_'.$area});

	my $matched = 0;
	foreach my $oz (sort { $a <=> $b; } keys %{$ref}) {
		next if ($oz !~ /^[\d\.]+$/);	# verify this is a number

		if (($matched==0) && ($oz>=$price)) { $matched = 1; }

		next unless ($matched==1);
		## when matched is 1, we found the next "oz" value that 
		$TOTAL = sprintf("%.2f",$ref->{$oz});
		$matched=2;
		}	

	return($TOTAL);
	}



1;
