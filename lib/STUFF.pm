package STUFF;

use strict;

use Clone;
use Data::Dumper;
use Carp;
use lib '/backend/lib';
require ZWEBSITE;
require PRODUCT;
require POGS;
require ZSHIP;
require ZTOOLKIT;
require EXTERNAL;

sub def { ZTOOLKIT::def(@_); }
sub entab { ZTOOLKIT::entab(@_); }
sub encode_latin1 { ZTOOLKIT::encode_latin1(@_); }

##
## <item 
##		waitship_qty	 integer
##		waitship_notes	 varchar(45)
##		>
##
##
##

##
## the TO_JSON method is used by JSON::XS->new->utf8->allow_blessed(1)->convert_blessed(1)->encode($R);
##	(PAGE::JQUERY)
##
sub TO_JSON {
	my ($self) = @_;
	my @r = ();

	foreach my $stid ($self->stids()) {
		my $i = Clone::clone($self->item($stid));
		delete $i->{'full_product'}->{'zoovy:base_cost'};
		delete $i->{'full_product'}->{'zoovy:pogs'};
		#$i->{'pogs'} = $i->{'%attribs'}->{'zoovy:pogs'};
		#delete $i->{'%attribs'}->{'zoovy:pogs'};
		#if ($i->{'pogs'} ne '') {
		#	#my @pogs = &POGS::text_to_struct("", $i->{'full_product'}->{'zoovy:pogs'}, 1);
		#	#$i->{'@pogs'} = \@pogs;
		#	my @pogs = &POGS::text_to_struct("", $i->{'pogs'}, 0);
		#	$i->{'@pogs'} = \@pogs;
		#	delete $i->{'pogs'};
		#	}

		delete $i->{'%attribs'}->{'zoovy:pogs'};
		$i->{'*pogs'} = $i->{'@pogs'};
		delete $i->{'@pogs'};
		
		push @r, $i;
		}
	return(\@r);
	}


##
## option shortcuts:
##		#Z12 = product opt-group (#Z) option: 12
##		0AFG = store opt-group (0A) option: FG
##		##00 = first of a particular stid with unique text
##		##01 = second of a particular stid with unique text
##		A2## = store opt-group (A2) with a text based value
## 


#
#
#
#
# '*options' => {
#                                   '0G02' => {
#                                               'w' => '',
#                                               'p' => '',
#                                               'value' => 'Black',
#                                               'img' => 'swchkiddblack',
#                                               'v' => '02',
#                                               'prompt' => 'Inlay',
#                                               'modifier' => 'w=|p=|img=swchkiddblack'
#                                             },
#
#
#          '*options' => {
#                          '040C' => {
#                                      'value' => 'Mens',
#                                      'modifier' => '',
#                                      'prompt' => 'Gender'
#                                    },
#                          '0300' => {
#                                      'value' => 'D (Standard Mens)',
#                                      'modifier' => '',
#                                      'prompt' => 'Width'
#                                    },
#                          'A2' => {
#                                    'value' => '',
#                                    'modifier' => '',
#                                    'prompt' => 'Order notes'
#                                  },
#                          'A40E' => {
#                                      'value' => 'Size 11',
#                                      'modifier' => '',
#                                      'prompt' => 'Size'
#                                    }
#                        },
#



##
## set properties such as schedule
##
sub set_property {
	my ($self, $property, $value) = @_;
	$self->{"_$property"} = $value;
	return();
	}


##
## get a property (such as schedule)
##
sub get_property {
	my ($self, $property) = @_;
	return($self->{"_$property"});
	}


## Creates a new STUFF object.  You can pass in an existing STUFF format hash of hashes and this will
## bless it into the class if it hasn't been already.
sub new {
	my ($class, $USERNAME, %params) = @_;

	my $DEBUG = 0;
	my $self = {};

	$self->{'_USERNAME'} = $USERNAME;
	bless $self, 'STUFF';

	foreach my $property ('schedule','cartid') {
		if (defined $params{$property}) {
			$self->set_property($property,$params{$property});
			}
		}

	if ($params{'xml'}) {
		## load this from xml
		## $params{'xmlcompat'}
		foreach my $item (@{STUFF::from_xml($params{'xml'},$params{'xmlcompat'})}) {
			my $stid = $item->{'stid'};
			if ($stid eq '') { $stid = $item->{'sku'}; $item->{'_warn'} = 'stid missing in new->from_xml'; }
			if ($stid eq '') { $stid = Data::GUID->new()->as_string(); $item->{'_warn'} = 'stid,sku not set in new->from_xml - using random guid'; }
			$self->{ $stid } = $item;
			}
		}

	if ($params{'stuff'}) {
		## populate this with existing stuff (verbatim)
		## note: this DOES NOT require that it be blessed, it effectively does a re-cram
		foreach my $stid (keys %{$params{'stuff'}}) {
			next if (substr($stid,0,1) eq '_');	# skip reserved fields ex.: _USERNAME

			## this does a quick version check of the stuff object, to see if we need to fix the pogs
			my $item = $params{'stuff'}->{$stid};
			if (defined $item->{'*pogs'}) {
				## new format options
				}
			elsif (not defined $item->{'pogs'}) {
				## this is odd, but probably fine.
				}
			elsif ($item->{'pogs'} eq '') {
				## this is fine, no options
				}
			elsif ( (ref($item->{'pogs'}) eq '') && ($item->{'pogs'} =~ /^<pog/) ) {
				## legacy option format
				# &ZOOVY::confess($USERNAME,"UPGRADED LEGACY POG STRUCTURE INSIDE STUFF",justkidding=>1);
				my (@pogs) = &POGS::text_to_struct($USERNAME,$item->{'pogs'},1);
				$item->{'*pogs'} = &POGS::upgrade_struct(\@pogs);
				delete $item->{'pogs'};
				}

			$self->recram( $item );
			}
		}

	return $self;
	}

sub username { return($_[0]->{'_USERNAME'}); }


sub DESTROY {
	my ($self) = @_;

	##
	## NOTE: destroying the cart as such causes unpleasantness inside ZSHIP virtual handling.
	##
	}


##
## this is intended to add an item which has already been run through a cram.
##		for example copying from one stuff object to another.
##
sub recram {
	my ($self,$item,%params) = @_;

	$self->{ $item->{'stid'} } = $item;
	return(0,'');
	}






