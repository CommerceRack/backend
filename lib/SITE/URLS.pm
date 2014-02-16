package SITE::URLS;

use strict;
use URI::Escape::XS qw();
use lib "/backend/lib";
require ZWEBSITE;
require ZTOOLKIT;

##
## 
##
$SITE::URLS::USE_CLOUDFRONT = 0;
$SITE::URLS::DISABLE_SSL_CERTS = 0;

%SITE::URLS::INFO = (
	## BEGIN SYSTEM VARIABLES ##
	## if we are missing these, it's because we didn't run a set yet.
#	'cart_url' => '',
#	'nonsecure_url' => '',
#	'dynamic_url' => '',
#	'wrapper_url' => '',
#	'graphics_url' => '',
#	'navbutton_url' => '',
#	'userbutton_url' => '',
#	'image_url' => '',			
	## END SYSTEM VARIABLES ##

	## FORMAT 	## 	var => ['path',handler,]
	##		handler is a bitwise value:
	##			1 = always rewrite secure
	##			2 = never rewrite secure ( NO LONGER AVAILABLE )
	##			4 = always include cart url
	##			8 = stay secure/nonsecure (depending on what the page is)
	##			16 = notify when requested.
	##
	
	'review_url'			  => ['/review.cgis',0+8],
	'confirm_url'			  => ['/confirm.cgis',0+8],
	'homepage_url'         => ['/',0+8],
	'continue_url'         => ['/',0+8],
	'logout_url'           => ['/',0+8],
	'homecategory_url'     => ['/',0+8],
	'cart_url'             => ['/cart.cgis',0+8+4],
	'privacy_url'          => ['/privacy.cgis',0+8],
	'returns_url'          => ['/returns.cgis',0+8],
	'aboutus_url'          => ['/about_us.cgis',0+8],
	'about_zoovy_url'		 => ['/about_zoovy.pl',0+8],
	'search_url'           => ['/search.cgis',0+8],
	'news_url'             => ['/about_us.cgis',0+8+16],
	'feedback_url'         => ['/contact_us.cgis',1+8+16],
	'product_url'          => ['/product',0+8],
	'category_url'         => ['/category',0+8],
	'magic_url'				  => ['/',4+8],
	#'adult_url'            => ['/adult.cgis',0+8],
	'claim_url'            => ['/claim.cgis',0+8],
	# 'claim_multi_url'      => ['/claim_multi.cgis',0+8],
	# 'counter_url'          => ['/counter.cgis',0+8+16],
	'mail_form_url'        => ['/mail_form.cgis',0+8+16],
	'results_url'          => ['/results.cgis',0+8],
	'subscribe_url'        => ['/subscribe.cgis',1+8],
	# 'no_cookies_url'       => ['/no_cookies.cgis',0+8+4],
	'disabled_url'         => ['/disabled.cgis',0+8],
	# 'gallery_url'          => ['/gallery.cgis',0+8+16],
	# 'kill_cookies_url'     => ['/kill_cookies.cgis',0+8+4],
	'redir_url'            => ['/redir.cgis',0+8],
	'paypal_url'           => ['/paypal.cgis',1+4],
	'closed_url'           => ['/closed.cgis',0+8],
	# 'shipquote_url'        => ['/shipquote.cgis',0+8],

	'home_url'       => ['/',0+8],
	'about_url'      => ['/about_us.cgis',0+8],
	'about_us_url'   => ['/about_us.cgis',0+8+16],
	'contact_url'    => ['/contact_us.cgis',0+8],
	'contact_us_url' => ['/contact_us.cgis',0+8+16],
	'contactus_url'  => ['/contact_us.cgis',0+8+16],

	#!'support_url'			  => ['/_support',1+4],	
	'customer_url'	=> ['/customer',1+4],
	'customer_main_url'	=> ['/customer/',1+4],
	#!'customer_main_url'    => ['/customer_main.cgis',1+4],
	#!'order_status_url'     => ['/order_status.cgis',1+4],
	'order_status_url'	=> ['/customer/order/status',1+4],
	#!'cancel_order_url'     => ['/cancel_order.cgis',1+4],
	'cancel_order_url'	=> ['/customer/order/cancel',1+4],
	#!'update_payment_url'   => ['/update_payment.cgis',1+4],
	'update_payment_url'	=> ['/customer/order/pay',1+4],
	'logout_function_url'  => ['/customer/logout',0+8],
	## mail_config_url and remove_url now both go to newsletter_handler
	#!'mail_config_url'      => ['/mail_config.cgis',1+4],
	'mail_config_url'	=> ['/customer/newsletter/config',0+8+4],
	#!'remove_url'           => ['/mail_config.cgis',0+8+4],
	'remove_url'	=> ['/customer/newsletter/config',0+8+4],
	#!'cust_address_url'     => ['/cust_address.cgis',1+4],
	'cust_address_url'     => ['/customer/addresses',1+4],
	#!'wishlist_url'			  => ['/wishlist.cgis',1+4],
	#!'login_url'            => ['/login.cgis',1+4],
	'login_url'            => ['/customer/login',1+4],
	#!'forgot_url'           => ['/forgot.cgis',1+4],
	'forgot_url'           => ['/customer/login/forgot',1+4],
	#!'password_url'         => ['/password.cgis',1+4],
	'password_url'         => ['/customer/password',1+4],
	#!'fastorder_url'        => ['/fastorder.cgis',1+4],
	'fastorder_url'        => ['/customer/wholesale/order',1+4],
	#!'rewards_url'			  => ['/rewards.cgis',1+4],
	#!'rma_url'				  => ['/rma.cgis',1+4],
	'checkout_url'         => ['/checkout.cgis',1+4],
	'confirm_url'			  => ['/confirm.cgis',1+4],
	'googlecheckout_url'	  => ['/_googlecheckout',1+4], 
);


