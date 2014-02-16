package DOMAIN::PANELS;

use strict;
use lib "/backend/lib";
require DOMAIN::TOOLS;
require DOMAIN::REGISTER;
require PAGE;
require PROJECT;
use Data::Dumper;

%DOMAIN::PANELS::func = (
	'builder'=>\&panel_builder,
	'navcat'=>\&panel_navcat,
	);




sub panel_navcat {
	my ($LU,$PID,$VERB,$nsref,$formref, %options) = @_;

	if ($VERB eq 'SAVE') {
		return();
		}

	# my $IMAGE_CHOOSER_OKAY = 1;

	my $FLAGS = $LU->flags();
	my $USERNAME = $LU->username();
	my $LUSER = $LU->luser();
	# if ($FLAGS !~ /,WEB,/) { $IMAGE_CHOOSER_OKAY = 0; }

	my $c = '';
	my $flow = '';

	#my $URL = "http://$USERNAME.zoovy.com";
	#if ($LU->prt() > 0) {
	#	}
	my $URL = "http://".&DOMAIN::TOOLS::domain_for_prt($USERNAME,$LU->prt());

	require NAVCAT;
	my $NC = NAVCAT->new($USERNAME,PRT=>$LU->prt());
	my $counter = 0;
	my @paths = sort $NC->paths();

	my $catcount = scalar(@paths);
	my $pagesref = undef;
	if ($catcount>5000) {
		$c = "<tr><td colspan='4'><i>Too many categories ".scalar(@paths)." to display (5000 max)</i></td></tr>";
		@paths = ();
		}
	else {
		require PAGE::BATCH;
		($pagesref) = PAGE::BATCH::fetch_pages($USERNAME,PRT=>$LU->prt(),quick=>1);
		}
		

	foreach my $safe (@paths) {
		$counter++;
		my ($lastedit,$since) = (0,'');
		my $ts = time();
		if ((defined $pagesref) && (defined $pagesref->{$safe})) {
			$lastedit = $pagesref->{$safe}->{'modified_gmt'};
			$since = &ZTOOLKIT::pretty_time_since($lastedit,$ts);
			}
		else {
			## more than 5000 categories doesn't show last edit time. (but is MUCH faster)
			$since = 'N/A';
			$lastedit = -1;
			}

		my $name = $NC->pretty_path($safe);

		# strip the leading period
		my $url = substr($safe,1);

		# at this point $url is setup with the GET safe version (standard decoding like on website)
		my ($PRETTY,$CHILDREN,$PRODUCTS,$SORTSTYLE,$metaref) = $NC->get($safe);
		if (not defined $metaref) { $metaref = {}; }

		if (substr($safe,0,1) eq '*') {
			# hidden page
			}
		elsif (substr($safe,0,1) eq '$') {
			}
		elsif ($safe ne '.') {
			$c .= "<tr><td class='cell'>";
	
			## Image Thumbnail
			my $img = '';
#			if ($IMAGE_CHOOSER_OKAY) {
			$img = $metaref->{'CAT_THUMB'};
#			$c .= "<a href=\"#\" onClick=\"openWindow('/biz/setup/media/popup.cgi?mode=navcat&img=$img&safe=$safe&thumb=img$counter'); return false;\">";
			$c .= "<a href=\"#\" onClick=\"mediaLibrary(jQuery('#img$counter'),'mode=navcat&img=$img&safe=$safe&thumb=img$counter','Category Thumbnail'); return false;\">";
#				}
#			else {
#				$c .= "<a href=\"#\" onClick=\"openWindow('/biz/vstore/builder/noaccess.shtml');\">";
#				}

			if (not defined $img) { 
				$img = '/biz/setup/images/camera_small.gif'; 
				} 
			elsif ($img eq '') {
				$img = '/biz/setup/images/camera_small.gif';
				}
			else {
				$img = &ZOOVY::mediahost_imageurl($USERNAME,$img,21,26,'FFFFFF',undef);
				}
			$c .= " <img border=0 id=\"img$counter\" name=\"img$counter\" width=26 height=21 src=\"$img\"></a>";
			## 

			$c .= " $name</td>";
			if ($lastedit == 0) {
				$c .= qq~<td class='cell'><button class="minibutton" onClick="navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&PG=$safe&FS=C'); return false;">Edit</button> &nbsp; ~;
				} 
			else {
				#$flow = $metaref->{'FLOW'};
				#if ($flow eq '') {
				#	## backward compatibility when flows used to be stored in page files.
				#	my $PG = PAGE->new($USERNAME,$safe,NS=>'');
				#	($flow) = $PG->get('FL');
				#	undef $PG;
				#	}
	
				$c .= qq~<td class='cell'><button class="minibutton" onClick="navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&PG=$safe&FS=C'); return false;">Edit</button> &nbsp; ~;
				$c .= "</td>";		
				}
			# $c .= qq~<td class='cell'><button class="minibutton" onClick="linkOffSite('http://www.zoovy.com/biz/preview.cgi?url=$URL/category/$url'); return false;">Preview</button></td>~;
			$c .= "<td class='cell'>$since</td></tr>\n";
			$c .= "<tr><td colspan='4'><div id=\"~$safe\"></div></td></tr>";

			}
		}




	return qq~
<table width=100%>
<tr><td class='cell' colspan='4'><br></td></tr>
<tr>
	<td class='zoovytableheader' bgcolor='3366CC' align='left'>Product Categories</td>
	<td class='zoovytableheader' bgcolor='3366CC' align='left'>Actions</td>
	<td class='zoovytableheader' bgcolor='3366CC' align='left'>Preview</td>
	<td class='zoovytableheader' bgcolor='3366CC' align='left'>Last Edit</td>
</tr>
<tr>
	<td class='cell' colspan='4'><a href='/biz/setup/navcats/index.cgi?EXIT=/biz/vstore/builder'>Add/Rename/Remove Categories &amp; Lists</a></td>
</tr>
$c
~;

	
	}


