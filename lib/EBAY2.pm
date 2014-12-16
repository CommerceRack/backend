package EBAY2;

use strict;

use Data::GUID;
use Data::Dumper;
use Carp;
use strict;
use POSIX;
use Compress::Zlib;
use MIME::Base64;
use DBI;
use CFG;

use lib "/backend/lib";
require PRODUCT;
require PRODUCT;
require ZOOVY;
require ZTOOLKIT::XMLUTIL;
require ZWEBSITE;
require LISTING::MSGS;
require XMLTOOLS;
require JSONAPI;
require INVENTORY2;


%EBAY2::IS_ENDED_REASONS = (
	0 => 'Live',
	1 => 'Ended', 	# generic don't use this
	2 => 'Sold Out',
	3 => 'Time Expired',
	35 => 'Manually Ended',
	## 50 and above are 'errors'
	48 => 'monitor.pl: txn ends_gmt expired',
	49 => 'monitor.pl: txn items remain is 0',
	55 => 'monitor.pl: not in ebay file',
	56 => 'monitor.pl: no more inventory',
	66 => 'aborted/unsuccessful launch',
	77 => 'aborted launch',
	83 => 'EndItem - reason not specified',
	84 => 'variation revision error',
	98 => 'Never Launched',
	99 => 'Zombie',
	);



##
##
##
sub load_production {
	my ($CFG) = CFG->new();
	$EBAY2::session_certificate = $CFG->get("ebay","session_certificate") || "";
	$EBAY2::developer_name = $CFG->get("ebay","developer_name") || "";
	$EBAY2::application_name = $CFG->get("ebay","application_name") || "";
	$EBAY2::certificate_name = $CFG->get("ebay","certificate_name") || "";
	$EBAY2::runame = $CFG->get("ebay","runame") || "";
	$EBAY2::compatibility = 833;
	}

sub load_sandbox {
	my ($CFG) = CFG->new();
	$EBAY2::session_certificate = $CFG->get("ebay_sandbox","session_certificate") || "";
	$EBAY2::developer_name = $CFG->get("ebay_sandbox","developer_name") || "";
	$EBAY2::application_name = $CFG->get("ebay_sandbox","application_name") || "";
	$EBAY2::certificate_name = $CFG->get("ebay_sandbox","certificate_name") || "";
	$EBAY2::runame = $CFG->get("ebay_sandbox","runame") || "";
	$EBAY2::compatibility = 833;
	}



##
## utility methods
##
sub prt { return($_[0]->{'PRT'}); }
sub username { return($_[0]->{'USERNAME'}); }
sub mid { return($_[0]->{'MID'}); }
sub ebay_eias { return($_[0]->{'EBAY_EIAS'}); }
sub ebay_username { return($_[0]->{'EBAY_USERNAME'}); }
sub ebay_token { return($_[0]->{'EBAY_TOKEN'}); }
sub is_sandbox { return($_[0]->{'IS_SANDBOX'}); }
sub is_epu { return(int($_[0]->{'IS_EPU'})); }

## some internal housekeeping stuff:
sub ebay_compat_level { 
	if ($EBAY2::compatibility<741) { $EBAY2::compatibility = 741; }
	return($EBAY2::compatibility); 
	}

sub validate_currency {
        my ($number) = @_;
        $number =~ s/[\,\$]+//g;        # strip out all the stupid stuff - thats OKAY!
        if ($number =~ /[^\d\.]/) { return(undef); }
        if (index($number,'.') != rindex($number,'.')) { return(undef); }
        return(sprintf("%.2f",$number));
        }


sub our_orderid {
	my ($USERNAME,$EBAY_ORDERID) = @_;

#	my ($EBAY_ID, $EBAY_TXN) = split(/-/,$EBAY_ORDERID,2);
#	use ZTOOLKIT; 
#	my( $ToBase36, $FromBase36 ) = ZTOOLKIT::GenerateBase( 62 );
#	my $COMPRESSTXN = uc($ToBase36->($EBAY_TXN));
#	my $OUR_ORDERID = sprintf("%s-%s",$EBAY_ID,$COMPRESSTXN);
#	if (length($OUR_ORDERID)>20) {
#		require Digest::MD5;
#		$OUR_ORDERID = 'E'.substr(Digest::MD5::md5_hex($EBAY_ORDERID),0,19);
#		}
	
	my ($OUR_ORDERID) = CART2::next_id($USERNAME,0,$EBAY_ORDERID);
	return($OUR_ORDERID);
	}


##
## returns an INV2 object
##
sub INV2 {
	if (not defined $_[0]->{'*INV2'}) { $_[0]->{'*INV2'} = INVENTORY2->new($_[0]->username(),"*EBAY"); }
	return($_[0]->{'*INV2'});
	}


sub sku_has_gtc {
	my ($self,$PRODUCT,%options) = @_;

	my ($udbh) = &DBINFO::db_user_connect($self->username());
	my $pstmt = "select EBAY_ID,ID from EBAY_LISTINGS where MID=".$self->mid()." and PRT=".$self->prt()." and PRODUCT=".$udbh->quote($PRODUCT)." and IS_GTC=1 and IS_ENDED=0";
	print STDERR "$pstmt\n";
	my ($EBAY_ID,$OOID) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();

	if ($options{'fast'}) {
		## don't do a lookup against ebay
		}
	elsif ($EBAY_ID>0) {
		## verify it's still active on eBay before we tell them it is!
		my ($node) = $self->GetItem($EBAY_ID);
		if ($node->{'_is_over'}) {
			$pstmt = "update EBAY_LISTINGS set IS_ENDED=1,ENDS_GMT=".$node->{'_ends_gmt'}." where MID=".$self->mid()." and PRT=".$self->prt()." and EBAY_ID=".$udbh->quote($EBAY_ID);
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			$EBAY_ID = 0;	# actually it's okay!
			}
		}

	return($EBAY_ID,$OOID);
	}


##
##
##
sub sync_inventory {
	my ($USERNAME,$SKU,$IS,$ATTEMPTS) = @_;

	my $error = 0;

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($PID) = &PRODUCT::stid_to_pid($SKU);
	
	my $HAS_OPTIONS = 0;
	if ($PID ne $SKU) {
		$HAS_OPTIONS++;
		warn "PID:$PID SKU:$SKU (WE ARE IN OPTION TERRITORY)\n";
		}
	
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($P) = PRODUCT->new($USERNAME,$PID);

	# my ($prodref) = &ZOOVY::fetchproduct_as_hashref($USERNAME,$PID);

	my ($PROD_MODIFIED_GMT) = -1;
	if (defined $P) {
		$PROD_MODIFIED_GMT = $P->modified_gmt();
		}

	if ($PROD_MODIFIED_GMT == 0) {
		warn "PROD_MODIFIED_GMT is 0 -- probably an error!\n";
		}

	my ($INV2) = INVENTORY2->new($USERNAME,"*EBAY");
	my ($INVSUMMARY) = $INV2->summary('@PIDS'=>[ $PID ]);
#$INVSUMMARY = {
#          'RB338600113:AC0N' => {
#                                  'TS' => '1399661109',
#                                  'PID' => 'RB338600113',
#                                  'DIRTY' => '0',
#                                  'MARKETS' => '0',
#                                  'ONSHELF' => '0',
#                                  'AVAILABLE' => '-1',
#                                  'SKU' => 'RB338600113:AC0N'
#                                },
#          'RB338600113:AC09' => {
#                                  'TS' => '1399661109',
#                                  'PID' => 'RB338600113',
#                                  'DIRTY' => '0',
#                                  'MARKETS' => '0',
#                                  'ONSHELF' => '2',
#                                  'AVAILABLE' => '2',
#                                  'SKU' => 'RB338600113:AC09'
#                                }
#        };

	my ($SKU_QTY_TO_SEND) = $INVSUMMARY->{$SKU}->{'AVAILABLE'};
	my ($PRODUCT_INVENTORY_AVAILABLE) = $INVSUMMARY->{$SKU}->{'AVAILABLE'};

	my $EBAY_FIXED_QTY = $P->fetch('ebay:fixed_qty');

	if ($HAS_OPTIONS) {
		## MAKE SURE WE DONT ACCIDENTALLY REMOVE A PRODUCT JSUT BECAUSE ONE OPTION IS OUT OF STOCK
		## for products that have options, it isn't as simple as just look up the inventory.
		$PRODUCT_INVENTORY_AVAILABLE = 0;	# we just need something so some checks below pass
		foreach my $SKU (keys %{$INVSUMMARY}) {
			if ($INVSUMMARY->{$SKU}->{'AVAILABLE'}>0) { $PRODUCT_INVENTORY_AVAILABLE += $INVSUMMARY->{$SKU}->{'AVAILABLE'}; }
			}
		}
	elsif (($EBAY_FIXED_QTY>0) && ($EBAY_FIXED_QTY < $SKU_QTY_TO_SEND)) {
		$SKU_QTY_TO_SEND = $EBAY_FIXED_QTY;
		}
	elsif (not defined $INVSUMMARY) {
		die("fatal user:$USERNAME pid:$PID could not get valid inventory\n");
		}

	my @PSTMTS = ();
	my $CURRENT_PRICE = undef;
	if (defined $P) {
		$CURRENT_PRICE = sprintf("%.2f",$P->fetch('zoovy:base_price')); # prodref->{'zoovy:base_price'});
		# if ((defined $prodref->{'ebay:fixed_price'}) && (int($prodref->{'ebay:fixed_price'})>0)) {
		if ((defined $P->fetch('ebay:fixed_price')) && (int($P->fetch('ebay:fixed_price')*100)>0)) {
			$CURRENT_PRICE = sprintf("%.2f",$P->fetch('ebay:fixed_price'));
			}
		}

	my $qtPID = $udbh->quote($PID);
	my $pstmt = "select ID,MERCHANT,PRT,PRODUCT,EBAY_ID,CLASS from EBAY_LISTINGS where EBAY_ID>0 and PRODUCT=$qtPID and MID=$MID /* $USERNAME */ and IS_ENDED=0 and IS_SYNDICATED=1";
	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	if ($sth->rows()==0) {
		warn "no rows!\n";
		}
	my %PRTS = ();
	while ( my ($UUID,$USERNAME,$PRT,$PID,$EBAY_ID,$CLASS) = $sth->fetchrow() ) {
		next if (not defined $P);
		next if ($PROD_MODIFIED_GMT <= 0);
		next if (not defined $CURRENT_PRICE);

		if (not defined $PRTS{$PRT}) { $PRTS{$PRT} = []; }

##
## LONG TERM WE SHOULD PROBABLY USE THIS:
#		##
#		#<?xml version="1.0" encoding="utf-8"?>
#		#<ReviseInventoryStatusRequest xmlns="urn:ebay:apis:eBLBaseComponents">
#		#  <!-- Standard Input Fields -->
#		#  <ErrorLanguage> string </ErrorLanguage>
#		#  <MessageID> string </MessageID>
#		#  <Version> string </Version>
#		#  <WarningLevel> WarningLevelCodeType </WarningLevel>
#		#  <!-- Call-specific Input Fields -->
#		#  <InventoryStatus> InventoryStatusType 
#		#    <ItemID> ItemIDType (string) </ItemID>
#		#    <Quantity> int </Quantity>
#		#    <SKU> SKUType (string) </SKU>
#		#  	  <StartPrice> AmountType (double) </StartPrice>
#		#  </InventoryStatus>
#		#  <!-- ... more InventoryStatus nodes here ... -->
#		#</ReviseInventoryStatusRequest>
#		($instock, $reserved) = $INV2->fetch_pidsummary_qtys('@PIDS'=>[$SKU],'%PIDS'=>{$P->pid()=>$P});
#		my %ref = ();
#		$ref{'InventoryStatus.ItemID'} = $le->{'LISTINGID'};
#		$ref{'InventoryStatus.SKU'} = $le->sku();
#		$ref{'InventoryStatus.Quantity'} = $instock;
#		my $result = $eb2->api('ReviseInventoryStatus',\%ref,xml=>3);
#
#		if ($result->{'.'}->{'Ack'}->[0] eq 'Failure') {
#			my ($code) = $result->{'.'}->{'Errors'}->[0]->{'ErrorCode'}->[0];
#			my ($msg) = $result->{'.'}->{'Errors'}->[0]->{'LongMessage'}->[0];
#			$msg =~ s/\|/ /g;
#			push @{$MSGS}, "ERROR|src=MKT|code=$code|+$msg";
#			}
#	
#		}


		if ($EBAY_ID == 0) {
			warn "CAN'T UPDATE EBAYID: 0\n";
			$error |= 1;
			}
		elsif (($CLASS ne 'STORE') && ($CLASS ne 'FIXED')) {
			## non-store, fixed price cannot be revised this way.
			warn "NON STORE/FIXED PRICE LISTING IS NOT COMPATIBLE WITH SYNC_INVENTORY\n";
			$error |= 2;
			}
		elsif ($PRODUCT_INVENTORY_AVAILABLE <= 0) {
			## this time should be ended.
			warn "we should remove this item\n";
			require LISTING::EVENT;
			my ($le) = LISTING::EVENT->new('USERNAME'=>$USERNAME,'PRT'=>$PRT,'SKU'=>$PID,'VERB'=>'END','TARGET'=>'EBAY','TARGET_LISTINGID'=>$EBAY_ID,'TARGET_UUID'=>$UUID,'REQUEST_APP'=>'ZERO');
			$le->dispatch($udbh);
			print sprintf("LE: %d\n",$le->id());
			}
		elsif ($HAS_OPTIONS) {
			## yeah, I know, this is a pain the arse.
			## eBay's option handling is a mess, for the following reasons:
			## 1. ebay drops options that have zero inventory
			## 2. we only update 4 sku's in a ReviseInventoryStatus call.
			## 3. if they don't have those 4 skus, THEN, it's an error!
			## 4. if an item comes back into stock, we have NO WAY to tell them about it, because they dropped it when it was zero!
			## 5. generally they are stupid dumbfucks.. 
			## 6. we can't use their crappy lms/batch call because it does not allow concurrent processing of documents.
			## .. for all the reasons above (and probably a few more i'm not yet aware of) - rather than actually update inventory
			## we'll call a full ReviseFixedPriceItem

			## cheap hack, since they probably have autopilot right?
			# if ($prodref->{'ebay:fixed_price'} <= 0) {

			my %info = ();
			$info{'#Verb'} = 'ReviseFixedPriceItem';
			$info{'Item.UUID'} = $UUID;
			$info{'Item.ItemID'} = $EBAY_ID;
	
			my @MSGS = ();

			require LISTING::EBAY;
			&LISTING::EBAY::add_options_to_request($P,\%info,\@MSGS);

			my ($eb2) = EBAY2->new($USERNAME,PRT=>$PRT);
			my ($r) = $eb2->api('ReviseFixedPriceItem',\%info,xml=>3);

			my $was_successful = 0;
			my $please_remove_to_fix_error = 0;

			if ($r->{'.'}->{'Ack'}->[0] eq 'Success') { $was_successful++; }
			if ($r->{'.'}->{'Ack'}->[0] =~ /^(Warning|Failure)$/) {
				if ($r->{'.'}->{'Ack'}->[0] eq 'Warning') {
					$was_successful = 1;	 ## default position for was_successful
					}

				foreach my $err (@{$r->{'.'}->{'Errors'}}) {
					if ((defined $err->{'id'}) && ($err->{'id'} eq 'HTTP:500')) {
						## HTTP500 error
						$was_successful = -1;		# -1 will retry
						if ($ATTEMPTS>2) {
							$please_remove_to_fix_error = 500; 
							}
						}
					elsif ($err->{'ErrorCode'}->[0] == 231) {
						# The item specified in your input is invalid, not activated, or no longer in our database.
						$please_remove_to_fix_error = 231;
						}
					elsif ($err->{'ErrorCode'}->[0] == 21917236) {
						# Funds from your sales will be unavailable and show as pending in your PayPal account for a period of time.
						$was_successful |= 4; 
						}
					elsif ($err->{'ErrorCode'}->[0] == 21916664) {
						# Invalid Multi-SKU item id supplied with variations.
						$please_remove_to_fix_error = 21916664;
						}
					elsif ($err->{'ErrorCode'}->[0] == 21916635) {
						# Invalid Multi-SKU item id supplied with variations.
						$please_remove_to_fix_error = 21916635; 
						}
					elsif ($err->{'ErrorCode'}->[0] == 21916626) {
						# 21916626: Variations Specifics and Item Specifics entered for a Multi-SKU item should be different.
						$please_remove_to_fix_error = 21916626; 
						}
					elsif ($err->{'ErrorCode'}->[0] == 21916620) { 
						# Variations with quantity \'0\' will be removed.
						$was_successful |= 2; 
						} 
					elsif ($err->{'ErrorCode'}->[0] == 21916608) {
						# Variation cannot be deleted during restricted revise.
						# Reason: This appears to happen after one or more sales happen on a variation listing and a new variation child is being added to the listing.  The eBay system has flagged that transactions have happened on the listing and is incorrectly restricting the options that can be revised.
						# Resolution: This is currently being investigated by eBay.  At this time the only way to resolve the error is to withdraw the children that are still available at eBay in the open listing and let the system submit a new listing with all of the children included.
						$please_remove_to_fix_error = 21916608;
						}
					elsif ($err->{'ErrorCode'}->[0] == 21916585) {
						# Duplicate custom variation label.	
						# Without knowing the open listing, the likely problem here is related to the item specifics changes eBay has in the CSA categories.  If your inventory has changed since that item went live, then the variation information in your inventory doesn't match what eBay knows about the item.  That can cause a conflict when trying to add a child into an open listing, though we try to give you better details about the problem.  While removing the open listing and submitting a new one is very likely to resolve the issue, you're trying to avoid that.  It may be that the open listing can't be modified due to the item specifics changes that eBay's made and that is the only choice if you want this chile item added into the variation listing.  I'd suggest you open a support case so your specific item can be investigated.
						$please_remove_to_fix_error = 21916585;
						}
					elsif ($err->{'ErrorCode'}->[0] == 21916271) {		
						# 21916271: When specifying SKU for InventoryTrackingMethod, the SKU must be unique within your active and scheduled listings.
						$please_remove_to_fix_error = 21916271;
						}
					elsif ($err->{'ErrorCode'}->[0] == 10007) {
						# Internal error to the application
						$was_successful = -1;		# -1 will retry
						if ($ATTEMPTS>2) {
							$please_remove_to_fix_error = 10007; 
							}
						}
					elsif ($err->{'ErrorCode'}->[0] == 932) {
						# Auth token is hard expired, User needs to generate a new token for this application.
						# NOTE: we probably ought to notify the user.
						$was_successful = -1;		# -1 will retry
						if ($ATTEMPTS>5) {
							$please_remove_to_fix_error = 932; 
							}
						}
					elsif (
						($err->{'ErrorCode'}->[0] < 1000) && 
						($err->{'ErrorClassification'}->[0] eq 'RequestError') &&
						($err->{'SeverityCode'}->[0] eq 'Error')
						) {
						## everything we've seen below 1000 seems to be a dealbreaker.
						# 841: Requested user is suspended.
						# 748: words not allowed.
						# 291: You are not allowed to revise ended auctions.
						# 240: The item cannot be listed or modified.
						# 240: From error parameters: You\x{2019}ve exceeded the number of items and dollar amount you can list.</b></div><div><p>You can list up to&nbsp;2,000 items or up to&nbsp;\$120,000.00 this month, whichever comes first. <a href=\"http://pages.ebay.com/help/buy/limits-on-sellers.html\" target=\"_blank\">Learn about selling limits </a>or <a href=\"https://scgi.ebay.com/ws/eBayISAPI.dll?UpgradeLimits\" target=\"_blank\">request higher selling limits.</a></p></div></td></tr></table></div><div class=\"panel-s\"><div class=\"panel-e\"><div class=\"panel-w\"></div></div></div></div>
						# 17: This item cannot be accessed because the listing has been deleted, is a Half.com listing, or you are not the seller.
						$please_remove_to_fix_error = $err->{'ErrorCode'}->[0];
						} 
					elsif ($err->{'SeverityCode'}->[0] eq 'Warning') {
						# 21917089: Revising bin price will end the promo sale on this item.
						$was_successful |= 8;
						}
					else {
						$was_successful = 0;
						}
					}
				}

			if ($please_remove_to_fix_error) {
				## IS_ENDED=84
				$eb2->kill_items('EBAY_ID'=>$EBAY_ID,'IS_ENDED'=>84,'REASON'=>"ReviseItem got Error:$please_remove_to_fix_error");
				}
			elsif ($was_successful==0) {
				&ZOOVY::confess($USERNAME,"eBay ReviseFixedPriceItem Failed [\n".Dumper($r,\%info),'justkidding'=>1);;
				}
			}
		else {
			my %EBREF = ();
			my %DBREF = ();

			warn "did else\n";
			$EBREF{'SKU'} = $SKU;
			$EBREF{'ItemID'} = $EBAY_ID;
			$DBREF{'MID'} = $MID;
			$DBREF{'ID'} = $UUID;
			$DBREF{'PRODTS'} = int($PROD_MODIFIED_GMT);

			$EBREF{'Quantity'} = $SKU_QTY_TO_SEND;
			$DBREF{'ITEMS_SOLD'} = 0;

			$EBREF{'StartPrice'} = $CURRENT_PRICE;
			$DBREF{'BUYITNOW'} = $CURRENT_PRICE;

			my ($eb2) = EBAY2->new($USERNAME,PRT=>$PRT);
			## note: while we can have multiple <InventoryStatus> containers, we are limited to 4 so it's probably better
			## to just pass one at a time!
			my %hash = ( '*'=>sprintf("<InventoryStatus>%s</InventoryStatus>\n",ZTOOLKIT::hashref_to_xmlish(\%EBREF)) );
			my ($r) = $eb2->api('ReviseInventoryStatus',\%hash,preservekeys=>['Item'],xml=>3);

			my $pstmt = &DBINFO::insert($udbh,'EBAY_LISTINGS',\%DBREF,'key'=>['MID','ID'],'update'=>2,'sql'=>1);
			$INV2->mktinvcmd('FOLLOW','EBAY',$EBAY_ID,$SKU,'QTY'=>$SKU_QTY_TO_SEND);
			$udbh->do($pstmt);
			}
		}
	$sth->finish();

	&DBINFO::db_user_close();
	return($error);
	}


