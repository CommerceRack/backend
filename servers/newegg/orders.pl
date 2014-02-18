#!/usr/bin/perl

use URI::Escape::XS;
use strict;

##
## orders.pl [EGG]
##		./orders.pl 'verb'=orders user=patti prt=0
##	- GET orders from NEWEGG via ftp 
##	- upload tracking info back to NEWEGG 
##
##
use Date::Parse;
use XML::Simple;
use XML::Writer;
use Data::Dumper;

use lib "/httpd/modules";
use SYNDICATION;
use CART2;
use LUSER::FILES;
use POSIX qw(strftime);
use LWP::UserAgent;
use HTTP::Headers;
use HTTP::Request;
use Net::FTP;
use IO::String;
use ZCSV;

## NEWEGG specific info
my $MKT_BITSTR = 43;	
my $syn_name = 'NEWEGG';
my $DST = 'EGG';
my $PS = '';
my $sdomain = 'newegg.com';
my @USERS = (); 


##
## parameters: 
##		user=toynk prt=0
##		type=tracking|orders
##			DEBUGORDER=####-##-#####
##		REDO=filename 
##			RECREATE=2009-01-1234 (will recreate the stuff in the order)
my %params = ();
foreach my $arg (@ARGV) {
	if ($arg !~ /=/) { die("Bad argument - [$arg] plz check syntax in file."); }
	my ($k,$v) = split(/=/,$arg);
	$params{$k} = $v;
	}


if ((not defined $params{'verb'}) && (defined $params{'type'})) { $params{'verb'} = $params{'type'}; }

## validate type
if ($params{'verb'} eq 'tracking') {
	print STDERR "\n\n######\n".`date`."GET TRACKING\n";
	}
elsif ($params{'verb'} eq 'orders') {
	print STDERR "\n\n######\n".`date`."GET ORDERS\n";
	}
elsif ($params{'verb'} eq 'jobs') {
	print STDERR "\n\n######\n".`date`."GET JOBS\n";
	}
else {
	die("Try a valid type (orders, tracking, jobs, credit)\n");
	}


## USER is defined, only run for this USER
if ($params{'user'} ne '')  {
#	if ((not defined $params{'profile'}) && (defined $params{'prt'})) {
		## if we get a prt, but not a profile, then lookup the profile
#		$params{'profile'} = &ZOOVY::prt_to_profile($params{'user'},$params{'prt'});
#		}
	my $udbh = &DBINFO::db_user_connect($params{'user'});
	my $pstmt = "select DOMAIN,ID from SYNDICATION where USERNAME=".$udbh->quote($params{'user'}).
					" and DSTCODE='".$DST."'";
	print STDERR $pstmt."\n";
	
	my ($DOMAIN,$ID) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();
	if ($ID>0) {
		print STDERR "FOUND ID: $ID\n";
#		push @USERS, [ $params{'user'}, $params{'profile'}, $ID ];
		push @USERS, [ $params{'user'}, $DOMAIN, $ID ];
		}
	}

## run for specific CLUSTER
elsif ($params{'user'} eq '' && $params{'cluster'} ne  '') {
	my $udbh = &DBINFO::db_user_connect("\@$params{'cluster'}");
	my $pstmt = "select USERNAME,DOMAIN,ID,ERRCOUNT from SYNDICATION where DSTCODE='".$DST."' and IS_ACTIVE>0 ";
	if ($params{'verb'} eq 'tracking') {
		$pstmt .= " order by TRACKING_NEXTQUEUE_GMT";
		}
	print STDERR $pstmt."\n";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($USERNAME,$DOMAIN,$ID,$ERRCOUNT) = $sth->fetchrow() ) {
		if ($ERRCOUNT>10) {
			print STDERR "USER:$USERNAME DOMAIN:$DOMAIN ID:$ID was skipped due to ERRCOUNT=$ERRCOUNT\n";
			}
		else {
			push @USERS, [ $USERNAME, $DOMAIN, $ID ];
			print STDERR "USERNAME: $USERNAME $DOMAIN\n";
			}
		}
	$sth->finish();
	&DBINFO::db_user_close();
	}

## die, we need user or cluster to run
else {
	die("Cluster or specific user is required!");
	}


