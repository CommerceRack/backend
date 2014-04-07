package TEMPLATE::KISS;

use URI::URL;
use Data::Dumper;
use CSS::Tiny;
use HTML::TreeBuilder;
use Text::WikiCreole;
use File::Slurp;
use HTML::TreeBuilder;

use strict;
use lib "/backend/lib";

require ZOOVY;
require LISTING::MSGS;
require TLC;



## 
sub getFields {
   my ($el,$EXISTSREF,$FIELDSREF) = @_;

	if (not defined $FIELDSREF) { $FIELDSREF = []; }
	if ( ($el->attr('data-object') eq 'PRODUCT') && 
			($el->attr('data-attrib') ne '') && 
			($el->attr('data-label') ne '') ) {
		my %flex = ();
		$flex{'title'} = $el->attr('data-label');
		$flex{'ns'} = 'product';
		$flex{'id'} = $el->attr('data-attrib');
		$flex{'type'} = $el->attr('data-input-type');
		if ((not defined $flex{'type'}) && ($el->tag() eq 'img')) {	$flex{'type'} = 'image'; }
		if (not defined $flex{'type'}) {	$flex{'type'} = 'textbox'; }
			
		if (not defined $EXISTSREF->{$flex{'id'}}) {
			push @{$FIELDSREF}, \%flex;
			$EXISTSREF->{ $flex{'id'} } = \%flex;
			}
		}

   foreach my $elx (@{$el->content_array_ref()}) {
      if (ref($elx) eq '') {
         ## just content!
         }
      else {
         &getFields($elx,$EXISTSREF,$FIELDSREF);
         }
      }
	return($FIELDSREF);	
	}


##
## returns the product input fields for an html template
##
sub getFlexedit {
	my ($USERNAME,$PROFILE) = @_;
	my @FIELDS = ();

	my $userpath = &ZOOVY::resolve_userpath($USERNAME);
	my $file = "$userpath/IMAGES/_ebay/$PROFILE/index.html";

	my $html = '';
	if (-f $file) { $html = File::Slurp::read_file($file); }

	my $tree = HTML::TreeBuilder->new(no_space_compacting=>1,ignore_unknown=>0,store_comments=>1); # empty tree
	$tree->parse_content($html);

	my %EXISTS = ();		
	my %META = ();
   my $el = $tree->elementify();
	&loadMeta($el,\%META);
	my $FIELDSREF = &getFields($el,%EXISTS);	

	return($FIELDSREF);
	}



sub attribsToTag {
	my ($tag,$attribs,$innerhtml) = @_;

	my $htmltag = "<$tag";
	foreach my $k (sort keys %{$attribs}) {
		$htmltag .= " $k=\"".&ZOOVY::incode($attribs->{$k})."\"";
		}
	if ($tag eq 'img') {
		$htmltag .= ' />';
		}
	else {
		if ($innerhtml ne '') { $innerhtml = "\n$innerhtml"; }
		$htmltag .= ">$innerhtml</$tag>\n";
		}
	return($htmltag);
	}




sub loadMeta {
   my ($el,$meta) = @_;

 	if ($el->tag() eq 'meta') {
		$meta->{ $el->attr('name') } = $el->attr('content');
      }

   foreach my $elx (@{$el->content_array_ref()}) {
      if (ref($elx) eq '') {
         ## just content!
         }
      else {
         ## print "-- ".$elx->tag()."\n";
         &loadMeta($elx,$meta);
         }
      }
	return($el);	
	}


