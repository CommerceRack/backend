package ZSHIP::FEDEXWS;

use encoding 'utf8';		## tells us to internally use utf8 for all encoding
use locale;  
use utf8 qw();
use Encode qw();

use strict;

#  perl -e 'use lib "/backend/lib"; use ZSHIP::FEDEXWS; ZSHIP::FEDEXWS::doRequest("brian","RegisterWebCspUserRequest");'
use XML::SAX qw();
use Data::Dumper;
use XML::Simple qw();
use XML::SAX::Simple qw();
use XML::Writer qw();
use IO::String;
use Digest::MD5 qw();
use LWP::UserAgent qw(); 
use HTTP::Headers qw();
use HTTP::Request qw();

use lib "/backend/lib";
require ZWEBSITE;
require ZTOOLKIT;
require ZTOOLKIT::XMLUTIL;
require CFG;



sub load_supplier_fedexws_cfg {
	my ($USERNAME,$SUPPLIER,$S) = @_;

	require SUPPLIER;
	if (not defined $S) {
		($S) = SUPPLIER->new($USERNAME,$SUPPLIER);
		}
	
	my %cfg = ();

	if (not defined $S) {
		## hmm.. error?
		}
	elsif ($S->get('.ship.meter') eq '') {
		# type=FEDEX&meter=6083299&account_number=449274946
		}
	else {
		%cfg = %{ &ZTOOLKIT::parseparams( $S->get('.ship.fedex') ) };
		$cfg{'type'} = 'FEDEX';		
		}

	## these origin zip origin state are configured in the u/i
	$cfg{'origin.zip'} = $S->fetch_property('.ship.origzip');
	$cfg{'origin.state'} = $S->fetch_property('.ship.origstate');
	$cfg{'origin.country'} = 'US';
	$cfg{'dom.ground'} = 1;
	$cfg{'int.ground'} = 1;
	$cfg{'src'} = sprintf("%s/SUPPLIER/%s",$USERNAME,$SUPPLIER);

	return(\%cfg);
	}


sub save_supplier_fedexws_cfg {
	my ($USERNAME,$SUPPLIER,$cfgref) = @_;

	require SUPPLIER;
	my ($S) = SUPPLIER->new($USERNAME,$SUPPLIER);
	
	$cfgref->{'src'} = sprintf("%s/SUPPLIER/%s",$USERNAME,$SUPPLIER);

	if (not defined $S) {
		## hmm.. error?
		}
	else {
		# type=FEDEX&meter=6083299&account_number=449274946
		$S->set('.ship.meter_createdgmt',time());
		$S->set('.ship.meter',sprintf("type=FEDEX&meter=%s&account_number=%s",$cfgref->{'meter'},$cfgref->{'account'}));
		$S->set('.ship.fedex',&ZTOOLKIT::buildparams($cfgref));
		$S->save();
		}

	return($cfgref);
	}



##
## note: always load the fedex configuration from here.
##
sub load_webdb_fedexws_cfg {
	my ($USERNAME,$PRT,$webdb) = @_;

	if (not defined $webdb) { $webdb = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT); }

	my $fdxcfg = {};
	if (defined $webdb->{'fedexws_cfg'}) {
		# print STDERR "WSCFG: $webdb->{'fedexws_cfg'}\n"; die();
		$fdxcfg = &ZTOOLKIT::parseparams($webdb->{'fedexws_cfg'});
		}
	elsif ($webdb->{'fedexapi_meter'}>0) {
		$fdxcfg = &legacy_webdb_to_fedexcfg($webdb);
		$webdb->{'fedexws_cfg'} = &ZTOOLKIT::buildparams($fdxcfg);
		# die();
		# &ZSHIP::FEDEXWS::save_webdb_fedexws_cfg($USERNAME,$PRT,$fdxcfg);
		}
	else {
		$fdxcfg->{'enabled'} = 0;
		}
	$fdxcfg->{'src'} = sprintf("%s/WEBDB/#%d",$USERNAME,$PRT);

	return($fdxcfg);
	}


##
## just a stub function
##
sub save_webdb_fedexws_cfg {
	my ($USERNAME,$PRT,$cfgref,$webdbref) = @_;

	$cfgref->{'src'} = sprintf("$USERNAME/WEBDB/#%d",$PRT);

	if (not defined $webdbref) {
		($webdbref) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
		}
	$webdbref->{'fedexws_cfg'} = &ZTOOLKIT::buildparams($cfgref);
	&ZWEBSITE::save_website_dbref($USERNAME,$webdbref,$PRT);
	return();
	}


##
##
sub legacy_webdb_to_fedexcfg {
	my ($webdb) = @_;

	# print Dumper($webdb);

 	my %cfg = ();

	$cfg{'legacy.int_pkg'} = $webdb->{'fedexapi_int_packaging'}; #  '01',
	delete $webdb->{'fedexapi_int_packaging'};
	#fedexapi_int_packaging
	#	01 - Other packaging
	#	02 - FedEx Pak
	#	03 - FedEx Box
	#	04 - FedEx Tube
	#	06 - FedEx Envelope
	#	15 - FedEx 10kg Box (International only)
	#	25 - FedEx 25kg Box (International only)
	$cfg{'enabled'} = int(($webdb->{'fedexapi_int'}?2:0) + ($webdb->{'fedexapi_dom'}?1:0));

	$cfg{'rates'} = ($webdb->{'fedexapi_rate'}==2)?'retail':'actual'; #  '2',
	delete $webdb->{'fedexapi_rate'};
	$cfg{'account'} = $webdb->{'fedexapi_account'}; #  '103297532',
	delete $webdb->{'fedexapi_account'};
	$cfg{'meter'} = $webdb->{'fedexapi_meter'}; #  '3448683',
	delete $webdb->{'fedexapi_meter'};
	$cfg{'legacy.fedexapi_int'} = $webdb->{'fedexapi_int'}; #  0,
	$cfg{'int.ground'} = (($webdb->{'fedexapi_int'} & 2)==2)?1:0;
	$cfg{'int.2day'} = (($webdb->{'fedexapi_int'} & 4)==4)?1:0;
	$cfg{'int.nextnoon'} = (($webdb->{'fedexapi_int'} & 8)==8)?1:0;
	$cfg{'int.nextearly'} = (($webdb->{'fedexapi_int'} & 16)==16)?1:0;
	delete $webdb->{'fedexapi_int'};
	#%ZSHIP::FEDEXAPI::INT_METHODS = (
#	2  => 'ground',    # fedex code 92 - FedEx Ground Service
#	4  => '2day',      # fedex code 03 - FedEx International Economy
#	8  => 'nextnoon',  # fedex code 01 - FedEx International Priority
#	16 => 'nextearly', # fedex code 06 - FedEx International First
#);

	$cfg{'is_multibox'} = (($webdb->{'fedexapi_options'} & 4)==4)?1:0; #  8,		## removed in current u/i
	$cfg{'is_residential'} = (($webdb->{'fedexapi_options'} & 8)==8)?1:0; #  8,	## removed in current u/i
	$cfg{'is_homesignature'} = (($webdb->{'fedexapi_options'} & 16)==16)?1:0; #  8,	## removed in current u/i
	delete $webdb->{'fedexapi_options'};
	$cfg{'dom.ground'} = (($webdb->{'fedexapi_dom'} & 2)==2)?1:0; #  254,
	$cfg{'dom.home'} = (($webdb->{'fedexapi_dom'} & 4)==4)?1:0; #  254,
	$cfg{'dom.home_eve'} = (($webdb->{'fedexapi_dom'} & 8)==8)?1:0; #  254,
	$cfg{'dom.3day'} = (($webdb->{'fedexapi_dom'} & 16)==16)?1:0; #  254,
	$cfg{'dom.2day'} = (($webdb->{'fedexapi_dom'} & 32)==32)?1:0; #  254,
	$cfg{'dom.nextday'} = (($webdb->{'fedexapi_dom'} & 64)==64)?1:0; #  254,
	$cfg{'dom.nextnoon'} = (($webdb->{'fedexapi_dom'} & 128)==128)?1:0; #  254,
	$cfg{'dom.nextearly'} = (($webdb->{'fedexapi_dom'} & 256)==256)?1:0; #  254,
	delete $webdb->{'fedexapi_dom'};
	$cfg{'legacy.dropoff'} = $webdb->{'fedexapi_drop_off'}; #  '1',
	delete $webdb->{'fedexapi_drop_off'};
	#fedexapi_drop_off
	#	1 if regular pickup
	#	2 if request courier
	#	3 if drop box
	#	4 if drop at BSC
	#	5 if drop at station
	my ($orig_state,$orig_zip,$orig_country) = split(/\|/,$webdb->{'fedexapi_origin'});
	$cfg{'origin.state'} = $orig_state;
	$cfg{'origin.zip'} = $orig_zip;
	$cfg{'origin.country'} = $orig_country;

	$cfg{'legacy.origin'} = $webdb->{'fedexapi_origin'}; #  'MD|21209|US',
	$cfg{'legacy.dom_pkg'} = $webdb->{'fedexapi_dom_packaging'}; #  '01',
	delete $webdb->{'fedexapi_origin'};
	delete $webdb->{'fedexapi_dom_packaging'};
	#		my $packaging = $WEBDBREF->{'fedexapi_dom_packaging'}; # Default to using whatever they had entered directly
	#		if ($packaging eq 'SMART') { # packaging of "SMART" overrides this default based on the weight of the shipment
	#			if ($LBS < 0.5) { $packaging = '06'; } # 4 oz or less?  Make it a letter
	#			elsif ($LBS <= 2) { $packaging = '02'; } # 2 lbs or less, fedex PAK
	#			else { $packaging = '01'; } # More than 2 lbs, other packaging
	#			}
	#		if ($base_param{'3025'} eq 'FDXG') { $packaging = '01'; }

	return(\%cfg);
	}


