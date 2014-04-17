package ZTOOLKIT;


use URI::Escape::XS qw();
require Exporter;
use locale;
use POSIX qw(locale_h strftime);
use Storable qw();
use MIME::Base64 qw();

@ISA = qw(Exporter); ## Adding a 'my' to this is incorrect, it actually causes the export of functions to fail.

# No functions are exported by default
@EXPORT = qw(); ## DO NOT ADD 'my'
# Allowable to be exported to foreign namespaces
@EXPORT_OK = qw(
	def good gstr gnum num gint pint trim qqtrim entab
	printarray printhash dumpvar htmlify
	validate_email validate_phone numtype isnum isdecnum isdecnumneg cleannum
	wordlength wordstrip htmlstrip numberlength isin unique minmax_lexical minmax_numeric spin
	spinto spintil unspintil iskey isval value_sort getafter getbefore urlparams moneyformat cashy zeropad
	padzero pretty ugly untab append_number_suffix prepend_text line_numer_text timetohash
	roundtimestamptohour unixtime_to_timestamp pretty_time_since make_password pretty_date base36 base26
	unixtime_to_gmtime gmtime_to_unixtime buildparams
	ip_to_int int_to_ip
	encode decode encode_latin1 decode_latin1
); ## DO NOT ADD 'my'
# These are the logical groupings of exported functions
%EXPORT_TAGS = ();  ## DO NOT ADD 'my'

###########################################################################
## Don't move anything from above this line below it, or vice versa!  
## Exporter variables need to be lexically scoped and strict likes to complain about them.
###########################################################################

use strict; ## See comment on above line
use CGI;

## Used by short_url_escape, placed here so it is only generated once
@ZTOOLKIT::esc = ();
## Create the translation table for all characters
foreach (0..255) { $ZTOOLKIT::esc[$_] = '%'.sprintf('%02X',$_); } 
## Whitelist these characters to map to themselves
foreach ('a'..'z', 'A'..'Z','0'..'9', '.', '/', ':', '?', '@', '$', '-', '_', '!', '~', '*', '(', ')', ',')
{
	$ZTOOLKIT::esc[ord($_)] = $_;
} 
$ZTOOLKIT::esc[32] = '+'; # Space is a special instance which can be shortened to +


# http://kellyjones.netfirms.com/webtools/ascii_utf8_table.shtml
@ZTOOLKIT::UTFX_MAPPINGS = ( 
	[ "\x{e2}\x{80}\x{93}", '-', '&ndash;' ], # En dash
	[ "\x{e2}\x{80}\x{94}", '-', '&mdash;' ], # Em dash
	[ "\x{e2}\x{80}\x{97}", '\'', '&lsquo;' ], # Left single quotation mark
	[ "\x{e2}\x{80}\x{98}", '\'', '&rsquo;' ], # Right single quotation mark
	[ "\x{e2}\x{80}\x{99}", '\'', '&sbquo;' ], # Single low-9 quotation mark
	[ "\x{e2}\x{80}\x{9C}", '"', '&ldquo;' ], # Left double quotation mark
	[ "\x{e2}\x{80}\x{9D}", '"', '&rdquo;' ], # Right double quotation mark
	[ "\x{e2}\x{80}\x{9E}", '"', '&bdquo;' ], # Double low-9 quotation mark
	[ "\x{c2}\x{a9}", "\x{a9}", '&copy;' ], # Copyright
	[ "\x{c2}\x{ae}", "\x{ae}", '&reg;' ], # Registered sign, registered trademark sign
	[ "\x{c2}\x{b0}", "\x{b0}", '&deg;' ], # Degree sign
	[ "\x{e2}\x{84}\x{a2}", "(tm)", '&trade;' ], # Trademark
	[ "\x{e2}\x{82}\x{ac}", "", "&euro;" ], # Euro
	[ "\x{ef}\x{bf}\x{bd}", "", "" ],	# hmm.. not sure what this is.
	# [ "", "" ]
	);


## NOTE: this needs to remain jquery compatible
sub trim { 
	my ($str) = @_;
	$str =~ s/^[\s\n\r\t]+//gs;	# remove leading
	$str =~ s/[\s\n\r\t]+$//gs;	# remove trailing
	return($str);
	}


## controller.js line 3114 (version 201352)
## data-bind
sub parseDataBindIntoRules {
	my ($str) = @_;

	my @TOKENS = split(/;/,$str);
	pop @TOKENS;	## last entry is blank, data-binds MUST end with a ;

	my @RULES = ();
	foreach my $token (@TOKENS) {
		my ($property,$value) = split(/:/,$token,2);

		my $trim = 1;
#		if (substr($property,0,1) eq '+') { $value = 1; $property = substr($property,1); } 		## ex: +trim; 
#		elsif (substr($property,0,1) eq '-') { $value = 0; $property = substr($property,1); } 		## ex: -trim;
		if (substr($property,0,1) eq '_') { $trim = 0; $property = substr($property,0,1); }		## turns off trimming.

		$property = &ZTOOLKIT::trim($property);
		if ($trim) { $value = &ZTOOLKIT::trim($value); }
		
		push @TOKENS, [ $property, $value ];
		}

	return(\@RULES);
	}


##
sub handleTranslation {
	my ($str, %options) = @_;

	## format: 
	## hideIfSet
	## showIfSet
	## showIfMatch
	## imageURL
	##	imageURL2Href
	##	stuffList
	## addClass	
	## truncText
	##	epoch2pretty
	## epoch2mdy
	## text
	## setVal
	## popVal

	## stringify
	##	trigger

	my %RULES = ();
	my $LAST_IF_RESULT = undef;
	foreach my $instruction (@{&ZTOOLKIT::parseDataBindIntoRules($str)}) {		
		my ($property,$value) = @{$instruction};

		if (substr($property,0,1) eq '$') {
			## ex  $trim: var;  would set trim to value of var.
			$value = $RULES{ substr($property,1) }; 
			$property = substr($property,1); 
			}	

		$RULES{$property} = $value;

		if ($property eq /^(if|then|else)\-(.*?)$/) {
			my ($cmd,$property) = ($1,$2);
			if ($cmd eq 'if') {
				## we do all the wild comparisons

#				my $is_true = undef;
#				if 	($if eq 'BLANK') 		{  $is_true = ($VALUE eq '')?1:0; }
#				elsif ($if eq 'NOTBLANK')	{  $is_true = ($VALUE ne '')?1:0; }
#				elsif ($if eq 'NULL') 		{  $is_true = (defined $VALUE)?1:0; }
#				elsif ($if eq 'NOTNULL')	{  $is_true = (not defined $VALUE)?1:0; }
#				elsif ($if eq 'TRUE')	{  $is_true = (&ZOOVY::is_true($VALUE))?1:0; }
#				elsif ($if eq 'FALSE')	{  $is_true = (not &ZOOVY::is_true($VALUE))?1:0; }
#				elsif ($if =~ /^(GT|LT|EQ)\/([\d\.]+)\/$/) 	{  
#					my ($OP,$OPVAL) = ($1,$2);  
#					$OPVAL = int($OPVAL*1000); 
#					$VALUE=int($VALUE*1000);
#					$is_true = undef;
#					if ($OP eq 'GT') { $is_true = ($VALUE > $OPVAL)?1:0; }
#					elsif ($OP eq 'LT') { $is_true = ($VALUE < $OPVAL)?1:0; }
#					elsif ($OP eq 'EQ') { $is_true = ($VALUE == $OPVAL)?1:0; }
#					elsif ($OP eq 'NE') { $is_true = ($VALUE == $OPVAL)?1:0; }
#					}
#				elsif ($if =~ /^REGEX\/(.*?)\/$/) 	{  $is_true = ($VALUE =~ /$1/)?1:0; }
#				elsif ($if =~ /^NOTREGEX\/(.*?)\/$/)	{  $is_true = ($VALUE !~ /$1/)?1:0; }
				
				}
			elsif (not defined $LAST_IF_RESULT) {
				## we can't run a then or else because 'if' hasn't been run
				$property = 'noop';
				}
			elsif ($cmd eq 'then') {
				if (not $LAST_IF_RESULT) { $property = 'noop'; }
				}
			elsif ($cmd eq 'else') {
				if ($LAST_IF_RESULT) { $property = 'noop'; }
				}
			}
		
		if ($property eq 'noop') {
			## no-operation
			}
		elsif (($property eq 'function') || ($property eq 'loadsTemplate')) {
			## these are not supported
			}
		elsif ($property eq 'var') {			
			## var: object(attrib)
			$RULES{'_'} = 0; 	## insert lookup magic here.
			}
		elsif ($property eq 'zero') {
			if (not $RULES{'_'}) { $RULES{'_'} = ''; }
			}


		if ($RULES{'dwiw'}) {
			if (($property eq 'pretext') || ($property eq 'posttext')) { 
				$RULES{$property} = &ZTOOLKIT::trim($RULES{$property});
				}
			}
		elsif ($RULES{'trim'}) {
			$RULES{$property} = &ZTOOLKIT::trim($RULES{$property});
			}

		if (($RULES{'dwiw'}) || ($RULES{'hideZero'})) {
			if ($RULES{$property} == 0) { $RULES{$property} = undef; }
			}

		}
	}


## controller.js line 3114 (version 201352)
sub parseDataBind {
	my ($str) = @_;

	my %RULES = ();
	foreach my $instruction (@{&ZTOOLKIT::parseDataBindIntoRules($str)}) {
		my ($property,$value) = @{$instruction};
		next if (defined $RULES{ $property });		## only the first property wins, we will discard the rest.

		$RULES{$property} = $value;
		}
	
	return(\%RULES);
	}