## run thru each USER 
foreach my $set (@USERS) {
	my ($USERNAME,$DOMAIN,$ID) = @{$set};
	## create LOGFILE for each USER/PROFILE
	my ($lm) = LISTING::MSGS->new($USERNAME,'logfile'=>"~/".lc($syn_name)."-%YYYYMM%.log");
	my ($so) = SYNDICATION->new($USERNAME,$DST,'DOMAIN'=>$DOMAIN,'ID'=>$ID);

 	my $ERROR = '';

	## deactivate, too many errors
	if (not &DBINFO::task_lock($USERNAME,"newegg-".$params{'verb'},(($params{'unlock'})?"PICKLOCK":"LOCK"))) {
		$lm->pooshmsg("STOP|+Could not obtain opportunistic lock");
		}
	elsif ($so->get('ERRCOUNT')>1000) {
		ZOOVY::confess($so->username(),"Deactivated $syn_name syndication for $USERNAME due to >1000 errors\n".Dumper($so),justkidding=>1);
		$so->deactivate();
		}

	## get orders 
	elsif ($params{'verb'} eq 'orders') { 
		$lm->pooshmsg("INFO|+Performing feed $params{'verb'}");

		## DOWNLOAD Orders
		($ERROR) = &downloadOrders($so, $lm, %params);

		## ACK Orders
		if ($ERROR eq '') {
			#&ackOrders($so, $lm, $ack_ordersref);
			}
		else {
			$lm->pooshmsg("ERROR|+$ERROR");
			}
		$lm->pooshmsg("INFO|+Finished feed $params{'verb'}");
		}

	## send tracking
	elsif ($params{'verb'} eq 'tracking') { 
		$lm->pooshmsg("INFO|+Performing feed $params{'verb'}");
		$so->set('TRACKING_NEXTQUEUE_GMT',time());
		$so->save();

		&uploadTracking($so, $lm, %params);
		
		$so->set('TRACKING_LASTRUN_GMT',time());
		$so->set('TRACKING_NEXTQUEUE_GMT',(time()+(3600)));
		$so->save();

		$lm->pooshmsg("INFO|+Finished feed $params{'verb'}");
		}
	elsif ($params{'verb'} eq 'jobs') {
		&findJobs($so, %params);
		}

	## unknown type
	else {
		$lm->pooshmsg("WARN|+Unknown feed type:$params{'verb'}");
		}

	&DBINFO::task_lock($USERNAME,"newegg-".$params{'verb'},"UNLOCK");
	}

exit 1; 	## success


sub findJobs {
	my ($so, %params) = @_;
	
	my ($zdbh) = &DBINFO::db_zoovy_connect();
	my $pstmt = "select * from BATCH_JOBS where MID=".$so->mid()." and TITLE like 'Order%' and CREATED_GMT>unix_timestamp(date_sub(now(),interval 14 day))";
	my $sth = $zdbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) {
		print "BATCH: $hashref->{'ID'} ".&ZTOOLKIT::pretty_date($hashref->{'CREATED_GMT'})." TITLE: $hashref->{'TITLE'} STATUS:$hashref->{'STATUS'} $hashref->{'STATUS_MSG'}\n";
		}
	$sth->finish();
	&DBINFO::db_zoovy_close();
	
	}


