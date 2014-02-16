package TOXML::CHOOSER;

use lib "/backend/lib";
require TOXML::UTIL;
require DBINFO;
require ZOOVY;
require TOXML;
require ZTOOLKIT;
use Data::Dumper;

use strict;



##
## to use the TOXML::CHOOSER inside a program all you have to do is 
##		call "buildChooser" pass USERNAME,FORMAT (e.g. LAYOUT, WIZARD), and SUBTYPE (undef if not appropriate)
##		
##	then somewhere in the program you'll need to handle the doSelect javascript function
#		which is called when the user makes a selection, after that the ball is back in your court (after all
#		this application is just a CHOOSER hence the name, otherwise it'd be called a "saver")
#
# // when a select is requested.
# function doSelect(docid) {
#	 alert('doSelect run!');
#	 }
#
##
## %options
##		selected = the currently selected template/docid
##		SUBTYPE = the subtype you want (if applicapble)
##
sub buildChooser {
	my ($USERNAME,$FORMAT,%options) = @_;

	my $HEADER = '';
	my $SUBTYPE = undef;
	if ($options{'SUBTYPE'}) { $SUBTYPE=$options{'SUBTYPE'}; }

	my $selected = $options{'selected'};
	if (not defined $selected) { $selected = ''; }
	elsif (substr($selected,0,1) eq '*') { $selected = '~'.substr($selected,1); } # change *PG to ~PG

	my $LU = $options{'*LU'};

	if ($FORMAT eq 'PRODUCT') { $FORMAT = 'LAYOUT'; }
	if ($FORMAT eq 'PAGE') { $FORMAT = 'LAYOUT'; }

	my $SREFstr = $options{'SREF'};

	$GTOOLS::TAG{'<!-- USERNAME -->'} = $USERNAME;
	$GTOOLS::TAG{'<!-- FORMAT -->'} = $FORMAT;
	my $c = '';
	my $arref = &TOXML::UTIL::listDocs($USERNAME,$FORMAT,DETAIL=>1,SUBTYPE=>$SUBTYPE,SORT=>1,LU=>$LU,SELECTED=>$selected);
	my $bgcolor = '';
	my @rows = ();

	#if ((defined $LU) && ($LU->is_zoovy())) {
	#	push @{$arref}, {
	#		TITLE=>"Facebook Announcement (Zoovy Use Only)",
	#		SUMMARY=>"Facebook Announcement",
	#		DOCID=>"i_20090624_facebook",
	#		CREATED=>"20200101",
	#		STAFF=>2,
	#		};
	#	}


	my $IMAGEpath = '';
	if ($FORMAT eq 'LAYOUT') { $IMAGEpath = &ZOOVY::resolve_userpath($USERNAME).'/TOXML'; }
	if ($FORMAT eq 'WIZARD') { $IMAGEpath = &ZOOVY::resolve_userpath($USERNAME).'/TOXML'; }
	if ($FORMAT eq 'EMAIL') { $IMAGEpath = &ZOOVY::resolve_userpath($USERNAME).'/TOXML'; }
	if ($FORMAT eq 'PAGE') { $IMAGEpath = &ZOOVY::resolve_userpath($USERNAME).'/TOXML'; }
	if ($FORMAT eq 'PRODUCT') { $IMAGEpath = &ZOOVY::resolve_userpath($USERNAME).'/TOXML'; }
	
	my @WARNINGS = ();
	


	my $rowcount = 0;
	foreach my $inforef (@{$arref}) {
		my $TITLE = $inforef->{'TITLE'};
		my $DOCID = $inforef->{'DOCID'};

		my $is_selected = ($DOCID eq $selected)?1:0;
		
		my $SUBTYPE = $inforef->{'SUBTYPE'};
		my $SUBTYPETXT = $TOXML::UTIL::LAYOUT_STYLES->{$SUBTYPE}[0];
		if (not defined $SUBTYPETXT) { $SUBTYPETXT = $SUBTYPE; }
		my $SUMMARY = $inforef->{'SUMMARY'};
		if ($SUMMARY eq '') { $SUMMARY = '<i>No summary provided.</i>'; }
		$SUMMARY =~ s/^[\n\r]+//gs;
		$SUMMARY =~ s/[\n\r]+/<br>\n/gs;
		
		#if (int($inforef->{'CREATED'}) == 0) {
		#	## a little backwards compatible logic
		#	$inforef->{'CREATED'} = int($inforef->{'RELEASED'});
		#	}


		if (not defined $inforef->{'CREATED'}) {
			## note: some old privacy policies don't have a "CREATED" date.
			$inforef->{'CREATED'} = $inforef->{'RELEASED'};
			}

		my $skip = 0;
		if (substr($DOCID,0,1) eq '~') {}
		elsif (int($inforef->{'CREATED'}) == 0) {
			## skip over deprecated layouts
			if ($inforef->{'REMEMBER'}) {}
			elsif ($is_selected) {}
			else { $skip++; }

			if (($is_selected) && (scalar(@WARNINGS)==0)) {
				push @WARNINGS, "The layout you are using has been deprecated. Be sure to make it a favorite before selecting another layout or you will be unable to navigate back to it.";
				}
			$SUMMARY = "<hr><font color='red'>** DEPRECATED: NO LONGER SUPPORTED **</font><br><i>Hint: add this file to your favorites, if it is removed it will no longer be selectable.</i><br><hr>".$SUMMARY;
			}
		next if ($skip);


		my $IMAGES = $inforef->{'IMAGES'};
	
		my ($height,$width) = (0,0);

		my $DIVID = "toxml-$FORMAT-$DOCID";
		$DIVID =~ s/[^a-zA-Z0-9\-]/-/gs;
		my ($t) = TOXML->new($FORMAT,$DOCID,USERNAME=>$USERNAME);
		## my $html = TOXML::CHOOSER::showDetails($USERNAME,$t);
		if (not defined $t) {
			$SUMMARY .= "<hr><font color='red'>Document FORMAT:$FORMAT DOCID:$DOCID could not be loaded (possibly corrupt).</font>";
			$skip++;
			}
		next if ($skip);
	
		$FORMAT = $t->getFormat();
		my ($config) = $t->findElements('CONFIG');
		my $html = '';
		# my $DOCID = $t->docId();
		my $img = '<img src="/images/image_not_selected.gif">';

		if ($t->{'_SYSTEM'}==0) {
			}
		elsif ((defined $config->{'THUMBNAIL_COUNT'}) && ($config->{'THUMBNAIL_COUNT'}<=0)) {
			## custom image!
			}
		elsif (($FORMAT eq 'EMAIL') || ($FORMAT eq 'WIZARD')) {
	
			my $dir = '';
			if ($FORMAT eq 'WIZARD') { $dir = 'wizards'; }
			if ($FORMAT eq 'EMAIL') { $dir = 'emails'; }

			my $URL = "http://www.zoovy.com/images/$dir/$DOCID~180x180.png";
			if ($FORMAT eq 'WIZARD') { $URL = '/images/blank.gif'; }

			$img = "<input type=\"hidden\" id=\"previewLink\" value=\"http://www.zoovy.com/images/$dir/$DOCID~0x0.png\"><a href=\"#\"><img onClick=\"openWindow(\$F('previewLink'));\" id=\"previewImg\" src=\"$URL\" width=180 border=0 height=180></a>";
			if ($config->{'THUMBNAIL_COUNT'}>1) {
				$img .= "<br><br><div class=\"tiny\">Additional Previews:</div><table><tr>";
				foreach my $i (split(',',$config->{'THUMBNAILS'})) {
					$img .= "<td><a href=\"#\"><img border=0 onClick=\"\$('previewLink').value='http://www.zoovy.com/images/$dir/$i~0x0.png'; \$('previewImg').src='http://www.zoovy.com/images/$dir/$i~180x180.png';\" width=75 height=75 src=\"http://www.zoovy.com/images/$dir/$i~75x75.png\"></td>";
					}
				$img .= "</tr></table>";
				}
			}
		elsif ($FORMAT eq 'LAYOUT') {
			$img = qq~<img id=previewImg src="/media/graphics/layouts/$DOCID.gif" width=100 height=100>~;
			}
		my $SUMMARYTXT = ($config->{'SUMMARY'})?$config->{'SUMMARY'}:'<i>No summary provided.</i>';
		my $detail = '';
	
		if ($FORMAT eq 'WIZARD') {
			my $profiledata = '';
			my $productdata = '';
		
			foreach my $el (@{$t->elements()}) {
				next if ($el->{'TYPE'} eq 'HIDDEN');
				next if ($el->{'READONLY'});
				next if ($el->{'DATA'} eq '');
				next if ($el->{'PROMPT'} eq '');
				if ($el->{'DATA'} =~ /^merchant\:/) { $profiledata .= $el->{'PROMPT'}.'<br>'; }
				elsif ($el->{'DATA'} =~ /^profile\:/) { $profiledata .= $el->{'PROMPT'}.'<br>'; }
				elsif ($el->{'DATA'} =~ /^product\:/) { $productdata .= $el->{'PROMPT'}.'<br>'; }
				}
			if ($profiledata eq '') { $profiledata = '<i>Unknown</i>'; }
			if ($productdata eq '') { $productdata = '<i>Unknown</i>'; }
	
			$detail = qq~	
					<table>
						<tr><td><b>Profile Fields</b></td><td><b>Product Fields</b></td></tr>
						<tr><td width=200 valign='top'>$profiledata</td><td width=200 valign='top'>$productdata</td></tr>
					</table>
					~;
			}

	
		$html = qq~
			<table cellspacing="0" cellpadding="2" width="100%">
				<tr class="table_colhead">
					<td colspan="3"><span class="text_colhead">Details</span></td>
				</tr>
				<tr>
					<td valign='top'>
					<center>
					$img<br>
					<a href="#" onClick="
detailDialog.dialog('close'); 
navigateTo('/biz/vstore/builder/index.cgi?ACTION=CHOOSERSAVE&FL=$DOCID&_SREF=$SREFstr');
">
					<img border=0  src="/images/toxmlicons/bigass_select.gif"></a>
					</center>
					</td>
					<td valign='top'>
					<b>$DOCID: $config->{'TITLE'}</b><br>
					<br>
					<div class="hint">
					Created: $config->{'CREATED'}
					</div>
					<div class="hint">
					Summary: $SUMMARYTXT
					</div>
					<div class="hint">
					$detail
					</div>
					</td>
				</tr>
			</table>
			~;
			
		if (not defined $html) { 
			$html = "<i>Could not load $FORMAT:$DOCID user=$USERNAME</i><br>"; 
			}

		$GTOOLS::TAG{'<!-- DETAILS -->'} .= "\n<div id=\"$DIVID\">\n$html\n</div>\n";
		
		my $image = '/images/blank.gif';
		if ($FORMAT eq 'LAYOUT') {
			$height = 70; $width = 50;
			if ( -f "/httpd/static/graphics/layouts/$DOCID.gif" ) { 
				$image = "/media/graphics/layouts/$DOCID.gif"; 
				$image = qq~
<a href="#" onClick="detailDialog = jQuery('#$DIVID').dialog({ autoOpen: true, closeOnEscape: true,  modal: true, width:550 });">
<img width=75 height=75 border=0 src='$image'></a>
~;			
				}
			}
		elsif ($FORMAT eq 'EMAIL') {
			$height = 70; $width = 50;
			my ($MEDIAHOST) = &ZOOVY::resolve_media_host($USERNAME);
			if (($inforef->{'SYSTEM'}==0) && (-f "/IMAGES/email-$DOCID.gif")) {
				$image = "//$MEDIAHOST/media/merchant/$USERNAME/email-$DOCID.gif";
				}
			elsif (-f "/httpd/htdocs/images/emails/$DOCID~75x75.png" ) { 
				$height = 75; $width = 75;
				$image = "/images/emails/$DOCID~75x75.png"; 
				}
			$image = qq~
<a href="#" onClick="detailDialog = jQuery('#$DIVID').dialog({ autoOpen: true, closeOnEscape: true,  modal: true, width:550 });">
			<img width=$width height=$height border=0 src='$image'></a>
			~;			
			}
		else {
			$image = 'Unknown Format';
			}
		
		## remember checkbox
		my $cb = "<input class='$bgcolor' ".($inforef->{'REMEMBER'}?'checked':'')." name='$DOCID' onClick='setCbState(this);' type='checkbox'>";			
		my $about = "<b>$DOCID: $TITLE</b><br><div class=\"hint\">$SUMMARY</div>";
		
		my $startxt = '';
		my $STARS = $inforef->{'STARS'};
		if (($STARS>0) && ($STARS<=10)) {
			$startxt = '<table border=0 cellpadding=0 cellspacing=0><tr>';
			foreach (1 .. int($STARS/2)) { $startxt .= "<td><img src='/images/toxmlicons/starfull.gif'></td>"; }
			if ($STARS % 2) {  $startxt .= "<td><img src='/images/toxmlicons/starhalf.gif'></td>"; }
			$startxt .= '<td></tr></table>';
			$about .= $startxt;
			}
		elsif ($STARS>10) {
			$about .= "<table border=0 cellpadding=0 cellspacing=0 width=100%><tr><td>Not Rated (Custom)</td></tr></table>";
			}

		my @icons = ();
		my $PROPERTIES = $inforef->{'PROPERTIES'};
		if ($FORMAT eq 'EMAIL') {
			}
		elsif ($FORMAT eq 'LAYOUT') {
			if ($PROPERTIES & 2) { push @icons, "dynamicimage.gif"; }
			if ($PROPERTIES & 4) { push @icons, "thumbnails.gif"; }
			}
		elsif ($FORMAT eq 'WIZARD') {
			if ($PROPERTIES & 2) { push @icons, "standard.gif"; }
			if ($PROPERTIES & 4) { push @icons, "header.gif"; }
			if ($PROPERTIES & 8) { push @icons, "detaildesc.gif"; }
			if ($PROPERTIES & 16) { push @icons, "flash.gif"; }
			}


		my $properties = '<table border=0 cellspacing=1 cellpadding=0><tr>';
		foreach my $icon (@icons) {
			$properties .= "<td><img src=\"/images/toxmlicons/$icon\"></td>";
			}
		$properties .= "</tr></table>";
		
		if ((defined $inforef->{'IMAGES'}) && ($inforef->{'IMAGES'}>0)) { 
			$properties .= "<table border=0 cellspacing=1 cellpadding=0><tr><td><img src=\"/images/toxmlicons/image.gif\"> x $inforef->{'IMAGES'}</td></tr></table>";
			}
		# use Data::Dumper; $properties .= Dumper(\@icons);
		if ($is_selected) { $properties .= "<b>Currently Selected</b><br>$cb<br>"; }
		else { $properties .= "<table border=0 cellspacing=0 cellpadding=0><tr><td>$cb</td><td>Favorite</td></tr></table>\n"; }

		my $class = 'r'.($rowcount++%2); # set to rx for highlight
		if ($inforef->{'REMEMBER'}) { $class .= '; rx'; }
		if ($is_selected) { $class = 'rs'; }

		my $buttons = qq~
		<button class="button" onClick="
detailDialog =  jQuery('#$DIVID').dialog({ autoOpen: true, closeOnEscape: true,  modal: true, width:550 });
">Details</button>
		<button class="button" onClick="
	jQuery('#setupContent').empty(); 
	return navigateTo('/biz/vstore/builder/index.cgi?ACTION=CHOOSERSAVE&FL=$DOCID&_SREF=$SREFstr');
">Select</button>
		~;

		push @rows, [ '', $image, $about, $properties, $buttons, $DOCID, $class ];
		}	




	my @header = ();
	push @header, { 'width'=>'5', 'title'=>'' };
	push @header, { 'width'=>'100', 'title'=>'Thumbnail' };
	push @header, { 'width'=>'250', 'title'=>'Description' };
	push @header, { 'width'=>'100', 'title'=>'Properties' };
	push @header, { 'width'=>'100', 'title'=>'' };

	my @icons = ();
	if ($FORMAT eq 'LAYOUT') {
		push @icons, { txt=>'Dynamic Images', img=>'dynamicimage.gif' };
		push @icons, { txt=>'Thumbnails', img=>'thumbnails.gif' };
		push @icons, { txt=>'Images', link=>'', img=>'image.gif' };
		}
	elsif ($FORMAT eq 'WIZARD') {
		push @icons, { txt=>'Standard Fields', img=>'standard.gif' };
		push @icons, { txt=>'Navigation Header', img=>'header.gif' };		
		push @icons, { txt=>'Detail Description', img=>'detaildesc.gif' };
		push @icons, { txt=>'Requires Flash', img=>'flash.gif' };		
		push @icons, { txt=>'2+ Images', link=>'', img=>'image.gif' };
		}
	elsif ($FORMAT eq 'WRAPPER') {
		push @icons, { txt=>'Logo', link=>'', img=>'logo.gif' };
		push @icons, { txt=>'Search', link=>'', img=>'search.gif' };
		push @icons, { txt=>'HTML Editor', link=>'', img=>'html.gif' };
		push @icons, { txt=>'Text Area', link=>'', img=>'text.gif' };
		push @icons, { txt=>'Text Box', link=>'', img=>'textbox.gif' };
		push @icons, { txt=>'Image', link=>'', img=>'image.gif' };
		}
	elsif ($FORMAT eq 'EMAIL') {
		}
	push @icons, { txt=>'Wiki', link=>'', img=>'wiki.gif' };
	push @icons, { txt=>'Web 2.0/AJAX', link=>'', img=>'web20.gif' };

	my $legend = '';
	foreach my $ref (@icons) {
		$legend .= qq~<tr><td><img src="/images/toxmlicons/$ref->{'img'}" width=17 height=17></td><td>~;
		if ($ref->{'link'}) { $legend .= qq~<a href="$ref->{'link'}">~; }
		$legend .= $ref->{'txt'};
		if ($ref->{'link'}) { $legend .= "</a>"; }
		$legend .= "</td></tr>\n"; 
		}

	$GTOOLS::TAG{'<!-- OURTABLE -->'} = &TOXML::CHOOSER::buildTable(\@header,\@rows,rowid=>5,rowclass=>6,height=>400);
	$GTOOLS::TAG{'<!-- ICONLEGEND -->'} = $legend;

	$GTOOLS::TAG{'<!-- WARNING -->'} = join("<br>WARNING: ",@WARNINGS);

	$/ = undef; my $data = <TOXML::CHOOSER::DATA>; $/ = "\n";

	$data = &ZTOOLKIT::interpolate(\%GTOOLS::TAG,$data);

	return($data);
	}