## 
## A STUFF style entry MUST have the following fields:
##      stid=>
##      qty => the quantity of the item.  Zeros will delete the item
##      pogs => The pog specification for the product, either an old-format comma-separated list OR a new format XMLish spec
##      base_price => The price before any options are applied (OPTIONAL)
##      base_weight => The weight before any options are applied
##      prod_name => Pretty name for the product
##      taxable => 1/0 Whether the item can be taxed or not (Not truly required, will default to false if missing)
##		%options or *options (see OPTION PROPERTIES section below)
##
##	the following should probably NEVER be set, unless you're also passing
##pid => the BASE product without any POGS selected






##
## Takes in an $item ref, and computes the optimal quantity price
##		'3=24.95,12=23.95,36=22.00',
##		6/144
##
sub qty_price {
	my ($item) = @_;

	$item->{'price'} = $item->{'base_price'};
	## note: if we have option price differences between base_price and $item->{'price'} we should add those
	if (defined $item->{'pogs_price_diff'}) {
		$item->{'price'} += $item->{'pogs_price_diff'};
		}

	my $newprice;
	foreach my $entry (split /[\,\n\r]+/, $item->{'qty_price'}) {
		my ($qtylimit,$operator,$qtyprice) = ($entry =~ m/^(.+?)(\=|\/)(.+?)$/);
		## qtylimit is the starting # allowed ex: must by 5
		## operator can be either / or =  (5=125 means buy 5 @ $125ea., 5/125 means buy 5 @ $25ea.)
	
		$qtylimit =~ s/\D//gs;		# strip non numeric from limit
		$qtyprice =~ s/[^\d\.]//gs;	# strip non numeric + decimal

		next unless ($qtylimit <= $item->{'qty'});		## this wont look at qty's below our current qty
		if ($operator eq '=') {
			$newprice = sprintf('%.2f', $qtyprice);
			}
		elsif ($operator eq '/') {
			$newprice = sprintf('%.2f', ($qtyprice/$qtylimit));
			}
		}

	## okay, so what happens if we have option modifiers which alter the base price.
	##	holy shit, yeah i know thats fucked up. so i've left a clue in STUFF->process_pog
	##	at the end it should set a variable called "pog_price_diff" in the item which we can
	## use here to add to the final price, this way the difference between base_price, and 
	##	modified base_price can be REAPPLIED to the $newprice .. that is of course assuming
	## this can be a little confusing though because when adding an item to the cart
	##	qty_price is run BEFORE process_pogs, so this line here is really only used when
	##	the customer decides to change the qty on a qty_price item that has option price modifiers.
	## yeah, i know how fucked up that is.

	## REMINDER: $newprice won't be set if there were no applicable qty price fields.
	if (defined $newprice) {
		if (defined $item->{'pogs_price_diff'}) {
			$newprice += $item->{'pogs_price_diff'};
			}
		$item->{'price'} = $newprice; 
		}

	}



##
##
##
sub structure_qtyprice {
	## return:
	##
	## [ 'pallet', 36, 0.95 ]
	## [ 'case', 6, 1.00 ]
	##	[ 'pair', 2, 1.50 ]
	## [ 'unit', 1, 2.00 ]
	## [ '+', 5, 1.00 ],
	}



##
## a digest representing items in the cart, and quantities.
##		if the cart changes, this will change guaranteed NOT to include pipes.
##
sub digest {
	my ($self) = @_;

	my $str = '';
	foreach my $stid ($self->stids()) {
		$str .= $stid.'='.$self->{$stid}->{'qty'}.',';
		}
	chop($str);
	return($str);
	}