##
## - find all orders with new tracking info
##	- create XML 
##	
##	valid params
##		=> DEBUGORDER
##
sub uploadTracking {
	my ($so, $lm, %params) = @_;

	my $ERROR = '';
	my $USERNAME = $so->username();
	my $output = '';
	use Text::CSV_XS;
	my $csv = Text::CSV_XS->new({sep_char=>','}); 	

	## get 'Ship From' information (required by NewEgg)
#	my $merchantref = ZOOVY::fetchmerchantns_ref($USERNAME,$so->profile());

	## return all orders that have been shipped since tracking was last sent
	require ORDER::BATCH;
#	#my ($list) = ORDER::BATCH::report($USERNAME,MKT_BIT=>$MKT_BITSTR,SHIPPED_GMT=>$so->get('TRACKING_LASTRUN_GMT'),PAID_GMT=>time()-(60*86400));
#	## changed the query to look for last modified_gmt (TS) and also SHIPPED_GMT > 1
#	## - this should resolve the issue we were having with merchants adding tracking to orders, syncing many hours later, and code missing order
#	my ($list) = ORDER::BATCH::report($USERNAME,MKT_BIT=>$MKT_BITSTR,TS=>$so->get('TRACKING_LASTRUN_GMT'),PAID_GMT=>time()-(60*86400),SHIPPED_GMT=>1);
#	my $list_cnt = scalar(@{$list});
#   $lm->pooshmsg("INFO-TRACK|+getting orders for SHIPPED_GMT >= ".ZTOOLKIT::pretty_date($so->get('TRACKING_LASTRUN_GMT'),1));
#	#$lm->pooshmsg("INFO-TRACK|+select MODIFIED_GMT,ORDERID from ORDERS_?????  where MID=????? and MODIFIED_GMT>=".$so->get('TRACKING_LASTRUN_GMT').
#	#					" and PAID_GMT>=".(time()-(60*86400))." and SHIPPED_GMT>='1' and  ((conv(substring(MKT_BITSTR,1*6+1,6),36,10)&1024)=1024)");
#	$lm->pooshmsg("INFO-TRACK|+$list_cnt edited orders found");

	my $trackingtry = $so->get_tracking();
	
	#if ($params{'DEBUGORDERl'}) {
	#	my $found = 0;
	#	foreach my $set ( @{$list} ) {
	#		if ($params{'DEBUGORDER'} eq $set->{'ORDERID'}) { $found++; }
	#		}
	#	if (not $found) {
	#		die("ORDER: $params{'DEBUGORDER'} not in current list of orders to send.");
	#		}
	#	}

	my @lines = ();
	print "FOUND ORDERS: ".Dumper($trackingtry)."\n";

	## feeds may contain multiple orders
	my @trackingdone = ();
	foreach my $trackset (@{$trackingtry}) {
		my ($DBID, $ORDERID, $CARRIER, $TRACKING) = @{$trackset};
		# my ($o,$err) = ORDER->new($USERNAME,$ORDERID,'turbo'=>1);
		my ($O2) = CART2->new_from_oid($USERNAME,$ORDERID);
		if (not defined $O2) {
			$lm->pooshmsg("ERROR|+Order: $ORDERID could not be loaded from db.");
			&ZOOVY::confess($USERNAME,"Order: $ORDERID could not be loaded from db.",justkidding=>1);
			}
		next if (not defined $O2);
		
		my $erefid = $O2->in_get('mkt/erefid');	
		if ($erefid eq '') { $erefid = $O2->in_get('want/erefid'); }

		my $PO_DATE = ($O2->in_get('mkt/newegg_po_date') eq '')?$O2->in_get('our/order_ts'):strftime("%m/%d/%Y",localtime($O2->in_get('mkt/newegg_po_date')));		
		my $SHIP_DATE = strftime("%Y-%m-%d",localtime($O2->in_get('flow/shipped_ts')));

		### CARRIER and TRACKING NUMBER
		## we dont currently store a tracking number per item, 
		## 	so just grab the first number and use for all items
		my $tracking_number = $TRACKING;
		my $carrier = $CARRIER;
		#foreach my $trk (@{$o->tracking()}) {
		#	next if ($trk->{'voided'}>0);	# skip voided #'s
		#	$tracking_number = $trk->{'track'};
		#	$carrier = $trk->{'carrier'};
		#	last;
		#	}

		if ($erefid eq '') {
			$lm->pooshmsg("WARN|+$erefid erefid ($sdomain receipt-id) is not set for order:$ORDERID");
			}
		elsif ($O2->in_get('flow/shipped_ts')==0) {
			$lm->pooshmsg("WARN|+".$O2->id()." is not flagged as shipped.");
			}
		elsif (scalar(@{$O2->tracking})==0) {
			$lm->pooshmsg("WARN|+".$O2->id()." no tracking in order.");
			}
		else {
			## add a line for each item in the order
			foreach my $item (@{$O2->stuff2()->items()}) {
				## skip assemly items (only send master)
				my $sku = $item->{'sku'};
				if ($sku =~ /@/) {
					## skip it
					}
				else {
					$lm->pooshmsg("Add order: ".$O2->id()." $carrier $tracking_number");
					my @item_line = ();
					push @item_line, $erefid; 										## Order Number
					push @item_line, $PO_DATE; 									## Order Date & Time
					push @item_line, $O2->in_get('ship/address1'); 		## Ship To Address Line 1
					push @item_line, $O2->in_get('ship/address2'); 		## Ship To Address Line 2
					push @item_line, $O2->in_get('ship/city'); 			## Ship To City
					push @item_line, $O2->in_get('ship/region'); 			## Ship To State
					push @item_line, $O2->in_get('ship/postal'); 			## Ship To ZipCode
					push @item_line, 'USA'; 										## Ship To Country
					push @item_line, $O2->in_get('ship/firstname'); 	## Ship To First Name
					push @item_line, $O2->in_get('ship/lastname'); 		## Ship To Last Name
					push @item_line, $O2->in_get('ship/company'); 		## Ship To Company
					push @item_line, $O2->in_get('ship/phone'); 			## Ship To Phone Number
					push @item_line, $O2->in_get('newegg:shp_carrier');## Order Shipping Method
					push @item_line, $sku;											## Item Seller Part #
					push @item_line, '';												## Item Newegg #
					push @item_line, '';												## Item Unit Price
					push @item_line, '';												## Item Unit Shipping Charge
					push @item_line, '';												## Order Shipping Total
					push @item_line, '';												## Order Total
					push @item_line, $item->{'qty'};							## Quantity Ordered
					push @item_line, $item->{'qty'};							## Quantity Shipped
					push @item_line, $SHIP_DATE;									## Ship Date
					push @item_line, $carrier;										## Actual Shipping Carrier
					push @item_line, $O2->in_get('sum/shp_method');			## Actual Shipping Method
					push @item_line, $tracking_number;							## Tracking Number
#					push @item_line, $merchantref->{'zoovy:address1'};		## Ship From Address
#					push @item_line, $merchantref->{'zoovy:city'};			## Ship From City
#					push @item_line, $merchantref->{'zoovy:state'};			## Ship From State
#					push @item_line, $merchantref->{'zoovy:zip'};			## Ship From Zipcode
					push @item_line, '';			## Ship From Address
					push @item_line, '';			## Ship From City
					push @item_line, '';			## Ship From State
					push @item_line, '';			## Ship From Zipcode
					push @item_line, '';												## Ship From Name

					my $status = $csv->combine(@item_line);
					my $out .= $csv->string();
					push @lines, $out;
					push @trackingdone, $trackset;
					}
				}
			}
		}

	## create CSV file with header and all the lines
	if ($ERROR eq '' && scalar(@lines) > 0) {
		my @header = ('Order Number','Order Date & Time','Ship To Address Line 1','Ship To Address Line 2',
						  'Ship To City','Ship To State','Ship To Zipcode','Ship To Country','Ship To First Name',
						  'Ship To Last Name','Ship To Company','Ship To Phone Number','Order Shipping Method',
						  'Item Seller Part #','Item Newegg #','Item Unit Price','Item Unit Shipping Charge',
						  'Order Shipping Total','Order Total','Quantity Ordered','Quantity Shipped','ShipDate',
						  'Actual Shipping Carrier','Actual Shipping Method','Tracking Number','Ship From Address',
						  'Ship From City','Ship From State','Ship From Zipcode','Ship From Name');
		my ($output) = &ZCSV::assembleCSVFile(\@header,\@lines,{});

		## write contents to tmp file
		#my $file = sprintf("$DST-tracking-%s-%s-%d",$USERNAME,$so->profile(),time());
		my $DATE = strftime("%Y%m%d%H%M%S",localtime(time()));
		my $file = $syn_name."Track".$DATE.".txt";
		open TMP, "> /tmp/$file";
		print TMP $output;
		close TMP;

		## write to private file	
		#my $FILETYPE = 'NEWEGG';
		my ($lf) = LUSER::FILES->new($USERNAME,'app'=>'NEWEGG');
		$lf->add(
			buf=>$output,
			type=>$DST,
			title=>$file,
			meta=>{'DSTCODE'=>$DST,'TYPE'=>$params{'type'}},
			);
		$lm->pooshmsg("INFO|+tracking xml written to private file [$file]");

		#my ($fileguid) = $lf->add(
		#	file=>"$file",
		#	meta=>{type=>"TRACKING"},
		#	title=>$file,
		#	unlink=>1,
		#	overwite=>1,
		#	guid=>substr($file,0,32),
		#	type=>$FILETYPE,
		#	expires_gmt=>time()+(86400*30),
		#	);

		### SANITY: CSV output is defined, time to ftp
		## CREDENTIALS	
		my $user = $so->get('.ftp_user');
		my $pass = $so->get('.ftp_pass');
		use POSIX qw(strftime);
		my $date = strftime("%Y%m%d_%H%M%S",localtime(time()));

		my $newegg_filename = "OrderList_".$date.".csv";
		my $url = sprintf("ftp://%s:%s\@ftp03.newegg.com/",
				URI::Escape::XS::uri_escape($user),
				URI::Escape::XS::uri_escape($pass),
			);

		print $url."\n";
		print qq~'in'=>"/tmp/$file",'out'=>$newegg_filename\n~;	
		my ($tlm) = $so->transfer_ftp($url,[{'in'=>"/tmp/$file",'out'=>"Inbound/Shipping/$newegg_filename"}]);
		# $lm->merge($tlm,'%mapstatus'=>{'SUCCESS'=>'TRANSFER-SUCCESS'});
		$lm->merge($tlm);
		if ($tlm->has_win()) {
			$lm->pooshmsg("SUCCESS|+Tracking file uploaded.");
			$so->ack_tracking(\@trackingdone);
			}
		else {
			#$lm->pooshmsg("ERROR|+Tracking error occured: $ERROR");
			$so->inc_err();
			&ZOOVY::confess(
				$USERNAME,
				"NewEgg got ftp error while sending tracking\n".Dumper($lm),
				justkidding=>1
				);
			$lm->pooshmsg("ERROR|+Tracking non-success occured.");
			}
		}		
	}


