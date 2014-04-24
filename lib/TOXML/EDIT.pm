package TOXML::EDIT;

no warnings 'once';

use locale;
use utf8 qw();
use Encode qw();


use lib "/backend/lib";
use Data::Dumper;
require ZOOVY;
require ZTOOLKIT;
require TOXML::RENDER;

use strict;

##
## required variables for SREF
##		_USERNAME
##		_SKU
##		_NS			the namespace (normally '')
##		_DOCID
##		%PRODREF		(not serialized)
##

##
## parameters: portal 
##		returns the attribute that contains the template for that marketplace. 
##
sub template_attrib { 
	my ($PORTAL) = @_;
	# if (not defined $PORTAL) { $PORTAL = $TEMPLATE::PORTAL; }

	if (index($PORTAL,'.')>=0) {
		## convert portal.blah to just portal
		$PORTAL = substr($PORTAL,0,index($PORTAL,'.'));
		}

	$PORTAL = lc($PORTAL);

	if ($PORTAL eq '') { return(''); }
	elsif ($PORTAL eq 'ebaystores' || $PORTAL eq 'ebaymotors') { return('ebay:template'); }
	else { return(lc($PORTAL).':template'); }
	}





%TOXML::EDIT::edit_element = (
	# 'EDITOR_ACTION'=>\&TOXML::EDIT::EDITOR_ACTION,
	# 'LISTEDITOR' => \&TOXML::EDIT::EDIT_LISTEDITOR,
	'HTML' => \&TOXML::EDIT::element_textarea,

	'DYNIMAGE' => \&TOXML::EDIT::EDIT_DYNIMAGE,

	'SLIDE' => \&TOXML::EDIT::EDIT_SLIDE,
	'PRODLIST' => \&TOXML::EDIT::EDIT_PRODLIST,
	'GALLERY' => \&TOXML::EDIT::EDIT_GALLERY,
	'SEARCHBOX' => \&TOXML::EDIT::EDIT_SEARCHBOX,
	'HITGRAPH' => \&TOXML::EDIT::EDIT_HITGRAPH,
	'QTYPRICE' => \&TOXML::EDIT::EDIT_QTYPRICE,
	'FINDER' => \&TOXML::EDIT::EDIT_FINDER,
	'DISPLAY' => \&TOXML::EDIT::element_display,	
	'META' => \&TOXML::EDIT::element_meta,
	'FORMAT' => \&TOXML::EDIT::element_display,		## ??
	'IF' => \&TOXML::EDIT::element_null,
   'TEXTBOX' => \&TOXML::EDIT::element_textbox,
   'TEXTAREA' => \&TOXML::EDIT::element_textarea,
	'TEXTLIST' => \&TOXML::EDIT::element_textlist,
   'TEXT' => \&TOXML::EDIT::element_textarea,
	'NUMBER' => \&TOXML::EDIT::element_textbox,
	'IMAGE' => \&TOXML::EDIT::element_image,
	'TREE' => \&TOXML::EDIT::element_tree,
	'BANNER' => \&TOXML::EDIT::element_banner,
	'PASSWORD' => \&TOXML::EDIT::element_password,
	'CHECKBOX' => \&TOXML::EDIT::element_checkbox,
	'SELECT' => \&TOXML::EDIT::element_select,
#	'PROFILE' => \&TOXML::EDIT::element_profile,
	'HIDDEN' => \&TOXML::EDIT::element_hidden,
	'NULL' => \&TOXML::EDIT::element_null,
	'BLANK' => \&TOXML::EDIT::element_blank,
	'RADIO' => \&TOXML::EDIT::element_radio,
	'IMAGESELECT' => \&TOXML::EDIT::element_imageselect,
	'IMAGELIST' => \&TOXML::EDIT::element_imageselect,
#	'COUNTER' => \&TOXML::EDIT::element_counter,
#	'SCHEDULEHIDDEN' => \&TOXML::EDIT::element_schedulehidden,
	'INVENTORY' => \&TOXML::EDIT::element_inventory,
	'SKU' => \&TOXML::EDIT::element_sku,
	'READONLY' => \&TOXML::EDIT::element_hidden,
	'TRISTATE' => \&TOXML::EDIT::element_hidden,
	'OUTPUT' => \&TOXML::EDIT::element_null,
#	'BUTTON' => \&TOXML::EDIT::element_button,
	'CONFIG'=> \&TOXML::EDIT::element_null,	
	);



# Each of these function takes in a reference to an element's INI hash, and returns the
# HTML code to display the element in an editor for the element.
# The only property of a textbox is CONTENTS

sub EDIT_FINDER {
	my ($iniref,undef,$SITE) = @_;

	require POGS;
	my $sogslist = '';


	my $sogsref = POGS::list_sogs($SITE->username());
	foreach my $s (keys %{$sogsref}) {
		$sogslist .= "<option value=\"$s\">$s: $sogsref->{$s}</option>";
		}

	my $val = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'},$iniref->{'LOADFROM'},$iniref->{'DEFAULT'});
	$val = &ZOOVY::incode($val);

	my $SPECS = '';
	foreach my $k (sort keys %{$iniref}) {
		if ($k =~ /SPEC_(.*?)$/) { $SPECS .= "<option value=\"$1\">$1</option>\n"; }
		}
	if ($SPECS eq '') { $SPECS = "<option value=\"DEFAULT\">DEFAULT</option>"; }

	my $c = q~
				<b>Product Finder Creation Wizard:</b><br>
				<i>This wizard will help you create a valid configuration string for a product finder. 
				The prompt is what is shown to the user above the choice they
will make (e.g. Color). Use the Include "ANY" value to make a particular
choice optional. Add as many groups as you want. 
The "display spec" is how the options will be output to the user.</i>
				
				<table>
					<tr><td>Prompt:</td><td><input type="textbox" id="finder!prompt" name="finder!prompt" value=""></td></tr>
					<tr><td>Group:</td><td><select id="finder!sog" name="finder!sog">
							~.$sogslist.q~
						</select></td></tr>
					<tr><td colspan="2"><input type="checkbox" checked id="finder!any" name="finder!any"> Include "ANY" value as first option.</td></tr>
					<tr><td>Display As:</td>
						<td><select id="finder!spec" name="finder!spec">
						~.$SPECS.q~
						</select></tr>
				</table>

				<input type="button" value="  Add to Finder Text  " onClick="
					var str = '?';
					str = str + 'prompt=' + escape($('finder!prompt').value) + '&'; 
					$('finder!prompt').value = '';
					str = str + 'any=' + (($('finder!any').checked)?'1':'0') + '&';
					str = str + 'spec=' + $('finder!spec').options[ $('finder!spec').selectedIndex ].value  + '&';
					str = str + 'sog=' + $('finder!sog').options[ $('finder!sog').selectedIndex ].value  + '&';
					
					$('finder!wizard').value = $('finder!wizard').value + str + '\n';
					">
				
				
				
				<br>
				<b>Finder Text: </b><i>(This is created by the wizard above)</i><br>
				<textarea rows="5" cols="60" id="finder!wizard" name="finder!~.$iniref->{'ID'}.'">'.$val.q~</textarea><br>
	~;



	my $PROMPT = $iniref->{'PROMPT'};
	return('FINDER',$PROMPT,$c);
	}


sub element_banner {
	my ($iniref,undef,$SITE) = @_; 

	if ($iniref->{'READONLY'}) { return('NULL'); }		# NOTE: used for backward compatibility in legacy HTML wizards
																	# for old SUB="xxx_URL" and SUB="xxx_RAWURL" 
	my $PROMPT = $iniref->{'PROMPT'};
	if (not defined $PROMPT) { $PROMPT = ''; }
	my $ID = $iniref->{'ID'};

	my $VALUE = &TOXML::RENDER::smart_load($SITE, $iniref->{'DATA'},$iniref->{'LOADFROM'},$iniref->{'VALUE'});
	if (not defined $VALUE) { $VALUE = $iniref->{'DEFAULT'}; }

	my $UREF = &ZTOOLKIT::parseparams($VALUE);		## UREF is a reference to user data.

	my $SRC = '';
	my $SSLIFY;
	if ((not defined($UREF->{'IMG'})) || $UREF->{'IMG'} eq '') { 
		$SRC = &ZOOVY::mediahost_imageurl($SITE->username(),"//www.zoovy.com/images/image_not_selected.gif",75,75,$TOXML::EDIT::BGCOLOR,$SSLIFY);
		} 
	else {
		$SRC = &ZOOVY::mediahost_imageurl($SITE->username(),$UREF->{'IMG'},75,75,$TOXML::EDIT::BGCOLOR,$SSLIFY);
		}

	my %serial = ();
	$serial{'ATTRIB'} = $ID;	
	$serial{'PROMPT'} = $PROMPT;
	$serial{'VALUE'} = $UREF->{'IMG'};
	$serial{'ID'} = $ID;
	my $passthis = &ZTOOLKIT::fast_serialize(\%serial,1);

	my $t = time();
	my $qIMG = &ZOOVY::incode($UREF->{'IMG'});

	my $HTML = "<input type=\"HIDDEN\" id=\"$ID\" name=\"$ID\" value=\"$qIMG\">\n";
	$HTML .= qq~
		<button type="button" class="button"
		onClick="
		mediaLibrary(
			jQuery(adminApp.u.jqSelector('#','$ID'+'img')),
			jQuery(adminApp.u.jqSelector('#','$ID')),'Banner Image'); return false;">Media Library</button>
		<button type="button" class="button"
		onClick="
			jQuery(adminApp.u.jqSelector('#','$ID'+'img')).attr('src','/images/blank.gif');
			jQuery(adminApp.u.jqSelector('#','$ID')).val('');
			">Clear Image</button>
		~;
	$HTML .= "<img id=\"${ID}img\" name=\"${ID}img\" src=\"$SRC\" border=\"0\" height=\"75\" width=\"75\">";
	
	my $qLINK = &ZOOVY::incode($UREF->{'LINK'});
	my $qALT = &ZOOVY::incode($UREF->{'ALT'});

	$HTML .= qq~
<table>
<tr><td>Link</td><td><input type="textbox" name="${ID}/link" value="$qLINK"></td></tr>
<tr><td>Alt/Title:</td><td><input type="textbox" name="${ID}/alt" value="$qALT"></td></tr>
</table>
~;	

	return('BANNER',is_global($iniref->{'DATA'}).$iniref->{'PROMPT'},$HTML);
	}



sub EDIT_HTML {
	my ($iniref,undef,$SITE) =@_; # ini is a reference to a hash of the element's contents

	my $val = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'},$iniref->{'LOADFROM'},$iniref->{'DEFAULT'});
	$val = &ZOOVY::incode($val);
	$GTOOLS::TAG{'<!-- HTMLCONTENT -->'} = $val;
	$GTOOLS::TAG{'<!-- PROMPT -->'} = $iniref->{'PROMPT'};
	my $cssurl = '';
	
#	$GTOOLS::TAG{'<!-- CSSLOADER -->'} = qq~editor.config.pageStyle = "\@import \\"http://www.zoovy.com/biz/setup/builder/htmlarea/examples/custom.css\\";";~;
	$GTOOLS::TAG{'<!-- CSSLOADER -->'} = qq~editor.config.pageStyle = "";~;

	my $c = "";
	#$c .= "<b>".$iniref->{'PROMPT'}.":</b><br>";
	#$c .= "<textarea rows=\"7\" cols=\"80\" name=\"CONTENTS\">";
	#$c .= $val;
	#$c .= "</textarea>\n";

	if (defined($iniref->{'HELPER'})) {
		$GTOOLS::TAG{'<!-- HELPER -->'} = "<center><br><table border='0' width='100%'><tr><td><font size='2'>$iniref->{'HELPER'}</font></td></tr></table><br></center>";
		}

	## Javascript Focus Code
	#$c .= "<SCRIPT LANGUAGE=\"Javascript\"><!--//\n";
	#$c .= "document.forms[0].CONTENTS.focus();\n";	
	#$c .= "//--></SCRIPT>\n";

	my $PROMPT = $iniref->{'PROMPT'};
	return('HTML',$PROMPT,$c);
	}


