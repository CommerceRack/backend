package SYNDICATION::DESIGNED2BSWEET001;


## custom syndication feed for designed2bsweet
## tab-delimited txt feed for 3rd party
## dstcode => DS1

use Data::Dumper;
use strict;
require SYNDICATION::HELPER;
use POSIX;

##
##
##
sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;
	bless $self, 'SYNDICATION::DESIGNED2BSWEET001';  

	my $ERROR = '';
	my $ftpserv = $so->get('.ftp_server');
	$ftpserv =~ s/ //g;
	if ($ftpserv =~ /^ftp\:\/\//i) { $ftpserv = substr($ftpserv,6); }
	my $fuser = ZOOVY::incode($so->get('.ftp_user'));
	$fuser =~ s/ //g;
	my $fpass = ZOOVY::incode($so->get('.ftp_pass'));
	$fpass =~ s/ //g;
	my $ffile = $so->get('.ftp_filename');
	$ffile =~ s/ //g;

	my ($mmddyyyy) = POSIX::strftime("%m%d%Y",localtime());
	$so->set(".url","ftp://$fuser:$fpass\@$ftpserv/$ffile".$mmddyyyy.".csv");
  
	$self->{'_NC'} = NAVCAT->new($so->username(),$so->prt());

	if (not defined $so) {
		die("No syndication object");
		}

	@SYNDICATION::DESIGNED2BSWEET001::COLUMNS = @{SYNDICATION::HELPER::get_headers($so->dstcode())};

	return($self);
	}

##
##
##
sub header_products {
	my ($self) = @_;

	$self->{'_csv'} = Text::CSV_XS->new({binary=>1, always_quote=>1});              # create a new object
	my $csv = $self->{'_csv'};

	my @columns = ();
	foreach my $column (@SYNDICATION::DESIGNED2BSWEET001::COLUMNS) {
		push @columns, $column->{'header'};
		}

	my $status = $csv->combine(@columns);    # combine columns into a string
	my $line = $csv->string();               # get the combined string
	return($line."\n");
	}

sub so { return($_[0]->{'_SO'}); }


sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	## format:
	##		field, prod_name, validation
	my $ERROR = undef;

	## skip any products that start with "KA", per merchant
	if ($SKU =~ /^KA/) {
		$ERROR = "VALIDATION|+{SKU} sku's that start with 'KA' are not allowed";
		}

	if ($ERROR ne '') {
		## just kidding!
		if ($self->so()->get('.ignore_validation')) { $ERROR = ''; }
		}

	if ($ERROR ne '') {
		$plm->pooshmsg($ERROR);
		}

	return($ERROR);
	}

  
##
##
##
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my %SPECIAL = %{$OVERRIDES};

	my $csv = $self->{'_csv'};
	my (my $arrayref) = &SYNDICATION::HELPER::do_product($self->so(),\@SYNDICATION::DESIGNED2BSWEET001::COLUMNS,\%SPECIAL,$SKU,$P,$plm);

	my $line = undef;
	if (not $plm->can_proceed()) {
		}
	else {
		my @columns = ();
		foreach my $set (@{$arrayref}) {
			push @columns, $set->[1];	## we can ignore the headers since we're doing a csv.
			}

		my $status = $csv->combine(@columns);    # combine columns into a string
		$line = $csv->string()."\n";               # get the combined string
		}

	return($line);
	}
	
  
sub footer_products {
  my ($self) = @_;

  return("");
  }


1;