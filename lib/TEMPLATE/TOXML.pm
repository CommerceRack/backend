package TEMPLATE::TOXML;

require TEMPLATE::KISS;

sub upgradeLegacy {
	my ($USERNAME,$dir) = @_;

	use lib "/backend/lib";
	use TOXML;
	use Data::Dumper;
	use File::Copy;

	my $PROJECT = undef;
	my @PREVIEWS = ();
	if (substr($dir,0,1) eq '~') {
		push @PREVIEWS, '/httpd/static/templates/ebay/nopreview.png';
		}
	else {
		foreach my $file (
			"/httpd/static/wizards/$dir/$dir.png",
			"/httpd/static/wizards/$dir/$dir\_a.png",
			"/httpd/static/wizards/$dir/$dir\_b.png",
			"/httpd/static/wizards/$dir/$dir\_c.png",
			"/httpd/static/wizards/$dir/$dir\_d.png",
			"/httpd/static/wizards/$dir/$dir\_e.png",
			"/httpd/static/wizards/$dir/$dir\_f.png"
			) {
			if (-f "$file") { push @PREVIEWS, $file; }
			}
		}
	
	if (scalar(@PREVIEWS)==0) {
		push @PREVIEWS, '/httpd/static/templates/ebay/nopreview.png';		
		}

	my ($t) = TOXML->new('WIZARD',$dir,USERNAME=>$USERNAME);

	my $TEMPLATEDIR = "/httpd/static/templates/ebay/$dir";
	if (substr($dir,0,1) ne '~') {
		$PROJECT = '$SYSTEM';
		mkdir "$TEMPLATEDIR";
		chmod 0777, "$TEMPLATEDIR";
		}
	else {
		$PROJECT = 'LEGACY';
		$dir = substr($dir,1);	# remove leading ~
		$TEMPLATEDIR = &ZOOVY::resolve_userpath($USERNAME).'/PROJECTS';
		mkdir $TEMPLATEDIR; chmod 0777, $TEMPLATEDIR;
		$TEMPLATEDIR .= '/LEGACY';
		mkdir $TEMPLATEDIR; chmod 0777, $TEMPLATEDIR;
		$TEMPLATEDIR .= '/ebay';
		mkdir $TEMPLATEDIR; chmod 0777, $TEMPLATEDIR;
		$TEMPLATEDIR .= "/$dir";
		mkdir $TEMPLATEDIR; chmod 0777, $TEMPLATEDIR;
		TEMPLATE::create($USERNAME,'ebay','LEGACY',$dir);		
		}

	## copy previews (or none)
	my $i = 0;
	foreach my $file (@PREVIEWS) {
		if ($i==0) {
			File::Copy::copy($file,"$TEMPLATEDIR/preview.png");
			}
		else {
			File::Copy::copy($file,sprintf("$TEMPLATEDIR/preview-%d.png",$i));
			}
		$i++;
		}

	my $ELEMENTS = $t->{'_ELEMENTS'};

	my @NODES = ();
	my $HTML = '';
	my $FOLDER = '';
	foreach my $node (@{$ELEMENTS}) {
		if ($node->{'TYPE'} eq 'OUTPUT') {
			$HTML .= $node->{'HTML'};
			}
		elsif ($node->{'TYPE'} eq 'CONFIG') {
			if ($USERNAME ne '') {
				$HTML .= "<style type=\"text/css\">\n".$node->{'CSS'}."\n</style>";
				}
			if ($node->{'FOLDER'}) { $FOLDER = $node->{'FOLDER'}; }
			}
		}

	foreach my $node (@{$ELEMENTS}) {
		my %attribs = ();

		$attribs{'id'} = $node->{'ID'};				
		if ($node->{'PROMPT'}) {
			$attribs{'data-label'} = $node->{'PROMPT'};	
			delete $node->{'PROMPT'};
			}

		my $SUB = undef;
		if ($node->{'SUB'}) { 
			$attribs{'id'} = $node->{'SUB'};
			$SUB = '%'.$node->{'SUB'}.'%'; 
			}
		delete $node->{'ID'};
		delete $node->{'SUB'};

		if ($node->{'TYPE'} eq 'OUTPUT') {
			}
		elsif ($node->{'TYPE'} eq 'CONFIG') {
			}
		elsif ($node->{'LOAD'} eq 'URL::WIZARD_URL') {
			}
		elsif ($node->{'LOAD'} eq 'URL::GRAPHICS_URL') {
			}
		elsif ($node->{'LOAD'} eq 'URL::IMAGE_URL') {
			}
		elsif ($node->{'LOAD'} eq 'MARKETPLACE::CHECKOUT_URL') {
			}
		elsif ($node->{'TYPE'} eq 'READONLY') {
			if ($node->{'DATA'} eq 'FLOW::SKU') {
				$attribs{'data-attrib'} = '$PRODUCT';
				}
			elsif ($node->{'DATA'} eq 'FLOW::PROD') {
				$attribs{'data-attrib'} = '$PRODUCT';
				}
			elsif ($node->{'DATA'} eq 'FLOW::USERNAME') {
				$attribs{'data-attrib'} = '$USERNAME';
				}
			elsif ($node->{'LOAD'} eq 'URL::CHECKOUT') {
				}
			elsif ($node->{'DATA'} eq 'URL::WIZARD_URL') {
				}
			elsif ($node->{'LOAD'} eq 'profile:zoovy:popup_wrapper') {
				warn "IGNORING: ".Dumper($node)."\n";
				}
			elsif ($node->{'LOAD'} eq 'merchant:zoovy:wiz_layout') {
				}
			elsif ($node->{'LOAD'} eq 'merchant:zoovy:wiz_chooselayout') {
				}
			elsif ($node->{'LOAD'} eq 'merchant:zoovy:wiz_choosebgc_layout') {
				}
			elsif ($node->{'LOAD'} eq 'merchant:zoovy:wiz_packaged_layout') {
				}
			else {
				warn 'UNKNOWN ELEMENTS: '.Dumper($node);
				}

			if ($attribs{'data-attrib'}) {
				my $TAG = TEMPLATE::KISS::attribsToTag('span',\%attribs,"$attribs{'data-attrib'}");
				if ($SUB) {
					$HTML =~ s/$SUB/$TAG/gs;
					}
				else {
					$HTML .= $TAG;
					}
				}
			}
		elsif ($node->{'DATA'} =~ /^product:(.*?)$/) {
			$attribs{'data-attrib'} = $1;
			$attribs{'data-object'} = 'PRODUCT';
			my %if = %attribs;
			delete $if{'data-label'};
			$if{'data-if'} = 'BLANK';
			$if{'data-then'} = 'REMOVE';

			my $TAG = '';
			if ($node->{'TYPE'} eq 'IMAGE') {
				foreach my $k (keys %{$node}) {
					my $attrib = '';
					next if ($k eq 'data');
					next if ($k eq 'id');

					if ($k eq 'ZOOM') { $attribs{'data-img-zoom'} = $node->{$k}; }
					elsif ($k eq 'TYPE') { $attribs{'data-format'} = 'img'; }
					elsif (($k eq 'HEIGHT') || ($k eq 'WIDTH')) { $attribs{lc($k)} = $node->{$k}; }
					else { $attribs{lc("data-img-$k")} = $node->{$k}; }
					}

				File::Copy::copy('/httpd/static/templates/ebay/placeholder-2.png',$TEMPLATEDIR);
				$attribs{'src'} = "placeholder-2.png";
				$TAG = &TEMPLATE::KISS::attribsToTag('img',\%attribs);
				delete $attribs{'src'};
				if ($attribs{'data-img-zoom'}) {
					my %zoom = %attribs;
					$zoom{'data-img-height'} = $attribs{'height'};
					$zoom{'data-img-width'} = $attribs{'width'};
					$TAG = &TEMPLATE::KISS::attribsToTag('a',\%zoom,$TAG);
					}
				$TAG = &TEMPLATE::KISS::attribsToTag('span',\%if,$TAG);
				}
			else {
				foreach my $k (keys %{$node}) {
					next if ($k eq 'data');
					next if ($k eq 'id');
					$attribs{lc("data-input-$k")} = $node->{$k};
					}
				$TAG = TEMPLATE::KISS::attribsToTag('span',\%attribs,"Product $attribs{'data-label'}");
				}

			if ($SUB) {
				$HTML =~ s/$SUB/$TAG/gs;
				}
			else {
				$HTML .= $TAG;
				}

			}
		elsif ($node->{'DATA'} =~ /^(merchant|profile):(.*?)$/) {
			$attribs{'data-attrib'} = $2;
			$attribs{'data-object'} = 'profile';
			my $TAG = '';
			if ($USERNAME eq '') {
				if ($node->{'TYPE'} eq 'IF') {
					$TAG = $node->{'TRUE'};
					}
				elsif ($node->{'TYPE'} eq 'IMAGE') {
					foreach my $k (keys %{$node}) { $attribs{lc($k)} = $node->{$k}; }
					if ($attribs{'data-attrib'} eq 'zoovy:company_logo') {	
						File::Copy::copy('/httpd/static/templates/ebay/yourlogohere.png',$TEMPLATEDIR);
						$attribs{'src'} = "yourlogohere.png";
						}
					else {
						File::Copy::copy('/httpd/static/templates/ebay/placeholder.jpg',$TEMPLATEDIR);
						$attribs{'src'} = "placeholder.jpg";
						}
					$TAG = &TEMPLATE::KISS::attribsToTag('img',\%attribs);
					}
				elsif ($attribs{'data-label'}) {
					$TAG = "[[Insert $attribs{'data-label'}]]";
					}
				else {
					$TAG = "[[Create $attribs{'id'}]]";
					}					
				}
			else {
				warn 'IGNORING: '.Dumper($node,\%attribs);
				$TAG = "<!-- UPGRADE-FAILED: ".Dumper($node,\%attribs)." -->";
				}

			if ($SUB) {
				$HTML =~ s/$SUB/$TAG/gs;
				}
			else {
				$HTML .= "$TAG";
				}

			}
		elsif (($dir eq 'warlock') || ($dir eq 'multiplain') || ($dir eq 'series3-gelflex') || ($dir eq 'isotope') || ($dir eq 'sirius') || ($dir eq 'neutron') || ($dir eq 'evolution') || ($dir eq 'brandx')) {
			}
		else {
			$HTML .= "<!-- CANNOT PROCESS: ".Dumper($dir,$node)." -->";
			print STDERR Dumper($dir,$node);
			}
		}

	if ($dir =~ /warlock/i) { 
		$HTML =~ s/\[\[Insert Color\]\]/\%COLOR1\%/gs;
		$HTML =~ s/\%COLOR1\%/17149D/gs; 
		$HTML =~ s/\/warlock\/17149D/\/warlock/gs;
		$HTML =~ s/\/warlock\//\//gs;
		system("/bin/cp /httpd/static/graphics/gfx/wizards/series5/warlock/*.gif $TEMPLATEDIR");
		system("/bin/cp /httpd/static/graphics/gfx/wizards/series5/warlock/17149D/*.gif $TEMPLATEDIR");
		}

	if ($HTML =~ /%LAYOUT%/) {
		my $LAYOUT = qq~

<!-- LAYOUT B -->

<div align="center">
<div style="color:#17149D; font-family:Verdana, Arial, Helvetica, sans-serif; font-size:15px; font-weight:bold;">
<span data-attrib="zoovy:prod_name" data-object="product"></span>
</div>
<table cellspacing="5" cellpadding="0" border="0"><tr>
   <td align="left">

<span data-attrib="zoovy:prod_image1" data-if="BLANK" data-object="PRODUCT" data-then="REMOVE" id="IMAGE1">
<a data-attrib="zoovy:prod_image1" data-format="img" data-img-bgcolor="FFFFFF" data-img-border="0" data-img-data="product:zoovy:prod_image1" data-img-height="150" data-img-width="150" data-img-zoom="1" data-label="Image (400x400)" data-object="PRODUCT" height="400" id="IMAGE1" width="400">
<img data-attrib="zoovy:prod_image1" data-format="img" data-img-bgcolor="FFFFFF" data-img-border="0" data-img-data="product:zoovy:prod_image1" data-img-zoom="1" data-label="Image (400x400)" data-object="PRODUCT" height="400" id="IMAGE1" src="placeholder-2.png" width="400" /></a>
</span>
	
	</td>
   <td align="center">

<span data-attrib="zoovy:prod_image2" data-if="BLANK" data-object="PRODUCT" data-then="REMOVE" id="IMAGE2">
<a data-attrib="zoovy:prod_image2" data-format="img" data-img-bgcolor="FFFFFF" data-img-border="0" data-img-data="product:zoovy:prod_image2" data-img-height="150" data-img-width="150" data-img-zoom="1" data-label="Image (400x400)" data-object="PRODUCT" height="400" id="IMAGE2" width="400">
<img data-attrib="zoovy:prod_image2" data-format="img" data-img-bgcolor="FFFFFF" data-img-border="0" data-img-data="product:zoovy:prod_image2" data-img-zoom="1" data-label="Image (400x400)" data-object="PRODUCT" height="400" id="IMAGE2" src="placeholder-2.png" width="400" /></a>
</span>
	</td>
   <td align="right">
<span data-attrib="zoovy:prod_image3" data-if="BLANK" data-object="PRODUCT" data-then="REMOVE" id="IMAGE3">
<a data-attrib="zoovy:prod_image3" data-format="img" data-img-bgcolor="FFFFFF" data-img-border="0" data-img-data="product:zoovy:prod_image3" data-img-height="150" data-img-width="150" data-img-zoom="1" data-label="Image (400x400)" data-object="PRODUCT" height="400" id="IMAGE3" width="400">
<img data-attrib="zoovy:prod_image3" data-format="img" data-img-bgcolor="FFFFFF" data-img-border="0" data-img-data="product:zoovy:prod_image3" data-img-zoom="1" data-label="Image (400x400)" data-object="PRODUCT" height="400" id="IMAGE3" src="placeholder-2.png" width="400" /></a>
</span>
	</td>
</tr></table>

<table cellspacing="0" cellpadding="0" width="100%"><tr>
   <td align="left" style="padding-right:5px;" valign="top" width="99%"><div class="war_text">
<div class="adtext"><p><span data-attrib="zoovy:prod_desc" data-input-cols="80" data-input-data="product:zoovy:prod_desc" data-input-rows="5" data-input-type="TEXTAREA" data-label="Product Description" data-object="PRODUCT" id="PRODUCT_DESCRIPTION">
Product Description</span>
	</div></td>
   <td valign="top">

   <table cellspacing="2"  cellpadding="0" width="100%" border="0"><tr>
      <td>
<span data-attrib="zoovy:prod_image4" data-if="BLANK" data-object="PRODUCT" data-then="REMOVE" id="IMAGE4">
<a data-attrib="zoovy:prod_image4" data-format="img" data-img-bgcolor="FFFFFF" data-img-border="0" data-img-data="product:zoovy:prod_image4" data-img-height="150" data-img-width="150" data-img-zoom="1" data-label="Image (150x150)" data-object="PRODUCT" height="150" id="IMAGE4" width="150">
<img data-attrib="zoovy:prod_image4" data-format="img" data-img-bgcolor="FFFFFF" data-img-border="0" data-img-data="product:zoovy:prod_image4" data-img-zoom="1" data-label="Image (150x150)" data-object="PRODUCT" height="150" id="IMAGE4" src="placeholder-2.png" width="150" /></a>
</span>
		</td>
      <td>
<span data-attrib="zoovy:prod_image5" data-if="BLANK" data-object="PRODUCT" data-then="REMOVE" id="IMAGE5">
<a data-attrib="zoovy:prod_image5" data-format="img" data-img-bgcolor="FFFFFF" data-img-border="0" data-img-data="product:zoovy:prod_image5" data-img-height="150" data-img-width="150" data-img-zoom="1" data-label="Image (150x150)" data-object="PRODUCT" height="150" id="IMAGE5" width="150">
<img data-attrib="zoovy:prod_image5" data-format="img" data-img-bgcolor="FFFFFF" data-img-border="0" data-img-data="product:zoovy:prod_image5" data-img-zoom="1" data-label="Image (150x150)" data-object="PRODUCT" height="150" id="IMAGE5" src="placeholder-2.png" width="150" /></a>
</span>
		</td>
   </tr><tr>
      <td>
<span data-attrib="zoovy:prod_image6" data-if="BLANK" data-object="PRODUCT" data-then="REMOVE" id="IMAGE6">
<a data-attrib="zoovy:prod_image6" data-format="img" data-img-bgcolor="FFFFFF" data-img-border="0" data-img-data="product:zoovy:prod_image6" data-img-height="150" data-img-width="150" data-img-zoom="1" data-label="Image (150x150)" data-object="PRODUCT" height="150" id="IMAGE6" width="150">
<img data-attrib="zoovy:prod_image6" data-format="img" data-img-bgcolor="FFFFFF" data-img-border="0" data-img-data="product:zoovy:prod_image6" data-img-zoom="1" data-label="Image (150x150)" data-object="PRODUCT" height="150" id="IMAGE6" src="placeholder-2.png" width="150" /></a>
</span>
		</td>
      <td>
<span data-attrib="zoovy:prod_image7" data-if="BLANK" data-object="PRODUCT" data-then="REMOVE" id="IMAGE7">
<a data-attrib="zoovy:prod_image7" data-format="img" data-img-bgcolor="FFFFFF" data-img-border="0" data-img-data="product:zoovy:prod_image7" data-img-height="150" data-img-width="150" data-img-zoom="1" data-label="Image (150x150)" data-object="PRODUCT" height="150" id="IMAGE7" width="150">
<img data-attrib="zoovy:prod_image7" data-format="img" data-img-bgcolor="FFFFFF" data-img-border="0" data-img-data="product:zoovy:prod_image7" data-img-zoom="1" data-label="Image (150x150)" data-object="PRODUCT" height="150" id="IMAGE6" src="placeholder-2.png" width="150" /></a>
</span>
		</td>
   </tr></table>

   </td>
</tr><tr>

   <td colspan="2"><div class="war_text">
<div class="adtext"><p><span data-attrib="zoovy:prod_desc" data-input-cols="80" data-input-data="product:zoovy:prod_detail" data-input-rows="5" data-input-type="TEXTAREA" data-label="Product Detail" data-object="PRODUCT" id="PRODUCT_DETAIL">
Product Detailed Description</span>
	</div></td>
</tr></table>
</div>


<!-- /LAYOUT B -->
~;
		$HTML =~ s/%LAYOUT%/$LAYOUT/;
		}

	my $NEW = '';
	foreach my $CHUNK ( split(/(\/\/www\.zoovy\.com\/.*?\.(jpg|png|gif))/, $HTML) ) {
		if ($CHUNK =~ /^(jpg|png|gif)$/) {
			}
		elsif ($CHUNK =~ /^\/\/www\.zoovy\.com\/htmlwiz\/(.*)\/(.*?)$/) {
			##htmlwiz/borders/corner_ul.gif
			File::Copy::copy("/httpd/static/graphics/$1/$2","$TEMPLATEDIR/$2");
			$NEW .= $2;
			}
		elsif ($CHUNK =~ /^\/\/www\.zoovy\.com\/images\/paymentlogos\/(.*?)$/) {
			File::Copy::copy("/httpd/static/graphics/paymentlogos/$1","$TEMPLATEDIR/$1");
			$NEW .= $1;
			}
		else {
			$NEW .= $CHUNK;
			}
		}

	$HTML = $NEW; $NEW = '';
	foreach my $CHUNK ( split(/(\%WIZARD_URL\%\/.*?\.(jpg|png|gif))/, $HTML) ) {
		if ($CHUNK =~ /^(jpg|png|gif)$/) {
			$CHUNK = '';
			}
		elsif ($CHUNK =~ /^\%WIZARD_URL\%\/(.*?)$/) {
			print STDERR "CHUNK:$CHUNK\n";
			if ($USERNAME eq '') {
				File::Copy::copy("/httpd/static/wizards/$dir/$1","$TEMPLATEDIR/$1");
				$NEW .= $1;
				}
			elsif ($FOLDER) {
				## in a folder.
				my ($userpath) = &ZOOVY::resolve_userpath($USERNAME);
				File::Copy::copy("$userpath/IMAGES/$FOLDER/$1","$TEMPLATEDIR/$1");
				$NEW .= $1;				
				}
			else {
				## not in a folder, public files dir.
				my ($userpath) = &ZOOVY::resolve_userpath($USERNAME);
				File::Copy::copy("$userpath/IMAGES/$1","$TEMPLATEDIR/$1");
				$NEW .= $1;				
				}
			}
		#elsif ($CHUNK =~ /^\/\/www\.zoovy\.com\/images\/paymentlogos\/(.*?)$/) {
		#	File::Copy::copy("/httpd/static/graphics/paymentlogos/$1","$TEMPLATEDIR/$1");
		#	$NEW .= $1;
		#	}
		else {
			$NEW .= $CHUNK;
			}
		}
	$HTML = $NEW; $NEW = '';

	foreach my $CHUNK ( split(/(\/\/static\.zoovy\.com.*?(jpg|png|gif))/, $HTML) ) {
		if ($CHUNK =~ /^(jpg|png|gif)$/) {
			}
		elsif (substr($CHUNK,0,2) eq '//') {
			print STDERR "CHUNK: $CHUNK\n";
			if ($CHUNK =~ /^\/\/static\.zoovy\.com\/graphics\/wizards\/(.*?)\/(.*?)$/) {
				print STDERR "$TEMPLATEDIR/$2\n";
				$CHUNK = $2;
				File::Copy::copy("/httpd/static/graphics/wizards/$1/$2","$TEMPLATEDIR/$2");
				}
			elsif ($CHUNK =~ /^\/\/static\.zoovy\.com\/graphics\/gfx\/wizards\/(.*?)\/(.*?)$/) {
				print STDERR "$TEMPLATEDIR/$2\n";
				$CHUNK = $2;
				File::Copy::copy("/httpd/static/graphics/gfx/wizards/$1/$2","$TEMPLATEDIR/$2");
				}
			elsif ($CHUNK =~ /^\/\/static\.zoovy\.com\/graphics\/wrappers\/(.*?)\/(.*?)$/) {
				## //static.zoovy.com/graphics/wrappers/baggy/body_left_bg.gif
				print STDERR "$TEMPLATEDIR/$2\n";
				$CHUNK = $2;
				File::Copy::copy("/httpd/static/graphics/wrappers/$1/$2","$TEMPLATEDIR/$2");
				}
			elsif ($CHUNK =~ /^\/\/static\.zoovy\.com\/graphics\/general\/([a-z0-9\.]+)$/) {
				print STDERR "$TEMPLATEDIR/$2\n";
				$CHUNK = $1;
				File::Copy::copy("/httpd/static/graphics/$1","$TEMPLATEDIR/$1");
				}
			elsif ($CHUNK eq '//static.zoovy.com/graphics/wizards/blank.gif') {
				$CHUNK = 'blank.gif';
				File::Copy::copy("/httpd/static/graphics/blank.gif","$TEMPLATEDIR/blank.gif");
				}
			else {
				die($CHUNK);
				}
			$NEW .= "$CHUNK";
			}
		else {
			$NEW .= $CHUNK;
			}
		}
	$HTML = $NEW;

	print STDERR "$TEMPLATEDIR/index.html\n";
	open Findex, ">$TEMPLATEDIR/index.html";
	print Findex "$HTML";
	close Findex;

	return($PROJECT,$dir);
	}

1;

