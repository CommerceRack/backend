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
## 
##
#sub prod_is {
#	my ($self) = @_;
#	my $stuff = $CART->stuff();
#	foreach my $stid ($stuff->stids()) {
#		my $item = $stuff->item($stids);
#		# is:preorder
#		if ($item->{'%attribs'}->{'zoovy:prod_is'} & (1<<8)) {
#			}
#		elsif ($item->{'%attribs'}->{'zoovy:prod_is'} & (1<<8)) {
#			}
#		}
#	}







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
## These items get updated automatically when you cram them into stuff
##	force_qty => 1/0, default 0
##	stid => This is what the item is keyed by, and is unique
##	weight => This is the modified weight after options are applied
##	price => This is the modified price after options are applied
##	description => This is the product name concatenated with descriptive information based on the selected options
##
##	OPTION PROPERTIES:
##		%options = a hashref of POGID=>POGVAL or POGID=>~text (for textboxes)
##		*options = a hashref, prechewed, by process_pog		
##
##	ASSEMBLY PROPERITIES:
##		assembly_master => if the item is part of an assembly, this references the master stid which controls it.
##		assembly_qty => if we have qty 3 masters, we have 3*assembly_qty of this item.
##
##
## %params
##		make_pogs_optional		turns the "optional" flag on each option on, so that it is less likely to fail
##
#sub legacy_cram {
#	my ($self, $item, %params) = @_;
#
#	my $USERNAME = $self->username();
#
#	my $LM = undef;
#	if ((defined $params{'*LM'}) && (ref($params{'*LM'}) eq 'LISTING::MSGS')) {
#		$LM = $params{'*LM'};
#		}
#
#	my $DEBUG = 0;
#	if (ref($item) ne 'HASH') {
#		warn ("Cram for $USERNAME failed: You must provide a hashref to be crammed");
#		return 1, "You must provide a hashref to be crammed";
#		}
#
#	if (scalar(keys %{$item})==0) {
#		warn ("Cram received a blank item hash");
#		return 1, "You must provide a hashref with keys to be crammed";
#		}
#
#
#	## valid parameters:
#	## auto_detct_options => 1|0 	
#	##	pogs_optional	
#	##	asm_processed => 500|0	(set in ORDER::AMAZON)
#	## *LM 	reference to a LISTING::MSGS item
#	## 
#
#	my %ASSEMBLE_THIS = ();
#	## a hash of items keyed by SKU, value is quantity which tracks 
#	## which items need to be added based on this item.
#
#	## so here's the deal, we need to figure out the STID really early
#	##	so we can figure out which SKU attributes to load. 
#
#	if (defined $item->{'auto_detect_options'}) {
#		if (defined $LM) { $LM->pooshmsg("WARN|+cram was called with item->auto_detect_options, which should be passed as a parameter"); }
#		$params{'auto_detect_options'} = $item->{'auto_detect_options'};
#		delete $item->{'auto_detect_options'};
#		}
#
#
#	if ($item->{'claim'} == 0) {
#		delete $item->{'claim'};
#		}
#	elsif (index($item->{'product'},'*')>=0) {
#		## this product has a claim in it.
#		if (defined $LM) { $LM->pooshmsg("WARN|+do not pass in the claim code in item->product"); }
#		warn("do not pass in the claim code in the product field");
#		}
#
#	$item->{'product'} = uc($item->{'product'});
#	my $stid = undef;
#	if (not defined $stid) { $stid = (defined $item->{'sku'})?uc($item->{'sku'}):undef; }
#	if (not defined $stid) { $stid = (defined $item->{'product'})?uc($item->{'product'}):undef; }
#
#	if (($item->{'product'} eq '') && ($item->{'sku'} eq '') && (defined $item->{'stid'}) && ($item->{'stid'} ne '')) {
#		if (defined $LM) { $LM->pooshmsg("WARN|+entered legacy mode, found stid"); }
#		## LEGACY MODE - WHERE WE USED TO PASS STID. (fixed 9/23/09)
#		$stid = (defined $item->{'stid'})?$item->{'stid'}:undef;
#		}
#   elsif ( ($params{'is_assembly_cram'}) && ($item->{'stid'} ne '')) {
#		## if we're getting passed from is_assembly_cram we'll trust the stid 
#		## see ticket# 196142 for a nasty example of what happens when trust breaks down.
#		if (defined $LM) { $LM->pooshmsg("WARN|+entered assemble cram mode, trusting stid implicitly."); }
#      $stid = $item->{'stid'};
#      }
#
#	if ((defined $item->{'claim'}) && (int($item->{'claim'})>0) && (index($stid,'*')<0)) {
#		## now we do this here, and we reset it again in validate_stid .. but remember validate_stid 
#		## might not be run if we don't have any options .. and this is pretty harmless.
#		if (defined $LM) { $LM->pooshmsg("WARN|+entered assemble cram mode, trusting stid implicitly."); }
#		$stid = int($item->{'claim'}).'*'.$stid;
#		}
#	$item->{'stid'} = $stid;
#
#	
##	print STDERR Dumper($item);
##	die();
#
#
##	## okay, so now we need to look if the stid already has options on it.
##	if ($stid eq '')  {
##		warn ("Cram for $USERNAME failed: No STID passed for addition to contents");
##		return 1, "No STID passed for addition to contents";
##		}
##	elsif ($item->{'special'}) {}	# hmm.. we can probably ignore the next step on this.
##	elsif (index($stid,':')>0) {}	# yep, the stid already has options set, so we can skip the next section.
#
##	use Data::Dumper;
##	open F, ">>/tmp/asdf";
##	print F Dumper($item,[caller(0)]);
##	close F;
#
#	#if ($stid =~ m/^(\!|\%)/) { 
#	#	## old style promotions and discounts don't get option processing done.		
#	#	}
#	if (defined $item->{'*options'}) {
#		## this has completed process_pog so no need to go any further.
#		delete $item->{'%options'};
#		delete $item->{'optionstr'};
#		die("Don't call cram with *options set");
#		}
#	elsif ((defined $params{'validate_options'}) && (int($params{'validate_options'})==0)) {
#		## this is probably used by assemblies, or anything which needs to create a "fast" stuff object
#		##	with no option validation
#		if (defined $LM) { $LM->pooshmsg("WARN|+validation options disabled!"); }
#		}
#	elsif ((defined $item->{'%options'}) && (ref($item->{'%options'}) eq 'HASH')) {
#		## okay, so options were passed, but we don't have them on the stid yet (probably an add to cart)
#		##		crap, okay, so to do this right we need to figure out what the stid is, since we'll need the stid
#		##		to get the sku, to load the inventory meta data, into the product, so we can run the option modifiers
#		##		yeah, i know it's a circular reference, and it sucks, but what the heck can i do about it? 
#		if (defined $LM) { $LM->pooshmsg("INFO|+received %options"); }
#
#		# print STDERR Dumper($item);
#		delete $params{'caller'};
#		(my $error, $item) = $self->process_pog($item,caller=>'upper_%options',stidonly=>1,%params);
#		$stid = $item->{'stid'};
#		
#		# print STDERR Dumper($item); die();
#		
#		if (def($error) ne '') {
#			warn("Upper Cram for $USERNAME failed: $error");
#			return 1, $error;
#			}
#		}
#	elsif (
#		((defined $item->{'optionstr'}) && ($item->{'optionstr'} ne '')) ||
#		((defined $item->{'sku'}) && ($item->{'sku'} =~ /[:\/]/) && ($params{'auto_detect_options'})) 
#		)
#		{
#		if (defined $LM) { $LM->pooshmsg("INFO|+will populate %options from optionstr or sku"); }
#
#		## note: optionstr is used by amazon promos
#		# print STDERR "OPTIONSTR: $item->{'optionstr'}\n";
#		my ($pid,$claim,$invopts,$noinvopts,$virtual) = ();
#		my $optionstr = '';
#		if ($item->{'optionstr'} =~ /[:\/]+/) {
#			## NOTE: if we pass in a SKU as 'optionstr' -- IT HAD BETTER HAVE OPTIONS or this will crash. .. no way to detect
#			## 	option boundaries here.. perhaps detecting :'s or / as substr($str,0,1) or something.. but no
#			##		time to test. used in ebay/monitor.pl
#			if (defined $LM) { $LM->pooshmsg("WARN|+using optionstr: $item->{'optionstr'}"); }
#	      ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($item->{'optionstr'});
#			delete $item->{'optionstr'};
#			$optionstr .= (($invopts)?":$invopts":"") . (($noinvopts)?"/$noinvopts":"");			
#			}
#		if ((defined $item->{'sku'}) && ($params{'auto_detect_options'})) {
#			## this is perhaps a better way to do this, this is an elsif because we might still want to leave optionstr
#			## for example if we have a unique giftcard message or something then 'sku' is PID:ABCD and optionstr 
#			##	might be: /##01 
#			if (defined $LM) { $LM->pooshmsg("WARN|+using auto_detect_options sku: $item->{'sku'}"); }
#	      ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($item->{'sku'});
#			# delete $item->{'auto_detect_options'};
#			$optionstr .= (($invopts)?":$invopts":"") . (($noinvopts)?"/$noinvopts":"");			
#			}
#		if (defined $LM) { $LM->pooshmsg("WARN|+result final optionstr: $optionstr"); }
#
#
#		$item->{'%options'} = {};
#		if ($pid ne '') {	$item->{'product'} = $pid; }
#
#		if ((defined $optionstr) && ($optionstr ne '')) {
#			foreach my $opt (split(/[\:\/]+/,$optionstr)) {
#				next if (length($opt)!=4);		## kkvv option format is all we'll accept!
#				# print STDERR "OPT: $opt\n";
#				$item->{'%options'}->{ substr($opt,0,2) } = substr($opt,2,4);
#				}		
#
#			#if ($item->{'pogs'} eq '') {
#			#	my ($pref) = &ZOOVY::fetchproduct_as_hashref($USERNAME,$pid);
#			#	$item->{'pogs'} = $pref->{'zoovy:pogs'};
#			#	}
#			if (not defined $item->{'*pogs'}) {
#				my ($pref) = &ZOOVY::fetchproduct_as_hashref($USERNAME,$pid);
#				$item->{'*pogs'} = &ZOOVY::fetch_pogs($USERNAME,$pref);
#				}
#
#			if ((scalar(keys %{$item->{'%options'}})==1) && (defined $item->{'%options'}->{'##'})) {
#				## the option '##' represents a text unique identifier, does not require $item->{'pogs'}
#				}
#			#elsif ($item->{'pogs'} eq '') {
#			#	return(1,"could not lookup pogs");
#			#	}
#			}	
#
#		my $x = &ZTOOLKIT::buildparams($item->{'%options'});
#		# warn "SENT PROCESS POG: $item->{'product'} $x\n";
#		delete $params{'caller'};
#		(my $error, $item) = $self->process_pog($item,caller=>'upper_optionstr',stidonly=>0,%params);
#		$stid = $item->{'stid'};
#		if (def($error) ne '') {
#			if (defined $LM) { $LM->pooshmsg("ERROR|+upper_optionstr cram got:$error"); }
#			warn("Upper Cram for $USERNAME failed: $error [$x]");
#			return 1, $error;
#			}
#		else {
#			if (defined $LM) { $LM->pooshmsg("INFO|+FINALSTID:$stid"); }
#			}
#		}
#	else {
#		## hmm.. well it doesn't have options. 
#		if (defined $LM) { $LM->pooshmsg("INFO|+found no options"); }
#		}
#
#
#	if (($item->{'claim'}>0) && (index($stid,'*')==-1)) {
#		## re-add the claim back, if it got nuked during the option handling.
#		$stid = sprintf("%s*%s",$item->{'claim'},$stid);
#		}
#
#	# print STDERR "STID: $stid\n";
#
#	##
#	## at this point STID is set, and should not change.
#	##
#
#
#	## BEWARE: if you trash claim here, then bad things will happen. .. remember the STID DOES NOT HAVE THE CLAIM ON IT.
#	my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($stid);
#	if (defined $claim) { $item->{'claim'} = $claim; } 
#	# print STDERR "Cramming STID: $stid\n";
#
#	my ($P) = PRODUCT->new($self->username(),$pid);
#
#	$stid = uc($stid);	## STIDS are always uppercase
#	$item->{'product'} = $pid;
#	$item->{'sku'} = $pid.(($invopts)?(':'.$invopts):'');
##	print STDERR "SKU: $item->{'sku'}\n";
#	$item->{'stid'} = $stid;
#
#	# print STDERR Dumper($stid,$pid,$claim,$invopts,$noinvopts,$virtual);
#
#	# print STDERR "PID: $pid ($stid)\n";
#
#	if (defined $item->{'claim'}) {
#		## check to see if the same claim is already in the cart
#		foreach my $stidz ($self->stids()) {
#			if ($stidz =~ /^([\d]+)\*/) {
#				if ($1 eq $item->{'claim'}) {
#					## if the same incomplete item already exists, then kill it.
#					delete $self->{$stidz};
#					}
#				}
#			}
#		}
#
#	if (not defined $item->{'sku'}) {
#		## if we didn't get passed a SKU -- create it from the SKU
#		$item->{'sku'} = $item->{'stid'};
#		if (index($item->{'sku'},'/')>0) { $item->{'sku'} = substr($item->{'sku'},0,index($item->{'sku'},'/')); }
#		}
#
#	## NOTE: STUFF::CGI::parse_products will load full product.
#	# warn "SKU: $item->{'sku'} ne $item->{'product'}\n";
#	if (not defined $item->{'full_product'}) {
#		my $claimsku = $item->{'sku'};
#		if ((index($item->{'sku'},'*')<0) && ($item->{'claim'}>0)) {
#			$claimsku = (($item->{'claim'}>0)?($item->{'claim'}.'*'):'').$item->{'sku'};
#			}
#		## this does not work the way we think it does.
#		if ($claimsku =~ /\*/) {
#			&ZOOVY::confess($USERNAME,"LEGACY CRAMMED A CLAIM WITHOUT FULL PRODUCT SET",justkidding=>1);
#			}
#		else {
##			&ZOOVY::confess($USERNAME,"LEGACY CRAMMED A PRODUCT WITHOUT FULL PRODUCT SET",justkidding=>1);
#			}
#		$item->{'full_product'} = &EXTERNAL::get_item($USERNAME, $claimsku, 1);
#		}
#	elsif ($item->{'sku'} ne $item->{'product'}) {
#		## reload the meta properties
#
#		my $mref = {};
#		if (not defined $item->{'full_product'}) {
#			warn "item->full_product not defined in STUFF\n";
#			}
#		elsif (not defined $item->{'full_product'}->{'%SKU'}) {
#			warn "item->full_product->%SKU not defined in STUFF\n";
#			}
#		elsif (not defined $item->{'full_product'}->{'%SKU'}->{$item->{'sku'}}) {
#			warn "item->full_product->%SKU->sku not defined in STUFF\n";
#			}
#		else {
#			$mref = $item->{'full_product'}->{'%SKU'}->{$item->{'sku'}};
#			}
#
#		# my $mref = {};
#		# TODO: FIX THIS!! my ($mref) = &ZOOVY::deserialize_skuref($item->{'full_product'},$item->{'sku'});
#		# my ($mref) = &INVENTORY::fetch_metaref($USERNAME,$item->{'sku'});
#		foreach my $k (keys %{$mref}) {
#			next if (($mref->{$k} eq '') && ($item->{'full_product'}->{$k} ne ''));
#			## never ovewrite a non-blank value, with a blank value in meta.
#			$item->{'full_product'}->{$k} = $mref->{$k};
#			}
#
#		# warn "fetch_metaref says $item->{'sku'} $item->{'full_product'}->{'zoovy:base_cost'}\n";
#		}
#	else {
#		}
#
#
#	# use Data::Dumper; print STDERR Dumper($item);
#
#	######################################################################################3
#	## SANITY: at this point $item->{'full_product'} contains a copy of the product!
#	##
#
#	# print Dumper($item);
#
#	my $gref = &ZWEBSITE::fetch_globalref($USERNAME);
#
#	## Promotion API stuff!
#	#foreach my $attrib (split /\,/,  def($webdb->{'dev_promotionapi_attribs'})) {
#	#	next unless (def($item->{'full_product'}->{$attrib}) ne '');
#	#	$item->{'%attribs'}->{$attrib} = $item->{'full_product'}->{$attrib};
#	#	}	
#
#	##
#	## standard attribs we always copy (eventually these might be different based on the type of account purchased)
#	##
#	foreach my $attrib ('zoovy:catalog','zoovy:prod_upc','zoovy:prod_isbn','zoovy:prod_mfg','zoovy:prod_supplier',
#		'gc:blocked','paypalec:blocked',
#		'zoovy:prod_asm', 'zoovy:prod_is',
#		'zoovy:ship_latency',
#		'zoovy:prod_supplierid','zoovy:prod_image1','zoovy:ship_handling','zoovy:ship_markup','zoovy:ship_insurance',
#		'zoovy:ship_cost1','zoovy:pkg_depth','zoovy:pkg_height','zoovy:pkg_width','zoovy:pkg_exclusive', 'zoovy:pkg_multibox_ignore',
#		'zoovy:prod_mfgid','zoovy:ship_mfgcountry','zoovy:ship_harmoncode','zoovy:ship_nmfccode','zoovy:ship_sortclass',
#		## needed for rules
#		'zoovy:ship_sortclass', 'zoovy:prod_promoclass',  'zoovy:prod_class', 'zoovy:profile', 
#		'is:shipfree','is:user1','is:sale',
#		) {
#
#		next unless (def($item->{'full_product'}->{$attrib}) ne '');
#		$item->{'%attribs'}->{$attrib} = $item->{'full_product'}->{$attrib};
#		}
#
#	if (defined $P) {
#		if (not $P->has_variations('inv')) {
#			$item->{'%attribs'}->{'zoovy:prod_asm'} = $P->fetch('pid:assembly');
#			}
#		else {
#			$P->skufetch($item->{'sku'}, $P->fetch('sku:assembly'));
#			}
#		}
#
#	if (defined $item->{'claim'}) {
#		$item->{'mkt'} = $item->{'full_product'}->{'zoovy:market'};
#		$item->{'mktid'} = $item->{'full_product'}->{'zoovy:marketid'};
#		$item->{'mkturl'} = $item->{'full_product'}->{'zoovy:marketurl'};
#		$item->{'mktuser'} = $item->{'full_product'}->{'zoovy:marketuser'};
#		$item->{'channel'} = $item->{'full_product'}->{'zoovy:channel'};
#		
##		my $full = &EXTERNAL::fetchexternal_full($USERNAME,$item->{'claim'});
##		my $STAGE = $full->{'STAGE'};
##		if ( ($STAGE ne 'A') && ($STAGE ne 'I') && ($STAGE ne 'V') && ($STAGE ne 'W')) { 
##			return(2,"Claim appears to have already been purchased - wrong stage ($STAGE)");
##			}
#		}
#
#	$item->{'qty'}         = def($item->{'full_product'}->{'zoovy:quantity'}, $item->{'qty'}, 1);
#
#	## NOTE: full_product appears to be required for stuff like product thumbnails (probably shouldn't be, but for now it is)
#	# delete $item->{'full_product'};
#
#	## BEGIN WHOLESALE PRICING
#	if (defined $params{'schedule'}) {
#		$item->{'schedule'} = $params{'schedule'};
#		}
#
#	if (defined $item->{'claim'}) {}
#	elsif ((defined $item->{'schedule'}) && ($item->{'schedule'} ne '') && ($item->{'assembly_master'} eq '')) {
#		require WHOLESALE;
#		&WHOLESALE::tweak_product($USERNAME,$item->{'schedule'},$item->{'full_product'});
#		$item->{'schedule'} = $item->{'schedule'};
#		$item->{'base_price'} = $item->{'full_product'}->{'zoovy:base_price'};
#		$item->{'qty_price'} = $item->{'full_product'}->{'zoovy:qty_price'};
#		delete $item->{'price'};
#		}
#	## END WHOLESALE PRICING
#
#	if (not defined $item->{'base_price'}) { 
#		$item->{'base_price'} = $item->{'full_product'}->{'zoovy:base_price'}; 
#		}
#		
##	if ((not defined $item->{'base_price'}) || ($item->{'base_price'} eq '')) {
##		return(1,"Product $item->{'sku'} does not have a base_price set.");
##		}
##	$item->{'base_price'}  = def($item->{'base_price'}, 0);
#	$item->{'price'}       = def($item->{'price'}, $item->{'base_price'});
#
#	if (not defined $item->{'base_weight'}) { $item->{'base_weight'} = $item->{'full_product'}->{'zoovy:base_weight'}; }
#	$item->{'base_weight'} = def($item->{'base_weight'}, 0);
#	## TODO: need to check for '1 lb' and other stupid strings here
#	$item->{'weight'}      = def($item->{'weight'},      $item->{'base_weight'});
#	## TODO: need to check for '1 lb' and other stupid strings here
#
#	if (not defined $item->{'taxable'}) { $item->{'taxable'} = $item->{'full_product'}->{'zoovy:taxable'}; }
#	$item->{'taxable'}     = taxable($item->{'taxable'});
#
#	if (not defined $item->{'prod_name'}) { $item->{'prod_name'} = $item->{'full_product'}->{'zoovy:prod_name'}; }
#	$item->{'prod_name'}   = def($item->{'prod_name'});
#
#	#if (not defined $item->{'pogs'}) { $item->{'pogs'} = $item->{'%attribs'}->{'zoovy:pogs'}; }
#	#$item->{'pogs'}        = (defined $item->{'pogs'})?$item->{'pogs'}:undef;
#	
#	$item->{'description'} = def($item->{'description'}, $item->{'prod_name'});
#	$item->{'cost'} 		  = $item->{'full_product'}->{'zoovy:base_cost'};
#
#	if (defined $item->{'full_product'}->{'zoovy:virtual_ship'}) {
#		$item->{'virtual_ship'} = $item->{'full_product'}->{'zoovy:virtual_ship'};
#		$item->{'%attribs'}->{'zoovy:virtual_ship'} = $item->{'full_product'}->{'zoovy:virtual_ship'};
#		}
#
#	if (defined $item->{'full_product'}->{'zoovy:virtual'}) {
#		$item->{'virtual'} = $item->{'full_product'}->{'zoovy:virtual'};
#		$item->{'%attribs'}->{'zoovy:virtual'} = $item->{'full_product'}->{'zoovy:virtual'};
#		}
#
#	if ($item->{'claim'}>0) {
#		$item->{'force_qty'}++;
#		}
#
#	if (not defined $item->{'force_qty'}) {
#		$item->{'force_qty'} = 0;
#		if (defined($item->{'full_product'}->{'zoovy:quantity'})) {
#			$item->{'force_qty'} = 1;
#			}
#		}
#
#	if ($item->{'qty'} < 0) {
#		warn("Cram for $USERNAME failed: Negative quantities not allowed in cart");
#		return 1, "Negative quantities not allowed in cart";
#		}
#	elsif ($item->{'qty'} == 0) {
#		#warn("Cram for $USERNAME failed: Zero quantities not allowed in cart");
#		#return 1, "Zero quantities not allowed in cart";
#		return 0, '';
#		}
#
#
#	if ((def($item->{'qty_price'}) ne '') && ($stid !~ m/\*/)) {
#		&qty_price($item);
#		}
#
#	my $message = '';
#
#	## note: force_qty is only run at the very beginning
#	if (not $item->{'force_qty'}) {
#		# Compatibility for old qty users nytape, candlemakers, etc.
#		if (defined $item->{'full_product'}->{"$USERNAME:minqty"}) {
#			$item->{'minqty'} = int($item->{'full_product'}->{"$USERNAME:minqty"});
#			}
#
#		if (defined $item->{'full_product'}->{"$USERNAME:incqty"}) {
#			$item->{'incqty'} = int($item->{'full_product'}->{"$USERNAME:incqty"});
#			}
#
#		if (defined $item->{'full_product'}->{"$USERNAME:maxqty"}) {
#			$item->{'maxqty'} = int($item->{'full_product'}->{"$USERNAME:maxqty"});
#			}
#
#		if (not defined $item->{'minqty'}) {}
#		elsif ($item->{'minqty'} eq '') {}
#		elsif ($item->{'qty'} < $item->{'minqty'}) {
#			$item->{'qty'} = int($item->{'minqty'});
#			# $message = "Minimum quantity for $stid is $item->{'qty_min'}";
#			$message = "Minimum quantity for $stid is $item->{'minqty'}";
#			## NOTE: we need to keep the qty_max values so we can enforce them if the quantities change!
#			## delete $item->{'qty_min'};
#			}
#
#	
#		if (not defined $item->{'incqty'}) {}
#		elsif ($item->{'incqty'} eq '') {}
#		elsif (int($item->{'incqty'})<=0) {}
#		elsif (($item->{'qty'} % $item->{'incqty'})>0) {
#			# qty30 += 30 % 25 
#			# 1 += 1 % 25
#			$item->{'qty'} = int($item->{'qty'});
#			$item->{'incqty'} = int($item->{'incqty'});
#			if ($item->{'qty'}<$item->{'incqty'}) {
#				$item->{'qty'} = $item->{'incqty'};
#				}
#			else {
#				$item->{'qty'} += $item->{'incqty'} - ($item->{'qty'} % $item->{'incqty'});
#				}
#			$message = "$stid must be purchased in quantities of $item->{'incqty'}, setting to $item->{'qty'}";
#			## NOTE: we need to keep the qty_max values so we can enforce them if the quantities change!
#			## delete $item->{'qty_increment'};
#			}	
#
#		if ((def($item->{'maxqty'}) ne '') && ($item->{'qty'} > $item->{'maxqty'})) {
#			$item->{'qty'} = int($item->{'maxqty'});
#			$message = "Maximum quantity for $stid is $item->{'qty_max'}";
#			## NOTE: we need to keep the qty_max values so we can enforce them if the quantities change!
#			## delete $item->{'qty_max'};
#			}
#		}
#
#	$item->{'base_weight'} = ZSHIP::smart_weight($item->{'base_weight'});
#	if (defined $item->{'base_weight'}) { $item->{'weight'} = $item->{'base_weight'}; }
#	## NOTE: weight will get reset later if we end up running process_pogs!
#
#
##	## If we get something passed in with a dash in it, we have to assume its a fully baked SKU
#	if ($item->{'pogs_processed'}) {
#		## not sure why we might still need to call unique_stid at this point, but we'll leave this code alone.
#		## i think this determines if a stid needs to be unique or something (which process_pogs should have already done)
#		}
#	elsif ($item->{'*pogs'}) {
#		##
#		## NOTE: THIS *MUST* RUN to PROPERLY SET PRICE MODIFIERS!!!!
#		##
#
#		# print "CRAMMING: $USERNAME $item->{'product'}\n";
#		delete $params{'schedule'};
#		delete $params{'assemblyref'};
#		delete $params{'caller'};
#		(my $error, $item) = $self->process_pog($item, 
#			schedule=>"$item->{'schedule'}", 
#			assemblyref=>\%ASSEMBLE_THIS, 
#			stidonly=>0,
#			caller=>'lower',
#			%params
#			);
#
#		# print "RETURNING\n";
#		if (def($error) ne '') {
#			warn("Lower Cram for ($item->{'product'}) $USERNAME failed: $error");
#			# print STDERR Dumper($item);
#			return 1, $error;
#			}
#		}
#
#	if ((defined $params{'asm_processed'}) && (int($params{'asm_processed'})>0)) {
#		## ORDER::AMAZON passes asm_processed=>500 -- it's code for "hey, you don't need to do assembly processing"
#		warn "overrode asm_processed to $params{'asm_processed'} via params";
#		$item->{'asm_processed'} = $params{'asm_processed'};
#		}
#
#	if ($item->{'assembly_master'} ne '') {
#		## wow.. this is already part of an assembly (no sub assemblies)
#		}	
#	elsif (defined $item->{'asm_processed'}) {
#		## skip this, we've already done it!
#		}	
#	elsif ((defined $item->{'%attribs'}->{'zoovy:prod_asm'}) && ($item->{'%attribs'}->{'zoovy:prod_asm'} ne '')) {			
#		## item kits
#		##		the items of a kit have no individual price, and no individual weight.
#		##		if any items in the kit cannot be added, then the entire sku cannot be purchased.
#		my $asm = $item->{'%attribs'}->{'zoovy:prod_asm'};
#		$asm =~ s/[ ]+//gs;	# remove spaces
#		foreach my $skuqty (split(/,/,$asm)) {
#			my ($SKU,$QTY) = split(/\*/,$skuqty);
#			if (not defined $QTY) { $QTY = 1; }
#			if (not defined $ASSEMBLE_THIS{$SKU}) { $ASSEMBLE_THIS{$SKU}=0; }
#			$ASSEMBLE_THIS{$SKU} += int($QTY);
#			}
#		}
#
#
#	## SANITY: at this point %ASSEMBLE_THIS is built out.. it has SKU=>qty  (qty does not reflect qty being purchased)
#
#
#
#	if ($item->{'assembly_master'} ne '') {
#		## wow.. this is already part of an assembly (no sub assemblies)
#		# print STDERR Dumper($item->{'pogs'});
#		if (not $item->{'pogs_processed'}) {
#			delete $params{'caller'};
#			$self->process_pog($item,caller=>'assembly_master', stidonly=>0, %params);
#			# warn "CALLING VALIDATE_STID FROM ASSEMBLY MASTER ne ''";
#			($stid) = $self->validate_stid($item,allow_no_options=>1);
#			}
#		}	
#	elsif (defined $item->{'asm_processed'}) {
#		## already processed this.
#		# print STDERR 'SKIPPED: '.Dumper($item->{'stid'});
#		}
#	elsif (scalar(keys %ASSEMBLE_THIS)>0) {
#		my $mystid = $item->{'stid'};	
#		## force_qty claims always allow assemblies to be purchased!
#		if ($item->{'force_qty'}>0) {
#			}
#		elsif ((defined $item->{'claim'}) && ($item->{'claim'}>0)) {
#			}
#		else {
#			my $tmpstuff = STUFF->new($USERNAME);
#			my $qty = $item->{'qty'};
#			foreach my $sku (keys %ASSEMBLE_THIS) {
#				$tmpstuff->legacy_cram( 
#						{ 
#						pogs_processed=>2,
#						asm_processed=>2, assembly_master=>$mystid, stid=>$sku, 
#						optionstr=>$sku,
#						qty=>$ASSEMBLE_THIS{$sku}*$item->{'qty'} 
#						},
#					validate_options=>0,
#					);
#				}
#
#			my ($result) = &INVENTORY::verify_stuff($USERNAME,$tmpstuff,$gref);
#			if (defined $result) {
#				return(1, "Some of the items in this kit are not available for purchase: ".join(',',keys %{$result}));
#				}	
#			}
#
#		foreach my $asmstid (keys %ASSEMBLE_THIS) {
#			my %newitem = ();
#
#			next if ($mystid eq $asmstid);	# if we're trying to cram the same stid, stop.
#
#			my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($asmstid);
#			next if ($item->{'product'} eq $pid); # if we're trying to cram the same product, stop.
#
#			if (($invopts ne '') && (substr($invopts,0,1) ne ':')) { $invopts = ":$invopts"; }
#			if (($noinvopts ne '') && (substr($noinvopts,0,1) ne ':')) { $noinvopts = "/$noinvopts"; }
#
#			my ($sku) = $pid.(($invopts ne '')?"$invopts":'');
#			next if ($item->{'sku'} eq $sku);  # if we're trying to cram the same sku, stop.
#
#			$newitem{'optionstr'} = "$invopts$noinvopts";
#			# print STDERR 'BLAH: '.Dumper(\%newitem); die();
#
#			## NOTE: do not re-enable this line, we *MUST* use the @ sign now.
#			# $item{'stid'} = (($claim)?$claim.'*':'').$asmstid.'/'.$stid;
#			$newitem{'stid'} = $stid.'@'.$asmstid;
#
#			# print STDERR "STID: $stid $newitem{'stid'}\n";
#			$newitem{'product'} = $pid;
#			$newitem{'sku'} = $sku;
#			$newitem{'qty'} = int($ASSEMBLE_THIS{$asmstid});
#			$newitem{'full_product'} = &ZOOVY::fetchsku_as_hashref($USERNAME,$asmstid);
#			# $newitem{'pogs'} = $newitem{'full_product'}->{'zoovy:pogs'};
#
#			delete $newitem{'full_product'}->{'zoovy:html'};
#			## dimensions for assembly sub components do not apply, the dimensional weight from the master item is used.
#			$newitem{'full_product'}->{'zoovy:pkg_depth'} = 0;
#			$newitem{'full_product'}->{'zoovy:pkg_height'} = 0;
#			$newitem{'full_product'}->{'zoovy:pkg_width'} = 0;
#
#			$newitem{'full_product'}->{'zoovy:quantity'} = int($newitem{'qty'});
#			$newitem{'force_qty'} = 1;
#
#			## note: some assembly items might have modifiers. e.g. p=3.50 which set the price
#			##		and that is bad (except on option based assemblies which aren't done here)
#			##		so we force the price to zero.
#			$newitem{'force_price'} = 1;
#			$newitem{'price'} = 0;
#
#			$newitem{'base_price'} = 0;
#			$newitem{'base_weight'} = 0;
#			$newitem{'taxable'} = 0;
#			$newitem{'asm_processed'} = 1;
#			$newitem{'assembly_master'} = $stid;
#			$newitem{'assembly_qty'} = $newitem{'qty'};		# if we have 1 item, we have 1*assembly_qty of these!
#			$newitem{'qty_price'} = '';		## implicitly turn off quantity pricing! (we don't have a cost!)
#
#			# print STDERR 'ASSEMBLY: '.Dumper({asmstid=>$asmstid,pid=>$pid,sku=>$sku,optionstr=>$newitem{'optionstr'}});
#
#			# print STDERR Dumper(\%newitem); die();
#
#			# print STDERR "CALLING CRAM: $newitem{'product'} ".join('|',$self->stids())."\n";
#			$self->legacy_cram(\%newitem,schedule=>$item->{'schedule'},is_assembly_cram=>1);	
#			}
#
#		
#		$item->{'asm_processed'} = $^T;
#		}
#	else {
##		die();
#		}
#
#
#
#	$item->{'stid'} = $stid;
#	if ((defined $self->{$stid}) && (not $item->{'force_qty'})) {
#		$message = sprintf("Item %s already in cart, adding %d", $stid, $item->{'qty'});
#		$item->{'qty'} += $self->{$stid}->{'qty'};
#		}
#
#	$item->{'extended'} = sprintf('%.2f', ($item->{'qty'} * $item->{'price'}));
#	$item->{'added_gmt'} = time();
#
#	## NOTE: promotion rules work off full_product
#	#if (defined $item->{'full_product'}) {
#	#	delete $item->{'full_product'};
#	#	}
#
#	$self->{$stid} = $item;
#	$DEBUG && warn($self,'*stuff_cram_end');
#
#	## this forces us to reupdate our assembly quantities as well.
#	if (defined $params{'is_assembly_cram'}) {
#		## note: when we're just cramming assembly items, we don't need to call update_quantities 
#		## each time, we can just call it once. .. it causes $stuff->{$assembly_master}->{qty} to be set
#		## which throws an erroneous error message
#		}
#	else {
#		$self->update_quantities({});
#		}
#
#	return 0, $message;
#}






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



