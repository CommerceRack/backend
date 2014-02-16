package ZPAY::AUTHORIZENET;


#  http://www.authorize.net/support/AIM_guide.pdf

sub new { 
	my ($class,$USERNAME,$WEBDB) = @_;	
	my $self = {}; 
	$self->{'%webdb'} = $WEBDB;
	bless $self, 'ZPAY::AUTHORIZENET'; 
	return($self);
	}
 

use LWP::UserAgent;
use HTTP::Request;

use lib '/backend/lib';
require ZPAY;
require ZWEBSITE;
require ZTOOLKIT;
require ZSHIP;
use strict;

my $DEBUG = 1;    # This just outputs debug information to the apache log file

## Got this list from http://www.iso.ch/iso/en/prods-services/iso3166ma/02iso-3166-code-lists/list-en1-semic.txt
## authorizenet does not tell us whether this is indeed the two-letter codes they're using, we had to guess.
%ZPAY::AUTHORIZENET::COUNTRIES = (
	'AFGHANISTAN' => 'AF',
	'ALBANIA' => 'AL',
	'ALGERIA' => 'DZ',
	'AMERICAN SAMOA' => 'AS',
	'ANDORRA' => 'AD',
	'ANGOLA' => 'AO',
	'ANGUILLA' => 'AI',
	'ANTARCTICA' => 'AQ',
	'ANTIGUA/BARBUDA' => 'AG',
	'ARGENTINA' => 'AR',
	'ARMENIA' => 'AM',
	'ARUBA' => 'AW',
	'AUSTRALIA' => 'AU',
	'AUSTRIA' => 'AT',
	'AZERBAIJAN' => 'AZ',
	'BAHAMAS' => 'BS',
	'BAHRAIN' => 'BH',
	'BANGLADESH' => 'BD',
	'BARBADOS' => 'BB',
	'BELARUS' => 'BY',
	'BELGIUM' => 'BE',
	'BELIZE' => 'BZ',
	'BENIN' => 'BJ',
	'BERMUDA' => 'BM',
	'BHUTAN' => 'BT',
	'BOLIVIA' => 'BO',
	'BOSNIA/HERZEGOVINA' => 'BA',
	'BOTSWANA' => 'BW',
	'BOUVET ISLAND' => 'BV',
	'BRAZIL' => 'BR',
	'BRIT. INDIAN OCEAN' => 'IO',
	'BRUNEI DARUSSALAM' => 'BN',
	'BULGARIA' => 'BG',
	'BURKINA FASO' => 'BF',
	'BURUNDI' => 'BI',
	'CAMBODIA' => 'KH',
	'CAMEROON' => 'CM',
	'CANADA' => 'CA',
	'CAPE VERDE' => 'CV',
	'CAYMAN ISLANDS' => 'KY',
	'CENTRAL AFRICAN REP.' => 'CF',
	'CHAD' => 'TD',
	'CHILE' => 'CL',
	'CHINA' => 'CN',
	'CHRISTMAS ISLAND' => 'CX',
	'COCOS (KEELING) ISL.' => 'CC',
	'COLOMBIA' => 'CO',
	'COMOROS' => 'KM',
	'CONGO' => 'CG',
	'CONGO, THE DEMOCRATIC REPUBLIC OF THE' => 'CD',
	'COOK ISLANDS' => 'CK',
	'COSTA RICA' => 'CR',
	'IVORY COAST' => 'CI',
	'CROATIA' => 'HR',
	'CUBA' => 'CU',
	'CYPRUS' => 'CY',
	'CZECH REPUBLIC' => 'CZ',
	'DENMARK' => 'DK',
	'DJIBOUTI' => 'DJ',
	'DOMINICA' => 'DM',
	'DOMINICAN REPUBLIC' => 'DO',
	'ECUADOR' => 'EC',
	'EGYPT' => 'EG',
	'EL SALVADOR' => 'SV',
	'EQUATORIAL GUINEA' => 'GQ',
	'ERITREA' => 'ER',
	'ESTONIA' => 'EE',
	'ETHIOPIA' => 'ET',
	'FALKLAND ISLANDS' => 'FK',
	'FAROE ISLANDS' => 'FO',
	'FIJI' => 'FJ',
	'FINLAND' => 'FI',
	'FRANCE' => 'FR',
	'FRENCH GUIANA' => 'GF',
	'FRENCH POLYNESIA' => 'PF',
	'FRENCH SOUTH TER.' => 'TF',
	'GABON' => 'GA',
	'GAMBIA' => 'GM',
	'GEORGIA' => 'GE',
	'GERMANY' => 'DE',
	'GHANA' => 'GH',
	'GIBRALTAR' => 'GI',
	'GREECE' => 'GR',
	'GREENLAND' => 'GL',
	'GRENADA' => 'GD',
	'GUADELOUPE' => 'GP',
	'GUAM' => 'GU',
	'GUATEMALA' => 'GT',
	'GUINEA' => 'GN',
	'GUINEA-BISSAU' => 'GW',
	'GUYANA' => 'GY',
	'HAITI' => 'HT',
	'HEARD AND MCDONALD' => 'HM',
	'VATICAN CITY' => 'VA',
	'HONDURAS' => 'HN',
	'HONG KONG' => 'HK',
	'HUNGARY' => 'HU',
	'ICELAND' => 'IS',
	'INDIA' => 'IN',
	'INDONESIA' => 'ID',
	'IRAN' => 'IR',
	'IRAQ' => 'IQ',
	'IRELAND' => 'IE',
	'ISRAEL' => 'IL',
	'ITALY' => 'IT',
	'JAMAICA' => 'JM',
	'JAPAN' => 'JP',
	'JORDAN' => 'JO',
	'KAZAKHSTAN' => 'KZ',
	'KENYA' => 'KE',
	'KIRIBATI' => 'KI',
	'KOREA, NORTH' => 'KP',
	'KOREA, SOUTH' => 'KR',
	'KUWAIT' => 'KW',
	'KYRGYZSTAN' => 'KG',
	'LAO PEOPLE REPUBLIC' => 'LA',
	'LATVIA' => 'LV',
	'LEBANON' => 'LB',
	'LESOTHO' => 'LS',
	'LIBERIA' => 'LR',
	'LIBYAN ARAB JAMAHIR.' => 'LY',
	'LIECHTENSTEIN' => 'LI',
	'LITHUANIA' => 'LT',
	'LUXEMBOURG' => 'LU',
	'MACAO' => 'MO',
	'MACEDONIA' => 'MK',
	'MADAGASCAR' => 'MG',
	'MALAWI' => 'MW',
	'MALAYSIA' => 'MY',
	'MALDIVES' => 'MV',
	'MALI' => 'ML',
	'MALTA' => 'MT',
	'MARSHALL ISLANDS' => 'MH',
	'MARTINIQUE' => 'MQ',
	'MAURITANIA' => 'MR',
	'MAURITIUS' => 'MU',
	'MAYOTTE' => 'YT',
	'MEXICO' => 'MX',
	'MICRONESIA' => 'FM',
	'MOLDOVA' => 'MD',
	'MONACO' => 'MC',
	'MONGOLIA' => 'MN',
	'MONTSERRAT' => 'MS',
	'MOROCCO' => 'MA',
	'MOZAMBIQUE' => 'MZ',
	'MYANMAR' => 'MM',
	'NAMIBIA' => 'NA',
	'NAURU' => 'NR',
	'NEPAL' => 'NP',
	'NETHERLANDS' => 'NL',
	'NETHERLANDS ANTILLES' => 'AN',
	'NEW CALEDONIA' => 'NC',
	'NEW ZEALAND' => 'NZ',
	'NICARAGUA' => 'NI',
	'NIGER' => 'NE',
	'NIGERIA' => 'NG',
	'NIUE' => 'NU',
	'NORFOLK ISLAND' => 'NF',
	'NORTHERN MARIANA ISL.' => 'MP',
	'NORWAY' => 'NO',
	'OMAN' => 'OM',
	'PAKISTAN' => 'PK',
	'PALAU' => 'PW',
	'PALESTINIAN TERRITORY, OCCUPIED' => 'PS',
	'PANAMA' => 'PA',
	'PAPUA NEW GUINEA' => 'PG',
	'PARAGUAY' => 'PY',
	'PERU' => 'PE',
	'PHILIPPINES' => 'PH',
	'PITCAIRN' => 'PN',
	'POLAND' => 'PL',
	'PORTUGAL' => 'PT',
	'PUERTO RICO' => 'PR',
	'QATAR' => 'QA',
	'REUNION' => 'RE',
	'ROMANIA' => 'RO',
	'RUSSIA' => 'RU',
	'RWANDA' => 'RW',
	'ST. HELENA' => 'SH',
	'ST. KITTS AND NEVIS' => 'KN',
	'ST. LUCIA' => 'LC',
	'ST. PIERRE AND MIQUELON' => 'PM',
	'ST. VINCENT AND THE GRENADINES' => 'VC',
	'SAMOA' => 'WS',
	'SAN MARINO' => 'SM',
	'SAO TOME/PRINCIPE' => 'ST',
	'SAUDI ARABIA' => 'SA',
	'SENEGAL' => 'SN',
	'SERBIA AND MONTENEGRO' => 'CS',
	'SEYCHELLES' => 'SC',
	'SIERRA LEONE' => 'SL',
	'SINGAPORE' => 'SG',
	'SLOVAKIA' => 'SK',
	'SLOVENIA' => 'SI',
	'SOLOMON ISLANDS' => 'SB',
	'SOMALIA' => 'SO',
	'SOUTH AFRICA' => 'ZA',
	'SOUTH GEORGIA AND THE SOUTH SANDWICH ISLANDS' => 'GS',
	'SPAIN' => 'ES',
	'SRI LANKA' => 'LK',
	'SUDAN' => 'SD',
	'SURINAME' => 'SR',
	'SVALBARD/JAN MAYEN' => 'SJ',
	'SWAZILAND' => 'SZ',
	'SWEDEN' => 'SE',
	'SWITZERLAND' => 'CH',
	'SYRIAN ARAB REPUBLIC' => 'SY',
	'TAIWAN, PROVINCE OF CHINA' => 'TW',
	'TAJIKISTAN' => 'TJ',
	'TANZANIA, UNITED REPUBLIC OF' => 'TZ',
	'THAILAND' => 'TH',
	'TIMOR-LESTE' => 'TL',
	'TOGO' => 'TG',
	'TOKELAU' => 'TK',
	'TONGA' => 'TO',
	'TRINIDAD AND TOBAGO' => 'TT',
	'TUNISIA' => 'TN',
	'TURKEY' => 'TR',
	'TURKMENISTAN' => 'TM',
	'TURKS AND CAICOS ISL.' => 'TC',
	'TUVALU' => 'TV',
	'UGANDA' => 'UG',
	'UKRAINE' => 'UA',
	'UNITED ARAB EMIRATES' => 'AE',
	'UNITED KINGDOM' => 'GB',
	'UNITED STATES' => 'US',
	'UNITED STATES MINOR OUTLYING ISLANDS' => 'UM',
	'URUGUAY' => 'UY',
	'UZBEKISTAN' => 'UZ',
	'VANUATU' => 'VU',
	'VENEZUELA' => 'VE',
	'VIET NAM' => 'VN',
	'BRITISH VIRGIN ISL.' => 'VG',
	'VIRGIN ISLANDS' => 'VI',
	'WALLIS / FUTUNA' => 'WF',
	'WESTERN SAHARA' => 'EH',
	'YEMEN' => 'YE',
	'ZAMBIA' => 'ZM',
	'ZIMBABWE' => 'ZW',
);


