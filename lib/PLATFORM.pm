package PLATFORM;

use strict;
use YAML::Syck;

use Data::Dumper;
use lib "/backend/lib";
require ZOOVY;
require DOMAIN;

BEGIN {
	## this library currently doesn't work on solaris
	eval 'require ZMQ::LibZMQ3';
	}

use ZMQ::Constants qw(ZMQ_REQ ZMQ_DONTWAIT ZMQ_RCVTIMEO ZMQ_SNDTIMEO);

##
## long term this is the thing which determines the environment/platform we're running on, and it will
##	ultimately replace ZOOVY.pm for accessing/discovering shared resources.
##


## TODO: SITE::Vstore used a global memcache handle.. it should use a cluster specific one.
	

sub ns_servers {
	my @SERVERS = (
		'tcp://ec2-184-72-43-111.us-west-1.compute.amazonaws.com:5555',
		'tcp://ec2-75-101-135-209.compute-1.amazonaws.com:5555',
		);
	if (&ZOOVY::servername() eq 'dev') {
		unshift @SERVERS, 'tcp://localhost:5555';
		}

	return(@SERVERS);
	}





sub send_cmds {
	my ($LM,$CMDS,$SERVERS) = @_;

	my $context = ZMQ::LibZMQ3::zmq_init();
	foreach my $SERVER (@{$SERVERS}) {

		$LM->pooshmsg("INFO|+Connecting to server: $SERVER");
		my $socket = ZMQ::LibZMQ3::zmq_socket($context, ZMQ_REQ);
		ZMQ::LibZMQ3::zmq_connect($socket, $SERVER);
		ZMQ::LibZMQ3::zmq_setsockopt($socket, ZMQ_RCVTIMEO, 5000);
		ZMQ::LibZMQ3::zmq_setsockopt($socket, ZMQ_SNDTIMEO, 5000);

		for my $CMD (@{$CMDS}) {
			$LM->pooshmsg("INFO|+Sending $CMD->{'_cmd'} uuid:$CMD->{'_uuid'}\n");
			my $msgstatus = ZMQ::LibZMQ3::zmq_sendmsg($socket, JSON::XS::encode_json($CMD), ZMQ_DONTWAIT);
			my $reply = ZMQ::LibZMQ3::zmq_recvmsg($socket);
			my $IN = undef;
			if (not $reply) {
				$LM->pooshmsg("INFO|+Transmission Failure -- ".Dumper($reply,$socket));
				$IN = { 'err'=>1, 'errmsg'=>sprintf("Transmission Failure to %s",$SERVER) };
				}
			else {
				my ($json) = ZMQ::LibZMQ3::zmq_msg_data($reply);
				$LM->pooshmsg("INFO|+Reply $CMD->{'_uuid'}");
				eval { $IN  = JSON::XS::decode_json($json) };
				if ($@) { $IN = { 'err'=>'2', 'errmsg'=>'Invalid JSON in response',json=>$json } };
				}

			## at this point $IN *must* be set
			if ($IN->{'err'}>0) {
				# $LM->pooshmsg(sprintf("ERROR|+DUMP: %s",Dumper($IN)));
				## sleep(10);
				}
			}
		## close down the sockets.
		ZMQ::LibZMQ3::zmq_close($socket);
		$LM->pooshmsg(sprintf("INFO|+Completed %s",$SERVER));
		}
	ZMQ::LibZMQ3::zmq_term($context);

	}



