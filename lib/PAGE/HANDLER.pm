package PAGE::HANDLER;

use Data::Dumper;
use strict;


require BLAST;
require CART2;

sub amazon_handler {
	my ($iniref,$toxml,$SITE,$dref) = @_;

	if (ref($SITE) ne 'SITE') { warn Carp::confess("PAGE::HANDLER::amazon_handler requires SITE object as SREF parameter"); }

	#http://hotnsexymama.zoovy.com/amazon.cgis?return&
	# 	amznPmtsOrderIds=103-6106627-1185859&
	#	amznPmtsReqId=WLPHf6rt6DoCI5VSgp2gx9CgJ&showAmznPmtsTYPopup=1&
	#	merchName=Zoovy Inc.&
	#	amznPmtsYALink=http%3A%2F%2Fhotnsexymama.zoovy.com%2Fcustomer_main.cgis%3FamznPmtsOrderIds%3D103-6106627-1185859%26amznPmtsReqId%3DWLPHf6rt6DoCI5VSgp2gx9Cg%26
	my $amzorderid = $SITE::v->{'amznpmtsorderids'};
	my $amzreqid = $SITE::v->{'amznpmtsreqid'};
	my $amztypop = $SITE::v->{'showamznpmtstypopup'};
	my $amzmerch = $SITE::v->{'merchname'};
	my $amzYAlink = $SITE::v->{'amznpmtsyalink'};

#create table AMZ_ORDERS (
#   ID integer unsigned auto_increment,
#   USERNAME varchar(20) default '' not null,
#   MID integer default 0 not null,
#   CREATED datetime,
#   CARTID varchar(24) default '' not null,
#   ORDERID varchar(12) default '' not null,
#   AMZ_PAYID varchar(24) default '' not null,
#   CART mediumtext default '' not null, 
#   PROCESSED_GMT integer unsigned default 0 not null,
#   primary key(ID),
#   unique(MID,CARTID),
#   unique(MID,AMZ_PAYID)
#);

	my $USERNAME = $SITE->username();
	my ($odbh) = &DBINFO::db_user_connect($SITE->username());
	my ($MID) = &ZOOVY::resolve_mid($SITE->username());

	my $pstmt = "select ORDERID from AMZPAY_ORDER_LOOKUP where MID=$MID /* $USERNAME */ and AMZ_PAYID=".$odbh->quote($amzorderid);
	my $sth = $odbh->prepare($pstmt);
	$sth->execute();
	my ($order_id) = $sth->fetchrow();
	$sth->finish();

	if ($SITE->client_is() eq 'BOT') {
		push @SITE::ERRORS, "Sorry, but we don't serve your type in here. (Regrettably you've been identified as a robot and cannot place orders)";
		}
	elsif (($amzorderid eq '') || ($amzreqid eq '')) {
		push @SITE::ERRORS, "Required variables: amznpmtsorderids, amznpmtsreqid were not received or understood.";
		}
	elsif (not defined $order_id) {	
		require CART2;
		my ($order_id) = CART2::next_id($SITE->username(),1);
		$SITE::CART2->in_set('our/orderid',$order_id);
		$SITE::CART2->in_set('mkt/amazon_orderid',$amzorderid);

		my ($pstmt) = &DBINFO::insert($odbh,'AMZPAY_ORDER_LOOKUP',{
			'MID'=>$MID,
			'USERNAME'=>$SITE->username(),
			'*CREATED'=>'now()',
			'CARTID'=>$SITE::CART2->cartid(),
			'ORDERID'=>$order_id,
			'AMZ_PAYID'=>$amzorderid,
			'AMZ_REQID'=>$amzreqid,
			'CART'=>$SITE::CART2->as_xml(210),
			'PROCESSED_GMT'=>0,
			},key=>['MID','CARTID'],sql=>1);
		$odbh->do($pstmt);
	
		my ($ID) = $odbh->selectrow_array("select last_insert_id()");
		if ($ID == 0) {
			&ZOOVY::confess($SITE->username(),"COULD NOT INSERT CHECKOUT_BY_AMAZON ORDER\n$pstmt\n",justkidding=>1);
			}
		}
	&DBINFO::db_user_close();

	my $out .= $SITE->msgs()->get('chkout_amazoncba_success');
	$out .= $SITE->conversion_trackers($SITE::CART2);
	$SITE::CART2->empty('reason'=>'amazon','scope'=>'order');
	
	push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>$out };
	return();
	}



