package TOXML::SPECL3;

use strict;
no warnings 'once'; # Keeps perl -w from bitching about single-use variables

use URI::Escape::XS qw();
use JSON::XS qw();
use lib '/backend/lib';
#use ZTOOLKIT qw(def num);
require ZTOOLKIT;
require TOXML::RENDER;



##
##
##
sub new {
	my ($CLASS, $USERNAME, $SITE, %options) = @_;

	if (ref($SITE) ne 'SITE') {
		Carp::croak("TOXML::SPECL3->new requires *SITE");
		}

	my $self = {};
#	if ($options{'*CART2'}) { $self->{'*CART2'} = $options{'*CART2'}; }
	if ($options{'NAVCATS'}) { $self->{'*NAVCATS'} = $options{'NAVCATS'}; }	# i don't think this is used anymore
#	if ($options{'*MSGS'}) { $self->{'*MSGS'} = $options{'*MSGS'}; }

	$self->{'USERNAME'} = $USERNAME;
	$self->{'*SITE'} = $SITE;
	bless $self, 'TOXML::SPECL3';

	return($self);	
	}

sub _SITE { return($_[0]->{'*SITE'}); }
sub username { return($_[0]->{'USERNAME'}); }
sub cart2 { 
	my ($self) = @_;
#	if (defined $self->{'*CART2'}) { return($self->{'*CART2'}); }
	return($self->_SITE()->cart2()); 
	}


sub def { return &ZTOOLKIT::def(@_); }
sub num { return &ZTOOLKIT::num(@_); }
sub isin { return &ZTOOLKIT::isin(@_); }


##
## you pass in the currentstack (a string)
##		basically this just creates a hard line delimited string to store variables we'll want to iterate through later.
##		handy for dealing with simple lists or objects. (we can deserialize these objects later using specl_pop)
##
sub spush {
	my ($self,$stack,@ar) = @_;

	foreach my $ref (@ar) {
		$stack .= (($stack eq '')?'':"\n").&ZTOOLKIT::fast_serialize($ref);
		}

	return($stack);
	}


##
## returns:
##		 the first element of the stack (in scalar form), plus a deserialized version of the reference.
##		NOTE: this is designed to be used to create a LIFO data structure.
##
sub spopfirst {	
	my ($self,$stack) = @_;

	(my $x,$stack) = split("\n",$stack,2);
	my $ref = &ZTOOLKIT::fast_deserialize($x);

	return($stack,$ref);
	}

##
## returns:
##		 the first element of the stack (in scalar form), plus a deserialized version of the reference.
##		NOTE: this is designed to be used to create a LIFO data structure.
##
sub spoplast {	
	my ($self,$stack) = @_;

	my $pos = rindex($stack,"\n");
	# print STDERR "$pos STACK[$stack]\n";
	if ($pos == length($stack)) { 
		# remove a trailing \n
		$pos = rindex($stack,"\n");
		$stack = substr($stack,0,-1); 
		}	
	
	my $x = undef;
	if ($pos==-1) { 
		## we're on the last element
		$x = $stack;
		$stack = '';
		}
	else {
		$x = substr($stack,$pos+1);		
		$stack = substr($stack,0,$pos);
		}
	# print STDERR "$stack\n\nX: $x\n";
	# print STDERR "start\n";
	my $ref = &ZTOOLKIT::fast_deserialize($x);
	# print STDERR "stop\n";

	return($stack,$ref);
	}




##
## returns two hashrefs $even,$odd in that order
##		creates variables such as bg_spec, fg_spec, head_bg_spec, etc. 
##		which are used in a spec for processing colors, etc.
##
sub initialize_rows {
	my ($self,$alternate) = @_;

	if (not defined $alternate) { $alternate = 1; }

#	my $TH = $SITE::CONFIG->{'%THEME'};
	my $CV = $SITE::CONFIG->{'%CSSVARS'};
	my %head = (
		'head_bg_spec' => substr($CV->{'ztable_head.bgcolor'},1),
		'head_fg_spec' => substr($CV->{'ztable_head.color'},1),
		'head_font'    => substr($CV->{'ztxt.font_family'},1),
		'head_size'    => substr($CV->{'ztable_head.font_size'},1),
		'username' => $self->username(),
		'wrapper_url' => $self->_SITE()->URLENGINE()->get('wrapper_url'),
		'graphics_url' => $self->_SITE()->URLENGINE()->get('graphics_url'),
		'image_url' => $self->_SITE()->URLENGINE()->get('image_url'),
		'head_fg'  		=> ' bgcolor="'.$CV->{'ztable_head.color'}.'"',
		'head_bg'  		=> ' bgcolor="'.$CV->{'ztable_head.bgcolor'}.'"',
		);

	
#	my %odd = (
#		'bg_spec'      => def($TH->{'table_listing_background_color'}),
#		'fg_spec'      => def($TH->{'table_listing_text_color'}),
#		'font'         => def($TH->{'table_listing_font_face'}),
#		'size'         => def($TH->{'table_listing_font_size'}),
#		);
	require TOXML::CSS;
	my %odd = (
		'bg_spec'      => substr($CV->{'ztable_row0.bgcolor'},1),
		'fg_spec'      => substr($CV->{'ztable_row0.color'},1),
		'font'         => $CV->{'ztxt.font_family'},
		'size'         => &TOXML::CSS::fontpt2size($CV->{'ztable_row0.font_size'}),
		);
	
	my %even = %odd; ## Most cases even and odd rows show the same thing
	if ($alternate eq '0') {
		## Use color 1 only (0)
		## Keep this blank if statement here because of the else statement lower
		}
	elsif ($alternate eq '2') {
		## Use color 2 only (2)
		# $odd{'bg_spec'} = def($TH->{'table_listing_background_color_alternate'});
		$odd{'bg_spec'} = substr($CV->{'ztable_row1.bgcolor'},1);
			## We don't set $even because $odd and it are pointing at the same hashref
		%even = %odd;		# WRONG! -bh
		}
	elsif (($alternate eq '3') || ($alternate eq '4')) {
		## Use content color (3)
		## Transparent table backround (4)
#		$odd{'bg_spec'} = def($TH->{'content_background_color'});
#		$odd{'fg_spec'} = def($TH->{'content_text_color'});
#		$odd{'font'}    = def($TH->{'content_font_face'});
#		$odd{'size'}    = def($TH->{'content_font_size'});
		$odd{'bg_spec'} = substr($CV->{'zbody.bgcolor'},1);
		$odd{'fg_spec'} = substr($CV->{'ztxt.color'},1);
		$odd{'font'}    = substr($CV->{'ztxt.font_family'},1);
		$odd{'size'}    = TOXML::CSS::fontpt2size($CV->{'ztxt.font_size'});
		## We don't set $even because $odd is pointing at the same hashref
		%even = %odd;		# WRONG! -bh
		}
	else {
		# Alternate (1) - default selection (swaps the colors then resets bg_spec)
		%even = %odd;
		# $even{'bg_spec'} = def($TH->{'table_listing_background_color_alternate'}); ## Change even to the alternate background
		$even{'bg_spec'} = substr($CV->{'ztable_row1.bgcolor'},1); ## Change even to the alternate background
		}
	
	## Set up some shortcuts
	$odd{'fg'}       = qq~ bgcolor="#$odd{'fg_spec'}"~;
	$even{'fg'}      = qq~ bgcolor="#$even{'fg_spec'}"~;
	$odd{'bg'}       = qq~ bgcolor="#$odd{'bg_spec'}"~;		
	$even{'bg'}      = qq~ bgcolor="#$even{'bg_spec'}"~;
	
	## Blank the bg shortcut to make table cells transparent for style 4
	if ($alternate eq '4') { $odd{'bg'}  = ''; $even{'bg'} = ''; }

	## 
	## LINE OF DEPRECATION - ALL VARIABLES ABOVE THIS LINE SHOULD NOT BE USED ANYMORE.
	##
	## ztable_row will load from ztable_row0 ztable_row1 based on even/odd
	## 	
	## 
	
	return(\%head,\%even,\%odd);	
	}



sub set_rowalt {
	my ($rowalt,$alternate) = @_;
			if ($alternate == 0) { $rowalt = 0; }
			elsif ($alternate==2) { $rowalt = 1; }
			elsif (($alternate==3) || ($alternate==4)) {
				$rowalt = $alternate;
				}
			else {
				$rowalt = $rowalt ? 0 : 1;
				}
	return($rowalt);
	}


