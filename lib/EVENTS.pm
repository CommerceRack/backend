package EVENTS;





##
## syntax:
##		cmd?key1=value1&key2=value2
##		cmd@YYYYMMDDHHMMSS?key1=value1&key2=value2
##		cmd@YYYYMMDD?key1=value1&key2=value2
##
sub parse_macro {
	my ($txt) = @_;

	my @CMDS = ();

	foreach my $line (split(/[\n\r]+/,$txt)) {
		my %ref = ();
		push @CMDS, [ $ts, $api, $ref ];
		}
	

	return(\@CMDS);
	}



1;

