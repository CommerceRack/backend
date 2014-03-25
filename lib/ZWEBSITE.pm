package ZWEBSITE;

use strict;
use YAML::Syck;
use JSON::XS;
use Storable;

##
## www-zephyrsports-com.zoovy.net to www.zephyrsports.com
##
sub checkout_domain_to_domain {
	my ($CDOMAIN) = @_;
	my $DOMAIN = undef;
	if ($CDOMAIN =~ /^([a-z0-9\-]+)\.app-hosted\.com$/) {
		$DOMAIN = $1;
		$DOMAIN =~ s/-/\./gs;
		$DOMAIN =~ s/\.\./-/gs;
		}
	return($DOMAIN);
	}

##
## www.zephyrsports.com to www-zephyrsports-com.zoovy.net
##
sub domain_to_checkout_domain {
	my ($DOMAIN) = @_;

	my $cdomain = lc($DOMAIN); 
	$cdomain =~ s/secure\./www\./gs;	## cheap hack! (keep until there are no more secure.domain.com's anymore
												## dns for secure.domain.com is very wonky!

	$cdomain =~ s/-/--/gs; $cdomain =~ s/\./-/gs;


	$cdomain = "$cdomain.app-hosted.com";
	return($cdomain);
	}

#
# global.bin settings:
#		%tuning
#			'auto_product_cache'=>1,
#			'allow_default_profile_overrides'=>1,	# turns on the ability to override the pricing schedule and root of the dfeault profile

#			'builder_show_all_navcats'=>1,		# show more than just root categories in website builder (when selecting root category on specialty)
#			'inhibit_image_nukes'=>1		# prevents removing of images from users account
#			'images_v'=>0		# image databsae version (resets url for resized images)
#			'large_navcats'=>0	# causes db updates to navcats instead of direct disk writes.
#			'disable_cacheable'=>1	# turns off all cacheable features
#			'disable_sessions'=>1	# turns off session id's on a site
#	
#	 %elastic
#		index_navcats
#


use lib "/backend/lib";
require ZOOVY;
require ZWEBSITE;
use DBI;
use Storable;
use Data::GUID;
use strict;

%ZWEBSITE::CACHE = ();

#
# WebDb Variables:
#		upic	= 0/1 for if UPIC is active on this partition.
#
## @CHECKFIELD - fields that must be checked during checkout			
## @SHIPPING - flexmethods
## @SITEMSGS - site messages array

#
# global variables:
#	%tuning
#		auto_nuke_product_cache -- disables nuking of ~/cache-products-by-name
#		allow_default_profile_overrides -- some behaviors (schedule/rootcat) for default can't be overridden unless this is set.
#	csv_fields => LEGACY no longer used.
#	img_version=>## which image version # we're on (for flushing cache)


sub init {
	}

# these two make peristent copies of the data, handy if we do lots of attribute reads


## a shortcut to get a list of partitions for a user
sub prts {
	my ($USERNAME) = @_;
	return(@{ZWEBSITE::list_partitions($USERNAME,output=>'prtonly')});
	}

sub fetch_website_db {
	my ($USERNAME,$PRT) = @_;
	return(%{&fetch_website_dbref($USERNAME,$PRT)});
}


##
## 
##
%ZWEBSITE::GLOBAL_DEFAULTS = (
	## becomes $gref->{'%ebay'}->{'default_new'}
	'ebay.default_new'=>1,			# don't require prod_condition to be set (assume it's new)
	'tuning.images_v'=>0,
	'tuning.disable_memcache'=>0,	# set to 1 to disable memcache for a client.
	);


##
## initializes global defaults for services that use them.
##
sub global_init_defaults {
	my ($gref) = @_;

	foreach my $k (keys %ZWEBSITE::GLOBAL_DEFAULTS) {
		my ($x,$y) = split(/\./,$k,2);
		next if (defined $gref->{"%$x"}->{$y});
		$gref->{"%$x"}->{$y} = $ZWEBSITE::GLOBAL_DEFAULTS{$k};
		}
	}

