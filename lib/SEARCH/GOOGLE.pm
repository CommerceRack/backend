package SEARCH::GOOGLE;
use XML::Parser;
use XML::Parser::EasyTree;
$XML::Parser::Easytree::Noempty=1;

use lib "/backend/lib";
require XMLTOOLS;
require ZTOOLKIT;

use Data::Dumper;


# 
use LWP::UserAgent;


#          'S' => 'IMPLEMENTED: Added second media type label for <b>FedEx Shipping</b> that contains no <br>  doc-tab, label s
#ize is 4&quot;x6&quot; and the <b>FedEx</b> supplies # is 156297. <b>...</b>',
#          'RK' => '0',
#          'HAS' => [
#                   {}
#                 ],
#          'T' => 'Zoovy Webdoc - Integrated Desktop Client v7 Release Notes',
#          'HAS.C' => undef,
#          'HAS.~SZ' => '2k',
#          'HAS.RT' => undef,
#          'HAS.~CID' => 'Aul0POAKP8UJ',
#          'Label' => '_cse_bts1i2nyxpm',
#          'UE' => 'http://webdoc.zoovy.com/doc-50959/Integrated%2520Desktop%2520Client%2520v7%2520Release%2520Notes',
#          'HAS.L' => undef,
#          'LANG' => 'en',
#          'U' => 'http://webdoc.zoovy.com/doc-50959/Integrated%20Desktop%20Client%20v7%20Release%20Notes'
 
sub search {
	my ($cx,$keywords,%options) = @_;

	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	my $hostname = &ZOOVY::servername();
	if ($hostname eq 'newdev') {
		$ua->proxy(['http'], 'http://192.168.1.126:8080');
		}

	$options{'q'} = $keywords;	
	$options{'cx'} = $cx;
	$options{'output'} = 'xml';
	$options{'client'} = 'google-csbe';
	if (not defined $options{'start'}) { $options{'start'} = 0; }
	if (not defined $options{'num'}) { $options{'num'} = 25; }

	my $url = 'http://www.google.com/search?'.&ZTOOLKIT::buildparams(\%options,0);
	print STDERR "URL: $url\n";
	my $response = $ua->get($url);

	my $xml = '';
	if ($response->is_success) {
		$xml = $response->content();
		}
	else {
		die $response->status_line;
		}

	my @results = ();

	if ($xml ne '') {
		my $p=new XML::Parser(Style=>'EasyTree');
		my $tree=$p->parse($xml);
		$tree = $tree->[0]->{'content'};
		foreach my $node (@{$tree}) {
			next if ($node->{'type'} eq 't');
			if ($node->{'name'} eq 'RES') {
				foreach my $result (@{$node->{'content'}}) {
					next if ($result->{'type'} eq 't');
					next if ($result->{'name'} eq 'NB');
					next if ($result->{'name'} eq 'M');
					next if ($result->{'name'} eq 'FI');
					next if ($result->{'name'} eq 'XT');

					my $ref = XMLTOOLS::XMLcollapse($result->{'content'});

					next if ($ref->{'T'} eq '');
					push @results, $ref;
					}
				}
			else {
				# other unsupported notes that display query parameters n' stuff
				# print Dumper($node);
				}
			}
		}

	return(\@results);
	}



1;