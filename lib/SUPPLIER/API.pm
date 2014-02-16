package SUPPLIER::API;

use lib "/backend/lib";
require SUPPLIER;

use URI::Split;
use LWP::Simple;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP::UserAgent;
use LWP::Simple;
use Data::Dumper;
use strict;

##
## SUPPLIER::API is the methods for interacting with a supplier of type API
##
##



##
## parameters:
##   USERNAME, ORDERID, MERCHANTREF (reference to merchant namespace),
## 
## returns: ERROR,MESSAGE
##		0 on success
##		1 on smart recovery failure
##		2 on response of text/error
##		3 received unknown response
##
#sub post {	
#	my ($URL,$VARS) = @_;
#
#	print STDERR "VARS \n".Dumper($VARS);
#	my $error = 0;
#	my $STATUS = '';
#
#	## parse the API scheme, and substitute any %orderid% in the path
#	my ($scheme, $auth, $path, $query, $frag) = URI::Split::uri_split($URL);
#	$path =~ s/%orderid%/$VARS->{'OrderID'}/ig;
#
#	print STDERR "SCHEME: $scheme\n";
#
#	if (($scheme eq 'http') || ($scheme eq 'https')) {
#	
#		my $agent = new LWP::UserAgent;
#		# $agent->timeout(60);
#		$agent->timeout(15);
#
#		## NOTE: this proxy is dead. not sure if one is still needed for dev. (doubt it)
#		# $agent->proxy(['http', 'ftp'], 'http://63.108.93.10:8080/');
#		my $result = $agent->request(POST $URL, $VARS);
#	
#		## non 200 OK results
#		if ($result->code() ne '200') {
#			$error = $result->code();
#			$STATUS = $result->content();
#	
#			## Shipping API's will return an error like this:
#			if ($STATUS =~ /<ERROR>(.*?)<\/ERROR>/) {
#				$error = 1; $STATUS = $1;
#				}
#	
#			}
#		}
#	elsif ($scheme eq 'ftp') {
#		my ($user,$pass,$host) = split(/[:\@]/,$auth);
#		require Net::FTP;
#		my $ftp = Net::FTP->new("$host", Debug => 1);
#		if ((not $error) && (defined $ftp)) {
#			print STDERR "USER[$user] PASS[$pass] HOST[$host]\n";
#			$ftp->login($user,$pass) or $error = "FTP error! could not login";
#			}
#		if ((defined $ftp) && (not $error)) {
#			$ftp->ascii();
#			require IO::Scalar;
#			my $SH = IO::Scalar->new(\$VARS->{'Contents'});
#			print STDERR "PATH[$path]\n";
#			$ftp->put($SH,"$path") or $error = "FTP error! could not upload file";
#			$ftp->quit();
#			}
#		
#		}
#	else {
#		warn("Unknown API protocol scheme: $scheme");
#		}
#
##	print STDERR "STATUS: $STATUS\n";
#	return($error,$STATUS);
#	}



