package WATCHER::AMAZON;

use Data::Dumper;
#use DIME::Parser;
use XML::Parser;
use XML::Parser::EasyTree;
use XML::Writer;
use LWP::UserAgent;
use HTML::Parser;

use lib "/backend/lib";
require ZOOVY;
require SYNDICATION;
require XMLTOOLS;
require ZTOOLKIT;
require AMAZON3;

use strict;


##
##
##
sub verify {
	my ($w,$SKU,$ASIN) = @_;

	my $MID = $w->mid();
	$ASIN =~ s/^[\s]+//gs;	# strip leading space
	$ASIN =~ s/[\s]+$//gs;	# strip trailing space

	my ($ERROR,$HTML,@ELEMENTS) = (undef,undef,());
	
	if (not defined $ERROR) {
		if ($ASIN eq '') { $ERROR = 'Product ASIN not set'; }
		elsif ($SKU eq '') { $ERROR = 'Product SKU not set'; }
		}

	if (not defined $ERROR) {
		## phase1: get the html
		my $URL = "http://www.amazon.com/gp/offer-listing/$ASIN/ref=old_seeall_fm";
		($ERROR,$HTML) = $w->get($URL);
		}

	if (not defined $ERROR) {
		## phase2: parse it.
		(@ELEMENTS) = @{&scrape($HTML)};
		if (scalar(@ELEMENTS)==0) {
			## this means nobody is selling the product
			$ERROR = "No valid pricing elements found during scrape (product is not for sale!?)";
			}
		else {
			## these are the required fields for this element to be considered VALID
			my @REQUIRED_KEYS = ('price','shipping','seller','sellerid','rating');
			foreach my $e (@ELEMENTS) {
				my $has_errors = 0;
				foreach my $k (@REQUIRED_KEYS) {
					if ((not defined $e->{$k}) || ($e->{$k} eq '')) { 
						$has_errors++; 
						push @{$e->{'@missing'}}, $k;
						}
					}
				$e->{'errors'} = $has_errors;
				if (not $has_errors) {
					## yay, it's complete. we can remove debug keys ex: _tr and _availability
					foreach my $k (keys %{$e}) {
						next if ($e->{'_debug'});	# tells me to keep the keys!
						if (substr($k,0,1) eq '_') { delete $e->{$k}; }
						}
					}
				if (not $e->{'errors'}) {
					$e->{'delivered_price'} = $e->{'price'} + $e->{'shipping'};
					}
				}
			## SANITY: at this point each element has 'errors' set or it's good to go.
			}
		}


	return($ERROR,\@ELEMENTS);
	}


