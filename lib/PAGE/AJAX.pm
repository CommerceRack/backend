package PAGE::AJAX;

use URI::Escape::XS qw (uri_escape);
use Data::Dumper;
use strict;



## 
## this library is ONLY supposed to be called from within 
##
##
## v=1 requests
##		request: m=ping
##			response: m=pong&t=funny message + timestamp
##		request: m=renderProduct		pid=[productid]&fl=[requestedflow]&div=[div to update]
##			response: m=updateDiv&div=[divid]&html=[html of product page]
##		
##
sub handle {
	my ($SITE,$URI) = @_;

	my $SUB = undef;
	my $METHOD = &SITE::untaint($SITE::v_mixed->{'m'});
	## certain methods e.g. AutoComplete must pass all variables on the URI e.g. /ajax/AutoComplete/CATALOG=DEFAULT
	if ((not defined $METHOD) && ($URI =~ /^\/ajax\/([A-Za-z]+)/)) { $METHOD = $1; }

	my $dref = undef;

	if (($SITE::v_mixed->{'data'} eq '') && (index($SUB,'?')>=0)) {
		## yeah, you can pass a "data" argument with psub parameters in it. 
		$dref = &ZTOOLKIT::urlparams($SUB);	
		$SUB = substr($SUB,0,index($SUB,'?'));
		}
	elsif (substr($SITE::v_mixed->{'data'},0,1) eq '?') {
		## hey, does the post start with a ? if so.. hmm.. it might be a multipart.
		$dref = &ZTOOLKIT::urlparams($SITE::v_mixed->{'data'});
		}
	else {
		## hey, this is the most common, a single post with multiple key/values (in which case it was interprted by site::v) 
		foreach my $k (keys %{$SITE::v_mixed}) { $dref->{$k} = $SITE::v_mixed->{$k}; }
		}
	## Lastly, any parameters passed on the URI override.
	## 	e.g. CATALOG=DEFAULT


	foreach my $kv (split(/\//,$URI)) {
		next unless (index($kv,'=')>0);
		my ($k,$v) = split(/\=/,$kv);
		$dref->{$k} = $v;
		}

	## convert dref variables to lowercase
	## 	we might want untaint these at some point too. (feeling chicken now)
	foreach my $k (keys %{$dref}) {
		next if ($k eq lc($k));
		$dref->{lc($k)} = $dref->{$k};
		# delete $dref->{$k}; 	## ELIMINATE THE MIXED CASE VARIABLES!
		}	

	$dref->{'_URI'} = $URI;		# keep a copy of this in case somebody down the foodchain wants it later.

	# print STDERR 'DREF: '.Dumper($METHOD,$dref)."\n";

	##
	## SANITY: at this point the following variables have been initialized:
	##		$METHOD (the method being requested)
	##		$dref = reference to key/values from data.
	##

	my $out = '';	
	my %METHODS = (
		'AddToCart' => \&PAGE::AJAX::AddToCart,
		'renderProduct' => \&PAGE::AJAX::renderProduct,
		'RenderElement' => \&PAGE::AJAX::RenderElement,
		'AutoComplete' => \&PAGE::AJAX::AutoComplete,
		'get' => \&PAGE::AJAX::get,
		'getScalar' => \&PAGE::AJAX::get,
		'set' => \&PAGE::AJAX::set,
		'ping'=>\&PAGE::AJAX::ping,
		'searchCatalog' => \&PAGE::AJAX::AutoComplete,
		'addReview'=>\&PAGE::AJAX::addReview,
		'addNotify'=>\&PAGE::AJAX::addNotify,
		'sendMsg'=>\&PAGE::AJAX::sendMsg,
		'customerLookup'=>\&PAGE::AJAX::customerLookup,
		'customerEmail'=>\&PAGE::AJAX::customerEmail,
		'newsletterSubscribe'=>\&PAGE::AJAX::newsletterSubscribe,
		'swog97vinLookup'=>\&PAGE::AJAX::swog97vinLookup,
		);


	$dref->{'_METHOD'} = $METHOD;
	if (not defined $METHODS{$METHOD}) {
		$out = "error=Unknown method: ".&ZOOVY::incode($METHOD);
		}
	else {
		($out) = $METHODS{$METHOD}->($SITE,$dref);
		}
	# print STDERR "RETURNING: $out\n";

	if ($SITE::OVERRIDES{'debug.ajax'}) {
		my $debugfile = &ZOOVY::resolve_userpath($SITE->username())."/ajax-debug-log.txt";
		open Fd, ">>$debugfile";
		print Fd "----[ ".&ZTOOLKIT::pretty_date(time(),2)." ]----\n";
		print Fd "INFO: prt=".$SITE->prt()." sdomain=".$SITE->sdomain()."\n";
		print Fd "CALL: $METHOD\n";
		print Fd "IN  : $URI?".&ZTOOLKIT::buildparams($dref)."\n";
		print Fd "OUT : ".$out."\n";
		print Fd "\n";
		close Fd;
		chown $ZOOVY::EUID,$ZOOVY::EGID, $debugfile;
		}

	return($out);
	}


##
##
## pass cid, or email
##		- 
##
#sub customerEmail {
#	my ($SITE,$dref) = @_;
#	my %result = ();
#
#	my $cid = int($dref->{'cid'});
#	my ($msgid) = sprintf("%s",$SITE::v->{'msgid'});
#
#	my $err = undef;
#
#	if ($msgid eq '') {
#		$err = "no msgid parameter passed";
#		}
#
#	if ((not defined $err) && ($cid==0)) {
#		my $email = $SITE::v->{'email'};
#		($cid) = &CUSTOMER::resolve_customer_id($SITE->username(), $SITE->prt(),  $email);
#		}
#
#	if (defined $err) {
#		## shit already went bad.
#		}
#	elsif ($cid<=0) {
#		$err = "could not resolve customer id";
#		}
#	else {
#	#	require SITE::EMAILS;
#	#	my ($se) = SITE::EMAILS->new($SITE->username(),'*SITE'=>$SITE); # ,NS=>$SITE->{'_NS'},PRT=>$SITE->prt());
#	#	($err) = $se->sendmail($msgid,CID=>$cid);
#	#	$se = undef;
#		my ($BLAST) = BLAST->new($SITE->username(), $SITE->prt());
#		my ($rcpt) = $BLAST->recipient('EMAIL',$email);
#		if ($msgid eq 'PTELLAF') { $msgid = 'PRODUCT.SHARE'; }
#		my ($msg) = $BLAST->msg($msgid);
#		
#		}
#	
#	return("?m=customerEmailResponse&cid=$cid&err=$err");
#	}


##
## Lookups a Customer ID based on email, returns customer #
##		email=
##
sub customerLookup {
	my ($SITE,$dref) = @_;
	my %result = ();
	my ($cid) = CUSTOMER::resolve_customer_id($SITE->username(),$SITE->prt(),$dref->{'email'});
	print STDERR "CID: $cid EMAIL: $dref->{'email'}\n";
	return("?m=customerLookupResponse&cid=".int($cid));
	}

##
## Adds a user to a newsletter
##		takes same paramters as subscribe_handler
##		required: email, fullname
##		optional: subscribe_check + subscribe_[1..16]
##		
sub newsletterSubscribe {
	my ($SITE,$dref) = @_;

	$SITE::v = $dref;
	my ($result) = &PAGE::HANDLER::subscribe_handler({'AJAX'=>1},undef,$SITE);	
	return("?m=newsletterSubscribeResponse&".&PAGE::AJAX::serialize_hashref($result));
	}

     






## pass in a dref vin=value
sub vinLookup {
	my ($SITE,$dref) = @_;
	
	my $vin = $dref->{'vin'};
	my %lettervalue = ("A", 1, "B", 2, "C", 3, "D", 4,"E", 5, "F", 6, "G", 7, "H", 8, "J", 1, "K", 2, "L", 3, "M", 4,
 		"N", 5, "P", 7, "R", 9, "S", 2,"T", 3, "U", 4, "V", 5, "W", 6,"X", 7, "Y", 8, "Z", 9, "1", 1, "2", 2, "3", 
		3, "4", 4, "5", 5, "6", 6, "7", 7, "8", 8, "9", 9, "0", 0);

	my %models = ( 
		'JA'=>'IS|Isuzu','JF'=>'SU|Fuji Heavy Industries (Subaru)','JH'=>'HO|Honda', #'JK'=>'Kawasaki (motorcycles)',
		'JM'=>'MZ|Mazda','JN'=>'NI|Nissan','JS'=>'SZSuzuki','JT'=>'TY|Toyota','KL'=>'DW|Daewoo',
		'KMH'=>'HY|Hyundai','KN'=>'KI|Kia','SAL'=>'LD|Land Rover','SAJ'=>'JA|Jaguar','SCC'=>'LO|Lotus Cars',
		'TRU'=>'AU|Audi','VF1'=>'RE|Renault','VF3'=>'PE|Peugeot','VF7'=>'CI|Citroën', #'VSS'=>'SEAT',
		'WAU'=>'AU|Audi','WBA'=>'BM|BMW','WBS'=>'BMW M','WDB'=>'MB|Mercedes-Benz','WMW'=>'MI|MINI',
		'WP0'=>'PO|Porsche','W0L'=>'OP|Opel','WVW'=>'VW|Volkswagen','WV1'=>'VW|Volkswagen Commercial Vehicles','WV2'=>'VW|Volkswagen Bus/Van',
		'YK1'=>'SB|Saab','YS3'=>'SB|Saab','YV1'=>'VO|Volvo Cars','YV2'=>'VO|Volvo Trucks','ZDF'=>'FR|Ferrari Dino',
		'ZFA'=>'FI|Fiat','ZFF'=>'FR|Ferrari','1FB'=>'FD|Ford Motor Company','1FC'=>'FD|Ford Motor Company','1FD'=>'FD|Ford Motor Company','1FM'=>'FD|Ford Motor Company',
		#'1FU'=>'Freightliner', '1FV'=>'Freightliner', '1F9'=>'FWD Corp.',
		'1G'=>'GM|General Motors','1GC'=>'CV|Chevrolet','1GM'=>'PT|Pontiac','1H'=>'HO|Honda USA','1L'=>'LI|Lincoln','1ME'=>'MY|Mercury',
		#'1M1'=>'Mack Truck', '1M2'=>'Mack Truck', '1M3'=>'Mack Truck', '1M4'=>'Mack Truck',
		'1N'=>'NI|Nissan USA','1VW'=>'VW|Volkswagen USA','1YV'=>'MZ|Mazda USA','2FB'=>'FD|Ford Motor Company Canada',
		'2FC'=>'FD|Ford Motor Company Canada','2FM'=>'FD|Ford Motor Company Canada','2FT'=>'FD|Ford Motor Company Canada',
		# '2FU'=>'Freightliner', '2FV'=>'Freightliner',
		'2M'=>'MY|Mercury','2G'=>'GM|General Motors Canada','2G1'=>'CV|Chevrolet Canada','2G2'=>'PO|Pontiac Canada',
		'2HM'=>'HY|Hyundai Canada','2T'=>'TY|Toyota Canada',# '2WK'=>'Western Star', '2WL'=>'Western Star', '2WM'=>'Western Star',
		'3FE'=>'FD|Ford Motor Company Mexico','3G'=>'GM|General Motors Mexico','3VW'=>'VW|Volkswagen Mexico','9BW'=>'VW|Volkswagen Brazil','4F'=>'MZ|Mazda USA',
		'4M'=>'MY|Mercury','4S'=>'SU|Subaru-Isuzu Automotive','4US'=>'BM|BMW USA',#'4UZ'=>'Frt-Thomas Bus',
		'4V1'=>'VO|Volvo','4V2'=>'VO|Volvo','4V3'=>'VO|Volvo','4V4'=>'VO|Volvo','4V5'=>'VO|Volvo','4V6'=>'VO|Volvo',
		'4VL'=>'VO|Volvo','4VM'=>'VO|Volvo','4VZ'=>'VO|Volvo','5L'=>'LI|Lincoln','6F'=>'FD|Ford Motor Company Australia',
		'6H'=>'GM|General Motors-Holden','6MM'=>'MI|Mitsubishi Motors Australia','6T1'=>'TY|Toyota Australia',
		'LTV'=>'TY|Toyota Tian Jin','LVS'=>'FD|Ford Chang An',#'LZM'=>'MAN China',
		'LZU'=>'IS|Isuzu Guangzhou');

	my %vinyears = (
		'A'=>'1980','L'=>'1990','Y'=>'2000',
		'B'=>'1981','M'=>'1991','1'=>'2001',
		'C'=>'1982','N'=>'1992','2'=>'2002',
		'D'=>'1983','P'=>'1993','3'=>'2003',
		'E'=>'1984','R'=>'1994','4'=>'2004',
		'F'=>'1985','S'=>'1995','5'=>'2005',
		'G'=>'1986','T'=>'1996','6'=>'2006',
		'H'=>'1987','V'=>'1997','7'=>'2007',
		'J'=>'1988','W'=>'1998','8'=>'2008',
		'K'=>'1989','X'=>'1999','9'=>'2009',
		);

	my @positionweight = (8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2);
	my @vinchar = split(//, $vin);
	my $total = 0;
	for (my $ctr = 0; $ctr < 17; $ctr++) {
		$total += $lettervalue{$vinchar[$ctr]} * $positionweight[$ctr];
		}
	my $validates = (($total % 11) == 10) ? "X" : ($total % 11);

	my %result = ();
	if ($validates) {
		my $model = $models{substr($vin,0,2)};	# try two digit
		if (not defined $model) { $model = $models{substr($vin,0,3)}; }
		## model should be XX|Vendor -- where XX is the swog 98 (manufacturers code)
		if (length($model)>0) {
			($result{'swog98'},$result{'factory'}) = split(/\|/,$model);
			$result{'year'} = $vinyears{ substr($vin,10,1) };		# pos 9 is the year digit (see %vinyears)
			if ($result{'swog98'}=='FD') {
				## Ford
				
				}

			}	
		}

	return(\%result);
	}

##
## sendMsg
##
##  from (email address)
##	 subject
##	 body
##	 
##
sub sendMsg {
	my ($SITE,$dref) = @_;

	my %response = ();
	## &ZMAIL::notify_customer($SITE->username(),$dref->{'from'},$dref->{'subject'},$dref->{'message'},undef,undef,1);

	#warn "AJAX SENDMSG\n";
	#require TODO;
	#my ($t) = TODO->new($SITE->username(),writeonly=>1);
	#$t->add(class=>"MSG",);
	&ZOOVY::add_enquiry($SITE->username(),"ENQUIRY",link=>"mailto:$dref->{'from'}",%{$dref});
	
	return("?m=sendMsgResponse&err=");
	}

##
## pass: 
##		handler=which handler to return the data addressed to (defaults to getResponse)
##		var=	(defaults to var)
##		src=	where to get the data from e.g. product:zoovy:asdf
##
##		sku=	(sets the default SKU for scoping - required if you are loading product: data)
##		cart=	(session id)
##
##	get response:
##		$var = data loaded from src
##		m = $handler
##	
##	getScalar response: only the text 
##
##
sub get {
	my ($SITE,$dref) = @_;

	my %response = ();
	$response{'m'} = (defined $dref->{'handler'})?$dref->{'handler'}:'getResponse';
	$dref->{'var'} = (defined $dref->{'var'})?$dref->{'var'}:'var';
	$dref->{'src'} = lc($dref->{'src'});

	if ($dref->{'src'} =~ /^product\:\:(.*?)$/) {
		$dref->{'src'} = $1;
		if (defined $dref->{'sku'}) { $SITE->sset('_SKU',$dref->{'sku'}); }
#		$response{ $dref->{'var'} } = &FLOW::smart_load($dref->{'src'},undef,undef);
		}
	elsif ($dref->{'src'} =~ m/^cart\:\:(.*?)$/) { 
		$dref->{'src'} = $1;
		if (not defined $SITE::CART2) { $SITE::CART2 = CART2->new_persist($SITE->username(),$SITE->prt(),$dref->{'cart'}); }
		if (defined $SITE::CART2) { $response{ $dref->{'var'} } = $SITE::CART2->legacy_fetch_property($dref->{'src'}); } 
		}

	# print STDERR Dumper(\%response);

	if ($dref->{'m'} eq 'getScalar') { 
		return($response{'var'}); 	
		}
	else {
		return("?".&PAGE::AJAX::serialize_hashref(\%response));
		}
	}

##
##	pass: 
##		uuid=request# (optional)
##		src=cart::variable	
##		cart=cart uuid
##		data=<data to be set in variable>
##		
##
## response:
##		uuid=request# (optional)
##		m=setResponse
##
sub set {
	my ($SITE,$dref) = @_;

	my %response = ();
	$response{'m'} = (defined $dref->{'handler'})?$dref->{'handler'}:'setResponse';
	$dref->{'var'} = (defined $dref->{'var'})?$dref->{'var'}:'var';
	$dref->{'src'} = lc($dref->{'src'});
	## uppercase all variables in the set since it's going to an element.
	foreach my $k (keys %{$dref}) {
		$dref->{uc($k)} = $dref->{$k}; 	
		}

	return(&TOXML::RENDER::RENDER_SET($dref,undef,$SITE));
	}

sub ping {
	return("?m=pong&t=".uri_escape("welcome to the junkyard ".(time()).' SITE::v='.Dumper($SITE::v_mixed)));	
	}

##
## parameters:
##		$VAR2 = {
#          'keywords' => undef,
#          'format' => 'WRAPPER',
#          'docid' => '*test',
#          'targetDiv' => 'IMAGECART',
#          'm' => 'RenderElement',
#          'targetdiv' => 'IMAGECART', -- sends back an "updateDiv" 
#          'element' => 'IMAGECART'
#        };				
##
sub RenderElement {
	my ($SITE,$dref) = @_;

	require TOXML;
	my $buf = undef;
	if ((not defined $dref->{'format'}) || ($dref->{'format'} eq '') || (not defined $dref->{'docid'}) || ($dref->{'docid'} eq '')) {
		$buf = "<!-- parameters 'format' and 'docid' are both required to render an element -->";
		}

	my $t = undef;
	if (not defined $buf) {
		($t) = TOXML->new($dref->{'format'},$dref->{'docid'},USERNAME=>$SITE->username());
		if (not defined $t) {
			$buf = sprintf('<!-- Could not load FORMAT=%s DOCID=%s -->',$dref->{'format'},$dref->{'docid'});
			}
		}

	if (not defined $buf) {
		require TOXML::RENDER;
		## Run the config element to setup site buttons
		$t->initConfig($SITE);
		if ($dref->{'format'} eq 'WRAPPER') {
			$SITE->URLENGINE()->set('wrapper'=>$t->docuri());
			}
	
		my ($el) = $t->getElementById($dref->{'element'});

		if ($el->{'INIT'}) {
			## this is a small chunk of specl code which can override various parameters.
			$SITE->txspecl()->translate3($el->{'INIT'},[$el,$dref],replace_undef=>1,initref=>$el);
			}

		if (defined $TOXML::RENDER::render_element{ $el->{'TYPE'} }) {
			($buf) = $TOXML::RENDER::render_element{ $el->{'TYPE'} }->($el,$t,$SITE,$dref);
			}
		else {
			$buf = "<!-- Could not find/run type [$el->{'TYPE'}] for $dref->{'element'} -->\n";
			}
		}
	my $out = '?m=updateDiv&div='.$dref->{'targetDiv'}.'&html='.URI::Escape::XS::uri_escape($buf)."\n";
	# my $out = '?m=updateDiv&div='.$dref->{'targetDiv'}.'&html='.URI::Escape::uri_escape_utf8($buf)."\n";
	# print STDERR "OUT: $out\n";

	return($out);
	}

##
## renderProduct
##
sub renderProduct {
	my ($SITE,$dref) = @_;
	require TOXML;
	require SITE;

	my ($t) = TOXML->new('LAYOUT',$dref->{'fl'},USERNAME=>$SITE->username());
	my $buf = '';
	if (not defined $t) {
		$buf = 'Could not load LAYOUT '.$dref->{'fl'};
		}
	else {
		($buf) = $t->render(SKU=>$dref->{'pid'},'*SITE'=>$SITE);
		}
	my $out = '?m=updateDiv&div='.$dref->{'div'}.'&html='.URI::Escape::XS::uri_escape($buf)."\n";
	return($out);
	}

##
## parameters:
## gets passed: cart and pid (and eventually other form parameters)		
##
sub AddToCart {
	my ($SITE,$dref) = @_;
	require STUFF::CGI;
	require LISTING::MSGS;
	if (not defined $SITE::CART2) { $SITE::CART2 = CART2->new_persist($SITE->username(),$SITE->prt(),$dref->{'cart'}); }

	my @ERRORS = ();

	my $lm = LISTING::MSGS->new();
	my ($s2) = STUFF2->new($SITE->username());

	$s2->link_cart2($SITE::CART2);
	($s2,$lm) = &STUFF::CGI::legacy_parse($s2,$dref,'*LM'=>$lm);

#	print STDERR 'DREF: '.Dumper($dref);

	# if ($SITE->username() eq 'cubworld') { print STDERR 'AJAX: '.Dumper(\@items); }
	my $itemsref = $s2->items();

	my $count = scalar(@{$itemsref});
	foreach my $item (@{$itemsref}) {
		my $existingitem = $SITE::CART2->stuff2()->item('stid'=>$item->{'stid'});
		if (defined $existingitem) {
			## item doesn't exist, add it## item exists, update quantity
			if ($existingitem->{'%options'}) {
				foreach my $pogidval (keys %{$existingitem->{'%options'}}) {
					if (substr($pogidval,2,2) eq '##') {
						$lm->pooshmsg("DEBUG|+Item '$existingitem->{'stid'}' was left in cart because pogset '$pogidval' requires it be unique");
						}
					}
				}
			}
	
		if (defined $existingitem) {
			## item exists, update quantity
			$SITE::CART2->stuff2()->drop('uuid'=>$existingitem->{'uuid'});
			$existingitem = undef;
			}
	
		$SITE::CART2->stuff2()->fast_copy_cram($item);
		}

	foreach my $msg (@{$lm->msgs()}) {
		my ($msgref,$status) = LISTING::MSGS::msg_to_disposition($msg);
		if ($status eq 'ERROR') { push @ERRORS, $msgref->{'+'}; }
		if ($status eq 'WARN') { push @ERRORS, $msgref->{'+'}; }
		if ($status eq 'STOP') { push @ERRORS, $msgref->{'+'}; }
		}

#	print STDERR Dumper($itemsref,$SITE::CART2->stuff2());

#	print STDERR 'AFTER'.Dumper($count,$itemsref,$SITE::CART2)."\n";

#	foreach my $item (@items) {
#		my ($err,$message) = $SITE::CART->cart_add_stuff($item,1);
#		print STDERR "ERR: $err MSG: $message\n";
#		if ($err) { push @ERRORS, $message; }
#		}
		
	my $out = '';
	foreach my $err (@ERRORS) { 
#		print STDERR "AJAX-AddToCart-Error: $err\n";
		$out .= "?m=cartError&msg=$err\n"; 
		}

	if ($SITE::CART2->stuff2()->count() || $count) {
#		print STDERR "Saving cart from ajax AddtOcart ".($SITE::CART->id())."\n";
#		$SITE::CART2->save();
		$SITE::CART2->cart_save();
		$out .= "?m=updateCart&\n";
		}
	else {
		warn "No items added/removed from cart (blank response was sent)";
		}

	return($out);
	}


##
## also does "searchResults" (which is just a different response format)
##
sub AutoComplete {
	my ($SITE,$dref) = @_;

	# $dref->{'CATALOG'} = 'TESTING';

	my $keywords = $dref->{'keywords'};
	my @AR = ();
#	if (($dref->{'catalog'} eq '') || ($dref->{'catalog'} eq 'TESTING')) {
#		# @AR = ('Test Result 1', 'Test Result 2', 'Test Result 3', 'If you are', 'seeing this, you', 'probably did not', 'specify a', 'search catalog', 'Test Result 9', 'Test Result 10');
#		@AR = ();
#		}
#	else {
#		require SEARCH::DICTIONARY;
#		@AR = SEARCH::DICTIONARY::dictionary_match($SITE->username(),$dref->{'catalog'},$keywords);
#		}
	
	my $out = '';
	if ($dref->{'_METHOD'} eq 'AutoComplete') {
		$out .= "<ul>";
		foreach my $result (@AR) {
			my ($word) = $result->[0];
			$out .= "<li>$result</li>";
			}
		$out .= "</ul>";
		}
	elsif ($dref->{'_METHOD'} eq 'searchCatalog') {
		my %pids = (); my $i = 0;
		foreach my $pid (@AR) { $pids{'pid'.$i++} = $pid; }
		$out = "?m=searchResponse&matches=".$i."&".serialize_hashref(\%pids);
		}
	else {		
		warn "Unknown method/function[$dref->{'_METHOD'}]\n";
		}


	return($out);
	}

##
##
##
sub addReview {
	my ($SITE,$ref) = @_;

	use Data::Dumper; print STDERR Dumper($ref);

	require PRODUCT::REVIEWS;
	if (not defined $ref->{'PID'}) { $ref->{'PID'} = $SITE->pid(); }
	my ($ERROR) = PRODUCT::REVIEWS::add_review($SITE->username(),$ref->{'PID'},$ref);
	my $out = "?m=addReviewResponse&err=".$ERROR;
	return($out);
	}


sub addNotify {
	my ($SITE,$vref) = @_;

#	use Data::Dumper; print STDERR Dumper($ref);
	if (not defined $vref->{'sku'}) { $vref->{'sku'} = $SITE->sku(); }

	my $SKU = $vref->{'sku'};
	my $email = $vref->{'email'};
	my $msgid = $vref->{'msgid'};

	require INVENTORY2::UTIL;
	my ($error) = &INVENTORY2::UTIL::request_notification( $SITE->username(), $SKU, 
		# NS=>$SITE->profile(),
		PRT=>$SITE->prt(),
		EMAIL=>$email, 
		MSGID=>$msgid,
		VARS=>&ZTOOLKIT::buildparams($vref,1));
	my $out = "?m=addNotifyResponse&err=".$error;
	return($out);
	}



## converts a hashref to a set of js_encoded key value pairs 
sub serialize_hashref {
	my ($ref) = @_;

	my $str = '';
	foreach my $k (keys %{$ref}) {
		$str .= sprintf("%s=%s&",&js_encode($k),&js_encode($ref->{$k}));
		}
	chop($str); 	# remove trailing &
	# print STDERR "serialized result: $str\n";
	return($str);
	}

##
## performs minimal uri encoding
##
sub js_encode {
	my ($str) = @_;

	if (not Encode::is_utf8($str)) {
		$str = Encode::encode_utf8($str);
		}

	my $string = '';
	foreach my $ch (split(//,$str)) {
		my $oi = ord($ch);
		if ((($oi>=48) && ($oi<58)) || (($oi>64) &&  ($oi<=127))) { $string .= $ch; }
		## don't encode <(60) or >(62) /(47)
		elsif (($oi==32) || ($oi==60) || ($oi==62) || ($oi==47)) { $string .= $ch; }
		else { $string .= '%'.sprintf("%02x",ord($ch));  }
		}
	return($string);
	}


1;

