package AJAX::PANELS;

use strict;

sub parselogin { my ($LOGIN) = @_; 	return(split(/\*/,$LOGIN,2)); }

##
## HANDLER:
##		'PRODEDIT',$PID,'edit.cgi'
##		'DOMAINEDIT','','index.cgi'
##		
sub header {
	my ($HANDLER,$PID,$APP) = @_;

	my $CSS = '/biz/standard.css';

	my $c = '';
	if ($HANDLER ne 'PRODEDIT') {
		$c = qq~
	<script type="text/javascript" src="/biz/ajax/jquery-1.6.4/jquery-1.6.4.min.js"></script>
	<link type="text/css" href="/biz/ajax/jquery-ui-1.8.16/css/smoothness/jquery-ui-1.8.16.custom.css" rel="stylesheet" />
	<script type="text/javascript" src="/biz/ajax/jquery-ui-1.8.16/js/jquery-ui-1.8.16.custom.min.js"></script>
		~; 
		}
	
	return(qq~
<link rel="STYLESHEET" type="text/css" href="$CSS">

<style type="text/css">
.lowOpacity {
   -moz-opacity: 0.80;
   opacity: 0.80;
   -ms-filter:"progid:DXImageTransform.Microsoft.Alpha"(Opacity=80);

	}

.loadx {
	background: url(//www.zoovy.com/biz/ajax/loading-3.gif) center center no-repeat;
	height: 32px;
	width: 32px;
	z-index:10000;
	position:absolute;
	}
</style>

<script type="text/javascript" src="/biz/ajax/zoovy-jquery.js"></script>
<script type="text/javascript" src="/biz/zoovy.js"></script>
<script type="text/javascript" src="/biz/ajax/select.js"></script>
<script type="text/javascript" src="/biz/ajax/navcat-20120207.js"></script>
<script type="text/javascript">
<!--

//
//
function changeState(panel) {
	var state = jQuery("#"+selectorEscapeExpression(panel+'!state'));
	var statehref = jQuery("#"+selectorEscapeExpression(panel+'!statehref'));
	var icon = jQuery("#"+selectorEscapeExpression(panel+"!stateicon"));
	var content = jQuery("#"+selectorEscapeExpression(panel+'!content')).css('position','relative');
	var pid = '$PID';


	// alert('changing state for: '+panel+' current state is: '+state.prop("value"));
	// alert(icon);
	// alert(icon.prop("src"));

	if ((icon.prop("src").indexOf("miniup")>0) && (state.prop("value") == '1')) {
		// cheap hack to detect when user pushes back button and browser resets panel to closed state. (ff/ie bug)
		// this is way confusing -- so see ticket: #173260
		state.prop("value",'0');
		}

	if (state.prop("value")=='0') {
		// currently closed
		icon.prop("src","/biz/ajax/navcat_icons/minidown.gif");
		state.prop("value",'1');
		statehref.prop("title",'Save and Close');
		content.html('Loading, please wait..');

		var postBody = 'm=$HANDLER/Load&_panel='+panel+'&_pid='+pid;
		jQuery.ajax('/biz/ajax/prototype.pl/$HANDLER/Load', 
			{ dataType:"text",data: postBody,async: 1,success: function(data, textStatus, jqXHR){ jHandleResponse(data);} } ) ;

		}	
	else {
		// currently open
		icon.prop("src","/biz/ajax/navcat_icons/miniup.gif");
		statehref.prop("title",'Display Panel');
		state.prop("value",'0');
		savePanel(null,panel,'Close');
		content.html('');
		}

	}


//
// subtype can be either Save or Close
//
function savePanel(mycaller,panel,subtype) {
	var pid = '$PID';

	frm = jQuery("#"+selectorEscapeExpression(panel+'!frm'));
	if (subtype == undefined) { subtype = 'Save'; }		// Normally we would call this $HANDLER/Save but sometimes it's $HANDLER/Close
	subtype = escape(subtype);
	var postBody = 'm=$HANDLER/'+subtype+'&_panel='+panel+'&_pid='+pid+'&'+frm.serialize();

//	alert(postBody);

	content = jQuery("#"+selectorEscapeExpression(panel+'!content'));
//	frm.css('visibility','hidden');	// hides the content doesn't collapse the space
//	frm.html('<center><img src="//www.zoovy.com/biz/images/header/loading-32x32.gif" height=32 widht=32 alt="Wait" /></center>');
//	frm.effect("pulsate", {}, 500);
//	frm.effect("highlight", {}, 100);
//	frm.showLoading();

	if (mycaller) {
		//gotta set position to relative on parent container prior to getting position of clicked element, 
		//or results of position() are for the window, not the container.
      content.css({'position':'relative','background':'#F3F681'}).addClass('lowOpacity');

		var wgcPosition = jQuery(mycaller).position();
		jQuery(":input",frm).attr('disabled','disabled');
		// console.log(" position to be set: "+Number(wgcPosition.top-40));
		var loader = jQuery("<div \/>").addClass('loadx').css({'top':(Number(wgcPosition.top-40))+"px",'left':(Number(wgcPosition.left-40))+"px"});
		content.append(loader);
		}

	// alert('saving panel: '+panel);
	

	jQuery.ajax({
		type:"POST",
		url:'/biz/ajax/prototype.pl/$HANDLER/'+subtype, 
		dataType:"text",
		data: postBody,
		async: 1,
		context:frm,
		success: function(data, textStatus, jqXHR){
			jHandleResponse(data); 
			} 
		}).complete(
			function(){ 
				jQuery(":input",frm).removeAttr('disabled');
				content.css('background-color','#ffffff').removeClass('lowOpacity');
				}
			);

	}


//
function doSubmit(panel,action,url) {
	if (url != undefined) { document.location = url; }
	else {
		jQuery('#VERB').val(action);
		jQuery("#"+selectorEscapeExpression(panel+'!frm')).attr("action",'$APP');
		jQuery("#"+selectorEscapeExpression(panel+'!frm')).submit();
		}

//	alert('running action: '+action);	
	}

//-->
</script>
	~);

	}

##
## parameters:
##	$panel (the panel name, this should correspond to $PRODUCT::PANELS::func)
##	$title - duh, the title of the panel
## $state = 0 (closed)
##				1 (open)
##				-1 (forced open)
##	$content = if the panel is open, this is the content which will appear in it when it is rendered.
##
##	each panel has the following sections/ids:
##		$panel!stateicon	(the icon of it being open or closed)
##		$panel!state		0/1 (hidden form variable -- mirrors the $state variable)
##		$panel!content		a div with content (or where content should go)
##		$panel!frm			a form which goes outside of the div (making it easy to serialize for updates)
##
sub render_panel {
	my ($panel,$title,$state,$content) = @_;

	my $stateicon = "//www.zoovy.com/biz/ajax/navcat_icons/miniup.gif";
	my $statetitle = 'Show';
	if ($state == 1) { $stateicon = "//www.zoovy.com/biz/ajax/navcat_icons/minidown.gif"; $statetitle = 'Save and Close'; }
	if ($state == -1) { $stateicon = "/images/blank.gif"; $statetitle = ''; }

	my $out = qq~
	<!-- panel: $panel -->
	<table cellpadding="5" cellspacing="0" width="100%" class="border_top border_right border_bottom border_left divider" style="margin: 0 0 4px 0;">
		<tr>
			<td class="bold">$title</td>
		</tr>
		<tr>
			<td bgcolor="#FFFFFF">
				<form style="margin: 0px; padding: 0px;" name="$panel!frm" id="$panel!frm" action="">
				<input type="hidden" id="$panel!state" name="$panel!state" value="$state">
				<div id="$panel!content">$content</div>
				</form>
			</td>
		</tr>
	</table>
	~;
	return($out);
	}


1;