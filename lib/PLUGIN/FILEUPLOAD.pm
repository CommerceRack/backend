package PLUGIN::FILEUPLOAD;

use strict;
use Data::Dumper qw();
use JSON::XS qw();
use CGI::Lite qw();
use CGI::Lite::Request qw();
use Data::GUID qw();
use MIME::Base64 qw();
use lib "/backend/lib";
require ZOOVY;
require DBINFO;

#/*
# * jQuery File Upload Plugin PHP Class 5.18.3
# * https://github.com/blueimp/jQuery-File-Upload
# *
# * Copyright 2010, Sebastian Tschan
# * https://blueimp.net
# *
# * Licensed under the MIT license:
# * http://www.opensource.org/licenses/MIT
# */

sub username { return($_[0]->{'USERNAME'}); }
sub ipaddress { return($_[0]->{'IPADDRESS'}); }

sub new {
	my ($class, $USERNAME, $IPADDRESS) = @_;

	%::ERROR_MESSAGES = (
		1 => 'The uploaded file exceeds the upload_max_filesize directive in php.ini',
		2 => 'The uploaded file exceeds the MAX_FILE_SIZE directive that was specified in the HTML form',
		3 => 'The uploaded file was only partially uploaded',
		4 => 'No file was uploaded',
		6 => 'Missing a temporary folder',
		7 => 'Failed to write file to disk',
		8 => 'A PHP extension stopped the file upload',
		'post_max_size' => 'The uploaded file exceeds the post_max_size directive in php.ini',
		'max_file_size' => 'File is too big',
		'min_file_size' => 'File is too small',
		'accept_file_types' => 'Filetype not allowed',
		'max_number_of_files' => 'Maximum number of files exceeded',
		'max_width' => 'Image exceeds maximum width',
		'min_width' => 'Image requires a minimum width',
		'max_height' => 'Image exceeds maximum height',
		'min_height' => 'Image requires a minimum height'
	);

	if (not defined $IPADDRESS) { $IPADDRESS = $ENV{'REMOTE_ADDR'}; }
	if (not defined $IPADDRESS) { $IPADDRESS = '0.0.0.0'; }

	my $self = {};
	$self->{'USERNAME'} = $USERNAME;
	$self->{'IPADDRESS'} = $IPADDRESS;
	bless $self, 'PLUGIN::FILEUPLOAD';

	$self->{'@FILES'} = [];

	$self->{'%OPTIONS'} = {
		'script_url' => $self->get_full_url().'/',
		'upload_dir' => '/tmp/', # dirname($ENV{'SCRIPT_FILENAME'}).'/files/',
		# 'upload_url' => $self->get_full_url().'/files/',
		# 'user_dirs' => 0,
		'mkdir_mode' => 0755,
		'param_name' => 'files',
		## Set the following option to 'POST', if your server does not support
		## DELETE requests. This is a parameter sent to the client:
		'delete_type' => 'DELETE',
		'access_control_allow_origin' => '*',
		'access_control_allow_credentials' => 0,
		'access_control_allow_methods' => [ 'OPTIONS', 'HEAD', 'POST', 'GET', 'PUT' ],
		'access_control_allow_headers' => [ 'Content-Type', 'Content-Range', 'Content-Disposition', 'Content-Description' ],
		## Enable to provide file downloads via GET requests to the PHP script:
		'download_via_get' => 1,
		## Defines which files can be displayed inline when downloaded:
		'inline_file_types' => '/\.(gif|jpe?g|png)$/i',
		## Defines which files (based on their names) are accepted for upload:
		'accept_file_types' => '/.+$/i',
		## The php.ini settings upload_max_filesize and post_max_size
		## take precedence over the following max_file_size setting:
		'max_file_size' => undef,
		'min_file_size' => 1,
		## The maximum number of files for the upload directory:
		'max_number_of_files' => undef,
		## Image resolution restrictions:
		'max_width' => undef,
		'max_height' => undef,
		'min_width' => 1,
		'min_height' => 1,
		## Set the following option to false to enable resumable uploads:
		'discard_aborted_uploads' => 1,
		## Set to 1 to rotate images based on EXIF meta data, if available:
		#'orient_image' => 0,
		#'image_versions' => {
		# ## Uncomment the following version to restrict the size of
		# ## uploaded images:
		#	'' => { 'max_width' => 1920, 'max_height' => 1200,  'jpeg_quality' => 95 },
		#	'medium' => { 'max_width' => 800, 'max_height' => 600, 'jpeg_quality' => 80 },
		#	'thumbnail' => { 'max_width' => 80, 'max_height' => 80 }
		#	}
		};

	return($self);
	}