##
## parameters (passed as a hash of key/value pair)
##		'spec' => [scalar] the list specification ??
##		'items' => [arrayref] the list of items to be put into the list.
##		'lookup' => [arrayref] the list of variables to translate %variables% from (array of hashes)
##		'theme_info' => [hashref] theme info as parsed from the theme INI
##		'preprocess' => [arrayref] a list of fields on a per-item basis which need to be pre-processed (use this to get row colors inside of stuff passed into this function)
##		'alternate' => [scalar number] 0 means color 1 only, 1 means alternate colors 1 and 2, 2 means color 2 only, 3 use content bg, 4 use transparent bg
##		'cols' => [scalar number] number of columns, defaults to 1
##
sub process_list {
	my ($self,%params) = @_;

	## Translate some params into local variables

	##	products use "<!-- PRODUCT --> and categories use <!-- CATEGORY --> (but they both do the same thing)
	my $item_tag		  = uc((defined $params{'item_tag'})?$params{'item_tag'}:'item');
	my $LIST_ID = $params{'id'};
	if ($LIST_ID eq '') { $LIST_ID = "UNKNOWN_".$item_tag; }
	my $alternate       = defined($params{'alternate'}) ? num($params{'alternate'}) : 1 ; ## Optional, 0 means color 1 only, 1 means alternate colors 1 and 2, 2 means color 2 only, 3 use content bg, 4 use transparent bg

	my $spec            = $params{'spec'};                     ## Required, the list specification
	my @items           = &array_param($params{'items'});      ## Required, the list of items to put into the list
	my @lookup          = &array_param($params{'lookup'});     ## Required, the list of hashes to translate %variables% from
	my @preprocess      = &array_param($params{'preprocess'}); ## Optional, a list of fields on a per-item basis which need to be pre-processed (use this to get row colors inside of stuff passed into this function)
	my $cols            = defined($params{'cols'}) ? num($params{'cols'}) : 1 ;           ## Optional, number of columns, defaults to 1
	my $replace_undef   = defined($params{'replace_undef'}) ? num($params{'replace_undef'}) : 1 ;
	my $divider		  = defined($params{'divider'})?$params{'divider'}:'';

	## Check for required params, default some of them
	if (not defined $spec || $spec eq '') { return "No list specification passed to list_process()"; }
	if (not @items) { return ''; }
	
	## Default the <!-- MARKER -->...<!-- /MARKER --> syntax for dividing up the sections of a list
	## If you include a sublist on field OPTIONS then the default marker for it will be <!-- OPTIONS -->
	## Going to try to document this better through examples. -AK
		
	my ($headref,$evenrow,$oddrow) = $self->initialize_rows($params{'alternate'});
	my $rowref = $oddrow; # Start off on an odd row (this will just be the same thing as row_info if passed in)

	my $sp = $spec; # make a copy of $spec that we can mangle.
	## Get the columns, row and blank column information
	my $col_raw = '';
	my $blankcol_raw = '';
	my $rowhead_raw = '';
	my $rowfoot_raw = '';



	(my $rowspec, $sp, my $head_raw, my $foot_raw) = $self->extract_comment($sp,'ROW');
#	print STDERR "ROW[$rowspec]\n";

	if ($rowspec ne '') {
		($blankcol_raw, $rowspec) = $self->extract_comment($rowspec,'BLANK');
		($col_raw, undef, $rowhead_raw, $rowfoot_raw) = $self->extract_comment($rowspec,$item_tag);
		}
	else {
		($col_raw, undef, $head_raw, $foot_raw) = $self->extract_comment($sp,$item_tag);
		$cols = 1;
		}

	my $out       = '';
	my $count     = 0; ## Keeps track of which product we're on (also changes rowflip when we get to the next row)
	my $rowalt   = &set_rowalt(1,$alternate); ## 0 if we're on an odd row, 1 if we're on an even row
	if ($cols <= 0) { $cols = 1; }

	my $basewidth = int(100 / $cols); ## The smallest column size
	my $remainder = (100 % $cols); ## The percent left after the 100% of the row was divided by the columns (used in the loop to make sure column width gets set properly even for divders with remainders)
	my $extra     = $remainder; ## Set the initial variable for the extra percent left in a row.  This will get reset on every row.
	my $totalcount = scalar(@items);

	push @lookup, { 'TOTALCOUNT'=>$totalcount };
	
	$out .= $self->translate3($head_raw,[$headref,$rowref,@lookup],replace_undef=>$replace_undef); ## output the prodlist header
	$out .= $self->translate3($rowhead_raw,[$headref,$rowref,@lookup],replace_undef=>$replace_undef); ## output the row header
	## Loop through all the products and create the output

	$divider = $self->translate3($divider,[@lookup],replace_undef=>$replace_undef);

	## BACKUP THE SREF SKU
	my $SITE = $self->_SITE();
	my $GLOBAL_STID = $SITE->stid();

	foreach my $item (@items) {
		
		if (defined $params{'sku'}) {
			## changes the focus of the global SKU to point at the current item
			$SITE->setSTID($item->{$params{'sku'}});
			}

		if ($count && not($count % $cols)) {
			if ($item->{'+SKIPALTERNATE'}) { }	# don't alternate for this row (e.g. assembly item)
			else {
				$rowalt = &set_rowalt($rowalt,$alternate);
				}
			## Output a row footer and header if we have another row to go
			$out .= $self->translate3($rowfoot_raw,[$headref,$rowref,@lookup],replace_undef=>$replace_undef);
			## Change to using the odd or even row colors/etc.
			$rowref     = $rowalt ? $evenrow : $oddrow;
			$extra   = $remainder; # This is essentially a pool of extra percent points that gets deducted from until depleted
			$out .= $self->translate3($rowhead_raw,[$headref,$rowref,@lookup],replace_undef=>$replace_undef);
			}	
		else {
			## this block is run whenever we DID NOT output a header and footer.
			my $r = (($cols+$count) % $cols);
			if ($r == 0) {}
			else { $out .= $divider; }
			}

		my $width = $basewidth;
		if ($extra) { $extra--; $width++; } ## Add the extra percents on (while we still have percents left for the row)
		

		## The product replacement variables for this particular product.
		my $col_repl = {
			'COLWIDTH'          => $width.'%',
			'COUNT'             => $count,
			'row.alt' => $rowalt,
			'ALTERNATE'         => $params{'alternate'},
			};

		## Add in column/row variables for any fields that may need to be pre-processed
		foreach (@preprocess) { 
			$item->{$_} = $self->translate3(def($item->{$_}),[$rowref],replace_undef=>$replace_undef); 
			}


		# print STDERR "$item_tag ROWREF[$count/$cols/$rowalt]: ".Dumper($rowref);
		## Output the product
		$out .= $self->translate3($col_raw,[$headref,$rowref,$col_repl,$item,@lookup],replace_undef=>$replace_undef);
		$count++;
		undef $item;
		}

	$SITE->setSTID( $GLOBAL_STID );

	# Pad out the row with blank columns
	while ($count % $cols) {
		my $width = $basewidth;
		if ($remainder) { $remainder--; $width++; }
		my $col_repl = { 'COLWIDTH' => $width . '%', 'COUNT' => $count, };
		$out .= $self->translate3($blankcol_raw,[$headref,$rowref,$col_repl,@lookup],replace_undef=>$replace_undef);
		$count++;
		}
	$out .= $self->translate3($rowfoot_raw,[$headref,$rowref,@lookup],replace_undef=>$replace_undef);
	$out .= $self->translate3($foot_raw,[$headref,$rowref,@lookup],replace_undef=>$replace_undef);

	#undef $item_tag,$alternate,$spec;
	#undef @items, @lookup, @preprocess;
	#undef $cols, $replace_undef, $headref, $evenrow, $oddrow;
	#undef $col_raw, $rowhead_raw, $rowfoot_raw; 
	#undef %params, $count, $rowalt; 
	#undef $basewidth, $remainder, $extra;
	#undef @preprocess;

	if ($SITE::pbench) { $SITE::pbench->stamp("::: LIST: $LIST_ID"); }

	return $out;
}



#<%
# load(_vartxt_); /* comment */
# $(_vartxt_);
# 
# default(_vartxt_);
# strip(length=>500,breaks=>0 1,html=>0 1);
# pretext(_vartxt_);
# posttext(_vartxt_);
#  
# format(hidezero);
# format(money);
# format(before after around= slash bar space paren bracket angle break bold);
# format(before=>slash);
# 
# format(before=>bar);
# format(link);
# math(op=>add subtract multiply divide percent,var=>_vartxt_);
# stop(if=>_vartxt_);
# stop(unless=>_vartxt_);
# image(h=>int,w=>int,m=>1 0,bg=>,alt=>_vartxt_);
# element(TYPE=>"READONLY");
#
#%>

# %zoovy:prod_name%
# <%$($zoovy:prod_name);%>

#_vartxt_ - can be any of the following:
#$variablename
#"txt":text scalar

#whenever _vartxt_ is not specified, the current value in scope is assumed. 

#The only character which MUST be escaped is the PIPE .. which to make things simple will be escaped
#by doing a double pipe || -- this really only applies to the translate function. 
#

#New proposed methods:

#element(type=,etc,etc)  /* can be used in lieu of a "start", output stored in current variable. */
#loadurp(_vartxt_)	/* specifies a piece of data to load */
#
#goto(if=_vartxt_,to=somelabel)
#gotonm (unless=_vartxt_,to=somelabel)
#label(somelabel)
#translate{_vartxt_}	 /* effectively allows nesting of multiple of statements */
#debug{mode=0 1}	 /* a set of bitwise values which control verbosity/format

##
## each "t2function" takes in:
##		$val,$hashes,$paramstr
##	returns:
##		$val,$verb		-- normal "verb" is "next"
##