##
##
sub globalfetch_attrib {
	my ($USERNAME,$attrib) = @_;
	
	my ($globalref) = &ZWEBSITE::fetch_globalref($USERNAME);
	return($globalref->{$attrib});
	}

##
##
##
sub globalset_attribs {
	my ($USERNAME,%options) = @_;

	my $changed++;
	my ($globalref) = &ZWEBSITE::fetch_globalref($USERNAME);
	foreach my $k (keys %options) {
		next if ($globalref->{$k} eq $options{$k});
		$globalref->{$k} = $options{$k};
		$changed++;
		}

	if ($changed) {
		&ZWEBSITE::save_globalref($USERNAME,$globalref);
		}
	return($changed);
	}




sub prt_get_profile {
	my ($USERNAME,$PRT) = @_;

	$PRT = int($PRT);
	my $PROFILE = undef;

	my ($globalref) = &ZWEBSITE::fetch_globalref($USERNAME);
	if ($PRT == 0) { 
		$PROFILE = 'DEFAULT'; 
		}
	elsif (not defined $globalref) {
		warn "$USERNAME globalref not set\n";
		}
	elsif (not defined $globalref->{'@partitions'}) {
		warn "$USERNAME globalref->\@partitions not set\n";
		}
	elsif (not defined $globalref->{'@partitions'}->[$PRT]) {
		warn "$USERNAME globalref->\@partitions->[$PRT] did not exist\n";
		}
	elsif (ref($globalref->{'@partitions'}->[$PRT]) ne 'HASH') {
		}
	else {
		$PROFILE = $globalref->{'@partitions'}->[$PRT]->{'profile'};
		}

	if (($PRT>0) && ($PROFILE eq '')) { 
		## oh shit.
		$PROFILE = '**ERR'.time();
		}

	return($PROFILE);
	}


##
## 
##
sub webdb_cache_file {
	my ($USERNAME,$PRT) = @_;
	return(&ZOOVY::cachefile($USERNAME,"webdb-$PRT.bin"));
	}

## this is for validating fields in the order e.g. banning by ip, etc.
sub checkfield_add {
	my ($USERNAME,$PRT,$ref) = @_;

	my ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	if (not defined $webdbref->{'@CHECKFIELD'}) {
		$webdbref->{'@CHECKFIELD'} = [];
		}
	if (not defined $ref->{'id'}) { $ref->{'id'} = 'ERR_'.time(); }

	my $ID = $ref->{'id'};
	my $count = scalar(@{$webdbref->{'@CHECKFIELD'}});
	my $i = 0;
	while ($i < $count) {
		if ($webdbref->{'@CHECKFIELD'}->[$i]->{'id'} eq $ID) {
			$webdbref->{'@CHECKFIELD'}->[$i] = $ref;
			$i = $count;	## get us out of the loop, but it also means we don't add another one.
			}
		$i++;					## this must stay at the bottom of the loop!
		}
	if ($i == $count) {
		## we did not find this, so we add it to the bottom!
		push @{$webdbref->{'@CHECKFIELD'}}, $ref;
		}


	&ZWEBSITE::save_website_dbref($USERNAME,$webdbref,$PRT);
	return();
	}



#sub checkout_profile {
#	my ($USERNAME,$PRT) = @_;
#	my $PROFILE = undef;
#	my ($dbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
#	if ($PRT==0) { 
#		$PROFILE = 'DEFAULT'; 
#		}
#	elsif ($dbref->{'profile'} eq '') { 
#		$PROFILE = 'DEFAULT'; 
#		}
#	else {
#		$PROFILE = $dbref->{'profile'};
#		}
#	return($PROFILE);
#	}


