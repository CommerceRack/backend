package DSS::AMAZON;

use strict;

use lib "/backend/lib";
require AMAZON3;
require ZTOOLKIT::XMLUTIL;


##
##
##
sub get_userref {
	my ($SELLERID) = @_;	
	print "RESOLVING $SELLERID\n";

	my %SELLER_IDS = (
		'A21CG51B4DJHNY'=>[ 'cubworld', 0 ],
		'A37SYHX13GSHLR'=>[ 'toynk', 0 ],
		'A371G8H8A5MY53'=>['zephyrsports', 0 ],
		'AO293CY7PLEN9'=> ['greatlookz', 2 ],
		);
	
	my ($userref) = undef;
	if (defined $SELLER_IDS{$SELLERID}) {
		$userref = &AMAZON3::fetch_userprt(@{$SELLER_IDS{$SELLERID}});
		}

	return($userref);
	}

##
##
##
sub sqs_queue_url {
	my ($CLUSTER) = @_;
	my $SQS_QUEUE_URL = "https://sqs.us-west-1.amazonaws.com/259948446197/$CLUSTER-mws-anyofferchanged";
	return($SQS_QUEUE_URL);
	}

##
##
##
sub getSellerSKUforASIN {
	my ($userref,$ASIN) = @_;

	my %HEADERS = ();
	$HEADERS{'Action'} = 'GetMyPriceForASIN';
	$HEADERS{'Version'} = '2011-10-01';
	$HEADERS{'ASINList.ASIN.1'} = $ASIN;

	my $agent = new LWP::UserAgent;
	$agent->agent('CommerceRack/FBA (Language=Perl/v5.8.6)');
	my ($request_url, $head) = &mws_headers("/Products/2011-10-01",$userref,\%HEADERS);
	my $request = HTTP::Request->new('POST',$request_url,$head);
	my $response = $agent->request($request);
	my $SKU = undef;
	if ($response->is_success) {
		if ($response->decoded_content() =~ /<SellerSKU>(.*?)<\/SellerSKU>/s) {
			$SKU = $1;	# cheap hack
			}
		}
	return($SKU);
	}


sub register {
	use lib "/backend/lib";
	use AMAZON3;
	use Data::Dumper;

	my ($USERNAME,$PRT) = ("toynk",0);
	my ($userref) = &AMAZON3::fetch_userprt($USERNAME,$PRT);
	my $LM = LISTING::MSGS->new($USERNAME);

	#my $AMZ_TOKEN = $userref->{'AMAZON_TOKEN'};
	#my $AMZ_MARKETPLACEID = $userref->{'AMAZON_MARKETPLACEID'};
	#my $AMZ_MERCHANTID = $userref->{'AMAZON_MERCHANTID'};
	# https://sqs.us-west-1.amazonaws.com/259948446197/endor-mws-anyofferchanged
	# https://sqs.us-west-1.amazonaws.com/259948446197/hoth-mws-anyofferchanged

	my $CLUSTER = &ZOOVY::resolve_cluster($USERNAME);
	my $HOSTNAME = &ZOOVY::servername();
	my $SQS_QUEUE_URL = "https://sqs.us-west-2.amazonaws.com/259948446197/$HOSTNAME-mws-anyofferchanged";

	if (1) {
		my %HEADERS = ();
		$HEADERS{'Action'} = 'RegisterDestination';
		$HEADERS{'Version'} = '2013-07-01';
		$HEADERS{'Destination.AttributeList.member.1.Key'} = 'sqsQueueUrl';
		$HEADERS{'Destination.AttributeList.member.1.Value'} = $SQS_QUEUE_URL;
		#  https%3A%2F%2Fsqs.us-east-1.amazonaws.com%2F51471EXAMPLE%2Fmws_notifications
		$HEADERS{'Destination.DeliveryChannel'} = 'SQS';

		my $agent = new LWP::UserAgent;
		$agent->agent('CommerceRack/FBA (Language=Perl/v5.8.6)');
		my ($request_url, $head) = &mws_headers("/Subscriptions/2013-07-01",$userref,\%HEADERS);
		my $request = HTTP::Request->new('POST',$request_url,$head);
		my $response = $agent->request($request);
		print Dumper($response);
		}
	
	if (1) {
		my %HEADERS = ();
		$HEADERS{'Action'} = 'CreateSubscription';
		$HEADERS{'Subscription.Destination.AttributeList.member.1.Key'} = 'sqsQueueUrl';
		$HEADERS{'Subscription.Destination.AttributeList.member.1.Value'} = $SQS_QUEUE_URL;
		$HEADERS{'Subscription.Destination.DeliveryChannel'} = 'SQS';
		$HEADERS{'Subscription.IsEnabled'} = 'true';
		$HEADERS{'Subscription.NotificationType'} = 'AnyOfferChanged';
		$HEADERS{'Version'} = '2013-07-01';
	
		my $agent = new LWP::UserAgent;
		$agent->agent('CommerceRack/FBA (Language=Perl/v5.8.6)');
		my ($request_url, $head) = &mws_headers("/Subscriptions/2013-07-01",$userref,\%HEADERS);
		my $request = HTTP::Request->new('POST',$request_url,$head);
		my $response = $agent->request($request);
		print Dumper($response);
		}
	
	}



sub queue_test {
	my ($userref) = @_;
	my %HEADERS = ();
	$HEADERS{'Action'} = 'SendTestNotificationToDestination';
	$HEADERS{'Destination.AttributeList.member.1.Key'} = 'sqsQueueUrl';
	$HEADERS{'Destination.AttributeList.member.1.Value'} = DSS::AMAZON::sqs_queue_url($userref);
	$HEADERS{'Destination.DeliveryChannel'} = 'SQS';
	$HEADERS{'Version'} = '2013-07-01';
	my $agent = new LWP::UserAgent;
	$agent->agent('CommerceRack/FBA (Language=Perl/v5.8.6)');
	my ($request_url, $head) = &mws_headers("/Subscriptions/2013-07-01",$userref,\%HEADERS);
	my $request = HTTP::Request->new('POST',$request_url,$head);
	my $response = $agent->request($request);
	print Dumper($response);
	
	}

