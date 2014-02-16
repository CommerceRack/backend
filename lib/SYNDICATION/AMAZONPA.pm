#!/usr/bin/perl

package SYNDICATION::AMAZONPA;

use strict;
use lib "/backend/lib";
use DBINFO;
use ZOOVY;
use NAVCAT;
use NAVCAT::FEED;
use ZSHIP;
use ZTOOLKIT;
# use SYNDICATION;
use SITE;
use LWP::UserAgent;
use Net::FTP;
use LWP::Simple;
use Data::Dumper;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );



sub new {
	my ($class, $so) = @_;
	my ($self) = {};
	$self->{'_SO'} = $so;

   tie my %s, 'SYNDICATION', THIS=>$so;
	
	if ($s{'.ftp_server'} =~ /^ftp\:\/\//i) { $s{'.ftp_server'} = substr($s{'.ftp_server'},6); }
	#if ($s{'.ftp_server'} !~ /yahoo\.com$/) {
	#	$ERROR = 'FTP Server must end in .yahoo.com'; 
	#	}
	$so->set('.url',sprintf("ftp://%s:%s\@%s/products.txt",$s{'.ftp_user'},$s{'.ftp_pass'},$s{'.ftp_server'}));
	bless $self, 'SYNDICATION::AMAZONPA';  
	untie %s;

	require SYNDICATION::HELPER;
	@SYNDICATION::AMAZONPA::COLUMNS = @{SYNDICATION::HELPER::get_headers($so->dstcode())};

	return($self);
	}

##
##
##
sub header_products {
	my ($self) = @_;

	$self->{'_csv'} = Text::CSV_XS->new({binary=>1,sep_char=>"\t"});              # create a new object
	my $csv = $self->{'_csv'};

	my @columns = ();
	foreach my $column (@SYNDICATION::AMAZONPA::COLUMNS) {
		push @columns, $column->{'header'};
		}

	my $status = $csv->combine(@columns);    # combine columns into a string
	my $line = $csv->string();               # get the combined string
	return($line."\n");
	}

sub so { return($_[0]->{'_SO'}); }


##
##
##
sub validate {
	my ($self,$SKU,$P,$plm,$OVERRIDES) = @_;

	my $ERROR = '';
	my $USERNAME = $self->so()->username();

## NOTE: we never need to call apply_options since it would have been called (and values would be in overrides)
#	if (($ERROR eq '') && ($P->has_variations('inv')) ) {
#		my ($pogs2) = $P->fetch_pogs();
#		my ($STID) = &POGS::default_options($USERNAME,$SKU,$pogs2);
#		&POGS::apply_options($USERNAME,$STID,$P->dataref());
#		}

	my $prodref = $P->prodref();

	if ($ERROR ne '') {
		}
	elsif (($SKU =~ /:/) && ($OVERRIDES->{'zoovy:base_price'}>0)) {
		}
	elsif (($SKU !~ /:/) && ($prodref->{'zoovy:base_price'} eq '')) {
		}
	else {
		$ERROR = "VALIDATION|ATTRIB=zoovy:base_price|+Base price is not set";
		}

#	if (($ERROR eq '') && (ZSHIP::smart_weight($prodref->{'zoovy:ship_weight'})==0)) {
#		$ERROR = "zoovy:base_weight|Base weight must be greater than zero or amzpa:base_weight must be set.";
#		}

	if ($ERROR ne '') {
		}
	elsif ($prodref->{'zoovy:prod_image1'} eq '') {
		$ERROR = "VALIDATION|ATTRIB=zoovy:prod_image1|+Image1 is required";
		}
	else {
		my ($w,$h) = ZOOVY::image_minimal_size($USERNAME,$prodref->{'zoovy:prod_image1'});
		if ($w>110) {
			if ($h<10) { $ERROR = "VALIDATION|ATTRIB=zoovy:prod_image1|+Height failure - Image1 must be at least 110x10 (w:$w h:$h)"; }
			}
		elsif ($h>110) {
			if ($w<10) { $ERROR = "VALIDATION|ATTRIB=zoovy:prod_image1|+Width failure - Image1 must be at least 110x10 (w:$w h:$h)"; }
			}
		else {
			$ERROR = "VALIDATION|ATTRIB=zoovy:prod_image1|+Image1 must be 110 pixels on one edge (w:$w x h:$h $prodref->{'zoovy:prod_image1'})";
			}
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

	my $csv = $self->{'_csv'};

	

=pod

[[SUBSECTION]%WORD1,%WORD2,%WORD3]
The contents of amzpa:keywords, zoovy:keywords, and zoovy:prod_keywords will be sequentially searched until an 
applicable value is found.  Then the contents will be split by hard returns and commas, each keyword becomes
%WORD1, %WORD2, etc.
[[/SUBSECTION]]

=cut

	my %SPECIAL = %{$OVERRIDES};

	## according to chrsity amazon doesn't actually use keywords
	my $keywords = $P->fetch('amzpa:keywords');
	if ($keywords eq '') { $keywords = $P->fetch('zoovy:keywords'); }
	if ($keywords eq '') { $keywords = $P->fetch('zoovy:prod_keywords'); }
	my @words = split(/[,\n\r]+/,$keywords);
	my $i = 0;
	foreach my $w (@words) { 
		next if ($w eq ''); 
		next if (++$i>10); 
		$SPECIAL{"%WORD$i"} = $w;  
		}
	while (++$i<10) { $SPECIAL{"%WORD$i"} = ''; };
	
	my ($arrayref) = &SYNDICATION::HELPER::do_product($self->so(),\@SYNDICATION::AMAZONPA::COLUMNS,\%SPECIAL,$SKU,$P,$plm);

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