##############################################################################
# AUTHORIZE.NET FUNCTIONS

# Docs at https://secure.authorize.net/docs/

# WE ARE USING VERSION 3.1 OF THE AUTHORIZENET API

sub authorizenet_whitelist {
	return qw(x_response_code x_response_subcode x_response_reason_code x_auth_code x_avs_code x_trans_id x_card_code_response_code);
	}

########################################
# AUTHORIZENET AUTHORIZE
sub authorize { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('AUTHORIZE',$O2,$payrec,$payment)); }
sub capture { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CAPTURE',$O2,$payrec,$payment)); }
sub charge { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('CHARGE',$O2,$payrec,$payment)); }
sub void { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('VOID',$O2,$payrec,$payment)); }
sub credit { my ($self, $O2, $payrec, $payment) = @_; return($self->unified('REFUND',$O2,$payrec,$payment)); } 


##
## takes an order object, and prepares all the correct authorize.net call parameters.
##
sub build_order_params {
	my ($O2) = @_;


	my $billaddr = $O2->in_get('bill/address1'); 
	my $shipaddr = $O2->in_get('ship/address1');
	if ($O2->in_get('bill/address2') ne '') { $billaddr .= ' ' . $O2->in_get('bill/address2'); }
	if ($O2->in_get('ship/address2') ne '') { $shipaddr .= ' ' . $O2->in_get('ship/address2'); }
	
	my $bill_state = gstr($O2->in_get('bill/region'));
	my $ship_state = gstr($O2->in_get('ship/region'));

	my $bill_zip   = gstr($O2->in_get('bill/postal'));
	my $ship_zip   = gstr($O2->in_get('ship/postal'));

	my $params = {
		'x_invoice_num'        => $O2->oid(),
		'x_address'            => $billaddr,
		'x_zip'                => $bill_zip,
		'x_city'               => $O2->in_get('bill/city'),
		'x_state'              => $bill_state,
		'x_company'            => $O2->in_get('bill/company'),
		'x_country'            => fix_country($O2->in_get('bill/countrycode')),
		'x_description'        => "Order number ".$O2->oid(),
		'x_email'              => $O2->in_get('bill/email'),
		'x_email_customer'     => 'FALSE',
		'x_phone'              => $O2->in_get('bill/phone'),
		'x_first_name'         => $O2->in_get('bill/firstname'),
		'x_last_name'          => $O2->in_get('bill/lastname'),
		'x_tax'                => &ZTOOLKIT::cashy($O2->in_get('sum/tax_total')),
		'x_ship_to_address'    => $shipaddr,
		'x_ship_to_city'       => $O2->in_get('ship/city'),
		'x_ship_to_company'    => $O2->in_get('ship/company'),
		'x_ship_to_country'    => fix_country($O2->in_get('ship/countrycode')),
		'x_ship_to_first_name' => $O2->in_get('ship/firstname'),
		'x_ship_to_last_name'  => $O2->in_get('ship/lastname'),
		'x_ship_to_state'      => $ship_state,
		'x_ship_to_zip'        => $ship_zip,
		'x_fax'                => '000-000-0000',
		'x_cust_id'            => $O2->in_get('bill/email'),
		'x_freight'            => &ZTOOLKIT::cashy($O2->in_get('sum/shp_total')),
		'x_customer_ip'        => $O2->in_get('cart/ip_address'),
		};

	## BH: added x_province and x_ship_to_province support 3/8/04
	## BH: deleted x_ship_to_province if it's blank - since authorize.net returns an error 3/20/04		
	## BH: Apparently they don't validate it, but they require it .. welcome to FooLand
	if (defined $params->{'x_ship_to_country'} ne 'US') { 
		$params->{'x_ship_to_province'} = $params->{'x_ship_to_state'}; 
		if ($params->{'x_ship_to_province'} eq '') { $params->{'x_ship_to_province'} = 'FooLand'; }	
		}
	if (defined $params->{'x_country'} ne 'US') { 
		$params->{'x_province'} = $params->{'x_state'}; 
		if ($params->{'x_province'} eq '') { $params->{'x_province'} = 'FooLand'; }
		}

	return($params);
	}