##########################################################################
##
## Internal function to process a pog for an item (used by cart)
## Returns an error (undef if none) a new STID and a re-processed STUFF-type item
## basically this takes: 
##		PRODUCT: ABC + cgi parameters (in $item)
##		
## OBEYS the "force_price" parameter in $item
##
##
## known params:
##		stidonly - doesn't actually do some of the heavy lifting such as inventory, or modifier calcs
##		schedule - the pricing schedule.
##		assemblyref - not sure what this is atm.
##		caller - this routine is called internally, so each upper function passes it's "name" or "reason" for calling
##		make_pogs_optional - passed in from stuff->cram to make "more options optional" .. this is generally used
##						as a "add as much as you know to cart" for marketplace compatibility where they don't use stid's.
##
##
##	and returns;
##		ABC:#001/#002/1
##
#sub process_pog {
#	my ($self, $item, %params) = @_;
#	my $err = undef;
#
#	# print STDERR "PROCESS_POG PARAMS:".Dumper(\%params,$item);
#
#	# warn "called process_pog($params{'caller'})\n";
#
#	my $schedule = $params{'schedule'};
#	my $assembly_ref = $params{'assemblyref'};
#
#	# open F, ">>/tmp/pog"; print F Dumper($item); close F;
#
#	my $stidonly = 0;
#	if (defined $params{'stidonly'}) { $stidonly = int($params{'stidonly'}); }
#	elsif (not defined $params{'stidonly'}) { $stidonly = 1; }
#	# if (not defined $schedule) { $stidonly++; }
#
#	## some fundamental sanity checks.
#	if (not defined $item) { 
#		$err = "called process_pog($params{'caller'}) on STUFF with an undefined item"; 
#		}
#
#	if (not defined $item->{'*pogs'}) {
#		## hmm.. some how a copy of zoovy:pogs didn't get put into $item->{'pogs'}, lets see if we can fix that
#	#	open F, ">>/tmp/fetch_pogs";
#	#	print F Dumper($item);
#		my ($pogs2) = &ZOOVY::fetch_pogs($self->username(),$item->{'full_product'});
#	#	print F Dumper($pogs2);
#	#	close F;
#		$item->{'*pogs'} = $pogs2;
#		}
#
#	if (defined $item->{'%options'}->{'##'}) {
#	# if ((defined $item->{'%options'}->{'##'}) && ($item->{'pogs'} eq '')) {
#		## if we've got one or more text based option, (e.g. notes) then we may not have zoovy:pogs set, and that's okay.
#		## but subsequent checks need too see something in item->pogs
#		push @{$item->{'*pogs'}}, { 'id'=>'##', 'inv'=>0, 'type'=>'text' };
#		# $item->{'pogs'} .= q~<pog id="##" inv="0" type="text"></pog>~;
#		}
#
#	if (not defined $item->{'*pogs'}) { 
#		$err = "called process_pog($params{'caller'}) on STUFF with item pogs not set";
#		}
#
##	if (not defined $item->{'price'}) {
##		$err = "please don't call process_pog($params{'caller'}) without setting item->price first";
##		}
#
#	## load pog struct, but first do a sanity check for structure
#	my @pog_struct = ();
#	if ($err) {
#		## don't trash the error we've already got.
#		}
#	elsif ($item->{'*pogs'}) {
#		}
#	elsif ($item->{'pogs'} =~ m/^<pog/) {
#		&ZOOVY::confess($self->username(), "UPGRADED legacy item->{'pogs'}\n",justkidding=>1);
#		$item->{'*pogs'} = POGS::text_to_struct($self->username(), $item->{'pogs'}, 1);
#		}
#	else {
#		$err = "called process_pog($params{'caller'}) on STUFF but item pogs appear to be misformatted"; 
#		}
#
#	##
#	## go through and check for finders, if all we've got is finders then we can safely exit.
#	## e.g. <pog type="attrib">
#	##
#	my @pogonly_struct = ();
#	if (not $err) {
#		foreach my $pog (@{$item->{'*pogs'}}) {
#			next if ($pog->{'type'} eq 'attribs');
#			push @pogonly_struct, $pog;
#			}
#
#		if (scalar(@pogonly_struct)==0) {
#			## okay, so we've got nothing but finders, what a sticky wicket!
#			## so this will short circuit
#			delete $item->{'*pogs'};
#			$item->{'pogs_processed'} = $^T;
#			$item->{'stid'} = $item->{'product'};
#			$item->{'sku'} = $item->{'product'};
##			print STDERR Dumper($item);
##			die();
#			}
#		#elsif ($stidonly) {
#		#	## leave $item->{*options} alone!
#		#	}
#		else {
#			## hurrah, we're going to rebuild our *options
#			$item->{'*options'} = {};
#			}
#		}
#
#
#	##
#	##	okay, so if we don't have %options, but we do have a stid with options on it, so we'll
#	##		pretend we did get passed %options so hopefully we don't error out in the next stage.
#	##
#
#
#
#	##
#	## okay, now lets see if we got some options passed to us.
#	## 
#	if ((scalar(@pogonly_struct)==0) || ($err)) {
#		## alas, we must have had only finder/attribs
#		}
#
#	# my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($stid);
#	my $description   = $item->{'description'};
#	my $weight        = $item->{'base_weight'};
#	my $price         = $item->{'price'};
#	my $orig_price		= $price;
#
#	# print STDERR "PRICE: $price\n";
#
#	my $checkinventory = 0;
#	if ($schedule ne '') {
#		require WHOLESALE;
#		my $S = WHOLESALE::load_schedule($self->username(),$schedule);
#		if (int($S->{'inventory_ignore'})==1) { $checkinventory = 0; }
#		}
#	
#
#	#$invopts   = '';	# we reset this so we can figure out the correct value.
#	#$noinvopts = '';
#
#	# print Dumper(\@pogonly_struct);
#
#	my $pog_sequence = '';
#	my $optionstr = '';
#	foreach my $pog (@pogonly_struct) {
#		last if ($err);
#
#		my $id = $pog->{'id'};
#		next if ($id eq '');
#		next if ($pog->{'type'} eq 'attribs');	## type "attribs" is used for a finder, and doesn't affect the stid.
#														   ## NOTE: this line should *NEVER* be executed since we're using @pogonly
#
#		if (not defined $pog->{'inv'}) { $pog->{'inv'} = 1; } 	# by default we assume the inventory is ON
#
#		my $pogtype   = $pog->{'type'};
#		if (not defined $pogtype) { $pogtype = 'text'; }			# by default we assume it's a text pog.
#
#	#	use Data::Dumper;
#	#	print STDERR Dumper($item->{'%options'});
#
#		my $value  = $item->{'%options'}->{$id};
#		## 10/20/11 - %options will be something like { 'A0'=>'00', 'A1'=>'01' }
#
#
##		print STDERR "VALUE: $value\n";
##		print STDERR Dumper($item);
#
#		## cheap hack to deal with readonly fields. -BH 05/08/2004
#		if (($pogtype eq 'readonly') && (not defined $value)) { $value = ''; }
#		elsif (($pogtype eq 'assembly') && (not defined $value)) { $value = ''; }
#
#		if ($params{'make_pogs_optional'}>0) {
#			# implicitly makes pogs optional
#			$pog->{'optional'} = 1;
#			}
#
#		if ((not defined $value) && ($pog->{'optional'}==0)) {
#			$err = "Pog mismatch: - cannot find pog ID $id ($pog->{'prompt'}) for product $item->{'product'}";
#			}
#
#		# my $meta = '';
#		my $value_pretty = '';
#		my $selected_opt = undef;
#
#		if (($value eq '') && ($pog->{'optional'}>0)) {
#			## this is optional, so we don't add it to the sequence since we'll skip it later.
#			}
#		elsif ($pog->{'type'} ne 'assembly') {
#			## build pog_sequence.
#			$pog_sequence .= $id.',';
#			}
#
#		if (($value eq '') && ($pog->{'optional'}>0)) {
#			## this puppy is optional, so it's no big deal we didn't get a value.
#			}
##		elsif ($pogtype eq 'assembly') {
##
##			if (not $stidonly) {
##				my ($qtyref) = &POGS::tweak_asm($pog,$checkinventory); 
##				# print STDERR 'QTYREF: '.Dumper($qtyref);
##				if (defined $qtyref) {
##					foreach my $pid (%{$qtyref}) {
##						$assembly_ref->{$pid} += $qtyref->{$pid};
##						}
##					}
##				else {
##					$err = "One or more components of this assembly are not available";
##					}
##				}
##			}
#		elsif (($pogtype eq 'text') || ($pogtype eq 'textarea') || ($pogtype eq 'number') || 
#				($pogtype eq 'calendar') || ($pogtype eq 'readonly')
#				|| $pogtype eq 'hidden') {
#
#
#			$value_pretty = $item->{'%options'}->{ $pog->{'id'} };
#			
#			if (($pog->{'optional'}>0) && ($value_pretty eq '')) {
#				## optional and blank.
#				$value = ''; 
#				}
#			else {
#				## this is required/non-optional *OR* not blank.
#				$value = '##';	
#				## handle fees.
#				my ($fee,$feetxt) = &POGS::pog_calc_textfees($self->username(),$pog,$value_pretty);
#				# print STDERR "POG: $pog->{'id'} FEE: $fee PRICE: $price\n";
#				if (not defined $price) {
#					## don't ever set $price if it wasn't already set, otherwise it won't properly inherit from
#					## zoovy:base_price
#					## since process_pog is called BEFORE the price is set, to make sure we've got a valid stid.
#					}
#				elsif ($fee>0) { 
#					## note: at some point we should really break these out into separate fields in *options
#					$value_pretty .= " ($feetxt)"	;  
#					$price += $fee;
#					}
#				}
#
#			## we need to keep this for becky, because apparently ZID uses the STID
#			## instead of pog sequence
#			# $noinvopts .= "/$id$value";
#
#			## since the xcompat 115, all options (even textboxes) appear in the stid sequence
#			## -- this was a bad idea: $noinvopts .= "/$id$value";
#			}
#		else {
#			##
#			## "SELECT" BASE TYPE
#			##	
#
#			## remember: swogs (system wide option groups) might start with a $
#			if ($value eq '') {
#				$err = "Pog required - (product $item->{'product'}) requires a value for pog ID $id ($pog->{'prompt'})";
#				}
#			elsif ($value !~ m/^[\$\#a-zA-Z0-9][a-zA-Z0-9]$/) {
#				$err = "Pog mismatch - (product $item->{'product'}) badly formatted pog value '$value' for pog ID $id ($pog->{'prompt'})";
#				}
#
#			foreach my $opt (@{$pog->{'@options'}}) {
#				if ($opt->{'v'} eq $value) {
#					$selected_opt = $opt;
#					}
#				}
#
#			if (defined $selected_opt) {
#				$value_pretty = $selected_opt->{'prompt'};
#				}
#			else {
#				$value_pretty = 'Err';
#				}
#
#			if ($pogtype eq 'cb') {
#				if ($value eq 'ON') { 
#					$value_pretty = 'Yes'; 
#					} 
#				elsif ($value eq 'NO') { 
#					$value_pretty = 'No'; 
#					}
#				elsif (($value eq '') && ($item->{'mkt'} ne '')) {
#					## YIPES marketplace order (so lets try NOT to throw an error eh?)
#					$value_pretty = 'Not Set';
#					}
#				elsif (($value ne 'ON') && ($value ne 'NO')) {
#					# if i am neither ON or NO e.g. I'm "CRAZY!"
#					$err = "Pog mismatch - badly formatted pog value $value for pog ID $id ($pog->{'prompt'}) checkboxes can only have ON and NO";
#					}
#				}
#						
#			if ($pog->{'inv'}) {
#				$optionstr .= ":$id$value";
#				}
#			else {
#				$optionstr .= "/$id$value";
#				}
#			
#			}
#
#		if ($err ne '') {
#			print STDERR "ERR:$err\n";
#			}
#
#
#		next if ($err);
#		# next if ($stidonly);		# HEY: stidonly mode skips calculations and JUST RETURNS THE STID.
#		next if ($pogtype eq 'assembly');		## hey, assembly's should not be added to *options
#
#		if ($stidonly) {
#			## we're going to set a summary *options
#			$item->{'*options'}->{"$id$value"} = {
#				'v' => $value,
#				'value'=>$value_pretty,
#				'prompt' =>$pog->{'prompt'},
#				'inv'=>$pog->{'inv'},
#				'quick'=>1,
#				};
#
#			# open F, ">>/tmp/foo"; use Data::Dumper; print F 'other '.Dumper($item->{'*options'}->{"$id$value"})."\n"; close F;
#			}
#		else {
#			$description .= " / $pog->{'prompt'}: $value_pretty";
#			#$meta = def($meta);
#			#if ($meta eq 'w=|p=') { $meta = ''; }
#
#			# my $mref = &POGS::parse_meta($meta);
#			if ($stidonly) {}	## don't need to run this code if stidonly=1
#			#elsif (($pog->{'inv'} & 2) && ($selected_opt->{'asm'} ne '')) { 
#			#	my $qtyref = &POGS::tweak_asm_option($pog,$selected_opt); 
#			#	# print STDERR 'QTYREF: '.Dumper($qtyref);
#			#	foreach my $pid (%{$qtyref}) {
#			#		if (not defined $assembly_ref->{$pid}) { $assembly_ref->{$pid} = 0; }
#			#		$assembly_ref->{$pid} += int($qtyref->{$pid});
#			#		# $ASSEMBLE_ITEMS{$pid} += $qtyref->{$pid};
#			#		}
#			#	}
#			#	# use Data::Dumper; print STDERR Dumper(\%ASSEMBLE_ITEMS);
#	
#			# use Data::Dumper; print STDERR "META: $meta\n".Dumper($mref);
#			if (int($item->{'claim'}) > 0) {
#				## i guess we probably shouldn't check inventory on claims 
#				## note: this is important for the shipping calculator
#				}
#			elsif ($selected_opt->{'skip'}>0) {	
#				$err = "Pog mismatch - one or more items [$selected_opt->{'skip_reason'}] needed to complete this assembly are not available.";
#				}
#	
#			if ($err) {
#				## bad shit has happened here.
#				}
#			elsif (($value eq '') && ($pog->{'optional'}>0)) {
#				## no value set, PLUS this is optional.. so we don't add to *options
#				print STDERR Dumper($pog);
#				}
#			else {
#				## okay, lets do some final price calculations.
#				# $meta = &POGS::encode_meta($selected_opt);
#	
#				if (not defined $weight) {
#					## if weight is undef, don't set weight to modifier value
#					## since it will ovwrite our change to inhert from zoovy:base_weight later.
#					}
#				elsif (defined($selected_opt->{'w'}) && ($selected_opt->{'w'} ne '')) {
#					$weight = calc_pog_modifier(ZSHIP::smart_weight($weight), ZSHIP::smart_weight($selected_opt->{'w'},1));
#					}
#
#				if (not defined $price) {
#					## if price is undef, don't set price to modifier value, since it will overwrite our chance
#					## to inherit from zoovy:base_price later
#					}
#				elsif (defined($selected_opt->{'p'}) && ($selected_opt->{'p'} ne '')) {
#					$price = sprintf('%.2f', calc_pog_modifier($price, $selected_opt->{'p'}));
#					}
#	
#				$item->{'*options'}->{"$id$value"} = {
#					'v' => $value,
#					'value' => $value_pretty,
#					'modifier' => &POGS::encode_meta($selected_opt),
#					'prompt' => $pog->{'prompt'},
#					'inv'=>$pog->{'inv'},
##				'vx'=>$value_pretty,
##				'px'=>$pog->{'prompt'},
#					};
#
#
#				# open F, ">>/tmp/foo"; use Data::Dumper; print F 'full '.Dumper($item->{'*options'}->{"$id$value"})."\n"; close F;
#				}
#			}
#		}
#
#	chop($pog_sequence);	 #remove the trailing comma (,)
#
#
#	## 
#	my $stid = undef;
#	if (scalar(@pogonly_struct)==0) {
#		## no options, probably just attributes
#		}
#	elsif (not $err) {
#		# print STDERR Dumper($item);
#		$item->{'optionstr'} = $optionstr;
#		$item->{'pog_sequence'} = $pog_sequence;
#		warn "CALLING VALIDATE_STID FROM process_pog($params{'caller'})";
#		($stid,$pog_sequence) = $self->validate_stid($item,note=>$item->{'notes'});
#		# print "STID: $stid pog: $pog_sequence\n";
#		}
#	elsif ($err) {
#		$item->{'pog_err'} = $err;
#		}
#
#	## pop the cherry.
#	if (not $stidonly) {
#		$item->{'pogs_processed'} = $^T;	# this makes sure we never go through this block of code twice for the same item.
#		delete $item->{'%options'};
#		}
#
#	if ((defined $item->{'force_price'}) && ($item->{'force_price'}>0)) {
#		## we're going to force the price (no option modifiers)
#		$price = $orig_price;
#		}
#	# $price = 0; $orig_price = 0;
#	
#	my $newitem = {
#		%{$item},
#		'weight' => $weight,
#		'price' => $price,
#		'pogs_price_diff' => $price - $orig_price,	# the difference (amount to add if we change base price later with qty_price)
#		'description' => $description,
#		'pog_sequence' => $pog_sequence,
#		};
#
##	## %ASSEMBLE_ITEMS is a keyed by SKU, value is quantity
##	if (scalar(keys %ASSEMBLE_ITEMS)>0) {
##		## we've got optiosn to assemble!
##		#use Data::Dumper; print STDERR Dumper(\%ASSEMBLE_ITEMS);
##		}
#	
#	if ($err) {
#		return($err);
#		}
#
#	# warn "leaving process_pog($params{'caller'})\n";
#	return (undef, $newitem);
#	}



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