##########################################################
##
##
## @shipping = [
##		{ 
##			id=>"SIMPLE_US_1"	 ## unique identifier for this shipping method. (partition wide)
##			country=>"US",	  ##  US, CA, UK, etc.
##			handler=>"",  	  ##  SIMPLE, FIXED, LOCAL, WEIGHT, PRICE
##			carrier=>"",	  ##  carrier code e.g. FDX
##			expedited=>1|0, 
##			ruleset=>"",	  ##  CODE
##		},
##		]
##
sub ship_add_method {
	my ($USERNAME,$PRT,$ref) = @_;
		
	my ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	if (not defined $webdbref->{'@SHIPPING'}) {
		$webdbref->{'@SHIPPING'} = [];
		}
	if (not defined $ref->{'id'}) { $ref->{'id'} = 'ERR_'.time(); }

	my $ID = $ref->{'id'};
	my $count = scalar(@{$webdbref->{'@SHIPPING'}});
	my $i = 0;
	while ($i < $count) {
		if ($webdbref->{'@SHIPPING'}->[$i]->{'id'} eq $ID) {
			$webdbref->{'@SHIPPING'}->[$i] = $ref;
			$i = $count;	## get us out of the loop, but it also means we don't add another one.
			}
		$i++;					## this must stay at the bottom of the loop!
		}
	if ($i == $count) {
		## we did not find this, so we add it to the bottom!
		push @{$webdbref->{'@SHIPPING'}}, $ref;
		}


	&ZWEBSITE::save_website_dbref($USERNAME,$webdbref,$PRT);
	return();
	}

##
## deletes a specific method, keyed by ID
##
sub ship_del_method {
	my ($USERNAME,$PRT,$ID) = @_;

	my ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	if (not defined $webdbref->{'@SHIPPING'}) { return([]); }
	
	my $found = -1;
	my $count = scalar(@{$webdbref->{'@SHIPPING'}});
	my $i = 0;
	while ( $i < $count ) {
		if ($webdbref->{'@SHIPPING'}->[$i]->{'id'} eq $ID) { 
			$found = $i;
			$i = $count; 	#short circuit loop
			}
		$i++;
		}
	
	## remember -1 is not found!
	if ($found>=0) {
		my @ar = @{$webdbref->{'@SHIPPING'}};
		splice(@ar,$found,1);
		$webdbref->{'@SHIPPING'} = \@ar;
		&ZWEBSITE::save_website_dbref($USERNAME,$webdbref,$PRT);
		}
	return($found);
	}


sub ship_get_method {
	my ($USERNAME,$PRT,$ID) = @_;

	my ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	if (not defined $webdbref->{'@SHIPPING'}) { return(undef); }
	my $ref = undef;	

	my $count = scalar(@{$webdbref->{'@SHIPPING'}});
	my $i = 0;
	while ( $i < $count ) {
		# print STDERR "ID: $webdbref->{'@SHIPPING'}->[$i]->{'id'} vs $ID  ($i < $count)\n";
		if ($webdbref->{'@SHIPPING'}->[$i]->{'id'} eq $ID) { 
			$ref = $webdbref->{'@SHIPPING'}->[$i];
			$i = $count; 	#short circuit loop
			}
		$i++;
		}

#	use Data::Dumper;
#	print STDERR "GET: ".Dumper($ref);

	return($ref);
	}


##
## returns an arrayref of shipping methods.
##
##	pass prt, or webdb
##
sub ship_methods {
	my ($USERNAME,%options) = @_;

	my $webdbref = $options{'webdb'};
	if (not defined $webdbref) { ($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$options{'prt'}); }
	if (not defined $webdbref->{'@SHIPPING'}) { $webdbref->{'@SHIPPING'} = []; }
	return( $webdbref->{'@SHIPPING'} );
	}


##
##
##
sub prtinfo {
	my ($USERNAME,$PRT) = @_;

	my ($ref) = &ZWEBSITE::fetch_globalref($USERNAME);

	my $prtinfo = $ref->{'@partitions'}->[int($PRT)];

	if (not defined $prtinfo->{'profile'}) {
		## use the default profile unless otherwise specified
		$prtinfo->{'profile'} = 'DEFAULT';
		}
	if (not defined $prtinfo->{'currency'}) {
		## make sure we've got USD set as a currency.
		$prtinfo->{'currency'} = 'USD';
		}
	if (not defined $prtinfo->{'language'}) {
		## make sure we've got ENGLISH
		$prtinfo->{'language'} = 'ENG';
		}
	if (not defined $prtinfo->{'p_navcats'}) {
		## make sure we've got ENGLISH
		$prtinfo->{'p_navcats'} = 0;
		}
	return($prtinfo);
	}