##
## 
##
sub render_kiss1 {
   my ($meta,$el) = @_;

	my @PRODUCT_INPUTS = ();

	my $MSGS = $meta->{'@MSGS'};
	if (not defined $MSGS) { $meta->{'@MSGS'} = $MSGS = []; }

	my $ATTR = $el->attr('data-attrib');
	# print STDERR "ATTR:$ATTR\n";

	my $data_object = uc($el->attr('data-object'));
	my $VALUE = undef;
	if ($data_object eq 'PRODUCT') {
		my ($P) = $meta->{'*PRODUCT'};
		if (not defined $P) {
			push @{$MSGS}, sprintf("ERROR|+template $meta->{'$CONTAINERTYPE'}/$meta->{'$CONTAINER'} called data-object=\"PRODUCT\" with no product in focus.",$meta->{'$TEMPLATE'});
			}
		else {
			# print STDERR Dumper($meta);
			$VALUE = $P->fetch( $el->attr('data-attrib') );
			}
		}

	if (my $if = $el->attr('data-if')) {
		# data-if=BLANK|NULL|NOTBLANK|NOTNULL|MATCH:|NOTMATCH:
		# data-then=REMOVE|SET:xyz|FORMAT:xyz
		my $is_true = undef;
		if 	($if eq 'BLANK') 		{  $is_true = ($VALUE eq '')?1:0; }
		elsif ($if eq 'NOTBLANK')	{  $is_true = ($VALUE ne '')?1:0; }
		elsif ($if eq 'NULL') 		{  $is_true = (defined $VALUE)?1:0; }
		elsif ($if eq 'NOTNULL')	{  $is_true = (not defined $VALUE)?1:0; }
		elsif ($if eq 'TRUE')	{  $is_true = (&ZOOVY::is_true($VALUE))?1:0; }
		elsif ($if eq 'FALSE')	{  $is_true = (not &ZOOVY::is_true($VALUE))?1:0; }
		elsif ($if =~ /^(GT|LT|EQ)\/([\d\.]+)\/$/) 	{  
			my ($OP,$OPVAL) = ($1,$2);  
			$OPVAL = int($OPVAL*1000); 
			$VALUE=int($VALUE*1000);
			$is_true = undef;
			if ($OP eq 'GT') { $is_true = ($VALUE > $OPVAL)?1:0; }
			elsif ($OP eq 'LT') { $is_true = ($VALUE < $OPVAL)?1:0; }
			elsif ($OP eq 'EQ') { $is_true = ($VALUE == $OPVAL)?1:0; }
			elsif ($OP eq 'NE') { $is_true = ($VALUE == $OPVAL)?1:0; }
			}
		elsif ($if =~ /^REGEX\/(.*?)\/$/) 	{  $is_true = ($VALUE =~ /$1/)?1:0; }
		elsif ($if =~ /^NOTREGEX\/(.*?)\/$/)	{  $is_true = ($VALUE !~ /$1/)?1:0; }

		if (not defined $is_true) {}
		elsif ($is_true) { 
			$el->attr('data-else',undef);
			$is_true = $el->attr('data-then');  }
		else { 
			$el->attr('data-then',undef);		
			$is_true = $el->attr('data-else'); 
			## if (not defined $is_true) { $is_true = 'IGNORE'; }	## this line is evil, because $IGNORE sets $VALUE to undef
			if (not defined $is_true) { 
				$is_true = 'PROCEED'; 
				}
			}

		if (not defined $is_true) {}												## else behavior will auto-populate data.
		# elsif ($is_true eq 'REMOVE') { $el->delete(); $el = undef; }	## remove the tag and all children
		elsif (($is_true eq 'REMOVE') || ($is_true eq 'EMPTY')) { 
			## remove the tag and all children
			$el->delete_content();
			if ($is_true eq 'REMOVE') { $el->replace_with(""); }
			## NOTE DO NOT USE $el->delete() it doesnt work.
			$el = undef;
			$VALUE = undef;
			}
		elsif ($is_true eq 'IGNORE') { $VALUE = undef; }					## not sure "ignore" is the best name for this.
		elsif ($is_true eq 'INNER')  { $VALUE = undef; }					## process the inner html
		elsif ($is_true eq 'PROCEED') { }										## continue with interpolation as if nothing has happened.
		# elsif ($is_true eq 'FORMAT') { $el->delete(); $el = undef; }
		}

	# if (defined $ATTR) { print "$ATTR VALUE:$VALUE\n";	}
	# data-attrib="zoovy:prod_image4" data-input-width="0"  data-object="product" data-type="imagelink"  data-input-bgcolor="ffffff" data-input-border="0" data-input-title="Image 4" href="#"
	if (not defined $el) {
		}
	elsif (not defined $VALUE) {
		}
	else {
		my $format = $el->tag();
		if ($el->attr('data-format') ne '') { $format = $el->attr('data-format'); }
		$format = lc($format);

		if ($format eq 'img') {
			## <a id="link_IMAGE1"  data-input-height="0"  id="IMAGE1" data-attrib="zoovy:prod_image1" data-input-width="0"
		   ## data-object="product" data-type="imagelink"  data-input-bgcolor="ffffff" data-input-border="0"
      	## data-input-title="Image 1" href="#">
			my %options = ();
			if ($el->attr('data-img-height')) { $options{'H'} = $el->attr('data-img-height'); }
			if (($format eq 'img') && ($el->attr('height')>0)) { $options{'H'} = $el->attr('height'); }
			if ($el->attr('data-img-width')) { $options{'W'} = $el->attr('data-img-width'); }
			if (($format eq 'img') && ($el->attr('width')>0)) { $options{'W'} = $el->attr('width'); }
			if ($el->attr('data-img-bgcolor')) { $options{'B'} = $el->attr('data-img-bgcolor'); }
			if ($el->attr('data-img-minimal')) { $options{'M'} = $el->attr('data-img-minimal'); }
			$VALUE = sprintf("//%s%s",&ZOOVY::resolve_media_host($meta->{'$USERNAME'}),&ZOOVY::image_path($meta->{'$USERNAME'},$VALUE,%options));
			if ($el->tag() eq 'a') {
				$el->attr('href',$VALUE);
				}
			elsif ($el->tag() eq 'img') {
				$el->attr('src',$VALUE);
				}
			}
		elsif ($format eq 'a') {
			$el->attr('href',$VALUE);
			}
		elsif ($format =~ /^(wiki|html|dwiw|td|div|span|p|q|h1|h2|h3|h4|h5|h6|figcaption|section|article|aside|li)$/) {
			# $el->replace_with_content($VALUE); 

			if ($format eq 'dwiw') {
				## detect what i want 
				$format = ($VALUE =~ /<.*?>/)?'html':'wiki';
				}

			if ($format eq 'wiki') {
				$VALUE = &Text::WikiCreole::creole_parse($VALUE);
				# print "VALUE: $VALUE\n";
   	      # $VALUE = "\n<!-- WIKI -->\n-$VALUE-\n<!-- WIKI -->\n";
				$format = 'html';
				}

			if ($format eq 'html') {
				## we're inserting html so we build a new tree, gut it, then push that.
				my ($fragment) = HTML::TreeBuilder->new(no_space_compacting=>1,ignore_unknown=>0,store_comments=>1)->parse($VALUE);
				$el->replace_with($fragment->guts())->delete;
				# $el->replace_with($fragment->guts());
				}
			else {
				## just text, so we can embed that.
				$el->delete_content();
				$el->push_content($VALUE);
				}
			}		
		elsif ($format eq 'currency') {
			$el->delete_content();
			$el->push_content(sprintf("\$%0.2f",$VALUE));
			}
		elsif ($format eq $el->tag()) {
			## this is fine!
			}
		else {
			$el->delete_content();
			$el->push_content(sprintf("[unhandled data-format %s]",$format));			
			}
      }

	if (defined $el) {
	   foreach my $elx (@{$el->content_array_ref()}) {
			if (ref($elx) eq '') {
				## just content!
				}
			else {
				&render_kiss1($meta,$elx);
	         }
			}
		}
   return();
   }