##
## Header is an array ref of hashes, and looks like this:
##	$header = [
##		{ 'width'=>'100', 'title'=>'Column 1' },
##		{ 'width'=>'200', 'title'=>'Column 2' },
##		{ 'width'=>'300', 'title'=>'Column 3' }
##	];
##
##	Rows are an array of arrays as follows:
##	$rows = [
##		[ 'data1a', 'data1b', 'data1c', ],
##		[ 'data2a', 'data2b', 'data2c', ],
##		];
##
##	%options are:
##		height=>n (where n is the height of the table in pixels - default 400)
##		rowid=>n	(where n is the column in the data row that will be used in the <tr id="row[n]"> value
##		rowclass=>n (now "n" is the column in the data row, if non-blank that class will be used to override)
##
sub buildTable {
	my ($headerrow,$rows, %options) = @_;	

	#use Data::Dumper;
	#print STDERR Dumper(\%options);

	if (not defined $options{'height'}) { $options{'height'} = 400; }

	my $selected_column = -1;	# which column contains the t/f value if it should appear as selected
	my $header = '';			# $header is the text for the "upper div"
	my $tablewidth = 0;
	my @colwidths = ();
	my $columnpos = 0;		# tracks which column in the array we are in.
	my $moreinfocol = -1; 
	my $visiblecolumns = 0;
	foreach my $col (@{$headerrow}) {

		if ($col->{'type'} eq 'moreinfo') {
			$moreinfocol = $columnpos;
			$col->{'width'} = 13;
			}

		$tablewidth += $col->{'width'};
		my $width = $col->{'width'};

		if ($col->{'type'} eq 'selected') {
			$selected_column = $columnpos;
			}				
		elsif ($col->{'type'} eq 'rowid') {
			$options{'rowid'} = $columnpos;
			}

		if ($width>0) {
			if ($col->{'title'} eq '') { $col->{'title'} = '&nbsp;'; }
			$header .= "<td class='zoovytableheader' valign='top' style='width: ${width}px;'>$col->{'title'}</td>";
			$visiblecolumns++;
			}
		$columnpos++;
		}
	$header .= "<td class='zoovytableheader' valign='top' style='width: 20px;'>&nbsp;</td>";	# implicit blank column for scrollbar

	my $ID = $options{'id'};
	if (not defined $ID) { $ID = ''; }
	my $body = '';						#		 
	my $x = 0;							# used to alternate column on/off
	my $colcount = @{$headerrow}-1;	# number of colunms -1 (since we go 0 to n-1)
	foreach my $row (@{$rows}) {
		$x++;
		my $id = $x;
		if ($options{'rowid'}) { $id = $row->[$options{'rowid'}]; }	# sets the row id from a data column (e.g. a hidden column)
		my $class = 'r'.($x%2);
		if (($options{'rowclass'}) && ($row->[$options{'rowclass'}] ne '')) { $class = $row->[$options{'rowclass'}]; }
		if (($selected_column > 0) && ($row->[$selected_column]>0)) { $class .= ' rs'; }

		my $line = '<tr id="'.$id.'" class="'.$class.'">';
		my $y = 0; 
		foreach my $col (0..$colcount) {
			my $width = $headerrow->[$y++]->{'width'};
			next if ($width==0);

			if ($col == $moreinfocol) {
				$line .= '<td class="cell" valign="top" style="width: 13px;">';
				$line .= '<a href="#"><img  id="'.$id.'!img" width=13 border=0 onClick="showMoreInfo(\''.$id.'\');" height=13 src="/biz/images/plus-13x13.gif"></a>';
				$line .= '</td>';
				}
			else {
				$line .= '<td class="cell" valign="top" style="width: '.$width.'px;">'.$row->[$col].'</td>';
				}
			}
		$line .= '</tr>';
		if ($moreinfocol>-1) {
			my $class = 'r'.($x%2);
			if (($options{'rowclass'}) && ($row->[$options{'rowclass'}] ne '')) { $class = $row->[$options{'rowclass'}]; }
			$line .= '<tr id="'.$id.'!trinfo" class="'.$class.'"><td colspan="'.($visiblecolumns).'" class="cell"><div id="'.$id.'!info"></div></td></tr>';
			}

		$body .= $line."\n";
		}

	
	$tablewidth += 20;	# allows for the scrollbar (ask Joel)
	
	if (defined $options{'width'}) {
		## this is a fixed width table
		$tablewidth = $options{'width'}-2;		## for padding
		}

	my $out =qq~
<div id="$ID!zoovytable" class="zoovytable" style="width: ${tablewidth}px;">
<div>
<table border="0" cellpadding="0" cellspacing="0">
<thead>	
<tr>$header</tr>
</thead>
</table>
</div>
<div id="$ID!zoovytableframe" class="zoovytableframe" style="height: $options{'height'}px; width: ${tablewidth}px;">
<table id="$ID!datatable" border="0" cellpadding="0" cellspacing="0">
<tbody>
$body
</tbody>
</table>
</div>
</div>~;
	return($out);
	}






