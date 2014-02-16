package PLUGIN::SILVERPOP;

use strict;

use lib "/backend/lib";
require ZOOVY;

use LWP::UserAgent;


sub notify {
	my ($cart,$listid,$visitorid) = @_;

	my $ua = LWP::UserAgent->new;
	$ua->timeout(2);
	#$ua->env_proxy;

	my $email = $cart->fetch_property('data.bill_email');

	my %hash = ();
	$hash{'visitor_id'} = $visitorid;
	$hash{'Visitor_Id'} = $visitorid;
	$hash{'VISITOR_ID'} = $visitorid;
	$hash{'VISITOR ID'} = $visitorid;
	$hash{'Visitor Id'} = $visitorid;
	$hash{'First Name'} = $cart->fetch_property('data.bill_firstname');
	$hash{'Last Name'} = $cart->fetch_property('data.bill_lastname');
	$hash{'Address1'} = $cart->fetch_property('data.bill_address1');
	$hash{'Address2'} = $cart->fetch_property('data.bill_address2');
	$hash{'City'} = $cart->fetch_property('data.bill_city');
	$hash{'State'} = $cart->fetch_property('data.bill_state');
	$hash{'ZipCode'} = $cart->fetch_property('data.bill_zip');
	$hash{'Phone'} = $cart->fetch_property('data.bill_phone');
	$hash{'Email'} = $email;
	my $xmlcolumns = '';
	foreach my $k (keys %hash) {
		$xmlcolumns .= "<COLUMN><NAME>$k</NAME><VALUE>".&ZOOVY::incode($hash{$k})."</VALUE></COLUMN>";
		}

#<Column><FirstName></FirstName></Column>
#<Column><LastName></LastName></Column>
#Last Name
#Address 1
#Address 2
#City
#State
#Zip Code
#Phone
#Email
	
	my $xml = qq~<Envelope><Body>
<AddRecipient>
<LIST_ID>$listid</LIST_ID>
<CREATED_FROM>2</CREATED_FROM>
<EMAIL>$email</EMAIL>
$xmlcolumns
</AddRecipient></Body>
</Envelope>~;

#	print STDERR "XML: $xml\n";

	my $url = "http://api2.silverpop.com/XMLAPI?xml=".URI::Escape::uri_escape($xml);
	my $response = $ua->get($url);
	
	use Data::Dumper;
	open F, ">>/tmp/silverpop";
	print F Dumper($response);
	close F;

	if ($response->is_success) {
		warn $response->content;
		}
	else {
		warn $response->status_line;
		}
	}


1;