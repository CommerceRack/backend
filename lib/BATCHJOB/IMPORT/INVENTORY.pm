package BATCHJOB::IMPORT::INVENTORY;

use strict;
use lib "/backend/lib";
require INVENTORY2;
require PRODUCT;
require PRODUCT::BATCH;
require ZTOOLKIT::FAKEUPC;
require PRODUCT::FLEXEDIT;

use Data::Dumper;

##
## Allowed columns
##
##
##	changes on 5/6/2011
##	- #CHECKSKU now works for options and products (ie was broken for products)
## - zoovy:base_cost/price now update in the SKU (options and products)
## 
## to support backward compatibility $obj can be either a BATCHJOB object or a LUSER object.
##
sub parseinventory {
	my ($bj,$fieldsref,$lineref,$optionsref,$ERRORSREF) = @_;

	my ($USERNAME,$LUSERNAME,$PRT) = ($bj->username(),$bj->lusername(),$bj->prt());
	my $udbh = &DBINFO::db_user_connect($USERNAME);

	my $SAFETY = $optionsref->{'SAFETY'};
	if (not defined $SAFETY) { $SAFETY = 0; }

	my ($LM) = LISTING::MSGS->new($USERNAME,stderr=>1);
	my ($INV2) = INVENTORY2->new($USERNAME,$LUSERNAME);

	my %INITCMD = ();
	my $USERFIELDS = &PRODUCT::FLEXEDIT::userfields( $USERNAME );
	## import headers as commands.

	## NOTE: INCREMENTAL ON/OFF was removed in version 201344
	$INITCMD{'CMD'} = 'SET';
	if ($optionsref->{'INCREMENTAL'}) {
		$INITCMD{'CMD'} = ($optionsref->{'INCREMENTAL'})?'ADD':'SET';
		}

	if (($optionsref->{'SUPPLIER'}) || ($optionsref->{'SUPPLIER_ID'})){
		$INITCMD{'SUPPLIER_ID'} = $optionsref->{'SUPPLIER_ID'} || $optionsref->{'SUPPLIER'};
		}

	## HEADERS are passed in from the user interface, specified by user via checkboxes, etc.
	if ($optionsref->{'HEADERS'}) {
		foreach my $kv (split(/\|/,$optionsref->{'HEADERS'})) {
			my ($k,$v) = split(/\=/,$kv,2);
			$INITCMD{$k} = $v;
			}
		}

	foreach my $HEADER ('CMD','WMS_GEO','WMS_ZONE','WMS_POS','MARKET_DST') {
		if ($optionsref->{$HEADER}) { $INITCMD{$HEADER} = $optionsref->{$HEADER}; }
		}

	if (($INITCMD{'SUPPLIER_ID'} ne '') && ($INITCMD{'BASETYPE'} eq '')) {
		$INITCMD{'BASETYPE'} = 'SUPPLIER';
		}

	if ( ($INITCMD{'CMD'} eq '') && ($INITCMD{'BASETYPE'} eq 'SIMPLE') ) {
		$INITCMD{'CMD'} = 'SET';
		}


	# print STDERR 'OPTIONSREF: '.Dumper($optionsref,\%INITCMD,$lineref)."\n";

	my $linecount = 1;		## let's start with 1, so it makes sense to merchant
	foreach my $line (@{$lineref}) {
		my %INVCMD = %INITCMD;
		my %prodattribs = ();

		my $ERROR = undef;
		my @DATA = ();
		if (ref($line) eq 'ARRAY') {
			@DATA = @{$line};
			}
		else {
			## OLD WAY (i don't think this is used anymore)
			@DATA = &ZCSV::parse_csv($line,$optionsref);
			}

		my $pos = 0; # $pos keeps track of which field in the @DATA array we are on.
		foreach my $destfield (@{$fieldsref}) {	

			$destfield =~ s/^[\s]+//g; 	# strip spaces.
			$destfield =~ s/[\s]+$//g;


			if ($DATA[$pos] eq '') { 
				# Skip blank fields
				}
			elsif ($destfield eq '') {
				## ignore blank fields.
				} 
			elsif (substr($destfield,0,1) eq '%') {
				$DATA[$pos] =~ s/^[\s]+//gs;	## we're gonna strip leading and trailing spaces on command fields.
				$DATA[$pos] =~ s/[\s]+$//gs;		
				if ( ($destfield eq '%UUID') && ($DATA[$pos] ne '')) { 
					$INVCMD{'UUID'} = $DATA[$pos];
					}
				elsif ($destfield eq '%SKU' && $DATA[$pos] ne '') { 
					($INVCMD{'SKU'}) = $DATA[$pos]; 
					}
				elsif ( ($destfield eq '%PID') && ($DATA[$pos] ne '')) { 
					$INVCMD{'PID'} = $DATA[$pos];
					}
				elsif ( ($destfield eq '%MARKET_DST') && ($DATA[$pos] ne '')) { 
					if (not defined $INVCMD{'BASETYPE'}) { $INVCMD{'BASETYPE'} = 'MARKET'; }
					$INVCMD{'MARKET_DST'} = $DATA[$pos];
					}
				elsif ( ($destfield eq '%MARKET_REFID') && ($DATA[$pos] ne '')) { 
					$INVCMD{'MARKET_REFID'} = $DATA[$pos];
					}
				elsif (($destfield eq '%UPC') && ($DATA[$pos] ne '')) { 
					if ($INVCMD{'SKU'} ne '') {
						($INVCMD{'SKU'}) = &PRODUCT::BATCH::resolve_sku($USERNAME,'UPC',$DATA[$pos]); 
						}
					}
				elsif (($destfield eq '%ASIN') && ($DATA[$pos] ne '')) { 
					if ($INVCMD{'SKU'} ne '') {
						($INVCMD{'SKU'}) = &PRODUCT::BATCH::resolve_sku($USERNAME,'ASIN',$DATA[$pos]); 
						}
					}
				elsif (($destfield eq '%MFGID') && ($DATA[$pos] ne '')) { 
					if ($INVCMD{'SKU'} ne '') {
						($INVCMD{'SKU'}) = &PRODUCT::BATCH::resolve_sku($USERNAME,'MFGID',$DATA[$pos]); 
						}
					}
				elsif (($destfield eq '%SUPPLIER_SKU') && ($DATA[$pos] ne '')) {
					my $SUPPLIER_ID = $optionsref->{'SUPPLIER_ID'} || $optionsref->{'SUPPLIER'};

					$INVCMD{'SUPPLIER_SKU'} = $DATA[$pos];
					if ($INVCMD{'SKU'} eq '') {
						($INVCMD{'SKU'}) = &PRODUCT::BATCH::resolve_sku($USERNAME,'SUPPLIER_SKU',$DATA[$pos],'SUPPLIER'=>$SUPPLIER_ID);
						}

					}
				## it would be nice to do supplier lookup here as well.
				elsif ( ($destfield eq '%QTY')  && $DATA[$pos] ne '') { 
					$INVCMD{'QTY'} = $DATA[$pos]; 
					}
				elsif ( ($destfield eq '%NOTE') && ($DATA[$pos] ne '')) { 
					$INVCMD{'NOTE'} = $DATA[$pos]; 
					if ($INVCMD{'NOTE'} eq '_') { $INVCMD{'NOTE'} = ''; }
					}
				elsif ( ($destfield eq '%WMS_GEO') && ($DATA[$pos] ne '')) { 
					if (not defined $INVCMD{'BASETYPE'}) { $INVCMD{'BASETYPE'} = 'WMS'; }
					$INVCMD{'GEO'} = $DATA[$pos]; 
					}
				elsif ( ($destfield eq '%WMS_ZONE') && ($DATA[$pos] ne '')) { 
					$INVCMD{'ZONE'} = $DATA[$pos]; 
					}
				elsif ( ($destfield eq '%WMS_POS') && ($DATA[$pos] ne '')) { 
					$INVCMD{'POS'} = $DATA[$pos]; 
					}
				elsif ( ($destfield eq '%WMS_LOC') && ($DATA[$pos] ne '')) { 
					$INVCMD{'LOC'} = $DATA[$pos]; 
					}
				elsif ( ($destfield eq '%BASETYPE') && ($DATA[$pos] ne '')) { 
					$INVCMD{'BASETYPE'} = $DATA[$pos];
					}
				elsif ( ($destfield eq '%COST') && ($DATA[$pos] ne '')) { 
					$INVCMD{'COST'} = $DATA[$pos];
					}
				elsif ( (($destfield eq '%SUPPLIER_ID') || ($destfield eq '%SUPPLIER')) && ($DATA[$pos] ne '')) { 
					if (not defined $INVCMD{'BASETYPE'}) { $INVCMD{'BASETYPE'} = 'SUPPLIER'; }
					$INVCMD{'SUPPLIER_ID'} = $DATA[$pos];
					}
				elsif ( ($destfield eq '%SUPPLIER_SKU') && ($DATA[$pos] ne '')) { 
					$INVCMD{'SUPPLIER_SKU'} = $DATA[$pos];
					}
				elsif ( ($destfield eq '%CMD') && ($DATA[$pos] ne '')) { 
					$INVCMD{'CMD'} = $DATA[$pos];
					}
				else {
					$ERROR = "UNKNOWN CSV HEADER: $destfield"; 
					}				
				} 
			else {
				## zoovy:prod_upc, zoovy:prod_mfgid, zoovy:prod_supplierid
				## zoovy:base_price, zoovy:base_cost are now also allowed
				$prodattribs{$destfield} = $DATA[$pos];
				}
			$pos++;  # move to the next field that we should parse
			}


		print STDERR 'INVCMD: '.Dumper(\%INVCMD);

		if ($ERROR) {
			}
		elsif (! $INVCMD{'CMD'}) {
			## ERROR: INVALID CMD
			$ERROR = "NO CMD specified";
			}
		elsif ( (!$INVCMD{'SKU'}) && (!$INVCMD{'UUID'}) && (!$INVCMD{'PID'}) ) {
			## ERROR: NO SKU/UUID
			$ERROR = "NO UUID,SKU, or PID specified";
			}
		elsif (not $optionsref->{'CHECKSKU'}) {
			## no error, no check.
			}
		elsif ((not defined $INVCMD{'PID'}) && (not defined $INVCMD{'SKU'})) {
			$ERROR = "CHECKSKU FAILURE - NO PID/SKU FOUND";
			}
		elsif ( (defined($INVCMD{'PID'})) && (!&ZOOVY::productidexists($USERNAME,$INVCMD{'PID'})) ) {		
			$ERROR = "CHECKSKU - INVALID PID";
			}
		elsif ( (defined($INVCMD{'SKU'})) && (!&ZCSV::skuexists($USERNAME,$INVCMD{'SKU'}))  ) {	
			$ERROR = "CHECKSKU - INVALID SKU";
			}

		## only do SKU updates

		if ($ERROR) {
			warn "ERROR: $ERROR\n";
			}
		else {
		#	if (defined($optionsref->{'ENABLEINVENTORY'}) && ($optionsref->{'ENABLEINVENTORY'}>0)) {
		#		my ($P) = PRODUCT->new($USERNAME,$SKU);	
		#		$P->store('zoovy:inv_enable',1);
		#		$P->save();
		#		# &ZOOVY::saveproduct_attrib($USERNAME,$SKU,'zoovy:inv_enable',1);		
		#		if (defined $bj) { $bj->slog("Enabling inventory for $SKU setting to zoovy:inv_enable\n"); }
		#		}
		#	if (($SAFETY>0) && ($SAFETY>=$QTY)) {
		#		if (defined $bj) { $bj->slog("---> warning: qty of $QTY is less than safety qty of $SAFETY"); }
		#		$QTY = 0;
		#		}

			# print "CMD:$INVCMD{'CMD'} ".Dumper(\%INVCMD)."\n";
 			my ($MSGS) = $INV2->invcmd($INVCMD{'CMD'},%INVCMD,'APPID'=>sprintf("b#%d",$bj->id()),'*LM'=>$LM);
			if (not $LM->can_proceed()) {
				my ($msg) = $LM->whatsup();
				$ERROR = "ERROR|$msg->{'+'}";
				}

			## make sure we sync the right stuff
			if ($INVCMD{'PID'}) { $INV2->synctag($INVCMD{'PID'}); }
			elsif ($INVCMD{'SKU'}) { my ($PID) = &PRODUCT::stid_to_pid($INVCMD{'SKU'}); $INV2->synctag($PID); }
			elsif ($INVCMD{'UUID'}) { 
				my ($DETAIL) = $INV2->uuid_detail($INVCMD{'UUID'});
				$INV2->sync($DETAIL->{'PID'});
				}

			#if (defined $QTY) {
			#	## &INVENTORY::add_incremental($USERNAME,$SKU,$TYPE,int($QTY),'APPID'=>sprintf("b#%d",$bj->id()));
			#	$INV2->skuinvcmd($SKU,$CMD,'QTY'=>int($QTY),'APPID'=>sprintf("b#%d",$bj->id()));
			#	if (defined $bj) { $bj->slog("---> updated $SKU = $QTY (line $linecount)");  }
			#	}
			#if (defined $LOCATION) {
			#	if ($LOCATION ne '') {
			#		## don't update blank locations.
			#		## &INVENTORY::set_meta($USERNAME,$SKU,'LOCATION'=>$LOCATION);
			#		$INV2->skuinvcmd($SKU,"ANNOTATE","NOTE"=>$LOCATION,'APPID'=>sprintf("b#%d",$bj->id()));
			#		if (defined $bj) { $bj->slog("---> updated $SKU = LOCATION: $LOCATION"); }
			#		}
			#	}
			#if (defined $MIN_QTY) {
			#	$prodattribs{'sku:inv_reorder'} = $MIN_QTY;
			#	# &INVENTORY::set_meta($USERNAME,$SKU,'REORDER_QTY'=>$MIN_QTY);
			#	if (defined $bj) { $bj->slog("---> updated $SKU MIN_QTY: $MIN_QTY (line $linecount)"); }
			#	}

			## any zoovy: attribs sent? ie zoovy:base_price, zoovy:prod_supplierid, etc					
			if (scalar(keys(%prodattribs))>0) {
				## note: im sure this isnt the best way to determine if SKU is an option
				##		but i wanted it to be fast and simple

				my ($PID) = $INVCMD{'PID'};
				if ((not defined $PID) || ($PID eq '')) { ($PID) = &PRODUCT::stid_to_pid($INVCMD{'SKU'}); }
				my ($P) = PRODUCT->new($USERNAME,$PID);

				my %SKU_FIELDS = ();
				foreach my $k (keys %PRODUCT::FLEXEDIT::fields) {
					if ($PRODUCT::FLEXEDIT::fields{$k}->{'sku'}==1) {
						$SKU_FIELDS{ $k }++;
						}
					}
				foreach my $fieldset (@{$USERFIELDS}) {
					if ($prodattribs{$fieldset->{'id'}}) {
						$SKU_FIELDS{ $fieldset->{'id'} } = 0; 
						if ($fieldset->{'sku'}) { $SKU_FIELDS{ $fieldset->{'id'} } = 1; }
						}
					}


				## sanity: at this point %SKU_FIELDS knows which fields are sku=>1

				foreach my $k (keys %prodattribs) {
					if (not $SKU_FIELDS{$k}) {
						$P->store($k,$prodattribs{$k});
						}
					elsif ($INVCMD{'SKU'} eq $PID) {
						$P->store($k,$prodattribs{$k});
						}
					elsif ($INVCMD{'SKU'} =~ /:/) { 
						$P->skustore($INVCMD{'SKU'},$k,$prodattribs{$k});
						}
					}

				if ($P->_changes()) {
					$P->save();
					if (defined $bj) { $bj->slog("---> saving prodref for SKU: $INVCMD{'SKU'}\n"); }
					## if option, save back to %SKU if change made
					## update the sku (%SKU in the product hashref) with params like
					## 	zoovy:prod_upc, zoovy:prod_mfgid, zoovy:prod_supplierid
					}
				}
			}

		if ($ERROR) {
			push @{$ERRORSREF}, "ERROR|+[$linecount] $ERROR";
			}

 
		$linecount++;
		}

	if (defined $bj) { $bj->slog("---> syncing summaries\n"); }
	$INV2->sync();

	&DBINFO::db_user_close();
	return();
	}



1;