sub new {
	my ($CLASS, %options) = @_;

	#my $file = $options{'file'};
	#if (not defined $file) {
	#	$file = "/httpd/platform.yaml";
	#	}
	my $self = {};
	my ($hostname) = &ZOOVY::servername();
	# print STDERR "HOST:$hostname\n";
	$self->{'_HOSTNAME'} = $hostname;
	$self->{'_CLUSTER'} = undef;

	if ($hostname eq 'dev') {
		$self->{'@ROLES'} = [ 'gw','static','public','vstore','admin','jsonapi','internal' ];
		$self->{'@CLUSTERS'} = &ZOOVY::return_all_clusters();
		}
	elsif ($hostname =~ /public[\d]+/) {
		$self->{'@ROLES'} = [ 'public' ];
		$self->{'@CLUSTERS'} = &ZOOVY::return_all_clusters();
		}
	else {
		$self->{'@ROLES'} = [];
		if ($hostname =~ /^gw[\d]+\-(.*?)$/) {
			push @{$self->{'@ROLES'}}, 'gw'; 
			push @{$self->{'@ROLES'}}, 'vstore'; 
			push @{$self->{'@ROLES'}}, 'static'; 
			push @{$self->{'@ROLES'}}, 'jsonapi'; 
			$self->{'_CLUSTER'} = $1;
			}
		if ($hostname =~ /^www[\d]+\-(.*?)$/) {
			push @{$self->{'@ROLES'}}, 'vstore'; 
			push @{$self->{'@ROLES'}}, 'jsonapi'; 
			$self->{'_CLUSTER'} = $1;
			}
		if ($hostname =~ /(www|gw)[\d]+\-(.*?)$/) {
			push @{$self->{'@CLUSTERS'}}, $2;
			$self->{'_CLUSTER'} = $2;
			}
		if (scalar(@{$self->{'@ROLES'}})==0) {
			warn "no \@ROLES discovered\n";
			}
		}


	bless $self, 'PLATFORM';
	if ($options{'use_root_configs'}) {
		my ($self) = $self->use_root_configs();
		}

	return $self;
	}




sub canDoRole { 
	my ($self, $testrole) = @_;
	my $cando = 0;
	foreach my $hasrole (@{$self->{'@ROLES'}}) {
		if ($hasrole eq $testrole) { $cando++; }
		}
	return($cando);
	}

sub hostname { return($_[0]->{'_HOSTNAME'}); }
sub thiscluster { return($_[0]->{'_CLUSTER'}); }
sub clusters { return($_[0]->{'@CLUSTERS'}); }
sub roles { return(@{$_[0]->{'@ROLES'}}); }

##
sub getHostProperty { 
	my ($self,%params) = @_;
	my $hostinfo = $_[0]->getHost($params{'host'});
	if (not defined $params{'property'}) {
		warn "no property= defined on command line\n";
		return("");
		}
	elsif (not defined $hostinfo) {
		warn "host does not have /root/configs/servers.txt entry\n";
		return("");
		}
	if (not defined $hostinfo->{$params{'property'}}) {
		if (defined $params{'else'}) {
			## pass warn=1 to suppress
			return($params{'else'});
			}
		else {
			warn "host does not have property '$params{'property'}' defined in /root/configs/servers.txt (use else= to suppress this)";
			}
		return("");
		}
	return($hostinfo->{$params{'property'}});
	}


##
## returns an array of hostnames which are members of this cluster
##
sub getClusterMembers {
	my ($self, %params) = @_;

	if (not defined $params{'cluster'}) {
		## lookup our cluster
		$params{'cluster'} = $self->thiscluster();
		}
	if (not defined $params{'cluster'}) {
		warn "cant get cluster members when we arent a member of a cluster! (check yer hostname)";
		return();
		}
	
	my @MEMBERS = ();
	my $hosts = $self->getHosts('cluster'=>$params{'cluster'});
	foreach my $node (@{$hosts}) {
		if ($node->{'cluster'} ne $params{'cluster'}) {
			}
		elsif ( (defined $params{'role'}) && (not defined $node->{'.'}->{ sprintf("roles.%s",$params{'role'}) }))  {
			## IGNORE THIS IT ISNT THE RIGHT ROLE
			# use Data::Dumper; print Dumper($node);
			}
		else {
			push @MEMBERS, $node->{'name'};
			}
		}
	return(\@MEMBERS);
	}

##
## returns the info for a single host (usually the one we're on)
##
sub getHost {
	my ($self,$HOSTNAME) = @_;

	if (not defined $HOSTNAME) { $HOSTNAME = $self->hostname(); }
	my $info = undef;
	if (not defined $self->{'@HOSTS'}) { $self->use_root_configs();  }
	$info = $self->{'%ROOT_CONFIGS_HOSTNAMES'}->{ $HOSTNAME };
	return($info);
	}



