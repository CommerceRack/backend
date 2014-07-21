package SYNDICATION::EBAY;

use POSIX;
use Data::Dumper;
use Text::CSV_XS;
use XML::Writer;
use lib "/backend/lib";

require PRODUCT;
use strict;
require ZTOOLKIT;
require EBAY2;
require LISTING::EBAY;

sub so { return($_[0]->{'*SO'}); }
sub INV2 { return($_[0]->{'*INV2'}); }


@SYNDICATION::EBAY::INVENTORY_UPDATES = ();




##
##
##
sub new {
	my ($class, $so) = @_;
	my ($self) = {};

	$self->{'*SO'} = $so;
	$self->{'*INV2'} = INVENTORY2->new($so->username());

	$so->set('.url','null');
	$so->pooshmsg("HINT|+Due to how the Zoovy system interacts with the eBay API - this tool will only diagnose which products WILL BE TRANSMITTED.  This tool does not determine which products WILL ACTUALLY BE ACCEPTED by eBay.  Of course transmission to eBaY is requisite for acceptance by eBay so this is still a great place to start.");

	bless $self, 'SYNDICATION::EBAY';  
	return($self);
	}


##
##
##
sub preflight {
	my ($self, $lm) = @_;

	my ($so) = $self->so();

	my $USERNAME = $so->username();	
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	##
	## FATAL ERRORS:
	##	
	my $ERROR = '';

	my ($PRT) = $so->prt();
	my $pstmt = "select count(*),sum(ERRORS) from EBAY_TOKENS where MID=$MID and PRT=$PRT";
	print STDERR $pstmt."\n";
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my ($gottoken,$goterrors) = $udbh->selectrow_array($pstmt);

	if ($so->get('.enable')==0) {
		$lm->pooshmsg("STOP|+New Product syndication has been disabled.");
		}	
	elsif (not $gottoken) {
		$lm->pooshmsg("ERROR|+No eBay token store syndication halted..");
		}
	elsif ($goterrors>1000) {
		$lm->pooshmsg("ERROR|+eBay token has more than 1000 errors, store syndication halted..");
		}
	else {
		$so->pooshmsg("INFO|+You've got an ebay token, and it currently has $goterrors errors on it.");
		}

	$self->{'+batchid'} = ZTOOLKIT::base36((time()/30)); ## / 

	##
	## NON FATAL ERRORS:
	## 
	&DBINFO::db_user_close();
	return($ERROR);
	}


##
##
##
sub header_products {
	return(sprintf("FILE CREATED: %s\n",&ZTOOLKIT::pretty_date(time(),1)));
	}


##
##
##
sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	my $so = undef;	# $so will be set if we're in debug mode.
	if ($self->so()->is_debug($P->pid())) {
		$so = $self->so();
		}

	my $ERROR = undef;
	if ((not $ERROR) && ($P->fetch('zoovy:base_price') eq '')) {
		$ERROR = "Product doesn't have a base price configured.";
		}

	if (not defined $ERROR) {
		}
	elsif (not defined $P->fetch('ebay:storecat')) {
		$OVERRIDES->{'ebay:storecat'} = $OVERRIDES->{'navcat:ebay_storecat'};
		}
	else {
		if (defined $so) { $plm->pooshmsg(sprintf('WARN|+eBay Store category "%d" loaded from product (category ignored).',$OVERRIDES->{'navcat:ebay_storecat'})); }			
		}
	if (not defined $P->fetch('ebay:storecat')) { 
		if (defined $so) { $plm->pooshmsg('WARN|+eBay store category was not found in product or category, setting to zero.'); }
		$OVERRIDES->{'ebay:storecat'} = 0; 
		}


	if (not defined $ERROR) {
		if (not defined $P->fetch('ebay:category')) {
			if (defined $so) { $plm->pooshmsg(sprintf('WARN|+eBay category was not set in product - inheriting "%d" from category.',$P->fetch('navcat:ebay_category'))); }
			}
		else {
			if (defined $so) { $plm->pooshmsg(sprintf('WARN|+eBay category "%d" loaded from product (category ignored).',$P->fetch('navcat:ebay_category'))); }			
			}

		if ($P->fetch('ebay:category') == 0) {
			$ERROR = "VALIDATION|ATTRIB=ebay:category|+eBay category must be set in product, or at category level ";
			}
		}


	$OVERRIDES->{'ebay:listingtype'} = 'FIXED';

	return(undef);
	}




##
##
##
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my ($so) = $self->so();
	my ($USERNAME) = $so->username();
	my ($MID) = $so->mid();
	my ($PID) = $P->pid();
	my $udbh = &DBINFO::db_user_connect($USERNAME);
	## don't insert products which are implicitly blocked.

	my $hashref = ();
	my $qtUSERNAME = $udbh->quote($USERNAME);
	my $qtPRODUCT = $udbh->quote($PID);

	my $QTY = 1;
	my %evdataref = %{$OVERRIDES};
	$evdataref{'zoovy:profile'} = $P->fetch('zoovy:profile');

	## PRE-PRE FLIGHT CHECK
	if (not $plm->can_proceed()) {
		}
	else {
		$OVERRIDES->{'zoovy:qty_instock'} = 0;
		my ($INVSUMMARY) = INVENTORY2->new($USERNAME)->summary( '@PIDS'=>[ $P->pid() ] );
		foreach my $SKU (sort keys %{$INVSUMMARY}) {
			if ($INVSUMMARY->{$SKU}->{'AVAILABLE'}>0) {
				$OVERRIDES->{'zoovy:qty_instock'} += $INVSUMMARY->{$SKU}->{'AVAILABLE'};
				}
			}
		}

	## PREFLIGHT CHECK
	if (not $plm->can_proceed()) {
		## shit happened.
		}
	elsif ($P->has_variations('inv')) {
		$plm->pooshmsg("HINT|+eBay syndication found variations, disabling most of the inventory checks (because they'll fail)");
		}
	elsif (not defined $OVERRIDES->{'zoovy:qty_instock'}) {
		$plm->pooshmsg("ISE|+EBAY: Inventory not set/available on product ".Dumper($OVERRIDES));
		}
	elsif ($OVERRIDES->{'zoovy:qty_instock'}>0) {
		$plm->pooshmsg("INFO|+cleared for launch - in stock: $OVERRIDES->{'zoovy:qty_instock'}");
		}
	elsif (($SKU eq $P->pid()) && ($P->fetch('pid:assembly') ne '')) {
		$plm->pooshmsg("STOP|+inventory too low: $OVERRIDES->{'zoovy:qty_instock'} (possibly a result of product assembly)");
		}
	elsif (($SKU =~ /:/) && ($P->skufetch($SKU,'sku:assembly') ne '')) {
		$plm->pooshmsg("STOP|+inventory too low: $OVERRIDES->{'zoovy:qty_instock'} (possibly a result of sku assembly)");
		}
	else {
		$plm->pooshmsg("STOP|+Inventory too low: $OVERRIDES->{'zoovy:qty_instock'}");
		}


	my $DETAILED_LOGGING = int($so->get('.logging'));
	if ($plm->can_proceed()) {
		##
		## PHASE1: check to see which items are already runnning on eBay
		##
		my $pstmt = "select ID,CREATED_GMT,EBAY_ID,ENDS_GMT from EBAY_LISTINGS where MID=$MID /* $USERNAME */ ";
		$pstmt .= " and IS_ENDED=0 and CLASS in ('FIXED','STORE') ";
		$pstmt .= " and PRODUCT=$qtPRODUCT ";
		$pstmt .= " and PRT=".$so->prt();
		if ($DETAILED_LOGGING) { $plm->pooshmsg("DEBUG|+$pstmt"); }
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		if ($udbh->err()) { $plm->pooshmsg("ISE|+Database error on detect duplicate listings"); }
		my $now = time();
		while ( my ($dbid,$created_gmt,$ebay_id,$ends_gmt) = $sth->fetchrow() ) {
			my $ignore = undef;
			if (($ebay_id == 0) && ($created_gmt>0) && ($created_gmt-3*86400<$now)) {
				## this listing was created more than three days ago, it has no ebay id, it's basically crap, we should treat it as ended.
				my $pstmt = "update EBAY_LISTINGS set IS_ENDED=65 where MID=$MID and ID=$dbid limit 1";
				$udbh->do($pstmt);
				$plm->pooshmsg("WARN|+Cleaned up a never-launched eBay Listing PID:$PID DBID:$dbid created_gmt:$created_gmt");
				$ignore++;
				}
		
			if ($ignore) {
				}
			elsif ($created_gmt==0) {
				$plm->pooshmsg("PAUSE|+Has entry with corrupt PRODUCT_GMT in DB");
				}
			elsif ($now-86400 < $created_gmt) {
				$plm->pooshmsg("PAUSE|+Can only try once every 24 hours");
				}
			elsif ($ebay_id==0) {
				}
			else {
				$plm->pooshmsg("STOP|+Similar listing ($ebay_id) with IS_ENDED=0");
				}
			}
		$sth->finish();
		}



	## PHASE3: check to see if the item is waiting to be launched, or if it had errors.
	if ($plm->can_proceed()) {
		my $pstmt = "select ID,SKU,RESULT,TARGET_LISTINGID from LISTING_EVENTS where MID=$MID /* $USERNAME */ and VERB='INSERT' and PROCESSED_GMT=0 and SKU=$qtPRODUCT";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($ID,$SKU,$RESULT,$LISTINGID) = $sth->fetchrow() ) {
			if ($RESULT eq 'PENDING') {
				$plm->pooshmsg("PAUSE|+Already have a PENDING INSERT event $ID for item $SKU");
				}
			}
		$sth->finish();
		}


	require LISTING::EVENT;
	if ($plm->can_proceed()) {
		my ($le) = LISTING::EVENT->new(
			USERNAME=>$USERNAME,
			REQUEST_APP=>'SYNDICATION',
			REQUEST_BATCHID=>"$self->{'+batchid'}",
			SKU=>$SKU,
			QTY=>$QTY,
			TARGET=>"EBAY.SYND",
			PRT=>$so->prt(),
			'%DATA'=>\%evdataref,
			VERB=>"INSERT"
			);

		if ($le->id()) {
			$plm->pooshmsg("SUCCESS|+Product:$SKU created ListingEvent:".$le->id());
			$self->{'+lcount_inserted'}++;
			}
		else {
			$le->pooshmsg("ERROR|+Product:$SKU failed to create ListingEvent");	
			}
		$plm->merge($le);
		}

	&DBINFO::db_user_close();
	return(undef,undef);
	}
  
sub footer_products {
  my ($self) = @_;

	my ($so) = $self->so();
	my ($lm) = $so->msgs();

	## okay now this modules doesn't create a classical footer, rather it sets the status of the module
	## ex: success/error based on the internal variables it set as it was running
	#if ($self->{'+lcount_mapped'}==0) {
	#	$lm->pooshmsg("STOP|+No products have ebay:ts configured launch.");		
	#	}
	#elsif (($self->{'+lcount_live'}>0) || ($self->{'+lcount_pending'}>0) || ($self->{'+lcount_inserted'}>0)) {
	#	$lm->pooshmsg("SUCCESS|+Live:($self->{'+lcount_live'} Pending:$self->{'+lcount_pending'} Inserted:$self->{'+lcount_inserted'}");
	#	## we should probably check here to see if we have nothing live, nothing pending, and the last 100 or more had errors
	#	}
	#else {
	#	$lm->pooshmsg("STOP|+No Live Listings, No Pending Listings, Nothing Launched");
	#	}

  return("");
  }


