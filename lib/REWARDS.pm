package REWARDS;

use strict;
use POSIX qw (strftime);
use lib "/backend/lib";
require ZWEBSITE;
require PRODUCT;
require ZTOOLKIT;

##
## Rewards Hash:
##		NAME => Program Name 
##		OPTIONS => bitwise
##			1 = Exclude Incomplete items from eligibility.
##			2 = Disable promotions when reward points are used.
##			3 = Allow negative orders (if disabled,  a customer must have a order total greater than or
##			4 = Base points on subtotal instead of grand total (subtotal does not include shipping, tax,
##		POINTS => bitwise
##			1 = add POINTS1_INC for every dollar spent
##			2 = add POINTS2_INC for every POINTS2_BUMP spent
##		BOUNTY_FREESHIP => Points needed for Free Shipping / Handling
##		BOUNTY1_INC => Points needed for BOUNTY1_SUM $ coupon
##		BOUNTY2_INC => Points needed for BOUNTY2_SUM $ coupon
##		BOUNTY3_INC => Points needed for BOUNTY3_SUM $ coupon
##		BOUNTY11_INC => Points needed for BOUNTY11_DISC % coupon
##		BOUNTY12_INC => Points needed for BOUNTY12_DISC % coupon
##		BOUNTY13_INC => Points needed for BOUNTY13_DISC % coupon
##	
##		EXPIRE (value)
##			1 => Points are cumulative and never expire.
##			2 => Points are cumulative for a period of EXPIRE_DAYS
##			3 => Points are consumable, but do not expire.
##			4 => Points are consumable, and they do expire
##		EXPIRE_OPTIONS
##			1 => give customers a EXPIRE_GRACEDAYS
##			2 => Daily point reduction of EXPIRE_DAILYLOSS
##			3 => Maximum Point Lifetime EXPIRE_MAXLIFE
##
##		AUTO_EXPLAIN =>
##		ZOOVY:REWARDS_EXPLANATION => 
##
sub recompute_rewards {
	my ($USERNAME,$EMAIL) = @_;

	my $profilestr = &ZWEBSITE::fetch_website_attrib($USERNAME,'rewards');
	my $params = &ZTOOLKIT::parseparams($profilestr);

#	require CUSTOMER::BATCH;
#	foreach my $oid (&CUSTOMER::BATCH::customer_orders($USERNAME,$CID)) {
#		print "OID: $oid\n";
#		my ($o) = ORDER->new($USERNAME,$oid);
#		print &REWARDS::calc_rewards($USERNAME,$EMAIL,$o,$params)."\n\n";
#		}
	
	}


##
## Disable promotions when reward points are used.
##	Allow negative orders (if disabled, a customer must have a order total greater than or equal to zero to checkout).
##
#sub calc_rewards {
#	my ($USERNAME,$EMAIL,$O2,$params) = @_;
#
#	if (not defined $O2) { return(0); }
#
#	my $SKIP = 0;
#	if (not defined $params) {
#		my $profilestr = &ZWEBSITE::fetch_website_attrib($USERNAME,'rewards');
#		$params = &ZTOOLKIT::parseparams($profilestr);
#		}
#
#	## Step1: is this order created AFTER the start date.
#	if ((not $SKIP) && ($params->{'STARTDATE'} ne '')) {
#		# print STDERR "$params->{'STARTDATE'}\n";
#		# print STDERR $o->get_attrib('created')."\n";
#		if (strftime("%Y%m%d",localtime($o->get_attrib('created'))) < $params->{'STARTDATE'}) { $SKIP = 1; }
#		}	
#
#	my $ORDERTOTAL = $o->get_attrib('order_total');
#	## Base points on subtotal instead of grand total (subtotal does not include shipping, tax, etc.) 
#	if ((not $SKIP) && ($params->{'OPTIONS'} & 8)) {
#		$ORDERTOTAL = $o->get_attrib('order_subtotal');
#		}
#	
#
#	## Step2: determine if incomplete items are excluded (if so, remove them)	
#	if ((not $SKIP) && ($params->{'OPTIONS'} & 1)) {
#		foreach my $item ($O2->stuff2()->as_array()) {
#			my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($item->{'stid'});
#			next unless ($claim>0);
#			print STDERR "SUBTRACTING CLAIM #$claim from $ORDERTOTAL / PRICE: $item->{'price'}\n";
#			$ORDERTOTAL -= $item->{'price'};
#			}
#		}
#
#
#	##
#	## SANITY: at this point $TOTAL is set. Now we can start the "conversion" process.
#	##
#	my $POINTS = 0;
#
#	## Add POINTS1_INC points for every dollar spent.
#	if ((not $SKIP) && ($params->{'POINTS'} & 1)) { 
#		$POINTS += int($ORDERTOTAL)*int($params->{'POINTS1_INC'}); 
#		print STDERR "$POINTS += int($ORDERTOTAL)*int($params->{'POINTS1_INC'})\n";
#		}
#	## Add POINTS2_INC points for every POINTS2_BUMP dollars spent (note: this always rounds down).
#	if ((not $SKIP) && ($params->{'POINTS'} & 2)) {
#		$POINTS += int($ORDERTOTAL/$params->{'POINTS2_BUMP'}) * int($params->{'POINTS2_INC'}); 
#		}
#	print "SKIP: $SKIP ORDERTOTAL: $ORDERTOTAL POINTS: $POINTS $params->{'POINTS'}\n";
#
#	##
#	## Sanity:
#	## 
#	if ($SKIP) { return(0); } else { return($POINTS); }	
#
#	}
#

sub set_rewards {
	}


1;