##
## if value not set, defaults.
## parameters: _vartxt_
##
sub t2default {
   my ($self,$val,$hashes,$paramstr) = @_;

   if ((not defined $val) || ($val eq '')) {
      ## it's pretty common that we'll initialize to blank.
      ## print STDERR "paramstr: $paramstr\n";
      if ($paramstr eq '""') {
         $val = '';
         }
      else {
         ($val) = &t2load($self,undef,$hashes,$paramstr);
         ## print STDERR "result[$paramstr] is [$val]\n";
         }
      }

   return($val);
   }





##
## (length=500,breaks=0 1,html=0 1,wiki=>0 1);
##
sub t2strip {
	my ($self,$val,$hashes,$paramstr) = @_;
	my $options = $self->parseparams($val,$hashes,$paramstr);

	my ($len,$strip_breaks,$strip_html) = ($options->{'length'},$options->{'strip_breaks'},$options->{'strip_html'});
	if (not defined $len) { $len = 500; }

	if ((defined $options->{'wiki'}) && ($options->{'wiki'}==1)) {
		## remove wiki formatting -- hmm.. this could probably be faster at some point.
		##		but this seems the most resilient way to write this.
		$val =~ s/\[\[.*?\].*?\]//gso;	## first strip bad tags.
		$val = $self->_SITE()->URLENGINE()->wiki_format($val);	## load in interpolation variables.
		$val =~ s/\%.*?\%//gso;				## then strip any interpolation variables.
		}

	if (not defined $strip_breaks) {
		$strip_breaks = not &find_in_hashes('no_strip_breaks',$hashes);
		if (not defined $strip_breaks) { $strip_breaks = 1; }
 		}
	if (not defined $strip_html) {
		$strip_html = not &find_in_hashes('no_strip_html',$hashes);
		if (not defined $strip_html) { $strip_html = 1; }
		}

	($strip_html) = (not $strip_html);
	$val = &smartstrip($val, $len, $strip_html, $strip_breaks);
	return($val);
	}

# math(op=>add subtract multiply divide percent,var=>_vartxt_);
sub t2math {
	my ($self,$val,$hashes,$paramstr) = @_;
	my $options = $self->parseparams($val,$hashes,$paramstr);

	## Make sure the original value is OK
	$val =~ s/[^0-9\.\-]//gso;
	my $option = $options->{'op'};
	my ($modifier) = $options->{'var'};

	$modifier =~ s/[^0-9\.\-]//gos;
	if ($modifier eq '') { $val = ''; }

	# print STDERR "MATH: value=[$val] option=[$option] modifier=[$modifier]\n";

	if ($val ne '') {
		## Avoid divide by zero errors
		if (($option eq 'divide') && ($modifier == 0)) { $val = ''; }
		}
	
	if ($val ne '') {
		## Perform the function
		if    ($option eq 'add')         { $val += $modifier; }
		elsif ($option eq 'subtract')    { $val -= $modifier; }
		elsif ($option eq 'multiply')    { $val *= $modifier; }
		elsif ($option eq 'divide')      { $val /= $modifier; }
		elsif ($option eq 'mod')      { $val = $val % $modifier; }
		elsif ($option eq 'percent')     { $val *= ($modifier/100); $val = sprintf("%.2f",$val); }
		elsif ($option eq 'percentdiff') { $val = int(((($val - $modifier) / $val) * 100) + 0.5).'%'; }
		}

	return($val);
	}

# stop(if=>_vartxt_);
# stop(unless=>_vartxt_);
sub t2stop {
	my ($self,$val,$hashes,$paramstr) = @_;
	my $options = $self->parseparams($val,$hashes,$paramstr);

	my $option = '';
	my $keepgoing = 0;

	# use Data::Dumper; print STDERR Dumper($options);

	if (defined $options->{'if'}) {
		if ($options->{'if'} eq '') { $options->{'if'} = $val; }
		$keepgoing = ($options->{'if'}) ? 0 : 1 ;
		}
	elsif (defined $options->{'unless'}) {
		if ($options->{'unless'} eq '') { $options->{'unless'} = $val; }
		$keepgoing = ($options->{'unless'}) ? 1 : 0 ;		
		}

	return($val,($keepgoing)?'':'stop');
	}

# image(src=>$zoovy,h=>int,w=>int,m=>1 0,bg=>,alt=>_vartxt_,tag=>1,library=>"zoovy");
sub t2image {
	my ($self,$val,$hashes,$paramstr) = @_;
	my $options = $self->parseparams($val,$hashes,$paramstr);
	
	my ($width,$height,$alt,$minimal,$tag,$ps)   = (75,75,'',0,0);

	my $bg = $options->{'bg'};
	if ((defined $bg) && (substr($bg,0,1) eq '#')) { $bg = substr($bg,1);  } 	# strip the leading # from hexcolor #FFFFFF
	if (not defined $bg) { $bg = &find_in_hashes('bg_spec',$hashes); }	# legacy lookup.

	my $USERNAME = $self->username();
	if (defined $options->{'src'}) { $val = $options->{'src'}; }
	if (defined $options->{'w'}) { $width = $options->{'w'}; }
	if (defined $options->{'h'}) { $height = $options->{'h'}; }
	if (defined $options->{'m'}) { $minimal = $options->{'m'}; }
	if (defined $options->{'p'}) { $ps = $options->{'p'}; }
	if (defined $options->{'tag'}) { $tag = $options->{'tag'}; }
	if (defined $options->{'alt'}) { $alt = $options->{'alt'}; }
	if (not defined $options->{'alt'}) { 
		$alt = &find_in_hashes($options->{'alt'},$hashes);
		if (not defined $alt) { $alt = &find_in_hashes('zoovy:prod_name',$hashes); $alt =~ s/[\W]+/ /og; }
		}

	if ($minimal) {
		($width,$height) = &ZOOVY::image_minimal_size($USERNAME, $val, $width, $height);
		}

	my $src = undef;
	if (defined $options->{'library'}) { 
		## for now the only supported library is proshop.
		## if ($options->{'library'} eq 'proshop') { $USERNAME = 'proshop'; }
		##	$src = &IMGLIB::Lite::url_to_image($USERNAME, $val, $width, $height, $bg, undef, $ps, $self->_SITE()->cache_ts());
    	$src = sprintf("//%s%s",&ZOOVY::resolve_media_host('proshop'),&ZOOVY::image_path('proshop', $val, W=>$width, H=>$height, B=>$bg));
		}
	else {
		## this is better and does versioning
		$src = $self->_SITE()->URLENGINE()->image_url($val,$width,$height,$bg,'p'=>$ps);
		}

	if ($tag==0) {
		$val = $src;	# don't output a tag (default behavior)
		}
	else {
		$alt = &ZOOVY::incode($alt);
		$val = qq~<img src="$src" width="$width" height="$height" alt="$alt" border="0" />~;
		}

	return($val);
	}