#################################################################
##
##
##
sub subscriptionRequest {
	my ($USERNAME,$cfg,$MSGSREF) = @_;

	my ($VERB,$XMLNS)  = ("SubscriptionRequest","http://fedex.com/ws/registration/v2");

	my @CMDS = ();

	## add header tags:
	push @CMDS, [ 'startTag', $VERB, 'xmlns:xsi'=>"http://www.w3.org/2001/XMLSchema-instance", 'xmlns:xsd'=>"http://www.w3.org/2001/XMLSchema", 'xmlns'=>$XMLNS ];
	foreach my $ref (@{&standard_header_tags($cfg,$VERB,$XMLNS)}) { push @CMDS, $ref; }

	## call specific tags:

 # <CspSolutionId xmlns="http://fedex.com/ws/registration/v2">050</CspSolutionId>
 # <CspType xmlns="http://fedex.com/ws/registration/v2">CERTIFIED_SOLUTION_PROVIDER</CspType>
	push @CMDS, [ 'dataElement', 'CspSolutionId', '050', xmlns=>$XMLNS ];
	push @CMDS, [ 'dataElement', 'CspType', 'CERTIFIED_SOLUTION_PROVIDER', xmlns=>$XMLNS ];


  #<Subscriber xmlns="http://fedex.com/ws/registration/v2">
  #  <AccountNumber>255047051</AccountNumber> <Contact>
  #    <PersonName>customer name</PersonName> <CompanyName>Zoovy
  #    Inc</CompanyName> <PhoneNumber>877966894</PhoneNumber>
  #  </Contact>
  #  <Address>
  #    <StreetLines>5868 Owens Ave</StreetLines> <City>Carlsbad</City>
  #    <StateOrProvinceCode>CA</StateOrProvinceCode>
  #    <PostalCode>92008</PostalCode> <CountryCode>US</CountryCode>
  #    </Address>
  #</Subscriber>
	push @CMDS, [ 'startTag', 'Subscriber', xmlns=>$XMLNS ];
		push @CMDS, [ 'dataElement', 'AccountNumber', $cfg->{'account'} ];
		push @CMDS, [ 'startTag', 'Contact' ];
			$cfg->{'register.firstname'} =~ s/^[\s]+//gs;
			$cfg->{'register.lastname'} =~ s/^[\s]+//gs;
			push @CMDS, [ 'dataElement', 'PersonName', sprintf("%s %s",$cfg->{'register.firstname'}, $cfg->{'register.lastname'}) ];
			push @CMDS, [ 'dataElement', 'CompanyName', $cfg->{'register.company'} ];
			push @CMDS, [ 'dataElement', 'PhoneNumber', $cfg->{'register.phone'} ];
		push @CMDS, [ 'endTag', 'Contact' ];

		push @CMDS, [ 'startTag', 'Address' ];
			push @CMDS, [ 'dataElement', 'StreetLines', $cfg->{'register.streetlines'} ];
			push @CMDS, [ 'dataElement', 'City', $cfg->{'register.city'} ];
			push @CMDS, [ 'dataElement', 'StateOrProvinceCode', $cfg->{'register.state'} ];
			push @CMDS, [ 'dataElement', 'PostalCode', $cfg->{'register.zip'} ];
			push @CMDS, [ 'dataElement', 'CountryCode', $cfg->{'register.country'} ];
		push @CMDS, [ 'endTag', 'Address' ];
	push @CMDS, [ 'endTag', 'Subscriber' ];

  #<AccountShippingAddress xmlns="http://fedex.com/ws/registration/v2">
  #  <StreetLines>5868 Owens Ave</StreetLines> <City>Carlsbad</City>
  #  <StateOrProvinceCode>CA</StateOrProvinceCode>
  #  <PostalCode>92008</PostalCode> <CountryCode>US</CountryCode>
  #</AccountShippingAddress>
	push @CMDS, [ 'startTag', 'AccountShippingAddress', 'xmlns'=>$XMLNS ];
		push @CMDS, [ 'dataElement', 'StreetLines', $cfg->{'register.streetlines'} ];
		push @CMDS, [ 'dataElement', 'City', $cfg->{'register.city'} ];
		push @CMDS, [ 'dataElement', 'StateOrProvinceCode', $cfg->{'register.state'} ];
		push @CMDS, [ 'dataElement', 'PostalCode', $cfg->{'register.zip'} ];
		push @CMDS, [ 'dataElement', 'CountryCode', $cfg->{'register.country'} ];
	push @CMDS, [ 'endTag', 'AccountShippingAddress' ];
	
	## FOOTER
	push @CMDS, [ 'endTag', 'SubscriptionRequest' ];

	#$VAR1 = {
   #       'v2:RegisteredServices' => [
   #                                  'EXPRESS_SHIPPING'
   #                                ],
   #       'v2:HighestSeverity' => [
   #                               'SUCCESS'
   #                             ],
   #       'xmlns:v2' => 'http://fedex.com/ws/registration/v2',
   #       'xmlns:env' => 'http://schemas.xmlsoap.org/soap/envelope/',
   #       'v2:MeterNumber' => [
   #                           '102989725'
   #                         ],
   #       'v2:Notifications' => [
   #                             {
   #                               'v2:Code' => [
   #                                            '0000'
   #                                          ],
   #                               'v2:Source' => [
   #                                              'auto'
   #                                            ],
   #                               'v2:Severity' => [
   #                                                'SUCCESS'
   #                                              ]
   #                             }
   #                           ],
   #       'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
   #       'Version' => [
   #                    {
   #                      'xmlns' => 'http://fedex.com/ws/registration/v2',
   #                      'Minor' => [
   #                                 '0'
   #                               ],
   #                      'Major' => [
   #                                 '2'
   #                               ],
   #                      'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
   #                      'Intermediate' => [
   #                                        '1'
   #                                      ],
   #                      'ServiceId' => [
   #                                     'fcas'
   #                                   ]
   #                    }
   #                  ]
   #     };

	my ($ref) = &doRequest($USERNAME,$VERB,\@CMDS);

	#open F, ">/tmp/foo2";
	#print F Dumper($ref,\@CMDS);
	#close F;

	if (not defined $ref) {
		push @{$MSGSREF}, sprintf("ERROR|+FedEx API DOWN/UNAVAILABLE");
		}
	elsif ($ref->{'err'}>0) {
		push @{$MSGSREF}, sprintf("ERROR|+FedEx API DOWN/UNAVAILABLE %s",$ref->{'msg'});
		}
	elsif ($ref->{'v2:HighestSeverity'}->[0] eq 'SUCCESS') {
		$cfg->{'meter'} = $ref->{'v2:MeterNumber'}->[0];
		$cfg->{'meter.created'} = time();
		$cfg->{'meter.services'} = join('|',@{$ref->{'v2:RegisteredServices'}});
		push @{$MSGSREF}, sprintf("SUCCESS|+Success! services available: %s\n",$cfg->{'meter.services'});
		}
	else {
		my $i = 0;
		foreach my $msgref (@{$ref->{'v2:Notifications'}}) {
			push @{$MSGSREF}, sprintf("ERROR|+FedEx API[%d] ERROR:%s",$msgref->{'v2:Code'}->[0],$msgref->{'v2:Message'}->[0]);
			$i++;
			}
		foreach my $msgref (@{$ref->{'ns:Notifications'}}) {
			push @{$MSGSREF}, sprintf("ERROR|+FedEx API[%d] ERROR:%s",$msgref->{'ns:Code'}->[0],$msgref->{'ns:Message'}->[0]);
			$i++;
			}

		if ($i==0) {
			push @{$MSGSREF}, "WARNING|+No messages returned ZSHIP::FEDEXWS::subscriptionRequest (this is probably an error)";
			}
		}

	return();
	}