sub EDIT_HITGRAPH {
	my ($iniref,undef,$SITE) = @_;
	
	my $val = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'},$iniref->{'LOADFROM'},$iniref->{'DEFAULT'});
	$val = &ZOOVY::incode($val);
	
	my $c = '';
	$c .= "Header Text on Graph: <input type=\"textbox\" name=\"header\" size=\"50\" value=\"$val\"><br>";
	$c .= "<br>";
	$c .= "<i>Default text is: Welcome to http://merchant.zoovy.com Channel #12345</i><br>";
	my $PROMPT = $iniref->{'PROMPT'};
	return('HITGRAPH',$PROMPT,$c);	
	}
	
sub EDIT_QTYPRICE 
{
	my ($iniref) = @_;
	$iniref->{'PROMPT'} = $iniref->{'PROMPT'};
	$iniref->{'HELPER'} = qq~
You must have the quantity price promotion api enabled in order for this feature to work properly with the cart.<br>
You may enter a list of values in the following format:<Br>
2/10,3/9 OR 2=5,3=3 which means either 2 for $10, 3 for $9, or 2+ means $5 each, 3+ means $3 each respectively.<br>
qty price pairs may be separated by either commas, or newlines.
~;
	return(&EDIT_TEXTBOX($iniref));
}








# note: we recycle the PROD variable, for internal use, specifically WHICH folder we are looking at
sub EDIT_DYNIMAGE {
	my ($iniref,undef,$SITE) =@_; # ini is a reference to a hash of the element's contents

	my $USERNAME = $SITE->username();
	my $protocol = 'http'; 
	if (defined($ENV{'HTTPS'}) && (lc($ENV{'HTTPS'}) eq 'on')) { $protocol = 'https'; }

	my $c = "";

	# Load the default into $BUF
	my $BUF = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'},$iniref->{'LOADFROM'},$iniref->{'DEFAULT'});
	my $count = $iniref->{'COUNT'};
	if (not defined $count) { $count = 5; }
	
	my %params = ();
	foreach my $keyval (split /[\n\r]+/, &ZOOVY::dcode($BUF)) {
		my ($key,$value) = split(/\=/,$keyval,2);
		$params{$key} = $value;
		}

	my $i = 0;
	my @images = ();
	my @image_names = ();
	foreach my $image (split /\,/, $params{'images'}) {
		if ($image =~ /^http\:/) {
			push @images, $image;
			push @image_names, $image;
			}
		else  {
			if ($i % 2) {
				push @images, "$protocol://static.zoovy.com/img/$USERNAME/W75-H75-BFFFFFF/$image";
				}
			else {
				push @images, "$protocol://static.zoovy.com/img/$USERNAME/W75-H75-BCCCCCC/$image";
				}
			push @image_names, $image;
			}
		$i++;
		}
	my @pauses_tmp = split(/\,/,$params{'pauses'});
	my @links_tmp = split(/\,/,$params{'links'});
	my @urls = ();
	my @pauses = ();
	foreach my $i (0..$#images) {
		if (defined $links_tmp[$i]) { $urls[$i] = $links_tmp[$i]; }
		else { $urls[$i] = ''; }
		if ((defined $pauses_tmp[$i]) && $pauses_tmp[$i]) {
			my $pause = sprintf("%.1f",($pauses_tmp[$i] / 1000));
			if ($pause == 0) { $pauses[$i] = 0.1; }
			else { $pauses[$i] = $pause; }
			}
		else { $pauses[$i] = 2; }
		}
	undef @pauses_tmp;

	$c .= <<"END";
<table width="600">
	<tr>
		<td align="left">
			<font size="+1">Dynamic Image Editor</font><br>
			<font size='2'>
			<p>Each of the images in this list will be shown in succession. You can select how long you'd
			like an image to remain on the screen by entering the number of seconds in the DELAY box.
			You can choose a URL for each image when clicked on by entering it in the URL field.
			If you do not specify a seperate action then the default Action below is used.</p>
			</font>
			<b>Default Action When Image Is Clicked:</b><br>
END

if ((not defined $params{'blank_behavior'}) || ($params{'blank_behavior'} eq '')) { $params{'blank_behavior'} = 'none'; }

        my $checked = ($params{'blank_behavior'} eq 'none')?'selected':'';
        $c .= "<select name=\"blank_behavior\">";
        $c .= qq~<option value="none" $checked>Do nothing when the image is clicked.</option>~;
        $checked = ($params{'blank_behavior'} eq 'zoom')?'selected':'';
        $c .= qq~<option value="zoom" $checked>Zoom in on the Image when clicked</option>~;
        $checked = ($params{'blank_behavior'} eq 'startstop')?'selected':'';
        $c .= qq~<option value="startstop" $checked>Stop / Start the Animation when clicked</option>~;
        $c .= "</select><br><br>";

$c .= <<"END";
		</td>
	</tr>
</table>
END

	$c .= "<table width=\"600\" border=\"0\" cellpadding=\"10\" cellspacing=\"0\">\n";
	
	foreach my $i (0 .. ($count-1)) {
		my $s = {};
		my $img = '';
		if (defined($images[$i]) && ($images[$i] ne '')) {
			$img = $images[$i]
			}
		else {
			$img = "http://www.zoovy.com/images/image_not_selected.gif"
			}
		#$s->{'ATTRIB'} = "image$i";
		#$s->{'SRC'} = $image_names[$i];
		#$s->{'VALUE'} = $img;
		#$s->{'PROMPT'} = "";
		#$s->{'ID'} = $iniref->{'ID'};
		#my $serial = &ZTOOLKIT::fast_serialize($s,1);

		my $bgcolor = '';
		if ($i % 2) { $bgcolor = "#FFFFFF"; }
		else { $bgcolor = "#CCCCCC"; }

		my $imgnum = $i + 1;
		$img = &ZOOVY::mediahost_imageurl($SITE->username(),$img,75,75,'FFFFFF');

		$c .= <<"END";
		<tr>
			<td bgcolor="$bgcolor" align="center">
				<img id="image${i}img" name="image${i}img" src="$img" border="0" height="75" width="75"><br>
				<input type="button" style='width: 75px; font-size: 8pt;' value="Select Image" onClick="mediaLibrary(jQuery('#image${i}img'),jQuery('#image$i'),'Choose Image $i'); return false;">
				<input type="button" style='width: 75px; font-size: 8pt;' value="Clear Image" onClick="jQuery('#image${i}img').val(''),jQuery('#image$i').val(''); return false;">
			</td>
			<td bgcolor="$bgcolor">
				<table border="0" cellpadding="1" cellspacing="0">
					<tr><td align="right" nowrap valign="middle"><font size='2'>Image $imgnum: </td><td valign="middle"><input style='font-size: 8pt; font-family: arial' type="text" id="image$i" name="image$i" value="$image_names[$i]" size="50"></td></tr>
					<tr><td align="right" nowrap valign="middle"><font size='2'>Delay </td><td valign="middle"><input style='font-size: 8pt; font-family: arial' type="text" name="pause$i" value="$pauses[$i]" size="4"><font size='2'> seconds (0 means no delay)</td></tr>
					<tr><td align="right" nowrap valign="middle"><font size='2'>URL </td><td nowrap valign="middle"><input style='font-size: 8pt; font-family: arial' type="text" name="link$i" value="$urls[$i]" size="50"><font size='2'> (optional)</td></tr>
				</table>
			</td>
		</tr>
END
	}

	$c .= "</table>\n";

#	open F, ">/tmp/foo"; print F $c; close F;

	my $PROMPT = $iniref->{'PROMPT'};
	return('DYNIMAGE',$PROMPT,$c);
}

# note: we recycle the PROD variable, for internal use, specifically WHICH folder we are looking at
sub EDIT_SLIDE {
	return ('SLIDE','',"There are no parameters to edit this element (To add/remove images, edit product).");
	}

##
##
##

sub EDIT_TEXTBOX {
	my ($iniref,undef,$SITE) = @_; # ini is a reference to a hash of the element's contents

	# print STDERR "EDIT-TEXTBOX\n";

	my $len = 100; # default
	if (defined($iniref->{'LENGTH'})) { $len = $iniref->{'LENGTH'}; }

	my $val = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'},$iniref->{'LOADFROM'},$iniref->{'DEFAULT'});
	$val = &ZOOVY::incode($val);
	
	my $c = "";
	$c .= "<b>".$iniref->{'PROMPT'}.":</b><br>";
	$c .= "<input type=\"TEXTBOX\" size=\"$len\" name=\"CONTENTS\" value=\"$val\">";

	if (defined($iniref->{'HELPER'}))
		{
		$c .= "<br>".$iniref->{'HELPER'}."<br>";
		}

	# Javascript Focus Code
	$c .= "<SCRIPT LANGUAGE=\"Javascript\"><!--//\n";
	$c .= "document.forms[0].CONTENTS.focus();\n";	
	$c .= "//--></SCRIPT>\n";
	

	my $PROMPT = $iniref->{'PROMPT'};
	return('TEXTBOX',$PROMPT,$c);
}


sub EDIT_SEARCHBOX {	
	my ($iniref,undef,$SITE) = @_;

	require SEARCH;
	&SEARCH::init();

	my $selected_catalog = &TOXML::RENDER::smart_load($SITE,$iniref->{'CATALOGATTRIB'});
	my $catalogs = &SEARCH::list_catalogs($SITE->username());
	my $prompt = &TOXML::RENDER::smart_load($SITE,$iniref->{'PROMPTATTRIB'});
	if ((not defined $prompt) || ($prompt eq '')) { $prompt = $iniref->{'PROMPTDEFAULT'}; }
	$prompt = &ZOOVY::incode($prompt);
	my $button = &TOXML::RENDER::smart_load($SITE,$iniref->{'BUTTONATTRIB'});
	if ((not defined $button) || ($button eq '')) { $button = $iniref->{'BUTTONDEFAULT'}; }
	$button = &ZOOVY::incode($button);
	my $options = '';
	foreach my $cat (keys %{$catalogs})
	{
		my $selected = '';
		if ($catalogs->{$cat}->{'CATALOG'} eq $selected_catalog) { $selected = ' selected'; }
		$options .= qq~<option value="$catalogs->{$cat}->{'CATALOG'}"$selected>$catalogs->{$cat}->{'CATALOG'}</option>~;
	}

	my $out = qq~
		<font class="title">Search Box Configuration</font>
		<table width="500">
			<tr>
				<td width="20%">
					<font class="smalltitle">Catalog:</td>
				<td>
					<select name="CATALOG">
					<option value="">Title Search Only</option>
					$options
					</select>
				</td>
			</tr>
<!--
			<tr>
				<td colspan='2'>
				Mode: <select name="MODE">
				<option value="">OR (default - most results)</option>
				<option value="AND">AND (recommended)</option>
				<option value="EXACT">EXACT</option>
				</select>
				</td>
			</tr>
-->
			<tr>
				<td colspan='2'>
					If you do not have advanced site search enabled, then leave the
					CATALOG blank to default to a product title search, otherwise enter
					the name of your catalog (e.g. DEFAULT)
				</td>
			</tr>
			<tr>
				<td><font class='smalltitle'>Search Box Prompt:</td>
				<td><input type='textbox' size='50' name='PROMPT' value='$prompt'></td>
			</tr>
			<tr>
				<td><font class='smalltitle'>Button Message</td>
				<td><input type='textbox' name='BUTTON' value='$button'></td>
			</tr>	
		</table>
	~;

	my $PROMPT = $iniref->{'PROMPT'};
	return('SEARCH',$PROMPT,$out);
}

