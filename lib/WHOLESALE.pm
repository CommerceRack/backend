package WHOLESALE;

##
## SCHEDULE properties
##		'SID' => '001',
##		'shiprule_mode' => 0 (disable all rules) | 1 apply rules based on how they are configured
##		'promotion_mode' => 0 (disable), 1 (use default), 2 (use alternate PROMO-SID promotions)
##		'discount_amount' => default discount (if no specific exists for the schedule)
##		'discount_default' => 0 - no default discount, 1 = apply default
##		'incomplete' => 0 - incomplete items have special pricing, 1 - no special pricing
##		'realtime_orders' => 
##		'realtime_inventory' =>
##
## use Storable;
use Data::Dumper;
use JSON::XS;

use lib "/backend/lib";
require ZOOVY;
use strict;

$WHOLESALE::CACHED_USERSID = undef;
$WHOLESALE::CACHED_SCHEDULE = undef;

##
## this function should attempt to *FIX* all the stupid things users do to break a formula.
##
sub sanitize_formula { 
	my ($formula) = @_;

	## uppercase variables
	$formula = uc($formula);

	## remove all invalid characters
	$formula =~ s/[^A-Z0-9\*\/\+\.\-\)\(]+//gs;

	## add leading zeros e.g. .70 becomes 0.70
	## if decimal is leaded by a valid operator (* + - /), fix
	$formula =~ s/(\*|\+|\-|\/)\./$1 0\./g;
	## if decimal leads formula, fix
	## other cases will break in validate
	$formula =~ s/^\./0\./g;

	## remove any whitespace.
	$formula =~ s/ //g;

	## should not begin/end with an operator
	## ie should only begin/end with char/number/parenthesis
	## this sanitation may break the formula, but keep in mind, it's
	## broken already
	##
	## get rid of leading operator (* + - / .)
	$formula =~ s/^(\*|\+|\-|\/|\.)//g;
	## get rid of trailing operator (* + - / .)
	$formula =~ s/(\*|\+|\-|\/|\.)$//g;

	## check for balanced parenthesis
	my ($cnt_start, $cnt_end);
	while($formula =~ m/\(/g){ $cnt_start++; }
   while($formula =~ m/\)/g){ $cnt_end++; }
	## adjust formula by adding ) or ( to match
	if($cnt_start > $cnt_end){ $formula .= ")" x ($cnt_start-$cnt_end); }
	if($cnt_start < $cnt_end){ $formula = "(" x ($cnt_end-$cnt_start) . $formula;	}

	return($formula);
	}


## 
## takes in a formula, returns a 1 (success), 0 (failure) if the function can be passed through
##	an eval and return a result. 
##
sub validate_formula {
	my ($formula) = @_;
	
	use Math::Symbolic;

	my $success = eval(qq~
		my \$tree = Math::Symbolic->parse_from_string(\$formula);         
		\$tree->implement('COST'=> 1 );
		\$tree->implement('BASE'=> 1 );
		\$tree->implement('SHIP'=> 1 );
		\$tree->implement('MSRP'=> 1 );
		my (\$sub) = Math::Symbolic::Compiler->compile_to_sub(\$tree);
		~);

	return($success);
	}

