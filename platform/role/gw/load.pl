#!/usr/bin/perl

use Data::Dumper;
use lib "/httpd/modules";
use DBINFO;


##
## subnet strategy
##		we use a /28 -- 16 address per subnet strategy  255.255.255.240 is the subnet mask
##	
##	0 .is network	
##	1. is router
##	2-14	is host
##	
## 16. is network
##	17. is router
##	18-
##

use Net::Netmask;

my @TODO = ();
push @TODO, [ 'bespin',		'208.74.187.0/28',+0 ];
push @TODO, [ 'bespin',		'208.74.187.0/28',+1 ];
push @TODO, [ 'crackle',	'208.74.187.0/28',+2 ];
push @TODO, [ 'crackle',	'208.74.187.0/28',+3 ];
push @TODO, [ 'crackle',	'208.74.187.0/28',+4 ];
push @TODO, [ 'pop', 		'208.74.187.0/28',+5 ];
push @TODO, [ 'pop', 		'208.74.187.0/28',+6 ];
push @TODO, [ 'pop', 		'208.74.187.0/28',+7 ];
push @TODO, [ 'dagobah', 	'208.74.187.0/28',+8 ];
push @TODO, [ 'dagobah', 	'208.74.187.0/28',+9 ];
push @TODO, [ 'hoth', 		'208.74.187.0/28',+10 ];
push @TODO, [ 'hoth', 		'208.74.187.0/28',+11 ];
push @TODO, [ 'crackle',	'208.74.187.0/28',+12 ];

my %CLUSTERS = ();
$CLUSTERS{'bespin'} = '208.74.184.169';
$CLUSTERS{'hoth'} = 	'208.74.184.152';
$CLUSTERS{'crackle'}= '208.74.184.88';
$CLUSTERS{'pop'} = 	'208.74.184.120';
$CLUSTERS{'dagobah'}= '208.74.184.136';

## bespin 0 
## hoth   1
## crackle 2,3,4
## pop  5,6,7

foreach my $TODO (@TODO) {
	my $CLUSTER = $TODO->[0];
	my ($block) = Net::Netmask->new($TODO->[1]);
	$block = $block->nextblock($TODO->[2]);

	my ($udbh) = &DBINFO::db_user_connect("\@$CLUSTER");
	
	my @IPS = $block->enumerate();
	shift @IPS;	# burn the network address
	pop @IPS;	# burn the broadcast address
	foreach my $IP (@IPS) {

		my $pstmt = "select ID from SSL_IPADDRESSES where IP_ADDR='$IP' order by ID";
		my ($ID) = $udbh->selectrow_array($pstmt);
		next if ($ID>0);

		my $VERB = 'insert';
		my $pstmt = &DBINFO::insert($udbh,'SSL_IPADDRESSES',{
			ID=>$ID,
			IP_ADDR=>$IP,
			NETWORK=>$block->desc(),
			},verb=>$VERB,sql=>1,key=>['ID']);
		print STDERR "$pstmt\n";
		$udbh->do($pstmt);
		}

	print "\n";
	print sprintf("# $CLUSTER NET: %s BROADCAST:%s\n",$block->first(),$block->last());
	print sprintf("ip route %s %s %s\n",$block->base(),$block->mask(),$CLUSTERS{$CLUSTER});
	}


&DBINFO::db_user_close();

__DATA__

## bespin
ip route 208.74.187.0 255.255.255.240 208.74.184.169
## hoth
ip route 208.74.187.16 255.255.255.240 208.74.184.152
## crackle
ip route 208.74.187.32 255.255.255.240 208.74.184.88
ip route 208.74.187.48 255.255.255.240 208.74.184.88
ip route 208.74.187.64 255.255.255.240 208.74.184.88
## pop
ip route 208.74.187.80 255.255.255.240 208.74.184.120
ip route 208.74.187.96 255.255.255.240 208.74.184.120
ip route 208.74.187.112 255.255.255.240 208.74.184.120
## dagobah
ip route 208.74.187. 255.255.255.240 208.74.184.136