##
##
##
sub EDIT_PRODLIST {
	my ($iniref,undef,$SITE) = @_;

	##
	## Okay, here's the plan, the OLD format was a kludge. 
	## 	basically DATA contained comma ($format,$cols,$alternate,$sortby,$params)
	##		then $params is a colon delimited key=value set of pairs (which doesn't allow any non-word characters)
	##		SO ... that is fucked. 
	##
	##	Also $iniref->{'DEFAULT'} contains the old legacy "saveto" format, but only default values. How fucked!
	##
	## My "ultimate" solution:
	##		recycle "DATA" and "DEFAULT" .. but have a leading "\n" in the data to denote it's a new format. 
	##		version 2 is formatted as such:
	##			key=value\nkey=value\n [e.g. use split(/,/,$some,2); .. ] the entire string should have a leading \n
	##			the keys should always be upper case, and they should ALWAYS be regular characters
	##			the values should always be URI encoded (e.g. \n becomes %0A) .. this should allow us to store much
	##			more complicate data structures.
	##		
	##		note: the escaping "\n" is a work around, it isn't necessary once every flow has been upgraded to the new
	##			format.
	##			

	# Load info from page
	my $DATA = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'},$iniref->{'LOADFROM'},$iniref->{'DEFAULT'});
	## NOTE: DEFAULT must be loaded here, so we can treat it as either legacy format, or current format.
	if ($DATA eq '') { $DATA = $iniref->{'DEFAULT'}; }

	## NOTE: $DATA is NOT getting the default user settings from webdb.bin
	## should be getting PRODLIST_DEFAULT
	## looks like the the element name in $initef->{'DATA'} is incorrect??
	my $params = &TOXML::RENDER::parse_prodlist_data($DATA,$iniref,$SITE);		# params contains the user settings.

	my $ID = $iniref->{'ID'};
	if (not defined $ID) { $ID = $iniref->{'_ID'}; }
	
	# Proper values are
	#	DEFAULT = Get information from the products manually added into this website category by the merchant
	#	CHOOSE = User select the smart source
	#	BYCATEGORY = Products are dynamic by items currently in the users cart, as organized into website
	#		categories by the merchant (uses default if no matching items are found)

	my $DEFAULT_SRC = $SITE->pageid();
	if ((defined $params->{'SRC'}) && ($params->{'SRC'} ne '')) { $DEFAULT_SRC = $params->{'SRC'}; }
	my $DEFAULT_CATEGORY = $DEFAULT_SRC;
	if ($DEFAULT_SRC eq '.') {
		## we might be in a specialty site so we should load the root
		$DEFAULT_SRC = $SITE->nsref()->{'zoovy:site_rootcat'};
		$DEFAULT_CATEGORY = ' ROOT CATEGORY:'.$DEFAULT_SRC;
		}
	if ((substr($DEFAULT_SRC,0,1) eq '.') || (substr($DEFAULT_SRC,0,1) eq '$')) {
		my ($NC) = NAVCAT->new($SITE->username(),PRT=>$SITE->prt());
		(undef,undef,undef,$params->{'SORTBY'}) = $NC->get($DEFAULT_SRC);
		undef $NC;
		}


	my $notes = '';

	my $out = '';
	$out .= '<table border=0><tr><td>';

	if ($iniref->{'FORMAT'} eq 'CUSTOM') {
		$out .= '<input type="hidden" name="FORMAT" value="CUSTOM"><b>Listing Style:</b> Custom Format<br>';
		}
	elsif (not $iniref->{'FORMAT'}) {
		$out .= '<b>Listing Style:</b> ['.$iniref->{'FORMAT'}.']<br>';
		$out .= "<select name=\"FORMAT\" onChange=\"prodlistEditorUpdate(this,'$ID');\">";
			if ($params->{'FORMAT'} eq '') { 
				$out .= '<option value=""'.(($params->{'FORMAT'} eq '')?' SELECTED ':'').'>*** NOT CONFIGURED ***</option>';
				}

			if (not $iniref->{'SMARTSOURCE'}) {
				$out .= '<option value="DEFAULT"'.(($params->{'FORMAT'} eq 'DEFAULT')?' SELECTED ':'').'>Default - use system wide preference.</option>';
				$out .= '<option value=""></option>';
				}
			$out .= '<option value="THUMB"'.(($params->{'FORMAT'} eq 'THUMB')?' SELECTED ':'').'>Thumbnail Preview</option>';
			$out .= '<option value="BIGTHUMB"'.(($params->{'FORMAT'} eq 'BIGTHUMB')?' SELECTED ':'').'>Big Thumbnail Preview</option>';
			$out .= '<option value="THUMBMSRP"'.(($params->{'FORMAT'} eq 'THUMBMSRP')?' SELECTED ':'').'>Thumbnail w/Retail Price</option>';
			$out .= '<option value=""></option>';
			$out .= '<option value="DETAIL"'.(($params->{'FORMAT'} eq 'DETAIL')?' SELECTED ':'').'>Detailed Description w/Small Icon (Style 1)</option>';
			$out .= '<option value="DETAIL2"'.(($params->{'FORMAT'} eq 'DETAIL2')?' SELECTED ':'').'>Detailed Description w/Small Icon (Style 2)</option>';
			$out .= '<option value="MULTIADD"'.(($params->{'FORMAT'} eq 'MULTIADD')?' SELECTED ':'').'>Detailed Description w/Small Icon + Multi Add to Cart</option>';
			$out .= '<option value="BIG"'.(($params->{'FORMAT'} eq 'BIG')?' SELECTED ':'').'>Detailed Description w/BIG Picture (Style 1)</option>';
			$out .= '<option value="BIG2"'.(($params->{'FORMAT'} eq 'BIG2')?' SELECTED ':'').'>Detailed Description w/BIG Picture (Style 2)</option>';
			$out .= '<option value=""></option>';
			$out .= '<option value="PLAINMSRP"'.(($params->{'FORMAT'} eq 'PLAINMSRP')?' SELECTED ':'').'>Plain List w/Retail Price</option>';		
			$out .= '<option value="PLAIN"'.(($params->{'FORMAT'} eq 'PLAIN')?' SELECTED ':'').'>Plain List</option>';
			$out .= '<option value="PLAINMULTI"'.(($params->{'FORMAT'} eq 'PLAINMULTI')?' SELECTED ':'').'>Plain List, w/Multi Add to Cart</option>';
			$out .= '<option value="SMALLMULTI"'.(($params->{'FORMAT'} eq 'SMALLMULTI')?' SELECTED ':'').'>Plain List, w/Tiny Icon + Multi Add to Cart</option>';
		$out .= '</select>';
		$out .= "<br>\n";
		}
	else {
		$out .= "<input type=\"hidden\" name=\"FORMAT\" value=\"$params->{'FORMAT'}\"><b>Listing Style:</b> $params->{'FORMAT'}<br>";
		}


	if ($iniref->{'SRC'} ne '') {
		$out .= "Products Source: $iniref->{'SRC'}<br>";
		}
	else {
		$out .= 'Products Source: ';
		$out .= '<select name="SRC">';
		if ($SITE->pid() eq '') {
			## EDITING A CATEGORY PAGE
			$out .= '<option '.(($params->{'SRC'} eq '')?' selected':'').qq~ value="">Default Source: $DEFAULT_CATEGORY</option>~;
#			$out .= '<option '.(($params->{'SRC'} eq 'NAVCAT:')?' selected':'').' value=""> Use Products in current Category</option>';
			}
		else {
			## EDITING A PRODUCT PAGE
			$out .= '<option value="PRODUCT:zoovy:related_products">Related Products</option>';
			}
		
		if ($SITE->pageid() eq '*cart') {
			$out .= '<option value="SMART:BYCATEGORY" '.(($params->{'SRC'} eq 'SMART:BYCATEGORY')?' selected':'').'>Dynamic, from categories associated to items in cart</option>';
			$out .= '<option value="SMART:BYPRODUCT"'.(($params->{'SRC'} eq 'SMART:BYPRODUCT')?' selected':'').'>Dynamic, related products</option>';
			$out .= '<option value="SMART:ACCESSORIES"'.(($params->{'SRC'} eq 'SMART:ACCESSORIES')?' selected':'').'>Dynamic, product accessories</option>';
	
			$notes .= "* The &quot;Website Category&quot; option means the products listed will be products ";
			$notes .= "specifically added to this page (just like regular categories).  The &quot;Dynamic&quot; ";
			$notes .= "mode determines the product list from the contents of the user's cart.  If it can't match ";
			$notes .= "any products in the cart, it pulls its list from the website category.  The preview on the next ";
			$notes .= "page will always show as if it were in &quot;Website Category&quot; mode.<br>\n";
			}

		if (1) {
			use NAVCAT;
			my ($NC) = NAVCAT->new($SITE->username(),PRT=>$SITE->prt());
			foreach my $safe ($NC->paths()) {
				next if (substr($safe,0,1) ne '$'); 	
				my ($PRETTY) = $NC->get($safe);
				$out .= "<option value='LIST:$safe' ".(($params->{'SRC'} eq "LIST:$safe")?'selected':'')."> LIST: $PRETTY</option>\n";
				}
			undef $NC;
			}
		$out .= '</select>';
		$out .= "<br>\n";
		}

	if (($params->{'SRC'} eq 'SMART:BYPRODUCT') || ($params->{'SRC'} eq 'SMART:BYCATEGORY')) {
		$out .= 'Maximum products in dynamic result: ';
		$out .= "<input type=\"text\" name=\"SMARTMAX\" value=\"$params->{'SMARTMAX'}\" size=\"3\" maxlength=\"2\">";
		$out .= "<br>(Reduce the maximum products to increase website performance - only applies to Dynamic types.)<br><br>\n";
		}
	else {
		delete $params->{'SMARTMAX'};
		}

	if ($params->{'FORMAT'} eq 'DEFAULT') {
		$out .= "<br>NOTE: This product listing is configured to use the system wide \"DEFAULT\" formatting rules.<br>";
		}

	if ($params->{'FORMAT'} ne 'DEFAULT') {

		# print STDERR "EDITING PRODLIST\n";
		$out .= "<b>Display Properties:</b><br>";
		$out .= 'Background ';
		$out .= "<select  onChange=\"prodlistEditorUpdate(this,'$ID');\" name=\"ALTERNATE\">";
			$out .= '<option value="1"'.(($params->{'ALTERNATE'}==1)?' selected':'').'>Alternating Colors 1 and 2';
			$out .= '<option value="0"'.(($params->{'ALTERNATE'}==0)?' selected':'').'>Table Color 1';
			$out .= '<option value="2"'.(($params->{'ALTERNATE'}==2)?' selected':'').'>Table Color 2';
			$out .= '<option value="3"'.(($params->{'ALTERNATE'}==3)?' selected':'').'>Page Background Color';
			$out .= '<option value="4"'.(($params->{'ALTERNATE'}==4)?' selected':'').'>Page Background Pattern';
		$out .= '</select>';
		$out .= "<br><br>\n";
		}

	if ($params->{'FORMAT'} ne 'DEFAULT') {
		$out .= 'Show SKU with Product Name ';
		$out .= "<select  onChange=\"prodlistEditorUpdate(this,'$ID');\" name=\"SHOWSKU\">";
			$out .= '<option value=""'.(($params->{'SHOWSKU'} eq '')?' selected':'').'>Do not show the SKU with the product name';
			$out .= '<option value="before"'.(($params->{'SHOWSKU'} eq 'before')?' selected':'').'>Show the SKU before the product name';
			$out .= '<option value="after"'.(($params->{'SHOWSKU'} eq 'after')?' selected':'').'>Show the SKU after the product name';
		$out .= '</select>';
		$out .= "<br><br>\n";
		}
	
	## removed conditional about params->{'SORTBY'}, 
	## ie if this isn't set, we should still give the merchant the chance to set it
	#if (($params->{'FORMAT'} ne 'DEFAULT') && ($params->{'SORTBY'} ne '')) {
	if ($params->{'FORMAT'} ne 'DEFAULT') {
		## added condition 2007-01-15 - patti
		## sorting isn't available for Search Results page
		if ($SITE->pageid() ne 'results') {
			$out .= 'Sort Products by ';
			$out .= '<select name="SORTBY">';
				$out .= '<option value="NONE"'.(($params->{'SORTBY'} eq "NONE")?' selected ':'').'>Default / Manual Sort</option>';
				$out .= '<option value="NAME"'.(($params->{'SORTBY'} eq "NAME")?' selected ':'').'>Product Name, Alphabetically</option>';
				$out .= '<option value="NAME_DESC"'.(($params->{'SORTBY'} eq "NAME_DESC")?' selected ':'').'>Product Name, Reverse Alphabetically</option>';
				$out .= '<option value="PRICE"'.(($params->{'SORTBY'} eq "PRICE")?' selected ':'').'>Price, Lowest to Highest</option>';
				$out .= '<option value="PRICE_DESC"'.(($params->{'SORTBY'} eq "PRICE_DESC")?' selected ':'').'>Price, Highest to Lowest</option>';
				$out .= '<option value="SKU"'.(($params->{'SORTBY'} eq "SKU")?' selected ':'').'>SKU, Alphabetically</option>';
				$out .= '<option value="SKU_DESC"'.(($params->{'SORTBY'} eq "SKU_DESC")?' selected ':'').'>SKU, Reverse Alphabetically</option>';
			$out .= '</select>';
			$out .= "<br><br>\n";
			}
		}

	if (($params->{'FORMAT'} eq 'THUMB') || ($params->{'FORMAT'} eq 'BIGTHUMB') || ($params->{'FORMAT'} eq 'THUMBMSRP')) {
		if (not defined $iniref->{'COLS'}) {
			# Unless we're forcing thumbnail don't allow them to choose columns
			# Or of course if we're not forcing anything, show it always
			$out .= 'Number of Columns per Row is ';
			$out .= "<select  onChange=\"prodlistEditorUpdate(this,'$ID');\" name=\"COLS\">";
				$out .= '<option value="2"'.(($params->{'COLS'} eq "2")?' selected ':'').'>2</option>';
				$out .= '<option value="3"'.(($params->{'COLS'} eq "3")?' selected ':'').'>3</option>';
				if ($params->{'FORMAT'} ne 'BIGTHUMB') {
					$out .= '<option value="4"'.(($params->{'COLS'} eq "4")?' selected ':'').'>4</option>';
					}
			$out .= '</select>';
			$out .= "<br><br>\n";
			}	
		else {
			$out .= "<input type=\"hidden\" name=\"COLS\" value=\"$iniref->{'COLS'}\">";
			}	# COLS was defined
		}
	else {
		delete $params->{'COLS'};
		}

	if ($params->{'FORMAT'} ne 'DEFAULT') {
		if ($iniref->{'CHANGESHOWPRICE'} || ($params->{'FORMAT'} eq 'THUMB') || ($params->{'FORMAT'} eq 'BIGTHUMB')) {
			$out .= 'Display of Price is ';
			$out .= "<select onChange=\"prodlistEditorUpdate(this,'$ID');\" name=\"SHOWPRICE\">";
				$out .= '<option value="1"'.(($params->{'SHOWPRICE'} eq "1")?' selected ':'').'>Enabled</option>';
				$out .= '<option value="0"'.(($params->{'SHOWPRICE'} eq "0")?' selected ':'').'>Disabled</option>';
			$out .= '</select>';
			$out .= "<br><br>\n";
			}
		}

	if ($params->{'FORMAT'} ne 'DEFAULT') {
		if ( ($params->{'FORMAT'} eq 'DETAIL') || ($params->{'FORMAT'} eq 'DETAIL2') || 
			  ($params->{'FORMAT'} eq 'MULTIADD') || ($params->{'FORMAT'} eq 'BIG') || ($params->{'FORMAT'} eq 'BIG2')) {	
			$out .= '&quot;View Details&quot; Link is ';
			$out .= "<select onChange=\"prodlistEditorUpdate(this,'$ID');\"   name=\"VIEWDETAILS\">";
				$out .= '<option value="1"'.(($params->{'VIEWDETAILS'} eq "1")?' selected ':'').'>Enabled</option>';
				$out .= '<option value="0"'.(($params->{'VIEWDETAILS'} eq "0")?' selected ':'').'>Disabled</option>';	
			$out .= '</select>';
			$out .= "<br><br>\n";
			}
		}
	
	if ($params->{'FORMAT'} ne 'DEFAULT') {
		if ( ($params->{'FORMAT'} eq 'MULTIADD') || ($params->{'FORMAT'} eq 'SMALLMULTI') || 
			  ($params->{'FORMAT'} eq 'PLAINMULTI') || ($params->{'FORMAT'} eq 'CUSTOM')) {	
			$out .= 'To Add To Cart a Customer ';
			$out .= '<select name="SHOWQUANTITY">';
				$out .= '<option value="1"'.(($params->{'SHOWQUANTITY'} eq "1")?' selected ':'').'>Enters a Quantity</option>';
				$out .= '<option value="0"'.(($params->{'SHOWQUANTITY'} eq "0")?' selected ':'').'>Checks a Checkbox</option>';	
			$out .= '</select>';
			$out .= "<br><br>\n";
			}
		}
	
	if (($params->{'FORMAT'} eq 'MULTIADD') || ($params->{'FORMAT'} eq 'SMALLMULTI') || ($params->{'FORMAT'} eq 'PLAINMULTI')) {	
		$out .= '&quot;Notes&quot; Field for Add to Cart is ';
		$out .= '<select name="SHOWNOTES">';
			$out .= '<option value="1"'.(($params->{'SHOWNOTES'} eq "1")?' selected ':'').'>Enabled</option>';
			$out .= '<option value="0"'.(($params->{'SHOWNOTES'} eq "0")?' selected ':'').'>Disabled</option>';	
		$out .= '</select>';
		$out .= "<br><br>\n";
		}

	if ($params->{'FORMAT'} ne 'DEFAULT') {
		if (not defined $iniref->{'SIZE'}) {
			$out .= 'Number of Products Per Page: ';
			$out .= qq~<input type="text" size="3" name="SIZE" value="$params->{'SIZE'}"><br>~;
			$out .= "<font size=\"-1\"><i><b>Notes</b>: Leave this number blank to not divide into pages.<br>If a list of products is divided into multiple pages, the products will be shown only in default/category order.<br>Product list will not show multiple pages until this number is reached.<br>Search engines are only capable of indexing the first page.</i></font><br>\n";
			$out .= "<br><br>\n";
			}
		}

	if (defined $iniref->{'SMARTSOURCE'}) {} 
	elsif ($iniref->{'FORMAT'} eq 'CUSTOM') {}
	elsif ($params->{'FORMAT'} ne 'DEFAULT') {
		$out .= "<b>Save settings system wide:</b><br>";
		$out .= "<input type=\"checkbox\" name=\"SAVE_AS_DEFAULT\"> Save these settings as my default, and set this category to the default.<br>";
		}

	$out .= '</td></tr></table><br>';

	if ($notes) {
		$out .= "<table width=\"500\"><tr><td align=\"left\"><small>$notes</small></td></tr></table>\n";
		}
	
	my $PROMPT = $iniref->{'PROMPT'};
	return 'PRODLIST',$PROMPT,$out;
}


