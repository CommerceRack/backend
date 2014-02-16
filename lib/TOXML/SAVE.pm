package TOXML::SAVE;

use encoding 'utf8';    ## tells us to internally use utf8 for all encoding
use locale;
use utf8 qw();
use Encode qw();
use Data::Dumper;

use lib '/backend/lib';
use strict;
require PRODUCT;

my $DEBUG = 0;

# This is a hash of references to subroutines, so we can make one simple call to
# generically reference a function for any of the element types byt the syntax
# $TOXML::flow_blah{FOO}->(params for foo);

# These are all of the flow save routines
%TOXML::SAVE::save_element = (
	'LISTEDITOR' => \&TOXML::SAVE::SAVE_LISTEDITOR,
	'TEXTBOX' => \&TOXML::SAVE::SAVE_TEXT,
	'QTYPRICE' => \&TOXML::SAVE::SAVE_TEXT,
	'TEXT' => \&TOXML::SAVE::SAVE_TEXT,
	'PRODLIST' => \&TOXML::SAVE::SAVE_PRODLIST,
	'IMAGE' => \&TOXML::SAVE::SAVE_TEXT,
	'SELECT' => \&TOXML::SAVE::SAVE_TEXT,
	'CHECKBOX' => \&TOXML::SAVE::SAVE_TEXT,

	'BANNER' => \&TOXML::SAVE::SAVE_BANNER,
	'HTML' => \&TOXML::SAVE::SAVE_TEXT,
	'DYNIMAGE' => \&TOXML::SAVE::SAVE_DYNIMAGE,
	'SLIDE' => \&TOXML::SAVE::SAVE_SLIDE,
	'GALLERY' => \&TOXML::SAVE::SAVE_GALLERY,
	'SEARCHBOX' => \&TOXML::SAVE::SAVE_SEARCHBOX,
	'HITGRAPH' => \&TOXML::SAVE::SAVE_HITGRAPH,
	'FINDER' => \&TOXML::SAVE::SAVE_FINDER,
);
if (defined $TOXML::SAVE::save_element{''}) {} #Keeps perl -w from bitching



sub SAVE_LISTEDITOR {
	my ($iniref,$dataref,$SREF) = @_;

	# print STDERR 'Saving: '.Dumper($iniref,$dataref,$SREF);	

	my $SORTBY = '';
	my $USERNAME = $SREF->{'_USERNAME'};
	my $list = $dataref->{'listorder'};
	my $SRC = $dataref->{'_SRC'};
#	print STDERR "CAT is: [$SRC]\n";
	$list =~ s/\|/\,/g;
	if ($SRC eq '') {
		## SHIT!! this shouldn't happen!
		}
	elsif (($SRC =~ /^NAVCAT\:(.*?)$/) || ($SRC =~ /^LIST\:(.*?)$/)) {
		my $safe = $1;
#		print STDERR "SAFENAME IS: [$safe]\n";
		my ($ncats) = NAVCAT->new($USERNAME,PRT=>$SREF->{'+prt'});
		$ncats->set($safe,products=>$list);
		$ncats->save();
		undef $ncats;
		}
	else {
		&TOXML::SAVE::smart_save($SREF,$SRC,$list);
		}
		
	return();
	}




sub SAVE_BANNER {
	my ($iniref,$dref,$SREF) = @_;
	
	my $ID = $iniref->{'ID'};

	my $USERNAME = $SREF->{'_USERNAME'};
	my %UREF = ();
	$UREF{'IMG'} = defined($dref->{$ID}) ? $dref->{$ID} : '' ;
	$UREF{'LINK'} = $dref->{"$ID/link"};
	$UREF{'ALT'} = $dref->{"$ID/alt"};
	&TOXML::SAVE::smart_save($SREF,$iniref->{'DATA'},&ZTOOLKIT::buildparams(\%UREF));

	return();
	}



###########################################################################
# SAVE ELEMENT