##
##
##
#sub gtc_update {
#	my ($self,$PRODUCT,$EBAY_ID,%options) = @_;
#
#	}

## returns a valid user for a cluster (useful for rebuilding category specifics)
## perl -e 'use lib "/backend/lib"; use EBAY2; use Data::Dumper; print Dumper(EBAY2::valid_user_for_cluster("crackle"));'
sub valid_user_for_cluster {
	my ($cluster) = @_;

	die("not cluster safe!\n");
#	my ($udbh) = &DBINFO::db_user_connect("\@$cluster");
#	my $pstmt = "select USERNAME,EBAY_EIAS from EBAY_TOKENS where ERRORS<=0 order by ID desc limit 0,1";
#	my ($USERNAME,$EIAS) = $udbh->selectrow_array($pstmt);
#	&DBINFO::db_user_close();
#
#	print "USER: $USERNAME EIAS: $EIAS\n";
#	return($USERNAME,$EIAS);
	}


##
## jobType: SoldReport, ActiveListings
##	frequency: 52 minutes!?
##
#sub verify_recurring_jobs {
#	my ($self,$lm) = @_;
#
#	if (not defined $lm) {
#		($lm) = LISTING::MSGS->new($self->username());
#		}
##
#	my $USERNAME = $self->username();
#	my ($udbh) = DBINFO::db_user_connect($self->username());
#	my %DB_UPDATES = ();
#	$DB_UPDATES{'MID'} = $self->mid();
#	$DB_UPDATES{'PRT'} = $self->prt();
#
#	my ($UUIDx,$resultx) = $self->bdesapi('getRecurringJobs',{},output=>"xml");
#	# print Dumper($resultx);
#	if (($UUIDx) && ($resultx->{'ack'}->[0] eq 'Success')) {
#		$DB_UPDATES{'LMS_SOLD_DOCID'} = 0;
#		$DB_UPDATES{'LMS_ACTIVE_DOCID'} = 0;
#		foreach my $jobdetail (@{$resultx->{'recurringJobDetail'}}) {
#			#$VAR1 = {
#			#	 'frequencyInMinutes' => [
#			#									 '52'
#			#								  ],
#			#	 'recurringJobId' => [
#			#								'5000096200'
#			#							 ],
#			#	 'creationTime' => [
#			#							 '2011-01-14T01:09:53.000Z'
#			#						  ],
#			#	 'jobStatus' => [
#			#						 'Active'
#			#					  ],
#			#	 'downloadJobType' => [
#			#								 'SoldReport'
#			#							  ]
#			#  };
#			#$jobdetail->{'downloadJobType'}->[0];	# ActiveInventoryReport|SoldReport
#			#$jobdetail->{'jobStatus'}->[0];	# Active|?
#			#$jobdetail->{'recurringJobId'}->[0];	# ###
#			if ($jobdetail->{'jobStatus'}->[0] ne 'Active') {
#				$lm->showmsg("FAIL|+JOB IS NOT ACTIVE");
#				}
#			elsif ($jobdetail->{'downloadJobType'}->[0] eq 'ActiveInventoryReport') {
#				$DB_UPDATES{'LMS_ACTIVE_DOCID'} = $jobdetail->{'recurringJobId'}->[0];
#				}
#			elsif ($jobdetail->{'downloadJobType'}->[0] eq 'SoldReport') {
#				$DB_UPDATES{'LMS_SOLD_DOCID'} = $jobdetail->{'recurringJobId'}->[0];
#				}
#			else {
#				$lm->showmsg(sprintf("WARN|Unknown downloadJobType: %s",$jobdetail->{'downloadJobType'}->[0]));
#				}
#			$lm->has_failed() && $lm->pooshmsg("DEBUG|+".Dumper($jobdetail));
#			}
#		$lm->pooshmsg(sprintf("INFO|+LMS_ACTIVE_DOCID=%s",$DB_UPDATES{'LMS_ACTIVE_DOCID'}));
#		$lm->pooshmsg(sprintf("INFO|+LMS_SOLD_DOCID=%s",$DB_UPDATES{'LMS_SOLD_DOCID'}));
#		}
#	else {
#		$lm->pooshmsg("ERROR|+Non 'Success' on getRecurringJobs ".Dumper($resultx));
#		}
#
#
#	my @NEED_JOBS = ();
#	if ($DB_UPDATES{'LMS_ACTIVE_DOCID'} == 0) {
#		# push @NEED_JOBS, [ 'ActiveInventoryReport', 'frequencyInMinutes', 54, 'LMS_ACTIVE_DOCID', 'LMS_ACTIVE_UUID' ];
#		push @NEED_JOBS, [ 'ActiveInventoryReport', 'dailyRecurrence.timeOfDay', '01:00:00.000Z', 'LMS_SOLD_DOCID', 'LMS_SOLD_UUID' ];
#		}
##	if ($DB_UPDATES{'LMS_SOLD_DOCID'} == 0) {
#		# push @NEED_JOBS, [ 'SoldReport', 'dailyRecurrence.timeOfDay', '08:00:00.000Z', 'LMS_SOLD_DOCID', 'LMS_SOLD_UUID' ];
#		push @NEED_JOBS, [ 'SoldReport', 'frequencyInMinutes', 60*3, 'LMS_ACTIVE_DOCID', 'LMS_ACTIVE_UUID' ];
#		}
#
#	if (not $lm->can_proceed()) {
#		$DB_UPDATES{'ERRORS'} += 1;
#		}
#	else {
#		foreach my $jobinfo (@NEED_JOBS) {
#			my ($jobtype,$jobperiod,$jobinterval,$DB_DOCID,$DB_UUID) = @{$jobinfo};
#			my ($UUID,$result) = $self->bdesapi('createRecurringJob',{
#				'downloadJobType'=>$jobtype,
#				$jobperiod=>$jobinterval,
#				#'frequencyInMinutes'=>$jobinterval,
#				#'dailyRecurrence.timeOfDay'=>'08:00:00.000Z',
#				},output=>'flat');
#	
#			# print Dumper($jobtype,$UUID,$result);
#			if ($UUID eq '') {
#				$lm->showmsg("ISE|+UUID returned from createRecurringJob is blank");
#				}
#			elsif (($result->{'.ack'} eq 'Success') || ($result->{'.ack'} eq 'Active')) {
#				## it's all cool!		
#				$DB_UPDATES{$DB_DOCID} = $result->{'.recurringJobId'}; # LMS_ACTIVE_DOCID
#				$DB_UPDATES{$DB_UUID} = $UUID;	# LMS_ACTIVE_UUID
#				$lm->pooshmsg("SUCCESS|+DB-UPDATE $DB_DOCID:$DB_UPDATES{$DB_DOCID}");
#				}
#			elsif ($result->{'.ack'} eq 'Failure') {
#				$lm->showmsg("ISE|+Ack was a failure!");
#				}
#			else {
#				$lm->showmsg("ISE|+Ack was an unknown type!");
#				}
#
#			$lm->has_failed() && $lm->pooshmsg("DEBUG|jobtype=$jobtype|".Dumper($result)); 
#			}
#		if ($DB_UPDATES{'LMS_ACTIVE_DOCID'} == 0) {
#			$lm->showmsg("ISE|+LMS_ACTIVE_DOCID==0 (still 0) - bumping token errors +250");
#			$DB_UPDATES{'ERRORS'} += 250;
#			}
#		if ($DB_UPDATES{'LMS_SOLD_DOCID'} == 0) {
#			$lm->showmsg("ISE|+LMS_SOLD_DOCID==0 (still 0) - bumping token errors +250");
#			$DB_UPDATES{'ERRORS'} += 250;
#			}
#
#		if (($DB_UPDATES{'LMS_ACTIVE_DOCID'}) && ($DB_UPDATES{'LMS_SOLD_DOCID'})) {
#			## might as well clear out errors.
#			$lm->pooshmsg("SUCCESS|+Setting token error count to zero since we have a ACTIVE/SOLD docs");
#			$DB_UPDATES{'ERRORS'} = 0;
#			}
#		}
#
#	if (my $result = $lm->had('ISE')) {
#		&ZOOVY::confess($USERNAME,"verify_recurring_jobs $result->{'+'}".Dumper($lm),justkidding=>1);
#		}
#
#	my $pstmt = &DBINFO::insert($udbh,'EBAY_TOKENS',\%DB_UPDATES,key=>['MID','PRT'],sql=>1,update=>2);
#	print STDERR $pstmt."\n";
#	$udbh->do($pstmt);
#
#	&DBINFO::db_user_close();
#	return(\%DB_UPDATES);
#	}
#
##
## ZSHIP::smart_weight always returns in oz
##		this returns in lbs/oz
##
sub smart_weight_in_lboz {
	my ($weight) = @_;
	
	my ($totaloz) = &ZSHIP::smart_weight_new($weight);
	my ($lbs) = int($totaloz/16);
	my ($oz) = int($totaloz%16);
	return($lbs,$oz);
	}