sub cgi { return($_[0]->{'*cgi'}->get_multiple_values($_[1])); }
sub options { my ($self) = @_; return($self->{'%OPTIONS'}->{$_[0]}); }
sub HASFILE {
	my ($self,$fileid) = @_;
	my $result = undef;
	foreach my $ref (@{$self->{'@FILES'}}) {
		if ($ref->[0] eq $fileid) { $result = $ref; }
		if ($ref->[1] eq $fileid) { $result = $ref; }
		}
	return($result);
	}
sub FILES { my ($self) = @_;return($self->{'@FILES'}); }

## some php emulation stuff
sub is_array { return(ref($_[0]) eq 'ARRAY'); }
sub header { 
	# print STDERR "$_[0]\n";
	print "$_[0]\n"; 
	}
sub empty { return( ((not defined $_[0])||($_[0] eq ''))?1:0 ); }
sub isset { return( ((defined $_[0])&&($_[0] ne ''))?1:0 ); }


sub get_full_url {
	my ($self) = @_;
	my $https = !empty($ENV{'HTTPS'}) && $ENV{'HTTPS'} ne 'off';
	return
		($https ? 'https://' : 'http://').
		(!empty($ENV{'REMOTE_USER'}) ? $ENV{'REMOTE_USER'}.'@' : '').
		(isset($ENV{'HTTP_HOST'}) ? $ENV{'HTTP_HOST'} : ($ENV{'SERVER_NAME'}.
		($https && $ENV{'SERVER_PORT'} eq 443 ||
		$ENV{'SERVER_PORT'} eq 80 ? '' : ':'.$ENV{'SERVER_PORT'}))).
		substr($ENV{'SCRIPT_NAME'},0, index($ENV{'SCRIPT_NAME'}, '/'));
	}

##
##
##
sub store_file {
	my ($self,$fileguid,$contents) = @_;

	$contents = MIME::Base64::encode($contents);

	my $USERNAME = $self->username();
	my ($redis) = &ZOOVY::getRedis($USERNAME,3);
	my $KEY = uc(sprintf("TMPFILE.%s.%s",$USERNAME,$fileguid));
	$redis->setex($KEY,600,$contents);

	print STDERR "STORE: $KEY $contents\n";

	return();
	}

##
##
##
sub fetch_file {
	my ($self,$fileguid) = @_;

	my ($redis) = &ZOOVY::getRedis($self->username(),3);
	my $KEY = uc(sprintf("TMPFILE.%s.%s",$self->username(),$fileguid));
	my ($contents) = $redis->get($KEY);

	if ($contents ne '') {
		$contents = MIME::Base64::decode($contents);
		}

	return($contents);
	}