##
## for handling supplier confirmations
##
sub confirm_handler {
	my ($iniref,$toxml,$SITE,$dref) = @_;

	my $confirm_url  = $SITE->URLENGINE()->get('confirm_url');
	require SUPPLIER;

	my $TH = $SITE::CONFIG->{'%THEME'};

	if ($SITE::v->{'submit'} eq ' Send Confirmation ') {
		my @ERRORS = &SUPPLIER::confirm_order($SITE->username(),
			&SITE::untaint($SITE::v->{'reference'}),
			&SITE::untaint($SITE::v->{'order_id'}),
			&SITE::untaint($SITE::v->{'order_total'}),
			&SITE::untaint($SITE::v->{'ship_method'}),
			&SITE::untaint($SITE::v->{'ship_num'}),
			&SITE::untaint($SITE::v->{'conf_person'}),
			&SITE::untaint($SITE::v->{'conf_email'}));

		if (scalar(@ERRORS)==0) {
			push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>qq~<font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">Order $SITE::v->{'order_id'} has been confirmed.</font>~, };
			$SITE::v->{'order_id'} = '';
			$SITE::v->{'order_total'} = '';
			$SITE::v->{'reference'} = '';
			$SITE::v->{'ship_num'} = '';
			}
		else {	
			foreach my $error (@ERRORS) {
				push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>qq~<font color="#$TH->{'alert_color'}">$error</font><br>~, };
				}
			}
		}

	my $conf_person = &ZOOVY::incode($SITE::v->{'conf_person'});
	my $conf_email = &ZOOVY::incode($SITE::v->{'conf_email'});

	my $reference = &ZOOVY::incode($SITE::v->{'reference'});
	my $order_id = &ZOOVY::incode($SITE::v->{'order_id'});
	my $order_total = &ZOOVY::incode($SITE::v->{'order_total'});
	my $ship_method = &ZOOVY::incode($SITE::v->{'ship_method'});
	my $ship_num = &ZOOVY::incode($SITE::v->{'ship_num'});



	my $html = qq~
		<br><br>
		Thank you for taking the time to confirm our order with your company. 
		Using this system helps us stay organized and also helps make sure we don't accidentally lose or duplicate orders.
		<br>
		<br>
		<form action="$confirm_url" method="get" target="$SITE::target">		
			<table>
				<tr>
					<td><font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">Your Name:</font></td>
					<td><input class="ztextbox" type="textbox" size="50" value="$conf_person" name="conf_person"> (optional)</td>
				</tr>
				<tr>
					<td><font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">Your Email:</font></td>
					<td><input class="ztextbox" type="textbox" size="50" value="$conf_email" name="conf_email"> (optional)</td>
				</tr>
				<tr>
					<td><font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">Reference#:</font></td>
					<td><input class="ztextbox" type="textbox" value="$reference" name="reference"> (Our reference #)</td>
				</tr>
				<tr>
					<td><font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">Order #:</font></td>
					<td><input class="ztextbox" type="textbox" value="$order_id" name="order_id"> (Your Order #)</td>
				</tr>
				<tr>
					<td><font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">Order Total:</font></td>
					<td>\$<input class="ztextbox" type="textbox" value="$order_total" size="6" name="order_total"> (Amount you Invoiced Us)</td>
				</tr>
				
				<tr>
					<td><font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">Shipping Method:</font></td>
					<td>
					<select name="ship_method">~;
	
	my @arr = ("","UPS", "USPS", "FEDX", "AIRB", "OTHR");			
	foreach my $method (@arr) {
		my $selected = '';
		if ($ship_method eq $method ) { $selected = "selected"; } 
		$html .= qq~<option value="$method" $selected>$method</option>\n~;
		}

	$html .= qq~</select>
					</td>			
				<tr>
					<td><font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">Tracking Number:</font></td>
					<td><input class="ztextbox" type="textbox" value="$ship_num" size="16" name="ship_num"></td>
				</tr>
			</table>
			<br>
			<input class="zsubmit" type="submit" name="submit" value=" Send Confirmation ">
		</form>~;

	push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>$html};

	my $USERNAME = $SITE->username();
	my $branding  = &ZTOOLKIT::def($SITE->webdb()->{'branding'},    0);
	if ($branding < 3) {
		push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>qq~
		<br>
		<br>
		<table border="0" cellpadding="1">
			<tr>
				<td bgcolor="$TH->{'disclaimer_background_color'}" background="">
				<font color="$TH->{'disclaimer_text_color'}" size="$TH->{'disclaimer_font_size'}" face="$TH->{'disclaimer_font_face'}">
				<b>ATTENTION SUPPLIERS:</b> e-Commerce supply chain automation provided by <a href="http://www.zoovy.com/track.cgi?P=$USERNAME">Zoovy.com</a>.
				Please visit our website to learn how we can revolutize your warehouse inventory management, 
				UPS/FedEx/USPS airbill generation, order acknowledgement/fullfillment and customer service operations 
				for far less than you'd pay single part time employee.
				</font>
				</td>
			</tr>
		</table>
		<br>
		<br>
		~, };
				
		}
	

	return();
	}



##
## 
##
sub search_handler {
	my ($iniref,$toxml,$SITE,$dref) = @_;
	my $error = $SITE::v->{'error'};
	if (not defined $error) { $error = ''; }

	my $title = "Search";
	if ($error eq 'nokeys') {
		$error = 'You must provide keywords to perform a search';
		$title = "Error";
		}
	elsif ($error eq 'noresults') {
		$error = 'Your search did not return any results';
		$title = "No results found";
		}

	$SITE->title( $title );
	if ($error) {
      my $TH = $SITE::CONFIG->{'%THEME'};
		push @SITE::PREBODY, { TYPE=>'OUTPUT',HTML=>qq~<font color="#$TH->{'alert_color'}"><div id="zsearch_error">$error</div></font><br>\n~ };
		}
	return();
	}


##
## requires the following cgi variables:
##		fullname
##		email
##		subscribe_check (enables per-newsletter checking)
##			subscribe_1, subscribe_2 .. can be Y,1,or "T" to enable
##
sub subscribe_handler {
	my ($iniref,$toxml,$SITE,$dref) = @_;

	require CUSTOMER;
	require ZTOOLKIT;
	
	my $email = (defined $SITE::v->{'email'}) ? $SITE::v->{'email'} : '' ;
	my $fullname = (defined $SITE::v->{'fullname'}) ? $SITE::v->{'fullname'} : '' ;
	my $errmessage = '';
	
	# print STDERR "[SUBSCRIBE TO NEWSLETTER] $SITE->username() $email $fullname\n";

	if ($SITE::v->{'email'} eq '') {
		$errmessage = 'Email address appears blank'; 
		}
	elsif (not &ZTOOLKIT::validate_email($email)) {
		# Not a valid email address?  No way!
		$errmessage = "Invalid email address";
		}
	elsif ($fullname !~ m/\w+\s+\w+/) {
		# No name?  How dare?
		$errmessage = "Please provide a first and last name";
		}

	if (not $errmessage) {
		# OK, check to see if we can create an account, if we can, $error and $errmessage are blank
		my $SUBSCRIPTIONS = 1;
		if ($SITE::v->{'subscribe_check'}) {
			## in subscriptions check mode, we're going to check to see which ones they opted in.
			$SUBSCRIPTIONS = 0;
			for my $x (1..16) {
				## looks for subscription_1 set to 1,T,Y or ON and will subscribe the customer.
				$SUBSCRIPTIONS += (&ZOOVY::is_true($SITE::v->{'subscribe_'.$x}))?(1 << ($x-1)):0;
				}
			}
			
		(undef, $errmessage) = &CUSTOMER::new_subscriber($SITE->username(), $SITE->prt(), $email, $fullname, undef, $ENV{'REMOTE_ADDR'}, 2, $SUBSCRIPTIONS);
		}

	if (not $errmessage) {
		# Mail them their brand-new password
		# &CUSTOMER::mail_password($SITE->username(), $email,2);

		my ($CID) = &CUSTOMER::resolve_customer_id($SITE->username(), $SITE->prt(), $email);
		my ($msgid) = $SITE::v->{'msgid'};
		if ((not defined $msgid) || ($msgid eq '')) {
			## default to the SUBSCRIBE message
			$msgid = 'ACCOUNT.SUBSCRIBE';
			}

		#require SITE::EMAILS;
		#my ($se) = SITE::EMAILS->new($SITE->username(),'*SITE'=>$SITE); #
		#$se->sendmail($msgid,CID=>$CID);
		#$se = undef;
		my ($BLAST) = BLAST->new($SITE->username(),int($SITE->prt()));
		my ($rcpt) = $BLAST->recipient('CUSTOMER',$CID);
		my ($msg) = $BLAST->msg($msgid);
		$BLAST->send($rcpt,$msg);

		}
	else {
		## uh-oh, error!
		$SITE::v->{lc($iniref->{'ID'}.'_err')} = $errmessage;
		}

	if ($iniref->{'AJAX'}) {
		## are we responding to an ajax request?
		return({err=>$errmessage});
		}
	else {
		## non-ajax (don't output anything)
		return('');	
		}
	}



