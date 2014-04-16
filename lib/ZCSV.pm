package ZCSV;

use LWP::Simple;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP::UserAgent;
use POSIX;
use Text::CSV_XS;

use lib "/backend/lib";
require INVENTORY2;
require ZOOVY;
require NAVCAT;
require MEDIA;
require File::Basename;
use strict;




##
## 
##
sub assembleCSVFile {
	my ($fieldref,$lineref,$optionsref) = @_;

	my $out = '';
	## output zoovy headers (start with #)
	foreach my $k (keys %{$optionsref}) {
		$out .= "#$k=$optionsref->{$k}\n";
		}

	## now the csv header.
   my ($csv) = Text::CSV_XS->new($optionsref);

#	use Data::Dumper;
#	print STDERR Dumper($fieldref);

	my $status  = $csv->combine(@{$fieldref});  # combine columns into a string
	$out .= $csv->string()."\n";           # get the combined string

	## now the data.		
	foreach my $line (@{$lineref}) {
		$out .= "$line\n";
		}
	return($out);
	}

##
## this is a compatibility layer to quickly import files.
##		BUFFER=>data..
##		SRC=>WEBAPI|SUPPLIER|USER
##		*LU => luser object reference
##		%DIRECTIVES=> hashref of additional csv directives that will be prepended to file.
##		TYPE=> (optional - overrides header)
##		note: TYPE=>'JEDI' gets some special handling becausse it's assumed to be a zip file.
##				so directives, etc. are dropped. (fuck)
##
## in hindsight -- it probably should have been called "addJob" or "queueImport" or some shit like that.		
##
sub addFile {
	my (%options) = @_;

	my $ERROR = undef;		## bail when this is defined!

	require ZTOOLKIT;
	require LUSER::FILES;
	require BATCHJOB;
	require LUSER;

	my $USERNAME = undef;
	my $PRT = undef;

	my $LU = $options{'*LU'};
	if ((defined $LU) && (ref($LU) eq 'LUSER')) {
		$USERNAME = $LU->username();
		$PRT = int($LU->prt());
		}
	else {
		$USERNAME = $options{'USERNAME'};
		$PRT = int($options{'PRT'});
		if (not defined $PRT) {
			$ERROR = "didn't pass *LU and PRT was not defined";
			}
		}

	if (defined $ERROR) {}
	elsif (not defined $USERNAME) { $ERROR = "Username was not defined"; }
	elsif (not defined $PRT) { $ERROR = "Partition PRT was not defined"; }

	my $directives = {};
	if (defined $options{'%DIRECTIVES'}) {
		$directives = $options{'%DIRECTIVES'};
		}

	my $FILETYPE = $options{'TYPE'};
	if (not defined $directives->{'TYPE'}) {
		## make sure we know what we're importing. e.g. PRODUCTS if was set a level higher.
		$directives->{'TYPE'} = $options{'TYPE'};
		}
	if (($FILETYPE eq '') && (defined $directives->{'TYPE'})) {
		$FILETYPE = $directives->{'TYPE'};
		}
	if ($FILETYPE eq '') {
		$ERROR = "Could not determine FILETYPE from either options or %DIRECTIVES";
		}
	if ($options{'SRC'} eq '') { $options{'SRC'} = 'UNKNOWN'; }
	my $FILENAME = sprintf("%s-%s-%s",$FILETYPE,$options{'SRC'},&ZTOOLKIT::pretty_date(time(),1));
	$FILENAME =~ s/[^A-Za-z0-9\:\-]+/_/gs;

#	print STDERR "FILETYPE: $FILETYPE\n";
#	print STDERR Dumper($directives);

	my $tmpfilename = undef;
	my $HEADER = '';
	if (defined $ERROR) {
		## already got an error!
		}
	elsif ($FILETYPE eq 'JEDI') {
		## JEDI: eventually we could pop this open and test for a YAML file.
		$FILETYPE = 'JEDI';
		$tmpfilename = 'JEDI-'.$USERNAME.'-'.&ZTOOLKIT::pretty_date(time(),1);
		$tmpfilename =~ s/[^a-zA-Z0-9\-\:]/_/gs;
		$tmpfilename .= '.zip';

		open F, ">/tmp/$tmpfilename";
		print F $options{'BUFFER'};
		close F;
		}
	else {
		## Supplier Code needs to be added to filename to make it unique
		my ($yyyymmddhhmmss) = POSIX::strftime("%Y%m%d-%H%M%S",localtime());
		if ($options{'SRC'} eq 'SUPPLIER') {
			$tmpfilename = 'CSV-'.$USERNAME.'-'.$FILETYPE.'-SC-'.$directives->{'SUPPLIER'}."-$yyyymmddhhmmss.csv";
			}
		else {
			$tmpfilename = 'CSV-'.$USERNAME.'-'.$FILETYPE."-$yyyymmddhhmmss.csv";
			}
		$FILETYPE = 'CSV';		## if this used to be "PRODUCT" or whatever... now it's just "CSV"
		$tmpfilename =~ s/[^a-zA-Z0-9\-\:]/_/gs;
		open F, ">/tmp/$tmpfilename";
		# print F "# Upload File: $filename\n";
		$HEADER .= "# Directives:\n";
		foreach my $k (keys %{$directives}) {
			$HEADER .= "#$k=$directives->{$k}\n";
			}
		$HEADER .= "# User File:\n";
		print F $HEADER.$options{'BUFFER'};
		close F;
		}

#	die();
	
	print STDERR "ERROR: $ERROR  | FILETYPE:$FILETYPE\n";
	print STDERR "TMPFILE: /tmp/$tmpfilename\n";

	my $GUID = undef;
	if (not defined $ERROR) {
		my ($LUF) = LUSER::FILES->new($USERNAME,LU=>$LU);
		($GUID) = $LUF->add(
			expires_gmt=>time()+(86400*45),
			type=>$FILETYPE,
			title=>$tmpfilename,
			buf=>$HEADER.$options{'BUFFER'},
			unlink=>1,
			unique=>1
			);
		if (not defined $GUID) {	
			$ERROR = "Could not save file $tmpfilename into account.";
			}	
		}

	my $JOBID = 0;
	if (not defined $ERROR) {
		require BATCHJOB;
		$directives->{'file'} = $tmpfilename;
		my ($bj) = BATCHJOB->create($USERNAME,
			GUID=>$GUID,
			'*LU'=>$LU,
			PRT=>$PRT,
			EXEC=>sprintf("IMPORT/%s",$directives->{'LOADTYPE'}),
			'%VARS'=>$directives,
			);
		$bj->start();
		$JOBID = $bj->id();
		if ($JOBID==0) {
			$ERROR = "Internal error - could not start batch job.";	
			}
		}

	if (defined $ERROR) {
		if ((defined $GUID) && ($GUID ne '')) {
			$ERROR = "$ERROR (support file guid: $GUID - please provide to support if you do not know what caused this error.)";
			}
		}
	else {
		$ERROR = $tmpfilename;
		}


	return($JOBID,$ERROR);
	}



