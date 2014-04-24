package TOXML::COMPILE;

use strict;
use Data::Dumper;
use XML::Parser;
use XML::Parser::EasyTree;
use Digest::MD5;


use lib "/backend/lib";
require TOXML;
require ZTOOLKIT;
require TOXML::UTIL;

$::SEQUENCE = time();


#mysql> desc TOXML;
#+-------------+------------------------------------------------------+------+-----+---------+----------------+
#| Field       | Type                                                 | Null | Key | Default | Extra          |
#+-------------+------------------------------------------------------+------+-----+---------+----------------+
#| ID          | int(11)                                              |      | PRI | NULL    | auto_increment |
#| MID         | int(10) unsigned                                     |      |     | 0       |                |
#| FORMAT      | enum('LAYOUT','WRAPPER','WIZARD','CUSTOM','CHANNEL') |      |     | LAYOUT  |                |
#| SUBTYPE     | char(1)                                              |      |     |         |                |
#| DIGEST      | varchar(32)                                          |      |     |         |                |
#| UPDATED_GMT | int(10) unsigned                                     |      |     | 0       |                |
#| TEMPLATE    | varchar(60)                                          |      |     |         |                |
#+-------------+------------------------------------------------------+------+-----+---------+----------------+
#7 rows in set (0.02 sec)


##
## this is run each time a TOXML file is saved (MaSTerSave or regular)
##		it is responsible for creating all files, building any indexes, cheat sheets, and 
##		EVENTUALLY pre-compiling the SPECL syntax into a non-interpreted version (e.g. via evals)
##		which would then run very very very fast.
##
sub compile {
	my ($self) = @_;

	my ($configel) = $self->findElements('CONFIG');	# fetch the first CONFIG element out of the document.
	my $format = $self->getFormat();
	if (not defined $configel) {
		}
	$self->{'_CONFIG'} = $configel;

	if (($format eq 'WRAPPER') && ($configel->{'CSS'} ne '')) {
		require TOXML::CSS;
		$configel->{'%CSSVARS'} = TOXML::CSS::css2cssvar($configel->{'CSS'});
		}

	}




##
## inputs: xml to be validated
## returns: 
##		result -> 1 if no errors
##				    0 if errors
##		xml - input xml and errors if present
##
sub xmlValidate{
	my ($xml) = @_;
	my $success= 1;
	use XML::Parser;

	my $DOCID = 'ERR';
	if ($xml =~ m/\<TEMPLATE.*?ID\=\"(.*?)\"/is) { $DOCID = $1.'_ERR'; }	
	$DOCID =~ s/\W+//gs;	# strip * (we'll add it back later)

	my $xmlerror;
	# initialize parser object and parse the string
	my $parser = XML::Parser->new( ErrorContext => 2 );
	eval { $parser->parse( $xml ); };
 
	# report any error that stopped parsing, or announce success
	if( $@ ) {
   	$@ =~ s/at \/.*?$//s;               # remove module line number
		$@ =~ s/=*^//s;							# remove pointer to error
		$@ =~ m/byte(.*):/;
		my $byte = $1;
		$@ =~ s/at line .*, column .*, byte .*//s;
		$@ =~ s/\n//g;

		# find the next > in the string after the error
		my $end = index( substr($xml, $byte), ">" )+1; 

		# attempt surround error with font red
		my $output = substr($xml, 0, $byte) . 
						 "<!!font color=red!!>".
						 substr($xml, $byte, $end). 
						 "<!!/font!!>". 
						 substr($xml, $byte+$end);
		
		$output = &ZOOVY::incode($output);	# encode the entire thing as html.
		$output =~ s/&gt;!!/</gs;
		$output =~ s/&lt;!!/>/gs;
		
		$output = "<TEMPLATE HASERRORS=\"1\" ID=\"\*$DOCID\" NAME=\"\*$DOCID\">
<!-- 
This document was automatically created because the uploaded/saved document
contained unrepairable error(s). The system stopped processing when it encountered
the first error which was: $@

The Zoovy system supports two formats:
	strict - a data format which follows xml 1.0 encoding specification, suitable for use
				by other applications outside the zoovy system.
	loose - allows HTML to be interspersed with editing tools, usually an html
				editor. Usually these files have a .html extension, most people generally 
				prefer to work in this format.

Old formats such as .flow, .zhtml, or mixed .xml/.txt/.html wizards are first converted
to loose XML, then upgraded to strict before they can be processed. Since troubleshooting
errors in this process can be very tedious we recommend you do not use these deprecated
formats. 

How to tell the difference between formats: 

strict documents always begin with a <TEMPLATE tag, and should be contained in a file
	with a .xml extension, they can be loaded into Internet Explorer to be validated.

loose documents do NOT have a <TEMPLATE tag. Because loose documents allow html to be used 
	throughout the document) they cannot be validated directly, they will almost always be 
	uploaded without errors, however they may not be interpreted correctly. (honestly if you're 
	seeing this message you probably uploaded a strict document)

we recommend you remove the offending content, review the documentation on creating
elements, and if all else fails contact Zoovy support. Remember: Assistance with custom documents is 
always billable. Remove content until the file uploads successfully and then slowly add it back in 
until the error appears.

the HTML element below is our attempt to highlight where the specific error is, however since
the document is not well formed cannot be validated, it is impossible for any computer algorithim 
to *guess* exactly where the actual error is, it could be before or after the highlighted syntax 
so it is merely intended to serve as a guide, rather than a specific pointer to the error.
-->
<ELEMENT ID=\"ERR\" TYPE=\"OUTPUT\">
<![CDATA[
<b>XML contains error: $@</b><br>
<i>Please fix and reupload document</i><br>
<br>
$output
]]>
</ELEMENT>
</TEMPLATE>
";
	

		# return xml with error at the top, initial xml with flagged error
    	$xmlerror = $output;
	
		$success= 0;
		}

	return($success, $xmlerror); 
	}




