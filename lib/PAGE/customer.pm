package PAGE::customer;

use strict; # Modules verified!
no warnings 'once';

use lib "/backend/lib";
require EXTERNAL;
require STUFF2;
require PRODUCT;
require CUSTOMER;
require CUSTOMER::TICKET;
require ZTOOLKIT;
require WHOLESALE;
require ZPAY;
require CART2;
require CART2::VIEW;
require BLAST;
require TLC;

$PAGE::customer::debug = 0;



=pod

[[STAFF]]
##
## List of officially supported URLS:
##	please keep in webdoc 50612 => PAGE::customer
##	
[[/STAFF]]

[[SECTION]Customer Service URLs]

<li> /customer/login
<li> /customer/logout
<li> /customer/addresses
<li> /customer/password
<li> /customer/forgot
<li> /customer/order/status?orderid=
<li> /customer/order/cancel?orderid=
<li> /customer/order/copy?orderid=
<li> /customer/newsletter/unsubscribe?email=
<li> /customer/newsletter/config
<li> /customer/newsletter/save
<li> /customer/wholesale/order
<li> /customer/export/inventory.xml
<li> /customer/export/inventory.csv
<li> /customer/export/products.xml
<li> /customer/export/products.csv

[[/SECTION]]

=cut


##
## sporks.zoovy.com brian@zoovy.com testtest
##

@PAGE::customer::panels = [
	{ id=>'account', title=>'Account History', gravity=>'right', func=>\&panel_account },
	];


#sub add_to_site_handler {
#	$SITE->{'+title'} = "JEDI: Add To Site";
#	$SITE->{'_FS'} = '_';
#	$SITE::PG = 'addtosite';
#	my $OUTPUT = '';
#	
#	require CUSTOMER;
#	my ($C) = $SITE::CART->fetch_property('customer');
#	my $JEDI_MID = $C->get_jedi();
#	my $JEDI_USERNAME = undef;
#	if ($JEDI_MID>0) {
#		$JEDI_USERNAME = &ZOOVY::resolve_merchant_from_mid($JEDI_MID);	
#		}
#	
#	my $S = $SITE::CART->stuff();
#	
#	if ($S->count(3)<=0) {
#		## ERROR BECAUSE NO ITEMS INC ART
#		$OUTPUT .= qq~Sorry, you must have items in your cart in order to add them to your store.~;
#		}
#	elsif ($JEDI_MID == 0) {
#		## ERROR BECAUSE JEDI_MID NOT SET
#		$OUTPUT .= qq~
#		Sorry, your account does not appear to be setup correctly for JEDI.
#		To fix this login to your Zoovy store at www.zoovy.com, go to Utilities / Suppliers and 
#		add this company as a supplier.
#		~;
#		}
#	elsif ($SITE::v->{'verb'} eq 'CONFIRM') {
#		## ADD THE ITEMS TO THE CART
#		$OUTPUT .= "JEDI ADDITION: $JEDI_USERNAME [$JEDI_MID]<br>";
#		
#		use Data::Dumper;
#		require INVENTORY;
#		require WHOLESALE;
#		require SUPPLIER;
#		require SUPPLIER::JEDI;
#	
#		my $MID = &ZOOVY::resolve_mid($SITE->username());
#		my $SCHEDULE = $SITE::CART->fetch_property('schedule');
#		my $SUPPLIER = SUPPLIER->new($JEDI_USERNAME,"#$MID");
#	
#		if (not defined $SUPPLIER) {
#			$OUTPUT .= "ERROR: SUPPLIER record could not be loaded from database<br>\n";
#			}
#	
#		my $SUPPLIER_CODE = uc($SUPPLIER->fetch_property('CODE','....'));
#		my $FOLDER = &SUPPLIER::JEDI::folder($SUPPLIER_CODE,$SITE->username());
#		$OUTPUT .= "Adding products to this folder: $FOLDER<br><br>\n";
#	 	#use Data::Dumper;  $OUTPUT .= Dumper($SUPPLIER);
#	
#		foreach my $stid ($S->stids()) {
#			#$OUTPUT .= '<pre>'.Dumper($stid,$S->{$stid}).'</pre>';
#	
#			my ($imgcount,$pid) = &SUPPLIER::JEDI::remote_pid_copy($SITE->username(),$JEDI_MID,$stid,$SCHEDULE,$SUPPLIER);
#	
#			$OUTPUT .= "Added $stid to store (imported $imgcount image".(($imgcount>1)?'s':'').")<br>";
#			}
#	
#		$OUTPUT .= "<br>Completed Adding Products\n"; 
#		}
#	else {
#		## REQUEST CONFIRMATION FROM USER
#		##	 The user needs to confirm how they want to add the items.
#	
#		$OUTPUT .= "JEDI: $JEDI_USERNAME [$JEDI_MID]<br><br>";
#		$OUTPUT .= qq~You are about to add ~.($S->count(3)).qq~ item(s) to your store, please confirm.~;
#	
#		$OUTPUT .= qq~<table><tr>~;
#		my $addsite_url = $SITE->URLENGINE()->rewrite("/c=".$SITE::CART->id()."/add_to_site.cgis");
#		$OUTPUT .= qq~<td><form action="$addsite_url"><input type="hidden" name="VERB" value="CONFIRM"><input type="submit" value=" Confirm "></form></td>~;
#		my $cart_url = $SITE->URLENGINE()->get('cart_url');
#		$OUTPUT .= qq~<td><form action="$cart_url"><input type="submit" value=" Cancel "></form></td>~;
#		$OUTPUT .= qq~</tr></table>~;
#		}
#
#	push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT };	
#	return();
#	}
#






##
##
##
## action=
##		newsletter/config: choose one or more mailing lists
##		newsletter/save: update specific newsletters on/off
##		newsletter/prompt: agree 'yes' i want to unsubscribe
##		newsletter/unsubscribe: stops all mailings
##
sub verb_newsletter {
	my ($lm,$C,$v,$cacheref,$SITE) = @_;

	require CUSTOMER;	
	require CUSTOMER::RECIPIENT;
	require CUSTOMER::NEWSLETTER;

#	use Data::Dumper;
#	print STDERR Dumper($SITE);

	my $OUTPUT = '';	
	# Note: the $SITE::v hash has all the params lowecased
	my $id       = defined($v->{'id'})           ? $v->{'id'}        : '' ;
	my $email = $C->email();
	if ($email eq '') { $email = $v->{'email'}; }

	my $VERB = $v->{'verb'};
	my $customer_url = $SITE->URLENGINE()->get('customer_url');
	
#	print STDERR "CPG: $cpg\n";

	##
	## SANITY: at this point if $softauth is non zero we can assume they are probably
	##				really who they claim to be!
	##


	my $cpnid =    defined($SITE::v->{'cpn'}) 	? $SITE::v->{'cpn'} : '';
	my $cpg =    defined($SITE::v->{'cpg'}) 	? $SITE::v->{'cpg'} : '';
	if ($cpg =~ /^\@CAMPAIGN:([\d]+)$/) { $cpg = $1; }
	my $SOFTAUTH_KEYS = '';
	if ($lm->had('SOFTAUTH-WIN')) { 
		$SOFTAUTH_KEYS = qq~<input type=hidden name="email" value="$email">
<input type=hidden name="cpn" value="$cpnid">
<input type=hidden name="cpg" value="$cpg">
~;
		}
	
	##
	## NOTE: 'prompt' + 'unsubscribe' go together (stage1 + stage2)
	## NOTE: 'newsletter/select' +  'newsletter/save
	if ($VERB eq 'newsletter/save') {
		my ($nlist) = &CUSTOMER::NEWSLETTER::available_newsletters($SITE->username(),$C->prt(),$email);
		my $LIKESPAM = 0;
		foreach my $key (@{$nlist}) {
			next if ($key->{'SUBSCRIBE'}<0);	# not available!
			if ($v->{'subscribe_'.$key->{'ID'}}) {
				$LIKESPAM += (1 << ($key->{'ID'}-1));
				}
			}		
      $C->set_attrib('INFO.IP',$ENV{'REMOTE_ADDR'});
      $C->set_attrib('INFO.NEWSLETTER',$LIKESPAM);
      $C->save();

		&CUSTOMER::RECIPIENT::coupon_action($SITE->username(),'UNSUBSCRIBED',
			CPG=>$cpg,
			CPNID=>$cpnid
			);

		$lm->pooshmsg("SUCCESS|+Successfully updated newsletter preferences");
		$VERB = 'newsletter/select';
		}

	

	if ($VERB eq 'newsletter/prompt') {
		$OUTPUT .= qq~<form action="$customer_url/newsletter/unsubscribe">
			<div class="ztxt">
			$SOFTAUTH_KEYS
			Email Address: <input type="text" size="50" name="email" value="$email"><br>
			<br>
			Are you sure you want to be removed from all mailing list(s)?<br>
			<br>
			<br><a href=\"$customer_url\">Return to Customer Account</a>
			</div>
			</form>
			~;
		}
	elsif ($VERB eq 'newsletter/unsubscribe') {
		#if (($email eq '') && (index($id,' ')>=0)) {
		#	$email = substr($id,0,index($id,' '));
		#	$id = substr($id,index($id,' ')+1);
		#	}
		$SITE->title( "Newsletter Unsubscribe" );

		$C->set_attrib('INFO.IP',$ENV{'REMOTE_ADDR'});
      $C->set_attrib('INFO.NEWSLETTER',0);
		use Data::Dumper;
		if (not $C->save()) {
			$lm->pooshmsg("ERROR|+database error occurred while updating newsletter settings");
			}

		my $home = $SITE->URLENGINE()->get('home_url');
		$OUTPUT .= qq~<div class="ztxt">
The user $email has been successfully unsubscribed from all newsletters.
</div>
<div class="ztxt">
<a href="$home">Continue Shopping</a>
</div>
~;
		}
	elsif (($VERB eq 'newsletter/select') || ($VERB eq 'newsletter/config')) {
		
		$SITE->title( "Newsletter Preferences" );
		
		$OUTPUT .= qq~
<div class="ztxt">
<p>Your current newsletter subscription preferences:<br></p>
<form action="$customer_url/newsletter/save">

<input type=hidden name="action" value="save">
$SOFTAUTH_KEYS~;

	
		my $PRT = $C->prt();
		print STDERR "EMAIL:$email\n";
		my ($nlist) = &CUSTOMER::NEWSLETTER::available_newsletters($SITE->username(),$PRT,$email);
		print STDERR Dumper($nlist);
		my $count = 0;
		foreach my $key (@{$nlist}) {
			next if (not defined $key);
			next if ($key->{'MODE'} == -1);

			## only show exclusive newsletters if the customer is subscribed to it
			next if ($key->{'MODE'} == 0 && $key->{'SUBSCRIBE'} == 0);			

			$OUTPUT .= "<label><input class=\"zform_checkbox\" type=\"checkbox\" name=\"subscribe_".($key->{'ID'})."\" ".(($key->{'SUBSCRIBE'})?'checked':'')."> ".$key->{'NAME'}."</label><br>";
			$count++;
			}
		if ($count==0) { 
			$OUTPUT .= "<div class=\"zwarn\">You have no newsletters available to you.</div><br>"; 
			}
	
		$OUTPUT .= qq~
			<br>
			<input type="hidden" name="id" value="$id">
			<input class="zform_button" type="button" onClick="document.location='$customer_url';" value=" Back ">
			<input class="zform_button zform_button1" type="submit" name="confirm" value=" Update Preferences ">
			</form>
		~;
	
		}
	elsif ($VERB eq '') {
		$OUTPUT .= qq~<p>Your request could not be processsed because action= was not passed</p>\n~;
		
		}
	else  {
		## Default subscribe unsubscribe
		$OUTPUT .= qq~<p>Your request could not be processsed (reason: unknown action \"$VERB\")</p>\n~;
		}

	$OUTPUT .= qq~
<br><a href=\"$customer_url\">Return to Customer Account</a>
</div>
~;

	$lm->pooshmsg("STOP|+verb newsletter");

	push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>$OUTPUT };
	return();	
	}


##
## edits a customer address on file.
##
## PARAMETERS:
##		type=BILL|SHIP|WS (case insensitive)
##		pos=# (defaults to 0 for "default")
##		action=SAVE|
##
sub verb_addresses {
	my ($lm,$C,$v,$cacheref,$SITE) = @_;
	require CUSTOMER;

	my $customer_url = $SITE->URLENGINE()->get('customer_url');
	my $TYPE = lc($v->{'type'});	# it's lowercase because of bill_address
	my $ACTION = uc($v->{'action'});
	
	if ($TYPE eq '') {
		$lm->pooshmsg("ERROR|+parameter 'type' must be one of: ship|bill");
		}
	elsif ($TYPE eq 'wc') {
		$lm->pooshmsg("ERROR|+no longer able to update wholesale records");
		}
	elsif (($TYPE eq 'ship') || ($TYPE eq 'bill')) {
		}
	else {
		$lm->pooshmsg("ERROR|+Unknown address type=$TYPE");
		}

	my $addr = {};
	my $SHORTCUT = uc((defined $v->{'shortcut'})?$v->{'shortcut'}:'');
	$SHORTCUT =~ s/[^A-Z0-9]+//gs;
 
	#if ($TYPE eq 'ws') {
	#	$addr = $C->fetch_attrib('WS',0);
	#	}
	#else {
	$addr = $C->fetch_address($TYPE,$SHORTCUT);
	#	}

	if (not defined $addr) {
		$lm->pooshmsg("ERROR|+address type:$TYPE shortcut:$SHORTCUT could not be loaded");
		}
	
	################################
	## save address edits
	if (not $lm->can_proceed()) {
		}
	elsif ($ACTION eq 'REMOVE') {
		$C->nuke_addr($TYPE,$SHORTCUT);
		$lm->pooshmsg("SUCCESS|+Successfully updated address");
		$lm->pooshmsg("REDIRECT|url=$customer_url|+customer address returning to customer main");
		}
	elsif ($ACTION eq 'SAVE') {
		print STDERR "Saving Address..\n";
		
		my %INFO = ();
		$INFO{'phone'} = $v->{'phone'};
		$INFO{'firstname'} = $v->{'firstname'};
		$INFO{'lastname'} = $v->{'lastname'};
		$INFO{'company'} = $v->{'company'};
		$INFO{'address1'} = $v->{'address1'};
		$INFO{'address2'} = $v->{'address2'};
		$INFO{'city'} = $v->{'city'};
		$INFO{'region'} = $v->{'region'};
		$INFO{'postal'} = $v->{'postal'};
		$INFO{'countrycode'} = $v->{'countrycode'};
		if (lc($TYPE) ne 'ship') {
			$INFO{'email'} = $v->{'email'};
			}

		$addr->from_hash(\%INFO);
		if (uc($TYPE) eq 'WS') { 
			$INFO{'BILLING_CONTACT'} = $v->{'BILLING_CONTACT'};
			$INFO{'BILLING_PHONE'} = $v->{'BILLING_PHONE'};
			$C->{'WS'} = $addr;
			}
		else {
			$C->add_address($addr,'SHORTCUT'=>$SHORTCUT);
			}
		$C->save();  
		$lm->pooshmsg("INFO|+saved TYPE:$TYPE SHORTCUT:$SHORTCUT ");

		## update address info for RECENT Orders 
		## (ie ones that have yet to be fulfilled)
		require ORDER::BATCH;
		my %options = (POOL=>'RECENT', CUSTOMER=>$C->{'_CID'});
		my ($orderset) = &ORDER::BATCH::report($SITE->username(),%options);
			
		foreach my $ID (@{$orderset}) {
			my ($O2) = CART2->new_from_oid($SITE->username(),$ID->{'ORDERID'});
			# my ($o) = ORDER->new($SITE->username(),$ID->{'ORDERID'});

			## make sure the country we're going from and to is the same before we update
			## so customers can't update to an international address.
			if (uc($O2->pu_get("$TYPE/countrycode")) eq uc($INFO{'countrycode'})) {
				$lm->pooshmsg("ERROR|+Sorry, you may not update the billing or shipping country in an order");
				}
			else {
				# $o->set_attribs(%{$addr});
				foreach my $k (keys %{$addr}) {
					$O2->pu_set(sprintf("%s/%s",$TYPE,substr($k,5)),$addr->{$k});
					}
				$O2->add_history("Customer updated $TYPE address");
				$O2->order_save();
				}
			}
		
		$lm->pooshmsg("SUCCESS|+Successfully updated address");
		$lm->pooshmsg("REDIRECT|url=$customer_url|+customer address returning to customer main");
		}

	if (not $lm->can_proceed()) {
		}
	else {
		my $CODE = $addr->shortcut();
		my $ref = $addr->as_hash();

		my $company = $ref->{'company'};
		my $firstname = $ref->{'firstname'};
		my $lastname = $ref->{'lastname'};
		my $address1 = $ref->{'address1'};
		my $address2 = $ref->{'address2'};
		my $city = $ref->{'city'};
		my $region = $ref->{'region'};
		my $postal = $ref->{'postal'};
		my $countrycode = $ref->{'countrycode'};

		my $email = $ref->{'email'};
		my $phone = $ref->{'phone'};
	
		##############################################################################
		## Output Page
		my $OUTPUT = qq~
		<form name="customerFrm" action="$customer_url/addresses" method="GET">
		<input type="hidden" name="type" value="$TYPE">
		<input type="hidden" name="shortcut" value="$SHORTCUT">
		<input type="hidden" name="action" value="SAVE">
		<table>
		<tr><td colspan=2 class="ztitle">$TYPE - $SHORTCUT</td></tr>
		<tr><td class="ztxt">First Name:</td>
		<td class="ztxt"><input size="60" class="zform_textbox" type='text' name='firstname' value="$firstname"></td></tr>
		<tr><td class="ztxt">Last Name:</td>
		<td class="ztxt"><input size="60" class="zform_textbox" type='text' name='lastname' value="$lastname"></td></tr>
		<tr><td class="ztxt">Company:</td>
		<td class="ztxt"><input size="60" class="zform_textbox" type='text' name='company' value="$company"></td></tr>
		<tr><td class="ztxt">Address:</td>
		<td class="ztxt"><input size="60" class="zform_textbox" type='text' name='address1' value="$address1"></td></tr>
		<tr><td class="ztxt">Address2:</td>
		<td class="ztxt"><input size="60" class="zform_textbox" type='text' name='address2' value="$address2"></td></tr>
		<tr><td class="ztxt">City:</td>
		<td class="ztxt"><input size="30" class="zform_textbox" type='text' name='city' value="$city"></td></tr>
		<tr><td class="ztxt">State/Region:</td>
		<td class="ztxt"><input type='text' class="zform_textbox" name='region' value="$region"></td></tr>
		<tr><td class="ztxt">Postal:</td>
		<td class="ztxt"><input type='text' class="zform_textbox" name='postal' value="$postal"></td></tr>
		<tr><td class="ztxt">Country:</td>
		<td class="ztxt"><input type='text' size="2" maxlength="2" class="zform_textbox" name='countrycode' value="$countrycode"></td></tr>
		~;

		if (uc($TYPE) ne 'SHIP') {
			$OUTPUT .= qq~
			<tr><td class="ztxt">Email:</td>
			<td class="ztxt"><input type='text' class="zform_textbox" size="30" name='email' value="$email"></td></tr>
			~;
			}

		$OUTPUT .= qq~
		<tr><td class="ztxt">Phone:</td>
		<td class="ztxt"><input type='text' class="zform_textbox" size="30" name='phone' value="$phone"></td></tr>~;

		if ($TYPE eq 'WS') {
			$OUTPUT .= qq~
		<tr><td class="ztxt">Purchasing Contact:</td>
		<td class="ztxt"><input type="text" class="zform_textbox" name="BILLING_CONTACT" value="~.&ZOOVY::incode($addr->{'BILLING_CONTACT'}).
		qq~"></td><td class="ztxt"><i>(For your internal use only)</i></td></tr>
		<tr><td class="ztxt">Purchasing Phone:</td>
		<td class="ztxt"><input type="text" class="zform_textbox" name="BILLING_PHONE" value="~.&ZOOVY::incode($addr->{'BILLING_PHONE'}).
		qq~"></td><td class="ztxt"><i>(For your internal use only)</i></td></tr>~;
			}

		$OUTPUT .= qq~<tr>
	<td colspan='2'>
	<center>
	<input class="zform_button" type="button" onClick="document.location='$customer_url';" value=" Back ">
	<input class="zform_button " type='button' onClick="customerFrm.action.value='REMOVE'; customerFrm.submit(); return false;" value=' Remove '>
	<input class="zform_button zform_button1" type='submit' value='  Save Changes  '>
	</center>
		</td></tr>
		</table>
		</form>~;
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT, };
		$lm->pooshmsg("STOP|+address handler");
		}
	
	$lm->pooshmsg("INFO|finished addresses");

	return();
	}


