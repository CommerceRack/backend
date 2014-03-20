package BATCHJOB::UTILITY::CUSTOM_PROD_FIX;

##
## custom code for nyciwear
## - go thru all products
##	-- grab variable information from variable value and prod_desc
## -- use variable information and current prod_desc to 
##		build NEW standardized prod_desc
##
## current "master product" that is used for standardization:
## 	http://www.nyciwear.com/product/PO714SM_2456_52
##

use strict;
use lib "/backend/lib";
use Data::Dumper;
require ZOOVY;
require ZTOOLKIT;
require DBINFO;
require NAVCAT;
require LISTING::MSGS;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub um { return($_[0]->{'*PARENT'}); }

sub work {
	my ($self, $bj) = @_;

	my $USERNAME = $bj->username();
	my $MID = $bj->mid();
	my $PRT = $bj->prt();
	my $TB = &ZOOVY::resolve_product_tb($USERNAME);	## used to set prod_salesrank below
	my $lm = LISTING::MSGS->new($USERNAME,logfile=>"~/custom_prod_fix-%YYYYMM%.log");

	## fix both sunglasses and eyeglasses
	foreach my $glass_type ('eyeglasses','sunglasses') {
		$lm->pooshmsg("INFO|+Fixing $glass_type");
		my $root = '.'.$glass_type;

		## get all the products inside the sunglasses (or eyeglasses) categories
		my $NC = NAVCAT->new($USERNAME,PRT=>0);
		my (@paths) = $NC->paths($root);
		my (%hash_all) = ();
		foreach my $path (@paths) {
			my ($pretty,$children,$products) = $NC->get($path);
			my @glasses = split(/,/,$products);
			foreach my $glass (@glasses) {
				$hash_all{$glass}++;
				}
			}
		my @all = keys %hash_all;

		my $Prodsref = &PRODUCT::group_into_hashref($USERNAME,\@all);
		my $count = scalar (keys %{$Prodsref});
		$lm->pooshmsg("INFO|+Checking $count pids");

		my $wiki_ctr = 0;
		my $done = 0;
		### go thru all products defined from above
		foreach my $P (values %{$Prodsref}) {
			my %changed = ();
			my $ctr = ($count--);
			my $PID = $P->pid();
			my $prodref = $P->prodref();
			$lm->pooshmsg("INFO|+$PID $ctr");
	
			###### VARS - determine which variables to update 
			## and use to build standardized prod_desc
			my %vars = (
				'Style' => 'user:prod_style',
				'Frame' => 'user:prod_eyeglass_framecolor',
				'Lens' => 'user:prod_eyeglass_lenstype',
				'Material' => 'user:prod_eyeglass_material',
				'Made In' => 'user:prod_madein',
				'Color Code' => 'user:prod_colorcode',
				'Eye'=> 'user:prod_eyeglass_size_eye',
				'Bridge'=> 'user:prod_eyeglass_size_bridge',
				'Temple'=> 'user:prod_eyeglass_size_temple',
				'Gender' => 'zoovy:prod_gender',
				'Brand' => 'zoovy:prod_brand',
				'Type' => 'zoovy:prod_eyeglass_type',
				'Color' => 'zoovy:prod_color',
				);

			## order of the variables in the prod_desc output
			my %var_order = (
				1 => 'Style',
				2 => 'Frame',
				3 => 'Lens',
				4 => 'Material',
				5 => 'Made In',
				6 => 'Size',
				7 => 'Color Code',
				8 => 'Color',
				);
		
			## order of the Size sub variables
			my %size_order = (
				1 => 'Eye',
				2 => 'Bridge',
				3 => 'Temple',
				);

			## start cleaning up and parsing prod_desc
			my $description = '';
			my @bullets = ();	
			my @wiki_sizeorder = ();
			my $contents = $prodref->{'zoovy:prod_desc'};
			$contents = ZTOOLKIT::stripUnicode($contents);  ## strip out unicode characters
			$contents =~ s/\r\n/\n/gs;	# convert CRLF to just CR
		
			## go thru each line in the prod_desc
			foreach my $line (split(/\n/,$contents)) {
				$line =~ s/\<li\>/\&li\;/ig;

				my $ch = substr($line,0,1);  ## get first char of each line
				if ($ch eq '*') {
					$line =~ s/^\* //;  ## take out, we'll re-add later if desired
					$line =~ s/^\*//;  ## take out, we'll re-add later if desired
					push @bullets, $line;
					}
				## hopefully this is a subsize bullet
				elsif ($ch eq '|') {
					$line =~ s/^|//;
					$line =~ s/\|/- /;
					if ($line =~ /Eye|Bridge|Temple/i) {
						push @bullets, $line;
						}
					elsif ($line =~ /mm\|/) {	
						push @bullets, $line;
						}
					}
				## ===Eye:=== for example
				elsif ($line =~ /===(.*):===/) {
					push @bullets, $line;
					}
				## dont need these lines
				elsif ($line =~ /Frame Size/i) {
					}	
				elsif ($line eq 'mm') { 
					}
				elsif ($line eq '==Size:==') {
					}
				## subsize measurements, 20mm
				elsif ($line =~ /(\d+)mm/) {
					push @bullets, $line;
					}
				## not a bullet, just add to description
				else {
					$description .= $line."\n";
					}
				}

			## cleanup bullets
			my $bullet_pos = 0;
			my @new_bullets = ();
			foreach my $bullet (@bullets) {
				## multiple SIZE formats
				## Size: Eye/Bridge/Temple- 64mm/10mm/NA
				## Bridge/Temple- 21mm/140mm
				if ($bullet =~ /Size:(.*)/ ) {
					my $size_stuff = $1;
					my ($size,$size_contents) = split(/-\s+/,$size_stuff);
					my (@ks) = split(/\//,$size);
					my (@vs) = split(/\//,$size_contents);

					## go thru all the sub sizes (in order)
					foreach my $size_key (sort keys %size_order) {
						my $size_var = $size_order{$size_key};  ## get the value; Eye, Bridge, Temple
						my $pos = 0;
						foreach my $k (@ks) {
							$k =~ s/ //g;
							if ($size_var eq $k) {
								## skip NA values
								if ($vs[$pos] eq 'NA') { }
								else {	
									push @new_bullets, $k."- ".$vs[$pos];
									}
								}
							$pos++;
							}
						}
					}
				## Size- Eye:59mm/Bridge:15mm/Temple:00
				## Size- Eye:52mm-Bridge:21mm-Temple:140mm
				elsif ($bullet =~ /Size- (.*)/) {
					my $size_contents = $1;
	
					## split into kv pairs			
					my @sizes = ();
					if ($size_contents =~ /-/) {
						@sizes = split(/-/,$size_contents);
						}
					elsif ($size_contents =~ /\//) {
						@sizes = split(/\//,$size_contents);
						}

					## go thru all the sub sizes (in order)
					## 	add to bullets array
					foreach my $size_key (sort keys %size_order) {
						my $size_var = $size_order{$size_key};  ## get the value; Eye, Bridge, Temple
						my $pos = 0;
						foreach my $k (@sizes) {
							if ($k =~ /$size_var:(.*)/) {
								push @new_bullets, "$size_var- $1";
								}
							$pos++;
							}
						}		
					}

				## |=EYE|=BRIDGE|=TEMPLE
				elsif ($bullet =~ /\|=/) {
					(@wiki_sizeorder) = split(/\|=/, $bullet);
					}
				##|Eye|Bridge|Temple
				elsif ($bullet =~ /Eye\|Bridge\|Temple/) {
					(@wiki_sizeorder) = split(/\|/, $bullet);
					}		

				## |60mm|16mm|120mm
				elsif (scalar(@wiki_sizeorder) > 0 && $bullet =~ /mm\|/) {
					$bullet =~ s/^- //;
					my (@wiki_sizevalues) = split(/\|/, $bullet);

					my $pos = 0;
					foreach my $element (@wiki_sizeorder) { 	
						$element =~ s/^- =//;
						push @new_bullets, uc($wiki_sizeorder[$pos])."- ".$wiki_sizevalues[$pos];
						$pos++;
						}
					}

				## ===Bridge:===
				## 19mm
				elsif ($bullet =~ /===(.*):===/) {
					my $var = $1;
					if ($var eq 'Eye' || $var eq 'Bridge' || $var eq 'Temple') {
						my $next_line = $bullet_pos+1;
	
						## only add subsequent line if 30mm not just mm or NAmm
						if ($bullets[$next_line] =~ /(\d+)mm/) {
							push @new_bullets, $var."- ".$bullets[$next_line];
							}
						}
					}

				## all other attribs (other than Size or other Size formats we don't know about)
				else {
					push @new_bullets, $bullet;
					}
			
				$bullet_pos++;
				}

			## go thru each of the vars/bullets that will be prepended to prod_desc
			## (if they have a value)
			my $lost_bullets = ''; 
			foreach my $bullet (@new_bullets) {
				my $added = 0;
				$bullet =~ s/^-//;
				$bullet =~ s/^\s+//;
				$bullet =~ s/^|//;
				next if $bullet eq '- - '; ## um, not needed

				my $value = '';
				foreach my $k (keys %vars) {
					## go thru all the main bullet values; Color, Size, Frame, etc			
					if ($bullet =~ /^$k(.*)/i) {
						$value = $1;
		
						## gender is formatted differently			
						if ($k eq 'gender' && $bullet =~ /Size:\|(Womens|Mens)(.*)/i) {
							$value = $1;
							}
						## just save the value for size, no "mm"
						if ($k eq 'Eye' || $k eq 'Bridge' || $k eq 'Temple') {
							$value =~ s/mm//g;
							}	
			
						## cleanup value
						$value =~ s/=//g;
						$value =~ s/\|//g;
						$value =~ s/://g;
						$value =~ s/\.$//;	## remove trailing .		
						$value =~ s/^- //;

						if ($value eq '') {
							}
						elsif ($value eq '00') {
							}
						elsif ($value eq 'NA') {
							}
						else {
				
							## mark to save product if the variable is different than the current value
							if ($prodref->{$vars{$k}} ne $value) {
								$changed{"VAR:".$vars{$k}}++;
								}
							$prodref->{$vars{$k}} = $value;
							## need to note that we used bullet 
							$added++;
							}
						}
					}
				## random bullets from CURRENT description, that need to added back to desc
				if ($added == 0) {
					## dont add Frame Size header
					if ($bullet =~ /Frame Size/i) {
						}
					## dont add Sizes, 33mm
					elsif ($bullet =~ /^(\d*)mm$/) {
						}
					else {
						## cleanup leading *'s
						if ($bullet =~ /^\*\S+/) {
							$bullet =~ s/\*/\* /;
							}
						if ($bullet !~ /^\*/) {
							$bullet = "* ".$bullet;
							}
						$bullet =~ s/\.$//;	## remove trailing .
						$lost_bullets .= $bullet."\n";
						}
					}  
				}

			## fix for bug created in first run
			## 'user:prod_eyeglass_framecolor' => 'S'
			## 'user:prod_eyeglass_lenstype' => 'ES',
			if (uc($prodref->{'user:prod_eyeglass_framecolor'}) =~ /^S\s*$/) {
				$prodref->{'user:prod_eyeglass_framecolor'} = '';
				}
			if (uc($prodref->{'user:prod_eyeglass_lenstype'}) =~ /^ES\s*$/) {
				$prodref->{'user:prod_eyeglass_lenstype'} = '';
				}		
			if (uc($prodref->{'user:prod_eyeglass_lenstype'}) =~ /^E-(.*)/) {
				$prodref->{'user:prod_eyeglass_lenstype'} = $1;
     			}


			## build new prod_desc output
			my $output = '';
			## go thru the vars in the correct order
			foreach my $order (sort keys %var_order) {
				my $key = $var_order{$order}; 

				## add to the output as a bullet if its not blank
				## format different if its Size
				## ex: Size- Eye:52mm-Bridge:21mm-Temple:140mm
				if ($key eq 'Size') {
					my $size_output = '';
					foreach my $size ('Eye','Bridge','Temple') {
						if ($prodref->{$vars{$size}} ne '') {
							## more cleanup
							$prodref->{$vars{$size}} =~ s/-//;
							$prodref->{$vars{$size}} =~ s/ //g;
							$prodref->{$vars{$size}} =~ s/(\d+)or(\d+)/$1 or $2/;
							$prodref->{$vars{$size}} =~ s/Only!//i;
							$size_output .= $size.":".$prodref->{$vars{$size}}."mm-";
							}
						}
	
					## save zoovy:prod_size, add size output to output
					if ($size_output ne '') {
						chop($size_output);		## take out trailing -
						$output .= "* $key- ".$size_output."\n";
						## only populate if Size is blank
						if ($prodref->{'zoovy:prod_size'} eq '' && $prodref->{'zoovy:prod_size'} ne $size_output) {
							$prodref->{'zoovy:prod_size'} = $size_output;
							$changed{'zoovy:prod_size'}++;
							}
						}
					}

				## all vars except Size, add to output
				elsif ($prodref->{$vars{$key}} ne '') {
					## more cleanup
					$prodref->{$vars{$key}} =~ s/^- //;
					$output .= "* $key- ".$prodref->{$vars{$key}}."\n";
					}
				}

			## add var output to description
			if ($output ne '') {
				$description = $output.$lost_bullets."\n".$description;
				}	


			## save original prod_desc into user:prod_desc
			if ($prodref->{'user:prod_desc'} eq '') {
				$prodref->{'user:prod_desc'} = $prodref->{'zoovy:prod_desc'};
				$changed{'user:prod_desc'}++;
				}
			## if the NEW prod_desc is different than existing, then mark to save
			## don't worry about newlines
			my $descA = $prodref->{'zoovy:prod_desc'};
			$descA =~ s/\n//g;
			my $descB = $description;
			$descB =~ s/\n//g;
			if ($descA ne $descB) {
				#open(TMP1,">nyciwear/".$prod."_a.out");print TMP1 $prodref->{'zoovy:prod_desc'}; close(TMP1);
				#open(TMP2,">nyciwear/".$prod."_b.out");print TMP2 $description; close(TMP2);
				$prodref->{'zoovy:prod_desc'} = $description;
				$changed{'zoovy:prod_desc'}++;
				}
			## set the eyeglass type
			if ($prodref->{'zoovy:prod_eyeglass_type'} ne $glass_type) {
				$prodref->{'zoovy:prod_eyeglass_type'} = $glass_type;
				$changed{'zoovy:prod_eyeglass_type'}++;
				}
			## last ditch effort to populate some fields
			## MATERIAL
			if ($prodref->{'user:prod_eyeglass_material'} eq '') {
				if ($prodref->{'zoovy:prod_desc'} =~ /Plastic/i) {
					$prodref->{'user:prod_eyeglass_material'} = 'Plastic';
					$changed{'user:prod_eyeglass_material'}++;
					}
				elsif ($prodref->{'zoovy:prod_desc'} =~ /Metal/i) {
					$prodref->{'user:prod_eyeglass_material'} = 'Metal';
					$changed{'user:prod_eyeglass_material'}++;
					}  
				elsif ($prodref->{'zoovy:prod_desc'} =~ /Titanium/i) {
					$prodref->{'user:prod_eyeglass_material'} = 'Titanium';
					$changed{'user:prod_eyeglass_material'}++;
					}  
				}
			## GENDER
			if ($prodref->{'zoovy:prod_gender'} eq '') {
				## WOMAN/WOMEN
				if (uc($prodref->{'zoovy:prod_desc'}) =~ / WOM(E|A)N/ ||
					uc($prodref->{'zoovy:keywords'}) =~ / WOM(E|A)N/) {
					$prodref->{'zoovy:prod_gender'} = 'Female';
					$changed{'zoovy:prod_gender'}++;
					}
				## MAN/MEN
				elsif (uc($prodref->{'zoovy:prod_desc'}) =~ / M(E|A)N/ ||
					uc($prodref->{'zoovy:keywords'}) =~ / M(E|A)N/) {
					$prodref->{'zoovy:prod_gender'} = 'Male';
					$changed{'zoovy:prod_gender'}++;
					}
				#else {
				#	$prodref->{'zoovy:prod_gender'} = 'Unisex';
				#	}
		
				}

			## BRAND
			if ($prodref->{'zoovy:prod_brand'} eq '' && $prodref->{'zoovy:prod_mfg'} eq '') {
				$prodref->{'zoovy:prod_brand'} = $prodref->{'zoovy:prod_mfg'};
				$changed{'zoovy:prod_brand'}++;
				}
			elsif ($prodref->{'zoovy:prod_brand'} eq '') {
				my @brands = ("Burberry","Carrera","Chanel","Chloe","Christian Dior","D&G","DKNY","Dior","Dolce & Gabbana","Dsquared","Ed Hardy","Gucci",
									"Juicy Couture","Maui Jim",
									"POLO","Persol","Prada","Linea Rossa","Ralph Lauren","Ray Ban","Ray Ban Jr","Roberto Cavalli","Tom Ford","Tory Burch",
									"Valentino","Versace","Vogue","Von Zipper","YSL");
				foreach my $brand (sort @brands) {
					if ($prodref->{'zoovy:prod_desc'} =~ /$brand/i) {
						$prodref->{'zoovy:prod_brand'} = $brand;
						$changed{'zoovy:prod_brand'}++;
						last;
						}
					} 
				}
			## new googlebase apparel fields
			## color
			if ($prodref->{'zoovy:prod_color'} eq '' && $prodref->{'gbase:prod_color'} eq '') {
				$prodref->{'gbase:prod_color'} = 'MultiColor';
				$changed{'zoovy:prod_color'}++;
				}
			if ($prodref->{'zoovy:prod_age_group'} eq '' && $prodref->{'gbase:prod_age_group'} eq '') {
				$prodref->{'gbase:prod_age_group'} = 'adult';
				$changed{'zoovy:prod_age_group'}++;
				}

			## populate zoovy:prod_salesrank with YYYYMMDD from converted product CREATED_GMT
			## per jamie...
			##	websites utilize tags to populate best sellers and new arrivals
			## throughout the websites (instead of product lists).  The fields/attributes that
			## have to be set are:
			## is:user1 = new
			## is:bestseller
			## **these sections also set to sort by zoovy:prod_salesrank date
			if ($prodref->{'zoovy:prod_salesrank'} eq '') {
				my $pdbh = &DBINFO::db_user_connect($USERNAME);
				my $pstmt = "select CREATED_GMT from $TB where MID=$MID and PRODUCT='".$PID."'";
				my $sth = $pdbh->prepare($pstmt);
				$sth->execute();
				my ($created_gmt) = $sth->fetchrow();
				$sth->finish();
				&DBINFO::db_user_close();

				my $datetime = ZTOOLKIT::mysql_from_unixtime($created_gmt);
				$datetime =~ /^(\d\d\d\d\d\d\d\d)/;
				my $date = $1;
				$prodref->{'zoovy:prod_salesrank'} = $date;
				$changed{'zoovy:prod_salesrank'}++;
				}


			## SAVE!!		
			## save product and print if change took place	
			my (@changed_cnt) = keys %changed;
			if (scalar @changed_cnt > 0) {
				$lm->pooshmsg("INFO|+CHANGED $PID");
				$P->save();

				## output fields and their values
				$vars{'New Desc'} = 'zoovy:prod_desc';		
				$vars{'Old Desc'} = 'user:prod_desc';		
				$vars{'Size'} = 'zoovy:prod_size';
				foreach my $key (keys %vars) {
					if ($prodref->{$vars{$key}} ne '') {
						$lm->pooshmsg("INFO|+".$vars{$key}." ".$prodref->{$vars{$key}});
						}
					}
				}
			else {
				## NO CHANGE
				}
			}
		}

	$bj->progress(0,0,"Finished Custom Product Fix",'');
	return(undef);
	}

1;
