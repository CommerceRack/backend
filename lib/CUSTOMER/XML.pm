package CUSTOMER::XML;

use lib "/backend/lib";
require ZTOOLKIT;

=pod

[[SUBSECTION]Customer XML Record]
[[HTML]]
<CUSTOMER CID="" EMAIL="">
<INFO>
	<FIRSTNAME></FIRSTNAME>
	<LASTNAME></LASTNAME>
</INFO>
<BILLING>
	<ADDRESS ID="" bill_company="" bill_city="" bill_state="" bill_zip=""  bill_address1="" bill_address2=""/>
	<ADDRESS ID="" bill_company="" bill_city="" bill_state="" bill_zip=""  bill_address1="" bill_address2=""/>
</BILLING>
<SHIPPING>
	<ADDRESS ship_company="" ship_city="" ship_state="" ship_zip=""  ship_address1="" ship_address2=""/>
	<ADDRESS ship_company="" ship_city="" ship_state="" ship_zip=""  ship_address1="" ship_address2=""/>
</SHIPPING>
<META>
	<tag1></tag2>
</META>
<WS>
	<ws_company></ws_company>
	<ws_address1></ws_address1>
	<ws_address2></ws_address2>
	<ws_city></ws_city>
	<ws_state></ws_state>
	<ws_zip></ws_zip>
	<ws_country></ws_country>
	<ws_phone></ws_phone>
	<LOGO></LOGO>
	<BILLING_CONTACT></BILLING_CONTACT>
	<BILLING_PHONE></BILLING_PHONE>
	<ALLOW_PO></ALLOW_PO>
	<RESALE></RESALE>
	<RESALE_PERMIT></RESALE_PERMIT>
	<CREDIT_LIMIT></CREDIT_LIMIT>
	<CREDIT_BALANCE></CREDIT_BALANCE>
	<ACCOUNT_MANAGER></ACCOUNT_MANAGER>
	<JEDI_MID></JEDI_MID>
</WS>
<NOTES>
	<NOTE LUSER="" CREATED_GMT="">..note..</NOTE>
	<NOTE LUSER="" CREATED_GMT="">..note..</NOTE>
	<NOTE LUSER="" CREATED_GMT="">..note..</NOTE>
</NOTES>
</CUSTOMER>
[[/HTML]]
[[/SUBSECTION]]

=cut

sub as_xml {
	my ($self,$XCOMPAT) = @_;

	my $out = "<CUSTOMER CID=\"$self->{'_CID'}\" EMAIL=\"".&ZTOOLKIT::encode($self->{'_EMAIL'})."\">\n";
	##		_STATE = 0 --> not loaded/no information saved.
	##		_STATE = +1 --> initialized w/primary info
	if ($self->{'_STATE'}&1) {

		if ($XCOMPAT<110) {
			$self->{'INFO'}->{'FULLNAME'} =  $self->{'INFO'}->{'FIRSTNAME'}.' '.$self->{'INFO'}->{'LASTNAME'};
			}

		$out .= "<INFO>\n".&ZTOOLKIT::hashref_to_xmlish($self->{'INFO'},encoder=>'latin1',skip_blanks=>1)."</INFO>\n\n";
		}

	##		_STATE = +2 --> initialized w/billing info
	if ($self->{'_STATE'}&2) {
		$out .= "<BILLING>\n";
		my @ADDRESSES = ();
		foreach my $addr (@{$self->fetch_addresses('BILL')}) { push @ADDRESSES, $addr->TO_HASHREF(); }
		$out .= &ZTOOLKIT::arrayref_to_xmlish_list(\@ADDRESSES,tag=>'ADDRESS',encoder=>'latin1',skip_blanks=>1)."\n";
		$out .= "</BILLING>\n\n";
		}
	##		_STATE = +4 --> initialized w/shipping info
	if ($self->{'_STATE'}&4) {
		$out .= "<SHIPPING>\n";
		## this is to correct an issue in order manager where it doesn't like a non-two-digit state
		## which happens from time to time.
		my @ADDRESSES = ();
		foreach my $addr (@{$self->fetch_addresses('SHIP')}) { push @ADDRESSES, $addr->TO_HASHREF(); }
		$out .= &ZTOOLKIT::arrayref_to_xmlish_list(\@ADDRESSES,tag=>'ADDRESS',encoder=>'latin1',skip_blanks=>1)."\n";
		$out .= "</SHIPPING>\n\n";
		}

	##		_STATE = +8 --> initialized w/meta info
	if ($self->{'_STATE'}&8) {
		$out .= "<META>".&ZTOOLKIT::hashref_to_xmlish($self->{'META'},encoder=>'latin1',skip_blanks=>1)."</META>\n\n";
		}

	##		_STATE = +16 --> initialized w/wholesale info (WS->{} populated)
	if ($self->{'_STATE'}&16) {
		my ($ORG) = $self->org();
		if (defined $ORG) {
			my $WSREF = $ORG->TO_JSON();
			$out .= "<WS>".&ZTOOLKIT::hashref_to_xmlish($WSREF,encoder=>'latin1',skip_blanks=>1)."</WS>\n\n";
			}
		}

	##		_STATE = +32 --> initialized w/notes
	if ($self->{'_STATE'}&16) {
		$out .= "<NOTES>".&ZTOOLKIT::arrayref_to_xmlish_list($self->{'@NOTES'},tag=>'NOTE',content_attrib=>'NOTE',encoder=>'latin1',skip_blanks=>1)."</NOTES>\n\n";
		}

	$out .= "</CUSTOMER>";
	}