sub header_inventory {
	@SYNDICATION::EBAY::INVENTORY_UPDATES = ();

	return("START\n");
	}


##
##
##
sub inventory {
	my ($self,$PID,$P,$lm,$OVERRIDES) = @_;

	my $INV2 = $self->INV2();

	if ($PID ne $P->pid()) {
		## what this really means is that inventory sync. for ebay should never be passed ANYTHING other than a 
		## $SKU=$PID because it should be expandPOGs=3  .. so 
		$lm->pooshmsg("ISE|+EBAY Inventory sync works with whole products, not skus (this line should never be reached)");
		}
	elsif ($P->has_variations('inv'=>1)) {
		## has variations, so we need to process each SKU individually.
		my ($ALLSKUS) = $INV2->summary('@PIDS'=>[ $PID ], 'COMBINE_PIDS'=>0);

		foreach my $SKUSET (@{$P->list_skus()}) {
			my ($SKU,$SKUREF) = @{$SKUSET};

			my $fixed_qty = $P->skufetch($SKU,'ebay:fixed_qty');
			## FIXED_QTY is the max quantity (ceiling) we will ever send to ebay
			my $AVAILABLE = $ALLSKUS->{$SKU}->{'AVAILABLE'};
			if (not defined $AVAILABLE) { $AVAILABLE = 0; }
			
			my %xml = ();
			my ($AVAILABLE) = $ALLSKUS->{$SKU}->{'AVAILABLE'};
			$xml{'Item.Quantity'} = $AVAILABLE; # ($instock-$reserve);

			if ((defined $fixed_qty) && (int($fixed_qty)>0)) {
				if ($fixed_qty<$AVAILABLE) {
					$lm->pooshmsg(sprintf("INFO|+Available [%d] was reduced to Fixed Quantity [%d].",$AVAILABLE,$fixed_qty));
					$xml{'Item.Quantity'} = $fixed_qty;
					}
				}

			if ($xml{'Item.Quantity'}<0) {
				$lm->pooshmsg("WARN|+Negative SKU Inventory: $xml{'Item.Quantity'}");
				$xml{'Item.Quantity'} = 0;
				}

			$SYNDICATION::EBAY::PRODUCTS_INVENTORY{$PID} += $xml{'Item.Quantity'};
			push @SYNDICATION::EBAY::INVENTORY_UPDATES, [ $PID, $xml{'Item.Quantity'}, $SKU ];
			}
		}
	else {
		## no variations	
		my %xml = ();
		my $fixed_qty = $P->fetch('ebay:fixed_qty');
		
		if (not defined $fixed_qty) { 
			$fixed_qty = -1; 
			$lm->pooshmsg("WARN|+Fixed Quantity was not set, launching full amount");
			}

		if (int($fixed_qty)==0) {
			## no, this is not valid. 
			$lm->pooshmsg("WARN|+Fixed Quantity was not set or zero. Removing.");
			$xml{'Item.Quantity'} = 0;
			}
		else {
			my ($AVAILABLE) = $INV2->summary('@PIDS'=>[ $PID ], 'COMBINE_PIDS'=>0)->{ $PID }->{'AVAILABLE'};

			$xml{'Item.Quantity'} = $AVAILABLE; # ($instock-$reserve);

			if ((defined $fixed_qty) && (int($fixed_qty)>0)) {
				if ($fixed_qty<$AVAILABLE) {
					$lm->pooshmsg(sprintf("INFO|+Available [%d] was reduced to Fixed Quantity [%d].",$AVAILABLE,$fixed_qty));
					$xml{'Item.Quantity'} = $fixed_qty;
					}
				}
			if ($xml{'Item.Quantity'}<0) {
				$lm->pooshmsg("WARN|+Negative Product Inventory: $xml{'Item.Quantity'}");
				$xml{'Item.Quantity'} = 0;
				}
			}
	
		$SYNDICATION::EBAY::PRODUCTS_INVENTORY{$PID} = $xml{'Item.Quantity'};
		push @SYNDICATION::EBAY::INVENTORY_UPDATES, [ $PID, $xml{'Item.Quantity'}, $PID ];
		}

	## return something for the output file!
	return("$PID:$SYNDICATION::EBAY::PRODUCTS_INVENTORY{$PID}\n");
	}



##
##
##
sub footer_inventory {
	my ($self) = @_;

	## NOTE: this does the actual upload of any items (if any)
	my ($so) = $self->so();
	my $lm = $so->msgs();

	print Dumper( \@SYNDICATION::EBAY::INVENTORY_UPDATES );

	#my $xml = '';
	#my $writer = new XML::Writer(OUTPUT => \$xml);
	#foreach my $update (@SYNDICATION::EBAY::INVENTORY_UPDATES) {
	#   $writer->startTag("InventoryStatus");
	#	$writer->dataTag("SKU",$update->[0]);
	#	$writer->dataTag("Quantity",$update->[1]);
	#	# $writer->startTag("StartPrice",$update->[1]);
	#	$writer->endTag("InventoryStatus");
	#	}
	#$writer->endTag("BulkDataExchangeRequests");
	#$writer->end();
	#$xml = qq~<?xml version="1.0" encoding="UTF-8"?>\n$xml\n~;

	my @REVISE_XMLHASHES = ();
	my @ENDITEM_XMLHASHES = ();
	foreach my $PID (keys %SYNDICATION::EBAY::PRODUCTS_INVENTORY) {
		if ($SYNDICATION::EBAY::PRODUCTS_INVENTORY{$PID} == 0) {
			push @ENDITEM_XMLHASHES, {
				'#Verb'=>'EndFixedPriceItem',
				'Version'=>'734',
				'SellerInventoryID'=>$PID,
				'EndingReason'=>'NotAvailable',
				};
			}
		}

	foreach my $set (@SYNDICATION::EBAY::INVENTORY_UPDATES) {
		my ($PID,$QTY,$SKU) = @{$set};
		next if ($SYNDICATION::EBAY::PRODUCTS_INVENTORY{$PID} == 0);	# we're ending this item.

		push @REVISE_XMLHASHES, {
			'#Verb'=>'ReviseInventoryStatus',
			'Version'=>'734',
			'InventoryStatus.SKU'=>$SKU, 
			'InventoryStatus.Quantity'=>$QTY,
			};		
		}

#	open F, ">/tmp/ebay.end";
#	print F Dumper(\@ENDITEM_XMLHASHES);
#	close F;
#
#	open F, ">/tmp/ebay.revise";
#	print F Dumper(\@REVISE_XMLHASHES);
#	close F;

	my ($USERNAME) = $so->username();
	my ($PRT) = $so->prt();
	my ($MID) = $so->mid();
	my ($eb2) = EBAY2->new($USERNAME,PRT=>$PRT);

	#my ($UUID,$result) = $eb2->bdesapi('getRecurringJobExecutionStatus',{'recurringJobId'=>$DOCID},output=>'flat');
	#$lm->pooshmsg(sprintf("INFO|+job created:%s job completed:%s",$result->{'.jobProfile.creationTime'},$result->{'.jobProfile.completionTime'}));

	my $PREVIOUS_JOBID = $eb2->{'LMS_INVENTORY_DOCID'};
	my $PREVIOUS_JOBID_GMT = $eb2->{'LMS_INVENTORY_GMT'};
	if ($PREVIOUS_JOBID_GMT < $^T-86400) {
		## if the old job is more than a day old, then we can safely ignore it.
		$PREVIOUS_JOBID = 0;
		}

	# 5019259443
	my ($UUID,$result) = ();
	if ($PREVIOUS_JOBID > 0) {
		($UUID,$result) = $eb2->bdesapi('getJobStatus',{jobId=>$PREVIOUS_JOBID});

		## we probably need to check to see if we got an expired job, or some crap like that, and if we do, then just suppress it.

		if ($UUID eq '') {
			$lm->pooshmsg("WARN|+Got blank UUID response from getJobStatus:$PREVIOUS_JOBID");
			}
		elsif (ref($result) ne 'HASH') {
			$lm->pooshmsg("WARN|+Got corruptresult response from getJobStatus:$PREVIOUS_JOBID");
			}
		elsif ($result->{'ack'}->[0] eq 'Failure') {
			## $result->{'errorMessage'}->[0]{'error'}->[0]{'message'}
			## ex: Job Id is invalid
			$lm->pooshmsg("WARN|+Got ack failure on previous job, but this might not be a bad thing.");
			}
		else {

			my ($jobStatus) = $result->{'jobProfile'}->[0]->{'jobStatus'}->[0];
			if ($jobStatus eq 'Created') { $jobStatus = 'Failed'; }

			if ($jobStatus eq 'Completed') {
				my $fileId = $result->{'jobProfile'}->[0]->{'fileReferenceId'}->[0];
				# $fileId = $result->{'jobProfile'}->[0]->{'InputFileReferenceId'}->[0];
				($UUID,$result) = $eb2->ftsdownload($PREVIOUS_JOBID,$fileId);
				## TODO: we need to parse the result, keep in mind items with zero inventory SHOULD have errors.
				## Invalid SKU number: WWFLOSAL (we can probably check current inventory to see if we need to ignore these)
				open F, ">>/tmp/ebay.result";
				print F $result;
				close F;
				}
			elsif ($jobStatus eq 'Failed') {
				$lm->pooshmsg("ISE|+Previous job:$PREVIOUS_JOBID is:$jobStatus (will need to manually reset account)");
				my ($udbh) = &DBINFO::db_user_connect($USERNAME);
				my $pstmt = "update EBAY_TOKENS set LMS_INVENTORY_DOCID=0,LMS_INVENTORY_TS=0 where MID=$MID and EBAY_EIAS=".$udbh->quote($eb2->ebay_eias());
				print STDERR "$pstmt\n";
				$udbh->do($pstmt);
				&DBINFO::db_user_close();
				}
			else {
				$lm->pooshmsg("PAUSE|+Previous job:$PREVIOUS_JOBID is not yet completed (is:$jobStatus)");
				}
			}
		}

	if (not $lm->can_proceed()) {
		## something bad already happened
		$lm->pooshmsg("PAUSE|+ReviseInventoryStatus upload was skipped because of earlier error.");
		warn "skipping file upload because something bad already happened\n";
		}
	elsif (scalar(@SYNDICATION::EBAY::INVENTORY_UPDATES)==0) {
		$lm->pooshmsg("STOP|+ReviseInventoryStatus - No SKUs available for syndication");
		}
	else {
		($UUID,$result) = $eb2->ftsupload("ReviseInventoryStatus",\@REVISE_XMLHASHES);
		if ($UUID eq '') {
			## somethign went wrong, $result will have error
			$lm->pooshmsg("ERROR|+ReviseInventoryStatus returned error: $result");
			}
		else {
			## SUCCESS!
			#print Dumper($UUID,$result);
			#$VAR1 = 'D7B3B5F8-064B-11E1-A19B-B4893A9CF7B1';
			#$VAR2 = {
			#          '.jobId' => '5026463323',
			#          '.fileReferenceId' => '5019260493',
			#          '.timestamp' => '2011-11-03T18:44:21.554Z',
			#          '.xmlns' => 'http://www.ebay.com/marketplace/services',
			#          '.version' => '1.2.0',
			#          '.ack' => 'Success',
			#          '.maxFileSize' => '15728640'
			#        };
			$eb2->set('LMS_INVENTORY_DOCID'=>int($result->{'.jobId'}),'*LMS_INVENTORY_TS'=>'now()');
			$lm->pooshmsg("SUCCESS|+ReviseInventoryStatus UUID:$UUID");
			}

		}




	# print Dumper($lm);
	return("\nEND\n");
	}