##
## removes all xss attack vectors
##
sub xssdeclaw {
	my ($txt) = @_;
	$txt =~ s/[\"\>\<]+//gso;
	return($txt);
	}


##
## This interoplates (eg: replaces) variables with the correct values
##
sub interpolate
{
	my ($HASHREF, $MESSAGE) = @_;

	foreach my $k (keys %{$HASHREF})
		{
		$MESSAGE =~ s/$k/$HASHREF->{$k}/igs;
		}
	
#	print "interpolate: $MESSAGE\n";
		return($MESSAGE);
}


##
##
##
sub textlist_to_arrayref {
	my ($data) = @_;

	my @ROWS = ();
	foreach my $line (split(/[\n\r]+/,$data)) {
		$line =~ s/^[\s]+//gs; # strip leading whitespace
		$line =~ s/[\s]+$//gs; # strip trailing whitespace
		next if ($line eq '');	# skip blank lines
		push @ROWS, $line;
		}
	return(\@ROWS);
	}



##
## $val = incoming value
## $value = of last resort
##	if key is found in %params then 
sub translatekeyto {
	my ($key,$volr,$possiblematchesref) = @_;
	my $result = $volr;
	if ($possiblematchesref->{$key}) { $result = $possiblematchesref->{$key}; }
	return($volr);
	}

sub iprice { my ($i) = @_; return(sprintf("%.2f",$i/100)); }

##
## see http://api.jquery.com/category/selectors/ for more information on escaping selectors
##
sub jquery_escape {
	my ($str) = @_;
	$str =~ s/([\!\"\#\$\%\&\'\(\)\*\+\,\.\/\:\;\<\=\>\?\@\[\\\]\^\{\|\}\~])/\\\\$1/gs;
	return($str);
	}


## converts a float to an int safely
## ex: perl -e 'print int(64.35*100);' == 6434  (notice the penny dropped)
## ex: perl -e 'print int(sprintf("%f",64.35*100));' == 6435
## ex: perl -e '$x = int(34.41*100); $y = int(34.43*100); $diff = ($y-$x); print "Diff: $diff\n";' # hint: it's 3!!
sub f2int { return(int(sprintf("%0f",$_[0]))); }


##
## store a sha1 password, plus a constant that makes sure the password won't appear in a rainbow file
##
sub sha1_password {
	my ($KEY,$pass) = @_;

	require Digest::SHA1;
	my $digest = Digest::SHA1::sha1_hex(sprintf("%s+%s",$KEY,$pass));
	return($digest);
	}


##
## A function to tell a user when they have made a good password.
##	returns undef, or a text reason WHY it's a bad password
##
sub is_bad_password {
	my ($password,%options) = @_;

	if (not defined $options{'length'}) { $options{'length'} = 6; }
	if (not defined $options{'mixed'}) { $options{'mixed'} = 1; }
	if (not defined $options{'special'}) { $options{'special'} = 1; }

	my $REASON = undef;
	if (($options{'mixed'}) && ($password eq uc($password))) {
		$REASON = "All uppercase";
		}
	elsif (($options{'mixed'}) && ($password eq lc($password))) {
		$REASON = "All lowercase";
		}
	elsif (length($password)<$options{'length'}) {
		$REASON = "Too short";
		}
	elsif (($options{'special'}) && ($password !~ /[^a-zA-Z]/)) {
		$REASON = "Needs non-alpha characters";
		}
	
	if (defined $REASON) {
		$REASON = "$REASON - passwords must be ".int($options{'length'})." characters, and should be mixed upper/lower case and contain at least 1 number or other special character";
		}

	return($REASON);
	}



##
##
##
sub batchify {
   my ($ARREF,$SEGSIZE) = @_;

   my @batches = ();
   my $arref = ();
   my $count = 0;
   foreach my $i (@{$ARREF}) {
      push @{$arref}, $i;
      $count++;
      if ($count>=$SEGSIZE) {
         $count=0;
         push @batches, $arref;
         $arref = ();
         }
      }
   if ($count>0) {
      push @batches, $arref;
      }
   return(\@batches);
   }

###############################################
##
## takes 4111111111111111
## returns: 4111xxxxxxxx1111
##
sub cardmask {
	my ($plaincard) = @_;
	$plaincard =~ s/[^0-9]+//gs;
	my $cardmask = substr($plaincard,0,5);		## 5 digits tells us which bank
	my $x = length($plaincard)-9;	# how many xx do we need?
	while ($x-->0) { $cardmask .= 'x'; }
	$cardmask .= substr($plaincard,-4);
	return($cardmask);
	}

################################################
##
## converts a name to an alphanumeric.
##		so you can do lt and gt operations on equivalent strings.
##		returns a float.
##
sub alphatonumeric {
	my ($str) = @_;

	$str = uc($str);
	my $i = ord(substr($str,0,1))-32;
	$str = substr($str,1);
	$i = "$i.";
	foreach my $ch (split(//,$str)) {
		$i .= sprintf("%02d",ord($ch)-32);
		}
	return($i);
	}



############################################
##
## string convert entity to utf8
sub sc_entity_to_utf8 {
	foreach my $set (@ZTOOLKIT::UTFX_MAPPINGS) {
		next if ($set->[2] eq '');
		$_[0] =~ s/$set->[2]/$set->[0]/gs;
		}
	return($_[0]);
	}

#############################################
##
##	string convert utf8 to entity
sub sc_utf8_to_entity {
	foreach my $set (@ZTOOLKIT::UTFX_MAPPINGS) {
		next if ($set->[0] eq '');
		$_[0] =~ s/$set->[0]/$set->[2]/gs;
		# print STDERR "\$_[0]: $_[0]\n";
		}
	return($_[0]);
	}


#############################################
##
##	string coverts utf8 to ascii equivalent
##
sub sc_utf8_to_ascii {
	foreach my $set (@ZTOOLKIT::UTFX_MAPPINGS) {
		next if ($set->[0] eq '');
		$_[0] =~ s/$set->[0]/$set->[1]/gs;
		}
	return($_[0]);
	}

#############################################
##
## converts all fields in a hashref from utf8 to entity
sub hashref_utf8_to_entity {
	my ($hashref) = @_;
	foreach my $k (keys %{$hashref}) { 
		foreach my $set (@ZTOOLKIT::UTFX_MAPPINGS) {
			next if ($set->[0] eq '');
			$hashref->{$k} =~ s/$set->[0]/$set->[2]/gs; 
			if ($set->[1] eq '') {
				}
			elsif (length($set->[1])>0) {
				}
			elsif (ord($set->[1])>127) { 
				$hashref->{$k} =~ s/$set->[1]/$set->[2]/gs; 
				}
			}
		}
	return($hashref);
	}


############################################
##
## strip unicode
##
############################################
sub stripUnicode {
	my ($str) = @_;
	my $new = '';

	foreach my $set (@ZTOOLKIT::UTFX_MAPPINGS) {
		# next if (index($str,$set->[0])==-1);		# this line doesn't work because binary comparisons don't work on index
		# print "IN: $set->[0]".index($str,$set->[0])."\n";
		$str =~ s/$set->[0]/$set->[1]/gs;
		}	

	foreach my $ch (split(//,$str)) {
		if (ord($ch)>127) { $new .= ''; } 
		elsif (ord($ch)==10) { $new .= $ch; } 
		elsif (ord($ch)==13) { $new .= $ch; } 
		elsif (ord($ch)==9) { $new .= $ch; } 
		elsif (ord($ch)<32) { } 
		else { $new .= $ch; }
		}
	return($new);
	}


######################################################
##
## NAME: base36
##
## purpose: converts a number, to an option code (base 36) representation e.g. 0 = 00, 10 = 0A, 17 = 0G
##
sub base36 {
	my ($NUM) = @_;


	my @vals = ('0'..'9','A'..'Z');
	my $result = '';
	if ($NUM>36) {
		# print "INT: ".int($NUM/36)."\n";
		$result = &ZTOOLKIT::base36( int($NUM/36) ).$vals[int($NUM % 36)];
		}
	else {
		$result = $vals[int($NUM % 36)];
		}
	# $result = $vals[int($NUM / 36)].$vals[int($NUM % 36)];
	$result = uc($result);
	return($result);
}

######################################################
##
## NAME: base62
##
## purpose: converts a number, to an option code (base 36) representation e.g. 0 = 00, 10 = 0A, 17 = 0G
##
sub ebase62 {
	my ($NUM) = @_;


	my @vals = ('0'..'9','A'..'Z','-A'..'-Z');
	my $result = '';
	if ($NUM>62) {
		# print "INT: ".int($NUM/62)."\n";
		$result = &ZTOOLKIT::base62( int($NUM/62) ).$vals[int($NUM % 62)];
		}
	else {
		$result = $vals[int($NUM % 62)];
		}
	# $result = $vals[int($NUM / 62)].$vals[int($NUM % 62)];
	$result = uc($result);
	return($result);
}


######################################################
##
## NAME: base36
##
## purpose: converts a number, to an option code (base 36) representation e.g. 0 = 00, 10 = 0A, 17 = 0G
##
sub AZsequence {
	my ($NUM) = @_;

	my @vals = ('A'..'Z');
	my $result = '';
	
	# $result = $vals[int($NUM % 26)].$result;
	if ($NUM > 25) {
		$result = &AZsequence(($NUM / 26)-1);
		$NUM = $NUM % 26;				
		}

	$result = $result.$vals[int($NUM % 26)];
	$result = uc($result);
	return($result);
}



######################################################
##
## NAME: unbase36
##
## purpose: converts a base36 representation into a number
##
sub unbase36 {
	my ($base36) = @_;

	return(undef) unless ($base36 =~ m/^([A-Z0-9]+)$/);

	my %LOOKUP = (
		0=>0,1=>1,2=>2,3=>3,4=>4,5=>5,6=>6,7=>7,8=>8,9=>9,
		A=>10,B=>11,C=>12,D=>13,E=>14,F=>15,G=>16,H=>17,I=>18,
		J=>19,K=>20,L=>21,M=>22,N=>23,O=>24,P=>25,Q=>26,R=>27,
		S=>28,T=>29,U=>30,V=>31,W=>32,X=>33,Y=>34,Z=>35
		);

	my $num = 0;
	my $v = 1;
	foreach my $digit (reverse split(//,$base36)) {
		$digit = uc($digit);
		# print "NUM: $num [$digit]\n";
		$num +=  ($LOOKUP{$digit} * $v);
		$v = $v * 36;
		# print "NUMx: $num [$digit]\n";
		}
	return $num
	}


######################################################
##
## NAME: base62
##
## purpose: converts a number, to an option code (base 62) representation 
##
sub base62 {
	my ($NUM) = @_;

	$NUM = int($NUM);
	my @vals = ('0'..'9','A'..'Z','a'..'z');
	my $result = '';
	if ($NUM>62) {
#		print "INT: ".int($NUM/62)."\n";
		$result = &ZTOOLKIT::base62( int($NUM/62) ).$vals[int($NUM %62)];
		}
	else {
		$result = $vals[int($NUM % 62)];
		}
	# $result = $vals[int($NUM / 36)].$vals[int($NUM % 36)];
	# $result = uc($result);
	return($result);
}



##
## my( $ToBase62, $FromBase62 ) = GenerateBase( 62 );
## my $UniqueID = $ToBase62->( $$ ) . $ToBase62->( time );
sub GenerateBase
{
    my $base = shift;
    $base = 62 if $base > 62;
    my @nums = (0..9,'A'..'Z','a'..'z')[0..$base-1];
    my $index = 0;
    my %nums = map {$_,$index++} @nums;

    my $To = sub
    {
        my $number = shift;
        return $nums[0] if $number == 0;
        my $rep = ""; # this will be the end value.
        while( $number > 0 )
        {
            $rep = $nums[$number % $base] . $rep;
            $number = int( $number / $base );
        }
        return $rep;
    };

    my $From = sub
    {
        my $rep = shift;
        my $number = 0;
        for( split //, $rep )
        {
            $number *= $base;
            $number += $nums{$_};
        }
        return $number;
    };

    return ( $To, $From );
}




## 
##
##
# perl -e 'use lib "/backend/lib"; use ZTOOLKIT; $a = 12345; print "$a\n"; $b = ZTOOLKIT::base62($a); print "$b\n"; print &ZTOOLKIT::unbase62("$b");'
sub unbase62 {
	my ($base62) = @_;

	return(undef) unless ($base62 =~ m/^([a-zA-Z0-9]+)$/);

	my %LOOKUP = (
		0=>0,1=>1,2=>2,3=>3,4=>4,5=>5,6=>6,7=>7,8=>8,9=>9,
		A=>10,B=>11,C=>12,D=>13,E=>14,F=>15,G=>16,H=>17,I=>18,
		J=>19,K=>20,L=>21,M=>22,N=>23,O=>24,P=>25,Q=>26,R=>27,
		S=>28,T=>29,U=>30,V=>31,W=>32,X=>33,Y=>34,Z=>35,
		a=>36,b=>37,c=>38,d=>39,e=>40,f=>41,g=>42,h=>43,i=>44,
		j=>45,k=>46,l=>47,m=>48,n=>49,o=>50,p=>51,q=>52,r=>53,
		s=>54,t=>55,u=>56,v=>57,w=>58,x=>59,y=>60,z=>61
		);
	# use Data::Dumper; print Dumper(\%LOOKUP);
	#%LOOKUP = (); my $i = 0; foreach my $ch ('0'..'9','A'..'Z','a'..'z') { $LOOKUP{$ch} = $i++;	}

	my $num = 0;
	my $v = 1;
	foreach my $digit (reverse split(//,$base62)) {
		my $x = ($LOOKUP{$digit} * $v);
#		print "NUM: $num $LOOKUP{$digit} [$digit] x=$x\n";
		$num +=  $x;
		$v = $v * 62;
		# print "DIGIT: $digit [$num]\n";
		# print "NUMx: $num [$digit]\n";
		}
#	print "FINAL: $num\n";
	return $num
	}



##
## parses a Time::Period and returns a value
##	the syntax is simple.
##
sub dateValueRange {
	my ($txt,$ts) = @_;
	
	require Time::Period;
	my $result = undef;
	if (not defined $ts) { $ts = time(); }

	foreach my $line (split(/[\n\r]+/,$txt)) {
		next if ($line eq '');
		my ($val,$period) = split(/=/,$line,2);
		
		if (Time::Period::inPeriod($ts,$period)>0) { 
			# print "LINE[$line]=[".Time::Period::inPeriod($ts,$period)."]\n";
			$val =~ s/^[\s]+(.*?)[\s]+$/$1/s;		# strip leading and trailing whitespace
			$result =  URI::Escape::XS::uri_unescape($val); 
			}
		}
	return($result);
	}




###########################################################################
# SERIALIZATION


########################################
# SER (SERIALIZE) - Now with NO REGEXPS!!!  :)
# Author: AK^H^H BH^H^H AK
# Decription: Serialize a perl variable into an obfuscated URL-friendly string
# Accepts: A reference to a perl variable, and a 1 to compress or 0 to not,
#          (defaults to 0), and a 1 to deobfuscate or 0 to not (used for
#          compatibility with old serialized structures, defaults to 0)
# Returns: The serialized, obfuscated url-friendly string version of the passed reference
# Notes:
#    Example: $friendlystr = &ZTOOLKIT::ser(\%hash);
#    Example: $friendlystr = &ZTOOLKIT::ser(\@array);
#    BAD:  $friendlystr = &ZTOOLKIT::ser($scal);
#    GOOD: $friendlystr = &ZTOOLKIT::ser(\$scal);
#sub ser
#{
#	my ($var,$compress,$obfuscate) = @_;
#
#
#	my $str; # Output string
#	if ((defined $compress) && ($compress))
#	{
#		# Freeze, Compress and Encode the reference
#		require Compress::Bzip2;
#		$str = &MIME::Base64::encode_base64(&Compress::Bzip2::compress(&Storable::freeze($var),9),'');
#	}
#	else
#	{
#		# Freeze and Encode the reference
#		$str = &MIME::Base64::encode_base64(&Storable::freeze($var),'');
#	}	
#	
#	# Use '_' and '-' instead of '+' and '/' since they don't have to be url encoded.
#	# THIS CORRUPTS DATA!!
#	# THIS DOES NOT CORRUPT DATA!!!  _ and - are NOT part of the Base64 character set.
#	# The Base64 character set is alpha, numbers, +, /, and = (see section 6.8 of RFC
#	# 2045 if you don't believe me).  Changed from s/// to tr/// since it will do it
#	# in one pass and doesn't use the regular expression library (simple replace, much
#	# quicker). READ THE SECTION ON tr/// in Programming Perl if you want to know more.
#	# -AK
#	if ((defined $obfuscate) && ($obfuscate))
#	{
#		# Added some obfuscation translation back in since we're already burning cycles on
#		# a tr/// here either way.
#		# d end option strips = since it doesn't have a counterpart in the replacement list
#		# - has to be last in the replace list or its interpreted as a range (like A-Z)
#		$str =~ tr[+/abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789=]
#		          [Z0OVY_Rocks42JLlmtGWHQM1gBfpqbhvUw3DIx5nad9PANTy8jiz7SEX6FuCKer-]d; 
#	}
#	else
#	{
#		$str =~ tr[+/=][_-]d;
#	}	
#	
#	return $str;
#}
#
#########################################
## DESER (DESERIALIZE) - Now with NO REGEXPS!!!
## Author: AK^H^H BH^H^H AK
## Description: Deserialize a perl variable from a string encoded using the algorithm above
## Accepts: A serialized, obfuscated url-friendly string encoded above,
##          and a 1 to decompress or 0 to not (defaults to 0 if not provided),
##          and a 1 to obfuscate or 0 to not (used for compatibility with old
##          serialized structures, defaults to 0)
## Returns: A reference to a perl variable
## Notes:
##    Example: $var = &ZTOOLKIT::deser($string);
#
#sub deser
#{
#	my ($str,$decompress,$deobfuscate) = @_;
#
#
#	if ((defined $deobfuscate) && ($deobfuscate))
#	{
#		# See comments for this function's evil twin in ser
#		$str =~ tr[Z0OVY_Rocks42JLlmtGWHQM1gBfpqbhvUw3DIx5nad9PANTy8jiz7SEX6FuCKer-]
#		          [+/abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789];
#	}
#	else
#	{
#		$str =~ tr[_-][+/];
#	}
#
#	# Add Base64 padding back on to the end to keep MIME::Base64 from bitching
#	while (length($str) % 4) { $str .= '='; }
#
#	if ((defined $decompress) && ($decompress))
#	{
#		# return the Decoded, Decompressed and Thawed reference
#		#require Compress::Bzip2;
#		#return &Storable::thaw(&Compress::Bzip2::decompress(&MIME::Base64::decode_base64($str)));
#		# Thaw: (would not work as a bare thaw under a require, because require does not import thaw
#		# into the local namespace, it now works 'cause we're specifying Storable:: explicitly).
#		## Complained about $ratio code (assume this was uncompleted work to Bzip2. -AK 8/20/03
#		require Compress::Bzip2;
#		my $ratio = 25;
#		my $ref = undef;
#		while ( (not defined $ref) && ($ratio < 400))
#		{
#			$ref = &Storable::thaw(&Compress::Bzip2::decompress(&MIME::Base64::decode_base64($str)));
#			$ratio *= 2;
#		}
#		return($ref);
#	}
#	else
#	{
#		# return the Decoded and Thawed reference
#		return &Storable::thaw(&MIME::Base64::decode_base64($str));
#	}
#
#}

#########################################
## SERIALIZE (DEPRECATED)
## Author: AK
## Decription: Serialize a hash or array into a string that can be used either with or without URL encoding (it uses no
##    characters that get packed like%20this)
## Accepts: a hash or array (names and values can be ANYTHING, including any special charater, even binary data)
## Returns: the serialized, obfuscated url-friendly string version of the hash/array
## Notes:
##    Example: $serialized_hash = &ZTOOLKIT::serialize(%hash);
##    Example: $serialized_array = &ZTOOLKIT::serialize(@array);
##    You can of course just take an arbitrary list of arguments as well:  $string = &ZTOOLKIT::serialize('foo','bar','baz');
##    And then deserialize them by going ($foo, $bar, $baz) = &ZTOOLKIT::deserialize(string);
##    Also note that this will translate undefs into blank strings
#sub serialize
#{
#	my $serialized = '';
##	print STDERR "ZTOOLKIT::serialize is deprecated.  Please use ZTOOLKIT::ser\n";
#	foreach my $entry (@_)
#	{
#		if (defined($entry) && ($entry ne ''))
#		{
#			# Mime encode it (turns the data into a-zA-Z+/= only (= is just a padding char)
#			$serialized .= &MIME::Base64::encode_base64($entry,'');
#		}
#		# delimit with a . since it doesn't have to be url encoded
#		$serialized .=  '.'; 
#	}
#	# Remove the end padding so we don't have to encode it in a URL
#	$serialized =~ s/\=//g;
#	# Use _ and - instead of + and /since they don't have to be url encoded
#	$serialized =~ s/\+/_/g;
#	$serialized =~ s/\//-/g;
#	# Take that!  Muahahahahah!
#	$serialized =~ tr[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]
#	                 [ZYXWVUTSRQPONMLKJIHGFEDCBAzyxwvutsrqponmlkjihgfedcba];
##	chop $serialized;
#	return reverse($serialized);
#}
#
#########################################
## DESERIALIZE (DEPRECATED)
## Author: AK
## Description: Deserialize a hash or array from a string encoded using the algorithm above
## Accepts: An array of serialized, obfuscated url-friendly strings encoded above to be placed into a single output array/hash
## Returns: a hash or array (names and values can be ANYTHING, including any special charater, even binary data)
## Notes:
##    Example: %deserialized_hash = &ZTOOLKIT::deserialize($string);
##    Example: @deserialized_array = &ZTOOLKIT::deserialize($string);
#sub deserialize
#{
#	my @deserialized;
##	print STDERR "ZTOOLKIT::deserialize is deprecated.  Please use ZTOOLKIT::deser\n";
#	foreach my $serialized (@_)
#	{
#		$serialized = reverse($serialized);
#		foreach my $entry (split(/\./,$serialized))
#		{
#			if (!defined($entry) || ($entry eq ''))
#			{
#				push @deserialized,'';
#				next;
#			}
#			# Use _ and - instead of + and /since they don't have to be url encoded
#			$entry =~ s/\_/+/;
#			$entry =~ s/\-/\//;
#			# Muahahahahah!
#			$entry =~ tr[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]
#			            [ZYXWVUTSRQPONMLKJIHGFEDCBAzyxwvutsrqponmlkjihgfedcba];
#			# Re-pad the base64 string with = so that perl -w doesn't complain
#			while (length($entry) % 4) { $entry .= '='; }
#			# Mime decode it (decodes the data from its a-zA-Z+/ form
#			push @deserialized, &MIME::Base64::decode_base64($entry);
#		}
#	}
#	return @deserialized;
#}
#
#
########################################
# FAST_SERIALIZE
# Author: AK^H^H BH
# Decription: Serialize a reference to something. Spirit of code borrowed from AK's original serialize function
#             Despite the name, SER/DESER is faster than FAST_SERIALIZE/FAST_DESERIALIZE
# Returns: the serialized, obfuscated url-friendly string version of the hash/array
# Notes:
#    Example: $friendlystr = &ZTOOLKIT::serialize(\%hash);
#    Example: $friendlystr = &ZTOOLKIT::serialize(\@array);

sub fast_serialize {
	# Fixed to use the storable as a require
	require Storable;

	my ($ref,$compress) = @_;

	if (!defined($ref)) { return ''; }

	my $result = '';

	if ($compress)
	{
		# Freeze: (would not work as a bare thaw under a require, because require does not import thaw
		# into the local namespace, it now works 'cause we're specifying Storable:: explicitly).

		#require Compress::Bzip2;
		## 8AAAAEdCWmg2MUFZJlNZwssodgAAD_vQffAEAD-AJAAvAIhAAAIACCAAUMYAAAAAamkMmgHqaMyQ9SZSIQvAeHOX6NwzktEwygC2sZ25jPrulUWzGjPDAqjeg9NvxdyRThQkMLLKHYA
		#$result = &MIME::Base64::encode_base64(Compress::Bzip2::compress(&Storable::freeze($ref),9),''); 
		### H4sIAAAAAAAA-2Nh5zA0MjYxNTO3YOHg4GBmYWBgYOtYHRIIpBkYgTiVoxdEJXNxViQWp6SBMIifyCbCycAAU5QCABDqwwpHAAAA
		#$result = &MIME::Base64::encode_base64(Compress::Zlib::memGzip(&Storable::freeze($ref)),'');
		require Compress::Zlib;
		require YAML::Syck;
		## H4sIAAAAAAAA-9PV1VXgSrRSqEgsTkkDYa5kKwVDY64UKwUjYyMTrlQrBXVDYzMTUwNjEwtLdS4AzmnFbzAAAAA
		$result = &MIME::Base64::encode_base64(Compress::Zlib::memGzip(&YAML::Syck::Dump($ref)),'');
	}
	else
	{
		## BAcIMTIzNDU2NzgECAgIAwQAAAAGVKtUUQAAAAABAAAAZQiNAQAAAGMKCXhhc2RmYXNkZgEAAABhBhQJAAAAAAAAAQAAAGQ
		## $result = &MIME::Base64::encode_base64(&Storable::freeze($ref),'');
		require YAML::Syck;
		$result = &MIME::Base64::encode_base64(YAML::Syck::Dump($ref),'');
	}

	study($result);
	# Remove end padding.
	$result =~ s/=//g; 

	# Use _ and - instead of + and /since they don't have to be url encoded
	$result =~ s/\+/\_/g;
	$result =~ s/\//-/g;
	
	return ($result);	# nice touch eh?
}


########################################
# FAST_DESERIALIZE
# Author: AK^H^H BH
# Description: Deserialize a hash or array from a string encoded using the algorithm above
#             Despite the name, SER/DESER is faster than FAST_SERIALIZE/FAST_DESERIALIZE
# Accepts: An array of serialized, obfuscated url-friendly strings encoded above to be placed into a single output array/hash
# Returns: a hash or array (names and values can be ANYTHING, including any special charater, even binary data)
# Notes:
#    Example: $ref = &ZTOOLKIT::fast_deserialize($string);

sub fast_deserialize
{
	my ($str,$compress) = @_;


	if ( (!defined($str)) || ($str eq '') ) {
#		print STDERR "fast deserialized null!\n";
		return({});
		}

	# study($str);

	# Use _ and - instead of + and /since they don't have to be url encoded
	# THIS CORRUPTS DATA!!
	# THIS DOES NOT CORRUPT DATA!!!  _ and - are NOT part of the Base64 character set.
	# The Base64 character set is alpha, numbers, +, /, and = (see section 6.8 of RFC
	# 2045 if you don't believe me).  -AK
	$str =~ s/\_/\+/g;
	$str =~ s/\-/\//g;

	# Remove the end padding so we don't have to encode it in a URL
	# stupid MIME tricks, it needs one or two padding characters to not throw an error
	# so we'll add 5 which is way more than we need, but doesn't make us calc the correct number.
	# Re-pad the base64 string with = so that perl -w doesn't complain
	while (length($str) % 4) { $str .= '='; } # Please do not change/remove this without consulting me -AK

	my $ref = undef;
	if ($compress) {
		# Thaw: (would not work as a bare thaw under a require, because require does not import thaw
		# into the local namespace, it now works 'cause we're specifying Storable:: explicitly).
		#require Compress::Bzip2;
		#my $ratio = 25;		
		#while ( (not defined $ref) && ($ratio < 400)) {
		#	$ref = &Storable::thaw(Compress::Bzip2::decompress(&MIME::Base64::decode_base64($str),$ratio));
		#	$ratio *= 2;
		#	}
		require Compress::Zlib;
		require YAML::Syck;
		# $ref = &Storable::thaw(Compress::Zlib::memGunzip(&MIME::Base64::decode_base64($str)));
		$ref = &YAML::Syck::Load(Compress::Zlib::memGunzip(&MIME::Base64::decode_base64($str)));
	} 
	else {
		$str = &MIME::Base64::decode_base64($str);
		$ref = YAML::Syck::Load($str); 
		# $ref = Storable::thaw($str); 
		}

	return ($ref);	# nice touch eh?
}

########################################
# DECODESTRING
# Author: AK
# Description: Takes a string and a key, and makes a URL-ready encoded validatable version
# Accepts: A string, and a "password" for decoding and validating that string on the flip-side
# Returns: The encoded version of the string
# Notes: I used this instead of ser/deser because we needed something to make much shorter URLs
sub encodestring
{
	my ($unencoded,$key) = @_;
	require Digest::MD5;
	require MIME::Base64;
	if (not defined $unencoded) { $unencoded = ''; }
	if (not defined $key)       { $key       = ''; }
	my $md5 = &Digest::MD5::md5_base64($unencoded.$key);
	my $string = &MIME::Base64::encode_base64($unencoded);
	my $encoded = $md5.':'.$string;
	$encoded =~ tr[+/abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789=]
	              [Z0OVY_Rocks42JLlmtGWHQM1gBfpqbhvUw3DIx5nad9PANTy8jiz7SEX6FuCKer-]d; 
	return $encoded;
}

########################################
# DECODESTRING
# Author: AK
# Description: Takes an encoded string and a key, and returns the validated decoded version of the string
# Accepts: A string, and a "password" for decoding and validating that string
# Returns: Undef if the string was invalid, or the decoded version of the string upon success
# Notes: I used this instead of ser/deser because we needed something to make much shorter URLs
sub decodestring
{
	my ($encoded,$key) = @_;
	require Digest::MD5;
	require MIME::Base64;
	if (not defined $encoded) { $encoded  = ''; }
	if (not defined $key)     { $key      = ''; }
	$encoded =~ tr[Z0OVY_Rocks42JLlmtGWHQM1gBfpqbhvUw3DIx5nad9PANTy8jiz7SEX6FuCKer-]
	              [+/abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789];
	my ($md5,$string) = split(/\:/,$encoded);
	while (length($string) % 4) { $string .= '='; }
	my $unencoded = &MIME::Base64::decode_base64($string);
	my $md5_check = &Digest::MD5::md5_base64($unencoded.$key);
	if ($md5_check ne $md5) { return undef; }
	return $unencoded;	
}

###########################################################################
# DEBUGGING

########################################
# DEBUG VAR (DEPRECATED, USE DUMPVAR)
# Author: AK
# Description: Takes any kind of variable and prints the code needed to recreate it (very useful for debugging)
# Accepts: a reference to the variable, and a name for the variable
# Returns: a string that contains the code needed to recreate the variable
# Notes: This is just a wrapper for dumpvar
sub debug_var
{
	# use something like debug_var(\$params,'$params'); to call this.
	my ($var_ref,$var_name) = @_;
	$var_name =~ s/^[\@\%\$]//; # strip off the variable type identifier
	return &dumpvar($var_ref,$var_name);
}

########################################
# PRINTARRAY (DEPRECATED, USE DUMPVAR)
# Prints out an array
# Accepts: The name of an array as a string, a reference to the array, and optionally
#   the string 'HTML' or 'TEXT' to indicate the desired output format (HTML default)
# Returns: nothing if printing, the results if not
# Notes: This is just a wrapper for dumpvar
sub printarray {
	my ($arrayname,$arrayref,$format,$printit) = @_;
	if (not defined $printit) { $printit = 1; }
	$arrayname =~ s/^[\@]//; # Strip off the leading @ on the var name
	my $out = &dumpvar($arrayref,$arrayname);
	if ($format eq 'HTML') { $out = "<pre>$out</pre>"; }
	if ($printit) { print $out; }
	else { return $out; }
}

########################################
# PRINTHASH (DEPRECATED, USE DUMPVAR)
# Does the same thing as printarray
# Notes: This is just a wrapper for dumpvar
sub printhash {
	my ($hashname,$hashref,$format,$printit) = @_;
	if (not defined $printit) { $printit = 1; }
	$hashname =~ s/^[\%]//; # Strip off the leading % on the var name
	my $out = &dumpvar($hashref,$hashname);
	if ($format eq 'HTML') { $out = "<pre>$out</pre>"; }
	if ($printit) { print $out; }
	else { return $out; }
}

########################################
# DUMPVAR
# Prints out an string of the variable passed either to a filehandle or as the return of the sub
# Accepts: A reference to the variable, variable name (without $ % @ yadda), and optionally a filehandle.
# Returns: nothing if a filehandle is provided, the code to make the variable if the filehandle is.
sub dumpvar {
	my ($varref,$varname,$fh) = @_;
	require Data::Dumper;
	my ($d) = Data::Dumper->new([$varref],['*'.$varname]);
	my $out = $d->Dump;
	if (defined($fh) && (ref($varref) eq 'GLOB')) {
		print $fh $out;
	}
	return $out;
}

########################################
# HTMLIFY
# Author: AK
# Description: Takes raw text and turns it into HTML (useful for debugging text output in the middle of a page)
# Accepts: an un-htmlified string (handing it HTML will result in said HTML being turned into plain text)
# Returns: an htmlified version of the plain text
sub htmlify
{
	my ($string) = @_;
	$string =~ s/ /\&nbsp\;/g;
	$string =~ s/\</\&lt\;/g;
	$string =~ s/\>/\&gt\;/g;
	$string =~ s/\n[\r]?/\<br\>\n/g;
	$string = '<pre>' . $string . "</pre>\n";
	return $string;
}

###########################################################################
# VALIDATION

########################################
# VALIDATE EMAIL
# Author: AK
# Description: Checks to see if what its handed is a validly formatted email address
# Accepts: A string to check to see if its an email address
# Returns: a 1 if it is a correct email address or a 0 if it is not.
## NOTE:: you probably actually want to use validate_email_strict
sub validate_email
{
	if (not defined $_[0]) { return 0; }
	if ($_[0] eq '') { return 0; }
	# matches *@*.?* (tld must be at least two chars long)
	if ($_[0] !~ m/^.+\@.+\...+$/) { return 0; }
	if ($_[0] =~ m/[\s]/) { return(0); }	# no spaces!
	if (substr($_[0],-1) eq '.') { return(0); } 	# cannot end with a .
	return 1;
}

########################################
# VALIDATE EMAIL STRICT
# Author: AK
# Description: Same as above but with tigher restrictions (tight enough to be passed on a command line in 'quotes')
# Accepts: A string to check to see if its an email address
# Returns: a 1 if it is a correct email address or a 0 if it is not.
sub validate_email_strict
{
	if (not defined $_[0]) { return 0; }
	if ($_[0] eq '') { return 0; }
	## Domain must have 3 or more letters to allow only one dot (.com .net .info .whatever)
	## Domains with 2 or less letters in the top (country codes) must have at least 2 dots
	## Only certain special characters allowed before the @ and all of them are command-line safe if included in 'quotes'.
	if ($_[0] !~ m/^[\*\!\&\_\=\+\.\,\:\;\.a-z0-9-]+\@[a-z0-9\.\-]+\.([a-z][a-z][a-z]+|[a-z]+\.[a-z][a-z])$/i) { return 0; }
	if ($_[0] !~ m/^.*?[a-z]+.*?\@/i) { return 0; } ## Must have at least one letter before the @
	## Note this is not RFC compliant, but will handle 99.9% of email addresses (better to kick back idiot email addresses than to let errant data into the system)
	return 1;
}

########################################
# VALIDATE PHONE
# Author: AK
# Description: All this does is see if therer are at least 10 digits in the phone number
#    if its in the US, 8 if its international.  We can expand this in the future to handle
#    the number of numbers for each country for a number ot be valid
# Accepts: A phone number and optionally a country
# Returns: A 1 if the phone number is good, a 0 if it isn't
sub validate_phone
{
	my ($phone_number,$country) = @_;
	if (not defined $phone_number) { return 0; }
	if ($phone_number eq '') { return 0; }
	$phone_number =~ s/\D//g;
	if (($country eq '') || ($country eq 'United States'))
	{
		if (length($phone_number) < 10) { return 0; }
	}
	else
	{
		if (length($phone_number) < 7) { return 0; }
	}
	return 1;
}

########################################
# NUMTYPE
# Author: AK
# Description: Determines whether a string is a valid decimal number
# Accepts: a scalar to check to see if its a number of a particular type
# Returns:
#	2 if its a positive decimal number
#	1 if it is a positive integer number
#	0 if it is not a recognized number
#	-1 if it is a negative integer number
#	2 if its a negative decimal number
sub numtype
{
	my ($number) = @_;
	# You can have a plus sign in front if you want
	if (not defined $number) { return 0; }
	elsif ("$number" =~ /^\+?\d+\.\d+$/) { return 2; }
	elsif ("$number" =~ /^\+?\d+$/) { return 1; }
	elsif ("$number" =~ /^\-\d+$/) { return -1; }
	elsif ("$number" =~ /^\-\d+\.\d+$/) { return -2; }
	else { return 0; }
}

########################################
# ISNUM
# Author: AK
# Checks to see whether a string is a valid integer
# Accepts: a scalar to check to see if its a valid non-decimal number
# Return: 1 if it is a number, 0 if it is not
sub isnum
{
	my ($number) = shift @_;
	if (not defined $number) { $number = ''; }
	return ($number =~ /^\d+$/) ? 1 : 0 ;
}

########################################
# ISDECNUM
# Author: AK
# Determines whether a string is a valid decimal number
# Accepts: a scalar to check to see if its a valid positive decimal (or non-decimal) number
# Return: 1 if it is a number, 0 if it is not

sub isdecnum
{
	my ($number) = shift @_;
	if (not defined $number) { $number = ''; }
	elsif ($number =~ /^\d+\.\d+$/) { return(1); } # 1.00000
	elsif ($number =~ /^\d+$/) { return(1); } # 123
	return(0);
	# return ($number =~ /^(\d+(\.\d+)?)|(\.\d+)$/) ? 1 : 0 ;
}

########################################
# ISDECNUMNEG
# Author: AK
# Determines whether a string is a valid decimal number
# Accepts: a scalar to check to see if its a valid positive or negative decimal (or non-decimal) number
# Return: 1 if it is a number, 0 if it is not

sub isdecnumneg {
	my ($number) = shift @_;

	if (not defined $number) { $number = ''; }
	elsif ($number =~ /^\-?\d+\.\d+$/) { return(1); } # 1.00000
	elsif ($number =~ /^\-?\d+$/) { return(1); } # 123
	return(0);
	}

########################################
# CLEANNUM
# Author: AK
# Always outputs a number
# Accepts: A scalar, which is checked to see if its a valid decimal (or non-decimal) number
# Return: The number, if it is a number, 0 if it is not
sub cleannum {
	my ($value) = @_;
	if (defined($value) && &isdecnum($value)) { return $value; }
	return 0;
}

########################################
# WORDLENGTH
# Author: AK
# Description: finds how long the string would be with all non-alphanumerics stripped
# Accepts:  A string
# Returns: the length of the string after all non-alphanumeric characters have been stripped
sub wordlength {
	my ($check_this) = @_;

##	NOTE: this now supports locale
#	print STDERR "CHECK: $check_this [".setlocale("LC_CTYPE")."]\n";

	if (not defined $check_this) { return 0; }
	$check_this =~ s/[\W]//g; #strip all non-alphanumeric characters
	return length($check_this);
	}

########################################
# WORDSTRIP
# Author: AK
# Description: returns the string with all non-alphanumerics stripped
# Accepts:  A string
# Returns: the string with all non-alphanumerics stripped
sub wordstrip
{
	my ($strip_this) = @_;
	if (not defined $strip_this) { return ''; }
	$strip_this =~ s/[\W]//g; #strip all non-alphanumeric characters
	return $strip_this;
}


## wikiStrip
sub wikistrip {
	my ($strip_this) = @_;

#	## eventually this should probably do something!
#	my $new = '';
#	foreach my $line (split(/[\n\r]/,$strip_this) {
#		}

	# STRIP: [[Planet of the Apes]:search=Planet of the Apes]
	$strip_this =~ s/\[\[(.*?)\]:.*?\]/$1/gs;
	
	$strip_this =~ s/\%(softbreak|hardbreak)\%/\n/gso;

	## stage 1: convert to html
	require Text::WikiCreole;
	$strip_this = Text::WikiCreole::creole_parse($strip_this);
	
	## stage 2: htmlstrip
	$strip_this = &ZTOOLKIT::htmlstrip($strip_this);

	return($strip_this);
	}


##
## looks in wikitext for bullets and extracts them.
## returns an arrayref of [ key1, value1 ], [ key2, value2 ]
sub extractWikiBullets {
	my ($wikicontents) = @_;

	my @bullets = ();
	foreach my $line (split(/[\n\r]+/, $wikicontents)) {
		# print STDERR "LINE[$line\n";
		my ($k,$v) = (undef,undef);
		if ($line =~ /^\*[\s]*(.*?)[\:\-][\s]+(.*?)$/) {      # *bullet: something   or *bullet- something
			($k,$v) = ($1,$2);
			print STDERR "K[$k] V[$v]\n";
			$k =~ s/^[\s]+//gs; $k =~ s/[\s]+$//gs;
			$v =~ s/^[\s]+//gs; $v =~ s/[\s]+$//gs;
			push @bullets, [ $k, $v ];
			}
		}

	return(\@bullets);
	}


########################################
# HTMLSTRIP
# Author: AK
# Description: returns the string with all HTML tags stripped
# Accepts:  A string
# Returns: the string with all HTML stripped
sub htmlstrip
{
	my ($strip_this,$detail) = @_;
	if (not defined $strip_this) { return ''; }
	$strip_this =~ s/\<br\>/\n/gs; 
	$strip_this =~ s/\<\/?p\>/\n/gs; 


	## WTF -- this switches the alt tag text into the description. LAME!
	# $strip_this =~ s/\<.*?[Aa][Ll][Tt]\s*\=\s*\"([^"]*)\"\>/$1/gs;
	# $strip_this =~ s/\<.*?[Aa][Ll][Tt]\s*\=\s*\'([^']*)\'\>/$1/gs;
	# $strip_this =~ s/\<.*?[Aa][Ll][Tt]\s*\=\s*(\S+)\>/$1/gs;

	## WRONG: this line doesn't do anything (the next line does the same
	## thing) DOH!  this removes stuff between <script><!-- //--></script>
	## tags!
	$strip_this =~ s/\<\!\-\-.*?\-\-\>//gs;
	$strip_this =~ s/\<.*?\>//gs;

	## hmmm -- this line seems bad.
	# $strip_this =~ s/[\"\']+/ /gs;

	## the following two lines  jackify wiki code.
	# $strip_this =~ s/\n+/\n/gs; # Remove extra blank lines
	# $strip_this =~ s/\s+/ /gs; # Remove extra space

	if (($detail & 1) == 1) { 
		$strip_this =~ s/\&nbsp\;/ /gs; 
		$strip_this =~ s/\&amp\;/ & /gs;
		}

	$strip_this = CGI::unescapeHTML($strip_this); # HTML entity decode.

	if (($detail & 2) == 2) { 
		my $tmp = '';
		foreach my $ch (split(//,$strip_this)) {
			next if ((ord($ch)>127) || (ord($ch)<32));
			$tmp .= $ch;
			}
		$strip_this = $tmp;
		}

	return $strip_this;
}

########################################
# NUMBERLENGTH
# Author: AK
# Description: finds how long the string would be with all non-numerics stripped
# Accepts: a string
# Returns: the length of the string after all non-numeric characters have been stripped
sub numberlength
{
	my ($check_this) = @_;
	if (not defined $check_this) { return 0; }
	$check_this =~ s/[\D]//g; #strip all non-numeric characters
	return length($check_this);
}

###########################################################################
# ARRAYS

########################################
# ISIN
# Author: AK
# Description: Checks to see if a scalar value exists as one of the entries of an array
# Accepts: a reference to an array and a scalar
# Returns: 1 if the scalar does appear in the array, and 0 if it doesn't
sub isin
{
	my ($arrayref,$check) = @_;
	if (
		(not defined $arrayref) ||
		(ref($arrayref) ne 'ARRAY') ||
		(not scalar(@{$arrayref}))
	)
	{
		return 0;
	}
	
	$check = uc($check);
	foreach my $this_entry (@{$arrayref})
	{
		# Compare this entry of the array to the scalar, if they match return true
		if (uc($this_entry) eq $check) { return 1; }
	}
	# Otherwise return false
	return 0;
}

########################################
# UNIQUE
# Author: AK
# Description: Returns a list of all the unique items in an array
# Accepts: an array
# Returns: an array
sub unique {
	my %found = ();
	my @uniques = ();
	foreach (@_) {
		if (not defined $found{$_}) {
			$found{$_} = 0;
			push @uniques, $_;
		}
		#$found{$_}++;
	}
	return @uniques;
}

########################################
# MINMAX LEXICAL
# Author: AK
# Description: Finds the minimum and maximum values in an array if sorted alphabetically
# Accepts: an array
# Returns: the minimum and maximum vales of the array when sorted lexically
sub minmax_lexical {
	my ($min, $max);
	$min = $_[ $[ ];
	$max = $min;
	foreach(@_) {
		if ($_ lt $min) { $min = $_; }
		elsif ($_ gt $max) { $max = $_; }
	}
}

########################################
# MINMAX NUMERIC
# Author: AK
# Description: Finds the minimum and maximum values in an array if sorted by number
# Accepts: an array
# Returns: the minimum and maximum vales of the array when sorted numerically
sub minmax_numeric {
	my ($min, $max);
	$min = $_[ $[ ];
	$max = $min;
	foreach(@_) {
		if ($_ < $min) { $min = $_; }
		elsif ($_ > $max) { $max = $_; }
	}
	return ($min, $max);
}

########################################
# SPIN
# Author: AK
# Description: if the number of elements to be rotated is positive, it rotates
#    the array by pulling leftmost values and adding them to the end as many
#    times as specified, and goes the opposite direction if its negative
# Accepts: the number of elements to rotate and a reference to an array
# Returns: nothing
sub spin {
	my ($elements, $array_ref) = @_;
	$elements = int($elements);
	if ($elements > 0) {
		foreach (1 .. $elements) { push @$array_ref, shift @$array_ref; }
	}
	elsif ($elements < 0) {
		foreach (1 .. (0 - $elements)) { unshift @$array_ref, pop @$array_ref; }
	}
}

########################################
# SPINTO
# Author: AK
# Description: rotates the array so that the destination index is the
#    first element
# Accepts: a destination index and a reference to an array
# Returns: nothing
sub spinto {
	my ($destination, $array_ref) = @_;
	foreach ($[ .. int($destination - 1)) { push @$array_ref, shift @$array_ref; }
}

########################################
# SPINTIL
# Author: AK
# Description: rotates the array by pulling leftmost values and adding
#    them to the end of the array until the destination value is the first
#    element
# Accepts: a destination value and a reference to an array
# Returns: nothing
sub spintil {
	my ($destination, $array_ref) = @_;
	while ($array_ref->[$[ ] ne $destination) { push @$array_ref, shift @$array_ref; }
}

########################################
# UNSPINTIL
# Author: AK
# Description: rotates the array by pulling rightmost values and adding
#    them to the start of the array until the destination value is the first
#   element
# Accepts: a destination value and a reference to an array
# Returns: nothing
sub unspintil {
	my ($destination,$array_ref) = @_;
	while ($array_ref->[ $[ ] ne $destination) { unshift @$array_ref, pop @$array_ref; }
}

##########################################################################
# HASHES

########################################
# ISKEY
# Author: AK
# Description: Checks to see if a scalar value exists as one of the keys of a hash
# Accepts: a reference to a hash and a scalar
# Returns: 1 if the scalar does appear as a key in the hash, and 0 if it doesn't

sub iskey
{
	my ($hashref,$check) = @_;
	return defined($hashref->{$check});
}

########################################
# ISVAL
# Author: AK
# Description: Checks to see if a scalar value exists as one of the values of a hash
# Accepts: a reference to a hash and a scalar
# Returns: 1 if the scalar does appear as a value in the hash, and 0 if it doesn't

sub isval
{
	my ($hashref,$check) = @_;
	# Compare this value of the hash to the scalar, if they match return true
	foreach my $this_key (keys %{$hashref}) { if ($hashref->{$this_key} eq $check) { return 1; } }
	# Otherwise return false
	return 0;
}

########################################
# VALUESORT
# Author: AK
# Description: Sorts a hash based on its values as opposed to its keys
# Accepts: a reference to a hash and optionally the string 'alphabetically' or 'numerically'
# Returns: a sorted list of keys from the referenced hash
# Notes: The secondary sort (if two values are the same) is always alphabetically on the key
sub value_sort
{
	my ($hashref, $type) = @_;
	
	if (not defined $type) { $type = 'alphabetically'; }
	my @output = ();
	my %inverted = ();

	# aded my
	foreach my $key (keys %{$hashref}) {
		# I tried really hard to explain this, and it didn't make a damn bit of sense.
		# See "Hashes with Multiple Values Per Key" in the Perl Cookbook
		# See the stuff on anonymous hashes and arrays in Programming Perl
		# See the stuff on references in Programming Perl
		# When you come back you still probably won't know what the heck this
		# means, but at least you'll be a little more confused.  PFM.  -AK
		if (defined $hashref->{$key}) {
			push @{$inverted{uc($hashref->{$key})}}, $key;
		}
		else {
			push @{$inverted{''}}, $key;
		}
	}

#	use Data::Dumper;
#	print Dumper(\%inverted);

	# Now we should have a hash called %inverted, keyed on the values of the array referred
	# to by $hashref and having values containing an array of keys.  Does this make sense?  No.
	if ($type eq 'numerically') {
		# Numeric sorting
		# sort { $a <=> $b; } just sorts numerically, see the programming perl entry on "sort" for more info
		no warnings 'numeric'; # Keep perl from bitching about non-numerics
		foreach my $key (sort { $a <=> $b; } keys(%inverted)) {
			# loop though all of the keys stored for each value, and add it onto the @output array (the sorted list of keys to $hashref)
			foreach my $entry (sort @{$inverted{$key}}) { # See the Note: above
				push @output, $entry;
			}
		}
	}
	else {
		# Default alphabetical sorting
		## patti - added insensitive sorting {lc($a) cmp lc($b} - 2005-09-06
		## bh - note: the "case insensitive" behavior here doesn't work properly in some cases - 2008-01-23 - bh
		##			it's not that simple!
		foreach my $key (sort {$a cmp $b} keys(%inverted)) {
			# loop though all of the keys stored for each value, and add it onto the @output array (the sorted list of keys to $hashref)
			foreach my $entry (sort {$a cmp $b} @{$inverted{$key}}) { # See the Note: above
				push @output, $entry;
			}
		}
	}

#	use Data::Dumper;
#	print STDERR Dumper(@output);

	return @output;
}

###########################################################################
# PARSING

########################################
# GETAFTER
# Author: AK
# Description: Retreives a chunk of a string past a certain anchor point
# Accepts: A reference to a scalar to be scanned, the text to scan for, the number 
#          of characters to return, and which occurrance of the anchor to look for
#          NOTE: starts at count starts at 1
# Returns: a string containing the text after the anchor, or undef if that occurance of the achor doesn't exist
sub getafter
{
	my ($REF, $ANCHOR, $SIZE, $NUMBER) = @_;

	# REF and ANCHOR are required, there are defaults for the others.
	unless (defined $NUMBER) { $NUMBER = 1; }
	my $location = 0;
	for (my $count = 0 ; $count < $NUMBER; $count++) 
	{
		my $offset = index(${$REF}, $ANCHOR, $location);
		# If the anchor isn't found then retun undef
		if ($offset == -1) { return undef; }
		$location = $offset + length($ANCHOR);
	}
	if (defined $SIZE) {
		# If you send a negative number, it will do a get BEFORE!
		if ($SIZE < 0) {
			$location += $SIZE - length($ANCHOR);
			if ($location < 0) { $location = 0; }
			$SIZE = 0 - $SIZE;
		}
		return substr(${$REF},$location,$SIZE);
	}
	else {
		# If we don't have a size defined return everything up to the end 
		return substr(${$REF},$location);
	}
}

sub getbefore {
	my ($REF, $ANCHOR, $SIZE, $NUMBER) = @_;
	return (&getafter($REF,$ANCHOR,(0-$SIZE),$NUMBER));
}

########################################
# URLPARAMS
# Description: Gets all of the params in a GET format URL
# Accepts: A list of he GET method params in URL format
# Returns: It returns a reference to a hash of all the parameters in
#          the URL.
sub urlparams {
	my ($url) = @_;
	$url =~ s/.*?\?//; # Strip everything that's the script portion of the url
	return parseparams($url);
}

##
## perl -e 'use lib "/backend/lib"; use ZTOOLKIT; use Data::Dumper; print Dumper(ZTOOLKIT::dsnparams("xxx?k1=v1&k2=v2"));'
##$VAR1 = 'xxx';
##$VAR2 = {
##         'k2' => 'v2',
##         'k1' => 'v1'
##        };
##
## NOTE: dsn uses *similiar* but not identical encoding rules to URI
##			specifically DSN does not encode +'s to %2B
sub dsnparams {
	my ($dsn) = @_;
	#print "SUBSTR: ".substr($uri,index($uri,'?')+1)."\n";
	my $dsnid = substr($dsn,0,index($dsn,'?'));
	my $dsnparams = {};
	foreach my $keyvalue (split /\&/, substr($dsn, index($dsn,'?')+1 ) ) {
		my ($key, $value) = split /\=/, $keyvalue;
		if ((defined $value) && ($value ne '')) {
			$value =~ s/\%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
			$key =~ s/\%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
			$dsnparams->{$key} = $value;
			}
		else {
			$dsnparams->{$key} = '';
			}
		}
	return($dsnid,$dsnparams);
	}

##
##
##
sub builddsn {
	my ($dsid,$dsnparams) = @_;
	
	my $dsn = "$dsid?";
	foreach my $k (sort keys %{$dsnparams}) {
		$dsn .= "$k=";
		foreach my $ch (split(//,$dsnparams->{$k})) {
			if (((ord($ch)>=48) && (ord($ch)<58)) || ((ord($ch)>64) &&  (ord($ch)<=127))) { $dsn .= $ch; }
			## don't encode <(60) or >(62) /(47)
			elsif ((ord($ch)==60) || (ord($ch)==62) || (ord($ch)==47)) { $dsn .= $ch; }
			else { $dsn .= '%'.sprintf("%02x",ord($ch));  }
			}
		$dsn .= '&';
		}
	chop($dsn);
	return($dsn);
	}

##
## Converts a hashref to URI params (returns a string)
## 	note: minimal defaults to 0 
##		note: minimal of 1 means do not escape < > or / in data.
##
sub buildparams {	
	my ($hashref,$minimal) = @_;

	if (not defined $minimal) { $minimal = 0; }	
	my $string = '';

	foreach my $k (sort keys %{$hashref}) {
		foreach my $ch (split(//,$k)) {
			# print "ORD: ".ord($ch)."\n";
			if ($ch eq ' ') { $string .= '+'; }
			elsif (((ord($ch)>=48) && (ord($ch)<58)) || ((ord($ch)>64) &&  (ord($ch)<=127))) { $string .= $ch; }
			else { $string .= '%'.sprintf("%02x",ord($ch));  }
			}
		$string .= '=';
		foreach my $ch (split(//,$hashref->{$k})) {
			if ($ch eq ' ') { $string .= '+'; }
			elsif (((ord($ch)>=48) && (ord($ch)<58)) || ((ord($ch)>64) &&  (ord($ch)<=127))) { $string .= $ch; }
			## don't encode <(60) or >(62) /(47)
			elsif (($minimal) && ((ord($ch)==60) || (ord($ch)==62) || (ord($ch)==47))) { $string .= $ch; }
			else { $string .= '%'.sprintf("%02x",ord($ch));  }
			}
		$string .= '&';
		}
	chop($string);
	return($string);
	}

########################################
# PARSEPARAMS
# Description: Gets all of the params in a GET format URL
# Accepts: A list of he GET method params in URL format
# Returns: It returns a reference to a hash of all the parameters in
#          the URL.
sub parseparams {
	my ($string) = @_;

	my $params = {};
	if (not defined $string) { return $params; }

	foreach my $keyvalue (split /\&/, $string) {
		my ($key, $value) = split /\=/, $keyvalue;
		next if (not defined $key);		## not sure how this happens!? but needs this line.

		if ((defined $value) && ($value ne '')) {
			$value =~ s/\+/ /g;
			$value =~ s/\%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
			$key =~ s/\+/ /g;
			$key =~ s/\%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
			$params->{$key} = $value;
		}
		else {
			$key =~ s/\+/ /g;
			$key =~ s/\%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
			$params->{$key} = '';
		}
	}
	return $params;
}

########################################
# XMLISH_TO_HASHREF
## Simple flat-hash of <field>value</field> to a hashref of 'field'=>'value'
sub xmlish_to_hashref {
	my ($xml,%params) = @_;
	if (not defined $xml) { $xml = ''; }
	## Fields are not lowercased by default, pass this in if you want the tags lowercased
	my $lowercase = num($params{'lowercase'});
	## If you want to match zoovy-style namespaced tags instead of all of them, you could pass in 'tag_match'=>qr/\w+\:\w+/
	my $tag_match  = defined($params{'tag_match'}) ? $params{'tag_match'} : qr/\w+/;
	## 'use_hashref'=>$foo will use $foo as the hashref for loading into (useful for overwriting values)
	my $hashref = (defined($params{'use_hashref'}) && (ref($params{'use_hashref'}) eq 'HASH')) ? $params{'use_hashref'} : {} ;
	my $decoder = \&decode;
	if (defined $params{'decoder'}) {
		if (ref $params{'decoder'} eq 'CODE')  { $decoder = $params{'decoder'}; }
		elsif ($params{'decoder'} eq 'basic')  { $decoder = \&decode; }
		elsif ($params{'decoder'} eq 'latin1')  { $decoder = \&decode_latin1; }
		}

   while ($xml =~ s/\<($tag_match)\>(.*?)\<\/\1\>//s) {
      $hashref->{$lowercase?lc($1):$1} = $decoder->($2);
      }

	#while ($xml =~ s/<($tag_match).*?>(.*?)<\/\1>//s) {		## what the @#$%^ was .*?
	#while ($xml =~ s/\<($tag_match)\>(.*?)\<\/\1\>//s) {
	#	$hashref->{$lowercase?lc($1):$1} = $decoder->($2);
	#	}
	return $hashref;
}


########################################
# XMLISH_TO_HASHREF
## Simple flat-hash of <field>value</field> to a hashref of 'field'=>'value'
sub fast_xmlish_to_hashref {
	my ($xml,%params) = @_;
	if (not defined $xml) { $xml = ''; }
	## Fields are not lowercased by default, pass this in if you want the tags lowercased
	my $lowercase = num($params{'lowercase'});
	## If you want to match zoovy-style namespaced tags instead of all of them, you could pass in 'tag_match'=>qr/\w+\:\w+/
	my $tag_match  = defined($params{'tag_match'}) ? $params{'tag_match'} : qr/\w+/;
	## 'use_hashref'=>$foo will use $foo as the hashref for loading into (useful for overwriting values)
	my $hashref = (defined($params{'use_hashref'}) && (ref($params{'use_hashref'}) eq 'HASH')) ? $params{'use_hashref'} : {} ;
	my $decoder = \&ZTOOLKIT::decode;
	if (defined $params{'decoder'}) {
		if (ref $params{'decoder'} eq 'CODE')  { $decoder = $params{'decoder'}; }
		elsif ($params{'decoder'} eq 'basic')  { $decoder = \&decode; }
		elsif ($params{'decoder'} eq 'latin1')  { $decoder = \&decode_latin1; }
		}

	# return($hashref);

	## while ($xml =~ s/<($tag_match).*?>(.*?)<\/\1>//s) {		## what the @#$%^ was .*?
	#while ($xml =~ s/\<($tag_match)\>(.*?)\<\/\1\>//s) {
	#	$hashref->{$lowercase?lc($1):$1} = $decoder->($2);
	#	}
	if ($lowercase) {
		while ($xml =~ m/<($tag_match)>(.*?)<\/\1\>/gs) {
			$hashref->{ lc($1) } = &ZTOOLKIT::decode($2);
			}
		}
	else {
		while ($xml =~ m/<($tag_match)>(.*?)<\/\1\>/gs) {
			$hashref->{$1} = $decoder->($2);
			}
		}
	
	return $hashref;
}

########################################
## XMLISH_LIST_TO_ARRAYREF
## Takes something like:
## <product id="foo" blah="blah, blah">What a great product!</product>
## <product id="foo2" blah="bar">Not so great</product>
## And turns it into a arrayref of
## [
##   { id=>'foo',  blah=>'blah, blah', content=>'What a great product!', tag=>'product' }, 
##   { id=>'foo2', blah=>'bar',        content=>'Not so great'         , tag=>'product' }, 
## ]
sub xmlish_list_to_arrayref
{
	my ($xml,%params) = @_;
	if (not defined $xml) { $xml = ''; }
	## 'tag'=>'product' in the above example is set by passing in 'tag_attrib'=>'tag'
	my $tag_attrib     = def($params{'tag_attrib'});
	## The content of the tag is automagically loaded into 'content', you can change this by passing 'content_attrib'=>'description' (or whatever)
	my $content_attrib = gstr($params{'content_attrib'},'content');
	## Attribs are passed through in whatever case they are found in...  you can lowercase all of them with 'lowercase'=>1
	my $lowercase      = num($params{'lowercase'});
	## 'tag_match'=>qr/event/i will only return event tags (case insensitive)...  you could do some tricks with this
	my $tag_match      = defined($params{'tag_match'}) ? $params{'tag_match'} : qr/\w+/;
	## $decoder is a reference to perl code to decode the XML contents of tags/values
	## If not passed it uses the default.
	my $decoder = \&decode;
	if (defined $params{'decoder'})
	{
		if (ref $params{'decoder'} eq 'CODE')  { $decoder = $params{'decoder'}; }
		elsif ($params{'decoder'} eq 'basic')  { $decoder = \&decode; }
		elsif ($params{'decoder'} eq 'latin1')  { $decoder = \&decode_latin1; }
	}
	my @results = ();
	while ($xml =~ s/<($tag_match)(.*?)>(.*?)<\/\1>//is) {
		my %item = ( $content_attrib => ($params{'content_raw'})?$3:decode($3) );
		my $attribs = " $2 ";
		if ($tag_attrib ne '') { $item{$tag_attrib} = $1; }
		while ($attribs =~ s/\s(\w+)\s*\=\s*\"(.*?)\"\s/ /s)
		{
			$item{$lowercase?lc($1):$1} = $decoder->($2);
		}
		push @results, \%item;
	}
	return \@results;
}

## NOTE: this function is actually *much* slower than decode is
#%ZTOOLKIT::INCODEMAP = ( '&quot;'=>'"','&lt;'=>'<','&gt;'=>'>','&amp;'=>'&' );
#sub decode_fast {
#	my ($i) = @_;
#	$i =~ s/([\&]{1}(quot|lt|gt|amp)[\;]{1})/$ZTOOLKIT::INCODEMAP{$1}/eogs;
#	return($i);
#	}

## why is this here, it duplicates ZOOVY dcode
## wow.. this is WAY faster on strings which don't have a lot of substitions
sub decode
{
	my ($i) = @_;

	if (not defined $i) { return($i); }
	$i =~ s/\&quot\;/"/go;
	$i =~ s/\&lt\;/</go;
	$i =~ s/\&gt\;/>/go;
	$i =~ s/\&amp\;/&/go;
	return ($i);
}

## why is this here, it duplicates ZOOVY::incode
sub encode {
	my ($i) = @_;
	if (not defined $i) { return($i); }

	$i =~ s/\&/&amp;/g;
	$i =~ s/\>/&gt;/g;
	$i =~ s/\</&lt;/g;
	$i =~ s/\"/&quot;/g;
	return ($i);
	}

sub decode_latin1 {
	my ($i) = @_;
	if (not defined $i) { return($i); }

	$i =~ s/\&\#(1?\d?\d|2([0-4]\d|5[0-5]))\;/chr($1)/eg; ## Match number between 0-255
	$i =~ s/\&quot\;/"/g;
	$i =~ s/\&lt\;/</g;
	$i =~ s/\&gt\;/>/g;
	$i =~ s/\&amp\;/&/g;
	return ($i);
	}

sub encode_latin1 {
	my ($i) = @_;
	if (not defined $i) { return($i); }

	$i =~ s/\&/&amp;/g;
	$i =~ s/\>/&gt;/g;
	$i =~ s/\</&lt;/g;
	$i =~ s/\"/&quot;/g;
	$i =~ s/([\x00-\x08\x0B\x0C\x0E-\x1F\x7F])//g; ## Strip control characters (leaves LF CR TAB)
	$i =~ s/([\x80-\xFF])/'&#'.ord($1).';'/eg; ## Encode high-bit characters
	return ($i);
	}

sub html_obfuscate {
	my $out = '';
	foreach my $char (split //, $_[0]) {
		$out .= '&#'.ord($char).';'
		}
	return $out;
	}


###########################################################################
# FORMATTING

########################################
# HASHREF_TO_XMLISH
##	
##	options:
##		sanitize = bitwise (0 = none, 1=\W+ becomes _)
sub hashref_to_xmlish
{
	my ($hashref,%params) = @_;
	if ((not defined $hashref) || (ref($hashref) ne 'HASH')) { $hashref = {}; }
	my $sort        = num($params{'sort'});
	my $newlines    = num(gstr($params{'newlines'},1));
	my $lowercase   = num($params{'lowercase'});
	my $skip_blanks = def($params{'skip_blanks'},0);
	my $sanitize = def($params{'sanitize'},1); 

	my $encoder = \&encode;
	if (defined $params{'encoder'})
	{
		if (ref $params{'encoder'} eq 'CODE')  { $encoder = $params{'encoder'}; }
		elsif ($params{'encoder'} eq 'basic')  { $encoder = \&encode; }
		elsif ($params{'encoder'} eq 'latin1')  { $encoder = \&encode_latin1; }
	}
	my $xml = '';
	foreach my $key ($sort ? (sort keys %{$hashref}) : (keys %{$hashref}))
	{
		my $value = $encoder->(def($hashref->{$key}));
		next if ($skip_blanks && ($value eq ''));
		if ($sanitize) { $key =~ s/\W+/\_/gs; }
		if ($lowercase) { $key = lc($key); }
		$xml .= "<$key>$value</$key>";
		$newlines && ($xml .= "\n");
	}
	return $xml;
}

sub arrayref_to_xmlish_list
{
	my ($array,%params) = @_;

	unless (defined($array) && scalar($array)) { return ''; }
	my @items = @{$array}; # Make a copy we can modify while outputting;
	## 'tag'=>'product' will set the XML to output the list as a series of <product ...>...</product> tags
	my $tag            = def($params{'tag'},'item');
	## The content of the tag is automagically loaded into 'content', you can change this by passing 'content_attrib'=>'description' (or whatever)
	my $content_attrib = gstr($params{'content_attrib'},'content');
	## Attribs are passed through in whatever case they are found in...  you can lowercase all of them with 'lowercase'=>1
	my $lowercase      = num($params{'lowercase'});
	## Attribs of the tag that should appear first in the output
	my @required_attribs = defined($params{'required_attribs'}) ? @{$params{'required_attribs'}} : () ;
	## Attribs not in attribs_first should be sorted by the passed param to perl's sort
	my $attribs_sort = undef;
	if (defined $params{'attribs_sort'})
	{
		if (ref $params{'attribs_sort'} eq 'CODE')  { $attribs_sort = $params{'attribs_sort'}; }
		elsif ($params{'attribs_sort'} eq 'alphabetically')  { $attribs_sort = sub { $a cmp $b }; }
	}
	## What encoder should be used for the XML
	my $encoder = \&encode;
	if (defined $params{'encoder'})
	{
		if (ref $params{'encoder'} eq 'CODE')  { $encoder = $params{'encoder'}; }
		elsif ($params{'encoder'} eq 'basic')  { $encoder = \&encode; }
		elsif ($params{'encoder'} eq 'latin1')  { $encoder = \&encode_latin1; }
	}
	my $newlines    = num(gstr($params{'newlines'},1));
	my $xml = '';
	foreach my $item (@items)
	{
		my $contents = ($params{'content_raw'})?$item->{$content_attrib}:$encoder->(def($item->{$content_attrib}));
		if (not defined $contents) { $contents = ''; }
		# delete $item->{$content_attrib};
		my $attribs_xml = '';
		foreach my $attrib (@required_attribs) {
			next if (substr($attrib,0,1) eq '_');	# tags with a leading _ are hidden (not valid anyway)
			next if (substr($attrib,0,1) eq '*');	# tags with a leading _ are hidden (not valid anyway)
			next if ($attrib eq $content_attrib);
			$attribs_xml .= ' '.($lowercase?lc($attrib):$attrib).'="'.$encoder->(def($item->{$attrib})).'"';
			delete $item->{$attrib};
		}
		my @attribs = defined($attribs_sort) ? (sort $attribs_sort keys(%{$item})) : keys(%{$item});
		foreach my $attrib (@attribs) {
			next if (substr($attrib,0,1) eq '_');	# tags with a leading _ are hidden (not valid anyway)
			next if (substr($attrib,0,1) eq '*');	# tags with a leading _ are hidden (not valid anyway)
			next if ($attrib eq $content_attrib);
			$attribs_xml .= ' '.($lowercase?lc($attrib):$attrib).'="'.$encoder->(def($item->{$attrib})).'"';
			}
		$xml .= "<$tag$attribs_xml>$contents</$tag>";
		if ($newlines) { $xml .= "\n"; }
	}
	return $xml;
}

########################################
# MAKEURL
# Author: AK
# Description: Creates a url from a hash and a base URL
# Accepts: A url and a hashref
# Returns: the new URL with the params added to it
sub makeurl
{
	my ($url,$hashref,$dropblanks,$shortmode) = @_;
	unless (defined($hashref) && (ref($hashref) eq 'HASH')) { return $url; }
	if (not defined $dropblanks) { $dropblanks = 0; }
	if (not defined $shortmode)  { $shortmode  = 0; }
	my $content = &makecontent($hashref,$dropblanks,$shortmode);
	if ($content)
	{
		if    ($url !~ /\?/)  { $url .= '?'; }
		elsif ($url !~ /\&$/) { $url .= '&'; }
		$url .= $content;
	}
	return $url;
}

########################################
# MAKECONTENT
# Author: AK
# Description: Creates a url-encoded string from a hashref
# Accepts: A hashref, and whether to drop undefs/blanks from the output
# Returns: The new URL formatted parameters list
sub makecontent
{
	my ($hashref,$dropblanks,$shortmode,$sortkeys) = @_;
	unless (defined($hashref) && (ref($hashref) eq 'HASH')) { return ''; }
	if (not defined $dropblanks) { $dropblanks = 0; }
	if (not defined $shortmode)  { $shortmode  = 0; }
	if (not defined $sortkeys) { $sortkeys = 0; }
	my $content = '';
	my @fields = $sortkeys ? sort keys(%{$hashref}) : keys(%{$hashref}); 
	foreach (@fields)
	{
		if (not defined $hashref->{$_}) { $hashref->{$_} = ''; }
		my $name  = $shortmode ? &short_url_escape($_)             : &CGI::escape($_);
		my $value = $shortmode ? &short_url_escape($hashref->{$_}) : &CGI::escape($hashref->{$_});
		next if ($dropblanks && ($value eq ''));
		if ($content ne '') { $content .= '&'; }
		$content .=  $name.'='.$value;
	}
	return $content;
}

########################################
# MAKEFORMCONTENT
# Author: AK
# Description: Same as above but it outputs a form for a POST instead of a GET compatible string
# Accepts: A url and a hashref, and whether to drop undefs/blanks from the output
# Returns: The new form contentns with the params added to it

sub makeformcontent
{
	my ($hashref,$dropblanks,$sortkeys) = @_;
	unless (defined($hashref) && (ref($hashref) eq 'HASH')) { return ''; }
	if (not defined $dropblanks) { $dropblanks = 0; }
	if (not defined $sortkeys) { $sortkeys = 0; }
	my $content = '';
	my @fields = $sortkeys ? sort keys(%{$hashref}) : keys(%{$hashref}); 
	foreach (@fields)
	{
		my $name  = CGI::escapeHTML($_);
		my $value = CGI::escapeHTML(defined($hashref->{$_})?$hashref->{$_}:'');
		next if ($dropblanks && ($value eq ''));
		$content .= qq~<input type="hidden" name="$name" value="$value">\n~;
	}
	return $content;
}

########################################
# SHORT_URL_ESCAPE
# Author: AK
# Description: URL encodes a string in the shortest possible fashion
#              uses plusses instead of %20, etc, is more liberal about not encoding reserved
#              URI characters like / : ? @ since they are universally supported by browsers
#              after the ?   This method is not suppored by CGI::escpape or URI::Escape
# Accepts: A string
# Returns: A URL encoded string
# Notes: uses a bit of code at the top of this module to generate the @ZTOOLKIT::esc var
sub short_url_escape {
	my ($in) = @_;
	return '' unless (defined $in);
	my $out = '';
	foreach (0..(length($in)-1)) {
		$out .= $ZTOOLKIT::esc[ord(substr($in,$_,1))];
		}
	return $out;
	}

########################################
# CLEANHASH
# Author: AK
# Description: Takes a hash and makes sure each of the values have the whitespace before and after removed
# Accepts: a hashref
# Returns: nuthin'
sub cleanhash
{
	my ($hashref) = @_;
	return unless (ref($hashref) eq 'HASH');
	foreach (keys %{$hashref})
	{
		next unless defined($hashref->{$_});
		$hashref->{$_} =~ s/^\s+//;
		$hashref->{$_} =~ s/\s+$//;
	}
}

########################################
# GARBAGE_COLLECT_HASH
# Author: AK
# Description: Takes a hash cleans undefs and optionally blanks
# Accepts: a hashref, and params 'del_blank'=>1/0 (defaults 1), 'clean_whitespace'=>1/0 (default 0)
# Returns: nuthin'
sub garbage_collect_hash
{
	my ($hashref,%params) = @_;
	return unless (ref($hashref) eq 'HASH');
	my $del_blank = def($params{'del_blank'},1); ## Usually only deletes undefs, you can delete blank strings too
	my $clean_whitespace = def($params{'clean_whitespace'},0); ## Clean up any extra whitespace as you go
	foreach (keys %{$hashref})
	{
		if (not defined $hashref->{$_}) { delete $hashref->{$_}; next; }
		if ($clean_whitespace) { $hashref->{$_} = trim($hashref->{$_}); }
		if ($del_blank && ($hashref->{$_} eq '')) { delete $hashref->{$_}; }
	}
}

########################################
# MONEYFORMAT
# Author: AK
# Description: Takes a number and makes it so it'll look like moolah
# Accepts: a scalar to be rendered like $1,000.00
# Returns: a number like $1,000.00 or (-$1,000.00) or the unmodified contents if its not a number
sub moneyformat {
	my ($output, $currency) = @_;

	if (not defined $currency) { $currency = 'USD'; }
	elsif ($currency eq '') { $currency = 'USD'; }

	if ($currency eq 'USD') {
		# Positive number?
		if (&numtype($output) >=  0) {
			$output = sprintf("%.2f",$output);
			# The idea for the comma part of this was yoinked from the Perl Cookbook
			$output = reverse $output;
			$output =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
			$output = scalar reverse $output;
			$output = "\$" . $output;
			}
		# Negative number?
		elsif (&numtype($output) <  0) {
			$output = sprintf("%.2f",$output);
			# Strip off the minus sign so we can use the regexp to add commas
			$output =~ s/^\-(.*)$/$1/;
			# The idea for the comma part of this was yoinked from the Perl Cookbook
			$output = reverse $output;
			$output =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
			$output = scalar reverse $output;
			# Add the minus sign back on and put it in parenthesis
			$output = "(-\$" . $output . ")";
			}
		}
	else {
		require ZTOOLKIT::CURRENCY;
		($output) = &ZTOOLKIT::CURRENCY::convert($output,'USD',$currency);
		($output) = &ZTOOLKIT::CURRENCY::format($output,$currency);
		}


	# If it wasn't a number, we return the output back unchanged
	return $output;
	}

## Formats a numer as 2 decimal points
## Tries to work around most things you'd see passed into a cash field accidentally
## Returns 0.00 if unable to parse for some reason
sub cashy
{
	my ($num) = @_;
	return '0.00' unless defined($num);
	$num =~ s/[\,\$]//gs; # Remove commas and dollar signs (often found in numbers)
	$num =~ s/\s//g; # Strip leading/trailing spaces
	return '0.00' unless $num =~ m/^\-?[0-9]+(\.[0-9]+)?$/; ## Does it look like a cash-able number?
	return sprintf("%.2f", $num);
}

########################################
# ZEROPAD
# Author: AK
# Description: Pads a number with zeroes
# Accepts: desired length of string, un-padded number
# Returns: String version of number with zeroes left-padding it to the requested length
sub zeropad {
	my ($needed_length, $number) = @_;
	while (length "$number" < $needed_length) { $number = "0" . $number; }
	return $number;
}

########################################
# PADZERO
# Author: AK
# Description: Pads a number with zeroes
# Accepts: desired length of string, un-padded number
# Returns: String version of number with zeroes right-padding it to the  requested length
sub padzero {
	my ($needed_length, $number) = @_;
	while (length "$number" < $needed_length) { $number = $number . "0"; }
	return $number;
}

#######################################
# PRETTY AND UGLY

# "pretty" and "ugly" are used in a few stencils...  render seemed the best place for them, especially since $title uses it already
# Pretty takes a string that "looks_like_this%21" and modifies it to where  it "Looks Like This!"
sub pretty {
	my ($prettystring) = @_;
	if (not defined $prettystring) { $prettystring = ''; }
	$prettystring =~ s/_/ /g;
	my $prettystring2 = '';
	foreach (split/\s/,$prettystring) {
		$prettystring2 = $prettystring2 . ucfirst($_) . ' ';
	}
	$prettystring2 =~ s/\s+$//;
	return $prettystring2;
}

# Ugly takes a string that "Looks Like This!" and modifies it to where  it "looks_like_this%21"
sub ugly {
	my ($uglystring) = @_;
	$uglystring = &CGI::escape($uglystring);
	$uglystring =~ s/\%20/_/g;
	return $uglystring;
}

########################################
# UNTAB
# Author: AK
# Description: removes leadign whitespace
# Accepts: number of tabs, and a string
# Returns: the string with the specified number of tabs removed
sub untab {
	my ($string) = @_;
	$string = def($string);    ## Prevent undef errors
	$string =~ s/\n\s+/\n /gs; ## Change any number of leading whitespace characters into a single whitespace char
	$string =~ s/^\n//gs;      ## Remove blank lines
	$string =~ s/[\t ]+$//gs;  ## Remove trailing whitespace
	return $string;
}

## Like untab but instead of translating leading whitespace into a single space, remove it entirely
## Also does not compress multiple newlines into a single
## Handy for using with qq~~, hence the name
sub qqtrim {
	my ($string) = @_;
	$string = def($string);   ## Prevent undef errors
	$string =~ s/^\n//;       ## Trim a single newline from the beginning of the string,
	                          ##    since a multi-line qq~~ requires it.
	$string =~ s/^[\t ]+//gm; ## Trim spaces/tabs from beginnings of lines
	$string =~ s/[\t ]+$//gm; ## Trim spaces/tabs from ends of lines
	$string =~ s/\n$//;       ## Trim a single newline from the end of the string, since
	                          ##   a multi-line qq~~ requires it.  Note that you will need to 
	                          ##   add in an extra newline if you want to end with a newline
	return $string;
}

sub entab
{
	my ($string) = @_;
	$string = def($string);
	return '' if ($string eq '');
	$string = "\t" . join("\n\t", split("\n", $string));
	if ($string !~ m/\n$/) { $string .= "\n"; }
	return $string;
}


########################################
# MULTI LINE

# Author: AK
# Description: Turns a string into an array of padded strings for multi-line processing
# Accepts: A string, and a desired length for each line when broken into multiple lines, and the sting 'left','right' or 'center' to specify justification
# Returns: An array of strings, broken to the appropriate length (existing line breaks are preserved if passed)
# Used By: Cart View Text in ORDER

#sub multi_line {
#	my ($str,$col,$just) = @_;
#	my ($pp);
#	require Text::Wrap;
#	$Text::Wrap::columns = ($col + 1);
#	if ($Text::Wrap::columns) {}  # Keep perl -w from whining
#	unless (defined $just) { $just = 'left'; }
#	my $newstr = '';
#
#	## if there is no value, return an empty hash
#	# if (not defined $str) { return([]); }
#
#	# preserve paragraphs (two newlines)
#	foreach $pp (split(/\n\n/, $str)) {
#		$pp =~ s/\n//gs;
#		$pp =~ s/\s+/ /gs;
#		$newstr .= &Text::Wrap::wrap('','',$pp) . "\n\n";
#		}
#
#	# Turn it into an array
#	my @output = split(/\n/,$newstr);
#	foreach (@output) { # we're operating on the $_ variable here so we don't have to do a lot of copying
#		chomp;
#		my $even = 0; 
#		# Keep padding the string until its as wide as we need it
#		while (length($_) < $col) {
#			# If we're right justified, or we're on an even numbered pass on a centered string
#			if (($just eq 'right') || (($just eq 'center') && $even)) { 
#				$_ = ' ' . $_; # Add a space to the end
#			}
#			else {
#				$_ .= ' '; # Add a space to the end
#			}
#			$even = $even ? 0 : 1 ; #Flip even
#		}
#	}
#	return @output;
#}


########################################
# JUSTIFY

# Author: AK
# Description: Justifies a string by padding with spaces
# Accepts: A string, and a width to be justified to, and the sting 'left','right' or 'center' to specify justification
# Returns: The justified string
# Used By: Cart View Text in ZORDER

#sub justify {
#	my ($str,$col,$just) = @_;
#	unless (defined $just) { $just = 'left'; }
#	$str =~ s/\n//gs;
#	$str =~ s/\s+/ /gs;
#	my $even = 0; 
#	# Keep padding the string until its as wide as we need it
#	while (length($str) < $col) {
#		# If we're right justified, or we're on an even numbered pass on a centered string
#		if (($just eq 'right') || (($just eq 'center') && $even)) { 
#			$str = ' ' . $str; # Add a space to the end
#		}
#		else {
#			$str .= ' '; # Add a space to the end
#		}
#		$even = $even ? 0 : 1 ; #Flip even
#	}
#
#	return $str;
#}

########################################
# APPEND NUMBER SUFFIX

# Author: BH
# Description: returns the st for the 1st, and the nd for the 2nd,
# and rd for the 3rd and so on..
# Accepts: A number
# Returns: The string to be appended to make the number readable as an iteration

sub append_number_suffix
{
	my ($number) = @_;
	$number = $number % 100;
	if ($number == 11 || $number == 12 || $number == 13) { return 'th'; } # special case.
	return ('th','st','nd','rd','th','th','th','th','th','th')[$number % 10];
}

sub line_number_text
{
	my ($text) = @_;
	my $out = '';
	my $count = 1;
	foreach (split /\n/, $text) { $out .= "$count: $_\n"; $count++; }
	return $out;
}

sub prepend_text
{
	my ($head,$text) = @_;
	$text = $head.join("\n$head",split(/\n/,$text))."\n";
	return $text;
}

###########################################################################
# DATETIME

##################################################
## ZTOOLKIT::stamp_to_gmtime
## Takes a GMT unixtime and turns it into YYYY-MM-DD HH:MM:SS for GMT as used in events
##################################################
sub unixtime_to_gmtime
{
	my ($stamp) = @_;
	$stamp = def($stamp);
	if ($stamp !~ m/^\d+$/) { return '1970-01-01 00:00:00'; }
	my @t = gmtime($stamp);	
	return sprintf("%04D-%02D-%02D %02D:%02D:%02D",$t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0]);
}

##################################################
## ZTOOLKIT::stamp_to_gmtime
## Takes a event style YYYY-MM-DD HH:MM:SS timestamp and returns GMT unixtime (or undef if unable to parse)
## (you can optionally pass it a PST/EDT/+700 whatevere to the end of it.)
##################################################
sub gmtime_to_unixtime
{
	my ($gmtime) = @_;
	$gmtime = def($gmtime);
	my $timestamp;
	require Date::Parse;
	## Recognizes YYYY-MM-DD HH:MM:SS with optional three-letter or +/- number timezone
	if ($gmtime =~ m/^\d\d\d\d\-\d\d\-\d\d \d\d\:\d\d\:\d\d$/)
	{
		## The GMT bit is important here or else it'll assume PST/PDT
		$timestamp = Date::Parse::str2time("$gmtime GMT"); 
	}
	elsif ($gmtime =~ m/^\d\d\d\d\-\d\d\-\d\d \d\d\:\d\d\:\d\d ([a-zA-Z]{3,3}|[+-]\d\d\d)$/)
	{
		## This should parse correctly given the timezone in the time stamp
		$timestamp = Date::Parse::str2time($gmtime); 
	}
	return $timestamp;
}

########################################
## MYSQL_TO_UNIXTIME
## Description: takes a mysql datetime (2001-08-13 21:47:15) and returns unixtime
## Accepts: mysql datetime
## returns: Unixtime
sub mysql_to_unixtime
{
	my ($datetime) = @_;
	
	if ((!defined($datetime)) || ($datetime eq '')) { return (''); }

	my ($y,$m,$d,$h,$mn,$s) = ();
	if (length($datetime)==14) {
		## e.g. 20070315010000
		$y = substr($datetime,0,4);
		$m = int( substr($datetime,4,2) );
		$d = int( substr($datetime,6,2) );
		$h = int( substr($datetime,8,2) );
		$mn = int(substr($datetime,10,2) );
		$s = int( substr($datetime,12,2) );
		}
	else {
		($y,$m,$d,$h,$mn,$s) = split(/[ \:\-]/,$datetime);
		}
	if ($y == 0) { return(0); }

	require Time::Local;
	$y -= 1900; $m--;

	if ($y>125) { $y = 125; $m = 1; $d = 1; $h = 0; $mn = 0; $s = 0; }
	return(Time::Local::timelocal($s,$mn,$h,$d,$m,$y));

#	print "$y $m $d $h $mn $s\n";
#	$y -= 1900; $y--; $m--; $d--;      # all mktime values start at zero.
	require POSIX;
	return(POSIX::mktime($s, $mn, $h, $d, $m, $y,undef,undef,0));

	require Date::Manip;	
	return(&Date::Manip::Date_SecsSince1970GMT($m,$d,$y,$h,$mn,$s));
}

########################################
# MYSQL_FROM_UNIXTIME
# Author: BH
# Description: Puts unixtimestamps into MYSQL time "YYYYMMDDHHMMSS" format
# Accepts: timestamp
# Returns: mysql timestamp
sub mysql_from_unixtime {
	my ($stamp) = @_;
	my @t = localtime($stamp);	
	return sprintf("%04D%02D%02D%02D%02D%02D",$t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0]);
}


########################################
# TIMETOHASH
# Author: AK
# Description: Takes a unix time stamp and turns it into a hash with the GMT date info in it
# Accepts: The output of a time command (seconds since ecpoch)
# Returns: A reference to a hash with the output of gmtime
sub timetohash {
	my ($stamp) = @_;
	my ($tssec,$tsmin,$tshour,$tsmday,$tsmon,$tsyear,$tswday,$tsyday,$tsisdst) = gmtime($stamp);
	return {
		'sec' => $tssec,
		'min' => $tsmin,
		'hour' => $tshour,
		'mday' => $tsmday,
		'mon' => $tsmon,
		'year' => $tsyear,
		'wday' => $tswday,
		'yday' => $tsyday,
		'isdst' => $tsisdst
	};
}

########################################
# ROUNDTIMESTAMPTOHOUR
# Author: AK
# Description: Takes a unix time stamp and rounds it down to the nearest hour
# Accepts: The output of a time command (seconds since ecpoch)
# Returns: The rounded down version of the same
sub roundtimestamptohour {
	my ($stamp) = @_;
	my ($stamphash, $rounded);
	$stamphash = &timetohash($stamp);
	require Time::Local;
	$rounded = &Time::Local::timegm(
		0,
		0,
		$stamphash->{'hour'},
		$stamphash->{'mday'},
		$stamphash->{'mon'},
		$stamphash->{'year'},
		$stamphash->{'wday'},
		$stamphash->{'yday'},
		$stamphash->{'isdst'}
	);
	return $rounded;
}

########################################
# ROUNDTIMESTAMPTOMONTH
# Author: AK
# Description: Takes a unix time stamp and rounds it down to the nearest month
# Accepts: The output of a time command (seconds since ecpoch)
# Returns: The rounded down version of the same
sub roundtimestamptomonth {
	my ($stamp) = @_;
	my ($stamphash, $rounded);
	$stamphash = &timetohash($stamp);
	$rounded = timegm(
		0,
		0,
		0,
		1,
		$stamphash->{'mon'},
		$stamphash->{'year'},
		'',
		'',
		$stamphash->{'isdst'}
	);
	return $rounded;
}

########################################
# UNIXTIME TO TIMESTAMP
# Author: BH
# Description: takes a unix time and gives a result formatted as YYYYMMDDHHMMSS
# Accepts: Unix time stamp
# Returns: A UTC time stamp string in the format YYYYMMDDHHMMSS
sub unixtime_to_timestamp
{
	my ($utime) = @_;
	my ($stamp,$sec,$min,$hour,$mday,$mon,$year);
	($sec,$min,$hour,$mday,$mon,$year,undef,undef) = gmtime($utime);
	$stamp = sprintf("%4.0f%2.0f%2.0f%2.0f%2.0f%2.0f",$year+1900,$mon+1,$mday,$hour,$min,$sec);
	$stamp =~ s/ /0/g;
	return ($stamp);
}


##############################################
# PRETTY TIME SINCE
# Author: BH 3/4/2001
# Description: takes unixtimestamp and returns the number of days, hours, mins, seconds that have elapsed till now
# Note: pass it a 0 it returns "Never"
# Returns: March 4th, 2001 
sub pretty_time_since
{
   my ($timestamp,$nowis) = @_;

   my $c = "";    # temp buffer used to build output

   if ($timestamp == 0) { return("Never"); }
   # make timestamp the time SINCE [lazy reuse of a variable]
   if (defined($nowis))
      {
      $timestamp = $nowis - $timestamp;
      } else {
      $timestamp = time() - $timestamp;
      }

	if ($timestamp>86400)
		{
		$c .= int($timestamp / 86400)." days, ";
		$timestamp = int($timestamp % 86400); 
		} 

	if ($timestamp>3600)
		{
		$c .= sprintf("%2d:",int($timestamp / 3600));
		$timestamp = int($timestamp%3600); 
		} else { $c .= "00:"; } 

	if ($timestamp>60)
		{
		$c .= sprintf("%2d:",int($timestamp / 60));
		$timestamp = int($timestamp%60);
		} else { $c .= "00:"; }

	# add the seconds!
	$c .= sprintf("%2d",$timestamp);

	# i'm sure there is a better way to do this.
	# replace all blank spots with zeros
	$c =~ s/: /:0/g;

	return($c);
}



sub elastic_datetime {
	my ($timestamp) = @_;
	my $c = strftime("%Y/%m/%d %H:%M:%S",localtime($timestamp));
	return($c);
	}


sub timestamp { return(&ZTOOLKIT::pretty_date($_[0],2)); }

###################################################################
## PRETTY_DATE
## Send it a timestamp, it sends back a date
## if you want time as well, pass it a 1 as the second parameter
##
sub pretty_date
{
	my ($timestamp,$style) = @_;

	if (not defined $style) { $style = 0; }
	require Date::Calc;

	my $c = "";		# temp buffer used to build output

	if ( (!defined $timestamp) || ($timestamp eq '') ) { $timestamp = time(); }
	elsif ($timestamp == 0) { 
		return("Never"); }
	# make timestamp the time SINCE [lazy reuse of a variable]

   my (undef,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($timestamp);
	$c = Date::Calc::Date_to_Text($year+1900,$mon+1,$mday);

	if ($style==-1) {
		$c = sprintf("%4d-%02d-%02d",$year+1900,$mon+1,$mday);
		}
	elsif ($style==1)	{
		my $TZ = 'PST';
		if ($isdst) { $TZ = 'PDT'; }	
	
		## by default we assume it's always PST/PDT
		if (($style & 2) == 2) {
			my ($gmsec,$gmmin,$gmhour,$gmmday,$gmmon,$gmyear,$gmwday,$gmyday,$gmisdst) = gmtime($timestamp);
			if ($wday!=$gmwday) { $gmhour+=24; }
			$gmhour = $gmhour-$hour;		# recycle gmyday
			if ($isdst) { $gmhour++; }
			if ($gmhour==8) { if ($isdst) { $TZ = 'PDT'; } else { $TZ = 'PST'; } }
			elsif ($gmhour==7) { if ($isdst) { $TZ = 'MDT'; } else { $TZ = 'MST'; } }
			elsif ($gmhour==6) { if ($isdst) { $TZ = 'CDT'; } else { $TZ = 'CST'; } }
			elsif ($gmhour==5) { if ($isdst) { $TZ = 'EDT'; } else { $TZ = 'EST'; } }
			}
		$c .= " $hour:";
		if ($min<10) { $c .= '0'; }
		$c .= $min;
		$c .= ' '.$TZ;
		}
	elsif ($style==-2) {
		$c = strftime("%Y%m%d",localtime($timestamp));
		}
	elsif ($style==2) {
		$c = strftime("%Y%m%d %H:%M:%S",localtime($timestamp));
		}
	elsif ($style==3) {
		$c = strftime("%Y%m%d%H%M%S",localtime($timestamp));
		}
	elsif ($style==4) {
		$c = strftime("%Y-%m-%d %H:%M",localtime($timestamp));
		}
	elsif (($style==-5) || ($style == 5)) {
		$c = strftime("%m%Y",localtime($timestamp));
		}
	elsif ($style==6) {
		# GMT: 2004-10-01T18:23:17+00:00
		$c = strftime("%Y-%m-%dT%H:%M:%S+00:00",gmtime($timestamp));
		}

#					my $ts = &ZTOOLKIT::timetohash($timestamp);
#					
#					my $ampm = '';
#					if ($ts->{'hour'} < 12) {
#						if ($ts->{'hour'} == 0) { $ts->{'hour'} = '12'; }
#						$ampm = 'a';
#						}
#					else {
#						$ts->{'hour'} = ($ts->{'hour'} - 12);
#						if ($ts->{'hour'} == 0) { $ts->{'hour'} = '12'; }
#						$ampm = 'p';
#						}
#					my $hour = $ts->{'hour'} . ':' . &ZTOOLKIT::zeropad(2,$ts->{'min'}) . $ampm;
#					my $posted = ($ts->{'mon'}+1) . "/" . $ts->{'mday'} . "/" . ($ts->{'year'}+1900). "<br>" . $hour . " GMT";
#
	return($c);
}

## Usage: def($foo) ... if $foo is undef it will return blank '', otherwise $foo
## def($foo,$def1,$def2,$def3) ... if $foo is undef it will return $def1, if $def1
## is undef it will return $def2, and so on until no parameters are left and it returns blank.
sub def  { foreach (0..$#_) { defined $_[$_]                              && return $_[$_]; } return ''; }
## Same as above, but checks that the value is true in addition to being defined
sub good { foreach (0..$#_) { defined $_[$_] && $_[$_]                    && return $_[$_]; } return ''; }
## Same as above, but checks that the value is not a blank string in addition to being defined
sub gstr { foreach (0..$#_) { defined $_[$_] && ($_[$_] ne '')            && return $_[$_]; } return ''; }
## Same as above, but checks that the value is an integer number in addition to being defined (returns 0 if not found)
sub gint { foreach (0..$#_) { defined $_[$_] && ($_[$_] =~ m/^[+-]?\d+$/) && return $_[$_]; } return 0; }
## Same as above, but checks that the value is a plain positive integer number in addition to being defined (returns 0 if not found)
sub pint { foreach (0..$#_) { defined $_[$_] && ($_[$_] =~ m/^\d+$/) && return $_[$_]; } return 0; }
## Same as above, but checks that the value is a 1 or 0 in addition to being defined (returns 0 if not found)
sub bool { foreach (0..$#_) { defined $_[$_] && ($_[$_] =~ m/^[01]$/) && return $_[$_]; } return 0; }
## Same as above, but checks that the value is a decimal number in addition to being defined (returns 0 if not found)
sub gnum { foreach (0..$#_) { defined $_[$_] && ($_[$_] =~ m/^\d*\.?\d+$/) && return $_[$_]; } return 0; }
## There's a lot of places where we need a 0 if not defined, and an int if so
## this is just is just a shortcut function to save some space
sub num { return (defined($_[0]) ? int(($_[0] ne '')?$_[0]:0) : 0); }
## Trims the space off the beginning and end of a string.  If undef, returns blank
#sub trim { my ($str) = @_; return '' unless defined $str; $str =~ s/^\s+//s; $str =~ s/\s+$//s; return $str; }


###########################################################################
# PASSWORD

##############################################
# MAKE PASSWORD
# Author: AK 3/7/2001
# Description: Generates a 8 to 10 character somewhat memorable password, but probably not offensive
#    that's 1 in several million to guess
#		but it won't generate passwords like 'killdog' or 'knifekitty';
# Accepts: nuthin'
# Returns: The password, silly.
# 
sub make_password {

	my @words = qw(

		dog cat egg man top pop mac goo pin pen
		bed leg arm toe eye hat dad cap try pop
		mom gym bee tin hen wig pie pot pan pod
		peg pet pad paw lot log lap lab lug map
		mat mob ape ham web job flu ice tax fax
		can all nut max new zip fax bug men law
		key dye use tie flu buy run fly lop mop
		sat bat

		pool sent link bike work plus help pint robe flow
		roll hope jolt mint mega melt milk call mall ball
		doll hall wall bill mill sill hill blue bend book
		nook dude rule cool tool sell sale home java free
		item data page land side left face heel foot knee
		code copy fast more base page name road toad load
		tree rush food need here used sold mail call live
		read chop chip push join sort pack open next mine
		time fork moon clap jump line last dole pole mole
		seed bead good kite date king sing
	
	);
	# 
 	foreach my $a ('aa'..'zz') { push @words, $a; }

	# use the current rand as part of the seed so subsequent calls
	# in the same second by the same process don't result in the same password.
	srand( time() ^ ($$ + ($$ << 15)) * (rand()+1) );
	my $word1 = $words[int(rand(scalar(@words)))];
	my $word2 = uc($words[int(rand(scalar(@words)))]);
	my $digit1 = (int rand 8)+2;
	my $digit2 = (int rand 8)+2;
	my $format = int rand 3;
	if ($format == 0)    { return $digit1 . $digit2 . $word1 . $word2 ; }
	elsif ($format == 1) { return $word1 . $word2 . $digit1 . $digit2 ; }
	else                 { return $word1 . $digit1 . $digit2 . $word2 ; }

}

## Ripped from CUSTOMER.pm

## Turns a dotted quad (1.2.3.4) into an integer.  returns 0 on failure
sub ip_to_int
{
        my $ip = shift;
        return 0 unless defined($ip);
        my @n = split(/\./, $ip);
        foreach (0..3)
        {
                unless (
                        defined($n[$_]) &&
                        ($n[$_] =~ m/^\d+$/) &&
                        ($n[$_] < 256)
                )
                {
                        return 0;
                }
        }
        return unpack('N', pack('C4', @n));
}

## Turns an integer into a dotted quad (1.2.3.4).  returns 0.0.0.0 on failure
sub int_to_ip
{
        my $num = shift;
        return '0.0.0.0' unless defined($num);
        return '0.0.0.0' unless $num =~ m/^\d+$/;
        return '0.0.0.0' unless $num < 4294967296;
        return join('.', unpack('C4', pack('N4', $num) ) );
}

1;

