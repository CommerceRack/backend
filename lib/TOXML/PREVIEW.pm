package TOXML::PREVIEW;
no warnings 'once'; # Keep perl -w from bitching about variables only used once

use lib '/backend/lib';
require TOXML::EDIT;
use strict;

my $DEBUG = 0;

# This is a hash of references to subroutines, so we can make one simple call to
# generically reference a function for any of the element types byt the syntax
# $FLOW::flow_blah{FOO}->(params for foo);




# These are all of the flow previews
%TOXML::PREVIEW::preview_element = (
	# 'EDITOR_ACTION'=>\&TOXML::PREVIEW::EDITOR_ACTION,
	'SELECT' => \&TOXML::PREVIEW::PREVIEW_SELECT,
	'BANNER'	=> \&TOXML::PREVIEW::PREVIEW_BANNER,
	'CHECKBOX' => \&TOXML::PREVIEW::PREVIEW_CHECKBOX,
	'TEXT' => \&TOXML::PREVIEW::PREVIEW_TEXT,
	'HTML' => \&TOXML::PREVIEW::PREVIEW_TEXT,
	'TEXTBOX' => \&TOXML::PREVIEW::PREVIEW_TEXTBOX,
	'FINDER' => \&TOXML::PREVIEW::PREVIEW_FINDER,
	'IMAGE' => \&TOXML::PREVIEW::PREVIEW_IMAGE,
	'PRODLIST' => \&TOXML::PREVIEW::PREVIEW_PRODLIST,
	'CART' => \&TOXML::PREVIEW::PREVIEW_CART,
	'SLIDE' => \&TOXML::PREVIEW::PREVIEW_SLIDE,
	'DYNIMAGE' => \&TOXML::PREVIEW::PREVIEW_DYNIMAGE,
	'SEARCHBOX' => \&TOXML::PREVIEW::PREVIEW_SEARCHBOX,
	'QTYPRICE'	=> \&TOXML::PREVIEW::PREVIEW_QTYPRICE,
	'TRISTATE'	=> \&TOXML::PREVIEW::PREVIEW_TRISTATE,
	'SELECTED'	=> \&TOXML::PREVIEW::PREVIEW_SELECTED,
	'TEXTLIST'	=> \&TOXML::PREVIEW::PREVIEW_TEXTLIST,
	);
# if (defined %FLOW::preview_element) {} #Keeps perl -w from bitching