sub lms_create_job {
	my ($eb2, $udbh, $jobType, $lm) = @_;

	my ($MID) = $eb2->mid();

		my ($jobid,$fileid);
 		my ($xUUID,$xresult) = $eb2->bdesapi('startDownloadJob',{'downloadJobType'=>$jobType},output=>'flat');
		if (not defined $xresult) {
			$lm->pooshmsg("ISE|+No Response from eBay");
			}
		elsif ($xresult->{'.ack'} eq 'Failure') {
			## possible failure reasons
			$lm->pooshmsg("FAIL-FATAL|+GOT FAILURE $xresult->{'.errorMessage.error.errorId'}");
			my $WAITING = 0;

			if ($xresult->{'.errorMessage.error.errorId'} == 7) {
				# '.errorMessage.error.message' => 'Maximum of one job per job-type in non-terminated state is allowed',
				## JobStatus are:
				## 	* Aborted (in/out) The Bulk Data Exchange has been aborted due to the abortJobRequset call.
				##		* Completed (in/out) Processing on the data file or the report has finished.
				##		* Created (in/out) The job ID and file reference ID have been created as a result of the createUploadJobRequest or the startDownloadJobRequest.
				##		* Failed (in/out) The Bulk Data Exchange job has not completed successfully, due to incorrect data format, request errors, or Bulk Data Exchange service errors.
				##		* InProcess (in/out) Processing on the data file or the report has begun.
				##		* Scheduled (in/out) The job has been internally scheduled for processing by the Bulk Data Exchange service.
				my ($xUUID,$xresult) = $eb2->bdesapi('getJobs',{	
					'jobType'=>$jobType,	## SoldReport or ActiveInventoryReport
					'jobStatus$A'=>'Scheduled',
					'jobStatus$B'=>'InProcess',
					#'jobStatus$C'=>'Aborted',
					#'jobStatus$D'=>'Failed',
					'jobStatus$E'=>'Created',
					},output=>'xml');
	
				my @DELETEJOBS = ();
				if ($xresult->{'ack'}->[0] eq 'Success') {
					foreach my $jobprofile ( @{$xresult->{'jobProfile'}} ) {
						## so we don't die if the job was created less than an hour ago
						if ($jobprofile->{'jobStatus'}->[0] eq 'Completed') {
							}
						elsif ($jobprofile->{'jobStatus'}->[0]  eq 'Created') {
							if ($eb2->ebt2gmt($jobprofile->{'creationTime'}->[0]) > time()-86400) {
								$WAITING++;
								}
							else {
								push @DELETEJOBS, $jobprofile->{'jobId'}->[0];
								}
							}
						elsif ($jobprofile->{'jobStatus'}->[0] eq 'InProcess') {
							if ($eb2->ebt2gmt($jobprofile->{'startTime'}->[0]) > time()-7200) {
								$WAITING++;
								}
							else {
								push @DELETEJOBS, $jobprofile->{'jobId'}->[0];
								}
							}
						else {
							$lm->pooshmsg("WARN|+Unknown jobStatus: $jobprofile->{'jobStatus'}->[0]");
							push @DELETEJOBS, $jobprofile->{'jobId'}->[0];
							}
						}
					}	

				if (scalar(@DELETEJOBS)>0) {
					foreach my $jobid (@DELETEJOBS) {
						my $result = $eb2->bdesapi('abortJob',{'jobId'=>$jobid},output=>'flat');
						$lm->pooshmsg("WARN|+Aborting Job: $jobid");
						}
					}
				}

			if ($WAITING==0) {
				$lm->pooshmsg("FAIL-FATAL|+delete recurring");
				}
			else {
				$lm->pooshmsg("SUMMARY-ORDERS|+Found $WAITING pending SoldReport(s)");
				}
			}
		elsif ($xresult->{'.ack'} eq 'Success') {
			#$VAR2 = {
			#	 '.jobId' => '5074278760',
			#	 '.timestamp' => '2012-10-04T08:42:58.394Z',
			#	 '.xmlns' => 'http://www.ebay.com/marketplace/services',
			#	 '.version' => '1.3.0',
			#	 '.ack' => 'Success'
			#  };
			my %vars = ( 'MID'=>$MID, 'USERNAME'=>$eb2->username(), 'PRT'=>$eb2->prt(), '*CREATED_TS'=>'now()' );
			$vars{'JOB_ID'} = $xresult->{'.jobId'};
			$vars{'JOB_TYPE'} = $jobType; # 'SoldReport';
			my $pstmt = &DBINFO::insert($udbh,'EBAY_JOBS',\%vars,verb=>'insert','sql'=>1);
			print STDERR $pstmt."\n";
			$udbh->do($pstmt);
			}
		else {
			$lm->pooshmsg("ERROR|+Unknown 'other' response check trace file");
			print STDERR Dumper($xresult);
			}
	return($lm);
	}



##
##
##
sub lms_get_jobs {
	my ($eb2,$udbh,$jobType,$lm,%params) = @_;	

	my ($MID) = $eb2->mid();
	my ($PRT) = $eb2->prt();
	my $USERNAME = $eb2->username();
	my (@JOBS) = ();

	my ($xUUID,$xresult) = $eb2->bdesapi('getJobs',{
		'jobType'=>"$jobType", # SoldReport or ActiveInventoryReport
		'creationTimeFrom'=>$eb2->ebdatetime(time()-(3600*10)),
		'creationTimeTo'=>$eb2->ebdatetime(time()),
		},output=>'xml');

	if ($xresult->{'ack'}->[0] eq 'Success') {
		foreach my $jobprofile ( @{$xresult->{'jobProfile'}} ) {
			# print Dumper($jobprofile);
			my $pstmt = "select count(*) from EBAY_JOBS where MID=$MID and PRT=$PRT and JOB_ID=".int($jobprofile->{'jobId'}->[0]);
			# print "$pstmt\n";
			my ($count) = $udbh->selectrow_array($pstmt);
	
			if ($count == 1) {
				}
			elsif ($jobprofile->{'jobStatus'}->[0] eq 'Completed') {
				## check db too see if we've gotten this before
				my %vars = ( 'MID'=>$MID, 'USERNAME'=>$eb2->username(), 'PRT'=>$eb2->prt(), );
				$vars{'*CREATED_TS'} = sprintf("from_unixtime(%d)",$eb2->ebt2gmt($jobprofile->{'creationTime'}->[0])); 
				$vars{'JOB_ID'} = $jobprofile->{'jobId'}->[0];
				if ($jobprofile->{'fileReferenceId'}->[0]>0) { $vars{'JOB_FILEID'} = $jobprofile->{'fileReferenceId'}->[0]; }
				$vars{'JOB_TYPE'} = $jobType; # 'SoldReport';
				my $pstmt = &DBINFO::insert($udbh,'EBAY_JOBS',\%vars,verb=>'insert','sql'=>1);
				print $pstmt."\n";
				$udbh->do($pstmt);
				}
			elsif ($jobprofile->{'jobStatus'}->[0] eq 'InProcess') {
				}
			elsif ($jobprofile->{'jobStatus'}->[0] eq 'Failed') {
				print Dumper($jobprofile);
				}
			elsif ($jobprofile->{'jobStatus'}->[0] eq 'Aborted') {
				print Dumper($jobprofile);
				}
			elsif ($jobprofile->{'jobStatus'}->[0] eq 'Scheduled') {
				print Dumper($jobprofile);
				}
			else {
				$lm->pooshmsg("ISE|+Unknown status $jobType job#$jobprofile->{'jobId'}->[0] $jobprofile->{'jobStatus'}->[0]");
				}
			}
		}
	else {
		&ZOOVY::confess($USERNAME,"EBAY FAILED");
		}

	my $PENDING_JOB_COUNT = 0;
	my $pstmt = "select ID,JOB_ID,JOB_TYPE,JOB_FILEID,CREATED_TS,DOWNLOADED_TS from EBAY_JOBS where MID=$MID and PRT=$PRT ";
	if ($params{'jobid'}>0) { $pstmt .= " and JOB_ID=".int($params{'jobid'});	}
	if ($params{'pending'}==1) { $pstmt .= " and DOWNLOADED_TS=0 "; }
	$pstmt .= " order by ID desc ";
	if ($params{'limit'}) {	$pstmt .= " limit 0,250";	}
	$lm->pooshmsg("DEBUG|+$pstmt");

	my $sth = $udbh->prepare($pstmt);
	$sth->execute();
	my %I_HAS = ();
	while ( my ($ID,$JOBID,$JOBTYPE,$JOBFILEID,$CREATED_TS,$DOWNLOADED_TS) = $sth->fetchrow() ) {
		
		if ($JOBFILEID == 0) {
			my ($xUUID,$xresult) = $eb2->bdesapi('getJobStatus',{'jobId'=>$JOBID},output=>'flat');
			if ($xresult->{'.jobProfile.fileReferenceId'}>0) {
				$JOBFILEID = $xresult->{'.jobProfile.fileReferenceId'};		
				$pstmt = "update EBAY_JOBS set JOB_FILEID=".$udbh->quote($JOBFILEID)." where MID=$MID and ID=$ID";
				print "$pstmt /* CREATED_TS: $CREATED_TS */\n";
				$udbh->do($pstmt);
				}
				
	      if ($xresult->{'.jobProfile.jobStatus'} eq 'Failed') {
   	       }
         elsif ($JOBTYPE eq $jobType ) { 
      		$PENDING_JOB_COUNT++; 
            }
			}

		if (($JOBFILEID>0) || ($params{'pending'})) {
			push @JOBS, [ $ID, $JOBID, $JOBTYPE, $JOBFILEID, $CREATED_TS, $DOWNLOADED_TS ];
			if (&ZTOOLKIT::mysql_to_unixtime($DOWNLOADED_TS)==0) {
				## on eBay - we only process one of each JOBTYPE
				if (defined $I_HAS{$JOBTYPE}) {
					$DOWNLOADED_TS = 1;
					$pstmt = "update EBAY_JOBS set DOWNLOADED_TS=1 where ID=$ID";
					print $pstmt."\n";
					$udbh->do($pstmt);
					pop @JOBS;
					}
				$I_HAS{$JOBTYPE} = $JOBID;
				}
			}
		}
	$sth->finish();

	return(@JOBS);
	}