##
##
sub from_xml {
	my ($self, $xml, $XCOMPAT) = @_;

	# die();

	if ($xml =~ /<CUSTOMER CID=\"(.*?)\"/) {
		## This is an existing CID
		$self->{'_CID'} = $1;
		if ($self->{'_CID'}==-1) {
			## CID of -1 means delete (we'll do this in a bit once we have an email address)
			}
		elsif ($self->{'_CID'}==0) {
			## New customer?? (Request to create)
			##		hmm.. this is a bad plan, because this *should* be a lookup request 
			##		we need to pass 0 as the CID to trigger a lookup since the customer *could* have been
			## 	created on the web.
			$self->{'_STATE'} = 0; $self->{'_CID'} = 0;
			}
		else {
			($self) = CUSTOMER->new($self->{'_USERNAME'},CID=>$self->{'_CID'},initx=>0xFF);
			# print Dumper($self); die();
			if (not defined $self) { return(undef); }	# shit, can't find CID?? uh-oh, must be a whacker!
			}
		}	
	
	if ($xml =~ /\<INFO\>(.*?)\<\/INFO\>/s) {
		$self->{'_STATE'} += 1;
		my $inforef = &ZTOOLKIT::xmlish_to_hashref($1,'decoder'=>'latin1');
		## NOTE: remote clients don't pass back passwords, or other settings, during a sync
		##			so we need to overwrite fields. rather than just do an all out replace.
		if (not defined $self->{'INFO'}) { $self->{'INFO'} = {}; }
		foreach my $k (keys %{$inforef}) {
			$self->{'INFO'}->{$k} = $inforef->{$k};
			}
		$self->{'_EMAIL'} = $self->{'INFO'}->{'EMAIL'};
		$self->{'_PRT'} = $self->{'INFO'}{'PRT'} if $self->{'INFO'}{'PRT'};
		}

#	print STDERR "CID IS: $CID\n";
	if ($self->{'_CID'} == -1) {
		print STDERR "deleting .. $self->{'_USERNAME'},$self->{'_EMAIL'}\n";
		&CUSTOMER::delete_customer($self->{'_USERNAME'},$self->{'_EMAIL'});
		return(undef);
		}
	elsif ($self->{'_CID'}==0) {
		## NOTE: the CUSTOMER->save() function requires a CID of -1 to create a new customer (doh!)
		$self->{'_CID'} = -1;
		}

	if ($xml =~ /\<BILLING\>(.*?)\<\/BILLING>/s) {
		if ($1 ne '') {
			foreach my $addrref (@{&ZTOOLKIT::xmlish_list_to_arrayref($1,tag=>'ADDRESS',encoder=>'latin1',skip_blanks=>1)}) {
				my ($ID) = $addrref->{'ID'};
				delete $addrref->{'ID'};
				my ($addr) = CUSTOMER::ADDRESS->new($self,'BILL',{},'SHORTCUT'=>$ID)->from_legacy($addrref);
				$self->add_address($addr,'SHORTCUT'=>$ID); 
				}
			}
		}

	if ($xml =~ /\<SHIPPING\>(.*?)\<\/SHIPPING>/s) {
		if ($1 ne '') {
			foreach my $addrref (@{&ZTOOLKIT::xmlish_list_to_arrayref($1,tag=>'ADDRESS',encoder=>'latin1',skip_blanks=>1)}) {
				my ($ID) = $addrref->{'ID'};
				delete $addrref->{'ID'};
				my ($addr) = CUSTOMER::ADDRESS->new($self,'SHIP',{},'SHORTCUT'=>$ID)->from_legacy($addrref);
				$self->add_address($addr,'SHORTCUT'=>$ID); 
				}
			}
		}

	if ($xml =~ /\<META\>(.*?)\<\/META\>/s) {
		if ($1 ne '') {
			$self->{'META'} = &ZTOOLKIT::xmlish_to_hashref($1,'decoder'=>'latin1');
			$self->{'_STATE'} += 8;
			}
		}

	## NOT SURE IF THIS WORKS OR IS EVEN USED:
	#if ($xml =~ /\<WS\>(.*?)\<\/WS\>/s) {
	#	require CUSTOMER::ORGANIZATION;
	#	$self->{'_STATE'} += 16;
	#	my $WSADDR = &ZTOOLKIT::xmlish_to_hashref($1,'decoder'=>'latin1');
	#	my ($addr) = CUSTOMER::ORGANIZATION->new_from_customer($self,$WSADDR);
	#	$self->{'WS'} = $addr;
	#	}

	if ($xml =~ /\<NOTES\>(.*?)\<\/NOTES\>/s) {
		$self->{'_STATE'} += 32;
		my $xml = $1;
		$self->{'NOTES'} =  &ZTOOLKIT::xmlish_list_to_arrayref($1,tag=>'NOTE',encoder=>'latin1',skip_blanks=>1);	
		foreach my $noteref (@{$self->{'NOTES'}}) {
			$noteref->{'NOTE'} = $noteref->{'content'};
			delete $noteref->{'content'};

			if ($noteref->{'ID'}==0) {
#[Wed Apr 02 08:55:03 2008] [error] [client 192.168.1.200] $VAR1 = [
#[Wed Apr 02 08:55:03 2008] [error] [client 192.168.1.200]           {
#[Wed Apr 02 08:55:03 2008] [error] [client 192.168.1.200]             'ID' => 0,
#[Wed Apr 02 08:55:03 2008] [error] [client 192.168.1.200]             'LUSER' => 'asdf',
#[Wed Apr 02 08:55:03 2008] [error] [client 192.168.1.200]             'content' => 'testing',
#[Wed Apr 02 08:55:03 2008] [error] [client 192.168.1.200]             'CREATED_GMT' => '1207151105'
#[Wed Apr 02 08:55:03 2008] [error] [client 192.168.1.200]           }
#				print STDERR Dumper($self->{'NOTES'},$xml); use Data::Dumper;	die();
				($noteref->{'ID'}) = $self->save_note($noteref->{'LUSER'},$noteref->{'NOTE'},$noteref->{'CREATED_GMT'});
				}
			}
		}

#	print STDERR $xml."\n";
#	use Data::Dumper;
#	print STDERR Dumper($self);

	$self->save();
	return($self);
	}

##
##
##
sub import {
	my ($USERNAME,$DATA,$XCOMPAT) = @_;

	require CUSTOMER;
	require ZTOOLKIT;
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	print STDERR "Running CUSTOMER::XML::import\n";

	# if we split on the </customer> tag, then we know everything before it is a
	# valid customer (at least anything after the <customer xxx> tag)
	my @ar = split(/\<\/CUSTOMER\>/s,$DATA."\n");
	# always remove the last element of the ARRAY since nothing good can come
	# after a </customer> tag
	pop(@ar);

	my $XML = '';
	foreach my $xblock (@ar) {
		my ($C) = CUSTOMER->new($USERNAME)->from_xml($xblock.'</CUSTOMER>',$XCOMPAT);
		# use Data::Dumper; print STDERR Dumper($C);
	
		next if (not defined $C);	## if we deleted a customer, $C will be undefined!
		# $C->save();

		$XML .= "<CUSTOMER CID=\"$C->{'_CID'}\" EMAIL=\"$C->{'_EMAIL'}\" TS=\"$C->{'INFO'}->{'MODIFIED_GMT'}\"/>\n";
		} 

	return($XML);
	}


1;