sub std_box {	
	my ($SITE,$iniref,$guts) = @_;

	my $el = $iniref->{'ID'};
	my $type = $iniref->{'TYPE'};
	my $name = $iniref->{'PROMPT'};
	my $width = $iniref->{'WIDTH'};
	if (!defined($width)) { $width = '100%'; }

	my $TYPE = $iniref->{'TYPE'};
	if (not defined $guts) {		
		($guts) = $TOXML::RENDER::render_element{$TYPE}->($iniref);
		}

#	my ($th,$sz) = $SITE::CONFIG->{'%THEME'};

	my $js = '';
	my $extra = '';
	my $edit = qq~[&nbsp;<a href="#" onClick="loadElement('$type','$el'); return false;">EDIT</a>&nbsp;]~;
	if (defined($iniref)) {

		# u
		# use Data::Dumper; print STDERR Dumper($iniref,$SITE);
		if ($iniref->{'TYPE'} eq 'SEARCHBOX') {}		#note: search boxes don't have a DATA=
		elsif ($iniref->{'DATA'} eq '') { $edit = ''; }
		my $ATTRIB = '';

		if ($iniref->{'TYPE'} ne 'PRODLIST') {
			}
		elsif ((defined $iniref->{'DISABLEPRODUCTS'}) && ($iniref->{'DISABLEPRODUCTS'})) {
			## not sure wtf this is
			}
		elsif ($iniref->{'SRC'} =~ /^SMART\:/) {
			## not editable.
			}
		elsif ($iniref->{'SRC'} ne '') {
			## SRC SET
			my ($PATH,$ATTRIB) = split(/\:/,$iniref->{'SRC'},2);
			if ($SITE->fs() eq 'C') { $TYPE = 'NAVCAT'; }		
			elsif ($SITE->fs() eq 'P') { $TYPE = 'PRODUCT'; }
			elsif ($SITE->fs() eq 'H') { 
				if (uc($PATH) eq 'PAGE') { 
					$TYPE = 'PAGE'; $PATH = '.';
					}
				else {
					$TYPE = 'NAVCAT'; $PATH = '.'; 
					}
				}
			# elsif ($SITE->format() eq 'NEWSLETTER') { $TYPE = 'PAGE'; $PATH = $SITE->layout(); }
			elsif ($SITE->format() eq 'NEWSLETTER') { $TYPE = 'PAGE'; $PATH = $SITE->pageid(); }
			else { $TYPE = 'ERROR'; $ATTRIB = '#SRC_INVALID='.$iniref->{'SRC'}; }

			$extra = qq~[&nbsp;<a href="#" data-src="$iniref->{'SRC'}" data-elementid="$el" onClick="adminApp.ext.admin.a.showFinderInModal('$TYPE','$PATH','$ATTRIB'); return false;">PRODUCTS</a>&nbsp;]~;
			}
		else {
			## SRC NOT SET - LOAD DEFAULTS
			# (($iniref->{'SRC'} =~ /^NAVCAT\:/i) || ($iniref->{'SRC'} =~ /^PAGE\:/i)) {
			my $DATA = &ZOOVY::dcode(&TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'}));
			my $params = &TOXML::RENDER::parse_prodlist_data($DATA,$iniref,$SITE);

			my ($TYPE,$PATH,$ATTRIB) = ();
			if ($SITE->fs() eq 'P') {
				($TYPE,$PATH,$ATTRIB) = ('PRODUCT',$SITE->pid(),'zoovy:related_products');
				}
			elsif ($SITE->fs() eq 'C') {
				($TYPE,$PATH,$ATTRIB) = ('NAVCAT',$SITE->pageid(),'products');
				}
			elsif ($SITE->fs() eq 'H') {
				($TYPE,$PATH) = ('NAVCAT',".",'products');
				}
			elsif ($SITE->fs() eq 'T') {
				## This used to be a NAVCAT named *cart (but we phased out the *cart notation)
				($TYPE,$PATH,$ATTRIB) = ('NULL');
				}
			else {
				($TYPE,$PATH) = ('ERROR',"#SRC_NOT_SET_BY_LAYOUT");
				}

			print STDERR "inisrc:$iniref->{'SRC'} data:$DATA params:$params->{'SRC'}\n";
			if ($TYPE ne 'NULL') {
				$extra = qq~[&nbsp;<a href="#" data-src="$iniref->{'SRC'}" data-elementid="$el" onClick="adminApp.ext.admin.a.showFinderInModal('$TYPE','$PATH','$ATTRIB'); return false;">PRODUCTS</a>&nbsp;]~;}
				}

		if (($iniref->{'TYPE'} eq 'PRODCATS') && ($iniref->{'TYPE'} eq 'PRODGALLERY')) {
			## Prodcats is not editable.
			$edit = '';
			}
		}


	#use Data::Dumper; my $debug = Dumper($th);
	my $editorDiv = "";
	#if (($iniref->{'EDITOR'} eq 'INLINE') || ($iniref->{'_V'}==3)) {
	#	## if editorDiv-ID is set then the content will be loaded into that <div> instead of other places.
	#	## NOTE: if we ever change this be sure to also change the EDITOR_ACTION function (since it relies on the same ajax stuff)
		$editorDiv = "editorDiv-".$iniref->{'ID'};
	#	}
	# $guts = 'Click the Edit Button to show the contents';
	
	return &ZTOOLKIT::untab(qq~
		<img src="https://www.zoovy.com/images/blank.gif" width="1" height="1"><br>
		<div id="$editorDiv">
		<table class="zoovytable" width="$width" cellspacing=0 border="0">
			<tr>
				<td class="zoovytableheader" align="left" valign="middle">$name:</td>
				<td class="zoovytableheader" align="right" valign="middle">$extra $edit</td>
			</tr>
			<tr>
				<td colspan="2">
					<table width="100%" cellpadding="0" cellspacing="5" border="0">
						<tr>
							<td class="zbody">
							<div class="ztxt">
							$guts
							</div>
							</td>
						</tr>
					</table>
				</td>
			</tr>
		</table>
		</div>
	~);
	
}


##
## not sure what this did, but probably isn't necessary anymore
##
sub pad {
	my ($txt) = @_;

	return($txt);

#	my $th = $SITE::CONFIG->{'%THEME'};
#
#	my $c  = "<table bgcolor=\"$th->{'content_background_color'}\" border=\"0\" cellpadding=\"3\" cellspacing=\"0\" width=\"100%\">";
#	$c .= "<tr><td style=\"background-color: #$th->{'content_background_color'};\" bgcolor=\"#$th->{'content_background_color'}\">";
#	$c .= "<font color=\"$th->{'content_text_color'}\" face=\"$th->{'content_font_face'}\"  size=\"$th->{'content_font_size'}\">";
#	$c .= "$txt</font></td></tr></table>\n";
#	return($c);
}


##
## EDITOR_ACTION
##		FUNC="EMAIL_TEST", EMAIL="Msg name"
##
#sub EDITOR_ACTION {
#	my ($iniref,$toxml,$SITE) = @_;
#
#	$iniref->{'_PREVIEW'}++;
#	my $out = TOXML::EDIT::EDITOR_ACTION($iniref,$toxml,$SITE);
#	
#	return($out);
#	}




###########################################################################
# PREVIEW ELEMENT
# Each of these function takes in a reference to an element's INI hash, and returns the
# HTML code to display the element in preview mode (a method which renders somewhat like
# the eventual output mode, with a limited set of editing functionality)

sub PREVIEW_TEXT {
	my ($iniref,$toxml,$SITE) = @_; # ini is a reference to a hash of the element's contents

	my $BUF = $TOXML::RENDER::render_element{'TEXTBOX'}->($iniref,$toxml,$SITE);
	if (not defined $BUF) {
		$BUF .= $iniref->{'DEFAULT'};
		}
	if ((not defined $BUF) || ($BUF eq '')) {
		$BUF = "<font size='2'><i>Currently Empty</i></font>";
		}

	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($BUF));

}