######################################################################
##
##  this is the primary "magic" routine for authorize.net
##
sub unified {
	my ($self, $VERB, $O2, $payrec, $payment) = @_;

	my $RESULT = undef;

	if ((not defined $O2) || (ref($O2) ne 'CART2')) { 
		$RESULT = "999|Order was not defined"; 
		}
	elsif (($payrec->{'tender'} ne 'CREDIT') && ($payrec->{'tender'} ne 'ECHECK')) {
		$RESULT = "900|tender:$payrec->{'tender'} unknown";
		}
	elsif (($VERB eq 'AUTHORIZE') && ($payrec->{'tender'} eq 'ECHECK')) {
		$RESULT = "252|ECHECK does not support $VERB";
		}
	elsif (($VERB eq 'CAPTURE') && ($payrec->{'tender'} eq 'ECHECK')) {
		$RESULT = "252|ECHECK does not support $VERB";
		}
	elsif ($payrec->{'amt'}<=0) {
		$RESULT = "901|amt is a required field and must be greater than zero.";
		}
	elsif (($VERB eq 'CAPTURE') && ($payrec->{'tender'} eq 'CREDIT') && 
		($payment->{'CM'} eq '') && ($payment->{'CC'} eq '')) { 
		$RESULT = "252|Payment variables CC or CM are required!";
		}

	my $params = {};
	if (defined $RESULT) {
		}
	elsif ($payrec->{'tender'} eq 'ECHECK') {
		($params) = &ZPAY::AUTHORIZENET::build_order_params($O2);
		$params->{'x_method'}         = 'ECHECK';
		$params->{'x_bank_aba_code'}  = $payment->{'ER'}; # $O2->in_get(('echeck_aba_number');
		$params->{'x_bank_acct_num'}  = $payment->{'EA'}; # orderref->{'echeck_acct_number'};
		$params->{'x_bank_acct_type'} = 'CHECKING';
		$params->{'x_bank_name'}      = $payment->{'EB'}; # $O2->in_get(('echeck_bank_name');
		$params->{'x_bank_acct_name'} = $payment->{'EN'}; # $O2->in_get(('echeck_acct_name');
		$params->{'x_echeck_type'}  	= 'WEB';
		}
	elsif (($payrec->{'tender'} eq 'CREDIT') && (($VERB eq 'AUTHORIZE') || ($VERB eq 'CHARGE')) ) {
		($params) = &ZPAY::AUTHORIZENET::build_order_params($O2);
		#'x_method'             => 'CC',
		#'x_card_num'           => $O2->in_get(('card_number'),
		#'x_exp_date'           => $O2->in_get(('card_exp_month') . $O2->in_get(('card_exp_year'),
		#'x_customer_tax_id'    => $O2->in_get(('tax_id'),
		#'x_drivers_license_num'   => $O2->in_get(('drivers_license_number'),
		#'x_drivers_license_state' => $O2->in_get(('drivers_license_state'),
		#'x_drivers_license_dob'   => $O2->in_get(('drivers_license_dob'),
		#'x_customer_organization_type' => gstr($O2->in_get(('business_account'),$O2->in_get('bill/company')) ? 'B' : 'I',
		$params->{'x_method'} = 'CC';
		$params->{'x_card_num'} = $payment->{'CC'};
		$params->{'x_exp_date'} = $payment->{'MM'} . $payment->{'YY'};					
		$params->{'x_card_code'} = '';
		if (defined($payment->{'CV'}) && ($payment->{'CV'} =~ m/^\d\d\d\d?$/)) {
			$params->{'x_card_code'} = $payment->{'CV'};
			}
		}
	elsif (($payrec->{'tender'} eq 'CREDIT') && ($VERB eq 'REFUND')) {
		($params) = &ZPAY::AUTHORIZENET::build_order_params($O2);
		$params->{'x_method'} = 'CC';
		$params->{'x_card_num'} = $payment->{'CM'}; # use the masked card
		$params->{'x_exp_date'} = $payment->{'MM'} . $payment->{'YY'};					
		}

	my $webdbref = undef;
	if (not defined $RESULT) {
		my $USERNAME = $O2->username();
		my $PRT = $O2->prt();
		$webdbref = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
		}

	## THIS PROBABLY ISN'T NECESSARY ANYMORE since it's in ORDER.pm
	if (($VERB eq 'CAPTURE') && ($payrec->{'ps'} eq '109')) {
		## status 109 is a special auth.net option called "NOAUTH_DELAY" where it stores the CC in the ACCT #
		## and we need to do a CHARGE

		my $kvs = &ZPAY::unpackit($payrec->{'acct'});
		foreach my $k ('CC','YY','MM','CV') { $payment->{$k} = $kvs->{$k}; } 	# copy CC,YY,MM into $payment
		$O2->add_history("NOAUTH_DELAY[PS=109] changed VERB=CAPTURE to VERB=CHARGE",'luser'=>'*AUTHNET');
		$VERB = 'CHARGE';
		}

	my $AMT = $payrec->{'amt'};
	if (defined $payment->{'amt'}) {
		$AMT = $payment->{'amt'};
		}

	my $api = undef;
	if (defined $RESULT) {
		}
	elsif ($VERB eq 'AUTHORIZE') {
		$params->{'x_amount'} = &ZTOOLKIT::cashy($AMT);
		$params->{'x_type'} = 'AUTH_ONLY';
		($api) = &authorizenet_call($O2, $webdbref, $params);
		$payrec->{'auth'} = $api->{'x_auth_code'};
		$payrec->{'txn'} = $api->{'x_trans_id'};
		}
	elsif ($VERB eq 'CAPTURE') {
		$params->{'x_type'} = 'PRIOR_AUTH_CAPTURE';
		$params->{'x_amount'} = &ZTOOLKIT::cashy($AMT);
		$params->{'x_trans_id'} = $payrec->{'txn'};  # orderref->{'cc_auth_transaction'}; # the id of the original transactions	
		$params->{'x_auth_id'} = $payrec->{'auth'};  
		#if ($payrec->{'uuid'} eq 'ORDERV4') {
		#	$params->{'x_trans_id'} = $O2->get_attrib('cc_auth_transaction');
		#	# if ($params->{'x_trans_id'} eq '') { $params->{'x_trans_id'} = 'xyz'; }
		#	$params->{'x_auth_id'} = $O2->get_attrib('cc_authorization');
		#	}
		($api) = &authorizenet_call($O2, $webdbref, $params);
		}
	elsif ($VERB eq 'CHARGE') {
		$params->{'x_type'} = 'AUTH_CAPTURE';
		$params->{'x_amount'} = &ZTOOLKIT::cashy($AMT);
		($api) = &authorizenet_call($O2, $webdbref, $params);
		$payrec->{'auth'} = $api->{'x_auth_code'};
		$payrec->{'txn'} = $api->{'x_trans_id'};
		}
	elsif ($VERB eq 'VOID') {
 		$params->{'x_card_num'} =~ /.*(\d\d\d\d)$/;
		$params->{'x_card_num'} = $1;
		$params->{'x_type'} = 'VOID';
		$params->{'x_trans_id'} = $payrec->{'txn'}; # $O2->in_get(('cc_bill_transaction');
		($api) = &authorizenet_call($O2, $webdbref, $params);
		}
	elsif ($VERB eq 'REFUND') {
		$params->{'x_type'} = 'CREDIT';
		$params->{'x_amount'} = &ZTOOLKIT::cashy($AMT);
		$params->{'x_trans_id'} = $payrec->{'txn'}; # $O2->in_get(('cc_bill_transaction'),
	
		## PATTI: parsed x_card_num to only pass last 4 digits 9/6/2005	
		$params->{'x_card_num'} =~ /.*(\d\d\d\d)$/;
		$params->{'x_card_num'} = $1;
		($api) = &authorizenet_call($O2, $webdbref, $params);
		}
	## other x_types: CAPTURE_ONLY for voice auth

	my $USERNAME = $O2->username();
	my $PRT = $O2->prt();
	my $RS = undef;
	my %k = ();			## KOUNT settings.

	if (defined $api) {
		my $trans      = def($api->{'x_trans_id'});
		my $auth       = def($api->{'x_auth_code'});
		my $error      = def($api->{'ERROR'});
		my $respcode   = def($api->{'x_response_code'});
		my $reasoncode     = def($api->{'x_response_reason_code'});
		my $reasontext = def($api->{'x_response_reason_text'});
		my $avs        = def($api->{'x_avs_code'});
		my $cardcode   = def($api->{'x_card_code_response_code'});
		my $method     = def($api->{'x_method'},'CC');
		if (length("$cardcode") > 1) { $cardcode = ''; }

		$DEBUG && &msg("\$error is '$error'");
		$DEBUG && &msg("\$respcode is '$respcode'");
		$DEBUG && &msg("\$reasoncode is '$reasoncode'");
		$DEBUG && &msg("\$reasontext is '$reasontext'");
		$DEBUG && &msg("\$avs is '$avs'");
		$DEBUG && &msg("\$cardcode is '$cardcode'");
		$DEBUG && &msg("\$method is '$method'");

		$RESULT = "257|Unrecognized response code $reasontext";
		if ($error ne '') {
			# A variety of network and SSL problems
			$RESULT = "249|Unable to contact authorizenet server";
			}
		elsif ($respcode == 1) {
			if ($params->{'x_type'} eq 'VOID') { 
				$RESULT = "603|Successfully VOID transaction";
				}
			elsif ($params->{'x_type'} eq 'CREDIT') {
				## See incident 7540 ... authorizenet sends back an auth of 000000... with a response code of 1
				## for credits.  This is actually a success for credits where it would indicate a
				## misconfiguration on debits.  (See incident referred to in next block)
				$RESULT = "303|Successfully credited transaction";
				}
			elsif (($auth =~ m/^0*$/) && ($payrec->{'tender'} ne 'ECHECK'))  {
				## See incident 5670 ...  authorizenet is sending back response codes of 1 with an all-zero authorization.
				## The transaction on the all-zero auth did not appear in the merchant's account or on the customer's statement -AK
				## This will match blank too just in case
				##
				## NOTE: apparently e-check does not send an $auth code, or if it does, it's crap!
				## 	see ticket #107287 6/2/05
				$RESULT = "257|Authorizenet incorrectly formatted the transaction response code good but authorization $auth ['.$auth.'] is bogus.";
				}
			elsif ($payrec->{'tender'} eq 'ECHECK') {
				if ($VERB eq 'AUTHORIZE') {
					$RESULT = "120|eCheck Authorized";
					}
				else {
					$RESULT = "060|eCheck Charged";
					}
				}
			elsif (($payrec->{'tender'} eq 'CREDIT') && ($params->{'x_type'} eq 'AUTH_ONLY')) {
				$RESULT = "199|Authorized";
				}
			elsif (($payrec->{'tender'} eq 'CREDIT') && ($params->{'x_type'} eq 'AUTH_CAPTURE')) {
				$RESULT = "001|Instant Capture";
				}
			elsif (($payrec->{'tender'} eq 'CREDIT') && ($params->{'x_type'} eq 'PRIOR_AUTH_CAPTURE')) {
				$RESULT = "002|Payment Captured";			
				}
			else {
				$RESULT = "257|Got success, but unknown handler for x_type$params->{'x_type'}";
				}
			}
		elsif (($respcode == 2) || ($respcode == 3)) {
			if ($reasoncode == 1)   { 
				if ($payrec->{'tender'} eq 'ECHECK') { $RESULT = "120|Approved with failure response code"; }
				elsif (($payrec->{'tender'} eq 'CREDIT') && ($params->{'x_type'} eq 'AUTH_ONLY')) { $RESULT = "199|Approved with failure response code"; }
				elsif (($payrec->{'tender'} eq 'CREDIT') && ($params->{'x_type'} eq 'AUTH_CAPTURE')) { $RESULT = "001|Approved with failure response code"; }
				elsif ($payrec->{'tender'} eq 'CREDIT') { $RESULT = "002|Approved with failure response code"; }
				else { $RESULT = "257|Approved with unknown failure response code"; }
				}                                                                                                                                       # Good card...  bad response???
			elsif ($reasoncode == 2)   { $RESULT = "200|General decline"; }                                                                                                                                                           # soft fail (NSF)
			elsif ($reasoncode == 3)   { $RESULT = "200|General decline"; }
			elsif ($reasoncode == 4)   { $RESULT = "206|DECLINED"; }                                                                                                                                                                  # hard fail (keep card)
			elsif ($reasoncode == 5)   { $RESULT = "253|Invalid Amount"; }
			elsif ($reasoncode == 6)   { $RESULT = "253|Invalid Credit Card Number"; }
			elsif ($reasoncode == 7)   { $RESULT = "253|Invalid Credit Card Expiration Date"; }
			elsif ($reasoncode == 8)   { $RESULT = "200|Credit Card Is Expired"; }
			elsif ($reasoncode == 9)   { $RESULT = "255|Invalid bank routing / ABA Code"; }
			elsif ($reasoncode == 10)  { $RESULT = "255|Invalid Account Number"; }
			elsif ($reasoncode == 11)  { $RESULT = "261|Duplicate Transaction Try again in 2 minutes"; }
			elsif ($reasoncode == 12)  { $RESULT = "253|Authorization Code is Required but is not present"; }
			elsif ($reasoncode == 13)  { $RESULT = "255|Invalid Merchant Login or Account Inactive"; }
			elsif ($reasoncode == 14)  { $RESULT = "253|Merchant configuration error - Invalid Referrer or Relay Response URL"; }
			elsif ($reasoncode == 15)  { $RESULT = "256|Invalid Transaction ID"; }
			elsif ($reasoncode == 16)  { $RESULT = "256|Transaction Not Found"; }
			elsif ($reasoncode == 17)  { $RESULT = "252|The Merchant does not accept this type of Credit Card"; }
			elsif ($reasoncode == 18)  { $RESULT = "252|ACH Transactions are not accepted by this Merchant"; }
			elsif ($reasoncode == 19)  { $RESULT = "250|An Authorizenet error occurred during processing - Try again in 5 minutes"; }
			elsif ($reasoncode == 20)  { $RESULT = "250|An Authorizenet error occurred during processing - Try again in 5 minutes"; }
			elsif ($reasoncode == 21)  { $RESULT = "250|An Authorizenet error occurred during processing - Try again in 5 minutes"; }
			elsif ($reasoncode == 22)  { $RESULT = "250|An Authorizenet error occurred during processing - Try again in 5 minutes"; }
			elsif ($reasoncode == 23)  { $RESULT = "250|An Authorizenet error occurred during processing - Try again in 5 minutes"; }
			elsif ($reasoncode == 24)  { $RESULT = "255|Nova Bank Number or Terminal ID is incorrect - Call Merchant Service Provider"; }
			elsif ($reasoncode == 25)  { $RESULT = "250|An Authorizenet error occurred during processing - Try again in 5 minutes"; }
			elsif ($reasoncode == 26)  { $RESULT = "250|An Authorizenet error occurred during processing - Try again in 5 minutes"; }
			elsif ($reasoncode == 27)  { $RESULT = "205|Address provided does not match billing address of cardholder"; }
			elsif ($reasoncode == 28)  { $RESULT = "252|The Merchant does not accept this type of Credit Card"; }
			elsif ($reasoncode == 29)  { $RESULT = "255|Paymentech identification numbers are incorrect - Call Merchant Service Provider"; }
			elsif ($reasoncode == 30)  { $RESULT = "255|Invalid configuration with Processor - Call Merchant Service Provider"; }
			elsif ($reasoncode == 31)  { $RESULT = "255|FDC Merchant ID or Terminal ID is incorrect - Call Merchant Service Provider"; }
			elsif ($reasoncode == 32)  { $RESULT = "255|This reason code is reserved or not applicable to this API."; }
			elsif ($reasoncode == 33)  { $RESULT = "209|$reasontext"; }
			elsif ($reasoncode == 34)  { $RESULT = "255|VITAL identification numbers are incorrect - Call Merchant Service Provider"; }
			elsif ($reasoncode == 35)  { $RESULT = "255|An error occurred during processing - Call Merchant Service Provider"; }
			elsif ($reasoncode == 36)  { $RESULT = "200|Approved authorization failed settlement"; }
			elsif ($reasoncode == 37)  { $RESULT = "200|Invalid Credit Card Number"; }
			elsif ($reasoncode == 38)  { $RESULT = "255|Global Payment System identification numbers are incorrect - Call Merchant Service Provider"; }
			elsif ($reasoncode == 39)  { $RESULT = "255|Supplied Currency Code is invalid not supported not allowed for this Merchant or does not have an Exchange Rate"; }
			elsif ($reasoncode == 40)  { $RESULT = "257|Transaction must be encrypted"; }
			elsif ($reasoncode == 41)  { $RESULT = "206|Transaction has been declined high fraud score"; }
#			elsif ($reasoncode == 42)  { $RESULT = "254|Merlin required field was missing"; }
			elsif ($reasoncode == 43)  { $RESULT = "255|The merchant was incorrectly set up at the processor. Call your Merchant Service Provider.	"; }
#			elsif ($reasoncode == 43)  { $RESULT = "255|Invalide Merlin terminal ID"; }
			elsif ($reasoncode == 44)  { $RESULT = "207|Transaction has been declined"; }
			elsif ($reasoncode == 45)  { $RESULT = "207|Card Code Mismatch with AVS"; }
			elsif ($reasoncode == 46)  { $RESULT = "250|Session Expired Error"; }
			elsif ($reasoncode == 47)  { $RESULT = "253|Amount requested for settlement may not be greater than the original amount authorized"; }
			elsif ($reasoncode == 48)  { $RESULT = "252|Processor does not accept partial reversals"; }
			elsif ($reasoncode == 49)  { $RESULT = "253|Transaction amount greater than $99999 will not be accepted"; }
			elsif ($reasoncode == 50)  { $RESULT = "258|Transaction is awaiting settlement and cannot be refunded"; }
			elsif ($reasoncode == 51)  { $RESULT = "256|Sum of all credits against this transaction is greater than the original amount"; }
			elsif ($reasoncode == 52)  { $RESULT = "250|Transaction was authorized but the client could not be notified - the transaction will not be settled"; }
			elsif ($reasoncode == 53)  { $RESULT = "256|Transaction type was invalid for ACH transactions"; }
			elsif ($reasoncode == 54)  { $RESULT = "256|Referenced transaction does not meet the criteria for issuing a credit"; }
			elsif ($reasoncode == 55)  { $RESULT = "256|Sum of credits against the referenced transaction would exceed the original debit amount"; }
			elsif ($reasoncode == 56)  { $RESULT = "252|Merchant accepts ACH transactions only - no credit card transactions are accepted"; }
			elsif ($reasoncode == 57)  { $RESULT = "250|An error occurred in processing - Please try again in 5 minutes"; }
			elsif ($reasoncode == 58)  { $RESULT = "250|An error occurred in processing - Please try again in 5 minutes"; }
			elsif ($reasoncode == 59)  { $RESULT = "250|An error occurred in processing - Please try again in 5 minutes"; }
			elsif ($reasoncode == 60)  { $RESULT = "250|An error occurred in processing - Please try again in 5 minutes"; }
			elsif ($reasoncode == 61)  { $RESULT = "250|An error occurred in processing - Please try again in 5 minutes"; }
			elsif ($reasoncode == 62)  { $RESULT = "250|An error occurred in processing - Please try again in 5 minutes"; }
			elsif ($reasoncode == 63)  { $RESULT = "250|An error occurred in processing - Please try again in 5 minutes"; }
#			elsif ($reasoncode == 64)  { $RESULT = "256|Wells Fargo SecureSource error - Credits or refunds cannot be issued against transactions that were not authorized try modifying your instant/delayed capture settings"; }
			elsif ($reasoncode == 65)  { $RESULT = "207|Card Code mismatch - merchant configured their account to reject transactions - Try setting CVV/CID to Required and verifying Card Data e.g. Number/Expiration"; }
			elsif ($reasoncode == 66)  { $RESULT = "251|Transaction did not meet gateway security requirements"; }
#			elsif ($reasoncode == 67)  { $RESULT = "252|Wells Fargo SecureSource error - The given transaction type is not supported for this merchant Wells Fargo does not support capture only"; }
			elsif ($reasoncode == 68)  { $RESULT = "253|Version parameter invalid"; }
			elsif ($reasoncode == 69)  { $RESULT = "253|Transaction type invalid"; }
			elsif ($reasoncode == 70)  { $RESULT = "253|Transaction method is invalid"; }
			elsif ($reasoncode == 71)  { $RESULT = "253|Bank account type is invalid"; }
			elsif ($reasoncode == 72)  { $RESULT = "253|Authorization code is invalid"; }
			elsif ($reasoncode == 73)  { $RESULT = "253|Drivers license date of birth is invalid"; }
			elsif ($reasoncode == 74)  { $RESULT = "253|Duty amount is invalid"; }
			elsif ($reasoncode == 75)  { $RESULT = "253|Freight amount is invalid"; }
#			elsif ($reasoncode == 76)  { $RESULT = "253|Tax amount is invalid"; }
			elsif ($reasoncode == 77)  { $RESULT = "253|SSN or tax ID is invalid"; }
			elsif ($reasoncode == 78)  { $RESULT = "207|Card Code CVV2/CVC2/CID is invalid"; }
			elsif ($reasoncode == 79)  { $RESULT = "253|Drivers license number is invalid"; }
			elsif ($reasoncode == 80)  { $RESULT = "253|Drivers license state is invalid"; }
			elsif ($reasoncode == 81)  { $RESULT = "253|Requested form type is invalid"; }
			elsif ($reasoncode == 82)  { $RESULT = "259|Scripts are only supported in version 2.5"; }
			elsif ($reasoncode == 83)  { $RESULT = "259|Requested script is either invalid or no longer supported"; }
			elsif ($reasoncode == 84)  { $RESULT = "259|Reason code is reserved or not applicable to this API"; }
			elsif ($reasoncode == 85)  { $RESULT = "259|Reason code is reserved or not applicable to this API"; }
			elsif ($reasoncode == 86)  { $RESULT = "259|Reason code is reserved or not applicable to this API"; }
			elsif ($reasoncode == 87)  { $RESULT = "259|Reason code is reserved or not applicable to this API"; }
			elsif ($reasoncode == 88)  { $RESULT = "259|Reason code is reserved or not applicable to this API"; }
			elsif ($reasoncode == 89)  { $RESULT = "259|Reason code is reserved or not applicable to this API"; }
			elsif ($reasoncode == 90)  { $RESULT = "259|Reason code is reserved or not applicable to this API"; }
			elsif ($reasoncode == 91)  { $RESULT = "259|Version 2.5 is no longer supported"; }
			elsif ($reasoncode == 92)  { $RESULT = "259|Gateway no longer supports the requested method of integration"; }
#			elsif ($reasoncode == 93)  { $RESULT = "254|Wells Fargo SecureSource error - Country is required"; }
#			elsif ($reasoncode == 94)  { $RESULT = "253|Wells Fargo SecureSource error - Shipping state or country is invalid"; }
#			elsif ($reasoncode == 95)  { $RESULT = "254|Wells Fargo SecureSource error - State is required"; }
#			elsif ($reasoncode == 96)  { $RESULT = "253|Wells Fargo SecureSource error - Country not authorized for buyers"; }
			elsif ($reasoncode == 97)  { $RESULT = "262|Time period for this request has expired"; }
			elsif ($reasoncode == 98)  { $RESULT = "256|SIM Transaction fingerprint has already been used"; }
			elsif ($reasoncode == 99)  { $RESULT = "251|SIM Transaction fingerprint does not match merchant-specified fingerprint"; }
			elsif ($reasoncode == 100) { $RESULT = "253|eCheck Type is Invalid"; }
			elsif ($reasoncode == 101) { $RESULT = "253|eCheck Name and / or account type does not match actual account"; }
			elsif ($reasoncode == 102) { $RESULT = "206|High security risk"; }
			elsif ($reasoncode == 103) { $RESULT = "254|Fingerprint transaction key or password is required"; }
			elsif ($reasoncode == 104) { $RESULT = "253|eCheck Country failed validation"; }
			elsif ($reasoncode == 105) { $RESULT = "253|eCheck Transaction under review - City and Country failed validation"; }
			elsif ($reasoncode == 106) { $RESULT = "253|eCheck Transaction under review - Company failed validation"; }
			elsif ($reasoncode == 107) { $RESULT = "253|eCheck Transaction under review - Bank account name failed validation"; }
			elsif ($reasoncode == 108) { $RESULT = "253|eCheck Transaction under review - First Name / Last Name failed validation"; }
			elsif ($reasoncode == 109) { $RESULT = "253|eCheck Transaction under review - First Name / Last Name failed validation"; }
			elsif ($reasoncode == 110) { $RESULT = "253|eCheck Transaction under review - Bank account name failed validation"; }
			else { $RESULT = "257|Unrecognized reason code $reasontext"; }
			} ## end elsif (($respcode == 2) ||...
		else {
			$RESULT = "257|Unknown Response";
			}
	
		## This section deals with AVS:
		## * If we failed AVS, set AVS Failure code to an appropriate ZOOVY status code
		## * If we got a partial match (on a transaction we thought was good) set the
		##   AVS failure code the partial AVS zoovy status code set above
		## * If we got a full match, set the AVS fail code to blank so we don't flag it
		##   as failed (flow through with the status code set before here)
		## In all cases report the AVS status into the message (this is what has fundamentally
		## changed in the logic of this code, it used to not report anything if set to IGNORE
		## now it reports on it, but IGNORE means it still doesn't do anything based on AVS)
		##  -AK 12/30/02

		if ((substr($RESULT,0,1) eq '0') || (substr($RESULT,0,1) eq '1')) {
			$RS = 'AOK'; # review status
			}
		elsif ($RESULT ne '') {
			$RESULT .= " - Auth.Net response=$respcode reason=$reasoncode";
			}

	
		my $avsmessage = '';
		if ($RS ne 'AOK') {
			## already had a negative review status
			}
		elsif ((substr($RESULT,0,1) eq '0') || (substr($RESULT,0,1) eq '1')) {
			my $avsch = 'X'; ## AVS Failure Code A=approved, X=not available, P=partial, D=Decline
			if ($avs eq 'B') { ($k{'AVSZ'},$k{'AVST'})=('X','X'); $avsch='X'; $avsmessage = ' - No data provided for AVS'; }
			elsif ($avs eq 'R') { ($k{'AVSZ'},$k{'AVST'})=('X','X');  $avsch='X'; $avsmessage = ' - Retry transaction later AVS system unavailable' }
			elsif ($avs eq 'G') { ($k{'AVSZ'},$k{'AVST'})=('X','X');  $avsch='X'; $avsmessage = ' - AVS Non-US Bank'; }
			elsif ($avs eq 'S') { ($k{'AVSZ'},$k{'AVST'})=('X','X');  $avsch=''; $avsmessage = ' - AVS is not supported by the credit card issuer'; }
			elsif ($avs eq 'E') { ($k{'AVSZ'},$k{'AVST'})=('X','X');  $avsch=''; $avsmessage = ' - AVS General / Unknown Error'; }
			elsif ($avs eq 'X') { ($k{'AVSZ'},$k{'AVST'})=('M','M');  $avsch='A'; $avsmessage = ' - Exact AVS Match'; }                                                                         ## Don't set the fail code (it passed AVS)
			elsif ($avs eq 'Y') { ($k{'AVSZ'},$k{'AVST'})=('M','M');  $avsch='A'; $avsmessage = ' - AVS Address and 5 Digit ZIP matches'; }                                                     ## Don't set the fail code (it passed AVS)
			elsif ($avs eq 'A') { ($k{'AVSZ'},$k{'AVST'})=('N','M');  $avsch='P'; $avsmessage = ' - AVS Address Matches Zip does not'; }                   ## Only set the fail code if it thinks its good and it failed AVS
			elsif ($avs eq 'W') { ($k{'AVSZ'},$k{'AVST'})=('M','N');  $avsch='P'; $avsmessage = ' - AVS 9 Digit ZIP matches Street address does not'; }    ## Only set the fail code if it thinks its good and it failed AVS
			elsif ($avs eq 'Z') { ($k{'AVSZ'},$k{'AVST'})=('M','N');  $avsch='P'; $avsmessage = ' - AVS 5 Digit ZIP matches Street address does not'; }    ## Only set the fail code if it thinks its good and it failed AVS
			elsif ($avs eq 'N') { ($k{'AVSZ'},$k{'AVST'})=('N','N');  $avsch='D'; $avsmessage = ' - AVS No match on address or ZIP'; }
			elsif ($avs eq 'U') { ($k{'AVSZ'},$k{'AVST'})=('X','X');  $avsch='X'; $avsmessage = ' - AVS Address information unavailable'; }
			elsif ($avs eq 'P') { ($k{'AVSZ'},$k{'AVST'})=('X','X');  $avsch='';}  ## We used to flag this as 205, now we don't change status based on it since it is irrelevant to the transaciton in question.
			elsif ($avs ne '') { ($k{'AVSZ'},$k{'AVST'})=('X','X');  $avsch='X'; $avsmessage = " - Unrecognized AVS Code $avs"; }
	
			## Change the AVS Code if we need to (capturing a delayed transaction doesn't
			## use AVS failure codes, since AVS shouldn't be happening, it should have
			## happened on the first hit to Authorizenet)  If $avsfc is blank then we have
			## no need to change the code. -AK
			# AVS Settings
			## Tell them we've changed status as a result of the AVS results (we weren't doing this before)
			$RS = &ZPAY::review_match($RS,$avsch,&ZTOOLKIT::gstr($webdbref->{'cc_avs_review'},$ZPAY::AVS_REVIEW_DEFAULT));
			}
	
		if ((substr($RESULT,0,1) eq '0') || (substr($RESULT,0,1) eq '1')) {
			## CVV2/CVC2/CID Card Code checking
			# Card code CVV2/CVC2/CID settings 
			my $cvvch = ''; ## $cvvfc = CVV failure status code, blank means no failure
			my $cvvreq = gstr($webdbref->{'cc_cvvcid'}, 0); # 0, 1 and 2 (1 is optional, 2 is required) ... default to 0
			if ($payrec->{'tender'} ne 'CREDIT') { $cvvreq = 0; }
			if (substr($RESULT,0,1) eq '2') {
				# if we've already failed the transaction skip this part.
				}	
			elsif (substr($params->{'x_card_num'},0,1) eq '3') {
				## amex apparently no long requires cvv #'s
				}
			elsif ($cvvreq) {    ## Non-zero means we should be reporting on card code failures
				if    ($cardcode eq 'M') { $k{'CVVR'} = 'M';  $avsmessage = ' - CVV2/CVC2/CID Matched card'; }
				elsif ($cardcode eq 'N') { $k{'CVVR'} = 'N';  $cvvch = 'D'; $avsmessage = ' - CVV2/CVC2/CID or Expiration did not match card'; }
				elsif ($cardcode eq 'S') { $k{'CVVR'} = 'N';  $cvvch = 'D'; $avsmessage = ' - CVV2/CVC2/CID Should have been present'; }
				elsif ($cardcode eq 'U') { $k{'CVVR'} = 'X';  $cvvch = 'X'; $avsmessage = ' - CVV2/CVC2/CID Issuer unable to process request'; }
				elsif ($cardcode eq 'P') { $k{'CVVR'} = 'X';  $cvvch = 'X'; $avsmessage = ' - CVV2/CVC2/CID Not Processed'; }
				elsif ($cardcode ne '')  { $k{'CVVR'} = 'X';  $cvvch = 'X'; $avsmessage = " - CVV2/CVC2/CID Unknown code"; }
				else { $cvvch = 'A'; }
				## Only change the status if $cvvreq is 2 (required)...  a setting of 1 is optional
				## Otherwise the reporting we added onto $message should do. -AK
				$RS = &ZPAY::review_match($RS,$cvvch,&ZTOOLKIT::gstr($webdbref->{'cc_cvv_review'},$ZPAY::CVV_REVIEW_DEFAULT));
				}
			}
	
		if (&ZPAY::has_kount($USERNAME)) {
			## store KOUNT values.
			require PLUGIN::KOUNT;
			$payment->{'KH'} = PLUGIN::KOUNT::generate_khash($payment->{'CC'});
			$O2->in_set('flow/kount',sprintf("AVSZ=%s|AVST=%s|CVVR=%s",$k{'AVSZ'},$k{'AVST'},$k{'CVVR'}));
			}
		
		if (defined($RS)) {
			$O2->in_set('flow/review_status',$RS);
			}
	
		## Report on the codes sent to us.
		#my $message = " (Authnet Reason $reason - Response $respcode";
		#if (($avs ne 'P') && ($avs ne '')) { $message .= " - AVS $avs"; }    ## We ignore AVS code P since it means AVS didn't apply to the transaction
		#if ($cardcode ne '') { $message .= " - Card Code $cardcode"; }
		#$message .= ")";
		# $DEBUG && &msg("\$message is $message");

		$DEBUG && &msg("\$trans is $trans");
		$DEBUG && &msg("\$auth is $auth");
		}


	if (defined $RESULT) {
		if ($RESULT eq '') { $RESULT = "999|Internal error - RESULT was blank"; }

		my ($PS,$DEBUG) = split(/\|/,$RESULT,2);

		my $chain = 0;

		if ($VERB eq 'AUTHORIZE') { $chain = 0; }
		elsif (($VERB eq 'CHARGE') && ($payrec->{'ps'} ne '109')) { 	
			## note: ps 109 is NOAUTH_DELAY (although it's verb CHARGE it's 
			## way more like verb CAPTURE and so we still want to chain errors)
			$chain = 0;
			}
		elsif ($VERB eq 'REFUND') { $chain++; }
		elsif (substr($PS,0,1) eq '2') { $chain++; }
		elsif (substr($PS,0,1) eq '3') { $chain++; }
		elsif (substr($PS,0,1) eq '6') { $chain++; $payrec->{'voided'} = time(); }
		elsif (substr($PS,0,1) eq '9') { $chain++; }

		if ($chain) {
			my %chain = %{$payrec};
			delete $chain{'debug'};
			delete $chain{'note'};
			$chain{'puuid'} = $chain{'uuid'};
			$chain{'uuid'} = $O2->next_payment_uuid();
			$chain{'auth'} = sprintf("%s",$api->{'x_auth_id'});	
			$chain{'txn'} = sprintf("%s",$api->{'x_trans_id'});	
			$payrec = $O2->add_payment($payrec->{'tender'},$params->{'x_amount'},%chain);
			}

		$payrec->{'amt'} = $AMT;
		$payrec->{'ts'} = time();	
		$payrec->{'ps'} = $PS;
		$payrec->{'note'} = $payment->{'note'};
		$payrec->{'debug'} = $DEBUG;

		if ($chain) {
			delete $payrec->{'acct'};
			}
		elsif ($VERB eq 'CAPTURE') {
			## don't touch payment on a CAPTURE
			}
		else {
			my %storepayment = %{$payment};
			$storepayment{'CM'} = &ZTOOLKIT::cardmask($payment->{'CC'});		
			if (not &ZPAY::ispsa($payrec->{'ps'},['2','9'])) {
				## we got a failure, so .. we toss out the CVV, but keep the CC
				delete $storepayment{'CC'};
				}
			delete $storepayment{'CV'};
			$payrec->{'acct'} = &ZPAY::packit(\%storepayment);
			}
		$payrec->{'r'} = &ZTOOLKIT::buildparams($api);
		}
	


	$O2->paymentlog("AUTHORIZENET API REQUEST: ".&ZTOOLKIT::buildparams($params));	
	$O2->paymentlog("AUTHORIZENET API RESPONSE: ".&ZTOOLKIT::buildparams($api));	
	$O2->paymentlog("AUTHORIZENET RESULT: $RESULT");

	return($payrec);
	}