# format(hidezero);
# format(wiki=>1,title1=>"tag",/title1=>"tag")
# format(money);
# format(before after around= slash bar space paren bracket angle break bold);
# format(before=>slash);
# format(before=>bar);
# format(link=>url);
# format(pretext=>text) format(posttext=>text)
#
# NOTE: all commands support skipblank=>1 which tells it to skip formatting for blank variables.
#
sub t2format {
	my ($self,$val,$hashes,$paramstr) = @_;
	my $options = $self->parseparams($val,$hashes,$paramstr);
	# use Data::Dumper; print STDERR Dumper($options,$paramstr);

	## added to get rid of basic declare error - patti - 2006-05-09
	my $source = '';

	if ($options->{'skipblank'}==1) {
		## the old syntax used to skip blank by default
		if ($val eq '') { return(''); }
		}

	if (defined $options->{'hidezero'}) {
		if ($val == 0) { $val = ''; }		
		}
	elsif (defined $options->{'encode'}) {
		$options->{'encode'} = lc($options->{'encode'});
		if ($options->{'encode'} eq 'entity') {
			## < = &lt; > = &gt; " = &quot and &amp;
			$val = &ZTOOLKIT::encode($val);
			}
		elsif ($options->{'encode'} eq 'uri') {
			# http://www.zoovy.com = http%3A%2F%2Fwww.zoovy.com%2F
			## was URI::Escape::uri_escape_utf8
			$val = URI::Escape::XS::uri_escape($val);
			}
		elsif ($options->{'encode'} eq 'json') {
			# make sure hardreturns and utf8 are properly escaped for javascript
			require JSON::XS;
			$val = JSON::XS->new->allow_nonref->encode($val);
			}
		}
	elsif (defined $options->{'decode'}) {
		$options->{'decode'} = lc($options->{'decode'});
		if ($options->{'decode'} eq 'entity') {
			## < = &lt; > = &gt; " = &quot and &amp;
			$val = &ZTOOLKIT::decode($val);
			}
		elsif ($options->{'decode'} eq 'uri') {
			# http://www.zoovy.com = http%3A%2F%2Fwww.zoovy.com%2F
			$val = URI::Escape::XS::uri_unescape($val);
			}
		}
	elsif ((defined $options->{'money'}) || (defined $options->{'currency'})) {
		## ## OLD PRE CURRENCY CODE:
		## $val =~ s/^\s+//o;
		## $val =~ s/\s+$//o;
		## $val =~ s/^\$\s*//o;
		## ## deal with negative numbers
		## if ($val =~ m/-/){ $val =~ s/\-//; $val = '-'.'$' . sprintf('%.2f', $val); }
		## elsif ($val =~ m/^[0-9\.]+$/) { $val = '$' . sprintf('%.2f', $val); }

		## NOTE: seems a lot of old legacy pre-specl code depends on the concept that then $val is '' then nothing happens.

		## ex: format(money=>1,currency=>"CAD");
		## money adds the symbol
		## currency converts from dollars

		require ZTOOLKIT::CURRENCY;
		if (($val ne '') && (defined $options->{'currency'})) { 
			($val) = ZTOOLKIT::CURRENCY::convert($val,'USD',$options->{'currency'});
			}
		
		if (($val ne '') && (defined $options->{'money'})) {
			($val) = &ZTOOLKIT::CURRENCY::format($val,$options->{'currency'});			
			}
		}
	elsif (defined $options->{'wiki'}) {
		$val = $self->_SITE()->URLENGINE()->wiki_format($val);
		# print STDERR Dumper($options);
		foreach my $k (keys %{$options}) {
			next if (index($val,'%'.$k.'%')==-1);
			# $k = quotemeta($k);
			# $options->{$k} = quotemeta($options->{$k});
			$val =~ s/\%$k\%/$options->{$k}/gs;
			}
		# print STDERR "VAL: $val\n";
		$val =~ s/\%.*?\%//gs;	# strip any remaining tags which were NOT specified in $options
		}
	elsif (defined $options->{'rewrite'}) {
		$val = $self->_SITE()->URLENGINE()->rewrite($val);
		}
	elsif (defined $options->{'link'}) {
		if ($source ne '') {
			my ($url) = &t2load($self,'',$hashes,$options->{'link'});
			if ($url ne '') { $val = qq~<a href="$url">$val</a>~; }
			}
		}
	elsif ((defined $options->{'before'}) || (defined $options->{'after'}) || (defined $options->{'around'})) {
		my ($what,$where,$before,$after) = ();
		if (defined $options->{'before'}) { $where = 'before'; $what = $options->{'before'}; }
		elsif (defined $options->{'after'}) { $where = 'after'; $what = $options->{'after'}; }
		elsif (defined $options->{'around'}) { $where = 'around'; $what = $options->{'around'}; }

		if    ($what eq 'slash')   { $before = '/'; }
		elsif ($what eq 'comma')   { $before = ','; }
		elsif ($what eq 'bar')     { $before = '|'; }
		elsif ($what eq 'space')   { $before = ' '; }
		elsif ($what eq 'paren')   { $before = '('; $after = ')'; }
		elsif ($what eq 'bracket') { $before = '['; $after = ']'; }
		elsif ($what eq 'angle')   { $before = '&lt;'; $after = '&gt;'; }
		elsif ($what eq 'break')   { $before = '<br>'; }
		elsif ($what eq 'bold')    { $before = '<b>'; $after = '</b>'; }
		if ($after eq '')          { $after  = $before; } # Most default to the same for both
		if ($where eq 'before')    { $after  = ''; }
		if ($where eq 'after')     { $before = ''; }
		$val = $before . $val . $after;		
		}
	elsif (defined $options->{'convert'}) {
		if ($options->{'convert'} eq 'lowercase') { $val = lc($val); }
		elsif ($options->{'convert'} eq 'uppercase') { $val = uc($val); }
		elsif ($options->{'convert'} eq 'number') { 
			if ($options->{'precision'}==1) { $val = sprintf("%.1f",$val); }
			elsif ($options->{'precision'}==2) { $val = sprintf("%.2f",$val); }
			else { $val = sprintf("%d",$val); }
			}
		}
	elsif (defined $options->{'payment'}) {
		require ZPAY;
		## takes a card number and transforms it to type e.g. VISA (based on the first digit)
		if ($options->{'payment'} eq 'cc_type') {  $val = $ZPAY::cc_names{&ZPAY::cc_type_from_number($val)}; }
		## takes a 
		elsif ($options->{'payment'} eq 'cc_masked') {  $val = &ZPAY::cc_hide_number($val); }
#		elsif ($options->{'payment'} eq 'paypal_url') {  
#			require ZPAY::PAYPAL_CART;
#			$val = &ZPAY::PAYPAL_CART::payment_url($SITE::merchant_id,$options->{'order'},$SITE::webdbref); 
#			# print "V[$val]\n";
#			}
		}
	elsif ($options->{'replace'}) {
		## replace=>"asdf",with=>"1234"
		my $needle = $options->{'replace'};
		my $with = $options->{'with'};
		$val =~ s/$needle/$with/g;
#		print STDERR "VAL: $val\n";
		}
	elsif ($options->{'substring'}) {
		## substring=>$_,pos=>0,len=>5
		$val = $options->{'substring'};
		$val = substr($val,$options->{'pos'},$options->{'len'});
		}

	if (defined $options->{'pretext'}) {
		if ($val ne '') { $val = $options->{'pretext'}.$val; }
		}
	if (defined $options->{'posttext'}) {
		if ($val ne '') { $val = $val.$options->{'posttext'}; }
		}

	return($val);
	}



##
## dereferences a variable as a pointer.
##		fuck specl is cool.
##
sub t2ptr {
	my ($self,$val,$hashes,$paramstr) = @_;

#	print STDERR 'PTR: '.Dumper($paramstr);
	($val) = t2load($self,$val,$hashes,$paramstr);
	if (substr($val,0,1) ne '$') { $val = '$'.$val; }	# makes input_bill_fullname $input_bill_fullname
#	print STDERR 'PTR: '.Dumper($val);
	($val) = t2load($self,undef,$hashes,$val);
#	print STDERR 'PTR: '.Dumper($val);

	return($val);
	}


##
##	val is the current value
##	$hashes is a list of hashes we can search		
##	$paramstr is a _vartxt_ 
##
sub t2load {
	my ($self,$val,$hashes,$paramstr) = @_;

	# print STDERR "LOADING: $val,$hashes,$paramstr\n";
	if ($paramstr eq '$_') { return($val); }		# $_ is the local variable in memory
	elsif (substr($paramstr,0,1) eq '$') { 
		# handles $zoovy:prod_name
		$paramstr = substr($paramstr,1);
	   foreach (@{$hashes}) { 
			# use Data::Dumper; print STDERR 'SEARCHING: '.Dumper($_);
			defined($_->{$paramstr}) && return($_->{$paramstr}); 
			}
		} 	
	elsif (substr($paramstr,0,1) eq '"') { 
		# handles "asdf"
		my $v = (substr($paramstr,1,-1));
		if (length($v)>10) { 
			# print STDERR "V: $v\n"; 
			}
		return(&ZTOOLKIT::decode($v));  
		} 	
	elsif (substr($paramstr,0,2) eq '>$') { 
		# handles pointers: e.g. *$variable .. which returns simply $variable 
		return(substr($paramstr,1));
		}
	return(undef);
	}

##
## this splits k1=>v1,k2=>v2,k3=>v3 and returns a hashref
##
sub parseparams {
	my ($self,$val,$hashes,$paramstr) = @_;
	if (not defined $val) { $val = ''; }

	## strings:
	## k=>$v,
	## k=>"",
	
	my %result = ();
	my $copy = $paramstr;

	# print STDERR "PARAMSTR: $paramstr\n";
	$paramstr =~ s/^[\s]+//o;
	while(1) {
		# print STDERR "START=[$paramstr]\n";
		## NOTE: $VAR resolve (except on set($var=>"string"); when they aren't supposed to!!
		##			/var is legal apparently to support wiki commands. FUCK!
		if ($paramstr =~ /^([\$]?[\/]?[a-zA-Z][a-zA-Z0-9\_]*)/o) {
			my ($k,$v) = ($1,undef);
			$paramstr = substr($paramstr,length($k));
			# print STDERR "NOW=[$paramstr]\n";
			if (substr($k,0,1) eq '$') {
				$k = &t2load($self,$val,$hashes,$k);
			#	print STDERR "RESOLVEDK=[$k]\n";
				}

			## SANITY: at this point $k has been resolved, and paramstr has been cut down.
			if (substr($paramstr,0,2) eq '=>') {
				if ($paramstr =~ /^\=\>\"(.*?)\"/so) { 
					# found a quoted string 
					$result{$k} = $1; 
					$paramstr = substr($paramstr,4+length($result{$k})); 
					$result{$k} = &ZTOOLKIT::decode($result{$k});
					# print STDERR "CHAR RESULT:$result{$k}\n";
					}
				elsif (substr($paramstr,0,4) eq '=>$_') {
					$result{$k} = $val;
					$paramstr = substr($paramstr,4);
					}
				elsif ($paramstr =~ /\=\>([>]?\$[a-zA-Z][a-zA-Z0-9_\:\.]*)/o) {
					# found a variable, or a pointer (ex:. =>>$var)
					$paramstr = substr($paramstr,length($1)+2);
					if (substr($1,0,1) eq '>') {
					#	print STDERR "PTR RESULT:$1\n";
						$result{$k} = substr($1,1);
						}
					else {
					#	print STDERR "VAR RESULT:$1\n";
						$result{$k} = &t2load($self,$val,$hashes,$1);
						}
					}
				else {
					# warn "found else .. implicit finish\n";
					$result{$k} = &t2load($self,$val,$hashes,$paramstr);
					$paramstr = '';
					}
				}
			else {
				## just an isolated parameter, e.g. money vs. money=>1
				$result{$k}++;
				}

			if ($paramstr =~ /^([\s]*\,[\s]*)/o) {
				# strip sp+comma+sp to get ready for next token
				# print STDERR "==> $paramstr\n";
				$paramstr = substr($paramstr,length($1)); 
				# print STDERR "==> $paramstr\n";
				}
			else {
				# we're done, no more tokens!
				last;
				}
			# print "END=[$paramstr]\n";
			}
		elsif ($paramstr =~ /^[\s]*$/o) {
			last;
			}
		else {
			## we're done!
			warn "premature end! [$paramstr] remains\n";
			last;
			}
		}

	# print STDERR Dumper(\%result);



	return(\%result);
	}