#	if ($modification =~ /\=/) { 
#		return($modification); 
#		}


#	return unless (defined $value);
#	return $value unless (defined $modification);
#	return $value unless ($modification =~ m/(\+|\-|\=\+|\=\-|\=)(.+)$/);
#
#	no warnings 'numeric';
#
#	my $modifier = $1;
#	my $amount = $2;
#
#	if ($amount =~ s/\%//gs)
#	{
#		$amount = ($value * $amount) / 100;
#	}
#
#	if    ($modifier eq '=')  { $value  = $amount; }
#	elsif ($modifier eq '+')  { $value += $amount; }
#	elsif ($modifier eq '=+') { $value += $amount; }
#	elsif ($modifier eq '-')  { $value -= $amount; }
#	elsif ($modifier eq '=-') { $value -= $amount; }
#
#	return $value;	
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


##
## SUB: legacy_xmlcontents_to_stuff
## 		
## <contents>
## &lt;product id=&quot;LIN-1&quot; price=&quot;15.50&quot; qty=&quot;1&quot; wt=&quot;8&quot; tax=&quot;Y&quot;&gt;Black Linux Tux Pengiun Shirt / T SHIRT SIZ
## &lt;product id=&quot;PROTUX-1&quot; price=&quot;26.95&quot; qty=&quot;1&quot; wt=&quot;8&quot; tax=&quot;Y&quot;&gt;Pro Collection Linux Tux Polo / Deluxe P
## </contents>
##
## loads it into the STUFF
##	returns legacy style contents and extra hashrefs
##
#sub legacy_xmlcontents_to_stuff  {
#	my ($self,$USERNAME,$CONTENTS) = @_;
#
#	my %cart = ();
#	my %extra = ();
#
#	## first, import the old contents
#	require ZORDER;
#	my $itemsref = &ZTOOLKIT::xmlish_list_to_arrayref($CONTENTS,'tag_match'=>qr/product/i,'content_attrib'=>'description','lowercase'=>1);
#	$itemsref = &ZORDER::clean_contents_newref($itemsref);	
#	foreach my $i (@{$itemsref}) {	
#		$cart{$i->{'id'}} = "$i->{'price'},$i->{'qty'},$i->{'wt'},$i->{'tax'},$i->{'description'}";
#		## Old format (non-hashed) is just the tracking number, new format has a hash of the item's info.  Keep in mind that the new format duplicates info stored in CART_REF
#		$extra{$i->{'id'}} = $i->{'trk'};
#		}
#
#	## now load the contents into the stuff	
#	&contents_to_stuff($self,$USERNAME,\%cart,\%extra);
#
#	return(\%cart,\%extra);
#}

