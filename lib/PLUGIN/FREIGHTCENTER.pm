package PLUGIN::FREIGHTCENTER;

use strict;
use lib "/backend/lib";

# shit- well here is freightquote.
#freightquote
#un: nickd@zoovy.com
#pw: robot!sush1

#
# https://www.freightcenter.com/sandboxfreightcenterWS/RatingService.asmx?WSDL
#
# perl -e 'use lib "lib"; use MyInterfaces::RatingService::RatingServiceSoap; my ($interface) = MyInterfaces::RatingService::RatingServiceSoap->new(); $response = $interface->HelloWorld( { name=>"Foo" }); print $response."\n"'
#
# wsdl2perl.pl -t FREIGHTCENTER -e FREIGHTCENTER -m FREIGHTCENTER -i FREIGHTCENTER file:RatingService.asmx\?WSDL -b .
#

use LWP::UserAgent;
use IO::String;
use XML::Writer;
require ZOOVY;



sub doRequest {
	my ($io) = IO::String->new();

	my $LICENSE = 'abde9758-45bb-4ddd-92b1-fb2a885ee7b1';
	my $USERNAME = 'lizm@zoovy.com';
	my $PASSWORD = 'password';

	my $writer = new XML::Writer(OUTPUT => $io);
	$writer->startTag("RateRequest",
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xmlns:xsd" => "http://www.w3.org/2001/XMLSchema",
		"LicenseKey" => $LICENSE,
		"Username"=>$USERNAME,
		"Password"=>$PASSWORD,
		"xmlns"=>"http://www.freightcenter.com/XMLSchema",
		);


#	$writer->characters("Hello, world!");

#
#<RateRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="" LicenseKey=" 726afc66-28" Username="xxx@x.com" Password="xxx" >
#	$writer->dataElement('OriginZipCode',34655);
  $writer->dataElement('OriginZipCode','34655');
  $writer->dataElement('OriginLocationType','BusinessWithDockOrForklift');
  $writer->dataElement('DestinationZipCode','70816');
  $writer->dataElement('DestinationLocationType','BusinessWithDockOrForklift');
  $writer->startTag('Items');
    $writer->startTag('Item');
      $writer->dataElement('Description','Item 1');
      $writer->dataElement('PackagingCode','Boxed');
      $writer->dataElement('Quantity','1');
      $writer->startTag('Dimensions');
        $writer->dataElement('Length','10');
        $writer->dataElement('Width','20');
        $writer->dataElement('Height','30');
        $writer->dataElement('UnitOfMeasure','in');
      $writer->endTag('Dimensions');
      $writer->dataElement('FreightClass','50');
      $writer->startTag('Weight');
        $writer->dataElement('WeightAmt','100');
        $writer->dataElement('UnitOfMeasure','lbs');
      $writer->endTag('Weight');
    $writer->endTag('Item');
    $writer->startTag('Item');
      $writer->dataElement('Description','Item 2');
      $writer->dataElement('PackagingCode','Crated');
      $writer->dataElement('Quantity','1');
      $writer->startTag('Dimensions');
        $writer->dataElement('Length','0');
        $writer->dataElement('Width','0');
        $writer->dataElement('Height','0');
        $writer->dataElement('UnitOfMeasure','in');
      $writer->endTag('Dimensions');
      $writer->dataElement('FreightClass','77.5');
      $writer->startTag('Weight');
        $writer->dataElement('WeightAmt','200');
        $writer->dataElement('UnitOfMeasure','lbs');
      $writer->endTag('Weight');
    $writer->endTag('Item');
  $writer->endTag('Items');
  $writer->startTag('Accessorials');
    $writer->startTag('Accessorial');
      $writer->dataElement('AccessorialCode','ORIGIN_LIFT_GATE');
    $writer->endTag('Accessorial');
    $writer->startTag('Accessorial');
      $writer->dataElement('AccessorialCode','ORIGIN_RESIDENT_PU');
    $writer->endTag('Accessorial');
    $writer->startTag('Accessorial');
      $writer->dataElement('AccessorialCode','DEST_LIFT_GATE');
    $writer->endTag('Accessorial');
  $writer->endTag('Accessorials');
  $writer->startTag('Filters');
    $writer->dataElement('Mode','LTL');
    $writer->startTag('CarrierFilter');
      $writer->dataElement('CarrierFilterType','include');
      $writer->startTag('Carrier');
        $writer->dataElement('CarrierCode','YRC_Freight');
      $writer->endTag('Carrier');
      $writer->startTag('Carrier');
        $writer->dataElement('CarrierCode','R_L_CARRIERS');
        $writer->dataElement('Services','RLCARRIERS');
        $writer->dataElement('Services','RLCARRIERS_GUARANTEED_AM');
        $writer->dataElement('Services','RLCARRIERS_GUARANTEED');
      $writer->endTag('Carrier');
    $writer->endTag('CarrierFilter');
  $writer->endTag('Filters');
	$writer->endTag("RateRequest");
	$writer->end();
#	$io->close();

	my $string = ${$io->string_ref()};



	# $string = &ZOOVY::incode($string);	

	my $message = qq~<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
	<GetRates xmlns="http://freightcenter.com/">
	<InputXML>$string</InputXML>
	</GetRates>
  </soap:Body>
</soap:Envelope>
~;
	# print ${$io->string_ref()};

	$message = qq~<?xml version="1.0" encoding="utf-8"?>\n$message~;
	
	use XML::Simple;
	my ($x) = XML::Simple::XMLin($message);
#	print Dumper($x); die();

	use LWP::UserAgent;
	use XML::Simple;
	# Declare constants
	my $ua = new LWP::UserAgent;
	my $xs = new XML::Simple;

	# Now send message
	use HTTP::Request::Common;
	use URI::Escape;
	my $URI = 'https://www.freightcenter.com/sandboxfreightcenterWS/RatingService.asmx/GetRates?InputXML='.URI::Escape::uri_escape($string);
	my $reply = $ua->request(GET $URI,
		# SOAPAction => 'http://freightcenter.com/GetRates',
		# Content_Type => 'application/soap+xml',
		#Content_Type => 'text/xml; charset=utf-8',
		# Content => ,
		);

	use Data::Dumper;
	print Dumper($reply);
	}




