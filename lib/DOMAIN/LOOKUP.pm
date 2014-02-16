#
# this has the ability to lookup config.domain.com records to determine which cluster
#

package DOMAIN::LOOKUP;

use strict;

use Data::Dumper;
use Net::DNS;

sub info {
	my ($DOMAIN) = @_;

	my $response = ();

	my $res   = Net::DNS::Resolver->new(nameservers => ['208.74.184.18']);

	# my $res   = Net::DNS::Resolver->new;
	my $query = $res->query(sprintf('config.%s',$DOMAIN),'TXT');
	# print Dumper($query);
	if ($query) {
		foreach my $rr (grep { $_->type eq 'TXT' } $query->answer) {
			$response->{'txt'} .= sprintf("%s\n",$rr->txtdata);
			foreach my $kvpair (split(/[;\s]+/,$rr->txtdata)) {
				my ($k,$v) = split(/=/,$kvpair,2);
				$response->{uc($k)} = $v;
				}
         }
		chomp($response->{'txt'}); # remove trailing cr/lf
		}
	else {
		warn "query failed: ", $res->errorstring, "\n";
		$response->{'err'} = $res->errorstring();
		}

	return($response);
	}

1;