## 
## purpose: converts the current stuff object to the legacy
##		<product id="">asdf</product> format
##
#sub stuff_to_legacyxml {
#	my ($self) = @_;
#
#	my @required_fields = qw(id price qty wt tax); ## Fields we make sure are defined, and output in this order at the beginning of the attribs
#	my $contents = '';
#	my @CONTENTS = $self->make_contents();
#	my $ITEMS_COPY = &ZORDER::clean_contents_newref(\@CONTENTS); ## Make a copy of the items ref and clean it.
#	foreach my $line_item (@{$ITEMS_COPY})
#	{
#		my %item = %{$line_item};
#		## Skip if we're killing hidden items
#		## Clean up the hash for XML output (encode the values, strip non-word characters from the the keys)
#		foreach my $orig_key (keys %item)
#		{
#			my $key = $orig_key;
#			## If we had to change the key for any reason, get rid of the old one a create the new one
#			if ($key =~ s/\W+/_/g)
#			{ 
#				$item{$key} = $item{$orig_key};
#				delete $item{$orig_key};
#			}
#			$item{$key} = &ZOOVY::incode($item{$key});
#		}
#		## Remove description from the hash, since we encode it into the value of the tag
#		my $description = $item{'description'}; delete $item{'description'};
#		## Create the attributes for the tag
#		my $attribs = '';
#		## Put all the required attribs up front, then go through all the remaining attribs
#		## (And remove them from the hash as we go, so they don't get output when called a second time)
#		foreach my $name (@required_fields, (sort keys %item))
#		{
#			next unless defined($item{$name}); ## Skip ones we've already output
#			$attribs .= qq~ $name="$item{$name}"~;
#			delete $item{$name}; ## Remove the attrib
#		}
#		## Create the fully baked line item!
#		$contents .= qq~<product$attribs>$description</product>\n~;
#	}
#	
#	return($contents);
#}
#