sub wrapper {  my ($self) = $_[0]; return($self->{'_WRAPPER'}); }
sub layout {  my ($self) = $_[0]; return($self->{'_LAYOUT'}); }
sub newsletter {  
	my ($self) = $_[0]; 
	if (defined $self->{'_NEWSLETTER'}) { return($self->{'_NEWSLETTER'}); }
	return( $self->{'_NEWSLETTER'} = $self->_SITE()->_is_newsletter() );
	}
sub email {  my ($self) = $_[0]; return($self->{'_EMAIL'}); }
sub state { my ($self) = $_[0]; return($self->{'_STATE'});  }
sub secure { my ($self) = $_[0]; return($self->{'_STATE'}&1); }
sub domain { 
	my ($self) = $_[0]; 
	my $SITE = $self->_SITE();
#	print STDERR Carp::cluck($SITE)."\n"; 
#	print STDERR Dumper($SITE)."\n";
#	print STDERR Dumper($self)."\n";
	return($self->_SITE()->linkable_domain()); 
	}
sub _SITE { my ($self) = $_[0]; return($self->{'*SITE'}); }
sub cart2 { return($_[0]->_SITE()->cart2()); }

## used to determine if CACHEABLE (in flags)
sub has_cookies { my ($self) = $_[0]; return(($self->{'_STATE'} & 4)==4); }
sub is_app { my ($self) = $_[0]; return(($self->{'_STATE'} & 32)==32); }

## %options
##		min=>minimal
sub image_url {
	my ($self,$imagename,$w,$h,$bg,%options) = @_;

	my $v = int($self->gref()->{'%tuning'}->{'images_v'});

	#require IMGLIB::Lite;
	#my $result = IMGLIB::Lite::url_to_image($self->username(),$imagename,$w,$h,$bg,
	#		$options{'minimal'},
	#		$options{'p'},	# pixel scaling
	#		$self->_SITE()->cache_ts(),
	#		$v
	#		);
	my $result = &ZOOVY::image_path($self->username(),$imagename,W=>$w,H=>$h,B=>$bg,
			minimal=>$options{'minimal'},
			pixel=>$options{'p'},	# pixel scaling
			cache=>$self->_SITE()->cache_ts(),
			V=>$v,
			shibby=>1,
			);

	if (substr($result,0,2) eq '//') {
		## this already has a host -- no append (don't remove this without rethnking shibby above)
		}
	elsif ($self->newsletter()) {
		## newsletters are always insecure
		$result = sprintf("http://%s%s",&ZOOVY::resolve_media_host($self->username()),$result);
		}
	elsif ($self->wrapper() ne '') {
		## hooray! we can just use a relative path
		}
	else {
		## prepend protocol://mediahost since we're not running on a site
		$result = sprintf("%s://%s%s",($self->secure()?'https':'http'),&ZOOVY::resolve_media_host($self->username()),$result);
		}

	return($result);
	}

