package REPORT::INVENTORY_MISSING;

use strict;

use lib "/backend/lib";
require DBINFO;
require ZOOVY;

##
## these methods should be included in the header of every report::module
##
sub new { my ($class) = @_; my $self = {}; bless $self, $class; return($self); }
sub r { return($_[0]->{'*PARENT'}); }


###########################################################################
##
##
##
sub init {
	my ($self, %params) = @_;

	my $r = $self->r();
	my $meta = $r->meta();
	my $USERNAME = $r->username();
	my $MID = $r->mid();
	
	$meta->{'title'} = 'Missing Inventory';
	$meta->{'subtitle'} = '';

	$r->{'@HEAD'} = [
		{ id=>0, 'name'=>'Product', type=>'CHR', link=>'/biz/product/index.cgi?VERB=EDIT&PID=', target=>'_blank' },
		{ id=>1, 'name'=>'Inventory', type=>'NUM' },
		{ id=>2, 'name'=>'Reserved', type=>'NUM' },
		];

	$r->{'@BODY'} = [];
	return($self);
	}

##################################################################################
##
## this module is what does the actual work, all t
##
sub work {
	my ($self) = @_;

	my $r = $self->r();
	my $meta = $r->meta();
	my $USERNAME = $r->username();
	my ($MID) = &ZOOVY::resolve_mid($USERNAME);

	$r->progress(1,100,"Starting .. ");

	my $udbh = &DBINFO::db_user_connect($USERNAME);

	#my ($onhandref,$reserveref) = &INVENTORY::load_records($USERNAME,undef);

	my @ar = &ZOOVY::fetchproduct_list_by_merchant($USERNAME);
	my ($onhandref) = INVENTORY2->new($USERNAME)->fetch_qty('@PIDS'=>[\@ar]);
	my @missing = ();

	my $reccount = 0;
	my $rectotal = scalar(@ar);
	
	my $missing_inventory_count = 0;
	foreach my $prod (@ar) {
		my $found = 0;
		if (defined $onhandref->{$prod}) { 
			$found = 1; 
			delete $onhandref->{$prod};
			}

		# search for this product with options
		if (not $found) {
			foreach my $k (keys %{$onhandref}) {
				if ($k =~ /^$prod\:/) {
					$found = 1; 
					delete $onhandref->{$k};
					}
				elsif ($k =~ /^$prod\-/) { 
					$found = 1; 
					delete $onhandref->{$k};
					}
				}
			}
		
		if (not $found) { 
			push @{$r->{'@BODY'}}, [ $prod, '?', int($reserveref->{$prod}) ];
			$missing_inventory_count++;
			}

		$reccount++;
		if (($reccount % 100)==0) {
			$r->progress($reccount,$rectotal,"Running .. found $missing_inventory_count so far");
			}
		}

	$r->progress($rectotal,$rectotal,"did $reccount/$rectotal records (found: $missing_inventory_count)");
   &DBINFO::db_user_close();
	}




1;

