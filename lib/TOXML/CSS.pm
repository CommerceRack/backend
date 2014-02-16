package TOXML::CSS;

#
# CSSVARS: 
#		loadURP("CSS::var")
#		<ELEMENT TYPE="READONLY" LOAD="CSS::var"/>
#          'zbody.bgcolor' => '#FFFFFF',
#          'zborder.border' => '1px solid #CCCCCC',
#          'zborder.border.color' => '#CCCCCC',
#          'zbox_body.bgcolor' => '#e5e5e5',
#          'zbox_body.color' => '#000000',
#          'zbox_body.font_size' => '8pt',
#          'zbox.border' => '1px solid #990000',
#          'zbox.border.color' => '#990000',
#          'zbox_head.bgcolor' => '#990000',
#          'zbox_head.color' => '#FFFFFF',
#          'zbox_head.font_size' => '9pt',
#          'zhint.color' => '#',
#          'zhint.font_size' => '8pt',
#          'zlink.color' => '#990000',
#          'zsmall.color' => '#',
#          'zsmall.font_size' => '8pt',
#          'ztable_head.bgcolor' => '#990000',
#          'ztable_head.color' => '#FFFFFF',
#          'ztable_head.font_size' => '9pt',
#          'ztable_row0.bgcolor' => '#e5e5e5',
#          'ztable_row0.font_size' => '8pt',
#          'ztable_row1.bgcolor' => '#cccccc',
#          'ztable_row1.font_size' => '8pt',
#          'ztable_row.bgcolor' => '#e5e5e5',
#          'ztable_row.color' => '#000000',
#          'ztable_row.font_size' => '8pt',
#          'ztitle2.color' => '#333333',
#          'ztitle2.font_size' => '9pt',
#          'ztitle.color' => '#333333',
#          'ztitle.font_size' => '9pt',
#          'ztxt.color' => '#333333',
#          'ztxt.font_family' => 'Arial, Helvetica'
#          'ztxt.font_size' => '9pt',
#          'zwarn.color' => '#990000',
#          'zwarn.font_weight' => 'bold',
#        };
##	
##	CSS::zbody.bgcolor
#
##
## OPTIONAL NOT GUARANTEED TO BE PRESENT:
##		z_add_link
##		


use strict;

##
## this converts a cssvar (probably loaded from css2cssvar) to the old 
##		theme.ini format (used for backward compatibility)
##
sub cssvar2iniref {
	my ($vars) = @_;

	my %ini = ();
	$ini{'alert_color'} = substr($vars->{'zwarn.color'},1);
	$ini{'content_background_color'} = substr($vars->{'zbody.bgcolor'},1);
	$ini{'content_font_face'} = $vars->{'ztxt.font_family'};
	$ini{'content_font_size'} = &fontpt2size($vars->{'ztxt.font_size'});
	$ini{'content_text_color'} = substr($vars->{'ztxt.color'},1);
	$ini{'disclaimer_background_color'} = substr($vars->{'zbody.bgcolor'},1);
	$ini{'disclaimer_font_face'} = $vars->{'ztxt.font_family'};
	$ini{'disclaimer_font_size'} = &fontpt2size($vars->{'zsmall.font_size'});
	$ini{'disclaimer_text_color'} = substr($vars->{'zsmall.color'},1);
	$ini{'link_active_text_color'} = substr($vars->{'zlink.color'},1);
	$ini{'link_text_color'} = substr($vars->{'zlink.color'},1);
	$ini{'link_visited_text_color'} = substr($vars->{'zlink.color'},1);
	$ini{'name'} = $vars->{'css2ini'};
	$ini{'pretty_name'} = $vars->{'css2ini'};
	$ini{'table_heading_background_color'} = substr($vars->{'ztable_head.bgcolor'},1);
	$ini{'table_heading_font_face'} = $vars->{'ztxt.font_family'};
	$ini{'table_heading_font_size'} = &fontpt2size($vars->{'ztable_head.font_size'});
	$ini{'table_heading_text_color'} = substr($vars->{'ztable_head.color'},1);
	$ini{'table_listing_background_color'} = substr($vars->{'ztable_row0.bgcolor'},1);
	$ini{'table_listing_background_color_alternate'} = substr($vars->{'ztable_row1.bgcolor'},1);
	$ini{'table_listing_font_face'} = $vars->{'ztxt.font_family'};
	$ini{'table_listing_font_size'} = &fontpt2size($vars->{'ztable_row.font_size'});
	$ini{'table_listing_text_color'} = substr($vars->{'ztable_row.color'},1);

	return(\%ini);
	}


