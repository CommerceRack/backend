package ZTOOLKIT::VOICE;


sub make_call {
	my $xml = q~<campaign menuid="34896-482723414" username="zoovy" password="password1" action="0">
<prompts>
<prompt promptid="1" tts="Amazon Static A, thinks Zoovy system is down." />
</prompts>
<phonenumbers>
<phonenumber number="7604199953" callid="Static-A" callerid="8779668948" />
</phonenumbers>
</campaign>~;

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

require HTTP::Headers;
my $h = HTTP::Headers->new;
$h->header('Content-Type'=>'text/xml');
$h->header('Content-Length'=>length($xml));

my $request = HTTP::Request->new('POST','http://api.voiceshot.com/ivrapi.asp',$h);
$request->content($xml);

my $response = $ua->request($request);

use Data::Dumper;
print Dumper($response);
	}




############### STRIKE IRON CODE IS BELOW (NOT USED) #########################

#	my $url = 'http://ws.strikeiron.com/StrikeIron/IVRVoiceNotification/Notify/getVoices?';
#	$url .= 'LicenseInfo.RegisteredUser.UserID=brianh@zoovy.com'; # UserID=ABA9FF856015BD485448';
#	$url .= '&LicenseInfo.RegisteredUser.Password=password1'; # UserID=ABA9FF856015BD485448';
#	$url .= '&getVoices';
#
#<WebServiceResponse xmlns="http://ws.strikeiron.com">
#    <SubscriptionInfo xmlns="http://ws.strikeiron.com">
#      <LicenseStatusCode>0</LicenseStatusCode>
#      <LicenseStatus>Valid license key</LicenseStatus>
#      <LicenseActionCode>7</LicenseActionCode>
#      <LicenseAction>No hit deduction for invocation</LicenseAction>
#      <RemainingHits>5</RemainingHits>
#      <Amount>0</Amount>
#    </SubscriptionInfo>
#
#    <getVoicesResponse xmlns="http://www.strikeiron.com">
#      <getVoicesResult>
#        <ServiceStatus>
#          <StatusNbr>200</StatusNbr>
#          <StatusDescription>Valid</StatusDescription>
#        </ServiceStatus>
#        <ServiceResult>
#          <Count>11</Count>
#          <Voices>
#            <Voice>
#              <VoiceID>0</VoiceID>
#              <VoiceName>Diane</VoiceName>
#              <VoiceGender>Female</VoiceGender>
#              <VoiceAge>35</VoiceAge>
#              <VoiceLanguage>US English</VoiceLanguage>
#              <VoiceSummary>Diane - US English (Female - 35)</VoiceSummary>
#            </Voice>
#            <Voice>
#              <VoiceID>1</VoiceID>
#              <VoiceName>David</VoiceName>
#              <VoiceGender>Male</VoiceGender>
#              <VoiceAge>30</VoiceAge>
#              <VoiceLanguage>US English</VoiceLanguage>
#              <VoiceSummary>David - US English (Male - 30)</VoiceSummary>
#            </Voice>
#            <Voice>
#              <VoiceID>2</VoiceID>
#              <VoiceName>William</VoiceName>
#              <VoiceGender>Male</VoiceGender>
#              <VoiceAge>30</VoiceAge>
#              <VoiceLanguage>US English</VoiceLanguage>
#              <VoiceSummary>William - US English (Male - 30)</VoiceSummary>
#            </Voice>
#            <Voice>
#              <VoiceID>3</VoiceID>
#              <VoiceName>Emily</VoiceName>
#              <VoiceGender>Female</VoiceGender>
#              <VoiceAge>30</VoiceAge>
#              <VoiceLanguage>US English</VoiceLanguage>
#              <VoiceSummary>Emily - US English (Female - 30)</VoiceSummary>
#            </Voice>
#            <Voice>
#              <VoiceID>4</VoiceID>
#              <VoiceName>Callie</VoiceName>
#              <VoiceGender>Female</VoiceGender>
#              <VoiceAge>30</VoiceAge>
#              <VoiceLanguage>US English</VoiceLanguage>
#              <VoiceSummary>Callie - US English (Female - 30)</VoiceSummary>
#            </Voice>
#            <Voice>
#              <VoiceID>5</VoiceID>
#              <VoiceName>Lawrence</VoiceName>
#              <VoiceGender>Male</VoiceGender>
#              <VoiceAge>55</VoiceAge>
#              <VoiceLanguage>UK English</VoiceLanguage>
#              <VoiceSummary>Lawrence - UK English (Male - 55)</VoiceSummary>
#            </Voice>
#            <Voice>
#              <VoiceID>6</VoiceID>
#              <VoiceName>Millie</VoiceName>
#              <VoiceGender>Female</VoiceGender>
#              <VoiceAge>45</VoiceAge>
#              <VoiceLanguage>UK English</VoiceLanguage>
#              <VoiceSummary>Millie - UK English (Female - 45)</VoiceSummary>
#            </Voice>
#            <Voice>
#              <VoiceID>7</VoiceID>
#              <VoiceName>Isabelle</VoiceName>
#              <VoiceGender>Female</VoiceGender>
#              <VoiceAge>30</VoiceAge>
#              <VoiceLanguage>Canadian French</VoiceLanguage>
#              <VoiceSummary>Isabelle - Canadian French (Female - 30)</VoiceSummary>
#            </Voice>
#            <Voice>
#              <VoiceID>8</VoiceID>
#              <VoiceName>Katrin</VoiceName>
#              <VoiceGender>Female</VoiceGender>
#              <VoiceAge>35</VoiceAge>
#              <VoiceLanguage>German</VoiceLanguage>
#              <VoiceSummary>Katrin - German (Female - 35)</VoiceSummary>
#            </Voice>
#            <Voice>
#              <VoiceID>9</VoiceID>
#              <VoiceName>Marta</VoiceName>
#              <VoiceGender>Female</VoiceGender>
#              <VoiceAge>30</VoiceAge>
#              <VoiceLanguage>Americas Spanish</VoiceLanguage>
#              <VoiceSummary>Marta - Americas Spanish (Female - 30)</VoiceSummary>
#            </Voice>
#            <Voice>
#              <VoiceID>10</VoiceID>
#              <VoiceName>Vittoria</VoiceName>
#              <VoiceGender>Female</VoiceGender>
#              <VoiceAge>30</VoiceAge>
#              <VoiceLanguage>Italian</VoiceLanguage>
#              <VoiceSummary>Vittoria - Italian (Female - 30)</VoiceSummary>
#            </Voice>
#          </Voices>
#        </ServiceResult>
#      </getVoicesResult>
#    </getVoicesResponse>
#  </WebServiceResponse>


