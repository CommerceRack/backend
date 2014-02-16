package ORDER::CSV;

use strict;
use Text::CSV_XS;
use Data::Dumper;

sub as_csv {
	my ($O2) = @_;

	my $OUT = '';
	my ($csv) = Text::CSV_XS->new({});

	## order header
	my @header = ();
	my $order_id = $O2->oid();
	# supplier_order_id is usually the same as the source order id.
	# but it COULD be something different, it's not order_id.
	if ($O2->is_supplier_order()) {
		$order_id = $O2->supplier_orderid();
		}
	
	@header = ();
	push @header, "HORDER";
	push @header, "ORDERID";
	push @header, 'bill/firstname';
	push @header, 'bill/lastname';
	push @header, 'bill/address1';
	push @header, 'bill/address2';
	push @header, 'bill/city';
	push @header, 'bill/region';
	push @header, 'bill/postal';
	push @header, 'bill/email';
	push @header, 'bill/countrycode';
	push @header, 'ship/firstname';
	push @header, 'ship/lastname';
	push @header, 'ship/address1';
	push @header, 'ship/address2';
	push @header, 'ship/city';
	push @header, 'ship/region';
	push @header, 'ship/postal';
	push @header, 'ship/country';
	push @header, 'ship/phone';
	push @header, 'flow/pool';
	push @header, 'flow/payment_status';
	push @header, 'sum/order_total';
	push @header, 'want/order_notes';
	push @header, 'want/referred_by';

	my @line = ();
	foreach my $k (@header) {
		if ($k eq 'HORDER') {
			push @line, 'ORDER';
			}
		elsif ($k eq 'ORDERID') {
			push @line, $order_id;
			}
		else {
			push @line, $O2->pr_get($k);
			}
		}
	my $status  = $csv->combine(@header);  
	$OUT .= $csv->string()."\r\n";
	$status  = $csv->combine(@line);
	$OUT .= $csv->string()."\r\n";

	##
	## order items
	##
	@header = ();
	push @header, "HITEM";
	push @header, "ORDERID";
	push @header, "stid";
	push @header, "sku";
	push @header, "mfgid";
	push @header, "description";
	push @header, "qty";
	push @header, "price";
	push @header, "cost";
	push @header, "mkt";
	push @header, "mktid";
	push @header, "asm_master";
	push @header, "%zoovy:prod_mfg";
	push @header, "%zoovy:prod_mfgid";
	$status  = $csv->combine(@header);  
	$OUT .= $csv->string()."\r\n";
	foreach my $item (@{$O2->stuff2()->items()}) {
		@line = ();

		foreach my $k (@header) {
			if ($k eq 'HITEM') {
				push @line, "ITEM";
				}
			elsif ($k eq 'ORDERID') {
				push @line, $order_id;
				}
			elsif (substr($k,0,1) eq '%') {
				push @line, $item->{'%attribs'}->{substr($k,1)};
				}
			else {
				push @line, $item->{$k};
				}
			} 
		$status  = $csv->combine(@line);
		$OUT .= $csv->string()."\r\n";
		}

	##
	## order events
	##
	if (scalar(@{$O2->history()})>0) {
		@header = ();
		push @header, "HEVENT";
		push @header, "ORDERID";
		push @header, "uuid";
		push @header, "ts";
		push @header, "etype";
		push @header, "luser";
		push @header, "content";
		$status  = $csv->combine(@header);  
		$OUT .= $csv->string()."\r\n";
		foreach my $e (@{$O2->history()}) {
			@line = ();
			foreach my $k (@header) {
				if ($k eq 'HEVENT') {	
					push @line, "EVENT";
					}
				elsif ($k eq 'ORDERID') {
					push @line, $order_id;
					}
				else {
					push @line, $e->{$k};
					}
				}
			$status  = $csv->combine(@line);
			$OUT .= $csv->string()."\r\n";
			}
		}

	##
	## order tracking.
	##
	if (scalar(@{$O2->tracking()})>0) {
		@header = ();
		push @header, "HTRACK";
		push @header, "ORDERID";
		push @header, 'carrier';
		push @header, 'created';
		push @header, 'cost';
		push @header, 'actualwt';
		push @header, 'track';
		push @header, 'content';
		push @header, 'void';
		push @header, 'ins';
		push @header, 'dv';
 		push @header, 'notes';
		$status  = $csv->combine(@header);  
		$OUT .= $csv->string()."\r\n";
		foreach my $trk (@{$O2->tracking()}) {
			@line = ();
			foreach my $k (@header) {
				if ($k eq 'HTRACK') {
					push @line, "TRACK";
					}
				elsif ($k eq 'ORDERID') {
					push @line, $order_id;
					}
				else {
					push @line, $trk->{$k};
					}
				}
			$status  = $csv->combine(@line);
			$OUT .= $csv->string()."\r\n";
			}
		}

	return($OUT);
	}


1;