##
## type: SKIP|FAIL|WARN|INFO|GOOD
## msg: 
## %options
##			PID=>
##
sub log {
	my ($self, $type, $msg, %options) = @_;
	require TODO;
	TODO::easylog($self->username(),class=>$type,title=>$msg,%options);		
	}


sub appid {
	return( (rindex($::0,'/')>=0)?substr($::0,rindex($::0,'/')+1):$::0);
	}


##
## which database table our data is in.
##
#sub monitor_tb {
#	my ($USERNAME) = @_;
#
#	if ($USERNAME eq '') {
#		Carp::confess("username not passed");
#		}
#
#	if (substr($USERNAME,0,1) eq '@') {
#		$USERNAME = uc($USERNAME);
#		# if ($USERNAME eq '@SNAP') { return("MONITOR_QUEUE_SNAP"); }
#		# if ($USERNAME eq '@CRACKLE') { return("MONITOR_QUEUE_CRACKLE"); }
#		# if ($USERNAME eq '@POP') { return("MONITOR_QUEUE_POP"); }
#		# if ($USERNAME eq '@DAGOBAH') { return("MONITOR_QUEUE_POP"); }
#		return("EBAY_LISTINGS");
#		}
#	else {
#		$USERNAME = lc($USERNAME);
#		my ($CLUSTER) = uc(&ZOOVY::resolve_cluster($USERNAME));
#		# if ($CLUSTER eq 'SNAP') { return('MONITOR_QUEUE_SNAP'); }
#		# if ($CLUSTER eq 'CRACKLE') { return('MONITOR_QUEUE_CRACKLE'); }
#		# if ($CLUSTER eq 'POP') { return('MONITOR_QUEUE_POP'); }
#		# if ($CLUSTER eq 'DAGOBAH') { return('MONITOR_QUEUE_POP'); }
#		return("EBAY_LISTINGS");
#		die("Unknown CLUSTER:$CLUSTER");
#		}
#
#	return("MONITOR_QUEUE_OO");
#	}

#sub tb {
#	return(&EBAY2::monitor_tb($_[0]->username()));
#	}


##
## accepts:
##		MKT_LISTINGID=>
##		OOID=>
##
sub resolve_channel {
	my ($self,%params) = @_;

	my $edbh = &DBINFO::db_user_connect($self->username());
	my $MID = $self->mid();
	my $USERNAME = $self->username();
	my $CHANNEL = undef;
	if (defined $params{'MKT_LISTINGID'}) {
		my $pstmt = "select CHANNEL from EBAY_LISTINGS where MID=$MID /* $USERNAME */ and EBAY_ID=".int($params{'MKT_LISTINGID'});
		($CHANNEL) = $edbh->selectrow_array($pstmt);
		}
	elsif (defined $params{'OOID'}) {
		my $pstmt = "select CHANNEL from EBAY_LISTINGS where MID=$MID /* $USERNAME */ and ID=".int($params{'OOID'});
		print STDERR $pstmt."\n";
		($CHANNEL) = $edbh->selectrow_array($pstmt);
		}
	&DBINFO::db_user_close();
	return($CHANNEL);
	}


sub new_for_auth {
	my ($CLASS, $USERNAME, $PRT) = @_;

	# my $self = { USERNAME=>$USERNAME, MID=>&ZOOVY::resolve_mid($USERNAME), PRT=>$PRT };
	my ($self) = { USERNAME=>$USERNAME,  PRT=>$PRT };
	bless $self, $CLASS;
	return($self);
	}



#################################################################
##
## accepts parameters:
##		EIAS=>	
##		PRT=>
##
sub new {
	my ($class,$USERNAME,%options) = @_;
	
	my $self = {};
	
	my $edbh = DBINFO::db_user_connect($USERNAME);
	my $MID = 0;

	my $pstmt = '';
	if ((defined $USERNAME) && ($USERNAME ne '')) {	
		$self->{'USERNAME'} = $USERNAME;
		($MID) = &ZOOVY::resolve_mid($USERNAME);
		$self->{'MID'} = $MID;
		}

	if ((not defined $options{'PRT'}) && (defined $options{'EBAYID'})) {
		## this is not recommended, but i realize it's necessary in some circumstances (for now) like pickup.pl
		my ($MID) = &ZOOVY::resolve_mid($USERNAME);
		$pstmt = "select PRT from EBAY_LISTINGS where MID=$MID and EBAY_ID=".int($options{'EBAYID'});
		print STDERR $pstmt."\n";
		my ($PRT) = $edbh->selectrow_array($pstmt);
		if (defined $PRT) { 
			$options{'PRT'} = $PRT; 
			}
		else {
			warn "Unable to lookup eBay Item";
			}
		}

	$pstmt = "select ID,USERNAME,PRT,EBAY_USERNAME,EBAY_TOKEN,EBAY_EIAS,CHKOUT_STYLE,IS_SANDBOX,DO_IMPORT_LISTINGS,";
	$pstmt .= " DO_CREATE_ORDERS,IGNORE_ORDERS_BEFORE_GMT,LMS_INVENTORY_DOCID,LMS_INVENTORY_TS+0 as LMS_INVENTORY_GMT ";
	$pstmt .= " from EBAY_TOKENS where 1=1 ";
	$pstmt .= " and MID=$MID /* $USERNAME */ ";

	if ((defined $options{'EIAS'}) && ($options{'EIAS'} ne '')) {
		$pstmt .= " and EBAY_EIAS=".$edbh->quote($options{'EIAS'});
		}
	elsif (defined $options{'PRT'}) {
		$pstmt .= " and PRT=".int($options{'PRT'});
		}
	elsif (defined $options{'ANYTOKENWILLDO'}) {
		## yep, just what it sounds like.
		}
	elsif (defined $options{'USERID'}) {
		$pstmt .= " and EBAY_USERNAME=".$edbh->quote($options{'USERID'});
		}
	else {
		warn("EBAY2->new called without EIAS,PRT or USERID set");
		return(undef);
		}
		

	print STDERR $pstmt."\n";
	my ($info) = $edbh->selectrow_hashref($pstmt);
	if (defined $info) {
		## copy database keys into account object.
		$USERNAME = $info->{'USERNAME'};
		foreach my $k (keys %{$info}) {
			$self->{$k} = $info->{$k};
			}

		if (not defined $self->{'MID'}) {
			## lookup the MID if $USERNAME wasn't passed.
			$self->{'MID'} = &ZOOVY::resolve_mid($USERNAME);
			}

		## implicitly force eBay checkout for all accounts.
		$self->{'CHKOUT_STYLE'} = 'EBAY';

		bless $self, 'EBAY2';
		}
	else {
		$self = undef;
		}
	
	&DBINFO::db_user_close();

	return($self);
	}





##
## this is a convenient (cached) way to lookup global attributes in the %ebay key in the global.bin
##	these are typically set in the setup/ebay/notifications area and affect some system level behaviors
##
sub global_shortcut {
	my ($self,$k) = @_;

	if (not defined $self->{'%EBAYGREF'}) {
		my ($gref) = &ZWEBSITE::fetch_globalref($self->username());
		&ZWEBSITE::global_init_defaults($gref);
		$self->{'%EBAYGREF'} = $gref->{'%ebay'};
		}
	return($self->{'%EBAYGREF'}->{$k});
	}

##
## currently this only returns USERNAME, EBAY_ID but it could return more in the future.
## undef on failure.
sub lookup_ooid {
	my ($self, $OOID) = @_;
	my ($USERNAME,$EBAY_ID) = &EBAY2::lookup_ooid($OOID);
	if ((defined $USERNAME) && ($USERNAME eq $self->username())) {
		return({USERNAME=>$USERNAME,EBAY_ID=>$EBAY_ID});
		}
	return(undef);
	}

##
##
##
sub get {
	my ($self, $attrib) = @_;	 
	return($self->{$attrib});
	}


##
## pass this key=>val 
##
sub set {
	my ($self, %options) = @_;

	## eventually we should probably have a white list of %options which can be set.
	
	my $edbh = &DBINFO::db_user_connect($self->username());
	my $pstmt = DBINFO::insert($edbh,'EBAY_TOKENS',\%options,update=>2,
		key=>{
			MID=>$self->mid(),
			PRT=>$self->prt()
			},
		debug=>2
		);
	print STDERR $pstmt."\n";
	$edbh->do($pstmt);

	while ( my ($k,$v) = each(%options) ) {
		$self->{$k} = $v;
		}

	&DBINFO::db_user_close();
	}


######################################################################################
##
## attempts to resolve a claim and/or order #
##
## params are:
##		listingid
##		buyeruserid OR buyereias OR txnid
##		
sub lookupSales {
	my ($self, %params) = @_;

	my $edbh = &DBINFO::db_user_connect($self->username());
	my $MID = $self->mid();
	my $USERNAME = $self->username();

	my $pstmt = "select * from EBAY_WINNERS where MID=$MID /* $USERNAME */ ";
	if ($params{'ebay_orderid'}) {
		$pstmt .= " and EBAY_ORDERID=".$edbh->quote($params{'ebay_orderid'});
		}

	if ($params{'listingid'}) {
		my $EBAY_ID = int($params{'listingid'});
		$pstmt .= " and EBAY_ID=$EBAY_ID ";
		}
	if ($params{'transactionid'}>0) {
		$pstmt .= " and TRANSACTION=".$edbh->quote($params{'transactionid'});
		}

	if (($params{'buyeruserid'}) && ($params{'buyereias'})) {
		$pstmt .= " and (EBAY_USER=".$edbh->quote($params{'buyeruserid'})." or EBAY_USER_EIAS=".$edbh->quote($params{'buyereias'}).") ";
		}
	elsif ($params{'buyereias'}) {
		$pstmt .= " and (EBAY_USER_EIAS=".$edbh->quote($params{'buyereias'}).") ";
		}
	elsif ($params{'buyeruserid'}) {
		$pstmt .= " and (EBAY_USER=".$edbh->quote($params{'buyeruserid'}).") ";
		}
	else {
		warn "No buyeruserid or buyereias passed";
		$pstmt .= " and 1=0 ";
		}
	print STDERR $pstmt."\n";
	my $sth = $edbh->prepare($pstmt);
	$sth->execute();
	my @ROWS = ();
	my @CLAIMS = ();
	while ( my $ref = $sth->fetchrow_hashref() ) {
		## returns a record structured like EBAY_WINNERS is
		push @ROWS, $ref;
		push @CLAIMS, $ref->{'CLAIM'};
		}
	$sth->finish();
	&DBINFO::db_user_close();

	require DBINFO;
	if (scalar(@CLAIMS)>0) {
		my ($udbh) = &DBINFO::db_user_connect($USERNAME);
		$pstmt = "select ID,MKT_LISTINGID,MKT_TRANSACTIONID,STAGE,ZOOVY_ORDERID from EXTERNAL_ITEMS where MID=$MID /* $USERNAME */ ";
		if ($params{'listingid'}) {
			my $EBAY_ID = int($params{'listingid'});
			$pstmt .= " and MKT_LISTINGID=$EBAY_ID ";
			}
		$pstmt .= " and ID in ".&DBINFO::makeset($udbh,\@CLAIMS);
		print $pstmt."\n";
		$sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my $incref = $sth->fetchrow_hashref() ) {
			print STDERR "CLAIM: $incref->{'ID'} ZOOVY_ORDERID: $incref->{'ZOOVY_ORDERID'}\n";
			foreach my $row (@ROWS) {
				if ($row->{'CLAIM'} eq $incref->{'ID'}) { 
					$row->{'ORDERID'} = $incref->{'ZOOVY_ORDERID'}; 
					$row->{'%CLAIM'} = $incref;
					}
				
				}
			}
		$sth->finish();
		}

	&DBINFO::db_user_close();	

	## now handle filters like _no_order 
	my @RESULT = ();
	foreach my $row (@ROWS) {
		my $skip = 0;
		if ($params{'_no_order'}) {
			if ($row->{'%CLAIM'}->{'ZOOVY_ORDERID'} ne '') { $skip++; }
			elsif ($row->{'%CLAIM'}->{'STAGE'} eq 'C') { $skip++; }
			elsif ($row->{'%CLAIM'}->{'STAGE'} eq 'P') { $skip++; }
			}
		if (not $skip) {
			push @RESULT, $row;
			}
		}

	return(@RESULT);
	}


