package ADVERT;

use strict;


##
##
## this program reads a directory /httpd/htdocs/biz/advertisements
##	and based on subdirectories in that directory it creates an array of urls @URLS
## then it randomizes the URLS and returns the array.
##
## the problem: 
##		with the way we push to production, new directories can be added, but old ones aren't removed.
##		jt would prefer that we use the file active_sync_ads.txt in the /httpd/htdocs/biz/advertisements
##		to get the list of ad's we should be showing.  This lets him move promotions in and out, without
##		actually needing to remove directories.
##
##	perl -e 'use lib "/backend/lib"; use ADVERT; use Data::Dumper; print Dumper(ADVERT::retrieve_urls);'
##
sub retrieve_urls {
	my ($USERNAME,$FLAGS,$count) = @_;

	my @URLS = ();
	open F, "</httpd/htdocs/biz/advertisements/active_sync_ads.txt";
	while (<F>) {
		my ($line) = $_;
		$line =~ s/[\n\r]+//g;
		next if ($line eq '');
		next if (substr($line,0,1) eq '#');  ## skip lines that start with a #
		next unless (-f '/httpd/htdocs/biz/advertisements/'.$line.'/index.html');
		push @URLS, '//www.zoovy.com/biz/advertisements/'.$line.'/index.html';
		}
	close F;

## old read from directory code:
#	my $D = undef;
#	opendir $D, "/httpd/htdocs/biz/advertisements";
#	while (my $file = readdir($D)) {
#		next if (substr($file,0,1) eq '.');
#		next if (! -d "/httpd/htdocs/biz/advertisements/$file");
#		
#		push @URLS, 'http://www.zoovy.com/biz/advertisements/'.$file.'/index.html';
#		}
#	closedir $D;	

	## randomize the array!
	my $cnt = scalar(@URLS);
	srand(time()*$$);
	for (my $pos=0; $pos < $cnt; $pos++) {
		my $rndpos = int(rand()*$$)%$cnt;
		my $tmp = $URLS[$rndpos];
		$URLS[$rndpos] = $URLS[$pos];
		$URLS[$pos] = $tmp;
		}

	return(@URLS);
	}

1;