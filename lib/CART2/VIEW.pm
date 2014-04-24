package CART2::VIEW;

##
## Cartview is called from the following locations:
##		/backend/lib/PAGE/checkout.pm
##		/backend/lib/PAGE/cart.pm
##		/backend/lib/PAGE/HANDLER.pm (fastorder)
##		/backend/lib/PAGE/order_status.pm
##		/httpd/htdocs/biz/orders/view.cgi
##


# This package only contains the functions neede to display a cart's contents
# Anything pertaining to the maintenance of the cart and addition/subtraction from
# it will be found in CART.pm

use lib '/backend/lib';
require ZTOOLKIT;
require PRODUCT;
require ZOOVY; # Don't have to init, we don't do anything merchant-specific with ZOOVY here
require INVENTORY2;
require CART2;
require TOXML::SPECL3;
require ZPAY;
use strict;


########################################
# as_html (formerly CARTVIEW::cart_view)
# Description: Shows the contents of a cart, and its totals.
# Accepts: See statements below
# Returns: HTML to show the cart
# Notes: This can be used outside of the cart/checkout systems to display a 
# cart as well, all you have to do is pass it the proper theme, etc to it.

##
## SREF is required (must have:
##
sub as_html {
	my (
		$CART2, #  order object
		$mode, 		 # A reference to the cart hash
		$iniref, 	# if we're a minicart, this is our element
		$SITE,
		) = @_;


	## MODES ARE:
	##		'SITE' 
	##		'SITE_PREVIEW'	-- a special mode just like '' for the PAGE editor.
	##		'CHECKOUT' -- calls in a cart
	##		'INVOICE' -- this is shown to a customer at end of checkout
	##		'SUMMARY' -- this is used in order edit by the merchant.
	##		'PRINT_INVOICE'
	##		'PRINT_PACKSLIP'
	##		'EMAIL'
	##		'CALLCENTER'
	##		'PR_FEEDBACK'	## power reviews (REVIEWS)
	##		'FEEDBACK'		## zoovy reviews
	##

	if (not defined $SITE) {
		warn Carp::croak("SREF is required for CART2::VIEW -- specifically: *TXSPECL (crashing intentionally)\n");
		die();
		}

	if (ref($CART2) ne 'CART2') {
		## convert the $O to an order
		print STDERR Carp::confess("CART2::VIEW::as_html EXPECTS CART2 OBJECT");
		}


	my $TXSPECL = $SITE->txspecl();
	my $webdbref = $SITE->webdb();

	if (ref($TXSPECL) ne 'TOXML::SPECL3') {
		Carp::croak("CART2::VIEW -- TOXML::SPECL3 interpreter needed to instantiated (not passed in as part of SREF)\n");
		}

	## SANITY: at this point we're ONLY dealing with orders.
	if (not defined $SITE) {
		print STDERR Carp::confess("CART2::VIEW::as_html really needs an SREF passed in\n");
		}

	if (defined $iniref->{'MODE'}) { $mode = $iniref->{'MODE'};  }
	if ($mode eq '') { 
		warn "CART2::VIEW::as_html mode parameter not set, defaulting to 'SITE'\n";
		$mode = 'SITE'; 
		}

	# print STDERR "CART2::VIEW::as_html -- ELEMENTID:$iniref->{'ID'} ".caller(join("|",caller(0)))."\n";
	if (not defined $iniref) { $iniref = {}; }

	my %cart2 = ();
	tie %cart2, 'CART2', 'CART2'=>$CART2;
	# $CART2->__SYNC__();

#	open F, ">>/tmp/foo";
#	use Data::Dumper; print F Dumper($CART2);
#	close F;


	#use Data::Dumper; 
	#print STDERR '...... ITEMS TOTAL ......'.Dumper($CART2, $cart2{'sum/items_total'})."\n\n\n";

	## 
	## now go forth and render...
	##
	
	my $spec = (defined $iniref->{'HTML'})?$iniref->{'HTML'}:'';

	## POGSPEC
	my $pog_spec = q~
<!-- POGS -->
<div class="z_cartpogs" style="margin-left: 15px;"><table class="z_cartpogs" cellpadding=0 cellspacing=2><!-- ROW -->
<!-- OPTION -->
<tr>
        <td valign="top" class="ztable_row_small ztable_row_pogprompt"><% print($prompt); %>:</td>
        <td valign="top" class="ztable_row_small ztable_row_pogvalue"><% load($value); format(replace=>"\n",with=>"&lt;br&gt;"); print($_); %></td>
</tr>
<!-- /OPTION -->
<!-- /ROW --></table></div>
<!-- /POGS -->
~;
	if (index($spec,'<!-- POGS -->')>=0) { 
		($pog_spec, $spec) = $TXSPECL->extract_comment($spec,'POGS');
		}
	elsif (defined $iniref->{'POGS_SPEC'}) { $pog_spec = $iniref->{'POGS_SPEC'}; }

	## REMOVE_LINK
	my $remove_link_spec = q~<a href="<% print($CART_URL); %>?delete_item=<% print($SAFESTID); %>"><font size="-2"><i>(remove)</i></font></a>~;
	if (defined $iniref->{'REMOVE_LINK_SPEC'}) {  $remove_link_spec = $iniref->{'REMOVE_LINK_SPEC'}; }
	if (index($spec,'<!-- REMOVE_LINK -->')>=0) { 
		($remove_link_spec, $spec) = $TXSPECL->extract_comment($spec,'REMOVE_LINK');
		}
	elsif (defined $iniref->{'REMOVE_LINK_SPEC'}) { $remove_link_spec = $iniref->{'REMOVE_LINK_SPEC'}; }

	## SURCHARGE
	my $surcharge_spec = q~<!-- SURCHARGE -->
<tr>
   <td></td>
   <td nowrap align="right" class="ztable_row<% print($row.alt); %>"><div id="cart_surcharge_<% print($SURCHARGEID); %>"><% print($SURCHARGE); %>:</div></td>
   <td nowrap align="right" class="ztable_row<% print($row.alt); %>"><% load($SURCHARGEVALUE);  format(money);  print(); %></td>
</tr>
<!-- /SURCHARGE -->
~;
	if (index($spec,'<!-- SURCHARGE -->')>=0) { 
		($surcharge_spec, $spec) = $TXSPECL->extract_comment($spec,'SURCHARGE');
		}
	elsif (defined $iniref->{'SURCHARGE_SPEC'}) { $surcharge_spec = $iniref->{'SURCHARGE_SPEC'}; }


	## TAX
	my $tax_spec = q~<!-- TAX -->
<tr>
<td></td>
<td nowrap align="right"  class="ztable_row<% print($row.alt); %>">State Tax (<% print($TAXRATE); %>%)</td>
<td nowrap align="right"  class="ztable_row<% print($row.alt); %>"><% load($TAXTOTAL);  format(money);  print(); %></td>
</tr>
<!-- /TAX -->
~;
	if (index($spec,'<!-- TAX -->')>=0) { 
		($tax_spec, $spec) = $TXSPECL->extract_comment($spec,'TAX');
		}
	elsif (defined $iniref->{'TAX_SPEC'}) { $tax_spec = $iniref->{'TAX_SPEC'}; }

	## FOOTER
	my $footer_spec = q~<!-- FOOTER -->
<div align="center">
<% print($ZIP_INPUT); %>
<% print($DESTINATIONBLURB); %><br>    <!-- NOTE: destination blurb is required by UPS / FedEx API EULA -->
<%
	 print($UPDATECART_BUTTON); print(" ");
	print($EMPTYCART_BUTTON);  print(" ");
	print($CONTINUE_BUTTON);   print(" ");
	print($CHECKOUT_BUTTON);   print(" ");
	print($ADDTOSITE_BUTTON); 
	print($GOOGLE_BUTTON); 
	print($AMZPAY_BUTTON); 
	print($PAYPAL_BUTTON); 
%>
</div>
<!-- /FOOTER -->
~;
	if (index($spec,'<!-- FOOTER -->')>=0) { 
		($footer_spec, $spec) = $TXSPECL->extract_comment($spec,'FOOTER');
		}
	elsif (defined $iniref->{'FOOTER_SPEC'}) { $footer_spec = $iniref->{'FOOTER_SPEC'}; }


	## NOITEMS
	my $noitems_spec = q~<br><table><tr><td valign="top" align="center" width="100%" colspan="<% print($TOTALCOLS); %>"  class="ztable_row"><b>There are no items in the shopping cart</b><br></td></tr></table><br>~;
	if (index($spec,'<!-- NOITEMS -->')>=0) { 
		($noitems_spec, $spec) = $TXSPECL->extract_comment($spec,'NOITEMS');
		}
	elsif (defined $iniref->{'NOITEMS_SPEC'}) { $noitems_spec = $iniref->{'NOITEMS_SPEC'}; }


	## HTML
	if ($spec eq '') {
		$spec = q~<% print($FORM); %>
<br>
<table width=100% cellspacing="0" cellpadding="2"><tr>
        <td width="15%" class="ztable_head"><b>SKU</b></td>
        <td class="ztable_head"><b>Description</b></font></td>
	<%
		/* We only output a buysafe header if have buysafe enabled. */
		print("");
		stop(unless=>$BUYSAFE_ENABLED);
		print("&lt;td nowrap align=&quot;center&quot; class=&quot;ztable_head&quot;&gt;&lt;b&gt;buySAFE Bond&lt;/b&gt;&lt;/font&gt;&lt;/td&gt;");
	%>
        <td width="12%" align="center" class="ztable_head"><b>Price</b></td>
        <td width="9%" class="ztable_head"><b>Qty.</b></td>
        <td width="12%" align="right" class="ztable_head"><b>Ext.</b></td>
</tr>
<!-- ROW -->
<tr>
<!-- PRODUCT -->
<td valign="top"  class="ztable_row<% print($row.alt); %>" align="left" valign="top"><% print($SKU_LINK); %></td>
<td valign="top"  class="ztable_row<% print($row.alt); %>">
<% load($prod_name); default(""); print(); %> <% print($REMOVE_LINK); %>
<% print($POGS); %>
</td>
<%
	print("");
	stop(unless=>$BUYSAFE_ENABLED);
	print("&lt;td align=&quot;center&quot; valign=&quot;top&quot; class=&quot;ztable_row");
	print($row.alt);
	print("&quot;&gt;");
	print($BOND_STATUS);
	print("&lt;/td&gt;");
%>
<td valign="top" align="center"  class="ztable_row<% print($row.alt); %>"><% load($PRICE);  format(money);  print(); %></td>

<td valign="top"  class="ztable_row<% print($row.alt); %>"><% print($QTY_INPUT); %></td>
<td valign="top" align="right"  class="ztable_row<% print($row.alt); %>"><% load($EXTENDED);  format(money);  print(); %></td>
<!-- /PRODUCT -->
</tr>
<!-- /ROW -->
</table>
<table width="100%" cellspacing="0" cellpadding="2">
<tr>
        <td width="70%">&nbsp;</td>
        <td nowrap align="right" class="ztable_head"> Subtotal:</td>
        <td width="12%" nowrap align="right" class="ztable_head"><% load($SUBTOTAL);  format(money);  print(); %></td>
</tr>
<% print($TAX_LINE);  %>
<% print($SURCHARGE_LINE);  %>
<tr>
        <td width="70%">&nbsp;</td>
        <td nowrap align="right" class="ztable_head"><strong>Grand Total: </strong></td>
        <td width="12%" nowrap align="right" class="ztable_head"><strong><% load($GRANDTOTAL);  format(money);  print(); %></strong></td>
</tr>
<tr><td colspan=2>&nbsp;<!-- spacer line --></td></tr>
<% print($PAYMENT_LINES); %>
<% print($BALANCEDUE_LINE); %>
</table><br>
<br>
<% print($FOOTER); %>
<% print($MESSAGES); %>
<% print($ENDFORM);  %>
~;
		}

	
	## at this point all the specs are initialized.

	my $buysafe = 0;
	my %VARS = (
		'TOTALCOLS'=>$iniref->{'TOTALCOLS'},					# a cheater variable so we can use relative colspans
		'FORM'=>'', 
		'FORMID'=>'thisFrm',											# note: we'll override this later if the formID is different.
		'ENDFORM'=>'',
		'FOOTER'=>'',
		'MESSAGES'=>'',	## future errors/!?
		'SHIPPING_CHOOSER'=>undef, 				## note: these will contain all sorts of fun data like select boxes, etc.
		'DESTINATIONBLURB'=>'',
		'ZIP_INPUT'=>'',
		'BUYSAFE_ENABLED'=>0,
		);


	$VARS{'graphics_url'} = $SITE->URLENGINE()->get('graphics_url');

	if (($mode eq 'SITE') || ($mode eq 'CALLCENTER')) {
		##
		## BEGIN CART SPECIFIC CODE
		##
		## lookup is an array of hashes, the keys of each hash will be interoplated.
		my $cart_url    = $SITE->URLENGINE()->get('cart_url');
		my $checkout_url    = $SITE->URLENGINE()->get('checkout_url');

		$VARS{'CART_URL'}=$cart_url;
		$VARS{'CHECKOUT_URL'}=$checkout_url;
		$VARS{'FORMID'} = $iniref->{'ID'};
			
		my $qs = int($SITE->webdb()->{'cart_quoteshipping'});
		# if ($SITE->URLENGINE()->wrapper() =~ /^aol/o) { $qs = 4; }

		## Map the $qs setting to what we have to do/ask for
		## 0 = don't quote, 1 = quote w/o zip, 2 = quote zip req'd, 3 = quote w/o zip lowest, 4 = quote zip optional
		my $getzip          = (($qs == 2) || ($qs == 4)) ? 1 : 0 ; # should we prompt the user for a zip code
		my $quotewithoutzip = (($qs == 1) || ($qs == 3) || ($qs==4)) ? 1 : 0 ; # can we quote shipping BEFORE we get a zip code
		my $quotelowestonly = ($qs == 3) ? 1 : 0 ; # should we show all available rates, or just the lowest

		## Calculates a ton of stuff, including applicable shipping, totals, etc.
		# my ($changed) = $CART2->shipping(); ## The blank forces the country to USA
	
		## Get the totals for the cart
		my $zipcode      = $cart2{'ship/postal'};
		my $state        = $cart2{'ship/region'};
		my $subtotal     = $cart2{'sum/items_total'};
		my $totalweight  = $cart2{'sum/pkg_weight'};
		my $totaltax     = $cart2{'sum/tax_total'};
		my $totaltaxable = $cart2{'sum/items_taxable'};
		my $grandtotal   = $cart2{'sum/order_total'};
		my $itemcount    = $cart2{'sum/items_count'};
	
		my $shipmethods = $CART2->shipmethods();
		## it's pretty common that we don't quote shipping for bots, but a lot of the code below really wants shipping.
		if (not defined $shipmethods) { $shipmethods = []; }

		# my $meta = $CART2->fetch_property('ship.%meta'); ## Information about shipping
		my $meta = {};
		# if (not defined $meta) { $meta = {}; }


		## Only display shipping/zip code entry if they have stuff in the cart
		if ($itemcount==0) {
			## no items = no shipping
#			$VARS{'SHIPPING_CHOOSER'} = '<i>No items to ship</i>';
			}
		elsif ((not $quotewithoutzip) && ($zipcode eq '')) {
			## if we require a zip, and zip is blank, we don't quote
#			$VARS{'SHIPPING_CHOOSER'} = '<i>Zip Code Required</i>';
			}
		elsif (($getzip) && ($zipcode eq '') && (not $quotewithoutzip)) {
			## if we require a zip, and zip is blank, we don't quote, unless we can still quotewithoutzip (zip is optional)
#			$VARS{'SHIPPING_CHOOSER'} = '<i>Zip Code Required</i>';
			}
		elsif (scalar(@{$shipmethods}) == 0) {
			## there are no shipping methods
#			$VARS{'SHIPPING_CHOOSER'} = '<i>No Shipping Methods</i>';
			}
		elsif ((scalar(@{$shipmethods}) == 1) || $quotelowestonly) {
			## yay! Single shipping method quote
			$VARS{'SHIPPING_CHOOSER'}  = qq~<span id="cgi_shipmethod_span">$shipmethods->[0]->{'name'}:</span>~;
			}
		elsif (scalar(@{$shipmethods}) > 1) {
			## Multiple shipping method quote
			## Show the select list (we may make this one radio-button optional like the minicart some time in the future)
			$VARS{'SHIPPING_CHOOSER'} .= qq~<span id="cgi_shipmethod_span">
<strong><label id="cgi_shipmethod_label" for="cgi_shipmethod_select">Shipping</label></strong>
<select id="cgi_shipmethod_select" class="zform_select" name="cgi.shipmethod" onChange="this.form.submit();">~;
			foreach my $shipmethod (@{$shipmethods}) {
				# $method =~ s/^[\s]+(.*)[\s]+$/$1/s;
				my $is_selected = 0;
				if ($shipmethod->{'id'} eq $cart2{'want/shipping_id'}) { $is_selected++; }
				elsif ($shipmethod->{'name'} eq $cart2{'want/shipping_id'}) { $is_selected++; }
				$VARS{'SHIPPING_CHOOSER'} .= qq~<option value="$shipmethod->{'id'}" ~.(($is_selected)?'selected':'').qq~>$shipmethod->{'name'} (~.&ZTOOLKIT::moneyformat($shipmethod->{'amount'}).qq~)</option>\n~;
				}
			$VARS{'SHIPPING_CHOOSER'} .= qq~</select>~;
			$VARS{'SHIPPING_CHOOSER'} .= qq~</span>~;
			}
		else {
#			$VARS{'SHIPPING_CHOOSER'} = '<i>Never Reached</i>';
			warn "NEVER REACHED!\n";
			}


		utf8::encode($VARS{'SHIPPING_CHOOSER'});		# make sure UPS symbols have (r)
	
		## Get the zip code from the customer.
		if ($getzip) {
			$VARS{'ZIP_INPUT'} = qq~<span id="cgi_zip_span" class="ztable_row"><label for="cgi_zip_input" id="cgi_zip_label">Enter U.S. Zip Code for Updated Total:</label> <input type="text" id="cgi_zip_input" class="zform_textbox" name="cgi.zip" size="5" maxlength="5" value="$zipcode"> <input id="cgi_zip_button_go" class="zform_button" type="submit" value="Go"></span>\n~;
			}
	
		## See if we need to tell them about international shipping
		my $ships_to_canada = 0;
		my $ships_international = 0;
		my $dsts = ZSHIP::available_destinations($CART2,$webdbref);
		foreach my $dst (@{$dsts}) {
			if ($dst->{'ISO'} eq 'US') {}
			elsif ($dst->{'ISO'} eq 'CA') { $ships_to_canada++; }
			else { $ships_international++; }
			}
		if ($ships_to_canada || $ships_international) {
			my $international = '';
			if ($ships_to_canada) { $international = 'Canadian'; }
			if ($ships_international) { $international = 'International'; }

			if ($quotelowestonly && (scalar(@{$shipmethods}) > 1)) {
				## If we're only showing them one of many U.S. shipping options, tell them so.
				$VARS{'DESTINATIONBLURB'} .= "<small><i>Quoted shipping is for U.S. destinations.  $international and other U.S. shipping quotes available upon checkout.</i></small><br>\n";
				}
			elsif ($getzip) {
				## If we're asking for a U.S. ZIP just above this, no reason to tell them the quotes presented are U.S. only.
				$VARS{'DESTINATIONBLURB'} .= "<small><i>$international shipping quotes available upon checkout.</i></small><br>\n";
				}
			else {
				## Default message.
				$VARS{'DESTINATIONBLURB'} .= "<small><i>Quoted shipping is for U.S. destinations.  $international shipping quotes available upon checkout.</i></small><br>\n";
				}
			}

		## Show the required trademark/etc. information.
		#if (defined($meta->{'force_blurb'}) && ($meta->{'force_blurb'} ne '')) {
		#	$VARS{'DESTINATIONBLURB'} .= "$meta->{'force_blurb'}<br>\n";
		#	}

		# print STDERR "QS: $qs Chooser: $VARS{'SHIPPING_CHOOSER'}\n";
		
		# Get what the cart should look like
		my $out = "";
		if ((defined $iniref) && ($iniref->{'_PREVIEW'})) {
			$VARS{'FORM'}=qq~<form onSubmit="return false;">\n~; 
			$VARS{'ENDFORM'}='</form>';
			$mode = 'SITE';
			}
		elsif ($mode eq 'CALLCENTER') {
			## no analytics for the call center
			}
		else {
			## GOOGLE ANALYTICS CROSS DOMAIN LINKING CODE
			##  http://code.google.com/apis/analytics/docs/gaTrackingSite.html#multipleDomains
			$VARS{'ANALYTICS'} = (int($SITE->nsref()->{'analytics:linker'})==0)?'':q~ onsubmit="javascript:pageTracker._linkByPost(this);" ~;

			my $cart_url = $SITE->URLENGINE()->get('cart_url');
			$VARS{'FORM'} = qq~<form $VARS{'ANALYTICS'} id="$VARS{'FORMID'}" name="$VARS{'FORMID'}" action="$cart_url" method="post">\n~;
			$VARS{'FORM'} .= sprintf('<input type="hidden" name="return" value="%s">',$SITE->continue_shopping_url());
			$VARS{'ENDFORM'}='</form>';
			}
	
		$VARS{'CONTINUE_BUTTON'} = &TOXML::RENDER::RENDER_SITEBUTTON({'button' => 'continue_shopping', 'alt' => 'Continue Shopping', 'name' => 'continue'},undef,$SITE);
	
		$VARS{'PAYPAL_BUTTON'} = '';
		$VARS{'GOOGLE_BUTTON'} = '';
		$VARS{'AMZPAY_BUTTON'} = '';
		if ($mode eq 'CALLCENTER') {
			## no buttons for the call center
			$VARS{'CONTINUE_BUTTON'} = '';
			}
		elsif ($SITE::CART2->count('real')) {	
			$VARS{'UPDATECART_BUTTON'} = &TOXML::RENDER::RENDER_SITEBUTTON({'button' => 'update_cart', 'alt' => 'Update Cart', 'name' => 'update'},undef,$SITE);
			$VARS{'EMPTYCART_BUTTON'} = &TOXML::RENDER::RENDER_SITEBUTTON({'button' => 'empty_cart',  'alt' => 'Empty Cart',  'name' => 'empty'},undef,$SITE);
			$VARS{'CHECKOUT_BUTTON'} = &TOXML::RENDER::RENDER_SITEBUTTON({'button' => 'checkout', 'alt' => 'Checkout', 'name' => 'checkout'},undef,$SITE);
			$VARS{'PAYPAL_BUTTON'} = &TOXML::RENDER::RENDER_SITEBUTTON({'button' => 'paypal' },undef,$SITE);
			# $VARS{'AMZPAY_BUTTON'} = &TOXML::RENDER::RENDER_SITEBUTTON({'button' => 'amzpay' },undef,$SITE);
			# $VARS{'GOOGLE_BUTTON'} = &TOXML::RENDER::RENDER_SITEBUTTON({'button' =>' google' },undef,$SITE);

			## NOTE: for some reason this SITEBUTTON doesn't seem to work
         #if ($webdbref->{'google_api_env'}>0) {
         #   require ZPAY::GOOGLE;
         #   $VARS{'GOOGLE_BUTTON'} = &ZPAY::GOOGLE::button_html($CART2,$SITE);
         #   }

			if ($webdbref->{'amzpay_env'}>0) {
				require ZPAY::AMZPAY;
				$VARS{'AMZPAY_BUTTON'} = &ZPAY::AMZPAY::button_html($CART2,$SITE);
				}

			}
		else {
			$VARS{'UPDATECART_BUTTON'} = '';
			$VARS{'EMPTYCART_BUTTON'} = '';
			$VARS{'CHECKOUT_BUTTON'} = '';
			}
	
		## BODY_SPEC
		# $CART2->shipping('flush'=>1);		

		## BUTTON_SPEC
		#$VARS{'ADDTOSITE_BUTTON'} = '';
		#if (defined $CART2) {
		#	my $is_wholesale = $CART2->get_in('is/wholesale');
		#	if ((defined $is_wholesale) && (($is_wholesale & 2)==2)) {
		#		my $addsite_url = $SITE->URLENGINE()->rewrite("/c=".$CART2->id()."/add_to_site.cgis");
		#		$VARS{'ADDTOSITE_BUTTON'} = "<a href=\"$addsite_url\">".&TOXML::RENDER::RENDER_SITEBUTTON({'button' => 'add_to_site', 'alt' => 'Add To My Site'},undef,$SITE)."</a>";
		#		}
		#	}
	
		$VARS{'FOOTER'} = $TXSPECL->translate3($footer_spec,[\%VARS],replace_undef=>1);
		##
		## END CART SPECIFIC CODE
		##
		}
	elsif (($mode eq 'PRINT_INVOICE') || ($mode eq 'PRINT_PACKSLIP') || ($mode eq 'EMAIL')) {
		$iniref->{'ALTERNATE'} = 0;
		$VARS{'FOOTER'} = '';
		}
	elsif ($mode eq 'CHECKOUT') {
		}
	elsif ($mode eq 'INVOICE') {
		}
	elsif ($mode eq 'CALLCENTER') {
		}


	my $otherfees = 0;

	if (not defined $cart2{'our/tax_rate'}) {
		$cart2{'our/tax_rate'} = 0;
		# warn "tax_rate is not set in CART2::VIEW (this should never happen)\n";
		}

	if ((defined $cart2{'cart/buysafe_val'}) && ($cart2{'cart/buysafe_val'}>0)) {			
		## in SITE and CHECKOUT modes we haven't purchased, so we always show buysafe logic (if available)
		## BUYSAFE_ENABLED is a bitwise value:
		##		1 = yep, it's enabled
		##		3 = don't allow prompting/checkboxes (used after an order is placed)
		if ($mode eq 'SITE') { $VARS{'BUYSAFE_ENABLED'}=1; }
		elsif ($mode eq 'CHECKOUT') { $VARS{'BUYSAFE_ENABLED'}=1; }
		elsif 
			(($mode eq 'EMAIL') || ($mode eq 'CALLCENTER') || ($mode eq 'INVOICE') || ($mode eq 'PRINT_INVOICE') || ($mode eq 'PRINT_PACKSLIP')) {
			## crap, can't check for buysafe total since we have seller pays
			$VARS{'BUYSAFE_ENABLED'}=3;	
			}			
		}


	if ($VARS{'BUYSAFE_ENABLED'}==0) {
		}
	elsif (not defined $iniref->{'SURCHARGE_BND_SPEC'}) {
		##
		## buySAFE Opt-In
		## buySAFE Free
		##
				
		$iniref->{'SURCHARGE_BND_SPEC'} = q~<tr>
<td><!-- null cell --></td>
<td nowrap align=right class="ztable_row<% print($row.alt); %>">

<input type=hidden id="ship.bnd_purchased" name="ship.bnd_purchased" value="<% print($BUYSAFE_PURCHASED); %>">
<script type="text/javascript">
<!--//
function buySAFEOnClick(WantsBond) {
	// alert("<% print($FORMID); %>");
	document.<% print($FORMID); %>['ship.bnd_purchased'].value = (String(WantsBond)=='true')?1:0;
	document.<% print($FORMID); %>.submit();
	}

//--></script>
<% load($BUYSAFE_BONDINGSIGNAL); format(posttext=>":"); default(""); print(); %>
<br><a target="_buysafe" href="<% print($BUYSAFE_CARTDETAILSURL); print(""); %>">
<span class='ztable_row<% print($row.alt); %>'>
<% print($BUYSAFE_CARTDETAILSDISPLAYTEXT); print(""); %>
</span>
</a>
	</td>
	<td nowrap align="right" valign="top"  class="ztable_row<% print($row.alt); %>">
	<% print($BUYSAFE_BONDCOSTDISPLAYTEXT); print(""); %>
	</td>
</tr>
~;

	my $graphics_url = $SITE->URLENGINE()->get('graphics_url');
	$VARS{'BUYSAFE_DISPLAY'} = '';
	$VARS{'BUYSAFE_PURCHASED'} = $cart2{'want/bnd_purchased'};
	$VARS{'BUYSAFE_SURCHARGETXT'} = $cart2{'sum/bnd_total'};
	$VARS{'BUYSAFE_CARTDETAILSDISPLAYTEXT'} = $cart2{'cart/buysafe_cartdetailsdisplaytext'};
	$VARS{'BUYSAFE_CARTDETAILSURL'} = $cart2{'cart/buysafe_cartdetailsurl'};
	$VARS{'BUYSAFE_BONDINGSIGNAL'} =	$cart2{'cart/buysafe_bondingsignal'};
	$VARS{'BUYSAFE_BONDCOSTDISPLAYTEXT'} =	$cart2{'cart/buysafe_bondcostdisplaytext'};
	if ($VARS{'BUYSAFE_ENABLED'} & 2) {
		## this item has already been purchased!
		$VARS{'BUYSAFE_BONDINGSIGNAL'} = $cart2{'sum/bnd_method'};
		$VARS{'BUYSAFE_BONDCOSTDISPLAYTEXT'} = sprintf("\$%.2f",$cart2{'sum/bnd_total'});
		}

	}


	my $out = '';
	if (not defined $iniref->{'COLS'}) { $iniref->{'COLS'} = 1; }					# how many products in a row
	if (not defined $iniref->{'ALTERNATE'}) { $iniref->{'ALTERNATE'} = 1; }		# the alternate bg color setting.
	if (not defined $iniref->{'TOTALCOLS'}) { $iniref->{'TOTALCOLS'} = 5; $VARS{'TOTALCOLS'} = 5; }		# total number of columns in the cart table


	my ($headrow,$evenrow,$oddrow) = $TXSPECL->initialize_rows($iniref->{'ALTERNATE'});
	$headrow->{'row.alt'} = 0;       # this is normally set in process_list

	# If cart linking is disabled, disable it.
	if (not defined($webdbref->{'dev_nocartlink'})) { $webdbref->{'dev_nocartlink'} = 0; }


	# use Data::Dumper; print STDERR Dumper($CART2);
	# print STDERR Carp::cluck("WTF - how did we get here");

	my @items = ();
	my $rowcount = 0;
	foreach my $xitem (@{$CART2->stuff2()->items()}) {
		my $item = Storable::dclone($xitem);	## make a copy before we trash it.

		my $showall = 0;
		if ((defined $SITE::v) && (ref($SITE::v) eq 'HASH')) {
			$showall = defined($SITE::v->{'showall'}) ? $SITE::v->{'showall'} : 0 ;
			}

		# If we're not a special cart item, display it
		# The showall cgi param says show everything even if its a special cart item.

		my $esc_key = $item->{'stid'};	
		$esc_key =~ s/([^a-zA-Z0-9_\.\-])/uc(sprintf("%%%02x",ord($1)))/eg;
		# $esc_key = &ZTOOLKIT::short_url_escape($esc_key);
		# print STDERR "ESC_KEY: $esc_key\n";

		my %p = %{$item};

		if ($VARS{'BUYSAFE_ENABLED'}>0) {
		
			#/httpd/site/graphics/general/buysafe/other/buysafe_45x16_mini_0506.gif
			#/httpd/site/graphics/general/buysafe/other/buysafe_53x17_item_0506.gif
			#/httpd/site/graphics/general/buysafe/other/buysafe_53x28_item_available_0506.gif
			#/httpd/site/graphics/general/buysafe/other/buysafe_53x28_item_bonded_0506.gif
			#/httpd/site/graphics/general/buysafe/other/buysafe_66x45_medallion_0506.gif
			$p{'BOND_STATUS'} = $item->{'buysafe_html'};


			}

	
		$p{'STID'} = $item->{'stid'};
		$p{'SKU'} = $item->{'sku'};
		$p{'PRODUCT_ID'} = $item->{'product'};
		$p{'PRICE'} = $item->{'price'};
		$p{'EXTENDED'} = $item->{'price'} * $item->{'qty'};


		## merge zoovy:prod_name, etc. into hash
		#if (defined $item->{'full_product'}) { 
		#	}
		#elsif (substr($stid,0,1) eq '%') {  # promotion
		#	$item->{'full_product'} = $item->{'%attribs'};	# hmm.. zoovy:prod_image1 should be set.
		#	}
		#else {
		#	require PRODUCT;
		#	my ($P) = PRODUCT->new($O->username(),$pid);
		#	if (defined $P) {
		#		$item->{'full_product'} = $P->prodref();
		#		}
		#	}

		foreach my $k (keys %{$item->{'%attribs'}}) {
			$p{$k} = $item->{'%attribs'}->{$k};
			}
		$p{'QTY'} = &ZTOOLKIT::def($item->{'qty'});

		my $stid = $item->{'stid'};
		my $pid = $item->{'product'};
		my $claim = $item->{'claim'};
		my $weight = &ZTOOLKIT::def($item->{'weight'});
		my $taxable = &ZTOOLKIT::def(STUFF::taxable($item->{'taxable'})?'Y':'N');
		my $description = &ZTOOLKIT::def($item->{'description'});
		if ((not defined $p{'prod_name'}) || ($p{'prod_name'} eq '')) { $p{'prod_name'} = $description; }
		if ((not defined $p{'prod_name'}) || ($p{'prod_name'} eq '')) { $p{'prod_name'} = $p{'zoovy:prod_name'}; }

		## DEFAULT SOME VARIABLES
		if (not defined $p{'zoovy:prod_name'}) { $p{'zoovy:prod_name'} = $description; }	# handy for promotions!
		if (not defined $p{'zoovy:prod_thumb'}) { $p{'zoovy:prod_thumb'} = ''; }	# handy for promotions!
		if ($p{'zoovy:prod_thumb'} eq '') { $p{'zoovy:prod_thumb'} = $p{'zoovy:prod_image1'}; }	# default to image1
		if (not defined $p{'zoovy:prod_thumb'}) { $p{'zoovy:prod_thumb'} = ''; }	# handy for promotions!

		my $assembly_component = ((defined $item->{'asm_master'}) && ($item->{'asm_master'} ne ''))?1:0;
		if ($assembly_component) { 
			$item->{'assembly_master'} = $item->{'asm_master'};		## STUFF2 COMPATIBILITY
			$item->{'+SKIPALTERNATE'}++;  ## since assembly components follow their master, they should have the same row color
			}	
		# if ($assembly_component) { $out .= "&nbsp;&nbsp;+&nbsp;"; }

		next if (($p{'QTY'} <= 0) && (not $showall));

		$p{'SKU_LINK'} = q~<a class="zlink" href="<% print($PROD_URL); %>"><% print($SKU); %></a>~;
		my $home_url = $SITE->URLENGINE()->get("home_url");
		# print STDERR "Creating SKU_LINK for MODE: $mode\n";

		if ($mode eq 'CALLCENTER') {
			## leave the SKU link in place for callcenter apps.
			}
		elsif ($mode eq 'PR_FEEDBACK') {
			if (index($stid,'%') >= 0) {
				## don't allow feedback for promotions
				$p{'SKU_LINK'} = q~<% print($SKU);  %>~;
				}
			else {
				## power reviews form, send the PID not the SKU
				$p{'SKU_LINK'} = q~<% print($SKU);  %><div class='zdiv_button_link'><button class="zform_button" onClick='document.location="~.$home_url.q~_powerreviews?verb=writereview&pr_page_id=~.$pid.q~";'>Leave Feedback</button></div>~;
				}
			}
		elsif ($mode eq 'FEEDBACK') {
			if (index($stid,'%') >= 0) {
				## don't allow feedback for promotions
				$p{'SKU_LINK'} = q~<% print($SKU);  %>~;
				}
			## zoovy reviews, note this was apparently called feedback on purpose because too many other things
			##	are named reviews and it just gets confusing. 
			## send the PID not the SKU
			else {
				my $href = $home_url.q~/popup.pl?verb=INIT_REVIEWS&pg=*reviews&fl=pop_reviews_ajax&product=~.$pid;
				$p{'SKU_LINK'} = q~<% print($SKU);  %><div class='zdiv_button_link'><button onclick="window.open('~.$href.q~','review','width=500,height=500,scrollbars=yes');" class="zform_button">Leave Feedback</button></div>~;
				}
			}
		elsif (($webdbref->{'dev_nocartlink'} == 1) || ($mode ne 'SITE')) {
			$p{'SKU_LINK'} = q~<% print($SKU);  %>~;
			}


		if (not defined $item->{'force_qty'}) { $item->{'force_qty'} = 0; }
		if (not defined $claim) { $claim = 0; }
		
		$p{'QTY_INPUT'} = '<% print($QTY); %>';
		if ((($mode eq 'SITE' || $mode eq 'CALLCENTER')) && (int($claim)==0) && (index($stid,'%') == -1) && ($item->{'asm_master'} eq '') && ($item->{'force_qty'}==0)) {
			# external cart items can't have the quantity editable but everything else can!
			$p{'QTY_INPUT'} = '<input class="z_textbox" type="text" name="QTY-<% print($STID); %>" value="<% print($QTY); %>" size="4" maxlength="4">';
			}

		
		# If we're in cart mode, put the (remove) link next to the item's description
		# BH: added % since you can't remove discounts (yet)
		$p{'REMOVE_LINK'} = '';
		$p{'SAFESTID'} = $esc_key;
		if (index($stid,'%') >= 0) {}		## can't remove promotions, ever!
		elsif ($assembly_component) { 
			$p{'REMOVE_LINK'} = " <i>(included)</i> "; 
			} ## assembly master items cannot be removed/edited by themselves.
		elsif ( $mode eq 'CALLCENTER' ) {
			$p{'REMOVE_LINK'} = qq~<a href="javascript:removeSTID('$stid');">(Remove)</a>~;
			}
		elsif ( $mode eq 'SITE' ) {
			$p{'REMOVE_LINK'} = $remove_link_spec;
			}
		
		if (1) { ## has options (note we need to run this code so we have $p{'POGS'} setup properly
			my @pogitems = ();
			my @pog_sequence = ();

			if ((defined $item->{'%options'}) && (ref($item->{'%options'}) eq 'HASH')) {
				## note: some orders (corrupt) have $item->{'*options'} set to '' instead of {}
				@pog_sequence = ();
				foreach my $pogval (sort keys %{$item->{'%options'}}) {
					push @pog_sequence, $pogval;
					}
				}

			## don't trust optionstr it gets truncated (not sure how) .. or at least it doesn't include text items.
			## it has a max length of 50 characters so options may be discarded, i can't imagine a situation where it
			## would *EVER* be conceivable that it was better.  2012/10/12 - BH
			#if ($item->{'optionstr'} ne '') {
			#	## optionstr is MUCh better than pog sequence because we can split on it.
			#	## ex: :A800:A900
			#	@pog_sequence = split(/[:\/]+/,$item->{'optionstr'});
			#	}

			if ($item->{'pog_sequence'} ne '') { 
				## note: @pog_sequence must be the four digit sequence e.g. #Z01 
				##		whereas $item->{'pog_sequence'} is a comma separated list of key/values
				## ex: A8,A9
				my %tmp = ();		# %tmp is a quick lookup table.
				foreach my $k (@pog_sequence) { $tmp{substr($k,0,2)} = $k; }
				@pog_sequence = ();
				foreach my $k (split(/,/,$item->{'pog_sequence'})) {
					if (length($k)==4) { push @pog_sequence, $k; $k = ''; }	# in case $item->{'pog_sequence'} ever goes 4 chars.
					next if ($k eq '');
					push @pog_sequence, $tmp{$k};	
					}
				undef %tmp;
				}
			## TODO: hmm... if $item->pog_sequence ever doesn't have a particular pog, bad things will happen!
			##			which could be a good thing (invisible pogs?) .. don't know.. interesting. leave as is for now.

				
			foreach my $k (@pog_sequence) {
				## note: prompt, value, img
				next if ($k eq ''); 	# sometimes, we have a bad day.
				my $ref = {};
				if (defined $item->{'%options'}->{$k}) { $ref = Storable::dclone($item->{'%options'}->{$k}); }

				$ref->{'value'} = $ref->{'data'};		## legacy compatibility for stuff v1/old specs

				## special code to handle blank text notes
				next if ((substr($k,0,2) eq '##') && ($ref->{'value'} eq ''));

				if (not defined $ref->{'prompt'}) { $ref->{'prompt'} = "PROMPT NOT SET $k='$ref->{'value'}'"; }
				#$ref->{'value'} = &ZOOVY::incode($ref->{'value'});
				# $ref->{'value'} =~ s/\n/\<br\>\n/sg;
				# ZTOOLKIT::htmlify($ref->{'value'});

				#if ((defined $ref->{'modifier'}) && ($ref->{'modifier'} ne '')) {
				#	## 2011/10/18 - this appears legacy code, we should try and  remove this in the future. 
				#	my $tmp = &POGS::parse_meta($ref->{'modifier'});
				#	foreach my $kz (keys %{$tmp}) { 
				#		next if (defined $ref->{$kz});		## note: this will overwrite prompt if removed.
				#		$ref->{$kz} = $tmp->{$kz}; 
				#		}  # make meta (e.g. img, html) accessible
				#	}
				
				push @pogitems, $ref;
				}
			## pog_spec likes: 
			## 		prompt
			##			value


#			use Data::Dumper; print STDERR Dumper($item->{'%options'},\@pog_sequence,\@pogitems);
#			die();

			$p{'POGS'} = $TXSPECL->process_list(
				'spec'=>$pog_spec,
				'items'=>[@pogitems],
				'divider'=>$iniref->{'POGDIVIDER'},
				'item_tag'=>'OPTION',
				'cols'=>$iniref->{'POGCOLS'},
				);
			undef @pogitems;
			}

		$p{'PROD_URL'} = $SITE->URLENGINE()->get('product_url').'/'.$pid; ## Set the URL for this particular product

		## note: we need to pre-translate these so that variables such as %SKU% etc will get properly interoplated.	
		## HEY -- STUPID, READ THE FUCKING LINE ABOVE, THEN GO DOWN AND ADD THIS TO PREPROCESS -- SEARCH FOR QTY_INPUT
		$p{'BOND_STATUS'} = $TXSPECL->translate3($p{'BOND_STATUS'},[\%p,\%VARS,$item],replace_undef=>0);
		$p{'QTY_INPUT'} = $TXSPECL->translate3($p{'QTY_INPUT'},[\%p,\%VARS],replace_undef=>0);
		$p{'SKU_LINK'} = $TXSPECL->translate3($p{'SKU_LINK'},[\%p,\%VARS],replace_undef=>0);
		$p{'REMOVE_LINK'} = $TXSPECL->translate3($p{'REMOVE_LINK'},[\%p,\%VARS],replace_undef=>0);


		push @items, \%p;
		$rowcount++;
		}


	##
	## Subtotal + Tax
	##

	

	# display the subtotal
	if (not defined $cart2{'our/tax_rate'}) { $cart2{'our/tax_rate'} = 0; }
	# my ($subtotal,$weight,$tax_total,$taxable,$itemcount) = $O->stuff()->totals($cart{'tax_rate'});

	## figure out the order that we should do each fee in
	foreach my $x ('shp','ins','hnd','spc','spx','spy','spz','bnd','gfc','pnt','pay') {
		## hmm, until the tax line can be rendered as part of the specialty specs we're kinda stuck.
		}

	# display the tax...  tax rate will be displayed if there is a tax rate other than zero, even if the total tax is 0 (this can happen if none of the items in the cart are taxable)
	if (not defined $cart2{'sum/tax_total'}) { $cart2{'sum/tax_total'} = 0; }
	$VARS{'TAXRATE'} = $cart2{'our/tax_rate'};
	$VARS{'TAXTOTAL'} = $cart2{'sum/tax_total'};

	#if (defined $orderattribs) {
	if (1) {
		## figure out what shipping is, and if tax on shipping should be applied.
		if (not defined $webdbref->{'ins_optional'}) { $webdbref->{'ins_optional'} = 0; }
		$VARS{'SHIPMETHOD'} = $cart2{'sum/shp_method'};
		$VARS{'SHIPVALUE'} = $cart2{'sum/shp_total'};
		$VARS{'SHIPVALUE'} = sprintf("%.2f",$VARS{'SHIPVALUE'});

		#if ($cart2{'is/shp_taxable'}) { 
		#	$VARS{'TAXTOTAL'} += ($VARS{'SHIPVALUE'} * ($VARS{'TAXRATE'}/100)); 
		#	}
		}

	$VARS{'SUBTOTAL'} = $cart2{'sum/items_total'};
	$VARS{'TOTALCOUNT'} = $cart2{'sum/items_count'};

	$VARS{'TAX_LINE'} = '';
	if ($cart2{'sum/tax_total'}>0) {
		$VARS{'TAX_LINE'} = $TXSPECL->translate3($tax_spec,[\%VARS,$oddrow,$headrow],replace_undef=>0);
		}


	$VARS{'PAYMENT_LINES'} = '';
	$VARS{'BALANCEDUE_LINE'} = '';

	if (ref($CART2) ne 'CART2') {
		&ZOOVY::confess("","NON CART2 OBJECT PRETENDING TO BE CART2",justkidding=>1);
		}
	elsif ($mode eq 'PRINT_PACKSLIP') {
		## no payment information on packing slips!
		}
	elsif ($mode eq 'EMAIL') {
		## emails will always be authorized (not captured) so the balance_due will confused the customer.
		}
	elsif (not $CART2->is_order()) {
		## don't show payments on TEMP orders (that haven't been placed yet)
		}
	elsif ($CART2->is_order()) {
		my $pay_spec = $iniref->{'SURCHARGE_PAY_SPEC'};
		if (not defined $pay_spec) { $pay_spec = $surcharge_spec; }

		my $balancedue = $CART2->in_get('sum/order_total');

		foreach my $payment (@{$CART2->payments()}) {
			#  $VAR1 = { 'due' => '23.00', 'ts' => '1258749488', 'txn' => '5769F14DF7BCD5BQ.1', 'uuid' => '5769F14DF7BCD5BQ.1', 'tender' => 'GIFTCARD', 'note' => 'Spent $80.00 on card 5769-xxxx-xxxx-D5BQ [#246]', 'amt' => '80.00' };
			# next if (($payment->{'tender'} eq 'GIFTCARD') && (substr($payment->{'ps'},0,1) eq '0'));	# skip giftcards because those get their own lines
			next if ($payment->{'voided'}>0);
			next if (substr($payment->{'ps'},0,1) eq '2');	# skip gw error
			next if (substr($payment->{'ps'},0,1) eq '9');	# skip ise
			next if (substr($payment->{'ps'},0,1) eq '6');	# skip void
			next if ($payment->{'uuid'} eq '');	# wtf?!?
			next if ($payment->{'tender'} eq 'ZERO');		# never show "zero" payments they confused the customer.
			next if ($payment->{'tender'} eq 'LAYAWAY');		# never show "zero" payments they confused the customer.
			my $note = $payment->{'note'};
			if ($note eq '') { $note = $payment->{'tender'}; }

			my $AMT = $payment->{'amt'};
			if (substr($payment->{'ps'},0,1) eq '3') {
				## credits (3xx)
				}
			else {
				## 
				$AMT = 0 - $AMT;	# AMT should be negative since we're subtracting from balance_due
				}
			$AMT = sprintf("%.2f",$AMT);
			if (substr($payment->{'ps'},0,1) eq '1') {
				# special rules for pending payments
				if ( 
					($payment->{'tender'} eq 'CREDIT') || 
					($payment->{'tender'} eq 'PAYPALEC') ||
					($payment->{'tender'} eq 'PAYPAL') 
					) {
					## pending paypal, paypalec, and credit card payments DO NOT go towards BALANCE_DUE
					$balancedue += $AMT; # an authorized payment, AND we're in 'SITE' mode
					}
				else {
					## NOTE: when displaying to customer, weprobably shouldn't remove these pending payments from balance_due
					$balancedue += $AMT;	# not an "authorized" payment
					}
				}
			else {
				$balancedue += $AMT;	# remember: $AMT is negative, so we're really subtracting.
				}

			$VARS{'PAYMENT_LINES'} .= 
				$TXSPECL->translate3($pay_spec,[
					{SURCHARGEID=>"surcharge_pay_spec",SURCHARGE=>$note,SURCHARGEVALUE=>$AMT },
					\%VARS,$payment],replace_undef=>0);
			}

#		$VARS{'PAYMENT_LINES'} =  q~
#<tr>
#        <td width="70%">&nbsp;</td>
#        <td nowrap align="right" class="ztable_head"><strong>Payment: </strong></td>
#        <td width="12%" nowrap align="right" class="ztable_head"><strong><% load($GRANDTOTAL);  format(money);  print(); %></strong></td>
#</tr>
#~;
	
		my $balancedue_spec = $iniref->{'BALANCE_SPEC'};
		if (not defined $balancedue_spec) { $balancedue_spec = $surcharge_spec; }

		$VARS{'BALANCEDUE_LINE'} = $TXSPECL->translate3($balancedue_spec,[
			{SURCHARGEID=>"balance_spec",SURCHARGE=>"<b>Balance Due</b>",SURCHARGEVALUE=>$balancedue },
			\%VARS],replace_undef=>0);
		}

	##
	## SHIPPING AND OTHER SURCHARGES
	##

	## SPC_ handler display the payment surcharge special cart item.
	$VARS{'SURCHARGE_LINE'} = '';
	my $sum_taxable = 0;
	my $sum_tax_total = 0;

	# print STDERR Data::Dumper::Dumper($CART2);
	foreach my $x ('shp','ins','hnd','spc','bnd','spz','spx','spy') {

		my $xtotal = sprintf("sum/%s_total",$x);
		# print STDERR sprintf("CART2::VIEW DEBUG [$x] '%s' '%s' '%s' \n",$xtotal,$cart2{$xtotal},(not defined $cart2{"sum/$x\_total"})?'undef':1);

		# print STDERR "$x [".$cart{$x.'_total'}."]\n";
		next if (not defined $cart2{"sum/$x\_total"});
		next if (($x ne 'shp') && ($x ne 'bnd') && ($cart2{"sum/$x\_total"} == 0));		# always show shipping regardless of price

		next if (($x eq 'bnd') && ($VARS{'BUYSAFE_ENABLED'} == 0)); 		# for bonds, don't show if the total is zero.

		## NOTE: the following line isn't needed anymore since ins_total won't be set if the insurance is optional and not selected!
		## next if (($x eq 'ins') && ($webdbref->{'ins_optional'}) && (not $cart{'ins_purchased'})); # don't show insurance if it's 

		my $description = $cart2{"sum/$x\_method"};

		if ($description eq '') { 
			if ($x eq 'spc') { $description = 'Speciality Fee'; }
			elsif ($x eq 'hnd') { $description = 'Handling Fee'; }
			elsif ($x eq 'ins') { $description = 'Insurance Fee'; }
			elsif ($x eq 'shp') { $description = 'Shipping Fee'; }
			elsif ($x eq 'bnd') { $description = 'Bonding Fee'; }
			elsif ($x eq 'spx') { $description = 'Specialty Fee #1'; }
			elsif ($x eq 'spy') { $description = 'Specialty Fee #2'; }
			elsif ($x eq 'spz') { $description = 'Specialty Fee #3'; }
			}

		if (($description eq '') && ($x eq 'shp')) { 
			$description = 'Shipping'; 
			# $cart2{'sum/shp_method'} = 'Shipping'; 
			}


		my $total = $cart2{"sum/$x\_total"}; 
		next if ((not defined $total) || ($total eq ''));


		if ($cart2{"is/$x\_taxable"}) { 
			$sum_tax_total += ($total * ($VARS{'TAXRATE'}/100));
			$sum_taxable += $total;
			## $total += ($total * ($VARS{'TAXRATE'}/100)); 	# don't modify the shipping total.
			## $cart2{'sum/tax_total'} += ($total * ($VARS{'TAXRATE'}/100));
			}

		my $linespec = $surcharge_spec;
		if (defined $iniref->{'SURCHARGE_'.uc($x).'_SPEC'}) { 
			## e.g. SURCHARGE_BND_SPEC, SURCHARGE_INS_SPEC
			$linespec = $iniref->{'SURCHARGE_'.uc($x).'_SPEC'}; 
			}

		if ($x eq 'shp') {
			if (defined $VARS{'SHIPPING_CHOOSER'}) { $description = $VARS{'SHIPPING_CHOOSER'}; }
			# if ($description eq '') { delete $cart2{'sum/shp_total'}; }	# reset shipping to zero so it doesn't add to grandtotal
			}


		next if ($description eq ''); 	# a blank description means DO NOT SHOW (requires zip or something)

		$VARS{'SURCHARGEID'} = lc('SURCHARGE_'.uc($x).'_SPEC');
		$VARS{'SURCHARGE'} = $description; 
		$VARS{'SURCHARGEVALUE'} = sprintf("%.2f",$total);
		$VARS{'SURCHARGE_LINE'} .= $TXSPECL->translate3($linespec,[\%VARS,$oddrow,$headrow],replace_undef=>0);

		next if ($x eq 'shp');
		## SKIP adding to otherfees total if it's insurance or bonding, it's optional, AND it's not purchased.
		next if ((($x eq 'ins') || ($x eq 'bnd')) && ($cart2{"is/$x\_optional"}) && (not $cart2{"will/$x.\_purchased"}));
		$otherfees += $cart2{"sum/$x\_total"};
		}

	## 
	## Grandtotal (needs to be computed here for giftcards)
	##	

	$sum_tax_total = sprintf("%.2f",int($sum_taxable * $cart2{'our/tax_rate'}) / 100);	# do this to fix up rounding errors.
	my $grandtotal = sprintf("%.2f",($cart2{'sum/items_total'}*1000 + $cart2{'sum/tax_total'}*1000 + $cart2{'sum/shp_total'}*1000 + $otherfees*1000)/1000);
	# print STDERR "GRAND: $grandtotal";
	## now, apply any giftcards

	# print STDERR "CALLER: ".Carp::cluck()."\n";
	if ($CART2->has_giftcards()>0) {
		## fake orders (not checked out) show giftcards before the Grand Total - whereas order shows them under balance due.
		my $gfctotal = $cart2{'sum/gfc_total'};

		if ($gfctotal>0) {
			my $gfcbalance = 0;
			if ($gfctotal > $grandtotal) {
				## our giftcard is for more than the order total.
				$gfcbalance = $gfctotal - $grandtotal;
				$gfctotal = $grandtotal;
				$grandtotal = 0;
				}
			else {
				$grandtotal = $grandtotal - $gfctotal;
				$gfcbalance = 0;
				}
			my $gfcspec = (defined $iniref->{'SURCHARGE_GFC_SPEC'})?$iniref->{'SURCHARGE_GFC_SPEC'}:$surcharge_spec;
			$VARS{'SURCHARGEID'} = lc('SURCHARGE_GFC_SPEC');
			$VARS{'SURCHARGE'} = sprintf('$%.2f in GiftCard(s)', $cart2{'sum/gfc_total'});
			$VARS{'SURCHARGEVALUE'} = sprintf("%.2f",$gfctotal);
			$VARS{'SURCHARGE_LINE'} .= $TXSPECL->translate3($gfcspec,[\%VARS,$oddrow,$headrow],replace_undef=>0);
			if ($gfcbalance > 0) {
				$VARS{'SURCHARGE'} = 'GiftCard(s) Balance:';
				$VARS{'SURCHARGEVALUE'} = $gfcbalance;
				$VARS{'SURCHARGE_LINE'} .= $TXSPECL->translate3($gfcspec,[\%VARS,$oddrow,$headrow],replace_undef=>0);
				}
			}
		}

#	if ($CART2->has_points()>0) {
#		my $pnttotal = $cart2{'sum/pnt_total'};
#
#		if ($pnttotal>0) {
#			my $pntbalance = 0;
#			if ($pnttotal > $grandtotal) {
#				## our giftcard is for more than the order total.
#				$pntbalance = $pnttotal - $grandtotal;
#				$pnttotal = $grandtotal;
#				$grandtotal = 0;
#				}
#			else {
#				$grandtotal = $grandtotal - $pnttotal;
#				$pntbalance = 0;
#				}
#			my $pntspec = (defined $iniref->{'SURCHARGE_PNT_SPEC'})?$iniref->{'SURCHARGE_PNT_SPEC'}:$surcharge_spec;
#			$VARS{'SURCHARGEID'} = lc('SURCHARGE_PNT_SPEC');
#			$VARS{'SURCHARGE'} = sprintf('$%.2f in GiftCard(s)', $cart2{'sum/pnt_total'});
#			$VARS{'SURCHARGEVALUE'} = sprintf("%.2f",$pnttotal);
#			$VARS{'SURCHARGE_LINE'} .= $TXSPECL->translate3($pntspec,[\%VARS,$oddrow,$headrow],replace_undef=>0);
#			if ($pntbalance > 0) {
#				$VARS{'SURCHARGE'} = 'Points Balance:';
#				$VARS{'SURCHARGEVALUE'} = $pntbalance;
#				$VARS{'SURCHARGE_LINE'} .= $TXSPECL->translate3($pntspec,[\%VARS,$oddrow,$headrow],replace_undef=>0);
#				}
#			}
#		}

	$VARS{'GRANDTOTAL'} = sprintf("%.2f",$grandtotal);
#	if (($grandtotal<0) && ($cart{'gfc_total'}>0)) {
#		## never let grandtotals drop below zero. (e.g. giftcards)
#		$VARS{'SURCHARGE'} = "Giftcard Remaining Balance";
#		$VARS{'SURCHARGEVALUE'} = $grandtotal;
#		$headrow->{'row.alt'} = 0;
#		$VARS{'SURCHARGE_LINE'} .= $TXSPECL->translate3($linespec,[\%VARS,$oddrow,$headrow],replace_undef=>0);
#		$grandtotal = 0;
#		}


	
	my @lookup = [ \%VARS ];
	if ((scalar(@items)==0) && ($noitems_spec ne '')) {
		## no items
		## NOTE: if noitems_spec is set to blank then it won't go in here. (used in minicarts)
		$out = $TXSPECL->translate3($noitems_spec,[\%VARS,$oddrow,$headrow],replace_undef=>0);
		}	
	else {
		## copied from TOXML::RENDER.pm line 2537


		$out = $TXSPECL->process_list(
			'spec'            => $spec,
			'items'           => [@items],
			'lookup'          => [\%VARS],
			'item_tag'        => 'PRODUCT',
			'alternate'       => $iniref->{'ALTERNATE'},
			'cols'            => $iniref->{'COLS'},
			                     ## These fields may have %fg% and other &translatable elements and therefore need to be preprocessed
			'preprocess'      => [ 'CART_URL', 'QTY_INPUT', 'SKU_LINK', 'REMOVE_LINK', 'BOND_STATUS' ], 
			'replace_undef'	=> 0,
			);

		}

	untie %cart2;

	undef @items;
	undef $spec;
	undef $pog_spec;
	undef $remove_link_spec;
	undef $surcharge_spec;
	undef $tax_spec;
	undef $footer_spec;
	undef $noitems_spec;
	undef %VARS;
	undef %cart2;

	return($out);
	############# LINE OF DEPRECATION -- ANYTHING ABOVE THIS LINE STAYS -- BEYOND THIS LINE GOES! #############
	}




1;