##
##	set causes the internal state engine to go through and evaluate urls that changed.
##
## possible things you can set
##		bit5/16 'authenticated'=>1/0
##		bit4/8 'bot'=>1/0 -- means that we're being scoured by a robot.
##		bit3/4 'cookies'=>1/0 -- basically the same thing as sessions 
## 	bit2/2 'sessions'=>1/0 -- turns on session rewriting in urls
##		bit1/1 'secure'=>1/0
##
sub set {
	my ($self,%options) = @_;

	
	if ($options{'toxml'}) {
		## toxml=>$docref is faster way to setup the proper document path based on the config.
		my ($t) = $options{'toxml'};
		$options{ lc($t->getFormat()) } = $t->docuri();
		delete $options{'toxml'};
		}


	foreach my $k (keys %options) {

		# print STDERR "SETTING st[$self->{'_STATE'}] OPTION '$k' = '$options{$k}' ".join("|",caller(0))."\n";

		if ($k eq 'cart') {
			$self->{'_CART'} = $options{$k};
			}
		elsif ($k eq 'secure') { 
			# NOTE: security can only be added, NOT removed. 
			## this is necessary since emails are sent non-secure
			if (($self->{'_STATE'}&1)==1) { $options{$k} = 1; }
			elsif ($SITE::OVERRIDES{'dev.ssl_only'}) { $options{$k} = 1; }
			$self->{'_STATE'} |= (($options{$k})?1:0); 
			}
		elsif ($k eq 'sessions') { 
			$self->{'_STATE'} |= (($options{$k})?2:0);		# forces session rewriting 
			}
		elsif ($k eq 'bot') {
			$self->{'_STATE'} |= (($options{$k})?8:0); 		# tracks if the client is a robot.
			}
		elsif ($k eq 'cookies') {
			$self->{'_STATE'} |= ($options{$k})?4:0; 			# tracks if we have cookies or not.
			}
		elsif ($k eq 'authenticated') {
			$self->{'_STATE'} |= ($options{$k})?16:0; 		# authenticated
			}
		elsif ($k eq 'is_app') {
			$self->{'_STATE'} |= ($options{$k})?32:0; 			# tracks if we have cookies or not.
			}
		elsif ($k eq 'domain') {
			$self->{'_DOMAIN'} = $options{$k};
			}
## NOTE: does not work
#		elsif ($k eq 'track') {
#			$self->{'_track'} = $options{$k};
#			}
		elsif (($k eq 'wrapper') || ($k eq 'layout') || ($k eq 'email') || ($k eq 'newsletter') || ($k eq 'wizard')) {
			my $PREFIX = 'X';
			if ($k eq 'wrapper') { $PREFIX = '_WRAPPER'; }
			elsif ($k eq 'layout') { $PREFIX = '_LAYOUT'; }
			elsif ($k eq 'email') { $PREFIX = '_EMAIL'; }
			elsif ($k eq 'newsletter') { $PREFIX = '_NEWSLETTER'; }
			elsif ($k eq 'wizard') { $PREFIX = '_WIZARD'; } 
			else { $PREFIX = 'FUCK'; }	## unknown PREFIX (should never be reached)

			## docuri is normally set by $toxml->docuri();
			my $docuri = $options{$k};
			if (index($docuri,"?")>0) {
				## ~docid?FOLDER=_xyz&V=3&PROJECT=123
				my $params = &ZTOOLKIT::parseparams(substr($docuri,index($docuri,"?")+1));
				foreach my $k (keys %{$params}) {
					## _WRAPPER.FOLDER  _LAYOUT.FOLDER
					## _WRAPPER.V		_LAYOUT.V
					$self->{"$PREFIX.$k"} = $params->{$k};
					}
				$docuri = substr($docuri,0,index($docuri,"?"));
				}
			## _WRAPPER _LAYOUT _EMAIL _NEWSLETTER _WIZARD
			$self->{"$PREFIX"} = $docuri;
			}
		}


	## make sure all urls we've set are up to date, for now this means simply flushing all variables.
	foreach my $urlname (keys %{$self}) {
		next if (substr($urlname,0,1) eq '_');		# hidden internal variables
		next if ($urlname eq 'nonsecure_url');		# reserved
		next if ($urlname eq 'secure_url');			# reserved
		next if (substr($urlname,0,1) eq '*');		# keep object references

		delete $self->{$urlname};
		}

	$self->{'userbutton_url'} = '';		## hmm.. not sure what the heck these are.
	$self->{'sitebutton_url'} = '';

	## each time we change state, we need to update internally.
	
	#my $imgcluster = 'static.zoovy.com';
	my $MEDIAHOST = &ZOOVY::resolve_media_host($self->{'_USERNAME'});
	my $protocol = 'http';
	if ($self->{'_STATE'}&1) { $protocol = 'https'; }

	## CONFIGURE email_url (if any)
	if (defined $self->{'_EMAIL'}) {
		$self->{'email_url'}    = "$protocol://$MEDIAHOST/media/graphics/emails/".$self->{'_EMAIL'};
		if (substr($self->{'_EMAIL'},0,1) eq '~') {
			$self->{'email_url'} = "$protocol://$MEDIAHOST/media/merchant/$self->{'_USERNAME'}";
			if ($self->{'_EMAIL.FOLDER'} ne '') {
				$self->{'email_url'} .= '/'.$self->{'_EMAIL.FOLDER'};
				}
			}
		}


	## CONFIGURE wizard_url (if any)
	if (defined $self->{'_WIZARD'}) {
		$self->{'wizard_url'}    = "$protocol://$MEDIAHOST/media/graphics/wizards/".$self->{'_WIZARD'};
		if (substr($self->{'_WIZARD'},0,1) eq '~') {
			$self->{'wizard_url'} = "$protocol://$MEDIAHOST/media/merchant/$self->{'_USERNAME'}";
			if ($self->{'_WIZARD.FOLDER'} ne '') {
				$self->{'wizard_url'} .= '/'.$self->{'_WIZARD.FOLDER'};
				}
			}
		}

	my $CDN_PREFIX = '';
	my ($CFG) = CFG->new();
	if ($CFG->get('global','cdn')) {
		$CDN_PREFIX = sprintf("//%s",$CFG->get('global','cdn'));
		}

	$self->{'files_url'} = "$protocol://$MEDIAHOST/media/merchant/$self->{'_USERNAME'}";
	$self->{'graphics_url'} = "$protocol://$MEDIAHOST/media/graphics/general";
	$self->{'navbutton_url'}  = "$protocol://$MEDIAHOST/media/graphics/navbuttons";
	$self->{'image_url'}	  = "$protocol://$MEDIAHOST/media/img/$self->{'_USERNAME'}";

	if ((defined $self->{'_WRAPPER'}) || (defined $self->{'_LAYOUT'})) {
		if ($self->newsletter() || $self->{'_EMAIL'}) { 
			## FUCKK!K!!!!!!!!!!!!!!!!!!  sometimes we use layouts as newsletters.
			}
		else {
			$self->{'files_url'} = "/media/merchant/$self->{'_USERNAME'}";
			$self->{'graphics_url'} = "$CDN_PREFIX/media/graphics/general";
			$self->{'navbutton_url'}  = "/media/graphics/navbuttons";
			$self->{'image_url'}	  = "$CDN_PREFIX/media/img/$self->{'_USERNAME'}";
			}

		## CONFIGURE wrapper_url (if any)
		if (defined $self->{'_WRAPPER'}) {
			$self->{'wrapper_url'}    = "$CDN_PREFIX/media/graphics/wrappers/".$self->{'_WRAPPER'};
			if (substr($self->{'_WRAPPER'},0,1) eq '~') {
				$self->{'wrapper_url'} = "$CDN_PREFIX/media/merchant/$self->{'_USERNAME'}";
				if ($self->{'_WRAPPER.FOLDER'} ne '') {
					$self->{'wrapper_url'} .= '/'.$self->{'_WRAPPER.FOLDER'};
					}
				}
			}

		## CONFIGURE layout_url (if any)
		if (defined $self->{'_LAYOUT'}) {
			$self->{'layout_url'}    = "$CDN_PREFIX/media/graphics/layouts/".$self->{'_LAYOUT'};
			if (substr($self->{'_LAYOUT'},0,1) eq '~') {
				$self->{'layout_url'} = "$CDN_PREFIX/media/merchant/$self->{'_USERNAME'}";
				if ($self->{'_LAYOUT.FOLDER'} ne '') {
					$self->{'layout_url'} .= '/'.$self->{'_LAYOUT.FOLDER'};
					}
				}
			if ($self->newsletter() || $self->{'_EMAIL'}) { 
				## FUCKK!K!!!!!!!!!!!!!!!!!!  sometimes we use layouts as newsletters.
				$self->{'layout_url'} = "$protocol://$MEDIAHOST$self->{'layout_url'}";
				}
			}
		}

	}