###################################################################################
##
## incref is:
##		BUYER_EMAIL, BUYER_USERID, BUYER_EIAS
##		SKU, PRICE, QTY, PROD_NAME
##		MKT_LISTINGID, MKT_TRANSACTIONID
##
sub createClaim {
	my ($self, $incref ) = @_;

	#my ($redis) = &ZOOVY::getRedis($self->username(),1);
	#my $limit = IPC::ConcurrencyLimit->new(
	#	type       => 'Redis',
	#	max_procs  => 1, # defaults to 1
	#	redis_conn => $redis,
	#	key_name   => sprintf("EBAY.ORDERS.%s",$self->username()),
	#  );
	#my $id = $limit->get_lock;
	#if (not $id) {
	#	warn "Couldn't get lock";
	#	return(0);
	#	}

	my $CLAIM = undef;

	my $ALWAYS_CREATE = 0;
	if ($self->username() eq 'nyciwear') { $ALWAYS_CREATE++; }
		

	if ((defined $CLAIM) && ($CLAIM==-1) && ($ALWAYS_CREATE)) {
		warn "ALWAYS_CREATE was turned on -- Claim was -1 -- we'll create a real one.";
		$CLAIM = undef;
		}

	if (not defined $CLAIM) {
		## check for all the required parameters.
		my @REQUIRED = (
				'BUYER_EMAIL','BUYER_USERID','BUYER_EIAS',
				'SKU','PRICE','QTY','PROD_NAME',
				'MKT_LISTINGID', 'SITE');
		if (not $ALWAYS_CREATE) { push @REQUIRED, 'CHANNEL'; }
		foreach my $attrib (@REQUIRED) {
			if (not defined $incref->{$attrib}) {
				warn "MISSING attrib: $attrib is required";
				$CLAIM = -1; 
				}
			}
		}

	if (not defined $incref->{'CHANNEL'}) {
		$incref->{'CHANNEL'} = $self->resolve_channel(MKT_LISTINGID=>$incref->{'MKT_LISTINGID'});
		}
	$incref->{'CHANNEL'} = int($incref->{'CHANNEL'});
	if (not defined $incref->{'MKT_TRANSACTIONID'}) { $incref->{'MKT_TRANSACTIONID'} = 0; }
	if (not defined $incref->{'BUYER_USERID'}) { $incref->{'BUYER_USERID'} = ''; }
	$incref->{'QTY'} += 0; if ($incref->{'QTY'} <= 0) { $incref->{'QTY'} = 1; }
	$incref->{'SITE'} = int($incref->{'SITE'});

	my $udbh = &DBINFO::db_user_connect($self->username());
	my $qtAPP = $udbh->quote($self->appid());
	my $qtEBAYID = $udbh->quote($incref->{'MKT_LISTINGID'});
	

	if (not defined $CLAIM) {
		# first thing, check for duplicates
		my $pstmt = "select CLAIM from EBAY_WINNERS where EBAY_ID=$qtEBAYID and EMAIL=".$udbh->quote($incref->{'BUYER_EMAIL'});
		if ($incref->{'MKT_TRANSACTIONID'}) { $pstmt .= " and TRANSACTION=".$udbh->quote($incref->{'MKT_TRANSACTIONID'}); }
		print STDERR $pstmt."\n";
		($CLAIM) = $udbh->selectrow_array($pstmt);
		}
	# print STDERR "createClaim: $incref->{'MKT_LISTINGID'} $incref->{'SKU'}/$incref->{'BUYER_EMAIL'}/$incref->{'PRICE'}/$incref->{'QTY'}/$incref->{'MKT_TRANSACTIONID'}/$incref->{'BUYER_USERID'}\n";

	if (not defined $CLAIM) {
		# first thing, check for duplicates
		my $pstmt = "select CLAIM from EBAY_WINNERS where EBAY_ID=$qtEBAYID and EBAY_USER=".$udbh->quote($incref->{'BUYER_USERID'});
		if ($incref->{'MKT_TRANSACTIONID'}) { $pstmt .= " and TRANSACTION=".$udbh->quote($incref->{'MKT_TRANSACTIONID'}); }
		print STDERR $pstmt."\n";
		($CLAIM) = $udbh->selectrow_array($pstmt);
		}

	if (not defined $CLAIM) {
		if (uc($incref->{'BUYER_EMAIL'}) eq '') { $CLAIM = -1; }
		if (uc($incref->{'BUYER_EMAIL'}) eq 'INVALID REQUEST') { $CLAIM = -1; }
		if (uc($incref->{'BUYER_EMAIL'}) eq 'INVALID EMAIL') { $CLAIM = -1; }
		if ($incref->{'BUYER_EMAIL'} eq 'Invalid Request') { $CLAIM = -1; }
		if (defined $CLAIM) {
			warn "BUYER EMAIL IS: $incref->{'BUYER_EMAIL'}\n";
			}
		}


	my $t = time();

	if (not defined $CLAIM) {
		my $MKTID = $incref->{'MKT_LISTINGID'};
		if ((defined $incref->{'MKT_TRANSACTIONID'}) && ($incref->{'MKT_TRANSACTIONID'}>0)) { $MKTID .= '-'.$incref->{'MKT_TRANSACTIONID'}; }

		require EXTERNAL;
		my %EXTINFO = ();
		$EXTINFO{'BUYER_EIAS'} = $incref->{'BUYER_EIAS'};
		$EXTINFO{'BUYER_EMAIL'} = $incref->{'BUYER_EMAIL'};
		$EXTINFO{'CHANNEL'} = $incref->{'CHANNEL'};
		$EXTINFO{'SKU'} = $incref->{'SKU'};
		$EXTINFO{'MKT'} = 'EBAY';
		$EXTINFO{'MKT_SITE'} = int($incref->{'SITE'});
		$EXTINFO{'MKT_LISTINGID'} = $incref->{'MKT_LISTINGID'};
		$EXTINFO{'PRICE'} = $incref->{'PRICE'};
		$EXTINFO{'MKT_TRANSACTIONID'} = $incref->{'MKT_TRANSACTIONID'};
		$EXTINFO{'PROD_NAME'} = $incref->{'PROD_NAME'}." (eBay: ".$incref->{'MKT_LISTINGID'}.")"; # $ZBREF->{'zoovy:prod_name'};
		$EXTINFO{'QTY'} = $incref->{'QTY'};	
		$EXTINFO{'BUYER_USERID'} = $incref->{'BUYER_USERID'};
		$EXTINFO{'SELLER_EIAS'} = $self->ebay_eias();
		if ($incref->{'OUR_ORDERID'}) { $EXTINFO{'ZOOVY_ORDERID'} = $incref->{'OUR_ORDERID'}; }

		## don't send emails when COR is not on.
		$EXTINFO{'AUTOEMAIL'} = 0; # int($self->get('CHKOUT_STYLE') eq 'COR')?1:0;

		my $USERNAME = $self->username();
		my $PRT = $self->prt();
	
		print STDERR "STARTING CREATE\n";
		($CLAIM) = &EXTERNAL::create($self->username(),$self->prt(), $incref->{'SKU'}, \%EXTINFO);
		if ($CLAIM eq '') { $CLAIM = 0; }	
		print STDERR "CREATED CLAIM: $CLAIM\n";
			
		if ($CLAIM<=0) {		
			## some sort of error occurred, wait and try again
			die();
			sleep(3);
		
			my @params = @_;
			shift @params;
			($CLAIM) = $self->createClaim(@params);
			}

		## okay dj - lets pump this party!@
		my $pstmt = &DBINFO::insert($udbh,'EBAY_WINNERS',{
			CLAIM=>$CLAIM,
			MERCHANT=>$self->username(),
			MID=>$self->mid(),
			CHANNEL=>$incref->{'CHANNEL'},
			PRODUCT=>$incref->{'SKU'},
			EBAY_ID=>$incref->{'MKT_LISTINGID'},
			EBAY_USER=>$incref->{'BUYER_USERID'},
			EMAIL=>$incref->{'BUYER_EMAIL'},
			CREATED=>&ZTOOLKIT::mysql_from_unixtime(time()),
			AMOUNT=>$incref->{'PRICE'},
			QTY=>$incref->{'QTY'},
			TRANSACTION=>$incref->{'MKT_TRANSACTIONID'},
			APP=>$self->appid(),
			SITE_ID=>$incref->{'SITE'},
			EIAS=>$self->ebay_eias(),
			## OUR_ORDERID=>
			},debug=>2);
		print STDERR $pstmt."\n";
		#open Fx, ">>/tmp/ebay-winners.sql";
		#print Fx "$pstmt\n";	
		#close Fx;
		$udbh->do($pstmt);

		## NOTE: we should probably update the channel here.
		if ($CLAIM > 0) {
			## yipes!
			my $qty = int($incref->{'QTY'});
			#				RELISTS=0 where CHANNEL=$incref->{'CHANNEL'} and MID=".$self->mid()." /* ".$self->username()." */";
			$pstmt = "update EBAY_LISTINGS set ITEMS_SOLD=ITEMS_SOLD+$qty where EBAY_ID=".$udbh->quote($incref->{'MKT_LISTINGID'})." and MID=".$self->mid()." /* ".$self->username()." */";
			print $pstmt."\n";
			my $rv = $udbh->do($pstmt) or warn or $udbh->errstr;
			}			

		} 
				

	&DBINFO::db_user_close();
	return($CLAIM);
	}





##
## resolve US, eBayMotors, etc. into the respective site id.
##
sub resolve_siteid {
	my ($self,$sitetxt) = @_;

	my $SITE = 0;
	if ($sitetxt eq 'US') {
		## US is SITE 0
		}
	elsif ($sitetxt eq 'eBayMotors') {
		$SITE = 100;
		}
	else {
		die("Unknown SITE: $sitetxt");
		}
	return($SITE);
	}


