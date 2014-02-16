package ORDER::EDIFACT;

use Business::EDI;

# en.wikipedia.org/wiki/EDIFACT


## convert order to an EDIFACT output
## based on partner's implementation guide
## specific to EDI 850 (ie Purchase Order)
sub as_edifact {
	my ($o) = @_;

	## open implementation guide to get "partner" required format
	## similar to an xsd


	#foreach my $stid ($o->stids()) {
	#  my $itemref = $o->item($stid);	
	#  $itemref->{'prod_name'}, 'qty', 'price', 'description', 'notes'
	#  }


	}
1;