##
## requires:
##		item->product needs to be set.
##		*options be setup
##			additionally: inv=> should be set in the *options
##		item->notes be *OPTIONALLY* set OR ##01
##		pog_sequence needs to be setup (even though this will reset it)
##
## purpose: rebuilds a stid
##				ensures that stid is unique.
##				sets up pog_sequence correctly
##				converts item->notes into a text based option
##
sub validate_stid {
	my ($self,$item,%params) = @_;

	my $note = $params{'note'};
	my $is_unique = 0;
	my $needs_unique = 0;

	## show some tough love:
	if ($params{'allow_no_options'}) {
		## don't fail, if there are no options setup (this is necessary since we want to consolidate all our 
		## stid handling, and there are cases were an item may have no options, and a $param{'note'} or even
		## might be part of a claim or assembly.
		}
	elsif (not defined $item->{'pog_sequence'}) {
		die("pog_sequence must be set before calling validate_stid");
		}
	elsif (not defined $item->{'*options'}) {
		print STDERR Carp::cluck();
		die("*options must be set before calling validate_stid");
		}
	elsif ($item->{'product'} eq '') {
		die("item->{'product'} must be set before calling validate_stid");
		}

	if ($item->{'product'} =~ /\:/) {
		warn "stuff->validate_stid says item->product ($item->{'product'}) appears to have options (fixin)\n";
		($item->{'product'}) = PRODUCT::stid_to_pid($item->{'product'});
		}
	
	my %options = ();	 #hash where key:pogid val: option
	my $invopts = '';
	my $noinvopts = '';
	my $unique_noinvopts = '';
	foreach my $optcode (sort keys %{$item->{'*options'}}) {
		## populate %options
		$options{ substr($optcode,0,2) } = substr($optcode,2,2);
		}

	## make a copy of %options we can destroy.
	my %is_extra__pog = %options;

	## step2: 
	my $new_pog_sequence = '';
	my %dup_optid = ();	## remove duplicate optcodes from pog_sequence
	foreach my $optid (split(/,/,$item->{'pog_sequence'})) {
		$optid = uc($optid);
		next if (defined $dup_optid{$optid});
		$dup_optid{$optid}++;
		my $optcode = $optid.$options{$optid};
		print STDERR "OPTCODE: $optcode\n";
		if (length($optcode)!=4) {
			warn "STUFF->validate_stid internal consistency error: optid $optid does not have entry in *options - ignoring";
			$optcode = '';
			}
		next if ($optcode eq '');
		delete $is_extra__pog{$optid};
		$new_pog_sequence .= "$optid,";

		if (substr($optcode,2,2) eq '##') {
			## we have one or more textboxen
			$needs_unique++;
			}
		if (substr($optcode,0,0) eq '##') {
			## already got ##xx
			$is_unique++;
			$unique_noinvopts = "/$optcode";
			}
		elsif ($item->{'*options'}->{$optcode}->{'inv'}>0) {
			## inventoriable
			$invopts .= ":$optcode";
			}
		else {
			# print Dumper($item->{'*options'});
			## non-inventoriable
			if ((length($noinvopts)<50) || (substr($optcode,2,2) eq '##')) {
				## we only append to noinvopts if it's not a textbox.
				$noinvopts .= "/$optcode";
				}
			}
		}
	chop($new_pog_sequence); # strip the trailing ,

	if ($item->{'pog_sequence'} ne $new_pog_sequence) {
		warn "detected a change in pog_sequence from $item->{'pog_sequence'} to $new_pog_sequence";
		$item->{'pog_sequence'} = $new_pog_sequence;
		}

	## step1: make sure pog_sequence is setup with everything in *options
	foreach my $pogid (keys %is_extra__pog) {
		warn "STUFF->validate_stid internal consistency error: *options has extra pogid: $pogid not found in pog_sequence ($item->{'pog_sequence'})";
		}


	$item->{'sku'}  = $item->{'product'}.$invopts;
	my $fullstid = $item->{'product'}.$invopts.$noinvopts;

	## in case sku isn't set.
	(my $pid,my $claim,undef,undef,my $virtual) = &PRODUCT::stid_to_pid($fullstid);
	
	##
	## okay now lets use the *options to make sure we didn't miss anything.
	##
	if ($is_unique) { 
		$needs_unique = 0; 	## we can't possibly need unique if we're already unique!
		}	


	##
	## shipping notes, or other types of notes (for secondact)
	## 	(i believe these are actually set in the cart stuff, by the website via ajax)
	##
	if ((defined $item->{'notes'}) && ($item->{'notes'} ne '')) {
		$item->{'notes'} =~ s/^[\s]*(.*?)[\s]*$/$1/;		# strip leading and trailing whitespace.
		}
	if (($item->{'notes'} ne '') && ($is_unique)) {
		## hmm.. we've already established we're unique e.g. ##001
		##	but we've also got notes, which make us unique.. dammit, so we'll append those and destory item->notes
		warn("item->notes is set, but is_unique already set to true! -- this line should never be reached");
		$item->{'*options'}->{ sprint("##%02d",$is_unique) }->{'value'} .= " |".$item->{'notes'};
		delete $item->{'notes'};
		}
	if ($item->{'notes'} ne '') {
		$needs_unique++;
		}


#	print STDERR Dumper($item,sku=>$sku,is_unique=>$is_unique,needs_unique=>$needs_unique);
#	die();


	## we need to be unique (probably because we have one or more text field,
	## or item notes, so loop through stuff until we can create a UNIQUE stid .. start at ##00,##01..##99
	my $pog_sequence = $item->{'pog_sequence'};
	my $base_stid = uc("$item->{'product'}$invopts$noinvopts");

	if ($needs_unique) {
		my $i = 0;
		my $trystid = uc(sprintf("%s/##%02d",$base_stid,$i));	## ABC:1234 becomes ABC:1234/##00

		while (defined $self->{$trystid}) { 
			++$i;
			$trystid = uc(sprintf("%s/##%02d",$base_stid,$i));	## ABC:1234 becomes ABC:1234/##00
			last if ($i>99);	## just in case the user does something stupid!
			}

		## NOTE: someday we might want to add 
		if ($item->{'notes'} ne '') {
			## if we have shipping notes, then add those as a text based option as the "unique" choice
			$pog_sequence .= ',##';	
			$item->{'*options'}->{ sprintf('##%02d',$i) } = {
				value=>$item->{'notes'},
				modified=>'',
				prompt=>'Notes',
				};
			}
		delete $item->{'notes'};
		$unique_noinvopts = sprintf("/##%02d",$i);
		}



	## duct-tape: make sure pog_sequence has all our options in it..
	my %pog_sequences = ();
	foreach my $pogid (split(/,/,$pog_sequence)) {
		$pog_sequences{$pogid}++;		
		}
	## normally we'll use the order in the stid (unless they were already set in pog_sequence)
	foreach my $optset (split(/[\/:]+/,"$invopts:$noinvopts:$unique_noinvopts")) {
		next if ($optset eq '');
		my ($pogid) = substr($optset,0,2); ## get #Z or #Z01
		next if ($pog_sequences{$pogid});  ## we've already got this particular pogid
		$pog_sequence .= ','.$pogid;
		$pog_sequences{$pogid}++;
		}
	## lastly, we'll make sure we didn't miss anything which is in *options	
	foreach my $optset (sort keys %{$item->{'*options'}}) {
		next if ($optset eq '');
		my ($pogid) = substr($optset,0,2); ## get #Z or #Z01
		next if ($pog_sequences{$pogid});  ## we've already got this particular pogid
		$pog_sequence .= ','.$pogid;
		$pog_sequences{$pogid}++;
		}

	if (substr($pog_sequence,0,1) eq ',') { $pog_sequence = substr($pog_sequence,1); } 	# strip leading ,
	$item->{'pog_sequence'} = $pog_sequence;

	## hmm.. we probably ought to rebuild description here!

	my $stid = "$base_stid$unique_noinvopts";
	if ((defined $item->{'claim'}) && ($item->{'claim'} ne '') && (index($stid,'*')<0)) { 
		$stid = $item->{'claim'}.'*'.$stid; 
		}

	if ((defined $item->{'assembly_master'}) && ($item->{'assembly_master'} ne '')) {
		$stid = $item->{'assembly_master'}.'@'.$stid;
		}
	# print STDERR "STID: $stid MASTER: $item->{'assembly_master'}\n";

	$item->{'stid'} = $stid;
	$item->{'sku'} = "$pid$invopts";
	$item->{'product'} = "$pid";

	##
	## remember: inventoriable options are NOT included in the STID anymore
	##		sku:inv1:inv2:inv3/##00
	##
	##

	return($stid,$pog_sequence);
	}




##
## change this function under penalty of death. it has bugs. it has big fucking bugs.  
## when we have a library, use it. then we only have to fix the bug in one fucking spot.
## this broke checkout for almost 3 weeks. caused lots of support tickets and generally ruined
## my fucking day. if you change this I will fire you. -BH
##
sub calc_pog_modifier
{
	my ($value, $modification) = @_;
	
#	print STDERR "VALUE: $value MOD: $modification\n";

	#   my ($diff,$pretty) = &ZOOVY::calc_modifier($value,$modification,1);
  	#	return($diff);


	## tweak for handling equal (=) modifiers
	if ($modification eq '=') { $modification = ''; }
	if ($modification eq '') { return($value); }
	elsif ($modification =~ /[\+\-]+/) {
	   my ($diff,$pretty) = &ZOOVY::calc_modifier($value,$modification,1);
  		return($diff);
		}
	else {
		$modification =~ s/[^\d\.]//gs;
		return($modification);
		}
	}