sub initialize {
	my ($self,$cgi) = @_;

	my $print_response = 0;

	if (not defined $cgi) {
		$cgi = CGI::Lite::Request->new;
		$cgi->set_platform("UNIX");
		$cgi->set_file_type("handle");
		$cgi->add_timestamp(0);
		}

	my $tmpdir = sprintf("/tmp/upload-%s-%d-%d",$self->username(),$$,time());
	mkdir($tmpdir);
	chmod 0777, $tmpdir;
	$cgi->set_directory ($tmpdir);
	$cgi->add_timestamp(0);
	$cgi->parse_form_data();
	$self->{'*cgi'} = $cgi;

	my $form = $cgi->parse_form_data;
	my ($unzip) = $form->{'unzip'};
	if (not defined $unzip) { $unzip = 1; }

	my @FILES = ();
	if (defined $cgi->uploads()) {
		foreach my $fh ($cgi->uploads()) {
			my ($finfo) = values %{$fh};	## this is specific to CGI::Lite	
			
			print STDERR "FINFO: ".$finfo->type."\n";
			if (! -f sprintf("/tmp/%s",$finfo->filename())) {
				print STDERR "FILE ".$finfo->filename()." DOES NOT EXIST\n";
				}
			elsif ($finfo->size() == 0) {
				print STDERR "FILE IS ZERO BYTES\n";
				}
			elsif (($finfo->type eq 'application/zip') && ($unzip)) {
				require Archive::Zip;
				my $zip = Archive::Zip->new();
				# $zip->read($fh);
				$zip->readFromFileHandle($finfo->fh);
				my @names = $zip->memberNames();
				foreach my $m (@names) {
					# next unless (($m =~ /.txt$/i) || ($m =~ /.csv/i));
					my $BUFFER = $zip->contents($m);
					my $fileguid = Data::GUID->new()->as_string();
					push @FILES, {
						'name'=>$m,
						'filename'=>$m,
						'size'=>length($BUFFER),
						'fileguid'=>$fileguid,
						};
					$self->store_file($fileguid,$BUFFER);
					}
				}
			else {
				## $finfo is a CGI::Lite::Request::Upload->new;
				my $fileguid = Data::GUID->new()->as_string();
				my $filename = $finfo->filename();
				$filename = lc($filename);
				$filename =~ s/[\s]+/_/gs;
				push @FILES, { 
					# '*fh'=>$fh, 
					'name'=>sprintf($finfo->filename),
					'filename'=>sprintf($finfo->filename), 
					'size'=>$finfo->size, 
					# 'tempname'=>$finfo->tempname, 
					'enctype'=>$finfo->type,
					'fileguid'=>$fileguid
					};
				$self->store_file($fileguid,$finfo->slurp());
				unlink("$tmpdir/".$finfo->filename());
				}
			}
		}
	$self->{'@FILES'} = \@FILES;

	open F, ">/tmp/files";	
	use Data::Dumper; print F Dumper(\@FILES);
	close F;

	rmdir($tmpdir);

	#my @FILES = $cgi->get_multiple_values( $self->options('param_name') );
	#foreach my $fh (@FILES) {
	#	#$/ = undef; my $BUFFER = <$fh>; $/ = "\n"; # while (<$fh>) { $BUFFER .= $_; }
	#	#($fhout, $filename) = File::Temp::tempfile();
	#	push @{$self->{'@FILES'}}, { 
	#		#'param_name'=>$self->options('param_name'), 
	#		#'file_name'=>sprintf("%s",$fh),
	#		#'*fh'=>$fh,
	#		};
	#	}	

	if (($ENV{'REQUEST_METHOD'} eq 'OPTIONS') || ($ENV{'REQUEST_METHOD'} eq 'HEAD')) {
		$self->head();
		}
	elsif ($ENV{'REQUEST_METHOD'} eq 'GET') {
		#if (not defined $print_response) { $print_response = 1; }
		#if ($print_response && isset($cgi->get_multiple_values('download'))) {
		#	return $self->download();
		#	}
		#my $file_name = $self->cgi('file');
		#my @info = ();
		#if ($file_name) {
		#	@info = $self->get_file_object($file_name);
		#	}
		#else {
		#	@info = $self->get_file_objects();
		#	}
		# $self->generate_response(\@info, $print_response);
		$self->head();
		# print "Content-type: text/plain\n\nHello";
		}
	elsif ($ENV{'REQUEST_METHOD'} eq 'POST') {
		if (scalar(@{$self->FILES()})>0) {
			my $ug = new Data::UUID;		
			foreach my $finfo (@{$self->FILES()}) {
		
		#		$finfo = $self->handle_file_upload(
		#		$upload->{'*fh'},
		#		$file_name ? $file_name : $upload->{'file_name'},
		#		$size ? $size : $upload->{'size'},
		#		$file_type ? $file_type : $upload->{'type'},
		#		$upload->{'error'},
		#		#$index,
		#		#$content_range
		#		);
		#		if (not defined $index) { $index = undef; }
		#		if (not defined $content_range) { $content_range = undef; }
				}
			}
		$self->generate_response($self->FILES(), $print_response);
		}
	#elsif ($ENV{'REQUEST_METHOD'} eq 'DELETE') {
	#	$self->delete();
	#	}
	else {
		header('HTTP/1.1 405 Method Not Allowed');
		}

	return($self);
	}


