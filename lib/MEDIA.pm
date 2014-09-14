package MEDIA;


use File::Path;
use File::Basename qw();
use Data::Dumper;
use JSON::XS qw();		## used to parse filters
use lib "/backend/lib";
require ZOOVY;
require ZWEBSITE;
require ZTOOLKIT;
use strict;
use Encode qw();

$MEDIA::DEBUG = 0;

$MEDIA::CACHE_DIR = "/local/media-cache";
$MEDIA::max_image_size = 2000; ## Maximum dimension of a scaled image in x or y
@MEDIA::ext = qw(jpg gif jpeg png);
@MEDIA::ext2 = qw(pdf swf);
$MEDIA::max_name_length = 80;
# $MEDIA::max_age =  1167963563;
$MEDIA::max_age = 1168049100;  ## 2007010518050000
##  Jan  8 08:12

$MEDIA::CACHE_FID = undef;
$MEDIA::CACHE_FIDSTR = undef;


## NOTE: webapi uses format dir1|dir2|dir3 -- these functions convert from and to that format!
sub from_webapi { my ($pwd) = @_; $pwd =~ s/\|/\//gs; return($pwd); }
sub to_webapi { my ($pwd) = @_; $pwd =~ s/\//\|/gs; return($pwd); }


###############################################################################
## load_buffer
##
## Purpose: Gets a file from disk and returns it
## Accepts: A filename and an optional username
## Returns: Undef on failure, the contents of the file on success and the last
##          modified time on success
##
###############################################################################
sub load_buffer {
	my ($orig_filename, $USERNAME) = @_; # USERNAME is optional

	# $MEDIA::DEBUG = ($orig_filename =~ m/ppslv2/) ? 1 : 0 ;

	my $filename = $orig_filename;
	if ((defined $USERNAME) && ($USERNAME ne '')) {

		if (not defined $filename) { $filename = ''; }
		my $subdir = undef;
		if (index($filename,'/')>=0) {
			$subdir = substr($filename,0,rindex($filename,'/'));
			## arrgh -- this doesn't work either, because it lc's the ENTIRE path (e.g. A/test1a becomes a/test1a)
			## if (length($subdir)>1) { $subdir = lc($subdir); }
			$filename = substr($filename,length($subdir)+1);
			if (substr($subdir,0,1) eq '/') { $subdir = substr($subdir,1); }	# remove leading /
			}
		elsif ($filename) {
			$subdir = uc(substr($filename, 0, 1));
			}
	
		##
		## $filename = lc($filename);		# NOTE: don't lowercase images, since this function is also used for params (e.g. H120-Bffffff)
		##
		$filename = &ZOOVY::resolve_userpath($USERNAME)."/IMAGES/$subdir/$filename";
		$MEDIA::DEBUG && warn ("query_collection($orig_filename, $USERNAME): Filename changed to $filename");
		}

	if (open FILE, "<$filename") {
		local $/ = undef;
		my $buffer = <FILE>;
		my @fileinfo = stat FILE;
		close FILE;
		$MEDIA::DEBUG && warn ("load_buffer($orig_filename, $USERNAME): Succeeded loading $filename!");
		return $buffer, $fileinfo[9];
		}
	else {
		$MEDIA::DEBUG && warn ("load_buffer($orig_filename, $USERNAME): Failed open $filename!");
		}
	return undef;
}



##
## /remote/cache
##
sub hashcache {
	my ($USERNAME,$filename) = @_;

	$filename =~ s/[\/\\]+/+/go;
	$USERNAME = uc($USERNAME);
	$filename = "$USERNAME:$filename";

	my ($i,$i1,$i2) = (0,0,13);
	foreach my $ch (split(//,$filename)) {
		$i++;
		$i1 += (ord($ch)*$i)%17;
		if ($i1>=0xFFF) { $i1 -= 0xFFF; }
		if (($i % 2)==0) { 
			$i2 += (ord($ch)*$i)%0xFE; 
			if ($i2>=0xFFF) { $i2 -= 0xFFF; }
			}
		}

	## perl -e 'foreach my $z (0 .. 0xFF) { foreach my $y (0 .. 0xFF) { my ($subdir) = sprintf("%02X/%02X",$x,$y); system("mkdir -p /local/media-cache/$subdir"); } }'
	my $basedir = $MEDIA::CACHE_DIR;
	my $dir = sprintf("$basedir/%02X/%02X/%s",$i1%0xFF,$i2%0xFF);
	if (! -d $dir) {
		mkdir(sprintf("$basedir/%02X",$i1%0xFF));
		mkdir(sprintf("$basedir/%02X/%02X",$i2%0xFF));
		chmod 0777, sprintf("$basedir/%02X",$i1%0xFF);
		chmod 0777, sprintf("$basedir/%02X/%02X",$i2%0xFF);
		if ( -d $dir ) {
			warn "could not create/write to dir: $dir\n";
			$dir = undef;
			}
		}

	if (not defined $dir) {
		return(undef);
		}
	else {
		my $filename = sprintf("%s/%s",$dir,$filename);
		print STDERR "CACHEFILE: $dir\n";
		return($filename);
		}
	}


##
## GetInfo Struct Errors
##		err=>0		everything is kosher
##		err=>1		serving a blank graphic
##		err=>3		could not write original file
##		err=>10 		database lookup failure
##		err=>11		file does not exist on disk
##		err=>12		getinfo returned undef to serve image
##		err=>50		invalid/unsupported image format.
##		err=>98		file appears to be html
##		err=>99		file corrupt, too small
##		err=>100		image magick error (generic)
##		err=>101		image magick could not determine image dimensions
##		err=>996		filename must be .PNG .JPG or .GIF
##		err=>997		filename must be provided
##		err=>998		username not provided
##		err=>999		unspecified application error (used by the application to handle unref iref result)
##

###############################################################################
## error_image
##
## Purpose: Returns a 1x1 image in GIF, JPG or PNG format in a certain color
## Accepts: A Color in hex RGB format with each byte being either FF or 00
## Returns: The corresponding image and the file format it was created in
##
###############################################################################
sub error_image {
	my ($color, $format) = @_;
	
	$color = uc(&ZTOOLKIT::def($color));

	if ($color !~ m/^(00|FF)(00|FF)(00|FF)$/i) {
		$color = 'FF0000'; ## Red by default
		}
	
	$format = lc(&ZTOOLKIT::def($format, 'gif'));
	
	my $img = undef;
	if (($format eq 'jpg') or ($format eq 'jpeg')) {
		if    ($color eq 'FFFFFF') { $img = 'FFD8FFE000104A46494600010101004800480000FFDB004300FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC0000B080001000101011100FFC40014000100000000000000000000000000000003FFC40014100100000000000000000000000000000000FFDA0008010100003F0047FFD9'; }
		elsif ($color eq '000000') { $img = 'FFD8FFE000104A46494600010101004800480000FFDB004300FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC0000B080001000101011100FFC40014000100000000000000000000000000000003FFC40014100100000000000000000000000000000000FFDA0008010100003F0037FFD9'; }
		elsif ($color eq 'FF0000') { $img = 'FFD8FFE000104A46494600010101004800480000FFDB004300FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDB004301FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC00011080001000103012200021101031101FFC4001500010100000000000000000000000000000002FFC40014100100000000000000000000000000000000FFC4001501010100000000000000000000000000000103FFC40014110100000000000000000000000000000000FFDA000C03010002110311003F0090028FFFD9'; }
		elsif ($color eq 'FFFF00') { $img = 'FFD8FFE000104A46494600010101004800480000FFDB004300FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDB004301FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC00011080001000103012200021101031101FFC4001500010100000000000000000000000000000002FFC40014100100000000000000000000000000000000FFC4001501010100000000000000000000000000000103FFC40014110100000000000000000000000000000000FFDA000C03010002110311003F00B0132FFFD9'; }
		elsif ($color eq '00FF00') { $img = 'FFD8FFE000104A46494600010101004800480000FFDB004300FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDB004301FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC00011080001000103012200021101031101FFC4001500010100000000000000000000000000000001FFC40014100100000000000000000000000000000000FFC40014010100000000000000000000000000000002FFC40014110100000000000000000000000000000000FFDA000C03010002110311003F00A0003FFFD9';   }
		elsif ($color eq '00FFFF') { $img = 'FFD8FFE000104A46494600010101004800480000FFDB004300FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDB004301FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC00011080001000103012200021101031101FFC4001500010100000000000000000000000000000002FFC40014100100000000000000000000000000000000FFC4001501010100000000000000000000000000000103FFC40014110100000000000000000000000000000000FFDA000C03010002110311003F00A00A6FFFD9'; }
		elsif ($color eq '0000FF') { $img = 'FFD8FFE000104A46494600010101004800480000FFDB004300FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDB004301FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC00011080001000103012200021101031101FFC4001500010100000000000000000000000000000002FFC40014100100000000000000000000000000000000FFC4001501010100000000000000000000000000000103FFC40014110100000000000000000000000000000000FFDA000C03010002110311003F0080140FFFD9'; }
		elsif ($color eq 'FF00FF') { $img = 'FFD8FFE000104A46494600010101004800480000FFDB004300FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDB004301FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC00011080001000103012200021101031101FFC4001500010100000000000000000000000000000001FFC40014100100000000000000000000000000000000FFC40014010100000000000000000000000000000002FFC40014110100000000000000000000000000000000FFDA000C03010002110311003F008019BFFFD9';   }
		$format = 'jpg';
		}
	elsif ($format eq 'png') {
		if    ($color eq 'FFFFFF') { $img = '89504E470D0A1A0A0000000D4948445200000001000000010100000000376EF92400000002624B47440001DD8A13A4000000097048597300000048000000480046C96B3E0000000A49444154789C636C0000008400821E067BAD0000000049454E44AE426082';   }
		elsif ($color eq '000000') { $img = '89504E470D0A1A0A0000000D4948445200000001000000010100000000376EF92400000002624B47440000AA8D2332000000097048597300000048000000480046C96B3E0000000A49444154789C63640000000400022164AD6A0000000049454E44AE426082';   }
		elsif ($color eq 'FF0000') { $img = '89504E470D0A1A0A0000000D494844520000000100000001010300000025DB56CA00000003504C5445FF000019E20937000000097048597300000048000000480046C96B3E0000000A49444154789C63640000000400022164AD6A0000000049454E44AE426082'; }
		elsif ($color eq 'FFFF00') { $img = '89504E470D0A1A0A0000000D494844520000000100000001010300000025DB56CA00000003504C5445FFFF008AC6F445000000097048597300000048000000480046C96B3E0000000A49444154789C63640000000400022164AD6A0000000049454E44AE426082'; }
		elsif ($color eq '00FF00') { $img = '89504E470D0A1A0A0000000D494844520000000100000001010300000025DB56CA00000003504C544500FF00345EC0A8000000097048597300000048000000480046C96B3E0000000A49444154789C63640000000400022164AD6A0000000049454E44AE426082'; }
		elsif ($color eq '00FFFF') { $img = '89504E470D0A1A0A0000000D494844520000000100000001010300000025DB56CA00000003504C544500FFFF195C2F25000000097048597300000048000000480046C96B3E0000000A49444154789C63640000000400022164AD6A0000000049454E44AE426082'; }
		elsif ($color eq '0000FF') { $img = '89504E470D0A1A0A0000000D494844520000000100000001010300000025DB56CA00000003504C54450000FF8A78D257000000097048597300000048000000480046C96B3E0000000A49444154789C63640000000400022164AD6A0000000049454E44AE426082'; }
		elsif ($color eq 'FF00FF') { $img = '89504E470D0A1A0A0000000D494844520000000100000001010300000025DB56CA00000003504C5445FF00FF34E0E6BA000000097048597300000048000000480046C96B3E0000000A49444154789C63640000000400022164AD6A0000000049454E44AE426082'; }
		}
	else {
		## GIF format by default
		$format = 'gif';
		$img = '47494638376101000100800000'.$color.'0000002C00000000010001000002024401003B';
		}
	
	return pack('H'.length($img), $img), $format;
	}



###############################################################################
## build_image
##
## Purpose: Calls ImageMagick and creates a new version of an exising image
## Accepts: A filename, the arguments used to create a modified version, and
##          an optional file format (if absent, will choose smallest from jpg
##          or gif)
## Returns: Contents of the actual image and its file format OR
##          Contents of a 1x1 image representing the error by its color, and a
##          file format.
##
## Error Image Colors:
## FF0000 - Red - Image read / imagemagick object creation problem
## FFFF00 - Yellow - Imagemagick object corruption problem
## 00FF00 - Green - Scaling / Sampling Problem
## 00FFFF - Aqua - Drawing / Background Color Problem
## FF00FF - Purple - Compositing problem
## 0000FF - Blue - Imagemagick output corruption problem
## White and black are supported but we haven't assigned them to any
## significance yet.
## See error_image()
##
###############################################################################
sub build_image {
	my ($source_filename, $argsref, $format) = @_;

	if ($MEDIA::DEBUG) { print STDERR "build_image ".Dumper($source_filename,$argsref,$format)."\n"; }

	## Make sure format is set
	my $blob = undef;
	my $result = undef;
	$format = lc(&ZTOOLKIT::def($format));
	if ($MEDIA::DEBUG) { print STDERR "source: $source_filename [format:$format]\n"; }
	if (($format ne 'png') && ($format ne "gif") && ($format ne "jpg")) { $format = 'jpg'; }


	if (not -f $source_filename) { 
		## crap, okay so basically we are asking for a file we don't got.
		($blob) = &MEDIA::blankout();
		$format = 'gif';
		$result = { err=>1, errmsg=>"Could not load $source_filename" };
		}


	require Image::Magick;
	my $source_image = Image::Magick->new();

	if (not defined $blob) {
		## Read in the source file or return a red 1x1 image
		$result = &MEDIA::magick_result($source_image->Read($source_filename),"reading $source_filename in build_image()");
		if (defined $result) {
			$blob = &MEDIA::error_image('FF0000', $format);
			}
		}

	my $source_width  = -1; 
	my $source_height = -1;
	if (not defined $blob) {	
		$source_width = $source_image->Get('width');
		$source_height = $source_image->Get('height');

		## Get the height and width or return a yellow 1x1 image
		unless ($source_width && $source_height) {
			$result = { err=>101, errmsg=>"Error getting image dimensions" };
			($blob) = &MEDIA::error_image('FFFF00', $format);
			}
		}


	## 
	## SANITY: 
	##		$source_width, $source_height contain the actual image size.
	##		$source_image contains a reference to the actual image
	##		OR $result is defined with an error.


	my ($output_image, $output_image_trans) = (undef,undef);
	if (not defined $result) {
		my $width  = &ZTOOLKIT::def($argsref->{'W'}, 0);
		my $height = &ZTOOLKIT::def($argsref->{'H'}, 0);

		if (($width == 0) && ($height == 0)) {
			## if we have a 0 in height and width then use the actual image size.
			$width  = $source_width;
			$height = $source_height;
			}
		elsif (defined($argsref->{'M'}) || ($width==0) || ($height==0))	{
			## If we're in minimal mode, just use the directly scaled size
			($width,$height) = &MEDIA::minsize($source_width,$source_height,$width,$height);
			}

		## If the actual and the desired sizes are the same and there's no bg color,
		## then skip doing all the scaling BS
		if (($source_width == $width) && ($source_height == $height) && (not defined $argsref->{'B'})) {
			## Its OK to base it off the original image, cause we're the same size
			## and we're not forcing a background color
			$output_image = $source_image;
			}
		else {
			## Scale the image...
			my ($x_offset,$y_offset,$scale_width,$scale_height);
			if ($MEDIA::DEBUG) { print STDERR "scaling: ($source_width == $width) && ($source_height == $height)\n"; }

			if (($source_width == $width) && ($source_height == $height)) {
				$x_offset = 0;
				$y_offset = 0;
				}
			elsif (defined $argsref->{'C'}) {
				$x_offset = int(($width - $source_width) / 2);
				$y_offset = int(($height - $source_height) / 2);
				}
			elsif (($scale_width>0) && ($scale_height>0)) {
				## if we already know the size then don't do math again, because we could have rounding erro
				$x_offset = 0;
				$y_offset = 0;
				}
 			else {
				## See how much each axis needs to be scaled by
				my $width_ratio  = ($width / $source_width);
				my $height_ratio = ($height / $source_height);

				## fudgefactor is the percentage we can be off, this comes into play since 
				##		there can be rounding issues.
				my ($fudgefactor) = ($source_width>$source_height)?$source_width:$source_height;

				if ( int($width_ratio*$fudgefactor) == int($height_ratio*$fudgefactor) ) {
					## Scale the same on both axes (e.g. a fudge factor of 1000 means both aspect ratios differ by <0.1%)
					$scale_width  = $width; # int($width_ratio  * $source_width);
					$scale_height = $height; # int($height_ratio * $source_height);
					$x_offset   = 0;
					$y_offset   = 0;
					}
				elsif ($height_ratio >= $width_ratio) {
					## we have to scale more on  the width (i.e., it has a smaller
					## value), then use it to scale the image
					$scale_width  = int($width_ratio * $source_width);
					$scale_height = int($width_ratio * $source_height); 
					$x_offset   = 0;
					$y_offset   = int(($height - $scale_height) / 2);
					}
				elsif ($height_ratio < $width_ratio) {
					## we have to scale more on  the height (i.e., it has a smaller
					## value), then use it to scale the image
					$scale_width  = int($height_ratio * $source_width); 
					$scale_height = int($height_ratio * $source_height);
					$x_offset   = int(($width - $scale_width) / 2);
					$y_offset   = 0;
					}
				else {
					## never reached
					}

				if ((abs($scale_width-$width)<=1) && (abs($scale_height-$height)<=1)) {
					## okay, so we got some sort of rounding issue that fudgefactor didn't catch
					$scale_width = $width;
					$scale_height = $height;
					}

				}
		

			## Okay, we're going to need to do *SOME* scaling.
			if ((defined $scale_width) && (defined $scale_height)) {
				if (defined $argsref->{'P'}) {
					## Pixel-sample scale the image if we have the P flag
					## (looks better for some transparent GIFs)
					## Sample the image or return a green 1x1 image
					$result = &MEDIA::magick_result(
						$source_image->Sample('width' => $scale_width,'height' => $scale_height),
						"sampling $source_filename to $scale_width x $scale_height in build_image()"
						);
					}
				else {
					## Regular scaling
					## Scale the image or return a green 1x1 image
					$result = &MEDIA::magick_result( 
						$source_image->Scale('width' => $scale_width,'height' => $scale_height),
						"scaling $source_filename to $scale_width x $scale_height in build_image()"
						);
					}
				}


			#print STDERR Dumper($argsref);
			#print STDERR "FORMAT: $format ARGSREF: $argsref->{'T'}\n";

			# Create the output image
			$output_image = Image::Magick->new('size' => $width.'x'.$height);
			if (defined $result) {
				## we've already encountered an error.
				}
			elsif (($format eq 'png') && (defined $argsref->{'T'})) {
				## no background stuff will be done if we're asking for a transparency.
				$result = &magick_result(
					$output_image->Read("xc:transparent"),
					"\$output_image->Read() from $source_filename in build_image()");
				}
			elsif (($format eq 'gif') && (not defined $argsref->{'B'})) {
				# We're transparent!
				## Read the source file or return a red 1x1 image
				if (not defined $result) {
					$result = &magick_result(
						$output_image->Read(),
						"\$output_image->Read() from $source_filename in build_image()");
					}
	
				if (not defined $result) {
					$result = &magick_result(
						$output_image->Draw('primitive' => 'Matte','method' => 'Replace','points' => '0,0'),
						"\$output_image->Draw(...) from $source_filename in build_image()");
					}
				}
			else {
				# We have a background color, or are outputting to
				# a format that needs a background color
				## Change the background color or return an aqua 1x1 image
				if (not defined $argsref->{'B'}) { $argsref->{'B'} = 'FFFFFF'; }
				$result = &magick_result(
					$output_image->Read('xc:#'.$argsref->{'B'}),
					"\$output_image->Read('xc:#$argsref->{'B'}') from $source_filename in build_image()");
				}
	
			## Paste the input image over the output image, offset so it is
			## centered on the image
			if (not defined $result) {
				$result = &magick_result(
					$output_image->Composite('compose' => 'over','image' => $source_image,'x' => $x_offset,'y' => $y_offset),
					"compositing $source_image onto \$output_image in build_image()"
					);
					}

				}

			if (defined $argsref->{'F'}) {
				## yippe..we gots an output filter.
			#	$output_image = $source_image; 

			#	$result = &magick_result(
			#		$output_image->Read("xc:transparent"),
			#		"\$output_image->Read() from $source_filename in build_image()");
			#	$result = &magick_result(
			#		$output_image->Flip()
			#		);
			#	$result = &magick_result(
			#		$output_image->Blur('factor'=>50)
			#		);
			#	$result = &magick_result(
			#		$output_image->Mogrify("Blur",'factor'=>50)
			#		);
			#	$result = &magick_result(
			#		$output_image->Mogrify("Emboss")
			#		);

				my ($script) = $argsref->{'F'};
				# print STDERR "SCRIPT: $script\n";
				$script =~ s/[^a-z]+//g;
				my $jscoder = JSON::XS->new();
				print STDERR "RUNNING: /httpd/static/graphics/imgfilters/$script.txt\n";
				open F, "</httpd/static/graphics/imgfilters/$script.txt";
				my @LAYERS = ($output_image);
				while (<F>) {
					chomp();
					next if ($_ eq '');
					my ($layer, $cmd,$jsontxt) = split(/[\t]+/, $_, 3);
					next if (substr($cmd,0,1) eq '#');

					print STDERR "RUNNING LINE: $cmd ($jsontxt)\n";

					my %params = ();
					if ($jsontxt ne '') {
						my $paramsref  = $jscoder->decode($jsontxt);
						# my $paramsref = JSON::XS::decode_json($jsontxt);
						if (ref($paramsref) eq 'HASH') {
							%params = %{$paramsref};
							}
						}
					print STDERR "RUNNING[$cmd] params...".&ZTOOLKIT::buildparams(\%params)."\n";
					# $params{'factor'} = 100;
					if ($cmd eq 'Set') {
						$LAYERS[$layer]->Set(%params);
						}
					elsif ($cmd eq 'New') {
						$LAYERS[$layer] = Image::Magick->new(%params);
						$LAYERS[$layer]->Read("xc:transparent");		## always read in a transparent background.
						}
					elsif ($cmd eq 'Composite') {
						$params{'image'} = $LAYERS[$params{'image'}];
						$LAYERS[$layer]->Composite(%params);
						}
					elsif ($cmd eq 'Montage') {
						$params{'image'} = $LAYERS[$params{'image'}];
						$LAYERS[$layer]->Composite(%params);
						}
					else {
						$LAYERS[$layer]->Mogrify("$cmd",%params);
						}
					}
				close F;		
				$output_image = $LAYERS[0];
				}

#	$output_image->Set(colorspace=>'gray');
#	$output_image->Quantize();
#		$output_image->Montage(geometry=>'160x160',gravity=>"North",borderwidth=>10,compose=>"Over",filename=>"/httpd/htdocs/images/zoovysmall.gif");
		
#		$output_image->Montage(geometry=>'160x160', tile=>'2x2', texture=>'granite:');
#		$output_image->Draw(pen=>'black', primitive=>'rectangle', points=>'20,20 100,100');


# Composite 	compose=>{Over, In, Out, Atop, Xor, Plus, Minus, Add, Subtract, Difference, Bumpmap, Replace, ReplaceRed, ReplaceGreen, ReplaceBlue, ReplaceMatte, Blend, Displace}, image=>image-handle, geometry=>geometry, x=>integer, y=>integer, gravity=>{NorthWest, North, NorthEast, West, Center, East, SouthWest, South, SouthEast}
#		my $xi = Image::Magick->new();
#		$xi->Read("/httpd/htdocs/images/zoovysmall.gif");
#		$output_image->Composite(  compose=>'Atop', image=>$xi, x=>0, y=>0, gravity=>'South');
		
	
		if (defined $result) { ($blob) = &error_image('FF00FF', $format); }
		}

	if (not defined $blob) {
		## there is a conversion error, going from large JPG to large PNG
		## calling a TRIM puts the JPG into imagemagick format so it doesn't
		## barf
		# if ($format eq 'png') { $output_image->Trim(); }
		if ($MEDIA::DEBUG) { print STDERR "outputting format[$format]\n"; }
		$output_image->Set('magick' => $format);
		$blob = $output_image->ImageToBlob();
		$result = { err=>0 };
		}

	if ((not defined $blob) || (length($blob) == 0)) {
		$result = { err=>100, errmsg=>"build_image($source_filename, $argsref, $format) Zero length or undefined output from ImageToBlob for $format format from $source_filename.\n" };
 		($blob) = &error_image('0000FF', $format);
	 	}

	return ($blob, $format, $result);
	}



###############################################################################
## blankout
##
## Purpose: Returns a blank 1x1 GIF image
sub blankout {
	return pack("H84", "4749463839610100010080FF00C0C0C000000021F90401000000002C000000000100010000010132003B");
	}



###############################################################################
## MEDIA::serve_image
##
## Purpose: Looks up an image in the user's image library, and returns a
##          version of that image based on the arguments string passed
## Accepts: A username, an image name (with optional .ext) and an argument
##          string (see decode_args for more information on the arg str)
## Returns: Undef on failure.  On success it returns the location of the file
##          for the image just created, a buffer of the image file just
##          created, the format of the image, the last modified time. and
##          1 for actual buffer, 2 for link contents buffer, and 0 for error
##          processing image but we're returning a colored image buffer
##
###############################################################################
sub serve_image {
	my ($USERNAME, $FQIMG, $req_argstr, %options) = @_;

	$FQIMG =~ s/[^\w\.\/]//gis;	# strip undesirable characters
	$FQIMG =~ s/[\/]+/\//g;		# convert // to / to avoid attacks
	my $format = '';
	my $collection = $FQIMG;
	my $extensions = join('|', @MEDIA::ext, 'jpeg');
	if ($FQIMG =~ m/^(.*?)\.($extensions)/) {
		$collection = $1;
		$format = $2;
		if ($format eq 'jpeg') { $format = 'jpg'; }
		}

	my $result = undef;
	my $userdir = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES';
	my ($subdir,$image,$ext) = &MEDIA::parse_filename($FQIMG);

	# print STDERR "SERVE_IMAGE: $subdir,$image,$ext\n";

	# load the info about the collection and return a pointer to the structure.
	my ($iref) = &MEDIA::getinfo($USERNAME, $FQIMG,DB=>2);
	if (not defined $iref) { $result = { err=>12, errmsg=>"Internal error [12]" }; }
	#$VAR1 = {
   #       'orig_timestamp' => '1093917322',
   #       'original' => 'bonsai_shipped.jpg',
   #       'ver' => '1.3',
   #       'orig_height' => 480,
   #       'orig_width' => 640,
   #       'created' => '1093918192',
   #       'subs' => {},
   #       'orig_filesize' => 194549
   #     };

	if ($iref->{'err'}>0) {
		## image lookup FAILED (does not exist)
		return(undef);
		}

	my ($argsref, $argstr) = &MEDIA::parse_args($USERNAME, "$subdir/$image", $req_argstr);
	my $orig_format = $iref->{'Format'};
	
	if (($argsref->{'H'} == $iref->{'H'}) && ($argsref->{'W'} == $iref->{'W'}) && (not defined $argsref->{'P'})) { 
		## okay so we're asking for the same height and width
		$argstr = '-'; 
		if ($format eq $orig_format) {
			## hmm.. we might want to create some sort of symlink here.
			# symlink ($orig_file, $file)
			}
		}
	
	##			
	## if we were queried for the original then just return it. right away (saves some time)
	##
	my ($filename,$buf,$lastmod) = (undef,undef,undef);

	## CREATE THE IMAGE IF IT DOESN'T EXIST
	if ($orig_format eq '') {
		## GUESS: make sure we've got a valid orig_format (extension)
		if (-f "$userdir/$subdir/$image.jpg") { $orig_format = 'jpg'; warn "guessed orig_format is jpg [requested: $format]"; }
		elsif (-f "$userdir/$subdir/$image.gif") { $orig_format = 'gif'; warn "guessed orig_format is gif [requested: $format]"; }
		elsif (-f "$userdir/$subdir/$image.png") { $orig_format = 'png'; warn "guessed orig_format is png [requested: $format]"; }
		}


	if (($argstr eq '-') && (($format eq '') || ($format eq $orig_format) )) {
		$iref->{'Format'} = $orig_format;
		$filename = "$subdir/$iref->{'ImgName'}.$iref->{'Format'}";
		($buf, $lastmod) = &MEDIA::load_buffer($filename, $USERNAME);
		if ($lastmod>0) {
			$result = $iref; $result->{'err'} = 0;
			return($filename,$buf,$iref->{'Format'},$lastmod,$result);
			}
		else {
			## failed on load original.. hmm.. crap.
			warn("missed on load original $USERNAME:[$filename]\n");
			return($filename,undef,undef,0,undef);
			}
		}


	## if we're asking for a transparency, it should always be a png.
	if (defined $argsref->{'T'}) { $format = 'png'; }
	
	#if (defined $argsref->{'Z'}) {
	#	$filename = "/httpd/htdocs/images/zoovy_main.gif";
	#	($buf, $lastmod) = &MEDIA::load_buffer($filename);
	#	$result = { err=>0 };
	#	return ($filename,$buf,'gif',time()-3600,$result);
	#	}

	## SEARCH FOR THE INSTANCE OF THE IMAGE (this return an undef buf if the file doesn't exist)
	$filename = "$subdir/$image-$argstr.$format"; 
	my $cachefile = &MEDIA::hashcache($USERNAME,$filename);
	if ((defined $cachefile) && (-f $cachefile)) {
		($buf, $lastmod) = &MEDIA::load_buffer($cachefile);
		if ($lastmod < $MEDIA::max_age) { $lastmod = 0; }
		if (($lastmod > 0)) {
			if ($MEDIA::DEBUG) { print STDERR "RETURNED CACHEFILE $cachefile [$argstr]\n"; }
			$result = $iref; $result->{'err'} = 0;
			return($filename,$buf,$format,$lastmod,$result);
			}
		}

	## SANITY: if we made it here, then we could not find the image and we should try and create
	##				it from the original

	## $MEDIA::DEBUG++;

	$filename = "$subdir/$image.$orig_format";
	($buf, $format, $result) = &MEDIA::build_image("$userdir/$filename", $argsref, $format);
	
	## WRITE OUT THE NEW IMAGE INSTANCE
	$lastmod = $^T-3600;
	if ((defined $result) && ($result->{'err'}==0)) {
		if ($argstr eq '-') { 
			$filename = "$subdir/$iref->{'ImgName'}-.$ext"; 
			}
		else { 
			$filename = "$subdir/$iref->{'ImgName'}-$argstr.$ext"; 
			}

		if (open FILE, ">$cachefile") { 
			print FILE $buf;
			close FILE;
			chmod(0666, $cachefile);
			chown($ZOOVY::EUID,$ZOOVY::EGID, $cachefile);
			}
		$result = $iref; 
		$result->{'err'} = 0;
		}
	else {
		## hmm.. some sort of result occurred.. the file wasn't written, hope we have $buf set
		}
			
	return (
		"$subdir/$filename",
		$buf,
		$ext,
		$lastmod,
		$result
		);
	}









###############################################################################
## magick_result
##
## Purpose: Imagemagick can output warnings for just about every operation it
##          can do.  This is a shortcut function for processing the output and
##          putting some useful information to the logs.
## Accepts: An image magick warning and a piece of text describing what we
##          tried to do (in case it was a failure and we want to scream)
## Returns: 0 on failure, 1 on success
##
###############################################################################
sub magick_result {
	my ($warning, $operation) = @_;

	my ($errnum) = ($warning =~ m/(\d+)/);
	if (defined($warning) && $warning) {
		if ($errnum >= 400) {
#			print STDERR "IMGLIB: Failure $operation - ImageMagick warning '$warning'\n";
			return( {err=>100, errmsg=>"ImageMagick err[$errnum]: $operation" });
			}
		elsif (($errnum == 325) && ($warning =~ m/extraneous bytes before marker/)) {
			## Happens for a lot of images and appears to be completely non-critical
			return(undef);
			}
		}
	return undef;
	}




###############################################################################
## minimal_size
##
## Purpose: Does all the algebra for resizing an image
## Accepts: A username, an orignal image name, a requested width and a
##          requested height
## Returns: A new width and a new height
##
###############################################################################
sub minsize {
	my ($orig_width, $orig_height, $request_width, $request_height) = @_;

	if (($request_width == 0) || ($request_width > $MEDIA::max_image_size)) {
		$request_width = $MEDIA::max_image_size;
		}
	if (($request_height == 0) || ($request_height > $MEDIA::max_image_size)) {
		$request_height = $MEDIA::max_image_size;
		}
	
	my ($width,$height);
	if (($request_width == $orig_width) && ($request_height == $orig_height)) {
		## silly user, the images are the same size.
		$width  = $request_width;
		$height = $request_height;
		}
	else {
		# See how much each axis needs to be scaled by
		my $width_ratio  = ($request_width  / $orig_width);
		my $height_ratio = ($request_height / $orig_height);
		# If the scale values are equal (meaning its already proportional)
		if ($width_ratio == $height_ratio) {
			## this will prevent possible rounding errors
			$width = $request_width;
			$height = $request_height;
			}
		elsif ($width_ratio < $height_ratio) {
			## we have to scale more on  the width (i.e., it has a smaller
			## value), then use it to scale the image
			$width  = int($width_ratio * $orig_width);
			$height = int($width_ratio * $orig_height);
			}
		else {
			## we have to scale more on  the height (i.e., it has a smaller
			## value), then use it to scale the image
			$width  = int($height_ratio * $orig_width);
			$height = int($height_ratio * $orig_height);
			}
		}

	return ($width, $height);
	}


###############################################################################
## decode_args
##
## Purpose: Takes an argument string for images and returns a normalized hash
##          and string version of the args
## Accepts: The argument string, a username, and an image name
## Returns: A string of properly formatted arguments and a hashref version of the arguments
##
## W Width         - numeric (0 for orig width)
## H Height        - numeric (0 for orig height)
## B Background    - Bg color in RRGGBB format, lack of it means make it 
##                   transparent or black if no transparency is available
## M Minimal       - will not buffer out to the total size of the image
## C Crop          - Disables scaling... made for logos, it will clip an
##                   image vice scaling it
## P Pixel Sampled - Scaling mode... makes some scaled transparent GIFs look
##                   better
## F Filter        - Not saved as an actual flag, the file is reconstructed
##                   and not loaded from cache
## Z Zoovy         - Defaulted on fail for URL get for image, not saved
##
##	T Transparency	 - this will only work with PNG.
##
###############################################################################
sub parse_args {
	my ($USERNAME, $FILENAME, $args_in) = @_;

	if (not defined $args_in) { $args_in = ''; }

	my @arglist = qw(W H B M P Z T F V); # Args minus -F and -Z so we don't output any fscked images

	# Remove any non-word or dash characters.
	$args_in =~ s/[^A-Za-z0-9_-]//gis;

	my $argsref = {};

	# Compile a hash of the arguments, regardless of order
	foreach my $arg (split /\-/, $args_in) {
		next unless defined($arg);
		$arg =~ m/^([WwHhBbMmPpFfZzTtVv])(\w*)$/;
		next unless defined $1;
		my $letter = uc($1);
		my $value = defined($2) ? lc($2) : '';
		$argsref->{$letter} = $value;
		}

	
	my $args_out = '';
	if (scalar keys %{$argsref}) {
		# Handle the background color specially

		if (not defined $argsref->{'B'}) {
			## no background image
			}
		elsif ($argsref->{'B'} eq 'tttttt') {
			$argsref->{'T'}++; 
			delete $argsref->{'B'};
			}
		elsif (defined $argsref->{'B'}) {
			$argsref->{'B'} =~ s/[^a-f0-9]//g;
			if (length($argsref->{'B'}) != 6) {
				delete $argsref->{'B'};
				}
			}
		else {
			## never reached!
			}
		# We alwyas have a width and height
		## NOTE: sometimes a height/width value of "X" means that the minimal size routine failed
		##			So we couldn't figure out the correct height and width (probably a database failure) and we've
		##			decided the correct behavior is to treat the image as (max size)
		if ((not defined $argsref->{'W'}) || ($argsref->{'W'} !~ m/^\d+$/)) {
			$argsref->{'W'} = 0;
			}
		elsif ($argsref->{'W'} > $MEDIA::max_image_size) {
			$argsref->{'W'} = $MEDIA::max_image_size;
			}

		if ((not defined $argsref->{'H'}) || ($argsref->{'H'} !~ m/^\d+$/)) {
			$argsref->{'H'} = 0;
			}
		elsif ($argsref->{'H'} > $MEDIA::max_image_size) {
			$argsref->{'H'} = $MEDIA::max_image_size;
			}
		
		## Restructured this whole thing, brian's mods were causing egregious crashes.
		## Missing or zero W or H should now properly force an image into mininal mode. -AK 11/21/02
		## FUCK YOU ANTHONY - bh 
		if (
			(($argsref->{'W'} == 0) && ($argsref->{'H'} != 0)) ||
			(($argsref->{'H'} == 0) && ($argsref->{'W'} != 0))) {
			## NOTE: we leave the 0's in there, until we actually request the correct size.
			$argsref->{'M'} = ''; ## Force minimal mode
			}
		
		## Special case of no width, height or other attribs.  Serve up the original
		if (($argsref->{'W'} == 0) && ($argsref->{'H'} == 0) && ((scalar keys %{$argsref}) == 2)) {
			## This is tied to the folowing if statement in such a way that either you're returning
			## a - only for args, or the normalized compiled version of the args.
			$argsref = {};
			$args_out = '-';
			}
		else {
			# Re-output the args, in order
			foreach my $letter (@arglist) {
				next unless defined($argsref->{$letter});
				$args_out .= "$letter$argsref->{$letter}-";
				}
			# Remove a trailing slash if present
			$args_out =~ s/\-$//;
			}
		}
	else {
		$args_out = '-';
		}

	return($argsref, $args_out);
	}
	


##
## takes an iref, and returns the filepath (on disk) to a given image for stat'ing
##
sub iref_to_filepath {
	my ($USERNAME,$iref) = @_;
	die('not actually implemented');
	}

##
## takes an iref, returns the proper image filename (ex: pwd/image.ext)  for an image
##
sub iref_to_imgname {
	my ($USERNAME,$iref) = @_;
	
	if (not defined $iref) {
		return("**ERR[iref_not_set]**/notfound.gif");
		}

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select FNAME from IFOLDERS where MID=$MID /* $USERNAME */ and FID=".int($iref->{'FID'});
	if ($MEDIA::DEBUG) { print STDERR $pstmt."\n"; }
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my $pwd = '**ERR[FID:'.int($iref->{'FID'}).']**';		# this *SHOULD* get overwritten
	if ($sth->rows()) { ($pwd) = $sth->fetchrow(); }
	$sth->finish();
	&DBINFO::db_user_close();

	my $fqname = sprintf("%s/%s.%s",$pwd,$iref->{'ImgName'},$iref->{'Format'});
	if ($MEDIA::DEBUG) { print STDERR "USERNAME:$USERNAME FQNAME[$fqname]\n"; }
	return($fqname);	
	}



##
## GetInfo
## parameters:
##		FILENAME - this is a fully qualified path (e.g. subdir/image.gif) 
##		IMGBUF - a buffer, assumed to be an image, that will be read in
##		DB - 1 tells the system to check the database, 2=check database but fail to actual file (DB=0)
##		DETAIL - 0 = no instance, 1 = instance info
##		SKIP_DISK => 0|1 (0 is default)  means never go to disk even if an image exists.
##				
##		
## returns:	 (info hashref)
##		err=>0
##		FILENAME
##		EXT, H, W, SIZE, TS
##		FID 
##
## 
#   $iref = { err=>0, ImgName=>$image, Format=>$ext,  FID=>$FID,
#                     TS=>$fileinfo[10], MERCHANT=>$USERNAME, MID=>$MID, ItExists=>0,
#                     MasterSize=>length($options{'IMGBUF'}), H=>$height, W=>$width };
#
sub getinfo {
	my ($USERNAME,$FILENAME,%options) = @_;

	my ($subdir,$image,$ext) = &MEDIA::parse_filename($FILENAME);
	if ($MEDIA::DEBUG) { print STDERR "SUBDIR: $subdir [$FILENAME]\n"; }

	my $result = undef; 

#	if (not defined $options{'CACHE'}) {}
#	elsif ($options{'CACHE'}<0) {
#		my $FID = undef;
#
#		my $data = undef;
#		my $PRT = abs($options{'CACHE'})-1;
#		my $pubfile = &ZOOVY::pubfile($USERNAME, $PRT, 'images.cdb');
#		if ($pubfile ne '') {
#			my $cdb = CDB_File->TIEHASH($pubfile);
#			if ($cdb->EXISTS("*$subdir")) { $FID = $cdb->FETCH("*$subdir"); } else { $FID = 0; }
#			if ($cdb->EXISTS("$FID:$image")) { $data = $cdb->FETCH("$FID:$image"); }
#			$cdb = undef;
#			}
#		if (defined $data) { $result = YAML::Syck::Load($data);	}
#		}

#	print STDERR "MEDIA::getinfo did not use publisher file!\n";

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $DB = (defined $options{'DB'})?int($options{'DB'}):1;		## assume we can do a database lookup
	my $FID = undef;
	if (not defined $result) {
		$FID = &MEDIA::resolve_fid($USERNAME,$subdir);
		}

	if (defined $options{'IMGBUF'}) { $DB  = -1; }	# found it (we'll technically we were passed it!)

	## added FID>0
	if (defined $result) {
		}
	elsif (($DB>0) && ($FID>0)) {
		#+------------+-------------------------+------+-----+---------+----------------+
		#| Field      | Type                    | Null | Key | Default | Extra          |
		#+------------+-------------------------+------+-----+---------+----------------+
		#| Id         | int(11)                 | NO   | PRI | NULL    | auto_increment |
		#| ImgName    | varchar(45)             | NO   |     | NULL    |                |
		#| Format     | enum('gif','jpg','png') | YES  |     | NULL    |                |
		#| TS         | int(10) unsigned        | NO   |     | 0       |                |
		#| MERCHANT   | varchar(20)             | NO   |     | NULL    |                |
		#| MID        | int(11)                 | NO   | MUL | 0       |                |
		#| FID        | int(11)                 | NO   |     | 0       |                |
		#| ItExists   | tinyint(4)              | NO   |     | 0       |                |
		#| ThumbSize  | int(10) unsigned        | NO   |     | 0       |                |
		#| MasterSize | int(10) unsigned        | NO   |     | 0       |                |
		#| H          | smallint(6)             | NO   |     | -1      |                |
		#| W          | smallint(6)             | NO   |     | -1      |                |
		#+------------+-------------------------+------+-----+---------+----------------+

		my $dbh = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "select * from IMAGES where FID=$FID and MID=$MID /* $USERNAME */ and ImgName=".$dbh->quote($image);
		if ($MEDIA::DEBUG) { print STDERR $pstmt."\n"; }
		my $sth = $dbh->prepare($pstmt);
		$sth->execute();
		if ($sth->rows()) {
			$result = $sth->fetchrow_hashref();
			if (($result->{'W'}>0) && ($result->{'H'}>0) && ($result->{'Format'} ne '')) { 
				$DB = -1; ## found it!
				} 
			else { 
				$DB = 0; $result = undef; ## corrupt db record ( go to disk )
				} 
			}
		else {
			if ($DB==1) { $result = { err=>10, errmsg=>"could not find file in database" }; }
			}
		$sth->finish();
		&DBINFO::db_user_close();

		# use Data::Dumper;
		# print STDERR 'getinfo: '.Dumper($result);
		}


	my @fileinfo = ();
	## DB=0 go directly to disk
	##	DB=2 if we get here, iz corrupt! (rebuild db record)
	if ((($DB==0) || ($DB==2)) && (not defined $result)) {
		## don't use the database (we'll just open the file and load it into IMGBUF then fall through)

		my $userdir = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES';
		foreach my $ext ('jpg','gif','png') {
			next if (defined $options{'IMGBUF'});		# found it already!
			print STDERR "getinfo reading from $userdir/$subdir/$image.$ext\n";
			my @fileinfo = stat("$userdir/$subdir/$image.$ext");
			next unless ($fileinfo[7]>0);		# check the size

			## the file exists, lets read it in.
			$/ = undef;
			open F, "<$userdir/$subdir/$image.$ext";
			$options{'IMGBUF'} = <F>;
			close F;
			$/ = "\n";
			}
		if (not defined $options{'IMGBUF'}) {
			$result = { err=>11, errmsg=>"Could not find original file on disk" }
			}
		}

	if (defined $result) {
		## already got a result
		}
	elsif ((defined $options{'IMGBUF'}) && (defined $options{'SKIP_DISK'}) && ($options{'SKIP_DISK'}>0)) {
		## return an error, rather than try to load actual image
		$result = { err=>12, errmsg=>"Prohibited from attempting to load original" }
		}
	elsif (defined $options{'IMGBUF'}) {
		require Image::Magick;
		my $imgblob = Image::Magick->new();

		# perl -e 'use Image::Magick;   $image=Image::Magick->new; print $image->get("Version");'
		#if ($imgblob->get("Version") ne 'ImageMagick 6.5.3-3 2009-07-03 Q16') {
		#	warn "I am running a different version of ImageMagick than I should be.";
		#	}


		$result = &MEDIA::magick_result( 
			$imgblob->BlobToImage($options{'IMGBUF'}),
			"reading $subdir/$image.$ext"
			);
		
		if (not defined $result) {
			## if result is still undef - then image was read in successfully
			my $width  = $imgblob->Get('width');
			my $height = $imgblob->Get('height');


			if ($imgblob->VERSION() eq '5.56') {
				## old image magick on app3 (we'll just trust the file extension)
				}
			else {
				my $mime = $imgblob->Get('mime');
				if ($mime eq 'image/jpeg') { $ext = 'jpg'; } 
				elsif ($mime eq 'image/gif') { $ext = 'gif'; }
				elsif ($mime eq 'image/png') { $ext = 'png'; }
				elsif (not defined $mime) {}
				else { warn "found unknown mime [$mime]"; }
				}

			if (not defined $fileinfo[10]) { $fileinfo[10] = time(); }
			if (&ZTOOLKIT::def($width) && &ZTOOLKIT::def($height)) {
				$result = { err=>0, ImgName=>$image, Format=>$ext,  FID=>$FID,
							TS=>$fileinfo[10], MERCHANT=>$USERNAME, MID=>$MID, ItExists=>0, 
							MasterSize=>length($options{'IMGBUF'}), H=>$height, W=>$width };
				}

			## okay since it wasn't in the database, we should update the database
			my $dbh = &DBINFO::db_user_connect($USERNAME);
			my $pstmt = sprintf(
				"update IMAGES set Format=%s,H=%d,W=%d,MasterSize=%d where MID=%d /* %s */ and FID=%d and ImgName=%s",
				$dbh->quote($ext),$height,$width,length($options{'IMGBUF'}),$MID,$USERNAME,$FID,$dbh->quote($image));
			my $rows_affected = $dbh->do($pstmt);			

			## added 2007-05-23 - patti, do's return # of rows affected or zero (0E0)	
			if (int($rows_affected) == 0) {
				my $pstmt = sprintf(
				"insert into IMAGES (TS,MERCHANT,Format,H,W,MasterSize,MID,FID,ImgName) values ".
				"(%s,%s,%s,%d,%d,%d,%d,%d,%s)", 
				$^T,$dbh->quote($USERNAME),$dbh->quote($ext),$height,$width,length($options{'IMGBUF'}),$MID,$FID,$dbh->quote($image));	
				$dbh->do($pstmt);
				}
				
			&DBINFO::db_user_close();
			}
		}


#	if (($options{'DETAIL'}&1)==1) {
#		## adds a *INSTANCES to the result which is an array of images
#		my @files = &MEDIA::related_files($USERNAME,$FILENAME);
#		$result->{'*INSTANCES'} = [];
#		foreach my $file (@files) {
#			if ($file =~ /^$image\-(.*?)\./) {
#				my $args = $1;
#				@fileinfo = stat "$userdir/$subdir/$file";
#				my ($argsref,$argstr) = MEDIA::parse_args($USERNAME,$image,$args);
#			
#				push @{$result->{'*INSTANCES'}}, { Img=>$file, Size=>$fileinfo[7], TS=>$fileinfo[10], H=>$argsref->{'H'}, W=>$argsref->{'W'} }; 
#				}
#			}
#		}
	

#	## Does the image look good to imagemagick?
#	)
#	{
#		$MEDIA::DEBUG && &msg("new_collection_binfile_hash($USERNAME, $imagename, $nuke): Image looks good to imagemagick");
#		{
#			$collection_hash = {
#				'original'       => $original,
#				'created'        => time(),
#				'orig_filesize'  => $fileinfo[7],
#				'orig_timestamp' => $fileinfo[10],
#				'orig_width'     => $width,
#				'orig_height'    => $height,
#				'ver'            => $IMGLIB::version,
#				'subs'           => {},
#			};
#		}
#		else
#		{
#			&msg("new_collection_binfile_hash($USERNAME, $imagename, $nuke): Unable to get width or height from ImageMagick on $userdir/$subdir/$original for $imagename!");
#		}

	return($result);
	}


###############################################################################
## find_instances
##
## Purpose: Locates all of the modified copies of an original image
## Accepts: A user name, an original image name, whether to sort the output,
##          and whether to ignore the .bin file and read the directory the
##          image is in directly.
## Returns: An array of filenames of the instances of the original image
##				NOTE: this is a *VERY* expensive call, and should be used with care.
##
###############################################################################
#sub related_files {
#	my ($USERNAME, $FILENAME) = @_;
#
#	my $userdir = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES';
#	my ($subdir,$image,$ext) = &MEDIA::parse_filename($FILENAME);
#
#	my @files = ();
#	if (opendir IMAGES, "$userdir/$subdir") {
#		## Looks for all instance and original image names
#		while (my $ifile = readdir IMAGES) {
#			next unless ($ifile =~ m/^$image[\.\-]/);
#			push @files, $ifile;
#			}
#		closedir IMAGES;
#		}
#	return @files;
#	}


##
## nukes an image and all instances
##		%opts
##			original=>0 means save the original (nuke_collection)   [defaults to 1]
##			instances=>0 means save the instances						  [defaults to 1]
##	
sub nuke {
	my ($USERNAME,$FILENAME,%opts) = @_;

	## &IMGLIB::nuke_collection($USERNAME,"$PWD/$FILE",1);
	## &IMGLIB::nuke_instances($USERNAME,"$PWD/$FILE",0);

	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);
	if (defined $gref->{'%tuning'}) {
		if ($gref->{'%tuning'}->{'inhibit_image_nukes'}) {
			warn "Sorry, can't remove images due to %tuning->inhibit_image_nukes";
			return(undef);
			}
		}


	my $nuke_orig = (defined $opts{'original'})?int($opts{'original'}):1;
#	my $nuke_inst = (defined $opts{'instances'})?int($opts{'instances'}):1;

	my $userdir = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES';
	my ($subdir,$image,$ext) = &MEDIA::parse_filename($FILENAME);

#	my @files = &MEDIA::related_files($USERNAME,"$FILENAME");
#	foreach my $file (@files) {
#		my $unlink = 0;
#		if ($file =~ /\.bin$/) { $unlink++; }
#		elsif (($nuke_inst) && ($file =~ /^$image\-/)) { $unlink++; }	# found an instance
#		elsif (($nuke_orig) && ($file =~ /^$image\./)) { $unlink++; }	# found an instance
#		if ($unlink) {
#			unlink "$userdir/$subdir/$file";
#			}
#		}

	## if we're removing the original, then we really ought to remove it from the database too.
	if ($nuke_orig) { 
		&MEDIA::delimage($USERNAME,$subdir,$image); 
		}
	
	return(undef);
	}


############################################################
##
## parameters:
##	
##	returns:
##		a GetInfo struct
sub store {
	my ($USERNAME,$FILENAME,$IMGBUF,%params) = @_;

	my $iref = undef;

	if ((not defined $iref) && ((not defined $USERNAME) || ($USERNAME eq ''))) {
		$iref = { err=>998, errmsg=>"Username not provided" };
		}

	if ((not defined $iref) && ((not defined $FILENAME) || ($FILENAME eq ''))) {
		$iref = { err=>997, errmsg=>"Filename must be provided." };
		}
		
#	if ($FILENAME !~ /\.(jpg|gif|png)$/i) {
#		$iref = { err=>996, errmsg=>"sorry only .JPG, .PNG, .GIF file formats are supported." };
#		}

	if ((not defined $iref) && (length($IMGBUF) <= 20)) { 
		$iref = { err=>99, errmsg=>"File too short" };
		}


	if ((not defined $iref) && ($IMGBUF =~ /^\s*<.*>\s*/)) {
		$iref = { err=>98, errmsg=>"File appears to be html" };
		}


	my $userdir = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES';
	my ($subdir,$image,$ext) = &MEDIA::parse_filename($FILENAME);
	$image =~ s/[_\s]+$//g;		# strip any underscores at the end of the filename (e.g. image___)

	#print STDERR "DEBUG: [$FILENAME]=[$subdir][$image][$ext]\n";
	#print STDERR "DEBUG: [FILEPATH]=[$userdir/$subdir/$image.$ext]\n";
	if (! -d "$userdir/$subdir") {
		## make sure the path actually exists.
		open F, ">>/tmp/folder";
		print F "$USERNAME,$subdir\n";
		close F;
		&MEDIA::mkfolder($USERNAME,"$subdir");
		}

	my $extensions = join('|', @MEDIA::ext, 'jpeg');
	my $extensions2 = join('|', @MEDIA::ext2);

	if (defined $iref) {
		}
	elsif ($ext =~ m/^($extensions2)$/i) {
		}
	elsif ($ext =~ m/^($extensions)$/i) {
		## this is good!
		}
	elsif ((defined $params{'allow_extension'}) && ($params{'allow_extension'})) {
		## if this is true, the extension is allowed.
		}
	else {
		$iref = { err=>50, errmsg=>"Invalid image format [$ext]!" };
		}

	if ($ext ne '') {
		if (-f "$userdir/$subdir/$image.$ext") {
			## TODO: file already exists, we should nuke it and all instances
			&MEDIA::nuke($USERNAME,"$FILENAME");
			}
		}

	
	if (defined $iref) {}
	else {

		if ($ext eq 'jpg') {
			## NOTE: eventually we might want to handle TIFF and BMP here!
			require Image::Magick;
			my $p = Image::Magick->new(magick=>'jpg');
			$p->BlobToImage($IMGBUF);
         my ($format) = $p->get("format");
         my ($cs) = $p->get("colorspace");
			if ($cs eq 'CMYK') {
				## warning: customer uploaded a CMYK jpg file!
				$p->set("colorspace"=>"RGB");
				($IMGBUF) = $p->ImageToBlob();
				}
			}

		## format the filename
		$image =~ s/^[\s]+//g;	# strip leading space
		$image =~ s/[\s]+$//g;	# strip trailing space

		my $filename = "$userdir/$subdir/$image.$ext";
		my $got_fh = 0;
		unless (open FILE, ">$filename") { 
			$iref = { err=>3, errmsg=>"Could not open file [$filename] for write access" }; 
			}

		unless (defined $iref) {
			print FILE $IMGBUF;
			close FILE;
			chmod(0666, $filename);
			chown($ZOOVY::EUID,$ZOOVY::EGID,$filename);
			}
	
		if (not $iref->{'err'} ) {
			&MEDIA::addimage($USERNAME,$subdir,$image,$ext,time(),length($IMGBUF));
         $iref->{'folder'} = $subdir;
         $iref->{'image'} = "$image.$ext";
			}
		}

	if (not defined $iref) {
		$iref = &MEDIA::getinfo($USERNAME,sprintf("%s/%s.$ext",$subdir,$image,$ext),IMGBUF=>$IMGBUF);
		}

	if ($MEDIA::DEBUG) { use Data::Dumper; print STDERR "RESULT: ".Dumper($iref)."\n"; }
	return($iref);
	}


##
## assumes that asdf.gif should actually be A/asdf.gif
##
sub parse_filename {
	my ($filename) = @_;

#	print STDERR "1FILENAME:[$filename]\n";

	$filename =~ s/[^\w\-\.\/]+/_/g;		# strip everything but dashes, alphanum and periods
	$filename =~ s/[\.]+/\./g;			# change double periods to ..
	$filename =~ s/^\.//g;					# remove leading periods
	$filename =~ s/[\s_]+$//; ## strip trailing spaces and underscoress
	$filename =~ s/[\/]+/\//g;			# remove duplicate slashes
	if (substr($filename,0,1) eq '/') { $filename = substr($filename,1); }	# remove a leading /

	if ($filename eq '') { return(undef); }

	## we got to get rid of periods
	#print STDERR "FILE: $filename\n";

	my ($name,$path,$suffix) = File::Basename::fileparse($filename,qr{\.[Jj][Pp][Ee][Gg]|\.[Jj][Pp][Gg]|\.[Pp][Nn][Gg]|\.[Gg][Ii][Ff]});
	## note: suffix has a .jpeg or .jpg (notice the leading period)
	$name = lc($name); 
	$name =~ s/[^a-z0-9\_]+/_/gs;
## Commented out due to conversation with Brian
#	$name =~ s/[\s_]+$//g;		## NO TRAILING SPACES!
	if (substr($path,0,2) eq './') { $path = substr($path,2); }
	$filename = "$path$name$suffix";

	## translate legacy filenames e.g. asdf.gif => A/asdf.gif
	if (index($filename,'/')==-1) {
		$filename = uc(substr($filename,0,1)).'/'.$filename;
		}


	my $ext = undef;
	my $imgname = "";
#	print STDERR "FILENAME[$filename]\n";
	my $pos = rindex($filename,'.');
	if ($pos>0) {
		$imgname = substr($filename,0,$pos);
		$ext = lc(substr($filename,$pos+1));		
		}
	else {
		## hmm.. no extensioN!
		$imgname = $filename;
		}

	##
	## SANITY: at this point $ext is either set, or it won't be.
	##			$imgname has something like A/asdf (so we'll need to split out subdir)
	
	$pos = rindex($imgname,'/')+1;
	# print STDERR "POS: $pos [$imgname]\n";
	my $subdir = substr($imgname,0,$pos-1);
	$imgname = lc(substr($imgname,$pos));	
	$imgname = substr($imgname,0,$MEDIA::max_name_length);			# max image name length is 80 characters

	if (length($subdir)==1) { $subdir = uc($subdir); }	# single char dirs e.g. P/palm_m500 are always uppercase

	my @pwds = ();
	foreach my $str (split(/\//,$subdir)) {
		if ((length($str)==1) && (scalar(@pwds)==0)) { 
			push @pwds, uc($str); 
			} 
		else { 
			push @pwds, lc($str); 
			}
		}
	$subdir = join('/',@pwds);

	return($subdir,$imgname,$ext);
	}



##
## returns a list of images for a given folder .. (used by webapi.pm)
##		key: imagename.ext  val: timestamp
##
sub folderdetail {
	my ($USERNAME, $PWD) = @_;

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $FID = &MEDIA::resolve_fid($USERNAME,$PWD);
	my %result = ();

	my $pstmt = "select ImgName,Format,TS from IMAGES where MID=$MID and FID=".$FID;
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	while ( my ($i,$e,$ts) = $sth->fetchrow() ) { 
		$result{$i.(($e ne '')?'.'.$e:'')} = $ts; 
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\%result);
	}

##
## returns an array of hashrefs 
##		keys in hashref: ImageCount,TS,ImgName,FID,ParentFID,ParentName
##
sub folderlist {
	my ($USERNAME) = @_;

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my @result = ();

	my $pstmt = "select ImageCount,TS,FName,FID,ParentFID,ParentName from IFOLDERS where MID=$MID order by FName";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	while ( my $hashref = $sth->fetchrow_hashref() ) { 
		push @result, $hashref;
		}
	$sth->finish();
	&DBINFO::db_user_close();
	return(\@result);
	}


sub foldertree {
	my ($USERNAME) = @_;

	my %FOLDERS = ();
	#foreach my $r (@{MEDIA::folderlist($USERNAME)}) {
	#	$r->{'FName'}
	#	}


	}

sub r_foldertree {
	}


##
## pass FID==0 to get all images
##
sub imglist {
	my ($USERNAME,$FID) = @_;
	
	my @results = ();
	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $pstmt = "select ImgName,Format,FID from IMAGES where MID=$MID /* $USERNAME */";
	if ($FID>0) { $pstmt .= " and FID=".int($FID); }

	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	while ( my $ref = $sth->fetchrow_hashref() ) {
		push @results, $ref;
		}
	$sth->finish();
	
	&DBINFO::db_user_close();
	return(\@results);
	}


##
## note: pass a depth of -1 to not descend the tree!
##
sub reindex {
	my ($USERNAME, $PWD, $DEPTH) = @_;

	require Image::Magick;
	if (not defined $PWD) { $PWD = ''; }
	elsif ($PWD eq '/') { $PWD = ''; }

	if (substr($PWD,0,1) eq '/') { $PWD = substr($PWD,1); }	# strip leading / from PWD if necessary
	# print "DOING PATH: $USERNAME $PWD\n";

	if (not defined $DEPTH) { $DEPTH = 0; }
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $OLDFID = &MEDIA::resolve_fid($USERNAME,$PWD);

	if ($PWD eq '') {
		my $dbh = &DBINFO::db_user_connect($USERNAME);
		my $pstmt = "delete from IFOLDERS where MID=$MID";
		# print STDERR $pstmt."\n";
		$dbh->do($pstmt);
		$pstmt = "delete from IMAGES where MID=$MID";
		# print STDERR $pstmt."\n";
		$dbh->do($pstmt);
		&DBINFO::db_user_close();
		}

	## note: if PWD is set e.g. "A" then it should be "/$PWD" otherwise just ""
	my $PATH = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES'.(($PWD eq '')?'':"/$PWD");

	my @SUBDIRS = ();
	my @FILES = ();

	my $D = undef;
	opendir $D, $PATH;
	my @NUKE = ();
	while ( my $file = readdir($D)) {
		# print "FILE: $file\n";

		next if (substr($file,0,1) eq '.');
		if (-d $PATH.'/'.$file) { push @SUBDIRS, $file; }		# subdirs
		elsif (($PWD eq '') || ($PWD eq '/')) {}	# root directory is custom files (don't index)
		## NOTE: the line below is *VERY* bad it removes images with a dash which can be uploaded as part of pm system.
		# elsif ($file =~ /\-/) { push @NUKE, $PATH.'/'.$file; }		# nuke instances
		elsif ($file =~ /\.bin$/) { push @NUKE, "$PATH/$file"; }	# ignore binfiles
		else { 

			if (1) {
				my $p = new Image::Magick;
				$p->Read("$PATH/$file");
				my ($format) = $p->get("format");
				my ($cs) = $p->get("colorspace");
			
				if ($cs eq 'CMYK') {
					print STDERR "$PATH/$file UPGRADING CMYK FORMAT: $format [$cs]\n";
					## converting from CMYK to RGB
					$p->set("colorspace"=>"RGB");
					$p->Write("$PATH/$file");				
					}
				}

			#next if (($format =~ /CompuServe/) && ($file =~ /\.gif$/));
			#next if (($format =~ /Joint Photographic/) && ($file =~ /\.jpg$/));
			#next if (($format =~ /Portable Network Graphics/) && ($file =~ /\.png$/));


			if ($file =~ /(.*?)\.jpeg$/) {
				## renames filename.jpeg to filename.jpg
				$file = $1; 
				rename("$PATH/$file.jpeg","$PATH/$file.jpg"); 
				$file .= ".jpg";
				}
			elsif ($file =~ /(.*?)\.(tif|bmp|tiff)$/) {
				## converts files of specific types to .png
				($file,my $ext) = ($1,$2);
   	      my $p = Image::Magick->new();
      	   $p->Read("$PATH/$file.$ext");
				$p->Set('magick'=>'png');
				$p->Write("$PATH/$file.png");
				chmod(0666,"$PATH/$file.png");
				chown($ZOOVY::EUID,$ZOOVY::EGID,"$PATH/$file.png");
				rename("$PATH/$file.$ext","$PATH/.$file.$ext");
				$file = "$file.png";
				}

			## strip any trailing spaces in the image name during a reindex
			if ($file =~ /^(.*)[_\s]+\.(jpg|png|gif)$/) {
				my ($file2,$ext2) = ($1,$2);
				print STDERR "RENAMING FILE: $PATH/$file to $PATH/$file2.$ext2\n";
				rename("$PATH/$file","$PATH/$file2.$ext2");
				$file = "$file2.$ext2";
				}

			push @FILES, $file; 
			}									
		# keep actual images
		}
	closedir($D);

	foreach my $nuke (@NUKE) {
#		die("Should never be reached");
		&ZOOVY::log($USERNAME,'',"MEDIA.REDINEX","Reindex script removed $nuke","WARN");
		unlink($nuke); 
		}

	# use Data::Dumper; print Dumper(\@SUBDIRS);
	## Now, lets recurse through directories. (if any)
	if (($DEPTH>=0) && ($DEPTH<5)) {
		foreach my $d (@SUBDIRS) { 
			# print STDERR "INDEXING: $d\n";
			&MEDIA::reindex($USERNAME, $PWD.'/'.$d, $DEPTH+1); 
			}
		}

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	if ($OLDFID > 0) {
		## okay now lets blow out this directory in the database!
		my $pstmt = "delete from IFOLDERS where MID=$MID and FID=".$dbh->quote($OLDFID);
#		print STDERR $pstmt."\n";
		$dbh->do($pstmt);

		$pstmt = "delete from IMAGES where MID=$MID and FID=".$dbh->quote($OLDFID);
#		print STDERR $pstmt."\n";
		$dbh->do($pstmt);
		}

	&MEDIA::mkfolder($USERNAME,$PWD);
	my $NEWFID = &MEDIA::resolve_fid($USERNAME,$PWD);

	my $pstmt = "update IFOLDERS set ParentFID=$NEWFID where MID=$MID and ParentFID=$OLDFID";
	#	print STDERR $pstmt."\n";
	$dbh->do($pstmt);

	if ($PWD ne '') {
		## okay, now lets interate through each file and add them to the database 
		foreach my $f (@FILES) {
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($PATH.'/'.$f);
	
			# print "F: $f\n";
			my ($fimg, $ext) = split(/\./,$f);
			&MEDIA::addimage($USERNAME,$PWD,$fimg,$ext,$mtime,$size);
			## this line will update the sizes.
			&MEDIA::getinfo($USERNAME,"$PWD/$f",CACHE=>0);
			}		
		}

	&DBINFO::db_user_close();
	}


##
## call this when we add an image (maintains media library sync database)
##
sub addimage {
	my ($USERNAME,$PWD,$IMGNAME,$FORMAT,$TS,$MASTERSIZE,$H,$W) = @_;
	
	if (substr($PWD,0,1) eq '/') { $PWD = substr($PWD,1); }	## remove leading /
	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = int(&ZOOVY::resolve_mid($USERNAME));

	my $FID = &MEDIA::resolve_fid($USERNAME,$PWD);
	if ($FID==-1) {
		## hmm.. folder doesn't exist!?!?!
		&MEDIA::mkfolder($USERNAME,$PWD);
		$FID = &MEDIA::resolve_fid($USERNAME,$PWD);
		}
		

	if (length($IMGNAME)>$MEDIA::max_name_length) {
		warn("Image [$IMGNAME] length is too long!");
		$IMGNAME = substr($IMGNAME,0,$MEDIA::max_name_length);
		}

	if (not defined $FORMAT) { $FORMAT = ''; }

	my %vars = ();
	$vars{'ImgName'} = lc($IMGNAME); 
	$vars{'Format'} = $FORMAT;
	$vars{'TS'} = $^T;
	$vars{'MERCHANT'} = $USERNAME;
	$vars{'MID'} = $MID;
	$vars{'FID'} = $FID;
	if (defined $MASTERSIZE) { $vars{'MasterSize'} = int($MASTERSIZE); }
	if ((defined $H) && (defined $W)) { $vars{'H'} = $H; $vars{'W'} = $W; }
	
	my $pstmt = &DBINFO::insert($dbh,'IMAGES',\%vars,debug=>2,key=>['MID','FID','ImgName']);
	#my $pstmt = "insert into IMAGES (ImgName,Format,TS,MERCHANT,MID,FID,MasterSize) values (";
	# $pstmt .= $dbh->quote($IMGNAME).','.$dbh->quote($FORMAT).','.time().','.$dbh->quote($USERNAME).','.$MID.','.$FID.','.int($MASTERSIZE).')';
#	print STDERR $pstmt."\n";
	if (defined $dbh->do($pstmt)) {
		&MEDIA::bumpfolder($USERNAME,$PWD,+1);	
		}

	&DBINFO::db_user_close();
	return();
	}

##
## call this when we delete an image (maintains media library  sync database)
##
sub delimage {
	my ($USERNAME,$PWD,$IMGNAME) = @_;

	if (substr($PWD,0,1) eq '/') { $PWD = substr($PWD,1); }	## remove leading /
	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = int(&ZOOVY::resolve_mid($USERNAME));

	my $FID = &MEDIA::resolve_fid($USERNAME,$PWD);
	my $pstmt = "select Id,Format from IMAGES where MID=$MID and FID=$FID and ImgName=".$dbh->quote($IMGNAME)." limit 1";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my ($Id,$Format) = $sth->fetchrow();
	$sth->finish();

	if (($FID > 0) && ($Id>0)) {
		my $pstmt = "delete from IMAGES where MID=$MID /* $USERNAME */ and FID=$FID and Id=$Id and ImgName=".$dbh->quote($IMGNAME)." limit 1";
#		print STDERR $pstmt."\n";
		if (defined $dbh->do($pstmt)) {

			my $userdir = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES';
			my ($subdir,$image,$ext) = &MEDIA::parse_filename("$PWD/$IMGNAME");
			if ($ext eq '') { $ext = $Format; }
			$ext = lc($ext);

			unlink "$userdir/$subdir/$image.$ext";
			&MEDIA::bumpfolder($USERNAME,$PWD,-1);	
			}
		}

	&DBINFO::db_user_close();
	}

##
## returns the folder id for a given pwd
##
sub resolve_fid {
	my ($USERNAME,$PWD) = @_;

	if (substr($PWD,0,1) eq '/') { $PWD = substr($PWD,1); }	## remove leading /
	if ($PWD eq '') { return 0; }

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	if ($MEDIA::CACHE_FIDSTR eq "$MID!$PWD") {
		return($MEDIA::CACHE_FID);
		}

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select FID from IFOLDERS where MID=$MID and FNAME=".$dbh->quote($PWD);
	if ($MEDIA::DEBUG) { print STDERR $pstmt."\n"; }
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	my ($FID) = $sth->fetchrow();
	$sth->finish();
	if (not defined $FID) { $FID = -1; }
	&DBINFO::db_user_close();
	$FID = int($FID);

	## this is a global variable, that will prevent us from doing the same lookup twice
	if ($FID>0) { $MEDIA::CACHE_FID = $FID; $MEDIA::CACHE_FIDSTR = "$MID!$PWD"; }
	
	return($FID);
	}


##
## returns 1 if a folder exists, 0 if not.
##


##
## creates a new folder
##		returns: new PWD
sub mkfolder {
	my ($USERNAME, $PWD) = @_;

	$MEDIA::CACHE_FID = undef;
	$MEDIA::CACHE_FIDSTR = undef;
	if ($PWD eq '') { return(); }

	my $DSTDIR = &ZOOVY::resolve_userpath($USERNAME)."/IMAGES/".$PWD;

	if (substr($PWD,0,1) eq '/') { $PWD = substr($PWD,1); }	## remove leading /
	$PWD =~ s/[\.]+/_/gs;
	
	my $PARENT = $PWD;
	if (rindex($PARENT,'/')>=0) { $PARENT = substr($PARENT,0,rindex($PARENT,'/')); } else { $PARENT = '/'; }
	if ($PARENT eq '') { $PARENT = ''; }

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = int(&ZOOVY::resolve_mid($USERNAME));

	my $ParentFID = -1;
	if ($PARENT eq '') { 
		## verify the parent exists. and if it doesn't, perhaps we ought to create it.
		}
	elsif ($PARENT eq '/') {
		## we assume /IMAGES always exists
		}
	elsif (-d $DSTDIR ) {
		## yay it exists
		}
	else {
		&mkfolder($USERNAME,$PARENT);
		}
	$ParentFID = &MEDIA::resolve_fid($USERNAME,$PARENT); 
	if ($ParentFID < 0) {
		&MEDIA::mkfolder($USERNAME,$PARENT);
		$ParentFID = &MEDIA::resolve_fid($USERNAME,$PARENT); 
		}


	my $FID = &MEDIA::resolve_fid($USERNAME,$PWD);
	print STDERR "FID:$FID PWD: $PWD\n";

	if ($FID > 0) {
		if (! -d  $DSTDIR) {
			warn "$DSTDIR doesn't actually exist, but has FID:$FID\n";
			File::Path::mkpath($DSTDIR,0,0777);
			}
		}
	elsif ($FID==-1) {
		## physically create the directory
		if (length($PWD)>1) { 
			$PWD = lc($PWD); 
			if ($PWD =~ /^[a-z0-9]\//) { $PWD = ucfirst($PWD); } # but keep uppercased single character directories.
			} 
		else { 
			$PWD = uc($PWD); 
			}
		my $PATH = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES/'.$PWD;
		# print STDERR "PATH: $PATH\n"; die();
		mkdir($PATH);
		chmod 0777, $PATH;

		## create index in database.
		my $pstmt = &DBINFO::insert($dbh,'IFOLDERS',{
			FName=>$PWD,ImageCount=>0,MERCHANT=>$USERNAME,MID=>$MID,
			ParentFID=>$ParentFID,ParentNAME=>$PARENT,TS=>$^T,ItExists=>1
			},debug=>2);
		$dbh->do($pstmt);
		}
	&DBINFO::db_user_close();
	

	return($PWD);
	}


##
## rmfolder - deletes a folder
##		returns: parent PWD
sub rmfolder {
	my ($USERNAME, $PWD) = @_;

	$MEDIA::CACHE_FID = undef;
	$MEDIA::CACHE_FIDSTR = undef;
	if (substr($PWD,0,1) eq '/') { $PWD = substr($PWD,1); }	## remove leading /

	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "delete from IFOLDERS where MID=$MID and FNAME=".$dbh->quote($PWD);
	$dbh->do($pstmt);
	&DBINFO::db_user_close();

	my $PATH = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES/';

	my $imageref = &MEDIA::listimgs("$PATH/$PWD");
   if (defined $imageref) {
		foreach my $img (keys %{$imageref}) {
			&MEDIA::delimage($USERNAME,$PWD,$img);
			}
		}
	
	
	## need to delete bin files too
	#opendir (DIR, $PATH.$PWD);
	#my @files = grep /\.bin$/, readdir(DIR);
	#closedir DIR;	
	#foreach my $file (@files) {
	#	unlink ($PATH.$PWD."/".$file);
	#	}
	
	rmdir($PATH.$PWD);

	## descend down a level
	if (rindex($PWD,'/')>=0) { $PWD = substr($PWD,0,rindex($PWD,'/')); } else { $PWD = '/'; }
	if ($PWD eq '') { $PWD = ''; }

	return($PWD);
	}


##
## call this anytime you add/remove/update an image in a folder! to maintain the count
##
sub bumpfolder {
	my ($USERNAME, $PWD, $IMGCOUNT) = @_;

	$IMGCOUNT = int($IMGCOUNT);
	
	if (substr($PWD,0,1) eq '/') { $PWD = substr($PWD,1); }	## remove leading /
	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);

	my $pstmt = "update IFOLDERS set TS=".time().",ImageCount=ImageCount+$IMGCOUNT where MID=$MID and FNAME=".$dbh->quote($PWD);
#	print STDERR $pstmt."\n";
	$dbh->do($pstmt);

	&DBINFO::db_user_close();	
	}


##
## converts a filename to a base name. (e.g. asdf-w100-h100-bffff.jpg becomes asdf)
##
sub filespec {
	my ($filename) = @_;
	$filename =~ s/\..*?$//gs;	# strip off extension
	if (index($filename,'-')>0) {
		$filename = substr($filename,0,index($filename,'-'));
		}
	return($filename);
	}

##
## returns: a hashref of folders with the value as their respective file counts
##
sub folders {
	my ($USERNAME,$PWD) = @_;

	my %folders = ();
	my %files = ();

	my $dbh = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $parentFID = &MEDIA::resolve_fid($USERNAME,$PWD);

	if ($parentFID == -1) {
		## bad directory!
		return(undef,undef);
		}

	my $pstmt = "select FName,ImageCount from IFOLDERS where ParentFID=$parentFID and MID=$MID /* $USERNAME */";
	# print STDERR $pstmt."\n";
	my $sth = $dbh->prepare($pstmt);
	$sth->execute();
	while ( my ($fname,$imgcount) = $sth->fetchrow() ) {
		$folders{$fname} = $imgcount;
		}
	$sth->finish();

	$pstmt = "select ImgName from IMAGES where FID=$parentFID and MID=$MID /* $USERNAME */";
	$sth = $dbh->prepare($pstmt);
	$sth->execute();
	while ( my ($fname) = $sth->fetchrow() ) {
		$files{$fname}++; 
		}
	$sth->finish();
	&DBINFO::db_user_close();

	return(\%folders,\%files);
	}


##
## returns: a hashref of folders with the value as their respsective file counts
##
sub foldersDEPRECATED {
	my ($USERNAME,$PWD) = @_;

	my %folders = ();
	my %files = ();

	if (substr($PWD,0,1) eq '/') { $PWD = substr($PWD,1); }	# strip leading /

	my $path = &ZOOVY::resolve_userpath($USERNAME).'/IMAGES';
	if (($PWD eq '') || ($PWD eq '/')) {
		## do nothing
		}
	else {
		$path = $path.'/'.$PWD;
		}

#mysql> desc IFOLDERS;
#+------------+------------------+------+-----+---------+----------------+
#| Field      | Type             | Null | Key | Default | Extra          |
#+------------+------------------+------+-----+---------+----------------+
#| FID        | int(11)          |      | PRI | NULL    | auto_increment |
#| FName      | varchar(35)      |      |     |         |                |
#| ImageCount | int(11)          |      |     | 0       |                |
#| MERCHANT   | varchar(20)      |      |     |         |                |
#| MID        | int(11)          |      | MUL | 0       |                |
#| ParentFID  | int(10) unsigned |      |     | 0       |                |
#| ParentName | varchar(175)     |      |     |         |                |
#| TS         | int(10) unsigned |      |     | 0       |                |
#| ItExists   | tinyint(4)       |      |     | 0       |                |
#+------------+------------------+------+-----+---------+----------------+
#9 rows in set (0.03 sec)
#	my $dbh = &DBINFO::db_user_connect($USERNAME);
#	my $MID = &ZOOVY::resolve_mid($USERNAME);
#	my $parentFID = &MEDIA::resolve_fid($USERNAME,$PWD);
#
#	if (1) {
#		my $pstmt = "select FName,ImageCount from IFOLDERS where ParentFID=$parentFID and MID=$MID /* $USERNAME */";
#		my $sth = $dbh->prepare($pstmt);
#		$sth->execute();
#		while ( my ($fname,$imgcount) = $sth->fetchrow() ) {
#			$fname = (($PWD ne '') && ($PWD ne '/'))?"$PWD/$fname":$fname;
#			$folders{$fname} = $imgcount;
#			}
#		$sth->finish();
#		}

#mysql> desc IMAGES;
#+------------+-------------------------+------+-----+---------+----------------+
#| Field      | Type                    | Null | Key | Default | Extra          |
#+------------+-------------------------+------+-----+---------+----------------+
#| Id         | int(11)                 |      | PRI | NULL    | auto_increment |
#| ImgName    | varchar(45)             |      |     |         |                |
#| Format     | enum('gif','jpg','png') | YES  |     | NULL    |                |
#| TS         | int(10) unsigned        |      |     | 0       |                |
#| MERCHANT   | varchar(20)             |      |     |         |                |
#| MID        | int(11)                 |      | MUL | 0       |                |
#| FID        | int(11)                 |      |     | 0       |                |
#| ItExists   | tinyint(4)              |      |     | 0       |                |
#| ThumbSize  | int(10) unsigned        |      |     | 0       |                |
#| MasterSize | int(10) unsigned        |      |     | 0       |                |
#+------------+-------------------------+------+-----+---------+----------------+
#10 rows in set (0.01 sec)

#	if (1) {
#		my $pstmt = "select ImgName from IMAGES where FID=$parentFID and MID=$MID /* $USERNAME */";
#		my $sth = $dbh->prepare($pstmt);
#		$sth->execute();
#		while ( my ($fname) = $sth->fetchrow() ) {
#			$files{$fname}++; 
#			}
#		$sth->finish();
#		}
#	&DBINFO::db_user_close();

#  # print STDERR "PATH: $path\n";
	my $D;
	opendir($D, $path);
	while ( my $file = readdir($D) ) {
		next if (substr($file,0,1) eq '.');
		if (-d $path.'/'.$file) {
			# print STDERR "FOLDER $file\n";
			$folders{$file} = scalar(keys %{listimgs($path.'/'.$file,1)});
			}
		elsif ($file =~ /\.bin$/) {
			## binfile! {don't count it}
			}
		else {
			$files{&MEDIA::filespec($file)}++;
			}
		}
	closedir($D);


	return(\%folders,\%files);
	}


##
## function:	imgcount
##		returns - the unique number of files in a specific directory
##		parameters: directory
##
sub listimgs {
	my ($dir) = @_;

	my %imgs = ();

	my $D1;
	opendir ($D1, $dir);
	while (my $file = readdir($D1)) {
		next if (substr($file,0,1) eq '.');
		next if ($file =~ /\.bin$/);
		$imgs{&MEDIA::filespec($file)}++;
		}
	closedir($D1);

	return(\%imgs);
	}


1;
