
package BATCHJOB::IMPORT::TRACKING;

##
##	import tracking information into orders 
##
## example options:
##
##	#STATUS=COMPLETED          ## order has already been shipped
##	#SUPPLIER=code             ## Supplier code, so supplier order can be confirmed
##	#DST=dstcode					## marketplace destination code, EGG, FBA, etc --- this may be used in the future to resolve orderid from erefid
##	#SEP_CHAR=\t					## how the import file is separated ( , \t ), default (,)
##
##
## possible column headers:
##
## %ORDERID					=> Zoovy OrderID		(REQUIRED, unless using ORDER_EREFID/DST)
## %EREFID					=> Order erefid (marketplace orderid)
## %DST						=> dstcode for the marketplace		--- this may be used in the future to resolve orderid from erefid
## %SHIPPING_CARRIER		=> carrier: UPS, FEDX, USPS
## %TRACKING_NUMBER		=> tracking number
## %NOTES					=> tracking notes
## %DECLARED_VALUE		=> declared value of order for intl orders
## %INS_PROV				=> insurance provider for intl orders
## %COST						=> actual cost, vs what was quoted to customer
## %WEIGHT					=> actual weight, vs what is in the order
## %CONF_PERSON			=> person/api inputing tracking
##	
##

use strict;
use lib "/backend/lib";
require CART2;
use ZCSV;
use SUPPLIER;
use Data::Dumper;


