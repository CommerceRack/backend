package LISTING::XMLTOOLS;

use strict;

## strips out nasty characters which break XML::Parser
sub clean_xml {
	my ($content) = @_;

	my $x = '';
	foreach my $ch (split(//,$content)) {
		next if (ord($ch)==26);
		$x .= $ch;
		}
	return($x);
}

sub getXMLstring {
	my ($tree,$path) = @_;

	my @ar = split(/\./,$path);
	foreach $a (@ar) {
		# now looking for 
		my $done = 0;
#		print "Now looking for $a [$done]\n";
		foreach my $node (@{$tree}) {
#			print "Checking: $node->{'name'}\n";
			next if ($node->{'type'} ne 'e');
			
			next unless ($node->{'name'} eq $a);
#			print "Found $node->{'name'} == $a\n";
#			print Dumper($node);
			$done++;
			$tree = $node->{'content'};
			}	

#		print "Done is: [$done]\n";
		if ($done==0) { return(undef); }
		}

#	print Dumper($tree);
	return($tree->[0]->{'content'});

	}

sub chopXMLtree {
	my ($tree,$path) = @_;

	my @ar = split(/\./,$path);
	foreach my $a (@ar) {
		# now looking for 
		my $done = 0;
#		print "Now looking for $a [$done]\n";
		foreach my $node (@{$tree}) {
#			print "Checking: $node->{'name'}\n";
			next unless (defined $node->{'name'});
			next unless ($node->{'name'} eq $a);
#			print "Found $node->{'name'} == $a\n";
#			print Dumper($node);
			$done++;
			$tree = $node->{'content'};
			}	

#		print "Done is: [$done]\n";
		if ($done==0) { return(undef); }
		}

#	print Dumper($tree);
	return($tree);

	}

sub XMLcollapse {
	my ($arref,$ix) = @_;
	my %hash = ();
	
	if (defined $ix) { $ix = $ix.'.'; } else { $ix = ''; }
	# use Data::Dumper;
	# print STDERR Dumper($arref);
	foreach my $i (@{$arref}) {
		next if ($i->{'type'} ne 'e');
		$hash{$ix.$i->{'name'}} = $i->{'content'}->[0]->{'content'};
		if (scalar($i->{'content'})) {
			my $fooref = &XMLcollapse($i->{'content'},$ix.$i->{'name'});
			foreach my $k (keys %{$fooref}) {
				$hash{$k} = $fooref->{$k};
				}
			}
		}
	return(\%hash);
}

sub XMLcollapseOLD {
	my ($arref) = @_;
	my %hash = ();
	
	# use Data::Dumper;
	# print STDERR Dumper($arref);
	foreach my $i (@{$arref}) {
		next if ($i->{'type'} ne 'e');
		$hash{$i->{'name'}} = $i->{'content'}->[0]->{'content'};
		}
	return(\%hash);
}


##
sub stripNasty {
	my ($str) = @_;

	my $new = '';
	foreach my $ch (split(//,$str)) {
		if (ord($ch)<32) { 
			}
		elsif (ord($ch)>127) {
			}
		else {
			$new .= $ch;
			}
		}

	return($new);
}


1;