#sub parseparamsTEST {
#	my ($val,$hashes,$paramstr) = @_;
#
#	my ($new) = parseparamsNEW($val,$hashes,$paramstr);
#	my ($old) = parseparamsOLD($val,$hashes,$paramstr);
#	
#	foreach my $k (keys %{$old}) {
#		# print "K: $k\n";
#		if ($old->{$k} eq $new->{$k}) { 
#			delete $new->{$k}; 
#			}
#		else {
#			$new->{"MISS-old-$k"} = $old->{$k};
#			$new->{"MISS-new-$k"} = $new->{$k};
#			}
#		}
#	if (scalar(keys %{$new})>0) {
#		warn "had extra keys: ".Dumper($new,$old);
#		}
#	return($old);
#	}

#sub parseparamsOLD { parseparams(@_); }

sub parseparamsOLD {
	my ($self,$val,$hashes,$paramstr) = @_;
	if (not defined $val) { $val = ''; }

	my %result = ();
	foreach my $paramkv (split(/,/,$paramstr)) {
		## splitting on commas is bad.
		if ( index($paramkv,'=>') >= 0 ) {
			my ($k,$v) = split(/\=\>/,$paramkv);
			# print STDERR "V: $v\n";
			$result{$k}=&t2load($self,$val,$hashes,$v);
			}
		else {
			## parameter by itself.
			$result{$paramkv}++;
			}
		}
	return(\%result);
	}

##
## yehaw, this calls another code block withing a code block!
##
sub t2runspec {
	my ($self,$val,$hashes,$paramstr) = @_;

	# print STDERR "RUNSPEC BEFORE: [$paramstr]\n";
	($val) = t2load($self,$val,$hashes,$paramstr);

	# print STDERR "RUNSPEC AFTER: [$val]\n";
	($val) = $self->translate3($val,$hashes,replace_undef=>1);

	# print STDERR "RUNSPEC RESULT [$val]\n";
	return($val);
	}


##
## syntax: set($var1=>_vartxt_,$var2=>_vartxt_);
##   (this will assign $var to whatever _vartxt_ is)		
##
sub t2set {
	my ($self,$val,$hashes,$paramstr) = @_;

	my $options = undef;
	if (ref($paramstr) eq '') {
		$options = $self->parseparamsOLD($val,$hashes,$paramstr);
		}
	elsif (ref($paramstr) eq 'HASH') {
		## this called by t2pop to set variables.
		$options = $paramstr; 
		}
	# print STDERR "t2set options: ".Dumper($options);

	foreach my $var (keys %{$options}) {
		next if (substr($var,0,1) ne '$');
		$var = substr($var,1);	# strip off $

		## now go through each hash in hashes
		my $ref = undef;
		foreach my $h (@{$hashes}) {
			next unless (defined $h->{$var});
			delete $h->{$var};
			$ref = $h;
			}

		if (not defined $ref) {
			$ref = {};
			push @{$hashes}, $ref;
			}
	
		$ref->{$var} = $options->{'$'.$var};
		}
	
	return($val);
	}

##################################
##
## syntax:
## element(TYPE=>OVERLOAD)
##
sub t2element {
	my ($self,$val,$hashes,$paramstr) = @_;

	my $options = $self->parseparams($val,$hashes,$paramstr);
	# print STDERR "Running t2element!\n".Dumper($options);

	my $cache_id = undef;
	my $tagout = undef;
	if ((defined $SITE::memd) && ($options->{'CACHEABLE'})) {
		$cache_id = $self->_SITE()->cache_id($options);
		if (defined $cache_id) {		
			($tagout) = $SITE::memd->get($cache_id);						
			if (defined $tagout) { $cache_id = "HIT/$cache_id"; }
			}
		}

	if (defined $tagout) {
		## woot.. already found it in cache.
		}
	elsif (defined $TOXML::RENDER::render_element{$options->{'TYPE'}}) {
		$tagout = $TOXML::RENDER::render_element{$options->{'TYPE'}}->($options,undef,$self->_SITE());
		if (defined $cache_id) {
			warn "Stored $cache_id $tagout\n";
			$SITE::memd->set($cache_id,$tagout);
			}
		}
	else {
		$tagout = "Unknown Element TYPE=$options->{'TYPE'}";
		}

	if ($SITE::pbench) { 
		$SITE::pbench->stamp("::: SPECL/ELEMENT: $options->{'ID'} (cache_id:$cache_id)"); 
		}

	return($tagout);
	}


sub t2debug {
	my ($val,$hashes,$paramstr) = @_;

	die($val);
	}


##
##	needle=>_vartxt_, haystack=>_vartxt_
## note:
##		if haystack not specified, then we'll use the current $_
##	 	returns 0 if not found, otherwise returns first position of occurance (string starts at 1)
##
sub t2strindex  {
	my ($self,$val,$hashes,$paramstr) = @_;

	$paramstr .= ",verb=>\"index\"";
	return(t2str($self,$val,$hashes,$paramstr));

#	my $options = parseparams($val,$hashes,$paramstr);
#	if (not defined $options->{'haystack'}) {
#		$options->{'haystack'} = $val;
#		}
#
#	$val = index($options->{'haystack'},$options->{'needle'})+1;

	return($val);	
	}