##
## Popup is a universal popup handler it supports a variety of "popup" type functions
##	initially designed for tell a friend, it can also be used to display other custom flows.
##		long term this will also be used to handle other special types of popups, such as:
##			"notify me when back in stock"
##			"buy back - pricing and interest guide"
##			"size chart?"
##			"insert other crazy things jt can dream up here"
##			"date reminder"
##			"add a comment"
##
##		by default it uses the popup wrapper
##			use wrapper= to set a different wrapper.
##
##		it is passed which FLOW to load using the FL= parameter
##		currently supported FL= values are:
##			'pop_taf' - popup tell a friend.
##
##		it is passed the pagename on the PG parameter
##		currently supported PG values are:
##			'*taf' -- reserved for tell a friend
##
##		it behaves different based on the "VERB" it is passed.
##		currently supported VERB= are:
##			'INIT' => doesn't do shit! (just displays the flow)
##			'EXEC_TAF' => executes/validates tell a friend variables.
##				requires the following extra parameters:
##				PRODUCT= the product id
##				SENTFROM =  the name of the person sending the message
##				SENDER = the email of the person sending the message
##				RECIPIENT = the person receiving the email
##				TITLE = the title of the message
##				MESSAGE = a custom message
##

use strict; # No modules!
sub popup_handler {
	my ($iniref,$toxml,$SITE,$dref) = @_;

	if (ref($SITE) ne 'SITE') { warn Carp::confess("PAGE::HANDLER::popup_handler SREF parameter requires SITE object"); }
	
	my $vref       = $SITE::v;
	if ($iniref->{'AJAX'}) { $vref = $dref; }

	my $error   = '';
	my $cart    = {};			# if cart is undef, then we'll die.
	my $attribs = {};
	
	my $VERB = $vref->{'verb'};
	if ($VERB eq '') { $VERB = $iniref->{'VERB'}; }
	if ($VERB eq '') { $VERB = 'INIT'; }
	print STDERR "VERB: $VERB\n";
	
	##############################################################################
	## Tell A Friend - init
	##		doesn't do much, just sets SITE::v->{'title'} title.
	##
	if ($VERB eq 'INIT_TAF') {
	
		#if ($SITE->globalref()->{'cached_flags'} !~ /,XSELL,/) {
		#	$error = "this feature requires the XSELL bundle - which is not enabled on this account.";
		#	}
	
		my $PRODUCT = $vref->{'product'};
		my ($P) = PRODUCT->new($SITE->username(),$PRODUCT);
		if ($PRODUCT eq '') {
			$error = 'Mama-mia! PRODUCT= was not passed in on url - this will probably not work!<br>'; 
			}
		elsif (not defined $P) {
			$error = "PRODUCT $PRODUCT does not appear to have any information, perhaps it was deleted?<br>";
			}
		elsif (not defined $vref->{'title'}) {
			$vref->{'title'} = $P->fetch('zoovy:prod_name');
			}	

		}
	

	if ($VERB eq 'EXEC_TAF') {
		my ($attempts) = &SITE::log_email($SITE->username(),$ENV{'REMOTE_ADDR'});
		if ($attempts<25) {
			## don't actually send if we sent to many <25 emails today.
			#require SITE::EMAILS;
			#my ($se) = SITE::EMAILS->new($SITE->username(),'*SITE'=>$SITE);
			#$se->sendmail('PRODUCT.SHARE',PRODUCT=>$vref->{'product'},
			#	TO=>$vref->{'recipient'},
			#	VARS=>$vref
			#	);
			#$se = undef;
			my ($BLAST) = BLAST->new($SITE->username(),int($SITE->prt()));
			my ($rcpt) = $BLAST->recipient('EMAIL',$vref->{'recipient'});
			my ($msg) = $BLAST->msg('PRODUCT.SHARE',{'%VARS'=>$vref});
			$BLAST->send($rcpt,$msg);

			$SITE->layout($vref->{'success_fl'}); 
			}

		# print STDERR "POP EXIT: $SITE->layout()\n";
		}

#	if ($VERB eq 'EXEC_WISHLIST') {
#		if ($SITE::SREF->{'%GREF'}->{'cached_flags'} !~ /,XSELL,/) {
#			$error = "this feature requires the XSELL bundle - which is not enabled on this account.";
#			}
#	
#		my $PRODUCT = $vref->{'product'};
#	
#		if ($PRODUCT eq '') {
#			$error = 'Mama-mia! PRODUCT= was not passed in on url - this will probably not work!<br>'; 
#			}
#		elsif (scalar(keys %{$prodsref})==0) {
#			$error = "PRODUCT $PRODUCT does not appear to have any information, perhaps it was deleted?<br>";
#			}
#		elsif (not defined $vref->{'title'}) {
#			$vref->{'title'} = $prodsref->{'zoovy:prod_name'};
#			}	
#		}

	

	if ($VERB eq 'INIT_NOTIFY') {
		## the initialization page for the notify inventory
		}

	if ($VERB eq 'EXEC_NOTIFY') {
		my $SKU = $vref->{'sku'};
		my $email = $vref->{'email'};
		my $msgid = $vref->{'msgid'};
		
		delete $vref->{'email'};
		delete $vref->{'msgid'};
		delete $vref->{'sku'};

		require INVENTORY2::UTIL;
		($error) = &INVENTORY2::UTIL::request_notification( $SITE->username(), $SKU, 
			# NS=>$SITE->profile(),  
			PRT=>$SITE->prt(),
			EMAIL=>$email, 
			MSGID=>$msgid,
			VARS=>&ZTOOLKIT::buildparams($vref,1)
			);
		}

	
	##############################################################################
	## Output Page
	
	if ($error ne '') {
		my $TH = $SITE::CONFIG->{'%THEME'};
		push @SITE::PREBODY, { TYPE=>'OUTPUT',HTML=>qq~<font color="#$TH->{'alert_color'}">$error</font>\n~ };
		$SITE->layout('empty');
		}
	else {
		}

	return();
	}	

	