########################################
# AUTHORIZENET CALL
# Description: Calls the external API
# Accepts: A hash of parameters needed to call PFPro
# Returns: A REFERENCE to a hash of the result codes 
#
sub authorizenet_call {
	my ($O2, $webdbref, $params_hash) = @_;

	my $USERNAME = $O2->username();
	my %results_hash = ();    # we'll return a pointer to this.
	my ($PRT) = $O2->prt();

	my $testmode = num($webdbref->{'authorizenet_testmode'});
	my $username = def($webdbref->{'authorizenet_username'}); 
	if ($username =~ m/(.*?)\/test([012])$/) { $username = $1; $testmode = $2; }
	my $key      = def($webdbref->{'authorizenet_key'});
	my $password = def($webdbref->{'authorizenet_password'});
	my $referer  = def($webdbref->{'authorizenet_referer'});

	my $url = "https://secure.authorize.net/gateway/transact.dll";
	if ($testmode > 1) { $url = "https://certification.authorize.net/gateway/transact.dll"; }

	# Add some custom values to the hash
	$params_hash = {
		%{$params_hash},
		'x_version'            => '3.1',
		'x_login'              => $username,
		'x_tran_key'           => $key,
		'x_test_request'       => (($testmode == 1) ? 'TRUE' : 'FALSE'),
		'x_delim_data'         => 'TRUE',
		'x_relay_response'     => 'FALSE',
		'x_adc_delim_data'     => 'TRUE',
		'x_adc_relay_response' => 'FALSE',
		'x_adc_url'            => 'FALSE',
		};

	if ($key eq '') {
		$params_hash->{'x_password'} = $password;
		}


	# Sanity - go ahead and strip any PIPES in the data
	foreach my $field (keys %{$params_hash}) {
		if (not defined $params_hash->{$field}) { $params_hash->{$field} = ''; }
		$params_hash->{$field} =~ s/\|//gs;
		}
	$params_hash->{'x_delim_char'}          = '|';
	$params_hash->{'x_adc_delim_character'} = '|';

	# Create an LWP instance
	my $agent = new LWP::UserAgent;
	$agent->agent('Groovy-Zoovy/1.0');
	# Now lets go ahead and create a request
	my $req = new HTTP::Request('POST', $url);
	if ($referer ne '') { $req->referer($referer); }
	$req->content(&ZTOOLKIT::makecontent($params_hash));
	my $result  = $agent->request($req);
	my $content = $result->content();

	if ($content eq '') {
		$results_hash{'ERROR'} = 'Authorize.net server "secure.authorize.net" did not respond.';
		}
	else {
		my @az = split (/\|/, $content);	# WE CAN USE | or ; as delimiters now.
		$results_hash{'x_response_code'}           = $az[0];
		$results_hash{'x_response_subcode'}        = $az[1];
		$results_hash{'x_response_reason_code'}    = $az[2];
		$results_hash{'x_response_reason_text'}    = $az[3];
		$results_hash{'x_auth_code'}               = $az[4];
		$results_hash{'x_avs_code'}                = $az[5];
		$results_hash{'x_trans_id'}                = $az[6];
		$results_hash{'x_method'}                  = $az[10];
		$results_hash{'x_type'}                    = $az[11];
		$results_hash{'x_card_code_response_code'} = $az[38];
		}


	# print STDERR "AuthorizeNet returned: " . $content . "\n";
	## only log AMEX transactions
	#if ($params_hash->{'x_card_num'} =~ m/^3[47].*$/) {
	#	open F, ">/tmp/authorizenet_amex.".time();
	#	use Data::Dumper; print F Dumper($USERNAME,$params_hash,\%results_hash);
	#	close F;
	#	}


	return (\%results_hash);
	} ## end sub authorizenet_call


