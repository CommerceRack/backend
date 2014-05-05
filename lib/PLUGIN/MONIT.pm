package PLUGIN::MONIT;

use strict;
use Data::Dumper;
use XML::Simple;

use lib "/backend/lib"; 
use HTTP::Tiny; 

sub status {
	my ($xml) = HTTP::Tiny->new()->get("http://127.0.0.1:2812/_status?format=xml"); 
	$xml = $xml->{'content'};

	my $xs = XML::Simple->new('ForceArray'=>1,KeyAttr=>"");
	my $ref = $xs->XMLin($xml);

	my @ROWS = ();
	foreach my $id (keys %{$ref}) {
		foreach my $line (@{$ref->{$id}}) {
			my %ROW = ( 'id'=>"$id" );
#			print Dumper($line)."\n";
			foreach my $attr (keys %{$line}) {
#				print "ATR:$attr\n";
				if (ref($line->{$attr}) eq '') {
					$ROW{$attr} = $line->{$attr};
					}
				elsif (ref($line->{$attr}->[0]) eq '') {
					$ROW{ $attr } = $line->{$attr}->[0];
					}
				elsif (ref($line->{$attr}->[0]) eq 'HASH') {
					foreach my $k (keys %{$line->{$attr}->[0]}) {
						if (ref($line->{$attr}->[0]->{$k}) eq '') {
							$ROW{"$attr/$k"} = $line->{$attr}->[0]->{$k};
							}
						elsif (ref($line->{$attr}->[0]->{$k}) eq 'ARRAY') {
							$ROW{"$attr/$k"} = $line->{$attr}->[0]->{$k}->[0];
							if (ref($ROW{"$attr/$k"}) eq 'HASH') {
								foreach my $k2 (keys %{$ROW{"$attr/$k"}}) {
									$ROW{"$attr/$k/$k2"} = $ROW{"$attr/$k"}->{$k2}->[0];
									}
								delete $ROW{"$attr/$k"};
								}
							}
						#elsif (ref($line->{$attr}->[0]->{$k}) eq 'HASH') {
						#	foreach my $k2 (keys %{$line->{$attr}->[0]->{$k}}) {
						#		$ROW{"$attr/$k/$k2"} = $line->{$attr}->[0]->{$k}->{$k2}->[0];
						#		}
						#	}
						}
					# print '.xxx.'.Dumper($attr=>$line->{$attr});
					}
	
				}
			push @ROWS, \%ROW;
			}	
		}	

	return(\@ROWS);
	}


sub print {
	print Dumper(PLUGIN::MONIT::status());
	}

1;


__DATA__


 my $hd = new Monit::HTTP(
                       hostname => '127.0.0.1',
                       port     => '2812',
                       use_auth => 0,
    #                   username => 'admin',
    #                   password => 'monit',
                       );


print Dumper($hd->_fetch_info());


my $service_status_href;

               eval {
                   my @processes = $hd->get_services();	
				
						 print Dumper(\@processes);
						 foreach my $process (@processes) {
	                   my $service_status_href = $hd->service_status($process);
							  print Dumper($service_status_href);
							
						    }
               } or do {
                       print $@;
               };

