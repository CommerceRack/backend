package DOMAIN::REGISTER;

use strict;

use XML::Parser;
use XML::Parser::EasyTree;
use HTTP::Request::Common qw(POST);
use HTTP::Request::Common;
use Digest::MD5 qw/md5_hex/;
use LWP::UserAgent;
use Data::Dumper;

use lib "/backend/lib";
require ZTOOLKIT::SECUREKEY;
require ACCOUNT;
require ZTOOLKIT;
require XMLTOOLS;
require ZOOVY;
require LISTING::MSGS;

# u:zoovy p:vi3jit0
# resellers.resellone.net -- u:zoovy p:vi3jit0


#$DOMAIN::REGISTER::USERNAME = 'zoovy';
#$DOMAIN::REGISTER::PRIVKEY = '5157000dbd003408eddd673c2aa72f8f81a5110fa2003c431f235ccfc0f2f982c9a35eb2b8f6d335de99ed26fe984bc4c5db8a8bafeb5b58';
$DOMAIN::REGISTER::PRIVKEY = '1a2725e4114d1278791ef50968252f475831bf50064e82da99875252fcdbbfa0430eda5c70d630e6a416d18adbbbf0caef452702fe03b066';
$DOMAIN::REGISTER::USERNAME = 'zoovy';

## SOFTLAYER API
#$DOMAIN::REGISTER::USERNAME = 'SL236096';
#$DOMAIN::REGISTER::PRIVKEY = '94688bbb6944bf185308b193657f91d16305d6c3fb7af4332561ad7a3221a9cd';

# $DOMAIN::REGISTER::PRIVKEY = '94688bbb6944bf185308b193657f91d16305d6c3fb7af4332561ad7a3221a9cd';
# $DOMAIN::REGISTER::PRIVKEY = 'b557b517e46fed37747cbaaab93af37e8ef62acdf18823f924a3b71560582fb03fc2fb11ad5776c5c8bc6e2bb71b84d4f7f8b9608e4edab0';
# http://forums.softlayer.com/showthread.php?p=50414
# http://sldn.softlayer.com/article/SoftLayer-API-Overview
# http://sldn.softlayer.com/

# NOTE: 
# NOTE: zoovy/shibby42

# 
# http://www.resellone.net/support/pdf/Resellone_DomainsAPI.pdf
#
my %info = ();

## print Dumper(doRequest('DOMAIN','LOOKUP',\%info));
#print "DOMAIN AVAILABLE: ".&DOMAIN::REGISTER::DomainAvailable('exampleasdfasdfasdf.com')."\n";
#exit;



##
## note: this takes a domain name, NOT a domain object.
##
sub is_locked {
   my ($DOMAIN) = @_;

   my $result = DOMAIN::REGISTER::doRequest('DOMAIN','check_transfer',{
      # command=>cancel,
      domain=>$DOMAIN,
      check_status=>1,
      # get_request_address=>1,
      });

  $result = not $result->{'attributes.item.~transferrable'};

   return($result);
   }






##
## returns: the number of nameservers + a status message
##		also logs to the DOMAIN that the nameservers were verified.
## 	a response of 2 means success.
##
sub verify_ns {
	my ($domain) = @_;

	my $server = &ZOOVY::servername();
	my @ns = qw(192.168.2.16 66.240.244.203);	# complex drive
	if ($server =~ /^dev/) { @ns = qw(192.168.1.100); }
	
	require Net::DNS;
	my $res   = Net::DNS::Resolver->new(nameservers => \@ns);

	my $VERIFIED = 0;
	my @ERRORS = ();
	my $query = $res->query("$domain", "NS");
	if ($query) {
		foreach my $rr (grep { $_->type eq 'NS' } $query->answer) {
			if ($rr->nsdname =~ /zoovy\.com$/) { 
				$VERIFIED++; 
				} 
			else { 
				push @ERRORS, sprintf("Incorrect server: %s",$rr->nsdname); 
				}
			}
		}
	else {
		push @ERRORS, sprintf("DNS query failed: %s",$res->errorstring);
		}

	return(@ERRORS);
	}