##
##
##
sub prtsave {
	my ($USERNAME,$PRT,$prtinfo) = @_;

	my ($ref) = &ZWEBSITE::fetch_globalref($USERNAME);
	$ref->{'@partitions'}->[int($PRT)] = $prtinfo;
	&ZWEBSITE::save_globalref($USERNAME,$ref);

	return();
	}


##
## event has:
##		type=>'product.save'
##		if=>eval statement
##		then=>execute statement
##		note
##
#sub add_event {
#	my ($USERNAME,$event) = @_;
#	my $type = $event->{'type'};
#	delete $event->{'type'};	## this is redundant.
#	if (not defined $event->{'id'}) {
#		$event->{'id'} = Data::GUID->new()->as_string();
#		}
#	my ($ref) = &ZWEBSITE::fetch_globalref($USERNAME);
#	if (not defined $ref->{'%events'}) { $ref->{'%events'} = {}; }
#	if (not defined $ref->{'%events'}->{ $type }) { $ref->{'%events'}->{ $type } = []; }
#	push @{$ref->{'%events'}->{$type}}, $event;	
#	&ZWEBSITE::save_globalref($USERNAME,$ref);
#	}

##
## note: this returns *ALL* events for a given event type (the entire array)
##		this returns a reference to gref, not a copy, so be careful. if you intend to jack up data then
##		make your own copy.
##
#sub get_events {
#	my ($USERNAME,$type) = @_;
#	my ($ref) = &ZWEBSITE::fetch_globalref($USERNAME);
#	if (not defined $ref->{'%events'}) { $ref->{'%events'} = {}; }
#	if (not defined $ref->{'%events'}->{ $type }) { $ref->{'%events'}->{ $type } = []; }
#	return($ref->{'%events'}->{ $type });	
#	}



##
##
##
sub fetch_globalref {
	my ($USERNAME,$cache) = @_;

	my $file = undef;
	my $ref = undef;

	my $memd = undef;
	my $MEMKEY = lc("$USERNAME:global.yaml");

	if (defined $ref) {
		}
	else {
		$memd = &ZOOVY::getMemd($USERNAME);
		if (defined $memd) {
			my $yaml = $memd->get($MEMKEY);
			if ($yaml ne '') { 
				$ref = YAML::Syck::Load($yaml);
				## warn "Loaded global/yaml from memcache\n";
				}
			}
		}

	if (defined $ref) {
		}
	else {
		my $file = &ZOOVY::resolve_userpath($USERNAME).'/global.bin'; 
		$ref = eval { retrieve($file); };

		#if (not defined $ref) {
		#	&ZOOVY::confess($USERNAME,"i might reset global.bin since it was corrupt",justkidding=>1);
		#	sleep(1);
		#	$ref = eval { retrieve($file); };
		#	}

		#if (not defined $ref) {
		#	&ZOOVY::confess($USERNAME,"i'd like to reset global.bin since it was corrupt",justkidding=>1);
		#	sleep(5);
		#	$ref = eval { retrieve($file); };
		#	}
		if ((not defined $ref) && (not -f &ZOOVY::resolve_userpath($USERNAME))) {
			$ref = undef;
			}
		elsif (not defined $ref) {
			rename("$file","$file.$$");
			$ref = undef;
			&ZOOVY::confess($USERNAME,"okay, i reset global.bin since it was corrupt",justkidding=>1);
			}

		if ((defined $memd) && (defined $ref)) {
			$memd->set($MEMKEY,YAML::Syck::Dump($ref),86400);
			## warn "set!\n";
			}
		}
	
	if (not defined $ref) {
		## RESET
		$ref = {};
		$ref->{'@partitions'} = [ { name=>"DEFAULT" } ];
		if (defined $memd) {
			$memd->set($MEMKEY,YAML::Syck::Dump($ref),60*5);
			}
		}

	if (ref($ref) eq '') { $ref = undef; }
	return($ref);	
	}


