package SUPPLIER::GENERIC;

use strict;

use LWP::Simple;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP::UserAgent;
use LWP::Simple;
use Text::CSV_XS;
use MIME::Entity;

use lib "/backend/lib";
require LISTING::MSGS;
require SUPPLIER;
require DBINFO;
require ZOOVY;
require ZTOOLKIT;


##
## dispatch GENERIC order
## (done)
#sub dispatch_order {
#	my ($S,$SO2) = @_;
#
#	## what do we do now?
#	my @EVENTS = ();		# order events
#	my $ERROR = '';
#	my $WARNING = '';
#	my $disposition = 'inline';
#	my $RECIPIENT = $S->fetch_property('.order.email');
#	my $IS_FAX = ($S->fetch_property('.order.type')==2)?1:0;
#	my $PROFILE = $S->fetch_property('PROFILE');
#	my ($BCC) = $S->fetch_property('.order.bcc');
#	## only added for testing
#	#if ($BCC eq '') { $BCC = "patti\@zoovy.com"; }
#	#else { $BCC .= ",patti\@zoovy.com"; }
#
#	## get source email from the DEFAULT PROFILE
#	my $FROM = ZOOVY::fetchmerchantns_attrib($S->username(),$S->profile(),,"zoovy:support_email");
#	
#	## find appropriate domain for this Profile
#	use DOMAIN::TOOLS;
#	my $domain = &DOMAIN::TOOLS::syndication_domain($S->username(),$S->profile());	
#
#	## build SUBS vars
#	## '%REFNUM%', '%DATE%', '%PAYINFO%', '%WEBSITE%'
#	my %SUBS = (
#		'%REFNUM%'=> $SO2->in_get('our/supplier_orderid'),
#		'%ORDERID%'=> $SO2->in_get('our/supplier_orderid'),
#		'%DATE%'=>	&ZTOOLKIT::pretty_date( $SO2->in_get('our/created') ),
#		'%PAYINFO%'=> '', # waiting for patti!',
#		'%WEBSITE%'=>'http://'.$domain,
#		'%SHIPMETHOD%'=>($SO2->in_get('this/shp_method') eq '')?'Standard':$SO2->in_get('this/shp_method'),
#		);
#
#	## build SUBS vars
#	## '%HTMLBILLADDR','%HTMLSHIPADDR', '%TXTBILLADDR', '%TXTSHIPADDR', '%XMLBILLADDR', '%XMLSHIPADDR'
#	## ship and bill address info for each type (txt, html, xml)
#	foreach my $type ('ship','bill') {
#		my ($xml,$html,$txt) = ('','',''); 
#
#		## NAME
#		if ($SO2->in_get(sprintf("%s/%s",$type,'firstname'))) { 
#			$txt .= $SO2->in_get(sprintf("%s/%s",$type,'firstname'))." ".$SO2->in_get(sprintf("%s/%s",$type,'lastname'))."\n";
#			$html .= $SO2->in_get(sprintf("%s/%s",$type,'firstname'))." ".$SO2->in_get(sprintf("%s/%s",$type,'lastname'))."<br>"; 
#			$xml .= '<firstname>'.$SO2->in_get(sprintf("%s/%s",$type,'firstname')).'</firstname><lastname>'.$SO2->in_get(sprintf("%s/%s",$type,'lastname')).'</lastname>';
#			}
#
#		## COMPANY
#		if ($SO2->in_get(sprintf("%s/%s",$type,'company'))) { 
#			$txt .= $SO2->in_get(sprintf("%s/%s",$type,'company'))."\n";
#			$html .= $SO2->in_get(sprintf("%s/%s",$type,'company'))."<br>"; 
#			$xml .= '<company>'.$SO2->in_get(sprintf("%s/%s",$type,'company')).'</company>';
#			}
#		
#		## ADDRESS
#		if ($SO2->in_get(sprintf("%s/%s",$type,'address1')) ne '') {
#			$html .= $SO2->in_get(sprintf("%s/%s",$type,'address1'))."<br>".(($SO2->in_get(sprintf("%s/%s",$type,'address2')) ne '')?$SO2->in_get(sprintf("%s/%s",$type,'address2')).'<br>':'');
#			$txt .= $SO2->in_get(sprintf("%s/%s",$type,'address1'))."\n".(($SO2->in_get(sprintf("%s/%s",$type,'address2')) ne '')?$SO2->in_get(sprintf("%s/%s",$type,'address2'))."\n":'');
#			$xml .= '<addr1>'.$SO2->in_get(sprintf("%s/%s",$type,'address1'))."</addr1>".(($SO2->in_get(sprintf("%s/%s",$type,'address2')) ne '')?'<addr2>'.$SO2->in_get(sprintf("%s/%s",$type,'address2')).'</addr2>':'');
#			} 
#
#		## CITY, STATE, PROVINCE, COUNTRY, ZIP
#		if (($SO2->in_get(sprintf("%s/%s",$type,'city')) eq '') && ($SO2->in_get(sprintf("%s/%s",$type,'state')) eq '')) {
#			## no city/state
#			}
#		elsif (defined $SO2->in_get(sprintf("%s/%s",$type,'int_zip')) && $SO2->in_get(sprintf("%s/%s",$type,'int_zip')) ne '') {
#			$html .= $SO2->in_get(sprintf("%s/%s",$type,'city')).', '.$SO2->in_get(sprintf("%s/%s",$type,'province')).', '.$SO2->in_get(sprintf("%s/%s",$type,'int_zip'))." ".$SO2->in_get(sprintf("%s/%s",$type,'countrycode'))."<br>\n"; 
#			$txt .= $SO2->in_get(sprintf("%s/%s",$type,'city')).', '.$SO2->in_get(sprintf("%s/%s",$type,'province')).', '.$SO2->in_get(sprintf("%s/%s",$type,'int_zip'))." ".$SO2->in_get(sprintf("%s/%s",$type,'countrycode'))."\n"; 
#			$xml .= '<city>'.$SO2->in_get(sprintf("%s/%s",$type,'city')).'</city><province>'.$SO2->in_get(sprintf("%s/%s",$type,'province')).'</province><int_zip>'.$SO2->in_get(sprintf("%s/%s",$type,'int_zip'))." ".$SO2->in_get(sprintf("%s/%s",$type,'countrycode'))."</int_zip>"; 
#			}
#		else {
#			$html .= $SO2->in_get(sprintf("%s/%s",$type,'city')).', '.$SO2->in_get(sprintf("%s/%s",$type,'state')).'. '.$SO2->in_get(sprintf("%s/%s",$type,'zip'))."<br>\n";
#			$txt .= $SO2->in_get(sprintf("%s/%s",$type,'city')).', '.$SO2->in_get(sprintf("%s/%s",$type,'state')).'. '.$SO2->in_get(sprintf("%s/%s",$type,'zip'))."\n";
#			$xml .= '<city>'.$SO2->in_get(sprintf("%s/%s",$type,'city')).'</city><state>'.$SO2->in_get(sprintf("%s/%s",$type,'state')).'</state><zip>'.$SO2->in_get(sprintf("%s/%s",$type,'zip'))."</zip>\n";
#			}
#	
#		## PHONE
#		$html .= ($SO2->in_get(sprintf("%s/%s",$type,'phone')) ne '')?"Phone: ".$SO2->in_get(sprintf("%s/%s",$type,'phone'))."<br>":'';
#		$txt .= ($SO2->in_get(sprintf("%s/%s",$type,'phone')) ne '')?"Phone: ".$SO2->in_get(sprintf("%s/%s",$type,'phone'))."\n":'';
#		$xml .= ($SO2->in_get(sprintf("%s/%s",$type,'phone')) ne '')?"<phone>".$SO2->in_get(sprintf("%s/%s",$type,'phone'))."</phone>":'';
#
#		## assign contact to variables below
#		## '%HTMLBILLADDR','%HTMLSHIPADDR', '%TXTBILLADDR', '%TXTSHIPADDR', '%XMLBILLADDR', '%XMLSHIPADDR'
#		$SUBS{'%TXT'.uc($type).'ADDR%'} = $txt;
#		$SUBS{'%HTML'.uc($type).'ADDR%'} = $html;
#		$SUBS{'%XML'.uc($type).'ADDR%'} = $xml;
#		}
#
#	## build SUBS vars
#	## '%HTMLCONTENTS%', '%XMLCONTENTS%', '%TXTCONTENTS%'
#
#	## this setting can be toggled in the UI
#	##		some merchants do not want the cost shown to their Supplier
#	my ($show_cost) = int($S->fetch_property('.order.field_cost'));
#	## this setting was added for ibuystores and is currently can only be changed on the backend
#	##		do not show items where the qty is zero, this would happen if the merchant edit the order
#	my ($dont_show_zero_qtys) = int($S->fetch_property('.order.dont_show_zero_qtys'));
#		
#
#	my ($xml,$html,$txt) = ('','',''); 
#	$txt .= sprintf("%s \t%4s \t%s\t%s",'SKU','QTY','DESC','COST');
#	$html .= "<table cellpadding='2' cellspacing='1' width='100%' bgcolor='#CCCCCC'>\n";
#	$html .= "<tr>\n";
#	$html .= "<td bgcolor='#FFFFFF'><b>SKU</b></td>\n";
#	$html .= "<td width=60 bgcolor='#ffffff' align='center'><b>QTY</b></td>\n";
#	$html .= "<td bgcolor='#ffffff'><b>DESCRIPTION</b></td>\n";
#	$html .= "<td bgcolor='#ffffff'><b>COST</b></td>\n";
#	$html .= "<td bgcolor='#ffffff'><b>EXTENDED</b></td>\n";
#	$html .= "</tr>\n";
# 
#	my $total_items = 0;
#	foreach my $item (@{$SO2->stuff2()->items()}) {
#		my $sku = $item->{'sku'};
#		my $qty = $item->{'qty'};
#		my $desc = $item->{'prod_name'};
#		
#		if ($dont_show_zero_qtys && int($qty) == 0) {
#			## go to the next item
#			print STDERR "dont_show_zero_qtys -- SKU: $sku QTY: $qty\n";
#			}
#		else {
#			$total_items++;
#			## get the SKU product name if its an ebay item
#			#if ($desc =~ /ebay:/) {
#			#	my $new_desc = &ZOOVY::fetchproduct_attrib($USERNAME,$sku,'zoovy:prod_name');
#			#	if ($new_desc ne '') { $desc = $new_desc; }
#			#	}
#
#			my $cost = $item->{'COST'};
#			my $extended = sprintf("%.2f",($cost*$qty));
#
#			if (not $show_cost) { 
#				$cost = '-'; 
#				$extended = '-'; 
#				}
#			$txt .= "\n".sprintf("%s \t%4d \t%s\t%2.f\t%2.f\n",$sku,$qty,$desc,$cost,$extended);
#			
#			$html .= "<tr>\n";
#			$html .= "<td bgcolor='#ffffff'>$sku</td>\n";
#			$html .= "<td bgcolor='#ffffff' align='center'>$qty</td>\n";
#			$html .= "<td bgcolor='#ffffff'>$desc</td>\n";
#			$html .= "<td bgcolor='#ffffff' align='center'>$cost</td>\n";
#			$html .= "<td bgcolor='#ffffff' align='center'>$extended</td>\n";
#			$html .= "</tr>\n";
#			
#			$xml .= "<sku>$sku</sku>\n";
#			$xml .= "<qty>$qty</qty>\n";
#			$xml .= "<desc>$desc</desc>\n";
#			if ($show_cost) { $xml .= "<cost>$cost</cost>\n"; }
#			}
#		}
#	$html .= "</table>";
#	$SUBS{'%HTMLCONTENTS%'} = $html;
#	$SUBS{'%XMLCONTENTS%'} = $xml;
#	$SUBS{'%TXTCONTENTS%'} = $txt;
#
#	my $USERNAME = $S->username();
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#	my $udbh = &DBINFO::db_user_connect($USERNAME);
#
#	## SEND VIA EFAX
#	if ($IS_FAX) {
#		$FROM = 'efax@zoovy.com'; 
#		$RECIPIENT = $S->fetch_property('.order.fax');
#		$RECIPIENT =~ s/[^\d]+//gs;
#		$RECIPIENT =~ s/^[01]+//gs;	# strip leading 01
#		$RECIPIENT = '1'.$RECIPIENT.'@efaxsend.com';
#
#		my $zdbh = &DBINFO::db_zoovy_connect();
#		&DBINFO::insert($zdbh,"BS_TRANSACTIONS", {
#			USERNAME=>$USERNAME,
#			MID=>$MID,
#			AMOUNT=>0.10,
#			CREATED=>&ZTOOLKIT::mysql_from_unixtime(time()),
#			BILLGROUP=>'OTHER',
#			MESSAGE=>"Fax to supplier for order ". $SO2->in_get('our/supplier_orderid'),
#			BILLCLASS=>"BILL",
#			BUNDLE=>"FAX",
#			NO_COMMISSION=>1, }, debug=>1);
#		&DBINFO::db_zoovy_close();
#
#		$disposition = 'attachment';
#		}
#
#	## this error may occur if 'dont_show_zero_qtys' is set, and no items are in the order
#	if ($total_items == 0) {
#		$WARNING = "Order: ".$SO2->in_get('our/supplier_orderid')." will not be dispatched to Supplier, no items found.\n";
#		}
#	if ($RECIPIENT eq '') {
#		$ERROR = "Recipient Email not found for Supplier: ".$S->fetch_property('CODE'). " unable to send order";
#		}
#	## return error if Source Email not found
#	if ($FROM eq '') { 
#		$ERROR = "Source Email not found for Supplier: ".$S->fetch_property('CODE'). " unable to send order";
#		}
#
#	my ($bodypart) = ();
#	## build SUBS vars
#	if ($ERROR eq '' && $WARNING eq '') {
#		$SUBS{'%TITLE%'} = $S->fetch_property('.order.title');
#		$SUBS{'%ADDITIONAL_TEXT%'} = $S->fetch_property('.order.body');
#
#		## ORDER NOTES (optional)
#		if ($S->fetch_property('.order.notes') == 1 && $SO2->in_get('want/order_notes') ne '') {
#			$SUBS{'%TXT_ORDER_NOTES%'} = "\n\nAdditional Notes:\n".$SO2->in_get('want/order_notes')."\n";
#			$SUBS{'%HTML_ORDER_NOTES%'} = "<p><p><b>Additional Notes:</b><br>".$SO2->in_get('want/order_notes');
#			$SUBS{'%XML_ORDER_NOTES%'} = "<additional_notes>".$SO2->in_get('want/order_notes')."</additional_notes>";
#			}
#		else {
#			$SUBS{'%TXT_ORDER_NOTES%'} = "";
#			$SUBS{'%HTML_ORDER_NOTES%'} = "";
#			$SUBS{'%XML_ORDER_NOTES%'} = "";
#			}
#
#		## determine what format to send email
#		my ($MSGID) = $S->fetch_property('.order.msgid'); ## txt,html,xml
#		if ($MSGID eq '') { 
#			## LEGACY ORDER FORMAT FIELD
#			$MSGID = $S->fetch_property('.order.attach'); 
#			if ($MSGID eq '1') { $MSGID = 'SCHTML';  }
#			elsif ($MSGID eq '2') { $MSGID = 'SCTXT'; }
#			elsif ($MSGID eq '3') { $MSGID = 'SCXML';  }
#			}
#	
#		require SITE;
#		my ($SITE) = SITE->new($USERNAME,'PROFILE'=>$S->fetch_property('PROFILE'), 'PRT'=>&ZOOVY::profile_to_prt($USERNAME,$S->fetch_property('PROFILE')));
#
#		require SITE::EMAILS;
#		my ($se) = SITE::EMAILS->new($USERNAME,'*SITE'=>$SITE);
#		my ($ERRCODE) = (0);
#
#		if (not $ERRCODE) {
#			## first we build the body
#			($ERRCODE,$bodypart) = $se->createMsg($MSGID,'*CART2'=>$SO2,'*SITE'=>$SITE,TO=>$RECIPIENT,MACROS=>\%SUBS,MSGSUBJECT=>$S->fetch_property('.order.subject'),DOCID=>'blank',SUPPLIER=>$S,SRC=>'SUPPLYCHAIN');		
#			}
#		if ($ERRCODE>0) { 
#			## test for errors!
#			$ERROR = $SITE::EMAILS::ERRORS{$ERRCODE}; 
#			}
#		}
#
#	if ($ERROR ne '' || $WARNING ne '') {
#		my $MSG = $ERROR ." ". $WARNING;
#		require TODO;
#		my ($t) = TODO->new($USERNAME,writeonly=>1);
#		if (defined $t) {
#			$t->add(class=>"ERROR",title=>"Supply Chain/".$S->id()." error: $MSG");
#			}
#		}
#
#	print STDERR "Sending email from $FROM to $RECIPIENT\n";
#
#	if ($ERROR eq '' && $WARNING eq '') {
#		my $mime = lc('text/'.$bodypart->{'FORMAT'});
#		if ($mime eq 'text/txt') { $mime = 'text/plain'; }	
#		if ($mime eq 'text/text') { $mime = 'text/plain'; }	
#
#		if ($IS_FAX) {
#			## remove cover page
#			$bodypart->{'BODY'} = "{nocoverpage}{showbodytext}\n".$bodypart->{'BODY'};
#			}
#	
#		### Create a new multipart message
#		use MIME::Lite;
#		my $msg = MIME::Lite->new(
#			'X-Mailer'=>"Zoovy-SupplyChain/2.0 [$USERNAME:".($S->id())."]",
#			From=>$FROM,
#			'Reply-To'=>$FROM,
#	  	   To=>$RECIPIENT,
#			Bcc=>$BCC,
#			Type=>$mime,
#			Subject=>$bodypart->{'SUBJECT'},
#			Data=>$bodypart->{'BODY'},
#			Disposition=>'inline',
#	  	   );
#
#		if ($IS_FAX) {
#			$msg->send("sendmail", "/usr/sbin/sendmail -r efax\@zoovy.com -t");
#			}
#		else {
#			$msg->send("sendmail", "/usr/sbin/sendmail -t");
#			}
#
#	   ### Format as a string:
#		# print $msg->as_string;
#		}
#
#		
#	&DBINFO::db_user_close();
#	return($ERROR);	
#	}