##
## allows a customer to create/update/manage their tickets
##
sub verb_ticket {
	my ($lm,$C,$v,$cacheref,$SITE) = @_;
	require CUSTOMER;

	my $customer_url = $SITE->URLENGINE()->get('customer_url');
	my $USERNAME = $SITE->username();

	my $OUTPUT = '';
	## NOTE: unless we do a $lm->poosh('REDIRECT') then $OUTPUT is guaranteed to have a 
	## <form id="ticketfrm"> with a <input type="hidden" name="verb" prepending to it.

	# $OUTPUT = "happy tickets handler";
	my ($VERB) = $v->{'verb'};
	my ($CT) = undef;	 ## reference to the customer ticket obj. (that was either created or loaded)

	my ($CTCONFIG) = &CUSTOMER::TICKET::deserialize_ctconfig($SITE->username(),$SITE->prt(),$SITE->webdb());
	if ($CTCONFIG->{'is_external'}==0) {
		$lm->pooshmsg("ERROR|+Sorry, but external access to cases/tickets is not currently allowed. Please contact merchant.");
		$VERB = 'deny';
		}


	## SANITY:
	if ($lm->can_proceed() && ($VERB eq 'ticket/save')) {
		## this is either a success which changes to $VERB='ticket/view'
		## or it's a failure which goes to ticket/create-fail
		my $ERROR = '';

		if ($v->{'class'} eq '') {
			$ERROR = 'Inquiry type is required';
			}
		elsif ($v->{'note'} eq '') {
			$ERROR = 'Please provide detail on your request';
			}
		elsif ($v->{'title'} eq '') {
			$ERROR = 'Ticket title is required';
			}

		if ($ERROR ne '') {
			$VERB = 'ticket/create';
			push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>sprintf("<div class=\"zwarn\">ERROR: %s</div>",$ERROR) };
			}
		else {	
			($CT) = CUSTOMER::TICKET->new($USERNAME,0,
					'PRT'=>$C->prt(),'CID'=>$C->cid(),
					'SUBJECT'=>$v->{'title'},
					'NOTE'=>$v->{'note'},
					'CLASS'=>$v->{'class'},
					'SRC'=>'CAD',
					);	
			$VERB = 'ticket/view';
			}
		}

	## SANITY: now load the ticket if we have a verb that requires a ticket.
	if (
		(($VERB eq 'ticket/view') || ($VERB eq 'ticket/update')) && 
		(not defined $CT)
		) 
		{
		my $ERROR = '';
		if (($v->{'tid'} eq '') && ($v->{'tktcode'} eq '')) {
			$ERROR = "Did not receive tid= or tktcode= parameter to ticket/view";
			}
		elsif ($v->{'tid'} ne '') {
			($CT) = CUSTOMER::TICKET->new($USERNAME,sprintf("#%d",$v->{'tid'}),'PRT'=>$C->prt(),'CID'=>$C->cid());
			if (not defined $CT) {
				$ERROR = "Sorry, could not load requested tid= from database";
				}
			}
		elsif ($v->{'tktcode'} ne '') {
			($CT) = CUSTOMER::TICKET->new($USERNAME,sprintf("+%s",$v->{'tktcode'}),'PRT'=>$C->prt(),'CID'=>$C->cid());
			if (not defined $CT) {
				$ERROR = "Sorry, could not load requested tktcode= from database";
				}
			}
		
		if ($ERROR ne '') {
			## view ticket failed, so we go back to the customer main page.
			$lm->pooshmsg("ISE|+$ERROR");
			}
		}



	if ($lm->can_proceed() && ($VERB eq 'ticket/update')) {
		## note: at this point $CT must already be set.
		my $ERROR = '';

		if (defined $v->{'close_ticket'}) {
			## if we're closing a ticket a message isn't required.
			}
		elsif (defined $v->{'open_ticket'}) {
			## if we're closing a ticket a message isn't required.
			}
		elsif ($v->{'note'} eq '') {
			$ERROR = "message must not be blank!";
			}

		if ($ERROR ne '') {
			push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>sprintf("<div class=\"zwarn\">ERROR: %s</div>",$ERROR) };
			}
		elsif ($v->{'note'} ne '') {
			$CT->changeState('UPDATE');
			$CT->addMsg('*CUSTOMER',$v->{'note'},0);
			}

		if ($v->{'close_ticket'}) {
			$CT->changeState('CLOSE');
			$CT->addMsg('*CUSTOMER',"Customer requested ticket be closed.");
			}

		if ($v->{'open_ticket'}) {
			$CT->changeState('ACTIVE');
			$CT->addMsg('*CUSTOMER',"Customer requested ticket be re-opened.");
			}


		$VERB = 'ticket/view';
		}

	if ($lm->can_proceed() && ($VERB eq 'ticket/view')) {
		$lm->pooshmsg('TITLE|+Viewing Ticket '.$CT->tktcode());

		$OUTPUT .= sprintf('<input type="hidden" name="tktcode" value="%s">',$CT->tktcode());

		my $STATUS = $CT->get('STATUS');
		$OUTPUT .= sprintf('<div id="crm_status">Status: %s</div>',$STATUS);
		if ($STATUS eq 'CLOSED') {
			$OUTPUT .= sprintf("<div id='crm_status_closed'>Closed: %s</div>",&ZTOOLKIT::pretty_date($CT->get('CLOSED_GMT')));
			}

		if (my $oid = $CT->get('ORDERID')) {
			$OUTPUT .= sprintf('<div id="crm_orderid">OrderID: %s</div>',$oid);
			}
		if (my $class = $CT->get('CLASS')) {
			$OUTPUT .= sprintf('<div id="crm_class">Class: %s</div>',$class);
			if ($class eq 'POSTSALE') {
				}
			elsif ($class eq 'PRESALE') {
				}
			elsif ($class eq 'REFUND') {
				}
			elsif ($class eq 'EXCHANGE') {
				}
			}

		require Text::Wrap;
		$OUTPUT .= sprintf("<div id='crm_subject'>Subject: %s</div>",&ZOOVY::incode($CT->get('SUBJECT'))); 
		$OUTPUT .= sprintf("<div id='crm_initial_message'><div class='crm_prompt'>Message:</div><div class='crm_message'>%s</div></div>",
			Text::Wrap::wrap("","",&ZOOVY::incode($CT->get('NOTE')))
			);

		
		## display any message updates by customer or admins
		my $msgs = $CT->getMsgs();
		if (defined $msgs) {
			foreach my $msgref (@{$msgs}) {
				next if ($msgref->{'PRIVATE'});	# never show private messages
				my $who = $msgref->{'AUTHOR'};
				if ($who eq '*CUSTOMER') { $who = $C->email(); }
				$OUTPUT .= sprintf("<div class='crm_update'><div class='crm_prompt'><b>Update %s by %s</b></div><div class='crm_message'>%s</div></div>",
					&ZTOOLKIT::pretty_date($msgref->{'CREATED_GMT'},2),
					$who,
					Text::Wrap::wrap("","",&ZOOVY::incode($msgref->{'NOTE'}))
					);

				# $OUTPUT .= Dumper($msgref);
				}
			}


		# $OUTPUT .= Dumper($CT);
		if ($CT->get('STATUS') eq 'CLOSED') {
			$OUTPUT .= qq~
<div class='crm_case_closed'><b>This case has been marked as closed/resolved.</b></div>

<input type="checkbox" name="open_ticket"> check this box if you wish to re-open this case.
~;
			}
		else {
			$OUTPUT .= qq~
<br>
<div><div>Add to message:</div><textarea rows=5 cols=70 name="note" class='zform_textarea'></textarea></div>
<input type="checkbox" name="close_ticket"> check this box to close this inquiry.
				~; 
			}

		$OUTPUT .= qq~
<div>
<input class="zform_button zform_button1" type="button" onClick="ticketfrm.verb.value='ticket/update'; ticketfrm.submit(); " name="button" value=" Update Ticket ">
<input class="zform_button zform_button1" type="button" onClick="document.location='$customer_url';" name="button" value=" Exit ">
</div>
		~;

		}
	elsif ($VERB eq 'ticket/create') {
		$lm->pooshmsg('TITLE|+Create Ticket');
	$OUTPUT .= qq~
<table>
<tr><td>
Subject/Title: <input type="textbox" size="60" value="~.&ZOOVY::incode($SITE::v->{'title'}).qq~" maxlength="60" name="title" class='zform_textbox'>
<div>
Please describe issue/concern in detail:<br>
<textarea rows=5 cols=70 name="note" class='zform_textarea'>~.&ZOOVY::incode($SITE::v->{'note'}).qq~</textarea>
</div>
<div>
Inquiry type:
<select name="class" class='zform_select'>
	<option value=""></option>
	<option ~.(($v->{'class'} eq 'PRESALE')?'selected':'').qq~ value="PRESALE">Presale Question</option>
	<option ~.(($v->{'class'} eq 'POSTSALE')?'selected':'').qq~ value="POSTSALE">Post Sale Question</option>
	<option ~.(($v->{'class'} eq 'RETURN')?'selected':'').qq~ value="RETURN">Inquire about Return</option>
	<option ~.(($v->{'class'} eq 'EXCHANGE')?'selected':'').qq~ value="EXCHANGE">Inquire about Exchange</option>
</select>
</div>

<input class="zform_button zform_button1" type="button" onClick="ticketfrm.verb.value='ticket/save'; ticketfrm.submit(); " name="button" value=" Create Ticket ">
<input class="zform_button zform_button1" type="button" onClick="document.location='$customer_url';" name="button" value=" Exit ">
</td></tr>
</table>
~;
		}
	elsif ($VERB eq 'ticket/respond') {
		}
	elsif ($lm->has_failed()) {
		## some type of error
		}
	else {
		## this will pass through back to customer/main or whatever because verb was unhandled.
		# push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>"verb_tickets received unknown verb: ".$VERB };
		$lm->pooshmsg("ISE|+verb_ticket received unknown verb: $VERB");
		}

	
	if (my $lmref = $lm->had('REDIRECT')) {
		
		}
	elsif (my $lmref = $lm->had('ISE')) {
		## not sure what this is yet, but it will do something then pass through to the main customer form.
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>sprintf("<div class=\"zwarn\">ERROR: %s</div>",$lmref->{'+'}) };
		}
	elsif ($lm->has_failed()) {
		my ($lmref) = $lm->whatsup();
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>sprintf("<div class=\"zwarn\">ERROR: %s</div>",$lmref->{'+'}) };
		}
	else {

		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>qq~
<form name="ticketfrm" id="ticketfrm" method="GET" action="$customer_url/ticket/create">
<input type="hidden" name="verb" value="">
~ };
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT };
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>qq~</form>~ };

		$lm->pooshmsg("STOP|+display ticket frm");
		}

	$lm->pooshmsg("INFO|+finished payments");

	return();
	}






##
## allows a customer to update their payments on file.
##
sub verb_payments {
	my ($lm,$C,$v,$cacheref,$SITE) = @_;
	require CUSTOMER;

	my $customer_url = $SITE->URLENGINE()->get('customer_url');

	my $OUTPUT = '';

	# $OUTPUT = "happy payments handler";
	my ($VERB) = $v->{'verb'};

	if ($VERB eq 'payments/prefer') {
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>"<div>Successfully set payment method as default</div>" };		
		my ($ID) = int($v->{'id'});
		$C->wallet_update($ID,'default'=>1);
		}

	if ($VERB eq 'payments/remove') {
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>"<div>Successfully removed payment method</div>" };		
		my ($ID) = int($v->{'id'});
		$C->wallet_nuke($ID);
		}

	if ($VERB eq 'payments/save-cc') {

		my %params = ();
		$params{'CC'} = $v->{'cc'};
		$params{'YY'} = $v->{'yy'};
		$params{'MM'} = $v->{'mm'};
		$params{'IP'} = $ENV{'REMOTE_ADDR'};
		my ($ID,$ERROR) = $C->wallet_store(\%params);
		if ($ERROR) {
			$lm->pooshmsg("ERROR|+could not store wallet reason:$ERROR");
			push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>"<div>could not store wallet reason: $ERROR</div>" };		
			}
		else {
			push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>"<div>Successfully added payment method</div>" };		
			}
		}

	if ($VERB eq 'payments/add-cc') {
		$OUTPUT = qq~
<form method="POST" action="$customer_url/payments/save-cc">
<table>
	<tr>
		<td class="ztxt">Credit Card:</td><td class="ztxt"><input class="zform_textbox" size="20" type="textbox" name="CC"></td>
	</tr>
	<tr>
		<td class="ztxt">Exp Month (MM):</td><td class="ztxt"><input class="zform_textbox" size="2" type="textbox" name="MM"></td>
	</tr>
	<tr>
		<td class="ztxt">Exp Year (YY):</td><td class="ztxt"><input class="zform_textbox" size="2" type="textbox" name="YY"></td>
	</tr>
	<tr>
		<td colspan=2>
		<input class="zform_button" type="button" onClick="document.location='$customer_url';" value=" Go Back ">
		<input class="zform_button zform_button1" type="submit" value=" Save ">
		</td>
	</tr>
</table>
</form>
~;
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT, };
		$lm->pooshmsg("STOP|+payments handler");
		}
	
	$lm->pooshmsg("INFO|+finished payments");

	return();
	}




## recover password
##
## has several different stages:
##		login=> prompts for login
##		question=> displays questions
##		email => sends email for given login
##



##
## verb
##			wholesale/order
##			wholesale/add
##			wholesale/checkout
##
sub verb_wholesale_order {
	my ($lm,$C,$v,$cacheref,$SITE) = @_;
	require EXTERNAL;
	require CUSTOMER;

	my $customer_url = $SITE->URLENGINE()->get('customer_url');

	my $DEBUG = 0 ;	
	if ($v->{'verb'} eq 'wholesale/checkout') {
		my ($url) = $SITE->URLENGINE()->get('checkout_url');
		$lm->pooshmsg("REDIRECT|url=$url|+need to complete checkout");
		}

	if (not $C->is_wholesale()) {
		$lm->pooshmsg("ERROR|+You must be a wholesale client to use this feature.");
		}
	
	##############################################################################
	## Output Page
	
	
	#print "Content-type: text/plain\n\n";
	#use Data::Dumper;
	################################################################
	
	### WHOLESALE
	# my $body = '<i>Fast Order Form - BETA -- please send comments/questions to support\@zoovy.com</i><br>';
	my $body = '';
	my $VERB = $v->{'verb'};



	## ADD TO CART
		
	if ($VERB eq 'wholesale/order') {
		}
	if ($VERB eq 'wholesale/add') {
		my $linecount = 0;
		my @ERRORS = ();
		foreach my $line (split(/[\n\r]+/,$v->{'products'})) {
			next if ($line eq '');
	 
			$linecount++;
	
			my ($qty,$lookup) = split(/\,/,$line);
			$lookup =~ s/[\s]+//g;

			if (int($qty)<=0) { $lookup = undef; push @ERRORS, "line[$linecount] Could not determine quantity. Format: qty,product found: $line"; }
			elsif ($lookup eq '') { $lookup = undef; push @ERRORS, "line[$linecount] Could not find SKU/Product Id (qty=$qty). Format: qty,product found: $line"; }

			my ($SKU) = undef;
			if (defined $lookup) {
				$SKU = &ZOOVY::resolve_sku($SITE->username(),$lookup);
				}
	
			my $P = undef;
			if (not defined $SKU) {
				push @ERRORS, "line[$linecount] could not determine valid SKU for: $lookup";
				}
			elsif (defined $SKU) {
				$P = $SITE::CART2->stuff2()->getPRODUCT($SKU);
				}

			if ((not defined $P) || (ref($P) ne 'PRODUCT')) {
				push @ERRORS, "line[$linecount] specifies a SKU/STID which is not available";
				$P = undef;
				}
			else {
				my $suggestions = $P->suggest_variations( $SKU );
				my $variations = STUFF2::variation_suggestions_to_selections($suggestions);
				my ($item,$lm) = $SITE::CART2->stuff2()->cram( $SKU, $qty, $variations );
				foreach my $msg (@{$lm->msgs()}) {
					my ($ref,$status) = LISTING::MSGS::msg_to_disposition($msg);
					if ($status ne 'DEBUG') {
						push @ERRORS, "$ref->{'_'}: $ref->{'+'}";
						}
					}
				}
			}


		if (scalar(@ERRORS)) {
			foreach my $err (@ERRORS) {
				$body .= "<div class=\"zwarn\">$err</div>\n";
				$lm->pooshmsg("ERROR|+$err");
				}
			}
		}

	
	if (($VERB eq 'wholesale/order') || ($VERB eq 'wholesale/add')) {
	   if ($SITE::CART2->stuff2()->count('')>0) {
			$body .= qq~<input class="zbutton" type="button" onClick="document.thisFrm.action='$customer_url/wholesale/checkout'; document.thisFrm.submit();" value=" Checkout / Create Order ">~;
			}	
		$body .= qq~<form name="thisFrm" action="$customer_url/wholesale/order">~;
		$body .= qq~<b>Add Products:</b> (<i>Enter quantity,sku -- one per line</i>)<br>~;
		$body .= qq~<textarea rows=5 cols=30 name="products"></textarea><br>~;
		$body .= qq~<input class="zbutton" type="button" onClick="document.thisFrm.action='$customer_url/wholesale/add'; document.thisFrm.submit();" value=" Add Items ">~;
		$body .= qq~</form>~;
		}
	else {
		$lm->pooshmsg("ERROR|+Unknown VERB[$VERB] sent to wholesale_order");
		}
	
	my $OUTPUT = '';	

	if ($C->cid() > 0) {
		$OUTPUT .=  qq~
			Account Information: ~.$SITE::CART2->in_get('customer/login').qq~<br>
			<div><a href="$customer_url">Back to Customer Page</a></div>
			~;
		}
	if ($SITE::CART2->stuff2()->count('')>0) {
		# $OUTPUT .=  CART::VIEW::as_html($SITE::CART,'SITE',$SITE->webdb(),undef);
		$OUTPUT .=  CART2::VIEW::as_html($SITE::CART2,'SITE',{},$SITE);
		}
	$OUTPUT .=  $body;	
	$OUTPUT .=  qq~
	<!-- END TOOLS TABLE -->	
		</td>
	</tr></table>
	
	</body>
	</html>
	~;
	
	$lm->pooshmsg("STOP|+wholesale order");
	
	push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT, };
	return();	
	}
	


