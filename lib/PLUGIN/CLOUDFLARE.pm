package PLUGIN::CLOUDFLARE;



sub run {
	my $CloudFlare = WebService::CloudFlare::Host->new(
   	host_key => $PLUGIN::CLOUDFLARE::API_KEY,
		timeout  => 30,
		);
	}



1;