##
##
##
sub update_price {
	my ($w,$SKU,$PRICE) = @_;

	my $USERNAME = $w->username();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
#	my $pstmt = "select PRT from AMAZON_FEEDS where MID=$MID /* $USERNAME */ and (FEED_PERMISSIONS&1)>0";
#	my ($PRT) = $udbh->selectrow_array($pstmt);
#	my ($userref) = &AMAZON3::fetch_userprt($USERNAME,$PRT);

	## switched fetch_merchants to key off username/prt vs just username
	# my $PROFILE = 'DEFAULT';
	# my ($so) = SYNDICATION->new($USERNAME,$PROFILE,'AMZ');
	my ($userref) = &AMAZON3::fetch_userprt($USERNAME);
	my $PRT = $userref->{'PRT'};

	my $ERROR = undef;
	## SKIP MERCHANT for the following reasons
	##	 Cancelled Merchant
	if ($userref->{'MID'} == '-1') { $ERROR = "Invalid username"; }
	## Invalid Password
	if ($userref->{'PASSWORD'} eq '') { $ERROR = "Invalid password"; }
	## Invalid UserID/Login
	if (($userref->{'USERID'} eq '') || 
		ZTOOLKIT::validate_email($userref->{'USERID'})==0) { $ERROR = "Invalid userid/login";	}

	print STDERR "Token: ".$userref->{'AMAZON_TOKEN'}."\n\n";
	## Invalid Token
	if ($userref->{'AMAZON_TOKEN'} !~ /^M_/) { $ERROR = "Invalid Token"; }

	my @MESSAGES = ();
		
	if (not defined $ERROR) {
		my $XML = '';
		my $writer = new XML::Writer(OUTPUT => \$XML, DATA_MODE => 1, DATA_INDENT => 4, ENCODING => 'utf-8');
		$writer->startTag('Message');
			$writer->dataElement( 'MessageID', scalar(@MESSAGES)+1 );
			$writer->startTag('Price');
				$writer->dataElement('SKU',$SKU);
				$writer->dataElement('StandardPrice',sprintf("%.2f",$PRICE),'currency'=>"USD");
			$writer->endTag('Price');
		$writer->endTag('Message');
		$writer->end();
		push @MESSAGES, $XML;
		}

	## if there's data     
	my ($docid,$error);
	if (scalar(@MESSAGES)) {
		($docid,$error) = push_xml($userref,join("\n",@MESSAGES),'Price','_POST_PRODUCT_PRICING_DATA_');
		print STDERR "DOCID: $docid\n";
		}

	&DBINFO::db_user_close();
	return($docid);
	}


##
##
##
sub push_xml {
	my ($userref,$xml,$type,$post) = @_;

	my $docid = 0;
	my $error = "default (unknown) error";

	($xml) = &addenvelope($userref,$type,$xml);
	$xml =~ s/^<\?(.*)\?>$//mg;

	my $USERNAME = $userref->{'USERNAME'};
	
	## Amazon's servers aren't handling the load well
	## 	some requests are erroring even though the credentials are valid
	## 	-- seeing if a retry works
	my $retries = 5;
	while ($retries && $docid == 0) {
		($docid,$error) = &postDocument($userref,$post,$xml);

		## retry if Authorization Required is returned or 500 SSL read timeout/read failed
		if ($docid>0) {
			}
		elsif ($error eq '401 Authorization Required' || $error =~ /^500 /) {
			print STDERR "Retrying due to '401 Authorization Required' or '500 ' error: $USERNAME $type\n";
			sleep($retries);
			}
		else {
			## other unknown error
			$error = "unhandled error in push_xml";
			}
		$retries--;
		}

	## copy DOCID to /httpd/servers/amazon/docids_500 or docids_401 if error still exists
	## (even after retrying feed 5 times)
	if ($error) {
		warn "ERROR: $error\n";
		}

	return($docid, $error);
	}