##
## commands:
##		NAMESERVER,REGISTRY_ADD_NS attribs: fqdn
##		domain, advanced_update_nameservers attribs: cookie? op_type=>'assign', assign_ns=>['ns1','ns2']
##		domain, bulk_transfer, attribs: 
##		domain, check_transfer attribs: domain, check_status, get_request_address
##		domain, send_password
sub format_phone {
	my ($PHONE) = @_;

	$PHONE =~ s/[^0-9]+//gs;
	if (substr($PHONE,0,1) eq '1') { $PHONE = substr($PHONE,1); }

	if (length($PHONE) != 10) { $PHONE = ''; }
	if ($PHONE eq '') { $PHONE = '555-555-1212'; }

	else {
		# +1.4165551122x1234
		$PHONE = "+1.".$PHONE;
		}
	
	return($PHONE);
	}


##
## returns the appropriate R1 username, and R1 password
##
sub credentials {
	my ($USERNAME) = @_;

	my $R1USER = &ZOOVY::resolve_mid($USERNAME);

	require ZTOOLKIT;
	my ($R1PASS) = &ZTOOLKIT::SECUREKEY::gen_key($USERNAME,'R1');
	$R1PASS =~ s/ /_/gs;

	return($R1USER,$R1PASS);
	}


##
## returns: undef on success, or an arrayref of error messages.
##
## note:
## 	reg_type can be either transfer, or process 
##		passing a reg_type of "new" will result in a process
##
sub register {
	my ($USERNAME,$DOMAIN,%options) = @_;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($lm) = $options{'*LM'};
	if (not defined $lm) { $lm = LISTING::MSGS->new($USERNAME); }

	my $reg_type = lc($options{'reg_type'});
	if ($reg_type eq '') {
		if (DOMAIN::REGISTER::DomainAvailable($DOMAIN)==1) {
			$lm->pooshmsg("DEBUG|+domain $DOMAIN is not registered, issuing new registration");
			$reg_type = 'new';
			}
		else {
			$reg_type = 'transfer';
			}
		}
	elsif ($reg_type eq 'new') { 
		if (DOMAIN::REGISTER::DomainAvailable($DOMAIN)==0) {
			$lm->pooshmsg("ERROR|+Domain $DOMAIN is not available for registration");
			}
		} 
	elsif ($reg_type eq 'transfer') { 
		if (DOMAIN::REGISTER::DomainAvailable($DOMAIN)>0) {
			$lm->pooshmsg("ERROR|+Domain $DOMAIN is not registered, cannot be transferred.");
			}
		}
	else {
		$lm->pooshmsg("ERROR|+need reg_type to be set");
		}
	# if ($reg_type eq 'new') { $reg_type = 'process'; }

	if ($DOMAIN eq '') {
		$lm->pooshmsg("ERROR|+Domain name not set");
		}

	if ($reg_type eq 'new') {
		}
	elsif (&DOMAIN::REGISTER::BelongsToRsp($DOMAIN)) {
		print STDERR "Belongs to us!\n";		
		$lm->pooshmsg("ERROR|+Domain already belongs to Zoovy - no need to transfer/register.");
		}
	else {
		print STDERR "Does not belong to us, okay for reg/transfer\n";
		}

	## 
	## SANITY: at this point either $ERRORSREF is set, or we're going to try and figure out the contact info.
	##
	my %contact = ();
	if ($lm->can_proceed()) {
		my $info = {};

		my $ACCT = ACCOUNT->new($USERNAME,"*DNS");
		foreach my $k ('org.name','org.address1','org.city','org.state','org.zip') {
			if ($ACCT->get($k) eq '') {
				$lm->pooshmsg("ERROR|+account $k must be set/not blank");
				}
			}

		%contact = (
			first_name => ($ACCT->get('org.first'))?$ACCT->get('org.first'):"DNS",
			last_name => ($ACCT->get('org.last'))?$ACCT->get('org.first'):"Admin",
			phone => &DOMAIN::REGISTER::format_phone($ACCT->get('org.phone')),
			# fax => &DOMAIN::REGISTER::format_phone(),
			email => $ACCT->get('org.email'),
			org_name => $ACCT->get('org.name'),
			address1 => $ACCT->get('org.address1'),
			address2 => $ACCT->get('org.addrses2'),
			address3 => '',
			city => $ACCT->get('org.city'),
			state => $ACCT->get('org.state'),
			country => ($ACCT->get('org.country'))?$ACCT->get('org.country'):'US',
			postal_code => $ACCT->get('org.zip'),,
			# url => '',
			);
		
		# print STDERR Dumper(\%contact);
		}

	my $IP_ADDRESS = $ENV{'REMOTE_ADDR'};
	if ($IP_ADDRESS eq '') { $IP_ADDRESS = $options{'IP'}; }

	if ($lm->can_proceed()) {
		if ($IP_ADDRESS eq '') {
			$lm->pooshmsg("ERROR|+REMOTE IP Address is required but was not available");
			}
		}

	## 
	## SANITY: at this point either $ERRORSREF is set, or we're going to try and register this domain.
	##
	my $D = undef;
	if ($lm->can_proceed()) {
		my ($R1User,$R1Pass) = &DOMAIN::REGISTER::credentials($USERNAME);
		# print STDERR "$R1User pw[$R1Pass]\n"; exit;

		my $result = &DOMAIN::REGISTER::doRequest('domain','sw_register',{
		 	registrant_ip=>$IP_ADDRESS,
			affiliate_id=>'zoovy',
			auto_renew=>1,
			custom_nameservers=>0,
			custom_tech_contact=>0,
			domain=>$DOMAIN,
			f_whois_privacy=>0,
			handle=>'process',
			lang_pref=>'EN',
			legal_type=>'TDM',
			link_domains=>0,
			# link_domains=>1, master_order_id=>#####,
			period=>1,
			reg_username=>$R1User,
			reg_password=>$R1Pass,
			reg_type=>$reg_type, 	# new, transfer, whois_privacy, sunrise

			tld_data=>{
				nexus=>{
					app_purpose=>'P1',
					category=>'C21',	
					},
				},

			contact_set => {
				admin => \%contact,
				owner => \%contact,
				billing => \%contact,
				},

			nameserver_list=>[
				{ name=>'ns.zoovy.com' },
				{ name=>'ns2.zoovy.com' },
				]

			},undef);
	
		$D = {};
		if ($result->{'item.~response_code'} == 465) {
			$result->{'item.~response_text'} =~ s/[\n\r]+//gs;
			$lm->pooshmsg("ERROR|+$result->{'item.~response_text'}");
			if (defined $result->{'attributes.item.~error'}) {				
				foreach my $msg (split(/[\n\r]+/,$result->{'attributes.item.~error'})) {
					$lm->pooshmsg("ERROR|+$msg");
					}
				}
			}
		elsif ($result->{'item.~response_code'} == 200) {
			$D->{'REG_STATUS'} = $reg_type.' order #'.$result->{'attributes.item.~id'};
			$D->{'REG_RENEWAL_GMT'} = time()+(86400*360); 
			$D->{'REG_TYPE'} = 'WAIT';
			$D->{'REG_ORDERID'} = $result->{'attributes.item.~id'};
			$lm->pooshmsg("SUCCESS|+$D->{'REG_STATUS'}");
			}
		elsif (($result->{'item.~response_code'} == 485) && ($result->{'item.~response_text'} eq 'Domain taken')) {
			$D->{'REG_TYPE'} = 'TRANSFER';
			$D->{'REG_STATUS'} = 'Domain already taken, changing to transfer (please wait)';
			$lm->pooshmsg("ERROR|+$D->{'REG_STATUS'}");
			}
		elsif ($result->{'item.~response_code'} == 487) {
			## this means an existing request has already been submitted.
			$D->{'REG_TYPE'} = 'WAIT';
			$D->{'REG_RENEWAL_GMT'} = time()+(86400*360); 
			$D->{'REG_STATUS'} = "Waiting order #".$result->{'attributes.item.~forced_pending'};
			$D->{'REG_ORDERID'} = $result->{'attributes.item.~forced_pending'};
			$lm->pooshmsg("SUCCESS|+$D->{'REG_STATUS'}");
			}
		else {
			$lm->pooshmsg("ERROR|+Unknown Response ".Dumper($result));
			}

		# print STDERR Dumper($result);	
		}



#	if (not defined $ERRORSREF) {
#		if ($reg_type eq 'transfer') { $D->sendmail('transfer'); }
#		}
#	elsif (scalar(@{$ERRORSREF})>0) {
#		$D->{'REG_STATUS'} = join("", @{$ERRORSREF});
#		$D->{'REG_TYPE'} = 'ERROR';
#		}

#	if (defined $D) {
#		bless $D, 'DOMAIN';
#		$D->save();
#		}
#	else {
#		print 'ERROR: '.Dumper($D);
#		die();
#		}

#$VAR1 = {
#          'attributes.item.~admin_email' => 'brian@zoovy.com',
#          'item.~action' => 'REPLY',
#          'item.~response_text' => 'Order created',
#          'item.~is_success' => '1',
#          'item.~object' => 'DOMAIN',
#          'item.~protocol' => 'XCP',
#          'attributes.item.~id' => '48502',
#          'item.~response_code' => 200
#        };

	return($D);
	}