##
##
##
sub EDIT_GALLERY {
	my ($iniref,undef,$SITE) = @_;

	# Load info from page
	my $val = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'},$iniref->{'LOADFROM'},$iniref->{'DEFAULT'});
	my ($format,$cols,$alternate,$sortby,$params) = split(/\,/, $val);
	# Load defaults for page
	my	($def_format,$def_cols,$def_alternate,$def_sortby,$def_params) = split(/,/, &ZOOVY::dcode($iniref->{'DEFAULT'}));

	# print STDERR "ALTERNATE: $alternate\n";

	unless (defined($format) && $format) { $format = $def_format; }
	unless (defined($cols) && $cols) { $cols = $def_cols; }
	unless (defined($alternate) && $alternate) { $alternate = $def_alternate; }
	unless (defined($sortby) && $sortby) { $sortby = $def_sortby; }
	
	# Parse additional parameters
	# NOTE: These parameters' names and values obvoiusly shouldn't contain ":", "=" or ","
	# since they are delimiters.  This is OK since we have control over what the meaning
	# of the names and values of these parameters are.
	my %param = ();
	# Load defaults first
	if (defined $def_params) {
		foreach my $nameval (split /\:/, $def_params) {
			my ($name, $val) = split /\=/, $nameval; $param{$name} = $val;
		}
	}
	# Then load the specified params
	if (defined $params) {
		foreach my $nameval (split /\:/, $params) {
			my ($name, $val) = split /\=/, $nameval; $param{$name} = $val;
		}
	}
	# Catch everything else since I don't want to change every PRODLIST in every flow :)
	if (not defined $param{'SHOWPRICE'}) { $param{'SHOWPRICE'} = 1; } # Have the showing of prices on by default

	# These settings force the use of defaults
	my $forcecolumns = 0;
	if (defined $iniref->{'FORCECOLUMNS'}) { $forcecolumns = $iniref->{'FORCECOLUMNS'}; }
	my $forceformat = 0;
	if (defined $iniref->{'FORCEFORMAT'}) { $forceformat = $iniref->{'FORCEFORMAT'}; }
	# Proper values are
	#	DEFAULT = Get information from the products manually added into this website category by the merchant
	#	CHOOSE = User select the smart source
	#	BYCATEGORY = Products are dynamic by items currently in the users cart, as organized into website
	#		categories by the merchant (uses default if no matching items are found)
	my $smartsource = 'DEFAULT'; # By default its a website category as the source for the listing
	require ZOOVY;

	my $notes = '';

	my $out = '';
	$out .= '<table><tr><td>';

	if (not $forceformat) {
		$out .= '<b>Listing Style:</b><br>';
		$out .= '<select name="LISTSTYLE" onChange="this.form.submit()">';
			$out .= '<option value="PLAIN"';
			if ($format eq "PLAIN") { $out .= ' selected' }
			$out .= '>Plain List';
	
			$out .= '<option value="THUMB"';
			if ($format eq "THUMB") { $out .= ' selected' }
			$out .= '>Thumbnail Preview';
	
		$out .= '</select>';
		$out .= "<br><br>\n";
	}
	else {
		$out .= "<input type=\"hidden\" name=\"LISTSTYLE\" value=\"$def_format\">";
	}
	
	$out .= 'Background ';
	$out .= '<select name="ALTERNATE">';
	
		$out .= '<option value="1"';
		if ($alternate == 1) { $out .= ' selected' }
		$out .= '>Alternating Colors 1 and 2';

		$out .= '<option value="0"';
		if ($alternate == 0) { $out .= ' selected' }
		$out .= '>Table Color 1';
	
		$out .= '<option value="2"';
		if ($alternate == 2) { $out .= ' selected' }
		$out .= '>Table Color 2';
	
		$out .= '<option value="3"';
		if ($alternate == 3) { $out .= ' selected' }
		$out .= '>Page Background Color';

		$out .= '<option value="4"';
		if ($alternate == 4) { $out .= ' selected' }
		$out .= '>Page Background Pattern';

	$out .= '</select>';
	$out .= "<br><br>\n";
	
	# Insert sorting stuff here eventually
	
	if ($format eq 'THUMB') {
		if (not $forcecolumns) {
			# Unless we're forcing thumbnail don't allow them to choose columns
			# Or of course if we're not forcing anything, show it always
			if ((not $forceformat) || ($def_format eq 'THUMB')) { 
				$out .= 'Number of Columns per Row is ';
				$out .= '<select name="COLS">';
				$out .= '<option value="2"'.(($cols == 2)?' selected':'').'>2</option>';
				$out .= '<option value="3"'.(($cols == 3)?' selected':'').'>3</option>';
				$out .= '<option value="4"'.(($cols == 4)?' selected':'').'>4</option>';
				$out .= '</select>';
				$out .= "<br><br>\n";
			}
			else {
				$out .= "<input type=\"hidden\" name=\"COLS\" value=\"$def_cols\">";
			}
		}
	}

	if ($format eq 'THUMB') {
		$out .= 'Display of Price is ';
		$out .= '<select name="SHOWPRICE">';
	
			$out .= '<option value="1"';
			if ($param{'SHOWPRICE'}) { $out .= ' selected' }
			$out .= '>Enabled';

			$out .= '<option value="0"';
			if (not $param{'SHOWPRICE'}) { $out .= ' selected' }
			$out .= '>Disabled';
	
		$out .= '</select>';
		$out .= "<br><br>\n";
	}

	$out .= '</td></tr></table><br>';

	if ($notes) {
		$out .= "<table width=\"500\"><tr><td align=\"left\"><small>$notes</small></td></tr></table>\n";
	}
	
	my $PROMPT = $iniref->{'PROMPT'};
	return 'GALLERY',$PROMPT,$out;
}