sub PREVIEW_HTML {
	my ($iniref,$toxml,$SITE) = @_; # ini is a reference to a hash of the element's contents

	my $BUF = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'});
	if (not defined $BUF) {
		$BUF .= $iniref->{'DEFAULT'};
		}
	if ((not defined $BUF) || ($BUF eq '')) {
		$BUF = "<font size='2'><i>Currently Empty</i></font>";
		}

	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($BUF));
	}


sub PREVIEW_IMAGE {
	my ($iniref,$toxml,$SITE) = @_; # ini is a reference to a hash of the element's contents

	my $BUF = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'});
	$iniref->{'PREVIEW'} = 1;
	my $guts = $TOXML::RENDER::render_element{'IMAGE'}->($iniref,$toxml,$SITE);

	if (defined($iniref->{'RAW'}) && $iniref->{'RAW'}) {
		return $guts;
		}
#	my $guts;
#	if (defined $BUF) {
#		if ($BUF =~ /^http/i) { 
#			# Legacy format, where image URL is hardcoded!
#			$guts = "<img width='$iniref->{'WIDTH'}' height='$iniref->{'HEIGHT'}' src='$BUF'>";
#		} elsif ($BUF eq "") {
#			# No image is found, use a blank gif
#			$guts = "<img width='$iniref->{'WIDTH'}' height='$iniref->{'HEIGHT'}' src='https://www.zoovy.com/images/blank.gif'>";
#		} else {
#			$guts = "<img width='$iniref->{'WIDTH'}' height='$iniref->{'HEIGHT'}' src='https://static.zoovy.com/img/$SITE::merchant_id/H$iniref->{'HEIGHT'}-W$iniref->{'WIDTH'}/$BUF'>";
#		}
#	}
#	else {
#		# No image was found.
#		if (defined($iniref->{'DEFAULT'}))
#			{
#			# if we have a default use that.
#			$guts = "<img width='$iniref->{'WIDTH'}' height='$iniref->{'HEIGHT'}' src='$iniref->{'DEFAULT'}'>";
#			} else {
#			# otherwise slaughter the Zoovy logo
#			$guts = "<img width='$iniref->{'WIDTH'}' height='$iniref->{'HEIGHT'}' src='https://static.zoovy.com/img/$SITE::merchant_id/H$iniref->{'HEIGHT'}-W$iniref->{'WIDTH'}-Z/zoovy/'>";
#			}
#	}
	my $width  = defined($iniref->{'WIDTH'})  ? $iniref->{'WIDTH'}  : 0;
	$width =~ s/\D//gs; 
	if ($width eq '') { $width = 0; }
	
	my $height = defined($iniref->{'HEIGHT'}) ? $iniref->{'HEIGHT'} : 0;
	$height =~ s/\D//gs;
	if ($height eq '') { $height = 0; }
	
	my $size = 'original size';
	if    ($width && $height) { $size = $width.'x'.$height; }
	elsif ($width)            { $size = $width.' wide';     }
	elsif ($height)           { $size = $height.' high';    }
	
	return &TOXML::PREVIEW::std_box($SITE,$iniref,$guts);

}