sub fix_country {
	my ($country) = @_;

	if (length($country)==2) { return($country); }

	$country = &ZSHIP::correct_country(@_);
	if ($country eq '') { $country = 'UNITED STATES'; }
	$country = def($ZPAY::AUTHORIZENET::COUNTRIES{uc($country)},'XX'); ## Default to XX if we couldn't find the country.
	return $country;
	}

## Certification account / password / transaction keys
# regular: scc_test82 / test1ng / 6kyeqQYU9dANikm7
# wells fargo: carttest82 / c@rttest / KKILjoEpqIkoqugK
# Use these with authorizenet_testmode = 2

sub def   { return ZTOOLKIT::def(@_); }
sub num   { return ZTOOLKIT::num(@_); }
sub gstr  { return ZTOOLKIT::gstr(@_); }

########################################
# MSG
# Description: Prints an error message to STDERR (the apache log file)
# Accepts: An error message as a string
# Returns: Nothing

sub msg
{
	my $head = 'ZPAY::AUTHORIZENET: ';
	while ($_ = shift (@_))
	{
		if (ref) { require Data::Dumper; $_ = Data::Dumper->Dump([$_], [shift (@_)]); }
		print STDERR $head, join ("\n$head", split (/\n/, $_)), "\n";
	}
}

1;