#################################################################################################
##
## this is a special call, intended to setup a new user.
##
sub register {
	my ($USERNAME,$cfg,$MSGSREF) = @_;

	# $cfg = load_webdb_fedexws_cfg($USERNAME,0);
	# print Dumper($cfg);

	my ($VERB,$XMLNS)  = ("RegisterWebCspUserRequest","http://fedex.com/ws/registration/v2");

	my @CMDS = ();
	## add header tags:
	push @CMDS, [ 'startTag', $VERB, 'xmlns:xsi'=>"http://www.w3.org/2001/XMLSchema-instance", 'xmlns:xsd'=>"http://www.w3.org/2001/XMLSchema", 'xmlns'=>$XMLNS ];
	foreach my $ref (@{&standard_header_tags($cfg,$VERB,$XMLNS)}) { push @CMDS, $ref; }

	## call specific tags:
	push @CMDS, [ 'startTag', 'BillingAddress','xmlns'=>$XMLNS ];
	push @CMDS, [ 'dataElement', 'StreetLines', $cfg->{'register.streetlines'} ];
	push @CMDS, [ 'dataElement', 'City', $cfg->{'register.city'} ];
	push @CMDS, [ 'dataElement', 'StateOrProvinceCode', $cfg->{'register.state'} ];
	push @CMDS, [ 'dataElement', 'PostalCode', $cfg->{'register.zip'} ];
	push @CMDS, [ 'dataElement', 'CountryCode', $cfg->{'register.country'} ];
	push @CMDS, [ 'endTag', 'BillingAddress' ];

	push @CMDS, [ 'startTag', 'UserContactAndAddress','xmlns'=>$XMLNS ];
		push @CMDS, [ 'startTag', 'Contact' ];
			push @CMDS, [ 'startTag', 'PersonName' ];
				push @CMDS, [ 'dataElement', 'FirstName', $cfg->{'register.firstname'} ];
				push @CMDS, [ 'dataElement', 'LastName', $cfg->{'register.lastname'} ];
				push @CMDS, [ 'endTag', 'PersonName' ];
			push @CMDS, [ 'dataElement', 'CompanyName', $cfg->{'register.company'} ];
			push @CMDS, [ 'dataElement', 'PhoneNumber', $cfg->{'register.phone'} ];
			push @CMDS, [ 'dataElement', 'EMailAddress',$cfg->{'register.email'} ];
		push @CMDS, [ 'endTag', 'Contact' ];
		push @CMDS, [ 'startTag', 'Address' ];
			push @CMDS, [ 'dataElement', 'StreetLines', $cfg->{'register.streetlines'} ];
			push @CMDS, [ 'dataElement', 'City', $cfg->{'register.city'} ];
			push @CMDS, [ 'dataElement', 'StateOrProvinceCode', $cfg->{'register.state'} ];
			push @CMDS, [ 'dataElement', 'PostalCode', $cfg->{'register.zip'} ];
			push @CMDS, [ 'dataElement', 'CountryCode', $cfg->{'register.country'} ];
		push @CMDS, [ 'endTag', 'Address' ];
	push @CMDS, [ 'endTag', 'UserContactAndAddress' ];


	## FOOTER:	
	push @CMDS, [ 'endTag', $VERB ];

	my ($ref) = &doRequest($USERNAME,$VERB,\@CMDS);

#           'v2:Credential' => [, 
#                              {, 
#                                'v2:Password' => [, 
#                                                 'gkqZEXa4LLgRsrAExBQoR3kq2', 
#                                               ],, 
#                                'v2:Key' => [, 
#                                            'le2HuSfKbowhI81g', 
#                                          ], 
#                              }, 
#                            ],, 
#           'xmlns:soapenv' => 'http://schemas.xmlsoap.org/soap/envelope/',, 
#           'v2:Notifications' => [, 
#                                 {, 
#                                   'v2:Message' => [, 
#                                                   'Success', 
#                                                 ],, 
#                                   'v2:Code' => [, 
#                                                '0000', 
#                                              ],, 
#                                   'v2:Source' => [, 
#                                                  'fcas', 
#                                                ],, 
#                                   'v2:Severity' => [, 
#                                                    'SUCCESS', 
#                                                  ], 
#                                 }, 
#                               ],, 
#           'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',, 
#           'Version' => [, 
#                        {, 
#                          'xmlns' => 'http://fedex.com/ws/registration/v2',, 
#                          'Minor' => [, 
#                                     '0', 
#                                   ],, 
#                          'Major' => [, 
#                                     '2', 
#                                   ],, 
#                          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',, 
#                          'Intermediate' => [, 
#                                            '1', 
#                                          ],, 
#                          'ServiceId' => [, 
#                                         'fcas', 
#                                       ], 
#                        }, 
#                      ], 

	
	print STDERR Dumper($ref);

	$cfg->{'registration.created'} = 0;
	if (not defined $ref) {
		push @{$MSGSREF}, sprintf("ERROR|+FedEx API DOWN/UNAVAILABLE");
		}
	elsif ($ref->{'err'}>0) {
		push @{$MSGSREF}, sprintf("ERROR|+FedEx API DOWN/UNAVAILABLE %s",$ref->{'msg'});
		}
	elsif (
			($ref->{'v2:HighestSeverity'}->[0] eq 'SUCCESS') 	## pre 8/9/2013
#			($ref->{'v2:HighestSeverity'}->[0]->{'content'} eq 'SUCCESS') 	## post 8/9/2013 (they now include namespace)
			)
		{
		$cfg->{'registration.created'} = time();
		$cfg->{'registration.password'} = $ref->{'v2:Credential'}->[0]->{'v2:Password'}->[0];
		$cfg->{'registration.key'} = $ref->{'v2:Credential'}->[0]->{'v2:Key'}->[0];
		push @{$MSGSREF}, "SUCCESS|+Successfully got key+password from FedEx";
		}
	else {
		foreach my $msgref (@{$ref->{'v2:Notifications'}}) {
			push @{$MSGSREF}, sprintf("ERROR|+FedEx API[%d] ERROR:%s",$msgref->{'v2:Code'}->[0],$msgref->{'v2:Message'}->[0]);
			}
		}

	if (scalar(@{$MSGSREF})==0) {
		push @{$MSGSREF}, "WARNING|+No messages returned ZSHIP::FEDEXWS::register (this is probably an error)";
		}

	return($cfg);
	}

## Accepts: A zoovy weight (with # for pounds) and an optional multiplier (good for quantities)
## Returns: Total lbs formatted with one decimal point and zeroes as 0.1, and total ounces
sub fedex_weight
{
	my ($zoovy_weight,$multiplier) = @_;
	if (not defined $multiplier) { $multiplier = 1; }
	my $oz = &ZSHIP::smart_weight($zoovy_weight); # We need this to figure out if we have something likely to go in a letter for "SMART" mode packaging
	$oz *= $multiplier;
	$oz *= 10;
	if ($oz <= 0) { $oz = 10; } ## Zero values are not allowed

	my $lbs = ($oz / 16);
	if ($lbs != int($lbs)) { $oz += 5; } ## Make sure to round up.

	$lbs = sprintf("%.1f",$oz/160);
	return ($lbs);
}