##
##
##
#sub verify_billing {
#	my ($USERNAME,$DOMAIN) = @_;
#
#	my ($zdbh) = &DBINFO::db_zoovy_connect();
#	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
#	my $pstmt = &DBINFO::insert($zdbh,'BS_REOCCURING', {
#	   MID=>$MID, USERNAME=>$USERNAME,
#		BILLGROUP=>'PARTNER',BUNDLE=>'DNS',
#		UUID=>$DOMAIN,
#      COST=>10.00,
#		'SETUP_PERIOD'=>366,
#		'SETUP_COST'=>10,
#      '*CREATED'=>"now()",
#      PERIOD=>365,
#      '*LASTRUN'=>"now()",
#      '*NEXTRUN'=>'now()',
#      },debug=>1+2);
#   $zdbh->do($pstmt);
#
#	my ($ID) = &DBINFO::last_insert_id($zdbh);
#	&DBINFO::db_zoovy_close();
#
#	return($ID);
#	}




##
## Sends the password for the domain administration panel.
##
sub sendpassword {
	my ($domain) = @_;

	my $result = &DOMAIN::REGISTER::doRequest('DOMAIN','send_password',{domain_name=>$domain},undef);
	print STDERR Dumper($result);
	}


##
## this will resubmit a FAILED transfer request.
##
sub resend_transfer_msg {
	my ($D) = @_;

	my $result = DOMAIN::REGISTER::doRequest('SEND_PASSWORD','transfer',{
		# command=>cancel,
		domain_name=>$D->{'DOMAIN'},
		});

	print STDERR Dumper($result);
	die();	
	}