# Takes the CGI output of either the editor or preview mode of an element, and saves it into the
# element's INI file.


##
## TOXML::SAVE::smart_save
## purpose: performs a smart save to determine namespace, etc.
## parameters: SAVETO (eg: namespace:owner:tag), DATA_REF (reference to data)
## note: uses $SITE::merchant_id
## returns: 0 on success, 1 on failure
sub smart_save {
	my ($SREF, $SAVETO, $VAL) = @_;

	my $USERNAME = $SREF->username();

	$SAVETO =~ s/[\n\r]+//gs;
	if (length($USERNAME)<=0) { warn "smart_save(): Called TOXML::SMART::smart_save without setting USERNAME!!!"; return 1; }

	my ($namespace,$remainder) = split(':',lc($SAVETO),2);
	my $SKU = $SREF->{'_SKU'};
	if (($SKU eq '') && ($namespace eq 'product')) { 
		$namespace = 'channel'; 
		}
	elsif ($namespace eq 'merchant') { 
		$namespace = 'profile'; 
		}
	elsif ($namespace eq 'wrapper') { 
		$namespace = 'profile'; 
		$remainder = "wrapper:$remainder";
		}

	# print STDERR "SAVING! [$USERNAME,$SREF->{'_NS'},$remainder,$VAL]\n";
	if ($namespace eq 'profile') {
		## &ZOOVY::savemerchantns_attrib($USERNAME,$SREF->profile(),$remainder,$VAL);
		## die("profile saving no longer supported");
		print STDERR "TOXML/SAVE -- PROFILE SAVING\n";
		my ($D) = $SREF->Domain();
		if ($D->domainname() eq '') { die(" NO DOMAIN NAME "); }

		my ($nsref) = $D->as_legacy_nsref();
		$nsref->{"$remainder"} = $VAL;
		$D->from_legacy_nsref($nsref);
		$D->save();
		}

	if ($namespace eq 'product') { 
		my $SKU = $SREF->{'_SKU'};
		# &ZOOVY::saveproduct_attrib($USERNAME,$SKU,$remainder,$VAL); 
		my ($P) = PRODUCT->new($USERNAME,$SKU);
		$P->store($remainder,$VAL);
		$P->save();
		}
	
	if ($namespace eq "page") { 
		# print STDERR "Writing pageid=[".$SREF->pageid()."] profile=[".$SREF->profile()."] remainder=[$remainder] val=[$VAL]\n";
		my ($D) = $SREF->Domain();
		if ($D->domainname() eq '') { die(" NO DOMAIN NAME "); }

		my ($PG) = PAGE->new($USERNAME,$SREF->pageid(),DOMAIN=>$D->domainname(),PRT=>$SREF->prt()); 
		$PG->set($remainder,$VAL);
		$PG->save();
		undef $PG;
		}


	return($VAL);
	}