##
## parameters:
##
sub fromXML {
	my ($FORMAT,$ID,$BUF,%options) = @_;

	require TOXML::COMPILE;

	my ($ERROR) = undef;
	my $toxml = undef;
	## first detect the type, loose or strict.
	if ($BUF eq '') {
		## empty document?
		$ERROR = "received empty document";
		}
	elsif (substr($BUF,0,100)=~/\<\?ZOOVY_DW_PLUGIN V\=\"([\d]+)\"\?\>/s) {
		## PLUGIN ULTRA-LOOSE FLOW! 
		my $V = $1; 
		$BUF = substr($BUF,index($BUF,'?>')+2);
		my ($out) = TOXML::COMPILE::xmlTighten($ID,$BUF,1);
		($toxml) = TOXML::COMPILE::xmlToRef($out);
		}
	elsif (substr($BUF,0,100)=~/\<TEMPLATE/) {
		## STRICT LAYOUT -- contains outer template tag.
		# print STDERR "TOXML::COMPILE took the STRICT route on fromXML\n";
		($toxml) = TOXML::COMPILE::xmlToRef($BUF);			
		}
	else {
		## LOOSE FLOW (no outer template tag)
		# print STDERR "TOXML::COMPILE took the LOOSE route on fromXML\n";
		my ($out) = TOXML::COMPILE::xmlTighten($ID,$BUF);
		($toxml) = TOXML::COMPILE::xmlToRef($out);
		}

	# print Dumper($toxml);
	($toxml) = TOXML->new($FORMAT,$ID,REF=>$toxml,%options);	

	if ($FORMAT eq 'WRAPPER') {
		require TOXML::CSS;
		my ($configel) = $toxml->findElements('CONFIG');

		if ((not defined $configel->{'CSS'}) && (defined $configel->{'THEME'})) {
			my $iniref = &ZTOOLKIT::parseparams($configel->{'THEME'});
			$configel->{'THEME_OLD'} = $configel->{'THEME'};
			$configel->{'THEME'} = '';
			$configel->{'CSS'} = &TOXML::CSS::iniref2css($iniref);
			}

		if (defined $configel->{'CSS'}) {
			require TOXML::CSS;

			my $cssref = &TOXML::CSS::css2cssvar( $configel->{'CSS'} );
         my $iniref = &TOXML::CSS::cssvar2iniref( $cssref );
         $configel->{'THEME'} = &ZTOOLKIT::buildparams( $iniref );
 			}
		}

	if ($options{'USERNAME'}) { 
		$toxml->{'_USERNAME'} = $options{'USERNAME'};
		$toxml->{'_MID'} = &ZOOVY::resolve_mid($options{'USERNAME'});
		}
	
	# use Data::Dumper; print STDERR Dumper($toxml);
	return($toxml);
	}