##
## returns a status:
##		'LOCKED' - to indicate the domain is locked.
##
sub check {
	my ($D) = @_;

	my $DOMAIN = $D->{'DOMAIN'};
	my $result = DOMAIN::REGISTER::doRequest('DOMAIN','check_transfer',{
		# command=>cancel,
		domain=>$DOMAIN,
		check_status=>1,
		# get_request_address=>1,
		});


	$D->{'VERIFIED_GMT'} = time();	
	if ($result->{'item.~response_code'} != 200) {
		die("internal error");
		}
	elsif ($result->{'attributes.item.~reason'} =~ /Domain not registered/) {
         # 'item.~action' => 'REPLY',
         # 'item.~response_text' => 'Query successful',
         # 'attributes.item.~transferrable' => 0,
         # 'item.~is_success' => '1',
         # 'attributes.item.~reason' => 'Domain not registered',
         # 'item.~object' => 'DOMAIN',
         # 'item.~protocol' => 'XCP',
         # 'item.~response_code' => 200
		## I THINK THIS ALSO MEANS THAT WE DO NOT HAVE A PENDING ORDER.
		$D->{'REG_TYPE'} = 'ERROR';
		$D->log(1+2,"Sorry, but domain $DOMAIN is not registered.");
		$D->save();
		}
	elsif ((not $result->{'attributes.item.~transferrable'}) && ($result->{'attributes.item.~reason'} =~ /Domain already exists/)) {
		#$VAR1 = {
      #    'item.~action' => 'REPLY',
      #    'item.~response_text' => 'Query successful',
      #    'attributes.item.~transferrable' => 0,
      #    'attributes.item.~status' => 'completed',
      #    'item.~response_code' => 200,
      #    'attributes.item.~unixtime' => '1155554395',
      #    'item.~object' => 'DOMAIN',
      #    'attributes.item.~reason' => 'Domain already exists in Zoovy, Inc.\'s account',
      #    'item.~is_success' => '1',
      #    'item.~protocol' => 'XCP',
      #    'attributes.item.~request_address' => 'andreasinc@tampabay.rr.com',
      #    'attributes.item.~timestamp' => 'Mon Aug 14 07:19:55 2006'
      #  };
		# $D->bill($result->{'attributes.item.~unixtime'});
		}
	elsif ((not $result->{'attributes.item.~transferrable'}) && ($result->{'attributes.item.~reason'} =~ /LOCK/)) {
		#$VAR1 = {
		#          'item.~action' => 'REPLY',
		#          'item.~response_text' => 'Query successful',
		#          'attributes.item.~transferrable' => '0',
		#          'item.~is_success' => 1,
		#          'attributes.item.~reason' => 'Domain Status: REGISTRAR-LOCK does not allow for transfer',
		#          'item.~object' => 'DOMAIN',
		#          'item.~protocol' => 'XCP',
		#          'item.~response_code' => 200
		#        };

		$D->log(1+2,$result->{'attributes.item.~reason'});
		my (@ERRORS) = &DOMAIN::REGISTER::verify_ns($D->{'DOMAIN'});
		if (scalar(@ERRORS)==0) {
			$D->log(2,sprintf("Verified Nameservers %s",&ZTOOLKIT::pretty_date(time(),1)));
			}
		elsif (scalar(@ERRORS)>0) {
			## they are configured to use our nameservers
			$D->{'REG_TYPE'} = 'OTHER';
			$D->log(1+2,sprintf("Nameserver Errors: %s",join(" ",@ERRORS)));
			$D->log(2,"Found ns.zoovy.com nameservers");
			}
		#else {
		#	## error the domain out, they are using somebody elses nameservers.
		#	$D->log(2,"Setting DOMAIN to ERROR due to invalid nameservers.");
		#	$D->{'REG_TYPE'} = 'ERROR'; 
		#	}
		$D->{'REG_STATUS'} = 'Domain is LOCKED, cannot transfer.';
		$D->save();
		}
	elsif (($result->{'attributes.item.~transferrable'}==1) && ($result->{'attributes.item.~type'} eq 'reg2reg')) {
		#$VAR1 = {
		#          'item.~action' => 'REPLY',
		#          'item.~response_text' => 'Query successful',
		#          'attributes.item.~transferrable' => 1,
		#          'item.~is_success' => 1,
		#          'item.~object' => 'DOMAIN',
		#          'item.~protocol' => 'XCP',
		#          'attributes.item.~type' => 'reg2reg',
		#          'item.~response_code' => 200
		#        };
		## now lets see if we've already got an order id.
		my ($oid) = $D->{'REG_ORDERID'};
		if ($oid==0) {
			## hmm, lets see if we can lookup the order id, or get a new one by resubmitting the transfer request.
			die();	# corrupt, no order id
			}
		else {
			# &DOMAIN::REGISTER::resend_transfer_msg($D);
			# &DOMAIN::REGISTER::process_transfer($D);
			my ($response) = &DOMAIN::REGISTER::get_order_info($D);
			if (
				(lc($response->{'attributes.item.~transfer_status'}) eq 'cancelled')
				|| (lc($response->{'attributes.item.~transfer'}) eq 'cancelled')
				)  {
				$D->log(1,"Domain transfer cancelled");
				$D->{'REG_TYPE'} = 'OTHER';
				$D->save();
				}
			elsif ($response->{'attributes.item.~transfer_status'} eq 'Unknown') {
				$D->log(1,"Domain transfer status unknown (error)");
				$D->{'REG_TYPE'} = 'OTHER';
				$D->save();
				}
			else {
				warn Dumper($response);
				die();
				}
			}
		}
	elsif ($result->{'attributes.item.~status'} eq 'pending_owner') {
		## this means we've submitted a transfer request, but it hasn't been tuned over yet.
		$D->{'REG_RENEWAL_GMT'} = time()+(86400*1);
		$D->log(1,"Waiting for you to approve transfer.");
		$D->save();
		}
	elsif ($result->{'attributes.item.~status'} eq 'pending_registry') {
		## 
		$D->{'REG_RENEWAL_GMT'} = time()+(86400*1);
		$D->log(1,"Domain is 'Pending Registry' approval (takes 5 days)");
		$D->save();		
		}
	elsif (($result->{'item.~is_success'}==1) && ($result->{'attributes.item.~transferrable'}==0)) {
		## NOTE: this is where we get when we've successfully transferred a domain to us as well!

		
		$D->log(1+2,$result->{'attributes.item.~reason'});
		$D->log(1+2,"Domain is probably LOCKED - changing to OTHER");
		$D->{'REG_TYPE'} = 'OTHER';
		$D->save();
		}
	elsif ($result->{'attributes.item.~status'} eq 'completed') {
		if ($result->{'attributes.item.~reason'} eq 'Domain status doesn\'t allow for transfer') {
			$D->{'REG_TYPE'} = 'OTHER';
			$D->log(1,"Domain status doesn't allow for transfers");
			$D->save();
			}
		else {
			warn Dumper($result);
			die();
			}
		}
	else {
		warn Dumper($result);
		die();
		}


	return();
	}