sub contact_handler {
	my ($iniref,undef,$SITE,$dref) = @_;
	
	my $validate   = defined($SITE::v->{'validate'})   ? $SITE::v->{'validate'}   : 0 ;
	my $customvars = defined($SITE::v->{'customvars'}) ? $SITE::v->{'customvars'} : '' ;
	my $message    = defined($SITE::v->{'message'})    ? $SITE::v->{'message'}    : 'Type your message here.' ;
	my $subject    = defined($SITE::v->{'subject'})    ? $SITE::v->{'subject'}    : '' ;
	my $order_id   = defined($SITE::v->{'order_id'})   ? $SITE::v->{'order_id'}   : '' ;
	
	my $from = $SITE::v->{'from'};
	if (not defined $from) { $from = ''; }
	# if (($from eq '') && &SITE::last_login()) { $from = &SITE::last_login(); }
	
	my $error = '';
	my $mode = 'form';
	if ($validate) {
		require ZTOOLKIT;
		if (($message eq '') && ($message eq 'Type your message here.')) {
			$error = $error . "Form field \"Message\" must be filled in.<br>\n";
			}
		if ($subject eq '') {
			$error = $error . "Form field \"Subject\" must be filled in.<br>\n";
			}
		if ($from eq '') {
			$error = $error . "Form field \"Email\" must be filled in.<br>\n";
			}
	
		# this is a last ditch catch
		if ($from ne '') { $message = "from: $from\n\n".$message; }
		if ($customvars ne '') {
			$message = '';
			$error = ''; # anything goes!
			my %required = ();	
			foreach my $k (split(',',$SITE::v->{'required'})) { $required{$k}++; }
			foreach my $k (split(',',$customvars)) {
				if ((defined $required{$k}) && ($SITE::v->{$k} eq '')) { $error = $error . "Form field $k is required.<br>\n"; }
				$message .= "$k:\t$SITE::v->{$k}\n\n";
				}
			}
	
		## if (not &ZTOOLKIT::validate_email_strict($from))
		if (not &ZTOOLKIT::validate_email($from)) {
			$error = $error . "Form field \"Email\" must be a valid internet email address.<br>\n";
			}
	
		if ($order_id ne '') {
			my ($O2) = CART2->new_from_oid($SITE->username(),$order_id);
			if (defined $O2) {
				my ($status,$created) = ($O2->pool(),$O2->in_get('our/order_ts'));
				if ($status eq '') {
					$error = $error . "Form field \"Regarding Order Number\" contains an invalid order number.<br>\n";
					}
				}
			}
	
		my $options = '';
		if ($order_id ne '') {
			$order_id =~ s/[^0-9\-]+//gs; 	# strip all non 0-9 and -'s
			$subject = "Order $order_id : $subject";
			$options = "ORDERID=$order_id";
			}

		# If we have no errors, send it off!
		if ($error eq '') {
			# require ZMAIL;
			# &ZMAIL::notify_customer($SITE->username(), $from, $subject, $message, "FEEDBACK", $options, 1, $SITE->profile());
			# $mode = 'confirmation';

			#require TODO;
         #my ($t) = TODO->new($SITE->username(),writeonly=>1);
			my ($link) = "mailto:$from";
			if ($order_id ne '') { $link = "order:$order_id"; }
         #$t->add(class=>"MSG",link=>$link,from=>$from,title=>$subject,detail=>$message);
			$mode = 'confirmation';
			&ZOOVY::add_enquiry($SITE->username(),"ENQUIRY.ORDER",
				order=>$order_id,link=>$link,from=>$from,title=>$subject,detail=>$message
				);
			}
		}
	
	my $phone = $SITE->nsref()->{'zoovy:support_phone'};
	my $customer_management = $SITE->webdb()->{'customer_management'};
	if ((not defined $customer_management) || ($customer_management eq '')) {
		$customer_management = 'DEFAULT';
		}
	
	my $contact_message = "Here you can send a message regarding this site or a particular order.  ";
	if (($customer_management ne 'DISABLED') && ($customer_management ne 'PASSIVE')) {
		my $customer_main_url = $SITE->URLENGINE()->get('customer_main_url');
		my $subscribe_url     = $SITE->URLENGINE()->get('subscribe_url');
		$contact_message .= qq[If you'd like to check the status of an order (or cancel one that hasn't been processed), please go to the\n];
		$contact_message .= qq[<a href="$customer_main_url" target="$SITE::target">customer account</a> page.  You can also\n];
		$contact_message .= qq[<a href="$subscribe_url">subscribe to our mailing list</a>. \n];
		}
	
	if (defined($phone) && $phone) {
		$contact_message .= "You can call us at $phone.";
		}

	##############################################################################
	## Output Page
	my $OUTPUT = '';
	if ($mode eq "confirmation") {
		$SITE->layout('empty'); 
		$SITE->sset('_FS','!');
		$OUTPUT .= $SITE->msgs()->get('page_contact_success',{'%CONTINUE_URL%'=>$SITE->URLENGINE()->get('continue_url')});
		}
	else {
		if ($error ne '') {
			my $TH = $SITE::CONFIG->{'%THEME'};
 			$OUTPUT .=  qq~<p align="left"><font color="#$TH->{'alert_color'}">$error</font></p>~;
			}
		}

	push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>$OUTPUT };
	return();
	}



	