##
##
##
#########################################################################################################
##
##
##
##
##
##
##
sub processListings {
	my ($eb2,$EBAY_JOBID,$CREATED_TS,$lm,$xml,$paramsref) = @_;

	my ($LOCK_GMT) = time();
	my ($LOCK_PID) = $$;

	my ($USERNAME) = $eb2->username();
	my ($udbh) = &DBINFO::db_user_connect($eb2->username());
	my ($MID) = $eb2->mid();
	my $PRT= $eb2->prt();

	## ANYTHING WHICH HAS CHANGED OR BEEN MODIFIED SINCE THE JOB WAS CREATED IS OFF LIMITS
	my $IGNORE_AFTER_GMT = &ZTOOLKIT::mysql_to_unixtime($CREATED_TS);

	my %ACTIVE_LISTINGS = ();

	my $NOW_TS = time();
	my @SKUDETAIL = ();
	my $parser = XML::LibXML->new();
	my $tree = $parser->parse_string($xml);
	my $root = $tree->getDocumentElement;
	my @details = $root->getElementsByTagName('SKUDetails');
	foreach my $detail (@details) {
		my $xml = $detail->toString();
		my ($skux) = XML::Simple::XMLin($xml,ForceArray=>1);
		my $skuref = &ZTOOLKIT::XMLUTIL::SXMLflatten($skux);
		if ($skuref->{'.Variations.Variation.SKU'}) {
			## print Dumper($skux);
			foreach my $variation ( @{$skux->{'Variations'}->[0]->{'Variation'}}) {
				my $varref = &ZTOOLKIT::XMLUTIL::SXMLflatten($variation);
				$varref->{'.ItemID'} = $skuref->{'.ItemID'};
				my ($PID,$CLAIM,$INVOPTS) = PRODUCT::stid_to_pid($varref->{'.SKU'});
				$varref->{'.UUID'} = sprintf("EBAY*%s*%s",$varref->{'.ItemID'},$INVOPTS);
				push @SKUDETAIL, $varref;
				}
			}
		elsif ($skuref->{'.SKU'} ne '') {
			push @SKUDETAIL, $skuref;
			}
		else {
			$lm->pooshmsg("WARN|+Listing $skuref->{'.ItemID'} (on eBay) has no SKU");
			}
		}

	my $GOT_DATA = ($xml ne '')?1:0;
	
	my $START_GMT = time();
	my ($INV2) = $eb2->INV2();
	foreach my $SKUREF (@SKUDETAIL) {
		print Dumper($SKUREF);

		my $EBAYID = $SKUREF->{'.ItemID'};
		my $SKU = $SKUREF->{'.SKU'};
		next if ($SKU eq '');

		## No Variations
		my $QTY = $SKUREF->{'.Quantity'};			
		my $UUID = $SKUREF->{'.UUID'} || sprintf("EBAY*$EBAYID");
		$INV2->mktinvcmd('FOLLOW',"EBAY",$EBAYID,$SKU,
			UUID=>$UUID,
			QTY=>$QTY,
			"NOTE"=>sprintf("Price:%0.2f",$SKUREF->{'.Price.content'})
			);
		}	

	## now remove any remaining inventory listings
	$INV2->invcmd('NUKE','MARKET_DST'=>'EBAY','CREATED_BEFORE_TS'=>&ZTOOLKIT::mysql_from_unixtime($IGNORE_AFTER_GMT));

	## alright, now we'll make sure that EBAY_LISTINGS matches 	
	my %ACTIVE_LISTINGS = ();
	my @RESULTS = ();

	if ($GOT_DATA) {
		## SANITY: get a list of all active listings in our database
		# [0] = items remain
		# [1] = created date
		# [2] = quantity
		# [3] = sku
		# [4] = db uuid
		#my $pstmt = "truncate table EBAY_LISTINGS";
		#$udbh->do($pstmt);

		## KEY = ebayid
		##	VALUE = array 0=ITEMS REMAIN, 1=created_gmt, 2=confirmed, exists on ebay 3=SKU, 4=dbid
		my $pstmt = "select EBAY_ID,ITEMS_REMAIN,CREATED_GMT,PRODUCT,ID from EBAY_LISTINGS where MID=$MID and PRT=$PRT and IS_ENDED=0 and EBAY_ID>0";
		print $pstmt."\n";
		my $sth = $udbh->prepare($pstmt);
		$sth->execute();
		while ( my ($EBAY_ID,$ITEMS_REMAIN,$CREATED_GMT,$SKU,$DBID) = $sth->fetchrow() ) {
			## the 0 in column 2 is "exists on ebay"
			if ($EBAY_ID == 0) {
				$lm->pooshmsg("WARN|+SKU:$SKU DBID:$DBID HAS NO EBAY_ID");
				}
			elsif ($CREATED_GMT > $IGNORE_AFTER_GMT) {
				$lm->pooshmsg("WARN|+SKU:$SKU DBID:$DBID WAS CREATED($CREATED_GMT) AFTER($IGNORE_AFTER_GMT)");
				}
			else {
				$ACTIVE_LISTINGS{$EBAY_ID} = [ $ITEMS_REMAIN, $CREATED_GMT, 0, $SKU, $DBID ];
				}
			}
		$sth->finish();
		my %END_ME = %ACTIVE_LISTINGS;
		foreach my $SKUREF (@SKUDETAIL) {
			my $EBAYID = $SKUREF->{'.ItemID'};
			delete $END_ME{$EBAYID};
			}
		foreach my $key (keys %END_ME) {
			print "KEY: $key IS_ENDED=0 but isn't on eBay\n";
			$pstmt = "update EBAY_LISTINGS set IS_ENDED=1 where EBAY_ID=$key\n"; 
			print "$pstmt\n";
			$udbh->do($pstmt);
			delete $ACTIVE_LISTINGS{$key};
			}
		}

	if ($GOT_DATA) {
		foreach my $SKUREF (@SKUDETAIL) {
			#$VAR1 = {
			#	 '.Quantity' => '4',
			#	 '.SKU' => 'DS_GREASE',
			#	 '.Price.content' => '29.99',
			#	 '.ItemID' => '280594712305',
			#	 '.Price.currencyID' => 'USD'
			#  };
			
			my $EBAYID = $SKUREF->{'.ItemID'};

			if (not defined $ACTIVE_LISTINGS{$EBAYID}) {
				## Listing on eBay that we don't have in the database
				warn "SKU: $SKUREF->{'.SKU'} EBAYID: $EBAYID exists on eBay, but not in database\n";
				my $pstmt = "select count(*) from EBAY_LISTINGS where MID=$MID and PRT=$PRT and EBAY_ID=".int($EBAYID);
				my ($count) = $udbh->selectrow_array($pstmt);
				print "$pstmt $count\n";

				if ($SKUREF->{'.SKU'} eq '') {
					warn "EBAYID: $EBAYID has no SKU\n";
					}
				elsif ($count==0) {
					warn "Importing listing $EBAYID [$count]\n";
					my ($pstmt) = &DBINFO::insert($udbh,'EBAY_LISTINGS',{
						'MERCHANT'=>$USERNAME,
						'MID'=>$MID,
						'PRT'=>$PRT,
						'CHANNEL'=>-10,
						'IS_GTC'=>1,
						'PRODUCT'=>$SKUREF->{'.SKU'},	
						'ITEMS_SOLD'=>0,
						'QUANTITY'=>$SKUREF->{'.Quantity'},
						'ITEMS_REMAIN'=>$SKUREF->{'.Quantity'},
						'EBAY_ID'=>$EBAYID,
						'RESULT'=>'Imported',
						},sql=>1);
					print $pstmt."\n";
					$udbh->do($pstmt);
					my ($UUID) = &DBINFO::last_insert_id($udbh);
					$ACTIVE_LISTINGS{$EBAYID} = [ $SKUREF->{'.Quantity'}, 0, 1, $SKUREF->{'.SKU'}, $UUID ];
					}
				elsif ($count>0) {
					warn "Resurrecting $EBAYID\n";
					$pstmt = "update EBAY_LISTINGS set IS_ENDED=0,EXPIRES_GMT=0,IS_GTC=1,ENDS_GMT=0,RESULT='Resurrected' where MID=$MID and PRT=$PRT and EBAY_ID=".$udbh->quote($EBAYID);
					print $pstmt."\n";
					$udbh->do($pstmt);
					$ACTIVE_LISTINGS{$EBAYID} = [ $SKUREF->{'.Quantity'}, 0, 1, $SKUREF->{'.SKU'} ];
					}
					
				}
			elsif ($ACTIVE_LISTINGS{$EBAYID}->[0] != $SKUREF->{'.Quantity'}) {
				warn "EBAYID: $EBAYID has different quantities ebay=[$SKUREF->{'.Quantity'}] zoovy=[$ACTIVE_LISTINGS{$EBAYID}->[0]]\n";
				}
				
			if ($SKUREF->{'.SKU'} ne $ACTIVE_LISTINGS{$EBAYID}->[3]) {
				print "$EBAYID is $SKUREF->{'.SKU'} should be $ACTIVE_LISTINGS{$EBAYID}->[3]\n";
				my ($LISTINGID) = $udbh->selectrow_array("select DISPATCHID from EBAY_LISTINGS where EBAY_ID=$EBAYID");
				print "update LISTING_EVENTS set SKU='$SKUREF->{'.SKU'}',PRODUCT='$SKUREF->{'.SKU'}' where ID=$LISTINGID\n";
				print "update EBAY_LISTINGS set PRODUCT='$SKUREF->{'.SKU'}' where EBAY_ID=$EBAYID\n";
				}
			$ACTIVE_LISTINGS{$EBAYID}->[2]++;
			}
		}


	$GOT_DATA = 0;
	$lm->pooshmsg("SUCCESS|+Finished listing sync");

	if ($GOT_DATA) {
		## END LISTINGS (NOT READY FOR PRIME-TIME)
		foreach my $EBAYID (keys %ACTIVE_LISTINGS) {
			next if ($EBAYID eq '');
			my $SKU = $ACTIVE_LISTINGS{$EBAYID}->[3];


			#my ($inv) = INVENTORY::fetch_incremental($USERNAME,$SKU);
			#if ((defined $params{'inv'}) && ($params{'inv'}==0)) { $inv = 9999; } 
			my ($AVAILABLE) = INVENTORY2->new($USERNAME,"*EBAY")->summary('SKU'=>$SKU,'SKU/VALUE'=>'AVAILABLE');
			if (not $ACTIVE_LISTINGS{$EBAYID}->[4]) {
				warn "EBAYID: $EBAYID .. hmmm, can't remove what we don't have! (EBAYID not in \$ACTIVE_LISTINGS)\n";
				}
			elsif ((defined $AVAILABLE) && ($AVAILABLE <= 0)) {
				warn "SKU: $SKU has $AVAILABLE inventory (removing) EBAYID:$EBAYID UUID:$ACTIVE_LISTINGS{$EBAYID}->[4] ";
				$lm->pooshmsg("INFO|+Created END event for EBAYID: $EBAYID (inv:$AVAILABLE)");
				require LISTING::EVENT;
				my ($le) = LISTING::EVENT->new(
					'USERNAME'=>$USERNAME,
					'PRT'=>$PRT,
					'SKU'=>$SKU,
					'VERB'=>'END',
					'TARGET'=>'EBAY',
					'TARGET_LISTINGID'=>$EBAYID,
					'TARGET_UUID'=>$ACTIVE_LISTINGS{$EBAYID}->[4], # dbid is our UUID
					'REQUEST_APP'=>'EBMONITOR',
					);
				$le->dispatch();	
				}
			elsif ($ACTIVE_LISTINGS{$EBAYID}->[1]>$NOW_TS-86400) {
				warn "SKU: $SKU EBAYID: $EBAYID was created in the last 86400 seconds, so we can't end it. (ebay file might not be up to date)\n";
				}
			elsif ($ACTIVE_LISTINGS{$EBAYID}->[2]==0) {
				## this is the infamous error=55
				warn "EBAYID: $EBAYID exists in database, but not on eBay\n";
				my $pstmt = "update EBAY_LISTINGS set IS_ENDED=if(IS_ENDED>0,IS_ENDED,55) where MID=$MID and PRT=$PRT and EBAY_ID=".$udbh->quote($EBAYID);
				print $pstmt."\n";
				$udbh->do($pstmt);
				$lm->pooshmsg("INFO|+Setting EBAYID:$EBAYID to IS_ENDED=55 [not in file]");
				}
			}
	
		my %ACTIVE_PRODUCTS = ();
		foreach my $EBAYID (sort keys %ACTIVE_LISTINGS) {
			my $SKU = $ACTIVE_LISTINGS{$EBAYID}->[3];
			next if ($SKU eq '');

			if (defined $ACTIVE_PRODUCTS{ $SKU }) {
				## duplicates
				print "SKU: $SKU is duplicated in eBayID: $ACTIVE_PRODUCTS{$SKU} - but also: $EBAYID\n";
				print Dumper($ACTIVE_LISTINGS{$EBAYID},$ACTIVE_LISTINGS{$ACTIVE_PRODUCTS{$SKU}});
				require LISTING::EVENT;
				my ($le) = LISTING::EVENT->new(
					'USERNAME'=>$USERNAME,
					'PRT'=>$PRT,
					'SKU'=>$SKU,
					'VERB'=>'END',
					'TARGET'=>'EBAY',
					'TARGET_LISTINGID'=>$EBAYID,
					'TARGET_UUID'=>$ACTIVE_LISTINGS{$EBAYID}->[4], # dbid is our UUID
					'REQUEST_APP'=>'EBMONITOR',
					);
				$le->dispatch();
				}
			else {
				$ACTIVE_PRODUCTS{ $SKU } = $EBAYID;
				}
			}

		## SANITY: now update any in our database that ebay still has as active
		}

	&DBINFO::db_user_close();
	return();
	}