##################################################################################
##
## Sub: compute_domestic
##
## Purpose: this is the function called by ZSHIP::domestic_marshall
## 	ZSHIP will automatically call this if webdb/fedex_meter is set, otherwise it
##		will default to the legacy FEDEX.pm
##
##	note: the parameter for fedex account changed from the FEDEX.pm it was
##		webdb/fedex_acct it is now webdb/fedex_account
##
##################################################################################
## compute_domestic
## compute_international
sub compute {
	my ($CART2, $PKG, $cfg, $METAREF) = @_;

	my $CARTID = $CART2->cartid();
	my $USERNAME = $CART2->username();

	## my ($USERNAME, $address{'zip'}, $WEIGHT, $PRICE, $ITEMCOUNT, $IS_COD, $CART, $STATE, $IS_EXTERNAL, $WEBDBREF) = @_;
	require LISTING::MSGS;
	my $lm = LISTING::MSGS->new($USERNAME);

	my @APILOG = ();
	$lm->pooshmsg("INFO|+FedEx Compute Starting");

	my %address = ();
	$address{'city'} = $CART2->in_get('ship/city');
	$address{'state'} = $CART2->in_get('ship/region');
	# if ($address{'zip'} eq '') { $address{'zip'} = $CART2->in_get('cgi.zip'); }

	$address{'street'} = $CART2->in_get('ship/address1');
	if ($CART2->in_get('ship/address2') eq '') {
		$address{'street'} .= ' '.$CART2->in_get('ship/address2');
		}

	my $WEIGHT = undef;
	$address{'country'} = 'US';
	if (($CART2->in_get('ship/countrycode') eq '') || ($CART2->in_get('ship/countrycode') eq 'US')) {
		if ($address{'state'} eq 'PR') {
			$lm->pooshmsg("INFO|+FedEx detected country PR");
			$address{'country'} = 'PR';
			}
		$address{'zip'} = $CART2->in_get('ship/postal');
		$WEIGHT = $PKG->get('pkg_weight');
		}
	elsif (length($CART2->in_get('ship/countrycode'))==2) {
		# my ($country_code) = &ZSHIP::fetch_country_shipcodes($COUNTRY);
		my ($info) = &ZSHIP::resolve_country('ISO'=>$CART2->in_get('ship/countrycode'));
		if ((defined $info) && (defined $info->{'FDX'})) {
			$address{'country'} = $info->{'FDX'};
			}
		else {
			$address{'country'} = $CART2->in_get('ship/countrycode');
			}
		$address{'zip'} = $CART2->in_get('ship/postal');
		}
	#elsif ($CART2->in_get('ship/country')) {
	#	# my ($country_code) = &ZSHIP::fetch_country_shipcodes($COUNTRY);
	#	my ($info) = &ZSHIP::resolve_country('ZOOVY'=>$CART2->in_get('ship/country'));
	#	$address{'country'} = $info->{'FDX'};
	#	}

	if (($address{'country'} eq 'US') || ($address{'country'} eq 'PR')) {
		$address{'zip'} =~ s/^(\d\d\d\d\d).*$/$1/;
		# Strip off zip+4 info
		if ($address{'zip'} eq '') { $lm->pooshmsg("ERROR|+No ZIP code"); }
		if ($address{'zip'} !~ m/^\d\d\d\d\d$/) { $lm->pooshmsg("ERROR|+mis-formatted Zip (must be ######)"); }
		}
	elsif ($address{'country'} eq 'CA') {
		# canada postal codes are: H7E2B3
		$address{'zip'} = uc($address{'zip'});
		$address{'zip'} =~ s/[\s]+//g;
		if ($address{'zip'} !~ /^[A-Z][0-9][A-Z][0-9][A-Z][0-9]$/) {
			$lm->pooshmsg("ISE|+Canada zips must be format: ANANAN");
			}
		## BACKWARD COMPATIBLE HACK
		$WEIGHT = sprintf("%0.1f",int($PKG->get('legacy_usps_weight_166')));
		}
	else {
		if ($address{'zip'} eq '') { $address{'zip'} = '92011';  }	## this usually works
		## BACKWARD COMPATIBLE HACK
		$WEIGHT = sprintf("%0.1f",int($PKG->get('legacy_usps_weight_166')));
		}

	my $PRICE = $PKG->get('items_total'); 
	my $ITEMCOUNT = $PKG->get('items_count'); 

	# my $IS_COD = $CART2->in_get('data.cod');
	my $STATE = $CART2->in_get('ship/region');
	
	if (not defined $METAREF) { $METAREF = {}; }
	$METAREF->{'single_only'} = 1;

	my %methods = ();

	# If we don't have a few required fields, bounce back nuthin'
	if ((not defined $cfg->{'account'}) || ($cfg->{'account'} eq '')) {
		$lm->pooshmsg("FAIL-FATAL|+FedEx Account number was not configured/loaded");
		}
	if ((not defined $cfg->{'meter'}) || ($cfg->{'meter'} eq '')) {
		$lm->pooshmsg("FAIL-FATAL|+FedEx Meter number was not configured/loaded");
		}
	if ((not defined $cfg->{'origin.state'}) || ($cfg->{'origin.state'} eq '')) {
		$lm->pooshmsg("FAIL-FATAL|+Origin State was not set");
		}
	if ((not defined $cfg->{'origin.country'}) || ($cfg->{'origin.country'} eq '')) {
		$lm->pooshmsg("FAIL-FATAL|+Origin Country was not set");
		}
	if ((not defined $cfg->{'origin.zip'}) || ($cfg->{'origin.zip'} eq '')) {
		$lm->pooshmsg("FAIL-FATAL|+Origin ZIP was not set");
		}
	if ((not defined $address{'country'}) || ($address{'country'} eq '')) { 
		warn "Could not look up country code for [$address{'country'}]";
		$lm->pooshmsg("ISE|+Could not determine country");
		}

	# Are we dealing with more than one SKU?
	my $skucount = $PKG->count();

	# my $total_packages = (($skucount > 1) && $options{'multibox'}) ? $skucount : 1;
	# if (not defined $WEBDBREF->{'fedexapi_rate'}) { $WEBDBREF->{'fedexapi_rate'} = 2; }
	#$default{'1529'} = 1;
	#if ($WEBDBREF->{'fedexapi_rate'} == 2) { $default{'1529'} = 2;  }
	my $use_retail = 0;
	if ($cfg->{'rates'} eq 'retail') { $use_retail = 1; }
	elsif ($cfg->{'rates'} eq 'actual') { $use_retail = 0; }
	elsif ($cfg->{'rates'} eq 'cost') { $use_retail = 0; }
	else {
		$use_retail++;
		$lm->pooshmsg("WARN|+rates was not configured, using retail");
		}
	# $use_retail = 1;

	my ($is_residential) = $CART2->in_get('ship/company')?0:1;
	if (($cfg->{'dom.ground'}==0) && ($cfg->{'dom.home'}>0)) {
		$lm->pooshmsg("INFO|+Appears 'GROUND' is not available, but 'HOME_DELIVERY' is, so treating all addresses as home");
		$is_residential = 1;
		}
	elsif (($cfg->{'dom.ground'}==1) && ($cfg->{'dom.home'}==0)) {
		$lm->pooshmsg("INFO|+Appears 'HOME_DELIVERY' is not available, but 'GROUND' is, so treating all addresses as commericial");
		$is_residential = 0;
		}
	
	my %origin = ();
	my @methods = ();

	# $cfg = load_webdb_fedexws_cfg($USERNAME,0);
	# print Dumper($cfg);
	my ($VERB,$XMLNS)  = ("RateRequest","http://fedex.com/ws/rate/v7");

	my @CMDS = ();
	## add header tags:
	push @CMDS, [ 'startTag', $VERB, 'xmlns:xsi'=>"http://www.w3.org/2001/XMLSchema-instance", 'xmlns:xsd'=>"http://www.w3.org/2001/XMLSchema", 'xmlns'=>$XMLNS ];
	foreach my $ref (@{&standard_header_tags($cfg,$VERB,$XMLNS)}) { push @CMDS, $ref; }

	## the line below might be interesting in the future:
	push @CMDS, [ 'dataElement', 'ReturnTransitAndCommit', 'false' ];

	## Tell FedEx which CarrierCodes we FDXE FDXG
	my $has_services = 0;
	if ($cfg->{'dom.nextearly'} || $cfg->{'dom.nextnoon'} || $cfg->{'dom.nextday'} ||
		 $cfg->{'dom.3day'} || $cfg->{'dom.2day'} ||
		 $cfg->{'int.nextnoon'} || $cfg->{'int.2day'} || $cfg->{'int.nextearly'}
		) {
		## EXPRESS
		push @CMDS, [ 'dataElement', 'CarrierCodes', 'FDXE' ];
		$has_services++;
		}
	if (
		$cfg->{'dom.ground'} || $cfg->{'dom.home'} || $cfg->{'dom.home_eve'} || 
		$cfg->{'int.ground'}
		) {
		## GROUND
		push @CMDS, [ 'dataElement', 'CarrierCodes', 'FDXG' ];
		$has_services++;
		}
	#push @CMDS, [ 'dataElement', 'CarrierCodes', 'FXFR' ]; # FedEx Freight
	#push @CMDS, [ 'dataElement', 'CarrierCodes', 'FXSP' ]; # FedEx Smart Post
	if (not $has_services) {
		$lm->pooshmsg("WARN|+No FedEx services was requested, this probably won't work!");
		}

	# print STDERR "ADDRESS: ".Dumper(\%address)."\n";


	push @CMDS, [ 'startTag', 'RequestedShipment' ];
		# push @CMD, [ 'dataElement', 'TotalWeight', 1.00 ];
		push @CMDS, [ 'startTag', 'TotalWeight' ];
			push @CMDS, [ 'dataElement', 'Units', 'LB' ];
			push @CMDS, [ 'dataElement', 'Value', &fedex_weight($WEIGHT) ];
		push @CMDS, [ 'endTag', 'TotalWeight' ];
		push @CMDS, [ 'startTag', 'TotalInsuredValue' ];
			push @CMDS, [ 'dataElement', 'Currency', 'USD' ];
			push @CMDS, [ 'dataElement', 'Amount', '1.00' ];
		push @CMDS, [ 'endTag', 'TotalInsuredValue' ];
		push @CMDS, [ 'startTag', 'Shipper' ];
			push @CMDS, [ 'dataElement', 'AccountNumber', $cfg->{'account'} ];
			push @CMDS, [ 'startTag', 'Address' ];
			#	push @CMDS, [ 'dataElement', 'StreetLines', '5868 Owens Ave. #150' ];
			#	push @CMDS, [ 'dataElement', 'City', $cfg->{'origin.city'} ];
			if ($METAREF->{'origin.zip'}) {
				## normally ZSHIP will set METAREF->{'origin.zip'} etc.
				push @CMDS, [ 'dataElement', 'StateOrProvinceCode', uc($METAREF->{'origin.state'}) ];
				push @CMDS, [ 'dataElement', 'PostalCode', $METAREF->{'origin.zip'} ];
				push @CMDS, [ 'dataElement', 'CountryCode', $METAREF->{'origin.country'} ];
				}
			else {
				push @CMDS, [ 'dataElement', 'StateOrProvinceCode', uc($cfg->{'origin.state'}) ];
				push @CMDS, [ 'dataElement', 'PostalCode', $cfg->{'origin.zip'} ];
				push @CMDS, [ 'dataElement', 'CountryCode', $cfg->{'origin.country'} ];
				}
				push @CMDS, [ 'dataElement', 'Residential', 'false' ];
			push @CMDS, [ 'endTag', 'Address' ];
		push @CMDS, [ 'endTag', 'Shipper' ];
		push @CMDS, [ 'startTag', 'Recipient' ];
			push @CMDS, [ 'startTag', 'Address' ];
				# push @CMDS, [ 'dataElement', 'StreetLines', $address{'street'} ];
				push @CMDS, [ 'dataElement', 'City', $address{'city'} ];
				if ($address{'country'} eq 'US') {
					## StateOrProvinceCode can only be 2 characters so we do'nt pass it for non-US destinations
					push @CMDS, [ 'dataElement', 'StateOrProvinceCode', $address{'state'} ];
					}
				push @CMDS, [ 'dataElement', 'PostalCode', $address{'zip'} ];
				push @CMDS, [ 'dataElement', 'CountryCode', $address{'country'} ];
				push @CMDS, [ 'dataElement', 'Residential', ($is_residential?'true':'false') ];
			push @CMDS, [ 'endTag', 'Address' ];
		push @CMDS, [ 'endTag', 'Recipient' ];
		push @CMDS, [ 'startTag', 'Origin' ];
			push @CMDS, [ 'startTag', 'Address' ];
			#	push @CMDS, [ 'dataElement', 'StreetLines', '5868 Owens Ave. #150' ];
			#	push @CMDS, [ 'dataElement', 'City', 'Carlsbad' ];
			push @CMDS, [ 'dataElement', 'StateOrProvinceCode', $cfg->{'origin.state'} ];
			push @CMDS, [ 'dataElement', 'PostalCode', $cfg->{'origin.zip'} ];
			push @CMDS, [ 'dataElement', 'CountryCode', $cfg->{'origin.country'} ];
			#	push @CMDS, [ 'dataElement', 'StateOrProvinceCode', 'CA' ];
			#	push @CMDS, [ 'dataElement', 'PostalCode', '92008' ];
			#	push @CMDS, [ 'dataElement', 'CountryCode', 'US' ];
				push @CMDS, [ 'dataElement', 'Residential', 'false' ];
			push @CMDS, [ 'endTag', 'Address' ];
		push @CMDS, [ 'endTag', 'Origin' ];
	
	
	push @CMDS, [ 'dataElement', 'RateRequestTypes', ($use_retail)?'LIST':'ACCOUNT' ];	# ACCOUNT, LIST, MULTIWEIGHT
	
	push @CMDS, [ 'dataElement', 'PackageCount', '1' ];
		push @CMDS, [ 'dataElement', 'PackageDetail', 'INDIVIDUAL_PACKAGES' ];
		push @CMDS, [ 'startTag', 'RequestedPackageLineItems' ];
			push @CMDS, [ 'dataElement', 'SequenceNumber', '1' ];
			push @CMDS, [ 'startTag', 'Weight' ];
				push @CMDS, [ 'dataElement', 'Units', 'LB' ];
				push @CMDS, [ 'dataElement', 'Value', &fedex_weight($WEIGHT) ];
			push @CMDS, [ 'endTag', 'Weight' ];
			#push @CMDS, [ 'startTag', 'Dimensions' ];
			#	push @CMDS, [ 'dataElement', 'Length', '6' ];
			#	push @CMDS, [ 'dataElement', 'Width', '6' ];
			#	push @CMDS, [ 'dataElement', 'Height', '6' ];
			#	push @CMDS, [ 'dataElement', 'Units', 'IN' ];
			#push @CMDS, [ 'endTag', 'Dimensions' ];
		push @CMDS, [ 'endTag', 'RequestedPackageLineItems' ];
	push @CMDS, [ 'endTag', 'RequestedShipment' ];
	push @CMDS, [ 'endTag', 'RateRequest' ];

	my $ref = undef;
	if (not $lm->has_failed()) {
		($ref) = &doRequest($USERNAME,$VERB,\@CMDS);
		}

	# print Dumper($ref);	die();
	if ($lm->has_failed()) {
		## shit already happened.
		}
	elsif (not defined $ref) {
		$lm->pooshmsg("ERROR|+FedEx servers were unreachable");
		}
	elsif ($ref->{'err'}>0) {
		$lm->pooshmsg(sprintf("ERROR|FedEx API DOWN/UNAVAILABLE %s",$ref->{'msg'}));
		}
	elsif ($ref->{'v7:RateReplyDetails'}) {
		## THIS WAS THE RESPONSE FORMAT BEFORE 1/18/13
		 open F, ">/tmp/fedex.$USERNAME.v7legacy";	

		foreach my $ratereplydetail (@{$ref->{'v7:RateReplyDetails'}}) {
			my $flatrrd = &ZTOOLKIT::XMLUTIL::SXMLflatten($ratereplydetail);
			my %method = (
				'zone'=>$flatrrd->{'.v7:RatedShipmentDetails.v7:ShipmentRateDetail.v7:RateZone'},
				'id'=>$flatrrd->{'.v7:ServiceType'},
				'carrier'=>'XXX',
				);
			## fedex response returns both actual and retail rates in RatedShipmentDetails
			print F Dumper($flatrrd)."\n\n";
			foreach my $ratedshipmentdetails (@{$ratereplydetail->{'v7:RatedShipmentDetails'}}) {
				print F 'ratedshipmentdetails: '.Dumper($ratedshipmentdetails);
				my $flatrsd = &ZTOOLKIT::XMLUTIL::SXMLflatten($ratedshipmentdetails);

				if ($flatrsd->{'.v7:ShipmentRateDetail.v7:RateType'} eq 'PAYOR_LIST') {
					$method{'retail_amount'} = $flatrsd->{'.v7:ShipmentRateDetail.v7:TotalNetCharge.v7:Amount'};
					}
				elsif ($flatrsd->{'.v7:ShipmentRateDetail.v7:RateType'} eq 'PAYOR_ACCOUNT') {
					# $method{'actual_amount'} = $flatrsd->{'.v7:ShipmentRateDetail.v7:TotalBaseCharge.v7:Amount'};	# 6.73
					# $method{'actual_amount'} = $flatrsd->{'.v7:ShipmentRateDetail.v7:TotalNetFedExCharge.v7:Amount'};	# 7
					# $flatrsd->{'.v7:ShipmentRateDetail.v7:TotalNetFreight.v7:Amount'};				# 6.39
					# $flatrsd->{'.v7:ShipmentRateDetail.v7:TotalSurcharges.v7:Amount'};				# 0.61
					##	NOTE: surcharges like FUEL etc. appear in @{.v7:ShipmentRateDetail.v7:Surcharges}
					$method{'actual_amount'} = $flatrsd->{'.v7:ShipmentRateDetail.v7:TotalNetCharge.v7:Amount'};				# 7
					# $method{'retail_amount'} = $method{'actual_amount'} + $flatrsd->{'.v7:RatedShipmentDetails.v7:ShipmentRateDetail.v7:TotalFreightDiscounts.v7:Amount'};
					}
				elsif ($flatrsd->{'.v7:ShipmentRateDetail.v7:RateType'} eq 'PAYOR_MULTIWEIGHT') {
					##	NOTE: not sure what the heck this is!?
					}
				elsif ($flatrsd->{'.v7:ShipmentRateDetail.v7:RateType'} eq 'RATED_LIST') {
					##	NOTE: not sure what the heck this is!?
					}
				elsif ($flatrsd->{'.v7:ShipmentRateDetail.v7:RateType'} eq 'RATED_ACCOUNT') {
					##	NOTE: not sure what the heck this is!?
					}
				else {
					$lm->pooshmsg("WARN|+Unknown RateType: ".$flatrsd->{'.v7:ShipmentRateDetail.v7:RateType'});
					}
				}

				#	<xs:enumeration value="EUROPE_FIRST_INTERNATIONAL_PRIORITY"/>
				#	<xs:enumeration value="FEDEX_1_DAY_FREIGHT"/>
				#	<xs:enumeration value="FEDEX_2_DAY"/>
				#	<xs:enumeration value="FEDEX_2_DAY_FREIGHT"/>
				#	<xs:enumeration value="FEDEX_3_DAY_FREIGHT"/>
				#	<xs:enumeration value="FEDEX_EXPRESS_SAVER"/>
				#	<xs:enumeration value="FEDEX_GROUND"/>
				#	<xs:enumeration value="FIRST_OVERNIGHT"/>
				#	<xs:enumeration value="GROUND_HOME_DELIVERY"/>
				#	<xs:enumeration value="INTERNATIONAL_ECONOMY"/>
				#	<xs:enumeration value="INTERNATIONAL_ECONOMY_FREIGHT"/>
				#	<xs:enumeration value="INTERNATIONAL_FIRST"/>
				#	<xs:enumeration value="INTERNATIONAL_PRIORITY"/>
				#	<xs:enumeration value="INTERNATIONAL_PRIORITY_FREIGHT"/>
				#	<xs:enumeration value="PRIORITY_OVERNIGHT"/>
				#	<xs:enumeration value="SMART_POST"/>
				#	<xs:enumeration value="STANDARD_OVERNIGHT"/>
				#	<xs:enumeration value="FEDEX_FREIGHT"/>
				#	<xs:enumeration value="FEDEX_NATIONAL_FREIGHT
			if ($method{'id'} eq 'FIRST_OVERNIGHT') {
				$method{'carrier'} = 'FXFO';
				$method{'ruleset'} = "FEDEXAPI_DOM,FEDEXAPI_DOM_NEXTEARLY";
				if ($cfg->{'dom.nextearly'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			elsif ($method{'id'} eq 'PRIORITY_OVERNIGHT') {
				$method{'carrier'} = 'FXPO';
				$method{'ruleset'} = "FEDEXAPI_DOM,FEDEXAPI_DOM_NEXTNOON";
				if ($cfg->{'dom.nextnoon'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			elsif ($method{'id'} eq 'STANDARD_OVERNIGHT') {
				$method{'carrier'} = 'FXSO';
				$method{'ruleset'} = "FEDEXAPI_DOM,FEDEXAPI_DOM_NEXTDAY";
				if ($cfg->{'dom.nextday'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			elsif ($method{'id'} eq 'FEDEX_2_DAY') {
				$method{'carrier'} = 'FX2D';
				$method{'ruleset'} = "FEDEXAPI_DOM,FEDEXAPI_DOM_2DAY";
				if ($cfg->{'dom.2day'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			elsif ($method{'id'} eq 'FEDEX_EXPRESS_SAVER') {
				$method{'carrier'} = 'FXES';
				$method{'ruleset'} = "FEDEXAPI_DOM,FEDEXAPI_DOM_3DAY";
				if ($cfg->{'dom.3day'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			elsif ($method{'id'} eq 'GROUND_HOME_DELIVERY') {
				$method{'carrier'} = 'FXHD';
				$method{'ruleset'} = "FEDEXAPI_DOM,FEDEXAPI_DOM_HOME";
				if ($cfg->{'dom.home'}>0) {}
				elsif ($cfg->{'dom.home_eve'}) {}
				else { $method{'skip'} = 'disabled by config.'; }
				}
			## GROUND_DELIVERY?					ground	FXGR
			## GROUND_HOME_EVENING_DELIVERY?	home_eve	FXHE
			elsif ($method{'id'} eq 'FEDEX_GROUND') {
				## apparently we can ship ground to us (dom) and canada! (int) what's all dee foos aboot?
				if ($address{'country'} eq 'US') { 
					$method{'carrier'} = 'FXGR';
					$method{'ruleset'} = "FEDEXAPI_DOM,FEDEXAPI_DOM_GROUND";
					if ($cfg->{'dom.ground'}==0) { $method{'skip'} = 'disabled by config.'; }
					}
				else {
					$method{'carrier'} = 'FXIG';
					$method{'ruleset'} = "FEDEXAPI_INT,FEDEXAPI_INT_GROUND";
					if ($cfg->{'int.ground'}==0) { $method{'skip'} = 'disabled by config.'; }
					}
				}
			elsif ($method{'id'} eq 'INTERNATIONAL_FIRST') {
				$method{'carrier'} = 'FXIF';
				$method{'ruleset'} = "FEDEXAPI_INT,FEDEXAPI_INT_NEXTEARLY";
				if ($cfg->{'int.nextearly'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			elsif ($method{'id'} eq 'INTERNATIONAL_PRIORITY') {
				$method{'carrier'} = 'FXIP';
				$method{'ruleset'} = "FEDEXAPI_INT,FEDEXAPI_INT_NEXTNOON";
				if ($cfg->{'int.nextnoon'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			elsif ($method{'id'} eq 'INTERNATIONAL_ECONOMY') {
				$method{'carrier'} = 'FXIE';
				$method{'ruleset'} = "FEDEXAPI_INT,FEDEXAPI_INT_2DAY";
				if ($cfg->{'int.2day'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			#elsif ($method{'id'} eq 'INTERNATIONAL_GROUND') {
			#	$method{'carrier'} = 'FXIG';
			#	$method{'ruleset'} = "FEDEXAPI_INT,FEDEXAPI_INT_GROUND";
			#	if ($cfg->{'int.ground'}==0) { $method{'skip'} = 'disabled by config.'; }
			#	}
			else {
				$method{'skip'} = "Unknown!";
				}

			###############################################
			## now lets copy the properties out of ZSHIP::SHIPCODES
			if ($ZSHIP::SHIPCODES{$method{'carrier'}}) {
				foreach my $k (keys %{$ZSHIP::SHIPCODES{$method{'carrier'}}}) {
					next if (defined $method{$k});
					$method{$k} = $ZSHIP::SHIPCODES{$method{'carrier'}}->{$k};
					}
				$method{'name'} = $method{'method'};
				delete $method{'method'};
				}
			else {
				$method{'name'} = "UNKNOWN CARRIER: $method{'id'}";
				}

			$method{'amount'} = ($use_retail)?$method{'retail_amount'}:$method{'actual_amount'};
			# print F 'amount type: '.Dumper($use_retail,$method{'retail_amount'},$method{'actual_amount'})."\n";

			#################################################
			## RULE PROCESSING
			if (not $method{'skip'}) {
				$method{'pre_rule_amount'} = $method{'amount'};
				my $amount = $method{'amount'};		
				foreach my $ruleset (split(/,/,$method{'ruleset'})) {
					next if (not defined $amount);
					next if ($method{'skip'});
					## RULESET is normally UPSAPI_DOM_ and UPSAPI_DOM_xxx
					my $note = $method{'carrier'} .'|'. $method{'name'};
					#print STDERR "$method{'name'} $method{'ruleset'} AMOUNT: [$amount] ruleset: $ruleset\n";
					($amount) = &ZSHIP::RULES::do_ship_rules($CART2, $PKG, $ruleset, $amount, $note);				
					#print STDERR "$method{'name'} $method{'ruleset'} AFTER AMOUNT: [$amount] ruleset: $ruleset\n";
					$lm->pooshmsg("INFO|+$method{'id'} ran rules: $ruleset amount is now: $amount");
					if (not defined $amount) {
						$method{'skip'} = "disabled by ruleset:$ruleset";
						}
					}
				# $UPSMETHODS{ $method{'carrier'} .'|'. $method{'name'}  } = $amount;
				$method{'amount'} = $amount;
				}
			
			#print F 'METHOD/CFG:'.Dumper(\%method,$cfg);
			#print F "\n\n\n";
			if ($method{'skip'}) {
				$lm->pooshmsg("INFO|+Skipped method: $method{'id'} (reason:$method{'skip'})");
				}
			else {
				$lm->pooshmsg("INFO|+Added method $method{'id'} price:$method{'amount'}");
				push @methods, \%method;
				}

			}
		close F; 
		}
	elsif ($ref->{'RateReplyDetails'}) {
		## on 1/21/13 - FedEx changed their response format for version 7
		 open F, ">/tmp/fedex.$USERNAME";	

		foreach my $ratereplydetail (@{$ref->{'RateReplyDetails'}}) {
			my $flatrrd = &ZTOOLKIT::XMLUTIL::SXMLflatten($ratereplydetail);
			my %method = (
				'zone'=>$flatrrd->{'.RatedShipmentDetails.ShipmentRateDetail.RateZone'},
				'id'=>$flatrrd->{'.ServiceType'},
				'carrier'=>'XXX',
				);
			## fedex response returns both actual and retail rates in RatedShipmentDetails
			print F Dumper($flatrrd)."\n\n";
			foreach my $ratedshipmentdetails (@{$ratereplydetail->{'RatedShipmentDetails'}}) {
				print F 'ratedshipmentdetails: '.Dumper($ratedshipmentdetails);
				my $flatrsd = &ZTOOLKIT::XMLUTIL::SXMLflatten($ratedshipmentdetails);

				if ($flatrsd->{'.ShipmentRateDetail.RateType'} eq 'PAYOR_LIST') {
					$method{'retail_amount'} = $flatrsd->{'.ShipmentRateDetail.TotalNetCharge.Amount'};
					}
				elsif ($flatrsd->{'.ShipmentRateDetail.RateType'} eq 'PAYOR_ACCOUNT') {
					# $method{'actual_amount'} = $flatrsd->{'.ShipmentRateDetail.TotalBaseCharge.Amount'};	# 6.73
					# $method{'actual_amount'} = $flatrsd->{'.ShipmentRateDetail.TotalNetFedExCharge.Amount'};	# 7
					# $flatrsd->{'.ShipmentRateDetail.TotalNetFreight.Amount'};				# 6.39
					# $flatrsd->{'.ShipmentRateDetail.TotalSurcharges.Amount'};				# 0.61
					##	NOTE: surcharges like FUEL etc. appear in @{.ShipmentRateDetail.Surcharges}
					$method{'actual_amount'} = $flatrsd->{'.ShipmentRateDetail.TotalNetCharge.Amount'};				# 7
					# $method{'retail_amount'} = $method{'actual_amount'} + $flatrsd->{'.RatedShipmentDetails.ShipmentRateDetail.TotalFreightDiscounts.Amount'};
					}
				elsif ($flatrsd->{'.ShipmentRateDetail.RateType'} eq 'PAYOR_MULTIWEIGHT') {
					##	NOTE: not sure what the heck this is!?
					}
				elsif ($flatrsd->{'.ShipmentRateDetail.RateType'} eq 'RATED_LIST') {
					##	NOTE: not sure what the heck this is!?
					}
				elsif ($flatrsd->{'.ShipmentRateDetail.RateType'} eq 'RATED_ACCOUNT') {
					##	NOTE: not sure what the heck this is!?
					}
				else {
					$lm->pooshmsg("WARN|+Unknown RateType: ".$flatrsd->{'.ShipmentRateDetail.RateType'});
					}
				}

				#	<xs:enumeration value="EUROPE_FIRST_INTERNATIONAL_PRIORITY"/>
				#	<xs:enumeration value="FEDEX_1_DAY_FREIGHT"/>
				#	<xs:enumeration value="FEDEX_2_DAY"/>
				#	<xs:enumeration value="FEDEX_2_DAY_FREIGHT"/>
				#	<xs:enumeration value="FEDEX_3_DAY_FREIGHT"/>
				#	<xs:enumeration value="FEDEX_EXPRESS_SAVER"/>
				#	<xs:enumeration value="FEDEX_GROUND"/>
				#	<xs:enumeration value="FIRST_OVERNIGHT"/>
				#	<xs:enumeration value="GROUND_HOME_DELIVERY"/>
				#	<xs:enumeration value="INTERNATIONAL_ECONOMY"/>
				#	<xs:enumeration value="INTERNATIONAL_ECONOMY_FREIGHT"/>
				#	<xs:enumeration value="INTERNATIONAL_FIRST"/>
				#	<xs:enumeration value="INTERNATIONAL_PRIORITY"/>
				#	<xs:enumeration value="INTERNATIONAL_PRIORITY_FREIGHT"/>
				#	<xs:enumeration value="PRIORITY_OVERNIGHT"/>
				#	<xs:enumeration value="SMART_POST"/>
				#	<xs:enumeration value="STANDARD_OVERNIGHT"/>
				#	<xs:enumeration value="FEDEX_FREIGHT"/>
				#	<xs:enumeration value="FEDEX_NATIONAL_FREIGHT
			if ($method{'id'} eq 'FIRST_OVERNIGHT') {
				$method{'carrier'} = 'FXFO';
				$method{'ruleset'} = "FEDEXAPI_DOM,FEDEXAPI_DOM_NEXTEARLY";
				if ($cfg->{'dom.nextearly'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			elsif ($method{'id'} eq 'PRIORITY_OVERNIGHT') {
				$method{'carrier'} = 'FXPO';
				$method{'ruleset'} = "FEDEXAPI_DOM,FEDEXAPI_DOM_NEXTNOON";
				if ($cfg->{'dom.nextnoon'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			elsif ($method{'id'} eq 'STANDARD_OVERNIGHT') {
				$method{'carrier'} = 'FXSO';
				$method{'ruleset'} = "FEDEXAPI_DOM,FEDEXAPI_DOM_NEXTDAY";
				if ($cfg->{'dom.nextday'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			elsif ($method{'id'} eq 'FEDEX_2_DAY') {
				$method{'carrier'} = 'FX2D';
				$method{'ruleset'} = "FEDEXAPI_DOM,FEDEXAPI_DOM_2DAY";
				if ($cfg->{'dom.2day'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			elsif ($method{'id'} eq 'FEDEX_EXPRESS_SAVER') {
				$method{'carrier'} = 'FXES';
				$method{'ruleset'} = "FEDEXAPI_DOM,FEDEXAPI_DOM_3DAY";
				if ($cfg->{'dom.3day'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			elsif ($method{'id'} eq 'GROUND_HOME_DELIVERY') {
				$method{'carrier'} = 'FXHD';
				$method{'ruleset'} = "FEDEXAPI_DOM,FEDEXAPI_DOM_HOME";
				if ($cfg->{'dom.home'}>0) {}
				elsif ($cfg->{'dom.home_eve'}) {}
				else { $method{'skip'} = 'disabled by config.'; }
				}
			## GROUND_DELIVERY?					ground	FXGR
			## GROUND_HOME_EVENING_DELIVERY?	home_eve	FXHE
			elsif ($method{'id'} eq 'FEDEX_GROUND') {
				## apparently we can ship ground to us (dom) and canada! (int) what's all dee foos aboot?
				if ($address{'country'} eq 'US') { 
					$method{'carrier'} = 'FXGR';
					$method{'ruleset'} = "FEDEXAPI_DOM,FEDEXAPI_DOM_GROUND";
					if ($cfg->{'dom.ground'}==0) { $method{'skip'} = 'disabled by config.'; }
					}
				else {
					$method{'carrier'} = 'FXIG';
					$method{'ruleset'} = "FEDEXAPI_INT,FEDEXAPI_INT_GROUND";
					if ($cfg->{'int.ground'}==0) { $method{'skip'} = 'disabled by config.'; }
					}
				}
			elsif ($method{'id'} eq 'INTERNATIONAL_FIRST') {
				$method{'carrier'} = 'FXIF';
				$method{'ruleset'} = "FEDEXAPI_INT,FEDEXAPI_INT_NEXTEARLY";
				if ($cfg->{'int.nextearly'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			elsif ($method{'id'} eq 'INTERNATIONAL_PRIORITY') {
				$method{'carrier'} = 'FXIP';
				$method{'ruleset'} = "FEDEXAPI_INT,FEDEXAPI_INT_NEXTNOON";
				if ($cfg->{'int.nextnoon'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			elsif ($method{'id'} eq 'INTERNATIONAL_ECONOMY') {
				$method{'carrier'} = 'FXIE';
				$method{'ruleset'} = "FEDEXAPI_INT,FEDEXAPI_INT_2DAY";
				if ($cfg->{'int.2day'}==0) { $method{'skip'} = 'disabled by config.'; }
				}
			#elsif ($method{'id'} eq 'INTERNATIONAL_GROUND') {
			#	$method{'carrier'} = 'FXIG';
			#	$method{'ruleset'} = "FEDEXAPI_INT,FEDEXAPI_INT_GROUND";
			#	if ($cfg->{'int.ground'}==0) { $method{'skip'} = 'disabled by config.'; }
			#	}
			else {
				$method{'skip'} = "Unknown!";
				}

			###############################################
			## now lets copy the properties out of ZSHIP::SHIPCODES
			if ($ZSHIP::SHIPCODES{$method{'carrier'}}) {
				foreach my $k (keys %{$ZSHIP::SHIPCODES{$method{'carrier'}}}) {
					next if (defined $method{$k});
					$method{$k} = $ZSHIP::SHIPCODES{$method{'carrier'}}->{$k};
					}
				$method{'name'} = $method{'method'};
				delete $method{'method'};
				}
			else {
				$method{'name'} = "UNKNOWN CARRIER: $method{'id'}";
				}

			$method{'amount'} = ($use_retail)?$method{'retail_amount'}:$method{'actual_amount'};
			# print F 'amount type: '.Dumper($use_retail,$method{'retail_amount'},$method{'actual_amount'})."\n";

			#################################################
			## RULE PROCESSING
			if (not $method{'skip'}) {
				$method{'pre_rule_amount'} = $method{'amount'};
				my $amount = $method{'amount'};		
				foreach my $ruleset (split(/,/,$method{'ruleset'})) {
					next if (not defined $amount);
					next if ($method{'skip'});
					## RULESET is normally UPSAPI_DOM_ and UPSAPI_DOM_xxx
					my $note = $method{'carrier'} .'|'. $method{'name'};
					#print STDERR "$method{'name'} $method{'ruleset'} AMOUNT: [$amount] ruleset: $ruleset\n";
					($amount) = &ZSHIP::RULES::do_ship_rules($CART2, $PKG, $ruleset, $amount, $note);				
					#print STDERR "$method{'name'} $method{'ruleset'} AFTER AMOUNT: [$amount] ruleset: $ruleset\n";
					$lm->pooshmsg("INFO|+$method{'id'} ran rules: $ruleset amount is now: $amount");
					if (not defined $amount) {
						$method{'skip'} = "disabled by ruleset:$ruleset";
						}
					}
				# $UPSMETHODS{ $method{'carrier'} .'|'. $method{'name'}  } = $amount;
				$method{'amount'} = $amount;
				}
			
			#print F 'METHOD/CFG:'.Dumper(\%method,$cfg);
			#print F "\n\n\n";
			if ($method{'skip'}) {
				$lm->pooshmsg("INFO|+Skipped method: $method{'id'} (reason:$method{'skip'})");
				}
			else {
				$lm->pooshmsg("INFO|+Added method $method{'id'} price:$method{'amount'}");
				push @methods, \%method;
				}

			}
		close F; 
		}
	elsif ($ref->{'HighestSeverity'}->[0] eq 'ERROR') {
		## THIS ERROR RESPONSE WAS LAST SEEN ON 4/16/14
		$lm->pooshmsg("ISE|+FedEx API returned Severity:ERROR");
		## see /backend/lib/ZSHIP/fedexws-sample-error.xml
		foreach my $notificationmsg (@{ $ref->{'Notifications'} }) {
			$lm->pooshmsg(sprintf(
				"ERROR|API Error Response Source=%s Code=%d Severity=%s Message=%s",
				$notificationmsg->{'Source'}->[0],
				$notificationmsg->{'Code'}->[0],
				$notificationmsg->{'Severity'}->[0],
				$notificationmsg->{'Message'}->[0],
				));
			}
		}
	elsif ($ref->{'ns:HighestSeverity'}->[0] eq 'ERROR') {
		$lm->pooshmsg("ISE|+FedEx API returned Severity:ERROR");
		## see /backend/lib/ZSHIP/fedexws-sample-error.xml
		foreach my $notificationmsg (@{ $ref->{'ns:Notifications'} }) {
			$lm->pooshmsg(sprintf(
				"ERROR|API Error Response Source=%s Code=%d Severity=%s Message=%s",
				$notificationmsg->{'ns:Source'}->[0],
				$notificationmsg->{'ns:Code'}->[0],
				$notificationmsg->{'ns:Severity'}->[0],
				$notificationmsg->{'ns:Message'}->[0],
				));
			}
		}
	else {
		$lm->pooshmsg("ISE|+Did not receive a KNOWN response from FedEx API (check /dev/shm/fedex.unknown)");
		open F, ">/dev/shm/fedex.unknown";
		print F Dumper($ref);
		close F;
		}


	if (scalar(@methods)==0) {
		$lm->pooshmsg("WARN|+No FedEx methods were returned");
		}

	foreach my $msg (@{$lm->msgs()}) {
		$PKG->pooshmsg("API|+FEDEX $msg"); print STDERR "MSG: $msg\n";
		}

	#push @methods, { 
	#	'id'=>'FEDEXWS:xyz', 
	#	'carrier'=>'FDXG',
	#	'name'=>'FedEX Test Method',
	#	'zone'=>1,
	#	'ruleset'=>'xyz',
	#	'amount'=>'1.00',
	#	};
	return(\@methods);
	}




####################################################################
##
##
##
sub standard_header_tags {
	my ($cfg,$VERB,$XMLNS) = @_;

	my @CMDS = ();

	my ($CFG) = CFG->new();

	# <WebAuthenticationDetail xmlns="http://fedex.com/ws/registration/v2">
	push @CMDS, [ 'startTag', "WebAuthenticationDetail",'xmlns'=>$XMLNS ];
		#	<CspCredential> <Key>A4.....</Key>
		#		<Password>Ek.....</Password> </CspCredential>
	 	#	</WebAuthenticationDetail>
		push @CMDS, [ 'startTag', "CspCredential" ];
		push @CMDS, [ 'dataElement', 'Key', $CFG->get("fedex","csp_credential_key") ];
		push @CMDS, [ 'dataElement', 'Password', $CFG->get("fedex","csp_credential_pass") ];
		push @CMDS, [ 'endTag', "CspCredential" ];
		if ($VERB ne 'RegisterWebCspUserRequest') {
			push @CMDS, [ 'startTag', 'UserCredential' ];
				push @CMDS, [ 'dataElement', 'Key', $cfg->{'registration.key'} ];
				push @CMDS, [ 'dataElement', 'Password', $cfg->{'registration.password'} ];
			push @CMDS, [ 'endTag', 'UserCredential' ];
			}
	push @CMDS, [ 'endTag', "WebAuthenticationDetail" ];

	#<ClientDetail xmlns="http://fedex.com/ws/registration/v2">
	#<AccountNumber>############</AccountNumber>
	#<ClientProductId>ZVZV</ClientProductId>
	#<ClientProductVersion>2353</ClientProductVersion> </ClientDetail>	

	push @CMDS, [ 'startTag', "ClientDetail",'xmlns'=>$XMLNS ];
		push @CMDS, [ 'dataElement', 'AccountNumber', $cfg->{'account'} ]; # '25504705 ];
		if ( $cfg->{'meter'} > 0 ) {
			## 20111004 fedex will throw an ise on meter registration if meter is zero
			push @CMDS, [ 'dataElement', 'MeterNumber', $cfg->{'meter'} ];
			}
		push @CMDS, [ 'dataElement', 'ClientProductId', $CFG->get("fedex","csp_client_productid") ];
		push @CMDS, [ 'dataElement', 'ClientProductVersion', $CFG->get("fedex","csp_client_version") ];
		
#				<Localization>
#					<LanguageCode>US</LanguageCode>
#					<LocaleCode>US</LocaleCode>
#				</Localization>
#		push @CMDS, [ 'startTag', 'Localization' ];
#			push @CMDS, [ 'dataElement', 'LanguageCode', 'US' ];
#			push @CMDS, [ 'dataElement', 'LocaleCode', 'US' ];
#		push @CMDS, [ 'endTag', 'Localization' ];
	push @CMDS, [ 'endTag', "ClientDetail" ];

	#		<TransactionDetail>
	#			<CustomerTransactionId/>
	#			<Localization>
	#				<LanguageCode>US</LanguageCode>
	#				<LocaleCode>US</LocaleCode>
	#			</Localization>
	#		</TransactionDetail>
	push @CMDS, [ 'startTag', 'TransactionDetail' ];
		push @CMDS, [ 'dataElement', 'CustomerTransactionId', '' ];
		push @CMDS, [ 'startTag', 'Localization' ];
			push @CMDS, [ 'dataElement', 'LanguageCode', 'US' ];
			push @CMDS, [ 'dataElement', 'LocaleCode', 'US' ];
		push @CMDS, [ 'endTag', 'Localization' ];
	push @CMDS, [ 'endTag', 'TransactionDetail' ];

	#  <Version xmlns="http://fedex.com/ws/registration/v2">
  	#<ServiceId>fcas</ServiceId> <Major>2</Major>
  	#<Intermediate>1</Intermediate> <Minor>0</Minor> </Version>
  	push @CMDS, [ 'startTag', "Version",'xmlns'=>$XMLNS ];
		## RegisterWebCspUserRequest: fcas SubscriptionRequest: fcas all
		## others: crs, 7, 0, 0
		if ($VERB eq 'RateRequest') {
			push @CMDS, [ 'dataElement', 'ServiceId','crs' ];
			push @CMDS, [ 'dataElement', 'Major','7' ];
			push @CMDS, [ 'dataElement', 'Intermediate','0' ];
			push @CMDS, [ 'dataElement', 'Minor','0' ];
			}
		else {
			push @CMDS, [ 'dataElement', 'ServiceId','fcas' ];
			push @CMDS, [ 'dataElement', 'Major','2' ];
			push @CMDS, [ 'dataElement', 'Intermediate','1' ];
			push @CMDS, [ 'dataElement', 'Minor','0' ];
			}
	push @CMDS, [ 'endTag', "Version" ];

	return(\@CMDS);
	}




##
##
##
##
# perl -e 'use lib "/backend/lib"; use ZSHIP::FEDEXAPI2; ZSHIP::FEDEXAPI2::doRequest("brian","RegisterWebCspUserRequest");'
sub doRequest {
	my ($USERNAME,$VERB,$CMDS,%options) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my $webdb = $options{'webdb'};
	my $PRT = int($options{'prt'});
	if (not defined $webdb) {
		$webdb = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);		
		}

	my $xml = '';
	my $writer = new XML::Writer(OUTPUT => \$xml);
	foreach my $tag (@{$CMDS}) {
		my ($writertype,$tagname,@attribs) = @{$tag};
		$writer->$writertype($tagname,@attribs);
		}
	$writer->end();

	$xml = qq~<?xml version="1.0" encoding="utf-8"?>\n$xml\n~;

	my ($md5) = Digest::MD5::md5_base64($xml);
	my ($xmlresponse) = undef;
	my ($memd) = &ZOOVY::getMemd($USERNAME);
	my $MEMCACHE_KEY = uc("FEDEX:$USERNAME:$md5");

	if (defined $memd) {
		($xmlresponse) = $memd->get($MEMCACHE_KEY);
		}	
	
	if ($xmlresponse) {
		}
	else {
		my ($ua) = LWP::UserAgent->new; 
		my ($h) = HTTP::Headers->new();
		my $r = HTTP::Request->new( "POST", "https://gateway.fedex.com/xml/", $h, $xml );

		my ($o) = $ua->request( $r ); 

		($xmlresponse) = $o->content(); 
	
		if ($xmlresponse =~ /(WARNING|SUCCESS)\<\/v7\:HighestSeverity\>/) {
			$memd->set($MEMCACHE_KEY,$xmlresponse,3600);
			}

		open F, ">/dev/shm/fedex.api";	print F Dumper($o,$CMDS);	close F;
		}

	my $xs = new XML::Simple(ForceArray=>1,NSExpand=>0,NoAttr=>1);
	my $ref = undef;
	
	if ($xmlresponse eq '') {
		}
	elsif ($xmlresponse =~ /500 Connect failed/) {
		## yeah fedex is down
		$ref = { 'err'=>1, 'msg'=>'500 Connect Failed' };
		}
	elsif ($xmlresponse =~ /\<HTML\>\<HEAD\>\<TITLE\>/) {
		## yeah fedex is down
		$ref = { 'err'=>1, 'msg'=>'Found HTML instead of XML response from API' };
		}
	else {
		eval { $ref = $xs->XMLin($xmlresponse) };
		if ($@) {
			$ref = { 'err'=>1, 'msg'=>$@,	'xml'=>$xmlresponse };
			}
		}

	return($ref);
	}


1;

__DATA__