##
## purpose: converts a contents array (array of hashrefs) to stuff.
## takes 
##		$contents - hashref keyed by sku - value: price,qty,wt,tax,description
##		$extra - hashref keyed by sku - value: trk-tracking#
##
#sub contents_to_stuff
#{
#	my ($self, $USERNAME, $contents, $extra) = @_;
#	if (not defined $extra) {
#		$extra = {}
#		}
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

#		if ($xcompat<=114) {
#	
#			# [Wed Apr 02 13:17:16 2008] [error] [client 192.168.1.200] STIDx: ABCDEF/#Z00
##			print STDERR "STIDx: $stid\n";
#			$stid =~ s/([\:\/]+)([\d]{2,2})$/$1##$2/g;	## make PID:1234/1 PID:1234/##01 
#			$stid =~ s/([\:\/]+)([\d]{1,1})$/$1##0$2/g;	## make PID:1234/1 PID:1234/##01 
##			print STDERR "STIDy: $stid\n";
#
#			if ($stid =~ /^(.*)\/(.*?)$/) {
#				my ($pre,$post) = ($1,$2);
#				$post =~ s/:/\//g;		# replace all :'s with / past the first /
#				$stid = $pre.'/'.$post;
##				print STDERR "STIDq: $stid\n";
#				}
#
#			
#			if ($ref->{'assembly_master'} ne '') {
#				my $asm = $ref->{'assembly_master'};
#				if ($stid =~ /^(.*)\/$asm$/i) {
#					$stid = $ref->{'assembly_master'}.'@'.$1;
#					}
#				}
#
#			## NOTE: it's far too difficult to reliably detect assemblies at this point
#			##			so we're just going to leave /master-sku at the end and we'll clean it up later.
#
#			# [Wed Apr 02 13:17:16 2008] [error] [client 192.168.1.200] STIDy: ABCDEF/
##			print STDERR "STIDy: $stid\n";
#			}
#

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