##
##
##
sub panel_builder {
	my ($LU,$PID,$VERB,$D,$formref) = @_;

	if ($VERB eq 'SAVE') {
		return();
		}

	my $USERNAME = $LU->username();
	my $LUSERNAME = $LU->luser();
	my $PRT = $LU->prt();
	my $FLAGS = $LU->flags();

	my $PANEL = 'BUILDER:'.$D->domainname();
	my $out = '';

	## my (@domains) = DOMAIN::TOOLS::domains($USERNAME,PROFILE=>$NS,PRT=>$PRT);
	my $WRAPPERS = '';
	## my $ref = &ZOOVY::fetchmerchantns_ref($USERNAME,$NS);
	my ($nsref) = $D->as_legacy_nsref();

	require ZWEBSITE;
	my $mapped_domain_count = 0;
	my @VSTORE_PREVIEWS = ();

	if ($D) {
		my ($dname) = $D->domainname();
		$mapped_domain_count++;
		foreach my $APPWWWM ('APP','WWW','M') {
			my $HOST_TYPE = $D->{"$APPWWWM\_HOST_TYPE"};
			if ($HOST_TYPE eq '') { $HOST_TYPE = '_NOT_CONFIGURED_'; }
			my %CONFIG = &ZTOOLKIT::parseparams($D->{"$APPWWWM\_CONFIG"});
			if ($HOST_TYPE eq 'APP') {
				$WRAPPERS .= qq~
				<tr>
					<td class='cell'>$APPWWWM.$dname</td>
					<td colspan=3 class='cell'>is APP $CONFIG{'PROJECT'}</td>
				</tr>~;
				}
			elsif ($HOST_TYPE eq 'VSTORE') {
				$WRAPPERS .= qq~
				<tr>
					<td class='cell'>$APPWWWM.$dname</td>
					<td colspan=3 class='cell'>uses legacy website builder (below)</td>
				</tr>~;
				push @VSTORE_PREVIEWS, lc("$APPWWWM.$dname");
				}
			elsif ($HOST_TYPE eq 'REDIR') {
				$WRAPPERS .= qq~
				<tr>
					<td class='cell'>$APPWWWM.$dname</td>
					<td colspan=3 class='cell'>redirects to: http://$CONFIG{'REDIR'}/$CONFIG{'URI'}</td>
				</tr>~;
				}
			else {
				$WRAPPERS .= qq~
				<tr>
					<td class='cell'>$APPWWWM.$dname</td>
					<td colspan=3 class='cell'>is type $HOST_TYPE</td>
				</tr>~;
				}
			}
		}	


	$out = '';
	my $wrapper = $nsref->{'zoovy:site_wrapper'};
	if ($wrapper eq '') { $wrapper = '&lt; NOT SET &gt;'; }

	my $pop_wrapper = $nsref->{'zoovy:popup_wrapper'};
	if ($pop_wrapper eq '') { $pop_wrapper = 'DEFAULT: '.&ZWEBSITE::fetch_website_attrib($USERNAME,'sitewrapper_n'); }
	if ($pop_wrapper eq '') { $pop_wrapper = 'DEFAULT: Not Set'; }

	my $mobile_wrapper = $nsref->{'zoovy:mobile_wrapper'};
	if ($mobile_wrapper eq '') { $mobile_wrapper = 'm09_moby'; }


	## my $email = &ZOOVY::fetchmerchantns_attrib($USERNAME,$NS,'email:docid');
	my $email = $nsref->{'email:docid'};
	if ($email eq '') { $email = 'Not Set'; }

	##my $prt = &ZOOVY::fetchmerchantns_attrib($USERNAME,$NS,'prt:id');
	##my $prtinfo = '';
	##if ($prt>0) {
	##	$prtinfo = "<tr><td>Partition:</td><td>$prt</td></tr>";
	##	}

	my $DOMAINNAME = $D->domainname();
	$out .= qq~
<table width=100%>
<tr>
	<td>Company Information</td>
	<td><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=COMPANYEDIT&DOMAIN=$DOMAINNAME');">[Edit]</a></td>
</tr>
<tr>
	<td>Email Messages</td>
	<td>
		<a href="#" onClick="return navigateTo('/biz/vstore/builder/emails/index.cgi?VERB=EDIT&DOMAIN=$DOMAINNAME');">[Edit]</a>
		<a href="#" onClick="return navigateTo('/biz/vstore/builder/themes/index.cgi?DOMAIN=$DOMAINNAME&SUBTYPE=E');">[Select]</a>
	</td>
	<td>$email</td>
</tr>

<tr>
	<td>WWW Site Theme</td>
	<td>
		~.
		(($wrapper eq '')?'':qq~<a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&DOMAIN=$DOMAINNAME&FS=!&FORMAT=WRAPPER&FL=$wrapper');">[Edit]</a>~).
		qq~
		<a href="#" onClick="return navigateTo('/biz/vstore/builder/themes/index.cgi?DOMAIN=$DOMAINNAME');">[Select]</a> 
		<a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=DECALS&DOMAIN=$DOMAINNAME');">[Decals]</a>
	</td>
	<td>$wrapper</td>
</tr>
~;


	$out .= qq~
<tr>
	<td>Mobile Site Theme</td>
	<td>
		~.
		(($wrapper eq '')?'':qq~<a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&DOMAIN=$DOMAINNAME&FS=!&FORMAT=WRAPPER&FL=$mobile_wrapper');">[Edit]</a>~).
		qq~
		<a href="#" onClick="return navigateTo('/biz/vstore/builder/themes/index.cgi?DOMAIN=$DOMAINNAME&SUBTYPE=M');">[Select]</a> 
	</td>
 	<td>$mobile_wrapper</td>
</tr>
</table>
<br>
	~;



	$out .= qq~
<center>
<table width="100%" class="zoovytable">
<tr>
	<td colspan=4 class='zoovytableheader' >Associated Domains</td>
</tr>
<tr>
$WRAPPERS
	~;


#	use Data::Dumper;
#	$out .= Dumper({'DOMAINS'=>\@domains,'PROFILE'=>$NS,'PRT'=>$PRT});

	if ($mapped_domain_count>1) {
		## if we have more than one domain, be sure to mention changes in one wrapper can overwrite another.
		$out .= qq~
<tr>
	<td colspan='4'>
<div class="error">
Two or more domains share the same profile.<br>
Changes in one wrapper will effect the other. In addition having duplicate domains with identical content will cause
duplicate content/SEO issues. This is NOT a recommended or supported configuration. Please reconfigure 
so there is only one associated domain per profile (use as many redirects as necessary).</div><br>
	</td>
</tr>
	~;
		}


## lets download the last modified page times.
my %LASTEDIT = ();
my ($PROFILE) = $D->profile();
my ($pageinfo) = &PAGE::page_info($USERNAME,$PROFILE,[
	'homepage','aboutus','cart','contactus','gallery','login','privacy','results','return','search'
	]);
foreach my $pg (@{$pageinfo}) {
	$LASTEDIT{uc($pg->{'safe'})} = &ZTOOLKIT::pretty_time_since($pg->{'modified'});
	}




$out .= qq~
<tr>
	<td valign=top class='zoovytableheader' align='left' width='200'>Profile Pages</td>
	<td valign=top class='zoovytableheader' align='left'>Actions</td>
	<td valign=top class='zoovytableheader' align='left'>Preview</td>
	<td valign=top class='zoovytableheader' align='left'>Last Edit</td>
</tr>
<tr>
	<td valign=top class='cell' >Homepage</td>
	<td valign=top class='cell' >
		<a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=.&FS=H');">[Edit]</a>
		&nbsp;
	<a href="#" onClick="adminApp.ext.admin.a.showFinderInModal('NAVCAT','.'); return false;">[Products]</a>
	</td>
	<td valign=top class='cell' >
	~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain');">[$preview_domain]<br></a>~;
		}
$out .= qq~
	</td>
	<td valign=top class='cell' >$LASTEDIT{'HOMEPAGE'}</td>
</tr>
<tr>
	<td valign=top class='cell' >About Us</td>
	<td valign=top class='cell' ><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=aboutus&FS=A');">[Edit]</a></td> 
	<td valign=top class='cell' >~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain/company_info.cgis');">[$preview_domain]<br></a>~;
		}

$out .= qq~
	</td>
	<Td>$LASTEDIT{'ABOUTUS'}</td>
</tr>
<tr>
	<td valign=top class='cell' >Contact Us</td>
	<td valign=top class='cell' ><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=contactus&FS=U');">[Edit]</a></td>
	<td valign=top class='cell' >~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain/contact_us.cgis');">[$preview_domain]<br></a>~;
		}