################################### BEGIN DEFINITION EDITOR ELEMENTS

##
## used to output unknown element types.
##
sub handle_error {
	my ($iniref) = @_;
	# print STDERR Dumper($iniref);
	return("<tr><td>Unknown Element $iniref->{'TYPE'}<br></td></tr>");
	}


#if (defined %parse) {}; #Keeps perl -w from bitching
#if (defined %display) {};
sub is_global {
	my ($NAME) = @_;
	my ($is_global) = 0;
	if (substr($NAME,0,9) eq 'merchant') { $is_global++; }
	elsif (substr($NAME,0,7) eq 'profile') { $is_global++; }
	elsif (substr($NAME,0,7) eq 'wrapper') { $is_global++; }
	return(($is_global)?'<img align="left" src="/images/globe.gif" border="0">':'');
	}

sub element_null { return('NULL'); };		# note: this will bump the color
sub element_blank { return('BLANK'); };	# note: this creates a blank frame, AND bumps the color


#sub element_button {
#	my ($el,undef,$SITE) = @_;

#$VAR1 = {
#          'VAR3' => 'ebay:title',
#          'URL' => 'http://app3.zoovy.com/ebayapi/catchooser/index.cgi/v1=ebay:category',
#          'ID' => 'CPVNNNW',
#          'TARGET' => '@REMOTEDIV',
#          'VAR4' => 'ebay:productid',
#          'TYPE' => 'BUTTON',
#          'VAR1' => 'ebay:category',
#          'VAR6' => 'ebay:financeoffer',
#          'PROMPT' => 'Choose Category 1 (NEW FORMAT)',
#          'VAR5' => 'ebay:attributeset',
#          'VAR2' => 'ebay:username'
#        };
	
#	$el->{'URL'} = 'http://app3.zoovy.com/ebayapi/catchooser/index2.cgi';
#	$el->{'URL'} = 'http://app3.zoovy.com/ebayapi/catchooser/motor.cgi'

#	if (($el->{'TYPE'} eq 'BUTTON') && ($el->{'TARGET'} eq '@REMOTEDIV')) {
#		my $params = &ZTOOLKIT::buildparams($el);
#
#		my $info = '';
#		if ($el->{'URL'} =~ /ebay/) {
#			if ($SITE->{'%PRODREF'}->{'ebay:attributeset'} ne '') { 
#				$info .= "<li> eBay Attribute Data has been set."; 
#				}
#			elsif ($SITE->{'ebay:attributeset'} ne '') { 
#				$info .= "<li> eBay Attribute Data has been set."; 
#				}
#			else {
#				$info .= "<li> eBay Attribute Data has NOT been set.";
#				}
#			# use Data::Dumper; $info = '<pre>'.Dumper($SITE).qq~</pre>~;
#			}
#
#		return('BUTTON',qq~
#		<input type="button" value="$el->{'PROMPT'}" onClick="clickBtn('REMOTEDIV?$params');"> 
#		$info
#		~);
#		}
#	elsif (($el->{'TYPE'} eq 'BUTTON') && ($el->{'TARGET'} eq 'OMEGA')) { return('NULL',''); }
#	elsif ($el->{'TYPE'} eq 'BUTTON') {
#		return('BUTTON',qq~
#		<input type="button" value="$el->{'PROMPT'}" onClick="clickBtn('TARGET?DIV=$el->{'TARGET'}');">
#		~);
#		}
#	else {
#		return('','Unknown button type');
#		}
#
#
#	# print STDERR Dumper($el);
#	die();
#	}

sub element_meta {	
	my ($el) = @_;
	
	$TEMPLATE::COLORCOUNT--;		# these should NOT bump the color counter
	
	##	<META> HANDLER
	## META TITLE
	if ($el->{'STYLE'} eq 'TITLE') {
		$GTOOLS::TAG{'<!-- TITLE -->'} = $el->{'TEXT'};
		}
	if ($el->{'STYLE'} eq 'LOGO') {
		my $c .= "<img src=\"$el->{'SRC'}\" border=\"0\" ";
		if (defined $el->{'WIDTH'}) { $c .= " width=\"$el->{'WIDTH'}\" "; }
		if (defined $el->{'HEIGHT'}) { $c .= " height=\"$el->{'HEIGHT'}\" "; }
		if (defined $el->{'ALIGN'}) { $c .= " align=\"$el->{'ALIGN'}\" "; }
		if (defined $el->{'ALT'}) { $c .= " align=\"$el->{'ALT'}\" "; }
		$c .= ">";
		if (defined $el->{'URL'}) { 
			$c = "<a target=\"_blank\" href=\"$el->{'URL'}\">$c</a>";
			}
		$GTOOLS::TAG{'<!-- LOGO -->'} = "<td>$c</td>";
		}
	## META DESCRIPTION
	if ($el->{'STYLE'} eq 'DESCRIPTION') {
		$GTOOLS::TAG{'<!-- DESCRIPTION -->'} = '<td width="60%" class="divdescription">'.$el->{'TEXT'}.'</td>'
		}
	## END </META> HANDLER
	return('META','');
	}


sub element_display {
	my ($el,$toxml,$SITE) = @_;

	my $out = '';
	my $STYLE = $el->{'STYLE'};
	$TEMPLATE::COLORCOUNT--;
	if ($TEMPLATE::COLORCOUNT%2 == 0) { $TEMPLATE::BGCOLOR = 'f0f0f0'; } else { $TEMPLATE::BGCOLOR = 'FFFFFF'; }

	my $TITLE = $el->{'TITLE'};
	if (not defined $el->{'TITLE'}) { $TITLE = $el->{'TEXT'}; }
	if ($STYLE eq 'BYVALUE') {
		my $VALUE = &TOXML::RENDER::smart_load($SITE,$el->{'DATA'},$el->{'LOADFROM'},$el->{'VALUE'});
		$out = "<tr bgcolor='$TEMPLATE::BGCOLOR'><td valign='top'><b>$TITLE</b></td><td colspan='2'>$VALUE</td></tr>\n"; 
		}
	elsif ($STYLE eq 'BYPROMPT') {
		my ($RESULT,$SHOWVALUE) = ('',''); 
		my $VALUE = &TOXML::RENDER::smart_load($SITE,$el->{'DATA'},$el->{'LOADFROM'},$el->{'VALUE'});

		## Step1: lets create a hash of name (category value)/ value pairs
		my $LIST = $el->{'LIST'};
		my $SHOWVALUE = (defined($el->{'SHOWVALUE'}) && uc($el->{'SHOWVALUE'}) eq 'Y')?1:0;

		## Step2: iterate through the list, find the VALUE
		#### THIS HAS A BUG: it won't work with image lists (well it sorta will, but we need to add more intelligence)
		$RESULT = $el->{'ERROR'};
		my $RESULTSREF = $toxml->getListOptByAttrib($LIST,'V',$VALUE);
		if (scalar(@{$RESULTSREF})==0) { 
			$RESULT = $el->{'ERROR'}; 
			}
		else {
			$RESULT = $RESULTSREF->[0]->{'T'};
			if ($SHOWVALUE) { $RESULT = $RESULT.' <font style="small">('.$VALUE.")</font>\n"; }
			}
		if (!defined($RESULT)) { $RESULT = ''; }
		$out = "<tr bgcolor='$TEMPLATE::BGCOLOR'><td valign='top'><b>$TITLE</b></td><td colspan='2'>$RESULT</td></tr>\n";
		}	
	elsif ($STYLE eq 'TITLE') {
		$out = "<tr bgcolor='330099'><td colspan='3'>&nbsp; <font color='white' style='title'><b>$TITLE</b></font></td></tr>";
		}
	elsif ($STYLE eq 'LABEL') {
		$out = "<tr bgcolor='$TEMPLATE::BGCOLOR'><td colspan='3'>$TITLE</td></tr>\n";
		}
	elsif ($STYLE eq 'IMAGE') {
		my $c .= "<img src=\"$el->{'SRC'}\" border=\"0\" ";
		if (defined $el->{'WIDTH'}) { $c .= " width=\"$el->{'WIDTH'}\" "; }
		if (defined $el->{'HEIGHT'}) { $c .= " height=\"$el->{'HEIGHT'}\" "; }
		if (defined $el->{'ALIGN'}) { $c .= " align=\"$el->{'ALIGN'}\" "; }	
		if (defined $el->{'ALT'}) { $c .= " align=\"$el->{'ALT'}\" "; }
		$c .= ">";
		if (defined $el->{'URL'}) { 
			$c = "<a target=\"_blank\" href=\"$el->{'URL'}\">$c</a>";
			}
		$out = "<tr bgcolor='$TEMPLATE::BGCOLOR'><td colspan='3'>$c</td></tr>\n";
		}
	elsif ($STYLE eq 'HELP') {
		$out = "<tr><td colspan='3'>$el->{'HTML'}</td></tr>";
		}
	else {
		$out = "<tr><td colspan='3'><br><font color='red'>Unknown element_display STYLE=[$STYLE] ".Dumper($el)."</font></td></tr>\n"; 
		} 

	return('FORMAT',$out);	
	}

############################################################


sub element_sku {
	my ($ref,undef,$SITE) = @_;

	my $SKU = $SITE->pid();
	my $NAME = $ref->{'DATA'};
	my $VALUE = &TOXML::RENDER::smart_load($SITE,$ref->{'DATA'},$ref->{'LOADFROM'},$ref->{'VALUE'});	
	if (!defined($VALUE)) { $VALUE = ''; }	# stop perl -w from whining

	return('SKU','Product SKU',$SKU.'<input type="HIDDEN" name="'.$NAME.'" value="'.&ZOOVY::incode($VALUE).'">');
	}

