#!/usr/bin/perl


use Carp;
use Date::Parse;
use strict;
use lib "/httpd/modules";
require SYNDICATION;
require SYNDICATION::BUYCOM;
use Data::Dumper;
use Net::FTP;
use CART2;
require LISTING::MSGS;
use IO::Scalar;
use IO::String;
require LUSER::FILES;
use URI::Escape;

use Text::CSV_XS;
my $csv = Text::CSV_XS->new({sep_char=>"\t",quote_char=>undef,escape_char=>undef,binary=>1});

##
## parameters: 
##		user=toynk prt=0
##		verb=tracking
##			DEBUGORDER=####-##-#####
##		download=1
##		unlock=1
##		REDO=filename 
##			RECREATE=2009-01-1234 (will recreate the stuff in the order)
##			IGNORE_EREFID=1	(will die before order is created, but will go through the steps to re-create)
##

my %params = ();
foreach my $arg (@ARGV) {
	if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}



if ($params{'verb'} eq 'tracking') {
	}
elsif ($params{'verb'} eq 'orders') {
	}
else {
	die("Try a valid verb (orders, tracking)\n");
	}

if ($params{'dst'} eq '') { 
	die("dst=BUY or dst=BST is required");
	}


my @USERS = (); 
if ($params{'user'} eq '') {
	die("user= is required");
#	$params{'cluster'} = &ZOOVY::resolve_cluster($params{'user'});
	}

#if ($params{'cluster'} eq '') {
#	die("cluster= is required");
#	}

my $DST = uc($params{'dst'});

if (1) {
	my $udbh = &DBINFO::db_user_connect($params{'user'});
#	if ((not defined $params{'profile'}) && (defined $params{'prt'})) {
		## if we get a prt, but not a profile, then lookup the profile
#		$params{'profile'} = &ZOOVY::prt_to_profile($params{'user'},$params{'prt'});
#		}
	my $pstmt = "select USERNAME,DOMAIN,ID,ERRCOUNT from SYNDICATION where DSTCODE='$DST' and IS_ACTIVE>0 ";
	if ($params{'user'} ne '') {
		$pstmt .= " and MID=".&ZOOVY::resolve_mid($params{'user'});		
		}
	if ($params{'verb'} eq 'tracking') {
#		$pstmt .= " order by TRACKING_NEXTRUN_GMT";
		}
	print $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($USERNAME,$DOMAIN,$ID,$ERRCOUNT) = $sth->fetchrow() ) {
		if ($ERRCOUNT>20) {
			print "USER:$USERNAME DOMAIN:$DOMAIN ID:$ID was skipped due to ERRCOUNT=$ERRCOUNT\n";
			}
		else {
			push @USERS, [ $USERNAME, $DOMAIN, $ID ];
			print "USERNAME: $USERNAME $DOMAIN\n";
			}
		}
	$sth->finish();
	&DBINFO::db_user_close();
	}


foreach my $set (@USERS) {
	my ($USERNAME,$DOMAIN,$ID) = @{$set};

	my ($lm) = undef;
	if ($DST eq 'BUY') {
		$lm = LISTING::MSGS->new($USERNAME,'logfile'=>"~/buycom-%YYYYMM%.log",'stderr'=>1);
		}
	elsif ($DST eq 'BST') {
		$lm = LISTING::MSGS->new($USERNAME,'logfile'=>"~/bestbuy-%YYYYMM%.log");
		}

	my ($so) = SYNDICATION->new($USERNAME,$DST,'DOMAIN'=>$DOMAIN,'ID'=>$ID,'*MSGS'=>$lm,'verb'=>$params{'verb'});

	my $ERROR = '';
	tie my %s, 'SYNDICATION', THIS=>$so;

	my $ftp = SYNDICATION::BUYCOM::ftp_connect($so,$lm);

	if (($ERROR) && ($so->get('ERRCOUNT')>1000)) {
		ZOOVY::confess($so->username(),"Deactivated $DST syndication for $USERNAME due to >1000 errors\n".Dumper($so),justkidding=>1);
		$so->deactivate();
		}

	if ($ERROR ne '') {
		warn "$USERNAME error=$ERROR";
		$so->inc_err();
		$lm->pooshmsg('ERROR|+Unable to login to ftp site.');
		$so->save();
		}
	elsif (not &DBINFO::task_lock($USERNAME,$DST."-".$params{'verb'},(($params{'unlock'})?"PICKLOCK":"LOCK"))) {
		$lm->pooshmsg("STOP|+Could not obtain opportunistic lock");
		}
	elsif ($params{'verb'} eq 'orders') { 
		$lm->pooshmsg("INFO|+Performing feed $params{'verb'}");
		&downloadOrders($so, $ftp, $lm, %params);
		$lm->pooshmsg("INFO|+Finished feed $params{'verb'}");
		}
	elsif ($params{'verb'} eq 'tracking') { 
		$lm->pooshmsg("INFO|+Performing feed $params{'verb'}");
		my $udbh = &DBINFO::db_user_connect($USERNAME);
		#my $pstmt = "update SYNDICATION set TRACKING_NEXTRUN_GMT=".(time())." where ID=$ID /* $USERNAME:$PROFILE */";
		#print "$pstmt\n";
		#$udbh->do($pstmt);

		&uploadTracking($so, $ftp, $lm, %params);
		&trackingAck($so, $ftp, $lm, %params);
	
		## this will make the tracking problem happen for everybody, not just owen @ nyciwear
		## but that will make it better for him, because it just won't happen as often to him anymore.
		## but it will be worse for everybody else. I FIXED IT!
		#my $pstmt = "update SYNDICATION set TRACKING_NEXTRUN_GMT=".(time()+(3600))." where ID=$ID /* $USERNAME:$PROFILE */";
		#print "$pstmt\n";
		#$udbh->do($pstmt);
		&DBINFO::db_user_close();
		$lm->pooshmsg("INFO|+Finished feed $params{'verb'}");
		}
	#elsif ($params{'verb'} eq 'productack') { 
	#	$lm->pooshmsg("INFO|+Performing feed $params{'verb'}");
	#	&productAck($so, $ftp, %params);
	#}
	else {
		$lm->pooshmsg("INFO|+Unknown feed verb:$params{'verb'}");
		warn "$USERNAME Unknown verb=$params{'verb'}";
		}

	$ftp->quit();

	&DBINFO::task_lock($USERNAME,$DST."-".$params{'verb'},"UNLOCK");
	}