##
## Takes in a hash keyed by SKU with a value of the new quantity
## NOTE: if SKU has a / then it is stripped.
##		
sub update_quantities {
	my ($self, $update) = @_;

	my ($changes) = 0;

	foreach my $stid (keys %{$update}) {
		my $qty = $update->{$stid};

		$stid =~ s/\/$//; # Remove trailing slash if present. (since it won't appear that way in the cart)
		$stid = uc($stid);

		next unless defined($self->{$stid});
		next if def($self->{$stid}->{'force_qty'}, 0); 	## If force_qty is set for the sku, ignore this update	

		## enforce qty min
		if ((defined $self->{$stid}->{'minqty'}) && ($self->{$stid}->{'minqty'} > $qty)) {
			$qty = $self->{$stid}->{'minqty'};
			}


		## enforce qty inc
		if (not defined $self->{$stid}->{'incqty'}) {}
		elsif (int($self->{$stid}->{'incqty'})<=0) {}
		elsif (($qty % $self->{$stid}->{'incqty'}) > 0) {
			$qty += ($self->{$stid}->{'incqty'} - ($qty % $self->{$stid}->{'incqty'}));
			}

		## enforce qty max
		if (not defined $self->{$stid}->{'maxqty'}) {}
		elsif (int($self->{$stid}->{'maxqty'}) < $qty) {
			$qty = int($self->{$stid}->{'maxqty'});
			}

		if (($qty > 0) && ($self->{$stid}->{'qty'} == $qty)) {
			## same quantity, no changes!
			}
		elsif ($qty > 0) { 
			$self->{$stid}->{'qty'} = $qty;
			if ((def($self->{$stid}->{'qty_price'}) ne '') && ($stid !~ m/\*/)) {
				&qty_price($self->{$stid})
				}
			$changes++;
			}
		elsif ($qty <= 0) {
			$self->chuck($stid);
			$changes++;
			}
		##
		## NOTE: DO NOT, UNDER ANY FUCKING CIRCUMSTANCES TOUCH $self->{$stid} after this line
		## 	or you're likely to have zero qty items appearing in the cart!
		}

	##
	## Update the quantity for any assembly components
	##
	foreach my $stid ($self->stids()) {
		next if (not defined $self->{$stid}->{'assembly_master'});
		next if ($self->{$stid}->{'assembly_master'} eq '');

		my $assemblymaster = $self->{$stid}->{'assembly_master'};
		$self->{$stid}->{'qty'} = $self->{$assemblymaster}->{'qty'} * $self->{$stid}->{'assembly_qty'};
		}

	return($changes);
	}

## This takes STUFF and turns it into legacy style CART.pm contents.
sub make_contents {
	my ($self) = @_;
	my $contents = {};
	foreach my $sku ($self->stids()) {
		my $item = $self->{$sku};
		next unless defined $item;
		$contents->{$sku} = join ',', def($item->{'price'}), def($item->{'qty'}), def($item->{'weight'}), (taxable($item->{'taxable'})?'Y':'N'), def($item->{'description'});
		}
	return $contents;
	}


#
#	##  ##
#	##  ##
#	###### E Y  T H E R E  T U R B O!!!!!!! -- this is still used by the external/fastorder.cgi program
#	##  ##
#
#	foreach my $stid (keys %{$contents}) {
#		my ($price, $qty, $weight, $taxable, $description) = split /\,/, $contents->{$stid}, 5;
#		my $item = $self->item($stid);
#		my %additional = ();
#		if (defined($extra->{$stid})) {
#			%additional = ( 'trk' => $extra->{$stid} );
#			}
#
#		if (defined $item) {
#			if ($qty == 0) {
#				$self->chuck($stid);
#				}
#			else {
#				$self->update_item(
#					$stid, {
#						'price'       => $price,
#						'qty'         => $qty,
#						'weight'      => $weight,
#						'base_weight' => $weight,
#						'taxable'     => taxable($taxable),
#						'description' => $description,
#						'prod_name' => $description,
#						%additional,
#						}
#					);
#				}
#			}
#		else {
#			$self->legacy_cram(
#				{
#					'stid'        => $stid,
#					'price'       => $price,
#					'qty'         => $qty,
#					'weight'      => $weight,
#					'base_weight' => $weight,
#					'taxable'     => taxable($taxable),
#					'description' => $description,
#				'prod_name' => $description,
#					%additional,
#					}
#				);
#			}
#		}
#
#	}

##
sub update_value
{
	my ($self, $stid, $attribute, $value) = @_;
	if (defined $value)
	{
		if ($attribute eq 'qty') {
			$value =~ s/[^0-9-]//gs
			}
		elsif ( ($attribute eq 'price') || ($attribute eq 'base_price') ) {
			if ($value !~ m/-?\d*\.?\d+/) {
				$value = 0;
				}
			$value = sprintf('%.2f', $value);
			}
		elsif ( ($attribute eq 'weight') || ($attribute eq 'base_weight') ) {
			$value = ZSHIP::smart_weight($value);
			}
		elsif ($attribute eq 'taxable') {
			$value = taxable($value);
			}
		$self->{$stid}->{$attribute} = $value;
		}
	else {
		delete $self->{$stid}->{$attribute};
		}
	}


##
sub qty_list {
	my ($self) = @_;
	my %qtys = map { $_ => $self->{$_}->{'qty'} } $self->stids();
	return %qtys;
	}

##
## pass in a STID, returns the item properties.
##		returns undef if not defined!
##
sub item {
	my ($self, $stid) = @_;
	if (substr($stid,0,1) eq '_') {
		return(undef); 
		}
	elsif (not defined $self->{$stid}) {
		return(undef);
		}
	else {	
		my $item = $self->{$stid};

		## 4/22/08 - ooh, looks like paypal may not always set the stid. Bad Paypal!
		if ($item->{'stid'} eq '') { $item->{'stid'} = $stid;  }

		## 4/23/08 - ooh, looks like barefoottess put non-numeric values in their cost.
		$item->{'cost'} = sprintf("%.2f",$item->{'cost'});

		return($item);
		}
	return undef;
}

##
sub update_item {
	my ($self, $stid, $update) = @_;
	foreach my $attrib (keys %{$update}) {
		$self->{$stid}->{$attrib} = $update->{$attrib};
		}
	}

##
sub as_array
{
	my ($self) = @_;
	my @array = ();
	foreach my $stid ($self->stids())
	{
		my $item = $self->{$stid};
		$item->{'stid'} = $stid;
		push @array, $item;
	}
	return @array;
}