############################################################
sub element_inventory {
	my ($ref,$toxml,$SITE) = @_;
	my $c = '';

	# things we need to check for:
	# MANDATORY="Y"
	# SIZE
	# MAXLENGTH
	# FORMAT
	# HELP
	# MIN

	my $SKU = $SITE->pid();
	my $PRODREF  = $SITE->{'%PRODREF'};
	my $ID = $ref->{'ID'};

	my $HELP = ''; my $TYPE = ''; my $SIZE = '';
	my ($NAME) = &tagname($ref->{'DATA'});
	if (!defined($ref->{'HELP'})) { $HELP = ''; } else { $HELP = $ref->{'HELP'}; }

	my $VALUE = &TOXML::RENDER::smart_load($SITE,$ref->{'DATA'},$ref->{'LOADFROM'},$ref->{'VALUE'});
	if (not defined($VALUE)) { $VALUE = ''; }
	my $PROMPT = $ref->{'PROMPT'};
	my $COLS = $ref->{'COLS'};
	if (not defined($COLS)) { $COLS = 0; }

	#if ($PRODREF->{'zoovy:inv_enable'} > 0) {
	#	## note: we probably ought not to let inventory be set negative.. but the system OUGHT to be smart enough to let 
	#	## any <0 number to zero. .. we'll see??
	#	##

	#	$PROMPT = "<font color=\"red\">INVENTORY - </font>".$PROMPT;
	#	$TOXML::EDIT::META{'CHECKFORM'} .= "\nwindow.document.thisFrm.elements['$NAME'].value = validated('-0123456789',window.document.thisFrm.elements['$NAME'].value);\n";
	#	if ($PRODREF->{$SITE->username().':pogs'} ne '') {
	#		$HELP = "<font color='red'>WARNING: This product has options, which are not compatible with channels! (YET)</font><br>".$HELP;
	#		} 
	#	else {
	#		require INVENTORY;
	#		my ($actual,$reserved) = &INVENTORY::fetch_incremental($SITE->username(),$SKU);
	#		$HELP = "<font color='blue'>In Stock: $actual - Reserved: $reserved</font><br>\n".$HELP;
	#		}
	#	}	
	#else {
	#	## inventory disabled -1 allowed!
	#	$TOXML::EDIT::META{'CHECKFORM'} .= "\nwindow.document.thisFrm.elements['$NAME'].value = validated('-0123456789',window.document.thisFrm.elements['$NAME'].value);\n";
	#	}

	# a little bit 'o' validation.
	$TOXML::EDIT::META{'CHECKFORM'} .= "if (window.document.thisFrm.elements['$NAME'].value.length<=0) { \n";
	$TOXML::EDIT::META{'CHECKFORM'} .= "   alert (\"Please fill in the INVENTORY field prior to proceeding.\");\n ";
	$TOXML::EDIT::META{'CHECKFORM'} .= "   return false; }\n";

	$VALUE = &ZOOVY::incode($VALUE);


	return('INVENTORY',is_global($ref->{'DATA'}).$PROMPT,"<input type='textbox' name='$NAME' value=\"$VALUE\" $SIZE size=\"5\"><br>".$HELP);
}





## sub stripns
## Purpose: strip a namespace:owner:tag to simply owner:tag
##
sub stripns
{
	my ($tag) = @_;
	my @ar = split(':',$tag);
	return($ar[1].':'.$ar[2]);
}



## sub tagname
## Purpose: 
## 	fucked up netscape can't use non alphanum chars in javascript variables.
##		so for stuff that uses js we gotta make a js safe name.
##		
sub tagname {
	my ($datasrc) = @_;
	my ($ns,$tag) = split(/:/,$datasrc,2);
	return($tag);	
	}


#sub element_counter {
#	my ($ref,$toxml,$SITE) = @_;
#
#	my $NAME = &tagname($ref->{'DATA'});
#	my $PROMPT = $ref->{'PROMPT'};
#	my $VALUE = &TOXML::RENDER::smart_load($SITE,$ref->{'DATA'},$ref->{'LOADFROM'},$ref->{'VALUE'});
#
#	my %serial = ();
#	$serial{'ATTRIB'} = $NAME;
#
#	my $passthis = &ZTOOLKIT::fast_serialize(\%serial,1);
#	my $t = time();
#
#	my $COL2 = "<img name=\"${NAME}img\" src=\"/images/samples/counters/$VALUE.gif\">";
#
#	my $COL3 = "<input type=\"hidden\" name=\"$NAME\" value=\"".&ZOOVY::incode($VALUE)."\">\n";
#	$COL3 .= "<input type=\"BUTTON\" value=\"Change Counter\" onClick=\"javascript:openWindow('counter.cgi?SERIAL=$passthis&$t');\"><br>";
#
##	$c = '<pre>'.Dumper($ref).'</pre>';
#	return('COUNTER',$PROMPT,$COL2,$COL3);	
#}



sub element_radio {
	my ($ref,$toxml,$SITE) = @_;
	my $c = '';

	my $COL2 = ''; my $CHECKED = ''; my $NAME = ''; my $SHOWVAL = ''; my $SHOWVALUE = ''; 
	# things we need to check for:
	# FORMAT

	my $VALUE = &TOXML::RENDER::smart_load($SITE,$ref->{'DATA'},$ref->{'LOADFROM'},$ref->{'VALUE'});
	my $PROMPT = $ref->{'PROMPT'};
	my $RADIONAME = $ref->{'DATA'};
	if (defined($ref->{'SHOWVALUE'}) && uc($ref->{'SHOWVALUE'}) eq 'Y')
		{ $SHOWVALUE = 1; } else { $SHOWVALUE = 0; }

	## Step1: lets create a hash of name (category value)/ value pairs
	my $LISTID = $ref->{'LIST'};
	my $listref = undef;
	if (defined($LISTID)) {
		$listref = $toxml->getList($LISTID);
		}

	# Step2: figure out which name we should use
	my $NAME = &tagname($ref->{'DATA'});

	## Step2: %hash is fully loaded.
	if (defined $listref) {
		foreach my $opt (@{$listref}) {
			my $THISVAL = &ZOOVY::incode($opt->{'V'});
			if (not defined $THISVAL) { $THISVAL = ''; }
			if ($THISVAL eq $VALUE) { $CHECKED = ' CHECKED '; } else { $CHECKED=''; }
			if ($SHOWVALUE) { $SHOWVAL = '<font style="small">(#'.$THISVAL.')</font>'; } else { $SHOWVAL = ''; }
			$c .= "<Tr><td><input type='radio' name=\"$NAME\" $CHECKED value=\"$THISVAL\"> $opt->{'T'} $SHOWVAL</font></td></tr>\n";
			}
		$COL2 = '<table border="0" cellspacing="0" cellpadding="0">'.$c.'</table>';
		}
	else {
		$COL2 = "<font color='red'>ERROR - LIST: $LISTID undefined</font>";
		}
	

	return('RADIO',is_global($ref->{'DATA'}).$PROMPT,$COL2);	
}



sub element_tree {
	my ($ref,$toxml,$SITE) = @_;
	my $c = '';



	my $COL2 = ''; my $CHECKED = ''; my $NAME = ''; my $SHOWVALUE = ''; my $SHOWVAL = ''; my $VALUE = '';

	# things we need to check for:
	# FORMAT

	$VALUE = &TOXML::RENDER::smart_load($SITE, $ref->{'DATA'},$ref->{'LOADFROM'},$ref->{'VALUE'});
	my $PROMPT = $ref->{'PROMPT'};
	my $RADIONAME = $ref->{'DATA'};
	if (defined($ref->{'SHOWVALUE'}) && uc($ref->{'SHOWVALUE'}) eq 'Y')
		{ $SHOWVALUE = 1; } else { $SHOWVALUE = 0; }

	my $hashref = undef;
	## Step1: lets create a hash of name (category value)/ value pairs
	my $LISTID = $ref->{'LIST'};
	my $listref = undef;
	if (defined($LISTID)) {
		$listref = $toxml->getList($LISTID);
		}

	# Step2: figure out which name we should use
	$NAME = &tagname($ref->{'DATA'});

	## Step2: %hash is fully loaded.
	if (defined $listref) {
		foreach my $opt (@{$listref}) {
		my $THISVAL = $opt->{'V'};

			if ((defined($VALUE)) && (defined($THISVAL)) && ($THISVAL eq $VALUE)) 
				{ $CHECKED = ' CHECKED SELECTED checked selected '; } else { $CHECKED=''; }
			$THISVAL = &ZOOVY::incode($THISVAL);
			if ($SHOWVALUE) { $SHOWVAL = '<font style="small">(#'.$THISVAL.')</font>'; } else { $SHOWVAL = ''; }
			$c .= "<input type='radio' name=\"$NAME\" $CHECKED value=\"$THISVAL\">  $opt->{'T'} $SHOWVAL</font><br>\n";
			}
		}

	$COL2 = $c;
	return('TREE',is_global($ref->{'DATA'}).$PROMPT,$COL2);	
}



##################################################################
##
## element_imageselect
## purpose: create an image dialog
##
##################################################################
sub element_imageselect {
	my ($ref,$toxml,$SITE) = @_;
	my $c = '';
	my $COL2 = '';

	# things we need to check for:
	# FORMAT

	my $VALUE = &TOXML::RENDER::smart_load($SITE, $ref->{'DATA'},$ref->{'LOADFROM'},$ref->{'VALUE'});
	my $PROMPT = $ref->{'PROMPT'};
	my $RADIONAME = $ref->{'DATA'};
	my $SHOWVAL = '';
	my $NAME = '';
	my $SSLIFY;
	my $SHOWVALUE;
	if (defined($ref->{'SHOWVALUE'}) && uc($ref->{'SHOWVALUE'}) eq 'Y')
		{ $SHOWVALUE = 1; } else { $SHOWVALUE = 0; }

	## Step1: lets create a hash of name (category value)/ value pairs
	my $LISTID = $ref->{'LIST'};
	my $listref = undef;
	if (defined($LISTID)) {
		$listref = $toxml->getList($LISTID);
		}

	# Step2: figure out which name we should use
	$NAME = &tagname($ref->{'DATA'});

	## Step2: %hash is fully loaded.
	if (defined $listref) {
		foreach my $opt (@{$listref}) {
			my $THISVAL = &ZOOVY::incode($opt->{'V'});
			my $CHECKED = '';

			if ($THISVAL eq $VALUE) { $CHECKED = ' CHECKED '; } else { $CHECKED=''; }
			if ($SHOWVALUE) { $SHOWVAL = '<font style="small">(#'.$THISVAL.')</font>'; } else { $SHOWVAL = ''; }
			if (not defined $opt->{'THUMB'}) { $opt->{'THUMB'} = $opt->{'SRC'}; }	# conflicting ?? IMAGELIST IMAGESELECT
			my $SRC = &ZOOVY::mediahost_imageurl($SITE->username(),$opt->{'THUMB'},75,75,$TOXML::EDIT::BGCOLOR,$SSLIFY);
			$c .= "<input type='radio' name=\"$NAME\" $CHECKED value=\"$THISVAL\"> <img src='$SRC'> $opt->{'T'} $SHOWVAL</font><br>\n";
			}
		}
	else {
		$c = "<i>Image Select could not load/find list [$LISTID]</i>";
		}
		
	return('TREE',is_global($ref->{'DATA'}).$PROMPT,$c);
	}




sub element_hidden {
	my ($ref,$toxml,$SITE) = @_;

	my $NAME = &tagname($ref->{'DATA'});
	my $VALUE = &TOXML::RENDER::smart_load($SITE, $ref->{'DATA'},$ref->{'LOADFROM'},$ref->{'VALUE'});	
	if (!defined($VALUE)) { $VALUE = ''; }	# stop perl -w from whining

	# print STDERR "HIDDEN VALUE: $ref->{'DATA'} = $VALUE\n";
	# open F, ">/tmp/debug.dump"; use Data::Dumper; print F Dumper($SITE); close F;

	return('HIDDEN','<input type="HIDDEN" name="'.$NAME.'" value="'.&ZOOVY::incode($VALUE).'">');
	}


#sub element_schedulehidden {
#	my ($ref) = @_;
#
#	my $NAME = &tagname($ref->{'DATA'});
#	my $VALUE = $ref->{'SCHEDULEVALUE'};	
#	if (!defined($VALUE)) { $VALUE = ''; }	# stop perl -w from whining
#
#	return('HIDDEN','<input type="HIDDEN" SCHEDULESET="" name="'.$NAME.'" value="'.&ZOOVY::incode($VALUE).'">');
#	}