sub cssvar2css {
	my ($cssvars) = @_;

	my %defs = ();
	foreach my $k (keys %{$cssvars}) {
		# print "K: $k\n";
		my ($tag,$property) = split(/\./,$k,2);
		if (not defined $defs{$tag}) { $defs{$tag} = {}; }

		next if ($property eq 'border.color');		# this is already contained in a border tag
		if ($property eq 'bgcolor') { $property = 'background-color'; }
		else {
			$property =~ s/_/-/gs;		# font_weight becomes font-weight
			}
		$defs{$tag}->{$property} = $cssvars->{$k};
		}

	my @csslines = ();
	foreach my $def (keys %defs) {
		my $body = '';
		foreach my $property (sort keys %{$defs{$def}}) {
			$body .= sprintf(" %s: %s;",$property,$defs{$def}->{$property});
			}
		push @csslines, sprintf(".%s { %s }\n",$def,$body);
		}
	my $csstxt = join("",sort @csslines);

	# use Data::Dumper; print STDERR Dumper(\%defs);
	return($csstxt);
	}


##
## this loads a css stylesheet, and creates a hashref that can be used in the wrapper
##	mode:
##		0 - only commonly used tags (strips some data)
##		1 - (useful if we're going to run cssvar2css later)
##
sub css2cssvar {
	my ($css,$mode) = @_;

	if (not defined $mode) { $mode = 0; }

	my %vars = ();
	foreach my $line (split(/[\n\r]+/s,$css)) {
		next if ($line eq '');
#		print "LINE: $line\n";
		$line =~ s/^[\s]+//gs;
		$line =~ s/[\s]+$//gs;
		## must start with .
		next if (substr($line,0,1) ne '.');
		if ($line =~ /\.(.*?)[\s]+\{(.*?)\}$/) {
			my ($class,$data) = ($1,$2);
#			print "CLASS[$class] DATA[$data]\n";
			foreach my $attrib (split(/;/,$data)) {
				$attrib =~ s/^[\s]+//gs;
				$attrib =~ s/[\s]+$//gs;
				next if ($attrib eq '');
#				print "  ATTRIB[$attrib]\n";
				if ($attrib =~ /([\w\-]+):[\s]+(.*?)[\s]*$/) {
					my ($key,$val) = ($1,$2);
					$key =~ s/-/_/gs;
#					print "KEY[$key] VAL:[$val]\n";
					if ($key eq 'background_color') { $key = 'bgcolor'; }

					if (($mode==0) && ($class ne 'ztxt') && ($key eq 'font_family')) {
						## the only font-family we keep is ztxt
						}
					elsif ($key eq 'border') {
						$vars{$class.'.'.$key} = $val;
						my @prop = split(/[\s]+/,$val);
						foreach my $p (@prop) {
							if (substr($p,0,1) eq '#') { $vars{$class.'.'.$key.'.color'} = $p; }
							}
						}
					else {
						#add this full key.
						$vars{$class.'.'.$key} = $val;
						}
					# end if valid attribute
					}
				# end foreach attribute
				}
			# end if line has class+data
			}
		# end foreach line
		}
	return(\%vars);
	}


