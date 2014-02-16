package PLUGIN::STRIKEIRON;

#!/usr/bin/perl

# This sample code file uses the SOAP::Lite extension to invoke the web service
use SOAP::Lite maptype => {};

# creates a web service client object and binds it to the web service endpoint
my $service = SOAP::Lite
   -> uri($callNs)
   -> on_action( sub { join '/', 'http://www.strikeiron.com', $_[1] } )
   -> proxy('http://ws.strikeiron.com/StrikeIron/SMSAlerts4/GlobalSMSPro');

# defines web service operation
my $method = SOAP::Data->name('SendMessage')->attr({xmlns => 'http://www.strikeiron.com'});

# provide authentication credentials here
my $userID = 'ABA9FF856015BD485448';
my $password = 'Your Password';

# constructs SOAP header for web service request, which will store authentication credentials
my $header = SOAP::Header->name(LicenseInfo => \SOAP::Header->name(RegisteredUser => {
             UserID => $userID, Password => $password}))->uri('http://ws.strikeiron.com')->prefix('');

# defines input parameters for web service call
my $toNumber = '+19195551212'; #number to which message will be sent
my $fromName = 'StrikeIron'; #appears in the BODY of the SMS message
my $messageText = 'This is a test message.'; #text of message

# add all web service inputs to an array
my @params = ($header, SOAP::Data->name("ToNumber" => $toNumber)->type('string'),
                       SOAP::Data->name("FromName" => $fromName)->type('string'),
                       SOAP::Data->name("MessageText" => $messageText)->type('string'));

# calls web service; note that for simplicity, there is only minimal error handling in this sample code file
# a production application should have appropriate multi-level error handling on any remote callout

my $result = $service->call($method, @params);

# displays error message if one exists
if ($result->fault)
{
  print "Soap fault generated: " . $result->faultstring
}

# otherwise displays result from a successful invocation
else {
  print "StatusNbr: " . $result->valueof('//SendMessageResponse/SendMessageResult/ServiceStatus/StatusNbr') . "\n";
  print "StatusDescription: " . $result->valueof('//SendMessageResponse/SendMessageResult/ServiceStatus/StatusDescription') . "\n\n";

  print "Ticket: " . $result->valueof('//SendMessageResponse/SendMessageResult/ServiceResult/Ticket') . "\n";
  print "StatusExtra: " . $result->valueof('//SendMessageResponse/SendMessageResult/ServiceResult/StatusExtra') . "\n";
  print "WelcomeMessageSent: " . $result->valueof('//SendMessageResponse/SendMessageResult/ServiceResult/WelcomeMessageSent') . "\n";
}