##
##
##
sub verb_password {
	my ($lm,$C,$v,$cacheref,$SITE) = @_;

	require CUSTOMER;
	
 	my $OUTPUT = '';
	# Make sure we only access this on the SSL server

	my @errors = ();
	my $customer_url = $SITE->URLENGINE()->get('customer_url');

	my $current_password = defined($SITE::v->{'current_password'}) ? $SITE::v->{'current_password'} : '' ;
	my $password = defined($SITE::v->{'password'}) ? $SITE::v->{'password'} : '' ;
	my $password2 = defined($SITE::v->{'password2'}) ? $SITE::v->{'password2'} : '' ;
	my $mode = "form";

	my ($login) = $C->email();
	
	if ($current_password && $password && $password2) {
		if (&CUSTOMER::authenticate($SITE->username(), $SITE->prt(), $login, $current_password)  <= 0) {
			$lm->pooshmsg("ERROR|+Cannot change - current password doesn't match");
			}
		elsif ($password ne $password2) {
			$lm->pooshmsg("ERROR|+New and old passwords don't match");
			}

		if ($lm->can_proceed()) {
			$C->initpassword(set=>$password);
			$mode = "success";
			}
		}
	elsif ($current_password || $password || $password2) {
		$lm->pooshmsg("ERROR|+You must fill in all form fields");
		}
	
	##############################################################################
	## Set Up FLOW Variables
	
	$SITE->title( "Change Password" );
	if ($mode eq 'success') {
		$OUTPUT .= qq~
			Your password has successfully been updated.<br>
			<a href="$customer_url">Back to Customer Page</a><br>
		~;
		}
	elsif ($mode eq 'form')
		{
		foreach my $error (@errors) {
			$OUTPUT .= qq~<div class="zwarn">$error</div><br>\n~;
			}
		$OUTPUT .= qq~						
			<div class="ztxt">
			<table border="0" cellpadding="3" cellspacing="0">
			<form action="$customer_url/password" method="post">
			<tr>
				<td class="ztxt" align="right">
					<label for="current_password">Current Password : </label>
				</td>
				<td class="ztxt">
					<input class="zform_textbox" type="password" length="20" maxlength="20" name="current_password" value="">
				</td>
			</tr>
			<tr>
				<td class="ztxt" align="right">
					<label for="password">Password : </label>
				</td>
				<td class="ztxt">
					<input class="zform_textbox"  type="password" length="20" maxlength="20" name="password" value=""><br>
				</td>
			</tr>
			<tr>
				<td class="ztxt" align="right">
					<label for="password2">Password (again) : </label>
				</td>
				<td class="ztxt">
					<input class="zform_textbox"  type="password" length="20" maxlength="20" name="password2" value=""><br>
				</td>
			</tr>
			<tr>
				<td class="ztxt" align="right">&nbsp;</td>
				<td class="ztxt">
					<input class="zform_button zform_button1"  type="submit" name="submit" value="Change Password"> 
					&nbsp; 
					<input class="zform_button" onClick="document.location='$customer_url';" type="button" name="button" value="Back">
				</td>
			</tr>
			</form>
			</table>
		</div>
		~;
		}
		
	$lm->pooshmsg("STOP|+verb password");
	
	push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT, };
	return();		
	}



