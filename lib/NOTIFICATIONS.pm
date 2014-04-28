package NOTIFICATIONS;

use strict;


@NOTIFICATIONS::OBJECTS = (
	'MARKET',
	'PRODUCT',
	'ORDER',
	'CUSTOMER',
	'SUPPLIER',
	'INVENTORY',
	'APP',
	'API',
	'ERROR',
	'ALERT',
	);

@NOTIFICATIONS::DEFAULTS = (
	[ 'APP.ENQUIRY'=>['verb=task'] ],
#	{ 'ERROR'=>['verb=task'] },
#	{ 'ALERT'=>['verb=task'] },
#	{ 'APIERR'=>['verb=task'] },
	[ 'CUSTOMER.ORDER.CANCEL'=>['verb=task'] ],
	[ 'INVENTORY.NAVCAT.SHOW'=>['verb=task'] ],
	[ 'INVENTORY.NAVCAT.HIDE'=>['verb=task'] ],
	[ 'INVENTORY.NAVCAT.FAIL'=>['verb=task'] ],
	);


##
##
##
sub list {
	my ($webdbref) = @_;

	my @EVENTS = ();
	if (not defined $webdbref->{'%NOTIFICATIONS'}) { $webdbref->{"%NOTIFICATIONS"} = {}; }
	foreach my $row (@NOTIFICATION::DEFAULTS) {
		my ($EVENTID, $CMDROWS) = @{$row};
		if (not defined $webdbref->{'%NOTIFICATIONS'}->{$EVENTID}) {
			$webdbref->{'%NOTIFICATIONS'}->{$EVENTID} = $CMDROWS;
			}
		}

	foreach my $EVENTID (sort keys %{$webdbref->{'%NOTIFICATIONS'}}) {	
		print STDERR "EVENTID: $EVENTID\n";
		my %EVENT = ();
		$EVENT{'event'} = $EVENTID;
		my @CMDS = ();
		$EVENT{'@VERBS'} = \@CMDS;
		foreach my $ROWSTR (@{$webdbref->{'%NOTIFICATIONS'}->{$EVENTID}}) {
			my $ref = &ZTOOLKIT::parseparams($ROWSTR);
			push @CMDS, $ref;
			}
		push @EVENTS, \%EVENT;
		}

	return(\@EVENTS);
	}


##
##
##
sub find {
	my ($webdbref,$path) = @_;

	my @TOKENS = split(/\./,$path);
	my $match = undef;
	while ( (not defined $match) && ( scalar(@TOKENS)>0 ) ) {
		my $try = join('.',@TOKENS);
		if (defined $webdbref->{'%NOTIFICATIONS'}->{$try}) {
			$match = $try;
			}
		if (defined $webdbref->{'%NOTIFICATIONS'}->{"$try.*"}) {
			$match = $try;
			}
		pop @TOKENS;
  		} 
	return($match);
	}


1;

