#!/usr/bin/perl

use Data::Dumper;
use JSON::XS;
use lib "/httpd/modules";
use DOMAIN;
use ZOOVY;

=pod

Hello World client

Connects REQ socket to tcp://localhost:5555

Author: Daisuke Maki (lestrrat)
Original version Author: Alexander D'Archangel (darksuji) <darksuji(at)gmail(dot)com>

=cut

#my 
my @USERS = ();

if ($ARGV[0]) {
	push @USERS, $ARGV[0]
	}


use strict;
use warnings;
use 5.10.0;

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(ZMQ_REQ ZMQ_DONTWAIT ZMQ_RCVTIMEO ZMQ_SNDTIMEO);
use JSON::XS;

my $context = zmq_init();
#my $socket = zmq_socket( $context );

my @SERVERS = (
	[ 'tcp://ec2-184-72-43-111.us-west-1.compute.amazonaws.com:5555' ],
	[ 'tcp://ec2-75-101-135-209.compute-1.amazonaws.com:5555' ],
	);

foreach my $row (@SERVERS) {
	# Socket to talk to server
	say "Connecting to server: $row->[0]";
	$row->[1] = my $socket = zmq_socket($context, ZMQ_REQ);
	zmq_connect($socket, $row->[0]);
	zmq_setsockopt($socket, ZMQ_RCVTIMEO, 5000);
	zmq_setsockopt($socket, ZMQ_SNDTIMEO, 5000);
	}


foreach my $USERNAME (@USERS) {
   my $CLUSTER = lc(&ZOOVY::resolve_cluster($USERNAME));
   my ($udbh) = &DBINFO::db_user_connect($USERNAME);

	my @DOMAINS = ();
   my ($MID) = &ZOOVY::resolve_mid($USERNAME);
   my ($pstmt) = "select DOMAIN from DOMAINS where MID=$MID order by DOMAIN";
	my ($sth) = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($DOMAIN) = $sth->fetchrow() ) {
		push @DOMAINS, $DOMAIN;
		}
	$sth->finish();

	my @CMDS = ();
	#push @CMDS, { '_uuid'=>"$USERNAME!nuke", '_cmd'=>'dns-user-delete' };

	my $VIP = DOMAIN::whatis_public_vip();
	push @CMDS, { '_uuid'=>"$USERNAME\@static", '_cmd'=>'dns-wildcard-reserve', 'zone'=>'app-hosted.com', 'host'=>sprintf("static---%s",$USERNAME), 'ipv4'=>$VIP };

	my $VIP = DOMAIN::whatis_public_vip();
	push @CMDS, { '_uuid'=>"$USERNAME\@static", '_cmd'=>'dns-wildcard-reserve', 'zone'=>'app-hosted.com', 'host'=>sprintf("admin---%s",$USERNAME), 'ipv4'=>$VIP };

	for my $DOMAIN (@DOMAINS) {
		my ($D) = DOMAIN->new($USERNAME,$DOMAIN);

		# push @CMDS, { '_uuid'=>"$USERNAME\@$DOMAIN", '_cmd'=>'dns-domain-delete', 'DOMAIN'=>$DOMAIN }; 
		push @CMDS, { '_uuid'=>"$USERNAME\@$DOMAIN", '_cmd'=>'dns-domain-update', 'DOMAIN'=>$DOMAIN, '%DOMAIN'=>$D->for_export() }; 

		foreach my $HOSTINFO (@{$D->hosts()}) {
			my $HOSTNAME = $HOSTINFO->{'HOSTNAME'};
			my ($wildHOST,$wildDOMAIN) = split(/\./,&ZWEBSITE::domain_to_checkout_domain("$HOSTNAME.$DOMAIN"),2);
			my %CMD = ( '_uuid'=>"$USERNAME\@$DOMAIN-$HOSTNAME", '_cmd'=>'dns-wildcard-reserve', 'DOMAIN'=>$DOMAIN, 'zone'=>$wildDOMAIN, 'host'=>$wildHOST, 'ipv4'=>$VIP ); 
			push @CMDS, \%CMD;
			}
		}

	foreach my $SERVER (@SERVERS) {
		my $socket = $SERVER->[1];
		for my $CMD (@CMDS) {
			$CMD->{'MID'} = $MID;
			$CMD->{'USERNAME'} = $USERNAME;
			$CMD->{'CLUSTER'} = $CLUSTER;
	
			print "Sending $CMD->{'_cmd'} uuid:$CMD->{'_uuid'}\n";
			print Dumper($CMD);
			my $msgstatus = zmq_sendmsg($socket, JSON::XS::encode_json($CMD), ZMQ_DONTWAIT);
			my $reply = zmq_recvmsg($socket);
			my $IN = undef;
			if (not $reply) {
				say "Transmission Failure\n";
				$IN = { 'err'=>1, 'errmsg'=>sprintf("Transmission Failure to %s",$SERVER->[0]) };
				}
			else {
				my ($json) = zmq_msg_data($reply);
				say "Reply $CMD->{'_uuid'}: [$json]";
				eval { $IN  = JSON::XS::decode_json($json) };
				if ($@) { $IN = { 'err'=>'2', 'errmsg'=>'Invalid JSON in response',json=>$json } };
				}

			## at this point $IN *must* be set
			if ($IN->{'err'}>0) {
				print Dumper($IN);
				sleep(10);
				}
			}
		}

	&DBINFO::db_user_close();
	}

foreach my $row (@SERVERS) {
	## close down the sockets.
	zmq_close(my $socket = $row->[1]);
	}
zmq_term($context);

print "Yo!\n";
exit;

__DATA__
	foreach my $USERNAME (keys %USERS) {
		next if ($USERNAME eq '');
		my %dref = ();
		$dref{'REG_TYPE'} = 'SERVICE';
		$dref{'USERNAME'} = $USERNAME;
		$dref{'CLUSTER'} = $CLUSTER;
		$dref{'DOMAIN'} = sprintf("static---%s.app-hosted.com",$USERNAME);
		$dref{'VIP'} = $VIP;
		push @a, \%dref;
		}

	my $pstmt = "select DOMAIN from DOMAINS_POOL where MID=0";
	$sth = $udbh->prepare($pstmt);
	$sth->execute();
	while ( my ($DOMAIN) = $sth->fetchrow() ) {
		push @a, { 'REG_TYPE'=>'RESERVATION', 'CLUSTER'=>$CLUSTER, 'DOMAIN'=>$DOMAIN, 'VIP'=>$VIP };
		}
	$sth->finish();