exit(1);





##
##
##
sub downloadOrders {
	my ($so, $ftp, $lm, %params) = @_;

	my $ERROR = '';
	my $USERNAME = $so->username();
	my $DSTCODE = $so->dstcode();


	# print Dumper($so);

	if (not $ERROR) {
		$ftp->binary();
		}


	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	print "GETTING ORDERS FOR $USERNAME!\n";
	$ftp->cwd("/Orders") or die "Cannot change working directory ", $ftp->message;

	my @ORDERSCSV = ();
	if ($params{'REDO'} ne '') {
		## redo an import (perhaps there was an issue?)
		open F, "<$params{'REDO'}";
		$/ = undef; my ($str) = <F>; $/ = "\n";
		close F;
		push @ORDERSCSV, [ $params{'REDO'}, $str ];
		}
	else {
		## ftp download orders.
		my %vars = ();
		$vars{'USERNAME'} = $so->username();
		$vars{'MID'} = $so->mid();
		$vars{'PRT'} = $so->prt();
		$vars{'DST'} = $DSTCODE;
		
		foreach my $remote_filename ($ftp->ls("/Orders")) {
			next unless ($remote_filename =~ /\.txt$/);
			print "FILE: $remote_filename\n";	
	
			my ($ios) = IO::String->new();
			$ftp->get("/Orders/$remote_filename",$ios) or die "get failed ", $ftp->message;
			my $str = ${$ios->string_ref()};
			$lm->pooshmsg("INFO|+Found order file: $remote_filename to process");
			my ($lf) = LUSER::FILES->new($USERNAME, 'app'=>'BUYCOM');
			$lf->add(
				buf=>$str,
				type=>$DSTCODE,
				title=>$DSTCODE."_".$remote_filename,
				meta=>{'DSTCODE'=>$DSTCODE ,'TYPE'=>$params{'verb'}},
				);

			my $local_filename = $DSTCODE."_".$remote_filename;
			my $local_filenamepath = &ZOOVY::resolve_userpath($USERNAME).'/PRIVATE/'.$local_filename;
			$lm->pooshmsg("INFO|+Saving to ".$local_filenamepath);

			$vars{'JOB_ID'} = $remote_filename;
			$vars{'JOB_TYPE'} = 'ORDERS';
			$vars{'FILENAME'} = $local_filename;
			$vars{'*CREATED_TS'} = 'now()';
			$vars{'*PROCESSED_TS'} = '0';

			my $pstmt = &DBINFO::insert($udbh,'SYNDICATION_JOBS',\%vars,sql=>1,verb=>'insert');
			print "$pstmt\n";
			$udbh->do($pstmt);
			$pstmt = "select last_insert_id()";
			my ($DBID) = $udbh->selectrow_array($pstmt);

			if ($DBID>0) {
				print "Renaming file $remote_filename to Archive folder\n";
				$ftp->rename("/Orders/$remote_filename","/Orders/Archive/2$remote_filename");
				}
			}
		}
	$ftp->quit();


	##
	## SANITY: at this stage we have  @ORDERSCSV = ( [ $filename, $csvcontents ] );
	##
	my $ORDERTS = 0;
	my $USERPATH = &ZOOVY::resolve_userpath($so->username());
	my ($MID) = $so->mid();
	my ($PRT) = $so->prt();
	my $pstmt = "select ID,FILENAME from SYNDICATION_JOBS where MID=$MID and PRT=$PRT and JOB_TYPE='ORDERS' and DST=".$udbh->quote($DSTCODE)." and PROCESSED_TS=0";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($DBID,$FILENAME) = $sth->fetchrow() ) {
		my $str = '';
		open F, "<$USERPATH/PRIVATE/$FILENAME";  $/ = undef; while (<F>) { $str = "$_"; } close F;
		if ($str eq '') {
			$lm->pooshmsg("ISE|+FILE: $USERPATH/PRIVATE/$FILENAME is empty");
			}
		
		my $lc = 0;		# line count
		my @header = ();
		my %ORDERS = ();
		my $FILE_VERSION = 1;
		foreach my $line (split(/[\n\r]+/,$str)) {
			# print "LINE:($line)\n";
			if ($lc == 0) {
				## look for directives while lc is 0
				if ($line =~ /^\#\#Type\=Order\;Version\=5\.0$/) {
					$line = '';	$FILE_VERSION = 5;
					}
				elsif ($line =~ /\^#/) {
					## future proofing their stupidity.
					die "UNKNOWN DIRECTIVE: $line\n";
					}
				}
			next if ($line eq '');	## ignore blank lines (don't increment line counter either)
			$lc++;
			# print "LINE[$line]\n";
			my $status = $csv->parse($line);         # parse a CSV string into fields
			my @columns = $csv->fields();            # get the parsed fields
			# print Dumper(\@columns);
		
			next if ($columns[0] eq '');
			# print "LC: $lc\n"; # Dumper(\@columns);

			if ($lc == 1) {
				@header = @columns;
				}
			else {
				my %line = ();
				for (my $i = scalar(@header); $i>0; --$i) { 
					$line{$header[$i]} = $columns[$i];
					}
				$line{'v'} = $FILE_VERSION;
				$line{'_FILENAME'} = $FILENAME;
				if ($FILE_VERSION == 1) {
					push @{$ORDERS{ "$line{'Receipt_ID'}" }}, \%line;
					}
				elsif ($FILE_VERSION == 5) {
					push @{$ORDERS{ "$line{'OrderId'}" }}, \%line;
					}
				else {
					die("Unknown file version");
					}
				}
			}

		foreach my $OrderId (sort keys %ORDERS) {
			if ($OrderId eq '') {
				warn "blank Receipt_ID\n";
				}
			elsif (scalar(@{$ORDERS{$OrderId}})==0) {
				warn "No orders? Wtf\n";
				}
			else {
				my $CREATED = 0;
				if ($ORDERS{$OrderId}->[0]->{'v'} == 1) {
					$CREATED = Date::Parse::str2time($ORDERS{$OrderId}->[0]->{'Date_Entered'});
					}
				elsif ($ORDERS{$OrderId}->[0]->{'v'} == 5) {
					$CREATED = Date::Parse::str2time($ORDERS{$OrderId}->[0]->{'OrderDate'});
					}
				else {
					die("Unknown order version");
					}
				if ($CREATED>$ORDERTS) { $ORDERTS = $CREATED; } 	# keep a high watermark for order timestamps.
				my $olm = $params{'*LM'} = LISTING::MSGS->new($so->username());
				my ($OID) = &createOrder($so,$olm,\%params,$OrderId,$ORDERS{$OrderId});
				$lm->merge($olm,'%mapstatus'=>{ 'STOP'=>'ORDER-STOP', 'ERROR'=>'ORDER-ERROR' });
				}
			}
		
		if ($lm->can_proceed()) {
			## FLAG THIS ORDER AS PROCESSED
			$pstmt = "update SYNDICATION_JOBS set PROCESSED_TS=now() where MID=$MID and PRT=$PRT and ID=$DBID";
			print "$pstmt\n";
			$udbh->do($pstmt);
			}
		else {
			print Dumper($lm);
			}

		}
	$sth->finish();





	## SANITY: at this point we have %ORDERS which is a hash keyed by order id,
	##				and the value is an array of lines hashrefs, the line is keyed by each value.
	#          {
	#            '' => undef,
	#            'Ship_To_Company' => '',
	#            'Ship_To_Zip' => '478033920',
	#          *  'ReferenceId' => 'PMG-6801467L-C',
	#            'Bill_To_Phone' => '8122402716',
	#            'ShippingFee' => '0',
	#            'Ship_To_Street1' => '5500 Wabash Ave',
	#            'Ship_To_City' => 'Terre Haute',
	#            'Product_Rev' => '43',
	#          *  'Quantity' => '1',
	#            'Email' => 'mario3@gmail.com',
	#          *  'PerItemFee' => '0.99',
	#            'Price' => '43',
	#            'Bill_To_Lname' => 'Plascak',
	#            'Qty_Shipped' => '0',
	#            'Shipping_Cost' => '9.99',
	#            'ShippingOwed' => '9.99',
	#          *  'ListingID' => '53026907',
	#            'Bill_To_Fname' => 'Michael',
	#            'Tax_Cost' => '0',
	#          *  'Title' => 'Paper Magic Group 34066 Street Fighter Ryu Adult Costume Size Large',
	#            'Receipt_ID' => '49230809',
	#            'Date_Entered' => '10/1/2009 8:51:00 PM',
	#            'Bill_To_Company' => '',
	#            'Qty_Cancelled' => '0',
	#            'ShippingMethodId' => '1',
	#            'Receipt_Item_ID' => '82389688',
	#            'Ship_To_State' => 'IN',
	#            'Commission' => '6.45',
	#            'ProductOwed' => '35.56',
	#            'Ship_To_Name' => 'Michael Plascak',
	#            'Ship_To_Street2' => 'CM 1843',
	#          *  'Sku' => '211934019'
	#          }
	#	

	if ($ORDERTS>0) {
		$so->set('ORDERS_LASTRUN_GMT',$ORDERTS);
		$so->save();
		}

	&DBINFO::db_user_close();
	}


