package PROVIDER;

use Data::Dumper;
use LWP::UserAgent;
use JSON::XS;
use strict;

require DOMAIN::QUERY;



#sub resolve_userdomains {
#	my ($USERNAME) = @_;
#	$USERNAME = uc($USERNAME);
#	my $ALLDOMAINS = Storable::retrieve $DOMAIN::QUERY::CACHE_FILE;
#	
#	my @RESULTS = ();	
#	foreach my $DREF (values %{$ALLDOMAINS}) {
#		next unless (uc($DREF->{'USERNAME'}) eq $USERNAME);
#		push @RESULTS, $DREF->{'DOMAIN'};
#		}
#	return(\@RESULTS);
#	}
#
#
###
###
###
#sub find_apiurl {
#	my ($USERNAME) = @_;
#	my $DOMAINS = PROVIDER::resolve_userdomains($USERNAME);
#	my $DOMAIN = shift @{$DOMAINS};

#	my $URL = "http://www.$DOMAIN/jsonapi/";
#	return($URL);
#	}

##
##
sub new {
	my ($CLASS, $APIURL) = @_;

   my ($ua) = LWP::UserAgent->new();
   $ua->timeout(10);
   $ua->env_proxy;

	my $self = {};
	$self->{'*UA'} = $ua;		
	$self->{'.apiurl'} = $APIURL;
	bless $self, 'PROVIDER';

	return($self);
	}


sub auth {
	my ($self, $USERNAME, $PASSWORD) = @_;

	my %api = ();
	$self->{'_username'} = $USERNAME;
	$self->{'_uuid'} = 0;

	$api{'_cmd'} = 'ping';

	$api{'_clientid'} = 'provider/perl';
	$api{'_userid'} = $USERNAME;
	$api{'_version'} = 201342;
	$api{'_domain'} = '';
	$api{'_deviceid'} = '';
	$api{'_authtoken'} = '';

	# my $content = JSON::XS::encode_json(\%api);
	# print "$content\n";
	}


sub _ua {  return($_[0]->{'*UA'}); }
sub _uuid {  return(++$_[0]->{'_uuid'}); }
sub _apiurl { return($_[0]->{'.apiurl'}); }


## 
## returns a response object that can be used to construct a url.
##
sub providerExecLogin {
	my ($self, %params) = @_;
	$params{'secret'} = 'shhhh';
	my ($R) = $self->api('providerExecLogin',\%params);
	return($R);
	}


## 
## returns a response object that can be used to construct a url.
##
sub providerExecTodoCreate {
	my ($self, %params) = @_;
	#ticket=>$TICKET, 
	#title=>'Support Ticket '.$TICKET.' - waiting for response',	
	#detail=>'This ticket is currently "WAITING" which means a response from you is needed before further action is taken.',
	$params{'secret'} = 'shhhh';
	my ($R) = $self->api('providerExecTodoCreate',\%params);
	return($R);
	}

##
## accepts filename, body
##	returns error (or null on success)
##
sub providerExecFileWrite {
	my ($self, $filename, $body) = @_;
	my %params = ();
	$params{'filename'} = $filename;
	$params{'body'} = $body;
	$params{'secret'} = 'shhhh';
	my ($R) = $self->api('providerExecFileWrite',\%params);
	return($self->got_error());
	}

##
## accepts filename, returns ($MIMETYPE,$body)
##
sub providerExecFileRead {
	my ($self, $filename) = @_;
	my %params = ();
	$params{'filename'} = $filename;
	$params{'secret'} = 'shhhh';
	my ($R) = $self->api('providerExecFileRead',\%params);
	if ($self->got_error()) { return(undef); }
	return($R->{'MIMETYPE'},$R->{'body'});
	}



##
##
##
sub api {
	my ($self,$cmd,$params) = @_;

	$params->{'_cmd'} = $cmd;
	$params->{'_uuid'} = $self->_uuid();

	delete $self->{'$?'};

	my $content = JSON::XS::encode_json($params);
	my ($h) = HTTP::Headers->new();
	$h->header('Content-Type' => 'application/json');  # set
	my ($r) = HTTP::Request->new();
	my $req = HTTP::Request->new( 'POST', $self->_apiurl(), $h, $content );
	my ($res) = $self->_ua()->request($req);

	my $R = undef;
	if ($res->is_error()) {
		$R = { '_errid'=>sprintf("%04d",$res->code),  '_errmsg'=>$res->status_line() };
		}
	elsif (not $res->is_success()) {
		$R = { '_errid'=>-1, '_errmsg'=>'unknown non-success response from api' };
		}
	elsif ($res->content() !~ /\{.*\}/) {
		$R = { '_errid'=>-1, '_errmsg'=>'got non-json response from api', '_debug'=>$res->content() };
		}
	else {
		$R = JSON::XS::decode_json($res->content());
		}

	if (not defined $self->{'@CALLS'}) { $self->{'@CALLS'} = []; }
	push @{$self->{'@CALLS'}}, [ $params->{'_cmd'}, $params, $R ];


	## set the last error
	$self->{'$@'} = ($R->{'_errid'})?sprintf("%s: %s",$R->{'errid'},$R->{'_errmsg'}):undef;
	
	return($R);
	}


##
## returns the last error we got (or undef on success)
sub is_error { return($_[0]->{'$@'}); }
sub got_error { return($_[0]->{'$@'}); }
sub last_response { return($_[0]->{'@CALLS'}->[ scalar(@{$_[0]->{'@CALLS'}}) - 1 ]); }




#      $R{'uri'} = "/app/latest/admin.html?
#trigger=support&username=$USERNAME&userid=$USERID&authtoken=$AUTHTOKEN&deviceid=$DEVICEID&flush=1";

## 
#   my $DOMAIN = $v->{'domain'};
#   my $D = undef;
#   if (not &JSONAPI::validate_required_parameter(\%R,$v,'domain')) {
#      ##
#      }
#   else {
#      $DOMAIN =~ s/[Hh][Tt][Tt][Pp][Ss]?\:\/\///gs;
#      $DOMAIN =~ s/www\.//gs;
#      ($D) = DOMAIN::QUERY::lookup($DOMAIN);
#      }


	



1;