sub PREVIEW_SLIDE {
	my ($iniref,$toxml,$SITE) = @_;
	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{'SLIDE'}->($iniref,$toxml,$SITE)));
	}

sub PREVIEW_SEARCHBOX {
	my ($iniref,$toxml,$SITE) = @_;
	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{'SEARCHBOX'}->($iniref,$toxml,$SITE)));
	}

sub PREVIEW_FINDER {
	my ($iniref,$toxml,$SITE) = @_;
	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{'FINDER'}->($iniref,$toxml,$SITE)));
	}


sub PREVIEW_DYNIMAGE {
	my ($iniref,$toxml,$SITE) = @_; # ini is a reference to a hash of the element's contents
	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{'DYNIMAGE'}->($iniref,$toxml,$SITE)));
	}

sub PREVIEW_TEXTBOX {
	my ($iniref,$toxml,$SITE) = @_; # ini is a reference to a hash of the element's contents

	my $BUF = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'});
#	print STDERR "BUF($SITE->{'+prt'}): $BUF\n";
	if (not defined $BUF) {
		$BUF .= $iniref->{'DEFAULT'};
		}

	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{'TEXTBOX'}->($iniref,$toxml,$SITE)));
	}


sub PREVIEW_PRODLIST {
	my ($iniref,$toxml,$SITE) = @_;
	$iniref->{'PREVIEW'} = 1;

	my $uses = '';
	my $BUF = &TOXML::RENDER::smart_load($SITE,$iniref->{'DATA'});
	my $DATA = &ZOOVY::dcode($BUF);
	if ($DATA eq '') { $DATA = &ZOOVY::dcode($iniref->{'DEFAULT'}); }
	require TOXML::RENDER;
	my $params = &TOXML::RENDER::parse_prodlist_data($DATA,$iniref,$SITE);
	if ($params->{'SRC'} eq '') {
		$uses = '[ Displays Category Products ]';
		}
	elsif ($params->{'SRC'} =~ /PRODUCT:(.*?)$/) {
		$uses = '[ Related Products ]'; 
		}
	elsif ($params->{'SRC'} =~ /LIST\:(.*?)$/) {
		$uses = "[ List: $1 ]";
		}
	elsif ($params->{'SRC'} =~ /PAGE\:(.*?)$/i) {
		$uses = "[ Page: $1 ]";
		}
	elsif ($params->{'SRC'} =~ /SMART:(.*?)$/) {
		my $type = $1;
		if ($type eq 'BYCATEGORY') {
			$uses = '[ Smart: dynamic from similiar categories ]';
			}
		elsif ($type eq 'BYPRODUCT') {
			$uses = '[ Smart: uses related products ]';
			}
		elsif ($type eq 'VISITED') {
			$uses = '[ Smart: viewed products ]';
			}
		else {
			$uses = '[ Unknown SMART Source: '.$params->{'SRC'}.' ]';
			}
		}
	
	if ($uses eq '') {
		$uses = '[Unknown source: '.$params->{'SRC'}.' ]';
		}

	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{PRODLIST}->($iniref,$toxml,$SITE)));
	}