##
## takes in a prod_ref, and modifies the base_price based on the username/schedule  it is passed.
##	called from:
##		/backend/lib/FLOW/RENDER.pm
##		/backend/lib/STUFF.pm
##		/httpd/site/product.pl
##
sub tweak_product {
	my ($USERNAME,$SCHEDULE,$PRODREF) = @_;

	## BEGIN WHOLESALE PRICING

	if (defined $PRODREF->{'zoovy:qtyprice_'.lc($SCHEDULE)}) {
		## load a custom qtyprice for a given schedule.
		$PRODREF->{'zoovy:qty_price'} = $PRODREF->{'zoovy:qtyprice_'.lc($SCHEDULE)};
		}
	elsif ($SCHEDULE =~ /^[QM]P/) {
		## the quantity price schedules will default to the public quantity pricing. 
		}
	elsif ($SCHEDULE ne '') {
		## the non-qp schedules ignore quantity pricing.
		delete $PRODREF->{'zoovy:qty_price'};
		}
	

	if (defined $PRODREF->{'zoovy:qtymin_'.lc($SCHEDULE)}) {
		## override the minimum quantities
		$PRODREF->{lc($USERNAME).':minqty'} = $PRODREF->{'zoovy:qtymin_'.lc($SCHEDULE)};
		}
	if (defined $PRODREF->{'zoovy:qtyinc_'.lc($SCHEDULE)}) {
		## override the increment quantities
		$PRODREF->{lc($USERNAME).':incqty'} = $PRODREF->{'zoovy:qtyinc_'.lc($SCHEDULE)};
		}

  my $formula = '';
  if ((not defined $PRODREF->{'zoovy:base_price'}) || ($PRODREF->{'zoovy:base_price'} eq '')) {
    }
  elsif ((defined $SCHEDULE) && ($SCHEDULE ne '')) {
		
		if (defined $PRODREF->{'zoovy:orig_price'}) {
			$PRODREF->{'zoovy:base_price'} = $PRODREF->{'zoovy:orig_price'};
			delete $PRODREF->{'zoovy:orig_price'};
			print STDERR "ORIG:  $PRODREF->{'zoovy:orig_price'} BASE: $PRODREF->{'zoovy:base_price'}\n";
			}

		$formula = $PRODREF->{'zoovy:schedule_'.lc($SCHEDULE)};		# load formula from product

		require WHOLESALE;
		my ($S) = WHOLESALE::load_schedule($USERNAME,$SCHEDULE);

		if ((not defined $formula) || ($formula eq '')) { 
			## use the default formula if we didn't have one in the product.
			if ((defined $S->{'discount_default'}) && ($S->{'discount_default'}>0)) { $formula = $S->{'discount_amount'}; }
			}

		if ((defined $S->{'currency'}) && ($S->{'currency'} ne '')) {
			require ZTOOLKIT::CURRENCY;
			$formula = '';
			$PRODREF->{'zoovy:schedule_currency'} = $S->{'currency'};
			$PRODREF->{'zoovy:schedule_price'} = $PRODREF->{'zoovy:schedule_'.lc($SCHEDULE)};

			$PRODREF->{'zoovy:base_currency'} = 'USD';
			$PRODREF->{'zoovy:base_price'} = &ZTOOLKIT::CURRENCY::convert($PRODREF->{'zoovy:schedule_price'},
				$PRODREF->{'zoovy:schedule_currency'},
				$PRODREF->{'zoovy:base_currency'});
			
			}

		#if (int($S->{'inventory_ignore'})==1) {
		#	## turn on unlimited inventory, and flag this as a "temporary unlimited"
		#	$PRODREF->{'zoovy:inv_enable'} |= 32 + 64;
		#	};
			
		if ((not defined $formula) || ($formula eq '')) {
		  ## Don't do shit!
        }
		elsif ($formula =~ /^[\d\.]+$/) {
		  ## here's a shortcut we can take if it's guaranteed to be a decimal number
		  $PRODREF->{'zoovy:schedule'} = $SCHEDULE;
		  $PRODREF->{'zoovy:orig_price'} = $PRODREF->{'zoovy:base_price'};
		  $PRODREF->{'zoovy:base_price'} = $formula;
		  }
		elsif ($formula ne '') {	
			require Math::Symbolic;
			if ((not defined $PRODREF->{'zoovy:base_cost'}) || ($PRODREF->{'zoovy:base_cost'} eq '')) { 
            $PRODREF->{'zoovy:base_cost'} = $PRODREF->{'zoovy:base_price'}; 
            }
			if ((not defined $PRODREF->{'zoovy:prod_msrp'}) || ($PRODREF->{'zoovy:prod_msrp'} eq '')) { 
			   $PRODREF->{'zoovy:prod_msrp'} = $PRODREF->{'zoovy:base_price'}; 
            }
			if ((not defined $PRODREF->{'zoovy:ship_cost1'}) || ($PRODREF->{'zoovy:ship_cost1'} eq '')) {
            $PRODREF->{'zoovy:ship_cost1'} = 0; 
            }

			my $tree = Math::Symbolic->parse_from_string($formula);         
			if (defined $tree) {
				$tree->implement('COST'=> sprintf("%.2f",$PRODREF->{'zoovy:base_cost'}) );
				$tree->implement('BASE'=> sprintf("%.2f",$PRODREF->{'zoovy:base_price'}) );
				$tree->implement('SHIP'=> sprintf("%.2f",$PRODREF->{'zoovy:ship_cost1'}) );
				$tree->implement('MSRP'=> sprintf("%.2f",$PRODREF->{'zoovy:prod_msrp'}) );

				my ($sub) = Math::Symbolic::Compiler->compile_to_sub($tree);
				$formula = sprintf("%.2f",$sub->());
				# use Data::Dumper; print STDERR Dumper($tree,$formula);

				$PRODREF->{'zoovy:schedule'} = $SCHEDULE;
			   $PRODREF->{'zoovy:orig_price'} = $PRODREF->{'zoovy:base_price'};
			   $PRODREF->{'zoovy:base_price'} = $formula;
				}
			}
		}

	## END WHOLESALE PRICING
	return($PRODREF);
	}


#sub load_schedule_for_login {
#	my ($USERNAME,$LOGIN) = @_;
#
#	require CUSTOMER;
#	my ($C) = CUSTOMER->new($USERNAME,EMAIL=>$LOGIN,INIT=>1);
#	if (defined $C) {
#		if ($C->fetch_attrib('INFO.SCHEDULE') ne '') {
#			return(load_schedule($USERNAME,$C->fetch_attrib('INFO.SCHEDULE')));
#			}
#		}
#
#	return(undef);
#	}