#				if ($xcompat<=114) {
##[Wed Apr 02 07:05:34 2008] [error] [client 66.240.244.217] $VAR1 = [
##[Wed Apr 02 07:05:34 2008] [error] [client 66.240.244.217]           {
##[Wed Apr 02 07:05:34 2008] [error] [client 66.240.244.217]             'content' => [],
##[Wed Apr 02 07:05:34 2008] [error] [client 66.240.244.217]             'name' => 'option',
##[Wed Apr 02 07:05:34 2008] [error] [client 66.240.244.217]             'attrib' => {
##[Wed Apr 02 07:05:34 2008] [error] [client 66.240.244.217]                           'value' => 'Enter Text Here (13 characters 3 words 1 lines)',
##[Wed Apr 02 07:05:34 2008] [error] [client 66.240.244.217]                           'id' => 'A5En',
##[Wed Apr 02 07:05:34 2008] [error] [client 66.240.244.217]                           'prompt' => 'Text Box',
##[Wed Apr 02 07:05:34 2008] [error] [client 66.240.244.217]                           'modifier' => ''
##[Wed Apr 02 07:05:34 2008] [error] [client 66.240.244.217]                         },
##[Wed Apr 02 07:05:34 2008] [error] [client 66.240.244.217]             'type' => 'e'
##[Wed Apr 02 07:05:34 2008] [error] [client 66.240.244.217]           }
##[Wed Apr 02 07:05:34 2008] [error] [client 66.240.244.217]         ];
##[Wed Apr 02 07:05:34 2008] [error] [client 66.240.244.217] No such pseudo-hash field "id" at /backend/lib/STUFF.pm line 1469, <STDIN> line 1.
#
#					## xcompat 114 and earlier sent up A2 instead of A2##
#					if (not defined $x->{'id'}) {}
#					elsif (length($x->{'id'})==2) { $x->{'id'} .= '##' }
#					}