##
## 
##
sub verb_order_status {	
	my ($lm,$C,$v,$cacheref,$SITE) = @_;
	require ZTOOLKIT;
	
	use Time::Local;
	use Time::Zone;
	
	my $timestamp_offset = &Time::Zone::tz_offset('pdt');
	my $customer_url = $SITE->URLENGINE()->get('customer_url');

	my $login = '';
	my $ACTION = $SITE::v->{'action'};
	if (not defined $ACTION) { $ACTION = ''; }
	
	# See if we need a login
	#my $disable_login = $SITE->webdb()->{'order_status_disable_login'};
	#if (not defined $disable_login) { $disable_login = 0; }
	#if ($disable_login) { if ($SITE->webdb()->{'aol'}) { 
	#	$disable_login = 1; } 
	#	}

	my ($O2) = $cacheref->{'*O2'};
	my $orderid = $O2->oid();
	my $cartid = $O2->cartid();
	
	if ($lm->can_proceed()) {
		}
	#elsif ($ACTION eq 'PAYCREDIT') {
	#	$o->set_attrib('payment_method','CREDIT');
	#	$ACTION = '';
	#	}
	elsif ($ACTION eq 'UPDATECC') {

		my $ps = $O2->payment_status();
		if ($O2->pool() ne "RECENT") {
			$lm->pooshmsg("ERROR|+order is no longer in RECENT state and cannot be updated");
			}
		elsif (substr($ps,0,1) eq '2') {
			}
		elsif (substr($ps,0,1) eq '0') {
			$lm->pooshmsg("ERROR|+order $orderid already flagged as paid, no further action is required on your part.");
			}
		elsif (substr($ps,0,1) eq '0') {
			$lm->pooshmsg("ERROR|+order $orderid already flagged as review, no further action is required on your part.");
			}
		elsif (substr($ps,0,1) eq '1') {
			$lm->pooshmsg("ERROR|+order $orderid already flagged as pending capture, no further action is required on your part.");
			}
		else {
			$lm->pooshmsg("ERROR|+order $orderid flagged in unknown payment state: $ps and cannot be updated.");
			}

		if ($lm->can_proceed()) {
			my ($cc_verify_errors) = &ZPAY::verify_credit_card($SITE::v->{'card_number'},$SITE::v->{'card_exp_month'},$SITE::v->{'card_exp_year'});
			if ($cc_verify_errors ne '') { $lm->pooshmsg("ERROR|+$cc_verify_errors"); }
			}

		if (not $lm->can_proceed()) {
			$ACTION = '';
			}
		else {
			my @events = ();
			$O2->add_history("Payment information updated on website by customer.",etype=>3,luser=>'*CUSTOMER');
			# $O2->add_history("Preserving old payment information: $attribs{'card_number'} - $attribs{'card_exp_month'}/$attribs{'card_exp_year'}",undef,2,'*CUSTOMER');
	
			#$o->set_attrib('payment_method','CREDIT');
			#$o->set_attrib('card_number',$SITE::v->{'card_number'});
			#$o->set_attrib('card_exp_month',$SITE::v->{'card_exp_month'});
			#$o->set_attrib('card_exp_year',$SITE::v->{'card_exp_year'});
			#if ($SITE::v->{'cvvcid_number'} ne '') { 
			#	$o->set_attrib('cvvcid',$SITE::v->{'cvvcid_number'});
			#	}
			#my ($success,$message) = $o->pay_init('CREDIT',1);
			#$O2->order_save();
			my $message = '';	
			my $success = 0;
			if ($success) {
				&ZOOVY::add_notify($SITE->username(),"CUSTOMER.ORDER.CANCEL",
					title=>"Customer Updated Order $orderid via website",
					detail=>"Customer Updated $orderid via website.  Payment Information for $orderid has been changed.",
					order=>$orderid,
					link=>"ORDER:$orderid",
					);
						
				#require TODO;
				#TODO::easylog($SITE->username(),
				#	title=>"Customer Updated Order $orderid via website",
				#	detail=>"Customer Updated $orderid via website.  Payment Information for $orderid has been changed.",
				#	order=>$orderid,
				#	link=>"ORDER:$orderid",
				#	code=>40001
				#	);
#				require ZMAIL;
#				my $subject = "Customer Updated Order $orderid via website";
#				my $message = "Customer Updated $orderid via website.  Payment Information for $orderid has been changed.";
#				&ZMAIL::notify_customer($SITE->username(), 'support@zoovy.com', $subject, $message, "UPDATE", "ORDERID=$orderid");
				}
			$lm->pooshmsg("ERROR|+$message");
			}

		$ACTION = '';
		} 


	# Try to load the order
	my $stuff2;
	if (not $lm->can_proceed()) {
		## crap already happened!
		}
	else {
		$stuff2 = $O2->stuff2();
		}

#	return();
#	print STDERR "SITE::CART ".$SITE::CART->id()."\n";
	
	# Get the info needed for order display
	my %prodmeta;
	my @details = ();

	my $OUTPUT = '';
	my $graphics_url = $SITE->URLENGINE()->get('graphics_url');
	$SITE->title( "Order $orderid" );

	if (not $lm->can_proceed()) {
		}
	elsif ($ACTION eq 'error') {
		# Do nothing, what needs to be said is said already.
		}
	elsif ($ACTION eq '') {

		my ($billhtmladdr) = $O2->addr_vars('bill')->{'%HTML'};
		my ($shiphtmladdr) = $O2->addr_vars('ship')->{'%HTML'};
		$OUTPUT .= qq~
			<table class="zadminpanel_table" border="0" width="100%">
			~;


		if ($O2->pool() =~ /^(CANCEL|DELETED|COMPLETED)$/) {
			## TODO: don't let them make a payment, if the order is cancelled, regardless if there is a balance due.
			my ($pool) = $O2->pool();
			$OUTPUT .= qq~
			<tr>
				<td colspan="2" class="ztable_head zadminpanel_table_head">Order is $pool</td>
			</tr>
			<tr>
				<td colspan="2">
<b>This order is currently in status "$pool". No updates or changes are allowed at this time.</b>
				</td>
			</tr>
~;
			}
		elsif (($O2->in_get('sum/balance_due_total') - $O2->in_get('sum/balance_auth_total'))>0) {
			## BEGIN PAYMENT DUE
			$OUTPUT .= qq~
			<tr>
				<td colspan="2" class="ztable_head zadminpanel_table_head">Payment Incomplete</td>
			</tr>
			<tr>
				<td colspan="2">

<form name="addpaymentfrm" id="addpaymentfrm" action="$customer_url/order/payment/add" method="post">
<input type="hidden" name="verb" value="order/payment/add">
<input type="hidden" name="orderid" value="$orderid">
<input type="hidden" name="cartid" value="$cartid">
<b>This order has a balance due. Please select a method of payment below:</b>
~;
			
			my ($ar) = ZPAY::payment_methods($O2->username(),prt=>$O2->prt(),admin=>0,'*C'=>$C,'cart2'=>$O2);
			my $r = undef;
			foreach my $method (@{$ar}) {
				my ($type,$typeid) = split(/:/,$method->{'id'});	 ## change: wallet:14 to wallet and 14
				if ($type eq 'WALLET') {
					($r) = ($r eq 'r0')?'r1':'r0';
					$OUTPUT .= sprintf("<div class=\"ztxt\"><input type=\"radio\" name=\"payby\" value=\"%s\">Stored Payment: %s</div>",$method->{'id'},$method->{'pretty'});
					}
				elsif ($type eq 'CREDIT') {
					($r) = ($r eq 'r0')?'r1':'r0';
					$OUTPUT .= sprintf("<div class=\"ztxt\"><input type=\"radio\" name=\"payby\" value=\"%s\">%s</div>",$method->{'id'},$method->{'pretty'});
				$OUTPUT .= qq~
				<table style=\"padding-left: 20px;\">
				<tr>
					<td class="ztable_row">Card Number:</td>
					<td class="ztable_row"><input type="text" class="zform_textbox" name="cc" value="$SITE::v->{'card_number'}"></td>
				</tr>
				<tr>
					<td class="ztable_row">Expiration Date:</td>
					<td class="ztable_row">
						<input type="text" size="2" class="zform_textbox" maxlength="2" name="mm"> / 
						<input type="text" size="2" class="zform_textbox" maxlength="2" name="yy"> (MM/YY)
					</td>
				</tr>
				<tr>
					<td class="ztable_row">CCV/CID</td>
					<td class="ztable_row">
					<input type="textbox" class="zform_textbox" name="cv" value="" size="4">
					</td>
				</tr>
				</table>
			~;
					}
				elsif ($type eq 'GIFTCARD') {
					($r) = ($r eq 'r0')?'r1':'r0';
					$OUTPUT .= sprintf("<div class=\"ztxt\"><input type=\"radio\" name=\"payby\" value=\"%s\">%s</div>",$method->{'id'},$method->{'pretty'});
					}
				#elsif ($type eq 'ECHECK') {
				#	($r) = ($r eq 'r0')?'r1':'r0';
				#	$OUTPUT .= sprintf("<div class=\"ztxt\"><input type=\"radio\" name=\"payby\" value=\"%s\">%s</div>",$method->{'id'},$method->{'pretty'});
				#	}
				#elsif ($type eq 'GOOGLE') {
				#	($r) = ($r eq 'r0')?'r1':'r0';
				#	$OUTPUT .= sprintf("<div class=\"ztxt\"><input type=\"radio\" name=\"payby\" value=\"%s\">%s</div>",$method->{'id'},$method->{'pretty'});
				#	}
				#elsif ($type eq 'PAYPALEC') {
				#	($r) = ($r eq 'r0')?'r1':'r0';
				#	$OUTPUT .= sprintf("<div class=\"ztxt\"><input type=\"radio\" name=\"payby\" value=\"%s\">%s</div>",$method->{'id'},$method->{'pretty'});
				#	}
				#elsif ($type eq 'CASH') {
				#	($r) = ($r eq 'r0')?'r1':'r0';
				#	$OUTPUT .= sprintf("<div class=\"ztxt\"><input type=\"radio\" name=\"payby\" value=\"%s\">%s</div>",$method->{'id'},$method->{'pretty'});
				#	}
				}
			
			if ($r ne '') {
				require ZTOOLKIT::CURRENCY;
				$OUTPUT .= qq~
			<div class="ztxt">Amount Due: ~.&ZTOOLKIT::CURRENCY::format($O2->in_get('sum/balance_due_total')).qq~</div>
			<input type="button" class="zform_button" 
		onClick="addpaymentfrm.verb.value='order/payment/add'; addpaymentfrm.submit();" 
		value="Make Payment">
		~;
				}
			$OUTPUT .= qq~
			</form>
		</td>
	</tr>
~;
			
			## END PAYMENT DUE
			}





		## BILL/SHIP ADDRESS
		$OUTPUT .= qq~
				<tr>
					<td colspan="1" class="ztable_head zadminpanel_table_head">Billing</td>
					<td colspan="1" class="ztable_head zadminpanel_table_head">Shipping</td>
				</tr>
				<tr>
					<td colspan="1" valign=top class="zadminpanel_table_row">$billhtmladdr</td>
					<td colspan="1" valign=top class="zadminpanel_table_row">$shiphtmladdr</td>
				</tr>
			~;

		## ORDER DETAILS
		$OUTPUT .= qq~
				<tr>
					<td colspan="2" class="ztable_head zadminpanel_table_head">Order Details</td>
				</tr>
			~;
		@details = (
			[ "Order Status" => ucfirst(lc($O2->pool())) ],
			[ "Payment Method" => sprintf("%s",$O2->payment_method()) ],
			);
		if ($O2->in_get('flow/paid_ts')>0) {
			push @details, [ "Paid Date" => &ZTOOLKIT::pretty_date($O2->in_get('flow/paid_ts'),1) ];
			}

		my ($BLAST) = BLAST->new($O2->username(),$O2->prt());
		my ($TLC) = TLC->new('username'=>$O2->username());
		my $payment_status = $BLAST->macros()->{'%PAYINFO%'} || "%PAYINFO% macro";
		$payment_status = $TLC->render_html($payment_status, { '%ORDER'=>$O2->jsonify() });
		push @details, [ "Payment", $payment_status ];

		# push @details, [ "Payment Detail", $O2->explain_payment_status('*SITE'=>$SITE,'format'=>'summary','html'=>1) ];

		if ($O2->in_get('flow/shipped_date')>0) {
			push @details, [ "Shipped Date" => &ZTOOLKIT::pretty_date($O2->in_get('flow/shipped_ts'),1) ]; 
			};
		my $cssclass = '';
		foreach my $set (@details) {
			my ($label,$detail) = @{$set};
			next unless $detail;
			$cssclass = ($cssclass eq 'ztable_row0')?'ztable_row1':'ztable_row0';
			$OUTPUT .= qq~
				<tr>
					<td valign="top" align="left" width="25%" class="$cssclass">$label:</td>
					<td valign="top" align="left" width="75%" class="$cssclass">$detail</td>
				</tr>
			~;
			}
		$OUTPUT .= qq~</table>~;
	
		## CART CONTENTS
		# $OUTPUT .= &CART::VIEW::as_html($o, 'INVOICE', $SITE->webdb(),undef);
		$OUTPUT .= &CART2::VIEW::as_html($O2, 'INVOICE', {},$SITE);

		## TRACKING		
		my %tracknumbers;
		my $ups_meta;
		if (defined $O2->tracking()) {
			foreach my $trkref (@{$O2->tracking()}) {
				next if ($trkref->{'void'} > 0);

		#		use Data::Dumper;
		#		print STDERR Dumper($trkref);
				my ($shipcode,$trackid) = ($trkref->{'carrier'},$trkref->{'track'});
				$shipcode = uc($shipcode);

				my $shipref = &ZSHIP::shipinfo($trkref->{'carrier'});
				my $link = '';

				if ($shipref->{'carrier'} eq 'FDX') {
					my $account = $SITE->webdb()->{'fedexapi_account'}; 
					#$link = "FedEx <a href=\"http://www.fedex.com/cgi-bin/tracking?action=track&language=english&cntry_code=us&tracknumbers=$trackid\">$trackid</a>";
					# 
					# https://www.fedex.com/cgi-bin/tracking?tracknumbers=144059310044924&action=track&language=english&cntry_code=us&mps=y&ascend_header=1&imageField=Track
					# https://www.fedex.com/us/tracking/?template_type=plugin&clienttype=pluginff&action=track&tracknumbers=144059310044924&account_number=284471644&reftype=express_track
					# https://www.fedex.com/us/tracking/?template_type=plugin&clienttype=pluginff&action=track&tracknumbers=$trackid&account_number=$account&reftype=express_track
					#
					# Changed from cgi-bin/tracking? to Tracking?
					# 11/07/2005 - patti
					$link = qq~
					<!-- Start Tracking Area -->
					<center>
					<iframe name="content_frame" width="600" height="500" src="https://www.fedex.com/Tracking?action=track&language=english&template_type=plugin&ascend_header=1&cntry_code=us&initial=x&mps=y&tracknumbers=$trackid"> 
					Go to <a href="https://www.fedex.com/Tracking?tracknumbers=$trackid&action=track&language=english&cntry_code=us&mps=y&ascend_header=1&imageField=Track">FedEx Tracking</a><br> 
					This application uses technology that may be incompatible with your browser.<br> 
					To use this application, we suggest you download <a href="http://cgi.netscape.com/cgi-bin/pdms_download_path.cgi?USE_NSDA=NO&BITPATH=/netscape6/english/6.01/windows/win32/N6Setup.exe"> Netscape 6.0</a> or newer.<br> 
					Please click on the link provided to download <a href="http://cgi.netscape.com/cgi-bin/pdms_download_path.cgi?USE_NSDA=NO&BITPATH=/netscape6/english/6.01/windows/win32/N6Setup.exe">Netscape 6.0</a> now.<br> 
					</iframe> </center> 
					<!-- End Tracking Area -->
					~;
					}
				elsif ($shipref->{'carrier'} eq 'USPS') {
					## updated 11/1/2006
					#$link = "USPS <a href=\"http://trkcnfrm1.smi.usps.com/netdata-cgi/db2www/cbd_243.d2w/output?CAMEFROM=OK&strOrigTrackNum=$trackid\">$trackid</a>";
					$link = "$shipref->{'method'} <a target=\"_new\" href=\"http://trkcnfrm1.smi.usps.com/PTSInternetWeb/InterLabelInquiry.do?CAMEFROM=OK&origTrackNum=$trackid\"><font class=\"zlink\">$trackid</font></a>";
					}
				elsif ($shipref->{'carrier'} eq 'UPS') {
					require ZSHIP::UPSAPI;
					($link, $ups_meta) = &ZSHIP::UPSAPI::track_package($SITE->username(),$SITE->webdb(),$trackid,'html'=>1);
					if ((not defined $link) || ($link eq '')) { $link = $trackid; }
					$link = "$shipref->{'method'}: $trackid<br>".$link."<a href=\"http://wwwapps.ups.com/etracking/tracking.cgi?TypeOfInquiryNumber=T&InquiryNumber1=$trackid\"><font class=\"zlink\">Check via UPS Site</font></a><br>";
					}
				elsif (($shipref->{'carrier'} eq 'AIRBORNE') || ($shipref->{'carrier'} eq 'AIRB')) {
					$link = "Airborne <a href=\"http://track.airborne.com/atrknav.asp?shipmentNumber=$trackid\"><font class=\"zlink\">$trackid</font></a>"
					}
				else {
					$link = "$shipref->{'carrier'}: $trackid";
					}
	
				$tracknumbers{$shipref->{'carrier'}.'-'.$trackid} = $link;
				} # end foreach
			} # end if 
		
		
		if (scalar %tracknumbers) {
			$OUTPUT .= qq~
				<table border="0" cellpadding="2" cellspacing="1" width="100%">
					<tr>
						<td colspan="2" class="ztable_head">Shipping Information</td>
					</tr>
						<tr>
							<td valign="middle" align="left" class="ztable_row">
			~;
			foreach my $link (values %tracknumbers) {
				$OUTPUT .= qq~$link<br>\n~;
				}
			if ((defined $ups_meta) && (scalar keys %{$ups_meta}) && (defined $ups_meta->{'force_blurb'}) && $ups_meta->{'force_blurb'}) {
				$OUTPUT .= qq~<font size="1">$ups_meta->{'force_blurb'}</font>~;
				}
			$OUTPUT .= qq~
							</td>
						</tr>
				</table>
			~;
			}
	

		$OUTPUT .= qq~
			<img src="$graphics_url/blank.gif" width="1" height="8"><br>
			<table border="0" cellpadding="2" cellspacing="1" width="100%">
			~;

		## open a ticket for the CRM people
#		my $support_url = $SITE->URLENGINE()->get('support_url');	
#		$OUTPUT .= qq~
#			<tr><td colspan="2" align="center" class="ztable_head">Contact Us regarding this order</td></tr>
#			<tr class="ztable_row">
#				<td valign="middle" align="left" width="65%" class="ztable_row">
#				<form action="$support_url"><input type="hidden" name="orderid" value="$orderid"><input type="submit" class="zform_button" value=" Open Ticket "></form>
#				</td>
#			</tr>
#			~;


		my $PS = $O2->in_get('flow/payment_status');
		my $RS = $O2->in_get('flow/review_status');
		if ($RS eq '') { $RS = 'XXX'; }
		$OUTPUT .= qq~
			<tr><td colspan="2" class="ztable_head zadminpanel_table_head">Order Payment History</td></tr>
			<tr class="ztable_row">
				<td valign="middle" align="left" width="65%" class="ztable_row">
				<div>Overall Payment Method: ~.$O2->in_get('our/payment_method').qq~</div>
				<div>Overall Payment Status: ~.sprintf("(%d) %s",$PS,$ZPAY::PAYMENT_STATUS{$PS}).qq~</div>
				<div>Overall Fraud/Review Status: ~.sprintf("(%s) %s",$RS,$ZPAY::REVIEW_STATUS{$RS}).qq~</div>
				</td>
			</tr>
			~;

	## NOTE: the verb should change to ordder
		$OUTPUT .= qq~
	<tr><td class="zadminpanel_table_row" colspan=2>	
	<form name="paymentfrm" id="paymentfrm" action="$customer_url/order/payment" method="post">
		<input type="hidden" name="verb" value="order/payment">
		<input type="hidden" name="orderid" value="$orderid">
		<input type="hidden" name="cartid" value="$cartid">
		<input type="hidden" name="payuuid" value="">
~;


		my $r = undef;
		foreach my $set (@{$O2->payments_as_chain()}) {
			my ($payrec,$chainedpayments) = @{$set};
			my $LINE = '';
			my $payuuid = $payrec->{'uuid'};

			my $status = &ZPAY::payment_status_short_desc($payrec->{'ps'});
			$LINE .= sprintf("<div style=\"padding-top: 10px;\"><b>Payment %s #%s Amt: \$%.2f Status: %s</b></div>",$payrec->{'tender'},$payuuid,$payrec->{'amt'},$status);
			$LINE .= "<div style=\"padding-left: 20px;\">";
			if ($payrec->{'note'} ne '') {
				$LINE .= sprintf("<div>NOTE: %s</div>",$payrec->{'note'});
				}
			#else {
			#	$LINE .= sprintf("<div><i>There are no administrative notes for this transaction</i></div>");
			#	}

			if ($payrec->{'ps'} eq '500') {
				## 500 - INTERNAL ERROR
				$LINE .= qq~Internal error occurred on this payment, please contact the merchant.~;
				}
			elsif (&ZPAY::ispsa($payrec->{'ps'},['6'])) {
				## VOIDED PAYMENTS ARE HANDLED SEPARATELY
				if ($payrec->{'tender'} eq 'CREDIT') {
					$LINE .= qq~This transaction has been voided, please allow 5 business days for it to be credited to your card.~;
					}	
				else {
					$LINE .= qq~This transaction has been voided.~;
					}
				}
			else {
				my ($BLAST) = BLAST->new($O2->username(),$O2->prt());
				my ($TLC) = TLC->new('username'=>$O2->username());
				my $payment_status_detail = $BLAST->macros()->{'%PAYINSTRUCTIONS%'} || "%PAYINSTRUCTIONS% macro";
				$payment_status_detail = $TLC->render_html($payment_status_detail, { '%ORDER'=>$O2->jsonify() });
				$LINE .= $payment_status_detail;
				}
			#elsif (scalar(@{$chainedpayments})>0) {
			#	## CHAINED PAYMENTS
			#	$LINE .= $O2->explain_payment_status(
			#		format=>"detail",
			#		try_prefix=>"admin_",
			#		uuid=>$payrec->{'uuid'},
			#		'*SITE'=>$SITE,
			#		'html'=>1,
			#		);
			#	$LINE .= "<div>The following changes were made to transaction $payrec->{'uuid'}:<ul>";
			#	foreach my $cpayrec (@{$chainedpayments}) {
			#		$LINE .= "<li>".$O2->explain_payment_status(
			#			format=>"summary",
			#			try_prefix=>"admin_",
			#			uuid=>$cpayrec->{'uuid'},
			#			'*SITE'=>$SITE,
			#			'skip_chained'=>0,
			#			'html'=>1,
			#			);			
			#		$LINE .= "</li>";	
			#		}
			#	$LINE .= "</ul></div>";
			#	}
			#elsif (&ZPAY::ispsa($payrec->{'ps'},['0','1','2'])) {
			#	$LINE .= $O2->explain_payment_status(
			#		format=>"detail",
			#		try_prefix=>"admin_",
			#		uuid=>$payrec->{'uuid'},
			#		'*SITE'=>$SITE,
			#		'html'=>1,
			#		);
			#	}
#			elsif (($payrec->{'tender'} eq 'PAYPAL') && ($payrec->{'ps'} eq '106')) {
#				## PAYPAL PAYMENTS
#				$LINE .= qq~
#Paypal payment instructions will go here.
#~;
#				}
#			elsif (($payrec->{'tender'} eq 'CASH') && (substr($payrec->{'ps'},0,1) eq '1')) {
#				## CASH PAYMENTS
#				$LINE .= qq~
#Cash payment instructions will go here.
#~;
#				}
#			elsif (($payrec->{'tender'} eq 'CREDIT') && (substr($payrec->{'ps'},0,1) eq '2')) {
#				$LINE .= qq~
#Credit card instructions go here.
#~;
#				}
#			elsif (
#				(($payrec->{'tender'} eq 'CREDIT') && ($payrec->{'ps'} == 195))
# 				) {
#				## CREDIT LAYAWAY
#				$LINE .= qq~
#				<div>
#				<table>
#				<tr class="ztable_row">
#					<td valign="middle" align="left" colspan="2" width="100%" class="ztable_row">
#			<table border="0" cellpadding="2" cellspacing="1">
#				<tr>
#					<td class="ztable_row">Card Number:</td>
#					<td class="ztable_row"><input type="text" class="zform_textbox" name="payment_cc.$payuuid" value="$SITE::v->{'card_number'}"></td>
#				</tr>
#				<tr>
#					<td class="ztable_row">Expiration Date:</td>
#					<td class="ztable_row">
#						<input type="text" size="2" class="zform_textbox" maxlength="2" name="payment_mm.$payuuid"> / 
#						<input type="text" size="2" class="zform_textbox" maxlength="2" name="payment_yy.$payuuid"> (MM/YY)
#					</td>
#				</tr>
#				<tr>
#					<td class="ztable_row">CCV/CID</td>
#					<td class="ztable_row">
#					<input type="textbox" class="zform_textbox" name="payment_cv.$payuuid" value="" size="4">
#					</td>
#				</tr>
#			</table>
#			<br>
#			<input type="button" class="zform_button" 
#		onClick="paymentfrm.payuuid.value='$payuuid'; 
#					paymentfrm.verb.value='order/payment/updatecc'; 
#					paymentfrm.submit();" 
#		value="Update Payment: $payrec->{'uuid'}">
#		</div>
#			~;
#				}
#			elsif ($payrec->{'tender'} eq 'PAYPALEC') {
			#elsif (($O2->in_get('payment_method') eq 'PAYPALEC') && (substr($O2->in_get('payment_status'),0,1) eq '2')) {
			#$OUTPUT .= qq~
			#~;			
			#	$LINE .= qq~
			#	<tr><td colspan="2" class="ztable_head">Paypal EC</td></tr>
			#	<tr class="ztable_row">
			#		<td valign="middle" align="left" width="65%" class="ztable_row">
			#		<b>We apologize but we were unable to complete this transaction via PayPal. </b><br>
			#		</td>
			#		<form action="$customer_url/order/status">
			#		<td valign="middle" align="center" width="35%"  class="ztable_row">
			#		<input type="hidden" name="VERB" value="PAYCREDIT">
			#		<input type="hidden" name="orderid" value="$orderid">
			#		<input type="submit" class="zform_button" value=" Pay by Credit Card ">
			#		</td>
			#		</form>
			#	</tr>
			#	~;
#				}
#			elsif ($payrec->{'tender'} eq 'GOOGLE') {
#				}
#			elsif ($payrec->{'tender'} eq 'AMAZON') {
#				}
#			elsif ($payrec->{'tender'} eq 'LAYAWAY') {
#
#				my $PAYMETHODS = &ZPAY::payment_methods($o->username(),ORDER=>$o,webdb=>$SITE->webdb(),CART=>$SITE::CART);
#				$LINE .= qq~
#<div>
#<div>
#This order requires payment before it can be shipped.  
#Please choose a payment method below to pay the balance due: \$~.sprintf("%.2f",$payrec->{'amt'}).qq~
#</div>
#	~;
#				foreach my $paymethod (@{$PAYMETHODS}) {
#					$LINE .= qq~<input type="radio" name="payby.$payuuid" value="$paymethod->{'id'}"> $paymethod->{'pretty'}<br>~;
#					}
#	$LINE .= qq~
#	<input class="zform_button" type="button" 
#		onClick="paymentfrm.payuuid.value='$payuuid'; 
#					paymentfrm.verb.value='order/payment/layaway'; 
#					paymentfrm.submit();" 
#		value="Set Payment Method: $payuuid">
#</div>
#~;
#				}
			#else {
			#	$LINE .= "<div>UNKNOWN TENDER:$payrec->{'tender'} PS:$payrec->{'ps'} AMT:$payrec->{'amt'}</div>";
			#	}
			$LINE .= "</div>";

			$OUTPUT .= qq~<div>$LINE</div>~;
			}
	
		$OUTPUT .= qq~</form>
		</td></tr>
~;
	## end paymentfrm
		

		my $allow_cancel = ($SITE->webdb()->{'disable_cancel_order'})?0:1;
		if (($O2->pool() eq 'RECENT') && ($allow_cancel)) {
			$OUTPUT .= qq~
				<tr><td colspan="2" class="ztable_head zadminpanel_table_head">Cancel Order</td></tr>
				<tr class="ztable_row">
					<td valign="middle" align="left" width="65%"  class="ztable_row">
					You can Cancel this order online if it was placed in error, unless we have already started processing it (then please contact us).<br>
					</td>
					<form action="$customer_url/order/cancel" method="post">
					<td valign="middle" align="center" width="35%" class="ztable_row">
						<input type="hidden" name="orderid" value="$orderid">
						<input type="hidden" name="cartid" value="$cartid">
						<input class="zform_button" type="submit" value="Cancel Order">
					</td>
					</form>
				</tr>
			~;
			}

		my $contact_url = $SITE->URLENGINE()->get('contact_url');
		$OUTPUT .= qq~
				<tr><td colspan="2" class="ztable_head zadminpanel_table_head">Contact Us</td></tr>
				<tr>
					<td valign="middle" align="left" width="65%" class="ztable_row">
						<b>If you have any questions or concerns about this order, please let us know.</b><br>
					</td>
					<form action="$contact_url" method="post">
					<td valign="middle" align="center" width="35%"  class="ztable_row">
						<input type="hidden" name="orderid" value="$orderid">
						<input type="hidden" name="cartid" value="$cartid">
						<input type="hidden" name="validate" value="0">
						<input class="zform_button" type="submit" value="Contact Us">
					</td>
					</form>
				</tr>
			</table>
		~;
	
	
	if ($SITE->webdb()->{'order_status_hide_events'} == 0) {
		$OUTPUT .= qq~
			<img src="$graphics_url/blank.gif" width="1" height="8"><br>
			<table border="0" cellpadding="2" cellspacing="1" width="100%">
				<tr>
					<td colspan="2" class="ztable_head zadminpanel_table_head">Order History</td>
				</tr>
			~;
			foreach my $event (@{$O2->history()}) {
				$cssclass = ($cssclass eq 'ztable_row0')?'ztable_row1':'ztable_row0';
				my $message = $event->{'content'};

				if (not defined $event->{'etype'}) { $event->{'etype'} = 64; }
				next unless ((int($event->{'etype'}) & 1)==1);	# only show messages which pertain to the user to the user.
				next if (not defined $message);
				$message =~ s/:[\d]+$//;
				my $posted = &ZTOOLKIT::pretty_date($event->{'ts'},2);
	
				if ($message ne '') {
					## This should be replaced with a better perl time library
					$OUTPUT .= qq~
							<tr>
								<td valign="middle" align="left" width="25%" class="$cssclass">
									<b>$posted</b><br>
								</td>
								<td valign="middle" align="left" width="75%" class="$cssclass">
									$message<br>
								</td>
							</tr>
					~;
					}
				}
			$OUTPUT .= qq~
			</table>
			~;
			} # end of if order_status_hide_events
		

		if ((defined $SITE->webdb()->{'order_status_notes_disable'}) && ($SITE->webdb()->{'order_status_notes_disable'})) {
			## ORDER NOTES ARE HIDDEN
			}
		elsif ($O2->in_get('want/order_notes') eq '') {
			## ORDER NOTES ARE BLANK
			}
		else {
			$OUTPUT .= qq~
			<img src="$graphics_url/blank.gif" width="1" height="8"><br>
			<table border="0" cellpadding="2" cellspacing="1" width="100%">
				<tr>
					<td colspan="2" class="ztable_head zadminpanel_table_head">Order Notes</td>
				</tr>
				<tr>
					<td valign="middle" align="left" class="ztable_row">~.
					&ZTOOLKIT::htmlify($O2->in_get('want/order_notes')).
					qq~<br></td>
				</tr>
			</table>
			~;
			}
		

		if ($C->cid() > 0) {
			## only show back to customer page for fully authed accounts.
			$OUTPUT .= qq~
				<div align="center">
				<a href="$customer_url">Back to Customer Page</a>
				</div>
				~;
			}

		}
	else {
		$OUTPUT = "<div class='zwarn'>Unknown verb: $ACTION</div>";
		}

	$lm->pooshmsg("STOP|+order status");

	push @SITE::PREBODY, { 'TYPE'=>'OUTPUT',HTML=>$OUTPUT };
	return();
	}


##
##
##
sub verb_order_payment {
	my ($lm,$C,$v,$cacheref,$SITE) = @_;
	require ZPAY;
	
	my $payrec = undef;
	my $payuuid = $v->{'payuuid'};
	my $payby = $v->{lc("payby.$payuuid")};
	my $verb = $v->{'verb'};


	my ($O2) = $cacheref->{'*O2'};
	my $orderid = $O2->oid();
	my $cartid = $O2->cartid();
	my $customer_url = $SITE->URLENGINE()->get('customer_url');

	print STDERR Dumper($SITE::v);

	if (not $lm->can_proceed()) {
		## shit already happened
		}
	elsif (($verb eq 'order/payment/add') && ($payuuid eq '')) {
		## adding payments does not require a uuid.
		$payby = $v->{'payby'};
		my $is_allowed = 0;
		my ($ar) = ZPAY::payment_methods($O2->username(),prt=>$O2->prt(),admin=>0,'*C'=>$C,'cart2'=>$O2);
		foreach my $method (@{$ar}) {
			if ($method->{'id'} eq $payby) { $is_allowed++; }
			}
		if ($payby eq '') {
			$lm->pooshmsg("ERROR|+URI param 'payby' is required and was not received. (please select a payment method)");
			}
		elsif (not $is_allowed) {
			$lm->pooshmsg("ERROR|+URI param 'payby' was sent a non-allowed value");
			}
		else {
			my %VARS = ();
			my ($AMOUNT) = sprintf("%.2f",($O2->in_get('sum/balance_due_total') - $O2->in_get('sum/balance_auth_total')));
			if ($payby =~ /^WALLET\:([\d]+)$/) {
				$payby = 'WALLET';
				$VARS{'ID'} = int($1);
				$VARS{'WI'} = int($1);
				}
			elsif ($payby =~ /^GIFTCARD:(.*?)$/) {
				$payby = 'GIFTCARD';
				$VARS{'GC'} = $1;
				}
			elsif ($payby eq 'CREDIT') {
				$VARS{'CC'} = $v->{'cc'};
				$VARS{'CV'} = $v->{'cv'};
				$VARS{'YY'} = $v->{'yy'};
				$VARS{'MM'} = $v->{'mm'};
				if (my $err = &ZPAY::verify_credit_card($VARS{'CC'},$VARS{'MM'},$VARS{'YY'},$VARS{'CV'})) {
					$lm->pooshmsg("ERROR|+verify_credit_card:$err");
					}
				elsif (($VARS{'CV'} eq '') && ($SITE->webdb()->{'cc_cvvcid'}==2)) {
					## cc_cvvcid 1="can" 2="must" have
					$lm->pooshmsg("ERROR|+cvv # is required for credit card transactions");
					}
				}
			
			if ($lm->can_proceed()) {
				($payrec) = $O2->add_payment($payby,
					$AMOUNT,
					'note'=>'Added by Customer after Order was placed',
					'luser'=>'*CUSTOMER',
					'app'=>'vstore'
					);
				$O2->process_payment('INIT',$payrec,%VARS);
				$O2->order_save();		

				&ZOOVY::add_event($O2->username(),"PAYMENT.UPDATE",
					'ORDERID'=>$O2->oid(),
					'PRT'=>$O2->prt(),
					'SDOMAIN'=>$SITE->sdomain(),
					'SRC'=>'Customer Account @ '.$SITE->sdomain(),
					);
				}
			}

		}
	elsif ((not defined $payuuid) || ($payuuid eq '')) {
		$lm->pooshmsg("ERROR|+URI param 'payuuid' is required and was not received.");
		}
	elsif ((not defined $payby) || ($payby eq '')) {
		$lm->pooshmsg("ERROR|+URI param 'payby' is required and was not received.");
		}
	elsif (not (($payrec) = $O2->payment_by_uuid($payuuid)) ) {
		$lm->pooshmsg("ERROR|+Could not find payment uuid: $payuuid in oid:$orderid");
		}
	elsif ($verb eq 'order/payment/layaway') {
		## Note: we should make sure this is actually a valid payby
		$payrec->{'tender'} = $payby;
		$O2->add_history("customer set layaway $payuuid to $payby");
		$O2->order_save();
		}
	else {
		## SUCCESS!
		$lm->pooshmsg("ERROR|+Invalid verb: $verb");
		}


	my $OUTPUT = '';
	if (not $lm->can_proceed()) {

		if ((&ZOOVY::servername() eq 'newdev') && (0)) {
			$OUTPUT = qq~<div class="ztxt">~;
			$OUTPUT .= "NEW DEBUG: OID: $orderid UUID: $payuuid";
			$OUTPUT .= "</div>";
			$OUTPUT .= "<pre>";
			$OUTPUT .= Dumper($lm);
			$OUTPUT .= "</pre>";
			}
		else {
			my ($statref) = $lm->whatsup();
			$OUTPUT .= "<div class='zwarn'>$statref->{'+'}</div>";
			}

		$OUTPUT .= "<a href=\"$customer_url/order/status?orderid=$orderid&cartid=$cartid\">Return to order status</a>";
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT, };
		$lm->pooshmsg("STOP|+layaway");
		# $lm->pooshmsg("REDIRECT|url=$customer_url|+cancel_order order has no attribs.");
		}
	else {
		$lm->pooshmsg("REDIRECT|url=$customer_url/order/status?orderid=$orderid&cartid=$cartid");
		}

	return();
	}	




