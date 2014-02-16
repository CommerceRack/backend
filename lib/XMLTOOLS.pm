package XMLTOOLS;
use strict;

sub currency {
	my ($attrib,$var) = @_;

	# print STDERR "[$attrib] VAR[$var]=[".sprintf("%.2f",$var)."]\n";
	return("<$attrib currencyID=\"USD\">".sprintf("%.2f",$var)."</$attrib>");
	}

sub boolean {
	my ($val) = @_;
	$val = uc(substr($val,0,1));
	if (($val eq 'T') || ($val eq 'Y') || (int($val)>0)) { $val = 'true'; } else { $val = 'false'; }
	return($val);
	}

## strips out nasty characters which break XML::Parser
sub clean_xml {
	my ($content) = @_;

	my $x = '';
	foreach my $ch (split(//,$content)) {
		next if (ord($ch)==26);
		$x .= $ch;
		}
	return($x);
}

sub getXMLstring {
	my ($tree,$path) = @_;

	my @ar = split(/\./,$path);
	foreach $a (@ar) {
		# now looking for 
		my $done = 0;
#		print "Now looking for $a [$done]\n";
		foreach my $node (@{$tree}) {
#			print "Checking: $node->{'name'}\n";
			next if ($node->{'type'} ne 'e');
			
			next unless ($node->{'name'} eq $a);
#			print "Found $node->{'name'} == $a\n";
#			print Dumper($node);
			$done++;
			$tree = $node->{'content'};
			}	

#		print "Done is: [$done]\n";
		if ($done==0) { return(undef); }
		}

#	print Dumper($tree);
	return($tree->[0]->{'content'});

	}

sub chopXMLtree {
	my ($tree,$path) = @_;

	my @ar = split(/\./,$path);
	foreach my $a (@ar) {
		# now looking for 
		my $done = 0;
#		print "Now looking for $a [$done]\n";
		foreach my $node (@{$tree}) {
#			print "Checking: $node->{'name'}\n";
			next unless (defined $node->{'name'});
			next unless ($node->{'name'} eq $a);
#			print "Found $node->{'name'} == $a\n";
#			print Dumper($node);
			$done++;
			$tree = $node->{'content'};
			}	

#		print "Done is: [$done]\n";
		if ($done==0) { return(undef); }
		}

#	print Dumper($tree);
	return($tree);

	}

sub XMLcollapse {
	my ($arref,$ix) = @_;
	my %hash = ();
	
	if (defined $ix) { $ix = $ix.'.'; } else { $ix = ''; }
	# use Data::Dumper;
	# print STDERR Dumper($arref);
	foreach my $i (@{$arref}) {
		next if ($i->{'type'} ne 'e');
		$hash{$ix.$i->{'name'}} = $i->{'content'}->[0]->{'content'};
		if (scalar($i->{'content'})) {
			my $fooref = &XMLcollapse($i->{'content'},$ix.$i->{'name'});
			foreach my $k (keys %{$fooref}) {
				$hash{$k} = $fooref->{$k};
				}
			}
		## handle any attributes.
		if (defined $i->{'attrib'}) {
			foreach my $k (keys %{$i->{'attrib'}}) {
				$hash{"$ix~$k"} = $i->{'attrib'}->{$k};
				}
			}
		}
	return(\%hash);
}

sub XMLcollapseOLD {
	my ($arref) = @_;
	my %hash = ();
	
	# use Data::Dumper;
	# print STDERR Dumper($arref);
	foreach my $i (@{$arref}) {
		next if ($i->{'type'} ne 'e');
		$hash{$i->{'name'}} = $i->{'content'}->[0]->{'content'};
		}
	return(\%hash);
}


##
sub stripNasty {
	my ($str) = @_;

	my $new = '';
	foreach my $ch (split(//,$str)) {
		if (ord($ch)<32) { 
			}
		elsif (ord($ch)>127) {
			}
		else {
			$new .= $ch;
			}
		}

	return($new);
}



sub xml_decode
{
	my ($str) = @_;
	$str =~ s/\&lt\;/\</g;
	$str =~ s/\&gt\;/\>/g;
	$str =~ s/\&quot\;/\"/g;
	$str =~ s/\&amp\;/\&/g;
	while ($str =~ /\&\#([\d]+)\;/)
	{
		my $found = $1;
		my $ch = chr($1);
		$str =~ s/\&\#$found\;/$ch/g;
	}
	return ($str);
}

##
## note: this is a cheap XML incode, it only does the upper 128 bytes, which is probably safe.
##
sub xml_incode
{
	my ($str) = @_;
	if (not defined $str) { $str = ''; }
	my $new = '';
	foreach my $c (split (//, $str))
	{
		if (ord($c) >= 127)
		{
			if ($c eq '>' || $c eq '<' || $c eq '&') { $new .= $c; }
			else { $new .= '&#' . ord($c) . ';'; }
		}
		else
		{
			if    ($c eq '&') { $new .= '&amp;'; }
			elsif ($c eq '>') { $new .= '&gt;'; }
			elsif ($c eq '<') { $new .= '&lt;'; }
			elsif ($c eq '"') { $new .= '&quot;'; }
			elsif (ord($c) == 18) { $new .= ''; }
			else { $new .= $c; }
		}
	}
	return ($new);
}

##
## Purpose: converts a buffer from ZML to XML
## Parameters: reference to ZML buffer (\$buffer)
##
sub zml_to_xml
{
	my ($BUF_REF) = @_;
	# Build the namespace because <zoovy:name> isn't valid
	study(${$BUF_REF});
	my %hash = ();
	my @chunks = split (/(<.*?>)/s, ${$BUF_REF});
	foreach my $chunk (@chunks)
	{
		# match all tags that don't have a </.*?> and 
		# split them into $1 = owner, $2 = tag
		if ($chunk =~ /^<([^\/].*?):(.*?)>$/) { $hash{$1} .= "$2,"; }
	}
	my $tmp = '';
	foreach my $owner (keys %hash)
	{
		chop($hash{$owner});
		$tmp .= "<$owner>\n";
		foreach my $tag (split (',', $hash{$owner}))
		{
			if (${$BUF_REF} =~ /\<$owner\:$tag\>(.*?)\<\/$owner:$tag\>/s) { $tmp .= "  <$tag>" . &xml_incode($1) . "</$tag>\n"; }
		}
		$tmp .= "</$owner>\n";
	}
	${$BUF_REF} = $tmp;
	return (0);
} ## end sub zml_to_xml

##
## Purpose: converts a buffer from XML to ZML
## Parameters: reference to XML buffer (\$buffer)
##
## note: this *might* cheese if the XML buffer has nested HTML 
##       eg: </somevalue: 10px> but its pretty unlikely since it must have
##       both a : and begin with a / and thats an illegal HTML entity.
##
## this takes the speedy route.
## 
sub xml_to_zml
{
	my ($BUF_REF) = @_;
	study(${$BUF_REF});
	${$BUF_REF} =~ s/<\/(.*?):(.*?)\>/<\/$2\>/gs;
	return (0);
}

##
## These are some functions that Brian came up with to easily work with XML
## parsed through XML::Parser::EasyTree
##

## This returns just a branch off of an EasyTree tree...
sub prune_easytree
{
	my ($tree, $path) = @_;
	my @ar = split (/\./, $path);
	foreach my $a (@ar)
	{
		my $done = 0;
		foreach my $node (@{$tree})
		{
			next unless (defined $node->{'name'});
			next unless ($node->{'name'} eq $a);
			$done++;
			$tree = $node->{'content'};
		}
		if ($done == 0) { return (undef); }
	}
	return ($tree);
}

## This returns just the contents of a branch off an EasyTree tree
sub get_easytree_contents
{
	my ($tree, $path) = @_;
	my $new_tree = chopXMLtree($tree,$path);
	return ($new_tree->[0]->{'content'});
}

## I'm not quite sure what this does but I copied it over for good measure
sub collapse_easytree
{
	my ($arref) = @_;
	my %hash = ();
	foreach my $i (@{$arref})
	{
		$hash{$i->{'name'}} = $i->{'content'}->[0]->{'content'};
	}
	return (\%hash);
}

## For trees that don't have attributes that can conflict with contents,
## this will return the whole thing as a simple dot-notation hash.
## Remember that for multiple items with the same name at the same level,
## the last one wins... This may result in unexpected behaviour, especially if
## the last item with the same name had different sub-params (those sub-params will
## still be set!). Also remember that contents will trump attributes if they have
## the same name.
## Yes, this is recursive. (Yes, this is recursive. (Yes, this is recursive...))) -AK
sub easytree_flattener
{
	my ($tree) = @_;
	my $hash = {};
	foreach my $element (@{$tree})
	{
		my $type    = defined($element->{'type'})    ? $element->{'type'}    : next;
		my $content = defined($element->{'content'}) ? $element->{'content'} : next;
		## Elements with sub-stuff
		if ($type eq 'e')
		{
			my $name = defined($element->{'name'}) ? $element->{'name'} : '';
			foreach my $key (keys %{$element->{'attrib'}})
			{
				## Add the attribs onto the hash under the current level
				$hash->{$name.'.'.$key} = $element->{'attrib'}{$key};
			}
			## Get everything under the current level
			my $sub_hash = easytree_flattener($content);
			## Parse the recursive results into the current dot namespace
			## (map the sub hash into the current hash)
			foreach my $key (keys %{$sub_hash})
			{
				## If the key is blank (usually as a result of a t-type element below
				## being passed back up the chain) then just use the name
				## But if we have a key, add a dot and the key name to the name
				my $keyname = $key ? $name.'.'.$key : $name;
				$hash->{$keyname} = $sub_hash->{$key};
			}
		}
		## Just plain text
		elsif ($type eq 't')
		{
			$content =~ s/^\s+//s; $content =~ s/\s+$//s; # Trim leading/trailing space
			## Multiple text elements at the same level just get appended in order of processing
			if (not defined $hash->{''}) { $hash->{''} = $content; }
			else { $hash->{''} .= ' '.$content; }
		}
	}
	return $hash;
}

## This one didn't handle attribs
sub easytree_flattener_old
{
	my ($tree) = @_;
	my $hash = {};
	foreach my $element (@{$tree})
	{
		my $name    = $element->{'name'};
		my $content = $element->{'content'};
		next unless defined($name);
		next unless defined($content);
		if (ref($content->[0]{'content'}))
		{
			my $sub_hash = easytree_flattener($content);
			foreach my $key (keys %{$sub_hash})
			{
				$hash->{$name.'.'.$key} = $sub_hash->{$key};
			}
		}
		else
		{
			$hash->{$name} = $content->[0]{'content'};
		}
	}
	return $hash;
}

## This strips all the ugly whitespace between tags off (you don't need it in most cases)
## This makes the output of XML::Parser::EasyTree a lot easier to look at.
sub scrub
{
	my ($content) = @_;
	$content =~ s/\s*(\<|\>)\s*/$1/gs;
	return $content;
}


##
## build tree is a spiffy  (recursive) function which creates a multilevel xml tree from a flat hash
##
## Syntax:
##		*Verb = tells us what the header type should be.
##		A.B.C=>123 would generate <A><B><C>123</C></B></A>
##		A.B!=>123 would generate <A><B><[[CDATA]asdf[]]></B></A>
##		A.B#1.X=>123  A.B#2.X=>456 would generate <A><B><X>123</X></B><B><X></B></A>
##		A.B~FOO=>123 would generate <A><B FOO="123"></B></A> 
##		A*=><a>xml</a> would generate raw <a>xml</a>
##		A$1=>"asdf",A$2=>"xyz"		would generate multiple (unique) <a>asdf</a><a>xyz</a> 
##
## The best way by far to grok this is to just run the following:
# my %p = (); $p{'#Verb'} = 'AddItemRequest';
# $p{'A.B.C'} = 123; $p{'A.B.G'} = 123; $p{'A.B!'} = 456; $p{'A.~FOO'} = 789; $p{'A.C*'} = "<badxml??>123</bad>";
# $p{'~xmlns'} = 'urn:ebay:apis:eBLBaseComponents'; print &encode($p{'#Verb'},\%p);
## 
sub buildTree {
	my ($parent, $p, $level) = @_;

	if (not defined $level) { $level = 0; }
	my $xml = '';

	## phase1: break apart the hash into various component types consisting of:
	my %NODES = ();		## anything which has a subtree 
	my %ATTRIBS = ();		## anything which has a ~ at the beginning and goes inside the tag e.g. <tag attrib="val">
	my %TAGS = ();			## anything which doesn't have any subnodes, or attributes.

	foreach my $k (keys %{$p}) {
		#print "K: $k\n";
		next if (substr($k,0,1) eq '#');	## comment lines! (these will be ignored!)
	
		if (index($k,'.')>=0) {
			## SUBNODE e.g. A.B 
			my ($node,$remain) = split(/\./,$k,2);

			## print "ADD NODE: $node DAT: $remain\n";
			if (not defined $NODES{$node}) { $NODES{$node}={}; }
			$NODES{$node}->{$remain} = $p->{$k};
			}
		elsif ((defined $parent) && (substr($k,0,1) eq '~')) {
			## print "ADD ATTRIB: [$parent] $k = $p->{$k}\n";
			$ATTRIBS{substr($k,1)} = $p->{$k};
			}
		else {
			## note: we intentionally handle tags separately since it's MUCH faster to not recurse unnecessarily.
			$TAGS{$k} = $p->{$k};		
			}
		}

	if (defined $parent) {
		my $node = $parent;
		if ($node =~ /(.*?)\#/) { $node = $1; }	# $parent might be the "B#1" in a A.B#1.C syntax
		$xml .= "<$node";
		foreach my $k (keys %ATTRIBS) { $xml .= " $k=\"".&XMLTOOLS::xml_incode($ATTRIBS{$k})."\""; }
		$xml .= ">\n";
		}		

	foreach my $t (sort keys %TAGS) {
		if (substr($t,-1) eq '!') {
			## CDATA
			$xml .= "<".substr($t,0,-1)."><![CDATA[".$TAGS{$t}."]]><".substr($t,0,-1).">\n";
			}
		elsif (substr($t,-1) eq '*') {
			## NESTED XML
			$xml .= $TAGS{$t};
			}
		elsif ($t =~ /^([a-zA-Z0-9]+)\$(.*)$/) {
			## UNIQUE (DUPLICATE TAGS)  X$1 X$2 etc..
			my ($tx) = $1;
			$xml .= sprintf("<%s>%s</%s>",$tx,&XMLTOOLS::xml_incode($TAGS{$t}),$tx);
			}
		else {
			$xml .= "<$t>".&XMLTOOLS::xml_incode($TAGS{$t})."</$t>";
			}
		}

	foreach my $n (keys %NODES) {
		$xml .= buildTree($n,$NODES{$n},$level+1);
		}

	if (defined $parent) {
		my $node = $parent;
		if ($node =~ /(.*?)\#/) { $node = $1; } # $parent might be the "B#1" in a A.B#1.C syntax
		$xml .= "\n</$node>";
		}

	if ($level == 0) { $xml = '<?xml version="1.0" encoding="utf-8"?>'.$xml; }
	return($xml);
	}


##
##
##
sub dumptree_as_xml {
	my ($tree) = @_;
	my $out = '';

	my $kill_whitespace = 1; ## Whether or not to strip whitespace
	my $add_newlines = 0;    ## Whether ot not to add newlines to the end tags
	my $shorten_tags = 1;    ## whether or not to output blank tags as <tag/> instead of <tag></tag>

	if (ref($tree) eq 'ARRAY')
	{
		foreach my $n (@{$tree})
		{
			if ($n->{'type'} eq 'e')
			{
				my $attribs = '';
				if (
					(defined $n->{'attrib'}) &&
					(scalar keys %{$n->{'attrib'}})
				)
				{
					foreach my $a (keys %{$n->{'attrib'}})
					{
						$attribs .= ' ' . $a . '="' . &ZTOOLKIT::encode_latin1($n->{'attrib'}{$a}) . '"';
					}
				}
				my $guts = '';
				if (scalar @{$n->{'content'}})
				{
					$guts = &dumptree_as_xml($n->{'content'});
				}
				if ((not $shorten_tags) || ($guts ne ''))
				{
					$out .= "<$n->{'name'}$attribs>$guts</$n->{'name'}>";
				}
				else
				{
					$out .= "<$n->{'name'}$attribs/>";
				}
				if ($add_newlines) { $out .= "\n"; }
			}
			elsif ($n->{'type'} eq 't')
			{
				if ((not $kill_whitespace) || ($n->{'content'} !~ m/^\s*$/))
				{
					$out .= &ZTOOLKIT::encode_latin1($n->{'content'});
				}
			}
		}
	}
	elsif (ref($tree) eq 'HASH')
	{
		foreach my $t (keys %{$tree})
		{
			$out .= "<$t>".parse_tree($tree->{$t})."</$t>";
			if ($add_newlines) { $out .= "\n"; }
		}
	}
	return $out;
}



1;