##
## this inputs an old $iniref format, and converts it to a css stylesheet
##		specifically this outputs a TEXT stylesheet.
##
sub iniref2css {
	my ($iniref) = @_;

	my %css = ();

	## these are the button classes --

	## use this on the TD for any table header row.
	$css{'table_head_bg'} = $iniref->{'table_heading_background_color'}; 
	$css{'table_head_txt_color'} = $iniref->{'table_heading_text_color'}; 
	$css{'table_head_txt_size'} = &fontsize2pt($iniref->{'table_heading_font_size'});
	$css{'table_head_txt_face'} = $iniref->{'table_heading_font_face'};

	$css{'table_row_txt_color'} = $iniref->{'table_listing_text_color'};
	$css{'table_row_txt_size'} = 	&fontsize2pt($iniref->{'table_listing_font_size'}); 
	$css{'table_row_txt_face'} =  $iniref->{'table_listing_font_face'};
	## row subclasses: row0, row1, rows (selected), rowh (highlighted)
	$css{'table_row_bg'} = $iniref->{'table_listing_background_color'};
	$css{'table_row0_bg'} = $iniref->{'table_listing_background_color'};
	$css{'table_row1_bg'} = $iniref->{'table_listing_background_color_alternate'};

	## NOTE: box will inherit from table_head
	$css{'box_head_bg'} = $iniref->{'table_heading_background_color'};
	$css{'box_head_txt_color'} = $iniref->{'table_heading_text_color'};
	$css{'box_head_txt_size'} = &fontsize2pt($iniref->{'table_heading_font_size'});
	$css{'box_head_txt_face'} = $iniref->{'table_heading_font_face'};
	$css{'box_body_bg'} = $iniref->{'table_listing_background_color'};
	$css{'box_body_txt_color'} = $iniref->{'table_listing_text_color'};
	$css{'box_body_txt_size'} = &fontsize2pt($iniref->{'table_listing_font_size'});
	$css{'box_body_txt_face'} = $iniref->{'table_listing_font_face'};

	## page properties:
	$css{'bg'} = $iniref->{'content_background_color'};
	$css{'txt_color'} = $iniref->{'content_text_color'};
	$css{'txt_size'} = &fontsize2pt($iniref->{'content_font_size'});
	$css{'txt_face'} = $iniref->{'content_font_face'};

	if ($iniref->{'disclaimer_font_color'} eq '') { 
		$iniref->{'disclaimer_font_color'} = $iniref->{'content_text_color'};
		}

	foreach my $txt_type ('title_txt','title2_txt') {
		foreach my $var ('_color','_size','_face') {
			next if (defined $css{$txt_type.$var});
			$css{$txt_type.$var} = $css{'txt'.$var};
			}
		}
	$css{'small_txt_color'} = $iniref->{'disclaimer_font_color'};
	$css{'small_txt_size'} = &fontsize2pt($iniref->{'disclaimer_font_size'});
	$css{'small_txt_face'} = $iniref->{'disclaimer_font_face'};

	$css{'hint_txt_color'} = $iniref->{'disclaimer_font_color'};
	$css{'hint_txt_size'} = &fontsize2pt($iniref->{'disclaimer_font_size'});
	$css{'hint_txt_face'} = $iniref->{'disclaimer_font_face'};

	$css{'link_color'} = $iniref->{'link_text_color'}; 
	$css{'warn_color'} = $iniref->{'alert_color'};
	

	my $css = '';
	my @lines = ();
	## WHOA so we've got our CSS definitions.
	my @cssdefs = ('table_head','table_row','box_head','box_body');
	foreach my $def (@cssdefs) {
		push @lines, sprintf(".z%s { background-color: #%s; color: #%s; font-family: %s; font-size: %s; }",
			$def, $css{$def.'_bg'}, $css{$def.'_txt_color'}, $css{$def.'_txt_face'}, $css{$def.'_txt_size'}
			); 
		}
	push @lines, sprintf(".ztable_row0 { background-color: #%s; font-size: %s; }",
		$css{'table_row0_bg'}, $css{'table_row_txt_size'});
	push @lines, sprintf(".ztable_row1 { background-color: #%s; font-size: %s; }",
		$css{'table_row1_bg'}, $css{'table_row_txt_size'});


	@cssdefs = ('small','hint');
	foreach my $def (@cssdefs) {
		push @lines, sprintf(".z%s { color: #%s; font-family: %s; font-size: %s; }",
			$def, $css{$def.'_txt_color'}, $css{$def.'_txt_face'}, $css{$def.'_txt_size'}
			); 
		}

	push @lines, sprintf(".ztitle { font-weight: bold; color: #%s; font-family: %s; font-size: %s; }",
		$css{'title_txt_color'}, $css{'title_txt_face'}, &TOXML::CSS::bumppt($css{'title_txt_size'},+1)); 

	push @lines, sprintf(".ztitle2 { font-weight: bold; color: #%s; font-family: %s; font-size: %s; }",
		$css{'title_txt_color'}, $css{'title_txt_face'}, $css{'title_txt_size'}
		); 


	push @lines, sprintf(".ztable_row_title { font-weight: bold; color: #%s; font-family: %s; font-size: %s; }",
		$css{'table_row_txt_color'}, $css{'table_row_txt_face'}, $css{'table_head_txt_size'}
		); 
	push @lines,  sprintf(".ztable_row_small { color: #%s; font-family: %s; font-size: 8pt; }",
		$css{'table_row_txt_color'}, $css{'table_row_txt_face'}
		); 

	push @lines, sprintf(".ztxt { color: #%s; font-family: %s; font-size: %s; }",
		$css{'txt_color'}, $css{'txt_face'}, $css{'txt_size'}
		); 

	push @lines, sprintf(".zbox { border: 1px solid #%s; }",
		$iniref->{'table_heading_background_color'});

	push @lines, sprintf(".zborder { border: 1px solid #CCCCCC; }"); 
	push @lines, sprintf(".zbody { background-color: #%s; }", $css{'bg'});
	push @lines, sprintf(".zlink { color: #%s; }", $css{'link_color'}); 
	push @lines, sprintf(".zwarn { color: #%s; font-weight: bold; }", $css{'warn_color'});

#	push @lines, sprintf(".zpanel { background-color: #%s; color: #%s; font-family: %s; font-size: 8pt; }",	
#		$css{'table_row0_bg'}, 
#		$css{'table_row_txt_color'},$css{'table_row_txt_face'});

	push @lines, sprintf(".ztab0 { background-color: #%s; color: #%s; font-family: %s; font-size: 9pt; }",
		&TOXML::CSS::shiftcolor($css{'table_row1_bg'},1), 
		&TOXML::CSS::shiftcolor($css{'table_row_txt_color'},1),$css{'table_row_txt_face'});
	push @lines, sprintf(".ztab1 { background-color: #%s; color: #%s; font-family: %s; font-size: 9pt; font-weight: bold;}", 
		$css{'table_row0_bg'}, $css{'table_row_txt_color'},$css{'table_row_txt_face'});
	push @lines, sprintf(".ztabbody { background-color: #%s; color: #%s; font-family: %s; font-size: 8pt; }",
		$css{'table_head_bg'}, $css{'table_head_txt_color'},$css{'table_row_txt_face'});

	# buttons
	# complimentary color palettes
	# form elements	
	my $border = &TOXML::CSS::shiftcolor( $css{'table_head_bg'}, -1);
	push @lines, sprintf(".zform_textbox { border: 1px solid #%s; background-color: #FFFFFF; color: #000000; font-size: 8pt; font-family: %s; };", $border, $css{'table_row_txt_face'});
	push @lines, sprintf(".zform_textarea { border: 1px solid #%s; background-color: #FFFFFF; color: #000000; font-size: 8pt; font-family: %s; };", $border, $css{'table_row_txt_face'});
	push @lines, sprintf(".zform_select { border: 1px solid #%s; background-color: #FFFFFF; color: #000000; font-size: 8pt; font-family: %s; };", $border, $css{'table_row_txt_face'});
	push @lines, sprintf(".zform_button { border: 1px solid #%s; background-color: #%s; color: #%s; font-size: 8pt; font-family: %s; }",  
			$border,  &TOXML::CSS::shiftcolor($css{'table_head_bg'},1), $border, $css{'table_row_txt_face'});

	push @lines, sprintf(".zcolor_light { background-color: #%s; color: #%s; }", 
		&TOXML::CSS::shiftcolor( $css{'table_head_bg'}, 1), &TOXML::CSS::shiftcolor( $css{'table_head_txt_color'}, 1) );
	push @lines, sprintf(".zcolor { background-color: #%s; color: #%s; }",
		&TOXML::CSS::shiftcolor( $css{'table_head_bg'}, 0), &TOXML::CSS::shiftcolor( $css{'table_head_txt_color'},0 ) );
	push @lines, sprintf(".zcolor_dark { background-color: #%s; color: #%s; }",
		&TOXML::CSS::shiftcolor( $css{'table_head_bg'}, -1), &TOXML::CSS::shiftcolor( $css{'table_head_txt_color'},-1 ) );

	push @lines, sprintf(".zcolor_contrast { background-color: #%s; color: #%s; }",
		&TOXML::CSS::shiftcolor( $css{'table_head_bg'},2), &TOXML::CSS::shiftcolor( $css{'table_head_txt_color'},3 ) );

	my $out = join("\n",sort @lines);

	return($out);
}