##
## takes one of several different ebay formats, and:
##		1. creates an entry in ebay winners
##		2. creates an entry in EXTERNAL_ITEMS
##		3. marks the sale as sold
##		4. notifies powerlister.
## 
sub recordSale {
	my ($self, %params) = @_;

	my $CLAIM = 0;


	my $data = undef;

	my $item = undef;
	if (defined $params{'%item'}) {
		## eventually this will replace the need for *ebl
		$item = $params{'%item'};
		if (not defined $item->{'.Item.ItemID'}) {
			Carp::confess("Sorry .. gotta have: ItemID in %item");
			die();
			}
		}


	if (defined $params{'%txn'}) {
		## this is a result from a TransactionArray
		$data = {};
		my $tx = $params{'%txn'};
#$tx = {
#					'.TransactionSiteID' => 'US',
#					'.ShippingDetails.ShippingServiceOptions.ShippingServiceAdditionalCost._' => '1.5',
#					'.Buyer.BuyerInfo.ShippingAddress.Street1' => '2021 N. BROADMOOR, # 504',
#					'.Buyer.FeedbackRatingStar' => 'Red',
#					'.ShippingServiceSelected.ShippingInsuranceCost._' => '0.0',
#					'.ShippingDetails.InsuranceWanted' => 'false',
#					'.TransactionID' => '389081919001',
#					'.Buyer.EIASToken' => 'nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wJnYOlD5CCpg6dj6x9nY+seQ==',
#					'.Buyer.BuyerInfo.ShippingAddress.AddressOwner' => 'PayPal',
#					'.Status.eBayPaymentStatus' => 'NoPaymentFailure',
#					'.ShippingServiceSelected.ShippingServiceCost._' => '3.0',
#					'.Buyer.VATStatus' => 'NoVATTax',
#					'.ShippingDetails.InternationalShippingServiceOption.ShippingServiceCost._' => '4.5',
#					'.Status.PaymentHoldStatus' => 'CustomCode',
#					'.Buyer.BuyerInfo.ShippingAddress.Country' => 'US',
#					'.ShippingDetails.InternationalShippingServiceOption.ShippingServiceAdditionalCost._' => '2.25',
#					'.ShippingDetails.SalesTax.SalesTaxAmount._' => '0.0',
#					'.DepositType' => 'None',
#					'.Status.LastTimeModified' => '2009-05-23T03:31:30.000Z',
#					'.Status.CheckoutStatus' => 'CheckoutIncomplete',
#					'.AdjustmentAmount._' => '0.0',
#					'.Buyer.UserID' => 'offload',
#					'.ShippingDetails.ShippingServiceOptions.ShippingServicePriority' => '1',
#					'.Buyer.Status' => 'Confirmed',
#					'.Status.PaymentMethodUsed' => 'None',
#					'.Buyer.BuyerInfo.ShippingAddress.Name' => 'ALAN BRUCHAS',
#					'.ShippingDetails.TaxTable.TaxJurisdiction.ShippingIncludedInTax' => 'false',
#					'.AdjustmentAmount.currencyID' => 'USD',
#					'.Buyer.BuyerInfo.ShippingAddress.AddressID' => '379982211',
#					'.Status.CompleteStatus' => 'Incomplete',
#					'.ShippingServiceSelected.ShippingService' => 'USPSFirstClass',
#					'.QuantityPurchased' => '1',
#					'.Buyer.FeedbackPrivate' => 'false',
#					'.TransactionPrice._' => '15.95',
#					'.BuyerGuaranteePrice.currencyID' => 'USD',
#					'.ShippingDetails.InternationalShippingServiceOption.ShippingService' => 'CustomCode',
#					'.ConvertedTransactionPrice._' => '15.95',
#					'.PayPalEmailAddress' => 'gsaleonline@yahoo.com',
#					'.ShippingDetails.InsuranceOption' => 'IncludedInShippingHandling',
#					'.ShippingDetails.PaymentEdited' => 'false',
#					'.ShippingDetails.InsuranceFee.currencyID' => 'USD',
#					'.ConvertedAdjustmentAmount.currencyID' => 'USD',
#					'.TransactionPrice.currencyID' => 'USD',
#					'.Buyer.Site' => 'US',
#					'.ShippingDetails.ShippingServiceOptions.ExpeditedService' => 'false',
#					'.CreatedDate' => '2009-05-23T03:31:30.000Z',
#					'.ShippingDetails.SalesTax.SalesTaxAmount.currencyID' => 'USD',
#					'.ShippingDetails.SalesTax.SalesTaxPercent' => '0.0',
#					'.ShippingDetails.InternationalShippingServiceOption.ShippingServiceCost.currencyID' => 'USD',
#					'.ShippingDetails.InternationalShippingServiceOption.ShippingServiceAdditionalCost.currencyID' => 'USD',
#					'.ShippingDetails.ShippingServiceOptions.ShippingTimeMin' => '2',
#					'.Buyer.UserIDLastChanged' => '1970-01-01T07:00:00.000Z',
#					'.IntangibleItem' => 'false',
#					'.ShippingDetails.TaxTable.TaxJurisdiction.JurisdictionID' => 'CA',
#					'.ShippingDetails.InternationalShippingServiceOption.ShippingServicePriority' => '2',
#					'.AmountPaid._' => '18.95',
#					'.ConvertedAdjustmentAmount._' => '0.0',
#					'.ConvertedTransactionPrice.currencyID' => 'USD',
#					'.Buyer.BuyerInfo.ShippingAddress.ExternalAddressID' => 'NY96GGTXU9T5J',
#					'.ShippingDetails.GetItFast' => 'false',
#					'.ShippingDetails.TaxTable.TaxJurisdiction.SalesTaxPercent' => '8.75',
#					'.BestOfferSale' => 'false',
#					'.ShippingDetails.ThirdPartyCheckout' => 'true',
#					'.Buyer.BuyerInfo.ShippingAddress.StateOrProvince' => 'KS',
#					'.Status.BuyerSelectedShipping' => 'false',
#					'.AmountPaid.currencyID' => 'USD',
#					'.ShippingServiceSelected.ShippingServiceCost.currencyID' => 'USD',
#					'.Buyer.eBayGoodStanding' => 'true',
#					'.Buyer.RegistrationDate' => '1998-09-24T16:50:20.000Z',
#					'.ShippingDetails.InternationalShippingServiceOption.ShipToLocation' => 'CA',
#					'.BuyerGuaranteePrice._' => '20000.0',
#					'.ShippingDetails.ShippingServiceOptions.ShippingTimeMax' => '5',
#					'.ShippingDetails.ShippingType' => 'Flat',
#					'.ConvertedAmountPaid._' => '18.95',
#					'.Buyer.PositiveFeedbackPercent' => '100.0',
#					'.Status.IntegratedMerchantCreditCardEnabled' => 'false',
#					'.Buyer.BuyerInfo.ShippingAddress.PostalCode' => '67206',
#					'.ShippingDetails.ChangePaymentInstructions' => 'true',
#					'.ConvertedAmountPaid.currencyID' => 'USD',
#					'.ShippingDetails.SalesTax.ShippingIncludedInTax' => 'false',
#					'.Buyer.FeedbackScore' => '4277',
#					'.ShippingDetails.ShippingServiceOptions.ShippingServiceCost.currencyID' => 'USD',
#					'.Buyer.UserIDChanged' => 'false',
#					'.Platform' => 'eBay',
#					'.Buyer.AboutMePage' => 'false',
#					'.ShippingDetails.ShippingServiceOptions.ShippingServiceAdditionalCost.currencyID' => 'USD',
#					'.Buyer.BuyerInfo.ShippingAddress.CityName' => 'WICHITA',
#					'.ShippingServiceSelected.ShippingInsuranceCost.currencyID' => 'USD',
#					'.ShippingDetails.ShippingServiceOptions.ShippingServiceCost._' => '3.0',
#					'.ShippingDetails.ShippingServiceOptions.ShippingService' => 'USPSFirstClass',
#					'.ShippingDetails.InsuranceFee._' => '0.0',
#					'.Buyer.IDVerified' => 'false',
#					'.Buyer.UserAnonymized' => 'false',
#					'.Buyer.Email' => 'a.bruchas@cox.net',
#					'.ShippingDetails.SellingManagerSalesRecordNumber' => '66284',
#					'.Buyer.BuyerInfo.ShippingAddress.CountryName' => 'United States',
#					'.Buyer.NewUser' => 'false'
#				};
#				
		
		# my $SKU = $item->{'.Item.SKU'};
		# my $PROD_NAME = $item->{'.Item.Title'};
		# my $PRICE = $tx->{'.TransactionPrice._'};
		#if (not defined $PRICE) { $PRICE = $tx->{'.ConvertedTransactionPrice._'}; }
		# my $QTY = $tx->{'.QuantityPurchased'};
		#my $WIN_EMAIL = $tx->{'.Buyer.Email'};
		#my $WIN_USER = $tx->{'.Buyer.UserID'};
		#my $WIN_EIAS = $tx->{'.Buyer.EIASToken'};
		#my $TRANSID = $tx->{'.TransactionID'};
		# my $EBAY_ID = $item->{'.Item.ItemID'};
		$data->{'BUYER_EMAIL'} = $tx->{'.Buyer.Email'};
		$data->{'BUYER_USERID'} = $tx->{'.Buyer.UserID'};
		$data->{'BUYER_EIAS'} =  $tx->{'.Buyer.EIASToken'};
		$data->{'SKU'} = $item->{'.Item.SKU'};
		$data->{'PRICE'} = $tx->{'.TransactionPrice._'};
		if (not defined $data->{'PRICE'}) { $data->{'PRICE'} = $tx->{'.ConvertedTransactionPrice._'}; }
		$data->{'QTY'} = $tx->{'.QuantityPurchased'};
		$data->{'PROD_NAME'} = $item->{'.Item.Title'};
		$data->{'MKT_LISTINGID'} =  $item->{'.Item.ItemID'};
		$data->{'MKT_TRANSACTIONID'} = $tx->{'.TransactionID'};
		if (defined $item->{'.Item.Site'}) {
			$data->{'SITE'} = $self->resolve_siteid($item->{'.Item.Site'});
			}
		elsif (defined $item->{'.Buyer.Site'}) {
			$data->{'SITE'} = $self->resolve_siteid($item->{'.Buyer.Site'});
			}
		$data->{'CHANNEL'} = $self->resolve_channel(OOID=>$item->{'.Item.ApplicationData'});
		}


	if (defined $data) {	
		($CLAIM) = $self->createClaim($data);
		#{
		#	'BUYER_EMAIL'=>$WIN_EMAIL,'BUYER_USERID'=>$WIN_USER,'BUYER_EIAS'=>$WIN_EIAS,
		#	'SKU'=>$SKU,'PRICE'=>$PRICE,'QTY'=>$QTY,'PROD_NAME'=>$PROD_NAME,
		#	'MKT_LISTINGID'=>$EBAY_ID, 'MKT_TRANSACTIONID'=>$TRANSID,
		#	'SITE'=>$SITE,
		#	'CHANNEL'=>$CHANNEL,});
		# ($CLAIM) = $listing->createClaim($WIN_EMAIL,$PRICE,$QTY,$TRANSID,$WIN_USER,$WIN_EIAS);
		}
	
	return($CLAIM);
	}


##
## returns the current ebay time, or if a time is passed, then that time in ebay format.
##
sub ebtime {
	my ($self,$t) = @_;
	if (not defined $t) { $t = time(); }
	return(POSIX::strftime("%Y-%m-%d %H:%M:%S", gmtime($t)));
	}

sub ebdatetime {
	my ($self,$t) = @_;
	if (not defined $t) { $t = time(); }
	## YYYY-MM-DDTHH:MM:SS.SSSZ
	return(POSIX::strftime("%Y-%m-%dT%H:%M:%SZ", gmtime($t)));
	}


##
## converts an ebay timestamp into a gmt
##
sub ebt2gmt {
	my ($self, $ebtime) = @_;
	require Date::Parse;
	return(Date::Parse::str2time($ebtime));
	}


##
## makes an API call.
##		options{xml} == 1		outputs .XML 
##		options{xml} == 2		no longer supported
##		options{xml} == 3 	simple xml format
##
##		options{debug} == 1
##			.DEBUG
##
sub api {
	my ($self, $VERB, $vars, %options) = @_;
#	use Data::Dumper;
#	print Dumper($self->username(),"EIAS:".$self->ebay_eias(),$vars,%options);
	
	my $credential = '';
	if ($options{'NO_TOKEN'}) {}
	elsif ($self->ebay_eias() ne '') { $credential = "EIAS:".$self->ebay_eias(); }
	elsif ($self->ebay_token() ne '') { $credential = "TOKEN:".$self->ebay_token(); }

	## print STDERR "CREDENTIAL: $credential\n";

	# my $r = &EBAY2::doRequest($self->username(),$credential,$VERB,$vars,%options,EBAY2=>$self);

	## preserve keys is a list of keys e.g. CategoryArray which are heirarchical and should be preserved.
	my %preservekeys = ();
	if ($options{'preservekeys'}) { foreach (@{$options{'preservekeys'}}) { $preservekeys{$_}++; } }

	my @ERRORS = ();
	my @WARNINGS = ();
	my $XML = '';

	my $agent = LWP::UserAgent->new('agent'=>'Groovy-Zoovy/1.0'); 
	if ($VERB eq '') { 
		push @ERRORS, { err=>'ZEBAY.100', msg=>'Verb was not passed to doRequest' }; 
		}

	if ($EBAY2::compatibility<741) {
		## minimum compat level 625 @ 7/20/09
		## bumped compat level to 741 @ 10/11/11
		$EBAY2::compatibility = 741;
		}
	# $EBAY2::compatibility = 700;

	my ($USERNAME) = $self->username();
	## print STDERR "BLAH! USERNAME:[$USERNAME]\n";

	my ($TOKEN,$SANDBOX,$EIAS) = ();
	if ($options{'NO_TOKEN'}) {
		$SANDBOX = 0;
		}
	else {
		($TOKEN,$SANDBOX,$EIAS) = ($self->ebay_token(),$self->is_sandbox(),$self->ebay_eias());
		}

	my ($CFG) = CFG->new();
	if ((not defined $TOKEN) && (not $options{'NO_TOKEN'})) { 
		print STDERR "MISSING TOKEN: $TOKEN SB: $SANDBOX\n";  
		}
	elsif ($SANDBOX) { 
		print STDERR "LOAD SANDBOX\n";
		$EBAY2::session_certificate = $CFG->get("ebay_sandbox","session_certificate") || "";
		$EBAY2::developer_name = $CFG->get("ebay_sandbox","developer_name") || "";
		$EBAY2::application_name = $CFG->get("ebay_sandbox","application_name") || "";
		$EBAY2::certificate_name = $CFG->get("ebay_sandbox","certificate_name") || "";
		$EBAY2::runame = $CFG->get("ebay_sandbox","runame") || "";
		}
	else { 
		if ($::DEBUG) {  print STDERR "LOAD PRODUCTION!\n"; }
		$EBAY2::session_certificate = $CFG->get("ebay","session_certificate") || "";
		$EBAY2::developer_name = $CFG->get("ebay","developer_name") || "";
		$EBAY2::application_name = $CFG->get("ebay","application_name") || "";
		$EBAY2::certificate_name = $CFG->get("ebay","certificate_name") || "";
		$EBAY2::runame = $CFG->get("ebay","runame") || "";
		}
	
	## print STDERR "APPNAME: $EBAY2::application_name\n";
	my $SITE = $vars->{'#Site'}; 
	delete $vars->{'#Site'};
	$vars->{'#Verb'} = $VERB.'Request';
	$vars->{'~xmlns'} = 'urn:ebay:apis:eBLBaseComponents';
	if ($options{'NO_TOKEN'}) {
		}
	else {
		$vars->{'RequesterCredentials.eBayAuthToken'} = $TOKEN; 
		}

	my %result = ();

 	if (scalar(@ERRORS)>0) {
 		## already took errors!
 		}
	else {
		if ($SITE eq '') { $SITE = 0; push @WARNINGS, 'SITE ID was not passed - default to 0'; }


		my $header = HTTP::Headers->new;
		$header->push_header('X-EBAY-API-COMPATIBILITY-LEVEL' => $EBAY2::compatibility);
		$header->push_header('X-EBAY-API-SESSION-CERTIFICATE' => $EBAY2::session_certificate);
		$header->push_header('X-EBAY-API-DEV-NAME'=>$EBAY2::developer_name);
		$header->push_header('X-EBAY-API-APP-NAME'=>$EBAY2::application_name);
		$header->push_header('X-EBAY-API-CERT-NAME'=>$EBAY2::certificate_name);
		$header->push_header('X-EBAY-API-CALL-NAME'=>$VERB);
		$header->push_header('X-EBAY-API-SITEID'=>$SITE);
		$header->push_header('Content-Type' => 'text/xml');

		my $body = &XMLTOOLS::buildTree($vars->{'#Verb'},$vars);
	

		my $URL = 'https://api.ebay.com/ws/api.dll';
		if ($SANDBOX) { $URL = 'https://api.sandbox.ebay.com/ws/api.dll'; }

		open F, ">/dev/shm/ebay.xml";
		print F $body;
		close F;

		my $request = HTTP::Request->new("POST", $URL,$header, $body); 
		my $response = $agent->request($request); 
	
#		print "RESPONSE: ".Dumper($response)."\n";
#		open Fqq, ">/tmp/log.$USERNAME";
#		# print Fq $header."\n\n";
#		print Fqq Dumper($request);
#		print Fqq $body."\n\n";
#		print Fqq $response->content();
#		close Fqq;
#		##	 perl -e 'use lib "/backend/lib"; use XML::Parser;  $p1 = new XML::Parser(Style =>"Debug"); $p1->parsefile("/tmp/log.dovikutoff");'
		open F, ">>/dev/shm/ebay.xml";
		print F Dumper($response);
		close F;

		if ($response->is_error()) { 
			## we got some nasty http response
			push @ERRORS, { 'id'=>"HTTP:".$response->code, 'msg'=>$response->status_line(), 'detail'=>$response->error_as_HTML };
			}

		if (scalar(@ERRORS)>0) {
			}
		elsif (defined $options{'xml'}) { 
			$result{'.XML'} = $response->content(); 
			}

		if (scalar(@ERRORS)>0) {
			}
		elsif ($options{'xml'} == 2) {
			## xml ==2 means do not attempt to process.
			die("no longer supported");
			}
		elsif ($options{'xml'} == 3) {
			## in xml==3 we parse the xml
			require XML::Simple;
			my $xs = new XML::Simple();
  		 	my ($r) = $xs->XMLin($result{'.XML'},ForceArray=>1,ContentKey=>'_');
			$result{'.'} = $r;

			if ($r->{'Ack'} ne 'Success') {
				## note: Ack could be Warning, or !??!
 
				foreach my $ref (@{$r->{'.'}->{'Errors'}}) {
					my $sref = &ZTOOLKIT::XMLUTIL::SXMLflatten($ref);
				  # $sref {
				  #	 '.ErrorClassification' => 'RequestError',
				  #	 '.ErrorParameters.Value' => 'STD35:0101:A005',
		  		  #	 '.ShortMessage' => 'Variations with quantity \'0\' will be removed.',
		  		  #	 '.LongMessage' => 'Variations with quantity \'0\' will be removed.',
	 			  #	 '.ErrorParameters.ParamID' => '0',
				  #	 '.SeverityCode' => 'Warning',
				  #	 '.ErrorCode' => '21916620'
		 		  #  }
					if ($sref->{'.SeverityCode'} eq 'Warning') {
						push @WARNINGS, $sref;
						}
					else {
						push @ERRORS, $sref;
						}
					}
				}

			}
		}

	# print STDERR 'ERRORS: '.Dumper(\@ERRORS);
	if (scalar(@ERRORS)==0) {
		# print STDERR "XML: $options{'xml'} USER: $USERNAME\n";
		if ($options{'NO_DB'}) {
			## no database here
			}
		elsif ($options{'xml'}==2) {
			# no errors are set on xml==2
			}
		elsif ($USERNAME ne '') {
			my ($udbh) = &DBINFO::db_user_connect($USERNAME);
			my $qtEIAS = $udbh->quote($EIAS);
			my ($MID) = &ZOOVY::resolve_mid($USERNAME);
			my $pstmt = "update EBAY_TOKENS set ERRORS=0 where MID=$MID /* $USERNAME */ and EBAY_EIAS=$qtEIAS";
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			&DBINFO::db_user_close();
			}
		else {
			print Dumper(\@ERRORS);
			die();
			}
		}		
	elsif ($ERRORS[0]->{'ErrorCode'}==932) {
		##  'ShortMessage' => 'Auth token is hard expired.',
		$result{'.CRITICAL'}++;			
		}
	elsif ($ERRORS[0]->{'ErrorCode'}==-1) {
		##  'ShortMessage' => 'Auth token is hard expired.',
		$result{'.CRITICAL'}++;			
		}
			
	$result{'.ERRORS'} = \@ERRORS;
	$result{'.WARNINGS'} = \@WARNINGS;

	return(\%result);
	}

