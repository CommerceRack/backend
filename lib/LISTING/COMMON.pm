package LISTING::COMMON;

require Exporter;
@ISA = qw(Exporter); ## Adding a 'my' to this is incorrect, it actually causes the export of functions to fail.

# No functions are exported by default
@EXPORT = qw(); ## DO NOT ADD 'my'
# Allowable to be exported to foreign namespaces
@EXPORT_OK = qw(
	xml_incode
); ## DO NOT ADD 'my'
# These are the logical groupings of exported functions
%EXPORT_TAGS = ();  ## DO NOT ADD 'my'

###########################################################################
## Don't move anything from above this line below it, or vice versa!  
## Exporter variables need to be lexically scoped and strict likes to complain about them.
###########################################################################

##
## note: this is a cheap XML incode, it only does the upper 128 bytes, which is probably safe.
##
sub xml_incode {
	my ($str) = @_;

	if (not defined $str) { return undef; }
	my $new = '';
	foreach my $c (split(//,$str))
		{
		if (ord($c)<10) {
			# ignore control characters
			}
		elsif (ord($c)>=127)
			{
			# remember to translate these characters (I think they come from word)
			if (ord($c) == 146) { $new .= "'"; } 				# backwards '
			elsif (ord($c) == 147) { $new .= '"'; }			# backwards double quote
			elsif (ord($c) == 148) { $new .= '"'; } 			# forwards double quote (ext)

			elsif ($c eq '>' || $c eq '<' || $c eq '&') {
				$new .= $c; } 
			else {
				$new .= '&#'.ord($c).';';	
				}
			} 
		else {
			if ($c eq '&') { $new .= '&amp;'; } 
			elsif ($c eq '>') { $new .= '&gt;'; }
			elsif ($c eq '<') { $new .= '&lt;'; }
			elsif ($c eq '"') { $new .= '&quot;'; }
			elsif (ord($c) == 18) { $new .= ''; }
			else { $new .= $c; }
			}
		}

#	print STDERR $new."\n";

	return($new);
}


1;