sub paypal_handler {
	my ($iniref,undef,$SITE,$dref) = @_;
	require ZPAY::PAYPAL;
	require ZPAY::PAYPALEC;
	require ZTOOLKIT;

	my $FORCE_POST = 0;
	
	my $error = ''; ## Error message if something went wrong, blank if everything's fine.
	
	## Get the order id from the obfuscated passed parameter
	## (This url is generated by ZPAY::PAYPAL::payment_url) 
	my $id       = defined($SITE::v->{'id'})      ? $SITE::v->{'id'}      : '';
	my $email    = defined($SITE::v->{'email'})   ? $SITE::v->{'email'}   : '';
	my $order_id = defined($SITE::v->{'orderid'}) ? $SITE::v->{'orderid'} : '';
	my $mode 	 = defined($SITE::v->{'mode'})	 ? $SITE::v->{'mode'}	 : '';
	my $cart     = defined($SITE::v->{'cart'})    ? $SITE::v->{'cart'}    : 0;

	#print STDERR "PAYPAL MODE[$mode]\n";
	
	if ($mode eq 'express-return') {
		## http://brian.zoovy.com/paypal.cgis?mode=createOrder&token=EC-67336940AE771842M&PayerID=NAJ7P4ATNYGNN
		## use Data::Dumper; print STDERR Dumper($SITE::v);

		## note: paypal sends us PayerID but SITE::v is lower case so it's just payerid
		$SITE::CART2->{'IS_LEGACY_CHECKOUT'}++;
		my ($result) = &ZPAY::PAYPALEC::GetExpressCheckoutDetails($SITE::CART2,$SITE::v->{'token'},$SITE::v->{'payerid'});

		if ($result->{'ACK'} eq 'Success') {
			$SITE->pageid( '?REDIRECT/paypal express return' );
			$SITE::REDIRECT_URL = $SITE->URLENGINE()->get('checkout_url')."?PayerID=".$SITE::v->{'payerid'}."&token=".$SITE::v->{'token'}."&sender=PAYPALEC&addrwarn=".int($result->{'_ADDRESS_CHANGED'});
			return();
			}
		else {
			$mode = 'error';
			if ($result->{'L_LONGMESSAGE0'} eq '') {
				$result->{'L_LONGMESSAGE0'} = 'Reason not given by Paypal';
				}
			$error = 'Paypal Express Checkout Failure: '.$result->{'L_LONGMESSAGE0'};
			}
		}
	elsif (($mode eq 'cartec') || ($mode eq 'chkoutec')) {
		## express echeckout! (sent to us either by checkout or by the add to cart link)
		my ($result) = &ZPAY::PAYPALEC::SetExpressCheckout($SITE,$SITE->cart2(),$mode);
		if ($result->{'ERR'} ne '') {
			$error = "SetExpressCheckout Error: ".$result->{'ERR'};
			}
		elsif ($result->{'ACK'} eq 'Failure') {
		#$VAR1 = {
      #    'L_SEVERITYCODE0' => 'Error',
      #    'TIMESTAMP' => '2013-04-12T16:17:41Z',
      #    'BUILD' => '5691908',
      #    'L_LONGMESSAGE0' => 'The totals of the cart item amounts do not match order amounts.',
      #    'CORRELATIONID' => 'a019544cefc88',
      #    'L_ERRORCODE0' => '10413',
      #    'VERSION' => '58',
      #    'L_SHORTMESSAGE0' => 'Transaction refused because of an invalid argument. See additional error messages for details.',
      #    'ACK' => 'Failure'
      #  };
			$error = sprintf("SetExpressCheckout Error #%d: %s",$result->{'L_ERRORCODE0'},$result->{'L_LONGMESSAGE0'});
			print STDERR Dumper($result);
			}
		elsif ($result->{'URL'} ne '') {
			$SITE->pageid( '?REDIRECT/paypal express checkout' );
			$SITE::REDIRECT_URL = $result->{'URL'};
			print STDERR "REDIRECTING TO: $result->{'URL'}\n";
			return();
			}	
		else {
			$error = "Unspecified error occurred during Paypal SetExpressCheckout";
			print STDERR Dumper($result);
			}
		}	
	elsif ($email && $order_id) {
		## Get link by email address
		$mode = 'order';
		my ($O2) = CART2->new_from_oid($SITE->username(), $order_id);
		if (defined $O2) {
			$error = "Invalid order $order_id";
			}
		elsif (uc($O2->in_get('bill/email')) ne uc($email)) {		
			# if (uc(&ORDER::fetchorder_attrib($SITE->username(), $order_id, 'bill_email')) ne uc($email)) {
			$error = "Billing email address of $email does not match order $order_id";
			}

		if ($error) { $order_id = ''; }
		}
#	elsif ($id) {
#		## Get link by serialized order ID
#		#$order_id = ${&ZTOOLKIT::deser($id,1,1)};
#		## Change to MD5-hased URLs to make them not get truncated in emails
#		require ZPAY::PAYPAL_CART;
#		$order_id = &ZTOOLKIT::decodestring($id,$SITE::webdbref->{'paypal_email'}.$ZPAY::PAYPAL_CART::KEY);
#		$mode = 'order';
#		if (not defined $order_id)	{
#			$order_id = '';
#			$error = "URL Error, are you sure the link you clicked was the entire URL?";
#			}
#		elsif ($order_id !~ m/^[0-9\-]+$/)	{
#			## We'll have to modify this if we ever have non-numeric order IDs 
#			$error = "Order ID $order_id appears to be invalid.  Administrator has been notified.";
#			} 
#		}
#	elsif ($cart) {
#		$mode = 'cart';
#		}
	else {
		$error = 'Required parameter not passed.';
		}


	if ($error ne '') {
		$mode = 'error';
		}
	
#	## If we have a proper order ID, fetch the paypal get/post vars for it.	
#	my ($geturl,$posturl,$formcontents);
#	if ($mode eq 'error') {}
#	elsif ($mode eq 'redir') {}
#	elsif ($mode eq 'order') {
#		require ZPAY::PAYPAL_CART;
#		($geturl,$posturl,$formcontents) = &ZPAY::PAYPAL_CART::payment_form($SITE->username(),$order_id);
#		unless ($geturl && $posturl && $formcontents) {
#			$error = "Invalid order id or unable to load merchant information for order $order_id to pass to paypal checkout.";
#			}
#		}
#	elsif ($mode eq 'cart') {
#		($geturl,$posturl,$formcontents) = &ZPAY::PAYPAL::cart_checkout_form($SITE->username());
#		unless ($geturl && $posturl && $formcontents) {
#			$error = "Unable to load cart information to pass to paypal checkout.";
#			}
#		}
	
#	## If we have a GET url short enough, perform a redirect to it.
#	if ($mode eq 'error') {}
#	elsif ($mode eq 'redir') {}
#	elsif ((not $error) && (not $FORCE_POST) && (length($geturl) < 1024)) {
#		$SITE::PG = '?REDIRECT/paypal passed via get';
#		$SITE::REDIRECT_URL = $geturl;
#		return();
#		}
	
#	##############################################################################
#	## Set Up FLOW Variables
	
	if ($error) {
		## If we had an error make a pretty page
		my $PRT = $SITE->prt();
		my $SDOMAIN = $SITE->sdomain();
		push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>"<p>Internal Error: $error</p>
			<b>Please include this diagnostic information when reporting any issue:</b>
			<ul>
			<li> DATE:".&ZTOOLKIT::pretty_date(time(),2)."
			<li> DOMAIN:$SDOMAIN
			<li> PRT:$PRT
			<li> REMOTE_IP:$ENV{'REMOTE_ADDR'}
			<li> CART_ID:".((defined $SITE::CART2->cartid())?$SITE::CART2->cartid():'not-set')."
			<li> SERVER:".&ZOOVY::servername()."
			</ul>",
			 };
		}