##
## 
##
#sub listing {
#	my ($self, %params) = @_;
#
#	my ($listing) = EBAY2::LISTING->new('*PARENT'=>$self,%params);
#	$listing->{'*PARENT'} = $self;
#
#	return($listing);	
#	}


##
##
##
sub ftsupload {
	my ($self,$OPERATION,$xmlhashes) = @_;

	if (ref($xmlhashes) ne 'ARRAY') {
		die("xmlhashes gotta be an array.");
		}

	## Phase1: upload a createUploadJobRequest to ebay.
	my ($fileid,$jobid) = (0,0);
	my ($UUID,$result) = $self->bdesapi('createUploadJob',{'fileType'=>'XML','uploadJobType'=>$OPERATION},output=>'flat');
	# print Dumper($result);

	if ($UUID eq '') {
		die("had bad error (blank UUID), need to handle this.");
		}
	elsif ($result->{'.ack'} eq 'Success') {
		$fileid = $result->{'.fileReferenceId'};
		$jobid = $result->{'.jobId'};
		}
	elsif (($result->{'.ack'} eq 'Failure') && ($result->{'.errorMessage.error.errorId'}==7)) {
		# Maximum of one job per job-type in non-terminated state is allowed
		$fileid = -1;
		$jobid = -1;
		#my ($xUUID,$xresult) = $self->bdesapi('getJobs',{
		#	'jobType'=>$OPERATION,
		#	'1*'=>'<jobStatus>Created</jobStatus>',
		#	#'2*'=>'<jobStatus>Failed</jobStatus>',
		#	#'3*'=>'<jobStatus>InProcess</jobStatus>',
		#	},output=>'flat');

		my ($xUUID,$xresult) = $self->bdesapi('getJobs',{'jobType'=>$OPERATION,'jobStatus'=>'Created'},output=>'flat');
		if (not defined $xresult->{'.jobProfile.jobId'}) {
			($xUUID,$xresult) = $self->bdesapi('getJobs',{'jobType'=>$OPERATION,'jobStatus'=>'Aborted'},output=>'flat');
			}
		if (not defined $xresult->{'.jobProfile.jobId'}) {
			($xUUID,$xresult) = $self->bdesapi('getJobs',{'jobType'=>$OPERATION,'jobStatus'=>'InProcess'},output=>'flat');
			}
		if (not defined $xresult->{'.jobProfile.jobId'}) {
			($xUUID,$xresult) = $self->bdesapi('getJobs',{'jobType'=>$OPERATION,'jobStatus'=>'Scheduled'},output=>'flat');
			if ((defined $xresult->{'.jobProfile.jobId'}) && ($OPERATION eq 'OrderAck')) {
				warn "Aborting OrderAck job";
				($xUUID,$xresult) = $self->bdesapi('abortJob',{'jobId'=>$xresult->{'.jobProfile.jobId'}},output=>'flat');
				}
			}
		if (not defined $xresult->{'.jobProfile.jobId'}) {
			($xUUID,$xresult) = $self->bdesapi('getJobs',{'jobType'=>$OPERATION,'jobStatus'=>'Failed'},output=>'flat');
			}
		if ( $self->ebt2gmt($xresult->{'.jobProfile.creationTime'}) < time()-(15*60) ) {
			print 'Killin .. '.Dumper($xUUID,$xresult);
			# $self->log("WARN","Recovered $OPERATION job file=$fileid/jobid=$jobid");
			($fileid) = $xresult->{'.jobProfile.inputFileReferenceId'};
			($jobid) = $xresult->{'.jobProfile.jobId'};
			}
		else {
			($UUID,$result) = ('',"we'll need to retry, got duplicate job issue");
			}
		if ($jobid == 0) {
			warn "Bogus response from getJobs\n";
			}
		}
	else {
		## unknown .ack status.
		Carp::confess("shit. shit shit.");
		}

	print STDERR "REFERENCE: $fileid\n";


	## example of the bodyxml:
	#<ReviseInventoryStatusRequest xmlns="urn:ebay:apis:eBLBaseComponents">
	# <InventoryStatus>
	#	<ItemID>330001291447</ItemID>
	#	<StartPrice>190.00</StartPrice>
	#	<Quantity>15</Quantity>
	# </InventoryStatus>
	#</ReviseInventoryStatusRequest>

	## FileTransferService
	if ($fileid>0) {
		my $bxml = qq~<?xml version="1.0" encoding="UTF-8"?>\n~;
		$bxml .= qq~<BulkDataExchangeRequests>~;
		$bxml .= qq~<Header><SiteID>0</SiteID><Version>675</Version></Header>\n~;
		foreach my $xmlhash (@{$xmlhashes}) {
			$xmlhash->{'#Verb'} = $OPERATION."Request";
			$xmlhash->{'~xmlns'} =  "urn:ebay:apis:eBLBaseComponents";
			## use buildTree level1 to ensure we don't have multiple xml item declarations
			$bxml .= &XMLTOOLS::buildTree($xmlhash->{'#Verb'},$xmlhash,1);	# bodyxml
			}
		$bxml .= qq~</BulkDataExchangeRequests>\n~;

		open F, ">/tmp/bxml.$OPERATION";
		print F $bxml;
		close F;

		my $gbxml = Compress::Zlib::memGzip($bxml);
		my ($msg) = MIME::Base64::encode_base64($gbxml);
		my $len = length($msg);
	
		$OPERATION = 'uploadFile';
		my $upxml = qq~<?xml version="1.0" encoding="utf-8"?>
<uploadFileRequest xmlns="http://www.ebay.com/marketplace/services">
<fileAttachment>
<Data>$msg</Data>
<Size>$len</Size>
</fileAttachment>
<fileFormat>gzip</fileFormat>
<fileReferenceId>$fileid</fileReferenceId>
<taskReferenceId>$jobid</taskReferenceId>
</uploadFileRequest>
~;

		my $ua = LWP::UserAgent->new;
		$ua->timeout(10);
		my $h = HTTP::Headers->new();
	
		$h->header('X-EBAY-SOA-OPERATION-NAME',$OPERATION);
		$h->header('X-EBAY-SOA-SECURITY-TOKEN',$self->ebay_token());
		$h->header('X-EBAY-SOA-SERVICE-NAME','FileTransferService');
		$h->header('X-EBAY-SOA-REQUEST-DATA-FORMAT','XML');
		$h->header('X-EBAY-SOA-RESPONSE-DATA-FORMAT','XML');
		my $URL = 'https://storage.ebay.com/FileTransferService';
		my $req = HTTP::Request->new('POST',$URL,$h,$upxml);

		# She sends a Bulk Data Exchange startDownloadJob request with the ActiveInventoryReport parameter
		my $response = $ua->request($req);
	
		my $xml = '';
		if ($response->is_success()) {
			$xml = $response->content();
			}

		
		my $xref = undef;
		if ($xml ne '') {
			my ($item) = XML::Simple::XMLin($xml,ForceArray=>1,ContentKey=>'_');
			$xref = &ZTOOLKIT::XMLUTIL::SXMLflatten($item);
			}
		
		my ($ok) = 0;
		if (not defined $xref) {
			ZOOVY::confess($self->username(),$response->as_html());
			}
		elsif ($xref->{'.errorMessage.error.errorId'} == 13) {
			$ok++;
			}
		elsif ($xref->{'.errorMessage.error.errorId'} == 14) {
			# The File UPload is already in progress (so we'll assume somebody else will ack it)
			warn "the file is already being uploaded";
			$ok = 0;	
			}
		elsif ($xref->{'.ack'} eq 'Success') {
			$ok++;
			}
		else {
			ZOOVY::confess($self->username(),Dumper($response));
			}

		# my @parts = $response->parts();

		#require IO::Scalar;
		#print Dumper(@parts);
		#my $data = $parts[1]->decoded_content();
		#my $SH = new IO::Scalar \$data;
		#$SH->seek(0);
		
		#open F, ">/tmp/foo.zip"; print F $data; close F;
		## my $SH = new IO::Scalar \$data;
		#use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
		#my $zip = Archive::Zip->new();
		#$zip->read("/tmp/foo.zip");
		## $zip->readFromFileHandle($SH);	
		#my @members = $zip->members();
		## print Dumper(@members);
		#my $xml = '';
		#foreach my $member ($zip->members()) {
		#	$xml .= $member->contents();
		#	# print Dumper($member->filename(),$zip->extractMember($member));
		#	}
		#
		if ($ok) {
			my ($UUID,$result) = $self->bdesapi('startUploadJob',{jobId=>$jobid});
			}
		else {
			warn "could not startUploadJob (was not ok)\n";
			}
		}
	else {
		warn "fileid was zero\n";
		}

	return($UUID,$result);
	}


