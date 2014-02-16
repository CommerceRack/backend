package POGS;

use strict;

%POGS::SOG_CACHE = ();

no warnings 'once';

use Carp;
use XML::Simple;
use YAML::Syck; 
use Clone;

use lib '/backend/lib';
require ZTOOLKIT;
require PRODUCT;
require ZWEBSITE;



##
## NOTE: not actually used at this point, this creates a map of all sogs.
##
##  perl -e 'use lib "/backend/lib"; use POGS; POGS::create_sog_lookup_map("fkaufmann");'
##
#sub create_sog_lookup_map {
#	my ($USERNAME) = @_;
#
#	my %MAP = ();
#	my $soglist = &POGS::list_sogs($USERNAME);
#	foreach my $sogid (sort keys %{$soglist}) {
#		my $sogname = $soglist->{$sogid};
#		my ($sogref) = &POGS::load_sogref($USERNAME,$sogid);
#		$MAP{uc(sprintf("%s:",$sogname))} = "$sogid:";
#		$MAP{uc(sprintf("%s:",$sogid))} = "$sogid:";
#		if ($sogref->{'@options'}) {
#			foreach my $opt (@{$sogref->{'@options'}}) {
#				$MAP{uc(sprintf("%s:%s",$sogname,$opt->{'prompt'}))} = "$sogid:$opt->{'v'}";
#				$MAP{uc(sprintf("%s:%s",$sogname,$opt->{'v'}))} = "$sogid:$opt->{'v'}";
#				$MAP{uc(sprintf("%s:%s",$sogid,$opt->{'prompt'}))} = "$sogid:$opt->{'v'}";
#				}
#			}
#
#		# $MAP{$sogname} = $sogid;
#		}
#
#	# print Dumper(\%MAP);
#	return(\%MAP);
#	}

##
## used by 
##
sub to_json {
	my ($pogs2) = @_;

	require JSON::XS;
	my $pidjs = JSON::XS::encode_json($pogs2);
	# my ($pidsjs) = JSON::XS::encode_json($pogs2);
	return($pidjs);
	}


sub from_json {
	my ($json) = @_;
	require JSON::XS;
	my @pogs2 = @{ JSON::XS::decode_json($json) };

	return(\@pogs2);
	}

##
## takes a stid, and a $pogs2 array reference and returns an abbreviated pog set 
##		abbreviated means it doesn't contain the same level of detail, and only the selected options
##		useful for minimizing disk storage after data is not likely to change
##
#sub abbreviate {
#	my ($STID,$pogs2) = @_;
#
#	my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($STID);
#	my %STIDOPTS = ();
#	foreach my $optidval (split(/[\:\/]+/,"$invopts:$noinvopts")) {
#		next if ($optidval eq '');
#		my $OPTID = substr($optidval,0,2);
#		my $OPTVAL = substr($optidval,2,2);
#		$STIDOPTS{$OPTID} = $OPTVAL;
#		}
#
#
#	my @abbrpogs2 = ();
#	foreach my $pog (@{$pogs2}) {
#		next if (not defined $STIDOPTS{$pog->{'id'}});
#		my %abbrpog = ();
#		$abbrpog{'type'} = $pog->{'type'};
#		$abbrpog{'abbr'} = 1;
#		$abbrpog{'id'} = $pog->{'id'};
#		$abbrpog{'inv'} = $pog->{'inv'};
#		if ($pog->{'sog'}) {	$abbrpog{'sog'} = $pog->{'sog'}; }
#		if (defined $pog->{'@options'}) {
#			foreach my $option (@{$pog->{'@options'}}) {
#				if ($option->{'v'} eq $STIDOPTS{$pog->{'id'}}) {
#					push @{$abbrpog{'@options'}}, $option;
#					}
#				}			
#			}
#		push @abbrpogs2, \%abbrpog;
#		}
#	
#	return(\@abbrpogs2);
#	}

##
##
##
sub serialize {
	my ($pogs2) = @_;

	my $xml = '';	
	foreach my $pog2 (@{$pogs2}) {
		$xml .= &POGS::to_xml($pog2);
		}
	
	return($xml);
	}

##
##
##
sub deserialize {
	my ($xml) = @_;

	my @pogs2 = ();
	my ($xref) = XML::Simple::XMLin("<pogs>$xml</pogs>",ForceArray=>1,KeepRoot=>0,KeyAttr=>'');
	foreach my $pognode (@{$xref->{'pog'}}) {
		#$VAR1 = [
  		#       {
  		#         'abbr' => 1,
  		#         'inv' => '0',
  		#         'id' => '00',
  		#         'type' => 'select',
  		#         '@options' => [
  		#                         {
  		#                           'v' => '01',
  		#                           'prompt' => 'Aqua - A'
  		#                         }
  		#                       ]
  		#       }
  		#     ];
		# print 'pognode: '.Dumper($pognode);
		my %newpog = ();
		foreach my $key (keys %{$pognode}) {
			if ($key eq 'option') {
				## special case
				foreach my $option (@{$pognode->{'option'}}) {
					push @{$newpog{'@options'}}, $option;
					}
				}
			elsif (ref($pognode->{$key}) eq '') {
			$newpog{$key} = $pognode->{$key};
				}
			}
		push @pogs2, \%newpog;
		}
	return(\@pogs2);
	}


##
## takes a single sog/pog (if you have multiple you must do your own looping and serializes to xml)
##	
sub to_xml {
	my ($ref) = @_;

	my %copy = %{$ref};
	delete $copy{'@options'};
	delete $copy{'$$'};

	require XML::Writer;
	my $xml = '';
	my $writer = new XML::Writer(OUTPUT => \$xml);
   $writer->startTag("pog",%copy);
	if (defined $ref->{'@options'}) {
		foreach my $opt (@{$ref->{'@options'}}) {
			$writer->startTag("option",%{$opt});
			$writer->endTag("option");
			}
		}
	$writer->endTag("pog");
	$writer->end();

	return($xml);
	}


##
## this is use to figure out a default set of options given a product.
##		if a STID is passed, then we'll try and figure it out from that.
##
sub default_options {
	my ($USERNAME,$STID,$pogs2, %params) = @_;

	&ZOOVY::confess($USERNAME,"DEPRECATED POGS::default_options",justkidding=>1);

	if (ref($pogs2) eq '') {
		Carp::croak("POGS::default_opptions cannot be passed a reference as pog2");
		}

	my ($pid,$claim,$invopts,$noinvopts,$virtual) = PRODUCT::stid_to_pid($STID);

	my %options = ();
	## addition so options is defined for both inv and non-inv STIDs
	if ($STID =~ /[:\/]/) {
		foreach my $pairs (split(/[:\/]/,$invopts.':'.$noinvopts)) {
			next if ($pairs eq '');
			$options{ substr($pairs,0,2) } = substr($pairs,2,2);
			}
		}

	$noinvopts = '';
	$invopts = '';

	foreach my $pog (@{$pogs2}) {
		next if ($pog->{'type'} eq 'attrib');
		next if ($pog->{'type'} eq 'attribs');
		# print STDERR "pog->{'options'} : ".Dumper($pog->{'options'})."\n";
		if (not defined $pog->{'@options'}) {
			## no options, it's probably a text field.
			$options{ $pog->{'id'} } = '##';
			# print STDERR "undef options: ".Dumper($pog->{'id'})."\n";
			}
		elsif (defined $options{ $pog->{'id'} }) {
			## %options already initialized - leave it alone.
			}
		else {
			## has options, then it's basically a select
			my $opt = undef;

			## use the selected value if one is available.
			if ($pog->{'selected'} ne '') { 
				foreach my $option (@{$pog->{'@options'}}) {
					if ($option->{'v'} eq $pog->{'selected'}) { $opt = $option; }
					}
				}
	
			## default to the first element in the list.
			if (not defined $opt) { $opt = $pog->{'@options'}->[0]; }

			$options{ $pog->{'id'} } = $opt->{'v'};
			}
		
		if ($pog->{'inv'}) {
			$invopts .= ':'. $pog->{'id'} . $options{ $pog->{'id'} };
			}
		else {
			$noinvopts .= '/'. $pog->{'id'} . $options{ $pog->{'id'} };
			}	
		}

	my $fullstid = (($claim ne '')?$claim.'*':'').$pid.$invopts.$noinvopts;

	return(\%options,$fullstid);
	}


##
## returns a hashref of sku+qty
##
##
#**VERIFY
#sub assembly_items {
#	my ($USERNAME, $PREF, $pogsref) = @_;
#
#	my %PIDQTY = ();
#
#	## prod_asm
#	if ($PREF->{'zoovy:prod_asm'} ne '') {
#		foreach my $pidqty (split(/,/,$PREF->{'zoovy:prod_asm'})) {
#			my ($PID,$qty) = split(/\*/,$pidqty);
#			if (not defined $qty) { $qty = 1; }
#			$qty = int($qty);
#			$PIDQTY{$PID} += $qty;
#			}
#		}
#
#	## asm's in options
#	foreach my $pogref (@{$pogsref}) {
#		foreach my $opt (@{$pogref->{'@options'}}) {
#			# my $metaref = parse_meta($opt->{'m'});
#			next if ($opt->{'asm'} eq '');
#
#			my $asm = $opt->{'asm'};
#			$asm =~ s/[ ]+//gs;	# remove spaces
#			foreach my $pidqty (split(/,/,$asm)) {
#				my ($PID,$qty) = split(/\*/,$pidqty);
#				if (not defined $qty) { $qty = 1; }
#				$qty = int($qty);
#				$PIDQTY{$PID} += $qty;
#				}
#			}
#		}
#	
#	return(\%PIDQTY);
#	}


##
##	function: pog_ispy (as in "I Spy" with my little eye) .. tells about the composition is in a pog.
##
##	 pass in: 
##		$USERNAME,$prodref, text_to_struct($pogtxt) 
##
##		($prodref isn't currently used but is reserved for future syndication stuff)
##
##	 returns a bitwise value:
##		1 = contains attributes 
##		2 = attributes ONLY	(NOTE: this means NO OTHER OPTIONS either inventoriable or non-inventoriable)
##		4 = contains non-inv options
##		8 = non-inv options ONLY  (NOTE: this ignores attributes since those don't matter in these cases)
##		16 = contains inv_options 
##		32 = inv options ONLY		(NOTE: this ignores attributes since those don't matter in these cases)
##	
##	note: 2 means that 1 is also turned on (in case that wasn't obvious)
##	
#sub pog_ispy {
#	my ($USERNAME,$prodref,@pogs2) = @_;
#
#	my $attribs = 0;
#	my $non_inv = 0;
#	my $inv = 0;
#	my $result = 0;
#	
#	foreach my $pogref (@pogs2) {
#		if ($pogref->{'type'} eq 'attribute') { $attribs++; }
#		elsif ($pogref->{'inv'}) { $inv++; } 
#		else { $non_inv++; }
#		}
#	
#	if ($attribs>0) {
#		$result += 1;
#		if (($non_inv==0) && ($inv==0)) { $result += 2; }
#		}
#	
#	if ($non_inv>0) {
#		$result +=4;
#		if ($inv==0) { $result += 8; }
#		}
#	
#	if ($inv>0) {
#		$result +=16;
#		if ($non_inv == 0) { $result += 32; }
#		}
#	
#	return($result);
#	}
#


##
## returns a list of swogs - keyed by id, value is name.
##		swogs are stored in /httpd/static/swogs/id-filename.txt
##
sub list_swogs {
	my ($USERNAME) = @_;

	my %ref = ();
	opendir my $D, "/httpd/static/swogs/";
	while ( my $file = readdir($D) ) {
		next if (substr($file,0,1) eq '.');	
		next if (substr($file,0,1) eq '_');	
#		print STDERR "FILE: $file\n";
		if ($file =~ /^(\d\d)\-(.*?)\.yaml$/) {
			$ref{$1} = $2;	
			}
		}
	closedir ($D);	
#	print STDERR Dumper(\%ref);
	
	return(\%ref);
	}