##
## pass a stid id
##
sub get {
	my ($self,$stid,$property) = @_;

	$stid = uc($stid); ## hmm.. STID's can't be lowercase, but yet sometimes we get them that way. dammit.
	my ($item) = $self->item($stid);
	if (defined $item) {
		if (index($property,'.')>0) {
			## we'll walk the tree.. e.g. full_product.zoovy:prod_name
			foreach (split(/\./,$property)) { $item = $item->{$_}; }
			return($item);
			}
		else {
			return($item->{$property});
			}
		}
	}

##
## property can be in the format:
##		full_product
##		attribs
##		yipes, this is pretty scary.
##
sub set {
	my ($self,$stid,$property,$value) = @_;

	$stid = uc($stid); ## hmm.. for some odd reason $STID often gets us in lower case. - don't remove with out testing.
#	print STDERR "STUFF SETTING: $stid,$property,$value\n";

	my ($item) = $self->item($stid);
	if (defined $item) {
		$item->{$property} = $value;
		}
	else {
		warn("Could not save $stid");
		}
	}

sub chuck {
	my ($self, $stid) = @_;

	## remove any assembly items that might be referencing this stid! 
	##		an assembly item will have assembly_master set
	foreach my $istid ($self->stids()) {
		next if ($stid eq $istid);
		my $item = $self->item($istid);
		if ((defined $item->{'assembly_master'}) && ($item->{'assembly_master'} eq $stid)) {
			$self->chuck($istid);
			} 
		}

	return delete $self->{$stid};
}

##
##
##
sub clean
{
	my ($self) = @_;
	foreach my $stid ($self->stids())
	{
		$self->chuck($stid);
	}
}

##
## formats stids into an array suitable for output (where the master stid comes before its children
##		and promotions and stuff are at the bottom)
##
sub stids_output {
	my ($self) = @_;

	my %st = (); 	## hash keyed by stid, value = added_gmt
	my %asm = ();	## hash keyed by asssembly_master, value is arrayref of component stids
	my @other = ();	## hash of other stuff (special stids) e.g. ! % which are added at the end.
	foreach my $stid ($self->stids()) {
		my $item = $self->item($stid);
		
		if ((defined $item->{'assembly_master'}) && ($item->{'assembly_master'} ne '')) {
			## handle assembly components
			if (not defined $asm{$item->{'assembly_master'}}) { $asm{$item->{'assembly_master'}} = (); }
			push @{$asm{$item->{'assembly_master'}}}, $stid;
			}
		elsif ((index($stid,'!')==0) || (index($stid,'%')==0)) {
			push @other, $stid;
			}
		else {
			$st{$stid} = int($item->{'added_gmt'});
			}
		}

	my @result = ();	## the final result we'll return
	## go through and add master stids, plus their assembly components
	foreach my $stid (ZTOOLKIT::value_sort(\%st,'numerically')) {
		push @result, $stid;

		## add assembly components (if any)
		if (defined $asm{$stid}) {
			foreach my $stid (@{$asm{$stid}}) { push @result, $stid; }
			}
		}
	
	## okay add any other crap !DISC, %SHIT
	foreach my $stid (@other) { push @result, $stid; }

	return(@result);		## to make this similiar to stids() we'll return an array
	}


##
## Returns all Stuff ID's (stids) for a STUFF as an array
##
sub stids {
	my ($self) = @_;
	return grep !m/^\_/, sort keys %{$self};
	}

##
## returns all products as an array
##
sub products {
	my ($self) = @_;
	my %products = ();

	foreach my $stid ($self->stids()) {
		my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($stid);
		next if (substr($pid,0,1) eq '%');
		next if (substr($pid,0,1) eq '_');
		$products{$pid} += $self->{$stid}->{'qty'};
		}

	return(\%products);
	}


##
## purpose: returns a count of all items in the cart
##	opts is a bitwise operator
##		undef = all values default to false
##			1 = only count real items (e.g. no !META) 
##			2 = only count each item once, regardless of quantity
##			4 = include in count % items (this was added for amz orders)
##			8 = include in count only master assembly items, skip children (this was added for amz orders)
##
sub count {
	my ($self,$opts) = @_;
	if (not defined $opts) { $opts = 0; }

	# print STDERR Dumper($self);

	my %STIDQTY = ();
	foreach my $stid ($self->stids()) {
		my $item = $self->{$stid};
		next unless defined $item;

		#next if (substr($stid,0,1) eq '%');
		## only skip % items if opts _not_ & 4, this is to support legacy settings (see above)
		## ie always skip % items, unless opts & 4
		next if (!($opts & 4) && (substr($stid,0,1) eq '%'));

		next if (($opts & 1) && ($item->{'product'} eq '') && ($item->{'sku'} eq ''));						# skip blank items
		next if (($opts & 1) && (substr($item->{'sku'},0,1) eq '!'));	# skip !META, etc. hidden items
		next if (($opts & 1) && (substr($item->{'sku'},0,1) eq '!'));	# skip !META, etc. hidden items
		
		
		if (($opts & 8) && (defined $item->{'assembly_master'}) && ($item->{'assembly_master'} ne '')) {
			# skip assembly children items, note this will skip the next check if $opts&1 is on ..
			# because otherwise anytype of virtual item wouldn't appear.
			$STIDQTY{$stid} = 0;
			}
		elsif (($opts & 1) && (defined $item->{'assembly_master'}) && ($item->{'assembly_master'} ne '')) {
			# skip or zero out any asssembly_master items in the stuff object
			# WHY? well if we buy a gift basket with 3 items, we should say "3 items" not "4"
			$STIDQTY{$item->{'assembly_master'}} = 0;
			}

		if (defined $STIDQTY{$stid}) {
			## hmm.. stids are unique, so this item has been blocked! (e.g. it was a master)
			}		
		elsif ($opts & 2) { 
			$STIDQTY{$stid} = 1; 
			} 
		else { 
			$STIDQTY{$stid} = $item->{'qty'};
			if (not defined $STIDQTY{$stid}) { $STIDQTY{$stid} = 0; }
			}

		}

	my $count = 0;
	foreach my $val (values %STIDQTY) {
		$count += int($val);
		}
	
	return $count;
	}

sub sanitize {
	my ($self) = @_;
	foreach my $stid ($self->stids())
	{
		my $item = $self->{$stid};
		$item->{'price'}    = sprintf('%.2f', $item->{'price'});
		$item->{'qty'}      = int($item->{'qty'});
		$item->{'extended'} = sprintf('%.2f', ($item->{'qty'} * $item->{'price'}));
	}
}