sub parsetracking {
	my ($bj,$fieldsref,$lineref,$optionsref) = @_;

	my ($USERNAME,$LUSERNAME,$PRT) = ($bj->username(),$bj->lusername(),$bj->prt());

	## all these GLOBAL vars can be set in the header
	# STATUS => RECENT,PENDING,APPROVED,COMPLETED,DELETED,ARCHIVE,BACKORDER
	## defaults to RECENT
	my $GLOBAL_STATUS = $optionsref->{'STATUS'}; 
	my $GLOBAL_SUPPLIER = $optionsref->{'SUPPLIER'};
	my $GLOBAL_DST = $optionsref->{'DST'};

	# SEPARATOR
	## defaults to comma [,]
	my $SEP_CHAR = ($optionsref->{'SEP_CHAR'} ne '')?$optionsref->{'SEP_CHAR'}:',';
	my $ctr = 0;


	## Step 1 - go thru each CSV line, assign variables
	$bj->slog("Step 1 - go thru each CSV line, assign variables");	
	foreach my $line ( @{$lineref} ) {
		## create temp hash to hold order contents
		my %order = ();

		my %trk = ();
		my($ORDERID,$OID_from_EREF,$CONF_PERSON,$DST,$EREFID) = '';
		
		my $ERROR = '';	## ERROR's are per line

		my @DATA = &ZCSV::parse_csv($line,{SEP_CHAR=>$SEP_CHAR});
		next if ($DATA[0] =~ /^\#/);		## skip header lines


		## Step 2 - go thru columns, populate order hash		
		$bj->slog("Step 2 - go thru columns, populate order hash, LINE: $ctr");	
		my $pos = 0; # $pos keeps track of which field in the @DATA array we are on.
		foreach my $destfield (@{$fieldsref}) {	
			if ($ERROR eq '') {
				# Skip blank fields
				if ($destfield eq '' || $DATA[$pos] eq '')  {
					} 
				## ignore columns that start with a !
				elsif (substr($destfield,0,1) eq '!') {
					}
				# % fields
				elsif (substr($destfield,0,1) eq '%') {

					if ($destfield eq '%ORDERID' && $DATA[$pos] ne '') { $ORDERID = $DATA[$pos]; }
					if ($destfield eq '%EREFID' && $DATA[$pos] ne '') {
						$EREFID = $DATA[$pos]; 
						$OID_from_EREF = CART2::lookup($USERNAME,'EREFID',$EREFID);
						$bj->slog("Step 2. found oid from erefid data_pos: $DATA[$pos] $OID_from_EREF");
						}
					if ($destfield eq '%DST' && $DATA[$pos] ne '') { $DST = $DATA[$pos]; }
					if ($destfield eq '%SHIPPING_CARRIER') { $destfield = '%CARRIER'; }	# changed 12/14/12

					if ($destfield eq '%CARRIER' && $DATA[$pos] ne '') { 
						my $carrier = uc($DATA[$pos]); 

						my $shipref = ZSHIP::shipinfo($carrier);
						## couldn't find a match
						if ($shipref->{'is_error'} == 1) {
							if ($carrier eq 'SMARTPOST') {
								$trk{'carrier'} = 'FEDX';        ## FEDEX
								}	
							else { 
								$trk{'carrier'} = 'OTHR'; 
								}
							}
						## otherwise, use the carrier defined in ZSHIP
						else {
							$trk{'carrier'} = $shipref->{'carrier'};
							}
						}
					if ($destfield eq '%TRACKING_NUMBER' && $DATA[$pos] ne '') { $trk{'track'} = $DATA[$pos]; }
					if ($destfield eq '%NOTES' && $DATA[$pos] ne '') { $trk{'notes'} = $DATA[$pos]; }
					if ($destfield eq '%DECLARED_VALUE' && $DATA[$pos] ne '') { $trk{'dval'} = $DATA[$pos]; }
					if ($destfield eq '%INS_PROV' && $DATA[$pos] ne '') { $trk{'ins'} = $DATA[$pos]; }
					if ($destfield eq '%COST' && $DATA[$pos] ne '') { $trk{'cost'} = $DATA[$pos]; }
					if ($destfield eq '%WEIGHT' && $DATA[$pos] ne '') { $trk{'actualwt'} = $DATA[$pos]; }
					if ($destfield eq '%CONF_PERSON' && $DATA[$pos] ne '') { $CONF_PERSON = $DATA[$pos]; }
					}	## end of % fields
				}

			$pos++;  # move to the next field that we should parse
			} # end of column loop, Step 2

		## Step 3 - determine what order id to use and create order object
		my $O2 = undef;
		if ($ERROR eq '') {
			if ($ORDERID ne '') {
				($O2) = CART2->new_from_oid($USERNAME,$ORDERID);
				$bj->slog("Step 3 - trying to use ORDERID: $ORDERID for order");	
				}

			## use erefid to create $o object
			if ((not defined $O2) && $OID_from_EREF ne '') {
				($O2) = CART2->new_from_oid($USERNAME,$OID_from_EREF );
				$ORDERID = $OID_from_EREF;
				$bj->slog("Step 3 - using OID_from_EREF: $OID_from_EREF for order");	
				}

			if (not defined $O2) {
				$ERROR = "Unable to create order object";
				}	
			}

		## Step 4 - confirm SUPPLIER order
		if ($ERROR eq '') {
			$bj->slog("Step 4 - confirming order for SUPPLIER??");
			#confirm Supplier order (in the SUPPLIER ORDER table)
			if ($GLOBAL_SUPPLIER ne '') {
				$bj->slog("Step 4 - confirming order for SUPPLIER: $GLOBAL_SUPPLIER");
				#($USERNAME, $srcorder, $supplierorderid, $conf_ordertotal, $ship_method, $ship_num, $conf_person, $conf_email, $supplier_orderitem)
				SUPPLIER::confirm_order($USERNAME,$ORDERID,$EREFID,'0.00',$trk{'carrier'},$trk{'track'},$CONF_PERSON,'NA','NA');
				}
			}
	
		## Step 5 - add tracking to order
		if ($ERROR eq '') {
			## add tracking to order
			$bj->slog("Step 5 - add tracking directly to orderid: $ORDERID");
			$O2->set_trackref(\%trk);
			}	

		## Step 6 - update order status
		if ($ERROR eq '' && $GLOBAL_STATUS ne '') {
			$bj->slog("Step 6 - update order status to $GLOBAL_STATUS");	
			$O2->in_set('our/pool',$GLOBAL_STATUS);
			}
	
		## Step 7 - report any line errors or save order
		if ($ERROR ne '') {
			$bj->slog("Step 7 - ERROR occured on line $ctr: ".$ERROR);
			}
		else {
			$bj->slog("Step 7 - No ERRORS! save it");	
			$O2->order_save();
			}

		$ctr++;
		}	## end of line loop
	}

1;