##
## pass an ID (e.g. 99) and it copies the swog into 
##		the local merchants directory.
##
#**VERIFY
sub import_swog {
	my ($USERNAME,$ID) = @_;

	my $ref = &POGS::list_swogs($USERNAME);
#	print STDERR 'import: '.Dumper($ref);
#	die();
	if (defined $ref->{$ID}) {
		die();
		my ($buf) = YAML::Syck::LoadFile("/httpd/static/swogs/$ID-$ref->{$ID}.yaml");
#		open F, "</httpd/static/swogs/".$ID."-".$ref->{$ID}.".yaml";
#		$/ = undef; my $buf = <F>; close F; $/ = "\n";
#		close F;
##		print STDERR "BUF: $buf\n";
##		die();
		&POGS::register_sog($USERNAME,$ID,$ref->{$ID},$buf);
		return(1);
		}
	return(0);
	}


##
## this is for tweaking a pog of type "assembly"
##
##	takes a pogstruct of type "assembly" and loads the "assembly" field
##		which is a comma separated list of: SKU1*QTY,SKU2*QTY
##		note: uses recram so that we don't do any bounds checking, we just want a simple stuff back with sku + qty.
##
##	returns:
##		undef on failure (no inventory)
##		a hash keyed by $SKU value is quantity to add
##
#**VERIFY
#sub tweak_asm {
#	my ($pog, $checkinventory) = @_;
#
#	if (not defined $checkinventory) { $checkinventory = 1; }
#
#	require STUFF;
#	## asm is a comma separated list of PID*QTY
#	my $USERNAME = $pog->{'USERNAME'};
#	my $tmpstuff = STUFF->new($USERNAME);	
#
#	my %QTY = ();
#	my $asm = '';
#	if ($pog->{'type'} eq 'assembly') {
#		$asm = $pog->{'assembly'};
#		}
#
#	## $asm probably looks something like this:
#	## XYZ*123, ABC*1, QWT*3
#	## XYZ*123,ABC*1,QWT*3
#
#	$asm =~ s/[ ]+//gs;	# remove spaces
#	foreach my $pidqty (split(/,/,$asm)) {
#		my ($SKU,$QTY) = split(/\*/,$pidqty);
#		if (not defined $QTY) { $QTY = 1; }
#		$QTY = int($QTY);
#
#		## NOTE: we're calling recram so it doesn't check circular dependencies.
#		$tmpstuff->recram( { product=>$SKU, sku=>$SKU, stid=>$SKU, qty=>int$QTY },is_assembly_cram=>1);
#		$QTY{$SKU} = $QTY;
#		}
#
#	if ($checkinventory) {
#		my ($result) = &INVENTORY::verify_stuff($USERNAME,$tmpstuff);
#		# print STDERR Dumper($USERNAME,$stuff,$result);
#		if (defined $result) {
#			return(undef);
#			}
#		}
#
#	return(\%QTY);
#	}
#





## 
## Call this before you output an option that has $pog->{'inv'}&2 and $mref->{'asm'} ne ''
##		this performs the following actions: 
##			determines if the option can be displayed (all assembly items are in stock)
##				if NO - then sets $mref->{'skip'} to true!
##	
##		computes the total price and total weight
##			computes the price and weight modifiers against the option
##			then sets the price and weight modifiers to add the respective value.
##
##		IF A MERCHANT DOES NOT WANT TO ALTER THE PRICE OR WEIGHT
##			THEN SIMPLY USE A PRICE MODIFIER OF =0 to set the price to zero. 
##		
##		NOTE: with assembly items, it also means it is NOT POSSIBLE to change the product price.	
##			which is fine, because it's reasonable that nobody [sane] will actually ever want to do this.
##			and there is a general conscensus that this was a bad idea anyway.
##	
#**VERIFY
#sub tweak_asm_option {
#	my ($pog,$mref) = @_;
#
#	my $USERNAME = $pog->{'USERNAME'};
#
#	my $asm = $mref->{'asm'};
#
#	require STUFF;
#	## asm is a comma separated list of PID*QTY
#	my $stuff = STUFF->new($USERNAME);	
#	my %QTY = ();
#	$asm =~ s/[ ]+//gs;	# remove spaces
#	foreach my $pidqty (split(/,/,$asm)) {
#		my ($PID,$QTY) = split(/\*/,$pidqty);
#		if (not defined $QTY) { $QTY = 1; }
#		$stuff->legacy_cram( { stid=>$PID, qty=>$QTY });
#		$QTY{$PID} = $QTY;
#		}
#	my ($result) = &INVENTORY::verify_stuff($USERNAME,$stuff);
#	# print STDERR Dumper($stuff,$result,\%QTY);
#	
#
#	my $inv_mode = &ZWEBSITE::fetch_website_attrib($USERNAME,'inv_mode');
#	if (defined $result) {
#		## okay so we failed the inventory check. damn, don't show this option.
#		$mref->{'skip'} = 1;
#		$mref->{'skip_reason'} = join(',',keys %{$result});
#		}
#	else {
#		## okay so lets sum up the prices and weights.
#		my @PIDS = keys %QTY;
#		my $ref = &ZOOVY::fetchproducts_into_hashref($USERNAME,\@PIDS);
#		my $totalprice = 0; my $totalweight = 0;
#		foreach my $pid (@PIDS) {
#			my $prodref = $ref->{$pid};
#
#			if ($inv_mode<=1) {}		## store inventory is disabled, so don't bother checking it.
#			elsif (($prodref->{'zoovy:inv_enable'} & 32)==32) {} 	## product inventory is disabled.
#			elsif (not defined $ref->{$pid}) { $mref->{'skip'} = 2; } ## one of the products doesn't exist!
#			next if ($mref->{'skip'});
#
#			## THOUGHT: eventually we might handle products which have a blank zoovy:base_price differently!
#			$totalprice += sprintf("%.2f",$prodref->{'zoovy:base_price'}*$QTY{$pid}); 
#			$totalweight += (&ZSHIP::smart_weight($prodref->{'zoovy:base_weight'},0)*$QTY{$pid});
#			}
#
#		if ($mref->{'w'} ne '') { 
#			## note: this will NOT work with % or -
#			($totalweight) = &ZOOVY::calc_modifier($totalweight,$mref->{'w'},1);
#			}
#
#		if ($mref->{'p'} ne '') {
#			($totalprice) = &ZOOVY::calc_modifier($totalprice,$mref->{'p'},1);
#			}
#
#		# print STDERR "TOTAL: totalprice:$totalprice / totalweight: $totalweight\n";
#		## SANITY: at this point $totalprice and $totalweight contain the full amount
#		##			 of the assembly.
#		$mref->{'p'} = "+$totalprice";
#		$mref->{'w'} = "+$totalweight"; 
#		}
#
#	return(\%QTY);
#	}


##
## a quicky function to take a modifier (e.g. [+/-][$/%]#.###)
## 	and return if it is a valid number.. we could probably do more validation here (but why?)
##		this way we don't display +$0.00 modifiers for stupid people like satin.
##
#**VERIFY
sub iznonzero {
	my ($mod) = @_;
	if (not defined $mod) { return(0); }
	if ($mod eq '') { return(0); }
	
	$mod =~ s/[^\d\.]+//gs;
	if ($mod == 0) { return(0); }
	return(1); 
	}

##
## Encodes a metaref (the m on an option/value)
##
#**VERIFY
sub encode_meta {
	my ($metaref) = @_;
	my $out = '';
	foreach my $k (keys %{$metaref}) {
		next if ($k =~ /\|/);					# pipes are delimeters,
		next if ($metaref->{$k} =~ /\|/);	# pipes are delimeters
		$out .= $k.'='.$metaref->{$k}."|";
		}
	chop($out);
	return($out);
}


#############################
## sub: use_inventory
##		parameters: reference to a pog struct
##		returns: number of options which have inventory
#**VERIFY
#sub use_inventory {
#	my ($pogsar) = @_;
#
#	my $count = 0;
#	foreach my $pog (@{$pogsar}) {
#		next unless ($pog->{'inv'}>0);
#		$count++;
#		}
#
#	return($count);
#	}