################################################################################
## 
## DO NOT RECYCLE THIS FUNCTION INTO AMAZON3 or SUPPLIER::FBA 
##		there are subtle differnces between headers depending on the version(s)
##		this generates different headers (ex: MarketplaceId insteadof Marketplace)
##
sub mws_headers {
	my ($request_uri, $userref, $headers) = @_;
	my $XML = $headers->{'XML'};
	
	## 1. define credentials
	my $AMZ_MARKETPLACEID = $userref->{'AMAZON_MARKETPLACEID'};
	my $AMZ_MERCHANTID = $userref->{'AMAZON_MERCHANTID'};

	my ($CFG) = CFG->new();
	my $host = CFG->get("amazon_mws","host");
	my $sk = $CFG->get('amazon_mws',"sk");
	my $awskey = $CFG->get('amazon_mws',"aws_key");

	my $TS = AMAZON3::amztime(time()+(8*3600));
	my $md5 = &Digest::MD5::md5_base64($XML);
	$md5 .= "==";		## this is officially duct-tape, run w/o and md5's dont match

	my %params = (
		'AWSAccessKeyId'=>$awskey,
		'MarketplaceId'=>$AMZ_MARKETPLACEID,		## NOTE: other calls use 'Marketplace'
		'SellerId'=>$AMZ_MERCHANTID,
		'SignatureVersion'=>2,
		'SignatureMethod'=>'HmacSHA1',
		'Timestamp'=>$TS,
		);

	## populate params w/actions from push_xml
	## ie Action, FeedType, ReportId, FeedSubmissionId, ReportRequestIdList.Id.1, ReportRequestIdList.Id.2
	foreach my $key (keys %{$headers}) {
		next if ($key eq 'XML');		## special KEY that represent an XML body
		$params{$key} = $headers->{$key};
		}
	
	if (not defined $params{'Version'}) { warn "no 'Version' parameter (mws requires it)\n"; }

	## 2. create header
	my $head = HTTP::Headers->new();
	$head->header('Content-Type'=>'text/xml');
	$head->header('Host',$host);	
	$head->header('Content-MD5',$md5);

	## 3. create query string
	my $query_string = '';
	foreach my $k (sort keys %params) {
		$query_string .= URI::Escape::uri_escape_utf8($k).'='.URI::Escape::uri_escape_utf8($params{$k}).'&';
		}
	$query_string = substr($query_string,0,-1);	# strip trailing &

	#print "PARAMS\n".Dumper(\%params)."\nQUERY_STRING:\n".$query_string."\n";

	## 4. create string to sign
	my $url = "https://mws.amazonaws.com";
	my $data = 'POST';
	$data .= "\n";
	$data .= $host;
	$data .= "\n";
	$data .= $request_uri;
	$data .= "\n";
	$data .= $query_string;

	## 5. create digest by calculating HMAC, convert to base64
	my $digest = Digest::HMAC_SHA1::hmac_sha1($data,$sk);
	$digest = MIME::Base64::encode_base64($digest);
	$digest =~ s/[\n\r]+//gs;

	## 6. POST contents to MWS
	my %sig = ('Signature'=>$digest);
	my $request_url = $url.$request_uri."?".$query_string."&".&AMAZON3::build_mws_params(\%sig);

	return($request_url, $head);	
	}