#sub STRIKEIRON_make_call {
#	my ($code) = @_;
#
#	require LWP::UserAgent;
#	# my $url = 'http://ws.strikeiron.com/HouseofDev/CurrencyRates160/CurrencyRates/getRate?LicenseInfo.RegisteredUser.UserID=ABA9FF856015BD485448&getRate.CurrencyCode='.$code;
#	my $url = 'http://ws.strikeiron.com/StrikeIron/IVRVoiceNotification/Notify/NotifyPhoneBasic';
#	# $url .= 'LicenseInfo.RegisteredUser.UserID=ABA9FF856015BD485448';
#	$url .= '?LicenseInfo.RegisteredUser.UserID=brianh@zoovy.com'; # UserID=ABA9FF856015BD485448';
#	$url .= '&LicenseInfo.RegisteredUser.Password=password1'; # UserID=ABA9FF856015BD485448';
#	$url .= '&NotifyPhoneBasic.PhoneNumberToDial=7604199953';
#	$url .= '&NotifyPhoneBasic.TextToSay=Good Evening, There is a High Priority Ticket 1234 from secondact';
#	$url .= '&NotifyPhoneBasic.CallerID=0000000000';
#	$url .= '&NotifyPhoneBasic.CallerIDname=test';
#	$url .= '&NotifyPhoneBasic.VoiceID=0';
#	# $url .= '&getRate.CurrencyCode='.$code;
#
#	print "URL: $url\n";
#	my $ua = LWP::UserAgent->new;
#
#	my $response = $ua->get($url);
#
#	my $xml = 0;
#	if ($response->is_success) {
#		$xml = $response->content;
#		}
#	else {
#		die $response->status_line;
#		}
#
#	print "XML: $xml\n";
#
#	#my $rate = undef;
#	#if ($xml =~ /<getRateResult>([\d.]+)<\/getRateResult>/) {
#	#	$rate = $1;
#	#	}
#	}
	



1;