##
## returns an arrayref of partition codes 
##		NOTE: this is *guaranteed* to always have one entry!
## filters:
##		has_navcats=>1  -- has unique navcats
##		has_customers=>1 -- has customers.
##		customer_prt=>1  -- has customers on partition #
##		output=>'prtonly' -- outputs the prt # only.
##		output=>'pretty' -- outputs "prt#: prt id"
##
sub list_partitions {
	my ($USERNAME, %filter) = @_;

	if (not defined $filter{'output'}) { $filter{'output'} = 'pretty'; }

	my $ref = &ZWEBSITE::fetch_globalref($USERNAME);
	my @prts = ();
	my $count = -1;
	foreach my $prtref (@{$ref->{'@partitions'}}) {
		++$count;
		my $skip = 0;

		if ((defined $filter{'has_navcats'}) && ($prtref->{'p_navcats'}!=$count)) { $skip++; }
		if ((defined $filter{'has_customers'}) && ($prtref->{'p_customers'}!=$count)) { $skip++; }
		if ((defined $filter{'has_giftcards'}) && ($prtref->{'p_giftcards'}!=$count)) { $skip++; }
		if (defined $filter{'prt_customer'}) {
			## only return partitions which match our p_customer setting.
			if ($filter{'prt_customer'} != $prtref->{'p_customers'}) { $skip++; }
			}
		next if ($skip);

		if ($filter{'output'} eq 'pretty') {
			push @prts, "$count: $prtref->{'name'}";
			}
		elsif ($filter{'output'} eq 'prtonly') {
			push @prts, $count;
			}
		else {
			push @prts, "unknown filter/output: $filter{'output'}";
			}
		}
	return(\@prts);
	}

##
## 
##
sub save_globalref {
	my ($USERNAME,$ref) = @_;
	my $file = &ZOOVY::resolve_userpath($USERNAME).'/global.bin';

#	delete $ref->{'__FLUSH__'};	## don't save this, it's just a placeholder.
#	open F, ">>/tmp/global.log";
#	print F sprintf("%d\t%s\t%s\n",time(),$USERNAME,$file);
#	close F;

	my $MEMKEY = lc("$USERNAME:global.yaml");
	Storable::nstore $ref, "$file.$$";
	chmod(0666, "$file.$$");
	rename("$file.$$","$file");
	
	my $memd = &ZOOVY::getMemd($USERNAME);
	if (defined $memd) {
		$memd->set($MEMKEY,YAML::Syck::Dump($ref));
		}

	return($ref);
	}