##
##
##
## perl -e 'use Data::Dumper; use lib "/backend/lib"; use TEMPLATE::KISS; $USERNAME=""; $PID=""; $PROFILE="";
## print Dumper(TEMPLATE::KISS::render($USERNAME,"EBAY","$PROFILE","*PRODUCT"=>PRODUCT->new($USERNAME,"$PID")));'
##

sub render {
	my ($USERNAME,$TYPE,$CONTAINER,%options) = @_;

	my $MSGS = $options{'@MSGS'};

	my $userpath = &ZOOVY::resolve_userpath($USERNAME);

	my $filepath = undef;
	my $filename = 'index.html';		## long term we might load a different one based on type of device.

	if ($TYPE eq 'EBAY') { $filepath = "$userpath/IMAGES/_ebay/$CONTAINER/$filename"; }
	if ($TYPE eq 'CPG')  { $filepath = "$userpath/IMAGES/_campaigns/$CONTAINER/$filename"; }

	my $html = '';
	## /remote/bespin/users/brian/IMAGES/_ebay/ASDF/index.html
	if (-f $filepath) { 
		$html = File::Slurp::read_file($filepath); 
		if ($html eq '') {
			if (defined $MSGS) { push @{$MSGS}, "ERROR|+$filename in container $CONTAINER found but empty."; }
			}
		}
	else {
		if (defined $MSGS) { push @{$MSGS}, "ERROR|+$filename file not found in container $TYPE/$CONTAINER"; }
		}

	my $tree = HTML::TreeBuilder->new(no_space_compacting=>1,ignore_unknown=>0,store_comments=>1); # empty tree
	$tree->parse_content($html);

	my %META = ();
	$META{'@MSGS'} = $MSGS;
   my $el = $tree->elementify();
	&loadMeta($el,\%META);
	foreach my $k (keys %options) { $META{$k} = $options{$k}; }	## necessary for ebay refresh *PRODUCT ref

	if ($META{'version'} eq '') {
		if (defined $MSGS) { push @{$MSGS}, "ERROR|+template $TYPE/$CONTAINER cannot render index.html missing meta 'version' tag (try kiss/1.0)"; }
		}
	elsif ($META{'version'} eq 'tlc/1.0') {
		my ($TLC) = TLC->new('username'=>$self->username());
		$META{'USERNAME'} = $USERNAME;
		$META{'CONTAINERTYPE'} = $TYPE;
		$META{'CONTAINER'} = $CONTAINER;
		if ($META{'SKU'}) {
			$META{'SKU'} = $META{'SKU'};
			$META{'%PRODUCT'} = $options{'*PRODUCT'}->TO_JSON();
			if (not defined $options{'*PRODUCT'}) {
				$META{'%PRODUCT'} = PRODUCT->new($USERNAME,$META{'SKU'})->TO_JSON();
				}
			}
		if ($META{'CID'}) {
			$META{'CID'} = $META{'CID'};
			$META{'PRT'} = $META{'PRT'};
			$META{'%CUSTOMER'} = $options{'*CUSTOMER'}->TO_JSON();
			if (not defined $options{'*CUSTOMER'}) {
				$META{'%CUSTOMER'} = CUSTOMER->new($USERNAME,'PRT'=>$META{'PRT'},'CID'=>$META{'CID'})->TO_JSON();
				}
			}
		($html) = $tlc->render_html($html, \%META);
		}
	elsif ($META{'version'} eq 'kiss/1.0') {
		$META{'$USERNAME'} = $USERNAME;
		$META{'$CONTAINERTYPE'} = $TYPE;
		$META{'$CONTAINER'} = $CONTAINER;
		if ($META{'SKU'}) {
			$META{'$SKU'} = $META{'SKU'};
			$META{'*PRODUCT'} = $options{'*PRODUCT'};
			if (not defined $options{'*PRODUCT'}) {
				$META{'*PRODUCT'} = PRODUCT->new($USERNAME,$META{'SKU'});
				}
			}
		if ($META{'CID'}) {
			$META{'$CID'} = $META{'CID'};
			$META{'$PRT'} = $META{'PRT'};
			$META{'*CUSTOMER'} = $options{'*CUSTOMER'};
			if (not defined $options{'*CUSTOMER'}) {
				$META{'*CUSTOMER'} = CUSTOMER->new($USERNAME,'PRT'=>$META{'PRT'},'CID'=>$META{'CID'});
				}
			}
		&render_kiss1(\%META,$el);	
		$html = $el->as_HTML();
		}
	else {
		# warn("Unhandled api version \"$META{'version'}\"\n");
		if (defined $MSGS) { push @{$MSGS}, "ERROR|+$TYPE/$CONTAINER/index.html contains invalid meta 'version' try kiss/1.0"; }
		}

	return($html);
	}