##
## round up to the "upto" value
##
sub roundup {
  my ($price,$upto) = @_;

  my $diff = (100 - int($upto)) / 100;
  return(sprintf("%.2f",ceil($price+$diff)-$diff));
  }

##
## round up by a certain number e.g. 5
## so 113.13 becomes 113.15
##
sub roundby {
  my ($price,$by) = @_;

  if ($by == 0) { return($price); }
  $price = $price * 100;
  if (($price % $by) > 0) {
    $price = $price + ($by - ($price % $by));
    }
  return(sprintf("%.2f",$price / 100));
  }




sub apply_filter {
	my ($TYPE,$MATCH,$DATA) = @_;

	my $pass = 0;
	if ($TYPE eq 'RE') {
		## Regular expression
		$MATCH =~ s/^\/(.*?)\/$/$1/igs;
		if ($DATA =~ /$MATCH/) { $pass = 1; }
		}
	elsif ($TYPE eq 'LT') {
		if ($DATA < $MATCH) { $pass = 1; }
		}
	return($pass);
	}

##
## goes through and cleansup badly formatted html
##
sub macro_fixhtml {
	my ($txt) = @_;

   # go through the keys looking for options    
	my $new = '';
	foreach my $ch (split(//,$txt)) {
		if (ord($ch)>127) { $new .= ' '; }
		elsif (ord($ch)==10) { $new .= $ch; }
		elsif (ord($ch)==13) { $new .= $ch; }
		elsif (ord($ch)==9) { $new .= $ch; }
		elsif (ord($ch)<32) { }
		else { $new .= $ch; }
		}
	
	return($new);
	}



sub parse_csv {
   my ($line,$opts) = @_;
	if (ref($line) eq 'ARRAY') { 	
		print STDERR "RECEIVED ALREADY PARSED LINE\n";
		return(@{$line}); 
		}
   # print STDERR "Data: $_[0]\n";

	if (not defined $opts) {}
	elsif (not defined $opts->{'ALLOW_CRLF'}) {
	   $line =~ s/[\n\r]+//g;
		}
   # the old way using quotewords
   # return quotewords(",",0, $_[0]);

	my %attribs = ();
	## supports different separators (\t, |, etc)
	if ($opts->{'DELIMITER'} ne '') {
		if ($opts->{'DELIMITER'} eq 'COMMA') {
			$attribs{'sep_char'} = ',';
			}
		elsif ($opts->{'DELIMITER'} eq 'TAB') {
			$attribs{'sep_char'} = "\t";
			}
		else {
			$attribs{'sep_char'} = $opts->{'DELIMITER'};
			}
		}
	elsif ($opts->{'sep_char'} ne '') {
		## compatibility, not used
		$attribs{'sep_char'} = $opts->{'sep_char'};
		}
	elsif ($opts->{'SEP_CHAR'} eq 'TAB') {
		## compatibility, not used
		$attribs{'sep_char'} = "\t";
		}
	elsif ($opts->{'SEP_CHAR'} ne '') { 
		## compatibility, not used
		$attribs{'sep_char'} = $opts->{'SEP_CHAR'}; 
		}

	$attribs{'binary'} = 1;

	print STDERR "attribs: ".Dumper(%attribs);

   my @columns;
   my $csv = Text::CSV_XS->new(\%attribs);
	my $LAST_ERROR;
   # my $sample_input_string = '01_09021_01,"EBC GreenStuff Brake Pads for 90-93 Miata, Front Set",59,,,,,Brakes';
   my $sample_input_string = $line;
   if ($csv->parse($sample_input_string)) {
      @columns = $csv->fields;
      my $count = 0;
      } else {
      $LAST_ERROR = $csv->error_input;
      }
 	if ($LAST_ERROR ne '') { 
		#print STDERR "LAST ERROR: $LAST_ERROR\n"; 
		} 

   return(@columns);
}


##
##
##
sub readHeaders {
	my ($BUFFER,%params) = @_;

	if (not defined $params{'header'}) { $params{'header'} = 1; }	# by default assume we have a header

	my %OPTIONS = ();
	$OPTIONS{'ALLOW_CRLF'} = $params{'ALLOW_CRLF'};

	## supports different separators (\t, |, etc)
	if ($params{'SEP_CHAR'} eq 'TAB') {
		$OPTIONS{'SEP_CHAR'} = "\t";
		}
	elsif ($params{'SEP_CHAR'} ne '') { 
		$OPTIONS{'SEP_CHAR'} = $params{'SEP_CHAR'}; 
		}
	else {
		$OPTIONS{'SEP_CHAR'} = ',';
		}
	

	use IO::String;
	$/ = "\n";
	my $io = IO::String->new($BUFFER);
	my @LINES = ();

	my $foundfirst = 0;
	#if (not $params{'header'}) { 
	#	## we've already got a header.
	#	$foundfirst++;
	#	}
	## we probably need to read lines until we get a non-header line.
	my $line = undef;
	my $csv = undef;
	my @COLFILTER = ();

	while ((not $foundfirst) && ($line = <$io>)) {
		# print "LINE: $line\n";
		chomp($line);
		if (substr($line,0,2) eq '"#') {
			## fucking application escaped # line.
			$line =~ s/[\r\n]+//s;
			$line = substr($line,1);	# strip leading "
			$line =~ s/\"[\,]+$//g;
			}

		if (substr($line,0,1) eq '#') {
			## haven't found a header yet.
			$line = substr($line,1);
			$line =~ s/[\r]//gs;		## strip carriage returns
			$line =~ s/[\,]+$//gs;	## strip trailing commas
			## NOTE: most variables are simply "ASDF" others are "ASDF=1" 
			if ($line =~ /=/) { 
				my ($k,$v) = split(/=/,$line,2); 
				if ($v eq 'on') { $v = 1; }
				$k = uc($k);
				$OPTIONS{$k}=$v; 
				if ($k eq 'DELIMITER') {
					if ($OPTIONS{'DELIMITER'} eq 'COMMA') {
						$OPTIONS{'SEP_CHAR'} = ',';
						}
					elsif ($OPTIONS{'DELIMITER'} eq 'TAB') {
						$OPTIONS{'SEP_CHAR'} = "\t";
						}
					else {
						$OPTIONS{'SEP_CHAR'} = $OPTIONS{'DELIMITER'};
						}
					## use Data::Dumper; print STDERR "OPTIONS:\n".Dumper(\%params,\%OPTIONS); die();
					}

				} 
			else { 
				$OPTIONS{ uc($line) }++; 
				}
			
			}
		else {
			## found first line in file (must be the header)
			$csv = Text::CSV_XS->new ({ binary => 1, eol => $/, sep_char=>$OPTIONS{'SEP_CHAR'} });
#			print "$OPTIONS{'SEP_CHAR'} LINE: $line\n";
			$csv->parse("$line\n");
			@COLFILTER = $csv->fields();
#			print 'COLFILTER'.Dumper(\@COLFILTER);
			$foundfirst++;
			}
		}


	if (defined $csv) {
		## okay we found the header, now proceed to read the lines.
		while (my $row = $csv->getline($io)) {
			# my $line = join($OPTIONS{'SEP_CHAR'},@{$row});
			#next if ($line eq '');
	
			last if (scalar(@{$row})==0);
			## getline isn't stopping at the end of the file, so continually loops
			## fyi... $csv->eof($io) errors, but would have been helpful
			# last if ($line eq '');
			## data line
			push @LINES, $row;
			}
		}
	close F;

#	open F, ">/tmp/csv.wtf";
#	use Data::Dumper; print F Dumper(\@COLFILTER,\@LINES,\%OPTIONS);
#	close F;
#	exit;
	my $i = scalar(@COLFILTER);
	while (--$i>=0) {
		$COLFILTER[$i] =~ s/^[\s]+//g;	# strip out leading spaces
		$COLFILTER[$i] =~ s/[\s]+$//g;	# strip out tailing spaces
		}

	return(\@COLFILTER,\@LINES,\%OPTIONS);
	exit;

		## EVENTUALLY A MACRO LAYER MIGHT BE FUN.
		#		elsif (substr($destfield,0,9) eq '%MACRO.FIXHTML=') {
		#			&IMPORT::divout("Fixing HTML - $DATA[$pos]");
		#			$prodhash{substr($destfield,9)} = &ZCSV::macro_fixhtml($DATA[$pos]);
		#			} # end of FIXHTML
		#		elsif (substr($destfield,0,9) eq '%SPECL.') {
		#			if ($destfield =~ /^\%SPECL.(.*?)=(.*?)/) {
		#				my $attrib = $2;
		#				my $macro = uc($1);
		#				require TOXML::SPECL;
		#				$prodhash{$attrib} = &TOXML::SPECL::translate2($optionsref->{"SPECL.$macro"},
		#					[ { z=>$DATA[$pos] }, $optionsref ],replace_undef=>1);
		#				}

}

##
## 
##
sub validsku {
	my ($sku) = @_;

	my $c = $sku;
	$sku =~ s/[^\w\-:\#]+//g;

	return($c eq $sku);
	}


##
## quick and dirty check to verify a sku existsin SKU_LOOKUP
##
sub skuexists {
	my ($USERNAME, $SKU) = @_;

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $MID = &ZOOVY::resolve_mid($USERNAME);
	my $qtSKU = $udbh->quote($SKU);
	my $pstmt = "select count(*) from SKU_LOOKUP where MID=$MID and SKU=".$qtSKU;
	print STDERR "$pstmt\n";
	my ($exists) = $udbh->selectrow_array($pstmt);
	&DBINFO::db_user_close();	
	$exists = int($exists);
	return($exists);
	}


## not used???
## wasn't called from anywhere
## subroutinue moved from IMPORT.pm (see below)
## optionsref:
##		suffix=>'jpg'
##		imgname=>'file_to_save_image_to'
##
sub remote_image_copy {
	my ($USERNAME,$URL,$optionsref) = @_;
	if (not defined $optionsref) { $optionsref = {}; }

	return(1,'') unless (defined($URL) && $URL);

	if ($optionsref->{'JEDI'}) {
		## JEDI can copy from static.zoovy.com
		}
	elsif ($URL =~ /zoovy\.com/) {
		if (defined $optionsref->{'*BJ'}) {
			$optionsref->{'*BJ'}->slog("<font color='red'>URL [$URL] appears to point at zoovy.com - NOT ALLOWED!</font>");
			}
		return(2,'');
		}

	if ($URL !~ /^http[s]?\:\/\//) {
		# hmm.. this might be a local file.
		
		#my $filename = &IMGLIB::path_to_image($USERNAME,$URL);
		#if (-f $filename) {
		if (defined $optionsref->{'*BJ'}) {
			$optionsref->{'*BJ'}->slog("Using local file $URL from Image Library");
			}
		return(0,$URL);
		#	} else {
		#	&IMPORT::divout("<font color='red'>ERROR: $URL appears to be a non-existant Image Library reference [$filename] - IGNORING!</font>");
		#	return(1,'');
		#	}
		
		}
	
	if (defined $optionsref->{'*BJ'}) {
		$optionsref->{'*BJ'}->slog("Retrieving Image $URL into Image Library");
		}

	my $CODE = 1;
	my $BUFFER = &ZCSV::snatch_url($URL);
	my $iref = undef;
	if (defined($BUFFER)) {
      # strip everything before the filename
	   $URL =~ s/.*\/(.*?)$/$1/i;
		# strip any extra periods except the last one
		my $ext = '';

		my ($name,$path,$suffix) = File::Basename::fileparse($URL,qr{\.[Jj][Pp][Ee][Gg]|\.[Jj][Pp][Gg]|\.[Pp][Nn][Gg]|\.[Gg][Ii][Ff]});
		if ($optionsref->{'imgname'}) { $name = $optionsref->{'imgname'}; }
		if ($suffix eq '') {
			if ($optionsref->{'suffix'}) { $suffix = ".$optionsref->{'suffix'}"; }
			}
		## note: suffix has a .jpeg or .jpg (notice the leading period)
		$name = lc($name); $path = lc($path);
		$name =~ s/[^a-z0-9\_]+/_/gs;
		$URL = $name.$suffix;

		print STDERR "IMGNAME: $URL\n";
		if ($optionsref->{'SUPPLIER'} ne '') {
			$URL = "SUPPLIER_$optionsref->{'SUPPLIER'}/$URL";
			}
		elsif ($optionsref->{'FOLDER'}) { 
			## probably need to do more data validation here.			
			$URL = "$optionsref->{'FOLDER'}/$URL";
			}

		print "URL:$URL\n";

		($iref) = &MEDIA::store($USERNAME,$URL,$BUFFER);
		if (not defined $iref) { $iref = { err=>999, errmsg=>"Internal Error: MEDIA returned undef iref to ZCSV", }; }
		if ($iref->{'err'}>0) { warn("MEDIA::store returned [$iref->{'err'}] $iref->{'errmsg'}"); }
		$URL = &MEDIA::iref_to_imgname($USERNAME,$iref);
#	   my ($f, $e) = strip_filename($URL);
#	   ($CODE,$URL) = &IMGLIB::create_collection($USERNAME,$f,$e,\$BUFFER);
        }
	else {
		$iref = { err=>998, errmsg=>"Internal Error: no data in buffer.", };
		
		}

	if ($iref->{'err'} == 0) {
		if (defined $optionsref->{'*BJ'}) {
			$optionsref->{'*BJ'}->slog("Load succeed, collection name is $URL");
			}
		} 
	else {
		if (defined $optionsref->{'*BJ'}) {
			$optionsref->{'*BJ'}->slog("<font color='red'>Load Failed (MEDIA error: $iref->{'err'}/$iref->{'errmsg'}), please upload by hand.</font>");
			}
		}

	return($iref->{'err'},$URL);
	}

### copied from IMPORT.pm - patti - 12/29/2006
### used in ZCSV::PRODUCT
#sub remote_image_copy
#{
#   my ($USERNAME,$URL) = @_;
#   require ZURL;
#
#	my ($CODE,$NAME,$EXT) = (10,'No image name specified.',undef);
#
#   if ($URL ne '') {
#		
#		if ($URL =~ /^http:\/\/images\.andale\.com/) {
#			## andale images are special!
#			## thumbnail: http://images.andale.com/f2/123/103/8958056/click2enlarge/1058057517595_7103009b.jpg
#			## actual: http://images.andale.com/f2/123/103/8958056/1058057517595_7103009b.jpg
##			print STDERR "ANDALE before: $URL\n";
#			$URL =~ s/click2enlarge\///sg;
##			print STDERR "ANDALE after: $URL\n";
#			}
#
#      my ($BUFFER,$CTYPE) = &ZURL::safe_snatch_url($URL,"image");
#      if (defined($BUFFER))
#        {
#        # strip everything before the filename
#        # $NAME =~ s/.*\/(.*?)$/$1/i;
#       	my ($f, $e) = strip_filename($URL,$CTYPE);
##         ($CODE,$NAME) = &IMGLIB::create_collection($USERNAME,$f,$e,\$BUFFER);
##			$EXT = $e;
#			&MEDIA::store($USERNAME,"$f.$e",$BUFFER);
##			print "create_collection result CODE=[$CODE] NAME=[$NAME]\n";
#        }
#      }
#
#   return($CODE,$NAME,$EXT);
# }


## Content type is optional.
sub snatch_url {
  my ($URL,$CONTENT_TYPE) = @_;

  # try to correct broken URL's
  if ($URL !~ /^http/i)
		{
		$URL = "http://$URL";
		}
#	print STDERR "SNATCHING: ".$URL."\n";

	my $agent = new LWP::UserAgent;
	$agent->agent('Zoovy_URL_Snatcher/1.0');
	$agent->timeout(30);
	my $hostname = &ZOOVY::servername();
	if (($hostname eq 'dev') || ($hostname eq 'newdev')) { 
		$agent->proxy(['http', 'ftp'], 'http://192.168.1.100:8080/'); 
		}
	my $result = $agent->request(GET $URL);
	my $BUFFER = $result->content();

	
	if (defined($CONTENT_TYPE))
		{
		if ($result->content_type() !~ /$CONTENT_TYPE/i)
			{
#			print STDERR "ZURL [$URL] did not match content type $CONTENT_TYPE type is ".$result->content_type()."\n";
			return undef;
			}
		}

  if (length($BUFFER)>0) { return $BUFFER; } else { return undef; }
}


sub strip_filename
{
   my ($filename) = @_;

	my $ext = "";
	my $name = "";
#	print STDERR "upload.cgi:strip-filename says filename is: $filename\n";
	my $pos = rindex($filename,'.');
#	print STDERR "upload.cgi:strip_filename says pos is: $pos\n";
	if ($pos>0)
		{
		$name = substr($filename,0,$pos);
		$ext = substr($filename,$pos+1);
		
		# lets strip name at the first / or \
		$name =~ s/.*[\/|\\](.*?)$/$1/;
		$name =~ s/\W+/_/g;
		} else {
		# very bad filename!! ?? what should we do!
		}

	# we should probably do a bit more sanity on the filename right here

#	print STDERR "upload.cgi:strip_filename says name=[$name] extension=[$ext]\n";
	return($name,$ext);
}

## moved from IMPORT.pm - patti - 12/29/2006
#sub divout {
#	if ($IMPORT::SILENT) { return(); }
#	# Removed the divs and un-ended center tags.  Neither are needed to make this update realtime.
#	print "<table width='600' cellpadding='3' align='center'><tr><td>\n";
#	foreach (@_) { print $_ . "<br>\n"; }
#	print "</td></tr></table>\n\r";
#	}


1;
