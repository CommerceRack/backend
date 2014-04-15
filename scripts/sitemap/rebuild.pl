#!/usr/bin/perl

use lib "/backend/lib";
use Data::Dumper;
use DOMAIN::QUERY;

my $USERNAME = $ARGV[0];
my $HOSTDOMAIN = $ARGV[1];

use JSONAPI;
my ($JSAPI) = JSONAPI->new('__config.js__');
$JSAPI->{'USERNAME'} = $USERNAME;
$JSAPI->{'PRT'} = 0;
my ($DNSINFO) = &DOMAIN::QUERY::lookup($HOSTDOMAIN);
if (defined $DNSINFO) {
	$JSAPI->{'SDOMAIN'} = $DNSINFO->{'DOMAIN'};
	$JSAPI->{'_PROJECTID'} = $DNSINFO->{'PROJECT'};
	}

my ($udbh) = &DBINFO::db_user_connect($USERNAME);
my $qtHOSTDOMAIN = $udbh->quote($HOSTDOMAIN);
my $pstmt = "select GUID from SEO_PAGES where DOMAIN=$qtHOSTDOMAIN order by ID desc limit 0,1;";
my ($TOKEN) = $udbh->selectrow_array($pstmt);
&DBINFO::db_user_close();

print Dumper($JSAPI->appSEO({'_cmd'=>'adminSEOInit','token'=>$TOKEN,'hostdomain'=>$HOSTDOMAIN}));

print Dumper($JSAPI->appSEO({'_cmd'=>'appSEOFinish','token'=>$TOKEN}));