#				use Data::Dumper; 	print STDERR Dumper($ref,$x);

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

#	my $xml = '';
#	my $errors = '';
#
#	foreach my $stid ($self->stids()) {
#		my %item = %{$self->item($stid)};
#
#		my $extra = '';
#		if ((defined $item{'*options'}) && (ref($item{'*options'}) eq 'HASH')) {
#			my %opts = %{$item{'*options'}};
#			my $opt_xml = '';
#			my $stid_str = $stid;
#			$stid_str =~ s/\/\d\d?\d?$//;		# wtf?? -- strips out "random" pogs (e.g. engraved)
#			$stid_str =~ s/^.*?[\:\/]+//;		# -- strips off the product
#			my (@stid_opts) = split("[:\/]+", $stid_str);
#			my $count = 0;
#			foreach my $oid (@stid_opts){
#				if (not $opts{$oid}) {
#					$errors .= "STUFF object does not match provided options for STID $stid, options skipped";
#					}
#				$count++;
#				}
#			if ($errors eq '') {
#				foreach my $oid (@stid_opts) {
#					my $opt = $opts{$oid};
#					my $prompt = encode_latin1($opt->{'prompt'});
#					my $value = encode_latin1($opt->{'value'});
#					my $modifier = encode_latin1($opt->{'modifier'});
#					$opt_xml .= qq~<option id="$oid" prompt="$prompt" modifier="$modifier">$value</option>\n~;
#					}
#				$extra .= "<options>\n" . entab($opt_xml) . "</options>\n";
#				delete $item{'*options'};
#				}
#			else {
#				$opt_xml .= qq~<options><!-- not rendered due to errors: $errors --></options>~;
#				}
#			}
#			
#
#		if (defined $item{'%fees'}) {
#			my %fees = %{$item{'%fees'}};
#			my $fee_xml = '';
#			foreach my $feeid (keys %fees) {
#				if ($feeid !~ m/^[\w\:]+$/) {
#					$errors .= "Fee ID $feeid does not look valid\n";
#					next;
#					}
#				my $id = $feeid;
#				$id =~ s/\:/-/gs;
#				my $value = encode_latin1(def($fees{$feeid}));
#				$fee_xml .= qq~<$id>$value</$id>\n~;
#				}
#			$extra .= "<fees>\n" . entab($fee_xml) . "</fees>\n";
#			delete $item{'%fees'};
#			}
#
#		if (defined $item{'%attribs'}) {
#			my %attribs = %{$item{'%attribs'}};
#			my $attribs_xml = '';
#			foreach my $attrib (keys %attribs) {
#				if ($attrib !~ m/^[\w\:]+$/) {
#					$errors .= "Attrib $attrib does not look valid\n";
#					next;
#					}
#				my $id = $attrib;
#				$id =~ s/\:/-/gs;
#				my $value = encode_latin1(def($attribs{$attrib}));
#				$attribs_xml .= qq~<$id>$value</$id>\n~;
#			}
#			$extra .= "<attribs>\n" . entab($attribs_xml) . "</attribs>\n";
#			delete $item{'%attribs'};
#		}
#
#		delete $item{'stid'};
#
#		my $attribs = '';
#		foreach my $key (qw(qty assembly_master notes prod_name pog_sequence cost weight price taxable description mkt mktid mktuser mkturl qty_price claim channel inv_mode)) {
#			next unless defined $item{$key};
#			my $value = encode_latin1(def($item{$key}));
#			$attribs .= qq~ $key="$value"~;
#			}
#		$stid = encode_latin1($stid);
#		$xml .= qq~<product stid="$stid"$attribs>\n~ . entab($extra) . qq~</product>\n~;
#	}
#	
#	#$xml = qq~<products>\n~ . entab($xml) . qq~</products>\n~;
#
#	return $xml, $errors;
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
	