##
##
## displays a select list
##
sub element_select {
	my ($ref,$toxml,$SITE) = @_;

	my $COL2 = '';
#	my $COL1 = '<pre>'.Dumper($ref).'</pre>';
	my $COL1 = $ref->{'PROMPT'};
	my $HELP = '';
	if (!defined($ref->{'HELP'})) { $HELP = ''; } else { $HELP = $ref->{'HELP'}; }
	
	my $LISTID = $ref->{'LIST'};
	my $listref = undef;
	if (defined($LISTID)) {
		$listref = $toxml->getList($LISTID);
		# print STDERR Dumper($listref);
		}

		# $COL2 .= Dumper(&ZTOOLKIT::value_sort(\%{$hashref}));
		# $COL2 .= Dumper($hashref);
		
	$COL2 .= "<select name=\"".&tagname($ref->{'DATA'})."\">\n";
	my $DEFAULT = '';
	my $VALUE = &TOXML::RENDER::smart_load($SITE, $ref->{'DATA'},$ref->{'LOADFROM'},$ref->{'VALUE'});
	if (defined $listref) {
		foreach my $opt (@{$listref}) {
			my $val = (defined ($_ = $opt->{'V'}))?$_:'';
			if ($VALUE eq $val) { $DEFAULT = ' SELECTED '; } else { $DEFAULT = ''; }
			$COL2 .= "<option value=\"$val\" $DEFAULT>".$opt->{'T'}."</option>";
			}
		}
	$COL2 .= '</select>';

	return('SELECT',$COL1,$COL2."<br>".$HELP);
}



##
##
## displays a list
##
#sub element_profile {
#	my ($ref,$toxml,$SITE) = @_;
#
#	my $COL2 = '';
#	$ref->{'PROMPT'} = ($ref->{'PROMPT'})?$ref->{'PROMPT'}:'Profile';
#	my $DOCID = $SITE->layout();
#
#	my $HELP = '';
#	if (!defined($ref->{'HELP'})) { $HELP = ''; } else { $HELP = $ref->{'HELP'}; }
#
#	my $profilelist = &ZOOVY::fetchprofiles($SITE->username());	
#	# print STDERR Dumper($profilelist);
#		
#	if (defined $profilelist) {
#		$ref->{'DATA'} = 'product:zoovy:profile';		## always zoovy:profile
#		my $NAME = &tagname($ref->{'DATA'});
#
#		if ($HELP eq '') { 
#			$HELP = 'HINT: If a profile doesn\'t appear here, make sure you have configured it for use with the marketplace your using.'; 
#			}
#		
#		my $OPTIONS = '';
#		my $DEFAULT = '';
#		my $VALUE = &TOXML::RENDER::smart_load($SITE, 'product:zoovy:profile','','');
#		# print STDERR "VALUE: $VALUE\n";
#		my $JS = ''; 
#		my $found = 0;
#		foreach my $profile (@{$profilelist}) {
#			if ($VALUE eq $profile) {
#				$DEFAULT = 'selected'; 
#				$found++;
#				}
#			else {
#				$DEFAULT = '';
#				}
#			$OPTIONS .= "<option value=\"$profile\" $DEFAULT>$profile</option>";
#			}
#		# $OPTIONS .= "<option ".(($VALUE eq '~')?'selected':'')." value=\"~\">Custom HTML Description</option>"; 
#		if (not $found) { 
#			$OPTIONS = "<option selected value=\"\">-- Please Select --</option>".$OPTIONS; 
#			if ($VALUE ne '') {
#				$HELP = "<font color='red'>WARNING: Detected corrupt/non-existant profile [$VALUE]</font>";
#				}
#			}
#
#		$TOXML::EDIT::META{'CHECKFORM'} .= qq~
#			// check profile x
#			if (window.document.thisFrm.elements\['$NAME'\].options\[window.document.thisFrm.elements\['$NAME'\].selectedIndex\].value == "") { 
#				alert("Please select a Listing Profile to Proceed");
#				return(false); 
#				}
#			~;
#	
#		$COL2 = "<table cellspacing=0 cellpadding=2 border=0 width='100%' bgcolor='BBBBDD'><tr><td>";
#		$COL2 .= "$ref->{'PROMPT'}: <select onChange=\"selectProfile(this);\" name=\"$NAME\">\n";
#		$COL2 .= $OPTIONS;
#		$COL2 .= '</select>';
#
#		$COL2 .= qq~<input class='button1' type='button' value=' Enter Data ' onClick="clickBtn('PROFILE');">~;
#		$COL2 .= "</td></tr><tr><td>$HELP</td></tr>";
##		if ($VALUE eq '~') {
##			my $ref = {
##				'attrib'=>{
##					'MAX'=>50000,
##					'DATA'=>'product:zoovy:html',
##					'PROMPT'=>'HTML Description',
##					'COLS'=>100, 
##					'ROWS'=>10,
##					'OPTIONS'=>'HTML',
##					},
##				};
##			(undef,my $buf) = &TOXML::EDIT::element_textarea($ref);
##			$COL2 .= "<tr><td valign=top>$buf</td></tr>";
##			}
#	
#		$COL2 .= "</table>";
#		} 
#	else {
#		# Corrupt Div?? no LIST referenced.
#		}
#
#	return('PROFILE',$COL2,'','','');
#}
#

###################################################################################################
## 
##
sub display_byprompt {
}



############################################################
sub element_textbox {
	my ($ref,$toxml,$SITE) = @_;
	my $c = '';

	# things we need to check for:
	# MANDATORY="Y"
	# SIZE
	# MAXLENGTH
	# FORMAT
	# HELP
	# MIN

	# backward compatibility for INVENTORY
	if (defined $ref->{'INVENTORY'}) { return(&element_inventory($ref,$toxml,$SITE)); }

	my $HELP = ''; my $TYPE = ''; my $SIZE = '';
	my $NAME = &tagname($ref->{'DATA'});
	my $MAXLENGTH = $ref->{'MAXLENGTH'};
	if (!defined($ref->{'HELP'})) { $HELP = ''; } else { $HELP = $ref->{'HELP'}; }
	if (defined($ref->{'HELPER'})) { $HELP = $ref->{'HELPER'}; }

	my $VALUE = &TOXML::RENDER::smart_load($SITE, $ref->{'DATA'},$ref->{'LOADFROM'},$ref->{'VALUE'});
	if (not defined($VALUE)) { $VALUE = ''; }
	if (not defined($MAXLENGTH)) { $MAXLENGTH = ''; } else { 
		$VALUE = substr($VALUE,0,$MAXLENGTH);		# truncate to maxlength characters
		$MAXLENGTH = " maxlength=\"$MAXLENGTH\" "; 
		}

	my $PROMPT = $ref->{'PROMPT'};
	my $COLS = $ref->{'COLS'};
	if (not defined($COLS)) { $COLS = 0; }

	# internally differentiate between long and short textboxes 
	if (int($COLS) > 30) { $TYPE = 'LONGTEXT'; } else { $TYPE = 'TEXTBOX'; }
	if (int($COLS)==0 && length($VALUE)>0) { $COLS = length($VALUE)+10; }
	if (int($COLS)==0) { $COLS = 60; }
	if (int($COLS)==0) { $SIZE=''; } else { $SIZE = " size=\"$COLS\" "; }

	if (defined($ref->{'MANDATORY'}) && uc($ref->{'MANDATORY'}) eq 'Y') {
      $TOXML::EDIT::META{'CHECKFORM'} .= "\nif (window.document.thisFrm.elements['$NAME'].value == '') { \n";
      $TOXML::EDIT::META{'CHECKFORM'} .= "   alert (\"Please fill in the $PROMPT field prior to proceeding.\");\n ";
      $TOXML::EDIT::META{'CHECKFORM'} .= "   return false; }\n";
		}




	if (defined($ref->{'VALIDATION'})) {
		if (uc($ref->{'VALIDATION'}) eq 'EMAIL') {
			## Email validation
	      $TOXML::EDIT::META{'CHECKFORM'} .= "\nif (window.document.thisFrm.elements['$NAME'].value != validated('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz01234567890-@.',window.document.thisFrm.elements['$NAME'].value)) { \n";
			$TOXML::EDIT::META{'CHECKFORM'} .= "   alert (\"The $PROMPT field must contain a valid email address (no HTML).\");\n ";
			$TOXML::EDIT::META{'CHECKFORM'} .= "   return false; }\n";
			}
		elsif (uc($ref->{'VALIDATION'}) eq 'WEIGHT') {
	      $TOXML::EDIT::META{'CHECKFORM'} .= "\nif (window.document.thisFrm.elements['$NAME'].value != validated('0123456789.#',window.document.thisFrm.elements['$NAME'].value)) { \n";
			$TOXML::EDIT::META{'CHECKFORM'} .= "   alert (\"The $PROMPT field must contain a valid email address (no HTML).\");\n ";
			$TOXML::EDIT::META{'CHECKFORM'} .= "   return false; }\n";			
			}
		}

	## trying to add session id warning
#	$TOXML::EDIT::META{'CHECKFORM'} .= "\nif (window.document.thisFrm.elements['$NAME'].value.indexOf(\"\/c\=\") != -1) { \n";
#	$TOXML::EDIT::META{'CHECKFORM'} .= "   alert (\"The $PROMPT may can a session id. Please remove.\");\n ";
#	$TOXML::EDIT::META{'CHECKFORM'} .= "   return true; }\n";
					
	# if ($MAXLENGTH ne '') { $VALUE = substr($VALUE,0,$MAXLENGTH); }
	$VALUE = &ZOOVY::incode($VALUE);

	return('HTML',
		is_global($ref->{'DATA'}).$PROMPT,
		qq~<input type='textbox' name='$NAME' value="$VALUE" $SIZE $MAXLENGTH><br>$HELP~
		);
	}


##
## 2 column format
##
sub fmt2col {
	my ($col1,$col2) = @_;
	}



############################################################
## element_checkbox
##
## purpose: takes a reference to a checkbox element returns a CHECKBOX type, plus COL1 and COL2
##
############################################################
sub element_checkbox
{
	my ($ref, $toxml, $SITE) = @_;

	my $form = $ref->{'_FORM'};
	if ($form eq '') { $form = 'thisFrm'; }

	my $COL2 = '';
	my $ID = $ref->{'ID'};
	my $NAME = $ref->{'DATA'};	
	$NAME = &tagname($NAME);

	my $PROMPT = $ref->{'PROMPT'};	
	my $CHECKED = '';

	my $OFF = $ref->{'OFF'};
	if (not defined($OFF)) { $OFF = ''; }
	$OFF =~ s/\'//g;			# cannot have single quotes

	my $ON = $ref->{'ON'};
	if (not defined($ON)) { $ON = 'on'; }
	$ON =~ s/\'//g; 			# cannot have single quotes

	if (defined($ref->{'CHECKED'})) {
		# always force value one way or another.	
		# each time DIV is loaded.		
		if (uc($ref->{'CHECKED'}) eq 'Y') {
			$COL2 .= "<input id=\"hcb-$ID\" type='hidden' name='$NAME' value='$ON'>";
			$CHECKED = ' CHECKED '; 
			}
		else {
			$COL2 .= "<input id=\"hcb-$ID\" type='hidden' name='$NAME' value='$OFF'>";
			$CHECKED = ''; 
			}
		} 
	else {
		# don't reset the value, try to load it.

		my $VALUE = &TOXML::RENDER::smart_load($SITE, $ref->{'DATA'},$ref->{'LOADFROM'},$ref->{'VALUE'});	
		if (defined($VALUE) && ($VALUE eq $ON)) {
			$CHECKED = ' CHECKED ';
			$COL2 = "<input id=\"hcb-$ID\" type='HIDDEN' name='$NAME' value='$ON'>\n";
			} 
		else {
			$COL2 = "<input id=\"hcb-$ID\" type='HIDDEN' name='$NAME' value='$OFF'>\n";
			$CHECKED = '';
			}
		}

	#if (defined($ref->{'MANDATORY'}) && (uc($ref->{'MANDATORY'}) eq 'Y')) {
   #   $TOXML::EDIT::META{'CHECKFORM'} .= "\nif (jQuery(\"#$NAME\").is(\":checked\")) { \n";
   #   $TOXML::EDIT::META{'CHECKFORM'} .= "   alert (\"$PROMPT must be checked prior to proceeding.\");\n ";
   #   $TOXML::EDIT::META{'CHECKFORM'} .= "   return false; }\n";
	#	}

	$COL2 .= is_global($ref->{'DATA'}).qq~
	<input type='CHECKBOX' $CHECKED onClick=\"jQuery('#hcb-$ID').val( 
		(jQuery(this).is(':checked'))?'$ON':'$OFF' 
		);
		\">
	$PROMPT
	~;
	return('CHECKBOX',$PROMPT,$COL2,$ref->{'HELP'});
}