##
##
##
sub verb_order_cancel {
	my ($lm,$C,$v,$cacheref,$SITE) = @_;
	require ZPAY;

	my $OUTPUT = qq~<div class="ztxt">~;
	my $customer_url = $SITE->URLENGINE()->get('customer_url');
	
	my $login = $SITE::CART2->in_get('customer/login');
	
	my $sure = $SITE::v->{'sure'};
	my $checksure = $SITE::v->{'checksure'};
	
	my ($O2) = $cacheref->{'*O2'};
	my $orderid = $O2->oid();
	my $cartid = $O2->cartid();

	my ($status,$created);
	
	if (defined $O2) {
		($status,$created) = ($O2->pool(),$O2->in_get('our/order_ts'));
		if (defined($status) && ($status ne '')) { }
		else { 
			$lm->pooshmsg("REDIRECT|url=$customer_url|+cancel_order order has no attribs.");
			}
		}
	else {
		## Order doesn't exist?
		$lm->pooshmsg("REDIRECT|url=$customer_url|+cancel_order order does not exist.");
		}
		
	if ($status ne 'RECENT') {
		$lm->pooshmsg("REDIRECT|url=$customer_url|+cancel_order status not recent");
		}
	
	my $disable_cancel = $SITE->webdb()->{'disable_cancel_order'};
	if (not defined $disable_cancel) { $disable_cancel = 0; }
	if ($disable_cancel) {
		$lm->pooshmsg("REDIRECT|url=$customer_url|+cancel_order disabled/not allowed");
		}
	
	my $mode;
	unless ($sure) {
		$mode = "confirm";
		}
	else {
		if ($O2->pool() eq "RECENT") {
			$O2->add_history("Customer requested cancellation of order",etype=>1+8,luser=>"*CUSTOMER");
			$O2->in_set('want/order_notes',sprintf("%s\nCANCELLATION REQUESTED BY CUSTOMER.",$O2->in_get('want/order_notes')));
			$O2->order_save();
#			require ZMAIL;
			my $subject = "Customer Cancelled Order $orderid via website";
			my $message = "Customer requested cancellation of Order $orderid via website.";

			&ZOOVY::add_enquiry($SITE->username(),"CUSTOMER.ORDER.CANCEL",
				class=>"MSG",
				ORDERID=>$orderid,
				LINK=>"order:$orderid",
				title=>$subject,
				detail=>$message
				);

#			&ZMAIL::notify_customer($SITE->username(), 'support@zoovy.com', $subject, $message, "CANCEL", "ORDERID=$orderid");
#			require TODO;
#         my ($t) = TODO->new($SITE->username(),writeonly=>1);
#         $t->add(class=>"MSG",link=>"order:$orderid",title=>$subject,detail=>$message);
  
			$mode = "complete";
			}
		else {
			$mode = "invalidstatus";
			}
		}
	
	$OUTPUT .= qq~<div class="ztxt">\n~;
	
	if ($mode eq "confirm") {
		$OUTPUT .= "<br>\n";
		if ($checksure) {
 			$OUTPUT .= qq~<div class="zwarn"><i>You must make sure the checkbox is selected if you wish to cancel this order!</i><br></div\n~;
			}
		else {
			$OUTPUT .= qq~<i>You must make sure the checkbox is selected if you wish to cancel this order!</i><br>\n~;
			}
		$OUTPUT .= qq~
			<form action="$customer_url/order/cancel" method="get">
			<input type="hidden" name="orderid" value="$orderid">
			<input type="hidden" name="cartid" value="$cartid">
			<input type="hidden" name="checksure" value="1">
			<input type="checkbox" name="sure" value="1"><b>Yes, I am sure I want to cancel order $orderid</b><br>
			<input class="zform_button" type="submit" value="Cancel Order">
			</form>
		<br><br>
			<form action="$customer_url/order/status"  method="get">
			<b>No, I do not want to cancel this order.</b>
			<input type="hidden" name="orderid" value="$orderid"><br>
			<input type="hidden" name="cartid" value="$cartid">
			<input class="zform_button" type="submit" value="Return to Order Status">
			</form>
		~;
		}
	elsif ($mode eq "complete") {
		$OUTPUT .= qq~
			<br>
			Order cancellation complete.<br>
			<form action="$customer_url/order/status"  method="get">
			<input type="hidden" name="orderid" value="$orderid"><br>
			<input class="zform_button" type="submit" value="Return to Order Status">
			</form>
		~;
		}
	elsif ($mode eq "invalidstatus") {
		$OUTPUT .= qq~
			<br>
			Order cancellation cannot be completed. The merchant must have started processing the order.
			If you return to the Order Status page, you can still send the merchant Feedback regarding this order<br>
			<form action="$customer_url/order/status" method="get">
			<input type="hidden" name="orderid" value="$orderid"><br>
			<input type="submit" value="Return to Order Status">
			</form>
		~;
		}
	
	$OUTPUT .= qq~</div>\n~;	

	$lm->pooshmsg("STOP|+cancel order");

	push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT, };
	return();
	}	



##
## 
##
sub verb_order_feedback {	
	my ($lm,$C,$v,$cacheref,$SITE) = @_;
	require ZTOOLKIT;
	
	use Time::Local;
	use Time::Zone;
	
	my $timestamp_offset = &Time::Zone::tz_offset('pdt');
	my $customer_url = $SITE->URLENGINE()->get('customer_url');

	my $login = '';
	my $ACTION = $SITE::v->{'action'};
	if (not defined $ACTION) { $ACTION = ''; }
	
	# See if we need a login
	#my $disable_login = $SITE->webdb()->{'order_status_disable_login'};
	#if (not defined $disable_login) { $disable_login = 0; }
	#if ($disable_login) { if ($SITE->webdb()->{'aol'}) { 
	#	$disable_login = 1; } 
	#	}

	my ($O2) = $cacheref->{'*O2'};
	my $orderid = $O2->oid();
	my $cartid = $O2->cartid();
	
	if ($lm->can_proceed()) {
		}
	#elsif ($ACTION eq 'PAYCREDIT') {
	#	$O2->set_attrib('payment_method','CREDIT');
	#	$ACTION = '';
	#	}

	# Get the info needed for order display
	my %prodmeta;
	my @details = ();

	my $OUTPUT = '';
	my $graphics_url = $SITE->URLENGINE()->get('graphics_url');
	$SITE->title( "Order $orderid" );

	if (not $lm->can_proceed()) {
		}
	elsif ($ACTION eq 'error') {
		# Do nothing, what needs to be said is said already.
		}
	elsif ($ACTION eq '') {

		my ($billhtmladdr) = $O2->addr_vars('bill')->{'%HTML'};
		my ($shiphtmladdr) = $O2->addr_vars('ship')->{'%HTML'};
		$OUTPUT .= qq~
			<table class="zadminpanel_table" border="0" width="100%">
			~;

		## find out if order is from a marketplace
		## 	and determine the feedback link
		## 	below action only occurs if feedback_link is defined
		my $mktref = ();
		if ($O2->pu_get('our/mkts') ne '') {
			foreach my $id (@{&ZOOVY::bitstr_bits($O2->pu_get('our/mkts'))}) {
				my $sref = &ZOOVY::fetch_integration('id'=>$id);
				$mktref = $sref;

				print STDERR "DST: $mktref->{'dst'}\n";
				## working on getting on the feedback_links
				## these could/should also live in @ZOOVY::INTEGRATIONS
				if ($mktref->{'dst'} eq 'EBA' || $mktref->{'dst'} eq 'EBF') {
					## EBAY Order
					$mktref->{'feedback_link'} = 'http://feedback.ebay.com/ws/eBayISAPI.dll?LeaveFeedback';
					}
				elsif ($mktref->{'dst'} eq 'BUY') {
					## Buy.com Order
					## this _needs_ to be modified (if possible), its really not direct enough for customers to leave feedback
					## ie it requires the erefid, not good
					$mktref->{'feedback_link'} = 'https://ssl.buy.com/AC/OrderLookup.aspx?source=buy';
					}
				elsif ($mktref->{'dst'} eq 'AMZ') {
					$mktref->{'feedback_link'} = 'http://www.amazon.com/gp/feedback/leave-customer-feedback.html?order=%AMAZON_ORDERID%';
					}
				}
			}

		
		#print STDERR "powerreviews: ".Dumper($SITE->{'%NSREF'})."\n";
		## determine order type to be sent to ORDER::VIEW
		my $order_type = '';


		if ($O2->pool() =~ /^(CANCEL|DELETED)$/) {
			## don't let them leave feedback, if the order is cancelled or deleted
			my ($pool) = $O2->pool();
			$OUTPUT .= qq~
			<tr>
				<td colspan="2" class="ztable_head zadminpanel_table_head">Order is $pool</td>
			</tr>
			<tr>
				<td colspan="2">
<b>This order is currently in status "$pool". Feedback is not allowed at this time.</b>
				</td>
			</tr>
~;
			$order_type = 'INVOICE';
			}
		elsif (($O2->in_get('our/balance_due') - $O2->in_get('our/balance_auth'))>0) {
			## BEGIN PAYMENT DUE
			$OUTPUT .= qq~
			<tr>
				<td colspan="2" class="ztable_head zadminpanel_table_head">Payment Incomplete</td>
			</tr>
			<tr>
				<td colspan="2">
<b>This order is currently has a balance due. Feedback is not allowed at this time.</b>
				</td>
			</tr>
~;
			$order_type = 'INVOICE';
			## END PAYMENT DUE
			}
		elsif ($mktref->{'feedback_link'} ne '') {
			$OUTPUT .= qq~
				<tr>
					<td colspan="2" class="ztable_head zadminpanel_table_head">~.$mktref->{'title'}.qq~ Order</td>
				</tr>
				<tr>
					<td colspan="2">
We appreciate your business and ask that you take a moment of your busy schedule
to rate us on ~.$mktref->{'title'}.qq~.  
<br>
<br>
Please give us the highest possible score in all categories, unless you feel we do not
deserve that score - in which case we'd greatly appreciate your feedback as to how 
we could have improved.  
<br>
<br>
By giving us a good rating you are ensuring that we'll continue to bring you the best
possible service at the most competitive prices!
<br>
<br>
<a href="~.$mktref->{'feedback_link'}.qq~">Leave Feedback</a> 
					</td>
				</tr>~;

			$order_type = 'INVOICE';
			}
		elsif ($SITE->nsref()->{'powerreviews:enable'}>0) {
			## POWERREVIEWS merchant
			$order_type = 'PR_FEEDBACK';
			}
		else {
			$order_type = 'FEEDBACK';
			}

		$OUTPUT .= qq~</table>~;
				
		## CART CONTENTS
		# $OUTPUT .= &CART::VIEW::as_html($o, 'INVOICE', $SITE->webdb(),undef);
		$OUTPUT .= &CART2::VIEW::as_html( $O2, $order_type,{},$SITE);


		$OUTPUT .= qq~<img src="$graphics_url/blank.gif" width="1" height="8"><br>
			<table border="0" cellpadding="2" cellspacing="1" width="100%">
			~;

		my $contact_url = $SITE->URLENGINE()->get('contact_url');
		$OUTPUT .= qq~
				<tr><td colspan="2" class="ztable_head zadminpanel_table_head">Contact Us</td></tr>
				<tr>
					<td valign="middle" align="left" width="65%" class="ztable_row">
						<b>If you have any questions or concerns about this order, please let us know.</b><br>
					</td>
					<form action="$contact_url" method="post">
					<td valign="middle" align="center" width="35%"  class="ztable_row">
						<input type="hidden" name="orderid" value="$orderid">
						<input type="hidden" name="cartid" value="$cartid">
						<input type="hidden" name="validate" value="0">
						<input class="zform_button" type="submit" value="Contact Us">
					</td>
					</form>
				</tr>
			</table>
		~;
	
	
		if ($C->cid() > 0) {
			## only show back to customer page for fully authed accounts.
			$OUTPUT .= qq~
				<div align="center">
				<a href="$customer_url">Back to Customer Page</a>
				</div>
				~;
			}

		}
	else {
		$OUTPUT = "<div class='zwarn'>Unknown verb: $ACTION</div>";
		}

	$lm->pooshmsg("STOP|+order feedback");

	push @SITE::PREBODY, { 'TYPE'=>'OUTPUT',HTML=>$OUTPUT };
	return();
	}

##
##
sub verb_wishlist {
	my ($lm,$C,$v) = @_;
	push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>qq~
		Wishlist Page
		~, };		
	}

sub verb_rewards {
	my ($lm,$C,$v) = @_;
	push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>qq~
		Rewards Page
		~, };
	}

sub verb_rma {
	my ($lm,$C,$v) = @_;
	push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>qq~
		RMA Page
		~, };
	}

sub verb_review {
	my ($lm,$C,$v) = @_;
	push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>qq~
		Review Page
		~, };

	return();
	}



sub verb_order_copy {
	my ($lm,$C,$v,$cacheref,$SITE) = @_;

	my ($O2) = $cacheref->{'*O2'};
	my $ORIG_OID = $O2->oid();

	my %URLparams = ();
	# my $ostuff = $o->stuff();
	$lm->pooshmsg("INFO|+copying order $ORIG_OID");

	# $SITE::CART->empty();


	foreach my $item (@{$O2->stuff2()->items()}) {
		my $stid = $item->{'stid'};
		my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($stid);
	
		next if ($item->{'base_price'}<0);	# skip negative promotions!
		next if ($item->{'is_promo'});
		next if (substr($stid,0,1) eq '%');

		if (&ZOOVY::productidexists($SITE->username(),$pid)) {
			# skip deleted items.
			my $newSTID = PRODUCT::generate_stid(pid=>$pid,invopts=>$invopts,noinvopts=>$noinvopts,virtual=>$virtual);
			my ($pid,$claim,$invopts,$noinvopts,$virtual) = &PRODUCT::stid_to_pid($newSTID);
			my ($P) = PRODUCT->new($SITE->username(),$pid);

			# my $pref = &ZOOVY::fetchsku_as_hashref($SITE->username(),$newSTID);

			if (not $P->is_purchasable()) {
				## skip products with blank prices!
				$lm->pooshmsg("ERROR|+Item $newSTID is configured to not allow website purchase");
				}
			else {
				my $suggested_variations = $P->suggest_variations('stid'=>$newSTID);
				my $selected_variations = &STUFF2::variation_suggestions_to_selections($suggested_variations);
				my ($item,$ilm) = $SITE::CART2->stuff2()->cram( $P->pid(), $item->{'qty'}, $selected_variations, '*P'=>$P );
				$item->{'is_reorder'} = $ORIG_OID;
				$lm->merge($ilm);
			#	my %newitem = ( product=>$pid, stid=>$newSTID, qty=>$item->{'qty'}, full_product=>$pref, description=>$item->{'description'} );
			#	$newitem{'is_reorder'} = $ORIG_OID;
			#	if (defined $item->{'*options'}) {
			#		my %options = ();
			#		foreach my $opt (keys %{$item->{'*options'}}) {
			#			$options{ substr($opt,0,2) } = substr($opt,2); 
			#			}
			#		$newitem{'%options'} = \%options;
			#
			#		#$newitem{'*options'} = $item->{'*options'};
			#		#$newitem{'pog_sequence'} = $item->{'pog_sequence'};
			#		#$newitem{'pogs_processed'} = $item->{'pogs_processed'};
			#		#$newitem{'pogs_price_diff'} = $item->{'pogs_price_diff'};
			#		}
			#	## we implicitly set the attribs we want to copy 
			#	my ($err,$errmsg) = $SITE::CART->stuff()->legacy_cram( \%newitem, schedule=>$SITE::CART->fetch_property('schedule'));
			#	if ($err) { $lm->pooshmsg("ERROR|+$errmsg"); }
				}
			}
		else {
			$lm->pooshmsg("ERROR|+Item $pid is no longer available for purchase.");
			}
		}

	# $lm->pooshmsg("REDIRECT|url=$customer_url|+cancel_order disabled");
	my $cart_url = $SITE->URLENGINE()->get('cart_url').'?'.&ZTOOLKIT::buildparams(\%URLparams);

	if ($lm->had('ERROR')) {
		my $OUTPUT = qq~<div class="ztxt">
<div>
We apologize, but one or more errors were encountered while attempting to re-create the order.
</div>
~;
		foreach my $msg (@{$lm->msgs()}) {
			my ($ref, $status) = LISTING::MSGS::msg_to_disposition($msg);	
			if ($ref->{'!'} eq 'ERROR') {
				$OUTPUT .= "<div class=\"zwarn\">ERROR: $ref->{'+'}</div>\n";
				}
			}

		$OUTPUT .= qq~
Please review the errors above, then 
<a href="$cart_url">Proceed to Shopping Cart</a>
</div>
~;	
		$lm->pooshmsg("STOP|+verb copy order - display errors");
		push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>$OUTPUT };
		}
	else {
		$lm->pooshmsg("SUCCESS|+Successfully copied order");
		$lm->pooshmsg("REDIRECT|url=$cart_url|+cart_url");
		}

	return($lm);	
	}


