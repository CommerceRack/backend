package ZTOOLKIT::BARCODE;

use URI::Escape::XS;
use strict;

sub qr_url {
	}


sub code39_url {
	my ($text) = @_;

	$text = uc($text);
	$text =~ s/[^A-Z0-9\s\-\.]/ /gs;
	$text = URI::Escape::XS::uri_escape($text);

	return("/media/auto/code39/$text.png");
	}


sub code128_url {
	my ($text) = @_;

	$text = uc($text);
	$text =~ s/[^A-Z0-9\s\-\.]/ /gs;
	$text = URI::Escape::XS::uri_escape($text);

	return("/media/auto/code128/$text.png");
	}


sub ean_to_isbn {
	my ($e) = @_;

	my $i = substr($e,3);	# strip the first three digits
	$i = substr($i,0,-1);	# strip off the ean checksum
	my @digits = split(//,$i);
	my $sum = 0;
	my $x = 0;
	# print "I: $i\n";
	while ($x<=length($i)) {
	 	$sum += ($digits[$x]*($x+1));
	#	print "SUM: $sum\n";
		$x++;
		}
	$sum = $sum % 11;
	# print "SUM: $sum\n";
	if ($sum == 10) { $sum = 'X'; }

	return($i.$sum);	
	}

sub isbn_to_ean {
	my ($i) = @_;

	$i = substr($i,0,-1); 	# strip the checksum
	$i = '978'.$i;

	#Add the values of the digits in the even-numbered positions.
	my @digits = split(//,$i);
	my $x = 1;
	my $evensum = 0;
	while ($x<=length($i)) {
		$evensum += $digits[$x];
		$x = $x+2;
		}
	#Multiply the sum in Step 1 by 3.
	$evensum = $evensum * 3;
	#Add the values of the digits in the odd-numbered positions
	$x = 0;
	my $oddsum = 0;
	while ($x<=length($i)) {
		$oddsum += $digits[$x];
		$x = $x+2;
		}
	# print "ODDSUM: $oddsum\n";
	#Add the results of Step 2 with the result of Step 3.
	#Find the smallest number which, when added to the result in Step 4, produces
	#a multiple of 10. This is the checksum digit of the EAN-13 code.
	$x = 10 - (($evensum + $oddsum) % 10);
	
	# print "X: $x\n";
	return($i.$x);
}

sub is_ean {
	my ($ean) = @_;

	if (length($ean) != 13) { return(0); }		# incorrect length
	if ((substr($ean,0,3) ne '978') && (substr($ean,0,3) ne '979')) { return(0); }	 # does not contain the proper digits
	my $chksum = substr($ean,-1);
	my @digits = split(//,substr($ean,0,-1));
	my $x = 1;
	my $evensum = 0;
	while ($x<=scalar(@digits)) {
		$evensum += $digits[$x];
		$x = $x+2;
		}
	#Multiply the sum in Step 1 by 3.
	$evensum = $evensum * 3;
	#Add the values of the digits in the odd-numbered positions
	$x = 0;
	my $oddsum = 0;
	while ($x<=scalar(@digits)) {
		$oddsum += $digits[$x];
		$x = $x+2;
		}
	#Add the results of Step 2 with the result of Step 3.
	#Find the smallest number which, when added to the result in Step 4, produces
	#a multiple of 10. This is the checksum digit of the EAN-13 code.
	$x = 10 - (($evensum + $oddsum) % 10);
	if ($x == 10) { $x = '0'; }

	if (uc($x) eq uc($chksum)) { return(1); }
	return(0);
}



1;