####################################################################################################


##
## ebay doesn't allow base urls, or meta tags so this rewrites the document.
##
## my $html = File::Slurp::read_file('index.html');
## print ebayify_html($html);
##
sub ebayify_html {
	my ($HTML) = @_;

	my $tree = HTML::TreeBuilder->new(no_space_compacting=>1,ignore_unknown=>0,store_comments=>1); # empty tree
	$tree->parse_content("$HTML");
	my %META = ();

	my $el = $tree->elementify();
	&ebay_parseElement($el,\%META);
	$HTML = $el->as_HTML();

	$HTML =~ s/\<([\/]?[Mm][Ee][Tt][Aa].*?)\>/<!-- $1 -->/gs;   ## ebay doesn't allow metas
	$HTML =~ s/\<([\/]?[Bb][Aa][Ss][Ee].*?)\>/<!-- $1 -->/gs;   ## ebay doesn't allow base urls
	return($HTML);
	}

sub ebay_parseElement {
	my ($el, $METAREF) = @_;

	if ($el->tag() eq 'base') {
		$METAREF->{'base'} = $el->attr('href');
		}

	if (not $METAREF->{'base'}) {
		}
	elsif ($el->tag() eq 'a') {
		## <a href="">
		$el->attr('href',URI::URL->new($el->attr('href'),$METAREF->{'base'})->abs());
		}
	elsif ($el->tag() eq 'img') {
		## <img src="">
		$el->attr('src',URI::URL->new($el->attr('src'),$METAREF->{'base'})->abs());
		}
	elsif ($el->tag() eq 'style') {
		my $sheet = $el->as_HTML();
		$sheet =~ s/\<[Ss][Tt][Yy][Ll][Ee].*?\>(.*)\<\/[Ss][Tt][Yy][Ll][Ee]\>/$1/s;
		$sheet =~ s/\<\!\-\-(.*)\-\-\>/$1/s;

		my $CSS = CSS::Tiny->new()->read_string($sheet);
		foreach my $property (keys %{$CSS}) {
			foreach my $k (keys %{$CSS->{$property}}) {
				if ($CSS->{$property}->{$k} =~ /^[Uu][Rr][Ll]\((.*?)\)/) {
					my $url = $1;
					my $absurl = URI::URL->new($url,$METAREF->{'base'})->abs();
					$CSS->{$property}->{$k} =~ s/^[Uu][Rr][Ll]\(.*?\)/url($absurl)/;
					}
				}
			}
		$sheet = $CSS->html();
		my $sheetnode = HTML::Element->new('style','type'=>'text/css');
		$sheetnode->push_content("<!-- \n".$CSS->write_string()."\n -->");
		$el->replace_with($sheetnode);
		}
	
	if (not $METAREF->{'base'}) {
		}
	elsif ($el->attr('style') ne '') {
		## parse the style tag
		# print $el->attr('style')."\n";
		my $sheet = sprintf("style { %s }",$el->attr('style'));
		my $CSS = CSS::Tiny->new()->read_string($sheet);
		foreach my $k (keys %{$CSS->{'style'}}) {
			if ($CSS->{'style'}->{$k} =~ /^[Uu][Rr][Ll]\((.*?)\)/) {
				my $url = $1;
				my $absurl = URI::URL->new($url,$METAREF->{'base'})->abs();
				$CSS->{'style'}->{$k} =~ s/^[Uu][Rr][Ll]\(.*?\)/url($absurl)/;
				}
			}
		$sheet = $CSS->write_string();
		$sheet =~ s/\n/ /gs;
		$sheet =~ s/\t/ /gs;
		$sheet =~ s/[\s]+/ /gs;
		$sheet =~ s/^.*?\{(.*)\}/$1/gs;
		$sheet =~ s/^[\s]+//gs;
		$sheet =~ s/[\s]+$//gs;
		$el->attr('style',$sheet);
		}

	foreach my $elx (@{$el->content_array_ref()}) {
		if (ref($elx) eq '') {
			}
		else {
			&ebay_parseElement($elx,$METAREF);
			}
		}

	}







1;

__DATA__

perl -e 'use lib "/backend/lib"; 
	use TEMPLATE::KISS;  
	use Data::Dumper; print Dumper(TEMPLATE::KISS::render("brian","ASDF","TEST"));
	';