##
## - download the most recent orders
##	-- all NEW orders from yesterday to today
##	- create orderref from XML
##	- assign values to CART
##	- use CART to create order
##
sub downloadOrders {
	my ($so, $lm, %params) = @_;

	my $USERNAME = $so->username();
	my $ORDERTS = 0;
	my @ORDERSXML = ();
	my $poref = ();
	my $ERROR = '';
	my @archive_files = ();

	## create order if no $ERROR
	if ($ERROR eq '') {
		## recreate order from existing file: REDO
#		if ($params{'REDO'} ne '') {
#			$lm->pooshmsg("INFO-REDO|+create orders for file: ".$params{'REDO'});
#			## redo an import (perhaps there was an issue?)
#			open F, "<$params{'REDO'}";
#			$/ = undef; my ($str) = <F>; $/ = "\n";
#			close F;
#			push @ORDERSXML, [ $params{'REDO'}, $str ];
#			}
#		## use csv returned via ftp
#		else {


		## values used to get order data
		## file is created every hour: OrderList_YYYYMMDD_HHMMSS.csv
		## somehow figure out which files havent been processed yet...
		my $dir = "/Outbound/OrderList";
		my $ftp = undef; 
		$ftp = Net::FTP->new($so->get('.ftp_server'), Port=>21, Debug => 0);
		if (not defined $ftp) { $ERROR = "FTP Error - Could not connect to ".$so->get('.ftp_server'); }

		if (not $ERROR) {
		## login into ftp server
			my $rc = $ftp->login($so->get('.ftp_user'),$so->get('.ftp_pass'));
			if ($rc != 1) { $ERROR = "FTP Error - Could not login"; }
			}

		if (not $ERROR) {
			## make OrderArchive directory
			## this directory does not exist by default...
			## would it be better to just rename files in the same dir when they need to be archived?
			$ftp->mkdir("/Outbound/OrderArchive");
			$lm->pooshmsg("INFO|+Created OrderArchive directory");
			}

		my $FILE_HEADER = '';

		## output will contain data from all files modified since the last time this import ran
		my $output = '';
		if ($ERROR) {
			$lm->pooshmsg("INFO|+$ERROR");
			}
		elsif ($params{'REDODIR'}) {
			if (-d $params{'REDODIR'}) {
				## download all the files into a directory ex. 'toynk'
				require File::Slurp;
				opendir my $D, $params{'REDODIR'};
				while ( my $file = readdir($D)) {
					next if (substr($file,0,1) eq '.');
					my @lines = File::Slurp::read_file( sprintf("%s/%s",$params{'REDODIR'},$file) ) ;
					shift @lines;	# strip the header;
					$output .= join("\n",@lines);
					}
				closedir $D;
				print "OUTPUT: $output\n";
				}
			else {
				die("REDODIR pass in dir, or add file support");
				}
			}
		else {
			foreach my $file ($ftp->ls($dir)) {
				## only check CSV files
				if ($file =~ /(Outbound)\/OrderList\/(OrderList.*csv)/i) {
					$lm->pooshmsg("INFO|+Found file: $file");
					## when thru with the file, archive it to 
					## /Outbound/OrderArchive/OrderList_20110918_200225.csv
					my $archivefile = "/".$1."/OrderArchive/".$2;

					## bummer, this function isnt supported on their new ftp server - changed - 2011-09-20
					#my $modified = $ftp->mdtm($dir."/".$file);
					## example: OrderList_20110918_200225.csv
					$file =~ /OrderList_(\d\d\d\d)(\d\d)(\d\d)_(\d\d)(\d\d)(\d\d)\.csv/i;
					my ($date) = ("$1-$2-$3 $4:$5:$6 MST");
					my $modified = ZTOOLKIT::gmtime_to_unixtime($date);
					
					if ($modified > $so->get('ORDERS_LASTRUN_GMT')) {
						$lm->pooshmsg("INFO|+Found file to process: $file date: $date modified: $modified last_updated: ".$so->get('ORDERS_LASTRUN_GMT'));
						## download the file into $ios
						my ($ios) = IO::String->new();
						## this also changed with EGG server change
						#$ftp->get($dir."/".$file,$ios) or $ERROR = "get failed: ".$ftp->message."\n";
						$ftp->get($file,$ios) or $ERROR = "get failed: ".$ftp->message;
						my $str = ${$ios->string_ref()};
						
						## remove header
						my @lines = ();
						@lines = split(/\n/, $str);
						my $THIS_HEADER = shift @lines;
						$THIS_HEADER = &ZTOOLKIT::stripUnicode($THIS_HEADER);	## remove the leading utf8 character (thanks #$%^& newegg)
						if ($THIS_HEADER ne 'Order Number,Order Date & Time,Sales Channel,Fulfillment Option,Ship To Address Line 1,Ship To Address Line 2,Ship To City,Ship To State,Ship To ZipCode,Ship To Country,Ship To First Name,Ship To LastName,Ship To Company,Ship To Phone Number,Order Customer Email,Order Shipping Method,Item Seller Part #,Item Newegg #,Item Unit Price,Extend Unit Price,Item Unit Shipping Charge,Extend Shipping Charge,Order Shipping Total,Order Total,Quantity Ordered,Quantity Shipped,ShipDate,Actual Shipping Carrier,Actual Shipping Method,Tracking Number,Ship From Address,Ship From City,Ship From State,Ship From Zipcode,Ship From Name') {
							$lm->pooshmsg("ERROR|+Non-supported header format");
							}
			
						## NOTE: we really should do a header checksum here!
						
						$lm->pooshmsg("INFO|+Preparing main import file from newegg file: $file");
						$lm->pooshmsg("INFO|+Found ".scalar(@lines)." order item lines to import");
						
						## append file contents onto output
						$output .= join("\n",@lines)."\n";
						#open F, ">/tmp/$file"; print F $str; close F;
						#print STDERR "Created File: /tmp/$file\n";

						## we will be setting the ORDER_LASTRUN_GMT to the most recent order modified time
						if ($modified > $ORDERTS) {
							$ORDERTS = $modified;
							}
						## archive file after order import file has been successfully created
						## ex: /Outbound/OrderList/OrderList_20111031_070017.csv
						if ($ERROR eq '') {
							push @archive_files, {'file'=>$file,'archivefile'=>$archivefile};
							}
						}
					else {
						## old file that has already been processed
						$lm->pooshmsg("INFO|+Move already processed file: $file to $archivefile");
						$ftp->rename($file,$archivefile) or $ERROR = "rename failed: ".$ftp->message;
						}
					}
				else {
					$lm->pooshmsg("WARN|+non-CSV File encountered: $file (ignored)");
					}
				}	
			}

		## SANITY: done going thru order files, now have output that contains all data
			
		## add appropriate header
		## 	blanks are used where we don't have a Zoovy equivalent to data
		##
		if ($ERROR ne '') {
			}
		elsif ($output eq '') {
			$ERROR = "no output\n";
			}
		else {

			# Order Number,Order Date & Time,Ship To Address Line 1,Ship To Address Line 2,Ship To City,Ship To State,Ship To ZipCode,Ship To Country,Ship To First Name,Ship To LastName,Ship To Company,Ship To Phone Number,Order Customer Email,Order Shipping Method,Item Seller Part #,Item Newegg #,Item Unit Price,Extend Unit Price,Item Unit Shipping Charge,Extend Shipping Charge,Order Shipping Total,Order Total,Quantity Ordered,Quantity Shipped,ShipDate,Actual Shipping Carrier,Actual Shipping Method,Tracking Number,Ship From Address,Ship From City,Ship From State,Ship From Zipcode,Ship From Name

			my $header = "#GROUP_BY=%EREFID\n".				## if order has multiple items (ie multiple rows in csv file)
																		## use the orderid to group items together
							"#STATUS=RECENT\n".					## order needs to be shipped
							"#DECREMENT_INV=Y\n".				## decrement inv
							"#ORDER_EMAIL=N\n".					## can't send email, none give by NewEgg
							"#PAYMENT_METHOD=NEWEGG\n".		## means checkout happened on NewEgg.com
							"#PAYMENT_STATUS=019\n".			## 019=PAID via Marketplace					 
							"#DST=EGG\n".
							"#SKIP_BLANK_LINES=Y\n".
							"#COPY_SHIP_TO_BILL=Y\n".
							"#CREATE_BASIC_ITEMS=Y\n".
							"#SDOMAIN=newegg.com\n".
							"#SEP_CHAR=,\n".

							#"%EREFID,%POST_DATE,ship/address1,ship/address2,ship/city,ship/region,ship/postal,".
							#"ship/countrycode,ship/firstname,ship/lastname,ship/company,ship/phone,bill/email,%SHIPPING_METHOD,".
						  	#"%SKU,Item Newegg #,%PRICE,Item Shipping,%SHIPPING,Order Total,%QTY\n";

							"%EREFID,%POST_DATE,app/saleschannel,app/fulfillmentoption,ship/address1,ship/address2,ship/city,ship/region,ship/postal,".
							"ship/countrycode,ship/firstname,ship/lastname,ship/company,ship/phone,bill/email,%SHIPPING_METHOD,".
						  	"%SKU,Item Newegg #,%PRICE,Extend Unit Price,Item Shipping,Extend Shipping Charge,%SHIPPING,Order Total,%QTY\n";
			## create orders (via import batch job)
			## create an OrderImport batch job based on the CSV file
			require LUSER;
			require ZCSV;
			my ($LU) = LUSER->new_app($USERNAME,'NEWEGG');
			(my $JOBID,$ERROR) = &ZCSV::addFile(
				USERNAME=>$USERNAME,
				PRT=>0,
				'*LU'=>$LU,
				SRC=>"newegg_orders",
				TYPE=>'ORDER',
				FILETYPE=>'CSV',
				BUFFER=>$header.$output,
				SEP_CHAR=>',');
				## addFile returns filename, if no ERROR
			my $filename = '';
			if ($JOBID > 0) {
				$filename = $ERROR;
				$ERROR = '';
				}
				
			if ($ERROR eq '') {
				## archive successfully processed files
				## keep in mind that errors could occur in the CSV Order Import, 
				## but at least files have now been copied to PRIVATE files and are still on newegg under the OrderArchive directory
				foreach my $rename (@archive_files) {
					$ftp->rename($rename->{'file'},$rename->{'archivefile'}) 
						or $ERROR = "rename failed for $rename->{'file'} to $rename->{'archivefile'}: ".$ftp->message;
					$lm->pooshmsg("INFO|+Rename of $rename->{'file'} to $rename->{'archivefile'}");
					}
				}
				
			$lm->pooshmsg("INFO|+JOBID: $JOBID FILENAME: $filename ERROR: $ERROR");
			}

		}

	## should we still save this if there was an ERROR??
	if ($ERROR) {
		}
	elsif ($params{'REDODIR'}) {
		}
	elsif ($ORDERTS>0) {
		$lm->pooshmsg("INFO|+Updating ORDER_LASTRUN_GMT to $ORDERTS");
		$so->set('ORDERS_LASTRUN_GMT',$ORDERTS);
		$so->save();
		}

	return($ERROR);
	}

##
##	possibly use in the future to move files to an Archive dir on NewEgg FTP server
sub ackOrders {
	my ($so, $lm, $ack_ordersref) = @_;

	my $ERROR = '';
	my $output = '';

	## CREDENTIALS	
	my $user = $so->get('.user');
	my $pass = $so->get('.pass');

	#$lm->pooshmsg("INFO|+ack invoice info written to private file [$local_file]");
	}

exit;