sub send_content_type_header {
	my ($self) = @_;
	header('Vary: Accept');
	if (&isset($ENV{'HTTP_ACCEPT'}) && (index($ENV{'HTTP_ACCEPT'}, 'application/json') >= 0)) {
		header('Content-type: application/json');
		} else {
		header('Content-type: text/plain');
		}
	# print STDERR "\n";
	print "\n";
	}

sub send_access_control_headers {
	my ($self) = @_;
	if ($ENV{'HTTP_ORIGIN'} eq 'null') {
		header('Access-Control-Allow-Origin: *');
		}
	else {
		header('Access-Control-Allow-Origin: '.$self->options('access_control_allow_origin'));
		}
	header('Access-Control-Allow-Credentials: false');
	header('Access-Control-Allow-Methods: OPTIONS, POST, GET, PUT');
	header('Access-Control-Allow-Headers: Content-Type, Content-Range, Content-Disposition, Content-Description');
	}

sub head {
	my ($self) = @_;
	header('Pragma: no-cache');
	header('Cache-Control: no-store, no-cache, must-revalidate');
	header('Content-Disposition: inline; filename="files.json"');
	## Prevent Internet Explorer from MIME-sniffing the content-type:
	header('X-Content-Type-Options: nosniff');
   $self->send_access_control_headers();
	$self->send_content_type_header();
	}




sub delete {
	my ($self, $print_response) = @_;
#	if (not defined $print_response) { $print_response = 1; }
#	my $file_name = $self->get_file_name_param();
#	my $file_path = $self->get_upload_path($file_name);
#	my $success = is_file($file_path) && $file_name[0] ne '.' && unlink($file_path);
#	if ($success) {
#		#foreach($self->options('image_versions') as $version => $options) {
#		#	if (!empty($version)) {
#		#		$file = $self->get_upload_path($file_name, $version);
#		#		if (is_file($file)) {
#		#			unlink($file);
#		#			}
#		#		}
#		#	}
#		}
#	return $self->generate_response($success, $print_response);
	}


sub download {
	my ($self) = @_;
	if (!$self->options('download_via_get')) {
		return;
		}
	my $file_name = $self->cgi('file');
	if ($self->is_valid_file_object($file_name)) {
		my $file_path = $self->get_upload_path($file_name, $self->get_version_param());
		if (is_file($file_path)) {
			if (!preg_match($self->options('inline_file_types'), $file_name)) {
				header('Content-Description: File Transfer');
				header('Content-Type: application/octet-stream');
					header('Content-Disposition: attachment; filename="'.$file_name.'"');
					header('Content-Transfer-Encoding: binary');
				} else {
					## Prevent Internet Explorer from MIME-sniffing the content-type:
					header('X-Content-Type-Options: nosniff');
					header('Content-Type: '.$self->get_file_type($file_path));
					header('Content-Disposition: inline; filename="'.$file_name.'"');
				}
				header('Content-Length: '.$self->get_file_size($file_path));
				header('Last-Modified: '.gmdate('D, d M Y H:i:s T', filemtime($file_path)));
				readfile($file_path);
			}
		}
	}

	#sub get_user_id {
	#	@session_start();
	#	return session_id();
	#}