##
## overrides a url (e.g. checkout_url)
##
sub override {
	my ($self, $urlname,$path) = @_;		
	$self->{$urlname} = $path;	
	return();
	}

####################################################################
##
## returns a URL variable -- see list above for a list of names.
##
sub get {
	my ($self,$urlname) = @_;

	# print STDERR "SITE::URLS GET[$self->{'_SDOMAIN'}] $urlname \n";

	my $result = undef;
	if (defined $self->{$urlname}) {
		$result = $self->{$urlname};
#		print STDERR "RESULT: $urlname=$result\n";
		}
	elsif ($urlname eq 'continue_url') {
		## continue always returns to the last category (from CART->{'memory_category'})
		if ((defined $SITE::CART2) && (defined $SITE::CART2->{'memory_navcat'})) {
			my ($safename) = split(/,/,$SITE::CART2->{'memory_navcat'});

			if ($safename eq '.') {
				}
			elsif (substr($safename,0,1) eq '.') { 
				$safename = substr($safename,1); 
				}

			$result = $self->rewrite( $self->{'nonsecure_url'}."/category/$safename" );
			undef $safename;
			}
		}
	elsif (defined $SITE::URLS::INFO{$urlname}) {}		## this is where MOST requests ought to stop.
	else {
		if (not defined $urlname) { 
			warn "missing url name -- setting to home_url"; 
			$urlname = 'home_url';  
			}

		$urlname = lc($urlname);
		$urlname =~ s/[\W]+//gs;
		if (defined $self->{$urlname}) {
			$result = $self->{$urlname};
			}

		if ((not defined $result) && (defined $self->{$urlname.'_url'})) {
			$self->{$urlname} = $self->{$urlname.'_url'};
			$result = $self->{$urlname};
			}

		if ((not defined $result) && (defined $SITE::URLS::INFO{$urlname.'_url'})) {
			# my ($package,$file,$line,$sub,$args) = caller(0);
			# warn "FLOW::URL Received old style url request for '$name' from $package $line\n";
			# print STDERR "Calling ourselves to get $urlname.'_url'\n";
			$self->{$urlname} = $self->get($urlname.'_url');
			$result = $self->{$urlname};
			}
		
		if ((not defined $result) && (not defined $SITE::URLS::INFO{$urlname})) {
			if ($urlname eq 'merchant_login_url') {}		## we know this one doesn't exist
			elsif ($urlname eq 'dynamic_url') {}		## we know this one doesn't exist
			else {
				#my ($package,$file,$line,$sub,$args) = caller(0);
				#warn "requested unknown url name [$urlname] $package,$file,$line,$sub,$args";
				# use Data::Dumper; print STDERR Dumper($self);
				}
			$urlname = 'home_url'; 
			}

		}

	## 
	## at this point we've already bailed if we new the answer
	##
	my ($secure) = undef;
	if (not defined $result) {
		my ($path,$state) = @{$SITE::URLS::INFO{$urlname}};
		## state is a variable - set above:
		##		1 - always secure
		##		2 - never secure
		## 	4 - force rewrite
		##		8 - secure/non-secure based on what the page was/is
		my ($rewrite) = ($state&4)?1:0;
		# print STDERR "URL_STATE:$state [$path]\n";
		
		if ($state&1) { $secure |= 1; }
		if ($state&8) {$secure |= (lc((defined $ENV{'HTTPS'})?$ENV{'HTTPS'}:'') eq 'on')?1:0; }
		if ($state&2) { $secure = 0; }
			
		## Determine which URLs need to be rewritten
		# if no cookies, then rewrite EVERYTHING
		if (($state & 4)==0) { $rewrite++;  }
		## If we don't have cookies and the cart has stuff in it, we need to rewrite all URLs
		## elsif ((defined $CART::TOUCHED) && ($CART::TOUCHED)) { $rewrite++; }
		elsif (defined $self->domain()) {
			## if we're on a speciality domain, we should *always* rewrite
			$rewrite++;
			}
		elsif (defined $self->_SITE()->linkable_domain()) {
			## if we're on a speciality domain, we should *always* rewrite
			$rewrite++;
			}

		if ($self->{'_STATE'}&8) { $rewrite = 0; }	# never rewrite bot urls!
		
		# Add the server name to the URL
		# Should handle http: https: mailto: javascript: etc.
		#if ($path !~ m/^[A-Za-z]+\:/) {
		#	$path = (($path !~ m/\.cgis$/) ? $u{'nonsecure_url'} : $u{'dynamic_url'} ) . $path;
		#	}

		if ($secure) {
			# Fully-qualify secure URLs (different process than non-secure since there are no user-defined secure URLs)
			if ($path !~ m/^[Hh][Tt][Tt][Pp][s]+\:/o) { $path = $self->{'secure_url'}.$path; }
			$rewrite++;
			}
		elsif (defined $SITE::OVERRIDES{'dev.'.$urlname}) { 
			$path = $SITE::OVERRIDES{'dev.'.$urlname}; $rewrite=0; 
			}
		else {
			$path = $self->{'nonsecure_url'}.$path;
			}

		# print STDERR "PATH: $path ($secure)\n";
		if (not $rewrite) {
			}
		elsif ($secure) {
			## checkout's always get session id's
			}
		elsif ($SITE::OVERRIDES{'dev.disable_sessions'}) {
			$rewrite = 0;
			}
		elsif (int($self->gref()->{'%tuning'}->{'disable_sessions'}) == 1) {
			$rewrite = 0;
			}
		# print STDERR "URLNAME: $urlname PATH: $path $rewrite\n";

		if ($rewrite) {
			$result = $self->rewrite($path);
			}
		else {
			$result = $path;
			}
	
		}

#	if ($self->{'_track'}) {
#		$result = "$result?$self->{'_track'}";
#		}

	if (not defined $result) {
		$result = "#uri_spec_$urlname\_not_found";
		}

	# print STDERR "Request[$secure]: $urlname=[$result]\n";
	return($result);
	}