##
## Returns a price for a supplier + CARTID
##		returns UNDEF on critical error! (price to be determined)
## 
## (done)
#sub compute_shipping {
#	my ($CART2,$S,$GROUPCODE) = @_;
#	
#	if (not defined $S) {
#		warn "WTF? you need to pass $S to have us compute shipping\n";
#		}
#
#	#if (not defined $S) {
#	#	## NOTE: $s should only be set when we call ourselves recursively.
#	#	($S) = SUPPLIER->new($USERNAME,$SUPPLIERCODE);
#	#	}
#
#	## merchant has since deleted the Supplier but not the product's association
#	## with the Supplier (ie zoovy:virtual, zoovy:prod_supplier, zoovy:prod_supplierid)
#	if (not defined $S) { return(undef); }
#
#	## *** NEEDS LOVE ***
#
#	if (($S->fetch_property('.ship.options')&1)==1) {
#		&ZOOVY::confess($CART2->username(),"MULTIBOX SHIPPING WAS ENABLED, BUT NO LONGER SUPPORTED",justkidding=>1);
#		}
#
#	#	## MULTIBOX OPTION
#	#	my $SHIPTOTAL = 0;
#	#	$S->save_property('.ship.options',0);		# turn off multibox shipping.
#
#	#	foreach my $item (@{$CART2->stuff2()->items('virtual'=>$GROUPCODE)}) {
#	#		next if (not defined $SHIPTOTAL); 			# an error occurred on a previous box!
#	#		## step 1:  backup quantity
#	#		my $qty = $item->{'qty'};
#	#		$item->{'qty'} = 1;
#
#	#		## step 2: create new stuff object, copy in product, set new stuff in CART
#	#		my ($TMPSTUFF) = STUFF->new($USERNAME);
#	#		$TMPSTUFF->{$stid} = $ORIGSTUFF->{$stid};
#	#		$CART2->stuff2() = $TMPSTUFF;
#	#		my ($price) = &SUPPLIER::GENERIC::compute_shipping($USERNAME,$SUPPLIERCODE,$CART2,$S);
#	#		if (not defined $price) { 
#	#			## ERROR!
#	#			$SHIPTOTAL = undef; 
#	#			}
#	#		else {
#	#			$SHIPTOTAL += ($price*$qty); 
#	#			}
#	#		$item->{'qty'} = $qty;
#	#		}
#	#	$CART->stuff() = $ORIGSTUFF;
#	#	$CART->totals();
#	#	## SHIPTOTAL will either be a dollar amount, or undef if an error occurred.
#	#	return($SHIPTOTAL);
#	#	}
#
#	my $total = 0;
#	my $SHIPMETHODS = $S->fetch_property('.ship.methods');
#	
#	##
#	##	Fixed Shipping!
#	##
#	if ((defined $total) && (($SHIPMETHODS&1)==1)) {
#		## (1) Fixed Shipping		
#		require ZSHIP::FLEX;
#		my $price = 0;
#
#		## USA
#		if ($CART2->in_get('ship/countrycode') eq '') {
#			$price = &ZSHIP::FLEX::calc_simplemultiprice($CART2, $PKG, 'zoovy:ship_cost1', 'zoovy:ship_cost2');
#			}
#		elsif ($CART2->in_get('ship/countrycode') eq 'US') {
#			$price = &ZSHIP::FLEX::calc_simplemultiprice($CART2, $PKG, 'zoovy:ship_cost1', 'zoovy:ship_cost2');
#			}
#		## Canada
#		elsif ($CART2->in_get('ship/countrycode') eq '') {
# 			$price = &ZSHIP::FLEX::calc_simplemultiprice($CART2, $PKG, 'zoovy:ship_can_cost1', 'zoovy:ship_can_cost2');
#			}
#		## International
#		else {
#			$price = &ZSHIP::FLEX::calc_simplemultiprice($CART2, $PKG, 'zoovy:ship_int_cost1', 'zoovy:ship_int_cost2');
#			}
#
#		$total += $price;
#		}
#	 
#	##
#	##	Zone based!
#	##
#	if ((defined $total) && (($SHIPMETHODS&2)==2)) {
#		## (2) Zone Based
#		my ($shipref,$metaref) = (undef,undef);
#		
#		## so GEN_SHIPMETER is a URI encoded key value pairs e.g. 
#		## type=UPS&user=tinaso2336&pass=osanit1202&license=5BE0D184D8F6B520&shipper_number=1E609R
#		my $METERREF = &ZTOOLKIT::parseparams($S->fetch_property('.ship.meter')); ## NEED!		
#
#		my %fake_webdb = ();
#		my %META = ();
#		my $methodsref = undef;
#
#		if ($S->fetch_property('.ship.meter_createdgmt')==0) {	
#			$total = undef;	## meter not registered!
#			}
#		elsif ($METERREF->{'type'} eq 'FEDEX') {
#			require ZSHIP::FEDEXWS;
#			my ($fdxcfg) = &ZSHIP::FEDEXWS::load_supplier_fedexws_cfg($CART2->username(),$S->id(),$S);
#			($methodsref) = ZSHIP::FEDEXWS::compute($CART2,$fdxcfg,\%META);
#			use Data::Dumper;
#			print STDERR 'methodsref: '.Dumper($methodsref,$fdxcfg,$CART2);
#			}
#		#elsif ($METERREF->{'type'} eq 'FEDEX-LEGACY') {
#		#	require ZSHIP::FEDEXAPI;
#		#	$fake_webdb{'ship_origin_zip'} = $S->fetch_property('.ship.origzip');
#		#	$fake_webdb{'fedexapi_dom'} = 2;
#		#	$fake_webdb{'fedexapi_int'} = 2;
#		#	
#		#	##  'type=FEDEX&meter=2745234&account_number=350321381'
#		#	my $meter = $S->fetch_property('.ship.meter');
#		#	print STDERR "METER[$meter]\n";
#		#	if ($meter =~ /\&/) {
#		#		my $params = &ZTOOLKIT::parseparams($meter);
#		#		$fake_webdb{'fedexapi_account'} = $params->{'account_number'};
#		#		$fake_webdb{'fedexapi_meter'} = $params->{'meter'};
#		#		}
#		#	else {
#		#	
#		#	## changed 3/12
#		#		$fake_webdb{'fedexapi_account'} = $S->fetch_property('.ship.account');
#		#		$fake_webdb{'fedexapi_meter'} = $S->fetch_property('.ship.meter');
#		#		}
#		#		
#		#	#$fake_webdb{'fedexapi_origin'} = $s->fetch_property('GEN_SHIPORIGZIP');
#		#	$fake_webdb{'fedexapi_drop_off'} = 1;
#		#	if ($S->fetch_property('.ship.options')&1) {	## MULTIBOX
#		#		$fake_webdb{'fedexapi_options'} = 4;					
#		#		}
#		#	## added 2007-11-01 - patti
#		#	## fedexapi_options must be defined to get a FEDEX quote
#		#	## need to determine if multi-box shipping is now allowed, setting is allowed in SC UI
#		#	## but turned off earlier in this code, line 370
#		#	else { $fake_webdb{'fedexapi_options'} = 8; }
##
##			if ($S->fetch_property('.ship.origzip') ne '' && 
##			    $S->fetch_property('.ship.origstate') ne '') {
##				$fake_webdb{'ship_origin_zip'} = $S->fetch_property('.ship.origzip');
##				## state, zip, country
##				$fake_webdb{'fedexapi_origin'} = $S->fetch_property('.ship.origstate')."|".
##					$S->fetch_property('.ship.origzip')."|"."US";
##				}
##
##			$fake_webdb{'fedexapi_dom_packaging'} = '01';
##			$fake_webdb{'fedexapi_int_packaging'} = '01';
##			if ($area eq 'can' || $area eq 'int') {
##				($shipref,$metaref) = ZSHIP::FEDEXAPI::compute_international($CART,\%fake_webdb);
##				}
##			elsif ($area eq 'dom') {
##				($shipref,$metaref) = ZSHIP::FEDEXAPI::compute_domestic($CART,\%fake_webdb);
##				# print STDERR 'SHIPREF: '.Dumper($shipref);
##				}
##			}
#		elsif ($METERREF->{'type'} eq 'UPS') {
#
#			my %config = ();
#			$config{'.dom_packaging'} = 'SMART';
#			$config{'.int_packaging'} = 'SMART';
#			$config{'.rate_chart'} = '01';
#		
#			require ZSHIP::UPSAPI;
#		#	$fake_webdb{'upsapi_dom_packaging'} = 'SMART';
#		#	$fake_webdb{'upsapi_int_packaging'} = 'SMART'; 
#		#	$fake_webdb{'upsapi_rate_chart'} = '01';
#		#	$fake_webdb{'upsapi_int'} = 2+4;
#			$config{'STD'} = 1;
#			$config{'XPR'} = 1;
#			$config{'enable_dom'} = 1;
#
#		# 	$fake_webdb{'upsapi_dom'} = 2;
#			$config{'GND'} = 1;
#
#			if ($S->fetch_property('.ship.options')&1) {	## MULTIBOX
#		#		$fake_webdb{'upsapi_options'} = 4;
#				$config{'.multibox'} = 1;
#				}
# 
#		#	$fake_webdb{'upsapi_license'} = $METERREF->{'license'};
#			$config{'.license'} = $METERREF->{'license'};
#		#	$fake_webdb{'upsapi_userid'} = $METERREF->{'user'};
#			$config{'.userid'} = $METERREF->{'user'};
#		#	$fake_webdb{'upsapi_password'} = $METERREF->{'pass'};
#			$config{'.password'} = $METERREF->{'pass'};
#		#	$fake_webdb{'upsapi_shipper_number'} = $METERREF->{'shipper_number'};
#			$config{'.shipper_number'} = $METERREF->{'shipper_number'};
#		#	$fake_webdb{'upsapi_options'} |= 8;
#			$config{'.residential'} = 1;
#		#	$fake_webdb{'upsapi_disable_rules'}++;
#			$config{'.use_rules'} = 0;
#
#			$fake_webdb{'upsapi_config'} = &ZTOOLKIT::buildparams(\%config,1);
#			if ($S->fetch_property('.ship.origzip') ne '') {
#				$fake_webdb{'ship_origin_zip'} = $S->fetch_property('.ship.origzip');
#				}
#
#			($methodsref) = &ZSHIP::UPSAPI::compute($CART2,\%fake_webdb,\%META);
#			}
#
#		if (defined $methodsref) {
#			$shipref = {};
#			foreach my $set (@{$methodsref}) {
#				next if (not defined $set->{'amount'});
#				$shipref->{ $set->{'carrier'}.'|'.$set->{'pretty'} } = $set->{'amount'};
#				}
#			}
#
#		my $lowprice = undef;
#		if (defined $shipref) {
#			foreach my $m (keys %{$shipref}) {
#				if (not defined $lowprice) { $lowprice = $shipref->{$m}; }
#				elsif (($lowprice > $shipref->{$m}) && ($shipref->{$m}>0)) { $lowprice = $shipref->{$m}; }
#				}
#			}	
#		if (not defined $lowprice) { $total = undef; } else { $total += $lowprice; }
#		}
#
#	##
#	##	Handling!
#	##
#	if ((defined $total) && (($SHIPMETHODS&32)==32)) {
#		## (32) Handling
#		## | GEN_HNDPERORDER   | decimal(8,2)                        |      |     | 0.00    |                |
#		## | GEN_HNDPERITEM    | decimal(8,2)                        |      |     | 0.00    |                |
#		## | GEN_HNDPERUNIITEM | decimal(8,2)                        |      |     | 0.00    |                |
#
#		if ($S->fetch_property('.ship.hnd.perorder')) {
#			$total += $S->fetch_property('.ship.hnd.perorder');
#			}
#
#		if ($S->fetch_property('.ship.hnd.peritem')>0) {
#			my $count = $CART2->stuff2()->count();
#			$total += ($count*$S->fetch_property('.ship.hnd.peritem'));
#			}
#
#		if ($S->fetch_property('.ship.hnd.perunititem')>0) {
#			my $count = $CART2->stuff2()->count(1+2);
#			$total += ($count*$S->fetch_property('.ship.hnd.perunititem'));
#			}
#		}
#
#	return($total);
#	}
#
#
#
#
###
### update Supplier inventory
## - can be called from web and done dynamically
## - or setup to be run nightly from app6:sc_update_inv.pl
##
## (done)
##
## %OPTIONS
##		LUSER=>luser who requested update
##
sub update_inventory {
	my ($S, %options) = @_;
	
	my $count = 0;

	my ($USERNAME) = $S->username();
	my ($SUPPLIER) = $S->id();

	my $lm = LISTING::MSGS->new($S->username());

	if ((not defined $S) || (ref($S) ne 'SUPPLIER')) { 
		$lm->pooshmsg("ISE|+Unknown supplier $SUPPLIER");
		}

	my $URL = $S->fetch_property('.inv.url');
	if ($URL eq '') { 
		$lm->pooshmsg("ERROR|+Inventory URL is not set."); 
		}

	my $HEADER = '';
	if ($S->fetch_property('.inv.header') eq '') {
		$lm->pooshmsg("ERROR|+Header should be set for file import (ready CSV INVENTORY IMPORT documentation)");
		}
	else {
		$HEADER = $S->fetch_property('.inv.header')."\n";
		$HEADER =~ s/[\r]//gs;		# remove any \r's (this is unix, they are not necessary)
		$HEADER =~ s/[\n]+/\n/gs;	# ensure we always end with a \n
		}
	
	my $prodsref = ();
	## the lines below would fail if there are no products for a supplier:
	## 
	#if ($lm->can_proceed()) {
	#	## map of Supplier SKU to Zoovy SKU, WE NEED THIS
	#	($prodsref) = $S->fetch_supplier_products($USERNAME,$SUPPLIER);
	#	my $count = scalar(keys %{$prodsref});
	#	if ($count == 0) { 
	#		$lm->pooshmsg("ERROR|+No products associated with this Supplier: $SUPPLIER"); 
	#		}
	#	else { 
	#		$lm->pooshmsg("INFO|+Found $count products in database for Supplier: $SUPPLIER");
	#		}
	#	}


	my $CONTENT = '';
	if (not $lm->can_proceed()) {
		}
	elsif ($URL =~ /^[Hh][Tt][Tt][Pp][Ss]?:\/\//) {
		## THIS DOES THE ACTUAL REQUEST
		my $agent = new LWP::UserAgent;
		$agent->timeout(60);

		## NOTE: this proxy is dead. not sure if one is still needed for dev. (doubt it)
		# $agent->proxy(['http', 'ftp'], 'http://63.108.93.10:8080/');
		$lm->pooshmsg("INFO|+Getting URL '$URL'");
		my $request = HTTP::Request->new(GET=>$URL);
		my $result = $agent->request($request);

		if ($result->is_error()) {
			$lm->pooshmsg(sprintf("ERROR|+Transfer error '%s'",$result->status_line()));
			}
		else {
			$CONTENT = $result->content();
			}
		$result = undef;
		}
	elsif ($URL =~ /^[Ff][Tt][Pp]\:\/\/(.*?)/) {
		# $lm->pooshmsg("ERROR|+FTP not implemented yet");
		require Net::FTP;

		## FTP TYPE added to indicate ftp SSL as necessary 
		my ($FTP_TYPE,$USER,$PASS,$HOST,$PORT,$FILE);
		$lm->pooshmsg("INFO|+FTP URL:$URL");
		if ($URL =~ /^(ftp|ftps)\:\/\/(.*?):(.*?)\@(.*?)\/(.*?)$/) {
			($FTP_TYPE,$USER,$PASS,$HOST,$FILE) = ($1,$2,$3,$4,$5);
			# $FILE = "/$FILE";
			$FILE = URI::Escape::uri_unescape($FILE);
			$lm->pooshmsg("INFO|+FILE:$FILE");
			}

		$USER = URI::Escape::uri_unescape($USER);
		$PASS = URI::Escape::uri_unescape($PASS);
		$HOST = URI::Escape::uri_unescape($HOST);

		$PORT = 21;
		if ($HOST =~ /^(.*?):([\d]+)$/) {
			## found an alternate FTP port number, necessary for:
			## - buy.com which uses an active ftp proxy
			## - hsn which uses SSL ftp, 990
			$PORT = int($2);
			$HOST = $1;
			}

		my $ftp = Net::FTP->new("$HOST", Port=>$PORT, Debug => 1);
		print STDERR "FTPSERV:[$HOST] FUSER: $USER FPASS: $PASS\n";
		if (not defined $ftp) { $lm->pooshmsg("ISE|+Unknown FTP server $HOST"); }
		if ($lm->can_proceed()) {
			my $rc = $ftp->login($USER,$PASS);	
			print STDERR "RC: $rc\n";
			if ($rc!=1) { $lm->pooshmsg('ERROR|+FTP User/Pass invalid.'); }
			}


		if ($lm->can_proceed()) {
			#$ftp->cwd("/pub")
         #    or die "Cannot change working directory ", $ftp->message;

			use IO::String;
			my $io = IO::String->new($CONTENT);			
			$ftp->get("$FILE",$io) or $lm->pooshmsg(sprintf("ERROR|+FTP Error %s", $ftp->message));
			}

		if ($lm->can_proceed()) {
			$ftp->quit;
			$lm->pooshmsg("INFO|+Transferred files via FTP"); 
			}
		}
	else {
		$lm->pooshmsg("ERROR|+Unknown request URL format try http:// or ftp://");
		}


	if (not $lm->can_proceed()) {
		}
	elsif ($CONTENT eq '') { 
		$lm->pooshmsg("ERROR|+Received no data from server");
		}
	else {
		$lm->pooshmsg(sprintf("INFO|+Received %d bytes from server.",length($CONTENT)));
		}


#	my @INV_HEADER = ();
#	my @PROD_HEADER = ();
#	my @INV_LINES = ();
#	my @PROD_LINES = ();
#	if (not $error) {
#		## At this point we build an INVENTORY IMPORT file of just the fields we want.
#		require ZCSV;
#		my $SKU_POS = int($S->fetch_property('.inv.pos.sku'))-1;
#		my $INVQTY_POS = int($S->fetch_property('.inv.pos.instock'))-1;
#		my $INVAVAIL_POS = int($S->fetch_property('.inv.pos.avail'))-1;
#		my $PRODSHIP_POS = int($S->fetch_property('.inv.pos.ship'))-1;
#		my $PRODCOST_POS = int($S->fetch_property('.inv.pos.cost'))-1;
#
#		my $INVTYPE = $S->fetch_property('.inv.type');
#		my $SEP_CHAR = $S->fetch_property('.inv.type_other');
#		
#		if ($INVTYPE eq 'OTHER') {	
#			## INVSEP is set by client. 
#			}
#		elsif ($INVTYPE eq 'TAB') { 
#			$SEP_CHAR = "\t";
#			}
#		else {
#			$SEP_CHAR = ",";
#			}
#
#		my $csv = Text::CSV_XS->new({sep_char=>$SEP_CHAR}); 
#		my $real_csv = Text::CSV_XS->new({sep_char=>','}); 	
#		
#
#		if (($PRODSHIP_POS>=0) || ($PRODCOST_POS>=0)) {
#			$PROD_HEADER[0] = '%SKU';
#			if ($PRODSHIP_POS>=0) { $PROD_HEADER[1] = 'zoovy:ship_cost1'; }
#			if ($PRODCOST_POS>=0) { $PROD_HEADER[2] = 'zoovy:base_cost'; }
#			}
#
#		if (($INVQTY_POS>=0) || ($INVAVAIL_POS>=0)) {
#			$INV_HEADER[0] = '%SKU';
#			if ($INVQTY_POS>=0) { $INV_HEADER[1] = '%QTY'; }
#			if ($INVAVAIL_POS>=0) { $INV_HEADER[1] = '%AVAIL'; }
#			}
#
#
#		my @DATA = ();
#		my $ctr =0;
#	
#		##
#		## Chew through the uploaded file and create zoovy formatted import data structures.
#		##
#
#		#foreach my $line (split(/[\n\r]+/,$CONTENT)) {
#
#			next if ($SKU_POS<0); 	## we don't have a SKU.. this ain't happening.
#			$line = ZTOOLKIT::stripUnicode($line);
#			print STDERR "SUPPLIER LINE: $line\n";
#			$csv->parse($line);		
#			my @COLS = $csv->fields();
#			
#			if (($PRODSHIP_POS>=0) || ($PRODCOST_POS>=0)) {
#				## create product lines (if needed)
#				## need to update fixed shipping, availability and cost as needed
#				## check if these fields are trying to be updated
#				my @PROD_LINE = ();
#
#				## get the Zoovy SKU from the Supplier SKU
#				## note: this doesn't work for options, but options really aren't officially supported in SC
#				if (defined $prodsref->{$COLS[$SKU_POS]}) {
#	 				$PROD_LINE[0] = $prodsref->{$COLS[$SKU_POS]};
#	 				}
# 				else { 
# 					print STDERR "$COLS[$SKU_POS] not found\n";  ## not all Supplier's products are being sold by this merchant
#					next;
# 					}
#				
#				if ($PRODSHIP_POS>=0) { $PROD_LINE[1] = $COLS[$PRODSHIP_POS]; }
#				if ($PRODCOST_POS>=0) { $PROD_LINE[2] = $COLS[$PRODCOST_POS]; }					
#				my $status = $real_csv->combine(@PROD_LINE);   
#				my $thisline = $real_csv->string();         
#				push @PROD_LINES, $thisline;
#				}
#
#			if (($INVQTY_POS>=0) || ($INVAVAIL_POS>=0)) {
#				## create inventory lines (if needed)
#				my @INV_LINE = ();
#				#$INV_LINE[0] = $COLS[$SKU_POS];
#
#				## get the Zoovy SKU from the Supplier SKU
#				## note: this doesn't work for options, but options really aren't officially supported in SC
#				if (defined $prodsref->{$COLS[$SKU_POS]}) {
#	 				$INV_LINE[0] = $prodsref->{$COLS[$SKU_POS]};
#	 				}
# 				else { 
# 					print STDERR "$COLS[$SKU_POS] not found\n";  ## not all Supplier's products are being sold by this merchant
#					next;
# 					}
#
#				if ($INVQTY_POS>=0) { $INV_LINE[1] = $COLS[$INVQTY_POS]; }
#				elsif ($INVAVAIL_POS>=0) { 
#					$INV_LINE[1] = &ZOOVY::is_true($COLS[$INVAVAIL_POS])?'9999':0;
#					}
#
#				my $status = $real_csv->combine(@INV_LINE);   
#				my $thisline = $real_csv->string();         
#				push @INV_LINES, $thisline;				
#				}
#
#			$count++;
#			}
#
#		if ($error) {
#			}
#		elsif ((scalar(@INV_LINES)==0) && (scalar(@PROD_LINES)==0)) {
#			$error = "Could not find any lines to import.";
#			}
#		}

	## SANITY: at this point @INV_LINES and @PROD_LINES has all our lines
	## 			and @INV_HEAD and @PROD_HEADER is our header columns OR error has been set

	my %DIRECTIVES = ();
	$DIRECTIVES{'SUPPLIER'} = $S->id();
	$DIRECTIVES{'DESTRUCTIVE'} = 0;


	my $JOBID = 0;

	my $STATUS = '';
	if (not $lm->can_proceed()) {
		}
	else {
		require ZCSV;
		($JOBID, my $JOBERR) = &ZCSV::addFile(
			SRC=>'SUPPLIER',
			TYPE=>'INVENTORY',
			'*LU'=>$options{'*LU'},		## note *LU might not be set (if we're in a nightly run)
			'%DIRECTIVES'=>\%DIRECTIVES,
			USERNAME=>$USERNAME, 
			PRT=>0,
			BUFFER=>$HEADER.$CONTENT,
			);
		if ($JOBID==0) { 
			$lm->pooshmsg("ERROR|+JOB ERROR '$JOBERR'"); 
			} 
		else { 
			$STATUS .= "&INVJOB=$JOBID"; 
			}
		}

	#if ((not $error) && (scalar(@PROD_LINES)>0)) {
	#	my ($BUFFER) = &ZCSV::assembleCSVFile(\@PROD_HEADER,\@PROD_LINES,{});
	#	my ($JOBID,$JOBERR) = &ZCSV::addFile(
	#		SRC=>'SUPPLIER',
	#		TYPE=>'PRODUCTS',
	#		'*LU'=>$options{'*LU'},		## note *LU might not be set (if we're in a nightly run)
	#		'%DIRECTIVES'=>{
	#			SUPPLIER=>$S->id(),
	#			NONDESTRUCTIVE=>1,
	#			},
	#		USERNAME=>$USERNAME, PRT=>0,
	#		BUFFER=>$BUFFER,
	#		);
	#	if ($JOBID==0) { $error = $JOBERR; } else { $STATUS .= "&PRODJOB=$JOBID"; }
	#	}

#		&ZCSV::INVENTORY::parseinventory($USERNAME,\@header,\@LINES,\%attribs);
#		my $optionsref = ();
#		&ZCSV::logImport($USERNAME,$options{'LUSER'},\@header,\@LINES,$optionsref);

	
#	## update SUPPLIERS w/update inv info
#	## so we've "repurposed" update_status so it contains a status key=value& pairs.
#	if ($error) {
#		$STATUS .= "&ERR=$error";
#		$S->save_property('.inv.update_rows', 0);
#		}
#	else {
#		$S->save_property('.inv.update_gmt', time());
#		$S->save_property('.inv.update_rows', $count);
#		}
#	$S->save_property('.inv.update_status', $STATUS); 		
#	$S->save();
	if ($JOBID > 0) {
		$lm->pooshmsg("SUCCESS|Started job $JOBID");
		}

	return($JOBID,$lm); 
	}