sub createOrder {
	my ($so,$olm,$paramsref,$EREFID,$ORDERSREF) = @_;

	print "EREFID: $EREFID\n";

	my @FEES = ();
	my $head = $ORDERSREF->[0];

	my $FILE_VERSION = $ORDERSREF->[0]->{'v'};	## 1 or 5

	my $ERROR = undef;
	my $previous_orderid;
	my ($ordsumref) = $so->resolve_erefid($EREFID);
	print Dumper($ordsumref);
	if (defined $ordsumref) {
		$previous_orderid = $ordsumref->{'ORDERID'};
		}
	if (defined $previous_orderid) {
		$olm->pooshmsg("STOP|+DUPLICATE $EREFID / $previous_orderid");
		}

	#my $previous_orderid = undef;	
	#if ((defined $ordsumref) && ($params{'IGNORE_EREFID'})) {
	#	warn "Ignoring previous_orderid ($ordsumref->{'ORDERID'}) because we're about to IGNORE_EREFID\n";
	#	}
	#elsif (defined $ordsumref) {
	#	$previous_orderid = $ordsumref->{'ORDERID'};
	#	warn "It appears $EREFID is already created as $ordsumref->{'ORDERID'} (RECREATE=$params{'RECREATE'})";
	#	}
	#else {
	#	warn "erefid $EREFID appears to be a new order\n";
	#	}

	## these lines are helpful, they stop me from being an idiot.
	#next if ((defined $previous_orderid) && (not $params{'REDO'}) && (not defined $params{'RECREATE'}));
	#next if ((defined $previous_orderid) && ($params{'RECREATE'} ne $previous_orderid)); 

	my $USERNAME = $so->username();
	my $O2 = undef;
	my %cart2 = ();
	my @EVENTS = ();
	
	if ($olm->can_proceed()) {
		($O2) = CART2->new_memory($USERNAME);
		$O2->in_set('is/origin_marketplace',1);	 # prevents syncs

		tie %cart2, 'CART2', 'CART2'=>$O2;
	
		if ($so->dstcode() eq 'BUY') {
		   $cart2{'our/domain'} = 'buy.com';
			$cart2{'our/mkts'} = '002T4W'; # &ZOOVY::bitstr([18])
			}
		elsif ($so->dstcode() eq 'BST') {
			$cart2{'our/domain'} = 'bestbuy.com';
			$cart2{'our/mkts'} = '002T4W'; 	# &ZOOVY::bitstr([19])
			}
		else {
			## this line should never be reached.
			$cart2{'our/domain'} = 'error-bst-buy';
			}

		if ($FILE_VERSION == 1) {
			$cart2{'bill/phone'} = $head->{'Bill_To_Phone'};
			$cart2{'bill/email'} = $head->{'Email'};
			$cart2{'bill/firstname'} = $head->{'Bill_To_Fname'};
			$cart2{'bill/lastname'} = $head->{'Bill_To_Lname'};
			$cart2{'bill/company'} = $head->{'Bill_To_Company'};	

			# $cart2{'ship/fullname'} = $head->{'Ship_To_Name'};
			($cart2{'ship/firstname'}, $cart2{'ship/lastname'}) = split(/[\s]+/,$head->{'Ship_To_Name'},2);
			## there seems to be some confusion in the buy.com docs about the company header. we'll cover our bases.
			$cart2{'ship/company'} = $head->{'Ship_To_Company'};
			if ($cart2{'ship/company'} eq '') { $cart2{'ship/company'} = $head->{'Ship_Company_Name'}; }
			$cart2{'ship/address1'} = $head->{'Ship_To_Street1'};
			$cart2{'ship/address2'} = $head->{'Ship_To_Street2'};
			$cart2{'ship/city'} = $head->{'Ship_To_City'};
			$cart2{'ship/region'} = $head->{'Ship_To_State'};
			$cart2{'ship/postal'} = $head->{'Ship_To_Zip'};
			if ((length($cart2{'ship/postal'})>5) && ($head->{'Ship_To_Zip'} !~ /-/)) {	
				## stupid buy.com transmits zip+4 codes like this: 123456789
				$cart2{'ship/postal'} = substr($cart2{'ship/postal'},0,5).'-'.substr($cart2{'ship/postal'},5);
				}

			$cart2{'ship/countrycode'} = 'US';
			$cart2{'mkt/erefid'} = $EREFID;
			$cart2{'mkt/docid'} = $head->{'_FILENAME'};
			}
		elsif ($FILE_VERSION == 5) {
			$cart2{'bill/phone'} = $head->{'BillToPhone'};
			$cart2{'bill/email'} = $head->{'Email'};
			($cart2{'bill/firstname'}, $cart2{'bill/lastname'}) = split(/[\s]+/,$head->{'BillToName'},2);
			$cart2{'bill/company'} = $head->{'BillToCompany'};	

			# $cart2{'ship/fullname'} = $head->{'Ship_To_Name'};
			($cart2{'ship/firstname'}, $cart2{'ship/lastname'}) = split(/[\s]+/,$head->{'ShipToName'},2);
			$cart2{'ship/company'} = $head->{'ShipToCompany'};
			$cart2{'ship/address1'} = $head->{'ShipToStreet1'};
			$cart2{'ship/address2'} = $head->{'ShipToStreet2'};
			$cart2{'ship/city'} = $head->{'ShipToCity'};
			$cart2{'ship/region'} = $head->{'ShipToState'};
			$cart2{'ship/postal'} = $head->{'ShipToZipCode'};
			if ((length($cart2{'ship/postal'})>5) && ($head->{'ShipToZipCode'} !~ /-/)) {	
				## stupid buy.com transmits zip+4 codes like this: 123456789
				$cart2{'ship/postal'} = substr($cart2{'ship/postal'},0,5).'-'.substr($cart2{'ship/postal'},5);
				}

			$cart2{'ship/countrycode'} = 'US';
			$cart2{'mkt/erefid'} = $EREFID;
			$cart2{'mkt/docid'} = $head->{'_FILENAME'};
			}
		else {
			## this point should never be reached
			}
		}
	my $ship_total = 0;
	my $tax_total = 0;
	my $OrderTotal = 0;
	if ($olm->can_proceed()) {
		foreach my $line (@{$ORDERSREF}) {
			my $ilm = LISTING::MSGS->new($USERNAME);
			# print Dumper($line);

			## optionstr will be a sku/stid/whatever
			#my $optionstr = undef;
			#if ($line->{'ReferenceId'} =~ /:/) { $optionstr = $line->{'ReferenceId'}; }

			if ($FILE_VERSION == 1) {
				my ($PID) = &PRODUCT::stid_to_pid($line->{'ReferenceId'});
				my ($P) = PRODUCT->new($USERNAME,$PID); 

				if (defined $P) {
					my $suggestions = $P->suggest_variations('stid'=>$line->{'ReferenceId'});
					my $variations = STUFF2::variation_suggestions_to_selections($suggestions);

					my ($item) = $O2->stuff2()->cram(
						$P->pid(),
						$line->{'Quantity'},
						$variations, 
						'*LM'=>$ilm,
						'*P'=>$P,
						'force_qty'=>$line->{'Quantity'},
						'force_price'=>$line->{'Price'},
						'mkt'=>$so->dstcode(),
						'mktid'=>sprintf("%d-%d",$line->{'ListingID'},$line->{'Receipt_Item_ID'})
						);
					}
				else {
					$O2->stuff2()->basic_cram(
						$line->{'ReferenceId'},
						$line->{'Quantity'},
						$line->{'Price'},
						$line->{'ReferenceId'},
						'mkt'=>$so->dstcode(),
						'mktid'=>sprintf("%d-%d",$line->{'ListingID'},$line->{'Receipt_Item_ID'})
						);
					}
				$olm->merge($ilm);
				$olm->pooshmsg("INFO|+Crammed sku: ".$line->{'ReferenceId'});

				$ship_total += $line->{'Shipping_Cost'};
				$tax_total += $line->{'Tax_Cost'};
				$OrderTotal += ($line->{'Price'} * $line->{'Quantity'}) + $line->{'Shipping_Cost'} + $line->{'Tax_Cost'};
				}
			elsif ($FILE_VERSION == 5) {
				my ($PID) = &PRODUCT::stid_to_pid($line->{'ReferenceId'});
				my ($P) = PRODUCT->new($USERNAME,$PID); 

				if (defined $P) {
					my $suggestions = $P->suggest_variations('stid'=>$line->{'ReferenceId'});
					my $variations = STUFF2::variation_suggestions_to_selections($suggestions);

					my ($item) = $O2->stuff2()->cram(
						$P->pid(),
						$line->{'Qty'},
						$variations, 
						'*LM'=>$ilm,
						'*P'=>$P,
						'force_qty'=>$line->{'Qty'},
						'force_price'=>$line->{'Price'},
						'mkt'=>$so->dstcode(),
						'mktid'=>sprintf("%d-%d",$line->{'ListingID'},$line->{'OrderItemId'})
						);
					}
				else {
					$O2->stuff2()->basic_cram(
						$line->{'ReferenceId'},
						$line->{'Qty'},
						$line->{'Price'},
						$line->{'ReferenceId'},
						'mkt'=>$so->dstcode(),
						'mktid'=>sprintf("%d-%d",$line->{'ListingID'},$line->{'OrderItemId'})
						);
					}
				$olm->merge($ilm);
				$olm->pooshmsg("INFO|+Crammed sku: ".$line->{'ReferenceId'});

				$ship_total += $line->{'ShippingAmount'};
				$tax_total += ($line->{'ItemTaxAmount'} + $line->{'ShippingTaxAmount'});
				$OrderTotal += ($line->{'Price'} * $line->{'Qty'}) + $line->{'ShippingAmount'} + $line->{'ItemTaxAmount'} + $line->{'ShippingTaxAmount'};
				}
			else {
				# this point should never be reached
				}
			## format: 
			push @FEES, [ $line->{'ReferenceId'}, 'BUY', $line->{'Commission'}  ];
			}

		$cart2{'mkt/order_total'} = $OrderTotal;
		}


	## NOT PORTED TO STUFF2
	#if ($previous_orderid) {
	#	my ($o) = ORDER->new($USERNAME,$previous_orderid);
	#	if ($o->stuff()->digest() ne $s->digest()) {
	#		$o->{'stuff'} = $s;						
	#		$o->event("Reset stuff. original order digest:".$o->stuff()->digest());
	#		$o->save();
	#		}
	#	die("done with redid stuff");
	#	}

	## buy.com collects and remits ca sales tax for the merchant
	## is this the same for besbuy?
	if ($cart2{'ship/region'} eq 'CA') {
		$tax_total = 0;
		}

	if (not $olm->can_proceed()) {
		}
	elsif ($tax_total>0) {
		$O2->surchargeQ("add","tax",1,"Tax",0,2);
		}

	if (not $olm->can_proceed()) {
		}
	elsif ($FILE_VERSION == 1) {
		if ($head->{'ShippingMethodId'}==1) {
			$O2->set_mkt_shipping('Standard Shipping',$ship_total,'carrier'=>'SLOW');
			}
		elsif ($head->{'ShippingMethodId'}==2) {
			$O2->set_mkt_shipping('Expedited Shipping',$ship_total,'carrier'=>'FAST');
			}
		elsif ($head->{'ShippingMethodId'}==3) {
			$O2->set_mkt_shipping('2 Day Shipping',$ship_total,'carrier'=>'2DAY');
			}
		elsif ($head->{'ShippingMethodId'}==4) {
			$O2->set_mkt_shipping('1 Day Shipping',$ship_total,'carrier'=>'1DAY');
			}
		## buy.com offers same day shipping but we do not have a same day shipping method yet.
#		elsif ($head->{'ShippingMethodId'}==5) {
#			}
		else {
			ZOOVY::confess($USERNAME,$cart2{'our/domain'}." got something [$head->{'ShippingMethodId'}] other than 1,2,3 or 4 in ShippingMethodId\nbuyoidline=[$EREFID]\nLINE:\n".Dumper($ORDERSREF));
			}
		}
	elsif ($FILE_VERSION == 5) {
		if ($head->{'ShippingMethodId'}==1) {
			$O2->set_mkt_shipping('Standard Shipping',$ship_total,'carrier'=>'SLOW');
			}
		elsif ($head->{'ShippingMethodId'}==2) {
			$O2->set_mkt_shipping('Expedited Shipping',$ship_total,'carrier'=>'FAST');
			}
		else {
			#don't think I like this for it will do for testing purposes
			ZOOVY::confess($USERNAME,$cart2{'our/domain'}." got something [$head->{'ShippingMethodId'}] other than 1 or 2 in ShippingMethodId\nbuyoidline=[$EREFID]\nLINE:\n".Dumper($ORDERSREF));
			}
		}
	else {
		# this point should never be reached
		}

	### 
	
	if ($tax_total>0) {
		$O2->guess_taxrate_using_voodoo($tax_total,src=>'Buy.com',events=>\@EVENTS);
		}
	
	if ($params{'IGNORE_EREFID'}) {
		$olm->pooshmsg("ISE|+$params{'IGNORE_EREFID'} does not actually allow order creation");
		print Dumper($olm);
		die();
		}

	foreach my $fee (@FEES) {
		# '',$FEETYPE,$AMOUNT,$payrec->{'ts'},undef,$UUID
		$O2->set_fee(@{$fee});
		}
	
	#my ($balance_due) = $O2->in_get('sum/balance_due');
	#my @PAYMENTS = ();
	#push @PAYMENTS, [ 'BUY', $balance_due, { ps=>'020', txn=>$head->{'Receipt_ID'}, 'BO'=>$head->{'Receipt_ID'} } ];
	## $O2->paymentQ('add',
	#my ($orderid,$success,$o,$ERROR) = &CHECKOUT::finalize($O2,
	#	'@payments'=>\@PAYMENTS,
	#	orderid=>$previous_orderid,
	#	use_order_cartid=>sprintf("%s",$EREFID),
	#	email_suppress=>0xFF
	#	);
	#if ($ERROR ne '') {
	#	die("ERROR: $ERROR");
	#	}
	#if ($ERROR eq '') {
	#	#my ($payrec) = $o->add_payment('BUY',
	#	#	$o->get_attrib('balance_due'),
	#	#	'ps'=>'020',
	#	#	'txn'=>"$head->{'Receipt_ID'}",
	#	#	'acct'=>"|BO:$head->{'Receipt_ID'}",
	#	#	);
	#	$O2->order_save();

	if ($olm->can_proceed()) {
		my $ts = time();

		$O2->in_set('want/create_customer',0);
		$O2->in_set('is/email_suppress',1);

		my %params = ();
		$params{'*LM'} = $olm;

		$params{'skip_ocreate'} = 1;

		$O2->add_payment($DST,$O2->in_get('mkt/order_total'),'ps'=>'020','txn'=>$EREFID);
		($olm) = $O2->finalize_order(%params);

		foreach my $estr (@EVENTS) {
			# $lm->pooshmsg(sprintf("EVENT|ebayoid=%s|%s",$ordref->{'.OrderID'},$msg));
			$O2->add_history($estr,ts=>$ts,etype=>2,luser=>'*BUYCOM');
			}

		if ($O2->oid()) {
			$olm->pooshmsg(sprintf("SUCCESS|+ORDERID:%s",$O2->oid()));
			}
		else {
			$olm->pooshmsg("WARN|+Order creation was skipped due to previous errors");
			}
		}
	
	#my $pstmt = &DBINFO::insert($dbh,'SYNDICATION_ORDERS',{
	#	MID=>$so->mid(),
 	#	USERNAME=>$so->username(),
	#	DST=>$so->dstcode(),
	#	MKT_ORDERID=>$o->get_attrib('data.erefid'),
	#	ZOOVY_ORDERID=>$o->oid(),
	#	},debug=>1+2);
	##$dbh->do($pstmt);
	# print Dumper($CART);

	return($olm);
	}