#	else {
#		## If we're successfully sending them off to paypal, output a quick and dirty form.
#		push @SITE::PREBODY, { TYPE=>'OUTPUT', HTML=>&ZTOOLKIT::untab(qq~
#
#					<!-- NOTE: paypal may have issues on carts over 25 items -->
#					<form name="paypalfrm" action="$posturl" method="POST">
#						$formcontents
#						Loaded paypal parameters successfully<br>
#						<input type="submit" value="Continue to PayPal.com...">
#					</form>
#					<script language="JavaScript">
#					<!--
#					document.paypalfrm.submit();
#					//-->
#					</script>
#		~), };
#		}
	return();
	}






##
##
##
#sub kill_cookies_handler {
#	my ($iniref,undef,$SITE,$dref) = @_;
#	my @cookies = ();
#	my %oldvalues = ();
#	foreach (keys %{$SITE::v}) {
#		$oldvalues{$_} = $SITE::v->{$_};
#		push @cookies, { 'name'=>$_, 'destroy'=>1 };
#		}
#	# Overide the cookies hash with our new, improved, cookie-destroying array of cookies.
#	# $SITE::cookies = @cookies;
#	
#	##############################################################################
#	## Set Up FLOW Variables
#	
#	$SITE->title( "Kill Cookies" );
#
#	my $OUTPUT = '';
#	$OUTPUT .= qq~<p>The following Zoovy cookies removed:</p>~;
#	foreach (keys %oldvalues) {
#		$OUTPUT .= "$_ : '$oldvalues{$_}'<br>\n";
#		}
#	
#	if ($SITE::CART2->empty('reason'=>'kill_cookies','scope'=>'all')) {
#		$OUTPUT .= qq~<p>Cart file deleted.</p>~;
#		}
#	
#	push @SITE::PREBODY, {'TYPE'=>'OUTPUT','HTML'=>$OUTPUT};
#	return();
#	}	
#