##
## this will terminate a transfer request
##
sub cancel_transfer {
	my $result = DOMAIN::REGISTER::doRequest('CANCEL_TRANSFER',{
		# domain_name=>'greatglovez.com',
		# order_id
		});

	## this supports lots of other features:
	## limit, gaining_registrar, 
	print STDERR Dumper($result);
	
	}




##
## this will resubmit a FAILED transfer request.
##
sub process_transfer {
	my ($D) = @_;

	my $result = DOMAIN::REGISTER::doRequest('DOMAIN','process_pending',{
		# command=>cancel,
		order_id=>$D->{'REG_ORDERID'},
		});

	#$VAR1 = {
   #       'item.~action' => 'REPLY',
   #       'item.~response_text' => 'Order saved in pending.',
   #       'item.~is_success' => '0',
   #       'item.~object' => 'DOMAIN',
   #       'item.~protocol' => 'XCP',
   #       'item.~response_code' => 440
   #     };
	if (($result->{'item.~response_code'}==440) && ($result->{'item.~response_text'} =~ /pending/)) {
		## this means the domain transfer was created, but never processed (our fault)
		my ($success) = &DOMAIN::REGISTER::process_pending($D);		
		}
	

	## this supports lots of other features:
	## limit, gaining_registrar, 
	print STDERR Dumper($result);
	die();
	}