## given a USERNAME & SUPPLIER_ID find the product
## (done)
#sub resolve_supplier_id {
#	my ($USERNAME, $SUPPLIER_ID) = @_;
#	my $MID = ZOOVY::resolve_mid($USERNAME);
#
#	my $pdbh = &DBINFO::db_user_connect($USERNAME);
#	my $TB = ZOOVY::resolve_product_tb($USERNAME);
#	my $pstmt = "select PRODUCT from $TB where SUPPLIER_ID = ".$pdbh->quote($SUPPLIER_ID). " and MID=$MID limit 1";
#	my $sth   = $pdbh->prepare($pstmt);
#	$sth->execute();
#	my ($product) = $sth->fetchrow();
#	$sth->finish;
#	&DBINFO::db_user_close();
#
#	#if ($product eq '') { $product = $SUPPLIER_ID; }
#	return($product);
#	}

## this subroutinue replaces import_produrl and import_prodfile
## (done)
#sub import_prods {
#	my ($USERNAME, $SUPPLIER, $headerref, $IMPORT_TYPE, $IMPORT_CONTENT) = @_;
#	my $error = '';
#	my @DATA = ();
#	my @LINES = ();
#	my $CONTENT = '';
#
#	if ($IMPORT_CONTENT eq '') { $error = $IMPORT_TYPE ." not set."; }
#
#	if ($error eq '') {
#		## for URLs, CONTENT needs to retrieved and header built
#		if ($IMPORT_TYPE eq 'URL') {
#			my $URL = $IMPORT_CONTENT;
#			## THIS DOES THE ACTUAL REQUEST
#			my $agent = new LWP::UserAgent;
#			$agent->timeout(60);
#
#			## NOTE: this proxy is dead. not sure if one is still needed for dev. (doubt it)
#			# $agent->proxy(['http', 'ftp'], 'http://63.108.93.10:8080/');
#			my $result = $agent->request(GET $URL);
#
#			if ($result->is_error()) {
#				$error = $result->status_line;
#				}
#			else {
#				$CONTENT = $result->content();
#				if ($CONTENT eq '') { $error = 'Received blank response from server.'; }
#				}
#			
#			## build headerref
#			my $cols = 10;
#			for (my $n=0;$n<=$cols;$n++) {
#				$headerref->[$n] = $ZOOVY::cgiv->{'GEN_PROD'.$n};
#				}
#			}
#		elsif ($IMPORT_TYPE eq 'FILE') {
#			$CONTENT = $IMPORT_CONTENT;
#			}
#		}
#
#	## find separator
#	if ($error eq '') {
#		my $TYPE = $ZOOVY::cgiv->{'GEN_PRODTYPE'};
#		my %attrib = ();
#		if ($TYPE eq 'OTHER') { $attrib{'sep_char'} = $ZOOVY::cgiv->{'GEN_PRODTYPE_OTHER'}; }
# 		elsif ($TYPE eq 'TAB') { $attrib{'sep_char'} = '\t'; }
#
#		## create CSV object w/correct separator 
#		my $csv = Text::CSV_XS->new(\%attrib); 
#		my $new_csv = Text::CSV_XS->new();
#
#		## go thru each line in CONTENT
#		foreach my $line (split(/[\n\r]+/,$CONTENT)) {
#			## strip nasty unicode chars
#			require ZCSV;
#			$line = ZCSV::macro_fixhtml($line);
#
#			$csv->parse($line);
#			my @COLS = ();
#			@COLS = $csv->fields();
#
#			my $cols = 10;
#			for (my $n=0;$n<$cols;$n++) {
#				if ($headerref->[$n]) {				
#     				$DATA[$n] = $COLS[$n];
#					}
#				}
#
#			my $status = $new_csv->combine(@DATA);    # combine columns into a string
#			my $line = $new_csv->string();               # get the combined string
#			push @LINES, $line;
#			}
#		}
#
#	if ($error eq '' && scalar(@LINES)==0) { $error = "Could not find any lines to import!"; }
#
#	return($headerref,\@LINES,$error);
#	}



1;