##
##
##
#sub no_cookies_handler {
#	my ($iniref,undef,$SITE,$dref) = @_;
#	my $TH = $SITE::CONFIG->{'%THEME'};
# 	my $url  = defined($SITE::v->{'url'})  ? $SITE::v->{'url'}  : '';
#	my $cgiurl = CGI->escape($url);
#	
#	my $type = defined($SITE::v->{'type'}) ? $SITE::v->{'type'} : 'site';
#	my $cgitype = CGI->escape($type);
#	
#	my $mode = defined($SITE::v->{'mode'}) ? $SITE::v->{'mode'} : '';
#	my $no_cookies_url = $SITE->URLENGINE()->get('no_cookies_url');
#	
#	##############################################################################
#	## Set Up FLOW Variables
#	
#	$SITE->title( "Browser Error" );
#	if ($mode eq 'more') { $SITE->title( "More Information on Cookies" ); }
#	elsif ($mode eq 'how') { $SITE->title( "How Do I Turn On Cookies?" ); }
#	
#	my $OUTPUT = '';	
#	
#	if ($mode eq 'more')
#	{
#		$OUTPUT .= qq~
#			
#			<p>To be sure that everything is working properly, make sure to go back to where you first
#			started and perform the action again (for instance, if you were adding to the Shopping
#			Cart, go back to where you found the product you'd like to add, and then add it to the
#			cart again).  If there is a "try again" link below, you can usually use that to do this.
#			Turning the cookies on will not mean that the item is now in your cart, the item must be
#			added to the cart <i>while cookies are turned on</i>.</p>
#			
#			<p>Also, You will need to leave cookies on for the entire duration of your visit for this
#			site to function properly.</p>
#	
#			<p>If you have your browser set to prompt for approval before cookies are set, you will
#			need to allow all the cookies that this site sends (if you don't approve the cookies,
#			then it's the same as having cookies turned off).</p>
#			
#			<p>Misconfigured proxy servers can also cause problems with cookies.  If you have the
#			option to bypass your proxy, you should try this.  Some ISPs, AOL and Earthlink namely
#			use a "transparent proxy", which can cache pages that weren't intended to be cached,
#			which can show up a cookies error since the cookie won't be set if the page isn't
#			actually loaded.  Try holding the shift key down while hitting the "Refresh" or
#			"Reload" button in your browser from the page before you got this error.</p>
#	
#	<!--
#			<p>If you've tried all these steps, and you are sure you've enabled cookies
#			(see the "How do I turn on cookies..." link below) and you are still having this
#			problem, you can send an email to <a href="mailto:support\@zoovy.com">support\@zoovy.com</a>
#			and we will attempt to help.  Keep in mind that cookies problems are usually web browser
#			or ISP related, which is unfortunately beyond our control, but we'll do our best.
#			Make sure to include your browser name and version, ISP, and the URL you were
#			attempting to reach, and the time when the error occurred.</p>
#	-->
#			
#		~;
#	}
#	elsif ($mode eq 'how')
#	{
#		$OUTPUT .= qq~
#	
#			<p>Instructions on how to enable cookies:</p>
#	
#			<p><b>Internet Explorer Versions 6.x and Later</b></p>
#	
#			<ol>
#			<li>Start Internet Explorer.
#			<li>On the "Tools" menu, select "Internet Options".
#			<li>Select the "Privacy" tab.
##			<li>Click the "Advanced..." button.
#			<li>Check the "Override automatic cookie handling" checkbox.
#			<li>Select "Accept" for First-party Cookies. <i>(This enables cookies to be sent to a single
#			server)</i>
#			<li>Select "Accept" for Third-party Cookies. <i>(This enables cookies to be visible from more
#			than one server, this allows us to transfer your shopping cart to the secure server for
#			checkout)</i>
#			<li>Check "Always allow session cookies". <i>(These cookies are not stored on hard drive, and
#			go away when you close your browser)</i>
#			</ol>
#	
#			<p><b>Internet Explorer Version 5.x</b></p>
#	
#			<ol>
#			<li>Start Internet Explorer.
#			<li>On the "Tools" menu, select "Internet Options".
#			<li>Select the "Security" tab.
#			<li>In the "Select a web content zone..." section, click the "Internet" icon.
#			<li>In the "Security level for this zone" section, click the "Custom Level..." button.
#			<li>Scroll down to the "Cookies" section (about a quarter of the way down)
#			<li>Select "Enable" under "Allow cookies that are stored on your computer". <i>(This enables cookies to be sent)</i>
#			<li>Select "Enable" under "Allow per-session cookies". <i>(These cookies are not stored on hard drive, and
#			go away when you close your browser)</i>
#			</ol>
#	
#			<p><b>Internet Explorer Version Before 5.x</b></p>
#	
#			<ol>
#			<li>Start Internet Explorer.
#			<li>On the "View" menu, select "Internet Options".
#			<li>Select the "Advanced" tab.
#			<li>Scroll down to the "Security" section.
#			<li>Select "Always accept cookies" under "Cookues". <i>(This enables cookies to be sent)</i>
#			</ol>
#			
#			<p><b>Internet Explorer for Macintosh Versions 4.x and Later</b></p>
#	
#			<ol>
#			<li>Start Internet Explorer.
#			<li>On the "Edit" menu, select "Preferences".
#			<li>Scroll down to the "Receiving Files" section.
#			<li>Click "Cookies".
#			<li>Select "Never Ask" from the "When Receiving Cookies" drop-down menu.
#			</ol>
#			
#			<p><b>Netscape Versions 6.x and Later<b></p>
#			
#			<ol>
#			<li>Start Netscape.
#			<li>On the "Edit" menu, select "Preferences".
#			<li>Expand the "Privacy &amp; Security" section by clicking its triangle.
#			<li>Click "Cookies".
#			<li>Select "Enable all cookies".
#			</ol>
#	
#			<p><b>Netscape Versions Before 6.x<b></p>
#			
#			<ol>
#			<li>Start Netscape.
#			<li>On the "Edit" menu, select "Preferences".
#			<li>Click "Advanced".
#			<li>Select "Accept All Cookies" in the "Cookies" section.
#			</ol>
#			
#			<p><b>AOL Version 5.x</b></p>
#			
#			<ol>
##			<li>Start AOL.
#			<li>From the "My AOL" menu, select "Preferences".
#			<li>In the preferences window, click "Internet Properties" (or "WWW").
#			<li>Select the "Security" tab.
#			<li>In the "Security level for this zone" section, click the "Custom Level..." button.
#			<li>Scroll down to the "Cookies" section (about a quarter of the way down)
#			<li>Select "Enable" under "Allow cookies that are stored on your computer". <i>(This enables cookies to be sent)</i>
#			<li>Select "Enable" under "Allow per-session cookies". <i>(These cookies are not stored on hard drive, and
#			go away when you close your browser)</i>
#			</ol>
#			
#			<p><b>AOL for Macintosh Version 5.x and Later</b></p>
#			
#			<ol>
#			<li>Start AOL.
#			<li>From the "My AOL" menu, select "Preferences".
#			<li>In the preferences window, click "WWW".
#			<li>Select "Advanced Settings".
#			<li>Scroll down to the "Receiving Files" section.
#			<li>Click "Cookies".
#			<li>Select "Never Ask" from the "When Receiving Cookies" drop-down menu.
#			</ol>
#			
#			<p><b>Opera 5.x</b></p>
#			
#			<ol>
#			<li>Start Opera.
#			<li>From the "File" menu, select "Preferences".
#			<li>Click "Privacy"
#			<li>Under the "Cookies" section, check the "Enable cookies" checkbox
#			<li>Select "Automatically accept all cookies" from the first drop-down menu.
#			<li>Select "Accept from all servers" from the second drop-down menu.
#			</ol>
#			
#		~;
#	}
#	else
#	{
#		my $t = time();
#		$OUTPUT .= qq~
#			<p>Your computer must have the date, daylight savings settings, time
#			and time zone set correctly to use this $type. Your browser must also
#			have cookies enabled to use this $type.</p>
#			
#			<script language="Javascript">
#			<!--
#			var secs = ($t - (Date.parse(new Date())/1000));
#			var diff = 'slower'; if (secs <= 0) { secs = (0 - secs); diff = 'faster'; }
#			var mins  = (secs >= 60)  ? Math.floor(secs  / 60) : 0 ; secs  = secs  - (mins  * 60);
#			var hours = (mins >= 60)  ? Math.floor(mins  / 60) : 0 ; mins  = mins  - (hours * 60);
#			var days  = (hours >= 24) ? Math.floor(hours / 24) : 0 ; hours = hours - (days  * 24);
#			if ((days > 0) || (hours > 0) || (mins > 10))
#			{
#				document.write('<p><font color="#$TH->{'alert_color'}" size="+1"><b>');
#				document.write("Your computer's time appears to be ");
#				if (days > 0) document.write(days + ((days==1)?' day, ':' days, '));
#				if (hours > 0) document.write(hours + ((hours==1)?' hour, ':' hours, '));
#				if (mins > 0) document.write(mins + ((mins==1)?' minute ':' minutes ') + ' and ');
#				document.write(secs + ((secs==1)?' second ':' seconds ') + diff + ' than our web server.  ');
#				document.write('This $type and many others will not work unless you have the correct date, time and time zone.</b></font>  ');
#				document.write('On most Windows and Macintosh computers you can fix this by going to the Date/Time Control Panel.  ');
#				document.write('If the date and time are correct but you still get this message, please make sure your time zone and daylight savings settings are also correct.</p>');
#			}
#			//-->
#			</script>
#			
#			<noscript>
#			<p>Additionally, certain features of this site are unavailable if you have JavaScript
#			disabled.  We cannot validate that your time is set correclty if JavaScript is
#			disabled.</p>
#			</noscript>
#			
#			<p>If your time is correct and you have received this message, you need to
#			enable cookies on your browser.  You can find out more about cookies at
#			<a href="http://whatis.techtarget.com/definitionsSearchResults/?query=cookie">WhatIs?</a>,
#			they are a neccessary element to browsing most modern web sites (including this one).</p>
#		~;
#	}
#	
#	if ($mode ne 'how')
#	{
#		$OUTPUT .= qq~<p><a href="$no_cookies_url?mode=how&url=$cgiurl&type=$cgitype" target="$SITE::target">How do I turn on cookies in my broswer?</a></p>~;
#	}
#	if ($url ne '')
#	{
#		$OUTPUT .= qq~<p><a href="$url" target="$SITE::target">I've turned cookies on, try the $type again.</a></p>~;
#	}
#	if ($mode ne 'more')
#	{
#		$OUTPUT .= qq~<p><a href="$no_cookies_url?mode=more&url=$cgiurl&type=$cgitype" target="$SITE::target">I've set my cookies, but it still isn't working.</a></p>~;
#	}
#	
#	$OUTPUT .= qq~<br><br>~;
#	return($OUTPUT);	
#	}
#