# sub SAVE_TEXTBOX (same functionality)
sub SAVE_TEXT {
	my ($iniref,$dataref,$SREF) = @_; # ini is a reference to a hash of the element's contents, $cgi is a CGI.pm object
	
	my ($namespace,$tag) = split(/:/,$iniref->{'DATA'},2);
	my $contents = $dataref->{ $tag };


	if ($iniref->{'TYPE'} eq 'HTML') {
		$contents =~ s/^.*<body.*?>(.*?)<\/body>.*$/$1/gs;

	   ## remove those crazy Â's
		# if (index($contents,chr(194))>=0) { my $ch = chr(194); $html =~ s/$ch/ /gs; }

		my $new = '';
		foreach my $seg (split(/(<img.*?>)/is,$contents)) {
			next if ($seg eq '');
			if ($seg =~ m/<img.*?>/i) {
				my $height = ''; if ($seg =~ /height="(.*?)"/) { $height = $1; }
				my $width = ''; if ($seg =~ /width="(.*?)"/) { $width = $1; }
				my $hspace = '0'; if ($seg =~ /hspace="(.*?)"/) { $hspace = $1; }
				my $align = 'baseline'; if ($seg =~ /align="(.*?)"/) { $align = $1; }
				my $border = 0; if ($seg =~ /border="(.*?)"/) { $border = $1; }
				my $src = ''; if ($seg =~ /src="(.*?)"/) { $src = $1; }
				my $alt = ''; if ($seg =~ /alt="(.*?)"/) { $alt = $1; }
	
				## SUBFOLDER
				## <img style="WIDTH: 175px; HEIGHT: 156px" height="156" hspace="0" src="http://static.zoovy.com/img/brian/-/subfolder/david.jpg" width="175" align="baseline" border="0" />
				if ($src =~ /http[s]?\:\/\/static\.zoovy\.com\/img\/(.*?)\/.*\/(.*?)\/(.*?)$/i) {
					$src = &ZOOVY::mediahost_imageurl($1,$2."/".$3,$height,$width,undef,0);
					}
			
				## <img style="WIDTH: 175px; HEIGHT: 156px" height="156" hspace="0" src="http://static.zoovy.com/img/brian/-/david.jpg" width="175" align="baseline" border="0" />
				elsif ($src =~ /http[s]?\:\/\/static\.zoovy\.com\/img\/(.*?)\/.*\/(.*?)$/i) {
					$src = &ZOOVY::mediahost_imageurl($1,$2,$height,$width,undef,0);
					}
				else {
					$src = undef;
					}
			
				if ($src eq '') {
					## NOT A ZOOVY URL .. so paste the original back in.
					$new .= $seg;
					}
				else {
					if ($alt eq '') { $alt = substr($src,index($src,'/')); }
	
					$new .= qq~<img src="$src" style="WIDTH: ~;
					$new .= $width;
					$new .= qq~px; HEIGHT: ~;
					$new .= $height;
					$new .= qq~px;" height="$height" width="$width" alt="$alt" hspace="$hspace" align="$align" border="$border"/>~;
					# print STDERR "FINAL NEW: $new\n";
					}
				}
			else {
				$new .= $seg;
				}
			}
		$contents = $new;
		}


	print STDERR Dumper($SREF);
	print STDERR "SAVE: $iniref->{'DATA'} [$contents]\n";
	&TOXML::SAVE::smart_save($SREF,$iniref->{'DATA'},$contents);

   return;
}


sub SAVE_PRODLIST {
	my ($iniref,$dref,$SREF) =@_; # ini is a reference to a hash of the element's contents, $cgi is a CGI.pm object
	
	## New code: manually sorted product lists.
	require NAVCAT;
	my ($productstr);

	my $PG = $SREF->pageid();
	my $sortby = $dref->{'SORTBY'};
	my $USERNAME = $SREF->{'_USERNAME'};

	
	my $SRC = $SREF->pageid();
	if ((defined $dref->{'SRC'}) && ($dref->{'SRC'} ne '')) { $SRC = $dref->{'SRC'}; }
	if (substr($SRC,0,5) eq 'LIST:') { $SRC = substr($SRC,5); }

	if ((substr($SRC,0,1) eq '.') || (substr($SRC,0,1) eq '$')) {
		my ($NC) = NAVCAT->new($USERNAME,PRT=>$SREF->{'+prt'});  
		$NC->set($SRC,sort=>$sortby);
		($productstr) = $NC->sort($SRC,$sortby); 
		$NC->set($SRC,products=>$productstr);
		$NC->save();
		undef $NC;
		}

	# ($productstr) = &NAVCAT::sort_navcat($SITE::merchant_id,&NAVCAT::resolve_navcat_from_page($SREF->{'_PG'}),$sortby,1,undef,undef,undef);
	## only save to navcat, then set the FLOW to manual sort

	
	my $DATA = "&";		# signifies this is stored in new format
	my @fields = qw(SORTBY FORMAT SRC SMARTMAX ALTERNATE COLS THUMB VIEWDETAILS MULTIPAGE SIZE SHOWSKU SHOWPRICE SHOWQUANTITY SHOWNOTES);
	require URI::Escape;
	foreach my $field (@fields) {
		next if (not defined $dref->{$field}); 								# don't save undef fields.
		next if (($field eq 'SRC') && ($dref->{'SAVE_AS_DEFAULT'}));	# if we're saving this as default, then don't save 
																										# SRC into the default (we'll save it separately)
		$DATA .= $field.'='.URI::Escape::uri_escape($dref->{$field})."&";
		}

	# print STDERR 'SAVING PRODLIST!'.Dumper($dref);
	if ((defined $dref->{'SAVE_AS_DEFAULT'}) && ($dref->{'SAVE_AS_DEFAULT'} eq 'on')) {
		&ZWEBSITE::save_website_attrib($USERNAME,'PRODLIST_DEFAULT',$DATA);
		## reset, just keep SRC .. everything else should go!
		$DATA = '&FORMAT=DEFAULT&SRC='.URI::Escape::uri_escape($dref->{'SRC'});
		}
	
	

#	print STDERR "SAVE_PRODLIST about to save: $iniref->{'DATA'}=$DATA\n";;	
	&TOXML::SAVE::smart_save($SREF,$iniref->{'DATA'},$DATA);

	return;
	}

