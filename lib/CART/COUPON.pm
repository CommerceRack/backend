package CART::COUPON;


use strict;
use Storable;
use lib "/backend/lib";
require ZOOVY;
require ZWEBSITE;

##
## the coupons file is structured as a hashref of codes
##
##	the value is another hashref that contains:
##
##		created_gmt=>
##		modified_gmt=>
##		title=>the title of the coupon
##		


##
## returns an arrayref of coupons sorted by code.
##
sub list {
	my ($webdbref,%options) = @_;

	my $ref = $webdbref->{'%COUPONS'};
	my @result = ();

	foreach my $x (sort keys %{$ref}) {
		next if ((defined $options{'auto'}) && (not $ref->{'auto'}));
		$ref->{$x}->{'code'} = $x;
		push @result, $ref->{$x};
		}

	return(\@result);
	}

##
##
##
sub add {
	my ($webdbref,$CODE) = @_;
	return(&CART::COUPON::save($webdbref,$CODE,{
		title=>"New Coupon ($CODE)",
		taxable=>1,
		}));
	}


sub delete {
	my ($webdbref,$CODE) = @_;

	if ($CODE ne '') {
		my ($ref) = $webdbref->{'%COUPONS'}; 
		if (defined $ref->{$CODE}) {
			delete $ref->{$CODE};
			}
		}
	}


sub save {
	my ($webdbref,$CODE, %options) = @_;

	if ($CODE ne '') {
		my ($ref) = $webdbref->{'%COUPONS'};
		if (not defined $ref->{$CODE}) { $ref->{$CODE} = { created_gmt=>time() }; }
		
		$ref->{$CODE}->{'modified_gmt'} = time();
		foreach my $k (keys %options) {
			next if ($k eq '');
			next if (not defined $options{$k});
	
			$ref->{$CODE}->{$k} = $options{$k};
			}
		}
	else {
		}
	}



sub load {
	my ($webdbref,$CODE) = @_;
	my ($ref) = $webdbref->{'%COUPONS'};
	
	if (defined $ref->{$CODE}) {
		## make sure the coupon has an ID set
		$ref->{$CODE}->{'id'} = $CODE;
		if (not defined $ref->{$CODE}->{'taxable'}) {
			## default to taxable = 1 (most coupons aren't rebates)
			$ref->{$CODE}->{'taxable'} = 1;
			}
		if (not defined $ref->{$CODE}->{'auto'}) {
			## default to a non-auto coupon
			$ref->{$CODE}->{'auto'} = 0;
			}
		if (not defined $ref->{$CODE}->{'stacked'}) {
			## default to a non-stacked coupon
			$ref->{$CODE}->{'stacked'} = 0;
			}
		
		}
	elsif (length($CODE)>5) {
		## coupon was not found, and we have a CODE longer than 5 characters, 
		## so we'll default back to 5 on a miss, to see if we have an older code.
		warn "Caught legacy 5 digit coupon code!";
		$CODE = substr($CODE,0,5);
		return(&CART::COUPON::load($webdbref,$CODE));
		}

	if (defined $ref->{$CODE}) {
		$ref->{$CODE}->{'type'} = 'coupon';
		}

	return($ref->{$CODE});	
	}


1;
