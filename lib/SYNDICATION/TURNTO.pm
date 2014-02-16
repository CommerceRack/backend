package SYNDICATION::TURNTO;


use strict;
use LWP::UserAgent;
use Data::Dumper;

use lib "/backend/lib";
require SYNDICATION::HELPER;

## 
## Product Syndication feed for TURNTO
##	- built 2011-05-18(specifically for orangeonions)
##
##	- only sends product feed
##
##
##
sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;

	bless $self, $class;

	$self->{'_NC'} = NAVCAT->new($so->username(),$so->prt());

	@SYNDICATION::TURNTO::COLUMNS = @{SYNDICATION::HELPER::get_headers($so->dstcode())};
	return($self);
	}


##
## returns a syndication object
sub so { return($_[0]->{'_SO'}); }


##
## returns a csv header for product feed
sub header_products {
	my ($self) = @_;

   $self->{'_csv'} = Text::CSV_XS->new({binary=>1,sep_char=>"\t"});              # create a new object
   my $csv = $self->{'_csv'};

   my @columns = ();
   foreach my $column (@SYNDICATION::TURNTO::COLUMNS) {
      push @columns, $column->{'header'};
      }

   my $status = $csv->combine(@columns);    # combine columns into a string
   my $line = $csv->string();               # get the combined string
   return($line."\n");
	}

##
##
sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	return("");
	}

##
sub product {
	my ($self, $SKU, $P, $plm, $OVERRIDES) = @_;

	my $csv = $self->{'_csv'};

	my %SPECIAL = %{$OVERRIDES};

=pod

[[SUBSECTION]%IN_STOCK]

the special field %IN_STOCK will be set to the inventory summary of a SKU
[[BREAK]]

if the inventory of the SKU is less than or equal to zero, then send 0
[[BREAK]]
if the inventory of the SKU is greater than zero, then send 1
[[BREAK]]
Example: -56
[[BREAK]]
Send: 0
[[BREAK]]
Example: 109
[[BREAK]]
Send: 1
[[/SUBSECTION]]

=cut 


	$SPECIAL{'%IN_STOCK'} = '';
	if ($OVERRIDES->{'zoovy:qty_instock'} <= 0) {
		$SPECIAL{'%IN_STOCK'} = 0;
		}
	else {
		$SPECIAL{'%IN_STOCK'} = 1;
		}

	my ($arrayref) = &SYNDICATION::HELPER::do_product($self->so(),\@SYNDICATION::TURNTO::COLUMNS,\%SPECIAL,$SKU,$P,$plm);

	my $line = undef;
	if (not $plm->can_proceed()) {
		}
	else {
		my @columns = ();
		foreach my $set (@{$arrayref}) {
			push @columns, $set->[1];  ## we can ignore the headers since we're doing a csv.
			}

		my $status = $csv->combine(@columns);    # combine columns into a string
		$line = $csv->string()."\n";               # get the combined string
		}

   return($line);
	}



##
##
sub footer_products {
	my ($self) = @_;

	return("");
	}


##
## BULK http uploader
## post file to handler
##
sub upload {
	my ($self,$file,$tlm) = @_;

	## copy contents to tmp file
	#my $new_file = "/tmp/turnto_feed_tab.csv";
	#open(NEW_FILE,">$new_file");
	#open(FILE,$file);
	#while(<FILE>) {
	#	print NEW_FILE $_."\n";
	#	}
	#close(FILE);
	#close(NEW_FILE);

	my $siteKey = $self->so()->get('.site_key');
	my $authKey = $self->so()->get('.auth_key');
	my $URL = "https://www.turnto.com/feedUpload/postfile";
	my $feedStyle="tab-style.1";
	
	my $ua = LWP::UserAgent->new(agent=> 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)');
	my $response = $ua->post($URL, Content_Type => 'form-data', Content => [ siteKey => "$siteKey", authKey => "$authKey", feedStyle => "$feedStyle", file => [$file]]);
	my $content = $response->decoded_content;
	
	use Data::Dumper;
	open F, ">/tmp/".$self->so()->username()."-turnto-content.html"; print F "FILE: $file\nsiteKey: $siteKey authKey: $authKey\nRESPONSE: ".$content; Dumper($response); close F;

	## probably needs some more diagnostics ..
	$tlm->pooshmsg("SUCCESS|+this is always a win");
	return($tlm);
	}




1;