$out .= qq~
	</td>
	<td valign=top>$LASTEDIT{'CONTACTUS'}</td>
</tr>
<tr>
	<td valign=top class='cell' >Privacy Policy</td>
	<td valign=top class='cell' ><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=privacy&FS=Y');">[Edit]</a></td>
	<td valign=top class='cell' >~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain/privacy.cgis');">[$preview_domain]<br></a>~;
		}


$out .= qq~
	</td>
	<td valign=top class='cell' >$LASTEDIT{'PRIVACY'}</td>
</tr>
<tr>
	<td valign=top class='cell' >Return Policy</td>
	<td valign=top class='cell' ><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=return&FS=R');">[Edit]</a></td>
	<td valign=top class='cell' >~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain/returns.cgis');">[$preview_domain]<br></a>~;
		}



$out .= qq~
	</td>
	<td valign=top class='cell' >$LASTEDIT{'RETURN'}</td>
</tr>
<tr>
	<td valign=top class='cell' >Shopping Cart Page</td>
	<td valign=top class='cell' >
		<a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=%2Acart&FS=T');">[Edit]</a>
		&nbsp;
	<!--
	<a onClick="adminApp.ext.admin.a.showFinderInModal('NAVCAT','\$shoppingcart'); return false;" href="#">[Products]</a>
	-->
	</td>
	<td valign=top class='cell' >
		~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain/cart.cgis');">[$preview_domain]<br></a>~;
		}