##
##
##
##
sub trackingAck {
	my ($so,$ftp,$lm,%params) = @_;

	$lm->pooshmsg("INFO|+tracking ack started");

	my @files = $ftp->ls("/Fulfillment/Archive");
	print Dumper(\@files);

	my ($udbh) = &DBINFO::db_user_connect($so->username());
	my $MID = $so->mid();

	my %input = ();
	my %output = ();

	$lm->pooshmsg("INFO|+Found ".scalar(@files)." files to ack");
	foreach my $file (@files) {

		## don't process files we've already done!
		my $pstmt = "select count(*) from BUYCOM_FILES_PROCESSED where MID=$MID and FILENAME=".$udbh->quote($file);
		my ($done) = $udbh->selectrow_array($pstmt);
		next if ($done);

		my $txt = '';
		my $sh = IO::Scalar->new(\$txt);
		my $attempts = 10;
		my $success = 0;
		
		while (($attempts-->0) && (not $success)) {
			$ftp->ascii();
			$success = $ftp->get("/Fulfillment/Archive/$file",$sh);
			if (not $success) {
				$lm->pooshmsg("INFO|+get tracking failed[$attempts] file[$file]".$ftp->message);
				warn "get tracking failed[$attempts] file[$file] ", $ftp->message;
				sleep(3);
				}
			else {
				$lm->pooshmsg("INFO|+get tracking success[$attempts] file[$file]");
				warn "get tracking success[$attempts] file[$file]";
				}
			}

		if ($attempts==0) {
			$lm->pooshmsg("INFO|+buy.com gave up on file: $file");
			&ZOOVY::confess($so->username(),"buy.com gave up on file: $file",justkidding=>1);
			}

		if ($file =~ /^(.*?)\.resp$/) {
			$output{$1} = $txt;
			}
		elsif ($file =~ /^(.*?)\.txt$/) {
			$input{$1} = $txt;
			}
		else {
			$lm->pooshmsg("INFO|+Unknown fulfillment file: $file");
			die("Unknown fulfillment file: $file\n");
			}
		}

	# print Dumper(input=>\%input,output=>\%output);
	

	## we need to merge the two input/output files together.
	foreach my $file (keys %output) {
		print "FILE: $file\n";
		next if (not defined $input{$file});
		
		my @inlines = split(/[\n\r]+/,$input{$file});
		my @outlines = split(/[\n\r]+/,$output{$file});
		next if ((scalar(@inlines)<2) && (scalar(@outlines)<2));

		if (scalar(@inlines)!=scalar(@outlines)) {
			$lm->pooshmsg("INFO|+inlines and outlines do not match for Fulfillment file $file");
			ZOOVY::confess($so->username(),"inlines and outlines do not match for Fulfillment file $file",justkidding=>1);
			}
		my @combined = ();
		my $i = scalar(@outlines);
		while (--$i>=0) {
			## 'File' header/lines is prepended, followed by input header/lines, then output header/lines
			$combined[$i] = (($i==0)?'File':$file)."\t".$inlines[$i]."\t".$outlines[$i];
			}
		print Dumper(\@combined);
		open F, ">/tmp/combined.txt";
		print F join("\n",@combined);
		close F;

		my %vars = ( 'MID'=>$MID, '*CREATED'=>'now()' );
		$vars{'FILENAME'} = "$file.resp";
		my $pstmt = &DBINFO::insert($udbh,'BUYCOM_FILES_PROCESSED',\%vars,sql=>1);
		$udbh->do($pstmt);
		$vars{'FILENAME'} = "$file.txt";
		my $pstmt = &DBINFO::insert($udbh,'BUYCOM_FILES_PROCESSED',\%vars,sql=>1);
		$udbh->do($pstmt);
		}
		
	##
	## we really should go and update the orders that have shipped to let them know we've notified buy.com
	##
	## so basically this module is incomplete!
	
	&DBINFO::db_user_close();
	$lm->pooshmsg("INFO|Tracking Ack finished");

	return();
	}