sub shiftcolor {
	my ($rgb,$distance) = @_;


#	print STDERR "RGB[$rgb] +$distance\n";
	my @color = ( hex(substr($rgb,0,2)), hex(substr($rgb,2,2)), hex(substr($rgb,4,2)) );
	
	if ($distance==0) {}
	elsif ($distance==1) {
		for (my $i = 0; $i<3; $i++) {
			$color[$i] += 0x40;
			if ($color[$i]>0xFF) { $color[$i] = 0xFF; }
#			print STDERR "Color:$i = $color[$i]\n"
			}
		}
	elsif ($distance==-1) {
		for (my $i = 0; $i<3; $i++) {
			$color[$i] -= 0x40;
			if ($color[$i]<0x00) { $color[$i] = 0x00; }
			}
		}
	elsif ($distance==2) {
		my $found = 0;
		for (my $i = 0; $i<3; $i++) {
			if ($color[$i]==0xFF) { $color[$i] = 0x8A; $found++; }
			elsif ($color[$i]==0x00) { $color[$i] = 0x75; $found++; }
			}
		if ($found==0) {
			for (my $i = 0; $i<3; $i++) {
				$color[$i] += 0x7F;
				$color[$i] = ($color[$i] % 0xFF);
				}
			}
		}
	elsif ($distance==3) {
		my $found = 0;
		for (my $i = 0; $i<3; $i++) {
			if ($color[$i]==0xFF) { $color[$i] = 0x10; $found++; }
			elsif ($color[$i]==0x00) { $color[$i] = 0x7F; $found++; }
			}
		if ($found==0) {
			for (my $i = 0; $i<3; $i++) {
				$color[$i] += $color[$i];
				$color[$i] = ($color[$i] % 0xFF);
				}
			}
		}

	return(sprintf("%02x%02x%02x",$color[0],$color[1],$color[2]));
	}


sub fontsize2pt { 
	my ($fontsize) = @_; 
	my $pt = '8pt';
	if ($fontsize==1) { $pt = '8pt' } elsif ($fontsize==2) { $pt = '9pt' } elsif ($fontsize==3) { $pt = '11pt' } elsif ($fontsize==4) { $pt = '15pt' }
	return($pt);
	}

##
## moves a font up or down a point.
sub bumppt {
	my ($fontpt, $bump) = @_;

	$fontpt = substr($fontpt,0,-2);
	$fontpt += $bump;
	return($fontpt."pt");
	}

##
##
##
sub fontpt2size { 
	my ($fontpt) = @_; 

	my $fontsize = 1; 
	if (substr($fontpt,-2) eq 'pt') {
		$fontpt = substr($fontpt,0,-2);
		if ($fontpt == 8) { $fontsize = 1; } 
		elsif ($fontpt == 9) { $fontsize = 2; }
		elsif ($fontpt == 11) { $fontsize= 3; }
		elsif ($fontpt == 15) { $fontsize= 4; }
		else { $fontsize = 2; }
		}
	else {
#		print STDERR "FONTPT[$fontpt]\n";
		}

	return($fontsize);
	}



1;