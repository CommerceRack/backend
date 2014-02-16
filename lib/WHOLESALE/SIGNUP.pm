package WHOLESALE::SIGNUP;

use strict;

use JSON::XS;
use lib "/backend/lib";
require ZWEBSITE;
require ZTOOLKIT;
require DOMAIN::TOOLS;

##
## configuration values:
## 	enabled
##		auto_create: auto_create
##		initial_schedule: 
##		queue_for_approval:
##		send_email,make_todo,make_ticket
##		


$WHOLESALE::SIGNUP::JSON = qq~
[
	{ "type":"legend","content":"Account Creation Form" },
	{ "type":"hint","content":"Please fill out the fields below to create a customer account. Fields with a * next to them are required." },
	{ "ignore":0,"id":"company","type":"text","label":"Company Name" },
	{ "ignore":0,"required":1,"id":"email","type":"text","label":"Email","customer":"INFO.EMAIL" },
	{ "ignore":0,"required":1,"id":"firstname","type":"text","label":"Purchasing Contact Firstname","customer":"INFO.firstname" },
	{ "ignore":0,"required":1,"id":"lastname","type":"text","label":"Purchasing Contact Lastname","customer":"INFO.lastname" },
	{ "ignore":0,"required":1,"id":"address1","type":"text","label":"Company Address 1","customer":"WS.address1" },
	{ "ignore":0,"required":1,"id":"address2","type":"text","label":"Company Address 2","customer":"WS.address2" },
	{ "ignore":1,"required":1,"id":password","type":"text","label":"Password","customer":"INFO.password", },
	{ "ignore":0,"required":1,"id":"city","type":"text","label":"Company City","customer":"WS.city" },
	{ "ignore":0,"required":1,"id":"region","type":"text","label":"Company State","customer":"WS.region" },
	{ "ignore":0,"required":1,"id":"postal","type":"text","label":"Company Zip","customer":"WS.postal" },
	{ "ignore":0,"id":"ar_contact","type":"text","label":"AR Contact","customer":"WS.BILLING_CONTACT" },
	{ "ignore":0,"id":"ar_phone","type":"text","label":"AR Phone","customer":"WS.BILLING_PHONE" },
	{ "ignore":0,"id":"order_volume","type":"text","label":"Anticipated Order Volume","customer":"META.volume" },
	{ "ignore":1,"id":"credit_reference1","type":"text","label":"Credit Reference #1","customer":"META.reference1" },
	{ "ignore":1,"id":"credit_reference2","type":"text","label":"Credit Reference #2","customer":"META.reference2" },
	{ "ignore":1,"id":"credit_reference3","type":"text","label":"Credit Reference #3","customer":"META.reference3" },
	{ "ignore":0,"required":1,"id":"resaleid","type":"text","label":"State Resale Permit","customer":"WS.RESALE_PERMIT" },
	{ "ignore":0,"id":"ein","type":"text","label":"Company EIN/Tax ID","customer":"WS.RESALE_PERMIT" },
	{ "ignore":1,"id":"credit_limit","type":"text","label":"Requested Credit Limit","customer":"META.requested_limit" },
	{ "type":"submit","label":"Create Account" }
]
~;


sub save_form {
	my ($USERNAME,$PRT,$formcfg,$vars) = @_;

   #$cfg->{'v'} = 1;
   #$cfg->{'saveinfo'} = "$LUSERNAME|".&ZTOOLKIT::pretty_date(time(),2);
   #$cfg->{'json'} = $ZOOVY::cgiv->{'json'};
   #$cfg->{'initial_schedule'} = $ZOOVY::cgiv->{'initial_schedule'};
   #$cfg->{'enabled'} = ($ZOOVY::cgiv->{'enabled'})?1:0;
   #$cfg->{'auto_create'} = ($ZOOVY::cgiv->{'auto_create'})?1:0;
   #$cfg->{'queue_for_approval'} = ($ZOOVY::cgiv->{'queue_for_approval'})?1:0;
   #$cfg->{'send_email'} = ($ZOOVY::cgiv->{'send_email'})?1:0;
   #$cfg->{'make_todo'} = ($ZOOVY::cgiv->{'make_todo'})?1:0;
   #$cfg->{'make_ticket'} = ($ZOOVY::cgiv->{'make_ticket'})?1:0;

	## %x will be a simple hashref of key values, we'll need 'email' to create account.
	my %x = (); 
	foreach my $ref (@{$vars}) { $x{ $ref->{'id'} } = $ref->{'value'}; }

	# use Data::Dumper; print STDERR Dumper($formcfg,$vars)."\n";

	my $ERR = undef;

	my $CID = 0;

	if (defined $ERR) {
		}
	elsif ($x{'email'} eq '') {
		$ERR = 'email is a required field.';
		}
	elsif (not &ZTOOLKIT::validate_email($x{'email'})) {
		$ERR = 'email format does not appear to be valid.';
		}
	elsif (&CUSTOMER::customer_exists($USERNAME,$x{'email'},$PRT)) {
		$ERR = 'the specified email address is already registered.';
		}

	if (defined $ERR) {
		}
	else {
		my ($C) = CUSTOMER->new($USERNAME,'PRT'=>$PRT,'EMAIL'=>$x{'email'},'CREATE'=>2, 'INIT'=>0xFF);
		
		$C->set_attrib('INFO.ORIGIN',99);
		foreach my $ref (@{$vars}) {
			## this is where all the META.xyz and BILL.whatever get setup.
			if ($ref->{'customer'}) {
				# print STDERR "SET: $ref->{'customer'}, $ref->{'value'}\n";
				$C->set_attrib( $ref->{'customer'}, $ref->{'value'} );
				}
			}

		if ($formcfg->{'auto_lock'}) {
			$C->set_attrib('INFO.IS_LOCKED',1);
			}
#		if ($formcfg->{'initial_schedule'}) {
#			$C->set_attrib('INFO.SCHEDULE', $formcfg->{'initial_schedule'});
#			}

		$C->save();
		$CID = $C->cid();
		## use Data::Dumper; print STDERR 'CUSTOMER: '.Dumper($C);
		}

	if (defined $ERR) {
		}
	else {
		my $body = '';
		foreach my $ref (@{$vars}) {
			$body .= sprintf("%s: %s\n",$ref->{'label'},$ref->{'value'});
			}

		#my ($PROFILE) = &ZOOVY::profile_to_prt($USERNAME,$PRT);
		## my ($PROFILE) = &ZOOVY::prt_to_profile($USERNAME,$PRT);
		my ($DOMAIN) = &DOMAIN::TOOLS::domain_for_prt($USERNAME,$PRT);

		#if ($formcfg->{'send_email'}) {
		#	require ZMAIL;
		#	&ZMAIL::notify_customer($USERNAME, "admin\@$USERNAME.zoovy.com", 
		#		"Wholesale Signup", $body, "SIGNUP", {}, 1, $PROFILE);						
		#	}
		if ($formcfg->{'make_todo'}) {
			require TODO;
			&TODO::easylog($USERNAME,class=>"INFO",title=>"New Customer Signup",detail=>$body,priority=>2,link=>"cid:$CID");
			}
		if ($formcfg->{'make_ticket'}) {
			require CUSTOMER::TICKET;
			my ($CT) = CUSTOMER::TICKET->new($USERNAME,0,
					new=>1,PRT=>$PRT,CID=>$CID,DOMAIN=>$DOMAIN,
					SUBJECT=>"New Account Signup",
					NOTE=>$body,
					);
			}

		# print STDERR "BODY: $body\n";
		}
	## print STDERR "CID: $CID [$ERR]\n";
	return($ERR);
	}



##
##
##
sub ref_to_vars {
	my ($ref,$v) = @_;

	my @VARS = ();
	foreach my $f (@{$ref}) {
		my $value = $v->{ $f->{'id'} };

		if ($f->{'unsafe'}) {
			## we're going to allow unsafe characters, hope you know what you're doing!
			}
		else {
			## for now, we'll remove <> to make things safe!
			$value =~ s/[\<\>]+/_/gs;
			}

		if ($f->{'type'} eq 'text') {
			$f->{'value'} = $value;
			if (($f->{'required'}) && ($value eq '')) {
				$f->{'err'} = "is required field";
				}
			push @VARS, $f;
			}

		}
	return(\@VARS);
	}


#  perl -e 'use lib "/backend/lib"; use WHOLESALE::SIGNUP; use Data::Dumper; print WHOLESALE::SIGNUP::ref_to_sitehtml(WHOLESALE::SIGNUP::json_to_ref($WHOLESALE::SIGNUP::JSON));'
sub ref_to_sitehtml {
	my ($ref,$v) = @_;

	my $html = '<fieldset>';
	foreach my $f (@{$ref}) {
		next if ($f->{'ignore'});	# skip over 'ignore':1 fields

		my $value = $v->{ $f->{'id'} };
		if ($f->{'unsafe'}) {
			## we're going to allow unsafe characters, hope you know what you're doing!
			}
		else {
			## for now, we'll remove <> to make things safe!
			$value =~ s/[\<\>]+/_/gs;
			}
		
		my $is_required = ($f->{'required'})?'* ':'';
		if ($is_required && $f->{'err'}) {
			$is_required = "<span class=\"zwarn\">$is_required</span>";
			}

		if ($f->{'type'} eq 'legend') {
			$html .= qq~<legend class="ztitle">$f->{'content'}</legend>~;
			}
		elsif ($f->{'type'} eq 'hint') {
			$html .= qq~<div class="zhint">$f->{'content'}</div>~;
			}
		elsif ($f->{'type'} eq 'text') {
			$value = &ZOOVY::incode($value);
			$html .= qq~
<div class="zform_div">
<label for="$f->{'id'}">$is_required$f->{'label'}</label>
<input type="text" id="$f->{'id'}" class="zform_textbox" name="$f->{'id'}" value="$value"/>
</div>~;
			}
		elsif ($f->{'type'} eq 'textarea') {
			if (not defined $f->{'cols'}) { $f->{'cols'} = 70; }
			if (not defined $f->{'rows'}) { $f->{'rows'} = 3; }
			$value = &ZOOVY::incode($value);
			$html .= qq~
<div class="zform_div">
<label for="$f->{'id'}">$is_required$f->{'label'}</label>
<textarea cols="$f->{'cols'}" rows="$f->{'rows'}" id="$f->{'id'}" class="zform_textarea" name="$f->{'id'}">$value</textarea>
</div>~;
			}
		elsif ($f->{'type'} eq 'submit') {
			$html .= qq~
<div class="zform_div"><input type="submit" id="customer_signup_submit_button" class="zform_button" value="$f->{'label'}"/></div>
~;
			}
		else {
			$html .= "<!-- unknown field: $f->{'label'} -->";
			}
		}
	$html .= "</fieldset>";
	return($html);
	}


# perl -e 'use lib "/backend/lib"; use WHOLESALE::SIGNUP; use Data::Dumper; 
# print Dumper(WHOLESALE::SIGNUP::json_to_ref($WHOLESALE::SIGNUP::JSON));'
sub json_to_ref {
	my ($json) = @_;
	
 	my $arrayref  = JSON::XS::decode_json($json);
	return($arrayref);
	}


##
## a quick method for deserializing a wholesale configuration
##
sub load_config {
	my ($USERNAME,$PRT) = @_;

	# print STDERR "LOAD CONFIG -- USERNAME:$USERNAME PRT:$PRT\n";
	my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	my $ref = &ZTOOLKIT::parseparams($webdb->{'wholesale_signup'});
	if ($ref->{'json'} eq '') { 
		$ref->{'enabled'} = 0;
		$ref->{'json'} = $WHOLESALE::SIGNUP::JSON; 
		}
	return($ref);
	}

##
## a quick method for persistently serializing a wholesale configuration.
##
sub save_config {
	my ($USERNAME,$PRT,$VARS) = @_;
	my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	$webdb->{'wholesale_signup'} = &ZTOOLKIT::buildparams($VARS);
	&ZWEBSITE::save_website_dbref($USERNAME,$webdb,$PRT);
	return();
	}


1;