##
## to confirm an existing order.
##		returns: 1/0 for success.
sub process_pending {
	my ($D) = @_;

	my $result = DOMAIN::REGISTER::doRequest('DOMAIN','PROCESS_PENDING',{
		# command=>cancel,
		order_id=>$D->{'REG_ORDERID'},
		});
	#$VAR1 = {
   #       'item.~action' => 'REPLY',
   #       'item.~response_text' => 'Order saved in pending.',
   #       'item.~is_success' => '0',
   #       'item.~object' => 'DOMAIN',
    #      'item.~protocol' => 'XCP',
   #       'item.~response_code' => 440
   #     };
	my $success = 0;
	if ($result->{'item.~response_code'}==440) {
		$success = 1;
		}

	
	## this supports lots of other features:
	## limit, gaining_registrar, 
	print STDERR 'process_pending '.Dumper($result);

	die();
	return($success);
	}


sub get_transferred_away {
	my ($DOMAIN) = @_;

#	my $req_from = 'YYYY-MM-DD';
#	$req_from = '2006-01-01'; 
#
#	my $result = DOMAIN::REGISTER::doRequest('DOMAIN','get_transfers_away',{
#		req_from=>$req_from,
#		page=>0,
#		});
#
#	## this supports lots of other features:
#	## limit, gaining_registrar, 
#	print Dumper($result);

	}