##
##
##
sub ftsdownload {
	my ($self, $jobid, $fileid) = @_;

	my $OPERATION = 'downloadFile';
	my $xml = qq~<?xml version="1.0" encoding="utf-8"?>
<downloadFileRequest xmlns="http://www.ebay.com/marketplace/services">
  <fileReferenceId>$fileid</fileReferenceId>
  <taskReferenceId>$jobid</taskReferenceId>
</downloadFileRequest>
~;

	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	my $h = HTTP::Headers->new();

	$h->header('X-EBAY-SOA-OPERATION-NAME',$OPERATION);
	$h->header('X-EBAY-SOA-SECURITY-TOKEN',$self->ebay_token());
	$h->header('X-EBAY-SOA-SERVICE-NAME','FileTransferService');
	$h->header('X-EBAY-SOA-REQUEST-DATA-FORMAT','XML');
	$h->header('X-EBAY-SOA-RESPONSE-DATA-FORMAT','XML');
	my $URL = 'https://storage.ebay.com/FileTransferService';
	if ($self->is_sandbox()) {
		$URL = 'https://storage.sandbox.ebay.com/FileTransferService';
		}
	my $req = HTTP::Request->new('POST',$URL,$h,$xml);
	# She sends a Bulk Data Exchange startDownloadJob request with the ActiveInventoryReport parameter
	#print STDERR "in EBAY2::ftsdownload, starting a file transfer, $jobid, $fileid\n";
	my $response = $ua->request($req);
	#print STDERR "in EBAY2::ftsdownload, file transfer finished, processing... $jobid, $fileid\n";
	use Data::Dumper;

	my $ERROR = undef;
	my @parts = ();
	if ($response->is_success()) {
		@parts = $response->parts();
		}
	else {
		$ERROR = "ftsdownload(job:$jobid,file:$fileid) got response->is_failure()";
		}

	my $rx = {};
	if (scalar(@parts)>0) {
		require XML::Simple;
		my $xs = new XML::Simple();
		my $xml = $parts[0]->decoded_content();
		## note: ebay leaves stupid --MIMEBoundaryurn_uuid_DDCFA29B5D2D979058129856613287120445-- at the end of xml
		$xml =~ s/--(.*?)--[\n\r]*$//gs;

		print Dumper($xml);
	 	my ($rxx) = $xs->XMLin($xml,ForceArray=>1,ContentKey=>'_');
		$rx = &ZTOOLKIT::XMLUTIL::SXMLflatten($rxx);
		#$VAR1 = {
		#	 '.errorMessage.error.domain' => 'Marketplace',
		#	 '.xmlns' => 'http://www.ebay.com/marketplace/services',
		#	 '.version' => '1.1.0',
		#	 '.ack' => 'Failure',
		#	 '.errorMessage.error.errorId' => '20',
		#	 '.errorMessage.error.message' => 'The task reference id does not belong to this user',
		#	 '.timestamp' => '2011-02-24T16:54:45.676Z',
		#	 '.errorMessage.error.subdomain' => 'FileTransfer',
		#	 '.errorMessage.error.severity' => 'Error',
		#	 '.errorMessage.error.category' => 'Application'
		#  };
		if ($rx->{'.ack'} eq 'Failure') {
			$ERROR = sprintf("eBay.%s.%s.%s[%d]:%s",
				$rx->{'.errorMessage.error.category'},
				$rx->{'.errorMessage.error.subdomain'},
				$rx->{'.errorMessage.error.severity'},
				$rx->{'.errorMessage.error.errorId'},
				$rx->{'.errorMessage.error.message'}
				);
			}
		}


	if (defined $ERROR) {
		## error already happened
		}
	elsif (scalar(@parts)<2) {
		# print Dumper(\@parts);
		$ERROR = sprintf("eb2->ftsdownload error\ninput was: %s\nnot enough parts: %s",$xml,$parts[0]->decoded_content());
		}


	if (not defined $ERROR) {
		require IO::Scalar;
		#print Dumper(\@parts);

		my $data = $parts[1]->decoded_content();
		#my $SH = new IO::Scalar \$data;
		#$SH->seek(0);
	
		my $FILE = sprintf("/tmp/fts-%s-%d.zip",$self->username(),time());
		if ($data =~ /^Internal server error\. Please check the server logs for details/) {
			return("eBay Returned:$data",undef);
			}

		open F, ">$FILE"; print F $data; close F;
		# my $SH = new IO::Scalar \$data;
		use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
		my $zip = Archive::Zip->new();
		$zip->read("$FILE");
		# $zip->readFromFileHandle($SH);	
		my @members = $zip->members();
		# print Dumper(@members);
		foreach my $member ($zip->members()) {
			return(undef,$member->contents());
			# print Dumper($member->filename(),$zip->extractMember($member));
			}
		unlink $FILE;
		}

	return($ERROR,'');
	}





##
## BulkDataExchangeService API
##
##	input: %options = output=>flat
##
## returns a UUID + simple xml ref
##		OR ON ERROR:
##		'',ERRRO
##
sub bdesapi {
	my ($self,$OPERATION,$xmlhash,%options) = @_;

	if (not $xmlhash->{'UUID'}) {
		my ($guid) = Data::GUID->new()->as_string();	
		$xmlhash->{'UUID'} = $guid;
		}
	my $lm = $options{'*LM'};
	
	$xmlhash->{'#Verb'} = $OPERATION."Request";
	$xmlhash->{'~xmlns'} =  "http://www.ebay.com/marketplace/services";
	my ($xml) = &XMLTOOLS::buildTree($xmlhash->{'#Verb'},$xmlhash);

	print "XML: $xml\n";

#	my $xml = qq~<?xml version="1.0" encoding="utf-8"?><startDownloadJobRequest xmlns="http://www.ebay.com/marketplace/services">
#<downloadJobType>SoldReport</downloadJobType><UUID>$^T</UUID></startDownloadJobRequest>~;

	my $attempts = 0;
	my $success = 0;
	my $response = undef;
	
	my $ua = LWP::UserAgent->new;
	$ua->timeout(300);	## note: 12/22/11 - this was raised from 10 to 300 to prevent 500 ssl read timeout issues

	while ( ($attempts++<3) && (not $success) ) {
		my $h = HTTP::Headers->new();

		## BulkDataExchangeService
		$h->header('X-EBAY-SOA-OPERATION-NAME',$OPERATION);
		$h->header('X-EBAY-SOA-SECURITY-TOKEN',$self->ebay_token());
		$h->header('X-EBAY-SOA-SERVICE-NAME','BulkDataExchangeService');
		$h->header('X-EBAY-SOA-REQUEST-DATA-FORMAT','XML');
		$h->header('X-EBAY-SOA-RESPONSE-DATA-FORMAT','XML');
		my $URL = 'https://webservices.ebay.com/BulkDataExchangeService';
		if ($self->is_sandbox()) {
			$URL = 'https://webservices.sandbox.ebay.com/BulkDataExchangeService';
			}

		my ($t) = time();
		print "$URL $OPERATION\n";
		# $ua->proxy(["http", "https"], "http://75.101.135.209:8080");
		my $req = HTTP::Request->new('POST',$URL,$h,$xml);
		# She sends a Bulk Data Exchange startDownloadJob request with the ActiveInventoryReport parameter
		$response = $ua->request($req);
		open F, ">/dev/shm/ebay.bdesapi.debug";
		print F Dumper($response);
		close F;
		print sprintf("TOOK: %d seconds.\n",time()-$t);

		if ($response->is_success()) {
			$success++;
			}
		else {
			print "Retry attempt $attempts/3 error: ".$response->status_line()."\n";
			if ((defined $lm) && ($attempts>=3)) {
				$lm->pooshmsg(sprintf("ISE|+eBay servers returned HTTP:",$response->status_line()));
				}
			}
		}
	

	# print Dumper($response);
	#print "!!!! Look Mr. Caterpillar - eb2->bdesapi $OPERATION said: \n";
	#print Dumper($response)."\n\n";

	my $UUID = $xmlhash->{'UUID'};
	my $result = undef;

	if ((not $response->is_success()) && ($response->content() !~ /^\<\?xml/)) {
		## handle xml errors.
		($UUID,$result) = ('',"Protocol Error: ".$response->status_line());
		if (defined $lm) { $lm->pooshmsg("ISE|+eBay sent Non XML response: ".$response->status_line()); }
		}
	else {
		$result = XML::Simple::XMLin($response->content(),ForceArray=>1);
		}


	if (ref($result) ne 'HASH') {
		## this already happened.
		}
	elsif (defined $result->{'error'}) {
		my $flat = &ZTOOLKIT::XMLUTIL::SXMLflatten($result);

		if ($flat->{'.error.errorId'} == 11002) {
			## hard expired token
			my ($edbh) = &DBINFO::db_user_connect($self->username()); 
			my $pstmt = "update EBAY_TOKENS set ERRORS=10000 where EBAY_EIAS=".$edbh->quote($self->ebay_eias());
			$edbh->do($pstmt);
			&ZOOVY::confess($self->username(),"eBay token has hard expired, and was removed from account.\n".Dumper($result,$flat),justkidding=>1);
			&DBINFO::db_user_close();	
			if (defined $lm) { 
				$lm->pooshmsg(sprintf("WARN|+handled exception[%d] %s",$flat->{'.error.errorId'},$flat->{'.error.message'})); 
				}
			($UUID,$result) = (-1,'');
			}
		elsif ($flat->{'.error.category'} eq 'System') {
			## system level error.
			($UUID,$result) = ('',sprintf("ebay%d: %s",$flat->{'.error.errorId'},$flat->{'.error.message'}));
			if (defined $lm) { $lm->pooshmsg("ISE|+$result"); }
			}
		elsif (defined $lm) {
			## we don't want a confession, just set $lm with an ISE
			if (defined $lm) { $lm->pooshmsg("ISE|+Unknown error: ".Dumper($flat)); }
			}
		else {
			ZOOVY::confess($self->username(),"Unknown error: ".Dumper($flat));
			}
		print Dumper($result);
		}
	else {
		if ($options{'output'} eq 'flat') {
			$result = &ZTOOLKIT::XMLUTIL::SXMLflatten($result);
			}
		}

	return($UUID,$result);
	}



##
##
##
sub GetSellerTransactions {
	my ($self, $LASTTRANS) = @_;

	# Type 7 = store queue
	# Type 9 = auction queue

	my $edbh = &DBINFO::db_user_connect($self->username());
	my $agent = LWP::UserAgent->new(timeout => 60);

	my %hash = ();
	$hash{'#Site'} = "0";
	$hash{'DetailLevel'} = 'ReturnAll';

	# we need to determine the last processed time.
	if ($LASTTRANS < time()-(86400*15)) { $LASTTRANS = (time()-(86400*15)); }
	# $LASTTRANS = $LASTTRANS - 86400;

	my $NOW = time()-1;
	# if ($NOW>$LASTTRANS+86400) { $NOW = $LASTTRANS+86400; }
	
	$hash{'ModTimeFrom'} = $self->ebtime($LASTTRANS);
	my $CHECKTIME = time()-$::EBAY_DELAY;	# this tracks the last time we fetched.
	$hash{'ModTimeTo'} = $self->ebtime($NOW); 	# always get current! (should be $CHECKTIME)
	

	print "START: ".$self->ebtime($LASTTRANS)."\n";
	print "END  : ".$self->ebtime($NOW)."\n";

	$hash{'Pagination.EntriesPerPage'} = 100;

	# use Data::Dumper;
	# print STDERR Dumper(\%hash);

	my $transactionsprocessed = 0;

	my $PAGES = 0;
	my $pagenum = 0;
	my $TIMENOW = 0;
	my $allDone = 0;
	do {
		$hash{'Pagination.PageNumber'} = ++$pagenum;
		print STDERR "Doing page $pagenum\n";

		my ($r) = $self->api('GetSellerTransactions',\%hash,preservekeys=>['TransactionArray'],xml=>3);
		if ($TIMENOW == 0) { $TIMENOW = $self->ebt2gmt($r->{'Timsetamp'})-$::EBAY_DELAY;  }

		if (defined $r->{'.'}->{'TransactionArray'}) {
			foreach my $txnref (@{$r->{'.'}->{'TransactionArray'}}) {
				## see: SAMPLE-GetSellerTransactions-TranasctionArray-Transaction.dmp
				my $txn = &ZTOOLKIT::XMLUTIL::SXMLflatten($txnref->{'Transaction'}->[0]);
				my $EBAY_ID = $txnref->{'.Item.ItemID'};
				# my ($listing) = $self->listing(listingid=>$EBAY_ID);
				my ($claim) = $self->recordSale('%txn'=>$txn);
				$transactionsprocessed++;
				print Dumper($txn);
				}
			}

		# use Data::Dumper; print Dumper($r);
		$allDone = ($r->{'.'}->{'HasMoreTransactions'}->[0] ne 'true');

		if (
			($r->{'.'}->{'TransactionsPerPage'}->[0] <= $r->{'.'}->{'ReturnedTransactionCountActual'}->[0]) 
			||
			($r->{'.'}->{'HasMoreTransactions'}->[0] eq 'true')
			) {
			# Apparently we're mushrooms: ebay won't tell us how many pages, only that there is one more.
			$PAGES = $r->{'.'}->{'PageNumber'}++; 		
			}
		}		# end of do until loop
	until ($allDone);
	# until ($pagenum++>=$PAGES);
	
	if ($transactionsprocessed) {
		my ($MID) = $self->mid();
		my ($USERNAME) = $self->username();
		my $pstmt = "update EBAY_TOKENS set LAST_TRANSACTIONS_GMT=$NOW where EBAY_EIAS=".$edbh->quote($self->ebay_eias())." and MID=$MID /* $USERNAME */ limit 1";
		print STDERR $pstmt."\n";
		$edbh->do($pstmt);
		}
	else {
		print STDERR "No transactions processed.\n";
		}

	&DBINFO::db_user_close();	

	}



##
##
##
sub GetSellerList {
	my ($self, %options) = @_;

	# Type 7 = store queue
	# Type 9 = auction queue

	my $edbh = &DBINFO::db_user_connect($self->username());
	my $agent = LWP::UserAgent->new(timeout => 60);
	my @RESULTS = ();

	my %hash = ();
	$hash{'#Site'} = "0";
	$hash{'DetailLevel'} = 'ReturnAll';
	$hash{'OutputSelector'} = 'ItemArray.Item.UUID,ItemArray.Item.ItemID,ItemArray.Item.ListingDetails.EndTime';
#	$hash{'OutputSelector'} = 'Item.BuyItNowPrice';
#	$hash{'OutputSelector'} = 'Item.ListingDetails.ViewItemURL';
	

	# we need to determine the last processed time.
	my $LASTTRANS = int($options{'STARTED_GMT'});
	if ($LASTTRANS < time()-(86400*15)) { $LASTTRANS = (time()-(86400*15)); }
	# $LASTTRANS = $LASTTRANS - 86400;

	my $NOW = time()-1;
	# if ($NOW>$LASTTRANS+86400) { $NOW = $LASTTRANS+86400; }
	
	$hash{'StartTimeFrom'} = $self->ebtime($LASTTRANS);
	my $CHECKTIME = time()-$::EBAY_DELAY;	# this tracks the last time we fetched.
	$hash{'StartTimeTo'} = $self->ebtime($NOW); 	# always get current! (should be $CHECKTIME)

	if ($options{'SKU'}) {
		$hash{'SKUArray.SKU'} = $options{'SKU'};
		}

#	print "START: ".$self->ebtime($LASTTRANS)."\n";
#	print "END  : ".$self->ebtime($NOW)."\n";

	$hash{'Pagination.EntriesPerPage'} = 200;

	# use Data::Dumper;
	# print STDERR Dumper(\%hash);

	my $transactionsprocessed = 0;

	my $PAGES = 0;
	my $pagenum = 0;
	my $TIMENOW = 0;
	my $allDone = 0;
	do {
		$hash{'Pagination.PageNumber'} = ++$pagenum;
		print STDERR "Doing page $pagenum\n";

		my ($r) = $self->api('GetSellerList',\%hash,preservekeys=>['ItemArray'],xml=>3);
		# print Dumper($r);
		if ($TIMENOW == 0) { $TIMENOW = $self->ebt2gmt($r->{'Timsetamp'})-$::EBAY_DELAY;  }

		my $found = 0;
		if (defined $r->{'.'}->{'ItemArray'}) {
			foreach my $itemref (@{$r->{'.'}->{'ItemArray'}->[0]->{'Item'}}) {
				## see: SAMPLE-GetSellerTransactions-TranasctionArray-Transaction.dmp
				my $i = &ZTOOLKIT::XMLUTIL::SXMLflatten($itemref);
				push @RESULTS, $i;
				$found++;
				}
			}

		# use Data::Dumper; print Dumper($r);
		$allDone = ($hash{'Pagination.EntriesPerPage'} > $found)?1:0;
		# $allDone = 1;
		}		# end of do until loop
	until ($allDone);
	# until ($pagenum++>=$PAGES);
	
	&DBINFO::db_user_close();	
	return(\@RESULTS);
	}