1;


__DATA__

<?xml version="1.0" encoding="utf-8"?>
<RateResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.freightcenter.com/XMLSchema">
  <TransactionResponse>
    <Type>SUCCESS</Type>
    <MessageNumber>200</MessageNumber>
    <Message>Rates Successfully generated from FeightCenter.</Message>
    <DateTime>8/25/2009 12:51:25 AM</DateTime>
    <RefId>183</RefId>
  </TransactionResponse>
  <Rates>
    <CarrierRate>
      <RateId>1655</RateId>
      <CarrierName>R + L Carriers</CarrierName>
      <CarrierCode>R_L_CARRIERS</CarrierCode>
      <Mode>LTL</Mode>
      <ServiceDays>2</ServiceDays>
      <ServiceName>R + L Carriers</ServiceName>
      <ServiceCode>RLCARRIERS</ServiceCode>
      <TotalCharge>225.90</TotalCharge>
      <ChargeDetails>
        <BaseCharge>190.90</BaseCharge>
        <AccessorialCharge>
          <AccessorialName>Lift Gate at Pickup Point</AccessorialName>
          <AccessorialChargeAmount>0.00</AccessorialChargeAmount>
        </AccessorialCharge>
        <AccessorialCharge>
          <AccessorialName>Lift Gate at Delivery Point</AccessorialName>
          <AccessorialChargeAmount>0.00</AccessorialChargeAmount>
        </AccessorialCharge>
        <AccessorialCharge>
          <AccessorialName>Residential Pickup</AccessorialName>
          <AccessorialChargeAmount>35.00</AccessorialChargeAmount>
        </AccessorialCharge>
      </ChargeDetails>
    </CarrierRate>
    <CarrierRate>
      <RateId>1656</RateId>
      <CarrierName>YRC Freight </CarrierName>
      <CarrierCode>YRC_FREIGHT</CarrierCode>
      <Mode>LTL</Mode>
      <ServiceDays>2</ServiceDays>
      <ServiceName>Yellow Freight  -  Roadway (YRC)</ServiceName>
      <ServiceCode>YRC</ServiceCode>
      <TotalCharge>320.82</TotalCharge>
      <ChargeDetails>
        <BaseCharge>180.82</BaseCharge>
        <AccessorialCharge>
          <AccessorialName>Lift Gate at Pickup Point</AccessorialName>
          <AccessorialChargeAmount>45.00</AccessorialChargeAmount>
        </AccessorialCharge>
        <AccessorialCharge>
          <AccessorialName>Lift Gate at Delivery Point</AccessorialName>
          <AccessorialChargeAmount>45.00</AccessorialChargeAmount>
        </AccessorialCharge>
        <AccessorialCharge>
          <AccessorialName>Residential Pickup</AccessorialName>
          <AccessorialChargeAmount>50.00</AccessorialChargeAmount>
        </AccessorialCharge>
      </ChargeDetails>
    </CarrierRate>
    <CarrierRate>
      <RateId>1657</RateId>
      <CarrierName>R + L Carriers</CarrierName>
      <CarrierCode>R_L_CARRIERS</CarrierCode>
      <Mode>LTL</Mode>
      <ServiceDays>2</ServiceDays>
      <ServiceName>R + L Carriers ** Guaranteed **</ServiceName>
      <ServiceCode>RLCARRIERS_GUARANTEED</ServiceCode>
      <TotalCharge>355.16</TotalCharge>
      <ChargeDetails>
        <BaseCharge>320.16</BaseCharge>
        <AccessorialCharge>
          <AccessorialName>Lift Gate at Pickup Point</AccessorialName>
          <AccessorialChargeAmount>0.00</AccessorialChargeAmount>
        </AccessorialCharge>
        <AccessorialCharge>
          <AccessorialName>Lift Gate at Delivery Point</AccessorialName>
          <AccessorialChargeAmount>0.00</AccessorialChargeAmount>
        </AccessorialCharge>
        <AccessorialCharge>
          <AccessorialName>Residential Pickup</AccessorialName>
          <AccessorialChargeAmount>35.00</AccessorialChargeAmount>
        </AccessorialCharge>
      </ChargeDetails>
    </CarrierRate>
    <CarrierRate>
      <RateId>1658</RateId>
      <CarrierName>R + L Carriers</CarrierName>
      <CarrierCode>R_L_CARRIERS</CarrierCode>
      <Mode>LTL</Mode>
      <ServiceDays>2</ServiceDays>
      <ServiceName>R + L Carriers **Guaranteed AM**</ServiceName>
      <ServiceCode>RLCARRIERS_GUARANTEED_AM</ServiceCode>
      <TotalCharge>432.35</TotalCharge>
      <ChargeDetails>
        <BaseCharge>397.35</BaseCharge>
        <AccessorialCharge>
          <AccessorialName>Lift Gate at Pickup Point</AccessorialName>
          <AccessorialChargeAmount>0.00</AccessorialChargeAmount>
        </AccessorialCharge>
        <AccessorialCharge>
          <AccessorialName>Lift Gate at Delivery Point</AccessorialName>
          <AccessorialChargeAmount>0.00</AccessorialChargeAmount>
        </AccessorialCharge>
        <AccessorialCharge>
          <AccessorialName>Residential Pickup</AccessorialName>
          <AccessorialChargeAmount>35.00</AccessorialChargeAmount>
        </AccessorialCharge>
      </ChargeDetails>
    </CarrierRate>
    <CarrierRate>
      <RateId>1659</RateId>
      <CarrierName>YRC Freight </CarrierName>
      <CarrierCode>YRC_FREIGHT</CarrierCode>
      <Mode>LTL</Mode>
      <ServiceDays>2</ServiceDays>
      <ServiceName>YRC **Guaranteed Standard Transit by 5 PM**</ServiceName>
      <ServiceCode>YRC_GUARANTEED_5_PM</ServiceCode>
      <TotalCharge>454.00</TotalCharge>
      <ChargeDetails>
        <BaseCharge>319.00</BaseCharge>
        <AccessorialCharge>
          <AccessorialName>Lift Gate at Pickup Point</AccessorialName>
          <AccessorialChargeAmount>45.00</AccessorialChargeAmount>
        </AccessorialCharge>
        <AccessorialCharge>
          <AccessorialName>Lift Gate at Delivery Point</AccessorialName>
          <AccessorialChargeAmount>45.00</AccessorialChargeAmount>
        </AccessorialCharge>
        <AccessorialCharge>
          <AccessorialName>Residential Pickup</AccessorialName>
          <AccessorialChargeAmount>45.00</AccessorialChargeAmount>
        </AccessorialCharge>
      </ChargeDetails>
    </CarrierRate>
  </Rates>
</RateResponse>