#	if (
#		(not defined $tax_rate) ||
#		($tax_rate eq '') ||
#		($tax_rate !~ m/[0-9]*\.?[0-9]*/)) {
#		$tax_rate = 0;
#		}
#
#	
#	if (not defined $skip_discounts) {
#		$skip_discounts = 0;
#		}
#
#	my $subtotal = 0; ## The total dollar value of the stuff before adding tax/shipping/etc
#	my $taxable  = 0; ## The total dollar value of the taxable stuff
#	my $weight   = 0; ## The total weight of the stuff
#	my $items    = 0; ## The number of items
#
#	## Loop over all of the items and add up the totals
#	my $pkg_weight_194 = 0;
#	my $pkg_weight_166 = 0;
#	foreach my $sku ($self->stids()) {
#		next if ($skip_discounts && (substr($sku, 0, 1) eq '%'));
#		my $item = $self->{$sku};
#		if (def($item->{'price'})    eq '') { $item->{'price'}    = 0; }
#		if (def($item->{'qty'})      eq '') { $item->{'qty'}      = 0; }
#		if (def($item->{'weight'})   eq '') { $item->{'weight'}   = 0; }
#
#		$item->{'taxable'} = taxable($item->{'taxable'});
#
#		$item->{'weight'} = &ZSHIP::smart_weight($item->{'weight'});
#		$item->{'cubic_inches'} = 0;
#		my $a = $item->{'%attribs'};
#		if (not defined $a->{'zoovy:pkg_depth'}) { $a->{'zoovy:pkg_depth'}=0; }
#		if (not defined $a->{'zoovy:pkg_width'}) { $a->{'zoovy:pkg_width'}=0; }
#		if (not defined $a->{'zoovy:pkg_height'}) { $a->{'zoovy:pkg_height'}=0; }
#
#		if ( (int($a->{'zoovy:pkg_depth'})>0) &&
#			(int($a->{'zoovy:pkg_width'})>0) && (int($a->{'zoovy:pkg_height'})>0) ) {
#
#			my $pkg_exclusive = int((defined $a->{'zoovy:pkg_exclusive'})?defined $a->{'zoovy:pkg_exclusive'}:0);
#			if ($pkg_exclusive==0) { $pkg_exclusive = 0; }	## no dimensional rounding
#			elsif ($pkg_exclusive==1) { $pkg_exclusive = 0.9999; }
#
#			$item->{'cubic_inches'} = int($a->{'zoovy:pkg_depth'}) * int($a->{'zoovy:pkg_width'}) * int($a->{'zoovy:pkg_height'});
#
#			my $w = int(($item->{'cubic_inches'} / 194)+$pkg_exclusive)*16;
#			if ($w>$item->{'weight'}) { $pkg_weight_194 += ($w*$item->{'qty'}); } else { $pkg_weight_194 += ($item->{'weight'} * $item->{'qty'}); }
#
#			$w = int(($item->{'cubic_inches'} / 166)+$pkg_exclusive)*16;
#			if ($w>$item->{'weight'}) { $pkg_weight_166 += ($w*$item->{'qty'}); } else { $pkg_weight_166 += ($item->{'weight'} * $item->{'qty'}); }
#			}
#		else {
#			$pkg_weight_194 += ($item->{'weight'} * $item->{'qty'});
#			$pkg_weight_166 += ($item->{'weight'} * $item->{'qty'});
#			}
#		#if (index($item->{'weight'}, '#') > 0) {
#		#	my ($lbs, $oz) = split ('#', $item->{'weight'});
#		#	$lbs =~ s/[^0-9]//g;
#		#	$oz  =~ s/[^0-9]//g;
#		#	if ($lbs eq '') { $lbs = 0; }
#		#	if ($oz  eq '') { $oz  = 0; }
#		#	$item->{'weight'} = ($lbs * 16) + $oz;
#		#	}
#
#
#		$item->{'extended'} = ($item->{'price'} * $item->{'qty'});
#		$subtotal += sprintf("%.2f", $item->{'extended'});
#		if ($item->{'taxable'}) { $taxable += sprintf("%.2f", $item->{'extended'}); }
#		$weight += ($item->{'qty'} * $item->{'weight'});
#		## Handle hidden items and discounts
#		if ((substr($sku, 0, 1) ne "!") && (substr($sku, 0, 1) ne '%')) { $items += $item->{'qty'}; }
#		}
#
#	my $tax = sprintf("%.2f", ($tax_rate / 100) * $taxable);
#	if (int($weight) < $weight) { $weight = int($weight)+1; }	# don't keep around decimals on the final weight
#
#	# print STDERR "CART WEIGHT: $weight\n";
#	
#	return ($subtotal, $weight, $tax, $taxable, $items, $pkg_weight_194, $pkg_weight_166);
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