############################################################
## 
############################################################
sub element_password {
	my ($ref, $toxml, $SITE) = @_;

	# things we need to check for:

	my $NAME = &tagname($ref->{'DATA'});
	my $MAX = $ref->{'MAX'};
	my $VALUE = &TOXML::RENDER::smart_load($SITE, $ref->{'DATA'},$ref->{'LOADFROM'},$ref->{'VALUE'});
	if (not defined($VALUE)) { $VALUE = ''; }
	my $PROMPT = $ref->{'PROMPT'};
	my $SIZE = (defined($ref->{'SIZE'}))?(' size="'.$ref->{'SIZE'}.'" '):'';
		
	$VALUE=&ZOOVY::incode($VALUE);
	return('PASSWORD',is_global($ref->{'DATA'}).$PROMPT,"<input type='password' name='$NAME' value='$VALUE' $SIZE>");
	}




##################################################################
##
## element_textarea
## purpose: create a textarea
##
##################################################################
sub element_textarea {
	my ($ref, $toxml, $SITE) = @_;

	# things we need to check for:
	# OPTIONS=MANDATORY
	# SIZE
	# MAX
	# FORMAT
	# HELP
	# MIN

	my $MAX = $ref->{'MAX'};

	if (not defined $ref->{'VALUE'}) {
		## hmm.. is it DEFAULT or VALUE?
		$ref->{'VALUE'} = $ref->{'DEFAULT'};
		}

	my $VALUE = &TOXML::RENDER::smart_load($SITE, $ref->{'DATA'},$ref->{'LOADFROM'},$ref->{'VALUE'});
	if (not defined $VALUE) { $VALUE = ''; }
	
	#if ($] > 5.008) {
	#	if (not utf8::is_utf8($VALUE)) {
	#		Encode::from_to($VALUE, "iso-8859-1", "utf8"); #1
	#		}
	#	}

	my $ID = $ref->{'ID'};
	my $NAME = &tagname($ref->{'DATA'});
	my $PROMPT = $ref->{'PROMPT'};
	my $COLS = $ref->{'COLS'};	if (not defined($COLS)) { $COLS = 80; }
	my $ROWS = $ref->{'ROWS'}; if (not defined($ROWS)) { $ROWS = 5; }

	$VALUE=&ZOOVY::incode($VALUE);
	if (!defined($ref->{'OPTIONS'})) { $ref->{'OPTIONS'} = ''; }

	my $resetdefault = '';
	if (defined $ref->{'DEFAULT'}) {
		my $escDefault = $ref->{'DEFAULT'};
		$escDefault =~ s/\'/\\\'/gs;
		$escDefault =~ s/[\r]+//gs;
		$escDefault =~ s/\n/\\n/gs;
		$escDefault = &ZOOVY::incode($escDefault);
		
		$resetdefault = qq~<input type="button" onClick="document.getElementById('$ID').value='$escDefault';" value=" Reset to Default ">~;
		}

	my $wikihelp = '';
	if ((defined $ref->{'WIKI'}) && ($ref->{'WIKI'}==0)) { 
		$wikihelp = '<br><i>This field has Wiki Commands turned off.</i><br>'; 
		}
	else {
		my $wiki_id = $ID."!wikihelp";
		$wikihelp = q~
<br><i>This field supports WikiText Formatting Commands [<a href="#" onClick="document.getElementById('~.$wiki_id.qq~').style.display='block'; return false;">Help</a>]</i><br>
<div id="$wiki_id" style="display: none;">
<br>
<b>WikiText Formatting Commands:</b><br>
Using wiki commands you can easily format your text without needing to know any HTML. 
Wiki Syntax takes just minutes to learn - 
<br>just remember to place each command on it's own line. Basic commands are:
<br>
= title1 (section header) =<br>
== title2 (sub section header) ==<br>
to start a new paragraph (column break) simply insert two blank lines.<br>
to create a bullet list, simply start place each bullet on its own line starting with an asterisk (*)<br>
<pre>
Example:
== product features ==
* feature1
* feature2 
</pre>
<p>
For more info, go to the <a target=_new href="http://webdoc.zoovy.com/INFO/index.php?POPUP=1&GOTO=detail/wikitext.php">WebDocs</a>
</div>
		~;
		}


	if (not defined $ref->{'HELPER'}) { $ref->{'HELPER'} = ''; }
	my $help = "<div class=\"hint\">$ref->{'HELPER'}</div>";

	my $htmlbutton = '';
	my $ID = (defined $ref->{'ID'})?$ref->{'ID'}:'';
	if ($ref->{'TYPE'} eq 'HTML') {
		$htmlbutton = qq~<input type='button' value=' HTML Edit ' onClick='openWindow(\"/biz/vstore/builder/htmlpop.cgi?frm=thisFrm&id=$ID\");'><br>~;
		}
#	elsif ($ref->{'OPTIONS'} =~ /HTML/) {
#		my $URIPROD = CGI->escape($SITE->pid());
#		my $NS = $SITE->profile();		
#		if (not defined $NS) { $NS = $SITE->{'zoovy:profile'}; }
#		$htmlbutton = qq~
#<table width='100%' bgcolor='777777' cellspacing='0' cellpadding='1' border='0' valign='middle'>
#<tr><Td><b>&nbsp; <font color='yellow'>HTML Tools:</font></b></td>
#<!--
#<td><input type='button' value=' Design ' onClick='openWindow("htmlwiz/index.pl?SKU=$URIPROD&PARENT=$NAME");'></td>
#//-->
#<td><input type='button' value=' Preview ' onClick='openWindow("htmlwiz/previewit.cgi?PARENT=$NAME");'></td></tr>
#</table>
#~;
#		}

	my $ROWSPLUS = $ROWS+10;
	return('TEXTAREA',is_global($ref->{'DATA'})."<table><tr><td><b>$PROMPT:</b><br><textarea onFocus=\"this.rows=$ROWSPLUS;\" rows='$ROWS' cols='$COLS' id='$ID' name='$NAME'>$VALUE</textarea>$help$htmlbutton $resetdefault $wikihelp</td></tr></table>");
	}


##################################################################
##
## element_textlist
## purpose: create a textarea
##
##################################################################
sub element_textlist {
	my ($ref, $toxml, $SITE) = @_;

	# things we need to check for:
	# OPTIONS=MANDATORY
	# SIZE
	# MAX
	# FORMAT
	# HELP
	# MIN

	my $MAX = $ref->{'MAX'};

	my $VALUE = &TOXML::RENDER::smart_load($SITE, $ref->{'DATA'},$ref->{'LOADFROM'},$ref->{'VALUE'});
	if (not defined $VALUE) { $VALUE = ''; }

	my $NAME = &tagname($ref->{'DATA'});
	my $PROMPT = $ref->{'PROMPT'};
	my $COLS = $ref->{'COLS'};	if (not defined($COLS)) { $COLS = 80; }
	my $ROWS = $ref->{'ROWS'}; if (not defined($ROWS)) { $ROWS = 5; }

	$VALUE=&ZOOVY::incode($VALUE);
	if (!defined($ref->{'OPTIONS'})) { $ref->{'OPTIONS'} = ''; }

	my $htmlbutton = '';
	return('TEXTLIST',is_global($ref->{'DATA'})."<table><tr><td><b>$PROMPT:</b> <i>Enter one item per line</i><br><textarea rows='$ROWS' cols='$COLS' name='$NAME'>$VALUE</textarea></td></tr></table>");
}


##
##
##



##################################################################
##
## element_image
## purpose: create an image dialog
##
##################################################################
sub element_image {
	my ($iniref, $toxml, $SITE) = @_;
	my $c = '';

	##
	## NOTE: this element_image is also called from element_banner
	##

	# things we need to check for:
	# FORMAT

	if ($iniref->{'READONLY'}) { return('NULL'); }		# NOTE: used for backward compatibility in legacy HTML wizards
																	# for old SUB="xxx_URL" and SUB="xxx_RAWURL" 

	my $PROMPT = $iniref->{'PROMPT'};
	if (not defined $PROMPT) { $PROMPT = ''; }
	my $NAME = &tagname($iniref->{'DATA'});
	my $VALUE = &TOXML::RENDER::smart_load($SITE, $iniref->{'DATA'},$iniref->{'LOADFROM'},$iniref->{'VALUE'});
	if (not defined $VALUE) { $VALUE = $iniref->{'DEFAULT'}; }

	my $SRC = '';
	my $SSLIFY;
	if ((not defined($VALUE)) || $VALUE eq '')
			{ 
			$SRC = &ZOOVY::mediahost_imageurl($SITE->username(),"//www.zoovy.com/images/image_not_selected.gif",75,75,$TOXML::EDIT::BGCOLOR,$SSLIFY);
			} else {
			$SRC = &ZOOVY::mediahost_imageurl($SITE->username(),$VALUE,75,75,$TOXML::EDIT::BGCOLOR,$SSLIFY);
			}

	my $ID = $iniref->{'ID'};
	my %serial = ();
#	$serial{'ATTRIB'} = $NAME;
#	$serial{'SRC'} = $SRC;
#	$serial{'PROMPT'} = $PROMPT;
#	$serial{'VALUE'} = $VALUE;
#	$serial{'ID'} = $ID;

	my $passthis = &ZTOOLKIT::fast_serialize(\%serial,1);

	my $t = time();
	my $COL3 = "<input type=\"HIDDEN\" id=\"$NAME\" name=\"$NAME\" value=\"".&ZOOVY::incode($VALUE)."\">\n";
	# $COL3 .= "<input type=\"BUTTON\" style='width: 100px;' value=\"Legacy Image Library\" onClick=\"javascript:openWindow('/biz/product/channel/image.pl?SERIAL=$passthis&$t');\"><br>";
	# $COL3 .= "<input type=\"BUTTON\" style='width: 100px;' value=\"Upload Image\" onClick=\"javascript:openWindow('/biz/product/channel/image.pl?ACTION=UPLOAD&SERIAL=$passthis&$t');\"><br>";

	$COL3 .= qq~
	<button type="submit" class="button"
			style="width: 100px;" 
			onClick="mediaLibrary(
				jQuery(adminApp.u.jqSelector('#','${NAME}img')),
				jQuery(adminApp.u.jqSelector('#','${NAME}')),
				'Choose Logo'); return false;">Media Library</button>
	<button type="submit" class="button"
			style="width: 100px;" 
			onClick="
				jQuery(adminApp.u.jqSelector('#','${NAME}img')).attr('src','/images/blank.gif');
				jQuery(adminApp.u.jqSelector('#','${NAME}')).val('');
				">Clear Image</button>
			<br>~;


	my $COL2 .= "<img id=\"${NAME}img\" name=\"${NAME}img\" src=\"$SRC\" border=\"0\" height=\"75\" width=\"75\">";
#	$c = '<pre>'.Dumper($iniref).'</pre>';

	return('IMAGE',is_global($iniref->{'DATA'}).$PROMPT,$COL2,$COL3);
}



sub stripslashes {
	my ($text, $count) = @_;	
	while ($count-->0)
		{
		$text = substr($text,index($text,'/')+1);
		}	
	return($text);
	}



1;
	