sub from_xml {
	my ($data,$xcompat) = @_;

	require XML::Parser;
	require XML::Parser::EasyTree;

	my @items = ();

	# <product id="OPTION/20AK:1" price="12.75" qty="1" cost="6" weight="8" taxable="1" channel="0" mktid="" mkt="" mkturl="" mktuser="" batchno="" description="" notes="" prod_name="This is test of option group / Simple Colors: Blue / Gift Message: Happy Birthday!" sku="" base_price="0.0000" force_qty="0" pogs_processed="0" pogs_price_diff="0.00" pog_sequence="" base_weight="0" special="0" schedule="" qty_price="0.00" added_gmt="0" inv_mode="" extended="0.0000">\r
	my $p1 = new XML::Parser(Style=>'EasyTree');
	foreach my $p (split(/<\/item>/s,$data)) {
		next unless ($p =~ /\<item(.*?)\>(.*)$/s);
		my ($attribsxml,$optsxml) = ($1,$2);


		# print STDERR "XML: <item $attribsxml/>\n";
		my $ref = $p1->parse("<item $attribsxml/>");
		next if (not defined $ref);
		$ref = $ref->[0]->{'attrib'};		## ditches everything but the attributes.

		# my $ref = &ZTOOLKIT::xmlish_list_to_arrayref("<item $attribsxml></item>",tag_attrib=>'item',content_attrib=>'')->[0];
		# next if (not defined $ref);
		my $stid = $ref->{'id'};
		if (not defined $ref->{'stid'}) {
			$ref->{'stid'} = $stid;		## NOTE: stid is *required* by SETSTUFF macro
			}

		delete $ref->{'id'};	 		## id contains the stid, which is redundant and not part of the record
		push @items, $ref;

		#if ($xcompat>100) {
		if ( (int($ref->{'claim'}) == 0) && (index($stid,'*')>0) ) {
			## add claim back into order, since zom apparently doesn't send it to us.
			$ref->{'claim'} = substr($stid,0,index($stid,'*'));
			}
		#	}


		## SANITY: at this point the stid should be added to stuff.				
		# print "ATTRIBS: [$attribsxml]\n";
		if ($optsxml =~ /<options>(.*?)<\/options>/s) {
      	# <option id="040C" prompt="Gender" value="Mens" modifier=""/>
	      # <option id="A2" prompt="Order notes" value="" modifier=""/>
     	 	# <option id="A501" prompt="Costume Shoe Size" value="Medium (Sizes 10-11)" modifier=""/> 
			# becomes:
         # '*options' => {                      
			#		'040C' => { 'value' => 'Mens', 'modifier' => '', 'prompt' => 'Gender' },
         #		'A2' => { 'value' => '', 'modifier' => '', 'prompt' => 'Order notes' },


			foreach my $tag (split(/(\<.*?\/\>)/s,$1)) {
				next if ($tag =~ /^[\t\s\n\r]*$/s);

				if (($xcompat <= 202) && ($tag =~ /\|prompt=/)) {
					## 2011-10-24 - so when we upgraded options to parse via xml, turns out becky wasn't encoding the
					##			modifier= section. so we'd end up with the modifier= below (notice the 24")
					## TAG: <option id="0107" modifier="v=07|prompt=M - 24"" prompt="Size" value="M - 24&quot;"/>
					## 		this little tidbit takes the 
					## TAG: <option id="0107" modifier="v=07|prompt=M - 24" prompt="Size" value="M - 24&quot;"/>
					# print STDERR "BROKE TAG: $tag\n";
					$tag =~ s/modifier=\"(.*?)\" prompt\=/modifier=\"**MODIFIER**\" prompt\=/gs;	
					my $modifier = $1;
					$modifier =~ s/[\"\<\>]+//gs;
					$tag =~ s/\*\*MODIFIER\*\*/$modifier/gs;
					# print STDERR "FIXED TAG: $tag\n";
					}

				# print STDERR "OPT: **$tag**\n";
				## TAG: <attrib id="zoovy:prod_image1" value="platsilverplats"/>
				my $x = $p1->parse($tag);
				$x = $x->[0]->{'attrib'};

				$ref->{'*options'}->{ $x->{'id'} } = $x;
				delete $x->{'id'};
				## use Data::Dumper; print Dumper($x);
				}
 
			}


		if ($optsxml =~ /<attribs>(.*?)<\/attribs>/s) {
			foreach my $tag (split(/(\<.*?\/\>)/s,$1)) {
				next if ($tag =~ /^[\t\s\n\r]*$/s);
				# print STDERR "TAG: $tag\n";
				## TAG: <attrib id="zoovy:prod_image1" value="platsilverplats"/>
				my $x = $p1->parse($tag);
				$x = $x->[0]->{'attrib'};
				$ref->{'%attribs'}->{ $x->{'id'} } = $x->{'value'};
				## use Data::Dumper; print Dumper($x);
				}
			}

		if (defined $ref->{'%attribs'}) {
			## list of variables which should copied into attribs when going to as_xml
			if (defined $ref->{'%attribs'}->{'buysafe:html'}) {
				$ref->{'buysafe_html'} = $ref->{'%attribs'}->{'buysafe:html'};
				delete $ref->{'%attribs'}->{'buysafe:html'};
				}
			}

		## assembly master should never be SET to blank!
		if ($ref->{'assembly_master'} eq '') {
			delete $ref->{'assembly_master'};
			}

		}

	return(\@items);	
	}


sub as_xml {
	my ($self,$xcompat) = @_;
	my $xml = '';
	my $errors = '';

	foreach my $stid ($self->stids()) {

		my $item = $self->item($stid);
		if (not defined $item->{'weight'}) { $item->{'weight'} = 0; }

		if (defined $item->{'buysafe_html'}) {
			## list of variables which should copied into attribs when going to as_xml
			$item->{'%attribs'}->{'buysafe:html'} = $item->{'buysafe_html'};
			delete $item->{'buysafe_html'};
			}

		
		my $extra = '';
		if ((defined $item->{'*options'}) && (ref($item->{'*options'}) eq 'HASH')) {
			my %opts = %{$item->{'*options'}};
			my $opt_xml = '';
			foreach my $oid (keys %opts) {
				my $id = encode_latin1($oid);
				my $value = encode_latin1(def($opts{$oid}->{'value'}));
				my $prompt = encode_latin1(def($opts{$oid}->{'prompt'}));
				my $modifier = encode_latin1(def($opts{$oid}->{'modifier'}));
				$opt_xml .= qq~<option id="$id" prompt="$prompt" value="$value" modifier="$modifier"/>\n~;
				}
			$extra .= "<options>\n" . entab($opt_xml) . "</options>\n";
			delete $item->{'%options'};
			}
		elsif (defined $item->{'%options'})  {
			warn "this line should never be reached!";
			}

		if (defined $item->{'%fees'}) {
			my %fees = %{$item->{'%fees'}};
			my $fee_xml = '';
			foreach my $feeid (keys %fees) {
				if ($feeid !~ m/^[\w\:]+$/) {
					$errors .= "Feeid $feeid does not look valid\n";
					next;
					}
				my $id = $feeid;
				$id =~ s/\:/-/gs;
				my $value = encode_latin1(def($fees{$feeid}));
				$fee_xml .= qq~<$id>$value</$id>\n~;
				}
			$extra .= "<fees>\n" . entab($fee_xml) . "</fees>\n";
			delete $item->{'%fees'};
			}

		if (defined $item->{'%attribs'}) {
			my %attribs = %{$item->{'%attribs'}};
			my $attribs_xml = '';
			foreach my $attrib (keys %attribs) {
				next if ($attrib eq 'zoovy:pogs');
				my $value = encode_latin1(def($attribs{$attrib}));
				my $id = encode_latin1($attrib);
				$attribs_xml .= qq~<attrib id="$id" value="$value"/>\n~;
				}
			$extra .= "<attribs>\n" . entab($attribs_xml) . "</attribs>\n";
			delete $item->{'%attribs'};
			}
		delete $item->{'stid'};

		if (defined $item->{'*pogs'}) {
			# $extra .= "<pogs>".&POGS::serialize(&POGS::abbreviate($item->{'stid'},$item->{'*pogs'}))."</pogs>";
			# $extra .= "<pogs>".&POGS::serialize($item->{'*pogs'})."</pogs>";
			}

		my $attribs = '';
		foreach my $key (keys %{$item}) {
			next if (substr($key,0,1) eq '*');
			next if ($key eq 'id');		## id is hardcoded below
			my $skip = 0;
			if ($key eq 'full_product') {
				## it's okay if we don't include this.
				$skip++;
				}
			elsif ($key !~ m/^\w+$/) {
				$errors .= "Unable to process root-level stuff item attribute $key (bad key name), not output in XML\n";
				$skip++;
				}
			elsif (ref($item->{$key}) ne '') {
				$errors .= "Unable to process root-level stuff item attribute $key (non-scalar value), not output in XML\n";
				$skip++;
				}
			if (not $skip) {
				my $value = encode_latin1(def($item->{$key}));
				$attribs .= qq~ $key="$value"~;
				}
			}
		$stid = encode_latin1($stid);

		if ($xcompat>=114) {
			## stid munging for assembly items
			##		e.g.  abc/123*xyz:ffff  becomes 123*abc/xyz:ffff
			my $newstid = '';
			if ($stid =~ /^(.*?)\*(.*?)$/) {
				my ($claim,$sku) = ($1,$2);
				if ($claim =~ /^(.*?)\/(.*)$/) {
					$newstid = "$2*$1/$sku";
					}
				}
			if ($newstid ne '') { $stid = $newstid; }
			}

		$xml .= qq~<item id="$stid"$attribs>\n~ . entab($extra) . qq~</item>\n~;
		}

	return $xml, $errors;
}


##
##
##
sub sync_serialize {
	my ($self) = @_;

	return('<!-- sync_serialize is deprecated -->');
}


## Essentially a replacement for $stuff->new() and $stuff->cram, populating from passed XML
sub sync_deserialize {
	my ($xml) = @_;

	my $errors = '';

	my $decoder = \&ZTOOLKIT::decode_latin1;

	my %hash = ();
	my $self = \%hash;

	while ($xml =~ s/<product(.*?)>(.*?)<\/product>//s) {
		my $contents = " $1 ";
		my $extra = " $2 ";
		my %item = ();
		while ($contents =~ s/\s(\w+)\s*\=\s*\"(.*?)\"\s/ /s) {
			my $attrib = $1; my $val = $2;
			$item{lc($attrib)} = $decoder->($val); # note: decoder trashes $1
			}
		my $stid = def($item{'stid'});
		next unless $stid;
		if ($extra =~ s/<fees.*?>(.*)<\/fees>/ /s) {
			$contents = " $1 ";
			my %fees =();
			while ($contents =~ s/<(.*?)>(.*)<\/\1>/ /s) {
				my $feeid = $1; $feeid = $decoder->($feeid);
				my $value = $2; $value = $decoder->($value);
				$feeid =~ s/\-/:/g;
				$fees{$feeid} = $value;
				}
			if (scalar keys %fees) {
				$item{'%fees'} = \%fees;
				}
			}

		if ($extra =~ s/<attribs.*?>(.*)<\/attribs>//s) {
			$contents = " $1 ";
			my %attr =();
			while ($contents =~ s/<(.*?)>(.*)<\/\1>/ /s) {
				my $attrib = $decoder->($1);
				my $value = $decoder->($2);
				$attrib =~ s/\-/:/g;
				$attr{$attrib} = $value;
				}
			if (scalar keys %attr) {
				$item{'%attribs'} = \%attr;
				}
			}

		if ($extra =~ s/<options.*?>(.*)<\/options>//s) {
			my $contents = $1;
			my %opts = (); 
			while ($contents =~ s/<option(.*?)>(.*?)<\/option>/ /s) {
				my $opt_attribs = " $1 ";
				my %opt = ( 'value' => $decoder->($2) );
				while ($opt_attribs =~ s/\s(\w+)\s*\=\s*\"(.*?)\"\s/ /s) {
					my $attrib = $1; 
					my $val = $2;
					$opt{lc($attrib)} = $decoder->($val);		# note: decoder trashes $1
					}
				my $id = def($opt{'id'});
				next unless $id;
				delete $opt{'id'};
				$opts{$id} = \%opt;
				}
			$item{'*options'} = \%opts;
			}

		## cheap hacks
		if (not defined $item{'base_price'}) { $item{'base_price'} = $item{'price'}; }
		if (not defined $item{'sku'}) { 
			$item{'sku'} = $item{'stid'}; 
			$item{'sku'} =~ s/\/.*$//; 
			}
		if (not defined $item{'product'}) {
			$item{'product'} = $item{'sku'};
			if ($item{'product'} =~ /^(.*?)[:\/]+/) { $item{'product'} = $1; }
			}

		$self->{$stid} = \%item;
		}
	bless $self, 'STUFF';
	return $self, $errors;
}

## converts a float to an int safely
## ex: perl -e 'print int(64.35*100);' == 6434  (notice the penny dropped)
## ex: perl -e 'print int(sprintf("%f",64.35*100));' == 6435
sub f2int { return(int(sprintf("%0f",$_[0]))); }



##
## this creates sum's for various items in the cart. values are described below (in about 10 lines)
##
sub sum {
	my ($self, %options) = @_;
	
	my $tax_rate = $options{'tax_rate'};
	if ((not defined $tax_rate) || ($tax_rate eq '') || ($tax_rate !~ m/[0-9]*\.?[0-9]*/)) {
		$tax_rate = 0;
		}
	
	my $skip_discounts = $options{'skip_discounts'};
	if (not defined $skip_discounts) {
		$skip_discounts = 0;
		}

	my %result = ();

	###
	## NOTE: the .int version avoids the floating point precision issues
	##			so (items.subtotal == 17.10)  means (items.subtotal.int == 1710)
	##
	$result{'items.subtotal'} = 0; ## The total dollar value of the stuff before adding tax/shipping/etc
	$result{'items.subtotal.int'} = 0; ## The total dollar value of the stuff before adding tax/shipping/etc (as integer)
	$result{'items.count'}    = 0; ## The number of items (not including promotion line items)
	$result{'tax.subtotal'}  = 0; ## The total dollar value of the taxable stuff
	$result{'tax.subtotal.int'}  = 0; ## The total dollar value of the taxable stuff (as integer)
	$result{'tax.due'}  = 0; ## The total dollar amount of taxes owed.
	$result{'tax.due.int'}  = 0; ## The total dollar amount of taxes owed (as integer)
	$result{'weight'}   = 0; ## The total weight of the stuff

	## Loop over all of the items and add up the totals
	$result{'pkg_weight_194'} = 0;
	$result{'pkg_weight_166'} = 0;
	foreach my $sku ($self->stids()) {
		next if ($skip_discounts && (substr($sku, 0, 1) eq '%'));
		my $item = $self->{$sku};
		if (def($item->{'price'})    eq '') { $item->{'price'}    = 0; }
		if (def($item->{'qty'})      eq '') { $item->{'qty'}      = 0; }
		if (def($item->{'weight'})   eq '') { $item->{'weight'}   = 0; }
		$item->{'taxable'} = taxable($item->{'taxable'});

		$item->{'weight'} = &ZSHIP::smart_weight($item->{'weight'});
		$item->{'cubic_inches'} = 0;
		my $a = $item->{'%attribs'};
		if (not defined $a->{'zoovy:pkg_depth'}) { $a->{'zoovy:pkg_depth'}=0; }
		if (not defined $a->{'zoovy:pkg_width'}) { $a->{'zoovy:pkg_width'}=0; }
		if (not defined $a->{'zoovy:pkg_height'}) { $a->{'zoovy:pkg_height'}=0; }

		if ( (int($a->{'zoovy:pkg_depth'})>0) &&
			(int($a->{'zoovy:pkg_width'})>0) && (int($a->{'zoovy:pkg_height'})>0) ) {

			my $pkg_exclusive = int((defined $a->{'zoovy:pkg_exclusive'})?defined $a->{'zoovy:pkg_exclusive'}:0);
			if ($pkg_exclusive==0) { $pkg_exclusive = 0; }	## no dimensional rounding
			elsif ($pkg_exclusive==1) { $pkg_exclusive = 0.9999; }

			$item->{'cubic_inches'} = int($a->{'zoovy:pkg_depth'}) * int($a->{'zoovy:pkg_width'}) * int($a->{'zoovy:pkg_height'});

			my $w = int(($item->{'cubic_inches'} / 194)+$pkg_exclusive)*16;
			if ($w>$item->{'weight'}) { $result{'pkg_weight_194'} += ($w*$item->{'qty'}); } else { $result{'pkg_weight_194'} += ($item->{'weight'} * $item->{'qty'}); }

			$w = int(($item->{'cubic_inches'} / 166)+$pkg_exclusive)*16;
			if ($w>$item->{'weight'}) { $result{'pkg_weight_166'} += ($w*$item->{'qty'}); } else { $result{'pkg_weight_166'} += ($item->{'weight'} * $item->{'qty'}); }
			}
		else {
			$result{'pkg_weight_194'} += ($item->{'weight'} * $item->{'qty'});
			$result{'pkg_weight_166'} += ($item->{'weight'} * $item->{'qty'});
			}

		$item->{'extended'} = ($item->{'price'} * $item->{'qty'});
		$result{'items.subtotal'} += sprintf("%.2f", $item->{'extended'});
		$result{'items.subtotal.int'} += &f2int(($item->{'price'}*100)*$item->{'qty'});

		if ($item->{'taxable'}) { 
			$result{'tax.subtotal'} += sprintf("%.2f", ($item->{'price'} * $item->{'qty'})); 
			$result{'tax.subtotal.int'} += &f2int(($item->{'price'}*100)*$item->{'qty'}); 
			}
		$result{'weight'} += ($item->{'qty'} * $item->{'weight'});
		## Handle hidden items and discounts
		if ((substr($sku, 0, 1) ne "!") && (substr($sku, 0, 1) ne '%')) { 
			$result{'items.count'} += $item->{'qty'}; 
			}
		}

	$result{'tax.due.int'} = sprintf("%.2f", ($tax_rate / 100) * $result{'tax.subtotal.int'});
	$result{'tax.due'} = sprintf("%.2f", $result{'tax.due.int'}/100);
	if (int($result{'weight'}) < $result{'weight'}) { $result{'weight'} = int($result{'weight'})+1; }	# don't keep around decimals on the final weight

	return (\%result);
	}




## This is roughly the equivalent of the old ZOOVY::calc_producthash_totals
## NOTE: This actually modifies the contents of the STUFF hash...  it 'ouncifies' weights,
## and it puts in default info missing in items to spare having to do it the next
## time around
sub totals {
	my ($self, $tax_rate, $skip_discounts ) = @_;
	
	# return ($subtotal, $weight, $tax, $taxable, $items, $pkg_weight_194, $pkg_weight_166);
	my ($result) = $self->sum('tax_rate'=>$tax_rate,'skip_discounts'=>$skip_discounts);
	return (
		$result->{'items.subtotal'}, 
		$result->{'weight'},
		$result->{'tax.due'},
		$result->{'tax.subtotal'},
		$result->{'items.count'},
		$result->{'pkg_weight_194'},
		$result->{'pkg_weight_166'}
		);
	
	}

## Tries to parse taxable into a boolean 1/0
sub taxable {
	my ($check) = @_;
	$check = uc(def($check));
	$check =~ s/\W//g;
	if (($check eq '0') || (substr($check, 0, 1) eq 'N')) {
		return 0;
		}
	return 1;
	}


1;
