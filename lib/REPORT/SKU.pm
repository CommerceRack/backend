package REPORT::SKU;

use strict;

use lib "/backend/lib";
require DBINFO;
require PRODUCT;
require ZOOVY;
require PRODUCT;
require INVENTORY2;
use Data::Dumper;

##
## these methods should be included in the header of every report::module
##
sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub r { return($_[0]->{'*PARENT'}); }


sub init {
	my ($self) = @_;

	my $r = $self->r();
	my $meta = $r->meta();
	my $USERNAME = $r->username();
	my $MID = $r->mid();

	$meta->{'title'} = 'SKU Summary Report';
	$meta->{'subtitle'} = '';

	
	$r->{'@BODY'} = [];

	return();
	}


###################################################################################
##
##
sub work {
	my ($self) = @_;

	my $r = $self->r();
	my $bj = $r->bj();
	my $meta = $r->meta();
	my $USERNAME = $r->username();
	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
	my $MID = $r->mid();

	my $INV2 = INVENTORY2->new($USERNAME);
	
	$r->progress(0,0,"Generating report.");
	my %options = %{$meta};
	#if ($meta->{'where'}) {
	#	## WHERE=AVAILABLE,GT,0
	#	my @VALS = split(/,/,$meta->{'META'},3);
	#	$options{'WHERE'} = \@VALS;
	#	}	

	my $SELECTED_PIDS = undef;
	if ((defined $meta->{'product_selectors'}) && ($meta->{'product_selectors'} ne '')) {
		$r->progress(0,0,"resolving product selectors.");
      require PRODUCT::BATCH;
      my @SELECTORS = split(/\n/,$meta->{'product_selectors'});
      my @PIDS = &PRODUCT::BATCH::resolveProductSelector($bj->username(),$bj->prt(),\@SELECTORS);
 		$SELECTED_PIDS = \@PIDS;
		}

	## future versions beyond 201338 should *ALWAYS* specifiy headers
	if (not defined $meta->{'headers'}) { $meta->{'headers'} = 'sku:title,sku:price,inv:available,inv:onhand,inv:markets'; }

	if ($meta->{'ALL'}==1) {
		$SELECTED_PIDS = [ &ZOOVY::fetchproduct_list_by_merchant($bj->username()) ];
		}

	if (not defined $SELECTED_PIDS) {
		## we should probably throw an error here.
		$SELECTED_PIDS = [];
		}

	my @HEAD = ();
	my $WANTS_INVENTORY = 0;
	foreach my $attrib (split(/,/,$meta->{'headers'})) {
		if ($attrib =~ /^inv:/) {
			$WANTS_INVENTORY++;
			if ($attrib eq 'inv:available') { 
				push @HEAD,	{ id=>'AVAILABLE', 'name'=>'inv:available', type=>'INV' }; 
				}
			elsif ($attrib eq 'inv:onhand') { 
				push @HEAD,	{ id=>'ONSHELF', 'name'=>'inv:onhand', type=>'INV' }; 
				}
			elsif ($attrib eq 'inv:markets') { 
				push @HEAD,	{ id=>'MARKETS', 'name'=>'inv:markets', type=>'INV' }; 
				}
			else { 
				push @HEAD, { id=>$attrib, name=>$attrib, type=>'ERROR' }; 
				}
			}
		else {
			push @HEAD, { id=>$attrib, name=>$attrib, type=>'CHR' };
			}
		}

	$r->{'@HEAD'} = \@HEAD;

	my $rectotal = scalar(@{$SELECTED_PIDS});
	my $reccount = 0;

	my $jobs = &ZTOOLKIT::batchify($SELECTED_PIDS,100);
   foreach my $batch (@{$jobs}) {
      my $PIDOBJS = &PRODUCT::group_into_hashref($USERNAME,$batch);
      my $INVSUMMARY = undef;
		if ($WANTS_INVENTORY) { $INVSUMMARY = INVENTORY2->new($USERNAME)->summary( '@PIDS'=>$batch ); }

		$r->progress($reccount,$rectotal,"compiling report");
		foreach my $P (values %{$PIDOBJS}) {
			$reccount++;
			foreach my $set (@{$P->list_skus('verify'=>1)}) {
				my ($SKU,$skuref) = @{$set};

				my @ROW = ();
				push @ROW, $P->pid();
				push @ROW, $SKU;

				foreach my $h (@HEAD) {
					if ($h->{'type'} eq 'INV') {
   			      ## SAMPLE: $INVSUMMARY{'AHD768'} => {  'TS' => '0', 'PID' => 'AHD768',  'DIRTY' => '0', 'MARKETS' => '0', 'ONSHELF' => '0', 'AVAILABLE' => '0',  'SKU' => 'AHD768'    },
						## print STDERR Dumper($h,$SKU,$INVSUMMARY);
						push @ROW, sprintf("%d",$INVSUMMARY->{$SKU}->{ $h->{'id'} });
						}
					elsif ($h->{'type'} eq 'ERROR') {
						push @ROW, sprintf('_ERROR_INVALID_FIELD[%s]_',$h->{'id'}); 
						}
					else {
						push @ROW, sprintf("%s",$P->skufetch($SKU,$h->{'id'}));
						}
  	          print STDERR "SKU:$SKU\n";
  	          }
				push @{$r->{'@BODY'}}, \@ROW;		
				}
			}
		}

	## prepend these to the front (they're hardcoded)
	## NOTE: they *MUST* be reverse order since it's an unshift (prepend)
	unshift @HEAD,	{ id=>'SKU', 'name'=>'SKU', type=>'CHR', };
	unshift @HEAD, { id=>'PID', 'name'=>'PRODUCTID', type=>'CHR', };

	$r->progress($reccount,$reccount,"did $reccount records");
	&DBINFO::db_user_close();	
	}



1;