##
## sets up %ROOT_CONFIGS_HOSTNAMES, %ROOT_CONFIGS_IP, and @HOSTS references from servers.txt
##
sub use_root_configs {
	my ($self, %params) = @_;
	$self->{'%ROOT_CONFIGS_HOSTNAMES'} = {};
	$self->{'%ROOT_CONFIGS_IP'} = {};
	open F, "</root/configs/servers.txt";

	my @HOSTS = ();
	while (<F>) {
		chomp();
		next if (substr($_,0,1) eq '#');
		next if ($_ eq '');
	
		my %host = ();
		foreach my $kv (split(/\|/,"ip=$_")) {
			my ($k,$v) = split(/=/,$kv,2);
			$v =~ s/[\s]+$//g;
			$host{$k} = $v;
			foreach my $vs (split(/,/,$v)) {
				$vs =~ s/[\s]+//g;
				$host{'.'}->{"$k.$vs"}++;		## creates model.dl380g3
				}
			}

		next if ((defined $params{'cluster'}) && ($params{'cluster'} ne $host{'cluster'}));
		
		push @HOSTS, \%host;
		$self->{'%ROOT_CONFIGS_HOSTNAMES'}->{ $host{'name'} } = \%host;
		$self->{'%ROOT_CONFIGS_IP'}->{ $host{'ip'} } = \%host;
		}
	close F;
	$self->{'@HOSTS'} = \@HOSTS;
	return($self);
	}

##
## returns: an array of host names we need to create host{} entries for.
##
sub getHosts { 
	my ($self, %params) = @_; 
	if (not defined $self->{'@HOSTS'}) { $self->use_root_configs(%params);  }

	return($self->{'@HOSTS'});
	}


## 
## lets do some sanity checks here .. many programs will want to do a 
##		@WARNINGS = HOSTCONFIG::sanity(\@HOSTS);
##
sub checkRootConfigsSanity {
	my ($self) = @_;

	my @WARNINGS = ();
	my $i = 0;
	foreach my $host (@{$self->getHosts()}) {
		my $fatal = 0;
		if (($host->{'name'} eq '') && ($host->{'ip'} eq '')) {
			push @WARNINGS, "HOST #$i does not have name= or ip= .. and probably isn't going to work real well.";
			$fatal++;
			}
		elsif ($host->{'name'} eq '') {
			push @WARNINGS, "HOST $host->{'ip'} does not have name= attribute.\n";
			$fatal++;
			}
		elsif ($host->{'ip'} eq '') {
			push @WARNINGS, "HOST $host->{'name'} does not have ip= attribute.\n";
			$fatal++;
			}
		next if ($fatal);
		## if we got a fatal error no sense outputting more messages since we won't be able to identify the host anyway
		if (($host->{'.'}->{'roles.mc'}) && ($host->{'cluster'} eq '')) {
			if ($host->{'.'}->{'roles.dev'}) {
				## this rule doesn't apply to dev boxes since they cross all clusters.
				}
			else {
				push @WARNINGS, "HOST $host->{'name'} roles=mc (memcache) servers should *ALWAYS* have a cluster= set.";
				}
			}
		if (($host->{'.'}->{'roles.vstore'}) && ($host->{'cluster'} eq '')) {
			if ($host->{'.'}->{'roles.dev'}) {
				## this rule doesn't apply to dev boxes since they cross all clusters.
				}
			else {
				push @WARNINGS, "HOST $host->{'name'} roles=vstore servers should *ALWAYS* have a cluster= set.";
				}
			}
		if (($host->{'.'}->{'roles.www'}) && ($host->{'cluster'} ne '')) {
			push @WARNINGS, "HOST $host->{'name'} roles=www servers should NEVER have a cluster= set.";
			}
		}
	return(@WARNINGS);
	}



1;



1;