## 
## ZWEBSITE::fetch_website_dbref
## Stub function: we'll speed this up later
## possibly even make website_db call this
## isn't it about fucking time?? 
##
##	PRT is "partition" 
##
sub fetch_website_dbref {
	my ($USERNAME,$PRT,$cache) = @_;	

	# print STDERR "Doing Change stuff!\n";
	if (not defined $cache) { $cache = 0; }
	if (not defined $PRT) { $PRT = 0; } else { $PRT = int($PRT); }
	if ((not defined $USERNAME) || ($USERNAME eq '')) {
		print STDERR "Warning blank or undefined username for webdb!\n";
		return();
		}


	my $WEBDBREF = undef;
	my $USERPATH = &ZOOVY::resolve_userpath($USERNAME);
	my $file = sprintf("%s/webdb-%d.json",$USERPATH,$PRT);
	my $cachefile = &ZWEBSITE::webdb_cache_file($USERNAME,$PRT);

	my $MEMCACHE_KEY = lc("webdb-ts|$USERNAME.$PRT");
	my $memd = &ZOOVY::getMemd($USERNAME);

	if (my $jsonts = $memd->get($MEMCACHE_KEY)) {
		if (defined $ZWEBSITE::CACHE{ "$USERNAME.$PRT.$jsonts" }) {
			$WEBDBREF = $ZWEBSITE::CACHE{ "$USERNAME.$PRT.$jsonts" };
			}

		if (not defined $WEBDBREF) {
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($cachefile);
			if ($ctime > $jsonts) {
				# print STDERR "USE CACHE ($ctime > $jsonts) ".($ctime-$jsonts)."\n";
				$ZWEBSITE::CACHE{ "$USERNAME.$PRT.$jsonts" } = $WEBDBREF = Storable::retrieve($cachefile);
				}
			else {
				unlink $cachefile;
				}
			}
		}

	if (defined $WEBDBREF) {
		}
	elsif (! -f $file) {
		my $oldfile = undef;
		if ($PRT==0) {
			$oldfile = &ZOOVY::resolve_userpath($USERNAME).'/webdb.bin';
			}
		else {
			$oldfile = &ZOOVY::resolve_userpath($USERNAME).'/webdb-'.$PRT.'.bin';
			}
		if (-f $oldfile) { $WEBDBREF = Storable::retrieve($oldfile); }
		if (not defined $WEBDBREF) { $WEBDBREF = {}; }
		open F, ">$file";		
		print F JSON::XS->new->allow_nonref->encode($WEBDBREF);
		close F;
		chmod 0666, $file;
		}




	#if ($cache>0) {	
	#	my $cfile = &ZWEBSITE::webdb_cache_file($USERNAME,$PRT);
	#	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($cfile);
	#	if ($mtime > $cache) {
	#		$file = $cfile;
	#		}		
	#	else {
	#		$cache = 1;
	#		}
	#	}
	#$SITE::DEBUG && print STDERR "fetch_website_dbref path: $file\n";

	if (not defined $file) {
		}
	elsif (defined $WEBDBREF) {
		}
	elsif (-f $file) {

	#	if ($cache==1) {
	#		my $cfile = &ZWEBSITE::webdb_cache_file($USERNAME,$PRT);
	#		Storable::nstore $WEBDBREF, $cfile;
	#		chmod 0666, $cfile;
	#		if ($< != $ZOOVY::EUID) { chown $ZOOVY::EUID,$ZOOVY::EGID, $cfile; }
	#		}

	#	}
	#else {
	#	warn "Could not load webdb for user  [$USERNAME]$file";
	#	$ZWEBSITE::WEBDBUSER = $USERNAME;
	#	$WEBDBREF = {};	
	#	$ZWEBSITE::WEBDBPRT = -1;
	#	}
		my $json = '';
		open F, "<$file"; $/ = undef; while (<F>) { $json = $_; } $/ = "\n"; close F;
		$WEBDBREF = JSON::XS::decode_json($json);

		Storable::nstore $WEBDBREF, $cachefile;
		chmod 0666, $cachefile;
		if (-f $file) {
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
			$memd->set($MEMCACHE_KEY,$ctime);
			}
		}



	if (not defined $WEBDBREF->{'v'}) { $WEBDBREF->{'v'} = 0; }
	if ($WEBDBREF->{'v'}==0) {
		## 
		if (not defined $WEBDBREF->{'cc_processor'}) {
			}
		elsif ($WEBDBREF->{'cc_processor'} eq 'PAYPALVT') { 
			## renamed this value.
			$WEBDBREF->{'cc_processor'} = 'PAYPALWP'; 
			}

		my %DESTINATIONBITS = (
			'NO'=>0,
			'NONE'=>0,
			'DOMESTIC'=>1,
			'ALL51'=>3,
			'INT_HIGH'=>1+2+4+8,
			'INT_LOW'=>1+2+4,
			);

		foreach my $f ('pay_google','pay_credit','pay_echeck','pay_paypal','pay_paypalec','pay_giftcard',
						'pay_chkod','pay_mo','pay_cash','pay_pickup','pay_check','pay_po','pay_wire',
						'pay_amzspay','pay_custom','pay_cod') {
			if (defined $WEBDBREF->{$f}) {
				if ($WEBDBREF->{$f} eq 'NO') {
					$WEBDBREF->{$f} = 0;
					}
				#elsif (int($WEBDBREF->{$f}) > 0) {
				#	## already converted
				#	}
				elsif (defined $DESTINATIONBITS{$WEBDBREF->{$f}}) {
					## cache
#					print STDERR "$f|$WEBDBREF->{$f}|$DESTINATIONBITS{$WEBDBREF->{$f}}\n";
					$WEBDBREF->{$f} = $DESTINATIONBITS{$WEBDBREF->{$f}};
					}
				}
			}
		$WEBDBREF->{'v'} = 1;
		}

	if ($WEBDBREF->{'v'}==1) {
		#<u>Account Creation:</u><br>
		#<input type='radio' name='customer_management' <!-- CM_DEFAULT --> value='DEFAULT'><b>Default:</b> Require customers to use/create accounts, require existing customers to login.<br>
		#<input type='radio' name='customer_management' <!-- CM_NICE --> value='NICE'><b>Nice:</b> Prompt customers to use/create accounts, but always let them purchase, even without logging into their account.<br>
		#<input type='radio' name='customer_management' <!-- CM_STRICT --> value='STRICT'><b>Strict:</b> Prompt customers to use/create accounts, and require a customer to login if they have an account.<br>
		#<input type='radio' name='customer_management' <!-- CM_PASSIVE --> value='PASSIVE'><b>Passive:</b> Never ask customers to create an account, let Zoovy automatically correlate multiple sales by the same customer.<br>
		#<input type='radio' name='customer_management' <!-- CM_DISABLED --> value='DISABLED'><b>Disabled:</b> Turn off all customer management and tracking.<br>
		#<input type='radio' name='customer_management' <!-- CM_MEMBER --> value='MEMBER'><b>Members Only:</b> Allow anybody to browse site, but do NOT allow new customers to create an account, or make a purchase (customers must have an account on record to purchase).<br>
		#<input type='radio' name='customer_management' <!-- CM_PRIVATE --> value='PRIVATE'><b>Private:</b> REQUIRE customer to login before they can access site, do NOT allow new customers to create an account, or make a purchase.<br>
		#<div class="hint">
		#HINT: If you configure customer accounts to either optional or disabled, you should immediately edit your "order created message"
		#so it does not invite the customer to login and view order status. To edit the default order created message go to Setup | Email Messages, and
		#edit the "Order Created" message.
		#</div>
		#if ($WEBDBREF->{'customer_management'} eq '') {
		#	}
		#elsif ($WEBDBREF->{'customer_management'} eq 'DEFAULT') {
		#	$WEBDBREF->{'site_private'} = 0;		# private sites require login
		#	$WEBDBREF->{'site_customer_accounts'} = 1;
		#	$WEBDBREF->{'site_passive_accounts'} = 0;
		#	}
		#elsif ($WEBDBREF->{'customer_management'} eq 'PASSIVE') {
		#	$WEBDBREF->{'site_private'} = 0;	
		#	$WEBDBREF->{'site_customer_accounts'} = 1;
		#	$WEBDBREF->{'site_passive_accounts'} = 1;
		#	}
		#elsif ($WEBDBREF->{'customer_management'} eq 'NICE') {
		#	$WEBDBREF->{'site_private'} = 0;	
		#	$WEBDBREF->{'site_customer_accounts'} = 1;
		#	$WEBDBREF->{'site_passive_accounts'} = 1;
		#	$WEBDBREF->{'site_checkout_login'} = 1;
		#	}
		#elsif ($WEBDBREF->{'customer_management'} eq 'DISABLED') {
		#	$WEBDBREF->{'site_private'} = 0;	
		#	$WEBDBREF->{'site_customer_accounts'} = 0;
		#	$WEBDBREF->{'site_passive_accounts'} = 0;
		#	}
		#elsif ($WEBDBREF->{'customer_management'} eq 'MEMBER') {
		#	$WEBDBREF->{'site_private'} = 0;	
		#	$WEBDBREF->{'site_customer_accounts'} = 0;
		#	$WEBDBREF->{'site_passive_accounts'} = 0;
		#	}
		#elsif ($WEBDBREF->{'customer_management'} eq 'PRIVATE') {
		#	$WEBDBREF->{'site_private'} = 1;	
		#	$WEBDBREF->{'site_customer_accounts'} = 1;
		#	$WEBDBREF->{'site_passive_accounts'} = 0;
		#	}
		# $WEBDBREF->{'v'} = 2;
		}


	## disable google
	# $WEBDBREF->{'google_api_env'} = 0; 
	return $WEBDBREF;
	}


