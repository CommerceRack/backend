package REPORT::PRODUCT_DISPOSITION;

use strict;

use lib "/backend/lib";
require PRODUCT;
require NAVCAT;
use Data::Dumper;
use Date::Calc;

sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub r { return($_[0]->{'*PARENT'}); }


##
##

sub init {
	my ($self) = @_;

	my $r = $self->r();
	my $meta = $r->meta();
	my $USERNAME = $r->username();
	my $MID = $r->mid();

	my @HEAD = ();		# the header rows



	$meta->{'title'} = 'Product Disposition Report';
	$meta->{'subtitle'} = '';

	push @HEAD, { id=>0, 'name'=>'SKU', type=>'CHR' }; 
	push @HEAD, { id=>0, 'name'=>'MKT', type=>'CHR' }; 
	push @HEAD, { id=>0, 'name'=>'MKT_ID', type=>'CHR' }; 
	push @HEAD, { id=>0, 'name'=>'QTY', type=>'NUM' }; 
#	push @HEAD, { id=>1, 'name'=>'In Stock', type=>'NUM' }; 
#	push @HEAD, { id=>2, 'name'=>'Reserved', type=>'NUM' }; 
#	push @HEAD, { id=>3, 'name'=>'Website Cats', type=>'NUM' }; 

	#push @HEAD, { id=>4, 'name'=>'eBay Store Channels', type=>'NUM' }; 
	#push @HEAD, { id=>5, 'name'=>'Overstock Channels', type=>'NUM' }; 

	#push @HEAD, { id=>4, 'name'=>'eBay Powerlister', type=>'NUM' }; 
	#push @HEAD, { id=>5, 'name'=>'eBay Auctions', type=>'NUM' }; 
	#push @HEAD, { id=>6, 'name'=>'eBay Store (Channel)', type=>'NUM' }; 
	#push @HEAD, { id=>8, 'name'=>'eBay Store (Syndicated)', type=>'NUM' }; 
	#push @HEAD, { id=>10, 'name'=>'Froogle Syndicated', type=>'NUM' }; 
	#push @HEAD, { id=>11, 'name'=>'BizRate Syndicated', type=>'NUM' }; 
	#push @HEAD, { id=>12, 'name'=>'Shopping.com Syndicated', type=>'NUM' }; 
	#push @HEAD, { id=>13, 'name'=>'YahooShop Syndicated', type=>'NUM' }; 
	$r->{'@HEAD'} = \@HEAD;

	$r->{'@BODY'} = [];
	
	return();
	}




###################################################################################
##
##
sub work {
	my ($self) = @_;

	my $r = $self->r();
	my $meta = $r->meta();
	my $USERNAME = $r->username();
	my $MID = $r->mid();
	my $PRT = $r->prt();

	$r->progress(1,100,"Starting .. ");

	my $pstmt = '';
	my $prodts = &PRODUCT::build_prodinfo_ts($USERNAME);
	my @products = keys %{$prodts};
	my $jobsref = &ZTOOLKIT::batchify(\@products,100);

	my $reccount = 0;
	my $rectotal = scalar(@products);
	$r->progress($reccount,$rectotal,"Loading Products");

	my ($INV2) = INVENTORY2->new($USERNAME);
	
	my $NC = NAVCAT->new( $USERNAME, PRT=>$PRT );
	foreach my $pidsref (@{$jobsref}) {
		#my ($qtyref,$resref,$locref) = &INVENTORY::fetch_qty($USERNAME,$pidsref);
		my @PIDSAR = keys %{$pidsref};
		my ($INVDETAIL) = $INV2->detail('BASETYPE'=>'MARKET','@PIDS'=>\@PIDSAR);

		foreach my $SKU (sort keys %{$INVDETAIL}) {
			foreach my $rowref (@{$INVDETAIL->{$SKU}}) {
				my @ROW = ();
				push @ROW, uc($SKU);
				push @ROW, $rowref->{'MARKET_DST'};
				push @ROW, $rowref->{'MARKET_REFID'};				
				push @ROW, $rowref->{'QTY'};
				}
			}

		#my $PROD = '';
		#foreach $PROD (@{$pidsref}) {
		#	$reccount++;
		#	my @ROW = ();
		#	$ROW[0] = uc($PROD);
		#	## in stock
		#	$ROW[1] = $qtyref->{$PROD};
		#	## reserved
		#	$ROW[2] = $resref->{$PROD};
		#	## website cats
		#	my $cats = $NC->paths_by_product($PROD);
		#	if (not defined $cats) { $cats = []; }
		#	$ROW[3] = scalar(@{$cats});
		#	#my ($DETAILINV) = $INV2->detail();
		#	$ROW[4] = 0;
		#	#my ($sum,$detail) = &INVENTORY::fetch_other($USERNAME,$PROD,'',3);
		#	#foreach my $d (@{$detail}) {
		#	#	#if (substr($d->{'APPKEY'},0,4) eq 'AOL:') { $ROW[5]++; }
		#	#	if ($d->{'APPKEY'} eq 'EBAYSTFEED') { $ROW[4]++; }
		#	#	elsif (substr($d->{'APPKEY'},0,3) eq 'OS:') { $ROW[5]++; }
		#	#	}
		#	## ebay powerlister
		#	## ebay auctions
		#	## ebay store (channel)
		#	## ebay
		#	push @{$r->{'@BODY'}}, \@ROW;
		#	}

		$r->progress($reccount,$rectotal,"");
		}
	undef $NC;
	$r->progress($rectotal,$rectotal,"did $reccount/$rectotal records");
	return();
	}



1;