################################################################################################################
##
##
##
##
sub processOrders {
	my ($eb2,$EBAY_JOBID,$CREATED_TS,$lm,$xml,$paramsref) = @_;

	my ($USERNAME) = $eb2->username();
	my ($MID) = $eb2->mid();


	my @XMLORDERS = ();
	my @ORDERACKS = ();

	# print "Why yes please, that would be wonderful!!\n";
	my $parser = XML::LibXML->new();
	my $tree = $parser->parse_string($xml);
	my $root = $tree->getDocumentElement;
	my @details = $root->getElementsByTagName('OrderDetails');
	foreach my $detail (@details) {
		push @XMLORDERS, $detail->toString();
		}

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	foreach my $xml (@XMLORDERS) {
		my ($olm) = LISTING::MSGS->new($USERNAME,'stderr'=>1);

		my @CLAIMS = ();
		my $RESULT = ''; 	## WARN|GOOD|FAIL

		my ($ord) = XML::Simple::XMLin($xml,ForceArray=>1);
		my $ebordref = &ZTOOLKIT::XMLUTIL::SXMLflatten($ord);

	
		my $EBAY_ORDERID = $ebordref->{'.OrderID'};

		# next if ((defined $paramsref->{'ebayid'}) && ($ebordref->{'.OrderItemDetails.OrderLineItem.ItemID'} ne $paramsref->{'ebayid'}));
		next if ((defined $paramsref->{'ebayid'}) && ($xml !~ /$paramsref->{'ebayid'}/));
		next if ((defined $paramsref->{'ebayoid'}) && ($EBAY_ORDERID ne $paramsref->{'ebayoid'}));
		# print "FOUND: $ebordref->{'.OrderItemDetails.OrderLineItem.ItemID'}\n";

		##
		## NOTE: I really need to rewrite this to use erefid instead of a separate table (this predates erefid)
		##			

		## WAIT: do not ack (this will close eventually)
		## SKIP: this order is not somethin we will process
		## STOP: we've already done this, (this will be acked)
		
		my $EBAY_PAID_GMT = 0;
		if (defined $ebordref->{'.PaymentClearedTime'}) {
			$EBAY_PAID_GMT = $eb2->ebt2gmt($ebordref->{'.PaymentClearedTime'});
			}

		my $OUR_ORDERID = undef;
		if ($EBAY_PAID_GMT==0) {
			$olm->pooshmsg(sprintf("WAIT|+eBay #:$EBAY_ORDERID -- we will not process non-paid orders"));
			}
		else {
			my $SHIPPED_GMT = 0;
			my $pstmt = "select OUR_ORDERID,count(*) from EBAY_ORDERS where MID=$MID /* $USERNAME */ and EBAY_ORDERID=".$udbh->quote($EBAY_ORDERID);
			($OUR_ORDERID,my $exists) = $udbh->selectrow_array($pstmt);

			if ($OUR_ORDERID eq '') {
				## LEGACY DUPLICATE ORDERID SUPPORT
				($OUR_ORDERID) = &CART2::lookup($USERNAME,"EREFID"=>$EBAY_ORDERID);
				}
			if ($OUR_ORDERID eq '') {
				## now.. we'll come up with a reliable ID# based on ebay transaction #
				$OUR_ORDERID = &EBAY2::our_orderid($USERNAME,$EBAY_ORDERID);
				}
			if ($OUR_ORDERID eq '') {
				$olm->pooshmsg(spritnf("FAIL|+OUR_ORDERID was not defined -- internal error."));
				}
			}

		print "EBAY_ORDERID: $EBAY_ORDERID\n";
		print " OUR_ORDERID: $OUR_ORDERID\n";

		my $O2 = undef;
		my $IS_NEW = 0;
		if (not $olm->can_proceed()) {
			## nothing to see here.
			}
		elsif ($OUR_ORDERID eq '') {
			$lm->pooshmsg("ISE|+INVALID EBAY ORDER ID");
			}
		elsif ($EBAY_ORDERID eq '') {
			$lm->pooshmsg("ISE|+INVALID OUR_ORDERID");
			}
		elsif ($EBAY_PAID_GMT==0) {
			$olm->pooshmsg(sprintf("WAIT|+eBay #:$EBAY_ORDERID -- we will not process non-paid orders"));
			}
		elsif ($eb2->get('IGNORE_ORDERS_BEFORE_GMT') > $EBAY_PAID_GMT) {
			## this is to help new users, so we can set a time when order processing started.
			$olm->pooshmsg(sprintf("SKIP|+IGNORE_ORDERS_BEFORE_GMT:%d PAID_GMT:%d\n",$eb2->get('IGNORE_ORDERS_BEFORE_GMT'),$EBAY_PAID_GMT));
			}
		else {
			($O2) = CART2->new_from_oid($USERNAME,$OUR_ORDERID,warn_on_undef=>0);
			if (defined $O2) {
				if ($paramsref->{'fix_corrupt'}) {
					$olm->pooshmsg("WARN|+running 'fix_corrupt' code on ORDER:$EBAY_ORDERID");
					my $pstmt = "delete from EBAY_ORDERS where MID=$MID /* $USERNAME */ and EBAY_ORDERID=".$udbh->quote($EBAY_ORDERID);
					print $pstmt."\n";
					$udbh->do($pstmt);
					## $O2 = CART2->new_memory($USERNAME,$eb2->prt());
					}
				else {
					$olm->pooshmsg("STOP|+We already have eBay Order#:$EBAY_ORDERID => Our #:$OUR_ORDERID");
					}
				}
			else {
				($O2) = CART2->new_memory($USERNAME,$eb2->prt());
				}
			}


		## SANITY: at this point $O2 is set, or $olm is set to error
		if (not $olm->can_proceed()) {
			}
		elsif ((not defined $O2) || (ref($O2) ne 'CART2')) {
			$olm->pooshmsg(sprintf("ISE|+COULD NOT INSTANTIATE O2 OBJECT - CANNOT PROCEED ORDER: %s EBAY:%s",$EBAY_ORDERID,$OUR_ORDERID));
			}
		elsif ($paramsref->{'fix_corrupt'}) {
			## special debug parameter
			}
		elsif ($O2->order_dbid()>0) {
			## CHECK FOR DUPLICATE ORDERS WE'VE ALREADY GOT
			## if they are shipped and paid we can ack them.
			$olm->pooshmsg(sprintf("WAIT|+ORDER: %s is already in db as %s",$EBAY_ORDERID,$OUR_ORDERID));

			if (($O2->in_get('flow/shipped_ts')>0) && ($O2->in_get('flow/paid_ts')>0)) {
				}
			if ($O2->in_get('flow/paid_ts')>0) {
				$olm->pooshmsg("STOP|+ORDER:$OUR_ORDERID is already existing+paid");
				}
			}

		if (not $olm->can_proceed()) {
			## nothing to do here.
			}
		else {
			## unprocessed order
			$O2->in_set('flow/paid_ts',$eb2->ebt2gmt($ebordref->{'.PaymentClearedTime'}));
			# '.OrderID' => '190336372311-367621280009',
			$O2->in_set('mkt/erefid', $EBAY_ORDERID);
			if ($EBAY_ORDERID eq '') {
				$lm->pooshmsg("SKIP|+EBAY ORDERID IS NOT SET (WTF)?");
				}
			}

		my $UNPAID_ITEMS = undef;
		if ($olm->can_proceed()) {
			my $ITEM_TOTALS = 0;

			# '.PaymentClearedTime' => '2009-10-05T01:32:10.000Z',
			$UNPAID_ITEMS = 0;

			##
			## Iterate through the items, and create claims, and add to cart (if appropriate)
			##
			my $ORDER_ITEM_LINES = 0;		## the number of line items in the order (for verification later)

			## PHASE1: pre-chew the items a bit.
			foreach my $item (@{$ord->{'OrderItemDetails'}->[0]->{'OrderLineItem'}}) {	
				#print Dumper($item);
				$ORDER_ITEM_LINES++;
				my $ilm = LISTING::MSGS->new($USERNAME,'stderr'=>1);
				my $ebitemref = &ZTOOLKIT::XMLUTIL::SXMLflatten($item);
	
				my $SKU = $ebitemref->{'.SKU'};
				if (defined $ebitemref->{'.Variation.SKU'}) {
					## .SKU is what we use for inventory, so we overwrite that with .Variation.SKU if it's avialable.
					$SKU = $ebitemref->{'.Variation.SKU'};
					}
				
				my $EBAYID = $ebitemref->{'.ItemID'};
	
				## we compute $ITEM_TOTALS for sales tax later (if we need it)
				## strip commas from sale price.
				$ebitemref->{'.SalePrice.content'} =~ s/[^\d\.]+//gs; 
				$ebitemref->{'.SalePrice.content'} = sprintf("%.2f",$ebitemref->{'.SalePrice.content'});
				$ITEM_TOTALS += $ebitemref->{'.SalePrice.content'};

				if ((defined $ebitemref->{'.PaymentClearedTime'}) && ($ebitemref->{'.PaymentClearedTime'} ne '')) {
					my $THIS_PAID_GMT = $eb2->ebt2gmt($ebitemref->{'.PaymentClearedTime'});
					if ($THIS_PAID_GMT>$O2->in_get('flow/paid_ts')) { $O2->in_set('flow/paid_ts',$THIS_PAID_GMT); }
					}
				elsif ($O2->in_get('flow/paid_ts')>0) {
					## this was already paid at the order level (not the item level)
					}
				else {
					$ilm->pooshmsg("WAIT|+EBAYID:$EBAYID is not paid $ebitemref->{'.PaymentClearedTime'}");
					$UNPAID_ITEMS++;
					}

				my $pstmt = "select ID,CHANNEL,TITLE from EBAY_LISTINGS where MID=$MID and EBAY_ID=".int($EBAYID);
				print STDERR "$pstmt\n";
				my ($UUID,$CHANNEL,$TITLE) = $udbh->selectrow_array($pstmt);

				## DO NOT PULL SKU FROM DATABASE SINCE IT WILL BE *PRODUCT* not SKU
				##	AND WILL FUCK UP OPTIONS

				if (not $ilm->can_proceed()) {
					}
				elsif ($UUID==0) {
					## hmm.. okay so we don't have it in our database, but that could mean it was a second chance offer
					my ($getitemresult) = $eb2->GetItem($ebitemref->{'.ItemID'});
					if (int($getitemresult->{'.Item.ListingDetails.SecondChanceOriginalItemID'})>0) {
						$ebitemref->{'_IS_SECONDCHANCE_FOR_ITEM'} = int($getitemresult->{'.Item.ListingDetails.SecondChanceOriginalItemID'});
						$pstmt = "/* SECOND CHANCE */ select ID,CHANNEL,TITLE from EBAY_LISTINGS where MID=$MID and EBAY_ID=".int($getitemresult->{'.Item.ListingDetails.SecondChanceOriginalItemID'});
						print STDERR $pstmt."\n";
						($UUID,$CHANNEL,$TITLE) = $udbh->selectrow_array($pstmt);
						$lm->pooshmsg(sprintf("INFO|+eBay item %s is a second chance of item:%s uuid:%d",
							$ebitemref->{'.ItemID'},$ebitemref->{'_IS_SECONDCHANCE_FOR_ITEM'},$UUID));
						}
					else {
						$lm->pooshmsg(sprintf("INFO|+eBay item %s is NOT a second chance offer.",$ebitemref->{'.ItemID'}));
						}
	
					if (($TITLE eq '') && ($getitemresult->{'.Item.Title'} ne '')) {
						$TITLE = $getitemresult->{'.Item.Title'};
						}
					}

				if (not defined $UUID) {
					($UUID,$CHANNEL,$TITLE) = (0,0,,"EBAY ITEM $EBAYID NOT IN DATABASE");
					}

				my ($P) = undef;
				if (not $ilm->can_proceed()) {
					}
				elsif ($UUID>0) {
					## best case scenario, we'll use .SKU from eBay, and title+channel from zoovy db.
					$ebitemref->{'_TITLE'} = $TITLE;
					$ebitemref->{'_UUID'} = $UUID;
					$ebitemref->{'_CHANNEL'} = $CHANNEL;
					}
				elsif (($SKU ne '') && (&ZOOVY::productidexists($USERNAME,$SKU))) {
					## workable scenario, not our listing (or we don't know about it) but at least we can figure out title.
					# ($P) = PRODUCT->new($USERNAME,$ebitemref->{'.SKU'});
					($P) = PRODUCT->new($USERNAME,$SKU);
					# my ($prodref) = &ZOOVY::fetchsku_as_hashref($USERNAME,$ebitemref->{'.SKU'});
					if (not defined $ebitemref->{'_TITLE'}) {
						$ebitemref->{'_TITLE'} = $P->skufetch($SKU,'zoovy:prod_name'); # $prodref->{'zoovy:prod_name'};
						}
					$ebitemref->{'_UUID'} = 0;
					}
				elsif ($eb2->{'DO_IMPORT_LISTINGS'}>0) {
					## SANITY: the next few lines ensure that _TITLE and .SKU are set to something!
					if (not defined $ebitemref->{'_TITLE'}) {
						$ebitemref->{'_TITLE'} = sprintf("Unknown eBay Item: %s",$ebitemref->{'.ItemID'});
						}
					if ($ebitemref->{'.SKU'} eq '') { 
						$SKU = "EBAY-".$ebitemref->{'.ItemID'}; 
						}
					}
				else {
					## nope, we really can't auto-create orders, and we have no zoovy items.
					$ilm->pooshmsg(sprintf("SKIP|+eBay order %s CANNOT CREATE ORDER BECAUSE ZOOVY_ITEM_COUNT==0 and DO_IMPORT_LISTINGS==0",$EBAY_ORDERID));
					}

				my $CLAIM = 0;
				my ($LISTINGID,$TXNID) = split(/-/,$ebitemref->{'.OrderLineItemID'});

				if (not $ilm->can_proceed()) {
					}
				elsif ($SKU) {
					($CLAIM) = $eb2->createClaim({
						'CHANNEL'=>$CHANNEL,
						'BUYER_EMAIL'=>$ebordref->{'.BuyerEmail'},
						'BUYER_USERID'=>$ebordref->{'.BuyerUserID'},
						'BUYER_EIAS'=>'*'.$ebordref->{'.BuyerUserID'},
						'SKU'=>$SKU,
						'PRICE'=>$ebitemref->{'.SalePrice.content'},
						'QTY'=>$ebitemref->{'.QuantitySold'},	
						'PROD_NAME'=>$ebitemref->{'_TITLE'},
			  		 	'MKT_LISTINGID'=>$ebitemref->{'.ItemID'}, 
						'MKT_TRANSACTIONID'=>$TXNID,
						'SITE'=>$ebitemref->{'.ListingSiteID'},
						'OUR_ORDERID'=>$OUR_ORDERID,
						});
					}
				else {
					$ilm->pooshmsg("WARN|+LISTING:$LISTINGID REFERENCED BLANK SKU (CANNOT CREATE A CLAIM#)");
					## sku was not found or not set, we'll throw a warning later.
					}
			
				## now lets see if an order has already been created.
				my $ACK = 0;	## send ack for this order.
				my $claimref = undef;
				if ($CLAIM>0) {
					$claimref = &EXTERNAL::fetchexternal_full($USERNAME,$CLAIM); 
					if (not defined $claimref) {
						$ilm->pooshmsg("ERROR|+Could not load CLAIM:$CLAIM from database");
						}
					}
			
				
				if (not $ilm->can_proceed()) {
					}
				elsif (not defined $claimref) {
					$ilm->pooshmsg("ERROR|+No claimref");
					}
				elsif ($paramsref->{'fix_corrupt'}) {
					}
## WE CANT DO THIS CHECK ANYMORE BECAUSE IT WILL ALWAYS HAVE AN ORDERID
#				elsif ($claimref->{'ZOOVY_ORDERID'} ne '') {
#					$ilm->pooshmsg("WARN|+CLAIM #$CLAIM references ORDER:$claimref->{'ZOOVY_ORDERID'}");
#					my ($O2) = CART2->new_from_oid($USERNAME,$claimref->{'ZOOVY_ORDERID'},'new'=>0);
#					if (not defined $O2) { 
#						$ilm->pooshmsg("WARN|+It appears order ORDER:$claimref->{'ZOOVY_ORDERID'} isn't real - we'll pretend we didn't see that");
#						$claimref->{'ZOOVY_ORDERID'} = '';
#						}
#					$ilm->pooshmsg("SKIP|+Skipped order creation, $CLAIM already linked to order $claimref->{'ZOOVY_ORDERID'}");
#
#					#if ($claimref->{'ZOOVY_ORDERID'} eq '') {
#					#	}
#					#else {
#					#	## hmm.. in hte future some SKIP logic here might be good to just drop this item from the order.
#					#	## not sure if it's necessary (ever happens) so i won't code it now.
#					#	$ilm->pooshmsg("SKIP|+CLAIM:$CLAIM is already part of order $claimref->{'ZOOVY_ORDERID'}");
#					# 	}
#					}
				elsif (($claimref->{'STAGE'} eq 'H') && ($O2->in_get('flow/paid_ts')>0)) {
					## ebay item is now flagged as paid. (change the line above to enter)
					my ($O2) = CART2->new($USERNAME,$claimref->{'ZOOVY_ORDERID'},'new'=>0);
					if (not $O2->is_paidinfull()) {
						$O2->add_history("Detected Order is actually PAID");
						# $O2->set_payment_status('060','ebay/monitor-recover',[]);  ## NO LONGER SUPPORTED
						# $O2->save();
						}
					}
				elsif ($claimref->{'STAGE'} eq 'C') {
					$ilm->pooshmsg("STOP|+the item $CLAIM is already completed (but without an order).");
					}
				elsif ((not defined $SKU) || ($SKU eq '')) {
					$ilm->pooshmsg("WARN|+ITEM $LISTINGID HAS BLANK SKU - CREATING AS BASIC ITEM");
					$O2->stuff2()->basic_cram(
						"EBAY-$LISTINGID",
						$ebitemref->{'.QuantitySold'},
						$ebitemref->{'.SalePrice.content'},
						"Misc EBAY Item (No SKU Provided)",
						);						
					}
				else {
					my $MKTID = sprintf("%s-%s",$LISTINGID,$TXNID);
					my $MKT = 'EBF';
					if ($TXNID == 0) { $MKT = 'EBA'; }	# auction listings don't have transaction id's!
	
					my ($P) = PRODUCT->new($USERNAME,$SKU,'create'=>1,'CLAIM'=>$CLAIM);
					my ($pid,$cx,$invopts,$noinvopts,$virtual) = PRODUCT::stid_to_pid($SKU);
					my $recommended_variations = $P->suggest_variations('guess'=>1,'stid'=>$SKU);
					foreach my $variation (@{$recommended_variations}) {
						if ($variation->[4] eq 'guess') {
							$ilm->pooshmsg("WARN|+SKU:$SKU had to guess for variation $variation->[0]$variation->[1]");
							}
						}
					my $selected_variations = STUFF2::variation_suggestions_to_selections($recommended_variations);
					(my $item, $ilm) = $O2->stuff2()->cram( 
						$pid, 
						$ebitemref->{'.QuantitySold'}, 
						$selected_variations, 
						'uuid'=>$MKTID,
						'*LM'=>$ilm, '*P'=>$P,
						'force_price'=>$ebitemref->{'.SalePrice.content'},
						'force_qty'=>$ebitemref->{'.QuantitySold'},
						'claim'=>int($CLAIM),
						);
					$item->{'mkt'} = $MKT;
					$item->{'mktid'} = $MKTID;
					}

				#if ($ilm->can_proceed()) {
				#	push @ORDERACKS, { OrderID=>$EBAY_ORDERID,OrderLineItemID=>$ebitemref->{'.OrderLineItemID'},Paid=>$O2->in_get('flow/paid_ts') };
				#	}
				$olm->merge($ilm);
				}
			}

		if (not $olm->can_proceed()) {
			}
		elsif ((defined $UNPAID_ITEMS) && ($UNPAID_ITEMS>0)) {
			$olm->pooshmsg(sprintf("STOP|+eBay order %s FOUND UNPAID ITEMS IN ORDER!",$EBAY_ORDERID));
			}
		elsif ($O2->in_get('flow/paid_ts')==0) {
			$olm->pooshmsg(sprintf("STOP|+eBay order %s MISSING PAYMENT FLAG",$EBAY_ORDERID));
			}
		else {
			$olm->pooshmsg("INFO|+passed preflight checks");
			}


		## okay there is an annoying case where the person can pay for items individually, and the order isn't
		## ever flagged as paid. so on a multi-item order, even if we decided that it isn't paid, we should still
		## check each item, for payment.
					
		if (not $olm->can_proceed()) {
			}
		elsif ($O2->in_get('flow/paid_ts')==0) {
			## this is a failsafe, just in case.. this line should never be reached.
			$olm->pooshmsg(sprintf("ISE|+eBay order %s is unpaid",$EBAY_ORDERID));
			}
		elsif ($O2->stuff2()->count('show'=>'real')==0) {
			## this is a failsafe, just in case.. this line should never be reached.
			## 10/20/2009 - kits were were not working - changed from 1+2 to 1+2+8 e.g. toynk 250511435648
			$lm->pooshmsg(sprintf("ISE|+eBay order %s skipped due to no items in cart",$EBAY_ORDERID));
			}
		else {
			## we should create an order
			my @EVENTS = ();

			## ebay sometimes likes to put commas in large numbers.
			$ebordref->{'.OrderTotalCost.content'} =~ s/[^\d\.]+//g;
			$ebordref->{'.OrderTotalCost.content'} = sprintf("%.2f",$ebordref->{'.OrderTotalCost.content'});
				
			my $PAYMENT_TXN = undef;
			my $CREATED_GMT = 0;
			my $EBAY_USER = undef;

			$O2->in_set('our/domain', 'ebay.com');
			# '.TaxAmount.currencyID' => 'USD',
			# '.OrderTotalCost.content' => '30.90',
			$O2->in_set('mkt/order_total', $ebordref->{'.OrderTotalCost.content'});
			$O2->in_set('sum/order_total', $ebordref->{'.OrderTotalCost.content'});

			# '.CheckoutSiteID' => '100',
			$O2->in_set('mkt/siteid', $ebordref->{'.CheckoutSiteID'});

			# '.OrderItemDetails.OrderLineItem.BuyerPaymentTransactionNumber> '1EX64160UV2011615');
			$PAYMENT_TXN = $ebordref->{'.OrderItemDetails.OrderLineItem.BuyerPaymentTransactionNumber'};
			$O2->in_set('mkt/payment_txn',$PAYMENT_TXN);

			#$O2->in_set(('ship.selected_method', $ebordref->{'.ShippingService'});
			# '.OrderCreationTime' => '2009-10-05T01:31:12.000Z',
			$CREATED_GMT = $eb2->ebt2gmt($ebordref->{'.OrderCreationTime'});
			$O2->in_set('mkt/post_date',$CREATED_GMT);


			# '.BuyerPhone' => '201 915 0180',
			$O2->in_set('bill/phone', $ebordref->{'.BuyerPhone'});
			$O2->in_set('bill/firstname', $ebordref->{'.BuyerFirstName'});
			$O2->in_set('bill/lastname', $ebordref->{'.BuyerLastName'});

			# '.BuyerEmail' => 'chrisautousa@wataru.com',
			$O2->in_set('bill/email', $ebordref->{'.BuyerEmail'});

			# '.ShipCountryName' => 'US',
			## stupid eBay:
			if ($ebordref->{'.ShipCountryName'} eq 'APO/FPO') { 
				push @EVENTS, "Seems .ShipCountryName is APO/FPO - so we'll change that to US";
				$ebordref->{'.ShipCountryName'} = 'US'; 
				}
			elsif ($ebordref->{'.ShipCountryName'} eq '') { 
				push @EVENTS, "Seems .ShipCountryName is BLANK - so we'll change that to US";
				$ebordref->{'.ShipCountryName'} = 'US'; 
				}
			elsif ($ebordref->{'.ShipCountryName'} eq 'UK') { 
				push @EVENTS, "Seems .ShipCountryName is 'UK' - so we'll change that to GB";
				$ebordref->{'.ShipCountryName'} = 'GB'; 
				}

			# $O2->in_set('ship/country', &ZSHIP::fetch_country_shipname($ebordref->{'.ShipCountryName'});			);
			$O2->in_set('ship/countrycode', $ebordref->{'.ShipCountryName'});

			if (($ebordref->{'.ShipPostalCode'} eq '') || ($ebordref->{'.ShipStateOrProvince'} eq '')) {
				## sanity marker. -- this would be a GREAT place to create a debug log.
				$olm->pooshmsg("WARNING|+Seems no zip and/or state came from eBay (perhaps an offline [customer pickup] payment method?)");
				}


			# '.ShipCityName' => 'Jersey City',
			$O2->in_set('ship/city', $ebordref->{'.ShipCityName'});
			if ($ebordref->{'.ShipCountryName'} eq 'US') {
				# '.ShipPostalCode' => '07302',
				$O2->in_set('ship/postal', $ebordref->{'.ShipPostalCode'});
				# '.ShipStateOrProvince' => 'NJ',
				$O2->in_set('ship/region', $ebordref->{'.ShipStateOrProvince'});
				}
			else {
				# '.ShipPostalCode' => '07302',
				$O2->in_set('ship/postal', $ebordref->{'.ShipPostalCode'});
				# '.ShipStateOrProvince' => 'NJ',
				$O2->in_set('ship/region', $ebordref->{'.ShipStateOrProvince'});
				}


			# '.ShipRecipientName' => 'Wataru Kanematsu',
			if (index($ebordref->{'.ShipRecipientName'}," ")>0) {
				my ($firstname, $lastname) = split(/[\s]+/,$ebordref->{'.ShipRecipientName'},2);
				$O2->in_set('ship/firstname', $firstname);
				$O2->in_set('ship/lastname', $lastname);
				}
			else {
				$O2->in_set('ship/company', $ebordref->{'.ShipRecipientName'});
				}
			# '.InsuranceCost.currencyID' => 'USD',
			# $O2->in_set(('data.', $ebordref->{'.InsuranceCost.currencyID'});
			# '.ShipStreet1' => '102 Columbus Drive',
			$O2->in_set('ship/address1', $ebordref->{'.ShipStreet1'});
			# '.ShipStreet2' => 'Unit 1004',
			$O2->in_set('ship/address2', $ebordref->{'.ShipStreet2'});


			# '.BuyerUserID' => 'chrisautousa',
			$O2->in_set('mkt/docid',$EBAY_JOBID);
			$O2->in_set('mkt/siteid',$ebordref->{'.ListingSiteID'});
			$EBAY_USER = $ebordref->{'.BuyerUserID'};
			$O2->in_set('mkt/buyerid',$ebordref->{'.BuyerUserID'});
			$O2->in_set('is/origin_marketplace',1);			

			# '.ShippingCost.content' => '5.00',
			# WRONG: $O2->in_set('data.shp_total', $ebordref->{'.ShippingCost.content'});
			## NEED A WAY TO MATCH THE EBAY SHIPPING TO A CARRIER CODE
			$O2->set_mkt_shipping( $ebordref->{'.ShippingService'}, $ebordref->{'.ShippingCost.content'} );

			#$O2->in_set('ship.selected_price', $ebordref->{'.ShippingCost.content'});
			# '.ShippingService' => 'US Postal Service Priority Mail',

			# '.OrderTotalCost.currencyID' => 'USD',
			# $O2->in_set('data.order_total', $ebordref->{'.OrderTotalCost.currencyID'});
			## free shipping adds insurance to order (not sure if this right logic)
			# '.InsuranceCost.content' => '0.00',
			if ($ebordref->{'.InsuranceCost.content'} > 0) {
				# $O2->in_set('ship.ins_total', $ebordref->{'.InsuranceCost.content'});	

				my $insurance_paid = $O2->in_get('mkt/shp_total');
				$insurance_paid -= $ebordref->{'.ShippingCost.content'};
				$insurance_paid -= $ebordref->{'.TaxAmount.content'};

				if ($insurance_paid <= 0) {
					push @EVENTS, "It appears the customer didn't actually purchase optional shipping insurance. (removing it)";
					$O2->surchargeQ('add','ins',0,'Insurance',0,2);
					}
				else {
					$O2->surchargeQ('add','ins',$ebordref->{'.InsuranceCost.content'},'Insurance',0,2);
					}
				}

			# '.OrderItemDetails.OrderLineItem.TaxAmount.currencyID' => 'USD',
			# $O2->in_set(('data.', $ebordref->{'.OrderItemDetails.OrderLineItem.TaxAmount.currencyID'});
			# '.TaxAmount.content' => '0.00',
			# $O2->in_set('data.tax_total', $ebordref->{'.TaxAmount.content'});
			my ($IGNORE_ORDER_TOTALS_DONT_MATCH) = 0;
			if ($ebordref->{'.TaxAmount.content'} > 0) {
				$O2->surchargeQ('add','tax',$ebordref->{'.TaxAmount.content'},'Tax',0,2);
				}



			#elsif (0) {
			#	## IS THIS NECESSARY?
			#	## reverse out the tax rate(s)	
			#	($IGNORE_ORDER_TOTALS_DONT_MATCH) = $O2->guess_taxrate_using_voodoo($ebordref->{'.TaxAmount.content'},src=>'eBay');
			#	}
			#if ($IGNORE_ORDER_TOTALS_DONT_MATCH++) {
			#	push @EVENTS, "OTDM! eBay thinks tax[$ebordref->{'.TaxAmount.content'}]+shipping[$ebordref->{'.ShippingCost.content'}]+itemstotal[$ITEM_TOTALS] = ordertotal[$ebordref->{'.OrderTotalCost.content'}]";
			#	}

			my $PAYMENT_STATUS = undef;
			my $PAYMENT_AMOUNT = $ebordref->{'.PaymentOrRefundAmount.content'};
			if (not defined $PAYMENT_AMOUNT) {
				push @EVENTS, "No PaymentOrRefundAmount specified by eBay, we'll use the OrderTotalCost instead";
				$PAYMENT_AMOUNT = $ebordref->{'.OrderTotalCost.content'};
				}

			if ($O2->in_get('flow/paid_ts')==0) {
				## we won't ACK PAID_GMT orders.
				$PAYMENT_STATUS = '160';
				push @EVENTS, "eBay told us the item isn't paid for yet.";
				}
			elsif (sprintf("%.2f",$O2->in_get('sum/order_total')) == sprintf("%.2f",$PAYMENT_AMOUNT)) {
				## woot, ebay matches our total.
				push @EVENTS, "ebay=$ebordref->{'.OrderTotalCost.content'} total matches zoovy=".$O2->in_get('sum/order_total');
				$PAYMENT_STATUS = '060';
				}
			elsif ($IGNORE_ORDER_TOTALS_DONT_MATCH) {
				push @EVENTS, "we are ignoring non-matching order totals! zoovy=".$O2->in_get('sum/order_total')." vs ebay=$ebordref->{'.OrderTotalCost.content'}";
				$PAYMENT_STATUS = '460';
				}
			elsif (sprintf("%.2f",$O2->in_get('sum/order_total')) != sprintf("%.2f",$PAYMENT_AMOUNT)) {

				if (sprintf("%.2f",$O2->in_get('sum/order_total')) > sprintf("%.2f",$PAYMENT_AMOUNT)) {
					push @EVENTS, "Order was underpaid.  zoovy=".$O2->in_get('sum/order_total')." ebay=$PAYMENT_AMOUNT";
					$PAYMENT_STATUS = '160';
					}
				else {
					$PAYMENT_STATUS = '460';
					push @EVENTS, "Order is OVERPAID. total: zoovy=".$O2->in_get('sum/order_total')." vs ebay=$PAYMENT_AMOUNT";
					}
				}
			else {
				ZOOVY::confess($USERNAME,"Order creation fault - this line should never be reached");
			#	$PAYMENT_STATUS = '060';
			#	push @EVENTS, "received update from ebay txn=$PAYMENT_TXN";
				}

			#$pstmt = "select OUR_ORDERID from EBAY_ORDERS where MID=".$eb2->mid()." and EBAY_ORDERID=".$udbh->quote($EBAY_ORDERID);
			#print $pstmt."\n";
			#my ($OUR_ORDERID) = $udbh->selectrow_array($pstmt);
			if ($olm->can_proceed()) {
				my $ts = time();

				my %params = ();
				$params{'*LM'} = $olm;
				# $cart2{'mkt/siteid'} eq 'cba')
				$O2->in_set('want/create_customer',0);
				$params{'skip_ocreate'} = 1;
				$params{'force_oid'} = $OUR_ORDERID;

				$O2->add_history(sprintf("eBay Large Merchant Services API %d - Z.LMSAPP %s Ps=$$",$eb2->ebay_compat_level(),$::LMS_APPVER));
				foreach my $estr (@EVENTS) {
					# $lm->pooshmsg(sprintf("EVENT|ebayoid=%s|%s",$EBAY_ORDERID,$msg));
					$O2->add_history($estr,ts=>$ts,etype=>2,luser=>'*EBAY');
					}

				## report any finalize errors, add payments before we save.
				if ($ebordref->{'.PaymentOrRefundAmount.content'} > 0) {
					## we found a payment on this order so we'll just apply that and hope everything lines up.
					$olm->pooshmsg(sprintf("SUCCESS|+eBay:%s Zoovy:%s was finalized SUCCESSFULLY, adding payment of $PAYMENT_AMOUNT",$EBAY_ORDERID,$O2->oid()));
					$O2->add_payment('EBAY',$PAYMENT_AMOUNT,'ps'=>$PAYMENT_STATUS,'txn'=>$PAYMENT_TXN );
					}
				else {
					## there was no payment amount, but it's paid, so we'll apply the order_total as the payment amount 
					$olm->pooshmsg(sprintf("SUCCESS|+eBay:%s Zoovy:%s was finalized SUCCESSFULLY (using Order Total)",$EBAY_ORDERID,$O2->oid()));
					$O2->add_payment('EBAY',$O2->in_get('mkt/order_total'),'ps'=>$PAYMENT_STATUS,'txn'=>$PAYMENT_TXN );
					}

				my ($pstmt) = &DBINFO::insert($udbh,'EBAY_ORDERS',{
					'*CREATED'=>'now()',
					'USERNAME'=>$eb2->username(),
					'MID'=>$eb2->mid(),
					'EBAY_EIAS'=>$eb2->ebay_eias(),				
					'EBAY_JOBID'=>$EBAY_JOBID,
					'EBAY_ORDERID'=>$EBAY_ORDERID,
					'EBAY_STATUS'=>'Active',
					'PAY_METHOD'=>'EBAY',
					'PAY_REFID'=>$PAYMENT_TXN,
					'APPVER'=>$::LMS_APPVER,
					'OUR_ORDERID'=>"$OUR_ORDERID",
					},'verb'=>'insert','sql'=>1);
				$udbh->do($pstmt);
				
				$params{'our_orderid'} = $OUR_ORDERID;
				($olm) = $O2->finalize_order(%params);

				if ($O2->oid()) {
					}
				else {
					$olm->pooshmsg("SKIP|+Order creation was skipped due to previous errors");
					}
				}
			## REMEMBER: if the order is success - then ACK it!
			}

		#if ($ebordref->{'.TaxAmount.content'}>0) {
		#	}

		if ($olm->had(['ISE','ERROR','WAIT','SKIP'])) {
			## we don't ACKNOWLEDGE these
			print Dumper($olm);
			}
		elsif ($olm->had(['STOP','SUCCESS'])) {
			foreach my $item (@{$ord->{'OrderItemDetails'}->[0]->{'OrderLineItem'}}) {	
				my $itemref = &ZTOOLKIT::XMLUTIL::SXMLflatten($item);
				push @ORDERACKS, { OrderID=>$EBAY_ORDERID,OrderLineItemID=>$itemref->{'.OrderLineItemID'} };
				}			
			}
		else {
			$olm->pooshmsg("ISE|+UNKNOWN ACK/UNACK STATUS -- NOT ISE,ERROR,WAIT,SKIP *or* STOP,SUCCESS");
			print Dumper($olm);
			die();
			}

		if (defined $paramsref->{'ebayoid'}) { die(); }
		$lm->merge($olm,'%mapstatus'=>{'STOP'=>'ORDER-STOP','SKIP'=>'ORDER-SKIP','WAIT'=>'ORDER-WAIT','SUCCESS'=>'ORDER-SUCCESS'});
		}

	## now summary size all the messages
	my $ORDER_AVOIDED = 0;
	my $ORDER_SUCCESS = 0;
	my $MSG_ERRORS = 0;
	my $MSG_WARNINGS = 0;
	
	foreach my $msg (@{$lm->msgs()}) {
		my ($ref) = &LISTING::MSGS::msg_to_disposition($msg);
		if (($ref->{'_'} eq 'WARN') || ($ref->{'_'} eq 'WARNING')) { $MSG_WARNINGS++; }
		if (($ref->{'_'} eq 'ERROR') || ($ref->{'_'} eq 'ISE')) { $MSG_ERRORS++; }
		if (($ref->{'_'} eq 'ORDER-STOP') || ($ref->{'_'} eq 'ORDER-SKIP') || ($ref->{'_'} eq 'ORDER-WAIT')) { $ORDER_AVOIDED++; }
		if ($ref->{'_'} eq 'ORDER-SUCCESS') { $ORDER_SUCCESS++; }
		}
	$lm->pooshmsg(sprintf("SUMMARY-ORDERS|+New-Orders:%d Pending-Orders:%d Warn-Msgs:%d Error-Msgs:%d",$ORDER_SUCCESS,$ORDER_AVOIDED,$MSG_WARNINGS,$MSG_ERRORS));

	if (my $iseref = $lm->had(['ISE'])) {
		## if we got an ise don't ack anything!
		&ZOOVY::confess($USERNAME,"EBAY ISE $iseref->{'+'}\n".Dumper($lm),justkidding=>0);
		$lm->pooshmsg(sprintf("SUMMARY-ORDERACK|+Order Ack skipped due to internal-error (ISE) in ORDER feed."));
		}
	elsif (scalar(@ORDERACKS)>0) {
		## we do a getJobs -- because we can only do one orderAck
		my ($xUUID,$xresult) = $eb2->bdesapi('getJobs',{'jobType'=>'OrderAck','jobStatus'=>'Created'},output=>'flat');
		# print Dumper($xresult)."\n";

		my ($UUID,$RESULT) = $eb2->ftsupload('OrderAck',\@ORDERACKS);
		# print Dumper($UUID,$RESULT);

		if ($RESULT->{'.ack'} eq 'Success') {
			$lm->pooshmsg(sprintf("SUMMARY-ORDERACK|+Acknowledged %d orders",scalar(@ORDERACKS)));
			$lm->pooshmsg("SUCCESS|+Complete");
			}
		else {
			## NOTE: it's normal to get failures here because we often send multiple ack jobs at the same time 
			##			and ebay would prefer if we sent it is as one big job.
			my $debugfile = "/tmp/ebay/orderack-$USERNAME.xml";
			open F, ">$debugfile"; 	print F Dumper($xresult);	close F;	
			$lm->pooshmsg(sprintf("SUMMARY-ORDERACK|+Did not get success on OrderAck .ack=$RESULT->{'.ack'} [debug:$debugfile]"));
			}
		}
	else {
		$lm->pooshmsg("SUMMARY-ORDERACK|+No orders to Acknowledge");
		$lm->pooshmsg("SUCCESS|+Nothing to do");
		}

	if (not $lm->can_proceed()) {
		# shit happened.
		}
	elsif ($lm->has_win()) {
		}
	else {
		# warn "Seems odd that we finished with no orders, but I'm setting setting YAY_WE_FINISHED to 1";
		$lm->pooshmsg("SUCCESS|+Done processing orders and acks.");
		}

	my $PRT = $eb2->prt();
	my $TXLOG = TXLOG->new();
	my $qtTXLOG = $udbh->quote($lm->status_as_txlog('@'=>\@SYNDICATION::TXMSGS)->serialize());
	my $pstmt = "update SYNDICATION set TXLOG=concat($qtTXLOG,TXLOG) where MID=$MID /* $USERNAME */ and DSTCODE='EBF'";
	print STDERR "$pstmt\n";
	$udbh->do($pstmt);

	# &DBINFO::task_lock($USERNAME,"ebay-orders","UNLOCK");
	&DBINFO::db_user_close();

	return();
	}






1;

