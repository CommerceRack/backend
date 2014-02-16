package LISTING;

use strict;
use warnings;
no warnings 'once';
no warnings 'redefine';

require Storable;
require Data::Dumper;

use lib "/backend/lib";
require ZOOVY;

my $TMPDIR = '/httpd/servers/aol/tmp';
my $MKT = '';		# this will be one of the following:
						# 	EBAY		- ebay (e.g. LISTING::EBAY)
						#  EBAYS		- ebay stores
						#  EBAYM		- ebay motors
						#  AOL		- aol classifieds
						#  AMZ		- amazon

my $MERCHANT = undef;		# the merchant that this listing belongs to.


######################################################################################
## LISTINGS->new
######################################################################################
## Purpose: creates a new listing object
## Accepts: $USERNAME (if known),
##          $LISTING ID (leave blank if we're going to create this)
sub new {
	my ($class, $MKT, $USERNAME, %options) = @_;

	print "USERNAME: $USERNAME\n";
	
	my $self = {};
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);
	$self->{'MID'} = $MID;
	$self->{'USERNAME'} = $USERNAME;
	$self->{'ID'} = 0;
	$self->{'CREATED_GMT'} = time();


	#if (($options{'LID'}>0) && ($MID>0)) {
	#	## a listing id was passed, so was mid
	#	my ($dbh) = &DBINFO::db_zoovy_connect();
	#	my $pstmt = "select * from LIST_SCHEDULE where MID=$MID and ID=".int($options{'LID'});
	#	my $sth = $dbh->prepare($pstmt);
	#	$sth->execute();
	#	$self = $sth->fetchrow_hashref();
	#	$sth->finish();
	#	&DBINFO::db_zoovy_close();
	#	}
	# use Data::Dumper; print Dumper($self);

	bless $self, 'LISTING';
	return($self);
	}	


sub set {
	my ($self,%attribs) = @_;
	foreach my $k (keys %attribs) {
		$self->{$k} = $attribs{$k};
		}
	}

#sub save {
#	my ($self) = @_;
#
#	if (not defined $self->{'SKIP_DOW'}) { $self->{'SKIP_DOW'} = 0; }
#	if (not defined $self->{'HOUR_START'}) { $self->{'HOUR_START'} = 0; }
#	if (not defined $self->{'HOUR_END'}) { $self->{'HOUR_END'} = 0; }
#	if (not defined $self->{'LAUNCHES_MAX'}) { $self->{'LAUNCHES_MAX'} = 0; }
#
#	my $dbh = &DBINFO::db_zoovy_connect();
#	my $pstmt = &DBINFO::insert($dbh,'LIST_SCHEDULE', {
#		MID=>$self->{'MID'},
#		USERNAME=>$self->{'USERNAME'},
#		PID=>$self->{'PID'},
#		SKU=>$self->{'SKU'},
#		LAUNCHES_MAX=>$self->{'LAUNCHES_MAX'},	
#		SKIP_DOW=>$self->{'SKIP_DOW'},
#		HOUR_START=>$self->{'HOUR_START'},
#		HOUR_END=>$self->{'HOUR_END'},
#		},debug=>1+2);
#	$dbh->do($pstmt);
#	&DBINFO::db_zoovy_close();
#
#	}

1;