sub SAVE_IMAGE {
	my ($iniref,$dref,$SREF) =@_; # ini is a reference to a hash of the element's contents, $cgi is a CGI.pm object
	
	my $USERNAME = $SREF->{'_USERNAME'};
	my $image = defined($dref->{'IMAGE'}) ? $dref->{'IMAGE'} : '' ;

	&TOXML::SAVE::smart_save($SREF,$iniref->{'DATA'},$image);
#	my $save_url = defined($dref->{'SAVEURL'}) ? $dref->{'SAVEURL'} : 0 ;
#	if (defined($iniref->{'URL_SAVETO'}) && $save_url) {
#		my $url = defined($dref->{'URL'}) ? $dref->{'URL'} : '' ;
#		&TOXML::SAVE::smart_save($SREF,$iniref->{'URL_SAVETO'},$url);
#		}
#	
#	# a lot of image elements don't have a SAVECONFIG element
#	# so we'll create one.
#	if (not defined $iniref->{'SAVECONFIG'}) {
#		$iniref->{'SAVECONFIG'} = $iniref->{'DATA'}.'cfg';
#		}
## we don't use configs anymore
#	if ($iniref->{'HEIGHT'} > 0 && $iniref->{'WIDTH'}>0) {
#		my ($width,$height) = &IMGLIB::minimal_size($USERNAME,$dref->{'IMAGE'},$iniref->{'WIDTH'},$iniref->{'HEIGHT'});
#		my $config = "H=$height,W=$width";
#		&TOXML::SAVE::smart_save($SREF,$iniref->{'SAVECONFIG'},$config);
#		}
#	else {
#		my $config = '';
#		&TOXML::SAVE::smart_save($SREF,$iniref->{'SAVECONFIG'},$config);
#		}

	## we need to bump the page timestamp so the last edited shows the correct time.
	#if ($iniref->{'DATA'} =~ /^merchant:/i) {
	#	&TOXML::SAVE::smart_save($SREF,'page:lastedit',time());
	#	}

	return;
	}



####################################################################################################


sub SAVE_FINDER {
	my ($iniref,$dataref,$SREF) = @_;
	&TOXML::SAVE::smart_save($SREF,$iniref->{'DATA'},$dataref->{"finder!$iniref->{'ID'}"});
	}

sub SAVE_HITGRAPH {
	my ($iniref,$dataref,$SREF) = @_;

	&TOXML::SAVE::smart_save($SREF,$iniref->{'DATA'},$dataref->{'header'});
	return;
	}