##
## showDetail displays the detail about a specific docid.
##
#sub showDetails {
#	my ($USERNAME,$t) = @_;
#
#	return($html);
#	}




1;

__DATA__

<!-- begin toxml chooser -->

<script type="text/javascript">
var detailDialog;	
var fmt = '<!-- FORMAT -->';


// when a favorite checkbox is clicked.
function setCbState(cb) {

	var docid = cb.name;
	c = jQuery(adminApp.u.jqSelector('#',docid));
	cb = jQuery(cb);
	var api = { '_cmd':'adminTOXMLSetFavorite','format':fmt,'docid':docid };

   if (cb.attr('checked')) {
      c.addClass('rx');
		api.favorite = true;
		adminApp.model.addDispatchToQ(api,'passive'); adminApp.model.dispatchThis('passive');
      // ajaxNotify('TOXML/Remember?format='+fmt+'&docid='+escape(cb.name),'');
      }
   else {
		c.removeClass('rx');
		api.favorite = false;
		adminApp.model.addDispatchToQ(api,'passive'); adminApp.model.dispatchThis('passive');
      // ajaxNotify('TOXML/Forget?format='+fmt+'&docid='+escape(cb.name),'');
      }
   }




</script>

<div id="dialogs-hidden" style="display: none">
<!-- DETAILS -->

</div>

<table>
<tr>
	<td valign='top'>
	<!-- OURTABLE -->
	</td>
	<td valign='top'>

		<table cellspacing="0" cellpadding="2" width="150">
			<tr class="table_colhead">
				<td colspan="2"><span class="text_colhead">Legend</span></td>
			</tr>
			<!-- ICONLEGEND -->
			<tr>
				<td colspan="2"><span class="small">Note - image size are always displayed as width by
				height</span></td>
			</tr>
			<tr>
				<td colspan="2"><br><div class="warning"><!-- WARNING --></span></td>
			</tr>
		</table>
			
	</td>
</tr>
</table>
							
<!-- end TOXML chooser -->
