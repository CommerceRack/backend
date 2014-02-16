package INVENTORY2::UTIL;


##
## purpose: combine (sum) a hashref of prod:#Z01=>value into a new hash keyed by product
##
sub combine_pogs {
   my ($hashref) = @_;

   my %prods = ();
   foreach my $sku (keys %{$hashref}) {
      my $prod = $sku;
      if (index($prod,':')>0) { $prod = substr($sku,0,index($prod,':')); }
      if (index($prod,'/')>0) { $prod = substr($sku,0,index($prod,'/')); }
      $prods{$prod} += $hashref->{$sku};
      }
   return(\%prods);
   }

##
##
##
sub request_notification {
	my ($USERNAME, $SKU, %options) = @_;

	my $error = undef;

	$SKU =~ s/[^\w\-\:]+/_/go;		# strips invalid characters
	if (not defined $options{'NS'}) { $options{'NS'} = 'DEFAULT'; }
	
	#if ((defined $options{'NS'}) && ($options{'PRT'})) {
	#	## got both PRT and NS
	#	}
	#elsif (defined $options{'NS'}) {
	#	## lookup PRT from profile
	#	$options{'PRT'} = &ZOOVY::profile_to_prt($USERNAME,$options{'NS'});
	#	}
	if (defined $options{'PRT'}) {
		## lookup profile from PRT
		$options{'PROFILE'} = &ZOOVY::prt_to_profile($USERNAME,$options{'PRT'});
		}
	else {
		$options{'PRT'} = 0;
		$options{'NS'} = 'DEFAULT';
		}

	my ($PID) = &PRODUCT::stid_to_pid($SKU);
	if (not defined $options{'MSGID'}) { $options{'MSGID'} = 'PINSTOCK'; }
	if (not defined $options{'CID'}) {
		$options{'CID'} = CUSTOMER::resolve_customer_id($USERNAME,$options{'PRT'},$options{'EMAIL'});
		}
	if ($options{'CID'}<0) { $options{'CID'} = undef; }

	if (($options{'CID'}==0) && ($options{'EMAIL'} eq '')) {
		$error = "Unknown customer or invalid email address";
		}

	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = &DBINFO::insert($udbh,'USER_EVENTS_FUTURE',{
		MID=>&ZOOVY::resolve_mid($USERNAME),
		USERNAME=>$USERNAME,
		PRT=>$options{'PRT'},
		PROFILE=>$options{'NS'},
		CREATED_GMT=>time(),
		TYPE=>'INVENTORY',
		UUID=>$SKU,
		MSGID=>$options{'MSGID'},
		CID=>$options{'CID'},
		EMAIL=>$options{'EMAIL'},
		VARS=>$options{'VARS'},
		},debug=>2);
	print STDERR $pstmt."\n";
	$udbh->do($pstmt);
	&DBINFO::db_user_close();

	return($error);
	}



1;