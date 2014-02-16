package STUFF2::PACKAGE;

use strict;
use Data::Dumper;

use lib "/backend/lib";

BEGIN { push @STUFF2::PACKAGE::ISA, 'STUFF2'; }

sub lm { return($_[0]->{'*MSGS'}); }
sub msgs { return($_[0]->{'*MSGS'}->msgs()); }

sub new {
	my ($CLASS, $CART2, $ID, %options) = @_;

	my $self = {};
	$self->{'_ID'} = $ID;
	$self->{'*CART2'} = $CART2;
	$self->{'@ITEMS'} = [];
	if (defined $options{'@ITEMS'}) {
		$self->{'@ITEMS'} = $options{'@ITEMS'};
		}
	$self->{'@RATES'} = [];
	$self->{'*MSGS'} = LISTING::MSGS->new($CART2->username());
	bless $self, $CLASS;
	return($self);
	}


##
##
##
sub sum {
	my ($self, %params) = @_;

	warn "STUFF2::PACKAGE::sum doesn't actually work\n";
	my $ref = $self->cart2()->stuff2()->sum(undef,%params);
#	open F, ">/tmp/asdf";
#	print F Dumper($self);
#	close F;

	return($ref);


	return({});
	}

sub count {
	my ($self) = @_;

	return scalar(@{$self->{'@ITEMS'}});

	return(0);
	}

sub cart2 { return($_[0]->{'*CART2'}); }
sub id { return($_[0]->{'_ID'}); }
sub is_local { 
	my ($self) = @_;

	my $groupid = $self->id();
	if (index($groupid,'?')>0) { $groupid = substr($groupid,0,index($groupid,'?')); }	# strip LOCAL?asdf to just 'LOCAL'

	return ( (($groupid eq '') || ($groupid eq 'LOCAL') || ($groupid =~ /^LOCAL:(.*?)$/))?1:0 );
	}



## value/get 
##		params: 
##			qty=>1 (for single qty)
sub get { return(&STUFF2::PACKAGE::value(@_)); }
sub value {
	my ($self, $key, %params) = @_;

	my $sums = $self->sum({},%params);
	if (not defined $sums->{$key}) {
		warn Carp::cluck("INVALID STUFF2/PACKAGE KEY READ '$key' (undef returned)\n");
		}
	return($sums->{$key});
	}

sub items {
	my ($self) = @_;
	return($self->{'@ITEMS'});
	}


sub pretty_dump {
	my ($self) = @_;

	my $c = '';
	$c .= "----------------------------------------------------------------------------\n";
	$c .= sprintf("PackageID: %s\n",$self->id());
	foreach my $item (@{$self->{'@ITEMS'}}) {
		$c .= sprintf("- %20s\t%d\t%d\t%s\n",$item->{'stid'},$item->{'weight'},$item->{'qty'},$item->{'prod_name'});
		}

	foreach my $line (@{$self->msgs}) {
		$c .= sprintf("%s\n",$line);
		}

	$c .= 'RATES: '.Dumper($self->{'@RATES'});
	$c .= "\n\n";
	return($c);
	}


sub shipmethods { my ($self) = @_;return($self->{'@RATES'}); }

sub pooshmsg {
	my ($self,$msg) = @_;
	$self->{'*MSGS'}->pooshmsg($msg);
	return();
	}