sub get_user_path {
	my ($self) = @_;
	if ($self->options('user_dirs')) {
		return $self->get_user_id().'/';
		}
	return '';
	}

sub get_upload_path {
	my ($self, $file_name, $version) = @_;

	if (not defined $file_name) { $file_name = undef; }
	if (not defined $version) { $version = undef; }
	$file_name = $file_name ? $file_name : '';
	my $version_path = empty($version) ? '' : $version.'/';
	return $self->options('upload_dir').$self->get_user_path()
		.$version_path.$file_name;
	}

sub get_download_url {
	my ($self, $file_name, $version) = @_;
	if (not defined $version) { $version = undef; }
		if ($self->options('download_via_get')) {
			my $url = $self->options('script_url').'?file='.rawurlencode($file_name);
			if ($version) {
				$url .= '&version='.rawurlencode($version);
			}
			return $url.'&download=1';
		}
		my $version_path = empty($version) ? '' : rawurlencode($version).'/';
		return $self->options('upload_url').$self->get_user_path().$version_path.rawurlencode($file_name);
	}

sub set_file_delete_properties {
	my ($self,$file) = @_;

		$file->delete_url = $self->options('script_url')
			.'?file='.rawurlencode($file->name);
		$file->delete_type = $self->options('delete_type');
		if ($file->delete_type ne 'DELETE') {
			$file->delete_url .= '&_method=DELETE';
		}
		if ($self->options('access_control_allow_credentials')) {
			$file->delete_with_credentials = 1;
		}
	}

sub get_file_size {
	my ($self, $file_path, $clear_stat_cache) = @_;
	#if ($clear_stat_cache) {
	#	clearstatcache();
	#	}
	return $self->filesize($file_path);
	}





sub get_file_object {
	my ($self,$file_name) = @_;
		
	# print STDERR "get_file_object $file_name\n";

	#if ($self->is_valid_file_object($file_name)) {
	#	$file = new stdClass();
	#	$file->name = $file_name;
	#	$file->size = $self->get_file_size(
	#		$self->get_upload_path($file_name)
	#	);
	#	$file->url = $self->get_download_url($file->name);
	#	foreach($self->options('image_versions') as $version => $options) {
	#		if (!empty($version)) {
	#			if ( -f $self->get_upload_path($file_name, $version)) {
	#				$file->{$version.'_url'} = $self->get_download_url(
	#					$file->name,
	#					$version
	#				);
	#			}
	#		}
	#	}
	#	$self->set_file_delete_properties($file);
	#	return $file;
	#}
	return undef;
	}

sub get_file_objects {
	my ($self) = @_;

	#print STDERR 'get_file_objects'. Dumper(@_);		
		#($iteration_method = 'get_file_object') {
		#$upload_dir = $self->get_upload_path();
		#if (!is_dir($upload_dir)) {
		#	mkdir($upload_dir, $self->options('mkdir_mode'));
		#}
		#return array_values(array_filter(array_map(
		#	array($self, $iteration_method),
		#	scandir($upload_dir)
		#)));
	}


sub count_file_objects {
	my ($self) = @_;
	return count($self->get_file_objects('is_valid_file_object'));
	}

sub is_valid_file_object {
	my ($self, $file_name) = @_;
	my $file_path = $self->get_upload_path($file_name);
	die();
	#if ((-f $file_path) && $file_name[0] ne '.') {
	#	return 1;
	#	}
	return 0;
	}


