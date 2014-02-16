package ZTOOLKIT::CURRENCY;

use File::Slurp;
use strict;

$ZTOOLKIT::CURRENCY::RATES = undef;


##
## to add new currencies: 
##
# mysql ZOOVY -e "insert into CURRENCIES values ('YEN',0,0);"
# perl -e 'use lib "/backend/lib"; use ZTOOLKIT::CURRENCY; ZTOOLKIT::CURRENCY::updateCurrencyTb();'
#

##
## this converts from us dollars to any amount.
##
sub convert {
	my ($amount,$fromcurrency,$tocurrency) = @_;

	$tocurrency = uc($tocurrency);
	$fromcurrency = uc($fromcurrency);

	if (($fromcurrency ne 'USD') && ($tocurrency ne 'USD')) {
		die("From NON-USD to NON-USD Not supported (YET)");
		}
	elsif (($fromcurrency ne 'USD') && ($tocurrency eq 'USD')) {
		## from non-US to USD
		my $result = getCachedExchangeRates();
		if (defined $result->{ $fromcurrency }) {
			my $rate = $result->{ $fromcurrency };
			$amount = $amount / $rate;
			}
		else {
			$amount = 0;
			}
		
		}
	elsif (($fromcurrency eq 'USD') && ($tocurrency ne 'USD')) {
		## from USD to non-USD 
		my $result = getCachedExchangeRates();
		if (defined $result->{ $tocurrency }) {
			my $rate = $result->{ $tocurrency };
			$amount = $amount * $rate;
			}
		else {
			$amount = 0;
			}
		}
	else {
		## USD to USD?
		warn "attempted USD to USD currency conversion";
		}

#		if ($tocurrency eq 'CAD') { $amount = $amount * 0.50; }
#		elsif ($tocurrency eq 'EUR') { $amount = $amount * 2; }
	
	return($amount);
	}


##
## NOTE:  this asssumes amount has already been converted from USD
##
sub format {
	my ($amount, $currency) = @_;

	if ($currency eq '') { $currency = 'USD'; }
	$currency = uc($currency);

	my $is_negative = ($amount<0)?1:0;
	if ($is_negative) {
		$amount = 0 - $amount;	# make it positive since the negative will come before currency. e.g. -$1.00
		}

	$amount = sprintf("%.2f",$amount);	## round down to two decimal places.
	$amount = reverse $amount;
	$amount =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;	## add commas
	$amount = scalar reverse $amount;

	if ($currency eq 'USD') {
		$amount = '&#36;'.$amount;				## add dollar sign
		}
	elsif ($currency eq 'EUR') {
		$amount = '&euro;'.$amount;
		}
	elsif ($currency eq 'CAD') {
		$amount = '$'.$amount;
		}
	elsif ($currency eq 'GBP') {
		## british pound
		$amount = '&pound;'.$amount;
		}
	elsif ($currency eq 'JPY') {
		## japanese yen!~
		$amount = '&#165;'.$amount;
		}
	elsif ($currency eq 'MXN') {
		## mexico peso
		$amount = '$'.$amount;
		}
	elsif ($currency eq 'AUD') {
		## australian dollar
		$amount = '$'.$amount;
		}
	elsif ($currency eq 'KRW') {
		## australian dollar
		$amount = '&#8361;'.$amount;
		}
	else {
		## Unknown currency!
		}

	if ($is_negative) {
		$amount = "-$amount";
		}

	return($amount);
	}


sub cacheExchangeRates {
	my $file = '/dev/shm/currencies.json';

	my $result = {};
	require File::Copy;
	if (-f "/mnt/configs/resources/currencies.json") {
		File::Copy::copy("/mnt/configs/resources/currencies.json",$file);
		}

	if (! -f $file) {
		require HTTP::Tiny;
		my $response = HTTP::Tiny->new()->get("http://s3-us-west-1.amazonaws.com/commercerack-configs/resources/currencies.json");
		use Data::Dumper; print Dumper($response);
		if ($response->{'content'} =~ /^{/) {
			open F, ">$file";
			print F $response->{'content'};
			close F;
			}
		}

	chmod(0666, $file);
	chown($ZOOVY::EUID,$ZOOVY::EGID, $file);
	return($result);
	}



##
## returns a hashref of 
##		{
##		'EUR'=>{ rate=>0.64, ts=>timestamp },
##		}
##
sub getCachedExchangeRates {

	my $file = '/dev/shm/currencies.json';
	my $exists = 0;
	if (-f $file) { $exists = 1; }

	my $result = undef;
	if ($exists) {
		my $json = File::Slurp::read_file( $file ) ;
		$result = JSON::XS::decode_json($json);
		}
	else {
		$result = cacheExchangeRates();
		}
	
	return($result);
	}



##
## round up to the "upto" value
##
sub roundup {
  my ($price,$upto) = @_;

  return $price if $price == 0;

  my $diff = (100 - int($upto)) / 100;
  return(sprintf("%.2f",ceil($price+$diff)-$diff));
  }

##
## round up by a certain number e.g. 5
## so 113.13 becomes 113.15
##
sub roundby {
  my ($price,$by) = @_;

  return $price if $price == 0;

  if ($by == 0) { return($price); }
  $price = $price * 100;
  if (($price % $by) > 0) {
    $price = $price + ($by - ($price % $by));
    }
  return(sprintf("%.2f",$price / 100));
  }


1;