#!/usr/bin/perl

use lib "/httpd/modules";
use ZOOVY;
use Data::Dumper;
use Storable;

foreach my $int (@ZOOVY::INTEGRATIONS) {
	my $dir = sprintf("/httpd/static/syndication/%s",$int->{'dst'});
	my $dmpfile = sprintf("%s/mapping.dmp",$dir);
	my $binfile = sprintf("%s/mapping.bin",$dir);

	if (! -d $dir) {
		## directoy does not exist
		}
	elsif (! -f $dmpfile) {
		}
	else {
		open F, $dmpfile;
		my $data = ''; 
		while (<F>) { 
			next if ($_ =~ /^[\s]*#/);	 #skip comments in file
			$data .= $_; 
			} 
		close F;
	
		# print $data;
		my $VAR1 = eval("$data;");
		# print Dumper($VAR1);

		Storable::nstore $VAR1, $binfile;
		chmod 0444, $file;
		print "$binfile -> \${HOSTS} install;\n";
		print "$dmpfile -> \${HOSTS} install;\n";
		}

	}