sub verb_updatepayment {
	my ($lm,$C,$v,$cacheref,$SITE) = @_;
	require ZPAY;

	my $customer_url = $SITE->URLENGINE()->get('customer_url');
	
	my $VERB = $SITE::v->{'verb'};
	my $cc_verify_errors;
	my $orderid;
	
	my $OUTPUT = '';	
	##############################################################################
	## Output Page
	$OUTPUT .= qq~<div align="center">\n~;
	
	if ($VERB eq "") {
		$OUTPUT .= "<br>\n";
		if ($cc_verify_errors) {
			$OUTPUT .= "<font color='red'>Please Try Again.</font><br>Errors: $cc_verify_errors<br>";
			}
		}
	elsif ($VERB eq "SUCCESS") {
		$OUTPUT .= qq~
			<br>
			Order payment information updated complete.<br>
			<form action="$customer_url/order/status"  method="get">
			<input type="hidden" name="orderid" value="$orderid"><br>
			<input type="submit" value="Return to Order Status">
			</form>
		~;
		}
	elsif ($VERB eq "ERROR") {
		$OUTPUT .= qq~
			<br>
			Order update cannot be completed. The merchant must have started processing the order.
			If you return to the Order Status page, you can still send the merchant a message regarding this order<br>
			<form action="$customer_url/order/status" method="get">
			<input type="hidden" name="orderid" value="$orderid"><br>
			<input type="submit" value="Return to Order Status">
			</form>
		~;
		}
	
	$OUTPUT .= qq~</div>\n~;

	push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT };
	return();
	}




############################################################################################################
##
##
##
############################################################################################################















####################################################################
##
##
##
sub panel_account {
	my ($cacheref) = @_;

	my $SITE = $cacheref->{'*SITE'};
	my $customer_url = $SITE->URLENGINE()->get('customer_url');
	my ($C) = $cacheref->{'*C'};

	my $body = '<table>';
	my $is_wholesale = 0;

	if (my ($schedule) = $C->is_wholesale()) {
		my ($SCH) = &WHOLESALE::load_schedule($SITE->username(),$schedule);
		$is_wholesale|=1;
		if ($SCH->{'realtime_inventory'}) { $is_wholesale |= 2; }
		if ($SCH->{'realtime_products'}) { $is_wholesale |= 4; }
		if ($SCH->{'realtime_orders'}) { $is_wholesale |= 8; }
		# $body .= "<tr><td>WHOLESALE[".$C->is_wholesale()."] is_wholesale=$is_wholesale</td></tr>";
		}
	if ($is_wholesale&1) {
		$body .= "<tr><td valign='top'>&#187;&nbsp;</td><td valign='top'><a href=\"$customer_url/wholesale/order\">Quick Order Entry Form</a></div></td></tr>\n";

		if (($is_wholesale & 4)==4) {
			$body .= qq~
	<tr>
	<td valign='top'>&#187;&nbsp;</td>
	<td valign='top'>Export Products:<br>
		<a target="_blank" href="~.$SITE->URLENGINE()->get('nonsecure_url').qq~/export/products.xml?verb=export&file=products.xml">XML</a> |
		<a target="_blank" href="~.$SITE->URLENGINE()->get('nonsecure_url').qq~/export/products.csv?verb=export&file=products.csv">CSV</a> 
	</td></tr>
	~;	
			}

		if (($is_wholesale & 2)==2) {
			$body .= qq~
	<tr>
	<td valign='top'>&#187;&nbsp;</td>
	<td valign='top'>Export Inventory:<br>
		<a target="_blank" href="~.$SITE->URLENGINE()->get('nonsecure_url').qq~/export/inventory.xml?verb=export&file=inventory.xml">XML</a> |
		<a target="_blank" href="~.$SITE->URLENGINE()->get('nonsecure_url').qq~/export/inventory.csv?verb=export&file=inventory.csv">CSV</a> 
	</td></tr>
~;
			}

		$body .= qq~<tr><td></td></tr>~;
		}
	
	$body .= "<tr><td valign='top'>&#187;&nbsp;</td><td valign='top'><a href=\"$customer_url/newsletter/config\">Email Settings</a></td></tr>\n";
	$body .= "<tr><td valign='top'>&#187;&nbsp;</td><td valign='top'><a href=\"$customer_url/password\">Change Password</a></td></tr>\n";
#	$body .= "<tr><td valign='top'>&#187;&nbsp;</td><td valign='top'><a href=\"".$SITE->URLENGINE()->get('support_url')."\">Customer Service</a></td></tr>\n";
#	if ($SITE::CART->fetch_property('aolsn') eq '') {
#		$body .= "<tr><td valign='top'>&#187;&nbsp;</td><td valign='top'><a href=\"#\" onClick=\"window.location='http://my.screenname.aol.com/_cqr/login/login.psp?siteId=zoovy&siteState=v%3D1*m%3D$SITE->username()*c%3D".$SITE::CART->id()."';\" target=\"_top\">Link AOL/Compuserve/AIM screen name</a></td></tr>\n";
#		}
	$body .= "<tr><td valign='top'>&#187;&nbsp;</td><td valign='top'><a href=\"$customer_url/logout\">Log Out</a></div></td></tr>\n";
	
	$body .= "</table>";
	return(&box('Account Management',$body));
	}


####################################################################
##
##
##
#sub panel_wholesale {
#	my ($cacheref) = @_;
#
#	my $SITE = $cacheref->{'*SITE'};
#	my ($C) = $cacheref->{'*C'};
#
#	my $OUTPUT = '';
#	## test for "is_wholesale"
#	if (my ($schedule) = $C->is_wholesale()) {
#		my $body = '';
#		my ($SCH) = &WHOLESALE::load_schedule($SITE->username(),$schedule);
#		$body .= "Schedule: ".$SITE::CART2->in_get('our/schedule')." $SCH->{'TITLE'}<br>";
#		if ($SCH->{'welcome_txt'} ne '') { $body .= $SCH->{'welcome_txt'}."<br>"; }
#		if (defined $C) {
#			my ($wsaddr) = $C->fetch_address('WS'); ## $wsaddr = $addr
#			# open F, ">/tmp/asdf";	print F Dumper($wsaddr,$C);close F;
#
#			if ($wsaddr->{'ws_city'} ne '') {
#				## use Data::Dumper; $body .= Dumper($wsinfo)."<br>";
#				if ($wsaddr->{'LOGO'}) { $body .= "<img src=\"".&GTOOLS::imageurl($SITE->username(),$wsaddr->{'LOGO'},70,200,'FFFFFF')."\" width=200 height=70><br>"; }
#				$body .= $wsaddr->as_html();
#				}
#			}
#		$OUTPUT .=  &box('Wholesale',$body);		
#		}
#	return($OUTPUT);
#	}


####################################################################
##
##
##
sub panel_rewards {
	my ($cacheref) = @_;

	my $SITE = $cacheref->{'*SITE'};
	### REWARDS MANAGEMENT
	my ($OUTPUT);
	if ( $cacheref->{'*C'}->get('INFO.REWARD_BALANCE') ) {
		my $points = int($cacheref->{'*C'}->get('INFO.REWARD_BALANCE'));
		my $body = qq~<div align="left">Available Points: $points<br></div>~;
		if ($SITE->username() eq 'cubworld') {
			$body .= qq~
<div>
<a target="_blank"  href="http://www.cubworld.com/category/rewards_program/">Learn More: Cubworld Rewards</a>
</div>
~;
			}
		# $body .= "CID: ".$C->cid();
		# use Data::Dumper; $body .= "<pre>".&ZOOVY::incode(Dumper($C))."</pre>";
		# <div align="right"><a href="/rewards.cgi">Learn More</a></div>~;
		$OUTPUT .= &box('Rewards Program',$body);
		};
	
	return($OUTPUT);
	}

####################################################################
##
##
##
sub panel_tickets {
	my ($cacheref) = @_;
	my $SITE = $cacheref->{'*SITE'};

	### TICKETS MANAGEMENT
	my $OUTPUT = '';

	my $customer_url = $SITE->URLENGINE()->get('customer_url');
	$OUTPUT .= qq~<form name="ticketfrm" id="ticketfrm" method="GET" action="$customer_url/ticket/create">~;

	my $SITE = $cacheref->{'*SITE'};
	my ($C) = $cacheref->{'*C'};
	my $ticketsref = CUSTOMER::TICKET::getTickets($SITE->username(),CID=>$C->cid());	
	if (scalar(@{$ticketsref})==0) {
		$OUTPUT .= qq~<div class="ztxt">No Tickets</div>~;
		}
	else {
		foreach my $ticketref (@{$ticketsref}) {
			$OUTPUT .= sprintf("<li> <a href=\"$customer_url/ticket/view?tktcode=%s\">[%s] %s</a> - %s</li>",$ticketref->{'TKTCODE'},$ticketref->{'TKTCODE'},$ticketref->{'SUBJECT'},$ticketref->{'STATUS'});
			}
		}

	$OUTPUT .= qq~
<input type="hidden" name="verb" value="ticket/create">
<input class="zform_button zform_button1" type="submit" name="button" value=" Create Ticket ">
</form>
	~;

	$OUTPUT = &box('Tickets',$OUTPUT);

	return($OUTPUT);
	}



####################################################################
##
##
##
sub panel_incomplete {
	my ($cacheref) = @_;


#	## INCOMPLETE ITEMS
#	my $login = $cacheref->{'login'};
#	my $SITE = $cacheref->{'*SITE'};
#
#	my $OUTPUT = '';
#
#	my $SITE = $cacheref->{'*SITE'};
#	my (@claimset) = &EXTERNAL::fetch_customer_claims($SITE->username(),$SITE->prt(),$login,1);
#
#	my @STIDSREF = ();
#	if (scalar(@claims)>0) {
#		foreach my $claim (@claims) {
#			&EXTERNAL::update_stage($SITE->username(),$external_id,'V');
#			}
#		}
#
#	if (scalar(@STIDSREF)>0) {
#		my $body = '';
#		my $cart_url = $SITE->URLENGINE()->get('cart_url');
#
#		# my $stidsref = &EXTERNAL::fetch_customer_claims($SITE->username(),$SITE::CART2->in_get('customer/login'),1);
#
#		my %ini = ();
#		$ini{'@claims'} = $stidsref;
#		$ini{'HAS_CLAIMS'}++;
#
#		$ini{'DEFAULT'} = '&COLS=1';
#		$ini{'FORMAT'} = 'CUSTOM';
#		$ini{'HTML'} = q~
#
#<% print($FORM); %>
#<div align='center'>
#<table border='0' cellpadding='3' cellspacing='0' width='90%' class='zborder'>
#<tr>
#	<td colspan='2' class='ztable_head'>Purchases waiting for Checkout</td>
#</tr>
#<!-- ROW -->
#<tr>
#<!-- PRODUCT -->
#	<td valign='top' width='1%' class='ztable_row<% print($row.alt); %>'>
#	<% load($zoovy:prod_thumb); default(""); default($zoovy:prod_image1); image(w=>"100",h=>"100",tag=>"1",alt=>$zoovy:prod_name);  print(); %>
#	</td>
#
#	<td class='ztable_row<% print($row.alt); %> ztable_row' align='left'>
#	<div class='ztable_row_title' style='margin-bottom:4px;'><% load($zoovy:prod_name); default(""); print(); %></div>
#	
#	<div style='line-height:135%; margin-bottom:5px;' class='ztable_small'>
#	<% load($zoovy:prod_desc);  default(""); format(wiki,title1=>"",/title1=>"",title2=>"",/title2=>"",title3=>"",/title3=>"",listitem=>"",/listitem=>"",list=>"",/list=>"",hardbreak=>""); strip(length=>"300"); format(encode=>"entity"); print(); %>
#	</div>
#
#	<div style='font-weight:bold; margin-bottom:5px;' align='right'>
#	<% load($zoovy:base_price); default(""); format(money); print(); %><br>
#	<% load($ADD_FIELD); print(); %>
#	</div>
#	
#	<div id="pogs"><% load($POGS); default(""); print(); %></div>
#	</td>
#<!-- /PRODUCT -->
#</tr>
#<!-- /ROW -->
#<tr>
#	<td class='ztable_head' align='right' colspan='2'><input type='submit' class='zform_button' value='add items to cart'></input></td>
#</tr>
#</table>
#</div>
#~;
#
#		my ($html) = &TOXML::RENDER::RENDER_PRODLIST(\%ini,undef,$SITE);
#		$OUTPUT .= &box('Items Waiting For Purchase',$body);
#		} 
#	return($OUTPUT);
	}


####################################################################
##
##
##
sub panel_customeraddresses {
	my ($cacheref) = @_;;

	my $SITE = $cacheref->{'*SITE'};
	my $OUTPUT = '';

	my $customer_url = $SITE->URLENGINE()->get('customer_url');
	
	my $body = '';
	my ($C) = $cacheref->{'*C'};
	if ((defined $C) && 
		((scalar(@{$C->fetch_addresses('BILL')})>0) || (scalar(@{$C->fetch_addresses('SHIP')})>0))) 
		{
			$body .= '<table cellspacing="1" cellpadding="2" width="100%" class="bg_color">';
			$body .= '<tr><td valign="top" class="">';
			if (1) {
				$body .= "<b>Billing Address</b><br>";
				my $shortcut = undef;
				foreach my $addr (@{$C->fetch_addresses('BILL')}) {
					if (defined $shortcut) { $body .= "<hr>\n"; }
					$shortcut = $addr->shortcut();
					$body .= 
						$addr->as_html().
						qq~[ <a href="$customer_url/addresses?type=bill&shortcut=$shortcut">EDIT</a> ]~;
					}
				}
			$body .= '</td><td valign="top">';
			if (1) {
				$body .= "<b>Shipping Address</b><br>";
				my $shortcut = undef;
				foreach my $addr (@{$C->fetch_addresses('SHIP')}) {
					if (defined $shortcut) { $body .= "<hr>\n"; }
					$shortcut = $addr->shortcut();
					$body .= 
						$addr->as_html().
						qq~[ <a href="$customer_url/addresses?type=ship&shortcut=$shortcut">EDIT</a> ]~;
					}
				}
			$body .= '</td></tr>';
			$body .= '</table>';

			$OUTPUT .=  &box('Address(es)',$body);
			}
	return($OUTPUT);
	}


####################################################################
##
##
##
sub panel_payments {
	my ($cacheref) = @_;


	my $SITE = $cacheref->{'*SITE'};
	my ($C) = $cacheref->{'*C'};
	my $customer_url = $SITE->URLENGINE()->get('customer_url');

	my $OUTPUT = '';
	my $payments_on_file = $C->wallet_list();
	if (not defined $payments_on_file) {
		$payments_on_file = [];
		}
	foreach my $payref (@{$payments_on_file}) {
		my ($DEFAULT) = ($payref->{'#*'})?
			'<i>Default</i>':
			qq~<a href="$customer_url/payments/prefer?id=$payref->{'WI'}">Make Default</a>~;

		$OUTPUT .= qq~
		<tr>
			<td><a href="$customer_url/payments/remove?id=$payref->{'WI'}">[Remove]</a></td>
			<td>$payref->{'TD'}</td>
			<td>$DEFAULT</td>
		</tr>
		~;
		}

	if (($OUTPUT ne '') || 1) {
		if ($OUTPUT eq '') { $OUTPUT = "<tr><td colspan=3><i>No Payment Methods on File</i></td></tr>"; }
		$OUTPUT = qq~
		<table cellspacing="1" border=0 cellpadding="2" width="100%" class="bg_color">
			<tr class="ztable_head zadminpanel_table_head">
				<td class="ztable_head zadminpanel_table_head"></td>
				<td class="ztable_head zadminpanel_table_head">Description</td>
				<td class="ztable_head zadminpanel_table_head"></td>
			</tr>
			$OUTPUT
		</table>
		<a class="zlink" href="$customer_url/payments/add-cc">Add Credit Card</a>
		~;
		$OUTPUT = &box('Payments On File',$OUTPUT);
		}
	
	return($OUTPUT);
	}

####################################################################
##
##
##
sub panel_giftcards {
	my ($cacheref) = @_;

	my ($C) = $cacheref->{'*C'};
	my $SITE = $cacheref->{'*SITE'};

	my $OUTPUT = '';
	if (defined $C) {
		my $body = '';
		require GIFTCARD;
		my $giftref = &GIFTCARD::list( $SITE->username(), PRT=>$C->prt(), CID=>$C->{'_CID'} );

		if ((defined $giftref) && (scalar(@{$giftref})>0)) {
			
			my $carturl = $SITE->URLENGINE()->get('cart_url');
			use Data::Dumper;
			$body .= '<table cellspacing="1" border=0 cellpadding="2" width="100%" class="bg_color">';
			$body .= qq~
						<tr class="bg_color">
							<td><strong>Code</strong></td>
							<td><strong>Note</strong></td>
							<td><strong>Balance</strong></td>
							<td><strong>Expires</strong></td>
						</tr>
			~;
			
			foreach my $card (@{$giftref}) {
				$body .= '<tr>'.
						"<td valign=\"top\"><a href=\"$carturl?giftcardcode=$card->{'CODE'}\">".&GIFTCARD::obfuscateCode($card->{'CODE'},1).'</a></td>'.
						'<td valign="top">'.$card->{'NOTE'}.'</td>'.
						'<td valign="top">'.$card->{'BALANCE'}.'</td>'.
						'<td valign="top">'.&ZTOOLKIT::pretty_date($card->{'EXPIRES_GMT'}).'</td>'.
						'</tr>';
				
				# Dumper($card);
				}
			$body .= '</table>';
			$OUTPUT .= &box('GiftCards &amp; Credits',$body);
			}
		}
	return($OUTPUT);
	}





	
#######################################################################
##
## Generates the Order History box w/HTML
## 
sub panel_orderhistory {
	my ($cacheref) = @_;
	
	my $SITE = $cacheref->{'*SITE'};

	my ($C) = $cacheref->{'*C'};
	my $is_wholesale = $C->is_wholesale();
	my $webdbref = $SITE->webdb();
	 
	require CUSTOMER::BATCH;
	my $SITE = $cacheref->{'*SITE'};

	my @orders = ();
	if ((defined $C) && (ref($C) eq 'CUSTOMER')) {
		@orders = &CUSTOMER::BATCH::customer_orders($SITE->username(),$C->cid(),100);
		}
	if ((scalar @orders)==0) { return(); }
		
	
		my $out = qq~
<!-- ORDER HISTORY TABLE -->
<table cellspacing="1" cellpadding="2" width="100%">
	<tr class="ztable_head zadminpanel_table_head">
	~.(($is_wholesale)?'<td class="ztable_head zadminpanel_table_head">Reference #</td>':'').qq~
	<td class="ztable_head zadminpanel_table_head">Order ID</td>
	<td class="ztable_head zadminpanel_table_head">Date</td>
	<td class="ztable_head zadminpanel_table_head">Status</td>
	<td class="ztable_head zadminpanel_table_head">Amount</td>
	~.(($webdbref->{'order_status_reorder'})?'<td class="ztable_head zadminpanel_table_head">Re-Order</td>':'').qq~
	</tr>
	~;

	my $customer_url = $SITE->URLENGINE()->get('customer_url');
	my $i = 0;
	foreach my $orderid (@orders) {
		my $class = ($i++%2)?"zadminpanel_table_row0":"zadminpanel_table_row1";
		next if ($orderid eq '');
		# my ($o) = ORDER->new($SITE->username(),$orderid,'CREATE'=>0);
		# my ($o) = undef;
		my ($O2) = CART2->new_from_oid($SITE->username(),$orderid);
		next if (not defined $O2);
		
		my $created = &ZTOOLKIT::pretty_date($O2->in_get('our/order_ts'));
		# my $pool = ucfirst(lc($O2->pool()));
		my $pool = $O2->pool();
		my $amount = sprintf("%.2f",$O2->in_get('sum/order_total')); # $o->get_attrib('order_total'));
		my $pc = &ZPAY::payment_status_short_desc($O2->in_get('flow/payment_status')); # $o->get_attrib('payment_status'));
		$pc = ucfirst(lc($pc));

		my $reference = ($is_wholesale)?'<td>'.$O2->in_get('want/po_number').'</td>':'';

		$out .= qq~
			<tr class="$class">
				$reference
				<td><a href="$customer_url/order/status?orderid=$orderid">$orderid</td>
				<td>$created</td>
				<td>$pc-$pool</td>
				<td align='right'>\$$amount</td>
				~.(($webdbref->{'order_status_reorder'})?qq~<td><a href="$customer_url/order/copy?orderid=$orderid">Re-Order</a></td>~:'').qq~
			</tr>
			~;
		}
	
	$out .= qq~
</table>
<!-- END ORDER HISTORY TABLE -->
~;
	
	$out = box("Order History",$out,'no_padding'=>1);

	return($out);
	}