sub SAVE_SEARCHBOX {
	my ($iniref,$dataref,$SREF) = @_;
	
	my $x = $dataref->{'CATALOG'};
	$x =~ s/[^\w\@]+//g;	# VIRTUAL@CATALOG
	&TOXML::SAVE::smart_save($SREF,$iniref->{'CATALOGATTRIB'},$x);
	&TOXML::SAVE::smart_save($SREF,$iniref->{'PROMPTATTRIB'},$dataref->{'PROMPT'});
	&TOXML::SAVE::smart_save($SREF,$iniref->{'BUTTONATTRIB'},$dataref->{'BUTTON'});

	return;
};




sub SAVE_DYNIMAGE
{
	my ($iniref,$dataref,$SREF) =@_; # ini is a reference to a hash of the element's contents, $cgi is a CGI.pm object
		
	my @images;
	my @links;
	my $save = '';

	# Load up the @images, @links and @pauses arrays
	# (and create the $save lines for everything that isn't a @images or @links entry)
	my $count = 0;
	my @pauses = ();
	foreach my $key (sort keys %{$dataref})
	{
		next if ($key !~ /^image(\d+)$/);
		next if ($dataref->{$key} eq ''); # Skip blank images
		my $image_num = $1;
		$images[$count] = $dataref->{$key};
		# Get the link
		$links[$count] = $dataref->{"link$image_num"};
		unless (defined $links[$count]) { $links[$count] = ''; }
		# Get the pause
		$pauses[$count] = $dataref->{"pause$image_num"};
		unless (defined($pauses[$count]) && ($pauses[$count] ne '')) { $pauses[$count] = 2; } # Blanks or undef set to 2 secs
		if ($pauses[$count] !~ /^\d+\.?\d*$/) { $pauses[$count] = 0; } # Non-numbers set to 0
		$pauses[$count] = 100 * int($pauses[$count] * 10); # Make it into ticks (1/1000 of a sec) instead of secs
		if ($pauses[$count] < 100) { $pauses[$count] = 100; } # Javascript can crash with very small waits, so override low ones
		$count++;
	}

	my $blank_behavior = $dataref->{'blank_behavior'};
	unless (defined($blank_behavior) && ($blank_behavior ne '')) { $blank_behavior = 'none'; }

	# images and links are comma-separated lists of 
	$save .= "images=" . join(',', @images) . "\n";
	$save .= "links=" . join(',', @links) . "\n";
	$save .= "pauses=" . join(',', @pauses) . "\n";
	$save .= "blank_behavior=$blank_behavior\n";
	
	&TOXML::SAVE::smart_save($SREF,$iniref->{'DATA'},$save);
	return;
}

sub SAVE_SLIDE
{
	# There is no editor for this element (It simply gives you a slide show of all of a product's elements
	return;
}


sub SAVE_GALLERY
{
	my ($iniref,$dataref,$SREF) =@_; # ini is a reference to a hash of the element's contents, $cgi is a CGI.pm object
	
	my @gallery_fields = qw(SHOWPRICE);
	my $encoded = '';
	foreach my $field (@gallery_fields) {
		my $fieldcontents = $dataref->{$field};
		if (defined $fieldcontents) {
			$fieldcontents =~ s/\W//g; # Only word characters get saved, simple way to keep things clean
		}
		else {
			$fieldcontents = '';
		}
		$encoded .= $field . '=' . $fieldcontents . ':';
	}
	chop $encoded; # remove trailing :
	
	my $temp_str = $dataref->{'LISTSTYLE'} . ',' . $dataref->{'COLS'} . ',' . $dataref->{'ALTERNATE'} . ',' . $dataref->{'SORTBY'} . ',' . $encoded;

	$temp_str = &ZOOVY::incode($temp_str);
	
	&TOXML::SAVE::smart_save($SREF,$iniref->{'DATA'},$temp_str);

	return;
}

1;