sub getSellerInfo {
	my ($USERNAME,$marketplaceid,$sellerid) = @_;


	my $name = '';
	my $logourl = '';

	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $pstmt = "select MKTNAME from DSS_COMPETITORS where MID=$MID and MKT='AMZ' and MKTID=".$udbh->quote($sellerid);
	my ($name) = $udbh->selectrow_array($pstmt);

	if ($name eq '') {
		my $URL = "http://www.amazon.com/gp/shops/storefront/index.html?ie=UTF8&marketplaceID=$marketplaceid&sellerID=$sellerid";
		print STDERR "URL: $URL\n";

		my $agent = LWP::UserAgent->new(timeout=>3);
		$agent->agent('CommerceRack/DSS (Language=Perl/v5.8.6)');
		$agent->env_proxy();
		my $request = HTTP::Request->new('GET',$URL);
		my $response = $agent->request($request);
		if ($response->is_success()) {
			print "GETTING: $URL\n";
			my ($body) = $response->content();
			if ($body =~ /\>About ([\w\s\-]+)<\/a>/) { $name = $1; }
			elsif ($body =~ /<title>Amazon.com:(.*?) Storefront/) { $name = $1; }
			elsif ($body =~ /<option value=\"searchSellerStore\" selected \>(.*?)<\/option>/) { $name = $1; }
			elsif ($body =~ /seller\=$sellerid\&amp;sn=(.*?)\"\>/) { $name = $1; }
			if ($body =~ /<img src=\"(.*?)\".*?Alt=\"Seller Logo\".*?\/>/) { $logourl = $1; }


			## lets attempt to get and store the logo
			my $logoformat = '';
			my $logobody = undef;
			if ($logourl ne '') {
				print "LOGO: $logourl\n";
				my $request = HTTP::Request->new('GET',$logourl);
				my $response = $agent->request($request);
				if ($response->is_success()) {
					$logobody = $response->content();
					}
				if ((defined $logobody) && (length($logobody)>0)) {
					if ($logourl =~ /\.(png|jpg|gif)$/i) { $logoformat = $1; }
					}
				}
	
			if ($name ne '') {
				$name =~ s/((?:^|\s)\w)/\U$1\E/g;
				$name =~ s/[^\w]+//gs;
				my ($pstmt) = &DBINFO::insert($udbh,'DSS_COMPETITORS',{
					MID=>$MID,
					MKT=>'AMZ',
					MKTID=>$sellerid,
					MKTNAME=>$name,
					LOGOFORMAT=>$logoformat,
					LOGOBLOB=>MIME::Base64::encode($logobody),
					},verb=>'insert',sql=>1);
				print STDERR "$pstmt\n";
				$udbh->do($pstmt);
				}
			}
		print "sleeping..\n";
		# sleep(1);		## if we don't pause, we'll get blocked.
		}

	&DBINFO::db_user_close();

	## ABOUT SELLER PAGE:
	## ALT URL: http://www.amazon.com/gp/aag/main?ie=UTF8&asin=&isAmazonFulfilled=&isCBA=&marketplaceID=ATVPDKIKX0DER&orderID=&seller=A21CG51B4DJHNY
	return($name);
	}




1;


__DATA__


TELL AMAZON WHERE YOU WANT THE MERCHANTS NOTIFICATIONS TO BE SENT

RegisterDestination

https://mws.amazonservices.com/Subscriptions/2013-07-01
?AWSAccessKeyId=AKIAEEXAMPLESA
&Action=RegisterDestination
&Destination.AttributeList.member.1.Key=sqsQueueUrl
&Destination.AttributeList.member.1.Value=
  https%3A%2F%2Fsqs.us-east-1.amazonaws.com%2F51471EXAMPLE%2Fmws_notifications
&Destination.DeliveryChannel=SQS
&MarketplaceId=ATVPDKIKX0DER
&SellerId=A135KEXAMPLE56
&SignatureMethod=HmacSHA256
&SignatureVersion=2
&Timestamp=2013-07-25T16%3A14%3A01Z
&Version=2013-07-01
&Signature=WgTRuEXAMPLEeIzoJ5tzX06uKV7ongzUserZ6vj8kug%3D


<RegisterDestinationResponse
    xmlns="http://mws.amazonservices.com/schema/Subscriptions/2013-07-01">
  <RegisterDestinationResult/>
  <ResponseMetadata>
    <RequestId>b120e610-9cf0-48d7-b615-ca869EXAMPLE</RequestId>
  </ResponseMetadata>
</RegisterDestinationResponse>

******************************************

TELL AMAZON WHAT KIND OF NOTIFICATIONS YOU WISH TO RECEIVE FOR THE MERCHANT

CreateSubscription

https://mws.amazonservices.com/Subscriptions/2013-07-01
?AWSAccessKeyId=AKIAEEXAMPLENGQCJLSA
&Action=CreateSubscription
&MarketplaceId=ATVPDKIKX0DER
&SellerId=A135KEXAMPLE56
&SignatureMethod=HmacSHA256
&SignatureVersion=2
&Subscription.Destination.AttributeList.member.1.Key=sqsQueueUrl
&Subscription.Destination.AttributeList.member.1.Value=
  https%3A%2F%2Fsqs.us-east-1.amazonaws.com%2F51471EXAMPLE%2Fmws_notifications
&Subscription.Destination.DeliveryChannel=SQS
&Subscription.IsEnabled=true
&Subscription.NotificationType=AnyOfferChanged
&Timestamp=2013-07-25T16%3A36%3A10Z
&Version=2013-07-01
&Signature=IUc%2EXAMPLEQajCIZLP8DHXxdl%2FXupCJ6f51bD%2BMEEU%2F%2Bc%3D

<CreateSubscriptionResponse
    xmlns="http://mws.amazonservices.com/schema/Subscriptions/2013-07-01">
  <CreateSubscriptionResult/>
  <ResponseMetadata>
    <RequestId>c9bb2e77-2425-4e1a-9c85-36d00EXAMPLE</RequestId>
  </ResponseMetadata>
</CreateSubscriptionResponse>


**********************************************
TEST TO MAKE SURE THE NOTIFICATIONS WILL BE RECEIVED BY THE QUEUE

SendTestNotificationToDestination

https://mws.amazonservices.com/Subscriptions/2013-07-01
?AWSAccessKeyId=AKIAEEXAMPLENGQCJLSA
&Action=SendTestNotificationToDestination
&Destination.AttributeList.member.1.Key=sqsQueueUrl
&Destination.AttributeList.member.1.Value=
  https%3A%2F%2Fsqs.us-east-1.amazonaws.com%2F51471EXAMPLE%2Fmws_notifications
&Destination.DeliveryChannel=SQS
&MarketplaceId=ATVPDKIKX0DER
&SellerId=A135KEXAMPLE56
&SignatureMethod=HmacSHA256
&SignatureVersion=2
&Timestamp=2013-07-25T16%3A34%3A10Z
&Version=2013-07-01
&Signature=4nVisEXAMPLEpMaKsvyGPLkvtang%2Bo6Gurz4PssrPIY%3D

Example response

<SendTestNotificationToDestinationResponse
    xmlns="http://mws.amazonservices.com/schema/Subscriptions/2013-07-01">
  <SendTestNotificationToDestinationResult/>
  <ResponseMetadata>
    <RequestId>f662dae6-bde0-4e75-a53b-741abEXAMPLE</RequestId>
  </ResponseMetadata>
</SendTestNotificationToDestinationResponse>


***************************************************
TELL AMAZON TO STOP SENDING NOTIFICATIONS FOR A SPECIFIC MERCHANT TO OUR QUEUE

DeregisterDestination

https://mws.amazonservices.com/Subscriptions/2013-07-01
?AWSAccessKeyId=AKIAEEXAMPLENGQCJLSA
&Action=DeregisterDestination
&Destination.AttributeList.member.1.Key=sqsQueueUrl
&Destination.AttributeList.member.1.Value=
  https%3A%2F%2Fsqs.us-east-1.amazonaws.com%2F51471EXAMPLE%2Fmws_notifications
&Destination.DeliveryChannel=SQS
&MarketplaceId=ATVPDKIKX0DER
&SellerId=A135KEXAMPLE56
&SignatureMethod=HmacSHA256
&SignatureVersion=2
&Timestamp=2013-07-25T16%3A21%3A03Z
&Version=2013-07-01
&Signature=H1%2FEXAMPLEEnwyhzIEk3wR2AiasJjj7hVeherC3r0Hk%3D

Example response

<DeregisterDestinationResponse
    xmlns="http://mws.amazonservices.com/schema/Subscriptions/2013-07-01">
  <DeregisterDestinationResult/>
  <ResponseMetadata>
    <RequestId>f662dae6-bde0-4e75-a53b-741abEXAMPLE</RequestId>
  </ResponseMetadata>
</DeregisterDestinationResponse>

**********************************************************

TELL AMAZON TO STOP SENDING SPECIFIC TYPES OF NOTIFICATIONS FOR A SPECIFIC MERCHANT TO OUR QUEUE

DeleteSubscription

https://mws.amazonservices.com/Subscriptions/2013-07-01
?AWSAccessKeyId=AKIAEEXAMPLENGQCJLSA
&Action=DeleteSubscription
&Destination.AttributeList.member.1.Key=sqsQueueUrl
&Destination.AttributeList.member.1.Value=
  https%3A%2F%2Fsqs.us-east-1.amazonaws.com%2F51471EXAMPLE%2Fmws_notifications
&Destination.DeliveryChannel=SQS
&MarketplaceId=ATVPDKIKX0DER
&NotificationType=AnyOfferChanged
&SellerId=A135KEXAMPLE56
&SignatureMethod=HmacSHA256
&SignatureVersion=2
&Timestamp=2013-07-25T16%3A41%3A16Z
&Version=2013-07-01
&Signature=vRBxMEXAMPLES2y0FGPufG4u7WY2HqhcsYUW6IVI9%2BQ%3D

Example response

<DeleteSubscriptionResponse
    xmlns="http://mws.amazonservices.com/schema/Subscriptions/2013-07-01">
  <DeleteSubscriptionResult/>
  <ResponseMetadata>
    <RequestId>2d7db8a1-8974-4541-9c9b-f882dEXAMPLE</RequestId>
  </ResponseMetadata>
</DeleteSubscriptionResponse>





package REPRICE::AMAZON;

use strict;
use Data::Dumper;
use XML::SAX::Simple;
use lib "/backend/lib";
require AMAZON3;
require SYNDICATION;
require REPRICE::LOG;


# print Dumper(lookupASINs($userref,\@SKUS));
#print Dumper(GetLowestOfferListingsForSKUs($userref,\@SKUS));
#die();


sub username { return($_[0]->{'USERNAME'}); };
sub ts { return($_[0]->{'TS'}); };

sub new {
	my ($CLASS, $USERNAME) = @_;

	my $self = {};
	$self->{'USERNAME'} = $USERNAME;
	$self->{'TS'} = time();
	bless $self, $CLASS;

	return($self);
	}


##
## globally loads any configuration data
##
sub init {
	my ($self) = @_;

	my $ERROR = undef;
	my ($userref) = &AMAZON3::fetch_userprt($self->username());
	if (not defined $userref) {
		$ERROR = "No Amazon account was configured/available.";
		}
	else {
		$self->{'%userref'} = $userref;
		}

	return($ERROR);
	}


##
## takes an array of products (sorted by most immediate need first)
##	returns a reference to a hash of products
##
sub run {
	my ($self,$SKUARRAY) = @_;
	my $i = 0;
	my @SKIPPED = ();
	my @PROCESS = ();
	foreach my $SKU (@{$SKUARRAY}) {
		if ($i++ > 10000) {
			## NOTE: we would eventually put any limiting code here
			push @SKIPPED, $SKU;
			}
		else {
			push @PROCESS, $SKU;
			}
		}

	sleep(rand());
	my $SKUREF = {};
	if (time() % 2 == 1) {
		$SKUREF = &REPRICE::AMAZON::GetLowestOfferListingsForSKUs($self->{'%userref'},\@PROCESS);
		}
	else {
		$SKUREF = &REPRICE::AMAZON::GetCompetitivePricingForSKU($self->{'%userref'},\@PROCESS);
		}
	foreach my $SKU (@SKIPPED) {
		$SKUREF->{$SKU} = { '.status'=>'skip', '.msg'=>'insufficient api calls' };
		}
	return($SKUREF);
	}




sub log {
	my ($self, $RESULT, $LOGSREF) = @_;

	foreach my $SKU (keys %{$RESULT}) {
		my $ref = $RESULT->{$SKU};
		my $rpl = REPRICE::LOG->new();

		if ($ref->{'.status'} eq 'skip') {
			$rpl->append( $self->ts(), "AMZ", "SKIP", {'+'=>$ref->{'.msg'}} );
			}
		elsif ($ref->{'.status'} ne 'success') {
			## error?!
			$rpl->append( $self->ts(), "AMZ", uc($ref->{'.status'}), {'+'=>$ref->{'.msg'}} );
			}
		elsif (scalar(@{$ref->{'@OFFERS'}})==0) {
			$rpl->append( $self->ts(), "AMZ", "STOP", { '+'=>"No offers" } );
			}
		else {
			foreach my $offer (@{$ref->{'@OFFERS'}}) {
				my %params = ();
				if ($offer->{'.type'} eq 'LowestOffer') {
					$params{'ship'} = $offer->{'.Price.Shipping.Amount'};
					$params{'item'} = $offer->{'.Price.ListingPrice.Amount'};
					$params{'fob'} = $offer->{'.Price.LandedPrice.Amount'};
					$params{'new'} = ($offer->{'.Qualifiers.ItemCondition'} eq 'New')?1:0;
					$params{'fbr'} = $offer->{'.Qualifiers.SellerPositiveFeedbackRating'};
					$params{'fbc'} = $offer->{'.Qualifiers.SellerPositiveFeedbackCount'};
					$params{'fba'} = ($offer->{'.Qualifiers.FulfillmentChannel'} eq 'Merchant')?0:1;
					if ($offer->{'.Qualifiers.ShippingTime.Max'} eq '0-2 days') { $params{'shin'} = 2; }
					$rpl->append($self->ts(), "AMZ", "SELL", \%params);
					}
				elsif ($offer->{'.type'} eq 'CompetitivePrice') {
                #           '.CompetitivePrice.Price.LandedPrice.CurrencyCode' => 'USD',
                #           '.CompetitivePrice.subcondition' => 'New',
                #           '.CompetitivePrice.CompetitivePriceId' => '1',
                #           '.CompetitivePrice.Price.ListingPrice.Amount' => '19.49',
                #           '.type' => 'CompetitivePrice',
                #           '.CompetitivePrice.Price.Shipping.CurrencyCode' => 'USD',
                #           '.CompetitivePrice.condition' => 'New',
                #           '.CompetitivePrice.Price.LandedPrice.Amount' => '19.49',
                #           '.CompetitivePrice.Price.ListingPrice.CurrencyCode' => 'USD',
                #           '.CompetitivePrice.belongsToRequester' => 'false',
                #           '.CompetitivePrice.Price.Shipping.Amount' => '0.00'
					$params{'ship'} = $offer->{'.CompetitivePrice.Price.Shipping.Amount'};
					$params{'item'} = $offer->{'.CompetitivePrice.Price.ListingPrice.Amount'};
					$params{'fob'} = $offer->{'.CompetitivePrice.Price.LandedPrice.Amount'};
					$params{'ours'} = ($offer->{'.CompetitivePrice.belongsToRequester'} eq 'false')?0:1;
					$params{'new'} = ($offer->{'.CompetitivePrice.condition'} eq 'New')?1:0;
					$params{'rank'} = $offer->{'.CompetitivePrice.CompetitivePriceId'};
					$rpl->append($self->ts(), "AMZ", "LOW", \%params);
					}
				else {
					$offer->{'+'} = "Unknown Offer .type";
					$rpl->append($self->ts(), "AMZ", "ISE", $offer);
					}
				}
			}
		#print Dumper($ref,$rpl);
		#die();

		if (not defined $LOGSREF->{$SKU}) {
			$LOGSREF->{$SKU} = $rpl;
			}
		else {
			$LOGSREF->{$SKU}->merge($rpl);
			}
		}

#         'MAT-P9633-C' => {
#                          '.Product.Identifiers.SKUIdentifier.SellerId' => 'A37SYHX13GSHLR',
#                          '.Product.xmlns' => 'http://mws.amazonservices.com/schema/Products/2011-10-01',
#                          '.SellerSKU' => 'MAT-P9633-C',
#                          '@OFFERS' => [
#                                         {
#                                           '.Price.Shipping.CurrencyCode' => 'USD',
#                                            '.Price.Shipping.Amount' => '0.00',
#                                           '.Qualifiers.ItemCondition' => 'New',
#                                           '.Qualifiers.ShipsDomestically' => 'True',
#                                            '.Qualifiers.FulfillmentChannel' => 'Merchant',
#                                            '.Qualifiers.ItemSubcondition' => 'New',
#                                            '.SellerFeedbackCount' => '14570',
#                                            '.Qualifiers.SellerPositiveFeedbackRating' => '95-97%',
#                                            '.Price.LandedPrice.Amount' => '9.25',
#                                            '.MultipleOffersAtLowestPrice' => 'False',
#                                            '.Price.ListingPrice.Amount' => '9.25',
#                                            '.Price.ListingPrice.CurrencyCode' => 'USD',
#                                            '.Qualifiers.ShippingTime.Max' => '0-2 days',
#                                            '.NumberOfOfferListingsConsidered' => '4',
#                                            '.Price.LandedPrice.CurrencyCode' => 'USD'
#                                          },
 
	}


##
## INPUT:
##		an amazon userref 
##		an arrayref of skus
##
## RESPONSE:
##		a hashref keyed by SKU where:
##		* every single sku in the passed in arrayref has a response that looks like:
##			.status=>'success' 	# will contain repricing info
##			.status=>'apierr'		# something went wrong on amazons side (may/may not be correctable)
##			.status=>'ise'			# indicates an internal failure in well formed logic handling 
##			.status=>'skip'		# skipped due to xyz? (this isn't actually used here, but is at 'run') 
##			.msg => long text
##		
sub GetLowestOfferListingsForSKUs {
	my ($userref, $SKUARRAY) = @_;

	my @MSGS = ();
	## Amazon only allows us to lookup 5 skus at the same time.
	my %SKUS = ();
	my @GROUPS_OF_SKUS = @{&ZTOOLKIT::batchify($SKUARRAY,5)};

	my $API_RETRY_ATTEMPTS = 0;
	while (scalar(@GROUPS_OF_SKUS)>0) {
		## note: this loop is intentionally written badly, it allows us to push silly errors with one sku
		## back onto the processing stack for processing. ex: if we get a 'retry' condition we'll retry once
		## but the retry counter is for all skus in the group so we won't retry each group separately.
		
		## this module uses a slighty different code pattern than a normal waterfall, each section is 
		## responsible for handling it's own errors, rather than letting the subsequent module 'catch' it
		## this is because amazon likes to group things and return wildly different errors -- and this 
		## approach ends up making more sense. -bh 8/16/2012
	
		## note: i ended up doing 'nuclear grade error handling' - e.g. the type of patterns you'd see in
		## literally in a nuclear reactor for failsafe error handling and reliable messaging about current
		## state. of course i don't think anybody would actually be stupid enough to connect amazon to 
		## the failsafe safety system of a nuclear reactor, and if somebody was that stupid .. well, hopefully
		## they will die a slow painful death of radiation poisoning. 

		my $GroupOfSKUs = shift @GROUPS_OF_SKUS;
		my %p = ();
		$p{'Action'} = 'GetLowestOfferListingsForSKU';
		$p{'Version'} = '2011-10-01';
		$p{'SellerId'} = $userref->{'AMAZON_MERCHANTID'};	
		$p{'MarketplaceId'} = 'ATVPDKIKX0DER'; # $userref->{'AMAZON_MERCHANTID'};
		$p{'IdType'} = 'SellerSKU';

		## ItemCondition: Any, New, Used, Collectible, Refurbished, Club
		## ExcludeMe	'True', 'False'
		$p{'ExcludeMe'} = 'False';
		$p{'ItemCondition'} = 'New';

		my $i = 1;
		foreach my $SKU (@{$GroupOfSKUs}) {
			#	$p{'SellerSKUList.SellerSKU.1'} = $SKU;
			$p{sprintf('SellerSKUList.SellerSKU.%d',$i++)} = $SKU;
			}
		# print 'API Request: '.Dumper(\%p);

		##
		## SANITY: at this point the request to amazon should be fully formed (regardless if we're going to
		##			  make the request or not.
		##
		my $raw_xml_response = undef;
		if ($API_RETRY_ATTEMPTS > 3) {
			foreach my $SKU (@{$GroupOfSKUs}) {
				next if (defined $SKUS{$SKU}); # note: leave prior errors alone, since they're (hopefully) more meaningful
				$SKUS{$SKU} = { 
					'.status'=>'apierr',
					'.msg'=>sprintf('Too many API failures: %d',$API_RETRY_ATTEMPTS)
					};
				}
			}
		else {
			my ($request_url, $head, $agent) = &AMAZON3::prep_header2($userref,\%p);
			my $request = HTTP::Request->new('POST',$request_url,$head);
			my $response = $agent->request($request);
			if ($response->code() == 400) {
				## 400 = this definitely means account was suspended or password is wrong.
				## this is DEFINITELY not a retry condition.
				foreach my $SKU (@{$GroupOfSKUs}) {
					next if (defined $SKUS{$SKU}); # note: leave prior errors alone, since they're (hopefully) more meani
					$SKUS{$SKU} = {
						'.status'=>'apierr',
						'.msg'=>'HTTP400 Error: mws token is invalid or account is suspended.'
						};
					}
				}
			elsif (not $response->is_success()) {
				## High level API Failure (this could be us, or Amazon down)
				foreach my $SKU (@{$GroupOfSKUs}) {
					next if (defined $SKUS{$SKU}); # note: leave prior errors alone, since they're (hopefully) more meani
					## NOTE: $response->code() might be different -- but for now -- just one error:
					$SKUS{$SKU} = {
						'.status'=>'apierr',
						'.msg'=>sprintf('API Failure: %s',$response->status_line())
						};
					}
				## api retry protocol: bump api error count, re-push this group and put another quarter in.
				push @GROUPS_OF_SKUS, $GroupOfSKUs;;
				$API_RETRY_ATTEMPTS++;
				}
			else {
				## we did not receive an api error so set $xml 
				$raw_xml_response = $response->content();
				}
			}

		##
		## SANITY: at this point $raw_xml_response is set, OR $SKUS{$SKU} has an error set.
		##
		my $PRETTY_PARSEDXML_RESPONSE = undef;
		if (not defined $raw_xml_response) {
			## yeah, i'm ocd about error handling (this error handler should be totally unnecessary)
			foreach my $SKU (@{$GroupOfSKUs}) {
				next if (defined $SKUS{$SKU}); # note: leave prior errors alone, since they're (hopefully) more meani
				## seriously: this error SHOULD NEVER be shown to anybody
				## because it indicates an earlier phase failed to handle it's shit properly.
				$SKUS{$SKU} = {
					'.status'=>'ise',
					'.msg'=>'Internal Logic Failure: sku error unspecified, and raw_xml_response is not defined'
					};
				}
			}
		else {
			## let's process this xml response.
			my ($sh) = IO::String->new(\$raw_xml_response);
			open F, ">/dev/shm/amazon.raw_xml_response"; print F $raw_xml_response; close F;
			my ($msgs) = XML::SAX::Simple::XMLin($sh,ForceArray=>1);
			## NOTE: stripNamespace rewrites the sax xml without namespaces e.g.:
			# original: '{http://mws.amazonservices.com/schema/Products/2011-10-01}SKUIdentifier'=>{..}
			#  	into: 'SKUIdentifier'=>{}
			## so the xml response looks very different (but much more managable after stripNamespace)
			&ZTOOLKIT::XMLUTIL::stripNamespace($msgs);	
			$PRETTY_PARSEDXML_RESPONSE = $msgs;		# !!! HEY look at the reminder about stripNamespace above.
			# print 'Parsed Response: '.Dumper($PRETTY_PARSEDXML_RESPONSE);

			## OKAY -- this right here is probably where we ought to handle high level API errors e.g.
			##		seller id is fucked, etc. (because they aren't really retry conditions)
			##	TODO: add this code later.
			}

		# $xml =~ s/xmlns=\"(.*?)\"//gs;

		# my ($msg) = XML::Simple::XMLin($xml,'ForceArray'=>1);
		## try to figure out what went wrong
		if (not defined $PRETTY_PARSEDXML_RESPONSE) {
			## yeah, more ocd error handling
			foreach my $SKU (@{$GroupOfSKUs}) {
				next if (defined $SKUS{$SKU}); # note: leave prior errors alone, since they're (hopefully) more meani
				## seriously: this error SHOULD NEVER be shown to anybody
				## because it indicates an earlier phase failed to handle it's shit properly.
				$SKUS{$SKU} = {
					'.status'=>'ise',
					'.msg'=>'Internal Logic Failure: sku error unspecified, and PRETTY_PARSEDXML_RESPONSE is not defined'
					};
				}
			}
		elsif (defined $PRETTY_PARSEDXML_RESPONSE->{'GetLowestOfferListingsForSKUResult'}) {
			foreach my $msg (@{$PRETTY_PARSEDXML_RESPONSE->{'GetLowestOfferListingsForSKUResult'}}) {
				#'.Product.Identifiers.SKUIdentifier.SellerId' => 'A2VJTIF5QBGOAS',
				#'.Product.Identifiers.MarketplaceASIN.MarketplaceId' => 'ATVPDKIKX0DER',
				#'.Product.Identifiers.SKUIdentifier.SellerSKU' => 'APPAREL-V:A800:A901',
				#'.Product.xmlns' => 'http://mws.amazonservices.com/schema/Products/2011-10-01',
				#'.Product.Identifiers.SKUIdentifier.MarketplaceId' => 'ATVPDKIKX0DER',
				#'.SellerSKU' => 'APPAREL-V:A800:A901',
				#'.Product.ns2' => 'http://mws.amazonservices.com/schema/Products/2011-10-01/default.xsd',
				#'.Product.Identifiers.MarketplaceASIN.ASIN' => 'B0078SIS1K',
				#'.AllOfferListingsConsidered' => 'true',
				#'.status' => 'Success'
				my ($node) = ZTOOLKIT::XMLUTIL::SXMLflatten($msg);
				# print 'Flattend Response: '. Dumper($node);
				if ($node->{'.status'} eq 'Success') {
					## it's all good bro.
					$node->{'.status'} = 'success';
					foreach my $k (keys %{$node}) {
						if ($k =~ /^\.Product\.LowestOfferListings\.LowestOfferListing/) {
							delete $node->{$k};
							}
						}

					my @OFFERS = ();
					foreach my $offernode (@{$msg->{'Product'}[0]->{'LowestOfferListings'}[0]->{'LowestOfferListing'}}) {
						my ($offer) = ZTOOLKIT::XMLUTIL::SXMLflatten($offernode);
						$offer->{'.type'} = 'LowestOffer';
						push @OFFERS, $offer;
						}
					$node->{'@OFFERS'} = \@OFFERS;
					# print Dumper($msg,$node); die();
					}
				elsif ($node->{'.status'} eq 'ClientError') {
					## a well formed error
					# '.status' => 'ClientError'
					# '.SellerSKU' => 'xyz23424',
					# '.Error.Message' => 'xyz23424 is an invalid SellerSKU for marketplace ATVPDKIKX0DER',
					# '.Error.Code' => 'InvalidParameterValue',
					# '.Error.Type' => 'Sender', 
					$node->{'.msg'} = sprintf("Amazon ClientError %s",$node->{'.Error.Message'});
					## note: we can override specific errors here
					if ($node->{'.SellerSKU'} eq '') {
						## WOW! wtf, seriously, those dickheads.
						$node->{'.msg'} = sprintf("Horrible Response from Amazon 1) .SellerSKU is blank, 2) %s",$node->{'.Error.Message'});
						}
					elsif ($node->{'.Error.Code'} eq 'InvalidParameterValue') {
						if ($node->{'.Error.Message'} =~ /invalid SellerSKU for marketplace/) {
							$node->{'.msg'} = sprintf("Amazon ClientError SKU %s is invalid for marketplace",$node->{'.SellerSKU'});
							}
						}					
					$node->{'.status'} = 'error';
					}
				elsif ($node->{'.status'} eq 'error') {
					## it's not good, but hopefully .msg will be set
					if (not defined $node->{'.msg'}) {
						$node->{'.msg'} = 'Amazon returned error, with no message for GetLowestOfferListingsForSKUResult node';
						}
					}
				else {
					if (not defined $node->{'.msg'}) {
						$node->{'.msg'} = sprintf('Caught invalid .status: %s, within GetLowestOfferListingsForSKUResult node',$node->{'.status'});
						}
					$node->{'.status'} = 'error';
					}

				$SKUS{ $node->{'.SellerSKU'} } = $node 

				
				}
			## do a quick double check to make sure that each of the SKUs in the GroupOfSKUs was covered in the response.
         foreach my $SKU (@{$GroupOfSKUs}) {
				next if (defined $SKUS{$SKU});	# hopefully an earlier error (or maybe even a success) was handled.
            $SKUS{ $SKU } = {
               '.status'=>'apierr',
               '.msg' => 'SKU was not included GetLowestOfferListingsForSKUResult Result'
               };
            }

			}		
		else {
			## WTF happened here!?! holy shit. very bad response amazon, very bad response.
			## AND BAD ERROR HANDLING ON OUR SIDE AS WELL.
			foreach my $SKU (@{$GroupOfSKUs}) {
				next if (defined $SKUS{$SKU});	# hopefully an earlier error indicates the problem.
				$SKUS{ $SKU } = {
					'.status'=>'ise',
					'.msg' => 'Internal Logic Failure: sku error unspecified, and no GetLowestOfferListingsForSKUResult'
					};				
				}
			}

		## a last ditch attempt to catch errors
		foreach my $SKU (@{$GroupOfSKUs}) {
			next if (defined $SKUS{$SKU});	# hopefully an earlier error indicates the problem.
			$SKUS{ $SKU } = {
				'.status'=>'ise',
				'.msg' => 'Internal Logic Failure: unhandled sku error within grouping loop'
				};				
			}
		}	

	## wtf, seriously, who the hell knows how we'd get here.
	foreach my $SKU (@{$SKUARRAY}) {
		next if (defined $SKUS{$SKU});	# hopefully an earlier error indicates the problem.
		$SKUS{ $SKU } = {
			'.status'=>'ise',
			'.msg' => 'Internal Logic Failure: unhandled sku error outside of grouping loop'
			};				
		}

	return(\%SKUS);
	}





##
## INPUT:
##		an amazon userref 
##		an arrayref of skus
##
## RESPONSE:
##		a hashref keyed by SKU where:
##		* every single sku in the passed in arrayref has a response that looks like:
##			.status=>'success' 	# will contain repricing info
##			.status=>'apierr'		# something went wrong on amazons side (may/may not be correctable)
##			.status=>'ise'			# indicates an internal failure in well formed logic handling 
##			.status=>'skip'		# skipped due to xyz? (this isn't actually used here, but is at 'run') 
##			.msg => long text
##		
sub GetCompetitivePricingForSKU {
	my ($userref, $SKUARRAY) = @_;

	my @MSGS = ();
	## Amazon only allows us to lookup 5 skus at the same time.
	my %SKUS = ();
	my @GROUPS_OF_SKUS = @{&ZTOOLKIT::batchify($SKUARRAY,5)};

	my $API_RETRY_ATTEMPTS = 0;
	while (scalar(@GROUPS_OF_SKUS)>0) {
		## note: this loop is intentionally written badly, it allows us to push silly errors with one sku
		## back onto the processing stack for processing. ex: if we get a 'retry' condition we'll retry once
		## but the retry counter is for all skus in the group so we won't retry each group separately.
		
		## this module uses a slighty different code pattern than a normal waterfall, each section is 
		## responsible for handling it's own errors, rather than letting the subsequent module 'catch' it
		## this is because amazon likes to group things and return wildly different errors -- and this 
		## approach ends up making more sense. -bh 8/16/2012
	
		## note: i ended up doing 'nuclear grade error handling' - e.g. the type of patterns you'd see in
		## literally in a nuclear reactor for failsafe error handling and reliable messaging about current
		## state. of course i don't think anybody would actually be stupid enough to connect amazon to 
		## the failsafe safety system of a nuclear reactor, and if somebody was that stupid .. well, hopefully
		## they will die a slow painful death of radiation poisoning. 

		my $GroupOfSKUs = shift @GROUPS_OF_SKUS;
		my %p = ();
		$p{'Action'} = 'GetCompetitivePricingForSKU';
		$p{'Version'} = '2011-10-01';
		$p{'SellerId'} = $userref->{'AMAZON_MERCHANTID'};	
		$p{'MarketplaceId'} = 'ATVPDKIKX0DER'; # $userref->{'AMAZON_MERCHANTID'};
		$p{'IdType'} = 'SellerSKU';

		## ItemCondition: Any, New, Used, Collectible, Refurbished, Club
		## ExcludeMe	'True', 'False'
		$p{'ExcludeMe'} = 'False';
		$p{'ItemCondition'} = 'New';

		my $i = 1;
		foreach my $SKU (@{$GroupOfSKUs}) {
			#	$p{'SellerSKUList.SellerSKU.1'} = $SKU;
			$p{sprintf('SellerSKUList.SellerSKU.%d',$i++)} = $SKU;
			}
		# print 'API Request: '.Dumper(\%p);

		##
		## SANITY: at this point the request to amazon should be fully formed (regardless if we're going to
		##			  make the request or not.
		##
		my $raw_xml_response = undef;
		if ($API_RETRY_ATTEMPTS > 3) {
			foreach my $SKU (@{$GroupOfSKUs}) {
				next if (defined $SKUS{$SKU}); # note: leave prior errors alone, since they're (hopefully) more meaningful
				$SKUS{$SKU} = { 
					'.status'=>'apierr',
					'.msg'=>sprintf('Too many API failures: %d',$API_RETRY_ATTEMPTS)
					};
				}
			}
		else {
			my ($request_url, $head, $agent) = &AMAZON3::prep_header2($userref,\%p);
			my $request = HTTP::Request->new('POST',$request_url,$head);
			my $response = $agent->request($request);
			if ($response->code() == 400) {
				## 400 = this definitely means account was suspended or password is wrong.
				## this is DEFINITELY not a retry condition.
				foreach my $SKU (@{$GroupOfSKUs}) {
					next if (defined $SKUS{$SKU}); # note: leave prior errors alone, since they're (hopefully) more meani
					$SKUS{$SKU} = {
						'.status'=>'apierr',
						'.msg'=>'HTTP400 Error: mws token is invalid or account is suspended.'
						};
					}
				}
			elsif (not $response->is_success()) {
				## High level API Failure (this could be us, or Amazon down)
				foreach my $SKU (@{$GroupOfSKUs}) {
					next if (defined $SKUS{$SKU}); # note: leave prior errors alone, since they're (hopefully) more meani
					## NOTE: $response->code() might be different -- but for now -- just one error:
					$SKUS{$SKU} = {
						'.status'=>'apierr',
						'.msg'=>sprintf('API Failure: %s',$response->status_line())
						};
					}
				## api retry protocol: bump api error count, re-push this group and put another quarter in.
				push @GROUPS_OF_SKUS, $GroupOfSKUs;;
				$API_RETRY_ATTEMPTS++;
				}
			else {
				## we did not receive an api error so set $xml 
				$raw_xml_response = $response->content();
				}
			}

		##
		## SANITY: at this point $raw_xml_response is set, OR $SKUS{$SKU} has an error set.
		##
		my $PRETTY_PARSEDXML_RESPONSE = undef;
		if (not defined $raw_xml_response) {
			## yeah, i'm ocd about error handling (this error handler should be totally unnecessary)
			foreach my $SKU (@{$GroupOfSKUs}) {
				next if (defined $SKUS{$SKU}); # note: leave prior errors alone, since they're (hopefully) more meani
				## seriously: this error SHOULD NEVER be shown to anybody
				## because it indicates an earlier phase failed to handle it's shit properly.
				$SKUS{$SKU} = {
					'.status'=>'ise',
					'.msg'=>'Internal Logic Failure: sku error unspecified, and raw_xml_response is not defined'
					};
				}
			}
		else {
			## let's process this xml response.
			my ($sh) = IO::String->new(\$raw_xml_response);
			open F, ">/dev/shm/amazon.raw_xml_response"; print F $raw_xml_response; close F;
			my ($msgs) = XML::SAX::Simple::XMLin($sh,ForceArray=>1);
			## NOTE: stripNamespace rewrites the sax xml without namespaces e.g.:
			# original: '{http://mws.amazonservices.com/schema/Products/2011-10-01}SKUIdentifier'=>{..}
			#  	into: 'SKUIdentifier'=>{}
			## so the xml response looks very different (but much more managable after stripNamespace)
			&ZTOOLKIT::XMLUTIL::stripNamespace($msgs);	
			$PRETTY_PARSEDXML_RESPONSE = $msgs;		# !!! HEY look at the reminder about stripNamespace above.
			# print 'Parsed Response: '.Dumper($PRETTY_PARSEDXML_RESPONSE);

			## OKAY -- this right here is probably where we ought to handle high level API errors e.g.
			##		seller id is fucked, etc. (because they aren't really retry conditions)
			##	TODO: add this code later.
			}

		# $xml =~ s/xmlns=\"(.*?)\"//gs;

		# my ($msg) = XML::Simple::XMLin($xml,'ForceArray'=>1);
		## try to figure out what went wrong
		if (not defined $PRETTY_PARSEDXML_RESPONSE) {
			## yeah, more ocd error handling
			foreach my $SKU (@{$GroupOfSKUs}) {
				next if (defined $SKUS{$SKU}); # note: leave prior errors alone, since they're (hopefully) more meani
				## seriously: this error SHOULD NEVER be shown to anybody
				## because it indicates an earlier phase failed to handle it's shit properly.
				$SKUS{$SKU} = {
					'.status'=>'ise',
					'.msg'=>'Internal Logic Failure: sku error unspecified, and PRETTY_PARSEDXML_RESPONSE is not defined'
					};
				}
			}
		elsif (defined $PRETTY_PARSEDXML_RESPONSE->{'GetCompetitivePricingForSKUResult'}) {
			foreach my $msg (@{$PRETTY_PARSEDXML_RESPONSE->{'GetCompetitivePricingForSKUResult'}}) {
				#'.Product.Identifiers.SKUIdentifier.SellerId' => 'A2VJTIF5QBGOAS',
				#'.Product.Identifiers.MarketplaceASIN.MarketplaceId' => 'ATVPDKIKX0DER',
				#'.Product.Identifiers.SKUIdentifier.SellerSKU' => 'APPAREL-V:A800:A901',
				#'.Product.xmlns' => 'http://mws.amazonservices.com/schema/Products/2011-10-01',
				#'.Product.Identifiers.SKUIdentifier.MarketplaceId' => 'ATVPDKIKX0DER',
				#'.SellerSKU' => 'APPAREL-V:A800:A901',
				#'.Product.ns2' => 'http://mws.amazonservices.com/schema/Products/2011-10-01/default.xsd',
				#'.Product.Identifiers.MarketplaceASIN.ASIN' => 'B0078SIS1K',
				#'.AllOfferListingsConsidered' => 'true',
				#'.status' => 'Success'
				my ($node) = ZTOOLKIT::XMLUTIL::SXMLflatten($msg);
				# print 'Flattend Response: '. Dumper($node);
				if ($node->{'.status'} eq 'Success') {
					## it's all good bro.
					$node->{'.status'} = 'success';
					foreach my $k (keys %{$node}) {
						if ($k =~ /^\.Product\.CompetitivePricing\.CompetitivePrices/) {
							## these will be reutrned in offers so we can clear them out here.
							delete $node->{$k};
							}
						}

					my @OFFERS = ();
					foreach my $offernode (@{$msg->{'Product'}[0]->{'CompetitivePricing'}[0]->{'CompetitivePrices'}}) {
						my ($offer) = ZTOOLKIT::XMLUTIL::SXMLflatten($offernode);
						$offer->{'.type'} = 'CompetitivePrice';
						push @OFFERS, $offer;
						}
					$node->{'@OFFERS'} = \@OFFERS;
					# print Dumper($msg,$node); die();
					}
				elsif ($node->{'.status'} eq 'ClientError') {
					## a well formed error
					# '.status' => 'ClientError'
					# '.SellerSKU' => 'xyz23424',
					# '.Error.Message' => 'xyz23424 is an invalid SellerSKU for marketplace ATVPDKIKX0DER',
					# '.Error.Code' => 'InvalidParameterValue',
					# '.Error.Type' => 'Sender', 
					$node->{'.msg'} = sprintf("Amazon ClientError %s",$node->{'.Error.Message'});
					## note: we can override specific errors here
					if ($node->{'.SellerSKU'} eq '') {
						## WOW! wtf, seriously, those dickheads.
						$node->{'.msg'} = sprintf("Horrible Response from Amazon 1) .SellerSKU is blank, 2) %s",$node->{'.Error.Message'});
						}
					elsif ($node->{'.Error.Code'} eq 'InvalidParameterValue') {
						if ($node->{'.Error.Message'} =~ /invalid SellerSKU for marketplace/) {
							$node->{'.msg'} = sprintf("Amazon ClientError SKU %s is invalid for marketplace",$node->{'.SellerSKU'});
							}
						}					
					$node->{'.status'} = 'error';
					}
				elsif ($node->{'.status'} eq 'error') {
					## it's not good, but hopefully .msg will be set
					if (not defined $node->{'.msg'}) {
						$node->{'.msg'} = 'Amazon returned error, with no message for GetCompetitivePricingForSKUResult node';
						}
					}
				else {
					if (not defined $node->{'.msg'}) {
						$node->{'.msg'} = sprintf('Caught invalid .status: %s, within GetCompetitivePricingForSKUResult node',$node->{'.status'});
						}
					$node->{'.status'} = 'error';
					}

				$SKUS{ $node->{'.SellerSKU'} } = $node 

				
				}
			## do a quick double check to make sure that each of the SKUs in the GroupOfSKUs was covered in the response.
         foreach my $SKU (@{$GroupOfSKUs}) {
				next if (defined $SKUS{$SKU});	# hopefully an earlier error (or maybe even a success) was handled.
            $SKUS{ $SKU } = {
               '.status'=>'apierr',
               '.msg' => 'SKU was not included GetCompetitivePricingForSKUResult Result'
               };
            }

			}		
		else {
			## WTF happened here!?! holy shit. very bad response amazon, very bad response.
			## AND BAD ERROR HANDLING ON OUR SIDE AS WELL.
			foreach my $SKU (@{$GroupOfSKUs}) {
				next if (defined $SKUS{$SKU});	# hopefully an earlier error indicates the problem.
				$SKUS{ $SKU } = {
					'.status'=>'ise',
					'.msg' => 'Internal Logic Failure: sku error unspecified, and no GetCompetitivePricingForSKUResult'
					};				
				}
			}

		## a last ditch attempt to catch errors
		foreach my $SKU (@{$GroupOfSKUs}) {
			next if (defined $SKUS{$SKU});	# hopefully an earlier error indicates the problem.
			$SKUS{ $SKU } = {
				'.status'=>'ise',
				'.msg' => 'Internal Logic Failure: unhandled sku error within grouping loop'
				};				
			}
		}	

	## wtf, seriously, who the hell knows how we'd get here.
	foreach my $SKU (@{$SKUARRAY}) {
		next if (defined $SKUS{$SKU});	# hopefully an earlier error indicates the problem.
		$SKUS{ $SKU } = {
			'.status'=>'ise',
			'.msg' => 'Internal Logic Failure: unhandled sku error outside of grouping loop'
			};				
		}

	return(\%SKUS);
	}










sub lookupASIN { my ($userref,$SKU) = @_; return(&lookupASINs($userref,[$SKU])); }
sub lookupASINs {
	my ($userref,$SKUREF) = @_;

	my $ERROR = '';
	my $ASIN = '';

	## Amazon only allows us to lookup 5 skus at the same time.
	foreach my $batch (@{&ZTOOLKIT::batchify($SKUREF,5)}) {

		# GetMatchingProduct, GetCompetitivePricingForSKU, 
		# GetCompetitivePricingForASIN, GetLowestOfferListingsForSKU, and GetLowestOfferListingsForASIN.
		# https://mws.amazonservices.com/Products/2011-10-01?AWSAccessKeyId=AKIAJGUVGFGHNKE2NVUA
		my %p = ();
		$p{'Action'} = 'GetMatchingProductForId';
		$p{'Version'} = '2011-10-01';
	#	$p{'SellerSKUList.SellerSKU.1'} = $hashref->{'SKU'};
		$p{'SellerId'} = $userref->{'AMAZON_MERCHANTID'};	
		$p{'MarketplaceId'} = 'ATVPDKIKX0DER'; # $userref->{'AMAZON_MERCHANTID'};
		$p{'IdType'} = 'SellerSKU';
		my $i = 1;
		foreach my $SKU (@{$batch}) {
			## IdList.Id.1 .. IdList.Id.5
			$p{sprintf('IdList.Id.%d',$i++)} = $SKU;
			}
		print 'API Request: '.Dumper(\%p);

		## SANITY: at this point the request to amazon should be fully formed.
		my ($request_url, $head, $agent) = &AMAZON3::prep_header2($userref,\%p);
		my $request = HTTP::Request->new('POST',$request_url,$head);
		my $response = $agent->request($request);

		my $xml = $response->content();
		# $xml =~ s/xmlns=\"(.*?)\"//gs;
		my ($sh) = IO::String->new(\$xml);

		open F, ">/tmp/foo";
		print F $xml;
		close F;

		# my ($msg) = XML::Simple::XMLin($xml,'ForceArray'=>1);
		my ($msg) = XML::SAX::Simple::XMLin($sh,ForceArray=>1);
		&ZTOOLKIT::XMLUTIL::stripNamespace($msg);

		print 'Parsed Response: '.Dumper($msg);
		my ($ref) = ZTOOLKIT::XMLUTIL::SXMLflatten($msg);
		print 'Flattend Response: '. Dumper($ref);

		if ($ref->{'.GetMatchingProductForIdResult.status'} ne 'Success') {
			$ERROR = sprintf("API call returned %s",$ref->{'.GetMatchingProductForIdResult.status'});
			}
		elsif ($ref->{'.GetMatchingProductForIdResult.IdType'} eq 'SellerSKU') {
			my $PARENT_ASIN = $ref->{'.GetMatchingProductForIdResult.Products.Product.Relationships.VariationParent.Identifiers.MarketplaceASIN.ASIN'};
			$ASIN = $ref->{'.GetMatchingProductForIdResult.Products.Product.Identifiers.MarketplaceASIN.ASIN'};
			}
		else {
			$ERROR = "Unknown response";
			}
	
		}


	return($ASIN,$ERROR);
	}



