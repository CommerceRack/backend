package PLUGIN::PODIO;

use strict;

use Data::Dumper;
use URI::Escape;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use JSON::Syck;



sub access_token { return($_[0]->{'_ACCESSTOKEN'}); }
sub app_id { return($_[0]->{'_APPID'}); }
sub ua { return($_[0]->{'*UA'}); }

##
##
##
sub authorize {
	my ($self) = @_;

	my ($ua) = $self->ua();

	my $AUTHURI = sprintf("https://podio.com/oauth/token?grant_type=app&app_id=%s&app_token=%s&client_id=%s&client_secret=%s",$self->{'_APPID'},$self->{'_APPTOKEN'},$self->{'_CLIENTID'},$self->{'_CLIENTSECRET'});
	my ($response) = $ua->post($AUTHURI);

	my ($r) = JSON::Syck::Load($response->content());
	$self->{'_ACCESSTOKEN'} = $r->{'access_token'};
	return();
	}



##
##
##
sub request {
	my ($self,$METHOD,$uri,%params) = @_;
	# https://developers.podio.com/doc/items/add-new-item-22362
	# /item/app/{app_id}/

	# { "external_id": The external id of the item. This can be used to hold a reference to the item in an external system. "fields": The values for each field, { "{field_id/external_id}": The values for the given field. Can be in any of the following formats: [ { "{sub_id}":{value}, ... (more sub_ids and values) }, ... (more values) ]   or   [ {value}, ... (more values) ]   or   { "{sub_id}":{value}, ... (more sub_ids and values) }   or   {value} }, .... (more fields) }, "file_ids": Temporary files that have been uploaded and should be attached to this item, [ {file_id}, .... (more file ids) ], "tags": The tags to put on the item [ {tag}: The text of the tag to add, ... (more tags) ], "reminder": Optional reminder on this task { "remind_delta": Minutes (integer) to remind before the due date }, "recurrence": The recurrence for the task, if any, { "name": The name of the recurrence, "weekly" or "monthly", "config": The configuration for the recurrence, depends on the type { "days": List of weekdays ("monday", "tuesday", etc) (for "weekly"), "repeat_on": When to repeat, "day_of_week" or "day_of_month" (for "monthly") }, "step": The step size, 1 or more, "until": The latest date the recurrence should take place }, "linked_account_id": The linked account to use for the meeting, "ref": The reference for the new item, if any { "type": The type of the reference, currently only "item", "id": The id of the reference } }	

	my %INTERPOLATE = (
		'{app_id}' => $self->app_id(),
		);
	foreach my $k (keys %INTERPOLATE) {
		$uri =~ s/$k/$INTERPOLATE{$k}/gs;
		}
	$uri = "https://api.podio.com:443/$uri";

	my ($ua) = $self->ua();
	my $req = undef;

	if ($METHOD eq 'GET') {
		if (scalar(keys %params)>0) {
			$uri .= '?';
			foreach my $k (keys %params) {
				$uri .= URI::Escape::uri_escape($k).'='.URI::Escape::uri_escape($params{$k}).'&';
				}
			chop($uri);
			}
		($req) = HTTP::Request->new($METHOD);
		}
	elsif ($METHOD eq 'POST') {
		my ($json) = JSON::Syck::Dump(\%params);	
		print "JSON: $json\n";
		($req) = HTTP::Request->new('POST');
		$req->content($json);
		}
#	elsif ($METHOD eq 'PUT') {
#		my ($json) = JSON::Syck::Dump(\%params);	
#		print "JSON: $json\n";
#		($req) = HTTP::Request->new('PUT');
#		$req->content($json);
#		}
	else {
		die "Unsupported method: $METHOD\n";
		}
#	print "URI:$uri\n";
	$req->header('Authorization',sprintf("OAuth2 %s",$self->access_token()));
	$req->uri($uri);

	my $response = $ua->request($req);
	my ($json) = $response->content();
	my $result = JSON::Syck::Load($json);
# 	print Dumper($result,$req);

	return($result);	
	}

##
##
##
sub new {
	my ($class, $clientid, $app) = @_;

	if (not defined $PLUGIN::PODIO::CLIENTS{$clientid}) {
		die("clientid: $clientid not valid (add to %PLUGIN::PODIO::CLIENTS)");
		}

	if (not defined $PLUGIN::PODIO::APPS{$app}) {
		die("clientid: $app not valid (add to %PLUGIN::PODIO::APPS)");
		}

	my $self = {
		'_APPID'=>$PLUGIN::PODIO::APPS{$app}->[0],
		'_APPTOKEN'=>$PLUGIN::PODIO::APPS{$app}->[1],
		'_CLIENTID'=>$clientid,
		'_CLIENTSECRET'=>$PLUGIN::PODIO::CLIENTS{$clientid},
		};

	$self->{'*UA'} = LWP::UserAgent->new();

	bless $self, 'PLUGIN::PODIO';
	$self->authorize();

	return($self);
	}


1;