#### NOT IN USE 2012-06-09
##
## NOTE: this has got a spiffy clone cart function! 
##	 	-- note if SUPPLIERCODE==EBAY then we were probably called from SUPPLIER::EBAY
##
## NOTE: this is also used by SUPPLIER::ATLAST
#sub compute_shipping {
#	my ($USERNAME,$SUPPLIERCODE,$CART) = @_;
#
#	my @m = ();
#	my %meta = ();
#
#	my ($URL,$APIVERSION) = ('',0);
#	if ($SUPPLIERCODE eq 'EBAY') {
#		$URL = "http://ebaycheckout.zoovy.com/shipapi2.cgi";
#		$APIVERSION = 1;
#		}
#	else {
#		my ($S) = SUPPLIER->new($USERNAME,$SUPPLIERCODE);
#		$URL = $S->fetch_property('.api.shipurl');
#		$APIVERSION = $S->fetch_property('.api.version');
#		}
#
#	if ($URL eq '') {
#		##
#      ## NO URL SPECIFIED: default and use store shipping.
#		##
#		my %preserve_virtuals = ();
#      foreach my $item ($CART->stuff()->as_array()) {
#			$preserve_virtuals{ $item->{'stid'} } = $item->{'virtual'};
#         delete $item->{'virtual'};
#         delete $item->{'%attribs'}->{'zoovy:virtual'};
#         }
#		@m = @{$shipresults};
#
#      foreach my $item ($CART->stuff()->as_array()) {
#			my $virtual = $preserve_virtuals{ $item->{'stid'} };
#			$item->{'virtual'} = $virtual;
#			$item->{'%attribs'}->{'zoovy:virtual'} = $virtual;
#         }
#		}
#	else {
#
#		my %vars = ( 'Method'=>'ShipQuote' );
#
#		if ($APIVERSION==1) {
#			require ORDER;
#			my ($O) = ORDER->create($USERNAME,'tmp'=>1,cart=>$CART);
#			$vars{'Contents'} = $O->as_xml();
#			}
#		elsif ($APIVERSION==4) {
#			require ORDER;
#			my ($O) = ORDER->create($USERNAME,'tmp'=>1,cart=>$CART);
#			require ORDER::XCBL;
#			$vars{'Contents'} = ORDER::XCBL::as_xcbl($O);						
#			}
#		elsif ($APIVERSION==108) {
#			require ORDER;
#			my ($O) = ORDER->create($USERNAME,'tmp'=>1,cart=>$CART);
#			$vars{'Contents'} = $O->as_xml(108);
#			}
#
#		my ($err,$content) = &SUPPLIER::API::post($URL, \%vars);
#
#		# <SHIPQUOTE><METHOD NAME="UPS. BOXES: 1" PRICE="12.03"/></SHIPQUOTE>
#
#		if ($err!=0) {
#			$meta{'ERROR'} = $err;
#			push @m, &ZSHIP::build_shipmethod_row( 'API Error', 0, carrier=>'ERR', api_err_code=>$1 );
#			}
#		else {
#
#			## Strip off <SHIPQUOTE> .. </SHIPQUOTE> tags so we don't confuse the split
#			if ($content =~ /<SHIPQUOTE.*?>(.*?)<\/SHIPQUOTE>/) {	$content = $1; }
#
#
#			foreach my $shipper (split /\<\/METHOD\>/,$content) {
#				$shipper =~ s/[\n\r]+//gs;
#				next if ($shipper eq '');
#				my $id = '';
#				my $name = '';
#				my $price = '';
#				my $carrier = 'SLOW';
#				if ($shipper =~ />(.*?)$/) { $name = $1; }
#				$shipper =~ s/\>.*//;
#	
#				# use the ID whenever possible, since it doesn't have the shipping price included
#				if ($shipper =~ m/ID=\"(.*?)\"/) { $id = $1; }
#				elsif ($shipper =~ m/NAME=\"(.*?)\"/) { $name = $1; }
#
#				if (($id eq '') && ($name ne '')) { $id = $name; }
#				if (($name eq '') && ($id ne '')) { $name = $id; }
#
#				if ($shipper =~ m/VALUE=\"(.*?)\"/) { $price = $1; }
#				elsif ($shipper =~ m/PRICE=\"(.*?)\"/) { $price = $1; }
#
#				if ($shipper =~ m/HANDLING=\"(.*?)\"/) { $price += $1; $meta{'VIRTUAL_HANDLING'} = $1 }
#				if ($shipper =~ m/INSURANCE=\"(.*?)\"/) { $price += $1; $meta{'VIRTUAL_INSURANCE'} = $1 }
#
#				if ($shipper =~ m/CARRIER=\"(.*?)\"/) { $carrier = $1; }
#				next if (($id eq '') || ($price eq ''));
#
#				push @m, &ZSHIP::build_shipmethod_row( $name, $price, id=>$id, carrier=>$carrier );
#				}
#			}		
#		}
#
#	return(\@m,\%meta);
#	}


##
## this returns a hash keyed by SKU with value as the value.
##		it returns -1 for each sku which is not found/in stock.
##	STORE = USERNAME for reseller
## SUPPLIERCODE = supply chain code for SUPPLIER
## SKUREF = skuref for the reseller
#sub fetch_inventory {
#	my ($USERNAME,$SUPPLIERCODE,$SKUREF) = @_;
#
#	#my ($S) = SUPPLIER->new($USERNAME,$SUPPLIERCODE);
#	#if (not defined $S) { return(undef); }
#
#	## we'll create a temporary webdb with the two values we need (INVENTORY.pm was designed poorly)
#	#@my %tmpwebdb = ( 'inv_source'=>1, 'inv_api_url'=> $S->fetch_property('.api.invurl') );
#	#return(&INVENTORY::api_fetch($USERNAME,$SKUREF,\%tmpwebdb));
#	}



1;