sub PREVIEW_PRODGALLERY {
	my ($iniref,$toxml,$SITE) = @_;
	$iniref->{'PREVIEW'} = 1;
	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{PRODGALLERY}->($iniref,$toxml,$SITE)));
	}

sub PREVIEW_GALLERY {
	my ($iniref,$toxml,$SITE) = @_;
	$iniref->{'PREVIEW'} = 1;
	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{GALLERY}->($iniref,$toxml,$SITE)));
	}

sub PREVIEW_CARTPRODCATS {
	my ($iniref,$toxml,$SITE) = @_;
	$iniref->{'PREVIEW'} = 1;
	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{CARTPRODCATS}->($iniref,$toxml,$SITE)));
	}

sub PREVIEW_PRODCATS {
	my ($iniref,$toxml,$SITE) = @_;
	$iniref->{'PREVIEW'} = 1;
	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{PRODCATS}->($iniref,$toxml,$SITE)));
	}

sub PREVIEW_CHECKBOX {
	my ($iniref,$toxml,$SITE) = @_;
	$iniref->{'PREVIEW'} = 1;
	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{'CHECKBOX'}->($iniref,$toxml,$SITE)));
	}

sub PREVIEW_SELECT {
	my ($iniref,$toxml,$SITE) = @_;
	$iniref->{'PREVIEW'} = 1;
	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{'SELECT'}->($iniref,$toxml,$SITE)));
	}

sub PREVIEW_BANNER {
	my ($iniref,$toxml,$SITE) = @_;
	$iniref->{'PREVIEW'} = 1;
	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{'BANNER'}->($iniref,$toxml,$SITE)));
	}

sub PREVIEW_MAILFORM {
	my ($iniref,$toxml,$SITE) = @_;
	$iniref->{'PREVIEW'} = 1;
	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{MAILFORM}->($iniref,$toxml,$SITE)));
	}


sub PREVIEW_READONLY {
	my ($iniref,$toxml,$SITE) = @_;
 	return($TOXML::RENDER::render_element{'READONLY'}->($iniref,$toxml,$SITE));
	}

sub PREVIEW_TRISTATE {
	my ($iniref,$toxml,$SITE) = @_;
 	return($TOXML::RENDER::render_element{'TRISTATE'}->($iniref,$toxml,$SITE));
	}

sub PREVIEW_SELECTED {
	my ($iniref,$toxml,$SITE) = @_;
 	return($TOXML::RENDER::render_element{'SELECTED'}->($iniref,$toxml,$SITE));
	}

sub PREVIEW_TEXTLIST {
	my ($iniref,$toxml,$SITE) = @_;
 	return($TOXML::RENDER::render_element{'TEXTLIST'}->($iniref,$toxml,$SITE));
	}

# shopping cart globals
sub PREVIEW_CART {
	my ($iniref, $toxml, $SITE) = @_;
 	return($TOXML::RENDER::render_element{'CART'}->($iniref,$toxml,$SITE));
	}

sub PREVIEW_ADDTOCART {
	my ($iniref) = @_;
	return '';
	}

sub PREVIEW_GALLERYSELECT {
	my ($iniref,$toxml,$SITE) = @_;
	$iniref->{'PREVIEW'} = 1;
 	return($TOXML::RENDER::render_element{'GALLERYSELECT'}->($iniref,$toxml,$SITE));
	}

sub PREVIEW_QTYPRICE {
	my ($iniref,$toxml,$SITE) = @_;
	$iniref->{'PREVIEW'} = 1;
	return &TOXML::PREVIEW::std_box($SITE,$iniref,&pad($TOXML::RENDER::render_element{'QTYPRICE'}->($iniref,$toxml,$SITE)));
	}


1;