##
##
##
sub uploadTracking {
	my ($so, $ftp, $lm, %params) = @_;

	##
	## NOTE: at some point, we should *really* move this over to use events, but that is not tonight.
	##	and frankly, this should be done for multiple marketplaces at the same time including amazon..
	##
	my $startts = time();
	my $USERNAME = $so->username();

	print "SENDING TRACKING FOR $USERNAME!\n";
	$lm->pooshmsg("INFO|+uploadTracking for $USERNAME");
	my @LINES = ();

	require ORDER::BATCH;

	## changed the query to look for last modified_gmt (TS) and also SHIPPED_GMT > 1
	## - this should resolve the issue we were having with merchants adding tracking to orders, syncing many hours later, and code missing order
	#($list) = ORDER::BATCH::report($USERNAME,'MKT_BIT'=>18,SHIPPED_GMT=>$so->get('TRACKING_LASTRUN_GMT'));
	my $MKT_BIT = undef;
	if ($so->dstcode() eq 'BUY') {
		$MKT_BIT = 18;
		}
	elsif ($so->dstcode() eq 'BST') {
		$MKT_BIT = 19;
		}
	else {
		$lm->pooshmsg(sprintf("ISE|+Internal error on uploadTracking - unknown dstcode '%s'",$so->dstcode()));
		}
	## ($list) = ORDER::BATCH::report($USERNAME,MKT_BIT=>$MKT_BIT,'TS'=>$so->get('TRACKING_LASTRUN_GMT'),'PAID_GMT'=>time()-(60*86400),'SHIPPED_GMT'=>1);

	## NEED TO WRITE CODE HERE

	my @ORDERLIST = ();
	my ($redis) = &ZOOVY::getRedis($USERNAME,1);
	my $REDISQUEUE = uc(sprintf("EVENTS.ORDER.SHIP.%s.%s",$so->dst(),$so->username()));
	my ($length) = $redis->llen($REDISQUEUE);
	if ($length > 0) {
		@ORDERLIST = $redis->lrange($REDISQUEUE,0,250);
		}

	if ($params{'DEBUGORDER'}) {
		print "TRACKING_LASTRUN_GMT: ".&ZTOOLKIT::pretty_date($so->get('TRACKING_LASTRUN_GMT'),1)."\n";
		my $found = 0;
		foreach my $set ( @ORDERLIST ) {
			if ($params{'DEBUGORDER'} eq $set->{'ORDERID'}) { $found++; }
			}
		if (not $found) {
			die("ORDER: $params{'DEBUGORDER'} not in current list of orders to send.");
			}
		}

	my $order_cnt = scalar(@ORDERLIST);
	$lm->pooshmsg("INFO|+Found ".$order_cnt." orders for tracking");
	foreach my $ORDERID (@ORDERLIST) {
		my ($O2) = CART2->new_from_oid($USERNAME,$ORDERID);
		my $EREFID =  $O2->in_get('mkt/erefid');	

		my @TRACKING = ();
		foreach my $trk (@{$O2->tracking()}) {
			push @TRACKING, $trk;
			}
	
		my @ITEMS = ();
		foreach my $item (@{$O2->stuff2()->items()}) {
			my ($ListingID,$Receipt_Item_ID) = split(/-/,$item->{'mktid'},2);
			if ($ListingID eq '') {
				$lm->pooshmsg("WARN|+ORDER:$ORDERID STID '$item->{'stid'}' has no ListingID associated");
				}
			elsif ($Receipt_Item_ID eq '') { 
				$lm->pooshmsg("WARN|+ORDER:$ORDERID STID '$item->{'stid'}' has no ReceiptID associated");
				}
			else {
				push @ITEMS, [ $ListingID, $Receipt_Item_ID, $item->{'qty'} ];
				}
			}

		## SANITY: at this point @TRACKING is an array of tracking #'s
		##			@ITEMS is an array of items in the order.
		if ($EREFID eq '') {
			warn "order $ORDERID erefid (buy.com receipt-id) is not set\n";
			$lm->pooshmsg("INFO|+order $ORDERID erefid (buy.com receipt-id) is not set");
			}
		elsif ($O2->in_get('flow/shipped_ts')==0) {
			warn "order $ORDERID is not flagged as shipped.\n";
			$lm->pooshmsg("INFO|+order $ORDERID is not flagged as shipped.");
			}
		elsif (scalar(@ITEMS)==0) {
			warn "No items in order.\n";
			$lm->pooshmsg("INFO|+No items in order.");
			}
		elsif (scalar(@TRACKING)==0) {
			warn "No tracking in order.\n";
			$lm->pooshmsg("INFO|+No tracking in order.");
			}
		else {
			my $i = 0;
			foreach my $iref (@ITEMS) {
				my @columns = ();
				push @columns, $EREFID;
				push @columns, $iref->[1];
				push @columns, $iref->[2];
				
				## we don't know which tracking goes to which item so randomly assign
				my $trk = $TRACKING[ (++$i % scalar(@TRACKING))-1 ];
				my $ccode = $trk->{'carrier'};
				## carriers are represented by single digit for tracking on buy.com (eg UPS is 1).
				##		- these numbers are mapped to zoovy carrier codes in ZSHIP::shipinfo.  
				my $tccode = &ZSHIP::shipinfo($ccode, 'buycomtc');
				if ($tccode ne '') {	push @columns, $tccode;	}

#				if ($trk->{'carrier'} eq 'UPS') { push @columns, 1; }
#				elsif ($trk->{'carrier'} eq 'FEDEX') { push @columns, 2; }
#				elsif ($trk->{'carrier'} eq 'FEDX') { push @columns, 2; }
#				elsif ($trk->{'carrier'} eq 'FDX') { push @columns, 2; }
#				elsif ($trk->{'carrier'} eq 'USPS') { push @columns, 3; }
#				elsif ($trk->{'carrier'} eq 'DHL') { push @columns, 4; }
				else { push @columns, 5; } # other
				push @columns, $trk->{'track'};
				if ($trk->{'created'}==0) { $trk->{'created'} = time(); }
				push @columns, POSIX::strftime("%m/%d/%Y",localtime($trk->{'created'}));
	
				$csv->combine(@columns);
				push @LINES, $csv->string();
				}
			$lm->pooshmsg("INFO|+added tracking for $ORDERID");
			}
		}
	print Dumper(\@LINES,$lm);
	$lm->pooshmsg("INFO|+Found ".scalar(@LINES)." valid orders to upload to Buy.com");

	my $SUCCESS = 0;
	my ($txt,$FILENAME) = ();
	if (scalar(@LINES)>0) {
		## prepend a header.
		my @header = (
			'receipt-id',
			'receipt-item-id',
			'quantity',
			'tracking-type',
			'tracking-number',
			'ship-date',
			);
		$csv->combine(@header);
		unshift @LINES, $csv->string();

		$txt = join("\n",@LINES)."\n";
		my $SH = new IO::Scalar \$txt;
		## BUY-fulfillment
		## BST-fulfillment
		$FILENAME = POSIX::strftime( $so->dstcode()."-fulfillment-%Y%m%d-%H%M%S.txt",localtime());
		print "FILENAME: $FILENAME\n";
		$lm->pooshmsg("INFO|+uploading to $FILENAME");

		# $ftp->ascii();
		$ftp->binary();
		my ($rc) = $ftp->put($SH,"/Fulfillment/$FILENAME");
		if (defined $rc) { $SUCCESS++; }
		if ($ftp->size("/Fulfillment/$FILENAME")==0) {
			$SUCCESS = -1;
			$lm->pooshmsg(sprintf("INFO|+%s receive zero byte tracking file",$so->dstcode()));
			&ZOOVY::confess($USERNAME,
				$so->dstcode()." received a zero byte tracking file (setting SUCCESS to -1)\n\n".$txt,
				justkidding=>1
				);
			}

		## store the file to private files.
		my ($lf) = LUSER::FILES->new($USERNAME, 'app'=>'BUYCOM');
		$lf->add(
			buf=>$txt,
			type=>$so->dstcode(),
			title=>"Tracking Feed File for ".$so->dstcode(),
			file=>sprintf("%s-tracking-%s.csv",$so->dstcode(),ZTOOLKIT::pretty_date(time(),3)),
			meta=>{'DSTCODE'=>$so->dstcode(),'TYPE'=>$params{'verb'}}
			);
		}


	if (scalar(@LINES)==0) {
		## nothing to see here.
		}
	elsif ($SUCCESS<0) {
		## a "handled" error has occurred. 
		## -1 means buy.com recorded zero bytes
		}
	elsif ($SUCCESS>0) {
		## hurrah we've uploaded all the @LINES to buy.com!
		foreach my $oid (@ORDERLIST) {
			$redis->lrem($REDISQUEUE,0,$oid);
			}
		$so->set('TRACKING_LASTRUN_GMT',$startts);
		$so->save();
		}
	else {
		$lm->pooshmsg("Buy.com got ftp error while sending tracking (will retry)");
		&ZOOVY::confess(
			$USERNAME,
			"Buy.com got ftp error while sending tracking (will retry)\nFTP MESSAGE:".$ftp->message."\nFILENAME:$FILENAME\ntxt:$txt\n",
			justkidding=>1
			);
		}
	

	}





