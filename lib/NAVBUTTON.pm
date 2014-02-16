package NAVBUTTON;

use strict;
use Storable;

use Digest::MD5;
use Storable;
use Image::Magick qw ();
use POSIX qw (ceil);

#$NAVBUTTON::CACHE_USER = '';			# username of the user currently in cache
#$NAVBUTTON::CACHE_INFO = {};					# cache currently on disk.


## note: you must set FLOW::USERNAME before calling this!
sub cached_button_info {
	my ($USERNAME,$type,$width,$height,$messages) = @_;

	if (not defined $USERNAME) { die("USERNAME NOT SET"); }

	if (not defined $type) { $type = 'default'; }
	if (not defined $width) { $width = ''; }
	if (not defined $height) { $height = ''; }
	if ((not defined $messages) || (not scalar @{$messages})) { return []; }

	my $UUID = &Digest::MD5::md5_hex($type.'|'.$width.'|'.$height.'|'.join('.',@{$messages}));		
	my $REF = undef;

	my ($memd) = &ZOOVY::getMemd($USERNAME);
	if (defined $memd) {
		my $YAML = $memd->get("$USERNAME.BUTTON.$UUID");
		if ($YAML ne '') {
			$REF = YAML::Syck::Load($YAML);
			}
		}

	if (not defined $REF) {
		open F, ">/dev/shm/button.$UUID";
		use Data::Dumper; print F Dumper($$,$USERNAME,$type,$width,$height,$messages);
		close F;

		$REF = &NAVBUTTON::button_info($USERNAME,$type,$width,$height,$messages);
		if (defined $memd) {
			# warn "set memd\n";
			$memd->set("$USERNAME.BUTTON.$UUID",YAML::Syck::Dump($REF));
			}

		# unlink("/dev/shm/button.$UUID");
		}

	return($REF);
	}






sub button_info {
	my ($merchant_id,$type,$width,$height,$messages) = @_;

	if (not defined $merchant_id) { $merchant_id = ''; }
	if (not defined $type) { $type = 'default'; }
	if (not defined $width) { $width = ''; }
	if (not defined $height) { $height = ''; }
	if ((not defined $messages) || (not scalar @{$messages})) { return []; }

	my $iniref = {};	## this should be whatever is in the .bin file
	if (-f "/httpd/static/navbuttons/$type/button.bin") {
		$iniref = retrieve("/httpd/static/navbuttons/$type/button.bin");
		$iniref->{'dir'} = "/httpd/static/navbuttons/$type";
		}

	########################################
	# Get the image width and height
	# (If we have it at this point)
	$iniref->{'get_width'} = 1;
	if ($width ne '') {
		$iniref->{'width'} = int($width);
		$iniref->{'get_width'} = 0;
		}
		
	$iniref->{'get_height'} = 1;
	if ($height ne '') {
		$iniref->{'height'} = int($height);
		$iniref->{'get_height'} = 0;
		}

	if (substr($iniref->{'font'},0,1) ne '/') {
		$iniref->{'font'} = '/httpd/static/fonts/'.$iniref->{'font'};
		}
		
	my $out = [];

	foreach my $message (@{$messages}) {
		my $cfg = {};		# this is stuff SPECIFIC to this message.

		## make a copy of all settings in $iniref since we'll need the settings for SITE::Static when it
		##		actually generates the button (yeah I know this is retarded)
		## NOTE: we could do this better, but it'd require some substantial testing.
		foreach my $k (keys %{$iniref}) { 
			$cfg->{$k} = $iniref->{$k}; 
			}

		$cfg->{'text_width'} = 0;
		$cfg->{'text_height'} = 0;

		if ((not defined $message) || ($message eq '')) { $message = ' '; }
		if ($message =~ m/^\s/) { $message = '-' . $message; }
		
		##############################################################################
		# Get width and height for the text, and extrapolate for the image if
		# neccessary
	
		my (@widths,@heights,@lines);
		# Put this in a temporary block 
		my $limit = 2000;
		if (not $iniref->{'get_width'}) {
			$limit = (
				$cfg->{'width'} -
				$iniref->{'padding_left'} -
				$iniref->{'padding_right'} -
				($iniref->{'border_x'} * 2)
				);
			}

		my $line_count = 0;
		my @results = ();
		my @words = split /\s/, $message;
		my $temp = Image::Magick->new();

		$temp->Read('xc:'.$iniref->{'background_color'});
		while (my $line = shift @words) {
			## ImageMagick 5.5.6 and higher require us to hard code /httpd/fonts
			# if (($Image::Magick::VERSION eq '5.5.7') || ($Image::Magick::VERSION eq '5.5.6') || 

		
			@results = $temp->QueryFontMetrics(
				'text' => $line,
				'font' => '@'.$iniref->{'font'},
				'pointsize' => $iniref->{'font_size'},
				);
			$widths[$line_count] = POSIX::ceil($results[4]);
			$heights[$line_count] = POSIX::ceil($results[5]);
		
			my @check_words = @words;
			while (my $word = shift @check_words) {
				@results = $temp->QueryFontMetrics(
					'text' => "$line $word",
					'font' => '@'.$iniref->{'font'},
					'pointsize' => $iniref->{'font_size'},
				);
				last if ($results[4] > $limit);
				shift @words;
				$line = "$line $word";
				$widths[$line_count] = POSIX::ceil($results[4]);
				$heights[$line_count] = POSIX::ceil($results[5]);
				}

			## added 4 pixels of padding per line for shadowed text 7/27/04 - BH
			if ((defined $iniref->{'shadow'}) || (defined $iniref->{'shadowpad'})) {
				if ((defined $iniref->{'shadowpad'}) || (lc($iniref->{'shadow'}) eq 'true')) { 
					$heights[$line_count] += 4; }
				}
	
			if ($widths[$line_count] > $cfg->{'text_width'}) {
				$cfg->{'text_width'} = $widths[$line_count];
				}
			$cfg->{'text_height'} = $cfg->{'text_height'} + $heights[$line_count];
		
			$lines[$line_count] = $line;
			$line_count++;		
			}

		$cfg->{'f_ascender'} = $results[2];
		$cfg->{'f_descender'} = $results[3];
		$cfg->{'f_max_advance'} = $results[6];

		## forced padding -- required since upgrade to version ImageMagick 6.5.3-3 2009-07-03 Q16
		if ($iniref->{'padding_left'}==0) { $iniref->{'padding_left'} = 1; }
		if ($iniref->{'padding_right'}==0) { $iniref->{'padding_right'} = 1; }

		if ($iniref->{'get_width'}) {
			$cfg->{'width'} = (
				$cfg->{'text_width'} +
				$iniref->{'padding_left'} +
				$iniref->{'padding_right'} +
				($iniref->{'border_x'} * 2) 
				);
			}

		if ($iniref->{'get_height'}) {
			$cfg->{'height'} = (
				$cfg->{'text_height'} +
				$iniref->{'padding_top'} +
				$iniref->{'padding_bottom'} +
				($iniref->{'border_y'} * 2)
				);
			}
		
		push @{$out}, [$cfg,\@widths,\@heights,\@lines];
		}
	

#	use Data::Dumper;	print STDERR Dumper($out);

	return ($out);
	}


1;