sub trim_file_name {
	my ($self, $name, $type, $index, $content_range) = @_;
	## Remove path information and dots around the filename, to prevent uploading
	## into different directories or replacing hidden system files.
	## Also remove control characters and spaces (\x00..\x20) around the filename:
	my $file_name = trim(basename(stripslashes($name)), ".\x00..\x20");
	## Add missing file extension for known image types:
	if ( (index($file_name, '.')>0) && ($type =~ /^image\/(gif|jpe?g|png)$/) ) {
		$file_name .= '.'.$1;
		}
		while(is_dir($self->get_upload_path($file_name))) {
			$file_name = $self->upcount_name($file_name);
		}
		my $uploaded_bytes = intval($content_range->[1]);
		while(-f $self->get_upload_path($file_name)) {
			if ($uploaded_bytes eq $self->get_file_size(
					$self->get_upload_path($file_name))) {
			last;
			}
			$file_name = $self->upcount_name($file_name);
		}
		return $file_name;
	}


sub generate_response {
	my ($self, $finfo, $print_response) = @_;
	if (not defined $print_response) { $print_response = 1; }

	# print STDERR Carp::cluck();
	# print STDERR "generate_response: ".Dumper($finfo);

	if ($print_response) {
		}
	elsif (not $finfo) {
		## never output undefined
		$self->head();
		}
	elsif (ref($finfo) ne '') {
		my ($json) = JSON::XS->new->utf8->allow_blessed(1)->convert_blessed(1)->encode($finfo);
		# $json = json_encode($finfo);
		#	$redirect = isset($_REQUEST['redirect']) ?
		#		stripslashes($_REQUEST['redirect']) : undef;
		#	if ($redirect) {
		#		header('Location: '.sprintf($redirect, rawurlencode($json)));
		#		return;
		#	}
		$self->head();
		#if (isset($ENV{'HTTP_CONTENT_RANGE'}) && is_array($finfo) &&
		#		is_object($finfo[0]) && $finfo[0]->size) {
		#		header('Range: 0-'.(int($finfo[0]->size) - 1));
		#	}
		# print STDERR "$json\n";
		print $json;
		}
	return $finfo;
	}


sub strip_filename {
   my ($filename) = @_;

	my $ext = "";
	my $name = "";
	print STDERR "upload.cgi:strip-filename says filename is: $filename\n";
	my $pos = rindex($filename,'.');
	print STDERR "upload.cgi:strip_filename says pos is: $pos\n";
	if ($pos>0)
		{
		$name = substr($filename,0,$pos);
		$ext = substr($filename,$pos+1);
		
		# lets strip name at the first / or \ e.g. C:\program files\zoovy\foo.gif becomes "foo.gif"
		$name =~ s/.*[\/|\\](.*?)$/$1/;
		# allow periods, alphanum, and dashes to pass through, kill any other special characters
		$name =~ s/[^\w\-\.]+/_/g;
		# now, remove duplicate periods
		$name =~ s/[\.]+/\./g;
		
		} else {
		# very bad filename!! ?? what should we do!
		}

	# we should probably do a bit more sanity on the filename right here

	print STDERR "upload.cgi:strip_filename says name=[$name] extension=[$ext]\n";
	return($name,$ext);
	}


1;