#######################################################################
##
## sends a file to amazon
##
sub postDocument {
	my ($userref,$msgtype,$xmldoc) = @_;
	my $error = '';
	
	my $MID = $userref->{'MID'};
	my $USERNAME = $userref->{'USERNAME'};
	my $AMZ_MERCHANT = $userref->{'AMAZON_MERCHANT'};
	my $AMZ_USER = $userref->{'USERID'};
	my $AMZ_PASS = $userref->{'PASSWORD'};
	my $AMZ_TOKEN = $userref->{'AMAZON_TOKEN'};
	
	$AMZ_MERCHANT =~ s/\&/and/g;

	if ($::PRODUCTION == 0) { $AMZ_PASS = 'amazon'; }

	my $ug = new Data::UUID; 
	my $envuuid = $ug->to_string( $ug->create() );

	my $payload2 = new DIME::Payload(1);
	$payload2->attach( Data =>\$xmldoc, MSCompat=>1, MIMEType => 'text/xml', Dynamic=>0 );
	my $payuuid = $payload2->id();

	my $URL = "https://merchant-api.amazon.com/gateway/merchant-interface-dime";
	#if ($::PRODUCTION) { $URL = "http://merchant-api.amazon.com/gateway/merchant-interface-dime"; }

	my $env = qq~<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" 
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/03/addressing" 
xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" 
xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
<soap:Header>
	<wsa:Action>http://www.amazon.com/merchants/merchant-interface/MerchantInterface#postDocument#KEx3YXNwY1NlcnZlci9BbXpJU0EvTWVyY2hhbnQ7TGphdmEvbGFuZy9TdHJpbmc7TG9yZy9pZG9veC93YXNwL3R5cGVzL1JlcXVlc3RNZXNzYWdlQXR0YWNobWVudDspTHdhc3BjU2VydmVyL0FteklTQS9Eb2N1bWVudFN1Ym1pc3Npb25SZXNwb25zZTs=</wsa:Action>
	<wsa:MessageID>uuid:$envuuid</wsa:MessageID>
	<wsa:ReplyTo><wsa:Address>http://schemas.xmlsoap.org/ws/2004/03/addressing/role/anonymous</wsa:Address></wsa:ReplyTo>
	<wsa:To>$URL</wsa:To>
	<wsse:Security>
		<wsu:Timestamp wsu:Id="Timestamp-4cb8e37e-37fb-4036-9687-961f0ad62f50">
		<wsu:Created>2005-08-12T04:08:15Z</wsu:Created>
		<wsu:Expires>2005-08-13T04:13:15Z</wsu:Expires>
		</wsu:Timestamp>
	</wsse:Security>
	</soap:Header>
	<soap:Body>
	<merchant xmlns="http://systinet.com/xsd/SchemaTypes/">
	<merchantIdentifier xmlns="http://www.amazon.com/merchants/merchant-interface/">$AMZ_TOKEN</merchantIdentifier>
	<merchantName xmlns="http://www.amazon.com/merchants/merchant-interface/">$AMZ_MERCHANT</merchantName>
</merchant>
<messageType xmlns="http://systinet.com/xsd/SchemaTypes/">$msgtype</messageType>
<doc d3p1:location="$payuuid" xmlns:d3p1="http://schemas.xmlsoap.org/ws/2002/04/reference/" xmlns="http://systinet.com/xsd/SchemaTypes/" />
</soap:Body>
</soap:Envelope>~;


#print STDERR $env."\n";

	my $payload = new DIME::Payload(0);
	$payload->attach(URIType=>'http://schemas.xmlsoap.org/soap/envelope/',Data=>\$env);
	my $message = new DIME::Message;

	$message->add_payload($payload);
	$message->add_payload($payload2);

	# Print the encoded message to STDOUT
	my $str = ${$message->print_data()};

	my $agent = new LWP::UserAgent;
	$agent->agent('Groovy/1.0');
	 
	my $head = HTTP::Headers->new();
	$head->header(SOAPAction=>'"http://www.amazon.com/merchants/merchant-interface/MerchantInterface#postDocument#KEx3YXNwY1NlcnZlci9BbXpJU0EvTWVyY2hhbnQ7TGphdmEvbGFuZy9TdHJpbmc7TG9yZy9pZG9veC93YXNwL3R5cGVzL1JlcXVlc3RNZXNzYWdlQXR0YWNobWVudDspTHdhc3BjU2VydmVyL0FteklTQS9Eb2N1bWVudFN1Ym1pc3Npb25SZXNwb25zZTs="');
	$head->header('Content-Type'=>'application/dime');
	$head->header('Expect','100-continue');
	$head->header('Host','merchant-api.amazon.com');
	if ($::PRODUCTION) { $head->header('Host','merchant-api.amazon.com'); }
	$head->header('Content-Length'=>length($str));

	my $request = HTTP::Request->new('POST',$URL,$head,$str);
	#$agent->credentials('merchant-api.amazon.com:80','/gateway/merchant-interface-dime',$AMZ_USER=>$AMZ_PASS);
	$agent->credentials('merchant-api.amazon.com:443','/gateway/merchant-interface-dime',$AMZ_USER=>$AMZ_PASS);
	my $response = $agent->request($request);

	use Data::Dumper;
	# print STDERR "$AMZ_USER $AMZ_PASS \n\nSTRING: $str\n\nURL: $URL\n\nhead: ".Dumper($head)."\n".Dumper($response)."\n\n\n";
	

	my $docid = -1;
	if ($response->is_success()) {
		$docid = 0;
#<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SE="http://schemas.xmlsoap.org/soap/encoding/">
#	<SOAP-ENV:Body>
#		<ns1:DocumentSubmissionResponse_Response xsi:type="ns0:DocumentSubmissionResponse" xmlns:ns0="http://www.amazon.com/merchants/merchant-interface/" xmlns:ns1="http://systinet.com/xsd/SchemaTypes/">
#		<ns0:documentTransactionID xsi:type="xsd:long">195954323</ns0:documentTransactionID>
#		</ns1:DocumentSubmissionResponse_Response>
#	</SOAP-ENV:Body>
#</SOAP-ENV:Envelope>
		if ($response->content() =~ /documentTransactionID.*?\>([\d]+)\</s) { $docid = $1; }
		# <ns0:documentTransactionID xsi:type="xsd:long">
		my $FILENAME = "/tmp/amz-$docid.xml";
		open F, ">$FILENAME";
		print F Dumper($xmldoc,$response->content());
		close F;
		}
	else {
		$error = $response->status_line;
		open F, ">>/tmp/amz-errors.$USERNAME.xml";
		use Data::Dumper; 
		print F "ERROR: $error\nREQUEST: ".Dumper($request)."\nRESPONSE: ".Dumper($response)."USER: $AMZ_USER PASS: $AMZ_PASS\n\n";
		close F;
		}


	return($docid,$error);
	}