##
##
##
##
##
sub handler {
	my ($iniref,$toxml,$SITE) = @_;

	if (ref($SITE) ne 'SITE') { warn Carp::confess("PAGE::customer::handler requires SReF to be a SITe object"); }


	## admin panel css -
## updates made by jt on 2/17/2010 to fix defaults (grey text on grey bg changed to black text on grey bg)
	push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$SITE->txspecl()->translate3(qq~
<style type='text/css'>

/* zadminpanel classes should ONLY be used inside the customer login area */

.zadminpanel {
 border: <% loadurp("CSS::zborder.border"); default("1px solid #cccccc"); print(); %>; 
 margin-bottom:20px;
 }

.zadminpanel_head {
 background:<% loadurp("CSS::zbox_head.bgcolor"); default("#333333"); print(); %>; 
 padding:2px 5px; 
 font-weight: bold;
 font-size:<% loadurp("CSS::ztitle.font_size"); default("14px"); print(); %>; 
 color:<% loadurp("CSS::zcolor_dark.color"); default("#ffffff"); print(); %>; 
 font-family:<% loadurp("CSS::ztitle.font_family"); default("Arial, Helvetica, sans-serif"); print(); %>;
 }

.zadminpanel_body {
 background:<% loadurp("CSS::zbox_body.bgcolor"); default("#efefef"); print(); %>;
 font-size:<% loadurp("CSS::zbox_body.font_size"); default("14px"); print(); %>; 
 color:<% loadurp("CSS::zbox_body.color"); default("#000000"); print(); %>; 
 font-family:<% loadurp("CSS::zbox_body.font_family"); default("Arial, Helvetica, sans-serif"); print(); %>;
 }

.zadminpanel_padding {padding:5px;}

.zadminpanel_table { 
	background: <% loadurp("CSS::zbox_body.bgcolor"); default("#efefef"); print(); %>; 
	}

/* set on table to control the cellspacing color */
.zadminpanel_table{
 background:<% loadurp("CSS::zbox_body.bgcolor"); default("#efefef"); print(); %>;
 }

/* for column headers */
.zadminpanel_table_head {
 background:<% loadurp("CSS::ztable_head.bgcolor"); default("#efefef"); print(); %>;
 color:<% loadurp("CSS::ztable_head.color"); default("#000000"); print(); %>;
 font-size:<% loadurp("CSS::ztable_head.font_size"); default("12px"); print(); %>;
 font-weight:bold;
 }

/* for rows that don't alternate colors */
.zadminpanel_table_row {
 color:<% loadurp("CSS::ztable_row.color"); default("#000000"); print(); %>;
 font-size:<% loadurp("CSS::ztable_row.font_size"); default("11px"); print(); %>;
 }
 
.zadminpanel_table_row0 {
 background:<% loadurp("CSS::ztable_row0.bgcolor"); default("#efefef"); print(); %>;
 color:<% loadurp("CSS::ztable_row0.color"); default("#000000"); print(); %>;
 font-size:<% loadurp("CSS::ztable_row0.font_size"); default("11px"); print(); %>;
 }

.zadminpanel_table_row1 {
 background:<% loadurp("CSS::ztable_row1.bgcolor"); default("#efefef"); print(); %>;
 color:<% loadurp("CSS::ztable_row1.color"); default("#000000"); print(); %>;
 font-size:<% loadurp("CSS::ztable_row1.font_size"); default("11px"); print(); %>;
 }

.zadminpanel_table_rows {
 background:<% loadurp("CSS::zcolor_light.bgcolor"); default("#efefef"); print(); %>;
 color:<% loadurp("CSS::zcolor_light.color"); default("#00efef"); print(); %>; 
 font-size:<% loadurp("CSS::ztable_row1.font_size"); default("11px"); print(); %>;
 }


.zadminpanel_table_row_title{
 color:<% loadurp("CSS::ztable_row_title.color"); default("#000000"); print(); %>;
 font-size:<% loadurp("CSS::ztable_row_title.font_size"); default("12px"); print(); %>;
 font-weight:bold;
 }

.zadminpanel_table_row_small{
 color:<% loadurp("CSS::ztable_row_small.color"); default("#666666"); print(); %>;
 font-size:<% loadurp("CSS::ztable_row_small.font_size"); default("10px"); print(); %>;
 }

</style>~) };





	# $SITE->{'+REQUEST_URI'}
	my %cache = ();

	require LISTING::MSGS;
	my ($lm) = LISTING::MSGS->new($SITE->username());
	
	my $C = undef;
	my $VERB = $SITE::v->{'verb'};
	if (($VERB eq '') && ($SITE->uri() =~ /\/customer\/(.*?)$/)) {
		## so if we get passed ?verb= then we use that, but if we don't then /customer/some/verb and we act like it was
		## a uri parameter.
		$VERB = $1;
		$SITE::v->{'verb'} = $VERB;	
		# $lm->pooshmsg("PRE-INIT-VERB|$VERB");
		}
	# $lm->pooshmsg("INIT-VERB|$VERB");
	# $lm->pooshmsg("INFO|+REQUEST_URI:".Dumper($SITE->{'+REQUEST_URI'},$VERB));

	if ($VERB =~ m/^newsletter/) {
		$lm->pooshmsg("SOFTAUTH-ALLOWED|newsletter");
		}
	elsif ($VERB =~ m/^order\/.*?/) {
		$lm->pooshmsg("SOFTAUTH-ALLOWED|order/");
		}
	else {
		$lm->pooshmsg("SOFTAUTH-DENY|VERB:$VERB|DEBUG:this is okay (perhaps we're not doing a soft auth)");
		}

	$lm->pooshmsg("DEBUG|VERB:$VERB|URI:".$SITE->uri());

	my $customer_url = $SITE->URLENGINE()->get('customer_url');
	# if ($customer_url eq '') { $customer_url = "$SITE::secure_url/customer"; }
	my $OUTPUT = '';

	##
	## PHASE1: Make sure we only access this on the SSL server
	if (($lm->can_proceed()) && (not $SITE->_is_secure())) { 
		$lm->pooshmsg('ERROR|+SSL Session Required');
		my $url = &ZTOOLKIT::makeurl("$customer_url/$VERB", $SITE::v_mixed);
		$lm->pooshmsg("REDIRECT|url=$url|+customer area requires login");
		}

	
	

	## Default the login to the last one if we didn't get one passed in
	#if (($lm->can_proceed()) && ($login eq '') && &SITE::last_login()) {
	#	$login = &SITE::last_login();
	#	}


	my $authenticated = 0;	# +1 = soft
									# +2 = full
	my $login = '';
	if ($login eq '') { $login = $SITE::v->{'login'}; }
	if ($login eq '') { $login = $SITE::v->{'email'}; }
	if (defined $login) { 
		$login =~ s/[^\w\@\.\-]//g;	# strip invalid characters in login (ex: space)
		$login = lc($login); 
		}
	my $password = defined($SITE::v->{'password'}) ? $SITE::v->{'password'} : '';
	
	
	if (($lm->can_proceed()) && ($VERB eq 'login')) {
		my $url = $SITE->URLENGINE()->rewrite($SITE::v_mixed->{'url'});
		if ($url eq '') { 
			## no redirect, just show main page
			$VERB = ''; 
			}
		elsif ($url =~ /\/logout$/) {
			## don't let them redirect to the logout page, or they'll think this didn't work.
			$lm->pooshmsg("WARN|+attempted redirect to logout page during login, ignoring REDIRECT");
			$VERB = '';
			}
		else {
			## redirect to a specific url
			print STDERR "URL: $url\n";
			$lm->pooshmsg("REDIRECT|url=$url|+customer requested redirect (login)");
			$lm->pooshmsg("STOP");
			}
		}

	## Delete the login property of the cart
	#if (&SITE::request_login()) {
	if (($lm->can_proceed()) && ($VERB eq 'logout')) {
		@SITE::cookies = ();
		$SITE::CART2->logout();
		
		my $url = $SITE->URLENGINE()->get('home_url');
		$lm->pooshmsg("PRIORITY-REDIRECT|url=$url|+Successfully Logged Out $url");
		$lm->pooshmsg("STOP");
		}


	## check to see if we can use softauth parameters (each verb has different softauth parameters)
	my $softauth_customer_id = 0;
	if ($VERB =~ /^newsletter/) { 
		#my $cpnid =    defined($SITE::v->{'cpn'}) 	? $SITE::v->{'cpn'} : '';
		#my $cpg =    defined($SITE::v->{'cpg'}) 	? $SITE::v->{'cpg'} : '';
		#if ($cpg =~ /^\@CAMPAIGN:([\d]+)$/) { $cpg = $1; }
		if ((defined $SITE::v->{'username'}) && (not defined $SITE::v->{'email'})) {
			## backward compatibility, convert's username => email
			$SITE::v->{'email'} = $SITE::v->{'username'};
			}
		if ((defined $SITE::v->{'aolemail'}) && (not defined $SITE::v->{'email'})) {
			## backward compatibility, convert's aolemail => email
			$SITE::v->{'email'} = $SITE::v->{'aolemail'};
			}

		if ((defined $SITE::v->{'cpn'}) && (defined $SITE::v->{'cpg'}) && (defined $SITE::v->{'email'})) {
			if (&CUSTOMER::RECIPIENT::softauth_user($SITE::CART2->username(),$SITE::CART2->prt(),$SITE::v->{'email'},$SITE::v->{'cpg'},$SITE::v->{'cpn'})) { 
				$softauth_customer_id = &CUSTOMER::resolve_customer_id($SITE->username(), int($SITE->prt()), ,$SITE::v->{'email'});
				$lm->pooshmsg("SOFTAUTH-WIN|+USER:$SITE::v->{'email'} CPN:$SITE::v->{'cpn'} CPNID:$SITE::v->{'cpg'}");
				}
			}
		}

	if (
		($lm->had('SOFTAUTH-ALLOWED')) && 
		(($login ne '') || ($SITE::v->{'cartid'} ne '')) ) {
		my $try_softauth = $SITE->webdb()->{'order_status_disable_login'};
		if (not defined $try_softauth) { $try_softauth = 0; }
		# if ($disable_login) { if ($SITE->webdb()->{'aol'}) { $disable_login = 1; } 

		my ($orderid) = &SITE::untaint($SITE::v->{'orderid'});

		my ($O2,$err) = undef;
		if (($try_softauth) && ($orderid ne '')) {
			($O2,$err) = CART2->new_from_oid($SITE->username(),$orderid);
			## one more quick check to make sure the order isn't corrupt
			# if ($err eq '') { ($err) = $o->check(); }

			if ($err ne '') { $lm->pooshmsg("SOFTAUTH-FAIL|+$err"); }
			# elsif (ref($o) ne 'ORDER') { $lm->pooshmsg("SOFTAUTH-FAIL|+Order object not defined."); }
			elsif (ref($O2) ne 'CART2') { $lm->pooshmsg("SOFTAUTH-FAIL|+Order object not defined."); }
			# elsif ($O2->pool() eq '') { $lm->pooshmsg("SOFTAUTH-FAIL|+Unable to get order status for $orderid");  }
			elsif ($O2->pool() eq '') { $lm->pooshmsg("SOFTAUTH-FAIL|+Unable to get order status for $orderid");  }
			}

		if ($lm->had('SOFTAUTH-FAIL')) {
			}
		elsif ((not defined $O2) || (ref($O2) ne 'CART2')) {
			}
		elsif (($SITE::v->{'cartid'} ne '') && ($SITE::v->{'cartid'} eq $O2->cartid()) ){
			## check for full access escalation (auto-login)
			## automatic login!
			$login = $O2->in_get('bill/email');
			$SITE::CART2->login($login,'',authenticated=>1);		
			$SITE::CART2->save();
			$lm->pooshmsg("SOFTAUTH-WIN|+order:$orderid cartid:$SITE::v->{'cartid'}");
			$cache{'*O2'} = $O2;
			}
	 	elsif ( lc($O2->in_get('bill/email')) eq $login ) {
			$lm->pooshmsg("SOFTAUTH-WIN|+order:$orderid email:$login");
			$cache{'*O2'} = $O2;
			}
		else {
			$lm->pooshmsg("INFO|+did not perform softauth");
			}

		if ($lm->had('SOFTAUTH-WIN')) {
			## yay, now lets try to load a customer record or we'll FAKE one.
			$softauth_customer_id = &CUSTOMER::resolve_customer_id($SITE->username(), int($SITE->prt()), $O2->in_get('bill/email'));
			if ($softauth_customer_id <= 0) {
				## shit, this customer doesn't have an account.
				($C) = CUSTOMER->new($SITE->username(), PRT=>int($SITE->prt()), 'CREATE'=>0, 'EMAIL'=>$O2->in_get('bill/email'));
				}
			}

		}


	if (($lm->can_proceed()) && (($VERB eq 'signup') || ($VERB eq 'signup/save'))) {
		## /customer/signup does not require a login!
		my $OUTPUT = '';

		require WHOLESALE::SIGNUP;
		my ($cfg) = WHOLESALE::SIGNUP::load_config($SITE->username(),int($SITE->prt()));
		
		my $fields = undef;
		if ($cfg->{'enabled'}) {
			$fields = WHOLESALE::SIGNUP::json_to_ref($cfg->{'json'});
			}

		if (($cfg->{'enabled'}) && ($VERB eq 'signup/save')) {
			## all the save magic happens here!
			my $vars = WHOLESALE::SIGNUP::ref_to_vars($fields,$SITE::v);
			my $err = undef;
			foreach my $f (@{$vars}) {
				next if $err;
				if ($f->{'err'}) { $err = "$f->{'label'} ($f->{'err'})"; }
				}
			if (not defined $err) {
				($err) = &WHOLESALE::SIGNUP::save_form($SITE->username(),int($SITE->prt()),$cfg,$vars);
				}

			if ($err) {
				$lm->pooshmsg("ERROR|+An error occurred: $err");
				}
			else {
				$lm->pooshmsg("SUCCESS|+Thanks!");
				}
			}

		if (not $cfg->{'enabled'}) {
			$OUTPUT = $SITE->msgs()->get('page_customer_signup_notenabled');
			}
		elsif ($lm->had('SUCCESS')) {
			$OUTPUT = $SITE->msgs()->get('page_customer_signup_success');
			}
		else {

			if (my $lmref = $lm->had('ERROR')) {
				$OUTPUT .= qq~<div class='zwarn'>$lmref->{'+'}</div>~;
				}

			$OUTPUT .= qq~
<form method="POST" id="customer_signup_form" name="customer_signup_form" action="$customer_url/signup/save">
<input type="hidden" name="VERB" value="signup/save">
~.&WHOLESALE::SIGNUP::ref_to_sitehtml($fields,$SITE::v).qq~
</form>
~;
			}

		print STDERR "OUTPUT: $OUTPUT\n";

		$lm->pooshmsg("STOP|+customer signup");
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT };
		$VERB = '*';
		}



	if (($lm->can_proceed()) && (($VERB eq 'question') || ($VERB eq 'mailpassword') || ($VERB eq 'answer')) ) {
		## recover password
		##
		## has several different stages:
		##		login=> prompts for login
		##		question=> displays questions
		##		mailpassword => sends email for given login
		##
		my $OUTPUT = '';
		my $answer = &ZTOOLKIT::def(&ZOOVY::incode($SITE::v->{'answer'}));
		my ($password, @errors, $question);

		my $tryC = undef;
		if ($login eq '') {
			$lm->pooshmsg("ERROR|+Please specify your login");
			}
		else {
			($tryC) = CUSTOMER->new($SITE->username(), PRT=>int($SITE->prt()), EMAIL=>$login, INIT=>1, CREATE=>0); 
			if (not defined $tryC) {
				$lm->pooshmsg("ERROR|+Specified login is invalid/customer record not found."); 
				}
			}
		

		if (not $lm->can_proceed()) {
			}
		elsif ($VERB eq 'question') {
			my $hintnum = $tryC->fetch_attrib('INFO.HINT_NUM');
			my $hintans = $tryC->fetch_attrib('INFO.HINT_ANSWER');

			if ((defined $hintnum) && ($hintnum) && (length($hintans)>3)) {
				my %hints = &CUSTOMER::fetch_password_hints();
				$question = $hints{$hintnum};
				}
			else {
				$VERB='mailpassword'; 
				}
			}
	
		if (not $lm->can_proceed()) {
			}
		elsif ($VERB eq 'answer') {
			my $hintans = $tryC->fetch_attrib('INFO.HINT_ANSWER');

			if ($hintans eq $SITE::v->{'answer'}) {
				($password) = $tryC->initpassword(reset=>1);
				$VERB = 'answer';		# provide answer
				}
			else {
				$VERB = 'question';
				$lm->pooshmsg("ERROR|+Your answer did not match our records, the password is being mailed to $login.");
				$VERB = 'mailpassword';
				}
			}

		##############################################################################
		## Set Up FLOW Variables	
		$SITE->title( "Forgotten Password" );
	
		##############################################################################
		## Output Page
		

		if ($VERB eq 'login') {
			$OUTPUT .= $SITE->msgs()->get('page_forgot_login_msg',{
				'%FORGET_URL%'=>"$customer_url/forgot",
				'%REDIRECT_URL%'=>'',
				'%LAST_LOGIN_FROM_COOKIE%'=>$login,
				});
			}
		elsif ($VERB eq 'question') {
			my $url = '';
			$OUTPUT .= qq~
				When you created your account you were asked for a question and answer to validate who you are in case you forgot your password.  
				Please answer the question <i>"$question"</i><br>
				<form action="" method="post">
				<input type="hidden" name="verb" value="answer">
				<input type="hidden" name="url" value="$url">
				<input type="hidden" name="login" value="$login">
				Your Answer : <input type="text" length="50" maxlength="50" name="answer" value="$answer"><input type="submit" name="submit" value="Go"><br>
				</form>
			~;
			}
		elsif ($VERB eq 'mailpassword') {
			## the customer/login/forgot must also pass verb='mailpassword' for now.
			my ($CID) = &CUSTOMER::resolve_customer_id($SITE->username(), int($SITE->prt()), $login);
			if ($CID>0) {
				## in case you were wondering, sending the CUSTOMER.PASSWORD.REQUEST email actually is what triggers the initpassword
				## function in the customer (so we don't do it here!)
				#require SITE::EMAILS;
				#require SITE;
				### my ($SITE) = SITE->new($SITE->username(),PRT=>int($SITE->prt()), NS=>$SITE->profile());
				#my ($se) = SITE::EMAILS->new($SITE->username(), '*SITE'=>$SITE);
				#$se->sendmail('CUSTOMER.PASSWORD.REQUEST',CID=>$CID);
				#$se = undef;
				my ($BLAST) = BLAST->new($SITE->username(),int($SITE->prt()));
				my ($rcpt) = $BLAST->recipient('CUSTOMER',$CID);
				my ($msg) = $BLAST->msg('CUSTOMER.PASSWORD.REQUEST');
				$BLAST->send($rcpt,$msg);
	
				#require TOXML::EMAIL;
				#&TOXML::EMAIL::sendmail($SITE->username(), 'CUSTOMER.PASSWORD.REQUEST', '', CID=>$CID);

				$OUTPUT .= qq~
				Your password has been emailed to $login.<br>
				<br>
				<br>
				<a href="$customer_url/login">Back to Login</a><br>
				~;
				}
			else {
				$OUTPUT .= qq~Email address provided does not belong to a customer.~;
				}
			}
		elsif (not defined $tryC) {
			$OUTPUT .= qq~
			Could not load your customer record.
			~;
			}
		elsif (($VERB eq 'answer') && ($password eq '')) {
			($password) = $tryC->initpassword(reset=>1);
			$OUTPUT .= qq~
			Your password was blank, and was changed to "$password".
			~;
			}
		elsif ($VERB eq 'answer') {
			$OUTPUT .= qq~
				Your password is "$password".<br>
				<br>
				<a href="$customer_url/login">Back to Login</a><br>
			~;
			}
		else {
			$OUTPUT .= qq~Unknown command verb=[$VERB]~;
			}

		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT };
		$VERB = '*';
		}



	## PHASE2: Test to see if we are already logged in, or if we passed credentials
	##		login - email address
	##		password - password		
	my $customer_id = 0;
	if (not $lm->can_proceed()) {
		## some type of internal error
		}
	elsif ($lm->had('SOFTAUTH-WIN')) {
		$lm->poosh("SUCCESS|+Softauth was accepted!");
		}
	elsif (my $cartlogin = $SITE::CART2->in_get('customer/login')) {
		## already logged in!
		my $login_gmt = $SITE::CART2->in_get('customer/login_gmt');
		if (($login_gmt+86400)>time()) {
			$login = $SITE::CART2->in_get('customer/login');
			$customer_id = CUSTOMER::resolve_customer_id($SITE->username(), $SITE->prt(), $cartlogin);
			}
		else {
			$lm->poosh("AUTHREQUIRED|+Your login has expired, please login again");
			}
		}	
	elsif ((defined $SITE::v->{'login'}) && ($login eq '') && (defined $SITE::v->{'password'}) && ($password eq '')) {
		## need to throw a message asking them to login.
		$lm->pooshmsg("AUTHREQUIRED|+Please provide a valid login id and password.");
		$login = undef;
		}
	elsif ((defined $SITE::v->{'login'}) && ($login eq '')) {
		$lm->pooshmsg("AUTHREQUIRED|+Login was blank");
		$login = undef;
		}
	elsif ((defined $SITE::v->{'password'}) && ($password eq '')) {
		$lm->pooshmsg("AUTHREQUIRED|+Supplied password was blank");
		$login = undef;
		}

	##
	## SANITY: at this point $customer_id is already set
	##

	if (not $lm->can_proceed()) {
		## already got an internal error
		}
	elsif ($customer_id>0) {
		## already logged in
		}
	elsif ($softauth_customer_id>0) {
		## already logged in
		$C = CUSTOMER->new($SITE->username(), PRT=>int($SITE->prt()), INIT=>1, CID=>$softauth_customer_id);
		}
	elsif ($lm->had('SOFTAUTH-WIN')) {
		## sometimes SOFTAUTH users might not have an account
		}
	elsif (($login ne '') && ($password ne '')) {
		## Try to log in if we have a email and password
		$lm->pooshmsg("DEBUG|+TRYING TO AUTH: $SITE->username(), prt: $SITE->prt(), $login, $password");
		($customer_id) = &CUSTOMER::authenticate($SITE->username(), $SITE->prt(), $login, $password);
		## Did we get authenticated
		$lm->pooshmsg("DEBUG|+GOT CUSTOMERID: $customer_id");
		print STDERR "LOGIN: $login / PASS: [$password] / customer: $customer_id\n";
		if ($customer_id > 0) {
			
			$SITE::CART2->login($login,$password,authenticated=>1);
			$SITE::CART2->save();	
			}
		else {
			$lm->pooshmsg("AUTHREQUIRED|+Login or password does not match, or account is locked.");
			}
		}
	else {
		$lm->pooshmsg("AUTHREQUIRED|+Please login in order to proceed.");
		}


	foreach my $msg (@{$lm->msgs()}) {
		my ($ref,$status) = LISTING::MSGS::msg_to_disposition($msg);
		my $okay_to_show = 1;
		## don't show debugging messages if debug isn't turned on.
		if ((not $PAGE::customer::debug) && ($status eq 'DEBUG')) { $okay_to_show = 0; }

		if ($okay_to_show) {
			$OUTPUT .= qq~<div class="zwarn">$ref->{'+'}</div><br>~;
			}
		}

	if ($SITE::DEBUG || $PAGE::customer::debug) {
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>qq~DEBUG. VERB:$VERB<br>~ };
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>qq~DEBUG. CUSTOMER:$customer_id<br>~ };
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>qq~DEBUG. LOGIN:$login<br>~ };
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>qq~PASSWORD:$password<br>~ };
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>'<pre>DEBUG (SITE::v)'.&ZOOVY::incode(Dumper($SITE::v)).'</pre><br>' };
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>'<pre>DEBUG lm:'.&ZOOVY::incode(Dumper($lm)).'</pre><br>' };
		}



	#print STDERR 'PREBODY '.Dumper(\@SITE::PREBODY);
	#die();


	#if ((defined $err) && ($err ne '')) {
	#	## something definitly went wrong
	#	$SITE::v->{ lc($iniref->{'ID'}.'_err') } = $err;
	#	}
	#if (($iniref->{'ID'} eq 'LOGIN') && ($customer_id>0)) {
	#	## Change the url to customer_main if we didn't get one, or we're
	#	## pointing back at ourselves for some reason
	#	my $url = defined($SITE::v->{'url'})?$SITE::v->{'url'}:'';
	#	if ($url eq '') {
	#		## customer login page always redirects
	#		$url = $SITE->URLENGINE()->get('customer_url');
	#		}
	#	elsif (defined $SITE::OVERRIDES{'dev.login_redirect_url'}) {
	#		## this forces a customer to redirect to a different url on login.
	#		$url = $SITE->URLENGINE()->rewrite($SITE::OVERRIDES{'dev.login_redirect_url'});
	#		}
	#	else {
	#		$url = $SITE->URLENGINE()->rewrite($url);
	#		}