sub calculate_rates {
	my ($self, $METAREF) = @_;

	my $PKG = $self;
	my $groupid = $PKG->id();
	my $CART2 = $PKG->cart2();

	my @SHIPMETHODS = ();
	my $WEBDBREF = $CART2->webdb(); 
	my $STATE = $CART2->in_get('ship/region');
	my $COUNTRYCODE = $CART2->in_get('ship/countrycode');

	$self->lm()->flush();
	if ($CART2->is_staff_order()) {
		## staff orders always get a free shipping option!
		push @SHIPMETHODS, { 'id'=>'STAFF', 'carrier'=>'SLOW', 'luser'=>$CART2->is_staff_order(), 'name'=>sprintf('Free Shipping (%s)',$CART2->is_staff_order()), 'amount'=>0, 'handling'=>0, 'insurance'=>0 };
		}	


	## yeah, i guess we'll assume it's domestic (eventually we should probably assume their country)
	if ($COUNTRYCODE eq '') { $COUNTRYCODE = 'US'; }

	if ($PKG->is_local() && $COUNTRYCODE eq 'US') {
		$PKG->pooshmsg('INFO|+*** RUNNING LOCAL SHIPPING ***');
		## eventually we'll need to do local methods here (and treat local the same as suppyl chain)
		# elsif (defined $shipref) {}	## hmm.. somehow shipref is already set, so we don't need to go in here.
		## NOTE: In some cases (with virtuals specifically) there might be no items in the cart.
		
		## Calculate the weight
		if (defined $WEBDBREF->{'ship_origin_zip'}) {
			$METAREF->{'origin.zip'} = $WEBDBREF->{'ship_origin_zip'};
			$METAREF->{'origin.country'} = 'US';
			$METAREF->{'origin.state'} = &ZSHIP::zip_state($WEBDBREF->{'ship_origin_zip'});
			}
	
		## Calculate the origin zip
		my $ORIG_ZIP = $WEBDBREF->{'ship_origin_zip'};
		if ($CART2->is_debug()) { $PKG->pooshmsg("INFO|+Origin Zip code is: $ORIG_ZIP"); }
	
		## Calculate the destination zip
		my $DEST_ZIP = $CART2->in_get('ship/postal');
		if (not defined $DEST_ZIP) { $DEST_ZIP = '';  }
		$DEST_ZIP =~ s/^(\d\d\d\d\d).*$/$1/;    # Strip Zip+4 info.
		$CART2->in_set('ship/postal',$DEST_ZIP);
	
		## Get the state from the zip if we don't recognize the state and the zip looks valid.
		## This addition effectively makes $STATE optional when $DEST_ZIP is present and good.
		if (not defined $CART2->in_get('ship/region')) { $CART2->in_set('ship/region','');  }
		if ((not &ZTOOLKIT::isin(\@ZSHIP::STATE_CODES,$CART2->in_get('ship/region'))) && ($DEST_ZIP =~ m/^\d\d\d\d\d$/)) {
			$CART2->in_set('ship/region',&ZSHIP::zip_state($DEST_ZIP));
			}
	
		##
		## FLEX SHIPPING (DOMESTIC)
		##
		if (&ZSHIP::good_to_go($METAREF)) {	
			## flex code!
	 		if ($CART2->is_debug()) { $PKG->pooshmsg("INFO|+Entered flex shipping"); }
			require ZSHIP::FLEX;
			&ZSHIP::FLEX::calc($CART2,$PKG,'US',$WEBDBREF,\@SHIPMETHODS,$METAREF);
			if ($CART2->is_debug()) { $PKG->pooshmsg("INFO|+finished flex shipping"); }
			}
	
		##
		## freight center
		## 
		if ((defined $WEBDBREF->{'freight_center'}) && ($WEBDBREF->{'freight_center'})) {
			## shipping freight is fun.
			}
	
	
		##
		## FEDEX
		##
		# Check to see if we're using the API for shipping...?
		$METAREF->{'has_fedex_rates'} = 0;
		require ZSHIP::FEDEXWS;
		my ($fdxcfg) = &ZSHIP::FEDEXWS::load_webdb_fedexws_cfg($CART2->username(),$CART2->prt(),$WEBDBREF);
		if (not $fdxcfg->{'enabled'}) {
			$PKG->pooshmsg("INFO|+Skipped Domestic/FedEx because not enabled.");					
			}	
		elsif ( 
			($fdxcfg->{'dom.ground'}==0) &&
			($fdxcfg->{'dom.home'}==0) &&
			($fdxcfg->{'dom.home_eve'}==0) &&
			($fdxcfg->{'dom.3day'}==0) &&
			($fdxcfg->{'dom.2day'}==0) &&
			($fdxcfg->{'dom.nextday'}==0)
			) {
			$PKG->pooshmsg("INFO|+Skipped Domestic/FedEx because no domestic methods are enabled.");					
			}
		elsif ($fdxcfg->{'meter'}==0) {
			$PKG->pooshmsg("INFO|+Skipped Domestic/FedEx because meter not available");					
			}
		elsif (&ZSHIP::is_usps_only($CART2->in_get('ship/address1'),$CART2->in_get('ship/region'))) {
			$PKG->pooshmsg("INFO|+Skipped Domestic/FedEx because address is USPS only.");					
			}
		elsif ($DEST_ZIP eq '') {
			$PKG->pooshmsg("INFO|+Skipped Domestic/FedEx because DEST_ZIP is not set.");					
			}
		elsif (not &ZSHIP::good_to_go($METAREF)) {
			$PKG->pooshmsg("INFO|+Skipped Domestic/FedEx because wer're not META good to go.");					
			}
		else {
			$PKG->pooshmsg("INFO|+Entered shipping type Domestic/FedEx");
			my ($methodsref) = &ZSHIP::FEDEXWS::compute($CART2,$PKG,$fdxcfg,$METAREF);	
			if (not defined $methodsref) {
				$PKG->pooshmsg("INFO|+FedexWS experienced a fatal error");					
				}
			elsif (scalar(@{$methodsref})==0) {
				$PKG->pooshmsg("INFO|+No methods returned from FedEx Domestic");					
				}
			else {
				$METAREF->{'has_fedex_rates'}++;		
				foreach my $method (@{$methodsref}) { 
					$PKG->pooshmsg("INFO|+ADDED METHOD: ".&ZTOOLKIT::buildparams($method));					
					push @SHIPMETHODS, $method; 
					}
				}
			$PKG->pooshmsg("INFO|+Finished shipping type Domestic/FedEx");
			}
	
		# print STDERR Dumper($CART);
	
	
		##
		## UPS SHIPPING (DOMESTIC)
		##
		if (ZSHIP::num($WEBDBREF->{'upsapi_dom'})>0) {
			## upgrade old webdb to new format
			require ZSHIP::UPSAPI;
			&ZSHIP::UPSAPI::upgrade_webdb($WEBDBREF);
			}
	
	
		my $HAS_UPS_RESTRICTION = &ZSHIP::has_ups_restriction($CART2->username());
	
		if ($WEBDBREF->{'upsapi_config'} ne '') {
			my $config = &ZTOOLKIT::parseparams($WEBDBREF->{'upsapi_config'});
			# open F, ">>/tmp/config"; print F "$WEBDBREF->{'upsapi_config'}\n"; close F;
	
			if (not $HAS_UPS_RESTRICTION) { 
				delete $METAREF->{'force_single'}; 
				}
			
			if (not $config->{'enable_dom'}) {
				$PKG->pooshmsg("INFO|+Skipped Domestic/UPS because not enabled.");						}
			elsif ($DEST_ZIP eq '') {
				$PKG->pooshmsg("INFO|+Skipped Domestic/UPS because no zip code");
				}
			elsif (($METAREF->{'has_fedex_rates'}) && ($HAS_UPS_RESTRICTION)) {
				$PKG->pooshmsg("INFO|+UPS rates cannot be shown next to FedEx");
				}
			elsif ( (not &ZSHIP::good_to_go($METAREF)) && ($HAS_UPS_RESTRICTION)) {
				$PKG->pooshmsg("INFO|+Skipped Domestic/UPS because not good_to_go in meta");
				}
			elsif (&ZSHIP::is_usps_only($CART2->in_get('ship/address1'),$CART2->in_get('ship/region'))) {
				$PKG->pooshmsg("INFO|+Skipped Domestic/UPS because appears to be USPS only address");
				}
			else {
				if ($CART2->is_debug()) { $PKG->pooshmsg("INFO|+Entered shipping type Domestic/UPS API"); }
				require ZSHIP::UPSAPI;
				my ($resultsref) = &ZSHIP::UPSAPI::compute($CART2,$PKG,$WEBDBREF,$METAREF);
		
				# print STDERR 'UPSRESULTS'.Dumper($resultsref);
				if (defined $resultsref) {	
					foreach my $m (@{$resultsref}) {
						next if (not defined $m->{'amount'});					
						push @SHIPMETHODS, $m;
						$METAREF->{'has_ups_rates'}++;
						}
					}
				}
	
			}
		else {
			$PKG->pooshmsg("INFO|+Skipped Domestic/UPS because it was not enabled.");
			}
		##
		## END UPS SHIPPING (DOMESTIC)
		##
	
	
	
		##
		## USPS SHIPPING (DOMESTIC)
		##
		if (&ZSHIP::num($WEBDBREF->{'usps_dom'}) && &ZSHIP::good_to_go($METAREF)) {
			if ($CART2->is_debug()) { $PKG->pooshmsg("INFO|+Entered shipping type Domestic/USPS"); }
			# use Data::Dumper; if ($CART2->is_debug() & 128) { $PKG->pooshmsgDINFO|+umper($METAREF)); }
			my $DEST_ZIP_USPS = ($DEST_ZIP eq '') ? '' : $DEST_ZIP;
			require ZSHIP::USPS;
			my $HANDLING = &ZTOOLKIT::def($WEBDBREF->{'usps_dom_handling'});
			my ($USPSMETHODS) = &ZSHIP::USPS::domestic_compute($CART2,$PKG,$WEBDBREF,$METAREF);
			foreach my $uspsmethod (@{$USPSMETHODS}) {
				my $amount = &ZSHIP::RULES::do_ship_rules($CART2, $PKG, "USPS_DOM", $uspsmethod->{'amount'});
				if (defined $amount) {
					$uspsmethod->{'amount-before-rules'} = $uspsmethod->{'amount'};
					$uspsmethod->{'amount'} = $amount;
					push @SHIPMETHODS, $uspsmethod;
					}
				}
			}

		}
	elsif ($PKG->is_local() && $COUNTRYCODE ne 'US') {
		my $ORIG_ZIP = $WEBDBREF->{'ship_origin_zip'};
		# if (!$ORIG_ZIP) { $ORIG_ZIP = &ZOOVY::fetchmerchant_attrib($CART2->username(), 'zoovy:zip'); }
		# if $ORIG_ZIP is not set, then default to Cardiff, CA.
		# if (!$ORIG_ZIP) { $ORIG_ZIP = "92007"; }
	
		require ZSHIP::FLEX;
		if (uc($COUNTRYCODE) eq 'CA') {
			&ZSHIP::FLEX::calc($CART2,$PKG,'CA',$WEBDBREF,\@SHIPMETHODS,$METAREF);
			}
		else {
			&ZSHIP::FLEX::calc($CART2,$PKG,'INT',$WEBDBREF,\@SHIPMETHODS,$METAREF);
			}
	
		##
		## FEDEX
		##
		# Check to see if we're using the API for shipping...?
		$METAREF->{'has_fedex_rates'} = 0;
		require ZSHIP::FEDEXWS;
		my ($fdxcfg) = &ZSHIP::FEDEXWS::load_webdb_fedexws_cfg($CART2->username(),$CART2->prt(),$WEBDBREF);
		# print STDERR Dumper($fdxcfg);
	
		if (not $fdxcfg->{'enabled'}) {
			$PKG->pooshmsg("INFO|+Skipped International/FedEx because not enabled.");					
			}	
		elsif ( 
			($fdxcfg->{'int.ground'}==0) &&
			($fdxcfg->{'int.2day'}==0) &&
			($fdxcfg->{'int.nextnoon'}==0) &&
			($fdxcfg->{'int.nextearly'}==0) 
			) {
			$PKG->pooshmsg("INFO|+Skipped International/FedEx because no international methods are enabled.");					
			}
		elsif ($fdxcfg->{'meter'}==0) {
			$PKG->pooshmsg("INFO|+Skipped International/FedEx because meter not available");					
			}
		elsif (&ZSHIP::is_usps_only($CART2->in_get('ship/address1'),$CART2->in_get('ship/region'))) {
			$PKG->pooshmsg("INFO|+Skipped International/FedEx because address is USPS only.");					
			}
		#elsif ($CART2->in_get('ship/int_zip') eq '') {
		#  ## NOTE: we'll make something up if we don't have one.
		#	$PKG->pooshmsg("INFO|+Skipped International/FedEx because DEST_ZIP is not set.");					
		#	}
		elsif (not &ZSHIP::good_to_go($METAREF)) {
			$PKG->pooshmsg("INFO|+Skipped International/FedEx because wer're not META good to go.");					
			}
		else {
			$PKG->pooshmsg("INFO|+Entered shipping type International/FedEx");
			my $methodsref = &ZSHIP::FEDEXWS::compute($CART2,$PKG,$fdxcfg,$METAREF);	
			if (not defined $methodsref) {
				$PKG->pooshmsg("INFO|+FedexWS experienced a fatal error");					
				}
			elsif (scalar(@{$methodsref})==0) {
				$PKG->pooshmsg("INFO|+No methods returned from FedEx International");					
				}
			else {
				$METAREF->{'has_fedex_rates'}++;		
				foreach my $method (@{$methodsref}) { push @SHIPMETHODS, $method; }
				}
			$PKG->pooshmsg("INFO|+Finished shipping type International/FedEx");
			}
	
	
		# print STDERR Dumper($CART);
	
		my $HAS_UPS_RESTRICTION = &ZSHIP::has_ups_restriction($CART2->username());
	
		##
		## UPS SHIPPING (INTERNATIONAL)
		##
	
		if ((not &ZSHIP::good_to_go($METAREF)) && ($HAS_UPS_RESTRICTION)) {
			## sorry, we're not allowed to do UPS
			}
		elsif (&ZSHIP::num($WEBDBREF->{'upsapi_int'})) {
			if ($CART2->is_debug()) { $PKG->pooshmsg("INFO|+Entered shipping type International/UPS API"); }
			##
			## NEW UPS
			##
			require ZSHIP::UPSAPI;
			my ($resultsref) = &ZSHIP::UPSAPI::compute($CART2,$PKG,$WEBDBREF,$METAREF);
			if (defined $resultsref) {	
				foreach my $m (@{$resultsref}) {
					next if (not defined $m->{'amount'});					
					push @SHIPMETHODS, $m;
					# $METHODS{$m->{'carrier'}.'|'.$m->{'pretty'}} = $m->{'amount'};
					}
				}
			}
		## END UPS SHIPPING (INTERNATIONAL)
		##
	
		##
		## USPS SHIPPING (INTERNATIONAL)
		##
		if (&ZSHIP::num($WEBDBREF->{'usps_int'}) && &ZSHIP::good_to_go($METAREF)) {
			my $INS      = &ZSHIP::bucks($WEBDBREF->{'usps_int_ins'});
			my $HANDLING = &ZTOOLKIT::def($WEBDBREF->{'usps_int_handling'});
			require ZSHIP::USPS;
	
			if ($CART2->is_debug()) { $PKG->pooshmsg("INFO|+Running USPS Int"); }
	
			my ($USPSMETHODS) = &ZSHIP::USPS::international_compute($CART2, $PKG, $WEBDBREF, $INS, $METAREF);
			if (scalar(@{$USPSMETHODS})==0) {
				if ($CART2->is_debug()) { $PKG->pooshmsg("INFO|+No methods returned from USPS::calc_ups_international"); }
				}
	
			foreach my $uspsmethod (@{$USPSMETHODS}) {
				my $amount = &ZSHIP::RULES::do_ship_rules($CART2, $PKG, "USPS_INT", $uspsmethod->{'amount'});
				if (defined $amount) {
					$uspsmethod->{'amount-before-rules'} = $uspsmethod->{'amount'};
					$uspsmethod->{'amount'} = $amount;
					push @SHIPMETHODS, $uspsmethod;
					}
				}
	
			## here's where we figure out which services the merchant wants to support
			## basically there's no easy way to do this since the USPS returns full text
			
			## Commented out section moved part into USPS.pm, and most of the rest into the new function
			## calc_handling_insurance above.
			## The hash was getting created in one way, modified there, then getting altered here, this
			## should consolidate this sort of thing and other shipping methods should be migrated on
			## an as-needed basis.
			}


		##
		## END USPS SHIPPING (INTERNATIONAL)
		##
		}
	#elsif ($groupid =~ /^JEDI\:(.*?)$/) {
	#	## JEDI
	#	&ZOOVY::confess($CART2->username(),"JEDI VIRTUAL $groupid",justkidding=>1);
	#	my $SUPPLIERCODE = $1;
	#	require SUPPLIER::JEDI;
	#	my ($shipresults,$metaresults) = SUPPLIER::JEDI::compute_shipping($CART2->username(),$SUPPLIERCODE,$CART);	
	#	if (defined $metaresults) { %{$METAREF} = (%{$METAREF}, %{$metaresults}); }
	#	@m = @{$shipresults};
	#	if (scalar(@m)==0) {
	#		$METAREF->{'ERROR'} = "JEDI $groupid failed";
	#		}
	#	}
	elsif ($groupid =~ /^SUPPLIER\:FBA(\?.*)?$/) {
		##
		## FBA rates
		##
		my ($S) = $CART2->getSUPPLIER('FBA');
		require SUPPLIER::FBA;
		my ($shipmethods) = &SUPPLIER::FBA::shipquote($S, $CART2, $PKG);
		foreach my $m (@{$shipmethods}) {
			## we use build_shipmethod_row here just so we know that this is yet another place shipmethods are added.
			## it's not necessary, the data from $shipmethods is intended to be used directly.
			push @SHIPMETHODS, &ZSHIP::build_shipmethod_row($m->{'name'},$m->{'amount'},%{$m});
			}
		}
	elsif ($groupid =~ /^SUPPLIER\:(.*?)(\?.*)?$/) {
		## GENERIC
		#require SUPPLIER::GENERIC;
		#my $SHIPPINGAMOUNT = &SUPPLIER::GENERIC::compute_shipping($CART2, $S, $groupid);

		my ($S) = $CART2->getSUPPLIER($1);
		if (not defined $S) {
			warn "WTF? you need to pass \$S to have us compute shipping\n";
			}
		#if (not defined $S) {
		#	## NOTE: $s should only be set when we call ourselves recursively.
		#	($S) = SUPPLIER->new($USERNAME,$SUPPLIERCODE);
		#	}
		## merchant has since deleted the Supplier but not the product's association
		## with the Supplier (ie zoovy:virtual, zoovy:prod_supplier, zoovy:prod_supplierid)
		if (not defined $S) { return(undef); }
		#if (($S->fetch_property('.ship.options')&1)==1) {
		#	&ZOOVY::confess($CART2->username(),"MULTIBOX SHIPPING WAS ENABLED, BUT NO LONGER SUPPORTED",justkidding=>1);
		#	}

		## MULTIBOX OPTION
		my $SHIPTOTAL = 0;

		## DO NOT DISABLE MULTIBOX SHIPPING **THIS WAY** because it will save to the supplier in memory
		# $S->save_property('.ship.options',0);		# turn off multibox shipping.

		my $total = 0;
		# my $SHIPMETHODS = $S->fetch_property('.ship.methods');
		my $SHIP_CONNECTOR = $S->fetch_property('SHIP_CONNECTOR'); 

		if ((defined $total) && ($SHIP_CONNECTOR eq 'FREE')) {
			## woot, free shipping!
			$total = 0;
			}
	
		##
		##	Fixed Shipping!
		##
		## if ((defined $total) && (($SHIPMETHODS&1)==1)) {
		if ((defined $total) && ($SHIP_CONNECTOR eq 'FIXED')) {
			## (1) Fixed Shipping		
			require ZSHIP::FLEX;
			my $price = 0;

			## USA
			if ($CART2->in_get('ship/countrycode') eq '') {
				$price = &ZSHIP::FLEX::calc_simplemultiprice($CART2,$PKG, 'zoovy:ship_cost1', 'zoovy:ship_cost2');
				}
			elsif ($CART2->in_get('ship/countrycode') eq 'US') {
				$price = &ZSHIP::FLEX::calc_simplemultiprice($CART2,$PKG, 'zoovy:ship_cost1', 'zoovy:ship_cost2');
				}
			## Canada
			elsif ($CART2->in_get('ship/countrycode') eq '') {
				$price = &ZSHIP::FLEX::calc_simplemultiprice($CART2,$PKG, 'zoovy:ship_can_cost1', 'zoovy:ship_can_cost2');
				}
			## International
			else {
				$price = &ZSHIP::FLEX::calc_simplemultiprice($CART2,$PKG, 'zoovy:ship_int_cost1', 'zoovy:ship_int_cost2');
				}
	
			$total += $price;
			}

 
		##
		##	Zone based!
		##
		## if ((defined $total) && (($SHIPMETHODS&2)==2)) {
		if ((defined $total) && ($SHIP_CONNECTOR eq 'ZONE')) {
			## (2) Zone Based
			my ($shipref,$METAREF) = (undef,undef);
		
			## so GEN_SHIPMETER is a URI encoded key value pairs e.g. 
			## type=UPS&user=tinaso2336&pass=osanit1202&license=5BE0D184D8F6B520&shipper_number=1E609R
			my $METERREF = &ZTOOLKIT::parseparams($S->fetch_property('.ship.meter')); ## NEED!		

			my %fake_webdb = ();
			my $methodsref = undef;
	
			if ($S->fetch_property('.ship.meter_createdgmt')==0) {	
				$total = undef;	## meter not registered!
				}
			elsif ($METERREF->{'type'} eq 'FEDEX') {
				require ZSHIP::FEDEXWS;
				my ($fdxcfg) = &ZSHIP::FEDEXWS::load_supplier_fedexws_cfg($CART2->username(),$S->id(),$S);
				($methodsref) = ZSHIP::FEDEXWS::compute($CART2,$PKG,$fdxcfg,$METAREF);
				#use Data::Dumper;
				#print STDERR 'methodsref: '.Dumper($methodsref,$fdxcfg,$CART2);
				}
			elsif ($METERREF->{'type'} eq 'UPS') {
				my %config = ();
				$config{'.dom_packaging'} = 'SMART';
				$config{'.int_packaging'} = 'SMART';
				$config{'.rate_chart'} = '01';
	
				require ZSHIP::UPSAPI;
				$config{'STD'} = 1;
				$config{'XPR'} = 1;
				$config{'enable_dom'} = 1;
				$config{'GND'} = 1;				
				if ($S->fetch_property('.ship.options')&1) {	$config{'.multibox'} = 1; } ## MULTIBOX

				$config{'.license'} = $METERREF->{'license'};
				$config{'.userid'} = $METERREF->{'user'};
				$config{'.password'} = $METERREF->{'pass'};
				$config{'.shipper_number'} = $METERREF->{'shipper_number'};
				$config{'.residential'} = 1;
				$config{'.use_rules'} = 0;
				$fake_webdb{'upsapi_config'} = &ZTOOLKIT::buildparams(\%config,1);
				if ($S->fetch_property('.ship.origzip') ne '') {
					$fake_webdb{'ship_origin_zip'} = $S->fetch_property('.ship.origzip');
					}
		
				($methodsref) = &ZSHIP::UPSAPI::compute($CART2,$PKG,\%fake_webdb,$METAREF);
				}

			if (defined $methodsref) {
				$shipref = {};
				foreach my $set (@{$methodsref}) {
					next if (not defined $set->{'amount'});
					$shipref->{ $set->{'carrier'}.'|'.$set->{'pretty'} } = $set->{'amount'};
					}
				}
	
			my $lowprice = undef;
			if (defined $shipref) {
				foreach my $m (keys %{$shipref}) {
					if (not defined $lowprice) { $lowprice = $shipref->{$m}; }
					elsif (($lowprice > $shipref->{$m}) && ($shipref->{$m}>0)) { $lowprice = $shipref->{$m}; }
					}
				}	
			if (not defined $lowprice) { $total = undef; } else { $total += $lowprice; }
			}

		##
		##	Handling!
		##
		## if ((defined $total) && (($SHIPMETHODS&32)==32)) {
		if (defined $total) {
			## (32) Handling
			## | GEN_HNDPERORDER   | decimal(8,2)                        |      |     | 0.00    |                |
			## | GEN_HNDPERITEM    | decimal(8,2)                        |      |     | 0.00    |                |
			## | GEN_HNDPERUNIITEM | decimal(8,2)                        |      |     | 0.00    |                |
			
			if ($S->fetch_property('.ship.hnd_perorder')) {
				$total += $S->fetch_property('.ship.hnd_perorder');
				}
		
			if ($S->fetch_property('.ship.hnd_peritem')>0) {
				my $count = $CART2->stuff2()->count();
				$total += ($count*$S->fetch_property('.ship.hnd_peritem'));
				}
		
			if ($S->fetch_property('.ship.hnd.perunititem')>0) {
				my $count = $CART2->stuff2()->count(1+2);
				$total += ($count*$S->fetch_property('.ship.hnd_perunititem'));
				}
			}
					
		my $SHIPPINGAMOUNT = $total;

		if (not defined $SHIPPINGAMOUNT) {
			$METAREF->{'ERROR'} = "No methods returned from $groupid";
			}
		else {
			push @SHIPMETHODS, &ZSHIP::build_shipmethod_row("Shipping",$SHIPPINGAMOUNT,'carrier'=>'SLOW','id'=>"SUPPLIER-$SHIP_CONNECTOR");
			}
		}
	#elsif ($groupid =~ /^API\:(.*?)$/) {
	#	&ZOOVY::confess($CART2->username(),"API VIRTUAL $groupid",justkidding=>1);
	#	my $SUPPLIERCODE = $1;
	#	require SUPPLIER::API;
	#	my ($shipresults, $metaresults) = SUPPLIER::API::compute_shipping($CART2->username(),$SUPPLIERCODE,$CART);
	#	if (defined $metaresults) { %{$METAREF} = (%{$METAREF}, %{$metaresults}); }
	#	@m = @{$shipresults};
	#	if (scalar(@m)==0) {
	#		$METAREF->{'ERROR'} = "virtual $groupid failed";
	#		}
	#	}
	#elsif ($groupid =~ /^PARTNER\:(.*?)$/) {
	#	&ZOOVY::confess($CART2->username(),"PARTNER VIRTUAL $groupid",justkidding=>1);
	#	my $SUPPLIERCODE = $1;
	#
	#	my ($S) = SUPPLIER->new($CART2->username(),$SUPPLIERCODE);
	#	my $PARTNER = $S->fetch_property('PARTNER');
	#	print STDERR "ZSHIP VIRTUAL PARTNER: $PARTNER\n";
	#	if ($PARTNER eq 'DOBA') {
	#		require SUPPLIER::DOBA;
	#		my ($vshipref) = SUPPLIER::DOBA::compute_shipping($CART2->username(),$SUPPLIERCODE,$CART);
	#		if ((defined $vshipref) && (ref($vshipref) eq 'HASH')) {
	#			# %m = %{$vshipref};
	#			@m = @{&ZSHIP::legacy_hashref_to_shipref($vshipref,'default_carrier'=>'SLOW')};
	#			}
	#		else {
	#			$METAREF->{'ERROR'} = "virtual $groupid failed";
	#			}
	#		}
	#	## need to add support for other PARTNERs
	#	else { 
	#		$METAREF->{'ERROR'} = "virtual $groupid failed"; 
	#		}
	#	}
	elsif ($groupid =~ /^FIXEDPRICE\:([\d\.]+)$/) {
		## FIXEDPRICE:0.00 an absolute fixed value for each item, e.g. 3.50
		my $amount = sprintf("%2.f",$1*100);
		if ($amount == 0) {
			push @SHIPMETHODS, &ZSHIP::build_shipmethod_row( 'Free Shipping', 0, 'carrier'=>'SLOW' );
			}
		else {
			push @SHIPMETHODS, &ZSHIP::build_shipmethod_row( 'Shipping', sprintf("%.2f",$1 * $CART2->stuff2()->count('virtual'=>$groupid)), 'carrier'=>'SLOW' );
			}
		}
	#elsif ($groupid =~ /^EBAY\:(.*?)$/) {
	#	my $UUID = $1;
	#	if (
	#		($CART2->in_get('ship/postal') eq '') && 
	#		($CART2->in_get('ship/countrycode') eq '')
	#		) {
	#		## this won't work, but shouldn't cause an error.
	#		## eventually this should trigger ZIP code to be enabled.
	#		$PKG->pooshmsg('sh'INFO|+No shipping zip code found (required for eBay)');
	#		}
	#	else {
	#		require SUPPLIER::EBAY;
	#		my ($vshipref) = SUPPLIER::EBAY::compute_shipping($CART2->username(),$UUID,$CART2,$METAREF);
	#			if (defined $vshipref) {
	#			# %m = %{$vshipref};				
	#			@m = @{&ZSHIP::legacy_hashref_to_shipref($vshipref,'default_carrier'=>'SLOW')};
	#			}
	#		else {
	#			$PKG->pooshmsg'INFO|+No methods returned from eBay (failing over to store shipping)');
	#			$METAREF->{'ERROR'} = 'No methods returned from eBay';	
	#			## FAIL OVER CODE - someday we'll probably want to make this configurable.
	#			if (ref($SHIPMENTS{''}) ne 'STUFF') { $SHIPMENTS{''} = STUFF->new($CART2->username()); }
	#			foreach my $stid ($CART->{'stuff'}->stids()) {
	#				$SHIPMENTS{''}->{$stid} = $CART->{'stuff'}->{$stid};
	#				}
	#			delete $METAREF->{'ERROR'};
	#			}
	#		}
	#	}
	else {
		$METAREF->{'ERROR'} = 'UNKNOWN INTERNAL PROVIDER:'.$groupid;
		$PKG->pooshmsg(sprintf("ISE|+%s",$METAREF->{'ERROR'}));
		}

	if (scalar(@SHIPMETHODS) <= 0) {
		my $WEIGHT = $PKG->get('pkg_weight_194');
		my $lbs = sprintf("%.2f",$WEIGHT/16);
		if ($CART2->is_debug()) { $PKG->pooshmsg("INFO|+Uh-oh -- no methods found, added 'Actual Cost' method!"); }
		push @SHIPMETHODS, &ZSHIP::build_shipmethod_row("Actual Cost to be Determined [$lbs lbs]",0,carrier=>"ERR");
		if (not defined $METAREF->{'ERROR'}) {
			$METAREF->{'ERROR'} = "$groupid had no rates";
			}
		}

	## make sure all shipping methods returned have a unique id=> (since this is required now)
	foreach my $method (@SHIPMETHODS) {
		if (not defined $method->{'id'}) {
			$method->{'id'} = uc($method->{'carrier'}.'-'.$method->{'name'}.'-'.$method->{'amount'});
			$method->{'id'} =~ s/[^0-9A-Z\-]/-/gs;	
			}
		if (not defined $method->{'carrier'}) {
			$method->{'carrier'} = 'SLOW'; 
			}
		}

	if ($CART2->is_debug()) {
		my $out = '';
		foreach my $ms (@SHIPMETHODS) {
			$out .= sprintf("name:%s carrier:%s price:%s |",$ms->{'name'},$ms->{'carrier'},$ms->{'amount'});
			}
		$PKG->pooshmsg("INFO|+RESULT: $out");
		}

	$PKG->pooshmsg('END|+FINISHED PROCESSING SHIPMENT:'.$groupid);
	$PKG->{'@RATES'} = \@SHIPMETHODS;

	# print STDERR Dumper(\@SHIPMETHODS);

	return(\@SHIPMETHODS);
	}


1;