##
## performs an ebay GetItem call 
##
sub GetItem {
	my ($self,$EBAY_ID,$SKU) = @_;

	my %hash = ();
	if ($EBAY_ID>0) {
		$hash{'ItemID'} = $EBAY_ID;
		}
	if ($SKU ne '') {
		$hash{'SKU'} = $SKU;
		}

	if ((not defined $hash{'ItemID'}) && (not defined $hash{'SKU'})) {
		&ZOOVY::confess($self->username(),"eBay GetItem Never had a chance (no SKU or ItemID)",just_kidding=>1);
		}

	my ($r) = $self->api('GetItem',\%hash,preservekeys=>['Item'],xml=>3);
	my $node = undef;
	if ($r->{'Ack'} eq 'Failure') {
		## possible failure reasons? 
		if ($r->{'.ERRORS'}->[0]->{'ErrorCode'}==17) {
			# 'Item "5965026088" is invalid, not activated, or no longer in our database, or an Live Auction item.',
			$node = $r->{'.ERRORS'}->[0]; 
			}
		}	
	else {
		require ZTOOLKIT::XMLUTIL;
		$node = &ZTOOLKIT::XMLUTIL::SXMLflatten($r->{'.'});
		}

	if ($node->{'.Item.TimeLeft'} eq 'PT0S') {
		$node->{'_is_over'}++;
		}	
	if ($node->{'.Item.ListingDetails.EndTime'}) {
		$node->{'_ends_gmt'} = $self->ebt2gmt($node->{'.Item.ListingDetails.EndTime'});
		}
	print STDERR Dumper($node);

	return($node);
	}



##
##
##
sub kill_items {
	my ($self,%params) = @_;

	my $edbh = &DBINFO::db_user_connect($self->username());
	my ($MID) = $self->mid();
	my ($USERNAME) = $self->username();
	
	my @SETS = ();
	if (defined $params{'CHANNEL'}) {
		my $qtCHANNEL = int($params{'CHANNEL'});
		my $pstmt = "select EBAY_ID,PRODUCT from EBAY_LISTINGS where MID=$MID and CHANNEL=$qtCHANNEL";
		my $sth = $edbh->prepare($pstmt);
		$sth->execute();
		while ( my ($EBAY_ID,$PRODUCT) = $sth->fetchrow() ) {
			push @SETS, sprintf("%d|%s",$EBAY_ID,$PRODUCT);
			}
		$sth->finish();
		}
	elsif (defined $params{'EBAY_ID'}) {
		push @SETS, int($params{'EBAY_ID'});
		}
	else {
		die("Unknown parameters passed to kill_items");
		}


	## @SETS is an array of pipe separated EBAY_ID|PRODUCTID
	my $IS_ENDED = 83;	## IS_ENDED reason 83 is "Unknown"
	if ($params{'IS_ENDED'}) { $IS_ENDED = int($params{'IS_ENDED'}); }
	my $qtREASON = $edbh->quote(sprintf("%s",($params{'REASON'})?$params{'REASON'}:join(";",caller(0))));

	foreach my $SET (@SETS) {
		my ($EBAY_ID,$SKU) = split(/\|/,$SET,2);

		my $result = $self->api('EndItem',{ ItemID=>$EBAY_ID, EndingReason=>'NotAvailable' },xml=>3);
		## we should REALLY check for a success here.
		print STDERR Dumper($result);

		my $pstmt = "update EBAY_LISTINGS set RESULT=$qtREASON,IS_ENDED=$IS_ENDED,ENDS_GMT=".time()." where MID=$MID /* $USERNAME */ and EBAY_ID=$EBAY_ID limit 1";
		if ($::DEBUG) { print STDERR $pstmt."\n"; }
		$edbh->do($pstmt);

		#&INVENTORY::set_other($USERNAME,'EBAYSTFEED',$SKU,0,time(),$EBAY_ID);
		require INVENTORY2;
		$self->INV2()->mktinvcmd("FOLLOW","EBAY",$EBAY_ID,$SKU,"QTY"=>0,"ENDS_GMT"=>time()-1,"NOTE"=>sprintf("Reason:%s",$params{"REASON"}));
		## &INVENTORY::update_reserve($USERNAME,$SKU,4);		
		}
	

	&DBINFO::db_user_close();	
	return(scalar(@SETS));	

	}



##### begin ebayUtils methods##################################################
##
sub str_safe {
	my $str = shift;
	if (not defined $str) { $str = ''; }
	$str =~ s/&/&amp;/g;
	$str =~ s/</&lt;/g;
	$str =~ s/>/&gt;/g;
	return $str;
}

## timestamp in mysql format
sub timestamp {
	my @t = localtime();
	return sprintf("%04D%02D%02D%02D%02D%02D",$t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0]);
}




##
## checks if category is media/dvd/video and we need to show UPC/ISBN/EAN field 
## (when selecting catgory and specifics)
sub is_media_cat {
	my ($self,$id) = @_;
	my $mediacats = {
		267 => 1,
		11232 => 1,
		307 => 1,
		46354 => 1
	};

	my $result = 0;
	$result = 1 if defined $mediacats->{$id};
	my $edbh = &DBINFO::db_user_connect($self->username());
	my $sth = $edbh->prepare('SELECT parent_id, level from ebay_categories where id=?');
	my $res = $sth->execute($id);
	if(int $res) {
		my ($cat_parent_id, $cat_level) = $sth->fetchrow_array();
		$sth->finish;
		foreach (1..$cat_level-1) {
			$sth = $edbh->prepare('SELECT parent_id from ebay_categories where id=?');
			$sth->execute($cat_parent_id);
			($cat_parent_id) = $sth->fetchrow_array();
			$sth->finish;
			$result = 1 if defined $mediacats->{$cat_parent_id};
		}
	}


	&DBINFO::db_user_close();	
	return $result;
}

## ebay category children count
sub get_children_count {
	my ($self,$id) = @_;

	my $edbh = &DBINFO::db_user_connect($self->username());
	my $result = 1;
	my $sth = $edbh->prepare('SELECT count(id) from ebay_categories where parent_id=?');
	my $res = $sth->execute($id);
	if(int $res) {
		$result = $sth->fetchrow_array();
		$sth->finish;
	}
	&DBINFO::db_user_close();	
	--$result;
	return $result;
}

#####end ebayUtils methods##################################################

#####begin EBAY::TOOLS methods##################################################


##
## used by paypal ipn processor to know "when we're done"		
##
sub getUserTimestamps {
	my ($USERNAME) = @_;
	
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	my $qtUSERNAME = $udbh->quote($USERNAME);

	my $LU = '';
	my $L1 = time();
	my $L2 = time();

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	
	my $pstmt = "select EBAY_USERNAME,LAST_POLL_GMT,LAST_TRANSACTIONS_GMT from EBAY_TOKENS where MID=$MID /* $USERNAME */";
	my $sth = $udbh->prepare($pstmt);
	my $rv = $sth->execute();
	while ( my ($EBAYUSER,$LASTGMT,$LASTTRANS) = $sth->fetchrow() ) {
		$LU .= $EBAYUSER.',';
		if ($L1>$LASTGMT) { $L1 = $LASTGMT; }
		if ($L2>$LASTTRANS) { $L2 = $LASTTRANS; }
		}
	$sth->finish();
	chop($LU);

	my $ERROR = 0;
	if (not defined $rv) { 
		$ERROR = 1; ## Database Error
		}
	elsif ($LU ne '') {
		## everything is cool
		}
	else {
		$ERROR = 100;	## Unknown merchant
		}
	&DBINFO::db_user_close();

	return($ERROR,$LU,$L1,$L2);
	}


##
## an older version of fetchStoreCats
##
#sub fetch_storecats {
#	my ($USERNAME) = @_;
#
#	my ($resultref) = &EBAY2::fetchStoreCats($USERNAME);
#	my @EBAYCATS = ();
#	foreach my $line (@{$resultref}) {
#		push @EBAYCATS, "$line->{'catID'},$line->{'eBayUser'}: $line->{'catPath'}";		
#		}
#	return(\@EBAYCATS);
#	}


##
## returns an array (sorted by eBay's sort order which isn't necessarily numerical) category #, category name
##
## options is:
##		profile=>
##		eias=>
##		rootonly=>1
##
sub fetchStoreCats {
	my ($USERNAME,%options) = @_;

	my $edbh = &DBINFO::db_user_connect($USERNAME);

	my $EIAS = $options{'eias'};
	#if ((not defined $EIAS) && ($options{'profile'} ne '')) {
	#	($EIAS) = &ZOOVY::fetchmerchantns_attrib($USERNAME,$options{'profile'},'ebay:eias');
	#	}
	#if ((not defined $EIAS) && ($options{'prt'} ne '')) {
	#	my ($profile) = &ZOOVY::profile_to_prt($USERNAME,int($options{'prt'}));
	#	($EIAS) = &ZOOVY::fetchmerchantns_attrib($USERNAME,$profile,'ebay:eias');
	#	}

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my @EBAYCATS = ();
	my $pstmt = "select CatNum,Category,EBAYUSER from EBAYSTORE_CATEGORIES where MID=$MID ";
	if ($EIAS ne '') {
		$pstmt .= " and EIAS=".$edbh->quote($EIAS).' ';
		}
	if (defined $options{'rootonly'}) {
		## root categories always have numbers below 100
		$pstmt .= " and CatNum<100 ";
		}

	$pstmt .= " order by EBAYUSER,CatNum";
	print STDERR $pstmt."\n";
	my $sth = $edbh->prepare($pstmt);
	$sth->execute();
	while ( my ($catID,$catPath,$ebu) = $sth->fetchrow() ) {

		## fix the eBay Category offset problem.
		## catId is the "store category id" that should be saved in the product
		my $linkCat = ($catID<100)?($catID+1):$catID;
		push @EBAYCATS, { catID=>$catID,catPath=>$catPath,eBayUser=>$ebu,linkCatID=>$linkCat };
		}
	$sth->finish();

	&DBINFO::db_user_close();
	return(\@EBAYCATS);
	}

#####end EBAY::TOOLS methods##################################################

#####begin MARKET::EBAYAPI methods##################################################
##
## returns an arrayref of accounts for a specific username
##
sub list_accounts {
	my ($USERNAME) = @_;

	my @accounts = ();
	$USERNAME = uc($USERNAME); $USERNAME =~ s/[^A-Z0-9]+//gs;
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	my $edbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select * from EBAY_TOKENS where MID=$MID /* $USERNAME */";
	my $sth = $edbh->prepare($pstmt);
	$sth->execute();
	while ( my $ref = $sth->fetchrow_hashref() ) {
		push @accounts, $ref;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return (\@accounts);
	}
#####end MARKET::EBAYAPI methods##################################################


#####begin EBAY::CREATE methods##################################################






##
##	These are *REQUIRED* for the ebay category chooser to work
##



sub resolve_resource_path {
	my ($VERSION,%options) = @_;
	my $PATH_TO_STATIC = '/httpd/static/ebay/'.$VERSION;
	if ((defined $options{'exists'}) && ($options{'exists'}==0)) {
		## if exists=>0 is passed then we assume it's okay if it doesn't exist (useful in creating paths)
		return($PATH_TO_STATIC);
		}

	if (! -d $PATH_TO_STATIC) {
		my $i = 0;
		while ($i < 100) {
			warn "EBAY2::resolve_resource_path -- MISSED DIRECTORY: /httpd/static/ebay/".($VERSION-$i)."\n";
			$i++;
			last if -d ($PATH_TO_STATIC = '/httpd/static/ebay/'.($VERSION-$i));
			$PATH_TO_STATIC = undef;	## never return a bogus path.
			}
		}

	return($PATH_TO_STATIC);
	}

########
### sqlite database connect - need fot ebay category chooser (see /httpd/static/ebay/VERSION, /httpd/servers/ebay2013)
### 
### THIS IS NOT A SINGLETON PATTERN, $dbh just returned from the sub and not saved inside EBAY2,
###  don't forget to do $dbh->disconnect() when you don't need it
##
### returns database handler or undef
sub db_resource_connect {
	my ($VERSION) = @_;

	my $dbh;
	my $PATH_TO_STATIC = &EBAY2::resolve_resource_path($VERSION);
	if (not defined $PATH_TO_STATIC) {
		warn "Could not EBAY2::resolve_resource_path($VERSION)\n";
		}
	elsif (-f "$PATH_TO_STATIC/ebay.db") {
		$dbh = DBI->connect("dbi:SQLite:dbname=$PATH_TO_STATIC/ebay.db","","");
		}
	return $dbh;
	}

### ebay category full path
sub get_cat_fullname {
	my ($USERNAME, $id) = @_;
	$id = $1 if $id =~ /(\d+)\./;

	my ($edbh) = &EBAY2::db_resource_connect($JSONAPI::VERSION);
	my $fullname = '';
	my $pstmt = "SELECT parent_id,name,level from ebay_categories where id=".int($id);
	# print STDERR "$pstmt\n";
	my ($cat_parent_id, $cat_name, $cat_level) = $edbh->selectrow_array($pstmt);

	if (defined $cat_name) {
		$fullname = $cat_name;
		while ( $cat_parent_id > 0 ) {
			##print "$cat_parent_id\n";
			my $category_id = $cat_parent_id;
			my $pstmt = "SELECT parent_id,name from ebay_categories where id=".int($category_id);
			# print STDERR "$pstmt\n";
			($cat_parent_id, $cat_name) = $edbh->selectrow_array($pstmt);
			$fullname = "$cat_name/$fullname";
			if ($cat_parent_id == $category_id) { $cat_parent_id = 0; }
			}
		}
	$edbh->disconnect();
	$fullname = "/$fullname" if $fullname;
	return $fullname; 
	}


1;