#
#		$SITE::v->{'url'} = $url;
#		$SITE::PG = '?REDIRECT/login success!';
#		$SITE::REDIRECT_URL = $url;
#		}
#	else {
#		## nothing went wrong, we should just show the login page
#		}


	if (not $lm->can_proceed()) {
		}
	elsif ((not defined $C) && ($customer_id>0)) {
		## $C is not set, but we know $customer_id for lookup
		($C) = CUSTOMER->new($SITE->username(),PRT=>$SITE->prt(),CREATE=>0,CID=>$customer_id,INIT=>0xFF);
		if (not defined $C) {
			$lm->pooshmsg("ERROR|+Unable to load customer record:$customer_id from database");
			}
		elsif (ref($C) ne 'CUSTOMER') {
			$lm->pooshmsg("ERROR|+Customer:$customer_id was not returned a type CUSTOMER");
			}
		else {
			$lm->pooshmsg("INFO|+Successfully loaded customer:$customer_id from database");
			}
		}
	elsif (defined $C) {
		## something already set $C, yay!
		}
	else {
		## error, no way to load customer record
		$lm->pooshmsg("FAIL-FATAL|+Unable to ascertain which customer record to load from database");
		}
	
	#	($C) = $SITE::CART->fetch_property('customer');
	#	}

	## SANITY: at this point $VERB is set to whatever we're going to do 
	if (not $lm->can_proceed()) {
		}
	elsif ($VERB eq 'export') {
		if (not $SITE::CART2->in_get('is/wholesale')) {
			$lm->pooshmsg('ERROR|+export requires wholesale access');
			}
		else {
			$lm->pooshmsg('STOP|+Exporting file');
			$SITE->pageid( "?EXPORT/".&SITE::untaint($SITE::v->{'file'}) );
			}
		}
	elsif ($VERB eq 'password') {
		&verb_password($lm,$C,$SITE::v,\%cache,$SITE);
		}
	elsif ($VERB =~ /^newsletter/) {
		## note: softauth allowed
		$SITE::v->{'verb'} = $VERB;
		&verb_newsletter($lm,$C,$SITE::v,\%cache,$SITE);
		}
	elsif ($VERB =~ /^wholesale/) {
		$SITE::v->{'verb'} = $VERB;
		&verb_wholesale_order($lm,$C,$SITE::v,\%cache,$SITE);
		}
	elsif ($VERB =~ /^order/) {

		#if ($ACTION eq 'get_email') {
		#	$OUTPUT .= qq~
		#	<form action="$order_status_url" method="get">
		#	<input type="hidden" name="orderid" value="$orderid">
		#	<b>Email Address:</b> <input type="text" name="email" value="$email"> <input type="submit" value="Send">
		#	</form>
		#	~;
		#	}

		if ((not defined $SITE::v->{'orderid'}) || ($SITE::v->{'orderid'} eq '')) {
			$lm->pooshmsg("ERROR|+orderid is a required parameter for any type of order/___ activity");
			}
		elsif (defined $cache{'*O2'}) {
			## we've already loaded te order in question previously (possibly for authentication)
			}
		elsif ($SITE::v->{'orderid'} ne '') {
			my ($O2,$err) = CART2->new_from_oid($SITE->username(),$SITE::v->{'orderid'});
			if ($err ne '') {
				$lm->pooshmsg("ERROR|+ORDER object returned error \"$err\"");
				} 
			elsif ((not defined $O2) || (ref($O2) ne 'CART2')) {
				$lm->pooshmsg("ERROR|+undefined, or non-CART2 object reference returned");
				}
			elsif (
				(lc($O2->in_get('ship/email')) eq lc($login)) ||
				(lc($O2->in_get('bill/email')) eq lc($login)) || 
				($O2->in_get('customer/cid') eq $customer_id)
				) {
				$cache{'*O2'} = $O2;
				}
			else {
				$lm->pooshmsg("ERROR|+Information in order does not match information in customer record");
				}
			}

		if (not $lm->can_proceed()) {
			## shit happened.
			}
		elsif ($VERB eq 'order/copy') {
			## REORDER
			&verb_order_copy($lm,$C,$SITE::v,\%cache,$SITE);
			}
		elsif ($VERB eq 'order/status') {
			## note: softauth allowed
			&verb_order_status($lm,$C,$SITE::v,\%cache,$SITE);
			}
		elsif ($VERB eq 'order/cancel') {
			&verb_order_cancel($lm,$C,$SITE::v,\%cache,$SITE);
			}
		elsif ($VERB =~ /^order\/payment(.*?)$/) {
			## note: order/payment/subverb
			&verb_order_payment($lm,$C,$SITE::v,\%cache,$SITE);
			}
		elsif ($VERB eq 'order/feedback') {
			## note: softauth allowed
			&verb_order_feedback($lm,$C,$SITE::v,\%cache,$SITE);
			}
		}	
	elsif ($VERB =~ /^ticket\/(.*?)$/) {
		if ($SITE::v->{'verb'} eq '') { $SITE::v->{'verb'} = $1; }
		&verb_ticket($lm,$C,$SITE::v,\%cache,$SITE);
		}
	elsif ($VERB =~ /^payments/) {
		$SITE::v->{'verb'} = $VERB;
		&verb_payments($lm,$C,$SITE::v,\%cache,$SITE);
		}
	elsif ($VERB eq 'addresses') {
		&verb_addresses($lm,$C,$SITE::v,\%cache,$SITE);
		}
	elsif (($VERB eq 'login') || ($VERB eq '')) {
		## do nothing!
		}
	else {
		$lm->pooshmsg("ERROR|+Unknown verb:$VERB");
		}

	## update the status of incomplete items to "V" for visited.



#	$OUTPUT .=  qq~
#		<table cellspacing="4" cellpadding="0" width="100%">
#		<tr>
#			<td colspan="2">
#				<strong>Account Information: ~.$SITE::CART2->in_get('customer/login').qq~</strong>
#				~.(($SITE::CART->fetch_property('aolsn') ne '')?"<br>AOL ScreenName: ".$SITE::CART->fetch_property('aolsn'):'').qq~
#			</td>
#		</tr>
#		<tr>
#			<td valign="top" width="70%">
#		~;


	if (my $ref = $lm->had('PRIORITY-REDIRECT')) {
		## note: PRIORITY-REDIRECT *MUST* be handled before AUTHREQUIRED 
		##			example: we PRIORITY-REDIRECT as part of LOGOUT we don't redirect to LOGIN page (we can go elsewhere)
		$SITE->pageid( '?REDIRECT/'.$ref->{'+'} );
		$SITE::REDIRECT_URL= $ref->{'url'};
		return();
		}
	elsif (my $ref = $lm->had('AUTHREQUIRED')) {
		undef $FLOW::LOGIN;
		$SITE->title( "Customer Login" );
	
		$VERB = 'login';
		$lm->pooshmsg('STOP|+Login Page');

		## LEGACY *login page support
		$SITE->pageid( "*login" );
		my ($PG) = $SITE->pAGE("login");  # PAGE->new($SITE->username(),"login",'NS'=>$SITE->profile(),'PRT'=>$SITE->prt());
		$SITE->sset('_FS','*');
		$SITE::v->{'url'} = 
			# $SITE->rewritable_uri().
			$SITE->uri().
			(((scalar keys %{$SITE::v_mixed})>0)?('?'.&ZTOOLKIT::buildparams($SITE::v_mixed,0)):'');

		$lm->pooshmsg("DEBUG|+redirect url:$SITE::v->{'url'}");
		
		$SITE->layout( undef );
		if (defined $SITE::OVERRIDES{'flow.'.$SITE->pageid()}) { 
			$SITE->layout( $SITE::OVERRIDES{'flow.login'} ); 
			}
		#if ((not defined $SITE->layout()) && ($SITE::SREF->username() eq 'teramasu')) {
		#	$SITE->layout() = 'login-20090310';
		#	}
		elsif ($PG->docid()) {
			$SITE->layout( $PG->docid() );
			}
		else {
			## the default login page
			$SITE->layout( 'login-20080305' );
			}
		my ($layouttoxml) = TOXML->new('LAYOUT',$SITE->layout(),USERNAME=>$SITE->username(),FS=>$SITE->fs(),cache=>$SITE->cache_ts());

		#print STDERR "SITE::SREF = ".Dumper($SITE->prt());	
		#print STDERR "SITE::SREF = ".Dumper($SITE::SREF->prt());	
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT };

		## NOT SURE WHY BUT $str SHOULD *NOT* be APPENED TO OUTPUT AS IT'S OWN PREBODY -- it magically gets on there.
		##		(I think it might get pushed on as a prebody on it's own)
		my $str = &TOXML::RENDER::render_page({},$layouttoxml,$SITE);

		# push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$str };
		#$lm->pooshmsg('ERROR|+Login Required');
		#my $u = &ZTOOLKIT::makeurl($SITE->URLENGINE()->get('login_url'), 'url'=>$SITE::return_url);
		#$lm->pooshmsg("REDIRECT|url=$u|+customer area requires login");
		}
	elsif (my $ref = $lm->had('REDIRECT')) {
		##
		## note: use PRIORITY-REDIRECT if you want to send somebody to a URL before AUTH-REQUIRED
		##			
		$SITE->pageid( '?REDIRECT/'.$ref->{'+'} );
		$SITE::REDIRECT_URL= $ref->{'url'};
		return();
		}
	elsif (my $ref = $lm->had('STOP')) {
		## don't do anything! (except maybe set the page title)
		if (my $lmref = $lm->had('TITLE')) {
			$SITE->title( $lmref->{'+'} );
			}
		}
	elsif (my $ref = $lm->had('FAIL-FATAL')) {
		$SITE->title( 'A fatal error was experienced!' );
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$ref->{'+'} };
		}
	elsif ($VERB eq '*') {
		## hmm.. 
		}
	else {
		$cache{'*C'} = $C;
		$cache{'*SITE'} = $SITE;
		$cache{'login'} = $login;

		my $RIGHT_PANELS = '';
		$RIGHT_PANELS .= &panel_account(\%cache);
		$RIGHT_PANELS .= &panel_rewards(\%cache);

		if ($SITE->globalref()->{'cached_flags'} !~ /,CRM,/) {
			## no CRM bundle = NO tickets
			$RIGHT_PANELS .= '<!-- NO CRM -->';
			}
		else {
			my ($CTCONFIG) = &CUSTOMER::TICKET::deserialize_ctconfig($SITE->username(),$SITE->prt(),$SITE->webdb());
			if ($CTCONFIG->{'is_external'}) {
				$RIGHT_PANELS .= &panel_tickets(\%cache);
				}
			# $RIGHT_PANELS .= sprintf("is external: %d",$CTCONFIG->{'is_external'});
			}
	
		my $LEFT_PANELS = '';
		$LEFT_PANELS .= &panel_customeraddresses(\%cache);
		# $LEFT_PANELS .= &panel_incomplete(\%cache);
		# $LEFT_PANELS .= &panel_wholesale(\%cache);
		$LEFT_PANELS .= &panel_giftcards(\%cache);
		$LEFT_PANELS .= &panel_payments(\%cache);
		$LEFT_PANELS .= &panel_orderhistory(\%cache);

		print STDERR "PANELS DONE\n";

		$SITE->title( "Customer Management" );
		$OUTPUT .= $SITE->login_trackers($SITE::CART2);
		$OUTPUT .= qq~
<div id="customer_main">
<table cellspacing="4" cellpadding="0" width="100%">
<tr>
	<td class="ztxt" colspan=2 width="100%">
	<!-- HEADER PANELS GO HERE -->
	</td>
</tr>
<tr>
	<td class="ztxt"  valign="top" width="70%">
	<!-- 70% PANELS GO HERE -->
	$LEFT_PANELS

	</td>
	<td class="ztxt"  valign="top" width="30%">
	<!-- 30% PANELS GO HERE -->

	$RIGHT_PANELS

	</td>
</tr>
<tr>
	<td class="ztxt"  valign="top" width="100%" colspan="2">
	<!-- FOOTER PANELS GO HERE -->
	</td>
</tr>
</table>
</div>
		~;
		push @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>$OUTPUT };
		}


	if ($lm->had('ERROR')) {
		foreach my $msg (@{$lm->msgs()}) {
			my ($ref,$status) = LISTING::MSGS::msg_to_disposition($msg);
			if ($status eq 'ERROR') {
				unshift @SITE::PREBODY, { 'TYPE'=>'OUTPUT', HTML=>"<div class=\"zwarn\">$ref->{'_'}: $ref->{'+'}</div>\n" };
				}
			}
		}


	return();	
	}





sub box {
	my ($title,$body, %cache) = @_;

	## unless we get parameter 'no_padding' then we output zadminpanel_padding after zadminpanel_body for txt based margins
	my $padding = ($cache{'no_padding'})?'':'zadminpanel_padding';

	return(qq~
<div id="div_id" style="margin-bottom: 15px;"> 
<div class="zadminpanel">
<div class="zadminpanel_head">$title</div>
<div class="zadminpanel_body $padding">
$body
</div>
</div></div>~);

	}


__DATA__
##
##


1;	