##
##
## pass this the <Message>....</Message> document.
##
sub addenvelope {
	my ($userref,$msgtype,$msgsxml) = @_;

	if ($msgtype eq '') { warn 'No msgtype passed to AMAZON::TRANSPORT::addenvelope - return undef'; return(undef); }
	elsif ($msgsxml eq '') { warn 'Msgsxml passed to AMAZON::TRANSPORT::addenvelope - return undef'; return(undef); }
	
	my $TOKEN = $userref->{'AMAZON_TOKEN'};
	#if ($TOKEN =~ /^Q_/) { $::PRODUCTION = 0; }

	my $xml = qq~<?xml version="1.0" ?>
<AmazonEnvelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="amzn-envelope.xsd">
<Header>
	<DocumentVersion>1.01</DocumentVersion>
	<MerchantIdentifier>$TOKEN</MerchantIdentifier>
</Header>
<MessageType>$msgtype</MessageType> 
$msgsxml
</AmazonEnvelope>
~;

	return($xml);
	}





## 
## this function parses through the html and returns an array of prices
##		[
##		{
##		'price'=>'','shipping'=>'',
##		'rating'=>'',
##		'instock'=>1|0,expedited=>1|0,
##		'ratings'=>####,
##		'condition'=>'New',
##		'sellerid'=>'15digitamazonid',
##		'seller'=>'Case Sensitive Merchant Name',
##		'errors'=>1	# if an error was encountered
##		'is_fba'=>1,	#self explanatory
##		}
##		]
##	
##	if an error is encountered during parsing the following fields might be set:
##		error=>1|0
##		_tagreference -- (these are normally discarded, but if we have an error we keep them around for diagnostics)
##		@missing=>[ 'seller','sellerid' ] -- this will be set if one or more required attributes are missing
##
sub scrape {
	my ($HTML) = @_;

	my $ERROR = undef;
	my @ELEMENTS = ();

#	use Marpa::HTML;
#	my $result = Marpa::HTML::html(\$HTML);
	
	use HTML::TreeBuilder;
	my $tree = HTML::TreeBuilder->new; # empty tree
	my $result = $tree->parse($HTML);

	## the rows for each seller seem to appear within a div class="resultsset"
	my @rows = $tree->look_down('class','resultsset');
	foreach my $row (@rows) {
		my @trs = $row->look_down('_tag','tr');
	
#		open F, ">/tmp/out"; print F Dumper(scalar(@results)); close F;
		foreach my $tr (@trs) {
			next if ($tr->look_down('class','buckettitle'));
			next if ($tr->look_down('_tag','th'));
			# <div id="af-div"
			next if ($tr->look_down('id','af-div'));

			my %info = ();		## is the hash we're going to return about this particular seller
									## we'll push this onto @ELEMENTS later.


			## _tr starts with a _ which means it's a debug key, it will be discarded (for readability) if no errors are encountered
			##	however if an error is found - then it will be preserved (for posterity)
			$info{'_tr'} = $tr->as_HTML();

			my $v = undef;	# just a temp variable.

			# <span class="price">$149.15</span>
			# <span class="price">$999.00</span>
			$v = $tr->look_down('class','price');
			if ($v) { $info{'price'} = $v->as_text(); }
			if (defined $info{'price'}) {	
				$info{'price'} =~ s/[^\d\.]+//gs;	# strip $ and spaces
				}

			# <span class="price_shipping">+ $0.00</span>
			$v = $tr->look_down('class','price_shipping'); 
			if ($v) { $info{'shipping'} = $v->as_text(); }
			if (defined $info{'shipping'}) {	
				$info{'shipping'} =~ s/[^\d\.]+//gs;	# strip $ and spaces
				}

			# <b>94% positive</b>
			if ($tr->as_HTML() =~ /<b>([\d]+)% positive\<\/b\>/) { 
				$info{'rating'} = $1; 
				}
			# <span class="justlaunched"> Just Launched</span>
			elsif ((not defined $info{'rating'}) && ($v = $tr->look_down('class','justlaunched'))) {
				$info{'is_justlaunched'}++;
				$info{'rating'} = 0;
				}

			# <div class="availability">
			$v = $tr->look_down('class','availability');
			if ($v) {
				$info{'_availability'} = $v->as_HTML();
				if ($info{'_availability'} =~ /Usually ships within 1 \- 3 weeks/) { $info{'instock'} = 0; }
				if ($info{'_availability'} =~ /In Stock./) { $info{'instock'} = 1; }
				if ($info{'_availability'} =~ /Expedited/) { $info{'expedited'} = 1; }
				# (7,066 total ratings)
				if ($info{'_availability'} =~ /\(([\d,]+) total ratings\)/) { $info{'ratings'} = $1; }
				# <a href="/gp/help/seller/shipping.html/ref=olp_merch_ship_10/180-5621601-3754528?ie=UTF8&amp;asin=B003L7X9O8&amp;seller=AA8YLSTZM38ZI"
				if ($info{'_availability'} =~ /seller\=(.*?)[\"\&]+/) { $info{'sellerid'} = $1; }
				}

			# <span class="ratingHeader">Seller Rating:</span>
			# <img alt="" border="0" height="12" src="http://g-ecx.images-amazon.com/images/G/01/detail/stars-4-5._V192261415_.gif" width="64" />
			# <a href="/gp/help/seller/at-a-glance.html/ref=olp_merch_rating_1/181-4322936-2570247?ie=UTF8&amp;isAmazonFulfilled=1&amp;asin=B001DHHPYI&amp;marketplaceSeller=0&amp;seller=A1IP5Q3GWK9OUR" id="rating_-ic0FuuTF1-WCaIi71wGoi3fhKGHqmO0dHaIc-HIGwmtqWDZ7wkwItgevvqZNkXJ9VTqKFRQSvB2nFlUZ3GJ7RiVZ4tgcAA5NClMSQ-QsDuOKEnsccv1SxOVLRZIihw2m8KIn71YdPFX1-SLYJi9-A--" onclick="return amz_js_PopWin(&#39;/gp/help/seller/at-a-glance.html//ref=olp_merch_rating_1/181-4322936-2570247?ie=UTF8&amp;isAmazonFulfilled=1&amp;asin=B001DHHPYI&amp;marketplaceSeller=0&amp;seller=A1IP5Q3GWK9OUR&#39;, &#39;OLPSellerRating&#39;, &#39;width=1000,height=600,resizable=0,scrollbars=1,toolbar=0,status=0&#39;);"><b>92% positive</b></a> over the past 12 months. (10,463 total ratings)</div><li><div class="availability"> In Stock. <span id="ftm_%2Fic0FuuTF1%2FWCaIi71wGoi3fhKGHqmO0dHaIc%2FHIGwmtqWDZ7wkwItgevvqZNkXJ9VTqKFRQSvB2nFlUZ3GJ7RiVZ4tgcAA5NClMSQ%2FQsDuOKEnsccv1SxOVLRZIihw2m8KIn71YdPFX1%2BSLYJi9%2FA%3D%3D">
			if ($v = $tr->look_down('class','sellerInformation')) {
				$info{'_sellerInformation'} = $v->as_HTML();
				if ($info{'_sellerInformation'} =~ /\&amp\;seller\=(.*?)\"/) { $info{'sellerid'} = $1; }
				}



			# <div class="condition">New </div>
			$v = $tr->look_down('class','condition');
			if ($v) {
				$info{'condition'} = $v->as_text();
				$info{'condition'} =~ s/[\n\r\s]+$//gs;
				}

			if ($info{'sellerid'} eq 'ATVPDKIKX0DER') {
				## amazon prime tm
				$info{'is_fba'}++;
				}
		
			# <div class="fba_link" style="margin-top:8px; margin-left:0px;">
			if ($tr->look_down('class','fba_link')) {
				$info{'is_fba'}++;
				}

			if ($info{'is_fba'}) {
				$info{'expedited'} = 1;
				$info{'rating'} = 100;
				if ($tr->look_down('class','supersaver')) {
					$info{'shipping'} = -0.01;
					}
				# $info{'_debug'}++;		# (if we set _debug then all debug tags (start with _) will be preserved even if no error was found)
				}

			if ($info{'seller'} ne '') {
				## wtf, already set seller name -- not sure how this happened.
				}
			elsif ($v = $tr->look_down('class','seller')) {
				## some sellers don't have a graphic, so we have to search this way:
				# <div class="seller"><span class="sellerHeader">Seller:</span> 
				# <a href="/gp/help/seller/at-a-glance.html/ref=olp_merch_name_3/191-2761299-2589101?ie=UTF8&amp;isAmazonFulfilled=0&amp;asin=B002FH5QJQ&amp;marketplaceSeller=0&amp;seller=A1IP5Q3GWK9OUR">
				# <b>Martial Arts Land</b></a> </div>
				$info{'seller'} = $v->as_text();
				# "Seller: Martial Arts Land ";
				$info{'seller'} =~ s/^Seller:[\s]+//gs;
				$info{'seller'} =~ s/[\n\s\r]+$//gs;	# not necessary, but just in case.
				# $info{'_debug'}++;
				}
			elsif ($v = $tr->look_down('_tag','img')) { 
				# <img alt="FramesExperts" border="0" height="30" src="http://ecx.images-amazon.com/images/I/51piq-1yfhL.jpg" width="120" />
				$info{'seller'} = $v->as_HTML(); 
				if ($info{'seller'} =~ /alt="(.*?)"/) { $info{'seller'} = $1; }
				}

			push @ELEMENTS, \%info;
			# print $tr->as_HTML()."\n";
			#print Dumper(\%info);
			#print "\n-------\n";
			}		
		}

	# print Dumper(\@ELEMENTS);

	## an array of %info nodes.		
	return(\@ELEMENTS);
	}


1;