##############################################################################
##
##
## makes sure we can substitute http with https before we output.
##
#sub nice_url_handler {
#
#	my ($URL) = @_;
#	if (length($URL)<10) {
#		$URL = "/images/image_blank.gif";
#		}
#	else  {
#		$URL =~ s/http\:\/\/static.zoovy.com/https\:\/\/static.zoovy.com/i;
#		}
#
#	return($URL);
#}

##############################################################################
##
## ZWEBSITE::fetch_website_attrib
## parameters: $USERNAME, $ATTRIBUTE
##
## returns: $VALUE
##
sub fetch_website_attrib
{

	my ($USERNAME, $KEY) = @_;
	
	if (!$USERNAME) { return(1); }
	# check the peristent copy
	#if (defined($ZWEBSITE::WEBDBUSER) && ($ZWEBSITE::WEBDBUSER eq $USERNAME)) {
	#	return($ZWEBSITE::WEBDBCACHE->{$KEY});
	#	} 
	
	my $webdbref = &fetch_website_dbref($USERNAME);
	return($webdbref->{$KEY});
	}



##############################################################################
##
## ZWEBSITE::save_website_attrib
## parameters: $USERNAME, $WEBSITE_ATTRIBUTE, $NEW_VALUE
##
## returns: 0 on success, 1 on failure.
##
sub save_website_attrib {
	my ($USERNAME, $KEY, $VALUE) = @_;
	
	if (!$USERNAME) { return(1); }
	my $webdbref = &fetch_website_dbref($USERNAME,0);

	if ((defined $webdbref->{$KEY}) && ($webdbref->{$KEY} eq $VALUE)) {
		## don't do anything since the values are the same!
		}
	else {
		$webdbref->{$KEY} = $VALUE;
		&save_website_dbref($USERNAME,$webdbref,0);
		}
	return(0);
	}