##
##
## mode 1 == Plugin Mode (encodes _ as HTML rather than looking for attributes! 
##
sub xmlTighten {
	my ($flowid, $xml, $mode) = @_;

	if (not defined $mode) { $mode = 0; }

	my @ELEMENTS = ();
	my @ar = split (/(<ELEMENT .*?<\/ELEMENT>)/s, $xml);
	foreach my $e (@ar) {

		# see if we hit an element, or if its just padding. (eg: HTML)
		if ($e =~ m/(<ELEMENT .*?<\/ELEMENT>[\n\r]*)/s) {
			##
			##	hey, why not set the embedded elements (content) to '_' and then we'll decode that quick and easy later on.
			##
			my $ref = &ZTOOLKIT::xmlish_list_to_arrayref($e,'tag_attrib'=>'ELEMENT',content_raw=>1,content_attrib=>'_');
			my $inforef = $ref->[0];
			if ((defined $inforef->{'_'}) && ($mode==1)) {
				$inforef->{'HTML'} = $inforef->{'_'};
				delete $inforef->{'_'};
				}
			elsif (defined $inforef->{'_'}) {
				my $ref = &ZTOOLKIT::xmlish_to_hashref($inforef->{'_'});
				foreach my $k (keys %{$ref}) {
					if ($ref->{$k} =~ /\<\!\[CDATA\[(.*?)[\]]+\>/s) { $ref->{$k} = $1; }		# strip any CDATA's
					if ($ref->{$k} =~ /\<\!\CDATA\[(.*?)[\]]+\>/s) { $ref->{$k} = $1; }		# strip any misformatted CDATA's
					$inforef->{$k} = $ref->{$k};
					}
				delete $inforef->{'_'};
				}

			push @ELEMENTS, $inforef;
			} ## end if ($e =~ m/<ELEMENT (.*?)<\/ELEMENT>/s...
		else {
			# no element found, lets go ahead and append it to the return
			my %info = ();
			$info{'TYPE'} = 'OUTPUT';
			# $e =~ s/[\n\r]+//gs;
			# $e =~ s/[\s]+/ /gs;
			$info{'HTML'} = $e;
			push @ELEMENTS, \%info;
			}   # end of if/else is element or html
		}

	my $out = '';
	$out = &elementsToXML(\@ELEMENTS);

	$out = qq~<TEMPLATE FORMAT=\"LAYOUT\" ID="$flowid">\n$out\n</TEMPLATE>\n~;
	return($out);	
	}


##
## takes in an elements array ref
##		e.g. [ { TYPE=>'', BLAH=>'' } ]
##	outputs the XML element tags in strict notation.
##
sub elementsToXML {
	my ($elementsref) = @_;

	my $out = '';
	foreach my $el (@{$elementsref}) {
		my $TYPE = $el->{'TYPE'};

		if ($el->{'ELEMENT'} eq 'ELEMENT') { delete $el->{'ELEMENT'}; }	

		if (($TYPE eq 'OUTPUT') && ($el->{'DIV'} eq '') && ($el->{'OUTPUTSKIP'} eq '')) {
			if ($el->{'HTML'} !~ /^[\s]*$/s) {	
            my $attribs = '';
            foreach my $k (keys %{$el}) {
               next if ($k eq 'TYPE');
               next if ($k eq 'HTML');
               $attribs .= ' '.$k.'="'.&ZTOOLKIT::encode($el->{$k}).'"';
               }
            $out .= "<ELEMENT".$attribs." TYPE=\"OUTPUT\"><![CDATA[$el->{'HTML'}]]></ELEMENT>\n";
				}
			}
		else {
			foreach my $tag (keys %{$el}) {
				## remove non-alphan numeric attributes (not supported/corrupt)
				if ($tag !~ /[A-Z]/) { delete $el->{$tag}; }
				}

					
			my $content = '';
			foreach my $k (keys %{$el}) {
				next if (substr($k,0,1) eq '%');	# removes the %CSSVARS
				# print "K: $k\n";
				if (($el->{$k} =~ /\n/) || (length($el->{$k})>100)) {
					$content .= "<$k><![CDATA[$el->{$k}]]></$k>\n";
					delete $el->{$k};
					}
				}
			if ($content ne '') { $el->{'content'} = $content; }

			## specialized since it doesn't encoded contents
			$out .= &ZTOOLKIT::arrayref_to_xmlish_list([$el],tag=>'ELEMENT',lowercase=>0,content_raw=>1);
			}
		}

	return($out);
	}


##
## takes in a strict xml and returns a reference 
##
## reference looks like:
##		$ref->{'_ID'} = id;
##		$ref->{'_FORMAT'} = 'LAYOUT','WIZARD',etc.
##		$ref->{'_V'} = version (2.0)
##		$ref->{'_DIGEST'} = 'unique identifier'
##	
##		$ref->{'_ELEMENTS'} = [ .. elements .. ]
##		$ref->{'_LISTS'} = [ .. lists .. ]
##		$ref->{'_DIVS'} = [ { ID, _ELEMENTS }, { ID, _ELEMENTS }, ]
##
sub xmlToRef {
	my ($xml) = @_;

	my $out = '';
	foreach my $ch (split(//,$xml)) {
		next if (ord($ch)==160);		# character 160 -- what the fuck is it?
		next if (ord($ch)>127);		# character 160 -- what the fuck is it?
		if (ord($ch)>127) {
			$out .= "&#".ord($ch).";";
			}
		else {
			$out .= $ch;
			}
		}
	$xml = $out;
	
	# open F, ">/tmp/toxml.debug"; print F $xml; close F;

	my ($success,$errorxml) = &xmlValidate($xml);
	if (not $success) {
		$xml = $errorxml;
		}

	my $p1 = new XML::Parser(Style => 'EasyTree');
	my $tree = $p1->parse($xml);
	$tree = $tree->[0];	

	

	my %result = ();
	foreach my $k (keys %{$tree->{'attrib'}}) {
		$result{'_'.$k} = $tree->{'attrib'}->{$k};
		}
	if (not $result{'_V'}) { $result{'_V'} = 2; }
	if (not $result{'_ID'}) { 
		warn "Flow does not have an ID set.. very dangerous.";
		$result{'_ID'} = base26(++$::SEQUENCE); 
		}

	$result{'_DIGEST'} = Digest::MD5::md5_base64($xml);

	$result{'_DIVS'} = [];
	$result{'_LISTS'} = [];		## an array of { ID=>'', TYPE=>'TEXT', 
										## 	_OPTS=> [ { V=>'', T=>'' }, { V=>'', T=>'' }  ] 
	$result{'_ELEMENTS'} = [];	## an array of { ID=>'', TYPE=>'', KEY=>'VALUE' }

	foreach my $tel (@{$tree->{'content'}}) {
		next if ($tel->{'type'} eq 't');

		if ($tel->{'name'} eq 'DIV') {
			push @{$result{'_DIVS'}}, &divAssemble($tel);
			}
		elsif ($tel->{'name'} eq 'LIST') {
			push @{$result{'_LISTS'}}, &listAssemble($tel);
			}
		elsif ($tel->{'name'} eq 'ELEMENT') {
			push @{$result{'_ELEMENTS'}}, &elementAssemble($tel);
			}

		next;
		}


	return(\%result);
	}



sub divAssemble {
	my ($tel) = @_;

	my %DIV = ();
	foreach my $k (keys %{$tel->{'attrib'}}) {
		$DIV{$k} = $tel->{'attrib'}->{$k};						
		}
	if ((not defined $DIV{'ID'}) || ($DIV{'ID'} eq '')) {
		warn 'warning: trying to assemble DIV that does not contain ID -- probably broken.';
		}
	$DIV{'_ELEMENTS'} = [];
	foreach my $el (@{$tel->{'content'}}) {
		next if ($el->{'type'} ne 'e');
		if ($el->{'name'} eq 'ELEMENT') {
			push @{$DIV{'_ELEMENTS'}}, &elementAssemble($el);
			}
		}

	return(\%DIV);
	}

sub listAssemble {
	my ($tel) = @_;

	my %LIST = ();
	foreach my $k (keys %{$tel->{'attrib'}}) {
		$LIST{$k} = $tel->{'attrib'}->{$k};						
		}
	if ((not defined $LIST{'ID'}) || ($LIST{'ID'} eq '')) {
		warn 'warning: trying to assemble LIST that does not contain ID -- probably broken.';
		}
	$LIST{'_OPTS'} = [];
	foreach my $opt (@{$tel->{'content'}}) {
		next if ($opt->{'type'} ne 'e');
		my %OPT = ();
		foreach my $k (keys %{$opt->{'attrib'}}) {
			$OPT{$k} = $opt->{'attrib'}->{$k};
			}
		if (not defined $OPT{'T'}) { warn 'LIST OPTS require T [TEXT] to be set, ignoring'; }
		elsif (not defined $OPT{'V'}) { warn 'LIST OPTS require V [VALUE] to be set, ignoring'; }
		else { push @{$LIST{'_OPTS'}}, \%OPT; }
		}

	return(\%LIST);
	}

##
##
##
#$VAR1 = {
#          'content' => [
#                         {
#                           'content' => [
#                                          {
#                                            'content' => 'Remember to keep this text short and to the point. If this is too long, or not helpful visitors probably won\'t go any further. A lot of businesses talk about what makes their products unique, or their excellent customer service. If you have neither of those, then consider simply welcoming the customer.<br>',
#                                            'type' => 't'
#                                          }
#                                        ],
#                           'name' => 'HELPER',
#                           'attrib' => {},
#                           'type' => 'e'
#                         },
#                         {
#                           'content' => '
#',
#                           'type' => 't'
#                         }
#                       ],
#          'name' => 'ELEMENT',
#          'attrib' => {
#                        'ID' => 'WELCOME',
#                        'HELP' => 'Please enter a Welcome message that will appear on your front page',
#                        'PROMPT' => 'Welcome Message',
#                        'DEFAULT' => 'Hello, welcome to our wonderful website!',
#                        'DATA' => 'page:welcome_message',
#                        'TYPE' => 'TEXT'
#                      },
#          'type' => 'e'
#        };
##
sub elementAssemble {
	my ($tel) = @_;

	my %result = ();
	## take all the attributes and flatten.
	foreach my $k (keys %{$tel->{'attrib'}}) {
		$result{$k} = $tel->{'attrib'}->{$k};
		}

	if ($result{'TYPE'} eq 'OUTPUT') {
		if (defined $result{'HTML'}) {}
		else { $result{'HTML'} = $tel->{'content'}->[0]->{'content'}; }

		if (ref($result{'HTML'}) eq 'ARRAY') { 
			## Fucking CDATA!
			$result{'HTML'} = $result{'HTML'}->[0]->{'content'};
			}
		}
	else {
		## go through the content and look for nested data.
		foreach my $el (@{$tel->{'content'}}) {
			next if ($el->{'type'} eq 't');
			if ($el->{'type'} eq 'e') {
				$result{$el->{'name'}} = $el->{'content'}->[0]->{'content'};
				}
			}
		}

	## cleanup, make sure each element has an ID
	if (not defined $result{'ID'}) { $result{'ID'} = base26(++$::SEQUENCE); }
	# open F, ">>/tmp/toxml.debug2"; print F Dumper(\%result);  close F;

	return(\%result);
	}



#############################################################
##
## Converts a decimal [base 10] number into it's alpha [base26] equivalent where A=1, Z=26, AA=27, AB=28
##
sub base26 { 
	my ($i) = @_;
	my @ar = ('A'..'Z');
	my $out = '';
	while ($i > 0) {
		if ($i<27) { $out = $ar[$i-1].$out; $i = 0; }
		else { $out = $ar[($i-1) % 26].$out; $i = int(($i-1) / 26); }
		}
	return($out);
	}


1;