__DATA__

	if ($error) {
		return(0,$error);
		}
		$content_length = intval($ENV{'CONTENT_LENGTH'});
		if ($content_length > $self->get_config_bytes(ini_get('post_max_size'))) {
			$file->error = $self->get_error_message('post_max_size');
			return 0;
		}
		if (!preg_match($self->options('accept_file_types'), $file->name)) {
			$file->error = $self->get_error_message('accept_file_types');
			return 0;
		}
		if ($uploaded_file && is_uploaded_file($uploaded_file)) {
			$file_size = $self->get_file_size($uploaded_file);
		} else {
			$file_size = $content_length;
		}
		if ($self->options('max_file_size') && (
				$file_size > $self->options('max_file_size') ||
				$file->size > $self->options('max_file_size'))
			) {
			$file->error = $self->get_error_message('max_file_size');
			return 0;
		}
		if ($self->options('min_file_size') &&
			$file_size < $self->options('min_file_size')) {
			$file->error = $self->get_error_message('min_file_size');
			return 0;
		}
		if (is_int($self->options('max_number_of_files')) && (
				$self->count_file_objects() >= $self->options('max_number_of_files'))
			) {
			$file->error = $self->get_error_message('max_number_of_files');
			return 0;
		}
		list($img_width, $img_height) = @getimagesize($uploaded_file);
		if (is_int($img_width)) {
			if ($self->options('max_width') && $img_width > $self->options('max_width')) {
				$file->error = $self->get_error_message('max_width');
				return 0;
			}
			if ($self->options('max_height') && $img_height > $self->options('max_height')) {
				$file->error = $self->get_error_message('max_height');
				return 0;
			}
			if ($self->options('min_width') && $img_width < $self->options('min_width')) {
				$file->error = $self->get_error_message('min_width');
				return 0;
			}
			if ($self->options('min_height') && $img_height < $self->options('min_height')) {
				$file->error = $self->get_error_message('min_height');
				return 0;
			}
		}
		return 1;
	}

	if ($self->validate($uploaded_file, $file, $error, $index)) {
		}
	}




			$self->handle_form_data($file, $index);
			$upload_dir = $self->get_upload_path();
			if (!is_dir($upload_dir)) {
				mkdir($upload_dir, $self->options('mkdir_mode'));
			}
			$file_path = $self->get_upload_path($file->name);
			$append_file = $content_range && -f $file_path &&
				$file->size > $self->get_file_size($file_path);
			if ($uploaded_file && is_uploaded_file($uploaded_file)) {
				## multipart/formdata uploads (POST method uploads)
				if ($append_file) {
					file_put_contents(
						$file_path,
						fopen($uploaded_file, 'r'),
						FILE_APPEND
					);
				} else {
					move_uploaded_file($uploaded_file, $file_path);
				}
			} else {
				## Non-multipart uploads (PUT method support)
				file_put_contents( $file_path, fopen('php:##input', 'r'),$append_file ? FILE_APPEND : 0);
			}
			$file_size = $self->get_file_size($file_path, $append_file);
			if ($file_size eq $file->size) {
				if ($self->options('orient_image')) {
					$self->orient_image($file_path);
				}
				$file->url = $self->get_download_url($file->name);
				#foreach($self->options('image_versions') as $version => $options) {
				#	if ($self->create_scaled_image($file->name, $version, $options)) {
				#		if (!empty($version)) {
				#			$file->{$version.'_url'} = $self->get_download_url(
				#				$file->name,
				#				$version
				#			);
				#		} else {
				#			$file_size = $self->get_file_size($file_path, 1);
				#		}
				#	}
				}
			} elsif ( ! $content_range && $self->options('discard_aborted_uploads') ) {
				unlink($file_path);
				$file->error = 'abort';
			}
			$file->size = $file_size;
			$self->set_file_delete_properties($file);
		}
		return $file;
	}






	function __construct($options = undef, $initialize = 1) {
	}





	sub create_scaled_image($file_name, $version, $options) {
		$file_path = $self->get_upload_path($file_name);
		if (!empty($version)) {
			$version_dir = $self->get_upload_path(undef, $version);
			if (!is_dir($version_dir)) {
				mkdir($version_dir, $self->options('mkdir_mode'));
			}
			$new_file_path = $version_dir.'/'.$file_name;
		} else {
			$new_file_path = $file_path;
		}
		list($img_width, $img_height) = @getimagesize($file_path);
		if (!$img_width || !$img_height) {
			return 0;
		}
		$scale = min(
			$options['max_width'] / $img_width,
			$options['max_height'] / $img_height
		);
		if ($scale >= 1) {
			if ($file_path ne $new_file_path) {
				return copy($file_path, $new_file_path);
			}
			return 1;
		}
		$new_width = $img_width * $scale;
		$new_height = $img_height * $scale;
		$new_img = @imagecreate1color($new_width, $new_height);
		switch (strtolower(substr(strrchr($file_name, '.'), 1))) {
			case 'jpg':
			case 'jpeg':
				$src_img = @imagecreatefromjpeg($file_path);
				$write_image = 'imagejpeg';
				$image_quality = isset($options['jpeg_quality']) ?
					$options['jpeg_quality'] : 75;
				break;
			case 'gif':
				@imagecolortransparent($new_img, @imagecolorallocate($new_img, 0, 0, 0));
				$src_img = @imagecreatefromgif($file_path);
				$write_image = 'imagegif';
				$image_quality = undef;
				break;
			case 'png':
				@imagecolortransparent($new_img, @imagecolorallocate($new_img, 0, 0, 0));
				@imagealphablending($new_img, 0);
				@imagesavealpha($new_img, 1);
				$src_img = @imagecreatefrompng($file_path);
				$write_image = 'imagepng';
				$image_quality = isset($options['png_quality']) ?
					$options['png_quality'] : 9;
				break;
			default:
				$src_img = undef;
		}
		$success = $src_img && @imagecopyresampled(
			$new_img,
			$src_img,
			0, 0, 0, 0,
			$new_width,
			$new_height,
			$img_width,
			$img_height
		) && $write_image($new_img, $new_file_path, $image_quality);
		## Free up memory (imagedestroy does not delete files):
		@imagedestroy($src_img);
		@imagedestroy($new_img);
		return $success;
	}

	sub get_error_message($error) {
		return array_key_exists($error, $self->error_messages) ?
			$self->error_messages[$error] : $error;
	}

	function get_config_bytes($val) {
		$val = trim($val);
		$last = strtolower($val[strlen($val)-1]);
		switch($last) {
			case 'g':
				$val *= 1024;
			case 'm':
				$val *= 1024;
			case 'k':
				$val *= 1024;
		}
		return $val;
	}


	sub upcount_name_callback($matches) {
		$index = isset($matches[1]) ? intval($matches[1]) + 1 : 1;
		$ext = isset($matches[2]) ? $matches[2] : '';
		return ' ('.$index.')'.$ext;
	}

	sub upcount_name($name) {
		return preg_replace_callback(
			'/(?:(?: \(([\d]+)\))?(\.[^.]+))?$/',
			array($self, 'upcount_name_callback'),
			$name,
			1
		);
	}


	sub handle_form_data($file, $index) {
		## Handle form data, e.g. $_REQUEST['description'][$index]
	}

	sub orient_image($file_path) {
		  $exif = @exif_read_data($file_path);
		if ($exif eq 0) {
			return 0;
		}
		  $orientation = intval(@$exif['Orientation']);
		  if (!in_array($orientation, array(3, 6, 8))) {
			  return 0;
		  }
		  $image = @imagecreatefromjpeg($file_path);
		  switch ($orientation) {
			  case 3:
				  $image = @imagerotate($image, 180, 0);
				  break;
			  case 6:
				  $image = @imagerotate($image, 270, 0);
				  break;
			  case 8:
				  $image = @imagerotate($image, 90, 0);
				  break;
			  default:
				  return 0;
		  }
		  $success = imagejpeg($image, $file_path);
		  ## Free up memory (imagedestroy does not delete files):
		  @imagedestroy($image);
		  return $success;
	}


	sub get_version_param() {
		return isset($_GET['version']) ? basename(stripslashes($_GET['version'])) : undef;
	}


	sub get_file_type($file_path) {
		switch (strtolower(pathinfo($file_path, PATHINFO_EXTENSION))) {
			case 'jpeg':
			case 'jpg':
				return 'image/jpeg';
			case 'png':
				return 'image/png';
			case 'gif':
				return 'image/gif';
			default:
				return '';
		}
	}


}