##
##
##
sub save_website_dbref {
	my ($USERNAME, $WEBDBREF, $PRT) = @_;

	if (not defined $PRT) { 
		die("No longer allowed to call save_website_dbref without partition");
		}

	#my $file = '';
	#if ($PRT==0) {
	#	$file = &ZOOVY::resolve_userpath($USERNAME).'/webdb.bin';
	#	}
	#else {
	#	$file = &ZOOVY::resolve_userpath($USERNAME).'/webdb-'.$PRT.'.bin';		
	#	}
	#my $path = &ZOOVY::resolve_userpath($USERNAME);
	#if (-d $path) {
	#	Storable::nstore $ZWEBSITE::WEBDBCACHE, $file;
	#	chmod(0666, $file);
	#	&ZOOVY::touched($USERNAME,1);
	#	}
	my $USERPATH = &ZOOVY::resolve_userpath($USERNAME);
	my $file = sprintf("%s/webdb-%d.json",$USERPATH,$PRT);
	if (not defined $WEBDBREF) { $WEBDBREF = {}; }
	open F, ">$file";		
	print F JSON::XS->new->allow_nonref->encode($WEBDBREF);
	close F;
	chmod(0666, $file);
	&ZOOVY::touched($USERNAME,1);

	## VERY IMPORTANT!
	my $MEMCACHE_KEY = lc("webdb-ts|$USERNAME.$PRT");
	my $memd = &ZOOVY::getMemd($USERNAME);
	$memd->delete($MEMCACHE_KEY);
	%ZWEBSITE::CACHE = ();
	return(0);
}

##############################################################################
##
## ZWEBSITE::save_website_db
## parameters: $USERNAME, $HASH_PTR
##
## returns: 0 on success, 1 on failure.											  
##
## note: try to avoid using this, its better to save each attribute				  
##       using the save_website_attrib (unless you fetched the entire			  
##
sub save_website_db {
	my ($USERNAME,$AR) = @_;
	return(&save_website_dbref($USERNAME,$AR));	
	}





1;