##
## used for type textarea, text, and calendar to assess any fees.
##		returns: 
##
#**VERIFY
sub pog_calc_textfees {
	my ($USERNAME,$pog,$srctxt) = @_;

	if ($srctxt eq '') { return (0,''); }		# no text?? -- so nothing to do.
	if ($srctxt eq '##') { return (0,''); }	# "##" from default_options, ie nothing -- so nothing to do.

	my $feetxt = '';
	my $fee = 0;
	if (($pog->{'type'} eq 'text') || ($pog->{'type'} eq 'textarea')) {
		## TODO: add fee_char fee_line and fee_word code
		if ($pog->{'fee_char'}>0) {
			my $chars = 0;
			foreach my $ch (split(//,uc($srctxt))) { 
				if ($ch =~ /[A-Z0-9]/) { $chars++; }
				}
			$fee += sprintf("%.2f",$pog->{'fee_char'}*$chars);
			$feetxt = "$chars characters ";
			}

		if ($pog->{'fee_word'}>0) {
			my @words = split(/\W+/, $srctxt);
			my $wordcount = scalar(@words);
			$fee += sprintf("%.2f",$pog->{'fee_word'}*$wordcount);
			$feetxt .= "$wordcount words ";
			}

		if ($pog->{'fee_line'}>0) {
			my @lines = split(/[\n\r]+/, $srctxt);
			my $linecount = scalar(@lines);
			$fee += sprintf("%.2f",$pog->{'fee_line'}*$linecount);
			$feetxt .= "$linecount lines ";
			}
		chop($feetxt);
		}

	if ($pog->{'type'} eq 'calendar') {
		## TODO: add fee_rush code.
		# FORMAT: 01/18/2006 
		require Date::Calc;
		my ($srcyear,$srcmonth,$srcday) = Date::Calc::Decode_Date_US($srctxt);

		## added check 2009-02-10
		## invalid date supplied (was causing Delta_Days to bomb)
		if ($srcyear eq '' || $srcmonth eq '' || $srcday eq '') {
			$fee = 0;
			## no rush needed
			if ($pog->{'fee_rush'} eq '') { $feetxt = ''; }
			## this could be an issue, ie invalid date used to bomb, now gives $0 fee
			else { $feetxt = 'Invalid data format'; }
			}

		## valid date
		else {
			my ($days) = Date::Calc::Delta_Days(Date::Calc::Today(),$srcyear,$srcmonth,$srcday);
			# print STDERR "DAYS: $days [$pog->{'rush_days'}]\n";
			if ($days <= $pog->{'rush_days'}) {
				$feetxt = $pog->{'rush_prompt'};
				$fee += $pog->{'fee_rush'}; 
				}
			}
		}

	return($fee,$feetxt);
	}


##############################
##
##	purpose: takes a product hash, and option qualified sku and rebuilds the product values such as base_weight,
##				base_price, and prod_name (plus any other future attributes we might think about changing)
##				this is recusive safe, meaning it serializes the original (un-modified) values in the product so if the
##				same call is made again, with a different sku, or different price, it will always revert back to the
##				original values. 
##				in addition we'll probably eventually make hooks so that these products can't actually be saved to the
##				database (which would stomp the original product's values)
##	returns; nothing!	
#sub apply_options {
#	my ($USERNAME,$sku,$prodref,%options) = @_;
#	require ZSHIP;						## require for smart_weight
#
#	my %result = ();
#
#	my $cache = $options{'cache'};
#	if (not defined ) { $cache = 0; }
#
#	if ($sku !~ /:/) { return(); }		# no new options - bail!
#	my ($product,@sogidval) = split(/:/,$sku);
#
#	## this is loopback recovery. it allows us to call the same function multiple times and preserve the original price and weight
#	if (defined $prodref->{'zoovy:base_price_orig'}) { $prodref->{'zoovy:base_price'} = $prodref->{'zoovy:base_price_orig'}; }
#	if (defined $prodref->{'zoovy:base_weight_orig'}) { $prodref->{'zoovy:base_weight'} = $prodref->{'zoovy:base_weight_orig'}; }
#	if (defined $prodref->{'zoovy:prod_name_orig'}) { $prodref->{'zoovy:prod_name'} = $prodref->{'zoovy:prod_name_orig'}; }
#
#	my %attribs = ( 
#		'zoovy:base_price_orig'=>'zoovy:base_price',
#		'zoovy:base_weight_orig'=>'zoovy:base_weight',
#		'zoovy:prod_name_orig'=>'zoovy:prod_name'
#		);
#	foreach my $k (keys %attribs) {
#		if (defined $prodref->{$k}) {
#			# legacy mode: copy base_price_orig, or whatever back into base_price
#			#	note: it's a bad idea to set base_price_orig in a prodref
#			$result{$attribs{$k}} = $prodref->{$k};
#			}
#		elsif (defined $prodref->{$attribs{$k}}) {
#			# copy base_price into $result 
#			$result{$attribs{$k}} = $prodref->{$attribs{$k}};
#			}
#		else {
#			# uh oh, this field doesn't exist.
#			$result{$attribs{$k}} = '';
#			}
#		# now make a copy of the orig_field so we have a new working copy
#		$result{$k} = $result{$attribs{$k}};
#		}
#
#	if ($result{'zoovy:base_price'} eq '') { $result{'zoovy:base_price'} = 0; }
#	if ($result{'zoovy:base_weight'} eq '') { $result{'zoovy:base_weight'} = 0; }
#	$result{'zoovy:base_weight'} = &ZSHIP::smart_weight($result{'zoovy:base_weight'});
#	$result{'zoovy:pogs_desc'} = '';	# starts off blank
#
#	# my @pogs = &POGS::text_to_struct($USERNAME,$prodref->{'zoovy:pogs'},1,$cache);
#	my @pogs2 = @{&ZOOVY::fetch_pogs($USERNAME,$prodref)};
#
#	$result{'!success'} = 1;
#	foreach my $kv (@sogidval) {
#		my $id = substr($kv,0,2); 
#		my $val = substr($kv,2,4);
#		# print STDERR  "OPT: $kv - id: $id val: $val\n";
#		my $found = 0;
#		foreach my $pog (@pogs2) {
#			next if ($pog->{'id'} ne $id);
#			next if ($pog->{'finder'}>0);
#			next if ($pog->{'type'} eq 'attribs');	## type "attribs" is used in FINDERS and has no properties.
#			next if ($pog->{'type'} eq 'assembly');	## type "attribs" is used in FINDERS and has no properties.
#
#			foreach my $opt (@{$pog->{'@options'}}) {
#				next if ($opt->{'v'} ne $val);
#				$found++;
#				# if (($pog->{'inv'} & 2) && ($opt->{'asm'} ne '')) { &tweak_asm_option($pog,$opt); }
#				next if ($opt->{'skip'});
#
#				if ($opt->{'p'} ne '') {
#					## if merchant didn't use a '+', '-' or '=' default to '='
#					if(substr($opt->{'p'},0,1) ne '+' && substr($opt->{'p'},0,1) ne '-') {
#						$opt->{'p'} = "=".$opt->{'p'};
#						}
#					my ($diff) = &ZOOVY::calc_modifier($result{'zoovy:base_price'},$opt->{'p'},1);
#					$result{'zoovy:base_price'} = $diff; 
#					}
#				if ($opt->{'w'} ne '') { 
#					## note: this will NOT work with % or -
#					my ($diff) = &ZOOVY::calc_modifier(
#						&ZSHIP::smart_weight($result{'zoovy:base_weight'}),
#						&ZSHIP::smart_weight($opt->{'w'},1),1);
#					$result{'zoovy:base_weight'} = $diff; 
#					}
#
#				$result{'zoovy:prod_name'} .= "\n".$pog->{'prompt'}.': '.$opt->{'prompt'};
#				## pogs_desc can be used by marketplaces (SYNDICATION's) to display option specific data
#				## appended to their own product title. e.g. gbase:prod_name
#				$result{'zoovy:pogs_desc'} .= "\n".$pog->{'prompt'}.': '.$opt->{'prompt'};
#				}
#			}
#
#		if (not $found) {
#			$result{'!success'} = 0;
#			$result{'!err'} = "variation $kv is invalid.";
#			}
#		}
#	
#	if ((not $options{'result'}) || ($options{'result'} == 0)) {
#		warn "POGS::apply_options is using legacy response format, please upgrade!\n";
#		## legacy mode: no result, we copy result over product if success
#		if ($result{'!success'}) {
#			foreach my $k (keys %result) {
#				next if (substr($k,0,1) eq '!');	# skip !success,!err
#				$prodref->{$k} = $result{$k};
#				}
#			}
#		}
#	elsif ($options{'result'}==1) {
#		return(\%result);
#		}
#	else {
#		warn "POGS::apply_options requested unknown response format!\n";
#		}
#
#	}
#
#
#

##############################
##
## #**VERIFY
## pog_modifier_clean (borrowed from ZSKU)
## purpose: Takes a pog modifier (increase/decrease by percentage or dollar amount) and get it ready for output
## returns: -20%   +$5.00   +100%  -$.99
##
##############################
#**VERIFY
sub pog_price_modifier_clean {
	my ($modifier) = @_;
	return '' unless (defined($modifier) && $modifier);
	my $type = (index($modifier, '%') >= 0) ? '%' : '$' ;
	my $sign = '';
	if (index($modifier, '-') >= 0) { $sign = '-'; }
	if (index($modifier, '+') >= 0) { $sign = '+'; }
	$modifier =~ s/[^\d\.]//g;
	if ($type eq '$') { return $sign.'$'. sprintf("%.2f",$modifier); }
	elsif ($type eq '%') { return $sign.$modifier.'%'; }
	return '';
}


##
## #**VERIFY
## parse_meta
## PURPOSE: accepts key1=val1|key2=val2|key3=val3
## RETURNS: { $key1=>$val1, key2=>val2, key3=>val3 }
#**VERIFY
#sub parse_meta {
#	my ($meta, $ref) = @_;
#
#	if (not defined $ref) { $ref = {}; }
#
#	foreach my $o (split(/\|/,$meta)) {
#		my ($k,$v) = split(/=/,$o,2);
#		$ref->{$k} = $v;
#		}
#
#	return($ref);
#	}

##
## Notes about POGs 2.0:
##		two letter ID for each POG - codes must be UPPER CASE
##			00-ZZ = storewide option group ($0-$Z = 62 maximum storewide)
##			#0-#Z = this is a "product specific" group -- product specific are non-reportable (like pog 1.0s)
##			$0-$Z = package specific sogs (system defined and maintained)
##		Checkboxes (type="cb") must have ON and NO 
##
# <zoovy:pogs>
#		<pog id="$Z" prompt="pretty name" inv="1" type="radio|cb|attribs|text|select">
#			<option v="CODE A-Z|0-9" m="p-5|w=6">Prompt</option>
#			<option v="CODE A-Z|0-9" m="p-5|w=6">Prompt</option>
#		</pog>
#		<pog id="$X" prompt="pretty name x" inv="1" type="radio|cb|attribs|text|select">
#			<option v="CODE A-Z|0-9" m="p-5|w=6">Prompt</option>
#			<option v="CODE A-Z|0-9" m="p-5|w=6">Prompt</option>
#		</pog>
# </zoovy:pogs>
##		
##			




##
##	this function contains lots of bad voodoo!
##
## POGSTXT is the text based version of the pogs
## INVSKU is the :#Z00:00AA syntax (returned as INV_SKU portion of STID)
##
#sub validate_invsku {
#	my ($USERNAME,$prodref,$INVSKU) = @_;
#
#	my $pogs2 = &ZOOVY::fetch_pogs($USERNAME,$prodref);
#
#	my $result = 0;		# this is consider success! (we'll flip it later)
#
#	## 
#	## step1: build a hashref keyed by option code e.g. #Z=>00,#Y=>AA .. you get the idea.
#	my %opts = ();
#	foreach my $kv (split(/\:/,$INVSKU)) {
#		next if ($kv eq '');
#		my $k = substr($kv,0,2);
#		my $v = substr($kv,2,2);
#		$opts{$k} = $v;
#		}
#	
#	## now go through each pog, one by one.
#	foreach my $pog (@{$pogs2}) {
#		my $id = (defined $pog->{'id'})?$pog->{'id'}:'';
#		if ($id !~ m/^[\$\#A-Z0-9][A-Z0-9]$/) { $result = 1; }		# wow. corrupt pog in product!
#
#		next if (not $pog->{'inv'}); 											# skip non inventoriable options!
#		next if ($result > 0);													# if we've already got an error, then bail!
#
#		if (defined $opts{$pog->{'id'}}) {									# check to see if this inv opt was passed to func. (if not thats an error)
#			$result = 2;															# assume we won't find shit.
#			foreach my $opt (@{$pog->{'@options'}}) {						# hunt through each pog, look for a success!
#				next if ($opt->{'v'} ne $opts{$pog->{'id'}});		
#				$result = 0;														# yippie-- now wash, rinse, repeat.
#				}	
#			}
#		else {
#			$result = 3; # option does not exist.							# shit, this wasn't passed in $INV_SKU
#			}
#		delete $opts{$pog->{'id'}};											
#		}
#	
##	print STDERR "RESULT: $result\n";
##	use Data::Dumper; print STDERR Dumper(\%opts);
#	if (scalar keys %opts) { $result = 4; }								# we had left over options!
#	
##	print STDERR "RESULT: $result\n";
#
#	## NOTE: we flip $result so true is false and false is true!
#	return(not $result);
#}
#
#
###
## NOTE: USERNAME IS REQUIRED! - else we can't resolve sogs!
## options is a hashref keyed by pog/sog id - and value is the value e.g. #Z=>00
##
#**VERIFY
sub describe_selected_options
{
	my ($USERNAME,$pogs_text, $options,$cache) = @_;
	my $desc = '';
	my $error = '';
	foreach my $pog (text_to_struct($USERNAME,$pogs_text,1,$cache)) {
		my $id = (defined $pog->{'id'})?$pog->{'id'}:'';
		if ($id !~ m/^[\$\#A-Z0-9][A-Z0-9]$/) {
			$error = "Invalid pog ID $id";
			last;
			}
		elsif (defined $options->{$id}) {
			my $value = $options->{$id};
			my $value_pretty = $value;
			my $prompt = $pog->{'prompt'};
			foreach my $opt ($pog->{'@options'}) {
				next unless ($opt->{'v'} eq $value);
				my $value_pretty = $opt->{'prompt'};
				}
			if ($pog->{'type'} eq 'cb') {
				if (($pog->{'optional'}>0) && ($value eq 'NO')) {
					## it's optional, and so shouldn't be included if not selected.
					}
				elsif (($value ne 'ON') && ($value ne 'NO')) {
					$error = "Pog mismatch - badly formatted pog value $value for pog ID $id ($prompt) checkboxes can only have ON and NO";
					last;
					}
				if ($value eq 'ON') { $value_pretty = 'Yes'; } else { $value_pretty = 'No'; }
				}
			$desc .= " / $prompt: $value_pretty";
			}
		elsif ($pog->{'optional'} == 1) {
			## this pog is optional, and probably wasn't selected.
			}
		else {
			$error = "Unable to find selected value for pog $id";
			last;
			}
		}
	return ($desc, $error);
}

######################################################
##
## NAME: build_sku_list
##
## purpose: returns an array reference to sku's which have inventory tracking enabled.
## returns: a hashref key = SKU:IDVV:IDVV value = pretty option name, undef on error
##
## 	OPTS: is a bitwise operator
##			1 - only include inventory enabled options
##			2 - "BRIEF" output displays only value prompt e.g. normal text is "T-Shirt Size: Large" => "Large"
##
#**VERIFY
sub build_sku_list {
	my ($PRODUCT,$POGSREF,$OPTS) = @_;
	
	use Data::Dumper;
	my %ar = ();
	$ar{$PRODUCT} = '';
	
	foreach my $pog (@{$POGSREF}) {
#		print Dumper($pog);
		next if (($OPTS&1) && (($pog->{'inv'}&1)!=1));		# inv can be +2 with assembles
		next if ($pog->{'type'} eq 'attribs');
		my %new = ();
		my $CODE = $pog->{'id'};
		foreach my $option (@{$pog->{'@options'}}) {
			foreach my $sku (keys %ar) {
				## nasty line, produces:
				##	 if brief ($OPT&2)	PRODUCT:IDVV:IDVV => 'IDprompt: VVprompt / IDprompt: VVprompt'
				##  if not brief			PRODUCT:IDVV:IDVV => 'VVprompt / VVprompt'
				$new{$sku.':'.$CODE.$option->{'v'}} = (($ar{$sku} ne '')?$ar{$sku}.' / ':'').((($OPTS&2)==0)?$pog->{'prompt'}.': ':'').$option->{'prompt'};
				}
			}
		%ar = %new;
		}

	## 10,000 options should be more than anybody needs! (note -it's not using "keys" below)
	if (scalar(%ar)>20000) {
		my %blank = ();
		return(\%blank);
		}

	return(\%ar);
}


######################################################
##
## NAME: find_next_available_id
## 	note: quick utility function
##
## purpose: returns the next local e.g. "#Z" pog
## returns: a scalar with the id, undef on error
##
sub find_next_available_pog_id { my ($pogsref) = @_; my $result = undef;	my @ids = ('0'..'9','A'..'Z'); foreach my $id (@ids) { next if (&POGS::find_pog_in_pogs($pogsref,'#'.$id)); $result = '#'.$id; } return($result); }

######################################################
##
## NAME: find_pog_in_pogs 
## 	note: quick utility function
##
## purpose: returns a specific pog from a list of pogs
## returns: a hashref that points at a specific pog, undef on error
##
sub find_pog_in_pogs { my ($pogsref,$id) = @_; $id = uc($id); my $result = undef; foreach my $pog (@{$pogsref}) { if ($pog->{'id'} eq $id) { $result = $pog; } } return($result); }


######################################################
##
## NAME: list_sogs
##
## purpose: returns a list of sogs available to a store.
## returns: a hash keyed by ID
##
sub list_sogs {
	my ($USERNAME,%options) = @_;
	my %soglist = ();

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select SOGID,NAME from STORE_OPTIONGROUPS where MID=$MID /* $USERNAME */";
	if ($options{'name'}) {
		$pstmt .= " and NAME=".$udbh->quote($options{'name'});
		}
	# print STDERR $pstmt."\n";


	my ($sth) = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($ID,$NAME) = $sth->fetchrow() ) {
		$soglist{$ID} = $NAME;
		}
	$sth->finish();
	&DBINFO::db_user_close();

	return(\%soglist);
}


##
##
##
sub load_sogref {
	my ($USERNAME,$SOGID) = @_;

	## SOGID's are always two characters (we can discard and 00-xyzcrap)
	$SOGID = substr($SOGID,0,2);

	my $REF = undef;
	my $content = undef;

	if ($POGS::SOG_CACHE{"$SOGID.$USERNAME"}) {
		# print STDERR "READING IN MEMORY $SOGID.$USERNAME $$\n";
		$REF = Clone::clone($POGS::SOG_CACHE{"$SOGID.$USERNAME"});
		}

	my $cachefile = undef;
	if (not defined $REF) {
		## the cachefile checks the disk, so we don't even bother looking for the cachefile if we already got this in memory.
		$cachefile = &ZOOVY::cachefile($USERNAME,"SOG-$SOGID.yaml");
		}

	if (defined $REF) {
		## already got a reference, nothing to see here.
		}
	elsif (-f $cachefile) {
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($cachefile);
		if ($mtime<=&ZOOVY::touched($USERNAME)) {
			## cache dirty, do not use.
			}
		else {
			## read in file from cache.
			# print STDERR "READING $cachefile FROM CACHE $$\n";
			$REF = YAML::Syck::LoadFile($cachefile);
			$POGS::SOG_CACHE{"$SOGID.$USERNAME"} = $REF;
			}
		}

	
	if (defined $REF) {
		## already got here.
		}
	else {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		my $pstmt = "select YAML from STORE_OPTIONGROUPS where MID=$MID /* $USERNAME */ and SOGID=".$udbh->quote($SOGID);
		my ($YAML) = $udbh->selectrow_array($pstmt);
		if ($YAML ne '') {
			## yay, successful decode.
			$REF = YAML::Syck::Load($YAML);
			}
		&DBINFO::db_user_close();
	
		YAML::Syck::DumpFile($cachefile, $REF);
		chmod(0666,$cachefile);

		$POGS::SOG_CACHE{"$SOGID.$USERNAME"} = $REF;
		}

	return($REF); 
	}


######################################################
##
## NAME: load_sog
##
## purpose: returns the content of a SOG (by ID)
## returns: xml content, or undef on error
##
## NOTE: eventually we'll build in a check by SOGNAME - this will be A LOT faster!
##
#sub load_sog {
#	my ($USERNAME,$SOGID) = @_;
#
#	warn "$USERNAME $SOGID still using load_sog (deprecated)\n";
#	if (not defined $POGS::SOG_CACHE{"$USERNAME-$SOGID"}) {
#		my ($ref) = &POGS::load_sogref($USERNAME,$SOGID);
#		($ref) = @{&POGS::downgrade_struct([$ref])};
#		$POGS::SOG_CACHE{"$USERNAME-$SOGID"} = &POGS::struct_to_text([$ref]);
#		}
#
#	return($POGS::SOG_CACHE{"$USERNAME-$SOGID"});
#	}

#sub load_sog {
#	my ($USERNAME,$SOGID,$SOGNAME,$cache) = @_;
#	
#	print STDERR "LOAD_SOG: $SOGID,$SOGNAME CACHE: $cache\n";
#	if (not defined $cache) { $cache = 0; }	# do not cache
#
#	my $content = undef;
#	my $cachefile = &ZOOVY::cachefile($USERNAME,"$SOGID.xml");
#	if ($cache>0) {
#		print STDERR "CACHE: $cache\n";
#		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($cachefile);
#		if ($mtime<=$cache) {
#			$cache = 1;
#			}
#		else {
#			## read in file from cache.
#			print STDERR "READING $cachefile FROM CACHE\n";
#			open F, "<$cachefile"; $/= undef; $content = <F>; $/ = "\n"; close F;
#			$cache = 0;
#			}
#		}
#
#	my $path = &ZOOVY::resolve_userpath($USERNAME).'/SOGS';
#
#	if (defined $content) {  }
#	elsif ((not defined $SOGNAME) || ($SOGNAME eq '')) {
#		## if we don't know the SOGNAME, try a shortcut lookup.
#		print STDERR "ATTEMPTING: $path/_$SOGID.xml\n";
#		if (-e "$path/_$SOGID.xml") {
#			print STDERR "Found file to get content: $path/_$SOGID.xml\n";
#			open F, "<$path/_$SOGID.xml"; $/ = undef; $content = <F>; $/ = "\n"; close F;
#			}
#		}
#	elsif (defined $SOGNAME) {
#		if (-f "$path/$SOGID-$SOGNAME.xml") {
##			my ($package,$file,$line,$sub,$args) = caller(1);
##			open F, ">>/tmp/sogs.log";
##			print F "$0 $$ ($package,$file,$line,$sub,$args)\n";
##			close F;			
##			print STDERR "READING $path/$SOGID-$SOGNAME.xml FROM DISK\n";
#			open F, "<$path/$SOGID-$SOGNAME.xml"; $/ = undef; $content = <F>; $/ = "\n"; close F;
#			}
#		}
#
#
#
#	if (defined $content) {}
#	elsif (-d $path) {
#		my @SYMLINKS = ();
#		my $D = undef;
#		opendir $D, $path;
#		while ( my $file = readdir($D)) {
#			next if (substr($file,0,1) eq '_');	# skip _A5.xml symlinks
#			next unless ($file =~ /^$SOGID\-.*?\.xml$/);
#			print STDERR "Opening file: $path/$file\n";
#			open Fz, "<$path/$file" || die("Could not open $file"); 
#			$/ = undef; 
#			while (<Fz>) { $content .= $_; }
#			$/ = "\n"; 
#			close Fz;
#			push @SYMLINKS, [ $file, "_$SOGID.xml" ];
#			}
#		closedir($D);
#
#		if (scalar(@SYMLINKS)>0) {
#			my $pwd = sprintf("%s",`pwd`); 
#			chomp($pwd);
#			chdir("$path"); 
#			foreach my $fileset (@SYMLINKS) {
#				symlink($fileset->[0],$fileset->[1]); 
#				}
#			chdir($pwd);
#			}
#		}
#
#	if (($content ne '') && ($cache==1)) {
#		## NOTE: make sure we disable $cache if we loaded from cache
#		open F, ">$cachefile";	print F $content; close F;
#		}
#
##	print STDERR "CONTENT: $content\n";
#	return($content);
#	}
#

##
##
##
sub next_available_sogid {
	my ($USERNAME) = @_;
	## we need to find the next available ID
	my $COUNTER = 0;
	$COUNTER = 360;
	my $soglistref = &list_sogs($USERNAME);
	while (defined $soglistref->{&base36($COUNTER)}) {
		$COUNTER++;
		}

	my $ID = undef;
	my $output = '';
	if ($COUNTER > (36*36)) {
#		print STDERR "ERROR: POG counter of $COUNTER is greater than 36^2\n";
		$ID = undef;
		}
	else {
		$ID = &base36($COUNTER);
		}
	return($ID);
	}

##
##
##
sub store_sog {
	my ($USERNAME,$sog,%options) = @_;

	if ($options{'new'}==0) {
		## don't allow us to create/register new sog id's
		}
	elsif (not defined $sog->{'id'}) {
		$sog->{'id'} = &POGS::next_available_sogid($USERNAME);
		}

	if ($sog->{'v'}<2) {
		warn "upgrading sog $sog->{'id'} in store_sog\n";
		($sog) = @{&POGS::upgrade_struct([$sog])};
		}

	my $SOGID = $sog->{'id'};

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $YAML = YAML::Syck::Dump($sog);
	my $pstmt = &DBINFO::insert($udbh,'STORE_OPTIONGROUPS',{
		'INPUT_TYPE'=>$sog->{'type'},
		'IS_INV'=>int($sog->{'global'}),
		'IS_GLOBAL'=>int($sog->{'inv'}),
		'MID'=>$MID,'USERNAME'=>$USERNAME,'SOGID'=>$SOGID,'NAME'=>$sog->{'prompt'},'YAML'=>$YAML,'V'=>$sog->{'v'},
		},sql=>1,key=>['SOGID','MID']);
	print STDERR "$pstmt\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();	

	&ZOOVY::touched($USERNAME,1);
	%POGS::SOG_CACHE = ();

	## make sure we don't accidentally cache on disk.
	my $cachefile = &ZOOVY::cachefile($USERNAME,"SOG-$SOGID.yaml");
	unlink($cachefile);

	return($sog);
	}

######################################################
##
## NAME: register_sog (replaced with store_sog)
##
## purpose: returns a list of sogs available to a store.
## returns: a SOG ID
##
#sub register_sog {
#	my ($USERNAME,$ID,$NAME,$CONTENTS) = @_;
#
#	## no name, no love!
#	if ($NAME eq '') { return('');  }
#	$NAME =~ s/[^\w]+/_/g;
#	$NAME = lc($NAME);
#
#	## first thing we do is find the next available sog
#	my $path = &ZOOVY::resolve_userpath($USERNAME).'/SOGS';
#	mkdir($path);
#	chmod 0777, $path;
#	my $output = undef;
#	
#	my $soglistref = &list_sogs($USERNAME);
#	
#	if (not defined $ID) {
#		$ID = &POGS::next_available_sogid($USERNAME);
#		}
#	else {
#		## ID is already defined - kill the existing file!
#		&POGS::kill_sog($USERNAME,$ID);
#		}
#
#	if (defined $ID) {
#		open F, ">$path/$ID-$NAME.xml";
#		print F $CONTENTS;
#		close F;
#		$output = "<pog type=\"sog\" id=\"$ID\" sog=\"$ID-$NAME\"></pog>";
#
#		my $pwd = sprintf("%s",`pwd`); chomp($pwd);
#		chdir("$path"); symlink("$ID-$NAME.xml","_$ID.xml"); chdir($pwd);
#		}
#
#	&ZOOVY::touched($USERNAME,1);
##	&POGS::update_cdb($USERNAME);
#
#	return($ID,$output);	
#}


######################################################
##
## NAME: kill_sog
##
## purpose: returns a list of sogs available to a store.
## returns: nothing
##
#**VERIFY
sub kill_sog {
	my ($USERNAME,$SOGID) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "delete from STORE_OPTIONGROUPS where MID=$MID /* $USERNAME */ and SOGID=".$udbh->quote($SOGID);
	$udbh->do($pstmt);
	&DBINFO::db_user_close();

#	## legacy - remove old sog reference as well
#	my $path = &ZOOVY::resolve_userpath($USERNAME).'/SOGS';
#	my $listref = &list_sogs($USERNAME);
#	my $NAME = $listref->{$SOGID};
#	&DEBUG && &msg("kill_sog: KILLING: $path/$SOGID-$NAME.xml!");
#	unlink("$path/$SOGID-$NAME.xml");

#	&ZOOVY::touched($USERNAME,1);
#	&POGS::update_cdb($USERNAME);

	return();
	}


######################################################
##
## NAME: base36
##
## purpose: converts a number, to an option code (base 36) representation e.g. 0 = 00, 10 = 0A, 17 = 0G
##
#**VERIFY
sub base36 {
	my ($NUM) = @_;

	my @vals = ('0'..'9','A'..'Z');
	my $result = '';
	$result = $vals[int($NUM / 36)].$vals[int($NUM % 36)];
	$result = uc($result);
	return($result);
}

######################################################
##
## NAME: unbase36
##
## purpose: converts a base36 representation into a number
##
#**VERIFY
sub unbase36 {

	my ($base36) = @_;

	return unless ($base36 =~ m/^([A-Z0-9])([A-Z0-9])?$/);

	my $digit1 = $1;
	my $digit2 = $2;

	my %vals = ();
	my $count = 0;
	foreach ('0'..'9','A'..'Z') { $vals{$_} = $count; $count++; }

	my $num = 0;
	if (defined $digit2) {
		$num = ($vals{$digit1} * 36) + $vals{$digit2};
		}
	else {
		$num = $vals{$digit1};
		}
	return $num
}


##
##
##
#**VERIFY
sub upgrade_struct {
	my ($struct1) = @_;

#	if (not defined $struct1->{'v'}) {
#		$struct1->{'v'} = 1;
#		}
#
#	if ($struct1->{'v'} == 2) {
#		warn "attempted to upgrade v2 pog\n";
#		return($struct1);
#		}

	if (not defined $struct1) {
		return(undef);
		}

	if (ref($struct1) ne 'ARRAY') {
		Carp::cluck("should not call upgrade_struct with non-array ref");
		}

	my $struct2 = Clone::clone($struct1);
	#<pog id="#Z" prompt="Size" inv="1" type="select" iname="1318257428" goo="" ghint="">
	#<option v="00">small</option>
	#<option v="01">medium</option>
	#<option v="02">large</option>
	#</pog>
	foreach my $og (@{$struct2}) {
		if (not defined $og->{'v'}) { $og->{'v'} = 1; }
		next if ($og->{'v'} == 2);
		$og->{'v'} = 2;		

		if ($og->{'options'}) {
			$og->{'@options'} = $og->{'options'};
			delete $og->{'options'};
			foreach my $opt (@{$og->{'@options'}}) {
				if (defined $opt->{'m'}) {
					my $kv = &POGS::parse_meta($opt->{'m'});
					delete $opt->{'m'};
					foreach my $k (keys %{$kv}) {
						next if (not defined $kv->{$k});
						next if ($kv->{$k} eq '');
						$opt->{$k} = $kv->{$k};
						}
					}
				}
			}
		}

	return($struct2);
	}

#**VERIFY
sub downgrade_struct {
	my ($struct2) = @_;

#	if (not defined $struct2->{'v'}) {
#		$struct2->{'v'} = 1;
#		}
#
#	if ($struct2->{'v'} == 1) {
#		warn "attempted to downgrade v1 pog\n";
#		return($struct2);
#		}

	my $struct1 = Clone::clone($struct2);
	foreach my $og (@{$struct1}) {
		if (not defined $og->{'v'}) { $og->{'v'} = 1; }
		next if ($og->{'v'} == 1);
		$og->{'v'} = 1;

		if ($og->{'@options'}) {
			$og->{'options'} = $og->{'@options'};
			delete $og->{'@options'};
			foreach my $opt (@{$og->{'options'}}) {
				my %meta = ();
				foreach my $k (keys %{$opt}) {
					if ($k eq 'prompt') {
						## leave it alone
						}
					elsif ($k eq 'v') {
						## leave it alone
						}
					else {
						$meta{$k} = $opt->{$k};
						delete $opt->{$k};
						}
					}
				if (scalar(keys %meta)>0) {
					$opt->{'m'} = &POGS::encode_meta(\%meta);
					}
				}
			}
		}

	return($struct1);
	}

	
######################################################
##
## NAME: text_to_struct
##
## purpose: takes a text pog, converts into a memory struct.
## returns: an array of hashes
## sample result:
## @ar = [
##		{ 'type'=>'...
##		];
##
#**VERIFY
sub text_to_struct {
	my ($USERNAME, $pogtext, $resolve_sogs,$cache_ts) = @_;

	if ($cache_ts==1) { $cache_ts = &ZOOVY::touched($USERNAME); }

	## cache should be the timestamp that should be greater
	&DEBUG && &msg("text_to_struct: $pogtext resolve_sogs=[$resolve_sogs]");

	my @struct = ();
	## Loop through all the <pogs></pogs> and get the attribs/contents
	while ($pogtext =~ s/<pog(\s.*?)>(.*?)<\/pog>//is) {
		my $attribs = $1;
		my $options = $2;
		my %pog = ();
		$pog{'USERNAME'} = $USERNAME;

		## a="b" c="d" 
		while ($attribs =~ s/\s+(\w+)\=\"(.*?)\"/ /is) {
			## next unless def($2); 
			$pog{$1} = ZTOOLKIT::decode($2);
			}
		my @opts = ();
		while ($options =~ s/<option(\s+.*?)>(.*?)<\/option>//is) {
			my %opt = ();
			my $option_attribs = $1;
			$opt{'prompt'} = ZTOOLKIT::decode($2);
			if ($opt{'prompt'} eq '') { delete $opt{'prompt'}; }
			while ($option_attribs =~ s/\s+(\w+)\=\"(.*?)\"/ /is) {
				## next unless def($2); ## <-- very bad, inv=0 would be UNDEF/NOT SET
				$opt{$1} = ZTOOLKIT::decode($2);
				}
			push @opts, \%opt;
			}


		## hmm... 

		# if ( ($pog{'type'} eq 'sog') && (defined $pog{'sog'}) && $resolve_sogs) {
		if ( (defined $pog{'sog'}) && $resolve_sogs) {


			## The purpose of resolve sogs is to trick the next layer up the chain (whatever that may be) into thinking that
			## a sog is really a pog.. since the rules for handling them are the same, everything SHOULD be fine.
         my $sogref = $POGS::SOG_CACHE{$pog{'sog'}.$USERNAME};
			#if ($USERNAME eq 'kyledesign') {
			#	## 9/8/11 - think an issue related to kyle's options not having modifiers might be related 
			#	$sogref = undef;
			#	}

			if (not defined $sogref) {
				my ($sogid,$sogname) = split(/-/,$pog{'sog'});		# by default it should just be "ID" but it could also be "ID-NAME"
	        	# my @sogs = &POGS::text_to_struct($USERNAME,&POGS::load_sog($USERNAME,$sogid,$sogname,$cache_ts),0,$cache_ts);
		      # $sogref = pop @sogs;
				($sogref) = @{&POGS::downgrade_struct([&POGS::load_sogref($USERNAME,$sogid)])};
          	$sogref->{'id'} = $sogid; 	# sometimes sogs get written with funny (as in wrong) id's - this ensures they match up!
				$POGS::SOG_CACHE{$pog{'sog'}.$USERNAME} = $sogref;
				}

			if ($pog{'type'} eq 'sog') {
				## holy batshit batman! better not use this type (hopefully the sog contains something more reasonable) 
				$pog{'type'} = $sogref->{'type'};
				}

			## basically, the REMAINDER of a SOG whalefucks a POG..
			foreach my $k (keys %{$sogref}) {
				## this line lets the product override the type
				## 	e.g. so one product can be "attribs" and the other can be "select" or "radio" or something
				next if ($k eq 'type');
				## we should also ALWAYS use the products inventoriable mode (again, in some cases the options might be
				##	inventoriable on a specific product, but not on other products
				next if ($k eq 'inv');

				$pog{$k} = $sogref->{$k};
				}
			## if it's global, we keep the SOG options
			## otherwise we replace them with the local copy.
			if ($sogref->{'global'}==0) {
				$pog{'options'} = \@opts;
				}
			## SANITY: at this point the only way you can know it's a sog is if you're looking at the $pog{'sog'} key!
			}
		elsif (scalar @opts) {
			## this is not a sog, or resolve sogs isn't on!
			$pog{'options'} = \@opts;
			}

		push @struct, \%pog;

	}

	return (@struct);
}

######################################################
##
## NAME: struct_to_text
##
## purpose: takes a struct created by "text_to_struct" and creates the text representation
##		probably for storage into the product, or SOG
##	returns: xmlish-text
##
#**VERIFY
sub struct_to_text {
	my ($struct) = @_;

	if (ref($struct) ne 'ARRAY') {
		Carp::cluck("struct_to_text must be called with array ref");
		}

	my $count = 0;

	my $text = '';
	foreach my $pog (@{$struct}) {
		my $attribs = '';

		$pog->{'id'} = (defined $pog->{'id'})?$pog->{'id'}:'';
		if ($pog->{'id'} eq '') {
			$pog->{'id'} = base36($count);
			$pog->{'id'} =~ s/^0/#/;
			$count++;
			if ($count > 36) { die "Options only allows 36 auto-generated POG IDs"; }
			}
		next unless ($pog->{'id'} =~ m/^[\$\#A-Z0-9][A-Z0-9]$/);

		$pog->{'type'} = (defined $pog->{'type'})?$pog->{'type'}:'';

		## NOTE: $pog->{'sog'} should ALWAYS be undefined -- thats really bad if it isn't.
		# $pog->{'sog'} = (defined $pog->{'sog'})?$pog->{'sog'}:'';
		if ((defined $pog->{'sog'}) && ($pog->{'sog'} eq '')) { delete $pog->{'sog'}; }	# blank is not the same as undef.

		unless ($pog->{'type'} =~ m/^(text|cb|radio|select|textarea|biglist|imgselect|imggrid|calendar|number|readonly|attribs|assembly|hidden)$/) {
			if ((defined $pog->{'sog'}) && ($pog->{'sog'} ne '')) {
				## SOGS don't need a type!
				}
			else {
				## default to text
				$pog->{'type'} = 'text';
				}
			}
		
		if (not defined $pog->{'inv'}) { $pog->{'inv'} = 0; }
		if (($pog->{'type'} eq 'textbox') || ($pog->{'type'} eq 'textarea') || ($pog->{'type'} eq 'readonly') ||
			($pog->{'type'} eq 'text') || ($pog->{'type'} eq 'calendar') || ($pog->{'type'} eq 'number')) {
			$pog->{'inv'} = 0;
			}

		if ($pog->{'type'} eq 'assembly') {
			$pog->{'prompt'} = 'Base Assembly';
			$pog->{'inv'} = 2;
			}

		# an attribute to try and resolve the proper finder values from		
		foreach my $attrib (qw(
			id prompt inv global optional finder type sog maxlength default cols rows iname 
			width amz goo ebay height zoom min max hint ghint oghint flags
			fee_line fee_word fee_char fee_rush rush_msg rush_days rush_prompt img_type 
			debug assembly
			lookup_attrib	
			)) {
			next unless (defined $pog->{$attrib});
			my $value = ZTOOLKIT::encode($pog->{$attrib});
			$attribs .= qq~ $attrib="$value"~;
			}

		my $options = '';
		if (defined $pog->{'options'}) {
			foreach my $option (@{$pog->{'options'}}) {
				my $prompt = &ZTOOLKIT::encode((defined $option->{'prompt'})?$option->{'prompt'}:'');
				$options .= "<option v=\"$option->{'v'}\"";
				if (defined $option->{'m'}) { $options .= qq~ m="$option->{'m'}"~; }
				if (defined $option->{'html'}) { $options .= qq~ html="$option->{'html'}"~; }
				$options .= qq~>$prompt</option>\n~;
				}
			}

		$text .= qq~<pog$attribs>\n$options</pog>\n~;
		}

	return ($text);
}

##############################################################################
## struct_to_html
## Purpose: Turns a pog specification into usable HTML to present to a user
## Accepts: $stuct is an arrayref for the pog
##          $field_suffix is what we put in front of the HTML field name before ID (defaults to 'option_')
##          $selected is a hash, keyed on POG id, with a value of the currently selected value for that pog
##          $context is 0 for product page, 1 for product list.  Nothing is handled different for this, yet.
## Returns: HTML... but no <form...> tag
## CONTEXT is a bitwise
##		1 = toggle product list style (0=page,1=prodlist)
##		2 = enables "simple" mode - for buy me buttons 
##		4 = enables pogwizard mode
##		8 = search indexing mode (e.g. just dumps the plaintext with minimal html output)
##		16 = add to cart
##	
##	INIREF is a set of parameters that tell us how to format the request
##		it could be a fully qualified ADDTOCART element
##

#**VERIFY
sub struct_to_html {
	my ($P, $selected, $context, $stid, $iniref) = @_;

	if (not defined $iniref) { $iniref = {}; }

	my ($pid,$claim,$invopts,$noinvopts,$virtual) = ();
	if (defined $stid) {
		($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($stid);
		}
	
	my $claimpid = $pid;
	if ($claim>0) { $claimpid = $claim.'*'.$claimpid; }
	## At this point $claimpid is 1234*PID

	## We make modifications to the pogs, so this keeps them from affecting things outside of this function
	my @struct_copy = @{$P->fetch_pogs()};

	&DEBUG && &msg(\@struct_copy, '*struct_to_html');

	if ($context == 4) { $context = 0; }
	elsif ($context == 16) { $context = 0; }

	## check to see how many inventoriable pogs we have 
	##	if 1, record it's position
	my $inv_pog = -1;
	my $count = 0;
	if (not defined $pid) { $inv_pog = -3; }	# product_id not set, can't do inventory
	else {
		foreach my $pog (@struct_copy) {
			next if ($inv_pog == -2);	# -2 means more than one inventoriable pog
			if ($pog->{'inv'}>0) { 
				if ($inv_pog>-1) { $inv_pog = -2; }	# set to -2 since we've already found one.
				else { $inv_pog = $count; }			# hurrah, the first one.
				}
			$count++;
			}
		}

	#if ($inv_pog>=0) {
	#	## check to see if we have unlimited inventory!
	#	my $inv_enable = 0;
	#	if (defined $P->fetch('zoovy:inv_enable')) {
	#		$inv_enable = $P->fetch('zoovy:inv_enable');
	#		}
	#	if (($inv_enable & 32)==32) { $inv_pog = -3; }	# turns out this has unlimited inventory
	#	if (($claim==0) && (($inv_enable & 1024)==1024)) { $claim = 1; }	# turns out this is really a claim!
	#	}

	my $gref = undef;
	if ($inv_pog>=0) {
		## check to see if we have inventory for internal use
		($gref) = &ZWEBSITE::fetch_globalref($P->username());
		my $inv_mode = $gref->{'inv_mode'};
		if ($inv_mode<2) { $inv_pog = -4; }
		}
	
   if ($inv_pog>=0) {
      ## if we get here, it means we only have one inventoriable pog.
      ## so we go through and check to see which options are and are NOT available.
      my $pog = $struct_copy[$inv_pog];
      my $pogid = (defined $pog->{'id'})?$pog->{'id'}:'';
      my @SKUS = ();
      foreach my $option (@{$pog->{'@options'}}) {
         my $SKU = uc($pid.':'.$pogid.$option->{'v'});
         push @SKUS, $SKU;
         }

		## NOTE: i don't want to rewrite the fetchskus_into_hashref function right now - BH
		# my $SKUSREF = &ZOOVY::fetchskus_into_hashref($P->username(),\@SKUS, { $pid=>$P->dataref() });
      my ($invref,$reserveref) = INVENTORY2->new($P->username(),'%GREF'=>$gref)->fetch_qty('@SKUS'=>\@SKUS,'%PIDS'=>{ $pid=>$P });
		# use Data::Dumper; print STDERR "POGS SKUS: ".Dumper($invref);

      # use Data::Dumper; print STDERR Dumper($pid,\@SKUS,$invref,$reserveref);
      my @options = ();
      foreach my $option (@{$pog->{'@options'}}) {
         my $SKU = uc($pid.':'.$pogid.$option->{'v'});
         if (($invref->{$SKU} - $reserveref->{$SKU}) >0) {
				## hooray, we've got inventory!
            push @options, $option;
            }
			elsif (($claim>0) && ($SKU eq $pid.':'.$invopts)) {
				## we've got a claim, with inventoriable options, so those should always appear
            push @options, $option;
				}
			else {
				## crap, this option won't be making the cut due to inventory
				}
         }
      $struct_copy[$inv_pog]->{'@options'} = \@options;
      }


	## 
	## Build the HTML
	## 

	my $biglists = 0;
	## 
	## PREFLIGHT CHECK, prepares the POGS to be output, this could be done as part of a LIST
	##				or just using the standard HTML output
	foreach my $pog (@struct_copy) {
		&DEBUG && &msg($pog, '*pog');

		$pog->{'USERNAME'} = $P->username();
		$pog->{'PRODUCT'} = $pid;
		$pog->{'CLAIM'} = $claim;
		$pog->{'id'} = (defined $pog->{'id'})?$pog->{'id'}:'';
		$pog->{'type'} = (defined $pog->{'type'})?$pog->{'type'}:'';

		## NOTE: finders must be displayed as a hidden value so we can process them later.
		## next if (int($pog->{'finder'})>0);	# finders can't be displayed in html (at least like this)
		next unless ($pog->{'id'} =~ m/^[\$\#A-Z0-9][A-Z0-9]$/);
		unless ($pog->{'type'} =~ m/^(text|textarea|cb|radio|select|biglist|imgselect|imggrid|readonly|calendar|attribs|hidden|assembly)$/) {
			$pog->{'type'} = 'text';
			}
		if (not defined $pog->{'@options'}) { $pog->{'@options'} = []; }

		$pog->{'selected'} = (defined $selected->{$pog->{'id'}})?$selected->{$pog->{'id'}}:'';
		$pog->{'fieldname'} = 'pog_'.$pog->{'id'};
		$pog->{'cb_fieldname'} = 'pog_'.$pog->{'id'}.'_cb';

		if (($context & 2)==2) {
			## special handling for buy me buttons, convert all text types to text
			## convert all non-text types to selects.
			if (($pog->{'type'} eq 'textarea') || ($pog->{'type'} eq 'text') || ($pog->{'type'} eq 'readonly') || ($pog->{'type'} eq 'calendar')) {
				$pog->{'type'} = 'text'; 
				}
			elsif ($pog->{'type'} eq 'attribs') {
				## finder attributes  should not be converted to select boxes, leave them the fuck alone.
				}
			else {
				$pog->{'type'} = 'select'; 
				}
			if (($context & 1)==0) { $context += 1; }		# enable prod list style!
			}

		if (($context & 1)==1) {
			## prod lists and buy me buttons
			$pog->{'fieldname'} .= ':'.$claimpid;
			$pog->{'cb_fieldname'} .= ':'.$claimpid;			
			}
		}


	##
	## SANITY: at this point, the $pog hashref for each element in @struct_copy is fully formatted and ready
	##			to be run by whatever output method we've got.
	##


	my $html = '';
#	$html .= $iniref->{'POG_HEADER'};

	foreach my $pog (@struct_copy) {
#		$html .= $iniref->{'POG_ROW_HEADER'};

		my $POGID = $pog->{'id'};
		if ($iniref->{'POG_SPEC_'.$POGID}) {
			## okay cool, we've got an overridden SOG here
			## <input type="hidden" name="pog:#Z" value="02">
			## <object flashvars="ID=ID&img1=&img2&img3="></option>
			require TOXML::SPECL;
			$pog->{'OPTIONSTACK'} = &TOXML::SPECL::spush('',@{$pog->{'@options'}});
			delete $pog->{'options'};
			my $SPECL = $iniref->{'POG_SPEC_'.$POGID}; 
			$html .= &TOXML::SPECL::translate2($SPECL, $pog, replace_undef=>0); 
			}
		elsif ($pog->{'type'} eq 'attribs') {
			## we don't output anything for attribs/finder
			}
		elsif ($pog->{'type'} eq 'cb') {
			&DEBUG && &msg('Its a CB');
			$html .= type_cb_to_html($pog, $context);
			}
		elsif ($pog->{'type'} eq 'radio') {
			&DEBUG && &msg('Its a RADIO');
			$html .= type_radio_to_html($pog, $context);
			}
		elsif ($pog->{'type'} eq 'select') {
			&DEBUG && &msg('Its a SELECT');
			$html .= type_select_to_html($pog, $context);
			}
		elsif ($pog->{'type'} eq 'textarea') {
			&DEBUG && &msg('Its a TEXTAREA');
			$html .= type_textarea_to_html($pog, $context);
			}
		elsif ($pog->{'type'} eq 'biglist') {
			&DEBUG && &msg('Its a BIGLIST');
			$html .= type_biglist_to_html($pog, $context, ++$biglists);
			}
		elsif ($pog->{'type'} eq 'imgselect') {
			$html .= type_imgselect_to_html($pog, $context);
			}
		elsif ($pog->{'type'} eq 'imggrid') {
			$html .= type_imggrid_to_html($pog, $context);
			}
		elsif ($pog->{'type'} eq 'readonly') {
			&DEBUG && &msg('Its a TEXT');
			## NOTE: eventually we'll do some substitution here, maybe lookup some flags!
			$html .= $pog->{'default'};
         $html .= qq~<input type="hidden" id="$pog->{'fieldname'}" name="$pog->{'fieldname'}" value="">~;
 			}
		elsif ($pog->{'type'} eq 'assembly') {
         $html .= qq~<input type="hidden" id="$pog->{'fieldname'}" name="$pog->{'fieldname'}" value="">~;
			}
		elsif (($pog->{'type'} eq 'hidden') || ($pog->{'type'} eq 'attribs')) {
         $html .= qq~<input type="hidden" id="$pog->{'fieldname'}" name="$pog->{'fieldname'}" value="$pog->{'default'}">~;
			}
		elsif ($pog->{'type'} eq 'calendar') {
			$html .= &type_calendar_to_html($pog,$context);
			}
		else {
			&DEBUG && &msg('Its a TEXT');
			$html .= type_text_to_html($pog, $context);
			}

#		$html .= $iniref->{'POG_ROW_FOOTER'};
		}	# end of forloop

#	$html .= $iniref->{'POG_FOOTER'};
	&DEBUG && &msg("HTML is $html");

	return $html;
	}



##############################################################################
## type_xxx_to_html
## Purpose: Used by struct_to_html to provide the HTML for a specific POG type
## Accepts: Struct version of the POG, a field suffix, what option is selected,
##          and the numeric context (as listed by struct_to_html)
#**VERIFY
sub type_text_to_html {
	my ($pog, $context) = @_;
	my $out = '';
	$out .= "\n\n<!-- POG $pog->{'id'} (text) -->\n";
	
	$out .= "<b class=\"ztxt pogprompt pogprompt_text\">".$pog->{'prompt'}.":</b> ";
	$out .= qq~<input type="text" name="$pog->{'fieldname'}" ~;
	if ($pog->{'maxlength'}) { $out .= "maxlength=\"$pog->{'maxlength'}\" "; }
	$out .= qq~value="$pog->{'default'}" /><br>\n~;
	if ($pog->{'fee_char'}>0) { $out .= sprintf("+\$%0.2f per character.<br>",$pog->{'fee_char'}); }
	if ($pog->{'fee_word'}>0) { $out .= sprintf("+\$%0.2f per word.<br>",$pog->{'fee_word'}); }
	$out .= qq~<br />\n~;
	return $out;
}



## See type_xxx_to_html header above
sub type_textarea_to_html {
	my ($pog, $context) = @_;
	my $out = '';
	$out .= "\n\n<!-- POG $pog->{'id'} (textarea) -->\n";
	$out .= "
<script language=\"Javascript\" type=\"text/javascript\">
<!-- 
function imposeMaxLength(textField, MaxLength) {
	if(textField.value.length > MaxLength){
		textField.value= textField.value.substring(0,MaxLength);
		textField.blur();
		}
	}
//-->
</script>
";

	$out .= "<table border=0><tr><td class=\"ztxt pogprompt\" valign=top><b class=\"ztxt pogprompt pogprompt_textarea\">".$pog->{'prompt'}.":</b></td> ";
	$out .= qq~<td class="ztxt"><textarea name="$pog->{'fieldname'}"~;
	if ($pog->{'cols'}) { $out .= " cols=\"$pog->{'cols'}\" "; }
	if ($pog->{'rows'}) { $out .= " rows=\"$pog->{'rows'}\" "; }
	
	#if ($pog->{'maxlength'}) { $out .= " maxlength=\"$pog->{'maxlength'}\" "; }
	if ($pog->{'maxlength'}) { $out .= " onKeyUp=\"imposeMaxLength(this,$pog->{'maxlength'})\" "; }
	$out .= qq~>$pog->{'default'}</textarea><br>~;

	if ($pog->{'fee_char'}>0) { $out .= sprintf("+\$%0.2f per character.<br>",$pog->{'fee_char'}); }
	if ($pog->{'fee_word'}>0) { $out .= sprintf("+\$%0.2f per word.<br>",$pog->{'fee_word'}); }
	if ($pog->{'fee_line'}>0) { $out .= sprintf("+\$%0.2f per line.<br>",$pog->{'fee_line'}); }
	if ($pog->{'hint'} ne '') { $out .= $pog->{'hint'}; };
	$out .= qq~\n</td></tr></table><br>\n~;
	return $out;
}

## See type_xxx_to_html header above
#**VERIFY
sub type_cb_to_html
{
	my ($pog, $context) = @_;
	my $checked = ($pog->{'selected'} eq 'ON') ? ' checked' : '';
	my $out = '';
	$out .= "\n\n<!-- POG $pog->{'id'} (cb) -->\n";
	$out .= qq~<input type="hidden" name="$pog->{'cb_fieldname'}" value="1" />\n~;
	$out .= qq~<input type="checkbox" name="$pog->{'fieldname'}" value="ON"$checked /> ~;

	$pog->{'prompt'} = (defined $pog->{'prompt'})?$pog->{'prompt'}:'';
	$out .= "<b class=\"pogprompt pogprompt_cb\">".$pog->{'prompt'}."</b>";
	foreach my $option (@{$pog->{'@options'}}) {
		# my $mref = &POGS::parse_meta($option->{'m'});	
		#if (($pog->{'inv'} & 2) && 
		#	(($option->{'asm'} ne '') || ($pog->{'type'} eq 'assembly'))) { &tweak_asm_option($pog,$option); }
		next if ($option->{'skip'});

		if ((defined $option->{'p'}) && ($option->{'p'} ne '')) { 
			if ($option->{'v'} eq 'ON') {
				$out .= ' '.&POGS::pog_price_modifier_clean($option->{'p'});
				}
			if ($option->{'v'} eq 'NO') {
				$out .= ' (Disable: '.&POGS::pog_price_modifier_clean($option->{'p'}).')';
				}
			} # end price modifier set
		} # end foreach option
	$out .= "<br />\n<br />\n";
	return $out;
}

## See type_xxx_to_html header above
#**VERIFY
sub type_radio_to_html
{
	my ($pog, $context) = @_;
	my $out = '';
	$out .= "\n\n<!-- POG $pog->{'id'} (radio) -->\n";
	$out .= "<b class=\"pogprompt pogprompt_radio\">".$pog->{'prompt'}.":</b> ";
	$out .= "<br />\n";
	my $count = 0;
	foreach my $option (@{$pog->{'@options'}}) {
		my $checked = '';
		if ($pog->{'selected'} eq $option->{'v'}) { $checked = ' checked'; }
		elsif (($pog->{'selected'} eq '') && ($count == 0)) { $checked = ' checked'; }
		$out .= qq~<input type="radio" name="$pog->{'fieldname'}" value="$option->{'v'}"$checked /> ~;
		$out .= (defined $option->{'prompt'})?$option->{'prompt'}:'';
		# my $option = &POGS::parse_meta($option->{'m'});	
		#if (($pog->{'inv'} & 2) && 
		#	(($option->{'asm'} ne '') || ($pog->{'type'} eq 'assembly'))) { &tweak_asm_option($pog,$option); }
		next if ($option->{'skip'});

		if ((defined $option->{'p'}) && ($option->{'p'} ne '')) { 
			$out .= ' '.&POGS::pog_price_modifier_clean($option->{'p'});
			}
		$out .= "<br />\n";
		$count++;
	}
	$out.= "<br />\n";
	return $out;
}

## See type_xxx_to_html header above
#**VERIFY
sub type_select_to_html {
	my ($pog, $context) = @_;
	my $out = '';
	$out .= "\n\n<!-- POG $pog->{'id'} (select) -->\n";
	$out .= "<b class=\"ztxt pogprompt pogprompt_select\">".$pog->{'prompt'}.":</b> ";
	$out .= qq~<select name="$pog->{'fieldname'}">\n~;

	my $count = 0;
	if ($pog->{'optional'}>0) {
		$count++;		## make sure this option defaults to selected, otherwise count=0 will.
		$out .= "<option value=''></option>";
		}
	foreach my $option (@{$pog->{'@options'}}) {
		my $select = '';
		if ($pog->{'selected'} eq $option->{'v'}) { $select = ' selected'; }
		elsif (($pog->{'selected'} eq '') && ($count == 0)) { $select = ' selected'; }

				
		$out .= qq~<option value="$option->{'v'}"$select>~;
		$out .= (defined $option->{'prompt'})?$option->{'prompt'}:'';

		# my $option = &POGS::parse_meta($option->{'m'});	
		#if (($pog->{'inv'} & 2) && 
		#	(($option->{'asm'} ne '') || ($pog->{'type'} eq 'assembly'))) { &tweak_asm_option($pog,$option); }
		next if ($option->{'skip'});

		# if ((defined $option->{'p'}) && ($option->{'p'} ne '') && ($option->{'p'} != 0)) { 
		## NOTE: remember this field is alphanum e.g. -- don't compare +$70.00
		if (( $pog->{'flags'} & 1 ) == 1 ) {
			## don't show modified prices.
			}
		elsif (&POGS::iznonzero($option->{'p'})) { 
			$out .= ' '.&POGS::pog_price_modifier_clean($option->{'p'});
			}
		$out .= qq~</option>\n~;
		$count++;
		}	
	$out .= "</select>";
	if ($pog->{'hint'} ne '') { $out .= $pog->{'hint'}; }
		
	$out .= "<br />\n";
	$out .= "<br />\n";
	return $out;
	}


## See type_xxx_to_html header above
#**VERIFY
sub type_biglist_to_html
{
	my ($pog, $context, $count) = @_;
	my $out = '';
	$out .= "\n\n<!-- POG $pog->{'id'} (biglist) -->\n";

	# $out .= "<pre>".Dumper($pog)."\n\n".Dumper($context)."</pre>";

	my $USERNAME = $pog->{'USERNAME'};

	if ($count==1) {
		$out .= qq~
		<SCRIPT src="/media/graphics/general/DynamicOptionList.js?v=20080223"></SCRIPT>
		~;
		}

	my $fieldName2 = $pog->{'fieldname'};
	my $fieldName1 = $pog->{'fieldname'}.'skip';
	my $jsVar = $pog->{'fieldname'};
	$jsVar =~ s/[\W]+//gs;

	# $out .= "JSVAR [$jsVar]\n";

	$out .= "<b class=\"pogprompt pogprompt_biglist\">".$pog->{'prompt'}.":</b> ";
	$out .= qq~<select name="$fieldName1">\n~;
	## go through and find level 1 options
	my %level1 = ();
	foreach my $option (@{$pog->{'@options'}}) {
		my ($opt1,$opt2) = split(/\|/,$option->{'prompt'});
		next if (defined $level1{$opt1});
		$out .= "<OPTION VALUE=\"$opt1\">$opt1</OPTION>";
		$level1{$opt1}++;
		}
	$out .= qq~</select>\n~;
	## note: level2 is created blank. - it is populated by initDynamicMenu later on.
	$out .= qq~<select name="$fieldName2">\n~;
	$out .= qq~</select>\n~;

	## now - go through and setup javascript variables for level2
	$out .= "<SCRIPT LANGUAGE=\"JavaScript\">\n<!--\n";
	$out .= "var $jsVar = new DynamicOptionList();\n";
	$out .= "$jsVar.addDependentFields(\"$fieldName1\",\"$fieldName2\");\n";
	$out .= "$jsVar.selectFirstOption = false;\n";

	foreach my $option (@{$pog->{'@options'}}) {
		my ($opt1,$opt2) = split(/\|/,$option->{'prompt'});
		$out .= "$jsVar.forValue(\"$opt1\").addOptionsTextValue(\"$opt2\",\"$option->{'v'}\");\n";
		}
	$out .= qq~

// this initializes the dynamic select menu
initDynamicOptionLists();
//-->
</SCRIPT>
				~;
	$out .= "<br />\n";
	$out .= "<br />\n";
	return $out;
}

#**VERIFY
sub type_calendar_to_html {
	my ($pog, $context) = @_;
	my $out = '';

	my $USERNAME = $pog->{'USERNAME'};

	$out .= "\n\n<!-- POG $pog->{'id'} (text) -->\n";
	$out .= "<SCRIPT src=\"/media/graphics/general/CalendarPopup.js\"></SCRIPT>\n";

	$out .= "<b class=\"ztxt pogprompt pogprompt_calendar\">".$pog->{'prompt'}.":</b> ";
#	$out .= qq~<input type="textbox" name="$pog->{'fieldname'}" ~;
#	
#	

	my $FIELDNAME = $pog->{'fieldname'};
	my $JSVAR = $FIELDNAME;
	$JSVAR =~ s/[\W\_]+//gs;
	my $ANCHOR = $JSVAR.'AnCh0R'; 
	my $FORMNAME = $JSVAR.'F0rMNaMe';

	## not sure exactly what this does, something about CSS??
#	$out .= "<SCRIPT LANGUAGE=\"JavaScript\">document.write(getCalendarStyles());</SCRIPT>\n";

	$out .= qq~
<SCRIPT LANGUAGE="JavaScript"><!--
	var $JSVAR = new CalendarPopup();
	$JSVAR.showNavigationDropdowns();

	

//--></SCRIPT>
	~;
	# $out .= "$jsVar.setCssPrefix(\"TEST\");\n";

	$out .= "<INPUT TYPE=\"text\" ";
	if ($pog->{'maxlength'}) { $out .= " maxlength=\"$pog->{'maxlength'}\" "; }	
	if ($pog->{'default'}) { $out .= " value=\"$pog->{'default'}\" "; }

	$out .= qq~ NAME="$FIELDNAME">
	<SCRIPT LANGUAGE="JavaScript"><!--
	// note: we need to figure out which form the anchor is on!
	var $FORMNAME = -1;
	for (var i = 0; i<document.forms.length; i++) {
		if (document.forms[i].elements['$FIELDNAME']) { $FORMNAME = i; }
		}
//--></SCRIPT>
<A HREF="#" onClick="$JSVAR.select(document.forms[$FORMNAME].elements['$FIELDNAME'],'$ANCHOR','MM/dd/yyyy'); return false;" 
	TITLE="$pog->{'prompt'} $pog->{'hint'}"
	NAME="$ANCHOR" ID="$ANCHOR">[Calendar]</A>
	~;

	$out .= qq~<br>\n~;
	if ($pog->{'fee_rush'}>0) { $out .= sprintf("<div class=\"ztxt zhint\">%s</div>",$pog->{'rush_msg'}); }
	$out .= qq~<br>\n~;
	return $out;
}


#**VERIFY
sub type_imggrid_to_html {
	my ($pog, $context) = @_;
	my $out = '';
	$out .= "\n\n<!-- POG $pog->{'id'} (imggrid) -->\n";

	my $COLS = $pog->{'cols'};
	if ($COLS eq '') { $COLS = 8; }

	my $HEIGHT = $pog->{'height'};
	my $WIDTH = $pog->{'width'};
	my $USERNAME = $pog->{'USERNAME'};
	my $FIELDNAME = $pog->{'fieldname'};

	my $COLPERCENT = int(100/$COLS);
	my $imgFormVar = $pog->{'fieldname'};
	$imgFormVar =~ s/[\W]+//gs;
	$imgFormVar .= 'F0rMVaR';

	$out .= qq~
<INPUT TYPE="HIDDEN" name="hidden$FIELDNAME">
<SCRIPT><!--
	// we'll use this to figure which form we're on.
	var $imgFormVar = -1;
	for (var i = 0; i<document.forms.length; i++) {
		if (document.forms[i].elements['hidden$FIELDNAME']) { $imgFormVar = i; }
		}
//--></SCRIPT>
~;

	$out .= '<b class="pogprompt pogprompt_imggrid">'.$pog->{'prompt'}.":</b><br>";
	$out .= "<table>";
	$out .= "<tr>";
	my $count = 0;
	foreach my $option (@{$pog->{'@options'}}) {
		# my $metaref = parse_meta($option->{'m'});
		# if (($pog->{'inv'} & 2) && ($option->{'asm'} ne '')) { &tweak_asm_option($pog,$option); }
		next if ($option->{'skip'});

		$out .= "<td class=\"ztxt\" width=\"$COLPERCENT\%\">";
		$out .= "<a href=\"#\" onClick=\"document.forms[$imgFormVar].elements['$FIELDNAME'][$count].checked = true; return(false);\">\n";
		$out .= "<img border=0 ".
			(($WIDTH>0)?"width=$WIDTH ":'').
			(($HEIGHT>0)?"height=$HEIGHT":'').
			" src=\"".(($option->{'img'} ne '')?&ZOOVY::mediahost_imageurl($USERNAME,$option->{'img'},$HEIGHT,$WIDTH,'FFFFFF',undef,'jpg'):
			'/media/graphics/general/blank.gif').
			"\">";
		$out .= "</a>";
		if ($pog->{'zoom'}) { 
			if ($option->{'img'} ne '') {
				$out .= "<a target=\"zoom\" href=\"".&ZOOVY::mediahost_imageurl($USERNAME,$option->{'img'},0,0,undef,undef,'jpg')."\"><font size=1>zoom<br></font></a>"; 
				}
			else {
				$out .= "<font size=1>&nbsp; <br></font>";
				}
			}
		$out .= "<br>";
		$out .= "<input ".(($count==0)?'checked':'')." type=\"radio\" name=\"$FIELDNAME\" value=\"$option->{'v'}\"> $option->{'prompt'}";

		# my $mref = &POGS::parse_meta($option->{'m'});	
		#if (($pog->{'inv'} & 2) && 
		#	(($option->{'asm'} ne '') || ($pog->{'type'} eq 'assembly'))) { &tweak_asm_option($pog,$option); }
		next if ($option->{'skip'});

		if ((defined $option->{'p'}) && ($option->{'p'} ne '') && ($option->{'p'} ne '+0')) { 
			$out .= ' '.&POGS::pog_price_modifier_clean($option->{'p'});
			}
		$out .= "<br>";
		$out .= "</td>";
		if (++$count % $COLS == 0) { $out .= "</tr><tr>"; }
		}
	$out .= "</tr>";
	## cheap hack to remove <tr></tr> 
	$out =~ s/\<tr\>\<\/tr\>$//s;
	$out .= "</table>";
	$out .= qq~
	~;

	# delete $pog->{'PRODUCT'};
	# $out .= "<pre>".Dumper($pog)."\n\n".Dumper($context)."</pre>";
	## STILL NEED TO IMPLEMENT ZOOM!
	return($out);
}


## See type_xxx_to_html header above
#**VERIFY
sub type_imgselect_to_html
{
	my ($pog, $context) = @_;
	my $out = '';
	$out .= "\n\n<!-- POG $pog->{'id'} (imgselect) -->\n";

	# $out .= "<pre>".Dumper($pog)."\n\n".Dumper($context)."</pre>";
	## STILL NEED TO IMPLEMENT ZOOM!

	my $HEIGHT = $pog->{'height'};
	my $WIDTH = $pog->{'width'};
	my $USERNAME = $pog->{'USERNAME'};

	my $IMGARRAY = '';
	my $ZOOMARRAY = '';
	my $OPTIONS = '';
	my $DEFAULTIMAGE = '';
	foreach my $option (@{$pog->{'@options'}}) {
		# my $metaref = parse_meta($option->{'m'});
		# if (($pog->{'inv'} & 2) && ($option->{'asm'} ne '')) { &tweak_asm_option($pog,$option); }
		next if ($option->{'skip'});

		if (($DEFAULTIMAGE eq '') && ($option->{'img'} ne '')) { 
			$DEFAULTIMAGE = &ZOOVY::mediahost_imageurl($USERNAME,$option->{'img'},$HEIGHT,$WIDTH,'FFFFFF',undef,'jpg');
			}
		$IMGARRAY .= '"'.&ZOOVY::mediahost_imageurl($USERNAME,$option->{'img'},$HEIGHT,$WIDTH,'FFFFFF',undef,'jpg').'",';
		$ZOOMARRAY .= '"'.&ZOOVY::mediahost_imageurl($USERNAME,$option->{'img'},0,0,undef,undef,'jpg').'",';

		$OPTIONS .= "<OPTION VALUE=\"$option->{'v'}\">$option->{'prompt'}";
		# my $mref = &POGS::parse_meta($option->{'m'});	
		#if (($pog->{'inv'} & 2) && 
		#	(($option->{'asm'} ne '') || ($pog->{'type'} eq 'assembly'))) { &tweak_asm_option($pog,$option); }
		next if ($option->{'skip'});

		# $OPTIONS .= $mref->{'p'};

		if ((defined $option->{'p'}) && (&POGS::iznonzero($option->{'p'}))) {
			$OPTIONS .= ' '.&POGS::pog_price_modifier_clean($option->{'p'});
			}
		$OPTIONS .= "</OPTION>\n";

		
		}
	chop($IMGARRAY);
	chop($ZOOMARRAY);
	
	$DEFAULTIMAGE = '//static.zoovy.com/graphics/general/blank.gif';
	my $imgName = $pog->{'fieldname'}.'ImAgEnAmE';
	$imgName =~ s/[\W\_]+//gs;
	my $imgFormVar = $imgName.'FoRmID';
	my $zoomFormVar = $imgName.'FoRmZ00mUrl';

	$out .= qq~
	<SCRIPT LANGUAGE="JavaScript"><!--
	var $zoomFormVar = '';
	function ~.$imgName.qq~change(what) {
		var i = new Array($IMGARRAY);
		var zurl = new Array($ZOOMARRAY);
		if (i[what.selectedIndex] == "") {
			document.images['$imgName'].src = "/media/graphics/general/blank.gif";
			$zoomFormVar = '/media/graphics/general/blank.gif'; 
			}
		else {
			document.images['$imgName'].src = i[what.selectedIndex];
			$zoomFormVar = zurl[what.selectedIndex];
			}
		}

	//--></SCRIPT>

	<table>
	<tr>
	<td class="ztxt" valign='top'>
		<b class="pogprompt pogprompt_imgselect">$pog->{'prompt'}:</b><br> 
		<SELECT name="$pog->{'fieldname'}" onChange="~.$imgName.qq~change(this)" onSelect=="~.$imgName.qq~change(this)">
		$OPTIONS
		</SELECT>
	</td><td class="ztxt" valign='top'>~;

	if ($pog->{'zoom'}) { $out .= qq~<a onClick="window.open($zoomFormVar,'zoomwindow');" href="#">~; } 
	$out .= qq~<IMG border=0 width=$WIDTH height=$HEIGHT SRC="$DEFAULTIMAGE" NAME="$imgName">~;
	if ($pog->{'zoom'}) { $out .= qq~<center><font size='1'><br>Zoom</font></center></a>~; }
	$out .= qq~<br>
	</td></tr>
	</table>

	<SCRIPT><!--
	// load the default selected image. - first figure out what form the image is on.
	var $imgFormVar = -1;
	for (var i = 0; i<document.forms.length; i++) {
		if (document.forms[i].$imgName) { $imgFormVar = i; }
		}

	~.$imgName.qq~change(document.forms[$imgFormVar].elements['$pog->{'fieldname'}']);
	//--></SCRIPT>
	~;
	
	## now select the first element
	$out .= "<br />\n";
	$out .= "<br />\n";
	return $out;
}

sub DEBUG { return 0; }

##############################################################################
##
## POGS::msg
##
## Purpose: Prints an error message to STDERR (the apache log file)
## Accepts: An error message as a string, or a reference to a variable (if a
##          reference, the name of the variable must be the next item in the
##          list, in the format that Data::Dumper wants it in).  For example:
##          &msg("This house is ON FIRE!!!");
##          &msg(\$foo=>'*foo');
##          &msg(\%foo=>'*foo');
## Returns: Nothing
##
#**VERIFY
sub msg
{
        my $head = 'POGS: ';
        while ($_ = shift (@_))
        {
                if (ref) { require Data::Dumper; $_ = Data::Dumper->Dump([$_], [shift (@_)]); }
#                print STDERR $head, join ("\n$head", split (/\n/, $_)), "\n";
        }
}


1;

