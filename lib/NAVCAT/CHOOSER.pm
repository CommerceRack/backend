package NAVCAT::CHOOSER;

use strict;
use lib "/htpd/modules";
require LUSER;

sub prodcount {
	my ($str) = @_;

	my $count = 0;
	foreach my $pid (split(/,/,$str)) {
		next if ($pid eq '');
		$count++;
		}
	return($count);
	}


##
##
##  note: you need to understand the following relevant div's 
##			_root is the root of the tree, and is only output when $safe = .
##			~safe (ex: ~.asdf) is the root of this tree branch, if you overwrite that, you toast everything!
##					but it's highly useful for expanding/compressing an entire subtree!
##			safe (ex: .asdf) is in a <tr> below the savename and can be updated with chooser content 
##								by chooser content I mean it can be modified by functions like the add/delete/products, etc.		
##
## note: in a chooser mode
##    a variable titled id="_pid" should set on the parent form and $options{'product'} should be passed.
##
##
sub buildLevel {
	my ($LU,$NC,$safe,%options) = @_;

	my $KEY = sprintf("%s*%s",$LU->username(),$LU->luser());
	my ($memd) = &ZOOVY::getMemd($LU->username());

	my $PID = $options{'product'};
	if (not defined $PID) { $PID = $options{'pid'}; }

	if (not defined $options{'restrict_add'}) { $options{'restricted'} = 0; }
	
	my $html = '';

	if ($safe eq '.') { 	
		$html .= "<div id=\"_root\">"; 
		if (defined $PID) {
			$html .= "<input type=\"hidden\" id=\"_pid\" name=\"_pid\" value=\"$PID\">";
			$html .= "<input type=\"hidden\" id=\"_diffs\" name=\"_diffs\" value=\"\">";
			print STDERR "<input type=\"hidden\" id=\"_pid\" name=\"_pid\" value=\"$PID\">\n";
			}
		}

	$html .= "<table width=100% border=0>";

	if ($safe eq '.') { 
		my ($pretty,$children,$products) = $NC->get('.');
		if ((not defined $pretty) || ($pretty eq '')) { $pretty = 'Homepage'; }
		my $prodcount = &prodcount($products);
		my $checked = '';
		if (defined $options{'product'}) {
			$checked = (index(",$products,",",$PID,")>=0)?'checked':'';
			$checked = qq~<input onChange="updateCat(this);" type="checkbox" $checked name="cb_$safe">~;
			}
		else {
			## NO EDIT ON THE HOMEPAGE SINCE THAT'S PROFILE SPECIFIC
			## $checked = "<a href=\"https://www.zoovy.com/biz/setup/builder/index.cgi?ACTION=INITEDIT&PG=$safe&FS=C\">[EDIT]</a> ";
			}
		$html .= qq~<tr id="tr_$safe"><td id="td_$safe" class="navcat_Z" colspan='3'> $checked <b>$pretty </b> <br></td></tr>~; 
		}
	$html .= "<tr><td nowrap colspan='2'>";

	my $breadcrumb = '';
	my ($bcorder,$bcnames) = $NC->breadcrumb($safe);
	foreach my $bcsafe (@{$bcorder}) {
		$breadcrumb .= '/ '.$bcnames->{$bcsafe}.' ';
		}
	# $html .= qq~<span style="font-size: 8pt; font-family: arial;">$breadcrumb</span><br>~;

	if ((substr($safe,0,1) ne '$') && ($NC->depth($safe)<5) && (not $options{'restricted'})) {
		$html .= "<a href=\"#\" onClick=\"addNew('$safe'); return false;\"><img border=0 src='https://www.zoovy.com/biz/ajax/navcat_icons/add_new.gif'></a>";
		}

	my $adddivs = '';

	if ($safe ne '.') { 
		# $html .= "<a href=\"javascript:addProducts('$safe');\"><img border=0 src='https://www.zoovy.com/biz/ajax/navcat_icons/products.gif'></a>";
		$html .= "<a href=\"#\" onClick=\"renameCat('$safe'); return false;\"><img border=0 src='https://www.zoovy.com/biz/ajax/navcat_icons/rename.gif'></a>"; 
		if (scalar(@{$NC->fetch_childnodes($safe)})==0) {
			$html .= "<a href=\"#\" onClick=\"deleteCat('$safe',0); return false;\"><img border=0 src='https://www.zoovy.com/biz/ajax/navcat_icons/delete.gif'></a>";
			}


		my $jssafe = $safe; $jssafe =~ s/[^\w]/_/g; $jssafe = "x_$jssafe"; 
		$html .= "<script>\nvar $jssafe;\n</script>";

		if ($PID ne '') {
			## only show a list of products in the navcat, don't let them edit.
			$html .= "<a href=\"#\" onClick=\"showNavcatProducts('$safe'); return false;\"><img border=0 src='https://www.zoovy.com/biz/ajax/navcat_icons/products.gif'></a>"; 
			}
		else {
#			$html .= "<a href=\"javascript:{
#				$jssafe = new ZProductFinder('~$safe','$jssafe','NAVCAT\:$safe');
#				$jssafe.Build();
#				};
#				\"><img border=0 src='https://www.zoovy.com/biz/ajax/navcat_icons/add_prod.gif'></a>"; 
#			$html .= "<a href=\"javascript:ProductFinder('NAVCAT:$safe','~$safe');\"><img border=0 src='https://www.zoovy.com/biz/ajax/navcat_icons/add_prod.gif'></a>";
			$html .= qq~<a href="#"><img border=0 src='https://www.zoovy.com/biz/ajax/navcat_icons/add_prod.gif' onClick="adminApp.ext.admin.a.showFinderInModal('NAVCAT','$safe'); return false;"></a>~;
			}
		}

	if (substr($safe,0,1) eq '.') {
			## Show the EDIT link adjacent to the category
			$html .= "<a href=\"#\" onClick=\"navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&PG=$safe&FS=C'); return(false);\"><img border=0 src=\"https://www.zoovy.com/biz/ajax/navcat_icons/edit_page-72x20.gif\"></a> ";
			}

	$html .= $adddivs;

	$html .= "</td></tr>";
	$html .= "<tr><td colspan='2'><div id=\"~$safe\"></div></td></tr>";

	foreach my $safe (@{$NC->fetch_childnodes($safe)}) {
		my ($pretty,$children,$products) = $NC->get($safe);
		if ($pretty eq '') { $pretty = "[Unnameda Category: $safe]"; }
		my $open = 0; 

		# print STDERR "LU: nc:$safe".$LU->get('nc:'.$safe)."\n";
		if ((defined $memd) && ($memd->get("$KEY/nc:$safe")>0)) { $open = 1; }
		my $checked = '';
		if (defined $PID) {
			$checked = (index(",$products,",",$PID,")>=0)?'checked':'';
			$checked = qq~<input type="checkbox" onChange="updateCat(this);" $checked name="cb_$safe">~;
			}
		
		my $prodcount = &prodcount($products);
		$html .= "<tr id=\"tr_$safe\">";
		$html .= "<td align=\"right\" id=\"td_$safe\">";
		my $imgfile = ($open)?'https://www.zoovy.com/biz/ajax/navcat_icons/minidown.gif':'https://www.zoovy.com/biz/ajax/navcat_icons/miniup.gif';
		$html .= qq~
			<a href="#" onClick="toggleCat('$safe'); return(false);">
			<img width=20 height=20 border=0 id='ICON_$safe' src='$imgfile'>
			</a>~;
		$html .= "</td>";

		if ($pretty eq '') { $pretty = "<i>Unnamedx Category [$safe]</i>"; }
		my $depth = $NC->depth($safe);
		$html .= qq~<td class=\"navcat_$depth\"> 
		<table>
			<tr>
				<td>$checked</td>
				<td><b>$pretty</b> ($prodcount products)<br></td>
			</tr>	
		</table>
		</td></tr>~;
		$html .= "<tr><td></td><td><div id=\"$safe\">";
		
		## a little bit 'o' recursion
		if ($open) {
			$html .= &NAVCAT::CHOOSER::buildLevel($LU,$NC,$safe,%options);
			}

		$html .= "</div></td></tr>";
		}


	if (($safe eq '.') && (not $options{'restricted'})) {
		## display lists
		$html .= "<tr><td colspan='2'>&nbsp;</td></tr>";
		foreach my $safe (sort $NC->paths()) {
			next unless (substr($safe,0,1) eq '$');
			my ($pretty,$children,$products) = $NC->get($safe);
			my $checked = '';
			if (defined $PID) {
				$checked = (index(",$products,",",$PID,")>=0)?'checked':'';
				$checked = qq~<input type="checkbox" onChange="updateCat(this);" $checked name="cb_$safe">~;
				}
			my $prodcount = &prodcount($products);
			$html .= "<tr>";
			$html .= "<td align=\"right\">";
			$html .= "<a href=\"#\" onClick=\"toggleCat('$safe');\"><img width=20 height=20 border=0 id='ICON_$safe' src='https://www.zoovy.com/biz/ajax/navcat_icons/miniup.gif'></a>";
			$html .= "</td>";

			if ($pretty eq '') { $pretty = "<i>Unnamed Category [$safe]</i>"; }
			if (substr($safe,0,1) eq '$') { $pretty = '<b>LIST: '.$pretty.'</b>'; }
			elsif (substr($safe,0,1) eq '*') { $pretty = 'SYSTEM PAGE: '.$pretty; }
			$html .= "<td class=\"navcat_0\">$checked $pretty ($prodcount products)</td></tr>";
			$html .= "<tr><td></td><td><div id=\"$safe\"></div></td></tr>";
			}		
		}
	$html .= "</table>";

	if ($safe eq '.') { $html .= "</div>"; }
	return($html);
	}





1;
