package PLUGIN::TWITTER;

use strict;

use Net::Twitter;
use Digest::MD5;
use lib "/backend/lib";

##
##
##

##
##
sub usertweet {
	my ($USERNAME,$PRT,$msg) = @_;

	my $ref = undef;
	require ZWEBSITE;
	my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,$PRT);
	require ZTOOLKIT;
	if ($webdb->{'twitter'} ne '') {
		$ref = &ZTOOLKIT::parseparams($webdb->{'twitter'});
		}
	if (defined $ref) {
		&PLUGIN::TWITTER::sendtweet($msg,$ref);
		}

	if (not defined $ref) {
		}


	}


##
##
##
sub sendtweet {
	my ($msg,$ref) = @_;

	if (not defined $ref) {
		&PLUGIN::TWITTER::zoovytweet('zoovydev',$msg);		
		}

	# source zoovy
	# source zoovyinc
	# source brianhorakh
	# source Zoovy, Inc.
	#my $twit = Net::Twitter->new({
	#		# username=>"brian\@zoovy.com", password=>"asdfasdf1", 
	#		username=>$TWITTER_USERNAME, password=>$TWITTER_PASSWORD,
	#		clientname=>"Zoovy Inc",
	#		clientver=>"1.00",
	#		clienturl=>"http://www.zoovy.com",
	#		source=>"brianhorakh" 
	#		});
	# print "SECRET: $TWITTER_ACCESS_SECRET\n";

	my $nt = Net::Twitter->new(
		traits   => [qw/OAuth API::REST/],
		consumer_key        => $ref->{'consumer_key'},
		consumer_secret     => $ref->{'consumer_secret'},
		access_token        => $ref->{'access_token'},
		access_token_secret => $ref->{'access_secret'},
		);

	$msg = substr($msg,0,140);
	my $result = $nt->update({status => "$msg"});
	# print Dumper($nt->get_error());
	if ( my $err = $@ ) {
		die $@ unless blessed $err && $err->isa("Net::Twitter::Error");
		warn "HTTP Response Code: ", $err->code, "\n",
     			"HTTP Message......: ", $err->message, "\n",
            "Twitter error.....: ", $err->error, "\n";
         }

	
	use Data::Dumper; print Dumper($result);
	}

1;