##
##	str
##		verb: "length"
##			returns the length of the string
##		verb: "mask"
##			mask: ",!" 
##			only allows commas and exclamation marks to pass through
##		verb: "index" / "rindex"
##			haystack: "haystack"
##			needle: "needle"
##			
## note:
##		if haystack not specified, then we'll use the current $_
##	 	returns 0 if not found, otherwise returns first position of occurance (string starts at 1)
##
sub t2str {
	my ($self,$val,$hashes,$paramstr) = @_;

	my $options = $self->parseparams($val,$hashes,$paramstr);
	if ($options->{'verb'} eq 'index') {
		## left index
		if (not defined $options->{'haystack'}) {
			$options->{'haystack'} = $val;
			}
		$val = index($options->{'haystack'},$options->{'needle'})+1;
		}
	elsif ($options->{'verb'} eq 'rindex') {
		## right index
		if (not defined $options->{'haystack'}) {
			$options->{'haystack'} = $val;
			}
		$val = rindex($options->{'haystack'},$options->{'needle'})+1;
		}
	elsif ($options->{'verb'} eq 'mask') {
		## mask
		my %mask = ();
		foreach my $ch (split(//,$options->{'mask'})) { 
			$mask{$ch}++;
			}
		if ($options->{'comma'}) { $mask{','}++; }

		my $out = '';
		foreach my $ch (split(//,$val)) {
			if (defined $mask{$ch}) { 
				$out .= $ch; 
				}
			}
		$val = $out;
		}
	elsif ($options->{'verb'} eq 'length') {
		## length
		$val = length($val);
		}

	return($val);	
	}


##
## t2sysmesg
##	
##	loads a system message from the global messages object.
##
sub t2sysmesg {
	my ($self,$val,$hashes,$paramstr) = @_;

	my $options = $self->parseparams($val,$hashes,$paramstr);
	if ($options->{'id'}) {
		$val = $self->_SITE()->msgs()->get($options->{'id'});
		}
	else {
		$val = "## sysmesg id not specified ##";
		}
	if (not defined $val) { $val = ""; }
	return($val);
	}


##
## this enables the eval of a perl function using data passed via specl
##
## parameters are:
##		module e.g. ZTOOLKIT
##		func e.g. 
##			dateValueRange p1=> p2=>
##			validateEmail
##			validatePhone
##			numtype
##			isnum
##			isdecnum
##
## zfunction(call=>"ZTOOLKIT::dateValueRange",p1=>$zoovy:cc_hours);
##	goto(eq=>"ON",label=>"BLAH");
##
sub t2zfunction {
	my ($self,$val, $hashes, $paramstr) = @_;

	$val = undef;
	my $options = $self->parseparams($val,$hashes,$paramstr);

	my ($mod,$msub) = split(/\:\:/,$options->{'call'},2);
	my @params = ();
	foreach my $p (1..5) {
		next if (not defined $options->{'p'.$p});
		push @params, $options->{'p'.$p};
		}

	if ($mod eq 'ZTOOLKIT') {
		if ($msub eq 'dateValueRange') {
			$val = &ZTOOLKIT::dateValueRange(@params);
			# use Data::Dumper; print STDERR Dumper(@params);
			}
		}
	#elsif ($mod eq 'EBAY') {
	#	require EBAY2;
	#	if ($msub eq 'fetchStoreCats') {
	#		## EBAY::fetchStoreCats(eias=>"")
	#		## note: eias is the "ebay international seller attribute" or some shit like that.
	#		##			basically it's the name of their account that doesn't change even if the username does!
	#		##			catID, catPath, eBayUser
	#		##	hint: you probably want to pass rootonly=>1,eias=>"",
	#		my $resultref = &EBAY2::fetchStoreCats($self->username(),%{$options});
	#		$val = $self->spush("",@{$resultref});
	#		}
	#	}
	elsif ($mod eq 'UTILITY') {
		if ($msub eq 'strftime') {
			## call=>"UTILITY::strftime",str=>"%Y%m%s %H:%M:%S",ts=>$CREATED_GMT
			if (not defined $options->{'ts'}) { $options->{'ts'} = time(); }
			$val = POSIX::strftime($options->{'str'},localtime($options->{'ts'}));
			}
		}

	# print STDERR "ZFUNCTION RETURN[$val]\n";
	return($val);
	}

%TOXML::SPECL::t2functions = (
	'default'=>\&t2default,
	'strip'=>\&t2strip,
	'format'=>\&t2format,
	'math'=>\&t2math,
	'stop'=>\&t2stop,
	'sysmesg'=>\&t2sysmesg,
	'image'=>\&t2image,	
	'load'=>\&t2load,	
	'loadurp'=>\&t2loadurp,
	'loadobj'=>\&t2loadobj,
	'loadjson'=>\&t2loadjson,
	'ptr'=>\&t2ptr,
	'$'=>\&t2load,
	'print'=>undef,
	'runspec'=>\&t2runspec,
	'debug'=>\&t2debug,
	'set'=>\&t2set,
	'element'=>\&t2element,
	'tfu'=>\&t2tfu,
	'label'=>undef,
	'goto'=>undef,
	'if'=>undef,
	'pop'=>\&t2pop,
	'pull'=>\&t2pull,
	'count'=>\&t2count,
	'strindex'=>\&t2strindex,
	'str'=>\&t2str,
	'zfunction'=>\&t2zfunction,
	'urivars'=>\&t2urivars,
	);




##
## outputs a list of cgi variables
##		override=>"x=1&y=2"
##
sub t2urivars {
	my ($self,$val, $hashes, $paramstr) = @_;

	my $txt = '';
	my $ref = $SITE::v;
	my $options = $self->parseparams($val,$hashes,$paramstr);

	my $copy = 0;

	if ($options->{'override'}) {
		my $newref = &ZTOOLKIT::parseparams($options->{'override'});
		foreach my $k (keys %{$ref}) {
			next if (defined $newref->{$k});	# don't overwrite settings we've already got.
			$newref->{$k} = $ref->{$k};
			}
		$ref = $newref; $copy++;
		}

	if (defined $options->{'whitelist'}) {
		## WHITELIST: a comma separated list which is allowed to pass
		if (not $copy) {
			## we need to make a copy
			my %newref = %{$ref}; $ref = \%newref; $copy++;
			}

		my %pairs = ();
		foreach my $k (split(/\,/,$options->{'whitelist'})) { $pairs{$k}++; }
		foreach my $k (keys %{$ref}) {
			if (not defined $pairs{$k}) { delete $ref->{$k}; }
			}
		}

	if (defined $options->{'blacklist'}) {
		## BLACKLIST: a comma separated list which is never allowed to pass
		if (not $copy) {
			## we need to make a copy
			my %newref = %{$ref}; $ref = \%newref; $copy++;
			}
		foreach my $k (split(/\,/,$options->{'blacklist'})) {
			delete $ref->{$k};
			}
		}

#	use Data::Dumper;
#	print STDERR Dumper($options,$ref);
	
	($txt) = &ZTOOLKIT::buildparams($ref,1);
	return($txt);
	}

##
## loadobj: loads an object for use 
##		namespace=>"XXX"
##		type=>"product"
##			sku=>"sku"
##			variables are accessible XXX.owner.attrib e.g. XXX.zoovy.prod_name
##		
##
sub t2loadobj {
	my ($self,$val,$hashes,$paramstr) = @_;

	($val) = &t2load($self,$val,$hashes,$paramstr);

	return(&TOXML::RENDER::loadURP($self->_SITE(),$val));	
	}


##
## 
##


##
## count(stack=>>$list);
## returns:
##		the count of items in the stack
##		-1 if the stack is not initialized.
##
sub t2count {
	my ($self,$val,$hashes,$paramstr) = @_;

	my $options = $self->parseparams($val,$hashes,$paramstr);
	my $stack = undef;
	my $count = -1;

	$stack = $options->{'stack'};
	if (substr($options->{'stack'},0,1) eq '$') {
		($stack) = &t2load($self,$val,$hashes,$options->{'stack'});
		}

	if (defined $stack) {
		my @elements = split("\n",$stack);
		($count) = scalar(@elements);
		}

	return($count);
	}



##
## pull(stack=>>$list,format=>"urilist");
##	format: urilist
## 	title=Something&price=1
##		title=Somethinelse&price=1
##	HINT: use the urilist when you don't want to have a fixed number of parameters, this is especially handy
##			when there are a lot of optional parameters that may or may not be set.
##
## pull(stack=>>$list,format=>"textlist",delimiter=>"|",p0=>"title",p1=>"price");
## format: textlist
##		something|1.00
##		somethingelse|2.00
##		note: textlist will automatically create a "position" variable so you know which element in the list you're on.
##				positions start at 0.
##	HINT: This is the most difficult for the user to fuck up, since they aren't required to type the key.
##			The default delimiter is a "|", but we recommend you implicitly set | anyway.
##			Remember it's "delimiter" not "delimeter"  .. deli-meters are only used to measure meat.
##	
##	NOTE: you must have your text to add to the stack stored in $_ before calling the pull
##			one unit per line separated by \n\r's (cr/lf or just cr), blank lines will be ignored.
##			the variable $list will be created if it does not already exist (if it does, it will be appended to)
##
## pull(stack=>>$stack,format=>"src",src=>"seebelow",hidden=>"0|1");
##		src can be any of the following:
##			NAVCAT::.some.path
##				a stack of categories
##				each has: safe, pretty, products
##				
##			CART::STUFF
##				a stack of products in the cart
##				each has: stid, pid, sku, + data (e.g. zoovy:prod_name)
##
##			SHIP::countries (not implemented YET!)
##
sub t2pull {
	my ($self,$val,$hashes,$paramstr) = @_;

	my $options = $self->parseparams($val,$hashes,$paramstr);
	if (substr($options->{'stack'},0,1) eq '$') {
		my ($stack) = $self->t2load($val,$hashes,$options->{'stack'});

		if ((not defined $options->{'format'}) && (defined $options->{'src'})) {
			$options->{'format'} = 'src';
			}

		my @sets = ();
		if ($options->{'format'} eq 'urilist') {
			foreach my $line (split(/[\n\r]+/,$val)) {
				my $dataref = &ZTOOLKIT::parseparams($line);
				push @sets, $dataref;
				}
			}
		elsif ($options->{'format'} eq 'json_array') {
			foreach my $ref (@{JSON::XS::decode_json($stack)}) {
				push @sets, $ref;
				}
			}
#		elsif ($options->{'format'} eq 'json_hash') {
#			JSON::XS::decode_json($stack);
#			}
		elsif ($options->{'format'} eq 'textlist') {
			my $d = quotemeta($options->{'delimiter'});
			if (not defined $d) { $d = '|'; }		# default delimiter for a textlist is a |

			my $linedelim = qr/[\n\r]+/;
			if (defined $options->{'linedelimiter'}) { 
				$linedelim = $options->{'linedelimiter'}; 
				}

			my $count = 0;
			foreach my $line (split($linedelim,$val)) {
				my %data = ();
				next if ($line eq '');
				my @ar = split(/$d/,$line);	# 
				my $i = scalar(@ar);
				$data{'p'} = ++$count;		# this always creates a variable called "p" for position in the list (line #)

				while (--$i>=0) {
					## creates a hashref element "0" (position) as the key, with the corresponding value.
					$data{ $i } = $ar[$i];
					if (defined $options->{'p'.$i}) {
						## if the column 0 has a name e.g. "title", we make another key named "title" as well.
						$data{ $options->{'p'.$i} } = $ar[$i];
						}
					}
				push @sets, \%data;
				}
			}
		elsif ($options->{'format'} eq 'src') {
			## navcat: 

			## default to do not show hidden categories.
			if (not defined $options->{'hidden'}) { $options->{'hidden'} = 0;  }

			if ($options->{'src'} =~ /^NAVCAT\:\:(.*?)$/o) {
				my $path = $1;
				my ($NC) = $self->_SITE()->get_navcats();
				my ($results) = $NC->fetch_childnodes($path);

				foreach my $path (@{$results}) {
					my %data = ( 'safe'=>$path );
					($data{'pretty'}, undef, $data{'products'}, $data{'sort'}, my $metaref) = $NC->get($path);

					## skip hidden categories.
					next if (($options->{'hidden'}==0) && (substr($data{'pretty'},0,1) eq '!'));

					## CAT_THUMB
					foreach my $k (keys %{$metaref}) { $data{$k} = $metaref->{$k}; }
					push @sets, \%data;
					}
				undef $NC;
				}
			elsif ($options->{'src'} eq 'CART::STUFF') {
			
				my $stuff2 = $self->cart2()->stuff2();
				my @DEBUG = ();
				foreach my $item (@{$stuff2->items()}) {
					push @DEBUG, $item;
					if (($options->{'attribs'}>0) && (ref($item->{'%attribs'}) eq 'HASH')) {
						## if attribs=>1 is passed as a parameter to pull, then we converb %attribs into a flat hash to make it accessible.
						## zoovy:prod_upc becomes zoovy_prod_upc
						my %itemc = %{$item};
						foreach my $attr (keys %{$item->{'%attribs'}}) {
							my $attrcopy = $attr;
							$attrcopy =~ s/:/_/g;
							$itemc{$attrcopy} = $item->{'%attribs'}->{$attr};
							}
						delete $itemc{'%attribs'};
						$item = \%itemc;
						}
					push @sets, $item;
					}

				}
			elsif ($options->{'src'} eq 'CART::COUPONS') {
				&ZOOVY::confess($self->username(),"There is a good chance %coupons doesn't work",justkidding=>1);
			#	my $coupons = $self->cart2()->{'%coupons'};
			#	if ((defined $coupons) && (ref($coupons) eq 'HASH')) {
			#		foreach my $code (keys %{$coupons}) {
			#			my $coupon = $coupons->{'%coupons'}->{$code};
			#			push @sets, $coupon;
			#			}
			#		}
				}
			}
		else {
			warn("trying to pull for an unknown format");
			}

		## SANITY: at this point @sets contains lots of data hashrefs that want to be pushed onto the stack.
		if (scalar(@sets)>0) {
			($stack) = $self->spush($stack,@sets);
			t2set($self,$val,$hashes,{
				$options->{'stack'} => $stack, 
				});
			}
		
		}
	else {
		warn("tried to pull to an invalid stack");
		}

	return();
	}


##
## syntax:
##		pop(stack=>>$list,namespace=>"someprefix",type=>"lifo");
##	this will create variables:
##		someprefix.subcontent_of_ref.. effectively flattening the data struct.		
##
sub t2pop {
	my ($self,$val,$hashes,$paramstr) = @_;

	my $options = $self->parseparams($val,$hashes,$paramstr);
#	print STDERR Dumper($options)."\n";
	if (not defined $options->{'type'}) { $options->{'type'} = 'fifo'; }
#$VAR1 = {
#          'namespace' => 'foobar',
#          'stack' => '$payment_methods',
#          'type' => 'lifo'
#        };
	if (substr($options->{'stack'},0,1) eq '$') {
		my ($stack) = &t2load($self,$val,$hashes,$options->{'stack'});

		my $ref = {};

		if ($options->{'type'} eq 'lifo') {
			($stack,$ref) = $self->spoplast($stack);
			}
		elsif ($options->{'type'} eq 'fifo') {
			($stack,$ref) = $self->spopfirst($stack);
			}

		if (defined $options->{'namespace'}) {
			## changes var to $namespace.var so we don't whalefuck data.
			# print STDERR 'REFFFF!!!!'.Carp::confess(Dumper($ref));
			foreach my $k (keys %{$ref}) {
				$ref->{'$'.$options->{'namespace'}.'.'.$k} = $ref->{$k};
				delete $ref->{$k};
				}
			}

		# print STDERR 'SETTING: '.Dumper($options->{'stack'},$stack,$ref);
		
		t2set($self,$val,$hashes,{
			$options->{'stack'} => $stack, 
			%{$ref}
			});
		}
	else {
		warn("tried to pop from an invalid stack");
		}

	## hmm.. seems like we ought to return something!!		
	return();	
	}

##
## this will accept the same parameters as a READONLY element, it's just a faster way to call it.
##	loadurp("CART::xyz");
##
sub t2loadurp {
	my ($self,$val,$hashes,$paramstr) = @_;

	($val) = &t2load($self,$val,$hashes,$paramstr);
	my $r = &TOXML::RENDER::loadURP($self->_SITE(),$val);
	# print STDERR "T2LOADURP '$val'='$r'\n";
	return($r);	
	}

##
## mimics loadurp
##
sub t2loadjson {
	my ($self,$val,$hashes,$paramstr) = @_;

	($val) = &t2load($self,$val,$hashes,$paramstr);
	return(JSON::XS::encode_json(&TOXML::RENDER::loadURP($self->_SITE(),$val)));
	}


##
##
##
sub t2tfu {
	my ($self,$val,$hashes,$paramstr) = @_;

	my $options = $self->parseparams($val,$hashes,$paramstr);
	if (not defined $val) {
		return($options->{'undef'});
		}
	elsif (&ZOOVY::is_true($val)) {
		return($options->{'true'});
		}
	else {
		return($options->{'false'});
		}	
	}


sub translate3 {
	my ($self, $text,$hashes,%options) = @_;

	# return($text);

	unless (defined $text)   { $text = ''; }
	unless (defined $hashes) { $hashes = []; }
	my $replace_undef = defined($options{'replace_undef'}) ? num($options{'replace_undef'}) : 1 ;
	
	if ($text eq '') { return ''; }
	my $out = '';
	my $field = undef;
	my $option_str = undef;

	my $debug = 0;
	if (index($text,'DEBUG!')>=0) { 
		# $debug++; print STDERR "Debug on! [$text]\n"; print STDERR Dumper($hashes); 
		}

	## split up text into chunks.
	my $max_instructions = 100000;
	my @entries = (split /(\<[~\%].*?[~\%]\>)/so, $text);
	foreach my $entry (@entries)  {

		last if ($max_instructions<0);

		if (substr($entry,0,2) eq '<%') {
			## SPECL
			$entry = substr($entry,2); $entry = substr($entry,0,-2);	# chops <% and %>
			# print STDERR "ENTRY: [$entry]\n";
			## this is the code handler. e.g. cmd1(..);cmd2(..);
			my $val = undef;
			my $verb = undef;		## can be undef (continue) or "stop"
			my $result = undef;		# the result of the last operation
			my $line=0;

			my @lines = ();
			my $prefix = '';
			$entry =~ s/[\s]+(\/\* .*? \*\/)//gso;	# strip /* comments  */
			
			my %LABELS = ();	# a hashref of labels

			## i should really replace this with Parse::RecDescent

			## next we tokenize by splitting on ); 
			while ($entry =~ m/\G(.*?\);)/gcso) {
				my $line = $prefix.$1;
				# $line =~ s/[\n\r]+//gs;
				# $line =~ s/\/\*.*?\*\///gs;

				if ((($line =~ tr/\"//)%2)==1) {
					## count the number of " in the line, if it's an odd number, then keep running.
					## this handles print("print(&quot;crap&quot;);"); cases. 
					$prefix = $line;
					}
				else {
					$line=~ s/^[\s]+//gos;	# strip leading whitespace on cmdline.

					if ($line ne '') {		# don't push blank lines since they just generate errors.
						push @lines, $line;
						if (substr($line,0,1) eq ':') {
							$LABELS{uc(substr($line,1,-3))} = scalar(@lines)-1;		# sub 1 since we want the array location
							}
						}
					$prefix = '';
					}
				}

	
			if ($debug) {		
				# use Data::Dumper; print STDERR 'DEBUG: '.Dumper(\@lines,\%LABELS);			
				}

			my $cmdpos = 0; 
			my $end = scalar(@lines);

			while ( $cmdpos <= $end ) {
				# print STDERR sprintf("[%d] CMDPOS: $cmdpos\n",$max_instructions);
				my $cmdline = $lines[$cmdpos]; 

				last if ($max_instructions--<0);

				## now just cmd(param=>1,param=>2)	
				## still has problems with: cmd(param=>"1,param=>2")
				if ($cmdline =~ /^(.*?)\((.*)\)/os) {
					## found a valid command
					my ($cmd,$paramstr) = ($1,$2);	
					if ($cmd eq '') { $cmd = 'load'; }

					if (defined $TOXML::SPECL::t2functions{$cmd}) {
						($val,$verb) = $TOXML::SPECL::t2functions{$cmd}->($self,$val,$hashes,$paramstr);
						if ($debug) { print STDERR "CMD[$cmd] returned $val [$verb]\n"; }
						# if ($cmd eq 'runspec') { print STDERR "VAL[$val] VERB[$verb]\n"; }
						if ($verb eq 'stop') { $cmdpos = $end; }
						}
					elsif ($cmd eq 'print') {
						if ($paramstr eq '') { } else { ($val) = &t2load($self,$val,$hashes,$paramstr); }
						if (defined $val) {
							## note: must check to see if val is defined, else will set result to '' accidentally.
							$result .= $val;
							}
						}
#					elsif ($cmd eq 'if') {
#						
#						#if ($paramstr ne '') {
#						#	if (a=>$var1,op=>"eq|ne|lt|gt",b=>$var2,then=>cmd(somethingelse),else=>cmd(somethingelse));
#						#	}
#						}
					elsif ($cmd eq 'goto') {
						## goto:
						## 	if=>"true"|"false"|"undef", label=>"LABEL"
						##		eq=>_vartxt_, label=>"LABEL", 
						##		ne=>_vartxt_, label=>"LABEL", 
						##		lt=>_vartxt_, label=>"LABEL",
						##		gt=>_vartxt_, label=>"LABEL",
						##		nb=>_vartxt_, label=>"LABEL", (not blank)
						my $options = $self->parseparams($val,$hashes,$paramstr);
						my $newpos = $LABELS{uc($options->{'label'})}; 
			
						# print STDERR "GOTO NEW POSITION: $newpos [currently $cmdpos]\n";
						# print STDERR 'GOTO: '.Dumper($options);
						if (not defined $newpos) { 
							warn("Could not resolve line # for label [$options->{'label'}] - ending program");
							$newpos = $end; 
							$cmdpos = $newpos 
							}
	
						if (exists $options->{'unless'}) {
							if (not &ZOOVY::is_true($options->{'unless'})) { $cmdpos = $newpos; }
							}	
						elsif (exists $options->{'if'}) {
							if (&ZOOVY::is_true($options->{'if'})) { $cmdpos = $newpos; }
							}
						elsif (exists $options->{'eq'}) {
							if ($options->{'eq'} eq $val) { $cmdpos = $newpos; } 
							# print STDERR "CMDPOS IS NOW: $cmdpos since [$options->{'eq'} eq $val] next is: $lines[$cmdpos]\n";
							}
						elsif (exists $options->{'ne'}) {
							if ($options->{'ne'} ne $val) { $cmdpos = $newpos; }
							}
						elsif (exists $options->{'gt'}) {
							# print STDERR "goto if val[$val] > gt[$options->{'gt'}\n";
							if ($val > $options->{'gt'}) { $cmdpos = $newpos; } 
							# print STDERR "CMD POS: [$cmdpos] newpos[$newpos]\n";
							}
						elsif (exists $options->{'lt'}) {
							if ($options->{'lt'} > $val) { $cmdpos = $newpos; }
							}
						elsif (exists $options->{'undef'}) {
							if (not defined $options->{'undef'}) { $cmdpos = $newpos; }
							}
						elsif (exists $options->{'nb'}) {
							if ($options->{'nb'} ne '') { $cmdpos = $newpos; }
							}
						elsif (exists $options->{'ifempty'}) {
							if ($options->{'ifempty'} eq '') { $cmdpos = $newpos; }
							}
						elsif (exists $options->{'ifmore'}) {
							if (not defined $options->{'ifmore'}) { }
							elsif ($options->{'ifmore'} eq '') { }
							elsif ($options->{'ifmore'} ne '') { $cmdpos = $newpos; }
							}
						else {
							## no condition specified
							$cmdpos = $newpos;
							}
						# warn "CMDPOS: $cmdpos\n";
						}
					elsif ($cmd eq 'initset') {
						if (not defined $options{'initref'}) { 
							warn "initref not set, but initset was called\n";
							$options{'initref'} = {}; 
							}
						my ($keyvalues2set) = $self->parseparams($val,$hashes,$paramstr);
						foreach my $k (keys %{$keyvalues2set}) {
							$options{'initref'}->{$k} = $keyvalues2set->{$k};
							}
						#use Data::Dumper;
						#print STDERR Dumper({val=>$val,hashes=>$hashes,paramstr=>$paramstr,keyvalueset=>$keyvalues2set});
						}
					elsif (substr($cmdline,0,1) eq ':') {}	# it's just a label and can be ignored.
					else {
						$cmdpos = $end;
						$val = "Translation error at line $cmdpos cmd[$cmd] cmdline[$cmdline] LAYOUT[".$self->_SITE()->docid()."] FS[".$self->_SITE()->fs()."]";
						warn($val);
						}

					}
				elsif ($cmdline eq '') {}
				else {
					## could not find a valid command
#					print STDERR "(Missing valid command! cmdline=[$cmdline]\n";
					}
				$cmdpos++;
				}

			# print STDERR "RESULT:[$result]\n";


			if ((not defined $result) && (not $replace_undef)) {
				$result = "<% $entry %>";
				}
			$out .= $result;
			undef $result;

			if ($SITE::v->{'_spec'} == 2) { $out .= '['.$entry.']'; }
			}
		else {
			## HTML: non code block.
			$out .= $entry;
			}
		}
	
	if ($max_instructions<0) {
		warn "reached max instructions\n";
		open F, ">>/tmp/err.rmaxinstructions";
		print F $self->username()."\t$text\n";
		close F;
		}

	return($out);
	}


		

##
## Purpose: Tries a series of hashes to see if a key is present
## Accepts: A key and a reference to an array of hashes
## Returns: The first value found (hashes are searched in order) or undef if not found in any hash
## Note:    For speed no error checking is performed.
##
sub find_in_hashes {
	my ($entry,$hashes) = @_;
	
	## this allows a scalar value to be passed in without substitution
	##	e.g. !asdf returns just "asdf" without needing a variable set to "asdf"
	if (substr($entry,0,1) eq '!') { return(substr($entry,1)); }

   foreach (@{$hashes}) { defined($_->{$entry}) && return($_->{$entry}); }
	return undef;
	}



sub smartstrip {
	my ($html, $len, $dont_strip_html, $dont_strip_breaks) = @_;
	return '' unless defined($html);

	if (not defined $len)                  { $len                  = 0; }
	if (not defined $dont_strip_html)   { $dont_strip_html   = 0; }
	if (not defined $dont_strip_breaks) { $dont_strip_breaks = 0; }

	if (not $dont_strip_html) {
		## if strip HTML.
		$html =~ s/\s+/ /gso;		# removes unnecessary spaces (since we're going to truncate and 2+ spaces don't matter in HTML)
		$html =~ s/<(\/?[BbIiUu])>/"[".lc($1)."]"/eog;	
		if ($dont_strip_breaks) { 
			## translates <br> or <p> to [br] and [p]
			$html =~ s/<([Bb][Rr]|\/?[Pp])>/"[".lc($1)."]"/eog; 
			}
		$html =~ s/\<.*?\>//gso;	# strip html tags
		$html =~ s/[\<\>]+//gso;	# strip any straggling < and > tags (stupid users!)
		$html =~ s/\[(\/?[biu]+)\]/\<$1\>/go;
		if ($dont_strip_breaks) { 
			## replaces the [br] to <br>
			$html =~ s/\[(br|\/?p)\]+/\<$1\>/go; 
			}
		}

	my $adddots = 0;
	if ($len && (length($html) > ($len - 3))) {
		$html = substr($html, 0, ($len - 3));
		$html =~ s/\<[^\>]*$//og;    # Catch any cut-off HTML tags
		$adddots = 1;
		}
	# Make sure we have balanced pairs of <b><i><s> (they could have been cut off)
	while (($html =~ s/<[Bb]>/<b>/og) > ($html =~ s/<\/[Bb]>/<\/b>/og)) { $html .= '</b>'; }
	while (($html =~ s/<[Ii]>/<i>/og) > ($html =~ s/<\/[Ii]>/<\/i>/og)) { $html .= '</i>'; }
	while (($html =~ s/<[Ss]>/<s>/og) > ($html =~ s/<\/[Ss]>/<\/s>/og)) { $html .= '</s>'; }
	if ($adddots) { $html .= '...'; }

	return $html;
	} ## end sub smartstrip


##
## RENDER::LIST::array_param
## 
## Returns a arrayref
## If passed and arrayref it sends it back
## If passed a scalar, it sends back a ref to the scalar split by commas
## Anything else it sends back an empty array
##
## Needed to be able to handle sub-lists 'cause we can only pass list parameters as scalar
## if we're chunking the options from a text file
sub array_param {
	my ($array) = @_;
	if (not defined $array) { return (); }
	elsif (ref $array eq 'ARRAY') { return @{$array}; }
	elsif (not ref $array) { return split(/\,/, $array); }
	else { return (); }
	}



##
## parameters:
##		spec is the list
##		tag is the tag we're looking for
##
sub extract_comment {
	my ($self, $spec,$tag) = @_;
	if (not defined $spec) { $spec = ''; }
	if (not defined $tag) { $tag = qr/\w+/o; }
	$tag =~ s/\W//go;
	my $head = '';
	my $attribs = '';
	my $options = {};
	my $contents = '';
	my $foot = '';
	my $found_tag = '';
	my $remainder = $spec;
	## explanation of the variables:
	##		^[HEAD]<!--[FOUND_TAG] [ATTRIBS]-->[CONTENTS]<!--[FOUND_TAG]-->[FOOT]$
	if (($head,$found_tag,$attribs,$contents,$foot) = $spec =~ m/^(.*?)\<\!\-\-\s*($tag)\s*(.*?)\s*\-\-\>(.*?)\<\!\-\-\s*\/\2\s*\-\-\>(.*?)$/is) {
#		warn ("found tag '$found_tag'");
		$attribs = " $attribs ";
		$remainder = "$head$foot";
		while ($attribs =~ s/\s(\w+)\s*\=\s*\"(.*?)\"\s/ /os) { $options->{$1} = $2; }
		}
#	if (scalar %{$options}) { warn ($options,'*options'); }
	return ($contents,$remainder,$head,$foot,$options,$found_tag);
	}


sub parse_data { return(&TOXML::RENDER::parse_prodlist_data(@_)); }