##
##
##
sub about_zoovy_handler {
	my ($iniref,undef,$SITE,$dref) = @_;

	my $company_name = $SITE->nsref()->{'zoovy:company_name'};
	if ((not defined $company_name) || ($company_name eq '')) {
		$company_name = &ZTOOLKIT::pretty($SITE->username());
		}

	my $USERNAME = $SITE->username();
	$SITE->title( "Learn more about Zoovy.com" );

	my $TH = $SITE::CONFIG->{'%THEME'};
 	my $OUTPUT = '';

$OUTPUT .= qq~
<center><table width=500><tr><td>
<font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">
<h2>
<font color="#$TH->{'table_head_text_color'}" face="$TH->{'table_head_font_face'}">
Thank you for your interest in Zoovy e-Commerce Services<br>
</h2>
</font>
If you are interested in establishing a new website for your online business please click here to access the 
<a href="http://www.zoovy.com/track.cgi?SRC=USR&OPERID=$USERNAME">Zoovy.com</a> homepage. <br>
<br>
If you are a customer who needs to check order status, use your email address and password to login:<br>
~;

my $AOLLOGIN = '';
my $customer_management = defined($SITE->webdb()->{'customer_management'}) ? $SITE->webdb()->{'customer_management'} : 'DEFAULT';

my $forgot_url = $SITE->URLENGINE()->get('forgot_url');
my $login_url = $SITE->URLENGINE()->get('login_url');
$OUTPUT .= qq~
	<br>
	If you have forgotten your password, please check the <a href="$forgot_url" target="$SITE::target">reminder page</a>.<br>
	<br>
	<table border="0" cellpadding="3" cellspacing="0">
		<form action="$login_url" method="post" target="$SITE::target">
		<input type="hidden" name="mode" value="check">
		<input type="hidden" name="url" value="">
		<tr>
			<td align="right" valign="top">
				<font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">
				Login: 
				</font>
			</td>
			<td valign="top">
				<font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">
				<input type="textbox" class="ztextbox" length="20" maxlength="60" name="login" value=""><br><font size="-1"><i>(this is usually your email address)</i></font>
				</font>
			</td>
		</tr>
		<tr>
			<td align="right">
				<font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">
				Password: 
				</font>
			</td>
			<td>
				<font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">
				<input type="password" class="ztextbox" length="20" maxlength="50" name="password" value=""><br>
				</font>
			</td>
		</tr>	
		<tr>
			<td align="right">&nbsp;</td>
			<td>
				<font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">
				<input type="submit" class="zsubmit" name="submit" value="Login"><br>
				</font>
			</td>
		</tr>
		</form>

		$AOLLOGIN

	</table>
	</font>
	<br>
	<br>
~;

$OUTPUT .= qq~
<font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">
If you are unable to login, or need to contact the merchant by mail/phone please use the information below:<br></font>~;

	my $inforef = $SITE->nsref();
	my $html = '';
	$html .= "<center><table cellspacing=3 cellpadding=4 border=1><tr><td>";
	$html .= qq~<font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">~;
	if ($inforef->{'zoovy:support_phone'} ne '') { $html .= "By Phone: $inforef->{'zoovy:support_phone'}<br>\n"; }
	
	$html .= "Mailing Address:<br>";
	$html .= "&nbsp;&nbsp;&nbsp; $inforef->{'zoovy:company_name'}<br>";
	$html .= "&nbsp;&nbsp;&nbsp; $inforef->{'zoovy:address1'}<br>";
	if ($inforef->{'zoovy:address2'} ne '') { $html .= "&nbsp;&nbsp;&nbsp; $inforef->{'zoovy:address2'}<br>"; }
	$html .= "&nbsp;&nbsp;&nbsp; $inforef->{'zoovy:city'}, $inforef->{'zoovy:state'}. $inforef->{'zoovy:zip'}<br>";
	if ($inforef->{'zoovy:support_email'} eq '') { $inforef->{'zoovy:email'} = ''; }
	if ($inforef->{'zoovy:support_email'} ne '') { $html .= "Email: <a href='/contact_us.pl'>$inforef->{'zoovy:support_email'}</a>"; }

	$html .= "<br><i>If any of the information above appears invalid please notify abuse\@zoovy.com immediately.</i><br>";
	$html .= "</font></td></tr></table></center><br>";

$OUTPUT .= qq~
$html
<font color="#$TH->{'content_text_color'}" face="$TH->{'content_font_face'}"  size="$TH->{'content_font_size'}">
<br>
Please note: Zoovy is a software and website hosting company. 
We are not equipped to offer assistance with orders or provide any form of customer service for this merchant.
To get questions answered please <a href="/contact_us.pl">click here to contact the merchant directly</a>.
<br>
<br>
</font>
</td></tr></table>
</center>
~;
	return($OUTPUT);
}



1;