##
##
sub username { return($_[0]->{'_USERNAME'}); }
sub gref {
	my ($self) = @_;
	if (not defined $self->{'_GREF'}) {
		$self->{'_GREF'} = &ZWEBSITE::fetch_globalref($self->username());
		}
	return($self->{'_GREF'});
	}


##
##
## internal state variables:
##	 _STATE (bitwise) 
##		1 = secure
##		2 = rewrite sessions into url
##		4 = user has cookies (which implicitly means +2)
##		NOT IMPLEMENTED: 8 = we're being called from within the editor/zoovy ui
##
sub new {
	my ($class, $USERNAME, %options) = @_;
	# print STDERR "SITE::URL->new ".join("|",caller(0))."\n";

	my $self = {};
	$self->{'_USERNAME'} = $USERNAME;
	bless $self, 'SITE::URLS';

	my $SITE = $self->{'*SITE'} = $options{'*SITE'};
	if ((not defined $self->{'*SITE'}) || (ref($self->{'*SITE'}) ne 'SITE')) {
		Carp::confess( "*SITE  is required parameter to SITE::URLS->new" );
		}

	## If we know we're at a merchant's domain, use that domain
	##
	## both secure and non_secure urls should be full qualified.
	##
	my $DOMAIN = $SITE->linkable_domain();

	$self->{'nonsecure_url'} = sprintf("http://%s",$DOMAIN);

	# if ($USERNAME eq 'depclar') { $SITE::URLS::DISABLE_SSL_CERTS = 1; }
	if (($SITE->secure_domain() ne '') && (not $SITE::URLS::DISABLE_SSL_CERTS)) {
		## $self->{'secure_url'} = sprintf("https://%s/s=%s",$SITE->secure_domain(),$DOMAIN);
		## DO NOT INCLUDE the /s=domain.com because that will jack up references to /jsonapi/
		$self->{'secure_url'} = sprintf("https://%s",$SITE->secure_domain());
		}
	else {
		# $self->{'secure_url'} = sprintf("https://ssl.zoovy.com/s=%s",$DOMAIN);
		my ($CDOMAIN) = &ZWEBSITE::domain_to_checkout_domain($DOMAIN);
		$self->{'secure_url'} = sprintf("https://%s",$CDOMAIN);
		}

	$self->set(%options);

	return($self);
	}