$out .= qq~
	</td>
	<td valign=top class='cell' >$LASTEDIT{'CART'}</td>
</tr>
~;


#if ($LU->is_level(4)) {
if (1) {
	$out .= qq~
<tr><td valign=top colspan='4'><div id="\~*cart"></div></td></tr>
<tr>
	<td valign=top class='zoovytableheader' align='left' width='200'>Optional Pages</td>
	<td valign=top class='zoovytableheader' align='left'>Actions</td>
	<td valign=top class='zoovytableheader' align='left'>Preview</td>
	<td valign=top class='zoovytableheader' align='left'>Last Edit</td>
</tr>
<tr>
	<td valign=top class='cell' >Search Page</td>
	<td valign=top class='cell' ><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=search&FS=S');">[Edit]</a></td>
	<td valign=top class='cell' >~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain/search.cgis');">[$preview_domain]<br></a>~;
		}
$out .= qq~
	</td>
	<td valign=top class='cell' >$LASTEDIT{'SEARCH'}</td>
</tr>
<tr>
	<td valign=top class='cell' >Search Results Page</td>
	<td valign=top class='cell' ><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=results&FS=E');">[Edit]</a></td>
	<td valign=top class='cell' >&nbsp;</td>
	<td valign=top class='cell' >$LASTEDIT{'RESULTS'}</td>
</tr>
<tr>
	<td valign=top class='cell' >Customer Login Page</td>
	<td valign=top class='cell' ><a href="#" onClick="return navigateTo('/biz/vstore/builder/index.cgi?ACTION=INITEDIT&FORMAT=PAGE&DOMAIN=$DOMAINNAME&PG=login&FS=L');">[Edit]</a></td>
	<td valign=top class='cell' >~;
	foreach my $preview_domain (@VSTORE_PREVIEWS) {
		$out .= qq~<a href="#" onClick="return linkOffSite('http://$preview_domain/login.cgis');">[$preview_domain]<br></a>~;
		}
$out .= qq~
	</td>
	<td valign=top class='cell' >$LASTEDIT{'LOGIN'}</td>
</tr>
~;
	}

	$out .= "</table>";

	return($out);
	}




sub panel_domain {
   my ($LU,$VERB,$d,$formref) = @_;

	return(qq~<font color='red'>Please use a more recent version of this app.</font>~);
	}


1;