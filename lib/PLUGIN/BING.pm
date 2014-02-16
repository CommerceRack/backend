package PLUGIN::BING;

#		## JELLYFISH
#		if (int($o->{'data'}->{'mkt'}) & 32768) {


#sub pixel_for_order {
#	my ($o) = @_;
#
#	# var jf_rnd = Math.floor(Math.random()*999999999);
#	# var jf_url ="https://www.jellyfish.com/pixel?rnd=" + jf_rnd + "&jftid=" + jf_transaction_id + "&jfoid=" + jf_merchant_order_num + "&jfmid=" + jf_merchant_id;
#	# for(var jf_i=0; jf_i<jf_purchased_items.length; jf_i++) {
#	#	var jf_mpi			= escape(jf_purchased_items[jf_i].mpi);
#	#	var jf_price		= (jf_purchased_items[jf_i].price+"").replace(/,/g,'').replace(/\$/g,'');
#	#	var jf_quantity = (jf_purchased_items[jf_i].quantity+"").replace(/,/g,'').replace(/\$/g,'');
#	# 	jf_url = jf_url + "&m["+jf_i+"]="+jf_mpi+"&p["+jf_i+"]="+jf_price+"&q["+jf_i+"]="+jf_quantity;
#	#	}
#	require URI::Escape;
#	my $JFMID = $o->{'data'}->{'jf_mid'};
#	my $JFTID = $o->{'data'}->{'jf_tid'};
#
#	# my $jf_url = "https://www.jellyfish.com/pixel?rnd=".rand()."&jftid=".$JFTID."&jfoid=".$o->id()."&jfmid=".$JFMID;
#	my $jf_url = "https://ssl.bing.com/cashback/pixel/index?rnd=".rand()."&jftid=".$JFTID."&jfoid=".$o->id()."&jfmid=".$JFMID;
#	if ($o->{'data'}->{'payment_methods'} eq 'PAYPALEC') {
#		## Brian,
#		## We'll be happy to get on the phone to discuss tomorrow but I think that I have the answer that you were looking for.	You will continue doing the same call but you'll need to add the paypal transaction id at the end of it and it should look as follows:
#		## https://www.jellyfish.com/pixel?rnd= <https://www.jellyfish.com/pixel?rnd=> ".rand()."&jftid=".$JFTID."&jfoid=".$o->id()."&jfmid=".$JFMID."&qcp=PayPal"."&qct=".$PaypalTransactionID
#		## Also please remember that you need to send an email to adcash@microsoft.com so MSFT can schedule a test date for you
#		## Thank you and please let me know if we still need a meeting for tomorrow
#		$jf_url .= "&qct=".$o->{'data'}->{'cc_bill_transaction'};
#		}
#
#	my $i = 0;
#	foreach my $stid ($O2->stuff2()->stids()) {
#		my $item = $o->stuff()->item($stid);
#		my $jf_mpi = URI::Escape::uri_escape($stid);
#		my $jf_price = URI::Escape::uri_escape($item->{'price'});
#		my $jf_quantity = URI::Escape::uri_escape($item->{'qty'});
#		$jf_url .= "&m[$i]=$jf_mpi&p[$i]=$jf_price&q[$i]=$jf_quantity";
#		$i++;
#		}
#
#	return($jf_url);
#	}
#
#
1;