################################################################################
## This code take a URL and adds on the cart string and speciality site string
## 	e.g. /c=1234567890aAbBcCdD.../ and e.g. /s=123457/ 
##
## So that we know what cart to look at.
##
sub rewrite {
	my ($self,$url) = @_;

	#if ($self->_SITE()->_is_app()) {
	#	## no rewrites for apps (they do their own session management)
	#	warn "is_app shortcut on $url\n";
	#	return($url);
	#	}

	my $header = '';
	my ($proto,$prefix,$host,$uripath) = '';

	my $username = quotemeta($self->{'_USERNAME'});
	
	my $rewrites = 0;		# bitwise operator
	## 1 = add cart url /c=
	##	2 = add session url /s=


	if (substr($url,0,1) eq '/') {
		## e.g. /something/asdfasfasdf (does not have the http://hostname)
		## at a minimum this is called by $SITE::URLS->get("continue_url") function 
		## normally these urls will work fine, unless we're on a secure url.
		$url = ((($self->{'_STATE'}&1)==1)?$self->{'secure_url'}:$self->{'nonsecure_url'}).$url;
		}

	## this handles everything but ssl.zoovy.com
	#https://ssl.zoovy.com/brian/login.cgis:
	if ($url =~ m/^([Hh][Tt][Tt][Pp][Ss]?\:\/\/)([Ww][Ww][Ww]\.|)(.*?)(\/|\Z)(.*?)$/go) {
		($proto,$prefix,$host,$uripath) = ($1,$2,$3,((defined $5)?$5:'') ); 
		$proto = lc($proto);
		$prefix = lc($prefix);
		$host = lc($host);
		}

	#if (($proto eq 'https://') && ($host eq 'ssl.zoovy.com')) {
	#	## for ssl.zoovy.com we've got to change the header to http://ssl.zoovy.com/brian/whatever
	#	# $header = $proto.$prefix.$host.'/'.$self->{'_USERNAME'};
	#	# $uripath = substr($uripath,length($self->{'_USERNAME'}));	# strip /(username) from uripath
	#	## NOTE: we gotta add c= for sessions since we might be cross domains
	#	$header = $proto.$prefix.$host;
	#	$rewrites = $rewrites | 3;
	#	}
	#elsif (($proto eq 'https://') && ($host =~ /^secure\./)) {
	#	## secure.domain.com (turn on ssl rewrites)
	#	$header = $proto.$prefix.$host;
	#	$rewrites = $rewrites | 3;
	#	}
	if ($proto eq 'https://') {
		$header = $proto.$prefix.$host;
		$rewrites = $rewrites | 3;
		}
	else {
		## everything else!
		$header = $proto.$prefix.$host;
		}

	## if we're on ssl.zoovy.com, or any secure page, rewrite EVERYTHING ..
	if ($self->{'_STATE'}&1) { $rewrites |= 3; }
	## state 4 means no cookies so we force c= into the url
	elsif (($self->{'_STATE'}&4)==0) { $rewrites |= 1; }

	if (($rewrites & 2)==2) {
		## rewrites are turned on, see if we can turn them off
		#if (defined $self->{'_NEWSLETTER'}) {
		#	# newsletters never need rewrites! -- hmm, this might be necessary
		#	$rewrites -= ($rewrites & 2); 
		#	}
		if ((($self->{'_STATE'}&2)==0) && ($host eq $self->domain())) {
			# forget it, we don't need to add s=asdf.com/ because we're on asdf.com
			$rewrites -= ($rewrites & 2);		
			}
		elsif ((($self->{'_STATE'}&2)==0) && ($host eq $self->_SITE()->linkable_domain())) {
			# forget it, we don't need to add s=asdf.com/ because we're on asdf.com
			$rewrites -= ($rewrites & 2);		
			}
		elsif ($url =~ /\/s\=([a-z0-9\.\-]+)\//o) {
			# we already have /s=../ in the url so we don't need to add another one.
			$rewrites -= ($rewrites & 2);
			}
		}
	
	# print STDERR "$url: [$proto][$prefix][$host]=$header   ($rewrites)\n";
	
#	if (not $rewrites) {
#		## don't do anything else, rewrites are not necessary.
#		}
#	else {
		if (not defined $uripath) { $uripath = ''; }
		$uripath =~ s/(\/|\A)c\=[A-Za-z0-9]{25,25}(\/|\Z)/\//go; # STRIP cart urls.
		##	we strip 'em to make sure we don't attempt to write multiple cart strings in a URI.
		$uripath =~ s/\/\/+/\//o; # Compress multiple slashes into one (hmm... this shouldn't happen)
		$uripath =~ s/^\///o; # Get rid of extra leading slash (why?)

		# Do we have to rewrite it?
		if ((not defined $header) || ($header eq '')) {
			## hmm.. no server? this is probably bad. i'm not sure how this could
			## happen, since anthony didn't bother to comment it. I'm guessing it can't, perhaps it will
			## for offsite links (but of course how could those be re-written here anyway?)
			$rewrites = 0;
			}
		elsif (substr($uripath,0,8) eq 'graphics') {
			## never rewrite graphics, they don't need cart ids (not that it would
			## hurt 'em)
			$rewrites = 0;
			}
		elsif ($self->_SITE()->_is_site()) {
			if (ref($self->cart2()) ne 'CART2') {
				&ZOOVY::confess($self->username(),"_is_site is true, but SITE::CART2 is undefined - will/can not continue");
				}			
			elsif ($self->cart2()->is_memory()) {
				## we never add /c=asdfasf/ cart urls for bots!
				## if (defined $self->_SITE()->domain()) { $rewrites = $rewrites | 2; }		# if we have an domain rewrite it.
				$rewrites -= ($rewrites & 1);
				}
			elsif ($self->cart2()->is_order()) {
				$rewrites -= ($rewrites & 1);
				}
			}
		else {
			## we're NOT on a site, avoid any type of cart rewrite
			$rewrites -= ($rewrites & 1);
			}

		if ($rewrites>0) {
			## I guess:
			##	 $header is the name of the site e.g. username.zoovy.com or www.mydomain.com
			##  $uripath is the path to the program we're linking to.
			use Data::Dumper;
			
			# print STDERR Dumper($self,$url,[caller(1)]);
			my $domain = undef;
			if (defined $self->{'_DOMAIN'}) { $domain = $self->{'_DOMAIN'}; }
			elsif (defined $self->_SITE()->linkable_domain()) { $domain = $self->_SITE()->linkable_domain(); }
			else { $rewrites -= ($rewrites & 2); }

			my $cartid = undef;
			if (($rewrites & 1)==0) {}
			elsif (ref($self->cart2()) ne 'CART2') {}
			elsif ($self->cart2()->is_memory()) {}
			else { $cartid = $self->cart2()->uuid(); }
		
			if (($rewrites & 1)==0) {}
			elsif (defined $cartid) {}
			elsif (ref($SITE::CART2) ne 'CART2') {}
			else { 
				warn "SITE::URLS->rewrite&1 is using global SITE::CART2 -- this is NOT recommended.\n";
				$cartid = $SITE::CART2->uuid();
				}
				
			if (($rewrites & 1) && (not defined $cartid))  { 
				warn Carp::confess("NO VALID CART FOUND - so DISABLED rewrites&1 (cart url)\n"); 
				$rewrites -= ($rewrites & 1); 
				}
	
			if (($rewrites & 2)==2) {
				# if we have +2 enabled, and we already have an domain, leave this alone.
				if ($url =~ m/\/s=(.*?)\//o) { $rewrites -= ($rewrites & 2); }
				}
	
			# c= and s=
			$url = $header."/".
					((($rewrites & 1)==1)?sprintf("c=%s/",$cartid):'').
					((($rewrites & 2)==2)?sprintf("s=%s/",$domain):'').
					$uripath;
			# print STDERR "## $$ SDOMAIN:$sdomain $url\n";
			}
#		}
			
	return $url;
	}







##
## perl -e 'use lib "/backend/lib"; use SITE::URLS; $SITE::URL = SITE::URLS->new("sporks",sdomain=>"sporks.zoovy.com"); use WIKI; print WIKI::wiki_format("text [[asdf]asdf][[asdf]asdf][[asdf]]");'
##


%SITE::URLS::WIKI_LINK_FUNCTIONS = (
	'url'=>sub { 
		return( $_[2]->{':url'} );
		},
	'popup'=>sub { 
		if (not defined $_[2]->{'target'}) { $_[2]->{'target'} = 'blank'; }
		return( $_[2]->{':popup'} );
		},
	'search'=>sub {
		my $url = $_[0]->_SITE()->URLENGINE()->get('search'); 
		foreach my $term (split(/[\s\t\n\r]+/,$_[2]->{':search'})) {
			next if ($term eq '');
				$url .= '/'.$term; 
				}
		return($url);
		},
	'app'=>sub {
		my $applink = $_[2]->{':app'};
		return($_[0]->_SITE()->URLENGINE()->get($applink));				
		},
	'policy'=>sub {
		return($_[0]->_SITE()->URLENGINE()->get($_[2]->{':policy'}));		
		},
	'product'=>sub {
		my $url = $_[0]->_SITE()->URLENGINE()->get('product').'/'.$_[2]->{':product'};
		return($url);
		},
	'category'=>sub {
		my $url = $_[0]->_SITE()->URLENGINE()->get('category').'/'.$_[2]->{':category'};
		return($url);
		},
	'customer'=>sub {
		my $url = $_[0]->_SITE()->URLENGINE()->get('customer').'/'.$_[2]->{':customer'};
		if (not defined $_[2]->{'rel'}) {
			$_[2]->{'rel'} = 'noindex, nofollow';
			}
		return($url);
		},
	);




##
## subs is a list of vars to do substitution to, this effectively bypasses
##		intermediate rendering stage.
##
sub wiki_format {
	my ($self,$text,%options) = @_;


	## hmm.. why are we even calling this?
	if (not defined $text) { return(undef); }
	if (index($text,'<nowiki>')>=0) { return($text); }

	my $varsref = $options{'subs'};
	if (not defined $varsref) {
		$varsref = {};
		foreach my $tag (
			'%title1%','%/title1%','%title2%','%/title2','%title2%','%/title3',
			'%table%','%tablerow%','%tablehead%','%/tablehead%','%tabledata%','%/tabledata%','%/table%',
			'%list%','%listitem%','%/listitem%','%/list%',
			'%section%','%/section%',
			'%hardbreak%','%softbreak%') {
			$varsref->{$tag} = $tag;
			}
		}


	my $hasSections = 0;
	$text =~ s/\r\n/\n/gso;	# convert CRLF to just CR
	if ($text =~ /<.*?>/) { $hasSections = -1; }


	##
	## embedded links
	##	format: 	[[word or phrase]]	 - defaults to a search
	##			  	[[word or phrase]:pid=1234]
	##			  	[[word or phrase]:search=asdf]
	##			  	[[word or phrase]:url=http://asdf]
	##				[[word or phrase]:category=.asdf.asdf.asdf]
	##				[[word or phrase]:app=]]
	##				[[word or phrase]:policy=]]
	##	

	if (index($text,'[[')>=0) {
		## handles links.

		my $output = '';
		# parsing strategy: start at the front of $text look for [[
		foreach my $chunk (split(/(\[\[.*?\].*?\])/os,$text)) {
			## at this point $text is [[asdf]...]
			if (substr($chunk,0,2) ne '[[') {
				# push @chunks, [ 0, $chunk ];
				$output .= $chunk;
				}
			elsif ($chunk =~ /^\[\[(.*?)\](.*?)\]$/os) {
			# elsif ($chunk =~ /^\[\[([a-zA-Z0-9\.\&\-\_\'\"\(\)\s]+)\](.*?)\]$/os) {
			
				my ($phrase,$operation) = ($1,$2);

				if ($operation eq '') { $operation = ':search='.$phrase; }
				my %pref = ();

				if ($operation =~ /\:url\=(.*?)$/o) {
					# dwiw: url links will often have ? and ='s in them so we handle them as one whole thing
					$operation = 'url';
					$pref{':url'} = $1;
					}
				elsif (index($operation,'&')>=0) {
					%pref = %{&ZTOOLKIT::parseparams($operation)};		# 3 seconds.
					$operation = lc(substr($operation,1,index($operation,'=')-1));	# operation :product=asdf should be just product
					}
				else {
					## single key=value so we can shortcut (to save time)
					my ($k,$v) = split(/=/o,$operation);
					if ($v !~ /%/o) {
						## if we don't have a %XX then we don't need to unescape, and that's expensive so we skip it.
						$pref{$k} = $v;
						}
					else {
						$pref{$k} = URI::Escape::XS::uri_unescape($v); # unescape %XY
						}
					$operation = lc(substr($k,1));	# was ':PRODUCT' now 'product'
					}

				# print "TEXT: $phrase OP:$operation\n";
				my $url = '';
				if (defined $SITE::URLS::WIKI_LINK_FUNCTIONS{$operation}) {
					$url = $SITE::URLS::WIKI_LINK_FUNCTIONS{$operation}->($self,$phrase,\%pref);
					}
				else {
					$url = "#unknown_wiki_link=$operation";
					}

				if (not defined $pref{'title'}) {
					$pref{'title'} = $phrase;
					}
				if (not defined $pref{'class'}) {
					$pref{'class'} = "wikilink wikilink_$operation";
					}
				if (defined $pref{':class'}) {
					## lets the user append their own class to a link.
					$pref{'class'} .= ' '.$pref{':class'};
					}

				my $attribs = '';
				foreach my $k (keys %pref) {
					next if (substr($k,0,1) eq ':');	# skip atrributes like :product
					# $attribs .= ' '.$k.'="'.&ZOOVY::incode($pref{$k}).'" ';
					if ($pref{$k} =~ /[\&\"\<\>]/o) {
						## if we need to incode, then encode
						$attribs .= ' '.$k.'="'.&ZOOVY::incode($pref{$k}).'" ';
						}
					else {
						$attribs .= ' '.$k.'="'.$pref{$k}.'" ';
						}
					}
				# push @chunks, [ 1, "<a $attribs href=\"$url\">$phrase</a>" ];
				$output .= "<a $attribs href=\"$url\">$phrase</a>";
				}
			else {
				# push @chunks, [ 0, $chunk ];
				$output .= $chunk;
				}
			}
		$text = $output;
		}

		#use Data::Dumper;
		#print Dumper(\@chunks);
		#die();

		#foreach my $chunk (split(/(\[\[.*?\].*?\])/so,$text)) {
		#	if ($chunk =~ /^(.*?)\[\[(.*?)\](.*?)\](.*?)$/gso) {
		#		my ($pretext,$text,$suffix,$posttext) = ($1,$2,$3,$4);
		#		# $output .= "pre[$pretext] txt[$text] suffx[$suffix] post[$posttext]<br><hr>";
		#		if ($suffix eq '') { $suffix = ':search='.$text; }
		#		my $pref = &ZTOOLKIT::parseparams($suffix);
		#		$suffix = lc(substr($suffix,1,index($suffix,'=')-1));	# takes :pid= 1234 to just "pid"
#
#				my $url = '';
#				my $attribs = '';
#				if ($suffix eq 'url') { 
#					$url = $pref->{':url'}; 
#					}
#				elsif ($suffix eq 'popup') { 
#					$attribs = " target=\"blank\" ";
#					$url = $pref->{':popup'}; 
#					}
#				else { 
#					$url = $SITE::URL->get($suffix); 
#					if ($suffix eq 'search') { 
#						foreach my $term (split(/[\s\t\n\r]+/,$pref->{':search'})) {
#							next if ($term eq '');
#							$url .= '/'.$term; 
#							}
#						}
#					elsif ($suffix eq 'product') { $url .= '/'.$pref->{':product'}; }
#					elsif ($suffix eq 'category') { $url .= '/'.$pref->{':category'}; }
#					}
#
#				$output .= "$pretext<a class=\"wikilink wikilink_$suffix\" $attribs href=\"$url\">$text</a>$posttext";
#				}
#			else {
#				$output .= "$chunk";
#				}
#			}
#		$text = $output;
#		}


#	return();

	my $output = '';
	my $lasttype = undef;
	my @SECTIONS = ();
	foreach my $line (split(/\n/o,$text)) {
		my $ch = substr($line,0,1);		

		## Tables
		if ($ch eq '|') {
			## | is a table
			if ($lasttype ne '|') { $output .= "%table%\n"; }
			$output .= "%tablerow%\n";
			my $i = 0;
			foreach my $col (split(/\|/o,$line)) {
				next if ($i++ == 0);	# skip the first column which is always empty!
				if (substr($col,0,1) eq '=') { $output .= "\t%tablehead%".substr($col,1)."%/tablehead%\n"; }
				else { $output .= "\t%tabledata%$col%/tabledata%\n"; }
				}
			$output .= "%/tablerow%\n"; $lasttype = '|';
			}
		elsif ($lasttype eq '|') {
			$output .= "%/table%\n";
			$lasttype = '';
			}

		## Bullet Lists
		if ($ch eq '*') {
			## * is a bullet
			if ($lasttype ne '*') { $output .= "%list%\n"; } 	# start the list
			$output .= "%listitem%".substr($line,1)."%/listitem%\n";
			$lasttype = '*';
			}
		elsif ($lasttype eq '*') {
			## if the last thing we had was a list, and this isn't, then we ought to end the list.
			$output .= "%/list%\n"; 		# end the list
			$lasttype = '';
			}

		## Other Text
		if ($lasttype eq '*') {}			# list handled earlier.
		elsif ($lasttype eq '\'') {}		# section handled earlier
		elsif ($lasttype eq '|') {}			# table handled earlier.
		elsif ($line =~ m/^([\=]+)[\s]*(.*?)[\s]*[\=]+$/) {	# copies [=]+ into $1 and the text into $2
			$ch = $1; 	# this could be = == or even ===	
			$line = $2;
			$output .= '%title'.length($ch).'%'.$line.'%/title'.length($ch)."%\n";
			$lasttype = $ch;
			}
		elsif (($ch eq '\'') && ($line =~ /([\']{2,5})(.*?)[\']+/)) {
			## SECTION APPROACH:
			##		if a one with more '''' is under a ''' then it ends, otherwise it just keeps going till the end
			my $txt = $2;
			my $len = length($1);
			my $class = '';

			if (scalar(@SECTIONS)>0) {
				## figure out if we're doing a subsection, or ending a section.
				my $lastsec = pop @SECTIONS;
				if ($lastsec->[0]>=$len) { 
					$output .= $lastsec->[3];
					}
				else {
					push @SECTIONS, $lastsec;
					}
				}

			if ($txt =~ /^([A-Z]+)\:(.*?)$/o) {
				## e.g. '''SAY:this stuff''' sets class to SAY
				($class,$txt)=($1,$2);
				}

			## so if %section_class% exists, we'll use that!
			my ($bsection,$esection) = ('%section%','%/section%');
			
			if (($class ne '') && (defined $varsref->{'%section_'.lc($class).'%'})) {
				($bsection,$esection) = ($varsref->{'%section_'.lc($class).'%'}, $varsref->{'%/section_'.lc($class).'%'});
				}

			my ($btitle,$etitle) = ('%title3%','%/title3%');
			if (defined $varsref->{"%title$len%"}) {
				($btitle,$etitle) = ($varsref->{"%title$len%"},$varsref->{"%/title$len%"});
				}
			$output .= "$bsection\n$btitle$txt$etitle\n";
			push @SECTIONS, [ $len, $txt, $class, $esection ];
			$lasttype = '';
			}
		elsif ($line eq '') {

			if ($lasttype eq "\n\n") {
				## we're already in a new section, so stay here!
				}
			elsif ($lasttype eq "\n") { 
				if ($hasSections>=0) {
					## when hasSections is -1
					$hasSections++;
					$output .= "%/section%\n%section%"; $lasttype = undef; 	# start a new section!
					$lasttype = "\n\n";
					}
				else {
					$output .= "%softbreak%";
					}
				}
			else {
				$lasttype = "\n"; 
				$output .= "%softbreak%\n";
				}
			}
		elsif (substr($line,0,4) eq '----') {
			$output .= "%hardbreak%"; $lasttype = '----';
			}
		else {
			$output .= $line."\n";
			$lasttype = undef;
			}

		}

	if ($lasttype eq '*') { $output .= "%/list%\n"; }
	if ($lasttype eq '|') { $output .= "%/table%\n"; }

	if ($hasSections>0) { 
		$output = "%section%$output%/section%"; 
		}

	foreach my $sec (@SECTIONS) {
		$output .= $sec->[3];  ## e.g. "%/section%";
		}


	$output =~ s/[\n]+$//gs;	# strip trailing hard returns (not necessary, break javascript)
	return($output);	
	}








1;
