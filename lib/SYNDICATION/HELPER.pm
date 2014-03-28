package SYNDICATION::HELPER;

##
## note: this module is very lite, intended to be called from within WEBDOC so it cannot reference
##			the SYNDICATION object itself.
##

use strict;
use Data::Dumper;
require PRODUCT::FLEXEDIT;
require ZSHIP;

sub get_headers {
	my ($dst) = @_;

	use File::Slurp;
	open F, "</httpd/static/syndication/$dst/mapping.dmp";
	my $data = ''; while (<F>) { 
		next if ($_ =~ /^[\s]*#/);	 #skip comments in file
		$data .= $_; 
		} 
	close F;
	
	# print $data;
	my $VAR1 = eval("$data;");
	return($VAR1);
	}


sub FORMAT_textify {
	my ($val) = @_;
	$val =~ s/<java.*?>.*?<\/java.*?>//gis;
	$val =~ s/<script.*?<\/script>//gis;

	## strip out advanced wikitext (%softbreak%, %hardbreak%)
	$val =~ s/%\w+%//gs;

	$val =~ s/<.*?>//gs;
	$val =~ s/[\t]+/ /g;
	$val =~ s/[^\"\w\.\:\:\!\@\#\$\%\^\&\*\(\)]+/ /g;
	$val =~ s/[\n\r]+//gs;		
	return($val);
	}

##
##
##
sub FORMAT_lookup_category {
	my ($so, $category) = @_;

	my ($CDS) = $so->{'_CDS'};
	if (not defined $CDS) {	
		require SYNDICATION::CATEGORIES;
		$CDS = SYNDICATION::CATEGORIES::CDSLoad($so->dstcode());
		$so->{'_CDS'} = $CDS;
		}

	my ($iref) = SYNDICATION::CATEGORIES::CDSInfo($CDS,$category);
	if (not defined $iref) {
		return(undef);
		}
	return($iref->{'Path'});
	}



sub do_product {
	my ($SO,$COLUMNSREF,$SPECIALREF,$SKU,$P,$plm) = @_;

	my @data_array = ();
	my %data_hash = ();


	$SPECIALREF->{'%PRODUCTID'} = $SKU;

	# print Dumper($COLUMNSREF);

	foreach my $col (@{$COLUMNSREF}) {
		next if (not $plm->can_proceed());

		my $RESULT = undef;
		my @LOGIC = ();

		my $FIRST_TRY_ATTRIB = undef;
		if ((defined $col->{'@try'}) && (scalar($col->{'@try'})>0)) {
			push @LOGIC, "$col->{'header'} START";
			foreach my $try (@{$col->{'@try'}}) {
				#next if (defined $RESULT);
				if (defined $RESULT) {
					push @LOGIC, "$col->{'header'} RESULT ALREADY SET - SKIPPING: $try";
					next;
					}

				push @LOGIC, "$col->{'header'} TRYING: $try";
				if (not defined $FIRST_TRY_ATTRIB) { $FIRST_TRY_ATTRIB = $try; }

				if ($try eq '') { 
					push @LOGIC, "$col->{'header'} TRY is set to BLANK value";
					$RESULT = ''; 
					}
				elsif (substr($try,0,1) eq '%') {
					if ($try eq '%PRODUCTID') { $RESULT = uc($SKU); }
					elsif ($try =~ /%CONSTANT\:(.*?)$/) { $RESULT = $1; }
					elsif (defined $SPECIALREF->{$try}) { $RESULT = $SPECIALREF->{$try}; }
					else {
						$plm->pooshmsg("ISE|+Unhandled special case %try [$try]");
						}
					if (defined $RESULT) {
						push @LOGIC, "$col->{'header'} $try set RESULT to '$RESULT'";
						}
					}
				elsif ($try =~ /^[a-z0-9]+\:[a-z0-9\_\-]+$/o) {
					## YAY, we have an attribute 
					if (defined $SPECIALREF->{ $try }) {
						## special (OVERRIDES) always win!
						$RESULT = $SPECIALREF->{$try};
						}
					elsif ( $SKU =~ /:/ ) {
						## this is a sku
						if ($PRODUCT::FLEXEDIT::fields{ $try }->{'sku'}) {
							## this is a sku field
							push @LOGIC, "$col->{'header'} $try will use skufetch($SKU)";
							$RESULT = $P->skufetch($SKU,$try);
							if (not defined $RESULT) {
								push @LOGIC, "$col->{'header'} $try found nothing in sku, try product record.";
								$RESULT = $P->fetch($try);
								}
							}
						else {
							## not a SKU field
							$RESULT = $P->fetch($try);
							}
						}
					else {
						## product field.
						$RESULT = $P->fetch($try);
						}
				
					if (not defined $RESULT) {
						push @LOGIC, "$col->{'header'} $try .. not configured.";
						}	
					elsif (not $plm->can_proceed()) {}		# skip if we' got an error already!
					elsif ((defined $col->{'@format'}) && (scalar($col->{'@format'})>0)) {

						push @LOGIC, "$col->{'header'} BEFORE FORMAT: $RESULT";
						foreach my $format (@{$col->{'@format'}}) {
							next if (not defined $RESULT);
							my $format_params = $col->{"%params-$format"};
							
							if (index($format,'?')>0) {
								## if format has parameters then parse them ex: format?x=y
								## remember, this is a foreach so it's a reference to the actual array in memory!
								$format_params = &ZTOOLKIT::parseparams(substr($format,index($format,'?')+1));
								$format = substr($format,0,index($format,'?'));
								$col->{"%params-$format"} = $format_params;
								#print Dumper($col);
								}
							# print "FORMAT: $format ".Dumper($format_params)."\n";

							if ($format eq 'textify') { 
								$RESULT = &SYNDICATION::HELPER::FORMAT_textify($RESULT);
								}
							elsif ($format eq 'htmlstrip') { 
								$RESULT = &ZTOOLKIT::htmlstrip($RESULT);
								}
							elsif ($format eq 'wikistrip') { 
								$RESULT = &ZTOOLKIT::wikistrip($RESULT);
								}
							elsif ($format eq 'stripunicode') { 
								$RESULT = &ZTOOLKIT::stripUnicode($RESULT);
								}
							elsif ($format eq 'boolean-opposite') {
								$RESULT = (not $RESULT);
								}
							elsif ($format eq 'boolean-truefalse') {
								$RESULT = (($RESULT)?'true':'false');
								}
							elsif ($format eq 'trim') {
								# print Dumper($format_params);
								if ($format_params->{'bytes'}) {
									$RESULT = substr($RESULT,0,$format_params->{'bytes'});
									}
								else {
									$plm->pooshmsg("ISE|+formattor /trim/ requires 'bytes' parameter to be specified".Dumper($format_params));
									}
								}
							elsif ($format eq 'currency' || $format eq 'currency-with-USD') {
								$RESULT = sprintf("%.2f",$RESULT);
								## added for googlebase
								if ($format eq 'currency-with-USD') {
									$RESULT .= " USD";
									}
								}
							elsif ($format eq 'imageurl') {
								if ($RESULT ne '') { 
									## default height and width to 0 if they aren't defined
									my $h = (int($format_params->{'h'}) > 0)?$format_params->{'h'}:0; 
									my $w = (int($format_params->{'w'}) > 0)?$format_params->{'w'}:0;

									## static---username.whatever doesn't allow spidering, so it's not good for syndication				
									## $RESULT = &ZOOVY::mediahost_imageurl($SO->username(),$RESULT,$h,$w,'FFFFFF',0,'jpg');
									## domain is prepended with www.
									$RESULT = sprintf('http://%s%s',$SO->domain(),&ZOOVY::image_path($SO->username(),$RESULT,H=>$h,W=>$w,B=>'FFFFFF',ext=>'jpg'));
				
									}
								}
							elsif ($format eq 'weight-in-oz') {
								$RESULT = &ZSHIP::smart_weight($RESULT);
								if ($RESULT == 0) { $RESULT = undef; } else { $RESULT = "$RESULT OZ"; }
								}
							elsif (($format eq 'weight-in-lbs') || ($format eq 'weight-in-lbs-number-only')
									|| ($format eq 'weight-in-lb')) {
								$RESULT = sprintf("%.1f",&ZSHIP::smart_weight($RESULT)/16);
								if ($RESULT == 0) { 
									$RESULT = undef; 
									}
								elsif ($format eq 'weight-in-lbs-number-only') {
									$RESULT = "$RESULT";
									}
								elsif ($format eq 'weight-in-lbs') { 
									$RESULT = "$RESULT LBS"; 
									}
								## added for googlebase
								elsif ($format eq 'weight-in-lb') { 
									$RESULT = "$RESULT lb"; 
									}
								
								# push @LOGIC, "WEIGHT IN LBS [$RESULT]";
								}
							elsif ($format eq 'replace') {
								# print 'REPLACE: '.Dumper($format_params);

								my $this = quotemeta($format_params->{'this'});
								my $with = $format_params->{'with'};
								$RESULT =~ s/$this/$with/gs;
								}
							elsif ($format eq 'lookup-category') {
								# print "RESULT: $RESULT\n";
								## 2011-08-11 - patti - added for gbase:product_type
								## which uses path of product type vs a number that needs to be looked up
								### if RESULT isnt a number, no need to lookup
								if ($RESULT !~ /\d/) { 
									}
								elsif ($RESULT==0) {
									$RESULT = ''; 
									}
								else {
									$RESULT = &SYNDICATION::HELPER::FORMAT_lookup_category($SO,$RESULT);
									}
								# print "RESULTx: $RESULT\n";
								}
							else {
								$plm->pooshmsg("ISE|+Unhandled formattor [$format] for header $col->{'header'}");
								}

							push @LOGIC, "$col->{'header'} AFTER FORMAT $format: $RESULT";
							}
						}

					}
				else {
					$plm->pooshmsg("ERROR|+Unhandled try case [$try] on header $col->{'header'}");
					}

				## VALIDATION MUST BE APPLIED TO ALL/ANY VALUES
				if ((not defined $col->{'@validation'}) || (scalar($col->{'@validation'})==0)) {
					}
				elsif (not $plm->can_proceed()) {
					push @LOGIC, "$col->{'header'} $try VALIDATION: SKIPPING BECAUSE OF EARLIER FAILURE";
					}
				elsif (not defined $RESULT) {
					# push @LOGIC, "$col->{'header'} VALIDATION: RESULT IS EMPTY (NOTHIN TO DO)";
					}
				elsif ((defined $col->{'@validation'}) && (scalar($col->{'@validation'})>0)) {
					foreach my $validator (@{$col->{'@validation'}}) {
						next if (not defined $RESULT);
						push @LOGIC, "$col->{'header'} $try VALIDATION TEST: $validator";
						if ($validator eq 'not-blank') { 
							if ($RESULT eq '') { $RESULT = undef;  }
							}
						elsif ($validator eq 'positive-number') {
							if ($RESULT <= 0) { $RESULT = undef; }
							}
						else {
							$plm->pooshmsg("ERROR|+Unhandled validator [$validator] for header $col->{'header'}");
							}
						}
					if (not defined $RESULT) {
						push @LOGIC, "$col->{'header'} $try VALIDATION blocked result";
						}
					else {
						push @LOGIC, "$col->{'header'} $try VALIDATION passed (very nice!)";
						}
					}
				else {
					push @LOGIC, "$col->{'header'} NO VALIDATION.";
					}

				if ($RESULT) { push @LOGIC, "$col->{'header'} $try = '$RESULT'\n"; } 
				if (not $plm->can_proceed()) { push @LOGIC, "*** ERROR SET -- WILL NOT PROCEED\n"; }
				}
			}

#		if ($col->{'header'} eq 'title') {
#			print Dumper(\@LOGIC);
#			die();
#			}

		# print Dumper($col);
		my $CAN_IGNORE_BECAUSE = undef;
		if (not $plm->can_proceed()) {
			}
		elsif (defined $col->{'@skip'}) {
			foreach my $reason (@{$col->{'@skip'}}) {
				if ($CAN_IGNORE_BECAUSE) {
					}
				elsif (($reason eq 'if-blank') && ($RESULT eq '')) {
					#=[[SUBSECTION]if-blank]
					#=[[/SUBSECTION]]
					$CAN_IGNORE_BECAUSE = $reason;
					}
				## patti added - 20110922 - to deal with headers that were required for just the Clothing category
				elsif (($reason =~ /if-blank-and-header-not-like:(.*)=(.*)/)  && ($RESULT eq '')) {
					my $previous_header = $1;
					my $value = $2;
					if ($data_hash{$previous_header} !~ /$value/) {
						$CAN_IGNORE_BECAUSE = $reason;
						}
					}

				elsif ($reason eq /same-as-previous-header\:(.*?)$/) {
					#=[[SUBSECTION]same-as-previous-header:header]
					#=[[/SUBSECTION]]
					my $previous_header = $1;
					if ($RESULT eq $data_hash{$1}) { $CAN_IGNORE_BECAUSE = $reason; }
					}
				}
			}
	

		if (not $plm->can_proceed()) {
			}
		elsif (defined $CAN_IGNORE_BECAUSE) {
			## safe to ignore this value
			push @LOGIC, "$col->{'header'} will be ignored BECAUSE: $CAN_IGNORE_BECAUSE";
			}
		elsif (not defined $RESULT) {
			$plm->pooshmsg("ERROR|ATTRIB=$FIRST_TRY_ATTRIB|+header '$col->{'header'}' failed (no data)");
			push @LOGIC, "$col->{'header'} is required, and has failed.";
			}
		else {
			push @data_array, [ $col->{'header'}, $RESULT ];
			$data_hash{ $col->{'header'} } = $RESULT;
			push @LOGIC, "$col->{'header'} = '$RESULT'"; 
			}

		push @LOGIC, "$col->{'header'} FINISHED.";
		if ($SO->is_debug($P->pid())) {
			foreach my $logic (@LOGIC) {
				# $log =~ s/[^a-z0-9A-Z\s\-\_\%\:]+/_/gs;
				$logic =~ s/[\|]+/~/gs;
				$plm->pooshmsg("LOGIC|+$logic");
				}
			}

		}
	
	return(\@data_array,\%data_hash);
	}


##
##
##
sub webdoc_explain {
	my ($DST) = @_;

	my $headers = &SYNDICATION::HELPER::get_headers($DST);
	my $out = '';

	foreach my $col (@{$headers}) {
		$out .= "<div>";
		$out .= "<h2>$col->{'header'}</h2>\n";
		if (not defined $col->{'@try'}) {
			}
		elsif (scalar(@{$col->{'@try'}})==0) {
			}
		else {
			my $ATTEMPT = 1;
			foreach my $try (@{$col->{'@try'}}) {
				if ($try eq '') { 
					$out .= "<li> ATTEMPT: $ATTEMPT - <i>Defaults to Blank</i>"; 
					}
				elsif (substr($try,0,10) eq '%CONSTANT:') {
					$out .= "<li> ATTEMPT: $ATTEMPT - Value will be set to: <font color='blue'>\"".substr($try,10)."\"</font>";
					}
				elsif (substr($try,0,1) eq '%') {
					$out .= "<li> ATTEMPT: $ATTEMPT - <font color='blue'>SPECIAL FIELD: $try</font>";
					}
				else {
					$out .= "<li> ATTEMPT: $ATTEMPT - Product Field: $try\n";
					if (not defined $PRODUCT::FLEXEDIT::fields{$try}) {
						$out .= " <font color='red'>NOT IN FLEXEDIT</font>";
						}
					}
				$ATTEMPT++;
				}
			foreach my $format (@{$col->{'@format'}}) {
				$out .= "<li> Formatting: $format\n";
				}
			foreach my $validation (@{$col->{'@validation'}}) {
				$out .= "<li> Validation: $validation\n";
				}
			foreach my $skip (@{$col->{'@skip'}}) {
				$out .= "<li> Skip Output Condition: $skip\n";
				}
			}
		$out .= "</div>\n";
		}

	# $out = Dumper($headers);	

	return($out);
	}


1;