##
## this could probably be done more efficiently.
##
sub schedule_exists {
	my ($USERNAME,$SID) = @_;

	## we use list_schedules now because it uses memcache
	my $schedules = &WHOLESALE::list_schedules($USERNAME,$SID);
	foreach my $sid (@{$schedules}) {
		if ($sid eq $SID) { return(1); }
		}
	return(0);
#	my ($S) = WHOLESALE::load_schedule($USERNAME,$SID);
#	return( (defined $S)?1:0 );
	}


## 
## returns a schedule list.
##
sub load_schedule {
  my ($USERNAME,$SID) = @_;

	my $SGUID = uc("$USERNAME:$SID");

  if ((defined $WHOLESALE::CACHED_USERSID) && ($WHOLESALE::CACHED_USERSID eq $SGUID)) {
    return($WHOLESALE::CACHED_SCHEDULE);
    }

	my $S = undef;
	$SID =~ s/[^\w]+//gs;
	## all schedules are saved in uppercase, patti added 9/23 
	$SID = uc($SID);
#	my $path = ZOOVY::resolve_userpath($USERNAME)."/WHOLESALE";
#
#	if ($SID eq '') {
#		}
#	elsif (-f "$path/$SID.schedule.bin") { 
#		$S = retrieve("$path/$SID.schedule.bin");
#		$S->{'SID'} = $SID;
#		if ($S->{'currency'} eq 'USD') {
#			delete $S->{'currency'};
#			}
#		}

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select JSON from WHOLESALE_SCHEDULES where MID=$MID and CODE=".$udbh->quote($SID);
	my ($JSON) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();

	$S = undef;
	if ($JSON ne '') {
		$S = JSON::XS::decode_json($JSON);
		}
   
  $WHOLESALE::CACHED_USERSID = $SGUID;
  $WHOLESALE::CACHED_SCHEDULE = $S;
    
  return($S);
  }

##
## NOTE: it's a good idea to remove all customers from a schedule BEFORE you remove the schedule.
##
sub nuke_schedule {
	my ($USERNAME,$SID) = @_;

	## LEGACY 201401
	my $path = ZOOVY::resolve_userpath($USERNAME)."/WHOLESALE";
	unlink($path."/$SID.schedule.bin");

	my ($memd) = &ZOOVY::getMemd($USERNAME);
	$memd->delete("$USERNAME.schedules");

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "delete from WHOLESALE_SCHEDULES where MID=$MID and CODE=".$udbh->quote($SID);
	print STDERR "$pstmt\n";
	$udbh->do($pstmt);

	return(1);  
	}

sub save_schedule {
  my ($USERNAME,$S) = @_;
  
#  my $path = ZOOVY::resolve_userpath($USERNAME)."/WHOLESALE";
#  $S->{'SID'} =~ s/[^\w]//gs;
#  mkdir "$path", 0777;
#  Storable::nstore $S, "$path/$S->{'SID'}.schedule.bin";
#  chmod 0666, "$path/$S->{'SID'}.schedule.bin";
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	&DBINFO::insert($udbh,'WHOLESALE_SCHEDULES',{ 
		'MID'=>$MID,
		'CODE'=>$S->{'SID'},
		'JSON'=>JSON::XS::encode_json($S)
		},key=>['MID','CODE']);
	&DBINFO::db_user_close();

	my ($memd) = &ZOOVY::getMemd($USERNAME);
	$memd->delete("$USERNAME.schedules");

  return(1);
  }

##
##
##
sub list_schedules {
	my ($USERNAME) = @_;

	my ($memd) = &ZOOVY::getMemd($USERNAME);
	my @schedules = ();

	my $cache = $memd->get("$USERNAME.schedules");	
	$cache = undef;
	if (defined $cache) {
		@schedules = split(/\|/,$cache);
		}	
	elsif (not defined $cache) {

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select CODE from WHOLESALE_SCHEDULES where MID=$MID";
	# print STDERR "$pstmt\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my $CODE = $sth->fetchrow() ) {
		push @schedules, $CODE;
		}
	$sth->finish();
	&DBINFO::db_user_close();

#		my $path = ZOOVY::resolve_userpath($USERNAME)."/WHOLESALE";
#		opendir(my $D,$path);
#		while ( my $file = readdir($D) ) {
#			next if (substr($file,0,1) eq '.');
#			if ($file =~ /^(.*?)\.schedule\.bin$/) {
#				push @schedules, $1;
#				}
#			}
#		closedir $D;
		$memd->set("$USERNAME.schedules",join("|",@schedules));
		}
	

	return(\@schedules);
	}


1;