## this seems to be pretty useless, it won't tell us if a domain order is completed.
sub get_order_info {
	my ($D) = @_;

	my $result = DOMAIN::REGISTER::doRequest('DOMAIN','get_order_info',{order_id=>$D->{'REG_ORDERID'}});

#$VAR1 = {
#          'item.~action' => 'REPLY',
#          'item.~response_text' => 'Command completed successfully',
#          'item.~is_success' => 1,
#          'item.~object' => 'DOMAIN',
#          'item.~protocol' => 'XCP',
#          'attributes.item.~field_hash' => '
#       ',
#          'item.~response_code' => 200
#        };

	return($result);
	}



##
## returns an expiration timestamp, or 0 (for false) if the domain belongs to our reseller account.
##
sub BelongsToRsp {
	my ($domain) = @_;

	my $result = &DOMAIN::REGISTER::doRequest('DOMAIN','belongs_to_rsp',{domain=>$domain},undef);
	# print Dumper($result);
	#$VAR1 = {
   #       'item.~action' => 'REPLY',
   #       'item.~response_text' => 'Unknown domain: slappy.com',
   #       'item.~is_success' => '0',
   #       'item.~object' => 'DOMAIN',
   #       'item.~protocol' => 'XCP',
   #       'item.~response_code' => '465'
   #     }
	# print Dumper($result);
	if ($result->{'item.~action'} ne 'REPLY') { return(undef); }

	my $success = ($result->{'item.~response_code'}==200)?1:0;

	if ($success) {
		require Date::Parse;
		($success) = Date::Parse::str2time($result->{'attributes.item.~domain_expdate'});
		}
	return($success);
	}



##
## returns: 1 for available
##				0 for not available
##				-1 for status unknown
##
sub DomainAvailable {
	my ($domain) = @_;

#	use Net::OpenSRS;

#	my $srs = Net::OpenSRS->new();
#	$srs->{'config'}->{'resellone'}->{'host'} = 'https://resellers.resellone.net:52443';
#	$srs->environment('resellone');
#	$srs->debug_level(3);
#	$srs->set_key( $DOMAIN::REGISTER::PRIVKEY );
#	$srs->set_manage_user( $DOMAIN::REGISTER::USERNAME );
#	my $result = $srs->is_available($domain);

	my $result = &DOMAIN::REGISTER::doRequest('DOMAIN','LOOKUP',{domain=>$domain},undef);
	print STDERR Dumper($result);
	die();
#	if ($result->{'attributes.item.~status'} eq 'taken') { 
#		return(0);
#		}
#	elsif ($result->{'attributes.item.~status'} eq 'available') {
#		return(1);
#		}
#	else {
#		return(-1);	# unknown??
#		}
	
	}


sub encodeAttribs {
	my ($attribs) = @_;

	my $attribxml = '';
	if (defined $attribs) {
		foreach my $k (keys %{$attribs}) {
			next if (not defined $k);
			if (ref($attribs->{$k}) eq '') {
				$attribxml .= "<item key=\"$k\">".&ZOOVY::incode($attribs->{$k})."</item>\n";
				}
			elsif (ref($attribs->{$k}) eq 'ARRAY') {
				$attribxml .= "<item key=\"$k\"><dt_array>";
				my $i = 0;
				foreach my $k (@{$attribs->{$k}}) {
					if (ref($k) eq '') {
						## scalara
						$attribxml .= "<item key=\"$i\">$k</item>\n";
						}
					elsif (ref($k) eq 'HASH') {
						$attribxml .= &encodeAttribs($attribs->{$k}); 
						}
					else {
						die("Can't have an array inside an array!");
						}
					$i++;
					}
				$attribxml .= "</dt_array></item>";
				}
			elsif (ref($attribs->{$k}) eq 'HASH') {
				$attribxml .= "<item key=\"$k\"><dt_assoc>";
				$attribxml .= &encodeAttribs($attribs->{$k});
				# print Dumper($k,$attribs->{$k});
				$attribxml .= "</dt_assoc></item>";
				}
			}
		}
	return($attribxml);
	}

##
##
##
sub doRequest {
	my ($object,$action,$attribs,$options) = @_;

	########################################################
	#Configuration Variables
	## my $REMOTE_HOST = "resellers.resellone.net:55443";
	my $REMOTE_HOST = "resellers.resellone.net:52443";

	## global defines

	#Using the following two lines ResellOne.net Client Packages for XML Parsing
	# require "DOMAIN::REGISTER/OPS.pm";
	#You might have to replace the 'use XML_Codec' in OPS.pm with the following line as well.
	# require "/XML_Codec.pm";

	my ($ua) = LWP::UserAgent->new();
	$ua->timeout(10);

	my $xml = qq~~;

	my $optionsxml = qq~~;
	foreach my $k (keys %{$options}) {
		$optionsxml .= "<item key=\"$k\">$options->{$k}</item>";
		}

	my $attribxml = '';
	if (defined $attribs) { 
		$attribxml = &encodeAttribs($attribs); 
		$attribxml =~ s/[\n\r]+//gs;
		$attribxml = qq~<item key="attributes"><dt_assoc>$attribxml</dt_assoc></item>~;
		}
	# print "ATTRIBXML[$attribxml]\n";
	
	$xml = qq~<?xml version='1.0' encoding='UTF-8' standalone='no' ?><!DOCTYPE OPS_envelope SYSTEM 'ops.dtd'>
<OPS_envelope><header><version>0.9</version></header><body><data_block>
<dt_assoc>
<item key="object">$object</item>
<item key="action">$action</item>
<item key="protocol">XCP</item>
$attribxml
$optionsxml
</dt_assoc>
</data_block></body></OPS_envelope>~;

#	$xml = qq~asdf~;

	my $request = HTTP::Request->new('POST',"https://$REMOTE_HOST");
	$request->header('Content-Type' => 'text/xml');
	$request->header('X-Username' => $DOMAIN::REGISTER::USERNAME);
	$request->header('X-Signature' => Digest::MD5::md5_hex(Digest::MD5::md5_hex($xml, $DOMAIN::REGISTER::PRIVKEY ),$DOMAIN::REGISTER::PRIVKEY ));
	$request->header('Content-Length' => length($xml));
	# $request->header('Content' => $xml);
	$request->content($xml);


	my ($response) = $ua->request($request);

	open F, ">/tmp/dns.log";
	print F Dumper($response);
	close F; 

	my $parser = new XML::Parser(Style=>'EasyTree');
#	print STDERR $response->content();
	
	my $tree = $parser->parse($response->content());
	$tree = &XMLTOOLS::chopXMLtree($tree,'OPS_envelope.body.data_block.dt_assoc');


	my %result = ();
	foreach my $node (@{$tree}) {
		next if ($node->{'type'} eq 't');

		my $attrib = '';
		if ($node->{'name'} eq 'item') { $attrib = $node->{'attrib'}->{'key'}; }
	
		if (($attrib eq 'attributes') || ($attrib eq 'options')) {
			$node = XMLTOOLS::chopXMLtree($node->{'content'},'dt_assoc');
			# print Dumper($node); die();
			
			foreach my $node2 (@{$node}) {
				next if ($node2->{'type'} eq 't');
				if (scalar(@{$node2->{'content'}})>0) {
					request_node_breakdown(\%result,$attrib,$node2);
					}
				}
			}
		else {
			$result{$node->{'name'}.'.~'.$attrib} = $node->{'content'}->[0]->{'content'};
			}
		# print Dumper($node);
		}
#	print STDERR Dumper(\%result);
	# exit;
#	print STDERR Dumper($tree);
	return(\%result);
	}

##
## this is a recursive function which helps us breakdown the tree.
##
sub request_node_breakdown {
	my ($resultref,$attrib,$node2) = @_;
	
	$resultref->{$attrib.'.'.$node2->{'name'}.'.~'.$node2->{'attrib'}->{'key'}} = $node2->{'content'}->[0]->{'content'};
	if ($node2->{'attrib'}->{'key'} eq 'field_hash') {
		foreach my $node (@{$node2->{'content'}}) {
			next if ($node->{'type'} eq 't');
			my $newattrib = $attrib.'.'.$node->{'name'};
			foreach my $node2 (@{$node->{'content'}}) {
				next if ($node2->{'type'} eq 't');
				request_node_breakdown($resultref,$attrib,$node2);
				#print Dumper($node2);
				#exit;
				}
			}
		}
	# exit;
	}

1;
